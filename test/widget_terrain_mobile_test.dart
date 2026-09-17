import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Elevation tools (contour prompt, profile clearing), design check, pivots,
/// alignment and the phone layout.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080), bool example = false}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.designRunner = InThreadDesignRunner();
    if (!example) c.newProject();
    c.snap.enabled = false;
    await settle(tester);
    return c;
  }

  Offset screenOf(WidgetTester tester, ProjectController c, Pt world) {
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    return box.localToGlobal(c.camera.toScreen(world));
  }

  Future<void> clickWorld(WidgetTester tester, ProjectController c, Pt world) async {
    await tester.tapAt(screenOf(tester, c, world));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('elevation tools', () {
    testWidgets('contour asks the elevation, increments the next one and spot cancel undoes', (tester) async {
      final c = await pumpShell(tester);
      c.toolSettings.contourElevation = 100;
      c.toolSettings.contourInterval = 2;
      c.setTool(ToolId.contour);
      await settle(tester, 2);
      await clickWorld(tester, c, const Pt(0, 0));
      await clickWorld(tester, c, const Pt(30, 5));
      await key(tester, LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byKey(const Key('elev_value')), findsOneWidget, reason: 'elevation dialog after Enter');
      await tester.enterText(find.byKey(const Key('elev_value')), '105');
      await tester.tap(find.byKey(const Key('elev_ok')));
      await settle(tester);
      final ct = c.project.entities.whereType<ContourEntity>().single;
      expect(ct.elevation, 105);
      expect(c.toolSettings.contourElevation, 107, reason: 'next contour = 105 + interval 2');
      // spot height: cancel removes the point again
      c.setTool(ToolId.spot);
      await settle(tester, 2);
      await clickWorld(tester, c, const Pt(10, 10));
      await settle(tester);
      expect(find.byKey(const Key('elev_cancel')), findsOneWidget);
      expect(c.project.entities.whereType<SpotHeightEntity>().length, 1);
      await tester.tap(find.byKey(const Key('elev_cancel')));
      await settle(tester);
      expect(c.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      // with the prompt off, the elevation of the tool settings is used and incremented
      c.toolSettings.askElevation = false;
      c.setTool(ToolId.contour);
      await settle(tester, 2);
      await clickWorld(tester, c, const Pt(0, 20));
      await clickWorld(tester, c, const Pt(30, 25));
      await key(tester, LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byKey(const Key('elev_value')), findsNothing);
      expect(c.project.entities.whereType<ContourEntity>().last.elevation, 107);
      expect(c.toolSettings.contourElevation, 109);
    });

    testWidgets('profile tool draws the path, the tab explains it and Clear/Esc remove it', (tester) async {
      final c = await pumpShell(tester, example: true);
      c.setTool(ToolId.profile);
      await settle(tester, 2);
      final b = c.project.bounds;
      await clickWorld(tester, c, Pt(b.minX + 10, b.center.y));
      await clickWorld(tester, c, Pt(b.maxX - 10, b.center.y));
      await key(tester, LogicalKeyboardKey.enter);
      await settle(tester);
      expect(c.profilePath, isNotNull);
      expect(c.showReports, isTrue);
      expect(c.reportTab, reportTabKeys.indexOf('reports.profile'));
      expect(find.byKey(const Key('profile_clear')), findsOneWidget);
      expect(find.textContaining('Declividade média'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile_clear')));
      await settle(tester);
      expect(c.profilePath, isNull);
      expect(find.textContaining('Como usar'), findsOneWidget, reason: 'the tab explains how to use the tool');
      // Esc in the profile tool clears a path too
      c.setProfilePath([Pt(b.minX, b.minY), Pt(b.maxX, b.maxY)]);
      c.setTool(ToolId.profile);
      await settle(tester, 2);
      await key(tester, LogicalKeyboardKey.escape);
      await settle(tester);
      expect(c.profilePath, isNull);
      // the Terrain submenu offers the clear item (disabled without a path)
      await tester.tap(find.text('Projeto').first);
      await settle(tester, 2);
      await tester.tap(find.text('Terreno').last);
      await settle(tester, 2);
      expect(find.byKey(const Key('menu_dem_online')), findsOneWidget);
      expect(find.byKey(const Key('menu_gen_contours')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu_gen_contours')));
      await settle(tester);
      expect(find.byKey(const Key('cgen_run')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cgen_run')));
      await settle(tester);
      expect(c.project.entities.whereType<ContourEntity>().where((e) => e.derived), isNotEmpty);
    });

    testWidgets('online DEM dialog asks for a georeference first', (tester) async {
      final c = await pumpShell(tester, example: true);
      expect(c.project.meta.georef, isNull);
      await tester.tap(find.text('Projeto').first);
      await settle(tester, 2);
      await tester.tap(find.text('Terreno').last);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('menu_dem_online')));
      await settle(tester);
      expect(find.byKey(const Key('dem_georef')), findsOneWidget);
      final run = tester.widget<FilledButton>(find.byKey(const Key('dem_run')));
      expect(run.onPressed, isNull);
      await tester.tap(find.text('Fechar'));
      await settle(tester);
    });
  });

  group('design check and pivot', () {
    testWidgets('design check dialog lists issues and locates them', (tester) async {
      final c = await pumpShell(tester);
      c.addEntity(PipeEntity(id: c.project.newId(), points: [const Pt(0, 0), const Pt(100, 0)], scope: HydraulicScope.mainline));
      c.addEntity(PipeEntity(id: c.project.newId(), points: [const Pt(50, -20), const Pt(50, 20)], scope: HydraulicScope.mainline));
      await settle(tester, 2);
      await tester.tap(find.text('Projeto').first);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('menu_check')));
      await settle(tester);
      expect(find.byKey(const Key('check_list')), findsOneWidget);
      expect(find.textContaining('Falta a fonte de água'), findsOneWidget);
      expect(find.textContaining('Tubos se cruzam sem junção'), findsOneWidget);
      await tester.tap(find.textContaining('Tubos se cruzam sem junção'));
      await settle(tester);
      expect(c.selection.length, 2);
      expect(c.camera.center.distanceTo(const Pt(50, 0)), lessThan(1e-6));
      await tester.tap(find.byKey(const Key('check_rerun')));
      await settle(tester);
      expect(c.eventCount('check'), 2);
      await tester.tap(find.text('Fechar'));
      await settle(tester);
    });

    testWidgets('pivot tool adds a pivot on the mainline and the design reports it', (tester) async {
      final c = await pumpShell(tester);
      c.addEntity(WaterSupplyEntity(id: c.project.newId(), position: const Pt(-200, 0), calculatePressure: true));
      c.addEntity(PipeEntity(id: c.project.newId(), points: [const Pt(-200, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      c.camera.center = const Pt(-60, 0);
      c.camera.scale = 4;
      c.refresh();
      await settle(tester, 2);
      c.setTool(ToolId.pivot);
      await settle(tester, 2);
      await clickWorld(tester, c, const Pt(0, 0));
      await clickWorld(tester, c, const Pt(60, 0));
      await settle(tester);
      final pv = c.project.entities.whereType<PivotEntity>().single;
      expect(pv.radiusM, closeTo(60, 0.5));
      expect(c.selection, contains(pv.id));
      expect(find.text('Tipo de máquina'), findsOneWidget, reason: 'properties panel shows the pivot');
      await tester.runAsync(() => c.runDesign());
      await settle(tester);
      expect(c.results!.pivots.containsKey(pv.id), isTrue);
      c.reportTab = reportTabKeys.indexOf('reports.pivots');
      c.showReports = true;
      c.refresh();
      await settle(tester);
      expect(find.text(pv.name), findsWidgets);
    });

    testWidgets('align by two points scales and moves the selection', (tester) async {
      final c = await pumpShell(tester);
      final pl = PolylineEntity(id: c.project.newId(), points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)]);
      c.addEntity(pl);
      c.select([pl.id]);
      c.camera.center = const Pt(20, 20);
      c.camera.scale = 8;
      c.refresh();
      await settle(tester, 2);
      c.setTool(ToolId.alignImage);
      await settle(tester, 2);
      await clickWorld(tester, c, const Pt(0, 0));
      await clickWorld(tester, c, const Pt(20, 20));
      await clickWorld(tester, c, const Pt(10, 0));
      await clickWorld(tester, c, const Pt(40, 20));
      await settle(tester);
      final moved = c.project.byId(pl.id) as PolylineEntity;
      expect(moved.points[0].distanceTo(const Pt(20, 20)), lessThan(0.6));
      expect(moved.points[1].distanceTo(const Pt(40, 20)), lessThan(0.6));
      expect(moved.points[2].distanceTo(const Pt(40, 40)), lessThan(0.9));
      expect(c.activeTool, ToolId.select);
    });
  });

  group('phone layout', () {
    testWidgets('narrow screens get the mobile shell with tool bar, Done button, menu and sheets', (tester) async {
      final c = await pumpShell(tester, size: const Size(420, 860));
      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.byKey(const Key('mobile_menu')), findsOneWidget);
      // let the "project loaded" snack bar go away
      await tester.pump(const Duration(seconds: 4));
      await settle(tester, 2);
      // draw a polyline with taps and the Done button (no keyboard)
      await tester.tap(find.byKey(const Key('mobile_group_draw')));
      await settle(tester, 2);
      final toolRect = tester.getRect(find.byKey(const Key('mtool_polyline')));
      await tester.tapAt(toolRect.center);
      await settle(tester, 2);
      expect(c.activeTool, ToolId.polyline, reason: 'tool button at $toolRect');
      expect(find.byKey(const Key('mobile_done')), findsOneWidget);
      await clickWorld(tester, c, const Pt(0, 0));
      await clickWorld(tester, c, const Pt(20, 0));
      await clickWorld(tester, c, const Pt(20, 15));
      await tester.tap(find.byKey(const Key('mobile_done')));
      await settle(tester);
      expect(c.project.entities.whereType<PolylineEntity>().length, 1);
      // Cancel returns to the select tool
      await tester.tap(find.byKey(const Key('mobile_cancel')));
      await settle(tester);
      expect(c.activeTool, ToolId.select);
      // menu sheet with the design section
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
      expect(find.byKey(const Key('mobile_menu_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile_menu_design')));
      await settle(tester);
      expect(find.byKey(const Key('mobile_menu_check')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile_menu_check')));
      await settle(tester);
      expect(find.byKey(const Key('check_list')), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await settle(tester);
      // properties sheet
      c.select([c.project.entities.first.id]);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('mobile_props')));
      await settle(tester);
      expect(find.byKey(const Key('mobile_props_sheet')), findsOneWidget);
      expect(find.text('Polilinha'), findsWidgets);
      await tester.tapAt(const Offset(200, 40)); // outside the sheet
      await settle(tester);
      // reports sheet
      await tester.tap(find.byKey(const Key('mobile_reports')));
      await settle(tester);
      expect(find.byKey(const Key('mobile_reports_sheet')), findsOneWidget);
      await tester.tapAt(const Offset(200, 20));
      await settle(tester);
      expect(c.showReports, isFalse);
    });

    testWidgets('the tutorial card fits a phone and the desktop layout returns on wide screens', (tester) async {
      final c = await pumpShell(tester, size: const Size(420, 860), example: true);
      final shell = tester.state(find.byType(AppShell)) as dynamic;
      shell.startTutorial();
      await settle(tester);
      expect(find.byKey(const Key('tut_next')), findsOneWidget);
      final card = tester.getRect(find.byKey(const Key('tut_next')));
      expect(card.right, lessThanOrEqualTo(420));
      await tester.tap(find.byKey(const Key('tut_close')));
      await settle(tester);
      tester.view.physicalSize = const Size(1600, 900);
      await settle(tester);
      expect(find.byType(MobileShell), findsNothing);
      expect(find.text('Arquivo'), findsOneWidget);
      expect(c.project.entities, isNotEmpty);
    });
  });
}
