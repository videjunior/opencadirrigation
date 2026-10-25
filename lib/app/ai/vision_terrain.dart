/// The ground for the AI assistant: pictures of the relief from the terrain
/// model of the project (a hillshade, colours by elevation or the app's
/// slope classes and aspect, labelled contour lines, hatching where heights
/// are interpolated far from any data), a profile along a line, and what
/// the terrain data are made of and how far they can be trusted.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/model/slope_map.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import 'vision_mapping.dart';

/// What colours the ground in a terrain picture.
enum TerrainColour { elevation, slope, aspect, none }

/// What a terrain picture draws.
class TerrainPictureOptions {
  const TerrainPictureOptions({this.colour = TerrainColour.elevation, this.hillshade = true, this.contours = true, this.interval, this.opacity = 1});
  final TerrainColour colour;
  final bool hillshade, contours;

  /// Contour interval (m); null: a round one giving 10–15 lines.
  final double? interval;

  /// Opacity of the colours and the hillshade (over a base map).
  final double opacity;
}

/// The samples of a terrain model in a spatial hash: the distance from a
/// point to the nearest one.
class NearestSamples {
  NearestSamples(Iterable<Pt> pts, this.cell) {
    for (final p in pts) {
      _b.putIfAbsent(_key((p.x / cell).floor(), (p.y / cell).floor()), () => []).add(p);
    }
  }
  final double cell;
  final Map<int, List<Pt>> _b = {};

  static int _key(int ix, int iy) => ix * 73856093 ^ iy * 19349663;

  /// Distance to the nearest sample, exact up to [rings] cells; infinity
  /// when none lies that near.
  double distance(Pt q, {int rings = 1}) {
    var best = double.infinity;
    final ix = (q.x / cell).floor(), iy = (q.y / cell).floor();
    for (var dx = -rings; dx <= rings; dx++) {
      for (var dy = -rings; dy <= rings; dy++) {
        final l = _b[_key(ix + dx, iy + dy)];
        if (l == null) continue;
        for (final p in l) {
          final d = (p - q).length;
          if (d < best) best = d;
        }
      }
    }
    return best <= cell * rings ? best : double.infinity;
  }
}

/// Where the samples of a terrain model lie: their hull, density and the
/// distance past which a height is far from any data.
class TerrainCoverage {
  TerrainCoverage._(this.samples, this.hull, this.hullArea, this.extent, this.spacing, this.farM) : near = NearestSamples(samples, farM);

  /// Positions of the samples (contour vertices every few metres, spot
  /// heights, breakline points).
  final List<Pt> samples;
  final List<Pt> hull;

  /// Area of [hull] (m²).
  final double hullArea;
  final Bounds extent;

  /// Mean distance between samples, and the distance from the nearest
  /// sample past which a height counts as far from data (m).
  final double spacing, farM;
  final NearestSamples near;

  bool get isEmpty => samples.isEmpty;

  /// Inside the hull of the samples (with fewer than three, nowhere).
  bool inside(Pt p) => hull.length >= 3 && (pointInPolygon(p, hull) || pointOnPolygonBoundary(p, hull));

  /// Inside the data and near a sample.
  bool reliable(Pt p) => inside(p) && near.distance(p) <= farM;

  static final Expando<TerrainCoverage> _cache = Expando<TerrainCoverage>('terrainCoverage');

  /// The coverage of [t] (kept with it: the toolbox rebuilds the terrain
  /// after every change).
  static TerrainCoverage of(Terrain t) => _cache[t] ??= _build(t);

  static TerrainCoverage _build(Terrain t) {
    // the breaklines join the samples on the first height asked
    if (!t.isEmpty) t.elevationAt(Pt.zero);
    final pts = [for (final s in t.samples) s.p];
    if (pts.isEmpty) return TerrainCoverage._(pts, const [], 0, Bounds.empty, 0, 10);
    final hull = convexHull(pts);
    final area = hull.length >= 3 ? polygonArea(hull).abs() : 0.0;
    final extent = Bounds.ofPoints(pts);
    final spacing = area > 0 && pts.length > 1 ? math.sqrt(area / pts.length) : math.max(10.0, math.max(extent.width, extent.height));
    return TerrainCoverage._(pts, hull, area, extent, spacing, math.max(10.0, 2.5 * spacing));
  }
}

/// Extent of the data of [t] (empty without any).
Bounds terrainExtent(Terrain t) => TerrainCoverage.of(t).extent;

/// The hypsometric ramp of the elevation colours, low to high.
const elevationRamp = <(double, int)>[(0, 0xFF1B5E20), (0.22, 0xFF4CAF50), (0.45, 0xFFCDDC39), (0.65, 0xFFFFC107), (0.85, 0xFF8D6E63), (1, 0xFFF5F5F5)];

int _ramp(double t) {
  final v = t.isFinite ? t.clamp(0.0, 1.0) : 0.0;
  for (var k = 1; k < elevationRamp.length; k++) {
    final (t1, c1) = elevationRamp[k];
    if (v <= t1) {
      final (t0, c0) = elevationRamp[k - 1];
      final f = t1 > t0 ? (v - t0) / (t1 - t0) : 0.0;
      int ch(int s) => ((((c0 >> s) & 0xFF) * (1 - f) + ((c1 >> s) & 0xFF) * f).round());
      return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
    }
  }
  return elevationRamp.last.$2;
}

Future<ui.Image> _image(Uint8List rgba, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

TextPainter _tp(String s, double size, Color ink, {FontWeight weight = FontWeight.normal}) => TextPainter(
  text: TextSpan(
    text: s,
    style: TextStyle(fontSize: size, color: ink, fontFamily: 'monospace', height: 1.15, fontWeight: weight),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Compass names of the eight aspect sectors.
const _sectors = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/// The relief of a terrain picture, prepared for its frame: the images,
/// the contour lines, the figures for the text and the legend.
class TerrainLayer {
  TerrainLayer._(this.o, this.frame);
  final TerrainPictureOptions o;
  final PictureFrame frame;

  ui.Image? _colour, _slope, _shade;
  Rect _slopeRect = Rect.zero, _gridRect = Rect.zero;
  Path? _hatch;
  final List<(double, List<Offset>, bool)> _contours = [];
  Rect? _legend;

  /// Range of the ground in the picture (m), its mean and steepest slope
  /// (%), and the vertical exaggeration of the hillshade.
  double zMin = 0, zMax = 0, meanSlope = 0, maxSlope = 0, exaggeration = 1;

  /// Contour interval (m) and the lines drawn.
  double interval = 0;
  int lines = 0;

  /// Share of the picture outside the data or far from any sample, and the
  /// distance that counts as far (m).
  double farShare = 0, farM = 0;

  /// Share of the mapped area in each slope class (slope colours).
  List<double> classShares = const [];
  int samples = 0;

  int get _zDecimals => interval > 0 && interval < 0.1 ? 2 : (interval > 0 && interval < 1 ? 2 : 1);

  /// Draws the colours, the hatching and the contours (under the drawing).
  void paintUnder(Canvas canvas, PictureFrame f) {
    final full = Offset.zero & Size(f.width.toDouble(), f.height.toDouble());
    final layered = o.opacity < 0.999;
    if (layered) canvas.saveLayer(full, Paint()..color = Color.fromRGBO(255, 255, 255, o.opacity.clamp(0.1, 1.0)));
    final smooth = Paint()..filterQuality = FilterQuality.medium;
    final colour = _colour, slope = _slope, shade = _shade;
    if (colour != null) canvas.drawImageRect(colour, Rect.fromLTWH(0, 0, colour.width.toDouble(), colour.height.toDouble()), _gridRect, smooth);
    if (slope != null) {
      canvas.drawImageRect(slope, Rect.fromLTWH(0, 0, slope.width.toDouble(), slope.height.toDouble()), _slopeRect, Paint()..filterQuality = FilterQuality.none);
    }
    if (shade != null) {
      canvas.drawImageRect(
        shade,
        Rect.fromLTWH(0, 0, shade.width.toDouble(), shade.height.toDouble()),
        _gridRect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = (colour == null && slope == null) ? BlendMode.srcOver : BlendMode.multiply,
      );
    }
    if (layered) canvas.restore();
    final hatch = _hatch;
    if (hatch != null) {
      canvas.save();
      canvas.clipPath(hatch);
      final dark = Paint()
        ..color = const Color(0x99000000)
        ..strokeWidth = 1.2;
      final light = Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1;
      for (var d = -f.height.toDouble(); d < f.width; d += 8) {
        canvas.drawLine(Offset(d, f.height.toDouble()), Offset(d + f.height, 0), dark);
        canvas.drawLine(Offset(d + 2, f.height.toDouble()), Offset(d + 2 + f.height, 0), light);
      }
      canvas.restore();
    }
    if (_contours.isNotEmpty) _paintContours(canvas, f);
  }

  void _paintContours(Canvas canvas, PictureFrame f) {
    final halo = Paint()
      ..color = const Color(0x8C000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final thin = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    final bold = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeJoin = StrokeJoin.round;
    for (final (_, px, index) in _contours) {
      final path = Path()..addPolygon(px, false);
      canvas.drawPath(path, index ? (Paint.from(halo)..strokeWidth = 4) : halo);
      canvas.drawPath(path, index ? bold : thin);
    }
    // labels along the lines, the index contours first, none over another
    final taken = <Rect>[?_legend];
    final order = [..._contours]..sort((a, b) => (b.$3 ? 1 : 0).compareTo(a.$3 ? 1 : 0));
    var placed = 0;
    for (final (z, px, index) in order) {
      if (placed >= 80) break;
      var run = 0.0, next = 70.0;
      for (var i = 1; i < px.length && placed < 80; i++) {
        run += (px[i] - px[i - 1]).distance;
        if (run < next) continue;
        final at = px[i];
        final tp = _tp(fmt(z, _zDecimals), 9.5, Colors.white, weight: index ? FontWeight.bold : FontWeight.normal);
        final r = Rect.fromCenter(center: at, width: tp.width + 4, height: tp.height + 2);
        if (r.left > 4 && r.top > 20 && r.right < f.width - 4 && r.bottom < f.height - 24 && taken.every((x) => !x.overlaps(r.inflate(3)))) {
          canvas.drawRect(r, Paint()..color = const Color(0xC0000000));
          tp.paint(canvas, r.topLeft + const Offset(2, 1));
          taken.add(r);
          placed++;
          next = run + 220;
        } else {
          next = run + 25;
        }
        tp.dispose();
      }
    }
  }

  /// Draws the legend, top right (over the drawing and the grid).
  void paintLegend(Canvas canvas, PictureFrame f) {
    final box = _legend;
    if (box == null) return;
    canvas.drawRect(box, Paint()..color = const Color(0xD9000000));
    var y = box.top + 4;
    void line(String s, {Color? swatch, bool hatch = false}) {
      final tp = _tp(s, 10, Colors.white);
      var x = box.left + 6;
      if (swatch != null || hatch) {
        final r = Rect.fromLTWH(x, y + 2, 11, 11);
        if (swatch != null) canvas.drawRect(r, Paint()..color = swatch);
        if (hatch) {
          canvas.drawRect(r, Paint()..color = const Color(0xFF555555));
          canvas.drawLine(r.bottomLeft, r.topRight, Paint()..color = Colors.white);
        }
        x += 16;
      }
      tp.paint(canvas, Offset(x, y));
      y += 15;
      tp.dispose();
    }

    switch (o.colour) {
      case TerrainColour.elevation:
        line('Elevation (m)');
        final bar = Rect.fromLTWH(box.left + 6, y + 2, 12, 96);
        for (var k = 0; k < 48; k++) {
          canvas.drawRect(Rect.fromLTWH(bar.left, bar.top + k * 2, bar.width, 2.5), Paint()..color = Color(_ramp(1 - k / 47)));
        }
        for (final (t, v) in [(0.0, zMax), (0.5, (zMin + zMax) / 2), (1.0, zMin)]) {
          final tp = _tp(fmt(v, 1), 10, Colors.white);
          tp.paint(canvas, Offset(bar.right + 5, bar.top + t * bar.height - tp.height / 2));
          tp.dispose();
        }
        y = bar.bottom + 6;
      case TerrainColour.slope:
        line('Slope (%)');
        var lo = 0.0;
        for (var k = 0; k < slopeClasses.length; k++) {
          final (hi, c) = slopeClasses[k];
          final share = k < classShares.length ? classShares[k] : 0.0;
          line('${hi.isInfinite ? '> ${fmt(lo, 0)}' : '${fmt(lo, 0)}–${fmt(hi, 0)}'}  ${fmt(share * 100, 0)} %', swatch: Color(c));
          lo = hi;
        }
      case TerrainColour.aspect:
        line('Aspect (faces)');
        for (var k = 0; k < _sectors.length; k++) {
          line(_sectors[k], swatch: Color(aspectColor(k * 45.0, 10)));
        }
        line('flat < 1 %', swatch: Color(aspectColor(0, 0)));
      case TerrainColour.none:
        line(o.hillshade ? 'Hillshade' : 'Contours');
    }
    if (lines > 0) line('contours ${fmt(interval, interval < 1 ? 2 : (interval < 10 ? 1 : 0))} m');
    if (farShare > 0) line('far from data', hatch: true);
  }

  Size _legendSize() {
    var rows = 1 + (lines > 0 ? 1 : 0) + (farShare > 0 ? 1 : 0);
    var h = 0.0;
    switch (o.colour) {
      case TerrainColour.elevation:
        h = 104;
      case TerrainColour.slope:
        rows += slopeClasses.length;
      case TerrainColour.aspect:
        rows += _sectors.length + 1;
      case TerrainColour.none:
        break;
    }
    return Size(150, rows * 15.0 + h + 8);
  }

  /// The figures of the picture in words, for the model.
  String describe() {
    final out = <String>[];
    out.add('In this picture the ground lies between ${fmt(zMin, 2)} and ${fmt(zMax, 2)} m (mean slope ${fmt(meanSlope, 1)} %, steepest ${fmt(maxSlope, 1)} %).');
    final shade = o.hillshade ? ', shaded by a hillshade lit from the north-west (${fmt(exaggeration, 1)}× vertical exaggeration: bright faces look north-west, dark ones south-east)' : '';
    switch (o.colour) {
      case TerrainColour.elevation:
        out.add('Colours: elevation, dark green (${fmt(zMin, 1)} m) → green → yellow → amber → brown → white (${fmt(zMax, 1)} m)$shade.');
      case TerrainColour.slope:
        var lo = 0.0;
        final parts = <String>[];
        for (var k = 0; k < slopeClasses.length; k++) {
          final (hi, _) = slopeClasses[k];
          final share = k < classShares.length ? classShares[k] : 0.0;
          if (share > 0) parts.add('${hi.isInfinite ? '> ${fmt(lo, 0)}' : '${fmt(lo, 0)}–${fmt(hi, 0)}'} % ${fmt(share * 100, 0)} %');
          lo = hi;
        }
        out.add('Colours: slope classes as the app\'s slope map (dark green flat → light green → yellow → orange → red → purple steep); share of the mapped area: ${parts.join(', ')}$shade.');
      case TerrainColour.aspect:
        out.add(
          'Colours: aspect, the compass direction the ground faces (downhill): N red, NE orange, E yellow-green, SE green, S cyan, SW blue, W violet, NW magenta; grey where flatter than 1 %$shade.',
        );
      case TerrainColour.none:
        out.add(o.hillshade ? 'A grey hillshade lit from the north-west (${fmt(exaggeration, 1)}× vertical exaggeration).' : 'No colours: contours only.');
    }
    if (o.contours) {
      out.add(
        lines == 0
            ? 'No contour line in this picture (fewer than three samples, or the ground varies less than the interval of ${fmt(interval, 2)} m).'
            : 'Contours: every ${fmt(interval, interval < 1 ? 2 : 1)} m (white; every ${fmt(5 * interval, interval < 1 ? 2 : 1)} m bolder), $lines lines, labelled with their elevation in m.',
      );
    }
    if (farShare > 0.001) {
      out.add(
        'Hatched: ${fmt(farShare * 100, 0)} % of the picture lies outside the data or farther than ${fmt(farM, 0)} m from any height sample: heights there are interpolated or extrapolated, so less reliable (terrain_info tells more; download_terrain or a survey fills the gaps).',
      );
    }
    return out.join('\n');
  }

  void dispose() {
    _colour?.dispose();
    _slope?.dispose();
    _shade?.dispose();
    _colour = _slope = _shade = null;
  }
}

/// Prepares the relief of [t] for the frame [f] of a picture.
Future<TerrainLayer> prepareTerrainLayer(Terrain t, PictureFrame f, TerrainPictureOptions o) async {
  final layer = TerrainLayer._(o, f);
  final cov = TerrainCoverage.of(t);
  layer.samples = cov.samples.length;
  layer.farM = cov.farM;
  // heights on a grid of cells a few pixels wide, rows from the top
  final cellPx = math.max(2, (math.max(f.width, f.height) / 256).ceil());
  final nx = (f.width / cellPx).ceil(), ny = (f.height / cellPx).ceil();
  final cell = cellPx * f.mpp;
  final n = nx * ny;
  final z = Float64List(n);
  final inside = Uint8List(n), far = Uint8List(n);
  var lo = double.infinity, hi = -double.infinity, loAll = double.infinity, hiAll = -double.infinity;
  var farCount = 0;
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final k = j * nx + i;
      final p = f.toWorld((i + 0.5) * cellPx, (j + 0.5) * cellPx);
      final v = t.elevationAt(p, fallback: double.nan);
      z[k] = v;
      final inHull = cov.inside(p);
      inside[k] = inHull ? 1 : 0;
      final isFar = !inHull || cov.near.distance(p) > cov.farM;
      far[k] = isFar ? 1 : 0;
      final onPicture = (i + 0.5) * cellPx <= f.width && (j + 0.5) * cellPx <= f.height;
      if (isFar && onPicture) farCount++;
      if (!v.isFinite) continue;
      loAll = math.min(loAll, v);
      hiAll = math.max(hiAll, v);
      if (inHull) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
  }
  if (!lo.isFinite) {
    lo = loAll;
    hi = hiAll;
  }
  if (!lo.isFinite) {
    lo = 0;
    hi = 0;
  }
  layer
    ..zMin = lo
    ..zMax = hi
    ..farShare = farCount / math.max(1, ((f.width / cellPx).floor()) * ((f.height / cellPx).floor()))
    .._gridRect = Rect.fromLTWH(0, 0, nx * cellPx.toDouble(), ny * cellPx.toDouble());
  layer.farShare = layer.farShare.clamp(0.0, 1.0);

  // gradients (Horn, 3 × 3 cells; y north)
  double at(int i, int j) {
    final v = z[j.clamp(0, ny - 1) * nx + i.clamp(0, nx - 1)];
    return v.isFinite ? v : z[j * nx + i];
  }

  final gx = Float64List(n), gy = Float64List(n);
  final mags = <double>[];
  var sum = 0.0, steep = 0.0, count = 0;
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final k = j * nx + i;
      if (!z[k].isFinite) continue;
      final dzdx = ((at(i + 1, j - 1) + 2 * at(i + 1, j) + at(i + 1, j + 1)) - (at(i - 1, j - 1) + 2 * at(i - 1, j) + at(i - 1, j + 1))) / (8 * cell);
      final dzdy = ((at(i - 1, j - 1) + 2 * at(i, j - 1) + at(i + 1, j - 1)) - (at(i - 1, j + 1) + 2 * at(i, j + 1) + at(i + 1, j + 1))) / (8 * cell);
      if (!dzdx.isFinite || !dzdy.isFinite) continue;
      gx[k] = dzdx;
      gy[k] = dzdy;
      final g = math.sqrt(dzdx * dzdx + dzdy * dzdy);
      if (inside[k] == 1 || layer.samples < 3) {
        mags.add(g);
        sum += g;
        steep = math.max(steep, g);
        count++;
      }
    }
  }
  layer
    ..meanSlope = count == 0 ? 0 : 100 * sum / count
    ..maxSlope = 100 * steep;
  // exaggerate gentle ground so its relief shows: the 90th percentile
  // gradient drawn at about 22°
  if (mags.isNotEmpty) {
    mags.sort();
    final p90 = mags[(0.9 * (mags.length - 1)).round()];
    layer.exaggeration = p90 > 1e-6 ? (0.4 / p90).clamp(1.0, 40.0) : 1.0;
  }
  final ve = layer.exaggeration;
  // brightness of the hillshade: 1 on flat ground, light from the
  // north-west at 45° (L = (−0.5, 0.5, 0.707))
  double light(int k) {
    final nxv = -ve * gx[k], nyv = -ve * gy[k];
    final len = math.sqrt(nxv * nxv + nyv * nyv + 1);
    final s = (-0.5 * nxv + 0.5 * nyv + 0.70710678) / len;
    return (s / 0.70710678).clamp(0.0, 1.42);
  }

  if (o.colour == TerrainColour.elevation) {
    final px = Uint8List(n * 4);
    final span = hi - lo;
    for (var k = 0; k < n; k++) {
      final v = z[k];
      if (!v.isFinite) continue;
      final c = _ramp(span > 1e-9 ? (v - lo) / span : 0.5);
      final f0 = (o.hillshade ? 0.45 + 0.55 * light(k) : 1.0) * (inside[k] == 1 ? 1.0 : 0.7);
      px[4 * k] = (((c >> 16) & 0xFF) * f0).round().clamp(0, 255);
      px[4 * k + 1] = (((c >> 8) & 0xFF) * f0).round().clamp(0, 255);
      px[4 * k + 2] = ((c & 0xFF) * f0).round().clamp(0, 255);
      px[4 * k + 3] = 255;
    }
    layer._colour = await _image(px, nx, ny);
  } else if (o.colour == TerrainColour.slope || o.colour == TerrainColour.aspect) {
    // the app's slope map (View → Overlay → slope / aspect), over the picture
    final m = SlopeMap.compute(t, f.world, maxCells: math.min(60000, n));
    if (!m.isEmpty) {
      layer._slope = await _image(slopeMapPixels(m, aspect: o.colour == TerrainColour.aspect, alpha: 255), m.nx, m.ny);
      final b = m.bounds;
      layer._slopeRect = Rect.fromPoints(f.toPx(Pt(b.minX, b.maxY)), f.toPx(Pt(b.maxX, b.minY)));
      layer.classShares = m.classShares();
      final (mean, max) = m.meanMax;
      layer
        ..meanSlope = mean
        ..maxSlope = max;
    }
  }
  if (o.hillshade && o.colour != TerrainColour.elevation) {
    // grey alone, or multiplied over the slope colours
    final over = o.colour != TerrainColour.none;
    final px = Uint8List(n * 4);
    for (var k = 0; k < n; k++) {
      if (!z[k].isFinite) continue;
      final b = light(k);
      final g = ((over ? (0.6 + 0.4 * b).clamp(0.0, 1.0) : (0.15 + 0.5 * b).clamp(0.0, 1.0)) * 255).round();
      px[4 * k] = g;
      px[4 * k + 1] = g;
      px[4 * k + 2] = g;
      px[4 * k + 3] = 255;
    }
    layer._shade = await _image(px, nx, ny);
  }
  // hatching where the heights are far from data, by runs of cells
  if (farCount > 0) {
    final path = Path();
    for (var j = 0; j < ny; j++) {
      var start = -1;
      for (var i = 0; i <= nx; i++) {
        final isFar = i < nx && far[j * nx + i] == 1;
        if (isFar && start < 0) start = i;
        if (!isFar && start >= 0) {
          path.addRect(Rect.fromLTWH(start * cellPx.toDouble(), j * cellPx.toDouble(), (i - start) * cellPx.toDouble(), cellPx.toDouble()));
          start = -1;
        }
      }
    }
    layer._hatch = path;
  }
  // contours over the range of the picture
  final range = hi - lo;
  var interval = o.interval ?? niceContourInterval(range, maxContours: 14);
  if (range > 0 && range / interval > 80) interval = niceContourInterval(range, maxContours: 80);
  layer.interval = interval;
  if (o.contours && range > 0 && layer.samples >= 3) {
    final first = (lo / interval).ceil() * interval;
    final view = f.world.inflate(f.mpp * 4);
    for (final (level, pts) in t.tin.contours(interval, from: first, to: hi)) {
      if (pts.length < 2 || !Bounds.ofPoints(pts).intersects(view)) continue;
      final index = ((level / interval).round() % 5) == 0;
      layer._contours.add((level, [for (final p in pts) f.toPx(p)], index));
    }
    layer.lines = layer._contours.length;
  }
  final s = layer._legendSize();
  layer._legend = Rect.fromLTWH(math.max(0, f.width - s.width - 6), 22, s.width, s.height);
  return layer;
}

// ---------------------------------------------------------------- profile

/// The ground along [pts] from [t], sampled every [step] metres (default:
/// a hundredth of the length, 1–50 m), with [rows] rows of the table.
String terrainProfileText(Terrain t, List<Pt> pts, {double? step, int rows = 40, String method = 'TIN'}) {
  final total = polylineLength(pts);
  final cov = TerrainCoverage.of(t);
  var st = step ?? (total / 100).clamp(1.0, 50.0);
  if (total < st) st = total / 4;
  st = math.max(st, total / 2000);
  // the vertices and every step between them
  final vertexD = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    vertexD.add(vertexD.last + pts[i].distanceTo(pts[i - 1]));
  }
  final ds = <double>{...vertexD};
  for (var k = 1; k * st < total - 1e-9; k++) {
    ds.add(k * st);
  }
  final d = ds.toList()..sort();
  final p = [for (final x in d) pointAlongPolyline(pts, x)];
  final z = [for (final q in p) t.elevationAt(q)];
  final n = d.length;
  var rise = 0.0, fall = 0.0, up = 0.0, down = 0.0;
  var upAt = 0.0, downAt = 0.0;
  for (var i = 1; i < n; i++) {
    final dz = z[i] - z[i - 1], dd = d[i] - d[i - 1];
    if (dz > 0) rise += dz;
    if (dz < 0) fall -= dz;
    if (dd <= 1e-9) continue;
    final s = 100 * dz / dd;
    if (s > up) {
      up = s;
      upAt = d[i - 1];
    }
    if (s < down) {
      down = s;
      downAt = d[i - 1];
    }
  }
  var hiI = 0, loI = 0;
  for (var i = 1; i < n; i++) {
    if (z[i] > z[hiI]) hiI = i;
    if (z[i] < z[loI]) loI = i;
  }
  String at(int i) => 'd ${fmt(d[i], 1)} m [${fmt(p[i].x, 2)}, ${fmt(p[i].y, 2)}]';
  final out = <String>[
    'Terrain profile along ${pts.length} vertices, ${fmt(total, 1)} m, sampled every ${fmt(st, 2)} m ($n samples; $method model).',
    'Start [${fmt(pts.first.x, 2)}, ${fmt(pts.first.y, 2)}] z ${fmt(z.first, 2)} m → end [${fmt(pts.last.x, 2)}, ${fmt(pts.last.y, 2)}] z ${fmt(z.last, 2)} m: net ${_signed(z.last - z.first)} m (${_signed(total > 0 ? 100 * (z.last - z.first) / total : 0, 2)} % mean).',
    'Total rise ${fmt(rise, 2)} m, total fall ${fmt(fall, 2)} m; ${up > 0 ? 'steepest uphill ${fmt(up, 1)} % from d ${fmt(upAt, 1)} m' : 'no uphill stretch'}, ${down < 0 ? 'steepest downhill ${fmt(down, 1)} % from d ${fmt(downAt, 1)} m' : 'no downhill stretch'}.',
    'Highest z ${fmt(z[hiI], 2)} m at ${at(hiI)}; lowest z ${fmt(z[loI], 2)} m at ${at(loI)}.',
  ];
  // local high points (air gathers there in a pipe) and low points (it drains there)
  final highs = <int>[], lows = <int>[];
  final w = math.max(1, n ~/ 40);
  const prominence = 0.3;
  // lowest and highest before and after each sample
  final minL = Float64List(n), maxL = Float64List(n), minR = Float64List(n), maxR = Float64List(n);
  for (var i = 0; i < n; i++) {
    minL[i] = i == 0 ? z[0] : math.min(minL[i - 1], z[i]);
    maxL[i] = i == 0 ? z[0] : math.max(maxL[i - 1], z[i]);
  }
  for (var i = n - 1; i >= 0; i--) {
    minR[i] = i == n - 1 ? z[i] : math.min(minR[i + 1], z[i]);
    maxR[i] = i == n - 1 ? z[i] : math.max(maxR[i + 1], z[i]);
  }
  for (var i = 1; i < n - 1; i++) {
    final a = math.max(0, i - w), b = math.min(n - 1, i + w);
    var isMax = true, isMin = true;
    for (var k = a; k <= b; k++) {
      if (z[k] > z[i] || (z[k] == z[i] && k < i)) isMax = false;
      if (z[k] < z[i] || (z[k] == z[i] && k < i)) isMin = false;
    }
    if (isMax && z[i] - minL[i - 1] >= prominence && z[i] - minR[i + 1] >= prominence) highs.add(i);
    if (isMin && maxL[i - 1] - z[i] >= prominence && maxR[i + 1] - z[i] >= prominence) lows.add(i);
  }
  if (highs.isNotEmpty) out.add('Local high points (air gathers there in a pipe: an air valve, or another route): ${highs.take(10).map((i) => 'z ${fmt(z[i], 2)} m at ${at(i)}').join('; ')}.');
  if (lows.isNotEmpty) out.add('Local low points (the line drains there): ${lows.take(10).map((i) => 'z ${fmt(z[i], 2)} m at ${at(i)}').join('; ')}.');
  if (pts.length > 2) {
    final segs = <String>[];
    for (var s = 1; s < pts.length && s <= 30; s++) {
      final a = d.indexOf(vertexD[s - 1]), b = d.indexOf(vertexD[s]);
      var r = 0.0, fl = 0.0;
      for (var i = a + 1; i <= b; i++) {
        final dz = z[i] - z[i - 1];
        if (dz > 0) r += dz;
        if (dz < 0) fl -= dz;
      }
      final len = vertexD[s] - vertexD[s - 1];
      segs.add('$s) ${fmt(vertexD[s - 1], 1)}–${fmt(vertexD[s], 1)} m: +${fmt(r, 2)} / −${fmt(fl, 2)} m, mean ${_signed(len > 0 ? 100 * (z[b] - z[a]) / len : 0, 2)} %');
    }
    out.add('Segments: ${segs.join('; ')}${pts.length > 31 ? '; …' : ''}.');
  }
  // where the line leaves the data
  if (!cov.isEmpty) {
    final runs = <String>[];
    int? from;
    for (var i = 0; i <= n; i++) {
      final off = i < n && !cov.reliable(p[i]);
      if (off && from == null) from = i;
      if (!off && from != null) {
        runs.add('${fmt(d[from], 0)}–${fmt(d[i - 1], 0)} m');
        from = null;
      }
    }
    if (runs.isNotEmpty) {
      out.add('Outside the terrain data or farther than ${fmt(cov.farM, 0)} m from any height sample (heights interpolated or extrapolated, less reliable): d ${runs.take(12).join(', ')}.');
    }
  }
  // the table: evenly spaced rows plus the highest and lowest points
  final keep = <int>{0, n - 1, hiI, loI};
  final r = rows.clamp(2, 200);
  for (var k = 0; k < r; k++) {
    keep.add(((n - 1) * k / math.max(1, r - 1)).round());
  }
  final idx = keep.toList()..sort();
  out.add('d m | x | y | z m | slope % to the next row (uphill positive)');
  for (var k = 0; k < idx.length; k++) {
    final i = idx[k];
    final j = k + 1 < idx.length ? idx[k + 1] : -1;
    final s = j < 0 || d[j] - d[i] <= 1e-9 ? '-' : _signed(100 * (z[j] - z[i]) / (d[j] - d[i]), 2);
    out.add('${fmt(d[i], 1)} | ${fmt(p[i].x, 2)} | ${fmt(p[i].y, 2)} | ${fmt(z[i], 2)} | $s');
  }
  return out.join('\n');
}

String _signed(double v, [int decimals = 2]) => '${v > 0 ? '+' : ''}${fmt(v, decimals)}';

// ---------------------------------------------------------------- info

/// What the terrain model of [p] is made of, its extent and density, how
/// much of the drawing lies inside the data and where heights are far from
/// any sample.
String terrainInfoText(Project p, Terrain t) {
  final own = p.entities.whereType<ContourEntity>().where((e) => !e.derived).length;
  final generated = p.entities.whereType<ContourEntity>().where((e) => e.derived).length;
  final spots = p.entities.whereType<SpotHeightEntity>().toList();
  final dem = spots.where((e) => e.layer == Layers.dem || e.isDem).length;
  final breaklines = p.entities.whereType<BreaklineEntity>().length;
  if (t.isEmpty) {
    return 'No terrain data: the project has no contour lines, spot heights or breaklines${generated > 0 ? ' (only $generated generated contours, which are drawn from the data and not data themselves)' : ''}, so every elevation is taken as 0 m. Get data with download_terrain (online elevations; needs a georeference: set_site), import_attachment of a survey (DXF/DWG contours, LandXML, GeoTIFF, CSV points), or ask the user for spot heights.';
  }
  final cov = TerrainCoverage.of(t);
  final (zLo, zHi) = t.elevationRange;
  final method = p.params.terrainMethod == TerrainMethod.tin
      ? 'TIN (Delaunay triangles, linear inside each; inverse distance outside the hull of the data)'
      : 'inverse distance weighting over the 8 nearest samples';
  final out = <String>[
    'Terrain model: $method, from ${cov.samples.length} height samples: $own contour lines (sampled every ${fmt(p.params.terrainDensify, 1)} m), ${spots.length - dem} own spot heights, $dem downloaded elevation points (DEM layer), $breaklines breaklines${generated > 0 ? '; $generated generated contours are drawn from the model, not data' : ''}.',
    'Data extent [minX, minY, maxX, maxY] = [${fmt(cov.extent.minX, 1)}, ${fmt(cov.extent.minY, 1)}, ${fmt(cov.extent.maxX, 1)}, ${fmt(cov.extent.maxY, 1)}] m; hull ${fmt(cov.hullArea / 1e4, 2)} ha; elevations ${fmt(zLo, 2)} … ${fmt(zHi, 2)} m.',
    if (cov.hullArea > 0)
      'Density: ${fmt(cov.samples.length / (cov.hullArea / 1e4), 1)} samples per hectare, about ${fmt(cov.spacing, 1)} m apart on average; a height farther than ${fmt(cov.farM, 0)} m from any sample counts as far from data.'
    else
      'The samples do not span an area (fewer than three, or in a line): heights away from them are extrapolated.',
  ];
  // the drawing against the data
  var drawing = Bounds.empty;
  for (final e in p.entities) {
    if (e is ContourEntity || e is SpotHeightEntity || e is BreaklineEntity || e is ImageEntity) continue;
    drawing = drawing.union(e.bounds);
  }
  if (drawing.isEmpty) {
    out.add('Nothing is drawn besides the terrain yet.');
  } else {
    final cell = math.max(1.0, math.max(drawing.width, drawing.height) / 48);
    final nx = math.max(1, (drawing.width / cell).ceil()), ny = math.max(1, (drawing.height / cell).ceil());
    final flag = Uint8List(nx * ny);
    var inside = 0, far = 0;
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final q = Pt(drawing.minX + (i + 0.5) * cell, drawing.minY + (j + 0.5) * cell);
        final inHull = cov.inside(q);
        if (inHull) inside++;
        if (!inHull || cov.near.distance(q) > cov.farM) {
          flag[j * nx + i] = 1;
          far++;
        }
      }
    }
    final total = nx * ny;
    out.add(
      'Drawing extent [${fmt(drawing.minX, 1)}, ${fmt(drawing.minY, 1)}, ${fmt(drawing.maxX, 1)}, ${fmt(drawing.maxY, 1)}] m: ${fmt(100 * inside / total, 0)} % inside the data; ${fmt(100 * far / total, 0)} % outside it or far from any sample.',
    );
    if (far > 0) {
      // the zones, largest first
      final seen = Uint8List(nx * ny);
      final zones = <(int, Bounds, double)>[];
      for (var s = 0; s < total; s++) {
        if (flag[s] == 0 || seen[s] == 1) continue;
        final stack = [s];
        seen[s] = 1;
        var count = 0;
        var box = Bounds.empty;
        var worst = 0.0;
        while (stack.isNotEmpty) {
          final k = stack.removeLast();
          count++;
          final i = k % nx, j = k ~/ nx;
          final q = Pt(drawing.minX + (i + 0.5) * cell, drawing.minY + (j + 0.5) * cell);
          box = box.union(Bounds(q.x - cell / 2, q.y - cell / 2, q.x + cell / 2, q.y + cell / 2));
          worst = math.max(worst, cov.near.distance(q, rings: 4));
          for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final a = i + di, b = j + dj;
            if (a < 0 || b < 0 || a >= nx || b >= ny) continue;
            final kk = b * nx + a;
            if (flag[kk] == 1 && seen[kk] == 0) {
              seen[kk] = 1;
              stack.add(kk);
            }
          }
        }
        zones.add((count, box, worst));
      }
      zones.sort((a, b) => b.$1.compareTo(a.$1));
      out.add(
        'Zones far from data (heights there are interpolated or extrapolated): ${[for (final (k, box, worst) in zones.take(5)) '[${fmt(box.minX, 0)}, ${fmt(box.minY, 0)}, ${fmt(box.maxX, 0)}, ${fmt(box.maxY, 0)}] (${fmt(100 * k / total, 0)} % of the extent, nearest sample ${worst.isFinite ? 'up to ${fmt(worst, 0)} m' : 'over ${fmt(4 * cov.farM, 0)} m'} away)'].join('; ')}${zones.length > 5 ? '; …' : ''}.',
      );
    }
    // hydraulic items away from the data
    final kinds = <String, int>{};
    var pipeOut = 0.0;
    for (final e in p.entities) {
      if (e is PointEntity && (e is OutletEntity || e is ControlValveEntity || e is WaterSupplyEntity || e is PumpEntity || e is MiscHydraulicEntity || e is JunctionEntity)) {
        if (!cov.reliable(e.position)) kinds[e.type.name] = (kinds[e.type.name] ?? 0) + 1;
      } else if (e is PipeEntity || e is SpraylineEntity || e is TapeEntity) {
        final pts = e.linearPoints!;
        final len = polylineLength(pts);
        final steps = math.max(1, (len / 5).ceil());
        for (var k = 0; k < steps; k++) {
          if (!cov.reliable(pointAlongPolyline(pts, len * (k + 0.5) / steps))) pipeOut += len / steps;
        }
      }
    }
    if (kinds.isNotEmpty || pipeOut > 0) {
      out.add(
        'Hydraulic items where heights are far from data: ${[for (final e in kinds.entries) '${e.value} ${e.key}', if (pipeOut > 0) '${fmt(pipeOut, 0)} m of pipes and laterals'].join(', ')}: check their elevations (get_elevations) or extend the terrain (download_terrain).',
      );
    } else {
      out.add('Every hydraulic item lies where the heights are well supported by data.');
    }
  }
  return out.join('\n');
}
