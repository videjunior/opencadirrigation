import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/advisor.dart';
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'advice_panel.dart';
import 'fields.dart' show localizeUi;
import 'hgl_chart.dart';
import 'profile_chart.dart';

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
];

/// Report tab indices used in code.
abstract final class ControllerTabs {
  static const messages = ProjectController.messagesReportTab;
}

/// Tabs that do not need design results.
const _noResultTabs = {5, 7, 8, 11, 12, 17, 19, 20, 21, 22};

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key, required this.c});
  final ProjectController c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final r = c.results;
    return ColoredBox(
      color: Cad.background,
      child: Column(
        children: [
          Container(
            color: Cad.panel,
            height: 30,
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
                              height: 30,
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
                IconButton(
                  key: const Key('reports_close'),
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
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
        return _fromTable('water', emptyKey: 'msg.noAreas');
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
        return _stack(const [('requirement', 3), ('requirementTotals', 1), ('licensing', 1)], emptyKey: 'msg.noRequirement');
      case 23:
        return _stack(const [('pivotPackageSummary', 1), ('pivotPackage', 3), ('pivotTimer', 1)], emptyKey: 'msg.noPivotPackage');
      case 25:
        return _fromTable('vih', emptyKey: 'msg.noVih');
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
        if (tables.where((x) => x.key == k).firstOrNull case final tb? when !tb.isEmpty) (k, f),
    ];
    if (present.isEmpty) {
      return Center(
        child: Text(c.t(emptyKey ?? 'msg.noResults'), style: TextStyle(color: Cad.fg54)),
      );
    }
    if (present.length == 1) return _fromTable(present.single.$1);
    return Column(
      children: [
        for (var i = 0; i < present.length; i++) ...[if (i > 0) Container(height: 1, color: Cad.fg12), Expanded(flex: present[i].$2, child: _fromTable(present[i].$1))],
      ],
    );
  }

  int _errorCount() => c.advice.where((a) => a.level == AdviceLevel.error).length;

  /// "Messages (3)": the number of problems, so they are hard to miss.
  String _messagesLabel() {
    final n = c.advice.where((a) => a.level != AdviceLevel.info).length;
    return n == 0 ? c.t('reports.messages') : '${c.t('reports.messages')} ($n)';
  }

  Widget _table(List<String> headers, List<List<Object>> rows, {List<Color?>? rowColors, Key? key}) => ReportTableView(key: key, headers: headers, rows: rows, rowColors: rowColors);

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
    return _table(tb.headers, tb.rows, rowColors: [for (final w in tb.warn) w ? Cad.warning : null], key: ValueKey('report_table_$key'));
  }

  /// Mainline duties on top, the pumps and devices of the mainline below
  /// (separate tables: their columns are inlet / outlet pressures).
  Widget _mainlineAndDevices() {
    final tables = c.reportTables();
    final dev = tables.where((x) => x.key == 'devices').firstOrNull;
    if (dev == null || dev.isEmpty) return _fromTable('mainline');
    final main = tables.where((x) => x.key == 'mainline').firstOrNull;
    return Column(
      children: [
        if (main != null && !main.isEmpty) Expanded(flex: main.rows.length + 1, child: _fromTable('mainline')),
        Container(
          width: double.infinity,
          color: Cad.panel,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            dev.title,
            style: TextStyle(fontSize: 11.5, color: Cad.fg70, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(flex: dev.rows.length + 1, child: _fromTable('devices')),
      ],
    );
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
      child: HglChart(segments: ordered, units: c.units, allowedMin: lo, allowedMax: hi, title: title, legend: c.t('hgl.legend')),
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
class ReportTableView extends StatefulWidget {
  const ReportTableView({super.key, required this.headers, required this.rows, this.rowColors});

  final List<String> headers;

  /// Cells are [String], [RNum], [int] or [double].
  final List<List<Object>> rows;

  /// Highlight colour per row (null: none).
  final List<Color?>? rowColors;

  static const rowHeight = 26.0;
  static const headerHeight = 30.0;
  static const cellPadding = 8.0;

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

    _widths = [
      for (var i = 0; i < n; i++)
        (math.max(measure(widget.headers[i], _headStyle!), measure(longest[i], _cellStyle!)) + 2 * ReportTableView.cellPadding + ReportTableView.slack).clamp(
          ReportTableView.minColumnWidth,
          ReportTableView.maxColumnWidth,
        ),
    ];
    painter.dispose();
  }

  Widget _cell(int i, String s, TextStyle style) => SizedBox(
    width: _widths[i],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: ReportTableView.cellPadding),
      child: Text(s, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total = _widths.fold(0.0, (a, b) => a + b);
    final header = Container(
      height: ReportTableView.headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Cad.fg24)),
      ),
      child: Row(children: [for (var i = 0; i < _widths.length; i++) _cell(i, widget.headers[i], ReportTableView.headingStyle)]),
    );
    final colors = widget.rowColors;
    return Scrollbar(
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
                      itemExtent: ReportTableView.rowHeight,
                      itemCount: _cells.length,
                      itemBuilder: (context, r) {
                        final warn = colors != null && r < colors.length ? colors[r] : null;
                        final bg = warn != null ? warn.withValues(alpha: 0.15) : (r.isOdd ? Cad.stripe : null);
                        return Container(
                          key: ValueKey('report_row_$r'),
                          color: bg,
                          alignment: Alignment.centerLeft,
                          child: Row(children: [for (var i = 0; i < _widths.length; i++) _cell(i, _cells[r][i], ReportTableView.cellStyle)]),
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
  }
}

/// Text of a report cell: counts as they are, other numbers with two
/// decimals. The int test comes first: on the web every number is a
/// JavaScript double, so `1 is double` holds there and a count would read
/// "1.00".
String reportCellText(Object v) => v is int ? '$v' : (v is double ? fmt(v) : '$v');
