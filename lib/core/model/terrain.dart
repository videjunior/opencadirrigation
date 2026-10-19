/// Digital elevation model built from spot heights and contour lines.
///
/// Two interpolators: a Delaunay TIN with linear interpolation inside the
/// triangles (the DTM of CAD packages, exact on planar slopes) and inverse
/// distance weighting over the densified contour vertices (smooth, also
/// used outside the TIN hull). A spatial hash keeps queries fast.
library;

import 'dart:math' as math;

import 'geometry.dart';
import 'tin.dart';

enum TerrainMethod { tin, idw }

class TerrainSample {
  const TerrainSample(this.p, this.z);
  final Pt p;
  final double z;
}

class Terrain {
  Terrain({List<TerrainSample>? samples, this.densify = 5.0, this.method = TerrainMethod.tin}) {
    if (samples != null) addAll(samples);
  }

  final double densify;
  final TerrainMethod method;
  final List<TerrainSample> _samples = [];
  final Map<int, List<int>> _grid = {};
  double _cell = 10;
  bool _dirty = false;
  Tin? _tin;

  bool get isEmpty => _samples.isEmpty;
  int get sampleCount => _samples.length;
  List<TerrainSample> get samples => List.unmodifiable(_samples);

  /// Largest sample count triangulated as is; bigger surveys are decimated
  /// uniformly for the TIN (IDW keeps every sample).
  static int maxTinPoints = 12000;

  /// The triangulation (built on first use).
  Tin get tin {
    var t = _tin;
    if (t == null || _dirty) {
      final n = _samples.length;
      final step = n > maxTinPoints ? (n / maxTinPoints).ceil() : 1;
      t = Tin.build([for (var i = 0; i < n; i += step) (_samples[i].p.x, _samples[i].p.y, _samples[i].z)]);
      _tin = t;
      if (_dirty) _rebuild();
    }
    return t;
  }

  void clear() {
    _samples.clear();
    _grid.clear();
    _tin = null;
    _dirty = false;
  }

  void addSpot(Pt p, double z) {
    _samples.add(TerrainSample(p, z));
    _dirty = true;
  }

  void addAll(Iterable<TerrainSample> s) {
    _samples.addAll(s);
    _dirty = true;
  }

  /// Adds a contour polyline sampled every [densify] metres.
  void addContour(List<Pt> pts, double z) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      addSpot(pts.first, z);
      return;
    }
    final total = polylineLength(pts);
    final n = math.max(1, (total / densify).ceil());
    for (var i = 0; i <= n; i++) {
      addSpot(pointAlongPolyline(pts, total * i / n), z);
    }
    _dirty = true;
  }

  void _rebuild() {
    _grid.clear();
    if (_samples.isEmpty) {
      _dirty = false;
      return;
    }
    final b = Bounds.ofPoints(_samples.map((s) => s.p));
    final span = math.max(b.width, b.height);
    _cell = math.max(1e-3, span / math.max(1, math.sqrt(_samples.length)));
    for (var i = 0; i < _samples.length; i++) {
      _grid.putIfAbsent(_key(_samples[i].p), () => []).add(i);
    }
    _dirty = false;
  }

  int _key(Pt p) {
    final ix = (p.x / _cell).floor();
    final iy = (p.y / _cell).floor();
    return ix * 73856093 ^ iy * 19349663;
  }

  /// Elevation at [p]. Returns [fallback] when no data. With the TIN method
  /// points outside the triangulated hull fall back to IDW.
  double elevationAt(Pt p, {double fallback = 0, int neighbours = 8}) {
    if (_samples.isEmpty) return fallback;
    if (method == TerrainMethod.tin) {
      final z = tin.elevationAt(p);
      if (z != null) return z;
    }
    return idwAt(p, fallback: fallback, neighbours: neighbours);
  }

  /// Inverse-distance interpolation over the nearest samples.
  double idwAt(Pt p, {double fallback = 0, int neighbours = 8}) {
    if (_samples.isEmpty) return fallback;
    if (_dirty) _rebuild();
    // gather candidates from expanding rings; cells share a hashed key, so a
    // far cell can bring back a list already taken: each sample counts once
    // (counting it twice weighted the average by where the drawing lies)
    final best = <(double, int)>[];
    final seen = <int>{};
    final ix = (p.x / _cell).floor();
    final iy = (p.y / _cell).floor();
    var ring = 0;
    final maxRing = 64;
    while (ring <= maxRing) {
      for (var dx = -ring; dx <= ring; dx++) {
        for (var dy = -ring; dy <= ring; dy++) {
          if (ring > 0 && dx.abs() != ring && dy.abs() != ring) continue;
          final key = (ix + dx) * 73856093 ^ (iy + dy) * 19349663;
          final list = _grid[key];
          if (list == null) continue;
          for (final i in list) {
            if (!seen.add(i)) continue;
            best.add((_samples[i].p.distanceTo(p), i));
          }
        }
      }
      if ((best.length >= neighbours && ring >= 1) || seen.length == _samples.length) break;
      ring++;
    }
    if (best.isEmpty) {
      // brute force fallback
      for (var i = 0; i < _samples.length; i++) {
        best.add((_samples[i].p.distanceTo(p), i));
      }
    }
    best.sort((a, b) => a.$1.compareTo(b.$1));
    final use = best.take(neighbours).toList();
    if (use.first.$1 < 1e-9) return _samples[use.first.$2].z;
    var num = 0.0, den = 0.0;
    for (final (d, i) in use) {
      final w = 1 / (d * d);
      num += w * _samples[i].z;
      den += w;
    }
    return den == 0 ? fallback : num / den;
  }

  /// Slope (m/m) at [p] from the TIN, or a finite difference otherwise.
  double slopeAt(Pt p) {
    if (_samples.isEmpty) return 0;
    if (method == TerrainMethod.tin) {
      final s = tin.slopeAt(p);
      if (s != null && s.$1.isFinite) return s.$1;
    }
    const h = 1.0;
    final dzdx = (elevationAt(p + const Pt(h, 0)) - elevationAt(p - const Pt(h, 0))) / (2 * h);
    final dzdy = (elevationAt(p + const Pt(0, h)) - elevationAt(p - const Pt(0, h))) / (2 * h);
    return math.sqrt(dzdx * dzdx + dzdy * dzdy);
  }

  /// Contour polylines every [interval] metres generated from the TIN.
  List<(double, List<Pt>)> generateContours(double interval) => _samples.length < 3 ? const [] : tin.contours(interval);

  (double, double) get elevationRange {
    if (_samples.isEmpty) return (0, 0);
    var lo = double.infinity, hi = -double.infinity;
    for (final s in _samples) {
      lo = math.min(lo, s.z);
      hi = math.max(hi, s.z);
    }
    return (lo, hi);
  }
}

/// A round contour interval (m) for an elevation [range] (m): the smallest
/// of 0.25, 0.5, 1, 2, 5, 10, 20, 50, 100 that draws at most [maxContours]
/// contours.
double niceContourInterval(double range, {int maxContours = 20}) {
  const steps = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
  if (!(range > 0) || !range.isFinite) return 1;
  for (final s in steps) {
    if (range / s <= maxContours) return s;
  }
  return steps.last;
}
