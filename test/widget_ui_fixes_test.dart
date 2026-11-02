import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/io/app_keys.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/app/widgets/layout_mode.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/app/widgets/fields.dart';
import 'package:opencadirrigation/app/widgets/properties_panel.dart';
import 'package:opencadirrigation/app/widgets/status_bar.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/main.dart';

/// Defects of the interface outside the drawing (sweep of 2026-11-01, UI-*):
/// each test fails on the code before its fix.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// The app as a visitor opens it: an empty project, nothing asked.
  Future<dynamic> pumpFresh(WidgetTester tester, {Size size = const Size(1600, 1000)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    (shell.c as ProjectController).autosaveEnabled = false;
    return shell;
  }

  Future<void> openHelp(WidgetTester tester, String item) async {
    await tester.tap(find.text('Ajuda'));
    await settle(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  group('UI-01 the tutorial works on its own orchard', () {
    testWidgets('Help → Tutorial in a freshly opened app loads the orchard the first step talks about', (tester) async {
      final shell = await pumpFresh(tester);
      final ws = shell.ws as Workspace;
      expect(ws.current.project.entities, isEmpty, reason: 'the app opens empty');
      await openHelp(tester, 'Tutorial interativo');
      expect(find.byKey(const Key('tut_next')), findsOneWidget);
      // the blank tab of the fresh start is used: no tab left over
      expect(ws.tabs, hasLength(1));
      final c = ws.current;
      expect(c.project.entities.whereType<ControlValveEntity>(), isNotEmpty, reason: 'the orchard is there');
      expect(c.project.entities.whereType<SpraylineEntity>(), isNotEmpty);
      // the first step says the truth
      expect(find.textContaining('numa aba só dele'), findsOneWidget);
      // and the steps that select something find it: the valve demo completes
      final steps = buildTutorialSteps('pt');
      final valve = steps.indexWhere((s) => s.id == 'properties');
      expect(valve, greaterThan(0));
      shell.tutorial.setAutoAdvance(false);
      shell.tutorial.goTo(valve);
      await settle(tester);
      await tester.tap(find.byKey(const Key('tut_demo')));
      await settle(tester);
      expect(find.textContaining('Feito!'), findsOneWidget, reason: 'the demo found a valve to rename');
    });

    testWidgets("the user's own project stays as it was: the demos run in a new tab", (tester) async {
      final shell = await pumpFresh(tester);
      final ws = shell.ws as Workspace;
      final mine = ws.current;
      mine.addEntity(LineEntity(id: mine.project.newId(), a: Pt.zero, b: const Pt(25, 0)));
      final before = mine.saveJson(markClean: false);
      await openHelp(tester, 'Tutorial interativo');
      expect(ws.tabs, hasLength(2));
      expect(identical(ws.current, mine), isFalse, reason: 'the tutorial tab is selected');
      shell.tutorial.setAutoAdvance(false);
      // the georeference, terrain and rename demos change only the tutorial's tab
      for (final id in ['georef', 'properties']) {
        shell.tutorial.goTo(buildTutorialSteps('pt').indexWhere((s) => s.id == id));
        await settle(tester);
        await tester.tap(find.byKey(const Key('tut_demo')));
        await settle(tester);
      }
      expect(ws.current.project.meta.georef, isNotNull);
      expect(mine.project.meta.georef, isNull);
      expect(mine.saveJson(markClean: false), before);
    });
  });

  group('UI-03 the application keys take the value being typed', () {
    Future<(ProjectController, SpotHeightEntity)> typeElevation(WidgetTester tester, dynamic shell, String text) async {
      final ProjectController c = shell.c;
      loadExampleAction(c);
      c.designRunner = InThreadDesignRunner();
      final sp = SpotHeightEntity(id: c.project.newId(), position: const Pt(5, 5), elevation: 100);
      c.addEntity(sp);
      c.select([sp.id]);
      await settle(tester);
      final field = find.widgetWithText(TextField, c.t('props.elevation'));
      expect(field, findsOneWidget);
      await tester.enterText(field, text);
      await tester.pump();
      expect(editableTextFocused(), isTrue);
      return (c, sp);
    }

    testWidgets('F5 while typing designs with the number just typed (it was refused as "design running")', (tester) async {
      final shell = await pumpFresh(tester);
      final (c, sp) = await typeElevation(tester, shell, '123.5');
      (shell.hotkeys as Hotkeys).handle(const HotkeyEvent('F5'));
      await settle(tester);
      for (var k = 0; k < 400 && c.busy; k++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await settle(tester);
      expect(c.results, isNotNull, reason: 'the design ran');
      expect((c.project.entities.firstWhere((e) => e.id == sp.id) as SpotHeightEntity).elevation, 123.5);
      expect(c.lastMessage, isNot(c.t('msg.designBusy')));
    });

    testWidgets('Ctrl+S while typing saves the number just typed', (tester) async {
      final shell = await pumpFresh(tester);
      final (c, sp) = await typeElevation(tester, shell, '321');
      (shell.hotkeys as Hotkeys).handle(const HotkeyEvent('s', ctrl: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final saved = c.store.load(c.project.meta.uid);
      expect(saved, isNotNull);
      final entities = ((jsonDecode(saved!) as Map<String, dynamic>)['project'] as Map<String, dynamic>? ?? jsonDecode(saved) as Map<String, dynamic>)['entities'] as List;
      expect((entities.firstWhere((e) => (e as Map)['id'] == sp.id) as Map)['z'], 321);
      expect(c.dirty, isFalse);
      // the file chooser of the desktop build
      appNavigatorKey.currentState?.pop();
      await settle(tester);
    });
  });

  group('UI-05 the phone menu has tabs, recent projects and the desktop toggles', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
    }

    Finder sheetList() => find.descendant(of: find.byKey(const Key('mobile_menu_sheet')), matching: find.byType(Scrollable)).first;

    testWidgets('the open tabs are listed, switched and closed; the recent projects open', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(390, 844));
      final ws = shell.ws as Workspace;
      final first = ws.current;
      first.addEntity(LineEntity(id: first.project.newId(), a: Pt.zero, b: const Pt(25, 0)));
      first.project.meta.name = 'Horta';
      first.saveJson(); // kept in this browser: a recent project
      ws.addTab();
      await settle(tester);
      expect(ws.active, 1);
      await openMenu(tester);
      expect(find.byKey(const Key('mobile_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('mobile_tab_1')), findsOneWidget);
      expect(find.text('Horta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile_tab_0')));
      await settle(tester);
      expect(ws.active, 0, reason: 'back to the first tab without a keyboard');
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('mobile_tab_close_1')));
      await settle(tester);
      expect(ws.tabs, hasLength(1));
      // the recent project opens (already open: its tab is selected)
      ws.addTab();
      await settle(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('mobile_menu_recent')));
      await settle(tester);
      await tester.tap(find.byKey(Key('mobile_recent_${first.project.meta.uid}')));
      await settle(tester);
      expect(identical(ws.current, first), isTrue);
    });

    testWidgets('grid snap, polar tracking, edit grips, autosave and the terrain method', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(390, 844));
      final ProjectController c = shell.c;
      Future<void> tapItem(String section, String label) async {
        await openMenu(tester);
        await tester.scrollUntilVisible(find.text(section), 200, scrollable: sheetList());
        await tester.tap(find.text(section));
        await settle(tester);
        await tester.scrollUntilVisible(find.text(label), 200, scrollable: sheetList());
        await tester.ensureVisible(find.text(label));
        await settle(tester, 1);
        await tester.tap(find.text(label));
        await settle(tester);
      }

      final grid = c.snap.grid, grips = c.showGrips, autosave = c.autosaveEnabled, polar = c.snap.polarStepDeg;
      await tapItem(c.t('menu.view'), c.t('mob.gridSnap'));
      expect(c.snap.grid, !grid);
      await tapItem(c.t('menu.view'), c.t('view.grips'));
      expect(c.showGrips, !grips);
      await tapItem(c.t('menu.view'), c.t('mob.polar', {'s': polar > 0 ? '${polar.round()}°' : c.t('mob.off')}));
      expect(c.snap.polarStepDeg, isNot(polar));
      await tapItem(c.t('menu.file'), c.t('file.autosave'));
      expect(c.autosaveEnabled, !autosave);
      await tapItem(c.t('menu.design'), c.t('terrain.idw'));
      expect(c.project.params.terrainMethod.name, 'idw');
    });
  });

  group('UI-06 commands, coordinates and lengths without a physical keyboard', () {
    testWidgets('the ⌨ field of the phone draws a 25 m line from typed points', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(390, 844));
      final ProjectController c = shell.c;
      await tester.tap(find.byKey(const Key('mobile_command')));
      await settle(tester);
      expect(find.byKey(const Key('command_entry')), findsOneWidget);
      final field = find.byKey(const Key('command_entry_field'));
      Future<void> run(String text) async {
        await tester.enterText(field, text);
        await tester.tap(find.byKey(const Key('command_entry_run')));
        await settle(tester, 2);
      }

      await run('l');
      expect(c.activeTool, ToolId.line, reason: 'an alias runs as Enter would');
      await run('0,0');
      // the keys the numeric keyboard lacks
      await tester.tap(find.byKey(const Key('command_key_@')));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '@');
      await tester.enterText(field, '@25<0');
      await tester.tap(find.byKey(const Key('command_entry_run')));
      await settle(tester, 2);
      final line = c.project.entities.whereType<LineEntity>().single;
      expect(line.length, closeTo(25, 1e-9));
      await tester.tap(find.byKey(const Key('command_entry_close')));
      await settle(tester);
      expect(find.byKey(const Key('command_entry')), findsNothing);
    });

    testWidgets('the length of a line or a pipe is typed in its properties', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
      c.addEntity(line);
      c.select([line.id]);
      await settle(tester);
      final field = find.descendant(of: find.byKey(const Key('props_length')), matching: find.byType(TextField));
      await tester.enterText(field, '25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect((c.project.byId(line.id) as LineEntity).length, closeTo(25, 1e-9));
      expect((c.project.byId(line.id) as LineEntity).b, const Pt(25, 0));
      // a length the last segment cannot give is refused with a message
      final pipe = PipeEntity(id: c.project.newId(), scope: HydraulicScope.mainline, points: [const Pt(0, 10), const Pt(30, 10), const Pt(30, 20)]);
      c.addEntity(pipe);
      c.select([pipe.id]);
      await settle(tester);
      await tester.enterText(field, '35');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect((c.project.byId(pipe.id) as PipeEntity).points.last, const Pt(30, 15));
      await tester.enterText(field, '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(c.lastMessage, c.t('props.lengthNo'));
      expect((c.project.byId(pipe.id) as PipeEntity).length, closeTo(35, 1e-9));
      expect(endForLength(const [Pt.zero, Pt.zero], 5), isNull);
    });
  });

  group('UI-07 the layout follows the width, the height and the pointer', () {
    tearDown(() => lastPointerKind.value = null);

    test('the arrangement of each kind of screen', () {
      expect(shellLayoutFor(const Size(390, 844), touch: true), ShellLayout.phone);
      expect(shellLayoutFor(const Size(844, 390), touch: true), ShellLayout.phone, reason: 'a phone held sideways');
      expect(shellLayoutFor(const Size(844, 390), touch: false), ShellLayout.narrow, reason: 'a low desktop window with a mouse');
      expect(shellLayoutFor(const Size(768, 1024), touch: true), ShellLayout.narrow, reason: 'a tablet in portrait');
      expect(shellLayoutFor(const Size(1280, 800), touch: true), ShellLayout.wide);
      expect(shellLayoutFor(const Size(650, 900), touch: false), ShellLayout.phone);
      lastPointerKind.value = PointerDeviceKind.mouse;
      expect(touchInput, isFalse);
      lastPointerKind.value = PointerDeviceKind.touch;
      expect(touchInput, isTrue);
    });

    testWidgets('a phone held sideways gets the touch layout', (tester) async {
      await pumpFresh(tester, size: const Size(844, 390));
      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.byKey(const Key('mobile_done')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet in portrait keeps the drawing: the side panel is a drawer, the assistant a sheet', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(768, 1024));
      final ProjectController c = shell.c;
      expect(find.byType(MobileShell), findsNothing);
      expect(find.byType(PropertiesPanel), findsNothing, reason: 'folded away');
      expect(tester.getSize(find.byKey(const ValueKey('canvas1'))).width, greaterThan(600));
      await tester.tap(find.byKey(const Key('side_drawer_open')));
      await settle(tester);
      expect(find.byType(PropertiesPanel), findsOneWidget);
      await tester.tap(find.byKey(const Key('side_drawer_close')));
      await settle(tester);
      expect(find.byType(PropertiesPanel), findsNothing);
      // the assistant opens over the drawing, never docked beside it
      showAiAssistantDialog(tester.element(find.byType(MenuBar)), c);
      await settle(tester);
      expect(AiAssistant.panelOpen.value, isFalse);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('canvas1'))).width, greaterThan(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the menus that do not fit go under ⋯', (tester) async {
      await pumpFresh(tester, size: const Size(900, 1000));
      expect(find.byKey(const Key('menu_more')), findsOneWidget);
      expect(find.text('Ajuda'), findsNothing, reason: 'the last menu is under ⋯');
      await tester.tap(find.byKey(const Key('menu_more')));
      await settle(tester);
      expect(find.text('Ajuda'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // a wide window shows them all
      tester.view.physicalSize = const Size(1920, 1080);
      await settle(tester);
      expect(find.byKey(const Key('menu_more')), findsNothing);
    });

    testWidgets('on a low window the reports leave the drawing room', (tester) async {
      lastPointerKind.value = PointerDeviceKind.mouse;
      final shell = await pumpFresh(tester, size: const Size(1280, 480));
      final ProjectController c = shell.c;
      c.showReports = true;
      c.refresh();
      await settle(tester);
      expect(find.byType(MobileShell), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('canvas1'))).height, greaterThan(120));
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-29 the status bar shows the real scale of the screen', () {
    test('4 pixels per metre on a 96 dpi screen is about 1:945, not 1:25', () {
      // one metre takes 4 px × 0.2646 mm = 1.058 mm
      expect(screenScaleDenominator(4), closeTo(944.88, 0.01));
      expect(screenScaleDenominator(1000 / 0.2645833), closeTo(1, 1e-3));
    });

    testWidgets('the status bar reads it', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      c.camera.scale = 4;
      c.refresh();
      await settle(tester);
      expect(find.textContaining('1:945'), findsOneWidget);
    });
  });

  group('UI-08 / UI-09 / UI-32 number fields', () {
    late String lang;
    setUp(() => lang = uiLanguage.value);
    tearDown(() => uiLanguage.value = lang);

    Future<List<double>> pumpField(WidgetTester tester, double value, {int decimals = 2, bool mixed = false}) async {
      final got = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCadTheme(),
          home: Scaffold(
            body: Column(
              children: [
                NumField(key: const Key('f'), label: 'x', value: value, decimals: decimals, mixed: mixed, onChanged: got.add),
                const TextField(key: Key('other')),
              ],
            ),
          ),
        ),
      );
      return got;
    }

    Finder field() => find.descendant(of: find.byKey(const Key('f')), matching: find.byType(TextField));
    String text(WidgetTester tester) => tester.widget<TextField>(field()).controller!.text;

    testWidgets('Portuguese: the decimal comma on screen, "2.000" is two thousand and the other reading one tap away', (tester) async {
      uiLanguage.value = 'pt';
      final got = await pumpField(tester, 12.5);
      expect(text(tester), '12,50');
      await tester.enterText(field(), '2.000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got, [2000], reason: 'it was read as 2');
      expect(find.byKey(const Key('num_alternative')), findsOneWidget);
      await tester.tap(find.byKey(const Key('num_alternative')));
      await tester.pump();
      expect(got, [2000, 2]);
      expect(find.byKey(const Key('num_alternative')), findsNothing);
      // a decimal comma is plain
      await tester.enterText(field(), '3,25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got.last, 3.25);
      expect(find.byKey(const Key('num_alternative')), findsNothing);
    });

    testWidgets('English: "1,500" is one thousand five hundred', (tester) async {
      uiLanguage.value = 'en';
      final got = await pumpField(tester, 1);
      await tester.enterText(field(), '1,500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got, [1500]);
      expect(find.textContaining('1.5'), findsOneWidget, reason: 'the other reading offered');
    });

    testWidgets('UI-09 focusing a field and leaving it without typing writes nothing', (tester) async {
      uiLanguage.value = 'pt';
      // 15 m of head in bar: 1.471 shows as 1,47
      final got = await pumpField(tester, 1.4710);
      expect(text(tester), '1,47');
      await tester.tap(field());
      await tester.pump();
      await tester.tap(find.byKey(const Key('other')));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got, isEmpty, reason: 'the rounded 1,47 must not replace 1,471');
      // small values keep three significant digits
      expect(formatFieldNumber(0.004, 2, 'pt'), '0,004');
      expect(formatFieldNumber(0.0471, 2, 'en'), '0.0471');
      expect(formatFieldNumber(5, 2, 'pt'), '5,0');
      expect(formatFieldNumber(2.5, 2, 'en'), '2.50');
    });

    testWidgets('UI-32 mixed values: an empty field with a hint, and 0 typed applies', (tester) async {
      uiLanguage.value = 'pt';
      final got = await pumpField(tester, 0, mixed: true);
      expect(text(tester), '');
      expect(find.text('(valores diferentes)'), findsOneWidget);
      await tester.enterText(field(), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got, [0]);
    });
  });

  group('properties: the item, the sizing, fractions, units and mixed values', () {
    Finder field(String prefix) => find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith(prefix));

    Future<void> type(WidgetTester tester, String prefix, String value) async {
      final f = field(prefix).first;
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(f, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 2);
    }

    Future<void> pick(WidgetTester tester, String label, String? id) async {
      final f = find.byWidgetPredicate((w) => w is SpecDropdown && w.label == label);
      (tester.widget(f.first) as SpecDropdown).onChanged(id);
      await settle(tester, 2);
    }

    testWidgets('UI-10 an emitter switched off in the catalogue still shows as itself, marked', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      final cat = c.project.catalog;
      final spec = cat.outlets.firstWhere((o) => o.enabled && o.nozzles.isNotEmpty);
      final o = OutletEntity(id: c.project.newId(), position: Pt.zero, outletSpecId: spec.id);
      c.addEntity(o);
      c.select([o.id]);
      spec.enabled = false;
      c.refresh();
      await settle(tester);
      expect(find.text('${spec.name} (desativado)'), findsOneWidget, reason: 'not the first emitter of the list');
      // one gone from the catalogue: its id, marked
      cat.outlets.remove(spec);
      c.refresh();
      await settle(tester);
      expect(find.text('${spec.id} (fora do catálogo)'), findsOneWidget);
    });

    testWidgets('UI-11 choosing a pipe fixes it: the automatic sizing switch goes off', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      final pipe = PipeEntity(id: c.project.newId(), scope: HydraulicScope.mainline, points: [Pt.zero, const Pt(50, 0)]);
      c.addEntity(pipe);
      c.select([pipe.id]);
      await settle(tester);
      expect(pipe.computerSized, isTrue);
      final spec = c.project.catalog.pipesFor(PipeUsage.mainline)[1];
      await pick(tester, c.t('props.pipe'), spec.id);
      final now = c.project.byId(pipe.id) as PipeEntity;
      expect(now.pipeSpecId, spec.id);
      expect(now.computerSized, isFalse, reason: 'the next design would replace the pipe chosen');
      await pick(tester, c.t('props.pipe'), null);
      expect((c.project.byId(pipe.id) as PipeEntity).computerSized, isTrue);
    });

    testWidgets('UI-12 85 typed as an efficiency is 85 %, and a cut value says so', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      final a = AreaEntity(id: c.project.newId(), points: [Pt.zero, const Pt(20, 0), const Pt(20, 20), const Pt(0, 20)]);
      c.addEntity(a);
      c.select([a.id]);
      await settle(tester);
      expect(field('Eficiência (0–1)'), findsOneWidget, reason: 'the range is in the label');
      await type(tester, 'Eficiência', '85');
      expect((c.project.byId(a.id) as AreaEntity).efficiency, closeTo(0.85, 1e-12));
      await type(tester, 'Eficiência', '0,01');
      expect((c.project.byId(a.id) as AreaEntity).efficiency, 0.05);
      expect(c.lastMessage, contains('0,05'), reason: 'the cut is told');
    });

    testWidgets('UI-21 with US units the depth and the riser are in feet', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      c.project.params.units = Units.us;
      final pipe = PipeEntity(id: c.project.newId(), scope: HydraulicScope.zone, points: [Pt.zero, const Pt(10, 0)])..depth = 0.3048;
      c.addEntity(pipe);
      c.select([pipe.id]);
      await settle(tester);
      expect(field('Profundidade (ft)'), findsOneWidget);
      expect(tester.widget<TextField>(field('Profundidade (ft)')).controller!.text, '1,0');
      await type(tester, 'Profundidade', '2');
      expect((c.project.byId(pipe.id) as PipeEntity).depth, closeTo(0.6096, 1e-9));
    });

    testWidgets('UI-32 batch editing: different depths show an empty field, and 0 typed applies to all', (tester) async {
      final shell = await pumpFresh(tester);
      final ProjectController c = shell.c;
      final a = PipeEntity(id: c.project.newId(), scope: HydraulicScope.zone, points: [Pt.zero, const Pt(10, 0)])..depth = 0.5;
      final b = PipeEntity(id: c.project.newId(), scope: HydraulicScope.zone, points: [const Pt(0, 5), const Pt(10, 5)])..depth = 0.8;
      c.addEntity(a);
      c.addEntity(b);
      c.select([a.id, b.id]);
      await settle(tester);
      final f = field('Profundidade');
      expect(tester.widget<TextField>(f).controller!.text, '', reason: 'not a 0 that reads as a value');
      await type(tester, 'Profundidade', '0');
      expect([(c.project.byId(a.id) as PipeEntity).depth, (c.project.byId(b.id) as PipeEntity).depth], [0, 0]);
    });
  });
}
