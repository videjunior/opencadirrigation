/// The design scorecard (1.7.0 SCR, `design/scorecard.dart`) as a chart of
/// the PDF sheets and documents: a radar of the category scores on the
/// rings of the grade limits (60, 70, 80, 90 and 100), the categories not
/// assessed drawn dashed and left out of the polygon, and beside it the
/// overall score and every category with its score and grade.
library;

import 'dart:math' as math;

import '../design/results.dart';
import '../design/scorecard.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'plot.dart';
import 'plot_charts.dart' show PlotChart, hglColor, pipeColor;

const _ink = 0xFF1A1A1A;
const _grid = 0xFFD5DBE1;
const _muted = 0xFF8A949E;
const _fill = 0xFFBBDEFB;
const _bad = 0xFFC62828;

/// The radar chart of the scorecard of [p] with results [r]; the scorecard
/// is computed when the chart is drawn (or given as [scorecard]).
PlotChart scorecardChart(Project p, DesignResults r, {required Translate t, DesignScorecard? scorecard}) {
  DesignScorecard? s = scorecard;
  return PlotChart(title: t('scr.title'))..draw = (w, h) => scorecardRadarScene(s ??= designScorecard(p, r), t: t, widthMm: w, heightMm: h);
}

/// The radar of [s] laid out in [widthMm] × [heightMm] (paper millimetres,
/// origin at the bottom left), as `chartScene` lays out the other charts.
PlotScene scorecardRadarScene(DesignScorecard s, {required Translate t, required double widthMm, required double heightMm}) {
  const layer = 'CHART';
  final items = <PlotItem>[];
  void path(List<Pt> pts, {int color = _ink, double w = 0.25, bool dashed = false, int? fill, bool closed = false, double opacity = 1}) {
    if (pts.length < 2) return;
    items.add(PlotPath(layer: layer, color: color, points: pts, closed: closed, widthMm: w, dashed: dashed, fillColor: fill, fillOpacity: opacity));
  }

  void text(Pt at, String v, {double h = 2.0, PlotAnchor anchor = PlotAnchor.bottomLeft, bool bold = false, int color = _ink}) {
    if (v.isEmpty) return;
    items.add(PlotText(layer: layer, color: color, position: at, text: v, heightMm: h, anchor: anchor, bold: bold));
  }

  final o = s.overall;
  text(Pt(0, heightMm - 4.2), '${t('scr.title')} — ${t('scr.overall')} ${o == null ? '-' : '${fmt(o, 1)} (${s.grade})'}', h: 2.8, bold: true);
  final top = 8.0, bottom = 6.0;
  final r = math.max(4.0, math.min((heightMm - top - bottom) / 2 - 3, widthMm / 6));
  final c = Pt(r + 26, bottom + 3 + r);
  final n = s.categories.length;
  Pt at(int i, double score) {
    final a = math.pi / 2 - 2 * math.pi * i / n;
    return c + Pt(math.cos(a), math.sin(a)) * (r * score.clamp(0, 100) / 100);
  }

  // the rings of the grade limits, the spokes and their labels
  for (final ring in const [60.0, 70.0, 80.0, 90.0, 100.0]) {
    path([for (var i = 0; i < n; i++) at(i, ring)], closed: true, color: ring == 100 ? _muted : _grid, w: ring == 100 ? 0.25 : 0.15);
  }
  for (final ring in const [60.0, 80.0, 100.0]) {
    text(at(0, ring) + const Pt(0.8, 0.2), fmt(ring, 0), h: 1.5, color: _muted);
  }
  for (var i = 0; i < n; i++) {
    final cat = s.categories[i];
    final assessed = cat.score != null;
    path([c, at(i, 100)], color: assessed ? _muted : _grid, w: 0.15, dashed: !assessed);
    final q = at(i, 100), dx = q.x - c.x, dy = q.y - c.y;
    final anchor = dx.abs() < r * 0.2 ? PlotAnchor.bottomCenter : (dx > 0 ? PlotAnchor.bottomLeft : PlotAnchor.bottomRight);
    final label = '${t('scr.c.${cat.category.name}')} ${assessed ? fmt(cat.score!, 0) : '-'}';
    text(q + Pt(dx.sign * 1.2, dy >= 0 ? 0.9 : -2.6), label, h: 1.8, anchor: anchor, color: assessed ? _ink : _muted);
  }
  // the polygon of the assessed categories
  final pts = [
    for (var i = 0; i < n; i++)
      if (s.categories[i].score != null) at(i, s.categories[i].score!),
  ];
  if (pts.length >= 3) {
    path(pts, closed: true, color: pipeColor, w: 0.45, fill: _fill, opacity: 0.6);
  } else {
    path(pts, color: pipeColor, w: 0.45);
  }
  for (var i = 0; i < n; i++) {
    final sc = s.categories[i].score;
    if (sc != null) items.add(PlotCircle(layer: layer, color: sc < 60 ? _bad : hglColor, center: at(i, sc), radius: 0.7, widthMm: 0.2, fillColor: sc < 60 ? _bad : hglColor, stroke: false));
  }
  // the list beside it
  var x = c.x + r + 34, y = heightMm - top - 3;
  if (x < widthMm - 40) {
    text(Pt(x, y), '${t('scr.overall')}: ${o == null ? '-' : '${fmt(o, 1)} / 100 (${s.grade})'}', h: 2.2, bold: true);
    y -= 4.2;
    text(Pt(x, y), t('scr.assessed', {'k': '${s.assessed.length}', 'n': '${s.categories.length}'}), h: 1.8, color: _muted);
    y -= 4.4;
    for (final cat in s.categories) {
      if (y < bottom) break;
      final sc = cat.score;
      text(Pt(x, y), t('scr.c.${cat.category.name}'), h: 1.9, color: sc == null ? _muted : _ink);
      text(Pt(x + 44, y), sc == null ? t('scr.na.none') : '${fmt(sc, 0)}  ${cat.grade}', h: 1.9, color: sc == null ? _muted : (sc < 60 ? _bad : _ink), bold: sc != null);
      y -= 3.6;
    }
    // the first improvements
    final imp = s.improvements.take(3).toList();
    if (imp.isNotEmpty && x + 90 < widthMm - 30) {
      var y2 = heightMm - top - 3;
      final x2 = x + 70;
      text(Pt(x2, y2), t('scr.improvements'), h: 2.0, bold: true);
      y2 -= 4.2;
      for (final (i, g) in imp) {
        text(Pt(x2, y2), '+${fmt(g, 1)}  ${t('scr.i.${i.key}')}', h: 1.8);
        y2 -= 3.6;
      }
    }
  }
  return PlotScene(items: items, bounds: Bounds(0, 0, widthMm, heightMm), unitsPerMm: 1, layers: const {});
}
