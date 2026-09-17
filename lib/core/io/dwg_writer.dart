/// Pure-Dart writer for AutoCAD DWG files in the R2000 (AC1015) format.
///
/// Produces a minimal but complete drawing database: the standard control
/// tables (layers, linetypes, text style, viewport, appid, dimension style),
/// the named-object dictionaries with layouts, model and paper space, and the
/// entities of a [DxfDocument] (LINE, LWPOLYLINE, CIRCLE, ARC, POINT, TEXT).
/// The byte layout follows the Open Design Alliance specification; field
/// order and default values were checked against files written by AutoCAD and
/// verified with LibreDWG (`dwgread`, `dwg2dxf`) and with [DwgReader].
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'dxf.dart';

// --------------------------------------------------------------------- bits

/// Bit-level writer (MSB first within each byte), the counterpart of the
/// reader in dwg.dart. Multi-byte integers are split arithmetically so the
/// code also works on the web (32-bit bitwise operations in dart2js).
class _BitWriter {
  final List<int> _data = [];
  int pos = 0; // bits

  int get byteLength => (pos + 7) >> 3;

  void writeBit(int b) {
    final i = pos >> 3;
    while (i >= _data.length) {
      _data.add(0);
    }
    if (b != 0) _data[i] |= 0x80 >> (pos & 7);
    pos++;
  }

  void writeBits(int v, int n) {
    for (var i = n - 1; i >= 0; i--) {
      writeBit((v >> i) & 1);
    }
  }

  void writeB(int b) => writeBit(b);
  void writeBB(int v) => writeBits(v & 3, 2);
  void write4Bits(int v) => writeBits(v & 15, 4);
  void writeRC(int v) => writeBits(v & 0xFF, 8);

  void writeRS(int v) {
    if (v < 0) v += 65536;
    writeRC(v % 256);
    writeRC((v ~/ 256) % 256);
  }

  void writeRSBE(int v) {
    if (v < 0) v += 65536;
    writeRC((v ~/ 256) % 256);
    writeRC(v % 256);
  }

  void writeRL(int v) {
    if (v < 0) v += 4294967296;
    writeRS(v % 65536);
    writeRS((v ~/ 65536) % 65536);
  }

  void writeRLL(int v) {
    writeRL(v % 4294967296);
    writeRL(v ~/ 4294967296);
  }

  void writeRD(double v) {
    final b = ByteData(8)..setFloat64(0, v, Endian.little);
    for (var i = 0; i < 8; i++) {
      writeRC(b.getUint8(i));
    }
  }

  void writeBS(int v) {
    if (v < 0) v += 65536;
    v &= 0xFFFF;
    if (v == 0) {
      writeBB(2);
    } else if (v == 256) {
      writeBB(3);
    } else if (v < 256) {
      writeBB(1);
      writeRC(v);
    } else {
      writeBB(0);
      writeRS(v);
    }
  }

  void writeBL(int v) {
    if (v == 0) {
      writeBB(2);
    } else if (v > 0 && v < 256) {
      writeBB(1);
      writeRC(v);
    } else {
      writeBB(0);
      writeRL(v);
    }
  }

  void writeBD(double v) {
    if (v == 0.0) {
      writeBB(2);
    } else if (v == 1.0) {
      writeBB(1);
    } else {
      writeBB(0);
      writeRD(v);
    }
  }

  void write2RD(Pt p) {
    writeRD(p.x);
    writeRD(p.y);
  }

  void write3BD(double x, double y, double z) {
    writeBD(x);
    writeBD(y);
    writeBD(z);
  }

  /// Double with default: identical → 2 bits, otherwise the full value.
  void writeDD(double v, double def) {
    if (v == def) {
      writeBB(0);
    } else {
      writeBB(3);
      writeRD(v);
    }
  }

  /// Thickness (R2000+): a single bit when zero.
  void writeBT(double v) {
    if (v == 0.0) {
      writeB(1);
    } else {
      writeB(0);
      writeBD(v);
    }
  }

  /// Extrusion (R2000+): a single bit for the default 0,0,1.
  void writeBE() => writeB(1);

  /// Modular short: 15 bits per word, high bit set on all but the last.
  void writeMS(int v) {
    final words = <int>[];
    do {
      words.add(v & 0x7FFF);
      v = v ~/ 32768;
    } while (v > 0);
    for (var i = 0; i < words.length; i++) {
      writeRS(words[i] | (i < words.length - 1 ? 0x8000 : 0));
    }
  }

  /// Modular char, signed (7 bits per byte, sign in bit 6 of the last byte).
  void writeMC(int v) {
    final neg = v < 0;
    var u = v.abs();
    while (true) {
      final b = u & 0x7F;
      u = u ~/ 128;
      if (u == 0 && (b & 0x40) == 0) {
        writeRC(b | (neg ? 0x40 : 0));
        return;
      }
      writeRC(b | 0x80);
      if (u == 0) {
        writeRC(neg ? 0x40 : 0);
        return;
      }
    }
  }

  /// Unsigned modular char.
  void writeUMC(int v) {
    while (true) {
      final b = v & 0x7F;
      v = v ~/ 128;
      if (v == 0) {
        writeRC(b);
        return;
      }
      writeRC(b | 0x80);
    }
  }

  /// Handle reference: code in the high nibble, byte count in the low one,
  /// then the value big-endian (a null handle is the code alone).
  void writeH(int code, int value) {
    if (value == 0) {
      writeRC(code << 4);
      return;
    }
    final bytes = <int>[];
    var v = value;
    while (v > 0) {
      bytes.insert(0, v % 256);
      v = v ~/ 256;
    }
    writeRC((code << 4) | bytes.length);
    for (final b in bytes) {
      writeRC(b);
    }
  }

  /// Text (R2000): length including the terminating NUL, then the bytes.
  void writeTV(String s) {
    final bytes = _cp1252Encode(s);
    if (bytes.isEmpty) {
      writeBS(0);
      return;
    }
    writeBS(bytes.length + 1);
    for (final b in bytes) {
      writeRC(b);
    }
    writeRC(0);
  }

  void writeTimeBLL(int days, int ms) {
    writeBL(days);
    writeBL(ms);
  }

  void writeBytes(List<int> b) {
    for (final x in b) {
      writeRC(x);
    }
  }

  void alignByte() {
    while (pos & 7 != 0) {
      writeBit(0);
    }
  }

  /// Overwrites a zero RL placeholder written earlier at bit [atBit].
  void patchRL(int atBit, int v) {
    final saved = pos;
    pos = atBit;
    writeRL(v);
    pos = saved;
  }

  Uint8List bytes() => Uint8List.fromList(_data.sublist(0, byteLength));
}

List<int> _cp1252Encode(String s) {
  const special = {0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F};
  final out = <int>[];
  for (final r in s.runes) {
    if (r < 0x80 || (r >= 0xA0 && r <= 0xFF)) {
      out.add(r);
    } else {
      out.add(special[r] ?? 0x3F);
    }
  }
  return out;
}

List<int>? _crcTable;

/// CRC-16 (reflected, polynomial 0xA001) as used throughout DWG files.
int dwgCrc16(List<int> d, int start, int end, int seed) {
  var table = _crcTable;
  if (table == null) {
    table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (c >> 1) ^ 0xA001 : c >> 1;
      }
      table[i] = c;
    }
    _crcTable = table;
  }
  var crc = seed;
  for (var i = start; i < end; i++) {
    final al = (d[i] ^ crc) & 0xFF;
    crc = ((crc >> 8) & 0xFF) ^ table[al];
  }
  return crc;
}

// ------------------------------------------------------------------ sentinels

const _sentinelHeaderEnd = [0x95, 0xA0, 0x4E, 0x28, 0x99, 0x82, 0x1A, 0xE5, 0x5E, 0x41, 0xE0, 0x5F, 0x9D, 0x3A, 0x4D, 0x00];
const _sentinelThumbBegin = [0x1F, 0x25, 0x6D, 0x07, 0xD4, 0x36, 0x28, 0x28, 0x9D, 0x57, 0xCA, 0x3F, 0x9D, 0x44, 0x10, 0x2B];
const _sentinelThumbEnd = [0xE0, 0xDA, 0x92, 0xF8, 0x2B, 0xC9, 0xD7, 0xD7, 0x62, 0xA8, 0x35, 0xC0, 0x62, 0xBB, 0xEF, 0xD4];
const _sentinelVarBegin = [0xCF, 0x7B, 0x1F, 0x23, 0xFD, 0xDE, 0x38, 0xA9, 0x5F, 0x7C, 0x68, 0xB8, 0x4E, 0x6D, 0x33, 0x5F];
const _sentinelVarEnd = [0x30, 0x84, 0xE0, 0xDC, 0x02, 0x21, 0xC7, 0x56, 0xA0, 0x83, 0x97, 0x47, 0xB1, 0x92, 0xCC, 0xA0];
const _sentinelClassBegin = [0x8D, 0xA1, 0xC4, 0xB8, 0xC4, 0xA9, 0xF8, 0xC5, 0xC0, 0xDC, 0xF4, 0x5F, 0xE7, 0xCF, 0xB6, 0x8A];
const _sentinelClassEnd = [0x72, 0x5E, 0x3B, 0x47, 0x3B, 0x56, 0x07, 0x3A, 0x3F, 0x23, 0x0B, 0xA0, 0x18, 0x30, 0x49, 0x75];
const _sentinel2ndBegin = [0xD4, 0x7B, 0x21, 0xCE, 0x28, 0x93, 0x9F, 0xBF, 0x53, 0x24, 0x40, 0x09, 0x12, 0x3C, 0xAA, 0x01];
const _sentinel2ndEnd = [0x2B, 0x84, 0xDE, 0x31, 0xD7, 0x6C, 0x60, 0x40, 0xAC, 0xDB, 0xBF, 0xF6, 0xED, 0xC3, 0x55, 0xFE];

// ------------------------------------------------------------------- handles

/// Fixed handles of the database skeleton (AutoCAD uses the same numbers).
class _H {
  static const blockControl = 0x01, layerControl = 0x02, styleControl = 0x03, ltypeControl = 0x05, viewControl = 0x06, ucsControl = 0x07, vportControl = 0x08, appidControl = 0x09, dimstyleControl = 0x0A;
  static const namedDict = 0x0C, groupDict = 0x0D, plotStyleDict = 0x0E, placeholder = 0x0F;
  static const layer0 = 0x10, styleStandard = 0x11, appidAcad = 0x12, ltByBlock = 0x14, ltByLayer = 0x15, ltContinuous = 0x16;
  static const mlineDict = 0x17, mlineStandard = 0x18, plotSettingsDict = 0x19, layoutDict = 0x1A;
  static const modelSpace = 0x1F, modelBlock = 0x20, modelEndblk = 0x21, modelLayout = 0x22;
  static const dimstyle = 0x27, vxControl = 0x2A, vxRecord = 0x2B, vport = 0x2C;
  static const paperSpace = 0x55, paperLayout = 0x56, paperBlock = 0x57, paperEndblk = 0x58;
  static const firstFree = 0x60;
}

class _Obj {
  _Obj(this.handle, this.bytes);
  final int handle;
  final Uint8List bytes;
  int address = 0;
}

// -------------------------------------------------------------------- writer

/// Writes a [DxfDocument] as an AutoCAD 2000 DWG.
class DwgWriter {
  DwgWriter._(this.doc, this.now);
  final DxfDocument doc;
  final DateTime now;

  final List<_Obj> _objects = [];
  final Map<String, int> _layerHandles = {};
  int _nextHandle = _H.firstFree;
  late Bounds _bounds;

  static Uint8List write(DxfDocument doc, {DateTime? now}) => DwgWriter._(doc, now ?? DateTime.now())._build();

  // ---- object framing

  /// Encodes one object: type, bitsize placeholder, own handle, empty EED,
  /// [data], then the handle stream at [bitsize]; framed by the MS size and
  /// followed by the CRC.
  void _add(int handle, int type, void Function(_BitWriter w) data, void Function(_BitWriter w) handles) {
    final w = _BitWriter();
    w.writeBS(type);
    final bsPos = w.pos;
    w.writeRL(0);
    w.writeH(0, handle);
    w.writeBS(0); // no extended entity data
    data(w);
    w.patchRL(bsPos, w.pos);
    handles(w);
    w.alignByte();
    final body = w.bytes();
    final f = _BitWriter();
    f.writeMS(body.length);
    f.writeBytes(body);
    final framed = f.bytes();
    final crc = dwgCrc16(framed, 0, framed.length, 0xC0C1);
    f.writeRS(crc);
    _objects.add(_Obj(handle, f.bytes()));
  }

  static void _tableFlags(_BitWriter w, String name) {
    w.writeTV(name);
    w.writeB(1); // is_xref_ref
    w.writeBS(0); // is_xref_resolved
    w.writeB(0); // is_xref_dep
  }

  /// Control object data: reactor count, then the entry count (BL, or BS for
  /// the tables AutoCAD stores with a short).
  static void _control(_BitWriter w, int entries, {bool short = false}) {
    w.writeBL(0); // num_reactors
    if (short) {
      w.writeBS(entries);
    } else {
      w.writeBL(entries);
    }
  }

  /// Common object handles: owner (soft pointer), reactors, xdictionary.
  static void _objHandles(_BitWriter w, int owner, {List<int> reactors = const [], bool xrefNull = false}) {
    w.writeH(4, owner);
    for (final r in reactors) {
      w.writeH(4, r);
    }
    w.writeH(3, 0);
    if (xrefNull) w.writeH(5, 0); // xref (table records)
  }

  // ---- entities

  static void _entityCommon(_BitWriter w, {int entmode = 2, int color = 256}) {
    w.writeB(0); // preview_exists
    w.writeBB(entmode);
    w.writeBL(0); // num_reactors
    w.writeB(0); // nolinks: prev/next are written
    w.writeBS(color);
    w.writeBD(1.0); // ltype_scale
    w.writeBB(0); // ltype_flags: ByLayer
    w.writeBB(0); // plotstyle_flags: ByLayer
    w.writeBS(0); // invisible
    w.writeRC(29); // lineweight ByLayer
  }

  static void _entityHandles(_BitWriter w, {required int prev, required int next, required int layer}) {
    w.writeH(3, 0); // xdicobjhandle
    w.writeH(4, prev);
    w.writeH(4, next);
    w.writeH(5, layer);
  }

  /// Writes the entity [e]; returns false when it cannot be represented.
  bool _entity(int handle, DxfEntity e, int prev, int next) {
    final layer = _layerHandles[e.layer] ?? _H.layer0;
    final color = e.color >= 1 && e.color <= 255 ? e.color : 256;
    final z = e.elevation ?? 0.0;
    void handles(_BitWriter w) => _entityHandles(w, prev: prev, next: next, layer: layer);
    switch (e.type) {
      case 'LINE':
        if (e.points.length < 2) return false;
        final a = e.points[0], b = e.points[1];
        _add(handle, 19, (w) {
          _entityCommon(w, color: color);
          final zZero = z == 0.0;
          w.writeB(zZero ? 1 : 0);
          w.writeRD(a.x);
          w.writeDD(b.x, a.x);
          w.writeRD(a.y);
          w.writeDD(b.y, a.y);
          if (!zZero) {
            w.writeRD(z);
            w.writeDD(z, z);
          }
          w.writeBT(0);
          w.writeBE();
        }, handles);
        return true;
      case 'POLYLINE':
        if (e.points.length < 2) return false;
        _add(handle, 77, (w) {
          _entityCommon(w, color: color);
          var flag = e.closed ? 512 : 0;
          if (z != 0.0) flag |= 8;
          w.writeBS(flag);
          if (z != 0.0) w.writeBD(z);
          w.writeBL(e.points.length);
          w.write2RD(e.points.first);
          var prevPt = e.points.first;
          for (var i = 1; i < e.points.length; i++) {
            w.writeDD(e.points[i].x, prevPt.x);
            w.writeDD(e.points[i].y, prevPt.y);
            prevPt = e.points[i];
          }
        }, handles);
        return true;
      case 'CIRCLE':
      case 'ARC':
        final c = e.center;
        if (c == null || e.radius <= 0) return false;
        _add(handle, e.type == 'ARC' ? 17 : 18, (w) {
          _entityCommon(w, color: color);
          w.write3BD(c.x, c.y, z);
          w.writeBD(e.radius);
          w.writeBT(0);
          w.writeBE();
          if (e.type == 'ARC') {
            w.writeBD(degToRad(e.startAngle));
            w.writeBD(degToRad(e.endAngle));
          }
        }, handles);
        return true;
      case 'POINT':
        if (e.points.isEmpty) return false;
        final p = e.points.first;
        _add(handle, 27, (w) {
          _entityCommon(w, color: color);
          w.write3BD(p.x, p.y, z);
          w.writeBT(0);
          w.writeBE();
          w.writeBD(0); // x_ang
        }, handles);
        return true;
      case 'TEXT':
        if (e.points.isEmpty || e.text.isEmpty) return false;
        final p = e.points.first;
        final rot = degToRad(e.rotation);
        _add(handle, 1, (w) {
          _entityCommon(w, color: color);
          var flags = 0xFF; // bit set = field absent (default)
          if (z != 0.0) flags &= ~0x01;
          if (rot != 0.0) flags &= ~0x08;
          w.writeRC(flags);
          if (z != 0.0) w.writeRD(z);
          w.write2RD(p);
          w.writeBE();
          w.writeBT(0);
          if (rot != 0.0) w.writeRD(rot);
          w.writeRD(e.height > 0 ? e.height : 1.0);
          w.writeTV(e.text);
        }, (w) {
          handles(w);
          w.writeH(5, _H.styleStandard);
        });
        return true;
      default:
        return false;
    }
  }

  // ---- tables and dictionaries

  void _skeleton(List<String> layerNames, List<int> layerColors, int firstEntity, int lastEntity, int handseed) {
    final layerHandles = layerNames.map((n) => _layerHandles[n]!).toList();
    // control objects
    _add(_H.blockControl, 48, (w) => _control(w, 0), (w) {
      _objHandles(w, 0);
      w.writeH(3, _H.modelSpace);
      w.writeH(3, _H.paperSpace);
    });
    _add(_H.layerControl, 50, (w) => _control(w, layerHandles.length), (w) {
      _objHandles(w, 0);
      for (final h in layerHandles) {
        w.writeH(2, h);
      }
    });
    _add(_H.styleControl, 52, (w) => _control(w, 1), (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.styleStandard);
    });
    _add(_H.ltypeControl, 56, (w) => _control(w, 1, short: true), (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.ltContinuous);
      w.writeH(3, _H.ltByBlock);
      w.writeH(3, _H.ltByLayer);
    });
    _add(_H.viewControl, 60, (w) => _control(w, 0), (w) => _objHandles(w, 0));
    _add(_H.ucsControl, 62, (w) => _control(w, 0, short: true), (w) => _objHandles(w, 0));
    _add(_H.vportControl, 64, (w) => _control(w, 1, short: true), (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.vport);
    });
    _add(_H.appidControl, 66, (w) => _control(w, 1, short: true), (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.appidAcad);
    });
    _add(_H.dimstyleControl, 68, (w) {
      _control(w, 1, short: true);
      w.writeRC(1); // num_morehandles
    }, (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.dimstyle);
      w.writeH(5, _H.dimstyle);
    });
    _add(_H.vxControl, 70, (w) => _control(w, 1, short: true), (w) {
      _objHandles(w, 0);
      w.writeH(2, _H.vxRecord);
    });
    // dictionaries
    void dict(int handle, int owner, List<(String, int)> items, {int type = 42, int? defaultId}) {
      _add(handle, type, (w) {
        w.writeBL(owner == 0 ? 0 : 1); // num_reactors
        w.writeBL(items.length);
        w.writeBS(1); // cloning
        w.writeRC(0); // is_hardowner
        for (final (name, _) in items) {
          w.writeTV(name);
        }
      }, (w) {
        _objHandles(w, owner, reactors: owner == 0 ? const [] : [owner]);
        for (final (_, h) in items) {
          w.writeH(2, h);
        }
        if (defaultId != null) w.writeH(5, defaultId);
      });
    }

    dict(_H.namedDict, 0, [('ACAD_GROUP', _H.groupDict), ('ACAD_LAYOUT', _H.layoutDict), ('ACAD_MLINESTYLE', _H.mlineDict), ('ACAD_PLOTSETTINGS', _H.plotSettingsDict), ('ACAD_PLOTSTYLENAME', _H.plotStyleDict)]);
    dict(_H.groupDict, _H.namedDict, const []);
    dict(_H.plotStyleDict, _H.namedDict, [('Normal', _H.placeholder)], type: 500, defaultId: _H.placeholder);
    _add(_H.placeholder, 501, (w) => w.writeBL(1), (w) => _objHandles(w, _H.plotStyleDict, reactors: [_H.plotStyleDict]));
    dict(_H.mlineDict, _H.namedDict, [('Standard', _H.mlineStandard)]);
    dict(_H.plotSettingsDict, _H.namedDict, const []);
    dict(_H.layoutDict, _H.namedDict, [('Layout1', _H.paperLayout), ('Model', _H.modelLayout)]);
    // layers
    for (var i = 0; i < layerNames.length; i++) {
      _add(layerHandles[i], 51, (w) {
        w.writeBL(0);
        _tableFlags(w, layerNames[i]);
        w.writeBS(0x3F0); // plottable, lineweight default
        w.writeBS(layerColors[i]);
      }, (w) {
        _objHandles(w, _H.layerControl, xrefNull: true);
        w.writeH(5, _H.placeholder); // plotstyle
        w.writeH(5, _H.ltContinuous);
      });
    }
    // text style
    _add(_H.styleStandard, 53, (w) {
      w.writeBL(0);
      _tableFlags(w, 'Standard');
      w.writeB(0); // is_shape
      w.writeB(0); // is_vertical
      w.writeBD(0); // text_size (variable)
      w.writeBD(1); // width_factor
      w.writeBD(0); // oblique
      w.writeRC(0); // generation
      w.writeBD(2.5); // last_height
      w.writeTV('txt');
      w.writeTV('');
    }, (w) => _objHandles(w, _H.styleControl, xrefNull: true));
    // appid
    _add(_H.appidAcad, 67, (w) {
      w.writeBL(0);
      _tableFlags(w, 'ACAD');
      w.writeRC(0);
    }, (w) => _objHandles(w, _H.appidControl, xrefNull: true));
    // linetypes
    for (final (h, name, desc) in [(_H.ltByBlock, 'ByBlock', ''), (_H.ltByLayer, 'ByLayer', ''), (_H.ltContinuous, 'Continuous', 'Solid line')]) {
      _add(h, 57, (w) {
        w.writeBL(0);
        _tableFlags(w, name);
        w.writeTV(desc);
        w.writeBD(0); // pattern_len
        w.writeRC(0x41); // alignment 'A'
        w.writeRC(0); // numdashes
        for (var i = 0; i < 256; i++) {
          w.writeRC(0); // strings_area
        }
      }, (w) => _objHandles(w, _H.ltypeControl, xrefNull: true));
    }
    // multiline style
    _add(_H.mlineStandard, 73, (w) {
      w.writeBL(1);
      w.writeTV('Standard');
      w.writeTV('');
      w.writeBS(0); // flag
      w.writeBS(256); // fill colour
      w.writeBD(math.pi / 2);
      w.writeBD(math.pi / 2);
      w.writeRC(2);
      for (final off in [0.5, -0.5]) {
        w.writeBD(off);
        w.writeBS(256);
        w.writeBS(32767); // linetype index ByLayer
      }
    }, (w) => _objHandles(w, _H.mlineDict, reactors: [_H.mlineDict]));
    // dimension style ISO-25
    _add(_H.dimstyle, 69, (w) {
      w.writeBL(0);
      _tableFlags(w, 'ISO-25');
      w.writeTV(''); // DIMPOST
      w.writeTV(''); // DIMAPOST
      for (final v in [1.0, 2.5, 0.625, 3.75, 1.25, 0.0, 0.0, 0.0, 0.0]) {
        w.writeBD(v); // DIMSCALE ASZ EXO DLI EXE RND DLE TP TM
      }
      for (var i = 0; i < 6; i++) {
        w.writeB(0); // DIMTOL LIM TIH TOH SE1 SE2
      }
      w.writeBS(1); // DIMTAD
      w.writeBS(8); // DIMZIN
      w.writeBS(0); // DIMAZIN
      for (final v in [2.5, 2.5, 0.0, 0.0393701, 1.0, 0.0, 1.0, 0.625, 0.0]) {
        w.writeBD(v); // DIMTXT CEN TSZ ALTF LFAC TVP TFAC GAP ALTRND
      }
      w.writeB(0); // DIMALT
      w.writeBS(3); // DIMALTD
      w.writeB(1); // DIMTOFL
      w.writeB(0); // DIMSAH
      w.writeB(0); // DIMTIX
      w.writeB(0); // DIMSOXD
      w.writeBS(0); // DIMCLRD
      w.writeBS(0); // DIMCLRE
      w.writeBS(0); // DIMCLRT
      for (final v in [0, 2, 2, 2, 3, 0, 0, 2, 44, 0, 0]) {
        w.writeBS(v); // ADEC DEC TDEC ALTU ALTTD AUNIT FRAC LUNIT DSEP TMOVE JUST
      }
      w.writeB(0); // DIMSD1
      w.writeB(0); // DIMSD2
      w.writeBS(0); // DIMTOLJ
      w.writeBS(8); // DIMTZIN
      w.writeBS(0); // DIMALTZ
      w.writeBS(0); // DIMALTTZ
      w.writeB(0); // DIMUPT
      w.writeBS(3); // DIMATFIT
      w.writeBS(-2); // DIMLWD
      w.writeBS(-2); // DIMLWE
      w.writeB(0); // flag0
    }, (w) {
      _objHandles(w, _H.dimstyleControl, xrefNull: true);
      w.writeH(5, _H.styleStandard); // DIMTXSTY
      for (var i = 0; i < 4; i++) {
        w.writeH(5, 0); // DIMLDRBLK DIMBLK DIMBLK1 DIMBLK2
      }
    });
    // viewport table record *Active
    final c = _bounds.center;
    final h = math.max(_bounds.height, 1.0) * 1.1;
    _add(_H.vport, 65, (w) {
      w.writeBL(0);
      _tableFlags(w, '*Active');
      w.writeBD(h); // VIEWSIZE
      w.writeBD(math.max(h * 1.4, _bounds.width * 1.1)); // view width
      w.write2RD(c); // VIEWCTR
      w.write3BD(0, 0, 0); // target
      w.write3BD(0, 0, 1); // VIEWDIR
      w.writeBD(0); // twist
      w.writeBD(50); // lens length
      w.writeBD(0); // front clip
      w.writeBD(0); // back clip
      w.write4Bits(1); // VIEWMODE
      w.writeRC(0); // render_mode
      w.write2RD(const Pt(0, 0)); // lower_left
      w.write2RD(const Pt(1, 1)); // upper_right
      w.writeB(0); // UCSFOLLOW
      w.writeBS(1000); // circle_zoom
      w.writeB(1); // FASTZOOM
      w.writeBB(3); // UCSICON
      w.writeB(0); // GRIDMODE
      w.write2RD(const Pt(10, 10)); // GRIDUNIT
      w.writeB(0); // SNAPMODE
      w.writeB(0); // SNAPSTYLE
      w.writeBS(0); // SNAPISOPAIR
      w.writeBD(0); // SNAPANG
      w.write2RD(const Pt(0, 0)); // SNAPBASE
      w.write2RD(const Pt(10, 10)); // SNAPUNIT
      w.writeB(0); // ucs_at_origin
      w.writeB(1); // UCSVP
      w.write3BD(0, 0, 0); // ucsorg
      w.write3BD(1, 0, 0);
      w.write3BD(0, 1, 0);
      w.writeBD(0); // ucs_elevation
      w.writeBS(0); // UCSORTHOVIEW
    }, (w) {
      _objHandles(w, _H.vportControl, xrefNull: true);
      w.writeH(5, 0); // named_ucs
      w.writeH(5, 0); // base_ucs
    });
    // VX (viewport entity header) record
    _add(_H.vxRecord, 71, (w) {
      w.writeBL(0);
      _tableFlags(w, '1');
      w.writeB(1); // is_on
    }, (w) {
      _objHandles(w, _H.vxControl, xrefNull: true);
      w.writeH(4, 0); // viewport
      w.writeH(5, 0); // prev_entry
    });
    // block headers, BLOCK/ENDBLK and layouts for model and paper space
    void blockHeader(int handle, String name, int block, int endblk, int first, int last, int layout) {
      _add(handle, 49, (w) {
        w.writeBL(0);
        _tableFlags(w, name);
        w.writeB(0); // anonymous
        w.writeB(0); // hasattrs
        w.writeB(0); // blkisxref
        w.writeB(0); // xrefoverlaid
        w.writeB(0); // loaded_bit
        w.write3BD(0, 0, 0); // base_pt
        w.writeTV(''); // xref_pname
        w.writeRC(0); // num_inserts terminator
        w.writeTV(''); // description
        w.writeBL(0); // preview_size
      }, (w) {
        _objHandles(w, _H.blockControl, xrefNull: true);
        w.writeH(3, block);
        w.writeH(4, first);
        w.writeH(4, last);
        w.writeH(3, endblk);
        w.writeH(5, layout);
      });
    }

    blockHeader(_H.modelSpace, '*Model_Space', _H.modelBlock, _H.modelEndblk, firstEntity, lastEntity, _H.modelLayout);
    blockHeader(_H.paperSpace, '*Paper_Space', _H.paperBlock, _H.paperEndblk, 0, 0, _H.paperLayout);
    for (final (block, endblk, name, mode) in [(_H.modelBlock, _H.modelEndblk, '*Model_Space', 2), (_H.paperBlock, _H.paperEndblk, '*Paper_Space', 1)]) {
      _add(block, 4, (w) {
        _entityCommon(w, entmode: mode);
        w.writeTV(name);
      }, (w) => _entityHandles(w, prev: 0, next: 0, layer: _H.layer0));
      _add(endblk, 5, (w) => _entityCommon(w, entmode: mode), (w) => _entityHandles(w, prev: 0, next: 0, layer: _H.layer0));
    }
    void layout(int handle, String name, int tab, int blockHeader, int viewport, {required bool model}) {
      _add(handle, 502, (w) {
        w.writeBL(1); // num_reactors
        w.writeTV(''); // printer_cfg_file
        w.writeTV('none_device'); // paper_size
        w.writeBS(model ? 0x2EB0 : 0x2B0); // plot_flags
        w.writeBD(7.5); // margins
        w.writeBD(20);
        w.writeBD(7.5);
        w.writeBD(20);
        w.writeBD(210); // paper width
        w.writeBD(297); // paper height
        w.writeTV('ISO_A4_(210.00_x_297.00_MM)');
        w.writeBD(0); // plot origin
        w.writeBD(0);
        w.writeBS(1); // plot_paper_unit: mm
        w.writeBS(0); // plot_rotation_mode
        w.writeBS(model ? 0 : 5); // plot_type
        w.writeBD(0); // plot window ll
        w.writeBD(0);
        w.writeBD(0); // plot window ur
        w.writeBD(0);
        w.writeTV(''); // plotview_name
        w.writeBD(1); // paper_units
        w.writeBD(1); // drawing_units
        w.writeTV(''); // stylesheet
        w.writeBS(model ? 0 : 16); // std_scale_type (16 = 1:1)
        w.writeBD(1); // std_scale_factor
        w.writeBD(0); // paper_image_origin
        w.writeBD(0);
        w.writeTV(name);
        w.writeBS(tab);
        w.writeBS(1); // layout_flags
        w.write3BD(0, 0, 0); // INSBASE
        w.write2RD(const Pt(0, 0)); // LIMMIN
        w.write2RD(model ? const Pt(420, 297) : const Pt(210, 297)); // LIMMAX
        w.write3BD(0, 0, 0); // UCSORG
        w.write3BD(1, 0, 0);
        w.write3BD(0, 1, 0);
        w.writeBD(0); // ucs_elevation
        w.writeBS(0); // UCSORTHOVIEW
        if (model) {
          w.write3BD(_bounds.minX, _bounds.minY, 0);
          w.write3BD(_bounds.maxX, _bounds.maxY, 0);
        } else {
          w.write3BD(1e20, 1e20, 1e20);
          w.write3BD(-1e20, -1e20, -1e20);
        }
      }, (w) {
        _objHandles(w, _H.layoutDict, reactors: [_H.layoutDict]);
        w.writeH(4, blockHeader);
        w.writeH(4, viewport);
        w.writeH(5, 0); // base_ucs
        w.writeH(5, 0); // named_ucs
      });
    }

    layout(_H.modelLayout, 'Model', 0, _H.modelSpace, _H.vport, model: true);
    layout(_H.paperLayout, 'Layout1', 1, _H.paperSpace, 0, model: false);
  }

  // ---- sections

  (int, int) _julian(DateTime t) {
    final u = t.toUtc();
    final ms = u.millisecondsSinceEpoch;
    final days = (ms / 86400000).floor() + 2440588; // JD at 0h UTC
    final dayMs = ms - (ms / 86400000).floor() * 86400000;
    return (days, dayMs);
  }

  Uint8List _headerSection(int handseed, int clayer) {
    final w = _BitWriter();
    w.writeBD(412148564080.0);
    w.writeBD(1);
    w.writeBD(1);
    w.writeBD(1);
    w.writeTV('m');
    w.writeTV('');
    w.writeTV('');
    w.writeTV('');
    w.writeBL(0);
    w.writeBL(0);
    w.writeH(5, _H.vxRecord); // VX_TABLE_RECORD
    for (final b in [1, 1, 0, 0, 1, 1, 0, 1, 0]) {
      w.writeB(b); // DIMASO DIMSHO PLINEGEN ORTHOMODE REGENMODE FILLMODE QTEXTMODE PSLTSCALE LIMCHECK
    }
    for (final b in [1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0]) {
      w.writeB(b); // USRTIMER SKPOLY ANGDIR SPLFRAME MIRRTEXT WORLDVIEW TILEMODE PLIMCHECK VISRETAIN DISPSILH PELLIPSE
    }
    w.writeBS(1); // PROXYGRAPHICS
    w.writeBS(3020); // TREEDEPTH
    for (final v in [2, 4, 0, 0, 1, 0]) {
      w.writeBS(v); // LUNITS LUPREC AUNITS AUPREC ATTMODE PDMODE
    }
    for (var i = 0; i < 5; i++) {
      w.writeBS(0); // USERI1..5
    }
    for (final v in [8, 6, 6, 6, 6, 6, 6, 3, 70, 0, 64, 4, 0, 50]) {
      w.writeBS(v); // SPLINESEGS SURFU SURFV SURFTYPE SURFTAB1 SURFTAB2 SPLINETYPE SHADEDGE SHADEDIF UNITMODE MAXACTVP ISOLINES CMLJUST TEXTQLTY
    }
    for (final v in [1.0, 2.5, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]) {
      w.writeBD(v); // LTSCALE TEXTSIZE TRACEWID SKETCHINC FILLETRAD THICKNESS ANGBASE PDSIZE PLINEWID
    }
    for (var i = 0; i < 9; i++) {
      w.writeBD(0); // USERR1..5 CHAMFERA..D
    }
    w.writeBD(0.5); // FACETRES
    w.writeBD(20); // CMLSCALE
    w.writeBD(1); // CELTSCALE
    w.writeTV('.'); // MENU
    final (days, ms) = _julian(now);
    w.writeTimeBLL(days, ms); // TDUCREATE
    w.writeTimeBLL(days, ms); // TDUUPDATE
    w.writeTimeBLL(0, 0); // TDINDWG
    w.writeTimeBLL(0, 0); // TDUSRTIMER
    w.writeBS(256); // CECOLOR
    w.writeH(0, handseed); // HANDSEED
    w.writeH(5, clayer);
    w.writeH(5, _H.styleStandard);
    w.writeH(5, _H.ltByLayer);
    w.writeH(5, _H.dimstyle);
    w.writeH(5, _H.mlineStandard);
    w.writeBD(0); // PSVPSCALE
    w.write3BD(0, 0, 0); // PINSBASE
    w.write3BD(1e20, 1e20, 1e20); // PEXTMIN
    w.write3BD(-1e20, -1e20, -1e20); // PEXTMAX
    w.write2RD(const Pt(0, 0)); // PLIMMIN
    w.write2RD(const Pt(210, 297)); // PLIMMAX
    w.writeBD(0); // PELEVATION
    w.write3BD(0, 0, 0); // PUCSORG
    w.write3BD(1, 0, 0);
    w.write3BD(0, 1, 0);
    w.writeH(5, 0); // PUCSNAME
    w.writeH(5, 0); // PUCSORTHOREF
    w.writeBS(0); // PUCSORTHOVIEW
    w.writeH(5, 0); // PUCSBASE
    for (var i = 0; i < 6; i++) {
      w.write3BD(0, 0, 0); // PUCSORGTOP..BACK
    }
    w.write3BD(0, 0, 0); // INSBASE
    w.write3BD(_bounds.minX, _bounds.minY, 0); // EXTMIN
    w.write3BD(_bounds.maxX, _bounds.maxY, 0); // EXTMAX
    w.write2RD(const Pt(0, 0)); // LIMMIN
    w.write2RD(const Pt(420, 297)); // LIMMAX
    w.writeBD(0); // ELEVATION
    w.write3BD(0, 0, 0); // UCSORG
    w.write3BD(1, 0, 0);
    w.write3BD(0, 1, 0);
    w.writeH(5, 0); // UCSNAME
    w.writeH(5, 0); // UCSORTHOREF
    w.writeBS(0); // UCSORTHOVIEW
    w.writeH(5, 0); // UCSBASE
    for (var i = 0; i < 6; i++) {
      w.write3BD(0, 0, 0); // UCSORGTOP..BACK
    }
    w.writeTV(''); // DIMPOST
    w.writeTV(''); // DIMAPOST
    for (final v in [1.0, 2.5, 0.625, 3.75, 1.25, 0.0, 0.0, 0.0, 0.0]) {
      w.writeBD(v); // DIMSCALE ASZ EXO DLI EXE RND DLE TP TM
    }
    for (var i = 0; i < 6; i++) {
      w.writeB(0); // DIMTOL LIM TIH TOH SE1 SE2
    }
    w.writeBS(1); // DIMTAD
    w.writeBS(8); // DIMZIN
    w.writeBS(0); // DIMAZIN
    for (final v in [2.5, 2.5, 0.0, 0.0393701, 1.0, 0.0, 1.0, 0.625]) {
      w.writeBD(v); // DIMTXT CEN TSZ ALTF LFAC TVP TFAC GAP
    }
    w.writeBD(0); // DIMALTRND
    w.writeB(0); // DIMALT
    w.writeBS(3); // DIMALTD
    w.writeB(1); // DIMTOFL
    w.writeB(0); // DIMSAH
    w.writeB(0); // DIMTIX
    w.writeB(0); // DIMSOXD
    w.writeBS(0); // DIMCLRD
    w.writeBS(0); // DIMCLRE
    w.writeBS(0); // DIMCLRT
    for (final v in [0, 2, 2, 2, 3, 0, 0, 2, 44, 0, 0]) {
      w.writeBS(v); // ADEC DEC TDEC ALTU ALTTD AUNIT FRAC LUNIT DSEP TMOVE JUST
    }
    w.writeB(0); // DIMSD1
    w.writeB(0); // DIMSD2
    w.writeBS(0); // DIMTOLJ
    w.writeBS(8); // DIMTZIN
    w.writeBS(0); // DIMALTZ
    w.writeBS(0); // DIMALTTZ
    w.writeB(0); // DIMUPT
    w.writeBS(3); // DIMATFIT
    w.writeH(5, _H.styleStandard); // DIMTXSTY
    for (var i = 0; i < 4; i++) {
      w.writeH(5, 0); // DIMLDRBLK DIMBLK DIMBLK1 DIMBLK2
    }
    w.writeBS(-2); // DIMLWD
    w.writeBS(-2); // DIMLWE
    for (final h in [_H.blockControl, _H.layerControl, _H.styleControl, _H.ltypeControl, _H.viewControl, _H.ucsControl, _H.vportControl, _H.appidControl, _H.dimstyleControl, _H.vxControl]) {
      w.writeH(3, h);
    }
    w.writeH(5, _H.groupDict);
    w.writeH(5, _H.mlineDict);
    w.writeH(3, _H.namedDict);
    w.writeBS(1); // TSTACKALIGN
    w.writeBS(70); // TSTACKSIZE
    w.writeTV(''); // HYPERLINKBASE
    w.writeTV(''); // STYLESHEET
    w.writeH(5, _H.layoutDict);
    w.writeH(5, _H.plotSettingsDict);
    w.writeH(5, _H.plotStyleDict);
    w.writeBL(0x2A1D); // FLAGS: lineweight ByLayer, EXTNAMES, PSTYLEMODE
    w.writeBS(6); // INSUNITS: metres
    w.writeBS(0); // CEPSNTYPE
    w.writeTV(_guid(0));
    w.writeTV(_guid(1));
    w.writeH(5, _H.paperSpace);
    w.writeH(5, _H.modelSpace);
    w.writeH(5, _H.ltByLayer);
    w.writeH(5, _H.ltByBlock);
    w.writeH(5, _H.ltContinuous);
    for (final v in [33157, 11426, 52689, 40600]) {
      w.writeBS(v); // unknown_54..57 as written by AutoCAD
    }
    w.alignByte();
    return _sectionWithSentinels(_sentinelVarBegin, w.bytes(), _sentinelVarEnd);
  }

  String _guid(int salt) {
    final r = math.Random(now.microsecondsSinceEpoch + salt);
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16).toUpperCase()).join();
    return '{${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}}';
  }

  /// sentinel + RL size + data + CRC(RL+data) + sentinel.
  static Uint8List _sectionWithSentinels(List<int> begin, Uint8List data, List<int> end) {
    final w = _BitWriter();
    w.writeBytes(begin);
    final sizeAt = w.byteLength;
    w.writeRL(data.length);
    w.writeBytes(data);
    final b = w.bytes();
    final crc = dwgCrc16(b, sizeAt, b.length, 0xC0C1);
    w.writeRS(crc);
    w.writeBytes(end);
    return w.bytes();
  }

  Uint8List _classesSection() {
    final w = _BitWriter();
    const classes = [
      (500, 'AcDbDictionaryWithDefault', 'ACDBDICTIONARYWDFLT'),
      (501, 'AcDbPlaceHolder', 'ACDBPLACEHOLDER'),
      (502, 'AcDbLayout', 'LAYOUT'),
      (503, 'AcDbDictionaryVar', 'DICTIONARYVAR'),
    ];
    for (final (num, cpp, dxf) in classes) {
      w.writeBS(num);
      w.writeBS(0); // proxy flags
      w.writeTV('ObjectDBX Classes');
      w.writeTV(cpp);
      w.writeTV(dxf);
      w.writeB(0); // is_zombie
      w.writeBS(0x1F3); // object class
    }
    w.alignByte();
    return _sectionWithSentinels(_sentinelClassBegin, w.bytes(), _sentinelClassEnd);
  }

  Uint8List _auxHeader(int handseed) {
    final w = _BitWriter();
    w.writeBytes(const [0xFF, 0x77, 0x01]);
    w.writeRS(0x17); // dwg_version
    w.writeRS(0x0F); // maint_version
    w.writeRL(1); // numsaves
    w.writeRL(-1);
    w.writeRS(1); // numsaves_1
    w.writeRS(0);
    w.writeRL(0);
    w.writeRS(0x17);
    w.writeRS(0x0F);
    w.writeRS(0x17);
    w.writeRS(0x0F);
    for (final v in [4, 0x565, 0, 0, 2, 1]) {
      w.writeRS(v);
    }
    for (final v in [0, 0, 0, 256, 393218]) {
      w.writeRL(v);
    }
    final (days, ms) = _julian(now);
    w.writeRL(days);
    w.writeRL(ms);
    w.writeRL(days);
    w.writeRL(ms);
    w.writeRL(handseed);
    w.writeRL(0); // plot_stamp
    w.writeRS(0);
    w.writeRS(1); // numsaves_3
    w.writeRL(0);
    w.writeRL(0);
    w.writeRL(0);
    w.writeRL(1); // numsaves_4
    w.writeRL(0);
    w.writeRL(0);
    for (var i = 0; i < 8; i++) {
      w.writeRC(0); // padding to the size AutoCAD writes
    }
    return w.bytes();
  }

  Uint8List _thumbnail() {
    final w = _BitWriter();
    w.writeBytes(_sentinelThumbBegin);
    w.writeRL(5); // overall size
    w.writeRC(0); // no pictures
    w.writeBytes(_sentinelThumbEnd);
    return w.bytes();
  }

  /// Object map: chunks of (handle delta UMC, offset delta MC) with a
  /// big-endian size and CRC each, closed by an empty chunk.
  Uint8List _handlesSection() {
    final sorted = [..._objects]..sort((a, b) => a.handle.compareTo(b.handle));
    final out = _BitWriter();
    var chunk = _BitWriter();
    var lastHandle = 0, lastOffset = 0;
    void flush() {
      final data = chunk.bytes();
      final w = _BitWriter();
      w.writeRSBE(data.length + 2);
      w.writeBytes(data);
      final b = w.bytes();
      w.writeRSBE(dwgCrc16(b, 0, b.length, 0xC0C1));
      out.writeBytes(w.bytes());
      chunk = _BitWriter();
      lastHandle = 0;
      lastOffset = 0;
    }

    for (final o in sorted) {
      chunk.writeUMC(o.handle - lastHandle);
      chunk.writeMC(o.address - lastOffset);
      lastHandle = o.handle;
      lastOffset = o.address;
      if (chunk.byteLength > 2030) flush();
    }
    if (chunk.byteLength > 0) flush();
    final tail = _BitWriter();
    tail.writeRSBE(2);
    final tb = tail.bytes();
    tail.writeRSBE(dwgCrc16(tb, 0, 2, 0xC0C1));
    out.writeBytes(tail.bytes());
    return out.bytes();
  }

  Uint8List _secondHeader(int address, List<(int, int, int)> sections, int handseed) {
    final w = _BitWriter();
    w.writeBytes(_sentinel2ndBegin);
    final sizeAt = w.byteLength;
    w.writeRL(0);
    w.writeBL(address);
    w.writeBytes('AC1015'.codeUnits);
    for (var i = 0; i < 5; i++) {
      w.writeRC(0);
    }
    w.writeRC(0x0F); // is_maint
    w.writeRC(1); // zero_one_or_three
    w.writeBS(0x0F17); // maint << 8 | dwg_version
    w.writeRS(30); // codepage
    w.writeBS(sections.length);
    for (final (nr, addr, size) in sections) {
      w.writeRC(nr);
      w.writeBL(addr);
      w.writeBL(size);
    }
    w.writeBS(14);
    final handles = [handseed, _H.blockControl, _H.layerControl, _H.styleControl, _H.ltypeControl, _H.viewControl, _H.ucsControl, _H.vportControl, _H.appidControl, _H.dimstyleControl, _H.vxControl, _H.namedDict, _H.mlineDict, _H.groupDict];
    for (var i = 0; i < handles.length; i++) {
      final bytes = <int>[];
      var v = handles[i];
      while (v > 0) {
        bytes.insert(0, v % 256);
        v = v ~/ 256;
      }
      w.writeRC(bytes.length);
      w.writeRC(i);
      w.writeBytes(bytes);
    }
    w.alignByte();
    final size = w.byteLength - sizeAt - 4;
    w.patchRL(sizeAt * 8, size);
    final b = w.bytes();
    w.writeRS(dwgCrc16(b, sizeAt, b.length, 0xC0C1));
    w.writeBytes(const [0x21, 0x80, 0xAE, 0x74, 0xD0, 0x43, 0x95, 0x98]); // junk_r14
    w.writeBytes(_sentinel2ndEnd);
    return w.bytes();
  }

  // ---- assembly

  Uint8List _build() {
    // layers: '0' first, then the document's (unique, valid names)
    final names = <String>['0'];
    final colors = <int>[7];
    for (final l in doc.layers) {
      final n = l.name.trim();
      if (n.isEmpty || names.contains(n)) continue;
      names.add(n);
      colors.add(l.color >= 1 && l.color <= 255 ? l.color : 7);
    }
    for (final e in doc.entities) {
      if (!names.contains(e.layer) && e.layer.trim().isNotEmpty) {
        names.add(e.layer);
        colors.add(7);
      }
    }
    _layerHandles['0'] = _H.layer0;
    for (final n in names.skip(1)) {
      _layerHandles[n] = _nextHandle++;
    }
    var b = doc.bounds;
    if (b.isEmpty) b = const Bounds(0, 0, 1, 1);
    _bounds = b;
    // entities: allocate handles first so prev/next links are known
    final writable = doc.entities.where(_representable).toList();
    final handles = [for (var i = 0; i < writable.length; i++) _nextHandle + i];
    _nextHandle += writable.length;
    for (var i = 0; i < writable.length; i++) {
      _entity(handles[i], writable[i], i > 0 ? handles[i - 1] : 0, i + 1 < writable.length ? handles[i + 1] : 0);
    }
    final handseed = _nextHandle + 1;
    _skeleton(names, colors, handles.isEmpty ? 0 : handles.first, handles.isEmpty ? 0 : handles.last, handseed);

    // sections in file order
    final fileHeaderSize = 0x19 + 6 * 9 + 2 + 16;
    final aux = _auxHeader(handseed);
    final thumb = _thumbnail();
    final header = _headerSection(handseed, _H.layer0);
    final classes = _classesSection();
    var at = fileHeaderSize;
    final auxAt = at;
    at += aux.length;
    final thumbAt = at;
    at += thumb.length;
    final headerAt = at;
    at += header.length;
    final classesAt = at;
    at += classes.length + 4; // trailing RL after the classes section
    // objects sorted by handle
    _objects.sort((a, b) => a.handle.compareTo(b.handle));
    for (final o in _objects) {
      o.address = at;
      at += o.bytes.length;
    }
    final handlesAt = at;
    final handlesSec = _handlesSection();
    at += handlesSec.length;
    final secondAt = at;
    final sections = [(0, headerAt, header.length), (1, classesAt, classes.length), (2, handlesAt, handlesSec.length), (3, 0, 0), (4, 0, 0), (5, auxAt, aux.length)];
    final second = _secondHeader(secondAt, sections, handseed);
    at += second.length;
    final templateAt = at;

    final w = _BitWriter();
    w.writeBytes('AC1015'.codeUnits);
    for (var i = 0; i < 5; i++) {
      w.writeRC(0);
    }
    w.writeRC(0x0F); // is_maint
    w.writeRC(1);
    w.writeRL(thumbAt);
    w.writeRC(0x17); // dwg_version
    w.writeRC(0x0F); // maint_version
    w.writeRS(30); // codepage ANSI_1252
    w.writeRL(6);
    for (final (nr, addr, size) in [(0, headerAt, header.length), (1, classesAt, classes.length), (2, handlesAt, handlesSec.length), (3, 0, 0), (4, templateAt, 4), (5, auxAt, aux.length)]) {
      w.writeRC(nr);
      w.writeRL(addr);
      w.writeRL(size);
    }
    final hb = w.bytes();
    w.writeRS(dwgCrc16(hb, 0, hb.length, 0xC0C1));
    w.writeBytes(_sentinelHeaderEnd);
    assert(w.byteLength == fileHeaderSize);
    w.writeBytes(aux);
    w.writeBytes(thumb);
    w.writeBytes(header);
    w.writeBytes(classes);
    w.writeRL(0x0DCA);
    for (final o in _objects) {
      assert(w.byteLength == o.address);
      w.writeBytes(o.bytes);
    }
    w.writeBytes(handlesSec);
    w.writeBytes(second);
    w.writeRS(0); // template: empty description
    w.writeRS(1); // MEASUREMENT metric
    return w.bytes();
  }

  static bool _representable(DxfEntity e) => switch (e.type) {
    'LINE' => e.points.length >= 2,
    'POLYLINE' => e.points.length >= 2,
    'CIRCLE' || 'ARC' => e.center != null && e.radius > 0,
    'POINT' => e.points.isNotEmpty,
    'TEXT' => e.points.isNotEmpty && e.text.isNotEmpty,
    _ => false,
  };
}
