import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/ui_prefs.dart';
import 'package:opencadirrigation/app/version.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/export_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/feedback_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/help_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/whats_new_dialog.dart';
import 'package:opencadirrigation/app/widgets/layout_mode.dart';
import 'package:opencadirrigation/app/widgets/menu_bar.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/sheet_set.dart' show SheetSplit;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The interface functions of 1.6.0 (wave 2) on the screen: the unnamed new
/// tab in the language of the moment, the command palette (Ctrl+K and the
/// search of the phone menu), the manual and the "?" of the dialogs, the
/// report and the news, the sheet preview (and a scale typed as "1.500"),
/// the side panel folded and widened, focus mode, the size and the contrast
/// of the interface, the zoom buttons for the finger, the tutorial's
/// chapters, tracks, touch texts, saved place and AI chapter, and the large
/// linked project.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  tearDown(() {
    for (final k in ['ui_scale', 'ui_contrast', 'ui_side_folded', 'ui_side_width', 'ui_reports_height', TutorialController.progressKey]) {
      removePref(k);
    }
    reloadUiPrefs();
    lastPointerKind.value = null;
    AiAssistant.panelOpen.value = false;
  });

  Future<dynamic> pumpShell(WidgetTester tester, {Size size = const Size(1600, 1000), String lang = 'pt', bool example = true}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    if (example) loadExampleAction(c);
    await settle(tester);
    return shell;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  testWidgets('a new tab has no name of its own: it reads "New project" in the language of the moment', (tester) async {
    final shell = await pumpShell(tester, example: false);
    final c = shell.c as ProjectController;
    expect(c.project.meta.name, '');
    expect(find.text('Novo projeto'), findsWidgets);
    await c.setLanguage('en', persist: false);
    await settle(tester);
    expect(find.text('New project'), findsWidgets, reason: 'the tab follows the language');
    expect(find.text('Novo projeto'), findsNothing);
  });

  testWidgets('Ctrl+K: the palette finds a menu item in Portuguese or in English and runs it', (tester) async {
    final shell = await pumpShell(tester);
    final c = shell.c as ProjectController;
    final grid = c.showGrid;
    shell.commandPalette();
    await settle(tester);
    expect(find.byKey(const Key('palette')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('palette_query')), 'grade');
    await settle(tester, 2);
    expect(find.text('${c.t('view.grid')}  (F7)'), findsWidgets);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const Key('palette')), findsNothing, reason: 'closed before running');
    expect(c.showGrid, !grid);
    // the English name of a Portuguese item, and nothing found
    shell.commandPalette();
    await settle(tester);
    await tester.enterText(find.byKey(const Key('palette_query')), 'grid');
    await settle(tester, 2);
    expect(find.text('${c.t('view.grid')}  (F7)'), findsWidgets);
    await tester.enterText(find.byKey(const Key('palette_query')), 'zzqqxx');
    await settle(tester, 2);
    expect(find.byKey(const Key('palette_none')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('palette')), findsNothing);
    expect(find.byKey(const Key('menu_palette')), findsNothing, reason: 'the Help item is in the closed menu');
    expect(AppMenuBar.barKey.currentWidget, isA<MenuBar>());
  });

  testWidgets('the phone menu: a search at the top lists the matching rows of every section', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ProjectController()..autosaveEnabled = false;
    await c.setLanguage('pt', persist: false);
    c.newProject();
    final ws = Workspace(systemClipboard: false, openBlankTab: false)..addTab(controller: c);
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: MobileShell(c: c, ws: ws, canvas: const SizedBox.expand(), hint: '', onStartTutorial: () {}, onShowWelcome: () {}, onCloseTab: () {}, onDesignCheck: () {}, onCommand: (_) {}),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('mobile_menu')));
    await settle(tester);
    expect(find.byKey(const Key('mobile_menu_search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mobile_menu_search')), 'selecionar tudo');
    await settle(tester, 2);
    expect(find.byKey(const Key('mobile_menu_results')), findsOneWidget);
    expect(find.text(c.t('edit.selectAll')), findsOneWidget);
    expect(find.text(c.t('menu.edit')), findsWidgets, reason: 'the section under the row');
    await tester.tap(find.text(c.t('edit.selectAll')));
    await settle(tester);
    expect(c.selection, isNotEmpty);
  });

  testWidgets('the manual: subjects, search, the chapter link, and the "?" of a dialog opening its subject', (tester) async {
    final shell = await pumpShell(tester);
    final c = shell.c as ProjectController;
    showHelpDialog(ctxOf(tester), c, topic: 'params');
    await settle(tester);
    expect(find.byKey(const Key('help_dialog')), findsOneWidget);
    expect(find.text(c.t('help.t.params')), findsWidgets);
    expect(find.byKey(const Key('help_chapter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('help_topic_layers')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('help_page_title'))).data, c.t('help.t.layers'));
    await tester.enterText(find.byKey(const Key('help_search')), 'satélite');
    await settle(tester, 2);
    expect(find.byKey(const Key('help_topic_terrain')), findsOneWidget);
    expect(find.byKey(const Key('help_topic_history')), findsNothing);
    await tester.tap(find.byKey(const Key('help_close')));
    await settle(tester);
    // the "?" of Design → Design parameters opens its subject
    showDesignParamsDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('help_button_params')), findsOneWidget);
    await tester.tap(find.byKey(const Key('help_button_params')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('help_page_title'))).data, c.t('help.t.params'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the report: a title first; diagnostics without the project; the news after an update', (tester) async {
    final shell = await pumpShell(tester);
    final c = shell.c as ProjectController;
    c.project.meta.name = 'Fazenda Secreta';
    showFeedbackDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('feedback')), findsOneWidget);
    final diag = tester.widget<SelectableText>(find.descendant(of: find.byKey(const Key('feedback_diag')), matching: find.byType(SelectableText))).data!;
    expect(diag, contains(appVersion));
    expect(diag, isNot(contains('Fazenda')));
    await tester.ensureVisible(find.byKey(const Key('feedback_github')));
    await tester.tap(find.byKey(const Key('feedback_github')));
    await settle(tester);
    expect(find.text(c.t('fb.needTitle')), findsOneWidget, reason: 'a title first');
    await tester.enterText(find.byKey(const Key('feedback_title')), 'Trava ao exportar');
    await tester.tap(find.text(c.t('fb.idea')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('feedback_github')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('feedback_close')));
    await settle(tester);
    showWhatsNewDialog(ctxOf(tester), c, afterUpdate: true);
    await settle(tester);
    expect(find.byKey(const Key('whats_new_updated')), findsOneWidget);
    for (final k in whatsNewKeys(whatsNewVersion)) {
      expect(find.text(c.t(k)), findsOneWidget, reason: k);
    }
    await tester.tap(find.byKey(const Key('whats_new_close')));
    await settle(tester);
  });

  testWidgets('the sheet export: a preview of each sheet of the set; "1.500" typed as the scale is 1500', (tester) async {
    final shell = await pumpShell(tester);
    final c = shell.c as ProjectController;
    c.designRunner = InThreadDesignRunner();
    await tester.runAsync(() => c.runDesign());
    await settle(tester);
    final result = showPlotDialog(ctxOf(tester), c, initial: const SheetOptions(scale: 500, split: SheetSplit.zones));
    await settle(tester, 6);
    expect(find.byKey(const Key('sheet_preview')), findsOneWidget);
    expect(find.byKey(const Key('sheet_preview_page')), findsOneWidget, reason: 'a set of sheets');
    final first = tester.widget<Text>(find.byKey(const Key('sheet_preview_page'))).data;
    await tester.ensureVisible(find.byKey(const Key('sheet_preview_next')));
    await tester.tap(find.byKey(const Key('sheet_preview_next')));
    await settle(tester, 3);
    expect(tester.widget<Text>(find.byKey(const Key('sheet_preview_page'))).data, isNot(first));
    final scale = find.widgetWithText(TextField, c.t('plot.scale'));
    await tester.enterText(scale, '1.500');
    await settle(tester, 3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o = await result;
    expect(o?.scale, 1500, reason: 'a thousands point in Portuguese');
  });

  testWidgets('the side panel folds away and widens; focus mode leaves the drawing board alone', (tester) async {
    final shell = await pumpShell(tester);
    expect(find.byKey(const Key('side_fold')), findsOneWidget);
    await tester.tap(find.byKey(const Key('side_fold')));
    await settle(tester);
    expect(uiSideFolded.value, isTrue);
    expect(getPref('ui_side_folded'), '1');
    expect(find.byKey(const Key('side_unfold')), findsOneWidget);
    await tester.tap(find.byKey(const Key('side_unfold')));
    await settle(tester);
    expect(uiSideFolded.value, isFalse);
    final before = uiSideWidth.value;
    // (a mouse: the first move only starts the drag)
    final drag = await tester.startGesture(tester.getCenter(find.byKey(const Key('side_resize'))), kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(-10, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();
    await drag.up();
    await settle(tester);
    expect(uiSideWidth.value, closeTo(before + 100, 1), reason: 'dragged to the left: wider');
    expect(getPref('ui_side_width'), '${uiSideWidth.value.round()}', reason: 'kept once the drag ends');
    // focus mode
    shell.toggleFocusMode();
    await settle(tester);
    expect(find.byType(AppMenuBar), findsNothing);
    expect(find.byKey(const Key('focus_exit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus_exit')));
    await settle(tester);
    expect(find.byType(AppMenuBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the size of the interface scales everything; high contrast switches the palette', (tester) async {
    const k = Key('box');
    await tester.pumpWidget(
      CadThemeHost(
        builder: (context, b) => MaterialApp(
          theme: buildCadTheme(b),
          builder: (context, child) => UiScaled(child: child!),
          home: const Scaffold(
            body: Align(alignment: Alignment.topLeft, child: SizedBox(key: k, width: 100, height: 40)),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(k)).width, closeTo(100, 0.01));
    setUiScale(1.5);
    await tester.pump();
    expect(tester.getRect(find.byKey(k)).width, closeTo(150, 0.01));
    expect(tester.getRect(find.byKey(k)).height, closeTo(60, 0.01));
    setUiScale(1);
    await tester.pump();
    expect(tester.getRect(find.byKey(k)).width, closeTo(100, 0.01));
    setHighContrast(true);
    await tester.pump();
    expect(identical(Cad.palette, CadPalette.darkHigh), isTrue);
    setHighContrast(false);
    await tester.pump();
    expect(identical(Cad.palette, CadPalette.dark), isTrue);
  });

  testWidgets('the zoom buttons of the drawing are named and finger-sized on touch screens (UI-23)', (tester) async {
    final shell = await pumpShell(tester);
    final c = shell.c as ProjectController;
    lastPointerKind.value = PointerDeviceKind.mouse;
    await settle(tester);
    final zoomIn = find.byKey(const Key('canvas_zoom_in'));
    expect(zoomIn, findsOneWidget);
    expect(tester.getSize(zoomIn).width, closeTo(32, 0.5));
    expect(find.byTooltip(c.t('view.zoomIn')), findsWidgets);
    lastPointerKind.value = PointerDeviceKind.touch;
    await settle(tester);
    expect(tester.getSize(find.byKey(const Key('canvas_zoom_in'))).width, closeTo(48, 0.5));
    final scale = c.camera.scale;
    await tester.tap(find.byKey(const Key('canvas_zoom_in')));
    await settle(tester);
    expect(c.camera.scale, greaterThan(scale));
  });

  testWidgets('the tutorial: chapters and tracks in the card, the AI chapter that watches the panel and only writes', (tester) async {
    final shell = await pumpShell(tester, example: false);
    shell.startTutorial();
    await settle(tester);
    final tutorial = shell.tutorial as TutorialController;
    expect(tutorial.current.id, 'welcome');
    await tester.tap(find.byKey(const Key('tut_chapters')));
    await settle(tester);
    await tester.tap(find.textContaining(tutorialText('trackLandscape', 'pt')).last);
    await settle(tester);
    expect(tutorial.track, TutorialTrack.landscape);
    expect(tutorial.steps.length, tutorialTrackSteps[TutorialTrack.landscape]!.length);
    // the AI chapter: Show me opens the panel with an example written in it, and nothing is sent
    tutorial.goToChapter(tutorial.steps.firstWhere((s) => s.id == 'aiOpen').chapter);
    await settle(tester);
    final open = tutorial.current;
    expect(open.id, 'aiOpen');
    await tester.tap(find.byKey(const Key('tut_demo')));
    await settle(tester, 6);
    expect(AiAssistant.panelOpen.value, isTrue);
    final ai = AiAssistant.peek(shell.c as ProjectController)!;
    expect(ai.busy, isFalse, reason: 'nothing went to any AI service');
    expect(open.isDone!(TutorialContext(shell.c as ProjectController, shell as TutorialHost, tutorial.memo)), isTrue);
    tutorial.skip();
    await settle(tester);
  });

  testWidgets('the tutorial on a phone: touch texts, the short track, and continuing where the user stopped', (tester) async {
    final shell = await pumpShell(tester, size: const Size(390, 844), example: false);
    setPref(TutorialController.progressKey, 'full|zoom');
    shell.startTutorial();
    await settle(tester);
    final tutorial = shell.tutorial as TutorialController;
    expect(find.byKey(const Key('tut_resume')), findsOneWidget);
    expect(find.byKey(const Key('tut_touch_track')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('tut_resume')));
    await tester.tap(find.byKey(const Key('tut_resume')));
    await settle(tester);
    expect(tutorial.current.id, 'zoom');
    expect(find.textContaining('pinça'), findsWidgets, reason: 'the touch text of the step');
    tutorial.goTo(0);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('tut_touch_track')));
    await tester.tap(find.byKey(const Key('tut_touch_track')));
    await settle(tester);
    expect(tutorial.track, TutorialTrack.touch);
    tutorial.skip();
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  test('the new strings are in the three compiled languages', () {
    for (final lang in ['pt', 'en', 'es']) {
      final t = I18n(lang);
      for (final k in ['pal.menu', 'help.manual', 'fb.menu', 'new.menu', 'uiv.menu', 'uiv.contrast', 'prev.title']) {
        expect(t.has(k), isTrue, reason: '$lang $k');
      }
    }
  });
}
