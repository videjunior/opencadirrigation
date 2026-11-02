/// Converts project entities into a connected hydraulic graph.
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/minor_losses.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';

enum GLinkKind { pipe, controlValve, pump, device, prv, psv, fcv }

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
    this.inlet = false,
  });
  final String entityId;

  /// Outlet index within a sprayline/tape (−1 for single outlets), counted
  /// from the start of the line as drawn.
  final int index;

  /// The group of outlets of a sprayline or tape next to its inlet (the end
  /// joined to the submain, whichever way the line was drawn): its pressure
  /// is the inlet pressure of a tape.
  final bool inlet;
  final EmitterCurve curve;
  final int count;
  final double nominalHead;
  final double allowedMin;
  final double allowedMax;
  final double cv;

  /// Height of the emitter above the node: the riser of a head up to the
  /// ground (with the burial depth of its pipe); 0 for the emitters of a
  /// tape, which discharge at the tube.
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
    this.settingFlow = 0,
    this.valveSpecId,
    this.pumpSpecId,
    this.speedRatio = 1,
    this.a = Pt.zero,
    this.b = Pt.zero,
    this.emitterCountAlong = 0,
    this.planLength,
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

  /// Flow setting of an FCV link (m³/s).
  final double settingFlow;
  final String? valveSpecId;
  final String? pumpSpecId;
  final double speedRatio;
  final Pt a;
  final Pt b;

  /// Number of emitters represented along this link (lumped laterals).
  final int emitterCountAlong;
  String? zoneId;

  /// Length in plan of a pipe link ([length] runs along the ground).
  final double? planLength;

  /// The length along the drawn line, in plan: stations, profiles and the
  /// positions between [a] and [b].
  double get drawnLength => planLength ?? length;

  String other(String n) => n == from ? to : from;

  /// The same link between other nodes (every setting kept: the flow of an
  /// FCV was lost when a device was inserted next to it).
  GLink withEnds({required String from, required String to}) => GLink(
    id: id,
    from: from,
    to: to,
    kind: kind,
    scope: scope,
    entityId: entityId,
    segmentIndex: segmentIndex,
    length: length,
    pipeSpecId: pipeSpecId,
    tapeSpecId: tapeSpecId,
    computerSized: computerSized,
    usage: usage,
    minorK: minorK,
    depth: depth,
    settingM: settingM,
    settingFlow: settingFlow,
    valveSpecId: valveSpecId,
    pumpSpecId: pumpSpecId,
    speedRatio: speedRatio,
    a: a,
    b: b,
    emitterCountAlong: emitterCountAlong,
    planLength: planLength,
  )..zoneId = zoneId;
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

  /// Position of the first link of every id, checked against [links] at each
  /// lookup: a scan per lookup made every zone network quadratic in the
  /// size of the model.
  Map<String, int>? _linkAt;

  GLink? linkById(String id) {
    final at = _linkAt ??= _indexLinks();
    final i = at[id];
    if (i != null && i < links.length && links[i].id == id) return links[i];
    // added or moved since the index was made: as before, and index again
    for (var k = 0; k < links.length; k++) {
      if (links[k].id == id) {
        _linkAt = null;
        return links[k];
      }
    }
    return null;
  }

  Map<String, int> _indexLinks() {
    final at = <String, int>{};
    for (var k = 0; k < links.length; k++) {
      at.putIfAbsent(links[k].id, () => k);
    }
    return at;
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

  /// The law the network uses for a catalogue curve: a pressure-compensating
  /// one (x < 0.1) compensates from the least pressure of its range,
  /// [minHeadM], an orifice below it (it gave 91 % of its flow at 1 m). One
  /// curve per catalogue curve, so emitters of one model still share it.
  final Map<(EmitterCurve, double), EmitterCurve> _compensated = {};

  EmitterCurve _compensating(EmitterCurve c, double minHeadM) {
    if (!c.isPressureCompensating || !(minHeadM > 0) || c.compensationHead > 0) return c;
    return _compensated[(c, minHeadM)] ??= c.compensatingFrom(minHeadM);
  }

  /// (min x, min y, max x, max y) of [pts].
  static (double, double, double, double) _bounds(List<Pt> pts) {
    var x0 = double.infinity, y0 = double.infinity, x1 = double.negativeInfinity, y1 = double.negativeInfinity;
    for (final p in pts) {
      x0 = math.min(x0, p.x);
      y0 = math.min(y0, p.y);
      x1 = math.max(x1, p.x);
      y1 = math.max(y1, p.y);
    }
    return (x0, y0, x1, y1);
  }

  NetworkModel build() {
    model.terrain = terrain;
    final catalog = project.catalog;
    final linear = project.entities.where((e) => e is PipeEntity || e is SpraylineEntity || e is TapeEntity).toList();
    final points = <Pt>[];
    final splitRequests = <String, List<Pt>>{for (final e in linear) e.id: []};

    List<Pt> ptsOf(Entity e) => (e as PolyEntity).points;
    HydraulicScope scopeOf(Entity e) => e.hydraulicScope ?? HydraulicScope.zone;

    // 1. split requests from point items and T-junctions; a point beyond
    // twice the tolerance of an entity's bounding box is not tried against
    // its segments (a scan of every segment made the build quadratic)
    final boxes = [for (final e in linear) _bounds(ptsOf(e))];
    final margin = 2 * tol + 1e-6;
    // Whether [p] lies on a pipe (not a lateral) of [scopes] other than
    // [exclude]: the end of a lateral joined to its submain.
    bool requestSplit(Pt p, Iterable<HydraulicScope> scopes, {String? exclude}) {
      var onPipe = false;
      for (var k = 0; k < linear.length; k++) {
        final e = linear[k];
        if (e.id == exclude) continue;
        if (!scopes.contains(scopeOf(e))) continue;
        final (x0, y0, x1, y1) = boxes[k];
        if (p.x < x0 - margin || p.x > x1 + margin || p.y < y0 - margin || p.y > y1 + margin) continue;
        final pts = ptsOf(e);
        for (var i = 1; i < pts.length; i++) {
          final (cp, t) = closestPointOnSegment(p, pts[i - 1], pts[i]);
          if (cp.distanceTo(p) > tol) continue;
          if (e is PipeEntity) onPipe = true;
          if (t > 1e-9 && t < 1 - 1e-9) {
            // not at a vertex: split
            if (pts[i - 1].distanceTo(p) > tol && pts[i].distanceTo(p) > tol) splitRequests[e.id]!.add(cp);
          }
        }
      }
      return onPipe;
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
        // 1.6.0 AGB: the hydrant of a traveller lane, the inlet of a furrow set
        case TravellerEntity t:
          requestSplit(t.start, [HydraulicScope.mainline]);
        case FurrowEntity f when f.points.isNotEmpty:
          requestSplit(f.points.first, [HydraulicScope.mainline]);
        default:
          break;
      }
    }
    // Items a lateral may start from (its inlet): valves, junctions, devices.
    final feeders = <HydraulicScope, List<Pt>>{};
    for (final e in project.entities) {
      switch (e) {
        case ControlValveEntity v:
          (feeders[HydraulicScope.zone] ??= []).add(v.position);
        case JunctionEntity j:
          (feeders[j.scope] ??= []).add(j.position);
        case MiscHydraulicEntity m:
          (feeders[m.scope] ??= []).add(m.position);
        case PumpEntity p:
          (feeders[p.scope] ??= []).add(p.position);
        default:
          break;
      }
    }
    bool fed(Pt p, HydraulicScope scope) => feeders[scope]?.any((f) => f.distanceTo(p) <= tol) ?? false;
    // laterals (spraylines and tapes) joined to their submain at the end as
    // drawn only: their emitters are numbered and grouped from that end
    final inletAtEnd = <String>{};
    for (final e in linear) {
      final pts = ptsOf(e);
      if (pts.length < 2) continue;
      final scope = scopeOf(e);
      final atStart = requestSplit(pts.first, [scope], exclude: e.id);
      final atEnd = requestSplit(pts.last, [scope], exclude: e.id);
      if (e is! SpraylineEntity && e is! TapeEntity) continue;
      if ((atEnd || fed(pts.last, scope)) && !(atStart || fed(pts.first, scope))) inletAtEnd.add(e.id);
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
            // 1.6.0 MOD: the item is there but not that nozzle
            model.warnings.add(outlet != null && outlet.nozzles.isNotEmpty ? 'nozzle_missing:${e.id}' : 'outlet_spec_missing:${e.id}');
            model.unconnectedEntities.add(e.id);
            continue;
          }
          final spec = catalog.pipe(s.pipeSpecId);
          final total = polylineLength(pts);
          final n = s.outletCount;
          final first = s.firstOutletDistance;
          final (lo, hi) = _window(nozzle, s.headM);
          final positions = [for (var i = 0; i < n; i++) first + i * s.spacing];
          final fromEnd = inletAtEnd.contains(e.id);
          final lumps = _lump(positions, total, fromEnd: fromEnd);
          final emitterAt = <double, EmitterRef>{};
          for (final (d, cnt, idx) in lumps) {
            emitterAt[d] = EmitterRef(
              entityId: e.id,
              index: idx,
              curve: _compensating(nozzle.curve, nozzle.minHeadM),
              count: cnt,
              nominalHead: s.headM,
              allowedMin: lo,
              allowedMax: hi,
              cv: nozzle.cv,
              offset: s.riserHeight + outlet.riserHeightM + s.depth,
              label: nozzle.name,
              inlet: emitterAt.isEmpty,
            );
          }
          _addLateralLinks(
            e.id,
            pts,
            scope,
            emitterAt,
            usage: PipeUsage.lateral,
            pipeSpecId: spec?.id,
            computerSized: s.computerSized || spec == null,
            depth: s.depth,
            perEmitterK: 0.0,
            inletAtEnd: fromEnd,
          );
        case TapeEntity t:
          final spec = catalog.tape(t.tapeSpecId);
          if (spec == null) {
            model.warnings.add('tape_spec_missing:${e.id}');
            model.unconnectedEntities.add(e.id);
            continue;
          }
          final total = polylineLength(pts);
          final n = spec.emitterSpacingM > 0 ? (total / spec.emitterSpacingM).floor() : 0;
          // the emitters stand every spacing from the inlet: from the start
          // as drawn, or from the end when the tape was drawn towards its
          // submain (numbered from the start either way)
          final fromEnd = inletAtEnd.contains(e.id);
          final positions = fromEnd ? [for (var i = n; i >= 1; i--) total - i * spec.emitterSpacingM] : [for (var i = 1; i <= n; i++) i * spec.emitterSpacingM];
          final lumps = _lump(positions, total, fromEnd: fromEnd);
          final lo = math.max(spec.minHeadM, t.inletHeadM * (1 - spec.tolBelowPct / 100));
          final hi = math.min(spec.maxHeadM, t.inletHeadM * (1 + spec.tolAbovePct / 100));
          final emitterAt = <double, EmitterRef>{};
          for (final (d, cnt, idx) in lumps) {
            emitterAt[d] = EmitterRef(
              entityId: e.id,
              index: idx,
              curve: _compensating(spec.emitter, spec.minHeadM),
              count: cnt,
              nominalHead: t.inletHeadM,
              allowedMin: lo,
              allowedMax: hi,
              cv: spec.cv,
              // a buried tape discharges at the tube, at the node's own
              // elevation (ground − depth): an offset of the depth put the
              // emitters back at the surface (MOT-21)
              offset: 0,
              label: spec.name,
              inlet: emitterAt.isEmpty,
            );
          }
          _addLateralLinks(
            e.id,
            pts,
            scope,
            emitterAt,
            usage: PipeUsage.lateral,
            pipeSpecId: null,
            tapeSpecId: spec.id,
            computerSized: false,
            depth: t.depth,
            perEmitterK: spec.barbK,
            endFlow: t.flushingFlow,
            inletAtEnd: fromEnd,
            regulatorM: t.regulated ? t.inletHeadM : null,
          );
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
              // 1.6.0 MOD: the item is there but not that nozzle
              model.warnings.add(outlet != null && outlet.nozzles.isNotEmpty ? 'nozzle_missing:${e.id}' : 'outlet_spec_missing:${e.id}');
              continue;
            }
            final n = _nodeAt(o.position, o.scope, create: false);
            if (n.id.isEmpty) {
              model.unconnectedEntities.add(e.id);
              continue;
            }
            final (lo, hi) = _window(nozzle, o.headM);
            n.entityIds.add(e.id);
            n.emitters.add(
              EmitterRef(
                entityId: e.id,
                index: -1,
                curve: _compensating(nozzle.curve, nozzle.minHeadM),
                count: 1,
                nominalHead: o.headM,
                allowedMin: lo,
                allowedMax: hi,
                cv: nozzle.cv,
                offset: o.riserHeight + outlet.riserHeightM,
                label: nozzle.name,
              ),
            );
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
          // 1.6.0 AGB: lanes and furrow sets take their water like a pivot
          case TravellerEntity _ || FurrowEntity _:
            final inlet = e is TravellerEntity ? e.start : (e as FurrowEntity).points.firstOrNull;
            final n = inlet == null ? null : _nodeAt(inlet, HydraulicScope.mainline, create: false);
            if (n == null || n.id.isEmpty) {
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
            final l = GLink(
              id: 'cv_${e.id}',
              from: nm.id,
              to: nz.id,
              kind: GLinkKind.controlValve,
              scope: HydraulicScope.mainline,
              entityId: e.id,
              valveSpecId: v.valveSpecId,
              depth: v.depth,
              a: v.position,
              b: v.position,
            );
            _register(l);
            model.valveNodes[e.id] = (nm.id, nz.id);
            if (nz.links.length <= 1) model.warnings.add('valve_no_zone_pipes:${e.id}');
          case PumpEntity p:
            final spec = catalog.pump(p.pumpSpecId);
            if (spec == null) {
              model.warnings.add('pump_spec_missing:${e.id}');
              continue;
            }
            // a fixed-speed motor turns with the mains frequency; a variable
            // speed drive makes its own (its speeds are set by the designer)
            final speed = p.speedRatio * (p.targetPressureM > 0 ? 1 : spec.mainsSpeedRatio(project.params.mainsHz));
            _insertInline(
              e.id,
              p.position,
              p.scope,
              (up, down) => GLink(id: 'pump_${e.id}', from: up, to: down, kind: GLinkKind.pump, scope: p.scope, entityId: e.id, pumpSpecId: spec.id, speedRatio: speed, a: p.position, b: p.position),
            );
          case MiscHydraulicEntity m:
            final spec = catalog.valve(m.valveSpecId);
            if (spec == null) {
              model.warnings.add('valve_spec_missing:${e.id}');
              continue;
            }
            final kind = switch (spec.kind) {
              ValveKind.prv => GLinkKind.prv,
              ValveKind.psv => GLinkKind.psv,
              ValveKind.fcv => GLinkKind.fcv,
              _ => GLinkKind.device,
            };
            final pressureSet = kind == GLinkKind.prv || kind == GLinkKind.psv ? (m.settingM > 0 ? m.settingM : spec.defaultSettingM) : 0.0;
            final flowSet = kind == GLinkKind.fcv ? (m.settingFlow > 0 ? m.settingFlow : spec.maxFlow) : 0.0;
            _insertInline(
              e.id,
              m.position,
              m.scope,
              (up, down) => GLink(
                id: 'dev_${e.id}',
                from: up,
                to: down,
                kind: kind,
                scope: m.scope,
                entityId: e.id,
                valveSpecId: spec.id,
                settingM: pressureSet,
                settingFlow: flowSet,
                a: m.position,
                b: m.position,
              ),
            );
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
        // 1.6.0 AGB
        case TravellerEntity _ || FurrowEntity _:
          final n = model.pivotNodes[e.id];
          if (n == null || !model.mainlineNodes.contains(n)) model.unconnectedEntities.add(e.id);
        default:
          break;
      }
    }
    if (project.params.applyMinorLosses && project.params.minorLossMethod == MinorLossMethod.fittings) _assignFittingLosses();
    return model;
  }

  /// Local losses of the bends and tees the drawing implies (method of the
  /// fitting coefficients, Crane TP-410), added to the K of the zone and
  /// mainline pipe links next to them; laterals and tapes keep only their
  /// emitter barb losses. A vertex turning by 67.5° or more is a 90° elbow,
  /// from 22.5° a 45° elbow; at a node of three or more pipes the straightest
  /// pair is the run (half the run K on each) and the others are branches.
  void _assignFittingLosses() {
    final laterals = {
      for (final e in project.entities)
        if (e is SpraylineEntity || e is TapeEntity) e.id,
    };
    Pt away(GLink l, String nodeId) => l.from == nodeId ? (l.b - l.a).normalized : (l.a - l.b).normalized;
    for (final n in model.nodes.values) {
      final pipes = n.links.where((l) => l.kind == GLinkKind.pipe && !laterals.contains(l.entityId) && l.length > 0).toList();
      if (pipes.length < 2) continue;
      if (pipes.length == 2) {
        final turn = 180 - math.acos(away(pipes[0], n.id).dot(away(pipes[1], n.id)).clamp(-1.0, 1.0)) * 180 / math.pi;
        final k = turn >= 67.5 ? FittingK.elbow90Standard : (turn >= 22.5 ? FittingK.elbow45 : 0.0);
        if (k > 0) (pipes[0].from == n.id ? pipes[0] : pipes[1]).minorK += k;
        continue;
      }
      var run = (0, 1);
      var straightest = 2.0;
      for (var i = 0; i < pipes.length; i++) {
        for (var j = i + 1; j < pipes.length; j++) {
          final c = away(pipes[i], n.id).dot(away(pipes[j], n.id));
          if (c < straightest) {
            straightest = c;
            run = (i, j);
          }
        }
      }
      for (var i = 0; i < pipes.length; i++) {
        pipes[i].minorK += i == run.$1 || i == run.$2 ? FittingK.teeRun / 2 : FittingK.teeBranch;
      }
    }
  }

  Iterable<GLink> links(String entityId) => model.links.where((l) => l.entityId == entityId);

  (double, double) _window(NozzleSpec nozzle, double nominalHead) {
    final (lo, hi) = nozzle.curve.headWindow(nominalHead, below: nozzle.flowTolBelow, above: nozzle.flowTolAbove);
    return (math.max(lo, nozzle.minHeadM), math.min(hi, nozzle.maxHeadM));
  }

  /// Groups outlet positions (increasing) into at most [maxNodesPerLateral]
  /// lumps, from the inlet: the first position, or with [fromEnd] the last.
  /// Returns (distance of lump centroid, count, first index), the lump next
  /// to the inlet first.
  List<(double, int, int)> _lump(List<double> positions, double total, {bool fromEnd = false}) {
    if (positions.isEmpty) return [];
    final k = (positions.length / maxNodesPerLateral).ceil();
    final out = <(double, int, int)>[];
    if (fromEnd) {
      for (var end = positions.length; end > 0; end -= k) {
        final start = math.max(0, end - k);
        final cnt = end - start;
        var sum = 0.0;
        for (var j = end - 1; j >= start; j--) {
          sum += positions[j];
        }
        out.add((math.max(sum / cnt, 0.0), cnt, start));
      }
      return out;
    }
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

  /// Length along the ground of a piece [plan] metres long in plan between
  /// [a] and [b]: √(L² + Δz²) with the ground at both ends (the distance in
  /// plan made the losses and the pipe bought 2 % short at a 20 % slope,
  /// 12 % at 50 %).
  static double _slopeLength(double plan, GNode a, GNode b) {
    final dz = b.ground - a.ground;
    return dz == 0 ? plan : math.sqrt(plan * plan + dz * dz);
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
      final plan = pts[i - 1].distanceTo(pts[i]);
      final len = _slopeLength(plan, a, b);
      final l = GLink(
        id: '${entityId}_${i - 1}',
        from: a.id,
        to: b.id,
        kind: GLinkKind.pipe,
        scope: scope,
        entityId: entityId,
        segmentIndex: i - 1,
        length: len,
        planLength: plan,
        pipeSpecId: pipeSpecId,
        computerSized: computerSized,
        usage: usage,
        depth: depth,
        a: pts[i - 1],
        b: pts[i],
      );
      _register(l);
    }
  }

  void _addLateralLinks(
    String entityId,
    List<Pt> pts,
    HydraulicScope scope,
    Map<double, EmitterRef> emitterAt, {
    required PipeUsage usage,
    String? pipeSpecId,
    String? tapeSpecId,
    bool computerSized = false,
    double depth = 0,
    double perEmitterK = 0,
    double endFlow = 0,
    bool inletAtEnd = false,
    double? regulatorM,
  }) {
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
    // walked from the inlet (the end of a line drawn towards its submain),
    // so the barb losses and the open end of the flushing come out the same
    // whichever way the line was drawn; the links keep the drawn order
    final walk = inletAtEnd ? sorted.reversed : sorted;
    GNode? prev;
    var prevD = 0.0;
    var emittersSince = 0;
    final made = <(GNode, GNode, double, double, Pt, Pt, int)>[];
    for (final d in walk) {
      final p = pointAlongPolyline(pts, d);
      var n = (prev != null && (d - prevD).abs() < tol) ? prev : _nodeAt(p, scope);
      if (prev == null && regulatorM != null) {
        // a regulated inlet: a pressure regulator set to the inlet pressure
        // between the submain and the tape, whose own first node no other
        // item joins
        final inlet = GNode(id: 'n${_seq++}', p: p, ground: n.ground, scope: scope);
        model.nodes[inlet.id] = inlet;
        n.entityIds.add(entityId);
        _register(GLink(id: 'reg_$entityId', from: n.id, to: inlet.id, kind: GLinkKind.prv, scope: scope, entityId: entityId, settingM: regulatorM, depth: depth, a: p, b: p));
        n = inlet;
      }
      n.entityIds.add(entityId);
      final em = emitterAt[d];
      if (em != null) {
        n.emitters.add(em);
        emittersSince += em.count;
      }
      if (prev != null && prev.id != n.id) {
        made.add((prev, n, prevD, d, pointAlongPolyline(pts, prevD), p, emittersSince));
        emittersSince = 0;
      }
      prev = n;
      prevD = d;
    }
    var seg = 0;
    for (final (up, down, du, dd, pu, pd, count) in inletAtEnd ? made.reversed : made) {
      final l = GLink(
        id: '${entityId}_$seg',
        from: inletAtEnd ? down.id : up.id,
        to: inletAtEnd ? up.id : down.id,
        kind: GLinkKind.pipe,
        scope: scope,
        entityId: entityId,
        segmentIndex: seg,
        length: _slopeLength((dd - du).abs(), up, down),
        planLength: (dd - du).abs(),
        pipeSpecId: pipeSpecId,
        tapeSpecId: tapeSpecId,
        computerSized: computerSized,
        usage: usage,
        minorK: perEmitterK * count,
        depth: depth,
        a: inletAtEnd ? pd : pu,
        b: inletAtEnd ? pu : pd,
        emitterCountAlong: count,
      );
      _register(l);
      seg++;
    }
    if (endFlow > 0 && prev != null) {
      prev.emitters.add(
        EmitterRef(
          entityId: entityId,
          index: -2,
          curve: EmitterCurve(k: endFlow, x: 0),
          count: 1,
          nominalHead: 1,
          allowedMin: 0,
          allowedMax: double.infinity,
          cv: 0,
          label: 'flush',
        ),
      );
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
    // on the zone side of a valve the device follows the valve; at a
    // supply every pipe leaves through it (the supply is the source)
    final valveHere = scope == HydraulicScope.zone
        ? [
            for (final e in model.valveNodes.entries)
              if (e.value.$2 == n.id) e.key,
          ]
        : const <String>[];
    if (n.isSupply) {
      upstreamLink = null;
    } else if (valveHere.isNotEmpty) {
      upstreamLink = attached.where((l) => l.kind == GLinkKind.controlValve && l.entityId == valveHere.first).firstOrNull;
    } else if (attached.length >= 2) {
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
      // device at a dead end: treat the single pipe as upstream
      upstreamLink = attached.first;
    }
    final down = GNode(id: 'n${_seq++}', p: p, ground: n.ground, scope: scope);
    model.nodes[down.id] = down;
    _grid.putIfAbsent(_key(p), () => []).add(down);
    down.entityIds.add(entityId);
    final movedValves = <String>{};
    for (final l in attached) {
      if (identical(l, upstreamLink)) continue;
      // move link end from n to down
      final idx = model.links.indexOf(l);
      final moved = l.withEnds(from: l.from == n.id ? down.id : l.from, to: l.to == n.id ? down.id : l.to);
      if (l.kind == GLinkKind.controlValve) movedValves.add(l.entityId);
      model.links[idx] = moved;
      n.links.remove(l);
      final other = model.nodes[l.other(n.id)]!;
      other.links.remove(l);
      other.links.add(moved);
      down.links.add(moved);
    }
    // what is drawn on the device's point is fed through it: a zone valve
    // (its zone demand), a pivot, the outlets of the node
    for (final v in movedValves) {
      final (nm, nz) = model.valveNodes[v]!;
      model.valveNodes[v] = (nm == n.id ? down.id : nm, nz == n.id ? down.id : nz);
    }
    for (final e in model.pivotNodes.entries.toList()) {
      if (e.value == n.id) model.pivotNodes[e.key] = down.id;
    }
    if (n.emitters.isNotEmpty) {
      down.emitters.addAll(n.emitters);
      n.emitters.clear();
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
