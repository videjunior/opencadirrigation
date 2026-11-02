/// Native CAD drawing for the R2000 writers (DXF AC1015 in
/// `dxf_r2000.dart`, DWG AC1015 in `dwg_writer.dart`): layers with their
/// true colours and linetypes, dimension styles, block definitions with
/// attribute definitions, and the entities CAD programs edit natively
/// (lightweight polylines with arcs, splines, hatches, multiline text,
/// dimensions with their anonymous blocks, leaders, block references with
/// attributes). The project is turned into this model by `cad_export.dart`;
/// both writers take the same model, so the DXF and the DWG carry the same
/// drawing. Coordinates are world metres.
library;

import 'dart:math' as math;

import '../model/geometry.dart';

/// A layer: colour index (ACI, 1–255), optional true colour (0xRRGGBB,
/// DXF code 420), linetype name, and the on/locked/plot states.
class CadLayer {
  const CadLayer(this.name, {this.aci = 7, this.rgb, this.linetype = 'Continuous', this.off = false, this.locked = false, this.plot = true});
  final String name;
  final int aci;
  final int? rgb;
  final String linetype;
  final bool off, locked, plot;
}

/// A simple linetype: dash lengths (positive), gaps (negative) and dots (0)
/// in drawing units, repeated along the line.
class CadLinetype {
  const CadLinetype(this.name, this.description, this.dashes);
  final String name;
  final String description;
  final List<double> dashes;
  double get patternLength => dashes.fold(0.0, (s, d) => s + d.abs());
}

/// A dimension style. Sizes are paper sizes multiplied by [scale] (DIMSCALE),
/// as CAD programs keep them; [lengthFactor] (DIMLFAC) turns the measured
/// metres into the displayed unit and [suffix] (DIMPOST, `<>` = the value)
/// names it. [horizontalText] keeps the text horizontal (DIMTIH, DIMTOH)
/// instead of aligned with the dimension line.
class CadDimStyle {
  const CadDimStyle(
    this.name, {
    this.scale = 1,
    this.textHeight = 2.5,
    this.arrowSize = 2.5,
    this.extOffset = 0.625,
    this.extBeyond = 1.25,
    this.gap = 0.625,
    this.decimals = 2,
    this.angleDecimals = 1,
    this.lengthFactor = 1,
    this.suffix = '',
    this.horizontalText = false,
    this.centerMark = 0,
    this.suppressZeros = 0,
  });

  /// The style every drawing has (the usual metric defaults of CAD programs).
  static const standard = CadDimStyle('Standard', suppressZeros: 8);

  final String name;
  final double scale, textHeight, arrowSize, extOffset, extBeyond, gap;
  final int decimals, angleDecimals;
  final double lengthFactor;
  final String suffix;
  final bool horizontalText;
  final double centerMark;

  /// DIMZIN: 0 keeps the trailing zeros ("10.00"), 8 drops them.
  final int suppressZeros;

  double get textSize => textHeight * scale;
  double get arrowLength => arrowSize * scale;
  double get offset => extOffset * scale;
  double get beyond => extBeyond * scale;
  double get textGap => gap * scale;
}

/// Base of the native entities: layer and colour (256 = by layer, 0 = by
/// block).
sealed class CadEntity {
  const CadEntity(this.layer, {this.color = 256});
  final String layer;
  final int color;

  /// Points that bound the entity (for the drawing extents).
  Iterable<Pt> get extentPoints;
}

class CadLine extends CadEntity {
  const CadLine(super.layer, this.a, this.b, {super.color, this.z = 0});
  final Pt a, b;
  final double z;
  @override
  Iterable<Pt> get extentPoints => [a, b];
}

/// Lightweight polyline. [bulges] (empty, or one per vertex) give the arc
/// from each vertex to the next: the tangent of a quarter of the included
/// angle, positive counter-clockwise. [elevation] is the Z of every vertex.
class CadPolyline extends CadEntity {
  const CadPolyline(super.layer, this.points, {super.color, this.bulges = const [], this.closed = false, this.elevation = 0, this.width = 0});
  final List<Pt> points;
  final List<double> bulges;
  final bool closed;
  final double elevation;

  /// Constant width (0 = thin line).
  final double width;
  bool get hasBulges => bulges.any((b) => b != 0);
  double bulgeAt(int i) => i < bulges.length ? bulges[i] : 0;
  @override
  Iterable<Pt> get extentPoints => points;
}

class CadCircle extends CadEntity {
  const CadCircle(super.layer, this.center, this.radius, {super.color});
  final Pt center;
  final double radius;
  @override
  Iterable<Pt> get extentPoints => [center - Pt(radius, radius), center + Pt(radius, radius)];
}

/// Arc counter-clockwise from [startDeg] to [endDeg].
class CadArc extends CadEntity {
  const CadArc(super.layer, this.center, this.radius, this.startDeg, this.endDeg, {super.color});
  final Pt center;
  final double radius, startDeg, endDeg;
  @override
  Iterable<Pt> get extentPoints => [center - Pt(radius, radius), center + Pt(radius, radius)];
}

class CadPoint extends CadEntity {
  const CadPoint(super.layer, this.position, {super.color, this.z = 0});
  final Pt position;
  final double z;
  @override
  Iterable<Pt> get extentPoints => [position];
}

/// Single-line text. [hAlign] 0 left, 1 centre, 2 right; [vAlign] 0
/// baseline, 1 bottom, 2 middle, 3 top: anything but left/baseline places
/// the text by its alignment point, which is then [position].
class CadText extends CadEntity {
  const CadText(super.layer, this.position, this.text, this.height, {super.color, this.rotationDeg = 0, this.hAlign = 0, this.vAlign = 0, this.z = 0});
  final Pt position;
  final String text;
  final double height, rotationDeg;
  final int hAlign, vAlign;
  final double z;
  bool get aligned => hAlign != 0 || vAlign != 0;
  @override
  Iterable<Pt> get extentPoints => [position, position + Pt.polar(height * 0.6 * text.length, degToRad(rotationDeg)) + Pt.polar(height, degToRad(rotationDeg) + math.pi / 2)];
}

/// Multiline text: plain [text] with line breaks (the writers escape it),
/// [attachment] 1–9 (top-left … bottom-right; 5 = middle centre), [width] of
/// the reference rectangle (0 = no wrapping).
class CadMText extends CadEntity {
  const CadMText(super.layer, this.position, this.text, this.height, {super.color, this.attachment = 7, this.rotationDeg = 0, this.width = 0});
  final Pt position;
  final String text;
  final double height;
  final int attachment;
  final double rotationDeg, width;
  @override
  Iterable<Pt> get extentPoints => [position];
}

/// NURBS curve of [degree] (non-rational): [control] points and [knots]
/// (control + degree + 1 values), plus the [fit] points the curve passes
/// through and their end tangents (unit vectors) when known.
class CadSpline extends CadEntity {
  const CadSpline(super.layer, {super.color, this.degree = 3, required this.control, required this.knots, this.fit = const [], this.closed = false, this.startTangent, this.endTangent});
  final int degree;
  final List<Pt> control;
  final List<double> knots;
  final List<Pt> fit;
  final bool closed;
  final Pt? startTangent, endTangent;
  @override
  Iterable<Pt> get extentPoints => control;
}

/// A closed boundary loop of a hatch: vertices and bulges (as a polyline).
class CadLoop {
  const CadLoop(this.points, [this.bulges = const []]);
  final List<Pt> points;
  final List<double> bulges;
  bool get hasBulges => bulges.any((b) => b != 0);
  double bulgeAt(int i) => i < bulges.length ? bulges[i] : 0;
}

/// One line family of a hatch pattern: angle, base point, offset to the
/// next line (world units) and dashes (empty = continuous).
class CadHatchLine {
  const CadHatchLine(this.angleDeg, this.base, this.offset, [this.dashes = const []]);
  final double angleDeg;
  final Pt base, offset;
  final List<double> dashes;
}

/// Hatch: solid fill, or the predefined [pattern] turned by [patternAngleDeg]
/// and scaled by [patternScale], whose resulting line families are [lines].
/// The first loop is the outer boundary, the others islands.
class CadHatch extends CadEntity {
  const CadHatch(super.layer, this.loops, {super.color, this.solid = false, this.pattern = 'SOLID', this.patternAngleDeg = 0, this.patternScale = 1, this.lines = const []});
  final List<CadLoop> loops;
  final bool solid;
  final String pattern;
  final double patternAngleDeg, patternScale;
  final List<CadHatchLine> lines;
  @override
  Iterable<Pt> get extentPoints => loops.expand((l) => l.points);
}

/// Filled triangle or quadrilateral (arrowheads), corners in the order of the
/// format: 1, 2, 3, 4 with 3 and 4 swapped against the outline ("bow-tie").
class CadSolid extends CadEntity {
  const CadSolid(super.layer, this.p1, this.p2, this.p3, this.p4, {super.color});

  /// Triangle a, b, c (the fourth corner repeats the third).
  CadSolid.triangle(String layer, Pt a, Pt b, Pt c, {int color = 256}) : this(layer, a, b, c, c, color: color);
  final Pt p1, p2, p3, p4;
  @override
  Iterable<Pt> get extentPoints => [p1, p2, p3, p4];
}

/// Attribute value of a block reference (or, in a block, its definition with
/// the default [value] and a [prompt]).
class CadAttrib {
  const CadAttrib(this.tag, this.value, this.position, this.height, {this.rotationDeg = 0, this.invisible = true, this.prompt = ''});
  final String tag, value;
  final Pt position;
  final double height, rotationDeg;
  final bool invisible;
  final String prompt;
}

/// Block reference with its attributes (already placed in world
/// coordinates).
class CadInsert extends CadEntity {
  const CadInsert(super.layer, this.block, this.position, {super.color, this.scale = 1, this.rotationDeg = 0, this.attribs = const []});
  final String block;
  final Pt position;
  final double scale, rotationDeg;
  final List<CadAttrib> attribs;
  @override
  Iterable<Pt> get extentPoints => [position];
}

enum CadDimKind { aligned, angular, radius, diameter, ordinate }

/// Dimension with its anonymous block (geometry already drawn, in world
/// coordinates). Definition points as the formats name them: [defPoint]
/// (10: dimension line, arc point, centre, far chord point or ordinate
/// origin), [p13]/[p14] (extension line origins, ordinate feature and leader
/// end), [p15] (angle vertex or the point on the circle). [text] is the
/// override (empty = the measured value, `<>` stands for it).
class CadDimension extends CadEntity {
  const CadDimension(
    super.layer,
    this.kind, {
    super.color,
    required this.block,
    required this.style,
    required this.defPoint,
    required this.textMid,
    this.p13 = Pt.zero,
    this.p14 = Pt.zero,
    this.p15 = Pt.zero,
    required this.measurement,
    this.text = '',
    this.userTextPosition = false,
    this.xOrdinate = true,
  });
  final CadDimKind kind;
  final String block, style;
  final Pt defPoint, textMid, p13, p14, p15;
  final double measurement;
  final String text;
  final bool userTextPosition;

  /// Ordinate dimensions: measures X (the datum is the Y axis) when true.
  final bool xOrdinate;

  /// DXF code 70 (type, block-referenced bit, ordinate X bit, user text position).
  int get dxfFlags =>
      switch (kind) {
        CadDimKind.aligned => 1,
        CadDimKind.angular => 5,
        CadDimKind.radius => 4,
        CadDimKind.diameter => 3,
        CadDimKind.ordinate => 6,
      } |
      32 |
      (kind == CadDimKind.ordinate && xOrdinate ? 64 : 0) |
      (userTextPosition ? 128 : 0);
  @override
  Iterable<Pt> get extentPoints => [defPoint, textMid, p13, p14, p15];
}

/// Leader: arrowhead at the first vertex, drawn with the sizes of [style];
/// its note is a separate multiline text.
class CadLeader extends CadEntity {
  const CadLeader(super.layer, this.points, {super.color, required this.style, this.arrow = true});
  final List<Pt> points;
  final String style;
  final bool arrow;
  @override
  Iterable<Pt> get extentPoints => points;
}

/// Block definition: entities in block coordinates around [base];
/// [attdefs] define the attributes its references carry. Anonymous blocks
/// (`*D…`) hold the geometry of dimensions, in world coordinates.
class CadBlock {
  CadBlock(this.name, this.entities, {this.base = Pt.zero, this.attdefs = const []});
  final String name;
  final Pt base;
  final List<CadEntity> entities;
  final List<CadAttrib> attdefs;
  bool get anonymous => name.startsWith('*');
}

class CadDrawing {
  CadDrawing({
    required this.layers,
    this.linetypes = const [],
    this.dimStyles = const [],
    this.blocks = const [],
    required this.entities,
    this.textFont = 'arial.ttf',
    this.pointMode = 0,
    this.pointSize = 0,
    this.xdata = const {},
  });
  final List<CadLayer> layers;
  final List<CadLinetype> linetypes;
  final List<CadDimStyle> dimStyles;
  final List<CadBlock> blocks;
  final List<CadEntity> entities;

  /// Extended data of the application `OPENCADIRRIGATION` (cad_xdata.dart)
  /// by entity (the very objects of [entities]): code and value of each
  /// group after the 1001 group.
  final Map<CadEntity, List<(int, Object)>> xdata;

  /// Font of the Standard text style (a TrueType font shows accents).
  final String textFont;

  /// Point display ($PDMODE, $PDSIZE: absolute size when positive).
  final int pointMode;
  final double pointSize;

  CadBlock? block(String name) => blocks.where((b) => b.name == name).firstOrNull;

  /// Extents of the model space (block references by their insertion point
  /// and the size of their block).
  Bounds get extents {
    var b = Bounds.empty;
    final blockRadius = <String, double>{};
    double radiusOf(String name) => blockRadius.putIfAbsent(name, () {
      var r = 0.0;
      final blk = block(name);
      if (blk == null) return 0;
      for (final e in blk.entities) {
        for (final p in e.extentPoints) {
          r = math.max(r, p.distanceTo(blk.base));
        }
      }
      return r;
    });
    for (final e in entities) {
      if (e is CadInsert) {
        final r = radiusOf(e.block) * e.scale.abs();
        b = b.include(e.position - Pt(r, r)).include(e.position + Pt(r, r));
      } else {
        for (final p in e.extentPoints) {
          if (p.x.isFinite && p.y.isFinite) b = b.include(p);
        }
      }
    }
    return b.isEmpty ? const Bounds(0, 0, 1, 1) : b;
  }
}

// ------------------------------------------------------------------ colours

/// RGB (0xRRGGBB) of the colour index (ACI) [i] (0–255): the nine basic
/// colours, 24 hues × 5 shades × 2 saturations, and six greys.
int aciRgb(int i) {
  const basic = [0x000000, 0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFFFFFF, 0x808080, 0xC0C0C0];
  if (i < 0 || i > 255) return 0xFFFFFF;
  if (i < 10) return basic[i];
  if (i >= 250) return const [0x333333, 0x505050, 0x696969, 0x828282, 0xBEBEBE, 0xFFFFFF][i - 250];
  final hue = ((i ~/ 10) - 1) * 15.0;
  final d = i % 10;
  final v = const [1.0, 1.0, 0.65, 0.65, 0.5, 0.5, 0.3, 0.3, 0.15, 0.15][d] * 255;
  final lo = d.isEven ? 0.0 : v / 2;
  // hue sector between two primaries; the minor channel rises or falls with the hue
  final h = hue / 60, f = h - h.floor();
  final up = lo + (v - lo) * f, down = v - (v - lo) * f;
  final (r, g, b) = switch (h.floor() % 6) {
    0 => (v, up, lo),
    1 => (down, v, lo),
    2 => (lo, v, up),
    3 => (lo, down, v),
    4 => (up, lo, v),
    _ => (v, lo, down),
  };
  return (r.round() << 16) | (g.round() << 8) | b.round();
}

/// Nearest colour index (1–255) to [rgb]; near-white and near-black colours
/// become 7, which CAD programs draw white on dark and black on light
/// backgrounds.
int nearestAci(int rgb) {
  final r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
  if ((r > 235 && g > 235 && b > 235) || (r < 20 && g < 20 && b < 20)) return 7;
  var best = 7, bestD = 1 << 30;
  for (var i = 1; i < 256; i++) {
    final c = aciRgb(i);
    final dr = r - ((c >> 16) & 0xFF), dg = g - ((c >> 8) & 0xFF), db = b - (c & 0xFF);
    // weighted distance (the eye is most sensitive to green)
    final dist = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
    if (dist < bestD) {
      bestD = dist;
      best = i;
    }
  }
  return best;
}

/// [name] as a valid table name of the formats (layers, blocks): the
/// characters `<>/\":;?*|=,` and the backquote become `_`, control
/// characters are dropped, and an empty name becomes [fallback].
String cadTableName(String name, [String fallback = '0']) {
  final s = name.trim().replaceAll(RegExp(r'[<>/\\":;?*|=,`]'), '_').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  return s.isEmpty ? fallback : (s.length > 255 ? s.substring(0, 255) : s);
}
