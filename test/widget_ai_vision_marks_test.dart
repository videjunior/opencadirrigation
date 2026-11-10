import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_vision.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// Map tiles drawn from the world: a field of crop rows inside [field]
/// (project metres), bare soil around it, as an aerial image would show
/// them, for the projection of [g]. Without [g], every tile one colour.
class _FieldTiles extends TileFetcher {
  _FieldTiles([this.g, this.field = Bounds.empty]);
  final GeoReference? g;
  final Bounds field;
  final _cache = <String, Uint8List>{};
  int served = 0;

  @override
  Future<Uint8List> bytes(String url) async {
    final m = RegExp(r'/(\d+)/(\d+)/(\d+)').firstMatch(url)!;
    final z = int.parse(m.group(1)!), ty = int.parse(m.group(2)!), tx = int.parse(m.group(3)!);
    return _cache.putIfAbsent(url, () {
      served++;
      final im = img.Image(width: 256, height: 256);
      final rnd = math.Random(tx * 31 + ty);
      // the tile corners in project metres; within a tile the projection is
      // as good as linear
      Pt at(double u, double v) {
        if (g == null) return Pt.zero;
        final n = math.pow(2.0, z);
        final lon = (tx + u) / n * 360 - 180;
        final lat = math.atan(_sinh(math.pi * (1 - 2 * (ty + v) / n))) * 180 / math.pi;
        final (x, y) = g!.fromLatLon(lat, lon);
        return Pt(x, y);
      }

      final p00 = at(0, 0), p10 = at(1, 0), p01 = at(0, 1);
      for (var j = 0; j < 256; j++) {
        for (var i = 0; i < 256; i++) {
          final u = (i + 0.5) / 256, v = (j + 0.5) / 256;
          final q = p00 + (p10 - p00) * u + (p01 - p00) * v;
          final inField = !field.isEmpty && field.contains(q);
          final rows = (q.x / 1.5).floor().isEven;
          final (r, gg, b) = inField ? (rows ? (60, 140, 50) : (44, 112, 38)) : (132, 102, 72);
          final k = rnd.nextInt(17) - 8;
          im.setPixelRgb(i, j, (r + k).clamp(0, 255), (gg + k).clamp(0, 255), (b + k).clamp(0, 255));
        }
      }
      return img.encodePng(im);
    });
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404);
}

/// The vision marks of the AI assistant: pictures for the model's own
/// resolution, coloured by zone or by results without touching the screen,
/// the design messages and the assistant's own changes marked at their
/// items, the picture after a round framed on what changed, and fields
/// traced on the aerial image from one point.
void main() {
  late ProjectController c;
  late AgentToolbox box;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _FieldTiles()));
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

  img.Image decode(ToolImage i) => img.decodeImage(base64Decode(i.base64))!;

  /// The colour at world point [p] of the last picture [id].
  List<int> colourAt(img.Image im, String id, Pt p) {
    final m = VisionSession.of(box)[id]!;
    final (x, y) = m.toPixel(p);
    final px = im.getPixel(x.floor().clamp(0, im.width - 1), y.floor().clamp(0, im.height - 1));
    return [px.r.toInt(), px.g.toInt(), px.b.toInt()];
  }

  /// Two zones fed by a mainline: North along y = 0, South along y = 30.
  void twoZones() {
    c.addEntities([
      WaterSupplyEntity(id: 'ws', position: const Pt(-40, 0), calculatePressure: false, designHeadM: 45, designFlow: 10 * m3sPerM3h),
      PipeEntity(id: 'm1', points: const [Pt(-40, 0), Pt(0, 0)], scope: HydraulicScope.mainline),
      PipeEntity(id: 'm2', points: const [Pt(0, 0), Pt(0, 30)], scope: HydraulicScope.mainline),
      ControlValveEntity(id: 'v1', position: const Pt(0, 0), zoneName: 'North', valveSpecId: 'ev40'),
      ControlValveEntity(id: 'v2', position: const Pt(0, 30), zoneName: 'South', valveSpecId: 'ev40'),
      PipeEntity(id: 'z1', points: const [Pt(0, 0), Pt(40, 0)], scope: HydraulicScope.zone),
      PipeEntity(id: 'z2', points: const [Pt(0, 30), Pt(40, 30)], scope: HydraulicScope.zone),
      OutletEntity(id: 'o1', position: const Pt(40, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
      OutletEntity(id: 'o2', position: const Pt(40, 30), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
    ]);
  }

  testWidgets('pictures follow the model: up to 2576 px and 3.6 megapixels on Claude\'s high-resolution models, 1568 px otherwise', (tester) async {
    expect(PictureLimits.of(AiModel.opus55), PictureLimits.high);
    expect(PictureLimits.of(AiModel.sonnet55), PictureLimits.high);
    expect(PictureLimits.of(AiModel.fable52), PictureLimits.high);
    expect(PictureLimits.of(AiModel.haiku55), PictureLimits.high, reason: 'every Claude model from Opus 4.7 on reads the high resolution');
    expect(PictureLimits.of(AiModel.orOpus55), PictureLimits.high, reason: 'the same model through OpenRouter');
    expect(PictureLimits.of(AiModel.orGpt61Sol), PictureLimits.openai);
    expect(PictureLimits.of(AiModel.gemini38Flash), PictureLimits.standard);
    expect(PictureLimits.of(AiModel.grok47), PictureLimits.standard);
    expect(PictureLimits.of(AiModel.museSpark), PictureLimits.standard);
    expect(PictureLimits.of(AiModel.gpt6Astra), PictureLimits.openai);
    expect(PictureLimits.of(AiModel.gpt61Sol), PictureLimits.openai);
    box = AgentToolbox(
      c,
      snapshots: CanvasSnapshots(tiles: _FieldTiles()),
      pictures: PictureLimits.high,
    );
    final size = ((tool('view_snapshot').inputSchema['properties'] as Map)['size'] as Map)['description'] as String;
    expect(size, contains('256–2576'));
    final wide = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 200, 100],
      'size': 2000,
    });
    expect(wide.text, contains('2000×1000 px'));
    expect(decode(wide.images.single).width, 2000);
    final square = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 100, 100],
      'size': 2000,
    });
    final sq = decode(square.images.single);
    expect(sq.width * sq.height, lessThanOrEqualTo(PictureLimits.high.maxPixels));
    expect(sq.width, greaterThan(1800));
    // the model of the next request reads less: the size comes down, with a note
    box.pictures = PictureLimits.standard;
    final reduced = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 200, 100],
      'size': 2000,
    });
    expect(reduced.text, contains('size 2000 was reduced to 1568'));
    final r = decode(reduced.images.single);
    expect(r.width, lessThanOrEqualTo(1568));
    expect(r.width * r.height, lessThanOrEqualTo(PictureLimits.standard.maxPixels));
    // OpenAI's models read a shorter side of at most 768 px as it is
    box.pictures = PictureLimits.openai;
    final gpt = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 100, 100],
    });
    final g = decode(gpt.images.single);
    expect(math.min(g.width, g.height), lessThanOrEqualTo(768));
  });

  testWidgets('colour_by zones paints every zone in its colour with its name, the mainline white; the screen keeps its overlay', (tester) async {
    twoZones();
    final overlay = c.overlay;
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -10, 50, 40],
      'colour_by': 'zones',
      'grid': 'none',
    });
    expect(out.text, contains('Colours: every zone in its own colour'));
    expect(out.text, contains('North #E6194B (valve v1'));
    expect(out.text, contains('South #3CB44B (valve v2'));
    expect(out.text, contains('The mainline is white'));
    final im = decode(out.images.single);
    final north = colourAt(im, 's1', const Pt(20, 0)), south = colourAt(im, 's1', const Pt(20, 30)), main = colourAt(im, 's1', const Pt(-20, 0));
    expect(north[0], greaterThan(150), reason: 'North is red: $north');
    expect(north[1], lessThan(110), reason: 'North is red: $north');
    expect(south[1], greaterThan(130), reason: 'South is green: $south');
    expect(south[0], lessThan(120), reason: 'South is green: $south');
    expect(main.every((v) => v > 170), isTrue, reason: 'the mainline is white: $main');
    expect(c.overlay, overlay, reason: 'the user\'s overlay is as it was');
    // without results, colours by pressure say so
    final p = await run(tester, 'view_snapshot', {'region': 'drawing', 'colour_by': 'pressure'});
    expect(p.text, contains('no design results now'));
    await expectLater(() => run(tester, 'view_snapshot', {'colour_by': 'rainbow'}), throwsA(isA<ToolInputError>()));
  });

  testWidgets('marks issues: the design messages at their items, numbered as get_design_messages', (tester) async {
    twoZones();
    // a zone pipe no valve reaches: unconnected
    c.addEntity(PipeEntity(id: 'loose', points: const [Pt(20, 15), Pt(30, 15)], scope: HydraulicScope.zone));
    final adv = c.advice;
    final k = adv.indexWhere((a) => a.entityIds.contains('loose'));
    expect(k, greaterThanOrEqualTo(0), reason: 'the design check reports the loose pipe');
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-50, -10, 50, 40],
      'marks': ['issues'],
    });
    expect(out.text, contains('Marks (messages, numbered as get_design_messages)'));
    expect(out.text, contains('#$k ${adv[k].level.name} [${adv[k].code}]'));
    final line = out.text.split('\n').firstWhere((l) => l.startsWith('#$k '));
    final px = RegExp(r'px \((\d+), (\d+)\)').firstMatch(line)!;
    final m = VisionSession.of(box)['s1']!;
    final at = m.toWorld(double.parse(px.group(1)!), double.parse(px.group(2)!));
    expect(at.distanceTo(const Pt(25, 15)), lessThan(6), reason: 'the mark points at the loose pipe: $at');
    expect(messagesText(box), contains('#$k '), reason: 'the same number in get_design_messages');
  });

  testWidgets('marks changes: what the assistant added, changed and removed in its task, readable after it ended', (tester) async {
    c.addEntities([LineEntity(id: 'keep', a: const Pt(0, 0), b: const Pt(50, 0)), LineEntity(id: 'gone', a: const Pt(0, 10), b: const Pt(50, 10))]);
    final none = await run(tester, 'view_snapshot', {
      'region': 'drawing',
      'marks': ['changes'],
    });
    expect(none.text, contains('you have changed nothing in this task yet'));
    box.change('test', () {
      final p = c.project;
      p.entities.add(LineEntity(id: 'new', a: const Pt(0, 20), b: const Pt(50, 20)));
      (p.byId('keep')! as LineEntity).b = const Pt(50, 4);
      p.entities.removeWhere((e) => e.id == 'gone');
      return true;
    });
    final out = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-10, -10, 60, 30],
      'marks': ['changes'],
      'grid': 'none',
    });
    expect(out.text, contains('Changes since your first change of this task: 1 added, 1 changed, 1 removed'));
    expect(out.text, contains('1 added (cyan halo), 1 changed (amber halo), 1 removed (dashed red outline'));
    final id = RegExp(r'Picture (s\d+)').firstMatch(out.text)!.group(1)!;
    final im = decode(out.images.single);
    final added = colourAt(im, id, const Pt(25, 20));
    expect(added[2] > 150 && added[1] > 150 && added[0] < 140, isTrue, reason: 'cyan along the new line: $added');
    final changed = colourAt(im, id, const Pt(25, 2));
    expect(changed[0] > 160 && changed[2] < 120, isTrue, reason: 'amber along the changed line: $changed');
    var red = false;
    for (var x = 2.0; x < 48 && !red; x += 0.5) {
      final px = colourAt(im, id, Pt(x, 10));
      red = px[0] > 180 && px[1] < 90 && px[2] < 110;
    }
    expect(red, isTrue, reason: 'a dashed red outline where the removed line was');
    // once the task ends its changes stay readable; the next change starts anew
    box.changes.endTask();
    final after = await run(tester, 'view_snapshot', {
      'region': 'drawing',
      'marks': ['changes'],
    });
    expect(after.text, contains('since the start of your last task that changed the drawing'));
    box.change('test', () {
      c.project.entities.add(LineEntity(id: 'next', a: const Pt(0, 30), b: const Pt(10, 30)));
      return true;
    });
    final next = await run(tester, 'view_snapshot', {
      'region': 'drawing',
      'marks': ['changes'],
    });
    expect(next.text, contains('Changes since your first change of this task: 1 added;'));
  });

  testWidgets('the picture after a round of changes is framed on them and marks them; nothing changed, no picture', (tester) async {
    c.addEntity(LineEntity(id: 'long', a: const Pt(-500, 0), b: const Pt(500, 0)));
    box.change('test', () {
      c.project.entities.add(LineEntity(id: 'small', a: const Pt(300, 300), b: const Pt(310, 300)));
      return true;
    });
    ToolImage? pic;
    await tester.runAsync(() async => pic = await feedbackPicture(box));
    expect(pic, isNotNull);
    final text = lastFeedbackMapping(box)!;
    expect(text, contains('Framed on what this round changed; the whole drawing spans'));
    expect(text, contains('Changes in this round of tools: 1 added'));
    final m = VisionSession.of(box).ids.map((id) => VisionSession.of(box)[id]!).last;
    expect(m.world.width, lessThan(100), reason: 'about the change, not the 1 km drawing');
    expect(m.world.contains(const Pt(305, 300)), isTrue);
    // the round ends: nothing new to show
    box.changes.endRound();
    await tester.runAsync(() async => pic = await feedbackPicture(box));
    expect(pic, isNull);
    // only settings changed: no picture either
    box.change('test', () {
      c.project.params.maxZoneVelocity = 1.4;
      return true;
    });
    await tester.runAsync(() async => pic = await feedbackPicture(box));
    expect(pic, isNull);
  });

  testWidgets('image_to_world snaps picked points to item ends and lines so new pipes meet the old ones', (tester) async {
    c.addEntity(PipeEntity(id: 'p1', points: const [Pt(0, 0), Pt(20, 0)], scope: HydraulicScope.mainline));
    final shot = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-10, -10, 30, 10],
    });
    final id = RegExp(r'Picture (s\d+)').firstMatch(shot.text)!.group(1)!;
    final m = VisionSession.of(box)[id]!;
    final px = [
      for (final q in const [Pt(20.3, 0.2), Pt(10, 0.4), Pt(10, 8)]) [m.toPixel(q).$1, m.toPixel(q).$2],
    ];
    final out = await run(tester, 'image_to_world', {'snapshot': id, 'pixels': px, 'snap': true});
    expect(out.text, contains('#1 to the pipe p1 end [20.00, 0.00]'));
    expect(out.text, contains('#2 onto the pipe p1 line (segment 1) at [10.00, 0.00]'));
    expect(out.text, isNot(contains('#3 ')), reason: 'nothing near the third point');
    final pts = jsonDecode(RegExp(r'World points \[x, y\] in m: (\[.*\])').firstMatch(out.text)!.group(1)!) as List;
    expect(pts[0], [20, 0]);
    expect(pts[1], [10, 0]);
    expect((pts[2] as List)[1], closeTo(8, 0.1));
    // without snap the points stay as picked
    final plain = await run(tester, 'image_to_world', {'snapshot': id, 'pixels': px});
    expect(plain.text, isNot(contains('Snapped')));
  });

  testWidgets('a picture drawn before the georeference changed is refused', (tester) async {
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-22.5, -47.5);
    final shot = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [0, 0, 50, 50],
      'base_map': 'none',
    });
    final id = RegExp(r'Picture (s\d+)').firstMatch(shot.text)!.group(1)!;
    await run(tester, 'image_to_world', {
      'snapshot': id,
      'pixels': [
        [10, 10],
      ],
    });
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-22.6, -47.5);
    await expectLater(
      () => run(tester, 'image_to_world', {
        'snapshot': id,
        'pixels': [
          [10, 10],
        ],
      }),
      throwsA(isA<ToolInputError>().having((e) => e.message, 'message', contains('before the georeference changed'))),
    );
  });

  testWidgets('trace_region outlines a field on the aerial image from one point, without changing the project', (tester) async {
    await expectLater(
      () => run(tester, 'trace_region', {
        'at': [0, 0],
      }),
      throwsA(isA<ToolInputError>()),
      reason: 'no georeference',
    );
    final g = GeoReference.fromLatLonOrigin(-22.5, -47.5);
    c.project.meta.georef = g;
    const field = Bounds(-50, -40, 70, 30); // 120 × 70 m = 8400 m²
    final tiles = _FieldTiles(g, field);
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
    final before = c.historyIndex;
    final out = await run(tester, 'trace_region', {
      'at': [10, -5],
    });
    expect(out.images, hasLength(1), reason: 'a picture with the outline');
    expect(out.text, contains('R1 outline:'));
    expect(out.text, contains('found where the region stopped growing at its boundary'));
    final r1 = out.text.split('\n').firstWhere((l) => l.startsWith('R1 outline:'));
    final pts = [for (final q in jsonDecode(r1.substring(r1.indexOf('pts ') + 4, r1.indexOf(']] (') + 2)) as List) Pt(((q as List)[0] as num).toDouble(), (q[1] as num).toDouble())];
    final area = polygonArea(pts);
    expect(area, greaterThan(0), reason: 'counter-clockwise');
    expect(area, closeTo(8400, 0.05 * 8400));
    final bb = Bounds.ofPoints(pts);
    expect(bb.minX, closeTo(-50, 2.5));
    expect(bb.maxX, closeTo(70, 2.5));
    expect(bb.minY, closeTo(-40, 2.5));
    expect(bb.maxY, closeTo(30, 2.5));
    expect(c.historyIndex, before, reason: 'no side effects');
    expect(c.project.entities, isEmpty);
    expect(
      tool('trace_region').describe({
        'at': [10, -5],
      }),
      c.t('ai.vis.trace'),
    );
    // from a pixel of an earlier picture, the same field
    final shot = await run(tester, 'view_snapshot', {
      'region': 'bbox',
      'bbox': [-100, -100, 100, 100],
    });
    final id = RegExp(r'Picture (s\d+)').firstMatch(shot.text)!.group(1)!;
    final (px, py) = VisionSession.of(box)[id]!.toPixel(const Pt(-20, 10));
    final again = await run(tester, 'trace_region', {
      'snapshot': id,
      'pixel': [px, py],
    });
    expect(again.text, contains('R1 outline:'));
    expect(again.text, contains('from [-20.0'));
  });

  testWidgets('trace_fields outlines every field of the area at once and leaves the soil cut by the edge out', (tester) async {
    final g = GeoReference.fromLatLonOrigin(-22.5, -47.5);
    c.project.meta.georef = g;
    const field = Bounds(-50, -40, 70, 30); // 120 × 70 m = 8400 m²
    box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _FieldTiles(g, field)));
    final out = await run(tester, 'trace_fields', {
      'region': 'bbox',
      'bbox': [-150, -150, 150, 150],
    });
    expect(out.images, hasLength(1));
    expect(out.text, contains('1 region kept'));
    expect(out.text, contains('cut by the edge of the area'));
    final f1 = out.text.split('\n').firstWhere((l) => l.startsWith('F1:'));

    final pts = [for (final q in jsonDecode(f1.substring(f1.indexOf('pts ') + 4)) as List) Pt(((q as List)[0] as num).toDouble(), (q[1] as num).toDouble())];
    final fb = Bounds.ofPoints(pts);
    expect(fb.minX, closeTo(-50, 1));
    expect(fb.maxX, closeTo(70, 1));
    expect(polygonArea(pts), closeTo(8400, 0.05 * 8400));
    expect(c.project.entities, isEmpty, reason: 'no side effects');
    expect(tool('trace_fields').describe({}), c.t('ai.vis.traceAll'));
    await expectLater(
      () => run(tester, 'trace_fields', {
        'region': 'bbox',
        'bbox': [0, 0, 5000, 5000],
      }),
      throwsA(isA<ToolInputError>()),
      reason: 'larger than 3 km',
    );
  });
}
