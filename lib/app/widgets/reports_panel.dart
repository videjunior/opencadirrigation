import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
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
];

/// Tabs that do not need design results.
const _noResultTabs = {5, 7, 8, 11, 12};

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key, required this.c});
  final ProjectController c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final r = c.results;
    return ColoredBox(
      color: CadColors.background,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1B1F24),
            height: 30,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
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
                              border: Border(bottom: BorderSide(color: c.reportTab == i ? const Color(0xFF42A5F5) : Colors.transparent, width: 2)),
                            ),
                            child: Text(t(reportTabKeys[i]), style: TextStyle(fontSize: 11.5, color: c.reportTab == i ? Colors.white : Colors.white60)),
                          ),
                        ),
                    ]),
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
                ? Center(child: Text(t('msg.noResults'), style: const TextStyle(color: Colors.white54)))
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
        return _fromTable('mainline');
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
      default:
        return _fromTable('pivotSpans');
    }
  }

  Widget _table(List<String> headers, List<List<Object>> rows, {List<Color?>? rowColors, Key? key}) => ReportTableView(key: key, headers: headers, rows: rows, rowColors: rowColors);

  String _entityName(String id) {
    final n = c.project.byId(id)?.name ?? '';
    return n.isEmpty ? id : n;
  }

  String _warn(String w) => c.t.warning(w, entityName: _entityName);

  /// Renders one of the shared report tables (same data as every exporter).
  Widget _fromTable(String key, {String? emptyKey}) {
    final tb = c.reportTables().where((x) => x.key == key).firstOrNull;
    if (tb == null || tb.isEmpty) {
      return Center(child: Text(c.t(emptyKey ?? 'msg.noResults'), style: const TextStyle(color: Colors.white54)));
    }
    // keyed per table so switching tabs starts from a fresh scroll position
    return _table(tb.headers, tb.rows, rowColors: [for (final w in tb.warn) w ? CadColors.warning : null], key: ValueKey('report_table_$key'));
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('prof.hint'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(t('prof.howTo'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(key: const Key('profile_tool'), onPressed: () => c.setTool(ToolId.profile), icon: const Icon(Icons.show_chart, size: 16), label: Text(t('tool.profile'))),
        ]),
      );
    }
    final samples = c.profileAlong(path);
    if (samples.length < 2) return Center(child: Text(t('dem.noData'), style: const TextStyle(color: Colors.white54)));
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
      child: Column(children: [
        if (noTerrain) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t('prof.noTerrain'), style: const TextStyle(fontSize: 11, color: CadColors.warning))),
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
        Row(children: [
          Expanded(child: Text(info, style: const TextStyle(fontSize: 11, color: Colors.white60))),
          if (c.profilePath != null)
            TextButton.icon(key: const Key('profile_clear'), onPressed: c.clearProfile, icon: const Icon(Icons.close, size: 14), label: Text(t('prof.clear'), style: const TextStyle(fontSize: 11))),
          TextButton.icon(onPressed: () => c.setTool(ToolId.profile), icon: const Icon(Icons.show_chart, size: 14), label: Text('PR', style: const TextStyle(fontSize: 11))),
        ]),
      ]),
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
      return Center(child: Text(c.t('msg.selectForHgl'), style: const TextStyle(color: Colors.white54)));
    }
    final ordered = List<PipeSegmentResult>.from(segs)..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    return Padding(
      padding: const EdgeInsets.all(8),
      child: HglChart(segments: ordered, units: c.units, allowedMin: lo, allowedMax: hi, title: title, legend: c.t('hgl.legend')),
    );
  }

  Widget _messages(DesignResults? r) {
    final t = c.t;
    final msgs = <(String, Color, String?)>[];
    String? idOf(String w) {
      final i = w.indexOf(':');
      if (i < 0) return null;
      final id = w.substring(i + 1).split(':').last;
      return c.project.byId(id) != null ? id : null;
    }

    if (r != null) {
      for (final m in r.messages) {
        msgs.add((_warn(m), CadColors.warning, idOf(m)));
      }
      for (final z in r.zones.values) {
        for (final w in z.warnings) {
          msgs.add(('${z.zoneName}: ${_warn(w)}', z.withinWindow ? Colors.white70 : CadColors.warning, idOf(w) ?? z.valveId));
        }
      }
      for (final f in r.systemFlows) {
        for (final w in f.warnings) {
          msgs.add(('${f.name}: ${_warn(w)}', CadColors.warning, idOf(w)));
        }
      }
    }
    for (final id in c.unconnected) {
      final e = c.project.byId(id);
      msgs.add(('${t('msg.unconnectedItem')}: ${e != null ? t('tool.${toolNameOfEntity(e)}') : ''} ${_entityName(id)}', CadColors.unconnected, id));
    }
    if (msgs.isEmpty) {
      return Center(child: Text(t('msg.noMessages'), style: const TextStyle(color: Colors.white54)));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final (m, col, id) in msgs)
          InkWell(
            onTap: id == null
                ? null
                : () {
                    c.select([id]);
                    c.zoomToEntity(id);
                  },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(m, style: TextStyle(fontSize: 11.5, color: col))),
          ),
      ],
    );
  }
}

/// Tool key matching an entity type (used for labels).
String toolNameOfEntity(Entity e) => switch (e) {
  LineEntity _ => 'line',
  PolylineEntity _ => 'polyline',
  CircleEntity _ => 'circle',
  ArcEntity _ => 'arc',
  SplineEntity _ => 'spline',
  HatchEntity _ => 'hatch',
  SymbolEntity _ => 'symbol',
  TextEntity _ => 'text',
  DimensionEntity _ => 'dimension',
  AngularDimensionEntity _ => 'dimAngular',
  RadialDimensionEntity _ => 'dimRadial',
  LeaderEntity _ => 'leader',
  ImageEntity _ => 'image',
  ContourEntity _ => 'contour',
  SpotHeightEntity _ => 'spot',
  PipeEntity p => p.scope == HydraulicScope.zone ? 'zonePipe' : 'mainPipe',
  SpraylineEntity _ => 'sprayline',
  TapeEntity _ => 'tape',
  OutletEntity _ => 'outlet',
  ControlValveEntity _ => 'valve',
  WaterSupplyEntity _ => 'supply',
  PumpEntity _ => 'pump',
  MiscHydraulicEntity _ => 'misc',
  JunctionEntity _ => 'junction',
  PivotEntity _ => 'pivot',
  AreaEntity _ => 'area',
  _ => 'select',
};

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
  static const headingStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70);
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

  static String _text(Object v) => v is double ? fmt(v) : '$v';

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
        (math.max(measure(widget.headers[i], _headStyle!), measure(longest[i], _cellStyle!)) + 2 * ReportTableView.cellPadding + ReportTableView.slack)
            .clamp(ReportTableView.minColumnWidth, ReportTableView.maxColumnWidth),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
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
                        final bg = warn != null ? warn.withValues(alpha: 0.15) : (r.isOdd ? const Color(0x0AFFFFFF) : null);
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
