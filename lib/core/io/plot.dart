/// Device-independent plot of a project ("paper space" scene).
///
/// Geometry is kept in world metres; pen widths, symbol sizes and text
/// heights are expressed in paper millimetres so that a sheet plotted at
/// 1:500 and one at 1:2000 both stay legible (annotation scaling, as CAD
/// packages do). Writers (PDF, SVG) only have to map metres to paper units.
library;

import 'dart:math' as math;

import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';

enum PlotAnchor { bottomLeft, bottomCenter, bottomRight, center, centerLeft }

sealed class PlotItem {
  PlotItem({required this.layer, required this.color});

  /// Layer name (for legends and SVG groups).
  final String layer;

  /// Opaque print colour (0xFFRRGGBB).
  final int color;
}

class PlotPath extends PlotItem {
  PlotPath({required super.layer, required super.color, required this.points, this.closed = false, this.widthMm = 0.25, this.dashed = false, this.fillColor});
  final List<Pt> points;
  final bool closed;
  final double widthMm;
  final bool dashed;

  /// Opaque fill colour (already blended over white) or null.
  final int? fillColor;
}

class PlotCircle extends PlotItem {
  PlotCircle({required super.layer, required super.color, required this.center, required this.radius, this.widthMm = 0.25, this.fillColor, this.stroke = true});
  final Pt center;

  /// Radius in world metres.
  final double radius;
  final double widthMm;
  final int? fillColor;
  final bool stroke;
}

class PlotText extends PlotItem {
  PlotText({required super.layer, required super.color, required this.position, required this.text, required this.heightMm, this.rotationDeg = 0, this.bold = false, this.anchor = PlotAnchor.bottomLeft});
  final Pt position;
  final String text;

  /// Cap height on paper, in millimetres.
  final double heightMm;
  final double rotationDeg;
  final bool bold;
  final PlotAnchor anchor;
}

class PlotScene {
  PlotScene({required this.items, required this.bounds, required this.unitsPerMm, required this.layers});
  final List<PlotItem> items;

  /// World extent of the plotted geometry.
  final Bounds bounds;

  /// World metres per paper millimetre (scale 1:N → N / 1000).
  final double unitsPerMm;

  /// Layers that received at least one item, in drawing order, with colour.
  final Map<String, int> layers;

  double get scaleDenominator => unitsPerMm * 1000;
}

class PlotOptions {
  const PlotOptions({this.wettedRadii = true, this.labels = true, this.results = true, this.textHeightMm = 2.5, this.labelHeightMm = 1.8});
  final bool wettedRadii;
  final bool labels;

  /// Annotate valves, supplies and pipes with design results when present.
  final bool results;
  final double textHeightMm;
  final double labelHeightMm;
}

/// Converts a screen (dark theme) layer colour to a colour that prints well
/// on white paper: very light colours are darkened, hue is preserved.
int printColor(int argb) {
  var r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  if (lum > 0.5) {
    final f = 0.38 / lum;
    r = (r * f).round();
    g = (g * f).round();
    b = (b * f).round();
  }
  return 0xFF000000 | (r << 16) | (g << 8) | b;
}

/// Blends an ARGB colour over white using its alpha, returning an opaque colour.
int blendOverWhite(int argb, [double? alphaOverride]) {
  final a = alphaOverride ?? ((argb >> 24) & 0xFF) / 255;
  int mix(int c) => (255 + (c - 255) * a).round().clamp(0, 255);
  return 0xFF000000 | (mix((argb >> 16) & 0xFF) << 16) | (mix((argb >> 8) & 0xFF) << 8) | mix(argb & 0xFF);
}

/// "Nice" plot scale denominators (1:50 … 1:100000).
const plotScales = [50, 100, 200, 250, 500, 750, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 7500, 10000, 15000, 20000, 25000, 50000, 100000];

/// Smallest nice scale so that [bounds] fits in [widthMm] × [heightMm].
double fitScale(Bounds bounds, double widthMm, double heightMm) {
  if (bounds.isEmpty || widthMm <= 0 || heightMm <= 0) return 1000;
  final need = math.max(bounds.width / widthMm, bounds.height / heightMm) * 1000; // denominator needed
  for (final s in plotScales) {
    if (s >= need) return s.toDouble();
  }
  return (need / 1000).ceil() * 1000.0;
}

/// A "round" length (m) for a scale bar close to [targetMm] on paper.
double niceBarLength(double unitsPerMm, double targetMm) {
  final target = targetMm * unitsPerMm;
  const steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000];
  var best = steps.first.toDouble();
  for (final s in steps) {
    if ((s - target).abs() < (best - target).abs()) best = s.toDouble();
  }
  return best;
}

/// Builds the plot scene of [project] at the given annotation scale.
PlotScene buildPlotScene(
  Project project, {
  DesignResults? results,
  required double unitsPerMm,
  PlotOptions options = const PlotOptions(),
  Units units = Units.metric,
  Translate? t,
}) {
  final items = <PlotItem>[];
  final layersUsed = <String, int>{};
  final mm = unitsPerMm; // world metres per paper mm
  final labelH = options.labelHeightMm;
  final pipeRes = options.results ? results?.pipesByEntity ?? const <String, List<PipeSegmentResult>>{} : const <String, List<PipeSegmentResult>>{};
  final visible = {for (final l in project.layers) l.name: l.visible};
  bool shown(String layer) => visible[layer] ?? true;
  int colorOf(String layer) => printColor(project.layerNamed(layer).color);
  String tr(String key, [Map<String, String>? args]) => t?.call(key, args) ?? key;

  void use(String layer) {
    if (!layersUsed.containsKey(layer)) layersUsed[layer] = colorOf(layer);
  }

  void path(String layer, List<Pt> pts, {bool closed = false, double widthMm = 0.25, bool dashed = false, int? fill, int? color}) {
    if (pts.isEmpty) return;
    use(layer);
    items.add(PlotPath(layer: layer, color: color ?? colorOf(layer), points: pts, closed: closed, widthMm: widthMm, dashed: dashed, fillColor: fill));
  }

  void circle(String layer, Pt c, double r, {double widthMm = 0.25, int? fill, bool stroke = true, int? color}) {
    use(layer);
    items.add(PlotCircle(layer: layer, color: color ?? colorOf(layer), center: c, radius: r, widthMm: widthMm, fillColor: fill, stroke: stroke));
  }

  void text(String layer, Pt p, String s, {double? heightMm, double rotation = 0, bool bold = false, PlotAnchor anchor = PlotAnchor.bottomLeft, int? color}) {
    if (s.isEmpty) return;
    use(layer);
    items.add(PlotText(layer: layer, color: color ?? colorOf(layer), position: p, text: s, heightMm: heightMm ?? labelH, rotationDeg: rotation, bold: bold, anchor: anchor));
  }

  /// Regular polygon / sector helper (world coordinates).
  List<Pt> arcPoints(Pt c, double r, double startRad, double sweepRad, [int segments = 32]) {
    final n = math.max(4, (segments * sweepRad.abs() / (2 * math.pi)).ceil());
    return [for (var i = 0; i <= n; i++) c + Pt.polar(r, startRad + sweepRad * i / n)];
  }

  // pass 1: areas (fills under everything else)
  for (final e in project.entities.whereType<AreaEntity>()) {
    if (!shown(e.layer) || e.points.length < 3) continue;
    final base = project.layerNamed(e.layer).color;
    path(e.layer, e.points, closed: true, widthMm: 0.25, fill: blendOverWhite(printColor(base), 0.18));
    if (options.labels) {
      // top-left corner inside the polygon, clear of the valve/laterals
      final b = Bounds.ofPoints(e.points);
      text(e.layer, Pt(b.minX + 1.5 * mm, b.maxY - (1.5 + labelH) * mm), '${e.name}  ${fmt(e.area / 10000, 2)} ha', heightMm: labelH, bold: true);
    }
  }
  // pass 2: drawing, terrain, linear hydraulics
  for (final e in project.entities) {
    if (e is AreaEntity || !shown(e.layer)) continue;
    switch (e) {
      case LineEntity l:
        path(l.layer, [l.a, l.b]);
      case PolylineEntity p:
        path(p.layer, p.points, closed: p.closed);
      case CircleEntity c:
        circle(c.layer, c.center, c.radius);
      case ArcEntity a:
        path(a.layer, arcPoints(a.center, a.radius, a.startRad, a.sweepRad));
      case SplineEntity sp:
        path(sp.layer, sp.curve(), closed: sp.closed);
      case HatchEntity h:
        if (h.solid) {
          path(h.layer, h.points, closed: true, widthMm: 0.18, fill: blendOverWhite(colorOf(h.layer), 0.35));
        } else {
          path(h.layer, h.points, closed: true, widthMm: 0.18);
          if (h.spacing / mm >= 0.6) {
            for (final l in h.patternLines()) {
              path(h.layer, l, widthMm: 0.13);
            }
          } else {
            path(h.layer, h.points, closed: true, widthMm: 0.18, fill: blendOverWhite(colorOf(h.layer), 0.2));
          }
        }
      case SymbolEntity sy:
        for (final st in sy.strokes()) {
          path(sy.layer, st, widthMm: 0.3);
        }
      case AngularDimensionEntity ad:
        path(ad.layer, [ad.a, ad.vertex, ad.b], widthMm: 0.18);
        path(ad.layer, ad.arcPoints(), widthMm: 0.18);
        text(ad.layer, ad.textPoint, '${fmt(ad.angleDeg, 1)}°', heightMm: labelH, anchor: PlotAnchor.center);
      case RadialDimensionEntity rd:
        path(rd.layer, [rd.start, rd.point], widthMm: 0.18);
        text(rd.layer, rd.diameter ? rd.center : Pt.lerp(rd.center, rd.point, 0.5), '${rd.diameter ? 'Ø' : 'R'} ${fmt(units.lengthFromSi(rd.value))} ${units.lengthLabel}', heightMm: labelH, anchor: PlotAnchor.bottomCenter);
      case OrdinateDimensionEntity od:
        path(od.layer, od.leader, widthMm: 0.18);
        text(od.layer, od.leaderEnd, '${od.xAxis ? 'X' : 'Y'} ${fmt(units.lengthFromSi(od.value))}', heightMm: labelH, anchor: od.xAxis ? PlotAnchor.bottomCenter : PlotAnchor.center);
      case WireEntity w:
        path(w.layer, w.points, widthMm: 0.25, dashed: true);
      case LeaderEntity le:
        path(le.layer, le.points, widthMm: 0.18);
        if (le.points.length >= 2) {
          final tip = le.points.first, from = le.points[1];
          final u = (tip - from).normalized;
          final n = u.perpendicular;
          path(le.layer, [tip, tip - u * (1.5 * mm) + n * (0.6 * mm), tip - u * (1.5 * mm) - n * (0.6 * mm)], closed: true, widthMm: 0.18, fill: colorOf(le.layer));
        }
        text(le.layer, le.textPosition + Pt(0.3 * le.height, 0), le.text, heightMm: le.height / mm);
      case ImageEntity im:
        path(im.layer, im.corners, closed: true, widthMm: 0.13);
      case TextEntity tx:
        text(tx.layer, tx.position, tx.text, heightMm: tx.height / mm, rotation: tx.rotationDeg);
      case DimensionEntity d:
        final n = d.normal * d.offset;
        path(d.layer, [d.a, d.a + n], widthMm: 0.18);
        path(d.layer, [d.b, d.b + n], widthMm: 0.18);
        path(d.layer, [d.a + n, d.b + n], widthMm: 0.18);
        final mid = Pt.lerp(d.a, d.b, 0.5) + n + n.normalized * (0.6 * labelH * mm);
        text(d.layer, mid, '${fmt(units.lengthFromSi(d.length))} ${units.lengthLabel}', heightMm: labelH, rotation: radToDeg((d.b - d.a).angle), anchor: PlotAnchor.bottomCenter);
      case ContourEntity ct:
        path(ct.layer, ct.points, widthMm: 0.2);
        if (options.labels && ct.points.isNotEmpty) text(ct.layer, ct.points.first, fmt(ct.elevation, 1), heightMm: labelH * 0.9);
      case SpotHeightEntity s:
        final a = 0.75 * mm;
        path(s.layer, [s.position + Pt(-a, 0), s.position + Pt(a, 0)], widthMm: 0.18);
        path(s.layer, [s.position + Pt(0, -a), s.position + Pt(0, a)], widthMm: 0.18);
        if (options.labels) text(s.layer, s.position + Pt(a * 1.2, a * 0.3), fmt(s.elevation, 1), heightMm: labelH * 0.9);
      case PipeEntity p:
        path(p.layer, p.points, widthMm: p.scope == HydraulicScope.mainline ? 0.7 : 0.5);
        final res = pipeRes[p.id];
        if (options.labels && p.points.length >= 2) {
          final spec = project.catalog.pipe(p.pipeSpecId);
          var label = spec?.name ?? '';
          if (res != null && res.isNotEmpty) {
            final r = res.reduce((a, b) => a.flow.abs() >= b.flow.abs() ? a : b);
            label = '${label.isEmpty ? '' : '$label  '}${fmt(units.flowFromSi(r.flow.abs()), 1)} ${units.flowLabel}';
          }
          if (label.isNotEmpty) {
            final total = polylineLength(p.points);
            if (total > 2 * labelH * mm * label.length * 0.45) {
              final mid = pointAlongPolyline(p.points, total / 2);
              final seg = _segmentAt(p.points, total / 2);
              var ang = radToDeg((seg.$2 - seg.$1).angle);
              if (ang > 90 || ang < -90) ang += 180;
              final normal = (seg.$2 - seg.$1).normalized.perpendicular;
              final flip = (ang - radToDeg((seg.$2 - seg.$1).angle)).abs() > 1;
              text(Layers.labels, mid + normal * (flip ? -1 : 1) * 0.5 * mm, label, heightMm: labelH, rotation: ang, anchor: PlotAnchor.bottomCenter);
            }
          }
        }
      case SpraylineEntity s:
        path(s.layer, s.points, widthMm: 0.35);
        if (shown(Layers.outlets)) {
          final nozzle = project.catalog.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
          final radius = nozzle?.curve.radius(s.headM) ?? 0;
          final showR = options.wettedRadii && radius > 0 && shown(Layers.wettedRadii);
          final outletColor = colorOf(Layers.outlets);
          for (final o in s.outletPositions()) {
            circle(Layers.outlets, o, 0.4 * mm, fill: outletColor, stroke: false);
            if (showR) circle(Layers.wettedRadii, o, radius, widthMm: 0.13);
          }
        }
      case TapeEntity tp:
        path(tp.layer, tp.points, widthMm: 0.35, dashed: true);
      case PivotEntity pv:
        path(pv.layer, pv.outline(), closed: true, widthMm: 0.25, fill: blendOverWhite(colorOf(pv.layer), 0.08));
        path(pv.layer, [pv.center, pv.endPoint], widthMm: 0.6);
        for (final tw in pv.towerPositions()) {
          final a = 0.8 * mm;
          path(pv.layer, [tw + Pt(-a, -a), tw + Pt(a, -a), tw + Pt(a, a), tw + Pt(-a, a)], closed: true, widthMm: 0.2, fill: colorOf(pv.layer));
        }
        circle(pv.layer, pv.center, 1.2 * mm, widthMm: 0.3, fill: colorOf(pv.layer));
        if (options.labels) {
          var s = pv.name;
          final r = options.results ? results?.pivots[pv.id] : null;
          if (r != null) s += '  ${fmt(units.flowFromSi(r.flow), 1)} ${units.flowLabel} / ${fmt(units.pressureFromHead(r.inletHead), 1)} ${units.pressureLabel}';
          text(Layers.labels, pv.center + Pt(1.6 * mm, 1.2 * mm), s, heightMm: labelH, bold: true);
        }
      default:
        break;
    }
  }
  // pass 3: point hydraulics (symbols sized in paper mm)
  for (final e in project.entities) {
    if (e is! PointEntity || !shown(e.layer)) continue;
    final p = e.position;
    switch (e) {
      case OutletEntity o:
        final nozzle = project.catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
        final radius = nozzle?.curve.radius(o.headM) ?? 0;
        if (options.wettedRadii && radius > 0 && shown(Layers.wettedRadii)) {
          final arc = nozzle!.effectiveArcDeg(o.arcDeg);
          if (arc >= 360) {
            circle(Layers.wettedRadii, p, radius, widthMm: 0.13, fill: blendOverWhite(colorOf(Layers.wettedRadii), 0.08));
          } else {
            // counter-clockwise from the orientation, as on the screen
            final start = degToRad(o.orientationDeg);
            path(Layers.wettedRadii, [p, ...arcPoints(p, radius, start, degToRad(arc))], closed: true, widthMm: 0.13, fill: blendOverWhite(colorOf(Layers.wettedRadii), 0.08));
          }
        }
        circle(o.layer, p, 0.6 * mm, fill: colorOf(o.layer), stroke: false);
      case ControlValveEntity v:
        final r = 1.5 * mm;
        path(v.layer, [p + Pt(-r, -r * 0.7), p + Pt(r, r * 0.7), p + Pt(r, -r * 0.7), p + Pt(-r, r * 0.7)], closed: true, widthMm: 0.3, fill: colorOf(v.layer));
        if (options.labels) {
          var s = v.zoneName;
          final z = options.results ? results?.zones[v.id] : null;
          if (z != null) s += '  ${fmt(units.flowFromSi(z.totalFlow), 1)} ${units.flowLabel} / ${fmt(units.pressureFromHead(z.requiredUpstreamHead), 1)} ${units.pressureLabel}';
          text(Layers.labels, p + Pt(r * 1.3, r * 0.4), s, heightMm: labelH, bold: true);
        }
      case WaterSupplyEntity w:
        final r = 2.0 * mm;
        path(w.layer, [p + Pt(-r, -r), p + Pt(r, -r), p + Pt(r, r), p + Pt(-r, r)], closed: true, widthMm: 0.3, fill: colorOf(w.layer));
        text(w.layer, p, 'W', heightMm: 2.4, bold: true, anchor: PlotAnchor.center, color: 0xFFFFFFFF);
        if (options.labels) {
          var s = w.name;
          if (options.results && results != null) {
            SupplyDuty? worst;
            for (final f in results.systemFlows) {
              for (final d in f.supplies) {
                if (d.supplyId == w.id && (worst == null || d.requiredHead > worst.requiredHead)) worst = d;
              }
            }
            if (worst != null) s += '  ${fmt(units.flowFromSi(worst.flow), 1)} ${units.flowLabel} @ ${fmt(units.pressureFromHead(worst.requiredHead), 1)} ${units.pressureLabel}';
          }
          // above-left of the symbol (the mainline usually leaves to the right)
          text(Layers.labels, p + Pt(r * 1.1, r * 1.3), s, heightMm: labelH, bold: true, anchor: PlotAnchor.bottomRight);
        }
      case PumpEntity pu:
        final r = 1.5 * mm;
        circle(pu.layer, p, r, widthMm: 0.3, fill: colorOf(pu.layer));
        text(pu.layer, p, 'P', heightMm: 2.0, bold: true, anchor: PlotAnchor.center, color: 0xFFFFFFFF);
        if (options.labels) text(Layers.labels, p + Pt(r * 1.3, -r * 1.6), project.catalog.pump(pu.pumpSpecId)?.name ?? tr('tool.pump'), heightMm: labelH * 0.9);
      case MiscHydraulicEntity m:
        final r = 1.2 * mm;
        path(m.layer, [p + Pt(0, r), p + Pt(r, 0), p + Pt(0, -r), p + Pt(-r, 0)], closed: true, widthMm: 0.3, fill: colorOf(m.layer));
        if (options.labels) text(Layers.labels, p + Pt(r * 1.3, r * 1.1), project.catalog.valve(m.valveSpecId)?.name ?? '', heightMm: labelH * 0.9);
      case JunctionEntity j:
        circle(j.layer, p, 0.5 * mm, fill: colorOf(j.layer), stroke: false);
      case ControllerEntity k:
        final r = 1.6 * mm;
        path(k.layer, [p + Pt(-r, -r), p + Pt(r, -r), p + Pt(r, r), p + Pt(-r, r)], closed: true, widthMm: 0.3, fill: colorOf(k.layer));
        text(k.layer, p, 'C', heightMm: 2.0, bold: true, anchor: PlotAnchor.center, color: 0xFFFFFFFF);
        if (options.labels) text(Layers.labels, p + Pt(r * 1.3, r * 0.4), k.name, heightMm: labelH, bold: true);
      default:
        break;
    }
  }
  var bounds = Bounds.empty;
  for (final it in items) {
    switch (it) {
      case PlotPath p:
        bounds = bounds.union(Bounds.ofPoints(p.points));
      case PlotCircle c:
        bounds = bounds.union(Bounds(c.center.x - c.radius, c.center.y - c.radius, c.center.x + c.radius, c.center.y + c.radius));
      case PlotText tx:
        // approximate extent of the text so auto-fit keeps labels on the sheet
        final w = tx.text.length * tx.heightMm * 0.62 * unitsPerMm;
        final h = tx.heightMm * unitsPerMm;
        final (dx0, dx1) = switch (tx.anchor) {
          PlotAnchor.bottomRight => (-w, 0.0),
          PlotAnchor.bottomCenter || PlotAnchor.center => (-w / 2, w / 2),
          _ => (0.0, w),
        };
        if (tx.rotationDeg == 0) {
          bounds = bounds.include(tx.position + Pt(dx0, 0)).include(tx.position + Pt(dx1, h));
        } else {
          bounds = bounds.include(tx.position);
        }
    }
  }
  return PlotScene(items: items, bounds: bounds, unitsPerMm: unitsPerMm, layers: layersUsed);
}

/// Segment of a polyline containing the given distance from its start.
(Pt, Pt) _segmentAt(List<Pt> pts, double distance) {
  var d = distance;
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i - 1].distanceTo(pts[i]);
    if (d <= seg || i == pts.length - 1) return (pts[i - 1], pts[i]);
    d -= seg;
  }
  return (pts.first, pts.last);
}
