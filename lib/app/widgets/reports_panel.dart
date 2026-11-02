import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/advisor.dart';
import '../../core/design/report_tables.dart' show RNum;
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/units.dart';
import '../i18n.dart';
import '../io/file_io.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'advice_panel.dart';
import 'fields.dart' show localizeUi;
import 'hgl_chart.dart';
import 'profile_chart.dart';
import 'dialogs/help_dialog.dart' show HelpButton; // 1.6.0 UI

const reportTabKeys = [
  'reports.zone',
  'reports.pipes',
  'reports.outlets',
  'reports.mainline',
  'reports.bom',
  'reports.water',
  'reports.hgl',
  'reports.messages',
  'reports.profile',
  'reports.flushing',
  'reports.surge',
  'reports.crop',
  'reports.schedule',
  'reports.pivots',
  'reports.pivotSpans',
  'reports.electrical',
  'reports.proposal',
  'reports.trench',
  'reports.bomZones',
  'reports.comments',
  'reports.revisions',
  'reports.scenarios',
  'reports.requirement',
  'reports.pivotPackage',
  'reports.machines',
  'reports.vih',
  // 1.6.0 AGB
  'reports.agb',
  // 1.6.0 AGR
  'reports.agronomy',
];

/// Report tab indices used in code.
abstract final class ControllerTabs {
  static const messages = ProjectController.messagesReportTab;
}

/// Tabs that do not need design results.
const _noResultTabs = {5, 7, 8, 11, 12, 17, 19, 20, 21, 22};

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key, required this.c, this.onClose, this.onLocated});
  final ProjectController c;

  /// What × does (the phone closes its sheet); null hides the panel.
  final VoidCallback? onClose;

  /// After a row framed its item (the phone closes its sheet over the drawing).
  final VoidCallback? onLocated;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final r = c.results;
    // (the tab bar grows with the text size the user chose)
    final tabHeight = math.max(30.0, MediaQuery.textScalerOf(context).scale(11.5) + 16);
    return ColoredBox(
      color: Cad.background,
      child: Column(
        children: [
          Container(
            color: Cad.panel,
            height: tabHeight,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < reportTabKeys.length; i++)
                          InkWell(
                            key: Key('report_tab_$i'),
                            onTap: () {
                              c.reportTab = i;
                              c.refresh();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              height: tabHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: c.reportTab == i ? Cad.accent : Colors.transparent, width: 2)),
                              ),
                              child: Text(
                                i == ControllerTabs.messages ? _messagesLabel() : t(reportTabKeys[i]),
                                style: TextStyle(fontSize: 11.5, color: c.reportTab == i ? Cad.fg : (i == ControllerTabs.messages && _errorCount() > 0 ? Cad.unconnected : Cad.fg60)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                HelpButton(c: c, topic: 'reports', panel: true), // 1.6.0 UI
                IconButton(
                  key: const Key('reports_close'),
                  tooltip: t('ui.reportsClose'),
                  icon: const Icon(Icons.close, size: 16),
                  onPressed:
                      onClose ??
                      () {
                        c.showReports = false;
                        c.refresh();
                      },
                ),
              ],
            ),
          ),
          Expanded(
            child: r == null && !_noResultTabs.contains(c.reportTab)
                ? Center(
                    child: Text(t('msg.noResults'), style: TextStyle(color: Cad.fg54)),
                  )
                : _tab(context, r),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, DesignResults? r) {
    switch (c.reportTab) {
      case 0:
        return _fromTable('zones');
      case 1:
        return _fromTable('pipes');
      case 2:
        return _fromTable('outlets');
      case 3:
        return _mainlineAndDevices();
      case 4:
        return _fromTable('bom');
      case 5:
        // 1.6.0 PRD: the slope by irrigated area under the water of each area
        return _stack(const [('water', 2), ('slopeClasses', 1)], emptyKey: 'msg.noAreas');
      case 6:
        return _hgl(r!);
      case 7:
        return _messages(r);
      case 8:
        return _profile();
      case 9:
        return _fromTable('flushing');
      case 10:
        return _fromTable('surge');
      case 11:
        return _fromTable('crop', emptyKey: 'msg.noAreas');
      case 12:
        return _fromTable('schedule', emptyKey: 'msg.noAreas');
      case 13:
        return _fromTable('pivots');
      case 14:
        return _fromTable('pivotSpans');
      case 15:
        return _fromTable('electrical', emptyKey: 'msg.noElectrical');
      case 16:
        return _fromTable('proposal');
      case 17:
        return _stack(const [('trench', 1), ('works', 1)], emptyKey: 'msg.noTrench');
      case 18:
        return _fromTable('bomZones');
      case 19:
        return _fromTable('comments', emptyKey: 'msg.noComments');
      case 20:
        return _fromTable('revisions', emptyKey: 'msg.noRevisions');
      case 21:
        return _fromTable('scenarios', emptyKey: 'msg.noScenarios');
      case 22:
        // 1.6.0 SIT: with the sources of the data (the climate of the requirement among them) and their credits
        return _stack(const [('requirement', 3), ('requirementTotals', 1), ('licensing', 1), ('sources', 1)], emptyKey: 'msg.noRequirement');
      case 23:
        return _stack(const [('pivotPackageSummary', 1), ('pivotPackage', 3), ('pivotTimer', 1)], emptyKey: 'msg.noPivotPackage');
      case 25:
        return _fromTable('vih', emptyKey: 'msg.noVih');
      // 1.6.0 AGB: pump house, pivots' supply, solar, water, two-wire, lanes and furrows
      case 26:
        return _stack(const [
          ('pumpHouse', 2),
          ('pumpHouseSupply', 1),
          ('pivotSupply', 1),
          ('solar', 1),
          ('solarMonths', 1),
          ('waterQuality', 1),
          ('waterTreatment', 1),
          ('twoWire', 1),
          ('travellers', 1),
          ('furrows', 1),
        ], emptyKey: 'agb.rep.empty');
      // 1.6.0 AGR: water balance, capacity, runoff, programme, fertigation, field tests
      case 27:
        return _stack(const [
          ('waterBalance', 2),
          ('capacity', 1),
          ('machineRunoff', 2),
          ('zoneRunoff', 1),
          ('programmeStations', 2),
          ('programmeRuns', 2),
          ('fertigationStages', 2),
          ('fieldTests', 1),
        ], emptyKey: 'msg.noAgronomy');
      default:
        return _stack(const [('cornerArm', 1), ('vri', 1), ('pivotElectrical', 1)], emptyKey: 'msg.noMachineExtras');
    }
  }

  /// The shared tables of [keys] that have rows, one above the other with
  /// the given flex.
  Widget _stack(List<(String, int)> keys, {String? emptyKey}) {
    final tables = c.reportTables();
    final present = [
      for (final (k, f) in keys)
        if (tables.where((x) => x.key == k).firstOrNull case final tb? when !tb.isEmpty) (tb, f),
    ];
    if (present.isEmpty) {
      return Center(
        child: Text(c.t(emptyKey ?? 'msg.noResults'), style: TextStyle(color: Cad.fg54)),
      );
    }
    if (present.length == 1) return _fromTable(present.single.$1.key);
    return StackedReportTables([for (final (tb, f) in present) (rows: tb.rows.length, flex: f, caption: null, child: _fromTable(tb.key))]);
  }

  int _errorCount() => c.advice.where((a) => a.level == AdviceLevel.error).length;

  /// "Messages (3)": the number of problems, so they are hard to miss.
  String _messagesLabel() {
    final n = c.advice.where((a) => a.level != AdviceLevel.info).length;
    return n == 0 ? c.t('reports.messages') : '${c.t('reports.messages')} ($n)';
  }

  /// Selects and frames the item of a report row.
  void _locate(String id) {
    if (c.project.byId(id) == null) return;
    c.select([id]);
    c.zoomToEntity(id);
    onLocated?.call();
  }

  String _entityName(String id) {
    final n = c.project.byId(id)?.name ?? '';
    return n.isEmpty ? id : n;
  }

  /// Renders one of the shared report tables (same data as every exporter).
  Widget _fromTable(String key, {String? emptyKey}) {
    final tb = c.reportTables().where((x) => x.key == key).firstOrNull;
    if (tb == null || tb.isEmpty) {
      return Center(
        child: Text(c.t(emptyKey ?? 'msg.noResults'), style: TextStyle(color: Cad.fg54)),
      );
    }
    // keyed per table so switching tabs starts from a fresh scroll position
    return ReportTableView(
      key: ValueKey('report_table_$key'),
      headers: tb.headers,
      rows: tb.rows,
      rowColors: [for (final w in tb.warn) w ? Cad.warning : null],
      rowIds: tb.ids,
      onLocate: _locate,
      title: tb.title,
      tools: true,
    );
  }

  /// Mainline duties on top, the pumps and devices of the mainline below
  /// (separate tables: their columns are inlet / outlet pressures).
  Widget _mainlineAndDevices() {
    final tables = c.reportTables();
    // 1.6.0 MOT: below the devices, the pump stations and the real operation of the zones
    final below = [
      for (final k in const ['devices', 'stations', 'operation'])
        if (tables.where((x) => x.key == k).firstOrNull case final tb? when !tb.isEmpty) tb,
    ];
    if (below.isEmpty) return _fromTable('mainline');
    final main = tables.where((x) => x.key == 'mainline').firstOrNull;
    return StackedReportTables([
      if (main != null && !main.isEmpty) (rows: main.rows.length, flex: main.rows.length + 1, caption: null, child: _fromTable('mainline')),
      for (final tb in below) (rows: tb.rows.length, flex: tb.rows.length + 1, caption: tb.title, child: _fromTable(tb.key)),
    ]);
  }

  Widget _profile() {
    final t = c.t;
    var path = c.profilePath;
    var title = t('reports.profile');
    String? entityId;
    if (path == null && c.selection.length == 1) {
      final e = c.project.byId(c.selection.first);
      final pts = e?.linearPoints;
      if (pts != null && pts.length >= 2) {
        path = pts;
        entityId = e!.id;
        title = _entityName(e.id);
      }
    }
    if (path == null || path.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('prof.hint'), style: TextStyle(color: Cad.fg70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(t('prof.howTo'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(key: const Key('profile_tool'), onPressed: () => c.setTool(ToolId.profile), icon: const Icon(Icons.show_chart, size: 16), label: Text(t('tool.profile'))),
          ],
        ),
      );
    }
    final samples = c.profileAlong(path);
    if (samples.length < 2) {
      return Center(
        child: Text(t('dem.noData'), style: TextStyle(color: Cad.fg54)),
      );
    }
    // pipe and hydraulic grade line of a designed pipe / lateral
    List<(double, double)>? pipe, hgl;
    final segs = entityId == null ? null : c.results?.pipesByEntity[entityId];
    if (segs != null && segs.isNotEmpty) {
      final ordered = List<PipeSegmentResult>.from(segs)..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
      pipe = [(0.0, ordered.first.elevationA)];
      hgl = [(0.0, ordered.first.elevationA + ordered.first.pressureStart)];
      var d = 0.0;
      for (final sg in ordered) {
        d += sg.length;
        pipe.add((d, sg.elevationB));
        hgl.add((d, sg.elevationB + sg.pressureEnd));
      }
    }
    final rise = samples.last.$2 - samples.first.$2;
    final len = samples.last.$1;
    final u = c.units;
    final info = t('prof.slope', {'s': fmt(len > 0 ? rise / len * 100 : 0, 2), 'd': fmt(rise, 2), 'l': '${fmt(u.lengthFromSi(len), 1)} ${u.lengthLabel}'});
    final noTerrain = c.terrainIsEmpty;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (noTerrain)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(t('prof.noTerrain'), style: TextStyle(fontSize: 11, color: Cad.warning)),
            ),
          Expanded(
            child: ProfileChart(
              samples: samples,
              units: u,
              title: title,
              yLabel: t('prof.elevation'),
              pipe: pipe,
              hgl: hgl,
              legendGround: t('prof.ground'),
              legendPipe: t('prof.pipe'),
              legendHgl: t('prof.hgl'),
              legendLow: t('prof.lowest'),
              legendHigh: t('prof.highest'),
              stationLabel: t('prof.station'),
              pressureLabel: t('prof.pressure'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(info, style: TextStyle(fontSize: 11, color: Cad.fg60)),
              ),
              if (c.profilePath != null)
                TextButton.icon(
                  key: const Key('profile_clear'),
                  onPressed: c.clearProfile,
                  icon: const Icon(Icons.close, size: 14),
                  label: Text(t('prof.clear'), style: const TextStyle(fontSize: 11)),
                ),
              TextButton.icon(
                onPressed: () => c.setTool(ToolId.profile),
                icon: const Icon(Icons.show_chart, size: 14),
                label: Text('PR', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hgl(DesignResults r) {
    String? id = c.selection.length == 1 ? c.selection.first : null;
    List<PipeSegmentResult>? segs;
    double? lo, hi;
    String title = '';
    final byEntity = r.pipesByEntity;
    if (id != null) {
      final e = c.project.byId(id);
      if (e is ControlValveEntity) {
        final z = r.zones[id];
        if (z != null && z.minOutlet != null) {
          id = z.minOutlet!.entityId;
          lo = z.allowedMin;
          hi = z.allowedMax;
          title = z.zoneName;
        }
      }
      segs = byEntity[id];
      if (segs != null) {
        for (final z in r.zones.values) {
          if (z.pipes.any((p) => p.entityId == id)) {
            lo ??= z.allowedMin;
            hi ??= z.allowedMax;
            title = title.isEmpty ? '${z.zoneName} — ${_entityName(id)}' : title;
          }
        }
      }
    }
    if (segs == null) {
      for (final z in r.zones.values) {
        final first = z.pipes.where((p) => c.project.byId(p.entityId) is SpraylineEntity || c.project.byId(p.entityId) is TapeEntity).toList();
        if (first.isNotEmpty) {
          segs = byEntity[first.first.entityId];
          lo = z.allowedMin;
          hi = z.allowedMax;
          title = '${z.zoneName} — ${_entityName(first.first.entityId)}';
          break;
        }
      }
    }
    if (segs == null || segs.isEmpty) {
      return Center(
        child: Text(c.t('msg.selectForHgl'), style: TextStyle(color: Cad.fg54)),
      );
    }
    final ordered = List<PipeSegmentResult>.from(segs)..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    return Padding(
      padding: const EdgeInsets.all(8),
      child: HglChart(
        segments: ordered,
        units: c.units,
        allowedMin: lo,
        allowedMax: hi,
        title: title,
        legend: c.t('hgl.legend'),
        // elevations and heads, in the length unit (not the pressure unit)
        axisLabel: c.t('hgl.axis', {'u': c.units.lengthLabel}),
        readout: (d, z, h, p) => c.t('hgl.readout', {'d': d, 'z': z, 'h': h, 'p': p}),
      ),
    );
  }

  /// Every problem with its explanation and corrections (design assistant).
  Widget _messages(DesignResults? r) => AdvicePanel(c: c);
}

/// Tool key matching an entity type (used for labels).
String toolNameOfEntity(Entity e) => ProjectController.toolKeyOf(e);

/// Virtualised report table: only the visible rows are built (the pipes
/// table of a real project has thousands of rows, which made a [DataTable]
/// rebuild the whole panel on every repaint), the header stays put while the
/// rows scroll, and both axes have visible scrollbars. Cells are formatted
/// and column widths measured once per table.
///
/// With [tools], a header tap sorts by that column (again: the other way), a
/// filter keeps the rows that contain a text (or only the highlighted ones),
/// and the visible rows are copied to the clipboard or saved as CSV; a row
/// with an entity in [rowIds] selects and frames it through [onLocate].
/// One table of a [StackedReportTables]: its row count, its share of the
/// room left, an optional caption above it and the table itself.
typedef StackedTable = ({int rows, int flex, String? caption, Widget child});

/// The heights of tables stacked in [available] pixels: each gets its
/// minimum ([mins]) and the room left is shared by [flex]. When the
/// minimums do not fit, each keeps its minimum and the stack scrolls.
List<double> stackedTableHeights(double available, List<double> mins, List<int> flex) {
  final need = mins.fold(0.0, (a, b) => a + b);
  final weight = flex.fold(0, (a, b) => a + math.max(1, b));
  final extra = math.max(0.0, available - need);
  return [for (var i = 0; i < mins.length; i++) mins[i] + extra * math.max(1, flex[i]) / weight];
}

/// Report tables one above the other (a tab may hold ten since 1.6.0):
/// each keeps room for its tools, its header and up to three rows, the room
/// left is shared by flex, and when a low panel cannot hold them all the
/// tables scroll as one list instead of overflowing.
class StackedReportTables extends StatelessWidget {
  const StackedReportTables(this.tables, {super.key});
  final List<StackedTable> tables;

  /// Rows a table keeps in view at the least.
  static const minRows = 3;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final captionHeight = scaler.scale(11.5) * 1.5 + 8;
    return LayoutBuilder(
      builder: (context, box) {
        const divider = 1.0;
        final mins = [for (final tb in tables) ReportTableView.minHeight(scaler, math.min(tb.rows, minRows)) + (tb.caption != null ? captionHeight : 0)];
        final dividers = [for (var i = 0; i < tables.length; i++) i > 0 && tables[i].caption == null ? divider : 0.0];
        final available = box.maxHeight.isFinite ? box.maxHeight - dividers.fold(0.0, (a, b) => a + b) : 0.0;
        final heights = stackedTableHeights(available, mins, [for (final tb in tables) tb.flex]);
        return SingleChildScrollView(
          key: const Key('report_stack'),
          primary: false,
          child: Column(
            children: [
              for (var i = 0; i < tables.length; i++) ...[
                if (dividers[i] > 0) Container(height: divider, color: Cad.fg12),
                SizedBox(
                  height: heights[i],
                  child: Column(
                    children: [
                      if (tables[i].caption case final caption?)
                        Container(
                          width: double.infinity,
                          height: captionHeight,
                          color: Cad.panel,
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: Cad.fg70, fontWeight: FontWeight.w600),
                          ),
                        ),
                      Expanded(child: tables[i].child),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ReportTableView extends StatefulWidget {
  const ReportTableView({super.key, required this.headers, required this.rows, this.rowColors, this.rowIds, this.onLocate, this.title = '', this.tools = false});

  final List<String> headers;

  /// Cells are [String], [RNum], [int] or [double].
  final List<List<Object>> rows;

  /// Highlight colour per row (null: none).
  final List<Color?>? rowColors;

  /// The entity each row is about (null: none), for [onLocate].
  final List<String?>? rowIds;

  /// Selects and frames the entity of a tapped row.
  final void Function(String id)? onLocate;

  /// Name of the table: the file name of its CSV.
  final String title;

  /// Sort, filter, copy and export above the table.
  final bool tools;

  static const rowHeight = 26.0;
  static const headerHeight = 30.0;
  static const cellPadding = 8.0;

  /// Height of the tool bar at the most (a finger's 48 px buttons, or a
  /// filter field grown with the text size).
  static double toolbarHeight(TextScaler s) => math.max(48.0, s.scale(12) * 1.5 + 22);

  /// The least height of a table with its tools that shows [rows] rows.
  static double minHeight(TextScaler s, int rows) => toolbarHeight(s) + math.max(headerHeight, s.scale(11) + 19) + rows * math.max(rowHeight, s.scale(11) + 15);

  /// Extra width so rounding never turns the widest cell into an ellipsis.
  static const slack = 4.0;
  static const minColumnWidth = 40.0;
  static const maxColumnWidth = 420.0;
  static TextStyle get headingStyle => TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Cad.fg70);
  static const cellStyle = TextStyle(fontSize: 11, fontFamily: 'monospace');

  @override
  State<ReportTableView> createState() => _ReportTableViewState();
}

class _ReportTableViewState extends State<ReportTableView> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  late List<List<String>> _cells;
  late List<double> _widths;

  /// The rows shown, in the order shown (indices of [ReportTableView.rows]).
  late List<int> _order;
  int? _sortColumn;
  bool _ascending = true;
  String _filter = '';
  bool _highlightedOnly = false;

  // effective styles (the ambient DefaultTextStyle adds letter spacing and
  // fallbacks, so measuring the bare styles undersizes the columns)
  TextStyle? _headStyle;
  TextStyle? _cellStyle;
  TextScaler _scaler = TextScaler.noScaling;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final base = DefaultTextStyle.of(context).style;
    final head = base.merge(ReportTableView.headingStyle);
    final cell = base.merge(ReportTableView.cellStyle);
    final scaler = MediaQuery.textScalerOf(context);
    if (head != _headStyle || cell != _cellStyle || scaler != _scaler) {
      _headStyle = head;
      _cellStyle = cell;
      _scaler = scaler;
      _layout();
    }
  }

  @override
  void didUpdateWidget(ReportTableView old) {
    super.didUpdateWidget(old);
    if (!identical(old.rows, widget.rows) || !identical(old.headers, widget.headers)) _layout();
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  /// (the numbers in the notation of the interface language)
  static String _text(Object v) => localizeUi(reportCellText(v));

  /// Height of a row: grows with the text size the user chose.
  double get _rowHeight => math.max(ReportTableView.rowHeight, _scaler.scale(11) + 15);

  /// Formats every cell once and sizes each column to its widest text (the
  /// longest string is the widest one in a monospace font).
  void _layout() {
    final n = widget.headers.length;
    _cells = [
      for (final r in widget.rows) [for (var i = 0; i < n; i++) i < r.length ? _text(r[i]) : ''],
    ];
    final longest = List<String>.filled(n, '');
    for (final r in _cells) {
      for (var i = 0; i < n; i++) {
        if (r[i].length > longest[i].length) longest[i] = r[i];
      }
    }
    final painter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, textScaler: _scaler);
    double measure(String s, TextStyle style) {
      painter.text = TextSpan(text: s, style: style);
      painter.layout();
      return painter.width;
    }

    // (room for the sort arrow of the tools)
    final arrow = widget.tools ? measure(' ▲', _headStyle!) : 0.0;
    _widths = [
      for (var i = 0; i < n; i++)
        (math.max(measure(widget.headers[i], _headStyle!) + arrow, measure(longest[i], _cellStyle!)) + 2 * ReportTableView.cellPadding + ReportTableView.slack).clamp(
          ReportTableView.minColumnWidth,
          ReportTableView.maxColumnWidth,
        ),
    ];
    painter.dispose();
    _arrange();
  }

  /// The order of the rows after the filter and the sort.
  void _arrange() {
    final colors = widget.rowColors;
    final f = _filter.trim().toLowerCase();
    final order = [
      for (var r = 0; r < _cells.length; r++)
        if ((!_highlightedOnly || (colors != null && r < colors.length && colors[r] != null)) && (f.isEmpty || _cells[r].any((s) => s.toLowerCase().contains(f)))) r,
    ];
    final k = _sortColumn;
    if (k != null) {
      // numbers by value (before texts), texts alphabetically; ties keep their order
      Object key(int r) {
        final row = widget.rows[r];
        final v = k < row.length ? row[k] : '';
        return switch (v) {
          RNum n => n.value,
          int i => i.toDouble(),
          double d => d,
          _ => _cells[r][k].toLowerCase(),
        };
      }

      int compare(int a, int b) {
        final x = key(a), y = key(b);
        final c = switch ((x, y)) {
          (double p, double q) => p.isNaN ? (q.isNaN ? 0 : 1) : (q.isNaN ? -1 : p.compareTo(q)),
          (double _, _) => -1,
          (_, double _) => 1,
          _ => (x as String).compareTo(y as String),
        };
        return c != 0 ? (_ascending ? c : -c) : a.compareTo(b);
      }

      order.sort(compare);
    }
    _order = order;
  }

  void _sortBy(int column) => setState(() {
    if (_sortColumn == column) {
      if (_ascending) {
        _ascending = false;
      } else {
        // a third tap: back to the order of the report
        _sortColumn = null;
        _ascending = true;
      }
    } else {
      _sortColumn = column;
      _ascending = true;
    }
    _arrange();
  });

  /// The visible rows as tab-separated text (pastes into a spreadsheet).
  String _tsv() => [widget.headers.join('\t'), for (final r in _order) _cells[r].join('\t')].join('\n');

  /// The visible rows as CSV with the decimal point, as the other exports.
  String _csv() {
    String q(String s) => s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    return [
      widget.headers.map(q).join(','),
      for (final r in _order) [for (var i = 0; i < widget.headers.length; i++) q(i < widget.rows[r].length ? reportCellText(widget.rows[r][i]) : '')].join(','),
    ].join('\r\n');
  }

  Widget _cell(int i, String s, TextStyle style) => SizedBox(
    width: _widths[i],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: ReportTableView.cellPadding),
      child: Text(s, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _toolbar(I18n t) {
    final colors = widget.rowColors;
    final highlighted = colors != null && colors.any((c) => c != null);
    return Container(
      color: Cad.panel,
      padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('report_filter'),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(isDense: true, hintText: t('rt.filter'), prefixIcon: const Icon(Icons.filter_list, size: 16), prefixIconConstraints: const BoxConstraints(minWidth: 28)),
              onChanged: (v) => setState(() {
                _filter = v;
                _arrange();
              }),
            ),
          ),
          if (highlighted)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: FilterChip(
                key: const Key('report_highlighted'),
                label: Text(t('rt.highlighted'), style: const TextStyle(fontSize: 11)),
                selected: _highlightedOnly,
                onSelected: (v) => setState(() {
                  _highlightedOnly = v;
                  _arrange();
                }),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: Text(
              t('rt.count', {'n': '${_order.length}', 'm': '${_cells.length}'}),
              key: const Key('report_count'),
              style: TextStyle(fontSize: 11, color: Cad.fg60),
            ),
          ),
          IconButton(
            key: const Key('report_copy'),
            tooltip: t('rt.copy'),
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _tsv()));
              if (mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t('rt.copied', {'n': '${_order.length}'})), duration: const Duration(seconds: 2)));
              }
            },
          ),
          IconButton(
            key: const Key('report_csv'),
            tooltip: t('rt.csv'),
            icon: const Icon(Icons.download_outlined, size: 18),
            onPressed: () => saveTextFile('${_fileName(widget.title.isEmpty ? 'table' : widget.title)}.csv', _csv(), mime: 'text/csv'),
          ),
        ],
      ),
    );
  }

  static String _fileName(String s) => s.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');

  @override
  Widget build(BuildContext context) {
    final t = I18n(uiLanguage.value);
    final total = _widths.fold(0.0, (a, b) => a + b);
    final rowHeight = _rowHeight;
    final header = Container(
      height: math.max(ReportTableView.headerHeight, _scaler.scale(11) + 19),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Cad.fg24)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _widths.length; i++)
            if (widget.tools)
              Semantics(
                button: true,
                label: t('rt.sortBy', {'c': widget.headers[i]}),
                excludeSemantics: true,
                child: InkWell(
                  key: Key('report_sort_$i'),
                  onTap: () => _sortBy(i),
                  child: _cell(i, '${widget.headers[i]}${_sortColumn == i ? (_ascending ? ' ▲' : ' ▼') : ''}', ReportTableView.headingStyle),
                ),
              )
            else
              _cell(i, widget.headers[i], ReportTableView.headingStyle),
        ],
      ),
    );
    final colors = widget.rowColors;
    final ids = widget.rowIds;
    final locate = widget.onLocate;
    final table = Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      // the rows' notifications pass through the horizontal scroll view first
      notificationPredicate: (n) => n.depth == 1,
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: ScrollConfiguration(
          // desktop platforms add their own scrollbar to every scroll view: ours are explicit
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: ListView.builder(
                      key: const Key('report_table_list'),
                      controller: _vertical,
                      itemExtent: rowHeight,
                      itemCount: _order.length,
                      itemBuilder: (context, i) {
                        final r = _order[i];
                        final warn = colors != null && r < colors.length ? colors[r] : null;
                        final bg = warn != null ? warn.withValues(alpha: 0.15) : (i.isOdd ? Cad.stripe : null);
                        final id = ids != null && r < ids.length ? ids[r] : null;
                        final row = Container(
                          key: ValueKey('report_row_$r'),
                          color: bg,
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(children: [for (var k = 0; k < _widths.length; k++) _cell(k, _cells[r][k], ReportTableView.cellStyle)]),
                        );
                        if (id == null || locate == null) return row;
                        return Tooltip(
                          message: t('rt.locate'),
                          waitDuration: const Duration(milliseconds: 800),
                          child: InkWell(key: ValueKey('report_locate_$r'), onTap: () => locate(id), child: row),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.tools) return table;
    return Column(
      children: [
        _toolbar(t),
        Expanded(child: table),
      ],
    );
  }
}

/// Text of a report cell: counts as they are, other numbers with two
/// decimals. The int test comes first: on the web every number is a
/// JavaScript double, so `1 is double` holds there and a count would read
/// "1.00".
String reportCellText(Object v) => v is int ? '$v' : (v is double ? fmt(v) : '$v');
