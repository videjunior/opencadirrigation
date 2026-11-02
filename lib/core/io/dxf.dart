/// Minimal DXF reader/writer (ASCII). Reads LINE, LWPOLYLINE and POLYLINE
/// (with bulges; polyface and polygon meshes by their vertices), CIRCLE,
/// ARC, ELLIPSE, SPLINE (fit points, or the NURBS evaluated from its control
/// points), HATCH (boundary paths of polylines, lines, arcs, ellipses and
/// splines; pattern angle and spacing), SOLID, TRACE, 3DFACE (its corners as
/// spot heights when it has elevations, else its outline), TEXT and ATTRIB
/// (placed by their justification), MTEXT (paragraphs kept, formatting codes
/// dropped, placed by its attachment point), MULTILEADER (text and leader
/// lines), MLINE (its reference line), LEADER (its line) and POINT entities
/// with their layers (colour, true colour, off and frozen), `\U+XXXX`
/// characters and `%%` symbols decoded, and expands block references
/// (INSERT, MINSERT, the blocks of DIMENSION and ACAD_TABLE). Paper space
/// is left out. Writes an R12-compatible file with a LAYER table (the
/// R2000 export with native entities is in `dxf_r2000.dart`).
///
/// The text is read group by group without being split into lines, and a
/// stray line (a text value broken in two) only costs that line: the reader
/// finds the next group code and says how many lines it skipped.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'cad_xdata.dart' show readHydraulicXdata;
import 'codepages.dart';
import 'work_slicer.dart';

class DxfEntity {
  DxfEntity({
    required this.type,
    required this.layer,
    this.points = const [],
    this.center,
    this.radius = 0,
    this.startAngle = 0,
    this.endAngle = 0,
    this.text = '',
    this.height = 1,
    this.rotation = 0,
    this.closed = false,
    this.color = 256,
    this.elevation,
    this.name = '',
    this.solid = false,
    this.xdata,
  });

  /// LINE, POLYLINE, SPLINE (fit points), HATCH, CIRCLE, ARC, TEXT, POINT.
  /// A HATCH carries its boundary in [points], the pattern line angle in
  /// [rotation] (degrees), the line spacing in [height] and [solid] fills.
  final String type;
  final String layer;
  final List<Pt> points;
  final Pt? center;
  final double radius;
  final double startAngle; // degrees
  final double endAngle;
  final String text;
  final double height;
  final double rotation;
  final bool closed;
  final int color;

  /// Elevation (Z) when meaningful (contours from KML/DWG, spot heights).
  final double? elevation;
  final String name;

  /// Solid fill (HATCH).
  final bool solid;

  /// The hydraulic data the app wrote in the extended data of the entity
  /// (cad_xdata.dart), when it has any: a pipe, lateral or drip line, or a
  /// label drawn for an item (`PART_OF`).
  final Map<String, String>? xdata;

  /// This entity with another [elevation].
  DxfEntity withElevation(double? z) => DxfEntity(
    type: type,
    layer: layer,
    points: points,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
    text: text,
    height: height,
    rotation: rotation,
    closed: closed,
    color: color,
    elevation: z,
    name: name,
    solid: solid,
    xdata: xdata,
  );

  /// This entity with the hydraulic data [x].
  DxfEntity withXdata(Map<String, String>? x) => DxfEntity(
    type: type,
    layer: layer,
    points: points,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
    text: text,
    height: height,
    rotation: rotation,
    closed: closed,
    color: color,
    elevation: elevation,
    name: name,
    solid: solid,
    xdata: x,
  );
}

/// A hydraulic item of the app exported as a block reference (an outlet,
/// a valve, a pump…), or a block drawn for one (the outlet symbols of a
/// lateral: `PART_OF` in [xdata]): its data from the extended data, where
/// it was inserted, and the drawing of the reference.
class DxfItem {
  DxfItem(this.xdata, this.position, this.layer, this.fallback);
  final Map<String, String> xdata;
  final Pt position;
  final String layer;

  /// The block of the reference drawn where it was inserted: these very
  /// entities are in [DxfDocument.entities] as well (a reader of the
  /// drawing sees it whole); an import that restores the item leaves them
  /// out.
  final List<DxfEntity> fallback;
}

class DxfLayer {
  DxfLayer(this.name, {this.color = 7, this.visible = true, this.rgb});
  final String name;

  /// Colour index (1–255).
  final int color;

  /// False for a layer the drawing has off or frozen.
  final bool visible;

  /// True colour (0xRRGGBB) when the layer has one.
  final int? rgb;
}

class DxfDocument {
  DxfDocument({List<DxfEntity>? entities, List<DxfLayer>? layers, this.unitScale = 1, List<String>? warnings, List<DxfItem>? items})
    : entities = entities ?? [],
      layers = layers ?? [],
      warnings = warnings ?? [],
      items = items ?? [];
  final List<DxfEntity> entities;
  final List<DxfLayer> layers;

  /// The hydraulic items of the app exported as block references (their
  /// blocks are not among [entities]).
  final List<DxfItem> items;

  /// Multiplier from file units to metres ($INSUNITS), 1 if unknown.
  final double unitScale;

  /// Notes for the import message (codes of `warn.*`, with a detail after
  /// `:`): lines skipped, paper space left out, unsupported entities…
  final List<String> warnings;

  Bounds get bounds {
    var b = Bounds.empty;
    for (final e in entities) {
      for (final p in e.points) {
        b = b.include(p);
      }
      if (e.center != null) {
        b = b.include(e.center! - Pt(e.radius, e.radius)).include(e.center! + Pt(e.radius, e.radius));
      }
    }
    return b;
  }
}

/// A block definition: entities in block coordinates plus nested references.
class DxfBlock {
  DxfBlock(this.name, this.base, this.entities, this.inserts, {this.xref = false});
  final String name;
  final Pt base;
  final List<DxfEntity> entities;
  final List<DxfInsert> inserts;

  /// An external reference (a drawing the file only points to).
  final bool xref;
}

/// A block reference (INSERT / MINSERT / the anonymous block of a DIMENSION).
class DxfInsert {
  DxfInsert({
    required this.name,
    required this.layer,
    this.color = 256,
    required this.position,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.cols = 1,
    this.rows = 1,
    this.colSpacing = 0,
    this.rowSpacing = 0,
    this.ocsMirror = false,
  });
  final String name;
  final String layer;
  final int color;
  final Pt position;
  final double scaleX;
  final double scaleY;

  /// Degrees.
  final double rotation;
  final int cols;
  final int rows;
  final double colSpacing;
  final double rowSpacing;

  /// Extrusion (0, 0, −1): position, rotation and block are in an object
  /// coordinate system whose X axis is the world −X (see [Affine2.ocsMirror]).
  final bool ocsMirror;

  /// The values of the attributes that follow the reference (ATTRIB), by
  /// tag in upper case, invisible ones included.
  final Map<String, String> attributes = {};

  /// Z of the insertion point, when the file gives it.
  double? z;

  /// A survey point (see [DxfReader.surveyPoints]): the points of its block
  /// are its marker, not data.
  bool survey = false;

  /// The hydraulic data the app wrote in the extended data of the
  /// reference (an outlet, a valve…), when it has any.
  Map<String, String>? xdata;

  /// Block → world transform of the array cell ([col], [row]).
  Affine2 affine(Pt base, [int col = 0, int row = 0]) {
    final r = degToRad(rotation);
    final cs = math.cos(r), sn = math.sin(r);
    final m = Affine2(scaleX * cs, -scaleY * sn, scaleX * sn, scaleY * cs, 0, 0);
    final offset = Pt.polar(col * colSpacing, r) + Pt.polar(row * rowSpacing, r + math.pi / 2);
    final mb = m.apply(base);
    final local = Affine2(m.a, m.b, m.c, m.d, position.x + offset.x - mb.x, position.y + offset.y - mb.y);
    return ocsMirror ? Affine2.ocsMirror.then(local) : local;
  }
}

/// x' = a·x + b·y + tx, y' = c·x + d·y + ty.
class Affine2 {
  const Affine2(this.a, this.b, this.c, this.d, this.tx, this.ty);
  final double a, b, c, d, tx, ty;
  Pt apply(Pt p) => Pt(a * p.x + b * p.y + tx, c * p.x + d * p.y + ty);

  /// This transform applied after [inner].
  Affine2 then(Affine2 inner) =>
      Affine2(a * inner.a + b * inner.c, a * inner.b + b * inner.d, c * inner.a + d * inner.c, c * inner.b + d * inner.d, a * inner.tx + b * inner.ty + tx, c * inner.tx + d * inner.ty + ty);

  /// Object coordinates of an entity whose extrusion is (0, 0, −1), the
  /// usual result of mirroring in CAD programs, to world coordinates: by
  /// the arbitrary axis algorithm its X axis is the world −X.
  static const ocsMirror = Affine2(-1, 0, 0, 1, 0, 0);

  /// Uniform scale and rotation only (circles stay circles).
  bool get isSimilarity {
    final eps = 1e-9 * (a.abs() + b.abs() + c.abs() + d.abs() + 1);
    return (a - d).abs() < eps && (b + c).abs() < eps;
  }

  /// Uniform scale, rotation and possibly a reflection: circles stay
  /// circles, arcs turn the other way when [mirrored].
  bool get isConformal {
    final eps = 1e-9 * (a.abs() + b.abs() + c.abs() + d.abs() + 1);
    return isSimilarity || ((a + d).abs() < eps && (b - c).abs() < eps);
  }

  bool get mirrored => a * d - b * c < 0;

  double get scale => math.sqrt((a * d - b * c).abs());
  double get rotationDeg => radToDeg(math.atan2(c, a));

  /// Angle (degrees) of the direction at [deg] once transformed.
  double dirDeg(double deg) {
    final r = degToRad(deg);
    final x = math.cos(r), y = math.sin(r);
    return radToDeg(math.atan2(c * x + d * y, a * x + b * y));
  }
}

/// Whether the extrusion direction ([x], [y], [z]) is the world −Z (the
/// object coordinates are mirrored, see [Affine2.ocsMirror]). Other
/// directions (3D entities) are drawn as projected.
bool ocsIsMirrored(double x, double y, double z) => z < 0 && x.abs() < 1 / 64 && y.abs() < 1 / 64;

/// [deg] brought into [0, 360) (a damaged or radian value would otherwise
/// sweep millions of turns); 0 when it is not a number.
double cadNormalizeDeg(double deg) {
  if (!deg.isFinite) return 0;
  final r = deg % 360;
  return r < 0 ? r + 360 : r;
}

/// The sweep from [a0] to [a1] (radians, counter-clockwise) within one
/// turn: (0, 2π], a full turn when they coincide.
double cadSweepRad(double a0, double a1) {
  if (!a0.isFinite || !a1.isFinite) return 2 * math.pi;
  var s = (a1 - a0) % (2 * math.pi);
  if (s < 0) s += 2 * math.pi;
  if (s <= 1e-12) s = 2 * math.pi;
  return s;
}

/// Lower-left corner (the point the program draws a text from) of a text
/// of [height] whose anchor is [anchor]: [hf] is the horizontal position of
/// the anchor across the text (0 left, ½ centre, 1 right) and [vf] its
/// height above that corner, as a fraction of the box. The box is the one
/// the program draws: 0.6·height per character, 1.2·height per line.
Pt cadTextBase(Pt anchor, String text, double height, double rotationDeg, double hf, double vf) {
  final lines = text.split('\n');
  var longest = 0;
  for (final l in lines) {
    longest = math.max(longest, l.length);
  }
  final w = 0.6 * height * longest;
  final h = lines.length <= 1 ? height : 1.2 * height * lines.length;
  final u = Pt.polar(1, degToRad(rotationDeg)), v = u.perpendicular;
  return anchor - u * (w * hf) - v * (h * vf);
}

class _Vertex {
  _Vertex(this.x, this.y, [this.bulge = 0]);
  final double x;
  double y;
  double bulge;
}

/// The groups (code, value) of a DXF text one after another, without the
/// text being split into lines. A line where a group code should be that is
/// not one (a text value broken over two lines, a hand edit) is skipped and
/// counted in [resyncs]: the next line is tried as the code.
class _Groups {
  _Groups(String content) : s = !content.contains('\n') && content.contains('\r') ? content.replaceAll('\r', '\n') : content;
  final String s;
  int _pos = 0;
  int resyncs = 0;
  int code = 0;
  String value = '';
  bool _held = false;

  double get fraction => s.isEmpty ? 1 : _pos / s.length;

  String? _line() {
    if (_pos >= s.length) return null;
    final nl = s.indexOf('\n', _pos);
    final end = nl < 0 ? s.length : nl;
    var e = end;
    if (e > _pos && s.codeUnitAt(e - 1) == 13) e--;
    final line = s.substring(_pos, e);
    _pos = nl < 0 ? s.length : nl + 1;
    return line;
  }

  /// Loads the next group; false at the end of the text.
  bool next() {
    if (_held) {
      _held = false;
      return true;
    }
    while (true) {
      final c = _line();
      if (c == null) return false;
      final t = c.trim();
      final k = int.tryParse(t);
      // group codes run from -5 to 1071
      if (k == null || k < -5 || k > 1071) {
        if (t.isNotEmpty) resyncs++;
        continue;
      }
      final v = _line();
      if (v == null) return false;
      code = k;
      value = v.trim();
      return true;
    }
  }

  /// The current group is read again by the next [next].
  void hold() => _held = true;
}

/// Entity types read without geometry for the plan (viewports, attribute
/// definitions of blocks, construction lines, lights, masks): left out
/// without a note.
const _silentTypes = {'VIEWPORT', 'SEQEND', 'VERTEX', 'ATTDEF', 'XLINE', 'RAY', 'LIGHT', 'SUN', 'WIPEOUT', 'ENDBLK', 'BLOCK'};

class _DxfParser {
  _DxfParser(String content) : g = _Groups(content);
  final _Groups g;
  final layers = <DxfLayer>[];
  final entities = <DxfEntity>[];
  final inserts = <DxfInsert>[];
  final blocks = <String, DxfBlock>{};

  /// Entity types left out, with their counts.
  final skipped = <String, int>{};

  /// Corners of the 3D faces already taken (millimetre grid), so a surface
  /// of triangles gives each survey point once.
  final _faceCorners = <(int, int)>{};
  var paper = 0;
  var insunits = 0;
  var section = '';
  var _done = false;

  double get fraction => g.fraction;

  static double _d(String v) => double.tryParse(v) ?? 0;

  /// Reads up to [budget] records; true when the file is done.
  bool step(int budget) {
    for (var n = 0; n < budget; n++) {
      if (_done || !g.next()) return _done = true;
      if (g.code != 0) {
        if (section == 'HEADER' && g.code == 9) _header(g.value);
        continue;
      }
      final v = g.value;
      switch (v) {
        case 'SECTION':
          section = '';
          if (g.next()) {
            if (g.code == 2) {
              section = g.value.toUpperCase();
            } else {
              g.hold();
            }
          }
        case 'ENDSEC':
          section = '';
        case 'EOF':
          return _done = true;
        default:
          if (section == 'TABLES') {
            if (v == 'LAYER') _layer();
          } else if (section == 'BLOCKS') {
            if (v == 'BLOCK') _block();
          } else if (section == 'ENTITIES') {
            _entity(v, entities, inserts, top: true);
          }
      }
    }
    return false;
  }

  void _header(String name) {
    if (!g.next()) return;
    if (g.code == 0 || g.code == 9) {
      g.hold();
      return;
    }
    if (name == r'$INSUNITS' && g.code == 70) insunits = int.tryParse(g.value) ?? 0;
  }

  /// The pairs of the current record up to the next code 0.
  void _skipRecord() {
    while (g.next()) {
      if (g.code == 0) {
        g.hold();
        return;
      }
    }
  }

  void _layer() {
    String? name;
    var color = 7, flags = 0;
    int? rgb;
    while (g.next()) {
      if (g.code == 0) {
        g.hold();
        break;
      }
      switch (g.code) {
        case 2:
          name = DxfReader.plainName(g.value);
        case 62:
          color = int.tryParse(g.value) ?? 7;
        case 70:
          flags = int.tryParse(g.value) ?? 0;
        case 420:
          rgb = int.tryParse(g.value);
      }
    }
    if (name == null || name.isEmpty) return;
    // a negative colour turns the layer off; flag 1 freezes it
    final c = color.abs();
    layers.add(DxfLayer(name, color: c >= 1 && c <= 255 ? c : 7, visible: color >= 0 && flags & 1 == 0, rgb: rgb == null ? null : rgb & 0xFFFFFF));
  }

  void _block() {
    var name = '';
    var bx = 0.0, by = 0.0;
    var flags = 0;
    while (g.next()) {
      if (g.code == 0) {
        g.hold();
        break;
      }
      switch (g.code) {
        case 2:
          name = DxfReader.plainName(g.value);
        case 10:
          bx = _d(g.value);
        case 20:
          by = _d(g.value);
        case 70:
          flags = int.tryParse(g.value) ?? 0;
      }
    }
    final ents = <DxfEntity>[];
    final ins = <DxfInsert>[];
    while (g.next()) {
      if (g.code != 0) continue;
      final t = g.value;
      if (t == 'ENDBLK') {
        _skipRecord();
        break;
      }
      if (t == 'ENDSEC' || t == 'EOF') {
        g.hold();
        break;
      }
      _entity(t, ents, ins, top: false);
    }
    // the layouts other than the active one: paper space, not the plan
    if (name.toLowerCase().startsWith('*paper_space')) {
      paper += ents.length + ins.length;
      return;
    }
    if (name.isNotEmpty) blocks[name] = DxfBlock(name, Pt(bx, by), ents, ins, xref: flags & 4 != 0);
  }

  /// Reads the entity of [type] whose code 0 was just read into [out], or
  /// into [ins] for block references. [top]: an entity of the ENTITIES
  /// section (where code 67 = 1 marks paper space).
  void _entity(String type, List<DxfEntity> out, List<DxfInsert> ins, {required bool top}) {
    final props = <int, List<String>>{};
    final ordered = type == 'HATCH' || type == 'MULTILEADER' || type == 'MLEADER' ? <(int, String)>[] : null;
    final verts = <_Vertex>[]; // LWPOLYLINE vertices in file order (10, 20, 42)
    final lw = type == 'LWPOLYLINE';
    // the extended data (1001 and the groups after it), in order
    List<(int, String)>? xg;
    while (g.next()) {
      final c = g.code;
      if (c == 0) {
        g.hold();
        break;
      }
      final v = g.value;
      if (c == 1001) xg ??= [];
      // a caret is written "^ " (the caret notation of control characters)
      if (c >= 1000 && xg != null) xg.add((c, c == 1000 ? v.replaceAll('^ ', '^') : v));
      if (lw && (c == 10 || c == 20 || c == 42)) {
        if (c == 10) {
          verts.add(_Vertex(_d(v), 0));
        } else if (verts.isNotEmpty) {
          if (c == 20) {
            verts.last.y = _d(v);
          } else {
            verts.last.bulge = _d(v);
          }
        }
        continue;
      }
      ordered?.add((c, v));
      (props[c] ??= []).add(v);
    }
    // a POLYLINE is followed by its VERTEX records up to SEQEND
    final pv = type == 'POLYLINE' ? _polylineVertices() : null;
    // the attributes of a block reference follow it up to SEQEND: their
    // values (invisible ones too) go with the reference
    final owner = _attribOwner;
    if (type == 'ATTRIB' && owner != null) {
      final tag = DxfReader.plainName(props[2]?.first ?? '').trim().toUpperCase();
      if (tag.isNotEmpty) owner.attributes[tag] = DxfReader.plainText([...?props[3], ...?props[1]].join()).trim();
    } else if (type != 'ATTRIB') {
      _attribOwner = null;
    }
    if (top && (props[67]?.first.trim() ?? '') == '1') {
      if (!_silentTypes.contains(type)) paper++;
      return;
    }
    final n = out.length, ni = ins.length;
    _build(type, props, ordered, verts, pv, out, ins);
    // the hydraulic data of an item the app exported goes with the entity
    final x = xg == null ? null : readHydraulicXdata(xg);
    if (x != null) {
      if (type == 'INSERT' && ins.length > ni) {
        ins.last.xdata = x;
      } else if (out.length == n + 1 && (type == 'LWPOLYLINE' || type == 'POLYLINE' || type == 'LINE' || type == 'TEXT' || type == 'MTEXT')) {
        out[n] = out[n].withXdata(x);
      }
    }
    if (type == 'INSERT' && (props[66]?.first.trim() ?? '') == '1' && ins.isNotEmpty) _attribOwner = ins.last;
  }

  /// The block reference whose attributes are being read.
  DxfInsert? _attribOwner;

  /// The vertices after a POLYLINE: positions (spline frame points and mesh
  /// face records left out), bulges and elevations.
  _PolyVertices _polylineVertices() {
    final out = _PolyVertices();
    while (g.next()) {
      if (g.code != 0) continue;
      if (g.value == 'VERTEX') {
        double? x, y, z;
        var bulge = 0.0, vflags = 0;
        while (g.next()) {
          if (g.code == 0) {
            g.hold();
            break;
          }
          switch (g.code) {
            case 10:
              x = double.tryParse(g.value);
            case 20:
              y = double.tryParse(g.value);
            case 30:
              z = double.tryParse(g.value);
            case 42:
              bulge = double.tryParse(g.value) ?? 0;
            case 70:
              vflags = int.tryParse(g.value) ?? 0;
          }
        }
        // spline frame control points (16) are not on the curve; face
        // records of a polyface mesh (128 without 64) hold no position
        if (vflags & 16 != 0 || (vflags & 128 != 0 && vflags & 64 == 0)) continue;
        if (x != null && y != null) {
          out.points.add(_Vertex(x, y, bulge));
          out.z.add(z);
        }
        continue;
      }
      if (g.value == 'SEQEND') {
        _skipRecord();
      } else {
        g.hold();
      }
      break;
    }
    return out;
  }

  void _build(String type, Map<int, List<String>> props, List<(int, String)>? ordered, List<_Vertex> verts, _PolyVertices? pv, List<DxfEntity> out, List<DxfInsert> inserts) {
    double num(int c, [int idx = 0, double def = 0]) => double.tryParse(props[c]?.elementAtOrNull(idx) ?? '') ?? def;
    int flags(int c) => int.tryParse(props[c]?.first ?? '0') ?? 0;
    final layer = DxfReader.plainName(props[8]?.first ?? '0');
    final color = int.tryParse(props[62]?.first ?? '') ?? 256;
    // extrusion (0, 0, −1): the object coordinates of the planar entities
    // (not the world coordinates of lines, points, splines, MTEXT, 3D
    // polylines) are mirrored
    final mirrored = ocsIsMirrored(num(210), num(220), num(230, 0, 1));
    final first = out.length;
    switch (type) {
      case 'LINE':
        out.add(DxfEntity(type: 'LINE', layer: layer, color: color, points: [Pt(num(10), num(20)), Pt(num(11), num(21))], elevation: props.containsKey(30) ? num(30) : null));
      case 'LWPOLYLINE':
        final closed = flags(70) & 1 == 1;
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: DxfReader._withBulges(verts, closed), closed: closed, elevation: props.containsKey(38) ? num(38) : null));
      case 'POLYLINE':
        final f = flags(70);
        final closed = f & 1 == 1;
        final v = pv ?? _PolyVertices();
        if (f & (16 | 64) != 0) {
          // polyface and polygon meshes: a surface (a survey's terrain), its vertices as spot heights
          for (var k = 0; k < v.points.length; k++) {
            _corner(Pt(v.points[k].x, v.points[k].y), v.z[k] ?? 0, layer, color, out);
          }
          break;
        }
        double? zElev;
        var sameZ = true;
        for (final z in v.z) {
          if (z == null) continue;
          if (zElev == null) {
            zElev = z;
          } else if ((zElev - z).abs() > 1e-9) {
            sameZ = false;
          }
        }
        // a 2D polyline carries its elevation in code 30; a 3D one in its vertices
        final own = props.containsKey(30) ? num(30) : null;
        final polyElev = own != null && own != 0 ? own : (sameZ && zElev != null && zElev != 0 ? zElev : own);
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: DxfReader._withBulges(v.points, closed), closed: closed, elevation: polyElev));
      case 'CIRCLE':
        out.add(DxfEntity(type: 'CIRCLE', layer: layer, color: color, center: Pt(num(10), num(20)), radius: num(40)));
      case 'ARC':
        out.add(DxfEntity(type: 'ARC', layer: layer, color: color, center: Pt(num(10), num(20)), radius: num(40), startAngle: cadNormalizeDeg(num(50)), endAngle: cadNormalizeDeg(num(51))));
      case 'ELLIPSE':
        // centre and major axis in world coordinates; the minor axis is
        // extrusion × major, the other side for an extrusion (0, 0, −1)
        final c = Pt(num(10), num(20)), major = Pt(num(11), num(21));
        final minor = major.perpendicular * num(40, 0, 1) * (mirrored ? -1 : 1);
        final a0 = num(41), a1 = num(42, 0, 2 * math.pi);
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: DxfReader.ellipsePoints(c, major, minor, a0, a1), closed: cadSweepRad(a0, a1) >= 2 * math.pi - 1e-9));
      case 'SPLINE':
        // fit points: a smooth curve through them; else the NURBS curve of
        // the control points (degree, knots and weights)
        List<double> nums(int c) => [for (final v in props[c] ?? const <String>[]) double.tryParse(v) ?? 0];
        final xs = nums(11), ys = nums(21);
        final cx = nums(10), cy = nums(20);
        final closed = flags(70) & 1 == 1;
        if (xs.length >= 2 && ys.length == xs.length) {
          out.add(DxfEntity(type: 'SPLINE', layer: layer, color: color, points: [for (var k = 0; k < xs.length; k++) Pt(xs[k], ys[k])], closed: closed));
        } else {
          final ctrl = [for (var k = 0; k < math.min(cx.length, cy.length); k++) Pt(cx[k], cy[k])];
          final pts = DxfReader.splineCurve(flags(71) > 0 ? flags(71) : 3, ctrl, knots: nums(40), weights: nums(41));
          if (pts.length >= 2) out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: closed));
        }
      case 'HATCH':
        DxfReader._readHatch(ordered ?? const [], layer, color, out);
      case 'SOLID' || 'TRACE':
        // corners in 1-2-4-3 order ("bow-tie" numbering of the format)
        final q = [Pt(num(10), num(20)), Pt(num(11), num(21)), Pt(num(13, 0, num(12)), num(23, 0, num(22))), Pt(num(12), num(22))];
        final pts = <Pt>[];
        for (final p in q) {
          if (pts.isEmpty || pts.last.distanceTo(p) > 1e-12) pts.add(p);
        }
        if (pts.length > 2 && pts.first.distanceTo(pts.last) < 1e-12) pts.removeLast();
        if (pts.length >= 3) out.add(DxfEntity(type: 'HATCH', layer: layer, color: color, points: pts, closed: true, solid: true));
      case '3DFACE':
        // a surface triangle (or quad) of a survey: its corners are spot
        // heights; a flat face is drawn by its outline
        final q = [for (var k = 0; k < 4; k++) (Pt(num(10 + k), num(20 + k)), num(30 + k))];
        if (q.any((c) => c.$2 != 0)) {
          for (final (p, z) in q) {
            _corner(p, z, layer, color, out);
          }
        } else {
          final pts = <Pt>[];
          for (final (p, _) in q) {
            if (pts.isEmpty || pts.last.distanceTo(p) > 1e-12) pts.add(p);
          }
          if (pts.length > 2 && pts.first.distanceTo(pts.last) < 1e-12) pts.removeLast();
          if (pts.length >= 3) out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: true));
        }
      case 'TEXT' || 'MTEXT' || 'ATTRIB':
        // invisible attributes are data, not drawing
        if (type == 'ATTRIB' && flags(70) & 1 == 1) break;
        // long MTEXT comes in code-3 chunks followed by the final code 1
        final raw = [...?props[3], ...?props[1]].join();
        final txt = type == 'MTEXT' ? DxfReader.plainMText(raw) : DxfReader.plainText(raw);
        // a text needs a size to be drawn (0 means "the style's" to CAD programs)
        final h40 = num(40, 0, 1);
        final height = h40 > 0 && h40.isFinite ? h40 : 1.0;
        if (type == 'MTEXT') {
          // MTEXT may give its direction as a vector instead of an angle
          final rotation = !props.containsKey(50) && props.containsKey(11) ? radToDeg(math.atan2(num(21), num(11))) : num(50);
          // the attachment point (1 top left … 9 bottom right) is the insertion point
          final a = flags(71).clamp(1, 9);
          final col = (a - 1) % 3, row = (a - 1) ~/ 3;
          final pos = cadTextBase(Pt(num(10), num(20)), txt, height, rotation, col / 2, (2 - row) / 2);
          out.add(DxfEntity(type: 'TEXT', layer: layer, color: color, points: [pos], text: txt, height: height, rotation: rotation));
        } else {
          // justified TEXT/ATTRIB: placed from its alignment point (fitted and
          // aligned texts run from the first point)
          final h = flags(72), v = type == 'ATTRIB' ? flags(74) : flags(73);
          final rotation = num(50);
          var pos = Pt(num(10), num(20));
          if ((h != 0 || v != 0) && h != 3 && h != 5 && props.containsKey(11)) {
            final hf = h == 1 || h == 4 ? 0.5 : (h == 2 ? 1.0 : 0.0);
            final vf = h == 4 ? 0.5 : (v == 2 ? 0.5 : (v == 3 ? 1.0 : 0.0));
            pos = cadTextBase(Pt(num(11), num(21)), txt, height, rotation, hf, vf);
          }
          out.add(DxfEntity(type: 'TEXT', layer: layer, color: color, points: [pos], text: txt, height: height, rotation: rotation));
        }
      case 'LEADER':
        // the leader line (its arrowhead and note are drawn by the program)
        final xs = props[10] ?? const <String>[], ys = props[20] ?? const <String>[];
        final pts = [for (var k = 0; k < math.min(xs.length, ys.length); k++) Pt(double.tryParse(xs[k]) ?? 0, double.tryParse(ys[k]) ?? 0)];
        if (pts.length >= 2) out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts));
      case 'MULTILEADER' || 'MLEADER':
        DxfReader._readMLeader(ordered ?? const [], layer, color, out);
      case 'MLINE':
        // the reference line through its vertices
        final xs = props[11] ?? const <String>[], ys = props[21] ?? const <String>[];
        final pts = [for (var k = 0; k < math.min(xs.length, ys.length); k++) Pt(double.tryParse(xs[k]) ?? 0, double.tryParse(ys[k]) ?? 0)];
        if (pts.length >= 2) out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: flags(71) & 2 != 0));
      case 'POINT':
        out.add(DxfEntity(type: 'POINT', layer: layer, color: color, points: [Pt(num(10), num(20))], elevation: props.containsKey(30) ? num(30) : null));
      case 'INSERT':
        inserts.add(
          DxfInsert(
            name: DxfReader.plainName(props[2]?.first ?? ''),
            layer: layer,
            color: color,
            position: Pt(num(10), num(20)),
            scaleX: num(41, 0, 1),
            scaleY: num(42, 0, 1),
            rotation: num(50),
            cols: flags(70).clamp(1, 32767),
            rows: flags(71).clamp(1, 32767),
            colSpacing: num(44),
            rowSpacing: num(45),
            ocsMirror: mirrored,
          )..z = props.containsKey(30) ? num(30) : null,
        );
      case 'DIMENSION' || 'ARC_DIMENSION' || 'LARGE_RADIAL_DIMENSION':
        // the dimension's geometry lives in an anonymous block, inserted at
        // the origin of the dimension's object coordinates
        final block = DxfReader.plainName(props[2]?.first ?? '');
        if (block.isNotEmpty) inserts.add(DxfInsert(name: block, layer: layer, color: color, position: Pt.zero, ocsMirror: mirrored));
      case 'ACAD_TABLE':
        // a table is a reference to its anonymous block at the insertion point
        final block = DxfReader.plainName(props[2]?.first ?? '');
        if (block.isEmpty) {
          skipped[type] = (skipped[type] ?? 0) + 1;
          break;
        }
        final dir = props.containsKey(11) ? radToDeg(math.atan2(num(21), num(11, 0, 1))) : 0.0;
        inserts.add(DxfInsert(name: block, layer: layer, color: color, position: Pt(num(10), num(20)), rotation: dir));
      default:
        if (!_silentTypes.contains(type)) skipped[type] = (skipped[type] ?? 0) + 1;
    }
    final planar = switch (type) {
      'CIRCLE' || 'ARC' || 'LWPOLYLINE' || 'HATCH' || 'SOLID' || 'TRACE' || 'TEXT' || 'ATTRIB' => true,
      // 2D polylines (not 3D polylines or meshes, flags 8/16/64)
      'POLYLINE' => flags(70) & (8 | 16 | 64) == 0,
      _ => false,
    };
    if (mirrored && planar) {
      for (var k = first; k < out.length; k++) {
        out[k] = DxfReader.mirrorOcs(out[k]);
      }
    }
  }

  /// A corner of a surface (3D face, mesh) as a spot height, once per place
  /// in the drawing (top level) or every time (blocks).
  void _corner(Pt p, double z, String layer, int color, List<DxfEntity> out) {
    if (!p.x.isFinite || !p.y.isFinite || !z.isFinite) return;
    if (identical(out, entities) && !_faceCorners.add(((p.x * 1000).round(), (p.y * 1000).round()))) return;
    out.add(DxfEntity(type: 'POINT', layer: layer, color: color, points: [p], elevation: z));
  }

  DxfDocument finish() {
    final w = <String>[];
    if (g.resyncs > 0) w.add('dxf_resync:${g.resyncs}');
    if (paper > 0) w.add('dxf_paper_space:$paper');
    // the hydraulic items the app exported (outlets, valves…): restored by
    // the import from their data, their blocks only drawn when they cannot be
    final items = DxfReader.hydraulicItems(inserts, blocks);
    for (final it in items) {
      entities.addAll(it.fallback);
    }
    // survey points delivered as blocks with an elevation attribute
    final survey = DxfReader.surveyPoints(inserts, blocks);
    entities.addAll(survey);
    if (survey.isNotEmpty) w.add('dxf_survey_points:${survey.length}');
    DxfReader.expandInserts(inserts, blocks, entities, warnings: w);
    DxfReader.flatPointElevations(entities);
    if (skipped.isNotEmpty) w.add('dxf_unsupported:${DxfReader.typeList(skipped)}');
    return DxfDocument(entities: entities, layers: layers, unitScale: DxfReader._unitScale(insunits), warnings: w, items: items);
  }
}

class _PolyVertices {
  final points = <_Vertex>[];
  final z = <double?>[];
}

/// Limits of the expansion of block references, against files (damaged or
/// hostile) whose blocks insert themselves or each other exponentially.
class _Expansion {
  _Expansion(this.blocks, this.out) {
    for (final b in blocks.values) {
      _lower.putIfAbsent(b.name.toLowerCase(), () => b);
    }
    for (final e in out) {
      points += math.max(1, e.points.length);
    }
  }
  final Map<String, DxfBlock> blocks;
  final List<DxfEntity> out;
  final _lower = <String, DxfBlock>{};
  final xrefs = <String>{};
  final cycles = <String>{};
  final stack = <String>[];
  var points = 0;
  var truncated = false;

  bool get full => out.length >= DxfReader.maxEntities || points >= DxfReader.maxPoints;

  DxfBlock? find(String name) => blocks[name] ?? _lower[name.toLowerCase()];

  void run(List<DxfInsert> inserts, Affine2? outer, String? layer, int? color) {
    if (stack.length >= DxfReader.maxNesting) {
      truncated = true;
      return;
    }
    for (final ins in inserts) {
      if (full) {
        truncated = true;
        return;
      }
      final block = find(ins.name);
      if (block == null) continue;
      if (block.xref) {
        xrefs.add(block.name);
        continue;
      }
      // a block inside itself would never end
      if (stack.contains(block.name)) {
        cycles.add(block.name);
        continue;
      }
      final insLayer = ins.layer == '0' && layer != null ? layer : ins.layer;
      final insColor = ins.color == 0 && color != null ? color : ins.color;
      var rows = ins.rows, cols = ins.cols;
      if (rows * cols > DxfReader.maxCells) {
        truncated = true;
        cols = math.min(cols, DxfReader.maxCells);
        rows = math.max(1, DxfReader.maxCells ~/ cols);
      }
      stack.add(block.name);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final local = ins.affine(block.base, c, r);
          final t = outer == null ? local : outer.then(local);
          for (final e in block.entities) {
            // definition points of dimensions are not drawing geometry, and
            // the point of a survey block is its marker (the point itself
            // comes with the elevation of its attribute)
            if (e.type == 'POINT' && (block.name.startsWith('*D') || ins.survey)) continue;
            if (full) {
              truncated = true;
              stack.removeLast();
              return;
            }
            DxfReader._transformed(e, t, insLayer, insColor, out);
            points += math.max(1, e.points.length);
          }
          run(block.inserts, t, insLayer, insColor);
        }
      }
      stack.removeLast();
    }
  }
}

class DxfReader {
  /// Most entities a drawing may hold once its blocks are expanded.
  static const maxEntities = 1000000;

  /// Most points (vertices) the expanded blocks may add.
  static const maxPoints = 8000000;

  /// Most cells of one MINSERT array.
  static const maxCells = 250000;

  /// Deepest nesting of blocks expanded.
  static const maxNesting = 16;

  static double _unitScale(int insunits) => switch (insunits) {
    1 => 0.0254, // inches
    2 => 0.3048, // feet
    4 => 0.001, // mm
    5 => 0.01, // cm
    6 => 1.0, // m
    7 => 1000.0, // km
    8 => 2.54e-8, // microinches
    9 => 2.54e-5, // mils
    10 => 0.9144, // yards
    13 => 1e-6, // microns
    14 => 0.1, // decimetres
    15 => 10.0, // decametres
    16 => 100.0, // hectometres
    21 => 1200 / 3937, // US survey feet
    _ => 1.0,
  };

  /// Metres per drawing unit of an `$INSUNITS` code (1 when unitless or
  /// unknown).
  static double unitScaleOf(int insunits) => _unitScale(insunits);

  /// Text of a DXF file: R2007 and later files are UTF-8; older ones are in
  /// the code page of their `$DWGCODEPAGE` (1252 when none), unless their
  /// bytes are valid UTF-8 (writers that ignore the code page). A byte order
  /// mark (UTF-8, UTF-16) wins. [warnings] gets
  /// `dxf_codepage_unsupported:<page>` for an East Asian page, read as 1252.
  static String decode(Uint8List bytes, [List<String>? warnings]) {
    if (byteOrderMark(bytes) != null || utf16WithoutBom(bytes) != null) return decodeTextBytes(bytes);
    final head = latin1.decode(Uint8List.sublistView(bytes, 0, math.min(bytes.length, 65536)));
    final ver = RegExp(r'\$ACADVER\s*\r?\n\s*1\s*\r?\n\s*(AC\d{4})').firstMatch(head)?.group(1);
    final page = RegExp(r'\$DWGCODEPAGE\s*\r?\n\s*3\s*\r?\n\s*([^\r\n]+)').firstMatch(head)?.group(1)?.trim();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // R2007 and later are UTF-8 by definition: a damaged byte is only that
      if (ver != null && ver.compareTo('AC1021') >= 0) return utf8.decode(bytes, allowMalformed: true);
    }
    var cp = page == null ? 1252 : (codepageFromName(page) ?? 1252);
    if (!supportedCodepages.contains(cp)) {
      warnings?.add('dxf_codepage_unsupported:$page');
      cp = 1252;
    }
    return decodeCodepage(bytes, cp);
  }

  /// [parse] of the bytes of a file (see [decode]).
  static DxfDocument parseBytes(Uint8List bytes) {
    final w = <String>[];
    final doc = parse(decode(bytes, w));
    doc.warnings.insertAll(0, w);
    return doc;
  }

  /// [parseBytes] in slices of [slicer] (the interface stays responsive and
  /// the user can cancel).
  static Future<DxfDocument> parseBytesAsync(Uint8List bytes, WorkSlicer slicer) async {
    final w = <String>[];
    final text = decode(bytes, w);
    await slicer.pause(0.05);
    final p = _DxfParser(text);
    while (!p.step(512)) {
      if (slicer.due) await slicer.pause(0.05 + 0.9 * p.fraction);
    }
    await slicer.pause(0.95);
    final doc = p.finish();
    doc.warnings.insertAll(0, w);
    return doc;
  }

  static DxfDocument parse(String content) {
    final p = _DxfParser(content);
    while (!p.step(1 << 30)) {}
    return p.finish();
  }

  /// Counts of entity types as a note (`3DSOLID ×2, IMAGE`).
  static String typeList(Map<String, int> counts) => counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', ');

  /// The block references of [inserts] that carry the app's hydraulic data,
  /// taken out of the list: each one with its data, its insertion point and
  /// its block drawn there (which the caller adds to the drawing: it stays
  /// when the item cannot be restored).
  static List<DxfItem> hydraulicItems(List<DxfInsert> inserts, Map<String, DxfBlock> blocks) {
    final items = <DxfItem>[];
    inserts.removeWhere((ins) {
      final x = ins.xdata;
      if (x == null || ins.rows * ins.cols != 1) return false;
      final geo = <DxfEntity>[];
      expandInserts([ins], blocks, geo);
      final base = blocks[ins.name]?.base ?? Pt.zero;
      items.add(DxfItem(x, ins.affine(base).apply(base), ins.layer, geo));
      return true;
    });
    return items;
  }

  /// An attribute tag reduced to its name: upper case, without accents,
  /// units in parentheses or punctuation (`COTA (m)` → `COTA`, `Elevação` →
  /// `ELEVACAO`, `PT_NUM` → `PT NUM`).
  static String attributeKey(String tag) {
    var s = tag.toUpperCase().replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    const from = 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
    const to = 'AAAAAACEEEEIIIINOOOOOUUUUY';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    s = b.toString().replaceAll(RegExp(r'[._:/\\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Attribute tags of the elevation of a survey point.
  static const surveyElevationTags = {
    'COTA',
    'COTAS',
    'ELEV',
    'ELEVACAO',
    'ELEVATION',
    'ELEVACION',
    'Z',
    'ALT',
    'ALTITUDE',
    'ALTURA',
    'H',
    'HEIGHT',
    'NIVEL',
    'LEVEL',
    'COTA TERRENO',
    'COTA PONTO',
    'COTA PT',
    'ELEV PT',
    'PT ELEV',
    'Z PT',
  };

  /// Attribute tags of the number or name of a survey point.
  static const surveyNameTags = {'PONTO', 'PT', 'PTO', 'POINT', 'PUNTO', 'NUM', 'NUMERO', 'NUMBER', 'ID', 'NOME', 'NAME', 'NOMBRE', 'PT NUM', 'NUM PT', 'ESTACA', 'MARCO'};

  /// Attribute tags of the description (code) of a survey point.
  static const surveyDescriptionTags = {'DESC', 'DESCRICAO', 'DESCRIPTION', 'DESCRIPCION', 'COD', 'CODIGO', 'CODE', 'OBS', 'OBSERVACAO', 'TIPO', 'TYPE'};

  /// Block names of survey points (`PONTO`, `PT_COTADO`, `SPOT`, `MARCO`…).
  static final _surveyBlockName = RegExp(r'^(PONTO|PTO?|POINT|PUNTO|COTA|SPOT|ELEV|LEVEL|MARCO|ESTACA|SURVEY|TOPO|LEV)([^A-Z]|$)');

  /// The first number in [s] (`612,35 m` → 612.35), or null.
  static double? _attributeNumber(String s) {
    final m = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(s.replaceAll(' ', ''));
    if (m == null) return null;
    return double.tryParse(m.group(0)!.replaceAll(',', '.'));
  }

  /// Survey points delivered as block references, the most common form of a
  /// topographic survey in DXF and DWG: a reference whose attributes give an
  /// elevation (COTA, ELEV, Z…) becomes a point with that elevation, or with
  /// the Z of its insertion point when the reference names a point (its
  /// attributes number or describe it, or the block is called PONTO, PT,
  /// SPOT…); the point is named by the number and description attributes.
  /// Top-level references only (not the references inside blocks); each one
  /// taken is marked [DxfInsert.survey].
  static List<DxfEntity> surveyPoints(List<DxfInsert> inserts, Map<String, DxfBlock> blocks) {
    final out = <DxfEntity>[];
    for (final ins in inserts) {
      if (ins.rows * ins.cols != 1) continue;
      final attrs = {for (final e in ins.attributes.entries) attributeKey(e.key): e.value};
      double? elev;
      for (final k in attrs.keys) {
        if (surveyElevationTags.contains(k)) {
          elev = _attributeNumber(attrs[k]!);
          if (elev != null) break;
        }
      }
      String? first(Set<String> tags) {
        for (final e in attrs.entries) {
          if (tags.contains(e.key) && e.value.trim().isNotEmpty) return e.value.trim();
        }
        return null;
      }

      final id = first(surveyNameTags), desc = first(surveyDescriptionTags);
      final pointLike = id != null || desc != null || _surveyBlockName.hasMatch(attributeKey(ins.name));
      if (elev == null && pointLike && ins.z != null && ins.z != 0 && ins.z!.isFinite) elev = ins.z;
      if (elev == null || !elev.isFinite) continue;
      final block = blocks[ins.name];
      final at = ins.affine(block?.base ?? Pt.zero).apply(block?.base ?? Pt.zero);
      if (!at.x.isFinite || !at.y.isFinite) continue;
      ins.survey = true;
      out.add(DxfEntity(type: 'POINT', layer: ins.layer, color: ins.color, points: [at], elevation: elev, name: [?id, ?desc].join(' ')));
    }
    return out;
  }

  /// Points of a 2D drawing are flat: a POINT at Z = 0 has no elevation
  /// (it would pull the terrain to sea level) unless other points of its
  /// layer have elevations, which makes zero a real one.
  static void flatPointElevations(List<DxfEntity> entities) {
    final measured = <String>{};
    for (final e in entities) {
      if (e.type == 'POINT' && e.elevation != null && e.elevation != 0) measured.add(e.layer);
    }
    for (var i = 0; i < entities.length; i++) {
      final e = entities[i];
      if (e.type == 'POINT' && e.elevation == 0 && !measured.contains(e.layer)) entities[i] = e.withElevation(null);
    }
  }

  /// Layer and block names: `\U+XXXX` characters decoded.
  static String plainName(String s) {
    if (!s.contains(r'\U+') && !s.contains(r'\u+')) return s;
    return s.replaceAllMapped(RegExp(r'\\[Uu]\+([0-9A-Fa-f]{4})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
  }

  /// TEXT and ATTRIB content as plain text: `\U+XXXX` characters (files in a
  /// code page), the `%%c` `%%d` `%%p` symbols, `%%%`, the underline and
  /// overline toggles and the caret notation of control characters.
  static String plainText(String s) {
    if (!s.contains('\\U+') && !s.contains('%%') && !s.contains('^')) return s;
    var t = s.replaceAllMapped(RegExp(r'\\U\+([0-9A-Fa-f]{4})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
    t = t.replaceAllMapped(
      RegExp(r'%%([cCdDpPuUoO%])'),
      (m) => switch (m[1]!.toLowerCase()) {
        'c' => 'Ø',
        'd' => '°',
        'p' => '±',
        '%' => '%',
        _ => '',
      },
    );
    return t.replaceAll('^ ', '^').replaceAll(RegExp(r'\^[@-_]'), ' ');
  }

  /// MTEXT content as plain text: escaped characters (`\\` `\{` `\}`),
  /// paragraph breaks (`\P`) as line breaks, non-breaking spaces as spaces,
  /// stacked fractions as `a/b`, formatting codes and grouping braces
  /// dropped; then as [plainText].
  static String plainMText(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '{' || ch == '}') continue;
      if (ch != '\\' || i + 1 >= s.length) {
        out.write(ch);
        continue;
      }
      final code = s[i + 1];
      switch (code) {
        case '\\' || '{' || '}':
          out.write(code);
          i++;
        case 'P':
          out.write('\n');
          i++;
        case '~':
          out.write(' ');
          i++;
        case 'U' || 'M':
          // \U+XXXX is decoded below; \M+cXXXX (multibyte) is left as it is
          out.write('\\');
        case 'S':
          // stacked text up to ';': numerator, separator (/ # ^) and denominator
          final end = s.indexOf(';', i + 2);
          if (end < 0) {
            i++;
            continue;
          }
          out.write(s.substring(i + 2, end).replaceAll('#', '/').replaceAll('^', '/'));
          i = end;
        case 'A' || 'C' || 'c' || 'F' || 'f' || 'H' || 'h' || 'Q' || 'q' || 'T' || 't' || 'W' || 'w' || 'p':
          // formatting with an argument up to ';'
          final end = s.indexOf(';', i + 2);
          i = end < 0 ? i + 1 : end;
        case 'L' || 'l' || 'O' || 'o' || 'K' || 'k' || 'N' || 'X':
          i++;
        default:
          out.write(code);
          i++;
      }
    }
    // spaces around the paragraphs, not inside them
    return plainText(out.toString()).split('\n').map((l) => l.trim()).join('\n').trim();
  }

  /// [e] read in the mirrored object coordinates of an extrusion
  /// (0, 0, −1), in world coordinates.
  static DxfEntity mirrorOcs(DxfEntity e) {
    final out = <DxfEntity>[];
    _transformed(e, Affine2.ocsMirror, e.layer, e.color, out);
    return out.single;
  }

  /// Points of the elliptical arc of centre [c], axes [major] and [minor]
  /// from parameter [a0] to [a1] (radians; at most one turn, one point
  /// every 10°).
  static List<Pt> ellipsePoints(Pt c, Pt major, Pt minor, double a0, double a1) {
    final sweep = cadSweepRad(a0, a1);
    final start = a0.isFinite ? a0 : 0.0;
    final full = sweep >= 2 * math.pi - 1e-9;
    final n = math.max(8, (sweep / (math.pi / 18)).ceil());
    return [for (var k = 0; k <= (full ? n - 1 : n); k++) c + major * math.cos(start + sweep * k / n) + minor * math.sin(start + sweep * k / n)];
  }

  /// The NURBS curve of a spline with a sane degree (1–11) and number of
  /// samples (damaged files give degrees of millions).
  static List<Pt> splineCurve(int degree, List<Pt> control, {List<double> knots = const [], List<double> weights = const []}) {
    if (control.length > 100000) return const [];
    final p = degree.clamp(1, 11);
    final samples = (control.length * 8).clamp(16, 20000);
    return nurbsCurve(p, control, knots: knots.length == control.length + p + 1 ? knots : const [], weights: weights, samples: samples);
  }

  /// Reads the HATCH whose group codes are [pairs]: the boundary paths
  /// become one hatch (the largest loop) plus closed polylines for the
  /// other loops (islands); the first pattern line gives the angle and
  /// spacing of the hatch lines.
  static void _readHatch(List<(int, String)> pairs, String layer, int color, List<DxfEntity> out) {
    final end = pairs.length;
    var k = 0;
    bool at(int code) => k < end && pairs[k].$1 == code;
    double rd(int code, [double def = 0]) {
      if (!at(code)) return def;
      return double.tryParse(pairs[k++].$2) ?? def;
    }

    int ri(int code) {
      final v = rd(code);
      return v.isFinite ? v.round().clamp(-1 << 30, 1 << 30) : 0;
    }

    var solid = false;
    var paths = 0;
    while (k < end) {
      final (c, v) = pairs[k];
      k++;
      if (c == 70) solid = (int.tryParse(v) ?? 0) & 1 == 1;
      if (c == 91) {
        paths = int.tryParse(v) ?? 0;
        break;
      }
    }
    final loops = <List<Pt>>[];
    for (var p = 0; p < paths && k < end; p++) {
      while (k < end && !at(92)) {
        k++;
      }
      if (k >= end) break;
      final flags = ri(92);
      final loop = <Pt>[];
      if (flags & 2 != 0) {
        final bulges = rd(72) != 0;
        rd(73);
        final n = ri(93);
        final verts = <_Vertex>[];
        for (var v = 0; v < n && k < end; v++) {
          final x = rd(10), y = rd(20);
          verts.add(_Vertex(x, y, bulges ? rd(42) : 0));
        }
        loop.addAll(_withBulges(verts, true));
      } else {
        final edges = ri(93);
        for (var e = 0; e < edges && k < end; e++) {
          final type = ri(72);
          switch (type) {
            case 1:
              final a = Pt(rd(10), rd(20)), b = Pt(rd(11), rd(21));
              if (loop.isEmpty || loop.last.distanceTo(a) > 1e-9) loop.add(a);
              loop.add(b);
            case 2:
              final c = Pt(rd(10), rd(20));
              final r = rd(40), s = rd(50), en = rd(51);
              final ccw = rd(73, 1) != 0;
              // clockwise arcs are stored with mirrored angles
              final a0 = degToRad(cadNormalizeDeg(ccw ? s : -s)), a1 = degToRad(cadNormalizeDeg(ccw ? en : -en));
              final sweep = ccw ? cadSweepRad(a0, a1) : cadSweepRad(a1, a0);
              final segs = math.max(4, (sweep / (math.pi / 18)).ceil());
              for (var q = 0; q <= segs; q++) {
                loop.add(c + Pt.polar(r, ccw ? a0 + sweep * q / segs : a0 - sweep * q / segs));
              }
            case 3:
              final c = Pt(rd(10), rd(20)), major = Pt(rd(11), rd(21));
              final ratio = rd(40, 1), s = rd(50), en = rd(51);
              final ccw = rd(73, 1) != 0;
              final minor = major.perpendicular * ratio;
              final a0 = degToRad(cadNormalizeDeg(ccw ? s : -s)), a1 = degToRad(cadNormalizeDeg(ccw ? en : -en));
              final sweep = ccw ? cadSweepRad(a0, a1) : cadSweepRad(a1, a0);
              final segs = math.max(8, (sweep / (math.pi / 18)).ceil());
              for (var q = 0; q <= segs; q++) {
                final t = ccw ? a0 + sweep * q / segs : a0 - sweep * q / segs;
                loop.add(c + major * math.cos(t) + minor * math.sin(t));
              }
            case 4:
              final degree = ri(94);
              final rational = rd(73) != 0;
              rd(74);
              final nk = ri(95), nc = ri(96);
              if (nk > 100000 || nc > 100000) return;
              final knots = [for (var q = 0; q < nk; q++) rd(40)];
              final ctrl = <Pt>[];
              final weights = <double>[];
              for (var q = 0; q < nc; q++) {
                ctrl.add(Pt(rd(10), rd(20)));
                if (rational) weights.add(rd(42, 1));
              }
              // R2010+: fit data (a count on code 97 followed by 11/21)
              if (at(97) && k + 1 < end && pairs[k + 1].$1 == 11) {
                final nf = ri(97);
                for (var q = 0; q < nf && k < end; q++) {
                  rd(11);
                  rd(21);
                }
                rd(12);
                rd(22);
                rd(13);
                rd(23);
              }
              loop.addAll(splineCurve(degree, ctrl, knots: knots, weights: weights));
            default:
              break;
          }
        }
      }
      // source boundary objects
      if (at(97)) {
        final n = ri(97);
        for (var q = 0; q < n && at(330); q++) {
          k++;
        }
      }
      if (loop.length > 2 && loop.first.distanceTo(loop.last) < 1e-9) loop.removeLast();
      if (loop.length >= 3) loops.add(loop);
    }
    // pattern: the first definition line (angle 53, offset 45/46)
    var angle = 45.0, spacing = 0.0, scale = 1.0;
    while (k < end) {
      final (c, v) = pairs[k];
      if (c == 52) angle = double.tryParse(v) ?? angle;
      if (c == 41) scale = double.tryParse(v) ?? scale;
      if (c == 53) {
        final a = double.tryParse(v) ?? angle;
        k++;
        rd(43);
        rd(44);
        final dx = rd(45), dy = rd(46);
        final r = degToRad(a);
        final d = (-math.sin(r) * dx + math.cos(r) * dy).abs();
        angle = a;
        if (d > 1e-9) spacing = d;
        break;
      }
      k++;
    }
    if (spacing <= 0) spacing = 3.175 * (scale > 0 ? scale : 1);
    if (loops.isEmpty) return;
    loops.sort((a, b) => polygonArea(b).abs().compareTo(polygonArea(a).abs()));
    out.add(DxfEntity(type: 'HATCH', layer: layer, color: color, points: loops.first, closed: true, rotation: angle, height: spacing, solid: solid));
    for (final island in loops.skip(1)) {
      out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: island, closed: true));
    }
  }

  /// Reads a MULTILEADER from its group codes [pairs]: the text of its
  /// context data (placed by its attachment) and each leader line, from the
  /// arrow to the landing and along the dogleg.
  static void _readMLeader(List<(int, String)> pairs, String layer, int color, List<DxfEntity> out) {
    var context = 0;
    var inLeader = false, inLine = false;
    String? text;
    double? tx, ty, height, dirX, dirY, rotation;
    var attach = 1;
    double? lastX, lastY, dogX, dogY;
    var dogLength = 0.0;
    final lines = <List<Pt>>[];
    var line = <Pt>[];
    double? vx;
    final leaderLines = <List<Pt>>[];
    void closeLeader() {
      final landing = lastX != null && lastY != null ? Pt(lastX, lastY) : null;
      for (final l in leaderLines) {
        final pts = [...l];
        if (landing != null && (pts.isEmpty || pts.last.distanceTo(landing) > 1e-9)) pts.add(landing);
        if (landing != null && dogX != null && dogY != null && dogLength > 0) pts.add(landing + Pt(dogX, dogY).normalized * dogLength);
        if (pts.length >= 2) lines.add(pts);
      }
      leaderLines.clear();
    }

    for (final (c, v) in pairs) {
      if (c == 300 && v.startsWith('CONTEXT_DATA')) {
        context++;
        continue;
      }
      if (c == 301 && context > 0) {
        context--;
        continue;
      }
      if (context == 0) continue;
      if (c == 302 && v.startsWith('LEADER')) {
        inLeader = true;
        lastX = lastY = dogX = dogY = null;
        dogLength = 0;
        continue;
      }
      if (c == 303 && inLeader) {
        closeLeader();
        inLeader = false;
        continue;
      }
      if (c == 304 && v.startsWith('LEADER_LINE')) {
        inLine = true;
        line = <Pt>[];
        continue;
      }
      if (c == 305 && inLine) {
        leaderLines.add(line);
        inLine = false;
        continue;
      }
      final d = double.tryParse(v);
      if (inLine) {
        if (c == 10) vx = d;
        if (c == 20 && vx != null && d != null) line.add(Pt(vx, d));
        continue;
      }
      if (inLeader) {
        switch (c) {
          case 10:
            lastX = d;
          case 20:
            lastY = d;
          case 11:
            dogX = d;
          case 21:
            dogY = d;
          case 40:
            dogLength = d ?? 0;
        }
        continue;
      }
      switch (c) {
        case 304:
          text ??= v;
        case 12:
          tx = d;
        case 22:
          ty = d;
        case 41:
          height ??= d;
        case 13:
          dirX = d;
        case 23:
          dirY = d;
        case 42:
          rotation = d;
        case 171:
          attach = int.tryParse(v) ?? attach;
      }
    }
    for (final l in lines) {
      out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: l));
    }
    final t = text == null ? '' : plainMText(text);
    if (t.isEmpty || tx == null || ty == null) return;
    final h = height != null && height > 0 ? height : 1.0;
    final rot = dirX != null && dirY != null && (dirX != 0 || dirY != 0) ? radToDeg(math.atan2(dirY, dirX)) : radToDeg(rotation ?? 0);
    final a = attach.clamp(1, 9);
    final pos = cadTextBase(Pt(tx, ty), t, h, rot, ((a - 1) % 3) / 2, (2 - (a - 1) ~/ 3) / 2);
    out.add(DxfEntity(type: 'TEXT', layer: layer, color: color, points: [pos], text: t, height: h, rotation: rot));
  }

  static List<Pt> _withBulges(List<_Vertex> v, bool closed) {
    final out = <Pt>[];
    for (var k = 0; k < v.length; k++) {
      final a = v[k];
      out.add(Pt(a.x, a.y));
      final next = k + 1 < v.length ? v[k + 1] : (closed && v.length > 2 ? v[0] : null);
      if (a.bulge != 0 && next != null) out.addAll(bulgeArc(Pt(a.x, a.y), Pt(next.x, next.y), a.bulge));
    }
    return out;
  }

  /// Intermediate points of the arc from [p1] to [p2] with the given bulge
  /// (tangent of a quarter of the included angle; positive = counter-clockwise),
  /// one every [stepRad] at most.
  static List<Pt> bulgeArc(Pt p1, Pt p2, double bulge, {double stepRad = math.pi / 12}) {
    final chord = p2 - p1;
    final c = chord.length;
    if (c < 1e-12 || bulge.abs() < 1e-9 || !bulge.isFinite) return const [];
    final theta = 4 * math.atan(bulge);
    final r = c / (2 * math.sin(theta.abs() / 2));
    final centre = Pt.lerp(p1, p2, 0.5) + chord.perpendicular * ((c / 2) / math.tan(theta / 2) / c);
    final a1 = (p1 - centre).angle;
    final n = math.max(2, (theta.abs() / stepRad).ceil());
    return [for (var k = 1; k < n; k++) centre + Pt.polar(r, a1 + theta * k / n)];
  }

  /// Appends the entities of every block reference in [inserts] (and of the
  /// references nested in the blocks) to [out], transformed to world
  /// coordinates. Entities on layer 0 take the reference's layer and colour
  /// BYBLOCK takes its colour, as CAD programs draw them. A block inside
  /// itself is drawn once, a reference to an external drawing is reported
  /// and the expansion stops at [maxEntities] / [maxPoints] (`warnings`:
  /// `dxf_blocks_truncated`, `dxf_block_cycle:<names>`,
  /// `dxf_xref_missing:<names>`).
  static void expandInserts(List<DxfInsert> inserts, Map<String, DxfBlock> blocks, List<DxfEntity> out, {List<String>? warnings}) {
    final x = _Expansion(blocks, out);
    x.run(inserts, null, null, null);
    if (x.truncated) warnings?.add('dxf_blocks_truncated');
    if (x.cycles.isNotEmpty) warnings?.add('dxf_block_cycle:${x.cycles.take(5).join(', ')}');
    if (x.xrefs.isNotEmpty) warnings?.add('dxf_xref_missing:${x.xrefs.take(8).join(', ')}');
  }

  static void _transformed(DxfEntity e, Affine2 t, String insLayer, int insColor, List<DxfEntity> out) {
    final layer = e.layer == '0' ? insLayer : e.layer;
    final color = e.color == 0 ? insColor : e.color;
    switch (e.type) {
      case 'CIRCLE':
        if (t.isConformal) {
          out.add(DxfEntity(type: 'CIRCLE', layer: layer, color: color, center: t.apply(e.center!), radius: e.radius * t.scale, elevation: e.elevation));
        } else {
          out.add(
            DxfEntity(
              type: 'POLYLINE',
              layer: layer,
              color: color,
              points: [for (var k = 0; k < 36; k++) t.apply(e.center! + Pt.polar(e.radius, 2 * math.pi * k / 36))],
              closed: true,
              elevation: e.elevation,
            ),
          );
        }
      case 'ARC':
        final sweep = radToDeg(cadSweepRad(degToRad(e.startAngle), degToRad(e.endAngle)));
        if (t.isConformal) {
          // a mirror turns the arc clockwise: it now starts at the image of its end
          final start = t.mirrored ? t.dirDeg(e.startAngle + sweep) : t.dirDeg(e.startAngle);
          out.add(
            DxfEntity(
              type: 'ARC',
              layer: layer,
              color: color,
              center: t.apply(e.center!),
              radius: e.radius * t.scale,
              startAngle: cadNormalizeDeg(start),
              endAngle: cadNormalizeDeg(start + sweep),
              elevation: e.elevation,
            ),
          );
        } else {
          final n = math.max(4, (sweep / 10).ceil());
          out.add(
            DxfEntity(
              type: 'POLYLINE',
              layer: layer,
              color: color,
              points: [for (var k = 0; k <= n; k++) t.apply(e.center! + Pt.polar(e.radius, degToRad(e.startAngle + sweep * k / n)))],
              elevation: e.elevation,
            ),
          );
        }
      case 'TEXT':
        out.add(
          DxfEntity(
            type: 'TEXT',
            layer: layer,
            color: color,
            points: [t.apply(e.points[0])],
            text: e.text,
            height: e.height * t.scale,
            rotation: t.dirDeg(e.rotation),
            elevation: e.elevation,
            name: e.name,
          ),
        );
      case 'HATCH':
        out.add(
          DxfEntity(
            type: 'HATCH',
            layer: layer,
            color: color,
            points: e.points.map(t.apply).toList(),
            closed: true,
            rotation: t.dirDeg(e.rotation),
            height: e.height * t.scale,
            solid: e.solid,
            name: e.name,
            elevation: e.elevation,
          ),
        );
      default:
        out.add(
          DxfEntity(
            type: e.type,
            layer: layer,
            color: color,
            points: e.points.map(t.apply).toList(),
            closed: e.closed,
            elevation: e.elevation,
            name: e.name,
            text: e.text,
            height: e.height,
            rotation: e.rotation,
          ),
        );
    }
  }
}

/// R12 writer (AC1009) of a [DxfDocument]: LINE, POLYLINE, CIRCLE, ARC,
/// TEXT and POINT (with its elevation) on layers with a colour index. Texts
/// are in code page 1252 ([writeBytes]; characters outside it become `?`)
/// and layer names follow the rule of the format (A–Z, 0–9, `$`, `-`, `_`,
/// at most 31 characters: [r12LayerName]). The R2000 export with
/// native entities is in `dxf_r2000.dart`.
class DxfWriter {
  static String _n(double v) => v.isFinite ? v.toStringAsFixed(4) : '0.0000';

  /// [name] as an R12 layer name: accents dropped, upper case, other
  /// characters as `_`, at most 31 characters ('0' when nothing is left).
  static String r12LayerName(String name) {
    const from = 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const to = 'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinooooouuuuyy';
    final b = StringBuffer();
    for (final r in name.trim().runes) {
      var ch = String.fromCharCode(r);
      final i = from.indexOf(ch);
      if (i >= 0) ch = to[i];
      ch = ch.toUpperCase();
      b.write(RegExp(r'^[A-Z0-9$_-]$').hasMatch(ch) ? ch : '_');
    }
    var s = b.toString();
    if (s.length > 31) s = s.substring(0, 31);
    return s.isEmpty ? '0' : s;
  }

  /// The R12 names of [layers], told apart once upper-cased and cut
  /// (`TUBOS`, `TUBOS_2`).
  static Map<String, String> r12LayerNames(Iterable<String> layers) {
    final out = <String, String>{};
    final used = <String>{};
    for (final l in layers) {
      if (out.containsKey(l)) continue;
      final base = r12LayerName(l);
      var n = base;
      var k = 2;
      while (!used.add(n)) {
        final suffix = '_$k';
        n = base.length + suffix.length > 31 ? base.substring(0, 31 - suffix.length) + suffix : base + suffix;
        k++;
      }
      out[l] = n;
    }
    return out;
  }

  /// The file as text (the characters as they are; see [writeBytes] for the
  /// bytes to save).
  static String write(DxfDocument doc) {
    final names = r12LayerNames(['0', ...doc.layers.map((l) => l.name), ...doc.entities.map((e) => e.layer)]);
    String layerOf(String l) => names[l] ?? r12LayerName(l);
    final b = StringBuffer();
    void pair(int code, Object value) {
      b.writeln(code);
      // a line break inside a value would end the pair: texts stay on one line
      b.writeln(value is String ? value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') : value);
    }

    pair(0, 'SECTION');
    pair(2, 'HEADER');
    pair(9, r'$ACADVER');
    pair(1, 'AC1009');
    pair(9, r'$DWGCODEPAGE');
    pair(3, 'ANSI_1252');
    pair(0, 'ENDSEC');
    // the linetype the layers use, then the layers
    pair(0, 'SECTION');
    pair(2, 'TABLES');
    pair(0, 'TABLE');
    pair(2, 'LTYPE');
    pair(70, 1);
    pair(0, 'LTYPE');
    pair(2, 'CONTINUOUS');
    pair(70, 0);
    pair(3, 'Solid line');
    pair(72, 65);
    pair(73, 0);
    pair(40, '0.0');
    pair(0, 'ENDTAB');
    pair(0, 'TABLE');
    pair(2, 'LAYER');
    final layers = <String, DxfLayer>{};
    for (final l in doc.layers) {
      layers.putIfAbsent(layerOf(l.name), () => l);
    }
    pair(70, layers.length);
    for (final MapEntry(key: name, value: l) in layers.entries) {
      pair(0, 'LAYER');
      pair(2, name);
      pair(70, 0);
      pair(62, l.color);
      pair(6, 'CONTINUOUS');
    }
    pair(0, 'ENDTAB');
    pair(0, 'ENDSEC');
    pair(0, 'SECTION');
    pair(2, 'ENTITIES');
    for (final e in doc.entities) {
      final layer = layerOf(e.layer);
      switch (e.type) {
        case 'LINE':
          pair(0, 'LINE');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, 0);
          pair(11, _n(e.points[1].x));
          pair(21, _n(e.points[1].y));
          pair(31, 0);
        case 'POLYLINE':
          pair(0, 'POLYLINE');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(66, 1);
          pair(70, e.closed ? 1 : 0);
          for (final p in e.points) {
            pair(0, 'VERTEX');
            pair(8, layer);
            pair(10, _n(p.x));
            pair(20, _n(p.y));
            pair(30, 0);
          }
          pair(0, 'SEQEND');
          pair(8, layer);
        case 'CIRCLE':
          pair(0, 'CIRCLE');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.center!.x));
          pair(20, _n(e.center!.y));
          pair(30, 0);
          pair(40, _n(e.radius));
        case 'ARC':
          pair(0, 'ARC');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.center!.x));
          pair(20, _n(e.center!.y));
          pair(30, 0);
          pair(40, _n(e.radius));
          pair(50, _n(e.startAngle));
          pair(51, _n(e.endAngle));
        case 'TEXT':
          pair(0, 'TEXT');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, 0);
          pair(40, _n(e.height));
          pair(1, e.text);
          if (e.rotation != 0) pair(50, _n(e.rotation));
        case 'POINT':
          pair(0, 'POINT');
          pair(8, layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, _n(e.elevation ?? 0));
      }
    }
    pair(0, 'ENDSEC');
    pair(0, 'EOF');
    return b.toString();
  }

  /// The bytes of the file: [write] in code page 1252, as the header says.
  static Uint8List writeBytes(DxfDocument doc) => encodeCp1252(write(doc));
}
