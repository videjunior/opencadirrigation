import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_vision.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Aerial tiles as photos are: grain a PNG cannot shrink.
class PhotoTiles extends TileFetcher {
  PhotoTiles() : png = _photo();
  final Uint8List png;
  final urls = <String>[];

  static Uint8List _photo() {
    final r = math.Random(7);
    final im = img.Image(width: 256, height: 256);
    for (final p in im) {
      p.setRgb(40 + r.nextInt(120), 90 + r.nextInt(120), 30 + r.nextInt(80));
    }
    return img.encodePng(im);
  }

  @override
  Future<Uint8List> bytes(String url) async {
    urls.add(url);
    return png;
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw StateError('offline');
}

/// The pictures the AI assistant's tools send the model: over the aerial
/// map a JPEG, a fraction of the PNG (every request of a conversation
/// carries its pictures again), at the same size, so the mapping holds; the
/// drawing on its plain background stays a PNG; the PNG itself stays for
/// what reads its pixels.
void main() {
  late ProjectController c;
  late AgentToolbox box;
  late PhotoTiles tiles;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    tiles = PhotoTiles();
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
  });

  Future<ToolOutput> run(WidgetTester tester, String name, Map<String, dynamic> input) async {
    ToolOutput? out;
    Object? error;
    await tester.runAsync(() async {
      try {
        out = await box.tools.firstWhere((t) => t.name == name).run(input);
      } catch (e) {
        error = e;
      }
    });
    if (error != null) throw error!;
    return out!;
  }

  Future<void> pipe(WidgetTester tester, {double y0 = 10, double y1 = 10}) => run(tester, 'create_entities', {
    'entities': [
      {
        'type': 'pipe',
        'scope': 'mainline',
        'pts': [
          [-50, y0],
          [50, y1],
        ],
      },
    ],
  });

  testWidgets('over the aerial map: a JPEG at the same size, far smaller than the PNG; a plain drawing stays PNG', (tester) async {
    c.setGeoreferenceAt(-21.8, -46.6);
    await pipe(tester);
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -60, 100, 60],
      'base_map': 'satellite',
      'size': 1024,
    });
    expect(tiles.urls, isNotEmpty);
    final shot = out.images.single;
    expect(shot.mediaType, 'image/jpeg');
    final im = img.decodeJpg(base64Decode(shot.base64))!;
    expect(im.width, 1024);
    expect(out.text, contains('1024×614 px'), reason: 'the mapping describes the picture sent');
    // the mainline (blue) still shows over the photo
    final m = VisionSession.of(box)['s1']!;
    final (x, y) = m.toPixel(const Pt(10, 10));
    expect(im.getPixel(x.floor(), y.floor()).b, greaterThan(140));

    SnapshotImage? pic;
    await tester.runAsync(() async {
      pic = await CanvasSnapshots(tiles: tiles).render(c, VisionSpec(world: const Bounds(-100, -60, 100, 60), maxSide: 1024, maps: const [BaseMap.satellite]));
    });
    expect(pic!.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: 'the PNG stays, lossless');
    expect(pic!.jpeg, isNotNull);
    expect(pic!.jpeg!.length, lessThan(pic!.png.length ~/ 2));
    expect(pic!.mediaType, 'image/jpeg');

    final plain = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -60, 100, 60],
      'base_map': 'none',
      'size': 1024,
    });
    expect(plain.images.single.mediaType, 'image/png', reason: 'a drawing on the plain background is small as a PNG and keeps its lines sharp');
  });

  testWidgets('the picture after a change and the user\'s view over the aerial map go as JPEG too', (tester) async {
    c.setGeoreferenceAt(-21.8, -46.6);
    c.baseMap = BaseMap.satellite;
    c.camera
      ..size = const Size(800, 600)
      ..center = Pt.zero
      ..scale = 4;
    // the picture after a change frames the drawing: a diagonal one, not a strip
    await pipe(tester, y0: -40, y1: 40);
    ToolImage? fb;
    ViewPicture? view;
    await tester.runAsync(() async {
      fb = await feedbackPicture(box);
      view = await captureUserView(c, snapshots: CanvasSnapshots(tiles: tiles));
    });
    expect(fb!.mediaType, 'image/jpeg');
    expect(img.decodeJpg(base64Decode(fb!.base64))!.width, 768);
    expect(view!.mime, 'image/jpeg');
    expect(view!.bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(view!.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(view!.name, 'view-u1.jpg');
    expect(view!.mapping, contains('1024×768 px'));
  });

  test('image_to_world says it converts both ways without naming a tool that does not exist', () {
    final d = box.tools.firstWhere((t) => t.name == 'image_to_world').description;
    expect(d, isNot(contains('world_to_image')));
    expect(d, contains('the other way'));
    expect(box.tools.any((t) => t.name == 'world_to_image'), isFalse);
  });
}
