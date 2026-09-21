/// Converts project entities into a connected hydraulic graph.
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';

enum GLinkKind { pipe, controlValve, pump, device, prv }

class EmitterRef {
  EmitterRef({
    required this.entityId,
    required this.index,
    required this.curve,
    required this.count,
    required this.nominalHead,
    required this.allowedMin,
    required this.allowedMax,
    required this.cv,
    this.offset = 0,
    this.label = '',
  });
  final String entityId;

  /// Outlet index within a sprayline/tape (−1 for single outlets).
  final int index;
  final EmitterCurve curve;
  final int count;
  final double nominalHead;
  final double allowedMin;
  final double allowedMax;
  final double cv;

  /// Height of the emitter above the node (riser + burial depth).
  final double offset;
  final String label;

  double get nominalFlow => curve.flow(nominalHead) * count;
}

class GNode {
  GNode({required this.id, required this.p, required this.ground, required this.scope});
  final String id;
  final Pt p;
  final double ground;
  final HydraulicScope scope;
  double depth = 0;
  final List<EmitterRef> emitters = [];
  final Set<String> entityIds = {};
  final List<GLink> links = [];
  String? zoneId;
  bool isSupply = false;
  String? supplyEntityId;
  double? fixedElevation;

  double get elevation => fixedElevation ?? (ground - depth);
}

class GLink {
  GLink({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.scope,
    required this.entityId,
    this.segmentIndex = 0,
    this.length = 0,
    this.pipeSpecId,
    this.tapeSpecId,
    this.computerSized = false,
    this.usage = PipeUsage.zone,
    this.minorK = 0,
    this.depth = 0,
    this.settingM = 0,
    this.valveSpecId,
    this.pumpSpecId,
    this.speedRatio = 1,
    this.a = Pt.zero,
    this.b = Pt.zero,
    this.emitterCountAlong = 0,
  });
  final String id;
  final String from;
  final String to;
  final GLinkKind kind;
  final HydraulicScope scope;
  final String entityId;
  final int segmentIndex;
  double length;
  String? pipeSpecId;
  final String? tapeSpecId;
  bool computerSized;
  final PipeUsage usage;
  double minorK;
  final double depth;
  final double settingM;
  final String? valveSpecId;
  final String? pumpSpecId;
  final double speedRatio;
  final Pt a;
  final Pt b;

  /// Number of emitters represented along this link (lumped laterals).
  final int emitterCountAlong;
  String? zoneId;

  String other(String n) => n == from ? to : from;
}

class NetworkModel {
  NetworkModel();
  final Map<String, GNode> nodes = {};
  final List<GLink> links = [];

  /// valve entity id -> (mainline node, zone node)
  final Map<String, (String, String)> valveNodes = {};
  final Map<String, String> supplyNodes = {};

  /// pivot entity id -> mainline node at the pivot point
  final Map<String, String> pivotNodes = {};

  /// zone id (= valve entity id) -> node ids
  final Map<String, Set<String>> zoneNodes = {};
  final Map<String, Set<String>> zoneLinks = {};
  final Set<String> mainlineNodes = {};
  final Set<String> mainlineLinks = {};
  final List<String> warnings = [];
  final Set<String> unconnectedEntities = {};
  Terrain? terrain;

  GLink? linkById(String id) {
    for (final l in links) {
      if (l.id == id) return l;
    }
    return null;
  }
}

class NetworkBuilder {
  NetworkBuilder(this.project);
  final Project project;

  /// Maximum lumped emitter nodes per lateral (from the design parameters).
  late final int maxNodesPerLateral = math.max(2, project.params.maxNodesPerLateral);

  late final double tol = project.params.connectTolerance;
  late final Terrain terrain = project.buildTerrain();
  final NetworkModel model = NetworkModel();
  final Map<int, List<GNode>> _grid = {};
  int _seq = 0;

  int _key(Pt p) => (p.x / (tol * 4)).floor() * 73856093 ^ (p.y / (tol * 4)).floor() * 19349663;

  GNode _nodeAt(Pt p, HydraulicScope scope, {bool create = true}) {
    final ix = (p.x / (tol * 4)).floor(), iy = (p.y / (tol * 4)).floor();
    GNode? best;
    var bestD = double.infinity;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final list = _grid[(ix + dx) * 73856093 ^ (iy + dy) * 19349663];
        if (list == null) continue;
        for (final n in list) {
          if (n.scope != scope) continue;
          final d = n.p.distanceTo(p);
          if (d <= tol && d < bestD) {
            best = n;
            bestD = d;
          }
        }
      }
    }
    if (best != null || !create) return best ?? _dummy;
    final n = GNode(id: 'n${_seq++}', p: p, ground: terrain.elevationAt(p), scope: scope);
    model.nodes[n.id] = n;
    _grid.putIfAbsent(_key(p), () => []).add(n);
    return n;
  }

  static final _dummy = GNode(id: '', p: Pt.zero, ground: 0, scope: HydraulicScope.zone);

  NetworkModel build() {
    model.terrain = terrain;
    final catalog = project.catalog;
    final linear = project.entities.where((e) => e is PipeEntity || e is SpraylineEntity || e is TapeEntity).toList();
    final points = <Pt>[];
    final splitRequests = <String, List<Pt>>{for (final e in linear) e.id: []};

    List<Pt> ptsOf(Entity e) => (e as PolyEntity).points;
    HydraulicScope scopeOf(Entity e) => e.hydraulicScope ?? HydraulicScope.zone;

    // 1. split requests from point items and T-junctions
    void requestSplit(Pt p, Iterable<HydraulicScope> scopes, {String? exclude}) {
      for (final e in linear) {
        if (e.id == exclude) continue;
        if (!scopes.contains(scopeOf(e))) continue;
        final pts = ptsOf(e);
        for (var i = 1; i < pts.length; i++) {
          final (cp, t) = closestPointOnSegment(p, pts[i - 1], pts[i]);
          if (cp.distanceTo(p) <= tol && t > 1e-9 && t < 1 - 1e-9) {
            // not at a vertex: split
            if (pts[i - 1].distanceTo(p) > tol && pts[i].distanceTo(p) > tol) splitRequests[e.id]!.add(cp);
          }
        }
      }
    }

    for (final e in project.entities) {
      switch (e) {
        case OutletEntity o:
          requestSplit(o.position, [o.scope]);
        case JunctionEntity j:
          requestSplit(j.position, [j.scope]);
        case ControlValveEntity v:
          requestSplit(v.position, HydraulicScope.values);
        case PumpEntity p:
          requestSplit(p.position, [p.scope]);
        case MiscHydraulicEntity m:
          requestSplit(m.position, [m.scope]);
        case WaterSupplyEntity s:
          requestSplit(s.position, [HydraulicScope.mainline]);
        case PivotEntity p:
          requestSplit(p.center, [HydraulicScope.mainline]);
        default:
          break;
      }
    }
    for (final e in linear) {
      final pts = ptsOf(e);
      if (pts.length < 2) continue;
      requestSplit(pts.first, [scopeOf(e)], exclude: e.id);
      requestSplit(pts.last, [scopeOf(e)], exclude: e.id);
    }

    // 2. build vertices (with splits) and links
    for (final e in linear) {
      final scope = scopeOf(e);
      final raw = ptsOf(e);
      if (raw.length < 2) {
        model.unconnectedEntities.add(e.id);
        continue;
      }
      final splits = splitRequests[e.id]!;
      var pts = List<Pt>.from(raw);
      if (splits.isNotEmpty) {
        final ds = <double>[];
        for (final s in splits) {
          // distance along polyline
          var acc = 0.0;
          var best = double.infinity;
          var bestD = 0.0;
          for (var i = 1; i < pts.length; i++) {
            final (cp, t) = closestPointOnSegment(s, pts[i - 1], pts[i]);
            final d = cp.distanceTo(s);
            if (d < best) {
              best = d;
              bestD = acc + t * pts[i - 1].distanceTo(pts[i]);
            }
            acc += pts[i - 1].distanceTo(pts[i]);
          }
          ds.add(bestD);
        }
        final pieces = splitPolylineAt(pts, ds);
        pts = [pieces.first.first];
        for (final piece in pieces) {
          pts.addAll(piece.skip(1));
        }
      }
      points.addAll(pts);
      switch (e) {
        case PipeEntity p:
          final spec = catalog.pipe(p.pipeSpecId);
          final usage = scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline;
          _addPolylineLinks(e.id, pts, scope, usage: usage, pipeSpecId: spec?.id, computerSized: p.computerSized || spec == null, depth: p.depth);
        case SpraylineEntity s:
          final outlet = catalog.outlet(s.outletSpecId);
          final nozzle = outlet?.nozzle(s.nozzleId);
          if (outlet == null || nozzle == null) {
            model.warnings.add('outlet_spec_missing:${e.id}');
            model.unconnectedEntities.add(e.id);
            continue;
          }
          final spec = catalog.pipe(s.pipeSpecId);
          final total = polylineLength(pts);
          final n = s.outletCount;
          final first = s.firstOutletDistance;
          final (lo, hi) = _window(nozzle, s.headM);
          final positions = [for (var i = 0; i < n; i++) first + i * s.spacing];
          final lumps = _lump(positions, total);
          final emitterAt = <double, EmitterRef>{};
          for (final (d, cnt, idx) in lumps) {
            emitterAt[d] = EmitterRef(entityId: e.id, index: idx, curve: nozzle.curve, count: cnt, nominalHead: s.headM, allowedMin: lo, allowedMax: hi, cv: nozzle.cv, offset: s.riserHeight + outlet.riserHeightM + s.depth, label: nozzle.name);
          }
          _addLateralLinks(e.id, pts, scope, emitterAt, usage: PipeUsage.lateral, pipeSpecId: spec?.id, computerSized: s.computerSized || spec == null, depth: s.depth, perEmitterK: 0.0);
        case TapeEntity t:
          final spec = catalog.tape(t.tapeSpecId);
          if (spec == null) {
            model.warnings.add('tape_spec_missing:${e.id}');
            model.unconnectedEntities.add(e.id);
            continue;
          }
          final total = polylineLength(pts);
          final n = (total / spec.emitterSpacingM).floor();
          final positions = [for (var i = 1; i <= n; i++) i * spec.emitterSpacingM];
          final lumps = _lump(positions, total);
          final lo = math.max(spec.minHeadM, t.inletHeadM * (1 - spec.tolBelowPct / 100));
          final hi = math.min(spec.maxHeadM, t.inletHeadM * (1 + spec.tolAbovePct / 100));
          final emitterAt = <double, EmitterRef>{};
          for (final (d, cnt, idx) in lumps) {
            emitterAt[d] = EmitterRef(entityId: e.id, index: idx, curve: spec.emitter, count: cnt, nominalHead: t.inletHeadM, allowedMin: lo, allowedMax: hi, cv: spec.cv, offset: t.depth, label: spec.name);
          }
          _addLateralLinks(e.id, pts, scope, emitterAt, usage: PipeUsage.lateral, pipeSpecId: null, tapeSpecId: spec.id, computerSized: false, depth: t.depth, perEmitterK: spec.barbK, endFlow: t.flushingFlow);
        default:
          break;
      }
    }

    // 3. point items (two passes: devices after supplies and valves)
    for (final pass in [0, 1]) {
    for (final e in project.entities) {
      final isDevice = e is PumpEntity || e is MiscHydraulicEntity;
      if ((pass == 0) == isDevice) continue;
      switch (e) {
        case OutletEntity o:
          final outlet = catalog.outlet(o.outletSpecId);
          final nozzle = outlet?.nozzle(o.nozzleId);
          if (outlet == null || nozzle == null) {
            model.warnings.add('outlet_spec_missing:${e.id}');
            continue;
          }
          final n = _nodeAt(o.position, o.scope, create: false);
          if (n.id.isEmpty) {
            model.unconnectedEntities.add(e.id);
            continue;
          }
          final (lo, hi) = _window(nozzle, o.headM);
          n.entityIds.add(e.id);
          n.emitters.add(EmitterRef(entityId: e.id, index: -1, curve: nozzle.curve, count: 1, nominalHead: o.headM, allowedMin: lo, allowedMax: hi, cv: nozzle.cv, offset: o.riserHeight + outlet.riserHeightM, label: nozzle.name));
        case JunctionEntity j:
          final n = _nodeAt(j.position, j.scope);
          n.entityIds.add(e.id);
          if (j.fixedElevation != null) n.fixedElevation = j.fixedElevation;
        case PivotEntity p:
          final n = _nodeAt(p.center, HydraulicScope.mainline, create: false);
          if (n.id.isEmpty) {
            model.unconnectedEntities.add(e.id);
            continue;
          }
          n.entityIds.add(e.id);
          model.pivotNodes[e.id] = n.id;
        case WaterSupplyEntity s:
          final n = _nodeAt(s.position, HydraulicScope.mainline);
          n.entityIds.add(e.id);
          n.isSupply = true;
          n.supplyEntityId = e.id;
          model.supplyNodes[e.id] = n.id;
          if (n.links.isEmpty) model.unconnectedEntities.add(e.id);
        case ControlValveEntity v:
          final nm = _nodeAt(v.position, HydraulicScope.mainline);
          final nz = _nodeAt(v.position, HydraulicScope.zone);
          nm.entityIds.add(e.id);
          nz.entityIds.add(e.id);
          final l = GLink(id: 'cv_${e.id}', from: nm.id, to: nz.id, kind: GLinkKind.controlValve, scope: HydraulicScope.mainline, entityId: e.id, valveSpecId: v.valveSpecId, depth: v.depth, a: v.position, b: v.position);
          _register(l);
          model.valveNodes[e.id] = (nm.id, nz.id);
          if (nz.links.length <= 1) model.warnings.add('valve_no_zone_pipes:${e.id}');
        case PumpEntity p:
          final spec = catalog.pump(p.pumpSpecId);
          if (spec == null) {
            model.warnings.add('pump_spec_missing:${e.id}');
            continue;
          }
          _insertInline(e.id, p.position, p.scope, (up, down) => GLink(id: 'pump_${e.id}', from: up, to: down, kind: GLinkKind.pump, scope: p.scope, entityId: e.id, pumpSpecId: spec.id, speedRatio: p.speedRatio, a: p.position, b: p.position));
        case MiscHydraulicEntity m:
          final spec = catalog.valve(m.valveSpecId);
          if (spec == null) {
            model.warnings.add('valve_spec_missing:${e.id}');
            continue;
          }
          final isPrv = spec.kind == ValveKind.prv;
          _insertInline(e.id, m.position, m.scope, (up, down) => GLink(id: 'dev_${e.id}', from: up, to: down, kind: isPrv ? GLinkKind.prv : GLinkKind.device, scope: m.scope, entityId: e.id, valveSpecId: spec.id, settingM: isPrv ? (m.settingM > 0 ? m.settingM : spec.defaultSettingM) : 0, a: m.position, b: m.position));
        default:
          break;
      }
    }
    }

    // 4. node depths
    for (final n in model.nodes.values) {
      var d = 0.0;
      for (final l in n.links) {
        d = math.max(d, l.depth);
      }
      n.depth = d;
    }

    // 5. zone assignment by BFS from each valve's zone node
    for (final entry in model.valveNodes.entries) {
      final valveId = entry.key;
      final start = entry.value.$2;
      final visited = <String>{};
      final linkSet = <String>{};
      final queue = [start];
      visited.add(start);
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        final n = model.nodes[id]!;
        if (n.zoneId != null && n.zoneId != valveId) {
          final pair = [valveId, n.zoneId!]..sort();
          final w = 'zone_overlap:${pair[0]}:${pair[1]}';
          if (!model.warnings.contains(w)) model.warnings.add(w);
        }
        n.zoneId = valveId;
        for (final l in n.links) {
          if (l.kind == GLinkKind.controlValve) continue;
          if (l.scope != HydraulicScope.zone) continue;
          linkSet.add(l.id);
          l.zoneId = valveId;
          final o = l.other(id);
          if (visited.add(o)) queue.add(o);
        }
      }
      model.zoneNodes[valveId] = visited;
      model.zoneLinks[valveId] = linkSet;
    }
    // 6. mainline reachability from supplies
    final mq = <String>[...model.supplyNodes.values];
    model.mainlineNodes.addAll(mq);
    while (mq.isNotEmpty) {
      final id = mq.removeLast();
      final n = model.nodes[id]!;
      for (final l in n.links) {
        if (l.scope != HydraulicScope.mainline || l.kind == GLinkKind.controlValve) continue;
        model.mainlineLinks.add(l.id);
        final o = l.other(id);
        if (model.mainlineNodes.add(o)) mq.add(o);
      }
    }
    _installElevations();
    for (final e in project.entities) {
      if (!e.isHydraulic) continue;
      if (model.unconnectedEntities.contains(e.id)) continue;
      switch (e) {
        case ControlValveEntity _:
          final (nm, _) = model.valveNodes[e.id] ?? ('', '');
          if (!model.mainlineNodes.contains(nm)) model.unconnectedEntities.add(e.id);
        case PipeEntity p when p.scope == HydraulicScope.mainline:
          if (!links(e.id).any((l) => model.mainlineLinks.contains(l.id))) model.unconnectedEntities.add(e.id);
        case PipeEntity _:
        case SpraylineEntity _:
        case TapeEntity _:
          if (!links(e.id).any((l) => l.zoneId != null)) model.unconnectedEntities.add(e.id);
        case OutletEntity o:
          final n = _nodeAt(o.position, o.scope, create: false);
          if (n.id.isEmpty) {
            model.unconnectedEntities.add(e.id);
          } else if (o.scope == HydraulicScope.zone ? n.zoneId == null : !model.mainlineNodes.contains(n.id)) {
            model.unconnectedEntities.add(e.id);
          }
        case PumpEntity _:
        case MiscHydraulicEntity _:
          if (!links(e.id).any((l) => model.mainlineLinks.contains(l.id) || l.zoneId != null)) model.unconnectedEntities.add(e.id);
        case PivotEntity _:
          final n = model.pivotNodes[e.id];
          if (n == null || !model.mainlineNodes.contains(n)) model.unconnectedEntities.add(e.id);
        default:
          break;
      }
    }
    return model;
  }

  Iterable<GLink> links(String entityId) => model.links.where((l) => l.entityId == entityId);

  (double, double) _window(NozzleSpec nozzle, double nominalHead) {
    final (lo, hi) = nozzle.curve.headWindow(nominalHead, below: nozzle.flowTolBelow, above: nozzle.flowTolAbove);
    return (math.max(lo, nozzle.minHeadM), math.min(hi, nozzle.maxHeadM));
  }

  /// Groups outlet positions into at most [maxNodesPerLateral] lumps.
  /// Returns (distance of lump centroid, count, first index).
  List<(double, int, int)> _lump(List<double> positions, double total) {
    if (positions.isEmpty) return [];
    final k = (positions.length / maxNodesPerLateral).ceil();
    final out = <(double, int, int)>[];
    for (var i = 0; i < positions.length; i += k) {
      final end = math.min(i + k, positions.length);
      final cnt = end - i;
      var sum = 0.0;
      for (var j = i; j < end; j++) {
        sum += positions[j];
      }
      out.add((math.min(sum / cnt, total), cnt, i));
    }
    return out;
  }

  void _register(GLink l) {
    model.links.add(l);
    model.nodes[l.from]!.links.add(l);
    model.nodes[l.to]!.links.add(l);
  }

  void _addPolylineLinks(String entityId, List<Pt> pts, HydraulicScope scope, {required PipeUsage usage, String? pipeSpecId, bool computerSized = false, double depth = 0}) {
    for (var i = 1; i < pts.length; i++) {
      final a = _nodeAt(pts[i - 1], scope);
      final b = _nodeAt(pts[i], scope);
      a.entityIds.add(entityId);
      b.entityIds.add(entityId);
      if (a.id == b.id) continue;
      final len = pts[i - 1].distanceTo(pts[i]);
      final l = GLink(id: '${entityId}_${i - 1}', from: a.id, to: b.id, kind: GLinkKind.pipe, scope: scope, entityId: entityId, segmentIndex: i - 1, length: len, pipeSpecId: pipeSpecId, computerSized: computerSized, usage: usage, depth: depth, a: pts[i - 1], b: pts[i]);
      _register(l);
    }
  }

  void _addLateralLinks(String entityId, List<Pt> pts, HydraulicScope scope, Map<double, EmitterRef> emitterAt, {required PipeUsage usage, String? pipeSpecId, String? tapeSpecId, bool computerSized = false, double depth = 0, double perEmitterK = 0, double endFlow = 0}) {
    // Build a list of stations along the polyline: vertices + emitter lumps.
    final total = polylineLength(pts);
    final stations = <double>{0, total};
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      acc += pts[i - 1].distanceTo(pts[i]);
      stations.add(acc);
    }
    stations.addAll(emitterAt.keys);
    final sorted = stations.toList()..sort();
    GNode? prev;
    var prevD = 0.0;
    var seg = 0;
    var emittersSince = 0;
    for (final d in sorted) {
      final p = pointAlongPolyline(pts, d);
      final n = (prev != null && (d - prevD) < tol) ? prev : _nodeAt(p, scope);
      n.entityIds.add(entityId);
      final em = emitterAt[d];
      if (em != null) {
        n.emitters.add(em);
        emittersSince += em.count;
      }
      if (prev != null && prev.id != n.id) {
        final l = GLink(id: '${entityId}_${seg++}', from: prev.id, to: n.id, kind: GLinkKind.pipe, scope: scope, entityId: entityId, segmentIndex: seg - 1, length: d - prevD, pipeSpecId: pipeSpecId, tapeSpecId: tapeSpecId, computerSized: computerSized, usage: usage, minorK: perEmitterK * emittersSince, depth: depth, a: pointAlongPolyline(pts, prevD), b: p, emitterCountAlong: emittersSince);
        _register(l);
        emittersSince = 0;
      }
      prev = n;
      prevD = d;
    }
    if (endFlow > 0 && prev != null) {
      prev.emitters.add(EmitterRef(entityId: entityId, index: -2, curve: EmitterCurve(k: endFlow, x: 0), count: 1, nominalHead: 1, allowedMin: 0, allowedMax: double.infinity, cv: 0, label: 'flush'));
    }
  }

  /// Inserts an in-line device at [p]: the node is split into an upstream and a
  /// downstream node; the side nearest to a supply (by hop count) is upstream.
  /// A supply node stands for its water surface (the head of the reservoir),
  /// so the pressure there is the supply pressure and a pipe leaving a well
  /// climbs from the water level. A submersible pump is installed at the
  /// water level of the supply that feeds it: its inlet sees no suction lift
  /// and the lift shows in the pipe that rises from it.
  void _installElevations() {
    final waterLevel = <String, double>{};
    for (final e in project.entities) {
      if (e is! WaterSupplyEntity) continue;
      final n = model.nodes[model.supplyNodes[e.id] ?? ''];
      if (n == null) continue;
      final z = n.ground + e.waterLevelOffsetM;
      n.fixedElevation = z;
      waterLevel[n.id] = z;
    }
    final submersible = [
      for (final l in model.links)
        if (l.kind == GLinkKind.pump && model.mainlineLinks.contains(l.id) && (project.catalog.pump(l.pumpSpecId)?.submersible ?? false)) l,
    ];
    if (submersible.isEmpty || waterLevel.isEmpty) return;
    // nearest supply of every mainline node (multi-source BFS)
    final source = <String, String>{for (final id in waterLevel.keys) id: id};
    final queue = [...waterLevel.keys];
    for (var i = 0; i < queue.length; i++) {
      final id = queue[i];
      for (final l in model.nodes[id]!.links) {
        if (!model.mainlineLinks.contains(l.id)) continue;
        final o = l.other(id);
        if (source.containsKey(o)) continue;
        source[o] = source[id]!;
        queue.add(o);
      }
    }
    for (final l in submersible) {
      final src = source[l.from];
      if (src == null) continue;
      for (final id in [l.from, l.to]) {
        final n = model.nodes[id]!;
        if (!n.isSupply) n.fixedElevation = waterLevel[src];
      }
    }
  }

  void _insertInline(String entityId, Pt p, HydraulicScope scope, GLink Function(String up, String down) make) {
    final n = _nodeAt(p, scope, create: false);
    if (n.id.isEmpty) {
      model.unconnectedEntities.add(entityId);
      return;
    }
    n.entityIds.add(entityId);
    final attached = List<GLink>.from(n.links);
    // BFS hop distance from supplies / valves-zone-nodes to each neighbour
    GLink? upstreamLink;
    if (attached.length >= 2) {
      final dist = _hopDistances(scope);
      var best = double.infinity;
      for (final l in attached) {
        final d = dist[l.other(n.id)] ?? double.infinity;
        if (d < best) {
          best = d;
          upstreamLink = l;
        }
      }
    } else if (attached.length == 1) {
      upstreamLink = n.isSupply ? null : attached.first;
      if (!n.isSupply) {
        // device at a dead end: treat the single pipe as upstream
      }
    }
    final down = GNode(id: 'n${_seq++}', p: p, ground: n.ground, scope: scope);
    model.nodes[down.id] = down;
    _grid.putIfAbsent(_key(p), () => []).add(down);
    down.entityIds.add(entityId);
    for (final l in attached) {
      if (identical(l, upstreamLink)) continue;
      // move link end from n to down
      final idx = model.links.indexOf(l);
      final moved = GLink(id: l.id, from: l.from == n.id ? down.id : l.from, to: l.to == n.id ? down.id : l.to, kind: l.kind, scope: l.scope, entityId: l.entityId, segmentIndex: l.segmentIndex, length: l.length, pipeSpecId: l.pipeSpecId, tapeSpecId: l.tapeSpecId, computerSized: l.computerSized, usage: l.usage, minorK: l.minorK, depth: l.depth, settingM: l.settingM, valveSpecId: l.valveSpecId, pumpSpecId: l.pumpSpecId, speedRatio: l.speedRatio, a: l.a, b: l.b, emitterCountAlong: l.emitterCountAlong);
      model.links[idx] = moved;
      n.links.remove(l);
      final other = model.nodes[l.other(n.id)]!;
      other.links.remove(l);
      other.links.add(moved);
      down.links.add(moved);
    }
    _register(make(n.id, down.id));
  }

  Map<String, double> _hopDistances(HydraulicScope scope) {
    final dist = <String, double>{};
    final queue = <String>[];
    if (scope == HydraulicScope.mainline) {
      for (final s in model.supplyNodes.values) {
        dist[s] = 0;
        queue.add(s);
      }
      // supplies may not be registered yet: use nodes flagged as supply
      for (final n in model.nodes.values) {
        if (n.isSupply && !dist.containsKey(n.id)) {
          dist[n.id] = 0;
          queue.add(n.id);
        }
      }
    } else {
      for (final v in model.valveNodes.values) {
        dist[v.$2] = 0;
        queue.add(v.$2);
      }
    }
    var head = 0;
    while (head < queue.length) {
      final id = queue[head++];
      final n = model.nodes[id]!;
      for (final l in n.links) {
        if (l.kind == GLinkKind.controlValve) continue;
        final o = l.other(id);
        if (!dist.containsKey(o)) {
          dist[o] = dist[id]! + 1;
          queue.add(o);
        }
      }
    }
    return dist;
  }
}
