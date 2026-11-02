/// Phone layout: the same controller, canvas, tools and dialogs as the
/// desktop shell, arranged for a narrow touch screen — a compact top bar
/// with a ☰ menu, floating Done / Cancel / Undo / Delete buttons that stand
/// in for Enter / Esc / Ctrl+Z / Del, a bottom tool bar by group, and the
/// properties, layers and reports panels as bottom sheets.
library;

import 'package:flutter/material.dart';

import '../../core/io/project_export.dart';
import '../../core/model/entities.dart';
import '../actions.dart';
import '../i18n.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import '../state/workspace.dart';
import '../examples.dart';
import '../theme.dart';
import '../tutorial/tutorial.dart';
import 'advice_panel.dart';
import 'ai/ai_panel.dart';
import 'dialogs/agronomy_dialogs.dart';
import 'dialogs/ai_assistant_dialog.dart';
import 'dialogs/auto_design_dialogs.dart';
import 'dialogs/field_calculators.dart';
import 'dialogs/network_ops_dialogs.dart';
import 'dialogs/vegetation_dialog.dart';
import 'dialogs/welcome_dialog.dart';
import '../io/png_export.dart';
import 'dialogs/basemap_dialogs.dart';
import 'dialogs/blocks_dialogs.dart';
import 'dialogs/densogram_dialog.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/export_dialogs.dart';
import 'dialogs/more_dialogs.dart';
import 'dialogs/shortcuts_dialog.dart';
import 'dialogs/terrain_dialogs.dart';
import 'dialogs/transient_dialogs.dart';
import 'history_panel.dart';
import 'layers_panel.dart';
import 'properties_panel.dart';
import 'reports_panel.dart';
import 'tool_palette.dart';

/// Screens narrower than this use the phone layout.
const mobileBreakpoint = 700.0;

class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.c,
    required this.ws,
    required this.canvas,
    required this.hint,
    required this.onStartTutorial,
    this.onShowWelcome,
    required this.onCloseTab,
    required this.onDesignCheck,
  });
  final ProjectController c;
  final Workspace ws;
  final Widget canvas;
  final String hint;
  final VoidCallback onStartTutorial;

  /// Help → Welcome and example gallery.
  final VoidCallback? onShowWelcome;
  final VoidCallback onCloseTab;
  final VoidCallback onDesignCheck;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  String _group = 'draw';

  ProjectController get c => widget.c;

  void _toolKey(String key) {
    final k = c.keyTarget;
    k?.toolKey(key);
    if (key == 'Escape' && c.activeTool != ToolId.select && (k?.toolIdle ?? true)) c.setTool(ToolId.select);
    k?.redraw();
    c.refresh();
  }

  Future<void> _sheet(Widget child, {double height = 0.6, Key? key}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Cad.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SizedBox(key: key, height: MediaQuery.sizeOf(ctx).height * height, child: child),
  );

  void _openProperties({int tab = 0}) {
    var index = tab;
    _sheet(
      key: const Key('mobile_props_sheet'),
      StatefulBuilder(
        builder: (ctx, setState) {
          final t = c.t;
          return Column(
            children: [
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Cad.fg24, borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  Expanded(child: _tab(t('props.title'), index == 0, () => setState(() => index = 0))),
                  Expanded(child: _tab(t('view.layers'), index == 1, () => setState(() => index = 1))),
                  Expanded(child: _tab(t('hist.title'), index == 2, () => setState(() => index = 2))),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: c,
                  builder: (_, _) => switch (index) {
                    1 => LayersPanel(c: c),
                    2 => HistoryPanel(c: c),
                    _ => PropertiesPanel(c: c),
                  },
                ),
              ),
            ],
          );
        },
      ),
      height: 0.7,
    );
  }

  void _openReports() {
    c.showReports = true;
    _sheet(
      key: const Key('mobile_reports_sheet'),
      ListenableBuilder(
        listenable: c,
        builder: (_, _) => ReportsPanel(c: c),
      ),
      height: 0.85,
    ).then((_) {
      c.showReports = false;
      c.refresh();
    });
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: on ? Cad.accent : Colors.transparent, width: 2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, color: on ? Cad.fg : Cad.fg60)),
    ),
  );

  // ---------------------------------------------------------------- menu sheet
  void _openMenu() {
    final t = c.t;
    final ws = widget.ws;
    void close() => Navigator.of(context).pop();
    ListTile row(String label, VoidCallback? action, {IconData? icon, Key? key}) => ListTile(
      key: key,
      dense: true,
      leading: icon != null ? Icon(icon, size: 18) : const SizedBox(width: 18),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      enabled: action != null,
      onTap: action == null
          ? null
          : () {
              close();
              action();
            },
    );
    ListTile check(String label, bool value, ValueChanged<bool> on) => ListTile(
      dense: true,
      leading: Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: () {
        on(!value);
        close();
      },
    );
    ExpansionTile section(String title, IconData icon, List<Widget> children, {Key? key, bool open = false}) => ExpansionTile(
      key: key,
      leading: Icon(icon, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
      initiallyExpanded: open,
      childrenPadding: const EdgeInsets.only(left: 12),
      children: children,
    );
    _sheet(
      key: const Key('mobile_menu_sheet'),
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Cad.fg24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          section(t('menu.file'), Icons.folder_outlined, [
            row(t('file.new'), () => confirmNew(context, c), icon: Icons.note_add_outlined),
            row(t('file.open'), () => openProjectInTabAction(context, ws), icon: Icons.folder_open),
            row(t('file.save'), () => saveProjectAction(context, c), icon: Icons.save_outlined),
            row(t('file.versions'), () => showVersionsDialog(context, c), icon: Icons.layers_outlined),
            for (final ex in exampleGallery) row('${t('file.examples')}: ${t(ex.titleKey)}', () => loadExampleAction(c, ex.id), icon: exampleIcon(ex.id)),
            row(t('file.importDrawing'), () => importDrawingAction(context, c), icon: Icons.upload_file),
            row(t('file.georefImage'), c.selectedEntity == null ? null : () => showImageGeorefDialog(context, c), icon: Icons.image_outlined),
            row(t('tool.alignImage'), c.selection.isEmpty ? null : () => c.setTool(ToolId.alignImage), icon: Icons.control_camera),
            for (final f in DrawingFormat.values) row('${t('file.exportDrawing')}: ${t('exp.${f.name}')}', () => exportDrawingAction(context, c, f), icon: Icons.download),
            row('${t('file.exportDrawing')}: ${t('exp.png')}', () => exportSheetPngAction(context, c), icon: Icons.image_outlined, key: const Key('mobile_menu_export_png')),
            for (final f in ReportFormat.values)
              row(
                '${t('file.exportReport')}: ${t(f == ReportFormat.pdf ? 'exp.reportPdf' : 'exp.${f.name}')}',
                c.results == null ? null : () => exportReportAction(context, c, f),
                icon: Icons.table_view,
              ),
            row(t('file.shareLink'), () => shareLinkAction(context, c), icon: Icons.share_outlined),
            row(t('file.details'), () => showProjectDetailsDialog(context, c), icon: Icons.info_outline),
            row(t('file.georef'), () => showGeoreferenceDialog(context, c), icon: Icons.public),
            row(t('file.newTab'), () => ws.addTab(), icon: Icons.tab_outlined),
            row(t('file.closeTab'), widget.onCloseTab, icon: Icons.tab_unselected),
          ], key: const Key('mobile_menu_file')),
          section(t('menu.edit'), Icons.edit_outlined, [
            row(t('edit.undo'), c.canUndo ? c.undo : null, icon: Icons.undo),
            row(t('edit.redo'), c.canRedo ? c.redo : null, icon: Icons.redo),
            row(t('edit.selectAll'), c.selectAll),
            row(t('edit.clipCopy'), c.selection.isEmpty ? null : () => copySelectionAction(ws), icon: Icons.copy_outlined),
            row(t('edit.clipCut'), c.selection.isEmpty ? null : () => copySelectionAction(ws, cut: true), icon: Icons.content_cut),
            row(t('edit.paste'), () => pasteAction(ws), icon: Icons.content_paste),
            row(t('edit.copy'), c.selection.isEmpty ? null : c.duplicateSelected),
            row(t('edit.delete'), c.selection.isEmpty ? null : c.deleteSelected, icon: Icons.delete_outline),
            row(t('bomSel.menu'), c.selection.isEmpty ? null : () => showSelectionBomDialog(context, c), icon: Icons.receipt_long_outlined, key: const Key('mobile_menu_selection_bom')),
            row(t('blk.save'), c.selection.isEmpty ? null : () => saveBlockAction(context, c, c.project.blocks), icon: Icons.widgets_outlined, key: const Key('mobile_menu_block_save')),
            row(
              t('blk.insert'),
              () => insertBlockAction(context, c, c.project.blocks, pickTool: ToolId.insertBlock),
              icon: Icons.input,
              key: const Key('mobile_menu_block_insert'),
            ),
            row(t('edit.array'), c.selection.isEmpty ? null : () => showArrayDialog(context, c)),
            for (final id in [ToolId.rotate, ToolId.mirror, ToolId.scale, ToolId.offset, ToolId.trim, ToolId.extend, ToolId.cutPipe]) row(toolLabel(t, id), () => c.setTool(id)),
          ]),
          section(t('gps.submenu'), Icons.my_location, [
            check(t('gps.menu'), c.gpsActive, (v) => v ? c.startGps() : c.stopGps()),
            if (c.gpsTrack == null) row(t('gps.walkStart'), c.startGpsTrack, icon: Icons.directions_walk),
            if (c.gpsTrack != null) ...[
              row(t('gps.walkArea'), () => c.finishGpsTrack(asArea: true), icon: Icons.crop_square),
              row(t('gps.walkOutline'), () => c.finishGpsTrack(), icon: Icons.pentagon_outlined),
              row(t('gps.walkLine'), () => c.finishGpsTrack(closed: false), icon: Icons.timeline),
            ],
            if (c.gpsPoint != null) row(t('gps.mark'), () => c.markGpsPoint(), icon: Icons.add_location_alt_outlined),
          ]),
          section(t('menu.view'), Icons.visibility_outlined, [
            row(t('view.zoomAll'), c.zoomAll, icon: Icons.fit_screen),
            check(t('view.grid'), c.showGrid, (v) {
              c.showGrid = v;
              c.refresh();
            }),
            check(t('view.labels'), c.showLabels, (v) {
              c.showLabels = v;
              c.refresh();
            }),
            check(t('view.wetted'), c.showWettedRadii, (v) {
              c.showWettedRadii = v;
              c.refresh();
            }),
            check(t('status.snap'), c.snap.enabled, (v) {
              c.snap.enabled = v;
              c.refresh();
            }),
            check(t('status.ortho'), c.snap.ortho, (v) {
              c.snap.ortho = v;
              c.refresh();
            }),
            check(t('status.keepLinks'), c.toolSettings.keepConnections, (v) {
              c.toolSettings.keepConnections = v;
              c.refresh();
            }),
            for (final m in OverlayMode.values)
              check(t('view.overlay.${m.name}'), c.overlay == m, (_) {
                c.overlay = m;
                c.refresh();
              }),
            for (final m in BaseMap.values) check('${t('view.baseMap')}: ${t('view.baseMap.${m.name}')}', c.baseMap == m, (_) => selectBaseMap(context, c, m)),
            row(t('view.baseMap.googleKey'), () => showGoogleMapsKeyDialog(context, c), icon: Icons.key_outlined),
            row(t('view.baseMap.customUrl'), () => showCustomTilesDialog(context, c), icon: Icons.link),
            for (final l in supportedLanguages) check(languageNames[l] ?? l, c.lang == l, (_) => c.setLanguage(l)),
            for (final m in CadThemeMode.values)
              check('${t('view.theme')}: ${t('view.theme.${m.name}')}', uiThemeMode.value == m, (_) {
                setThemeMode(m);
                c.refresh();
              }),
            row(t('tools.units'), () => showUnitsDialog(context, c), icon: Icons.straighten),
            row(t('lbl.menu'), () => showLabelRulesDialog(context, c), icon: Icons.label_important_outline),
          ]),
          section(t('menu.design'), Icons.play_circle_outline, [
            row(t('design.params'), () => showDesignParamsDialog(context, c), icon: Icons.tune),
            row(t('design.catalog'), () => showCatalogEditorDialog(context, c), icon: Icons.inventory_2_outlined),
            row(t('design.management'), () => showManagementDialog(context, c), icon: Icons.schedule),
            row(t('design.proposal'), () => showProposalDialog(context, c), icon: Icons.request_quote_outlined),
            row(t('design.scenarios'), () => showScenariosDialog(context, c), icon: Icons.compare_outlined),
            row(t('terrain.onlineDem'), () => showOnlineDemDialog(context, c), icon: Icons.cloud_download_outlined),
            row(t('terrain.generateContours'), () => showGenerateContoursDialog(context, c), icon: Icons.gesture),
            row(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.view_in_ar_outlined),
            row(t('terrain.clearProfile'), c.profilePath == null ? null : c.clearProfile, icon: Icons.close),
            row(t('design.check'), widget.onDesignCheck, icon: Icons.fact_check_outlined, key: const Key('mobile_menu_check')),
            row(t('adv.fixAll'), c.busy ? null : () => showAutoFixDialog(context, c), icon: Icons.auto_fix_high, key: const Key('mobile_menu_autofix')),
            row('${t('adv.optimize')}…', c.busy ? null : () => showOptimizeDialog(context, c), icon: Icons.savings_outlined, key: const Key('mobile_menu_optimize')),
            row(t('ai.menu'), () => showAiAssistantDialog(context, c), icon: Icons.smart_toy_outlined, key: const Key('mobile_menu_ai')),
            row(t('design.zone'), c.busy ? null : () => c.runDesign(sizeZones: true, sizeMain: false), icon: Icons.account_tree_outlined),
            row(t('design.mainline'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: true), icon: Icons.timeline),
            row(t('design.all'), c.busy ? null : () => c.runDesign(), icon: Icons.play_arrow),
            row(t('design.analyze'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: false), icon: Icons.analytics_outlined),
            check(t('design.autoAnalyze'), c.autoAnalyze, (v) => c.autoAnalyze = v),
            row(t('design.pumpSelect'), c.results == null ? null : () => showPumpSelectionDialog(context, c), icon: Icons.settings_suggest_outlined),
            row(t('tr.menu'), () => showTransientDialog(context, c), icon: Icons.waves, key: const Key('mobile_menu_transients')),
            row(t('av.menu'), () => showAirValveDialog(context, c), icon: Icons.air, key: const Key('mobile_menu_air_valves')),
            row(t('eps.menu'), () => showEpsDialog(context, c), icon: Icons.schedule_outlined, key: const Key('mobile_menu_eps')),
            row(t('tar.menu'), () => showTariffDialog(context, c), icon: Icons.price_change_outlined, key: const Key('mobile_menu_tariff')),
            row(t('eg.menu'), () => showEnergyGroupingDialog(context, c), icon: Icons.bolt, key: const Key('mobile_menu_energy_groups')),
            row(t('od.menu'), () => showOnDemandDialog(context, c), icon: Icons.groups_outlined, key: const Key('mobile_menu_on_demand')),
            row(t('crit.menu'), () => showCriticalityDialog(context, c), icon: Icons.call_split, key: const Key('mobile_menu_criticality')),
            row(t('cal.menu'), () => showCalibrationDialog(context, c), icon: Icons.tune, key: const Key('mobile_menu_calibration')),
            row(t('fert.menu'), () => showFertigationDialog(context, c), icon: Icons.science_outlined, key: const Key('mobile_menu_fertigation')),
            row(t('wr.menu'), () => showWireRoutingDialog(context, c), icon: Icons.alt_route, key: const Key('mobile_menu_wire_routes')),
            row(t('clim.menu'), () => showSiteClimateDialog(context, c), icon: Icons.wb_sunny_outlined),
            row(t('zone.feedEnvelope'), c.selection.isEmpty ? null : () => feedEnvelopeAction(c), icon: Icons.straighten),
            row(t('dens.menu'), () => showDensogramDialog(context, c), icon: Icons.blur_on, key: const Key('mobile_menu_densogram')),
            row(t('zone.deviceOnLaterals'), c.selection.isEmpty ? null : () => showDeviceOnLateralsDialog(context, c), icon: Icons.settings_input_component_outlined),
            row(t('zone.toPipe'), c.selection.isEmpty ? null : () => convertToPipeAction(c), icon: Icons.linear_scale),
            row(t('autolay.menu'), () => showAutoLayoutDialog(context, c), icon: Icons.auto_awesome_mosaic_outlined, key: const Key('mobile_menu_auto_layout')),
            row(t('tpl.menu'), () => showTemplateDialog(context, c), icon: Icons.sports_soccer_outlined, key: const Key('mobile_menu_templates')),
            row(t('subdiv.menu'), () => showFieldSubdivisionDialog(context, c), icon: Icons.grid_view_outlined, key: const Key('mobile_menu_subdivide')),
            row(t('rings.menu'), () => showTreeRingsDialog(context, c), icon: Icons.park_outlined, key: const Key('mobile_menu_tree_rings')),
            row(t('pfit.menu'), () => showPivotFitDialog(context, c), icon: Icons.track_changes, key: const Key('mobile_menu_pivot_fit')),
            row(t('veg.menu'), () => showVegetationDialog(context, c), icon: Icons.image_search, key: const Key('mobile_menu_vegetation')),
            row(t('design.clear'), c.results == null ? null : c.clearResults, icon: Icons.clear_all),
          ], key: const Key('mobile_menu_design')),
          section(t('menu.reports'), Icons.table_chart_outlined, [
            for (var i = 0; i < reportTabKeys.length; i++)
              row(t(reportTabKeys[i]), () {
                c.reportTab = i;
                _openReports();
              }),
          ]),
          section(t('menu.tools'), Icons.calculate_outlined, [
            row(t('tools.lateral'), () => showLateralCalculator(context, c), icon: Icons.calculate_outlined),
            row(t('tools.pump'), () => showPumpCalculator(context, c), icon: Icons.settings_input_component),
            row(t('tools.hammer'), () => showHammerCalculator(context, c), icon: Icons.bolt),
            row(t('solar.menu'), () => showSolarPumpingDialog(context, c), icon: Icons.solar_power_outlined),
            row(t('bulb.menu'), () => showWettedBulbDialog(context, c), icon: Icons.water_drop_outlined),
            row(t('wb.menu'), () => showWaterBudgetDialog(context, c), icon: Icons.local_florist_outlined),
            row(t('trav.menu'), () => showTravellerCalculator(context, c), icon: Icons.agriculture_outlined),
            row(t('surf.menu'), () => showSurfaceIrrigationCalculator(context, c), icon: Icons.water_outlined),
            row(t('gate.menu'), () => showGatedPipeCalculator(context, c), icon: Icons.view_week_outlined),
          ]),
          section(t('menu.help'), Icons.help_outline, [
            row(t('help.tutorial'), widget.onStartTutorial, icon: Icons.school_outlined),
            row(t('help.welcome'), widget.onShowWelcome, icon: Icons.waving_hand_outlined),
            row(t('help.shortcuts'), () => showShortcutsDialog(context, c), icon: Icons.keyboard_outlined),
            row(t('help.about'), () => showAboutDialogApp(context, c), icon: Icons.info_outline),
          ]),
        ],
      ),
      height: 0.85,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final drawing = c.activeTool != ToolId.select && c.activeTool != ToolId.pan;
    final group = ToolPalette.groups.firstWhere((g) => g.$1 == _group, orElse: () => ToolPalette.groups.first);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // top bar
            Container(
              height: 44,
              color: Cad.panel,
              child: Row(
                children: [
                  IconButton(key: const Key('mobile_menu'), tooltip: t('mob.menu'), icon: const Icon(Icons.menu), onPressed: _openMenu),
                  Image.asset('assets/brand/logo-mark.png', height: 22, filterQuality: FilterQuality.medium),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.project.meta.name.isEmpty ? t('app.title') : c.project.meta.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  AiPanelButton(key: const Key('mobile_ai'), c: c, size: 22, onPressed: () => showAiAssistantDialog(context, c)),
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
                ],
              ),
            ),
            // canvas with floating actions
            Expanded(
              child: KeyedSubtree(
                key: TutorialTargets.canvas,
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.canvas),
                    // hint
                    Positioned(
                      left: 8,
                      top: 8,
                      right: 130,
                      child: IgnorePointer(
                        child: Container(
                          key: TutorialTargets.statusBar,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Cad.overlay, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            c.command.isNotEmpty ? '${t('status.command')}: ${c.command}' : widget.hint,
                            style: TextStyle(fontSize: 11, color: Cad.fg70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    // floating actions (bottom-right, above the zoom buttons)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (drawing) _fab(const Key('mobile_done'), Icons.check, t('mob.done'), () => _toolKey('Enter'), color: Cad.okFill),
                          if (drawing) _fab(const Key('mobile_cancel'), Icons.close, t('mob.cancel'), () => _toolKey('Escape')),
                          if (c.selection.isNotEmpty) _fab(const Key('mobile_delete'), Icons.delete_outline, t('edit.delete'), c.deleteSelected),
                          _fab(const Key('mobile_undo'), Icons.undo, t('edit.undo'), c.canUndo ? c.undo : null),
                          _fab(const Key('mobile_history'), Icons.history, t('hist.title'), () => _openProperties(tab: 2)),
                          _fab(const Key('mobile_props'), Icons.tune, t('mob.props'), _openProperties, badge: c.selection.isNotEmpty ? '${c.selection.length}' : null),
                          _fab(const Key('mobile_reports'), Icons.table_chart_outlined, t('menu.reports'), _openReports, badge: c.results != null ? '✓' : null),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // tool bar: group tabs + tools of the group
            Container(
              key: TutorialTargets.palette,
              color: Cad.panel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final g in ToolPalette.groups)
                          InkWell(
                            key: Key('mobile_group_${g.$1}'),
                            onTap: () => setState(() => _group = g.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: _group == g.$1 ? Cad.accent : Colors.transparent, width: 2)),
                              ),
                              child: Text(t('mob.group.${g.$1}'), style: TextStyle(fontSize: 12, color: _group == g.$1 ? Cad.fg : Cad.fg60)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: [
                        for (final (id, icon) in group.$2)
                          InkWell(
                            key: Key('mtool_${id.name}'),
                            onTap: () {
                              if (group.$1 == 'main' && (id == ToolId.pump || id == ToolId.misc || id == ToolId.junction)) c.toolSettings.pointScope = HydraulicScope.mainline;
                              if (group.$1 == 'zone' && (id == ToolId.outlet || id == ToolId.valve)) c.toolSettings.pointScope = HydraulicScope.zone;
                              c.setTool(id);
                            },
                            child: Container(
                              width: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                              decoration: BoxDecoration(color: c.activeTool == id ? Cad.accentFill : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 20, color: c.activeTool == id ? Colors.white : Cad.fg70),
                                  Text(
                                    _shortLabel(t, id),
                                    style: TextStyle(fontSize: 9, color: c.activeTool == id ? Colors.white : Cad.fg60),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortLabel(I18n t, ToolId id) {
    final s = t('tool.${id.name}');
    final cut = s.indexOf(RegExp(r'[ /(]'));
    return cut > 3 ? s.substring(0, cut) : s;
  }

  Widget _fab(Key key, IconData icon, String tooltip, VoidCallback? onTap, {Color? color, String? badge}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? Cad.overlayFaint : (color ?? Cad.overlayStrong),
        shape: CircleBorder(side: BorderSide(color: Cad.fg24)),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // white on a coloured button (Done), the text colour on the others
                Icon(icon, size: 20, color: onTap == null ? Cad.fg30 : (color != null ? Colors.white : Cad.fg)),
                if (badge != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: Cad.accent, borderRadius: BorderRadius.circular(8)),
                      child: Text(badge, style: const TextStyle(fontSize: 9, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
