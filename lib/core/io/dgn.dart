/// DGN V7 (ISFF design file) reader producing the
/// intermediate drawing of the DXF and DWG readers ([DxfDocument]): lines,
/// line strings, shapes, curves, complex chains and shapes (joined into one
/// polyline), circles, ellipses and arcs, text, cells (their components, named
/// after the cell), levels as layers (`LEVEL_<n>`), 2D and 3D files (a
/// constant Z becomes the elevation; a 3D point — a zero-length line — keeps
/// its Z). Coordinates are converted from the file's units of resolution with
/// the master/sub-unit ratio and the global origin of the design file header
/// (type 9 element); the master unit names the metres per unit
/// ([DxfDocument.unitScale]).
///
/// DGN V8 files (an OLE compound document) are recognised and refused with
/// `dgn_v8_unsupported`; other files with `dgn_not_dgn`.
///
/// Element layout: 18-word header (level, complex and deleted bits, type,
/// words to follow, range, graphic group, attribute index, properties,
/// symbology), 32-bit integers in middle-endian word order (high word first,
/// each word little-endian), floating point values in VAX D format (ellipse
/// and arc axes and origins, the global origin), angles in 1/360000 degree.
///
/// Reference: the ISFF specification of the V7 design file (element
/// structure, 1994).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'dxf.dart';

class DgnImportResult {
  DgnImportResult({required this.document, required this.is3d, required this.masterUnit, required this.elementCount, required this.typeCounts, required this.cellCount, required this.warnings});
  final DxfDocument document;
  final bool is3d;

  /// Master unit name of the design file header (`m`, `ft`…).
  final String masterUnit;

  /// Elements read (deleted ones excluded).
  final int elementCount;

  /// Elements per type number.
  final Map<int, int> typeCounts;
  final int cellCount;

  /// Message codes: `dgn_truncated`, `dgn_units_unknown:<name>`, `dgn_skipped:<type>:<n>`.
  final List<String> warnings;
}

class DgnReader {
  /// OLE compound document signature (DGN V8 and other formats).
  static bool isOle(Uint8List b) => b.length >= 8 && b[0] == 0xD0 && b[1] == 0xCF && b[2] == 0x11 && b[3] == 0xE0 && b[4] == 0xA1 && b[5] == 0xB1 && b[6] == 0x1A && b[7] == 0xE1;

  /// True when the file starts with a V7 design file header (type 9).
  static bool isV7(Uint8List b) => b.length >= 4 && (b[0] & 0x3F) == 8 && (b[1] & 0x7F) == 9 && b[2] == 0xFE && b[3] == 0x02;

  static DgnImportResult parse(Uint8List b) {
    if (isOle(b)) throw const FormatException('dgn_v8_unsupported');
    if (!isV7(b)) throw const FormatException('dgn_not_dgn');
    final p = _Parser(b);
    p.run();
    final unit = p.masterUnit.toLowerCase();
    final scale = switch (unit) {
      'm' || 'mt' || 'me' || 'mtr' => 1.0,
      'cm' => 0.01,
      'mm' => 0.001,
      'km' => 1000.0,
      'ft' || "'" || 'fe' => 0.3048,
      'in' || '"' => 0.0254,
      'yd' => 0.9144,
      'mi' => 1609.344,
      'us' || 'uf' || 'sf' => 1200 / 3937,
      _ => 1.0,
    };
    if (scale == 1.0 && !const {'m', 'mt', 'me', 'mtr', ''}.contains(unit)) p.warnings.add('dgn_units_unknown:${p.masterUnit}');
    final layers = [for (final l in p.levels.toList()..sort()) DxfLayer('LEVEL_$l', color: 7)];
    return DgnImportResult(
      document: DxfDocument(entities: p.out, layers: layers, unitScale: scale),
      is3d: p.dim3,
      masterUnit: p.masterUnit,
      elementCount: p.count,
      typeCounts: p.types,
      cellCount: p.cells,
      warnings: p.warnings,
    );
  }
}

class _Complex {
  _Complex(this.type, this.level, this.remaining, this.name);
  final int type; // 2 cell, 12 chain, 14 shape
  final int level;

  /// Components still expected (chains, shapes) or words (cells).
  int remaining;
  final String name;
  final pts = <Pt>[];
  final zs = <double>[];
}

class _Parser {
  _Parser(this.b) : d = ByteData.sublistView(b);
  final Uint8List b;
  final ByteData d;
  final out = <DxfEntity>[];
  final levels = <int>{};
  final types = <int, int>{};
  final warnings = <String>[];
  var count = 0, cells = 0;
  var dim3 = false;
  var masterUnit = '';
  double scale = 1, ox = 0, oy = 0, oz = 0;
  var tcb = false;
  final stack = <_Complex>[];

  int u16(int o) => b[o] | (b[o + 1] << 8);

  /// Middle-endian signed 32-bit integer.
  int i32(int o) {
    final v = u16(o) * 65536 + u16(o + 2);
    return v >= 2147483648 ? v - 4294967296 : v;
  }

  /// VAX D-format double.
  double vax(int o) {
    final w0 = u16(o), w1 = u16(o + 2), w2 = u16(o + 4), w3 = u16(o + 6);
    final e = (w0 >> 7) & 0xFF;
    if (e == 0) return 0;
    final frac = ((w0 & 0x7F) * 65536 + w1) / 8388608 + (w2 * 65536 + w3) / 36028797018963968;
    final v = (1 + frac) * math.pow(2, e - 129);
    return w0 & 0x8000 != 0 ? -v : v.toDouble();
  }

  double x(int o) => i32(o) * scale - ox;
  double y(int o) => i32(o) * scale - oy;
  double z(int o) => i32(o) * scale - oz;

  void run() {
    var o = 0;
    while (o + 4 <= b.length) {
      if (b[o] == 0xFF && b[o + 1] == 0xFF) break; // end of design
      final level = b[o] & 0x3F;
      final complex = b[o] & 0x80 != 0;
      final type = b[o + 1] & 0x7F;
      final deleted = b[o + 1] & 0x80 != 0;
      final size = (u16(o + 2) + 2) * 2;
      if (o + size > b.length || size < 4) {
        warnings.add('dgn_truncated');
        break;
      }
      if (type == 9 && !tcb) {
        _tcb(o);
      } else if (!deleted) {
        count++;
        types[type] = (types[type] ?? 0) + 1;
        if (!complex) {
          _closeAll();
        } else {
          _component(size ~/ 2);
        }
        _element(o, size, level, type, complex);
        // headers whose components are all read (a header just opened
        // waits for its own)
        while (stack.isNotEmpty && stack.last.remaining <= 0) {
          _close(stack.removeLast());
        }
      }
      o += size;
    }
    _closeAll();
  }

  void _tcb(int o) {
    if (o + 1264 > b.length) return;
    tcb = true;
    dim3 = b[o + 1214] & 0x40 != 0;
    final subPerMaster = i32(o + 1112), uorPerSub = i32(o + 1116);
    masterUnit = latin1.decode([for (final c in b.sublist(o + 1120, o + 1122)) if (c > 0x20) c]).trim();
    final f = (subPerMaster == 0 ? 1 : subPerMaster) * (uorPerSub == 0 ? 1 : uorPerSub);
    scale = 1 / f.toDouble();
    ox = vax(o + 1240) * scale;
    oy = vax(o + 1248) * scale;
    oz = vax(o + 1256) * scale;
  }

  /// Counts an element with the complex bit as a component of the open
  /// headers: its words against every open cell, one component against an
  /// open chain or shape.
  void _component(int words) {
    for (final c in stack) {
      if (c.type == 2) c.remaining -= words;
    }
    if (stack.isNotEmpty && stack.last.type != 2) stack.last.remaining--;
  }

  void _closeAll() {
    while (stack.isNotEmpty) {
      _close(stack.removeLast());
    }
  }

  void _close(_Complex c) {
    if (c.type == 2) return;
    var pts = c.pts;
    final closed = c.type == 14;
    // components share their end points
    final dedup = <Pt>[];
    final zs = <double>[];
    for (var i = 0; i < pts.length; i++) {
      if (dedup.isNotEmpty && dedup.last.distanceTo(pts[i]) < 1e-9) continue;
      dedup.add(pts[i]);
      if (i < c.zs.length) zs.add(c.zs[i]);
    }
    pts = dedup;
    if (closed && pts.length > 3 && pts.first.distanceTo(pts.last) < 1e-9) pts = pts.sublist(0, pts.length - 1);
    if (pts.length >= 2) _add(DxfEntity(type: 'POLYLINE', layer: 'LEVEL_${c.level}', points: pts, closed: closed, elevation: _sameZ(zs), name: _cellName()), c.level);
  }

  String _cellName() {
    for (final c in stack.reversed) {
      if (c.type == 2) return c.name;
    }
    return '';
  }

  double? _sameZ(List<double> zs) => dim3 && zs.isNotEmpty && zs.every((v) => (v - zs.first).abs() < 1e-9) ? zs.first : null;

  void _add(DxfEntity e, int level) {
    levels.add(level);
    out.add(e);
  }

  /// Vertices of a line string, shape or curve element.
  (List<Pt>, List<double>) _vertices(int o, int size) {
    final n = u16(o + 36);
    final step = dim3 ? 12 : 8;
    final pts = <Pt>[], zs = <double>[];
    for (var i = 0; i < n && o + 38 + (i + 1) * step <= o + size; i++) {
      final v = o + 38 + i * step;
      pts.add(Pt(x(v), y(v + 4)));
      if (dim3) zs.add(z(v + 8));
    }
    return (pts, zs);
  }

  void _element(int o, int size, int level, int type, bool complex) {
    final layer = 'LEVEL_$level';
    final chain = stack.isNotEmpty && stack.last.type != 2 ? stack.last : null;
    switch (type) {
      case 2: // cell header
        cells++;
        final name = '${_rad50(u16(o + 38))}${_rad50(u16(o + 40))}'.trim();
        // components follow: the words after the header's 19th word, less
        // the rest of this header
        stack.add(_Complex(2, level, u16(o + 36) - (size ~/ 2 - 19), name));
        if (stack.last.remaining <= 0) stack.removeLast();
        return;
      case 12 || 14: // complex chain / shape header
        stack.add(_Complex(type, level, u16(o + 38), ''));
        if (stack.last.remaining <= 0) stack.removeLast();
        return;
      case 3: // line
        final a = Pt(x(o + 36), y(o + 40));
        final bb = dim3 ? Pt(x(o + 48), y(o + 52)) : Pt(x(o + 44), y(o + 48));
        final za = dim3 ? z(o + 44) : null, zb = dim3 ? z(o + 56) : null;
        if (chain != null) {
          chain.pts.addAll([a, bb]);
          if (za != null) chain.zs.addAll([za, zb!]);
          return;
        }
        if (a.distanceTo(bb) < 1e-9) {
          _add(DxfEntity(type: 'POINT', layer: layer, points: [a], elevation: za, name: _cellName()), level);
        } else {
          _add(DxfEntity(type: 'LINE', layer: layer, points: [a, bb], elevation: za != null && (za - zb!).abs() < 1e-9 ? za : null, name: _cellName()), level);
        }
      case 4 || 6 || 11: // line string, shape, curve
        var (pts, zs) = _vertices(o, size);
        if (type == 11 && pts.length > 4) {
          // a curve's first and last two points set its end tangents
          pts = pts.sublist(2, pts.length - 2);
          if (zs.isNotEmpty) zs = zs.sublist(2, zs.length - 2);
        }
        if (chain != null) {
          chain.pts.addAll(pts);
          chain.zs.addAll(zs);
          return;
        }
        final closed = type == 6;
        if (closed && pts.length > 3 && pts.first.distanceTo(pts.last) < 1e-9) {
          pts = pts.sublist(0, pts.length - 1);
          if (zs.isNotEmpty) zs = zs.sublist(0, zs.length - 1);
        }
        if (pts.length >= 2) _add(DxfEntity(type: 'POLYLINE', layer: layer, points: pts, closed: closed && pts.length >= 3, elevation: _sameZ(zs), name: _cellName()), level);
      case 15 || 16: // ellipse, arc
        _conic(o, level, type == 16, chain);
      case 17: // text
        _text(o, size, level);
      default:
        // headers, symbology, application data and other non-graphic elements
        break;
    }
  }

  /// Rotation (degrees) about Z of a 3D element's quaternion (w, x, y, z
  /// as 32-bit fractions of 2³¹).
  double _quatRotation(int o) {
    final w = i32(o) / 2147483648, qx = i32(o + 4) / 2147483648, qy = i32(o + 8) / 2147483648, qz = i32(o + 12) / 2147483648;
    return math.atan2(2 * (qx * qy + w * qz), w * w + qx * qx - qy * qy - qz * qz) * 180 / math.pi;
  }

  void _conic(int o, int level, bool arc, _Complex? chain) {
    final layer = 'LEVEL_$level';
    double start = 0, sweep = 360;
    var a = 36;
    if (arc) {
      start = i32(o + 36) / 360000;
      final raw = u16(o + 40) * 65536 + u16(o + 42);
      // sign and magnitude, zero meaning a full turn
      sweep = raw == 0 ? 360 : (raw & 0x80000000 != 0 ? -(raw & 0x7FFFFFFF) / 360000 : raw / 360000);
      a = 44;
    }
    final primary = vax(o + a) * scale, secondary = vax(o + a + 8) * scale;
    double rot, cx, cy;
    double? cz;
    if (dim3) {
      rot = _quatRotation(o + a + 16);
      cx = vax(o + a + 32) * scale - ox;
      cy = vax(o + a + 40) * scale - oy;
      cz = vax(o + a + 48) * scale - oz;
    } else {
      rot = i32(o + a + 16) / 360000;
      cx = vax(o + a + 20) * scale - ox;
      cy = vax(o + a + 28) * scale - oy;
    }
    final c = Pt(cx, cy);
    final circular = (primary - secondary).abs() <= 1e-9 * math.max(primary, 1);
    if (chain == null && circular) {
      if (!arc || sweep.abs() >= 360) {
        _add(DxfEntity(type: 'CIRCLE', layer: layer, center: c, radius: primary, elevation: cz, name: _cellName()), level);
      } else {
        final s0 = sweep >= 0 ? start + rot : start + rot + sweep;
        _add(DxfEntity(type: 'ARC', layer: layer, center: c, radius: primary, startAngle: _norm(s0), endAngle: _norm(s0 + sweep.abs()), elevation: cz, name: _cellName()), level);
      }
      return;
    }
    final n = math.max(8, (72 * sweep.abs() / 360).ceil());
    final r = rot * math.pi / 180, cr = math.cos(r), sr = math.sin(r);
    final pts = <Pt>[
      for (var i = 0; i <= n; i++)
        () {
          final t = (start + sweep * i / n) * math.pi / 180;
          final ex = primary * math.cos(t), ey = secondary * math.sin(t);
          return Pt(cx + ex * cr - ey * sr, cy + ex * sr + ey * cr);
        }(),
    ];
    final full = !arc || sweep.abs() >= 360;
    if (chain != null) {
      chain.pts.addAll(pts);
      if (cz != null) chain.zs.addAll(List.filled(pts.length, cz));
      return;
    }
    _add(DxfEntity(type: 'POLYLINE', layer: layer, points: full ? pts.sublist(0, pts.length - 1) : pts, closed: full, elevation: cz, name: _cellName()), level);
  }

  static double _norm(double deg) {
    var d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }

  void _text(int o, int size, int level) {
    final layer = 'LEVEL_$level';
    final heightMult = i32(o + 42);
    double rot;
    Pt at;
    int nChars, textAt;
    if (dim3) {
      rot = _quatRotation(o + 46);
      at = Pt(x(o + 62), y(o + 66));
      nChars = b[o + 74];
      textAt = o + 76;
    } else {
      rot = i32(o + 46) / 360000;
      at = Pt(x(o + 50), y(o + 54));
      nChars = b[o + 58];
      textAt = o + 60;
    }
    final end = math.min(textAt + nChars, o + size);
    if (end <= textAt) return;
    final raw = b.sublist(textAt, end);
    String text;
    if (raw.length >= 2 && raw[0] == 0xFF && raw[1] == 0xFD) {
      // 16-bit text
      final u = <int>[for (var i = 2; i + 1 < raw.length; i += 2) raw[i] | (raw[i + 1] << 8)];
      text = String.fromCharCodes(u.takeWhile((c) => c != 0));
    } else {
      text = latin1.decode(raw.takeWhile((c) => c != 0).toList());
    }
    final height = heightMult * scale * 6 / 1000;
    _add(DxfEntity(type: 'TEXT', layer: layer, points: [at], text: text, height: height > 0 ? height : 1, rotation: rot, name: _cellName()), level);
  }

  /// Three characters of a Radix-50 word.
  static String _rad50(int w) {
    const chars = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ\$.?0123456789';
    final c1 = w ~/ 1600, c2 = (w ~/ 40) % 40, c3 = w % 40;
    String ch(int i) => i < chars.length ? chars[i] : ' ';
    return '${ch(c1)}${ch(c2)}${ch(c3)}';
  }
}
