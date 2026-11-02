/// Report tables of the machines, electrical and water analyses of 1.6.0
/// (`agb_design.dart`): the pump house circuits and its supply, the
/// pivots' supply, the solar array and its energy, the water analysis with
/// its filtration and treatment, and the two-wire paths. They go with every
/// other table to the reports panel and to every report export.
library;

import '../model/agb_settings.dart';
import '../model/project.dart';
import '../units.dart';
import 'report_tables.dart';
import 'results.dart';
import 'water_quality.dart';

/// Keys of the tables, in order.
const agbTableKeys = ['pumpHouse', 'pumpHouseSupply', 'pivotSupply', 'solar', 'solarMonths', 'water', 'waterTreatment', 'twoWire', 'travellers', 'furrows'];

/// The tables of [results] (none without results or with every part off).
List<ReportTable> agbReportTables(Project project, DesignResults? results, ReportLabels labels) {
  final a = results?.agb;
  if (a == null) return const [];
  final t = labels.t;
  final u = project.params.units;
  final out = <ReportTable>[];
  String len(double m) => fmt(u.lengthFromSi(m), 0);
  final ph = a.pumpHouse;
  if (ph != null && ph.circuits.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pumpHouse',
        title: t('agb.rep.pumpHouse'),
        headers: [
          t('agb.rep.pump'),
          '${t('agb.rep.motor')} (kW)',
          '${t('agb.rep.current')} (A)',
          t('agb.rep.starter'),
          '${t('agb.rep.startCurrent')} (A)',
          '${t('agb.rep.length')} (${u.lengthLabel})',
          '${t('agb.rep.section')} (mm²)',
          'PE (mm²)',
          '${t('agb.rep.ampacity')} (A)',
          '${t('agb.rep.dropRun')} (%)',
          '${t('agb.rep.dropStart')} (%)',
          '${t('agb.rep.ik')} (kA)',
          t('rep.warnings'),
        ],
        rows: [
          for (final c in ph.circuits)
            [
              c.name,
              RNum(c.motorKw, c.motorKw < 10 ? 1 : 0),
              RNum(c.currentA, 1),
              t('agb.starter.${c.starter.name}'),
              RNum(c.startCurrentA, 0),
              len(c.lengthM),
              RNum(c.sectionMm2, c.sectionMm2 < 10 ? 1 : 0),
              RNum(c.peMm2, c.peMm2 < 10 ? 1 : 0),
              RNum(c.ampacityA, 0),
              '${fmt(c.runningDropPct, 2)} / ${fmt(c.runningLimitPct, 1)}',
              RNum(c.startingDropPct, 1),
              c.ik3EndKa.isFinite ? RNum(c.ik3EndKa, 2) : '-',
              c.warnings.map(labels.warning).join('; '),
            ],
        ],
        warn: [for (final c in ph.circuits) c.warnings.isNotEmpty],
        ids: [for (final c in ph.circuits) c.pumpId],
      ),
    );
    final source = ph.supply == PowerSupplyKind.generator ? t('agb.rep.generator') : t('agb.rep.transformer');
    out.add(
      ReportTable(
        key: 'pumpHouseSupply',
        title: t('agb.rep.supply'),
        headers: [t('agb.rep.item'), t('agb.rep.value')],
        rows: [
          [t('agb.rep.supplyKind'), t('agb.supply.${ph.supply.name}')],
          [t('agb.rep.voltage'), '${fmt(ph.voltage, 0)} V'],
          [t('agb.rep.demand'), '${fmt(ph.demandKw, 1)} kW · ${fmt(ph.runningKva, 1)} kVA'],
          [t('agb.rep.installed'), '${fmt(ph.installedKw, 1)} kW'],
          [t('agb.rep.largestStart'), '${fmt(ph.largestStartKva, 1)} kVA'],
          if (ph.supply != PowerSupplyKind.lowVoltage) [source, '${fmt(ph.sourceKva, 1)} kVA (≥ ${fmt(ph.sourceKvaRequired, 1)} kVA)'],
          if (ph.supply == PowerSupplyKind.ownTransformer) [t('agb.rep.uk'), '${fmt(ph.ukPct, 1)} %'],
          [t('agb.rep.ikSource'), ph.ik3SourceKa.isFinite ? '${fmt(ph.ik3SourceKa, 2)} kA' : '-'],
          [t('agb.rep.tariffGroup'), t('agb.group.${ph.tariffGroup}')],
        ],
      ),
    );
  }
  if (ph != null && ph.pivots.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'pivotSupply',
        title: t('agb.rep.pivotSupply'),
        headers: [
          t('tool.pivot'),
          '${t('agb.rep.spanCable')} (mm²)',
          'AWG',
          '${t('agb.rep.spanCurrent')} (A)',
          '${t('agb.rep.ampacity')} (A)',
          '${t('agb.rep.ring')} (A)',
          '${t('agb.rep.endTower')} (V / %)',
          '${t('mech.booster')} (kW)',
          '${t('agb.rep.ownTransformer')} (kVA)',
          t('rep.warnings'),
        ],
        rows: [
          for (final s in ph.pivots)
            [
              s.name,
              '${fmt(s.spanCableMm2, 1)}${s.spanMinMm2 > s.spanCableMm2 + 1e-9 ? ' → ${fmt(s.spanMinMm2, 1)}' : ''}',
              s.awg > 0 ? '${s.awg}' : '-',
              RNum(s.spanCurrentA, 1),
              RNum(s.spanAmpacityA, 0),
              RNum(s.collectorRingA, 0),
              '${fmt(s.endTowerVolts, 0)} / ${fmt(s.endTowerDropPct, 1)}',
              s.boosterKw > 0 ? RNum(s.boosterKw, 1) : '-',
              RNum(s.transformerKva, 1),
              s.warnings.map(labels.warning).join('; '),
            ],
        ],
        warn: [for (final s in ph.pivots) s.warnings.isNotEmpty],
        ids: [for (final s in ph.pivots) s.pivotId],
      ),
    );
  }
  final sol = a.solar;
  if (sol != null) {
    final cur = project.params.currency;
    final grid = sol.mode == SolarMode.gridTied;
    out.add(
      ReportTable(
        key: 'solar',
        title: t('agb.rep.solar'),
        headers: [t('agb.rep.item'), t('agb.rep.value')],
        rows: [
          [t('agb.rep.solarMode'), t('agb.solar.${sol.mode.name}')],
          [t('agb.rep.array'), '${sol.modules} × ${fmt(sol.moduleWp, 0)} Wp = ${fmt(sol.arrayKWp, 2)} kWp'],
          [t('agb.rep.arrayArea'), '${fmt(sol.areaM2, 0)} m²'],
          [t(grid ? 'agb.rep.inverter' : 'agb.rep.pumpDrive'), '${fmt(sol.inverterKw, 1)} kW'],
          [t('agb.rep.tilt'), '${fmt(sol.tiltDeg, 0)}°'],
          [t('agb.rep.head'), '${fmt(u.lengthFromSi(sol.headM), 1)} ${u.lengthLabel} · η ${fmt(sol.efficiency * 100, 0)} %'],
          [t('agb.rep.yield'), '${fmt(sol.yieldKWhPerKWp, 0)} kWh/kWp'],
          [t('agb.rep.generation'), '${fmt(sol.generationKWh, 0)} kWh'],
          [t('agb.rep.consumption'), '${fmt(sol.consumptionKWh, 0)} kWh'],
          if (grid) [t('agb.rep.selfConsumed'), '${fmt(sol.selfConsumedKWh, 0)} kWh'],
          if (grid) [t('agb.rep.compensated'), '${fmt(sol.compensatedKWh, 0)} kWh · Fio B ${fmt(sol.fioBPaidPct, 0)} %'],
          if (grid && sol.excessKWh > 0) [t('agb.rep.excess'), '${fmt(sol.excessKWh, 0)} kWh'],
          [t('agb.rep.gridCost'), '$cur ${fmt(sol.gridCost, 2)}'],
          [t('agb.rep.netCost'), '$cur ${fmt(sol.netCost, 2)}'],
          [t('agb.rep.saving'), '$cur ${fmt(sol.saving, 2)}'],
        ],
      ),
    );
    out.add(
      ReportTable(
        key: 'solarMonths',
        title: t('agb.rep.solarMonths'),
        headers: [
          t('req.month'),
          t('solar.sunHours'),
          if (!grid) '${t('solar.volume')} (m³/d)',
          if (!grid) '${t('solar.pumped')} (m³/d)',
          '${t('agb.rep.generation')} (kWh)',
        ],
        rows: [
          for (final m in sol.months) [t('mon.${m.month}'), RNum(m.peakSunHours, 2), if (!grid) RNum(m.demandM3Day, 1), if (!grid) RNum(m.pumpedM3Day, 1), RNum(m.generationKWh, 0)],
        ],
        warn: [for (final m in sol.months) !grid && m.pumpedM3Day + 1e-6 < m.demandM3Day],
      ),
    );
  }
  final w = a.water;
  if (w != null) {
    const units = {'tss': 'mg/L', 'ph': '', 'tds': 'mg/L', 'mn': 'mg/L', 'fe': 'mg/L', 'h2s': 'mg/L', 'bact': '/mL'};
    out.add(
      ReportTable(
        key: 'water',
        title: t('agb.rep.water'),
        headers: [t('agb.rep.parameter'), t('agb.rep.value'), t('agb.rep.risk')],
        rows: [
          for (final h in w.hazards) [t('agb.water.${h.key}'), '${fmt(h.value, h.key == 'bact' ? 0 : 2)} ${units[h.key]}'.trim(), t('agb.risk.${h.risk.name}')],
          if (w.lsi != null) [t('agb.water.lsi'), fmt(w.lsi!, 2), t(w.lsi! > 0 ? 'agb.risk.scaling' : 'agb.risk.low')],
        ],
        warn: [for (final h in w.hazards) h.risk == ClogRisk.severe, if (w.lsi != null) w.lsi! > 0],
      ),
    );
    final safe = project.catalog.valve(w.safetyFilterId);
    out.add(
      ReportTable(
        key: 'waterTreatment',
        title: t('agb.rep.waterTreatment'),
        headers: [t('agb.rep.item'), t('agb.rep.value')],
        rows: [
          [t('agb.rep.risk'), t('agb.risk.${w.overall.name}')],
          [t('agb.rep.filterFlow'), '${fmt(u.flowFromSi(w.designFlowM3h / 3600), 2)} ${u.flowLabel}'],
          [t('agb.rep.passage'), '${fmt(w.passageMm, 2)} mm → ${fmt(w.openingUm, 0)} µm (${w.mesh} mesh)'],
          [t('agb.rep.filterType'), t(w.media ? 'agb.filter.media' : (w.discFilter ? 'agb.filter.disc' : 'agb.filter.screen'))],
          if (w.media && w.mediaTanks > 0) [t('agb.rep.mediaTanks'), '${w.mediaTanks} × Ø ${fmt(w.tankDiameterM * 1000, 0)} mm · ${fmt(w.mediaFlux, 0)} m³/h/m²'],
          if (safe != null && w.safetyFilters > 0) [t('agb.rep.safetyFilter'), '${w.safetyFilters} × ${safe.name}'],
          if (w.drawnFilters > 0) [t('agb.rep.drawnFilters'), '${w.drawnFilters} · ${fmt(u.flowFromSi(w.drawnCapacityM3h / 3600), 2)} ${u.flowLabel}'],
          [t('agb.rep.chlorination'), t('agb.cl.${w.chlorination.name}')],
          if (w.chlorination == ChlorinationMode.continuous || w.chlorination == ChlorinationMode.intermittent) ...[
            [t('agb.rep.clDemand'), '${fmt(w.chlorineDemandMgL, 2)} mg/L · ${t('agb.rep.dose')} ${fmt(w.chlorineDoseMgL, 2)} mg/L'],
            [t('agb.rep.hypochlorite'), '${fmt(w.hypochloriteLph, 2)} L/h · ${fmt(w.hypochloriteLYear, 0)} L/a'],
          ],
          if (w.acidTargetPh != null) [t('agb.rep.acid'), 'pH ${fmt(w.acidTargetPh!, 1)} · ${fmt(w.acidMeqL, 2)} meq/L · ${fmt(w.acidMlM3, 1)} mL/m³'],
          if (w.acidMeqL > 0) [t('agb.rep.acidRate'), '${fmt(w.acidLph, 2)} L/h · ${fmt(w.acidLYear, 0)} L/a'],
        ],
      ),
    );
  }
  if (a.travellers.isNotEmpty) {
    String h(double m) => fmt(u.pressureFromHead(m), 1);
    out.add(
      ReportTable(
        key: 'travellers',
        title: t('agb.rep.travellers'),
        headers: [
          t('agb.rep.lane'),
          t('agb.rep.machine'),
          '${t('agb.rep.length')} (${u.lengthLabel})',
          '${t('agb.rep.laneWidth')} (${u.lengthLabel})',
          '${t('rep.flow')} (${u.flowLabel})',
          '${t('trav.speed')} (m/min)',
          '${t('agb.rep.depth')} (mm)',
          '${t('agb.rep.travel')} (h)',
          '${t('agb.rep.laneTime')} (h)',
          '${t('agb.rep.rate')} (mm/h)',
          '${t('agb.rep.hoseLoss')} (${u.pressureLabel})',
          '${t('rep.pRequired')} (${u.pressureLabel})',
          '${t('agb.rep.available')} (${u.pressureLabel})',
          t('rep.warnings'),
        ],
        rows: [
          for (final l in a.travellers)
            [
              l.name,
              l.machine,
              len(l.result.laneLengthM),
              fmt(u.lengthFromSi(l.result.laneSpacingM), 1),
              RNum(u.flowFromSi(l.flow), 2),
              RNum(l.result.speedMPerMin, 2),
              RNum(l.result.grossDepthMm, 1),
              RNum(l.result.travelHours, 1),
              RNum(l.result.laneHours, 1),
              RNum(l.result.applicationRateMmH, 1),
              h(l.result.hoseFrictionM),
              h(l.requiredHead),
              l.availableHead == null ? '-' : h(l.availableHead!),
              [...l.result.warnings.map(labels.warning), if (l.deficit > 0.01) labels.warning('valve_pressure_deficit')].join('; '),
            ],
        ],
        warn: [for (final l in a.travellers) l.result.warnings.isNotEmpty || l.deficit > 0.01],
        ids: [for (final l in a.travellers) l.laneId],
      ),
    );
  }
  if (a.furrows.isNotEmpty) {
    String h(double m) => fmt(u.pressureFromHead(m), 2);
    out.add(
      ReportTable(
        key: 'furrows',
        title: t('agb.rep.furrows'),
        headers: [
          t('agb.rep.furrowSet'),
          t('agb.rep.furrowCount'),
          t('agb.rep.perSet'),
          '${t('agb.rep.inflow')} (L/s)',
          '${t('rep.flow')} (${u.flowLabel})',
          '${t('agb.rep.advance')} (min)',
          '${t('agb.rep.cutoff')} (min)',
          '${t('agb.rep.irrigation')} (h)',
          'Ea %',
          'DU %',
          '${t('agb.rep.runoff')} %',
          '${t('rep.pRequired')} (${u.pressureLabel})',
          '${t('agb.rep.available')} (${u.pressureLabel})',
          t('rep.warnings'),
        ],
        rows: [
          for (final f in a.furrows)
            [
              f.name,
              f.furrows,
              f.perSet,
              RNum(f.inflow * 1000, 2),
              RNum(u.flowFromSi(f.setFlow), 2),
              RNum(f.advanceS / 60, 0),
              RNum(f.cutoffS / 60, 0),
              RNum(f.irrigationHours, 1),
              RNum(f.efficiency * 100, 0),
              RNum(f.lowQuarterDu * 100, 0),
              RNum(f.tailwaterRatio * 100, 0),
              h(f.inletHeadM),
              f.availableHead == null ? '-' : h(f.availableHead!),
              f.warnings.map(labels.warning).toSet().join('; '),
            ],
        ],
        warn: [for (final f in a.furrows) f.warnings.isNotEmpty || (f.availableHead != null && f.availableHead! < f.inletHeadM - 0.01)],
        ids: [for (final f in a.furrows) f.setId],
      ),
    );
  }
  final tw = a.twoWire;
  if (tw != null && tw.paths.isNotEmpty) {
    String decoders(String ctl) {
      final by = <int, int>{};
      for (final d in tw.decoders) {
        if (d.controllerId == ctl) by[d.capacity] = (by[d.capacity] ?? 0) + 1;
      }
      final caps = by.keys.toList()..sort();
      return caps.isEmpty ? '0' : caps.map((k) => '${by[k]} × $k').join(' · ');
    }

    out.add(
      ReportTable(
        key: 'twoWire',
        title: t('agb.rep.twoWire'),
        headers: [
          t('rep.controller'),
          t('tw.wire'),
          '${t('wr.route')} (${u.lengthLabel})',
          '${t('tw.length')} (${u.lengthLabel})',
          t('tw.decoders'),
          '${t('elec.peak')} (A)',
          '${t('tw.worst')} (V)',
          '${t('tw.maxDistance')} (${u.lengthLabel})',
        ],
        rows: [
          for (final path in tw.paths)
            [
              labels.name(path.controllerId),
              path.wireId == null ? '-' : (project.catalog.wire(path.wireId)?.name ?? path.wireId!),
              len(path.routeM),
              len(path.cableM),
              decoders(path.controllerId),
              RNum(path.peakCurrentA, 2),
              RNum(path.worstVolts, 1),
              path.maxDistanceM.isFinite ? len(path.maxDistanceM) : '∞',
            ],
        ],
        warn: [for (final path in tw.paths) path.worstVolts < project.agb.twoWire.minVolts - 1e-9],
        ids: [for (final path in tw.paths) path.controllerId],
      ),
    );
  }
  return out;
}
