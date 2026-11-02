/// Several centre pivots in one property: the arrangement of machines of
/// standard spans that irrigates the most of a field outline, keeping clear
/// of its obstacles (legal reserves, roads, buildings, machines already
/// drawn) and of each other, within the flow the water right allows, and
/// the common mainline from the water supply to every pivot point.
///
/// Two arrangements are tried and the larger irrigated area is kept:
///
/// * largest first: the largest full circle of `pivot_fit.dart` (the pole
///   of inaccessibility of the field and the machines placed so far), until
///   no machine of the smallest length fits;
/// * a lattice of equal machines, square or hexagonal, turned and shifted
///   over the field for every machine length, each machine then grown to the
///   longest that fits where it stands and the gaps filled largest first.
///
/// The wetted radius is the machine length plus the end throw; a clearance
/// is kept between neighbouring wetted circles and from the field edge.
/// Optionally the corners left are filled with part-circle pivots
/// (`fitSectorPivot`). Each machine's flow is its area times the gross depth
/// over the hours of a revolution; with a flow allowance the smallest
/// machines are dropped first. The mainline is the minimum spanning tree of
/// the supply and the pivot points (Prim), drawn straight (Keller &
/// Bliesner 1990, ch. 14 for the machines; the tree is the shortest network
/// of straight pipes joining the points through them).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart' show LayoutRegion, normalizeDeg, poleOfInaccessibility;
import 'pivot.dart' show PivotKind;
import 'pivot_fit.dart';

/// Options of [layoutPivots].
class MultiPivotOptions {
  const MultiPivotOptions({
    this.obstacles = const [],
    this.pointObstacles = const [],
    this.spanLengths = defaultSpanLengths,
    this.overhangs = defaultOverhangs,
    this.minSpans = 2,
    this.maxSpans = 12,
    this.endThrowM = 5,
    this.clearanceM = 5,
    this.maxPivots = 12,
    this.minRadiusM = 100,
    this.maxTotalFlow = 0,
    this.grossDepthMm = 8,
    this.hoursPerCycle = 21,
    this.corners = false,
    this.minSweepDeg = 90,
    this.supply,
    this.precision = 2,
  });

  /// Areas the machines may not cross and points they keep clear of.
  final List<List<Pt>> obstacles;
  final List<PointObstacle> pointObstacles;

  /// Standard spans and overhangs, and the towers of a machine.
  final List<double> spanLengths;
  final List<double> overhangs;
  final int minSpans, maxSpans;

  /// Throw of the end sprinkler (m) and the clearance between wetted
  /// circles and from the field edge (m).
  final double endThrowM;
  final double clearanceM;

  /// Most machines, the smallest wetted radius worth a machine (m) and the
  /// flow the water right allows (m³/s; 0 = no limit).
  final int maxPivots;
  final double minRadiusM;
  final double maxTotalFlow;

  /// Gross depth (mm) in the hours of one revolution, for each machine's flow.
  final double grossDepthMm;
  final double hoursPerCycle;

  /// Fill the corners with part-circle pivots of at least [minSweepDeg].
  final bool corners;
  final double minSweepDeg;

  /// Water supply the mainline starts from (null = the first pivot).
  final Pt? supply;

  /// Precision of the searches (m).
  final double precision;
}

/// One machine of the arrangement.
class PlacedPivot {
  const PlacedPivot({required this.center, required this.spans, required this.endThrowM, this.sectorStartDeg = 0, this.sectorSweepDeg = 360, required this.flow});
  final Pt center;
  final SpanCombination spans;
  final double endThrowM;

  /// Counter-clockwise sector from [sectorStartDeg] (360 = full circle).
  final double sectorStartDeg, sectorSweepDeg;

  /// Design flow (m³/s).
  final double flow;

  double get machineLength => spans.length;
  double get irrigatedRadius => machineLength + endThrowM;
  bool get fullCircle => sectorSweepDeg >= 360 - 1e-6;
  double get areaM2 => degToRad(sectorSweepDeg) / 2 * irrigatedRadius * irrigatedRadius;
  double get angleDeg => fullCircle ? 0 : normalizeDeg(sectorStartDeg + sectorSweepDeg / 2);

  /// The machine as a pivot of [p] (new id).
  PivotEntity toEntity(Project p, {String name = '', double grossDepthMm = 8, double hoursPerCycle = 21}) => PivotEntity(
    id: p.newId(),
    name: name,
    center: center,
    radiusM: machineLength,
    angleDeg: angleDeg,
    kind: PivotKind.pivot,
    spanLengthM: spans.mainSpan,
    endThrowM: endThrowM,
    sectorDeg: fullCircle ? 360 : sectorSweepDeg,
    grossDepthMm: grossDepthMm,
    hoursPerCycle: hoursPerCycle,
    zoneName: name,
  );
}

/// The arrangement found.
class MultiPivotLayout {
  const MultiPivotLayout({required this.pivots, required this.fieldAreaM2, required this.mainline, required this.strategy, this.messages = const []});
  final List<PlacedPivot> pivots;
  final double fieldAreaM2;

  /// Pipes of the common mainline (straight, from the supply or the first
  /// pivot through the tree).
  final List<(Pt, Pt)> mainline;

  /// `largest` or `lattice`.
  final String strategy;

  /// Codes `mpivot_*` (`mpivot_none`, `mpivot_flow_limit`, `mpivot_max`).
  final List<String> messages;

  double get irrigatedAreaM2 => pivots.fold(0.0, (a, p) => a + p.areaM2);
  double get coverage => fieldAreaM2 > 0 ? irrigatedAreaM2 / fieldAreaM2 : 0;
  double get totalFlow => pivots.fold(0.0, (a, p) => a + p.flow);
  double get mainlineLengthM => mainline.fold(0.0, (a, e) => a + e.$1.distanceTo(e.$2));
}

/// Flow (m³/s) of a machine watering [areaM2] with [grossDepthMm] in [hours].
double pivotDesignFlow(double areaM2, double grossDepthMm, double hours) => hours > 0 ? areaM2 * grossDepthMm / 1000 / (hours * 3600) : 0;

/// A polygon round the circle of [c] and [r] (its edges touch the circle, so
/// a clearance measured to it is never less than to the circle).
List<Pt> _circle(Pt c, double r, [int n = 96]) {
  final rc = r / math.cos(math.pi / n);
  return [for (var i = 0; i < n; i++) c + Pt.polar(rc, 2 * math.pi * (i + 0.5) / n)];
}

/// The minimum spanning tree of [points] (Prim), as index pairs.
List<(int, int)> minimumSpanningTree(List<Pt> points) {
  final n = points.length;
  if (n < 2) return const [];
  final inTree = List<bool>.filled(n, false)..[0] = true;
  final best = List<double>.generate(n, (i) => points[0].distanceTo(points[i]));
  final from = List<int>.filled(n, 0);
  final out = <(int, int)>[];
  for (var k = 1; k < n; k++) {
    var j = -1;
    for (var i = 0; i < n; i++) {
      if (!inTree[i] && (j < 0 || best[i] < best[j])) j = i;
    }
    inTree[j] = true;
    out.add((from[j], j));
    for (var i = 0; i < n; i++) {
      final d = points[j].distanceTo(points[i]);
      if (!inTree[i] && d < best[i]) {
        best[i] = d;
        from[i] = j;
      }
    }
  }
  return out;
}

/// Machines and mainline of the most irrigated arrangement in [field].
MultiPivotLayout layoutPivots(List<Pt> field, MultiPivotOptions o) {
  final region = LayoutRegion(field, exclusions: o.obstacles);
  final fieldArea = region.area;
  if (region.isEmpty) return MultiPivotLayout(pivots: const [], fieldAreaM2: 0, mainline: const [], strategy: 'largest', messages: const ['mpivot_none']);
  final lengths = [
    for (final c in pivotLengthOptions(spans: o.spanLengths, overhangs: o.overhangs, minSpans: o.minSpans, maxSpans: o.maxSpans))
      if (c.length + o.endThrowM >= o.minRadiusM - 1e-9) c,
  ];
  if (lengths.isEmpty) return MultiPivotLayout(pivots: const [], fieldAreaM2: fieldArea, mainline: const [], strategy: 'largest', messages: const ['mpivot_none']);
  final shortest = lengths.last.length + o.endThrowM;
  PlacedPivot place(Pt c, SpanCombination s, {double start = 0, double sweep = 360}) {
    final p = PlacedPivot(center: c, spans: s, endThrowM: o.endThrowM, sectorStartDeg: start, sectorSweepDeg: sweep, flow: 0);
    return PlacedPivot(center: c, spans: s, endThrowM: o.endThrowM, sectorStartDeg: start, sectorSweepDeg: sweep, flow: pivotDesignFlow(p.areaM2, o.grossDepthMm, o.hoursPerCycle));
  }

  // the field with the machines placed so far as obstacles
  PivotFitOptions fitOptions(List<PlacedPivot> placed) => PivotFitOptions(
    obstacles: [...o.obstacles, for (final p in placed) _circle(p.center, p.irrigatedRadius)],
    pointObstacles: o.pointObstacles,
    spanLengths: o.spanLengths,
    overhangs: o.overhangs,
    minSpans: o.minSpans,
    maxSpans: o.maxSpans,
    // the clearance taken from the room the field leaves
    endThrowM: o.endThrowM + o.clearanceM,
    precision: o.precision,
    minSweepDeg: o.minSweepDeg,
  );
  // adds full circles, largest first, to [placed]
  void fill(List<PlacedPivot> placed) {
    while (placed.length < o.maxPivots) {
      final fit = fitFullCirclePivot(field, fitOptions(placed));
      final s = fit.spans;
      if (s == null || s.length + o.endThrowM < math.max(o.minRadiusM, shortest) - 1e-9) break;
      placed.add(place(fit.center, s));
    }
  }

  // ---- largest first
  final greedy = <PlacedPivot>[];
  fill(greedy);
  var best = greedy;
  var strategy = 'largest';
  double area(List<PlacedPivot> ps) => ps.fold(0.0, (a, p) => a + p.areaM2);

  // ---- lattices of equal machines, grown and filled
  double signed(Pt p, List<PlacedPivot> others) {
    var d = region.signedDistance(p);
    for (final q in o.pointObstacles) {
      d = math.min(d, q.position.distanceTo(p) - q.radius);
    }
    for (final q in others) {
      d = math.min(d, q.center.distanceTo(p) - q.irrigatedRadius);
    }
    return d;
  }

  final b = region.bounds;
  final centre = Pt((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2);
  final reach = math.sqrt(b.width * b.width + b.height * b.height) / 2;
  final tried = lengths.length <= 8 ? lengths : [for (var i = 0; i < 8; i++) lengths[(i * (lengths.length - 1) / 7).round()]];
  // the lattices grown, the best three then filled
  final grown = <List<PlacedPivot>>[];
  for (final s in tried) {
    final r = s.length + o.endThrowM;
    final pitch = 2 * r + o.clearanceM;
    if (pitch <= 0) continue;
    for (final hex in const [false, true]) {
      for (var a = 0; a < 90; a += 15) {
        final ux = Pt.polar(1, degToRad(a.toDouble())), uy = ux.perpendicular;
        for (final fx in const [0.0, 1 / 3, 2 / 3]) {
          for (final fy in const [0.0, 1 / 3, 2 / 3]) {
            final rowStep = hex ? pitch * math.sqrt(3) / 2 : pitch;
            final rows = (reach / rowStep).ceil() + 1, cols = (reach / pitch).ceil() + 1;
            final placed = <PlacedPivot>[];
            for (var i = -rows; i <= rows && placed.length < o.maxPivots; i++) {
              for (var j = -cols; j <= cols && placed.length < o.maxPivots; j++) {
                final shift = hex && i.isOdd ? pitch / 2 : 0.0;
                final c = centre + ux * ((j + fx) * pitch + shift) + uy * ((i + fy) * rowStep);
                if (signed(c, placed) >= r + o.clearanceM - 1e-9) placed.add(place(c, s));
              }
            }
            if (placed.isEmpty || area(placed) * 1.5 < area(best)) continue;
            // every machine grown to the longest that fits where it stands
            for (var k = 0; k < placed.length; k++) {
              final others = [...placed.sublist(0, k), ...placed.sublist(k + 1)];
              final room = signed(placed[k].center, others) - o.clearanceM - o.endThrowM;
              final g = snapPivotLength(room, spans: o.spanLengths, overhangs: o.overhangs, minSpans: o.minSpans, maxSpans: o.maxSpans);
              if (g != null && g.length > placed[k].machineLength + 1e-9) placed[k] = place(placed[k].center, g);
            }
            grown.add(placed);
          }
        }
      }
    }
  }
  grown.sort((x, y) => area(y).compareTo(area(x)));
  for (final placed in grown.take(3)) {
    fill(placed);
    if (area(placed) > area(best) + 1e-6) {
      best = placed;
      strategy = 'lattice';
    }
  }
  final out = [...best];
  // ---- part circles in the corners left
  if (o.corners) {
    while (out.length < o.maxPivots) {
      final fit = fitSectorPivot(field, fitOptions(out));
      final s = fit.spans;
      if (s == null || fit.sectorSweepDeg < o.minSweepDeg - 1e-9 || s.length + o.endThrowM < o.minRadiusM - 1e-9) break;
      out.add(place(fit.center, s, start: fit.sectorStartDeg, sweep: fit.sectorSweepDeg));
    }
  }
  final messages = <String>[];
  if (out.length >= o.maxPivots) messages.add('mpivot_max');
  // ---- the flow allowance: the smallest machines go first
  if (o.maxTotalFlow > 0) {
    out.sort((x, y) => y.areaM2.compareTo(x.areaM2));
    var q = 0.0;
    final kept = <PlacedPivot>[];
    for (final p in out) {
      if (q + p.flow <= o.maxTotalFlow + 1e-12) {
        kept.add(p);
        q += p.flow;
      }
    }
    if (kept.length < out.length) messages.add('mpivot_flow_limit');
    out
      ..clear()
      ..addAll(kept);
  }
  if (out.isEmpty) messages.add('mpivot_none');
  // the machines from the supply outwards, then the tree
  final start = o.supply ?? (out.isEmpty ? Pt.zero : out.first.center);
  out.sort((x, y) => x.center.distanceTo(start).compareTo(y.center.distanceTo(start)));
  final nodes = [if (o.supply != null) o.supply!, for (final p in out) p.center];
  final mainline = [for (final (i, j) in minimumSpanningTree(nodes)) (nodes[i], nodes[j])];
  return MultiPivotLayout(pivots: out, fieldAreaM2: fieldArea, mainline: mainline, strategy: strategy, messages: messages);
}

/// Centre of the largest circle of [field] avoiding [obstacles] (for a
/// supply hint when there is none).
Pt fieldPole(List<Pt> field, {List<List<Pt>> obstacles = const []}) {
  final region = LayoutRegion(field, exclusions: obstacles);
  if (region.isEmpty) return Pt.zero;
  return poleOfInaccessibility(region.bounds, region.signedDistance, precision: 1).$1;
}
