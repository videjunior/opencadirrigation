import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/ai/vision_render.dart';
import 'package:opencadirrigation/app/ai/vision_tiles.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tools/ai_mark_tool.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_marks_bar.dart';
import 'package:opencadirrigation/core/ai/project_context.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Aerial tiles without a network: every tile the dark green of a crop.
class _GreenTiles extends TileFetcher {
  final png = img.encodePng(img.fill(img.Image(width: 256, height: 256), color: img.ColorRgb8(46, 84, 38)));

  @override
  Future<Uint8List> bytes(String url) async => png;

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404);
}

/// What the mark tool tells the widget layer: only the status line.
class _Host implements ToolHost {
  String status = '';

  @override
  void setStatus(String text) => status = text;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

bool _orange(int r, int g, int b) => r > 200 && g > 60 && g < 160 && b < 70;

/// Orange seen through: a translucent preview over the canvas.
bool _orangish(int r, int g, int b) => r > 120 && r > g + 40 && g > b + 15 && b < 90;

/// The marks for the AI assistant on the drawing: the point and line tools
/// (clicks and taps, Enter, Esc, double clicks, Backspace), marks that are
/// no project items and leave no undo step, the painter drawing them on
/// both canvas themes and in the assistant's pictures (over the canvas and
/// an aerial map), the line being marked, the repaint when they change, the
/// marks bar of the assistant's panel, the phone's sheet closed while
/// marking, and the marks in the assistant's next message.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  tearDown(() {
    AiAssistant.dockable = false;
    AiAssistant.panelOpen.value = false;
    AiAssistant.clearSessionKey();
  });

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    c.snap.enabled = false;
    c.camera
      ..center = const Pt(20, 10)
      ..scale = 10;
    await settle(tester);
    return c;
  }

  Future<ProjectController> plainController() async {
    LocalProjectStore().clearAll();
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    return c;
  }

  Offset screenOf(WidgetTester tester, ProjectController c, Pt world) {
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    return box.localToGlobal(c.camera.toScreen(world));
  }

  Future<void> clickWorld(WidgetTester tester, ProjectController c, Pt world) async {
    await tester.tapAt(screenOf(tester, c, world));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Two quick clicks at [world] (the canvas takes the second as a double click).
  Future<void> doubleClickWorld(WidgetTester tester, ProjectController c, Pt world, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    final at = screenOf(tester, c, world);
    await tester.tapAt(at, kind: kind);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at, kind: kind);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }

  testWidgets('point marks: one at each click or tap and the tool stays; no project item, no undo step; Esc leaves, Enter repeats the drawing tool', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.polyline);
    c.setTool(ToolId.aiMarkPoint);
    await settle(tester, 1);
    expect(find.textContaining('Click each place to show the AI assistant'), findsWidgets, reason: 'the hint of the tool');
    final project = jsonEncode(c.project.toJson());
    final undo = c.historyIndex, dirty = c.dirty;
    await clickWorld(tester, c, const Pt(0, 0));
    await clickWorld(tester, c, const Pt(12, 6));
    expect([for (final m in c.aiMarks.marks) m.label], ['A', 'B']);
    expect(c.aiMarks.marks.every((m) => m.isPoint), isTrue);
    expect(c.aiMarks.marks[0].points.single.distanceTo(Pt.zero), lessThan(1e-6));
    expect(c.aiMarks.marks[1].points.single.distanceTo(const Pt(12, 6)), lessThan(1e-6));
    expect(c.activeTool, ToolId.aiMarkPoint, reason: 'the tool stays for more');
    // a mouse double click marks one point, not two
    await doubleClickWorld(tester, c, const Pt(30, 0), kind: PointerDeviceKind.mouse);
    expect(c.aiMarks.marks.length, 3);
    expect(c.project.entities, isEmpty, reason: 'marks are no project items');
    expect(jsonEncode(c.project.toJson()), project, reason: 'nothing of them goes into the project');
    expect(c.historyIndex, undo, reason: 'no undo step');
    expect(c.dirty, dirty);
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool, ToolId.select);
    expect(c.aiMarks.marks.length, 3, reason: 'leaving the tool keeps the marks');
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.activeTool, ToolId.polyline, reason: 'Enter repeats the last drawing tool, as before the marking');
    await key(tester, LogicalKeyboardKey.escape);
  });

  testWidgets('line marks: clicks add vertices, Enter or a double click ends the line as one mark; Esc drops the line, Esc again leaves', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.aiMarkLine);
    await settle(tester, 1);
    final project = jsonEncode(c.project.toJson());
    for (final p in const [Pt(0, 0), Pt(10, 0), Pt(10, 10)]) {
      await clickWorld(tester, c, p);
    }
    expect(c.aiMarks.isEmpty, isTrue, reason: 'the line is not ended yet');
    expect(c.keyTarget!.toolIdle, isFalse);
    expect(c.keyTarget!.referencePoint!.distanceTo(const Pt(10, 10)), lessThan(1e-6), reason: 'snapping and typed points go from the last vertex');
    await key(tester, LogicalKeyboardKey.enter);
    final a = c.aiMarks.marks.single;
    expect((a.label, a.points.length, a.isPoint), ('A', 3, false));
    expect(c.activeTool, ToolId.aiMarkLine, reason: 'ready for the next line');
    // a double tap ends the next one, its first tap being the last vertex
    await clickWorld(tester, c, const Pt(20, 0));
    await doubleClickWorld(tester, c, const Pt(30, 5));
    final b = c.aiMarks.marks.last;
    expect((b.label, b.points.length), ('B', 2));
    expect(b.points.last.distanceTo(const Pt(30, 5)), lessThan(1e-6));
    // Backspace takes the last vertex back
    for (final p in const [Pt(0, 20), Pt(8, 20), Pt(8, 28)]) {
      await clickWorld(tester, c, p);
    }
    await key(tester, LogicalKeyboardKey.backspace);
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.aiMarks.marks.last.points, hasLength(2));
    // Esc drops the line in progress and keeps the tool; Esc again leaves it
    await clickWorld(tester, c, const Pt(40, 0));
    await clickWorld(tester, c, const Pt(40, 10));
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.aiMarks.marks, hasLength(3));
    expect(c.activeTool, ToolId.aiMarkLine);
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool, ToolId.select);
    // one vertex and Enter mark a point; Enter with nothing in progress
    // leaves the tool (Done on a phone)
    c.setTool(ToolId.aiMarkLine);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(50, 0));
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.aiMarks.marks.last.isPoint, isTrue);
    expect(c.activeTool, ToolId.aiMarkLine);
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.activeTool, ToolId.select);
    expect(c.aiMarks.marks, hasLength(4));
    // another tool chosen in the middle of a line: the line is dropped and
    // the new tool works as ever (one Esc leaves the idle polyline tool)
    c.setTool(ToolId.aiMarkLine);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(0, 30));
    await clickWorld(tester, c, const Pt(10, 30));
    c.setTool(ToolId.polyline);
    await settle(tester, 1);
    expect(c.aiMarks.marks, hasLength(4));
    expect(c.keyTarget!.toolIdle, isTrue);
    expect(c.keyTarget!.referencePoint, isNull);
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool, ToolId.select);
    expect(jsonEncode(c.project.toJson()), project, reason: 'the project is untouched');
    expect(c.canUndo, isFalse, reason: 'no undo step');
  });

  testWidgets('marks snap as the drawing tools do', (tester) async {
    final c = await pumpShell(tester);
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    c.snap.enabled = true;
    c.setTool(ToolId.aiMarkPoint);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(10.4, 0.3));
    expect(c.aiMarks.marks.single.points.single, const Pt(10, 0), reason: 'onto the end of the line');
    c.setTool(ToolId.aiMarkLine);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(0.3, -0.4));
    await clickWorld(tester, c, const Pt(9.7, 0.4));
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.aiMarks.marks.last.points, [Pt.zero, const Pt(10, 0)]);
    await key(tester, LogicalKeyboardKey.escape);
  });

  testWidgets('the canvas repaints when the marks change, without an edit of the project', (tester) async {
    final c = await pumpShell(tester);
    final paint = tester.renderObjectList<RenderCustomPaint>(find.descendant(of: find.byType(CadCanvas), matching: find.byType(CustomPaint))).where((r) => r.painter is CadPainter).single;
    await settle(tester, 1);
    expect(paint.debugNeedsPaint, isFalse);
    c.aiMarks.add([const Pt(1, 1)]);
    expect(paint.debugNeedsPaint, isTrue, reason: 'a new mark');
    await tester.pump();
    c.aiMarks.setNote('A', 'well');
    expect(paint.debugNeedsPaint, isTrue, reason: 'a new note');
    await tester.pump();
    c.aiMarks.clear();
    expect(paint.debugNeedsPaint, isTrue, reason: 'marks cleared');
    await tester.pump();
  });

  testWidgets('the painter draws the marks in orange over the dark and the light canvas, and the line being marked', (tester) async {
    final c = await plainController();
    const w = 400, h = 300;
    c.camera
      ..center = const Pt(20, 10)
      ..scale = 10;
    Future<ByteData> render({Tool? tool, CadPalette palette = CadPalette.dark}) async {
      ByteData? data;
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        Cad.paintWith(palette, () => CadPainter(c: c, tool: tool, snapResult: null, repaint: c).paint(Canvas(rec), const Size(400, 300)));
        final image = await rec.endRecording().toImage(w, h);
        data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
      });
      return data!;
    }

    int orangeNear(ByteData d, Offset o, [int r = 2, bool Function(int r, int g, int b) test = _orange]) {
      var n = 0;
      for (var y = o.dy.round() - r; y <= o.dy.round() + r; y++) {
        for (var x = o.dx.round() - r; x <= o.dx.round() + r; x++) {
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          final i = (y * w + x) * 4;
          if (test(d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2))) n++;
        }
      }
      return n;
    }

    // A at (10, 10) is at (100, 150) px, its pin's head 19 px above; B runs
    // along y = 0 (250 px) from x = 0 to 300 px
    c.aiMarks.add([const Pt(10, 10)], note: 'pump');
    c.aiMarks.add([const Pt(0, 0), const Pt(30, 0)]);
    for (final palette in [CadPalette.dark, CadPalette.light]) {
      final d = await render(palette: palette);
      final theme = palette.brightness.name;
      expect(orangeNear(d, const Offset(100, 126)), greaterThan(10), reason: 'the pin of A ($theme)');
      expect(orangeNear(d, const Offset(112, 131), 1), greaterThan(4), reason: 'the tag of A ($theme)');
      expect(orangeNear(d, const Offset(150, 250)), greaterThan(10), reason: 'the line B ($theme)');
      expect(orangeNear(d, const Offset(200, 50), 6), 0, reason: 'nothing orange elsewhere ($theme)');
    }
    // the line being marked: its vertices so far, then the dashed segment to the cursor
    final host = _Host();
    final tool = createTool(ToolId.aiMarkLine, c, host) as AiMarkTool;
    tool
      ..onDown(const Pt(0, 20))
      ..onDown(const Pt(30, 20))
      ..onMove(const Pt(30, 5));
    final d = await render(tool: tool);
    expect(orangeNear(d, const Offset(150, 50)), greaterThan(10), reason: 'the line so far (y = 20 m: 50 px)');
    var dashes = 0;
    for (var y = 60; y < 195; y++) {
      if (orangeNear(d, Offset(300, y.toDouble()), 0) > 0) dashes++;
    }
    expect(dashes, inInclusiveRange(30, 125), reason: 'the dashed segment to the cursor');
    expect(host.status, contains('L = 45.00'), reason: 'the length so far, as the polyline tool shows it');
    // the point tool shows the pin it would place under the cursor (30, 15 m:
    // 300, 100 px), see-through, except over the pin it has just placed
    final pin = createTool(ToolId.aiMarkPoint, c, host)..onMove(const Pt(30, 15));
    final p = await render(tool: pin);
    expect(orangeNear(p, const Offset(300, 76), 2, _orangish), greaterThan(10), reason: 'the pin under the cursor');
    expect(orangeNear(p, const Offset(300, 76)), 0, reason: 'see-through');
    expect(c.aiMarks.marks, hasLength(2), reason: 'a preview marks nothing');
    pin.onDown(const Pt(30, 15));
    final placed = await render(tool: pin);
    expect(orangeNear(placed, const Offset(300, 76)), greaterThan(10), reason: 'the pin placed, with no see-through one over it');
    // a mark at the edge of the view keeps its tag whole in it: left of the
    // pin's head (395, 131 px) instead of right
    c.aiMarks.add([const Pt(39.5, 10)]);
    final edge = await render();
    expect(orangeNear(edge, const Offset(382, 131), 1), greaterThan(4), reason: 'the tag of a pin at the right edge');
  });

  testWidgets('the assistant\'s pictures show the marks in orange, over the drawing and over an aerial map', (tester) async {
    final c = await plainController();
    c.addEntity(LineEntity(id: c.project.newId(), a: const Pt(-50, -30), b: const Pt(50, 30)));
    // off the lines of the picture grid (every 10 m), which lie over the drawing
    final a = c.aiMarks.add([const Pt(-23, 13)], note: 'pump');
    c.aiMarks.add([const Pt(-43, -17), const Pt(-3, -17), const Pt(27, 23)]);
    Future<SnapshotImage> picture(VisionSpec spec, {TileFetcher tiles = const HttpTileFetcher()}) async {
      SnapshotImage? out;
      await tester.runAsync(() async => out = await CanvasSnapshots(tiles: tiles).render(c, spec));
      return out!;
    }

    void check(SnapshotImage pic, String what) {
      final im = img.decodePng(pic.png)!;
      final f = pic.frame;
      int orangeNear(Offset o, [int r = 2]) {
        var n = 0;
        for (var y = o.dy.round() - r; y <= o.dy.round() + r; y++) {
          for (var x = o.dx.round() - r; x <= o.dx.round() + r; x++) {
            if (x < 0 || y < 0 || x >= im.width || y >= im.height) continue;
            final px = im.getPixel(x, y);
            if (_orange(px.r.toInt(), px.g.toInt(), px.b.toInt())) n++;
          }
        }
        return n;
      }

      final at = f.toPx(a.points.single);
      expect(orangeNear(at + const Offset(0, -24)), greaterThan(10), reason: 'the pin of A ($what)');
      expect(orangeNear(at + const Offset(12, -19), 1), greaterThan(4), reason: 'the tag of A ($what)');
      expect(orangeNear(f.toPx(const Pt(-23, -17))), greaterThan(10), reason: 'the line B ($what)');
      expect(orangeNear(f.toPx(const Pt(9, -1))), greaterThan(10), reason: 'the second leg of B ($what)');
      expect(orangeNear(f.toPx(const Pt(45, -35)), 6), 0, reason: 'nothing orange elsewhere ($what)');
    }

    check(await picture(const VisionSpec(world: Bounds(-60, -40, 60, 40), maxSide: 800, grid: GridDensity.none)), 'drawing');
    c.setGeoreferenceAt(-21.8, -46.6);
    final aerial = await picture(
      const VisionSpec(world: Bounds(-60, -40, 60, 40), maxSide: 800, maps: [BaseMap.satellite]),
      tiles: _GreenTiles(),
    );
    expect(aerial.map, BaseMap.satellite);
    final ground = img.decodePng(aerial.png)!.getPixel(30, aerial.height - 60);
    expect(ground.g.toInt(), greaterThan(ground.r.toInt()), reason: 'the aerial map is under the drawing');
    check(aerial, 'aerial map');
  });

  testWidgets('the marks bar: its buttons start and stop the tools, a chip per mark, the note written in a dialog, a mark removed, all cleared; it fits a phone', (tester) async {
    final c = await plainController();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AiMarksBar(c: c),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Show the AI where: the marks go with your next message.'), findsOneWidget);
    expect(find.text('Mark a point'), findsOneWidget);
    expect(find.text('Mark a line'), findsOneWidget);
    Finder active(String button) => find.descendant(of: find.byKey(Key(button)), matching: find.byIcon(Icons.check));
    expect(active('ai_mark_point'), findsNothing);
    await tester.tap(find.byKey(const Key('ai_mark_point')));
    await tester.pump();
    expect(c.activeTool, ToolId.aiMarkPoint);
    expect(active('ai_mark_point'), findsOneWidget, reason: 'the active tool shows');
    await tester.tap(find.byKey(const Key('ai_mark_point')));
    await tester.pump();
    expect(c.activeTool, ToolId.select, reason: 'a second click stops marking');
    await tester.tap(find.byKey(const Key('ai_mark_line')));
    await tester.pump();
    expect(c.activeTool, ToolId.aiMarkLine);
    expect(active('ai_mark_line'), findsOneWidget);
    // a chip per mark, with Clear marks
    expect(find.byKey(const Key('ai_marks_clear')), findsNothing);
    c.aiMarks.add([const Pt(1, 2)]);
    c.aiMarks.add([Pt.zero, const Pt(5, 0)]);
    await tester.pump();
    expect(find.byKey(const Key('ai_mark_A')), findsOneWidget);
    expect(find.byKey(const Key('ai_mark_B')), findsOneWidget);
    expect(find.byKey(const Key('ai_marks_clear')), findsOneWidget);
    // the note, in a small dialog
    await tester.tap(find.byKey(const Key('ai_mark_A')));
    await settle(tester, 2);
    expect(find.text('Note on mark A'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai_mark_note_field')), '  pump  ');
    await tester.tap(find.byKey(const Key('ai_mark_note_ok')));
    await settle(tester, 2);
    expect(c.aiMarks.byLabel('A')!.note, 'pump');
    expect(find.descendant(of: find.byKey(const Key('ai_mark_A')), matching: find.text('pump')), findsOneWidget);
    // Cancel keeps it; Enter in the box writes it
    await tester.tap(find.byKey(const Key('ai_mark_A')));
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('ai_mark_note_field')), 'well');
    await tester.tap(find.text('Cancel'));
    await settle(tester, 2);
    expect(c.aiMarks.byLabel('A')!.note, 'pump');
    await tester.tap(find.byKey(const Key('ai_mark_B')));
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('ai_mark_note_field')), 'the mainline along the road, up to the shed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    expect(c.aiMarks.byLabel('B')!.note, 'the mainline along the road, up to the shed');
    expect(
      find.descendant(of: find.byKey(const Key('ai_mark_B')), matching: find.textContaining('…')),
      findsOneWidget,
      reason: 'a long note is shortened in its chip',
    );
    // × removes one mark, Clear marks the rest
    await tester.tap(find.descendant(of: find.byKey(const Key('ai_mark_B')), matching: find.byTooltip('Remove the mark')));
    await tester.pump();
    expect([for (final m in c.aiMarks.marks) m.label], ['A']);
    await tester.tap(find.byKey(const Key('ai_marks_clear')));
    await tester.pump();
    expect(c.aiMarks.isEmpty, isTrue);
    expect(find.byKey(const Key('ai_mark_A')), findsNothing);
    expect(find.byKey(const Key('ai_marks_clear')), findsNothing);
    expect(tester.takeException(), isNull, reason: 'it fits 360 px');
  });

  testWidgets('on a phone the assistant\'s sheet closes while marking, keeps the draft, and comes back once the marking is done', (tester) async {
    final c = await plainController();
    final ai = AiAssistant.of(c)..saveKey('sk-ant-api03-TEST-ANTHROPIC-0000');
    AiAssistant.dockable = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final draft = TextEditingController(text: 'the pump goes at A');
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  builder: (_) => AiMarksBar(c: c, input: draft),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> openSheet() async {
      await tester.tap(find.byKey(const Key('open')));
      await settle(tester, 3);
      expect(find.byKey(const Key('ai_marks_bar')), findsOneWidget);
    }

    await openSheet();
    await tester.tap(find.byKey(const Key('ai_mark_point')));
    await settle(tester, 3);
    expect(find.byKey(const Key('ai_marks_bar')), findsNothing, reason: 'the sheet over the drawing closed');
    expect(c.activeTool, ToolId.aiMarkPoint);
    expect(ai.rewound, 'the pump goes at A', reason: 'the draft waits in the assistant');
    // a mark on the drawing, then Done: the tool back at Select
    c.aiMarks.add([const Pt(3, 4)]);
    c.setTool(ToolId.select);
    await settle(tester, 4);
    expect(find.byKey(const Key('ai_panel')), findsOneWidget, reason: 'the assistant is back');
    expect((tester.widget(find.byKey(const Key('ai_input'))) as TextField).controller!.text, 'the pump goes at A');
    // marking again, but another tool chosen meanwhile: it stays closed
    Navigator.of(tester.element(find.byKey(const Key('ai_panel')))).pop();
    await settle(tester, 3);
    await openSheet();
    await tester.tap(find.byKey(const Key('ai_mark_line')));
    await settle(tester, 3);
    expect(c.activeTool, ToolId.aiMarkLine);
    c.setTool(ToolId.zonePipe);
    c.setTool(ToolId.select);
    await settle(tester, 4);
    expect(find.byKey(const Key('ai_panel')), findsNothing);
    // the assistant opened by hand while marking, the marking stopped from
    // its bar: nothing opens a second time over it
    await openSheet();
    await tester.tap(find.byKey(const Key('ai_mark_point')));
    await settle(tester, 3);
    await openSheet();
    await tester.tap(find.byKey(const Key('ai_mark_point')));
    await settle(tester, 4);
    expect(c.activeTool, ToolId.select);
    expect(find.byKey(const Key('ai_marks_bar')), findsOneWidget);
    expect(find.byKey(const Key('ai_panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the assistant\'s next message carries the marks placed on the canvas, with their coordinates and notes', (tester) async {
    final c = await pumpShell(tester);
    final ai = AiAssistant.of(c);
    expect(ai.composeText('Hello', ProjectContext.empty), 'Hello', reason: 'no marks, nothing added');
    c.setTool(ToolId.aiMarkPoint);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(12, 6));
    c.aiMarks.setNote('A', 'pump');
    c.setTool(ToolId.aiMarkLine);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(0, 0));
    await clickWorld(tester, c, const Pt(30, 0));
    await key(tester, LogicalKeyboardKey.enter);
    final text = ai.composeText('Put the pump at A, the mainline along B', ProjectContext.empty);
    expect(text, contains('<user_marks>'));
    expect(text, contains('orange'));
    expect(text, contains('A: point [12.00, 6.00] — "pump"'));
    expect(text, contains('B: line [[0.00, 0.00], [30.00, 0.00]], 30.0 m long'));
    expect(text, endsWith('Put the pump at A, the mainline along B'));
    await key(tester, LogicalKeyboardKey.escape);
  });
}
