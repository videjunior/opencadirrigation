/// Layout checks of a plot sheet as it prints, read from its recorded
/// drawing ([RecordedSheet], what [PdfSheetBuilder.recordSheet] draws): where
/// every text lands on the paper, measured with the fonts the PDF writes
/// with; the clipped regions (the drawing area of a drawing sheet, the cells
/// of a detail sheet) and what is drawn in them; and the marks a drawing
/// sheet draws over its drawing area (north arrow, scale bar, the title of a
/// sheet of a set, the credit of the base map). From these: texts printed
/// over each other or under a mark, cut by the edge of their region or off
/// the paper, and texts too small to read.
///
/// Positions are paper millimetres from the bottom-left corner of the sheet,
/// x to the right and y up, as in the PDF.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'fonts/pdf_fonts.dart';
import 'pdf.dart' show PdfAlign, ptPerMm;
import 'sheet_canvas.dart';

/// Height of the capitals of a text and the top and bottom of its box, as
/// fractions of its size in points: Helvetica's capitals (the text height of
/// the plot scene is a cap height), from below the descenders to above the
/// capitals.
const _capEm = 0.72, _topEm = 0.75, _bottomEm = 0.2;

/// Parts of a mark closer than this (mm) are one mark.
const _markGap = 1.2;

/// A text of a sheet where it prints.
class SheetTextBox {
  SheetTextBox._(this.text, this.anchor, this.corners, this.sizePt, this.bold, this.rotationDeg, this.region, this.order) : bounds = Bounds.ofPoints(corners);

  final String text;

  /// The point it is written at (mm): the start, middle or end of its
  /// baseline, as it is aligned.
  final Pt anchor;

  /// Its box along the baseline, from below the descenders to above the
  /// capitals (mm): bottom-left, bottom-right, top-right, top-left.
  final List<Pt> corners;
  final Bounds bounds;
  final double sizePt;
  final bool bold;
  final double rotationDeg;

  /// The clipped region it is drawn in ([SheetReview.regions]); -1 for the
  /// sheet's own parts (frame, legend, tables, title block and the marks
  /// over the drawing).
  final int region;

  /// Its place among the texts, in drawing order.
  final int order;

  /// Height of its capitals on paper (mm): the text height of the plot scene.
  double get capMm => sizePt * _capEm / ptPerMm;

  /// How far its box reaches beyond [b] (mm; 0 when inside).
  double beyond(Bounds b) => corners.fold(0.0, (m, p) => math.max(m, math.max(math.max(b.minX - p.x, p.x - b.maxX), math.max(b.minY - p.y, p.y - b.maxY))));
}

enum SheetMarkKind { northArrow, scaleBar, caption, credit, other }

/// Something a drawing sheet draws over its drawing area: the north arrow,
/// the scale bar, the title of a sheet of a set (on a white box), the credit
/// of the base map.
class SheetMark {
  SheetMark(this.kind, this.box, this.texts);
  final SheetMarkKind kind;

  /// Its extent (mm).
  final Bounds box;

  /// Its texts, in drawing order.
  final List<SheetTextBox> texts;
}

/// Texts printed over each other: each runs into another of the group.
class TextOverlap {
  TextOverlap(this.texts, this.depthMm, this.box);

  /// In drawing order.
  final List<SheetTextBox> texts;

  /// How deep the deepest pair runs into each other (mm): the shortest move
  /// that would part them.
  final double depthMm;

  /// Where they overlap (mm).
  final Bounds box;
}

/// The texts, regions and marks of a recorded sheet, and the checks on them.
class SheetReview {
  /// Reads [sheet], measuring its texts with [fonts]; [ignoreImages] (the
  /// encoded bytes, by identity) are left out of what the regions hold: the
  /// base map under the drawing is not part of the drawing.
  SheetReview(RecordedSheet sheet, {required PdfFonts fonts, Iterable<Uint8List> ignoreImages = const []}) : widthMm = sheet.width / ptPerMm, heightMm = sheet.height / ptPerMm {
    final skip = Set<Uint8List>.identity()..addAll(ignoreImages);
    final stack = <(Bounds?, int)>[];
    Bounds? clip;
    var region = -1;
    // the first region has ended: what follows inside it is drawn over it
    var overFirst = false;
    final parts = <(Bounds, SheetTextBox?)>[];
    Pt mm(double x, double y) => Pt(x / ptPerMm, y / ptPerMm);
    void place(Bounds b, [SheetTextBox? t]) {
      if (b.isEmpty) return;
      if (region >= 0) {
        _boxes[region].add(b);
        _extent[region] = _extent[region].union(b);
      } else if (overFirst && regions.first.contains(b.center)) {
        parts.add((b, t));
      }
    }

    for (final op in sheet.ops) {
      switch (op) {
        case SheetSaveOp():
          stack.add((clip, region));
        case SheetRestoreOp():
          if (stack.isEmpty) break;
          final (c0, r0) = stack.removeLast();
          if (region == 0 && r0 != 0) overFirst = true;
          clip = c0;
          region = r0;
        case SheetClipOp o:
          final r = _norm(o.x / ptPerMm, o.y / ptPerMm, (o.x + o.w) / ptPerMm, (o.y + o.h) / ptPerMm);
          clip = clip == null ? r : _meet(clip, r);
          regions.add(clip);
          _boxes.add([]);
          _extent.add(Bounds.empty);
          region = regions.length - 1;
        case SheetTextOp o:
          final w = fonts.textWidth(o.text, o.size, bold: o.bold) / ptPerMm;
          final top = o.size * _topEm / ptPerMm, bottom = o.size * _bottomEm / ptPerMm;
          final u0 = switch (o.align) {
            PdfAlign.center => -w / 2,
            PdfAlign.right => -w,
            PdfAlign.left => 0.0,
          };
          final a = o.rotationDeg * math.pi / 180, ca = math.cos(a), sa = math.sin(a);
          final at = mm(o.x, o.y);
          Pt p(double u, double v) => Pt(at.x + u * ca - v * sa, at.y + u * sa + v * ca);
          final t = SheetTextBox._(o.text, at, [p(u0, -bottom), p(u0 + w, -bottom), p(u0 + w, top), p(u0, top)], o.size, o.bold, o.rotationDeg, region, texts.length);
          texts.add(t);
          place(t.bounds, t);
        case SheetPathOp o:
          if (o.points.isNotEmpty) place(Bounds.ofPoints([for (final (x, y) in o.points) mm(x, y)]));
        // 1.6.0 MOD: an area with islands
        case SheetRingsOp o:
          final pts = [
            for (final r in o.rings)
              for (final (x, y) in r) mm(x, y),
          ];
          if (pts.isNotEmpty) place(Bounds.ofPoints(pts));
        case SheetRectOp o:
          place(_norm(o.x / ptPerMm, o.y / ptPerMm, (o.x + o.w) / ptPerMm, (o.y + o.h) / ptPerMm));
        case SheetCircleOp o:
          place(Bounds((o.cx - o.r) / ptPerMm, (o.cy - o.r) / ptPerMm, (o.cx + o.r) / ptPerMm, (o.cy + o.r) / ptPerMm));
        case SheetImageOp o:
          if (skip.contains(o.bytes)) break;
          final bl = mm(o.bottomLeft.$1, o.bottomLeft.$2), br = mm(o.bottomRight.$1, o.bottomRight.$2), tl = mm(o.topLeft.$1, o.topLeft.$2);
          place(Bounds.ofPoints([bl, br, tl, br + tl - bl]));
        default:
          break;
      }
    }
    marks = _marksOf(parts);
  }

  /// Paper size (mm).
  final double widthMm, heightMm;

  /// Every text, in drawing order.
  final List<SheetTextBox> texts = [];

  /// The clipped regions in drawing order (mm): the drawing area of a
  /// drawing sheet; the cells of a detail sheet.
  final List<Bounds> regions = [];
  final List<List<Bounds>> _boxes = [];
  final List<Bounds> _extent = [];

  /// What is drawn over the first region after it (on a drawing sheet the
  /// north arrow, the scale bar, the title of a sheet of a set, the map
  /// credit).
  late final List<SheetMark> marks;

  SheetMark? mark(SheetMarkKind k) => marks.where((m) => m.kind == k).firstOrNull;

  /// Extent of everything drawn in region [r] (mm), also where the region
  /// does not show it.
  Bounds drawnIn(int r) => _extent[r];

  /// Extent of most of what region [r] holds (mm): the items whose centres
  /// lie within the [fraction] farthest out on each side (at least one) are
  /// left out (a few items far from the rest). The whole extent when it
  /// holds fewer than 20 items.
  Bounds bulk(int r, {double fraction = 0.01}) {
    final bs = _boxes[r];
    if (bs.length < 20) return _extent[r];
    final xs = [for (final b in bs) b.center.x]..sort();
    final ys = [for (final b in bs) b.center.y]..sort();
    final k = math.max(1, (bs.length * fraction).floor());
    final x0 = xs[k], x1 = xs[bs.length - 1 - k], y0 = ys[k], y1 = ys[bs.length - 1 - k];
    var out = Bounds.empty;
    for (final b in bs) {
      final c = b.center;
      if (c.x >= x0 && c.x <= x1 && c.y >= y0 && c.y <= y1) out = out.union(b);
    }
    return out;
  }

  /// What region [r] holds away from [core] (outside it grown by [pad]),
  /// as the extents of groups of items (at most [max], the largest first).
  List<Bounds> away(int r, Bounds core, {double pad = 2, int max = 6}) {
    final near = core.inflate(pad);
    final groups = <Bounds>[];
    for (final b in _boxes[r]) {
      if (b.intersects(near)) continue;
      var g = b;
      for (var merged = true; merged;) {
        merged = false;
        for (var i = groups.length - 1; i >= 0; i--) {
          if (groups[i].inflate(pad).intersects(g)) {
            g = g.union(groups.removeAt(i));
            merged = true;
          }
        }
      }
      groups.add(g);
    }
    groups.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return groups.take(max).toList();
  }

  /// Texts that run into each other, grouped (a group is a chain of
  /// overlapping pairs), the deepest first. A pair counts when it runs in
  /// deeper than [minDepthMm] and [relDepth] of the lower cap height (less
  /// is a touch) where its region shows it. Texts of the drawing are
  /// compared with each other, the sheet's own texts with each other.
  List<TextOverlap> overlaps({double minDepthMm = 0.3, double relDepth = 0.12}) {
    final n = texts.length;
    final byX = List<int>.generate(n, (i) => i)..sort((a, b) => texts[a].bounds.minX.compareTo(texts[b].bounds.minX));
    final parent = List<int>.generate(n, (i) => i);
    int root(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    final pairs = <(int, int, double, Bounds)>[];
    for (var x = 0; x < n; x++) {
      final a = texts[byX[x]];
      for (var y = x + 1; y < n; y++) {
        final b = texts[byX[y]];
        if (b.bounds.minX > a.bounds.maxX) break;
        if (a.region != b.region || b.bounds.minY > a.bounds.maxY || b.bounds.maxY < a.bounds.minY) continue;
        final d = _depth(a.corners, b.corners);
        if (d <= 0 || d < math.max(minDepthMm, relDepth * math.min(a.capMm, b.capMm))) continue;
        var where = _meet(a.bounds, b.bounds);
        if (a.region >= 0) where = _meet(where, regions[a.region]);
        if (where.isEmpty) continue;
        pairs.add((a.order, b.order, d, where));
        parent[root(a.order)] = root(b.order);
      }
    }
    final groups = <int, (Set<int>, double, Bounds)>{};
    for (final (i, j, d, where) in pairs) {
      final g = groups[root(i)];
      groups[root(i)] = g == null ? ({i, j}, d, where) : (g.$1..addAll([i, j]), math.max(g.$2, d), g.$3.union(where));
    }
    return [
      for (final (ids, d, where) in groups.values) TextOverlap([for (final i in ids.toList()..sort()) texts[i]], d, where),
    ]..sort((a, b) => b.depthMm.compareTo(a.depthMm));
  }

  /// Texts of the drawing (the first region) under a mark, with how deep
  /// they run under it (mm).
  List<(SheetTextBox, SheetMark, double)> underMarks({double minDepthMm = 0.3, double relDepth = 0.12}) {
    final out = <(SheetTextBox, SheetMark, double)>[];
    for (final m in marks) {
      final box = [Pt(m.box.minX, m.box.minY), Pt(m.box.maxX, m.box.minY), Pt(m.box.maxX, m.box.maxY), Pt(m.box.minX, m.box.maxY)];
      for (final t in texts) {
        if (t.region != 0 || !t.bounds.intersects(m.box)) continue;
        final d = _depth(t.corners, box);
        if (d > 0 && d >= math.max(minDepthMm, relDepth * t.capMm)) out.add((t, m, d));
      }
    }
    return out;
  }

  /// Texts of a region that run across its edge, part inside, with how far
  /// they reach out (mm, more than [tolMm]).
  List<(SheetTextBox, double)> cut({double tolMm = 0.2}) => [
    for (final t in texts)
      if (t.region >= 0 && t.bounds.intersects(regions[t.region]) && t.beyond(regions[t.region]) > tolMm) (t, t.beyond(regions[t.region])),
  ];

  /// Texts of a region that lie wholly outside it: not printed.
  List<SheetTextBox> hidden() => [
    for (final t in texts)
      if (t.region >= 0 && !t.bounds.intersects(regions[t.region])) t,
  ];

  /// The sheet's own texts (not of a region) reaching beyond [frame] (mm,
  /// more than [tolMm]), with how far.
  List<(SheetTextBox, double)> beyond(Bounds frame, {double tolMm = 0.2}) => [
    for (final t in texts)
      if (t.region < 0 && t.beyond(frame) > tolMm) (t, t.beyond(frame)),
  ];

  /// Texts of the regions (the drawing, the details) whose capitals are
  /// lower than [minCapMm] on paper.
  List<SheetTextBox> small(double minCapMm) => [
    for (final t in texts)
      if (t.region >= 0 && t.capMm < minCapMm - 1e-6) t,
  ];
}

/// The rectangle of two corners in any order.
Bounds _norm(double x0, double y0, double x1, double y1) => Bounds(math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1));

/// The common part of [a] and [b] (empty when they do not meet).
Bounds _meet(Bounds a, Bounds b) {
  final out = Bounds(math.max(a.minX, b.minX), math.max(a.minY, b.minY), math.min(a.maxX, b.maxX), math.min(a.maxY, b.maxY));
  return out.isEmpty ? Bounds.empty : out;
}

/// How deep the rectangles [a] and [b] (four corners each, in order) run
/// into each other: the shortest move along an axis of their sides that
/// parts them; 0 when they do not meet.
double _depth(List<Pt> a, List<Pt> b) {
  var best = double.infinity;
  for (final poly in [a, b]) {
    for (var i = 0; i < 2; i++) {
      final e = poly[i + 1] - poly[i];
      final len = e.length;
      if (len < 1e-9) continue;
      final n = Pt(-e.y / len, e.x / len);
      var a0 = double.infinity, a1 = -double.infinity, b0 = double.infinity, b1 = -double.infinity;
      for (final p in a) {
        final d = p.dot(n);
        a0 = math.min(a0, d);
        a1 = math.max(a1, d);
      }
      for (final p in b) {
        final d = p.dot(n);
        b0 = math.min(b0, d);
        b1 = math.max(b1, d);
      }
      final o = math.min(a1, b1) - math.max(a0, b0);
      if (o <= 0) return 0;
      best = math.min(best, o);
    }
  }
  return best.isFinite ? best : 0;
}

/// The parts drawn over the first region, gathered into marks.
List<SheetMark> _marksOf(List<(Bounds, SheetTextBox?)> parts) {
  final groups = <(Bounds, List<SheetTextBox>)>[];
  for (final (b, t) in parts) {
    var box = b;
    final ts = <SheetTextBox>[?t];
    for (var merged = true; merged;) {
      merged = false;
      for (var i = groups.length - 1; i >= 0; i--) {
        if (groups[i].$1.inflate(_markGap).intersects(box)) {
          final (gb, gt) = groups.removeAt(i);
          box = box.union(gb);
          ts.addAll(gt);
          merged = true;
        }
      }
    }
    groups.add((box, ts));
  }
  return [for (final (box, ts) in groups) SheetMark(_kindOf(ts), box, ts..sort((a, b) => a.order.compareTo(b.order)))];
}

SheetMarkKind _kindOf(List<SheetTextBox> ts) {
  if (ts.any((t) => t.text == 'N' && t.bold)) return SheetMarkKind.northArrow;
  if (ts.length >= 2 && ts.any((t) => t.text == '0')) return SheetMarkKind.scaleBar;
  if (ts.any((t) => t.bold)) return SheetMarkKind.caption;
  return ts.isEmpty ? SheetMarkKind.other : SheetMarkKind.credit;
}
