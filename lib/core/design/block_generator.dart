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
  BlockResult({required this.laterals, required this.submain, required this.valve, required this.stub});
  final List<Entity> laterals;
  final PipeEntity? submain;
  final ControlValveEntity? valve;
  final PipeEntity? stub;
  List<Entity> get all => [...laterals, ?submain, ?stub, ?valve];
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

BlockResult generateBlock(Project project, BlockOptions o) {
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
  final first = o.firstLateralOffset ?? o.lateralSpacing / 2;
  final uSub = switch (o.submainPosition) {
    SubmainPosition.start => uMin,
    SubmainPosition.centre => (uMin + uMax) / 2,
    SubmainPosition.end => uMax,
  };
  final laterals = <Entity>[];
  final submainPts = <Pt>[];
  final zone = o.zoneName ?? project.uniqueZoneName();
  var idx = 0;
  for (var v = vMin + first; v <= vMax - first / 2 + 1e-9; v += o.lateralSpacing) {
    final origin = perp * v;
    final intervals = _clipLine(poly, origin, dir);
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
      submainPts.add(feed);
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
  }
  if (submainPts.isEmpty) return BlockResult(laterals: laterals, submain: null, valve: null, stub: null);
  // submain along perp axis at u = uSub, from first to last feed point
  submainPts.sort((p, q) => p.dot(perp).compareTo(q.dot(perp)));
  final subStart = submainPts.first;
  final subEnd = submainPts.last;
  PipeEntity? submain;
  if (subStart.distanceTo(subEnd) > 1e-6) {
    submain = PipeEntity(id: project.newId(), name: '${o.submainLabel} $zone', points: [subStart, subEnd], scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  }
  final valveAnchor = switch (o.valvePosition) {
    ValvePosition.start => subStart,
    ValvePosition.centre => Pt.lerp(subStart, subEnd, 0.5),
    ValvePosition.end => subEnd,
  };
  // stub goes away from the block (towards -dir if submain at start, +dir if at end, else -dir)
  final outward = o.submainPosition == SubmainPosition.end ? dir : -dir;
  PipeEntity? stub;
  Pt valvePos = valveAnchor;
  if (o.submainStub > 0) {
    valvePos = valveAnchor + outward * o.submainStub;
    stub = PipeEntity(id: project.newId(), name: '${o.stubLabel} $zone', points: [valvePos, valveAnchor], scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  }
  final valve = ControlValveEntity(id: project.newId(), name: zone, position: valvePos, valveSpecId: o.valveSpecId, zoneName: zone);
  return BlockResult(laterals: laterals, submain: submain, valve: valve, stub: stub);
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
  if (poly.length < 3) return const [];
  var vMin = double.infinity, vMax = -double.infinity, uMin = double.infinity, uMax = -double.infinity;
  for (final p in poly) {
    final v = p.dot(perp), u = p.dot(dir);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
    uMin = math.min(uMin, u);
    uMax = math.max(uMax, u);
  }
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
  final first = o.firstLateralOffset ?? o.lateralSpacing / 2;
  final zone = o.zoneName ?? project.uniqueZoneName();
  final laterals = <Entity>[];
  final feeds = <(double, Pt)>[];
  var idx = 0;
  for (var v = vMin + first; v <= vMax - first / 2 + 1e-9; v += o.lateralSpacing) {
    final line = offsetPolyline(guide, v);
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
      feeds.add((v, feed));
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
  }
  if (feeds.isEmpty) return BlockResult(laterals: laterals, submain: null, valve: null, stub: null);
  feeds.sort((a, b) => a.$1.compareTo(b.$1));
  final subPts = feeds.map((f) => f.$2).toList();
  PipeEntity? submain;
  if (subPts.length >= 2 && polylineLength(subPts) > 1e-6) {
    submain = PipeEntity(id: project.newId(), name: '${o.submainLabel} $zone', points: subPts, scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  }
  final anchor = switch (o.valvePosition) {
    ValvePosition.start => subPts.first,
    ValvePosition.centre => pointAlongPolyline(subPts, polylineLength(subPts) / 2),
    ValvePosition.end => subPts.last,
  };
  final outward = o.submainPosition == SubmainPosition.end ? dir : -dir;
  PipeEntity? stub;
  var valvePos = anchor;
  if (o.submainStub > 0) {
    valvePos = anchor + outward * o.submainStub;
    stub = PipeEntity(id: project.newId(), name: '${o.stubLabel} $zone', points: [valvePos, anchor], scope: HydraulicScope.zone, pipeSpecId: o.submainPipeSpecId, computerSized: o.submainPipeSpecId == null);
  }
  final valve = ControlValveEntity(id: project.newId(), name: zone, position: valvePos, valveSpecId: o.valveSpecId, zoneName: zone);
  return BlockResult(laterals: laterals, submain: submain, valve: valve, stub: stub);
}
