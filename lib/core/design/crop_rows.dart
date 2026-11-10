/// 1.7.0 ROW: the planting rows of a row crop (orchard, coffee, vineyard,
/// citrus, olive, sugar cane, vegetables on beds…) read from an aerial image
/// of a field: the direction the rows run, their spacing, how many rows
/// cross the field, how sure the reading is and, where the image shows them,
/// the spacing of the plants along the rows and the share of the ground the
/// canopy covers. Drip laterals are laid along the rows that already exist
/// in the field; today their direction and spacing are measured by hand on
/// the satellite image. Plain image processing on this device, linear in the
/// pixels for every direction tried: no service, no trained model.
///
/// The pixels come as straight RGBA, north up, square pixels over a world
/// rectangle of the project (the satellite base map or a placed aerial photo
/// rendered for the frame [cropRowFrame] chooses), so a distance in pixels
/// times the pixel size is metres of the project plane and an angle in the
/// image is an angle of the drawing.
///
/// The method:
///
/// 1. Mask: the pixels whose centre lies inside the outline and outside its
///    holes (even–odd scanline fill) and that carry data (alpha ≥ 128).
/// 2. Signal: the colour high-passed by subtracting the mean over a box
///    1.25 × the largest spacing searched (masked: only pixels of the field
///    count), which removes the shading and the patches of the field and
///    keeps the stripes of the rows, and divided by its RMS over the same
///    box (floored at a quarter of the field's), so that a dark orchard and
///    a bright bare patch or road in one outline weigh alike; projected on its first principal
///    component (Pearson, 1901), the colour axis along which the image varies
///    most once the field-scale changes are gone — in a row crop the
///    contrast of canopy against inter-row, whether that is green against
///    red soil (excess green) or dark canopy against a lighter cover crop
///    (brightness). Its sign is chosen so that canopy is positive: the
///    projection correlates positively with excess green ExG = (2G − R −
///    B)/(R + G + B + 30) (Woebbecke et al., 1995, damped for dark pixels as
///    in vegetation.dart) less half the standardised brightness (canopy is
///    greener and darker than what lies between the rows). Values beyond
///    four robust standard deviations (1.4826 × the median absolute
///    deviation) are clipped, so a road or a roof inside the field does not
///    rule the result.
/// 3. Direction, coarse: the field is cut into square blocks of about 3.5 ×
///    the largest spacing searched; for every direction θ (steps of at most
///    1°, finer when the smallest spacing is few pixels against the block)
///    the pixels of each block are binned by their distance across θ (bins
///    of at most one pixel, a discrete Radon projection; Radon, 1917), and
///    the share of the signal's variance the bins explain, R²(θ) = between-
///    bin sum of squares / total sum of squares, is averaged over the
///    blocks (one vote each). The spacings searched start at three pixels
///    of the imagery: a finer period is the grain of the image itself. Straight stripes along θ make the bins differ and R² large;
///    any other direction averages them out. Blocks keep the angular peak
///    about (spacing ÷ block) radians wide, so a coarse step cannot miss it,
///    and they follow rows that bend slightly. θ of the largest pooled R²,
///    refined by a parabola through its neighbours.
/// 4. Spacing, coarse: the autocorrelation of the block profiles at that
///    direction, averaged over the blocks; the first peak that reaches half
///    of the highest one between the smallest and the largest spacing
///    searched (the first, not the highest: the profile of narrow rows has
///    peaks at every multiple of the spacing; a lag below the spacing at
///    which the stripes line up again does not exist). A peak whose half or
///    third lag correlates at least half as well is a multiple of rows
///    closer than the range: no rows are read then.
/// 5. Direction, fine: R² of the whole field (one profile across it) on a
///    grid around the coarse direction, the step a quarter of the angular
///    width of the peak (spacing ÷ length of the rows), refined by a
///    parabola. Long straight rows give a sharp peak: about 0.1° over a field
///    of a hundred spacings in length.
/// 6. Spacing, fine: the autocorrelation of the field's profile gives the
///    spacing near the coarse one; the power of the profile (Hann-windowed
///    discrete Fourier transform) is then searched within ±6 % of it and its
///    peak refined by a parabola through the logarithm of the power (sub-bin
///    interpolation: Quinn, 1994, for the reasoning; Gaussian peak fit). The
///    phase of that harmonic places the rows (its maxima). When the
///    whole-field profile repeats far less than the block profiles (its
///    autocorrelation at the spacing below half theirs) the rows bend or
///    change direction across the field: the coarse values stand and the
///    result says so.
///    Which of the two bands of a period is the crop: the greener and
///    darker one, as the sign of the signal says — save when both bands are
///    vegetation and the other one is clearly the wider (a closed canopy
///    whose narrow alleys lie in its shade, darker and greener than the
///    sunlit crowns): then the wider band ([_cropBand]). The user can move
///    the rows half a spacing where that is wrong ([CropRowOptions.otherBand]).
/// 7. Rows: lines along the direction at the spacing and phase found, over
///    the whole outline (also beyond the window analysed in a large field),
///    clipped to it and to its holes; a line counts as a row when at least
///    max(1 m, half a spacing) of it lies in the field.
/// 8. Plants along the rows: the signal sampled along the centre of every
///    row (three samples across, ±0.12 spacing), the autocorrelation of
///    those profiles averaged over at most 150 rows (phase-independent: the
///    plants of neighbouring rows need not line up), and its first peak
///    between max(4 pixels of the imagery, 0.25 m) and 1.2 × the row
///    spacing that reaches [plantPeriodicityMin]. Hedgerows (coffee, vines, a closed row of
///    citrus) have no such peak: the plant spacing is then left unknown.
/// 9. Ground cover: the share of the pixels of the field above the Otsu
///    (1979) threshold of the signal smoothed over 3 × 3 pixels, given only
///    when its histogram has two populations by the bimodality coefficient
///    BC = (skewness² + 1) / (excess kurtosis + 3) > 5/9 (SAS Institute,
///    1990; Pfister et al., 2013; 5/9 is the value of a uniform
///    distribution) — canopy share of a vertical image, the usual stand-in
///    for the ground shaded at noon (FAO-56, Allen et al., 1998, § 9 "fc").
///
/// Confidence = angular prominence × periodicity: (1 − median R² over all
/// directions ÷ the largest R²) times the autocorrelation of the profile at
/// the spacing found (a correlation coefficient, 0–1). Both are near 1 for
/// clear rows and near 0 for an image without rows (bare soil, pasture, a
/// closed canopy). The limits [confidenceRows] and [confidenceUncertain]
/// were set on the synthetic fields of test/core/crop_rows_test.dart and the
/// real fields listed in the notes of the round (no published benchmark of
/// this measure exists): they separate fields with rows (confidence 0.6–0.95)
/// from fields without (below 0.1).
///
/// What it assumes: rows straight over the area analysed (contour plantings
/// that bend give a lower confidence and an average direction: draw smaller
/// areas), evenly spaced (single rows; the pairs of twin-row plantings come
/// out as their own spacing or as the pair spacing), visible as a contrast
/// of canopy against the inter-row at the resolution of the imagery (at
/// least about three pixels per spacing), and an image of a single date.
/// Shadows cast by the canopy count as canopy in the ground cover.
///
/// References: Radon, "Über die Bestimmung von Funktionen durch ihre
/// Integralwerte längs gewisser Mannigfaltigkeiten", 1917; Pearson, "On lines
/// and planes of closest fit to systems of points in space", Phil. Mag. 2,
/// 1901; Woebbecke, Meyer, Von Bargen & Mortensen, Trans. ASAE 38(1), 1995;
/// Otsu, IEEE Trans. SMC 9(1), 1979; Quinn, "Estimating frequency by
/// interpolation using Fourier coefficients", IEEE Trans. Signal Process.
/// 42(5), 1994; Pfister, Schwarz, Janczyk, Dale & Freeman, "Good things peak
/// in pairs: a note on the bimodality coefficient", Front. Psychol. 4, 2013;
/// Allen, Pereira, Raes & Smith, FAO Irrigation and Drainage Paper 56, 1998.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart' show LayoutRegion, maximumInscribedCircle, normalizeDeg;
import 'vegetation.dart' show VegetationImage;

/// The layer the rows drawn as guide lines go to, and its colour (amber:
/// it reads on aerial imagery and on both canvas themes).
const cropRowLayer = 'CROP_ROWS';
const cropRowLayerColor = 0xFFFFD740;

/// Pixels of the raster analysed at most, and its longest side.
const cropRowMaxPixels = 2500000;
const cropRowMaxSide = 2600;

/// Confidence from which the rows count as found, and from which they are
/// shown as uncertain (see the library comment for where they come from).
const confidenceRows = 0.35;
const confidenceUncertain = 0.15;

/// Autocorrelation of the profiles along the rows from which a plant
/// spacing is given (orchards of separate crowns reach 0.5–0.9 on the
/// synthetic fields; the grain of real imagery along hedgerows reaches
/// 0.45).
const plantPeriodicityMin = 0.5;

/// Bimodality coefficient above which the canopy and the ground are two
/// populations (that of a uniform distribution).
const bimodalityMin = 5 / 9;

/// How much wider than half the period the lighter of two green bands must
/// be to be taken for a closed canopy (its alleys in shade): the sunlit
/// crowns took 0.62–0.67 of the spacing in the mature orchards of the
/// notes, the bands of coffee, vines, olives and young orchards 0.42–0.58.
const bandShareMargin = 0.1;

/// The spacings searched.
class CropRowOptions {
  const CropRowOptions({this.minSpacingM = 1.5, this.maxSpacingM = 12, this.otherBand = false});

  /// Closest and widest row spacing looked for (m). The smallest one also
  /// sets the pixel size asked of the imagery (six pixels to it).
  final double minSpacingM, maxSpacingM;

  /// Put the rows on the other band than the one [detectCropRows] takes for
  /// the crop (half a spacing away): for the fields where it took the
  /// alleys (see the library comment).
  final bool otherBand;

  /// The range made usable: 0.3–40 m for the closest, the widest at least
  /// 1.5 times it and at most 60 m.
  CropRowOptions get sane {
    final lo = minSpacingM.isFinite ? minSpacingM.clamp(0.3, 40.0).toDouble() : 1.5;
    final hi = maxSpacingM.isFinite ? maxSpacingM.clamp(lo * 1.5, 60.0).toDouble() : math.max(12.0, lo * 1.5);
    return CropRowOptions(minSpacingM: lo, maxSpacingM: hi, otherBand: otherBand);
  }

  String get key => '$minSpacingM|$maxSpacingM|$otherBand';
}

/// The pixels analysed: straight RGBA row by row from the top, north up,
/// square pixels exactly over [world] (left = minX, top = maxY).
class CropRowRaster {
  CropRowRaster(this.rgba, this.width, this.height, this.world, {this.imageryPixelM}) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) throw ArgumentError('raster');
  }
  final Uint8List rgba;
  final int width, height;
  final Bounds world;

  /// Ground size of a pixel of the imagery itself (m), when known: coarser
  /// than [pixelM] when the service had no finer tiles here.
  final double? imageryPixelM;

  /// Metres per pixel of the raster.
  double get pixelM => world.width / width;

  /// The finer of the raster and the imagery: what the image really
  /// resolves.
  double get resolutionM => math.max(pixelM, imageryPixelM ?? 0);

  Pt toWorld(double px, double py) => Pt(world.minX + px * pixelM, world.maxY - py * pixelM);
  (double, double) toPixel(Pt p) => ((p.x - world.minX) / pixelM, (world.maxY - p.y) / pixelM);
}

/// The world rectangle to analyse and its pixel size; [window] when the
/// field is too large for the pixel budget at that size and only a part of
/// it (round its widest inner point) is analysed.
class CropRowFrame {
  const CropRowFrame(this.world, this.pixelM, {this.window = false});
  final Bounds world;
  final double pixelM;
  final bool window;

  int get width => math.max(1, (world.width / pixelM).round());
  int get height => math.max(1, (world.height / pixelM).round());
}

/// The frame for [outline]: six pixels to the closest spacing searched (or
/// the imagery's own pixel when coarser); the whole field when it fits
/// [maxPixels] at that size or at up to a quarter of the closest spacing,
/// else a window of the field as large as the budget allows at that size,
/// centred on its widest inner point.
CropRowFrame cropRowFrame(List<Pt> outline, CropRowOptions options, {List<List<Pt>> holes = const [], double? imageryPixelM, int maxPixels = cropRowMaxPixels, int maxSide = cropRowMaxSide}) {
  final o = options.sane;
  final b = Bounds.ofPoints(outline);
  final want = math.max(math.max(o.minSpacingM / 6, imageryPixelM ?? 0), 0.03);
  final coarsest = math.max(want, o.minSpacingM / 4);
  final margin = 2 * want;
  final whole = b.inflate(margin);
  final bw = math.max(whole.width, want), bh = math.max(whole.height, want);
  final fit = math.max(math.sqrt(bw * bh / maxPixels), math.max(bw, bh) / maxSide);
  if (fit <= want) return CropRowFrame(whole, want);
  if (fit <= coarsest) return CropRowFrame(whole, fit);
  // a window of the budget's size, of the field's proportions where it can
  final budget = maxPixels * want * want, longest = maxSide * want;
  double wh = math.min(bh, math.min(longest, math.sqrt(budget)));
  double ww = math.min(bw, math.min(longest, budget / wh));
  if (ww < bw) {
    wh = math.min(bh, math.min(longest, budget / ww));
  }
  var centre = whole.center;
  if (outline.length >= 3) {
    final (c, _) = maximumInscribedCircle(LayoutRegion(outline, exclusions: holes));
    centre = c;
  }
  var x0 = centre.x - ww / 2, y0 = centre.y - wh / 2;
  x0 = x0.clamp(whole.minX, math.max(whole.minX, whole.maxX - ww)).toDouble();
  y0 = y0.clamp(whole.minY, math.max(whole.minY, whole.maxY - wh)).toDouble();
  return CropRowFrame(Bounds(x0, y0, x0 + ww, y0 + wh), want, window: true);
}

/// How the reading came out.
enum CropRowVerdict {
  /// Rows found (confidence at least [confidenceRows]).
  rows,

  /// Something row-like, not certain: look at the preview.
  uncertain,

  /// No rows in the image.
  none,

  /// Nothing to analyse: no pixels of the field, no contrast, a field too
  /// small for the spacings searched.
  noData,
}

/// A remark on the reading: an i18n code (`row.msg.<code>`) and its
/// arguments (numbers in SI, written by the app).
class CropRowMessage {
  const CropRowMessage(this.code, [this.args = const {}]);
  final String code;
  final Map<String, double> args;
  @override
  String toString() => '$code $args';
}

/// What [detectCropRows] read.
class CropRowResult {
  CropRowResult({
    required this.verdict,
    this.directionDeg = 0,
    this.spacingM = 0,
    this.rows = 0,
    this.confidence = 0,
    this.angularContrast = 0,
    this.periodicity = 0,
    this.explained = 0,
    this.plantSpacingM,
    this.plantPeriodicity = 0,
    this.groundCover,
    this.bimodality = 0,
    this.offsetM = 0,
    this.rowOffsetsM = const [],
    this.rowLines = const [],
    this.pixelM = 0,
    this.resolutionM = 0,
    this.pixels = 0,
    this.curved = false,
    this.bandShare = 0,
    this.swapped = false,
    this.messages = const [],
  });

  final CropRowVerdict verdict;

  /// Direction of the rows in degrees counter-clockwise from the x axis of
  /// the drawing (east on a georeferenced project), in [0, 180): the
  /// convention of "Row direction (°)" of the automatic design dialogs and
  /// of `direction_deg` of the assistant's design tools.
  final double directionDeg;

  /// Distance between neighbouring rows (m).
  final double spacingM;

  /// Rows that cross the field.
  final int rows;

  /// 0–1: [angularContrast] × [periodicity].
  final double confidence;

  /// 1 − median R² over the directions ÷ the largest R² (0–1).
  final double angularContrast;

  /// Autocorrelation of the profile across the rows at the spacing (0–1).
  final double periodicity;

  /// Share of the signal's variance the rows explain (R², 0–1).
  final double explained;

  /// Spacing of the plants along the rows (m); null when not visible.
  final double? plantSpacingM;
  final double plantPeriodicity;

  /// Canopy share of the field (0–1); null when canopy and ground cannot be
  /// told apart in the image.
  final double? groundCover;
  final double bimodality;

  /// Distance of the first row line from the origin across the rows (m):
  /// the rows are the lines p·n = [offsetM] + k·[spacingM], n = (−sin θ,
  /// cos θ).
  final double offsetM;

  /// The offset of every row line counted (m).
  final List<double> rowOffsetsM;

  /// The rows clipped to the field (two points each, world metres).
  final List<List<Pt>> rowLines;

  /// Pixel size of the raster, the resolution of the imagery (m) and the
  /// pixels of the field analysed.
  final double pixelM, resolutionM;
  final int pixels;

  /// The rows bend or change direction across the field.
  final bool curved;

  /// Share of the spacing the crop band takes across the rows (its width ÷
  /// the spacing, at the midpoint of the folded profile).
  final double bandShare;

  /// The rows were put on the band the colour did not favour (the wider of
  /// two green bands: a closed canopy with shaded alleys; or the user asked
  /// for the other band).
  final bool swapped;
  final List<CropRowMessage> messages;

  bool get found => verdict == CropRowVerdict.rows || verdict == CropRowVerdict.uncertain;

  /// Unit vector along the rows.
  Pt get direction => Pt.polar(1, degToRad(directionDeg));
}

/// Thrown by [detectCropRows] when [cancelled] says so.
class CropRowsCancelled implements Exception {
  const CropRowsCancelled();
  @override
  String toString() => 'cancelled';
}

/// Gives the event loop a turn now and then (the screen paints, the Stop
/// button is heard) and stops when asked.
class _Ticker {
  _Ticker(this.cancelled, this.progress);
  final bool Function()? cancelled;
  final void Function(double fraction)? progress;
  final Stopwatch _sw = Stopwatch()..start();

  Future<void> at(double fraction) async {
    if (_sw.elapsedMilliseconds < 14) return;
    progress?.call(fraction.clamp(0.0, 1.0).toDouble());
    await Future<void>.delayed(Duration.zero);
    _sw.reset();
    if (cancelled?.call() ?? false) throw const CropRowsCancelled();
  }
}

/// Reads the rows of the field [outline] (less its [holes]) in [im]; see
/// the library comment. [progress] gets the share done now and then;
/// throws [CropRowsCancelled] once [cancelled] returns true.
Future<CropRowResult> detectCropRows(
  CropRowRaster im,
  List<Pt> outline, {
  List<List<Pt>> holes = const [],
  CropRowOptions options = const CropRowOptions(),
  bool Function()? cancelled,
  void Function(double fraction)? progress,
}) async {
  final o = options.sane;
  final tick = _Ticker(cancelled, progress);
  if (cancelled?.call() ?? false) throw const CropRowsCancelled();
  final w = im.width, h = im.height;
  final mpp = im.pixelM, res = im.resolutionM;
  CropRowResult empty(List<CropRowMessage> m, {int pixels = 0}) => CropRowResult(verdict: CropRowVerdict.noData, pixelM: mpp, resolutionM: res, pixels: pixels, messages: m);
  if (outline.length < 3 || polygonArea(outline).abs() < 1e-6) return empty(const [CropRowMessage('noField')]);

  // ---- 1. mask
  final mask = _mask(im, outline, holes);
  var valid = 0, mx0 = w, my0 = h, mx1 = -1, my1 = -1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      if (mask[row + x] == 0) continue;
      valid++;
      if (x < mx0) mx0 = x;
      if (x > mx1) mx1 = x;
      if (y < my0) my0 = y;
      if (y > my1) my1 = y;
    }
  }
  if (valid < 400) return empty(const [CropRowMessage('noPixels')], pixels: valid);
  final mw = mx1 - mx0 + 1, mh = my1 - my0 + 1;

  // the spacings searched, in pixels; at least three pixels of the imagery
  // (a finer period is the grain of the image: its compression, its
  // resampling); the field must hold a few of the widest
  final pMin = math.max(math.max(o.minSpacingM, 3 * res) / mpp, 3.0);
  var pMax = o.maxSpacingM / mpp;
  pMax = math.min(pMax, 0.4 * math.max(mw, mh));
  if (pMax < pMin * 1.2) {
    return empty([
      CropRowMessage('tooSmall', {'s': o.minSpacingM}),
    ], pixels: valid);
  }
  final coarse = o.minSpacingM < 3 * res;
  final notes = <CropRowMessage>[
    if (coarse) CropRowMessage('coarse', {'r': res, 's': 3 * res}),
  ];
  await tick.at(0.02);

  // ---- 2. signal
  final s = await _signal(im, mask, math.max(2, (0.625 * o.maxSpacingM / mpp).round()), tick);
  if (s == null) return CropRowResult(verdict: CropRowVerdict.noData, pixelM: mpp, resolutionM: res, pixels: valid, messages: [const CropRowMessage('flat'), ...notes]);
  await tick.at(0.12);

  // ---- 3. coarse direction over blocks
  final int bSize = math.min(math.max((3.5 * pMax).round(), 48), math.min(320, math.max(8, math.max(mw, mh))));
  final blocks = <_Block>[];
  for (var by = my0; by <= my1; by += bSize) {
    for (var bx = mx0; bx <= mx1; bx += bSize) {
      blocks.add(_Block(bx, by, math.min(bx + bSize, mx1 + 1), math.min(by + bSize, my1 + 1)));
    }
  }
  final strideC = valid > 300000 && bSize >= 160 ? 2 : 1;
  for (final b in blocks) {
    b.measure(mask, s, w, strideC);
  }
  final full = (bSize / strideC) * (bSize / strideC);
  var used = [
    for (final b in blocks)
      if (b.count >= math.max(64, 0.2 * full)) b,
  ];
  if (used.isEmpty) {
    used = [
      for (final b in blocks)
        if (b.count >= 16) b,
    ];
  }
  if (used.isEmpty) return CropRowResult(verdict: CropRowVerdict.noData, pixelM: mpp, resolutionM: res, pixels: valid, messages: [const CropRowMessage('noPixels'), ...notes]);
  final binC = math.min(1.0, pMin / 3);
  final stepC = (radToDeg(pMin / bSize) / 2).clamp(0.25, 1.0);
  final nC = math.max(36, (180 / stepC).round());
  final r2 = Float64List(nC);
  final halfC = 0.7072 * bSize + 2 * binC;
  final kC = (2 * halfC / binC).ceil() + 2;
  final sums = Float64List(kC);
  final cnts = Int32List(kC);
  used = [
    for (final b in used)
      if (b.sst > 0) b,
  ];
  if (used.isEmpty) return CropRowResult(verdict: CropRowVerdict.noData, pixelM: mpp, resolutionM: res, pixels: valid, messages: [const CropRowMessage('flat'), ...notes]);
  for (var a = 0; a < nC; a++) {
    final th = degToRad(a * 180 / nC);
    final nx = -math.sin(th), ny = math.cos(th);
    // every block one vote
    var sum = 0.0;
    for (final b in used) {
      sum += b.betweenSS(mask, s, w, strideC, nx, ny, halfC, 1 / binC, sums, cnts) / b.sst;
    }
    r2[a] = sum / used.length;
    await tick.at(0.12 + 0.5 * (a + 1) / nC);
  }
  var best = 0;
  for (var a = 1; a < nC; a++) {
    if (r2[a] > r2[best]) best = a;
  }
  final sorted = Float64List.fromList(r2)..sort();
  final median = sorted[nC ~/ 2];
  final contrast = r2[best] > 0 ? (1 - median / r2[best]).clamp(0.0, 1.0).toDouble() : 0.0;
  final thetaC = _parabolaPeak(r2[(best - 1 + nC) % nC], r2[best], r2[(best + 1) % nC]) * 180 / nC + best * 180 / nC;

  // ---- 4. coarse spacing from the block profiles
  final binF = math.min(1.0, pMin / 4);
  final maxLag = (1.3 * pMax / binF).ceil() + 2;
  final thC = degToRad(thetaC);
  final blockAcf = _Acf(maxLag);
  {
    final halfB = 0.7072 * bSize + 2 * binF;
    final kB = (2 * halfB / binF).ceil() + 2;
    final bs = Float64List(kB), bc = Int32List(kB), prof = Float64List(kB);
    final ok = Uint8List(kB);
    for (final b in used) {
      b.profile(mask, s, w, -math.sin(thC), math.cos(thC), halfB, 1 / binF, bs, bc);
      _means(bs, bc, kB, prof, ok, 3);
      // every block one vote
      var ss = 0.0;
      for (var k = 0; k < kB; k++) {
        ss += prof[k] * prof[k];
      }
      if (ss <= 0) continue;
      final f = 1 / math.sqrt(ss);
      for (var k = 0; k < kB; k++) {
        prof[k] *= f;
      }
      blockAcf.add(prof, ok, kB);
    }
  }
  final blockR = blockAcf.values();
  final blockPeak = _firstPeak(blockR, (0.9 * pMin / binF).floor(), math.min(maxLag - 1, (1.2 * pMax / binF).ceil()), 0.1);
  await tick.at(0.66);
  if (blockPeak == null) {
    return CropRowResult(
      verdict: CropRowVerdict.none,
      directionDeg: _half(thetaC),
      angularContrast: contrast,
      explained: r2[best],
      pixelM: mpp,
      resolutionM: res,
      pixels: valid,
      messages: [const CropRowMessage('noRows'), ...notes],
    );
  }
  // a peak whose half or third repeats as well is a multiple of a period
  // below the range (rows closer than the closest spacing searched, or than
  // the imagery shows): not the rows' spacing
  for (final k in const [2, 3]) {
    final sub = blockPeak.$1 / k;
    if (sub < 2) break;
    final rs = math.max(blockR[sub.floor()], blockR[sub.ceil()]);
    if (rs > 0.1 && rs >= 0.5 * blockPeak.$2) {
      return CropRowResult(
        verdict: CropRowVerdict.none,
        directionDeg: _half(thetaC),
        angularContrast: contrast,
        explained: r2[best],
        pixelM: mpp,
        resolutionM: res,
        pixels: valid,
        messages: [const CropRowMessage('noRows'), ...notes],
      );
    }
  }
  final pBlock = blockPeak.$1 * binF;
  final blockPeriodicity = blockPeak.$2.clamp(0.0, 1.0).toDouble();

  // ---- 5. fine direction over the whole field
  final cx = (mx0 + mx1 + 1) / 2, cy = (my0 + my1 + 1) / 2;
  final halfG = 0.5 * math.sqrt(mw * mw + mh * mh) + 2 * binF;
  final kG = (2 * halfG / binF).ceil() + 2;
  final gs = Float64List(kG);
  final gc = Int32List(kG);
  final strideF = valid > 600000 ? 2 : 1;
  final totals = _Totals.of(mask, s, w, mx0, my0, mx1, my1, strideF);
  double globalR2(double deg, int stride, _Totals tot) {
    final th = degToRad(deg);
    final ssb = _betweenSS(mask, s, w, mx0, my0, mx1, my1, stride, cx, cy, -math.sin(th), math.cos(th), halfG, 1 / binF, gs, gc, tot);
    return tot.sst > 0 ? ssb / tot.sst : 0;
  }

  final rowLength = (mw * math.cos(thC)).abs() + (mh * math.sin(thC)).abs();
  final lobe = radToDeg(pBlock / math.max(rowLength, pBlock));
  final range = math.max(1.5 * 180 / nC, 0.5);
  var stepF = (lobe / 4).clamp(0.004, 0.1);
  if (2 * range / stepF > 120) stepF = 2 * range / 120;
  final nF = (2 * range / stepF).round() + 1;
  final fr = Float64List(nF);
  for (var i = 0; i < nF; i++) {
    fr[i] = globalR2(thetaC - range + i * stepF, strideF, totals);
    await tick.at(0.66 + 0.2 * (i + 1) / nF);
  }
  var fb = 0;
  for (var i = 1; i < nF; i++) {
    if (fr[i] > fr[fb]) fb = i;
  }
  final thetaF = thetaC - range + (fb + (fb > 0 && fb < nF - 1 ? _parabolaPeak(fr[fb - 1], fr[fb], fr[fb + 1]) : 0)) * stepF;

  // ---- 6. the profile across the field at that direction: spacing, phase
  final all = strideF == 1 ? totals : _Totals.of(mask, s, w, mx0, my0, mx1, my1, 1);
  final explained = all.sst > 0 ? _betweenSS(mask, s, w, mx0, my0, mx1, my1, 1, cx, cy, -math.sin(degToRad(thetaF)), math.cos(degToRad(thetaF)), halfG, 1 / binF, gs, gc, all) / all.sst : 0.0;
  final prof = Float64List(kG);
  final ok = Uint8List(kG);
  _means(gs, gc, kG, prof, ok, _minCount(gc, kG));
  final acf = _Acf(maxLag)..add(prof, ok, kG);
  final gr = acf.values();
  // the highest autocorrelation near the coarse spacing
  final lo = math.max(math.max(1, (0.9 * pMin / binF).floor()), (0.75 * pBlock / binF).floor()), hi = math.min(maxLag - 2, (1.33 * pBlock / binF).ceil());
  var gk = lo;
  for (var k = lo; k <= hi; k++) {
    if (gr[k] > gr[gk]) gk = k;
  }
  final globalPeriodicity = gr[gk].clamp(0.0, 1.0).toDouble();
  final curved = globalPeriodicity < 0.5 * blockPeriodicity;
  double theta, period, periodicity, u0;
  if (curved) {
    // the rows bend: the block values, rows placed by the phase over the field
    theta = thetaC;
    period = pBlock;
    periodicity = blockPeriodicity * 0.75;
    final th = degToRad(theta);
    _betweenSS(mask, s, w, mx0, my0, mx1, my1, 1, cx, cy, -math.sin(th), math.cos(th), halfG, 1 / binF, gs, gc, all);
    _means(gs, gc, kG, prof, ok, _minCount(gc, kG));
    final (_, phase) = _refine(prof, ok, kG, period / binF, rel: 0);
    u0 = -halfG + (phase + 0.5) * binF;
  } else {
    theta = thetaF;
    final p0 = gk + (gk > lo && gk < hi ? _parabolaPeak(gr[gk - 1], gr[gk], gr[gk + 1]) : 0.0);
    final (pBins, phase) = _refine(prof, ok, kG, p0);
    period = pBins * binF;
    periodicity = globalPeriodicity;
    u0 = -halfG + (phase + 0.5) * binF;
  }
  if (period < 0.9 * pMin || period > 1.25 * pMax) {
    // the bins and the interpolation let a period slip past the range
    return CropRowResult(
      verdict: CropRowVerdict.none,
      directionDeg: _half(theta),
      angularContrast: contrast,
      explained: explained,
      pixelM: mpp,
      resolutionM: res,
      pixels: valid,
      messages: [const CropRowMessage('noRows'), ...notes],
    );
  }
  // which band is the crop: the colour put the greener (and darker) band
  // first; when both bands are vegetation, the crop is the wider one — a
  // closed canopy whose narrow alleys lie in its shade (darker and, lit
  // through the leaves, greener than the sunlit canopy)
  final (autoShare, autoSwap) = _cropBand(im.rgba, mask, s, w, mx0, my0, mx1, my1, cx, cy, theta, period, u0);
  final swapped = autoSwap != o.otherBand;
  final share = o.otherBand ? 1 - autoShare : autoShare;
  if (swapped) {
    u0 += period / 2;
    for (var i = 0; i < s.length; i++) {
      s[i] = -s[i];
    }
  }
  await tick.at(0.88);

  // ---- 7. the rows over the whole outline
  final dirDeg = _half(theta);
  final th = degToRad(dirDeg);
  final nrm = Pt(-math.sin(th), math.cos(th));
  // u was measured across θ (or θ − 180°: the same lines, the other way)
  final flip = (normalizeDeg(theta) >= 180) ? -1.0 : 1.0;
  final centreW = im.toWorld(cx, cy);
  final spacingM = period * mpp;
  final firstW = centreW.dot(nrm) + flip * u0 * mpp;
  final (counted, lines) = cropRowLines(outline, holes, dirDeg, spacingM, firstW);
  final offsetM = counted.isEmpty ? firstW : counted.first;

  // ---- 8. plants along the rows
  double? plantSpacingM;
  var plantPeriodicity = 0.0;
  if (!curved && period >= 4) {
    // a crown needs more pixels than a stripe: four of the imagery's
    final pl = _plants(mask, s, w, h, mx0, my0, mx1, my1, cx, cy, theta, period, u0, math.max(4 * res, 0.25) / mpp, 1.2 * period);
    if (pl != null && pl.$2 >= plantPeriodicityMin) {
      plantSpacingM = pl.$1 * mpp;
      plantPeriodicity = pl.$2;
    } else if (pl != null) {
      plantPeriodicity = math.max(0, pl.$2);
    }
  }
  await tick.at(0.94);

  // ---- 9. ground cover
  final (cover, bc) = _cover(mask, s, w, h);

  final confidence = (contrast * periodicity).clamp(0.0, 1.0).toDouble();
  var verdict = confidence >= confidenceRows ? CropRowVerdict.rows : (confidence >= confidenceUncertain ? CropRowVerdict.uncertain : CropRowVerdict.none);
  if (verdict == CropRowVerdict.rows && counted.length < 3) verdict = CropRowVerdict.uncertain;
  final messages = <CropRowMessage>[
    if (verdict == CropRowVerdict.none) const CropRowMessage('noRows'),
    // the imagery's limit matters when the rows were not clearly found
    if (verdict != CropRowVerdict.rows) ...notes,
    if (verdict != CropRowVerdict.none && curved) const CropRowMessage('curved'),
    if (verdict != CropRowVerdict.none && counted.length < 3) CropRowMessage('fewRows', {'n': counted.length.toDouble()}),
    if (verdict != CropRowVerdict.none && spacingM < 3 * res) CropRowMessage('fewPixels', {'p': spacingM / res}),
  ];
  final found = verdict != CropRowVerdict.none;
  return CropRowResult(
    verdict: verdict,
    directionDeg: dirDeg,
    spacingM: spacingM,
    rows: found ? counted.length : 0,
    confidence: confidence,
    angularContrast: contrast,
    periodicity: periodicity,
    explained: explained,
    plantSpacingM: found ? plantSpacingM : null,
    plantPeriodicity: plantPeriodicity,
    groundCover: found && bc > bimodalityMin ? cover : null,
    bimodality: bc,
    offsetM: offsetM,
    rowOffsetsM: found ? counted : const [],
    rowLines: found ? lines : const [],
    pixelM: mpp,
    resolutionM: res,
    pixels: valid,
    curved: curved,
    bandShare: share,
    swapped: swapped,
    messages: messages,
  );
}

/// [deg] as a direction of a line, in [0, 180).
double _half(double deg) {
  final v = normalizeDeg(deg) % 180;
  return v >= 180 - 1e-9 ? 0 : v;
}

/// Offset of the top of the parabola through (−1, a), (0, b), (1, c).
double _parabolaPeak(double a, double b, double c) {
  final d = a - 2 * b + c;
  if (d >= 0 || !d.isFinite) return 0;
  return (0.5 * (a - c) / d).clamp(-0.5, 0.5).toDouble();
}

/// The row lines of a field: the lines p·n = [offsetM] + k·[spacingM] (n =
/// (−sin θ, cos θ), θ = [directionDeg]) that lie in [outline] less its
/// [holes] for at least max(1 m, half a spacing); their offsets and their
/// pieces (shorter than 0.25 m left out).
(List<double>, List<List<Pt>>) cropRowLines(List<Pt> outline, List<List<Pt>> holes, double directionDeg, double spacingM, double offsetM) {
  final th = degToRad(directionDeg);
  final nrm = Pt(-math.sin(th), math.cos(th));
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in outline) {
    final v = p.dot(nrm);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
  }
  final counted = <double>[];
  final lines = <List<Pt>>[];
  if (!(spacingM > 0) || outline.length < 3 || (vMax - vMin) / spacingM > 50000) return (counted, lines);
  final minLen = math.max(1.0, spacingM / 2);
  for (var k = ((vMin - offsetM) / spacingM).ceil(); offsetM + k * spacingM <= vMax; k++) {
    final v = offsetM + k * spacingM;
    final segs = rowSegments(outline, holes, directionDeg, [v]);
    final len = segs.fold(0.0, (a, x) => a + x[0].distanceTo(x[1]));
    if (len < minLen) continue;
    counted.add(v);
    for (final x in segs) {
      if (x[0].distanceTo(x[1]) >= 0.25) lines.add(x);
    }
  }
  return (counted, lines);
}

/// The pieces of the lines p·n = v (n = (−sin θ, cos θ), θ = [directionDeg])
/// for each of [offsets] inside [outline] and outside its [holes] (even–odd
/// over all the rings), two points each, the shorter than [minLength]
/// left out.
List<List<Pt>> rowSegments(List<Pt> outline, List<List<Pt>> holes, double directionDeg, Iterable<double> offsets, {double minLength = 0}) {
  final th = degToRad(directionDeg);
  final d = Pt(math.cos(th), math.sin(th)), n = Pt(-math.sin(th), math.cos(th));
  final rings = [
    if (outline.length >= 3) outline,
    for (final x in holes)
      if (x.length >= 3) x,
  ];
  final out = <List<Pt>>[];
  final ts = <double>[];
  for (final v in offsets) {
    final o = n * v;
    ts.clear();
    for (final r in rings) {
      for (var i = 0; i < r.length; i++) {
        final a = r[i], b = r[(i + 1) % r.length];
        final va = a.dot(n) - v, vb = b.dot(n) - v;
        if ((va > 0) == (vb > 0)) continue;
        final f = va / (va - vb);
        ts.add((Pt.lerp(a, b, f) - o).dot(d));
      }
    }
    ts.sort();
    for (var i = 0; i + 1 < ts.length; i += 2) {
      if (ts[i + 1] - ts[i] >= minLength && ts[i + 1] - ts[i] > 1e-9) out.add([o + d * ts[i], o + d * ts[i + 1]]);
    }
  }
  return out;
}

// ---------------------------------------------------------------- pixels

/// 1 where the pixel centre lies in the field and the pixel has data.
Uint8List _mask(CropRowRaster im, List<Pt> outline, List<List<Pt>> holes) {
  final w = im.width, h = im.height;
  final m = Uint8List(w * h);
  final ex0 = <double>[], ey0 = <double>[], ex1 = <double>[], ey1 = <double>[];
  for (final r in [
    outline,
    for (final x in holes)
      if (x.length >= 3) x,
  ]) {
    for (var i = 0; i < r.length; i++) {
      final (ax, ay) = im.toPixel(r[i]);
      final (bx, by) = im.toPixel(r[(i + 1) % r.length]);
      if (ay == by) continue;
      ex0.add(ax);
      ey0.add(ay);
      ex1.add(bx);
      ey1.add(by);
    }
  }
  final xs = <double>[];
  final px = im.rgba;
  for (var j = 0; j < h; j++) {
    final yc = j + 0.5;
    xs.clear();
    for (var e = 0; e < ex0.length; e++) {
      final a = ey0[e], b = ey1[e];
      if ((a <= yc) != (b <= yc)) xs.add(ex0[e] + (yc - a) * (ex1[e] - ex0[e]) / (b - a));
    }
    if (xs.length < 2) continue;
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final i0 = math.max(0, (xs[k] - 0.5).ceil()), i1 = math.min(w - 1, (xs[k + 1] - 0.5).floor());
      final row = j * w;
      for (var i = i0; i <= i1; i++) {
        if (px[4 * (row + i) + 3] >= 128) m[row + i] = 1;
      }
    }
  }
  return m;
}

/// Sums of [src] over the (2r+1)² box round every pixel (clipped at the
/// edges), into [dst]; [tmp] holds the horizontal pass.
void _boxSum(Float32List src, Float32List dst, Float32List tmp, int w, int h, int r) {
  for (var y = 0; y < h; y++) {
    final o = y * w;
    var acc = 0.0;
    for (var x = 0; x <= math.min(r, w - 1); x++) {
      acc += src[o + x];
    }
    for (var x = 0; x < w; x++) {
      tmp[o + x] = acc;
      final add = x + r + 1, sub = x - r;
      if (add < w) acc += src[o + add];
      if (sub >= 0) acc -= src[o + sub];
    }
  }
  for (var x = 0; x < w; x++) {
    var acc = 0.0;
    for (var y = 0; y <= math.min(r, h - 1); y++) {
      acc += tmp[y * w + x];
    }
    for (var y = 0; y < h; y++) {
      dst[y * w + x] = acc;
      final add = y + r + 1, sub = y - r;
      if (add < h) acc += tmp[add * w + x];
      if (sub >= 0) acc -= tmp[sub * w + x];
    }
  }
}

/// The high-passed colour of the field projected on its first principal
/// component, canopy positive, robustly clipped (0 outside the field); null
/// when the field shows no contrast at all.
Future<Float32List?> _signal(CropRowRaster im, Uint8List mask, int r, _Ticker tick) async {
  final w = im.width, h = im.height, n = w * h;
  final px = im.rgba;
  final mf = Float32List(n);
  for (var i = 0; i < n; i++) {
    mf[i] = mask[i].toDouble();
  }
  final tmp = Float32List(n), boxM = Float32List(n), v = Float32List(n), bv = Float32List(n);
  _boxSum(mf, boxM, tmp, w, h, r);
  await tick.at(0.04);
  // a sample of the high-passed colour for its covariance (every third
  // pixel each way)
  final idx = <int>[];
  for (var y = 1; y < h; y += 3) {
    for (var x = 1; x < w; x += 3) {
      if (mask[y * w + x] == 1) idx.add(y * w + x);
    }
  }
  if (idx.length < 30) {
    for (var i = 0; i < n; i++) {
      if (mask[i] == 1) idx.add(i);
    }
  }
  final hp = [Float64List(idx.length), Float64List(idx.length), Float64List(idx.length)];
  for (var ch = 0; ch < 3; ch++) {
    for (var i = 0; i < n; i++) {
      v[i] = mask[i] == 1 ? px[4 * i + ch].toDouble() : 0;
    }
    _boxSum(v, bv, tmp, w, h, r);
    final out = hp[ch];
    for (var k = 0; k < idx.length; k++) {
      final i = idx[k];
      out[k] = px[4 * i + ch] - bv[i] / boxM[i];
    }
    await tick.at(0.05 + 0.02 * ch);
  }
  // covariance and its first eigenvector (power iteration)
  final cov = Float64List(9);
  for (var k = 0; k < idx.length; k++) {
    final a = hp[0][k], b = hp[1][k], c = hp[2][k];
    cov[0] += a * a;
    cov[1] += a * b;
    cov[2] += a * c;
    cov[4] += b * b;
    cov[5] += b * c;
    cov[8] += c * c;
  }
  cov[3] = cov[1];
  cov[6] = cov[2];
  cov[7] = cov[5];
  for (var i = 0; i < 9; i++) {
    cov[i] /= idx.length;
  }
  if (cov[0] + cov[4] + cov[8] < 0.25) return null;
  var e0 = 1.0, e1 = 1.0, e2 = 1.0;
  for (var it = 0; it < 60; it++) {
    final a = cov[0] * e0 + cov[1] * e1 + cov[2] * e2;
    final b = cov[3] * e0 + cov[4] * e1 + cov[5] * e2;
    final c = cov[6] * e0 + cov[7] * e1 + cov[8] * e2;
    final l = math.sqrt(a * a + b * b + c * c);
    if (l <= 0) break;
    e0 = a / l;
    e1 = b / l;
    e2 = c / l;
  }
  // canopy positive: greener and darker
  var mExg = 0.0, mLum = 0.0, sExg = 0.0, sLum = 0.0;
  final exg = Float64List(idx.length), lum = Float64List(idx.length);
  for (var k = 0; k < idx.length; k++) {
    final i = idx[k];
    final rr = px[4 * i].toDouble(), gg = px[4 * i + 1].toDouble(), bb = px[4 * i + 2].toDouble();
    exg[k] = (2 * gg - rr - bb) / (rr + gg + bb + 30);
    lum[k] = (rr + gg + bb) / 3;
    mExg += exg[k];
    mLum += lum[k];
  }
  mExg /= idx.length;
  mLum /= idx.length;
  for (var k = 0; k < idx.length; k++) {
    sExg += (exg[k] - mExg) * (exg[k] - mExg);
    sLum += (lum[k] - mLum) * (lum[k] - mLum);
  }
  sExg = math.sqrt(sExg / idx.length);
  sLum = math.sqrt(sLum / idx.length);
  var corr = 0.0;
  for (var k = 0; k < idx.length; k++) {
    final proj = e0 * hp[0][k] + e1 * hp[1][k] + e2 * hp[2][k];
    final ind = (sExg > 0 ? (exg[k] - mExg) / sExg : 0) - 0.5 * (sLum > 0 ? (lum[k] - mLum) / sLum : 0);
    corr += proj * ind;
  }
  if (corr < 0) {
    e0 = -e0;
    e1 = -e1;
    e2 = -e2;
  }
  // the projection, high-passed (the box filter is linear)
  for (var i = 0; i < n; i++) {
    v[i] = mask[i] == 1 ? e0 * px[4 * i] + e1 * px[4 * i + 1] + e2 * px[4 * i + 2] : 0;
  }
  _boxSum(v, bv, tmp, w, h, r);
  for (var i = 0; i < n; i++) {
    v[i] = mask[i] == 1 ? v[i] - bv[i] / boxM[i] : 0;
  }
  // divided by its local RMS over the same box: a dark orchard and a bright
  // bare patch or road in the same outline weigh alike (local contrast
  // normalisation); the floor, a quarter of the field's own robust RMS,
  // keeps flat parts (a uniform pasture, a blank tile) from being raised to
  // the level of the rows, their compression grain with them
  final floor = 0.25 * _robustSigma(v, idx);
  if (floor <= 0) return null;
  for (var i = 0; i < n; i++) {
    bv[i] = v[i] * v[i];
  }
  _boxSum(bv, mf, tmp, w, h, r);
  for (var i = 0; i < n; i++) {
    if (mask[i] == 1) v[i] /= math.sqrt(mf[i] / boxM[i] + floor * floor);
  }
  await tick.at(0.1);
  // clipped at four robust standard deviations
  final sigma = _robustSigma(v, idx);
  if (sigma <= 0) return null;
  final lim = 4 * sigma;
  for (var i = 0; i < n; i++) {
    if (v[i] > lim) {
      v[i] = lim;
    } else if (v[i] < -lim) {
      v[i] = -lim;
    }
  }
  return v;
}

/// Robust standard deviation of [v] over the pixels [idx]: 1.4826 × the
/// median absolute deviation, or the RMS when more than half of them are
/// one value; 0 for a flat field.
double _robustSigma(Float32List v, List<int> idx) {
  if (idx.isEmpty) return 0;
  final sample = Float64List(idx.length);
  for (var k = 0; k < idx.length; k++) {
    sample[k] = v[idx[k]];
  }
  sample.sort();
  final med = sample[sample.length ~/ 2];
  for (var k = 0; k < sample.length; k++) {
    sample[k] = (sample[k] - med).abs();
  }
  sample.sort();
  var sigma = 1.4826 * sample[sample.length ~/ 2];
  if (sigma <= 1e-6) {
    var ss = 0.0;
    for (var k = 0; k < idx.length; k++) {
      ss += v[idx[k]] * v[idx[k]];
    }
    sigma = math.sqrt(ss / idx.length);
  }
  return sigma < 1e-4 ? 0 : sigma;
}

/// A square of the field for the coarse scan, with its sums at a stride.
class _Block {
  _Block(this.x0, this.y0, this.x1, this.y1) : xc = (x0 + x1) / 2, yc = (y0 + y1) / 2;
  final int x0, y0, x1, y1;
  final double xc, yc;
  int count = 0;
  double sum = 0, sst = 0;

  void measure(Uint8List mask, Float32List s, int w, int stride) {
    var ss = 0.0;
    count = 0;
    sum = 0;
    for (var y = y0; y < y1; y += stride) {
      for (var x = x0; x < x1; x += stride) {
        final i = y * w + x;
        if (mask[i] == 0) continue;
        count++;
        sum += s[i];
        ss += s[i] * s[i];
      }
    }
    sst = count > 0 ? ss - sum * sum / count : 0;
  }

  /// Between-bin sum of squares of the block binned across (nx, ny).
  double betweenSS(Uint8List mask, Float32List s, int w, int stride, double nx, double ny, double half, double inv, Float64List sums, Int32List cnts) {
    if (count == 0) return 0;
    final k = (2 * half * inv).ceil() + 1;
    sums.fillRange(0, math.min(k, sums.length), 0);
    cnts.fillRange(0, math.min(k, cnts.length), 0);
    for (var y = y0; y < y1; y += stride) {
      final yy = (yc - y - 0.5) * ny + half;
      final row = y * w;
      for (var x = x0; x < x1; x += stride) {
        final i = row + x;
        if (mask[i] == 0) continue;
        final b = (((x + 0.5 - xc) * nx + yy) * inv).toInt();
        sums[b] += s[i];
        cnts[b]++;
      }
    }
    var ssb = 0.0;
    for (var b = 0; b < k && b < sums.length; b++) {
      final c = cnts[b];
      if (c > 0) ssb += sums[b] * sums[b] / c;
    }
    return ssb - sum * sum / count;
  }

  /// The binned sums and counts across (nx, ny) at stride 1.
  void profile(Uint8List mask, Float32List s, int w, double nx, double ny, double half, double inv, Float64List sums, Int32List cnts) {
    sums.fillRange(0, sums.length, 0);
    cnts.fillRange(0, cnts.length, 0);
    for (var y = y0; y < y1; y++) {
      final yy = (yc - y - 0.5) * ny + half;
      final row = y * w;
      for (var x = x0; x < x1; x++) {
        final i = row + x;
        if (mask[i] == 0) continue;
        final b = (((x + 0.5 - xc) * nx + yy) * inv).toInt();
        if (b < 0 || b >= sums.length) continue;
        sums[b] += s[i];
        cnts[b]++;
      }
    }
  }
}

/// Count, sum and total sum of squares of the field at a stride.
class _Totals {
  _Totals(this.count, this.sum, this.sst);
  final int count;
  final double sum, sst;

  static _Totals of(Uint8List mask, Float32List s, int w, int x0, int y0, int x1, int y1, int stride) {
    var n = 0;
    var sum = 0.0, ss = 0.0;
    for (var y = y0; y <= y1; y += stride) {
      for (var x = x0; x <= x1; x += stride) {
        final i = y * w + x;
        if (mask[i] == 0) continue;
        n++;
        sum += s[i];
        ss += s[i] * s[i];
      }
    }
    return _Totals(n, sum, n > 0 ? ss - sum * sum / n : 0);
  }
}

/// Between-bin sum of squares of the whole field binned across (nx, ny)
/// round (cx, cy), leaving the sums and counts in [sums] and [cnts].
double _betweenSS(
  Uint8List mask,
  Float32List s,
  int w,
  int x0,
  int y0,
  int x1,
  int y1,
  int stride,
  double cx,
  double cy,
  double nx,
  double ny,
  double half,
  double inv,
  Float64List sums,
  Int32List cnts,
  _Totals tot,
) {
  sums.fillRange(0, sums.length, 0);
  cnts.fillRange(0, cnts.length, 0);
  for (var y = y0; y <= y1; y += stride) {
    final yy = (cy - y - 0.5) * ny + half;
    final row = y * w;
    for (var x = x0; x <= x1; x += stride) {
      final i = row + x;
      if (mask[i] == 0) continue;
      final b = (((x + 0.5 - cx) * nx + yy) * inv).toInt();
      sums[b] += s[i];
      cnts[b]++;
    }
  }
  if (tot.count == 0) return 0;
  var ssb = 0.0;
  for (var b = 0; b < sums.length; b++) {
    final c = cnts[b];
    if (c > 0) ssb += sums[b] * sums[b] / c;
  }
  return ssb - tot.sum * tot.sum / tot.count;
}

/// The share of the period the crop band takes and whether the crop is
/// the band the signal made negative. The profile is folded over the
/// period from a row line (24 phases) and split at the midpoint of its
/// extremes into two bands, each with the excess green of its mean colour
/// (damped as in vegetation.dart). The signal made the greener and darker
/// band positive: the crop where the alleys are bare soil, dry grass or a
/// lighter cover (young plantings, vines, hedgerows, coffee — whose glossy
/// leaves are darker than a grassed alley). When both bands are vegetation
/// (excess green at least [VegetationImage.greenFloor]) and the other band
/// is the wider by [bandShareMargin], the field is a closed canopy whose
/// narrow alleys lie in its shade — darker and, lit through the leaves,
/// greener than the sunlit crowns: the wider band is the crop. Where that is
/// wrong the user moves the rows by half a spacing
/// ([CropRowOptions.otherBand]).
(double, bool) _cropBand(Uint8List px, Uint8List mask, Float32List s, int w, int x0, int y0, int x1, int y1, double cx, double cy, double thetaDeg, double period, double u0) {
  const nb = 24;
  final th = degToRad(thetaDeg);
  final nx = -math.sin(th), ny = math.cos(th);
  final sum = Float64List(nb), r = Float64List(nb), g = Float64List(nb), b = Float64List(nb);
  final cnt = Int32List(nb);
  for (var y = y0; y <= y1; y++) {
    final yy = (cy - y - 0.5) * ny;
    for (var x = x0; x <= x1; x++) {
      final i = y * w + x;
      if (mask[i] == 0) continue;
      final ph = ((x + 0.5 - cx) * nx + yy - u0) / period;
      final k = ((ph - ph.floor()) * nb).floor() % nb;
      sum[k] += s[i];
      r[k] += px[4 * i];
      g[k] += px[4 * i + 1];
      b[k] += px[4 * i + 2];
      cnt[k]++;
    }
  }
  var hi = -double.infinity, lo = double.infinity;
  for (var k = 0; k < nb; k++) {
    if (cnt[k] == 0) continue;
    final m = sum[k] / cnt[k];
    hi = math.max(hi, m);
    lo = math.min(lo, m);
  }
  if (!hi.isFinite || hi <= lo) return (0.5, false);
  final mid = (hi + lo) / 2;
  var nA = 0, nB = 0, kA = 0, kB = 0;
  var rA = 0.0, gA = 0.0, bA = 0.0, rB = 0.0, gB = 0.0, bB = 0.0;
  for (var k = 0; k < nb; k++) {
    if (cnt[k] == 0) continue;
    if (sum[k] / cnt[k] >= mid) {
      kA++;
      nA += cnt[k];
      rA += r[k];
      gA += g[k];
      bA += b[k];
    } else {
      kB++;
      nB += cnt[k];
      rB += r[k];
      gB += g[k];
      bB += b[k];
    }
  }
  if (nA == 0 || nB == 0) return (0.5, false);
  double exg(double r, double g, double b, int n) => (2 * g - r - b) / n / ((r + g + b) / n + VegetationImage.darkDamping);
  final shareA = kA / (kA + kB);
  final bothGreen = exg(rA, gA, bA, nA) >= VegetationImage.greenFloor && exg(rB, gB, bB, nB) >= VegetationImage.greenFloor;
  final swap = bothGreen && shareA <= 0.5 - bandShareMargin;
  return (swap ? 1 - shareA : shareA, swap);
}

/// Bins of a profile counted as data: a tenth of the median count of the
/// bins with pixels, at least two.
int _minCount(Int32List cnts, int k) {
  final c = <int>[
    for (var b = 0; b < k; b++)
      if (cnts[b] > 0) cnts[b],
  ]..sort();
  if (c.isEmpty) return 1;
  return math.max(2, (0.1 * c[c.length ~/ 2]).round());
}

/// The bin means less their mean into [prof], [ok] = 1 where a bin has at
/// least [minCount] pixels.
void _means(Float64List sums, Int32List cnts, int k, Float64List prof, Uint8List ok, int minCount) {
  var total = 0.0;
  var n = 0;
  for (var b = 0; b < k; b++) {
    if (cnts[b] >= minCount) {
      prof[b] = sums[b] / cnts[b];
      ok[b] = 1;
      total += prof[b];
      n++;
    } else {
      prof[b] = 0;
      ok[b] = 0;
    }
  }
  final mean = n > 0 ? total / n : 0.0;
  for (var b = 0; b < k; b++) {
    if (ok[b] == 1) prof[b] -= mean;
  }
}

/// Autocorrelation of profiles with gaps, pooled: for every lag the sum of
/// the products of the pairs where both bins have data, normalised by the
/// sums of squares of those same pairs (a correlation coefficient).
class _Acf {
  _Acf(this.maxLag) : num = Float64List(maxLag + 1), d1 = Float64List(maxLag + 1), d2 = Float64List(maxLag + 1);
  final int maxLag;
  final Float64List num, d1, d2;

  void add(Float64List a, Uint8List ok, int len) {
    for (var lag = 0; lag <= maxLag && lag < len; lag++) {
      var nn = 0.0, x1 = 0.0, x2 = 0.0;
      for (var k = 0; k + lag < len; k++) {
        if (ok[k] == 0 || ok[k + lag] == 0) continue;
        final p = a[k], q = a[k + lag];
        nn += p * q;
        x1 += p * p;
        x2 += q * q;
      }
      num[lag] += nn;
      d1[lag] += x1;
      d2[lag] += x2;
    }
  }

  Float64List values() {
    final r = Float64List(maxLag + 1);
    for (var lag = 0; lag <= maxLag; lag++) {
      final d = math.sqrt(d1[lag] * d2[lag]);
      r[lag] = d > 0 ? num[lag] / d : 0;
    }
    return r;
  }
}

/// The first local maximum of [r] in [lo, hi] that reaches half of the
/// highest one there and [minHeight]: its position (sub-bin, by a parabola)
/// and value; null when none.
(double, double)? _firstPeak(Float64List r, int lo, int hi, double minHeight) {
  lo = math.max(1, lo);
  hi = math.min(r.length - 2, hi);
  if (hi <= lo) return null;
  final peaks = <int>[];
  for (var k = lo; k <= hi; k++) {
    if (r[k] > r[k - 1] && r[k] >= r[k + 1]) peaks.add(k);
  }
  if (peaks.isEmpty) return null;
  final top = peaks.map((k) => r[k]).reduce(math.max);
  for (final k in peaks) {
    if (r[k] >= math.max(minHeight, 0.5 * top)) {
      final d = _parabolaPeak(r[k - 1], r[k], r[k + 1]);
      return (k + d, r[k]);
    }
  }
  return null;
}

/// The period (bins) near [p0] at which the power of the profile [a]
/// (Hann-windowed over its data) peaks, searched within ±[rel] and refined
/// by a parabola through the logarithm of the power, and the position
/// (bins from the start) of a maximum of that harmonic.
(double, double) _refine(Float64List a, Uint8List ok, int len, double p0, {double rel = 0.06, int steps = 120}) {
  var first = -1, last = -1;
  for (var k = 0; k < len; k++) {
    if (ok[k] == 1) {
      if (first < 0) first = k;
      last = k;
    }
  }
  if (first < 0 || last <= first || p0 <= 0) return (p0, 0);
  final c = (first + last) / 2, span = (last - first).toDouble();
  final win = Float64List(len);
  for (var k = first; k <= last; k++) {
    win[k] = ok[k] == 1 ? a[k] * 0.5 * (1 - math.cos(2 * math.pi * (k - first) / span)) : 0;
  }
  (double, double) dft(double f) {
    // cos and sin of 2πf(k − c) by rotation
    final step = 2 * math.pi * f;
    final cs = math.cos(step), sn = math.sin(step);
    var cr = math.cos(step * (first - c)), ci = math.sin(step * (first - c));
    var re = 0.0, im = 0.0;
    for (var k = first; k <= last; k++) {
      final x = win[k];
      re += x * cr;
      im += x * ci;
      final nr = cr * cs - ci * sn;
      ci = ci * cs + cr * sn;
      cr = nr;
    }
    return (re, im);
  }

  double f;
  if (rel <= 0) {
    f = 1 / p0;
  } else {
    final f0 = 1 / p0;
    final pw = Float64List(steps + 1);
    for (var j = 0; j <= steps; j++) {
      final fj = f0 * (1 - rel + 2 * rel * j / steps);
      final (re, im) = dft(fj);
      pw[j] = re * re + im * im;
    }
    var jb = 0;
    for (var j = 1; j <= steps; j++) {
      if (pw[j] > pw[jb]) jb = j;
    }
    if (jb == 0 || jb == steps || pw[jb] <= 0) {
      f = f0;
    } else {
      double lg(double v) => math.log(math.max(v, 1e-300));
      final d = _parabolaPeak(lg(pw[jb - 1]), lg(pw[jb]), lg(pw[jb + 1]));
      f = f0 * (1 - rel + 2 * rel * (jb + d) / steps);
    }
  }
  final (re, im) = dft(f);
  // a(k) ≈ A·cos(2πf(k − c) − ψ) with ψ = atan2(Σ x sin, Σ x cos)
  final psi = math.atan2(im, re);
  var pos = c + psi / (2 * math.pi * f);
  final p = 1 / f;
  pos = pos - (pos / p).floor() * p;
  return (p, pos);
}

/// Spacing (px) of the plants along the rows and the autocorrelation at it,
/// from the signal sampled along the centre lines of the rows (see the
/// library comment); null when no peak lies in [minP, maxP].
(double, double)? _plants(Uint8List mask, Float32List s, int w, int h, int x0, int y0, int x1, int y1, double cx, double cy, double thetaDeg, double period, double u0, double minP, double maxP) {
  if (maxP < minP * 1.2) return null;
  final th = degToRad(thetaDeg);
  final dx = math.cos(th), dy = math.sin(th), nx = -math.sin(th), ny = math.cos(th);
  // extents across and along, from the corners of the field's box
  var uLo = double.infinity, uHi = -double.infinity, tLo = double.infinity, tHi = -double.infinity;
  for (final (x, y) in [(x0, y0), (x1 + 1, y0), (x0, y1 + 1), (x1 + 1, y1 + 1)]) {
    final X = x - cx, Y = cy - y;
    final u = X * nx + Y * ny, t = X * dx + Y * dy;
    uLo = math.min(uLo, u);
    uHi = math.max(uHi, u);
    tLo = math.min(tLo, t);
    tHi = math.max(tHi, t);
  }
  final len = (tHi - tLo).ceil() + 1;
  if (len < 3 * minP) return null;
  final maxLag = math.min(len - 2, (1.3 * maxP).ceil() + 2);
  final acf = _Acf(maxLag);
  final prof = Float64List(len), sum = Float64List(len);
  final cnt = Int32List(len);
  final ok = Uint8List(len);
  final kLo = ((uLo - u0) / period).ceil(), kHi = ((uHi - u0) / period).floor();
  final total = kHi - kLo + 1;
  if (total <= 0) return null;
  final every = math.max(1, (total / 150).ceil());
  for (var k = kLo; k <= kHi; k += every) {
    final u = u0 + k * period;
    sum.fillRange(0, len, 0);
    cnt.fillRange(0, len, 0);
    var n = 0;
    for (final off in [-0.12 * period, 0.0, 0.12 * period]) {
      final uu = u + off;
      for (var j = 0; j < len; j++) {
        final t = tLo + j;
        final X = uu * nx + t * dx, Y = uu * ny + t * dy;
        final px = (cx + X).floor(), py = (cy - Y).floor();
        if (px < 0 || py < 0 || px >= w || py >= h) continue;
        final i = py * w + px;
        if (mask[i] == 0) continue;
        sum[j] += s[i];
        cnt[j]++;
        n++;
      }
    }
    if (n < 3 * minP) continue;
    var mean = 0.0, m = 0;
    for (var j = 0; j < len; j++) {
      if (cnt[j] > 0) {
        prof[j] = sum[j] / cnt[j];
        ok[j] = 1;
        mean += prof[j];
        m++;
      } else {
        prof[j] = 0;
        ok[j] = 0;
      }
    }
    mean /= m;
    for (var j = 0; j < len; j++) {
      if (ok[j] == 1) prof[j] -= mean;
    }
    acf.add(prof, ok, len);
  }
  final r = acf.values();
  return _firstPeak(r, (0.9 * minP).floor(), math.min(maxLag - 1, maxP.ceil()), 0.05);
}

/// Canopy share of the field (Otsu threshold of the signal smoothed over
/// 3 × 3 pixels) and the bimodality coefficient of that signal.
(double, double) _cover(Uint8List mask, Float32List s, int w, int h) {
  var count = 0;
  for (var i = 0; i < mask.length; i++) {
    count += mask[i];
  }
  final vals = Float64List(count);
  var at = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (mask[i] == 0) continue;
      var sum = 0.0;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final j = yy * w + xx;
          if (mask[j] == 0) continue;
          sum += s[j];
          n++;
        }
      }
      vals[at++] = sum / n;
    }
  }
  if (vals.length < 10) return (0, 0);
  var lo = double.infinity, hi = -double.infinity, mean = 0.0;
  for (final v in vals) {
    lo = math.min(lo, v);
    hi = math.max(hi, v);
    mean += v;
  }
  mean /= vals.length;
  var m2 = 0.0, m3 = 0.0, m4 = 0.0;
  for (final v in vals) {
    final d = v - mean, d2 = d * d;
    m2 += d2;
    m3 += d2 * d;
    m4 += d2 * d2;
  }
  m2 /= vals.length;
  m3 /= vals.length;
  m4 /= vals.length;
  if (m2 <= 0 || hi <= lo) return (0, 0);
  final skew = m3 / math.pow(m2, 1.5), kurt = m4 / (m2 * m2) - 3;
  final n = vals.length.toDouble();
  final bc = (skew * skew + 1) / (kurt + 3 * (n - 1) * (n - 1) / ((n - 2) * (n - 3)));
  // Otsu on a 256-bin histogram
  const bins = 256;
  final hist = Float64List(bins);
  final scale = (bins - 1) / (hi - lo);
  for (final v in vals) {
    hist[((v - lo) * scale).round()]++;
  }
  var sumAll = 0.0;
  for (var b = 0; b < bins; b++) {
    sumAll += b * hist[b];
  }
  var wB = 0.0, sumB = 0.0, bestVar = -1.0;
  var thr = 0;
  for (var b = 0; b < bins; b++) {
    wB += hist[b];
    if (wB == 0) continue;
    final wF = n - wB;
    if (wF == 0) break;
    sumB += b * hist[b];
    final mB = sumB / wB, mF = (sumAll - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > bestVar) {
      bestVar = between;
      thr = b;
    }
  }
  var above = 0.0;
  for (var b = thr + 1; b < bins; b++) {
    above += hist[b];
  }
  return (above / n, bc);
}

// ---------------------------------------------------------------- the project

/// The row direction stored on [e] (read from the image), as a unit vector;
/// null when [e] is not an area or has none: the automatic design dialogs
/// and the assistant's design tools then default to the longest edge.
Pt? storedRowDirection(Entity? e) {
  final d = e is AreaEntity ? e.rowDirectionDeg : null;
  return d == null || !d.isFinite ? null : Pt.polar(1, degToRad(d));
}

/// The row spacing of the area [e] (m); null when [e] is not an area or
/// has none.
double? storedRowSpacing(Entity? e) => e is AreaEntity && e.rowSpacingM > 0 ? e.rowSpacingM : null;

/// The plant spacing of the area [e] (m); null when not set.
double? storedPlantSpacing(Entity? e) => e is AreaEntity && e.plantSpacingM > 0 ? e.plantSpacingM : null;

/// The area of [p] the polygon [poly] lies in (by its centroid), the
/// smallest when several hold it; null when none.
AreaEntity? areaHolding(Project p, List<Pt> poly) {
  if (poly.length < 3) return null;
  final c = polygonCentroid(poly);
  AreaEntity? best;
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3 || !a.bounds.contains(c) || !pointInPolygon(c, a.points)) continue;
    if (best == null || a.grossArea < best.grossArea) best = a;
  }
  return best;
}

/// Writes what [r] read into [target] and the drawing: the row direction,
/// row spacing and (when read) the plant spacing of an area with [rows]
/// (the defaults of Field blocks, Tree rings and Block for it), its ground
/// cover with [cover] (when read), and with [guides] the rows as lines on
/// the [cropRowLayer] layer (made when missing). The caller wraps it in one
/// undo step. Returns the lines added.
List<Entity> applyCropRows(Project p, Entity target, CropRowResult r, {bool rows = true, bool cover = true, bool guides = false, String name = ''}) {
  if (!r.found) return const [];
  double round(double v, double step) => (v / step).round() * step;
  if (target is AreaEntity) {
    if (rows) {
      target.rowDirectionDeg = round(r.directionDeg, 0.01) % 180;
      target.rowSpacingM = round(r.spacingM, 0.001);
      final ps = r.plantSpacingM;
      if (ps != null) target.plantSpacingM = round(ps, 0.001);
    }
    final gc = r.groundCover;
    if (cover && gc != null) target.groundCover = round(gc, 0.01).clamp(0.01, 1.0).toDouble();
  }
  if (!guides || r.rowLines.isEmpty) return const [];
  if (p.findLayer(cropRowLayer) == null) p.layers.add(Layer(name: cropRowLayer, color: cropRowLayerColor));
  final out = <Entity>[for (final l in r.rowLines) LineEntity(id: p.newId(), layer: cropRowLayer, name: name, a: l[0], b: l[1])];
  p.entities.addAll(out);
  return out;
}

/// A copy of [im] at most [maxSide] pixels a side (box-averaged), for a
/// preview: the pixels, width and height.
(Uint8List, int, int) cropRowPreview(CropRowRaster im, {int maxSide = 720}) {
  final f = math.max(1, (math.max(im.width, im.height) / maxSide).ceil());
  final w = (im.width / f).ceil(), h = (im.height / f).ceil();
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var r = 0, g = 0, b = 0, a = 0, n = 0;
      for (var j = y * f; j < math.min(im.height, (y + 1) * f); j++) {
        for (var i = x * f; i < math.min(im.width, (x + 1) * f); i++) {
          final k = 4 * (j * im.width + i);
          r += im.rgba[k];
          g += im.rgba[k + 1];
          b += im.rgba[k + 2];
          a += im.rgba[k + 3];
          n++;
        }
      }
      final o = 4 * (y * w + x);
      out[o] = r ~/ n;
      out[o + 1] = g ~/ n;
      out[o + 2] = b ~/ n;
      out[o + 3] = a ~/ n;
    }
  }
  return (out, w, h);
}
