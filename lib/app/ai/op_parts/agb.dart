/// Operations (find_operations / run_operation) added in 1.6.0 for machines, electrical and water (pump house and pivot electrics, traveller and furrows as design, several pivots, solar pumping, water quality and filtration, two-wire):
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/agb_design.dart';
import '../../../core/design/field_machines.dart';
import '../../../core/design/mechanised.dart' show closedOutlineOf;
import '../../../core/design/multi_pivot.dart';
import '../../../core/design/network_ops.dart' show wiringFlows;
import '../../../core/design/pump_house.dart';
import '../../../core/design/solar_design.dart';
import '../../../core/design/traveller.dart' show WindClass;
import '../../../core/design/two_wire.dart';
import '../../../core/design/water_quality.dart';
import '../../../core/model/agb_settings.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../ops_eng_common.dart';
import '../../widgets/dialogs/field_machine_dialogs.dart' show agbAddFlows;

const _group = 'machines';

/// A copy of the project's settings changed by [edit] replaces them as one
/// undo step (the design results go).
void _setAgb(AgentToolbox b, String op, void Function(AgbSettings s) edit) {
  engNotBusy(b.c);
  final draft = b.p.agb.clone();
  edit(draft);
  b.change(op, () {
    b.p.agb = draft;
    return 1;
  });
}

/// The pump house design as text.
String _pumpHouseText(AgentToolbox b, PumpHouseResult r) {
  final s = b.p.agb.pumpHouse;
  final out = <String>[
    'Settings (set_pump_house names): enabled ${s.enabled}, voltage ${engN(s.voltage, 0)} V, supply ${s.supply.name}, insulation ${s.insulation.name}, method ${s.method.name}, '
        'ambient_c ${s.ambientC == null ? 'reference' : engN(s.ambientC!, 0)}, grouping ${engN(s.groupingFactor)}, service_factor ${engN(s.serviceFactor)}, direct_max_kw ${engN(s.directMaxKw, 1)}, '
        'soft_multiple ${engN(s.softStartMultiple, 1)}, default_length_m ${engN(s.defaultFeederM, 0)}, max_running_drop_pct ${engN(s.maxRunningDropPct, 1)} (0 = NBR 5410), uk_pct ${engN(s.transformerUkPct, 1)} (0 = typical), '
        'loading_pct ${engN(s.transformerLoadingPct, 0)}, other_kva ${engN(s.otherLoadsKva, 1)}, include_pivots ${s.includePivots}.',
    if (r.circuits.isNotEmpty)
      engTable(
        ['pump', 'motor kW', 'eff', 'pf', 'In A', 'Ib A', 'starter', 'Istart A', 'length m', 'mm²', 'PE mm²', 'Iz A', 'drop run %', 'limit %', 'drop start %', 'Ik starter kA', 'messages'],
        [
          for (final c in r.circuits)
            [
              '${c.pumpId} ${c.name}',
              engN(c.motorKw, 1),
              engN(c.efficiency, 3),
              engN(c.powerFactor, 2),
              engN(c.currentA, 1),
              engN(c.designCurrentA, 1),
              c.starter.name,
              engN(c.startCurrentA, 0),
              engN(c.lengthM, 0),
              engN(c.sectionMm2, 1),
              engN(c.peMm2, 1),
              engN(c.ampacityA, 0),
              engN(c.runningDropPct, 2),
              engN(c.runningLimitPct, 1),
              engN(c.startingDropPct, 2),
              c.ik3EndKa.isFinite ? engN(c.ik3EndKa, 2) : '-',
              c.warnings.map((w) => w.split(':').first).join(' '),
            ],
        ],
      ),
    if (r.circuits.isNotEmpty || r.pivots.isNotEmpty)
      'Supply ${r.supply.name}: demand ${engN(r.demandKw, 1)} kW / ${engN(r.runningKva, 1)} kVA${r.worstFlow.isEmpty ? '' : ' (flow ${r.worstFlow})'}, installed ${engN(r.installedKw, 1)} kW, '
          'largest start ${engN(r.largestStartKva, 1)} kVA, source ${engN(r.sourceKva, 1)} kVA (needs ≥ ${engN(r.sourceKvaRequired, 1)}), uk ${engN(r.ukPct, 1)} %, '
          'Ik3 at the source ${r.ik3SourceKa.isFinite ? '${engN(r.ik3SourceKa, 2)} kA' : '-'}, tariff group ${r.tariffGroup}.',
    if (r.pivots.isNotEmpty)
      engTable(
        ['pivot', 'span cable mm²', 'least mm² (ampacity)', 'AWG', 'first span A', 'Iz A', 'collector ring A', 'end tower V', 'end tower drop %', 'booster kW', 'own transformer kVA'],
        [
          for (final x in r.pivots)
            [
              '${x.pivotId} ${x.name}',
              engN(x.spanCableMm2, 1),
              engN(x.spanMinMm2, 1),
              x.awg > 0 ? '${x.awg}' : '-',
              engN(x.spanCurrentA, 1),
              engN(x.spanAmpacityA, 0),
              engN(x.collectorRingA, 0),
              engN(x.endTowerVolts, 0),
              engN(x.endTowerDropPct, 2),
              engN(x.boosterKw, 1),
              engN(x.transformerKva, 1),
            ],
        ],
      ),
    if (r.circuits.isEmpty && r.pivots.isEmpty) 'No electric pump and no pivot with an electrical design.',
  ];
  return out.join('\n') + engCodes(b, r.warnings);
}

/// The solar design as text.
String _solarText(AgentToolbox b, SolarDesign? r) {
  final s = b.p.agb.solar;
  final head =
      'Settings (set_solar_design names): mode ${s.mode.name}, module_wp ${engN(s.moduleWp, 0)}, module_area_m2 ${engN(s.moduleAreaM2)}, tilt_deg ${s.tiltDeg == null ? 'latitude' : engN(s.tiltDeg!, 0)}, '
      'azimuth_deg ${engN(s.azimuthFromEquatorDeg, 0)}, oversize ${engN(s.oversize)}, converter_efficiency ${engN(s.converterEfficiency)}, motor_pump_efficiency ${engN(s.motorPumpEfficiency)} (0 = design), '
      'head_m ${engN(s.headM, 1)} (0 = design), dc_ac_ratio ${engN(s.dcAcRatio)}, simultaneity ${engN(s.simultaneity)}, fio_b_pct ${engN(s.fioBSharePct, 1)}, billing_year ${s.billingYear}, grandfathered ${s.grandfathered}.';
  if (r == null) return '$head\nSolar pumping is off (mode "off").';
  return [
    head,
    '${r.mode.name}: ${r.modules} × ${engN(r.moduleWp, 0)} Wp = ${engN(r.arrayKWp, 2)} kWp, ${engN(r.areaM2, 0)} m², ${r.mode == SolarMode.offGrid ? 'pump drive' : 'inverter'} ${engN(r.inverterKw, 1)} kW, tilt ${engN(r.tiltDeg, 0)}°, '
        'head ${engN(r.headM, 1)} m, wire-to-water ${engN(r.efficiency, 3)}; yield ${engN(r.yieldKWhPerKWp, 0)} kWh/kWp, generation ${engN(r.generationKWh, 0)} kWh/a, pumping ${engN(r.consumptionKWh, 0)} kWh/a'
        '${r.mode == SolarMode.gridTied ? '; used as generated ${engN(r.selfConsumedKWh, 0)}, compensated ${engN(r.compensatedKWh, 0)} (Fio B paid ${engN(r.fioBPaidPct, 0)} %), left over ${engN(r.excessKWh, 0)} kWh' : ''}'
        '${r.criticalMonth == null ? '' : '; critical month ${r.criticalMonth}'}. Energy cost on the grid ${engN(r.gridCost, 2)}, with the array ${engN(r.netCost, 2)}, saving ${engN(r.saving, 2)} ${b.p.params.currency}/year.',
    engTable(
      ['month', 'sun hours', 'demand m³/d', 'pumped m³/d', 'generation kWh'],
      [
        for (final m in r.months) [engMonths[m.month - 1], engN(m.peakSunHours, 2), engN(m.demandM3Day, 1), engN(m.pumpedM3Day, 1), engN(m.generationKWh, 0)],
      ],
    ),
  ].join('\n') + engCodes(b, r.warnings, name: (m) => m);
}

/// The water design as text.
String _waterText(AgentToolbox b, WaterQualityResult? r) {
  final w = b.p.agb.water;
  String v(double? x) => x == null ? '-' : engN(x, 3);
  final head =
      'Analysis (set_water_quality names): source ${w.source.name}, ph ${v(w.ph)}, ec_ds_m ${v(w.ecDsM)}, tds_mg_l ${v(w.tdsMgL)}, tss_mg_l ${v(w.tssMgL)}, iron_mg_l ${v(w.ironMgL)}, manganese_mg_l ${v(w.manganeseMgL)}, '
      'sulfide_mg_l ${v(w.sulfideMgL)}, calcium_mg_l ${v(w.calciumMgL)}, bicarbonate_mg_l ${v(w.bicarbonateMgL)}, bacteria_per_ml ${v(w.bacteriaPerMl)}, temperature_c ${engN(w.temperatureC, 0)}; '
      'treatment: emitter_passage_mm ${engN(w.emitterPassageMm)} (0 = by the emitters), mesh_ratio ${engN(w.meshRatio, 0)}, chlorination ${w.chlorination.name}, residual_mg_l ${engN(w.chlorineResidualMgL)}, '
      'shock_mg_l ${engN(w.shockMgL)}, shock_minutes ${engN(w.shockMinutes, 0)}, shocks_per_month ${engN(w.shocksPerMonth, 0)}, hypochlorite_pct ${engN(w.hypochloritePct, 1)}, acid_target_ph ${v(w.acidTargetPh)}, acid ${w.acid.name}.';
  if (r == null) return '$head\nNo analysis yet: give at least one value with set_water_quality.';
  final safe = b.p.catalog.valve(r.safetyFilterId);
  return [
    head,
    engTable(['parameter', 'value', 'clogging hazard (Nakayama 1982)'], [
      for (final h in r.hazards) [h.key, engN(h.value, 3), h.risk.name],
    ]),
    'Overall hazard ${r.overall.name}; Langelier index ${r.lsi == null ? '-' : engN(r.lsi!, 2)}; dissolved solids ${engN(r.tdsMgL, 0)} mg/L.',
    'Filtration for ${engN(r.designFlowM3h, 1)} m³/h: emitter passage ${engN(r.passageMm, 2)} mm → opening ${engN(r.openingUm, 0)} µm (${r.mesh} mesh); '
        '${r.media ? 'media filters ${r.mediaTanks} × Ø ${engN(r.tankDiameterM * 1000, 0)} mm at ${engN(r.mediaFlux, 0)} m³/h/m² + ' : ''}${r.discFilter ? 'disc' : 'screen'} filter'
        '${safe == null ? '' : ' (${r.safetyFilters} × ${safe.id} ${safe.name})'}; filters drawn ${r.drawnFilters} (${engN(r.drawnCapacityM3h, 1)} m³/h).',
    'Chlorination ${r.chlorination.name}: demand ${engN(r.chlorineDemandMgL, 2)} mg/L, dose ${engN(r.chlorineDoseMgL, 2)} mg/L, hypochlorite ${engN(r.hypochloriteLph, 2)} L/h, ${engN(r.hypochloriteLYear, 0)} L/year.',
    if (r.acidTargetPh != null)
      'Acid to pH ${engN(r.acidTargetPh!, 1)}: ${engN(r.acidMeqL, 2)} meq/L, ${engN(r.acidMlM3, 1)} mL/m³ of ${w.acid.name}, ${engN(r.acidLph, 2)} L/h, ${engN(r.acidLYear, 0)} L/year.',
  ].join('\n') + engCodes(b, r.warnings);
}

/// The two-wire design as text.
String _twoWireText(AgentToolbox b, TwoWireResult? r) {
  final s = b.p.agb.twoWire;
  final head =
      'Settings (set_two_wire names): enabled ${s.enabled}, output_volts ${engN(s.outputVolts, 1)}, min_volts ${engN(s.minVolts, 1)}, idle_ma ${engN(s.decoderIdleMa)}, solenoid_reach_m ${engN(s.solenoidReachM, 0)}, '
      'ground_every_decoders ${s.groundEveryDecoders}, ground_every_m ${engN(s.groundEveryM, 0)}.';
  if (r == null) return '$head\nNo controller or no wire route: draw the routes first (route_wires or create_entities type "wire").';
  final caps = <int, int>{};
  for (final d in r.decoders) {
    caps[d.capacity] = (caps[d.capacity] ?? 0) + 1;
  }
  return [
    head,
    engTable(
      ['controller', 'wire', 'route m', 'cable m', 'decoders', 'most open', 'peak A', 'worst V', 'largest distance m'],
      [
        for (final x in r.paths)
          [
            x.controllerId,
            x.wireId ?? '-',
            engN(x.routeM, 0),
            engN(x.cableM, 0),
            '${x.decoders}',
            '${x.maxOpen}',
            engN(x.peakCurrentA, 2),
            engN(x.worstVolts, 1),
            x.maxDistanceM.isFinite ? engN(x.maxDistanceM, 0) : '∞',
          ],
      ],
    ),
    'Decoders by outputs: ${caps.isEmpty ? 'none' : (caps.keys.toList()..sort()).map((k) => '${caps[k]} × $k').join(', ')}; grounding points ${r.grounds.length}; stations ${r.stations.length}.',
  ].join('\n') + engCodes(b, r.warnings);
}

/// The lanes and furrow sets analysed (the design's when it ran).
String _fieldMachinesText(AgentToolbox b) {
  final p = b.p;
  final terrain = p.buildTerrain();
  final lanes = b.c.results?.agb?.travellers ?? [for (final e in p.entities.whereType<TravellerEntity>()) analyzeTravellerLane(p, e, terrain: terrain)];
  final sets = b.c.results?.agb?.furrows ?? [for (final e in p.entities.whereType<FurrowEntity>()) analyzeFurrowSet(p, e, terrain: terrain)];
  if (lanes.isEmpty && sets.isEmpty) return 'No traveller lane and no furrow set in the drawing (traveller_lanes, furrow_set).';
  return [
    if (lanes.isNotEmpty)
      engTable(
        ['lane', 'reel', 'run m', 'spacing m', 'flow m³/h', 'speed m/min', 'depth mm', 'travel h', 'lane h', 'rate mm/h', 'hose loss m', 'required m', 'available m', 'messages'],
        [
          for (final l in lanes)
            [
              '${l.laneId} ${l.name}',
              l.machine,
              engN(l.result.laneLengthM, 0),
              engN(l.result.laneSpacingM, 1),
              engN(l.flow * 3600, 1),
              engN(l.result.speedMPerMin, 2),
              engN(l.result.grossDepthMm, 1),
              engN(l.result.travelHours, 1),
              engN(l.result.laneHours, 1),
              engN(l.result.applicationRateMmH, 1),
              engN(l.result.hoseFrictionM, 1),
              engN(l.requiredHead, 1),
              l.availableHead == null ? '-' : engN(l.availableHead!, 1),
              l.result.warnings.map((w) => w.split(':').first).join(' '),
            ],
        ],
      ),
    if (sets.isNotEmpty)
      engTable(
        ['set', 'furrows', 'per set', 'sets', 'L/s per furrow', 'set m³/h', 'advance min', 'cutoff min', 'irrigation h', 'Ea %', 'DU %', 'tailwater %', 'required m', 'available m', 'messages'],
        [
          for (final f in sets)
            [
              '${f.setId} ${f.name}',
              '${f.furrows}',
              '${f.perSet}',
              '${f.sets}',
              engN(f.inflow * 1000, 2),
              engN(f.setFlow * 3600, 1),
              engN(f.advanceS / 60, 0),
              engN(f.cutoffS / 60, 0),
              engN(f.irrigationHours, 1),
              engN(f.efficiency * 100, 0),
              engN(f.lowQuarterDu * 100, 0),
              engN(f.tailwaterRatio * 100, 0),
              engN(f.inletHeadM, 2),
              f.availableHead == null ? '-' : engN(f.availableHead!, 1),
              f.warnings.map((w) => w.split(':').first).toSet().join(' '),
            ],
        ],
      ),
    if (b.c.results == null) 'No design results: the hydrant pressures come with run_design.',
  ].join('\n');
}

/// The closed outline named by [ref] (default: the first closed shape of
/// the selection).
(String, List<Pt>) _field(AgentToolbox b, String? ref, String what) {
  if (ref != null) {
    final e = b.find(ref);
    final pts = closedOutlineOf(b.p, e.id);
    if (pts == null) throw ToolInputError('"$ref" is not a closed shape (an area, a closed polyline or a circle) for the $what.');
    return (e.id, pts);
  }
  for (final id in b.c.selection) {
    final pts = closedOutlineOf(b.p, id);
    if (pts != null && b.p.byId(id) is! PivotEntity) return (id, pts);
  }
  throw ToolInputError('Give "field": the id or name of the closed shape (area or closed polyline) of the $what.');
}

List<AgentTool> opsAgb(AgentToolbox b) {
  final c = b.c;
  return [
    // ---------------------------------------------------------------- pump house
    cadOp(
      b,
      group: _group,
      name: 'pump_house_electrics',
      description:
          'Reads the electrical design of the pump house (Design → Pump house electrics) as the dialog shows it on the last design: for every electric pump the motor (kW, IE3 efficiency, power factor), rated and design current, the starting method (direct, star-delta, soft-starter, frequency drive) and its current, the feeder cable by ampacity (NBR 5410 Tables 36-40), running drop (6.2.7) and starting drop (10 % at the starter, 6.5.1.3.3), the protective conductor and the short-circuit current (IEC 60909); the transformer or generator, the demand, the installed load and the tariff group; and the supply of every pivot with an electrical design (span cable ampacity and AWG, collector ring, end tower). Works without design results (the pumps at their curve). No input.',
      schema: obj({}),
      run: (a, _) async => ToolOutput(_pumpHouseText(b, await engSoon(() => designPumpHouse(b.p, c.results)))),
    ),
    cadOp(
      b,
      group: _group,
      name: 'set_pump_house',
      effect: ToolEffect.write,
      description:
          'Changes the pump house electrical settings (one undo step; the design results are discarded and the bill of materials then lists the feeders, starter panels and transformer). Give only what changes: enabled (include it in the design), voltage (V), supply (ownTransformer | lowVoltage | generator), insulation (pvc | xlpe), method (b1 conduit on a wall | c on a wall or plain tray | d duct in the ground | e multicore in free air), ambient_c (air, soil for d), grouping (0.3-1), service_factor, direct_max_kw (largest direct start the utility allows), soft_multiple (soft-starter current × rated), default_length_m, max_running_drop_pct (0 = NBR 5410), uk_pct (0 = typical), loading_pct, other_kva, include_pivots, clearing_s, upstream_mva (0 = infinite), panel_cost, transformer_cost, pumps ({pump id or name: {length_m, starter auto|direct|starDelta|softStarter|vfd, motor_kw (0 = from the duty), efficiency, power_factor, electric}}). Output: the new design (pump_house_electrics).',
      schema: obj({
        'enabled': bool_(),
        'voltage': num_('110-1000 V.'),
        'supply': str(null, [for (final k in PowerSupplyKind.values) k.name]),
        'insulation': str(null, [for (final k in CableInsulation.values) k.name]),
        'method': str(null, [for (final k in CableMethod.values) k.name]),
        'ambient_c': num_('0-80 °C.'),
        'grouping': num_('0.3-1.'),
        'service_factor': num_('1-1.5.'),
        'direct_max_kw': num_('0-1000 kW.'),
        'soft_multiple': num_('1-6.'),
        'default_length_m': num_('1-20000 m.'),
        'max_running_drop_pct': num_('0-15 %.'),
        'uk_pct': num_('0-15 %.'),
        'loading_pct': num_('30-150 %.'),
        'other_kva': num_('0-5000 kVA.'),
        'include_pivots': bool_(),
        'clearing_s': num_('0-5 s.'),
        'upstream_mva': num_('0-10000 MVA.'),
        'panel_cost': num_(),
        'transformer_cost': num_(),
        'pumps': {'type': 'object', 'description': 'Pump id or name → {length_m, starter, motor_kw, efficiency, power_factor, electric}.'},
      }),
      run: (a, i) async {
        if (i.isEmpty) throw ToolInputError('Give at least one setting to change.');
        _setAgb(b, 'set_pump_house', (d) {
          final s = d.pumpHouse;
          s.enabled = a.flag('enabled') ?? s.enabled;
          s.voltage = a.number('voltage', min: 110, max: 1000) ?? s.voltage;
          if (a.has('supply')) s.supply = PowerSupplyKind.values.byName(a.str('supply')!);
          if (a.has('insulation')) s.insulation = CableInsulation.values.byName(a.str('insulation')!);
          if (a.has('method')) s.method = CableMethod.values.byName(a.str('method')!);
          s.ambientC = a.number('ambient_c', min: 0, max: 80) ?? s.ambientC;
          s.groupingFactor = a.number('grouping', min: 0.3, max: 1) ?? s.groupingFactor;
          s.serviceFactor = a.number('service_factor', min: 1, max: 1.5) ?? s.serviceFactor;
          s.directMaxKw = a.number('direct_max_kw', min: 0, max: 1000) ?? s.directMaxKw;
          s.softStartMultiple = a.number('soft_multiple', min: 1, max: 6) ?? s.softStartMultiple;
          s.defaultFeederM = a.number('default_length_m', min: 1, max: 20000) ?? s.defaultFeederM;
          s.maxRunningDropPct = a.number('max_running_drop_pct', min: 0, max: 15) ?? s.maxRunningDropPct;
          s.transformerUkPct = a.number('uk_pct', min: 0, max: 15) ?? s.transformerUkPct;
          s.transformerLoadingPct = a.number('loading_pct', min: 30, max: 150) ?? s.transformerLoadingPct;
          s.otherLoadsKva = a.number('other_kva', min: 0, max: 5000) ?? s.otherLoadsKva;
          s.includePivots = a.flag('include_pivots') ?? s.includePivots;
          s.clearingTimeS = a.number('clearing_s', min: 0, max: 5) ?? s.clearingTimeS;
          s.upstreamMva = a.number('upstream_mva', min: 0, max: 10000) ?? s.upstreamMva;
          s.panelCost = a.number('panel_cost', min: 0) ?? s.panelCost;
          s.transformerCost = a.number('transformer_cost', min: 0) ?? s.transformerCost;
          final pumps = i['pumps'];
          if (pumps != null) {
            if (pumps is! Map) throw ToolInputError('"pumps" must be an object {pump id or name: {…}}.');
            for (final e in pumps.entries) {
              final pump = b.find('${e.key}');
              if (pump is! PumpEntity) throw ToolInputError('"${e.key}" is not a pump.');
              if (e.value is! Map) throw ToolInputError('pumps["${e.key}"] must be an object.');
              final pa = ToolArgs(Map<String, dynamic>.from(e.value as Map));
              final f = s.pumps.putIfAbsent(pump.id, PumpFeeder.new);
              f.lengthM = pa.number('length_m', min: 1, max: 20000) ?? f.lengthM;
              if (pa.has('starter')) f.starter = StarterKind.values.byName(pa.str('starter')!);
              f.motorKw = pa.number('motor_kw', min: 0, max: 2000) ?? f.motorKw;
              f.efficiency = pa.number('efficiency', min: 0, max: 1) ?? f.efficiency;
              f.powerFactor = pa.number('power_factor', min: 0, max: 1) ?? f.powerFactor;
              f.electric = pa.flag('electric') ?? f.electric;
            }
            s.pumps.removeWhere((_, f) => f.isDefault);
          }
        });
        return ToolOutput('Pump house settings changed; design results discarded (run_design again).\n${_pumpHouseText(b, designPumpHouse(b.p, null))}');
      },
    ),
    // ---------------------------------------------------------------- solar
    cadOp(
      b,
      group: _group,
      name: 'solar_design',
      description:
          'Reads the solar pumping of the design (Design → Solar pumping of the design): an off-grid PV pumping array sized for the month of largest need (IEC 62253), or a grid-tied array whose energy offsets the pumping under net metering (Lei 14.300/2022, the Fio B paid on the credits by the year billed), with modules, kWp, area, inverter or pump drive, the yearly yield and generation, the pumping energy, the energy cost on the grid and with the array, and the month table. The irradiation comes from the site climate (set_site_climate or the climate download). No input.',
      schema: obj({}),
      run: (a, _) async => ToolOutput(_solarText(b, await engSoon(() => designSolar(b.p, c.results)))),
    ),
    cadOp(
      b,
      group: _group,
      name: 'set_solar_design',
      effect: ToolEffect.write,
      description:
          'Changes the solar pumping of the design (one undo step; the results are discarded, and after run_design the bill of materials lists the modules, structure and inverter and the energy cost of the design carries the solar compensation). Give only what changes: mode (off | offGrid | gridTied), module_wp, module_area_m2, tilt_deg (-1 = the latitude), azimuth_deg (from the equator, west positive), oversize, soiling, converter_efficiency, motor_pump_efficiency (0 = from the design), head_m (0 = from the design), dc_ac_ratio, simultaneity (0-1 share used as generated), fio_b_pct (share of the Fio B in the tariff), billing_year, grandfathered (access asked before 7 Jan 2023), module_price, inverter_price_per_kw, structure_price. Output: the new solar design.',
      schema: obj({
        'mode': str(null, [for (final k in SolarMode.values) k.name]),
        'module_wp': num_('10-1000 Wp.'),
        'module_area_m2': num_('0.1-10 m².'),
        'tilt_deg': num_('0-90°, or -1 for the latitude.'),
        'azimuth_deg': num_('-180-180°.'),
        'oversize': num_('0.5-3.'),
        'soiling': num_('0-0.5.'),
        'converter_efficiency': num_('0.5-1.'),
        'motor_pump_efficiency': num_('0-1 (0 = design).'),
        'head_m': num_('0-2000 m (0 = design).'),
        'dc_ac_ratio': num_('0.8-2.'),
        'simultaneity': num_('0-1.'),
        'fio_b_pct': num_('0-100 %.'),
        'billing_year': int_('2020-2100.'),
        'grandfathered': bool_(),
        'module_price': num_(),
        'inverter_price_per_kw': num_(),
        'structure_price': num_(),
      }),
      run: (a, i) async {
        if (i.isEmpty) throw ToolInputError('Give at least one setting to change.');
        _setAgb(b, 'set_solar_design', (d) {
          final s = d.solar;
          if (a.has('mode')) s.mode = SolarMode.values.byName(a.str('mode')!);
          s.moduleWp = a.number('module_wp', min: 10, max: 1000) ?? s.moduleWp;
          s.moduleAreaM2 = a.number('module_area_m2', min: 0.1, max: 10) ?? s.moduleAreaM2;
          final tilt = a.number('tilt_deg', min: -1, max: 90);
          if (tilt != null) s.tiltDeg = tilt < 0 ? null : tilt;
          s.azimuthFromEquatorDeg = a.number('azimuth_deg', min: -180, max: 180) ?? s.azimuthFromEquatorDeg;
          s.oversize = a.number('oversize', min: 0.5, max: 3) ?? s.oversize;
          s.soiling = a.number('soiling', min: 0, max: 0.5) ?? s.soiling;
          s.converterEfficiency = a.number('converter_efficiency', min: 0.5, max: 1) ?? s.converterEfficiency;
          s.motorPumpEfficiency = a.number('motor_pump_efficiency', min: 0, max: 1) ?? s.motorPumpEfficiency;
          s.headM = a.number('head_m', min: 0, max: 2000) ?? s.headM;
          s.dcAcRatio = a.number('dc_ac_ratio', min: 0.8, max: 2) ?? s.dcAcRatio;
          s.simultaneity = a.number('simultaneity', min: 0, max: 1) ?? s.simultaneity;
          s.fioBSharePct = a.number('fio_b_pct', min: 0, max: 100) ?? s.fioBSharePct;
          s.billingYear = a.integer('billing_year', min: 2020, max: 2100) ?? s.billingYear;
          s.grandfathered = a.flag('grandfathered') ?? s.grandfathered;
          s.modulePrice = a.number('module_price', min: 0) ?? s.modulePrice;
          s.inverterPricePerKw = a.number('inverter_price_per_kw', min: 0) ?? s.inverterPricePerKw;
          s.structurePricePerModule = a.number('structure_price', min: 0) ?? s.structurePricePerModule;
        });
        return ToolOutput('Solar settings changed; design results discarded (run_design again).\n${_solarText(b, designSolar(b.p, null))}');
      },
    ),
    // ---------------------------------------------------------------- water
    cadOp(
      b,
      group: _group,
      name: 'water_quality',
      description:
          'Reads the water analysis and what it asks of the system (Design → Water quality and filtration): the clogging hazard of every parameter (Nakayama 1982: suspended solids, pH, dissolved solids, iron, manganese, hydrogen sulfide, bacteria), the Langelier index, the filtration for the design flow (opening from the smallest emitter passage, mesh, media filters and their tanks, the catalogue safety filter, the filters drawn), the chlorination (oxidation demand, dose, hypochlorite L/h and per year) and the acid to the target pH (meq/L, mL/m³, L/h). No input.',
      schema: obj({}),
      run: (a, _) async => ToolOutput(_waterText(b, designWaterQuality(b.p, c.results))),
    ),
    cadOp(
      b,
      group: _group,
      name: 'set_water_quality',
      effect: ToolEffect.write,
      description:
          'Changes the water analysis and the treatment (one undo step; the results are discarded, and after run_design the report and the bill of materials carry the filtration and the injectors). Give only what changes: source (well | surface | reservoir | municipal), ph, ec_ds_m, tds_mg_l, tss_mg_l, iron_mg_l, manganese_mg_l, sulfide_mg_l, calcium_mg_l, bicarbonate_mg_l, bacteria_per_ml, temperature_c, emitter_passage_mm (0 = by the emitters), mesh_ratio, chlorination (auto | none | continuous | intermittent), residual_mg_l, shock_mg_l, shock_minutes, shocks_per_month, hypochlorite_pct, acid_target_ph, acid (sulfuric | hydrochloric | nitric | phosphoric), filter_cost, injector_cost; clear (keys of the analysis to set to "not analysed"). Output: the new water design.',
      schema: obj({
        'source': str(null, [for (final k in WaterSource.values) k.name]),
        'ph': num_('0-14.'),
        'ec_ds_m': num_('dS/m.'),
        'tds_mg_l': num_('mg/L.'),
        'tss_mg_l': num_('mg/L.'),
        'iron_mg_l': num_('mg/L.'),
        'manganese_mg_l': num_('mg/L.'),
        'sulfide_mg_l': num_('mg/L.'),
        'calcium_mg_l': num_('mg/L.'),
        'bicarbonate_mg_l': num_('mg/L.'),
        'bacteria_per_ml': num_('per mL.'),
        'temperature_c': num_('0-50 °C.'),
        'emitter_passage_mm': num_('0-20 mm.'),
        'mesh_ratio': num_('1-20.'),
        'chlorination': str(null, [for (final k in ChlorinationMode.values) k.name]),
        'residual_mg_l': num_('0-20 mg/L.'),
        'shock_mg_l': num_('0-100 mg/L.'),
        'shock_minutes': num_('0-600 min.'),
        'shocks_per_month': num_('0-31.'),
        'hypochlorite_pct': num_('0.5-20 %.'),
        'acid_target_ph': num_('2-9.'),
        'acid': str(null, [for (final k in AcidProduct.values) k.name]),
        'filter_cost': num_(),
        'injector_cost': num_(),
        'clear': arr(str(null, const ['ph', 'ec_ds_m', 'tds_mg_l', 'tss_mg_l', 'iron_mg_l', 'manganese_mg_l', 'sulfide_mg_l', 'calcium_mg_l', 'bicarbonate_mg_l', 'bacteria_per_ml', 'acid_target_ph'])),
      }),
      run: (a, i) async {
        if (i.isEmpty) throw ToolInputError('Give at least one value to change.');
        _setAgb(b, 'set_water_quality', (d) {
          final w = d.water;
          if (a.has('source')) w.source = WaterSource.values.byName(a.str('source')!);
          w.ph = a.number('ph', min: 0, max: 14) ?? w.ph;
          w.ecDsM = a.number('ec_ds_m', min: 0, max: 100) ?? w.ecDsM;
          w.tdsMgL = a.number('tds_mg_l', min: 0, max: 100000) ?? w.tdsMgL;
          w.tssMgL = a.number('tss_mg_l', min: 0, max: 100000) ?? w.tssMgL;
          w.ironMgL = a.number('iron_mg_l', min: 0, max: 1000) ?? w.ironMgL;
          w.manganeseMgL = a.number('manganese_mg_l', min: 0, max: 1000) ?? w.manganeseMgL;
          w.sulfideMgL = a.number('sulfide_mg_l', min: 0, max: 1000) ?? w.sulfideMgL;
          w.calciumMgL = a.number('calcium_mg_l', min: 0, max: 10000) ?? w.calciumMgL;
          w.bicarbonateMgL = a.number('bicarbonate_mg_l', min: 0, max: 10000) ?? w.bicarbonateMgL;
          w.bacteriaPerMl = a.number('bacteria_per_ml', min: 0, max: 1e9) ?? w.bacteriaPerMl;
          w.temperatureC = a.number('temperature_c', min: 0, max: 50) ?? w.temperatureC;
          w.emitterPassageMm = a.number('emitter_passage_mm', min: 0, max: 20) ?? w.emitterPassageMm;
          w.meshRatio = a.number('mesh_ratio', min: 1, max: 20) ?? w.meshRatio;
          if (a.has('chlorination')) w.chlorination = ChlorinationMode.values.byName(a.str('chlorination')!);
          w.chlorineResidualMgL = a.number('residual_mg_l', min: 0, max: 20) ?? w.chlorineResidualMgL;
          w.shockMgL = a.number('shock_mg_l', min: 0, max: 100) ?? w.shockMgL;
          w.shockMinutes = a.number('shock_minutes', min: 0, max: 600) ?? w.shockMinutes;
          w.shocksPerMonth = a.number('shocks_per_month', min: 0, max: 31) ?? w.shocksPerMonth;
          w.hypochloritePct = a.number('hypochlorite_pct', min: 0.5, max: 20) ?? w.hypochloritePct;
          w.acidTargetPh = a.number('acid_target_ph', min: 2, max: 9) ?? w.acidTargetPh;
          if (a.has('acid')) w.acid = AcidProduct.values.byName(a.str('acid')!);
          w.filterCost = a.number('filter_cost', min: 0) ?? w.filterCost;
          w.injectorCost = a.number('injector_cost', min: 0) ?? w.injectorCost;
          for (final k in a.strings('clear')) {
            switch (k) {
              case 'ph':
                w.ph = null;
              case 'ec_ds_m':
                w.ecDsM = null;
              case 'tds_mg_l':
                w.tdsMgL = null;
              case 'tss_mg_l':
                w.tssMgL = null;
              case 'iron_mg_l':
                w.ironMgL = null;
              case 'manganese_mg_l':
                w.manganeseMgL = null;
              case 'sulfide_mg_l':
                w.sulfideMgL = null;
              case 'calcium_mg_l':
                w.calciumMgL = null;
              case 'bicarbonate_mg_l':
                w.bicarbonateMgL = null;
              case 'bacteria_per_ml':
                w.bacteriaPerMl = null;
              case 'acid_target_ph':
                w.acidTargetPh = null;
              default:
                throw ToolInputError('clear: "$k" is no value of the analysis.');
            }
          }
        });
        return ToolOutput('Water analysis changed; design results discarded (run_design again).\n${_waterText(b, designWaterQuality(b.p, null))}');
      },
    ),
    // ---------------------------------------------------------------- two-wire
    cadOp(
      b,
      group: _group,
      name: 'two_wire_system',
      description:
          'Reads the two-wire (decoder) wiring of the project (Zone → Two-wire system) with its settings: for every controller the wire of the pair, the route and cable length, the decoders, the most stations open, the peak current, the worst decoder voltage and the largest distance the wire allows; the decoders by outputs, the grounding points and the messages. When two-wire is on, the bill of materials lists these instead of the station wires. No input.',
      schema: obj({}),
      run: (a, _) async => ToolOutput(_twoWireText(b, designTwoWire(b.p, flows: wiringFlows(b.p), spec: twoWireSpecOf(b.p.agb.twoWire)))),
    ),
    cadOp(
      b,
      group: _group,
      name: 'set_two_wire',
      effect: ToolEffect.write,
      description:
          'Changes the two-wire settings (one undo step; the results are discarded). Give only what changes: enabled (two-wire in the design and the bill of materials), output_volts, min_volts, idle_ma (decoder idle current), solenoid_reach_m, ground_every_decoders, ground_every_m, decoder_prices ({"1": price, "2": …, "4": …, "6": …}), arrester_price. Output: the two-wire design with the new settings.',
      schema: obj({
        'enabled': bool_(),
        'output_volts': num_('1-100 V.'),
        'min_volts': num_('1-100 V.'),
        'idle_ma': num_('0-100 mA.'),
        'solenoid_reach_m': num_('0-1000 m.'),
        'ground_every_decoders': int_('0-999.'),
        'ground_every_m': num_('0-10000 m.'),
        'decoder_prices': {'type': 'object', 'description': 'Outputs of the decoder ("1", "2", "4", "6") → price.'},
        'arrester_price': num_(),
      }),
      run: (a, i) async {
        if (i.isEmpty) throw ToolInputError('Give at least one setting to change.');
        _setAgb(b, 'set_two_wire', (d) {
          final s = d.twoWire;
          s.enabled = a.flag('enabled') ?? s.enabled;
          s.outputVolts = a.number('output_volts', min: 1, max: 100) ?? s.outputVolts;
          s.minVolts = a.number('min_volts', min: 1, max: 100) ?? s.minVolts;
          s.decoderIdleMa = a.number('idle_ma', min: 0, max: 100) ?? s.decoderIdleMa;
          s.solenoidReachM = a.number('solenoid_reach_m', min: 0, max: 1000) ?? s.solenoidReachM;
          s.groundEveryDecoders = a.integer('ground_every_decoders', min: 0, max: 999) ?? s.groundEveryDecoders;
          s.groundEveryM = a.number('ground_every_m', min: 0, max: 10000) ?? s.groundEveryM;
          s.arresterPrice = a.number('arrester_price', min: 0) ?? s.arresterPrice;
          final prices = i['decoder_prices'];
          if (prices != null) {
            if (prices is! Map) throw ToolInputError('"decoder_prices" must be an object {"1": price, …}.');
            for (final e in prices.entries) {
              final k = int.tryParse('${e.key}');
              if (k == null || e.value is! num || (e.value as num) < 0) throw ToolInputError('decoder_prices: "${e.key}" must be outputs → a price ≥ 0.');
              s.decoderPrices[k] = (e.value as num).toDouble();
            }
          }
        });
        final r = designTwoWire(b.p, flows: wiringFlows(b.p), spec: twoWireSpecOf(b.p.agb.twoWire));
        return ToolOutput('Two-wire settings changed; design results discarded (run_design again).\n${_twoWireText(b, r)}');
      },
    ),
    // ---------------------------------------------------------------- several pivots
    cadOp(
      b,
      group: _group,
      name: 'multi_pivot_layout',
      effectFor: (i) => i['apply'] == false ? ToolEffect.read : ToolEffect.write,
      args: (i) => {'n': '${i['field'] ?? ''}'},
      description:
          'Arranges several centre pivots of standard spans in a property outline (Design → Automatic → Several pivots): the arrangement that irrigates the most area (the largest first, and lattices of equal machines grown where they stand), with a clearance between wetted circles and from the boundary, avoiding the obstacles and the pivots drawn, within the flow allowed, and the common mainline from the first water supply (minimum spanning tree). Inputs: field (closed shape id or name; default the selection), obstacles (closed shape ids), end_throw_m, clearance_m, min_radius_m, max_pivots, min_spans, max_spans, max_flow_m3h (0 = no limit), depth_mm and hours (gross depth per revolution for each flow), corners (part-circle pivots in the corners left), mainline (draw the pipes, default true), apply (default true; false only reports). Output: the machines (centre, radius, towers, area, flow), coverage, total flow, mainline length.',
      schema: obj({
        'field': str('Closed shape of the property.'),
        'obstacles': arr(str(), 'Closed shapes to keep clear of.'),
        'end_throw_m': num_('0-100 m.'),
        'clearance_m': num_('0-500 m.'),
        'min_radius_m': num_('20-2000 m.'),
        'max_pivots': int_('1-60.'),
        'min_spans': int_('1-30.'),
        'max_spans': int_('1-30.'),
        'max_flow_m3h': num_('0 = no limit.'),
        'depth_mm': num_('0.5-100 mm.'),
        'hours': num_('1-240 h.'),
        'corners': bool_(),
        'mainline': bool_(),
        'apply': bool_(),
      }),
      run: (a, i) async {
        final (fieldId, field) = _field(b, a.str('field'), 'property');
        final obstacles = <List<Pt>>[
          for (final ref in a.strings('obstacles'))
            closedOutlineOf(b.p, b.find(ref).id) ?? (throw ToolInputError('obstacles: "$ref" is not a closed shape.')),
          for (final p in b.p.entities.whereType<PivotEntity>()) p.outline(),
        ];
        final depth = a.number('depth_mm', min: 0.5, max: 100) ?? 8;
        final hours = a.number('hours', min: 1, max: 240) ?? 21;
        final minSpans = a.integer('min_spans', min: 1, max: 30) ?? 2;
        final o = MultiPivotOptions(
          obstacles: obstacles,
          endThrowM: a.number('end_throw_m', min: 0, max: 100) ?? 5,
          clearanceM: a.number('clearance_m', min: 0, max: 500) ?? 5,
          minRadiusM: a.number('min_radius_m', min: 20, max: 2000) ?? 100,
          maxPivots: a.integer('max_pivots', min: 1, max: 60) ?? 12,
          minSpans: minSpans,
          maxSpans: [a.integer('max_spans', min: 1, max: 30) ?? 12, minSpans].reduce((x, y) => x > y ? x : y),
          maxTotalFlow: (a.number('max_flow_m3h', min: 0) ?? 0) / 3600,
          grossDepthMm: depth,
          hoursPerCycle: hours,
          corners: a.flag('corners') ?? false,
          supply: b.p.entities.whereType<WaterSupplyEntity>().firstOrNull?.position,
        );
        final l = await engSoon(() => layoutPivots(field, o));
        final rows = engTable(
          ['#', 'centre', 'wetted radius m', 'towers', 'sector °', 'area ha', 'flow m³/h'],
          [
            for (var k = 0; k < l.pivots.length; k++)
              [
                '${k + 1}',
                AgentToolbox.pt(l.pivots[k].center),
                engN(l.pivots[k].irrigatedRadius, 1),
                '${l.pivots[k].spans.count}',
                engN(l.pivots[k].sectorSweepDeg, 0),
                engN(l.pivots[k].areaM2 / 1e4, 2),
                engN(l.pivots[k].flow * 3600, 1),
              ],
          ],
        );
        final summary =
            '${l.pivots.length} pivots (${l.strategy}) in $fieldId: ${engN(l.irrigatedAreaM2 / 1e4, 2)} ha of ${engN(l.fieldAreaM2 / 1e4, 2)} ha (${engN(l.coverage * 100, 1)} %), total flow ${engN(l.totalFlow * 3600, 1)} m³/h, mainline ${engN(l.mainlineLengthM, 0)} m.';
        if (i['apply'] == false || l.pivots.isEmpty) return ToolOutput('$summary\n$rows${engCodes(b, l.messages)}');
        engNotBusy(c);
        final mainline = a.flag('mainline') ?? true;
        final ids = b.change('multi_pivot_layout', () {
          final p = b.p;
          final first = p.entities.whereType<PivotEntity>().length;
          final made = <String>[];
          for (var k = 0; k < l.pivots.length; k++) {
            final e = l.pivots[k].toEntity(p, name: '${b.t('tool.pivot')} ${first + k + 1}', grossDepthMm: depth, hoursPerCycle: hours);
            p.entities.add(e);
            made.add(e.id);
          }
          if (mainline) {
            for (final (x, y) in l.mainline) {
              p.entities.add(PipeEntity(id: p.newId(), points: [x, y], scope: HydraulicScope.mainline));
            }
          }
          return made;
        });
        return ToolOutput('Drawn: pivots ${ids.join(', ')}${mainline ? ' and ${l.mainline.length} mainline pipes' : ''}. $summary\n$rows${engCodes(b, l.messages)}');
      },
    ),
    // ---------------------------------------------------------------- travellers and furrows
    cadOp(
      b,
      group: _group,
      name: 'traveller_lanes',
      effectFor: (i) => i['apply'] == false ? ToolEffect.read : ToolEffect.write,
      args: (i) => {'n': '${i['field'] ?? ''}'},
      description:
          'Lays travelling-gun (hose reel) lanes across a field (Mainline → Traveller lanes): parallel lanes in a direction, spaced by the NRCS NEH 623 wind table for the gun\'s wetted diameter (or a given spacing), each starting at a hydrant on the field edge and running the hose length; every lane is a traveller item, a demand on the mainline at its hydrant. Inputs: field (closed shape; default the selection), angle_deg (lane direction, counter-clockwise from east; default across the longest edge), gun and nozzle (catalogue gun), gun_flow_m3h and wetted_diameter_m (without a gun), gun_pressure_m, sector_deg, hose_m (0 = the run), hose_bore_mm, drive_loss_m, lane_width_m (0 = table), depth_mm, wind (none | light | moderate | strong), setup_h, hours_per_day, machine (reel label), machine_cost, hydrant_cost, hydrant_line (draw a mainline through the hydrants, default true), flows (one system flow per lane, default true), apply (default true; false only reports). Change one lane later with update_entities (type traveller).',
      schema: obj({
        'field': str('Closed shape of the field.'),
        'angle_deg': num_('Lane direction, degrees from east.'),
        'gun': str('Catalogue gun id.'),
        'nozzle': str('Nozzle id of the gun.'),
        'gun_flow_m3h': num_('m³/h without a gun.'),
        'wetted_diameter_m': num_('m without a gun.'),
        'gun_pressure_m': num_('5-150 m.'),
        'sector_deg': num_('30-360°.'),
        'hose_m': num_('0-2000 m.'),
        'hose_bore_mm': num_('20-200 mm.'),
        'drive_loss_m': num_('0-50 m.'),
        'lane_width_m': num_('0-300 m.'),
        'depth_mm': num_('1-200 mm.'),
        'wind': str(null, [for (final w in WindClass.values) w.name]),
        'setup_h': num_('0-24 h.'),
        'hours_per_day': num_('1-24 h.'),
        'machine': str('Reel label.'),
        'machine_cost': num_(),
        'hydrant_cost': num_(),
        'hydrant_line': bool_(),
        'flows': bool_(),
        'apply': bool_(),
      }),
      run: (a, i) async {
        final (fieldId, field) = _field(b, a.str('field'), 'lanes');
        var angle = a.number('angle_deg');
        if (angle == null) {
          var longest = 0.0;
          for (var k = 0; k < field.length; k++) {
            final d = field[(k + 1) % field.length] - field[k];
            if (d.length > longest) {
              longest = d.length;
              angle = radToDeg(d.angle) + 90;
            }
          }
        }
        final t = TravellerEntity(id: '', start: Pt.zero, end: const Pt(100, 0));
        if (a.has('gun')) {
          final g = b.p.catalog.outlet(a.str('gun'));
          if (g == null || g.kind != OutletKind.gun) throw ToolInputError('"${a.str('gun')}" is not a gun of the catalogue.');
          t.gunSpecId = g.id;
          t.gunNozzleId = a.str('nozzle') ?? g.nozzles.firstOrNull?.id;
          if (g.nozzle(t.gunNozzleId) == null) throw ToolInputError('"${t.gunNozzleId}" is no nozzle of ${g.id}: ${g.nozzles.map((n) => n.id).join(', ')}.');
        }
        final q = a.number('gun_flow_m3h', min: 0.01, max: 3600);
        if (q != null) t.gunFlow = q / 3600;
        t.wettedDiameterM = a.number('wetted_diameter_m', min: 5, max: 300) ?? t.wettedDiameterM;
        t.gunPressureM = a.number('gun_pressure_m', min: 5, max: 150) ?? t.gunPressureM;
        t.sectorDeg = a.number('sector_deg', min: 30, max: 360) ?? t.sectorDeg;
        t.hoseLengthM = a.number('hose_m', min: 0, max: 2000) ?? t.hoseLengthM;
        t.hoseInnerMm = a.number('hose_bore_mm', min: 20, max: 200) ?? t.hoseInnerMm;
        t.driveLossM = a.number('drive_loss_m', min: 0, max: 50) ?? t.driveLossM;
        t.laneWidthM = a.number('lane_width_m', min: 0, max: 300) ?? t.laneWidthM;
        t.targetDepthMm = a.number('depth_mm', min: 1, max: 200) ?? t.targetDepthMm;
        if (a.has('wind')) t.wind = WindClass.values.byName(a.str('wind')!);
        t.setupHours = a.number('setup_h', min: 0, max: 24) ?? t.setupHours;
        t.hoursPerDay = a.number('hours_per_day', min: 1, max: 24) ?? t.hoursPerDay;
        t.machine = a.str('machine') ?? t.machine;
        t.machineCost = a.number('machine_cost', min: 0) ?? t.machineCost;
        t.hydrantCost = a.number('hydrant_cost', min: 0) ?? t.hydrantCost;
        String laneName(int k) => '${b.t('agb.rep.lane')} ${k + 1}';
        var seq = 0;
        final preview = layoutTravellerLanes(b.p, field, t, angleDeg: angle ?? 0, newId: () => 'preview${seq++}', name: laneName);
        final terrain = b.p.buildTerrain();
        final rows = engTable(
          ['lane', 'hydrant', 'far end', 'run m', 'spacing m', 'speed m/min', 'depth mm', 'lane h', 'required m'],
          [
            for (final l in preview)
              () {
                final r = analyzeTravellerLane(b.p, l, terrain: terrain);
                return [
                  l.name,
                  AgentToolbox.pt(l.start),
                  AgentToolbox.pt(l.end),
                  engN(r.result.laneLengthM, 0),
                  engN(r.result.laneSpacingM, 1),
                  engN(r.result.speedMPerMin, 2),
                  engN(r.result.grossDepthMm, 1),
                  engN(r.result.laneHours, 1),
                  engN(r.requiredHead, 1),
                ];
              }(),
          ],
        );
        final summary = '${preview.length} lanes across $fieldId at ${engN(angle ?? 0, 0)}°.';
        if (i['apply'] == false || preview.isEmpty) return ToolOutput('$summary\n$rows');
        engNotBusy(c);
        final line = a.flag('hydrant_line') ?? true, flows = a.flag('flows') ?? true;
        final ids = b.change('traveller_lanes', () {
          final p = b.p;
          final made = layoutTravellerLanes(p, field, t, angleDeg: angle ?? 0, newId: p.newId, name: laneName);
          p.layerNamed(Layers.travellers);
          p.entities.addAll(made);
          if (line && made.length > 1) p.entities.add(PipeEntity(id: p.newId(), points: [for (final l in made) l.start], scope: HydraulicScope.mainline));
          if (flows && made.isNotEmpty) agbAddFlows(p, made, b.t('name.allZones'));
          return [for (final l in made) l.id];
        });
        return ToolOutput('Drawn lanes ${ids.join(', ')}${line && ids.length > 1 ? ' and the hydrant line' : ''}${flows ? ', one system flow each' : ''}. $summary\n$rows');
      },
    ),
    cadOp(
      b,
      group: _group,
      name: 'furrow_set',
      effectFor: (i) => i['apply'] == false ? ToolEffect.read : ToolEffect.write,
      args: (i) => {'n': '${i['line'] ?? ''}'},
      description:
          'Draws a furrow set fed from a head line (Mainline → Furrows with gated pipe): the furrows run from the line (its first point is the inlet on the mainline) to one side; the FAO 45 volume balance finds the inflow per furrow of the highest efficiency (or the one given) and the cutoff for the depth, and the gated pipe of the farthest set the pressure at the inlet. Inputs: line (line or polyline id or name; default the selection), right (furrows to the right), length_m, spacing_m, slope, family (NRCS intake family in/h), manning, depth_mm, inflow_lps (0 = best), per_set (0 = all), gated (default true; false = head ditch with siphons), pipe_bore_mm, pipe_cost, gate_cost, flow (a system flow for it, default true), apply (default true; false only reports). Change it later with update_entities (type furrows).',
      schema: obj({
        'line': str('Head line (line or polyline).'),
        'right': bool_(),
        'length_m': num_('10-2000 m.'),
        'spacing_m': num_('0.2-5 m.'),
        'slope': num_('0-0.05 m/m.'),
        'family': num_('0.05-4 in/h.'),
        'manning': num_('0.01-0.2.'),
        'depth_mm': num_('5-300 mm.'),
        'inflow_lps': num_('0-20 L/s.'),
        'per_set': int_('0 = all.'),
        'gated': bool_(),
        'pipe_bore_mm': num_('50-500 mm.'),
        'pipe_cost': num_(),
        'gate_cost': num_(),
        'flow': bool_(),
        'apply': bool_(),
      }),
      run: (a, i) async {
        Entity? src;
        if (a.has('line')) {
          src = b.find(a.str('line')!);
        } else {
          src = [for (final id in c.selection) b.p.byId(id)].whereType<Entity>().where((e) => (e.linearPoints?.length ?? 0) >= 2).firstOrNull;
        }
        final pts = src?.linearPoints;
        if (src == null || pts == null || pts.length < 2) throw ToolInputError('Give "line": a line or polyline for the head of the furrows.');
        final f = FurrowEntity(id: '', name: '${b.t('agb.rep.furrowSet')} ${b.p.entities.whereType<FurrowEntity>().length + 1}', points: List.of(pts));
        f.leftSide = !(a.flag('right') ?? false);
        f.furrowLengthM = a.number('length_m', min: 10, max: 2000) ?? f.furrowLengthM;
        f.furrowSpacingM = a.number('spacing_m', min: 0.2, max: 5) ?? f.furrowSpacingM;
        f.slope = a.number('slope', min: 0, max: 0.05) ?? f.slope;
        f.intakeFamily = a.number('family', min: 0.05, max: 4) ?? f.intakeFamily;
        f.manningN = a.number('manning', min: 0.01, max: 0.2) ?? f.manningN;
        f.requiredDepthMm = a.number('depth_mm', min: 5, max: 300) ?? f.requiredDepthMm;
        f.inflowLps = a.number('inflow_lps', min: 0, max: 20) ?? f.inflowLps;
        f.furrowsPerSet = a.integer('per_set', min: 0, max: 100000) ?? f.furrowsPerSet;
        f.gatedPipe = a.flag('gated') ?? f.gatedPipe;
        f.pipeInnerMm = a.number('pipe_bore_mm', min: 50, max: 500) ?? f.pipeInnerMm;
        f.pipeCostPerM = a.number('pipe_cost', min: 0) ?? f.pipeCostPerM;
        f.gateCost = a.number('gate_cost', min: 0) ?? f.gateCost;
        final r = await engSoon(() => analyzeFurrowSet(b.p, f, terrain: b.p.buildTerrain()));
        final text =
            '${r.furrows} furrows, ${r.perSet} per set × ${r.sets} sets; ${engN(r.inflow * 1000, 2)} L/s per furrow (${engN(r.setFlow * 3600, 1)} m³/h per set), advance ${engN(r.advanceS / 60, 0)} min, cutoff ${engN(r.cutoffS / 60, 0)} min, '
            'irrigation of all ${engN(r.irrigationHours, 1)} h; Ea ${engN(r.efficiency * 100, 0)} %, DU ${engN(r.lowQuarterDu * 100, 0)} %, tailwater ${engN(r.tailwaterRatio * 100, 0)} %; inlet head ${engN(r.inletHeadM, 2)} m.'
            '${engCodes(b, r.warnings)}';
        if (i['apply'] == false) return ToolOutput(text);
        engNotBusy(c);
        final flow = a.flag('flow') ?? true;
        final id = b.change('furrow_set', () {
          final p = b.p;
          final e = f.clone(newId: p.newId());
          p.layerNamed(Layers.surface);
          p.entities.add(e);
          if (flow) agbAddFlows(p, [e], b.t('name.allZones'));
          return e.id;
        });
        return ToolOutput('Drew furrow set $id${flow ? ' with a system flow' : ''}: $text');
      },
    ),
    cadOp(
      b,
      group: _group,
      name: 'field_machines',
      description:
          'Reads the traveller lanes and furrow sets of the drawing as the report shows them: per lane the reel, run, spacing, flow, speed, depth, travel and lane hours, application rate, hose loss, the head needed at the hydrant and the head the design leaves there; per furrow set the furrows, sets, inflow, advance and cutoff, the hours of an irrigation, efficiency, uniformity, tailwater and the inlet heads. Uses the design results when there are; else analyses the items as drawn (no available heads). No input.',
      schema: obj({}),
      run: (a, _) async => ToolOutput(await engSoon(() => _fieldMachinesText(b))),
    ),
  ];
}
