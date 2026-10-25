/// Grid decimation of large point sets (LAS point clouds, LandXML and other
/// surveyed surfaces) so the terrain model stays within
/// `Terrain.maxTinPoints`: points fall into the cells of a regular grid over
/// their bounds, sized so the grid has at most the requested number of cells,
/// and each cell keeps one point. Points are added one at a time (a stream);
/// memory grows with the occupied cells, not with the input.
library;

import 'dart:math' as math;

/// What a cell keeps.
enum GridReduce {
  /// Mean position and mean elevation of the cell's points (a smoothed model
  /// of classified ground).
  mean,

  /// The lowest point (bare ground from unclassified data, where vegetation
  /// and buildings sit above it).
  lowest,

  /// The point nearest the cell centre (an original, measured point).
  nearestCentre,
}

class PointGridDecimator {
  /// A grid over [minX]…[maxX] × [minY]…[maxY] with at most [maxCells] cells.
  PointGridDecimator({required this.minX, required this.minY, required double maxX, required double maxY, required int maxCells, this.reduce = GridReduce.mean}) {
    final w = math.max(maxX - minX, 0.0), h = math.max(maxY - minY, 0.0);
    final n = math.max(maxCells, 1);
    var c = w > 0 && h > 0 ? math.sqrt(w * h / n) : math.max(w, h) / n;
    if (!(c > 0)) c = 1;
    while (((w / c).floor() + 1) * ((h / c).floor() + 1) > n) {
      c *= 1.02;
    }
    cell = c;
    _cols = (w / c).floor() + 1;
  }

  final double minX, minY;
  final GridReduce reduce;

  /// Cell size (units of the coordinates).
  late final double cell;
  late final int _cols;
  final _cells = <int, _Cell>{};

  /// Points added so far.
  int added = 0;

  void add(double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return;
    added++;
    final ix = ((x - minX) / cell).floor(), iy = ((y - minY) / cell).floor();
    final key = iy * _cols + ix;
    final c = _cells[key] ??= _Cell();
    switch (reduce) {
      case GridReduce.mean:
        c.sx += x;
        c.sy += y;
        c.sz += z;
        c.n++;
      case GridReduce.lowest:
        if (c.n == 0 || z < c.z) {
          c.x = x;
          c.y = y;
          c.z = z;
        }
        c.n++;
      case GridReduce.nearestCentre:
        final cx = minX + (ix + 0.5) * cell, cy = minY + (iy + 0.5) * cell;
        final d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
        if (c.n == 0 || d < c.d) {
          c.d = d;
          c.x = x;
          c.y = y;
          c.z = z;
        }
        c.n++;
    }
  }

  int get cellCount => _cells.length;

  /// One point per occupied cell (x, y, z).
  List<(double, double, double)> result() => [
    for (final c in _cells.values)
      if (reduce == GridReduce.mean) (c.sx / c.n, c.sy / c.n, c.sz / c.n) else (c.x, c.y, c.z),
  ];
}

class _Cell {
  double sx = 0, sy = 0, sz = 0, x = 0, y = 0, z = 0, d = 0;
  int n = 0;
}
