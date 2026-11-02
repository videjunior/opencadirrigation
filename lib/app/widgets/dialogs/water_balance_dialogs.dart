/// Agronomy dialogs added in 1.6.0: the daily soil water balance of an area
/// with its chart, the potential runoff of the machines and sprinkler
/// areas, and the irrigation programme (window, cycle and soak, seasonal
/// adjustment, the programme by controller station and month).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/agr_tables.dart';
import '../../../core/design/fertigation_stages.dart' show fertStageNames;
import '../../../core/design/irrigation_programme.dart';
import '../../../core/design/report_tables.dart';
import '../../../core/design/runoff_potential.dart';
import '../../../core/design/soil_water_balance.dart';
import '../../../core/design/system_capacity.dart';
import '../../../core/model/agronomy_plan.dart';
import '../../../core/model/entities.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import '../reports_panel.dart' show ReportTableView;
import 'terrain_dialogs.dart' show dialogWidth;

Widget _row(List<Widget> children) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

/// Fields two by two, one under the other on a narrow screen.
Widget _pairs(BuildContext ctx, List<Widget> fields) {
  final narrow = MediaQuery.sizeOf(ctx).width < 520;
  if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  return Column(
    children: [
      for (var i = 0; i < fields.length; i += 2) _row([fields[i], if (i + 1 < fields.length) fields[i + 1] else const SizedBox.shrink()]),
    ],
  );
}

Widget _hint(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
);

Widget _table(ReportTable tb, {double height = 200, void Function(String id)? onLocate}) => SizedBox(
  height: height,
  child: ReportTableView(headers: tb.headers, rows: tb.rows, rowIds: tb.ids, rowColors: [for (final w in tb.warn) w ? Cad.tintWarning : null], onLocate: onLocate, title: tb.key, tools: true),
);

Future<void> _message(BuildContext context, ProjectController c, String title, String text) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    content: SizedBox(width: dialogWidth(ctx, 420), child: Text(text, style: const TextStyle(fontSize: 12.5))),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
  ),
);

void _locate(ProjectController c, String id) {
  if (c.project.byId(id) == null) return;
  c.select([id]);
  c.zoomToEntity(id);
}

// ---------------------------------------------------------------- water balance

/// The daily soil water balance of one irrigated area (FAO-56 chapter 8):
/// when to irrigate (at the readily available water, with a regulated
/// deficit by growth stage, every few days, or never), the weather (the
/// typical year of the normals or a year of the daily series), the totals,
/// the relative yield (Ky of FAO-33), the chart of the depletion against
/// the RAW and the TAW and the irrigations. Save keeps the settings for the
/// area (the report shows them).
Future<void> showWaterBalanceDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && a.useWaterBalance) a,
  ];
  if (areas.isEmpty) return _message(context, c, t('swb.title'), t('swb.noAreas'));
  final selected = c.selection.map(p.byId).whereType<AreaEntity>().where(areas.contains).firstOrNull;
  var area = selected ?? areas.first;
  var s = balanceSettingsOf(p, area).copy();
  var gen = 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final r = areaWaterBalance(p, area, settings: s);
        final years = balanceYears(p);
        final u = p.params.units;
        String mm(double v) => '${fmtUi(u.depthFromMm(v), 0)} ${u.depthLabel}';
        Widget num(String key, String label, double value, ValueChanged<double> on, {int decimals = 2}) =>
            NumField(key: ValueKey('swb_${key}_$gen'), label: label, value: value, decimals: decimals, onChanged: (v) => setState(() => on(v)));
        final y = r?.relativeYield;
        final body = <Widget>[
          _hint(t('swb.hint')),
          SpecDropdown<AreaEntity>(
            key: const Key('swb_area'),
            label: t('rep.area'),
            value: area.id,
            items: areas,
            labelOf: (a) => a.name.isEmpty ? a.id : a.name,
            idOf: (a) => a.id,
            onChanged: (v) => setState(() {
              area = areas.firstWhere((a) => a.id == v);
              s = balanceSettingsOf(p, area).copy();
              gen++;
            }),
          ),
          _pairs(ctx, [
            SpecDropdown<BalanceTrigger>(
              key: const Key('swb_trigger'),
              label: t('swb.trigger'),
              value: s.trigger.name,
              items: BalanceTrigger.values,
              labelOf: (x) => t('swb.trigger.${x.name}'),
              idOf: (x) => x.name,
              onChanged: (v) => setState(() => s.trigger = BalanceTrigger.values.byName(v!)),
            ),
            SpecDropdown<int>(
              key: const Key('swb_year'),
              label: t('swb.weather'),
              value: '${years.contains(s.year) ? s.year : 0}',
              items: [0, ...years],
              labelOf: (y) => y == 0 ? t('swb.typicalYear') : '$y',
              idOf: (y) => '$y',
              onChanged: (v) => setState(() => s.year = int.tryParse(v ?? '') ?? 0),
            ),
            if (s.trigger == BalanceTrigger.interval) num('every', t('swb.intervalDays'), s.intervalDays.toDouble(), (v) => s.intervalDays = v.round().clamp(1, 60), decimals: 0),
            if (s.trigger != BalanceTrigger.rainfed) num('refill', t('swb.refillPct'), s.refillPct, (v) => s.refillPct = v.clamp(10, 100).toDouble(), decimals: 0),
            num('dr0', t('swb.initialPct'), s.initialDepletionPct, (v) => s.initialDepletionPct = v.clamp(0, 100).toDouble(), decimals: 0),
            if (s.year == 0) num('rain', t('swb.rainEvents'), s.rainEventsPerMonth.toDouble(), (v) => s.rainEventsPerMonth = v.round().clamp(1, 31), decimals: 0),
            num('ky', t('swb.ky'), s.ky, (v) => s.ky = v.clamp(0, 3).toDouble()),
          ]),
          if (s.trigger == BalanceTrigger.depletion) ...[
            const SizedBox(height: 4),
            Text(t('swb.deficitHint'), style: TextStyle(fontSize: 11, color: Cad.fg60)),
            _pairs(ctx, [
              for (var k = 0; k < 4; k++) num('mad$k', t('fst.stage.${fertStageNames[k]}'), s.allowedDepletion[k], (v) => s.allowedDepletion[k] = v.clamp(0, 0.95).toDouble()),
            ]),
          ],
          const SizedBox(height: 8),
          if (r == null || r.days.isEmpty)
            Text(t('swb.none'), style: TextStyle(color: Cad.caution, fontSize: 12))
          else ...[
            KV(t('swb.period'), '${r.days.first.date.toIso8601String().substring(0, 10)} … ${r.days.last.date.toIso8601String().substring(0, 10)} (${r.days.length} d)'),
            KV('ETc / ETc,adj', '${mm(r.etcMm)} / ${mm(r.etaMm)} (${fmtUi(100 * r.relativeEt, 1)} %)'),
            KV('${t('req.rain')} / ${t('req.effRain')}', '${mm(r.rainMm)} / ${mm(r.effectiveRainMm)}'),
            KV('${t('req.net')} / ${t('req.gross')}', '${mm(r.netMm)} / ${mm(r.grossMm)} (${fmtUi(u.volumeFromM3(r.grossMm / 1000 * area.area), 0)} ${u.volumeLabel})'),
            KV(t('swb.events'), '${r.events.length}'),
            KV(t('swb.percolation'), mm(r.deepPercolationMm)),
            KV(t('swb.stressDays'), '${r.stressDays}', color: r.stressDays > 0 ? Cad.caution : null),
            if (y != null) KV(t('swb.yield'), '${fmtUi(100 * y, 1)} % (Ky ${fmtUi(r.ky!, 2)})', color: y < 0.999 ? Cad.caution : null),
            for (final w in r.warnings) Text(c.t.warning(w), style: TextStyle(fontSize: 11, color: Cad.caution)),
            const SizedBox(height: 6),
            SizedBox(
              height: 190,
              child: CustomPaint(
                key: const Key('swb_chart'),
                painter: BalanceChartPainter(r, line: Cad.accent, raw: Cad.caution, taw: Cad.error, rain: Cad.info, irrigation: Cad.ok, grid: Cad.chartGrid, text: Cad.fg60, labels: (t('swb.depletion'), 'RAW', 'TAW')),
                child: const SizedBox.expand(),
              ),
            ),
            Wrap(
              spacing: 10,
              children: [
                _legend(Cad.accent, t('swb.depletion')),
                _legend(Cad.caution, 'RAW'),
                _legend(Cad.error, 'TAW'),
                _legend(Cad.info, t('req.rain')),
                _legend(Cad.ok, t('swb.irrigation')),
              ],
            ),
            const SizedBox(height: 6),
            _table(
              ReportTable(
                key: 'water_balance_${area.name.isEmpty ? area.id : area.name}',
                title: t('swb.events'),
                headers: [t('sch.date'), '${t('swb.depletion')} (${u.depthLabel})', '${t('req.net')} (${u.depthLabel})', '${t('req.gross')} (${u.depthLabel})'],
                rows: [
                  for (final e in r.events) [e.date.toIso8601String().substring(0, 10), RNum(u.depthFromMm(e.depletionMm), 1), RNum(u.depthFromMm(e.netMm), 1), RNum(u.depthFromMm(e.grossMm), 1)],
                ],
              ),
              height: 170,
            ),
          ],
        ];
        return AlertDialog(
          title: Text(t('swb.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 640),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(key: const Key('swb_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
            FilledButton(
              key: const Key('swb_save'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final keep = s.copy();
                final id = area.id;
                c.mutate(() => p.agronomy.balance[id] = keep, invalidateResults: false, label: 'hist.waterBalance');
                c.notify(t('swb.saved'));
              },
              child: Text(t('swb.save')),
            ),
          ],
        );
      },
    ),
  );
}

Widget _legend(Color color, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 10, height: 10, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ],
);

/// The depletion of the root zone day by day (0 at the top: field
/// capacity), the RAW and TAW lines, the rain and the irrigations as bars.
class BalanceChartPainter extends CustomPainter {
  BalanceChartPainter(this.r, {required this.line, required this.raw, required this.taw, required this.rain, required this.irrigation, required this.grid, required this.text, required this.labels});
  final BalanceResult r;
  final Color line, raw, taw, rain, irrigation, grid, text;
  final (String, String, String) labels;

  @override
  void paint(Canvas canvas, Size size) {
    final days = r.days;
    if (days.length < 2 || size.width < 40 || size.height < 40) return;
    const left = 34.0, bottom = 16.0, top = 6.0;
    final w = size.width - left - 4, h = size.height - top - bottom;
    final maxTaw = days.fold(0.0, (m, d) => math.max(m, d.tawMm));
    final maxBar = days.fold(0.0, (m, d) => math.max(m, math.max(d.rainMm, d.netIrrigationMm)));
    final scale = math.max(maxTaw, 1.0);
    double x(int i) => left + w * i / (days.length - 1);
    double yDepth(double mm) => top + h * (mm / scale).clamp(0.0, 1.0);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final yy = top + h * k / 4;
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: fmtUi(scale * k / 4, 0), style: TextStyle(fontSize: 9, color: text)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 3, yy - tp.height / 2));
    }
    // bars: rain and irrigation from the top, a quarter of the height at most
    if (maxBar > 0) {
      final bw = math.max(1.0, w / days.length);
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        if (d.rainMm > 0) canvas.drawRect(Rect.fromLTWH(x(i) - bw / 2, top, bw, h * 0.25 * d.rainMm / maxBar), Paint()..color = rain.withValues(alpha: 0.55));
        if (d.netIrrigationMm > 0) canvas.drawRect(Rect.fromLTWH(x(i) - bw / 2, top, bw, h * 0.25 * d.netIrrigationMm / maxBar), Paint()..color = irrigation.withValues(alpha: 0.8));
      }
    }
    Path path(double Function(BalanceDay d) f) {
      final pa = Path()..moveTo(x(0), yDepth(f(days.first)));
      for (var i = 1; i < days.length; i++) {
        pa.lineTo(x(i), yDepth(f(days[i])));
      }
      return pa;
    }

    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawPath(path((d) => d.tawMm), stroke(taw, 1.2));
    canvas.drawPath(path((d) => d.rawMm), stroke(raw, 1.2));
    canvas.drawPath(path((d) => d.depletionMm), stroke(line, 1.6));
    // months along the bottom
    var lastMonth = -1;
    for (var i = 0; i < days.length; i++) {
      final m = days[i].date.month;
      if (m == lastMonth) continue;
      lastMonth = m;
      final tp = TextPainter(
        text: TextSpan(text: '$m', style: TextStyle(fontSize: 9, color: text)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i), top + h + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BalanceChartPainter old) => !identical(old.r, r) || old.line != line;
}

// ---------------------------------------------------------------- runoff

/// The potential runoff of the sprinkler irrigation: every machine station
/// by station against the intake of the soil under it (family and surface
/// storage editable: the values of a field test), and the sprinkler areas
/// against the basic intake of their soil.
Future<void> showRunoffPotentialDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final machines = p.entities.whereType<PivotEntity>().toList();
  final family = <String, double>{};
  final storage = <String, double>{};
  var initial = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final u = p.params.units;
        final labels = c.exporter().labels;
        final body = <Widget>[_hint(t('ro.hint'))];
        if (machines.isNotEmpty) {
          body.add(
            SwitchListTile(
              key: const Key('ro_initial'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t('ro.initial'), style: const TextStyle(fontSize: 12)),
              value: initial,
              onChanged: (v) => setState(() => initial = v),
            ),
          );
        }
        for (final m in machines) {
          final auto = runoffSoilAt(p, m.center);
          final f = family[m.id] ?? auto?.family, st = storage[m.id] ?? auto?.surfaceStorageMm;
          final soil = f == null || st == null ? null : RunoffSoil(family: f, surfaceStorageMm: st, areaId: auto?.areaId);
          final r = soil == null ? null : machineRunoff(p, m, soil: soil, results: c.results, laterIrrigations: !initial);
          body.addAll([
            SectionTitle(m.name.isEmpty ? m.id : m.name),
            _pairs(ctx, [
              NumField(key: ValueKey('ro_family_${m.id}'), label: t('ro.familyIn'), value: f ?? 0, onChanged: (v) => setState(() => family[m.id] = v.clamp(0.05, 4).toDouble())),
              NumField(key: ValueKey('ro_storage_${m.id}'), label: '${t('ro.storage')} (mm)', value: st ?? 0, decimals: 1, onChanged: (v) => setState(() => storage[m.id] = v.clamp(0, 50).toDouble())),
            ]),
            if (auto == null && soil == null) Text(t('ro.noSoil'), style: TextStyle(fontSize: 11.5, color: Cad.caution)),
            if (r != null) ...[
              KV(t('ro.worst'), '${fmtUi(r.worst.runoffMm, 1)} mm (${fmtUi(r.worst.runoffPct, 0)} %) · ${t('ro.maxDepth')} ${fmtUi(r.worst.maxDepthMm, 1)} mm', color: r.worst.runoffMm > 0.5 ? Cad.caution : Cad.ok),
              _table(
                ReportTable(
                  key: 'runoff_${m.name.isEmpty ? m.id : m.name}',
                  title: t('reports.machineRunoff'),
                  headers: [
                    '${t('ro.radius')} (${u.lengthLabel})',
                    '${t('ro.peakRate')} (${u.depthRateLabel})',
                    '${t('ro.pass')} (min)',
                    '${t('ro.depth')} (${u.depthLabel})',
                    '${t('ro.runoff')} (${u.depthLabel})',
                    '${t('ro.maxDepth')} (${u.depthLabel})',
                    '${t('ro.minTimer')} (%)',
                  ],
                  rows: [
                    for (final w in r.rows)
                      [
                        RNum(u.lengthFromSi(w.radiusM), 0),
                        RNum(u.depthFromMm(w.peakRateMmH), 1),
                        RNum(w.passMinutes, 0),
                        RNum(u.depthFromMm(w.depthMm), 1),
                        RNum(u.depthFromMm(w.runoffMm), 1),
                        RNum(u.depthFromMm(w.maxDepthMm), 1),
                        w.minTimerPct == null ? '-' : RNum(w.minTimerPct!, 0),
                      ],
                  ],
                  warn: [for (final w in r.rows) w.runoffMm > 0.5],
                ),
                height: 160,
              ),
            ],
          ]);
        }
        final zones = runoffTables(p, c.results, labels).where((x) => x.key == 'zoneRunoff').firstOrNull;
        if (zones != null) body.addAll([SectionTitle(t('reports.zoneRunoff')), _table(zones, height: 180, onLocate: (id) => _locate(c, id))]);
        if (machines.isEmpty && zones == null) body.add(Text(t('ro.none'), style: TextStyle(fontSize: 12, color: Cad.fg60)));
        return AlertDialog(
          title: Text(t('ro.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 640),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [TextButton(key: const Key('ro_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- programme

/// The irrigation programme as a controller is set: the daily window,
/// cycle and soak, the seasonal adjustment (from the requirement or typed),
/// the capacity of the system in the window, the programme by controller
/// station and month (PRD-27) and the runs; CSV of both. Save keeps the
/// settings (the design check takes the window).
Future<void> showIrrigationProgrammeDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final s = p.agronomy.programme.copy();
  var days = 7;
  var month = 0;
  var gen = 0;
  var typed = s.seasonalPct != null;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // the programme with the settings being edited (the project's are put back at once)
        final (prog, cap, tables) = () {
          final kept = p.agronomy.programme;
          p.agronomy.programme = s;
          try {
            final pr = buildIrrigationProgramme(p, c.results, days: days, month: month == 0 ? null : month);
            return (pr, systemCapacity(p, results: c.results), programmeTablesOf(pr, c.exporter().labels));
          } finally {
            p.agronomy.programme = kept;
          }
        }();
        // a system flow by its name, else an item
        String nameOf(String id) => p.systemFlows.where((f) => f.id == id).firstOrNull?.name ?? c.entityName(id);
        Widget num(String key, String label, double value, ValueChanged<double> on, {int decimals = 1}) =>
            NumField(key: ValueKey('prog_${key}_$gen'), label: label, value: value, decimals: decimals, onChanged: (v) => setState(() => on(v)));
        final body = <Widget>[
          _hint(t('prog.hint')),
          if (c.results == null) Text(t('mgmt.needResults'), style: TextStyle(fontSize: 11.5, color: Cad.caution)),
          _pairs(ctx, [
            num('start', t('prog.windowStart'), s.windowStartHour, (v) => s.windowStartHour = v.clamp(0, 24).toDouble()),
            num('hours', t('prog.windowHours'), s.windowHours, (v) => s.windowHours = v.clamp(1, 24).toDouble()),
            num('days', t('mgmt.days'), days.toDouble(), (v) => days = v.round().clamp(1, 60), decimals: 0),
            SpecDropdown<int>(
              key: const Key('prog_month'),
              label: t('mgmt.month'),
              value: '$month',
              items: [for (var m = 0; m <= 12; m++) m],
              labelOf: (m) => m == 0 ? t('mgmt.monthDesign') : t('mon.$m'),
              idOf: (m) => '$m',
              onChanged: (v) => setState(() => month = int.tryParse(v ?? '') ?? 0),
            ),
          ]),
          SwitchListTile(
            key: const Key('prog_cycle_soak'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('prog.cycleSoakOn'), style: const TextStyle(fontSize: 12)),
            value: s.cycleSoak,
            onChanged: (v) => setState(() => s.cycleSoak = v),
          ),
          if (s.cycleSoak)
            _pairs(ctx, [
              num('minCycle', t('prog.minCycle'), s.minCycleMinutes, (v) => s.minCycleMinutes = v.clamp(1, 120).toDouble(), decimals: 0),
              num('maxCycles', t('prog.maxCycles'), s.maxCycles.toDouble(), (v) => s.maxCycles = v.round().clamp(1, 24), decimals: 0),
            ]),
          SwitchListTile(
            key: const Key('prog_seasonal_typed'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('prog.seasonalTyped'), style: const TextStyle(fontSize: 12)),
            value: typed,
            onChanged: (v) => setState(() {
              typed = v;
              s.seasonalPct = v ? [...prog.seasonalPct] : null;
              gen++;
            }),
          ),
          if (typed && s.seasonalPct != null)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var m = 0; m < 12; m++)
                  SizedBox(
                    width: 74,
                    child: NumField(key: ValueKey('prog_pct_${m}_$gen'), label: t('mon.${m + 1}'), value: s.seasonalPct![m], decimals: 0, onChanged: (v) => setState(() => s.seasonalPct![m] = v.clamp(0, 300).toDouble())),
                  ),
              ],
            )
          else
            KV(t('prog.seasonal'), [for (var m = 0; m < 12; m++) '${t('mon.${m + 1}')} ${fmtUi(prog.seasonalPct[m], 0)} %'].join(' · ')),
          SwitchListTile(
            key: const Key('prog_in_reports'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('prog.inReports'), style: const TextStyle(fontSize: 12)),
            value: s.inReports,
            onChanged: (v) => setState(() => s.inReports = v),
          ),
          KV(t('prog.windowUsed'), '${fmtUi(prog.maxDailyWindowHours, 2)} / ${fmtUi(prog.windowHours, 1)} h', color: prog.maxDailyWindowHours > prog.windowHours + 1e-6 ? Cad.caution : null),
          KV(t('prog.capacity'), '${fmtUi(cap.totalHours, 2)} / ${fmtUi(cap.windowHours, 1)} h/d', color: cap.ok ? Cad.ok : Cad.caution),
          for (final m in cap.machines) KV(m.name, '${fmtUi(m.capacityMmDay, 2)} / ${fmtUi(m.peakGrossMmDay, 2)} mm/d', color: m.short ? Cad.caution : Cad.ok),
          for (final x in prog.cycles.values) KV(nameOf(x.flowId), '${x.cycles} × ${fmtUi(x.runMinutes, 0)} min / ${fmtUi(x.soakMinutes, 0)} min'),
          for (final w in prog.warnings) Text(c.t.warning(w, entityName: nameOf), style: TextStyle(fontSize: 11, color: Cad.caution)),
          for (final tb in tables) ...[SectionTitle(tb.title), _table(tb, height: tb.key == 'programmeStations' ? 180 : 200, onLocate: (id) => _locate(c, id))],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                key: const Key('prog_export_stations'),
                onPressed: prog.stations.isEmpty ? null : () => saveTextFile('${p.meta.name}_programme_stations.csv', programmeStationsCsv(prog, t: t.call), mime: 'text/csv'),
                child: Text(t('prog.exportStations')),
              ),
              OutlinedButton(
                key: const Key('prog_export_runs'),
                onPressed: prog.runs.isEmpty ? null : () => saveTextFile('${p.meta.name}_programme_runs.csv', programmeRunsCsv(prog, t: t.call), mime: 'text/csv'),
                child: Text(t('prog.exportRuns')),
              ),
            ],
          ),
        ];
        return AlertDialog(
          title: Text(t('prog.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 720),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(key: const Key('prog_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
            FilledButton(
              key: const Key('prog_save'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final keep = s.copy();
                c.mutate(() => p.agronomy.programme = keep, invalidateResults: false, label: 'hist.programme');
                c.notify(t('prog.saved'));
              },
              child: Text(t('prog.save')),
            ),
          ],
        );
      },
    ),
  );
}
