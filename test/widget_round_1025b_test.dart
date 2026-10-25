import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/gps.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Interface of the field and review features: right-to-left layout for
/// Arabic and Urdu, the conditional labels dialog, the GPS chip, the
/// breakline tool and the materials of a selection.
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
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  testWidgets('Arabic and Urdu lay the interface out right to left', (tester) async {
    final c = await pumpShell(tester);
    expect(Directionality.of(ctxOf(tester)), TextDirection.ltr);
    await c.setLanguage('ar', persist: false);
    await settle(tester);
    expect(Directionality.of(ctxOf(tester)), TextDirection.rtl);
    await c.setLanguage('pt', persist: false);
    await settle(tester);
    expect(Directionality.of(ctxOf(tester)), TextDirection.ltr);
  });

  testWidgets('conditional labels: a rule added in the dialog is one undo step', (tester) async {
    final c = await pumpShell(tester);
    final before = c.historyIndex;
    showLabelRulesDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Rótulos condicionais'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lbl_add')));
    await settle(tester, 2);
    expect(c.project.labelRules, hasLength(1));
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(c.historyIndex, before + 1);
    c.undo();
    expect(c.project.labelRules, isEmpty);
  });

  testWidgets('the GPS chip shows the accuracy while the GPS is on', (tester) async {
    late void Function(GpsFix) feed;
    ProjectController.gpsWatcher = (onFix, onError) {
      feed = onFix;
      return () {};
    };
    final c = await pumpShell(tester);
    c.startGps();
    await settle(tester, 1);
    expect(find.text('GPS: aguardando posição…'), findsOneWidget);
    feed(GpsFix(lat: -15.78, lon: -47.93, accuracyM: 4, time: DateTime(2026)));
    await settle(tester, 1);
    expect(find.text('GPS ±4 m'), findsOneWidget);
    // (the notice of the georeference the first fix created covers the chip)
    c.stopGps();
    await settle(tester, 1);
    expect(find.byKey(const Key('gps_chip')), findsNothing);
  });

  testWidgets('the breakline tool draws a breakline', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.breakline);
    await settle(tester, 1);
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    Offset at(double x, double y) => box.localToGlobal(c.camera.toScreen(Pt(x, y)));
    await tester.tapAt(at(0, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(at(20, 5));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 1);
    final b = c.project.entities.whereType<BreaklineEntity>().single;
    expect(b.points, hasLength(2));
    expect(b.elevations.every((z) => z.isNaN), isTrue);
  });

  testWidgets('the Edit menu lists the materials of the selection', (tester) async {
    final c = await pumpShell(tester);
    loadExampleAction(c, ExampleId.garden);
    await settle(tester);
    final pipes = c.project.entities.whereType<PipeEntity>().take(2).map((e) => e.id).toList();
    c.select(pipes);
    await settle(tester, 1);
    await tester.tap(find.text('Editar').first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_selection_bom')));
    await settle(tester);
    expect(find.text('Materiais da seleção (2 itens)'), findsOneWidget);
    expect(find.byKey(const Key('bom_sel_unsized')), findsOneWidget, reason: 'the pipes are not sized before the design');
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    c.results = Designer(c.project).designAll();
    c.refresh();
    c.select(pipes);
    showSelectionBomDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('bom_sel_unsized')), findsNothing);
    expect(find.byKey(const Key('bom_sel_csv')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
