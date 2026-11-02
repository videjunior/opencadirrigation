/// Design advisor: turns the design check, the design results and a sweep of
/// the settings into a list of problems, each with a severity, the items
/// involved, an explanation key (`adv.<code>.why` / `adv.<code>.how`) and the
/// automatic corrections that apply to it ([FixKind], see auto_fix.dart).
///
/// Everything here is pure Dart and read-only: the corrections are applied by
/// [applyFix].
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'design_check.dart';
import 'management.dart' show AutoFlowOptions, autoSystemFlows;
import 'network_builder.dart';
import 'results.dart';
import 'valve_in_head.dart';

enum AdviceLevel { error, warning, info }

/// Automatic corrections. The first fix of an [Advice] is its main one.
enum FixKind {
  /// Moves an unconnected item (or the nearest end of an unconnected pipe)
  /// onto the closest compatible pipe or item within reach ([connectReach]).
  connect,

  /// Deletes a zero-length pipe.
  deleteItem,

  /// Removes the vertices closer than the connection tolerance.
  cleanSegments,

  /// Keeps one of several identical items at the same place.
  removeDuplicates,

  /// Gives a unique zone name to valves that share one.
  renameZone,

  /// Lets the design compute the supply pressure (calculated supply).
  calculateSupply,

  /// Selects (or inserts) the catalogue pump with the lowest life-cycle cost
  /// that meets the duty of the supply.
  choosePump,

  /// Replaces a surface pump that cannot lift the water with a submersible one.
  submersiblePump,

  /// Lets the design choose the pipe diameters (unlocks fixed pipes).
  autoSizePipes,

  /// Pipe of a pressure class that withstands the pressure (same bore or larger).
  raisePipeClass,

  /// Control valve whose flow range covers the zone flow.
  resizeValve,

  /// Assigns a catalogue model to an item whose model is missing.
  assignModel,

  /// Regroups the zones into more system flows so none exceeds the supply flow.
  splitFlows,

  /// Adds the generic fittings missing from the catalogue.
  addFittings,

  /// Joins two crossing pipes at their intersection.
  joinCrossing,

  /// Places a water supply at the only free end of the mainline.
  addSupply,

  /// Restores out-of-range design parameters to their defaults.
  resetSettings,

  /// Puts the zones that are in no system flow into a new one.
  addMissingFlow,

  /// Drops deleted valves from the system flows and deletes the flows left
  /// without zones.
  removeEmptyFlows,

  /// Sets zero or negative system flow durations to one hour.
  fixFlowDurations,

  /// Sets the emitter pressure to the nozzle / tape nominal pressure.
  nominalEmitterHead,

  /// Sets the pump speed ratio back to 1.
  resetPumpSpeed,

  /// Makes the maximum pressure / flow of a supply at least its design value
  /// (no longer offered: a maximum is a physical limit of the well or of the
  /// water company; see [capSupplyDesign]).
  fixSupplyLimits,

  /// Re-enables the default catalogue pipes for a usage with none enabled.
  enablePipes,

  /// Enables every wire of the catalogue (the thicker ones included), or
  /// adds the default wires when the catalogue has none.
  enableWires,

  /// Gives a controller the next standard number of stations that holds
  /// all the valves wired to it.
  controllerStations,

  // 1.6.0 AUT
  /// Cuts an irrigated area whose outline crosses itself into the simple
  /// areas it encloses (same crop and settings, the first keeps the id).
  splitArea,

  /// Lowers the design flow / pressure of a supply to its maximum (the
  /// well or the water company cannot give more): the design then shows
  /// what the system lacks instead of hiding it.
  capSupplyDesign,
}

/// Corrections the "fix automatically" command may apply on its own: they
/// only restore consistency or pick catalogue items for a known duty.
/// [joinCrossing] and [addSupply] guess the intent and stay manual.
const autoSafeFixes = {
  FixKind.connect,
  FixKind.deleteItem,
  FixKind.cleanSegments,
  FixKind.removeDuplicates,
  FixKind.renameZone,
  FixKind.calculateSupply,
  FixKind.choosePump,
  FixKind.submersiblePump,
  FixKind.autoSizePipes,
  FixKind.raisePipeClass,
  FixKind.resizeValve,
  FixKind.assignModel,
  FixKind.splitFlows,
  FixKind.addFittings,
  FixKind.resetSettings,
  FixKind.addMissingFlow,
  FixKind.removeEmptyFlows,
  FixKind.fixFlowDurations,
  FixKind.nominalEmitterHead,
  FixKind.resetPumpSpeed,
  FixKind.enablePipes,
  FixKind.enableWires,
  FixKind.controllerStations,
  // 1.6.0 AUT
  FixKind.splitArea,
};

/// Corrections that need design results (duties, pressures, flows).
const resultFixes = {FixKind.choosePump, FixKind.submersiblePump, FixKind.raisePipeClass, FixKind.resizeValve, FixKind.splitFlows};

class Advice {
  Advice({required this.code, required this.raw, required this.level, this.entityIds = const [], this.context = '', this.contextId, this.at, this.fixes = const [], this.value = ''});

  /// Explanation key: `adv.<code>.why` and `adv.<code>.how`.
  final String code;

  /// Code of the original message (`check.<raw>` / `warn.<raw>` title).
  final String raw;
  final AdviceLevel level;
  final List<String> entityIds;

  /// Zone, system flow or pivot the message belongs to ('' = project).
  final String context;

  /// Valve id (zone), flow id or pivot id of [context].
  final String? contextId;

  /// Where to look (null: the first entity).
  final Pt? at;

  /// Corrections that apply, the main one first.
  final List<FixKind> fixes;

  /// Extra text: a count, a name, the missing catalogue id…
  final String value;

  bool get autoFixable => fixes.isNotEmpty && autoSafeFixes.contains(fixes.first);

  /// Identity used to merge the same problem reported by several sources.
  String get key => '$code|${entityIds.isEmpty ? '$contextId|$value' : entityIds.join(',')}';

  Map<String, dynamic> toJson() => {
    'code': code,
    'raw': raw,
    'level': level.name,
    if (entityIds.isNotEmpty) 'ids': entityIds,
    if (context.isNotEmpty) 'ctx': context,
    'ctxId': ?contextId,
    if (at != null) 'at': [at!.x, at!.y],
    if (fixes.isNotEmpty) 'fixes': [for (final f in fixes) f.name],
    if (value.isNotEmpty) 'value': value,
  };

  static Advice fromJson(Map<String, dynamic> j) {
    final at = j['at'] as List?;
    return Advice(
      code: j['code'] as String,
      raw: j['raw'] as String? ?? '',
      level: AdviceLevel.values.byName(j['level'] as String? ?? 'info'),
      entityIds: [for (final id in (j['ids'] as List?) ?? const []) '$id'],
      context: j['ctx'] as String? ?? '',
      contextId: j['ctxId'] as String?,
      at: at == null ? null : Pt((at[0] as num).toDouble(), (at[1] as num).toDouble()),
      fixes: [for (final f in (j['fixes'] as List?) ?? const []) FixKind.values.byName('$f')],
      value: j['value'] as String? ?? '',
    );
  }
}

/// How far (m) [FixKind.connect] looks for a pipe or item to join.
double connectReach(Project p) => math.max(2.0, 20 * p.params.connectTolerance);

/// Code of the explanation for a message code (several messages share one).
String adviceCode(String raw) => switch (raw) {
  'no_water_supply' || 'no_fixed_head_node' => 'no_supply',
  'pivot_unconnected' || 'valve_unreachable' => 'unconnected',
  'zone_empty' || 'valve_no_zone_pipes' => 'zone_no_emitters',
  'outlet_spec_missing' || 'tape_spec_missing' || 'pump_spec_missing' || 'valve_spec_missing' => 'spec_missing',
  'lp_loops_approx' => 'looped_mainline',
  'outlet_under_pressure' => 'cannot_meet_pressure_window',
  'mainline_cannot_meet_pressure' => 'valve_pressure_deficit',
  'pivot_pkg_pressure_deficit' || 'pivot_pkg_regulator_starved' || 'pivot_pkg_low_pressure' || 'pivot_pkg_no_pressure' => 'pivot_pkg_pressure',
  'pivot_pkg_nozzle_range' || 'pivot_pkg_nozzle_max' || 'pivot_pkg_flow_dev' => 'pivot_pkg_nozzles',
  'pivot_pkg_no_outlets' || 'pivot_pkg_no_flow' || 'pivot_pkg_gun_undefined' => 'pivot_pkg_setup',
  'corner_arm_no_path' || 'corner_arm_no_rate' || 'corner_arm_overrun' || 'corner_arm_short' || 'corner_arm_jump' => 'corner_arm',
  'vri_above_maximum' || 'vri_below_minimum' || 'vri_no_depth' => 'vri_limits',
  'pivot_elec_drop' || 'pivot_elec_no_towers' || 'pivot_elec_start_drop' => 'pivot_elec_drop',
  // 1.6.0 AGR
  'req_leaching_infeasible' => 'area_leaching_infeasible',
  // 1.6.0 MOD: a nozzle the catalogue item no longer has
  'nozzle_missing' => 'spec_missing',
  _ => raw,
};

/// Every explanation code (each has `adv.<code>.why` and `adv.<code>.how`).
const adviceCodes = [
  'no_supply',
  'no_valves',
  'no_hydraulics',
  'unconnected',
  'zero_length',
  'tiny_segment',
  'duplicate_item',
  'duplicate_zone_name',
  'pipes_cross',
  'mainline_dead_end',
  'zone_dead_end',
  'zone_no_emitters',
  'zone_mixed_emitters',
  'area_no_emitters',
  'spec_missing',
  'supply_no_head',
  'looped_mainline',
  'no_terrain',
  'not_converged',
  'cannot_meet_pressure_window',
  'outlet_over_pressure',
  'velocity_exceeded',
  'pressure_rating_exceeded',
  'surge_rating_exceeded',
  'valve_flow_out_of_range',
  'valve_pressure_deficit',
  'pivot_pressure_deficit',
  'supply_flow_exceeded',
  'supply_head_exceeded',
  'pump_out_of_range',
  'pump_suction_lift',
  'pump_npsh',
  'vfd_target_unreachable',
  'vfd_below_min_speed',
  'vfd_target_low',
  'zone_overlap',
  'lp_infeasible',
  'fitting_missing',
  'pivot_no_flow',
  'pivot_no_end_pressure',
  'pivot_app_rate',
  'valve_missing',
  'pivot_pkg_pressure',
  'pivot_pkg_nozzles',
  'pivot_pkg_setup',
  'pivot_pkg_no_drive',
  'corner_arm',
  'vri_limits',
  'pivot_elec_drop',
  'set_velocity',
  'set_hours',
  'set_economy',
  'set_tolerance',
  'set_variation',
  'set_temperature',
  'no_pipes_for_usage',
  'supply_limits',
  'valve_not_in_flow',
  'flow_empty',
  'flow_duration',
  'emitter_head_range',
  'pump_speed',
  'bom_unpriced',
  'elec_no_controller',
  'elec_unwired',
  'elec_wire_orphan',
  'elec_ctrl_unwired',
  'elec_no_wires',
  'elec_stations',
  'elec_voltage',
  'elec_simultaneous',
  'vih_not_in_flow',
  'vih_pressure_deficit',
  'vih_pressure_high',
  // 1.6.0 AGR
  'area_rate_exceeds_soil',
  'area_eto_climate',
  'area_planting_date',
  'area_leaching_infeasible',
  'elec_station_current',
  'elec_overcurrent',
  'pivot_pkg_slow_drive',
  // 1.6.0 AGR: capacity against the peak demand, runoff under the machines
  'capacity_below_peak',
  'pivot_capacity_below_peak',
  'pivot_runoff',
  // 1.6.0 AUT
  'area_self_intersect',
  'pipes_overlap',
  'zone_spacing_wide',
  'area_uniformity_low',
  // 1.6.0 MOD
  'outside_terrain',
  'pump_motor_overload',
  'pump_motor_sf',
  // 1.6.0 MOT
  'zone_pressure_unreachable',
  'pump_below_min_flow',
  'lp_iteration_limit',
  'zone_slope_exceeds_window',
  'pressure_below_atmospheric',
  'valve_pressure_excess',
];

AdviceLevel _level(String code) => switch (code) {
  'no_supply' ||
  'no_valves' ||
  'unconnected' ||
  'zero_length' ||
  'spec_missing' ||
  'not_converged' ||
  'cannot_meet_pressure_window' ||
  'pressure_rating_exceeded' ||
  'valve_pressure_deficit' ||
  'pivot_pressure_deficit' ||
  'supply_flow_exceeded' ||
  'supply_head_exceeded' ||
  'pump_out_of_range' ||
  'pump_suction_lift' ||
  'pump_npsh' ||
  'zone_no_emitters' ||
  'valve_missing' ||
  'pivot_no_flow' ||
  'pivot_no_end_pressure' ||
  'no_pipes_for_usage' ||
  'emitter_head_range' ||
  'valve_not_in_flow' ||
  'elec_stations' ||
  'elec_voltage' ||
  'vih_pressure_deficit' ||
  // 1.6.0 AUT: two valves feeding each other's pipes make both zones wrong;
  // an area crossing itself has the wrong size
  'zone_overlap' ||
  'area_self_intersect' ||
  // 1.6.0 MOT
  'zone_pressure_unreachable' ||
  'zone_slope_exceeds_window' => AdviceLevel.error,
  'looped_mainline' || 'no_terrain' || 'zone_dead_end' || 'area_no_emitters' || 'no_hydraulics' || 'bom_unpriced' || 'vfd_below_min_speed' || 'pivot_pkg_no_drive' => AdviceLevel.info,
  // 1.6.0 MOD: a motor working within its service factor
  'pump_motor_sf' => AdviceLevel.info,
  // 1.6.0 MOT: the flow control of the valve can throttle it on site
  'valve_pressure_excess' => AdviceLevel.info,
  _ => AdviceLevel.warning,
};

// ---------------------------------------------------------------- settings

/// Settings that make the design impossible or meaningless: design parameters
/// outside physical ranges, a catalogue without pipes for a use, supply
/// limits below the design values, zones left out of every system flow,
/// empty flows, emitter pressures outside the nozzle range, pump speeds.
List<CheckIssue> checkSettings(Project p) {
  final out = <CheckIssue>[];
  final s = p.params;
  bool bad(double v, double lo, double hi) => !(v >= lo && v <= hi);
  if (bad(s.maxZoneVelocity, 0.3, 5) || bad(s.maxMainlineVelocity, 0.3, 5) || bad(s.maxLateralVelocity, 0.3, 5)) {
    out.add(CheckIssue('set_velocity', CheckSeverity.warning, value: '${_f(s.maxLateralVelocity)} / ${_f(s.maxZoneVelocity)} / ${_f(s.maxMainlineVelocity)} m/s'));
  }
  if (bad(s.hoursPerYear, 1, 8760) || bad(s.zoneHoursPerYear, 1, 8760)) out.add(CheckIssue('set_hours', CheckSeverity.warning, value: '${_f(s.hoursPerYear)} / ${_f(s.zoneHoursPerYear)} h'));
  if (bad(s.interestRate, 0, 0.5) || s.termYears < 1 || s.termYears > 100 || bad(s.pumpEfficiency, 0.2, 0.95) || s.powerCostPerKwh < 0) {
    out.add(const CheckIssue('set_economy', CheckSeverity.warning));
  }
  if (bad(s.connectTolerance, 0.001, 1)) out.add(CheckIssue('set_tolerance', CheckSeverity.warning, value: '${_f(s.connectTolerance)} m'));
  if (bad(s.maxZoneVariationPct, 0, 60)) out.add(CheckIssue('set_variation', CheckSeverity.warning, value: '${_f(s.maxZoneVariationPct)} %'));
  if (bad(s.waterTempC, 0, 60)) out.add(CheckIssue('set_temperature', CheckSeverity.warning, value: '${_f(s.waterTempC)} °C'));

  final ents = p.entities;
  final cat = p.catalog;
  // pipes the design would have to size without any catalogue option
  final needs = <PipeUsage>{
    for (final e in ents)
      if (e is PipeEntity && (e.computerSized || cat.pipe(e.pipeSpecId) == null))
        e.scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline
      else if (e is SpraylineEntity && (e.computerSized || cat.pipe(e.pipeSpecId) == null))
        PipeUsage.lateral,
  };
  for (final u in PipeUsage.values) {
    if (needs.contains(u) && cat.pipesFor(u).isEmpty) out.add(CheckIssue('no_pipes_for_usage', CheckSeverity.error, value: u.name));
  }
  for (final w in ents.whereType<WaterSupplyEntity>()) {
    final head = !w.calculatePressure && w.maxHeadM > 0 && w.designHeadM > w.maxHeadM + 1e-9;
    final flow = w.maxFlow > 0 && w.designFlow > w.maxFlow + 1e-12;
    if (head || flow) out.add(CheckIssue('supply_limits', CheckSeverity.warning, entityIds: [w.id]));
  }
  // system flows: zones left out, empty flows, durations
  final valves = ents.whereType<ControlValveEntity>().toList();
  final pivots = ents.whereType<PivotEntity>().toList();
  if (p.systemFlows.isNotEmpty) {
    final vih = VihStations.of(p);
    final ids = {for (final e in ents) e.id, ...vih.heads.keys};
    final inFlow = {for (final f in p.systemFlows) ...f.valveIds};
    final missing = [
      for (final v in valves)
        if (!inFlow.contains(v.id)) v.id,
      for (final v in pivots)
        if (!inFlow.contains(v.id)) v.id,
    ];
    if (missing.isNotEmpty) out.add(CheckIssue('valve_not_in_flow', CheckSeverity.error, entityIds: missing, value: '${missing.length}'));
    // valve-in-head stations no flow lists run in every flow
    final loose = vih.unscheduled(p.systemFlows);
    if (loose.isNotEmpty) out.add(CheckIssue('vih_not_in_flow', CheckSeverity.warning, entityIds: [for (final s in loose) ...vih.heads[s]!], value: '${loose.length}'));
    final empty = [
      for (final f in p.systemFlows)
        if (!f.valveIds.any(ids.contains)) f.name,
    ];
    if (empty.isNotEmpty) out.add(CheckIssue('flow_empty', CheckSeverity.warning, value: empty.join(', ')));
    final zero = [
      for (final f in p.systemFlows)
        if (!(f.durationHours > 0)) f.name,
    ];
    if (zero.isNotEmpty) out.add(CheckIssue('flow_duration', CheckSeverity.warning, value: zero.join(', ')));
  }
  // emitter pressure outside the range of the nozzle / tape
  final badHead = <String>[];
  for (final e in ents) {
    switch (e) {
      case OutletEntity o:
        final n = cat.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
        if (n != null && bad(o.headM, n.minHeadM, n.maxHeadM)) badHead.add(e.id);
      case SpraylineEntity sl:
        final n = cat.outlet(sl.outletSpecId)?.nozzle(sl.nozzleId);
        if (n != null && bad(sl.headM, n.minHeadM, n.maxHeadM)) badHead.add(e.id);
      case TapeEntity t:
        final spec = cat.tape(t.tapeSpecId);
        if (spec != null && bad(t.inletHeadM, spec.minHeadM, spec.maxHeadM)) badHead.add(e.id);
      default:
        break;
    }
  }
  if (badHead.isNotEmpty) out.add(CheckIssue('emitter_head_range', CheckSeverity.error, entityIds: badHead, value: '${badHead.length}'));
  final speeds = [
    for (final e in ents.whereType<PumpEntity>())
      if (bad(e.speedRatio, 0.4, 1.3)) e.id,
  ];
  if (speeds.isNotEmpty) out.add(CheckIssue('pump_speed', CheckSeverity.warning, entityIds: speeds));
  return out;
}

String _f(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// ---------------------------------------------------------------- advice

/// Builds the advice list. [check] is the design check of the current
/// drawing (run here when null); [results] the latest design, used only when
/// it matches the drawing ([resultsCurrent]).
List<Advice> buildAdvice(Project p, {DesignResults? results, DesignCheckReport? check, bool resultsCurrent = true}) {
  final ch = check ?? runDesignCheck(p);
  final r = resultsCurrent ? results : null;
  final out = <Advice>[];
  final seen = <String, int>{};
  NetworkModel? model;
  NetworkModel net() => model ??= NetworkBuilder(p).build();

  void add(String raw, {List<String> ids = const [], String context = '', String? contextId, Pt? at, String value = ''}) {
    final code = adviceCode(raw);
    final ents = [
      for (final id in ids)
        if (p.byId(id) != null) id,
    ];
    final a = Advice(code: code, raw: raw, level: _level(code), entityIds: ents, context: context, contextId: contextId, at: at, value: value, fixes: _fixesFor(p, r, code, raw, ents, contextId, net));
    final k = a.key;
    final prev = seen[k];
    if (prev != null) {
      // same problem from several flows: keep the first, note the contexts
      final old = out[prev];
      if (context.isNotEmpty && !old.context.split(', ').contains(context)) {
        out[prev] = Advice(
          code: old.code,
          raw: old.raw,
          level: old.level,
          entityIds: old.entityIds,
          context: old.context.isEmpty ? context : '${old.context}, $context',
          contextId: old.contextId,
          at: old.at,
          value: old.value,
          fixes: old.fixes,
        );
      }
      return;
    }
    seen[k] = out.length;
    out.add(a);
  }

  // "code:arg:arg" — arguments are entity ids or free text
  void addCoded(String w, {String context = '', String? contextId}) {
    final parts = w.split(':');
    final raw = parts.first;
    final args = parts.skip(1).toList();
    final ids = [
      for (final a in args)
        if (p.byId(a) != null) a,
    ];
    final text = [
      for (final a in args)
        if (p.byId(a) == null) a,
    ].join(', ');
    add(raw, ids: ids, context: context, contextId: contextId, value: text);
  }

  for (final i in [...ch.issues, ...checkSettings(p)]) {
    add(i.code, ids: i.entityIds, at: i.at, value: i.value);
  }
  if (r != null) {
    for (final m in r.messages) {
      addCoded(m);
    }
    for (final z in r.zones.values) {
      for (final w in z.warnings) {
        addCoded(w, context: z.zoneName, contextId: z.valveId);
      }
    }
    for (final f in r.systemFlows) {
      for (final w in f.warnings) {
        addCoded(w, context: f.name, contextId: f.flowId);
      }
    }
    for (final pv in r.pivots.entries) {
      for (final w in pv.value.warnings) {
        addCoded(w, context: pv.value.name, contextId: pv.key);
      }
    }
    for (final id in r.unconnected) {
      add('unconnected', ids: [id]);
    }
  }
  // without any supply every mainline item is "unconnected": the missing
  // supply is the one problem to solve
  if (!p.entities.any((e) => e is WaterSupplyEntity)) {
    out.removeWhere((a) => a.code == 'unconnected' && a.entityIds.every((id) => p.byId(id)?.hydraulicScope == HydraulicScope.mainline || p.byId(id) is ControlValveEntity));
  }
  const order = {AdviceLevel.error: 0, AdviceLevel.warning: 1, AdviceLevel.info: 2};
  final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
  indexed.sort((a, b) {
    final c = order[a.$2.level]!.compareTo(order[b.$2.level]!);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final (_, a) in indexed) a];
}

/// Corrections that apply to a problem in the current project.
List<FixKind> _fixesFor(Project p, DesignResults? r, String code, String raw, List<String> ids, String? contextId, NetworkModel Function() net) {
  final first = ids.isEmpty ? null : p.byId(ids.first);
  switch (code) {
    case 'unconnected':
      return first != null && canConnect(p, first, model: first is OutletEntity ? net() : null) ? const [FixKind.connect] : const [];
    case 'zero_length':
      return const [FixKind.deleteItem];
    case 'tiny_segment':
      return const [FixKind.cleanSegments];
    case 'duplicate_item':
      return ids.length > 1 ? const [FixKind.removeDuplicates] : const [];
    case 'duplicate_zone_name':
      return ids.length > 1 ? const [FixKind.renameZone] : const [];
    case 'pipes_cross':
      return ids.length == 2 && ids.every((id) => p.byId(id) is PipeEntity) ? const [FixKind.joinCrossing] : const [];
    case 'spec_missing':
      return first != null ? const [FixKind.assignModel] : const [];
    case 'supply_no_head':
      return const [FixKind.calculateSupply];
    case 'no_supply':
      return mainlineFreeEnds(p).length == 1 ? const [FixKind.addSupply] : const [];
    case 'mainline_dead_end':
      return !p.entities.any((e) => e is WaterSupplyEntity) && mainlineFreeEnds(p).length == 1 ? const [FixKind.addSupply] : const [];
    case 'velocity_exceeded':
      return first is PipeEntity && !first.computerSized || first is SpraylineEntity && !first.computerSized ? const [FixKind.autoSizePipes] : const [];
    case 'cannot_meet_pressure_window':
      if (contextId == null) return const [];
      return zoneEntities(p, contextId, net()).any((e) => e is PipeEntity && !e.computerSized || e is SpraylineEntity && !e.computerSized) ? const [FixKind.autoSizePipes] : const [];
    case 'pressure_rating_exceeded':
    case 'surge_rating_exceeded':
      return first is PipeEntity && r != null && higherClassPipe(p, r, first, surge: code == 'surge_rating_exceeded') != null ? const [FixKind.raisePipeClass] : const [];
    case 'valve_flow_out_of_range':
      return contextId != null && r != null && fittingValve(p, r, contextId) != null ? const [FixKind.resizeValve] : const [];
    case 'valve_pressure_deficit':
    case 'pivot_pressure_deficit':
    case 'vih_pressure_deficit':
    case 'supply_head_exceeded':
      final fixed = p.entities.whereType<WaterSupplyEntity>().any((s) => !s.calculatePressure);
      return [if (r != null) FixKind.choosePump, if (fixed && code != 'supply_head_exceeded') FixKind.calculateSupply];
    case 'pump_out_of_range':
      return r != null ? const [FixKind.choosePump] : const [];
    case 'pump_suction_lift':
      return r != null ? const [FixKind.submersiblePump] : const [];
    case 'supply_flow_exceeded':
      return r != null && first is WaterSupplyEntity && splitFlowsPlan(p, r, first, (k) => k) != null ? const [FixKind.splitFlows] : const [];
    case 'fitting_missing':
      return const [FixKind.addFittings];
    case 'set_velocity' || 'set_hours' || 'set_economy' || 'set_tolerance' || 'set_variation' || 'set_temperature':
      return const [FixKind.resetSettings];
    case 'no_pipes_for_usage':
      return const [FixKind.enablePipes];
    case 'supply_limits':
      // 1.6.0 AUT: the maximum is the physical limit; the design value comes down to it
      return const [FixKind.capSupplyDesign];
    case 'valve_not_in_flow':
      return const [FixKind.addMissingFlow];
    case 'flow_empty':
    case 'valve_missing':
      return const [FixKind.removeEmptyFlows];
    case 'flow_duration':
      return const [FixKind.fixFlowDurations];
    case 'emitter_head_range':
      return const [FixKind.nominalEmitterHead];
    case 'pump_speed':
      return const [FixKind.resetPumpSpeed];
    case 'elec_no_wires':
      return const [FixKind.enableWires];
    case 'elec_voltage':
      // thicker wires still disabled in the catalogue
      final thickest = p.catalog.enabledWires.lastOrNull?.ohmPerKm ?? double.infinity;
      return p.catalog.wires.any((w) => !w.enabled && w.ohmPerKm < thickest) ? const [FixKind.enableWires] : const [];
    case 'elec_stations':
      return const [FixKind.controllerStations];
    // 1.6.0 AUT
    case 'area_self_intersect':
      return first is AreaEntity ? const [FixKind.splitArea] : const [];
    case 'pipes_overlap':
      return ids.length == 2 && sameLine(p.byId(ids[0]), p.byId(ids[1]), math.max(p.params.connectTolerance, 1e-3)) ? const [FixKind.removeDuplicates] : const [];
    default:
      return const [];
  }
}

/// Whether [a] and [b] are the same line drawn twice: one kind and model,
/// vertices within [tol] of each other (in either direction).
bool sameLine(Entity? a, Entity? b, double tol) {
  if (a is! PolyEntity || b is! PolyEntity || a.runtimeType != b.runtimeType) return false;
  final pa = a.points, pb = b.points;
  if (pa.length != pb.length || pa.isEmpty) return false;
  final spec = switch ((a, b)) {
    (PipeEntity x, PipeEntity y) => x.pipeSpecId == y.pipeSpecId && x.scope == y.scope,
    (SpraylineEntity x, SpraylineEntity y) => x.outletSpecId == y.outletSpecId && x.nozzleId == y.nozzleId && x.spacing == y.spacing,
    (TapeEntity x, TapeEntity y) => x.tapeSpecId == y.tapeSpecId,
    _ => false,
  };
  if (!spec) return false;
  bool along(List<Pt> q) {
    for (var i = 0; i < pa.length; i++) {
      if (pa[i].distanceTo(q[i]) > tol) return false;
    }
    return true;
  }

  return along(pb) || along(pb.reversed.toList());
}

// ---------------------------------------------------------------- helpers shared with auto_fix.dart

/// Hydraulic entities of the zone fed by valve [valveId].
List<Entity> zoneEntities(Project p, String valveId, NetworkModel model) {
  final links = model.zoneLinks[valveId] ?? const <String>{};
  final ids = <String>{for (final lid in links) model.linkById(lid)?.entityId ?? ''};
  return [
    for (final e in p.entities)
      if (ids.contains(e.id)) e,
  ];
}

/// Ends of mainline pipes that touch nothing (no other pipe, no item).
List<Pt> mainlineFreeEnds(Project p) {
  final tol = math.max(p.params.connectTolerance, 1e-3);
  final pipes = p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline && e.points.length >= 2).toList();
  final items = [
    for (final e in p.entities)
      if (e is ControlValveEntity)
        e.position
      else if (e is PumpEntity && e.scope == HydraulicScope.mainline)
        e.position
      else if (e is MiscHydraulicEntity && e.scope == HydraulicScope.mainline)
        e.position
      else if (e is WaterSupplyEntity)
        e.position
      else if (e is OutletEntity && e.scope == HydraulicScope.mainline)
        e.position
      else if (e is PivotEntity)
        e.center,
  ];
  final out = <Pt>[];
  for (final pipe in pipes) {
    for (final end in [pipe.points.first, pipe.points.last]) {
      final touchesPipe = pipes.any((o) => !identical(o, pipe) && o.points.any((v) => v.distanceTo(end) <= tol));
      final touchesItem = items.any((q) => q.distanceTo(end) <= tol);
      if (!touchesPipe && !touchesItem && !out.any((q) => q.distanceTo(end) <= tol)) out.add(end);
    }
  }
  return out;
}

/// How [FixKind.connect] joins an item: [moved] gets its point [index]
/// (−1: the position of a point item) set to [to]; [splitPipe], when set, is
/// cut at [to] first so the joint is a vertex of both. With [pipe] the item
/// stays where it is and a short pipe (a swing joint) runs from it to [to]:
/// a sprinkler left off the pipe keeps its place in the layout.
class ConnectPlan {
  const ConnectPlan(this.moved, this.index, this.to, [this.splitPipe, this.pipe = false]);
  final Entity moved;
  final int index;
  final Pt to;
  final PipeEntity? splitPipe;
  final bool pipe;
  double get distance => switch (moved) {
    PointEntity e => e.position.distanceTo(to),
    PolyEntity e => e.points[index].distanceTo(to),
    _ => 0,
  };
}

/// How far (m) the automatic correction moves an item to join it: a gap
/// of about the connection tolerance (a vertex snapped a little off);
/// farther items are joined by the button, as the user decides.
double autoConnectReach(Project p) => math.max(0.05, 2 * p.params.connectTolerance);

/// Zone (valve zone name) of every hydraulic entity the network puts in a
/// zone.
Map<String, String> entityZones(Project p, NetworkModel model) {
  final out = <String, String>{};
  for (final v in p.entities.whereType<ControlValveEntity>()) {
    for (final lid in model.zoneLinks[v.id] ?? const <String>{}) {
      final id = model.linkById(lid)?.entityId;
      if (id != null) out.putIfAbsent(id, () => v.zoneName);
    }
  }
  return out;
}

/// Where [FixKind.connect] would join [e], or null when nothing is in reach.
/// A sprinkler of a zone is piped to the nearest zone pipe (of its own
/// zone when it names one), never moved. [model] is the network of [p]
/// when the caller has built it.
ConnectPlan? connectTarget(Project p, Entity e, {NetworkModel? model}) {
  final reach = connectReach(p);
  final tol = math.max(p.params.connectTolerance, 1e-3);
  bool isVertex(PipeEntity pipe, Pt q) => pipe.points.any((v) => v.distanceTo(q) <= 1e-9);
  if (e is PivotEntity) {
    // the nearest mainline pipe end comes to the pivot centre
    ConnectPlan? best;
    var bd = reach;
    for (final pipe in p.entities.whereType<PipeEntity>()) {
      if (pipe.scope != HydraulicScope.mainline || pipe.points.length < 2) continue;
      for (final i in [0, pipe.points.length - 1]) {
        final d = pipe.points[i].distanceTo(e.center);
        if (d <= bd) {
          bd = d;
          best = ConnectPlan(pipe, i, e.center);
        }
      }
    }
    return best;
  }
  if (e is ControlValveEntity) {
    // a valve belongs where the mainline meets the start of its zone: the
    // nearest zone line end that touches a mainline pipe
    ConnectPlan? best;
    var bd = reach;
    final mains = p.entities.whereType<PipeEntity>().where((m) => m.scope == HydraulicScope.mainline && m.points.length >= 2).toList();
    for (final z in p.entities) {
      if (!(z is PipeEntity && z.scope == HydraulicScope.zone || z is SpraylineEntity || z is TapeEntity)) continue;
      final pts = (z as PolyEntity).points;
      if (pts.length < 2) continue;
      for (final end in [pts.first, pts.last]) {
        final d = end.distanceTo(e.position);
        if (d >= bd) continue;
        for (final m in mains) {
          final (_, cp) = polylineStationOf(m.points, end);
          if (cp.distanceTo(end) > tol) continue;
          bd = d;
          best = ConnectPlan(e, -1, end, isVertex(m, end) ? null : m);
          break;
        }
      }
    }
    if (best != null) return best;
  }
  if (e is OutletEntity && e.scope == HydraulicScope.zone) {
    // 1.6.0 AUT: a head off its pipe gets a short pipe; it is not moved
    final zones = e.zoneName.trim().isEmpty ? const <String, String>{} : entityZones(p, model ?? NetworkBuilder(p).build());
    ConnectPlan? best;
    var bd = reach;
    for (final pipe in p.entities.whereType<PipeEntity>()) {
      if (pipe.scope != HydraulicScope.zone || pipe.points.length < 2) continue;
      final z = zones[pipe.id];
      if (z != null && z.trim().toLowerCase() != e.zoneName.trim().toLowerCase()) continue;
      final (_, cp) = polylineStationOf(pipe.points, e.position);
      var target = cp;
      for (final v in pipe.points) {
        if (v.distanceTo(cp) <= math.max(0.25, 5 * tol) && v.distanceTo(e.position) <= reach) {
          target = v;
          break;
        }
      }
      final d = target.distanceTo(e.position);
      if (d < bd) {
        bd = d;
        best = ConnectPlan(e, -1, target, isVertex(pipe, target) ? null : pipe, true);
      }
    }
    return best;
  }
  if (e is PointEntity) {
    final scope = e is ControlValveEntity ? HydraulicScope.mainline : e.hydraulicScope;
    if (scope == null) return null;
    ConnectPlan? best;
    var bd = reach;
    for (final pipe in p.entities.whereType<PipeEntity>()) {
      if (pipe.scope != scope || pipe.points.length < 2) continue;
      final (_, cp) = polylineStationOf(pipe.points, e.position);
      var target = cp;
      // prefer a vertex close to the foot of the perpendicular
      for (final v in pipe.points) {
        if (v.distanceTo(cp) <= math.max(0.25, 5 * tol) && v.distanceTo(e.position) <= reach) {
          target = v;
          break;
        }
      }
      final d = target.distanceTo(e.position);
      if (d < bd) {
        bd = d;
        best = ConnectPlan(e, -1, target, isVertex(pipe, target) ? null : pipe);
      }
    }
    return best;
  }
  if (e is PolyEntity && e.isLinearHydraulic) {
    final pts = e.points;
    if (pts.length < 2) return null;
    final scope = e.hydraulicScope;
    final anchors = <Pt>[];
    for (final o in p.entities) {
      if (identical(o, e)) continue;
      if (o is ControlValveEntity) {
        anchors.add(o.position);
      } else if (o is PointEntity && o.isHydraulic && o.hydraulicScope == scope) {
        anchors.add(o.position);
      } else if (o is PivotEntity && scope == HydraulicScope.mainline) {
        anchors.add(o.center);
      } else if (o is PolyEntity && o.isLinearHydraulic && o.hydraulicScope == scope) {
        anchors.addAll(o.points);
      }
    }
    ConnectPlan? best;
    var bd = reach;
    for (final i in [0, pts.length - 1]) {
      final end = pts[i];
      for (final a in anchors) {
        final d = a.distanceTo(end);
        if (d > tol && d <= bd) {
          bd = d;
          best = ConnectPlan(e, i, a);
        }
      }
      // T-junction on another pipe of the same scope
      for (final o in p.entities.whereType<PipeEntity>()) {
        if (identical(o, e) || o.scope != scope || o.points.length < 2) continue;
        final (_, cp) = polylineStationOf(o.points, end);
        final d = cp.distanceTo(end);
        if (d > tol && d < bd - 1e-9) {
          bd = d;
          best = ConnectPlan(e, i, cp, isVertex(o, cp) ? null : o);
        }
      }
    }
    return best;
  }
  return null;
}

bool canConnect(Project p, Entity e, {NetworkModel? model}) => connectTarget(p, e, model: model) != null;

/// Cheapest enabled pipe of the same use that withstands the pressure of
/// [pipe] (steady, or steady plus water hammer with [surge]; class derated
/// for the water temperature) with a bore not smaller than the current one;
/// null when the catalogue has none.
PipeSpec? higherClassPipe(Project p, DesignResults r, PipeEntity pipe, {bool surge = false}) {
  final segs = r.pipesByEntity[pipe.id] ?? const <PipeSegmentResult>[];
  var need = 0.0;
  for (final s in segs) {
    need = math.max(need, math.max(s.pressureStart, s.pressureEnd));
  }
  if (surge) {
    for (final s in r.surge) {
      if (s.entityId == pipe.id) need = math.max(need, s.totalHead);
    }
  }
  if (!(need > 0)) return null;
  final cat = p.catalog;
  final current = cat.pipe(pipe.pipeSpecId) ?? (segs.isEmpty ? null : cat.pipe(segs.first.pipeSpecId));
  final bore = current?.innerDiameterMm ?? (segs.isEmpty ? 0.0 : segs.map((s) => s.diameter * 1000).reduce(math.max));
  final usage = pipe.scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline;
  PipeSpec? best;
  for (final s in cat.pipesFor(usage)) {
    if (s.ratingAt(p.params.waterTempC) < need - 1e-6 || s.innerDiameterMm < bore * 0.98 - 1e-9) continue;
    if (current != null && s.id == current.id) continue;
    if (best == null || s.costPerM < best.costPerM || (s.costPerM == best.costPerM && s.innerDiameterMm < best.innerDiameterMm)) best = s;
  }
  return best;
}

/// Smallest enabled valve of the same kind whose flow range covers the flow
/// of the zone of [valveId]; null when none (or the current one already fits).
ValveSpec? fittingValve(Project p, DesignResults r, String valveId) {
  final v = p.byId(valveId);
  final z = r.zones[valveId];
  if (v is! ControlValveEntity || z == null) return null;
  final cat = p.catalog;
  final current = cat.valve(v.valveSpecId);
  final kind = current?.kind ?? ValveKind.control;
  final q = z.totalFlow;
  ValveSpec? best;
  for (final s in cat.valves) {
    if (!s.enabled || s.kind != kind) continue;
    if (q > s.maxFlow + 1e-12 || q < s.minFlow - 1e-12) continue;
    if (best == null || s.sizeMm < best.sizeMm || (s.sizeMm == best.sizeMm && s.cost < best.cost)) best = s;
  }
  if (best == null || best.id == current?.id) return null;
  return best;
}

/// System flows regrouped so the flow of none exceeds the design flow of
/// [supply], or null when a single zone is already above it or the supply
/// has no design flow. The grouping is that of [autoSystemFlows]
/// (first-fit decreasing, every zone and pivot, also those without a design
/// result yet); each new flow keeps the name of the user's flow most of its
/// zones came from and runs as long as the longest of them did, the first
/// one at the hour the user's first flow started and the others one after
/// the other ([applyFix] refuses a plan longer than a day).
List<SystemFlow>? splitFlowsPlan(Project p, DesignResults r, WaterSupplyEntity supply, String Function(String key) label) {
  final cap = supply.designFlow;
  if (!(cap > 0)) return null;
  final flows = p.systemFlows;
  final first = flows.isEmpty ? 0.0 : flows.map((f) => f.startHour).reduce(math.min);
  final plan = autoSystemFlows(
    p,
    AutoFlowOptions(maxFlow: cap, firstStartHour: first),
    results: r,
    label: label,
  );
  if (plan.flows.isEmpty || plan.oversized.isNotEmpty) return null;
  final durationOf = <String, double>{};
  final flowOf = <String, SystemFlow>{};
  for (final f in flows) {
    for (final id in f.valveIds) {
      durationOf[id] = math.max(durationOf[id] ?? 0, f.durationHours > 0 ? f.durationHours : 1);
      flowOf.putIfAbsent(id, () => f);
    }
  }
  final usedNames = <String, int>{};
  var start = first;
  final out = <SystemFlow>[];
  for (final f in plan.flows) {
    final ids = f.valveIds;
    final dur = ids.map((id) => durationOf[id] ?? 1.0).reduce(math.max);
    // the user's flow that gave most of the zones lends its name
    final votes = <SystemFlow, int>{};
    for (final id in ids) {
      final src = flowOf[id];
      if (src != null) votes[src] = (votes[src] ?? 0) + 1;
    }
    var name = f.name;
    if (votes.isNotEmpty) {
      final src = votes.entries.reduce((x, y) => y.value > x.value ? y : x).key;
      final k = usedNames[src.name] = (usedNames[src.name] ?? 0) + 1;
      name = k == 1 ? src.name : '${src.name} ($k)';
    }
    out.add(SystemFlow(id: f.id, name: name, valveIds: {...ids}, startHour: start % 24, durationHours: dur));
    start += dur;
  }
  return out;
}
