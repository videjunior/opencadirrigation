/// Minimal DXF reader/writer (ASCII). Reads LINE, LWPOLYLINE and POLYLINE
/// (with bulges), CIRCLE, ARC, ELLIPSE, SPLINE, TEXT, MTEXT, ATTRIB and POINT
/// entities with their layers, and expands block references (INSERT,
/// MINSERT, DIMENSION blocks); writes an R12-compatible file with a LAYER
/// table.
library;

import 'dart:math' as math;

import '../model/geometry.dart';

class DxfEntity {
  DxfEntity({required this.type, required this.layer, this.points = const [], this.center, this.radius = 0, this.startAngle = 0, this.endAngle = 0, this.text = '', this.height = 1, this.rotation = 0, this.closed = false, this.color = 256, this.elevation, this.name = ''});
  final String type; // LINE, POLYLINE, CIRCLE, ARC, TEXT, POINT
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
}

class DxfLayer {
  DxfLayer(this.name, {this.color = 7});
  final String name;
  final int color;
}

class DxfDocument {
  DxfDocument({List<DxfEntity>? entities, List<DxfLayer>? layers, this.unitScale = 1})
      : entities = entities ?? [],
        layers = layers ?? [];
  final List<DxfEntity> entities;
  final List<DxfLayer> layers;

  /// Multiplier from file units to metres ($INSUNITS), 1 if unknown.
  final double unitScale;

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
  DxfBlock(this.name, this.base, this.entities, this.inserts);
  final String name;
  final Pt base;
  final List<DxfEntity> entities;
  final List<DxfInsert> inserts;
}

/// A block reference (INSERT / MINSERT / the anonymous block of a DIMENSION).
class DxfInsert {
  DxfInsert({required this.name, required this.layer, this.color = 256, required this.position, this.scaleX = 1, this.scaleY = 1, this.rotation = 0, this.cols = 1, this.rows = 1, this.colSpacing = 0, this.rowSpacing = 0});
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

  /// Block → world transform of the array cell ([col], [row]).
  Affine2 affine(Pt base, [int col = 0, int row = 0]) {
    final r = degToRad(rotation);
    final cs = math.cos(r), sn = math.sin(r);
    final m = Affine2(scaleX * cs, -scaleY * sn, scaleX * sn, scaleY * cs, 0, 0);
    final offset = Pt.polar(col * colSpacing, r) + Pt.polar(row * rowSpacing, r + math.pi / 2);
    final mb = m.apply(base);
    return Affine2(m.a, m.b, m.c, m.d, position.x + offset.x - mb.x, position.y + offset.y - mb.y);
  }
}

/// x' = a·x + b·y + tx, y' = c·x + d·y + ty.
class Affine2 {
  const Affine2(this.a, this.b, this.c, this.d, this.tx, this.ty);
  final double a, b, c, d, tx, ty;
  Pt apply(Pt p) => Pt(a * p.x + b * p.y + tx, c * p.x + d * p.y + ty);

  /// This transform applied after [inner].
  Affine2 then(Affine2 inner) => Affine2(a * inner.a + b * inner.c, a * inner.b + b * inner.d, c * inner.a + d * inner.c, c * inner.b + d * inner.d, a * inner.tx + b * inner.ty + tx, c * inner.tx + d * inner.ty + ty);

  /// Uniform scale and rotation only (circles stay circles).
  bool get isSimilarity {
    final eps = 1e-9 * (a.abs() + b.abs() + c.abs() + d.abs() + 1);
    return (a - d).abs() < eps && (b + c).abs() < eps;
  }

  double get scale => math.sqrt((a * d - b * c).abs());
  double get rotationDeg => radToDeg(math.atan2(c, a));
}

class _Vertex {
  _Vertex(this.x, this.y, [this.bulge = 0]);
  final double x;
  double y;
  double bulge;
}

class DxfReader {
  static double _unitScale(int insunits) => switch (insunits) {
    1 => 0.0254, // inches
    2 => 0.3048, // feet
    4 => 0.001, // mm
    5 => 0.01, // cm
    6 => 1.0, // m
    _ => 1.0,
  };

  static DxfDocument parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final pairs = <(int, String)>[];
    for (var i = 0; i + 1 < lines.length; i += 2) {
      final code = int.tryParse(lines[i].trim());
      if (code == null) continue;
      pairs.add((code, lines[i + 1].trim()));
    }
    final layers = <DxfLayer>[];
    final entities = <DxfEntity>[];
    final inserts = <DxfInsert>[];
    final blocks = <String, DxfBlock>{};
    var insunits = 0;
    var section = '';
    var i = 0;
    while (i < pairs.length) {
      final (code, value) = pairs[i];
      if (code == 0 && value == 'SECTION') {
        section = i + 1 < pairs.length ? pairs[i + 1].$2 : '';
        i += 2;
        continue;
      }
      if (code == 0 && value == 'ENDSEC') {
        section = '';
        i++;
        continue;
      }
      if (section == 'HEADER' && code == 9 && value == r'$INSUNITS') {
        if (i + 1 < pairs.length && pairs[i + 1].$1 == 70) insunits = int.tryParse(pairs[i + 1].$2) ?? 0;
        i++;
        continue;
      }
      if (section == 'TABLES' && code == 0 && value == 'LAYER') {
        String? name;
        var color = 7;
        var j = i + 1;
        while (j < pairs.length && pairs[j].$1 != 0) {
          if (pairs[j].$1 == 2) name = pairs[j].$2;
          if (pairs[j].$1 == 62) color = int.tryParse(pairs[j].$2)?.abs() ?? 7;
          j++;
        }
        if (name != null && name.isNotEmpty) layers.add(DxfLayer(name, color: color));
        i = j;
        continue;
      }
      if (section == 'BLOCKS' && code == 0 && value == 'BLOCK') {
        var j = i + 1;
        var name = '';
        var bx = 0.0, by = 0.0;
        while (j < pairs.length && pairs[j].$1 != 0) {
          final (c, v) = pairs[j];
          if (c == 2) name = v;
          if (c == 10) bx = double.tryParse(v) ?? 0;
          if (c == 20) by = double.tryParse(v) ?? 0;
          j++;
        }
        final ents = <DxfEntity>[];
        final ins = <DxfInsert>[];
        while (j < pairs.length && !(pairs[j].$1 == 0 && (pairs[j].$2 == 'ENDBLK' || pairs[j].$2 == 'ENDSEC'))) {
          j = pairs[j].$1 == 0 ? _readEntity(pairs, j, ents, ins) : j + 1;
        }
        if (j < pairs.length && pairs[j].$2 == 'ENDBLK') {
          j++;
          while (j < pairs.length && pairs[j].$1 != 0) {
            j++;
          }
        }
        if (name.isNotEmpty) blocks[name] = DxfBlock(name, Pt(bx, by), ents, ins);
        i = j;
        continue;
      }
      if (section == 'ENTITIES' && code == 0) {
        i = _readEntity(pairs, i, entities, inserts);
        continue;
      }
      i++;
    }
    expandInserts(inserts, blocks, entities);
    return DxfDocument(entities: entities, layers: layers, unitScale: _unitScale(insunits));
  }

  /// Reads the entity whose type is at `pairs[i]` (a code 0) into [out], or
  /// into [inserts] for block references, and returns the index of the next
  /// code-0 pair.
  static int _readEntity(List<(int, String)> pairs, int i, List<DxfEntity> out, List<DxfInsert> inserts) {
    final type = pairs[i].$2;
    var j = i + 1;
    final props = <int, List<String>>{};
    final verts = <_Vertex>[]; // LWPOLYLINE vertices in file order (10, 20, 42)
    while (j < pairs.length && pairs[j].$1 != 0) {
      final (c, v) = pairs[j];
      props.putIfAbsent(c, () => []).add(v);
      if (type == 'LWPOLYLINE') {
        if (c == 10) {
          verts.add(_Vertex(double.tryParse(v) ?? 0, 0));
        } else if (c == 20 && verts.isNotEmpty) {
          verts.last.y = double.tryParse(v) ?? 0;
        } else if (c == 42 && verts.isNotEmpty) {
          verts.last.bulge = double.tryParse(v) ?? 0;
        }
      }
      j++;
    }
    double num(int c, [int idx = 0, double def = 0]) => double.tryParse(props[c]?.elementAtOrNull(idx) ?? '') ?? def;
    int flags(int c) => int.tryParse(props[c]?.first ?? '0') ?? 0;
    final layer = props[8]?.first ?? '0';
    final color = int.tryParse(props[62]?.first ?? '') ?? 256;
    switch (type) {
      case 'LINE':
        out.add(DxfEntity(type: 'LINE', layer: layer, color: color, points: [Pt(num(10), num(20)), Pt(num(11), num(21))], elevation: props.containsKey(30) ? num(30) : null));
      case 'LWPOLYLINE':
        final closed = flags(70) & 1 == 1;
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: _withBulges(verts, closed), closed: closed, elevation: props.containsKey(38) ? num(38) : null));
      case 'POLYLINE':
        final closed = flags(70) & 1 == 1;
        final pv = <_Vertex>[];
        double? zElev;
        var sameZ = true;
        // consume VERTEX entities until SEQEND
        var k = j;
        while (k < pairs.length) {
          if (pairs[k].$1 == 0) {
            if (pairs[k].$2 == 'SEQEND') {
              k++;
              while (k < pairs.length && pairs[k].$1 != 0) {
                k++;
              }
              break;
            }
            if (pairs[k].$2 == 'VERTEX') {
              var m = k + 1;
              double? x, y, z;
              var bulge = 0.0, vflags = 0;
              while (m < pairs.length && pairs[m].$1 != 0) {
                final v = pairs[m].$2;
                switch (pairs[m].$1) {
                  case 10:
                    x = double.tryParse(v);
                  case 20:
                    y = double.tryParse(v);
                  case 30:
                    z = double.tryParse(v);
                  case 42:
                    bulge = double.tryParse(v) ?? 0;
                  case 70:
                    vflags = int.tryParse(v) ?? 0;
                }
                m++;
              }
              // spline frame control points (flag 16) are not on the curve
              if (x != null && y != null && vflags & 16 == 0) pv.add(_Vertex(x, y, bulge));
              if (z != null) {
                if (zElev == null) {
                  zElev = z;
                } else if ((zElev - z).abs() > 1e-9) {
                  sameZ = false;
                }
              }
              k = m;
              continue;
            }
            break;
          }
          k++;
        }
        j = k;
        // a 2D polyline carries its elevation in code 30; a 3D one in its vertices
        final own = props.containsKey(30) ? num(30) : null;
        final polyElev = own != null && own != 0 ? own : (sameZ && zElev != null && zElev != 0 ? zElev : own);
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: _withBulges(pv, closed), closed: closed, elevation: polyElev));
      case 'CIRCLE':
        out.add(DxfEntity(type: 'CIRCLE', layer: layer, color: color, center: Pt(num(10), num(20)), radius: num(40)));
      case 'ARC':
        out.add(DxfEntity(type: 'ARC', layer: layer, color: color, center: Pt(num(10), num(20)), radius: num(40), startAngle: num(50), endAngle: num(51)));
      case 'ELLIPSE':
        final c = Pt(num(10), num(20)), major = Pt(num(11), num(21));
        final minor = major.perpendicular * num(40, 0, 1);
        final a0 = num(41), a1 = num(42, 0, 2 * math.pi);
        var sweep = a1 - a0;
        if (sweep <= 1e-9) sweep += 2 * math.pi;
        final full = sweep >= 2 * math.pi - 1e-9;
        final n = math.max(8, (sweep / (math.pi / 18)).ceil());
        final pts = [for (var k = 0; k <= (full ? n - 1 : n); k++) c + major * math.cos(a0 + sweep * k / n) + minor * math.sin(a0 + sweep * k / n)];
        out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: full));
      case 'SPLINE':
        // fit points when present, else the control polygon
        final xs = props[11] ?? [], ys = props[21] ?? [];
        final cx = props[10] ?? [], cy = props[20] ?? [];
        final pts = xs.isNotEmpty && ys.length == xs.length
            ? [for (var k = 0; k < xs.length; k++) Pt(double.tryParse(xs[k]) ?? 0, double.tryParse(ys[k]) ?? 0)]
            : [for (var k = 0; k < math.min(cx.length, cy.length); k++) Pt(double.tryParse(cx[k]) ?? 0, double.tryParse(cy[k]) ?? 0)];
        if (pts.length >= 2) out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: flags(70) & 1 == 1));
      case 'TEXT':
      case 'MTEXT':
      case 'ATTRIB':
        // long MTEXT comes in code-3 chunks followed by the final code 1
        final raw = [...?props[3], ...?props[1]].join();
        final txt = raw.replaceAll(RegExp(r'\\P'), ' ').replaceAll(RegExp(r'\{|\}|\\[A-Za-z][^;]*;'), '');
        // aligned TEXT/ATTRIB is positioned by its second point
        final aligned = type != 'MTEXT' && (flags(72) != 0 || flags(73) != 0) && props.containsKey(11);
        final pos = aligned ? Pt(num(11), num(21)) : Pt(num(10), num(20));
        out.add(DxfEntity(type: 'TEXT', layer: layer, color: color, points: [pos], text: txt, height: num(40, 0, 1), rotation: num(50)));
      case 'POINT':
        out.add(DxfEntity(type: 'POINT', layer: layer, color: color, points: [Pt(num(10), num(20))], elevation: props.containsKey(30) ? num(30) : null));
      case 'INSERT':
        inserts.add(DxfInsert(name: props[2]?.first ?? '', layer: layer, color: color, position: Pt(num(10), num(20)), scaleX: num(41, 0, 1), scaleY: num(42, 0, 1), rotation: num(50), cols: math.max(1, flags(70)), rows: math.max(1, flags(71)), colSpacing: num(44), rowSpacing: num(45)));
      case 'DIMENSION':
        // the dimension's geometry lives in an anonymous block in world coordinates
        final block = props[2]?.first ?? '';
        if (block.isNotEmpty) inserts.add(DxfInsert(name: block, layer: layer, color: color, position: Pt.zero));
      default:
        break;
    }
    return j;
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
    if (c < 1e-12 || bulge.abs() < 1e-9) return const [];
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
  /// BYBLOCK takes its colour, as CAD programs draw them.
  static void expandInserts(List<DxfInsert> inserts, Map<String, DxfBlock> blocks, List<DxfEntity> out, {Affine2? outer, String? layer, int? color, int depth = 0}) {
    if (depth > 8) return;
    for (final ins in inserts) {
      final block = blocks[ins.name];
      if (block == null) continue;
      final insLayer = ins.layer == '0' && layer != null ? layer : ins.layer;
      final insColor = ins.color == 0 && color != null ? color : ins.color;
      for (var r = 0; r < ins.rows; r++) {
        for (var c = 0; c < ins.cols; c++) {
          final local = ins.affine(block.base, c, r);
          final t = outer == null ? local : outer.then(local);
          for (final e in block.entities) {
            // definition points of dimensions are not drawing geometry
            if (e.type == 'POINT' && block.name.startsWith('*D')) continue;
            _transformed(e, t, insLayer, insColor, out);
          }
          expandInserts(block.inserts, blocks, out, outer: t, layer: insLayer, color: insColor, depth: depth + 1);
        }
      }
    }
  }

  static void _transformed(DxfEntity e, Affine2 t, String insLayer, int insColor, List<DxfEntity> out) {
    final layer = e.layer == '0' ? insLayer : e.layer;
    final color = e.color == 0 ? insColor : e.color;
    switch (e.type) {
      case 'CIRCLE':
        if (t.isSimilarity) {
          out.add(DxfEntity(type: 'CIRCLE', layer: layer, color: color, center: t.apply(e.center!), radius: e.radius * t.scale, elevation: e.elevation));
        } else {
          out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: [for (var k = 0; k < 36; k++) t.apply(e.center! + Pt.polar(e.radius, 2 * math.pi * k / 36))], closed: true, elevation: e.elevation));
        }
      case 'ARC':
        var sweep = e.endAngle - e.startAngle;
        if (sweep <= 0) sweep += 360;
        if (t.isSimilarity) {
          out.add(DxfEntity(type: 'ARC', layer: layer, color: color, center: t.apply(e.center!), radius: e.radius * t.scale, startAngle: e.startAngle + t.rotationDeg, endAngle: e.startAngle + sweep + t.rotationDeg, elevation: e.elevation));
        } else {
          final n = math.max(4, (sweep / 10).ceil());
          out.add(DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: [for (var k = 0; k <= n; k++) t.apply(e.center! + Pt.polar(e.radius, degToRad(e.startAngle + sweep * k / n)))], elevation: e.elevation));
        }
      case 'TEXT':
        out.add(DxfEntity(type: 'TEXT', layer: layer, color: color, points: [t.apply(e.points[0])], text: e.text, height: e.height * t.scale, rotation: e.rotation + t.rotationDeg, elevation: e.elevation, name: e.name));
      default:
        out.add(DxfEntity(type: e.type, layer: layer, color: color, points: e.points.map(t.apply).toList(), closed: e.closed, elevation: e.elevation, name: e.name, text: e.text, height: e.height, rotation: e.rotation));
    }
  }
}

class DxfWriter {
  static String _n(double v) => v.toStringAsFixed(4);

  static String write(DxfDocument doc, {int insunits = 6}) {
    final b = StringBuffer();
    void pair(int code, Object value) {
      b.writeln(code);
      b.writeln(value);
    }

    pair(0, 'SECTION');
    pair(2, 'HEADER');
    pair(9, r'$ACADVER');
    pair(1, 'AC1009');
    pair(9, r'$INSUNITS');
    pair(70, insunits);
    pair(0, 'ENDSEC');
    // layers
    pair(0, 'SECTION');
    pair(2, 'TABLES');
    pair(0, 'TABLE');
    pair(2, 'LAYER');
    pair(70, doc.layers.length);
    for (final l in doc.layers) {
      pair(0, 'LAYER');
      pair(2, l.name);
      pair(70, 0);
      pair(62, l.color);
      pair(6, 'CONTINUOUS');
    }
    pair(0, 'ENDTAB');
    pair(0, 'ENDSEC');
    pair(0, 'SECTION');
    pair(2, 'ENTITIES');
    for (final e in doc.entities) {
      switch (e.type) {
        case 'LINE':
          pair(0, 'LINE');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, 0);
          pair(11, _n(e.points[1].x));
          pair(21, _n(e.points[1].y));
          pair(31, 0);
        case 'POLYLINE':
          pair(0, 'POLYLINE');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(66, 1);
          pair(70, e.closed ? 1 : 0);
          for (final p in e.points) {
            pair(0, 'VERTEX');
            pair(8, e.layer);
            pair(10, _n(p.x));
            pair(20, _n(p.y));
            pair(30, 0);
          }
          pair(0, 'SEQEND');
          pair(8, e.layer);
        case 'CIRCLE':
          pair(0, 'CIRCLE');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.center!.x));
          pair(20, _n(e.center!.y));
          pair(30, 0);
          pair(40, _n(e.radius));
        case 'ARC':
          pair(0, 'ARC');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.center!.x));
          pair(20, _n(e.center!.y));
          pair(30, 0);
          pair(40, _n(e.radius));
          pair(50, _n(e.startAngle));
          pair(51, _n(e.endAngle));
        case 'TEXT':
          pair(0, 'TEXT');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, 0);
          pair(40, _n(e.height));
          pair(1, e.text);
          if (e.rotation != 0) pair(50, _n(e.rotation));
        case 'POINT':
          pair(0, 'POINT');
          pair(8, e.layer);
          if (e.color != 256) pair(62, e.color);
          pair(10, _n(e.points[0].x));
          pair(20, _n(e.points[0].y));
          pair(30, 0);
      }
    }
    pair(0, 'ENDSEC');
    pair(0, 'EOF');
    return b.toString();
  }
}
