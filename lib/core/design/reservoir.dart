/// The reservoir or dam behind a water supply (1.6.0 MOT+, PRD-16): its
/// stage–area–volume curve from the terrain model (a dam or pond: the ground
/// inside the outline; an excavated reservoir: a flat bottom with the sides
/// sloping up to the outline), the volume it stores between its lowest and
/// its full level, the earth an excavated one takes out, the days of demand
/// it holds and the time its inflow takes to fill it.
///
/// The basin is integrated on a grid of the outline (about 40 000 cells):
/// the area at a level is the cells whose bed lies below it, the volume the
/// sum of the depth of water over every cell — the end-area method of earth
/// works on a fine grid, as the stage–volume tables of dam studies.
library;

import 'dart:math' as math;

import '../hydraulics/eps.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import 'results.dart';

/// A point of the stage–area–volume curve.
class ReservoirStage {
  const ReservoirStage({required this.level, required this.area, required this.volume});

  /// Water level (m, elevation), its surface (m²) and the volume below it (m³).
  final double level;
  final double area;
  final double volume;

  Map<String, dynamic> toJson() => {'z': level, 'a': area, 'v': volume};
}

/// The study of the reservoir of one supply.
class ReservoirStudy {
  ReservoirStudy({
    required this.supplyId,
    required this.curve,
    required this.bottom,
    required this.fullLevel,
    required this.minLevel,
    required this.initialLevel,
    required this.inflow,
    this.cut = 0,
    this.dailyDemand = 0,
    this.messages = const [],
  });

  final String supplyId;

  /// From the bottom to the full level.
  final List<ReservoirStage> curve;

  /// Lowest point of the bed, full level, lowest operating level and the
  /// level at the start of the day (m, elevations).
  final double bottom;
  final double fullLevel;
  final double minLevel;
  final double initialLevel;

  /// Water flowing in (m³/s).
  final double inflow;

  /// Earth taken out of an excavated reservoir below the ground (m³).
  final double cut;

  /// Water the system flows of the design draw from the supply in a day
  /// (each flow once, for its duration; m³).
  final double dailyDemand;

  /// `reservoir_no_outline:<supply>`, `reservoir_full_below_bottom:<supply>`.
  final List<String> messages;

  /// Volume below [level] (m³), by the curve (straight on beyond its ends).
  double volumeAt(double level) {
    if (curve.isEmpty) return 0;
    if (level <= curve.first.level) return 0;
    for (var i = 1; i < curve.length; i++) {
      if (level <= curve[i].level) {
        final a = curve[i - 1], b = curve[i];
        final t = b.level > a.level ? (level - a.level) / (b.level - a.level) : 1.0;
        return a.volume + t * (b.volume - a.volume);
      }
    }
    final last = curve.last;
    return last.volume + (level - last.level) * last.area;
  }

  /// Volume at the full level (m³) and its surface (m²).
  double get volume => volumeAt(fullLevel);
  double get surfaceArea => curve.isEmpty ? 0 : curve.last.area;

  /// Volume between the lowest operating level and the full level (m³).
  double get usableVolume => math.max(0, volume - volumeAt(minLevel));

  /// Days of demand the usable volume holds, the inflow counted (infinite
  /// when the inflow covers the demand; 0 without a demand).
  double get autonomyDays {
    final net = dailyDemand - inflow * 86400;
    if (dailyDemand <= 0) return 0;
    return net <= 0 ? double.infinity : usableVolume / net;
  }

  /// Hours the inflow takes to fill the usable volume (infinite without one).
  double get fillHours => inflow > 0 ? usableVolume / inflow / 3600 : double.infinity;

  /// The reservoir as a tank of the 24-hour simulation at node [nodeId]
  /// (levels above the bottom).
  EpsTank tankAt(String nodeId, {double? initialLevel}) => EpsTank(
    nodeId: nodeId,
    initialLevel: (initialLevel ?? this.initialLevel) - bottom,
    maxLevel: fullLevel - bottom,
    minLevel: math.max(0, minLevel - bottom),
    volumeCurve: [for (final s in curve) (s.level - bottom, s.volume)],
    bottomElevation: bottom,
    inflow: inflow,
  );

  Map<String, dynamic> toJson() => {
    'id': supplyId,
    'curve': [for (final s in curve) s.toJson()],
    'bottom': bottom,
    'full': fullLevel,
    'min': minLevel,
    'init': initialLevel,
    'inflow': inflow,
    'cut': cut,
    'daily': dailyDemand,
    'msg': messages,
  };
}

/// The outline (closed, at least three points) of the reservoir of [spec],
/// or null.
List<Pt>? reservoirOutline(Project p, ReservoirSpec spec) {
  final e = p.byId(spec.outlineId);
  final pts = switch (e) {
    AreaEntity a => a.points,
    PolylineEntity l => l.points,
    _ => null,
  };
  if (pts == null || pts.length < 3) return null;
  // a polyline drawn back to its start counts as closed
  return pts.first.distanceTo(pts.last) < 1e-6 ? pts.sublist(0, pts.length - 1) : pts;
}

/// The study of the reservoir of supply [s] of [p] (null without one), the
/// ground from [terrain] (the project's by default) and the daily demand
/// from the system flows of [results]. [cells] bounds the grid.
ReservoirStudy? reservoirStudy(Project p, WaterSupplyEntity s, {Terrain? terrain, DesignResults? results, int cells = 40000, int stages = 24}) {
  final spec = s.reservoir;
  if (spec == null) return null;
  final messages = <String>[];
  final outline = reservoirOutline(p, spec);
  var daily = 0.0;
  for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) {
    for (final d in f.supplies) {
      if (d.supplyId == s.id) daily += math.max(0, d.flow) * f.durationHours.clamp(0.0, 24.0) * 3600;
    }
  }
  if (outline == null) {
    messages.add('reservoir_no_outline:${s.id}');
    final full = spec.fullLevelM;
    return ReservoirStudy(supplyId: s.id, curve: const [], bottom: full, fullLevel: full, minLevel: full, initialLevel: full, inflow: spec.inflow, dailyDemand: daily, messages: messages);
  }
  final t = terrain ?? p.buildTerrain();
  var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
  for (final q in outline) {
    x0 = math.min(x0, q.x);
    y0 = math.min(y0, q.y);
    x1 = math.max(x1, q.x);
    y1 = math.max(y1, q.y);
  }
  final step = math.max(math.sqrt((x1 - x0) * (y1 - y0) / math.max(cells, 100)), 0.05);
  final cellArea = step * step;
  final full = spec.fullLevelM;
  final excavated = spec.kind == ReservoirKind.excavated;
  final floor = spec.bottomM ?? full - 3;
  final slope = math.max(spec.sideSlope, 0.0);
  // the bed of every cell inside the outline, and the ground over it
  final beds = <double>[];
  var cut = 0.0;
  for (var y = y0 + step / 2; y < y1; y += step) {
    for (var x = x0 + step / 2; x < x1; x += step) {
      final c = Pt(x, y);
      if (!pointInPolygon(c, outline)) continue;
      final ground = t.isEmpty ? full : t.elevationAt(c);
      double bed;
      if (excavated) {
        // the sides rise from the bottom to the outline at the full level
        final e = _distanceToEdge(c, outline);
        bed = slope > 0 ? math.max(floor, full - e / slope) : floor;
        cut += math.max(0.0, ground - bed) * cellArea;
      } else {
        bed = ground;
      }
      beds.add(bed);
    }
  }
  if (beds.isEmpty) {
    messages.add('reservoir_no_outline:${s.id}');
    return ReservoirStudy(supplyId: s.id, curve: const [], bottom: full, fullLevel: full, minLevel: full, initialLevel: full, inflow: spec.inflow, dailyDemand: daily, messages: messages);
  }
  final bottom = beds.reduce(math.min);
  if (!(full > bottom)) messages.add('reservoir_full_below_bottom:${s.id}');
  final top = math.max(full, bottom);
  final curve = <ReservoirStage>[];
  for (var i = 0; i <= stages; i++) {
    final z = bottom + (top - bottom) * i / stages;
    var area = 0.0, volume = 0.0;
    for (final b in beds) {
      if (b < z) {
        area += cellArea;
        volume += (z - b) * cellArea;
      }
    }
    curve.add(ReservoirStage(level: z, area: area, volume: volume));
  }
  final minLevel = (spec.minLevelM ?? bottom).clamp(bottom, top).toDouble();
  final initial = (spec.initialLevelM ?? top).clamp(bottom, top).toDouble();
  return ReservoirStudy(supplyId: s.id, curve: curve, bottom: bottom, fullLevel: top, minLevel: minLevel, initialLevel: initial, inflow: spec.inflow, cut: cut, dailyDemand: daily, messages: messages);
}

/// Distance (m) from [p] to the nearest edge of the closed [polygon].
double _distanceToEdge(Pt p, List<Pt> polygon) {
  var best = double.infinity;
  for (var i = 0; i < polygon.length; i++) {
    final (cp, _) = closestPointOnSegment(p, polygon[i], polygon[(i + 1) % polygon.length]);
    best = math.min(best, cp.distanceTo(p));
  }
  return best;
}
