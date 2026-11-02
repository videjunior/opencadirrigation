/// Report tables of the agronomy added in 1.6.0 (the reports panel and the
/// CSV, TXT, XLSX and PDF exports take them with the others): the daily
/// soil water balance of the areas, the potential runoff of the machines
/// and of the sprinkler areas, the capacity of the system against the peak
/// demand, the programme by controller station and month and its runs
/// (when the programme settings ask for them), the fertigation by growth
/// stage and the field evaluations of uniformity.
library;

import '../model/agronomy_plan.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'agronomy.dart' show clockText;
import 'area_water.dart';
import 'catch_cans.dart';
import 'fertigation_stages.dart';
import 'irrigation_programme.dart';
import 'report_tables.dart';
import 'results.dart';
import 'runoff_potential.dart';
import 'soil_water_balance.dart';
import 'system_capacity.dart';

/// Every table of this library that has rows for [project].
List<ReportTable> agronomyPlusTables(Project project, DesignResults? results, ReportLabels labels) => [
  ?waterBalanceTable(project, labels),
  ...runoffTables(project, results, labels),
  ?capacityTable(project, results, labels),
  if (project.agronomy.programme.inReports) ...programmeTables(project, results, labels),
  ?fertigationTable(project, results, labels),
  ?fieldTestTable(project, results, labels),
];

String _name(Project p, String id) {
  final e = p.byId(id);
  return e == null || e.name.isEmpty ? id : e.name;
}

/// The strategy of [s] in words.
String balanceStrategyText(BalanceSettings s, String Function(String key, [Map<String, String>? args]) t) {
  final base = switch (s.trigger) {
    BalanceTrigger.depletion => s.deficit ? t('swb.strategy.deficit') : t('swb.strategy.raw'),
    BalanceTrigger.interval => t('swb.strategy.interval', {'n': '${s.intervalDays}'}),
    BalanceTrigger.rainfed => t('swb.strategy.rainfed'),
  };
  return s.refillPct < 100 && s.trigger != BalanceTrigger.rainfed ? '$base · ${t('swb.refill')} ${s.refillPct.round()} %' : base;
}

/// The daily soil water balance of every area with a water balance.
ReportTable? waterBalanceTable(Project p, ReportLabels labels) {
  final t = labels.t;
  final u = p.params.units;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  for (final a in p.entities.whereType<AreaEntity>()) {
    final s = balanceSettingsOf(p, a);
    final b = areaWaterBalance(p, a, settings: s);
    if (b == null || b.days.isEmpty) continue;
    final y = b.relativeYield;
    rows.add([
      a.name.isEmpty ? a.id : a.name,
      a.cropKey.isEmpty ? (a.crop.isEmpty ? '-' : a.crop) : cropNameOf(p, a.cropKey, t),
      s.year == 0 || !(balanceYears(p).contains(s.year)) ? t('swb.typicalYear') : '${s.year}',
      balanceStrategyText(s, t),
      b.events.length,
      RNum(u.depthFromMm(b.netMm), 0),
      RNum(u.depthFromMm(b.grossMm), 0),
      RNum(u.volumeFromM3(b.grossMm / 1000 * a.area), 0),
      RNum(u.depthFromMm(b.rainMm), 0),
      RNum(u.depthFromMm(b.effectiveRainMm), 0),
      RNum(u.depthFromMm(b.etcMm), 0),
      RNum(u.depthFromMm(b.etaMm), 0),
      RNum(100 * b.relativeEt, 1),
      b.stressDays,
      y == null ? '-' : RNum(100 * y, 1),
      RNum(u.depthFromMm(b.deepPercolationMm), 0),
    ]);
    warn.add(b.warnings.isNotEmpty);
    ids.add(a.id);
  }
  if (rows.isEmpty) return null;
  return ReportTable(
    key: 'waterBalance',
    title: t('reports.waterBalance'),
    headers: [
      t('rep.area'),
      t('props.crop'),
      t('swb.weather'),
      t('swb.strategy'),
      t('swb.events'),
      '${t('req.net')} (${u.depthLabel})',
      '${t('req.gross')} (${u.depthLabel})',
      '${t('rep.volume')} (${u.volumeLabel})',
      '${t('req.rain')} (${u.depthLabel})',
      '${t('req.effRain')} (${u.depthLabel})',
      'ETc (${u.depthLabel})',
      'ETc,adj (${u.depthLabel})',
      'ETc,adj/ETc (%)',
      t('swb.stressDays'),
      '${t('swb.yield')} (%)',
      '${t('swb.percolation')} (${u.depthLabel})',
    ],
    rows: rows,
    warn: warn,
    ids: ids,
  );
}

/// The potential runoff of the machines (station by station) and of the
/// sprinkler areas over a known soil.
List<ReportTable> runoffTables(Project p, DesignResults? results, ReportLabels labels) {
  final t = labels.t;
  final u = p.params.units;
  final out = <ReportTable>[];
  final mRows = <List<Object>>[];
  final mWarn = <bool>[];
  final mIds = <String?>[];
  for (final m in p.entities.whereType<PivotEntity>()) {
    final r = machineRunoff(p, m, results: results);
    if (r == null) continue;
    for (final row in r.rows) {
      mRows.add([
        r.name,
        RNum(u.lengthFromSi(row.radiusM), 0),
        RNum(u.depthFromMm(row.meanRateMmH), 1),
        RNum(u.depthFromMm(row.peakRateMmH), 1),
        RNum(row.passMinutes, 0),
        RNum(u.depthFromMm(row.depthMm), 1),
        RNum(u.depthFromMm(row.runoffMm), 1),
        RNum(row.runoffPct, 0),
        RNum(u.depthFromMm(row.maxDepthMm), 1),
        row.minTimerPct == null ? '-' : RNum(row.minTimerPct!, 0),
        '${RNum(r.soil.family, 2)} / ${RNum(u.depthFromMm(r.soil.surfaceStorageMm), 1)}',
      ]);
      mWarn.add(row.runoffMm > 0.5);
      mIds.add(m.id);
    }
  }
  if (mRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'machineRunoff',
        title: t('reports.machineRunoff'),
        headers: [
          t('ro.machine'),
          '${t('ro.radius')} (${u.lengthLabel})',
          '${t('ro.meanRate')} (${u.depthRateLabel})',
          '${t('ro.peakRate')} (${u.depthRateLabel})',
          '${t('ro.pass')} (min)',
          '${t('ro.depth')} (${u.depthLabel})',
          '${t('ro.runoff')} (${u.depthLabel})',
          '${t('ro.runoff')} (%)',
          '${t('ro.maxDepth')} (${u.depthLabel})',
          '${t('ro.minTimer')} (%)',
          '${t('ro.family')} / ${t('ro.storage')} (${u.depthLabel})',
        ],
        rows: mRows,
        warn: mWarn,
        ids: mIds,
      ),
    );
  }
  final zones = zoneRunoff(p, results: results);
  if (zones.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'zoneRunoff',
        title: t('reports.zoneRunoff'),
        headers: [
          t('rep.area'),
          '${t('rep.rate')} (${u.depthRateLabel})',
          '${t('ro.intake')} (${u.depthRateLabel})',
          '${t('ro.storage')} (${u.depthLabel})',
          '${t('ro.depth')} (${u.depthLabel})',
          '${t('ro.run')} (h)',
          '${t('ro.runoff')} (${u.depthLabel})',
          '${t('ro.runoff')} (%)',
          '${t('ro.maxRun')} (min)',
          t('prog.cycleSoak'),
        ],
        rows: [
          for (final z in zones)
            [
              z.name,
              RNum(u.depthFromMm(z.rateMmH), 1),
              RNum(u.depthFromMm(z.intakeMmH), 1),
              RNum(u.depthFromMm(z.surfaceStorageMm), 1),
              RNum(u.depthFromMm(z.depthMm), 1),
              RNum(z.runHours, 2),
              RNum(u.depthFromMm(z.runoffMm), 1),
              RNum(z.runoffPct, 0),
              z.maxRunMinutes.isFinite ? RNum(z.maxRunMinutes, 0) : '∞',
              z.cycles > 1 ? '${z.cycles} × ${(z.runHours * 60 / z.cycles).round()} min / ${z.soakMinutes.round()} min' : '-',
            ],
        ],
        warn: [for (final z in zones) z.runoffMm > 0.5],
        ids: [for (final z in zones) z.areaId],
      ),
    );
  }
  return out;
}

/// The capacity of the system against the peak demand (hours of every
/// flow, the window, every machine).
ReportTable? capacityTable(Project p, DesignResults? results, ReportLabels labels) {
  final t = labels.t;
  final u = p.params.units;
  final c = systemCapacity(p, results: results);
  if (c.flows.isEmpty && c.machines.isEmpty) return null;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  for (final f in c.flows) {
    rows.add([f.name.isEmpty ? t('cap.allZones') : f.name, RNum(f.hours, 2), '', '', f.areaId == null ? '' : _name(p, f.areaId!)]);
    warn.add(false);
    ids.add(f.areaId);
  }
  if (c.flows.isNotEmpty) {
    rows.add([t('cap.total', {'w': fmtHours(c.windowHours)}), RNum(c.totalHours, 2), '', '', c.flowsFit ? t('cap.fits') : t('cap.short')]);
    warn.add(!c.flowsFit);
    ids.add(null);
  }
  for (final m in c.machines) {
    rows.add([m.name, RNum(m.hoursNeeded, 2), RNum(u.depthFromMm(m.capacityMmDay), 2), RNum(u.depthFromMm(m.peakGrossMmDay), 2), m.short ? t('cap.short') : t('cap.fits')]);
    warn.add(m.short);
    ids.add(m.pivotId);
  }
  return ReportTable(
    key: 'capacity',
    title: t('reports.capacity'),
    headers: [t('cap.item'), t('cap.hoursNeeded'), '${t('cap.capacity')} (${u.depthPerDayLabel})', '${t('cap.peak')} (${u.depthPerDayLabel})', t('cap.status')],
    rows: rows,
    warn: warn,
    ids: ids,
  );
}

/// Hours as text (`20 h`).
String fmtHours(double h) => '${RNum(h, h == h.roundToDouble() ? 0 : 1)} h';

/// The programme by controller station and month, and its runs.
List<ReportTable> programmeTables(Project p, DesignResults? results, ReportLabels labels) => programmeTablesOf(buildIrrigationProgramme(p, results, days: 7), labels);

/// The tables of the programme [prog].
List<ReportTable> programmeTablesOf(IrrigationProgramme prog, ReportLabels labels) {
  final t = labels.t;
  final out = <ReportTable>[];
  if (prog.stations.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'programmeStations',
        title: t('reports.programmeStations'),
        headers: [
          t('prog.controller'),
          t('prog.station'),
          t('sch.zones'),
          t('rep.area'),
          '${t('rep.flow')} (m³/h)',
          '${t('rep.rate')} (mm/h)',
          t('rep.interval'),
          t('prog.cycleSoak'),
          for (var m = 1; m <= 12; m++) '${t('mon.$m')} (min)',
        ],
        rows: [
          for (final s in prog.stations)
            [
              s.controller.isEmpty ? '-' : s.controller,
              s.station,
              s.name,
              s.areas.join(' + '),
              RNum(s.flowM3h, 2),
              RNum(s.rateMmH, 1),
              s.intervalDays,
              s.cycles == null ? '-' : '${s.cycles!.cycles} × ${s.cycles!.runMinutes.round()} / ${s.cycles!.soakMinutes.round()} min',
              for (final x in s.minutesByMonth) RNum(x, 0),
            ],
          [t('prog.seasonal'), '', '', '', '', '', '', '', for (final x in prog.seasonalPct) '${RNum(x, 0)} %'],
        ],
        ids: [for (final s in prog.stations) s.demandId, null],
      ),
    );
  }
  if (prog.runs.isNotEmpty) {
    String hhmm(double h) => clockText(h, t: t);
    out.add(
      ReportTable(
        key: 'programmeRuns',
        title: t('reports.programmeRuns'),
        headers: [t('sch.date'), t('sch.flow'), t('sch.zones'), t('prog.cycle'), t('sch.start'), t('sch.end'), t('sch.duration')],
        rows: [
          for (final r in prog.runs) [r.day.toIso8601String().substring(0, 10), r.flowName, r.zones.join(' + '), '${r.cycle}/${r.cycles}', hhmm(r.startHour), hhmm(r.endHour), RNum(r.durationHours, 2)],
        ],
      ),
    );
  }
  return out;
}

/// The fertigation by stage of every area with a plan.
ReportTable? fertigationTable(Project p, DesignResults? results, ReportLabels labels) {
  final t = labels.t;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  for (final e in p.agronomy.fertigation.entries) {
    if (e.value.isEmpty) continue;
    final a = p.byId(e.key);
    if (a is! AreaEntity) continue;
    final f = fertigationSchedule(p, a, plan: e.value, results: results);
    if (f == null) continue;
    for (final s in f.stages) {
      rows.add([
        a.name.isEmpty ? a.id : a.name,
        t('fst.stage.${fertStageNames[s.stage]}'),
        '${s.start.toIso8601String().substring(5, 10)} – ${s.end.toIso8601String().substring(5, 10)}',
        s.days,
        RNum(s.kgHa[0], 1),
        RNum(s.kgHa[1], 1),
        RNum(s.kgHa[2], 1),
        s.fertigations,
        for (var k = 0; k < 3; k++) RNum(s.productKgPerEvent[k], 2),
        RNum(s.stockLPerEvent, 1),
        RNum(s.injectionLph, 1),
        RNum(s.concentrationGL, 2),
        RNum(s.ecRiseDsM, 2),
      ]);
      warn.add(f.warnings.any((w) => w.endsWith(':${fertStageNames[s.stage]}')));
      ids.add(a.id);
    }
  }
  if (rows.isEmpty) return null;
  return ReportTable(
    key: 'fertigationStages',
    title: t('reports.fertigationStages'),
    headers: [
      t('rep.area'),
      t('fst.stage'),
      t('fst.dates'),
      t('fst.days'),
      'N (kg/ha)',
      'P₂O₅ (kg/ha)',
      'K₂O (kg/ha)',
      t('fst.events'),
      '${t('fst.productN')} (kg)',
      '${t('fst.productP')} (kg)',
      '${t('fst.productK')} (kg)',
      '${t('fst.stock')} (L)',
      '${t('fst.injection')} (L/h)',
      '${t('fst.concentration')} (g/L)',
      'ΔEC (dS/m)',
    ],
    rows: rows,
    warn: warn,
    ids: ids,
  );
}

/// The field evaluations of uniformity.
ReportTable? fieldTestTable(Project p, DesignResults? results, ReportLabels labels) {
  final t = labels.t;
  if (p.agronomy.fieldTests.isEmpty) return null;
  final rows = <List<Object>>[];
  for (final ft in p.agronomy.fieldTests) {
    final e = evaluateFieldTest(p, ft, results: results);
    final cans = ft.kind == FieldTestKind.cans;
    rows.add([
      ft.name.isEmpty ? ft.id : ft.name,
      t('ft.kind.${ft.kind.name}'),
      ft.zoneId.isEmpty ? '-' : _name(p, ft.zoneId),
      ft.date.isEmpty ? '-' : ft.date,
      e.measuredStats.count,
      RNum(e.measuredStats.mean, 2),
      cans ? 'mm' : 'L/h',
      RNum(e.measuredStats.cu, 1),
      RNum(e.measuredStats.du, 1),
      RNum(e.measuredStats.us, 1),
      cans && e.predictedStats.count > 0 ? RNum(e.predictedStats.cu, 1) : '-',
      cans && e.predictedStats.count > 0 ? RNum(e.predictedStats.du, 1) : '-',
      e.designMean > 0 ? RNum(100 * e.meanRatio, 0) : '-',
    ]);
  }
  return ReportTable(
    key: 'fieldTests',
    title: t('reports.fieldTests'),
    headers: [t('ft.name'), t('ft.kind'), t('sch.zones'), t('ft.date'), t('ft.count'), t('ft.mean'), t('ft.unit'), 'CU %', 'DU %', 'US %', '${t('ft.design')} CU %', '${t('ft.design')} DU %', '${t('ft.meanRatio')} (%)'],
    rows: rows,
  );
}
