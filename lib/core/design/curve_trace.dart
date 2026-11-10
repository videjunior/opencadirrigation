/// The automatic trace of a curve on a picture of a chart (1.7.0, DGZ): the
/// user clicks the curve, its colour is followed pixel by pixel to both
/// sides between two limits of the horizontal axis, and evenly spaced
/// points are read off the track for the user to correct.
///
/// Method. The colour is taken where the user clicked (the pixel of a 5×5
/// window that differs most from the local background, the per-channel
/// median of a 21×21 window), so a click beside a thin anti-aliased line
/// still picks the line. A pixel belongs to the curve when its colour lies
/// near the segment between the background and the curve's colour in RGB
/// space: its share α of the way from the background (the projection on the
/// segment) is at least [TraceSettings.minShare] and its distance from the
/// segment at most [TraceSettings.tolerance]. That takes the blended edge
/// pixels of an anti-aliased line, and leaves out grid lines (a light grey
/// has a small share of a dark blue) and curves or legends of other colours
/// (far from the segment). The curve is then followed along the horizontal
/// axis of the picture (rotated or sheared like the calibration says) in
/// steps of one pixel; at each step the matching pixels across the curve, in
/// a window around the position the last steps predict, form runs, and the
/// run nearest the prediction gives the position (its α-weighted centre).
/// Short gaps (a grid line drawn over the curve, a label) are bridged, a
/// longer one ends the track, so a legend or another curve of the same
/// colour elsewhere on the page is not taken. It assumes a curve that is a
/// function of the horizontal value, as every catalogue curve is.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../io/image_decode.dart';
import '../model/geometry.dart';
import 'curve_digitiser.dart';

/// The pixels of a picture: [width] × [height], 4 bytes (RGBA) a pixel,
/// rows from the top. Transparent parts are laid on white, as a page.
class ChartRaster {
  ChartRaster(this.width, this.height, this.rgba) : assert(rgba.length == width * height * 4);
  final int width;
  final int height;
  final Uint8List rgba;

  /// The pixels of [image], at most [maxSide] pixels on its longer side
  /// (reduced by averaging), oriented as its EXIF tag says.
  factory ChartRaster.fromImage(img.Image image, {int maxSide = defaultMaxSide}) {
    var im = img.bakeOrientation(image);
    final side = math.max(im.width, im.height);
    if (side > maxSide) {
      final k = maxSide / side;
      im = img.copyResize(im, width: math.max(1, (im.width * k).round()), height: math.max(1, (im.height * k).round()), interpolation: img.Interpolation.average);
    }
    if (im.format != img.Format.uint8 || im.numChannels != 4 || im.hasPalette) im = im.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
    final px = Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgba));
    for (var i = 0; i < px.length; i += 4) {
      final a = px[i + 3];
      if (a == 255) continue;
      for (var k = 0; k < 3; k++) {
        px[i + k] = ((px[i + k] * a + 255 * (255 - a)) / 255).round();
      }
      px[i + 3] = 255;
    }
    return ChartRaster(im.width, im.height, px);
  }

  /// Largest side kept: a catalogue page or a phone photo stays readable
  /// and its pixels fit the browser's memory (3200² × 4 bytes = 41 MB).
  static const defaultMaxSide = 3200;

  /// Decodes a PNG, JPEG, WebP (or GIF, BMP, TIFF) picture; throws
  /// `FormatException('image_unreadable')` (or `image_too_large`) when it
  /// cannot.
  static ChartRaster decode(Uint8List bytes, {int maxSide = defaultMaxSide}) {
    final im = decodeImageSafe(bytes);
    if (im == null || im.width < 2 || im.height < 2) throw const FormatException('image_unreadable');
    return ChartRaster.fromImage(im, maxSide: maxSide);
  }

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// The colour of pixel (x, y): (r, g, b).
  (int, int, int) rgb(int x, int y) {
    final i = (y * width + x) * 4;
    return (rgba[i], rgba[i + 1], rgba[i + 2]);
  }

  /// The colour at the picture point [p] (the pixel holding it), or null
  /// outside.
  (int, int, int)? colourAt(Pt p) {
    final x = p.x.floor(), y = p.y.floor();
    return contains(x, y) ? rgb(x, y) : null;
  }
}

/// How closely the trace follows a colour.
class TraceSettings {
  const TraceSettings({this.tolerance = 60, this.minShare = 0.35, this.maxGapPx = 12, this.stepPx = 1});

  /// Largest distance (RGB units, 0–441) of a pixel's colour from the
  /// segment between the background and the curve's colour.
  final double tolerance;

  /// Smallest share of the way from the background to the curve's colour:
  /// the faint edge of an anti-aliased line, not a light grid line.
  final double minShare;

  /// Longest stretch (pixels along the horizontal axis) without the colour
  /// that is bridged.
  final double maxGapPx;

  /// Step along the horizontal axis (pixels).
  final double stepPx;
}

/// Why a trace found nothing.
enum TraceError {
  /// The colour clicked is the background's.
  background,

  /// No pixel of the colour at the click.
  notFound,
}

/// The colours a trace follows: the curve's and the background's around it.
typedef TraceColours = ({(int, int, int) curve, (int, int, int) background});

/// The colour of the curve clicked at [seed] and of the background around
/// it (see the library comment), or null outside the picture.
TraceColours? pickCurveColour(ChartRaster r, Pt seed) {
  final cx = seed.x.floor(), cy = seed.y.floor();
  if (!r.contains(cx, cy)) return null;
  final rs = <int>[], gs = <int>[], bs = <int>[];
  for (var y = cy - 10; y <= cy + 10; y++) {
    for (var x = cx - 10; x <= cx + 10; x++) {
      if (!r.contains(x, y)) continue;
      final (pr, pg, pb) = r.rgb(x, y);
      rs.add(pr);
      gs.add(pg);
      bs.add(pb);
    }
  }
  int median(List<int> v) => (v..sort())[v.length ~/ 2];
  final bg = (median(rs), median(gs), median(bs));
  var best = r.rgb(cx, cy);
  var far = _dist2(best, bg);
  for (var y = cy - 2; y <= cy + 2; y++) {
    for (var x = cx - 2; x <= cx + 2; x++) {
      if (!r.contains(x, y)) continue;
      final c = r.rgb(x, y);
      final d = _dist2(c, bg);
      if (d > far) {
        far = d;
        best = c;
      }
    }
  }
  return (curve: best, background: bg);
}

int _dist2((int, int, int) a, (int, int, int) b) {
  final dr = a.$1 - b.$1, dg = a.$2 - b.$2, db = a.$3 - b.$3;
  return dr * dr + dg * dg + db * db;
}

/// Smallest distance (RGB units) between the curve's colour and the
/// background for a trace: closer, the click was on the background.
const double minCurveContrast = 40;

/// The curve followed from a click: positions (s, t) along the horizontal
/// direction of the picture and across it, from [origin], sorted by s.
class CurveTrack {
  CurveTrack._(this.origin, this.along, this.across, this.s, this.t, this.colours, this.maxGapPx);
  final Pt origin;

  /// Unit directions of the picture along which the horizontal value grows
  /// (s) and the vertical one (t).
  final Pt along, across;
  final List<double> s, t;
  final TraceColours colours;
  final double maxGapPx;

  int get length => s.length;

  /// The picture point of track position (s, t).
  Pt pointAt(double s, double t) => origin + along * s + across * t;

  /// Every point of the track, in picture pixels.
  List<Pt> get points => [for (var i = 0; i < s.length; i++) pointAt(s[i], t[i])];

  /// The track's position across at [at] along it, interpolated between the
  /// steps that hold it; null outside the track or across a gap longer than
  /// [maxGapPx].
  double? acrossAt(double at) {
    if (s.isEmpty || at < s.first - 1e-9 || at > s.last + 1e-9) return null;
    var lo = 0, hi = s.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (s[mid] <= at) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    if (hi == lo) return t[lo];
    final span = s[hi] - s[lo];
    if (span > maxGapPx + 1e-9) return null;
    return span <= 0 ? t[lo] : t[lo] + (t[hi] - t[lo]) * (at - s[lo]) / span;
  }
}

/// The result of [traceCurve]: the track, or the error.
typedef TraceOutcome = ({CurveTrack? track, TraceError? error});

/// Follows the curve clicked at [seed] on [r] (see the library comment)
/// along the horizontal axis of [m] between the horizontal values [from]
/// and [to] (either order; the axis values, not their logarithms).
TraceOutcome traceCurve(ChartRaster r, ChartMapping m, Pt seed, {required double from, required double to, TraceSettings settings = const TraceSettings()}) {
  final colours = pickCurveColour(r, seed);
  if (colours == null) return (track: null, error: TraceError.notFound);
  final (cr, cg, cb) = colours.curve;
  final (br, bg, bb) = colours.background;
  final er = (cr - br).toDouble(), eg = (cg - bg).toDouble(), eb = (cb - bb).toDouble();
  final ee = er * er + eg * eg + eb * eb;
  if (math.sqrt(ee) < minCurveContrast) return (track: null, error: TraceError.background);
  // a colour farther from the segment than half its length is no blend of
  // its two ends, whatever the tolerance (a light grey curve)
  final tol = math.min(settings.tolerance, 0.5 * math.sqrt(ee));
  final tol2 = tol * tol;

  /// The share α of the pixel at [p] (0 when it is not of the curve).
  double share(Pt p) {
    final x = p.x.floor(), y = p.y.floor();
    if (!r.contains(x, y)) return 0;
    final i = (y * r.width + x) * 4;
    final dr = (r.rgba[i] - br).toDouble(), dg = (r.rgba[i + 1] - bg).toDouble(), db = (r.rgba[i + 2] - bb).toDouble();
    final a = (dr * er + dg * eg + db * eb) / ee;
    if (a < settings.minShare) return 0;
    final pr = dr - a * er, pg = dg - a * eg, pb = db - a * eb;
    if (pr * pr + pg * pg + pb * pb > tol2) return 0;
    return math.min(a, 1);
  }

  final along = m.xDirection, across = m.yDirection;
  final rate = m.xRatePerPixel;
  if (!(rate.abs() > 0) || along == Pt.zero || across == Pt.zero) return (track: null, error: TraceError.notFound);
  final (u0, _) = m.coordinatesAt(seed);
  double sOf(double value) => (ChartMapping.axisCoordinate(value, m.xScale) - u0) / rate;
  if (m.xScale == AxisScale.log && (!(from > 0) || !(to > 0))) return (track: null, error: TraceError.notFound);
  final s1 = math.min(sOf(from), sOf(to)), s2 = math.max(sOf(from), sOf(to));

  /// The α-weighted centre (across) of the run of curve pixels nearest
  /// [predicted] within [window], at [s] along; null when there is none.
  double? runAt(double s, double predicted, double window) {
    const dt = 0.5;
    double? best;
    var bestGap = double.infinity;
    var w = 0.0, wt = 0.0;
    void close() {
      if (w <= 0) return;
      final centre = wt / w;
      final gap = (centre - predicted).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = centre;
      }
      w = 0;
      wt = 0;
    }

    for (var t = predicted - window; t <= predicted + window + 1e-9; t += dt) {
      final a = share(seed + along * s + across * t);
      if (a > 0) {
        w += a;
        wt += a * t;
      } else {
        close();
      }
    }
    close();
    return best;
  }

  bool inside(double s, double t) {
    final p = seed + along * s + across * t;
    return p.x >= 0 && p.y >= 0 && p.x < r.width && p.y < r.height;
  }

  // the curve at the click, or a step or three beside it (a grid line drawn
  // over the curve where it was clicked)
  var s0 = 0.0;
  double? t0;
  for (final ds in const [0, 1, -1, 2, -2, 3, -3]) {
    t0 = runAt(ds * settings.stepPx, 0, 6);
    if (t0 != null) {
      s0 = ds * settings.stepPx;
      break;
    }
  }
  if (t0 == null) return (track: null, error: TraceError.notFound);
  final tStart = t0;
  final ss = <double>[s0], ts = <double>[tStart];

  /// Follows the curve from the click in direction [dir] (±1).
  void follow(int dir) {
    var sLast = s0, tLast = tStart, slope = 0.0;
    var s = s0;
    var found = 0;
    while (true) {
      s += dir * settings.stepPx;
      if ((dir > 0 && s > s2 + settings.stepPx) || (dir < 0 && s < s1 - settings.stepPx)) break;
      final ds = s - sLast;
      final predicted = tLast + slope * ds;
      if (!inside(s, predicted) && !inside(s, tLast)) break;
      final window = math.max(3.0, 2 * slope.abs() * ds.abs() + 2);
      final t = runAt(s, predicted, window);
      if (t == null) {
        if ((s - sLast).abs() > settings.maxGapPx) break;
        continue;
      }
      final next = (t - tLast) / ds;
      // the first steps set the slope, the later ones smooth it
      slope = found++ < 2 ? next : 0.5 * slope + 0.5 * next;
      sLast = s;
      tLast = t;
      ss.add(s);
      ts.add(t);
    }
  }

  follow(1);
  follow(-1);
  final order = List<int>.generate(ss.length, (i) => i)..sort((a, b) => ss[a].compareTo(ss[b]));
  // a step beyond each limit stays, so the points at the limits interpolate
  final margin = settings.stepPx + 1e-9;
  final keep = [
    for (final i in order)
      if (ss[i] >= s1 - margin && ss[i] <= s2 + margin) i,
  ];
  if (keep.isEmpty) return (track: null, error: TraceError.notFound);
  return (track: CurveTrack._(seed, along, across, [for (final i in keep) ss[i]], [for (final i in keep) ts[i]], colours, settings.maxGapPx), error: null);
}

/// [count] points of [track], evenly spaced along the horizontal axis of
/// [m] from the value [from] to [to] (evenly in the logarithm on a
/// logarithmic axis), in picture pixels; the places the track does not
/// cover are left out.
List<Pt> sampleTrack(CurveTrack track, ChartMapping m, {required double from, required double to, required int count}) {
  if (count < 1) return const [];
  final ua = ChartMapping.axisCoordinate(from, m.xScale), ub = ChartMapping.axisCoordinate(to, m.xScale);
  final (u0, _) = m.coordinatesAt(track.origin);
  final rate = m.xRatePerPixel;
  final out = <Pt>[];
  for (var k = 0; k < count; k++) {
    final u = count == 1 ? (ua + ub) / 2 : ua + (ub - ua) * k / (count - 1);
    final s = (u - u0) / rate;
    final t = track.acrossAt(s);
    if (t != null) out.add(track.pointAt(s, t));
  }
  return out;
}
