/// Field subdivision: an agricultural field cut into irrigation blocks
/// (sectors) no larger than an area, or than the flow a block may draw
/// given the emitter flow per hectare, as strips along the rows or as a
/// grid that also limits the length of the laterals, with service roads
/// between the blocks and a minimum block width; every block gets the side
/// of its submain and the position of its valve, ready for the block
/// generator (`generateBlock`).
///
/// The cuts give the blocks equal net areas (the field area between two
/// cuts is integrated exactly, with the roads taken out), so that the
/// shifts draw the same flow (Keller & Bliesner 1990, chap. 17 and 21;
/// NRCS NEH 623 chap. 7: blocks of equal size, laterals no longer than the
/// pressure window allows, the submain on the side of the supply).
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import 'auto_layout.dart' show LayoutRegion, normalizePolygon, polygonSelfCrossings, simplePolygonParts;
import 'block_generator.dart';

/// How the field is cut.
enum SubdivisionMode {
  /// Strips along the rows: every block spans the field along the laterals.
  strips,

  /// Strips cut again across the rows, so that no block is longer than
  /// the laterals allow.
  grid,
}

/// Options of [subdivideField].
class FieldSubdivisionOptions {
  FieldSubdivisionOptions({
    required this.direction,
    this.mode = SubdivisionMode.strips,
    this.maxBlockArea = 0,
    this.maxBlockFlow = 0,
    this.flowPerHectare = 0,
    this.maxLateralLength = 0,
    this.centreFeed = false,
    this.minBlockWidth = 10,
    this.roadWidth = 4,
    this.pointOfConnection,
    this.submainPosition,
    this.exclusions = const [],
  });

  /// Direction of the rows (the laterals).
  final Pt direction;

  /// Ground inside the field that is not irrigated (a pond, a shed, a well,
  /// a stand of trees): left out of the block areas and flows, and the
  /// laterals go round it ([blockOptionsFor] passes it on). Holes lying
  /// across the outline count only for their part inside the field.
  final List<List<Pt>> exclusions;
  final SubdivisionMode mode;

  /// Largest block (m²); 0 = from the flow.
  final double maxBlockArea;

  /// Largest flow of a block (m³/s), with [flowPerHectare] (m³/s per ha
  /// applied by the emitters: q·10⁴/(emitter spacing·lateral spacing)).
  final double maxBlockFlow;
  final double flowPerHectare;

  /// Longest lateral (m); in [SubdivisionMode.grid] a block is at most
  /// this long along the rows (twice as long with [centreFeed]). 0 = no
  /// limit.
  final double maxLateralLength;

  /// Submains across the middle of the blocks, laterals both ways.
  final bool centreFeed;

  /// Narrowest block (m) across the cuts.
  final double minBlockWidth;

  /// Service road between neighbouring blocks (m): it also keeps the tape
  /// ends of two zones apart.
  final double roadWidth;

  /// Where the water comes from: submains and valves on its side.
  final Pt? pointOfConnection;

  /// Submain side of every block (null = by [centreFeed] and the point of
  /// connection).
  final SubmainPosition? submainPosition;
}

/// One block of the subdivision.
class FieldBlock {
  FieldBlock({
    required this.polygon,
    required this.area,
    required this.flow,
    required this.submain,
    required this.valvePosition,
    required this.valvePoint,
    required this.strip,
    required this.column,
    required this.lateralLength,
  });

  /// Outline, counter-clockwise.
  final List<Pt> polygon;

  /// Area (m²) and flow (m³/s; 0 without a flow per hectare).
  final double area, flow;

  /// Submain side and valve position along the submain, as the block
  /// generator takes them.
  final SubmainPosition submain;
  final ValvePosition valvePosition;

  /// Suggested valve point: on the submain line, before the stub.
  final Pt valvePoint;

  /// Strip (across the rows) and column (along them) of the block.
  final int strip, column;

  /// Longest lateral of the block (m).
  final double lateralLength;
}

/// Outcome of [subdivideField].
class FieldSubdivision {
  FieldSubdivision({required this.blocks, required this.fieldArea, required this.direction, required this.messages});
  final List<FieldBlock> blocks;

  /// Area of the field (m²); the blocks cover it but for the roads.
  final double fieldArea;
  final Pt direction;

  /// Codes: `field_empty`, `field_no_limit` (no area nor flow limit: one
  /// block), `field_block_narrow:<block>` (narrower than the minimum width),
  /// `field_lateral_long:<block>` (laterals longer than allowed),
  /// `field_block_large:<block>` (still above the limit: a road ate the
  /// margin or a strip could not be cut).
  final List<String> messages;

  double get blocksArea => blocks.fold(0.0, (s, b) => s + b.area);
}

/// Block-generator options for [block] of a subdivision along [direction]
/// (the rest as [generateBlock] takes it).
BlockOptions blockOptionsFor(
  FieldBlock block,
  Pt direction, {
  required double lateralSpacing,
  bool isTape = false,
  String? tapeSpecId,
  String? outletSpecId,
  String? nozzleId,
  double outletSpacing = 4,
  double headM = 15,
  double tapeInletHeadM = 10,
  String? lateralPipeSpecId,
  String? submainPipeSpecId,
  String? valveSpecId,
  double submainStub = 1.5,
  String? zoneName,
  String submainLabel = 'Submain',
  String stubLabel = 'Stub',
  String lateralPrefix = 'L',
  double submainDepth = 0,
  List<List<Pt>> exclusions = const [],
}) => BlockOptions(
  polygon: block.polygon,
  direction: direction,
  lateralSpacing: lateralSpacing,
  isTape: isTape,
  tapeSpecId: tapeSpecId,
  outletSpecId: outletSpecId,
  nozzleId: nozzleId,
  outletSpacing: outletSpacing,
  headM: headM,
  tapeInletHeadM: tapeInletHeadM,
  lateralPipeSpecId: lateralPipeSpecId,
  submainPipeSpecId: submainPipeSpecId,
  submainPosition: block.submain,
  valveSpecId: valveSpecId,
  valvePosition: block.valvePosition,
  submainStub: submainStub,
  zoneName: zoneName,
  submainLabel: submainLabel,
  stubLabel: stubLabel,
  lateralPrefix: lateralPrefix,
  submainDepth: submainDepth,
  exclusions: [
    for (final e in exclusions)
      if (Bounds.ofPoints(e).intersects(Bounds.ofPoints(block.polygon))) e,
  ],
);

/// Pieces of the simple polygon [poly] where p·[n] ≥ [c] ([above]) or
/// ≤ [c]: a concave polygon may fall in several pieces; each is
/// counter-clockwise.
List<List<Pt>> clipPolygonHalfPlane(List<Pt> poly, Pt n, double c, {bool above = true}) {
  final p = normalizePolygon(poly);
  if (p.length < 3) return const [];
  final sgn = above ? 1.0 : -1.0;
  final scale = math.max(Bounds.ofPoints(p).width, Bounds.ofPoints(p).height);
  final eps = math.max(1e-12, scale * 1e-12);
  // vertices on the line count as outside: the piece's boundary there is the
  // cut itself
  final s = [for (final q in p) (q.dot(n) - c) * sgn];
  final ins = [for (final v in s) v > eps];
  if (ins.every((x) => x)) return [p];
  if (!ins.any((x) => x)) return const [];
  final d = n.perpendicular;
  // ring with the crossings; crossing k is (ring index, t along the line)
  final ring = <Pt>[];
  final inside = <bool>[];
  final crossAt = <int>[];
  final crossT = <double>[];
  for (var i = 0; i < p.length; i++) {
    final j = (i + 1) % p.length;
    ring.add(p[i]);
    inside.add(ins[i]);
    if (ins[i] != ins[j]) {
      final a = s[i], b = s[j];
      final t = a / (a - b);
      final x = Pt.lerp(p[i], p[j], t.clamp(0.0, 1.0));
      crossAt.add(ring.length);
      crossT.add(x.dot(d));
      ring.add(x);
      inside.add(false);
    }
  }
  // the line runs inside the polygon between crossings paired in order
  final order = List<int>.generate(crossAt.length, (k) => k)..sort((a, b) => crossT[a] != crossT[b] ? crossT[a].compareTo(crossT[b]) : a.compareTo(b));
  final partner = <int, int>{};
  for (var k = 0; k + 1 < order.length; k += 2) {
    partner[crossAt[order[k]]] = crossAt[order[k + 1]];
    partner[crossAt[order[k + 1]]] = crossAt[order[k]];
  }
  final isCross = {for (final r in crossAt) r};
  final used = List<bool>.filled(ring.length, false);
  final out = <List<Pt>>[];
  for (var start = 0; start < ring.length; start++) {
    if (!inside[start] || used[start]) continue;
    final piece = <Pt>[];
    var i = start;
    for (var guard = 0; guard <= 2 * ring.length; guard++) {
      if (used[i] && i == start && piece.isNotEmpty) break;
      used[i] = true;
      piece.add(ring[i]);
      final next = (i + 1) % ring.length;
      if (isCross.contains(next) && inside[i]) {
        // leaving the half-plane: along the cut to the partner crossing
        used[next] = true;
        piece.add(ring[next]);
        final back = partner[next];
        if (back == null) break;
        used[back] = true;
        piece.add(ring[back]);
        i = (back + 1) % ring.length;
      } else {
        i = next;
      }
      if (i == start) break;
    }
    final clean = normalizePolygon(piece);
    if (clean.length >= 3 && polygonArea(clean).abs() > eps) out.add(clean);
  }
  return out;
}

/// Pieces of [poly] between p·[n] = [a] and p·[n] = [b] (a < b).
List<List<Pt>> clipPolygonSlab(List<Pt> poly, Pt n, double a, double b) => [for (final piece in clipPolygonHalfPlane(poly, n, a)) ...clipPolygonHalfPlane(piece, n, b, above: false)];

/// Area of a polygon below the line p·n = v as a function of v, in closed
/// form: by Green's theorem with the 1-form (t − v) du, which vanishes on
/// the cut, every edge adds a polynomial of degree two at most in v
/// (nothing below its lower end, a quadratic across it, a linear term
/// above it), so the area is piecewise quadratic between the projections of
/// the vertices. Built once in O(n log n), it answers in O(log n) what a
/// clip of the polygon answered in O(n) with allocations; the subdivision
/// of a field with thousands of vertices asks it hundreds of thousands of
/// times.
class _AreaProfile {
  _AreaProfile(List<Pt> polygon, Pt n) {
    final poly = normalizePolygon(polygon);
    final d = n.perpendicular;
    // positions relative to the first vertex: the squares stay small in
    // projected coordinates of millions of metres
    _t0 = poly.isEmpty ? 0 : poly.first.dot(n);
    final u0 = poly.isEmpty ? 0.0 : poly.first.dot(d);
    final events = <(double, double, double, double)>[]; // position, Δa, Δb, Δc
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final ta = p.dot(n) - _t0, tb = q.dot(n) - _t0, ua = p.dot(d) - u0, ub = q.dot(d) - u0;
      if ((tb - ta).abs() < 1e-12) {
        // along the cut direction: (c − v)·Δu once v reaches it
        final du = ub - ua;
        events.add((ta, du * ta, -du, 0));
        continue;
      }
      final t0 = math.min(ta, tb), t1 = math.max(ta, tb);
      // w·∫ (t − v) dt over the part below v, w = σ·du/dt = Δu/Δt·sign = Δu/(t1 − t0)
      final w = (ub - ua) / (tb - ta) * (ta < tb ? 1 : -1);
      // across the edge: −w(v − t0)²/2
      events.add((t0, -w * t0 * t0 / 2, w * t0, -w / 2));
      // above it: w(t1 − t0)((t1 + t0)/2 − v), replacing the quadratic
      events.add((t1, w * (t1 * t1 - t0 * t0) / 2 + w * t0 * t0 / 2, -w * (t1 - t0) - w * t0, w / 2));
    }
    events.sort((x, y) => x.$1.compareTo(y.$1));
    var a = 0.0, b = 0.0, c = 0.0;
    for (final (t, da, db, dc) in events) {
      a += da;
      b += db;
      c += dc;
      if (_pos.isNotEmpty && (t - _pos.last).abs() <= 1e-12) {
        _a[_a.length - 1] = a;
        _b[_b.length - 1] = b;
        _c[_c.length - 1] = c;
      } else {
        _pos.add(t);
        _a.add(a);
        _b.add(b);
        _c.add(c);
      }
    }
    total = polygonArea(poly).abs();
    final top = _pos.isEmpty ? 0.0 : _raw(_pos.last + 1);
    _sign = top < 0 ? -1 : 1;
  }

  final List<double> _pos = [], _a = [], _b = [], _c = [];
  double _sign = 1;
  late final double _t0;
  late final double total;

  /// The raw sum at [v] measured from the first vertex.
  double _raw(double v) {
    if (_pos.isEmpty || v <= _pos.first) return 0;
    var lo = 0, hi = _pos.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_pos[mid] <= v) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _a[lo] + _b[lo] * v + _c[lo] * v * v;
  }

  /// Area (m²) of the polygon where p·n ≤ [v].
  double below(double v) {
    final t = v - _t0;
    if (_pos.isEmpty || t <= _pos.first) return 0;
    if (t >= _pos.last) return total;
    return (_raw(t) * _sign).clamp(0.0, total).toDouble();
  }

  /// v in [lo, hi] where the area below reaches [target] (bisection).
  double cutAt(double lo, double hi, double target) {
    final span = hi - lo;
    for (var it = 0; it < 64 && hi - lo > 1e-9 * math.max(1, span); it++) {
      final mid = (lo + hi) / 2;
      if (below(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

/// [_AreaProfile] of a polygon less its holes (each a simple polygon inside
/// it): the area below a cut minus the holes' areas below it.
class _NetProfile {
  _NetProfile(List<Pt> poly, List<List<Pt>> holes, Pt n) : _field = _AreaProfile(poly, n), _holes = [for (final h in holes) _AreaProfile(h, n)];
  final _AreaProfile _field;
  final List<_AreaProfile> _holes;

  double get total => math.max(0.0, _field.total - _holes.fold(0.0, (s, h) => s + h.total));

  double below(double v) => math.max(0.0, _field.below(v) - _holes.fold(0.0, (s, h) => s + h.below(v)));

  double cutAt(double lo, double hi, double target) {
    final span = hi - lo;
    for (var it = 0; it < 64 && hi - lo > 1e-9 * math.max(1, span); it++) {
      final mid = (lo + hi) / 2;
      if (below(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

/// The holes of [poly] among [holes]: their parts inside it (a hole lying
/// across the outline counts only inside the field), as simple polygons.
List<List<Pt>> _holesIn(List<Pt> poly, List<List<Pt>> holes) {
  final out = <List<Pt>>[];
  final pb = Bounds.ofPoints(poly);
  for (final h in holes) {
    final q = normalizePolygon(h);
    if (q.length < 3 || !Bounds.ofPoints(q).intersects(pb)) continue;
    if (q.every((x) => pointInPolygon(x, poly))) {
      out.add(q);
      continue;
    }
    // the part inside: the hole less the outside of the field, by the
    // region of the hole with the field's complement pieces taken out
    final inside = LayoutRegion(q, exclusions: [for (final piece in _complementPieces(poly, q)) piece]);
    for (final l in inside.loops) {
      if (!l.isHole && polygonArea(l.points).abs() > 1e-9) out.add(l.points);
    }
  }
  return out;
}

/// The parts of the bounding box of [hole] outside [poly] (the field), as
/// polygons: the box less the field.
List<List<Pt>> _complementPieces(List<Pt> poly, List<Pt> hole) {
  final b = Bounds.ofPoints(hole).inflate(1);
  final box = [Pt(b.minX, b.minY), Pt(b.maxX, b.minY), Pt(b.maxX, b.maxY), Pt(b.minX, b.maxY)];
  final region = LayoutRegion(box, exclusions: [poly]);
  return [
    for (final l in region.loops)
      if (!l.isHole) l.points,
  ];
}

/// Positions of the cuts of [poly] across [n] into [count] parts of equal
/// net area (less the [holes]) with [road] metres between parts: (start,
/// end) of every part.
List<(double, double)> _equalCuts(List<Pt> poly, Pt n, int count, double road, {List<List<Pt>> holes = const []}) {
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in poly) {
    vMin = math.min(vMin, p.dot(n));
    vMax = math.max(vMax, p.dot(n));
  }
  if (count <= 1) return [(vMin, vMax)];
  final profile = _NetProfile(poly, holes, n);
  final total = profile.total;
  List<(double, double)> place(double target) {
    final out = <(double, double)>[];
    var e = vMin;
    for (var k = 1; k < count; k++) {
      final s = profile.cutAt(e, vMax, profile.below(e) + target);
      out.add((e, s));
      e = math.min(vMax, s + road);
    }
    out.add((e, vMax));
    return out;
  }

  double lastArea(List<(double, double)> cuts) => total - profile.below(cuts.last.$1);
  var lo = 0.0, hi = total / count;
  for (var it = 0; it < 50; it++) {
    final mid = (lo + hi) / 2;
    if (lastArea(place(mid)) > mid) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return place((lo + hi) / 2);
}

/// Cuts [field] into blocks (see the library comment). A field outline
/// that crosses itself is cut into the simple loops it encloses, each
/// subdivided on its own (`field_self_intersect`).
FieldSubdivision subdivideField(List<Pt> field, FieldSubdivisionOptions o) {
  final poly = normalizePolygon(field);
  final dir = o.direction.length > 0 ? o.direction.normalized : const Pt(1, 0);
  final messages = <String>[];
  if (poly.length >= 4 && polygonSelfCrossings(poly).isNotEmpty) {
    final parts = simplePolygonParts(field);
    if (parts.length > 1) {
      final blocks = <FieldBlock>[];
      final out = <String>['field_self_intersect'];
      var area = 0.0;
      for (final part in parts) {
        final sub = subdivideField(part, o);
        for (final m in sub.messages) {
          final i = m.indexOf(':');
          final k = i > 0 ? int.tryParse(m.substring(i + 1)) : null;
          final msg = k == null ? m : '${m.substring(0, i)}:${k + blocks.length}';
          if (!out.contains(msg)) out.add(msg);
        }
        blocks.addAll(sub.blocks);
        area += sub.fieldArea;
      }
      return FieldSubdivision(blocks: blocks, fieldArea: area, direction: dir, messages: out);
    }
  }
  if (poly.length < 3 || polygonArea(poly).abs() < 1e-9) return FieldSubdivision(blocks: const [], fieldArea: 0, direction: dir, messages: ['field_empty']);
  final perp = dir.perpendicular;
  final holes = _holesIn(poly, o.exclusions);
  final total = math.max(0.0, polygonArea(poly).abs() - holes.fold(0.0, (s, h) => s + polygonArea(h).abs()));
  final fromFlow = o.maxBlockFlow > 0 && o.flowPerHectare > 0 ? o.maxBlockFlow / o.flowPerHectare * 1e4 : double.infinity;
  final maxArea = math.min(o.maxBlockArea > 0 ? o.maxBlockArea : double.infinity, fromFlow);
  if (!maxArea.isFinite) messages.add('field_no_limit');
  final road = math.max(0.0, o.roadWidth);
  final maxLen = o.maxLateralLength > 0 ? o.maxLateralLength * (o.centreFeed ? 2 : 1) : double.infinity;
  // strips across the rows: equal areas, the roads taken out
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in poly) {
    vMin = math.min(vMin, p.dot(perp));
    vMax = math.max(vMax, p.dot(perp));
  }
  // in a grid the columns share the area of a strip
  var columns = 1;
  if (o.mode == SubdivisionMode.grid && maxLen.isFinite) {
    var uMin = double.infinity, uMax = -double.infinity;
    for (final p in poly) {
      uMin = math.min(uMin, p.dot(dir));
      uMax = math.max(uMax, p.dot(dir));
    }
    columns = math.max(1, ((uMax - uMin + road) / (maxLen + road) - 1e-9).ceil());
  }
  var strips = maxArea.isFinite ? math.max(1, (total / (maxArea * columns) - 1e-9).ceil()) : 1;
  // as wide as the minimum allows
  final widest = math.max(1, ((vMax - vMin + road) / (math.max(o.minBlockWidth, 1e-6) + road)).floor());
  var blocks = <FieldBlock>[];
  for (var attempt = 0; attempt < 12; attempt++) {
    blocks = _cut(poly, dir, perp, o, math.min(strips, widest), road, maxLen, holes);
    // a strip whose pieces took fewer columns than planned may be too large
    if (!maxArea.isFinite || strips >= widest || blocks.every((bl) => bl.area <= maxArea * (1 + 1e-6))) break;
    strips++;
  }
  for (var i = 0; i < blocks.length; i++) {
    final bl = blocks[i];
    var w0 = double.infinity, w1 = -double.infinity;
    for (final p in bl.polygon) {
      w0 = math.min(w0, p.dot(perp));
      w1 = math.max(w1, p.dot(perp));
    }
    if (w1 - w0 < o.minBlockWidth - 1e-6) messages.add('field_block_narrow:$i');
    if (o.maxLateralLength > 0 && bl.lateralLength > o.maxLateralLength + 1e-6) messages.add('field_lateral_long:$i');
    if (maxArea.isFinite && bl.area > maxArea * (1 + 1e-6)) messages.add('field_block_large:$i');
  }
  return FieldSubdivision(blocks: blocks, fieldArea: total, direction: dir, messages: messages);
}

/// The blocks of [strips] strips (each cut in columns in a grid).
List<FieldBlock> _cut(List<Pt> poly, Pt dir, Pt perp, FieldSubdivisionOptions o, int strips, double road, double maxLen, List<List<Pt>> holes) {
  final blocks = <FieldBlock>[];
  final cuts = _equalCuts(poly, perp, strips, road, holes: holes);
  for (var si = 0; si < cuts.length; si++) {
    final (a, b) = cuts[si];
    if (b - a <= 1e-9) continue;
    for (final piece in clipPolygonSlab(poly, perp, a, b)) {
      var parts = [piece];
      if (o.mode == SubdivisionMode.grid && maxLen.isFinite) {
        var uMin = double.infinity, uMax = -double.infinity;
        for (final p in piece) {
          uMin = math.min(uMin, p.dot(dir));
          uMax = math.max(uMax, p.dot(dir));
        }
        // equal areas, one more column while a part is longer than allowed
        final first = math.max(1, ((uMax - uMin + road) / (maxLen + road) - 1e-9).ceil());
        for (var count = first; count > 1 && count < first + 6; count++) {
          // the holes in this strip piece, cut to it
          final inPiece = [
            for (final h in holes)
              if (Bounds.ofPoints(h).intersects(Bounds.ofPoints(piece))) ..._holesIn(piece, [h]),
          ];
          parts = [
            for (final (c0, c1) in _equalCuts(piece, dir, count, road, holes: inPiece))
              if (c1 - c0 > 1e-9) ...clipPolygonSlab(piece, dir, c0, c1),
          ];
          bool long(List<Pt> q) {
            var a = double.infinity, b = -double.infinity;
            for (final p in q) {
              a = math.min(a, p.dot(dir));
              b = math.max(b, p.dot(dir));
            }
            return b - a > maxLen + 1e-6;
          }

          if (!parts.any(long)) break;
        }
      }
      for (var ci = 0; ci < parts.length; ci++) {
        blocks.add(_block(parts[ci], dir, perp, o, si, ci, holes));
      }
    }
  }
  return blocks;
}

FieldBlock _block(List<Pt> poly, Pt dir, Pt perp, FieldSubdivisionOptions o, int strip, int column, List<List<Pt>> holes) {
  var u0 = double.infinity, u1 = -double.infinity, v0 = double.infinity, v1 = -double.infinity;
  for (final p in poly) {
    u0 = math.min(u0, p.dot(dir));
    u1 = math.max(u1, p.dot(dir));
    v0 = math.min(v0, p.dot(perp));
    v1 = math.max(v1, p.dot(perp));
  }
  // the net area: the holes inside the block left out
  final inside = [
    for (final h in holes)
      if (Bounds.ofPoints(h).intersects(Bounds.ofPoints(poly))) h,
  ];
  final area = inside.isEmpty ? polygonArea(poly).abs() : LayoutRegion(poly, exclusions: inside).area;
  final poc = o.pointOfConnection;
  final submain = o.submainPosition ?? (o.centreFeed ? SubmainPosition.centre : (poc != null && poc.dot(dir) > (u0 + u1) / 2 ? SubmainPosition.end : SubmainPosition.start));
  final uSub = switch (submain) {
    SubmainPosition.start => u0,
    SubmainPosition.centre => (u0 + u1) / 2,
    SubmainPosition.end => u1,
  };
  var valve = ValvePosition.centre;
  if (poc != null) {
    final pv = poc.dot(perp);
    if (pv < v0 + (v1 - v0) / 3) valve = ValvePosition.start;
    if (pv > v0 + 2 * (v1 - v0) / 3) valve = ValvePosition.end;
  }
  final vValve = switch (valve) {
    ValvePosition.start => v0,
    ValvePosition.centre => (v0 + v1) / 2,
    ValvePosition.end => v1,
  };
  // the feed line across the rows clipped to the block: the valve sits on
  // the part nearest to the wanted point
  var valvePoint = dir * uSub + perp * vValve;
  final line = clipPolylineToPolygon([dir * uSub + perp * (v0 - 1), dir * uSub + perp * (v1 + 1)], poly);
  if (line.isNotEmpty) {
    var best = double.infinity;
    for (final l in line) {
      final (_, q) = polylineStationOf(l, valvePoint);
      if (q.distanceTo(valvePoint) < best) {
        best = q.distanceTo(valvePoint);
        valvePoint = q;
      }
    }
  }
  final lateral = switch (submain) {
    SubmainPosition.centre => math.max(uSub - u0, u1 - uSub),
    _ => u1 - u0,
  };
  return FieldBlock(
    polygon: poly,
    area: area,
    flow: o.flowPerHectare > 0 ? area / 1e4 * o.flowPerHectare : 0,
    submain: submain,
    valvePosition: valve,
    valvePoint: valvePoint,
    strip: strip,
    column: column,
    lateralLength: lateral,
  );
}
