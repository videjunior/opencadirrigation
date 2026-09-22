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
  BlockResult({required this.laterals, required this.submain, required this.valve, required this.stub, this.branches = const []});
  final List<Entity> laterals;
  final PipeEntity? submain;
  final ControlValveEntity? valve;
  final PipeEntity? stub;

  /// Submain branches feeding the laterals of rows the polygon cuts in
  /// several pieces (a U-shaped block, a curved row clipped in two), joined
  /// to [submain].
  final List<PipeEntity> branches;
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
List<(double, double)> _clipLine(List<Pt> poly, Pt origin, Pt dir) {
  final ts = <double>[];
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    final e = b - a;
    final denom = dir.cross(e);
    if (denom.abs() < 1e-12) continue;
    final ao = a - origin;
    final t = ao.cross(e) / denom;
    final u = ao.cross(dir) / denom;
    if (u >= -1e-9 && u <= 1 + 1e-9) ts.add(t);
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
          laterals.add(SpraylineEntity(id: project.newId(), name: '${o.lateralPrefix}$idx', points: [s, e], pipeSpecId: o.lateralPipeSpecId, computerSized: o.lateralPipeSpecId == null, outletSpecId: o.outletSpecId ?? '', nozzleId: o.nozzleId, headM: o.headM, spacing: o.outletSpacing, offset: o.outletOffsetHalf ? o.outletSpacing / 2 : 0));
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
/// [main]; the stub leaves the block along [outward].
BlockResult _finishBlock(Project project, BlockOptions o, String zone, List<Entity> laterals, List<Pt> main, List<List<Pt>> branchLines, Pt outward) {
  PipeEntity pipe(String name, List<Pt> pts) => PipeEntity(id: project.newId(), name: name, points: pts, scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  final submain = main.length >= 2 && polylineLength(main) > 1e-6 ? pipe('${o.submainLabel} $zone', main) : null;
  final branches = [for (var k = 0; k < branchLines.length; k++) pipe('${o.submainLabel} $zone (${k + 2})', branchLines[k])];
  final anchor = switch (o.valvePosition) {
    ValvePosition.start => main.first,
    ValvePosition.centre => pointAlongPolyline(main, polylineLength(main) / 2),
    ValvePosition.end => main.last,
  };
  PipeEntity? stub;
  var valvePos = anchor;
  if (o.submainStub > 0) {
    valvePos = anchor + outward * o.submainStub;
    stub = pipe('${o.stubLabel} $zone', [valvePos, anchor]);
  }
  final valve = ControlValveEntity(id: project.newId(), name: zone, position: valvePos, valveSpecId: o.valveSpecId, zoneName: zone);
  return BlockResult(laterals: laterals, submain: submain, valve: valve, stub: stub, branches: branches);
}

enum GridPattern { square, triangular }

class SprinklerGridOptions {
  SprinklerGridOptions({required this.polygon, required this.outletSpecId, this.nozzleId, required this.spacingAlong, required this.spacingBetween, this.pattern = GridPattern.square, this.direction = const Pt(1, 0), this.headM = 25, this.scope = HydraulicScope.zone});
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

/// Block whose laterals are offsets of a guide polyline (curved laterals).
BlockResult _generateGuidedBlock(Project project, BlockOptions o) {
  final guide = o.guide!;
  final poly = o.polygon;
  if (poly.length < 3) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  final dir = (guide.last - guide.first).normalized;
  final perp = dir.length == 0 ? const Pt(0, 1) : dir.perpendicular;
  // offsets needed to cover the polygon on both sides of the guide
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in poly) {
    final v = (p - guide.first).dot(perp);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
  }
  if ((vMax - vMin) / o.lateralSpacing > maxBlockRows) return BlockResult(laterals: const [], submain: null, valve: null, stub: null);
  final first = o.firstLateralOffset ?? o.lateralSpacing / 2;
  final zone = o.zoneName ?? project.uniqueZoneName();
  final laterals = <Entity>[];
  final rows = <List<_Feed>>[];
  var idx = 0;
  final g0 = guide.first;
  for (var v = vMin + first; v <= vMax - first / 2 + 1e-9; v += o.lateralSpacing) {
    final line = offsetPolyline(guide, v);
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
      row.add((p: feed, u: (feed - g0).dot(dir), v: v));
      for (final pts in parts) {
        if (polylineLength(pts) < 1e-6) continue;
        idx++;
        if (o.isTape) {
          laterals.add(TapeEntity(id: project.newId(), name: '${o.lateralPrefix}$idx', points: pts, tapeSpecId: o.tapeSpecId ?? '', inletHeadM: o.tapeInletHeadM));
        } else {
          laterals.add(SpraylineEntity(id: project.newId(), name: '${o.lateralPrefix}$idx', points: pts, pipeSpecId: o.lateralPipeSpecId, computerSized: o.lateralPipeSpecId == null, outletSpecId: o.outletSpecId ?? '', nozzleId: o.nozzleId, headM: o.headM, spacing: o.outletSpacing, offset: o.outletOffsetHalf ? o.outletSpacing / 2 : 0));
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
  return _finishBlock(project, o, zone, laterals, main, branchLines, o.submainPosition == SubmainPosition.end ? dir : -dir);
}
