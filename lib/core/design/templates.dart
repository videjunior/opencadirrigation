/// Head layout templates for sports and golf turf: a football pitch with 3,
/// 4 or 5 rows of rotors, the infield of a running track, a golf green
/// ringed by part-circle rotors, a tee and a fairway on a triangular grid
/// along its centreline. Each returns the heads with their arcs and
/// matched-precipitation nozzles for a head family, and the uniformity
/// over the turf (see `auto_layout.dart`).
///
/// Spacings, after sports turf and golf course irrigation practice (Keller
/// & Bliesner 1990, chap. 5; Irrigation Association, *Landscape Irrigation
/// Best Management Practices*, 2014; United States Golf Association green
/// construction recommendations for the green and its collar):
/// - Football pitch (105 × 68 m, the size IFAB Law 1 recommends for
///   international matches): rows along the touchlines, the outer two on
///   the touchlines with half circles, quarter circles in the corners and
///   half circles on the goal lines. 5 rows are 17.0 m apart and need a
///   radius of at least 17 m (with 18 m: 7 heads a row, 17.5 m apart, 35
///   heads); 4 rows are 22.7 m apart (R ≥ 23 m; with 24 m: 6 a row, 21 m
///   apart, 24 heads); 3 rows are 34 m apart (R ≥ 34 m, large rotors or
///   guns; with 35 m: 4 a row, 35 m apart, 12 heads). Along a row the heads
///   stand no farther apart than the radius (head to head both ways).
/// - Running track infield: the area inside the kerb of a standard 400 m
///   track (World Athletics: 36.50 m kerb radius, 84.39 m straights),
///   laid out as a lawn with rows along the straights.
/// - Golf green: rotors on a ring a set-back outside the collar, no farther
///   apart than their radius, each a part circle opening onto the green
///   (its arc spans the green as seen from the head, plus a margin onto the
///   collar); nothing inside the putting surface.
/// - Tee: a rectangle laid out as a lawn with rows along its length.
/// - Fairway: rows parallel to the centreline 0.866 spacings apart, heads
///   one spacing apart along each, alternate rows shifted half a spacing
///   (equilateral triangles, head to head); full circles (the rough takes
///   the edge water), or half circles on rows along both edges.
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/geometry.dart';
import 'auto_layout.dart';
import 'block_generator.dart' show offsetPolylineMitred;
import 'densogram.dart';

/// Rectangle [length] × [width] with its lower-left corner at [origin],
/// turned [rotationDeg] about it, counter-clockwise.
List<Pt> rotatedRectangle(Pt origin, double length, double width, {double rotationDeg = 0}) {
  final t = Affine.rotation(degToRad(rotationDeg), origin);
  return [
    for (final p in [origin, origin + Pt(length, 0), origin + Pt(length, width), origin + Pt(0, width)]) t.apply(p),
  ];
}

/// Ellipse of [length] × [width] centred on [center], turned [rotationDeg]
/// (a green outline), counter-clockwise with [segments] vertices.
List<Pt> ellipseOutline(Pt center, double length, double width, {double rotationDeg = 0, int segments = 48}) {
  final rot = degToRad(rotationDeg);
  return [for (var i = 0; i < segments; i++) center + Pt(length / 2 * math.cos(2 * math.pi * i / segments), width / 2 * math.sin(2 * math.pi * i / segments)).rotate(rot)];
}

/// Outline of the infield of a running track: two straights of [straight]
/// metres joined by half circles of [radius] (the kerb), centred on
/// [center], the straights along [rotationDeg].
List<Pt> trackInfieldOutline({double straight = 84.39, double radius = 36.5, Pt center = Pt.zero, double rotationDeg = 0, int segmentsPerEnd = 36}) {
  final rot = degToRad(rotationDeg);
  final half = straight / 2;
  final pts = <Pt>[
    for (var i = 0; i <= segmentsPerEnd; i++) Pt(half, 0) + Pt.polar(radius, -math.pi / 2 + math.pi * i / segmentsPerEnd),
    for (var i = 0; i <= segmentsPerEnd; i++) Pt(-half, 0) + Pt.polar(radius, math.pi / 2 + math.pi * i / segmentsPerEnd),
  ];
  return normalizePolygon([for (final p in pts) center + p.rotate(rot)]);
}

/// The full-circle nozzle of [family] with the smallest wetted radius of
/// at least [minRadius] at [headM] (the largest when none reaches, and
/// whether it reaches).
(NozzleSpec?, bool) _nozzleReaching(OutletSpec family, double headM, double minRadius) {
  NozzleSpec? best, largest;
  for (final n in family.nozzles) {
    if (n.arcDeg < 360 - 1e-6) continue;
    final r = n.curve.radius(headM);
    if (!(r > 0)) continue;
    if (largest == null || r > largest.curve.radius(headM)) largest = n;
    if (r >= minRadius - 1e-9 && (best == null || r < best.curve.radius(headM))) best = n;
  }
  return best != null ? (best, true) : (largest, false);
}

LandscapeLayout _empty(LayoutRegion region, OutletSpec family, double headM, String code) => LandscapeLayout(region: region, outletSpecId: family.id, heads: const [], headM: headM, messages: [code]);

NozzleSpec? _byId(OutletSpec family, String? id) {
  if (id == null) return null;
  for (final n in family.nozzles) {
    if (n.id == id) return n;
  }
  return null;
}

/// Football pitch of [length] × [width] with its lower-left corner at
/// [origin] turned [rotationDeg]: [rows] (3, 4 or 5) rows of heads of
/// [family] along the touchlines (see the library comment); [rows] 0 = the
/// fewest rows the largest full-circle nozzle of the family reaches across.
/// The nozzle [nozzleId] (else the full circle that reaches the next row)
/// sets the spacing along the rows. Codes: `template_radius_short` (no
/// nozzle throws as far as the next row).
LandscapeLayout sportsPitchLayout({
  required OutletSpec family,
  double length = 105,
  double width = 68,
  int rows = 5,
  Pt origin = Pt.zero,
  double rotationDeg = 0,
  double headM = 0,
  String? nozzleId,
  bool evaluate = true,
  SprayProfile profile = SprayProfile.triangular,
}) {
  final h = headM > 0 ? headM : defaultLayoutHead(family);
  final outline = rotatedRectangle(origin, length, width, rotationDeg: rotationDeg);
  final region = LayoutRegion(outline);
  var n = rows;
  if (n <= 0) {
    final reach = (_byId(family, nozzleId) ?? _nozzleReaching(family, h, double.infinity).$1)?.curve.radius(h) ?? 0;
    n = reach > 0 ? (width / (reach * 0.98) - 1e-9).ceil() + 1 : 5;
  }
  n = n.clamp(2, 50).toInt();
  final rowSp = width / (n - 1);
  final messages = <String>[];
  var ref = _byId(family, nozzleId);
  if (ref == null) {
    final (nz, reaches) = _nozzleReaching(family, h, rowSp * 0.98);
    ref = nz;
    if (!reaches) messages.add('template_radius_short');
  }
  if (ref == null) return _empty(region, family, h, 'layout_no_nozzle');
  final radius = ref.curve.radius(h);
  if (radius < rowSp * 0.98 && !messages.contains('template_radius_short')) messages.add('template_radius_short');
  final cols = math.max(1, (length / math.max(radius, 1e-6) - 1e-9).ceil());
  final colSp = length / cols;
  final t = Affine.rotation(degToRad(rotationDeg), origin);
  final heads = <LayoutHead>[];
  for (var k = 0; k < n; k++) {
    final y = k * rowSp;
    for (var j = 0; j <= cols; j++) {
      final x = j * colSp;
      final bottom = k == 0, top = k == n - 1, left = j == 0, right = j == cols;
      var arc = 360.0, orient = 0.0;
      var role = HeadRole.interior;
      if ((bottom || top) && (left || right)) {
        arc = 90;
        orient = left ? (bottom ? 0 : 270) : (bottom ? 90 : 180);
        role = HeadRole.corner;
      } else if (bottom || top || left || right) {
        arc = 180;
        orient = left ? 270 : (right ? 90 : (bottom ? 0 : 180));
        role = HeadRole.edge;
      }
      heads.add(LayoutHead(position: t.apply(origin + Pt(x, y)), arcDeg: arc, orientationDeg: normalizeDeg(orient + rotationDeg), role: role));
    }
  }
  return finishHeadLayout(
    region: region,
    family: family,
    heads: heads,
    headM: h,
    reference: ref,
    spacing: colSp,
    rowSpacing: rowSp,
    direction: Pt.polar(1, degToRad(rotationDeg)),
    messages: messages,
    evaluate: evaluate,
    profile: profile,
  );
}

/// The infield of a running track (see [trackInfieldOutline]) laid out as
/// a lawn with rows along the straights.
LandscapeLayout runningTrackInfieldLayout({required OutletSpec family, double straight = 84.39, double radius = 36.5, Pt center = Pt.zero, double rotationDeg = 0, LandscapeLayoutOptions? options}) {
  final o = options?.copy() ?? LandscapeLayoutOptions();
  o.direction ??= Pt.polar(1, degToRad(rotationDeg));
  return layoutLandscape(
    outline: trackInfieldOutline(straight: straight, radius: radius, center: center, rotationDeg: rotationDeg),
    family: family,
    options: o,
  );
}

/// A tee of [length] × [width] centred on [center], turned [rotationDeg],
/// laid out as a lawn with rows along its length.
LandscapeLayout teeLayout({required OutletSpec family, required double length, required double width, Pt center = Pt.zero, double rotationDeg = 0, LandscapeLayoutOptions? options}) {
  final o = options?.copy() ?? LandscapeLayoutOptions();
  o.direction ??= Pt.polar(1, degToRad(rotationDeg));
  final corner = center + Pt(-length / 2, -width / 2).rotate(degToRad(rotationDeg));
  return layoutLandscape(
    outline: rotatedRectangle(corner, length, width, rotationDeg: rotationDeg),
    family: family,
    options: o,
  );
}

/// [poly] (counter-clockwise) moved [d] metres outwards (vertices along the
/// bisectors, mitre limited).
List<Pt> _grow(List<Pt> poly, double d) {
  final n = poly.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final prev = poly[(i - 1 + n) % n], v = poly[i], next = poly[(i + 1) % n];
        final d1 = (v - prev).normalized, d2 = (next - v).normalized;
        final n1 = Pt(d1.y, -d1.x), n2 = Pt(d2.y, -d2.x);
        var b = (n1 + n2).normalized;
        if (b.length == 0) b = n1;
        final c = b.dot(n1);
        return v + b * (c > 0.3 ? d / c : 3 * d);
      }(),
  ];
}

/// Rotors of [family] round the [green] outline, [setback] metres outside
/// it, each a part circle opening onto the green over the angle the green
/// spans from it plus [arcMarginDeg] on either side; at least [minHeads],
/// no farther apart than their radius. The nozzle [nozzleId] (else the
/// full circle reaching 60 % of the way across the green) sets the
/// spacing; the uniformity is that of the green itself. Codes:
/// `template_radius_short`.
LandscapeLayout golfGreenLayout({
  required OutletSpec family,
  required List<Pt> green,
  double setback = 1.5,
  double headM = 0,
  String? nozzleId,
  double arcMarginDeg = 15,
  int minHeads = 4,
  bool evaluate = true,
  SprayProfile profile = SprayProfile.triangular,
}) {
  final h = headM > 0 ? headM : defaultLayoutHead(family);
  final region = LayoutRegion(green);
  if (region.isEmpty) return _empty(region, family, h, 'layout_empty');
  final (_, rIn) = maximumInscribedCircle(region);
  final across = 2 * rIn + 2 * setback;
  final messages = <String>[];
  var ref = _byId(family, nozzleId);
  if (ref == null) {
    final (nz, reaches) = _nozzleReaching(family, h, 0.6 * across);
    ref = nz;
    if (!reaches) messages.add('template_radius_short');
  }
  if (ref == null) return _empty(region, family, h, 'layout_no_nozzle');
  final radius = ref.curve.radius(h);
  if (region.selfCrossing) messages.add('layout_self_intersect');
  final ring = RegionLoop(_grow(region.parts.first, setback));
  final count = math.max(minHeads, (ring.length / radius - 1e-9).ceil());
  final step = ring.length / count;
  // start at the vertex farthest along x (a deterministic place)
  var start = 0;
  for (var i = 1; i < ring.vertexCount; i++) {
    if (ring.points[i].x > ring.points[start].x + 1e-9) start = i;
  }
  // the outline sampled every half metre at most (with its vertices): the
  // directions to the green from a head are those of the outline points in
  // reach, along straight sides too, not only of the vertices (a green
  // drawn with four corners would get 30° arcs at the corners)
  final samples = <Pt>[
    for (final outline in region.parts)
      for (var i = 0; i < outline.length; i++) ...[
        outline[i],
        for (var j = 1, m = (outline[i].distanceTo(outline[(i + 1) % outline.length]) / 0.5).ceil(); j < m; j++) Pt.lerp(outline[i], outline[(i + 1) % outline.length], j / m),
      ],
  ];
  final heads = <LayoutHead>[];
  for (var k = 0; k < count; k++) {
    final p = ring.at(ring.cum[start] + k * step);
    // directions to the green within reach: the arc spans them
    final angles = <double>[
      for (final q in samples)
        if (q.distanceTo(p) <= radius) normalizeDeg(radToDeg((q - p).angle)),
    ]..sort();
    if (angles.isEmpty) continue;
    var gap = 360 - angles.last + angles.first, from = angles.first;
    for (var i = 1; i < angles.length; i++) {
      if (angles[i] - angles[i - 1] > gap) {
        gap = angles[i] - angles[i - 1];
        from = angles[i];
      }
    }
    final span = 360 - gap;
    final arc = (span + 2 * arcMarginDeg).clamp(30.0, 360.0).toDouble();
    heads.add(LayoutHead(position: p, arcDeg: arc, orientationDeg: normalizeDeg(from - (arc - span) / 2), role: HeadRole.edge));
  }
  return finishHeadLayout(region: region, family: family, heads: heads, headM: h, reference: ref, spacing: step, messages: messages, evaluate: evaluate, profile: profile);
}

/// Sharpest turn (degrees) a fairway centreline may take: beyond it the
/// fairway would double back over itself.
const fairwayMaxTurnDeg = 150.0;

/// Rotors of [family] over a fairway [width] metres wide along
/// [centreline] (see the library comment): rows 0.866 spacings apart, heads
/// one spacing apart, alternate rows shifted half a spacing; with
/// [edgePartCircles] the outer rows run along the edges with half circles
/// facing in. The nozzle [nozzleId] (else the full circle with the largest
/// radius) sets the spacing. The corridor and the rows are offsets of the
/// centreline with a mitre limit (round on the outside of a sharp dogleg);
/// a centreline that turns back by more than [fairwayMaxTurnDeg] gets no
/// heads (`template_centreline_turn`).
LandscapeLayout fairwayLayout({
  required OutletSpec family,
  required List<Pt> centreline,
  required double width,
  double headM = 0,
  String? nozzleId,
  bool edgePartCircles = false,
  bool evaluate = true,
  SprayProfile profile = SprayProfile.triangular,
}) {
  final h = headM > 0 ? headM : defaultLayoutHead(family);
  final line = [
    for (var i = 0; i < centreline.length; i++)
      if (i == 0 || centreline[i].distanceTo(centreline[i - 1]) > 1e-9) centreline[i],
  ];
  if (line.length < 2 || !(width > 0)) return _empty(LayoutRegion(const []), family, h, 'layout_empty');
  for (var i = 1; i + 1 < line.length; i++) {
    final a = line[i] - line[i - 1], b = line[i + 1] - line[i];
    if (radToDeg(math.atan2(a.cross(b), a.dot(b))).abs() > fairwayMaxTurnDeg) return _empty(LayoutRegion(const []), family, h, 'template_centreline_turn');
  }
  final corridor = [...offsetPolylineMitred(line, width / 2), ...offsetPolylineMitred(line, -width / 2).reversed];
  final region = LayoutRegion(corridor);
  var ref = _byId(family, nozzleId);
  if (ref == null) {
    final (nz, _) = _nozzleReaching(family, h, double.infinity);
    ref = nz;
  }
  if (ref == null) return _empty(region, family, h, 'layout_no_nozzle');
  final s = ref.curve.radius(h);
  final rowTarget = s * math.sqrt(3) / 2;
  final offsets = <double>[];
  if (edgePartCircles) {
    final n = math.max(2, (width / rowTarget - 1e-9).ceil() + 1);
    for (var k = 0; k < n; k++) {
      offsets.add(-width / 2 + width * k / (n - 1));
    }
  } else {
    // enough rows that the edges lie within half a row of the outer ones
    final n = math.max(1, (width / rowTarget - 0.15).ceil());
    for (var k = 0; k < n; k++) {
      offsets.add((k - (n - 1) / 2) * rowTarget);
    }
  }
  final heads = <LayoutHead>[];
  for (var k = 0; k < offsets.length; k++) {
    final row = offsetPolylineMitred(line, offsets[k]);
    final len = polylineLength(row);
    final m = math.max(1, (len / s - 1e-9).ceil());
    final step = len / m;
    final shifted = k.isOdd;
    final edge = edgePartCircles && (k == 0 || k == offsets.length - 1);
    for (var j = 0; j <= m; j++) {
      final at = shifted ? (j + 0.5) * step : j * step;
      if (at > len + 1e-9) continue;
      final p = pointAlongPolyline(row, at);
      if (!edge) {
        heads.add(LayoutHead(position: p, arcDeg: 360, role: HeadRole.interior));
        continue;
      }
      // half circles facing the centreline: the left edge (offset > 0)
      // waters to its right
      final a = pointAlongPolyline(row, math.max(0, at - 0.01)), b = pointAlongPolyline(row, math.min(len, at + 0.01));
      final tangent = (b - a).normalized;
      final facing = offsets[k] > 0 ? -tangent : tangent;
      heads.add(LayoutHead(position: p, arcDeg: 180, orientationDeg: normalizeDeg(radToDeg(facing.angle)), role: HeadRole.edge));
    }
  }
  return finishHeadLayout(
    region: region,
    family: family,
    heads: heads,
    headM: h,
    reference: ref,
    spacing: s,
    rowSpacing: rowTarget,
    direction: (line.last - line.first).normalized,
    evaluate: evaluate,
    profile: profile,
  );
}
