/// Lengthen (1.6.0 CAD): changes the length of an open item at one of its
/// ends — by a difference, to a total length, or to a percentage of its
/// length — as the LENGTHEN command of CAD programs. A longer item grows
/// along the direction of its end segment (an arc along its circle); a
/// shorter one is cut back along its path. The outlets of a spray lateral
/// stay where they were (the pattern goes on into a part added at the
/// start).
library;

import 'dart:math' as math;

import 'entities.dart';
import 'geometry.dart';
import 'split.dart';

/// How [lengthenEntity] reads its value: metres added (negative takes
/// away), the new total length in metres, or the new length as a
/// percentage of the present one.
enum LengthenMode { delta, total, percent }

/// Whether [e] can be lengthened: lines, arcs and the open polyline items
/// (polylines, pipes, spray laterals, tapes, wires, contours).
bool canLengthen(Entity e) => switch (e) {
  LineEntity _ || ArcEntity _ || PipeEntity _ || SpraylineEntity _ || TapeEntity _ || WireEntity _ => true,
  PolylineEntity p => !p.closed,
  ContourEntity _ => true,
  _ => false,
};

/// The length of [e] as [lengthenEntity] measures it (an arc along its
/// circle), or null when it cannot be lengthened.
double? lengthOfLengthenable(Entity e) {
  if (!canLengthen(e)) return null;
  if (e is ArcEntity) return e.length;
  final pts = e.linearPoints;
  return pts == null || pts.length < 2 ? null : polylineLength(pts);
}

/// The new length [mode] and [value] give an item of length [length], or
/// null when it is not a length (not a number, zero or less).
double? lengthenTarget(double length, LengthenMode mode, double value) {
  if (!value.isFinite) return null;
  final l = switch (mode) {
    LengthenMode.delta => length + value,
    LengthenMode.total => value,
    LengthenMode.percent => length * value / 100,
  };
  return l > 1e-6 && l.isFinite ? l : null;
}

/// A copy of [e] with the end nearest to [near] moved so that its length
/// becomes what [mode] and [value] ask for (see [LengthenMode]); null when
/// [e] cannot be lengthened or the new length is not above zero.
Entity? lengthenEntity(Entity e, Pt near, LengthenMode mode, double value) {
  final length = lengthOfLengthenable(e);
  if (length == null || length < 1e-9) return null;
  final target = lengthenTarget(length, mode, value);
  if (target == null) return null;
  final d = target - length;
  if (d.abs() < 1e-9) return e.clone();
  if (e is ArcEntity) return _arc(e, near, target);
  final pts = e.linearPoints!;
  final atEnd = pts.last.distanceTo(near) <= pts.first.distanceTo(near);
  if (d > 0) return _grow(e, pts, atEnd, d);
  return _shrink(e, pts, atEnd, target, length);
}

/// An arc whose sweep makes it [target] long, grown or cut back at the end
/// nearest to [near] (a whole circle at most).
ArcEntity? _arc(ArcEntity a, Pt near, double target) {
  if (a.radius < 1e-9) return null;
  final sweep = target / a.radius;
  if (sweep >= 2 * math.pi - 1e-9) return null;
  final sign = a.sweepRad < 0 ? -1.0 : 1.0;
  final atEnd = a.endPoint.distanceTo(near) <= a.startPoint.distanceTo(near);
  final c = a.clone();
  if (atEnd) {
    c.sweepRad = sign * sweep;
  } else {
    // the end stays: the start moves back along the circle
    final end = a.startRad + a.sweepRad;
    c
      ..sweepRad = sign * sweep
      ..startRad = end - sign * sweep;
  }
  return c;
}

/// [e] with its end (the last vertex when [atEnd], else the first) moved
/// [d] metres further along the direction of its end segment.
Entity? _grow(Entity e, List<Pt> pts, bool atEnd, double d) {
  final tip = atEnd ? pts.last : pts.first;
  // the direction of the end segment (a zero-length one is skipped)
  Pt dir = Pt.zero;
  if (atEnd) {
    for (var i = pts.length - 2; i >= 0 && dir.length == 0; i--) {
      dir = (tip - pts[i]).normalized;
    }
  } else {
    for (var i = 1; i < pts.length && dir.length == 0; i++) {
      dir = (tip - pts[i]).normalized;
    }
  }
  if (dir.length == 0) return null;
  final to = tip + dir * d;
  final c = e.clone();
  switch (c) {
    case LineEntity l:
      if (atEnd) {
        l.b = to;
      } else {
        l.a = to;
      }
    case PolyEntity p:
      p.points[atEnd ? p.points.length - 1 : 0] = to;
      // the outlets keep their places: the pattern goes on into the part added
      if (c is SpraylineEntity && !atEnd && c.spacing > 0) {
        final first = c.firstOutletDistance + d;
        final k = ((first - 1e-9) / c.spacing).floor();
        c.offset = math.max(first - k * c.spacing, 1e-9);
      }
    default:
      return null;
  }
  return c;
}

/// [e] cut back to [target] metres, the part at its end (the last vertex
/// when [atEnd], else the first) taken away.
Entity? _shrink(Entity e, List<Pt> pts, bool atEnd, double target, double length) {
  final station = atEnd ? target : length - target;
  if (e is SpraylineEntity) {
    // the split keeps the outlets in place (the offset of the piece kept)
    var n = 0;
    final pieces = splitLinearEntity(e, [station], () => '#lengthen${n++}');
    if (pieces.length != 2) return null;
    return (atEnd ? pieces.first : pieces.last).clone(newId: e.id)..name = e.name;
  }
  final parts = splitPolylineAt(pts, [station]);
  if (parts.length != 2) return null;
  final keep = atEnd ? parts.first : parts.last;
  final c = e.clone();
  switch (c) {
    case LineEntity l:
      l
        ..a = keep.first
        ..b = keep.last;
    case PolyEntity p:
      p.points
        ..clear()
        ..addAll(keep);
    default:
      return null;
  }
  return c;
}
