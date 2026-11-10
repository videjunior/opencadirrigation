import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/design/curve_digitiser.dart';
import 'package:opencadirrigation/core/design/curve_trace.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The automatic trace (1.7.0 DGZ) on synthetic charts: a pump curve
/// H = 50 − 0.003·Q² drawn over a grid, anti-aliased or not, thin or
/// thick, crossed by a red legend line and a red curve, with the grid drawn
/// over it, and on the same picture rotated by 8°; the points it reads are
/// within a fraction of a metre of the curve; a click on the background is
/// refused.
void main() {
  // the chart: Q 0–100 m³/h along px 60–610, H 0–50 m up py 400–50
  double head(double q) => 50 - 0.003 * q * q;
  Pt chart(double q, double h) => Pt(60 + 5.5 * q, 400 - 7 * h);

  img.Image picture({bool antialias = true, num thickness = 2, bool gridOver = false, bool legend = true}) {
    final im = img.Image(width: 660, height: 440, numChannels: 3)..clear(img.ColorRgb8(255, 255, 255));
    void grid() {
      for (var q = 0; q <= 100; q += 10) {
        final p = chart(q.toDouble(), 0);
        img.drawLine(im, x1: p.x.round(), y1: 50, x2: p.x.round(), y2: 400, color: img.ColorRgb8(205, 205, 205));
      }
      for (var h = 0; h <= 50; h += 5) {
        final p = chart(0, h.toDouble());
        img.drawLine(im, x1: 60, y1: p.y.round(), x2: 610, y2: p.y.round(), color: img.ColorRgb8(205, 205, 205));
      }
    }

    if (!gridOver) grid();
    // the axes, black
    img.drawLine(im, x1: 60, y1: 400, x2: 615, y2: 400, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    img.drawLine(im, x1: 60, y1: 45, x2: 60, y2: 400, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    // the curve, blue
    Pt? last;
    for (var q = 0.0; q <= 100.0001; q += 1) {
      final p = chart(q, head(q));
      if (last != null) {
        img.drawLine(im, x1: last.x.round(), y1: last.y.round(), x2: p.x.round(), y2: p.y.round(), color: img.ColorRgb8(20, 70, 200), antialias: antialias, thickness: thickness);
      }
      last = p;
    }
    if (legend) {
      // a red curve crossing it and a legend box with a red sample line
      img.drawLine(im, x1: 60, y1: 380, x2: 610, y2: 120, color: img.ColorRgb8(220, 30, 30), antialias: true, thickness: 2);
      img.fillRect(im, x1: 470, y1: 60, x2: 600, y2: 100, color: img.ColorRgb8(245, 245, 245));
      img.drawLine(im, x1: 480, y1: 80, x2: 520, y2: 80, color: img.ColorRgb8(220, 30, 30), thickness: 3);
    }
    if (gridOver) grid();
    return im;
  }

  ChartMapping mapping({Pt Function(Pt)? move}) {
    final f = move ?? (Pt p) => p;
    final (m, err) = ChartMapping.solve(AxisCalibration(p1: f(chart(0, 0)), v1: 0, p2: f(chart(100, 0)), v2: 100), AxisCalibration(p1: f(chart(0, 0)), v1: 0, p2: f(chart(0, 50)), v2: 50));
    expect(err, isNull);
    return m!;
  }

  /// Traces from a click 2 px off the curve at Q = 40 and reads [n] points
  /// from 5 to 95 m³/h; returns the largest error in metres.
  double traceError(ChartRaster r, ChartMapping m, {Pt Function(Pt)? move, int n = 10}) {
    final f = move ?? (Pt p) => p;
    final seed = f(chart(40, head(40)) + const Pt(0, 2));
    final out = traceCurve(r, m, seed, from: 5, to: 95);
    expect(out.error, isNull);
    final pts = sampleTrack(out.track!, m, from: 5, to: 95, count: n);
    expect(pts, hasLength(n), reason: 'every point found');
    var worst = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final (q, h) = m.valueAt(pts[i]);
      expect(q, closeTo(5 + 90 * i / (n - 1), 1e-6), reason: 'evenly spaced along the axis');
      worst = math.max(worst, (h - head(q)).abs());
    }
    return worst;
  }

  test('an anti-aliased curve crossing the grid, a red curve and a red legend: within 0.15 m', () {
    final r = ChartRaster.fromImage(picture());
    final m = mapping();
    expect(traceError(r, m, n: 19), lessThan(0.15)); // 1 px = 1/7 m
    final colours = pickCurveColour(r, chart(40, head(40)) + const Pt(0, 2))!;
    expect(colours.background, (255, 255, 255));
    final (cr, cg, cb) = colours.curve;
    expect(cb, greaterThan(cr + 80), reason: 'the blue of the curve, not the white beside it: ($cr, $cg, $cb)');
  });

  test('thin lines, aliased or not, and a grid drawn over the curve', () {
    final m = mapping();
    expect(traceError(ChartRaster.fromImage(picture(thickness: 1)), m), lessThan(0.2));
    expect(traceError(ChartRaster.fromImage(picture(antialias: false, thickness: 1)), m), lessThan(0.2));
    expect(traceError(ChartRaster.fromImage(picture(gridOver: true)), m), lessThan(0.2));
    expect(traceError(ChartRaster.fromImage(picture(thickness: 5)), m), lessThan(0.2));
  });

  test('the same picture rotated by 8° reads the same once its axes are clicked', () {
    final src = picture();
    final rot = img.copyRotate(src, angle: 8, interpolation: img.Interpolation.linear);
    // copyRotate turns clockwise about the centre into a larger canvas
    const th = 8 * math.pi / 180;
    final cx = src.width / 2, cy = src.height / 2, nx = rot.width / 2, ny = rot.height / 2;
    Pt move(Pt p) {
      final dx = p.x - cx, dy = p.y - cy;
      return Pt(nx + dx * math.cos(th) - dy * math.sin(th), ny + dx * math.sin(th) + dy * math.cos(th));
    }

    final r = ChartRaster.fromImage(rot);
    final m = mapping(move: move);
    expect(traceError(r, m, move: move), lessThan(0.3));
  });

  test('the limits of the trace and the points between them', () {
    final r = ChartRaster.fromImage(picture(legend: false));
    final m = mapping();
    final out = traceCurve(r, m, chart(50, head(50)), from: 20, to: 70);
    final track = out.track!;
    final (q0, _) = m.valueAt(track.points.first);
    final (q1, _) = m.valueAt(track.points.last);
    expect(q0, closeTo(20, 0.4));
    expect(q1, closeTo(70, 0.4));
    expect(sampleTrack(track, m, from: 20, to: 70, count: 6), hasLength(6));
    // points asked beyond the track are left out: 20, 30 … 70 stay
    expect(sampleTrack(track, m, from: 0, to: 100, count: 11), hasLength(6));
    expect(sampleTrack(track, m, from: 20, to: 70, count: 0), isEmpty);
  });

  test('a click on the background or off the picture is refused', () {
    final r = ChartRaster.fromImage(picture(legend: false));
    final m = mapping();
    // between the curve and the grid lines: white all round
    expect(traceCurve(r, m, chart(75, 42), from: 0, to: 100).error, TraceError.background);
    expect(traceCurve(r, m, const Pt(-5, 10), from: 0, to: 100).error, TraceError.notFound);
    expect(pickCurveColour(r, const Pt(9999, 0)), isNull);
  });

  test('a picture is decoded, reduced to its largest side and laid on white', () {
    final im = img.Image(width: 400, height: 100, numChannels: 4)..clear(img.ColorRgba8(0, 0, 255, 0));
    img.fillRect(im, x1: 0, y1: 0, x2: 9, y2: 9, color: img.ColorRgba8(0, 0, 0, 255));
    final png = Uint8List.fromList(img.encodePng(im));
    final r = ChartRaster.decode(png, maxSide: 200);
    expect((r.width, r.height), (200, 50));
    expect(r.rgb(100, 40), (255, 255, 255), reason: 'transparent is the white of a page');
    expect(r.rgb(1, 1), (0, 0, 0));
    expect(() => ChartRaster.decode(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
    final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 30, height: 20)..clear(img.ColorRgb8(10, 200, 10))));
    final rj = ChartRaster.decode(jpg);
    expect((rj.width, rj.height), (30, 20));
    expect(rj.rgb(15, 10).$2, greaterThan(180));
  });
}
