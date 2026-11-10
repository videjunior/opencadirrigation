import 'package:flutter/material.dart';

import '../../core/io/project_export.dart';
import '../../core/model/entities.dart';
import '../../core/model/terrain.dart';
import '../actions.dart';
import '../examples.dart';
import '../i18n.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import '../state/insert_project.dart';
import '../state/workspace.dart';
import '../theme.dart';
import '../tools/area_hole_commands.dart';
import '../tools/edit_commands.dart';
import '../tutorial/tutorial.dart';
import '../io/png_export.dart';
import 'dialogs/basemap_dialogs.dart';
import 'dialogs/blocks_dialogs.dart';
import 'dialogs/data_terms_dialog.dart'; // 1.6.0 SIT
import 'dialogs/field_map_dialog.dart'; // 1.6.0 SIT
import 'dialogs/agronomy_dialogs.dart';
// 1.6.0 AGB
import 'dialogs/agb_dialogs.dart';
import 'dialogs/field_machine_dialogs.dart';
import 'dialogs/crop_plan_dialogs.dart';
import 'dialogs/ai_assistant_dialog.dart';
import 'dialogs/auto_design_dialogs.dart';
import 'dialogs/deliverables_dialogs.dart'; // 1.6.0 PRB
import 'dialogs/densogram_dialog.dart';
import 'dialogs/water_balance_dialogs.dart';
import 'dialogs/climate_risk_dialog.dart'; // 1.7.0 CLR
import 'dialogs/field_calculators.dart';
import 'dialogs/network_ops_dialogs.dart';
// 1.6.0 MOT: ageing and clogging
import 'dialogs/life_scenarios_dialog.dart';
import 'dialogs/vegetation_dialog.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/export_dialogs.dart';
import 'dialogs/more_dialogs.dart';
import 'dialogs/shortcuts_dialog.dart';
import 'dialogs/selection_dialogs.dart';
import 'cad_plus_menus.dart';
import 'dialogs/storage_dialog.dart';
import 'dialogs/terrain_dialogs.dart';
import 'dialogs/transient_dialogs.dart';
import 'dialogs/welcome_dialog.dart';
import 'dialogs/document_package_dialog.dart'; // 1.6.0 PRD
import 'dialogs/title_block_dialog.dart'; // 1.6.0 PRD
// 1.6.0 FMT
import 'dialogs/data_cache_dialog.dart';
import 'dialogs/stakeout_dialog.dart';
import 'advice_panel.dart';
import 'message_log.dart';
import 'reports_panel.dart';
import '../project_name.dart'; // 1.6.0 UI
import 'dialogs/command_palette.dart'; // 1.6.0 UI
import 'dialogs/feedback_dialog.dart'; // 1.6.0 UI
import 'dialogs/help_dialog.dart'; // 1.6.0 UI
import 'dialogs/whats_new_dialog.dart'; // 1.6.0 UI
import 'interface_menu.dart'; // 1.6.0 UI

class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key, required this.c, this.ws, this.onStartTutorial, this.onShowWelcome, this.onCloseTab, this.onCommand});

  /// Number of open menus (the keyboard dispatcher leaves arrows, Enter and
  /// Esc to an open menu).
  static final ValueNotifier<int> openMenus = ValueNotifier<int>(0);

  /// The menu bar on the screen (1.6.0 UI: the command palette reads its items).
  static final GlobalKey barKey = GlobalKey(debugLabel: 'menuBar');
  final ProjectController c;

  /// Tabs and clipboard (null when the bar is used standalone).
  final Workspace? ws;
  final VoidCallback? onStartTutorial;

  /// Help → Welcome and example gallery.
  final VoidCallback? onShowWelcome;
  final VoidCallback? onCloseTab;

  /// Runs a typed command as the keyboard would (1.6.0 UI: the palette's commands).
  final void Function(String alias)? onCommand;

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
                        for (final p in recent.take(8)) item(storedProjectLabel(t, p), ws == null ? null : () => openStoredAction(ws!, p), key: Key('recent_${p.uid}')),
                        // 1.6.0 CAD: what these copies are (kept in this browser only), and all of them at once
                        const Divider(height: 1),
                        item(t('file.storage'), () => showStorageDialog(context, c), icon: Icons.storage_outlined, key: const Key('menu_recent_storage')),
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
                      menuChildren: [
                        for (final ex in exampleGallery)
                          item(
                            t(ex.titleKey),
                            () => openExampleAction(context, c, ex.id, ws: ws),
                            icon: exampleIcon(ex.id),
                            key: Key('menu_example_${ex.id.name}'),
                          ),
                      ],
                      child: Text(t('file.examples')),
                    ),
                    const Divider(height: 1),
                    item(t('file.importDrawing'), () => importDrawingAction(context, c), icon: Icons.upload_file, shortcut: 'Ctrl+I'),
                    // 1.6.0 MOD: another project into this one
                    item(t('file.insertProject'), () => insertProjectAction(context, c), icon: Icons.merge_type, key: const Key('menu_insert_project')),
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
                        // 1.6.0 FMT
                        item(t('exp.stakeout'), () => showStakeoutDialog(context, c), key: const Key('menu_export_stakeout')),
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
                    // 1.6.0 PRD
                    item(t('prd.menu.package'), () => showDocumentPackageDialog(context, c), icon: Icons.picture_as_pdf_outlined, key: const Key('menu_document_package')),
                    const Divider(height: 1),
                    item(t('file.shareLink'), () => shareLinkAction(context, c), icon: Icons.share_outlined, key: const Key('menu_share_link')),
                    item(t('file.details'), () => showProjectDetailsDialog(context, c), icon: Icons.info_outline),
                    // 1.6.0 PRD
                    item(t('prd.menu.titleBlock'), () => showTitleBlockDialog(context, c), icon: Icons.badge_outlined, key: const Key('menu_title_block')),
                    item(t('file.georef'), () => showGeoreferenceDialog(context, c), icon: Icons.public),
                    // 1.6.0 CAD
                    const Divider(height: 1),
                    item(t('file.saveAs'), () => saveProjectAction(context, c, saveAs: true), icon: Icons.save_as_outlined, key: const Key('menu_save_as')),
                    item(t('file.saveCopy'), () => saveCopyAction(context, c), icon: Icons.file_copy_outlined, key: const Key('menu_save_copy')),
                    item(t('file.storage'), () => showStorageDialog(context, c), icon: Icons.storage_outlined, key: const Key('menu_storage')),
                    // 1.6.0 CAD+: compare with another copy, the comments of a copy
                    ...cadPlusFileItems(context, c, item),
                    // 1.6.0 FMT
                    item(t('cache.menu'), () => showDataCacheDialog(context, c), icon: Icons.cloud_download_outlined, key: const Key('menu_data_cache')),
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
                    // 1.6.0 EDT: editing by base point, selection filters
                    const Divider(height: 1),
                    tool(ToolId.move),
                    tool(ToolId.copy),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_select'),
                      leadingIcon: const Icon(Icons.select_all, size: 16),
                      menuChildren: [
                        item(t('sel.similar'), c.selection.isEmpty ? null : c.selectSimilar, shortcut: 'SIMILAR ⏎', key: const Key('menu_select_similar')),
                        item(t('sel.quick'), () => showQuickSelectDialog(context, c), shortcut: 'QSELECT ⏎', key: const Key('menu_quick_select')),
                        item(t('sel.layer'), c.selectOnLayer, shortcut: 'SELLAYER ⏎', key: const Key('menu_select_layer')),
                        tool(ToolId.lasso),
                        tool(ToolId.fence),
                      ],
                      child: Text(t('sel.menu')),
                    ),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_geometry'),
                      leadingIcon: const Icon(Icons.architecture, size: 16),
                      menuChildren: [
                        for (final id in [ToolId.stretch, ToolId.fillet, ToolId.chamfer, ToolId.breakTwo]) tool(id),
                        const Divider(height: 1),
                        item(t('edt.join'), c.selection.isEmpty ? null : c.joinSelected, shortcut: 'JOIN ⏎', key: const Key('menu_join')),
                        item(t('edt.explode'), c.selection.isEmpty ? null : c.explodeSelected, shortcut: 'X ⏎', key: const Key('menu_explode')),
                        item(t('edt.toArea'), c.selection.isEmpty ? null : c.convertSelectedToArea, shortcut: 'TOAREA ⏎', key: const Key('menu_to_area')),
                        // 1.6.0 MOD: islands of the irrigated areas
                        item(t('area.subtract'), c.selection.isEmpty ? null : c.subtractSelectedFromAreas, key: const Key('menu_area_subtract')),
                        item(t('area.holes.clear'), c.selection.isEmpty ? null : c.clearSelectedAreaHoles, key: const Key('menu_area_holes_clear')),
                      ],
                      child: Text(t('edt.geometry')),
                    ),
                    // 1.6.0 CAD+: lengthen, outline by a click, drawing order, blocks
                    ...cadPlusEditItems(context, c, item),
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
                        // 1.6.0 CAD
                        const Divider(height: 1),
                        item(t('basemap.osm.menu'), () => showStreetsServerDialog(context, c), icon: Icons.dns_outlined, key: const Key('menu_osm_server')),
                        item(t('basemap.terms.menu'), () => showBaseMapTermsDialog(context, c), icon: Icons.gavel_outlined, key: const Key('menu_map_terms')),
                        // 1.6.0 SIT: the map of the area kept in the project, for the field without a network (PRD-09)
                        item(t('fieldmap.menu'), () => showFieldMapDialog(context, c), icon: Icons.download_for_offline_outlined, key: const Key('menu_field_map')),
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
                    // 1.6.0 UI: the size and the contrast of the interface, focus mode, the side panel
                    interfaceMenu(c, onOpen: _menuOpened, onClose: _menuClosed),
                    // 1.6.0 CAD+: object snaps, layer states and isolation
                    ...cadPlusViewItems(context, c, item),
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
                      ToolId.traceImage, // 1.6.0 AUT
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
                        // 1.6.0 CAD
                        item(t('gps.walkDiscard'), c.gpsTrack == null && !c.hasKeptWalk ? null : c.discardGpsTrack, icon: Icons.delete_sweep_outlined, key: const Key('menu_gps_walk_discard')),
                      ],
                      child: Text(t('gps.submenu')),
                    ),
                    // 1.6.0 CAD+: dimension style, field photo
                    ...cadPlusDrawItems(context, c, item),
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
                    // 1.6.0 AGB
                    item(t('agb.tw.menu'), () => showTwoWireDialog(context, c), icon: Icons.settings_ethernet, key: const Key('menu_agb_two_wire')),
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
                    // 1.6.0 MOT: the design over its life (ageing and clogging)
                    item(t('life.menu'), c.results == null ? null : () => showLifeScenariosDialog(context, c), icon: Icons.hourglass_bottom, key: const Key('menu_life')),
                    item(t('fert.menu'), () => showFertigationDialog(context, c), icon: Icons.science_outlined, shortcut: 'FERT ⏎', key: const Key('menu_fertigation')),
                    const Divider(height: 1),
                    item(t('tool.pivot'), () => c.setTool(ToolId.pivot), icon: Icons.radar, shortcut: 'PV ⏎', key: const Key('menu_pivot')),
                    // 1.6.0 AGB: travelling guns and furrows as parts of the design
                    item(t('agb.trav.menu'), () => showTravellerLanesDialog(context, c), icon: Icons.agriculture, key: const Key('menu_agb_traveller')),
                    item(t('agb.furrow.menu'), () => showFurrowSetDialog(context, c), icon: Icons.view_week, key: const Key('menu_agb_furrows')),
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
                    // 1.6.0 AGB: pump house electrics, solar pumping, water quality
                    item(t('agb.ph.menu'), () => showPumpHouseDialog(context, c), icon: Icons.electrical_services_outlined, key: const Key('menu_agb_pump_house')),
                    item(t('agb.solar.menu'), () => showSolarDesignDialog(context, c), icon: Icons.solar_power, key: const Key('menu_agb_solar')),
                    item(t('agb.water.menu'), () => showWaterQualityDialog(context, c), icon: Icons.water_drop, key: const Key('menu_agb_water')),
                    // 1.6.0 AGR: water balance, programme, runoff, fertigation by stage, field uniformity, user crops
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_agronomy'),
                      leadingIcon: const Icon(Icons.eco_outlined, size: 16),
                      menuChildren: [
                        item(t('swb.menu'), () => showWaterBalanceDialog(context, c), icon: Icons.water_drop_outlined, key: const Key('menu_water_balance')),
                        item(t('clr.menu'), () => showClimateRiskDialog(context, c), icon: Icons.thunderstorm_outlined, key: const Key('menu_climate_risk')), // 1.7.0 CLR
                        item(t('prog.menu'), () => showIrrigationProgrammeDialog(context, c), icon: Icons.event_repeat, key: const Key('menu_programme')),
                        item(t('ro.menu'), () => showRunoffPotentialDialog(context, c), icon: Icons.waves, key: const Key('menu_runoff')),
                        item(t('fst.menu'), () => showFertigationStagesDialog(context, c), icon: Icons.science_outlined, key: const Key('menu_fert_stages')),
                        item(t('ft.menu'), () => showFieldUniformityDialog(context, c), icon: Icons.grid_on, key: const Key('menu_field_uniformity')),
                        item(t('uc.menu'), () => showUserCropsDialog(context, c), icon: Icons.spa_outlined, key: const Key('menu_user_crops')),
                      ],
                      child: Text(t('agr.menu')),
                    ),
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
                        // 1.6.0 AGB
                        item(t('agb.mp.menu'), () => showMultiPivotDialog(context, c), icon: Icons.blur_circular, key: const Key('menu_agb_multi_pivot')),
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
                    // 1.6.0 PRB: the technical documents
                    const Divider(height: 1),
                    SubmenuButton(
                      onOpen: _menuOpened,
                      onClose: _menuClosed,
                      key: const Key('menu_prb_docs'),
                      leadingIcon: const Icon(Icons.description_outlined, size: 16),
                      menuChildren: [
                        item(t('prb.menu.permit'), () => showPermitTableDialog(context, c), icon: Icons.water_drop_outlined, key: const Key('menu_prb_permit')),
                        item(t('prb.menu.memorial'), () => showMemorialDialog(context, c), icon: Icons.notes, key: const Key('menu_prb_memorial')),
                        item(t('prb.menu.om'), () => showOmPlanDialog(context, c), icon: Icons.fact_check_outlined, key: const Key('menu_prb_om')),
                        item(t('prb.menu.budget'), () => showBudgetDialog(context, c), icon: Icons.request_quote_outlined, key: const Key('menu_prb_budget')),
                        item(t('prb.menu.lcc'), () => showLifeCycleDialog(context, c), icon: Icons.savings_outlined, key: const Key('menu_prb_lcc')),
                      ],
                      child: Text(t('prb.menu.docs')),
                    ),
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
                    item(
                      t('pal.menu'),
                      () => showCommandPalette(context, c, runAlias: onCommand),
                      icon: Icons.search,
                      shortcut: 'Ctrl+K',
                      key: const Key('menu_palette'),
                    ),
                    item(t('help.manual'), () => showHelpDialog(context, c), icon: Icons.menu_book_outlined, shortcut: 'F1', key: const Key('menu_manual')),
                    item(t('new.menu'), () => showWhatsNewDialog(context, c), icon: Icons.new_releases_outlined, key: const Key('menu_whats_new')),
                    item(t('fb.menu'), () => showFeedbackDialog(context, c), icon: Icons.bug_report_outlined, key: const Key('menu_feedback')),
                    // 1.6.0 SIT: the terms of the third-party data in professional work (PRD-06)
                    item(t('terms.menu'), () => showDataTermsDialog(context, c), icon: Icons.policy_outlined, key: const Key('menu_data_terms')),
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
    key: AppMenuBar.barKey,
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
