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
import '../model/catalog_check.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/split.dart';
import '../units.dart';
import 'agb_design.dart';
import 'area_water.dart';
import 'electrical.dart';
import 'field_machines.dart';
import 'fittings.dart';
import 'lp.dart';
import 'lp_sizing.dart';
import 'mechanised.dart';
import 'network_builder.dart';
import 'pivot.dart';
import 'pump_selection.dart';
import 'results.dart';
import 'valve_in_head.dart';

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
  /// [stations] defaults to the valve-in-head stations of [project] and how
  /// its system flows schedule them; [VihStations.none] designs every
  /// mainline outlet as a plain emitter of every flow, as before the heads
  /// could be scheduled.
  Designer(this.project, {String Function(String key)? label, VihStations? stations})
    : model = NetworkBuilder(project).build(),
      vih = stations ?? VihStations.of(project),
      _label = label ?? ((k) => k);

  final Project project;
  final String Function(String key) _label;
  NetworkModel model;
  final DesignResults results = DesignResults(timestamp: DateTime.now());

  /// Valve-in-head stations (`valve_in_head.dart`).
  final VihStations vih;

  NetworkModel? _headsModel;
  Map<String, (String, EmitterRef)> _headsOf = const {};

  /// Mainline node and emitter of every valve-in-head head of the model, by
  /// outlet id.
  Map<String, (String, EmitterRef)> get _heads {
    if (!identical(_headsModel, model)) {
      _headsModel = model;
      _headsOf = {
        for (final id in model.mainlineNodes)
          for (final e in model.nodes[id]!.emitters)
            if (vih.stationOf.containsKey(e.entityId)) e.entityId: (id, e),
      };
    }
    return _headsOf;
  }

  /// What the heads of the scheduled valve-in-head stations that run in a
  /// flow opening [listed] need at their mainline nodes: the pressure head
  /// that gives the nozzle its nominal pressure (nominal plus riser), like
  /// the head a zone valve needs. Stations no flow lists run as mainline
  /// outlets always did, without a say on the supply pressure.
  List<(String, double)> _headNeeds(Set<String> listed) => [
    for (final h in _heads.entries)
      if (vih.headScheduled(h.key) && vih.headRuns(h.key, listed)) (h.value.$1, h.value.$2.nominalHead + h.value.$2.offset),
  ];

  /// The valve-in-head stations running in a flow opening [listed], from its
  /// solution [r]; adds the pressure messages of the scheduled ones to
  /// [warnings] (an unscheduled station keeps the silence of the plain
  /// mainline outlets).
  List<VihDuty> _vihDuties(NetworkResult r, Set<String> listed, List<String> warnings) {
    final out = <VihDuty>[];
    final heads = _heads;
    for (final s in vih.heads.entries) {
      if (!vih.runs(s.key, listed)) continue;
      var n = 0;
      var q = 0.0, pMin = double.infinity, pMax = -double.infinity, lo = -double.infinity, hi = double.infinity;
      var worst = -double.infinity, need = 0.0, avail = 0.0;
      String? crit, top;
      GNode? at;
      for (final id in s.value) {
        final h = heads[id];
        final nr = h == null ? null : r.nodes[h.$1];
        if (h == null || nr == null) continue;
        final (node, e) = h;
        final gn = model.nodes[node]!;
        final p = nr.head - (gn.elevation + e.offset);
        n += e.count;
        q += e.curve.flow(math.max(p, 0)) * e.count;
        pMin = math.min(pMin, p);
        if (p > pMax) {
          pMax = p;
          top = id;
        }
        lo = math.max(lo, e.allowedMin);
        hi = math.min(hi, e.allowedMax);
        final d = e.nominalHead + e.offset - nr.pressure;
        if (crit == null || d > worst) {
          crit = id;
          worst = d;
          need = e.nominalHead + e.offset;
          avail = nr.pressure;
          at = gn;
        }
      }
      if (crit == null || at == null) continue;
      final scheduled = vih.scheduled.contains(s.key);
      out.add(
        VihDuty(
          stationId: s.key,
          name: vih.nameOf(s.key),
          heads: n,
          flow: q,
          minPressure: pMin,
          maxPressure: pMax,
          allowedMin: lo,
          allowedMax: hi,
          criticalId: crit,
          availableHead: avail,
          requiredHead: need,
          elevation: at.elevation,
          p: at.p,
          scheduled: scheduled,
        ),
      );
      if (scheduled && worst > 0.01) warnings.add('vih_pressure_deficit:$crit');
      if (scheduled && top != null && pMax > hi + 0.01) warnings.add('vih_pressure_high:$top');
    }
    return out;
  }

  /// Mainline node of the worst need of flow [f]: the valve or pivot, or the
  /// critical head of a scheduled valve-in-head station, furthest below what
  /// it needs (the first on a tie, valves first); null when it has none.
  String? _worstNode(SystemFlowResult f) => _worstNodeOf(f.valves, f.heads);

  String? _worstNodeOf(List<ValveDuty> valves, List<VihDuty> heads) {
    String? node;
    var most = -double.infinity;
    for (final v in valves) {
      if (node == null || v.deficit > most) {
        node = _demandNode(v.valveId);
        most = v.deficit;
      }
    }
    for (final h in heads) {
      if (h.scheduled && (node == null || h.deficit > most)) {
        node = _heads[h.criticalId]?.$1;
        most = h.deficit;
      }
    }
    return node;
  }

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
    final spec = pivotSpecOf(project, p);
    final terrain = model.terrain;
    final rise = terrain == null || terrain.isEmpty ? null : groundRiseFunction(spec, p.center, p.angleRad, terrain.elevationAt);
    final name = p.name.isNotEmpty ? p.name : (p.zoneName.isNotEmpty ? p.zoneName : _label('tool.pivot'));
    final nozzles = [for (final n in catalog.outlet(p.sprinklerSpecId)?.nozzles ?? const <NozzleSpec>[]) (n.name, n.curve)];
    final r = analyzePivot(spec, id: p.id, name: name, groundRiseAt: rise, nozzles: nozzles);
    // the mainline feeds what the sprinkler package needs: its regulators,
    // drops and nozzles may ask for more than the plain machine hydraulics
    final mech = analyzeMechanised(project, p, terrain: terrain);
    final pkg = mech.package;
    // a corner arm adds its banks (all on, the arm extended) to the machine,
    // whose package then ends at the hinge
    final arm = mech.cornerArm;
    final armFlow = arm == null || arm.steps.isEmpty ? 0.0 : math.max(0.0, arm.peakFlow - arm.mainFlow);
    if (pkg.requiredInletHeadM > 0 && pkg.designFlow > 0) return r.withInlet(flow: pkg.designFlow + armFlow, inletHead: pkg.requiredInletHeadM);
    return r;
  }

  /// Flow and required head of a demand id (zone valve or pivot).
  (double, double) _demandOf(String id) {
    if (model.pivotNodes.containsKey(id)) {
      final p = project.byId(id);
      // 1.6.0 AGB: a traveller lane or a furrow set
      if (p != null && p is! PivotEntity) return fieldMachineDemand(project, p, terrain: model.terrain) ?? (0, 0);
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

  /// Speed ratio a variable-speed drive set for each pump (entity id) in the
  /// system flow being analysed.
  final Map<String, double> _vfdSpeed = {};

  /// Pumps with a variable-speed drive (target outlet pressure) on the
  /// mainline.
  List<(GLink, PumpEntity)> get _vfdPumps => [
    for (final lid in model.mainlineLinks)
      if (model.linkById(lid) case final l? when l.kind == GLinkKind.pump)
        if (project.byId(l.entityId) case final PumpEntity p when p.targetPressureM > 0) (l, p),
  ];

  /// Sets the speed of every variable-speed pump so its outlet keeps the
  /// target pressure with the demands of the flow (bisection on the speed,
  /// a few rounds when several pumps interact); warns when the target is
  /// out of the speed range.
  void _tuneVfd(HydraulicNetwork Function() build, List<String> warnings) {
    final pumps = _vfdPumps;
    if (pumps.isEmpty) return;
    double outlet(GLink l) {
      final r = build().solve();
      final n = r.nodes[l.to];
      return n == null ? 0 : n.pressure;
    }

    for (var round = 0; round < (pumps.length > 1 ? 3 : 1); round++) {
      for (final (l, p) in pumps) {
        final hi = p.speedRatio, lo = math.min(p.minSpeedRatio.clamp(0.1, 1.0).toDouble(), hi);
        final target = p.targetPressureM;
        _vfdSpeed[p.id] = hi;
        if (outlet(l) < target - 0.05) {
          if (round == 0) warnings.add('vfd_target_unreachable:${p.id}');
          continue;
        }
        _vfdSpeed[p.id] = lo;
        if (outlet(l) > target + 0.05) {
          if (round == 0) warnings.add('vfd_below_min_speed:${p.id}');
          continue;
        }
        var a = lo, b = hi;
        for (var it = 0; it < 30 && b - a > 1e-4; it++) {
          final m = (a + b) / 2;
          _vfdSpeed[p.id] = m;
          if (outlet(l) < target) {
            a = m;
          } else {
            b = m;
          }
        }
        _vfdSpeed[p.id] = (a + b) / 2;
      }
    }
  }

  /// Least pressure rating (m) every computer-sized unit needs, learnt from
  /// the analyses of the sizing passes: the LP and the greedy steps then only
  /// offer the unit pipes that withstand it.
  final Map<String, double> _requiredRating = {};

  /// Pressure rating of [s] at the design water temperature (PVC and PE lose
  /// part of their class when the water is warm).
  double _rating(PipeSpec s) => s.ratingAt(params.waterTempC);

  List<PipeSpec> _candidates(GLink l) {
    final all = catalog.pipesFor(l.usage);
    final need = _requiredRating[l.entityId];
    if (need == null) return all;
    final ok = all.where((s) => s.pressureRatingM <= 0 || _rating(s) >= need - 1e-6).toList();
    return ok.isEmpty ? all : ok;
  }

  /// Raises [_requiredRating] for every unit of [units] whose pipe is rated
  /// below the operating pressure found in [pipes]; true when a unit got a
  /// new, higher requirement (another sizing pass is then worth it).
  bool _learnRatings(Iterable<PipeSegmentResult> pipes, Map<String, List<GLink>> units) {
    var changed = false;
    for (final p in pipes) {
      if (!units.containsKey(p.entityId)) continue;
      final spec = catalog.pipe(p.pipeSpecId);
      if (spec == null || spec.pressureRatingM <= 0) continue;
      final need = math.max(p.pressureStart, p.pressureEnd);
      if (need <= _rating(spec) + 1e-6 || need <= (_requiredRating[p.entityId] ?? 0) + 1e-6) continue;
      _requiredRating[p.entityId] = need;
      _networkInputs++;
      changed = true;
    }
    return changed;
  }

  /// Adds a design message once (sizing passes may meet it again).
  void _note(String message) {
    if (!results.messages.contains(message)) results.messages.add(message);
  }

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

  double _effectiveLength(GLink l) =>
      math.max(l.length * (params.applyMinorLosses && params.minorLossMethod == MinorLossMethod.percent && l.usage != PipeUsage.lateral ? 1 + params.minorLossPct / 100 : 1), 1e-3);

  HLink _toHLink(GLink l) {
    switch (l.kind) {
      case GLinkKind.pipe:
        final tape = catalog.tape(l.tapeSpecId);
        final spec = _specOf(l);
        final c = params.adjustedC(tape?.hazenC ?? spec?.hazenC ?? 150);
        final rough = tape != null ? tape.roughnessMm / 1000 : (spec?.roughness ?? 1.5e-6);
        return HLink(
          id: l.id,
          from: l.from,
          to: l.to,
          diameter: _diameter(l),
          length: _effectiveLength(l),
          hazenC: c,
          roughness: rough,
          minorK: params.applyMinorLosses ? l.minorK : 0,
          tag: l,
          scobeyKs: spec?.scobeyKs ?? 0.32,
          manningN: spec?.manningN ?? 0.009,
        );
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
      case GLinkKind.psv:
        final spec = catalog.valve(l.valveSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.psv, prvSetting: l.settingM, device: spec?.loss, tag: l);
      case GLinkKind.fcv:
        final spec = catalog.valve(l.valveSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.fcv, fcvFlow: l.settingFlow, device: spec?.loss, tag: l);
      case GLinkKind.pump:
        final spec = catalog.pump(l.pumpSpecId);
        return HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.pump, pump: spec?.curve.withSpeed(_vfdSpeed[l.entityId] ?? l.speedRatio), tag: l);
    }
  }

  /// Head loss of a pipe link built with [spec] carrying [q] (m³/s).
  double _linkLoss(GLink l, PipeSpec spec, double q) {
    if (q <= 0) return 0;
    final hf = frictionLoss(
      method: params.frictionMethod,
      flow: q,
      diameter: spec.innerDiameter,
      length: _effectiveLength(l),
      c: params.adjustedC(spec.hazenC),
      roughness: spec.roughness,
      kinematicViscosity: params.kinematicViscosity,
      scobeyKs: spec.scobeyKs,
      manningN: spec.manningN,
    );
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
    final hf = frictionLoss(
      method: params.frictionMethod,
      flow: q,
      diameter: d,
      length: _effectiveLength(l),
      c: c,
      roughness: rough,
      kinematicViscosity: params.kinematicViscosity,
      scobeyKs: spec?.scobeyKs ?? 0.32,
      manningN: spec?.manningN ?? 0.009,
    );
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

  /// Zone networks by valve and detail, reused while the model and
  /// [_networkInputs] stay the same: the bisections on the valve pressure
  /// solve the same network with another head again and again.
  final Map<(String, bool), _ZoneNetwork> _zoneNetworks = {};

  /// Counts the changes the zone networks are built from: pipe assignments
  /// and pressure rating requirements.
  int _networkInputs = 0;

  /// The hydraulic network of a zone. [detailed] true = pressure dependent
  /// emitters, false = nominal fixed demands.
  HydraulicNetwork _zoneNetwork(String valveId, double downstreamHead, bool detailed) {
    final kept = _zoneNetworks[(valveId, detailed)];
    if (kept != null && identical(kept.model, model) && kept.inputs == _networkInputs) {
      final inlet = kept.inlet;
      if (inlet != null) inlet.fixedHead = inlet.elevation + downstreamHead;
      assert(_sameNetwork(kept.net, _buildZoneNetwork(valveId, downstreamHead, detailed)), 'zone network of $valveId reused after a change');
      return kept.net;
    }
    final net = _buildZoneNetwork(valveId, downstreamHead, detailed);
    // a pump's curve depends on the speed a variable-speed drive was given
    if (net.links.any((l) => l.kind == HLinkKind.pump)) {
      _zoneNetworks.remove((valveId, detailed));
    } else {
      final (_, zoneNode) = model.valveNodes[valveId]!;
      _zoneNetworks[(valveId, detailed)] = (model: model, inputs: _networkInputs, net: net, inlet: net.nodes[zoneNode]);
    }
    return net;
  }

  /// Whether two networks have the same nodes and links (debug check of the
  /// reused zone networks).
  static bool _sameNetwork(HydraulicNetwork a, HydraulicNetwork b) {
    if (a.nodes.length != b.nodes.length || a.links.length != b.links.length) return false;
    final na = a.nodes.values.toList(), nb = b.nodes.values.toList();
    for (var i = 0; i < na.length; i++) {
      final x = na[i], y = nb[i];
      if (x.id != y.id ||
          x.kind != y.kind ||
          x.elevation != y.elevation ||
          x.demand != y.demand ||
          x.fixedHead != y.fixedHead ||
          !identical(x.emitter, y.emitter) ||
          x.emitterCount != y.emitterCount ||
          x.emitterOffset != y.emitterOffset) {
        return false;
      }
    }
    for (var i = 0; i < a.links.length; i++) {
      final x = a.links[i], y = b.links[i];
      if (x.id != y.id || x.from != y.from || x.to != y.to || x.kind != y.kind || x.diameter != y.diameter || x.length != y.length || x.hazenC != y.hazenC || x.roughness != y.roughness) return false;
      if (x.minorK != y.minorK ||
          x.checkValve != y.checkValve ||
          !identical(x.device, y.device) ||
          x.prvSetting != y.prvSetting ||
          x.fcvFlow != y.fcvFlow ||
          x.scobeyKs != y.scobeyKs ||
          x.manningN != y.manningN ||
          !identical(x.tag, y.tag)) {
        return false;
      }
    }
    return true;
  }

  HydraulicNetwork _buildZoneNetwork(String valveId, double downstreamHead, bool detailed) {
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

  /// [count] gives the emitters running of each emitter reference (all of
  /// them by default); one that is off keeps its place with a count of 0.
  void _attachEmitters(HydraulicNetwork net, HNode h, GNode n, bool detailed, {int Function(EmitterRef e)? count}) {
    if (n.emitters.isEmpty) return;
    if (!detailed) {
      h.demand = n.emitters.fold(0.0, (s, e) => s + e.nominalFlow);
      return;
    }
    var first = true;
    var satellite = 0;
    for (final e in n.emitters) {
      if (e.index == -2) {
        // open tape end while flushing: a fixed outflow is a nodal demand. As
        // an emitter (exponent 0) it would switch off at any negative
        // pressure between iterations and, next to the last dripper, need a
        // satellite link whose huge conductance ill-conditions the system.
        h.demand += e.curve.k * e.count;
        continue;
      }
      final c = count == null ? e.count : count(e);
      if (first) {
        h.emitter = e.curve;
        h.emitterCount = c;
        h.emitterOffset = e.offset;
        first = false;
      } else if (identical(h.emitter, e.curve) && (h.emitterOffset - e.offset).abs() < 1e-9) {
        h.emitterCount += c;
      } else {
        final sid = '${n.id}_s${satellite++}';
        net.addNode(HNode(id: sid, elevation: n.elevation, emitter: e.curve, emitterCount: c, emitterOffset: e.offset));
        net.addLink(HLink(id: 'sat_$sid', from: n.id, to: sid, diameter: 0.5, length: 0.01, hazenC: 150));
      }
    }
  }

  /// Mean reference pressure of the emitters of a zone from a solved network.
  /// Whether [id] is a tape, for the entities of [_tapeModel]: a scan of the
  /// entities for every emitter of each analysis was quadratic.
  final Map<String, int> _tapeOf = {};
  NetworkModel? _tapeModel;

  /// 0 for an item that is no tape, 1 for a tape, 2 for a tape with a
  /// pressure regulator at its inlet.
  int _tapeKind(String id) {
    if (!identical(_tapeModel, model)) {
      _tapeModel = model;
      _tapeOf.clear();
      _regulatorsOf.clear();
    }
    if (id.isEmpty) return 0;
    return _tapeOf[id] ??= switch (project.byId(id)) {
      TapeEntity t => t.regulated ? 2 : 1,
      _ => 0,
    };
  }

  bool _isTape(String id) => _tapeKind(id) > 0;

  /// Whether the emitters of [id] sit behind the regulator of a tape: their
  /// pressure follows the regulator, not the zone valve.
  bool _regulated(String id) => _tapeKind(id) == 2;

  final Map<String, List<(String, double)>> _regulatorsOf = {};

  /// The inlet regulators of the tapes of zone [valveId]: the submain node
  /// before each one and the least pressure it needs there (the minimum
  /// submain pressure of the tape, at least its inlet pressure).
  List<(String, double)> _regulators(String valveId) {
    _tapeKind('');
    return _regulatorsOf[valveId] ??= [
      for (final lid in model.zoneLinks[valveId] ?? const <String>{})
        if (model.linkById(lid) case final l? when l.kind == GLinkKind.prv && _regulated(l.entityId))
          if (project.byId(l.entityId) case final TapeEntity t) (l.from, math.max(t.submainMinHeadM, t.inletHeadM)),
    ];
  }

  /// Whether zone [valveId] has emitters that follow the valve (not behind
  /// the inlet regulator of a tape).
  bool _followers(String valveId) {
    for (final id in model.zoneNodes[valveId] ?? const <String>{}) {
      for (final e in model.nodes[id]!.emitters) {
        if (e.index != -2 && !_regulated(e.entityId)) return true;
      }
    }
    return false;
  }

  /// The least margin of the regulators of [regs] in solution [r]: pressure
  /// at the submain node less what the regulator needs there.
  double _regulatorMargin(List<(String, double)> regs, NetworkResult r) {
    var m = double.infinity;
    for (final (node, need) in regs) {
      final nr = r.nodes[node];
      if (nr != null) m = math.min(m, nr.pressure - need);
    }
    return m;
  }

  (double, double) _meanPressures(String valveId, NetworkResult r) {
    var sumActual = 0.0, sumNominal = 0.0, w = 0.0;
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      final head = r.nodes[id]?.head;
      if (head == null) continue;
      for (final e in n.emitters) {
        if (e.index == -2) continue; // flushing
        // a tape by the pressure at its inlet (whichever way it was drawn);
        // behind a regulator by the regulator, not by the valve
        if (!e.inlet && _isTape(e.entityId)) continue;
        if (_regulated(e.entityId)) continue;
        final p = head - (n.elevation + e.offset);
        sumActual += p * e.count;
        sumNominal += e.nominalHead * e.count;
        w += e.count;
      }
    }
    if (w == 0) return (0, 0);
    return (sumActual / w, sumNominal / w);
  }

  /// Least rise of the mean emitter pressure per metre of valve head while
  /// the emitters follow the valve; below it a PRV, a PSV or an FCV of the
  /// zone holds them (without one the mean rises by 0.1 m/m or more even
  /// when nine tenths of the head are lost on the way).
  static const _saturationSlope = 0.05;

  /// The PRV, PSV or FCV of zone [valveId] that holds the pressure in the
  /// solution [r] (active), if any.
  String? _holdingDevice(String valveId, NetworkResult r) {
    for (final lid in model.zoneLinks[valveId] ?? const <String>{}) {
      final l = model.linkById(lid);
      if (l == null || (l.kind != GLinkKind.prv && l.kind != GLinkKind.psv && l.kind != GLinkKind.fcv)) continue;
      if (r.links[lid]?.status == LinkStatus.active) return l.entityId;
    }
    return null;
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
    var saturated = false;
    // tapes with an inlet regulator do not follow the valve: they set a
    // least pressure at the submain instead (MOT-14)
    final regs = _regulators(valveId);
    final followers = _followers(valveId);
    var byRegulators = false;
    if (head != null) {
      r = _zoneNetwork(valveId, head, detailed).solve();
    } else if (!detailed) {
      final h0 = 10.0;
      r = _zoneNetwork(valveId, h0, false).solve();
      final (pm, pn) = _meanPressures(valveId, r);
      head = followers ? h0 + (pn - pm) : 0.0;
      // fixed demands: the pressures upstream of the regulators move with
      // the valve head
      if (regs.isNotEmpty && h0 - _regulatorMargin(regs, r) > head) {
        head = h0 - _regulatorMargin(regs, r);
        byRegulators = true;
      }
      r = _zoneNetwork(valveId, head, false).solve();
    } else if (!followers) {
      head = 0.0;
      r = _zoneNetwork(valveId, head, true).solve();
    } else {
      // bisection so that mean emitter pressure equals nominal mean
      final probe = _zoneNetwork(valveId, 10, false).solve();
      final (_, pn) = _meanPressures(valveId, probe);
      var lo = 0.0, hi = math.max(pn * 3, 5.0);
      r = _zoneNetwork(valveId, hi, true).solve();
      var mean = _meanPressures(valveId, r).$1;
      var it = 0;
      double? held;
      String? holder;
      while (mean < pn && it < 20) {
        final next = _zoneNetwork(valveId, hi * 2, true).solve();
        final m = _meanPressures(valveId, next).$1;
        // the emitters no longer follow the valve: a PRV or an FCV of the
        // zone holds them (doubling on took the valve to 4.7·10⁷ m)
        if (m - mean < _saturationSlope * hi) {
          held = math.max(m, mean);
          holder = _holdingDevice(valveId, next);
          break;
        }
        hi *= 2;
        r = next;
        mean = m;
        it++;
      }
      if (held != null) {
        // the lowest valve head that gives the zone all it can get
        final target = held - 0.01;
        for (var i = 0; i < 40 && hi - lo >= 1e-3; i++) {
          final mid = (lo + hi) / 2;
          if (_meanPressures(valveId, _zoneNetwork(valveId, mid, true).solve()).$1 >= target) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        head = hi;
        r = _zoneNetwork(valveId, head, true).solve();
        saturated = true;
        warnings.add(['zone_pressure_unreachable', ?holder].join(':'));
      } else {
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
    }
    if (detailed && downstreamHead == null && valve.fixedDownstreamHeadM == null && regs.isNotEmpty) {
      // raise the valve until every regulator gets the pressure it needs
      final m0 = _regulatorMargin(regs, r);
      if (m0 < 0) {
        final base = head;
        var step = -m0, margin = m0;
        var top = _zoneNetwork(valveId, base + step, true).solve();
        for (var it = 0; it < 20; it++) {
          final m = _regulatorMargin(regs, top);
          if (m >= 0) break;
          // a regulator held by another device upstream: as far as it goes
          if (m - margin < _saturationSlope * step) break;
          margin = m;
          step *= 2;
          top = _zoneNetwork(valveId, base + step, true).solve();
        }
        var lo = base, hi = base + step;
        for (var i = 0; i < 40 && hi - lo >= 1e-3; i++) {
          final mid = (lo + hi) / 2;
          if (_regulatorMargin(regs, _zoneNetwork(valveId, mid, true).solve()) >= 0) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        head = hi;
        r = _zoneNetwork(valveId, head, true).solve();
        byRegulators = true;
      }
    }
    if (!r.converged) warnings.add('not_converged');

    // If the spread of pressures fits inside the allowable window but the
    // mean-targeted head leaves some outlets outside, centre the band.
    if (downstreamHead == null && valve.fixedDownstreamHeadM == null && !saturated && !byRegulators) {
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
    var nominalFlowSum = 0.0;
    for (final id in nodeIds) {
      final n = model.nodes[id]!;
      final nr = r.nodes[id];
      if (nr == null) continue;
      for (final e in n.emitters) {
        final p = nr.head - (n.elevation + e.offset);
        final q = detailed ? e.curve.flow(math.max(p, 0)) : e.curve.flow(e.nominalHead);
        totalFlow += q * e.count;
        if (e.index == -2) continue;
        outlets.add(
          OutletResult(
            entityId: e.entityId,
            index: e.index,
            p: n.p,
            elevation: n.elevation + e.offset,
            pressure: p,
            flow: q,
            nominalFlow: e.curve.flow(e.nominalHead),
            count: e.count,
            allowedMin: e.allowedMin,
            allowedMax: e.allowedMax,
            label: e.label,
          ),
        );
        // each flow relative to its own nominal flow: part-circle nozzles of
        // a matched-precipitation zone differ by design, not by pressure
        final qn = e.curve.flow(e.nominalHead);
        final rel = qn > 0 ? e.curve.flow(math.max(p, 0)) / qn : 1.0;
        for (var k = 0; k < e.count; k++) {
          flows.add(rel);
          nominalFlowSum += qn;
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
    final epp = _zoneEmittersPerPlant(valveId, outlets);
    // back to flows at the zone's mean nominal flow (the same numbers as
    // before when every emitter has the same nozzle)
    final qnMean = flows.isEmpty ? 0.0 : nominalFlowSum / flows.length;
    final uni = UniformityStats.compute([for (final f in flows) f * qnMean], manufacturerCv: cv, emittersPerPlant: epp);

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
        pipes.add(
          PipeSegmentResult(
            linkId: lid,
            entityId: l.entityId,
            segmentIndex: l.segmentIndex,
            a: l.a,
            b: l.b,
            elevationA: na.elevation,
            elevationB: nb.elevation,
            length: l.drawnLength,
            slopeLength: l.length,
            diameter: d,
            pipeSpecId: tape?.id ?? spec?.id,
            pipeName: tape?.name ?? spec?.name ?? '?',
            flow: lr.flow,
            velocity: v,
            headLoss: lr.headLoss,
            pressureStart: ha - na.elevation,
            pressureEnd: hb - nb.elevation,
            pressureRating: tape?.pressureRatingM ?? (spec == null ? 0 : _rating(spec)),
            zoneId: valveId,
            overVelocity: v > _vmax(l) + 1e-6,
          ),
        );
        if (v > _vmax(l) + 1e-6) warnings.add('velocity_exceeded:${l.entityId}');
        // a submain over a rise, its line of heads below the pipe
        if (l.usage == PipeUsage.zone && math.min(ha - na.elevation, hb - nb.elevation) < _belowAtmosphere) warnings.add('pressure_below_atmospheric:${l.entityId}');
        final rating = tape?.pressureRatingM ?? (spec == null ? 0.0 : _rating(spec));
        if (rating > 0 && math.max(ha - na.elevation, hb - nb.elevation) > rating) warnings.add('pressure_rating_exceeded:${l.entityId}');
      } else {
        devices.add(
          DeviceResult(
            entityId: l.entityId,
            linkId: lid,
            flow: lr.flow,
            headLoss: lr.headLoss,
            pumpHead: lr.pumpHead,
            upstreamPressure: ha - na.elevation,
            downstreamPressure: hb - nb.elevation,
            status: lr.status.name,
            elevation: na.elevation,
          ),
        );
        // a booster of the zone: the same range, suction and NPSH checks
        if (l.kind == GLinkKind.pump) _checkPump(l, lr, ha - na.elevation, na.elevation, warnings);
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

  /// [_emittersPerPlantFor] of each zone of [_eppModel], whose outlets stay
  /// where they are while the zone is sized and analysed again and again.
  final Map<String, int> _eppOfZone = {};
  NetworkModel? _eppModel;

  int _zoneEmittersPerPlant(String valveId, List<OutletResult> outlets) {
    if (!identical(_eppModel, model)) {
      _eppModel = model;
      _eppOfZone.clear();
    }
    final kept = _eppOfZone[valveId];
    assert(kept == null || kept == _emittersPerPlantFor(outlets), 'emitters per plant of $valveId kept after a change');
    return kept ?? (_eppOfZone[valveId] = _emittersPerPlantFor(outlets));
  }

  /// Emitters per plant for the EU: from an irrigated area containing most
  /// of the zone's outlets, else the project default.
  int _emittersPerPlantFor(List<OutletResult> outlets) {
    if (outlets.isEmpty) return math.max(1, params.emittersPerPlant);
    for (final a in project.entities.whereType<AreaEntity>()) {
      if (a.emittersPerPlant <= 0 || a.points.length < 3) continue;
      // an outlet beyond the outline's tolerance of the area's bounding box
      // is neither inside nor on it
      var x0 = double.infinity, y0 = double.infinity, x1 = double.negativeInfinity, y1 = double.negativeInfinity;
      for (final q in a.points) {
        x0 = math.min(x0, q.x);
        y0 = math.min(y0, q.y);
        x1 = math.max(x1, q.x);
        y1 = math.max(y1, q.y);
      }
      const margin = 0.02;
      var inside = 0;
      for (final o in outlets) {
        if (o.p.x < x0 - margin || o.p.x > x1 + margin || o.p.y < y0 - margin || o.p.y > y1 + margin) continue;
        // outlets on the outline count (strict point-in-polygon takes those
        // on a top or right edge for outside)
        if (pointInPolygon(o.p, a.points) || pointOnPolygonBoundary(o.p, a.points, tol: 0.01)) inside++;
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
        if (e.index == -2 || _regulated(e.entityId)) continue;
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
    valveId: valveId,
    zoneName: name,
    converged: false,
    totalFlow: 0,
    downstreamHead: 0,
    valveLoss: 0,
    requiredUpstreamHead: 0,
    minOutletPressure: 0,
    maxOutletPressure: 0,
    allowedMin: 0,
    allowedMax: 0,
    nominalPressure: 0,
    uniformity: UniformityStats.empty,
    pipes: const [],
    outlets: const [],
    devices: const [],
    warnings: warnings,
    valveElevation: 0,
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
    _networkInputs++;
  }

  double _crf() => capitalRecoveryFactor(params.interestRate, params.termYears);

  Map<String, double>? _sizingCosts;

  /// Price per metre for the sizing: the catalogue price, or an estimate
  /// for pipes without one ([Catalog.sizingPipeCosts]).
  double _pipeCost(PipeSpec s) => (_sizingCosts ??= catalog.sizingPipeCosts())[s.id] ?? s.costPerM;

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

  /// Greedy upsizing along the critical path until the window is met. When
  /// it cannot be met and the ground alone spreads the emitters beyond the
  /// window (no pipe, however large, gives them the same pressure), the
  /// assignment goes back to the one before the repair, with
  /// `zone_slope_exceeds_window` (it bought the largest pipes for nothing).
  ZoneResult _repairZone(String valveId, Map<String, List<GLink>> units, List<String> warnings, ZoneResult res) {
    if (res.withinWindow) return res;
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final start = res;
    final assigned = {for (final u in units.keys) u: _assigned[u]};
    final splits = {for (final u in units.keys) u: ?_pendingSplits[u]};
    var failed = false;
    for (var it = 0; it < 400 && !res.withinWindow; it++) {
      final target = res.minOutlet;
      if (target == null) break;
      final targetNode = _nodeOfOutlet(valveId, target);
      if (targetNode == null) break;
      // only the pipes after the last regulating device that holds the
      // pressure on the way change the pressure of the outlet
      final route = _path(zoneNode, targetNode, linkIds);
      final active = {
        for (final d in res.devices)
          if (d.status == LinkStatus.active.name) d.linkId,
      };
      var from = 0;
      for (var i = 0; i < route.length; i++) {
        final k = route[i].kind;
        if ((k == GLinkKind.prv || k == GLinkKind.psv || k == GLinkKind.fcv) && active.contains(route[i].id)) from = i + 1;
      }
      final path = route.sublist(from).toSet();
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
        final cost = (_pipeCost(next) - _pipeCost(cur)) * _unitLength(e.value);
        final score = red / (math.max(cost, 1e-6));
        if (score > bestScore) {
          bestScore = score;
          bestUnit = e.key;
          bestSpec = next;
        }
      }
      if (bestUnit == null) {
        failed = true;
        break;
      }
      _assign(bestUnit, bestSpec!);
      _pendingSplits.remove(bestUnit);
      res = analyzeZone(valveId, detailed: false);
    }
    if (res.withinWindow) return res;
    if (_staticSpread(valveId) > res.allowedMax - res.allowedMin + 1e-6) {
      for (final e in assigned.entries) {
        final id = e.value;
        if (id == null) {
          _assigned.remove(e.key);
        } else {
          _assigned[e.key] = id;
        }
      }
      _pendingSplits.addAll(splits);
      _networkInputs++;
      warnings.add('zone_slope_exceeds_window');
      return start;
    }
    if (failed) warnings.add('cannot_meet_pressure_window');
    return res;
  }

  /// Spread (m) of the elevations of the emitters of zone [valveId], risers
  /// included: the spread of their pressures with no friction at all.
  double _staticSpread(String valveId) {
    var lo = double.infinity, hi = -double.infinity;
    for (final id in model.zoneNodes[valveId] ?? const <String>{}) {
      final n = model.nodes[id]!;
      for (final e in n.emitters) {
        if (e.index == -2) continue;
        final z = n.elevation + e.offset;
        lo = math.min(lo, z);
        hi = math.max(hi, z);
      }
    }
    return hi > lo ? hi - lo : 0;
  }

  /// Critical emitter nodes of a zone for the LP: per lateral its end, its
  /// highest and its lowest node; every single outlet (capped).
  Set<String> _criticalNodes(String valveId, Map<String, int> depth) {
    final byEntity = <String, List<String>>{};
    for (final id in model.zoneNodes[valveId] ?? <String>{}) {
      final n = model.nodes[id]!;
      for (final e in n.emitters) {
        // behind a regulator the pressure is the regulator's, whatever the
        // sizes: the regulator's own need at the submain stands for them
        if (e.index == -2 || _regulated(e.entityId)) continue;
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

  /// Message code of an LP that gave no sizing: infeasible, or stopped at
  /// its iteration limit (which says nothing about feasibility).
  static String _lpFailure(LpAssignment a) => a.message == LpStatus.iterationLimit.name ? 'lp_iteration_limit' : 'lp_infeasible';

  /// Builds and solves the zone LP with the current assignment for flows.
  LpAssignment _lpZone(String valveId, Map<String, List<GLink>> units, {Set<String> extraNodes = const {}}) {
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final r = _zoneNetwork(valveId, 10, false).solve();
    double q(GLink l) => (r.links[l.id]?.flow ?? 0).abs();
    final (parent, _, depth) = _bfs([zoneNode], linkIds);
    final unitOf = <String, String>{
      for (final e in units.entries)
        for (final l in e.value) l.id: e.key,
    };
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
    final energy = params.tradeCapitalVsRunning
        ? annualEnergyCost(flow: total, head: 1, hoursPerYear: params.zoneHoursPerYear, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency)
        : 0.0;
    final zRoot = model.nodes[zoneNode]!.elevation;
    final regNeed = <String, double>{};
    for (final (node, need) in _regulators(valveId)) {
      regNeed[node] = math.max(regNeed[node] ?? need, need);
    }
    final nodes = {..._criticalNodes(valveId, depth), ...extraNodes, ...regNeed.keys};
    final constraints = <LpHeadConstraint>[];
    for (final k in nodes) {
      final n = model.nodes[k];
      if (n == null || !parent.containsKey(k)) continue;
      var lo = regNeed[k] ?? -double.infinity, hi = double.infinity, off = 0.0, nomSum = 0.0, nomW = 0.0;
      for (final e in n.emitters) {
        if (e.index == -2 || _regulated(e.entityId)) continue;
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
    return lpSize(
      LpSizingInput(
        units: units.keys.toList(),
        candidates: cands,
        unitLength: lengths,
        maxSizes: maxSizes,
        headVars: [LpHeadVar(energyPerMetre: energy, name: 'zone')],
        constraints: constraints,
        crf: _crf(),
        tradeCapital: params.tradeCapitalVsRunning,
        pipeCost: _pipeCost,
      ),
    );
  }

  ZoneResult sizeZone(String valveId) {
    final valve = project.byId(valveId) as ControlValveEntity?;
    if (valve == null || !model.valveNodes.containsKey(valveId)) return analyzeZone(valveId);
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final units = _units(linkIds);
    if (units.isEmpty) return analyzeZone(valveId);
    final (_, zoneNode) = model.valveNodes[valveId]!;
    final warnings = <String>[];
    // Passes: a pipe rated below the pressure it ends up carrying (water
    // temperature derating included) leaves the candidates of its unit and
    // the zone is sized again.
    for (var pass = 0; ; pass++) {
      warnings.clear();
      final res = _sizeZonePass(valve, units, warnings);
      if (pass >= 2 || !_learnRatings(res.pipes, units)) break;
    }

    // 4. rationalize: downstream never larger than upstream (tree order from valve)
    _rationalize(zoneNode, linkIds, units);

    // 5. write back and final detailed analysis
    _writeBack(units);
    final finalRes = analyzeZone(valveId, detailed: true);
    return finalRes.copyWith(warnings: {...warnings, ...finalRes.warnings}.toList());
  }

  /// Steps 1–3 of [sizeZone]: velocity sizing, LP sizing with its
  /// pressure-window rounds (or the greedy method), repair and, for the
  /// greedy method, the economic trade-off; returns the last analysis.
  ZoneResult _sizeZonePass(ControlValveEntity valve, Map<String, List<GLink>> units, List<String> warnings) {
    final valveId = valve.id;
    final linkIds = model.zoneLinks[valveId] ?? <String>{};
    final (_, zoneNode) = model.valveNodes[valveId]!;

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
        _note('${_lpFailure(a)}:${valve.zoneName}');
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
          final capital = (_pipeCost(next) - _pipeCost(cur)) * _unitLength(e.value) * crf;
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

    return res;
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
    // BFS from root tracking parent link (and the node each link leads to,
    // which a search of `parent` per link made quadratic on big zones)
    final parent = <String, GLink?>{root: null};
    final downNode = <GLink, String>{};
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
          downNode[l] = o;
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
        final upNode = downNode[l]!;
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
    _networkInputs++;
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
    _networkInputs++;
    model = NetworkBuilder(project).build();
    return count;
  }

  // ------------------------------------------------------------ mainline

  /// The mainline of a flow that opens the demands of [valveDemand] and
  /// lists [listed] (its zone valves, pivots and valve-in-head stations, see
  /// `valve_in_head.dart`). With [nominal] (the analyses that size the
  /// pipes, whose calculated supplies stand at zero pressure) the heads of
  /// the scheduled stations draw their nominal flow, as a zone valve draws
  /// the flow of its zone.
  HydraulicNetwork _mainlineNetwork(Map<String, double> supplyPressure, Map<String, double> valveDemand, Set<String> listed, {bool nominal = false}) {
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
      // mainline outlets (valve-in-head) as emitters, each in the flows that
      // run its station; a head that is off keeps its place with no emitter
      // running, so every flow has the same nodes and links
      bool fixed(EmitterRef e) => nominal && vih.headScheduled(e.entityId);
      _attachEmitters(net, h, n, true, count: (e) => !vih.headRuns(e.entityId, listed) || fixed(e) ? 0 : e.count);
      for (final e in n.emitters) {
        if (fixed(e) && vih.headRuns(e.entityId, listed)) h.demand += e.nominalFlow;
      }
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

  List<WaterSupplyEntity> get _supplies =>
      project.entities.whereType<WaterSupplyEntity>().where((s) => model.supplyNodes.containsKey(s.id) && model.mainlineNodes.contains(model.supplyNodes[s.id])).toList();

  /// A running surface pump whose inlet pressure is below minus the
  /// practical suction lift (atmospheric head − vapour pressure − NPSH
  /// allowance): it would cavitate or lose its prime.
  bool _suctionLiftExceeded(GLink l, LinkResult lr, double inletPressure, double elevation) {
    if (l.kind != GLinkKind.pump || lr.flow <= 0) return false;
    final spec = catalog.pump(l.pumpSpecId);
    if (spec == null || spec.submersible) return false;
    return -inletPressure > maxSuctionLift(elevation) + 1e-6;
  }

  /// Pressure head (m) below which a pipe runs under vacuum (a margin below
  /// the atmosphere for the rounding of a line at zero pressure).
  static const _belowAtmosphere = -0.1;

  /// Whether zone valve [vid] holds its downstream pressure (a set outlet
  /// pressure, or a pressure reducing model).
  bool _regulates(String vid) {
    final v = project.byId(vid);
    if (v is! ControlValveEntity) return true;
    return v.fixedDownstreamHeadM != null || catalog.valve(v.valveSpecId)?.kind == ValveKind.prv;
  }

  NetworkModel? _suctionModel;
  Set<String> _suctionOf = const {};

  /// Mainline pipes on the suction side of a pump: from its inlet back to a
  /// supply through no other device. Below the atmosphere there is the
  /// suction lift of a surface pump, checked as such (a submersible one
  /// stands at the water level).
  Set<String> get _suctionLinks {
    if (identical(_suctionModel, model)) return _suctionOf;
    _suctionModel = model;
    final out = <String>{};
    for (final lid in model.mainlineLinks) {
      final l = model.linkById(lid)!;
      if (l.kind != GLinkKind.pump) continue;
      final seen = <String>{l.from};
      final queue = [l.from];
      final pipes = <String>{};
      var supply = false;
      for (var i = 0; i < queue.length; i++) {
        final n = model.nodes[queue[i]]!;
        if (n.isSupply) {
          supply = true;
          continue;
        }
        for (final x in n.links) {
          if (x.kind != GLinkKind.pipe || !model.mainlineLinks.contains(x.id)) continue;
          pipes.add(x.id);
          final o = x.other(n.id);
          if (seen.add(o)) queue.add(o);
        }
      }
      if (supply) out.addAll(pipes);
    }
    return _suctionOf = out;
  }

  /// Elevation of the inlet of device link [l] (upstream node [up]): a
  /// surface pump drawn on its water supply stands on the ground there,
  /// above the water it lifts (the supply node lies at the water level, so
  /// its suction lift and NPSH were never checked); else the node.
  double _inletElevation(GLink l, GNode up) {
    if (l.kind == GLinkKind.pump && up.isSupply && !(catalog.pump(l.pumpSpecId)?.submersible ?? false)) return up.ground;
    return up.elevation;
  }

  /// Operating range, suction lift and NPSH of pump link [l] in solution
  /// [lr], with the pressure head [inletPressure] at its inlet at
  /// [elevation]. The range of the catalogue scales with the speed the pump
  /// turns at (a drive, or a curve of other mains): Q ∝ n.
  void _checkPump(GLink l, LinkResult lr, double inletPressure, double elevation, List<String> warnings) {
    final spec = catalog.pump(l.pumpSpecId);
    final speed = _vfdSpeed[l.entityId] ?? l.speedRatio;
    if (spec != null) {
      if (lr.flow > spec.maxFlow * speed + 1e-9 || lr.flow <= 0) {
        warnings.add('pump_out_of_range:${l.entityId}');
      } else if (spec.minFlow > 0 && lr.flow < spec.minFlow * speed - 1e-9) {
        warnings.add('pump_below_min_flow:${l.entityId}');
      }
    }
    if (_suctionLiftExceeded(l, lr, inletPressure, elevation)) warnings.add('pump_suction_lift:${l.entityId}');
    // NPSH available against the required one (curve of the catalogue)
    final npshr = spec?.npshrAt(lr.flow, speed: speed);
    if (npshr != null && lr.flow > 0 && npshAvailable(inletPressure: inletPressure, elevation: elevation, tempC: params.waterTempC) < npshr + npshMargin) {
      warnings.add('pump_npsh:${l.entityId}');
    }
    // 1.6.0 MOD: the shaft power at the duty against the motor
    final motor = spec == null ? null : pumpMotorLoad(spec, lr.flow, lr.pumpHead, speed: speed);
    if (motor != null) warnings.add('$motor:${l.entityId}');
  }

  SystemFlowResult analyzeSystemFlow(SystemFlow sf, {double totalDuration = 0}) {
    final warnings = <String>[];
    final supplies = _supplies;
    if (supplies.isEmpty) {
      return SystemFlowResult(
        flowId: sf.id,
        name: sf.name,
        converged: false,
        supplies: const [],
        valves: const [],
        pipes: const [],
        devices: const [],
        warnings: const ['no_water_supply'],
        totalFlow: 0,
        durationHours: sf.durationHours,
      );
    }
    final demand = <String, double>{};
    final required = <String, double>{};
    for (final vid in sf.valveIds) {
      if (_demandNode(vid) == null) continue;
      final (q, h) = _demandOf(vid);
      demand[vid] = q;
      required[vid] = h;
    }
    final listed = sf.valveIds;
    final needs = _headNeeds(listed);
    final pressure = <String, double>{for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM};
    _vfdSpeed.clear();
    _tuneVfd(() => _mainlineNetwork(pressure, demand, listed), warnings);
    var r = _mainlineNetwork(pressure, demand, listed).solve();
    final calc = supplies.where((s) => s.calculatePressure).toList();
    double deficit(NetworkResult r) {
      var d = -double.infinity;
      for (final vid in demand.keys) {
        final nr = r.nodes[_demandNode(vid) ?? ''];
        if (nr == null) continue;
        d = math.max(d, required[vid]! - nr.pressure);
      }
      for (final (node, need) in needs) {
        final nr = r.nodes[node];
        if (nr != null) d = math.max(d, need - nr.pressure);
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
      // a drive set below what the valves need: the supply would have to
      // make up the difference
      if (requiredExtra > 0.01) {
        for (final (_, pump) in _vfdPumps) {
          warnings.add('vfd_target_low:${pump.id}');
        }
      }
      if (requiredExtra > 0) {
        for (final s in calc) {
          pressure[s.id] = requiredExtra;
        }
        r = _mainlineNetwork(pressure, demand, listed).solve();
        requiredExtra = _raiseForHeads(requiredExtra, needs.isNotEmpty, () => deficit(r), (x) {
          for (final s in calc) {
            pressure[s.id] = x;
          }
          r = _mainlineNetwork(pressure, demand, listed).solve();
        });
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
      final duty = ValveDuty(
        valveId: vid,
        zoneName: zoneName,
        flow: demand[vid]!,
        availableHead: nr.pressure,
        requiredHead: required[vid]!,
        p: model.nodes[nm]!.p,
        regulates: pivot != null || _regulates(vid),
      );
      valves.add(duty);
      if (pivot != null) pivot.availableHead = nr.pressure;
      if (nr.pressure < required[vid]! - 0.01) warnings.add(pivot != null ? 'pivot_pressure_deficit:$vid' : 'valve_pressure_deficit:$vid');
      // a valve that does not regulate passes the surplus on: the zone then
      // runs above its design pressure and flow, and so do the line and the
      // pumps (the analysis of the zone takes a valve that throttles)
      if (duty.excessive) warnings.add('valve_pressure_excess:$vid');
    }
    final heads = _vihDuties(r, listed, warnings);
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
      duties.add(
        SupplyDuty(
          supplyId: s.id,
          name: s.name.isEmpty ? _label('name.supply') : s.name,
          flow: q,
          head: avail,
          requiredHead: req,
          elevation: model.nodes[nid]!.elevation,
          calculated: s.calculatePressure,
          designHead: s.designHeadM,
          maxHead: s.maxHeadM,
          designFlow: s.designFlow,
          maxFlow: s.maxFlow,
        ),
      );
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
        pipes.add(
          PipeSegmentResult(
            linkId: lid,
            entityId: l.entityId,
            segmentIndex: l.segmentIndex,
            a: l.a,
            b: l.b,
            elevationA: na.elevation,
            elevationB: nb.elevation,
            length: l.drawnLength,
            slopeLength: l.length,
            diameter: d,
            pipeSpecId: spec?.id,
            pipeName: spec?.name ?? '?',
            flow: lr.flow,
            velocity: v,
            headLoss: lr.headLoss,
            pressureStart: ha - na.elevation,
            pressureEnd: hb - nb.elevation,
            pressureRating: spec == null ? 0 : _rating(spec),
            overVelocity: v > _vmax(l) + 1e-6,
          ),
        );
        if (v > _vmax(l) + 1e-6) warnings.add('velocity_exceeded:${l.entityId}');
        if (spec != null && spec.pressureRatingM > 0 && math.max(ha - na.elevation, hb - nb.elevation) > _rating(spec)) warnings.add('pressure_rating_exceeded:${l.entityId}');
        // a mainline over a hill: siphon, air coming in, a thin wall
        // collapsing; the suction pipe of a surface pump has its own check
        if (math.min(ha - na.elevation, hb - nb.elevation) < _belowAtmosphere && !_suctionLinks.contains(lid)) warnings.add('pressure_below_atmospheric:${l.entityId}');
      } else {
        final inletZ = _inletElevation(l, na);
        devices.add(
          DeviceResult(
            entityId: l.entityId,
            linkId: lid,
            flow: lr.flow,
            headLoss: lr.headLoss,
            pumpHead: lr.pumpHead,
            upstreamPressure: ha - inletZ,
            downstreamPressure: hb - nb.elevation,
            status: lr.status.name,
            elevation: inletZ,
            speedRatio: l.kind == GLinkKind.pump ? (_vfdSpeed[l.entityId] ?? l.speedRatio) : 1,
          ),
        );
        if (l.kind == GLinkKind.pump) _checkPump(l, lr, ha - inletZ, inletZ, warnings);
      }
    }
    // energy: supplies with calculated pressure and pumps
    final share = totalDuration > 0 ? sf.durationHours / totalDuration : 1.0;
    final hours = params.hoursPerYear * share;
    var energy = 0.0;
    for (final d in duties) {
      if (d.calculated && d.requiredHead > 0) {
        energy += annualEnergyCost(flow: d.flow, head: d.requiredHead, hoursPerYear: hours, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency);
      }
    }
    for (final d in devices) {
      if (d.pumpHead > 0) {
        final l = model.linkById(d.linkId)!;
        final entity = project.byId(l.entityId);
        energy += annualEnergyCost(
          flow: d.flow,
          head: d.pumpHead,
          hoursPerYear: hours,
          costPerKwh: params.powerCostPerKwh,
          // the pump on its curve, and its motor and drive (MOT-15)
          pumpEfficiency: wireToWaterEfficiency(catalog.pump(l.pumpSpecId), entity is PumpEntity ? entity : null, d.flow, speed: d.speedRatio, fallback: params.pumpEfficiency),
        );
      }
    }
    // the pumps in series from each supply to the valve or head that sets
    // its pressure: what a new pump at the supply must add besides them
    // (the pump selection summed every pump of the flow, parallel ones and
    // boosters of other branches too)
    final worstNode = _worstNodeOf(valves, heads);
    if (worstNode != null) {
      final pumpHead = {
        for (final d in devices)
          if (d.pumpHead > 0) d.linkId: d.pumpHead,
      };
      for (final duty in duties) {
        final from = model.supplyNodes[duty.supplyId];
        final path = from == null ? const <GLink>[] : (from == worstNode ? const <GLink>[] : _path(from, worstNode, model.mainlineLinks));
        if (path.isNotEmpty || from == worstNode) duty.pumpBoost = path.fold<double>(0, (s, l) => s + (pumpHead[l.id] ?? 0));
      }
    }
    // the speeds belong to this flow; sizing analyses run the pumps as drawn
    _vfdSpeed.clear();
    return SystemFlowResult(
      flowId: sf.id,
      name: sf.name,
      converged: r.converged,
      supplies: duties,
      valves: valves,
      pipes: pipes,
      devices: devices,
      warnings: warnings.toSet().toList(),
      totalFlow: total,
      durationHours: sf.durationHours,
      annualEnergyCost: energy,
      heads: heads,
    );
  }

  /// The mainline network of system flow [sf] as [analyzeSystemFlow] solves
  /// it, with the final supply pressures (a calculated supply at the head the
  /// valves need) and the drive speeds of the flow, and its steady solution;
  /// null without a water supply. For the transient, on-demand and
  /// calibration analyses, which work on a copy of the network.
  (HydraulicNetwork, NetworkResult, Map<String, double> demand)? mainlineNetworkFor(SystemFlow sf) {
    final supplies = _supplies;
    if (supplies.isEmpty) return null;
    final demand = <String, double>{};
    final required = <String, double>{};
    for (final vid in sf.valveIds) {
      if (_demandNode(vid) == null) continue;
      final (q, h) = _demandOf(vid);
      demand[vid] = q;
      required[vid] = h;
    }
    final listed = sf.valveIds;
    final needs = _headNeeds(listed);
    final pressure = <String, double>{for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM};
    _vfdSpeed.clear();
    _tuneVfd(() => _mainlineNetwork(pressure, demand, listed), []);
    var net = _mainlineNetwork(pressure, demand, listed);
    var r = net.solve();
    if (supplies.any((s) => s.calculatePressure)) {
      double deficit() {
        var extra = -double.infinity;
        for (final vid in demand.keys) {
          final nr = r.nodes[_demandNode(vid) ?? ''];
          if (nr != null) extra = math.max(extra, required[vid]! - nr.pressure);
        }
        for (final (node, need) in needs) {
          final nr = r.nodes[node];
          if (nr != null) extra = math.max(extra, need - nr.pressure);
        }
        return extra;
      }

      void solveAt(double extra) {
        for (final s in supplies) {
          if (s.calculatePressure) pressure[s.id] = extra;
        }
        net = _mainlineNetwork(pressure, demand, listed);
        r = net.solve();
      }

      final extra = deficit();
      if (extra.isFinite && extra > 0) {
        solveAt(extra);
        _raiseForHeads(extra, needs.isNotEmpty, deficit, solveAt);
      }
    }
    _vfdSpeed.clear();
    return (net, r, demand);
  }

  /// The heads of valve-in-head stations draw more as the supply pressure
  /// rises, and the losses grow with their flow: from the pressure [extra]
  /// of the calculated supplies, which covered the needs at the flows
  /// before, raise it until the worst need is met ([deficit] of the latest
  /// solution, [solve] sets the supplies to a pressure and solves). Nothing
  /// changes without [heads] (zone valves and pivots draw fixed flows).
  double _raiseForHeads(double extra, bool heads, double Function() deficit, void Function(double extra) solve) {
    if (!heads) return extra;
    for (var it = 0; it < 30; it++) {
      final d = deficit();
      if (!d.isFinite || d.abs() < 1e-3) break;
      extra = math.max(0.0, extra + d);
      solve(extra);
      if (extra == 0) break;
    }
    return extra;
  }

  /// Mainline node fed by a zone valve or a pivot (public for the analyses
  /// built on [mainlineNetworkFor]).
  String? demandNodeOf(String id) => _demandNode(id);

  /// Mainline nodes of the heads of the scheduled valve-in-head stations
  /// that run in [sf] (for the analyses built on [mainlineNetworkFor] that
  /// close or follow them with their flow), with what each needs there.
  Map<String, double> scheduledHeadNodes(SystemFlow sf) => {for (final (n, need) in _headNeeds(sf.valveIds)) n: need};

  /// Mainline node of every valve-in-head head (outlet id → node id).
  Map<String, String> get vihHeadNodes => {for (final e in _heads.entries) e.key: e.value.$1};

  List<SystemFlow> effectiveSystemFlows() {
    if (project.systemFlows.isNotEmpty) return project.systemFlows;
    return [
      SystemFlow(id: 'auto', name: _label('name.allZones'), valveIds: {...model.valveNodes.keys, ...model.pivotNodes.keys}, durationHours: 1),
    ];
  }

  /// Builds and solves the mainline LP over all system flows.
  LpAssignment _lpMainline(Map<String, List<GLink>> units, List<SystemFlow> flows, double totalDur) {
    final supplies = _supplies;
    final supplyNodes = {for (final s in supplies) model.supplyNodes[s.id]!: s};
    final (parent, source, _) = _bfs(supplyNodes.keys, model.mainlineLinks);
    final unitOf = <String, String>{
      for (final e in units.entries)
        for (final l in e.value) l.id: e.key,
    };
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
      flowResults.add(_mainlineNetwork({for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM}, demand, f.valveIds, nominal: true).solve());
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
        final energy = s.calculatePressure && params.tradeCapitalVsRunning
            ? annualEnergyCost(flow: math.max(q, 0), head: 1, hoursPerYear: params.hoursPerYear * share, costPerKwh: params.powerCostPerKwh, pumpEfficiency: params.pumpEfficiency)
            : 0.0;
        headIndex['${s.id}|$fi'] = headVars.length;
        headVars.add(
          LpHeadVar(
            energyPerMetre: energy,
            fixedValue: s.calculatePressure ? null : s.designHeadM,
            maxValue: s.calculatePressure && s.maxHeadM > 0 ? s.maxHeadM : null,
            name: '${s.name}|${flows[fi].name}',
          ),
        );
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
        constraints.add(
          LpHeadConstraint(
            headVar: headIndex['${s.id}|$fi']!,
            lossByUnitSpec: byUnit,
            constant: constant,
            minPressure: minPressure + dz,
            maxPressure: maxPressure != null ? maxPressure + dz : null,
            tag: node,
          ),
        );
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
      // mainline outlets (valve-in-head) keep their pressure window in the
      // flows they run in; the heads of a scheduled station at least their
      // nominal pressure, the need the analysis then sets the supply for
      final listed = flows[fi].valveIds;
      for (final id in model.mainlineNodes) {
        final n = model.nodes[id]!;
        if (n.emitters.isEmpty) continue;
        var lo = -double.infinity, hi = double.infinity, off = 0.0;
        for (final e in n.emitters) {
          if (!vih.headRuns(e.entityId, listed)) continue;
          lo = math.max(lo, vih.headScheduled(e.entityId) ? math.max(e.allowedMin, e.nominalHead) : e.allowedMin);
          hi = math.min(hi, e.allowedMax);
          off = math.max(off, e.offset);
        }
        if (lo.isFinite) constrain(id, lo, hi.isFinite ? hi : null, off);
      }
    }
    return lpSize(
      LpSizingInput(
        units: units.keys.toList(),
        candidates: cands,
        unitLength: lengths,
        maxSizes: maxSizes,
        headVars: headVars,
        constraints: constraints,
        crf: _crf(),
        tradeCapital: params.tradeCapitalVsRunning,
        pipeCost: _pipeCost,
      ),
    );
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
    // Passes: a pipe rated below the pressure it ends up carrying (water
    // temperature derating included) leaves the candidates of its unit and
    // the mainline is sized again.
    for (var pass = 0; ; pass++) {
      final res = _sizeMainlinePass(units, flows, totalDur, supplyNodes, analyzeAll);
      if (pass >= 2 || !_learnRatings([for (final f in res) ...f.pipes], units)) break;
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

  /// Steps 1–3 of [sizeMainline]: velocity sizing over every system flow, LP
  /// sizing (or the greedy method), the deficit loop of fixed-pressure
  /// supplies and, for the greedy method, the economic trade-off; returns the
  /// last analysis of every flow.
  List<SystemFlowResult> _sizeMainlinePass(Map<String, List<GLink>> units, List<SystemFlow> flows, double totalDur, Set<String> supplyNodes, List<SystemFlowResult> Function() analyzeAll) {
    final supplies = _supplies;
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
        final r = _mainlineNetwork({for (final s in supplies) s.id: s.calculatePressure ? 0.0 : s.designHeadM}, demand, f.valveIds, nominal: true).solve();
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
      final looped = pipeLinks >= model.mainlineNodes.length && model.mainlineNodes.isNotEmpty;
      if (looped) _note('lp_loops_approx');
      final a = _lpMainline(units, flows, totalDur);
      if (a.feasible) {
        _applyAssignment(a);
        lpDone = true;
        // in a loop the sizes decide how the flow splits: size again with
        // the flows of the new sizes until the choice settles (the gradient
        // idea of Alperovits & Shamir 1977, Water Resources Research 13(6),
        // with this LP at every step)
        for (var it = 0; looped && it < 4; it++) {
          final before = {for (final k in units.keys) k: _assigned[k]};
          final next = _lpMainline(units, flows, totalDur);
          if (!next.feasible) break;
          _applyAssignment(next);
          if (units.keys.every((k) => _assigned[k] == before[k])) break;
        }
      } else {
        _note('${_lpFailure(a)}:${_label('menu.mainline')}');
      }
    }
    // 2. deficit loop for fixed-pressure supplies
    var res = analyzeAll();
    final anyFixed = supplies.any((s) => !s.calculatePressure);
    if (anyFixed) {
      for (var it = 0; it < 400; it++) {
        SystemFlowResult? worst;
        String? nm;
        var most = 0.0;
        for (final f in res) {
          for (final v in f.valves) {
            if (v.deficit > 0.01 && (nm == null || v.deficit > most)) {
              worst = f;
              nm = _demandNode(v.valveId);
              most = v.deficit;
            }
          }
          // the critical heads of the scheduled valve-in-head stations too
          for (final h in f.heads) {
            if (h.scheduled && h.deficit > 0.01 && (nm == null || h.deficit > most)) {
              worst = f;
              nm = _heads[h.criticalId]?.$1;
              most = h.deficit;
            }
          }
        }
        if (worst == null || nm == null) break;
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
          final cost = (_pipeCost(next) - _pipeCost(cur)) * _unitLength(e.value);
          final score = red / math.max(cost, 1e-6);
          if (score > bestScore) {
            bestScore = score;
            bestUnit = e.key;
            bestSpec = next;
          }
        }
        if (bestUnit == null) {
          _note('mainline_cannot_meet_pressure');
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
            final nm = _worstNode(f);
            if (nm == null) continue;
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
          final capital = (_pipeCost(next) - _pipeCost(cur)) * _unitLength(e.value) * crf;
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
    return res;
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
    yield (
      stage: DesignStage.surge,
      zoneId: null,
      zoneIndex: 0,
      run: () {
        checkSurge();
        analyzeMachines();
      },
    );
    yield (stage: DesignStage.bom, zoneId: null, zoneIndex: 0, run: designWiring);
    // 1.6.0 AGB: pump house electrics, solar pumping, water quality, two-wire
    yield (stage: DesignStage.bom, zoneId: null, zoneIndex: 0, run: designMachinesAndWater);
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
  Future<DesignResults> designAllAsync({bool sizeZones = true, bool sizeMain = true, void Function(DesignProgress progress)? onProgress, Future<void> Function()? yieldControl}) async {
    final pause = yieldControl ?? () => Future<void>.delayed(Duration.zero);
    final zoneCount = model.valveNodes.length;
    // zones + mainline + flushing + surge + wiring + BOM; a split re-analysis
    // adds one step per zone plus the split and the system-flow steps.
    var total = zoneCount + 5;
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
        var target = params.flushingMinEndHeadM;
        var end = minEnd(r);
        while (end < target && it < 12) {
          final next = _zoneNetwork(vid, hi * 2, true).solve();
          final e = minEnd(next);
          // a PRV or an FCV of the zone holds the ends below the target:
          // the lowest head that gives them all they can get
          if (e - end < _saturationSlope * hi) {
            target = math.max(e, end) - 0.01;
            break;
          }
          hi *= 2;
          r = next;
          end = e;
          it++;
        }
        for (var i = 0; i < 30; i++) {
          final mid = (lo + hi) / 2;
          r = _zoneNetwork(vid, mid, true).solve();
          if (minEnd(r) >= target) {
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
        results.flushing.add(
          FlushingResult(
            valveId: vid,
            zoneName: valve.zoneName,
            flow: flow,
            requiredDownstreamHead: head,
            requiredUpstreamHead: head + valveLoss + (zn.elevation - mn.elevation),
            tapeCount: tapeCount,
            minEndHead: minEnd(r),
            maxVelocity: vmax,
            flushingVelocity: params.flushingVelocity,
            converged: r.converged,
          ),
        );
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

  /// Surge screening of every pipe entity against its pressure class
  /// (Joukowsky / Michaud; the transient study simulates the line): the
  /// pressure a closure adds at a point x metres along the water path from
  /// the supply (from the valve in a zone), the envelope of a closure in T
  /// seconds, min(a·ΔV/g, 2·x·ΔV/(g·T)) (Michaud 1878: the surge grows from
  /// nothing at the reflecting supply), over the static pressure there; the
  /// worst point of the entity counts. The critical time 2L/a takes the
  /// path to the far end of the entity: the length of one entity of a line
  /// drawn in pieces made the closure look slow and the surge half of what
  /// it is.
  List<SurgeResult> checkSurge() {
    results.surge.clear();
    if (!params.checkSurge) return results.surge;
    // every analysed segment of every entity, with its context, in one pass
    // (a search of every segment per entity was quadratic)
    final segs = <String, List<(PipeSegmentResult, String)>>{};
    for (final z in results.zones.values) {
      for (final p in z.pipes) {
        (segs[p.entityId] ??= []).add((p, z.zoneName));
      }
    }
    for (final f in results.systemFlows) {
      for (final p in f.pipes) {
        (segs[p.entityId] ??= []).add((p, f.name));
      }
    }
    final along = _distancesAlongWater();
    final closure = params.valveClosureTimeS;
    for (final entry in segs.entries) {
      // the fastest flow the entity carries: the velocity a closure stops
      var (p, ctx) = entry.value.first;
      for (final (q, c) in entry.value) {
        if (q.velocity > p.velocity) (p, ctx) = (q, c);
      }
      final spec = catalog.pipe(p.pipeSpecId);
      if (spec == null) continue; // tapes: not checked
      final e = project.byId(entry.key);
      final own = e is PolyEntity ? e.length : p.length;
      final a = waveCelerity(diameter: spec.innerDiameter, wallThickness: math.max(spec.wallThicknessMm, 0.5) / 1000, material: spec.material);
      final full = joukowskySurgeHead(celerity: a, velocityChange: p.velocity);
      double surgeAt(double x) => closure <= 0 ? full : math.min(full, 2 * x * p.velocity / (gravity * closure));
      var worstTotal = double.negativeInfinity, staticAt = 0.0, surge = 0.0, far = 0.0;
      for (final (q, _) in entry.value) {
        final l = model.linkById(q.linkId);
        for (final (pressure, node) in [(q.pressureStart, l?.from), (q.pressureEnd, l?.to)]) {
          // off the trees (a loop): the pipe itself, as before
          final x = along[node] ?? own;
          far = math.max(far, x);
          final s = surgeAt(x);
          if (pressure + s > worstTotal) {
            worstTotal = pressure + s;
            staticAt = pressure;
            surge = s;
          }
        }
      }
      final length = far > 0 ? far : own;
      final sr = SurgeResult(
        pathLength: length,
        entityId: entry.key,
        context: ctx,
        pipeName: spec.name,
        velocity: p.velocity,
        celerity: a,
        surgeHead: surge,
        maxStaticHead: staticAt,
        rating: _rating(spec),
        closureTime: closure,
        criticalTime: criticalClosureTime(length: math.max(length, 1), celerity: a),
      );
      results.surge.add(sr);
      if (sr.exceeds) results.messages.add('surge_rating_exceeded:${entry.key}');
    }
    return results.surge;
  }

  /// Distance (m) of every node along the water path from its source: from
  /// the supplies along the mainline, from its valve in a zone
  /// (breadth-first trees, lengths summed along them).
  Map<String, double> _distancesAlongWater() {
    final out = <String, double>{};
    void walk(Iterable<String> roots, Set<String> allowed) {
      final (parent, _, depth) = _bfs(roots, allowed);
      final order = parent.keys.toList()..sort((x, y) => depth[x]!.compareTo(depth[y]!));
      for (final id in order) {
        final l = parent[id];
        out[id] = l == null ? 0 : out[l.other(id)]! + l.length;
      }
    }

    walk(model.supplyNodes.values, model.mainlineLinks);
    for (final v in model.valveNodes.entries) {
      walk([v.value.$2], model.zoneLinks[v.key] ?? const <String>{});
    }
    return out;
  }

  // ------------------------------------------------------------ machines

  /// Sprinkler package, timer chart and, when configured, corner arm,
  /// variable-rate prescription and electrical design of every machine, its
  /// pivot point at the pressure the mainline gives it.
  Map<String, MechanisedResult> analyzeMachines() {
    results.mechanised.clear();
    for (final p in project.entities.whereType<PivotEntity>()) {
      if (!model.pivotNodes.containsKey(p.id)) continue;
      final available = results.pivots[p.id]?.availableHead ?? 0;
      final m = analyzeMechanised(project, p, terrain: model.terrain, availableInletHeadM: available > 0 ? available : 0);
      results.mechanised[p.id] = m;
      for (final w in m.warnings) {
        _note(w);
      }
    }
    return results.mechanised;
  }

  // ------------------------------------------------------------ BOM

  /// Valve wiring: controllers, station and common wires sized for the
  /// solenoid voltage (see `electrical.dart`), with the system flows telling
  /// which valves (and valve-in-head stations) are on together.
  ElectricalResult? designWiring() {
    final flows = [
      for (final f in effectiveSystemFlows()) {...f.valveIds, ...vih.runningIn(f.valveIds)},
    ];
    final r = designElectrical(project, flows: flows);
    results.electrical = r;
    if (r != null) results.messages.addAll(r.warnings);
    return r;
  }

  // 1.6.0 AGB
  /// Pump house electrics and the pivots' supply, solar pumping, water
  /// quality and two-wire wiring (`agb_design.dart`), on the flows of the
  /// valve wiring.
  AgbResults? designMachinesAndWater() {
    final flows = [
      for (final f in effectiveSystemFlows()) {...f.valveIds, ...vih.runningIn(f.valveIds)},
    ];
    final r = designAgb(project, results, flows: flows, terrain: model.terrain);
    results.agb = r;
    if (r != null) results.messages.addAll(r.warnings);
    return r;
  }

  List<BomLine> buildBom() {
    final lines = <String, BomLine>{};
    // the same lines split by where they are installed: a zone (its valve
    // id), the mainline (''), a pivot (its id) or the electrical part
    final byZone = <String, Map<String, BomLine>>{};
    void put(Map<String, BomLine> into, String key, String cat, String desc, String unit, double qty, double cost, String? specId, String code, String supplier) {
      final l = into[key];
      if (l != null) {
        l.quantity += qty;
      } else {
        into[key] = BomLine(
          category: cat,
          description: desc,
          unit: unit,
          quantity: qty,
          unitCost: cost,
          specId: specId,
          code: code,
          supplier: supplier,
          finame: specId == null ? '' : (catalog.finame[specId] ?? ''),
        );
      }
    }

    void add(String cat, String desc, String unit, double qty, double cost, String? specId, {String code = '', String supplier = '', String zone = ''}) {
      final key = '$cat|$desc';
      put(lines, key, cat, desc, unit, qty, cost, specId, code, supplier);
      put(byZone.putIfAbsent(zone, () => {}), key, cat, desc, unit, qty, cost, specId, code, supplier);
    }

    // zone of every entity: of its links, else of its node
    final zoneOf = <String, String>{};
    for (final l in model.links) {
      if (l.zoneId != null) zoneOf.putIfAbsent(l.entityId, () => l.zoneId!);
    }
    for (final n in model.nodes.values) {
      if (n.zoneId == null) continue;
      for (final id in n.entityIds) {
        zoneOf.putIfAbsent(id, () => n.zoneId!);
      }
    }

    for (final l in model.links) {
      if (l.kind != GLinkKind.pipe) continue;
      final tape = catalog.tape(l.tapeSpecId);
      if (tape != null) {
        add('bom.tapes', tape.name, 'm', l.length, tape.costPerM, tape.id, code: tape.code, supplier: tape.supplier, zone: l.zoneId ?? '');
        continue;
      }
      final spec = _specOf(l);
      if (spec != null) add('bom.pipes', spec.name, 'm', l.length, spec.costPerM, spec.id, code: spec.code, supplier: spec.supplier, zone: l.zoneId ?? '');
    }
    for (final e in project.entities) {
      if (model.unconnectedEntities.contains(e.id)) continue;
      final zone = e is ControlValveEntity ? e.id : (e is PivotEntity ? e.id : (zoneOf[e.id] ?? ''));
      switch (e) {
        case OutletEntity o:
          final s = catalog.outlet(o.outletSpecId);
          if (s != null) add('bom.outlets', '${s.name} — ${s.nozzle(o.nozzleId)?.name ?? ''}', 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier, zone: zone);
        case SpraylineEntity s:
          final spec = catalog.outlet(s.outletSpecId);
          if (spec != null) {
            add('bom.outlets', '${spec.name} — ${spec.nozzle(s.nozzleId)?.name ?? ''}', 'un', s.outletCount.toDouble(), spec.cost, spec.id, code: spec.code, supplier: spec.supplier, zone: zone);
          }
        case ControlValveEntity v:
          final s = catalog.valve(v.valveSpecId);
          if (s != null) add('bom.valves', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier, zone: zone);
        case MiscHydraulicEntity m:
          final s = catalog.valve(m.valveSpecId);
          if (s != null) add('bom.devices', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier, zone: zone);
        case PumpEntity p:
          final s = catalog.pump(p.pumpSpecId);
          if (s != null) add('bom.pumps', s.name, 'un', 1, s.cost, s.id, code: s.code, supplier: s.supplier, zone: zone);
          if (p.hourMeter) add('bom.pumps', _label('acc.hourMeter'), 'un', 1, p.hourMeterCost, null, zone: zone);
        case PivotEntity p:
          final r = results.pivots[p.id];
          final towers = r?.towerCount ?? p.towerPositions().length;
          final label = p.name.isNotEmpty ? p.name : _label('tool.pivot');
          add(
            'bom.pivots',
            '$label — ${p.kind == PivotKind.pivot ? _label('pivot.kindPivot') : _label('pivot.kindLinear')} ${p.radiusM.round()} m, $towers ${_label('pivot.towers')}',
            'un',
            1,
            p.machineCost,
            null,
            zone: zone,
          );
          add('bom.pivots', '$label — ${_label('pivot.towersItem')} (${p.spanLengthM.round()} m)', 'un', towers.toDouble(), p.towerCost, null, zone: zone);
          final pipe = catalog.pipe(p.pipeSpecId);
          if (pipe != null) add('bom.pipes', pipe.name, 'm', p.radiusM, pipe.costPerM, pipe.id, code: pipe.code, supplier: pipe.supplier, zone: zone);
          final mech = results.mechanised[p.id];
          final nSpr = mech?.package.sprinklerCount ?? r?.sprinklerCount ?? (p.sprinklerSpacingM > 0 ? (p.radiusM / p.sprinklerSpacingM).round() : 0);
          final spr = catalog.outlet(p.sprinklerSpecId);
          if (nSpr > 0) {
            add(
              'bom.pivots',
              '$label — ${spr?.name ?? _label('pivot.sprinklersItem')}',
              'un',
              nSpr.toDouble(),
              spr?.cost ?? 0,
              spr?.id,
              code: spr?.code ?? '',
              supplier: spr?.supplier ?? '',
              zone: zone,
            );
          }
          final reg = catalog.valve(p.regulatorSpecId);
          if (reg != null && nSpr > 0) add('bom.pivots', '$label — ${reg.name}', 'un', nSpr.toDouble(), reg.cost, reg.id, code: reg.code, supplier: reg.supplier, zone: zone);
          if (p.endGunFlow > 0 || (mech?.package.endGunFlow ?? 0) > 0) add('bom.pivots', '$label — ${_label('pivot.endGunItem')}', 'un', 1, 0, null, zone: zone);
          if (mech != null) {
            if (mech.package.boosterPowerKw > 0) {
              add('bom.pivots', '$label — ${_label('mech.booster')} (${fmt(mech.electrical?.boosterMotorKw ?? mech.package.boosterPowerKw, 1)} kW)', 'un', 1, 0, null, zone: zone);
            }
            if (mech.cornerArm != null && mech.cornerArm!.steps.isNotEmpty) {
              add('bom.pivots', '$label — ${_label('mech.cornerArm')} (${p.machine.cornerArmLengthM.round()} m)', 'un', 1, 0, null, zone: zone);
            }
            final el = mech.electrical;
            if (el != null) {
              add('bom.pivots', '$label — ${_label('mech.spanCable')} ${fmt(el.cableMm2, 1)} mm²', 'm', el.towers.isEmpty ? 0 : el.towers.last.cableM, 0, null, zone: zone);
              if (p.machine.supplyCableM > 0) add('bom.pivots', '$label — ${_label('mech.supplyCable')} ${fmt(el.supplyCableMm2, 1)} mm²', 'm', p.machine.supplyCableM, 0, null, zone: zone);
            }
          }
        default:
          break;
      }
    }
    final el = results.electrical;
    // 1.6.0 AGB: with two-wire wiring the decoder path replaces the station wires
    final twoWire = twoWireOn(project) && results.agb?.twoWire != null;
    if (el != null) {
      for (final e in el.wireMeters.entries) {
        final w = catalog.wire(e.key);
        if (w != null && e.value > 0 && !twoWire) add('bom.electrical', w.name, 'm', e.value, w.costPerM, w.id, code: w.code, supplier: w.supplier, zone: 'elec');
      }
      for (final c in project.entities.whereType<ControllerEntity>()) {
        add('bom.electrical', '${c.name.isNotEmpty ? c.name : _label('tool.controller')} (${c.stations} ${_label('elec.stationsShort')})', 'un', 1, c.cost, null, zone: 'elec');
        for (final k in controllerAccessoryKinds) {
          final price = c.accessories[k];
          if (price != null) add('bom.electrical', _label('acc.$k'), 'un', 1, price, null, zone: 'elec');
        }
      }
      // two waterproof splices per solenoid (station and common conductors)
      if (el.runs.isNotEmpty && !twoWire) add('bom.electrical', _label('elec.splice'), 'un', 2.0 * el.runs.fold(0, (s, r) => s + r.solenoids), 0, null, zone: 'elec');
    }
    // 1.6.0 AGB: pump house, pivots' supply, solar array, filtration, two-wire
    agbBomLines(project, results, add, _label);
    results.bom
      ..clear()
      ..addAll(lines.values);
    results.bomByZone
      ..clear()
      ..addAll({for (final e in byZone.entries) e.key: e.value.values.toList()});
    if (params.selectFittings) {
      final sel = selectFittings(project, model, _specOf, t: _label);
      results.bom.addAll(sel.lines);
      for (final z in {'', ...model.valveNodes.keys}) {
        final part = selectFittings(project, model, _specOf, t: _label, zone: z);
        if (part.lines.isNotEmpty) results.bomByZone.putIfAbsent(z, () => []).addAll(part.lines);
      }
      final seen = <String>{};
      for (final m in sel.missing) {
        final name = genericFittingName(m.kind, m.sizeMm, m.size2Mm, _label);
        if (seen.add(name)) results.messages.add('fitting_missing:$name');
      }
    }
    results.bom.sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
    // catalogue items without a price (manufacturer packs come without them)
    final unpriced = results.bom.where((l) => l.specId != null && l.quantity > 0 && !(l.unitCost > 0) && catalog.outlet(l.specId)?.kind != OutletKind.demandPoint).length;
    if (unpriced > 0) results.messages.add('bom_unpriced:$unpriced');
    results.capitalCost = results.bom.fold(0.0, (s, l) => s + l.total);
    results.annualCapitalCost = results.capitalCost * _crf();
    results.annualEnergyCost = results.systemFlows.fold(0.0, (s, f) => s + f.annualEnergyCost);
    // 1.6.0 AGB: what the solar array leaves of the energy cost
    results.annualEnergyCost = agbEnergyCost(results);
    return results.bom;
  }
}

/// Water requirement summary for an irrigation area.
class AreaRequirement {
  AreaRequirement({
    required this.areaId,
    required this.name,
    required this.areaM2,
    required this.grossDepthMm,
    required this.dailyVolumeM3,
    required this.flow,
    required this.hoursPerDay,
    required this.precipitationMmH,
    this.machineFlow = 0,
  });
  final String areaId;
  final String name;
  final double areaM2;
  final double grossDepthMm;
  final double dailyVolumeM3;
  final double flow;
  final double hoursPerDay;
  final double precipitationMmH;

  /// Part of [flow] that comes from centre pivots and linear moves (m³/s).
  final double machineFlow;
}

List<AreaRequirement> areaRequirements(Project project, DesignResults? results) {
  final out = <AreaRequirement>[];
  final outletsByEntity = results?.outletsByEntity ?? {};
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    var flow = 0.0, machineFlow = 0.0;
    for (final e in project.entities) {
      if (e is OutletEntity && project.outletWatersArea(e, a.points)) {
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
          if (t != null && t.emitterSpacingM > 0) flow += t.emitter.flow(e.inletHeadM) * (e.length / t.emitterSpacingM) * inside;
        }
      } else if (e is PivotEntity) {
        // a machine applies an even depth: the area gets the share of the
        // flow that falls on the part of the irrigated outline inside it
        final q = results?.pivots[e.id]?.flow ?? 0;
        if (q > 0) {
          final share = q * _shareInside(e.outline(), a.points);
          flow += share;
          machineFlow += share;
        }
      }
    }
    final area = a.area;
    // the gross depth of the design period by the rule every report shares
    // (area_water.dart: ETc,loc = Kr·Kc·ETo over the whole area for
    // localized irrigation, the wetted fraction only in the RAW)
    final gross = areaWaterBasis(project, a).grossMmDay;
    final vol = gross / 1000 * area;
    final hours = flow > 0 ? vol / (flow * 3600) : 0.0;
    final pr = area > 0 ? flow * 3600 * 1000 / area : 0.0;
    out.add(
      AreaRequirement(
        areaId: a.id,
        name: a.name.isEmpty ? a.id : a.name,
        areaM2: area,
        grossDepthMm: gross,
        dailyVolumeM3: vol,
        flow: flow,
        hoursPerDay: hours,
        precipitationMmH: pr,
        machineFlow: machineFlow,
      ),
    );
  }
  return out;
}

/// Share of the polygon [src] that lies inside [area], sampled on a 40 × 40
/// grid over [src].
double _shareInside(List<Pt> src, List<Pt> area) {
  final b = Bounds.ofPoints(src);
  const n = 40;
  var inSrc = 0, inBoth = 0;
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final p = Pt(b.minX + (i + 0.5) * b.width / n, b.minY + (j + 0.5) * b.height / n);
      if (!pointInPolygon(p, src)) continue;
      inSrc++;
      if (pointInPolygon(p, area)) inBoth++;
    }
  }
  return inSrc == 0 ? 0 : inBoth / inSrc;
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

/// A zone network kept for reuse, with what it was built from.
typedef _ZoneNetwork = ({NetworkModel model, int inputs, HydraulicNetwork net, HNode? inlet});
