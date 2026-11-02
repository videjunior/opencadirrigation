/// Generators for blocks of laterals (spray / tape irrigation blocks) and
/// automatic sprinkler grids inside a polygon.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';

enum SubmainPosition { start, centre, end }

enum ValvePosition { start, centre, end }

class BlockOptions {
  BlockOptions({
    required this.polygon,
    required this.direction,
    required this.lateralSpacing,
    this.firstLateralOffset,
    this.isTape = false,
    this.tapeSpecId,
    this.outletSpecId,
    this.nozzleId,
    this.outletSpacing = 4,
    this.outletOffsetHalf = true,
    this.headM = 15,
    this.tapeInletHeadM = 10,
    this.lateralPipeSpecId,
    this.submainPipeSpecId,
    this.submainPosition = SubmainPosition.start,
    this.valveSpecId,
    this.valvePosition = ValvePosition.centre,
    this.submainStub = 1.5,
    this.zoneName,
    this.submainLabel = 'Submain',
    this.stubLabel = 'Stub',
    this.lateralPrefix = 'L',
    this.guide,
  });

  final List<Pt> polygon;

  /// Optional guide polyline: laterals follow its shape (offset copies every
  /// [lateralSpacing], clipped to the polygon) instead of straight lines
  /// along [direction] — spray lines that follow the contours.
  final List<Pt>? guide;

  /// Unit direction of the laterals.
  final Pt direction;
  final double lateralSpacing;
  final double? firstLateralOffset;
  final bool isTape;
  final String? tapeSpecId;
  final String? outletSpecId;
  final String? nozzleId;
  final double outletSpacing;
  final bool outletOffsetHalf;
  final double headM;
  final double tapeInletHeadM;
  final String? lateralPipeSpecId;
  final String? submainPipeSpecId;
  final SubmainPosition submainPosition;
  final String? valveSpecId;
  final ValvePosition valvePosition;
  final double submainStub;
  final String? zoneName;
  final String submainLabel;
  final String stubLabel;
  final String lateralPrefix;
}

class BlockResult {
  BlockResult({required this.laterals, required this.submain, required this.valve, required this.stub, this.branches = const [], this.messages = const []});
  final List<Entity> laterals;
  final PipeEntity? submain;
  final ControlValveEntity? valve;
  final PipeEntity? stub;

  /// Submain branches feeding the laterals of rows the polygon cuts in
  /// several pieces (a U-shaped block, a curved row clipped in two), joined
  /// to [submain].
  final List<PipeEntity> branches;

  /// Codes: `block_uncovered:<percent> %` (part of the polygon farther than
  /// one lateral spacing from every lateral of a guided block).
  final List<String> messages;
  List<Entity> get all => [...laterals, ?submain, ...branches, ?stub, ?valve];
}

/// The feed point of one lateral: world point and coordinates along the
/// laterals (u) and across them (v).
typedef _Feed = ({Pt p, double u, double v});

/// Submain lines through the feed points of a block's rows (rows sorted by
/// v, each with its feeds). The main line takes, row by row, the feed
/// nearest [uRef] (the submain side); where it jumps between two rows it
/// steps across the gap between them when a straight run would leave the
/// polygon. The other feeds (rows cut in several pieces) form branches,
/// each joined to the main line across the gap next to it. [at] maps (u, v)
/// to world coordinates.
(List<Pt>, List<List<Pt>>) _submainLines(List<List<_Feed>> rows, List<Pt> poly, {required double uRef, required double spacing, required Pt Function(double u, double v) at}) {
  bool inside(Pt a, Pt b) {
    for (var k = 1; k < 8; k++) {
      final q = Pt.lerp(a, b, k / 8);
      if (!pointInPolygon(q, poly) && !_onBoundary(q, poly, 1e-6)) return false;
    }
    return true;
  }

  /// From feed [a] to feed [b] of the next row: straight, or stepping at
  /// the middle of the gap between the rows.
  List<Pt> link(_Feed a, _Feed b) {
    if (inside(a.p, b.p)) return [b.p];
    final vm = (a.v + b.v) / 2;
    final c1 = at(a.u, vm), c2 = at(b.u, vm);
    if (inside(a.p, c1) && inside(c1, c2) && inside(c2, b.p)) return [c1, c2, b.p];
    return [b.p];
  }

  List<Pt> simplify(List<Pt> pts) {
    final out = <Pt>[];
    for (final q in pts) {
      if (out.isNotEmpty && out.last.distanceTo(q) < 1e-9) continue;
      // drop the middle one of three collinear points
      if (out.length >= 2 && ((out.last - out[out.length - 2]).cross(q - out.last)).abs() < 1e-9 && (out.last - out[out.length - 2]).dot(q - out.last) > 0) out.removeLast();
      out.add(q);
    }
    return out;
  }

  final primary = <_Feed>[];
  final secondary = <List<_Feed>>[];
  for (final r in rows) {
    final sorted = List.of(r)..sort((a, b) => (a.u - uRef).abs().compareTo((b.u - uRef).abs()));
    primary.add(sorted.first);
    secondary.add(sorted.sublist(1));
  }
  final main = <Pt>[primary.first.p];
  for (var i = 1; i < primary.length; i++) {
    main.addAll(link(primary[i - 1], primary[i]));
  }
  // chains of feeds of the extra pieces, row after row
  final chains = <(int, List<_Feed>)>[];
  for (var i = 0; i < rows.length; i++) {
    for (final f in secondary[i]) {
      (int, List<_Feed>)? best;
      var bd = double.infinity;
      for (final ch in chains) {
        if (ch.$1 + ch.$2.length != i) continue;
        final d = (ch.$2.last.u - f.u).abs();
        if (d < bd && d <= 3 * spacing) {
          bd = d;
          best = ch;
        }
      }
      if (best != null) {
        best.$2.add(f);
      } else {
        chains.add((i, [f]));
      }
    }
  }
  final branches = <List<Pt>>[];
  for (final (first, chain) in chains) {
    final pts = <Pt>[chain.first.p];
    for (var k = 1; k < chain.length; k++) {
      pts.addAll(link(chain[k - 1], chain[k]));
    }
    // join the main line at the row before the chain, else the one after
    final last = first + chain.length - 1;
    if (first > 0) {
      final join = link(primary[first - 1], chain.first); // ends at the chain's first feed
      pts.insertAll(0, [primary[first - 1].p, ...join.take(join.length - 1)]);
    } else if (last + 1 < primary.length) {
      pts.addAll(link(chain.last, primary[last + 1]));
    }
    // a join that runs along the main line starts where it leaves it
    bool onMain(Pt q) {
      for (var k = 1; k < main.length; k++) {
        if (distanceToSegment(q, main[k - 1], main[k]) < 1e-6) return true;
      }
      return false;
    }

    final line = simplify(pts);
    while (line.length > 2 && onMain(line[0]) && onMain(line[1]) && onMain(Pt.lerp(line[0], line[1], 0.5))) {
      line.removeAt(0);
    }
    while (line.length > 2 && onMain(line.last) && onMain(line[line.length - 2]) && onMain(Pt.lerp(line.last, line[line.length - 2], 0.5))) {
      line.removeLast();
    }
    if (line.length >= 2) branches.add(line);
  }
  return (simplify(main), branches);
}

/// Clips the infinite line through [origin] with direction [dir] against the
/// polygon and returns the parameter intervals (t along dir) inside it.
/// An edge crosses the line only when its ends lie on opposite sides of it
/// (a vertex on the line counts on one side only), so a row through a
/// vertex of the outline is cut once there, not twice.
List<(double, double)> _clipLine(List<Pt> poly, Pt origin, Pt dir) {
  final ts = <double>[];
  final n = dir.perpendicular;
  final v0 = origin.dot(n), u0 = origin.dot(dir);
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    final va = a.dot(n) - v0, vb = b.dot(n) - v0;
    if ((va > 0) == (vb > 0)) continue;
    final ua = a.dot(dir) - u0, ub = b.dot(dir) - u0;
    ts.add(ua + (ub - ua) * va / (va - vb));
  }
  ts.sort();
  final out = <(double, double)>[];
  for (var i = 0; i + 1 < ts.length; i += 2) {
    if (ts[i + 1] - ts[i] > 1e-6) {
      // check midpoint inside
      final mid = origin + dir * ((ts[i] + ts[i + 1]) / 2);
      if (pointInPolygon(mid, poly)) out.add((ts[i], ts[i + 1]));
    }
  }
  return out;
}

/// Most rows of laterals a block gets (a spacing typed far too small would
/// otherwise stall the page).
const maxBlockRows = 5000;

BlockResult generateBlock(Project project, BlockOptions o) {
  if (!(o.lateralSpacing > 0) || !o.lateralSpacing.isFinite) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  if (o.guide != null && o.guide!.length >= 2) return _generateGuidedBlock(project, o);
  final dir = o.direction.normalized;
  final perp = dir.perpendicular;
  final poly = o.polygon;
  if (poly.length < 3) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  // extent along perp axis (v) and dir axis (u)
  var vMin = double.infinity, vMax = -double.infinity, uMin = double.infinity, uMax = -double.infinity;
  for (final p in poly) {
    final v = p.dot(perp), u = p.dot(dir);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
    uMin = math.min(uMin, u);
    uMax = math.max(uMax, u);
  }
  if ((vMax - vMin) / o.lateralSpacing > maxBlockRows) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  final first = o.firstLateralOffset ?? o.lateralSpacing / 2;
  final uSub = switch (o.submainPosition) {
    SubmainPosition.start => uMin,
    SubmainPosition.centre => (uMin + uMax) / 2,
    SubmainPosition.end => uMax,
  };
  final laterals = <Entity>[];
  final rows = <List<_Feed>>[];
  final zone = o.zoneName ?? project.uniqueZoneName();
  var idx = 0;
  for (var v = vMin + first; v <= vMax - first / 2 + 1e-9; v += o.lateralSpacing) {
    final origin = perp * v;
    final intervals = _clipLine(poly, origin, dir);
    final row = <_Feed>[];
    for (final (t0, t1) in intervals) {
      final a = origin + dir * t0;
      final b = origin + dir * t1;
      // split at the submain if it crosses inside
      final segs = <(Pt, Pt)>[];
      final crosses = uSub > t0 + 1e-6 && uSub < t1 - 1e-6;
      final feed = origin + dir * uSub.clamp(t0, t1);
      if (crosses) {
        segs.add((feed, a));
        segs.add((feed, b));
      } else if ((uSub - t0).abs() <= (uSub - t1).abs()) {
        segs.add((a, b));
      } else {
        segs.add((b, a));
      }
      row.add((p: feed, u: uSub.clamp(t0, t1), v: v));
      for (final (s, e) in segs) {
        if (s.distanceTo(e) < 1e-6) continue;
        idx++;
        if (o.isTape) {
          laterals.add(TapeEntity(id: project.newId(), name: '${o.lateralPrefix}$idx', points: [s, e], tapeSpecId: o.tapeSpecId ?? '', inletHeadM: o.tapeInletHeadM));
        } else {
          laterals.add(
            SpraylineEntity(
              id: project.newId(),
              name: '${o.lateralPrefix}$idx',
              points: [s, e],
              pipeSpecId: o.lateralPipeSpecId,
              computerSized: o.lateralPipeSpecId == null,
              outletSpecId: o.outletSpecId ?? '',
              nozzleId: o.nozzleId,
              headM: o.headM,
              spacing: o.outletSpacing,
              offset: o.outletOffsetHalf ? o.outletSpacing / 2 : 0,
            ),
          );
        }
      }
    }
    if (row.isNotEmpty) rows.add(row);
  }
  if (rows.isEmpty) return BlockResult(laterals: laterals, submain: null, valve: null, stub: null);
  // the submain runs across the rows at u = uSub, following the polygon
  // where a row does not reach that line (an L-shaped block)
  final (main, branchLines) = _submainLines(rows, poly, uRef: uSub, spacing: o.lateralSpacing, at: (u, v) => dir * u + perp * v);
  return _finishBlock(project, o, zone, laterals, main, branchLines, o.submainPosition == SubmainPosition.end ? dir : -dir);
}

/// Submain, branches, valve and stub of a block whose submain runs through
/// [main]; the stub leaves the block along [outward]. With the submain in
/// the middle of the block laterals leave it both ways, so the stub runs on
/// along the submain out of the block (valve at its start or end), or, with
/// the valve in the middle, starts between two rows instead of on the feed
/// of one (it would lie on that row's lateral).
BlockResult _finishBlock(Project project, BlockOptions o, String zone, List<Entity> laterals, List<Pt> main, List<List<Pt>> branchLines, Pt outward, {List<String> messages = const []}) {
  PipeEntity pipe(String name, List<Pt> pts) =>
      PipeEntity(id: project.newId(), name: name, points: pts, scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  final submain = main.length >= 2 && polylineLength(main) > 1e-6 ? pipe('${o.submainLabel} $zone', main) : null;
  final branches = [for (var k = 0; k < branchLines.length; k++) pipe('${o.submainLabel} $zone (${k + 2})', branchLines[k])];
  final total = polylineLength(main);
  final centred = o.submainPosition == SubmainPosition.centre && main.length >= 2 && total > 1e-6;
  var anchor = switch (o.valvePosition) {
    ValvePosition.start => main.first,
    ValvePosition.centre => pointAlongPolyline(main, total / 2),
    ValvePosition.end => main.last,
  };
  var away = outward;
  if (centred) {
    switch (o.valvePosition) {
      case ValvePosition.start:
        away = (main.first - main[1]).normalized;
      case ValvePosition.end:
        away = (main.last - main[main.length - 2]).normalized;
      case ValvePosition.centre:
        // the feeds along the submain (the first point of every lateral on
        // it): the anchor goes half way to the next feed when it sits on one
        final stations = <double>[
          for (final l in laterals)
            if (l is PolyEntity && l.points.isNotEmpty)
              if (polylineStationOf(main, l.points.first) case (final s, final q) when q.distanceTo(l.points.first) < 1e-6) s,
        ]..sort();
        final at = total / 2;
        final gap = o.lateralSpacing / 4;
        if (stations.any((s) => (s - at).abs() < gap)) {
          final after = stations.where((s) => s > at + gap).firstOrNull;
          final before = stations.lastWhere((s) => s < at - gap, orElse: () => -1);
          final next = after ?? (before >= 0 ? before : null);
          final on = stations.reduce((a, b) => (a - at).abs() <= (b - at).abs() ? a : b);
          if (next != null) anchor = pointAlongPolyline(main, (on + next) / 2);
        }
    }
  }
  PipeEntity? stub;
  var valvePos = anchor;
  if (o.submainStub > 0) {
    valvePos = anchor + away * o.submainStub;
    stub = pipe('${o.stubLabel} $zone', [valvePos, anchor]);
  }
  final valve = ControlValveEntity(id: project.newId(), name: zone, position: valvePos, valveSpecId: o.valveSpecId, zoneName: zone);
  return BlockResult(laterals: laterals, submain: submain, valve: valve, stub: stub, branches: branches, messages: messages);
}

enum GridPattern { square, triangular }

class SprinklerGridOptions {
  SprinklerGridOptions({
    required this.polygon,
    required this.outletSpecId,
    this.nozzleId,
    required this.spacingAlong,
    required this.spacingBetween,
    this.pattern = GridPattern.square,
    this.direction = const Pt(1, 0),
    this.headM = 25,
    this.scope = HydraulicScope.zone,
  });
  final List<Pt> polygon;
  final String outletSpecId;
  final String? nozzleId;
  final double spacingAlong;
  final double spacingBetween;
  final GridPattern pattern;
  final Pt direction;
  final double headM;
  final HydraulicScope scope;
}

/// Places sprinklers on a grid clipped to the polygon (automatic head layout).
List<OutletEntity> generateSprinklerGrid(Project project, SprinklerGridOptions o) {
  final dir = o.direction.normalized;
  final perp = dir.perpendicular;
  final poly = o.polygon;
  if (poly.length < 3 || !(o.spacingAlong > 0) || !(o.spacingBetween > 0)) return const [];
  var vMin = double.infinity, vMax = -double.infinity, uMin = double.infinity, uMax = -double.infinity;
  for (final p in poly) {
    final v = p.dot(perp), u = p.dot(dir);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
    uMin = math.min(uMin, u);
    uMax = math.max(uMax, u);
  }
  // a spacing typed far too small would place millions of heads
  if ((vMax - vMin) / o.spacingBetween * ((uMax - uMin) / o.spacingAlong) > 1e6) return const [];
  final out = <OutletEntity>[];
  var row = 0;
  for (var v = vMin; v <= vMax + 1e-9; v += o.spacingBetween, row++) {
    final shift = o.pattern == GridPattern.triangular && row.isOdd ? o.spacingAlong / 2 : 0.0;
    for (var u = uMin + shift; u <= uMax + 1e-9; u += o.spacingAlong) {
      final p = dir * u + perp * v;
      if (!pointInPolygon(p, poly) && !_onBoundary(p, poly)) continue;
      out.add(OutletEntity(id: project.newId(), position: p, scope: o.scope, outletSpecId: o.outletSpecId, nozzleId: o.nozzleId, headM: o.headM));
    }
  }
  return out;
}

bool _onBoundary(Pt p, List<Pt> poly, [double tol = 1e-6]) {
  for (var i = 0; i < poly.length; i++) {
    if (distanceToSegment(p, poly[i], poly[(i + 1) % poly.length]) <= tol) return true;
  }
  return false;
}

/// Signed distance from [q] to the polyline [line] (positive on its left,
/// as [offsetPolyline] counts offsets): at a vertex the side is taken from
/// the mean direction of its two segments.
double _signedDistance(Pt q, List<Pt> line) {
  var best = double.infinity, sign = 1.0;
  for (var i = 1; i < line.length; i++) {
    final a = line[i - 1], b = line[i];
    final (cp, t) = closestPointOnSegment(q, a, b);
    final d = cp.distanceTo(q);
    if (d >= best) continue;
    best = d;
    var tangent = b - a;
    if (t <= 1e-12 && i > 1) tangent = (a - line[i - 2]).normalized + tangent.normalized;
    if (t >= 1 - 1e-12 && i + 1 < line.length) tangent = tangent.normalized + (line[i + 1] - b).normalized;
    sign = tangent.cross(q - cp) >= 0 ? 1.0 : -1.0;
  }
  return best.isFinite ? best * sign : 0;
}

/// [pts] without the loops of a self-crossing offset (the swallowtail an
/// offset on the inner side of a sharp bend makes, or two arms of a U offset
/// past each other): where two segments cross, the vertices between them
/// are dropped and the crossing joins the two parts.
List<Pt> _withoutLoops(List<Pt> pts) {
  var cur = pts;
  for (var guard = 0; guard < 256; guard++) {
    final n = cur.length;
    if (n < 4) return cur;
    // segments bucketed on a grid of about one segment a cell
    final b = Bounds.ofPoints(cur);
    final cell = math.max(polylineLength(cur) / (n - 1), math.max(b.width, b.height) / 1024) + 1e-9;
    final buckets = <int, List<int>>{};
    int key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
    Iterable<int> keys(Pt a, Pt c) sync* {
      final x0 = ((math.min(a.x, c.x) - b.minX) / cell).floor(), x1 = ((math.max(a.x, c.x) - b.minX) / cell).floor();
      final y0 = ((math.min(a.y, c.y) - b.minY) / cell).floor(), y1 = ((math.max(a.y, c.y) - b.minY) / cell).floor();
      for (var ix = x0; ix <= x1; ix++) {
        for (var iy = y0; iy <= y1; iy++) {
          yield key(ix, iy);
        }
      }
    }

    for (var s = 1; s < n; s++) {
      for (final k in keys(cur[s - 1], cur[s])) {
        (buckets[k] ??= []).add(s);
      }
    }
    // the first segment that crosses a later one, and the last one it crosses
    var cutI = -1, cutJ = -1;
    Pt? at;
    for (var i = 1; i < n && cutI < 0; i++) {
      final a = cur[i - 1], c = cur[i];
      final seen = <int>{};
      for (final k in keys(a, c)) {
        for (final j in buckets[k] ?? const <int>[]) {
          if (j <= i + 1 || !seen.add(j)) continue;
          final x = segmentIntersection(a, c, cur[j - 1], cur[j], eps: 1e-12);
          if (x == null) continue;
          if (j > cutJ) {
            cutJ = j;
            at = x;
          }
        }
      }
      if (cutJ > 0) cutI = i;
    }
    if (cutI < 0 || at == null) return cur;
    cur = [...cur.sublist(0, cutI), at, ...cur.sublist(cutJ)];
  }
  return cur;
}

/// [pts] offset [d] metres to its left (negative: to its right), as
/// [offsetPolyline] does, but a bend sharper than the mitre limit (the
/// corner point farther than [mitreLimit]·|d| from the vertex) is rounded
/// on its outer side, and the loops the offset makes on the inner side of
/// tight bends are cut out: a centreline or guide that turns back stays
/// [d] from itself instead of spiking kilometres away.
List<Pt> offsetPolylineMitred(List<Pt> pts, double d, {double mitreLimit = 2}) {
  final p = <Pt>[
    for (var i = 0; i < pts.length; i++)
      if (i == 0 || pts[i].distanceTo(pts[i - 1]) > 1e-9) pts[i],
  ];
  if (p.length < 2 || d == 0) return p;
  final out = <Pt>[p.first + (p[1] - p.first).normalized.perpendicular * d];
  for (var i = 1; i + 1 < p.length; i++) {
    final e1 = (p[i] - p[i - 1]).normalized, e2 = (p[i + 1] - p[i]).normalized;
    final n1 = e1.perpendicular, n2 = e2.perpendicular;
    final m = n1 + n2;
    final c = m.length / 2; // cosine of half the turn
    if (c >= 1e-9 && 1 / c <= mitreLimit) {
      out.add(p[i] + m.normalized * (d / c));
      continue;
    }
    final turn = math.atan2(e1.cross(e2), e1.dot(e2));
    if (d * turn < 0) {
      // outer side: an arc of radius |d| round the vertex
      final a0 = (n1 * d).angle;
      final steps = math.max(2, (turn.abs() / (math.pi / 12)).ceil());
      for (var k = 0; k <= steps; k++) {
        out.add(p[i] + Pt.polar(d.abs(), a0 + turn * k / steps));
      }
    } else {
      // inner side: the two offsets cross, the loop goes below
      out
        ..add(p[i] + n1 * d)
        ..add(p[i] + n2 * d);
    }
  }
  out.add(p.last + (p.last - p[p.length - 2]).normalized.perpendicular * d);
  return _withoutLoops(out);
}

/// Share (0–1) of [poly] farther than [reach] from every polyline of
/// [lines], on a grid of about [samples] points.
double _uncoveredShare(List<Pt> poly, List<List<Pt>> lines, double reach, {int samples = 2500}) {
  final b = Bounds.ofPoints(poly);
  final area = polygonArea(poly).abs();
  if (area <= 0 || b.isEmpty) return 0;
  final h = math.max(math.sqrt(area / samples), 1e-6);
  final segs = <(Pt, Pt)>[
    for (final l in lines)
      for (var i = 1; i < l.length; i++) (l[i - 1], l[i]),
  ];
  // segments bucketed by cells of the reach, so a point looks at its own
  // cell and its neighbours only
  final cell = math.max(reach, h);
  final buckets = <int, List<int>>{};
  int key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
  for (var s = 0; s < segs.length; s++) {
    final (p, q) = segs[s];
    final x0 = ((math.min(p.x, q.x) - b.minX) / cell).floor(), x1 = ((math.max(p.x, q.x) - b.minX) / cell).floor();
    final y0 = ((math.min(p.y, q.y) - b.minY) / cell).floor(), y1 = ((math.max(p.y, q.y) - b.minY) / cell).floor();
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 100000) continue;
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        (buckets[key(ix, iy)] ??= []).add(s);
      }
    }
  }
  var inside = 0, dry = 0;
  for (var y = b.minY + h / 2; y < b.maxY; y += h) {
    for (var x = b.minX + h / 2; x < b.maxX; x += h) {
      final q = Pt(x, y);
      if (!pointInPolygon(q, poly)) continue;
      inside++;
      final ix = ((x - b.minX) / cell).floor(), iy = ((y - b.minY) / cell).floor();
      var near = false;
      for (var dx = -1; dx <= 1 && !near; dx++) {
        for (var dy = -1; dy <= 1 && !near; dy++) {
          for (final s in buckets[key(ix + dx, iy + dy)] ?? const <int>[]) {
            if (distanceToSegment(q, segs[s].$1, segs[s].$2) <= reach) {
              near = true;
              break;
            }
          }
        }
      }
      if (!near) dry++;
    }
  }
  return inside == 0 ? 0 : dry / inside;
}

/// A block of a guide leaves more than this share of its polygon farther
/// than one lateral spacing from every lateral before it says so.
const guidedUncoveredLimit = 0.02;

/// Block whose laterals are offsets of a guide polyline (curved laterals).
/// The guide is prolonged along its end segments past the polygon, and the
/// offsets run from the polygon point farthest on one side of the guide to
/// the one farthest on the other (signed distances to the guide itself, not
/// to the chord of its ends), so that a contour that bends in a valley or
/// covers only part of the field still gets laterals over all of it.
BlockResult _generateGuidedBlock(Project project, BlockOptions o) {
  final poly = o.polygon;
  final guide = <Pt>[
    for (final q in o.guide!)
      if (q.x.isFinite && q.y.isFinite) q,
  ];
  for (var i = guide.length - 1; i > 0; i--) {
    if (guide[i].distanceTo(guide[i - 1]) < 1e-9) guide.removeAt(i);
  }
  if (poly.length < 3 || guide.length < 2) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  final dir = (guide.last - guide.first).normalized;
  final perp = dir.length == 0 ? const Pt(0, 1) : dir.perpendicular;
  // the guide prolonged past the polygon on both ends
  final all = Bounds.ofPoints([...poly, ...guide]);
  final reach = 2 * math.sqrt(all.width * all.width + all.height * all.height) + 1;
  final prolonged = [guide.first - (guide[1] - guide.first).normalized * reach, ...guide, guide.last + (guide.last - guide[guide.length - 2]).normalized * reach];
  // offsets needed to cover the polygon on both sides of the guide: the
  // distance to a bent guide peaks along the edges and inside the polygon,
  // not only at its vertices, so those are sampled too
  var vMin = double.infinity, vMax = -double.infinity;
  final perimeter = polylineLength([...poly, poly.first]);
  final pb = Bounds.ofPoints(poly);
  final step = math.max(perimeter / 400, 1e-6);
  final grid = math.max(math.max(pb.width, pb.height) / 24, 1e-6);
  final samples = <Pt>[
    for (var i = 0; i < poly.length; i++) ...[
      poly[i],
      for (var k = 1, m = (poly[i].distanceTo(poly[(i + 1) % poly.length]) / step).ceil(); k < m; k++) Pt.lerp(poly[i], poly[(i + 1) % poly.length], k / m),
    ],
    for (var y = pb.minY + grid / 2; y < pb.maxY; y += grid)
      for (var x = pb.minX + grid / 2; x < pb.maxX; x += grid)
        if (pointInPolygon(Pt(x, y), poly)) Pt(x, y),
  ];
  for (final p in samples) {
    final v = _signedDistance(p, prolonged);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
  }
  if ((vMax - vMin) / o.lateralSpacing > maxBlockRows) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  final first = o.firstLateralOffset ?? o.lateralSpacing / 2;
  final zone = o.zoneName ?? project.uniqueZoneName();
  final laterals = <Entity>[];
  final rows = <List<_Feed>>[];
  final lines = <List<Pt>>[];
  var idx = 0;
  final g0 = guide.first;
  for (var v = vMin + first; v <= vMax - first / 2 + 1e-9; v += o.lateralSpacing) {
    final line = offsetPolylineMitred(prolonged, v);
    final row = <_Feed>[];
    for (final piece in clipPolylineToPolygon(line, poly, minLength: o.lateralSpacing / 4)) {
      final len = polylineLength(piece);
      // feed end (start / end / split at the middle)
      List<List<Pt>> parts;
      Pt feed;
      switch (o.submainPosition) {
        case SubmainPosition.start:
          parts = [piece];
          feed = piece.first;
        case SubmainPosition.end:
          parts = [piece.reversed.toList()];
          feed = piece.last;
        case SubmainPosition.centre:
          final halves = splitPolylineAt(piece, [len / 2]);
          feed = pointAlongPolyline(piece, len / 2);
          parts = halves.length == 2 ? [halves[0].reversed.toList(), halves[1]] : [piece];
      }
      // across the rows in the frame of the guide's chord (where the
      // submain steps between rows)
      row.add((p: feed, u: (feed - g0).dot(dir), v: (feed - g0).dot(perp)));
      for (final pts in parts) {
        if (polylineLength(pts) < 1e-6) continue;
        lines.add(pts);
        idx++;
        if (o.isTape) {
          laterals.add(TapeEntity(id: project.newId(), name: '${o.lateralPrefix}$idx', points: pts, tapeSpecId: o.tapeSpecId ?? '', inletHeadM: o.tapeInletHeadM));
        } else {
          laterals.add(
            SpraylineEntity(
              id: project.newId(),
              name: '${o.lateralPrefix}$idx',
              points: pts,
              pipeSpecId: o.lateralPipeSpecId,
              computerSized: o.lateralPipeSpecId == null,
              outletSpecId: o.outletSpecId ?? '',
              nozzleId: o.nozzleId,
              headM: o.headM,
              spacing: o.outletSpacing,
              offset: o.outletOffsetHalf ? o.outletSpacing / 2 : 0,
            ),
          );
        }
      }
    }
    if (row.isNotEmpty) rows.add(row);
  }
  if (rows.isEmpty) return BlockResult(laterals: laterals, submain: null, valve: null, stub: null);
  // the submain side along the guide: its start, its end or the middle
  var uMin = double.infinity, uMax = -double.infinity;
  for (final p in poly) {
    final u = (p - g0).dot(dir);
    uMin = math.min(uMin, u);
    uMax = math.max(uMax, u);
  }
  final uRef = switch (o.submainPosition) {
    SubmainPosition.start => uMin,
    SubmainPosition.centre => (uMin + uMax) / 2,
    SubmainPosition.end => uMax,
  };
  final (main, branchLines) = _submainLines(rows, poly, uRef: uRef, spacing: o.lateralSpacing, at: (u, v) => g0 + dir * u + perp * v);
  final dry = _uncoveredShare(poly, lines, o.lateralSpacing);
  final messages = [if (dry > guidedUncoveredLimit) 'block_uncovered:${(dry * 100).toStringAsFixed(1)} %'];
  return _finishBlock(project, o, zone, laterals, main, branchLines, o.submainPosition == SubmainPosition.end ? dir : -dir, messages: messages);
}
