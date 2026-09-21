/// Automatic corrections of the design advisor: one correction at a time
/// ([applyFix]), the "fix automatically" loop ([runAutoFix]) and the design
/// optimisation ([runOptimize]). Every function edits the project in place;
/// the caller takes the undo snapshot and runs the design between rounds.
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/split.dart';
import 'advisor.dart';
import 'network_builder.dart';
import 'pump_selection.dart';
import 'results.dart';

/// Outcome of a correction: a message key (`fixed.<kind>` on success,
/// `fixfail.<reason>` otherwise) with its arguments.
class FixResult {
  const FixResult.done(this.key, [this.args = const {}]) : ok = true;
  const FixResult.failed(this.key, [this.args = const {}]) : ok = false;
  final bool ok;
  final String key;
  final Map<String, String> args;
}

String _m(double v) => v.toStringAsFixed(v < 10 ? 2 : 1);

/// Applies correction [kind] of [a] to [p]. [results] are the latest design
/// results (needed by the [resultFixes]); [label] translates the names given
/// to new items and flows.
FixResult applyFix(Project p, Advice a, FixKind kind, {DesignResults? results, String Function(String key)? label, String lang = 'en'}) {
  final tr = label ?? (String k) => k;
  final ents = [for (final id in a.entityIds) p.byId(id)].whereType<Entity>().toList();
  final first = ents.isEmpty ? null : ents.first;
  if (resultFixes.contains(kind) && results == null) return const FixResult.failed('fixfail.needsResults');
  switch (kind) {
    case FixKind.connect:
      if (first == null) return const FixResult.failed('fixfail.notFound');
      final plan = connectTarget(p, first);
      if (plan == null) return FixResult.failed('fixfail.nothingNear', {'d': _m(connectReach(p))});
      final d = plan.distance;
      if (plan.splitPipe != null) splitPipeAt(p, plan.splitPipe!, plan.to);
      switch (plan.moved) {
        case PointEntity e:
          e.position = plan.to;
        case PolyEntity e:
          e.points[plan.index] = plan.to;
        default:
          return const FixResult.failed('fixfail.notFound');
      }
      return FixResult.done('fixed.connect', {'d': _m(d)});

    case FixKind.deleteItem:
      if (ents.isEmpty) return const FixResult.failed('fixfail.notFound');
      p.entities.removeWhere((e) => a.entityIds.contains(e.id));
      return FixResult.done('fixed.deleteItem', {'n': '${ents.length}'});

    case FixKind.cleanSegments:
      final tol = math.max(p.params.connectTolerance, 1e-3);
      var n = 0;
      for (final e in ents) {
        if (e is! PolyEntity) continue;
        final pts = e.points;
        final kept = <Pt>[];
        for (var i = 0; i < pts.length; i++) {
          final last = i == pts.length - 1;
          if (kept.isNotEmpty && pts[i].distanceTo(kept.last) < tol) {
            if (last) kept[kept.length - 1] = pts[i]; // keep the true end
            n++;
            continue;
          }
          kept.add(pts[i]);
        }
        if (kept.length < 2 || polylineLength(kept) < tol) {
          p.entities.remove(e);
        } else {
          pts
            ..clear()
            ..addAll(kept);
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.cleanSegments', {'n': '$n'});

    case FixKind.removeDuplicates:
      if (ents.length < 2) return const FixResult.failed('fixfail.notFound');
      final drop = ents.skip(1).map((e) => e.id).toSet();
      p.entities.removeWhere((e) => drop.contains(e.id));
      return FixResult.done('fixed.removeDuplicates', {'n': '${drop.length}'});

    case FixKind.renameZone:
      final valves = ents.whereType<ControlValveEntity>().toList();
      if (valves.length < 2) return const FixResult.failed('fixfail.notFound');
      final names = {for (final v in p.entities.whereType<ControlValveEntity>()) v.zoneName.trim().toLowerCase()};
      var n = 0;
      for (final v in valves.skip(1)) {
        final base = v.zoneName.trim();
        var k = 2;
        var name = '$base $k';
        while (names.contains(name.toLowerCase())) {
          name = '$base ${++k}';
        }
        names.add(name.toLowerCase());
        if (v.name == v.zoneName) v.name = name;
        v.zoneName = name;
        n++;
      }
      return FixResult.done('fixed.renameZone', {'n': '$n'});

    case FixKind.calculateSupply:
      final supplies = _suppliesOf(p, a, results).where((s) => !s.calculatePressure).toList();
      if (supplies.isEmpty) return const FixResult.failed('fixfail.noChange');
      for (final s in supplies) {
        s.calculatePressure = true;
      }
      return FixResult.done('fixed.calculateSupply', {'n': supplies.map((s) => s.name.isEmpty ? tr('name.supply') : s.name).join(', ')});

    case FixKind.choosePump:
    case FixKind.submersiblePump:
      final supplies = _suppliesOf(p, a, results);
      if (supplies.isEmpty) return const FixResult.failed('fixfail.noSupply');
      final target = first is PumpEntity ? first : null;
      final supply = target == null ? supplies.first : _nearest(supplies, target.position);
      return choosePumpFor(p, results!, supply, target: target, submersible: kind == FixKind.submersiblePump);

    case FixKind.autoSizePipes:
      final targets = a.contextId != null && p.byId(a.contextId!) is ControlValveEntity ? zoneEntities(p, a.contextId!, NetworkBuilder(p).build()) : ents;
      var n = 0;
      for (final e in targets) {
        if (e is PipeEntity && !e.computerSized) {
          e.computerSized = true;
          n++;
        } else if (e is SpraylineEntity && !e.computerSized) {
          e.computerSized = true;
          n++;
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.autoSizePipes', {'n': '$n'});

    case FixKind.raisePipeClass:
      if (first is! PipeEntity) return const FixResult.failed('fixfail.notFound');
      final spec = higherClassPipe(p, results!, first, surge: a.code == 'surge_rating_exceeded');
      if (spec == null) return const FixResult.failed('fixfail.noOption');
      first
        ..pipeSpecId = spec.id
        ..computerSized = false;
      return FixResult.done('fixed.raisePipeClass', {'n': spec.name});

    case FixKind.resizeValve:
      final vid = a.contextId ?? (first is ControlValveEntity ? first.id : null);
      final v = vid == null ? null : p.byId(vid);
      if (v is! ControlValveEntity) return const FixResult.failed('fixfail.notFound');
      final spec = fittingValve(p, results!, v.id);
      if (spec == null) return const FixResult.failed('fixfail.noOption');
      v.valveSpecId = spec.id;
      return FixResult.done('fixed.resizeValve', {'n': spec.name});

    case FixKind.assignModel:
      if (first == null) return const FixResult.failed('fixfail.notFound');
      final name = _assignModel(p, first, results, tr);
      return name == null ? const FixResult.failed('fixfail.noOption') : FixResult.done('fixed.assignModel', {'n': name});

    case FixKind.splitFlows:
      final supply = first is WaterSupplyEntity ? first : (_suppliesOf(p, a, results).firstOrNull);
      if (supply == null) return const FixResult.failed('fixfail.noSupply');
      final plan = splitFlowsPlan(p, results!, supply, tr);
      if (plan == null) return const FixResult.failed('fixfail.noOption');
      p.systemFlows
        ..clear()
        ..addAll(plan);
      return FixResult.done('fixed.splitFlows', {'n': '${plan.length}'});

    case FixKind.addFittings:
      final have = {for (final f in p.catalog.fittings) f.id};
      final add = [for (final f in Catalog.defaultFittings(p.catalog.pipes, lang: lang, currency: p.params.currencyCode)) if (!have.contains(f.id)) f];
      if (add.isEmpty) return const FixResult.failed('fixfail.noChange');
      p.catalog.fittings.addAll(add);
      return FixResult.done('fixed.addFittings', {'n': '${add.length}'});

    case FixKind.joinCrossing:
      final pipes = ents.whereType<PipeEntity>().toList();
      final at = a.at;
      if (pipes.length != 2 || at == null) return const FixResult.failed('fixfail.notFound');
      for (final pipe in pipes) {
        splitPipeAt(p, pipe, at);
      }
      return const FixResult.done('fixed.joinCrossing');

    case FixKind.addSupply:
      final ends = mainlineFreeEnds(p);
      if (ends.length != 1) return const FixResult.failed('fixfail.noOption');
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: ends.single, name: tr('name.supply'), calculatePressure: true));
      return const FixResult.done('fixed.addSupply');

    case FixKind.resetSettings:
      final s = p.params, d = DesignParameters();
      bool bad(double v, double lo, double hi) => !(v >= lo && v <= hi);
      switch (a.code) {
        case 'set_velocity':
          if (bad(s.maxZoneVelocity, 0.3, 5)) s.maxZoneVelocity = d.maxZoneVelocity;
          if (bad(s.maxMainlineVelocity, 0.3, 5)) s.maxMainlineVelocity = d.maxMainlineVelocity;
          if (bad(s.maxLateralVelocity, 0.3, 5)) s.maxLateralVelocity = d.maxLateralVelocity;
        case 'set_hours':
          if (bad(s.hoursPerYear, 1, 8760)) s.hoursPerYear = d.hoursPerYear;
          if (bad(s.zoneHoursPerYear, 1, 8760)) s.zoneHoursPerYear = d.zoneHoursPerYear;
        case 'set_economy':
          if (bad(s.interestRate, 0, 0.5)) s.interestRate = d.interestRate;
          if (s.termYears < 1 || s.termYears > 100) s.termYears = d.termYears;
          if (bad(s.pumpEfficiency, 0.2, 0.95)) s.pumpEfficiency = d.pumpEfficiency;
          if (s.powerCostPerKwh < 0) s.powerCostPerKwh = d.powerCostPerKwh;
        case 'set_tolerance':
          s.connectTolerance = d.connectTolerance;
        case 'set_variation':
          s.maxZoneVariationPct = d.maxZoneVariationPct;
        case 'set_temperature':
          s.waterTempC = d.waterTempC;
        default:
          return const FixResult.failed('fixfail.noChange');
      }
      return const FixResult.done('fixed.resetSettings');

    case FixKind.enablePipes:
      final usage = PipeUsage.values.where((u) => u.name == a.value).firstOrNull;
      if (usage == null) return const FixResult.failed('fixfail.notFound');
      var n = 0;
      for (final s in p.catalog.pipes) {
        if (!s.enabled && s.usage.contains(usage)) {
          s.enabled = true;
          n++;
        }
      }
      if (n == 0) {
        final have = {for (final s in p.catalog.pipes) s.id};
        for (final s in Catalog.defaultCatalog(lang: lang, currency: p.params.currencyCode).pipes) {
          if (s.enabled && s.usage.contains(usage) && !have.contains(s.id)) {
            p.catalog.pipes.add(s);
            n++;
          }
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noOption') : FixResult.done('fixed.enablePipes', {'n': '$n'});

    case FixKind.fixSupplyLimits:
      var n = 0;
      for (final s in ents.whereType<WaterSupplyEntity>()) {
        if (!s.calculatePressure && s.maxHeadM > 0 && s.designHeadM > s.maxHeadM) {
          s.maxHeadM = s.designHeadM;
          n++;
        }
        if (s.maxFlow > 0 && s.designFlow > s.maxFlow) {
          s.maxFlow = s.designFlow;
          n++;
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : const FixResult.done('fixed.fixSupplyLimits');

    case FixKind.addMissingFlow:
      final inFlow = {for (final f in p.systemFlows) ...f.valveIds};
      final ids = [for (final e in ents) if ((e is ControlValveEntity || e is PivotEntity) && !inFlow.contains(e.id)) e.id];
      if (ids.isEmpty) return const FixResult.failed('fixfail.noChange');
      final end = p.systemFlows.fold<double>(0, (m, f) => math.max(m, f.startHour + math.max(f.durationHours, 0)));
      final taken = {for (final f in p.systemFlows) f.id};
      var id = 'sfm1';
      for (var k = 2; taken.contains(id); k++) {
        id = 'sfm$k';
      }
      p.systemFlows.add(SystemFlow(id: id, name: '${tr('name.flow')} ${p.systemFlows.length + 1}', valveIds: ids.toSet(), startHour: end, durationHours: 1));
      return FixResult.done('fixed.addMissingFlow', {'n': '${ids.length}'});

    case FixKind.removeEmptyFlows:
      final ids = {for (final e in p.entities) e.id};
      var n = 0;
      for (final f in p.systemFlows) {
        final gone = f.valveIds.where((id) => !ids.contains(id)).toList();
        f.valveIds.removeAll(gone);
        n += gone.length;
      }
      final before = p.systemFlows.length;
      p.systemFlows.removeWhere((f) => f.valveIds.isEmpty);
      n += before - p.systemFlows.length;
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.removeEmptyFlows', {'n': '$n'});

    case FixKind.fixFlowDurations:
      var n = 0;
      for (final f in p.systemFlows) {
        if (!(f.durationHours > 0)) {
          f.durationHours = 1;
          n++;
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.fixFlowDurations', {'n': '$n'});

    case FixKind.nominalEmitterHead:
      var n = 0;
      for (final e in ents) {
        switch (e) {
          case OutletEntity o:
            final nz = p.catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
            if (nz != null) {
              o.headM = nz.defaultHeadM.clamp(nz.minHeadM, math.max(nz.minHeadM, nz.maxHeadM)).toDouble();
              n++;
            }
          case SpraylineEntity s:
            final nz = p.catalog.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
            if (nz != null) {
              s.headM = nz.defaultHeadM.clamp(nz.minHeadM, math.max(nz.minHeadM, nz.maxHeadM)).toDouble();
              n++;
            }
          case TapeEntity t:
            final spec = p.catalog.tape(t.tapeSpecId);
            if (spec != null) {
              t.inletHeadM = spec.defaultInletHeadM.clamp(spec.minHeadM, math.max(spec.minHeadM, spec.maxHeadM)).toDouble();
              n++;
            }
          default:
            break;
        }
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.nominalEmitterHead', {'n': '$n'});

    case FixKind.resetPumpSpeed:
      var n = 0;
      for (final e in ents.whereType<PumpEntity>()) {
        e.speedRatio = 1;
        n++;
      }
      return n == 0 ? const FixResult.failed('fixfail.noChange') : FixResult.done('fixed.resetPumpSpeed', {'n': '$n'});
  }
}

/// Cuts [pipe] at [at] (a point on it) so the point becomes a vertex shared
/// by the two pieces; false when [at] already is a vertex or off the pipe.
bool splitPipeAt(Project p, PipeEntity pipe, Pt at) {
  final pts = pipe.points;
  if (pts.length < 2 || pts.any((v) => v.distanceTo(at) <= 1e-9)) return false;
  final (d, cp) = polylineStationOf(pts, at);
  if (cp.distanceTo(at) > math.max(p.params.connectTolerance, 1e-3) + 1e-6) return false;
  final pieces = splitLinearEntity(pipe, [d], () => p.newId());
  if (pieces.length < 2) return false;
  for (final piece in pieces) {
    final pp = (piece as PipeEntity).points;
    for (var i = 0; i < pp.length; i++) {
      if (pp[i].distanceTo(cp) < 1e-9) pp[i] = at;
    }
  }
  final idx = p.entities.indexOf(pipe);
  if (idx < 0) return false;
  p.entities
    ..removeAt(idx)
    ..insertAll(idx, pieces);
  return true;
}

WaterSupplyEntity _nearest(List<WaterSupplyEntity> list, Pt at) => list.reduce((a, b) => a.position.distanceTo(at) <= b.position.distanceTo(at) ? a : b);

/// Supplies a problem is about: the item itself, the supplies of its system
/// flow, else every supply of the project.
List<WaterSupplyEntity> _suppliesOf(Project p, Advice a, DesignResults? r) {
  final own = [for (final id in a.entityIds) p.byId(id)].whereType<WaterSupplyEntity>().toList();
  if (own.isNotEmpty) return own;
  if (r != null && a.contextId != null) {
    for (final f in r.systemFlows) {
      if (f.flowId != a.contextId) continue;
      final ids = f.supplies.map((s) => s.supplyId).toSet();
      final list = p.entities.whereType<WaterSupplyEntity>().where((s) => ids.contains(s.id)).toList();
      if (list.isNotEmpty) return list;
    }
  }
  return p.entities.whereType<WaterSupplyEntity>().toList();
}

/// Selects the single catalogue pump with the lowest life-cycle cost that
/// meets every duty of [supply] (all system flows) and puts it in [target]
/// (by default the pump nearest to the supply) or, without a pump, inserts
/// one on the mainline pipe leaving the supply. With [submersible] only
/// submersible pumps are considered (also when the water is too deep for a
/// surface pump or the current pump is submersible).
FixResult choosePumpFor(Project p, DesignResults r, WaterSupplyEntity supply, {PumpEntity? target, bool submersible = false}) {
  final cat = p.catalog;
  target ??= () {
    PumpEntity? best;
    var bd = 50.0;
    for (final e in p.entities.whereType<PumpEntity>()) {
      if (e.scope != HydraulicScope.mainline) continue;
      final d = e.position.distanceTo(supply.position);
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }();
  // pump head needed per flow: what the supply lacks plus what the pump
  // being replaced already adds
  final duties = <(double, double, SupplyDuty)>[];
  for (final f in r.systemFlows) {
    for (final d in f.supplies) {
      if (d.supplyId != supply.id) continue;
      final base = d.requiredHead - (d.calculated ? 0 : d.head);
      final own = target == null ? 0.0 : f.devices.where((x) => x.entityId == target!.id).fold<double>(0, (m, x) => math.max(m, x.pumpHead));
      final need = base + own;
      if (d.flow > 0 && need > 0) duties.add((d.flow, need, d));
    }
  }
  if (duties.isEmpty) return const FixResult.failed('fixfail.noDuty');
  duties.sort((a, b) => b.$2.compareTo(a.$2));
  final worst = duties.first;
  final wantSub = submersible || (target != null && (cat.pump(target.pumpSpecId)?.submersible ?? false)) || suctionLiftTooDeep(supply, worst.$3);
  final cands = rankPumps(
    cat,
    flow: worst.$1,
    head: worst.$2,
    staticHead: supply.calculatePressure ? staticLift(p, r, supply, worst.$3) : null,
    hoursPerYear: p.params.hoursPerYear,
    costPerKwh: p.params.powerCostPerKwh,
    otherDuties: [for (final d in duties.skip(1)) (d.$1, d.$2)],
    requireSubmersible: wantSub,
  );
  final pick = cands.where((c) => c.suitable && c.parallelCount == 1).firstOrNull;
  if (pick == null) return const FixResult.failed('fixfail.noPump');
  if (target != null) {
    if (target.pumpSpecId == pick.spec.id && target.speedRatio == 1) return FixResult.failed('fixfail.alreadyBest', {'n': pick.spec.name});
    target
      ..pumpSpecId = pick.spec.id
      ..speedRatio = 1;
    return FixResult.done('fixed.choosePump', {'n': pick.spec.name});
  }
  // new pump 1.5 m along the mainline pipe leaving the supply
  final tol = math.max(p.params.connectTolerance, 1e-3);
  for (final pipe in p.entities.whereType<PipeEntity>().toList()) {
    if (pipe.scope != HydraulicScope.mainline || pipe.points.length < 2) continue;
    final atStart = pipe.points.first.distanceTo(supply.position) <= tol;
    final atEnd = pipe.points.last.distanceTo(supply.position) <= tol;
    if (!atStart && !atEnd) continue;
    final len = pipe.length;
    final along = math.min(1.5, len / 3);
    final pos = pointAlongPolyline(pipe.points, atStart ? along : len - along);
    splitPipeAt(p, pipe, pos);
    p.entities.add(PumpEntity(id: p.newId(), position: pos, pumpSpecId: pick.spec.id));
    return FixResult.done('fixed.insertPump', {'n': pick.spec.name});
  }
  return const FixResult.failed('fixfail.noPipeAtSupply');
}

/// Gives [e] a catalogue model; returns its name (null: nothing suitable).
String? _assignModel(Project p, Entity e, DesignResults? r, String Function(String) tr) {
  final cat = p.catalog;
  switch (e) {
    case PipeEntity pipe:
      pipe
        ..pipeSpecId = null
        ..computerSized = true;
      return tr('auto');
    case PivotEntity pv:
      pv.pipeSpecId = null;
      return tr('auto');
    case ControlValveEntity v:
      final fit = r == null ? null : fittingValve(p, r, v.id);
      final spec = fit ?? (cat.valves.where((s) => s.enabled && s.kind == ValveKind.control).toList()..sort((a, b) => a.sizeMm.compareTo(b.sizeMm))).firstOrNull;
      if (spec == null) return null;
      v.valveSpecId = spec.id;
      return spec.name;
    case PumpEntity pump:
      final spec = cat.pumps.where((s) => s.enabled).firstOrNull;
      if (spec == null) return null;
      pump.pumpSpecId = spec.id;
      return spec.name;
    case MiscHydraulicEntity m:
      final spec = cat.valves.where((s) => s.enabled && s.kind != ValveKind.control).firstOrNull;
      if (spec == null) return null;
      m.valveSpecId = spec.id;
      return spec.name;
    case OutletEntity o:
      final outlet = cat.outlet(o.outletSpecId) ?? cat.outlets.where((s) => s.enabled && s.nozzles.isNotEmpty).firstOrNull;
      final nozzle = outlet?.nozzle(o.nozzleId) ?? outlet?.nozzles.firstOrNull;
      if (outlet == null || nozzle == null) return null;
      o
        ..outletSpecId = outlet.id
        ..nozzleId = nozzle.id
        ..headM = nozzle.defaultHeadM;
      return '${outlet.name} ${nozzle.name}';
    case SpraylineEntity s:
      final outlet = cat.outlet(s.outletSpecId) ?? cat.outlets.where((x) => x.enabled && x.nozzles.isNotEmpty).firstOrNull;
      final nozzle = outlet?.nozzle(s.nozzleId) ?? outlet?.nozzles.firstOrNull;
      if (outlet == null || nozzle == null) return null;
      s
        ..outletSpecId = outlet.id
        ..nozzleId = nozzle.id
        ..headM = nozzle.defaultHeadM;
      return '${outlet.name} ${nozzle.name}';
    case TapeEntity t:
      final spec = cat.tapes.where((x) => x.enabled).firstOrNull;
      if (spec == null) return null;
      t
        ..tapeSpecId = spec.id
        ..inletHeadM = spec.defaultInletHeadM;
      return spec.name;
    default:
      return null;
  }
}

// ---------------------------------------------------------------- fix automatically

/// One round of the automatic correction. Settings and drawing corrections
/// go first, because they change what the design sees; the corrections that
/// need design results run only in a round without them (and with fresh
/// [results]). [attempted] collects the problems already tried, so a
/// correction that did not help is not repeated.
List<FixResult> autoFixRound(Project p, List<Advice> advice, {DesignResults? results, required Set<String> attempted, String Function(String key)? label, String lang = 'en'}) {
  final candidates = [for (final a in advice) if (a.autoFixable && !attempted.contains('${a.key}|${a.fixes.first.name}')) a];
  final drawing = [for (final a in candidates) if (!resultFixes.contains(a.fixes.first)) a];
  final round = drawing.isNotEmpty ? drawing : [if (results != null) ...candidates];
  final out = <FixResult>[];
  final touched = <String>{};
  for (final a in round) {
    // two problems on the same item: the second waits for the next round
    if (a.entityIds.any(touched.contains)) continue;
    final kind = a.fixes.first;
    attempted.add('${a.key}|${kind.name}');
    final res = applyFix(p, a, kind, results: results, label: label, lang: lang);
    if (res.ok) {
      out.add(res);
      touched.addAll(a.entityIds);
      // one pump / flow change per round: the next one needs new results
      if (kind == FixKind.choosePump || kind == FixKind.submersiblePump || kind == FixKind.splitFlows) break;
    }
  }
  return out;
}

class AutoFixReport {
  AutoFixReport(this.applied, this.remaining, this.results, this.rounds);
  final List<FixResult> applied;
  final List<Advice> remaining;
  final DesignResults? results;
  final int rounds;
  int get errors => remaining.where((a) => a.level == AdviceLevel.error).length;
  int get warnings => remaining.where((a) => a.level == AdviceLevel.warning).length;
}

/// Fixes what can be fixed safely: designs ([design] runs the design and
/// returns its results, null when it cannot run), applies a round of
/// corrections, designs again, and repeats until a round changes nothing
/// (at most [maxRounds]).
Future<AutoFixReport> runAutoFix(Project p, Future<DesignResults?> Function() design, {String Function(String key)? label, String lang = 'en', int maxRounds = 6, void Function(int round)? onRound}) async {
  final applied = <FixResult>[];
  final attempted = <String>{};
  var results = await design();
  var rounds = 0;
  for (; rounds < maxRounds; rounds++) {
    onRound?.call(rounds + 1);
    final advice = buildAdvice(p, results: results);
    final done = autoFixRound(p, advice, results: results, attempted: attempted, label: label, lang: lang);
    if (done.isEmpty) break;
    applied.addAll(done);
    results = await design();
  }
  return AutoFixReport(applied, buildAdvice(p, results: results), results, rounds);
}

// ---------------------------------------------------------------- optimisation

class OptimizeOptions {
  const OptimizeOptions({this.resizeFixedPipes = false, this.choosePumps = true, this.resizeValves = true});

  /// Also let the design choose the pipes whose diameter the user fixed.
  final bool resizeFixedPipes;

  /// Pick the pump with the lowest life-cycle cost for every supply.
  final bool choosePumps;

  /// Smallest control valve that carries the flow of each zone.
  final bool resizeValves;
}

/// Cost and problem count of a design, for the before / after comparison.
class DesignScore {
  DesignScore(DesignResults? r, List<Advice> advice)
      : capital = r?.capitalCost ?? 0,
        annualCapital = r?.annualCapitalCost ?? 0,
        energy = r?.annualEnergyCost ?? 0,
        errors = advice.where((a) => a.level == AdviceLevel.error).length,
        warnings = advice.where((a) => a.level == AdviceLevel.warning).length;
  final double capital;
  final double annualCapital;
  final double energy;
  final int errors;
  final int warnings;
  double get annualTotal => annualCapital + energy;

  /// Fewer errors wins; with as many errors, the lower annual cost.
  bool betterThan(DesignScore o) => errors != o.errors ? errors < o.errors : annualTotal < o.annualTotal - 1e-6 * math.max(1, o.annualTotal);
}

class OptimizeReport {
  OptimizeReport(this.before, this.after, this.applied, this.results);
  final DesignScore before;
  final DesignScore after;
  final List<FixResult> applied;
  final DesignResults? results;
  bool get improved => after.betterThan(before);
}

/// Optimises the design for the lowest annual cost (annualised investment
/// plus energy) that meets every requirement: LP sizing that trades pipe
/// cost against pumping energy, optionally every pipe free, the smallest
/// valve per zone and the pump with the lowest life-cycle cost per supply.
/// The caller keeps or undoes the result ([OptimizeReport.improved]).
Future<OptimizeReport> runOptimize(Project p, Future<DesignResults?> Function() design, {OptimizeOptions options = const OptimizeOptions(), DesignResults? baseline, String Function(String key)? label}) async {
  final start = baseline ?? await design();
  final before = DesignScore(start, buildAdvice(p, results: start));
  final applied = <FixResult>[];
  if (options.resizeFixedPipes) {
    var n = 0;
    for (final e in p.entities) {
      if (e is PipeEntity && !e.computerSized) {
        e.computerSized = true;
        n++;
      } else if (e is SpraylineEntity && !e.computerSized) {
        e.computerSized = true;
        n++;
      }
    }
    if (n > 0) applied.add(FixResult.done('fixed.autoSizePipes', {'n': '$n'}));
  }
  final params = p.params;
  if (params.sizingMethod != SizingMethod.lp || (params.powerCostPerKwh > 0 && !params.tradeCapitalVsRunning)) {
    params.sizingMethod = SizingMethod.lp;
    if (params.powerCostPerKwh > 0) params.tradeCapitalVsRunning = true;
    applied.add(const FixResult.done('fixed.lpSizing'));
  }
  if (options.resizeValves && start != null) {
    for (final v in p.entities.whereType<ControlValveEntity>().toList()) {
      final spec = fittingValve(p, start, v.id);
      if (spec == null) continue;
      v.valveSpecId = spec.id;
      applied.add(FixResult.done('fixed.resizeValve', {'n': spec.name}));
    }
  }
  var results = await design();
  if (options.choosePumps && results != null) {
    var changed = false;
    for (final s in p.entities.whereType<WaterSupplyEntity>().toList()) {
      final hasPump = p.entities.any((e) => e is PumpEntity && e.scope == HydraulicScope.mainline && e.position.distanceTo(s.position) < 50);
      if (!hasPump) continue;
      final res = choosePumpFor(p, results, s);
      if (res.ok) {
        applied.add(res);
        changed = true;
      }
    }
    if (changed) results = await design();
  }
  return OptimizeReport(before, DesignScore(results, buildAdvice(p, results: results)), applied, results);
}
