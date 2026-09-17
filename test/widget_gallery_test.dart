import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/catalog_packs.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The welcome dialog with the example gallery, the Examples menu, the
/// manufacturer packs dialog (bundled packs, URL) and the "type a
/// coordinate" shortcut of the online DEM dialog.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {bool autoTutorial = false}) async {
    if (!autoTutorial) TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(IrrigationCadApp(autoTutorial: autoTutorial, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    return c;
  }

  Future<void> openMenu(WidgetTester tester, String top, String item) async {
    await tester.tap(find.text(top).first);
    await settle(tester, 2);
    await tester.tap(find.text(item).last);
    await settle(tester, 3);
  }

  group('welcome and example gallery', () {
    testWidgets('first run shows the gallery; opening an example loads it and remembers the choice', (tester) async {
      TutorialController.reset();
      final c = await pumpShell(tester, autoTutorial: true);
      expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsOneWidget);
      expect(find.byKey(const Key('welcome_version')), findsOneWidget);
      expect(find.text('Versão $appVersionLabel'), findsOneWidget);
      for (final ex in exampleGallery) {
        expect(find.byKey(Key('example_${ex.id.name}')), findsOneWidget, reason: ex.id.name);
      }
      expect(find.byKey(const Key('tut_start')), findsOneWidget);
      await tester.tap(find.byKey(const Key('example_garden')));
      await settle(tester);
      expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsNothing);
      expect(c.project.meta.name, 'Jardim residencial');
      expect(c.project.entities.whereType<OutletEntity>().length, 24);
      expect(TutorialController.isDone, isTrue, reason: 'not asked again next time');
      expect(c.eventCount('example'), greaterThanOrEqualTo(1));
    });

    testWidgets('Help reopens the gallery; File → Examples loads any example; the tutorial still starts', (tester) async {
      final c = await pumpShell(tester);
      expect(c.project.meta.name, 'Exemplo pomar');
      await openMenu(tester, 'Ajuda', 'Boas-vindas e galeria de exemplos…');
      expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsOneWidget);
      await tester.tap(find.byKey(const Key('example_pivot')));
      await settle(tester);
      expect(c.project.entities.whereType<PivotEntity>().length, 1);
      expect(c.project.meta.name, 'Pivô central');
      // File → Examples submenu
      await tester.tap(find.text('Arquivo').first);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('menu_examples')));
      await settle(tester, 2);
      expect(find.byKey(const Key('menu_example_sportsField')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu_example_sportsField')));
      await settle(tester);
      expect(c.project.meta.name, 'Campo de futebol');
      expect(c.project.entities.whereType<ControlValveEntity>().length, 5);
      // the gallery's tutorial button starts the tutorial
      await openMenu(tester, 'Ajuda', 'Boas-vindas e galeria de exemplos…');
      await tester.tap(find.byKey(const Key('tut_start')));
      await settle(tester);
      expect(find.byKey(const Key('tut_next')), findsOneWidget);
    });
  });

  group('manufacturer packs', () {
    testWidgets('the packs dialog lists the bundled JSON packs and merges one; a URL index loads more', (tester) async {
      final c = await pumpShell(tester);
      final savedUrl = catalogUrlLoader;
      final rain = File('catalogs/rainbird.oci.cat').readAsStringSync();
      catalogUrlLoader = (url) async {
        if (url == 'https://community.example/index.json') return '{"format":"opencadirrigation-catalog-index","version":1,"packs":[{"id":"rainbird","brand":"Rain Bird","file":"rb.oci.cat"}]}';
        if (url == 'https://community.example/rb.oci.cat') return rain.replaceAll('"id": "rainbird"', '"id": "rainbird_community"').replaceAll('"rb_', '"rbc_');
        throw Exception('HTTP 404');
      };
      addTearDown(() => catalogUrlLoader = savedUrl);
      final before = c.project.catalog.itemCount;
      await openMenu(tester, 'Projeto', 'Catálogo de componentes…');
      await tester.tap(find.byKey(const Key('cat_packs')));
      await settle(tester);
      // bundled packs are read from the asset bundle (FutureBuilder)
      await tester.runAsync(() => loadBundledCatalogPacks());
      await settle(tester);
      expect(find.byKey(const Key('pack_hunter')), findsOneWidget);
      expect(find.byKey(const Key('pack_netafim')), findsOneWidget);
      // the first pack in the list is on screen without scrolling
      await tester.tap(find.byKey(const Key('pack_hunter')));
      await settle(tester);
      expect(c.project.catalog.itemCount, greaterThan(before));
      expect(c.project.catalog.valves.any((v) => v.supplier == 'Hunter Industries'), isTrue);
      // the button now shows the pack as present
      final btn = tester.widget<FilledButton>(find.byKey(const Key('pack_hunter')));
      expect(btn.onPressed, isNull);
      // load a community index by URL
      await tester.enterText(find.byKey(const Key('pack_url')), 'https://community.example/index.json');
      await tester.tap(find.byKey(const Key('pack_load_url')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(find.byKey(const Key('pack_rainbird_community')), findsOneWidget);
      expect(find.byKey(const Key('pack_error')), findsNothing);
      // a bad URL reports the error
      await tester.enterText(find.byKey(const Key('pack_url')), 'https://community.example/nope');
      await tester.tap(find.byKey(const Key('pack_load_url')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(find.byKey(const Key('pack_error')), findsOneWidget);
      await tester.tap(find.text('Fechar').last);
      await settle(tester);
      // export as a pack: the dialog opens with the id preview
      await tester.tap(find.byKey(const Key('cat_export_pack')));
      await settle(tester);
      expect(find.byKey(const Key('pack_export_ok')), findsOneWidget);
      expect(find.textContaining('.oci.cat'), findsWidgets);
      await tester.tap(find.text('Cancelar').last);
      await settle(tester);
    });
  });

  group('online DEM from a coordinate', () {
    testWidgets('typing a coordinate georeferences an empty project and enables the download', (tester) async {
      final c = await pumpShell(tester);
      c.newProject();
      await settle(tester);
      expect(c.project.meta.georef, isNull);
      await tester.tap(find.text('Projeto').first);
      await settle(tester, 2);
      await tester.tap(find.text('Terreno').last);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('menu_dem_online')));
      await settle(tester);
      expect(find.byKey(const Key('dem_coord')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('dem_run'))).onPressed, isNull);
      // junk is refused
      await tester.enterText(find.byKey(const Key('dem_coord')), 'somewhere');
      await tester.tap(find.byKey(const Key('dem_use_coord')));
      await settle(tester);
      expect(find.text('Coordenada não reconhecida'), findsOneWidget);
      expect(c.project.meta.georef, isNull);
      // a pasted Google Maps link works
      await tester.enterText(find.byKey(const Key('dem_coord')), 'https://www.google.com/maps/@-22.9068,-43.1729,17z');
      await tester.tap(find.byKey(const Key('dem_use_coord')));
      await settle(tester);
      final geo = c.project.meta.georef;
      expect(geo, isNotNull);
      expect(geo!.zone, utmZoneFor(-22.9068, -43.1729));
      expect(geo.north, isFalse);
      final (lat, lon) = geo.toLatLon(0, 0);
      expect(lat, closeTo(-22.9068, 1e-5));
      expect(lon, closeTo(-43.1729, 1e-5));
      // the view frames the 500 m square around the origin, so the download has an area
      expect(c.camera.visible.width, greaterThan(450));
      expect(c.camera.visible.contains(const Pt(0, 0)), isTrue);
      expect(find.byKey(const Key('dem_coord')), findsNothing, reason: 'georeferenced: the coordinate box gives way to the download options');
      expect(find.byKey(const Key('dem_contours')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('dem_run'))).onPressed, isNotNull);
      await tester.tap(find.text('Fechar'));
      await settle(tester);
    });
  });
}
