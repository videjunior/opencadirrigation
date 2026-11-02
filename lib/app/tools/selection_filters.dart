/// Selection by what items are rather than where they are (CAD-25): the
/// kind and specification that make two items alike, the filters of the
/// quick-select dialog, and the window polygon (lasso) and fence tests.
/// Pure functions over the project, without Flutter.
library;

import 'dart:math' as math;

import '../../core/design/results.dart';
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';

/// The kind of [e] as the interface names it (`tool.<kind>`): pipes of a
/// zone and of the mainline are different kinds.
String selectionKindOf(Entity e) => switch (e) {
  LineEntity _ => 'line',
  PolylineEntity _ => 'polyline',
  CircleEntity _ => 'circle',
  ArcEntity _ => 'arc',
  SplineEntity _ => 'spline',
  HatchEntity _ => 'hatch',
  SymbolEntity _ => 'symbol',
  TextEntity _ => 'text',
  DimensionEntity _ => 'dimension',
  AngularDimensionEntity _ => 'dimAngular',
  RadialDimensionEntity _ => 'dimRadial',
  OrdinateDimensionEntity _ => 'dimOrdinate',
  LeaderEntity _ => 'leader',
  ImageEntity _ => 'image',
  ContourEntity _ => 'contour',
  BreaklineEntity _ => 'breakline',
  SpotHeightEntity _ => 'spot',
  PipeEntity p => p.scope == HydraulicScope.zone ? 'zonePipe' : 'mainPipe',
  SpraylineEntity _ => 'sprayline',
  TapeEntity _ => 'tape',
  OutletEntity _ => 'outlet',
  ControlValveEntity _ => 'valve',
  WaterSupplyEntity _ => 'supply',
  PumpEntity _ => 'pump',
  MiscHydraulicEntity _ => 'misc',
  JunctionEntity _ => 'junction',
  PivotEntity _ => 'pivot',
  AreaEntity _ => 'area',
  ControllerEntity _ => 'controller',
  WireEntity _ => 'wire',
  CommentEntity _ => 'comment',
  RevisionCloudEntity _ => 'revisionCloud',
  _ => e.type.name,
};

/// The catalogue item (or kind of symbol) [e] is made of, as an id: the
/// pipe of a pipe ("" when the design sizes it), the emitter and nozzle of
/// an outlet or a lateral, the tape, the valve, the pump, the fitting; null
/// for an item without one.
String? specOf(Entity e) => switch (e) {
  PipeEntity p => p.pipeSpecId ?? '',
  SpraylineEntity s => '${s.outletSpecId}|${s.nozzleId ?? ''}',
  TapeEntity t => t.tapeSpecId,
  OutletEntity o => '${o.outletSpecId}|${o.nozzleId ?? ''}',
  ControlValveEntity v => v.valveSpecId ?? '',
  PumpEntity p => p.pumpSpecId ?? '',
  MiscHydraulicEntity m => m.valveSpecId ?? '',
  SymbolEntity s => s.kind.name,
  _ => null,
};

/// The name of spec [id] of an item of [kind] (see [specOf]), from the
/// catalogue; [auto] names the pipe left to the design.
String specLabel(Catalog cat, String kind, String id, {required String auto}) {
  String outletNozzle() {
    final parts = id.split('|');
    final o = cat.outlet(parts.first);
    final n = parts.length > 1 && parts[1].isNotEmpty ? o?.nozzle(parts[1])?.name : null;
    return [o?.name ?? parts.first, ?n].join(' · ');
  }

  return switch (kind) {
    'zonePipe' || 'mainPipe' => id.isEmpty ? auto : (cat.pipe(id)?.name ?? id),
    'sprayline' || 'outlet' => outletNozzle(),
    'tape' => cat.tape(id)?.name ?? id,
    'valve' || 'misc' => id.isEmpty ? auto : (cat.valve(id)?.name ?? id),
    'pump' => id.isEmpty ? auto : (cat.pump(id)?.name ?? id),
    _ => id,
  };
}

/// What makes two items alike for "select similar": the same kind and the
/// same catalogue item, or the same kind on the same layer for the drawing.
String similarityKey(Entity e) {
  final spec = specOf(e);
  return spec == null ? '${selectionKindOf(e)}@${e.layer}' : '${selectionKindOf(e)}#$spec';
}

/// A number of an item the quick selection can range over.
enum SelectionProperty { length, area, elevation, head, diameter }

/// [p] of [e] in SI units (m, m², m of head, m of bore), or null when the
/// item has no such number.
double? propertyValue(Entity e, SelectionProperty p, Catalog cat) => switch (p) {
  SelectionProperty.length => switch (e) {
    LineEntity l => l.length,
    ArcEntity a => a.length,
    CircleEntity c => 2 * math.pi * c.radius,
    PolyEntity x when e is! AreaEntity && e is! HatchEntity => x.length,
    _ => null,
  },
  SelectionProperty.area => switch (e) {
    AreaEntity a => a.area,
    HatchEntity h => h.area,
    PolylineEntity l when l.closed => l.area,
    CircleEntity c => math.pi * c.radius * c.radius,
    _ => null,
  },
  SelectionProperty.elevation => switch (e) {
    ContourEntity c => c.elevation,
    SpotHeightEntity s => s.elevation,
    JunctionEntity j => j.fixedElevation,
    _ => null,
  },
  SelectionProperty.head => switch (e) {
    OutletEntity o => o.headM,
    SpraylineEntity s => s.headM,
    TapeEntity t => t.inletHeadM,
    _ => null,
  },
  SelectionProperty.diameter => switch (e) {
    PipeEntity p => cat.pipe(p.pipeSpecId)?.innerDiameter,
    SpraylineEntity s => cat.pipe(s.pipeSpecId)?.innerDiameter,
    TapeEntity t => (cat.tape(t.tapeSpecId)?.innerDiameterMm ?? double.nan) / 1000,
    _ => null,
  },
};

/// What the quick selection keeps: every condition given must hold.
class SelectionQuery {
  SelectionQuery({this.kind, this.layer, this.spec, this.zone, this.property, this.min, this.max});

  /// [selectionKindOf] of the items (null: any kind).
  String? kind;
  String? layer;

  /// [specOf] of the items (null: any).
  String? spec;

  /// Zone name: its valve and outlets and, after a design, its pipes and
  /// laterals (null: any).
  String? zone;
  SelectionProperty? property;

  /// Range of [property] in SI units (either end may be open).
  double? min, max;
}

/// How the items found change the selection.
enum SelectionMode { replace, add, remove, within }

/// Ids of the items of zone [zone]: its valve and outlets by their zone
/// names and, after a design, its pipes, laterals and outlets.
Set<String> zoneMembers(Project p, DesignResults? r, String zone) {
  final z = zone.toLowerCase();
  final out = <String>{};
  for (final e in p.entities) {
    final name = switch (e) {
      ControlValveEntity v => v.zoneName,
      OutletEntity o => o.zoneName,
      PivotEntity v => v.zoneName,
      _ => null,
    };
    if (name != null && name.toLowerCase() == z) out.add(e.id);
  }
  for (final zr in r?.zones.values ?? const <ZoneResult>[]) {
    if (zr.zoneName.toLowerCase() != z) continue;
    out
      ..add(zr.valveId)
      ..addAll(zr.pipes.map((x) => x.entityId))
      ..addAll(zr.outlets.map((x) => x.entityId));
  }
  return out;
}

/// The zone names of the project (valves, outlets, pivots, the design).
List<String> zoneNames(Project p, DesignResults? r) {
  final out = <String>{
    for (final e in p.entities)
      if (e is ControlValveEntity && e.zoneName.isNotEmpty) e.zoneName,
    for (final zr in r?.zones.values ?? const <ZoneResult>[])
      if (zr.zoneName.isNotEmpty) zr.zoneName,
  };
  return out.toList()..sort();
}

/// Whether [e] meets every condition of [q]; [members] are the items of
/// the zone of [q].
bool matchesQuery(Entity e, SelectionQuery q, Catalog cat, {Set<String>? members}) {
  if (q.kind != null && selectionKindOf(e) != q.kind) return false;
  if (q.layer != null && e.layer != q.layer) return false;
  if (q.spec != null && specOf(e) != q.spec) return false;
  if (q.zone != null && !(members ?? const {}).contains(e.id)) return false;
  final prop = q.property;
  if (prop != null) {
    final v = propertyValue(e, prop, cat);
    if (v == null || !v.isFinite) return false;
    if (q.min != null && v < q.min! - 1e-9) return false;
    if (q.max != null && v > q.max! + 1e-9) return false;
  }
  return true;
}

/// The points that stand for [e] in the polygon tests: its vertices (a
/// circle's and an arc's sampled), its corners for the rest.
List<Pt> outlineOf(Entity e) {
  switch (e) {
    case PointEntity p:
      return [p.position];
    case CircleEntity c:
      return [for (var i = 0; i < 24; i++) c.center + Pt.polar(c.radius, 2 * math.pi * i / 24)];
    case SplineEntity s:
      return s.curve();
    default:
      final pts = e.linearPoints;
      if (pts != null && pts.isNotEmpty) return pts;
      final b = e.bounds;
      return [Pt(b.minX, b.minY), Pt(b.maxX, b.minY), Pt(b.maxX, b.maxY), Pt(b.minX, b.maxY)];
  }
}

bool _closedOutline(Entity e) => e is CircleEntity || e.isClosedShape || e.linearPoints == null && e is! PointEntity;

List<(Pt, Pt)> _segments(List<Pt> pts, {bool closed = false}) => [for (var i = 1; i < pts.length; i++) (pts[i - 1], pts[i]), if (closed && pts.length > 2) (pts.last, pts.first)];

bool _crossesSegments(List<(Pt, Pt)> a, List<(Pt, Pt)> b) {
  for (final (p, q) in a) {
    for (final (r, s) in b) {
      if (segmentIntersection(p, q, r, s) != null) return true;
    }
  }
  return false;
}

/// Whether [e] lies inside the polygon [poly] (a lasso): every point of it
/// inside and no side of it crossing the polygon; with [crossing], any
/// part of it inside or crossing.
bool inPolygon(Entity e, List<Pt> poly, {bool crossing = false}) {
  if (poly.length < 3) return false;
  final pts = outlineOf(e);
  if (pts.isEmpty) return false;
  final inside = [for (final p in pts) pointInPolygon(p, poly)];
  final edges = _segments(poly, closed: true);
  final own = _segments(pts, closed: _closedOutline(e));
  if (crossing) return inside.any((x) => x) || _crossesSegments(own, edges);
  return inside.every((x) => x) && !_crossesSegments(own, edges);
}

/// Whether the fence [fence] (an open polyline) crosses [e], or passes
/// within [tolerance] of a point item.
bool crossedByFence(Entity e, List<Pt> fence, double tolerance) {
  if (fence.length < 2) return false;
  final edges = _segments(fence);
  if (e is PointEntity) return edges.any((s) => distanceToSegment(e.position, s.$1, s.$2) <= tolerance);
  final pts = outlineOf(e);
  return _crossesSegments(_segments(pts, closed: _closedOutline(e)), edges);
}
