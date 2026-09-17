/// Drawing and hydraulic entities of a design.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../design/pivot.dart' show PivotKind;
import 'geometry.dart';

enum HydraulicScope { zone, mainline }

enum EntityType {
  line,
  polyline,
  circle,
  arc,
  spline,
  hatch,
  symbol,
  text,
  dimension,
  angularDimension,
  radialDimension,
  leader,
  image,
  contour,
  spotHeight,
  pipe,
  sprayline,
  tape,
  outlet,
  controlValve,
  waterSupply,
  pump,
  misc,
  junction,
  area,
  pivot,
}

/// Default layer names.
class Layers {
  static const drawing = 'DRAWING';
  static const text = 'TEXT';
  static const dimensions = 'DIMENSIONS';
  static const contours = 'CONTOURS';
  static const spotHeights = 'SPOT_HEIGHTS';
  static const zonePipes = 'ZONE_PIPES';
  static const mainlinePipes = 'MAINLINE_PIPES';
  static const spraylines = 'SPRAYLINES';
  static const tapes = 'TAPES';
  static const outlets = 'OUTLETS';
  static const wettedRadii = 'WETTED_RADII';
  static const controlValves = 'CONTROL_VALVES';
  static const waterSupply = 'WATER_SUPPLY';
  static const pumps = 'PUMPS';
  static const misc = 'MISC_HYDRAULIC';
  static const junctions = 'JUNCTIONS';
  static const areas = 'AREAS';
  static const labels = 'LABELS';
  static const images = 'IMAGES';
  static const hatches = 'HATCHES';
  static const symbols = 'SYMBOLS';
  static const pivots = 'PIVOTS';

  static const all = [
    images, drawing, hatches, symbols, text, dimensions, contours, spotHeights, zonePipes, mainlinePipes, spraylines, tapes,
    outlets, wettedRadii, controlValves, waterSupply, pumps, misc, junctions, pivots, areas, labels,
  ];

  static const defaultColors = <String, int>{
    drawing: 0xFFB0BEC5,
    text: 0xFFECEFF1,
    dimensions: 0xFF90A4AE,
    contours: 0xFF8D6E63,
    spotHeights: 0xFFA1887F,
    zonePipes: 0xFF42A5F5,
    mainlinePipes: 0xFF1E88E5,
    spraylines: 0xFF26C6DA,
    tapes: 0xFF66BB6A,
    outlets: 0xFF29B6F6,
    wettedRadii: 0x5529B6F6,
    controlValves: 0xFFFFA726,
    waterSupply: 0xFF7E57C2,
    pumps: 0xFFEF5350,
    misc: 0xFFFFCA28,
    junctions: 0xFF78909C,
    areas: 0x33AED581,
    labels: 0xFFCFD8DC,
    images: 0xFFFFFFFF,
    hatches: 0xFF78909C,
    symbols: 0xFFB0BEC5,
    pivots: 0xFF4DB6AC,
  };
}

sealed class Entity {
  Entity({required this.id, required this.layer, this.name = ''});
  final String id;
  String layer;
  String name;

  EntityType get type;
  Bounds get bounds;
  Entity clone({String? newId});
  Entity translated(Pt d);

  /// Copy with every point mapped through [t] (rotation, mirror, scale…).
  Entity transformed(Affine t);

  /// Editable points shown as grips when the entity is selected.
  List<Pt> get grips;

  /// Moves grip [index] to [p] (in place).
  void setGrip(int index, Pt p);

  /// Pick distance in world units.
  double distanceTo(Pt p);

  Map<String, dynamic> toJson();

  Map<String, dynamic> _base() => {'type': type.name, 'id': id, 'layer': layer, if (name.isNotEmpty) 'name': name};

  static Entity fromJson(Map<String, dynamic> j) {
    final type = EntityType.values.byName(j['type'] as String);
    final id = j['id'] as String;
    final layer = j['layer'] as String? ?? Layers.drawing;
    final name = j['name'] as String? ?? '';
    List<Pt> pts() => ((j['pts'] as List?) ?? []).map((p) => Pt.fromList(p as List)).toList();
    Pt pos() => Pt.fromList(j['p'] as List);
    double d(String k, [double def = 0]) => (j[k] as num?)?.toDouble() ?? def;
    switch (type) {
      case EntityType.line:
        return LineEntity(id: id, layer: layer, name: name, a: Pt.fromList(j['a'] as List), b: Pt.fromList(j['b'] as List));
      case EntityType.polyline:
        return PolylineEntity(id: id, layer: layer, name: name, points: pts(), closed: j['closed'] as bool? ?? false);
      case EntityType.circle:
        return CircleEntity(id: id, layer: layer, name: name, center: pos(), radius: d('r'));
      case EntityType.arc:
        return ArcEntity(id: id, layer: layer, name: name, center: pos(), radius: d('r'), startRad: d('s'), sweepRad: d('w'));
      case EntityType.spline:
        return SplineEntity(id: id, layer: layer, name: name, points: pts(), closed: j['closed'] as bool? ?? false);
      case EntityType.hatch:
        return HatchEntity(id: id, layer: layer, name: name, points: pts(), angleDeg: d('ang', 45), spacing: d('sp', 1), solid: j['solid'] as bool? ?? false);
      case EntityType.symbol:
        return SymbolEntity(id: id, layer: layer, name: name, position: pos(), kind: SymbolKind.values.byName(j['kind'] as String? ?? 'tree'), size: d('size', 2), rotationDeg: d('rot'));
      case EntityType.text:
        return TextEntity(id: id, layer: layer, name: name, position: pos(), text: j['text'] as String? ?? '', height: d('h', 1), rotationDeg: d('rot'));
      case EntityType.dimension:
        return DimensionEntity(id: id, layer: layer, name: name, a: Pt.fromList(j['a'] as List), b: Pt.fromList(j['b'] as List), offset: d('off', 1));
      case EntityType.angularDimension:
        return AngularDimensionEntity(id: id, layer: layer, name: name, vertex: Pt.fromList(j['v'] as List), a: Pt.fromList(j['a'] as List), b: Pt.fromList(j['b'] as List), radius: d('r', 2));
      case EntityType.radialDimension:
        return RadialDimensionEntity(id: id, layer: layer, name: name, center: Pt.fromList(j['c'] as List), point: pos());
      case EntityType.leader:
        return LeaderEntity(id: id, layer: layer, name: name, points: pts(), text: j['text'] as String? ?? '', height: d('h', 1));
      case EntityType.image:
        return ImageEntity(id: id, layer: layer, name: name, origin: pos(), width: d('w', 1), height: d('h', 1), rotationDeg: d('rot'), opacity: d('op', 1), mime: j['mime'] as String? ?? 'image/png', data: j['data'] != null ? base64Decode(j['data'] as String) : null, source: j['src'] as String? ?? '');
      case EntityType.contour:
        return ContourEntity(id: id, layer: layer, name: name, points: pts(), elevation: d('z'), derived: j['gen'] as bool? ?? false);
      case EntityType.spotHeight:
        return SpotHeightEntity(id: id, layer: layer, name: name, position: pos(), elevation: d('z'));
      case EntityType.pipe:
        return PipeEntity(id: id, layer: layer, name: name, points: pts(), scope: HydraulicScope.values.byName(j['scope'] as String), pipeSpecId: j['spec'] as String?, computerSized: j['auto'] as bool? ?? true, depth: d('depth'));
      case EntityType.sprayline:
        return SpraylineEntity(id: id, layer: layer, name: name, points: pts(), pipeSpecId: j['spec'] as String?, computerSized: j['auto'] as bool? ?? true, outletSpecId: j['outlet'] as String? ?? '', nozzleId: j['nozzle'] as String?, headM: d('head', 20), spacing: d('sp', 5), offset: d('off', 0), arcDeg: d('arc', 360), riserHeight: d('riser'), depth: d('depth'));
      case EntityType.tape:
        return TapeEntity(id: id, layer: layer, name: name, points: pts(), tapeSpecId: j['spec'] as String? ?? '', inletHeadM: d('inlet', 10), regulated: j['reg'] as bool? ?? false, submainMinHeadM: d('submin', 0), depth: d('depth'), flushingFlow: d('flush'));
      case EntityType.outlet:
        return OutletEntity(id: id, layer: layer, name: name, position: pos(), scope: HydraulicScope.values.byName(j['scope'] as String? ?? 'zone'), outletSpecId: j['outlet'] as String? ?? '', nozzleId: j['nozzle'] as String?, headM: d('head', 20), arcDeg: d('arc', 360), orientationDeg: d('rot'), riserHeight: d('riser'), zoneName: j['zone'] as String? ?? '');
      case EntityType.controlValve:
        return ControlValveEntity(id: id, layer: layer, name: name, position: pos(), valveSpecId: j['spec'] as String?, zoneName: j['zone'] as String? ?? name, orientationDeg: d('rot'), fixedDownstreamHeadM: (j['fixed'] as num?)?.toDouble(), depth: d('depth'));
      case EntityType.waterSupply:
        return WaterSupplyEntity(id: id, layer: layer, name: name, position: pos(), calculatePressure: j['calc'] as bool? ?? true, designHeadM: d('dh'), maxHeadM: d('mh'), designFlow: d('dq'), maxFlow: d('mq'), waterLevelOffsetM: d('wl'));
      case EntityType.pump:
        return PumpEntity(id: id, layer: layer, name: name, position: pos(), pumpSpecId: j['spec'] as String?, speedRatio: d('speed', 1), orientationDeg: d('rot'), scope: HydraulicScope.values.byName(j['scope'] as String? ?? 'mainline'));
      case EntityType.misc:
        return MiscHydraulicEntity(id: id, layer: layer, name: name, position: pos(), valveSpecId: j['spec'] as String?, scope: HydraulicScope.values.byName(j['scope'] as String? ?? 'mainline'), settingM: d('set'), orientationDeg: d('rot'));
      case EntityType.junction:
        return JunctionEntity(id: id, layer: layer, name: name, position: pos(), scope: HydraulicScope.values.byName(j['scope'] as String? ?? 'zone'), fixedElevation: (j['z'] as num?)?.toDouble());
      case EntityType.area:
        return AreaEntity(
          id: id, layer: layer, name: name, points: pts(), netDepthMmPerDay: d('depth', 5), efficiency: d('eff', 0.9), crop: j['crop'] as String? ?? '',
          emittersPerPlant: (j['epp'] as num?)?.toInt() ?? 0, useWaterBalance: j['wb'] as bool? ?? false, etoMmDay: d('eto', 5), kc: d('kc', 1), awcMmPerM: d('awc', 120), rootDepthM: d('root', 0.6), mad: d('mad', 0.5),
          plantSpacingM: d('psp'), rowSpacingM: d('rsp'), wettedFraction: d('wf', 1),
        );
      case EntityType.pivot:
        return PivotEntity(
          id: id, layer: layer, name: name, center: pos(), radiusM: d('r', 400), angleDeg: d('ang'), kind: PivotKind.values.byName(j['kind'] as String? ?? 'pivot'), travelM: d('travel'),
          spanLengthM: d('span', 50), pipeSpecId: j['spec'] as String?, pipeInnerMm: d('idmm', 162), hazenC: d('c', 130), pipeHeightM: d('hp', 3.5), endPressureM: d('hend', 14),
          endGunFlow: d('qg'), endGunPressureM: d('hg'), endThrowM: d('throw', 5), grossDepthMm: d('depth', 8), hoursPerCycle: d('hours', 24), wettedWidthM: d('ww', 18),
          machineLossM: d('hm', 2), maxAppRateMmH: d('imax'), sectorDeg: d('sector', 360), machineCost: d('cost'), zoneName: j['zone'] as String? ?? '',
          sprinklerSpacingM: d('ssp', 2.5), sprinklerSpecId: j['sspec'] as String?, regulatorSpecId: j['rspec'] as String?, towerCost: d('tcost'),
        );
    }
  }
}

mixin PointEntity on Entity {
  Pt get position;
  set position(Pt p);
  @override
  Bounds get bounds => Bounds(position.x, position.y, position.x, position.y);
  @override
  double distanceTo(Pt p) => position.distanceTo(p);
  @override
  List<Pt> get grips => [position];
  @override
  void setGrip(int index, Pt p) => position = p;
}

mixin PolyEntity on Entity {
  List<Pt> get points;
  double get length => polylineLength(points);
  @override
  Bounds get bounds => Bounds.ofPoints(points);
  @override
  double distanceTo(Pt p) {
    var best = double.infinity;
    for (var i = 1; i < points.length; i++) {
      best = math.min(best, distanceToSegment(p, points[i - 1], points[i]));
    }
    if (points.length == 1) best = points.first.distanceTo(p);
    return best;
  }

  @override
  List<Pt> get grips => points;
  @override
  void setGrip(int index, Pt p) {
    if (index >= 0 && index < points.length) points[index] = p;
  }

  void insertVertex(int index, Pt p) => points.insert(index.clamp(0, points.length), p);
  void removeVertex(int index) {
    if (points.length > 2 && index >= 0 && index < points.length) points.removeAt(index);
  }
}

List<List<double>> _ptsJson(List<Pt> pts) => pts.map((p) => p.toList()).toList();
List<Pt> _map(List<Pt> pts, Affine t) => pts.map(t.apply).toList();
double _rotDeg(Affine t, double deg) => radToDeg(t.transformAngle(degToRad(deg)));

// ---------------------------------------------------------------- drawing

class LineEntity extends Entity {
  LineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.a, required this.b});
  Pt a, b;
  @override
  EntityType get type => EntityType.line;
  @override
  Bounds get bounds => Bounds.ofPoints([a, b]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, a, b);
  double get length => a.distanceTo(b);
  @override
  List<Pt> get grips => [a, b];
  @override
  void setGrip(int index, Pt p) => index == 0 ? a = p : b = p;
  @override
  LineEntity clone({String? newId}) => LineEntity(id: newId ?? id, layer: layer, name: name, a: a, b: b);
  @override
  LineEntity translated(Pt d) => LineEntity(id: id, layer: layer, name: name, a: a + d, b: b + d);
  @override
  LineEntity transformed(Affine t) => LineEntity(id: id, layer: layer, name: name, a: t.apply(a), b: t.apply(b));
  @override
  Map<String, dynamic> toJson() => {..._base(), 'a': a.toList(), 'b': b.toList()};
}

class PolylineEntity extends Entity with PolyEntity {
  PolylineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.points, this.closed = false});

  /// Perimeter when closed, open length otherwise.
  @override
  double get length => polylineLength(points) + (closed && points.length > 2 ? points.last.distanceTo(points.first) : 0);
  @override
  List<Pt> points;
  bool closed;
  @override
  EntityType get type => EntityType.polyline;
  @override
  double distanceTo(Pt p) {
    var d = super.distanceTo(p);
    if (closed && points.length > 2) d = math.min(d, distanceToSegment(p, points.last, points.first));
    return d;
  }

  double get area => closed ? polygonArea(points).abs() : 0;
  @override
  PolylineEntity clone({String? newId}) => PolylineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), closed: closed);
  @override
  PolylineEntity translated(Pt d) => PolylineEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), closed: closed);
  @override
  PolylineEntity transformed(Affine t) => PolylineEntity(id: id, layer: layer, name: name, points: _map(points, t), closed: closed);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'closed': closed};
}

class CircleEntity extends Entity {
  CircleEntity({required super.id, super.layer = Layers.drawing, super.name, required this.center, required this.radius});
  Pt center;
  double radius;
  @override
  EntityType get type => EntityType.circle;
  @override
  Bounds get bounds => Bounds(center.x - radius, center.y - radius, center.x + radius, center.y + radius);
  @override
  double distanceTo(Pt p) => (center.distanceTo(p) - radius).abs();
  @override
  List<Pt> get grips => [center, center + Pt(radius, 0), center + Pt(0, radius), center + Pt(-radius, 0), center + Pt(0, -radius)];
  @override
  void setGrip(int index, Pt p) {
    if (index == 0) {
      center = p;
    } else {
      radius = math.max(1e-6, center.distanceTo(p));
    }
  }

  @override
  CircleEntity clone({String? newId}) => CircleEntity(id: newId ?? id, layer: layer, name: name, center: center, radius: radius);
  @override
  CircleEntity translated(Pt d) => CircleEntity(id: id, layer: layer, name: name, center: center + d, radius: radius);
  @override
  CircleEntity transformed(Affine t) => CircleEntity(id: id, layer: layer, name: name, center: t.apply(center), radius: radius * t.scale);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': center.toList(), 'r': radius};
}

class ArcEntity extends Entity {
  ArcEntity({required super.id, super.layer = Layers.drawing, super.name, required this.center, required this.radius, required this.startRad, required this.sweepRad});
  Pt center;
  double radius;
  double startRad;
  double sweepRad;
  @override
  EntityType get type => EntityType.arc;
  Pt get startPoint => center + Pt.polar(radius, startRad);
  Pt get endPoint => center + Pt.polar(radius, startRad + sweepRad);
  Pt get midPoint => center + Pt.polar(radius, startRad + sweepRad / 2);
  double get length => radius * sweepRad.abs();

  /// Sampled polyline along the arc.
  List<Pt> polyline([int segments = 32]) {
    final n = math.max(2, (segments * sweepRad.abs() / (2 * math.pi)).ceil());
    return [for (var i = 0; i <= n; i++) center + Pt.polar(radius, startRad + sweepRad * i / n)];
  }

  @override
  Bounds get bounds => Bounds.ofPoints(polyline());
  @override
  double distanceTo(Pt p) {
    final ang = (p - center).angle;
    var rel = (ang - startRad) % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;
    final sweep = sweepRad.abs();
    final inside = sweepRad >= 0 ? rel <= sweep : (2 * math.pi - rel) <= sweep;
    if (inside) return (center.distanceTo(p) - radius).abs();
    return math.min(p.distanceTo(startPoint), p.distanceTo(endPoint));
  }

  @override
  List<Pt> get grips => [center, startPoint, endPoint, midPoint];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        center = p;
      case 1:
        final end = startPoint + (endPoint - startPoint);
        final a = arcThrough(p, midPoint, end);
        if (a != null) _set(a);
      case 2:
        final a = arcThrough(startPoint, midPoint, p);
        if (a != null) _set(a);
      default:
        final a = arcThrough(startPoint, p, endPoint);
        if (a != null) _set(a);
    }
  }

  void _set((Pt, double, double, double) a) {
    center = a.$1;
    radius = a.$2;
    startRad = a.$3;
    sweepRad = a.$4;
  }

  @override
  ArcEntity clone({String? newId}) => ArcEntity(id: newId ?? id, layer: layer, name: name, center: center, radius: radius, startRad: startRad, sweepRad: sweepRad);
  @override
  ArcEntity translated(Pt d) => ArcEntity(id: id, layer: layer, name: name, center: center + d, radius: radius, startRad: startRad, sweepRad: sweepRad);
  @override
  ArcEntity transformed(Affine t) => ArcEntity(id: id, layer: layer, name: name, center: t.apply(center), radius: radius * t.scale, startRad: t.transformAngle(startRad), sweepRad: t.isMirror ? -sweepRad : sweepRad);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': center.toList(), 'r': radius, 's': startRad, 'w': sweepRad};
}

/// Smooth curve through fit points (centripetal Catmull-Rom).
class SplineEntity extends Entity with PolyEntity {
  SplineEntity({required super.id, super.layer = Layers.drawing, super.name, required this.points, this.closed = false});
  @override
  List<Pt> points;
  bool closed;
  @override
  EntityType get type => EntityType.spline;
  List<Pt> curve([int segments = 8]) => catmullRom(points, closed: closed, segments: segments);
  @override
  double get length => polylineLength(curve());
  @override
  Bounds get bounds => Bounds.ofPoints(curve());
  @override
  double distanceTo(Pt p) {
    final c = curve();
    var best = double.infinity;
    for (var i = 1; i < c.length; i++) {
      best = math.min(best, distanceToSegment(p, c[i - 1], c[i]));
    }
    return best;
  }

  @override
  SplineEntity clone({String? newId}) => SplineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), closed: closed);
  @override
  SplineEntity translated(Pt d) => SplineEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), closed: closed);
  @override
  SplineEntity transformed(Affine t) => SplineEntity(id: id, layer: layer, name: name, points: _map(points, t), closed: closed);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'closed': closed};
}

/// Hatched (or solid filled) polygon.
class HatchEntity extends Entity with PolyEntity {
  HatchEntity({required super.id, super.layer = Layers.hatches, super.name, required this.points, this.angleDeg = 45, this.spacing = 1, this.solid = false});
  @override
  List<Pt> points;
  double angleDeg;
  double spacing;
  bool solid;
  @override
  EntityType get type => EntityType.hatch;
  double get area => polygonArea(points).abs();
  List<List<Pt>> patternLines() => solid ? const [] : hatchLines(points, degToRad(angleDeg), spacing);
  @override
  double distanceTo(Pt p) => pointInPolygon(p, points) ? 0 : math.min(super.distanceTo(p), points.length > 2 ? distanceToSegment(p, points.last, points.first) : double.infinity);
  @override
  HatchEntity clone({String? newId}) => HatchEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), angleDeg: angleDeg, spacing: spacing, solid: solid);
  @override
  HatchEntity translated(Pt d) => clone()..points = points.map((p) => p + d).toList();
  @override
  HatchEntity transformed(Affine t) => HatchEntity(id: id, layer: layer, name: name, points: _map(points, t), angleDeg: _rotDeg(t, angleDeg), spacing: spacing * t.scale, solid: solid);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'ang': angleDeg, 'sp': spacing, 'solid': solid};
}

enum SymbolKind { northArrow, tree, building, tank, well, valveBox, pumpHouse, gate, filterStation }

/// Vector symbol (north arrow, tree, building…), sized in world metres.
class SymbolEntity extends Entity with PointEntity {
  SymbolEntity({required super.id, super.layer = Layers.symbols, super.name, required this.position, this.kind = SymbolKind.tree, this.size = 2, this.rotationDeg = 0});
  @override
  Pt position;
  SymbolKind kind;
  double size;
  double rotationDeg;
  @override
  EntityType get type => EntityType.symbol;
  @override
  Bounds get bounds => Bounds(position.x - size, position.y - size, position.x + size, position.y + size);
  @override
  double distanceTo(Pt p) => math.max(0, position.distanceTo(p) - size * 0.7);

  /// Glyph strokes in world coordinates (unit glyph scaled by [size]).
  List<List<Pt>> strokes() {
    final t = Affine.rotation(degToRad(rotationDeg)).then(Affine.scaling(size)).then(Affine.translation(position));
    List<Pt> poly(List<List<double>> pts) => [for (final p in pts) t.apply(Pt(p[0], p[1]))];
    List<Pt> circle(double cx, double cy, double r, [int n = 24]) => [for (var i = 0; i <= n; i++) t.apply(Pt(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)))];
    switch (kind) {
      case SymbolKind.northArrow:
        return [
          poly([[0, -1], [0, 1]]),
          poly([[-0.25, 0.55], [0, 1], [0.25, 0.55], [0, 0.7], [-0.25, 0.55]]),
          poly([[-0.18, -0.5], [-0.18, -0.15], [0.18, -0.5], [0.18, -0.15]]), // "N"
        ];
      case SymbolKind.tree:
        return [circle(0, 0, 1), circle(0, 0, 0.08), poly([[0, 0], [0.7, 0.7]]), poly([[0, 0], [-0.7, 0.7]]), poly([[0, 0], [0, -1]])];
      case SymbolKind.building:
        return [poly([[-1, -0.7], [1, -0.7], [1, 0.7], [-1, 0.7], [-1, -0.7]]), poly([[-1, -0.7], [1, 0.7]]), poly([[-1, 0.7], [1, -0.7]])];
      case SymbolKind.tank:
        return [circle(0, 0, 1), circle(0, 0, 0.8), poly([[-0.5, 0], [0.5, 0]]), poly([[0, -0.5], [0, 0.5]])];
      case SymbolKind.well:
        return [circle(0, 0, 0.8), poly([[-0.8, 0], [0.8, 0]]), poly([[0, 0.8], [0, -0.8]]), poly([[-0.57, -0.57], [0.57, 0.57]]), poly([[-0.57, 0.57], [0.57, -0.57]])];
      case SymbolKind.valveBox:
        return [poly([[-1, -0.6], [1, -0.6], [1, 0.6], [-1, 0.6], [-1, -0.6]]), poly([[-0.5, -0.3], [0.5, 0.3], [0.5, -0.3], [-0.5, 0.3], [-0.5, -0.3]])];
      case SymbolKind.pumpHouse:
        return [poly([[-1, -0.8], [1, -0.8], [1, 0.4], [0, 1], [-1, 0.4], [-1, -0.8]]), circle(0, -0.1, 0.35), poly([[0.35, -0.1], [0.7, -0.1]])];
      case SymbolKind.gate:
        return [poly([[-1, 0], [1, 0]]), poly([[-1, -0.3], [-1, 0.3]]), poly([[1, -0.3], [1, 0.3]]), poly([[-0.6, 0], [-0.6, 0.5], [0.6, 0.5], [0.6, 0]])];
      case SymbolKind.filterStation:
        return [poly([[-1, -0.6], [1, -0.6], [1, 0.6], [-1, 0.6], [-1, -0.6]]), poly([[-0.6, -0.3], [-0.2, 0.3]]), poly([[-0.2, -0.3], [0.2, 0.3]]), poly([[0.2, -0.3], [0.6, 0.3]])];
    }
  }

  @override
  SymbolEntity clone({String? newId}) => SymbolEntity(id: newId ?? id, layer: layer, name: name, position: position, kind: kind, size: size, rotationDeg: rotationDeg);
  @override
  SymbolEntity translated(Pt d) => clone()..position = position + d;
  @override
  SymbolEntity transformed(Affine t) => SymbolEntity(id: id, layer: layer, name: name, position: t.apply(position), kind: kind, size: size * t.scale, rotationDeg: _rotDeg(t, rotationDeg));
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'kind': kind.name, 'size': size, 'rot': rotationDeg};
}

class TextEntity extends Entity with PointEntity {
  TextEntity({required super.id, super.layer = Layers.text, super.name, required this.position, required this.text, this.height = 1, this.rotationDeg = 0});
  @override
  Pt position;
  String text;
  double height;
  double rotationDeg;
  @override
  EntityType get type => EntityType.text;
  @override
  Bounds get bounds => Bounds(position.x, position.y, position.x + height * 0.6 * text.length, position.y + height);
  @override
  double distanceTo(Pt p) {
    final b = bounds;
    if (b.contains(p)) return 0;
    return position.distanceTo(p);
  }

  @override
  TextEntity clone({String? newId}) => TextEntity(id: newId ?? id, layer: layer, name: name, position: position, text: text, height: height, rotationDeg: rotationDeg);
  @override
  TextEntity translated(Pt d) => TextEntity(id: id, layer: layer, name: name, position: position + d, text: text, height: height, rotationDeg: rotationDeg);
  @override
  TextEntity transformed(Affine t) => TextEntity(id: id, layer: layer, name: name, position: t.apply(position), text: text, height: height * t.scale, rotationDeg: _rotDeg(t, rotationDeg));
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'text': text, 'h': height, 'rot': rotationDeg};
}

class DimensionEntity extends Entity {
  DimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.a, required this.b, this.offset = 1});
  Pt a, b;
  double offset;
  @override
  EntityType get type => EntityType.dimension;
  double get length => a.distanceTo(b);
  Pt get normal => (b - a).normalized.perpendicular;
  @override
  Bounds get bounds => Bounds.ofPoints([a, b, a + normal * offset, b + normal * offset]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, a + normal * offset, b + normal * offset);
  @override
  List<Pt> get grips => [a, b, Pt.lerp(a, b, 0.5) + normal * offset];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        a = p;
      case 1:
        b = p;
      default:
        offset = (p - a).dot(normal);
    }
  }

  @override
  DimensionEntity clone({String? newId}) => DimensionEntity(id: newId ?? id, layer: layer, name: name, a: a, b: b, offset: offset);
  @override
  DimensionEntity translated(Pt d) => DimensionEntity(id: id, layer: layer, name: name, a: a + d, b: b + d, offset: offset);
  @override
  DimensionEntity transformed(Affine t) => DimensionEntity(id: id, layer: layer, name: name, a: t.apply(a), b: t.apply(b), offset: offset * t.scale * (t.isMirror ? -1 : 1));
  @override
  Map<String, dynamic> toJson() => {..._base(), 'a': a.toList(), 'b': b.toList(), 'off': offset};
}

/// Angle between the rays vertex→a and vertex→b, drawn as an arc of [radius].
class AngularDimensionEntity extends Entity {
  AngularDimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.vertex, required this.a, required this.b, this.radius = 2});
  Pt vertex, a, b;
  double radius;
  @override
  EntityType get type => EntityType.angularDimension;
  double get startRad => (a - vertex).angle;

  /// Counter-clockwise sweep from a to b, in (0, 2π).
  double get sweepRad {
    var s = ((b - vertex).angle - startRad) % (2 * math.pi);
    if (s < 0) s += 2 * math.pi;
    return s;
  }

  double get angleDeg => radToDeg(sweepRad);
  List<Pt> arcPoints([int segments = 32]) {
    final n = math.max(2, (segments * sweepRad / (2 * math.pi)).ceil());
    return [for (var i = 0; i <= n; i++) vertex + Pt.polar(radius, startRad + sweepRad * i / n)];
  }

  Pt get textPoint => vertex + Pt.polar(radius * 1.15, startRad + sweepRad / 2);
  @override
  Bounds get bounds => Bounds.ofPoints([vertex, a, b, ...arcPoints(8)]);
  @override
  double distanceTo(Pt p) {
    final pts = arcPoints();
    var best = math.min(distanceToSegment(p, vertex, a), distanceToSegment(p, vertex, b));
    for (var i = 1; i < pts.length; i++) {
      best = math.min(best, distanceToSegment(p, pts[i - 1], pts[i]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [vertex, a, b, vertex + Pt.polar(radius, startRad + sweepRad / 2)];
  @override
  void setGrip(int index, Pt p) {
    switch (index) {
      case 0:
        vertex = p;
      case 1:
        a = p;
      case 2:
        b = p;
      default:
        radius = math.max(0.1, vertex.distanceTo(p));
    }
  }

  @override
  AngularDimensionEntity clone({String? newId}) => AngularDimensionEntity(id: newId ?? id, layer: layer, name: name, vertex: vertex, a: a, b: b, radius: radius);
  @override
  AngularDimensionEntity translated(Pt d) => AngularDimensionEntity(id: id, layer: layer, name: name, vertex: vertex + d, a: a + d, b: b + d, radius: radius);
  @override
  AngularDimensionEntity transformed(Affine t) => t.isMirror
      ? AngularDimensionEntity(id: id, layer: layer, name: name, vertex: t.apply(vertex), a: t.apply(b), b: t.apply(a), radius: radius * t.scale)
      : AngularDimensionEntity(id: id, layer: layer, name: name, vertex: t.apply(vertex), a: t.apply(a), b: t.apply(b), radius: radius * t.scale);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'v': vertex.toList(), 'a': a.toList(), 'b': b.toList(), 'r': radius};
}

/// Radius dimension from [center] to [point] on the circle.
class RadialDimensionEntity extends Entity {
  RadialDimensionEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.center, required this.point});
  Pt center, point;
  @override
  EntityType get type => EntityType.radialDimension;
  double get radius => center.distanceTo(point);
  @override
  Bounds get bounds => Bounds.ofPoints([center, point]);
  @override
  double distanceTo(Pt p) => distanceToSegment(p, center, point);
  @override
  List<Pt> get grips => [center, point];
  @override
  void setGrip(int index, Pt p) => index == 0 ? center = p : point = p;
  @override
  RadialDimensionEntity clone({String? newId}) => RadialDimensionEntity(id: newId ?? id, layer: layer, name: name, center: center, point: point);
  @override
  RadialDimensionEntity translated(Pt d) => RadialDimensionEntity(id: id, layer: layer, name: name, center: center + d, point: point + d);
  @override
  RadialDimensionEntity transformed(Affine t) => RadialDimensionEntity(id: id, layer: layer, name: name, center: t.apply(center), point: t.apply(point));
  @override
  Map<String, dynamic> toJson() => {..._base(), 'c': center.toList(), 'p': point.toList()};
}

/// Leader: arrow polyline ending at a text note.
class LeaderEntity extends Entity with PolyEntity {
  LeaderEntity({required super.id, super.layer = Layers.dimensions, super.name, required this.points, this.text = '', this.height = 1});
  @override
  List<Pt> points;
  String text;
  double height;
  @override
  EntityType get type => EntityType.leader;
  Pt get textPosition => points.isEmpty ? Pt.zero : points.last;
  @override
  Bounds get bounds => Bounds.ofPoints([...points, if (points.isNotEmpty) points.last + Pt(height * 0.6 * text.length, height)]);
  @override
  LeaderEntity clone({String? newId}) => LeaderEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), text: text, height: height);
  @override
  LeaderEntity translated(Pt d) => clone()..points = points.map((p) => p + d).toList();
  @override
  LeaderEntity transformed(Affine t) => LeaderEntity(id: id, layer: layer, name: name, points: _map(points, t), text: text, height: height * t.scale);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'text': text, 'h': height};
}

/// Raster image (georeferenced background, aerial photo, scanned plan).
/// [origin] is the bottom-left corner in world metres; the image spans
/// [width] × [height] metres rotated by [rotationDeg] about the origin.
class ImageEntity extends Entity {
  ImageEntity({required super.id, super.layer = Layers.images, super.name, required this.origin, required this.width, required this.height, this.rotationDeg = 0, this.opacity = 1, this.mime = 'image/png', this.data, this.source = ''});
  Pt origin;
  double width;
  double height;
  double rotationDeg;
  double opacity;
  String mime;

  /// Encoded image bytes (PNG/JPEG); null when the file was not embedded.
  Uint8List? data;
  String source;
  @override
  EntityType get type => EntityType.image;

  /// Corners: bottom-left, bottom-right, top-right, top-left.
  List<Pt> get corners {
    final r = degToRad(rotationDeg);
    final u = Pt.polar(width, r), v = Pt.polar(height, r + math.pi / 2);
    return [origin, origin + u, origin + u + v, origin + v];
  }

  @override
  Bounds get bounds => Bounds.ofPoints(corners);
  @override
  double distanceTo(Pt p) {
    final c = corners;
    if (pointInPolygon(p, c)) return 0;
    var best = double.infinity;
    for (var i = 0; i < 4; i++) {
      best = math.min(best, distanceToSegment(p, c[i], c[(i + 1) % 4]));
    }
    return best;
  }

  @override
  List<Pt> get grips => corners;
  @override
  void setGrip(int index, Pt p) {
    final r = degToRad(rotationDeg);
    final u = Pt.polar(1, r), v = Pt.polar(1, r + math.pi / 2);
    switch (index) {
      case 0:
        origin = p;
      case 1:
        width = math.max(0.01, (p - origin).dot(u));
      case 2:
        width = math.max(0.01, (p - origin).dot(u));
        height = math.max(0.01, (p - origin).dot(v));
      default:
        height = math.max(0.01, (p - origin).dot(v));
    }
  }

  @override
  ImageEntity clone({String? newId}) => ImageEntity(id: newId ?? id, layer: layer, name: name, origin: origin, width: width, height: height, rotationDeg: rotationDeg, opacity: opacity, mime: mime, data: data, source: source);
  @override
  ImageEntity translated(Pt d) => clone()..origin = origin + d;
  @override
  ImageEntity transformed(Affine t) {
    final c = corners.map(t.apply).toList();
    final e = clone();
    e.origin = t.isMirror ? c[1] : c[0];
    e.width = width * t.scale;
    e.height = height * t.scale;
    // a mirrored image keeps its raster and is placed on the mirrored
    // rectangle: origin at the mirrored second corner, bottom edge towards
    // the mirrored first corner
    e.rotationDeg = t.isMirror ? radToDeg((c[0] - c[1]).angle) : radToDeg((c[1] - c[0]).angle);
    return e;
  }

  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': origin.toList(), 'w': width, 'h': height, 'rot': rotationDeg, 'op': opacity, 'mime': mime, if (data != null) 'data': base64Encode(data!), if (source.isNotEmpty) 'src': source};
}

// ---------------------------------------------------------------- terrain

class ContourEntity extends Entity with PolyEntity {
  ContourEntity({required super.id, super.layer = Layers.contours, super.name, required this.points, required this.elevation, this.derived = false});
  @override
  List<Pt> points;
  double elevation;

  /// Generated from the terrain model (not a survey input): drawn, exported,
  /// but not fed back into the DTM.
  bool derived;
  @override
  EntityType get type => EntityType.contour;
  @override
  ContourEntity clone({String? newId}) => ContourEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), elevation: elevation, derived: derived);
  @override
  ContourEntity translated(Pt d) => ContourEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), elevation: elevation, derived: derived);
  @override
  ContourEntity transformed(Affine t) => ContourEntity(id: id, layer: layer, name: name, points: _map(points, t), elevation: elevation, derived: derived);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'z': elevation, if (derived) 'gen': true};
}

class SpotHeightEntity extends Entity with PointEntity {
  SpotHeightEntity({required super.id, super.layer = Layers.spotHeights, super.name, required this.position, required this.elevation});
  @override
  Pt position;
  double elevation;
  @override
  EntityType get type => EntityType.spotHeight;
  @override
  SpotHeightEntity clone({String? newId}) => SpotHeightEntity(id: newId ?? id, layer: layer, name: name, position: position, elevation: elevation);
  @override
  SpotHeightEntity translated(Pt d) => SpotHeightEntity(id: id, layer: layer, name: name, position: position + d, elevation: elevation);
  @override
  SpotHeightEntity transformed(Affine t) => SpotHeightEntity(id: id, layer: layer, name: name, position: t.apply(position), elevation: elevation);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'z': elevation};
}

// ---------------------------------------------------------------- hydraulic (linear)

class PipeEntity extends Entity with PolyEntity {
  PipeEntity({required super.id, String? layer, super.name, required this.points, required this.scope, this.pipeSpecId, this.computerSized = true, this.depth = 0})
      : super(layer: layer ?? (scope == HydraulicScope.zone ? Layers.zonePipes : Layers.mainlinePipes));
  @override
  List<Pt> points;
  HydraulicScope scope;
  String? pipeSpecId;
  bool computerSized;
  double depth;
  @override
  EntityType get type => EntityType.pipe;
  @override
  PipeEntity clone({String? newId}) => PipeEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), scope: scope, pipeSpecId: pipeSpecId, computerSized: computerSized, depth: depth);
  @override
  PipeEntity translated(Pt d) => PipeEntity(id: id, layer: layer, name: name, points: points.map((p) => p + d).toList(), scope: scope, pipeSpecId: pipeSpecId, computerSized: computerSized, depth: depth);
  @override
  PipeEntity transformed(Affine t) => clone()..points = _map(points, t);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'scope': scope.name, if (pipeSpecId != null) 'spec': pipeSpecId, 'auto': computerSized, 'depth': depth};
}

/// Lateral with equally spaced outlets (a "connected" sprayline: analysed as one unit).
class SpraylineEntity extends Entity with PolyEntity {
  SpraylineEntity({
    required super.id,
    super.layer = Layers.spraylines,
    super.name,
    required this.points,
    this.pipeSpecId,
    this.computerSized = true,
    required this.outletSpecId,
    this.nozzleId,
    this.headM = 20,
    this.spacing = 5,
    this.offset = 0,
    this.arcDeg = 360,
    this.riserHeight = 0,
    this.depth = 0,
  });
  @override
  List<Pt> points;
  String? pipeSpecId;
  bool computerSized;
  String outletSpecId;
  String? nozzleId;
  double headM;
  double spacing;

  /// Distance from the start to the first outlet (0 = half spacing rule not applied; first at [offset] if > 0, else at [spacing]).
  double offset;
  double arcDeg;
  double riserHeight;
  double depth;
  @override
  EntityType get type => EntityType.sprayline;

  double get firstOutletDistance => offset > 0 ? offset : spacing;
  int get outletCount {
    final l = length;
    if (l < firstOutletDistance - 1e-9) return 0;
    return ((l - firstOutletDistance) / spacing + 1e-9).floor() + 1;
  }

  List<Pt> outletPositions() => [for (var i = 0; i < outletCount; i++) pointAlongPolyline(points, firstOutletDistance + i * spacing)];

  @override
  SpraylineEntity clone({String? newId}) => SpraylineEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), pipeSpecId: pipeSpecId, computerSized: computerSized, outletSpecId: outletSpecId, nozzleId: nozzleId, headM: headM, spacing: spacing, offset: offset, arcDeg: arcDeg, riserHeight: riserHeight, depth: depth);
  @override
  SpraylineEntity translated(Pt d) => clone()..points = points.map((p) => p + d).toList();
  @override
  SpraylineEntity transformed(Affine t) => clone()
    ..points = _map(points, t)
    ..spacing = spacing * t.scale
    ..offset = offset * t.scale;
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), if (pipeSpecId != null) 'spec': pipeSpecId, 'auto': computerSized, 'outlet': outletSpecId, if (nozzleId != null) 'nozzle': nozzleId, 'head': headM, 'sp': spacing, 'off': offset, 'arc': arcDeg, 'riser': riserHeight, 'depth': depth};
}

class TapeEntity extends Entity with PolyEntity {
  TapeEntity({required super.id, super.layer = Layers.tapes, super.name, required this.points, required this.tapeSpecId, this.inletHeadM = 10, this.regulated = false, this.submainMinHeadM = 0, this.depth = 0, this.flushingFlow = 0});
  @override
  List<Pt> points;
  String tapeSpecId;
  double inletHeadM;
  bool regulated;
  double submainMinHeadM;
  double depth;

  /// Extra end flow for flushing analysis (m³/s).
  double flushingFlow;
  @override
  EntityType get type => EntityType.tape;
  @override
  TapeEntity clone({String? newId}) => TapeEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), tapeSpecId: tapeSpecId, inletHeadM: inletHeadM, regulated: regulated, submainMinHeadM: submainMinHeadM, depth: depth, flushingFlow: flushingFlow);
  @override
  TapeEntity translated(Pt d) => clone()..points = points.map((p) => p + d).toList();
  @override
  TapeEntity transformed(Affine t) => clone()..points = _map(points, t);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'pts': _ptsJson(points), 'spec': tapeSpecId, 'inlet': inletHeadM, 'reg': regulated, 'submin': submainMinHeadM, 'depth': depth, 'flush': flushingFlow};
}

// ---------------------------------------------------------------- hydraulic (point)

class OutletEntity extends Entity with PointEntity {
  OutletEntity({required super.id, super.layer = Layers.outlets, super.name, required this.position, this.scope = HydraulicScope.zone, required this.outletSpecId, this.nozzleId, this.headM = 20, this.arcDeg = 360, this.orientationDeg = 0, this.riserHeight = 0, this.zoneName = ''});
  @override
  Pt position;
  HydraulicScope scope;
  String outletSpecId;
  String? nozzleId;
  double headM;
  double arcDeg;
  double orientationDeg;
  double riserHeight;

  /// For mainline outlets (valve-in-head), each outlet is its own zone.
  String zoneName;
  @override
  EntityType get type => EntityType.outlet;
  @override
  OutletEntity clone({String? newId}) => OutletEntity(id: newId ?? id, layer: layer, name: name, position: position, scope: scope, outletSpecId: outletSpecId, nozzleId: nozzleId, headM: headM, arcDeg: arcDeg, orientationDeg: orientationDeg, riserHeight: riserHeight, zoneName: zoneName);
  @override
  OutletEntity translated(Pt d) => clone()..position = position + d;
  @override
  OutletEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'scope': scope.name, 'outlet': outletSpecId, if (nozzleId != null) 'nozzle': nozzleId, 'head': headM, 'arc': arcDeg, 'rot': orientationDeg, 'riser': riserHeight, if (zoneName.isNotEmpty) 'zone': zoneName};
}

class ControlValveEntity extends Entity with PointEntity {
  ControlValveEntity({required super.id, super.layer = Layers.controlValves, super.name, required this.position, this.valveSpecId, this.zoneName = '', this.orientationDeg = 0, this.fixedDownstreamHeadM, this.depth = 0});
  @override
  Pt position;
  String? valveSpecId;
  String zoneName;
  double orientationDeg;

  /// If set, the zone is analysed with this downstream pressure (Detailed Analysis).
  double? fixedDownstreamHeadM;
  double depth;
  @override
  EntityType get type => EntityType.controlValve;
  @override
  ControlValveEntity clone({String? newId}) => ControlValveEntity(id: newId ?? id, layer: layer, name: name, position: position, valveSpecId: valveSpecId, zoneName: zoneName, orientationDeg: orientationDeg, fixedDownstreamHeadM: fixedDownstreamHeadM, depth: depth);
  @override
  ControlValveEntity translated(Pt d) => clone()..position = position + d;
  @override
  ControlValveEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), if (valveSpecId != null) 'spec': valveSpecId, 'zone': zoneName, 'rot': orientationDeg, if (fixedDownstreamHeadM != null) 'fixed': fixedDownstreamHeadM, 'depth': depth};
}

class WaterSupplyEntity extends Entity with PointEntity {
  WaterSupplyEntity({required super.id, super.layer = Layers.waterSupply, super.name, required this.position, this.calculatePressure = true, this.designHeadM = 0, this.maxHeadM = 0, this.designFlow = 0, this.maxFlow = 0, this.waterLevelOffsetM = 0});
  @override
  Pt position;
  bool calculatePressure;
  double designHeadM;
  double maxHeadM;
  double designFlow;
  double maxFlow;

  /// Static water level relative to ground (tank +, well −).
  double waterLevelOffsetM;
  @override
  EntityType get type => EntityType.waterSupply;
  @override
  WaterSupplyEntity clone({String? newId}) => WaterSupplyEntity(id: newId ?? id, layer: layer, name: name, position: position, calculatePressure: calculatePressure, designHeadM: designHeadM, maxHeadM: maxHeadM, designFlow: designFlow, maxFlow: maxFlow, waterLevelOffsetM: waterLevelOffsetM);
  @override
  WaterSupplyEntity translated(Pt d) => clone()..position = position + d;
  @override
  WaterSupplyEntity transformed(Affine t) => clone()..position = t.apply(position);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'calc': calculatePressure, 'dh': designHeadM, 'mh': maxHeadM, 'dq': designFlow, 'mq': maxFlow, 'wl': waterLevelOffsetM};
}

class PumpEntity extends Entity with PointEntity {
  PumpEntity({required super.id, super.layer = Layers.pumps, super.name, required this.position, this.pumpSpecId, this.speedRatio = 1, this.orientationDeg = 0, this.scope = HydraulicScope.mainline});
  @override
  Pt position;
  String? pumpSpecId;
  double speedRatio;
  double orientationDeg;
  HydraulicScope scope;
  @override
  EntityType get type => EntityType.pump;
  @override
  PumpEntity clone({String? newId}) => PumpEntity(id: newId ?? id, layer: layer, name: name, position: position, pumpSpecId: pumpSpecId, speedRatio: speedRatio, orientationDeg: orientationDeg, scope: scope);
  @override
  PumpEntity translated(Pt d) => clone()..position = position + d;
  @override
  PumpEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), if (pumpSpecId != null) 'spec': pumpSpecId, 'speed': speedRatio, 'rot': orientationDeg, 'scope': scope.name};
}

class MiscHydraulicEntity extends Entity with PointEntity {
  MiscHydraulicEntity({required super.id, super.layer = Layers.misc, super.name, required this.position, this.valveSpecId, this.scope = HydraulicScope.mainline, this.settingM = 0, this.orientationDeg = 0});
  @override
  Pt position;
  String? valveSpecId;
  HydraulicScope scope;

  /// PRV downstream pressure setting (m).
  double settingM;
  double orientationDeg;
  @override
  EntityType get type => EntityType.misc;
  @override
  MiscHydraulicEntity clone({String? newId}) => MiscHydraulicEntity(id: newId ?? id, layer: layer, name: name, position: position, valveSpecId: valveSpecId, scope: scope, settingM: settingM, orientationDeg: orientationDeg);
  @override
  MiscHydraulicEntity translated(Pt d) => clone()..position = position + d;
  @override
  MiscHydraulicEntity transformed(Affine t) => clone()
    ..position = t.apply(position)
    ..orientationDeg = _rotDeg(t, orientationDeg);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), if (valveSpecId != null) 'spec': valveSpecId, 'scope': scope.name, 'set': settingM, 'rot': orientationDeg};
}

class JunctionEntity extends Entity with PointEntity {
  JunctionEntity({required super.id, super.layer = Layers.junctions, super.name, required this.position, this.scope = HydraulicScope.zone, this.fixedElevation});
  @override
  Pt position;
  HydraulicScope scope;
  double? fixedElevation;
  @override
  EntityType get type => EntityType.junction;
  @override
  JunctionEntity clone({String? newId}) => JunctionEntity(id: newId ?? id, layer: layer, name: name, position: position, scope: scope, fixedElevation: fixedElevation);
  @override
  JunctionEntity translated(Pt d) => clone()..position = position + d;
  @override
  JunctionEntity transformed(Affine t) => clone()..position = t.apply(position);
  @override
  Map<String, dynamic> toJson() => {..._base(), 'p': position.toList(), 'scope': scope.name, if (fixedElevation != null) 'z': fixedElevation};
}

/// Centre pivot or linear-move machine: a demand point on the mainline whose
/// flow and required inlet pressure come from the machine hydraulics
/// (see `design/pivot.dart`). Drawn as the irrigated circle (or strip), the
/// span pipe and its towers.
class PivotEntity extends Entity {
  PivotEntity({
    required super.id,
    super.layer = Layers.pivots,
    super.name,
    required this.center,
    this.radiusM = 400,
    this.angleDeg = 0,
    this.kind = PivotKind.pivot,
    this.travelM = 0,
    this.spanLengthM = 50,
    this.pipeSpecId,
    this.pipeInnerMm = 162,
    this.hazenC = 130,
    this.pipeHeightM = 3.5,
    this.endPressureM = 14,
    this.endGunFlow = 0,
    this.endGunPressureM = 0,
    this.endThrowM = 5,
    this.grossDepthMm = 8,
    this.hoursPerCycle = 24,
    this.wettedWidthM = 18,
    this.machineLossM = 2,
    this.maxAppRateMmH = 0,
    this.sectorDeg = 360,
    this.machineCost = 0,
    this.zoneName = '',
    this.sprinklerSpacingM = 2.5,
    this.sprinklerSpecId,
    this.regulatorSpecId,
    this.towerCost = 0,
  });

  /// Sprinkler package: spacing along the span, catalogue sprinkler and
  /// pressure regulator (bill of materials and sprinkler chart).
  double sprinklerSpacingM;
  String? sprinklerSpecId;
  String? regulatorSpecId;

  /// Price of one tower (span + drive), for the bill of materials.
  double towerCost;

  /// Pivot point (inlet) — a mainline node.
  Pt center;

  /// Span pipe length to the last sprinkler (m).
  double radiusM;

  /// Drawing angle of the span (pivot) or of the lateral (linear), degrees.
  double angleDeg;
  PivotKind kind;

  /// Linear only: travel length perpendicular to the lateral (m).
  double travelM;
  double spanLengthM;

  /// Catalogue pipe for the spans (null: use [pipeInnerMm] / [hazenC]).
  String? pipeSpecId;
  double pipeInnerMm;
  double hazenC;
  double pipeHeightM;
  double endPressureM;

  /// End gun flow (m³/s) and pressure (m); 0 = no end gun.
  double endGunFlow;
  double endGunPressureM;
  double endThrowM;
  double grossDepthMm;
  double hoursPerCycle;
  double wettedWidthM;
  double machineLossM;
  double maxAppRateMmH;
  double sectorDeg;

  /// Machine price for the bill of materials (0 = not costed).
  double machineCost;
  String zoneName;

  double get irrigatedRadius => radiusM + endThrowM;
  double get angleRad => degToRad(angleDeg);
  Pt get direction => Pt.polar(1, angleRad);

  /// Far end of the span pipe (the radius grip).
  Pt get endPoint => center + direction * radiusM;

  /// Irrigated outline (circle / sector for a pivot, rectangle for a linear).
  List<Pt> outline([int segments = 72]) {
    if (kind == PivotKind.linear) {
      final along = direction * irrigatedRadius, across = direction.perpendicular * travelM;
      return [center, center + along, center + along + across, center + across];
    }
    final sweep = degToRad(sectorDeg.clamp(1.0, 360.0));
    final full = sweep >= 2 * math.pi - 1e-9;
    final start = full ? 0.0 : angleRad - sweep / 2;
    final n = math.max(8, (segments * sweep / (2 * math.pi)).round());
    return [if (!full) center, for (var i = 0; i <= n; i++) center + Pt.polar(irrigatedRadius, start + sweep * i / n)];
  }

  /// Tower positions along the drawn span.
  List<Pt> towerPositions() {
    if (spanLengthM <= 0) return const [];
    final n = math.max(1, (radiusM / spanLengthM).floor());
    return [for (var i = 1; i <= n; i++) center + direction * (i * spanLengthM)];
  }

  @override
  EntityType get type => EntityType.pivot;
  @override
  Bounds get bounds => Bounds.ofPoints(outline(24)).include(center);
  @override
  double distanceTo(Pt p) {
    final dc = p.distanceTo(center);
    if (kind == PivotKind.pivot) {
      // pivot point, span line or the outline circle
      return math.min(math.min(dc, distanceToSegment(p, center, endPoint)), (dc - irrigatedRadius).abs());
    }
    final o = outline();
    var best = math.min(dc, distanceToSegment(p, center, endPoint));
    for (var i = 0; i < o.length; i++) {
      best = math.min(best, distanceToSegment(p, o[i], o[(i + 1) % o.length]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [center, endPoint];
  @override
  void setGrip(int index, Pt p) {
    if (index == 0) {
      center = p;
    } else {
      final d = p - center;
      if (d.length > 1e-6) {
        radiusM = d.length;
        angleDeg = radToDeg(d.angle);
      }
    }
  }

  @override
  PivotEntity clone({String? newId}) => PivotEntity(
    id: newId ?? id, layer: layer, name: name, center: center, radiusM: radiusM, angleDeg: angleDeg, kind: kind, travelM: travelM, spanLengthM: spanLengthM, pipeSpecId: pipeSpecId, pipeInnerMm: pipeInnerMm,
    hazenC: hazenC, pipeHeightM: pipeHeightM, endPressureM: endPressureM, endGunFlow: endGunFlow, endGunPressureM: endGunPressureM, endThrowM: endThrowM, grossDepthMm: grossDepthMm, hoursPerCycle: hoursPerCycle,
    wettedWidthM: wettedWidthM, machineLossM: machineLossM, maxAppRateMmH: maxAppRateMmH, sectorDeg: sectorDeg, machineCost: machineCost, zoneName: zoneName,
    sprinklerSpacingM: sprinklerSpacingM, sprinklerSpecId: sprinklerSpecId, regulatorSpecId: regulatorSpecId, towerCost: towerCost,
  );
  @override
  PivotEntity translated(Pt d) => clone()..center = center + d;
  @override
  PivotEntity transformed(Affine t) => clone()
    ..center = t.apply(center)
    ..radiusM = radiusM * t.scale
    ..travelM = travelM * t.scale
    ..angleDeg = _rotDeg(t, angleDeg);
  @override
  Map<String, dynamic> toJson() => {
    ..._base(), 'p': center.toList(), 'r': radiusM, 'ang': angleDeg, 'kind': kind.name, if (travelM > 0) 'travel': travelM, 'span': spanLengthM, if (pipeSpecId != null) 'spec': pipeSpecId, 'idmm': pipeInnerMm, 'c': hazenC,
    'hp': pipeHeightM, 'hend': endPressureM, if (endGunFlow > 0) 'qg': endGunFlow, if (endGunPressureM > 0) 'hg': endGunPressureM, 'throw': endThrowM, 'depth': grossDepthMm, 'hours': hoursPerCycle, 'ww': wettedWidthM,
    'hm': machineLossM, if (maxAppRateMmH > 0) 'imax': maxAppRateMmH, if (sectorDeg != 360) 'sector': sectorDeg, if (machineCost > 0) 'cost': machineCost, if (zoneName.isNotEmpty) 'zone': zoneName,
    'ssp': sprinklerSpacingM, if (sprinklerSpecId != null) 'sspec': sprinklerSpecId, if (regulatorSpecId != null) 'rspec': regulatorSpecId, if (towerCost > 0) 'tcost': towerCost,
  };
}

class AreaEntity extends Entity with PolyEntity {
  AreaEntity({
    required super.id,
    super.layer = Layers.areas,
    super.name,
    required this.points,
    this.netDepthMmPerDay = 5,
    this.efficiency = 0.9,
    this.crop = '',
    this.emittersPerPlant = 0,
    this.useWaterBalance = false,
    this.etoMmDay = 5,
    this.kc = 1,
    this.awcMmPerM = 120,
    this.rootDepthM = 0.6,
    this.mad = 0.5,
    this.plantSpacingM = 0,
    this.rowSpacingM = 0,
    this.wettedFraction = 1,
  });
  @override
  List<Pt> points;
  double netDepthMmPerDay;
  double efficiency;
  String crop;

  /// Emitters per plant for the EU formula (0 = project default).
  int emittersPerPlant;

  /// Agronomy (crop water requirement and soil water balance).
  bool useWaterBalance;
  double etoMmDay;
  double kc;

  /// Available water capacity of the soil (mm per metre of depth).
  double awcMmPerM;
  double rootDepthM;

  /// Management allowed depletion (fraction).
  double mad;
  double plantSpacingM;
  double rowSpacingM;

  /// Fraction of the area wetted (localized irrigation).
  double wettedFraction;

  double get area => polygonArea(points).abs();

  /// Crop evapotranspiration ETc = ETo·Kc (mm/day).
  double get etcMmDay => etoMmDay * kc;

  /// Net depth per day actually used by the reports (balance or fixed).
  double get effectiveNetDepthMmPerDay => useWaterBalance ? etcMmDay : netDepthMmPerDay;
  @override
  EntityType get type => EntityType.area;
  @override
  double distanceTo(Pt p) => pointInPolygon(p, points) ? 0 : math.min(super.distanceTo(p), points.length > 2 ? distanceToSegment(p, points.last, points.first) : double.infinity);
  @override
  AreaEntity clone({String? newId}) => AreaEntity(id: newId ?? id, layer: layer, name: name, points: List.of(points), netDepthMmPerDay: netDepthMmPerDay, efficiency: efficiency, crop: crop, emittersPerPlant: emittersPerPlant, useWaterBalance: useWaterBalance, etoMmDay: etoMmDay, kc: kc, awcMmPerM: awcMmPerM, rootDepthM: rootDepthM, mad: mad, plantSpacingM: plantSpacingM, rowSpacingM: rowSpacingM, wettedFraction: wettedFraction);
  @override
  AreaEntity translated(Pt d) => clone()..points = points.map((p) => p + d).toList();
  @override
  AreaEntity transformed(Affine t) => clone()..points = _map(points, t);
  @override
  Map<String, dynamic> toJson() => {
    ..._base(), 'pts': _ptsJson(points), 'depth': netDepthMmPerDay, 'eff': efficiency, 'crop': crop,
    if (emittersPerPlant > 0) 'epp': emittersPerPlant, if (useWaterBalance) 'wb': true, 'eto': etoMmDay, 'kc': kc, 'awc': awcMmPerM, 'root': rootDepthM, 'mad': mad,
    if (plantSpacingM > 0) 'psp': plantSpacingM, if (rowSpacingM > 0) 'rsp': rowSpacingM, if (wettedFraction != 1) 'wf': wettedFraction,
  };
}

extension EntityKindX on Entity {
  bool get isHydraulic => switch (type) {
    EntityType.pipe || EntityType.sprayline || EntityType.tape || EntityType.outlet || EntityType.controlValve ||
    EntityType.waterSupply || EntityType.pump || EntityType.misc || EntityType.junction || EntityType.pivot => true,
    _ => false,
  };

  /// Linear hydraulic entity that can be cut / split.
  bool get isLinearHydraulic => this is PipeEntity || this is SpraylineEntity || this is TapeEntity;

  HydraulicScope? get hydraulicScope => switch (this) {
    PipeEntity e => e.scope,
    SpraylineEntity _ => HydraulicScope.zone,
    TapeEntity _ => HydraulicScope.zone,
    OutletEntity e => e.scope,
    ControlValveEntity _ => null, // bridges both
    WaterSupplyEntity _ => HydraulicScope.mainline,
    PumpEntity e => e.scope,
    MiscHydraulicEntity e => e.scope,
    JunctionEntity e => e.scope,
    PivotEntity _ => HydraulicScope.mainline,
    _ => null,
  };

  /// Polyline geometry usable for trim/extend/offset/intersections, or null.
  List<Pt>? get linearPoints => switch (this) {
    LineEntity l => [l.a, l.b],
    PolyEntity p => p.points,
    ArcEntity a => a.polyline(),
    _ => null,
  };

  bool get isClosedShape => switch (this) {
    PolylineEntity p => p.closed,
    AreaEntity _ || HatchEntity _ => true,
    SplineEntity s => s.closed,
    _ => false,
  };
}
