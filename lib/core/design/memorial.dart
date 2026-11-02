/// Descriptive and calculation memorial of the project (1.6.0): a document
/// built from the project alone, without the AI assistant — the same
/// project gives the same text — with fixed sections: identification,
/// objective, irrigated areas and crops, climate and water requirement,
/// water source and abstraction, design criteria, the formulas the program
/// uses (with the meaning of every symbol and their sources), the zones,
/// the network, pumping and energy, operation, the checks, the materials,
/// the designer's notes and the references. The designer adds an objective
/// and closing notes (MemorialSettings); the rest comes from the drawing,
/// its settings and the design results. Exported as PDF or Markdown (to
/// edit), and its sections go into the document packages as they are.
///
/// The formulas are those of the engine: Hazen-Williams, Darcy-Weisbach
/// with the Swamee-Jain friction factor (laminar 64/Re), Scobey and
/// Manning (hydraulics/friction.dart); the emitter law q = k·H^x
/// (hydraulics/emitter.dart); the uniformity of Christiansen (1942), the
/// low-quarter distribution uniformity and the emission uniformity of
/// Keller & Karmeli (1974) (hydraulics/uniformity.dart); the Joukowsky
/// surge with the wave celerity of the pipe (hydraulics/water_hammer.dart);
/// the water requirement of FAO-56 (Allen et al. 1998) with the localized
/// reduction factor of Keller & Bliesner (1990) and the leaching
/// requirement of FAO-29 (Ayers & Westcot 1985) (irrigation_requirement.dart
/// and area_water.dart).
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../io/tech_doc.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../units.dart';
import 'agronomy.dart';
import 'area_requirement.dart';
import 'area_water.dart';
import 'design_check.dart';
import 'permit.dart';
import 'proposal.dart';
import 'report_tables.dart';
import 'results.dart';
import 'soils.dart';

/// Number of the references of the memorial (`prb.ref.1`…).
const memorialReferenceCount = 10;

/// The memorial of [p] with its design results [r] (null: the sections of
/// the results say the design has not been run), in the language of
/// [labels].
TechDocument buildMemorial(Project p, DesignResults? r, ReportLabels labels) {
  final t = labels.t;
  final u = p.params.units;
  final m = p.meta;
  final prm = p.params;
  final cur = prm.currency;
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3) a,
  ];
  final totalHa = areas.fold(0.0, (s, a) => s + a.area / 10000);
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  final supplies = p.entities.whereType<WaterSupplyEntity>().toList();
  final emitters = r != null && r.zones.isNotEmpty
      ? r.zones.values.fold<int>(0, (a, z) => a + z.emitterCount)
      : p.entities.fold<int>(0, (a, e) => a + (e is SpraylineEntity ? e.outletCount : (e is OutletEntity ? 1 : 0)));
  String name(AreaEntity a) => a.name.isNotEmpty ? a.name : labels.name(a.id);
  String cropOf(AreaEntity a) => a.cropKey.isNotEmpty ? labels.category(a.cropKey) : (a.crop.trim().isEmpty ? '-' : a.crop.trim());
  final methods = {for (final a in areas) areaIrrigationMethod(a)}.toList()..sort();
  final crops = {
    for (final a in areas)
      if (cropOf(a) != '-') cropOf(a),
  }.toList()..sort();
  final needResults = TechNote(t('prb.mem.needDesign'), warning: true);
  final sections = <TechSection>[];
  // what runs in a system flow: the zone of a valve, a machine, a station
  String zoneName(String id) => switch (p.byId(id)) {
    ControlValveEntity v when v.zoneName.isNotEmpty => v.zoneName,
    final e? when e.name.isNotEmpty => e.name,
    _ => labels.name(id),
  };

  // ---- 1. identification
  final g = m.georef;
  final (lat, lon) = g == null ? (null, null) : g.toLatLon(p.bounds.isEmpty ? 0 : p.bounds.center.x, p.bounds.isEmpty ? 0 : p.bounds.center.y);
  sections.add(
    TechSection(t('prb.mem.identification'), [
      TechFields([
        (t('dlg.project'), m.name),
        (t('dlg.client'), m.client),
        (t('dlg.site'), m.site),
        (t('dlg.designer'), m.designer),
        (t('prb.mem.location'), lat == null ? t('prb.mem.noGeoref') : '${dmsText(lat, 'N', 'S')}, ${dmsText(lon!, t('prb.east'), t('prb.west'))} (SIRGAS 2000)'),
        (t('prb.mem.irrigatedArea'), '${fmt(totalHa, 2)} ha'),
        (t('prb.mem.counts'), t('prb.mem.countsValue', {'a': '${areas.length}', 'z': '${valves.length}', 'e': '$emitters', 's': '${supplies.length}'})),
        (t('prb.mem.methods'), methods.map((x) => t('req.method.$x')).join(', ')),
      ]),
    ], key: 'identification'),
  );

  // ---- 2. objective
  final objective = p.deliverables.memorial.objective.trim();
  sections.add(
    TechSection(t('prb.mem.objective'), [
      if (objective.isNotEmpty) TechParagraph(objective),
      TechParagraph(
        t('prb.mem.objectiveText', {
          'm': methods.isEmpty ? t('prb.mem.pressurised') : methods.map((x) => t('req.method.$x').toLowerCase()).join(', '),
          'ha': fmt(totalHa, 2),
          'c': crops.isEmpty ? '-' : crops.join(', '),
          's': m.site.isEmpty ? (m.name.isEmpty ? '-' : m.name) : m.site,
        }),
      ),
    ], key: 'objective'),
  );

  // ---- 3. areas and crops
  if (areas.isNotEmpty) {
    final rows = <List<Object>>[];
    for (final a in areas) {
      final b = areaWaterBasis(p, a);
      final soil = soilTable[a.soilKey];
      rows.add([
        name(a),
        RNum(a.area / 10000, 2),
        t('req.method.${areaIrrigationMethod(a)}'),
        cropOf(a),
        soil == null ? '-' : t(soil.key),
        RNum(a.awcMmPerM, 0),
        RNum(a.rootDepthM, 2),
        RNum(a.mad, 2),
        RNum(b.kr, 2),
        RNum(b.pw, 2),
        RNum(a.efficiency * 100, 0),
        t('prb.mem.source.${b.source.name}'),
        b.month == null ? '-' : t('mon.${b.month}'),
        RNum(u.depthFromMm(b.grossMmDay), 2),
      ]);
    }
    sections.add(
      TechSection(t('prb.mem.areas'), [
        TechParagraph(t('prb.mem.areasText')),
        TechTable(
          ReportTable(
            key: 'memAreas',
            title: t('prb.mem.areas'),
            headers: [
              t('rep.area'),
              '${t('rep.area')} (ha)',
              t('req.method'),
              t('props.crop'),
              t('prb.mem.soil'),
              'AWC (mm/m)',
              'Zr (m)',
              'p',
              'Kr',
              'Pw',
              'Ea (%)',
              t('prb.mem.needSource'),
              t('area.designMonth'),
              '${t('req.gross')} (${u.depthPerDayLabel})',
            ],
            rows: rows,
          ),
        ),
      ], key: 'areas'),
    );
  }

  // ---- 4. climate and water requirement
  final climate = p.climate;
  final reqTables = areaRequirementTables(p, r);
  final all = buildReportTables(project: p, results: r, labels: labels, includeMessages: false);
  ReportTable? table(String key) => all.where((x) => x.key == key).firstOrNull;
  sections.add(
    TechSection(t('prb.mem.climate'), [
      TechParagraph(
        climate == null
            ? t('prb.mem.climateTyped')
            : t('prb.mem.climateSite', {
                'src': [
                  labels.has('clim.src.${climate.source}') ? t('clim.src.${climate.source}') : climate.source,
                  if (climate.firstYear > 0 && climate.lastYear >= climate.firstYear) '${climate.firstYear}–${climate.lastYear}',
                ].join(', '),
                'lat': fmt(climate.latitudeDeg, 3),
                'lon': fmt(climate.longitudeDeg, 3),
              }),
      ),
      if (climate != null)
        TechTable(
          ReportTable(
            key: 'memClimate',
            title: t('prb.mem.climateTable'),
            headers: ['', for (var i = 1; i <= 12; i++) t('prb.mon.$i'), t('prb.year')],
            rows: [
              ['ETo (mm/d)', for (final v in climate.etoMmDay) RNum(v, 2), RNum(climate.etoMmDay.fold(0.0, (a, b) => a + b) / 12, 2)],
              ['${t('req.rain')} (mm)', for (final v in climate.rainMm) RNum(v, 0), RNum(climate.rainMm.fold(0.0, (a, b) => a + b), 0)],
            ],
          ),
        ),
      TechFormula(t('prb.f.etcExpr'), where: [('ETo', t('prb.f.eto')), ('Kc', t('prb.f.kc')), ('Kr', t('prb.f.kr'))], source: t('prb.src.etc')),
      TechFormula(t('prb.f.nibExpr'), where: [('Pe', t('prb.f.pe')), ('Ea', t('prb.f.ea')), ('LR', t('prb.f.lr'))], source: t('prb.src.nib')),
      TechFormula(t('prb.f.rawExpr'), where: [('AWC', t('prb.f.awc')), ('Zr', t('prb.f.zr')), ('p', t('prb.f.p')), ('Pw', t('prb.f.pw')), ('T', t('prb.f.interval'))], source: t('prb.src.raw')),
      if (reqTables.isNotEmpty && table('requirementTotals') != null) TechTable(table('requirementTotals')!),
      if (table('water') != null) TechTable(table('water')!),
    ], key: 'climate'),
  );

  // ---- 5. water source and abstraction
  final permit = buildPermitStudy(p, r, cropName: labels.category);
  sections.add(
    TechSection(t('prb.mem.source'), [
      if (permit.sources.isEmpty) TechNote(t('prb.warn.permit_no_source'), warning: true),
      for (final s in permit.sources)
        TechFields([
          (t('tool.supply'), s.supply.name.isNotEmpty ? s.supply.name : s.supply.id),
          (t('prb.permit.kind'), t('prb.kind.${s.info.kind}')),
          (t('prb.permit.waterBody'), s.info.waterBody),
          (t('prb.permit.maxFlow'), '${fmt(s.maxFlowM3h, 1)} m³/h'),
          (t('prb.permit.annualVolume'), '${fmt(s.annualM3, 0)} m³'),
          (t('prb.permit.months'), [for (final x in s.months) t('prb.mon.$x')].join(', ')),
          (t('prb.mem.supplyHead'), s.supply.calculatePressure ? t('prb.mem.headCalculated') : '${fmt(u.pressureFromHead(s.supply.designHeadM), 1)} ${u.pressureLabel}'),
        ]),
      if (permit.sources.isNotEmpty) TechParagraph(t('prb.mem.sourceText')),
    ], key: 'source'),
  );

  // ---- 6. design criteria
  final friction = switch (prm.frictionMethod) {
    FrictionMethod.hazenWilliams => t('dlg.hw'),
    FrictionMethod.darcyWeisbach => t('dlg.dw'),
    FrictionMethod.scobey => t('dlg.scobey'),
    FrictionMethod.manning => t('dlg.manning'),
  };
  sections.add(
    TechSection(t('prb.mem.criteria'), [
      TechFields([
        (t('dlg.frictionFormula'), friction),
        (t('dlg.waterTemp'), fmt(prm.waterTempC, 0)),
        (t('dlg.vLateral'), fmt(prm.maxLateralVelocity, 2)),
        (t('dlg.vZone'), fmt(prm.maxZoneVelocity, 2)),
        (t('dlg.vMain'), fmt(prm.maxMainlineVelocity, 2)),
        (
          t('dlg.minorMethod'),
          !prm.applyMinorLosses ? t('prb.no') : (prm.minorLossMethod == MinorLossMethod.fittings ? t('dlg.minorByFittings') : '${fmt(prm.minorLossPct, 1)} ${t('dlg.minorByPct')}'),
        ),
        (t('dlg.zoneVar'), fmt(prm.maxZoneVariationPct, 1)),
        (t('dlg.epp'), '${prm.emittersPerPlant}'),
        (t('dlg.sizingMethod'), prm.sizingMethod == SizingMethod.lp ? t('dlg.lp') : t('dlg.greedy')),
        (t('dlg.terrainMethod'), t(prm.terrainMethod.name == 'tin' ? 'terrain.tin' : 'terrain.idw')),
        (t('dlg.checkSurge'), prm.checkSurge ? '${t('prb.yes')} (${t('dlg.closure')}: ${fmt(prm.valveClosureTimeS, 1)})' : t('prb.no')),
        (t('dlg.flushV'), fmt(prm.flushingVelocity, 2)),
        (t('dlg.interest'), fmt(prm.interestRate, 3)),
        (t('dlg.term'), '${prm.termYears}'),
        (t('dlg.energyCost', {'c': cur}), fmt(prm.powerCostPerKwh, 3)),
        (t('dlg.pumpEff'), fmt(prm.pumpEfficiency, 2)),
        (t('dlg.hoursMain'), fmt(prm.hoursPerYear, 0)),
        (t('dlg.hoursZone'), fmt(prm.zoneHoursPerYear, 0)),
      ]),
      TechParagraph(t('prb.mem.criteriaText')),
    ], key: 'criteria'),
  );

  // ---- 7. formulas
  final frictionFormula = switch (prm.frictionMethod) {
    FrictionMethod.hazenWilliams => TechFormula(
      t('prb.f.hwExpr'),
      where: [('hf', t('prb.f.hf')), ('L', t('prb.f.l')), ('Q', t('prb.f.q')), ('C', t('prb.f.c')), ('D', t('prb.f.d'))],
      source: t('prb.src.hw'),
    ),
    FrictionMethod.darcyWeisbach => TechFormula(
      t('prb.f.dwExpr'),
      where: [('f', t('prb.f.f')), ('V', t('prb.f.v')), ('g', t('prb.f.g')), ('ε', t('prb.f.eps')), ('Re', t('prb.f.re'))],
      source: t('prb.src.dw'),
    ),
    FrictionMethod.scobey => TechFormula(t('prb.f.scobeyExpr'), where: [('Ks', t('prb.f.ks')), ('L', t('prb.f.l')), ('Q', t('prb.f.q')), ('D', t('prb.f.d'))], source: t('prb.src.scobey')),
    FrictionMethod.manning => TechFormula(t('prb.f.manningExpr'), where: [('n', t('prb.f.n')), ('L', t('prb.f.l')), ('Q', t('prb.f.q')), ('D', t('prb.f.d'))], source: t('prb.src.manning')),
  };
  sections.add(
    TechSection(t('prb.mem.formulas'), [
      frictionFormula,
      TechFormula(t('prb.f.velocityExpr'), where: [('V', t('prb.f.v')), ('Q', t('prb.f.q')), ('D', t('prb.f.d'))]),
      TechFormula(t('prb.f.emitterExpr'), where: [('q', t('prb.f.qe')), ('k', t('prb.f.k')), ('H', t('prb.f.h')), ('x', t('prb.f.x'))]),
      TechFormula(t('prb.f.cuExpr'), where: [('qi', t('prb.f.qi')), ('qm', t('prb.f.qmean')), ('n', t('prb.f.count'))], source: t('prb.src.cu')),
      TechFormula(t('prb.f.duExpr'), where: [('q25', t('prb.f.q25'))], source: t('prb.src.du')),
      TechFormula(t('prb.f.euExpr'), where: [('Cv', t('prb.f.cv')), ('e', t('prb.f.epp')), ('qmin', t('prb.f.qmin'))], source: t('prb.src.eu')),
      TechFormula(t('prb.f.powerExpr'), where: [('P', t('prb.f.power')), ('ρ', t('prb.f.rho')), ('H', t('prb.f.head')), ('η', t('prb.f.eta'))]),
      if (prm.checkSurge)
        TechFormula(t('prb.f.surgeExpr'), where: [('a', t('prb.f.a')), ('K', t('prb.f.kw')), ('E', t('prb.f.e')), ('e', t('prb.f.wall')), ('ΔV', t('prb.f.dv'))], source: t('prb.src.surge')),
    ], key: 'formulas'),
  );

  // ---- 8. zones
  if (r == null || r.zones.isEmpty) {
    sections.add(TechSection(t('prb.mem.zones'), [r == null ? needResults : TechParagraph(t('prb.mem.noZones'))], key: 'zones'));
  } else {
    final zones = r.zones.values.toList();
    sections.add(
      TechSection(t('prb.mem.zones'), [
        TechTable(
          ReportTable(
            key: 'memZones',
            title: t('prb.mem.zones'),
            headers: [
              t('rep.zone'),
              t('rep.emitters'),
              '${t('rep.flow')} (${u.flowLabel})',
              '${t('rep.pRequired')} (${u.pressureLabel})',
              '${t('rep.pMin')} (${u.pressureLabel})',
              '${t('rep.pMax')} (${u.pressureLabel})',
              t('rep.varActual'),
              t('rep.varAllow'),
              'CU %',
              'EU %',
            ],
            rows: [
              for (final z in zones)
                [
                  z.zoneName,
                  z.emitterCount,
                  RNum(u.flowFromSi(z.totalFlow), 1),
                  RNum(u.pressureFromHead(z.requiredUpstreamHead), 1),
                  RNum(u.pressureFromHead(z.minOutletPressure), 1),
                  RNum(u.pressureFromHead(z.maxOutletPressure), 1),
                  RNum(z.actualVariationPct, 1),
                  RNum(z.allowedVariationPct, 1),
                  RNum(z.uniformity.cu, 1),
                  RNum(z.uniformity.eu, 1),
                ],
            ],
            warn: [for (final z in zones) !z.withinWindow],
          ),
        ),
        TechParagraph(t('prb.mem.zonesText', {'n': '${zones.length}', 'ok': '${zones.where((z) => z.withinWindow).length}'})),
      ], key: 'zones'),
    );
  }

  // ---- 9. network
  if (r == null) {
    sections.add(TechSection(t('prb.mem.network'), [needResults], key: 'network'));
  } else {
    // pipes by catalogue item: length and the largest velocity and flow
    final byPipe = <String, (String, double, double, double)>{};
    for (final seg in [for (final z in r.zones.values) ...z.pipes, for (final f in r.systemFlows) ...f.pipes]) {
      final scope = p.byId(seg.entityId) is PipeEntity ? (p.byId(seg.entityId) as PipeEntity).scope.name : 'lateral';
      final k = '${seg.pipeName}|$scope';
      final old = byPipe[k];
      byPipe[k] = (scope, (old?.$2 ?? 0) + seg.length, math.max(old?.$3 ?? 0, seg.velocity), math.max(old?.$4 ?? 0, seg.flow.abs()));
    }
    final keys = byPipe.keys.toList()..sort();
    final mainRows = [
      for (final f in r.systemFlows)
        for (final s in f.supplies) [f.name, s.name, RNum(u.flowFromSi(s.flow), 1), RNum(u.pressureFromHead(s.head), 1), RNum(u.pressureFromHead(math.max(0, s.requiredHead)), 1)],
    ];
    sections.add(
      TechSection(t('prb.mem.network'), [
        TechTable(
          ReportTable(
            key: 'memPipes',
            title: t('prb.mem.pipes'),
            headers: [t('rep.pipe'), t('prb.mem.use'), '${t('rep.length')} (${u.lengthLabel})', 'Vmax (${u.velocityLabel})', 'Qmax (${u.flowLabel})'],
            rows: [
              for (final k in keys)
                [
                  k.split('|').first,
                  t(byPipe[k]!.$1 == 'lateral' ? 'prb.mem.useLateral' : 'scope.${byPipe[k]!.$1}'),
                  RNum(u.lengthFromSi(byPipe[k]!.$2), 0),
                  RNum(u.velocityFromSi(byPipe[k]!.$3), 2),
                  RNum(u.flowFromSi(byPipe[k]!.$4), 1),
                ],
            ],
          ),
        ),
        if (mainRows.isNotEmpty)
          TechTable(
            ReportTable(
              key: 'memMainline',
              title: t('prb.mem.duty'),
              headers: [t('rep.flowName'), t('rep.supply'), '${t('rep.q')} (${u.flowLabel})', '${t('rep.pAvailable')} (${u.pressureLabel})', '${t('rep.pRequired')} (${u.pressureLabel})'],
              rows: mainRows,
            ),
          ),
      ], key: 'network'),
    );
  }

  // ---- 10. pumping and energy
  final pumps = p.entities.whereType<PumpEntity>().toList();
  if (pumps.isNotEmpty || r != null) {
    final rows = <List<Object>>[];
    for (final pu in pumps) {
      final spec = p.catalog.pump(pu.pumpSpecId);
      DeviceResult? duty;
      for (final f in r?.systemFlows ?? const <SystemFlowResult>[]) {
        for (final d in f.devices) {
          if (d.entityId == pu.id && (duty == null || d.flow > duty.flow)) duty = d;
        }
      }
      final eta = duty != null && spec != null ? spec.efficiencyAt(duty.flow, speed: duty.speedRatio) * pu.motorEfficiency : prm.pumpEfficiency;
      final kw = duty == null ? 0.0 : waterDensity * gravity * duty.flow * duty.pumpHead / math.max(eta, 0.05) / 1000;
      rows.add([
        pu.name.isNotEmpty ? pu.name : (spec?.name ?? pu.id),
        spec?.name ?? '-',
        duty == null ? '-' : RNum(u.flowFromSi(duty.flow), 1),
        duty == null ? '-' : RNum(u.pressureFromHead(duty.pumpHead), 1),
        RNum(eta * 100, 0),
        duty == null ? '-' : RNum(kw, 2),
        (spec?.powerKw ?? 0) > 0 ? RNum(spec!.powerKw, 1) : '-',
      ]);
    }
    final energy = r?.annualEnergyCost ?? 0;
    sections.add(
      TechSection(t('prb.mem.pumping'), [
        if (rows.isNotEmpty)
          TechTable(
            ReportTable(
              key: 'memPumps',
              title: t('prb.mem.pumping'),
              headers: [
                t('tool.pump'),
                t('prb.model'),
                '${t('rep.q')} (${u.flowLabel})',
                '${t('rep.pumpHead')} (${u.pressureLabel})',
                'η (%)',
                '${t('prb.mem.absorbed')} (kW)',
                '${t('prb.power')} (kW)',
              ],
              rows: rows,
            ),
          ),
        if (r != null)
          TechFields([(t('rep.annualEnergy'), '$cur ${fmt(energy, 2)}'), if (prm.powerCostPerKwh > 0) (t('prb.mem.energyKwh'), '${fmt(energy / prm.powerCostPerKwh, 0)} kWh')])
        else
          needResults,
      ], key: 'pumping'),
    );
  }

  // ---- 11. operation
  final prog = buildControllerProgram(p, r, days: 7);
  sections.add(
    TechSection(t('prb.mem.operation'), [
      if (p.systemFlows.isEmpty) TechParagraph(t('prb.mem.allTogether')),
      if (p.systemFlows.isNotEmpty)
        TechTable(
          ReportTable(
            key: 'memFlows',
            title: t('prb.mem.flows'),
            headers: [t('rep.flowName'), t('sch.zones'), t('prb.mem.interval'), t('sch.duration')],
            rows: [
              for (final f in p.systemFlows) [f.name, f.valveIds.map(zoneName).join(', '), prog.intervalDays[f.id] ?? 1, RNum(prog.perFlowHours[f.id] ?? f.durationHours, 2)],
            ],
          ),
        ),
      if (prog.entries.isNotEmpty) TechParagraph(t('prb.mem.operationText', {'h': fmt(prog.maxDailyHours, 1)})),
      for (final w in prog.warnings) TechNote(labels.warning(w), warning: true),
    ], key: 'operation'),
  );

  // ---- 12. checks and messages
  final check = runDesignCheck(p);
  final designMessages = r == null ? 0 : r.messages.length + r.zones.values.fold<int>(0, (a, z) => a + z.warnings.length) + r.systemFlows.fold<int>(0, (a, f) => a + f.warnings.length);
  final messages = <String>[
    for (final i in check.issues.where((i) => i.severity != CheckSeverity.info)) '${labels.has('check.${i.code}') ? t('check.${i.code}') : i.code}${i.value.isEmpty ? '' : ' (${i.value})'}',
    if (r != null) ...[
      ...r.messages.map(labels.warning),
      for (final z in r.zones.values) ...z.warnings.map((w) => '${z.zoneName}: ${labels.warning(w)}'),
      for (final f in r.systemFlows) ...f.warnings.map((w) => '${f.name}: ${labels.warning(w)}'),
    ],
  ];
  sections.add(
    TechSection(t('prb.mem.checks'), [
      TechParagraph(t('prb.mem.checksText', {'e': '${check.errors}', 'w': '${check.warnings}', 'm': '$designMessages'})),
      if (messages.isNotEmpty)
        TechBullets(
          messages.length > 40
              ? [
                  ...messages.take(40),
                  t('prb.mem.more', {'n': '${messages.length - 40}'}),
                ]
              : messages,
        ),
      if (messages.isEmpty && r != null) TechNote(t('prb.mem.noMessages')),
      if (r == null) needResults,
    ], key: 'checks'),
  );

  // ---- 13. materials
  if (r == null) {
    sections.add(TechSection(t('prb.mem.materials'), [needResults], key: 'materials'));
  } else {
    final byCat = <String, (int, double)>{};
    for (final l in r.bom) {
      final old = byCat[l.category];
      byCat[l.category] = ((old?.$1 ?? 0) + 1, (old?.$2 ?? 0) + l.total);
    }
    final q = buildProposal(p, r, p.proposal);
    sections.add(
      TechSection(t('prb.mem.materials'), [
        TechTable(
          ReportTable(
            key: 'memBom',
            title: t('prb.mem.bomSummary'),
            headers: [t('rep.category'), t('prb.mem.items'), '${t('rep.total')} ($cur)'],
            rows: [
              for (final e in byCat.entries) [labels.category(e.key), e.value.$1, RNum(e.value.$2, 2)],
              [t('rep.totalRow'), r.bom.length, RNum(r.capitalCost, 2)],
            ],
          ),
        ),
        TechFields([
          (t('rep.annualCapital'), '$cur ${fmt(r.annualCapitalCost, 2)}'),
          (t('rep.annualEnergy'), '$cur ${fmt(r.annualEnergyCost, 2)}'),
          if (!p.proposal.isDefault) (t('proposal.total'), '$cur ${fmt(q.total, 2)}'),
        ]),
        if (q.unpriced > 0) TechNote(t('proposal.unpriced', {'n': '${q.unpriced}'}), warning: true),
      ], key: 'materials'),
    );
  }

  // ---- 14. notes
  final notes = p.deliverables.memorial.notes.trim();
  if (notes.isNotEmpty || m.notes.trim().isNotEmpty) {
    sections.add(TechSection(t('prb.mem.notes'), [if (m.notes.trim().isNotEmpty) TechParagraph(m.notes.trim()), if (notes.isNotEmpty) TechParagraph(notes)], key: 'notes'));
  }

  // ---- 15. references
  sections.add(
    TechSection(t('prb.mem.references'), [
      TechBullets([for (var i = 1; i <= memorialReferenceCount; i++) t('prb.ref.$i')]),
    ], key: 'references'),
  );
  return TechDocument(
    key: 'memorial',
    title: t('prb.mem.title'),
    subtitle: [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].where((x) => x.isNotEmpty).join(' · '),
    sections: sections,
  );
}
