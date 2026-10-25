/// Tree rings for orchards: around every tree of a planting grid inside an
/// area (plant × row spacing with offsets) or of surveyed tree positions, a
/// ring of dripline of a radius, or a number of drippers round the trunk
/// on a small ring pipe, joined to a lateral along the row; the laterals
/// start from a submain across the rows with the zone valve.
///
/// A ring of emitters round the trunk wets the root zone of a young tree
/// evenly on every side and away from the trunk (Keller & Bliesner 1990,
/// chap. 15 and 16: emitters per plant, wetted area as a share of the
/// canopy; NRCS NEH 623 chap. 7, microirrigation). Each ring is drawn as
/// two halves from the point where the lateral enters it to the point where
/// it leaves it, both vertices of the lateral, so the network builder joins
/// the ring to the lateral at both ends (coincident vertices connect).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart';
import 'block_generator.dart' show SubmainPosition;

/// What waters the tree.
enum RingKind {
  /// A ring of dripline (a tape entity per half ring).
  dripline,

  /// Single drippers round the trunk on a small ring pipe.
  drippers,
}

/// Options of [layoutTreeRings].
class TreeRingOptions {
  TreeRingOptions({
    this.direction = const Pt(1, 0),
    this.plantSpacing = 6,
    this.rowSpacing = 7,
    this.rowOffset = 0,
    this.plantOffset = 0,
    this.ringRadius = 0.6,
    this.kind = RingKind.dripline,
    this.drippersPerTree = 4,
    this.edgeClearance = -1,
    this.submainPosition = SubmainPosition.start,
    this.submainStub = 1.5,
    this.rowTolerance = 0,
    this.ringSegments = 8,
  });

  /// Direction of the rows.
  final Pt direction;

  /// Spacing of the trees along a row and between rows (m).
  final double plantSpacing, rowSpacing;

  /// First row from the edge of the area, first tree from the start of its
  /// row (m; 0 = half the spacing).
  final double rowOffset, plantOffset;

  /// Radius of the ring round the trunk (m).
  final double ringRadius;
  final RingKind kind;

  /// Drippers per tree ([RingKind.drippers]).
  final int drippersPerTree;

  /// Trees keep this far (m) from the outline (−1 = the ring radius).
  final double edgeClearance;

  /// Side of the submain across the rows.
  final SubmainPosition submainPosition;

  /// Stub (m) from the submain to the valve.
  final double submainStub;

  /// Surveyed trees: a tree within this distance (m) across the rows of a
  /// row belongs to it (0 = a quarter of the row spacing).
  final double rowTolerance;

  /// Segments of every half ring of dripline.
  final int ringSegments;
}

/// The ring round one tree.
class TreeRing {
  TreeRing({required this.tree, required this.row, required this.halves, required this.drippers});
  final Pt tree;
  final int row;

  /// Two halves from where the lateral enters the ring to where it leaves
  /// it, one on each side of the row.
  final List<List<Pt>> halves;

  /// Dripper positions ([RingKind.drippers]); each is a vertex of a half.
  final List<Pt> drippers;
}

/// Outcome of [layoutTreeRings].
class TreeRingLayout {
  TreeRingLayout({required this.trees, required this.rings, required this.laterals, required this.submain, required this.stub, required this.valve, required this.kind, required this.direction, required this.messages});

  final List<Pt> trees;
  final List<TreeRing> rings;

  /// Laterals (zone pipes) along the rows: from the feed on the submain
  /// through both ends of every ring.
  final List<List<Pt>> laterals;

  /// Submain across the rows through the feed of every lateral (empty for
  /// a single row).
  final List<Pt> submain;

  /// Stub from the valve to the submain, and the valve (null without trees).
  final List<Pt> stub;
  final Pt? valve;
  final RingKind kind;
  final Pt direction;

  /// Codes: `rings_no_trees`, `rings_overlap` (rings of neighbouring trees
  /// touch: radius at least half the plant spacing), `rings_row_gap:<row>`
  /// (a lateral crosses ground outside the area between two trees).
  final List<String> messages;

  int get dripperCount => rings.fold(0, (s, r) => s + r.drippers.length);

  /// Length of ring (dripline or ring pipe) (m).
  double get ringLength => rings.fold(0.0, (s, r) => s + r.halves.fold(0.0, (t, h) => t + polylineLength(h)));

  /// The layout as entities of [p] (new ids): laterals, submain and stub as
  /// zone pipes, the valve of zone [zoneName], and the rings as dripline
  /// ([tapeSpecId] at [tapeInletHeadM]) or as ring pipes with drippers
  /// ([outletSpecId], [nozzleId] at [headM]).
  List<Entity> toEntities(Project p, {String? tapeSpecId, double tapeInletHeadM = 10, String? outletSpecId, String? nozzleId, double headM = 10, String? valveSpecId, String zoneName = '', String? lateralPipeSpecId}) {
    final out = <Entity>[];
    PipeEntity pipe(List<Pt> pts) => PipeEntity(id: p.newId(), points: List.of(pts), scope: HydraulicScope.zone, pipeSpecId: lateralPipeSpecId, computerSized: lateralPipeSpecId == null);
    for (final l in laterals) {
      if (l.length >= 2) out.add(pipe(l));
    }
    if (submain.length >= 2) out.add(pipe(submain));
    if (stub.length >= 2) out.add(pipe(stub));
    if (valve != null) out.add(ControlValveEntity(id: p.newId(), position: valve!, valveSpecId: valveSpecId, zoneName: zoneName, name: zoneName));
    for (final r in rings) {
      for (final h in r.halves) {
        if (kind == RingKind.dripline) {
          out.add(TapeEntity(id: p.newId(), points: List.of(h), tapeSpecId: tapeSpecId ?? '', inletHeadM: tapeInletHeadM));
        } else {
          out.add(PipeEntity(id: p.newId(), points: List.of(h), scope: HydraulicScope.zone));
        }
      }
      for (final d in r.drippers) {
        out.add(OutletEntity(id: p.newId(), position: d, outletSpecId: outletSpecId ?? '', nozzleId: nozzleId, headM: headM, zoneName: zoneName));
      }
    }
    return out;
  }
}

/// Trees of a planting grid inside [area]: rows along [o.direction] from
/// the offsets, trees [o.edgeClearance] inside the outline. Grouped by row.
List<List<Pt>> plantingGrid(List<Pt> area, TreeRingOptions o) {
  final region = LayoutRegion(area);
  if (region.isEmpty || !(o.plantSpacing > 0) || !(o.rowSpacing > 0)) return const [];
  final dir = o.direction.length > 0 ? o.direction.normalized : const Pt(1, 0);
  final perp = dir.perpendicular;
  final clear = o.edgeClearance >= 0 ? o.edgeClearance : o.ringRadius;
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in region.outline) {
    vMin = math.min(vMin, p.dot(perp));
    vMax = math.max(vMax, p.dot(perp));
  }
  if ((vMax - vMin) / o.rowSpacing > 20000) return const [];
  final rows = <List<Pt>>[];
  for (var v = vMin + (o.rowOffset > 0 ? o.rowOffset : o.rowSpacing / 2); v <= vMax + 1e-9; v += o.rowSpacing) {
    final origin = perp * v;
    final row = <Pt>[];
    for (final (u0, u1) in region.clipLine(origin, dir)) {
      if ((u1 - u0) / o.plantSpacing > 100000) continue;
      for (var u = u0 + (o.plantOffset > 0 ? o.plantOffset : o.plantSpacing / 2); u <= u1 + 1e-9; u += o.plantSpacing) {
        final p = origin + dir * u;
        if (region.distanceToBoundary(p, maxDistance: clear) < clear - 1e-9) continue;
        row.add(p);
      }
    }
    if (row.isNotEmpty) rows.add(row);
  }
  return rows;
}

/// Surveyed [trees] grouped in rows along [dir]: sorted across the rows,
/// a new row where the gap exceeds [tolerance]; each row sorted along.
List<List<Pt>> treeRows(List<Pt> trees, Pt dir, double tolerance) {
  final d = dir.length > 0 ? dir.normalized : const Pt(1, 0);
  final n = d.perpendicular;
  final sorted = List.of(trees)..sort((a, b) => a.dot(n) != b.dot(n) ? a.dot(n).compareTo(b.dot(n)) : a.dot(d).compareTo(b.dot(d)));
  final rows = <List<Pt>>[];
  double? last;
  for (final t in sorted) {
    final v = t.dot(n);
    if (last == null || v - last > tolerance) rows.add([]);
    rows.last.add(t);
    last = v;
  }
  for (final r in rows) {
    r.sort((a, b) => a.dot(d).compareTo(b.dot(d)));
  }
  return rows;
}

/// Lays out the rings, laterals, submain and valve for the trees of a
/// planting grid in [area], or for the surveyed [trees] (see the library
/// comment).
TreeRingLayout layoutTreeRings({List<Pt>? area, List<Pt>? trees, required TreeRingOptions options}) {
  final o = options;
  final dir = o.direction.length > 0 ? o.direction.normalized : const Pt(1, 0);
  final perp = dir.perpendicular;
  final messages = <String>[];
  final r = math.max(0.05, o.ringRadius);
  final List<List<Pt>> rows;
  if (trees != null && trees.isNotEmpty) {
    final tol = o.rowTolerance > 0 ? o.rowTolerance : (o.rowSpacing > 0 ? o.rowSpacing / 4 : 1.0);
    rows = treeRows(trees, dir, tol);
  } else if (area != null) {
    rows = plantingGrid(area, o);
  } else {
    rows = const [];
  }
  final all = [for (final row in rows) ...row];
  if (all.isEmpty) {
    return TreeRingLayout(trees: const [], rings: const [], laterals: const [], submain: const [], stub: const [], valve: null, kind: o.kind, direction: dir, messages: ['rings_no_trees']);
  }
  // closest neighbours along the rows: rings that would touch
  for (final row in rows) {
    for (var i = 1; i < row.length; i++) {
      if (row[i - 1].distanceTo(row[i]) < 2 * r + 1e-9) {
        if (!messages.contains('rings_overlap')) messages.add('rings_overlap');
      }
    }
  }
  final region = area != null ? LayoutRegion(area) : null;
  // the feed of every row: the start of the row (or its end, or its middle)
  var uMin = double.infinity, uMax = -double.infinity;
  for (final t in all) {
    uMin = math.min(uMin, t.dot(dir));
    uMax = math.max(uMax, t.dot(dir));
  }
  final half = math.max(1.5 * r, (o.plantSpacing > 0 ? o.plantSpacing : 2 * r + 1) / 2);
  final uMid = (uMin + uMax) / 2;
  final rings = <TreeRing>[];
  final laterals = <List<Pt>>[];
  final feeds = <Pt>[];
  for (var k = 0; k < rows.length; k++) {
    final row = rows[k];
    final v = row.fold(0.0, (s, t) => s + t.dot(perp)) / row.length;
    // runs: the trees fed one way from the feed point
    final runs = <(Pt, List<Pt>)>[];
    switch (o.submainPosition) {
      case SubmainPosition.start:
        runs.add((_feedPoint(region, dir, perp, v, row.first.dot(dir) - half, row.first, 1.25 * r), row));
      case SubmainPosition.end:
        runs.add((_feedPoint(region, dir, perp, v, row.last.dot(dir) + half, row.last, 1.25 * r), row.reversed.toList()));
      case SubmainPosition.centre:
        final feed = dir * uMid + perp * v;
        final before = [for (final t in row) if (t.dot(dir) < uMid) t].reversed.toList();
        final after = [for (final t in row) if (t.dot(dir) >= uMid) t];
        if (before.isNotEmpty) runs.add((feed, before));
        if (after.isNotEmpty) runs.add((feed, after));
    }
    for (final (feed, run) in runs) {
      final lateral = <Pt>[feed];
      for (var i = 0; i < run.length; i++) {
        final c = run[i];
        final prev = i == 0 ? feed : run[i - 1];
        final next = i + 1 < run.length ? run[i + 1] : null;
        // the local direction of the lateral through the tree
        var e = next != null ? (next - prev) : (c - prev);
        if (e.length < 1e-9) e = run.length > 1 ? run.last - run.first : dir;
        e = e.normalized;
        final upstream = c - e * r, downstream = c + e * r;
        lateral
          ..add(upstream)
          ..add(downstream);
        rings.add(_ring(c, e, r, k, o));
        if (region != null && i > 0) {
          final mid = Pt.lerp(run[i - 1], c, 0.5);
          if (!region.contains(mid) && !messages.contains('rings_row_gap:$k')) messages.add('rings_row_gap:$k');
        }
      }
      laterals.add(_dedupe(lateral));
    }
    feeds.add(runs.first.$1);
  }
  // submain through the feeds, the valve on a stub
  final submain = feeds.length >= 2 ? _dedupe(feeds) : <Pt>[];
  final Pt anchor;
  final Pt out;
  switch (o.submainPosition) {
    case SubmainPosition.start:
      anchor = submain.isEmpty ? feeds.first : pointAlongPolyline(submain, polylineLength(submain) / 2);
      out = -dir;
    case SubmainPosition.end:
      anchor = submain.isEmpty ? feeds.first : pointAlongPolyline(submain, polylineLength(submain) / 2);
      out = dir;
    case SubmainPosition.centre:
      anchor = feeds.first;
      out = -perp;
  }
  final valve = anchor + out * math.max(0.1, o.submainStub);
  // a valve on a vertex of the submain splits nothing; a stub joins it
  final stub = [valve, anchor];
  if (submain.isNotEmpty && !submain.any((p) => p.distanceTo(anchor) < 1e-9)) {
    // put the anchor on the submain as a vertex
    final (s, _) = polylineStationOf(submain, anchor);
    final pieces = splitPolylineAt(submain, [s]);
    if (pieces.length == 2) {
      submain
        ..clear()
        ..addAll([...pieces[0], ...pieces[1].skip(1)]);
    }
  }
  return TreeRingLayout(trees: all, rings: rings, laterals: laterals, submain: submain, stub: stub, valve: valve, kind: o.kind, direction: dir, messages: messages);
}

/// Feed of a row at u = [u], moved back towards the [first] tree into the
/// area when there is one, but never within [keep] metres of the tree (the
/// lateral must reach the ring from outside).
Pt _feedPoint(LayoutRegion? region, Pt dir, Pt perp, double v, double u, Pt first, double keep) {
  var p = dir * u + perp * v;
  if (region != null && !region.contains(p)) {
    final room = p.distanceTo(first) - keep;
    for (var k = 1; k <= 20 && room > 0; k++) {
      final q = Pt.lerp(p, first, room * k / 20 / p.distanceTo(first));
      if (region.contains(q)) {
        p = q;
        break;
      }
    }
  }
  return p;
}

TreeRing _ring(Pt c, Pt e, double r, int row, TreeRingOptions o) {
  final n = e.perpendicular;
  Pt at(double phi) => c + e * (r * math.cos(phi)) + n * (r * math.sin(phi));
  final up = c - e * r, down = c + e * r;
  if (o.kind == RingKind.dripline) {
    final m = math.max(2, o.ringSegments);
    // from the upstream point (phi = π) to the downstream one (phi = 0),
    // over one side of the row and over the other
    final left = [up, for (var i = 1; i < m; i++) at(math.pi - math.pi * i / m), down];
    final right = [up, for (var i = 1; i < m; i++) at(math.pi + math.pi * i / m), down];
    return TreeRing(tree: c, row: row, halves: [left, right], drippers: const []);
  }
  final count = math.max(1, o.drippersPerTree);
  final phis = [for (var k = 0; k < count; k++) math.pi / count * (1 + 2 * k)];
  final onUp = phis.any((p) => (p - math.pi).abs() < 1e-9);
  final leftPhis = [for (final p in phis) if (p > 1e-9 && p < math.pi - 1e-9) p]..sort((a, b) => b.compareTo(a));
  final rightPhis = [for (final p in phis) if (p > math.pi + 1e-9) p]..sort();
  final left = [up, for (final p in leftPhis) at(p), down];
  final right = [up, for (final p in rightPhis) at(p), down];
  return TreeRing(tree: c, row: row, halves: [left, right], drippers: [if (onUp) up, for (final p in leftPhis) at(p), for (final p in rightPhis) at(p)]);
}

List<Pt> _dedupe(List<Pt> pts) {
  final out = <Pt>[];
  for (final p in pts) {
    if (out.isEmpty || out.last.distanceTo(p) > 1e-9) out.add(p);
  }
  return out;
}
