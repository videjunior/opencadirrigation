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
import '../tutorial/tutorial.dart';
import 'dialogs/welcome_dialog.dart';
import 'dialogs/basemap_dialogs.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/export_dialogs.dart';
import 'dialogs/more_dialogs.dart';
import 'dialogs/shortcuts_dialog.dart';
import 'dialogs/terrain_dialogs.dart';
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
    backgroundColor: const Color(0xFF1B1F24),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SizedBox(key: key, height: MediaQuery.sizeOf(ctx).height * height, child: child),
  );

  void _openProperties({int tab = 0}) {
    var index = tab;
    _sheet(
      key: const Key('mobile_props_sheet'),
      StatefulBuilder(builder: (ctx, setState) {
        final t = c.t;
        return Column(children: [
          const SizedBox(height: 6),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Expanded(child: _tab(t('props.title'), index == 0, () => setState(() => index = 0))),
            Expanded(child: _tab(t('view.layers'), index == 1, () => setState(() => index = 1))),
            Expanded(child: _tab(t('hist.title'), index == 2, () => setState(() => index = 2))),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
          ]),
          Expanded(child: ListenableBuilder(listenable: c, builder: (_, _) => switch (index) { 1 => LayersPanel(c: c), 2 => HistoryPanel(c: c), _ => PropertiesPanel(c: c) })),
        ]);
      }),
      height: 0.7,
    );
  }

  void _openReports() {
    c.showReports = true;
    _sheet(key: const Key('mobile_reports_sheet'), ListenableBuilder(listenable: c, builder: (_, _) => ReportsPanel(c: c)), height: 0.85).then((_) {
      c.showReports = false;
      c.refresh();
    });
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? const Color(0xFF42A5F5) : Colors.transparent, width: 2))),
      child: Text(label, style: TextStyle(fontSize: 12.5, color: on ? Colors.white : Colors.white60)),
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
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
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
            for (final f in ReportFormat.values) row('${t('file.exportReport')}: ${t(f == ReportFormat.pdf ? 'exp.reportPdf' : 'exp.${f.name}')}', c.results == null ? null : () => exportReportAction(context, c, f), icon: Icons.table_view),
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
            row(t('edit.array'), c.selection.isEmpty ? null : () => showArrayDialog(context, c)),
            for (final id in [ToolId.rotate, ToolId.mirror, ToolId.scale, ToolId.offset, ToolId.trim, ToolId.extend, ToolId.cutPipe]) row(toolLabel(t, id), () => c.setTool(id)),
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
            for (final m in BaseMap.values)
              check('${t('view.baseMap')}: ${t('view.baseMap.${m.name}')}', c.baseMap == m, (_) => selectBaseMap(context, c, m)),
            row(t('view.baseMap.googleKey'), () => showGoogleMapsKeyDialog(context, c), icon: Icons.key_outlined),
            row(t('view.baseMap.customUrl'), () => showCustomTilesDialog(context, c), icon: Icons.link),
            for (final l in supportedLanguages) check(languageNames[l] ?? l, c.lang == l, (_) => c.setLanguage(l)),
            row(t('tools.units'), () => showUnitsDialog(context, c), icon: Icons.straighten),
          ]),
          section(t('menu.design'), Icons.play_circle_outline, [
            row(t('design.params'), () => showDesignParamsDialog(context, c), icon: Icons.tune),
            row(t('design.catalog'), () => showCatalogEditorDialog(context, c), icon: Icons.inventory_2_outlined),
            row(t('design.management'), () => showManagementDialog(context, c), icon: Icons.schedule),
            row(t('terrain.onlineDem'), () => showOnlineDemDialog(context, c), icon: Icons.cloud_download_outlined),
            row(t('terrain.generateContours'), () => showGenerateContoursDialog(context, c), icon: Icons.gesture),
            row(t('design.dem3d'), () => showDemDialog(context, c), icon: Icons.view_in_ar_outlined),
            row(t('terrain.clearProfile'), c.profilePath == null ? null : c.clearProfile, icon: Icons.close),
            row(t('design.check'), widget.onDesignCheck, icon: Icons.fact_check_outlined, key: const Key('mobile_menu_check')),
            row(t('design.zone'), c.busy ? null : () => c.runDesign(sizeZones: true, sizeMain: false), icon: Icons.account_tree_outlined),
            row(t('design.mainline'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: true), icon: Icons.timeline),
            row(t('design.all'), c.busy ? null : () => c.runDesign(), icon: Icons.play_arrow),
            row(t('design.analyze'), c.busy ? null : () => c.runDesign(sizeZones: false, sizeMain: false), icon: Icons.analytics_outlined),
            row(t('design.pumpSelect'), c.results == null ? null : () => showPumpSelectionDialog(context, c), icon: Icons.settings_suggest_outlined),
            row(t('zone.feedEnvelope'), c.selection.isEmpty ? null : () => feedEnvelopeAction(c), icon: Icons.straighten),
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
              color: const Color(0xFF1B1F24),
              child: Row(children: [
                IconButton(key: const Key('mobile_menu'), tooltip: t('mob.menu'), icon: const Icon(Icons.menu), onPressed: _openMenu),
                Image.asset('assets/brand/logo-mark.png', height: 22, filterQuality: FilterQuality.medium),
                const SizedBox(width: 6),
                Expanded(child: Text(c.project.meta.name.isEmpty ? t('app.title') : c.project.meta.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                if (c.busy) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                IconButton(key: TutorialTargets.runButton, tooltip: t('design.all'), icon: const Icon(Icons.play_arrow, color: Color(0xFF66BB6A)), onPressed: c.busy ? null : () => c.runDesign()),
                IconButton(key: TutorialTargets.saveButton, tooltip: t('file.save'), icon: Icon(Icons.save_outlined, color: c.dirty ? Colors.amber : null), onPressed: () => saveProjectAction(context, c)),
              ]),
            ),
            // canvas with floating actions
            Expanded(
              child: KeyedSubtree(
                key: TutorialTargets.canvas,
                child: Stack(children: [
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
                        decoration: BoxDecoration(color: const Color(0xAA1B1F24), borderRadius: BorderRadius.circular(6)),
                        child: Text(c.command.isNotEmpty ? '${t('status.command')}: ${c.command}' : widget.hint, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  // floating actions (bottom-right, above the zoom buttons)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (drawing) _fab(const Key('mobile_done'), Icons.check, t('mob.done'), () => _toolKey('Enter'), color: const Color(0xFF2E7D32)),
                      if (drawing) _fab(const Key('mobile_cancel'), Icons.close, t('mob.cancel'), () => _toolKey('Escape')),
                      if (c.selection.isNotEmpty) _fab(const Key('mobile_delete'), Icons.delete_outline, t('edit.delete'), c.deleteSelected),
                      _fab(const Key('mobile_undo'), Icons.undo, t('edit.undo'), c.canUndo ? c.undo : null),
                      _fab(const Key('mobile_history'), Icons.history, t('hist.title'), () => _openProperties(tab: 2)),
                      _fab(const Key('mobile_props'), Icons.tune, t('mob.props'), _openProperties, badge: c.selection.isNotEmpty ? '${c.selection.length}' : null),
                      _fab(const Key('mobile_reports'), Icons.table_chart_outlined, t('menu.reports'), _openReports, badge: c.results != null ? '✓' : null),
                    ]),
                  ),
                ]),
              ),
            ),
            // tool bar: group tabs + tools of the group
            Container(
              key: TutorialTargets.palette,
              color: const Color(0xFF1B1F24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _group == g.$1 ? const Color(0xFF42A5F5) : Colors.transparent, width: 2))),
                            child: Text(t('mob.group.${g.$1}'), style: TextStyle(fontSize: 12, color: _group == g.$1 ? Colors.white : Colors.white60)),
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
                            decoration: BoxDecoration(color: c.activeTool == id ? const Color(0xFF2E7DD1) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(icon, size: 20, color: c.activeTool == id ? Colors.white : Colors.white70),
                              Text(_shortLabel(t, id), style: TextStyle(fontSize: 9, color: c.activeTool == id ? Colors.white : Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
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
        color: onTap == null ? const Color(0x661B1F24) : (color ?? const Color(0xDD1B1F24)),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: 20, color: onTap == null ? Colors.white30 : Colors.white),
              if (badge != null) Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: const Color(0xFF42A5F5), borderRadius: BorderRadius.circular(8)), child: Text(badge, style: const TextStyle(fontSize: 9, color: Colors.white)))),
            ]),
          ),
        ),
      ),
    ),
  );
}
