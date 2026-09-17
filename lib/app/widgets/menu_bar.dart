import 'package:flutter/material.dart';

import '../../core/io/project_export.dart';
import '../../core/model/entities.dart';
import '../../core/model/terrain.dart';
import '../actions.dart';
import '../examples.dart';
import '../i18n.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import '../state/workspace.dart';
import '../tutorial/tutorial.dart';
import 'dialogs/basemap_dialogs.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/export_dialogs.dart';
import 'dialogs/more_dialogs.dart';
import 'dialogs/shortcuts_dialog.dart';
import 'dialogs/terrain_dialogs.dart';
import 'dialogs/welcome_dialog.dart';
import 'reports_panel.dart';

class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key, required this.c, this.ws, this.onStartTutorial, this.onShowWelcome, this.onCloseTab});

  /// Number of open menus (the keyboard dispatcher leaves arrows, Enter and
  /// Esc to an open menu).
  static final ValueNotifier<int> openMenus = ValueNotifier<int>(0);
  final ProjectController c;

  /// Tabs and clipboard (null when the bar is used standalone).
  final Workspace? ws;
  final VoidCallback? onStartTutorial;

  /// Help → Welcome and example gallery.
  final VoidCallback? onShowWelcome;
  final VoidCallback? onCloseTab;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    MenuItemButton item(String label, VoidCallback? onPressed, {IconData? icon, String? shortcut, Key? key}) => MenuItemButton(
      key: key,
      onPressed: onPressed == null
          ? null
          : () {
              onPressed();
              c.focusCanvas?.call();
            },
      leadingIcon: icon != null ? Icon(icon, size: 16) : null,
      trailingIcon: shortcut != null ? Text(shortcut, style: const TextStyle(fontSize: 10, color: Colors.white38)) : null,
      child: Text(label),
    );
    MenuItemButton tool(ToolId id, {HydraulicScope? scope}) => item(t('tool.${id.name}'), () {
      if (scope != null) c.toolSettings.pointScope = scope;
      c.setTool(id);
    }, shortcut: '${aliasOf(id)} ⏎');
    final recent = c.store.list();
    return Container(
      color: const Color(0xFF1B1F24),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Image.asset('assets/brand/logo-mark.png', height: 24, filterQuality: FilterQuality.medium, semanticLabel: 'OpenCADIrrigation'),
          const SizedBox(width: 6),
          Text(t('app.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: MenuBar(
              style: const MenuStyle(backgroundColor: WidgetStatePropertyAll(Color(0xFF1B1F24)), elevation: WidgetStatePropertyAll(0)),
              children: [
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuFile, menuChildren: [
                  item(t('file.new'), () => confirmNew(context, c), icon: Icons.note_add_outlined),
                  if (ws != null) item(t('file.newTab'), () => ws!.addTab(), icon: Icons.tab_outlined, shortcut: 'Ctrl+Alt+N'),
                  if (ws != null) item(t('file.closeTab'), onCloseTab, icon: Icons.tab_unselected, shortcut: 'Ctrl+Alt+W'),
                  item(t('file.open'), () => ws == null ? openProjectAction(context, c) : openProjectInTabAction(context, ws!), icon: Icons.folder_open, shortcut: 'Ctrl+O'),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, leadingIcon: const Icon(Icons.history, size: 16), menuChildren: [
                    if (recent.isEmpty) item(t('file.noRecent'), null),
                    for (final p in recent.take(8)) item(p.name.isEmpty ? p.uid : p.name, ws == null ? null : () => openStoredAction(ws!, p), key: Key('recent_${p.uid}')),
                  ], child: Text(t('file.recent'))),
                  item(t('file.save'), () => saveProjectAction(context, c), icon: Icons.save_outlined, shortcut: 'Ctrl+S'),
                  item(t('file.versions'), () => showVersionsDialog(context, c), icon: Icons.layers_outlined),
                  CheckboxMenuButton(value: c.autosaveEnabled, onChanged: (v) {
                    c.autosaveEnabled = v ?? true;
                    c.refresh();
                  }, child: Text(t('file.autosave'))),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: const Key('menu_examples'), leadingIcon: const Icon(Icons.auto_awesome_outlined, size: 16), menuChildren: [
                    for (final ex in exampleGallery) item(t(ex.titleKey), () => loadExampleAction(c, ex.id), icon: exampleIcon(ex.id), key: Key('menu_example_${ex.id.name}')),
                  ], child: Text(t('file.examples'))),
                  const Divider(height: 1),
                  item(t('file.importDrawing'), () => importDrawingAction(context, c), icon: Icons.upload_file, shortcut: 'Ctrl+I'),
                  item(t('file.georefImage'), c.selectedEntity == null ? null : () => showImageGeorefDialog(context, c), icon: Icons.image_outlined),
                  item(t('tool.alignImage'), c.selection.isEmpty ? null : () => c.setTool(ToolId.alignImage), icon: Icons.control_camera, shortcut: 'AL ⏎', key: const Key('menu_align')),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuExportDrawing, leadingIcon: const Icon(Icons.download, size: 16), menuChildren: [
                    for (final f in DrawingFormat.values) item(t('exp.${f.name}'), () => exportDrawingAction(context, c, f)),
                  ], child: Text(t('file.exportDrawing'))),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, leadingIcon: const Icon(Icons.table_view, size: 16), menuChildren: [
                    for (final f in ReportFormat.values) item(t(f == ReportFormat.pdf ? 'exp.reportPdf' : 'exp.${f.name}'), c.results == null ? null : () => exportReportAction(context, c, f)),
                    const Divider(height: 1),
                    item(t('mgmt.export'), () => exportScheduleAction(context, c)),
                  ], child: Text(t('file.exportReport'))),
                  const Divider(height: 1),
                  item(t('file.details'), () => showProjectDetailsDialog(context, c), icon: Icons.info_outline),
                  item(t('file.georef'), () => showGeoreferenceDialog(context, c), icon: Icons.public),
                ], child: Text(t('menu.file'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuEdit, menuChildren: [
                  item(t('edit.undo'), c.canUndo ? c.undo : null, icon: Icons.undo, shortcut: 'Ctrl+Z'),
                  item(t('edit.redo'), c.canRedo ? c.redo : null, icon: Icons.redo, shortcut: 'Ctrl+Y'),
                  const Divider(height: 1),
                  item(t('edit.selectAll'), c.selectAll, shortcut: 'Ctrl+A'),
                  item(t('edit.clipCopy'), c.selection.isEmpty || ws == null ? null : () => copySelectionAction(ws!), icon: Icons.copy_outlined, shortcut: 'Ctrl+C'),
                  item(t('edit.clipCut'), c.selection.isEmpty || ws == null ? null : () => copySelectionAction(ws!, cut: true), icon: Icons.content_cut, shortcut: 'Ctrl+X'),
                  item(t('edit.paste'), ws == null ? null : () => pasteAction(ws!), icon: Icons.content_paste, shortcut: 'Ctrl+V'),
                  item(t('edit.copy'), c.selection.isEmpty ? null : c.duplicateSelected, shortcut: 'Ctrl+D'),
                  item(t('edit.delete'), c.selection.isEmpty ? null : c.deleteSelected, icon: Icons.delete_outline, shortcut: 'Del'),
                  const Divider(height: 1),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, leadingIcon: const Icon(Icons.transform, size: 16), menuChildren: [
                    for (final id in [ToolId.rotate, ToolId.mirror, ToolId.scale, ToolId.offset, ToolId.trim, ToolId.extend, ToolId.cutPipe, ToolId.alignImage]) tool(id),
                    const Divider(height: 1),
                    item(t('edit.array'), c.selection.isEmpty ? null : () => showArrayDialog(context, c), shortcut: 'ARRAY ⏎', key: const Key('menu_array')),
                  ], child: Text(t('edit.transform'))),
                ], child: Text(t('menu.edit'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuView, menuChildren: [
                  item(t('view.zoomAll'), c.zoomAll, icon: Icons.fit_screen, shortcut: 'Home'),
                  item(t('view.zoomIn'), () => c.zoomBy(1.25), icon: Icons.zoom_in, shortcut: '+'),
                  item(t('view.zoomOut'), () => c.zoomBy(0.8), icon: Icons.zoom_out, shortcut: '-'),
                  const Divider(height: 1),
                  CheckboxMenuButton(value: c.showGrid, onChanged: (v) {
                    c.showGrid = v ?? true;
                    c.refresh();
                  }, child: Text('${t('view.grid')}  (F7)')),
                  CheckboxMenuButton(value: c.showLabels, onChanged: (v) {
                    c.showLabels = v ?? true;
                    c.refresh();
                  }, child: Text(t('view.labels'))),
                  CheckboxMenuButton(value: c.showWettedRadii, onChanged: (v) {
                    c.showWettedRadii = v ?? true;
                    c.refresh();
                  }, child: Text(t('view.wetted'))),
                  CheckboxMenuButton(value: c.showGrips, onChanged: (v) {
                    c.showGrips = v ?? true;
                    c.refresh();
                  }, child: Text(t('view.grips'))),
                  const Divider(height: 1),
                  for (final m in OverlayMode.values)
                    RadioMenuButton<OverlayMode>(value: m, groupValue: c.overlay, onChanged: (v) {
                      c.overlay = v ?? OverlayMode.none;
                      c.refresh();
                    }, child: Text(t('view.overlay.${m.name}'))),
                  const Divider(height: 1),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, leadingIcon: const Icon(Icons.map_outlined, size: 16), menuChildren: [
                    for (final m in const [BaseMap.none, BaseMap.streets, BaseMap.topo, BaseMap.carto, BaseMap.satellite, BaseMap.esriStreets, BaseMap.esriTopo])
                      RadioMenuButton<BaseMap>(value: m, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.${m.name}'))),
                    const Divider(height: 1),
                    for (final m in const [BaseMap.googleRoads, BaseMap.googleSatellite, BaseMap.googleHybrid, BaseMap.googleTerrain])
                      RadioMenuButton<BaseMap>(value: m, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.${m.name}'))),
                    item(t('view.baseMap.googleKey'), () => showGoogleMapsKeyDialog(context, c), icon: Icons.key_outlined, key: const Key('menu_google_key')),
                    const Divider(height: 1),
                    RadioMenuButton<BaseMap>(value: BaseMap.custom, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.custom'))),
                    item(t('view.baseMap.customUrl'), () => showCustomTilesDialog(context, c), icon: Icons.link, key: const Key('menu_custom_tiles')),
                  ], child: Text(t('view.baseMap'))),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, leadingIcon: const Icon(Icons.language, size: 16), menuChildren: [
                    for (final l in supportedLanguages)
                      RadioMenuButton<String>(value: l, groupValue: c.lang, onChanged: (v) => c.setLanguage(v ?? 'en'), child: Text(t('lang.$l'))),
                  ], child: Text(t('view.language'))),
                ], child: Text(t('menu.view'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuDraw, menuChildren: [
                  for (final id in [ToolId.line, ToolId.polyline, ToolId.rect, ToolId.circle, ToolId.arc, ToolId.spline, ToolId.hatch, ToolId.symbol, ToolId.text, ToolId.dimension, ToolId.dimAngular, ToolId.dimRadial, ToolId.leader, ToolId.contour, ToolId.spot, ToolId.area, ToolId.measure, ToolId.profile])
                    tool(id),
                ], child: Text(t('menu.draw'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuZone, menuChildren: [
                  for (final id in [ToolId.zonePipe, ToolId.sprayline, ToolId.tape, ToolId.outlet, ToolId.valve, ToolId.misc, ToolId.junction, ToolId.block, ToolId.autohead])
                    tool(id, scope: id == ToolId.misc || id == ToolId.junction || id == ToolId.outlet ? pointScopeZone : null),
                  const Divider(height: 1),
                  item(t('zone.feedEnvelope'), c.selection.isEmpty ? null : () => feedEnvelopeAction(c), icon: Icons.straighten, shortcut: 'FE ⏎', key: const Key('menu_feed')),
                ], child: Text(t('menu.zone'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuMain, menuChildren: [
                  item(t('tool.supply'), () => c.setTool(ToolId.supply), shortcut: 'WS ⏎'),
                  item(t('tool.mainPipe'), () => c.setTool(ToolId.mainPipe), shortcut: 'MP ⏎'),
                  item(t('tool.pump'), shortcut: 'PU ⏎', () {
                    c.toolSettings.pointScope = pointScopeMain;
                    c.setTool(ToolId.pump);
                  }),
                  item('${t('tool.misc')} (${t('scope.mainline')})', () {
                    c.toolSettings.pointScope = pointScopeMain;
                    c.setTool(ToolId.misc);
                  }),
                  item('${t('tool.outlet')} (${t('scope.mainline')})', () {
                    c.toolSettings.pointScope = pointScopeMain;
                    c.setTool(ToolId.outlet);
                  }),
                  item('${t('tool.junction')} (${t('scope.mainline')})', () {
                    c.toolSettings.pointScope = pointScopeMain;
                    c.setTool(ToolId.junction);
                  }),
                  const Divider(height: 1),
                  item(t('design.pumpSelect'), c.results == null ? null : () => showPumpSelectionDialog(context, c), icon: Icons.settings_suggest_outlined, key: const Key('menu_pump_select')),
                  const Divider(height: 1),
                  item(t('tool.pivot'), () => c.setTool(ToolId.pivot), icon: Icons.radar, shortcut: 'PV ⏎', key: const Key('menu_pivot')),
                ], child: Text(t('menu.mainline'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuDesign, menuChildren: [
                  item(t('design.params'), () => showDesignParamsDialog(context, c), icon: Icons.tune),
                  item(t('design.catalog'), () => showCatalogEditorDialog(context, c), icon: Icons.inventory_2_outlined, key: const Key('menu_catalog')),
                  item(t('design.management'), () => showManagementDialog(context, c), icon: Icons.schedule),
                  SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuTerrain, leadingIcon: const Icon(Icons.terrain, size: 16), menuChildren: [
                    tool(ToolId.contour),
                    tool(ToolId.spot),
                    tool(ToolId.profile),
                    const Divider(height: 1),
                    item(t('terrain.onlineDem'), () => showOnlineDemDialog(context, c), icon: Icons.cloud_download_outlined, key: const Key('menu_dem_online')),
                    item(t('terrain.generateContours'), () => showGenerateContoursDialog(context, c), icon: Icons.gesture, key: const Key('menu_gen_contours')),
                    item(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.view_in_ar_outlined, key: const Key('menu_dem3d')),
                    item(t('terrain.clearProfile'), c.profilePath == null ? null : c.clearProfile, icon: Icons.close, key: const Key('menu_clear_profile')),
                    const Divider(height: 1),
                    for (final m in TerrainMethod.values)
                      RadioMenuButton<TerrainMethod>(value: m, groupValue: c.project.params.terrainMethod, onChanged: (v) {
                        c.project.params.terrainMethod = v ?? TerrainMethod.tin;
                        c.results = null;
                        c.dirty = true;
                        c.refresh();
                      }, child: Text(t(m == TerrainMethod.tin ? 'terrain.tin' : 'terrain.idw'))),
                  ], child: Text(t('menu.terrain'))),
                  const Divider(height: 1),
                  item(t('design.check'), () => showDesignCheckDialog(context, c), icon: Icons.fact_check_outlined, shortcut: 'CHK ⏎', key: const Key('menu_check')),
                  item(t('design.zone'), c.busy ? null : () => c.runDesign(sizeZones: true, sizeMain: false), icon: Icons.account_tree_outlined),
                  item(t('design.mainline'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: true), icon: Icons.timeline),
                  item(t('design.all'), c.busy ? null : () => c.runDesign(), icon: Icons.play_arrow, shortcut: 'F5'),
                  item(t('design.analyze'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: false), icon: Icons.analytics_outlined),
                  const Divider(height: 1),
                  item(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.terrain, key: const Key('menu_dem3d_top')),
                  item(t('design.clear'), c.results == null ? null : c.clearResults, icon: Icons.clear_all),
                ], child: Text(t('menu.design'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuReports, menuChildren: [
                  for (var i = 0; i < reportTabKeys.length; i++)
                    item(t(reportTabKeys[i]), () {
                      c.reportTab = i;
                      c.showReports = true;
                      c.refresh();
                    }),
                ], child: Text(t('menu.reports'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuTools, menuChildren: [
                  item(t('tools.lateral'), () => showLateralCalculator(context, c), icon: Icons.calculate_outlined),
                  item(t('tools.pump'), () => showPumpCalculator(context, c), icon: Icons.settings_input_component),
                  item(t('tools.hammer'), () => showHammerCalculator(context, c), icon: Icons.bolt),
                  item(t('tools.units'), () => showUnitsDialog(context, c), icon: Icons.straighten),
                ], child: Text(t('menu.tools'))),
                SubmenuButton(onOpen: _menuOpened, onClose: _menuClosed, key: TutorialTargets.menuHelp, menuChildren: [
                  item(t('help.tutorial'), onStartTutorial, icon: Icons.school_outlined),
                  item(t('help.welcome'), onShowWelcome, icon: Icons.waving_hand_outlined, key: const Key('menu_welcome')),
                  item(t('help.shortcuts'), () => showShortcutsDialog(context, c), icon: Icons.keyboard_outlined),
                  item(t('help.about'), () => showAboutDialogApp(context, c), icon: Icons.info_outline),
                ], child: Text(t('menu.help'))),
              ],
            ),
          ),
          if (c.busy) const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(key: TutorialTargets.runButton, tooltip: t('design.all'), icon: const Icon(Icons.play_arrow, color: Color(0xFF66BB6A)), onPressed: c.busy ? null : () => c.runDesign()),
          IconButton(key: TutorialTargets.saveButton, tooltip: t('file.save'), icon: Icon(Icons.save_outlined, color: c.dirty ? Colors.amber : null), onPressed: () => saveProjectAction(context, c)),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

void _menuOpened() => AppMenuBar.openMenus.value++;

void _menuClosed() => AppMenuBar.openMenus.value = AppMenuBar.openMenus.value > 0 ? AppMenuBar.openMenus.value - 1 : 0;
