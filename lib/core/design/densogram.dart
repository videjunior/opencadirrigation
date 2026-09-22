/// Densogram: the map of the water applied by the sprinklers and
/// micro-sprinklers of the drawing as they are laid out (positions, arcs,
/// orientations and, after a design, the pressure of each one), with the
/// uniformity of the application inside the irrigated area.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'network_builder.dart';
import 'results.dart';

/// Radial distribution of the water of one sprinkler: the depth applied at
/// distance r from the head, relative to the wetted radius R.
enum SprayProfile {
  /// 1 − r/R: single-nozzle impact sprinklers and most rotors (the classic
  /// triangular pattern that asks for head-to-head spacing).
  triangular,

  /// √(1 − (r/R)²): rotors with several nozzles, micro-sprinklers.
  elliptical,

  /// Constant: spray heads and matched-precipitation nozzles.
  uniform,
}

/// One wetted circle (or sector) of the map.
class SpraySource {
  const SpraySource({required this.entityId, required this.p, required this.flow, required this.radius, this.startRad = 0, this.sweepRad = 2 * math.pi});
  final String entityId;
  final Pt p;

  /// Discharge (m³/s).
  final double flow;

  /// Wetted radius (m).
  final double radius;

  /// Sector swept counter-clockwise from [startRad] (world angles).
  final double startRad;
  final double sweepRad;

  bool get fullCircle => sweepRad >= 2 * math.pi - 1e-9;

  /// Application rate (m/s) at [d] metres from the head for [profile]; the
  /// flow spread over the sector integrates back to [flow].
  double rateAt(double d, SprayProfile profile) {
    if (d >= radius || radius <= 0 || flow <= 0) return 0;
    final x = d / radius;
    final r2 = radius * radius * sweepRad;
    return switch (profile) {
      SprayProfile.triangular => flow * (1 - x) / (r2 / 6),
      SprayProfile.elliptical => flow * math.sqrt(1 - x * x) / (r2 / 3),
      SprayProfile.uniform => flow / (r2 / 2),
    };
  }

  /// Whether the direction [angle] (radians) is inside the sector.
  bool covers(double angle) {
    if (fullCircle) return true;
    var a = (angle - startRad) % (2 * math.pi);
    if (a < 0) a += 2 * math.pi;
    return a <= sweepRad + 1e-9;
  }
}

class DensogramOptions {
  DensogramOptions({this.cellSize = 0, this.profile = SprayProfile.triangular, this.useResults = true, this.valveIds, this.maxCells = 60000});

  /// Grid spacing (m); 0 = automatic (a quarter of the smallest wetted
  /// radius, coarser when the grid would exceed [maxCells]).
  double cellSize;
  SprayProfile profile;

  /// Use the pressure and flow of every emitter from the design results
  /// (else each one works at its nominal pressure).
  bool useResults;

  /// Zones to include (valve ids); null = every sprinkler of the drawing.
  Set<String>? valveIds;
  int maxCells;
}

/// Uniformity statistics of the application rate over the target cells.
class DensogramStats {
  const DensogramStats({required this.cells, required this.mean, required this.min, required this.max, required this.cu, required this.du, required this.sc, required this.dryPct, required this.areaM2});
  static const empty = DensogramStats(cells: 0, mean: 0, min: 0, max: 0, cu: 0, du: 0, sc: 0, dryPct: 0, areaM2: 0);

  /// Cells evaluated.
  final int cells;

  /// Application rate (mm/h).
  final double mean, min, max;

  /// Christiansen uniformity coefficient (%).
  final double cu;

  /// Low-quarter distribution uniformity (%).
  final double du;

  /// Scheduling coefficient: mean rate over the mean of the driest 5 % of
  /// the cells (how much longer the system must run so the driest spots get
  /// the mean depth; 1 = perfect).
  final double sc;

  /// Share of the cells receiving less than half the mean (%).
  final double dryPct;

  /// Area evaluated (m²).
  final double areaM2;
}

/// Uniformity inside one irrigated area.
class DensogramArea {
  const DensogramArea(this.areaId, this.name, this.stats);
  final String areaId;
  final String name;
  final DensogramStats stats;
}

class Densogram {
  Densogram({required this.origin, required this.cell, required this.nx, required this.ny, required this.rate, required this.inside, required this.sources, required this.stats, required this.masked, required this.fromResults, Int16List? areaOf, this.areas = const []})
      : areaOf = areaOf ?? (Int16List(nx * ny)..fillRange(0, nx * ny, -1));

  /// Lower-left corner of the grid (world metres) and cell size (m).
  final Pt origin;
  final double cell;
  final int nx, ny;

  /// Application rate per cell (mm/h), row by row from the bottom.
  final Float64List rate;

  /// Cells that belong to the target area (irrigated areas, or the wetted
  /// cells when the drawing has no area around the sprinklers).
  final Uint8List inside;
  final List<SpraySource> sources;
  final DensogramStats stats;

  /// The target is the irrigated areas (true) or the wetted cells (false).
  final bool masked;

  /// The emitter flows came from the design results.
  final bool fromResults;

  /// Irrigated area of each cell (index into [areas], −1 = none) and the
  /// uniformity inside each area: zones of different rates (sprays next to
  /// rotors) are judged against their own mean, not a mixed one.
  final Int16List areaOf;
  final List<DensogramArea> areas;

  /// Mean rate (mm/h) the cell at index [k] is compared with: its area's,
  /// or the overall one.
  double meanAt(int k) {
    final a = areaOf[k];
    return a >= 0 && a < areas.length && areas[a].stats.mean > 0 ? areas[a].stats.mean : stats.mean;
  }

  bool get isEmpty => sources.isEmpty || nx == 0 || ny == 0;

  Pt cellCenter(int i, int j) => Pt(origin.x + (i + 0.5) * cell, origin.y + (j + 0.5) * cell);
  Bounds get bounds => Bounds(origin.x, origin.y, origin.x + nx * cell, origin.y + ny * cell);

  /// Rate (mm/h) at [p], 0 outside the grid.
  double rateAt(Pt p) {
    final i = ((p.x - origin.x) / cell).floor(), j = ((p.y - origin.y) / cell).floor();
    if (i < 0 || j < 0 || i >= nx || j >= ny) return 0;
    return rate[j * nx + i];
  }

  /// Grid as CSV (x, y, rate mm/h, inside).
  String toCsv() {
    final b = StringBuffer('x;y;mm_h;target\n');
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final c = cellCenter(i, j), k = j * nx + i;
        if (rate[k] <= 0 && inside[k] == 0) continue;
        b.writeln('${c.x.toStringAsFixed(2)};${c.y.toStringAsFixed(2)};${rate[k].toStringAsFixed(3)};${inside[k]}');
      }
    }
    return b.toString();
  }
}

/// Converts a rate in m/s to mm/h.
double _mmh(double si) => si * 1000 * 3600;

/// The sprinklers of [p] as wetted sectors: single outlets and the outlets
/// of every lateral whose nozzle has a wetted radius. With [results] each
/// one takes the pressure and flow of the latest design.
List<SpraySource> spraySources(Project p, {DesignResults? results, Set<String>? valveIds}) {
  final cat = p.catalog;
  final out = <SpraySource>[];
  Set<String>? allowed;
  if (valveIds != null) {
    // emitters downstream of the chosen valves
    final m = NetworkBuilder(p).build();
    allowed = {
      for (final v in valveIds)
        for (final nid in m.zoneNodes[v] ?? const <String>{})
          for (final em in m.nodes[nid]?.emitters ?? const <EmitterRef>[]) em.entityId,
    };
  }
  final byEntity = results?.outletsByEntity;
  for (final e in p.entities) {
    if (allowed != null && !allowed.contains(e.id)) continue;
    switch (e) {
      case OutletEntity o:
        final nz = cat.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
        if (nz == null) continue;
        final r = byEntity?[o.id]?.firstOrNull;
        final head = r?.pressure ?? o.headM;
        final radius = nz.curve.radius(head);
        final flow = r?.flow ?? nz.curve.flow(head);
        if (radius <= 0 || flow <= 0) continue;
        // a part-circle nozzle left on a full-circle head still waters its own arc
        final arc = (nz.arcDeg < 360 && o.arcDeg >= 360 ? nz.arcDeg : o.arcDeg).clamp(1.0, 360.0);
        out.add(SpraySource(entityId: o.id, p: o.position, flow: flow, radius: radius, startRad: degToRad(o.orientationDeg), sweepRad: degToRad(arc)));
      case SpraylineEntity s:
        final nz = cat.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
        if (nz == null || s.points.length < 2) continue;
        final res = byEntity?[s.id] ?? const <OutletResult>[];
        final arc = degToRad((nz.arcDeg < 360 && s.arcDeg >= 360 ? nz.arcDeg : s.arcDeg).clamp(1.0, 360.0));
        var d = s.firstOutletDistance;
        for (final pos in s.outletPositions()) {
          // the lumped result nearest to this outlet gives its pressure
          OutletResult? near;
          var best = double.infinity;
          for (final r in res) {
            final dd = r.p.distanceTo(pos);
            if (dd < best) {
              best = dd;
              near = r;
            }
          }
          final head = near?.pressure ?? s.headM;
          final radius = nz.curve.radius(head);
          final flow = near != null && near.flow > 0 ? near.flow : nz.curve.flow(head);
          if (radius > 0 && flow > 0) {
            // part circles open to the left of the lateral, centred on its normal
            var start = 0.0;
            if (arc < 2 * math.pi - 1e-9) {
              final a = pointAlongPolyline(s.points, math.max(0, d - 0.01)), b = pointAlongPolyline(s.points, d + 0.01);
              start = (b - a).perpendicular.angle - arc / 2;
            }
            out.add(SpraySource(entityId: s.id, p: pos, flow: flow, radius: radius, startRad: start, sweepRad: arc));
          }
          d += s.spacing;
        }
      default:
        break;
    }
  }
  return out;
}

/// Builds the densogram of the sprinklers of [p] (see [DensogramOptions]).
Densogram computeDensogram(Project p, {DesignResults? results, DensogramOptions? options}) {
  final o = options ?? DensogramOptions();
  final res = o.useResults ? results : null;
  final sources = spraySources(p, results: res, valveIds: o.valveIds);
  final fromResults = res != null && sources.isNotEmpty;
  if (sources.isEmpty) {
    return Densogram(origin: Pt.zero, cell: 1, nx: 0, ny: 0, rate: Float64List(0), inside: Uint8List(0), sources: const [], stats: DensogramStats.empty, masked: false, fromResults: false);
  }
  // target: the irrigated areas that hold sprinklers
  final areaEntities = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && sources.any((s) => pointInPolygon(s.p, a.points))) a,
  ];
  final areas = [for (final a in areaEntities) a.points];
  var b = Bounds.empty;
  var minR = double.infinity;
  for (final s in sources) {
    b = b.union(Bounds(s.p.x - s.radius, s.p.y - s.radius, s.p.x + s.radius, s.p.y + s.radius));
    minR = math.min(minR, s.radius);
  }
  for (final a in areas) {
    b = b.union(Bounds.ofPoints(a));
  }
  var cell = o.cellSize > 0 ? o.cellSize : math.max(0.05, minR / 4);
  final maxCells = math.max(100, o.maxCells);
  while ((b.width / cell).ceil() * (b.height / cell).ceil() > maxCells) {
    cell *= 1.25;
  }
  final nx = math.max(1, (b.width / cell).ceil()), ny = math.max(1, (b.height / cell).ceil());
  final origin = Pt(b.minX, b.minY);
  final rate = Float64List(nx * ny);
  for (final s in sources) {
    final i0 = math.max(0, ((s.p.x - s.radius - origin.x) / cell).floor()), i1 = math.min(nx - 1, ((s.p.x + s.radius - origin.x) / cell).floor());
    final j0 = math.max(0, ((s.p.y - s.radius - origin.y) / cell).floor()), j1 = math.min(ny - 1, ((s.p.y + s.radius - origin.y) / cell).floor());
    for (var j = j0; j <= j1; j++) {
      final cy = origin.y + (j + 0.5) * cell - s.p.y;
      for (var i = i0; i <= i1; i++) {
        final cx = origin.x + (i + 0.5) * cell - s.p.x;
        final d = math.sqrt(cx * cx + cy * cy);
        if (d >= s.radius) continue;
        if (!s.fullCircle && d > 1e-9 && !s.covers(math.atan2(cy, cx))) continue;
        rate[j * nx + i] += _mmh(s.rateAt(d, o.profile));
      }
    }
  }
  final inside = Uint8List(nx * ny);
  final areaOf = Int16List(nx * ny)..fillRange(0, nx * ny, -1);
  final perArea = [for (final _ in areas) <double>[]];
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final k = j * nx + i;
      if (areas.isEmpty) {
        if (rate[k] > 0) inside[k] = 1;
      } else {
        final c = Pt(origin.x + (i + 0.5) * cell, origin.y + (j + 0.5) * cell);
        for (var a = 0; a < areas.length; a++) {
          if (pointInPolygon(c, areas[a])) {
            inside[k] = 1;
            areaOf[k] = a;
            perArea[a].add(rate[k]);
            break;
          }
        }
      }
    }
  }
  final values = <double>[
    for (var k = 0; k < rate.length; k++)
      if (inside[k] == 1) rate[k],
  ];
  return Densogram(
    origin: origin, cell: cell, nx: nx, ny: ny, rate: rate, inside: inside, sources: sources, stats: densogramStats(values, cell * cell), masked: areas.isNotEmpty, fromResults: fromResults,
    areaOf: areaOf, areas: [for (var a = 0; a < areas.length; a++) DensogramArea(areaEntities[a].id, areaEntities[a].name, densogramStats(perArea[a], cell * cell))],
  );
}

/// Uniformity of the rates [values] (mm/h) of cells of [cellArea] m².
DensogramStats densogramStats(List<double> values, double cellArea) {
  if (values.isEmpty) return DensogramStats.empty;
  final n = values.length;
  final sorted = List.of(values)..sort();
  final mean = sorted.fold(0.0, (s, v) => s + v) / n;
  if (mean <= 0) return DensogramStats(cells: n, mean: 0, min: 0, max: 0, cu: 0, du: 0, sc: 0, dryPct: 100, areaM2: n * cellArea);
  final dev = sorted.fold(0.0, (s, v) => s + (v - mean).abs()) / n;
  final q = math.max(1, (n / 4).round());
  final lq = sorted.take(q).fold(0.0, (s, v) => s + v) / q;
  final f = math.max(1, (n * 0.05).round());
  final low5 = sorted.take(f).fold(0.0, (s, v) => s + v) / f;
  final dry = sorted.where((v) => v < mean / 2).length;
  return DensogramStats(
    cells: n,
    mean: mean,
    min: sorted.first,
    max: sorted.last,
    cu: 100 * (1 - dev / mean),
    du: 100 * lq / mean,
    sc: low5 > 0 ? mean / low5 : double.infinity,
    dryPct: 100 * dry / n,
    areaM2: n * cellArea,
  );
}

/// Name of a spray profile key (`dens.profile.<name>`).
String sprayProfileKey(SprayProfile p) => 'dens.profile.${p.name}';

/// Whether catalogue [c] has any nozzle with a wetted radius.
bool hasSprinklerNozzles(Catalog c) => c.outlets.any((o) => o.nozzles.any((n) => n.curve.radiusA > 0));

/// Colour stops of the densogram: rate relative to the mean → ARGB.
/// Dry spots are red, the mean green, over-watering blue to purple.
const densogramStops = <(double, int)>[
  (0.0, 0xFF7F1D0B),
  (0.5, 0xFFE65100),
  (0.8, 0xFFFFD54F),
  (1.0, 0xFF66BB6A),
  (1.25, 0xFF29B6F6),
  (1.6, 0xFF1565C0),
  (2.0, 0xFF6A1B9A),
];

/// Colour (ARGB, opaque) of a cell receiving [v] mm/h when the mean over
/// the target is [mean].
int densogramColor(double v, double mean) {
  final r = mean > 0 ? (v / mean).clamp(0.0, densogramStops.last.$1) : 0.0;
  for (var k = 1; k < densogramStops.length; k++) {
    final (r1, c1) = densogramStops[k];
    if (r <= r1) {
      final (r0, c0) = densogramStops[k - 1];
      return _lerpArgb(c0, c1, (r - r0) / (r1 - r0));
    }
  }
  return densogramStops.last.$2;
}

int _lerpArgb(int a, int b, double t) {
  int ch(int shift) => (((a >> shift) & 0xFF) + ((((b >> shift) & 0xFF) - ((a >> shift) & 0xFF)) * t)).round().clamp(0, 255);
  return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// RGBA pixels of the densogram, one per cell, top row first (for an
/// image); each cell is coloured against the mean of its irrigated area,
/// dry cells are transparent and wetted cells outside the target are
/// fainter.
Uint8List densogramPixels(Densogram d, {int alpha = 185, int outsideAlpha = 80}) {
  final px = Uint8List(d.nx * d.ny * 4);
  for (var j = 0; j < d.ny; j++) {
    final row = d.ny - 1 - j;
    for (var i = 0; i < d.nx; i++) {
      final k = j * d.nx + i;
      final v = d.rate[k];
      if (v <= 0) continue;
      final c = densogramColor(v, d.meanAt(k));
      final o = (row * d.nx + i) * 4;
      px[o] = (c >> 16) & 0xFF;
      px[o + 1] = (c >> 8) & 0xFF;
      px[o + 2] = c & 0xFF;
      px[o + 3] = d.inside[k] == 1 ? alpha : outsideAlpha;
    }
  }
  return px;
}
