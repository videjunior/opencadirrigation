/// Pure-Dart reader for AutoCAD DWG files (R13/R14/R2000 uncompressed
/// containers, the R2004/R2010–R2018 compressed container and the R2007
/// Reed–Solomon interleaved container). Extracts layers and the entities
/// relevant to an irrigation plan: LINE, CIRCLE, ARC, POINT, TEXT, MTEXT,
/// LWPOLYLINE and 2D POLYLINE, producing a [DxfDocument].
///
/// Based on the Open Design Alliance specification of the DWG format.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'dxf.dart';

class DwgUnsupportedException implements Exception {
  DwgUnsupportedException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class DwgResult {
  DwgResult({required this.document, required this.version, required this.warnings, required this.typeCounts, required this.objectCount, this.debugLog = const []});
  final DxfDocument document;
  final String version;
  final List<String> warnings;
  final Map<String, int> typeCounts;
  final int objectCount;
  final List<String> debugLog;
}

enum DwgVersion { r13, r14, r2000, r2004, r2007, r2010, r2013, r2018 }

class _Eof implements Exception {}

/// Bit-level reader over a byte buffer (MSB first within each byte).
/// All multi-byte integers are assembled arithmetically so the code is safe
/// on the web (dart2js bitwise operations are 32-bit).
class _BitReader {
  _BitReader(this.data, int startByte, int endByte)
      : pos = startByte * 8,
        end = endByte * 8;
  final Uint8List data;
  int pos;
  final int end;

  int get bytePos => pos >> 3;
  bool get eof => pos >= end;

  int readBit() {
    if (pos >= end) throw _Eof();
    final b = data[pos >> 3];
    final bit = (b >> (7 - (pos & 7))) & 1;
    pos++;
    return bit;
  }

  int readBits(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = v * 2 + readBit();
    }
    return v;
  }

  int readByte() {
    if (pos + 8 > end) throw _Eof();
    final i = pos >> 3;
    final s = pos & 7;
    int v;
    if (s == 0) {
      v = data[i];
    } else {
      v = ((data[i] << s) & 0xFF) | (data[i + 1] >> (8 - s));
    }
    pos += 8;
    return v;
  }

  int readRC() => readByte();
  int readRS() => readByte() + readByte() * 256;
  int readRL() => readByte() + readByte() * 256 + readByte() * 65536 + readByte() * 16777216;
  double readRD() {
    final b = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      b[i] = readByte();
    }
    return ByteData.view(b.buffer).getFloat64(0, Endian.little);
  }

  int readBB() => readBits(2);
  int readB() => readBit();
  int read3B() => readBits(3);

  int readBS() {
    switch (readBB()) {
      case 0:
        return readRS();
      case 1:
        return readRC();
      case 2:
        return 0;
      default:
        return 256;
    }
  }

  /// R2010+ object type (BOT): 00 → RC, 01 → RC + 0x1F0, 10 → RS.
  int readBOT() {
    switch (readBB()) {
      case 0:
        return readRC();
      case 1:
        return readRC() + 0x1F0;
      case 2:
        return readRS();
      default:
        return 0;
    }
  }

  int readBL() {
    switch (readBB()) {
      case 0:
        return readRL();
      case 1:
        return readRC();
      default:
        return 0;
    }
  }

  int readBLL() {
    final n = read3B();
    var v = 0;
    var mul = 1;
    for (var i = 0; i < n; i++) {
      v += readByte() * mul;
      mul *= 256;
    }
    return v;
  }

  double readBD() {
    switch (readBB()) {
      case 0:
        return readRD();
      case 1:
        return 1.0;
      default:
        return 0.0;
    }
  }

  double readDD(double def) {
    final code = readBB();
    if (code == 0) return def;
    if (code == 3) return readRD();
    final b = Uint8List(8);
    ByteData.view(b.buffer).setFloat64(0, def, Endian.little);
    if (code == 1) {
      for (var i = 0; i < 4; i++) {
        b[i] = readByte();
      }
    } else {
      b[4] = readByte();
      b[5] = readByte();
      for (var i = 0; i < 4; i++) {
        b[i] = readByte();
      }
    }
    return ByteData.view(b.buffer).getFloat64(0, Endian.little);
  }

  double readBT(DwgVersion v) {
    if (v.index < DwgVersion.r2000.index) return readBD();
    return readB() == 1 ? 0.0 : readBD();
  }

  /// Extrusion direction: whether it is the world −Z (the object
  /// coordinates are mirrored, see [ocsIsMirrored]).
  bool readBE(DwgVersion v) {
    if (v.index >= DwgVersion.r2000.index && readB() == 1) return false; // (0, 0, 1)
    return readExtrusion();
  }

  /// Three BD of an extrusion direction; true when it is the world −Z.
  bool readExtrusion() {
    final x = readBD(), y = readBD(), z = readBD();
    return ocsIsMirrored(x, y, z);
  }

  /// Modular char (signed).
  int readMC() {
    var v = 0;
    var mul = 1;
    for (var i = 0; i < 8; i++) {
      final b = readByte();
      if (b & 0x80 != 0) {
        v += (b & 0x7F) * mul;
        mul *= 128;
      } else {
        v += (b & 0x3F) * mul;
        return (b & 0x40) != 0 ? -v : v;
      }
    }
    return v;
  }

  /// Unsigned modular char.
  int readUMC() {
    var v = 0;
    var mul = 1;
    for (var i = 0; i < 8; i++) {
      final b = readByte();
      v += (b & 0x7F) * mul;
      mul *= 128;
      if (b & 0x80 == 0) return v;
    }
    return v;
  }

  /// Modular short.
  int readMS() {
    var v = 0;
    var mul = 1;
    for (var i = 0; i < 4; i++) {
      final w = readRS();
      v += (w & 0x7FFF) * mul;
      mul *= 32768;
      if (w & 0x8000 == 0) return v;
    }
    return v;
  }

  /// Handle: returns (code, value).
  (int, int) readH() {
    final c = readRC();
    final code = c >> 4;
    final counter = c & 0x0F;
    var v = 0;
    for (var i = 0; i < counter; i++) {
      v = v * 256 + readByte();
    }
    return (code, v);
  }

  /// Text (R13–R2004): length BS then bytes.
  String readTV() {
    final len = readBS();
    if (len <= 0 || len > 4096) return '';
    final b = List<int>.generate(len, (_) => readByte());
    return String.fromCharCodes(b.where((c) => c != 0).map(_cp1252));
  }

  /// Unicode text (R2007+ string stream): length BS then UTF‑16LE units.
  String readTU() {
    final len = readBS();
    if (len <= 0 || len > 4096) return '';
    final units = List<int>.generate(len, (_) => readRS());
    return String.fromCharCodes(units.where((c) => c != 0));
  }

  void skipBytes(int n) {
    pos += n * 8;
    if (pos > end) throw _Eof();
  }

  static int _cp1252(int c) {
    const map = {0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178};
    return map[c] ?? c;
  }
}

class _Layer {
  _Layer(this.name, this.color);
  final String name;
  final int color;
}

class _Entity {
  _Entity({required this.handle, required this.type, required this.layerHandle, this.entmode = 2, this.color = 256, this.owner = 0});
  final int handle;
  final int type;
  final int layerHandle;
  final int entmode;
  final int color;
  final int owner;
  List<Pt> points = const [];
  Pt? center;
  double radius = 0;
  double startAngle = 0;
  double endAngle = 0;
  String text = '';
  double height = 1;
  double rotation = 0;
  bool closed = false;
  double? elevation;
  int firstVertex = 0;
  int lastVertex = 0;
  List<int> ownedVertices = const [];

  /// SPLINE with fit points (the curve passes through [points]).
  bool fitSpline = false;

  /// Planar entity whose extrusion is (0, 0, −1): its object coordinates
  /// are mirrored (see [DxfReader.mirrorOcs]).
  bool ocsMirror = false;

  /// HATCH / SOLID: solid fill, and the island loops of a hatch.
  bool solidFill = false;
  List<List<Pt>> islands = const [];

  /// INSERT / MINSERT: scales, referenced block and array.
  double scaleX = 1;
  double scaleY = 1;
  int blockHandle = 0;
  int cols = 1;
  int rows = 1;
  double colSpacing = 0;
  double rowSpacing = 0;
}

/// A BLOCK_HEADER: name, base point and (per version) the handles of the
/// entities it owns.
class _Block {
  _Block(this.handle, this.name);
  final int handle;
  final String name;
  Pt base = Pt.zero;
  int first = 0;
  int last = 0;
  List<int> owned = const [];
}

class DwgReader {
  DwgReader._(this.file);
  final Uint8List file;

  late DwgVersion ver;
  late Uint8List objData;
  final List<(int, int)> handleMap = [];
  final Map<int, _Layer> _layers = {};
  final Map<int, Pt> _vertices = {};
  final Map<int, double> _vertexZ = {};

  /// Bulge of the segment that starts at a VERTEX_2D (arc segments of a
  /// 2D polyline), by vertex handle; absent when straight.
  final Map<int, double> _vertexBulge = {};
  final Map<int, _Block> _blocks = {};
  final List<_Entity> _entities = [];
  final List<String> warnings = [];
  final List<String> debugLog = [];
  int _modelSpaceHandle = 0;
  final Set<int> _blockHeaders = {};

  /// Debug aid: handle whose parsing is traced into [debugLog].
  static int? traceHandle;
  String _stage = '';
  int _curHandle = 0;
  void _t(int handle, String msg) {
    if (traceHandle == handle) debugLog.add('trace $handle: $msg');
  }
  final Map<String, int> typeCounts = {};
  int objectCount = 0;

  static DwgVersion? versionOf(Uint8List bytes) {
    if (bytes.length < 6) return null;
    final s = String.fromCharCodes(bytes.sublist(0, 6));
    return switch (s) {
      'AC1012' => DwgVersion.r13,
      'AC1014' => DwgVersion.r14,
      'AC1015' => DwgVersion.r2000,
      'AC1018' => DwgVersion.r2004,
      'AC1021' => DwgVersion.r2007,
      'AC1024' => DwgVersion.r2010,
      'AC1027' => DwgVersion.r2013,
      'AC1032' => DwgVersion.r2018,
      _ => null,
    };
  }

  static DwgResult parse(Uint8List bytes) => DwgReader._(bytes)._run();

  DwgResult _run() {
    final v = versionOf(file);
    if (v == null) throw DwgUnsupportedException('notDwg', 'Not a recognised DWG file (version ${String.fromCharCodes(file.take(6))}).');
    ver = v;
    if (ver == DwgVersion.r2007) {
      _readR2007Container();
    } else if (ver.index <= DwgVersion.r2000.index) {
      _readR2000Container();
    } else {
      _readR2004Container();
    }
    _readObjects();
    return _build();
  }

  // ------------------------------------------------------------ containers

  int _rl(Uint8List d, int at) => d[at] + d[at + 1] * 256 + d[at + 2] * 65536 + d[at + 3] * 16777216;

  void _readR2000Container() {
    objData = file;
    final numRecords = _rl(file, 0x15);
    int? handlesSeeker;
    var at = 0x19;
    for (var i = 0; i < numRecords && at + 9 <= file.length; i++) {
      final num = file[at];
      final seeker = _rl(file, at + 1);
      if (num == 2) handlesSeeker = seeker;
      at += 9;
    }
    if (handlesSeeker == null) throw DwgUnsupportedException('corrupt', 'Handles section not found.');
    _parseHandleMap(file, handlesSeeker);
  }

  void _parseHandleMap(Uint8List data, int start) {
    for (final resetPerSection in [false, true]) {
      handleMap.clear();
      var pos = start;
      var lastHandle = 0, lastOffset = 0;
      var ok = true;
      while (pos + 2 <= data.length) {
        final sectionSize = data[pos] * 256 + data[pos + 1];
        if (sectionSize <= 2) break;
        final startPos = pos;
        pos += 2;
        if (resetPerSection) {
          lastHandle = 0;
          lastOffset = 0;
        }
        final endPos = math.min(startPos + sectionSize, data.length);
        final r = _BitReader(data, pos, endPos);
        try {
          while (r.bytePos < endPos) {
            lastHandle += r.readUMC();
            lastOffset += r.readMC();
            handleMap.add((lastHandle, lastOffset));
          }
        } on _Eof {
          ok = false;
        }
        pos = endPos + 2;
      }
      // validate a few entries: object's own handle must match
      var good = 0, bad = 0;
      for (final (h, off) in handleMap.take(40)) {
        if (off < 0 || off >= objData.length - 4) {
          bad++;
          continue;
        }
        try {
          final r = _BitReader(objData, off, objData.length);
          final size = r.readMS();
          if (ver.index >= DwgVersion.r2010.index) r.readUMC();
          final st = r.bytePos;
          final br = _BitReader(objData, st, math.min(st + size + 1, objData.length));
          if (ver.index >= DwgVersion.r2010.index) {
            br.readBOT();
          } else {
            br.readBS();
          }
          if (ver.index >= DwgVersion.r2000.index && ver.index < DwgVersion.r2010.index) br.readRL();
          if (ver.index < DwgVersion.r2000.index) {
            // R13/R14: objects have RL here, entities later; skip validation strictly
          }
          final (_, hv) = br.readH();
          if (hv == h) {
            good++;
          } else {
            bad++;
          }
        } catch (_) {
          bad++;
        }
      }
      if (ok && good >= bad) return;
    }
  }

  // ---- R2004+ compressed container

  Uint8List _decrypt2004Header() {
    final out = Uint8List(0x6C);
    var seed = 1;
    for (var i = 0; i < 0x6C; i++) {
      seed = (seed * 0x343fd + 0x269ec3) % 4294967296;
      out[i] = file[0x80 + i] ^ ((seed ~/ 65536) & 0xFF);
    }
    return out;
  }

  void _readR2004Container() {
    final h = _decrypt2004Header();
    final pageMapId = _rl(h, 0x50);
    final pageMapAddr = _rl(h, 0x54) + _rl(h, 0x58) * 4294967296 + 0x100;
    final sectionMapId = _rl(h, 0x5C);
    debugLog.add('hdr magic=${String.fromCharCodes(h.sublist(0, 11))} pageMapId=$pageMapId pageMapAddr=$pageMapAddr sectionMapId=$sectionMapId pages=${_rl(h, 0x40)} sections=${_rl(h, 0x60)} file=${file.length}');
    // page map
    final pm = _readSystemPage(pageMapAddr, 0x41630e3b);
    final pages = <int, (int, int)>{}; // page number -> (address, size)
    var addr = 0x100;
    var p = 0;
    while (p + 8 <= pm.length) {
      var num = _rl(pm, p);
      final size = _rl(pm, p + 4);
      p += 8;
      if (num >= 2147483648) {
        num -= 4294967296;
        p += 16;
      }
      if (num > 0) pages[num] = (addr, size);
      addr += size;
    }
    debugLog.add('pageMap entries=${pages.length} decompressed=${pm.length} first=${pages.entries.take(5).map((e) => '${e.key}@${e.value.$1}+${e.value.$2}').join(',')}');
    if (!pages.containsKey(sectionMapId)) throw DwgUnsupportedException('corrupt', 'Section map not found (id $sectionMapId, map $pageMapId).');
    final sm = _readSystemPage(pages[sectionMapId]!.$1, 0x4163003b);
    // section descriptions
    final numDesc = _rl(sm, 0);
    var q = 20;
    Uint8List? handles;
    Uint8List? objects;
    for (var i = 0; i < numDesc && q + 108 <= sm.length; i++) {
      final size = _rl(sm, q) + _rl(sm, q + 4) * 4294967296;
      final pageCount = _rl(sm, q + 8);
      final maxDecompressed = _rl(sm, q + 12);
      final compressed = _rl(sm, q + 20);
      final name = String.fromCharCodes(sm.sublist(q + 32, q + 96).takeWhile((c) => c != 0));
      debugLog.add('section "$name" size=$size pages=$pageCount compressed=$compressed');
      q += 96;
      final pageList = <(int, int, int)>[];
      for (var j = 0; j < pageCount && q + 16 <= sm.length; j++) {
        pageList.add((_rl(sm, q), _rl(sm, q + 4), _rl(sm, q + 8) + _rl(sm, q + 12) * 4294967296));
        q += 16;
      }
      if (name == 'AcDb:Handles' || name == 'AcDb:AcDbObjects') {
        final buf = Uint8List(size);
        for (final (pageNum, dataSize, startOffset) in pageList) {
          final page = pages[pageNum];
          if (page == null) {
            warnings.add('page_missing:$pageNum');
            continue;
          }
          final outSize = math.min(maxDecompressed > 0 ? maxDecompressed : size - startOffset, size - startOffset);
          final data = _readDataPage(page.$1, dataSize, compressed == 2, outSize);
          final n = math.min(data.length, size - startOffset);
          if (n > 0) buf.setRange(startOffset, startOffset + n, data);
          debugLog.add('page $pageNum @${page.$1}: dataSize=$dataSize start=$startOffset produced=${data.length} $_lastDecomp');
        }
        if (name == 'AcDb:Handles') handles = buf;
        if (name == 'AcDb:AcDbObjects') objects = buf;
      }
    }
    if (handles == null || objects == null) throw DwgUnsupportedException('corrupt', 'Object sections not found in the DWG.');
    objData = objects;
    _parseHandleMap(handles, 0);
    debugLog.add('handles=${handleMap.length} first=${handleMap.take(5).map((e) => '${e.$1}@${e.$2}').join(',')} objData=${objData.length}');
  }

  Uint8List _readSystemPage(int address, int expectedType) {
    if (address + 20 > file.length) throw DwgUnsupportedException('corrupt', 'System page outside the file.');
    final type = _rl(file, address);
    final decompSize = _rl(file, address + 4);
    final compSize = _rl(file, address + 8);
    final compType = _rl(file, address + 12);
    if (type != expectedType) warnings.add('system_page_type:${type.toRadixString(16)}');
    final src = file.sublist(address + 20, math.min(file.length, address + 20 + compSize));
    if (compType == 2) return _decompress(src, decompSize);
    return src;
  }

  Uint8List _readDataPage(int address, int dataSize, bool compressed, int outSize) {
    final hdr = Uint8List(32);
    // mask = 0x4164536b ^ address, applied per 32-bit word (byte-wise here)
    final maskBytes = [0x6b ^ (address & 0xFF), 0x53 ^ ((address ~/ 256) & 0xFF), 0x64 ^ ((address ~/ 65536) & 0xFF), 0x41 ^ ((address ~/ 16777216) & 0xFF)];
    for (var i = 0; i < 32; i++) {
      hdr[i] = file[address + i] ^ maskBytes[i & 3];
    }
    final pageType = _rl(hdr, 0);
    final compSize = _rl(hdr, 8);
    if (pageType != 0x4163043b) warnings.add('data_page_type:${pageType.toRadixString(16)}');
    final n = compSize > 0 ? compSize : dataSize;
    final src = file.sublist(address + 32, math.min(file.length, address + 32 + n));
    if (compressed) return _decompress(src, outSize);
    return src.length > outSize ? src.sublist(0, outSize) : src;
  }

  String _lastDecomp = '';

  /// R2004 LZ77-style decompression.
  Uint8List _decompress(Uint8List src, int outSize) {
    final dst = Uint8List(outSize);
    var s = 0, d = 0;
    _lastDecomp = '';
    int next() => s < src.length ? src[s++] : 0;
    int literalLength(int first) {
      if (first >= 0x01 && first <= 0x0F) return first + 3;
      var total = 0x0F;
      var b = next();
      while (b == 0 && s < src.length) {
        total += 0xFF;
        b = next();
      }
      return total + b + 3;
    }

    int longLength() {
      var total = 0;
      var b = next();
      while (b == 0 && s < src.length) {
        total += 0xFF;
        b = next();
      }
      return total + b;
    }

    void copyLiteral(int n) {
      for (var i = 0; i < n && d < outSize && s < src.length; i++) {
        dst[d++] = src[s++];
      }
    }

    var opcode = next();
    if ((opcode & 0xF0) == 0) {
      copyLiteral(literalLength(opcode));
      opcode = next();
    }
    while (s <= src.length && d < outSize) {
      int compBytes, compOffset, lit;
      if (opcode == 0x10) {
        compBytes = longLength() + 9;
        final b1 = next(), b2 = next();
        compOffset = ((b1 >> 2) | (b2 << 6)) + 0x3FFF;
        lit = b1 & 3;
      } else if (opcode >= 0x12 && opcode <= 0x1F) {
        compBytes = (opcode & 0x0F) + 2;
        final b1 = next(), b2 = next();
        compOffset = ((b1 >> 2) | (b2 << 6)) + 0x3FFF;
        lit = b1 & 3;
      } else if (opcode == 0x20) {
        compBytes = longLength() + 0x21;
        final b1 = next(), b2 = next();
        compOffset = (b1 >> 2) | (b2 << 6);
        lit = b1 & 3;
      } else if (opcode >= 0x21 && opcode <= 0x3F) {
        compBytes = opcode - 0x1E;
        final b1 = next(), b2 = next();
        compOffset = (b1 >> 2) | (b2 << 6);
        lit = b1 & 3;
      } else if (opcode >= 0x40) {
        compBytes = ((opcode & 0xF0) >> 4) - 1;
        final b1 = next();
        compOffset = (b1 << 2) | ((opcode & 0x0C) >> 2);
        lit = opcode & 3;
      } else if (opcode == 0x11) {
        break;
      } else {
        warnings.add('decompress_opcode:$opcode');
        break;
      }
      for (var i = 0; i < compBytes && d < outSize; i++) {
        final from = d - compOffset - 1;
        dst[d] = from >= 0 ? dst[from] : 0;
        d++;
      }
      if (lit == 0) {
        final b = next();
        if (b < 0x10) {
          copyLiteral(literalLength(b));
          opcode = next();
        } else {
          opcode = b;
        }
      } else {
        copyLiteral(lit);
        opcode = next();
      }
      if (s >= src.length) break;
    }
    _lastDecomp = 'decomp: in=${src.length} used=$s out=$outSize written=$d lastOp=${opcode.toRadixString(16)}';
    return dst;
  }


  // ---- R2007 container: pages are Reed–Solomon interleaved (the parity
  // bytes are ignored, only the de-interleave matters) and compressed with a
  // variant of the 2004 scheme that reverses byte runs.

  void _readR2007Container() {
    if (file.length < 0x480) throw DwgUnsupportedException('corrupt', 'File too short for an R2007 header.');
    final pedata = _rsDeinterleave(file, 0x80, 3, 239);
    final comprLen = _rl(pedata, 24);
    Uint8List hdr;
    if (comprLen > 0 && comprLen < 0x80000000) {
      hdr = _decompress2007(Uint8List.sublistView(pedata, 32, math.min(pedata.length, 32 + comprLen)), 0x110);
    } else {
      hdr = Uint8List.sublistView(pedata, 32, 32 + 0x110);
    }
    int f(int i) => _rl(hdr, i * 8) + _rl(hdr, i * 8 + 4) * 4294967296;
    final pagesMapCorrection = f(3), pagesMapOffset = f(7), pagesMapSizeComp = f(10), pagesMapSizeUncomp = f(11);
    final sectionsMapSizeComp = f(22), sectionsMapId = f(24), sectionsMapSizeUncomp = f(25), sectionsMapCorrection = f(27);
    debugLog.add('r2007 hdr size=${f(0)} file=${f(1)} pagesMap@${0x480 + pagesMapOffset} comp=$pagesMapSizeComp uncomp=$pagesMapSizeUncomp corr=$pagesMapCorrection sectionsMapId=$sectionsMapId comp=$sectionsMapSizeComp uncomp=$sectionsMapSizeUncomp sections=${f(20)}');
    if (pagesMapSizeUncomp <= 0 || pagesMapSizeUncomp > file.length || sectionsMapSizeUncomp <= 0 || sectionsMapSizeUncomp > file.length) {
      throw DwgUnsupportedException('corrupt', 'R2007 file header is damaged.');
    }
    // pages map: (size, id) pairs; page offsets accumulate from 0x480
    final pm = _readSystemPage2007(0x480 + pagesMapOffset, pagesMapSizeComp, pagesMapSizeUncomp, pagesMapCorrection);
    final pages = <int, (int, int)>{}; // id -> (offset, size)
    var offset = 0x480;
    var p = 0;
    while (p + 16 <= pm.length) {
      final size = _rl(pm, p) + _rl(pm, p + 4) * 4294967296;
      final idLo = _rl(pm, p + 8), idHi = _rl(pm, p + 12);
      if (idHi < 0x80000000) pages[idLo + idHi * 4294967296] = (offset, size); // negative ids are free pages
      offset += size;
      p += 16;
    }
    final smPage = pages[sectionsMapId];
    if (smPage == null) throw DwgUnsupportedException('corrupt', 'Section map page $sectionsMapId not found.');
    final sm = _readSystemPage2007(smPage.$1, sectionsMapSizeComp, sectionsMapSizeUncomp, sectionsMapCorrection);
    int f8(int at) => _rl(sm, at) + _rl(sm, at + 4) * 4294967296;
    Uint8List? handles;
    Uint8List? objects;
    var q = 0;
    while (q + 64 <= sm.length) {
      final dataSize = f8(q);
      final nameLength = f8(q + 32);
      final numPages = f8(q + 56);
      q += 64;
      if (q >= sm.length) break;
      final nl = nameLength.isOdd ? nameLength + 1 : nameLength;
      final units = <int>[];
      for (var i = 0; i + 1 < nl && q + i + 1 < sm.length; i += 2) {
        final u = sm[q + i] + sm[q + i + 1] * 256;
        if (u == 0) break;
        units.add(u);
      }
      final name = String.fromCharCodes(units);
      q += nl;
      final pageList = <(int, int, int, int)>[]; // offset, id, uncomp, comp
      for (var i = 0; i < numPages && q + 56 <= sm.length; i++) {
        pageList.add((f8(q), f8(q + 16), f8(q + 24), f8(q + 32)));
        q += 56;
      }
      debugLog.add('section "$name" size=$dataSize pages=${pageList.length}');
      if (name != 'AcDb:Handles' && name != 'AcDb:AcDbObjects') continue;
      if (dataSize <= 0 || dataSize > 512 * 1024 * 1024) throw DwgUnsupportedException('corrupt', 'Section $name has an invalid size.');
      final buf = Uint8List(dataSize);
      for (final (off, id, uncomp, comp) in pageList) {
        final pg = pages[id];
        if (pg == null || off < 0 || off >= dataSize) {
          warnings.add('page_missing:$id');
          continue;
        }
        Uint8List data;
        if (comp != uncomp) {
          data = _readDataPage2007(pg.$1, pg.$2, comp, uncomp);
        } else {
          final end = math.min(file.length, pg.$1 + uncomp);
          data = Uint8List.sublistView(file, math.min(pg.$1, file.length), end);
        }
        final n = math.min(data.length, dataSize - off);
        if (n > 0) buf.setRange(off, off + n, data);
      }
      if (name == 'AcDb:Handles') handles = buf;
      if (name == 'AcDb:AcDbObjects') objects = buf;
    }
    if (handles == null || objects == null) throw DwgUnsupportedException('corrupt', 'Object sections not found in the DWG.');
    objData = objects;
    _parseHandleMap(handles, 0);
    debugLog.add('handles=${handleMap.length} objData=${objData.length}');
  }

  /// Undoes the Reed–Solomon interleave: block i, byte j sits at
  /// src[j * blockCount + i]. Parity bytes are discarded.
  Uint8List _rsDeinterleave(Uint8List src, int start, int blockCount, int dataSize) {
    final dst = Uint8List(blockCount * dataSize);
    for (var i = 0; i < blockCount; i++) {
      for (var j = 0; j < dataSize; j++) {
        final s = start + j * blockCount + i;
        dst[i * dataSize + j] = s < src.length ? src[s] : 0;
      }
    }
    return dst;
  }

  /// System page (pages/sections map): 239-byte RS blocks, repeated
  /// [repeat] times, then decompressed when the compressed size is smaller.
  Uint8List _readSystemPage2007(int address, int sizeComp, int sizeUncomp, int repeat) {
    final pesize = ((sizeComp + 7) & ~7) * math.max(1, repeat);
    final blockCount = (pesize + 238) ~/ 239;
    final pedata = _rsDeinterleave(file, address, blockCount, 239);
    if (sizeComp < sizeUncomp) return _decompress2007(Uint8List.sublistView(pedata, 0, math.min(pedata.length, sizeComp)), sizeUncomp);
    return Uint8List.sublistView(pedata, 0, math.min(pedata.length, sizeUncomp));
  }

  /// Data page: 251-byte RS blocks.
  Uint8List _readDataPage2007(int address, int pageSize, int sizeComp, int sizeUncomp) {
    final pesize = (sizeComp + 7) & ~7;
    final blockCount = (pesize + 0xFA) ~/ 0xFB;
    final pedata = _rsDeinterleave(file, address, blockCount, 0xFB);
    if (sizeComp < sizeUncomp) return _decompress2007(Uint8List.sublistView(pedata, 0, math.min(pedata.length, sizeComp)), sizeUncomp);
    return Uint8List.sublistView(pedata, 0, math.min(pedata.length, sizeUncomp));
  }

  /// R2007 decompression (ODA spec 5.0 §4.7): literal runs are stored with
  /// their byte order shuffled in 8-byte words; back-references as in 2004.
  Uint8List _decompress2007(Uint8List src, int dstSize) {
    final dst = Uint8List(dstSize);
    final n = src.length;
    var d = 0, s = 0, length = 0, offset = 0;
    if (n < 2 || dstSize == 0) return dst;
    int next() => s < n ? src[s++] : 0;
    var opcode = next();
    if ((opcode & 0xF0) == 0x20) {
      s += 2;
      length = next() & 7;
      if (length == 0) {
        warnings.add('decompress2007_start');
        return dst;
      }
    }
    int literalLength(int op) {
      var len = op + 8;
      if (len == 0x17) {
        var b = next();
        len += b;
        if (b == 0xFF) {
          do {
            b = next();
            b |= next() << 8;
            len += b;
          } while (b == 0xFFFF && s < n);
        }
      }
      return len;
    }

    void instructions() {
      switch (opcode >> 4) {
        case 0:
          length = (opcode & 0xF) + 0x13;
          offset = next();
          opcode = next();
          length = ((opcode >> 3) & 0x10) + length;
          offset = ((opcode & 0x78) << 5) + 1 + offset;
        case 1:
          length = (opcode & 0xF) + 3;
          offset = next();
          opcode = next();
          offset = ((opcode & 0xF8) << 5) + 1 + offset;
        case 2:
          offset = next();
          offset = ((next() << 8) & 0xFF00) | offset;
          length = opcode & 7;
          if ((opcode & 8) == 0) {
            opcode = next();
            length = (opcode & 0xF8) + length;
          } else {
            offset++;
            length = (next() << 3) + length;
            opcode = next();
            length = (((opcode & 0xF8) << 8) + length) + 0x100;
          }
        default:
          length = opcode >> 4;
          offset = opcode & 15;
          opcode = next();
          offset = (((opcode & 0xF8) << 1) + offset) + 1;
      }
    }

    while (s < n) {
      if (length == 0) length = literalLength(opcode);
      if (d + length > dstSize || s + length > n) {
        warnings.add('decompress2007_bounds');
        break;
      }
      _copyLiteral2007(dst, d, src, s, length);
      d += length;
      s += length;
      length = 0;
      if (s >= n) break;
      opcode = next();
      instructions();
      while (true) {
        if (d + length > dstSize || offset > d) {
          warnings.add('decompress2007_backref');
          return dst;
        }
        for (var i = 0; i < length; i++) {
          dst[d + i] = dst[d + i - offset];
        }
        d += length;
        length = opcode & 7;
        if (length != 0 || s >= n) break;
        opcode = next();
        if ((opcode >> 4) == 0) break;
        if ((opcode >> 4) == 0x0F) opcode &= 0xF;
        instructions();
      }
    }
    return dst;
  }

  /// Literal run copy with the R2007 byte shuffling (8-byte words reversed
  /// within 32-byte groups, with a fixed pattern for the tail).
  static void _copyLiteral2007(Uint8List dst, int d, Uint8List src, int s, int length) {
    void c1(int off) {
      dst[d++] = src[s + off];
    }

    void c2(int off) {
      dst[d] = src[s + off + 1];
      dst[d + 1] = src[s + off];
      d += 2;
    }

    void c3(int off) {
      dst[d] = src[s + off + 2];
      dst[d + 1] = src[s + off + 1];
      dst[d + 2] = src[s + off];
      d += 3;
    }

    void cn(int k, int off) {
      for (var i = 0; i < k; i++) {
        dst[d + i] = src[s + off + i];
      }
      d += k;
    }

    void c16(int off) {
      for (var i = 0; i < 8; i++) {
        dst[d + i] = src[s + off + 8 + i];
        dst[d + 8 + i] = src[s + off + i];
      }
      d += 16;
    }

    while (length >= 32) {
      c16(16);
      c16(0);
      s += 32;
      length -= 32;
    }
    switch (length) {
      case 1:
        c1(0);
      case 2:
        c2(0);
      case 3:
        c3(0);
      case 4:
        cn(4, 0);
      case 5:
        c1(4);
        cn(4, 0);
      case 6:
        c1(5);
        cn(4, 1);
        c1(0);
      case 7:
        c2(5);
        cn(4, 1);
        c1(0);
      case 8:
        cn(8, 0);
      case 9:
        c1(8);
        cn(8, 0);
      case 10:
        c1(9);
        cn(8, 1);
        c1(0);
      case 11:
        c2(9);
        cn(8, 1);
        c1(0);
      case 12:
        cn(4, 8);
        cn(8, 0);
      case 13:
        c1(12);
        cn(4, 8);
        cn(8, 0);
      case 14:
        c1(13);
        cn(4, 9);
        cn(8, 1);
        c1(0);
      case 15:
        c2(13);
        cn(4, 9);
        cn(8, 1);
        c1(0);
      case 16:
        c16(0);
      case 17:
        cn(8, 9);
        c1(8);
        cn(8, 0);
      case 18:
        c1(17);
        c16(1);
        c1(0);
      case 19:
        c3(16);
        c16(0);
      case 20:
        cn(4, 16);
        c16(0);
      case 21:
        c1(20);
        cn(4, 16);
        c16(0);
      case 22:
        c2(20);
        cn(4, 16);
        c16(0);
      case 23:
        c3(20);
        cn(4, 16);
        c16(0);
      case 24:
        cn(8, 16);
        c16(0);
      case 25:
        cn(8, 17);
        c1(16);
        c16(0);
      case 26:
        c1(25);
        cn(8, 17);
        c1(16);
        c16(0);
      case 27:
        c2(25);
        cn(8, 17);
        c1(16);
        c16(0);
      case 28:
        cn(4, 24);
        cn(8, 16);
        c16(0);
      case 29:
        c1(28);
        cn(4, 24);
        cn(8, 16);
        c16(0);
      case 30:
        c2(28);
        cn(4, 24);
        cn(8, 16);
        c16(0);
      case 31:
        c1(30);
        cn(4, 26);
        cn(8, 18);
        c16(2);
        c2(0);
      default:
        break;
    }
  }

  // ------------------------------------------------------------ objects

  static bool _isEntity(int type) => (type >= 1 && type <= 47 && type != 42) || type == 74 || type == 77 || type == 78;

  void _readObjects() {
    for (final (h, off) in handleMap) {
      if (off < 0 || off >= objData.length - 2) continue;
      _stage = 'start';
      try {
        _readObject(h, off);
        objectCount++;
      } on _Eof {
        warnings.add('eof_in_object:$h@$_stage');
      } catch (e) {
        warnings.add('object_error:$h@$_stage:$e');
      }
    }
  }

  void _readObject(int handle, int offset) {
    _curHandle = handle;
    final r = _BitReader(objData, offset, objData.length);
    final size = r.readMS();
    var start = r.bytePos;
    int handleStreamSize = 0;
    if (ver.index >= DwgVersion.r2010.index) {
      // R2010+: the handle-stream size (UMC) precedes the object data and is
      // not counted in the object size.
      handleStreamSize = r.readUMC();
      start = r.bytePos;
    }
    _t(handle, 'offset=$offset size=$size start=$start bytes=${objData.sublist(start, math.min(start + 10, objData.length)).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    final endByte = math.min(start + size, objData.length);
    final br = _BitReader(objData, start, endByte + 1 <= objData.length ? endByte + 1 : endByte);
    _stage = 'type';
    final type = ver.index >= DwgVersion.r2010.index ? br.readBOT() : br.readBS();
    typeCounts['$type'] = (typeCounts['$type'] ?? 0) + 1;
    _t(handle, 'type=$type hsSize=$handleStreamSize');
    final entity = _isEntity(type);
    int bitsize; // relative to start, position of handle stream
    if (ver.index >= DwgVersion.r2010.index) {
      bitsize = size * 8 - handleStreamSize;
    } else if (ver.index >= DwgVersion.r2000.index) {
      bitsize = br.readRL();
    } else {
      bitsize = 0; // R13/R14: after the handle and EED (objects) or the graphics (entities)
    }
    final interesting = type == 51 || type == 49 || type == 7 || type == 8 || (type >= 20 && type <= 26) || type == 1 || type == 10 || type == 11 || type == 15 || type == 16 || type == 17 || type == 18 || type == 19 || type == 27 || type == 44 || type == 77 || type == 31 || type == 32 || type == 35 || type == 36 || type == 78;
    _t(handle, 'bitsize=$bitsize');
    if (!interesting) return;
    _stage = 'handle';
    final (_, ownHandle) = br.readH();
    if (ownHandle != handle) warnings.add('handle_mismatch:$handle:$ownHandle');
    _stage = 'eed';
    // EED
    for (var guard = 0; guard < 200; guard++) {
      final sz = br.readBS();
      if (sz == 0) break;
      br.readH();
      br.skipBytes(sz);
    }
    if (ver.index < DwgVersion.r2000.index && !entity) bitsize = br.readRL();
    _BitReader? strings;
    if (ver.index >= DwgVersion.r2007.index && bitsize > 17) {
      strings = _stringStream(start, bitsize);
    }
    _t(handle, 'after eed pos=${br.pos - start * 8} strings=${strings != null}');
    _stage = 'body$type';
    if (entity) {
      _readEntity(br, strings, handle, type, start, bitsize, size);
    } else if (type == 51) {
      _readLayer(br, strings, handle);
    } else if (type == 49) {
      _readBlockHeader(br, strings, handle, start, bitsize);
    }
  }

  void _readBlockHeader(_BitReader br, _BitReader? strings, int handle, int start, int bitsize) {
    final numReactors = br.readBL();
    var xdicMissing = false;
    if (ver.index >= DwgVersion.r2004.index) xdicMissing = br.readB() == 1;
    if (ver.index >= DwgVersion.r2013.index) br.readB();
    final name = strings != null ? strings.readTU() : br.readTV();
    _blockHeaders.add(handle);
    if (name.toLowerCase() == '*model_space') _modelSpaceHandle = handle;
    final block = _Block(handle, name);
    _blocks[handle] = block;
    // base point and entity handles, needed to draw INSERTs of this block
    try {
      _readTableXrefFlags(br);
      br.readB(); // anonymous
      br.readB(); // has attribute definitions
      final isXref = br.readB() == 1;
      final isOverlaid = br.readB() == 1;
      if (ver.index >= DwgVersion.r2000.index) br.readB(); // loaded
      var numOwned = 0;
      if (ver.index >= DwgVersion.r2004.index) numOwned = br.readBL();
      block.base = Pt(br.readBD(), br.readBD());
      br.readBD();
      // handle stream: block control, reactors, xdic, null, BLOCK entity, then the entities
      final hr = _BitReader(objData, start, objData.length);
      hr.pos = start * 8 + bitsize;
      hr.readH();
      for (var i = 0; i < numReactors && i < 10000; i++) {
        hr.readH();
      }
      if (!xdicMissing) hr.readH();
      hr.readH();
      hr.readH();
      if (ver.index < DwgVersion.r2004.index) {
        if (!isXref && !isOverlaid) {
          block.first = _absHandle(hr.readH(), handle);
          block.last = _absHandle(hr.readH(), handle);
        }
      } else {
        block.owned = [for (var i = 0; i < numOwned && i < 1000000; i++) _absHandle(hr.readH(), handle)];
      }
    } catch (_) {
      // without the entity list the block's references are skipped
    }
  }

  _BitReader? _stringStream(int start, int bitsize) {
    try {
      final probe = _BitReader(objData, start, objData.length);
      probe.pos = start * 8 + bitsize - 1;
      final flag = probe.readBit();
      _t(_curHandle, 'strstream flag=$flag at bit ${bitsize - 1}');
      if (flag == 0) return null;
      probe.pos = start * 8 + bitsize - 1 - 16;
      var dataSize = probe.readRS();
      var back = 16;
      if (dataSize & 0x8000 != 0) {
        probe.pos = start * 8 + bitsize - 1 - 32;
        final hi = probe.readRS();
        dataSize = (dataSize & 0x7FFF) + hi * 32768;
        back = 32;
      }
      final strStart = bitsize - 1 - back - dataSize;
      _t(_curHandle, 'strstream dataSize=$dataSize back=$back strStart=$strStart');
      if (strStart < 0) return null;
      final sr = _BitReader(objData, start, objData.length);
      sr.pos = start * 8 + strStart;
      return sr;
    } catch (_) {
      return null;
    }
  }

  void _readLayer(_BitReader br, _BitReader? strings, int handle) {
    br.readBL(); // numreactors
    if (ver.index >= DwgVersion.r2004.index) br.readB(); // xdic missing
    if (ver.index >= DwgVersion.r2013.index) br.readB(); // ds binary data
    final name = strings != null ? strings.readTU() : br.readTV();
    _t(handle, 'layer name="$name" datapos=${br.pos - (br.pos >> 3 << 3)}');
    _readTableXrefFlags(br);
    if (ver.index >= DwgVersion.r2000.index) {
      br.readBS(); // flags
    } else {
      br.readB();
      br.readB();
      br.readB();
      br.readB();
    }
    final color = _readCMC(br);
    _layers[handle] = _Layer(name.isEmpty ? '0' : name, color);
  }

  /// Xref flags of a table entry after its name: R13–R2004 store the
  /// "xref referenced" bit, the xref index and the "xref dependent" bit;
  /// R2007+ only the index (the xref itself is a handle).
  void _readTableXrefFlags(_BitReader br) {
    if (ver.index < DwgVersion.r2007.index) {
      br.readB(); // xref referenced (64)
      br.readBS(); // xref index + 1
      br.readB(); // xref dependent
    } else {
      br.readBS(); // xref index + 1
    }
  }

  int _readCMC(_BitReader br) {
    final index = br.readBS();
    if (ver.index >= DwgVersion.r2004.index) {
      br.readBL(); // rgb
      final flags = br.readRC();
      if (ver.index < DwgVersion.r2007.index) {
        if (flags & 1 != 0) br.readTV();
        if (flags & 2 != 0) br.readTV();
      }
    }
    return index;
  }

  int _readENC(_BitReader br) {
    if (ver.index < DwgVersion.r2004.index) return br.readBS();
    final flags = br.readBS();
    if (flags & 0x2000 != 0) br.readBL();
    if (flags & 0x4000 != 0 && ver.index < DwgVersion.r2007.index) br.readTV();
    if (flags & 0x8000 != 0) br.readBL();
    return flags & 0x1FF;
  }

  void _readEntity(_BitReader br, _BitReader? strings, int handle, int type, int start, int bitsize, int size) {
    // graphics
    if (br.readB() == 1) {
      final gsize = ver.index >= DwgVersion.r2010.index ? br.readBLL() : br.readRL();
      _t(handle, 'graphics size=$gsize');
      br.skipBytes(gsize);
    }
    if (ver.index < DwgVersion.r2000.index) {
      bitsize = br.readRL();
    }
    final entmode = br.readBB();
    final numReactors = br.readBL();
    var xdicMissing = false;
    if (ver.index >= DwgVersion.r2004.index) xdicMissing = br.readB() == 1;
    if (ver.index >= DwgVersion.r2013.index) br.readB();
    var isByLayerLt = true;
    if (ver.index < DwgVersion.r2000.index) isByLayerLt = br.readB() == 1;
    var noLinks = true;
    if (ver.index < DwgVersion.r2004.index) noLinks = br.readB() == 1;
    final color = _readENC(br);
    br.readBD(); // ltype scale
    var ltFlags = 0, psFlags = 0, matFlags = 0;
    if (ver.index >= DwgVersion.r2000.index) {
      ltFlags = br.readBB();
      psFlags = br.readBB();
    }
    if (ver.index >= DwgVersion.r2007.index) {
      matFlags = br.readBB();
      br.readRC(); // shadow flags
    }
    var vsFull = 0, vsFace = 0, vsEdge = 0;
    if (ver.index >= DwgVersion.r2010.index) {
      vsFull = br.readB();
      vsFace = br.readB();
      vsEdge = br.readB();
    }
    final invis = br.readBS(); // invisibility
    var lw = 0;
    if (ver.index >= DwgVersion.r2000.index) lw = br.readRC(); // lineweight
    _t(handle, 'entmode=$entmode reactors=$numReactors xdicMissing=$xdicMissing noLinks=$noLinks color=$color ltFlags=$ltFlags psFlags=$psFlags matFlags=$matFlags invis=$invis lw=$lw pos=${br.pos - start * 8}');
    if (traceHandle == handle) {
      final tail = objData.sublist(math.max(start, start + size - 8), math.min(objData.length, start + size + 2));
      _t(handle, 'tail bytes=${tail.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} size=$size bitsize=$bitsize');
    }

    // handles: locate stream
    final hr = _BitReader(objData, start, objData.length);
    hr.pos = start * 8 + bitsize;
    int layerHandle = 0;
    int owner = 0;
    List<int> ownedVertices = const [];
    int firstVertex = 0, lastVertex = 0;
    void readCommonHandles() {
      _t(handle, 'handles start pos=${hr.pos - start * 8} bitsize=$bitsize');
      if (entmode == 0) owner = _absHandle(hr.readH(), handle);
      for (var i = 0; i < numReactors && i < 10000; i++) {
        hr.readH();
      }
      if (!xdicMissing) hr.readH();
      if (ver.index < DwgVersion.r2004.index && !noLinks) {
        hr.readH();
        hr.readH();
      }
      final lh = hr.readH();
      layerHandle = lh.$2;
      _t(handle, 'layer handle code=${lh.$1} value=${lh.$2} pos=${hr.pos - start * 8}');
      if (ver.index < DwgVersion.r2000.index) {
        if (!isByLayerLt) hr.readH();
      } else {
        if (ltFlags == 3) hr.readH();
        if (psFlags == 3) hr.readH();
      }
      if (ver.index >= DwgVersion.r2007.index && matFlags == 3) hr.readH();
      if (vsFull == 1) hr.readH();
      if (vsFace == 1) hr.readH();
      if (vsEdge == 1) hr.readH();
    }

    final e = _Entity(handle: handle, type: type, layerHandle: 0, entmode: entmode, color: color);
    switch (type) {
      case 19: // LINE
        double sx, sy, sz = 0, ex, ey, ez = 0;
        if (ver.index < DwgVersion.r2000.index) {
          sx = br.readBD();
          sy = br.readBD();
          sz = br.readBD();
          ex = br.readBD();
          ey = br.readBD();
          ez = br.readBD();
        } else {
          final zZero = br.readB() == 1;
          sx = br.readRD();
          ex = br.readDD(sx);
          sy = br.readRD();
          ey = br.readDD(sy);
          if (!zZero) {
            sz = br.readRD();
            ez = br.readDD(sz);
          }
        }
        e.points = [Pt(sx, sy), Pt(ex, ey)];
        if ((sz - ez).abs() < 1e-9 && sz != 0) e.elevation = sz;
      case 18: // CIRCLE
      case 17: // ARC
        final cx = br.readBD(), cy = br.readBD(), cz = br.readBD();
        e.center = Pt(cx, cy);
        e.radius = br.readBD();
        br.readBT(ver);
        e.ocsMirror = br.readBE(ver);
        if (type == 17) {
          e.startAngle = br.readBD() * 180 / math.pi;
          e.endAngle = br.readBD() * 180 / math.pi;
        }
        if (cz != 0) e.elevation = cz;
      case 27: // POINT
        final x = br.readBD(), y = br.readBD(), z = br.readBD();
        e.points = [Pt(x, y)];
        if (z != 0) e.elevation = z;
      case 31: // SOLID
      case 32: // TRACE
        br.readBT(ver);
        final elev = br.readBD();
        final c = [for (var k = 0; k < 4; k++) Pt(br.readRD(), br.readRD())];
        e.ocsMirror = br.readBE(ver);
        // corners in 1-2-4-3 order
        final pts = <Pt>[];
        for (final p in [c[0], c[1], c[3], c[2]]) {
          if (pts.isEmpty || pts.last.distanceTo(p) > 1e-12) pts.add(p);
        }
        if (pts.length > 2 && pts.first.distanceTo(pts.last) < 1e-12) pts.removeLast();
        e.points = pts;
        e.closed = true;
        e.solidFill = true;
        if (elev != 0) e.elevation = elev;
      case 35: // ELLIPSE
        final c = Pt(br.readBD(), br.readBD());
        br.readBD();
        final major = Pt(br.readBD(), br.readBD());
        br.readBD();
        // centre and major axis are world coordinates; the minor axis is
        // extrusion × major, the other side for an extrusion (0, 0, −1)
        final flip = br.readExtrusion();
        final ratio = br.readBD();
        final a0 = br.readBD(), a1 = br.readBD();
        var sweep = a1 - a0;
        if (sweep <= 1e-9) sweep += 2 * math.pi;
        final full = sweep >= 2 * math.pi - 1e-9;
        final n = math.max(8, (sweep / (math.pi / 18)).ceil());
        final minor = major.perpendicular * ratio * (flip ? -1 : 1);
        e.points = [for (var k = 0; k <= (full ? n - 1 : n); k++) c + major * math.cos(a0 + sweep * k / n) + minor * math.sin(a0 + sweep * k / n)];
        e.closed = full;
      case 36: // SPLINE
        var scenario = br.readBL();
        if (ver.index >= DwgVersion.r2013.index) {
          final flags = br.readBL();
          final knotParam = br.readBL();
          if (flags & 1 != 0) scenario = 2;
          if (knotParam == 15) scenario = 1;
        }
        final degree = br.readBL();
        if (scenario & 1 != 0) {
          final rational = br.readB() == 1;
          e.closed = br.readB() == 1;
          br.readB(); // periodic
          br.readBD(); // knot tolerance
          br.readBD(); // control tolerance
          final nk = br.readBL(), nc = br.readBL();
          final weighted = br.readB() == 1;
          if (nk > 100000 || nc > 100000) return;
          final knots = [for (var k = 0; k < nk; k++) br.readBD()];
          final ctrl = <Pt>[];
          final weights = <double>[];
          for (var k = 0; k < nc; k++) {
            final x = br.readBD(), y = br.readBD();
            br.readBD();
            ctrl.add(Pt(x, y));
            if (weighted) weights.add(br.readBD());
          }
          e.points = nurbsCurve(degree, ctrl, knots: knots, weights: rational || weighted ? weights : const []);
        } else {
          br.readBD(); // fit tolerance
          for (var k = 0; k < 6; k++) {
            br.readBD(); // start and end tangents
          }
          final nf = br.readBL();
          if (nf > 100000) return;
          final pts = <Pt>[];
          for (var k = 0; k < nf; k++) {
            final x = br.readBD(), y = br.readBD();
            br.readBD(); // z
            pts.add(Pt(x, y));
          }
          e.points = pts;
        }
        e.fitSpline = scenario & 1 == 0;
      case 78: // HATCH
        if (ver.index >= DwgVersion.r2004.index) {
          br.readBL(); // gradient fill
          br.readBL(); // reserved
          br.readBD(); // gradient angle
          br.readBD(); // gradient shift
          br.readBL(); // single colour
          br.readBD(); // tint
          final nColors = br.readBL();
          for (var k = 0; k < nColors && k < 1000; k++) {
            br.readBD();
            _readCMC(br);
          }
          if (ver.index < DwgVersion.r2007.index) br.readTV(); // gradient name
        }
        final elev = br.readBD();
        e.ocsMirror = br.readExtrusion();
        if (ver.index < DwgVersion.r2007.index) br.readTV(); // pattern name
        e.solidFill = br.readB() == 1;
        br.readB(); // associative
        final nPaths = br.readBL();
        if (nPaths > 100000) return;
        final loops = <List<Pt>>[];
        var derived = false;
        for (var p = 0; p < nPaths; p++) {
          final flag = br.readBL();
          if (flag & 4 != 0) derived = true;
          final loop = <Pt>[];
          if (flag & 2 == 0) {
            final nSegs = br.readBL();
            for (var sgm = 0; sgm < nSegs && sgm < 100000; sgm++) {
              switch (br.readRC()) {
                case 1:
                  final a = Pt(br.readRD(), br.readRD()), b = Pt(br.readRD(), br.readRD());
                  if (loop.isEmpty || loop.last.distanceTo(a) > 1e-9) loop.add(a);
                  loop.add(b);
                case 2:
                  final c = Pt(br.readRD(), br.readRD());
                  final r = br.readBD(), s = br.readBD(), en = br.readBD();
                  final ccw = br.readB() == 1;
                  final a0 = ccw ? s : -s, a1 = ccw ? en : -en;
                  var sweep = ccw ? a1 - a0 : a0 - a1;
                  if (sweep <= 1e-12) sweep += 2 * math.pi;
                  final n = math.max(4, (sweep / (math.pi / 18)).ceil());
                  for (var q = 0; q <= n; q++) {
                    loop.add(c + Pt.polar(r, ccw ? a0 + sweep * q / n : a0 - sweep * q / n));
                  }
                case 3:
                  final c = Pt(br.readRD(), br.readRD()), major = Pt(br.readRD(), br.readRD());
                  final ratio = br.readBD(), s = br.readBD(), en = br.readBD();
                  final ccw = br.readB() == 1;
                  final minor = major.perpendicular * ratio;
                  final a0 = ccw ? s : -s, a1 = ccw ? en : -en;
                  var sweep = ccw ? a1 - a0 : a0 - a1;
                  if (sweep <= 1e-12) sweep += 2 * math.pi;
                  final n = math.max(8, (sweep / (math.pi / 18)).ceil());
                  for (var q = 0; q <= n; q++) {
                    final t = ccw ? a0 + sweep * q / n : a0 - sweep * q / n;
                    loop.add(c + major * math.cos(t) + minor * math.sin(t));
                  }
                case 4:
                  final degree = br.readBL();
                  final rational = br.readB() == 1;
                  br.readB(); // periodic
                  final nk = br.readBL(), nc = br.readBL();
                  if (nk > 100000 || nc > 100000) return;
                  final knots = [for (var q = 0; q < nk; q++) br.readBD()];
                  final ctrl = <Pt>[];
                  final weights = <double>[];
                  for (var q = 0; q < nc; q++) {
                    ctrl.add(Pt(br.readRD(), br.readRD()));
                    if (rational) weights.add(br.readBD());
                  }
                  if (ver.index >= DwgVersion.r2010.index) {
                    final nf = br.readBL();
                    if (nf > 0) {
                      for (var q = 0; q < nf && q < 100000; q++) {
                        br.readRD();
                        br.readRD();
                      }
                      for (var q = 0; q < 4; q++) {
                        br.readRD(); // start and end tangents
                      }
                    }
                  }
                  loop.addAll(nurbsCurve(degree, ctrl, knots: knots, weights: weights));
                default:
                  return; // unknown edge: the rest of the stream cannot be trusted
              }
            }
          } else {
            final bulges = br.readB() == 1;
            br.readB(); // closed
            final n = br.readBL();
            if (n > 100000) return;
            final pts = <Pt>[];
            final bl = <double>[];
            for (var q = 0; q < n; q++) {
              pts.add(Pt(br.readRD(), br.readRD()));
              bl.add(bulges ? br.readBD() : 0);
            }
            loop.addAll(bl.any((b) => b != 0) ? _tessellateBulges(pts, bl, true) : pts);
          }
          br.readBL(); // boundary handles (in the handle stream)
          if (loop.length > 2 && loop.first.distanceTo(loop.last) < 1e-9) loop.removeLast();
          if (loop.length >= 3) loops.add(loop);
        }
        br.readBS(); // style
        br.readBS(); // pattern type
        var angle = 45.0, spacing = 0.0;
        if (!e.solidFill) {
          angle = br.readBD() * 180 / math.pi;
          final scale = br.readBD();
          br.readB(); // double
          final nLines = br.readBS();
          for (var q = 0; q < nLines && q < 1000; q++) {
            final a = br.readBD();
            br.readBD();
            br.readBD(); // base point
            final ox = br.readBD(), oy = br.readBD();
            final nd = br.readBS();
            for (var k = 0; k < nd && k < 1000; k++) {
              br.readBD();
            }
            if (q == 0) {
              angle = a * 180 / math.pi;
              spacing = (-math.sin(a) * ox + math.cos(a) * oy).abs();
            }
          }
          if (spacing <= 1e-9) spacing = 3.175 * (scale > 0 ? scale : 1);
        }
        if (derived) br.readBD(); // pixel size
        if (loops.isEmpty) return;
        loops.sort((a, b) => polygonArea(b).abs().compareTo(polygonArea(a).abs()));
        e.points = loops.first;
        e.islands = loops.skip(1).toList();
        e.closed = true;
        e.rotation = angle;
        e.height = spacing > 0 ? spacing : 1;
        if (elev != 0) e.elevation = elev;
      case 10: // VERTEX_2D
      case 11: // VERTEX_3D
        final vflags = br.readRC();
        final x = br.readBD(), y = br.readBD();
        _vertexZ[handle] = br.readBD();
        // spline frame control points (flag 16) are not on the curve
        if (vflags & 16 != 0) return;
        _vertices[handle] = Pt(x, y);
        if (type == 10) {
          // start width (a negative one stands for both), end width, bulge
          if (br.readBD() >= 0) br.readBD();
          final bulge = br.readBD();
          if (bulge != 0) _vertexBulge[handle] = bulge;
        }
        return;
      case 16: // POLYLINE_3D
        br.readRC(); // curve flags
        final flag2 = br.readRC();
        e.closed = flag2 & 1 != 0;
        var numOwned3 = 0;
        if (ver.index >= DwgVersion.r2004.index) numOwned3 = br.readBL();
        readCommonHandles();
        if (ver.index >= DwgVersion.r2004.index) {
          ownedVertices = [for (var i = 0; i < numOwned3 && i < 100000; i++) _absHandle(hr.readH(), handle)];
        } else {
          firstVertex = _absHandle(hr.readH(), handle);
          lastVertex = _absHandle(hr.readH(), handle);
        }
        e.ownedVertices = ownedVertices;
        e.firstVertex = firstVertex;
        e.lastVertex = lastVertex;
        _entities.add(_withLayer(e, layerHandle, owner));
        return;
      case 15: // POLYLINE_2D
        final flags = br.readBS();
        br.readBS(); // curve type
        br.readBD(); // start width
        br.readBD(); // end width
        br.readBT(ver);
        final elev = br.readBD();
        e.ocsMirror = br.readBE(ver);
        e.closed = flags & 1 != 0;
        if (elev != 0) e.elevation = elev;
        var numOwned = 0;
        if (ver.index >= DwgVersion.r2004.index) numOwned = br.readBL();
        readCommonHandles();
        if (ver.index >= DwgVersion.r2004.index) {
          ownedVertices = [for (var i = 0; i < numOwned && i < 100000; i++) _absHandle(hr.readH(), handle)];
        } else {
          firstVertex = _absHandle(hr.readH(), handle);
          lastVertex = _absHandle(hr.readH(), handle);
        }
        e.ownedVertices = ownedVertices;
        e.firstVertex = firstVertex;
        e.lastVertex = lastVertex;
        _entities.add(_withLayer(e, layerHandle, owner));
        return;
      case 77: // LWPOLYLINE
        final flag = br.readBS();
        if (flag & 4 != 0) br.readBD();
        double? elev;
        if (flag & 8 != 0) elev = br.readBD();
        if (flag & 2 != 0) br.readBD();
        if (flag & 1 != 0) e.ocsMirror = br.readExtrusion();
        final numPoints = br.readBL();
        var numBulges = 0, numWidths = 0;
        if (flag & 16 != 0) numBulges = br.readBL();
        if (ver.index >= DwgVersion.r2010.index && flag & 1024 != 0) br.readBL();
        if (flag & 32 != 0) numWidths = br.readBL();
        final pts = <Pt>[];
        if (numPoints > 0 && numPoints < 1000000) {
          if (ver.index < DwgVersion.r2000.index) {
            for (var i = 0; i < numPoints; i++) {
              pts.add(Pt(br.readRD(), br.readRD()));
            }
          } else {
            var x = br.readRD(), y = br.readRD();
            pts.add(Pt(x, y));
            for (var i = 1; i < numPoints; i++) {
              x = br.readDD(x);
              y = br.readDD(y);
              pts.add(Pt(x, y));
            }
          }
        }
        final bulges = <double>[];
        for (var i = 0; i < numBulges && i < 1000000; i++) {
          bulges.add(br.readBD());
        }
        for (var i = 0; i < numWidths && i < 1000000; i++) {
          br.readBD();
          br.readBD();
        }
        e.closed = flag & 512 != 0;
        e.points = bulges.isEmpty ? pts : _tessellateBulges(pts, bulges, e.closed);
        if (elev != null && elev != 0) e.elevation = elev;
      case 1: // TEXT
        if (ver.index < DwgVersion.r2000.index) {
          final elev = br.readBD();
          final ix = br.readRD(), iy = br.readRD();
          final align = Pt(br.readRD(), br.readRD());
          e.ocsMirror = br.readExtrusion();
          br.readBD(); // thickness
          br.readBD(); // oblique
          e.rotation = br.readBD() * 180 / math.pi;
          e.height = br.readBD();
          br.readBD(); // width factor
          e.text = br.readTV();
          br.readBS(); // generation
          final h = br.readBS(), v = br.readBS();
          // aligned text is positioned by its alignment point (as in DXF)
          e.points = [h != 0 || v != 0 ? align : Pt(ix, iy)];
          if (elev != 0) e.elevation = elev;
        } else {
          final f = br.readRC();
          double elev = 0;
          if (f & 1 == 0) elev = br.readRD();
          final ix = br.readRD(), iy = br.readRD();
          Pt? align;
          if (f & 2 == 0) {
            final ax = br.readDD(ix);
            align = Pt(ax, br.readDD(iy));
          }
          e.ocsMirror = br.readBE(ver);
          br.readBT(ver);
          if (f & 4 == 0) br.readRD();
          if (f & 8 == 0) e.rotation = br.readRD() * 180 / math.pi;
          e.height = br.readRD();
          if (f & 16 == 0) br.readRD();
          e.text = strings != null ? strings.readTU() : br.readTV();
          var h = 0, v = 0;
          if (f & 0x20 == 0) br.readBS(); // generation
          if (f & 0x40 == 0) h = br.readBS();
          if (f & 0x80 == 0) v = br.readBS();
          // aligned text is positioned by its alignment point (as in DXF)
          e.points = [(h != 0 || v != 0) && align != null ? align : Pt(ix, iy)];
          if (elev != 0) e.elevation = elev;
        }
      case 44: // MTEXT
        final ix = br.readBD(), iy = br.readBD();
        br.readBD();
        br.readBD();
        br.readBD();
        br.readBD(); // extrusion
        final ax = br.readBD(), ay = br.readBD();
        br.readBD();
        br.readBD(); // rect width
        if (ver.index >= DwgVersion.r2007.index) br.readBD(); // rect height
        e.height = br.readBD();
        br.readBS(); // attachment
        br.readBS(); // drawing dir
        br.readBD();
        br.readBD(); // extents
        final raw = strings != null ? strings.readTU() : br.readTV();
        e.text = _stripMtext(raw);
        e.rotation = math.atan2(ay, ax) * 180 / math.pi;
        e.points = [Pt(ix, iy)];
      case 20: // DIMENSION_ORDINATE … DIMENSION_DIAMETER: geometry lives in an
      case 21: // anonymous *D block in world coordinates, so only the handles
      case 22: // (dimstyle, block) are needed
      case 23:
      case 24:
      case 25:
      case 26:
        readCommonHandles();
        hr.readH(); // dimstyle
        e.blockHandle = _absHandle(hr.readH(), handle);
        e.points = [Pt.zero];
        _entities.add(_withLayer(e, layerHandle, owner));
        return;
      case 7: // INSERT
      case 8: // MINSERT
        final ix = br.readBD(), iy = br.readBD();
        br.readBD(); // z
        double sx = 1, sy = 1;
        if (ver.index < DwgVersion.r2000.index) {
          sx = br.readBD();
          sy = br.readBD();
          br.readBD();
        } else {
          switch (br.readBB()) {
            case 3: // 1, 1, 1
              break;
            case 2: // one value for the three axes
              sx = br.readRD();
              sy = sx;
            case 1: // x = 1
              sy = br.readDD(1);
              br.readDD(1);
            default:
              sx = br.readRD();
              sy = br.readDD(sx);
              br.readDD(sx);
          }
        }
        e.rotation = br.readBD() * 180 / math.pi;
        e.ocsMirror = br.readExtrusion();
        final hasAttribs = br.readB() == 1;
        if (ver.index >= DwgVersion.r2004.index && hasAttribs) br.readBL(); // owned attribs
        if (type == 8) {
          e.cols = br.readBS();
          e.rows = br.readBS();
          e.colSpacing = br.readBD();
          e.rowSpacing = br.readBD();
        }
        e.points = [Pt(ix, iy)];
        e.scaleX = sx;
        e.scaleY = sy;
        readCommonHandles();
        e.blockHandle = _absHandle(hr.readH(), handle);
        _entities.add(_withLayer(e, layerHandle, owner));
        return;
      default:
        return;
    }
    readCommonHandles();
    _entities.add(_withLayer(e, layerHandle, owner));
  }

  /// Absolute handle of a reference: codes 6/8/A/C are offsets from the
  /// handle of the object holding the reference.
  static int _absHandle((int, int) h, int self) => switch (h.$1) {
    6 => self + 1,
    8 => self - 1,
    0xA => self + h.$2,
    0xC => self - h.$2,
    _ => h.$2,
  };

  _Entity _withLayer(_Entity e, int layerHandle, int owner) {
    final n = _Entity(handle: e.handle, type: e.type, layerHandle: layerHandle, entmode: e.entmode, color: e.color, owner: owner)
      ..points = e.points
      ..center = e.center
      ..radius = e.radius
      ..startAngle = e.startAngle
      ..endAngle = e.endAngle
      ..text = e.text
      ..height = e.height
      ..rotation = e.rotation
      ..closed = e.closed
      ..elevation = e.elevation
      ..firstVertex = e.firstVertex
      ..lastVertex = e.lastVertex
      ..ownedVertices = e.ownedVertices
      ..fitSpline = e.fitSpline
      ..ocsMirror = e.ocsMirror
      ..solidFill = e.solidFill
      ..islands = e.islands
      ..scaleX = e.scaleX
      ..scaleY = e.scaleY
      ..blockHandle = e.blockHandle
      ..cols = e.cols
      ..rows = e.rows
      ..colSpacing = e.colSpacing
      ..rowSpacing = e.rowSpacing;
    return n;
  }

  static String _stripMtext(String s) {
    var t = s.replaceAll(r'\P', ' ').replaceAll(r'\~', ' ');
    t = t.replaceAll(RegExp(r'\\[ACFHQTWfhpc][^;]*;'), '');
    t = t.replaceAll(RegExp(r'\\[LlOoKk]'), '');
    t = t.replaceAll('{', '').replaceAll('}', '');
    return t.trim();
  }

  static List<Pt> _tessellateBulges(List<Pt> pts, List<double> bulges, bool closed) {
    final out = <Pt>[];
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      out.add(pts[i]);
      final next = i + 1 < n ? pts[i + 1] : (closed ? pts.first : null);
      if (next == null) break;
      final b = i < bulges.length ? bulges[i] : 0.0;
      if (b.abs() < 1e-9) continue;
      final theta = 4 * math.atan(b.abs());
      final chord = pts[i].distanceTo(next);
      if (chord < 1e-12) continue;
      final r = chord / (2 * math.sin(theta / 2));
      final mid = Pt.lerp(pts[i], next, 0.5);
      final dir = (next - pts[i]).normalized;
      final perp = dir.perpendicular;
      final h = math.sqrt(math.max(0, r * r - chord * chord / 4));
      final centre = mid + perp * (b > 0 ? h : -h) * (theta > math.pi ? -1 : 1);
      final a0 = (pts[i] - centre).angle;
      final segs = math.max(3, (theta / (math.pi / 18)).ceil());
      for (var k = 1; k < segs; k++) {
        final ang = a0 + (b > 0 ? 1 : -1) * theta * k / segs;
        out.add(centre + Pt.polar(r, ang));
      }
    }
    return out;
  }

  // ------------------------------------------------------------ build

  DwgResult _build() {
    final resolved = _entities.where((e) => _layers.containsKey(e.layerHandle)).length;
    debugLog.add('layerResolved=$resolved/${_entities.length} layerHandles=${_layers.keys.take(6).toList()} entityLayerRefs=${_entities.map((e) => e.layerHandle).toSet().take(6).toList()}');
    debugLog.add('layers=${_layers.length} vertices=${_vertices.length} rawEntities=${_entities.length} entmodes=${_entities.map((e) => e.entmode).fold<Map<int, int>>({}, (m, v) => m..[v] = (m[v] ?? 0) + 1)} blockHeaders=${_blockHeaders.length} modelSpace=$_modelSpaceHandle owners=${_entities.where((e) => e.entmode == 0).map((e) => e.owner).toSet().take(6).toList()}');
    final layerList = <DxfLayer>[];
    final seen = <String>{};
    for (final l in _layers.values) {
      if (seen.add(l.name)) layerList.add(DxfLayer(l.name, color: l.color >= 1 && l.color <= 255 ? l.color : 7));
    }
    String layerOf(_Entity e) => _layers[e.layerHandle]?.name ?? '0';
    int colorOf(_Entity e) => e.color == 0 ? 0 : (e.color >= 1 && e.color <= 255 ? e.color : 256);
    DxfEntity? toDxf(_Entity e) {
      final layer = layerOf(e);
      final color = colorOf(e);
      switch (e.type) {
        case 19:
          return DxfEntity(type: 'LINE', layer: layer, color: color, points: e.points, elevation: e.elevation);
        case 18:
          return DxfEntity(type: 'CIRCLE', layer: layer, color: color, center: e.center, radius: e.radius, elevation: e.elevation);
        case 17:
          return DxfEntity(type: 'ARC', layer: layer, color: color, center: e.center, radius: e.radius, startAngle: e.startAngle, endAngle: e.endAngle, elevation: e.elevation);
        case 27:
          return DxfEntity(type: 'POINT', layer: layer, color: color, points: e.points, elevation: e.elevation);
        case 1:
        case 44:
          return e.text.isNotEmpty ? DxfEntity(type: 'TEXT', layer: layer, color: color, points: e.points, text: e.text, height: e.height, rotation: e.rotation, elevation: e.elevation) : null;
        case 77:
          return e.points.length >= 2 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 35:
          return e.points.length >= 2 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 36:
          return e.points.length >= 2 ? DxfEntity(type: e.fitSpline ? 'SPLINE' : 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 31:
        case 32:
        case 78:
          return e.points.length >= 3 ? DxfEntity(type: 'HATCH', layer: layer, color: color, points: e.points, closed: true, rotation: e.rotation, height: e.height, solid: e.solidFill, elevation: e.elevation) : null;
        case 15:
        case 16:
          final handles = e.ownedVertices.isNotEmpty ? e.ownedVertices.where((h) => _vertices[h] != null).toList() : (_vertices.keys.where((h) => h >= e.firstVertex && h <= e.lastVertex).toList()..sort());
          var pts = [for (final h in handles) _vertices[h]!];
          final bulges = [for (final h in handles) _vertexBulge[h] ?? 0.0];
          if (e.type == 15 && bulges.any((b) => b != 0)) pts = _tessellateBulges(pts, bulges, e.closed);
          var elev = e.elevation;
          if (e.type == 16 && elev == null && handles.isNotEmpty) {
            // a 3D polyline at one height is a contour
            final zs = [for (final h in handles) _vertexZ[h] ?? 0.0];
            if (zs.first != 0 && zs.every((z) => (z - zs.first).abs() < 1e-9)) elev = zs.first;
          }
          return pts.length >= 2 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: e.closed, elevation: elev) : null;
        default:
          return null;
      }
    }

    DxfInsert toInsert(_Entity e) => DxfInsert(name: _blocks[e.blockHandle]?.name ?? '', layer: layerOf(e), color: colorOf(e), position: e.points.first, scaleX: e.scaleX, scaleY: e.scaleY, rotation: e.rotation, cols: math.max(1, e.cols), rows: math.max(1, e.rows), colSpacing: e.colSpacing, rowSpacing: e.rowSpacing, ocsMirror: e.ocsMirror);
    // block membership: owned lists (R2004+), owner handle, or the handle range (R13–R2000)
    final blockOfHandle = <int, _Block>{};
    for (final b in _blocks.values) {
      for (final h in b.owned) {
        blockOfHandle[h] = b;
      }
    }
    bool isSpace(_Block b) => b.name.toLowerCase() == '*model_space' || b.name.toLowerCase() == '*paper_space';
    _Block? blockFor(_Entity e) {
      final owned = blockOfHandle[e.handle];
      if (owned != null) return owned;
      if (e.entmode == 0) return _blocks[e.owner];
      // the tightest handle range wins (model space spans everything)
      _Block? best;
      for (final b in _blocks.values) {
        if (isSpace(b) || b.first == 0 || e.handle < b.first || e.handle > b.last) continue;
        if (best == null || b.last - b.first < best.last - best.first) best = b;
      }
      return best;
    }

    final ents = <DxfEntity>[];
    final counts = <String, int>{};
    final inserts = <DxfInsert>[];
    final blockEntities = <int, List<DxfEntity>>{};
    final blockInserts = <int, List<DxfInsert>>{};
    for (final e in _entities) {
      // model space: entmode 2, or entmode 0 owned by *Model_Space
      final inModel = e.entmode == 2 || (e.entmode == 0 && (e.owner == _modelSpaceHandle || (_modelSpaceHandle == 0 && !_blockHeaders.contains(e.owner))));
      final isInsert = e.type == 7 || e.type == 8 || (e.type >= 20 && e.type <= 26);
      // hatch islands become closed polylines next to the hatch
      Iterable<DxfEntity> converted() sync* {
        DxfEntity world(DxfEntity x) => e.ocsMirror ? DxfReader.mirrorOcs(x) : x;
        final d = toDxf(e);
        if (d == null) return;
        yield world(d);
        for (final island in e.islands) {
          yield world(DxfEntity(type: 'POLYLINE', layer: d.layer, color: d.color, points: island, closed: true));
        }
      }

      if (inModel) {
        if (isInsert) {
          inserts.add(toInsert(e));
        } else {
          ents.addAll(converted());
        }
        continue;
      }
      if (e.entmode == 1) continue; // paper space
      final b = blockFor(e);
      if (b == null) continue;
      if (isInsert) {
        blockInserts.putIfAbsent(b.handle, () => []).add(toInsert(e));
      } else {
        blockEntities.putIfAbsent(b.handle, () => []).addAll(converted());
      }
    }
    final blocksByName = {for (final b in _blocks.values) b.name: DxfBlock(b.name, b.base, blockEntities[b.handle] ?? const [], blockInserts[b.handle] ?? const [])};
    DxfReader.expandInserts(inserts, blocksByName, ents);
    for (final d in ents) {
      counts[d.type] = (counts[d.type] ?? 0) + 1;
    }
    debugLog.add('blockHeaders=${_blockHeaders.length} blocks=${[for (final b in _blocks.values.take(12)) '${b.name}@${b.handle}:base=${b.base},first=${b.first},last=${b.last},owned=${b.owned.length},ents=${blockEntities[b.handle]?.length ?? 0}']} inserts=${[for (final i in inserts.take(8)) '${i.name}@${i.position} s=${i.scaleX},${i.scaleY} r=${i.rotation}']} nonModel=${_entities.where((e) => e.entmode != 2).map((e) => 'h${e.handle}:t${e.type}:m${e.entmode}:o${e.owner}').take(8).toList()}');
    return DwgResult(document: DxfDocument(entities: ents, layers: layerList), version: ver.name, warnings: warnings, typeCounts: counts, objectCount: objectCount, debugLog: debugLog);
  }
}
