/// Coordinate grids of the drawing sheets (1.6.0 PRD): the UTM grid of the
/// project's zone, whose lines are straight because the drawing is in that
/// grid (local x, y = easting, northing minus the origin of the
/// georeference), and the geographic graticule, whose parallels and
/// meridians are slightly curved and turned by the grid convergence. The
/// values are written inside the drawing area along its edges: eastings at
/// the bottom, northings on the left, longitudes at the top, latitudes on
/// the right, each on a white box and left out where it would cover the
/// north arrow, the scale bar or another mark of the sheet. Without a
/// georeference the "UTM" grid is the local grid (X, Y in metres).
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import '../translate.dart';
import '../units.dart';
import 'fonts/pdf_fonts.dart';
import 'geo.dart';
import 'pdf.dart' show PdfAlign, ptPerMm;
import 'sheet_canvas.dart';

/// The coordinate grid a drawing sheet prints.
enum SheetGrid {
  none,
  utm,
  geographic,
  both;

  bool get hasUtm => this == utm || this == both;
  bool get hasGeographic => this == geographic || this == both;
}

/// Grid steps (m) offered for the UTM grid.
const _metreSteps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000, 20000, 25000, 50000, 100000];

/// Graticule steps (arc seconds).
const _secondSteps = [1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600, 900, 1200, 1800, 3600, 7200, 18000, 36000];

/// Least distance (mm on paper) between two lines of a grid.
const gridMinSpacingMm = 35.0;

/// Most lines of one direction a grid draws.
const _maxLines = 60;

/// Spacing (m) of the UTM grid of a sheet at [unitsPerMm] (world metres per
/// paper millimetre): the first round step at least [minMm] apart on paper.
double utmGridStep(double unitsPerMm, {double minMm = gridMinSpacingMm}) {
  final need = unitsPerMm * minMm;
  for (final s in _metreSteps) {
    if (s >= need) return s.toDouble();
  }
  return (need / 100000).ceil() * 100000.0;
}

/// Spacing (arc seconds) of the graticule of a sheet at [unitsPerMm] near
/// latitude [lat]: the first round step whose parallels are at least
/// [minMm] apart on paper (a second of latitude is about 30.9 m).
int graticuleStepSeconds(double unitsPerMm, {double minMm = gridMinSpacingMm}) {
  final need = unitsPerMm * minMm / 30.87;
  for (final s in _secondSteps) {
    if (s >= need) return s;
  }
  return _secondSteps.last;
}

/// What a grid line is.
enum GridLineKind { easting, northing, meridian, parallel }

/// A line of a grid in world coordinates (m) and the value it carries.
class GridLine {
  const GridLine(this.kind, this.points, this.value, this.label);
  final GridLineKind kind;
  final List<Pt> points;

  /// Easting or northing (m), or longitude or latitude (degrees).
  final double value;
  final String label;
}

/// The lines of the UTM grid of step [step] (m) over the world rectangle
/// [view]: eastings and northings of [g]'s zone, or local X and Y without a
/// georeference.
List<GridLine> utmGridLines(GeoReference? g, Bounds view, double step) {
  if (view.isEmpty || !(step > 0)) return const [];
  final e0 = g?.originEasting ?? 0.0, n0 = g?.originNorthing ?? 0.0;
  final out = <GridLine>[];
  final eFirst = ((view.minX + e0) / step).ceil(), eLast = ((view.maxX + e0) / step).floor();
  final nFirst = ((view.minY + n0) / step).ceil(), nLast = ((view.maxY + n0) / step).floor();
  if (eLast - eFirst > _maxLines || nLast - nFirst > _maxLines) return const [];
  for (var k = eFirst; k <= eLast; k++) {
    final e = k * step, x = e - e0;
    out.add(GridLine(GridLineKind.easting, [Pt(x, view.minY), Pt(x, view.maxY)], e, g == null ? 'X ${fmt(e, 0)}' : 'E ${fmt(e, 0)}'));
  }
  for (var k = nFirst; k <= nLast; k++) {
    final n = k * step, y = n - n0;
    out.add(GridLine(GridLineKind.northing, [Pt(view.minX, y), Pt(view.maxX, y)], n, g == null ? 'Y ${fmt(n, 0)}' : 'N ${fmt(n, 0)}'));
  }
  return out;
}

/// The parallels and meridians of step [stepSeconds] (arc seconds) over the
/// world rectangle [view] of a project georeferenced by [g], each a
/// polyline sampled finely enough to show its curvature; [label] writes a
/// value (degrees; latitude when [latitude]).
List<GridLine> graticuleLines(GeoReference g, Bounds view, int stepSeconds, {required String Function(double degrees, bool latitude) label}) {
  if (view.isEmpty || stepSeconds <= 0) return const [];
  // the latitude and longitude range of the view (its corners and the
  // middle of its edges: the graticule turns, so the corners alone may miss)
  var latMin = double.infinity, latMax = -double.infinity, lonMin = double.infinity, lonMax = -double.infinity;
  for (final fx in const [0.0, 0.5, 1.0]) {
    for (final fy in const [0.0, 0.5, 1.0]) {
      final (lat, lon) = g.toLatLon(view.minX + fx * view.width, view.minY + fy * view.height);
      latMin = math.min(latMin, lat);
      latMax = math.max(latMax, lat);
      lonMin = math.min(lonMin, lon);
      lonMax = math.max(lonMax, lon);
    }
  }
  if (!latMin.isFinite || !lonMin.isFinite) return const [];
  final step = stepSeconds / 3600.0;
  // a little beyond the view, so the lines cross its edges
  final padLat = (latMax - latMin) * 0.05 + step * 0.01, padLon = (lonMax - lonMin) * 0.05 + step * 0.01;
  latMin -= padLat;
  latMax += padLat;
  lonMin -= padLon;
  lonMax += padLon;
  final out = <GridLine>[];
  const samples = 24;
  final lonFirst = (lonMin / step).ceil(), lonLast = (lonMax / step).floor();
  final latFirst = (latMin / step).ceil(), latLast = (latMax / step).floor();
  if (lonLast - lonFirst > _maxLines || latLast - latFirst > _maxLines) return const [];
  Pt local(double lat, double lon) {
    final (x, y) = g.fromLatLon(lat, lon);
    return Pt(x, y);
  }

  for (var k = lonFirst; k <= lonLast; k++) {
    final lon = k * step;
    out.add(GridLine(GridLineKind.meridian, [for (var i = 0; i <= samples; i++) local(latMin + (latMax - latMin) * i / samples, lon)], lon, label(lon, false)));
  }
  for (var k = latFirst; k <= latLast; k++) {
    final lat = k * step;
    out.add(GridLine(GridLineKind.parallel, [for (var i = 0; i <= samples; i++) local(lat, lonMin + (lonMax - lonMin) * i / samples)], lat, label(lat, true)));
  }
  return out;
}

/// [degrees] in degrees, minutes and seconds with the hemisphere letter of
/// [t] (`prd.grid.n` …): seconds only when [stepSeconds] is under a minute,
/// minutes only when it is under a degree ("15°47'30"S", "47°55'W", "16°S").
String dmsText(double degrees, {required bool latitude, required int stepSeconds, Translate? t}) {
  final total = (degrees.abs() * 3600).round();
  final d = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  final hemi = latitude ? (degrees < 0 ? 's' : 'n') : (degrees < 0 ? 'w' : 'e');
  final letter = t?.call('prd.grid.$hemi') ?? hemi.toUpperCase();
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  if (stepSeconds < 60) return '$d°$mm\'$ss"$letter';
  if (stepSeconds < 3600) return '$d°$mm\'$letter';
  return '$d°$letter';
}

/// Size (pt) of the values of a grid; the capitals stay above the least
/// size a sheet check asks of the drawing's texts (1.6 mm).
const gridLabelPt = 6.6;

const _utmLine = 0xFF6E8CA8, _utmText = 0xFF2F4F6F;
const _geoLine = 0xFFA0825A, _geoText = 0xFF5C4325;

/// Draws [grid] over the drawing area of a sheet (call inside its clip):
/// [view] is the world rectangle the area shows, [area] the area on paper
/// (pt), [map] world → paper (pt); labels whose box meets one of [avoid]
/// (paper boxes, pt) are left out. Returns the steps drawn (m and arc
/// seconds; 0 where none).
(double, int) drawSheetGrid(
  SheetCanvas page,
  PdfFonts fonts, {
  required SheetGrid grid,
  required GeoReference? georef,
  required Bounds view,
  required Bounds area,
  required double unitsPerMm,
  required (double, double) Function(Pt) map,
  List<Bounds> avoid = const [],
  Translate? t,
}) {
  if (grid == SheetGrid.none || view.isEmpty) return (0, 0);
  final placed = <Bounds>[...avoid];
  final edge = 1.0 * ptPerMm;
  const size = gridLabelPt;
  final ascent = 0.75 * size, descent = 0.2 * size;
  // a label (horizontal, or turned 90° counter-clockwise) where it fits
  void label(String s, double x, double y, int color, {bool turned = false}) {
    final w = fonts.textWidth(s, size);
    // the box of the text with a margin of half a millimetre
    final pad = 0.5 * ptPerMm;
    final box = turned ? Bounds(x - ascent - pad, y - w / 2 - pad, x + descent + pad, y + w / 2 + pad) : Bounds(x - w / 2 - pad, y - descent - pad, x + w / 2 + pad, y + ascent + pad);
    if (box.minX < area.minX || box.maxX > area.maxX || box.minY < area.minY || box.maxY > area.maxY) return;
    for (final b in placed) {
      if (b.intersects(box)) return;
    }
    placed.add(box);
    page.save();
    page.opacity(0.85);
    page.fillColor(0xFFFFFFFF);
    page.rect(box.minX, box.minY, box.width, box.height, stroke: false, fill: true);
    page.restore();
    page.fillColor(color);
    page.text(x, y, s, size: size, align: PdfAlign.center, rotationDeg: turned ? 90 : 0);
  }

  void lines(List<GridLine> ls, int color, {bool dashed = false}) {
    page.strokeColor(color);
    page.lineWidth(0.12 * ptPerMm);
    page.dash(dashed, 1.2 * ptPerMm, 0.8 * ptPerMm);
    for (final l in ls) {
      page.path([for (final p in l.points) map(p)]);
    }
    page.dash(false);
  }

  var metres = 0.0;
  var seconds = 0;
  final utm = grid.hasUtm ? utmGridLines(georef, view, metres = utmGridStep(unitsPerMm)) : const <GridLine>[];
  final geo = grid.hasGeographic && georef != null
      ? graticuleLines(georef, view, seconds = graticuleStepSeconds(unitsPerMm), label: (v, lat) => dmsText(v, latitude: lat, stepSeconds: seconds, t: t))
      : const <GridLine>[];
  if (geo.isEmpty) seconds = 0;
  if (utm.isEmpty) metres = 0;
  lines(utm, _utmLine);
  lines(geo, _geoLine, dashed: true);
  // values: eastings at the bottom, northings on the left
  for (final l in utm) {
    final (x, y) = map(l.points.first);
    if (l.kind == GridLineKind.easting) {
      label(l.label, x, area.minY + edge + descent, _utmText);
    } else {
      label(l.label, area.minX + edge + ascent, y, _utmText, turned: true);
    }
  }
  // longitudes at the top, latitudes on the right, where each line crosses that edge
  for (final l in geo) {
    final pts = [for (final p in l.points) map(p)];
    if (l.kind == GridLineKind.meridian) {
      final x = _crossing(pts, area.maxY, horizontal: true);
      if (x != null) label(l.label, x, area.maxY - edge - ascent, _geoText);
    } else {
      final y = _crossing(pts, area.maxX, horizontal: false);
      if (y != null) label(l.label, area.maxX - edge - descent, y, _geoText, turned: true);
    }
  }
  return (metres, seconds);
}

/// Where the paper polyline [pts] crosses the line y = [at] ([horizontal])
/// or x = [at]: the other coordinate, or null.
double? _crossing(List<(double, double)> pts, double at, {required bool horizontal}) {
  for (var i = 1; i < pts.length; i++) {
    final (ax, ay) = pts[i - 1];
    final (bx, by) = pts[i];
    final a = horizontal ? ay : ax, b = horizontal ? by : bx;
    if ((a - at) * (b - at) > 0 || a == b) continue;
    final f = (at - a) / (b - a);
    return horizontal ? ax + (bx - ax) * f : ay + (by - ay) * f;
  }
  return null;
}
