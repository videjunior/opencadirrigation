/// Thematic sheets of the terrain (1.6.0 PRD, PRD-30): the slope map by
/// class, or the aspect by compass sector, printed under the drawing (in
/// grey, as context) with its key, the area of each class and, for the
/// slope, the classes of each irrigated area. The cells are the grid of
/// the slope map of the screen, drawn as filled runs of equal class, so the
/// sheet stays vector and sharp at any print size.
library;

import 'dart:math' as math;

import '../design/slope_report.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/slope_map.dart';
import '../translate.dart';
import '../units.dart';
import 'fonts/pdf_fonts.dart';
import 'pdf.dart' show PdfAlign, ptPerMm;
import 'sheet_canvas.dart';
import 'sheet_set.dart' show SheetTheme;

/// The eight compass sectors of the aspect key, from north clockwise.
const aspectSectors = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

/// Below this slope (%) the aspect means little: the cell is "flat".
const _flatPct = 1.0;

/// Colour of the flat cells of the aspect sheet.
const _flatColor = 0xFF9E9E9E;

/// What a thematic sheet maps: the slope map of the terrain and the colour
/// class of each of its cells.
class ThemeMap {
  ThemeMap._(this.theme, this.map, this.classes, this.colors, this.areas);

  /// The map of [theme] for [p]; null without terrain data.
  static ThemeMap? of(Project p, SheetTheme theme) {
    final m = terrainSlopeMap(p);
    if (m.isEmpty) return null;
    final n = m.nx * m.ny;
    final classes = List<int>.filled(n, -1);
    final List<int> colors;
    if (theme == SheetTheme.slope) {
      colors = [for (final c in slopeClasses) c.$2];
      for (var k = 0; k < n; k++) {
        final v = m.slopePct[k];
        if (!v.isNaN) classes[k] = slopeClassOf(v);
      }
    } else {
      // eight sectors of 45° around the compass, then the flat cells
      colors = [for (var s = 0; s < aspectSectors.length; s++) aspectColor(s * 45.0, 10), _flatColor];
      for (var k = 0; k < n; k++) {
        final v = m.slopePct[k], b = m.bearing[k];
        if (v.isNaN) continue;
        classes[k] = v < _flatPct || b.isNaN ? aspectSectors.length : ((b + 22.5) % 360 ~/ 45);
      }
    }
    final areas = List<double>.filled(colors.length, 0);
    final cellArea = m.cell * m.cell;
    for (final c in classes) {
      if (c >= 0) areas[c] += cellArea;
    }
    return ThemeMap._(theme, m, classes, colors, areas);
  }

  final SheetTheme theme;
  final SlopeMap map;

  /// Colour class of each cell (row by row from the bottom), -1 without data.
  final List<int> classes;

  /// Colour (ARGB) of each class: the slope classes, or the eight sectors
  /// and the flat cells.
  final List<int> colors;

  /// Area (m²) of each class.
  final List<double> areas;

  Bounds get bounds => map.bounds;
  double get mappedArea => areas.fold(0.0, (a, b) => a + b);
}

/// Draws the cells of [m] as filled runs of equal class (call inside the
/// clip of the drawing area); [opacity] below 1 over a base map.
void drawThemeCells(SheetCanvas page, ThemeMap m, (double, double) Function(Pt) map, {double opacity = 1}) {
  final s = m.map;
  page.save();
  if (opacity < 1) page.opacity(opacity);
  for (var j = 0; j < s.ny; j++) {
    final y0 = s.origin.y + j * s.cell, y1 = y0 + s.cell;
    var i = 0;
    while (i < s.nx) {
      final c = m.classes[j * s.nx + i];
      if (c < 0) {
        i++;
        continue;
      }
      var end = i + 1;
      while (end < s.nx && m.classes[j * s.nx + end] == c) {
        end++;
      }
      final (ax, ay) = map(Pt(s.origin.x + i * s.cell, y0));
      final (bx, by) = map(Pt(s.origin.x + end * s.cell, y1));
      page.fillColor(m.colors[c]);
      // a hair wider than the cell, so no white seam shows between runs
      page.rect(math.min(ax, bx) - 0.05, math.min(ay, by) - 0.05, (bx - ax).abs() + 0.1, (by - ay).abs() + 0.1, stroke: false, fill: true);
      i = end;
    }
  }
  page.restore();
}

const _ink = 0xFF1A1A1A, _grey = 0xFF8A8F94;

/// The key of a thematic sheet in the side column of the sheet, from [top]
/// (mm, the top of the column) down to no lower than [floor] (mm): the
/// colour of each class with its range (or sector), its area and share;
/// for the slope, the mean and largest slope and then each irrigated area
/// with the share of its classes. [x0] and [width] in mm.
void drawThemeKey(SheetCanvas page, PdfFonts fonts, Translate t, Project p, ThemeMap m, {required double x0, required double top, required double width, required double floor}) {
  double px(double mm) => mm * ptPerMm;
  final u = p.params.units;
  var y = top;
  page.fillColor(_ink);
  page.text(px(x0), px(y), fonts.fit(t(m.theme == SheetTheme.slope ? 'prd.sheet.slopeKey' : 'prd.sheet.aspectKey'), px(width), 9, bold: true), size: 9, bold: true);
  y -= 4.6;
  if (m.theme == SheetTheme.slope) {
    final (mean, max) = m.map.meanMax;
    page.fillColor(_grey);
    page.text(px(x0), px(y), fonts.fit(t('prd.sheet.slopeMeanMax', {'mean': fmt(mean, 1), 'max': fmt(max, 1)}), px(width), 6.5), size: 6.5);
    y -= 4.2;
  }
  // columns: colour, class, area, share
  final areaX = x0 + width * 0.66, shareX = x0 + width;
  page.fillColor(_grey);
  page.text(px(x0 + 6), px(y), t(m.theme == SheetTheme.slope ? 'prd.sheet.class' : 'prd.sheet.sector').toUpperCase(), size: 5.5);
  page.text(px(areaX), px(y), u.areaLabel.toUpperCase(), size: 5.5, align: PdfAlign.right);
  page.text(px(shareX), px(y), '%', size: 5.5, align: PdfAlign.right);
  y -= 3.8;
  final mapped = m.mappedArea;
  for (var k = 0; k < m.colors.length; k++) {
    if (y < floor + 3) return;
    page.fillColor(m.colors[k]);
    page.strokeColor(_grey);
    page.lineWidth(px(0.1));
    page.rect(px(x0), px(y - 0.4), px(4.2), px(2.8), fill: true);
    page.fillColor(_ink);
    final name = m.theme == SheetTheme.slope ? slopeClassLabel(k) : (k < aspectSectors.length ? t('compass.${aspectSectors[k]}') : t('prd.sheet.flat'));
    page.text(px(x0 + 6), px(y), fonts.fit(name, px(areaX - x0 - 18), 7), size: 7);
    page.text(px(areaX), px(y), fmt(u.areaFromSi(m.areas[k]), 2), size: 7, align: PdfAlign.right);
    page.text(px(shareX), px(y), fmt(mapped > 0 ? 100 * m.areas[k] / mapped : 0, 1), size: 7, align: PdfAlign.right);
    y -= 3.9;
  }
  page.strokeColor(_ink);
  page.lineWidth(px(0.2));
  page.line(px(x0), px(y + 2.6), px(shareX), px(y + 2.6));
  page.fillColor(_ink);
  page.text(px(x0 + 6), px(y - 0.4), t('rep.totalRow'), size: 7, bold: true);
  page.text(px(areaX), px(y - 0.4), fmt(u.areaFromSi(mapped), 2), size: 7, bold: true, align: PdfAlign.right);
  y -= 6;
  if (m.theme != SheetTheme.slope) return;
  // each irrigated area: its size and the share of its classes
  final rows = areaSlopeClasses(p, m.map);
  if (rows.isEmpty) return;
  if (y < floor + 8) return;
  page.fillColor(_ink);
  page.text(px(x0), px(y), fonts.fit(t('prd.sheet.byArea'), px(width), 7.5, bold: true), size: 7.5, bold: true);
  y -= 4;
  for (final (a, s) in rows) {
    final parts = <String>[
      for (var k = 0; k < slopeClasses.length; k++)
        if (s.share(k) >= 0.005) '${slopeClassLabel(k)}: ${fmt(100 * s.share(k), 0)} %',
    ];
    final head = '${a.name.isEmpty ? t('tool.area') : a.name} (${fmt(u.areaFromSi(a.area), 2)} ${u.areaLabel})';
    final lines = [head, ..._wrap(fonts, parts.join(' · '), px(width - 2), 6)];
    if (y - lines.length * 3.1 < floor + 2) {
      page.fillColor(_grey);
      page.text(px(x0), px(y), fonts.fit(t('prd.sheet.seeReport'), px(width), 6), size: 6);
      return;
    }
    for (var i = 0; i < lines.length; i++) {
      page.fillColor(i == 0 ? _ink : _grey);
      page.text(px(x0 + (i == 0 ? 0 : 2)), px(y), i == 0 ? fonts.fit(lines[i], px(width), 6.5, bold: true) : lines[i], size: i == 0 ? 6.5 : 6, bold: i == 0);
      y -= 3.1;
    }
    y -= 1;
  }
}

List<String> _wrap(PdfFonts fonts, String s, double width, double size) {
  final lines = <String>[];
  var cur = '';
  for (final w in s.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final cand = cur.isEmpty ? w : '$cur $w';
    if (fonts.textWidth(cand, size) <= width + 0.01) {
      cur = cand;
    } else {
      if (cur.isNotEmpty) lines.add(cur);
      cur = fonts.textWidth(w, size) <= width ? w : fonts.fit(w, width, size);
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines;
}
