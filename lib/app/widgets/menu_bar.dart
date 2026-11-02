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
import '../theme.dart';
import '../tutorial/tutorial.dart';
import '../io/png_export.dart';
import 'dialogs/basemap_dialogs.dart';
import 'dialogs/blocks_dialogs.dart';
import 'dialogs/agronomy_dialogs.dart';
import 'dialogs/ai_assistant_dialog.dart';
import 'dialogs/auto_design_dialogs.dart';
import 'dialogs/densogram_dialog.dart';
import 'dialogs/field_calculators.dart';
import 'dialogs/network_ops_dialogs.dart';
import 'dialogs/vegetation_dialog.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/export_dialogs.dart';
import 'dialogs/more_dialogs.dart';
import 'dialogs/shortcuts_dialog.dart';
import 'dialogs/terrain_dialogs.dart';
import 'dialogs/transient_dialogs.dart';
import 'dialogs/welcome_dialog.dart';
import 'advice_panel.dart';
import 'message_log.dart';
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
      trailingIcon: shortcut != null ? Text(shortcut, style: TextStyle(fontSize: 10, color: Cad.fg38)) : null,
      child: Text(label),
    );
    MenuItemButton tool(ToolId id, {HydraulicScope? scope}) => item(t('tool.${id.name}'), () {
      if (scope != null) c.toolSettings.pointScope = scope;
      c.setTool(id);
    }, shortcut: '${aliasOf(id)} ⏎');
    final recent = c.store.list();
    return Container(
      color: Cad.menu,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Image.asset('assets/brand/logo-mark.png', height: 24, filterQuality: FilterQuality.medium, semanticLabel: 'OpenCADIrrigation'),
          const SizedBox(width: 6),
          Text(t('app.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            // the menus that do not fit the window go under "⋯" (no hidden
            // horizontal scroll the mouse wheel cannot reach)
            child: LayoutBuilder(
              builder: (context, box) => _fitMenus(context, box.maxWidth, [
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuFile,
                  menuChildren: [
                    item(t('file.new'), () => confirmNew(context, c), icon: Icons.note_add_outlined),
                    if (ws != null) item(t('file.newTab'), () => ws!.addTab(), icon: Icons.tab_outlined, shortcut: 'Ctrl+Alt+N'),
                    if (ws != null) item(t('file.closeTab'), onCloseTab, icon: Icons.tab_unselected, shortcut: 'Ctrl+Alt+W'),
                    item(t('file.open'), () => ws == null ? openProjectAction(context, c) : openProjectInTabAction(context, ws!), icon: Icons.folder_open, shortcut: 'Ctrl+O'),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.history, size: 16),
                      menuChildren: [
                        if (recent.isEmpty) item(t('file.noRecent'), null),
                        for (final p in recent.take(8)) item(p.name.isEmpty ? p.uid : p.name, ws == null ? null : () => openStoredAction(ws!, p), key: Key('recent_${p.uid}')),
                      ],
                      child: Text(t('file.recent')),
                    ),
                    item(t('file.save'), () => saveProjectAction(context, c), icon: Icons.save_outlined, shortcut: 'Ctrl+S'),
                    item(t('file.versions'), () => showVersionsDialog(context, c), icon: Icons.layers_outlined),
                    CheckboxMenuButton(
                      value: c.autosaveEnabled,
                      onChanged: (v) {
                        c.autosaveEnabled = v ?? true;
                        c.refresh();
                      },
                      child: Text(t('file.autosave')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_examples'),
                      leadingIcon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      menuChildren: [for (final ex in exampleGallery) item(t(ex.titleKey), () => loadExampleAction(c, ex.id), icon: exampleIcon(ex.id), key: Key('menu_example_${ex.id.name}'))],
                      child: Text(t('file.examples')),
                    ),
                    const Divider(height: 1),
                    item(t('file.importDrawing'), () => importDrawingAction(context, c), icon: Icons.upload_file, shortcut: 'Ctrl+I'),
                    item(t('file.georefImage'), c.selectedEntity == null ? null : () => showImageGeorefDialog(context, c), icon: Icons.image_outlined),
                    item(t('tool.alignImage'), c.selection.isEmpty ? null : () => c.setTool(ToolId.alignImage), icon: Icons.control_camera, shortcut: 'AL ⏎', key: const Key('menu_align')),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: TutorialTargets.menuExportDrawing,
                      leadingIcon: const Icon(Icons.download, size: 16),
                      menuChildren: [
                        for (final f in DrawingFormat.values) item(t('exp.${f.name}'), () => exportDrawingAction(context, c, f)),
                        item(t('exp.png'), () => exportSheetPngAction(context, c), key: const Key('menu_export_png')),
                      ],
                      child: Text(t('file.exportDrawing')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.table_view, size: 16),
                      menuChildren: [
                        for (final f in ReportFormat.values) item(t(f == ReportFormat.pdf ? 'exp.reportPdf' : 'exp.${f.name}'), () => exportReportAction(context, c, f)),
                        const Divider(height: 1),
                        item(t('mgmt.export'), () => exportScheduleAction(context, c)),
                      ],
                      child: Text(t('file.exportReport')),
                    ),
                    const Divider(height: 1),
                    item(t('file.shareLink'), () => shareLinkAction(context, c), icon: Icons.share_outlined, key: const Key('menu_share_link')),
                    item(t('file.details'), () => showProjectDetailsDialog(context, c), icon: Icons.info_outline),
                    item(t('file.georef'), () => showGeoreferenceDialog(context, c), icon: Icons.public),
                  ],
                  child: Text(t('menu.file')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuEdit,
                  menuChildren: [
                    item(t('edit.undo'), c.canUndo ? c.undo : null, icon: Icons.undo, shortcut: 'Ctrl+Z'),
                    item(t('edit.redo'), c.canRedo ? c.redo : null, icon: Icons.redo, shortcut: 'Ctrl+Y'),
                    const Divider(height: 1),
                    item(t('edit.selectAll'), c.selectAll, shortcut: 'Ctrl+A'),
                    item(t('edit.clipCopy'), c.selection.isEmpty || ws == null ? null : () => copySelectionAction(ws!), icon: Icons.copy_outlined, shortcut: 'Ctrl+C'),
                    item(t('edit.clipCut'), c.selection.isEmpty || ws == null ? null : () => copySelectionAction(ws!, cut: true), icon: Icons.content_cut, shortcut: 'Ctrl+X'),
                    item(t('edit.paste'), ws == null ? null : () => pasteAction(ws!), icon: Icons.content_paste, shortcut: 'Ctrl+V'),
                    item(t('edit.copy'), c.selection.isEmpty ? null : c.duplicateSelected, shortcut: 'Ctrl+D'),
                    item(t('edit.delete'), c.selection.isEmpty ? null : c.deleteSelected, icon: Icons.delete_outline, shortcut: 'Del'),
                    item(t('bomSel.menu'), c.selection.isEmpty ? null : () => showSelectionBomDialog(context, c), icon: Icons.receipt_long_outlined, key: const Key('menu_selection_bom')),
                    item(
                      t('blk.save'),
                      c.selection.isEmpty ? null : () => saveBlockAction(context, c, c.project.blocks),
                      icon: Icons.widgets_outlined,
                      shortcut: 'WBLOCK ⏎',
                      key: const Key('menu_block_save'),
                    ),
                    item(
                      t('blk.insert'),
                      () => insertBlockAction(context, c, c.project.blocks, pickTool: ToolId.insertBlock),
                      icon: Icons.input,
                      shortcut: 'INSERT ⏎',
                      key: const Key('menu_block_insert'),
                    ),
                    const Divider(height: 1),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.transform, size: 16),
                      menuChildren: [
                        for (final id in [ToolId.rotate, ToolId.mirror, ToolId.scale, ToolId.offset, ToolId.trim, ToolId.extend, ToolId.cutPipe, ToolId.alignImage]) tool(id),
                        const Divider(height: 1),
                        item(t('edit.array'), c.selection.isEmpty ? null : () => showArrayDialog(context, c), shortcut: 'ARRAY ⏎', key: const Key('menu_array')),
                      ],
                      child: Text(t('edit.transform')),
                    ),
                  ],
                  child: Text(t('menu.edit')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuView,
                  menuChildren: [
                    item(t('view.zoomAll'), c.zoomAll, icon: Icons.fit_screen, shortcut: 'Home'),
                    item(t('view.zoomIn'), () => c.zoomBy(1.25), icon: Icons.zoom_in, shortcut: '+'),
                    item(t('view.zoomOut'), () => c.zoomBy(0.8), icon: Icons.zoom_out, shortcut: '-'),
                    const Divider(height: 1),
                    CheckboxMenuButton(
                      value: c.showGrid,
                      onChanged: (v) {
                        c.showGrid = v ?? true;
                        c.refresh();
                      },
                      child: Text('${t('view.grid')}  (F7)'),
                    ),
                    CheckboxMenuButton(
                      value: c.showLabels,
                      onChanged: (v) {
                        c.showLabels = v ?? true;
                        c.refresh();
                      },
                      child: Text(t('view.labels')),
                    ),
                    CheckboxMenuButton(
                      value: c.showWettedRadii,
                      onChanged: (v) {
                        c.showWettedRadii = v ?? true;
                        c.refresh();
                      },
                      child: Text(t('view.wetted')),
                    ),
                    CheckboxMenuButton(
                      value: c.showGrips,
                      onChanged: (v) {
                        c.showGrips = v ?? true;
                        c.refresh();
                      },
                      child: Text(t('view.grips')),
                    ),
                    item(t('lbl.menu'), () => showLabelRulesDialog(context, c), icon: Icons.label_important_outline, key: const Key('menu_label_rules')),
                    CheckboxMenuButton(key: const Key('menu_gps'), value: c.gpsActive, onChanged: (v) => (v ?? false) ? c.startGps() : c.stopGps(), child: Text(t('gps.menu'))),
                    const Divider(height: 1),
                    for (final m in OverlayMode.values)
                      RadioMenuButton<OverlayMode>(
                        value: m,
                        groupValue: c.overlay,
                        onChanged: (v) {
                          c.overlay = v ?? OverlayMode.none;
                          c.refresh();
                        },
                        child: Text(t('view.overlay.${m.name}')),
                      ),
                    const Divider(height: 1),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.map_outlined, size: 16),
                      menuChildren: [
                        for (final m in const [BaseMap.none, BaseMap.streets, BaseMap.topo, BaseMap.carto, BaseMap.satellite, BaseMap.esriStreets, BaseMap.esriTopo])
                          RadioMenuButton<BaseMap>(value: m, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.${m.name}'))),
                        const Divider(height: 1),
                        for (final m in const [BaseMap.googleRoads, BaseMap.googleSatellite, BaseMap.googleHybrid, BaseMap.googleTerrain])
                          RadioMenuButton<BaseMap>(value: m, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.${m.name}'))),
                        item(t('view.baseMap.googleKey'), () => showGoogleMapsKeyDialog(context, c), icon: Icons.key_outlined, key: const Key('menu_google_key')),
                        const Divider(height: 1),
                        RadioMenuButton<BaseMap>(value: BaseMap.custom, groupValue: c.baseMap, onChanged: (v) => selectBaseMap(context, c, v ?? BaseMap.none), child: Text(t('view.baseMap.custom'))),
                        item(t('view.baseMap.customUrl'), () => showCustomTilesDialog(context, c), icon: Icons.link, key: const Key('menu_custom_tiles')),
                      ],
                      child: Text(t('view.baseMap')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.language, size: 16),
                      menuChildren: [
                        for (final l in supportedLanguages) RadioMenuButton<String>(value: l, groupValue: c.lang, onChanged: (v) => c.setLanguage(v ?? 'en'), child: Text(languageNames[l] ?? l)),
                      ],
                      child: Text(t('view.language')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_theme'),
                      leadingIcon: const Icon(Icons.contrast, size: 16),
                      menuChildren: [
                        for (final m in CadThemeMode.values)
                          RadioMenuButton<CadThemeMode>(
                            key: Key('menu_theme_${m.name}'),
                            value: m,
                            groupValue: uiThemeMode.value,
                            onChanged: (v) {
                              setThemeMode(v ?? CadThemeMode.dark);
                              c.refresh();
                            },
                            child: Text(t('view.theme.${m.name}')),
                          ),
                      ],
                      child: Text(t('view.theme')),
                    ),
                  ],
                  child: Text(t('menu.view')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuDraw,
                  menuChildren: [
                    for (final id in [
                      ToolId.line,
                      ToolId.polyline,
                      ToolId.rect,
                      ToolId.circle,
                      ToolId.arc,
                      ToolId.spline,
                      ToolId.hatch,
                      ToolId.symbol,
                      ToolId.text,
                      ToolId.dimension,
                      ToolId.dimAngular,
                      ToolId.dimRadial,
                      ToolId.dimOrdinate,
                      ToolId.leader,
                      ToolId.contour,
                      ToolId.spot,
                      ToolId.area,
                      ToolId.measure,
                      ToolId.profile,
                      ToolId.comment,
                      ToolId.revisionCloud,
                    ])
                      tool(id),
                    const Divider(height: 1),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      leadingIcon: const Icon(Icons.my_location, size: 16),
                      menuChildren: [
                        item(t('gps.walkStart'), c.gpsTrack != null ? null : c.startGpsTrack, icon: Icons.directions_walk, key: const Key('menu_gps_walk')),
                        item(t('gps.walkArea'), c.gpsTrack == null ? null : () => c.finishGpsTrack(asArea: true), icon: Icons.crop_square),
                        item(t('gps.walkOutline'), c.gpsTrack == null ? null : () => c.finishGpsTrack(), icon: Icons.pentagon_outlined),
                        item(t('gps.walkLine'), c.gpsTrack == null ? null : () => c.finishGpsTrack(closed: false), icon: Icons.timeline),
                        item(t('gps.mark'), c.gpsPoint == null ? null : c.markGpsPoint, icon: Icons.add_location_alt_outlined, key: const Key('menu_gps_mark')),
                      ],
                      child: Text(t('gps.submenu')),
                    ),
                  ],
                  child: Text(t('menu.draw')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuZone,
                  menuChildren: [
                    for (final id in [ToolId.zonePipe, ToolId.sprayline, ToolId.tape, ToolId.outlet, ToolId.valve, ToolId.misc, ToolId.junction, ToolId.block, ToolId.autohead])
                      tool(id, scope: id == ToolId.misc || id == ToolId.junction || id == ToolId.outlet ? pointScopeZone : null),
                    const Divider(height: 1),
                    item(t('zone.feedEnvelope'), c.selection.isEmpty ? null : () => feedEnvelopeAction(c), icon: Icons.straighten, shortcut: 'FE ⏎', key: const Key('menu_feed')),
                    item(t('dens.menu'), () => showDensogramDialog(context, c), icon: Icons.blur_on, shortcut: 'DENS ⏎', key: const Key('menu_densogram')),
                    item(
                      t('zone.deviceOnLaterals'),
                      c.selection.isEmpty ? null : () => showDeviceOnLateralsDialog(context, c),
                      icon: Icons.settings_input_component_outlined,
                      key: const Key('menu_device_laterals'),
                    ),
                    item(t('zone.toPipe'), c.selection.isEmpty ? null : () => convertToPipeAction(c), icon: Icons.linear_scale, key: const Key('menu_to_pipe')),
                    const Divider(height: 1),
                    item(t('tool.controller'), () => c.setTool(ToolId.controller), icon: Icons.developer_board, shortcut: 'CTRL ⏎', key: const Key('menu_controller')),
                    item(t('tool.wire'), () => c.setTool(ToolId.wire), icon: Icons.cable, shortcut: 'WR ⏎', key: const Key('menu_wire')),
                    item(t('wr.menu'), () => showWireRoutingDialog(context, c), icon: Icons.alt_route, shortcut: 'WROUTE ⏎', key: const Key('menu_wire_routes')),
                  ],
                  child: Text(t('menu.zone')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuMain,
                  menuChildren: [
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
                    item(t('tr.menu'), () => showTransientDialog(context, c), icon: Icons.waves, shortcut: 'SURGE ⏎', key: const Key('menu_transients')),
                    item(t('av.menu'), () => showAirValveDialog(context, c), icon: Icons.air, shortcut: 'AV ⏎', key: const Key('menu_air_valves')),
                    item(t('eps.menu'), () => showEpsDialog(context, c), icon: Icons.schedule_outlined, shortcut: 'EPS ⏎', key: const Key('menu_eps')),
                    const Divider(height: 1),
                    item(t('od.menu'), () => showOnDemandDialog(context, c), icon: Icons.groups_outlined, shortcut: 'DEMAND ⏎', key: const Key('menu_on_demand')),
                    item(t('crit.menu'), () => showCriticalityDialog(context, c), icon: Icons.call_split, shortcut: 'CRIT ⏎', key: const Key('menu_criticality')),
                    item(t('cal.menu'), () => showCalibrationDialog(context, c), icon: Icons.tune, shortcut: 'CALIB ⏎', key: const Key('menu_calibration')),
                    item(t('fert.menu'), () => showFertigationDialog(context, c), icon: Icons.science_outlined, shortcut: 'FERT ⏎', key: const Key('menu_fertigation')),
                    const Divider(height: 1),
                    item(t('tool.pivot'), () => c.setTool(ToolId.pivot), icon: Icons.radar, shortcut: 'PV ⏎', key: const Key('menu_pivot')),
                  ],
                  child: Text(t('menu.mainline')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuDesign,
                  menuChildren: [
                    item(t('design.params'), () => showDesignParamsDialog(context, c), icon: Icons.tune),
                    item(t('design.catalog'), () => showCatalogEditorDialog(context, c), icon: Icons.inventory_2_outlined, key: const Key('menu_catalog')),
                    item(t('design.management'), () => showManagementDialog(context, c), icon: Icons.schedule),
                    item(t('tar.menu'), () => showTariffDialog(context, c), icon: Icons.price_change_outlined, shortcut: 'TARIFF ⏎', key: const Key('menu_tariff')),
                    item(t('eg.menu'), () => showEnergyGroupingDialog(context, c), icon: Icons.bolt, shortcut: 'EGROUP ⏎', key: const Key('menu_energy_groups')),
                    item(t('design.proposal'), () => showProposalDialog(context, c), icon: Icons.request_quote_outlined, key: const Key('menu_proposal')),
                    item(t('design.scenarios'), () => showScenariosDialog(context, c), icon: Icons.compare_outlined, key: const Key('menu_scenarios')),
                    item(t('clim.menu'), () => showSiteClimateDialog(context, c), icon: Icons.wb_sunny_outlined, key: const Key('menu_climate')),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: TutorialTargets.menuTerrain,
                      leadingIcon: const Icon(Icons.terrain, size: 16),
                      menuChildren: [
                        tool(ToolId.contour),
                        tool(ToolId.breakline),
                        tool(ToolId.spot),
                        tool(ToolId.profile),
                        const Divider(height: 1),
                        item(t('terrain.onlineDem'), () => showOnlineDemDialog(context, c), icon: Icons.cloud_download_outlined, key: const Key('menu_dem_online')),
                        item(t('terrain.generateContours'), () => showGenerateContoursDialog(context, c), icon: Icons.gesture, key: const Key('menu_gen_contours')),
                        item(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.view_in_ar_outlined, key: const Key('menu_dem3d')),
                        item(t('terrain.clearProfile'), c.profilePath == null ? null : c.clearProfile, icon: Icons.close, key: const Key('menu_clear_profile')),
                        const Divider(height: 1),
                        for (final m in TerrainMethod.values)
                          RadioMenuButton<TerrainMethod>(
                            value: m,
                            groupValue: c.project.params.terrainMethod,
                            onChanged: (v) {
                              final edit = c.beginSettingsEdit('hist.params');
                              c.project.params.terrainMethod = v ?? TerrainMethod.tin;
                              c.commitSettingsEdit(edit);
                            },
                            child: Text(t(m == TerrainMethod.tin ? 'terrain.tin' : 'terrain.idw')),
                          ),
                      ],
                      child: Text(t('menu.terrain')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_auto_design'),
                      leadingIcon: const Icon(Icons.auto_awesome, size: 16),
                      menuChildren: [
                        item(t('autolay.menu'), () => showAutoLayoutDialog(context, c), icon: Icons.auto_awesome_mosaic_outlined, shortcut: 'LAYOUT ⏎', key: const Key('menu_auto_layout')),
                        item(t('tpl.menu'), () => showTemplateDialog(context, c), icon: Icons.sports_soccer_outlined, shortcut: 'TPL ⏎', key: const Key('menu_templates')),
                        item(t('subdiv.menu'), () => showFieldSubdivisionDialog(context, c), icon: Icons.grid_view_outlined, shortcut: 'SUBDIV ⏎', key: const Key('menu_subdivide')),
                        item(t('rings.menu'), () => showTreeRingsDialog(context, c), icon: Icons.park_outlined, shortcut: 'RINGS ⏎', key: const Key('menu_tree_rings')),
                        item(t('pfit.menu'), () => showPivotFitDialog(context, c), icon: Icons.track_changes, shortcut: 'PFIT ⏎', key: const Key('menu_pivot_fit')),
                        item(t('veg.menu'), () => showVegetationDialog(context, c), icon: Icons.image_search, shortcut: 'VEG ⏎', key: const Key('menu_vegetation')),
                      ],
                      child: Text(t('auto.menu')),
                    ),
                    const Divider(height: 1),
                    item(t('design.check'), () => showDesignCheckDialog(context, c), icon: Icons.fact_check_outlined, shortcut: 'CHK ⏎', key: const Key('menu_check')),
                    item(t('adv.fixAll'), c.busy ? null : () => showAutoFixDialog(context, c), icon: Icons.auto_fix_high, shortcut: 'FIX ⏎', key: const Key('menu_autofix')),
                    item('${t('adv.optimize')}…', c.busy ? null : () => showOptimizeDialog(context, c), icon: Icons.savings_outlined, shortcut: 'OPT ⏎', key: const Key('menu_optimize')),
                    item(t('ai.menu'), () => showAiAssistantDialog(context, c), icon: Icons.smart_toy_outlined, shortcut: 'AI ⏎', key: const Key('menu_ai')),
                    item(t('design.zone'), c.busy ? null : () => c.runDesign(sizeZones: true, sizeMain: false), icon: Icons.account_tree_outlined),
                    item(t('design.mainline'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: true), icon: Icons.timeline),
                    item(t('design.all'), c.busy ? null : () => c.runDesign(), icon: Icons.play_arrow, shortcut: 'F5'),
                    item(t('design.analyze'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: false), icon: Icons.analytics_outlined),
                    CheckboxMenuButton(key: const Key('menu_auto_analyze'), value: c.autoAnalyze, onChanged: (v) => c.autoAnalyze = v ?? false, child: Text(t('design.autoAnalyze'))),
                    const Divider(height: 1),
                    item(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.terrain, key: const Key('menu_dem3d_top')),
                    item(t('design.clear'), c.results == null ? null : c.clearResults, icon: Icons.clear_all),
                  ],
                  child: Text(t('menu.design')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuReports,
                  menuChildren: [
                    for (var i = 0; i < reportTabKeys.length; i++)
                      item(t(reportTabKeys[i]), () {
                        c.reportTab = i;
                        c.showReports = true;
                        c.refresh();
                      }),
                  ],
                  child: Text(t('menu.reports')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuTools,
                  menuChildren: [
                    item(t('tools.lateral'), () => showLateralCalculator(context, c), icon: Icons.calculate_outlined),
                    item(t('tools.pump'), () => showPumpCalculator(context, c), icon: Icons.settings_input_component),
                    item(t('tools.hammer'), () => showHammerCalculator(context, c), icon: Icons.bolt),
                    const Divider(height: 1),
                    item(t('solar.menu'), () => showSolarPumpingDialog(context, c), icon: Icons.solar_power_outlined, key: const Key('menu_solar')),
                    item(t('bulb.menu'), () => showWettedBulbDialog(context, c), icon: Icons.water_drop_outlined, key: const Key('menu_bulb')),
                    item(t('wb.menu'), () => showWaterBudgetDialog(context, c), icon: Icons.local_florist_outlined, key: const Key('menu_water_budget')),
                    const Divider(height: 1),
                    item(t('trav.menu'), () => showTravellerCalculator(context, c), icon: Icons.agriculture_outlined, key: const Key('menu_traveller')),
                    item(t('surf.menu'), () => showSurfaceIrrigationCalculator(context, c), icon: Icons.water_outlined, key: const Key('menu_surface')),
                    item(t('gate.menu'), () => showGatedPipeCalculator(context, c), icon: Icons.view_week_outlined, key: const Key('menu_gated_pipe')),
                    const Divider(height: 1),
                    item(t('tools.units'), () => showUnitsDialog(context, c), icon: Icons.straighten),
                  ],
                  child: Text(t('menu.tools')),
                ),
                SubmenuButton(
                  onOpen: _menuOpened,
                  onClose: _menuClosed,
                  key: TutorialTargets.menuHelp,
                  menuChildren: [
                    item(t('help.tutorial'), onStartTutorial, icon: Icons.school_outlined),
                    item(t('help.welcome'), onShowWelcome, icon: Icons.waving_hand_outlined, key: const Key('menu_welcome')),
                    item(t('help.shortcuts'), () => showShortcutsDialog(context, c), icon: Icons.keyboard_outlined),
                    // 1.6.0 UI
                    item(t('ui.messagesMenu'), () => showMessageLogDialog(context, c), icon: Icons.notes_outlined, key: const Key('menu_messages')),
                    item(t('help.about'), () => showAboutDialogApp(context, c), icon: Icons.info_outline),
                  ],
                  child: Text(t('menu.help')),
                ),
              ]),
            ),
          ),
          if (c.busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            key: TutorialTargets.runButton,
            tooltip: t('design.all'),
            icon: Icon(Icons.play_arrow, color: Cad.ok),
            onPressed: c.busy ? null : () => c.runDesign(),
          ),
          IconButton(
            key: TutorialTargets.saveButton,
            tooltip: t('file.save'),
            icon: Icon(Icons.save_outlined, color: c.dirty ? Cad.amber : null),
            onPressed: () => saveProjectAction(context, c),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// The menu bar with as many of [menus] as fit [width] (each measured by
/// its title); the others go into a last "⋯" menu, where they open as
/// submenus.
Widget _fitMenus(BuildContext context, double width, List<SubmenuButton> menus) {
  final style = Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
  final scaler = MediaQuery.textScalerOf(context);
  final dir = Directionality.of(context);
  double titleWidth(Widget? child) {
    final tp = TextPainter(
      text: TextSpan(text: child is Text ? child.data ?? '' : '', style: style),
      textDirection: dir,
      textScaler: scaler,
    )..layout();
    final w = tp.width;
    tp.dispose();
    // the padding of the button (8 on each side) and a little slack
    return w + 18;
  }

  final widths = [for (final m in menus) titleWidth(m.child)];
  // (the bar's own padding)
  final room = width - 8;
  var fit = menus.length;
  if (widths.fold<double>(0, (a, b) => a + b) > room) {
    const more = 40.0;
    var used = 0.0;
    fit = 0;
    for (final w in widths) {
      if (used + w + more > room) break;
      used += w;
      fit++;
    }
  }
  return MenuBar(
    style: MenuStyle(backgroundColor: WidgetStatePropertyAll(Cad.menu), elevation: const WidgetStatePropertyAll(0)),
    children: [
      ...menus.take(fit),
      if (fit < menus.length)
        SubmenuButton(
          key: const Key('menu_more'),
          onOpen: _menuOpened,
          onClose: _menuClosed,
          // copies without the global key of the top menu: a menu moving between the bar and "⋯"
          // as the window is resized is then a new button, never one reparented between menu anchors
          menuChildren: [for (final m in menus.skip(fit)) SubmenuButton(onOpen: m.onOpen, onClose: m.onClose, leadingIcon: m.leadingIcon, menuChildren: m.menuChildren, child: m.child)],
          child: const Text('⋯'),
        ),
    ],
  );
}

void _menuOpened() => AppMenuBar.openMenus.value++;

void _menuClosed() => AppMenuBar.openMenus.value = AppMenuBar.openMenus.value > 0 ? AppMenuBar.openMenus.value - 1 : 0;
