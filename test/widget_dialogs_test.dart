import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/more_dialogs.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Every dialog of the app opened through the menus, with its main
/// interactions (fields, tabs, buttons) and the effect on the project.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  late dynamic shell;
  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = true, bool design = false}) async {
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
    c.autosaveEnabled = false;
    c.snap.enabled = false;
    if (!example) c.newProject();
    if (design) {
      // the design runs real async work: outside the fake-async test zone
      await tester.runAsync(() => c.runDesign());
    }
    await settle(tester);
    return c;
  }

  Future<void> openMenu(WidgetTester tester, String top, String item) async {
    await tester.tap(find.text(top).first);
    await settle(tester, 2);
    await tester.tap(find.text(item).last);
    await settle(tester, 3);
  }

  /// Text field of the open dialog (falls back to the whole tree).
  Future<void> enterField(WidgetTester tester, String label, String value) async {
    final inDialog = find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(TextField, label));
    final f = (inDialog.evaluate().isNotEmpty ? inDialog : find.widgetWithText(TextField, label)).first;
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await settle(tester, 3);
  }

  Offset screenOf(WidgetTester tester, ProjectController c, Pt world) {
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    return box.localToGlobal(c.camera.toScreen(world));
  }

  Future<void> clickWorld(WidgetTester tester, ProjectController c, Pt world) async {
    await tester.tapAt(screenOf(tester, c, world));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('design parameters: OK keeps results when nothing changed and clears them on edit', (tester) async {
    final c = await pumpShell(tester, design: true);
    expect(c.results, isNotNull);
    await openMenu(tester, 'Projeto', 'Parâmetros de projeto…');
    expect(find.text('Parâmetros de projeto…'), findsWidgets);
    await tapText(tester, 'OK');
    expect(c.results, isNotNull, reason: 'unchanged parameters must not discard results');
    await openMenu(tester, 'Projeto', 'Parâmetros de projeto…');
    await enterField(tester, 'Temperatura da água (°C)', '25');
    await tapText(tester, 'OK');
    expect(c.project.params.waterTempC, 25);
    expect(c.results, isNull);
  });

  testWidgets('management dialog adds a flow and shows the controller programme', (tester) async {
    final c = await pumpShell(tester, design: true);
    final before = c.project.systemFlows.length;
    await openMenu(tester, 'Projeto', 'Turnos de operação (management)…');
    await tapText(tester, '+ Turno');
    expect(c.project.systemFlows.length, before + 1);
    await tapText(tester, 'Programação do controlador');
    expect(find.text('Dias'), findsWidgets);
    await tapText(tester, 'Turnos');
    await tapText(tester, 'OK');
    expect(find.text('Turnos de operação (management)…'), findsNothing);
  });

  testWidgets('calculators: lateral, pump and water hammer react to input', (tester) async {
    final c = await pumpShell(tester);
    await openMenu(tester, 'Ferramentas', 'Calculadora de lateral…');
    expect(find.text(c.t('dlg.results').toUpperCase()), findsOneWidget);
    await enterField(tester, 'Comprimento (m)', '60');
    await tapText(tester, 'Lateral com emissores');
    expect(find.text(c.t('dlg.results').toUpperCase()), findsOneWidget);
    await tapText(tester, 'Fechar');
    await openMenu(tester, 'Ferramentas', 'Bomba e curva do sistema…');
    expect(find.text(c.t('dlg.operatingPoint').toUpperCase()), findsOneWidget);
    await enterField(tester, 'Altura estática (m.c.a.)', '80');
    expect(find.textContaining(c.t('dlg.pumpCannot').split('.').first), findsWidgets);
    await tapText(tester, 'Fechar');
    await openMenu(tester, 'Ferramentas', 'Golpe de aríete…');
    expect(find.text(c.t('dlg.resultJoukowsky').toUpperCase()), findsOneWidget);
    await enterField(tester, 'Velocidade (m/s)', '3');
    await tapText(tester, 'Fechar');
  });

  testWidgets('units dialog switches to US units', (tester) async {
    final c = await pumpShell(tester);
    await openMenu(tester, 'Ferramentas', 'Unidades…');
    await tapText(tester, 'US');
    await tapText(tester, 'OK');
    expect(c.units.lengthLabel, 'ft');
    await openMenu(tester, 'Ferramentas', 'Unidades…');
    await tapText(tester, 'Métrico');
    await tapText(tester, 'OK');
    expect(c.units.lengthLabel, 'm');
  });

  testWidgets('help dialogs: shortcuts and about', (tester) async {
    await pumpShell(tester);
    await openMenu(tester, 'Ajuda', 'Atalhos de teclado…');
    expect(find.text('Ctrl+S'), findsOneWidget);
    expect(find.text('ZP · ZONE'), findsOneWidget);
    await tapText(tester, 'Fechar');
    await openMenu(tester, 'Ajuda', 'Sobre');
    expect(find.textContaining('Global Gradient'), findsOneWidget);
    // exact build identification and the project links
    expect(find.text('Versão $appVersionLabel'), findsOneWidget);
    expect(find.textContaining('$appVersion (build $appBuild) · '), findsOneWidget);
    expect(find.byKey(const Key('about_github')), findsNothing, reason: 'no repository link');
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.byKey(const Key('about_site')), findsOneWidget);
    await tapText(tester, 'Fechar');
    // the status bar carries it too
    expect(find.text('v$appVersionFull'), findsOneWidget);
  });

  testWidgets('project details dialog edits metadata', (tester) async {
    final c = await pumpShell(tester);
    await openMenu(tester, 'Arquivo', 'Detalhes do projeto…');
    await enterField(tester, 'Cliente', 'Fazenda Nova');
    await enterField(tester, 'Notas', 'Obs.');
    await tapText(tester, 'OK');
    expect(c.project.meta.client, 'Fazenda Nova');
    expect(c.project.meta.notes, 'Obs.');
    expect(c.dirty, isTrue);
  });

  testWidgets('georeference dialog sets the origin from latitude and longitude', (tester) async {
    final c = await pumpShell(tester);
    expect(c.project.meta.georef, isNull);
    await openMenu(tester, 'Arquivo', 'Georreferência…');
    await enterField(tester, 'Latitude (°)', '-15.78');
    await enterField(tester, 'Longitude (°)', '-47.93');
    await tester.tap(find.byKey(const Key('geo_ok')));
    await settle(tester);
    expect(c.project.meta.georef, isNotNull);
    expect(c.project.meta.georef!.zone, 23);
    expect(c.project.meta.georef!.north, isFalse);
  });

  testWidgets('versions and recovery dialogs', (tester) async {
    final c = await pumpShell(tester);
    await openMenu(tester, 'Arquivo', 'Histórico de versões…');
    expect(find.textContaining('Nenhuma versão'), findsOneWidget);
    await tapText(tester, 'Fechar');
    expect(find.textContaining('Nuvem'), findsNothing, reason: 'the cloud feature was removed');
    // an autosaved project that was never saved is offered for recovery
    c.autosaveEnabled = true;
    c.dirty = true;
    c.autosaveNow();
    expect(LocalProjectStore().recoverable().length, 1);
    final ctx = tester.element(find.byType(AppShell));
    final future = showRecoveryDialog(ctx, shell.ws);
    await settle(tester);
    expect(find.text('Recuperar projeto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rec_discard')));
    await settle(tester);
    expect(await future, 0);
    expect(LocalProjectStore().recoverable(), isEmpty);
  });

  testWidgets('DEM view and pump selection dialogs', (tester) async {
    final c = await pumpShell(tester, design: true);
    await openMenu(tester, 'Projeto', 'Vista 3D do terreno…');
    expect(find.text('Exagero vertical'), findsOneWidget);
    final paint = find.byType(CustomPaint).last;
    final g = await tester.startGesture(tester.getCenter(paint));
    await g.moveBy(const Offset(80, 40));
    await g.up();
    await settle(tester, 2);
    await tapText(tester, 'Fechar');
    await openMenu(tester, 'Linha principal', 'Selecionar bomba…');
    expect(find.text(c.t('pump.title')), findsOneWidget);
    expect(find.textContaining('cv'), findsWidgets);
    await tapText(tester, 'Fechar');
  });

  testWidgets('catalog editor: tabs, add and remove an item', (tester) async {
    final c = await pumpShell(tester);
    final pipes = c.project.catalog.pipes.length;
    await openMenu(tester, 'Projeto', 'Catálogo de componentes…');
    for (final tab in ['Emissores', 'Fitas', 'Válvulas', 'Bombas', 'Conexões', 'Tubos']) {
      expect(find.text(tab), findsWidgets, reason: tab);
      await tapText(tester, tab);
    }
    await tester.tap(find.byKey(const Key('cat_add')));
    await settle(tester, 2);
    expect(c.project.catalog.pipes.length, pipes + 1);
    final added = c.project.catalog.pipes.last;
    // the remove button sits in the last column of the last row: scroll both ways
    await tester.drag(find.byType(DataTable).first, const Offset(-3000, 0), warnIfMissed: false);
    await settle(tester, 1);
    await tester.ensureVisible(find.byKey(Key('cat_rm_${added.id}')));
    await settle(tester, 1);
    await tester.tap(find.byKey(Key('cat_rm_${added.id}')), warnIfMissed: false);
    await settle(tester, 2);
    if (find.byType(AlertDialog).evaluate().length > 1) {
      await tester.tap(find.text('OK').last);
      await settle(tester, 2);
    }
    expect(c.project.catalog.pipes.length, pipes);
    final close = find.text('Fechar').evaluate().isNotEmpty ? 'Fechar' : 'OK';
    await tapText(tester, close);
    expect(find.byKey(const Key('cat_add')), findsNothing);
  });

  testWidgets('drawing export dialogs: PDF plot options and the desktop file dialog', (tester) async {
    await pumpShell(tester);
    await openMenu(tester, 'Arquivo', 'Exportar desenho');
    await tapText(tester, 'PDF (prancha para impressão)…');
    expect(find.text('Exportar PDF (prancha)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester, 4);
    // desktop build: an in-app file dialog asks where to save
    expect(find.text('Save as'), findsOneWidget);
    await tapText(tester, 'Cancel');
    // DXF export written to a temp file through the same dialog
    final dir = Directory.systemTemp.createTempSync('oci_export');
    await openMenu(tester, 'Arquivo', 'Exportar desenho');
    await tapText(tester, 'DXF (AutoCAD, QGIS)');
    expect(find.text('Save as'), findsOneWidget);
    final target = '${dir.path}${Platform.pathSeparator}saida.dxf';
    await tester.enterText(find.byKey(const Key('desktop_filename')), target);
    await tester.tap(find.text('Save'));
    await settle(tester, 4);
    // the write is real file I/O: let it finish outside the fake-async zone
    await tester.runAsync(() async {
      for (var i = 0; i < 40 && (!File(target).existsSync() || File(target).lengthSync() == 0); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await settle(tester, 2);
    expect(File(target).existsSync(), isTrue);
    expect(File(target).readAsStringSync(), contains('ENTITIES'));
    dir.deleteSync(recursive: true);
  });

  testWidgets('array dialog multiplies the selection', (tester) async {
    final c = await pumpShell(tester, example: false);
    final circle = CircleEntity(id: c.project.newId(), center: const Pt(0, 0), radius: 3);
    c.addEntity(circle);
    c.select([circle.id]);
    await settle(tester, 2);
    final ctx = tester.element(find.byType(AppShell));
    showArrayDialog(ctx, c);
    await settle(tester, 2);
    expect(find.text(c.t('arr.title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('array_ok')));
    await settle(tester, 2);
    expect(c.project.entities.whereType<CircleEntity>().length, greaterThan(1));
  });

  testWidgets('text and leader tools open their dialogs and create entities', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.setTool(ToolId.text);
    await settle(tester, 1);
    final centre = c.camera.visible.center;
    await clickWorld(tester, c, centre);
    await settle(tester, 2);
    expect(find.text('Texto'), findsWidgets);
    await enterField(tester, 'Texto', 'Olá mundo');
    await tapText(tester, 'OK');
    expect(c.project.entities.whereType<TextEntity>().where((t) => t.text == 'Olá mundo').length, 1);
    c.setTool(ToolId.leader);
    await settle(tester, 1);
    await clickWorld(tester, c, centre + const Pt(-5, -5));
    await clickWorld(tester, c, centre + const Pt(5, 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 3);
    await enterField(tester, 'Texto', 'Chamada 1');
    await tapText(tester, 'OK');
    expect(c.project.entities.whereType<LeaderEntity>().where((l) => l.text == 'Chamada 1').length, 1);
  });

  testWidgets('lateral block and sprinkler grid dialogs generate hydraulics', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.setTool(ToolId.block);
    await settle(tester, 1);
    final o = c.camera.visible.center;
    for (final p in [o, o + const Pt(60, 0), o + const Pt(60, 40), o + const Pt(0, 40)]) {
      await clickWorld(tester, c, p);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 3);
    expect(find.text(c.t('design.block')), findsOneWidget);
    await tapText(tester, 'OK');
    expect(c.project.entities.whereType<SpraylineEntity>().length, greaterThan(3));
    expect(c.project.entities.whereType<ControlValveEntity>().length, 1);
    c.setTool(ToolId.autohead);
    await settle(tester, 1);
    for (final p in [o + const Pt(-80, 0), o + const Pt(-40, 0), o + const Pt(-40, 30), o + const Pt(-80, 30)]) {
      await clickWorld(tester, c, p);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 3);
    expect(find.text(c.t('design.autohead')), findsOneWidget);
    await tapText(tester, 'OK');
    expect(c.project.entities.whereType<OutletEntity>().length, greaterThan(4));
  });

  testWidgets('base map: google maps asks for the api key, the custom map for its url', (tester) async {
    removePref('basemap.googleKey');
    removePref('basemap.customUrl');
    final c = await pumpShell(tester);
    Future<void> pickBaseMap(String item) async {
      await tester.tap(find.text('Ver'));
      await settle(tester, 2);
      await tester.tap(find.text('Mapa base'));
      await settle(tester, 2);
      await tester.tap(find.text(item).last);
      await settle(tester, 3);
    }

    // no key yet: the dialog opens; cancelling keeps the previous map
    await pickBaseMap('Google Maps – satélite');
    expect(find.byKey(const Key('google_key_field')), findsOneWidget);
    await tapText(tester, 'Cancelar');
    expect(c.baseMap, BaseMap.none);
    expect(c.googleMapsKey, isNull);
    // entering a key selects the map and remembers the key
    await pickBaseMap('Google Maps – satélite');
    await enterField(tester, 'Chave da API', ' AIzaTest ');
    if (find.byKey(const Key('google_key_save')).evaluate().isNotEmpty) await tapText(tester, 'OK');
    expect(c.googleMapsKey, 'AIzaTest');
    expect(c.baseMap, BaseMap.googleSatellite);
    expect(getPref('basemap.googleKey'), 'AIzaTest');
    // with a key the other google maps switch directly
    await pickBaseMap('Google Maps – híbrido (satélite + vias)');
    expect(find.byKey(const Key('google_key_field')), findsNothing);
    expect(c.baseMap, BaseMap.googleHybrid);
    // the custom map validates its template
    await pickBaseMap('Personalizado (URL XYZ)');
    expect(find.byKey(const Key('custom_tiles_field')), findsOneWidget);
    await enterField(tester, 'Modelo de URL', 'tiles/{z}/{x}');
    expect(find.text(c.t('basemap.customInvalid')), findsOneWidget);
    expect(c.baseMap, BaseMap.googleHybrid);
    await enterField(tester, 'Modelo de URL', 'https://t.example/{z}/{x}/{y}.png');
    if (find.byKey(const Key('custom_tiles_save')).evaluate().isNotEmpty) await tapText(tester, 'OK');
    expect(c.customTileUrl, 'https://t.example/{z}/{x}/{y}.png');
    expect(c.baseMap, BaseMap.custom);
    // the key dialog from the menu removes the key; a google map falls back to none
    await pickBaseMap('Google Maps – relevo');
    expect(c.baseMap, BaseMap.googleTerrain);
    await pickBaseMap('Chave da API do Google Maps…');
    await tapText(tester, 'Remover chave');
    expect(c.googleMapsKey, isNull);
    expect(c.baseMap, BaseMap.none);
    // free maps never ask for anything
    await pickBaseMap('Topográfico (OpenTopoMap)');
    expect(c.baseMap, BaseMap.topo);
    removePref('basemap.googleKey');
    removePref('basemap.customUrl');
  });
}
