/// Tabular report data shared by the reports panel and every report
/// exporter (CSV, TXT, XLSX, PDF), so all outputs show the same numbers.
library;

import 'dart:math' as math;

import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/scenario.dart';
import '../translate.dart';
import '../units.dart';
import 'agronomy.dart';
import 'area_requirement.dart';
import 'designer.dart';
import 'proposal.dart';
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

/// Timeline cell of a schedule: days [start] (from 0) to [end] (the day
/// after the last) of [total]. Text outputs show it as a bar of characters
/// [width] long; the PDF draws a bar (the bundled fonts have no block
/// characters).
class RBar {
  const RBar(this.start, this.end, this.total, {this.width = 30});
  final int start, end, total;
  final int width;
  @override
  String toString() {
    if (total <= 0) return '';
    final a = (start * width / total).round(), b = math.max(a + 1, (end * width / total).round());
    return '${'·' * a}${'█' * (b - a)}';
  }
}

class ReportTable {
  ReportTable({required this.key, required this.title, required this.headers, required this.rows, List<bool>? warn}) : warn = warn ?? List.filled(rows.length, false);

  /// Stable identifier: zones, pipes, outlets, mainline, bom, water, messages.
  final String key;
  final String title;
  final List<String> headers;

  /// Cells are [String], [RNum], [RBar] or [int].
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
    out.add(
      ReportTable(
        key: 'zones',
        title: t('reports.zone'),
        headers: [
          t('rep.zone'),
          t('rep.valve'),
          t('rep.emitters'),
          '${t('rep.flow')} (${u.flowLabel})',
          '${t('rep.pDown')} (${u.pressureLabel})',
          t('rep.valveLoss'),
          t('rep.pRequired'),
          t('rep.pMin'),
          t('rep.pMax'),
          t('rep.allowMin'),
          t('rep.allowMax'),
          t('rep.varAllow'),
          t('rep.varActual'),
          'CU %',
          'DU %',
          'EU %',
          t('rep.overlapCu'),
          '${t('rep.pipeCost')} (${project.params.currency})',
          t('rep.warnings'),
        ],
        rows: [
          for (final z in zones)
            [
              z.zoneName,
              z.valveSpecName,
              z.emitterCount,
              RNum(u.flowFromSi(z.totalFlow), 1),
              RNum(u.pressureFromHead(z.downstreamHead), 1),
              RNum(u.pressureFromHead(z.valveLoss), 2),
              RNum(u.pressureFromHead(z.requiredUpstreamHead), 1),
              RNum(u.pressureFromHead(z.minOutletPressure), 1),
              RNum(u.pressureFromHead(z.maxOutletPressure), 1),
              RNum(u.pressureFromHead(z.allowedMin), 1),
              RNum(u.pressureFromHead(z.allowedMax), 1),
              RNum(z.allowedVariationPct, 1),
              RNum(z.actualVariationPct, 1),
              RNum(z.uniformity.cu, 1),
              RNum(z.uniformity.du, 1),
              RNum(z.uniformity.eu, 1),
              z.overlapCu > 0 ? RNum(z.overlapCu, 0) : '-',
              RNum(z.pipeCost, 0),
              z.warnings.map(labels.warning).join('; '),
            ],
        ],
        warn: [for (final z in zones) !z.withinWindow],
      ),
    );
    // ---- pipes
    final pipeRows = <List<Object>>[];
    final pipeWarn = <bool>[];
    void addPipe(String ctx, PipeSegmentResult p) {
      pipeRows.add([
        ctx,
        labels.name(p.entityId),
        p.segmentIndex,
        p.pipeName,
        RNum(u.diameterFromSi(p.diameter), 1),
        RNum(u.lengthFromSi(p.length), 1),
        RNum(u.flowFromSi(p.flow.abs()), 1),
        RNum(u.velocityFromSi(p.velocity), 2),
        RNum(u.pressureFromHead(p.headLoss.abs()), 2),
        RNum(u.pressureFromHead(p.pressureStart), 1),
        RNum(u.pressureFromHead(p.pressureEnd), 1),
        RNum(p.elevationA, 1),
        RNum(p.elevationB, 1),
        RNum(u.pressureFromHead(p.pressureRating), 0),
      ]);
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
    out.add(
      ReportTable(
        key: 'pipes',
        title: t('reports.pipes'),
        headers: [
          t('rep.context'),
          t('rep.entity'),
          t('rep.segment'),
          t('rep.pipe'),
          '${t('rep.innerDiam')} (${u.diameterLabel})',
          '${t('rep.length')} (${u.lengthLabel})',
          '${t('rep.q')} (${u.flowLabel})',
          'V (${u.velocityLabel})',
          '${t('rep.hf')} (${u.pressureLabel})',
          t('rep.pStart'),
          t('rep.pEnd'),
          t('rep.zStart'),
          t('rep.zEnd'),
          t('rep.pn'),
        ],
        rows: pipeRows,
        warn: pipeWarn,
      ),
    );
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
        outletRows.add([
          z.zoneName,
          labels.name(e.key),
          list.first.label,
          n,
          RNum(u.flowFromSi(q), 1),
          RNum(u.flowFromSi(n > 0 ? q / n : 0), 2),
          RNum(u.pressureFromHead(pmin), 1),
          RNum(u.pressureFromHead(pmax), 1),
          RNum(u.pressureFromHead(list.first.allowedMin), 1),
          RNum(u.pressureFromHead(list.first.allowedMax), 1),
        ]);
        outletWarn.add(!list.every((o) => o.inWindow));
      }
    }
    out.add(
      ReportTable(
        key: 'outlets',
        title: t('reports.outlets'),
        headers: [
          t('rep.zone'),
          t('rep.entity'),
          t('rep.emitter'),
          t('rep.n'),
          '${t('rep.qTotal')} (${u.flowLabel})',
          '${t('rep.qMean')} (${u.flowLabel})',
          '${t('rep.pMin')} (${u.pressureLabel})',
          t('rep.pMax'),
          t('rep.allowMin'),
          t('rep.allowMax'),
        ],
        rows: outletRows,
        warn: outletWarn,
      ),
    );
    // ---- mainline / duty
    final mainRows = <List<Object>>[];
    final mainWarn = <bool>[];
    for (final f in r.systemFlows) {
      for (final s in f.supplies) {
        final surplus = s.surplusHead > 0.05 ? ' · ${t('rep.surplus')} ${fmt(u.pressureFromHead(s.surplusHead), 1)}' : '';
        mainRows.add([
          f.name,
          '${t('rep.supply')}: ${s.name}',
          RNum(u.flowFromSi(s.flow), 1),
          RNum(u.pressureFromHead(s.head), 1),
          RNum(u.pressureFromHead(math.max(0, s.requiredHead)), 1),
          '${s.calculated ? t('rep.calculated') : t('rep.fixed')}$surplus',
          RNum(f.annualEnergyCost, 0),
        ]);
        mainWarn.add(s.flowExceedsDesign || s.headExceedsMax);
      }
      for (final v in f.valves) {
        mainRows.add([
          f.name,
          '${t('rep.valve')}: ${v.zoneName}',
          RNum(u.flowFromSi(v.flow), 1),
          RNum(u.pressureFromHead(v.availableHead), 1),
          RNum(u.pressureFromHead(v.requiredHead), 1),
          v.deficit > 0.01 ? '${t('rep.deficit')} ${fmt(u.pressureFromHead(v.deficit), 1)}' : t('rep.ok'),
          '',
        ]);
        mainWarn.add(v.deficit > 0.01);
      }
    }
    out.add(
      ReportTable(
        key: 'mainline',
        title: t('reports.mainline'),
        headers: [
          t('rep.flowName'),
          t('rep.item'),
          '${t('rep.q')} (${u.flowLabel})',
          '${t('rep.pAvailable')} (${u.pressureLabel})',
          t('rep.pRequired'),
          t('rep.status'),
          '${t('rep.energyYear')} (${project.params.currency})',
        ],
        rows: mainRows,
        warn: mainWarn,
      ),
    );
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
    out.add(
      ReportTable(
        key: 'devices',
        title: t('reports.devices'),
        headers: [t('rep.flowName'), t('rep.item'), '${t('rep.q')} (${u.flowLabel})', '${t('rep.pIn')} (${u.pressureLabel})', t('rep.pOut'), t('rep.pumpHead'), t('rep.loss'), t('rep.status')],
        rows: devRows,
        warn: devWarn,
      ),
    );
    // ---- valve-in-head stations in every flow they run in
    if (r.systemFlows.any((f) => f.heads.isNotEmpty)) {
      final vihRows = <List<Object>>[];
      final vihWarn = <bool>[];
      Object window(double v) => v.isFinite ? RNum(u.pressureFromHead(v), 1) : '-';
      for (final f in r.systemFlows) {
        for (final h in f.heads) {
          final high = h.maxPressure > h.allowedMax + 0.01;
          final status = !h.scheduled
              ? t('rep.vihEveryFlow')
              : h.deficit > 0.01
              ? '${t('rep.deficit')} ${fmt(u.pressureFromHead(h.deficit), 1)}'
              : (high ? t('rep.vihHigh') : t('rep.ok'));
          vihRows.add([
            f.name,
            h.name,
            h.heads,
            RNum(u.flowFromSi(h.flow), 1),
            RNum(u.pressureFromHead(h.minPressure), 1),
            RNum(u.pressureFromHead(h.maxPressure), 1),
            window(h.allowedMin),
            window(h.allowedMax),
            status,
          ]);
          vihWarn.add(h.scheduled && (h.deficit > 0.01 || high));
        }
      }
      out.add(
        ReportTable(
          key: 'vih',
          title: t('reports.vih'),
          headers: [
            t('rep.flowName'),
            t('rep.vihStation'),
            t('rep.n'),
            '${t('rep.q')} (${u.flowLabel})',
            '${t('rep.pMin')} (${u.pressureLabel})',
            t('rep.pMax'),
            t('rep.allowMin'),
            t('rep.allowMax'),
            t('rep.status'),
          ],
          rows: vihRows,
          warn: vihWarn,
        ),
      );
    }
    // ---- bill of materials
    final cur = project.params.currency;
    // the BNDES FINAME column only when an item carries a code
    final withFiname = r.bom.any((l) => l.finame.isNotEmpty);
    List<Object> sumRow(String label, double v) => [label, '', '', '', '', '', if (withFiname) '', RNum(v)];
    final bomRows = <List<Object>>[
      for (final l in r.bom) [labels.category(l.category), l.description, l.code, l.unit, RNum(l.quantity, 1), RNum(l.unitCost), if (withFiname) l.finame, RNum(l.total)],
    ];
    bomRows.add(sumRow(t('rep.totalRow'), r.capitalCost));
    if (withFiname) bomRows.add(sumRow(t('rep.finameTotal'), r.bom.where((l) => l.finame.isNotEmpty).fold(0.0, (a, l) => a + l.total)));
    bomRows.add(sumRow(t('rep.annualCapital'), r.annualCapitalCost));
    bomRows.add(sumRow(t('rep.annualEnergy'), r.annualEnergyCost));
    bomRows.add(sumRow(t('rep.annualTotal'), r.annualCapitalCost + r.annualEnergyCost));
    out.add(
      ReportTable(
        key: 'bom',
        title: t('reports.bom'),
        headers: [t('rep.category'), t('rep.description'), t('rep.code'), t('rep.unit'), t('rep.quantity'), '${t('rep.unitCost')} ($cur)', if (withFiname) 'FINAME', '${t('rep.total')} ($cur)'],
        rows: bomRows,
      ),
    );
    // ---- materials by sector (installation folders)
    if (r.bomByZone.isNotEmpty) {
      String zoneLabel(String z) => switch (z) {
        '' => t('menu.mainline'),
        'elec' => t('bom.electrical'),
        _ => switch (project.byId(z)) {
          ControlValveEntity v => v.zoneName.isNotEmpty ? v.zoneName : labels.name(z),
          final e? => e.name.isNotEmpty ? e.name : labels.name(z),
          null => labels.name(z),
        },
      };
      int order(String z) => z == '' ? 0 : (z == 'elec' ? 2 : 1);
      final zones = r.bomByZone.keys.toList()..sort((a, b) => order(a) != order(b) ? order(a).compareTo(order(b)) : zoneLabel(a).compareTo(zoneLabel(b)));
      final zr = <List<Object>>[];
      final zw = <bool>[];
      for (final z in zones) {
        final items = [...r.bomByZone[z]!]..sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
        for (final l in items) {
          zr.add([zoneLabel(z), labels.category(l.category), l.description, l.code, l.unit, RNum(l.quantity, 1), RNum(l.unitCost), RNum(l.total)]);
          zw.add(false);
        }
        zr.add([zoneLabel(z), t('rep.totalRow'), '', '', '', '', '', RNum(items.fold(0.0, (a, l) => a + l.total))]);
        zw.add(true);
      }
      out.add(
        ReportTable(
          key: 'bomZones',
          title: t('reports.bomZones'),
          headers: [t('rep.zone'), t('rep.category'), t('rep.description'), t('rep.code'), t('rep.unit'), t('rep.quantity'), '${t('rep.unitCost')} ($cur)', '${t('rep.total')} ($cur)'],
          rows: zr,
          warn: zw,
        ),
      );
    }
    // ---- quote: sale prices, labour, trenches, extras, discount, taxes
    final ps = project.proposal;
    final q = buildProposal(project, r, ps);
    final qRows = <List<Object>>[
      for (final l in q.lines) [labels.category(l.category), l.description, l.code, l.unit, RNum(l.quantity, 1), RNum(l.unitPrice), RNum(l.total)],
    ];
    void sum(String label, double v) => qRows.add([label, '', '', '', '', '', RNum(v)]);
    sum(t('proposal.materials'), q.materialsSale);
    if (q.labour != 0) sum(t('proposal.labour', {'p': fmt(ps.labourPct, 1)}), q.labour);
    if (q.trenchCost != 0) sum(t('proposal.trench', {'v': fmt(q.trenchVolume, 1)}), q.trenchCost);
    if (q.extras != 0) sum(t('proposal.extra'), q.extras);
    sum(t('proposal.subtotal'), q.subtotal);
    if (q.discount != 0) sum(t('proposal.discount', {'p': fmt(ps.discountPct, 1)}), -q.discount);
    if (q.taxes != 0) sum(t('proposal.taxes', {'p': fmt(ps.taxPct, 1)}), q.taxes);
    if (q.freight != 0) sum(t('proposal.freight'), q.freight);
    sum(t('proposal.total'), q.total);
    final financeable = q.lines.where((l) => l.finame.isNotEmpty).fold(0.0, (a, l) => a + l.total);
    if (financeable > 0) sum(t('proposal.finame'), financeable);
    if (ps.markupPct != 0) sum(t('proposal.margin'), q.materialsMargin);
    if (ps.annualBenefit > 0) {
      final pb = Payback(total: q.total, annualBenefit: ps.annualBenefit, annualCost: r.annualEnergyCost, years: project.params.termYears, rate: project.params.interestRate);
      sum(t('proposal.benefit'), ps.annualBenefit);
      sum(t('rep.annualEnergy'), r.annualEnergyCost);
      qRows.add([t('proposal.payback'), pb.simpleYears.isFinite ? fmt(pb.simpleYears, 1) : '—', '', '', '', '', '']);
      sum(t('proposal.npv', {'n': '${pb.years}', 'r': fmt(pb.rate * 100, 1)}), pb.npv);
      final irr = pb.irr;
      qRows.add([t('proposal.irr'), irr == null ? '—' : '${fmt(irr * 100, 1)} %', '', '', '', '', '']);
    }
    qRows.add([
      t('proposal.validity', {'n': '${ps.validityDays}'}),
      '',
      '',
      '',
      '',
      '',
      '',
    ]);
    if (ps.paymentTerms.trim().isNotEmpty) qRows.add([t('proposal.terms'), ps.paymentTerms.trim(), '', '', '', '', '']);
    if (ps.notes.trim().isNotEmpty) qRows.add([t('proposal.notes'), ps.notes.trim(), '', '', '', '', '']);
    if (q.unpriced > 0) {
      qRows.add([
        t('proposal.unpriced', {'n': '${q.unpriced}'}),
        '',
        '',
        '',
        '',
        '',
        '',
      ]);
    }
    out.add(
      ReportTable(
        key: 'proposal',
        title: t('reports.proposal'),
        headers: [t('rep.category'), t('rep.description'), t('rep.code'), t('rep.unit'), t('rep.quantity'), '${t('rep.unitPrice')} ($cur)', '${t('rep.total')} ($cur)'],
        rows: qRows,
        warn: [for (final row in qRows) identical(row, qRows.last) && q.unpriced > 0],
      ),
    );
    // ---- trenches of the buried pipes
    final trenches = trenchRows(project, ps);
    if (trenches.isNotEmpty) {
      final tr = <List<Object>>[
        for (final row in trenches)
          [
            t('scope.${row.scope.name}'),
            row.nominalMm > 0 ? 'DN ${fmt(row.nominalMm, 0)}' : '',
            RNum(u.lengthFromSi(row.length), 1),
            RNum(u.lengthFromSi(row.width), 2),
            RNum(u.lengthFromSi(row.depth), 2),
            RNum(u.volumeFromM3(row.volume), 2),
          ],
      ];
      tr.add([t('rep.totalRow'), '', RNum(u.lengthFromSi(trenches.fold(0.0, (a, x) => a + x.length)), 1), '', '', RNum(u.volumeFromM3(trenches.fold(0.0, (a, x) => a + x.volume)), 2)]);
      out.add(
        ReportTable(
          key: 'trench',
          title: t('reports.trench'),
          headers: [
            t('rep.category'),
            t('rep.pipe'),
            '${t('rep.length')} (${u.lengthLabel})',
            '${t('rep.width')} (${u.lengthLabel})',
            '${t('rep.depth')} (${u.lengthLabel})',
            '${t('rep.volume')} (${u.volumeLabel})',
          ],
          rows: tr,
        ),
      );
    }
    // ---- pivots / linear moves
    if (r.pivots.isNotEmpty) {
      final pv = r.pivots.values.toList();
      out.add(
        ReportTable(
          key: 'pivots',
          title: t('reports.pivots'),
          headers: [
            t('rep.pivot'),
            t('rep.type'),
            t('rep.towers'),
            '${t('rep.area')} (${u.areaLabel})',
            '${t('rep.flow')} (${u.flowLabel})',
            '${t('rep.pRequired')} (${u.pressureLabel})',
            '${t('rep.pAvail')} (${u.pressureLabel})',
            '${t('rep.hf')} (${u.pressureLabel})',
            '${t('rep.rise')} (${u.lengthLabel})',
            '${t('rep.pEnd')} (${u.pressureLabel})',
            'V (${u.velocityLabel})',
            '${t('rep.depthCycle')} (mm)',
            '${t('rep.hoursCycle')} (h)',
            '${t('rep.appRatePeak')} (mm/h)',
            t('rep.warnings'),
          ],
          rows: [
            for (final p in pv)
              [
                p.name,
                p.kind == PivotKind.pivot ? t('pivot.kindPivot') : t('pivot.kindLinear'),
                p.towerCount,
                RNum(u.areaFromSi(p.areaM2), 2),
                RNum(u.flowFromSi(p.flow), 1),
                RNum(u.pressureFromHead(p.inletHead), 1),
                p.availableHead == null ? '-' : RNum(u.pressureFromHead(p.availableHead!), 1),
                RNum(u.pressureFromHead(p.frictionLoss), 2),
                RNum(p.elevationRise, 2),
                RNum(u.pressureFromHead(p.endPressure), 1),
                RNum(u.velocityFromSi(p.inletVelocity), 2),
                RNum(p.depthPerCycleMm, 1),
                RNum(p.hoursPerCycle, 1),
                RNum(p.appRateEndPeak, 1),
                p.warnings.map(labels.warning).join('; '),
              ],
          ],
          warn: [for (final p in pv) p.warnings.isNotEmpty || p.deficit > 0.01],
        ),
      );
      final spanRows = <List<Object>>[];
      for (final p in pv) {
        for (final sp in p.spans) {
          spanRows.add([
            p.name,
            sp.index,
            RNum(u.lengthFromSi(sp.rStart), 0),
            RNum(u.lengthFromSi(sp.rEnd), 0),
            sp.sprinklers,
            RNum(sp.flowPerSprinkler / m3sPerLph, 0),
            RNum(u.pressureFromHead(sp.pressure), 1),
            sp.nozzle.isEmpty ? '-' : sp.nozzle,
          ]);
        }
      }
      if (spanRows.isNotEmpty) {
        out.add(
          ReportTable(
            key: 'pivotSpans',
            title: t('reports.pivotSpans'),
            headers: [
              t('rep.pivot'),
              t('rep.span'),
              '${t('rep.rFrom')} (${u.lengthLabel})',
              '${t('rep.rTo')} (${u.lengthLabel})',
              t('rep.sprinklers'),
              '${t('rep.qSprinkler')} (L/h)',
              '${t('rep.pMid')} (${u.pressureLabel})',
              t('rep.nozzleSuggested'),
            ],
            rows: spanRows,
          ),
        );
      }
    }
    // ---- machines: nozzle chart, timer chart, corner arm, prescription, electrical
    if (r.mechanised.isNotEmpty) out.addAll(mechanisedTables(project, r, labels));
    // ---- valve wiring
    final el = r.electrical;
    if (el != null && (el.runs.isNotEmpty || el.controllers.isNotEmpty)) {
      final cat = project.catalog;
      String wireName(String? id) => cat.wire(id)?.name ?? '-';
      out.add(
        ReportTable(
          key: 'electrical',
          title: t('reports.electrical'),
          headers: [
            t('rep.zone'),
            t('rep.controller'),
            t('rep.station'),
            '${t('rep.route')} (${u.lengthLabel})',
            '${t('rep.wireLength')} (${u.lengthLabel})',
            t('rep.stationWire'),
            t('rep.commonWire'),
            t('rep.openTogether'),
            '${t('rep.solenoidV')} (V)',
            t('rep.warnings'),
          ],
          rows: [
            for (final run in el.runs)
              [
                run.zoneName,
                labels.name(run.controllerId),
                run.station == 0 ? t('elec.masterTag') : run.station,
                RNum(u.lengthFromSi(run.routeM), 0),
                RNum(u.lengthFromSi(run.wireM), 0),
                wireName(run.stationWireId),
                wireName(run.commonWireId),
                run.openTogether,
                RNum(run.volts, 1),
                run.ok ? '' : labels.warning('elec_voltage'),
              ],
            for (final d in el.controllers)
              [
                t('elec.commonRow'),
                labels.name(d.controllerId),
                '${d.used}/${d.stations}',
                RNum(u.lengthFromSi(d.commonRouteM), 0),
                RNum(u.lengthFromSi(d.commonWireM), 0),
                '-',
                wireName(d.commonWireId),
                d.maxOpen,
                '${fmt(d.peakCurrentA, 2)} A',
                d.overloaded ? labels.warning('elec_stations') : '',
              ],
          ],
          warn: [for (final run in el.runs) !run.ok, for (final d in el.controllers) d.overloaded],
        ),
      );
    }
    // ---- flushing
    if (r.flushing.isNotEmpty) {
      out.add(
        ReportTable(
          key: 'flushing',
          title: t('reports.flushing'),
          headers: [
            t('rep.zone'),
            t('rep.tapes'),
            '${t('rep.flow')} (${u.flowLabel})',
            '${t('rep.pDown')} (${u.pressureLabel})',
            t('rep.pRequired'),
            '${t('rep.pEnd')} (${u.pressureLabel})',
            'V (${u.velocityLabel})',
            t('rep.vFlush'),
          ],
          rows: [
            for (final f in r.flushing)
              [
                f.zoneName,
                f.tapeCount,
                RNum(u.flowFromSi(f.flow), 1),
                RNum(u.pressureFromHead(f.requiredDownstreamHead), 1),
                RNum(u.pressureFromHead(f.requiredUpstreamHead), 1),
                RNum(u.pressureFromHead(f.minEndHead), 2),
                RNum(u.velocityFromSi(f.maxVelocity), 2),
                RNum(u.velocityFromSi(f.flushingVelocity), 2),
              ],
          ],
          warn: [for (final f in r.flushing) !f.converged],
        ),
      );
    }
    // ---- surge (water hammer)
    if (r.surge.isNotEmpty) {
      out.add(
        ReportTable(
          key: 'surge',
          title: t('reports.surge'),
          headers: [
            t('rep.context'),
            t('rep.entity'),
            t('rep.pipe'),
            'V (${u.velocityLabel})',
            '${t('rep.celerity')} (m/s)',
            '${t('rep.surge')} (${u.pressureLabel})',
            '${t('rep.pStatic')} (${u.pressureLabel})',
            '${t('rep.pTotal')} (${u.pressureLabel})',
            t('rep.pn'),
            t('rep.tCritical'),
          ],
          rows: [
            for (final s in r.surge)
              [
                s.context,
                labels.name(s.entityId),
                s.pipeName,
                RNum(u.velocityFromSi(s.velocity), 2),
                RNum(s.celerity, 0),
                RNum(u.pressureFromHead(s.surgeHead), 1),
                RNum(u.pressureFromHead(s.maxStaticHead), 1),
                RNum(u.pressureFromHead(s.totalHead), 1),
                RNum(u.pressureFromHead(s.rating), 0),
                RNum(s.criticalTime, 2),
              ],
          ],
          warn: [for (final s in r.surge) s.exceeds],
        ),
      );
    }
  }
  // ---- crop water / schedule (available with areas)
  final crops = cropWaterRequirements(project, results);
  if (crops.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'crop',
        title: t('reports.crop'),
        headers: [
          t('rep.area'),
          'ETc (${u.depthPerDayLabel})',
          '${t('rep.raw')} (${u.depthLabel})',
          t('rep.interval'),
          '${t('rep.netEvent')} (${u.depthLabel})',
          '${t('rep.grossEvent')} (${u.depthLabel})',
          '${t('rep.rate')} (${u.depthRateLabel})',
          t('rep.hoursEvent'),
          '${t('rep.volume')} (${u.volumeLabel})',
          t('rep.hoursDay'),
        ],
        rows: [
          for (final c in crops)
            [
              c.name,
              RNum(u.depthFromMm(c.etcMmDay), 2),
              RNum(u.depthFromMm(c.rawMm), 2),
              RNum(c.intervalDays, 0),
              RNum(u.depthFromMm(c.netDepthMm), 2),
              RNum(u.depthFromMm(c.grossDepthMm), 2),
              RNum(u.depthFromMm(c.applicationRateMmH), 2),
              RNum(c.hoursPerEvent, 2),
              RNum(u.volumeFromM3(c.volumePerEventM3), 1),
              RNum(c.dailyHours, 2),
            ],
        ],
      ),
    );
    final prog = buildControllerProgram(project, results, days: 7);
    if (prog.entries.isNotEmpty) {
      String hhmm(double h) {
        final hh = h.floor() % 24, mm = ((h - h.floor()) * 60).round();
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }

      out.add(
        ReportTable(
          key: 'schedule',
          title: t('reports.schedule'),
          headers: [t('sch.date'), t('sch.flow'), t('sch.zones'), t('sch.start'), t('sch.end'), t('sch.duration'), '${t('rep.flow')} (${u.flowLabel})'],
          rows: [
            for (final e in prog.entries)
              [e.day.toIso8601String().substring(0, 10), e.flowName, e.zones.join(' + '), hhmm(e.startHour), hhmm(e.endHour), RNum(e.durationHours, 2), RNum(u.flowFromSi(e.flow), 1)],
          ],
        ),
      );
    }
  }
  // ---- requirement by crop, month and growth stage (areas with a crop of
  // the table; available without results)
  final reqTables = areaRequirementTables(project, results);
  if (reqTables.isNotEmpty) {
    final rows = <List<Object>>[];
    final warn = <bool>[];
    final totals = <List<Object>>[];
    for (final e in reqTables.entries) {
      final a = project.byId(e.key);
      final name = a == null || a.name.isEmpty ? labels.name(e.key) : a.name;
      for (final row in e.value.monthly) {
        if (row.cropDays == 0) continue;
        final d = math.max(1, row.end.difference(row.start).inDays + 1);
        rows.add([
          name,
          t(row.cropKey),
          t('mon.${row.start.month}'),
          row.cropDays,
          RNum(u.depthFromMm(row.etoMm), 1),
          RNum(row.kc, 2),
          RNum(row.kr, 2),
          RNum(u.depthFromMm(row.etcLocMm), 1),
          RNum(u.depthFromMm(row.rainMm), 1),
          RNum(u.depthFromMm(row.effectiveRainMm), 1),
          RNum(u.depthFromMm(row.netMm), 1),
          RNum(row.leachingFraction * 100, 1),
          RNum(u.depthFromMm(row.grossMm), 1),
          RNum(u.depthFromMm(row.grossMm / d), 2),
          RNum(u.depthFromMm(row.rawMm), 1),
          row.intervalDays,
          RNum(u.depthFromMm(row.grossPerEventMm), 1),
          row.hoursPerEvent == null ? '-' : RNum(row.hoursPerEvent!, 2),
          RNum(u.volumeFromM3(row.volumeM3), 0),
        ]);
        warn.add(row.warnings.any((w) => w != 'req_no_application_rate'));
      }
      final tt = e.value.areaTotals;
      totals.add([
        name,
        RNum(u.depthFromMm(tt.etoMm), 0),
        RNum(u.depthFromMm(tt.etcLocMm), 0),
        RNum(u.depthFromMm(tt.effectiveRainMm), 0),
        RNum(u.depthFromMm(tt.netMm), 0),
        RNum(u.depthFromMm(tt.grossMm), 0),
        RNum(u.volumeFromM3(tt.volumeM3), 0),
        RNum(u.depthFromMm(tt.peakGrossMmDay), 2),
        RNum(u.volumeFromM3(tt.peakDailyVolumeM3), 1),
      ]);
    }
    out.add(
      ReportTable(
        key: 'requirement',
        title: t('reports.requirement'),
        headers: [
          t('rep.area'),
          t('props.crop'),
          t('req.month'),
          t('req.cropDays'),
          'ETo (${u.depthLabel})',
          'Kc',
          'Kr',
          'ETc (${u.depthLabel})',
          '${t('req.rain')} (${u.depthLabel})',
          '${t('req.effRain')} (${u.depthLabel})',
          '${t('req.net')} (${u.depthLabel})',
          '${t('req.lr')} (%)',
          '${t('req.gross')} (${u.depthLabel})',
          '${t('req.gross')} (${u.depthPerDayLabel})',
          '${t('rep.raw')} (${u.depthLabel})',
          t('rep.interval'),
          '${t('rep.grossEvent')} (${u.depthLabel})',
          t('rep.hoursEvent'),
          '${t('rep.volume')} (${u.volumeLabel})',
        ],
        rows: rows,
        warn: warn,
      ),
    );
    out.add(
      ReportTable(
        key: 'requirementTotals',
        title: t('reports.requirementTotals'),
        headers: [
          t('rep.area'),
          'ETo (${u.depthLabel})',
          'ETc (${u.depthLabel})',
          '${t('req.effRain')} (${u.depthLabel})',
          '${t('req.net')} (${u.depthLabel})',
          '${t('req.gross')} (${u.depthLabel})',
          '${t('rep.volume')} (${u.volumeLabel})',
          '${t('req.peakGross')} (${u.depthPerDayLabel})',
          '${t('req.peakVolume')} (${u.volumeLabel}/d)',
        ],
        rows: totals,
      ),
    );
  }
  // ---- construction schedule (available without results)
  final works = scheduleTasks(project, project.proposal);
  if (works.isNotEmpty) {
    final total = works.fold(0, (m, w) => math.max(m, w.end));
    out.add(
      ReportTable(
        key: 'works',
        title: t('reports.works'),
        headers: [t('works.task'), t('rep.quantity'), t('rep.unit'), t('works.perDay'), t('works.days'), t('works.start'), t('works.end'), t('works.bar')],
        rows: [
          for (final w in works) [t('works.${w.key}'), RNum(w.quantity, w.unit == 'un' ? 0 : 1), w.unit, RNum(w.perDay, 0), w.days, w.start + 1, w.end, RBar(w.start, w.end, total)],
          [
            t('works.total', {'n': '${project.proposal.crews}'}),
            '',
            '',
            '',
            total,
            1,
            total,
            '',
          ],
        ],
      ),
    );
  }
  // ---- environmental licensing category (informative; available without results)
  final lic = licensingRows(project);
  if (lic.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'licensing',
        title: t('reports.licensing'),
        headers: [t('req.method'), '${t('rep.area')} (ha)', t('lic.category'), t('lic.limits')],
        rows: [
          for (final (method, ha, cat) in lic) [t('req.method.$method'), RNum(ha, 2), cat, t('lic.limits.$method')],
          [t('lic.project'), RNum(lic.fold(0.0, (a, r) => a + r.$2), 2), lic.map((r) => r.$3).reduce((a, b) => a.compareTo(b) >= 0 ? a : b), t('lic.note')],
        ],
      ),
    );
  }
  // ---- water requirements (available without results)
  final reqs = areaRequirements(project, results);
  if (reqs.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'water',
        title: t('reports.water'),
        headers: [
          t('rep.area'),
          u.areaLabel,
          '${t('rep.grossDepth')} (${u.depthPerDayLabel})',
          '${t('rep.volume')} (${u.volumeLabel}/d)',
          '${t('rep.flow')} (${u.flowLabel})',
          '${t('rep.rate')} (${u.depthRateLabel})',
          t('rep.hoursDay'),
        ],
        rows: [
          for (final a in reqs)
            [
              a.name,
              RNum(u.areaFromSi(a.areaM2), 3),
              RNum(u.depthFromMm(a.grossDepthMm), 2),
              RNum(u.volumeFromM3(a.dailyVolumeM3), 1),
              RNum(u.flowFromSi(a.flow), 1),
              RNum(u.depthFromMm(a.precipitationMmH), 2),
              RNum(a.hoursPerDay, 2),
            ],
        ],
      ),
    );
  }
  // ---- alternatives saved for comparison
  if (project.scenarios.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'scenarios',
        title: t('reports.scenarios'),
        headers: [t('scn.name'), for (final k in scenarioMetricKeys) scenarioMetricHeader(k, project, t)],
        rows: [
          for (final sc in project.scenarios) [sc.name, for (final k in scenarioMetricKeys) scenarioMetricCell(k, sc.metrics[k], u)],
        ],
      ),
    );
  }
  // ---- review: comments and revisions (available without results)
  final comments = project.entities.whereType<CommentEntity>().toList();
  if (comments.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'comments',
        title: t('reports.comments'),
        headers: ['#', t('props.date'), t('props.author'), t('props.text'), t('props.resolved')],
        rows: [
          for (var i = 0; i < comments.length; i++) [i + 1, comments[i].date, comments[i].author, comments[i].text, comments[i].resolved ? '✓' : ''],
        ],
        warn: [for (final cm in comments) !cm.resolved],
      ),
    );
  }
  final revisions = project.entities.whereType<RevisionCloudEntity>().toList()..sort((a, b) => a.date != b.date ? a.date.compareTo(b.date) : a.revision.compareTo(b.revision));
  if (revisions.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'revisions',
        title: t('reports.revisions'),
        headers: [t('props.revision'), t('props.date'), t('props.description')],
        rows: [
          for (final rv in revisions) [rv.revision, rv.date, rv.description],
        ],
      ),
    );
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

/// Column title of a scenario figure, with its unit.
String scenarioMetricHeader(String key, Project project, Translate t) {
  final u = project.params.units;
  final cur = project.params.currency;
  final unit = switch (key) {
    'capital' || 'annualEnergy' || 'annualTotal' => cur,
    'peakFlow' => u.flowLabel,
    'pumpHead' || 'pMin' || 'pMax' => u.pressureLabel,
    'euMin' || 'cuMin' => '%',
    'mainlineM' || 'zonePipeM' => u.lengthLabel,
    _ => '',
  };
  return unit.isEmpty ? t('scn.$key') : '${t('scn.$key')} ($unit)';
}

/// Cell of a scenario figure in the display units ('-' when unknown).
Object scenarioMetricCell(String key, double? v, Units u) {
  if (v == null) return '-';
  return switch (key) {
    'capital' || 'annualEnergy' || 'annualTotal' => RNum(v, 0),
    'peakFlow' => RNum(u.flowFromSi(v), 1),
    'pumpHead' || 'pMin' || 'pMax' => RNum(u.pressureFromHead(v), 1),
    'euMin' || 'cuMin' => RNum(v, 1),
    'mainlineM' || 'zonePipeM' => RNum(u.lengthFromSi(v), 0),
    _ => v.round(),
  };
}

/// Tables of the mechanised machines: the nozzle chart and the timer chart
/// of every machine, its corner arm banks, its variable-rate prescription
/// and its electrical design (tower by tower).
List<ReportTable> mechanisedTables(Project project, DesignResults r, ReportLabels labels) {
  final t = labels.t;
  final u = project.params.units;
  String nameOf(String id) {
    final e = project.byId(id);
    if (e != null && e.name.isNotEmpty) return e.name;
    final pr = r.pivots[id];
    return pr != null && pr.name.isNotEmpty ? pr.name : labels.name(id);
  }

  final out = <ReportTable>[];
  final machines = r.mechanised.values.toList();
  // nozzle chart
  final pkgRows = <List<Object>>[];
  final pkgWarn = <bool>[];
  for (final m in machines) {
    final name = nameOf(m.pivotId);
    for (final o in m.package.outlets) {
      final nozzle = o.plugged ? t('mech.plugged') : (o.nozzle.isNotEmpty ? o.nozzle : (o.nozzleNumber > 0 ? '#${o.nozzleNumber} (${fmt(o.nozzleDiameterMm, 2)} mm)' : '-'));
      pkgRows.add([
        name,
        o.number,
        o.span,
        RNum(u.lengthFromSi(o.distanceM), 1),
        RNum(u.lengthFromSi(o.spacingM), 2),
        RNum(o.requiredFlow / m3sPerLph, 0),
        RNum(o.deliveredFlow / m3sPerLph, 0),
        RNum(u.pressureFromHead(o.pipePressureM), 1),
        RNum(u.pressureFromHead(o.nozzlePressureM), 1),
        o.regulatorM > 0 ? RNum(u.pressureFromHead(o.regulatorM), 1) : '-',
        nozzle,
        o.dropLengthM > 0 ? RNum(u.lengthFromSi(o.dropLengthM), 2) : '-',
      ]);
      pkgWarn.add(!o.plugged && o.requiredFlow > 0 && (o.deliveredFlow / o.requiredFlow - 1).abs() > 0.05);
    }
  }
  if (pkgRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pivotPackage',
        title: t('reports.pivotPackageTable'),
        headers: [
          t('rep.pivot'),
          t('mech.outlet'),
          t('rep.span'),
          '${t('mech.distance')} (${u.lengthLabel})',
          '${t('mech.spacing')} (${u.lengthLabel})',
          '${t('mech.qRequired')} (L/h)',
          '${t('mech.qDelivered')} (L/h)',
          '${t('mech.pPipe')} (${u.pressureLabel})',
          '${t('mech.pNozzle')} (${u.pressureLabel})',
          '${t('mech.regulator')} (${u.pressureLabel})',
          t('mech.nozzle'),
          '${t('mech.drop')} (${u.lengthLabel})',
        ],
        rows: pkgRows,
        warn: pkgWarn,
      ),
    );
  }
  // timer chart and the machine summary
  final timerRows = <List<Object>>[];
  for (final m in machines) {
    final p = m.package;
    final name = nameOf(m.pivotId);
    for (final row in p.timer) {
      timerRows.add([name, RNum(row.timerPct, 0), RNum(row.hours, 1), RNum(u.depthFromMm(row.depthMm), 1), RNum(u.lengthFromSi(row.speedMPerMin), 2)]);
    }
  }
  if (timerRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pivotTimer',
        title: t('reports.pivotTimer'),
        headers: [t('rep.pivot'), '${t('mech.timer')} (%)', '${t('mech.hoursRev')} (h)', '${t('mech.depth')} (${u.depthLabel})', '${t('mech.speed')} (${u.lengthLabel}/min)'],
        rows: timerRows,
      ),
    );
  }
  final sumRows = <List<Object>>[
    for (final m in machines)
      [
        nameOf(m.pivotId),
        m.package.sprinklerCount,
        RNum(u.flowFromSi(m.package.designFlow), 1),
        RNum(u.flowFromSi(m.package.deliveredFlow), 1),
        RNum(u.pressureFromHead(m.package.requiredInletHeadM), 1),
        RNum(u.pressureFromHead(m.package.endPressureM), 1),
        m.package.regulatorM > 0 ? RNum(u.pressureFromHead(m.package.regulatorM), 1) : '-',
        m.package.endGunFlow > 0 ? RNum(u.flowFromSi(m.package.endGunFlow), 1) : '-',
        m.package.boosterPowerKw > 0 ? RNum(m.package.boosterPowerKw, 2) : '-',
        RNum(u.lengthFromSi(m.package.speedAt100MPerMin), 2),
        RNum(m.package.hoursAt100, 1),
        RNum(u.depthFromMm(m.package.depthAt100Mm), 1),
        m.package.warnings.map(labels.warning).join('; '),
      ],
  ];
  if (sumRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pivotPackageSummary',
        title: t('reports.pivotPackageSummary'),
        headers: [
          t('rep.pivot'),
          t('rep.sprinklers'),
          '${t('mech.qDesign')} (${u.flowLabel})',
          '${t('mech.qDelivered')} (${u.flowLabel})',
          '${t('rep.pRequired')} (${u.pressureLabel})',
          '${t('rep.pEnd')} (${u.pressureLabel})',
          '${t('mech.regulator')} (${u.pressureLabel})',
          '${t('mech.gunFlow')} (${u.flowLabel})',
          '${t('mech.booster')} (kW)',
          '${t('mech.speed')} (${u.lengthLabel}/min)',
          '${t('mech.hoursRev')} (h)',
          '${t('mech.depth')} (${u.depthLabel})',
          t('rep.warnings'),
        ],
        rows: sumRows,
        warn: [for (final m in machines) m.package.warnings.isNotEmpty],
      ),
    );
  }
  // corner arm
  final armRows = <List<Object>>[];
  for (final m in machines) {
    final a = m.cornerArm;
    if (a == null || a.steps.isEmpty) continue;
    final name = nameOf(m.pivotId);
    for (final b in a.banks) {
      armRows.add([name, b.index + 1, RNum(u.lengthFromSi(b.startM), 1), RNum(u.lengthFromSi(b.endM), 1), RNum(u.flowFromSi(b.designFlow), 2), RNum(b.onFraction * 100, 0)]);
    }
    armRows.add([name, t('mech.addedArea'), RNum(u.areaFromSi(a.addedAreaM2), 2), '', '', '']);
    armRows.add([name, t('mech.peakFlow'), RNum(u.flowFromSi(a.peakFlow), 1), t('mech.minFlow'), RNum(u.flowFromSi(a.minFlow), 1), '']);
    armRows.add([name, t('mech.tipSpeed'), RNum(a.maxTipSpeedRatio, 2), t('mech.shortfall'), RNum(u.lengthFromSi(math.max(a.maxShortfallM, a.maxOverrunM)), 1), '']);
  }
  if (armRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'cornerArm',
        title: t('reports.cornerArm'),
        headers: [t('rep.pivot'), t('mech.bank'), '${t('rep.rFrom')} (${u.lengthLabel})', '${t('rep.rTo')} (${u.lengthLabel})', '${t('mech.qDesign')} (${u.flowLabel})', '${t('mech.onTime')} (%)'],
        rows: armRows,
      ),
    );
  }
  // variable-rate prescription
  final vriRows = <List<Object>>[];
  final vriWarn = <bool>[];
  for (final m in machines) {
    final v = m.vri;
    if (v == null) continue;
    final name = nameOf(m.pivotId);
    for (final row in v.rows) {
      vriRows.add([
        name,
        RNum(row.startDeg, 1),
        RNum(row.endDeg, 1),
        RNum(row.timerPct, 0),
        RNum(u.depthFromMm(row.depthMm), 1),
        RNum(u.depthFromMm(row.targetMm), 1),
        row.bankDutyPct.isEmpty ? '-' : row.bankDutyPct.map((d) => fmt(d, 0)).join(' / '),
      ]);
      vriWarn.add(row.limit != 0);
    }
  }
  if (vriRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'vri',
        title: t('reports.vri'),
        headers: [
          t('rep.pivot'),
          '${t('mech.start')} (°)',
          '${t('mech.end')} (°)',
          '${t('mech.timer')} (%)',
          '${t('mech.depth')} (${u.depthLabel})',
          '${t('mech.target')} (${u.depthLabel})',
          '${t('mech.bankDuty')} (%)',
        ],
        rows: vriRows,
        warn: vriWarn,
      ),
    );
  }
  // electrical design of the machines
  final elRows = <List<Object>>[];
  final elWarn = <bool>[];
  for (final m in machines) {
    final e = m.electrical;
    if (e == null) continue;
    final name = nameOf(m.pivotId);
    for (final tw in e.towers) {
      elRows.add([
        name,
        tw.index,
        RNum(u.lengthFromSi(tw.radiusM), 0),
        RNum(u.lengthFromSi(tw.cableM), 0),
        RNum(tw.spanCurrentA, 1),
        RNum(tw.volts, 0),
        RNum(tw.runningDropPct, 2),
        RNum(tw.startingDropPct, 2),
      ]);
      elWarn.add(false);
    }
    elRows.add([name, t('mech.cable'), '${fmt(e.cableMm2, 1)} mm²', t('mech.supplyCable'), '${fmt(e.supplyCableMm2, 1)} mm²', '', '', '']);
    elRows.add([name, t('mech.connected'), '${fmt(e.connectedKw, 2)} kW', t('mech.kva'), '${fmt(e.runningKva, 1)} kVA', '${fmt(e.runningCurrentA, 1)} A', '', '']);
    elRows.add([name, t('mech.generator'), '${fmt(e.generatorKva, 1)} kVA', t('mech.averagePower'), '${fmt(e.averagePowerKw, 2)} kW', '', RNum(e.maxRunningDropPct, 2), RNum(e.maxStartingDropPct, 2)]);
    elWarn.addAll([false, false, e.warnings.isNotEmpty]);
  }
  if (elRows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pivotElectrical',
        title: t('reports.pivotElectrical'),
        headers: [
          t('rep.pivot'),
          t('mech.tower'),
          '${t('mech.distance')} (${u.lengthLabel})',
          '${t('mech.cableLength')} (${u.lengthLabel})',
          '${t('mech.current')} (A)',
          '${t('mech.volts')} (V)',
          '${t('mech.dropRun')} (%)',
          '${t('mech.dropStart')} (%)',
        ],
        rows: elRows,
        warn: elWarn,
      ),
    );
  }
  return out;
}

/// Category (A, B or C) of an irrigation project for the environmental
/// licensing of Brazilian Resolution CONAMA 284/2001 (annex): by the
/// irrigated area of the property and the method — sprinkler below 100 ha,
/// up to 1 000 ha, beyond; micro-irrigation below 500 ha, up to 1 000 ha,
/// beyond; surface below 50 ha, up to 100 ha, beyond. Informative: the
/// validity of the resolution and the rules of each state agency must be
/// checked.
String conamaCategory(String method, double hectares) {
  final (a, b) = switch (method) {
    'localized' => (500.0, 1000.0),
    'surface' => (50.0, 100.0),
    _ => (100.0, 1000.0),
  };
  return hectares < a ? 'A' : (hectares <= b ? 'B' : 'C');
}

/// Irrigated area (ha) by method of the project — the irrigated areas by
/// their method and the machines as sprinkler irrigation — with the CONAMA
/// 284/2001 category of each; empty without irrigated areas or machines.
List<(String, double, String)> licensingRows(Project project) {
  final ha = <String, double>{};
  for (final e in project.entities) {
    if (e is AreaEntity && e.points.length >= 3) ha[e.irrigationMethod] = (ha[e.irrigationMethod] ?? 0) + e.area / 10000;
    // a machine on a field already drawn as an area counts once
    if (e is PivotEntity && !project.entities.any((a) => a is AreaEntity && a.points.length >= 3 && pointInPolygon(e.center, a.points))) {
      ha['sprinkler'] = (ha['sprinkler'] ?? 0) + polygonArea(e.outline()).abs() / 10000;
    }
  }
  return [
    for (final m in const ['sprinkler', 'localized', 'surface'])
      if ((ha[m] ?? 0) > 0) (m, ha[m]!, conamaCategory(m, ha[m]!)),
  ];
}
