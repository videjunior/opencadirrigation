import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/agb_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/field_machine_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/more_dialogs.dart';
import 'package:opencadirrigation/app/widgets/message_log.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The dialogs of the interface on a phone, on a phone held sideways, in a
/// right-to-left language and with the system text twice as big: none
/// throws a layout error (UI-14, UI-15, UI-31, UI-36, UI-37); and the phone
/// layout passes the accessibility guidelines of labelled targets of at
/// least 48 px (UI-23).
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, Size size, {String lang = 'pt', double textScale = 1}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c.autosaveEnabled = false;
    loadExampleAction(c);
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  final dialogs = <String, Future<void> Function(BuildContext, ProjectController)>{
    'details': showProjectDetailsDialog,
    'params': showDesignParamsDialog,
    'units': showUnitsDialog,
    'management': showManagementDialog,
    'proposal': showProposalDialog,
    'labelRules': showLabelRulesDialog,
    'lateral': showLateralCalculator,
    'pump': showPumpCalculator,
    'hammer': showHammerCalculator,
    'catalog': showCatalogEditorDialog,
    'versions': showVersionsDialog,
    'messages': showMessageLogDialog,
    'about': showAboutDialogApp,
    // 1.6.0 AGB
    'pumpHouse': showPumpHouseDialog,
    'solarDesign': showSolarDesignDialog,
    'waterQuality': showWaterQualityDialog,
    'twoWire': showTwoWireDialog,
    'multiPivot': showMultiPivotDialog,
    'travellerLanes': showTravellerLanesDialog,
    'furrowSet': showFurrowSetDialog,
  };

  for (final (name, size, lang, scale) in const [
    ('phone', Size(360, 640), 'pt', 1.0),
    ('phone sideways', Size(844, 390), 'pt', 1.0),
    ('right to left', Size(360, 640), 'ar', 1.0),
    ('text twice as big', Size(1280, 800), 'pt', 2.0),
  ]) {
    testWidgets('every dialog lays out: $name', (tester) async {
      final c = await pumpShell(tester, size, lang: lang, textScale: scale);
      expect(tester.takeException(), isNull, reason: 'the shell itself');
      for (final e in dialogs.entries) {
        e.value(ctxOf(tester), c);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} at $name');
        expect(find.byType(Dialog), findsWidgets, reason: '${e.key} opened');
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} closing at $name');
      }
    });
  }

  testWidgets('the phone layout: tap targets of 48 px, each with a label', (tester) async {
    // the phone shell around a placeholder (the drawing and its zoom buttons are the canvas's)
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    final ws = Workspace(systemClipboard: false, openBlankTab: false)..addTab(controller: c);
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    c.select([c.project.entities.first.id]);
    c.activeTool = ToolId.line;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: MobileShell(c: c, ws: ws, canvas: const SizedBox.expand(), hint: 'hint', onStartTutorial: () {}, onShowWelcome: () {}, onCloseTab: () {}, onDesignCheck: () {}, onCommand: (_) {}),
      ),
    );
    await settle(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
