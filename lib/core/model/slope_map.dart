/// Slope and aspect of the terrain on a regular grid: the slope map of the
/// drawing (View → Overlay) and the share of the area in each slope class.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';
import 'terrain.dart';

/// Upper bounds (%) of the slope classes and their colours (ARGB): flat to
/// gentle in greens, the classes where laterals need pressure compensation
/// or contour layout in yellow and orange, the steep ones in red and purple
/// (class limits after the soil-survey slope phases, USDA Soil Survey
/// Manual ch. 3, rounded for irrigation layout).
const slopeClasses = <(double, int)>[
  (2, 0xFF1B9E77),
  (5, 0xFF66BD63),
  (10, 0xFFD9EF8B),
  (15, 0xFFFEE08B),
  (20, 0xFFFDAE61),
  (30, 0xFFF46D43),
  (45, 0xFFD73027),
  (double.infinity, 0xFF7B3294),
];

/// Index of the slope class of [slopePct] in [slopeClasses].
int slopeClassOf(double slopePct) {
  for (var k = 0; k < slopeClasses.length; k++) {
    if (slopePct < slopeClasses[k].$1) return k;
  }
  return slopeClasses.length - 1;
}

/// Compass bearing (degrees, 0 = north/+y, clockwise) of a mathematical
/// angle in radians.
double bearingDeg(double angleRad) {
  final b = 90 - angleRad * 180 / math.pi;
  return ((b % 360) + 360) % 360;
}

/// Colour of an aspect: the eight compass sectors around a hue wheel
/// (north red, east yellow, south cyan, west blue), dim where the ground is
/// nearly flat (under 1 %) and the aspect means little.
int aspectColor(double bearing, double slopePct) {
  if (slopePct < 1) return 0xFF9E9E9E;
  final hue = bearing % 360;
  final c = 1.0, x = 1 - ((hue / 60) % 2 - 1).abs();
  final (r, g, b) = switch (hue ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int ch(double v) => (v * 230 + 25).round().clamp(0, 255);
  return 0xFF000000 | ch(r) << 16 | ch(g) << 8 | ch(b);
}

class SlopeMap {
  SlopeMap({required this.origin, required this.cell, required this.nx, required this.ny, required this.slopePct, required this.bearing});

  /// Lower-left corner of the grid (world metres) and cell size (m).
  final Pt origin;
  final double cell;
  final int nx, ny;

  /// Slope (%) of each cell centre, row by row from the bottom; NaN where the
  /// terrain has no data.
  final Float64List slopePct;

  /// Direction of steepest descent (compass degrees) of each cell.
  final Float64List bearing;

  bool get isEmpty => nx == 0 || ny == 0;
  Bounds get bounds => Bounds(origin.x, origin.y, origin.x + nx * cell, origin.y + ny * cell);

  static final SlopeMap empty = SlopeMap(origin: Pt.zero, cell: 1, nx: 0, ny: 0, slopePct: Float64List(0), bearing: Float64List(0));

  /// Samples [terrain] over [area] with square cells, at most [maxCells]
  /// of them (the cell grows to fit). Cells outside the triangulated hull
  /// and outside the hull of the samples are left out when [hullOnly].
  static SlopeMap compute(Terrain terrain, Bounds area, {int maxCells = 60000, bool hullOnly = true}) {
    if (terrain.isEmpty || !(area.width > 0) || !(area.height > 0)) return empty;
    final cell = math.max(math.sqrt(area.width * area.height / math.max(1, maxCells)), 1e-3);
    final nx = math.max(1, (area.width / cell).ceil()), ny = math.max(1, (area.height / cell).ceil());
    final slope = Float64List(nx * ny), bearing = Float64List(nx * ny);
    final hull = hullOnly ? convexHull([for (final s in terrain.samples) s.p]) : const <Pt>[];
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final k = j * nx + i;
        final p = Pt(area.minX + (i + 0.5) * cell, area.minY + (j + 0.5) * cell);
        if (hull.length >= 3 && !pointInPolygon(p, hull) && !pointOnPolygonBoundary(p, hull)) {
          slope[k] = double.nan;
          bearing[k] = double.nan;
          continue;
        }
        final sa = terrain.slopeAspectAt(p);
        slope[k] = sa == null ? double.nan : sa.$1 * 100;
        bearing[k] = sa == null ? double.nan : bearingDeg(sa.$2);
      }
    }
    return SlopeMap(origin: Pt(area.minX, area.minY), cell: cell, nx: nx, ny: ny, slopePct: slope, bearing: bearing);
  }

  /// Share (0–1) of the mapped cells in each slope class (optionally only
  /// the cells inside [polygon]).
  List<double> classShares({List<Pt>? polygon}) {
    final counts = List<int>.filled(slopeClasses.length, 0);
    var total = 0;
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final v = slopePct[j * nx + i];
        if (v.isNaN) continue;
        if (polygon != null && !pointInPolygon(Pt(origin.x + (i + 0.5) * cell, origin.y + (j + 0.5) * cell), polygon)) continue;
        counts[slopeClassOf(v)]++;
        total++;
      }
    }
    return [for (final c in counts) total == 0 ? 0.0 : c / total];
  }

  /// Mean and maximum slope (%) of the mapped cells.
  (double, double) get meanMax {
    var sum = 0.0, max = 0.0;
    var n = 0;
    for (final v in slopePct) {
      if (v.isNaN) continue;
      sum += v;
      max = math.max(max, v);
      n++;
    }
    return n == 0 ? (0, 0) : (sum / n, max);
  }
}

/// RGBA pixels of [m] (one per cell, top row first) coloured by slope class,
/// or by aspect when [aspect].
Uint8List slopeMapPixels(SlopeMap m, {bool aspect = false, int alpha = 150}) {
  final px = Uint8List(m.nx * m.ny * 4);
  for (var j = 0; j < m.ny; j++) {
    final row = m.ny - 1 - j;
    for (var i = 0; i < m.nx; i++) {
      final k = j * m.nx + i;
      final s = m.slopePct[k];
      if (s.isNaN) continue;
      final c = aspect ? aspectColor(m.bearing[k], s) : slopeClasses[slopeClassOf(s)].$2;
      final o = (row * m.nx + i) * 4;
      px[o] = (c >> 16) & 0xFF;
      px[o + 1] = (c >> 8) & 0xFF;
      px[o + 2] = c & 0xFF;
      px[o + 3] = alpha;
    }
  }
  return px;
}
