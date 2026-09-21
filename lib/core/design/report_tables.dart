/// Tabular report data shared by the reports panel and every report
/// exporter (CSV, TXT, XLSX, PDF), so all outputs show the same numbers.
library;

import 'dart:math' as math;

import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'agronomy.dart';
import 'designer.dart';
import 'results.dart';

/// Formatted number cell: keeps the raw value for spreadsheets and the number
/// of decimals for text outputs.
class RNum {
  const RNum(this.value, [this.decimals = 2]);
  final double value;
  final int decimals;
  @override
  String toString() => fmt(value, decimals);
}

class ReportTable {
  ReportTable({required this.key, required this.title, required this.headers, required this.rows, List<bool>? warn}) : warn = warn ?? List.filled(rows.length, false);

  /// Stable identifier: zones, pipes, outlets, mainline, bom, water, messages.
  final String key;
  final String title;
  final List<String> headers;

  /// Cells are [String], [RNum] or [int].
  final List<List<Object>> rows;

  /// Rows that should be highlighted as warnings.
  final List<bool> warn;

  bool get isEmpty => rows.isEmpty;
}

/// Labels/translation hooks needed to build the tables.
class ReportLabels {
  ReportLabels({required this.t, required this.has, required this.warning, this.entityName});
  final Translate t;
  final bool Function(String key) has;

  /// Translates a warning code such as `velocity_exceeded:e12`.
  final String Function(String code) warning;

  /// Display name of an entity id (defaults to the id).
  final String Function(String id)? entityName;

  String name(String id) => entityName?.call(id) ?? id;
  String category(String key) => has(key) ? t(key) : key;
}

/// Builds every report table available for the project. Tables that need
/// design results are omitted when [results] is null; the water table only
/// needs irrigated areas.
List<ReportTable> buildReportTables({required Project project, required DesignResults? results, required ReportLabels labels, Set<String> unconnected = const {}, bool includeMessages = true}) {
  final t = labels.t;
  final u = project.params.units;
  final out = <ReportTable>[];
  final r = results;
  if (r != null) {
    // ---- zones
    final zones = r.zones.values.toList();
    out.add(ReportTable(
      key: 'zones',
      title: t('reports.zone'),
      headers: [t('rep.zone'), t('rep.valve'), t('rep.emitters'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.pDown')} (${u.pressureLabel})', t('rep.valveLoss'), t('rep.pRequired'), t('rep.pMin'), t('rep.pMax'), t('rep.allowMin'), t('rep.allowMax'), t('rep.varAllow'), t('rep.varActual'), 'CU %', 'DU %', 'EU %', t('rep.overlapCu'), '${t('rep.pipeCost')} (${project.params.currency})', t('rep.warnings')],
      rows: [
        for (final z in zones)
          [z.zoneName, z.valveSpecName, z.emitterCount, RNum(u.flowFromSi(z.totalFlow), 1), RNum(u.pressureFromHead(z.downstreamHead), 1), RNum(u.pressureFromHead(z.valveLoss), 2), RNum(u.pressureFromHead(z.requiredUpstreamHead), 1), RNum(u.pressureFromHead(z.minOutletPressure), 1), RNum(u.pressureFromHead(z.maxOutletPressure), 1), RNum(u.pressureFromHead(z.allowedMin), 1), RNum(u.pressureFromHead(z.allowedMax), 1), RNum(z.allowedVariationPct, 1), RNum(z.actualVariationPct, 1), RNum(z.uniformity.cu, 1), RNum(z.uniformity.du, 1), RNum(z.uniformity.eu, 1), z.overlapCu > 0 ? RNum(z.overlapCu, 0) : '-', RNum(z.pipeCost, 0), z.warnings.map(labels.warning).join('; ')],
      ],
      warn: [for (final z in zones) !z.withinWindow],
    ));
    // ---- pipes
    final pipeRows = <List<Object>>[];
    final pipeWarn = <bool>[];
    void addPipe(String ctx, PipeSegmentResult p) {
      pipeRows.add([ctx, labels.name(p.entityId), p.segmentIndex, p.pipeName, RNum(u.diameterFromSi(p.diameter), 1), RNum(u.lengthFromSi(p.length), 1), RNum(u.flowFromSi(p.flow.abs()), 1), RNum(u.velocityFromSi(p.velocity), 2), RNum(u.pressureFromHead(p.headLoss.abs()), 2), RNum(u.pressureFromHead(p.pressureStart), 1), RNum(u.pressureFromHead(p.pressureEnd), 1), RNum(p.elevationA, 1), RNum(p.elevationB, 1), RNum(u.pressureFromHead(p.pressureRating), 0)]);
      pipeWarn.add(p.overVelocity || p.overPressure);
    }

    for (final z in r.zones.values) {
      for (final p in z.pipes) {
        addPipe(z.zoneName, p);
      }
    }
    for (final f in r.systemFlows) {
      for (final p in f.pipes) {
        addPipe(f.name, p);
      }
    }
    out.add(ReportTable(
      key: 'pipes',
      title: t('reports.pipes'),
      headers: [t('rep.context'), t('rep.entity'), t('rep.segment'), t('rep.pipe'), '${t('rep.innerDiam')} (${u.diameterLabel})', '${t('rep.length')} (${u.lengthLabel})', '${t('rep.q')} (${u.flowLabel})', 'V (${u.velocityLabel})', '${t('rep.hf')} (${u.pressureLabel})', t('rep.pStart'), t('rep.pEnd'), t('rep.zStart'), t('rep.zEnd'), t('rep.pn')],
      rows: pipeRows,
      warn: pipeWarn,
    ));
    // ---- outlets
    final outletRows = <List<Object>>[];
    final outletWarn = <bool>[];
    for (final z in r.zones.values) {
      final byEntity = <String, List<OutletResult>>{};
      for (final o in z.outlets) {
        byEntity.putIfAbsent(o.entityId, () => []).add(o);
      }
      for (final e in byEntity.entries) {
        final list = e.value;
        final pmin = list.map((o) => o.pressure).reduce((a, b) => a < b ? a : b);
        final pmax = list.map((o) => o.pressure).reduce((a, b) => a > b ? a : b);
        final q = list.fold<double>(0, (s, o) => s + o.flow * o.count);
        final n = list.fold<int>(0, (s, o) => s + o.count);
        outletRows.add([z.zoneName, labels.name(e.key), list.first.label, n, RNum(u.flowFromSi(q), 1), RNum(u.flowFromSi(n > 0 ? q / n : 0), 2), RNum(u.pressureFromHead(pmin), 1), RNum(u.pressureFromHead(pmax), 1), RNum(u.pressureFromHead(list.first.allowedMin), 1), RNum(u.pressureFromHead(list.first.allowedMax), 1)]);
        outletWarn.add(!list.every((o) => o.inWindow));
      }
    }
    out.add(ReportTable(
      key: 'outlets',
      title: t('reports.outlets'),
      headers: [t('rep.zone'), t('rep.entity'), t('rep.emitter'), t('rep.n'), '${t('rep.qTotal')} (${u.flowLabel})', '${t('rep.qMean')} (${u.flowLabel})', '${t('rep.pMin')} (${u.pressureLabel})', t('rep.pMax'), t('rep.allowMin'), t('rep.allowMax')],
      rows: outletRows,
      warn: outletWarn,
    ));
    // ---- mainline / duty
    final mainRows = <List<Object>>[];
    final mainWarn = <bool>[];
    for (final f in r.systemFlows) {
      for (final s in f.supplies) {
        final surplus = s.surplusHead > 0.05 ? ' · ${t('rep.surplus')} ${fmt(u.pressureFromHead(s.surplusHead), 1)}' : '';
        mainRows.add([f.name, '${t('rep.supply')}: ${s.name}', RNum(u.flowFromSi(s.flow), 1), RNum(u.pressureFromHead(s.head), 1), RNum(u.pressureFromHead(math.max(0, s.requiredHead)), 1), '${s.calculated ? t('rep.calculated') : t('rep.fixed')}$surplus', RNum(f.annualEnergyCost, 0)]);
        mainWarn.add(s.flowExceedsDesign || s.headExceedsMax);
      }
      for (final v in f.valves) {
        mainRows.add([f.name, '${t('rep.valve')}: ${v.zoneName}', RNum(u.flowFromSi(v.flow), 1), RNum(u.pressureFromHead(v.availableHead), 1), RNum(u.pressureFromHead(v.requiredHead), 1), v.deficit > 0.01 ? '${t('rep.deficit')} ${fmt(u.pressureFromHead(v.deficit), 1)}' : t('rep.ok'), '']);
        mainWarn.add(v.deficit > 0.01);
      }
    }
    out.add(ReportTable(
      key: 'mainline',
      title: t('reports.mainline'),
      headers: [t('rep.flowName'), t('rep.item'), '${t('rep.q')} (${u.flowLabel})', '${t('rep.pAvailable')} (${u.pressureLabel})', t('rep.pRequired'), t('rep.status'), '${t('rep.energyYear')} (${project.params.currency})'],
      rows: mainRows,
      warn: mainWarn,
    ));
    // ---- pumps and inline devices of the mainline: pressure at the inlet
    // (negative = suction) and at the outlet
    final devRows = <List<Object>>[];
    final devWarn = <bool>[];
    for (final f in r.systemFlows) {
      for (final d in f.devices) {
        final e = project.byId(d.entityId);
        final isPump = e is PumpEntity;
        final specName = switch (e) {
          PumpEntity p => project.catalog.pump(p.pumpSpecId)?.name,
          MiscHydraulicEntity m => project.catalog.valve(m.valveSpecId)?.name,
          _ => null,
        };
        final name = (e?.name.isNotEmpty ?? false) ? e!.name : (specName ?? labels.name(d.entityId));
        final flagged = f.warnings.any((w) => w == 'pump_suction_lift:${d.entityId}' || w == 'pump_out_of_range:${d.entityId}');
        devRows.add([
          f.name,
          '${isPump ? t('rep.pump') : t('rep.device')}: $name',
          RNum(u.flowFromSi(d.flow), 1),
          RNum(u.pressureFromHead(d.upstreamPressure), 1),
          RNum(u.pressureFromHead(d.downstreamPressure), 1),
          if (isPump) RNum(u.pressureFromHead(d.pumpHead), 1) else '',
          if (isPump) '' else RNum(u.pressureFromHead(d.headLoss), 2),
          deviceStatusText(t, d, f.warnings, pump: isPump ? project.catalog.pump(e.pumpSpecId) : null, isPump: isPump, units: u),
        ]);
        devWarn.add(flagged);
      }
    }
    out.add(ReportTable(
      key: 'devices',
      title: t('reports.devices'),
      headers: [t('rep.flowName'), t('rep.item'), '${t('rep.q')} (${u.flowLabel})', '${t('rep.pIn')} (${u.pressureLabel})', t('rep.pOut'), t('rep.pumpHead'), t('rep.loss'), t('rep.status')],
      rows: devRows,
      warn: devWarn,
    ));
    // ---- bill of materials
    final cur = project.params.currency;
    final bomRows = <List<Object>>[for (final l in r.bom) [labels.category(l.category), l.description, l.code, l.unit, RNum(l.quantity, 1), RNum(l.unitCost), RNum(l.total)]];
    bomRows.add([t('rep.totalRow'), '', '', '', '', '', RNum(r.capitalCost)]);
    bomRows.add([t('rep.annualCapital'), '', '', '', '', '', RNum(r.annualCapitalCost)]);
    bomRows.add([t('rep.annualEnergy'), '', '', '', '', '', RNum(r.annualEnergyCost)]);
    bomRows.add([t('rep.annualTotal'), '', '', '', '', '', RNum(r.annualCapitalCost + r.annualEnergyCost)]);
    out.add(ReportTable(
      key: 'bom',
      title: t('reports.bom'),
      headers: [t('rep.category'), t('rep.description'), t('rep.code'), t('rep.unit'), t('rep.quantity'), '${t('rep.unitCost')} ($cur)', '${t('rep.total')} ($cur)'],
      rows: bomRows,
    ));
    // ---- pivots / linear moves
    if (r.pivots.isNotEmpty) {
      final pv = r.pivots.values.toList();
      out.add(ReportTable(
        key: 'pivots',
        title: t('reports.pivots'),
        headers: [t('rep.pivot'), t('rep.type'), t('rep.towers'), '${t('rep.area')} (ha)', '${t('rep.flow')} (${u.flowLabel})', '${t('rep.pRequired')} (${u.pressureLabel})', '${t('rep.pAvail')} (${u.pressureLabel})', '${t('rep.hf')} (${u.pressureLabel})', '${t('rep.rise')} (m)', '${t('rep.pEnd')} (${u.pressureLabel})', 'V (${u.velocityLabel})', '${t('rep.depthCycle')} (mm)', '${t('rep.hoursCycle')} (h)', '${t('rep.appRatePeak')} (mm/h)', t('rep.warnings')],
        rows: [
          for (final p in pv)
            [p.name, p.kind == PivotKind.pivot ? t('pivot.kindPivot') : t('pivot.kindLinear'), p.towerCount, RNum(p.areaM2 / 10000, 2), RNum(u.flowFromSi(p.flow), 1), RNum(u.pressureFromHead(p.inletHead), 1), p.availableHead == null ? '-' : RNum(u.pressureFromHead(p.availableHead!), 1), RNum(u.pressureFromHead(p.frictionLoss), 2), RNum(p.elevationRise, 2), RNum(u.pressureFromHead(p.endPressure), 1), RNum(u.velocityFromSi(p.inletVelocity), 2), RNum(p.depthPerCycleMm, 1), RNum(p.hoursPerCycle, 1), RNum(p.appRateEndPeak, 1), p.warnings.map(labels.warning).join('; ')],
        ],
        warn: [for (final p in pv) p.warnings.isNotEmpty || p.deficit > 0.01],
      ));
      final spanRows = <List<Object>>[];
      for (final p in pv) {
        for (final sp in p.spans) {
          spanRows.add([p.name, sp.index, RNum(u.lengthFromSi(sp.rStart), 0), RNum(u.lengthFromSi(sp.rEnd), 0), sp.sprinklers, RNum(sp.flowPerSprinkler / m3sPerLph, 0), RNum(u.pressureFromHead(sp.pressure), 1), sp.nozzle.isEmpty ? '-' : sp.nozzle]);
        }
      }
      if (spanRows.isNotEmpty) {
        out.add(ReportTable(
          key: 'pivotSpans',
          title: t('reports.pivotSpans'),
          headers: [t('rep.pivot'), t('rep.span'), '${t('rep.rFrom')} (${u.lengthLabel})', '${t('rep.rTo')} (${u.lengthLabel})', t('rep.sprinklers'), '${t('rep.qSprinkler')} (L/h)', '${t('rep.pMid')} (${u.pressureLabel})', t('rep.nozzleSuggested')],
          rows: spanRows,
        ));
      }
    }
    // ---- flushing
    if (r.flushing.isNotEmpty) {
      out.add(ReportTable(
        key: 'flushing',
        title: t('reports.flushing'),
        headers: [t('rep.zone'), t('rep.tapes'), '${t('rep.flow')} (${u.flowLabel})', '${t('rep.pDown')} (${u.pressureLabel})', t('rep.pRequired'), '${t('rep.pEnd')} (${u.pressureLabel})', 'V (${u.velocityLabel})', t('rep.vFlush')],
        rows: [
          for (final f in r.flushing) [f.zoneName, f.tapeCount, RNum(u.flowFromSi(f.flow), 1), RNum(u.pressureFromHead(f.requiredDownstreamHead), 1), RNum(u.pressureFromHead(f.requiredUpstreamHead), 1), RNum(u.pressureFromHead(f.minEndHead), 2), RNum(u.velocityFromSi(f.maxVelocity), 2), RNum(u.velocityFromSi(f.flushingVelocity), 2)],
        ],
        warn: [for (final f in r.flushing) !f.converged],
      ));
    }
    // ---- surge (water hammer)
    if (r.surge.isNotEmpty) {
      out.add(ReportTable(
        key: 'surge',
        title: t('reports.surge'),
        headers: [t('rep.context'), t('rep.entity'), t('rep.pipe'), 'V (${u.velocityLabel})', '${t('rep.celerity')} (m/s)', '${t('rep.surge')} (${u.pressureLabel})', '${t('rep.pStatic')} (${u.pressureLabel})', '${t('rep.pTotal')} (${u.pressureLabel})', t('rep.pn'), t('rep.tCritical')],
        rows: [
          for (final s in r.surge) [s.context, labels.name(s.entityId), s.pipeName, RNum(u.velocityFromSi(s.velocity), 2), RNum(s.celerity, 0), RNum(u.pressureFromHead(s.surgeHead), 1), RNum(u.pressureFromHead(s.maxStaticHead), 1), RNum(u.pressureFromHead(s.totalHead), 1), RNum(u.pressureFromHead(s.rating), 0), RNum(s.criticalTime, 2)],
        ],
        warn: [for (final s in r.surge) s.exceeds],
      ));
    }
  }
  // ---- crop water / schedule (available with areas)
  final crops = cropWaterRequirements(project, results);
  if (crops.isNotEmpty) {
    out.add(ReportTable(
      key: 'crop',
      title: t('reports.crop'),
      headers: [t('rep.area'), 'ETc (mm/d)', '${t('rep.raw')} (mm)', t('rep.interval'), '${t('rep.netEvent')} (mm)', '${t('rep.grossEvent')} (mm)', t('rep.rate'), t('rep.hoursEvent'), '${t('rep.volume')} (m³)', t('rep.hoursDay')],
      rows: [
        for (final c in crops) [c.name, RNum(c.etcMmDay, 2), RNum(c.rawMm, 1), RNum(c.intervalDays, 0), RNum(c.netDepthMm, 1), RNum(c.grossDepthMm, 1), RNum(c.applicationRateMmH, 2), RNum(c.hoursPerEvent, 2), RNum(c.volumePerEventM3, 1), RNum(c.dailyHours, 2)],
      ],
    ));
    final prog = buildControllerProgram(project, results, days: 7);
    if (prog.entries.isNotEmpty) {
      String hhmm(double h) {
        final hh = h.floor() % 24, mm = ((h - h.floor()) * 60).round();
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }

      out.add(ReportTable(
        key: 'schedule',
        title: t('reports.schedule'),
        headers: [t('sch.date'), t('sch.flow'), t('sch.zones'), t('sch.start'), t('sch.end'), t('sch.duration'), '${t('rep.flow')} (${u.flowLabel})'],
        rows: [
          for (final e in prog.entries) [e.day.toIso8601String().substring(0, 10), e.flowName, e.zones.join(' + '), hhmm(e.startHour), hhmm(e.endHour), RNum(e.durationHours, 2), RNum(u.flowFromSi(e.flow), 1)],
        ],
      ));
    }
  }
  // ---- water requirements (available without results)
  final reqs = areaRequirements(project, results);
  if (reqs.isNotEmpty) {
    out.add(ReportTable(
      key: 'water',
      title: t('reports.water'),
      headers: [t('rep.area'), 'ha', t('rep.grossDepth'), t('rep.volume'), '${t('rep.flow')} (${u.flowLabel})', t('rep.rate'), t('rep.hoursDay')],
      rows: [
        for (final a in reqs) [a.name, RNum(a.areaM2 / 10000, 3), RNum(a.grossDepthMm, 1), RNum(a.dailyVolumeM3, 1), RNum(u.flowFromSi(a.flow), 1), RNum(a.precipitationMmH, 2), RNum(a.hoursPerDay, 2)],
      ],
    ));
  }
  // ---- messages
  if (includeMessages) {
    final rows = <List<Object>>[];
    final warn = <bool>[];
    if (r != null) {
      for (final m in r.messages) {
        rows.add(['', labels.warning(m)]);
        warn.add(true);
      }
      for (final z in r.zones.values) {
        for (final w in z.warnings) {
          rows.add([z.zoneName, labels.warning(w)]);
          warn.add(!z.withinWindow);
        }
      }
      for (final f in r.systemFlows) {
        for (final w in f.warnings) {
          rows.add([f.name, labels.warning(w)]);
          warn.add(true);
        }
      }
    }
    for (final id in unconnected) {
      rows.add([t('msg.unconnectedItem'), labels.name(id)]);
      warn.add(true);
    }
    if (rows.isNotEmpty) out.add(ReportTable(key: 'messages', title: t('reports.messages'), headers: [t('rep.context'), t('reports.messages')], rows: rows, warn: warn));
  }
  return out;
}

/// Operating state of a pump or inline device for the reports: running /
/// stopped (pumps), open / closed / regulating (devices), plus the suction
/// lift against its limit, "submersible" and "out of range" when they apply
/// ([warnings] are those of the analysis the device belongs to).
String deviceStatusText(Translate t, DeviceResult d, List<String> warnings, {required bool isPump, PumpSpec? pump, required Units units}) {
  final parts = <String>[
    switch (d.status) {
      'closed' => t(isPump ? 'rep.st.stopped' : 'rep.st.closed'),
      'active' => t('rep.st.active'),
      _ => t(isPump ? 'rep.st.running' : 'rep.st.open'),
    },
  ];
  if (warnings.contains('pump_suction_lift:${d.entityId}')) {
    parts.add('${t('rep.suction')} ${fmt(units.pressureFromHead(-d.upstreamPressure), 1)} > ${fmt(units.pressureFromHead(maxSuctionLift(d.elevation)), 1)}');
  }
  if (warnings.contains('pump_out_of_range:${d.entityId}')) parts.add(t('rep.outOfRange'));
  if (pump?.submersible ?? false) parts.add(t('rep.submersible'));
  return parts.join(' · ');
}

/// Semicolon-separated CSV (Excel-friendly in pt/es locales) with a UTF-8 BOM.
String reportTablesToCsv(List<ReportTable> tables) {
  final b = StringBuffer('﻿');
  for (final tb in tables) {
    b.writeln(tb.title.toUpperCase());
    b.writeln(tb.headers.map(_csvCell).join(';'));
    for (final r in tb.rows) {
      b.writeln(r.map((c) => _csvCell('$c')).join(';'));
    }
    b.writeln();
  }
  return b.toString();
}

String _csvCell(String s) => s.contains(RegExp(r'[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// Fixed-width plain-text report.
String reportTablesToText(List<ReportTable> tables, {List<String> header = const []}) {
  final b = StringBuffer();
  for (final h in header) {
    b.writeln(h);
  }
  if (header.isNotEmpty) b.writeln();
  for (final tb in tables) {
    final cells = [tb.headers, ...tb.rows.map((r) => r.map((c) => '$c').toList())];
    final n = tb.headers.length;
    final widths = List<int>.filled(n, 0);
    for (final row in cells) {
      for (var i = 0; i < n && i < row.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }
    final numeric = List<bool>.generate(n, (i) => tb.rows.every((r) => i >= r.length || r[i] is num || r[i] is RNum || '${r[i]}'.isEmpty));
    String line(List<String> row) => [for (var i = 0; i < n; i++) i < row.length ? (numeric[i] ? row[i].padLeft(widths[i]) : row[i].padRight(widths[i])) : ''.padRight(widths[i])].join('  ');
    b.writeln(tb.title.toUpperCase());
    b.writeln(line(tb.headers));
    b.writeln(List.filled(widths.fold(0, (s, w) => s + w) + 2 * (n - 1), '-').join());
    for (var i = 0; i < tb.rows.length; i++) {
      b.writeln(line(cells[i + 1]));
    }
    b.writeln();
  }
  return b.toString();
}
