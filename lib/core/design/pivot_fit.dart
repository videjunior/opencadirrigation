/// Pivot field fit: the largest full-circle centre pivot that fits in a
/// field avoiding its obstacles (the maximum inscribed circle, found as the
/// pole of inaccessibility), and the part-circle pivot (centre, radius and
/// sector) that irrigates the most area inside the field; the machine
/// length is a sum of standard spans plus an overhang (Keller & Bliesner
/// 1990, chap. 14; NRCS NEH 623 chap. 11: the wetted radius is the machine
/// length plus the throw of the end sprinkler or gun).
///
/// For a centre and a radius the sector is exact: every piece of the field
/// outline or of an obstacle within the radius blocks the directions it
/// spans as seen from the centre, every point obstacle the directions of
/// its clearance circle, and the free directions between the blocks form
/// arcs that are either wholly inside the field or wholly outside; the
/// widest arc inside is the sector. Centres are searched on a grid (and at
/// the corners and edges of the field, where part-circle pivots often
/// stand), then refined by a pattern search.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart';
import 'pivot.dart' show PivotKind;

/// Span lengths (m) of the usual centre pivot towers (113, 137, 160, 180
/// and 204 ft).
const defaultSpanLengths = [34.4, 41.8, 48.8, 54.9, 62.2];

/// Overhangs (m) beyond the last tower (none, 21, 42, 63 and 85 ft).
const defaultOverhangs = [0.0, 6.4, 12.8, 19.2, 25.9];

/// A point the machine must keep clear of by [radius] metres (a power
/// pole, a well, a tree).
class PointObstacle {
  const PointObstacle(this.position, this.radius);
  final Pt position;
  final double radius;
}

/// Options of [fitFullCirclePivot] and [fitSectorPivot].
class PivotFitOptions {
  PivotFitOptions({
    this.obstacles = const [],
    this.pointObstacles = const [],
    this.spanLengths = defaultSpanLengths,
    this.overhangs = defaultOverhangs,
    this.minSpans = 1,
    this.maxSpans = 20,
    this.endThrowM = 0,
    this.precision = 0.5,
    this.minSweepDeg = 30,
    this.searchCells = 24,
  });

  /// Areas the machine may not cross (buildings, ponds, woods).
  final List<List<Pt>> obstacles;
  final List<PointObstacle> pointObstacles;

  /// Span lengths and overhangs the machine is built from (m).
  final List<double> spanLengths;
  final List<double> overhangs;
  final int minSpans, maxSpans;

  /// Throw of the end sprinkler or gun beyond the machine (m): the wetted
  /// radius is the machine length plus this.
  final double endThrowM;

  /// Precision of the search (m).
  final double precision;

  /// Narrowest sector worth a machine (degrees).
  final double minSweepDeg;

  /// Centres tried across the field (per side of the grid).
  final int searchCells;
}

/// A machine length: the spans and the overhang.
class SpanCombination {
  const SpanCombination({required this.spans, required this.overhang});

  /// Span lengths from the pivot point out (m).
  final List<double> spans;
  final double overhang;

  /// Machine length to the last sprinkler (m).
  double get length => spans.fold(0.0, (s, v) => s + v) + overhang;
  int get count => spans.length;

  /// The span length used most.
  double get mainSpan {
    final counts = <double, int>{};
    for (final s in spans) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    var best = spans.isEmpty ? 0.0 : spans.first;
    for (final e in counts.entries) {
      if (e.value > (counts[best] ?? 0) || (e.value == counts[best] && e.key > best)) best = e.key;
    }
    return best;
  }
}

/// The machines that can be built from [spans] (at most two lengths, the
/// longer ones first) and [overhangs] with [minSpans]–[maxSpans] towers:
/// for every distinct length (to the centimetre) the combination with the
/// fewest span lengths, then the fewest spans; longest first.
List<SpanCombination> pivotLengthOptions({List<double> spans = defaultSpanLengths, List<double> overhangs = defaultOverhangs, int minSpans = 1, int maxSpans = 20}) {
  final ls = {
    for (final s in spans)
      if (s > 0 && s.isFinite) s,
  }.toList()..sort((a, b) => b.compareTo(a));
  final os = {
    for (final o in overhangs)
      if (o >= 0 && o.isFinite) o,
  }.toList()..sort();
  if (os.isEmpty) os.add(0);
  final lo = math.max(1, minSpans), hi = math.max(lo, maxSpans);
  final best = <int, (SpanCombination, int, int)>{};
  void offer(List<double> sp, double over, int kinds) {
    final c = SpanCombination(spans: sp, overhang: over);
    final key = (c.length * 100).round();
    final cur = best[key];
    if (cur == null || kinds < cur.$2 || (kinds == cur.$2 && sp.length < cur.$3)) best[key] = (c, kinds, sp.length);
  }

  for (var i = 0; i < ls.length; i++) {
    for (var na = 1; na <= hi; na++) {
      for (final over in os) {
        if (na >= lo) offer(List.filled(na, ls[i]), over, 1);
        for (var j = i + 1; j < ls.length; j++) {
          for (var nb = 1; na + nb <= hi; nb++) {
            if (na + nb < lo) continue;
            offer([...List.filled(na, ls[i]), ...List.filled(nb, ls[j])], over, 2);
          }
        }
      }
    }
  }
  final out = [for (final v in best.values) v.$1]..sort((a, b) => b.length.compareTo(a.length));
  return out;
}

/// The longest machine of [pivotLengthOptions] no longer than [maxLength]
/// (null when even the shortest is longer).
SpanCombination? snapPivotLength(double maxLength, {List<double> spans = defaultSpanLengths, List<double> overhangs = defaultOverhangs, int minSpans = 1, int maxSpans = 20}) {
  for (final c in pivotLengthOptions(spans: spans, overhangs: overhangs, minSpans: minSpans, maxSpans: maxSpans)) {
    if (c.length <= maxLength + 1e-9) return c;
  }
  return null;
}

/// A pivot fitted to a field.
class PivotFit {
  PivotFit({
    required this.center,
    required this.availableRadius,
    required this.spans,
    required this.endThrowM,
    required this.sectorStartDeg,
    required this.sectorSweepDeg,
    required this.fieldArea,
    required this.messages,
  });

  /// Pivot point.
  final Pt center;

  /// Wetted radius the field allows there (m): the inscribed radius for a
  /// full circle, the radius of the sector for a part circle.
  final double availableRadius;

  /// The machine (null when none fits).
  final SpanCombination? spans;
  final double endThrowM;

  /// Sector swept counter-clockwise from [sectorStartDeg] over
  /// [sectorSweepDeg] (360 = full circle).
  final double sectorStartDeg, sectorSweepDeg;
  final double fieldArea;

  /// Codes: `pivot_no_room` (no machine fits), `pivot_field_empty`.
  final List<String> messages;

  /// Machine length to the last sprinkler (m).
  double get machineLength => spans?.length ?? 0;

  /// Wetted radius (m).
  double get irrigatedRadius => spans == null ? 0 : machineLength + endThrowM;

  bool get fullCircle => sectorSweepDeg >= 360 - 1e-6;

  /// Irrigated area (m²).
  double get area => spans == null ? 0 : degToRad(sectorSweepDeg) / 2 * irrigatedRadius * irrigatedRadius;

  /// Share of the field irrigated.
  double get coverage => fieldArea > 0 ? area / fieldArea : 0;

  /// Direction of the middle of the sector (the drawing angle of a part
  /// circle [PivotEntity]).
  double get angleDeg => fullCircle ? 0 : normalizeDeg(sectorStartDeg + sectorSweepDeg / 2);

  /// The machine as a pivot of [p] (new id), its spans drawn at the main
  /// span length.
  PivotEntity toPivotEntity(Project p, {String zoneName = '', String name = ''}) => PivotEntity(
    id: p.newId(),
    name: name,
    center: center,
    radiusM: machineLength,
    angleDeg: angleDeg,
    kind: PivotKind.pivot,
    spanLengthM: spans?.mainSpan ?? 50,
    endThrowM: endThrowM,
    sectorDeg: fullCircle ? 360 : sectorSweepDeg,
    zoneName: zoneName,
  );
}

/// The field with its obstacles: signed distances and sectors.
class _Field {
  _Field(List<Pt> field, PivotFitOptions o) : region = LayoutRegion(field, exclusions: o.obstacles), points = o.pointObstacles;
  final LayoutRegion region;
  final List<PointObstacle> points;

  bool inside(Pt p) => region.contains(p) && points.every((q) => q.position.distanceTo(p) > q.radius);

  double signedDistance(Pt p) {
    var d = region.signedDistance(p);
    if (d <= 0) return d;
    for (final q in points) {
      d = math.min(d, q.position.distanceTo(p) - q.radius);
    }
    return d;
  }

  /// Widest free sector of radius [r] round [c]: (start, sweep) in radians,
  /// sweep 0 when none.
  (double, double) sector(Pt c, double r) {
    const twoPi = 2 * math.pi;
    final blocks = <(double, double)>[];
    void block(double a0, double a1) {
      // the minor arc between two directions
      var s = a0 % twoPi;
      if (s < 0) s += twoPi;
      var w = (a1 - a0) % twoPi;
      if (w < 0) w += twoPi;
      if (w > math.pi) {
        s = (s + w) % twoPi;
        w = twoPi - w;
      }
      blocks.add((s, s + w));
    }

    for (final loop in region.loops) {
      final pts = loop.points;
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        final ab = b - a, ac = a - c;
        final qa = ab.dot(ab);
        if (qa <= 0) continue;
        // |a + t·ab − c|² = r²
        final qb = 2 * ab.dot(ac), qc = ac.dot(ac) - r * r;
        final disc = qb * qb - 4 * qa * qc;
        if (disc <= 0) continue;
        final sq = math.sqrt(disc);
        final t0 = math.max(0.0, (-qb - sq) / (2 * qa)), t1 = math.min(1.0, (-qb + sq) / (2 * qa));
        if (t1 <= t0) continue;
        final p0 = a + ab * t0, p1 = a + ab * t1;
        if (distanceToSegment(c, p0, p1) < 1e-9) {
          // the outline runs through the centre: the directions along it
          for (final q in [p0, p1]) {
            if (q.distanceTo(c) > 1e-9) block((q - c).angle, (q - c).angle);
          }
          continue;
        }
        block((p0 - c).angle, (p1 - c).angle);
      }
    }
    for (final q in points) {
      final d = q.position.distanceTo(c);
      if (d <= q.radius) return (0, 0);
      if (d - q.radius >= r) continue;
      final half = math.asin((q.radius / d).clamp(0.0, 1.0));
      final a = (q.position - c).angle;
      block(a - half, a + half);
    }
    bool freeAt(double ang) => inside(c + Pt.polar(r / 2, ang));
    if (blocks.isEmpty) return freeAt(0) ? (0, twoPi) : (0, 0);
    blocks.sort((x, y) => x.$1.compareTo(y.$1));
    final merged = <(double, double)>[];
    for (final bl in blocks) {
      if (merged.isNotEmpty && bl.$1 <= merged.last.$2 + 1e-12) {
        merged[merged.length - 1] = (merged.last.$1, math.max(merged.last.$2, bl.$2));
      } else {
        merged.add(bl);
      }
    }
    // a block running past 2π covers the start of the circle
    while (merged.length > 1 && merged.first.$1 + twoPi <= merged.last.$2 + 1e-12) {
      merged[merged.length - 1] = (merged.last.$1, math.max(merged.last.$2, merged.first.$2 + twoPi));
      merged.removeAt(0);
    }
    var bestS = 0.0, bestW = 0.0;
    for (var i = 0; i < merged.length; i++) {
      final s = merged[i].$2;
      final e = i + 1 < merged.length ? merged[i + 1].$1 : merged.first.$1 + twoPi;
      final w = e - s;
      if (w <= bestW + 1e-12) continue;
      if (freeAt(s + w / 2)) {
        bestS = s % twoPi;
        bestW = w;
      }
    }
    return (bestS, bestW);
  }
}

/// Centre and radius of the largest circle in [field] clear of the
/// obstacles of [o] (within [PivotFitOptions.precision]).
(Pt, double) pivotInscribedCircle(List<Pt> field, PivotFitOptions o) {
  final f = _Field(field, o);
  if (f.region.isEmpty) return (Pt.zero, 0);
  final hint = polygonCentroid(f.region.outline);
  return poleOfInaccessibility(f.region.bounds, f.signedDistance, precision: math.max(1e-3, o.precision), hint: f.inside(hint) ? hint : null);
}

/// The largest full-circle pivot in [field]: at the centre of the largest
/// inscribed circle, the longest machine whose wetted radius fits.
PivotFit fitFullCirclePivot(List<Pt> field, PivotFitOptions o) {
  final f = _Field(field, o);
  final area = f.region.area;
  if (f.region.isEmpty) {
    return PivotFit(center: Pt.zero, availableRadius: 0, spans: null, endThrowM: o.endThrowM, sectorStartDeg: 0, sectorSweepDeg: 360, fieldArea: 0, messages: const ['pivot_field_empty']);
  }
  final (c, r) = pivotInscribedCircle(field, o);
  final spans = snapPivotLength(r - o.endThrowM, spans: o.spanLengths, overhangs: o.overhangs, minSpans: o.minSpans, maxSpans: o.maxSpans);
  return PivotFit(
    center: c,
    availableRadius: r,
    spans: spans,
    endThrowM: o.endThrowM,
    sectorStartDeg: 0,
    sectorSweepDeg: 360,
    fieldArea: area,
    messages: spans == null ? const ['pivot_no_room'] : const [],
  );
}

/// The part-circle (or full-circle) pivot of [field] irrigating the most
/// area: the best centre, machine and sector of a grid of centres, the
/// corners and edges of the field and the pole of inaccessibility, refined
/// by a pattern search.
PivotFit fitSectorPivot(List<Pt> field, PivotFitOptions o) {
  final f = _Field(field, o);
  final fieldArea = f.region.area;
  if (f.region.isEmpty) {
    return PivotFit(center: Pt.zero, availableRadius: 0, spans: null, endThrowM: o.endThrowM, sectorStartDeg: 0, sectorSweepDeg: 0, fieldArea: 0, messages: const ['pivot_field_empty']);
  }
  final b = f.region.bounds;
  final diag = math.sqrt(b.width * b.width + b.height * b.height);
  // machines that may fit: up to the diagonal of the field, at most 32
  // lengths spread over the range
  final all = [
    for (final c in pivotLengthOptions(spans: o.spanLengths, overhangs: o.overhangs, minSpans: o.minSpans, maxSpans: o.maxSpans))
      if (c.length + o.endThrowM <= diag) c,
  ];
  if (all.isEmpty) {
    return PivotFit(center: Pt.zero, availableRadius: 0, spans: null, endThrowM: o.endThrowM, sectorStartDeg: 0, sectorSweepDeg: 0, fieldArea: fieldArea, messages: const ['pivot_no_room']);
  }
  final lengths = all.length <= 32 ? all : [for (var i = 0; i < 32; i++) all[(i * (all.length - 1) / 31).round()]];
  final minSweep = degToRad(o.minSweepDeg.clamp(0.0, 360.0));
  (double, double, double, int) evaluate(Pt c) {
    // (area, start, sweep, length index), the best radius for this centre
    var best = (0.0, 0.0, 0.0, -1);
    if (!f.inside(c) && !f.region.loops.any((l) => l.nearest(c).$2 < 1e-6)) return best;
    for (var k = 0; k < lengths.length; k++) {
      final r = lengths[k].length + o.endThrowM;
      final (s, w) = f.sector(c, r);
      if (w < minSweep - 1e-9) continue;
      final a = w / 2 * r * r;
      if (a > best.$1 + 1e-9) best = (a, s, w, k);
    }
    return best;
  }

  final cands = <Pt>[];
  final n = math.max(4, o.searchCells);
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final p = Pt(b.minX + (i + 0.5) * b.width / n, b.minY + (j + 0.5) * b.height / n);
      if (f.inside(p)) cands.add(p);
    }
  }
  for (final l in f.region.loops) {
    for (var i = 0; i < l.vertexCount; i++) {
      cands
        ..add(l.points[i])
        ..add(Pt.lerp(l.points[i], l.vertex(i + 1), 0.5));
    }
  }
  final (pole, _) = pivotInscribedCircle(field, o);
  cands.add(pole);
  final scored = [for (final c in cands) (c, evaluate(c))]..sort((x, y) => y.$2.$1 != x.$2.$1 ? y.$2.$1.compareTo(x.$2.$1) : (x.$1.x != y.$1.x ? x.$1.x.compareTo(y.$1.x) : x.$1.y.compareTo(y.$1.y)));
  var bestC = scored.first.$1;
  var best = scored.first.$2;
  // pattern search from the three best centres
  for (final (start, score) in scored.take(3)) {
    var c = start;
    var cur = score;
    var step = math.max(b.width, b.height) / n;
    while (step > o.precision / 2) {
      var moved = false;
      for (final (dx, dy) in const [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0), (0.7071, 0.7071), (-0.7071, 0.7071), (0.7071, -0.7071), (-0.7071, -0.7071)]) {
        final q = Pt(c.x + dx * step, c.y + dy * step);
        final e = evaluate(q);
        if (e.$1 > cur.$1 + 1e-6) {
          c = q;
          cur = e;
          moved = true;
        }
      }
      if (!moved) step /= 2;
    }
    if (cur.$1 > best.$1 + 1e-6) {
      best = cur;
      bestC = c;
    }
  }
  if (best.$4 < 0) {
    return PivotFit(center: bestC, availableRadius: 0, spans: null, endThrowM: o.endThrowM, sectorStartDeg: 0, sectorSweepDeg: 0, fieldArea: fieldArea, messages: const ['pivot_no_room']);
  }
  final machine = lengths[best.$4];
  final sweep = radToDeg(best.$3);
  return PivotFit(
    center: bestC,
    availableRadius: machine.length + o.endThrowM,
    spans: machine,
    endThrowM: o.endThrowM,
    sectorStartDeg: sweep >= 360 - 1e-6 ? 0 : normalizeDeg(radToDeg(best.$2)),
    sectorSweepDeg: sweep >= 360 - 1e-6 ? 360 : sweep,
    fieldArea: fieldArea,
    messages: const [],
  );
}
