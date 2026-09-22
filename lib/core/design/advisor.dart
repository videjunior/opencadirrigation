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
import 'network_builder.dart';
import 'results.dart';

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

  /// Makes the maximum pressure / flow of a supply at least its design value.
  fixSupplyLimits,

  /// Re-enables the default catalogue pipes for a usage with none enabled.
  enablePipes,

  /// Enables every wire of the catalogue (the thicker ones included), or
  /// adds the default wires when the catalogue has none.
  enableWires,

  /// Gives a controller the next standard number of stations that holds
  /// all the valves wired to it.
  controllerStations,
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
  FixKind.fixSupplyLimits,
  FixKind.enablePipes,
  FixKind.enableWires,
  FixKind.controllerStations,
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
  _ => raw,
};

/// Every explanation code (each has `adv.<code>.why` and `adv.<code>.how`).
const adviceCodes = [
  'no_supply', 'no_valves', 'no_hydraulics', 'unconnected', 'zero_length', 'tiny_segment', 'duplicate_item', 'duplicate_zone_name',
  'pipes_cross', 'mainline_dead_end', 'zone_dead_end', 'zone_no_emitters', 'area_no_emitters', 'spec_missing', 'supply_no_head',
  'looped_mainline', 'no_terrain', 'not_converged', 'cannot_meet_pressure_window', 'outlet_over_pressure', 'velocity_exceeded',
  'pressure_rating_exceeded', 'surge_rating_exceeded', 'valve_flow_out_of_range', 'valve_pressure_deficit', 'pivot_pressure_deficit',
  'supply_flow_exceeded', 'supply_head_exceeded', 'pump_out_of_range', 'pump_suction_lift', 'zone_overlap', 'lp_infeasible',
  'fitting_missing', 'pivot_no_flow', 'pivot_no_end_pressure', 'pivot_app_rate', 'valve_missing',
  'set_velocity', 'set_hours', 'set_economy', 'set_tolerance', 'set_variation', 'set_temperature', 'no_pipes_for_usage', 'supply_limits',
  'valve_not_in_flow', 'flow_empty', 'flow_duration', 'emitter_head_range', 'pump_speed', 'bom_unpriced',
  'elec_no_controller', 'elec_unwired', 'elec_wire_orphan', 'elec_ctrl_unwired', 'elec_no_wires', 'elec_stations', 'elec_voltage', 'elec_simultaneous',
];

AdviceLevel _level(String code) => switch (code) {
  'no_supply' || 'no_valves' || 'unconnected' || 'zero_length' || 'spec_missing' || 'not_converged' || 'cannot_meet_pressure_window' ||
  'pressure_rating_exceeded' || 'valve_pressure_deficit' || 'pivot_pressure_deficit' || 'supply_flow_exceeded' || 'supply_head_exceeded' ||
  'pump_out_of_range' || 'pump_suction_lift' || 'zone_no_emitters' || 'valve_missing' || 'pivot_no_flow' || 'pivot_no_end_pressure' ||
  'no_pipes_for_usage' || 'emitter_head_range' || 'valve_not_in_flow' || 'elec_stations' || 'elec_voltage' => AdviceLevel.error,
  'looped_mainline' || 'no_terrain' || 'zone_dead_end' || 'area_no_emitters' || 'no_hydraulics' || 'bom_unpriced' => AdviceLevel.info,
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
      if (e is PipeEntity && (e.computerSized || cat.pipe(e.pipeSpecId) == null)) e.scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline
      else if (e is SpraylineEntity && (e.computerSized || cat.pipe(e.pipeSpecId) == null)) PipeUsage.lateral,
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
    final ids = {for (final e in ents) e.id};
    final inFlow = {for (final f in p.systemFlows) ...f.valveIds};
    final missing = [for (final v in valves) if (!inFlow.contains(v.id)) v.id, for (final v in pivots) if (!inFlow.contains(v.id)) v.id];
    if (missing.isNotEmpty) out.add(CheckIssue('valve_not_in_flow', CheckSeverity.error, entityIds: missing, value: '${missing.length}'));
    final empty = [for (final f in p.systemFlows) if (!f.valveIds.any(ids.contains)) f.name];
    if (empty.isNotEmpty) out.add(CheckIssue('flow_empty', CheckSeverity.warning, value: empty.join(', ')));
    final zero = [for (final f in p.systemFlows) if (!(f.durationHours > 0)) f.name];
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
  final speeds = [for (final e in ents.whereType<PumpEntity>()) if (bad(e.speedRatio, 0.4, 1.3)) e.id];
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
    final ents = [for (final id in ids) if (p.byId(id) != null) id];
    final a = Advice(code: code, raw: raw, level: _level(code), entityIds: ents, context: context, contextId: contextId, at: at, value: value, fixes: _fixesFor(p, r, code, raw, ents, contextId, net));
    final k = a.key;
    final prev = seen[k];
    if (prev != null) {
      // same problem from several flows: keep the first, note the contexts
      final old = out[prev];
      if (context.isNotEmpty && !old.context.split(', ').contains(context)) {
        out[prev] = Advice(code: old.code, raw: old.raw, level: old.level, entityIds: old.entityIds, context: old.context.isEmpty ? context : '${old.context}, $context', contextId: old.contextId, at: old.at, value: old.value, fixes: old.fixes);
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
    final ids = [for (final a in args) if (p.byId(a) != null) a];
    final text = [for (final a in args) if (p.byId(a) == null) a].join(', ');
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
      return first != null && canConnect(p, first) ? const [FixKind.connect] : const [];
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
      return const [FixKind.fixSupplyLimits];
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
    default:
      return const [];
  }
}

// ---------------------------------------------------------------- helpers shared with auto_fix.dart

/// Hydraulic entities of the zone fed by valve [valveId].
List<Entity> zoneEntities(Project p, String valveId, NetworkModel model) {
  final links = model.zoneLinks[valveId] ?? const <String>{};
  final ids = <String>{for (final lid in links) model.linkById(lid)?.entityId ?? ''};
  return [for (final e in p.entities) if (ids.contains(e.id)) e];
}

/// Ends of mainline pipes that touch nothing (no other pipe, no item).
List<Pt> mainlineFreeEnds(Project p) {
  final tol = math.max(p.params.connectTolerance, 1e-3);
  final pipes = p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline && e.points.length >= 2).toList();
  final items = [
    for (final e in p.entities)
      if (e is ControlValveEntity) e.position
      else if (e is PumpEntity && e.scope == HydraulicScope.mainline) e.position
      else if (e is MiscHydraulicEntity && e.scope == HydraulicScope.mainline) e.position
      else if (e is WaterSupplyEntity) e.position
      else if (e is OutletEntity && e.scope == HydraulicScope.mainline) e.position
      else if (e is PivotEntity) e.center,
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
/// cut at [to] first so the joint is a vertex of both.
class ConnectPlan {
  const ConnectPlan(this.moved, this.index, this.to, [this.splitPipe]);
  final Entity moved;
  final int index;
  final Pt to;
  final PipeEntity? splitPipe;
  double get distance => switch (moved) {
    PointEntity e => e.position.distanceTo(to),
    PolyEntity e => e.points[index].distanceTo(to),
    _ => 0,
  };
}

/// Where [FixKind.connect] would join [e], or null when nothing is in reach.
ConnectPlan? connectTarget(Project p, Entity e) {
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

bool canConnect(Project p, Entity e) => connectTarget(p, e) != null;

/// Cheapest enabled pipe of the same use that withstands the pressure of
/// [pipe] (steady, or steady plus water hammer with [surge]) with a bore not
/// smaller than the current one; null when the catalogue has none.
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
    if (s.pressureRatingM < need - 1e-6 || s.innerDiameterMm < bore * 0.98 - 1e-9) continue;
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
/// [supply] (first-fit decreasing by zone flow), or null when a single zone
/// is already above it or the supply has no design flow.
List<SystemFlow>? splitFlowsPlan(Project p, DesignResults r, WaterSupplyEntity supply, String Function(String key) label) {
  final cap = supply.designFlow;
  if (!(cap > 0)) return null;
  final flows = p.systemFlows;
  final valveIds = flows.isNotEmpty
      ? [for (final f in flows) ...f.valveIds]
      : [...p.entities.whereType<ControlValveEntity>().map((v) => v.id), ...p.entities.whereType<PivotEntity>().map((v) => v.id)];
  final demand = <String, double>{};
  for (final id in valveIds.toSet()) {
    final q = r.zones[id]?.totalFlow ?? r.pivots[id]?.flow;
    if (q == null) continue;
    if (q > cap + 1e-12) return null;
    demand[id] = q;
  }
  if (demand.isEmpty) return null;
  final durationOf = <String, double>{};
  for (final f in flows) {
    for (final id in f.valveIds) {
      durationOf[id] = math.max(durationOf[id] ?? 0, f.durationHours > 0 ? f.durationHours : 1);
    }
  }
  final order = demand.keys.toList()..sort((a, b) => demand[b]!.compareTo(demand[a]!));
  final bins = <(List<String>, double)>[];
  for (final id in order) {
    var placed = false;
    for (var i = 0; i < bins.length; i++) {
      if (bins[i].$2 + demand[id]! <= cap + 1e-12) {
        bins[i] = ([...bins[i].$1, id], bins[i].$2 + demand[id]!);
        placed = true;
        break;
      }
    }
    if (!placed) bins.add(([id], demand[id]!));
  }
  var start = flows.isEmpty ? 0.0 : flows.map((f) => f.startHour).reduce(math.min);
  final taken = {for (final f in flows) f.id};
  final out = <SystemFlow>[];
  for (var i = 0; i < bins.length; i++) {
    final ids = bins[i].$1;
    final dur = ids.map((id) => durationOf[id] ?? 1.0).reduce(math.max);
    var id = 'sfa${i + 1}';
    for (var k = 2; taken.contains(id); k++) {
      id = 'sfa${i + 1}_$k';
    }
    out.add(SystemFlow(id: id, name: '${label('name.flow')} ${i + 1}', valveIds: ids.toSet(), startHour: start, durationHours: dur));
    start += dur;
  }
  return out;
}
