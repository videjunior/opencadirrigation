import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/file_io.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/more_dialogs.dart';
import 'package:opencadirrigation/core/io/project_export.dart' show DrawingFormat, ReportFormat;
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Interface flows the other widget tests do not reach: the automatic
/// correction and optimisation dialogs, pump selection, image
/// georeference, currency conversion, the catalogue editor tabs, version
/// restore, polar arrays, keyboard shortcuts for files and the assistant,
/// the desktop file browser and the export guards.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  late dynamic shell;
  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = true}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    if (!example) c.newProject();
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

  Future<void> openMenu(WidgetTester tester, String top, String item) async {
    await tester.tap(find.text(top).first);
    await settle(tester, 2);
    await tester.tap(find.text(item).last);
    await settle(tester, 3);
  }

  Future<void> enterField(WidgetTester tester, String label, String value) async {
    final f = find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(TextField, label)).first;
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(AppShell));

  /// Waits for [f], which ends with real file I/O: lets the I/O run outside
  /// the fake clock and pumps so its callbacks are delivered.
  Future<T> resolve<T>(WidgetTester tester, Future<T> f) async {
    late T value;
    var done = false;
    f.then((v) {
      value = v;
      done = true;
    });
    for (var i = 0; i < 100 && !done; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(done, isTrue, reason: 'the file operation did not finish');
    return value;
  }

  testWidgets('fix automatically: progress, the summary of what was done and undo all', (tester) async {
    final c = await pumpShell(tester);
    final pump = c.project.entities.whereType<PumpEntity>().first;
    c.select([pump.id]);
    c.moveSelected(const Pt(0, 0.8));
    c.showReports = true;
    c.reportTab = ProjectController.messagesReportTab;
    c.refresh();
    await settle(tester);
    expect(c.advice.where((a) => a.code == 'unconnected'), isNotEmpty);
    await tester.tap(find.byKey(const Key('advice_fix_all')));
    await tester.pump();
    expect(find.text('Corrigir automaticamente'), findsWidgets, reason: 'the progress dialog');
    await until(tester, () => find.text('Correção automática').evaluate().isNotEmpty);
    expect(find.textContaining('correção(ões) aplicada(s)'), findsOneWidget);
    expect(c.advice.where((a) => a.code == 'unconnected'), isEmpty);
    await tester.tap(find.text('Desfazer tudo'));
    await settle(tester);
    expect(find.text('Correção automática'), findsNothing);
    expect(c.advice.where((a) => a.code == 'unconnected'), isNotEmpty, reason: 'one undo brings everything back');
  });

  testWidgets('optimise: the before/after table, then close', (tester) async {
    final c = await pumpShell(tester);
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    await tester.tap(find.text('Projeto').first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_optimize')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('opt_run')));
    await tester.pump();
    await until(tester, () => find.text('Investimento').evaluate().isNotEmpty);
    for (final label in ['Antes', 'Depois', 'Investimento', 'Energia por ano', 'Custo anual total', 'Erros / avisos']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final cur = c.project.params.currency;
    expect(find.textContaining('$cur '), findsWidgets, reason: 'money cells carry the currency');
    final undo = find.text('Desfazer otimização');
    if (undo.evaluate().isNotEmpty) {
      final history = c.historyEntries.length;
      await tester.tap(undo);
      await settle(tester);
      expect(c.historyEntries.length, lessThanOrEqualTo(history));
    } else {
      await tester.tap(find.text('Fechar').last);
      await settle(tester);
    }
    expect(find.text('Investimento'), findsNothing);
  });

  testWidgets('pump selection replaces the pump near the supply', (tester) async {
    final c = await pumpShell(tester);
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    await openMenu(tester, 'Linha principal', 'Selecionar bomba…');
    final apply = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('pump_apply_'));
    expect(apply, findsWidgets);
    final key = tester.widget(apply.first).key as ValueKey<String>;
    final specId = key.value.substring('pump_apply_'.length);
    expect(find.text('Aplicar à bomba existente'), findsWidgets);
    await tester.ensureVisible(apply.first);
    await tester.tap(apply.first);
    await settle(tester);
    expect(c.project.entities.whereType<PumpEntity>().first.pumpSpecId, specId);
    expect(c.lastMessage, startsWith('Bomba '));
  });

  testWidgets('pump selection inserts a pump on the mainline leaving the supply', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.project = buildExample(ExampleId.garden, c.t.call, lang: 'pt');
    final s = c.project.entities.whereType<WaterSupplyEntity>().first
      ..designHeadM = 5
      ..maxHeadM = 40;
    c.refresh();
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    expect(c.project.entities.whereType<PumpEntity>(), isEmpty);
    await openMenu(tester, 'Linha principal', 'Selecionar bomba…');
    final apply = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('pump_apply_'));
    expect(find.text('Inserir na fonte'), findsWidgets);
    await tester.ensureVisible(apply.first);
    await tester.tap(apply.first);
    await settle(tester);
    final pump = c.project.entities.whereType<PumpEntity>().single;
    expect(pump.position.distanceTo(s.position), closeTo(1.5, 0.01), reason: '1.5 m along the pipe leaving the supply');
    expect(pump.scope, HydraulicScope.mainline);
  });

  testWidgets('image georeference: position, width with the aspect kept, rotation', (tester) async {
    final c = await pumpShell(tester, example: false);
    showImageGeorefDialog(ctx(tester), c);
    await settle(tester);
    expect(c.lastMessage, 'Nada selecionado');
    final img = ImageEntity(id: c.project.newId(), origin: Pt.zero, width: 20, height: 10, data: Uint8List(1));
    c.addEntity(img);
    c.select([img.id]);
    showImageGeorefDialog(ctx(tester), c);
    await settle(tester);
    expect(find.text('Georreferenciar imagem'), findsOneWidget);
    await enterField(tester, 'X (m)', '5');
    await enterField(tester, 'Y (m)', '-3');
    await enterField(tester, 'Largura (m) ', '40');
    await enterField(tester, 'Rotação (°)', '15');
    await tester.tap(find.text('OK').last);
    await settle(tester);
    expect(img.origin, const Pt(5, -3));
    expect(img.width, 40);
    expect(img.height, 20, reason: 'the aspect ratio is kept');
    expect(img.rotationDeg, 15);
    c.undo();
    expect((c.project.byId(img.id) as ImageEntity).width, 20, reason: 'one undo step (the project is restored from a snapshot)');
  });

  testWidgets('currency change: convert, change only the symbol or cancel', (tester) async {
    final c = await pumpShell(tester);
    Future<(bool, double, String)?> ask(String button) async {
      final f = askCurrencyConversion(ctx(tester), c, 'BRL', 'USD');
      await settle(tester);
      expect(find.text('Converter os preços?'), findsOneWidget);
      if (button.isNotEmpty) {
        await tester.tap(find.byKey(Key(button)));
      } else {
        await tester.tap(find.text('Cancelar').last);
      }
      await settle(tester);
      return f;
    }

    final convert = await ask('cur_convert');
    expect(convert!.$1, isTrue);
    expect(convert.$2, closeTo(exchangeRate('BRL', 'USD')!, 1e-9));
    expect(convert.$3, 'BRL');
    final only = await ask('cur_only');
    expect(only!.$1, isFalse);
    expect(await ask(''), isNull);
    // an edited rate is used
    final f = askCurrencyConversion(ctx(tester), c, 'BRL', 'XYZ');
    await settle(tester);
    expect(find.textContaining('sem taxa'), findsNothing);
    await tester.enterText(find.byKey(const Key('cur_rate')), '2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('cur_convert')));
    await settle(tester);
    expect((await f)!.$2, 2);
  });

  testWidgets('catalogue editor: add on every tab, save as default and restore', (tester) async {
    final c = await pumpShell(tester);
    final cat = c.project.catalog;
    await openMenu(tester, 'Projeto', 'Catálogo de componentes…');
    final counts = <String, int Function()>{
      'Emissores': () => cat.outlets.length,
      'Fitas': () => cat.tapes.length,
      'Válvulas': () => cat.valves.length,
      'Bombas': () => cat.pumps.length,
      'Conexões': () => cat.fittings.length,
    };
    for (final e in counts.entries) {
      await tester.tap(find.text(e.key).last);
      await settle(tester, 2);
      final before = e.value();
      await tester.tap(find.byKey(const Key('cat_add')));
      await settle(tester, 2);
      expect(e.value(), before + 1, reason: e.key);
    }
    expect(cat.pumps.last.curve.head(0), greaterThan(0), reason: 'a new pump has a curve');
    removePref('catalog.default');
    await tester.tap(find.text('Usar como padrão para novos projetos'));
    await settle(tester, 2);
    expect(getPref('catalog.default'), isNotNull);
    expect(c.lastMessage, 'Catálogo salvo como padrão para novos projetos');
    await tester.tap(find.text('Restaurar padrão'));
    await settle(tester, 2);
    if (find.byType(AlertDialog).evaluate().length > 1) {
      await tester.tap(find.text('OK').last);
      await settle(tester, 2);
    }
    expect(getPref('catalog.default'), isNull);
    expect(cat.outlets.length, counts['Emissores']!() , reason: 'restored');
    expect(c.lastMessage, 'Catálogo padrão restaurado');
    removePref('catalog.default');
    removePref('catalog.default.currency');
  });

  testWidgets('version history restores an older save', (tester) async {
    final c = await pumpShell(tester);
    final n = c.project.entities.length;
    c.saveJson();
    c.addEntity(CircleEntity(id: c.project.newId(), center: Pt.zero, radius: 2));
    c.saveJson();
    await openMenu(tester, 'Arquivo', 'Histórico de versões…');
    expect(find.byKey(const Key('ver_restore_1')), findsOneWidget);
    expect(find.byKey(const Key('ver_restore_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ver_restore_1')));
    await settle(tester);
    expect(c.project.entities.length, n);
    expect(c.dirty, isTrue);
    expect(c.lastMessage, 'Versão 1 restaurada');
  });

  testWidgets('polar array: count, total angle and centre', (tester) async {
    final c = await pumpShell(tester, example: false);
    showArrayDialog(ctx(tester), c);
    await settle(tester);
    expect(c.lastMessage, 'Nada selecionado');
    final circle = CircleEntity(id: c.project.newId(), center: const Pt(10, 0), radius: 1);
    c.addEntity(circle);
    c.select([circle.id]);
    showArrayDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text('Polar'));
    await settle(tester, 2);
    await enterField(tester, 'Número de itens', '6');
    await enterField(tester, 'Ângulo total (°)', '180');
    await enterField(tester, 'Centro (X, Y) X', '0');
    await enterField(tester, 'Centro (X, Y) Y', '0');
    await tester.tap(find.byKey(const Key('array_ok')));
    await settle(tester);
    final circles = c.project.entities.whereType<CircleEntity>().toList();
    expect(circles.length, 6);
    expect(circles.last.center.x, closeTo(-10, 1e-6), reason: 'the last copy at 180°');
    expect(circles.every((e) => (e.center.distanceTo(Pt.zero) - 10).abs() < 1e-6), isTrue);
  });

  testWidgets('keyboard: files, PDF, design, tabs, the assistant and Esc on a menu', (tester) async {
    final c = await pumpShell(tester);
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    Future<void> ctrl(LogicalKeyboardKey key, String ch, {bool alt = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key, character: ch);
      if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester, 3);
    }

    for (final (key, ch, title) in [(LogicalKeyboardKey.keyS, 's', 'Save as'), (LogicalKeyboardKey.keyO, 'o', 'Open'), (LogicalKeyboardKey.keyI, 'i', 'Open')]) {
      await ctrl(key, ch);
      expect(find.text(title), findsWidgets, reason: 'Ctrl+$ch (the title; Open is also the button)');
      await tester.tap(find.text('Cancel'));
      await settle(tester, 3);
    }
    await ctrl(LogicalKeyboardKey.keyP, 'p');
    expect(find.text('Exportar PDF (prancha)'), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await settle(tester);
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await until(tester, () => !c.busy && c.results != null);
    expect(c.results, isNotNull);
    await ctrl(LogicalKeyboardKey.keyN, 'n', alt: true);
    expect(shell.ws.tabs.length, 2);
    await ctrl(LogicalKeyboardKey.arrowRight, '', alt: true);
    expect(shell.ws.active, 0, reason: 'next wraps around');
    await ctrl(LogicalKeyboardKey.arrowRight, '', alt: true);
    expect(shell.ws.active, 1);
    await ctrl(LogicalKeyboardKey.keyW, 'w', alt: true);
    expect(shell.ws.tabs.length, 1);
    // typed commands for the assistant
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    for (final ch in 'opt'.split('')) {
      await tester.sendKeyEvent(LogicalKeyboardKey(ch.codeUnitAt(0)), character: ch);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byKey(const Key('opt_run')), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await settle(tester);
    // Esc closes an open menu (a dismissible popup) even without focus in it
    await tester.tap(find.text('Ver').first);
    await settle(tester, 2);
    expect(find.text('Enquadrar tudo'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, 2);
    expect(find.text('Enquadrar tudo'), findsNothing);
  });

  testWidgets('a cancelled pointer leaves no drag behind', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.addEntity(LineEntity(id: 'l', a: const Pt(0, 0), b: const Pt(10, 0)));
    c.camera.center = const Pt(5, 0);
    c.camera.scale = 20;
    c.refresh();
    await settle(tester, 1);
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    final at = box.localToGlobal(c.camera.toScreen(const Pt(5, 0)));
    final g = await tester.startGesture(at);
    await g.moveBy(const Offset(40, 40));
    await tester.pump();
    await g.cancel();
    await settle(tester, 1);
    expect((c.project.byId('l') as LineEntity).a, Pt.zero, reason: 'nothing moved');
    // the next press starts afresh
    await tester.tapAt(at);
    await settle(tester, 1);
    expect(c.selection, {'l'});
  });

  testWidgets('desktop file browser: filter, folders, up, pick to save and open', (tester) async {
    await pumpShell(tester, example: false);
    final dir = Directory.systemTemp.createTempSync('oci_browser');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/a.json').writeAsStringSync('{"x":1}');
    File('${dir.path}/b.txt').writeAsStringSync('no');
    File('${dir.path}/sub/c.json').writeAsStringSync('{"y":2}');
    setPref('desktop.dir', dir.path);
    // open: only the accepted extension is listed
    final opened = openTextFile(accept: '.json');
    await settle(tester);
    expect(find.text('a.json'), findsOneWidget);
    expect(find.text('b.txt'), findsNothing);
    await tester.tap(find.text('sub'));
    await settle(tester, 2);
    expect(find.text('c.json'), findsOneWidget);
    await tester.tap(find.byTooltip('..'));
    await settle(tester, 2);
    expect(find.text('a.json'), findsOneWidget);
    // typing a folder path goes there
    final pathField = find.widgetWithText(TextField, 'Folder');
    await tester.enterText(pathField, '${dir.path}/sub');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    expect(find.text('c.json'), findsOneWidget);
    await tester.tap(find.text('c.json'));
    await settle(tester, 2);
    final r = await resolve(tester, opened);
    expect(r!.$1, 'c.json');
    expect(r.$2, '{"y":2}');
    expect(getPref('desktop.dir'), '${dir.path}/sub', reason: 'the folder is remembered');
    // save: a tap on a file takes its name; Save overwrites it
    setPref('desktop.dir', dir.path);
    final saved = saveTextFile('novo.json', '{"z":3}');
    await settle(tester);
    expect(find.text('Save as'), findsOneWidget);
    await tester.tap(find.text('a.json'));
    await settle(tester, 1);
    expect(tester.widget<TextField>(find.byKey(const Key('desktop_filename'))).controller!.text, 'a.json');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester, 2);
    await resolve(tester, saved);
    expect(File('${dir.path}/a.json').readAsStringSync(), '{"z":3}');
    // open with a name that does not exist stays open; binary open of an existing file
    final bin = openBinaryFile(accept: '');
    await settle(tester);
    expect(find.text('b.txt'), findsOneWidget, reason: 'no filter: everything');
    await tester.enterText(find.byKey(const Key('desktop_filename')), 'missing.bin');
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester, 1);
    expect(find.byKey(const Key('desktop_filename')), findsOneWidget, reason: 'a missing file is not accepted');
    await tester.enterText(find.byKey(const Key('desktop_filename')), 'b.txt');
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester, 2);
    final b = await resolve(tester, bin);
    expect(String.fromCharCodes(b!.$2), 'no');
    removePref('desktop.dir');
  });

  testWidgets('file actions through the desktop dialog: open, import, export DXF and the report CSV', (tester) async {
    final c = await pumpShell(tester);
    final dir = Directory.systemTemp.createTempSync('oci_actions');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pomar.oci.json').writeAsStringSync(c.saveJson());
    File('${dir.path}/ruim.oci.json').writeAsStringSync('{"format": "outro"}');
    File('${dir.path}/linha.dxf').writeAsStringSync(c.exportDxf());
    setPref('desktop.dir', dir.path);
    Future<void> pick(Future<void> action, String name, String button) async {
      await settle(tester);
      await tester.enterText(find.byKey(const Key('desktop_filename')), name);
      await tester.tap(find.widgetWithText(FilledButton, button));
      await settle(tester, 2);
      await resolve(tester, action);
      await settle(tester, 2);
    }

    final n = c.project.entities.length;
    c.newProject();
    await pick(openProjectAction(ctx(tester), c), 'pomar.oci.json', 'Open');
    expect(c.project.entities.length, n);
    await pick(openProjectAction(ctx(tester), c), 'ruim.oci.json', 'Open');
    expect(c.lastMessage, startsWith('Erro'));
    expect(c.project.entities.length, n, reason: 'a bad file leaves the project as it was');
    await pick(importDxfAction(ctx(tester), c), 'linha.dxf', 'Open');
    expect(c.lastMessage, startsWith('Importado: '));
    expect(c.project.entities.length, greaterThan(n));
    await pick(exportDxfAction(ctx(tester), c), '${dir.path}/saida.dxf', 'Save');
    expect(File('${dir.path}/saida.dxf').readAsStringSync(), contains('ENTITIES'));
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    await pick(exportCsvAction(ctx(tester), c), '${dir.path}/relatorio.csv', 'Save');
    expect(File('${dir.path}/relatorio.csv').readAsStringSync(), contains('LISTA DE MATERIAIS'));
    removePref('desktop.dir');
  });

  testWidgets('an area takes its crop coefficient from the FAO-56 list', (tester) async {
    final c = await pumpShell(tester);
    final area = c.project.entities.whereType<AreaEntity>().first
      ..crop = ''
      ..useWaterBalance = false;
    c.select([area.id]);
    c.refresh();
    await settle(tester);
    final field = find.text('Kc por cultura (FAO-56)');
    await tester.ensureVisible(field);
    await settle(tester, 1);
    await tester.tap(find.text('Personalizado').first);
    await settle(tester, 2);
    await tester.tap(find.text('Citros (Kc 0.65)').last);
    await settle(tester, 2);
    expect(area.kc, 0.65);
    expect(area.useWaterBalance, isTrue);
    expect(area.crop, 'Citros', reason: 'an empty crop name takes the preset name');
    expect(c.canUndo, isTrue);
  });

  testWidgets('export guards: an empty drawing, a report without results, a schedule without areas, new project confirmation', (tester) async {
    final c = await pumpShell(tester, example: false);
    await exportDrawingAction(ctx(tester), c, DrawingFormat.dxf);
    expect(c.lastMessage, 'O desenho está vazio');
    await exportReportAction(ctx(tester), c, ReportFormat.csv);
    expect(c.lastMessage, 'Execute o projeto (F5) antes de exportar o relatório');
    await exportScheduleAction(ctx(tester), c);
    expect(c.lastMessage, startsWith('Desenhe áreas irrigadas'));
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 1)));
    expect(c.dirty, isTrue);
    final first = confirmNew(ctx(tester), c);
    await settle(tester);
    expect(find.text('O projeto atual tem alterações não salvas. Continuar?'), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await settle(tester);
    await first;
    expect(c.project.entities.length, 1, reason: 'cancel keeps the drawing');
    final second = confirmNew(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text('OK').last);
    await settle(tester);
    await second;
    expect(c.project.entities, isEmpty);
    expect(c.dirty, isFalse);
    // a clean project is replaced without asking
    await confirmNew(ctx(tester), c);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
