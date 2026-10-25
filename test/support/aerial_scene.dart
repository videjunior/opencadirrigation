/// A synthetic aerial view for the vegetation detection tests: lawns (one
/// with a patio and a tree, one half in a building's shade), tree crowns on
/// paving with their shadows, bare soil, a pool and a small green speck,
/// with the noise, texture and soft edges of a real image.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencadirrigation/core/model/geometry.dart';

List<Pt> sceneRect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

class AerialScene {
  AerialScene({this.widthM = 48, this.heightM = 36, this.pixelM = 0.1, this.seed = 7});

  /// Ground size (m) and resolution (m per pixel); scene coordinates in
  /// metres from the bottom-left corner, y up.
  final double widthM, heightM, pixelM;
  final int seed;

  int get width => (widthM / pixelM).round();
  int get height => (heightM / pixelM).round();

  // ---- what the scene holds (net areas in the comments)
  static final lawnA = sceneRect(4, 4, 28, 20); // 384 m² gross
  static final patio = sceneRect(8, 8, 12, 11); // 12 m², paving inside lawn A
  static const treeInLawn = (Pt(22, 14), 2.2); // 15.2 m², inside lawn A
  static const lawnB = [Pt(32, 4), Pt(46, 4), Pt(46, 18), Pt(38, 18)]; // 154 m², x < 40 in shade
  static const shadeX = 40.0;
  static const trees = [(Pt(36, 28), 2.5), (Pt(44, 30), 1.8)]; // 19.6 and 10.2 m², on paving
  static final soil = sceneRect(2, 26, 12, 34);
  static final pool = sceneRect(14, 24, 18, 27);
  static final speck = sceneRect(30, 30, 31.5, 31.5); // 2.25 m² of green

  static double get lawnBArea => polygonArea(lawnB).abs();
  static double circleArea(double r) => math.pi * r * r;

  /// World corners (bottom-left, bottom-right, top-right, top-left) of the
  /// scene placed with its bottom-left corner at [origin], turned by
  /// [rotationDeg] (as an image entity).
  List<Pt> corners({Pt origin = Pt.zero, double rotationDeg = 0}) {
    final r = degToRad(rotationDeg);
    final u = Pt.polar(widthM, r), v = Pt.polar(heightM, r + math.pi / 2);
    return [origin, origin + u, origin + u + v, origin + v];
  }

  /// World point of the scene point [p] in the placement of [corners].
  static Pt place(Pt p, {Pt origin = Pt.zero, double rotationDeg = 0}) => origin + p.rotate(degToRad(rotationDeg));

  /// RGBA rows, top to bottom; every pixel the mean of 2 × 2 samples.
  /// [transparentRight]: that share of the columns on the right has no data
  /// (map tiles not loaded).
  Uint8List rgba({double transparentRight = 0}) {
    final w = width, h = height;
    final rnd = math.Random(seed);
    double gauss() {
      final u1 = math.max(1e-12, rnd.nextDouble()), u2 = rnd.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    // value noise for the leaf clumps of the crowns (0.35 m cells) and the
    // stains of the paving (3 m cells)
    final leaves = _ValueNoise(rnd, widthM, heightM, 0.35), stains = _ValueNoise(rnd, widthM, heightM, 3);
    final out = Uint8List(4 * w * h);
    final cut = (w * (1 - transparentRight)).round();
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var s = 0; s < 4; s++) {
          final p = Pt((i + 0.25 + 0.5 * (s & 1)) * pixelM, heightM - (j + 0.25 + 0.5 * (s >> 1)) * pixelM);
          final c = _colour(p, leaves, stains);
          r += c.$1;
          g += c.$2;
          b += c.$3;
        }
        // sensor noise: mostly brightness, a little colour
        final l = gauss() * 4, k = 4 * (j * w + i);
        out[k] = (r / 4 + l + gauss() * 1.5).round().clamp(0, 255);
        out[k + 1] = (g / 4 + l + gauss() * 1.5).round().clamp(0, 255);
        out[k + 2] = (b / 4 + l + gauss() * 1.5).round().clamp(0, 255);
        out[k + 3] = i < cut ? 255 : 0;
      }
    }
    return out;
  }

  static (double, double, double) _colour(Pt p, _ValueNoise leaves, _ValueNoise stains) {
    for (final (c, r) in [treeInLawn, ...trees]) {
      if (p.distanceTo(c) <= r) {
        // clumps of leaves in light and shade, the crown darker at its rim
        final f = (1 + 0.5 * leaves.at(p)) * (1 - 0.25 * p.distanceTo(c) / r);
        return (52 * f, 88 * f, 46 * f);
      }
    }
    final stain = 1 + 0.05 * stains.at(p);
    (double, double, double) paving() => (134 * stain, 131 * stain, 126 * stain);
    if (pointInPolygon(p, lawnA) && !pointInPolygon(p, patio)) return _lawn(p);
    if (pointInPolygon(p, lawnB)) {
      final c = _lawn(p);
      return p.x < shadeX ? (c.$1 * 0.5, c.$2 * 0.5, c.$3 * 0.5 + 4) : c;
    }
    if (pointInPolygon(p, speck)) return _lawn(p);
    if (pointInPolygon(p, pool)) return (70, 176, 196);
    if (pointInPolygon(p, soil)) return (148 * stain, 114 * stain, 84 * stain);
    // the shadow of the first tree on the paving (bluish: lit by the sky)
    final (t0, r0) = trees.first;
    if (p.distanceTo(t0 + const Pt(2.4, -1.6)) <= r0 * 0.95) {
      final c = paving();
      return (c.$1 * 0.45, c.$2 * 0.45, c.$3 * 0.45 + 8);
    }
    return paving();
  }

  /// Mown grass: even, with the light and dark stripes of the mower.
  static (double, double, double) _lawn(Pt p) {
    final stripe = ((p.x / 1.5).floor().isEven ? 4.0 : -4.0);
    return (96 + stripe, 140 + stripe, 70 + stripe);
  }
}

/// Smooth random field in [-1, 1] over a grid of [cell] metres.
class _ValueNoise {
  _ValueNoise(math.Random rnd, double w, double h, this.cell) : nx = (w / cell).ceil() + 2, ny = (h / cell).ceil() + 2 {
    values = Float64List.fromList([for (var k = 0; k < nx * ny; k++) rnd.nextDouble() * 2 - 1]);
  }
  final double cell;
  final int nx, ny;
  late final Float64List values;

  double at(Pt p) {
    final fx = p.x / cell, fy = p.y / cell;
    final x0 = fx.floor().clamp(0, nx - 2), y0 = fy.floor().clamp(0, ny - 2);
    double s(double t) => t * t * (3 - 2 * t);
    final tx = s((fx - x0).clamp(0.0, 1.0)), ty = s((fy - y0).clamp(0.0, 1.0));
    double v(int x, int y) => values[y * nx + x];
    final a = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * tx, b = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * tx;
    return a + (b - a) * ty;
  }
}
