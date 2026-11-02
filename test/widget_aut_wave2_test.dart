import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/vision_render.dart';
import 'package:opencadirrigation/app/ai/vision_tiles.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/app/tools/trace_image_tool.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/advice_panel.dart';
import 'package:opencadirrigation/app/widgets/dialogs/auto_design_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/main.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Map tiles drawn from the world: a field of crop rows inside [field]
/// (project metres) on bare soil, for the projection of [g].
class _FieldTiles extends TileFetcher {
  _FieldTiles(this.g, this.field);
  final GeoReference g;
  final Bounds field;
  final _cache = <String, Uint8List>{};

  @override
  Future<Uint8List> bytes(String url) async {
    final m = RegExp(r'/(\d+)/(\d+)/(\d+)').firstMatch(url)!;
    final z = int.parse(m.group(1)!), ty = int.parse(m.group(2)!), tx = int.parse(m.group(3)!);
    return _cache.putIfAbsent(url, () {
      final im = img.Image(width: 256, height: 256);
      final rnd = math.Random(tx * 31 + ty);
      Pt at(double u, double v) {
        final n = math.pow(2.0, z);
        final lon = (tx + u) / n * 360 - 180;
        final s = math.pi * (1 - 2 * (ty + v) / n);
        final lat = math.atan((math.exp(s) - math.exp(-s)) / 2) * 180 / math.pi;
        final (x, y) = g.fromLatLon(lat, lon);
        return Pt(x, y);
      }

      final p00 = at(0, 0), p10 = at(1, 0), p01 = at(0, 1);
      for (var j = 0; j < 256; j++) {
        for (var i = 0; i < 256; i++) {
          final q = p00 + (p10 - p00) * ((i + 0.5) / 256) + (p01 - p00) * ((j + 0.5) / 256);
          final inField = field.contains(q);
          final rows = (q.x / 1.5).floor().isEven;
          final (r, gg, b) = inField ? (rows ? (60, 140, 50) : (44, 112, 38)) : (132, 102, 72);
          final k = rnd.nextInt(17) - 8;
          im.setPixelRgb(i, j, (r + k).clamp(0, 255), (gg + k).clamp(0, 255), (b + k).clamp(0, 255));
        }
      }
      return img.encodePng(im);
    });
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404);
}

class _Host implements ToolHost {
  final status = <String>[];
  @override
  void setStatus(String text) => status.add(text);
  @override
  void showBlockDialog(List<Pt> polygon) {}
  @override
  void showAutoheadDialog(List<Pt> polygon) {}
  @override
  void showTextDialog(Pt position) {}
  @override
  void showLeaderDialog(List<Pt> points) {}
  @override
  void showCommentDialog(Pt position) {}
  @override
  void showRevisionDialog(List<Pt> polygon) {}
  @override
  void promptElevation(Entity e) {}
}

/// The functions added in 1.6.0 (wave 2) for automatic design in the app:
/// the warning for an area that crosses itself, the computed longest
/// lateral in the block and subdivision dialogs, the review item by item of
/// "fix automatically", the outline traced on the satellite image without
/// the AI (and the assistant's operations for all of them).
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  /// Pumps frames until [done] (the in-thread design runs between frames).
  Future<void> until(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'condition not reached');
    await settle(tester, 2);
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  testWidgets('AUT-05: an area drawn or edited crossing itself is said at once', (tester) async {
    final c = await pumpShell(tester);
    final bow = AreaEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)], name: 'Gravata');
    c.addEntity(bow);
    expect(c.lastMessage, contains('Gravata'));
    expect(c.lastMessage, contains('cruza a si mesmo'));
    final square = AreaEntity(id: c.project.newId(), points: _rect(20, 0, 30, 10), name: 'Quadrado');
    final seq = c.messageSeq;
    c.addEntity(square);
    expect(c.messageSeq, seq, reason: 'a simple area says nothing');
    // a grip dragged across another side
    c.setGrip(square.id, 2, const Pt(10, 5));
    expect(c.lastMessage, contains('Quadrado'));
    await settle(tester);
  });

  testWidgets('B and SUBDIV: the longest lateral the tape, the slope and the variation allow; SUBDIV takes it', (tester) async {
    final c = await pumpShell(tester);
    showBlockDialog(ctxOf(tester), c, _rect(0, 0, 200, 50));
    await settle(tester);
    await tester.tap(find.text('Gotejamento (fita/tubo)'));
    await settle(tester);
    final view = find.byKey(const Key('latmax'));
    await tester.ensureVisible(view);
    await settle(tester);
    expect(view, findsOneWidget);
    expect(find.textContaining('Lateral máxima (em nível)'), findsOneWidget, reason: 'no terrain: level');
    expect(find.textContaining('Lateral mais longa do desenho'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    // the subdivision of a field fills its maximum lateral length with it
    final field = AreaEntity(id: c.project.newId(), points: _rect(0, 0, 300, 120), name: 'Talhão');
    c.addEntities([field]);
    c.select([field.id]);
    await settle(tester);
    showFieldSubdivisionDialog(ctxOf(tester), c);
    await settle(tester);
    final use = find.byKey(const Key('latmax_use'));
    await tester.ensureVisible(use);
    await settle(tester);
    TextField maxField() => tester.widget<TextField>(find.descendant(of: find.byKey(const Key('fs_max_lateral')), matching: find.byType(TextField)));
    expect(maxField().controller!.text, '0');
    await tester.tap(use);
    await settle(tester);
    final typed = double.parse(maxField().controller!.text.replaceAll(',', '.'));
    expect(typed, greaterThan(10));
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
  });

  testWidgets('FIX: the review keeps only the corrections ticked, in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final p = c.project;
    p.params.connectTolerance = 0.05;
    c.addEntities([
      WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0), calculatePressure: true),
      PipeEntity(id: p.newId(), points: [const Pt(-20, 0), const Pt(0, 0)], scope: HydraulicScope.mainline),
      ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'A', valveSpecId: 'ev25'),
      PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone),
      OutletEntity(id: p.newId(), position: const Pt(30, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: 'A'),
      // a head off its pipe and a pipe of no length
      OutletEntity(id: p.newId(), position: const Pt(15, 1.8), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: 'A'),
      PipeEntity(id: p.newId(), points: [const Pt(500, 500), const Pt(500, 500)], scope: HydraulicScope.mainline),
    ]);
    await settle(tester);
    final step = c.historyIndex;
    showAutoFixDialog(ctxOf(tester), c);
    await tester.pump();
    await until(tester, () => find.text('Correção automática').evaluate().isNotEmpty);
    expect(find.byKey(const Key('autofix_step_0')), findsOneWidget);
    expect(find.byKey(const Key('autofix_step_1')), findsOneWidget);
    final steps = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('autofix_step_')).evaluate().length;
    expect(find.byKey(const Key('autofix_keep')), findsNothing, reason: 'all ticked: the dialog just closes');
    await tester.tap(find.descendant(of: find.byKey(const Key('autofix_step_1')), matching: find.byType(Checkbox)));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('autofix_keep')));
    await tester.pump();
    await until(tester, () => (c.lastMessage ?? '').contains('mantida(s)'));
    expect(c.lastMessage, contains('${steps - 1} correção(ões) mantida(s), 1 deixada(s) de fora'));
    expect(c.historyIndex, step + 1, reason: 'one undo step');
  });

  testWidgets('OPT: the review keeps only the changes ticked, made again and designed in one undo step', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, startExample: ExampleId.orchard));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    // a greedy sizing and pipes fixed by hand: the optimisation changes both
    c.project.params.sizingMethod = SizingMethod.greedy;
    for (final e in c.project.entities.whereType<PipeEntity>()) {
      e.computerSized = false;
    }
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    final step = c.historyIndex;
    showOptimizeDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('opt_resize_all')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('opt_run')));
    await tester.pump();
    await until(tester, () => find.byKey(const Key('optimize_summary')).evaluate().isNotEmpty);
    expect(find.byKey(const Key('optimize_change_0')), findsOneWidget);
    expect(find.byKey(const Key('optimize_change_1')), findsOneWidget);
    expect(find.byKey(const Key('optimize_keep')), findsNothing);
    final changes = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('optimize_change_')).evaluate().length;
    await tester.tap(find.descendant(of: find.byKey(const Key('optimize_change_0')), matching: find.byType(Checkbox)));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('optimize_keep')));
    await tester.pump();
    await until(tester, () => (c.lastMessage ?? '').contains('mudança(s) mantida(s)'));
    expect(c.lastMessage, contains('${changes - 1} mudança(s) mantida(s), 1 deixada(s) de fora'));
    expect(c.historyIndex, step + 1, reason: 'one undo step');
    expect(c.results, isNotNull, reason: 'designed again');
  });

  group('PRD-05 the outline traced on the satellite image', () {
    late ProjectController c;
    final g = GeoReference.fromLatLonOrigin(-22.5, -47.5);
    const field = Bounds(-50, -40, 70, 30); // 120 × 70 m = 8400 m²
    setUp(() async {
      LocalProjectStore().clearAll();
      c = ProjectController()
        ..autosaveEnabled = false
        ..designRunner = InThreadDesignRunner();
      c.newProject();
      await c.setLanguage('pt', persist: false);
      c.project.meta.georef = g;
      c.camera
        ..size = const Size(800, 600)
        ..center = const Pt(10, -5)
        ..scale = 2;
      TraceImageSession.renderer = CanvasSnapshots(tiles: _FieldTiles(g, field));
    });
    tearDown(() => TraceImageSession.renderer = const CanvasSnapshots());

    testWidgets('a click inside the field traces it; Enter makes the area, one undo step; Esc drops it', (tester) async {
      final tool = createTool(ToolId.traceImage, c, _Host());
      expect(tool, isA<TraceImageTool>());
      final s = TraceImageSession.of(c);
      await tester.runAsync(() async {
        tool.onDown(const Pt(10, -5));
        for (var i = 0; i < 500 && (s.busy || s.preview == null); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(s.preview, isNotNull, reason: c.lastMessage);
      expect(s.preview!.area, closeTo(8400, 0.06 * 8400));
      expect(c.lastMessage, contains('Contorno:'));
      expect(tool.idle, isFalse, reason: 'Esc first drops the preview');
      // another tolerance traces again from the same pixels
      expect(tool.onInput('20'), isTrue);
      expect(s.tolerance, 20);
      expect(s.preview, isNotNull);
      final step = c.historyIndex;
      tool.onKey('Enter');
      final made = c.project.entities.whereType<AreaEntity>().single;
      expect(polygonArea(made.points).abs(), closeTo(8400, 0.08 * 8400));
      expect(c.historyIndex, step + 1);
      expect(s.hasPreview, isFalse);
      c.undo();
      expect(c.project.entities.whereType<AreaEntity>(), isEmpty);
      // a polyline when asked, and Esc drops what is on show
      expect(tool.onInput('P'), isTrue);
      expect(s.output, TraceOutput.polyline);
      await tester.runAsync(() async {
        tool.onDown(const Pt(-20, 10));
        for (var i = 0; i < 500 && (s.busy || s.preview == null); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(s.preview, isNotNull);
      tool.onKey('Escape');
      expect(s.hasPreview, isFalse);
      expect(tool.idle, isFalse, reason: 'this Esc dropped the outline: the next one leaves the tool');
      tool.onKey('Escape');
      expect(tool.idle, isTrue);
      expect(c.project.entities, isEmpty);
    });

    testWidgets('without a georeference it says what to do', (tester) async {
      c.project.meta.georef = null;
      await tester.runAsync(() => TraceImageSession.of(c).traceAt(c, const Pt(0, 0)));
      expect(TraceImageSession.of(c).preview, isNull);
      expect(c.lastMessage, contains('georreferência'));
    });

    testWidgets('the assistant: outline_from_image adds the field as an area at once', (tester) async {
      final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _FieldTiles(g, field)));
      final op = box.operations.firstWhere((o) => o.name == 'outline_from_image');
      expect(op.effectOf(const {}), ToolEffect.write);
      ToolOutput? out;
      await tester.runAsync(() async {
        out = await op.run({
          'at': [10, -5],
          'name': 'Talhão 1',
        });
      });
      expect(out!.text, contains('Added area'));
      final a = c.project.entities.whereType<AreaEntity>().single;
      expect(a.name, 'Talhão 1');
      expect(polygonArea(a.points).abs(), closeTo(8400, 0.06 * 8400));
    });
  });

  testWidgets('the assistant: the longest lateral, the trench depths and the review of "fix automatically"', (tester) async {
    LocalProjectStore().clearAll();
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    final box = AgentToolbox(c);
    AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);
    final tape = c.project.catalog.tapes.first;
    final lat = await op('max_lateral_length').run({'tape': tape.id, 'slope_pct': 1});
    expect(lat.text, contains('Longest lateral fed uphill'));
    expect(lat.text, contains('Longest lateral fed downhill'));
    final depths = await op('set_trench_depths').run({'zone_depth_m': 0.35});
    expect(depths.text, contains('zone pipes 0.35 m'));
    expect(c.project.proposal.zoneDepthM, 0.35);
    // the preview of "fix automatically" leaves the project as it was
    final p = c.project;
    p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(500, 500), const Pt(500, 500)], scope: HydraulicScope.mainline));
    c.entitiesChanged();
    final count = p.entities.length;
    Future<ToolOutput>? running;
    ToolOutput? preview;
    running = op('preview_auto_fix').run(const {});
    running.then((v) => preview = v);
    for (var i = 0; i < 2000 && preview == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(preview, isNotNull);
    expect(preview!.text, contains('corrections'));
    expect(c.project.entities, hasLength(count), reason: 'put back as it was');
    final id = RegExp(r'^- (\S+): ', multiLine: true).firstMatch(preview!.text)!.group(1)!;
    ToolOutput? applied;
    op('auto_fix_selected')
        .run({
          'keep': [id],
        })
        .then((v) => applied = v);
    for (var i = 0; i < 2000 && applied == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(applied!.text, contains('Made 1'));
    expect(c.project.entities, hasLength(count - 1), reason: 'the pipe of no length is gone');
  });
}
