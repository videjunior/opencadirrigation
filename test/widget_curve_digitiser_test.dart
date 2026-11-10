import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/io/file_drop.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_drop.dart';
import 'package:opencadirrigation/app/widgets/dialogs/curve_digitiser_dialog.dart';
import 'package:opencadirrigation/app/widgets/history_panel.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/curve_digitiser.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/main.dart';

/// Design → Digitise a curve from a picture (1.7.0 DGZ) in the app: the
/// menu opens it on an empty project, a dropped picture loads, the axes
/// are calibrated and the points clicked on the picture, the pump goes into
/// the catalogue as one undo step; points are dragged, deleted and undone,
/// a bad calibration says why, the trace follows the curve, the CSV and the
/// clipboard get the points; an outlet and a profile; the phone layout in
/// the light theme; and the assistant's operations.
void main() {
  // the chart of the picture: Q 0–100 m³/h along px 60–610, H 0–50 m up py 400–50
  double head(double q) => 50 - 0.003 * q * q;
  Pt chart(double q, double h) => Pt(60 + 5.5 * q, 400 - 7 * h);
  Uint8List png() {
    final im = img.Image(width: 660, height: 440, numChannels: 3)..clear(img.ColorRgb8(255, 255, 255));
    for (var q = 0; q <= 100; q += 10) {
      img.drawLine(im, x1: chart(q.toDouble(), 0).x.round(), y1: 50, x2: chart(q.toDouble(), 0).x.round(), y2: 400, color: img.ColorRgb8(210, 210, 210));
    }
    img.drawLine(im, x1: 60, y1: 400, x2: 615, y2: 400, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    img.drawLine(im, x1: 60, y1: 45, x2: 60, y2: 400, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    for (var q = 0.0; q < 100; q += 1) {
      final a = chart(q, head(q)), b = chart(q + 1, head(q + 1));
      img.drawLine(im, x1: a.x.round(), y1: a.y.round(), x2: b.x.round(), y2: b.y.round(), color: img.ColorRgb8(20, 70, 200), antialias: true, thickness: 2);
    }
    return Uint8List.fromList(img.encodePng(im));
  }

  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  CurveDigitiserDialogState state(WidgetTester tester) => tester.state<CurveDigitiserDialogState>(find.byType(CurveDigitiserDialog));

  Future<void> click(WidgetTester tester, Pt p) async {
    await tester.tapAt(state(tester).screenOf(p));
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final f = find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.enterText(f, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await settle(tester, 2);
  }

  /// Clicks the two points of each axis and types their values.
  Future<void> calibrate(WidgetTester tester) async {
    expect(state(tester).mode, DigitiserMode.x);
    await click(tester, chart(0, 0));
    await click(tester, chart(100, 0));
    expect(state(tester).mode, DigitiserMode.y, reason: 'on to the vertical axis');
    await click(tester, chart(0, 0));
    await click(tester, chart(0, 50));
    expect(state(tester).mode, DigitiserMode.points, reason: 'on to the points');
    await type(tester, 'dgz_x1', '0');
    await type(tester, 'dgz_x2', '100');
    await type(tester, 'dgz_y1', '0');
    await type(tester, 'dgz_y2', '50');
    expect(state(tester).session.mapping().$2, isNull);
  }

  Future<ProjectController> harness(WidgetTester tester, {Size size = const Size(1500, 950), Brightness brightness = Brightness.dark}) async {
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Cad.use(brightness);
    addTearDown(() => Cad.use(Brightness.dark));
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(brightness),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showCurveDigitiserDialog(ctx, c, picture: png(), name: 'chart.png'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(state(tester).raster, isNotNull, reason: 'the picture was read');
    return c;
  }

  testWidgets('Design menu on an empty project → a dropped picture → calibrate, click, apply as one undo step, undo', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c.autosaveEnabled = false;
    expect(c.project.entities, isEmpty);
    final pumps = c.project.catalog.pumps.length;
    await tester.tap(find.text(c.t('menu.design')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('menu_digitiser')));
    await settle(tester);
    expect(find.byKey(const Key('dgz_open')), findsOneWidget, reason: 'nothing to read yet: open, paste or drop');
    expect(find.text(c.t('dgz.empty')), findsOneWidget);
    // a picture dropped on the window goes to the open dialog
    AiFileDrop.instance.dropped(const Offset(300, 300), [DroppedFile.bytes('pump 40-200.png', png())]);
    await settle(tester);
    expect(state(tester).raster!.width, 660);
    await calibrate(tester);
    for (final q in const <double>[0, 20, 40, 60, 80, 100]) {
      await click(tester, chart(q, head(q)));
    }
    expect(state(tester).session.active.pixels, hasLength(6));
    final vals = state(tester).session.values();
    for (final (q, h) in vals) {
      expect(h, closeTo(head(q), 0.2), reason: 'Q $q');
    }
    expect(find.text(c.t('dgz.fit.parabola')), findsOneWidget);
    expect(find.byKey(const Key('dgz_table')), findsOneWidget);
    await type(tester, 'dgz_name_pump', 'Chart pump');
    await tapKey(tester, 'dgz_apply');
    expect(c.project.catalog.pumps, hasLength(pumps + 1));
    final p = c.project.catalog.pumps.last;
    expect(p.name, 'Chart pump');
    expect(p.points, hasLength(6));
    expect(p.curve.head(50 * m3sPerM3h), closeTo(head(50), 0.3));
    expect(p.maxFlow / m3sPerM3h, closeTo(100, 0.3));
    expect(find.byKey(const Key('dgz_applied')), findsOneWidget);
    expect(HistoryPanel.labelText(c, c.historyEntries.last.label), 'Curve from a picture: Chart pump');
    // a second Apply updates the pump just added
    await tapKey(tester, 'dgz_apply');
    expect(c.project.catalog.pumps, hasLength(pumps + 1));
    c.undo();
    c.undo();
    expect(c.project.catalog.pumps, hasLength(pumps), reason: 'each Apply was one undo step');
    await tapKey(tester, 'dgz_close');
    await settle(tester);
    expect(find.byType(CurveDigitiserDialog), findsNothing);
    // the work stays with the tab
    await tester.tap(find.text(c.t('menu.design')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('menu_digitiser')));
    await settle(tester);
    expect(state(tester).session.active.pixels, hasLength(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('points dragged, deleted and undone; a bad calibration says why; the trace; CSV and clipboard', (tester) async {
    final c = await harness(tester);
    await calibrate(tester);
    final s = state(tester);
    // back on the horizontal axis with both points set: a click moves the
    // nearer one and the step stays
    await tapKey(tester, 'dgz_mode_x');
    await click(tester, chart(100, 0) + const Pt(2, 0));
    expect(s.mode, DigitiserMode.x);
    expect(s.session.x.p2!.x, closeTo(chart(100, 0).x + 2, 1e-6));
    await click(tester, chart(100, 0));
    await tapKey(tester, 'dgz_mode_points');
    for (final q in const <double>[10, 50, 90]) {
      await click(tester, chart(q, head(q)));
    }
    expect(s.session.active.pixels, hasLength(3));
    // drag the middle point 10 m up: the screen distance at the view's zoom
    final from = s.screenOf(s.session.active.pixels[1]);
    final to = s.screenOf(s.session.active.pixels[1] + const Pt(0, -70));
    await tester.dragFrom(from, to - from);
    await settle(tester, 2);
    expect(s.session.values()[1].$2, closeTo(head(50) + 10, 0.4));
    await tapKey(tester, 'dgz_undo');
    expect(s.session.values()[1].$2, closeTo(head(50), 0.2), reason: 'the drag undone');
    // select a point and delete it with the button, then with the key
    await click(tester, s.session.active.pixels.first);
    await tapKey(tester, 'dgz_delete');
    expect(s.session.active.pixels, hasLength(2));
    await click(tester, s.session.active.pixels.first);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(s.session.active.pixels, hasLength(1));
    await tapKey(tester, 'dgz_undo');
    await tapKey(tester, 'dgz_undo');
    expect(s.session.active.pixels, hasLength(3));
    // two equal values on an axis: no mapping, and the reason
    await type(tester, 'dgz_x2', '0');
    expect(find.text(c.t('dgz.err.sameValues')), findsOneWidget);
    expect(find.byKey(const Key('dgz_apply')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('dgz_apply'))).onPressed, isNull);
    await type(tester, 'dgz_x2', '100');
    expect(find.byKey(const Key('dgz_cal_error')), findsNothing);
    // the trace: a click on the curve gives 15 evenly spaced points
    await tapKey(tester, 'dgz_mode_trace');
    await click(tester, chart(40, head(40)) + const Pt(0, 1.5));
    await settle(tester, 1);
    expect(find.byKey(const Key('dgz_trace_msg')), findsOneWidget);
    final traced = s.session.values();
    expect(traced, hasLength(15));
    for (var i = 0; i < traced.length; i++) {
      expect(traced[i].$1, closeTo(100 * i / 14, 1e-6));
      expect(traced[i].$2, closeTo(head(traced[i].$1), 0.35), reason: 'Q ${traced[i].$1}');
    }
    // the background clicked: the reason
    await click(tester, chart(75, 42));
    expect(find.text(c.t('dgz.trace.background')), findsOneWidget);
    expect(s.session.active.pixels, hasLength(15), reason: 'nothing changed');
    // CSV through the app's export, the clipboard tab-separated
    final files = <String, Object>{};
    final sink = engFileSink;
    engFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => engFileSink = sink);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tapKey(tester, 'dgz_csv');
    expect(files.keys.single, endsWith('_curve.csv'));
    final csv = files.values.single as String;
    expect(csv.split('\n').where((l) => l.startsWith('"Head";')), hasLength(15));
    expect(csv, contains(';"m³/h";"m.c.a."'));
    await tapKey(tester, 'dgz_copy');
    expect(copied, startsWith('Head\t\t\nm³/h\tm.c.a.\n0\t'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an outlet’s flow–pressure curve and a sprinkler’s profile into the catalogue', (tester) async {
    final c = await harness(tester);
    final s = state(tester);
    // the same picture read as a dripline chart: pressure 0–20 m along, flow 0–5 L/h up
    s.setKind(CurveKind.emitter);
    await tester.pump();
    expect(s.session.xUnit.id, 'head.mH2O');
    expect(s.session.active.yUnit.id, 'flow.lph');
    await click(tester, chart(0, 0));
    await click(tester, chart(100, 0));
    await click(tester, chart(0, 0));
    await click(tester, chart(0, 50));
    await type(tester, 'dgz_x1', '0');
    await type(tester, 'dgz_x2', '20');
    await type(tester, 'dgz_y1', '0');
    await type(tester, 'dgz_y2', '5');
    // q = 2·√(H/10) L/h
    for (final h in const <double>[4, 8, 12, 16, 20]) {
      await click(tester, chart(h * 5, 10 * 2 * math.sqrt(h / 10)));
    }
    final outlets = c.project.catalog.outlets.length;
    await type(tester, 'dgz_name_emitter', 'Chart dripper');
    await tapKey(tester, 'dgz_apply');
    expect(c.project.catalog.outlets, hasLength(outlets + 1));
    final o = c.project.catalog.outlets.last;
    expect((o.name, o.kind), ('Chart dripper', OutletKind.dripper));
    expect(o.nozzles.single.curve.x, closeTo(0.5, 0.03));
    expect(o.nozzles.single.curve.flow(10) / m3sPerLph, closeTo(2, 0.05));
    expect(o.nozzles.single.name, contains('L/h @'));
    // the profile: distance 0–20 m along, rate 0–10 mm/h up; onto a sprinkler's nozzle
    s.setKind(CurveKind.profile);
    await tester.pump();
    await click(tester, chart(0, 0));
    await click(tester, chart(100, 0));
    await click(tester, chart(0, 0));
    await click(tester, chart(0, 50));
    await type(tester, 'dgz_x1', '0');
    await type(tester, 'dgz_x2', '20');
    await type(tester, 'dgz_y1', '0');
    await type(tester, 'dgz_y2', '10');
    for (final (d, r) in const [(0.0, 6.0), (4.0, 7.0), (8.0, 5.0), (12.0, 2.5), (16.0, 0.8), (18.0, 0.0)]) {
      await click(tester, chart(d * 5, r * 5));
    }
    await tapKey(tester, 'dgz_apply');
    final withProfile = c.project.catalog.outlets.expand((o) => o.nozzles).where((n) => n.profile.isNotEmpty).toList();
    expect(withProfile, hasLength(1));
    final prof = withProfile.single.profile;
    expect(prof.last.$1, closeTo(1, 1e-9), reason: 'scaled to the wetted radius read (16 m)');
    expect(prof[1].$2, closeTo(1, 1e-9), reason: 'scaled to the largest rate');
    expect(prof.first.$2, closeTo(6 / 7, 0.03));
    // no outlet in the catalogue: the profile says so, never an exception
    c.mutate(() => c.project.catalog.outlets.clear());
    await tester.pump();
    s.setKind(CurveKind.pump);
    await tester.pump();
    s.setKind(CurveKind.profile);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('dgz_no_nozzle')));
    expect(find.byKey(const Key('dgz_no_nozzle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone (360 px) in the light theme: the picture above, the steps below, nothing overflows', (tester) async {
    final c = await harness(tester, size: const Size(360, 740), brightness: Brightness.light);
    expect(tester.getSize(find.byKey(const Key('dgz_dialog'))).width, lessThanOrEqualTo(360));
    await calibrate(tester);
    for (final q in const <double>[0, 30, 60, 90]) {
      await click(tester, chart(q, head(q)));
    }
    await tapKey(tester, 'dgz_apply');
    expect(c.project.catalog.pumps.last.points, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the assistant: fit, apply (pump, outlet, nozzle, tape, profile) and export the points of a chart', (tester) async {
    LocalProjectStore().clearAll();
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    final box = AgentToolbox(c);
    AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);
    final pts = [
      for (var q = 0; q <= 100; q += 20) [q, 50 - 0.003 * q * q],
    ];
    await tester.runAsync(() async {
      final fit = await op('fit_curve_points').run({
        'kind': 'pump',
        'head': pts,
        'efficiency': [
          [20, 55],
          [60, 74],
          [100, 66],
        ],
      });
      expect(fit.text, allOf(contains('least-squares parabola'), contains('best 74.0 %')));
      expect(c.canUndo, isFalse, reason: 'a fit changes nothing');
      await expectLater(op('fit_curve_points').run({'kind': 'pump'}), throwsA(isA<ToolInputError>()));
      await expectLater(op('fit_curve_points').run({'kind': 'pump', 'profile': pts}), throwsA(isA<ToolInputError>()));
      await expectLater(op('fit_curve_points').run({'kind': 'pump', 'head': pts, 'flow_unit': 'cfs'}), throwsA(isA<ToolInputError>()));
      final apply = op('apply_curve_points');
      expect(apply.effectOf(const {}), ToolEffect.write);
      await expectLater(apply.run({'kind': 'pump', 'head': pts}), throwsA(isA<ToolInputError>()), reason: 'a new pump needs a name');
      final n = c.project.catalog.pumps.length;
      final added = await apply.run({'kind': 'pump', 'name': 'AI pump', 'head': pts, 'flow_unit': 'lps', 'pressure_unit': 'bar'});
      expect(added.text, startsWith('Added pump'));
      final p = c.project.catalog.pumps.last;
      expect(p.name, 'AI pump');
      expect(p.points.last.$1, closeTo(0.1, 1e-12), reason: '100 L/s');
      expect(p.points.first.$2, closeTo(50 / barPerMeterHead, 1e-9), reason: '50 bar');
      expect(c.project.catalog.pumps, hasLength(n + 1));
      c.undo();
      expect(c.project.catalog.pumps, hasLength(n), reason: 'one undo step');
      // emitters: a new outlet, a nozzle, a tape
      final fp = [
        for (final h in [5, 10, 15, 20]) [h, 4 * math.sqrt(h / 10)],
      ];
      final out = await apply.run({'kind': 'emitter', 'name': 'AI dripper', 'flow_pressure': fp});
      expect(out.text, contains('Added outlet'));
      final o = c.project.catalog.outlets.last;
      expect(o.nozzles.single.curve.x, closeTo(0.5, 1e-9));
      final sprinkler = c.project.catalog.outlets.firstWhere((x) => x.nozzles.first.curve.radiusA > 0);
      final ra = sprinkler.nozzles.first.curve.radiusA;
      await apply.run({'kind': 'emitter', 'outlet_id': sprinkler.id, 'flow_pressure': fp});
      final nz = c.project.catalog.outlet(sprinkler.id)!.nozzles.first;
      expect(nz.curve.x, closeTo(0.5, 1e-9));
      expect(nz.curve.radiusA, ra, reason: 'the wetted radius kept');
      final tape = c.project.catalog.tapes.first;
      await apply.run({'kind': 'emitter', 'tape_id': tape.id, 'flow_pressure': fp});
      expect(c.project.catalog.tape(tape.id)!.emitter.flow(10) / m3sPerLph, closeTo(4, 1e-9));
      await expectLater(apply.run({'kind': 'emitter', 'outlet_id': 'nope', 'flow_pressure': fp}), throwsA(isA<ToolInputError>()));
      // the profile
      await apply.run({
        'kind': 'profile',
        'outlet_id': sprinkler.id,
        'profile': [
          [0, 4.1],
          [5, 4.4],
          [10, 2.0],
          [12, 0],
        ],
      });
      final prof = c.project.catalog.outlet(sprinkler.id)!.nozzles.first.profile;
      expect(prof.last.$1, 1.0);
      expect(prof.last.$2, closeTo(2 / 4.4, 1e-9));
      await expectLater(apply.run({'kind': 'profile', 'profile': fp}), throwsA(isA<ToolInputError>()), reason: 'the nozzle is needed');
      // the export
      final files = <String, Object>{};
      final sink = engFileSink;
      engFileSink = (c, name, mime, data) async => files[name] = data;
      try {
        final exp = op('export_curve_points');
        expect(exp.mustConfirm(const {'kind': 'pump'}), isTrue, reason: 'a download is always confirmed');
        expect((await exp.run({'kind': 'pump', 'head': pts})).text, contains('6 points'));
        expect((files.values.single as String).split('\n')[1], '"Head";0;50;"m³/h";"m.c.a."');
      } finally {
        engFileSink = sink;
      }
    });
  });
}
