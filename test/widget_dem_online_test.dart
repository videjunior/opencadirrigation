import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Online DEM download over a project that already has its own elevation
/// data (the example spot heights at ~100 m): the dialog replaces them by
/// default, and warns when they are kept on another datum.
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
    c.autosaveEnabled = false;
    c.designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    loadExampleAction(c, ExampleId.bananas);
    await settle(tester);
    return c;
  }

  /// A fake elevation server: a plane at ~800 m sloping with latitude and
  /// longitude, answered from the request URL.
  final requests = <String>[];
  Future<String> fakeServer(String url) async {
    requests.add(url);
    final u = Uri.parse(url);
    final lats = u.queryParameters['latitude']!.split(',').map(double.parse).toList();
    final lons = u.queryParameters['longitude']!.split(',').map(double.parse).toList();
    return jsonEncode({'elevation': [for (var i = 0; i < lats.length; i++) (800 + (lats[i] + 21.8) * 4000 + (lons[i] + 46.6) * 2000).roundToDouble()]});
  }

  /// Cancels the snack bar timer (a notification raised inside runAsync
  /// would otherwise fire its hide timer after the test is torn down).
  void clearSnacks(WidgetTester tester) => tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();

  /// Inside runAsync: dismisses the snack bar and runs its exit animation to
  /// the end there, so its completion callbacks (real-zone microtasks) run
  /// while the tree is still mounted.
  Future<void> settleSnacks(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    clearSnacks(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// A fake tile server: gentle hills around 800 m, continuous across tiles.
  final tileRequests = <String>[];
  Future<List<int>> fakeTiles(String url) async {
    tileRequests.add(url);
    final m = RegExp(r'/(\d+)/(\d+)/(\d+)\.png$').firstMatch(url)!;
    final tx = int.parse(m[2]!), ty = int.parse(m[3]!);
    final t = Float32List(demTileSize * demTileSize);
    for (var y = 0; y < demTileSize; y++) {
      for (var x = 0; x < demTileSize; x++) {
        final gx = tx * demTileSize + x, gy = ty * demTileSize + y;
        t[y * demTileSize + x] = 800 + 10 * math.sin(gx / 40) + 10 * math.sin(gy / 30);
      }
    }
    return demEncodeTerrarium(t);
  }

  Future<void> openDemDialog(WidgetTester tester) async {
    await tester.tap(find.text('Projeto').first);
    await settle(tester, 2);
    await tester.tap(find.text('Terreno').last);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_dem_online')));
    await settle(tester);
  }

  setUp(() {
    requests.clear();
    tileRequests.clear();
    ProjectController.demUrlLoader = fakeServer;
    ProjectController.demTileLoader = fakeTiles;
  });

  testWidgets('a slow source shows the estimated download time in minutes', (tester) async {
    final c = await pumpShell(tester);
    c.setGeoreferenceAt(-21.8, -46.6);
    // a 3 km farm: the grid hits the 5000-point cap
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(3000, 3000)));
    await settle(tester);
    await openDemDialog(tester);
    expect(find.textContaining('Tempo estimado'), findsNothing, reason: 'tiles download in seconds');
    await tester.tap(find.text('Terrain Tiles 30 m (SRTM · AWS)'));
    await settle(tester, 2);
    await tester.tap(find.text('Open-Meteo (Copernicus DEM 90 m)').last);
    await settle(tester, 2);
    // thousands of points at 550 per minute
    expect(find.textContaining(RegExp(r'Tempo estimado: ≈ \d+ min')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dem_close')));
    await settle(tester);
    expect(find.byKey(const Key('dem_close')), findsNothing);
  });

  testWidgets('replaces the example spot heights by default and draws contours on the DEM layer', (tester) async {
    final c = await pumpShell(tester);
    final own = c.ownTerrainData();
    expect(own.spots, 5);
    expect(own.lo, greaterThan(95));
    expect(own.hi, lessThan(105));
    c.setGeoreferenceAt(-21.8, -46.6);
    await settle(tester);
    await openDemDialog(tester);
    expect(find.text('Terrain Tiles 30 m (SRTM · AWS)'), findsOneWidget, reason: 'default source');
    expect(find.byKey(const Key('dem_replace_existing')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('dem_replace_existing'))).value, isTrue);
    expect(find.textContaining('já tem 5 cotas e 0 curvas'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('dem_contours'))).value, isTrue, reason: 'contours follow the replaced model');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('dem_run')));
      for (var i = 0; i < 20 && find.byKey(const Key('dem_run')).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // the "imported" snack bar was raised in this real zone: dismiss it here
      await settleSnacks(tester);
    });
    await settle(tester);
    expect(find.byKey(const Key('dem_run')), findsNothing, reason: 'dialog closed after the download');
    expect(tileRequests, isNotEmpty);
    expect(tileRequests.length, lessThanOrEqualTo(4), reason: 'a small field needs a few tiles');
    expect(requests, isEmpty, reason: 'no point requests with the tile source');
    expect(c.ownTerrainData().count, 0, reason: 'the example spot heights are gone');
    final dem = c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem).toList();
    expect(dem.length, greaterThan(50));
    expect(dem.every((e) => e.layer == Layers.dem), isTrue);
    expect(c.project.findLayer(Layers.dem), isNotNull);
    final (lo, hi) = c.project.buildTerrain().elevationRange;
    expect(lo, greaterThan(700));
    expect(hi - lo, lessThan(60), reason: 'no spikes: only the plane of the fake server');
    expect(c.project.entities.whereType<ContourEntity>().where((e) => e.derived), isNotEmpty);
    expect(c.lastMessage, contains('cotas importadas'));
    expect(c.lastMessage, contains('curvas de nível'));
    expect(find.byKey(const Key('dem_mismatch_remove')), findsNothing);
    // undo restores the example heights in one step (contours) + one (DEM)
    c.undo();
    c.undo();
    expect(c.ownTerrainData().spots, 5);
    expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem), isEmpty);
    clearSnacks(tester);
  });

  testWidgets('keeping the example heights on another datum warns and offers to remove them', (tester) async {
    final c = await pumpShell(tester);
    c.setGeoreferenceAt(-21.8, -46.6);
    await settle(tester);
    await openDemDialog(tester);
    await tester.tap(find.byKey(const Key('dem_replace_existing')));
    await settle(tester, 2);
    expect(find.textContaining('picos'), findsOneWidget, reason: 'the warning about mixing datums shows when the switch is off');
    // the whole flow runs in the real async zone: the dialog's continuation
    // after the confirmation must resume there
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('dem_run')));
      for (var i = 0; i < 20 && find.byKey(const Key('dem_mismatch_remove')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(find.byKey(const Key('dem_mismatch_remove')), findsOneWidget, reason: '100 m example data vs 800 m DEM');
      expect(c.ownTerrainData().spots, 5, reason: 'nothing removed yet');
      await tester.tap(find.byKey(const Key('dem_mismatch_remove')));
      for (var i = 0; i < 20 && find.byKey(const Key('dem_run')).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await settleSnacks(tester);
    });
    await settle(tester);
    expect(c.ownTerrainData().count, 0);
    final (lo, hi) = c.project.buildTerrain().elevationRange;
    expect(lo, greaterThan(700));
    expect(hi - lo, lessThan(60));
    expect(find.byKey(const Key('dem_run')), findsNothing);
    // undo: contours, then the removal of the own heights, then the download
    c.undo();
    c.undo();
    expect(c.ownTerrainData().spots, 5);
    expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem), isNotEmpty);
    c.undo();
    expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem), isEmpty);
    clearSnacks(tester);
  });

  testWidgets('a slow download can be cancelled and leaves the project untouched', (tester) async {
    var calls = 0;
    ProjectController.demTileLoader = (url) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return fakeTiles(url);
    };
    final c = await pumpShell(tester);
    c.setGeoreferenceAt(-21.8, -46.6);
    await settle(tester);
    await openDemDialog(tester);
    // a fine grid: many batches
    await tester.enterText(find.widgetWithText(TextField, 'Espaçamento da grade (m)'), '5');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('dem_run')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cancelar'), findsOneWidget, reason: 'Close turns into Cancel while busy');
      await tester.tap(find.byKey(const Key('dem_close')));
      for (var i = 0; i < 30 && find.byKey(const Key('dem_progress')).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await settleSnacks(tester);
    });
    await settle(tester);
    expect(find.byKey(const Key('dem_progress')), findsNothing, reason: 'no longer busy');
    expect(find.byKey(const Key('dem_run')), findsOneWidget, reason: 'the dialog stays open');
    expect(calls, lessThan(10), reason: 'the workers stopped early');
    expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem), isEmpty);
    expect(c.ownTerrainData().spots, 5);
    expect(c.lastMessage, 'Download cancelado');
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    clearSnacks(tester);
  });

  testWidgets('a server error is shown in the dialog and nothing is imported', (tester) async {
    ProjectController.demTileLoader = (url) async => throw HttpStatusException(403, 'Forbidden');
    final c = await pumpShell(tester);
    c.setGeoreferenceAt(-21.8, -46.6);
    await settle(tester);
    await openDemDialog(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('dem_run')));
      for (var i = 0; i < 20 && find.textContaining('Forbidden').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(find.textContaining('Falha ao baixar elevações'), findsOneWidget);
    expect(find.byKey(const Key('dem_run')), findsOneWidget, reason: 'the dialog stays open to retry');
    expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem), isEmpty);
    expect(c.ownTerrainData().spots, 5, reason: 'own data is only replaced after a successful download');
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    clearSnacks(tester);
  });
}
