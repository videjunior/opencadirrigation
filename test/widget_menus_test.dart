import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/main.dart';

/// Menu items without a test elsewhere: the mainline tools (which set the
/// scope of point items), the terrain interpolation, autosave; and the view
/// and reports sections of the phone menu.
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
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    if (!example) c.newProject();
    await settle(tester);
    return c;
  }

  /// Opens the menu bar entry path[0] (the first match: the menu bar comes
  /// first) and taps the items below it (the last match: the open menu).
  Future<void> menu(WidgetTester tester, List<String> path) async {
    for (var i = 0; i < path.length; i++) {
      final f = find.text(path[i]);
      await tester.tap(i == 0 ? f.first : f.last);
      await settle(tester, 2);
    }
  }

  testWidgets('mainline menu: point items go on the mainline; terrain method; autosave', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    for (final (label, tool) in [
      (t('tool.pump'), ToolId.pump),
      ('${t('tool.misc')} (${t('scope.mainline')})', ToolId.misc),
      ('${t('tool.outlet')} (${t('scope.mainline')})', ToolId.outlet),
      ('${t('tool.junction')} (${t('scope.mainline')})', ToolId.junction),
      (t('tool.supply'), ToolId.supply),
      (t('tool.mainPipe'), ToolId.mainPipe),
    ]) {
      c.toolSettings.pointScope = HydraulicScope.zone;
      await menu(tester, [t('menu.mainline'), label]);
      expect(c.activeTool, tool, reason: label);
      if (tool != ToolId.supply && tool != ToolId.mainPipe) expect(c.toolSettings.pointScope, HydraulicScope.mainline, reason: label);
    }
    // terrain interpolation: one undo step, results discarded
    expect(c.project.params.terrainMethod, TerrainMethod.tin);
    await menu(tester, [t('menu.design'), t('menu.terrain'), t('terrain.idw')]);
    expect(c.project.params.terrainMethod, TerrainMethod.idw);
    expect(c.historyEntries.last.label, 'hist.params');
    c.undo();
    expect(c.project.params.terrainMethod, TerrainMethod.tin);
    // autosave on and off from the file menu
    c.autosaveEnabled = true;
    await menu(tester, [t('menu.file'), t('file.autosave')]);
    expect(c.autosaveEnabled, isFalse);
    // the tools of the terrain submenu set the tool with its alias shown
    await tester.tapAt(const Offset(1500, 900));
    await settle(tester, 2);
    await menu(tester, [t('menu.design'), t('menu.terrain'), t('tool.contour')]);
    expect(c.activeTool, ToolId.contour);
  });

  testWidgets('phone menu: view toggles, overlays and the reports of every tab', (tester) async {
    final c = await pumpShell(tester, size: const Size(420, 860), example: true);
    final t = c.t;
    expect(find.byType(MobileShell), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 2);
    Finder inMenu(Finder f) => find.descendant(of: find.byKey(const Key('mobile_menu_sheet')), matching: f);
    Future<void> openView() async {
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
      await tester.tap(inMenu(find.text(t('menu.view'))));
      await settle(tester);
    }

    Future<void> tick(String label) async {
      await openView();
      await tester.ensureVisible(inMenu(find.text(label)));
      await settle(tester, 1);
      await tester.tap(inMenu(find.text(label)));
      await settle(tester);
    }

    final grid = c.showGrid, labels = c.showLabels, wetted = c.showWettedRadii, snap = c.snap.enabled, ortho = c.snap.ortho, keep = c.toolSettings.keepConnections;
    await tick(t('view.grid'));
    await tick(t('view.labels'));
    await tick(t('view.wetted'));
    await tick(t('status.snap'));
    await tick(t('status.ortho'));
    await tick(t('status.keepLinks'));
    expect((c.showGrid, c.showLabels, c.showWettedRadii, c.snap.enabled, c.snap.ortho, c.toolSettings.keepConnections), (!grid, !labels, !wetted, !snap, !ortho, !keep));
    await tick(t('view.overlay.pressure'));
    expect(c.overlay, OverlayMode.pressure);
    // reports: every tab opens the reports sheet on it
    for (final i in [0, reportTabKeys.length - 1]) {
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
      await tester.tap(inMenu(find.text(t('menu.reports'))));
      await settle(tester);
      // the row inside the reports section (a label may repeat elsewhere)
      final row = find.descendant(of: find.widgetWithText(ExpansionTile, t('menu.reports')), matching: find.text(t(reportTabKeys[i])));
      await tester.ensureVisible(row);
      await settle(tester, 1);
      await tester.tap(row);
      await settle(tester);
      expect(c.reportTab, i);
      expect(find.byKey(const Key('mobile_reports_sheet')), findsOneWidget);
      await tester.tapAt(const Offset(200, 20));
      await settle(tester);
    }
  });
}
