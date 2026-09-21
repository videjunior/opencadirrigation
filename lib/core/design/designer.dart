/// Design orchestration: zone analysis and sizing, mainline analysis and
/// sizing per system flow, fittings, flushing, surge checks and the bill
/// of materials.
///
/// Sizing is a linear programme over the candidate diameters
/// of every computer-sized unit (pipe cost, interest, energy, topography
/// and the pressure window of the emitters), verified with the non-linear
/// network solver and repaired with a greedy upsizing when needed. The
/// older greedy method (velocity → pressure window → economics) remains
/// available as `SizingMethod.greedy`.
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/friction.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/network.dart';
import '../hydraulics/pump.dart';
import '../hydraulics/uniformity.dart';
import '../hydraulics/water_hammer.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/split.dart';
import '../units.dart';
import 'fittings.dart';
import 'lp_sizing.dart';
import 'network_builder.dart';
import 'pivot.dart';
import 'results.dart';

/// Stage of a design run, reported through [DesignProgress].
enum DesignStage { zones, mainline, splits, flushing, surge, bom }

/// Progress of [Designer.designAllAsync]: the stage about to run and the
/// number of steps completed out of the estimated total.
class DesignProgress {
  const DesignProgress({required this.stage, required this.done, required this.total, this.zoneId, this.zoneIndex = 0, this.zoneCount = 0});

  final DesignStage stage;

  /// Steps completed so far.
  final int done;

  /// Estimated total number of steps (grows when telescoped pipes need a
  /// second pass).
  final int total;

  /// Valve of the zone about to be processed (zone steps only).
  final String? zoneId;

  /// 1-based index of that zone, and the number of zones.
  final int zoneIndex;
  final int zoneCount;

  /// Completed fraction in 0..1.
  double get fraction => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {'stage': stage.name, 'done': done, 'total': total, if (zoneId != null) 'zone': zoneId, 'zi': zoneIndex, 'zn': zoneCount};

  static DesignProgress fromJson(Map<String, dynamic> j) => DesignProgress(
    stage: DesignStage.values.firstWhere((s) => s.name == j['stage'], orElse: () => DesignStage.zones),
    done: (j['done'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    zoneId: j['zone'] as String?,
    zoneIndex: (j['zi'] as num?)?.toInt() ?? 0,
    zoneCount: (j['zn'] as num?)?.toInt() ?? 0,
  );

  @override
  String toString() => 'DesignProgress(${stage.name} $done/$total${zoneId == null ? '' : ' zone $zoneIndex/$zoneCount'})';
}

typedef _DesignStep = ({DesignStage stage, String? zoneId, int zoneIndex, void Function() run});

class Designer {
  Designer(this.project, {String Function(String key)? label})
      : model = NetworkBuilder(project).build(),
        _label = label ?? ((k) => k);

  final Project project;
  final String Function(String key) _label;
  NetworkModel model;
  final DesignResults results = DesignResults(timestamp: DateTime.now());

  /// Working pipe assignment for computer-sized units (entity id -> spec id).
  final Map<String, String> _assigned = {};

  /// Telescoped units (entity id -> diameters and length fractions, largest
  /// first) to be split into pieces before the final analysis.
  final Map<String, List<(PipeSpec, double)>> _pendingSplits = {};

  Catalog get catalog => project.catalog;
  DesignParameters get params => project.params;

  /// Mainline node fed by a demand id: a control valve or a pivot.
  String? _demandNode(String id) => model.valveNodes[id]?.$1 ?? model.pivotNodes[id];

  /// Pivot / linear-move analysis: flow and required inlet pressure from the
  /// machine hydraulics with the worst ground rise around the circle.
  PivotResult analyzePivotEntity(PivotEntity p) {
    final pipe = catalog.pipe(p.pipeSpecId);
    final spec = PivotSpec(
      kind: p.kind,
      lengthM: p.radiusM,
      travelM: p.travelM,
      spanLengthM: p.spanLengthM,
      pipeInnerMm: pipe?.innerDiameterMm ?? p.pipeInnerMm,
      hazenC: params.adjustedC(pipe?.hazenC ?? p.hazenC),
      roughnessMm: pipe?.roughnessMm ?? 0.15,
      method: params.frictionMethod,
      kinematicViscosity: params.kinematicViscosity,
      pipeHeightM: p.pipeHeightM,
      endPressureM: p.endPressureM,
      endGunFlow: p.endGunFlow,
      endGunPressureM: p.endGunPressureM,
      endThrowM: p.endThrowM,
      grossDepthMm: p.grossDepthMm,
      hoursPerCycle: p.hoursPerCycle,
      wettedWidthM: p.wettedWidthM,
      machineLossM: p.machineLossM,
      maxAppRateMmH: p.maxAppRateMmH,
      sectorDeg: p.sectorDeg,
      maxVelocity: math.max(params.maxMainlineVelocity, 3.0),
      sprinklerSpacingM: p.sprinklerSpacingM,
    );
    final terrain = model.terrain;
    final rise = terrain == null || terrain.isEmpty ? null : groundRiseFunction(spec, p.center, p.angleRad, terrain.elevationAt);
    final name = p.name.isNotEmpty ? p.name : (p.zoneName.isNotEmpty ? p.zoneName : _label('tool.pivot'));
    final nozzles = [for (final n in catalog.outlet(p.sprinklerSpecId)?.nozzles ?? const <NozzleSpec>[]) (n.name, n.curve)];
    return analyzePivot(spec, id: p.id, name: name, groundRiseAt: rise, nozzles: nozzles);
  }

  /// Flow and required head of a demand id (zone valve or pivot).
  (double, double) _demandOf(String id) {
    if (model.pivotNodes.containsKey(id)) {
      final p = project.byId(id);
      if (p is! PivotEntity) return (0, 0);
      final r = results.pivots[id] ?? analyzePivotEntity(p);
      results.pivots[id] = r;
      return (r.flow, r.inletHead);
    }
    final z = results.zones[id] ?? analyzeZone(id);
    results.zones[id] = z;
    return (z.totalFlow, z.requiredUpstreamHead);
  }

  // ------------------------------------------------------------ helpers

  PipeSpec? _specOf(GLink l) {
    final id = _assigned[l.entityId] ?? l.pipeSpecId;
    return catalog.pipe(id);
  }

  /// Pipe spec of a link after sizing (public for the fitting selector).
  PipeSpec? specOf(GLink l) => _specOf(l);

  List<PipeSpec> _candidates(GLink l) => catalog.pipesFor(l.usage);

  double _diameter(GLink l) {
    if (l.tapeSpecId != null) return catalog.tape(l.tapeSpecId)!.innerDiameter;
    final s = _specOf(l);
    if (s != null) return s.innerDiameter;
    final c = _candidates(l);
    return c.isEmpty ? 0.05 : c.first.innerDiameter;
  }

  double _vmax(GLink l) => switch (l.usage) {
    PipeUsage.lateral => params.maxLateralVelocity,
    PipeUsage.zone => params.maxZoneVelocity,
    PipeUsage.mainline => params.maxMainlineVelocity,
  };

  double _effectiveLength(GLink l) => math.max(l.length * (params.applyMinorLosses && l.usage != PipeUsage.lateral ? 1 + params.minorLossPct / 100 : 1), 1e-3);

  HLink _toHLink(GLink l) {
    switch (l.kind) {
      case GLinkKind.pipe:
        final tape = catalog.tape(l.tapeSpecId);
        final spec = _specOf(l);
        final c = params.adjustedC(tape?.hazenC ?? spec?.hazenC ?? 150);
        final rough = tape != null ? tape.roughnessMm / 1000 : (spec?.roughness ?? 1.5e-6);
        return HLink(id: l.id, from: l.from, to: l.to, diameter: _diameter(l), length: _effectiveLength(l), hazenC: c, roughness: rough, minorK: params.applyMinorLosses ? l.minorK : 0, tag: l);
      case GLinkKind.controlValve:
        final spec = catalog.valve(l.valveSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.device, device: spec?.loss ?? const DeviceLossCurve(k: 1e-3), tag: l);
      case GLinkKind.device:
        final spec = catalog.valve(l.valveSpecId);
        final curve = spec?.loss ?? const DeviceLossCurve(k: 0);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.device, device: curve.k > 0 ? curve : const DeviceLossCurve(k: 1e-3), checkValve: spec?.kind == ValveKind.check, tag: l);
      case GLinkKind.prv:
        final spec = catalog.valve(l.valveSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.prv, prvSetting: l.settingM, device: spec?.loss, tag: l);
      case GLinkKind.pump:
        final spec = catalog.pump(l.pumpSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.pump, pump: spec?.curve.withSpeed(l.speedRatio), tag: l);
    }
  }

  /// Head loss of a pipe link built with [spec] carrying [q] (m³/s).
  double _linkLoss(GLink l, PipeSpec spec, double q) {
    if (q <= 0) return 0;
    final hf = frictionLoss(method: params.frictionMethod, flow: q, diameter: spec.innerDiameter, length: _effectiveLength(l), c: params.adjustedC(spec.hazenC), roughness: spec.roughness, kinematicViscosity: params.kinematicViscosity);
    final hm = params.applyMinorLosses && l.minorK > 0 ? minorLoss(k: l.minorK, flow: q, diameter: spec.innerDiameter) : 0.0;
    return hf + hm;
  }

  /// Head loss of a link with its current diameter (tapes, fixed pipes).
  double _currentLoss(GLink l, double q) {
    if (q <= 0) return 0;
    final tape = catalog.tape(l.tapeSpecId);
    final spec = _specOf(l);
    final c = params.adjustedC(tape?.hazenC ?? spec?.hazenC ?? 150);
    final rough = tape != null ? tape.roughnessMm / 1000 : (spec?.roughness ?? 1.5e-6);
    final d = _diameter(l);
    final hf = frictionLoss(method: params.frictionMethod, flow: q, diameter: d, length: _effectiveLength(l), c: c, roughness: rough, kinematicViscosity: params.kinematicViscosity);
    final hm = params.applyMinorLosses && l.minorK > 0 ? minorLoss(k: l.minorK, flow: q, diameter: d) : 0.0;
    return hf + hm;
  }

  NetworkOptions get _options => NetworkOptions(method: params.frictionMethod, kinematicViscosity: params.kinematicViscosity);

  /// Shortest-hop path (list of links) from [start] to [target] over the given link set.
  List<GLink> _path(String start, String target, Set<String> allowed) {
    final parent = <String, GLink?>{start: null};
    final queue = [start];
    var head = 0;
    while (head < queue.length) {
      final id = queue[head++];
      if (id == target) break;
      for (final l in model.nodes[id]!.links) {
        if (!allowed.contains(l.id)) continue;
        final o = l.other(id);
        if (!parent.containsKey(o)) {
          parent[o] = l;
          queue.add(o);
        }
      }
    }
    if (!parent.containsKey(target)) return const [];
    final path = <GLink>[];
    var cur = target;
    while (cur != start) {
      final l = parent[cur]!;
      path.add(l);
      cur = l.other(cur);
    }
    return path.reversed.toList();
  }

  /// BFS from [roots] over [allowed] links: parent link, source root and hop
  /// depth of every reached node.
  (Map<String, GLink?>, Map<String, String>, Map<String, int>) _bfs(Iterable<String> roots, Set<String> allowed) {
    final parent = <String, GLink?>{};
    final source = <String, String>{};
    final depth = <String, int>{};
    final queue = <String>[];
    for (final r in roots) {
      parent[r] = null;
      source[r] = r;
      depth[r] = 0;
      queue.add(r);
    }
    var head = 0;
    while (head < queue.length) {
      final id = queue[head++];
      for (final l in model.nodes[id]!.links) {
        if (!allowed.contains(l.id)) continue;
        final o = l.other(id);
        if (!parent.containsKey(o)) {
          parent[o] = l;
          source[o] = source[id]!;
          depth[o] = depth[id]! + 1;
          queue.add(o);
        }
      }
    }
    return (parent, source, depth);
  }

  List<GLink> _pathFromParents(Map<String, GLink?> parent, String node) {
    final path = <GLink>[];
    var cur = node;
    while (true) {
      final l = parent[cur];
      if (l == null) break;
      path.add(l);
      cur = l.other(cur);
    }
    return path;
  }

  PipeSpec? _next(PipeSpec current, List<PipeSpec> cands) {
    for (final c in cands) {
      if (c.innerDiameterMm > current.innerDiameterMm + 1e-9) return c;
    }
    return null;
  }

  // ------------------------------------------------------------ zones

  static const double _hwExp = 4.871;

  /// Builds the hydraulic network of a zone. [emitterMode] true = pressure
  /// dependent, false = nominal fixed demands.
  HydraulicNetwork _zoneNetwork(String valveId, double downstreamHead, bool detailed) {
    final net = HydraulicNetwork(options: _options);
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final nodeIds = model.zoneNodes[valveId] ?? {};
    for (final id in nodeIds) {
      final n = model.nodes[id]!;
      if (id == zoneNode) {
        net.addNode(HNode(id: id, kind: HNodeKind.reservoir, elevation: n.elevation, fixedHead: n.elevation + downstreamHead));
        continue;
      }
      final h = HNode(id: id, elevation: n.elevation);
      net.addNode(h);
      _attachEmitters(net, h, n, detailed);
    }
    for (final lid in model.zoneLinks[valveId] ?? <String>{}) {
      final l = model.linkById(lid)!;
      net.addLink(_toHLink(l));
    }
    return net;
  }

  void _attachEmitters(HydraulicNetwork net, HNode h, GNode n, bool detailed) {
    if (n.emitters.isEmpty) return;
    if (!detailed) {
      h.demand = n.emitters.fold(0.0, (s, e) => s + e.nominalFlow);
      return;
    }
    var first = true;
    var satellite = 0;
    for (final e in n.emitters) {
      if (first) {
        h.emitter = e.curve;
        h.emitterCount = e.count;
        h.emitterOffset = e.offset;
        first = false;
      } else if (identical(h.emitter, e.curve) && (h.emitterOffset - e.offset).abs() < 1e-9) {
        h.emitterCount += e.count;
      } else {
        final sid = '${n.id}_s${satellite++}';
        net.addNode(HNode(id: sid, elevation: n.elevation, emitter: e.curve, emitterCount: e.count, emitterOffset: e.offset));
        net.addLink(HLink(id: 'sat_$sid', from: n.id, to: sid, diameter: 0.5, length: 0.01, hazenC: 150));
      }
    }
  }

  /// Mean reference pressure of the emitters of a zone from a solved network.
  (double, double) _meanPressures(String valveId, NetworkResult r) {
    var sumActual = 0.0, sumNominal = 0.0, w = 0.0;
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      final head = r.nodes[id]?.head;
      if (head == null) continue;
      for (final e in n.emitters) {
        if (e.index == -2) continue; // flushing
        final isTapeInlet = e.entityId.isNotEmpty && project.byId(e.entityId) is TapeEntity;
        if (isTapeInlet && e.index != 0) continue;
        final p = head - (n.elevation + e.offset);
        sumActual += p * e.count;
        sumNominal += e.nominalHead * e.count;
        w += e.count;
      }
    }
    if (w == 0) return (0, 0);
    return (sumActual / w, sumNominal / w);
  }

  ZoneResult analyzeZone(String valveId, {double? downstreamHead, bool detailed = true}) {
    final valve = project.byId(valveId) as ControlValveEntity?;
    final warnings = <String>[];
    if (valve == null || !model.valveNodes.containsKey(valveId)) {
      return _emptyZone(valveId, valve?.zoneName ?? '', ['valve_missing']);
    }
    final (mainNode, zoneNode) = model.valveNodes[valveId]!;
    final zn = model.nodes[zoneNode]!;
    final nodeIds = model.zoneNodes[valveId] ?? {};
    if (nodeIds.length <= 1 || (model.zoneLinks[valveId]?.isEmpty ?? true)) {
      return _emptyZone(valveId, valve.zoneName, ['zone_empty']);
    }
    var head = downstreamHead ?? valve.fixedDownstreamHeadM;
    NetworkResult r;
    if (head != null) {
      r = _zoneNetwork(valveId, head, detailed).solve();
    } else if (!detailed) {
      final h0 = 10.0;
      r = _zoneNetwork(valveId, h0, false).solve();
      final (pm, pn) = _meanPressures(valveId, r);
      head = h0 + (pn - pm);
      r = _zoneNetwork(valveId, head, false).solve();
    } else {
      // bisection so that mean emitter pressure equals nominal mean
      final probe = _zoneNetwork(valveId, 10, false).solve();
      final (_, pn) = _meanPressures(valveId, probe);
      var lo = 0.0, hi = math.max(pn * 3, 5.0);
      r = _zoneNetwork(valveId, hi, true).solve();
      var it = 0;
      while (_meanPressures(valveId, r).$1 < pn && it < 20) {
        hi *= 2;
        r = _zoneNetwork(valveId, hi, true).solve();
        it++;
      }
      for (var i = 0; i < 28; i++) {
        final mid = (lo + hi) / 2;
        r = _zoneNetwork(valveId, mid, true).solve();
        if (_meanPressures(valveId, r).$1 > pn) {
          hi = mid;
        } else {
          lo = mid;
        }
        if (hi - lo < 1e-3) break;
      }
      head = (lo + hi) / 2;
      r = _zoneNetwork(valveId, head, true).solve();
    }
    if (!r.converged) warnings.add('not_converged');

    // If the spread of pressures fits inside the allowable window but the
    // mean-targeted head leaves some outlets outside, centre the band.
    if (downstreamHead == null && valve.fixedDownstreamHeadM == null) {
      final (mn, mx, aMin, aMax) = _pressureSpread(valveId, r);
      if (mx - mn <= aMax - aMin + 1e-9 && (mn < aMin - 1e-6 || mx > aMax + 1e-6)) {
        final shift = (aMin + aMax) / 2 - (mn + mx) / 2;
        head = head + shift;
        r = _zoneNetwork(valveId, head, detailed).solve();
      }
    }

    // outlets
    final outlets = <OutletResult>[];
    final flows = <double>[];
    var totalFlow = 0.0;
    var minP = double.infinity, maxP = -double.infinity, allowMin = -double.infinity, allowMax = double.infinity, nominalSum = 0.0, nominalW = 0.0, cvSum = 0.0;
    var emitterCount = 0;
    for (final id in nodeIds) {
      final n = model.nodes[id]!;
      final nr = r.nodes[id];
      if (nr == null) continue;
      for (final e in n.emitters) {
        final p = nr.head - (n.elevation + e.offset);
        final q = detailed ? e.curve.flow(math.max(p, 0)) : e.curve.flow(e.nominalHead);
        totalFlow += q * e.count;
        if (e.index == -2) continue;
        outlets.add(OutletResult(entityId: e.entityId, index: e.index, p: n.p, elevation: n.elevation + e.offset, pressure: p, flow: q, nominalFlow: e.curve.flow(e.nominalHead), count: e.count, allowedMin: e.allowedMin, allowedMax: e.allowedMax, label: e.label));
        for (var k = 0; k < e.count; k++) {
          flows.add(e.curve.flow(math.max(p, 0)));
        }
        emitterCount += e.count;
        minP = math.min(minP, p);
        maxP = math.max(maxP, p);
        allowMin = math.max(allowMin, e.allowedMin);
        allowMax = math.min(allowMax, e.allowedMax);
        nominalSum += e.nominalHead * e.count;
        nominalW += e.count;
        cvSum += e.cv * e.count;
      }
    }
    if (outlets.isEmpty) {
      minP = maxP = 0;
      allowMin = 0;
      allowMax = 0;
    }
    final nominal = nominalW > 0 ? nominalSum / nominalW : 0.0;
    if (params.maxZoneVariationPct > 0 && nominal > 0) {
      allowMin = math.max(allowMin, nominal * (1 - params.maxZoneVariationPct / 200));
      allowMax = math.min(allowMax, nominal * (1 + params.maxZoneVariationPct / 200));
    }
    final cv = nominalW > 0 ? cvSum / nominalW : 0.0;
    final epp = _emittersPerPlantFor(outlets);
    final uni = UniformityStats.compute(flows, manufacturerCv: cv, emittersPerPlant: epp);

    // pipes and devices
    final pipes = <PipeSegmentResult>[];
    final devices = <DeviceResult>[];
    for (final lid in model.zoneLinks[valveId] ?? <String>{}) {
      final l = model.linkById(lid)!;
      final lr = r.links[lid];
      if (lr == null) continue;
      final na = model.nodes[l.from]!, nb = model.nodes[l.to]!;
      final ha = r.nodes[l.from]!.head, hb = r.nodes[l.to]!.head;
      if (l.kind == GLinkKind.pipe) {
        final spec = _specOf(l);
        final tape = catalog.tape(l.tapeSpecId);
        final d = _diameter(l);
        final v = velocity(flow: lr.flow.abs(), diameter: d);
        pipes.add(PipeSegmentResult(linkId: lid, entityId: l.entityId, segmentIndex: l.segmentIndex, a: l.a, b: l.b, elevationA: na.elevation, elevationB: nb.elevation, length: l.length, diameter: d, pipeSpecId: tape?.id ?? spec?.id, pipeName: tape?.name ?? spec?.name ?? '?', flow: lr.flow, velocity: v, headLoss: lr.headLoss, pressureStart: ha - na.elevation, pressureEnd: hb - nb.elevation, pressureRating: tape?.pressureRatingM ?? spec?.pressureRatingM ?? 0, zoneId: valveId, overVelocity: v > _vmax(l) + 1e-6));
        if (v > _vmax(l) + 1e-6) warnings.add('velocity_exceeded:${l.entityId}');
        if ((tape?.pressureRatingM ?? spec?.pressureRatingM ?? 0) > 0 && math.max(ha - na.elevation, hb - nb.elevation) > (tape?.pressureRatingM ?? spec!.pressureRatingM)) warnings.add('pressure_rating_exceeded:${l.entityId}');
      } else {
        devices.add(DeviceResult(entityId: l.entityId, linkId: lid, flow: lr.flow, headLoss: lr.headLoss, pumpHead: lr.pumpHead, upstreamPressure: ha - na.elevation, downstreamPressure: hb - nb.elevation, status: lr.status.name, elevation: na.elevation));
        if (_suctionLiftExceeded(l, lr, ha - na.elevation, na.elevation)) warnings.add('pump_suction_lift:${l.entityId}');
      }
    }
    for (final o in outlets) {
      if (!(o.pressure >= allowMin - 1e-6 && o.pressure <= allowMax + 1e-6)) {
        warnings.add(o.pressure < allowMin ? 'outlet_under_pressure:${o.entityId}' : 'outlet_over_pressure:${o.entityId}');
        break;
      }
    }
    final valveSpec = catalog.valve(valve.valveSpecId);
    final valveLoss = valveSpec?.loss.loss(totalFlow) ?? 0;
    if (valveSpec != null && (totalFlow > valveSpec.maxFlow + 1e-9 || totalFlow < valveSpec.minFlow - 1e-9)) warnings.add('valve_flow_out_of_range');
    var pipeCost = 0.0;
    for (final lid in model.zoneLinks[valveId] ?? <String>{}) {
      final l = model.linkById(lid)!;
      if (l.kind != GLinkKind.pipe) continue;
      final tape = catalog.tape(l.tapeSpecId);
      pipeCost += (tape?.costPerM ?? _specOf(l)?.costPerM ?? 0) * l.length;
    }
    final energy = annualEnergyCost(flow: totalFlow, head: head + valveLoss, hoursPerYear: params.zoneHoursPerYear, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency);
    final mn = model.nodes[mainNode]!;
    return ZoneResult(
      valveId: valveId,
      zoneName: valve.zoneName,
      converged: r.converged,
      totalFlow: totalFlow,
      downstreamHead: head,
      valveLoss: valveLoss,
      requiredUpstreamHead: head + valveLoss + (zn.elevation - mn.elevation),
      minOutletPressure: minP,
      maxOutletPressure: maxP,
      allowedMin: allowMin,
      allowedMax: allowMax,
      nominalPressure: nominal,
      uniformity: uni,
      pipes: pipes,
      outlets: outlets,
      devices: devices,
      warnings: warnings.toSet().toList(),
      valveElevation: mn.elevation,
      valveSpecName: valveSpec?.name ?? '',
      emitterCount: emitterCount,
      pipeCost: pipeCost,
      annualEnergyCost: energy,
      overlapCu: detailed ? _overlapCu(valveId, outlets) : 0,
      emittersPerPlant: epp,
    );
  }

  /// Emitters per plant for the EU: from an irrigated area containing most
  /// of the zone's outlets, else the project default.
  int _emittersPerPlantFor(List<OutletResult> outlets) {
    if (outlets.isEmpty) return math.max(1, params.emittersPerPlant);
    for (final a in project.entities.whereType<AreaEntity>()) {
      if (a.emittersPerPlant <= 0 || a.points.length < 3) continue;
      var inside = 0;
      for (final o in outlets) {
        if (pointInPolygon(o.p, a.points)) inside++;
      }
      if (inside * 2 >= outlets.length) return a.emittersPerPlant;
    }
    return math.max(1, params.emittersPerPlant);
  }

  /// Christiansen CU of the overlapped sprinkler pattern of a zone (0 when
  /// the zone has no wetted-radius emitters).
  double _overlapCu(String valveId, List<OutletResult> outlets) {
    if (outlets.isEmpty) return 0;
    final ids = outlets.map((o) => o.entityId).toSet();
    final spraylines = <SpraylineEntity>[];
    final points = <OutletEntity>[];
    for (final id in ids) {
      final e = project.byId(id);
      if (e is SpraylineEntity) spraylines.add(e);
      if (e is OutletEntity) points.add(e);
    }
    double meanP = 0;
    var w = 0;
    for (final o in outlets) {
      meanP += o.pressure * o.count;
      w += o.count;
    }
    meanP = w > 0 ? meanP / w : 0;
    if (spraylines.isNotEmpty) {
      final s = spraylines.first;
      final nz = catalog.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
      final radius = nz?.curve.radius(meanP) ?? 0;
      if (radius <= 0) return 0;
      final between = <double>[];
      for (final a in spraylines) {
        if (a.points.length < 2) continue;
        final mid = pointAlongPolyline(a.points, a.length / 2);
        var best = double.infinity;
        for (final b in spraylines) {
          if (identical(a, b)) continue;
          best = math.min(best, b.distanceTo(mid));
        }
        if (best.isFinite) between.add(best);
      }
      if (between.isEmpty) return 0;
      between.sort();
      final sb = between[between.length ~/ 2];
      return gridOverlapCU(radius: radius, spacingAlong: s.spacing, spacingBetween: sb);
    }
    if (points.length >= 4) {
      final o = points.first;
      final nz = catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
      final radius = nz?.curve.radius(meanP) ?? 0;
      if (radius <= 0) return 0;
      final nn = <double>[];
      final sample = points.length > 400 ? points.sublist(0, 400) : points;
      for (final a in sample) {
        var best = double.infinity;
        for (final b in sample) {
          if (identical(a, b)) continue;
          best = math.min(best, a.position.distanceTo(b.position));
        }
        if (best.isFinite) nn.add(best);
      }
      if (nn.isEmpty) return 0;
      nn.sort();
      final s = nn[nn.length ~/ 2];
      return gridOverlapCU(radius: radius, spacingAlong: s, spacingBetween: s);
    }
    return 0;
  }

  /// (min pressure, max pressure, allowed min, allowed max) over zone emitters.
  (double, double, double, double) _pressureSpread(String valveId, NetworkResult r) {
    var mn = double.infinity, mx = -double.infinity, aMin = -double.infinity, aMax = double.infinity;
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      final nr = r.nodes[id];
      if (nr == null) continue;
      for (final e in n.emitters) {
        if (e.index == -2) continue;
        final p = nr.head - (n.elevation + e.offset);
        mn = math.min(mn, p);
        mx = math.max(mx, p);
        aMin = math.max(aMin, e.allowedMin);
        aMax = math.min(aMax, e.allowedMax);
      }
    }
    if (!mn.isFinite) return (0, 0, 0, 0);
    return (mn, mx, aMin, aMax);
  }

  ZoneResult _emptyZone(String valveId, String name, List<String> warnings) => ZoneResult(
    valveId: valveId, zoneName: name, converged: false, totalFlow: 0, downstreamHead: 0, valveLoss: 0, requiredUpstreamHead: 0,
    minOutletPressure: 0, maxOutletPressure: 0, allowedMin: 0, allowedMax: 0, nominalPressure: 0, uniformity: UniformityStats.empty,
    pipes: const [], outlets: const [], devices: const [], warnings: warnings, valveElevation: 0,
  );

  /// Sizable units (entities with computer-sized pipes) among the given links.
  Map<String, List<GLink>> _units(Iterable<String> linkIds) {
    final m = <String, List<GLink>>{};
    for (final lid in linkIds) {
      final l = model.linkById(lid)!;
      if (l.kind != GLinkKind.pipe || !l.computerSized || l.tapeSpecId != null) continue;
      if (_candidates(l).isEmpty) continue;
      m.putIfAbsent(l.entityId, () => []).add(l);
    }
    return m;
  }

  void _assign(String entityId, PipeSpec spec) {
    _assigned[entityId] = spec.id;
  }

  double _crf() => capitalRecoveryFactor(params.interestRate, params.termYears);

  /// Loss reduction (m) if [unit] is upsized to [next], given segment losses.
  double _lossReduction(List<GLink> unit, PipeSpec next, Map<String, double> lossByLink, Set<GLink> onPath) {
    var s = 0.0;
    for (final l in unit) {
      if (!onPath.contains(l)) continue;
      final d = _diameter(l);
      final loss = lossByLink[l.id] ?? 0;
      s += loss.abs() * (1 - math.pow(d / next.innerDiameter, _hwExp));
    }
    return s;
  }

  double _unitLength(List<GLink> unit) => unit.fold(0.0, (s, l) => s + l.length);

  /// Candidate pipes of a unit that respect the velocity limit at [qmax]
  /// (the largest one when none does).
  List<PipeSpec> _velocityCandidates(GLink l, double qmax) {
    final cands = _candidates(l);
    final ok = cands.where((c) => velocity(flow: qmax, diameter: c.innerDiameter) <= _vmax(l) + 1e-9).toList();
    return ok.isEmpty ? [cands.last] : ok;
  }

  int _maxSizesFor(GLink l) => switch (l.usage) {
    PipeUsage.lateral => math.max(1, params.maxLateralSizes),
    PipeUsage.zone => math.max(1, params.maxSubmainSizes),
    PipeUsage.mainline => math.max(1, params.maxMainlineSizes),
  };

  /// Records an LP assignment: the largest diameter is used for interim
  /// analyses and multi-diameter units are split before the final analysis.
  void _applyAssignment(LpAssignment a) {
    a.fractions.forEach((unit, list) {
      _assign(unit, list.first.$1);
      if (list.length > 1) {
        _pendingSplits[unit] = list;
      } else {
        _pendingSplits.remove(unit);
      }
    });
  }

  /// Velocity sizing of the units of a zone (initial assignment).
  List<String> _velocitySizeZone(String valveId, Map<String, List<GLink>> units) {
    final warnings = <String>[];
    for (final e in units.entries) {
      _assign(e.key, _candidates(e.value.first).first);
    }
    for (var pass = 0; pass < 4; pass++) {
      final r = _zoneNetwork(valveId, 10, false).solve();
      var changed = false;
      for (final e in units.entries) {
        var qmax = 0.0;
        for (final l in e.value) {
          qmax = math.max(qmax, (r.links[l.id]?.flow ?? 0).abs());
        }
        final pick = _velocityCandidates(e.value.first, qmax).first;
        if (velocity(flow: qmax, diameter: pick.innerDiameter) > _vmax(e.value.first) + 1e-6) warnings.add('velocity_exceeded:${e.key}');
        if (_assigned[e.key] != pick.id) {
          _assign(e.key, pick);
          changed = true;
        }
      }
      if (!changed) break;
    }
    return warnings;
  }

  /// Greedy upsizing along the critical path until the window is met.
  ZoneResult _repairZone(String valveId, Map<String, List<GLink>> units, List<String> warnings, ZoneResult res) {
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    for (var it = 0; it < 400 && !res.withinWindow; it++) {
      final target = res.minOutlet;
      if (target == null) break;
      final targetNode = _nodeOfOutlet(valveId, target);
      if (targetNode == null) break;
      final path = _path(zoneNode, targetNode, linkIds).toSet();
      final lossByLink = {for (final p in res.pipes) p.linkId: p.headLoss};
      String? bestUnit;
      PipeSpec? bestSpec;
      var bestScore = 0.0;
      for (final e in units.entries) {
        if (!e.value.any(path.contains)) continue;
        final cur = _specOf(e.value.first)!;
        final next = _next(cur, _candidates(e.value.first));
        if (next == null) continue;
        final red = _lossReduction(e.value, next, lossByLink, path);
        final cost = (next.costPerM - cur.costPerM) * _unitLength(e.value);
        final score = red / (math.max(cost, 1e-6));
        if (score > bestScore) {
          bestScore = score;
          bestUnit = e.key;
          bestSpec = next;
        }
      }
      if (bestUnit == null) {
        warnings.add('cannot_meet_pressure_window');
        break;
      }
      _assign(bestUnit, bestSpec!);
      _pendingSplits.remove(bestUnit);
      res = analyzeZone(valveId, detailed: false);
    }
    return res;
  }

  /// Critical emitter nodes of a zone for the LP: per lateral its end, its
  /// highest and its lowest node; every single outlet (capped).
  Set<String> _criticalNodes(String valveId, Map<String, int> depth) {
    final byEntity = <String, List<String>>{};
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      for (final e in n.emitters) {
        if (e.index == -2) continue;
        byEntity.putIfAbsent(e.entityId, () => []).add(id);
      }
    }
    final out = <String>{};
    for (final list in byEntity.values) {
      if (list.length == 1) {
        out.add(list.first);
        continue;
      }
      String? end, high, low;
      var dEnd = -1, zHigh = -double.infinity, zLow = double.infinity;
      for (final id in list) {
        final n = model.nodes[id]!;
        final d = depth[id] ?? 0;
        if (d > dEnd) {
          dEnd = d;
          end = id;
        }
        final z = n.elevation;
        if (z > zHigh) {
          zHigh = z;
          high = id;
        }
        if (z < zLow) {
          zLow = z;
          low = id;
        }
      }
      out.addAll([?end, ?high, ?low]);
    }
    if (out.length > 1500) {
      final list = out.toList();
      return list.take(1500).toSet();
    }
    return out;
  }

  /// Builds and solves the zone LP with the current assignment for flows.
  LpAssignment _lpZone(String valveId, Map<String, List<GLink>> units, {Set<String> extraNodes = const {}}) {
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final r = _zoneNetwork(valveId, 10, false).solve();
    double q(GLink l) => (r.links[l.id]?.flow ?? 0).abs();
    final (parent, _, depth) = _bfs([zoneNode], linkIds);
    final unitOf = <String, String>{for (final e in units.entries) for (final l in e.value) l.id: e.key};
    final cands = <String, List<PipeSpec>>{};
    final lengths = <String, double>{};
    final maxSizes = <String, int>{};
    for (final e in units.entries) {
      var qmax = 0.0;
      for (final l in e.value) {
        qmax = math.max(qmax, q(l));
      }
      cands[e.key] = _velocityCandidates(e.value.first, qmax);
      lengths[e.key] = _unitLength(e.value);
      maxSizes[e.key] = _maxSizesFor(e.value.first);
    }
    var total = 0.0;
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      for (final e in model.nodes[id]!.emitters) {
        total += e.nominalFlow;
      }
    }
    final energy = params.tradeCapitalVsRunning ? annualEnergyCost(flow: total, head: 1, hoursPerYear: params.zoneHoursPerYear, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency) : 0.0;
    final zRoot = model.nodes[zoneNode]!.elevation;
    final nodes = {..._criticalNodes(valveId, depth), ...extraNodes};
    final constraints = <LpHeadConstraint>[];
    for (final k in nodes) {
      final n = model.nodes[k];
      if (n == null || !parent.containsKey(k)) continue;
      var lo = -double.infinity, hi = double.infinity, off = 0.0, nomSum = 0.0, nomW = 0.0;
      for (final e in n.emitters) {
        if (e.index == -2) continue;
        lo = math.max(lo, e.allowedMin);
        hi = math.min(hi, e.allowedMax);
        off = math.max(off, e.offset);
        nomSum += e.nominalHead * e.count;
        nomW += e.count;
      }
      if (!lo.isFinite && !hi.isFinite) continue;
      if (params.maxZoneVariationPct > 0 && nomW > 0) {
        final nominal = nomSum / nomW;
        lo = math.max(lo, nominal * (1 - params.maxZoneVariationPct / 200));
        hi = math.min(hi, nominal * (1 + params.maxZoneVariationPct / 200));
      }
      final byUnit = <String, Map<String, double>>{};
      var constant = 0.0;
      for (final l in _pathFromParents(parent, k)) {
        final u = unitOf[l.id];
        if (u != null) {
          final m = byUnit.putIfAbsent(u, () => {});
          for (final s in cands[u]!) {
            m[s.id] = (m[s.id] ?? 0) + _linkLoss(l, s, q(l));
          }
        } else if (l.kind == GLinkKind.pipe) {
          constant += _currentLoss(l, q(l));
        } else {
          constant += r.links[l.id]?.headLoss ?? 0;
        }
      }
      final dz = n.elevation + off - zRoot;
      constraints.add(LpHeadConstraint(headVar: 0, lossByUnitSpec: byUnit, constant: constant, minPressure: lo.isFinite ? lo + dz : null, maxPressure: hi.isFinite ? hi + dz : null, tag: k));
    }
    return lpSize(LpSizingInput(units: units.keys.toList(), candidates: cands, unitLength: lengths, maxSizes: maxSizes, headVars: [LpHeadVar(energyPerMetre: energy, name: 'zone')], constraints: constraints, crf: _crf(), tradeCapital: params.tradeCapitalVsRunning));
  }

  ZoneResult sizeZone(String valveId) {
    final valve = project.byId(valveId) as ControlValveEntity?;
    if (valve == null || !model.valveNodes.containsKey(valveId)) return analyzeZone(valveId);
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final units = _units(linkIds);
    if (units.isEmpty) return analyzeZone(valveId);
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final warnings = <String>[];

    // 1. velocity sizing (also provides the nominal flows for the LP)
    warnings.addAll(_velocitySizeZone(valveId, units));

    ZoneResult res;
    var lpDone = false;
    if (params.sizingMethod == SizingMethod.lp) {
      var a = _lpZone(valveId, units);
      if (a.feasible) {
        _applyAssignment(a);
        res = analyzeZone(valveId, detailed: false);
        var extra = <String>{};
        for (var round = 0; round < 4 && !res.withinWindow; round++) {
          final add = <String>{};
          for (final o in [?res.minOutlet, ?res.maxOutlet]) {
            final node = _nodeOfOutlet(valveId, o);
            if (node != null) add.add(node);
          }
          if (add.every(extra.contains)) break;
          extra = {...extra, ...add};
          a = _lpZone(valveId, units, extraNodes: extra);
          if (!a.feasible) break;
          _applyAssignment(a);
          res = analyzeZone(valveId, detailed: false);
        }
        lpDone = true;
      } else {
        results.messages.add('lp_infeasible:${valve.zoneName}');
        res = analyzeZone(valveId, detailed: false);
      }
    } else {
      res = analyzeZone(valveId, detailed: false);
    }

    // 2. pressure-window repair (greedy upsizing along the critical path)
    res = _repairZone(valveId, units, warnings, res);

    // 3. economic trade-off: capital vs running cost (greedy method only;
    //    the LP objective already includes energy)
    if (!lpDone && params.tradeCapitalVsRunning) {
      final crf = _crf();
      for (var it = 0; it < 200; it++) {
        final target = res.minOutlet;
        if (target == null) break;
        final targetNode = _nodeOfOutlet(valveId, target);
        if (targetNode == null) break;
        final path = _path(zoneNode, targetNode, linkIds).toSet();
        final lossByLink = {for (final p in res.pipes) p.linkId: p.headLoss};
        String? bestUnit;
        PipeSpec? bestSpec;
        var bestGain = 0.0;
        for (final e in units.entries) {
          if (!e.value.any(path.contains)) continue;
          final cur = _specOf(e.value.first)!;
          final next = _next(cur, _candidates(e.value.first));
          if (next == null) continue;
          final red = _lossReduction(e.value, next, lossByLink, path);
          final saving = annualEnergyCost(flow: res.totalFlow, head: red, hoursPerYear: params.zoneHoursPerYear, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency);
          final capital = (next.costPerM - cur.costPerM) * _unitLength(e.value) * crf;
          final gain = saving - capital;
          if (gain > bestGain) {
            bestGain = gain;
            bestUnit = e.key;
            bestSpec = next;
          }
        }
        if (bestUnit == null) break;
        _assign(bestUnit, bestSpec!);
        res = analyzeZone(valveId, detailed: false);
      }
    }

    // 4. rationalize: downstream never larger than upstream (tree order from valve)
    _rationalize(zoneNode, linkIds, units);

    // 5. write back and final detailed analysis
    _writeBack(units);
    final finalRes = analyzeZone(valveId, detailed: true);
    return finalRes.copyWith(warnings: {...warnings, ...finalRes.warnings}.toList());
  }

  String? _nodeOfOutlet(String valveId, OutletResult o) {
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      for (final e in n.emitters) {
        if (e.entityId == o.entityId && e.index == o.index) return id;
      }
    }
    return null;
  }

  void _rationalize(String root, Set<String> linkIds, Map<String, List<GLink>> units) {
    final unitOf = <String, String>{};
    for (final e in units.entries) {
      for (final l in e.value) {
        unitOf[l.id] = e.key;
      }
    }
    // BFS from root tracking parent link
    final parent = <String, GLink?>{root: null};
    final queue = [root];
    var head = 0;
    final order = <GLink>[];
    while (head < queue.length) {
      final id = queue[head++];
      for (final l in model.nodes[id]!.links) {
        if (!linkIds.contains(l.id)) continue;
        final o = l.other(id);
        if (!parent.containsKey(o)) {
          parent[o] = l;
          order.add(l);
          queue.add(o);
        }
      }
    }
    // walk from leaves upward: child size must be <= parent size
    for (var pass = 0; pass < 5; pass++) {
      var changed = false;
      for (final l in order.reversed) {
        final u = unitOf[l.id];
        if (u == null) continue;
        final upNode = parent.entries.firstWhere((e) => e.value == l).key;
        final upFrom = l.other(upNode);
        final pl = parent[upFrom];
        if (pl == null) continue;
        final pu = unitOf[pl.id];
        if (pu == null || pu == u) continue;
        final child = _specOf(l)!, par = _specOf(pl)!;
        if (child.innerDiameterMm > par.innerDiameterMm + 1e-9) {
          // upsize parent to at least child size
          final cands = _candidates(pl);
          for (final c in cands) {
            if (c.innerDiameterMm >= child.innerDiameterMm - 1e-9) {
              _assign(pu, c);
              _pendingSplits.remove(pu);
              changed = true;
              break;
            }
          }
        }
      }
      if (!changed) break;
    }
  }

  void _writeBack(Map<String, List<GLink>> units) {
    for (final e in units.entries) {
      final spec = _assigned[e.key];
      if (spec == null) continue;
      final ent = project.byId(e.key);
      if (ent is PipeEntity) ent.pipeSpecId = spec;
      if (ent is SpraylineEntity) ent.pipeSpecId = spec;
      for (final l in e.value) {
        l.pipeSpecId = spec;
      }
    }
  }

  // ------------------------------------------------------------ telescoping

  /// Splits telescoped units into one entity per diameter (largest
  /// upstream), then rebuilds the network model. Returns the number of
  /// entities that were split.
  int _applySplits() {
    if (_pendingSplits.isEmpty) return 0;
    var count = 0;
    final zoneRoots = {for (final v in model.valveNodes.values) v.$2};
    final mainRoots = model.supplyNodes.values.toSet();
    final zoneDepth = _bfs(zoneRoots, {for (final s in model.zoneLinks.values) ...s}).$3;
    final mainDepth = _bfs(mainRoots, model.mainlineLinks).$3;
    for (final entry in _pendingSplits.entries) {
      final e = project.byId(entry.key);
      if (e == null || !e.isLinearHydraulic) continue;
      final links = model.links.where((l) => l.entityId == e.id && l.kind == GLinkKind.pipe).toList()..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
      if (links.isEmpty) continue;
      final depth = links.first.scope == HydraulicScope.mainline ? mainDepth : zoneDepth;
      // chain of nodes along the entity must have monotonic depth
      final chain = <String>[links.first.from, for (final l in links) l.to];
      final ds = chain.map((n) => depth[n]).toList();
      if (ds.any((d) => d == null)) continue;
      var increasing = true, decreasing = true;
      for (var i = 1; i < ds.length; i++) {
        if (ds[i]! < ds[i - 1]!) increasing = false;
        if (ds[i]! > ds[i - 1]!) decreasing = false;
      }
      if (increasing == decreasing) continue; // fed in the middle or flat
      final fractions = entry.value;
      final total = (e as PolyEntity).length;
      // pieces from the start: descending diameters when the start is upstream
      final ordered = increasing ? fractions : fractions.reversed.toList();
      final stations = <double>[];
      var acc = 0.0;
      for (var i = 0; i < ordered.length - 1; i++) {
        acc += ordered[i].$2 * total;
        stations.add(acc);
      }
      final pieces = splitLinearEntity(e, stations, () => project.newId());
      if (pieces.length < 2) continue;
      final idx = project.entities.indexOf(e);
      project.entities.removeAt(idx);
      for (var i = 0; i < pieces.length; i++) {
        final p = pieces[i];
        final spec = ordered[math.min(i, ordered.length - 1)].$1;
        if (p is PipeEntity) p.pipeSpecId = spec.id;
        if (p is SpraylineEntity) p.pipeSpecId = spec.id;
        project.entities.insert(idx + i, p);
      }
      count++;
    }
    _pendingSplits.clear();
    _assigned.clear();
    model = NetworkBuilder(project).build();
    return count;
  }

  // ------------------------------------------------------------ mainline

  HydraulicNetwork _mainlineNetwork(Map<String, double> supplyPressure, Map<String, double> valveDemand) {
    final net = HydraulicNetwork(options: _options);
    for (final id in model.mainlineNodes) {
      final n = model.nodes[id]!;
      if (n.isSupply) {
        final s = project.byId(n.supplyEntityId!) as WaterSupplyEntity;
        final p = supplyPressure[s.id] ?? 0;
        // the supply node lies at the water level (NetworkBuilder)
        net.addNode(HNode(id: id, kind: HNodeKind.reservoir, elevation: n.elevation, fixedHead: n.elevation + p));
        continue;
      }
      final h = HNode(id: id, elevation: n.elevation);
      net.addNode(h);
      // mainline outlets (VIH) as emitters
      _attachEmitters(net, h, n, true);
    }
    for (final e in model.valveNodes.entries) {
      final (nm, _) = e.value;
      final hn = net.nodes[nm];
      if (hn == null) continue;
      hn.demand += valveDemand[e.key] ?? 0;
    }
    for (final e in model.pivotNodes.entries) {
      final hn = net.nodes[e.value];
      if (hn == null) continue;
      hn.demand += valveDemand[e.key] ?? 0;
    }
    for (final lid in model.mainlineLinks) {
      net.addLink(_toHLink(model.linkById(lid)!));
    }
    return net;
  }

  List<WaterSupplyEntity> get _supplies => project.entities.whereType<WaterSupplyEntity>().where((s) => model.supplyNodes.containsKey(s.id) && model.mainlineNodes.contains(model.supplyNodes[s.id])).toList();

  /// A running surface pump whose inlet pressure is below minus the
  /// practical suction lift (atmospheric head − vapour pressure − NPSH
  /// allowance): it would cavitate or lose its prime.
  bool _suctionLiftExceeded(GLink l, LinkResult lr, double inletPressure, double elevation) {
    if (l.kind != GLinkKind.pump || lr.flow <= 0) return false;
    final spec = catalog.pump(l.pumpSpecId);
    if (spec == null || spec.submersible) return false;
    return -inletPressure > maxSuctionLift(elevation) + 1e-6;
  }

  SystemFlowResult analyzeSystemFlow(SystemFlow sf, {double totalDuration = 0}) {
    final warnings = <String>[];
    final supplies = _supplies;
    if (supplies.isEmpty) {
      return SystemFlowResult(flowId: sf.id, name: sf.name, converged: false, supplies: const [], valves: const [], pipes: const [], devices: const [], warnings: const ['no_water_supply'], totalFlow: 0, durationHours: sf.durationHours);
    }
    final demand = <String, double>{};
    final required = <String, double>{};
    for (final vid in sf.valveIds) {
      if (_demandNode(vid) == null) continue;
      final (q, h) = _demandOf(vid);
      demand[vid] = q;
      required[vid] = h;
    }
    final pressure = <String, double>{for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM};
    var r = _mainlineNetwork(pressure, demand).solve();
    final calc = supplies.where((s) => s.calculatePressure).toList();
    double deficit(NetworkResult r) {
      var d = -double.infinity;
      for (final vid in demand.keys) {
        final nr = r.nodes[_demandNode(vid) ?? ''];
        if (nr == null) continue;
        d = math.max(d, required[vid]! - nr.pressure);
      }
      return d.isFinite ? d : 0;
    }

    // Required pressure of the calculated supplies: the deficit of the worst
    // valve with the supply at zero pressure, i.e. after the head the pumps of
    // the flow add at their operating flow. A negative deficit is a surplus
    // (the pumps or the elevation already cover the need): a supply cannot
    // absorb head, so the analysis then keeps it at zero and the surplus shows
    // as extra pressure along the mainline and at the valves
    // (SupplyDuty.surplusHead); requiredHead keeps the signed value so the
    // pump duty (required head plus the head the pumps add) stays right.
    var requiredExtra = 0.0;
    if (calc.isNotEmpty) {
      requiredExtra = deficit(r);
      if (requiredExtra > 0) {
        for (final s in calc) {
          pressure[s.id] = requiredExtra;
        }
        r = _mainlineNetwork(pressure, demand).solve();
      }
    }
    if (!r.converged) warnings.add('not_converged');

    final valves = <ValveDuty>[];
    for (final vid in demand.keys) {
      final nm = _demandNode(vid) ?? '';
      final nr = r.nodes[nm];
      final pivot = results.pivots[vid];
      final zoneName = pivot?.name ?? results.zones[vid]?.zoneName ?? vid;
      if (nr == null) {
        warnings.add('valve_unreachable:$vid');
        continue;
      }
      valves.add(ValveDuty(valveId: vid, zoneName: zoneName, flow: demand[vid]!, availableHead: nr.pressure, requiredHead: required[vid]!, p: model.nodes[nm]!.p));
      if (pivot != null) pivot.availableHead = nr.pressure;
      if (nr.pressure < required[vid]! - 0.01) warnings.add(pivot != null ? 'pivot_pressure_deficit:$vid' : 'valve_pressure_deficit:$vid');
    }
    final duties = <SupplyDuty>[];
    var total = 0.0;
    for (final s in supplies) {
      final nid = model.supplyNodes[s.id]!;
      var q = 0.0;
      for (final l in model.nodes[nid]!.links) {
        final lr = r.links[l.id];
        if (lr == null) continue;
        q += l.from == nid ? lr.flow : -lr.flow;
      }
      total += q;
      final avail = pressure[s.id]!;
      final req = s.calculatePressure ? requiredExtra : (s.designHeadM + deficit(r));
      duties.add(SupplyDuty(supplyId: s.id, name: s.name.isEmpty ? _label('name.supply') : s.name, flow: q, head: avail, requiredHead: req, elevation: model.nodes[nid]!.elevation, calculated: s.calculatePressure, designHead: s.designHeadM, maxHead: s.maxHeadM, designFlow: s.designFlow, maxFlow: s.maxFlow));
      if (s.designFlow > 0 && q > s.designFlow + 1e-9) warnings.add('supply_flow_exceeded:${s.id}');
      if (s.maxHeadM > 0 && req > s.maxHeadM + 1e-6) warnings.add('supply_head_exceeded:${s.id}');
    }
    final pipes = <PipeSegmentResult>[];
    final devices = <DeviceResult>[];
    for (final lid in model.mainlineLinks) {
      final l = model.linkById(lid)!;
      final lr = r.links[lid];
      if (lr == null) continue;
      final na = model.nodes[l.from]!, nb = model.nodes[l.to]!;
      final ha = r.nodes[l.from]!.head, hb = r.nodes[l.to]!.head;
      if (l.kind == GLinkKind.pipe) {
        final spec = _specOf(l);
        final d = _diameter(l);
        final v = velocity(flow: lr.flow.abs(), diameter: d);
        pipes.add(PipeSegmentResult(linkId: lid, entityId: l.entityId, segmentIndex: l.segmentIndex, a: l.a, b: l.b, elevationA: na.elevation, elevationB: nb.elevation, length: l.length, diameter: d, pipeSpecId: spec?.id, pipeName: spec?.name ?? '?', flow: lr.flow, velocity: v, headLoss: lr.headLoss, pressureStart: ha - na.elevation, pressureEnd: hb - nb.elevation, pressureRating: spec?.pressureRatingM ?? 0, overVelocity: v > _vmax(l) + 1e-6));
        if (v > _vmax(l) + 1e-6) warnings.add('velocity_exceeded:${l.entityId}');
        if ((spec?.pressureRatingM ?? 0) > 0 && math.max(ha - na.elevation, hb - nb.elevation) > spec!.pressureRatingM) warnings.add('pressure_rating_exceeded:${l.entityId}');
      } else {
        devices.add(DeviceResult(entityId: l.entityId, linkId: lid, flow: lr.flow, headLoss: lr.headLoss, pumpHead: lr.pumpHead, upstreamPressure: ha - na.elevation, downstreamPressure: hb - nb.elevation, status: lr.status.name, elevation: na.elevation));
        if (l.kind == GLinkKind.pump) {
          final spec = catalog.pump(l.pumpSpecId);
          if (spec != null && (lr.flow > spec.maxFlow + 1e-9 || lr.flow <= 0)) warnings.add('pump_out_of_range:${l.entityId}');
          if (_suctionLiftExceeded(l, lr, ha - na.elevation, na.elevation)) warnings.add('pump_suction_lift:${l.entityId}');
        }
      }
    }
    // energy: supplies with calculated pressure and pumps
    final share = totalDuration > 0 ? sf.durationHours / totalDuration : 1.0;
    final hours = params.hoursPerYear * share;
    var energy = 0.0;
    for (final d in duties) {
      if (d.calculated && d.requiredHead > 0) energy += annualEnergyCost(flow: d.flow, head: d.requiredHead, hoursPerYear: hours, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency);
    }
    for (final d in devices) {
      if (d.pumpHead > 0) {
        final l = model.linkById(d.linkId)!;
        final spec = catalog.pump(l.pumpSpecId);
        energy += annualEnergyCost(flow: d.flow, head: d.pumpHead, hoursPerYear: hours, costPerKwh: params.powerCostPerKwh, pumpEfficiency: spec?.efficiency ?? params.pumpEfficiency);
      }
    }
    return SystemFlowResult(flowId: sf.id, name: sf.name, converged: r.converged, supplies: duties, valves: valves, pipes: pipes, devices: devices, warnings: warnings.toSet().toList(), totalFlow: total, durationHours: sf.durationHours, annualEnergyCost: energy);
  }

  List<SystemFlow> effectiveSystemFlows() {
    if (project.systemFlows.isNotEmpty) return project.systemFlows;
    return [SystemFlow(id: 'auto', name: _label('name.allZones'), valveIds: {...model.valveNodes.keys, ...model.pivotNodes.keys}, durationHours: 1)];
  }

  /// Builds and solves the mainline LP over all system flows.
  LpAssignment _lpMainline(Map<String, List<GLink>> units, List<SystemFlow> flows, double totalDur) {
    final supplies = _supplies;
    final supplyNodes = {for (final s in supplies) model.supplyNodes[s.id]!: s};
    final (parent, source, _) = _bfs(supplyNodes.keys, model.mainlineLinks);
    final unitOf = <String, String>{for (final e in units.entries) for (final l in e.value) l.id: e.key};
    // nominal analyses per flow
    final flowResults = <NetworkResult>[];
    final demands = <Map<String, double>>[];
    for (final f in flows) {
      final demand = <String, double>{};
      for (final vid in f.valveIds) {
        if (_demandNode(vid) == null) continue;
        demand[vid] = _demandOf(vid).$1;
      }
      demands.add(demand);
      flowResults.add(_mainlineNetwork({for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM}, demand).solve());
    }
    final cands = <String, List<PipeSpec>>{};
    final lengths = <String, double>{};
    final maxSizes = <String, int>{};
    for (final e in units.entries) {
      var qmax = 0.0;
      for (final r in flowResults) {
        for (final l in e.value) {
          qmax = math.max(qmax, (r.links[l.id]?.flow ?? 0).abs());
        }
      }
      cands[e.key] = _velocityCandidates(e.value.first, qmax);
      lengths[e.key] = _unitLength(e.value);
      maxSizes[e.key] = _maxSizesFor(e.value.first);
    }
    // head variables per (supply, flow)
    final headVars = <LpHeadVar>[];
    final headIndex = <String, int>{};
    for (var fi = 0; fi < flows.length; fi++) {
      final share = totalDur > 0 ? flows[fi].durationHours / totalDur : 1.0;
      for (final s in supplies) {
        final nid = model.supplyNodes[s.id]!;
        var q = 0.0;
        for (final l in model.nodes[nid]!.links) {
          final lr = flowResults[fi].links[l.id];
          if (lr == null) continue;
          q += l.from == nid ? lr.flow : -lr.flow;
        }
        final energy = s.calculatePressure && params.tradeCapitalVsRunning ? annualEnergyCost(flow: math.max(q, 0), head: 1, hoursPerYear: params.hoursPerYear * share, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency) : 0.0;
        headIndex['${s.id}|$fi'] = headVars.length;
        headVars.add(LpHeadVar(energyPerMetre: energy, fixedValue: s.calculatePressure ? null : s.designHeadM, maxValue: s.calculatePressure && s.maxHeadM > 0 ? s.maxHeadM : null, name: '${s.name}|${flows[fi].name}'));
      }
    }
    final constraints = <LpHeadConstraint>[];
    for (var fi = 0; fi < flows.length; fi++) {
      final r = flowResults[fi];
      double q(GLink l) => (r.links[l.id]?.flow ?? 0).abs();
      void constrain(String node, double minPressure, double? maxPressure, double offset) {
        final src = source[node];
        if (src == null) return;
        final s = supplyNodes[src]!;
        final byUnit = <String, Map<String, double>>{};
        var constant = 0.0;
        for (final l in _pathFromParents(parent, node)) {
          final u = unitOf[l.id];
          if (u != null) {
            final m = byUnit.putIfAbsent(u, () => {});
            for (final sp in cands[u]!) {
              m[sp.id] = (m[sp.id] ?? 0) + _linkLoss(l, sp, q(l));
            }
          } else if (l.kind == GLinkKind.pipe) {
            constant += _currentLoss(l, q(l));
          } else {
            constant += r.links[l.id]?.headLoss ?? 0;
          }
        }
        final dz = model.nodes[node]!.elevation + offset - model.nodes[src]!.elevation;
        constraints.add(LpHeadConstraint(headVar: headIndex['${s.id}|$fi']!, lossByUnitSpec: byUnit, constant: constant, minPressure: minPressure + dz, maxPressure: maxPressure != null ? maxPressure + dz : null, tag: node));
      }

      for (final vid in flows[fi].valveIds) {
        final vn = _demandNode(vid);
        if (vn == null) continue;
        final pr = results.pivots[vid];
        if (pr != null) {
          constrain(vn, pr.inletHead, null, 0);
          continue;
        }
        final z = results.zones[vid];
        if (z == null) continue;
        constrain(vn, z.requiredUpstreamHead, null, 0);
      }
      // mainline outlets (valve-in-head) keep their pressure window
      for (final id in model.mainlineNodes) {
        final n = model.nodes[id]!;
        if (n.emitters.isEmpty) continue;
        var lo = -double.infinity, hi = double.infinity, off = 0.0;
        for (final e in n.emitters) {
          lo = math.max(lo, e.allowedMin);
          hi = math.min(hi, e.allowedMax);
          off = math.max(off, e.offset);
        }
        if (lo.isFinite) constrain(id, lo, hi.isFinite ? hi : null, off);
      }
    }
    return lpSize(LpSizingInput(units: units.keys.toList(), candidates: cands, unitLength: lengths, maxSizes: maxSizes, headVars: headVars, constraints: constraints, crf: _crf(), tradeCapital: params.tradeCapitalVsRunning));
  }

  void sizeMainline() {
    final flows = effectiveSystemFlows();
    final totalDur = flows.fold(0.0, (s, f) => s + f.durationHours);
    final units = _units(model.mainlineLinks);
    List<SystemFlowResult> analyzeAll() => [for (final f in flows) analyzeSystemFlow(f, totalDuration: totalDur)];
    if (units.isEmpty || _supplies.isEmpty) {
      results.systemFlows
        ..clear()
        ..addAll(analyzeAll());
      return;
    }
    final supplies = _supplies;
    final supplyNodes = supplies.map((s) => model.supplyNodes[s.id]!).toSet();
    for (final e in units.entries) {
      _assign(e.key, _candidates(e.value.first).first);
    }
    // 1. velocity sizing over all flows
    for (var pass = 0; pass < 4; pass++) {
      final qmax = <String, double>{};
      for (final f in flows) {
        final demand = <String, double>{};
        for (final vid in f.valveIds) {
          if (_demandNode(vid) == null) continue;
          demand[vid] = _demandOf(vid).$1;
        }
        final r = _mainlineNetwork({for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM}, demand).solve();
        for (final e in units.entries) {
          for (final l in e.value) {
            qmax[e.key] = math.max(qmax[e.key] ?? 0, (r.links[l.id]?.flow ?? 0).abs());
          }
        }
      }
      var changed = false;
      for (final e in units.entries) {
        final pick = _velocityCandidates(e.value.first, qmax[e.key] ?? 0).first;
        if (_assigned[e.key] != pick.id) {
          _assign(e.key, pick);
          changed = true;
        }
      }
      if (!changed) break;
    }
    var lpDone = false;
    if (params.sizingMethod == SizingMethod.lp) {
      final pipeLinks = model.mainlineLinks.where((l) => model.linkById(l)?.kind == GLinkKind.pipe).length;
      if (pipeLinks >= model.mainlineNodes.length && model.mainlineNodes.isNotEmpty) results.messages.add('lp_loops_approx');
      final a = _lpMainline(units, flows, totalDur);
      if (a.feasible) {
        _applyAssignment(a);
        lpDone = true;
      } else {
        results.messages.add('lp_infeasible:${_label('menu.mainline')}');
      }
    }
    // 2. deficit loop for fixed-pressure supplies
    var res = analyzeAll();
    final anyFixed = supplies.any((s) => !s.calculatePressure);
    if (anyFixed) {
      for (var it = 0; it < 400; it++) {
        SystemFlowResult? worst;
        ValveDuty? worstValve;
        for (final f in res) {
          for (final v in f.valves) {
            if (v.deficit > 0.01 && (worstValve == null || v.deficit > worstValve.deficit)) {
              worst = f;
              worstValve = v;
            }
          }
        }
        if (worst == null || worstValve == null) break;
        final nm = _demandNode(worstValve.valveId)!;
        // path from nearest supply
        Set<GLink> path = {};
        for (final sn in supplyNodes) {
          final p = _path(sn, nm, model.mainlineLinks);
          if (p.isNotEmpty && (path.isEmpty || p.length < path.length)) path = p.toSet();
        }
        final lossByLink = {for (final p in worst.pipes) p.linkId: p.headLoss};
        String? bestUnit;
        PipeSpec? bestSpec;
        var bestScore = 0.0;
        for (final e in units.entries) {
          if (!e.value.any(path.contains)) continue;
          final cur = _specOf(e.value.first)!;
          final next = _next(cur, _candidates(e.value.first));
          if (next == null) continue;
          final red = _lossReduction(e.value, next, lossByLink, path);
          final cost = (next.costPerM - cur.costPerM) * _unitLength(e.value);
          final score = red / math.max(cost, 1e-6);
          if (score > bestScore) {
            bestScore = score;
            bestUnit = e.key;
            bestSpec = next;
          }
        }
        if (bestUnit == null) {
          results.messages.add('mainline_cannot_meet_pressure');
          break;
        }
        _assign(bestUnit, bestSpec!);
        _pendingSplits.remove(bestUnit);
        res = analyzeAll();
      }
    }
    // 3. economic trade-off for calculated supplies / pumps (greedy only)
    if (!lpDone && params.tradeCapitalVsRunning) {
      final crf = _crf();
      for (var it = 0; it < 300; it++) {
        String? bestUnit;
        PipeSpec? bestSpec;
        var bestGain = 0.0;
        for (final e in units.entries) {
          final cur = _specOf(e.value.first)!;
          final next = _next(cur, _candidates(e.value.first));
          if (next == null) continue;
          var saving = 0.0;
          for (final f in res) {
            if (f.valves.isEmpty) continue;
            final worstValve = f.valves.reduce((a, b) => a.deficit >= b.deficit ? a : b);
            final nm = _demandNode(worstValve.valveId)!;
            Set<GLink> path = {};
            for (final sn in supplyNodes) {
              final p = _path(sn, nm, model.mainlineLinks);
              if (p.isNotEmpty && (path.isEmpty || p.length < path.length)) path = p.toSet();
            }
            if (!e.value.any(path.contains)) continue;
            final lossByLink = {for (final p in f.pipes) p.linkId: p.headLoss};
            final red = _lossReduction(e.value, next, lossByLink, path);
            final share = totalDur > 0 ? f.durationHours / totalDur : 1.0;
            saving += annualEnergyCost(flow: f.totalFlow, head: red, hoursPerYear: params.hoursPerYear * share, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency);
          }
          final capital = (next.costPerM - cur.costPerM) * _unitLength(e.value) * crf;
          final gain = saving - capital;
          if (gain > bestGain) {
            bestGain = gain;
            bestUnit = e.key;
            bestSpec = next;
          }
        }
        if (bestUnit == null) break;
        _assign(bestUnit, bestSpec!);
        res = analyzeAll();
      }
    }
    // 4. rationalize from each supply
    for (final sn in supplyNodes) {
      _rationalize(sn, model.mainlineLinks, units);
    }
    _writeBack(units);
    results.systemFlows
      ..clear()
      ..addAll(analyzeAll());
  }

  // ------------------------------------------------------------ all

  /// The design as a lazy sequence of steps. Steps must be run in order as
  /// they are produced: the sequence inspects the state left by the previous
  /// step (telescoped units) to decide what comes next, so it must not be
  /// materialised with `toList()` before running.
  Iterable<_DesignStep> _steps({required bool sizeZones, required bool sizeMain}) sync* {
    results.unconnected.addAll(model.unconnectedEntities);
    results.messages.addAll(model.warnings);
    results.method = (sizeZones || sizeMain) ? params.sizingMethod.name : 'analysis';
    var i = 0;
    for (final vid in model.valveNodes.keys) {
      yield (stage: DesignStage.zones, zoneId: vid, zoneIndex: ++i, run: () => results.zones[vid] = sizeZones ? sizeZone(vid) : analyzeZone(vid));
    }
    for (final p in project.entities.whereType<PivotEntity>()) {
      if (!model.pivotNodes.containsKey(p.id)) continue;
      yield (stage: DesignStage.zones, zoneId: p.id, zoneIndex: ++i, run: () => results.pivots[p.id] = analyzePivotEntity(p));
    }
    void analyzeFlows() {
      final flows = effectiveSystemFlows();
      final totalDur = flows.fold(0.0, (s, f) => s + f.durationHours);
      results.systemFlows
        ..clear()
        ..addAll([for (final f in flows) analyzeSystemFlow(f, totalDuration: totalDur)]);
    }

    yield (
      stage: DesignStage.mainline,
      zoneId: null,
      zoneIndex: 0,
      run: () {
        if (sizeMain) {
          sizeMainline();
        } else {
          analyzeFlows();
        }
      },
    );
    // telescoped units: split the entities and analyse the final network
    if (_pendingSplits.isNotEmpty) {
      var n = 0;
      yield (
        stage: DesignStage.splits,
        zoneId: null,
        zoneIndex: 0,
        run: () {
          n = _applySplits();
          if (n > 0) {
            results.unconnected
              ..clear()
              ..addAll(model.unconnectedEntities);
            results.zones.clear();
          }
        },
      );
      if (n > 0) {
        i = 0;
        for (final vid in model.valveNodes.keys) {
          yield (stage: DesignStage.splits, zoneId: vid, zoneIndex: ++i, run: () => results.zones[vid] = _reanalyzeSplitZone(vid));
        }
        yield (stage: DesignStage.splits, zoneId: null, zoneIndex: 0, run: analyzeFlows);
      }
    }
    yield (
      stage: DesignStage.flushing,
      zoneId: null,
      zoneIndex: 0,
      run: () {
        results.invalidateCaches();
        analyzeFlushing();
      },
    );
    yield (stage: DesignStage.surge, zoneId: null, zoneIndex: 0, run: checkSurge);
    yield (stage: DesignStage.bom, zoneId: null, zoneIndex: 0, run: buildBom);
  }

  /// Final analysis of a zone after its telescoped pipes were split; repairs
  /// the zone when the pieces no longer keep the pressure window.
  ZoneResult _reanalyzeSplitZone(String vid) {
    var z = analyzeZone(vid);
    if (z.withinWindow) return z;
    final units = _units(model.zoneLinks[vid] ?? <String>{});
    if (units.isEmpty) return z;
    final warnings = <String>[];
    for (final e in units.entries) {
      final spec = catalog.pipe(e.value.first.pipeSpecId);
      if (spec != null) _assign(e.key, spec);
    }
    _repairZone(vid, units, warnings, analyzeZone(vid, detailed: false));
    _writeBack(units);
    z = analyzeZone(vid);
    return z.copyWith(warnings: {...warnings, ...z.warnings}.toList());
  }

  DesignResults designAll({bool sizeZones = true, bool sizeMain = true}) {
    for (final s in _steps(sizeZones: sizeZones, sizeMain: sizeMain)) {
      s.run();
    }
    return results;
  }

  /// Same design as [designAll], but returns to the event loop between steps
  /// (every zone, the mainline, flushing, surge, bill of materials) so that a
  /// UI can repaint and show [onProgress]. [yieldControl] is awaited before
  /// each step; it defaults to a zero-delay timer, which is enough for the
  /// browser to paint a frame between steps.
  Future<DesignResults> designAllAsync({
    bool sizeZones = true,
    bool sizeMain = true,
    void Function(DesignProgress progress)? onProgress,
    Future<void> Function()? yieldControl,
  }) async {
    final pause = yieldControl ?? () => Future<void>.delayed(Duration.zero);
    final zoneCount = model.valveNodes.length;
    // zones + mainline + flushing + surge + BOM; a split re-analysis adds
    // one step per zone plus the split and the system-flow steps.
    var total = zoneCount + 4;
    var done = 0;
    var splitsCounted = false;
    for (final s in _steps(sizeZones: sizeZones, sizeMain: sizeMain)) {
      if (s.stage == DesignStage.splits && !splitsCounted) {
        splitsCounted = true;
        total += model.valveNodes.length + 2;
      }
      onProgress?.call(DesignProgress(stage: s.stage, done: done, total: total, zoneId: s.zoneId, zoneIndex: s.zoneIndex, zoneCount: model.valveNodes.length));
      await pause();
      s.run();
      done++;
    }
    onProgress?.call(DesignProgress(stage: DesignStage.bom, done: total, total: total, zoneCount: zoneCount));
    return results;
  }

  DesignResults analyzeAll() => designAll(sizeZones: false, sizeMain: false);

  // ------------------------------------------------------------ flushing

  /// Flushing analysis: every tape of a zone is flushed with its end open
  /// at the target velocity; finds the valve pressure that keeps the
  /// minimum end pressure and reports the flushing flow.
  List<FlushingResult> analyzeFlushing() {
    results.flushing.clear();
    final tapes = project.entities.whereType<TapeEntity>().toList();
    if (tapes.isEmpty || params.flushingVelocity <= 0) return results.flushing;
    final saved = {for (final t in tapes) t.id: t.flushingFlow};
    for (final t in tapes) {
      final spec = catalog.tape(t.tapeSpecId);
      if (spec == null) continue;
      if (t.flushingFlow <= 0) t.flushingFlow = flowForVelocity(velocity: params.flushingVelocity, diameter: spec.innerDiameter);
    }
    final savedModel = model;
    try {
      model = NetworkBuilder(project).build();
      for (final vid in model.valveNodes.keys) {
        final valve = project.byId(vid) as ControlValveEntity?;
        if (valve == null) continue;
        final nodeIds = model.zoneNodes[vid] ?? <String>{};
        final endNodes = <String>[];
        var tapeCount = 0;
        final tapeIds = <String>{};
        for (final id in nodeIds) {
          for (final e in model.nodes[id]!.emitters) {
            if (e.index == -2) {
              endNodes.add(id);
              tapeIds.add(e.entityId);
            }
          }
        }
        tapeCount = tapeIds.length;
        if (endNodes.isEmpty) continue;
        final (mainNode, zoneNode) = model.valveNodes[vid]!;
        double minEnd(NetworkResult r) {
          var m = double.infinity;
          for (final id in endNodes) {
            final nr = r.nodes[id];
            if (nr == null) continue;
            m = math.min(m, nr.head - model.nodes[id]!.elevation);
          }
          return m.isFinite ? m : 0;
        }

        var lo = 0.0, hi = 20.0;
        var r = _zoneNetwork(vid, hi, true).solve();
        var it = 0;
        while (minEnd(r) < params.flushingMinEndHeadM && it < 12) {
          hi *= 2;
          r = _zoneNetwork(vid, hi, true).solve();
          it++;
        }
        for (var i = 0; i < 30; i++) {
          final mid = (lo + hi) / 2;
          r = _zoneNetwork(vid, mid, true).solve();
          if (minEnd(r) >= params.flushingMinEndHeadM) {
            hi = mid;
          } else {
            lo = mid;
          }
          if (hi - lo < 1e-3) break;
        }
        final head = hi;
        r = _zoneNetwork(vid, head, true).solve();
        var flow = 0.0;
        for (final id in nodeIds) {
          final n = model.nodes[id]!;
          final nr = r.nodes[id];
          if (nr == null) continue;
          for (final e in n.emitters) {
            flow += e.curve.flow(math.max(nr.head - (n.elevation + e.offset), 0)) * e.count;
          }
        }
        var vmax = 0.0;
        for (final lid in model.zoneLinks[vid] ?? <String>{}) {
          final l = model.linkById(lid)!;
          if (l.tapeSpecId == null) continue;
          final lr = r.links[lid];
          if (lr != null) vmax = math.max(vmax, velocity(flow: lr.flow.abs(), diameter: _diameter(l)));
        }
        final valveSpec = catalog.valve(valve.valveSpecId);
        final valveLoss = valveSpec?.loss.loss(flow) ?? 0;
        final zn = model.nodes[zoneNode]!, mn = model.nodes[mainNode]!;
        results.flushing.add(FlushingResult(valveId: vid, zoneName: valve.zoneName, flow: flow, requiredDownstreamHead: head, requiredUpstreamHead: head + valveLoss + (zn.elevation - mn.elevation), tapeCount: tapeCount, minEndHead: minEnd(r), maxVelocity: vmax, flushingVelocity: params.flushingVelocity, converged: r.converged));
      }
    } finally {
      for (final t in tapes) {
        t.flushingFlow = saved[t.id]!;
      }
      model = savedModel;
    }
    return results.flushing;
  }

  // ------------------------------------------------------------ surge

  /// Joukowsky surge check of every pipe entity against its pressure class.
  List<SurgeResult> checkSurge() {
    results.surge.clear();
    if (!params.checkSurge) return results.surge;
    final worst = <String, (PipeSegmentResult, String)>{};
    void consider(PipeSegmentResult p, String ctx) {
      final cur = worst[p.entityId];
      if (cur == null || p.velocity > cur.$1.velocity) worst[p.entityId] = (p, ctx);
    }

    for (final z in results.zones.values) {
      for (final p in z.pipes) {
        consider(p, z.zoneName);
      }
    }
    for (final f in results.systemFlows) {
      for (final p in f.pipes) {
        consider(p, f.name);
      }
    }
    for (final entry in worst.entries) {
      final (p, ctx) = entry.value;
      final spec = catalog.pipe(p.pipeSpecId);
      if (spec == null) continue; // tapes: not checked
      final e = project.byId(entry.key);
      final length = e is PolyEntity ? e.length : p.length;
      final a = waveCelerity(diameter: spec.innerDiameter, wallThickness: math.max(spec.wallThicknessMm, 0.5) / 1000, material: spec.material);
      final full = joukowskySurgeHead(celerity: a, velocityChange: p.velocity);
      final tc = criticalClosureTime(length: math.max(length, 1), celerity: a);
      final closure = params.valveClosureTimeS;
      final surge = closure <= 0 || closure < tc ? full : full * tc / closure;
      var staticMax = math.max(p.pressureStart, p.pressureEnd);
      for (final z in results.zones.values) {
        for (final q in z.pipes) {
          if (q.entityId == entry.key) staticMax = math.max(staticMax, math.max(q.pressureStart, q.pressureEnd));
        }
      }
      for (final f in results.systemFlows) {
        for (final q in f.pipes) {
          if (q.entityId == entry.key) staticMax = math.max(staticMax, math.max(q.pressureStart, q.pressureEnd));
        }
      }
      final sr = SurgeResult(entityId: entry.key, context: ctx, pipeName: spec.name, velocity: p.velocity, celerity: a, surgeHead: surge, maxStaticHead: staticMax, rating: spec.pressureRatingM, closureTime: closure, criticalTime: tc);
      results.surge.add(sr);
      if (sr.exceeds) results.messages.add('surge_rating_exceeded:${entry.key}');
    }
    return results.surge;
  }

  // ------------------------------------------------------------ BOM

  List<BomLine> buildBom() {
    final lines = <String, BomLine>{};
    void add(String cat, String desc, String unit, double qty, double cost, String? specId, {String code = '', String supplier = ''}) {
      final key = '$cat|$desc';
      final l = lines[key];
      if (l != null) {
        l.quantity += qty;
      } else {
        lines[key] = BomLine(category: cat, description: desc, unit: unit, quantity: qty, unitCost: cost, specId: specId, code: code, supplier: supplier);
      }
    }

    for (final l in model.links) {
      if (l.kind != GLinkKind.pipe) continue;
      final tape = catalog.tape(l.tapeSpecId);
      if (tape != null) {
        add('bom.tapes', tape.name, 'm', l.length, tape.costPerM, tape.id, code: tape.code, supplier: tape.supplier);
        continue;
      }
      final spec = _specOf(l);
      if (spec != null) add('bom.pipes', spec.name, 'm', l.length, spec.costPerM, spec.id, code: spec.code, supplier: spec.supplier);
    }
    for (final e in project.entities) {
      if (model.unconnectedEntities.contains(e.id)) continue;
      switch (e) {
        case OutletEntity o:
          final s = catalog.outlet(o.outletSpecId);
          if (s != null) add('bom.outlets', '${s.name} — ${s.nozzle(o.nozzleId)?.name ?? ''}', 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
        case SpraylineEntity s:
          final spec = catalog.outlet(s.outletSpecId);
          if (spec != null) add('bom.outlets', '${spec.name} — ${spec.nozzle(s.nozzleId)?.name ?? ''}', 'un', s.outletCount.toDouble(), spec.cost, spec.id, code: spec.code, supplier: spec.supplier);
        case ControlValveEntity v:
          final s = catalog.valve(v.valveSpecId);
          if (s != null) add('bom.valves', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
        case MiscHydraulicEntity m:
          final s = catalog.valve(m.valveSpecId);
          if (s != null) add('bom.devices', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
        case PumpEntity p:
          final s = catalog.pump(p.pumpSpecId);
          if (s != null) add('bom.pumps', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier);
        case PivotEntity p:
          final r = results.pivots[p.id];
          final towers = r?.towerCount ?? p.towerPositions().length;
          final label = p.name.isNotEmpty ? p.name : _label('tool.pivot');
          add('bom.pivots', '$label — ${p.kind == PivotKind.pivot ? _label('pivot.kindPivot') : _label('pivot.kindLinear')} ${p.radiusM.round()} m, $towers ${_label('pivot.towers')}', 'un', 1, p.machineCost, null);
          add('bom.pivots', '$label — ${_label('pivot.towersItem')} (${p.spanLengthM.round()} m)', 'un', towers.toDouble(), p.towerCost, null);
          final pipe = catalog.pipe(p.pipeSpecId);
          if (pipe != null) add('bom.pipes', pipe.name, 'm', p.radiusM, pipe.costPerM, pipe.id, code: pipe.code, supplier: pipe.supplier);
          final nSpr = r?.sprinklerCount ?? (p.sprinklerSpacingM > 0 ? (p.radiusM / p.sprinklerSpacingM).round() : 0);
          final spr = catalog.outlet(p.sprinklerSpecId);
          if (nSpr > 0) add('bom.pivots', '$label — ${spr?.name ?? _label('pivot.sprinklersItem')}', 'un', nSpr.toDouble(), spr?.cost ?? 0, spr?.id, code: spr?.code ?? '', supplier: spr?.supplier ?? '');
          final reg = catalog.valve(p.regulatorSpecId);
          if (reg != null && nSpr > 0) add('bom.pivots', '$label — ${reg.name}', 'un', nSpr.toDouble(), reg.cost, reg.id, code: reg.code, supplier: reg.supplier);
          if (p.endGunFlow > 0) add('bom.pivots', '$label — ${_label('pivot.endGunItem')}', 'un', 1, 0, null);
        default:
          break;
      }
    }
    results.bom
      ..clear()
      ..addAll(lines.values);
    if (params.selectFittings) {
      final sel = selectFittings(project, model, _specOf, t: _label);
      results.bom.addAll(sel.lines);
      final seen = <String>{};
      for (final m in sel.missing) {
        final name = genericFittingName(m.kind, m.sizeMm, m.size2Mm, _label);
        if (seen.add(name)) results.messages.add('fitting_missing:$name');
      }
    }
    results.bom.sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
    results.capitalCost = results.bom.fold(0.0, (s, l) => s + l.total);
    results.annualCapitalCost = results.capitalCost * _crf();
    results.annualEnergyCost = results.systemFlows.fold(0.0, (s, f) => s + f.annualEnergyCost);
    return results.bom;
  }
}

/// Water requirement summary for an irrigation area.
class AreaRequirement {
  AreaRequirement({required this.areaId, required this.name, required this.areaM2, required this.grossDepthMm, required this.dailyVolumeM3, required this.flow, required this.hoursPerDay, required this.precipitationMmH});
  final String areaId;
  final String name;
  final double areaM2;
  final double grossDepthMm;
  final double dailyVolumeM3;
  final double flow;
  final double hoursPerDay;
  final double precipitationMmH;
}

List<AreaRequirement> areaRequirements(Project project, DesignResults? results) {
  final out = <AreaRequirement>[];
  final outletsByEntity = results?.outletsByEntity ?? {};
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    var flow = 0.0;
    for (final e in project.entities) {
      if (e is OutletEntity && pointInPolygonSafe(e.position, a.points)) {
        final res = outletsByEntity[e.id];
        if (res != null && res.isNotEmpty) {
          flow += res.first.flow * res.first.count;
        } else {
          final n = project.catalog.outlet(e.outletSpecId)?.nozzle(e.nozzleId);
          if (n != null) flow += n.curve.flow(e.headM);
        }
      } else if (e is SpraylineEntity || e is TapeEntity) {
        final pts = (e as PolyEntity).points;
        // fraction of the lateral length inside the area, sampled away from
        // the vertices (laterals often start exactly on the boundary)
        final total = polylineLength(pts);
        const samples = 20;
        var hits = 0;
        for (var i = 0; i < samples; i++) {
          if (pointInPolygonSafe(pointAlongPolyline(pts, total * (i + 0.5) / samples), a.points)) hits++;
        }
        final inside = hits / samples;
        if (inside == 0) continue;
        final res = outletsByEntity[e.id];
        if (res != null) {
          flow += res.fold(0.0, (s, o) => s + o.flow * o.count) * inside;
        } else if (e is SpraylineEntity) {
          final n = project.catalog.outlet(e.outletSpecId)?.nozzle(e.nozzleId);
          if (n != null) flow += n.curve.flow(e.headM) * e.outletCount * inside;
        } else if (e is TapeEntity) {
          final t = project.catalog.tape(e.tapeSpecId);
          if (t != null) flow += t.emitter.flow(e.inletHeadM) * (e.length / t.emitterSpacingM) * inside;
        }
      }
    }
    final area = a.area;
    final gross = a.effectiveNetDepthMmPerDay / math.max(a.efficiency, 0.05);
    // Localised irrigation waters only the wetted fraction of the area; the
    // same factor is used by the crop table so both agree on volume and hours.
    final vol = gross / 1000 * area * a.wettedFraction.clamp(0.05, 1.0);
    final hours = flow > 0 ? vol / (flow * 3600) : 0.0;
    final pr = area > 0 ? flow * 3600 * 1000 / area : 0.0;
    out.add(AreaRequirement(areaId: a.id, name: a.name.isEmpty ? a.id : a.name, areaM2: area, grossDepthMm: gross, dailyVolumeM3: vol, flow: flow, hoursPerDay: hours, precipitationMmH: pr));
  }
  return out;
}

bool pointInPolygonSafe(dynamic p, List<dynamic> poly) {
  // thin wrapper to avoid importing geometry here twice
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i], pj = poly[j];
    if ((pi.y > p.y) != (pj.y > p.y) && p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) inside = !inside;
  }
  return inside;
}

/// Convenience for lateral tools: builds an [EmitterCurve] description string.
String describeEmitter(EmitterCurve c, Units u) => 'q = ${fmt(u.flowFromSi(c.k), 3)}·H^${fmt(c.x, 2)}';
