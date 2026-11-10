/// Charts of a design drawn as plot items, so the PDF (and any [PlotScene]
/// writer) prints what the screen shows: the hydraulic grade line of the
/// mainline in every system flow (from the supply to the valve with the least
/// pressure margin), the longitudinal profile of the terrain along it or
/// along a path drawn with the profile tool, and the curve of every pump
/// with its duty point in each system flow.
///
/// A chart is laid out by [chartScene] in paper millimetres (a scene with
/// one world unit per millimetre); values are converted to the project units.
library;

import 'dart:math' as math;

import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'plot.dart';
import 'scorecard_chart.dart' show scorecardChart; // 1.7.0 SCR

/// A line of a chart, in chart units (project units already).
class ChartSeries {
  const ChartSeries({required this.label, required this.points, this.color = 0xFF1565C0, this.widthMm = 0.45, this.dashed = false, this.fillColor});
  final String label;
  final List<(double, double)> points;
  final int color;
  final double widthMm;
  final bool dashed;

  /// Fill between the line and the bottom of the plot (a ground profile).
  final int? fillColor;
}

/// A labelled point (a duty point, a required pressure, a low point).
class ChartMarker {
  const ChartMarker({required this.x, required this.y, this.label = '', this.color = 0xFFC62828, this.radiusMm = 0.8});
  final double x, y;
  final String label;
  final int color;
  final double radiusMm;
}

class PlotChart {
  PlotChart({required this.title, this.xLabel = '', this.yLabel = '', this.series = const [], this.markers = const [], this.notes = const [], this.xFromZero = true, this.yFromZero = false});

  /// 1.7.0 SCR: a chart that lays itself out (the scorecard radar) instead
  /// of the axes, series and markers.
  PlotScene Function(double widthMm, double heightMm)? draw;
  final String title;
  final String xLabel, yLabel;
  final List<ChartSeries> series;
  final List<ChartMarker> markers;

  /// Lines printed under the chart.
  final List<String> notes;

  /// Axes that start at zero (stations, flows; heads of a pump curve).
  final bool xFromZero, yFromZero;

  bool get isEmpty => draw == null && series.every((s) => s.points.length < 2) && markers.isEmpty;
}

const _ink = 0xFF1A1A1A;
const _grid = 0xFFD5DBE1;
const _axisText = 0xFF4A5560;
const groundColor = 0xFF8D6E63;
const pipeColor = 0xFF1E88E5;
const hglColor = 0xFF2E7D32;

/// "Nice" tick values covering [lo]..[hi] (about [target] of them).
List<double> niceTicks(double lo, double hi, {int target = 6}) {
  if (!(hi > lo)) return [lo];
  final raw = (hi - lo) / target;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n < 1.5 ? 1 : (n < 2.25 ? 2 : (n < 3.5 ? 2.5 : (n < 7.5 ? 5 : 10)))) * mag;
  final out = <double>[];
  // k·step, cleaned of the binary noise (0.6000000000000001)
  for (var k = (lo / step - 1e-9).ceil(); k * step <= hi + step * 1e-6; k++) {
    final v = double.parse((k * step).toStringAsPrecision(12));
    out.add(v == 0 ? 0 : v);
  }
  return out;
}

int _decimals(List<double> ticks) {
  if (ticks.length < 2) return 1;
  final step = (ticks[1] - ticks[0]).abs();
  if (step >= 1) return step == step.roundToDouble() ? 0 : 1;
  return math.min(4, (-math.log(step) / math.ln10).ceil() + (step * math.pow(10, (-math.log(step) / math.ln10).ceil()) % 1 == 0 ? 0 : 1));
}

/// Lays [chart] out in [widthMm] × [heightMm]: title, axes with ticks and
/// grid, the series, markers and the legend; items in paper millimetres
/// with the origin at the bottom-left of the frame.
PlotScene chartScene(PlotChart chart, {required double widthMm, required double heightMm}) {
  if (chart.draw case final draw?) return draw(widthMm, heightMm); // 1.7.0 SCR
  const layer = 'CHART';
  final items = <PlotItem>[];
  void path(List<Pt> pts, {int color = _ink, double w = 0.25, bool dashed = false, int? fill, bool closed = false}) {
    if (pts.length < 2) return;
    items.add(PlotPath(layer: layer, color: color, points: pts, closed: closed, widthMm: w, dashed: dashed, fillColor: fill));
  }

  void text(Pt p, String s, {double h = 2.0, PlotAnchor anchor = PlotAnchor.bottomLeft, bool bold = false, int color = _axisText, double rot = 0}) {
    if (s.isEmpty) return;
    items.add(PlotText(layer: layer, color: color, position: p, text: s, heightMm: h, anchor: anchor, bold: bold, rotationDeg: rot));
  }

  final legend = [
    for (final s in chart.series)
      if (s.label.isNotEmpty && s.points.length >= 2) s,
  ];
  final left = 17.0, right = 4.0, top = 9.0, bottom = legend.isEmpty ? 13.0 : 18.0;
  final pw = widthMm - left - right, ph = heightMm - top - bottom;
  text(Pt(0, heightMm - 4.2), chart.title, h: 2.8, bold: true, color: _ink);
  if (pw <= 5 || ph <= 5 || chart.isEmpty) {
    return PlotScene(items: items, bounds: Bounds(0, 0, widthMm, heightMm), unitsPerMm: 1, layers: const {});
  }
  // ranges
  var x0 = double.infinity, x1 = -double.infinity, y0 = double.infinity, y1 = -double.infinity;
  void span(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    x0 = math.min(x0, x);
    x1 = math.max(x1, x);
    y0 = math.min(y0, y);
    y1 = math.max(y1, y);
  }

  for (final s in chart.series) {
    for (final (x, y) in s.points) {
      span(x, y);
    }
  }
  for (final m in chart.markers) {
    span(m.x, m.y);
  }
  if (chart.xFromZero) x0 = math.min(0, x0);
  if (chart.yFromZero) y0 = math.min(0, y0);
  if (x1 - x0 < 1e-9) x1 = x0 + 1;
  if (y1 - y0 < 1e-6) {
    y0 -= 0.5;
    y1 += 0.5;
  }
  final pad = (y1 - y0) * 0.08;
  if (!chart.yFromZero || y0 < 0) y0 -= pad;
  y1 += pad;
  final xt = niceTicks(x0, x1, target: 8), yt = niceTicks(y0, y1, target: 6);
  // snap the frame to the outer ticks so the grid closes the plot
  if (xt.length >= 2) {
    final st = xt[1] - xt[0];
    x0 = math.min(x0, xt.first);
    x1 = math.max(x1, xt.last + (xt.last < x1 - 1e-9 ? st : 0));
  }
  if (yt.length >= 2) {
    final st = yt[1] - yt[0];
    if (yt.first > y0 + 1e-9) yt.insert(0, yt.first - st);
    if (yt.last < y1 - 1e-9) yt.add(yt.last + st);
    y0 = yt.first;
    y1 = yt.last;
  }
  if (xt.isNotEmpty && xt.last < x1 - 1e-9 && xt.length >= 2) xt.add(xt.last + xt[1] - xt[0]);
  if (xt.isNotEmpty) x1 = math.max(x1, xt.last);
  Pt at(double x, double y) => Pt(left + (x - x0) / (x1 - x0) * pw, bottom + (y - y0) / (y1 - y0) * ph);
  // grid, ticks and their values
  final xd = _decimals(xt), yd = _decimals(yt);
  for (final v in xt) {
    final p = at(v, y0);
    path([p, Pt(p.x, bottom + ph)], color: _grid, w: 0.15);
    text(Pt(p.x, bottom - 3.4), fmt(v, xd), h: 1.7, anchor: PlotAnchor.bottomCenter);
  }
  for (final v in yt) {
    final p = at(x0, v);
    path([p, Pt(left + pw, p.y)], color: _grid, w: 0.15);
    text(Pt(left - 1.2, p.y - 0.85), fmt(v, yd), h: 1.7, anchor: PlotAnchor.bottomRight);
  }
  path([Pt(left, bottom), Pt(left + pw, bottom), Pt(left + pw, bottom + ph), Pt(left, bottom + ph)], closed: true, color: _ink, w: 0.3);
  text(Pt(left + pw / 2, bottom - 7.2), chart.xLabel, h: 1.9, anchor: PlotAnchor.bottomCenter);
  text(Pt(4.2, bottom + ph / 2), chart.yLabel, h: 1.9, anchor: PlotAnchor.bottomCenter, rot: 90);
  // fills first, then the lines
  for (final s in chart.series) {
    if (s.fillColor == null || s.points.length < 2) continue;
    final pts = [for (final (x, y) in s.points) at(x, y)];
    path([...pts, Pt(pts.last.x, bottom), Pt(pts.first.x, bottom)], closed: true, color: s.fillColor!, w: 0.05, fill: s.fillColor);
  }
  for (final s in chart.series) {
    path([for (final (x, y) in s.points) at(x, y)], color: s.color, w: s.widthMm, dashed: s.dashed);
  }
  for (final m in chart.markers) {
    final p = at(m.x, m.y);
    items.add(PlotCircle(layer: layer, color: m.color, center: p, radius: m.radiusMm, widthMm: 0.2, fillColor: m.color, stroke: false));
    if (m.label.isNotEmpty) {
      // inside the frame: to the left of points in the right third
      final right = p.x > left + pw * 0.66;
      text(Pt(p.x + (right ? -1.4 : 1.4), p.y + 1.0), m.label, h: 1.7, anchor: right ? PlotAnchor.bottomRight : PlotAnchor.bottomLeft, color: m.color);
    }
  }
  // legend under the axis title
  var lx = left;
  for (final s in legend) {
    path([Pt(lx, 3.1), Pt(lx + 7, 3.1)], color: s.color, w: math.max(0.5, s.widthMm), dashed: s.dashed);
    text(Pt(lx + 8.5, 2.3), s.label, h: 1.8);
    lx += 8.5 + s.label.length * 1.8 * 0.62 + 6;
  }
  return PlotScene(items: items, bounds: Bounds(0, 0, widthMm, heightMm), unitsPerMm: 1, layers: const {});
}

// ---------------------------------------------------------------- mainline path

/// A pipe segment of a path with the direction it is walked in.
typedef PathStep = ({PipeSegmentResult seg, bool forward});

/// Mainline segments of system flow [f] from the supply to the valve with
/// the least pressure margin (largest deficit), in order; empty when the
/// flow has no mainline or the two are not connected.
List<PathStep> criticalMainlinePath(Project p, SystemFlowResult f) {
  if (f.pipes.isEmpty || f.valves.isEmpty) return const [];
  final supply = f.supplies.isEmpty ? null : p.byId(f.supplies.first.supplyId);
  final from = supply is WaterSupplyEntity ? supply.position : null;
  final valve = f.valves.reduce((a, b) => a.deficit >= b.deficit ? a : b);
  if (from == null) return const [];
  return mainlinePathBetween(f.pipes, from, valve.p);
}

/// Segments of [pipes] joining the points nearest to [from] and [to]
/// (breadth-first over the network; ends closer than 1 cm are the same
/// node, so a pump or valve between two pipes keeps them joined).
List<PathStep> mainlinePathBetween(List<PipeSegmentResult> pipes, Pt from, Pt to) {
  String key(Pt q) => '${(q.x * 100).round()},${(q.y * 100).round()}';
  final adj = <String, List<(int, String)>>{};
  final pos = <String, Pt>{};
  for (var i = 0; i < pipes.length; i++) {
    final s = pipes[i];
    final ka = key(s.a), kb = key(s.b);
    if (ka == kb) continue;
    pos[ka] = s.a;
    pos[kb] = s.b;
    (adj[ka] ??= []).add((i, kb));
    (adj[kb] ??= []).add((i, ka));
  }
  String? nearest(Pt q) {
    String? best;
    var bd = double.infinity;
    for (final e in pos.entries) {
      final dd = e.value.distanceTo(q);
      if (dd < bd) {
        bd = dd;
        best = e.key;
      }
    }
    return best;
  }

  final start = nearest(from), end = nearest(to);
  if (start == null || end == null || start == end) return const [];
  final prev = <String, (int, String)>{};
  final queue = [start];
  final seen = {start};
  for (var qi = 0; qi < queue.length; qi++) {
    final k = queue[qi];
    if (k == end) break;
    for (final (i, other) in adj[k] ?? const <(int, String)>[]) {
      if (seen.add(other)) {
        prev[other] = (i, k);
        queue.add(other);
      }
    }
  }
  if (!prev.containsKey(end)) return const [];
  final out = <PathStep>[];
  var k = end;
  while (k != start) {
    final (i, back) = prev[k]!;
    final s = pipes[i];
    out.add((seg: s, forward: key(s.a) == back));
    k = back;
  }
  return out.reversed.toList();
}

/// Stations, pipe elevations and heads along [path]: (station, z, head).
List<(double, double, double)> _profileOf(List<PathStep> path) {
  final out = <(double, double, double)>[];
  var x = 0.0;
  for (final st in path) {
    final s = st.seg;
    final za = st.forward ? s.elevationA : s.elevationB, zb = st.forward ? s.elevationB : s.elevationA;
    final ha = st.forward ? s.pressureStart : s.pressureEnd, hb = st.forward ? s.pressureEnd : s.pressureStart;
    out.add((x, za, za + ha));
    x += s.length;
    out.add((x, zb, zb + hb));
  }
  return out;
}

/// Ground elevation along [path]: (station, elevation) samples of the
/// project terrain, about every terrain densify step (at most 400 samples).
List<(double, double)> groundProfile(Project p, List<Pt> path) {
  if (path.length < 2) return const [];
  final terrain = p.buildTerrain();
  if (terrain.isEmpty) return const [];
  final total = polylineLength(path);
  if (total <= 0) return const [];
  final step = math.max(math.max(0.5, math.min(p.params.terrainDensify, total / 50)), total / 400);
  final out = <(double, double)>[];
  for (var d = 0.0; d < total; d += step) {
    out.add((d, terrain.elevationAt(pointAlongPolyline(path, d))));
  }
  out.add((total, terrain.elevationAt(path.last)));
  return out;
}

String _flowName(SystemFlowResult f, int i) => f.name.isEmpty ? '${i + 1}' : f.name;

/// Hydraulic grade line of the mainline in system flow [f] (index [i]):
/// pipe elevation and head from the supply to the critical valve, with the
/// head that valve requires.
PlotChart? hglChart(Project p, SystemFlowResult f, int i, {required Translate t, Units u = Units.metric}) {
  final path = criticalMainlinePath(p, f);
  if (path.isEmpty) return null;
  final prof = _profileOf(path);
  final valve = f.valves.reduce((a, b) => a.deficit >= b.deficit ? a : b);
  final end = prof.last;
  final req = end.$2 + valve.requiredHead;
  String pr(double h) => '${fmt(u.pressureFromHead(h), 1)} ${u.pressureLabel}';
  return PlotChart(
    title: t('chart.hglTitle', {'f': _flowName(f, i)}),
    xLabel: '${t('chart.station')} (${u.lengthLabel})',
    yLabel: '${t('chart.elevation')} (${u.lengthLabel})',
    series: [
      ChartSeries(label: t('chart.pipe'), points: [for (final (x, z, _) in prof) (u.lengthFromSi(x), u.lengthFromSi(z))], color: pipeColor, widthMm: 0.5, fillColor: 0xFFEFF5FB),
      ChartSeries(label: t('chart.hgl'), points: [for (final (x, _, h) in prof) (u.lengthFromSi(x), u.lengthFromSi(h))], color: hglColor, widthMm: 0.55),
    ],
    markers: [
      ChartMarker(x: u.lengthFromSi(end.$1), y: u.lengthFromSi(req), label: t('chart.required', {'z': valve.zoneName, 'p': pr(valve.requiredHead)})),
      ChartMarker(x: u.lengthFromSi(end.$1), y: u.lengthFromSi(end.$3), label: t('chart.available', {'p': pr(end.$3 - end.$2)}), color: hglColor),
    ],
    notes: [
      t('chart.hglNote', {'z': valve.zoneName, 'a': pr(valve.availableHead), 'r': pr(valve.requiredHead), 'q': '${fmt(u.flowFromSi(f.totalFlow), 1)} ${u.flowLabel}'}),
    ],
  );
}

/// Longitudinal profile along [path] (a path drawn on the screen, or the
/// critical mainline path): the ground, and the pipe and grade line when
/// [steps] give them; lowest and highest ground points marked.
PlotChart? profileChart(Project p, List<Pt> path, {required Translate t, Units u = Units.metric, List<PathStep> steps = const [], String name = ''}) {
  final ground = groundProfile(p, path);
  final prof = steps.isEmpty ? const <(double, double, double)>[] : _profileOf(steps);
  if (ground.length < 2 && prof.isEmpty) return null;
  final series = <ChartSeries>[
    if (ground.length >= 2)
      ChartSeries(label: t('prof.ground'), points: [for (final (x, z) in ground) (u.lengthFromSi(x), u.lengthFromSi(z))], color: groundColor, widthMm: 0.55, fillColor: 0xFFF1E8E2),
    if (prof.isNotEmpty) ChartSeries(label: t('prof.pipe'), points: [for (final (x, z, _) in prof) (u.lengthFromSi(x), u.lengthFromSi(z))], color: pipeColor, widthMm: 0.5),
    if (prof.isNotEmpty) ChartSeries(label: t('prof.hgl'), points: [for (final (x, _, h) in prof) (u.lengthFromSi(x), u.lengthFromSi(h))], color: hglColor, widthMm: 0.4),
  ];
  final markers = <ChartMarker>[];
  final notes = <String>[];
  if (ground.length >= 2) {
    var lo = ground.first, hi = ground.first;
    for (final g in ground) {
      if (g.$2 < lo.$2) lo = g;
      if (g.$2 > hi.$2) hi = g;
    }
    markers.add(ChartMarker(x: u.lengthFromSi(lo.$1), y: u.lengthFromSi(lo.$2), label: '${t('prof.lowest')} ${fmt(u.lengthFromSi(lo.$2), 2)}', color: 0xFF0277BD));
    markers.add(ChartMarker(x: u.lengthFromSi(hi.$1), y: u.lengthFromSi(hi.$2), label: '${t('prof.highest')} ${fmt(u.lengthFromSi(hi.$2), 2)}', color: 0xFFEF6C00));
    final rise = ground.last.$2 - ground.first.$2, len = ground.last.$1;
    notes.add(t('prof.slope', {'s': fmt(len > 0 ? rise / len * 100 : 0, 2), 'd': fmt(rise, 2), 'l': '${fmt(u.lengthFromSi(len), 1)} ${u.lengthLabel}'}));
  }
  return PlotChart(
    title: t('chart.profileTitle', {'n': name}),
    xLabel: '${t('chart.station')} (${u.lengthLabel})',
    yLabel: '${t('chart.elevation')} (${u.lengthLabel})',
    series: series,
    markers: markers,
    notes: notes,
  );
}

/// Curve of every pump of the drawing with its duty point in each system
/// flow (and the curve at the speed a variable-speed drive runs it).
List<PlotChart> pumpCharts(Project p, DesignResults? r, {required Translate t, Units u = Units.metric}) {
  final out = <PlotChart>[];
  for (final e in p.entities.whereType<PumpEntity>()) {
    final spec = p.catalog.pump(e.pumpSpecId);
    if (spec == null) continue;
    final duties = <(String, DeviceResult)>[];
    if (r != null) {
      for (var i = 0; i < r.systemFlows.length; i++) {
        final f = r.systemFlows[i];
        for (final d in f.devices) {
          if (d.entityId == e.id && d.flow > 0) duties.add((_flowName(f, i), d));
        }
      }
    }
    var qMax = spec.points.fold(0.0, (a, pt) => math.max(a, pt.$1));
    for (final (_, d) in duties) {
      qMax = math.max(qMax, d.flow);
    }
    final run = spec.curve.runoutFlow;
    qMax = run.isFinite ? math.min(math.max(qMax * 1.15, 1e-6), run) : math.max(qMax * 1.25, 1e-6);
    List<(double, double)> curve(double speed) {
      final c = spec.curve.withSpeed(speed);
      final top = math.min(qMax, c.runoutFlow.isFinite ? c.runoutFlow : qMax);
      return [for (var k = 0; k <= 40; k++) (u.flowFromSi(top * k / 40), u.pressureFromHead(math.max(0, c.head(top * k / 40))))];
    }

    final speeds = {
      for (final (_, d) in duties)
        if ((d.speedRatio - 1).abs() > 1e-3) (d.speedRatio * 1000).round() / 1000,
    };
    if ((e.speedRatio - 1).abs() > 1e-3) speeds.add((e.speedRatio * 1000).round() / 1000);
    final title = e.name.isEmpty ? spec.name : '${e.name} — ${spec.name}';
    String pct(double s) => '${fmt(s * 100, 0)} %';
    out.add(
      PlotChart(
        title: t('chart.pumpTitle', {'n': title}),
        xLabel: '${t('chart.flow')} (${u.flowLabel})',
        yLabel: '${t('chart.head')} (${u.pressureLabel})',
        xFromZero: true,
        yFromZero: true,
        series: [
          ChartSeries(label: t('chart.curveFull'), points: curve(1), color: 0xFFC62828, widthMm: 0.55),
          for (final s in speeds) ChartSeries(label: t('chart.curveSpeed', {'s': pct(s)}), points: curve(s), color: 0xFFEF9A9A, widthMm: 0.4, dashed: true),
        ],
        markers: [
          for (final (q, h) in spec.points) ChartMarker(x: u.flowFromSi(q), y: u.pressureFromHead(h), color: 0xFF9E9E9E, radiusMm: 0.5),
          for (final (name, d) in duties) ChartMarker(x: u.flowFromSi(d.flow), y: u.pressureFromHead(d.pumpHead), label: name, color: 0xFF1565C0),
        ],
        notes: [
          for (final (name, d) in duties)
            t('chart.duty', {
              'f': name,
              'q': '${fmt(u.flowFromSi(d.flow), 1)} ${u.flowLabel}',
              'h': '${fmt(u.pressureFromHead(d.pumpHead), 1)} ${u.pressureLabel}',
              'e': fmt(spec.efficiencyAt(d.flow, speed: d.speedRatio) * 100, 0),
              's': pct(d.speedRatio),
            }),
        ],
      ),
    );
  }
  return out;
}

/// Every chart the PDF appends: the grade line of each system flow, the
/// profile along the critical mainline path of the flow with the least
/// margin (and along [profilePath], the path drawn on the screen), and the
/// pump curves.
List<PlotChart> designCharts(Project p, DesignResults? r, {required Translate t, Units u = Units.metric, List<Pt>? profilePath}) {
  final out = <PlotChart>[];
  if (r != null) {
    for (var i = 0; i < r.systemFlows.length; i++) {
      final c = hglChart(p, r.systemFlows[i], i, t: t, u: u);
      if (c != null) out.add(c);
    }
    SystemFlowResult? worst;
    for (final f in r.systemFlows) {
      if (f.pipes.isNotEmpty && f.valves.isNotEmpty && (worst == null || f.maxDeficit > worst.maxDeficit)) worst = f;
    }
    if (worst != null) {
      final steps = criticalMainlinePath(p, worst);
      if (steps.isNotEmpty) {
        final pts = <Pt>[steps.first.forward ? steps.first.seg.a : steps.first.seg.b];
        for (final st in steps) {
          pts.add(st.forward ? st.seg.b : st.seg.a);
        }
        final c = profileChart(p, pts, t: t, u: u, steps: steps, name: t('menu.mainline'));
        if (c != null) out.add(c);
      }
    }
  }
  if (profilePath != null && profilePath.length >= 2) {
    final c = profileChart(p, profilePath, t: t, u: u, name: t('chart.drawnPath'));
    if (c != null) out.add(c);
  }
  out.addAll(pumpCharts(p, r, t: t, u: u));
  // 1.7.0 SCR: the radar of the design scorecard (computed when drawn)
  if (r != null) out.add(scorecardChart(p, r, t: t));
  return out;
}
