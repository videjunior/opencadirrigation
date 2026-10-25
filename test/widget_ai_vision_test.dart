import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_vision.dart';
import 'package:opencadirrigation/app/ai/playbooks.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Map tiles without a network: every tile one colour, none above
/// [maxZoom] (404 as the services answer), or every request failing.
class FakeTiles extends TileFetcher {
  FakeTiles({this.maxZoom = 30, this.offline = false, int r = 30, int g = 200, int b = 40}) : png = img.encodePng(img.fill(img.Image(width: 256, height: 256), color: img.ColorRgb8(r, g, b)));
  final int maxZoom;
  final bool offline;
  final Uint8List png;
  final urls = <String>[];
  final requests = <String>[];

  static int zoomOf(String url) => int.parse(RegExp(r'/(\d+)/(\d+)/(\d+)').firstMatch(url)!.group(1)!);

  @override
  Future<Uint8List> bytes(String url) async {
    urls.add(url);
    if (offline) throw StateError('offline');
    if (zoomOf(url) > maxZoom) throw HttpStatusException(404);
    return png;
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async {
    requests.add('$method $url');
    if (offline) throw StateError('offline');
    if (url.contains('createSession')) return jsonEncode({'session': 'fake-session', 'expiry': '${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}'});
    if (url.contains('viewport')) {
      return jsonEncode({
        'copyright': 'Imagery ©2026 Google',
        'maxZoomRects': [
          {'maxZoom': 19, 'north': 90, 'south': -90, 'east': 180, 'west': -180},
        ],
      });
    }
    throw HttpStatusException(404);
  }
}

/// The vision tools of the AI assistant: one composite picture of the
/// drawing over the base map (the satellite whenever georeferenced) with an
/// exact pixel ↔ world mapping, previews that leave the project alone, the
/// terrain relief and its numbers, and the pictures the assistant attaches.
void main() {
  late ProjectController c;
  late AgentToolbox box;
  late FakeTiles tiles;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    tiles = FakeTiles();
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
  });

  AgentTool tool(String name) => box.tools.firstWhere((t) => t.name == name);

  Future<ToolOutput> run(WidgetTester tester, String name, Map<String, dynamic> input) async {
    Object? error;
    ToolOutput? out;
    await tester.runAsync(() async {
      try {
        out = await tool(name).run(input);
      } catch (e) {
        error = e;
      }
    });
    if (error != null) throw error!;
    return out!;
  }

  img.Image decode(ToolImage i) => img.decodePng(base64Decode(i.base64))!;

  /// The colour at world point [p] of picture [id].
  List<int> colourAt(img.Image im, String id, Pt p) {
    final m = VisionSession.of(box)[id]!;
    final (x, y) = m.toPixel(p);
    final px = im.getPixel(x.floor(), y.floor());
    return [px.r.toInt(), px.g.toInt(), px.b.toInt()];
  }

  /// Spot heights z(x, y) on a grid over ±[half] every [step] metres.
  void heights(double Function(double x, double y) z, {double half = 100, double step = 10}) {
    final p = c.project;
    for (var x = -half; x <= half + 1e-9; x += step) {
      for (var y = -half; y <= half + 1e-9; y += step) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z(x, y)));
      }
    }
    c.entitiesChanged();
  }

  testWidgets('pixel ↔ world mapping: square pixels, exact round trip, image_to_world both ways', (tester) async {
    final f = PictureFrame.fit(const Bounds(-12.4, -30, 243.6, 140.75), 1024);
    expect(f.width, 1024);
    expect(f.world.width / f.width, closeTo(f.world.height / f.height, 1e-12), reason: 'square pixels');
    final m = SnapshotMapping('s9', f.world, f.width, f.height);
    for (final (px, py) in [(0.0, 0.0), (1024.0, f.height.toDouble()), (123.5, 456.25)]) {
      final (bx, by) = m.toPixel(m.toWorld(px, py));
      expect(bx, closeTo(px, 1e-9));
      expect(by, closeTo(py, 1e-9));
    }
    expect(m.toWorld(0, 0), Pt(f.world.minX, f.world.maxY), reason: 'pixel (0, 0) is the top-left corner');
    expect(m.describe(), contains('x = minX + px·s'));
    final square = PictureFrame.fit(const Bounds(0, 0, 100, 100), maxPictureSide);
    expect(square.width * square.height, lessThanOrEqualTo(maxPicturePixels), reason: 'no provider rescales it');

    final shot = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 200, 100],
      'size': 800,
    });
    expect(shot.images, hasLength(1));
    expect(shot.text, contains('Picture s1'));
    expect(shot.text, contains('800×400 px'));
    expect(shot.text, contains('s = 0.25000 m per pixel'));
    final conv = await run(tester, 'image_to_world', {
      'snapshot': 's1',
      'pixels': [
        [0, 0],
        [800, 400],
        [123.5, 77.25],
      ],
      'closed': true,
    });
    final world = jsonDecode(RegExp(r'World points \[x, y\] in m: (\[.*\])').firstMatch(conv.text)!.group(1)!) as List;
    expect(world[0], [0.0, 100.0]);
    expect(world[1], [200.0, 0.0]);
    expect(world[2], [30.88, 80.69]);
    expect(conv.text, contains('Closed outline: area'));
    final back = await run(tester, 'image_to_world', {'snapshot': 's1', 'pts': world});
    final px = jsonDecode(RegExp(r'Pixels \[px, py\] on s1: (\[.*\])').firstMatch(back.text)!.group(1)!) as List;
    expect((px[2] as List)[0], closeTo(123.5, 0.1));
    expect((px[2] as List)[1], closeTo(77.25, 0.1));
    await expectLater(
      tool('image_to_world').run({
        'snapshot': 's7',
        'pixels': [
          [1, 1],
        ],
      }),
      throwsA(isA<ToolInputError>().having((e) => e.message, 'message', contains('view_snapshot'))),
    );
    // zoom: a part of the picture at full resolution
    final zoom = await run(tester, 'view_snapshot', {
      'snapshot': 's1',
      'pixel_bbox': [0, 0, 400, 200],
      'size': 800,
    });
    expect(zoom.text, contains('Picture s2'));
    expect(zoom.text, contains('[0.00, 50.00, 100.00, 100.00]'));
  });

  testWidgets('the satellite under the drawing in one picture; the user\'s base map and view stay', (tester) async {
    c.setGeoreferenceAt(-21.8, -46.6);
    c.baseMap = BaseMap.streets;
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'pipe',
          'scope': 'mainline',
          'pts': [
            [-50, 10],
            [50, 10],
          ],
        },
      ],
    });
    final cam = c.camera;
    final before = (cam.center, cam.scale, cam.size);
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -60, 100, 60],
      'base_map': 'satellite',
      'size': 600,
    });
    expect(out.images, hasLength(1), reason: 'one composite image');
    expect(tiles.urls, isNotEmpty);
    expect(tiles.urls.every((u) => u.contains('World_Imagery')), isTrue, reason: 'Esri World Imagery without a Google key');
    expect(c.baseMap, BaseMap.streets, reason: 'the user\'s choice stays');
    expect((cam.center, cam.scale, cam.size), before, reason: 'the view did not move');
    expect(out.text, contains('the drawing over Esri World Imagery (tile zoom 19)'));
    expect(out.text, contains('Imagery credit: Esri, Maxar, Earthstar Geographics'));
    expect(out.text, contains('keeps its own base map (OpenStreetMap)'));
    final im = decode(out.images.single);
    expect(im.width, 600);
    final ground = colourAt(im, 's1', const Pt(-80, 40));
    expect(ground[1], greaterThan(140), reason: 'the tile shows where nothing is drawn: $ground');
    expect(ground[0], lessThan(60));
    final pipe = colourAt(im, 's1', const Pt(10, 10));
    expect(pipe[2], greaterThan(150), reason: 'the mainline is drawn over the map in its layer colour: $pipe');

    // imagery that ends at a lower zoom: the level under the centre is used
    tiles = FakeTiles(maxZoom: 17);
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
    final low = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -60, 100, 60],
      'base_map': 'satellite',
      'size': 600,
    });
    expect(low.text, contains('tile zoom 17'));
    expect(low.text, contains('nothing closer than zoom 17'));

    // offline: the drawing alone, and why
    tiles = FakeTiles(offline: true);
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
    final off = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -60, 100, 60],
      'base_map': 'satellite',
    });
    expect(off.images, hasLength(1));
    expect(off.text, contains('could be downloaded'));
    expect(off.text, contains('the drawing without a base map'));
  });

  testWidgets('Google satellite when the user has a key, with its copyright; the default map follows the screen', (tester) async {
    c.setGeoreferenceAt(-21.8, -46.6);
    c.googleMapsKey = 'test-key';
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -50, 50, 50],
      'base_map': 'satellite',
      'size': 512,
    });
    expect(tiles.requests.first, contains('createSession'));
    expect(tiles.urls.every((u) => u.contains('tile.googleapis.com/v1/2dtiles')), isTrue);
    expect(out.text, contains('Google satellite'));
    expect(out.text, contains('Imagery ©2026 Google'));
    expect(c.baseMap, BaseMap.none);
    // no base_map: georeferenced with nothing on screen → the satellite
    tiles.urls.clear();
    final plain = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -50, 50, 50],
      'size': 512,
    });
    expect(plain.text, contains('over Google satellite'));
    // the map alone, and none
    final map = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -50, 50, 50],
      'drawing': false,
      'size': 400,
    });
    expect(map.text, contains('Google satellite (tile zoom 19) without the drawing'));
    final none = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -50, 50, 50],
      'base_map': 'none',
      'labels': 'ids',
      'legend': true,
      'grid': 'dense',
    });
    expect(none.text, isNot(contains('Base map:')));
    expect(none.text, contains('Legend: no items'));
    expect(none.text, contains('Labels: 0 items'));
  });

  testWidgets('preview_geometry draws proposals and leaves the project as it was', (tester) async {
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'area',
          'pts': [
            [0, 0],
            [60, 0],
            [60, 40],
            [0, 40],
          ],
        },
        {
          'type': 'controlValve',
          'p': [5, 5],
        },
      ],
    });
    final before = c.project.toJsonString();
    final history = c.historyIndex;
    final out = await run(tester, 'preview_geometry', {
      'shapes': [
        {
          'kind': 'polygon',
          'pts': [
            [10, 10],
            [50, 10],
            [50, 40],
            [10, 40],
          ],
          'label': 'Field',
        },
        {
          'kind': 'polyline',
          'pts': [
            [0, -5],
            [60, -5],
          ],
        },
        {
          'kind': 'point',
          'pts': [
            [30, 20],
          ],
        },
      ],
    });
    expect(out.images, hasLength(1));
    expect(c.project.toJsonString(), before, reason: 'nothing added or changed');
    expect(c.historyIndex, history, reason: 'no undo step');
    expect(out.text, contains('Field polygon, 4 vertices: area 1200.0 m²'));
    expect(out.text, contains('P2 polyline, 2 vertices: length 60.00 m'));
    expect(out.text, contains('The project was not changed.'));
    final im = decode(out.images.single);
    var magenta = 0;
    for (final px in im) {
      if (px.r > 200 && px.g < 90 && px.b > 160) magenta++;
    }
    expect(magenta, greaterThan(100), reason: 'the proposals are drawn in magenta');
    // pixels of a picture, and an outline that crosses itself
    final cross = await run(tester, 'preview_geometry', {
      'snapshot': 's1',
      'shapes': [
        {
          'kind': 'polygon',
          'pixels': [
            [100, 100],
            [300, 300],
            [300, 100],
            [100, 300],
          ],
        },
      ],
    });
    expect(cross.text, contains('crosses itself'));
    expect(c.project.toJsonString(), before);
    await expectLater(
      tool('preview_geometry').run({
        'shapes': [
          {
            'kind': 'polygon',
            'pts': [
              [0, 0],
              [1, 1],
            ],
          },
        ],
      }),
      throwsA(isA<ToolInputError>()),
    );
  });

  testWidgets('terrain picture of a hill: contours, hillshade lit from the north-west, slope classes', (tester) async {
    await expectLater(tool('terrain_picture').run({}), throwsA(isA<ToolInputError>().having((e) => e.message, 'message', contains('download_terrain'))));
    heights((x, y) => 100 - 0.002 * (x * x + y * y));
    final out = await run(tester, 'terrain_picture', {'region': 'terrain', 'size': 512, 'grid': 'none'});
    expect(out.images, hasLength(1));
    expect(out.text, contains('Picture s1: terrain relief (hillshade, elevation colours, contours every 5.0 m)'));
    expect(out.text, contains('441 height samples'));
    expect(out.text, contains('Contours: every 5.0 m'));
    final range = RegExp(r'between (\d+\.\d+) and (\d+\.\d+) m').firstMatch(out.text)!;
    expect(double.parse(range.group(1)!), inInclusiveRange(59.5, 61.5), reason: 'the corners of the data');
    expect(double.parse(range.group(2)!), inInclusiveRange(99.5, 100), reason: 'the summit');
    expect(out.text, contains('lit from the north-west'));
    expect(out.text, contains('Hatched'), reason: 'the margin around the data');
    // pure hillshade: the north-west flank bright, the south-east one dark
    final shade = await run(tester, 'terrain_picture', {'region': 'terrain', 'size': 512, 'grid': 'none', 'colour': 'none', 'contours': false});
    final im = decode(shade.images.single);
    final nw = colourAt(im, 's2', const Pt(-50, 50)), se = colourAt(im, 's2', const Pt(50, -50));
    expect(nw[0], greaterThan(se[0] + 40), reason: 'NW $nw, SE $se');
    final slope = await run(tester, 'terrain_picture', {'region': 'terrain', 'size': 400, 'colour': 'slope'});
    expect(slope.text, contains('slope classes as the app\'s slope map'));
    expect(slope.text, contains('share of the mapped area'));
    final info = await run(tester, 'terrain_info', {});
    expect(info.text, contains('441 height samples'));
    expect(info.text, contains('441 own spot heights'));
    expect(info.text, contains('samples per hectare'));
  });

  testWidgets('terrain profile on a plane: exact rise, fall, extremes and slope', (tester) async {
    final none = await run(tester, 'terrain_info', {});
    expect(none.text, contains('No terrain data'));
    heights((x, y) => 50 + 0.02 * x, step: 50);
    final out = await run(tester, 'terrain_profile', {
      'pts': [
        [-50, 0],
        [50, 0],
        [0, 0],
      ],
      'step_m': 5,
    });
    expect(out.text, contains('150.0 m, sampled every 5.00 m'));
    expect(out.text, contains('z 49.00 m → end [0.00, 0.00] z 50.00 m: net +1.00 m'));
    expect(out.text, contains('Total rise 2.00 m, total fall 1.00 m; steepest uphill 2.0 %'));
    expect(out.text, contains('Highest z 51.00 m at d 100.0 m [50.00, 0.00]'));
    expect(out.text, contains('lowest z 49.00 m at d 0.0 m [-50.00, 0.00]'));
    expect(out.text, contains('Segments: 1) 0.0–100.0 m: +2.00 / −0.00 m, mean +2.00 %; 2) 100.0–150.0 m: +0.00 / −1.00 m, mean -2.00 %'));
    expect(out.text, contains('d m | x | y | z m | slope %'));
  });

  testWidgets('the user\'s view as a picture with its mapping, and the picture after a change', (tester) async {
    c.camera
      ..size = const Size(800, 600)
      ..center = Pt.zero
      ..scale = 4;
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'pipe',
          'scope': 'mainline',
          'pts': [
            [-40, 0],
            [40, 0],
          ],
        },
      ],
    });
    ViewPicture? pic;
    await tester.runAsync(() async => pic = await captureUserView(c, snapshots: CanvasSnapshots(tiles: tiles)));
    expect(pic, isNotNull);
    expect(pic!.png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(pic!.mapping, contains('Picture u1'));
    expect(pic!.mapping, contains('1024×768 px'));
    expect(pic!.mapping, contains('[-100.00, -75.00, 100.00, 75.00]'));
    expect(c.camera.center, Pt.zero);
    expect(c.camera.scale, 4);
    final conv = await run(tester, 'image_to_world', {
      'snapshot': 'u1',
      'pixels': [
        [0, 0],
      ],
    });
    expect(conv.text, contains('[[-100.0,75.0]]'));
    ToolImage? fb;
    await tester.runAsync(() async => fb = await feedbackPicture(box));
    expect(fb, isNotNull);
    expect(fb!.mediaType, 'image/png');
    expect(decode(fb!).width, 768);
    expect(lastFeedbackMapping(box), contains('the drawing after the change'));
  });
  testWidgets('without a georeference a picture says why it has no map; drawing false then has nothing to show', (tester) async {
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'controlValve',
          'p': [0, 0],
        },
      ],
    });
    final out = await run(tester, 'view_snapshot', {'region': 'drawing', 'base_map': true, 'size': 400});
    expect(out.images, hasLength(1));
    expect(out.text, contains('No base map: the project has no georeference'));
    expect(tiles.urls, isEmpty);
    await expectLater(tool('view_snapshot').run({'region': 'drawing', 'drawing': false}), throwsA(isA<ToolInputError>().having((e) => e.message, 'message', contains('set_site'))));
    await expectLater(tool('view_snapshot').run({'region': 'drawing', 'base_map': 'aerial photo'}), throwsA(isA<ToolInputError>()));
  });

  testWidgets('every playbook starts from the satellite picture and checks traced shapes before creating them', (tester) async {
    final names = box.tools.map((t) => t.name).toSet();
    for (final n in ['view_snapshot', 'image_to_world', 'preview_geometry', 'terrain_picture', 'terrain_profile', 'terrain_info']) {
      expect(names, contains(n));
    }
    for (final pb in playbooks) {
      expect(pb.steps, contains('view_snapshot {region "bbox", bbox'), reason: pb.id);
      expect(pb.steps, contains('base_map "satellite"'), reason: pb.id);
      expect(pb.steps, contains('image_to_world'), reason: pb.id);
      expect(pb.steps, contains('preview_geometry'), reason: pb.id);
      expect(pb.steps, isNot(contains('base_map true')), reason: pb.id);
    }
    expect(playbooks.where((pb) => pb.steps.contains('terrain_profile')).length, greaterThanOrEqualTo(8));
  });
  testWidgets('when no tile comes off screen, the map on screen is used and the view comes back', (tester) async {
    c.setGeoreferenceAt(-21.8, -46.6);
    c.baseMap = BaseMap.satellite;
    c.camera
      ..size = const Size(800, 600)
      ..center = const Pt(500, 500)
      ..scale = 2;
    final screen = FakeTiles(r: 200, g: 30, b: 30).png;
    var asked = 0;
    c.baseMapSnapshot = () async {
      asked++;
      final v = c.camera.visible;
      return (screen, [Pt(v.minX, v.minY), Pt(v.maxX, v.minY), Pt(v.maxX, v.maxY), Pt(v.minX, v.maxY)]);
    };
    tiles = FakeTiles(offline: true);
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -50, 50, 50],
      'size': 400,
    });
    expect(asked, greaterThan(0));
    expect(out.text, contains('as the screen shows it'));
    expect(c.camera.center, const Pt(500, 500), reason: 'the view is back');
    expect(c.camera.scale, 2);
    expect(c.baseMap, BaseMap.satellite);
    final red = colourAt(decode(out.images.single), 's1', const Pt(-10, 10));
    expect(red[0], greaterThan(120), reason: 'the map the screen showed: $red');
    expect(red[1], lessThan(60));
  });
  testWidgets('the summaries of the vision tools are translated', (tester) async {
    final calls = <(String, Map<String, dynamic>)>[
      ('view_snapshot', {}),
      ('view_snapshot', {'base_map': 'satellite'}),
      ('view_snapshot', {'base_map': 'street'}),
      ('view_snapshot', {'base_map': 'current'}),
      ('view_snapshot', {'drawing': false}),
      (
        'view_snapshot',
        {
          'snapshot': 's1',
          'pixel_bbox': [0, 0, 10, 10],
        },
      ),
      (
        'image_to_world',
        {
          'snapshot': 's1',
          'pixels': [
            [0, 0],
          ],
        },
      ),
      ('preview_geometry', {'shapes': []}),
      ('terrain_picture', {}),
      ('terrain_picture', {'colour': 'slope'}),
      (
        'terrain_profile',
        {
          'pts': [
            [0, 0],
            [120, 0],
          ],
        },
      ),
      ('terrain_info', {}),
    ];
    for (final (name, input) in calls) {
      expect(tool(name).describe(input), isNot(contains('ai.')), reason: name);
    }
    expect(tool('terrain_profile').describe(calls[10].$2), 'Terrain profile along 120 m');
    await c.setLanguage('pt', persist: false);
    expect(tool('view_snapshot').describe({'base_map': 'satellite'}), 'Olhar o desenho sobre a imagem de satélite');
    expect(c.t('ai.vis.privacy'), contains('provedor de IA'));
  });
}
