/// Operation and maintenance plan of the project (1.6.0): the manual the
/// owner gets with the system, built from the design — the system as
/// built, its start-up (filling, flushing, the pressure test at 1.5 times
/// the working pressure of each line within the class of its pipes, the
/// first run of every zone), the sheet to check the pressures of every zone
/// in the field against the design, the flushing of the laterals with the
/// flows and pressures of the flushing analysis, the cleaning of the
/// filters by the rise of their pressure loss, chlorination with the
/// injection rate of every system flow, the preparation for the off-season,
/// pumps, valves and controller, the schedule of every task by component
/// over the months of the irrigation season, the self-monitoring of the
/// water permit and the spare parts.
///
/// Sources of the figures: the pressure test of buried pressure pipe at
/// 1.5 times the working pressure (AWWA C605 for PVC); the flushing
/// velocity of the laterals of the design parameters (0.3 m/s by default,
/// ASABE EP405.1); the chlorine injection rate q = Q·C / (10·P) (Q in m³/h,
/// C in mg/L, P the available chlorine of the product in %, q in L/h: the
/// mass of chlorine a flow carries over the chlorine a litre of product
/// holds); the effectiveness of chlorine below pH 7.5, where the
/// hypochlorous acid prevails (Nakayama & Bucks 1986, Trickle Irrigation
/// for Crop Production).
library;

import 'dart:math' as math;

import '../io/tech_doc.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../units.dart';
import 'permit.dart';
import 'report_tables.dart';
import 'results.dart';

/// Injection rate (L/h) of a chlorine product with [productPct] % of
/// available chlorine that gives [doseMgL] mg/L in a flow of [flowM3h].
double chlorineInjectionLph({required double flowM3h, required double doseMgL, required double productPct}) => productPct <= 0 ? 0 : flowM3h * doseMgL / (10 * productPct);

/// Test pressure of a line whose highest working pressure is [workingM]
/// and whose weakest pipe is of class [ratingM] (m): 1.5 times the working
/// pressure, at most the class (0 = class unknown).
double testPressure(double workingM, double ratingM) {
  final p = 1.5 * workingM;
  return ratingM > 0 ? math.min(p, ratingM) : p;
}

/// The operation and maintenance plan of [p] with its design results [r].
TechDocument buildOmPlan(Project p, DesignResults? r, ReportLabels labels) {
  final t = labels.t;
  final u = p.params.units;
  final s = p.deliverables.om;
  final cat = p.catalog;
  final m = p.meta;
  final needResults = TechNote(t('prb.mem.needDesign'), warning: true);
  final sections = <TechSection>[];
  String nameOf(Entity e) => e.name.isNotEmpty ? e.name : labels.name(e.id);
  // an item by its name, else its catalogue item, else its kind and id
  String itemName(Entity e) {
    if (e.name.isNotEmpty) return e.name;
    final spec = switch (e) {
      PumpEntity x => cat.pump(x.pumpSpecId)?.name,
      MiscHydraulicEntity x => cat.valve(x.valveSpecId)?.name,
      _ => null,
    };
    return spec != null && spec.isNotEmpty ? spec : labels.name(e.id);
  }

  final supplies = p.entities.whereType<WaterSupplyEntity>().toList();
  final pumps = p.entities.whereType<PumpEntity>().toList();
  final devices = p.entities.whereType<MiscHydraulicEntity>().toList();
  List<MiscHydraulicEntity> devicesOf(ValveKind k) => [
    for (final d in devices)
      if (cat.valve(d.valveSpecId)?.kind == k) d,
  ];
  final filters = devicesOf(ValveKind.filter);
  final prvs = devicesOf(ValveKind.prv);
  final airValves = devicesOf(ValveKind.airRelease);
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  final controllers = p.entities.whereType<ControllerEntity>().toList();
  final emitterModels = <String>{
    for (final e in p.entities)
      ...switch (e) {
        OutletEntity o => [?cat.outlet(o.outletSpecId)?.name],
        SpraylineEntity sl => [?cat.outlet(sl.outletSpecId)?.name],
        TapeEntity tp => [?cat.tape(tp.tapeSpecId)?.name],
        _ => const <String>[],
      },
  }.toList()..sort();
  // the irrigation season: the months with abstraction in the permit study
  final permit = buildPermitStudy(p, r, cropName: labels.category);
  final season = <int>{for (final x in permit.sources) ...x.months}.toList()..sort();
  final seasonMonths = season.isEmpty ? [for (var i = 1; i <= 12; i++) i] : season;
  String monthList(List<int> ms) => ms.length == 12 ? t('prb.om.allYear') : ms.map((x) => t('prb.mon.$x')).join(', ');

  // ---- 1. the system
  sections.add(
    TechSection(t('prb.om.system'), [
      TechFields([
        (t('tool.supply'), supplies.map(nameOf).join(', ')),
        (t('prb.om.pumps'), pumps.map(itemName).join('; ')),
        (t('prb.om.filters'), filters.map(itemName).join('; ')),
        (t('prb.om.zones'), '${valves.length}'),
        (t('prb.om.flows'), '${p.systemFlows.length}'),
        (t('prb.om.emitters'), emitterModels.join(', ')),
        (t('prb.om.controllers'), controllers.map((c) => '${nameOf(c)} (${c.stations})').join(', ')),
        (t('prb.om.season'), monthList(seasonMonths)),
      ]),
      TechParagraph(t('prb.om.systemText')),
    ], key: 'system'),
  );

  // ---- 2. start-up
  final testRows = <List<Object>>[];
  if (r != null) {
    for (final scope in HydraulicScope.values) {
      var work = 0.0, rating = double.infinity;
      for (final seg in [for (final z in r.zones.values) ...z.pipes, for (final f in r.systemFlows) ...f.pipes]) {
        final e = p.byId(seg.entityId);
        if (e is! PipeEntity || e.scope != scope) continue;
        work = math.max(work, math.max(seg.pressureStart, seg.pressureEnd));
        if (seg.pressureRating > 0) rating = math.min(rating, seg.pressureRating);
      }
      if (work <= 0) continue;
      final rated = rating.isFinite ? rating : 0.0;
      testRows.add([t('scope.${scope.name}'), RNum(u.pressureFromHead(work), 1), rated > 0 ? RNum(u.pressureFromHead(rated), 0) : '-', RNum(u.pressureFromHead(testPressure(work, rated)), 1)]);
    }
  }
  sections.add(
    TechSection(t('prb.om.startup'), [
      TechBullets([for (var i = 1; i <= 7; i++) t('prb.om.start.$i')], numbered: true),
      if (testRows.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omTest',
            title: t('prb.om.testTable'),
            headers: [t('prb.mem.use'), '${t('prb.om.workP')} (${u.pressureLabel})', '${t('rep.pn')} (${u.pressureLabel})', '${t('prb.om.testP')} (${u.pressureLabel})'],
            rows: testRows,
          ),
          note: t('prb.om.testNote'),
        ),
    ], key: 'startup'),
  );

  // ---- 3. pressure check sheet of every zone
  if (r == null || r.zones.isEmpty) {
    sections.add(TechSection(t('prb.om.pressures'), [if (r == null) needResults else TechParagraph(t('prb.mem.noZones'))], key: 'pressures'));
  } else {
    final zones = r.zones.values.toList();
    final dutyRows = [
      for (final f in r.systemFlows)
        for (final x in f.supplies) [f.name, x.name, RNum(u.flowFromSi(x.flow), 1), RNum(u.pressureFromHead(x.head), 1), '', ''],
    ];
    sections.add(
      TechSection(t('prb.om.pressures'), [
        TechParagraph(t('prb.om.pressuresText')),
        TechTable(
          ReportTable(
            key: 'omPressures',
            title: t('prb.om.pressures'),
            headers: [
              t('rep.zone'),
              '${t('rep.flow')} (${u.flowLabel})',
              '${t('rep.pDown')} (${u.pressureLabel})',
              '${t('prb.om.emitterP')} (${u.pressureLabel})',
              '${t('prb.om.measuredValve')} (${u.pressureLabel})',
              '${t('prb.om.measuredEnd')} (${u.pressureLabel})',
              '${t('prb.om.measuredFlow')} (${u.flowLabel})',
              t('prb.om.okCol'),
            ],
            rows: [
              for (final z in zones)
                [
                  z.zoneName,
                  RNum(u.flowFromSi(z.totalFlow), 1),
                  RNum(u.pressureFromHead(z.downstreamHead), 1),
                  '${fmt(u.pressureFromHead(z.minOutletPressure), 1)} – ${fmt(u.pressureFromHead(z.maxOutletPressure), 1)}',
                  '',
                  '',
                  '',
                  '',
                ],
            ],
          ),
        ),
        if (dutyRows.isNotEmpty)
          TechTable(
            ReportTable(
              key: 'omDuty',
              title: t('prb.om.dutyTable'),
              headers: [
                t('rep.flowName'),
                t('rep.supply'),
                '${t('rep.q')} (${u.flowLabel})',
                '${t('rep.pAvailable')} (${u.pressureLabel})',
                '${t('prb.om.measuredFlow')} (${u.flowLabel})',
                '${t('prb.om.measuredP')} (${u.pressureLabel})',
              ],
              rows: dutyRows,
            ),
          ),
      ], key: 'pressures'),
    );
  }

  // ---- 4. flushing
  sections.add(
    TechSection(t('prb.om.flushing'), [
      TechParagraph(t('prb.om.flushingText', {'v': fmt(u.velocityFromSi(p.params.flushingVelocity), 2), 'vu': u.velocityLabel})),
      if (r != null && r.flushing.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omFlushing',
            title: t('reports.flushing'),
            headers: [
              t('rep.zone'),
              t('rep.tapes'),
              '${t('rep.flow')} (${u.flowLabel})',
              '${t('rep.pRequired')} (${u.pressureLabel})',
              '${t('rep.pEnd')} (${u.pressureLabel})',
              'V (${u.velocityLabel})',
            ],
            rows: [
              for (final f in r.flushing)
                [
                  f.zoneName,
                  f.tapeCount,
                  RNum(u.flowFromSi(f.flow), 1),
                  RNum(u.pressureFromHead(f.requiredUpstreamHead), 1),
                  RNum(u.pressureFromHead(f.minEndHead), 2),
                  RNum(u.velocityFromSi(f.maxVelocity), 2),
                ],
            ],
            warn: [for (final f in r.flushing) !f.converged],
          ),
        ),
    ], key: 'flushing'),
  );

  // ---- 5. filters
  final filterRows = <List<Object>>[];
  for (final f in filters) {
    var loss = 0.0;
    for (final fl in r?.systemFlows ?? const <SystemFlowResult>[]) {
      for (final d in fl.devices) {
        if (d.entityId == f.id) loss = math.max(loss, d.headLoss);
      }
    }
    filterRows.add([
      itemName(f),
      cat.valve(f.valveSpecId)?.name ?? '-',
      r == null ? '-' : RNum(u.pressureFromHead(loss), 2),
      r == null ? '+${fmt(u.pressureFromHead(s.filterDeltaM), 2)}' : RNum(u.pressureFromHead(loss + s.filterDeltaM), 2),
    ]);
  }
  sections.add(
    TechSection(t('prb.om.filtersTitle'), [
      TechParagraph(t('prb.om.filtersText', {'d': fmt(u.pressureFromHead(s.filterDeltaM), 2), 'u': u.pressureLabel})),
      if (filterRows.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omFilters',
            title: t('prb.om.filtersTitle'),
            headers: [t('prb.om.filter'), t('prb.model'), '${t('prb.om.cleanLoss')} (${u.pressureLabel})', '${t('prb.om.cleanAt')} (${u.pressureLabel})'],
            rows: filterRows,
          ),
        )
      else
        TechNote(t('prb.om.noFilters'), warning: true),
    ], key: 'filters'),
  );

  // ---- 6. chlorination and acid
  final clRows = <List<Object>>[];
  if (r != null) {
    for (final f in r.systemFlows) {
      final q = f.totalFlow * 3600;
      if (q <= 0) continue;
      clRows.add([
        f.name,
        RNum(q, 1),
        RNum(chlorineInjectionLph(flowM3h: q, doseMgL: s.chlorineContinuousMgL, productPct: s.chlorineProductPct), 2),
        RNum(chlorineInjectionLph(flowM3h: q, doseMgL: s.chlorineShockMgL, productPct: s.chlorineProductPct), 2),
      ]);
    }
  }
  sections.add(
    TechSection(t('prb.om.chemical'), [
      TechParagraph(t('prb.om.chemicalText')),
      TechFormula(t('prb.f.chlorineExpr'), where: [('q', t('prb.f.qInj')), ('Q', t('prb.f.qm3h')), ('C', t('prb.f.dose')), ('P', t('prb.f.product'))]),
      if (clRows.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omChlorine',
            title: t('prb.om.chlorineTable', {'p': fmt(s.chlorineProductPct, 1)}),
            headers: [t('rep.flowName'), 'Q (m³/h)', '${t('prb.om.continuous')} ${fmt(s.chlorineContinuousMgL, 1)} mg/L (L/h)', '${t('prb.om.shock')} ${fmt(s.chlorineShockMgL, 1)} mg/L (L/h)'],
            rows: clRows,
          ),
        )
      else if (r == null)
        needResults,
      TechNote(t('prb.om.chemicalSafety'), warning: true),
    ], key: 'chemical'),
  );

  // ---- 7. off-season
  final off = [
    for (var i = 1; i <= 12; i++)
      if (!seasonMonths.contains(i)) i,
  ];
  sections.add(
    TechSection(t('prb.om.offSeason'), [
      TechParagraph(off.isEmpty ? t('prb.om.noOffSeason') : t('prb.om.offSeasonText', {'m': monthList(off)})),
      TechBullets([for (var i = 1; i <= 7; i++) t('prb.om.off.$i')]),
    ], key: 'offSeason'),
  );

  // ---- 8. pumps, valves, controller
  final pumpRows = <List<Object>>[];
  for (final pu in pumps) {
    final spec = cat.pump(pu.pumpSpecId);
    DeviceResult? duty;
    for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
      for (final d in f.devices) {
        if (d.entityId == pu.id && (duty == null || d.flow > duty.flow)) duty = d;
      }
    }
    pumpRows.add([
      itemName(pu),
      spec?.name ?? '-',
      duty == null ? '-' : RNum(u.flowFromSi(duty.flow), 1),
      duty == null ? '-' : RNum(u.pressureFromHead(duty.pumpHead), 1),
      (spec?.powerKw ?? 0) > 0 ? RNum(spec!.powerKw, 1) : '-',
      pu.hourMeter ? t('prb.yes') : t('prb.no'),
    ]);
  }
  sections.add(
    TechSection(t('prb.om.equipment'), [
      if (pumpRows.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omPumps',
            title: t('prb.om.pumps'),
            headers: [t('tool.pump'), t('prb.model'), '${t('rep.q')} (${u.flowLabel})', '${t('rep.pumpHead')} (${u.pressureLabel})', '${t('prb.power')} (kW)', t('prb.hourMeter')],
            rows: pumpRows,
          ),
        ),
      TechBullets([for (var i = 1; i <= 4; i++) t('prb.om.pump.$i')]),
      if (prvs.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'omPrv',
            title: t('prb.om.prvTable'),
            headers: [t('prb.om.device'), t('prb.model'), '${t('prb.om.setting')} (${u.pressureLabel})'],
            rows: [
              for (final d in prvs) [itemName(d), cat.valve(d.valveSpecId)?.name ?? '-', RNum(u.pressureFromHead(d.settingM), 1)],
            ],
          ),
        ),
      TechBullets([
        t('prb.om.valve.1'),
        airValves.isEmpty ? t('prb.om.valve.2none') : t('prb.om.valve.2', {'n': '${airValves.length}'}),
        t('prb.om.valve.3'),
        t('prb.om.controller.1'),
        t('prb.om.controller.2'),
      ]),
    ], key: 'equipment'),
  );

  // ---- 9. schedule of the maintenance by component
  final first = seasonMonths.first, last = seasonMonths.last;
  final offFirst = off.isEmpty ? last : off.first;
  // (component, task, frequency, months)
  final tasks = <(String, String, String, Set<int>)>[
    (t('prb.om.c.filters'), t('prb.om.t.filters'), t('prb.om.f.irrigation'), {...seasonMonths}),
    (t('prb.om.c.laterals'), t('prb.om.t.flush'), t('prb.om.f.monthly'), {...seasonMonths}),
    (t('prb.om.c.mainline'), t('prb.om.t.flushMain'), t('prb.om.f.season'), {first, last}),
    (t('prb.om.c.zones'), t('prb.om.t.pressures'), t('prb.om.f.monthly'), {...seasonMonths}),
    (t('prb.om.c.emitters'), t('prb.om.t.emitters'), t('prb.om.f.quarterly'), {for (var i = 0; i < seasonMonths.length; i += 3) seasonMonths[i]}),
    (t('prb.om.c.chemical'), t('prb.om.t.chemical'), t('prb.om.f.water'), {...seasonMonths}),
    (t('prb.om.c.pumps'), t('prb.om.t.pumps'), t('prb.om.f.monthly'), {...seasonMonths}),
    (t('prb.om.c.pumps'), t('prb.om.t.pumpsYear'), t('prb.om.f.yearly'), {offFirst}),
    (t('prb.om.c.valves'), t('prb.om.t.valves'), t('prb.om.f.start'), {first}),
    (t('prb.om.c.controller'), t('prb.om.t.controller'), t('prb.om.f.start'), {first}),
    (t('prb.om.c.meter'), t('prb.om.t.meter'), t('prb.om.f.monthlyAll'), {for (var i = 1; i <= 12; i++) i}),
    (t('prb.om.c.electrical'), t('prb.om.t.electrical'), t('prb.om.f.yearly'), {offFirst}),
  ];
  sections.add(
    TechSection(t('prb.om.schedule'), [
      TechTable(
        ReportTable(
          key: 'omSchedule',
          title: t('prb.om.schedule'),
          headers: [t('prb.om.component'), t('prb.om.task'), t('prb.om.frequency'), for (var i = 1; i <= 12; i++) t('prb.mon.$i')],
          rows: [
            for (final (c, k, f, ms) in tasks) [c, k, f, for (var i = 1; i <= 12; i++) ms.contains(i) ? 'X' : ''],
          ],
        ),
        note: t('prb.om.scheduleNote', {'m': monthList(seasonMonths)}),
      ),
    ], key: 'schedule'),
  );

  // ---- 10. self-monitoring of the permit
  sections.add(
    TechSection(t('prb.permit.monitoring'), [
      TechParagraph(t('prb.om.monitoringText')),
      for (final src in permit.sources)
        for (final tb in permitSourceTables(src, p.deliverables.permit, t).where((x) => x.key.startsWith('permitLog'))) TechTable(tb, note: t('prb.permit.logNote')),
      if (permit.sources.isEmpty) TechNote(t('prb.warn.permit_no_source'), warning: true),
    ], key: 'monitoring'),
  );

  // ---- 11. spare parts
  if (r == null) {
    sections.add(TechSection(t('prb.om.spares'), [needResults], key: 'spares'));
  } else {
    // the parts that wear (not the filters, meters and regulators themselves)
    const kept = {'bom.outlets', 'bom.tapes', 'bom.valves', 'bom.fittings', 'bom.risers', 'bom.takeoffs'};
    final rows = <List<Object>>[];
    for (final l in r.bom) {
      if (!kept.contains(l.category) || l.quantity <= 0) continue;
      final spare = math.max(1.0, (l.quantity * s.sparesPct / 100).ceilToDouble());
      rows.add([labels.category(l.category), l.description, l.unit, RNum(l.quantity, 0), RNum(spare, 0)]);
    }
    sections.add(
      TechSection(t('prb.om.spares'), [
        TechParagraph(t('prb.om.sparesText', {'p': fmt(s.sparesPct, 1)})),
        if (rows.isNotEmpty)
          TechTable(ReportTable(key: 'omSpares', title: t('prb.om.spares'), headers: [t('rep.category'), t('rep.description'), t('rep.unit'), t('prb.om.installed'), t('prb.om.spare')], rows: rows)),
      ], key: 'spares'),
    );
  }
  return TechDocument(
    key: 'om',
    title: t('prb.om.title'),
    subtitle: [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].where((x) => x.isNotEmpty).join(' · '),
    sections: sections,
  );
}
