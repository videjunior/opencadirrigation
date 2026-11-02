/// Digital elevation model built from spot heights and contour lines.
///
/// Two interpolators: a Delaunay TIN with linear interpolation inside the
/// triangles (the DTM of CAD packages, exact on planar slopes) and inverse
/// distance weighting over the densified contour vertices (smooth, also
/// used outside the TIN hull). A uniform grid of cells, addressed by column
/// and row, keeps the nearest-sample queries fast and exact.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';
import 'tin.dart';

enum TerrainMethod { tin, idw }

class TerrainSample {
  const TerrainSample(this.p, this.z, {this.dem = false});
  final Pt p;
  final double z;

  /// Downloaded from an online elevation model: the first data thinned when
  /// the terrain has more samples than the TIN takes ([Terrain.tinLimit]);
  /// the user's own survey (contours, spot heights, breaklines) is kept.
  final bool dem;
}

class Terrain {
  Terrain({List<TerrainSample>? samples, this.densify = 5.0, this.method = TerrainMethod.tin, int? tinLimit}) : tinLimit = math.max(3, tinLimit ?? maxTinPoints) {
    if (samples != null) addAll(samples);
  }

  final double densify;
  final TerrainMethod method;

  /// Largest sample count this terrain triangulates as is (default
  /// [maxTinPoints]); above it the TIN takes all the surveyed data and a
  /// spatially even subset of the downloaded elevation model.
  final int tinLimit;
  final List<TerrainSample> _samples = [];
  bool _dirty = false;
  Tin? _tin;

  // Uniform grid over the bounds of the samples in compressed form: the
  // samples of the cell in column ix and row iy are
  // _cellItems[_cellStart[k] .. _cellStart[k + 1]) with k = iy * _nx + ix.
  // Cells are addressed by column and row, never through a hash, so a far
  // cell can never answer for a near one.
  double _cell = 10, _gx0 = 0, _gy0 = 0;
  int _nx = 0, _ny = 0;
  Int32List _cellStart = Int32List(1), _cellItems = Int32List(0);
  List<Pt>? _hull;

  bool get isEmpty => _samples.isEmpty && _breaklines.isEmpty;
  int get sampleCount => _samples.length;

  /// Breaklines as given: vertices and their elevations (NaN = unknown).
  final List<(List<Pt>, List<double>)> _breaklines = [];
  List<List<(double, double, double)>>? _resolved;
  bool _resolving = false;

  int get breaklineCount => _breaklines.length;

  /// Adds a breakline: the polyline [pts] with the elevation of every vertex
  /// in [zs] (NaN where unknown: taken from the other data there), sampled
  /// every [densify] metres with the elevation varying linearly along each
  /// segment. Its segments become edges of the TIN, so the surface folds
  /// along it; its samples also feed the IDW interpolation.
  void addBreakline(List<Pt> pts, List<double> zs) {
    if (pts.length < 2) return;
    _breaklines.add((List.of(pts), [for (var i = 0; i < pts.length; i++) i < zs.length ? zs[i] : double.nan]));
    _resolved = null;
    _dirty = true;
  }

  /// The breaklines densified, with every elevation known; their samples
  /// join the model the first time (unknown vertex elevations interpolated
  /// from the other samples first).
  List<List<(double, double, double)>> _breaklinePolylines() {
    final done = _resolved;
    if (done != null || _resolving) return done ?? const [];
    _resolving = true;
    final out = <List<(double, double, double)>>[];
    final adds = <TerrainSample>[];
    for (final (pts, zs) in _breaklines) {
      final z = [for (var i = 0; i < pts.length; i++) zs[i].isFinite ? zs[i] : (_samples.isEmpty ? double.nan : idwAt(pts[i], fallback: double.nan))];
      final line = <(double, double, double)>[];
      for (var i = 0; i < pts.length; i++) {
        if (i > 0) {
          final a = pts[i - 1], b = pts[i];
          final n = math.max(1, (a.distanceTo(b) / densify).ceil());
          for (var k = 1; k < n; k++) {
            final f = k / n;
            final q = Pt.lerp(a, b, f);
            line.add((q.x, q.y, z[i - 1] + (z[i] - z[i - 1]) * f));
          }
        }
        line.add((pts[i].x, pts[i].y, z[i]));
      }
      out.add(line);
      for (final (x, y, zz) in line) {
        if (zz.isFinite) adds.add(TerrainSample(Pt(x, y), zz));
      }
    }
    _resolved = out;
    _samples.addAll(adds);
    _dirty = true;
    _resolving = false;
    return out;
  }

  List<TerrainSample> get samples => List.unmodifiable(_samples);

  /// Default largest sample count triangulated as is ([tinLimit]); bigger
  /// surveys keep all their own data and thin the downloaded elevation
  /// model over a grid for the TIN (IDW keeps every sample).
  static const int maxTinPoints = 40000;

  /// Samples the TIN is built from: all of them up to [tinLimit]; above it
  /// every surveyed sample and an even spread of the downloaded elevation
  /// model in the rest of the budget (only the survey, spread, when it alone
  /// is larger).
  List<int> _tinSampleIndices() {
    final n = _samples.length;
    if (n <= tinLimit) return [for (var i = 0; i < n; i++) i];
    final own = <int>[], dem = <int>[];
    for (var i = 0; i < n; i++) {
      (_samples[i].dem ? dem : own).add(i);
    }
    if (own.length >= tinLimit) return _spread(own, tinLimit);
    return [...own, ..._spread(dem, tinLimit - own.length)]..sort();
  }

  /// Samples the TIN takes ([tinLimit]): every one when the terrain has no
  /// more than that.
  int get tinSampleCount => _samples.length <= tinLimit ? _samples.length : _tinSampleIndices().length;

  /// At most [budget] of the samples [idx], evenly spread over their extent:
  /// the corners of their outline (so the model covers the same area) and,
  /// in each cell of a grid over their bounds, the sample nearest its centre
  /// (an original sample, never an average).
  List<int> _spread(List<int> idx, int budget) {
    if (idx.length <= budget) return idx;
    if (budget <= 0) return const [];
    final outline = convexHull([for (final i in idx) _samples[i].p]).toSet();
    final corners = [
      for (final i in idx)
        if (outline.remove(_samples[i].p)) i,
    ];
    if (corners.length < budget) return ({..._grid(idx, budget - corners.length), ...corners}.toList()..sort());
    return _grid(idx, budget);
  }

  List<int> _grid(List<int> idx, int budget) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final i in idx) {
      final p = _samples[i].p;
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    final w = maxX - minX, h = maxY - minY;
    var cell = w > 0 && h > 0 ? math.sqrt(w * h / budget) : math.max(w, h) / budget;
    if (!(cell > 0)) return idx.sublist(0, budget);
    for (var round = 0; round < 60; round++) {
      final cols = (w / cell).floor() + 1;
      final best = <int, (double, int)>{};
      for (final i in idx) {
        final p = _samples[i].p;
        final ix = ((p.x - minX) / cell).floor(), iy = ((p.y - minY) / cell).floor();
        final dx = p.x - (minX + (ix + 0.5) * cell), dy = p.y - (minY + (iy + 0.5) * cell);
        final d2 = dx * dx + dy * dy;
        final key = iy * cols + ix;
        final b = best[key];
        // a tie goes to the least (x, y, z), whatever the order of the samples
        if (b == null || d2 < b.$1 || (d2 == b.$1 && _before(_samples[i], _samples[b.$2]))) best[key] = (d2, i);
      }
      if (best.length <= budget) return [for (final b in best.values) b.$2]..sort();
      cell *= math.max(1.02, math.sqrt(best.length / budget));
    }
    return idx.sublist(0, budget);
  }

  /// Whether sample [a] comes before [b] in (x, y, z) order.
  static bool _before(TerrainSample a, TerrainSample b) => a.p.x != b.p.x ? a.p.x < b.p.x : (a.p.y != b.p.y ? a.p.y < b.p.y : a.z < b.z);

  /// The triangulation (built on first use).
  Tin get tin {
    var t = _tin;
    if (t == null || _dirty) {
      final lines = _breaklinePolylines();
      t = Tin.build([for (final i in _tinSampleIndices()) (_samples[i].p.x, _samples[i].p.y, _samples[i].z)], breaklines: lines);
      _tin = t;
      if (_dirty) _rebuild();
    }
    return t;
  }

  void clear() {
    _samples.clear();
    _breaklines.clear();
    _resolved = null;
    _tin = null;
    _hull = null;
    _dirty = true;
  }

  /// Adds a spot height; [dem] marks a point of a downloaded elevation model
  /// ([TerrainSample.dem]).
  void addSpot(Pt p, double z, {bool dem = false}) {
    // an unknown elevation (NaN, a damaged file) is no datum: 0 m would dig a
    // pit as deep as the terrain is high
    if (!z.isFinite || !p.x.isFinite || !p.y.isFinite) return;
    _samples.add(TerrainSample(p, z, dem: dem));
    _dirty = true;
  }

  void addAll(Iterable<TerrainSample> s) {
    _samples.addAll(s.where((x) => x.z.isFinite && x.p.x.isFinite && x.p.y.isFinite));
    _dirty = true;
  }

  /// Adds a contour polyline sampled every [densify] metres.
  void addContour(List<Pt> pts, double z) {
    if (!z.isFinite) return;
    pts = [
      for (final p in pts)
        if (p.x.isFinite && p.y.isFinite) p,
    ];
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
    _hull = null;
    final n = _samples.length;
    if (n == 0) {
      _nx = _ny = 0;
      _cellStart = Int32List(1);
      _cellItems = Int32List(0);
      _dirty = false;
      return;
    }
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final s in _samples) {
      minX = math.min(minX, s.p.x);
      minY = math.min(minY, s.p.y);
      maxX = math.max(maxX, s.p.x);
      maxY = math.max(maxY, s.p.y);
    }
    final span = math.max(maxX - minX, maxY - minY);
    _cell = math.max(1e-3, span / math.max(1, math.sqrt(n)));
    _gx0 = minX;
    _gy0 = minY;
    _nx = ((maxX - minX) / _cell).floor() + 1;
    _ny = ((maxY - minY) / _cell).floor() + 1;
    final cellOf = Int32List(n);
    final start = Int32List(_nx * _ny + 1);
    for (var i = 0; i < n; i++) {
      final p = _samples[i].p;
      final ix = ((p.x - _gx0) / _cell).floor().clamp(0, _nx - 1), iy = ((p.y - _gy0) / _cell).floor().clamp(0, _ny - 1);
      final k = iy * _nx + ix;
      cellOf[i] = k;
      start[k + 1]++;
    }
    for (var k = 0; k < _nx * _ny; k++) {
      start[k + 1] += start[k];
    }
    final fill = Int32List.fromList(start);
    final items = Int32List(n);
    for (var i = 0; i < n; i++) {
      items[fill[cellOf[i]]++] = i;
    }
    _cellStart = start;
    _cellItems = items;
    _dirty = false;
  }

  /// Whether [p] lies outside the area the data cover (their convex hull)
  /// by more than [margin] metres: its elevation is then extrapolated from
  /// the nearest samples, not interpolated between them.
  bool extrapolatesAt(Pt p, {double margin = 0}) {
    if (_breaklines.isNotEmpty && _resolved == null) _breaklinePolylines();
    if (_samples.isEmpty) return false;
    if (_dirty) _rebuild();
    final hull = _hull ??= convexHull([for (final s in _samples) s.p]);
    if (hull.length >= 3 && pointInPolygon(p, hull)) return false;
    // distance to the outline (to the line or the point the data make when
    // they do not span an area)
    var d = hull.length == 1 ? p.distanceTo(hull.first) : double.infinity;
    for (var i = 0; i < hull.length && hull.length > 1; i++) {
      d = math.min(d, distanceToSegment(p, hull[i], hull[(i + 1) % hull.length]));
    }
    return d > margin;
  }

  /// Elevation at [p]. Returns [fallback] when no data. With the TIN method
  /// points outside the triangulated hull fall back to IDW.
  double elevationAt(Pt p, {double fallback = 0, int neighbours = 8}) {
    if (_breaklines.isNotEmpty && _resolved == null) _breaklinePolylines();
    if (_samples.isEmpty) return fallback;
    if (method == TerrainMethod.tin) {
      final z = tin.elevationAt(p);
      if (z != null) return z;
    }
    return idwAt(p, fallback: fallback, neighbours: neighbours);
  }

  /// Inverse-distance interpolation over the [neighbours] nearest samples.
  double idwAt(Pt p, {double fallback = 0, int neighbours = 8}) {
    if (_breaklines.isNotEmpty && _resolved == null) _breaklinePolylines();
    final n = _samples.length;
    if (n == 0) return fallback;
    if (_dirty) _rebuild();
    // the k nearest samples, sorted by squared distance (ties: the first met)
    final k = neighbours.clamp(1, n);
    final bd = Float64List(k);
    final bi = Int32List(k);
    var m = 0;
    void cellAt(int ix, int iy) {
      final key = iy * _nx + ix;
      for (var q = _cellStart[key], end = _cellStart[key + 1]; q < end; q++) {
        final i = _cellItems[q];
        final s = _samples[i].p;
        final dx = s.x - p.x, dy = s.y - p.y;
        final d2 = dx * dx + dy * dy;
        if (m == k && d2 >= bd[k - 1]) continue;
        var j = m < k ? m++ : k - 1;
        while (j > 0 && bd[j - 1] > d2) {
          bd[j] = bd[j - 1];
          bi[j] = bi[j - 1];
          j--;
        }
        bd[j] = d2;
        bi[j] = i;
      }
    }

    // rings of cells around the cell of p (which may lie off the grid): ring
    // r is the outline of the square of cells cx±r × cy±r. Once k samples
    // are in hand, every sample not seen yet lies outside that square, at
    // least as far from p as its nearest side: the search stops when that
    // distance reaches the k-th nearest one, an exact k-nearest search
    // however far from the data p is.
    final cx = ((p.x - _gx0) / _cell).floor(), cy = ((p.y - _gy0) / _cell).floor();
    final r0 = math.max(0, math.max(math.max(-cx, cx - (_nx - 1)), math.max(-cy, cy - (_ny - 1))));
    final rEnd = math.max(math.max(cx, _nx - 1 - cx), math.max(cy, _ny - 1 - cy));
    for (var r = r0; r <= rEnd; r++) {
      if (r == 0) {
        cellAt(cx, cy);
      } else {
        final x0 = math.max(cx - r, 0), x1 = math.min(cx + r, _nx - 1);
        for (final y in [cy - r, cy + r]) {
          if (y < 0 || y >= _ny) continue;
          for (var x = x0; x <= x1; x++) {
            cellAt(x, y);
          }
        }
        final y0 = math.max(cy - r + 1, 0), y1 = math.min(cy + r - 1, _ny - 1);
        for (final x in [cx - r, cx + r]) {
          if (x < 0 || x >= _nx) continue;
          for (var y = y0; y <= y1; y++) {
            cellAt(x, y);
          }
        }
      }
      if (m == k) {
        final gap = math.min(math.min(p.x - (_gx0 + (cx - r) * _cell), _gx0 + (cx + r + 1) * _cell - p.x), math.min(p.y - (_gy0 + (cy - r) * _cell), _gy0 + (cy + r + 1) * _cell - p.y));
        if (gap > 0 && gap * gap >= bd[k - 1]) break;
      }
    }
    if (m == 0) return fallback;
    if (bd[0] < 1e-18) return _samples[bi[0]].z;
    var num = 0.0, den = 0.0;
    for (var j = 0; j < m; j++) {
      final w = 1 / bd[j];
      num += w * _samples[bi[j]].z;
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

  /// Slope (m/m) and aspect (radians, mathematical angle of the direction of
  /// steepest descent) at [p], from the TIN or by central differences;
  /// null when the terrain is empty.
  (double, double)? slopeAspectAt(Pt p) {
    if (_samples.isEmpty) return null;
    if (method == TerrainMethod.tin) {
      final s = tin.slopeAt(p);
      if (s != null && s.$1.isFinite) return s;
    }
    const h = 1.0;
    final dzdx = (elevationAt(p + const Pt(h, 0)) - elevationAt(p - const Pt(h, 0))) / (2 * h);
    final dzdy = (elevationAt(p + const Pt(0, h)) - elevationAt(p - const Pt(0, h))) / (2 * h);
    return (math.sqrt(dzdx * dzdx + dzdy * dzdy), math.atan2(-dzdy, -dzdx));
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
