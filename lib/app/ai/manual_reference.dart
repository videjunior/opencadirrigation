/// The reference topics of the AI assistant's manual that are read from the
/// program when asked for: design parameters, the catalogue, every message
/// code, the typical values the engine uses, units, report tables and
/// exports, the playbooks and the agronomy tables. A sentence of prose
/// frames each table; the numbers and lists come from the engine, the
/// defaults and the open project, so they cannot drift from it.
library;

import 'dart:math' as math;

import '../../core/ai/agent_loop.dart';
import '../../core/design/advisor.dart';
import '../../core/design/auto_layout.dart' show LandscapeLayoutOptions;
import '../../core/design/crops.dart' show fao56Crops;
import '../../core/design/effective_rain.dart' show EffectiveRainMethod;
import '../../core/design/pivot.dart' show PivotKind, PivotSpec;
import '../../core/design/pivot_fit.dart' show defaultSpanLengths, defaultOverhangs;
import '../../core/design/results.dart';
import '../../core/design/soils.dart' show soilTable;
import '../../core/design/tree_rings.dart' show TreeRingOptions;
import '../../core/design/water_budget.dart' show PlantWaterUse;
import '../../core/hydraulics/emitter.dart';
import '../../core/hydraulics/pump.dart' show maxSuctionLift;
import '../../core/hydraulics/uniformity.dart';
import '../../core/io/project_export.dart' show DrawingFormat, ReportFormat;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/units.dart';
import '../i18n.dart';
import 'agent_tools.dart';
import 'agent_tools_edit.dart';
import 'manual_entities.dart' show numText, sampleEntity;
import 'playbooks.dart';

final _en = I18n('en');

String _n(double v) => numText(v);
String _lph(double m3s) => '${_n(roundTo(m3s * 3.6e6, 2))} L/h';

// ---------------------------------------------------------------- parameters

/// The "parameters" topic: every design parameter with its project-file
/// key, current value, default, unit, range and effect.
String parametersTopic(AgentToolbox b, String? item) {
  final p = b.p.params;
  final d = DesignParameters();
  final list = item == null || item.trim().isEmpty
      ? designParameters
      : [
          for (final x in designParameters)
            if (x.name.toLowerCase() == item.trim().toLowerCase() || x.jsonKey.toLowerCase() == item.trim().toLowerCase()) x,
        ];
  if (list.isEmpty) throw ToolInputError('No design parameter "$item". Names: ${designParameters.map((x) => x.name).join(', ')}.');
  final out = StringBuffer(
    '# Design parameters\n'
    'set_parameters {"values": {"name": value}} changes them (one undo step; the design results are discarded); get_parameters lists the current values. Values are SI as listed, whatever the display units.\n'
    'name (key in the project file) = current value [default] unit (allowed) — effect\n',
  );
  for (final x in list) {
    final def = x.name == 'powerCostPerKwh' ? '${x.get(d)} ${d.currency}, before conversion to the project currency' : '${x.get(d)}';
    out.writeln('- ${x.name} (${x.jsonKey}) = ${x.get(p)} [$def]${x.unit.isEmpty ? '' : ' ${x.unit}'} (${x.range})${x.note.isEmpty ? '' : ' — ${x.note}'}');
  }
  if (item == null) {
    out.writeln('\nNot changed by set_parameters:');
    for (final e in otherParameterKeys.entries) {
      out.writeln(
        '- ${e.key}: ${e.value}. Now: ${switch (e.key) {
          'units' => 'flow ${b.u.flowLabel}, pressure ${b.u.pressureLabel}, length ${b.u.lengthLabel}, diameter ${b.u.diameterLabel}',
          'currency' => p.currency,
          _ => p.currencyCode.isEmpty ? '(unknown)' : p.currencyCode,
        }}.',
      );
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------- catalogue

String _list(Iterable<String> items, [int max = 24]) {
  final l = items.toList();
  return l.length <= max ? l.join(', ') : '${l.take(max).join(', ')} … (${l.length - max} more)';
}

String _range(Iterable<double> v, String unit, [double f = 1]) {
  final l = [
    for (final x in v)
      if (x.isFinite) x * f,
  ];
  if (l.isEmpty) return '-';
  final lo = l.reduce(math.min), hi = l.reduce(math.max);
  final u = unit.isEmpty ? '' : ' $unit';
  return lo == hi ? '${_n(roundTo(lo, 2))}$u' : '${_n(roundTo(lo, 2))}–${_n(roundTo(hi, 2))}$u';
}

/// The "catalog" topic: how the catalogue works and what this project's
/// holds.
String catalogTopic(AgentToolbox b, String? item) {
  final cat = b.p.catalog;
  final out = StringBuffer('''# Catalogue
The project carries its own catalogue, saved in the project file: pipes, emitters (${OutletKind.values.map((k) => k.name).join(', ')}) with their nozzles, drip tapes, valves and in-line devices, pumps, fittings and wires. Every item is referred to by its id (spec, outlet, nozzle…); ids are case-sensitive. The default catalogue uses short generic ids (pe16, pvc75, rotor, micro, drip16_16_50, ev40, filter_disc80, pump_c5…) with illustrative prices; manufacturer packs (Design → Catalogue packs) add the makers' models with a brand prefix in the id; edit_catalog adds items typed from a data sheet (ids such as pipe3, out2 unless one is given).
- search_catalog {kind, query, usage} lists the items with the data the design uses. Disabled items are never used by the design and are hidden unless include_disabled.
- Pipes have usages: lateral (spraylines), zone (zone pipes), mainline. The design sizes a pipe from the enabled pipes of its usage that are rated for the pressure found (PVC and PE classes are derated in warm water). The class is given as metres of head (PN 6 = 60 m).
- Emitter nozzles: flow q = k·h^x (x 0.5 for an orifice, about 0 when pressure compensating), a pressure range (min/max head), a nominal pressure, a wetted radius growing with pressure, an arc, the manufacturer CV and a flow tolerance (default ±5 %) that sets the pressure window.
- Tapes and driplines: inner Ø, emitter spacing and curve, a pressure range, and a window of the inlet pressure (default −30 % / +20 %).
- Valves and devices by kind: ${ValveKind.values.map((k) => k.name).join(', ')}. Control valves are zone valves: the zone flow must fall within their flow range. Each has a loss curve (head loss at a flow); PRV and PSV a setting.
- Pumps: a head–flow curve of at least 3 points, efficiency, rated power and frequency, the submersible flag and a flow range.
- Prices are in the project currency; unpriced items count 0 in the bill of materials (bom_unpriced).

## This project's catalogue
''');
  final suppliers = <String>{
    for (final x in [
      ...cat.pipes.map((e) => e.supplier),
      ...cat.outlets.map((e) => e.supplier),
      ...cat.tapes.map((e) => e.supplier),
      ...cat.valves.map((e) => e.supplier),
      ...cat.pumps.map((e) => e.supplier),
    ])
      if (x.trim().isNotEmpty) x.trim(),
  };
  out.writeln('Suppliers: ${suppliers.isEmpty ? 'none named (the generic catalogue)' : _list(suppliers, 20)}. Currency ${b.p.params.currency}.');
  for (final u in PipeUsage.values) {
    final l = cat.pipesFor(u);
    out.writeln(
      '- pipes, usage ${u.name}: ${l.length} enabled, inner Ø ${_range(l.map((x) => x.innerDiameterMm), 'mm')}, classes ${_range(l.map((x) => x.pressureRatingM), 'm')}: ${_list(l.map((x) => x.id))}',
    );
  }
  final offPipes = cat.pipes.where((x) => !x.enabled).length;
  if (offPipes > 0) out.writeln('  ($offPipes pipes disabled)');
  for (final k in OutletKind.values) {
    final l = [
      for (final o in cat.outlets)
        if (o.enabled && o.kind == k) o,
    ];
    if (l.isEmpty) continue;
    final nz = [for (final o in l) ...o.nozzles];
    out.writeln(
      '- emitters, ${k.name}: ${l.length}, ${nz.length} nozzles, ${_range([for (final z in nz) z.curve.flow(z.defaultHeadM)], 'L/h', 3.6e6)} at their nominal pressure, least pressure ${_range([for (final z in nz) z.minHeadM], 'm')}, greatest ${_range([for (final z in nz) z.maxHeadM], 'm')}: ${_list(l.map((o) => '${o.id} (${o.nozzles.length})'), 16)}',
    );
  }
  final tapes = [
    for (final x in cat.tapes)
      if (x.enabled) x,
  ];
  if (tapes.isNotEmpty) {
    out.writeln(
      '- tapes: ${tapes.length}: ${_list(tapes.map((x) => '${x.id} (${_n(roundTo(x.emitter.flow(x.defaultInletHeadM) * 3.6e6, 2))} L/h every ${_n(x.emitterSpacingM)} m, ${_n(x.minHeadM)}–${_n(x.maxHeadM)} m)'), 12)}',
    );
  }
  for (final k in ValveKind.values) {
    final l = [
      for (final v in cat.valves)
        if (v.enabled && v.kind == k) v,
    ];
    if (l.isEmpty) continue;
    out.writeln(
      '- valves, ${k.name}: ${_list(l.map((v) => k == ValveKind.control || k == ValveKind.master ? '${v.id} (${_n(roundTo(v.minFlow * 3600, 1))}–${_n(roundTo(v.maxFlow * 3600, 1))} m³/h)' : (v.defaultSettingM > 0 ? '${v.id} (set ${_n(v.defaultSettingM)} m)' : v.id)), 16)}',
    );
  }
  final pumps = [
    for (final x in cat.pumps)
      if (x.enabled) x,
  ];
  if (pumps.isNotEmpty) {
    out.writeln(
      '- pumps: ${pumps.length} (${pumps.where((x) => x.submersible).length} submersible), up to ${_range(pumps.map((x) => x.maxFlow), 'm³/h', 3600)} and shut-off heads ${_range(pumps.map((x) => x.points.first.$2), 'm')}: ${_list(pumps.map((x) => x.id), 30)}',
    );
  }
  out.writeln(
    '- fittings: ${cat.fittings.where((f) => f.enabled).length} enabled; wires: ${cat.wires.where((w) => w.enabled).length} enabled (${_range(cat.wires.where((w) => w.enabled).map((w) => w.sectionMm2), 'mm²')}).',
  );
  out.writeln('search_catalog gives each item\'s data.');
  return out.toString();
}

// ---------------------------------------------------------------- messages

/// Severity of every message code, as the advisor gives it.
Map<String, AdviceLevel> adviceLevels() {
  // every code reported once by a design result: the advisor sets the level
  final p = Project(
    entities: [WaterSupplyEntity(id: 'manual_supply', position: Pt.zero)],
  );
  final r = DesignResults(timestamp: DateTime(2000))..messages.addAll(adviceCodes);
  final out = <String, AdviceLevel>{};
  for (final a in buildAdvice(p, results: r)) {
    out.putIfAbsent(a.code, () => a.level);
  }
  return out;
}

/// English title of message [code].
String adviceTitleEn(String code) {
  for (final k in ['check.$code', 'warn.$code', 'adv.$code.title']) {
    if (_en.has(k)) return _en(k);
  }
  final why = _en.has('adv.$code.why') ? _en('adv.$code.why') : code;
  final dot = why.indexOf('. ');
  return dot > 0 ? why.substring(0, dot) : why;
}

/// The "messages" topic: the index of every code, or one code in full.
String messagesTopic(AgentToolbox b, String? item) {
  final levels = adviceLevels();
  String fixLabel(FixKind f) => _en.has('fix.${f.name}') ? _en('fix.${f.name}', {'d': _n(roundTo(connectReach(b.p), 1))}) : f.name;
  if (item != null && item.trim().isNotEmpty) {
    final code = adviceCode(item.trim());
    if (!adviceCodes.contains(code)) throw ToolInputError('No message code "$item". Codes: ${adviceCodes.join(', ')}.');
    return '## $code (${levels[code]?.name ?? '?'}): ${adviceTitleEn(code)}\n'
        'Why: ${_en.has('adv.$code.why') ? _en('adv.$code.why') : '-'}\n'
        'How to fix: ${_en.has('adv.$code.how') ? _en('adv.$code.how') : '-'}\n'
        'The corrections offered for a message depend on the items involved: get_design_messages lists them, apply_fix applies one.';
  }
  final out = StringBuffer('''# Design messages
get_design_messages lists the current messages: number, severity, code, the items involved, why and how (once per code) and the corrections offered. Severity: error = the design is wrong or incomplete, its numbers are not to be trusted; warning = it works but breaks a limit or a good practice; info = worth knowing. Messages about pressures and flows exist only after a design. read_manual {"topic": "messages", "item": "<code>"} gives why and how for one code.

## Codes
''');
  for (final code in adviceCodes) {
    out.writeln('- $code (${levels[code]?.name ?? '?'}): ${adviceTitleEn(code)}');
  }
  out.writeln('\n## Corrections (apply_fix "fix"; * = applied by auto_fix, † = needs design results)');
  for (final f in FixKind.values) {
    out.writeln('- ${f.name}${autoSafeFixes.contains(f) ? '*' : ''}${resultFixes.contains(f) ? '†' : ''}: ${fixLabel(f)}');
  }
  return out.toString();
}

// ---------------------------------------------------------------- typical values

/// The "values" topic: the values the engine uses, read from its defaults
/// and from the default catalogue.
String valuesTopic(AgentToolbox b) {
  final d = DesignParameters();
  final cat = Catalog.defaultCatalog();
  final orifice = const EmitterCurve(k: 1, x: 0.5).headWindow(1);
  final out = StringBuffer('# Typical values as the engine uses them\n');
  out.writeln('## Velocity limits (defaults; set_parameters changes them)');
  out.writeln(
    '- laterals ${_n(d.maxLateralVelocity)} m/s, zone pipes ${_n(d.maxZoneVelocity)} m/s, mainline ${_n(d.maxMainlineVelocity)} m/s; pivot span pipe ${_n(const PivotSpec(kind: PivotKind.pivot, lengthM: 400).maxVelocity)} m/s. The sizing keeps every pipe within them; faster segments are flagged velocity_exceeded.',
  );
  out.writeln('## Pressure windows');
  out.writeln(
    '- An emitter allows the pressures that keep its flow within its nozzle\'s tolerance (default −${_n(NozzleSpec(id: 'x', name: 'x', curve: const EmitterCurve(k: 1, x: 0.5)).flowTolBelow * 100)} % / +${_n(NozzleSpec(id: 'x', name: 'x', curve: const EmitterCurve(k: 1, x: 0.5)).flowTolAbove * 100)} % of the nominal flow), within the nozzle\'s pressure range. For an orifice (x = 0.5) that is ${_n(roundTo(orifice.$1 * 100, 1))} %–${_n(roundTo(orifice.$2 * 100, 1))} % of the nominal pressure; a pressure-compensating emitter (x ≤ 0.01) takes its whole range.',
  );
  final tape = TapeSpec(id: 'x', name: 'x', innerDiameterMm: 16, emitterSpacingM: 0.3, emitter: const EmitterCurve(k: 1, x: 0.5));
  out.writeln(
    '- A tape allows −${_n(tape.tolBelowPct)} % / +${_n(tape.tolAbovePct)} % of its inlet pressure (the tape model\'s tolerance) within its pressure range. maxZoneVariationPct > 0 narrows any zone to its nominal pressure ± half that percentage.',
  );
  out.writeln(
    '- Surface pumps lift at most about ${_n(roundTo(maxSuctionLift(0), 1))} m at sea level (${_n(roundTo(maxSuctionLift(1000), 1))} m at 1000 m): the atmosphere less vapour pressure and an NPSH allowance; deeper water needs a submersible pump (pump_suction_lift).',
  );
  out.writeln('## The default catalogue (what its models assume)');
  for (final k in OutletKind.values) {
    final nz = [
      for (final o in cat.outlets)
        if (o.kind == k) ...o.nozzles,
    ];
    if (nz.isEmpty) continue;
    final radius = [
      for (final z in nz)
        if (z.curve.radius(z.defaultHeadM) > 0) z.curve.radius(z.defaultHeadM),
    ];
    out.writeln(
      '- ${k.name}: nominal pressure ${_range(nz.map((z) => z.defaultHeadM), 'm')}, least ${_range(nz.map((z) => z.minHeadM), 'm')}, greatest ${_range(nz.map((z) => z.maxHeadM), 'm')}, flow ${_range([for (final z in nz) z.curve.flow(z.defaultHeadM)], 'L/h', 3.6e6)}${radius.isEmpty ? '' : ', wetted radius ${_range(radius, 'm')}'}, manufacturer CV ${_range(nz.map((z) => z.cv), '')}.',
    );
  }
  for (final x in cat.tapes) {
    out.writeln(
      '- tape ${x.id}: ${_lph(x.emitter.flow(x.defaultInletHeadM))} every ${_n(x.emitterSpacingM)} m at ${_n(x.defaultInletHeadM)} m (range ${_n(x.minHeadM)}–${_n(x.maxHeadM)} m, x ${_n(x.emitter.x)}), inner Ø ${_n(x.innerDiameterMm)} mm, class ${_n(x.pressureRatingM)} m.',
    );
  }
  out.writeln(
    '- control valves: ${[for (final v in cat.valves.where((v) => v.kind == ValveKind.control)) '${v.id} ${_n(v.sizeMm)} mm for ${_n(roundTo(v.minFlow * 3600, 1))}–${_n(roundTo(v.maxFlow * 3600, 1))} m³/h'].join('; ')}.',
  );
  out.writeln('- pipe classes: ${[for (final u in PipeUsage.values) '${u.name} ${_range(cat.pipesFor(u).map((p) => p.pressureRatingM), 'm')}'].join('; ')}.');
  out.writeln('## Automations');
  final lay = LandscapeLayoutOptions();
  out.writeln(
    '- layout_sprinklers: head_to_head spacing = the wetted radius of the reference nozzle at the design pressure; percent_of_diameter default ${_n(lay.spacingPercent)} % of the wetted diameter; triangular rows 0.866 spacings apart; corners from ${_n(lay.cornerAngleDeg)}° get a head, sharper than ${_n(lay.minCornerArcDeg)}° none; heads never closer than ${_n(lay.minSpacingFraction * 100)} % of the spacing.',
  );
  out.writeln(
    '- generate_block and subdivide_field: first lateral half a spacing inside the area, a 1.5 m stub to the valve; subdivide_field defaults: 1.5 m (tape) or 12 m (spray) between laterals, blocks of 20 000 m², roads of 4 m.',
  );
  final rings = TreeRingOptions();
  out.writeln('- tree_rings (the tool\'s defaults): 6 × 7 m planting, ring radius 0.75 m (the engine\'s own default ${_n(rings.ringRadius)} m), ${rings.drippersPerTree} drippers per tree.');
  out.writeln('- fit_pivot: spans of ${defaultSpanLengths.map(_n).join(', ')} m, overhangs of ${defaultOverhangs.map(_n).join(', ')} m, end throw 5 m, sectors from 30°, 10 m clear of symbols.');
  final pv = sampleEntity('pivot') as PivotEntity;
  out.writeln(
    '- a new pivot item: span ${_n(pv.spanLengthM)} m, end pressure ${_n(pv.endPressureM)} m, ${_n(pv.grossDepthMm)} mm per ${_n(pv.hoursPerCycle)} h cycle, pipe ${_n(pv.pipeInnerMm)} mm C ${_n(pv.hazenC)}, ${_n(pv.pipeHeightM)} m high, machine losses ${_n(pv.machineLossM)} m, wetted width ${_n(pv.wettedWidthM)} m; the peak application rate is 4/π × the mean at the outer end.',
  );
  out.writeln('- suggest_air_valves: at most 800 m between air valves (AWWA M51), at least 400 m.');
  out.writeln('## Economics and wiring (defaults)');
  out.writeln(
    '- interest ${_n(d.interestRate * 100)} %/year over ${d.termYears} years, energy ${_n(d.powerCostPerKwh)} ${d.currency} per kWh (converted with the project currency), pump efficiency ${_n(d.pumpEfficiency)}, ${_n(d.hoursPerYear)} h/year on the mainline and ${_n(d.zoneHoursPerYear)} h/year per zone, minor losses ${_n(d.minorLossPct)} % of the length, connection tolerance ${_n(d.connectTolerance)} m.',
  );
  out.writeln(
    '- solenoids: ${_n(d.solenoidInrushA)} A inrush, ${_n(d.solenoidHoldingA)} A holding, open from ${_n(d.solenoidMinVolts)} V; ${_n(d.wireSlackPct)} % wire slack; mains ${_n(d.mainsHz)} Hz.',
  );
  out.writeln('## Uniformity classes (EU and CU)');
  final classes = <String, (int, int)>{};
  for (var v = 0; v <= 100; v++) {
    final c = UniformityStats.classify(v.toDouble());
    final r = classes[c];
    classes[c] = r == null ? (v, v) : (math.min(r.$1, v), math.max(r.$2, v));
  }
  out.writeln(
    '- ${[for (final e in classes.entries.toList().reversed) '${e.key} ${e.value.$1}–${e.value.$2} %'].join(', ')} (ASAE). EU is the Keller-Karmeli emission uniformity (the lowest emitter flow over the mean, with the manufacturer CV and the emitters per plant); CU the Christiansen coefficient; DU the low-quarter distribution uniformity.',
  );
  return out.toString();
}

// ---------------------------------------------------------------- units

/// The "units" topic: SI in the tools, the display units, the conversions.
String unitsTopic(AgentToolbox b) {
  final u = b.u;
  final bar = const Units(pressure: PressureUnit.bar), kpa = const Units(pressure: PressureUnit.kPa), psi = const Units(pressure: PressureUnit.psi);
  final m3h = const Units(flow: FlowUnit.m3h), lps = const Units(flow: FlowUnit.lps), gpm = const Units(flow: FlowUnit.gpm);
  return '''# Units
Tool inputs, item properties and set_parameters are SI as the project file holds them: lengths and coordinates m, flows m³/s, pressures as metres of water head (m), diameters in mm where the name says _mm, angles in degrees (arcs in radians). Inputs whose name ends in _m3h take m³/h, _lph L/h, _mm mm, _pct %. Reports, tables and get_project_summary use the project's display units, written in their headers: now flow ${u.flowLabel}, pressure ${u.pressureLabel}, length ${u.lengthLabel}, diameter ${u.diameterLabel}, velocity ${u.velocityLabel}, area ${u.areaLabel}, depth ${u.depthLabel} (Design → Units, or set_setting units.*, changes them).
Conversions (exact factors of the program):
- pressure: 1 m of head = ${_n(roundTo(bar.pressureFromHead(1), 6))} bar = ${_n(roundTo(kpa.pressureFromHead(1), 4))} kPa = ${_n(roundTo(psi.pressureFromHead(1), 5))} psi; 1 bar = ${_n(roundTo(bar.pressureToHead(1), 3))} m; 1 psi = ${_n(roundTo(psi.pressureToHead(1), 4))} m; 1 kPa = ${_n(roundTo(kpa.pressureToHead(1), 5))} m.
- flow: 1 m³/h = ${_n(roundTo(m3h.flowToSi(1), 9))} m³/s = ${_n(roundTo(lps.flowFromSi(m3h.flowToSi(1)), 4))} L/s = ${_n(roundTo(gpm.flowFromSi(m3h.flowToSi(1)), 3))} US gpm; 1 L/h = ${numText(m3sPerLph)} m³/s; 1 L/s = 3.6 m³/h; 1 gpm = ${_n(roundTo(gpm.flowToSi(1) * 3600, 4))} m³/h.
- length: 1 ft = $metersPerFoot m, 1 in = $metersPerInch m; area: 1 ha = 10 000 m², 1 acre = 4046.86 m².
- depth and rate: 1 mm over 1 ha = 10 m³; a flow Q (m³/h) over A (ha) applies Q / (10 × A) mm/h.
- energy: hydraulic power (kW) = 9.81 × Q (m³/s) × H (m); shaft power = that ÷ efficiency.
- elevation and pressure: 1 m of elevation = 1 m of head (water at 20 °C, ${_n(waterDensity)} kg/m³).''';
}

// ---------------------------------------------------------------- reports

/// What each report table holds (a test keeps it in step with
/// [reportTableKeys]).
const reportTableNotes = <String, String>{
  'zones': 'one row per zone: valve, emitters, flow, pressure after the valve, valve loss, pressure needed before it, lowest and highest emitter pressure against the allowed window, uniformity (CU, DU, EU)',
  'pipes': 'every pipe segment by zone or system flow: model, inner Ø, length, flow, velocity, head loss, pressures at both ends, class; ⚠ over the velocity limit or the class',
  'outlets': 'the emitters of each zone: count, flows, lowest and highest pressure and the window',
  'mainline': 'per system flow: each supply (flow, pressure available and needed) and each valve or pivot (flow, pressure available against needed, status)',
  'devices': 'pumps and in-line devices per system flow: flow, inlet and outlet pressure, head added or lost, pump speed and efficiency, suction',
  'vih': 'valve-in-head stations per system flow: heads, flow, pressures against the window',
  'flushing': 'flushing of the drip zones with the tape ends open: flow, pressures needed, end pressure and velocity',
  'surge': 'water hammer per pipe: velocity, wave celerity, surge, highest static pressure, class, closure and critical times',
  'bom': 'bill of materials: pipes by model and length, emitters, tapes, valves, devices, fittings, pumps, wires, with unit and total prices',
  'bomZones': 'the bill of materials split by zone, mainline, pivot and electrical',
  'proposal': 'the quote: the materials with markup, labour, trenches, extras, discount, taxes, freight and the payback (set_quote)',
  'trench': 'trench lengths, widths, depths and volumes by pipe',
  'works': 'the installation schedule: tasks, quantities, daily output, days, start and end',
  'electrical': 'valve wiring: zone, controller, station, route and wire length, wire size, voltage at the solenoid',
  'pivots': 'pivots and linears: type, towers, area, flow, inlet pressure needed and available, friction, application rate',
  'pivotSpans': 'per span of each machine: radii, sprinklers, flow, pressure',
  'pivotPackage': 'the sprinkler package of each machine: outlet by outlet, position, spacing, nozzle, pressure, flow',
  'pivotPackageSummary': 'per machine: sprinklers, design and delivered flow, pressures, regulators',
  'pivotTimer': 'percentage timer chart: timer %, hours per revolution, depth, end tower speed',
  'cornerArm': 'corner arm banks: radii, flows, valve schedule',
  'vri': 'variable-rate prescription by sector: timer and depth against the target',
  'pivotElectrical': 'pivot electrical design: towers, cable length, current, voltage drop',
  'crop': 'crop water requirement per area: ETc, readily available water, interval, net and gross depth per event, hours per event',
  'schedule': 'the controller programme: date, system flow, zones, start, end, duration, flow',
  'requirement': 'monthly irrigation requirement per area (FAO-56 with the site climate): ETo, Kc, Kr, ETc, effective rain, net and gross',
  'requirementTotals': 'the yearly totals of the requirement per area',
  'water': 'water use per area: area, gross depth, daily volume and flow',
  'licensing': 'water-use licence data per irrigation method: area, category and limits',
  'scenarios': 'the design alternatives saved for comparison and their figures',
  'comments': 'the review comments of the drawing',
  'revisions': 'the revision clouds: revision, date, description',
  'messages': 'the design messages, as get_design_messages lists them',
};

/// The "reports" topic: the report tables and the export formats.
String reportsTopic(AgentToolbox b) {
  final now = b.c.reportTables();
  final out = StringBuffer('# Reports and exports\nget_report_table {table, filter, offset, limit} reads a table exactly as the reports panel shows it, in the display units. The tables:\n');
  for (final k in reportTableKeys) {
    out.writeln('- $k: ${reportTableNotes[k] ?? ''}');
  }
  out.writeln(
    '\nAvailable now: ${now.isEmpty ? 'none' : now.map((t) => '${t.key} (${t.rows.length} rows)').join(', ')}${b.c.results == null ? '. Without design results only the tables that need none exist.' : '.'}',
  );
  out.writeln(
    '''
## Files (export_file; always confirmed by the user, only when asked)
- Drawing: ${DrawingFormat.values.map((f) => '${f.name} (.${f.extension}${f.needsGeoref ? ', needs a georeference' : ''})').join(', ')}. pdf is one plot sheet, dxf and dwg keep the layers, inp is an EPANET model of the network, landxml the terrain and pipes, shp a zipped shapefile set.
- Reports: ${ReportFormat.values.map((f) => 'report_${f.name}').join(', ')}: every report table (xlsx a sheet each); they need design results.
- project: the project file (.oci.json) with the catalogue and the results.

## Sheet sets (run_operation export_sheet_pdf; always confirmed, only when asked)
For drawings to build or to hand over, use export_sheet_pdf rather than export_file "pdf": it has every option of the plot dialog — page size and orientation, scale, labels, legend, the bill of materials beside the drawing, the base map under it, split "zones" or "areas" (an overview plus one sheet per zone or per irrigated area, the others in grey), extra sheets of chosen windows or of the user's view, construction detail sheets (trench, valve box, riser, drip connection, air valve, thrust block, pump suction, filter station), the report pages and the charts (grade lines, profiles, pump curves) after the sheets. export_sheet_png makes a picture of the sheet.''',
  );
  return out.toString();
}

// ---------------------------------------------------------------- playbooks

/// The "playbooks" topic: every playbook with what it is for.
String playbooksTopic(AgentToolbox b) => [
  '# Playbooks\nget_playbook {"id"} reads one: what to ask, the tools in order with their typical inputs, the values and the checks, written from how the example projects are built. read_example and open_example show those examples.',
  for (final p in playbooks) '- ${p.id}: ${p.title}. When: ${p.when} Examples: ${p.examples.map((e) => e.name).join(', ')}.',
].join('\n');

// ---------------------------------------------------------------- agronomy

/// The "agronomy" topic: how areas carry the crop and soil, and the tables
/// the program uses.
String agronomyTopic(AgentToolbox b) {
  final climate = b.p.climate;
  final out = StringBuffer('''# Agronomy
An area (create_entities type "area") carries the crop and soil data; the reports crop, schedule, requirement, requirementTotals and water read them, and the zones whose emitters lie in the area take its emitters per plant for the EU.
- Fixed depth: wb false and depth = net mm/day (default 5). Water balance: wb true, then ETc = eto × kc (mm/day); the readily available water = awc (mm/m) × root (m) × mad; interval = that ÷ ETc; gross depth per event = net ÷ eff; hours per event from the zone's precipitation (flow ÷ area). Localized irrigation (im "localized"): wf (wetted fraction) and gc (ground cover) reduce the area wetted and Kc.
- FAO-56 crop table (ck): the monthly requirement by growth stage uses the crop's Kc curve, planted on pd (MM-DD) or the table's month, with the site climate (download_climate) for ETo and rain. Setting ck through the tools sets only the key: set kc (mid-season), root and mad as well, as the properties panel does (values below).
- Effective rain (erm): ${EffectiveRainMethod.values.map((m) => m.name).join(', ')}; dep true uses the dependable (80 %) rain. Salinity: ecw (dS/m) adds the leaching requirement for the crop's ECe threshold.
- Landscape hydrozones: pwu (${PlantWaterUse.values.map((w) => w.name).join(', ')}) gives the water budget (report water).
- Site climate: ${climate == null ? 'none in this project (download_climate stores the monthly normals; without it eto per area is used)' : 'stored (${climate.firstYear}–${climate.lastYear}); ETo by month ${climate.etoMmDay.map((x) => _n(roundTo(x, 1))).join(' ')} mm/day'}.

## Crops (ck: name, Kc initial / mid / end, root depth m, depletion p)
''');
  for (final e in fao56Crops.entries) {
    final c = e.value;
    out.writeln(
      '- ${e.key}: ${_en.has(e.key) ? _en(e.key) : e.key}, Kc ${_n(c.kcIni)} / ${_n(c.kcMid)} / ${_n(c.kcEnd)}${c.rootDepthMinM == null ? '' : ', root ${_n(c.rootDepthMinM!)}–${_n(c.rootDepthMaxM ?? c.rootDepthMinM!)}'}${c.depletionFraction == null ? '' : ', p ${_n(c.depletionFraction!)}'}${c.perennial ? ', perennial' : ''}',
    );
  }
  out.writeln('\n## Soils (soil: name, typical available water mm/m, basic intake mm/h)');
  for (final e in soilTable.entries) {
    out.writeln('- ${e.key}: ${_en.has(e.key) ? _en(e.key) : e.key}, awc ${_n(roundTo(e.value.awcMmPerM, 0))}, intake ${_n(roundTo(e.value.basicIntakeMmH, 1))}');
  }
  return out.toString();
}
