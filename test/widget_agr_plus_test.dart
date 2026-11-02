import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/agronomy_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/crop_plan_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/water_balance_dialogs.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/main.dart';

/// The agronomy dialogs of 1.6.0 (AGR+): daily water balance, runoff
/// potential, controller programme, the user's crops, fertigation by stage
/// and the uniformity in the field — they lay out on a phone, sideways, in a
/// right-to-left language and with text twice as big, and Save keeps their
/// settings in the project as one undo step.
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
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    loadExampleAction(c);
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  AreaEntity balanceArea(ProjectController c) => c.project.entities.whereType<AreaEntity>().firstWhere((a) => a.points.length >= 3 && a.useWaterBalance);

  final dialogs = <String, Future<void> Function(BuildContext, ProjectController)>{
    'waterBalance': showWaterBalanceDialog,
    'runoff': showRunoffPotentialDialog,
    'programme': showIrrigationProgrammeDialog,
    'userCrops': showUserCropsDialog,
    'fertigation': showFertigationStagesDialog,
    'fieldUniformity': showFieldUniformityDialog,
  };

  for (final (name, size, lang, scale) in const [
    ('phone', Size(360, 640), 'pt', 1.0),
    ('phone sideways', Size(844, 390), 'pt', 1.0),
    ('right to left', Size(360, 640), 'ar', 1.0),
    ('text twice as big', Size(1280, 800), 'pt', 2.0),
  ]) {
    testWidgets('the agronomy dialogs lay out: $name', (tester) async {
      final c = await pumpShell(tester, size, lang: lang, textScale: scale);
      // a crop of the user and a field test, so their editors open too
      c.project.agronomy.userCrops.add(UserCrop(id: 'maracuja', name: 'Maracujá', ky: 1.1, eceThreshold: 1.5, eceMax: 10));
      final a = balanceArea(c);
      c.project.agronomy.fieldTests.add(FieldTest(id: 'ft1', name: 'Zona 1', areaId: a.id, origin: a.points.first, cols: 3, values: [10, 12, null, 11, 9, 10]));
      c.project.agronomy.fertigation[a.id] = FertigationStagePlan(doseKgHa: [120, 60, 90]);
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

  group('saving the settings', () {
    testWidgets('water balance: the chart of the area, kept for the area', (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      final a = balanceArea(c);
      showWaterBalanceDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('swb.title')), findsOneWidget);
      expect(find.byKey(const Key('swb_chart')), findsOneWidget);
      final before = c.historyIndex;
      await tester.tap(find.byKey(const Key('swb_save')));
      await settle(tester);
      expect(c.project.agronomy.balance.containsKey(a.id), isTrue);
      expect(c.historyIndex, before + 1);
      await tester.tap(find.byKey(const Key('swb_close')));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('programme: cycle and soak switched on, undone in one step', (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      showIrrigationProgrammeDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('prog.title')), findsOneWidget);
      expect(find.byKey(const Key('prog_export_stations')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('prog_cycle_soak')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('prog_cycle_soak')));
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('prog_save')));
      await settle(tester);
      expect(c.project.agronomy.programme.cycleSoak, isTrue);
      await tester.tap(find.byKey(const Key('prog_close')));
      await settle(tester);
      c.undo();
      expect(c.project.agronomy.programme.cycleSoak, isFalse);
    });

    testWidgets("the user's crops: a crop added is in the project", (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      showUserCropsDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('uc.none')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('uc_add')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('uc_add')));
      await settle(tester, 2);
      expect(find.textContaining('user.'), findsOneWidget, reason: 'the crop key the areas take');
      await tester.tap(find.byKey(const Key('uc_ok')));
      await settle(tester);
      expect(c.project.agronomy.userCrops, hasLength(1));
      expect(c.project.agronomy.userCrops.single.key, startsWith(userCropPrefix));
    });

    testWidgets('fertigation by stage: the doses typed are saved for the area', (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      final a = balanceArea(c);
      showFertigationStagesDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('fst.title')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('fst_dose0_0')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('fst_dose0_0')), '120');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('fst_save')));
      await settle(tester);
      expect(c.project.agronomy.fertigation[a.id]!.doseKgHa[0], 120);
      await tester.tap(find.byKey(const Key('fst_close')));
      await settle(tester);
    });

    testWidgets('field uniformity: a grid of cans over the area becomes a field test', (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      showFieldUniformityDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('ft.title')), findsOneWidget);
      expect(find.text(c.t('ft.none')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ft_add')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ft_add')));
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('ft_ok')));
      await settle(tester);
      final ft = c.project.agronomy.fieldTests.single;
      expect(ft.kind, FieldTestKind.cans);
      expect(ft.cols, greaterThan(0));
      expect(ft.values, isNotEmpty);
      expect(ft.areaId, isNotEmpty);
    });

    testWidgets('runoff without soils says so; the site climate offers the station file', (tester) async {
      final c = await pumpShell(tester, const Size(1600, 1000));
      showRunoffPotentialDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.text(c.t('ro.none')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ro_close')));
      await settle(tester);
      showSiteClimateDialog(ctxOf(tester), c);
      await settle(tester);
      expect(find.byKey(const Key('clim_inmet')), findsOneWidget);
      Navigator.of(tester.element(find.byType(Dialog).last)).pop();
      await settle(tester);
    });
  });
}
