/// Pure-Dart reader for DWG files (R13/R14/R2000 uncompressed
/// containers, the R2004/R2010–R2018 compressed container and the R2007
/// Reed–Solomon interleaved container). Extracts layers (colour, true
/// colour, off and frozen) and the entities relevant to an irrigation plan,
/// producing a [DxfDocument]: LINE, CIRCLE, ARC, ELLIPSE, POINT, TEXT and
/// visible ATTRIB (placed by their justification), MTEXT (paragraphs kept,
/// placed by its attachment), LWPOLYLINE, 2D and 3D POLYLINE, polyface and
/// polygon meshes and 3DFACE (their corners as spot heights), SPLINE,
/// HATCH, SOLID/TRACE, LEADER and MLINE (as polylines), INSERT/MINSERT with
/// their blocks and the DIMENSION blocks. The drawing units come from the
/// header variables (`$INSUNITS`, R2000 and later) and the texts of
/// R13–R2004 files are read in the code page the file names.
///
/// Based on the Open Design Alliance specification of the DWG format.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'cad_drawing.dart' show nearestAci;
import 'cad_xdata.dart';
import 'codepages.dart';
import 'dxf.dart';
import 'work_slicer.dart';

class DwgUnsupportedException implements Exception {
  DwgUnsupportedException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class DwgResult {
  DwgResult({required this.document, required this.version, required this.warnings, required this.typeCounts, required this.objectCount, this.debugLog = const [], this.insunits});
  final DxfDocument document;
  final String version;

  /// Diagnostics of the reader (objects that did not read, pages missing);
  /// the notes for the user are in [DxfDocument.warnings].
  final List<String> warnings;
  final Map<String, int> typeCounts;
  final int objectCount;
  final List<String> debugLog;

  /// `$INSUNITS` of the header (null when it could not be read).
  final int? insunits;
}

enum DwgVersion { r13, r14, r2000, r2004, r2007, r2010, r2013, r2018 }

class _Eof implements Exception {}

/// Bit-level reader over a byte buffer (MSB first within each byte).
/// All multi-byte integers are assembled arithmetically so the code is safe
/// on the web (dart2js bitwise operations are 32-bit).
class _BitReader {
  _BitReader(this.data, int startByte, int endByte) : pos = startByte * 8, end = endByte * 8;
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

  /// Code page of the R13–R2004 texts (the drawing's, from its header).
  int codepage = 1252;

  /// Text (R13–R2004): length BS then bytes in [codepage]. Every byte is
  /// read, however long the text (a cut would leave the stream misaligned).
  String readTV() {
    final len = readBS();
    if (len <= 0) return '';
    final b = <int>[];
    for (var i = 0; i < len; i++) {
      final c = readByte();
      if (c != 0) b.add(c);
    }
    return decodeCodepage(b, codepage);
  }

  /// Unicode text (R2007+ string stream): length BS then UTF‑16LE units.
  String readTU() {
    final len = readBS();
    if (len <= 0) return '';
    final units = <int>[];
    for (var i = 0; i < len; i++) {
      final u = readRS();
      if (u != 0) units.add(u);
    }
    return String.fromCharCodes(units);
  }

  void skipBytes(int n) {
    pos += n * 8;
    if (pos > end) throw _Eof();
  }
}

class _Layer {
  _Layer(this.name, this.color, {this.visible = true, this.rgb});
  final String name;
  final int color;

  /// False when the layer is off or frozen.
  final bool visible;

  /// True colour (0xRRGGBB), R2004+.
  final int? rgb;
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

  /// INSERT / MINSERT: the handles of its attributes (R2004+), or the first
  /// and the last of them (R13–R2000, a range of handles).
  List<int> ownedAttribs = const [];
  int firstAttrib = 0;
  int lastAttrib = 0;

  /// 3DFACE: the elevations of the corners in [points].
  List<double> cornerZ = const [];

  /// ATTRIB: its tag, and whether it is invisible (data, not drawing).
  String attribTag = '';
  bool invisible = false;

  /// The hydraulic data the app wrote in the extended data (cad_xdata.dart).
  Map<String, String>? xdata;
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

  /// An external reference (or an overlay): a drawing the file only names.
  bool xref = false;
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

  /// Notes for the user (codes of `warn.*`), carried by the document.
  final List<String> _notes = [];

  /// Entity types read but not drawn, with their counts.
  final Map<String, int> _unsupported = {};

  /// Code page of the R13–R2004 texts (byte 0x13 of the file).
  int _codepage = 1252;

  /// The AcDb:Header section (header variables), when found.
  Uint8List? _header;

  /// The hydraulic data in the EED of the object being read.
  Map<String, String>? _eed;

  /// The groups of the EED bytes [d] of one application: code (1000 + the
  /// stored byte) and value as text (strings in the file's code page,
  /// R2007+ in UTF-16; reals and integers in plain notation).
  List<(int, String)> _eedGroups(Uint8List d) {
    final out = <(int, String)>[];
    final bd = ByteData.sublistView(d);
    var p = 0;
    while (p < d.length) {
      final code = d[p++];
      switch (code) {
        case 0:
          if (ver.index >= DwgVersion.r2007.index) {
            if (p + 2 > d.length) return out;
            final n = bd.getUint16(p, Endian.little);
            p += 2;
            if (p + 2 * n > d.length) return out;
            out.add((1000, decodeUtf16(d.sublist(p, p + 2 * n), littleEndian: true)));
            p += 2 * n;
          } else {
            if (p + 3 > d.length) return out;
            final n = d[p];
            p += 3; // length, then the code page (2 bytes)
            if (p + n > d.length) return out;
            out.add((1000, decodeCodepage(d, _codepage, p, p + n)));
            p += n;
          }
        case 2:
          if (p >= d.length) return out;
          out.add((1002, d[p++] == 0 ? '{' : '}'));
        case 3 || 5:
          p += 8;
        case 4:
          if (p >= d.length) return out;
          p += 1 + d[p];
        case >= 10 && <= 13:
          p += 24;
        case 40 || 41 || 42:
          if (p + 8 > d.length) return out;
          out.add((1000 + code, '${bd.getFloat64(p, Endian.little)}'));
          p += 8;
        case 70:
          if (p + 2 > d.length) return out;
          out.add((1070, '${bd.getInt16(p, Endian.little)}'));
          p += 2;
        case 71:
          if (p + 4 > d.length) return out;
          out.add((1071, '${bd.getInt32(p, Endian.little)}'));
          p += 4;
        default:
          return out;
      }
    }
    return out;
  }

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

  /// [parse] in slices of [slicer] (the interface stays responsive and the
  /// user can cancel).
  static Future<DwgResult> parseAsync(Uint8List bytes, WorkSlicer slicer) async {
    final r = DwgReader._(bytes);
    r._open();
    await slicer.pause(0.1);
    final n = r.handleMap.length;
    for (var i = 0; i < n; i++) {
      r._readObjectAt(i);
      if (slicer.due) await slicer.pause(0.1 + 0.8 * i / n);
    }
    await slicer.pause(0.9);
    return r._build();
  }

  DwgResult _run() {
    _open();
    for (var i = 0; i < handleMap.length; i++) {
      _readObjectAt(i);
    }
    return _build();
  }

  /// Version, code page and container: the handle map and the object data.
  void _open() {
    final v = versionOf(file);
    if (v == null) throw DwgUnsupportedException('notDwg', 'Not a recognised DWG file (version ${String.fromCharCodes(file.take(6))}).');
    ver = v;
    // R13–R2004 texts are in the code page the header names (R2007+ are UTF-16)
    if (ver.index < DwgVersion.r2007.index && file.length > 0x14) {
      final n = file[0x13] + file[0x14] * 256;
      final cp = codepageFromDwg(n);
      if (cp != null && supportedCodepages.contains(cp)) {
        _codepage = cp;
      } else {
        _notes.add('dwg_codepage_unsupported:${cp != null ? codepageName(cp) : n}');
      }
    }
    if (ver == DwgVersion.r2007) {
      _readR2007Container();
    } else if (ver.index <= DwgVersion.r2000.index) {
      _readR2000Container();
    } else {
      _readR2004Container();
    }
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
      final size = _rl(file, at + 5);
      if (num == 2) handlesSeeker = seeker;
      if (num == 0 && seeker > 0 && seeker < file.length) _header = Uint8List.sublistView(file, seeker, math.min(file.length, seeker + math.max(size, 0)));
      // the classes: the names of the object types from 500 on
      if (num == 1 && seeker > 0 && seeker < file.length) _readClasses(Uint8List.sublistView(file, seeker, math.min(file.length, seeker + math.max(size, 0))));
      at += 9;
    }
    if (handlesSeeker == null) throw DwgUnsupportedException('corrupt', 'Handles section not found.');
    _parseHandleMap(file, handlesSeeker);
  }

  /// The handle map: (handle, offset) pairs delta-coded in sections. The
  /// specification restarts the deltas at every section; some writers keep
  /// them running. Both readings agree on the first section, so they are
  /// told apart by checking objects spread over the whole map (a check of
  /// the first entries only misread 64 of 750 objects of a real-world file).
  void _parseHandleMap(Uint8List data, int start) {
    List<(int, int)>? best;
    var bestGood = -1;
    for (final resetPerSection in [true, false]) {
      final map = <(int, int)>[];
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
            map.add((lastHandle, lastOffset));
          }
        } on _Eof {
          ok = false;
        }
        pos = endPos + 2;
      }
      final good = _handleMatches(map);
      if (ok && good > bestGood) {
        best = map;
        bestGood = good;
      }
      best ??= map;
    }
    handleMap
      ..clear()
      ..addAll(best ?? const []);
  }

  /// Objects among up to 60 entries spread over [map] whose own handle is
  /// the one the map gives them.
  int _handleMatches(List<(int, int)> map) {
    if (map.isEmpty) return 0;
    final n = math.min(60, map.length);
    var good = 0;
    for (var k = 0; k < n; k++) {
      final (h, off) = map[(k * map.length) ~/ n];
      if (off < 0 || off >= objData.length - 4) continue;
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
        final (_, hv) = br.readH();
        if (hv == h) good++;
      } catch (_) {
        // not an object at that offset
      }
    }
    return good;
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
    debugLog.add(
      'hdr magic=${String.fromCharCodes(h.sublist(0, 11))} pageMapId=$pageMapId pageMapAddr=$pageMapAddr sectionMapId=$sectionMapId pages=${_rl(h, 0x40)} sections=${_rl(h, 0x60)} file=${file.length}',
    );
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
      if (name == 'AcDb:Handles' || name == 'AcDb:AcDbObjects' || name == 'AcDb:Header' || name == 'AcDb:Classes') {
        if (size <= 0 || size > 512 * 1024 * 1024) {
          if (name == 'AcDb:Header' || name == 'AcDb:Classes') continue;
          throw DwgUnsupportedException('corrupt', 'Section $name has an invalid size.');
        }
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
        if (name == 'AcDb:Header') _header = buf;
        if (name == 'AcDb:Classes') _readClasses(buf);
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
    debugLog.add(
      'r2007 hdr size=${f(0)} file=${f(1)} pagesMap@${0x480 + pagesMapOffset} comp=$pagesMapSizeComp uncomp=$pagesMapSizeUncomp corr=$pagesMapCorrection sectionsMapId=$sectionsMapId comp=$sectionsMapSizeComp uncomp=$sectionsMapSizeUncomp sections=${f(20)}',
    );
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
      if (name != 'AcDb:Handles' && name != 'AcDb:AcDbObjects' && name != 'AcDb:Header' && name != 'AcDb:Classes') continue;
      if (dataSize <= 0 || dataSize > 512 * 1024 * 1024) {
        if (name == 'AcDb:Header' || name == 'AcDb:Classes') continue;
        throw DwgUnsupportedException('corrupt', 'Section $name has an invalid size.');
      }
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
      if (name == 'AcDb:Header') _header = buf;
      if (name == 'AcDb:Classes') _readClasses(buf);
    }
    if (handles == null || objects == null) throw DwgUnsupportedException('corrupt', 'Object sections not found in the DWG.');
    objData = objects;
    _parseHandleMap(handles, 0);
    debugLog.add('handles=${handleMap.length} objData=${objData.length}');
  }

  /// The classes of the drawing (types from 500 on): DXF name and whether
  /// the class is an entity, by class number.
  final Map<int, (String, bool)> _classes = {};

  /// Reads the classes section [d] (its start sentinel included): number,
  /// names and item class (0x1F2 entity, 0x1F3 object) of each class; R2007
  /// and later keep their names in a string stream at the end of the data.
  /// A section that does not read leaves the classes it read.
  void _readClasses(Uint8List d) {
    if (d.length < 24) return;
    try {
      final br = _BitReader(d, 16, d.length)..codepage = _codepage;
      final size = br.readRL();
      final dataEnd = math.min(d.length, 20 + size);
      var base = 160; // bits up to the end of the size
      _BitReader? strings;
      final r2007 = ver.index >= DwgVersion.r2007.index;
      if (ver.index >= DwgVersion.r2010.index && file.length > 0x0B && file[0x0B] > 3) {
        br.readRL(); // high size
        base += 32;
      }
      if (r2007) {
        final bitsize = br.readRL();
        // the string stream ends at the bit before the end of the data, its size before that
        final probe = _BitReader(d, 0, d.length);
        probe.pos = base + bitsize - 1;
        if (probe.readBit() == 1) {
          probe.pos = base + bitsize - 1 - 16;
          var strSize = probe.readRS();
          var back = 16;
          if (strSize & 0x8000 != 0) {
            probe.pos = base + bitsize - 1 - 32;
            strSize = (strSize & 0x7FFF) + probe.readRS() * 32768;
            back = 32;
          }
          final at = base + bitsize - 1 - back - strSize;
          if (at > 0) strings = _BitReader(d, 0, d.length)..pos = at;
        }
        if (strings == null) return;
      }
      // R2004 and later say how many classes there are (numbered from 500):
      // in R2007 and later the string stream follows them in the same data
      var count = 5000;
      if (ver.index >= DwgVersion.r2004.index) {
        final highest = br.readBS();
        br.readRC();
        br.readRC();
        br.readB();
        count = highest >= 500 ? math.min(5000, highest - 499) : 0;
      }
      for (var k = 0; k < count && br.bytePos < dataEnd - 1; k++) {
        final number = br.readBS();
        br.readBS(); // proxy flags
        String text() => strings != null ? strings.readTU() : br.readTV();
        text(); // application
        text(); // C++ class
        final dxf = text();
        br.readB(); // was a zombie
        final item = br.readBS();
        if (ver.index >= DwgVersion.r2004.index) {
          br.readBL(); // instances
          br.readBL(); // version
          br.readBL(); // maintenance version
          br.readBL();
          br.readBL();
        }
        if (number >= 500 && dxf.isNotEmpty) _classes[number] = (dxf.toUpperCase(), item == 0x1F2);
      }
    } catch (_) {
      // a damaged or unknown layout: the classes read so far
    }
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

  /// Entity types of the format that carry no geometry the reader takes
  /// (solids, regions, OLE frames…): counted for the import message.
  static const _unsupportedTypes = {33: 'SHAPE', 37: 'REGION', 38: '3DSOLID', 39: 'BODY', 43: 'OLEFRAME', 46: 'TOLERANCE', 74: 'OLE2FRAME'};

  void _readObjectAt(int i) {
    final (h, off) = handleMap[i];
    if (off < 0 || off >= objData.length - 2) return;
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
    final br = _BitReader(objData, start, endByte + 1 <= objData.length ? endByte + 1 : endByte)..codepage = _codepage;
    _stage = 'type';
    final type = ver.index >= DwgVersion.r2010.index ? br.readBOT() : br.readBS();
    typeCounts['$type'] = (typeCounts['$type'] ?? 0) + 1;
    final unsupported = _unsupportedTypes[type];
    if (unsupported != null) _unsupported[unsupported] = (_unsupported[unsupported] ?? 0) + 1;
    // the entities of the classes the reader does not draw (MULTILEADER,
    // IMAGE, WIPEOUT, ACAD_TABLE…), named in the import message
    if (type >= 500) {
      final c = _classes[type];
      if (c != null && c.$2) _unsupported[c.$1] = (_unsupported[c.$1] ?? 0) + 1;
    }
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
    final interesting =
        type == 51 ||
        type == 49 ||
        type == 7 ||
        type == 8 ||
        (type >= 20 && type <= 26) ||
        type == 1 ||
        type == 2 ||
        (type >= 10 && type <= 13) ||
        type == 15 ||
        type == 16 ||
        type == 17 ||
        type == 18 ||
        type == 19 ||
        type == 27 ||
        type == 28 ||
        type == 29 ||
        type == 30 ||
        type == 44 ||
        type == 45 ||
        type == 47 ||
        type == 77 ||
        type == 31 ||
        type == 32 ||
        type == 35 ||
        type == 36 ||
        type == 78;
    _t(handle, 'bitsize=$bitsize');
    if (!interesting) return;
    _stage = 'handle';
    final (_, ownHandle) = br.readH();
    if (ownHandle != handle) warnings.add('handle_mismatch:$handle:$ownHandle');
    _stage = 'eed';
    // EED: kept when it is the hydraulic data the app writes
    _eed = null;
    for (var guard = 0; guard < 200; guard++) {
      final sz = br.readBS();
      if (sz == 0) break;
      br.readH();
      if (!entity || sz > 16384) {
        br.skipBytes(sz);
        continue;
      }
      final data = Uint8List(sz);
      for (var i = 0; i < sz; i++) {
        data[i] = br.readRC();
      }
      final x = readHydraulicXdata([(1001, xdataApp), ..._eedGroups(data)]);
      if (x != null) _eed = x;
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
    final name = DxfReader.plainName(strings != null ? strings.readTU() : br.readTV());
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
      block.xref = isXref || isOverlaid;
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
    final name = DxfReader.plainName(strings != null ? strings.readTU() : br.readTV());
    _t(handle, 'layer name="$name" datapos=${br.pos - (br.pos >> 3 << 3)}');
    _readTableXrefFlags(br);
    var frozen = false, off = false;
    if (ver.index >= DwgVersion.r2000.index) {
      // frozen 1, off 2, frozen in new viewports 4, locked 8, plotted 16, lineweight
      final flags = br.readBS();
      frozen = flags & 1 != 0;
      off = flags & 2 != 0;
    } else {
      frozen = br.readB() == 1;
      br.readB(); // on (the colour sign says it)
      br.readB(); // frozen in new viewports
      br.readB(); // locked
    }
    final (color, rgb) = _readColor(br);
    // R13–R2000 also give an off layer a negative colour
    if (color < 0) off = true;
    final aci = color.abs();
    _layers[handle] = _Layer(name.isEmpty ? '0' : name, aci >= 1 && aci <= 255 ? aci : 7, visible: !off && !frozen, rgb: rgb);
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

  int _readCMC(_BitReader br) => _readColor(br).$1;

  /// A colour (CMC): the colour index (negative for an off layer of R13–
  /// R2000; 256 by layer, 0 by block) and, R2004+, the true colour. R2004+
  /// keep the index in the low byte of the colour word when its method byte
  /// is 0xC3 (the index field itself is then unused), a true colour under
  /// method 0xC2 (drawn with the nearest index).
  (int, int?) _readColor(_BitReader br) {
    var index = br.readBS();
    if (index > 32767) index -= 65536;
    if (ver.index < DwgVersion.r2004.index) return (index, null);
    final word = br.readBL();
    final flags = br.readRC();
    if (ver.index < DwgVersion.r2007.index) {
      if (flags & 1 != 0) br.readTV();
      if (flags & 2 != 0) br.readTV();
    }
    return _colorWord(word, index);
  }

  /// Index and true colour of an R2004+ colour word ([index] when the word
  /// gives none).
  static (int, int?) _colorWord(int word, int index) {
    final method = (word ~/ 16777216) & 0xFF;
    final low = word % 16777216;
    return switch (method) {
      0xC0 => (256, null),
      0xC1 => (0, null),
      0xC2 => (nearestAci(low), low),
      0xC3 => ((low & 0xFF) == 0 ? 7 : low & 0xFF, null),
      _ => (index, null),
    };
  }

  /// Entity colour (ENC): the index and whether a colour book entry (a
  /// handle at the head of the handle stream) is referenced.
  (int, bool) _readENC(_BitReader br) {
    if (ver.index < DwgVersion.r2004.index) {
      final i = br.readBS();
      return (i > 32767 ? i - 65536 : i, false);
    }
    final flags = br.readBS();
    var index = flags & 0x1FF;
    if (flags & 0x8000 != 0) index = _colorWord(br.readBL(), index).$1;
    if (flags & 0x2000 != 0) br.readBL(); // transparency
    return (index, flags & 0x4000 != 0);
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
    final (color, colorBook) = _readENC(br);
    br.readBD(); // ltype scale
    var ltFlags = 0, psFlags = 0, matFlags = 0, shadowFlags = 0;
    if (ver.index >= DwgVersion.r2000.index) {
      ltFlags = br.readBB();
      psFlags = br.readBB();
    }
    if (ver.index >= DwgVersion.r2007.index) {
      matFlags = br.readBB();
      shadowFlags = br.readRC();
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
    _t(
      handle,
      'entmode=$entmode reactors=$numReactors xdicMissing=$xdicMissing noLinks=$noLinks color=$color ltFlags=$ltFlags psFlags=$psFlags matFlags=$matFlags invis=$invis lw=$lw pos=${br.pos - start * 8}',
    );
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
      // a colour book entry is referenced ahead of the other handles
      if (colorBook) hr.readH();
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
      if (ver.index >= DwgVersion.r2007.index && shadowFlags == 3) hr.readH();
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
          e.startAngle = cadNormalizeDeg(br.readBD() * 180 / math.pi);
          e.endAngle = cadNormalizeDeg(br.readBD() * 180 / math.pi);
        }
        if (cz != 0) e.elevation = cz;
      case 27: // POINT
        final x = br.readBD(), y = br.readBD(), z = br.readBD();
        e.points = [Pt(x, y)];
        // zero is kept: the layer decides whether it is a real elevation
        e.elevation = z;
      case 28: // 3DFACE: its corners (spot heights when it has elevations)
        final q = <(Pt, double)>[];
        if (ver.index < DwgVersion.r2000.index) {
          for (var k = 0; k < 4; k++) {
            q.add((Pt(br.readBD(), br.readBD()), br.readBD()));
          }
          br.readBS(); // invisible edges
        } else {
          final noFlags = br.readB() == 1;
          final zZero = br.readB() == 1;
          var x = br.readRD(), y = br.readRD(), z = zZero ? 0.0 : br.readRD();
          q.add((Pt(x, y), z));
          for (var k = 1; k < 4; k++) {
            x = br.readDD(x);
            y = br.readDD(y);
            z = br.readDD(z);
            q.add((Pt(x, y), z));
          }
          if (!noFlags) br.readBS();
        }
        e.points = [for (final c in q) c.$1];
        e.cornerZ = [for (final c in q) c.$2];
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
        final minor = major.perpendicular * ratio * (flip ? -1 : 1);
        e.points = DxfReader.ellipsePoints(c, major, minor, a0, a1);
        e.closed = cadSweepRad(a0, a1) >= 2 * math.pi - 1e-9;
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
          e.points = DxfReader.splineCurve(degree, ctrl, knots: knots, weights: rational || weighted ? weights : const []);
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
                  // one turn at most, whatever the angles say
                  final sweep = ccw ? cadSweepRad(a0, a1) : cadSweepRad(a1, a0);
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
                  final sweep = ccw ? cadSweepRad(a0, a1) : cadSweepRad(a1, a0);
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
                  loop.addAll(DxfReader.splineCurve(degree, ctrl, knots: knots, weights: weights));
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
      case 12: // VERTEX_MESH
      case 13: // VERTEX_PFACE
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
      case 29: // POLYLINE_PFACE and
      case 30: // POLYLINE_MESH: a surface, its vertices become spot heights
        if (type == 29) {
          br.readBS(); // vertices
          br.readBS(); // faces
        } else {
          for (var k = 0; k < 6; k++) {
            br.readBS(); // flags, curve type, M and N counts and densities
          }
        }
        var numOwnedMesh = 0;
        if (ver.index >= DwgVersion.r2004.index) numOwnedMesh = br.readBL();
        readCommonHandles();
        if (ver.index >= DwgVersion.r2004.index) {
          e.ownedVertices = [for (var i = 0; i < numOwnedMesh && i < 1000000; i++) _absHandle(hr.readH(), handle)];
        } else {
          e.firstVertex = _absHandle(hr.readH(), handle);
          e.lastVertex = _absHandle(hr.readH(), handle);
        }
        _entities.add(_withLayer(e, layerHandle, owner));
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
      case 2: // ATTRIB: a text, then its tag and flags
        Pt ins, align;
        int h, v;
        if (ver.index < DwgVersion.r2000.index) {
          final elev = br.readBD();
          ins = Pt(br.readRD(), br.readRD());
          align = Pt(br.readRD(), br.readRD());
          e.ocsMirror = br.readExtrusion();
          br.readBD(); // thickness
          br.readBD(); // oblique
          e.rotation = br.readBD() * 180 / math.pi;
          e.height = br.readBD();
          br.readBD(); // width factor
          e.text = DxfReader.plainText(br.readTV());
          br.readBS(); // generation
          h = br.readBS();
          v = br.readBS();
          if (elev != 0) e.elevation = elev;
        } else {
          final f = br.readRC();
          double elev = 0;
          if (f & 1 == 0) elev = br.readRD();
          ins = Pt(br.readRD(), br.readRD());
          align = ins;
          if (f & 2 == 0) {
            final ax = br.readDD(ins.x);
            align = Pt(ax, br.readDD(ins.y));
          }
          e.ocsMirror = br.readBE(ver);
          br.readBT(ver);
          if (f & 4 == 0) br.readRD();
          if (f & 8 == 0) e.rotation = br.readRD() * 180 / math.pi;
          e.height = br.readRD();
          if (f & 16 == 0) br.readRD();
          e.text = DxfReader.plainText(strings != null ? strings.readTU() : br.readTV());
          h = 0;
          v = 0;
          if (f & 0x20 == 0) br.readBS(); // generation
          if (f & 0x40 == 0) h = br.readBS();
          if (f & 0x80 == 0) v = br.readBS();
          if (elev != 0) e.elevation = elev;
        }
        if (type == 2) {
          var multiline = false;
          if (ver.index >= DwgVersion.r2010.index) br.readRC(); // class version
          if (ver.index >= DwgVersion.r2018.index) multiline = br.readRC() > 1;
          // a multiline attribute carries an MTEXT before its tag: taken as shown
          if (!multiline) {
            e.attribTag = DxfReader.plainName(strings != null ? strings.readTU() : br.readTV()).trim().toUpperCase();
            br.readBS(); // field length
            // invisible attributes are data, not drawing: kept for their value
            if (br.readRC() & 1 != 0) e.invisible = true;
          }
        }
        // a text needs a size to be drawn (0 means "the style's" to CAD programs)
        if (!(e.height > 0 && e.height.isFinite)) e.height = 1;
        // justified texts are placed from their alignment point (fitted and
        // aligned ones run from the first point), as the DXF reader does
        var pos = ins;
        if ((h != 0 || v != 0) && h != 3 && h != 5) {
          final hf = h == 1 || h == 4 ? 0.5 : (h == 2 ? 1.0 : 0.0);
          final vf = h == 4 ? 0.5 : (v == 2 ? 0.5 : (v == 3 ? 1.0 : 0.0));
          pos = cadTextBase(align, e.text, e.height, e.rotation, hf, vf);
        }
        e.points = [pos];
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
        if (!(e.height > 0 && e.height.isFinite)) e.height = 1;
        final attachment = br.readBS().clamp(1, 9);
        br.readBS(); // drawing dir
        br.readBD();
        br.readBD(); // extents
        final raw = strings != null ? strings.readTU() : br.readTV();
        e.text = DxfReader.plainMText(raw).trim();
        e.rotation = math.atan2(ay, ax) * 180 / math.pi;
        // the attachment point (1 top left … 9 bottom right) is the insertion point
        final col = (attachment - 1) % 3, row = (attachment - 1) ~/ 3;
        e.points = [cadTextBase(Pt(ix, iy), e.text, e.height, e.rotation, col / 2, (2 - row) / 2)];
      case 47: // MLINE: its reference line
        br.readBD(); // scale
        br.readRC(); // justification
        br.readBD();
        br.readBD();
        br.readBD(); // base point
        br.readBD();
        br.readBD();
        br.readBD(); // extrusion
        final openClosed = br.readBS();
        final lines = br.readRC();
        final nv = br.readBS();
        final pts = <Pt>[];
        for (var k = 0; k < nv && k < 100000; k++) {
          final x = br.readBD(), y = br.readBD();
          br.readBD();
          for (var q = 0; q < 6; q++) {
            br.readBD(); // vertex and miter directions
          }
          for (var l = 0; l < lines; l++) {
            final ns = br.readBS();
            for (var q = 0; q < ns; q++) {
              br.readBD();
            }
            final na = br.readBS();
            for (var q = 0; q < na; q++) {
              br.readBD();
            }
          }
          pts.add(Pt(x, y));
        }
        e.points = pts;
        e.closed = openClosed == 3;
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
        // the Z of a survey point's block
        final iz = br.readBD();
        if (iz != 0 && iz.isFinite) e.elevation = iz;
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
        final ownedAttribs = ver.index >= DwgVersion.r2004.index && hasAttribs ? br.readBL() : 0;
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
        // its attributes: by them an ATTRIB written in model space (as
        // LibreDWG writes them, with no owner) still belongs to it
        if (hasAttribs) {
          if (ver.index >= DwgVersion.r2004.index) {
            e.ownedAttribs = [for (var i = 0; i < ownedAttribs && i < 100000; i++) _absHandle(hr.readH(), handle)];
          } else {
            e.firstAttrib = _absHandle(hr.readH(), handle);
            e.lastAttrib = _absHandle(hr.readH(), handle);
          }
        }
        _entities.add(_withLayer(e, layerHandle, owner));
        return;
      case 45: // LEADER: its vertices only (a polyline, as the DXF reader takes it)
        br.readB(); // unknown
        br.readBS(); // annotation type
        br.readBS(); // path type
        final n = br.readBL();
        final pts = <Pt>[];
        for (var i = 0; i < n && i < 100000; i++) {
          final x = br.readBD(), y = br.readBD();
          br.readBD();
          pts.add(Pt(x, y));
        }
        e.points = pts;
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
      ..rowSpacing = e.rowSpacing
      ..ownedAttribs = e.ownedAttribs
      ..firstAttrib = e.firstAttrib
      ..lastAttrib = e.lastAttrib
      ..cornerZ = e.cornerZ
      ..attribTag = e.attribTag
      ..invisible = e.invisible
      ..xdata = _eed;
    return n;
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

  // ------------------------------------------------------------ header

  /// `$INSUNITS` of the header variables (R2000 and later; R13 and R14 have
  /// none), or null when the section is missing or does not read as the
  /// format describes it: every variable before it is read in order, and
  /// values that a misaligned read would scramble (scales, extents, the
  /// GUIDs and flags after it) are checked.
  int? _insunits() {
    final sec = _header;
    if (sec == null || sec.length < 64 || ver.index < DwgVersion.r2000.index) return null;
    // the section starts with its sentinel (16 bytes) and size (RL); R2007+
    // then give the size of the data in bits (RL), and files of a
    // maintenance release above 3 (all R2018 ones) a high part of the size
    // before it (both layouts are tried, the expected one first)
    final candidates = <int>[];
    if (ver.index >= DwgVersion.r2007.index) {
      final maint = file.length > 0x12 ? file[0x12] : 0;
      final hiFirst = maint > 3 || ver.index >= DwgVersion.r2018.index;
      candidates.addAll(hiFirst ? [28, 24] : [24, 28]);
    } else {
      candidates.add(20);
    }
    for (final start in candidates) {
      try {
        final v = _headerVariables(_BitReader(sec, start, sec.length)..codepage = _codepage);
        if (v != null) return v;
      } on Object catch (e) {
        // not this layout
        debugLog.add('header@$start: $e');
      }
    }
    return null;
  }

  int? _headerVariables(_BitReader r) {
    final v = ver.index;
    final r2004 = DwgVersion.r2004.index, r2007 = DwgVersion.r2007.index, r2010 = DwgVersion.r2010.index, r2013 = DwgVersion.r2013.index;
    // R2007+ keep the texts in a string stream and the handles in a stream of
    // their own: only the data stream is read here
    void tv() {
      if (v < r2007) r.readTV();
    }

    void h() {
      if (v < r2007) r.readH();
    }

    void bits(int n) {
      for (var i = 0; i < n; i++) {
        r.readB();
      }
    }

    void shorts(int n) {
      for (var i = 0; i < n; i++) {
        r.readBS();
      }
    }

    void doubles(int n) {
      for (var i = 0; i < n; i++) {
        r.readBD();
      }
    }

    bool fine(double x, double lo, double hi) => x.isFinite && x >= lo && x <= hi;
    if (v >= r2013) r.readBLL(); // REQUIREDVERSIONS
    for (var i = 0; i < 4; i++) {
      if (!r.readBD().isFinite) return null; // unit ratios
    }
    if (v < r2007) {
      for (var i = 0; i < 4; i++) {
        r.readTV(); // unit names
      }
    }
    r.readBL();
    r.readBL();
    if (v < r2004) h(); // current viewport entity header (R13–R2000)
    bits(2); // DIMASO DIMSHO
    bits(7); // PLINEGEN ORTHOMODE REGENMODE FILLMODE QTEXTMODE PSLTSCALE LIMCHECK
    if (v >= r2004) r.readB();
    bits(4); // USRTIMER SKPOLY ANGDIR SPLFRAME
    bits(2); // MIRRTEXT WORLDVIEW
    bits(3); // TILEMODE PLIMCHECK VISRETAIN
    bits(2); // DISPSILH PELLIPSE
    r.readBS(); // PROXYGRAPHICS
    r.readBS(); // TREEDEPTH
    shorts(4); // LUNITS LUPREC AUNITS AUPREC
    r.readBS(); // ATTMODE
    r.readBS(); // PDMODE
    if (v >= r2004) {
      r.readBL();
      r.readBL();
      r.readBL();
    }
    shorts(5); // USERI1–5
    shorts(14); // SPLINESEGS … TEXTQLTY
    final ltscale = r.readBD(), textsize = r.readBD();
    doubles(7); // TRACEWID SKETCHINC FILLETRAD THICKNESS ANGBASE PDSIZE PLINEWID
    doubles(9); // USERR1–5 CHAMFERA–D
    final facetres = r.readBD();
    r.readBD(); // CMLSCALE
    final celtscale = r.readBD();
    if (!fine(ltscale, 0, 1e12) || !fine(textsize, 0, 1e12) || !fine(facetres, 0, 100) || !fine(celtscale, 0, 1e12)) return null;
    tv(); // MENU
    for (var i = 0; i < 4; i++) {
      r.readBL(); // TDUCREATE TDUUPDATE (days, milliseconds)
    }
    if (v >= r2004) {
      r.readBL();
      r.readBL();
      r.readBL();
    }
    for (var i = 0; i < 4; i++) {
      r.readBL(); // TDINDWG TDUSRTIMER
    }
    _readCMC(r); // CECOLOR
    r.readH(); // HANDSEED (always in the data stream)
    h(); // CLAYER
    h(); // TEXTSTYLE
    h(); // CELTYPE
    h(); // DIMSTYLE
    h(); // CMLSTYLE
    r.readBD(); // PSVPSCALE
    doubles(9); // PINSBASE PEXTMIN PEXTMAX
    for (var i = 0; i < 4; i++) {
      r.readRD(); // PLIMMIN PLIMMAX
    }
    r.readBD(); // PELEVATION
    doubles(9); // PUCSORG PUCSXDIR PUCSYDIR
    h(); // PUCSNAME
    h(); // PUCSORTHOREF
    r.readBS(); // PUCSORTHOVIEW
    h(); // PUCSBASE
    doubles(18); // PUCSORGTOP … PUCSORGBACK
    doubles(3); // INSBASE
    final ext = [for (var i = 0; i < 6; i++) r.readBD()]; // EXTMIN EXTMAX
    if (ext.any((x) => !x.isFinite)) return null;
    for (var i = 0; i < 4; i++) {
      r.readRD(); // LIMMIN LIMMAX
    }
    r.readBD(); // ELEVATION
    doubles(9); // UCSORG UCSXDIR UCSYDIR
    h(); // UCSNAME
    h(); // UCSORTHOREF
    r.readBS(); // UCSORTHOVIEW
    h(); // UCSBASE
    doubles(18); // UCSORGTOP … UCSORGBACK
    tv(); // DIMPOST
    tv(); // DIMAPOST
    final dimscale = r.readBD();
    doubles(8); // DIMASZ … DIMTM
    if (v >= r2007) {
      doubles(2); // DIMFXL DIMJOGANG
      r.readBS(); // DIMTFILL
      _readCMC(r); // DIMTFILLCLR
    }
    bits(6); // DIMTOL DIMLIM DIMTIH DIMTOH DIMSE1 DIMSE2
    shorts(3); // DIMTAD DIMZIN DIMAZIN
    if (v >= r2007) r.readBS(); // DIMARCSYM
    final dimtxt = r.readBD();
    doubles(7); // DIMCEN … DIMGAP
    if (!fine(dimscale, 0, 1e12) || !fine(dimtxt, 0, 1e12)) return null;
    r.readBD(); // DIMALTRND
    r.readB(); // DIMALT
    r.readBS(); // DIMALTD
    bits(4); // DIMTOFL DIMSAH DIMTIX DIMSOXD
    _readCMC(r); // DIMCLRD
    _readCMC(r); // DIMCLRE
    _readCMC(r); // DIMCLRT
    shorts(11); // DIMADEC … DIMJUST
    bits(2); // DIMSD1 DIMSD2
    shorts(4); // DIMTOLJ DIMTZIN DIMALTZ DIMALTTZ
    r.readB(); // DIMUPT
    r.readBS(); // DIMATFIT
    if (v >= r2007) r.readB(); // DIMFXLON
    if (v >= r2010) {
      r.readB(); // DIMTXTDIRECTION
      doubles(2); // DIMALTMZF DIMMZF
    }
    for (var i = 0; i < 5; i++) {
      h(); // DIMTXSTY DIMLDRBLK DIMBLK DIMBLK1 DIMBLK2
    }
    shorts(2); // DIMLWD DIMLWE
    for (var i = 0; i < 9; i++) {
      h(); // table control objects
    }
    if (v < r2004) h(); // VX control (R13–R2000)
    for (var i = 0; i < 3; i++) {
      h(); // group, mline style and named object dictionaries
    }
    shorts(2); // TSTACKALIGN TSTACKSIZE
    tv(); // HYPERLINKBASE
    tv(); // STYLESHEET
    for (var i = 0; i < 3; i++) {
      h(); // layout, plot settings and plot style dictionaries
    }
    if (v >= r2004) {
      h(); // material dictionary
      h(); // colour dictionary
    }
    if (v >= r2007) h(); // visual style dictionary
    if (v >= r2013) h();
    r.readBL(); // FLAGS
    final insunits = r.readBS();
    final cepsntype = r.readBS();
    if (insunits > 24 || cepsntype > 3) return null;
    if (v < r2007) {
      if (cepsntype == 3) r.readH();
      // the GUIDs: a header read out of step gives no such text
      for (var i = 0; i < 2; i++) {
        final guid = r.readTV();
        if (guid.isNotEmpty && !RegExp(r'^\{[0-9A-Fa-f-]{36}\}$').hasMatch(guid)) return null;
      }
    }
    if (v >= r2004) {
      r.readRC(); // SORTENTS
      final indexctl = r.readRC(), hidetext = r.readRC(), xclipframe = r.readRC(), dimassoc = r.readRC(), halogap = r.readRC();
      final obscolor = r.readBS(), intersectioncolor = r.readBS();
      if (indexctl > 3 || hidetext > 2 || xclipframe > 2 || dimassoc > 2 || halogap > 100 || obscolor > 257 || intersectioncolor > 257) return null;
    }
    return insunits;
  }

  // ------------------------------------------------------------ build

  DwgResult _build() {
    final resolved = _entities.where((e) => _layers.containsKey(e.layerHandle)).length;
    debugLog.add('layerResolved=$resolved/${_entities.length} layerHandles=${_layers.keys.take(6).toList()} entityLayerRefs=${_entities.map((e) => e.layerHandle).toSet().take(6).toList()}');
    debugLog.add(
      'layers=${_layers.length} vertices=${_vertices.length} rawEntities=${_entities.length} entmodes=${_entities.map((e) => e.entmode).fold<Map<int, int>>({}, (m, v) => m..[v] = (m[v] ?? 0) + 1)} blockHeaders=${_blockHeaders.length} modelSpace=$_modelSpaceHandle owners=${_entities.where((e) => e.entmode == 0).map((e) => e.owner).toSet().take(6).toList()}',
    );
    final layerList = <DxfLayer>[];
    final seen = <String>{};
    for (final l in _layers.values) {
      if (seen.add(l.name)) layerList.add(DxfLayer(l.name, color: l.color >= 1 && l.color <= 255 ? l.color : 7, visible: l.visible, rgb: l.rgb));
    }
    String layerOf(_Entity e) => _layers[e.layerHandle]?.name ?? '0';
    int colorOf(_Entity e) => e.color == 0 ? 0 : (e.color >= 1 && e.color <= 255 ? e.color : 256);
    // vertex handles in order: the vertices of an R13–R2000 polyline are a
    // range of them (one sort, then a binary search per polyline)
    final vertexHandles = _vertices.keys.toList()..sort();
    int lowerBound(int h) {
      var lo = 0, hi = vertexHandles.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (vertexHandles[mid] < h) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo;
    }

    List<int> verticesOf(_Entity e) {
      if (e.ownedVertices.isNotEmpty) return e.ownedVertices.where((h) => _vertices[h] != null).toList();
      if (e.lastVertex < e.firstVertex) return const [];
      final out = <int>[];
      for (var i = lowerBound(e.firstVertex); i < vertexHandles.length && vertexHandles[i] <= e.lastVertex; i++) {
        out.add(vertexHandles[i]);
      }
      return out;
    }

    // corners of model space surfaces (3D faces, meshes) already taken
    final corners = <(int, int)>{};
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
        case 2:
        case 44:
          return e.text.isNotEmpty ? DxfEntity(type: 'TEXT', layer: layer, color: color, points: e.points, text: e.text, height: e.height, rotation: e.rotation, elevation: e.elevation) : null;
        case 77:
        case 45:
        case 47:
          return e.points.length >= 2 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 28:
          // a flat face is drawn by its outline (faces with elevations are corners, see [surface])
          final pts = <Pt>[];
          for (final p in e.points) {
            if (pts.isEmpty || pts.last.distanceTo(p) > 1e-12) pts.add(p);
          }
          if (pts.length > 2 && pts.first.distanceTo(pts.last) < 1e-12) pts.removeLast();
          return pts.length >= 3 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: pts, closed: true) : null;
        case 35:
          return e.points.length >= 2 ? DxfEntity(type: 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 36:
          return e.points.length >= 2 ? DxfEntity(type: e.fitSpline ? 'SPLINE' : 'POLYLINE', layer: layer, color: color, points: e.points, closed: e.closed, elevation: e.elevation) : null;
        case 31:
        case 32:
        case 78:
          return e.points.length >= 3
              ? DxfEntity(type: 'HATCH', layer: layer, color: color, points: e.points, closed: true, rotation: e.rotation, height: e.height, solid: e.solidFill, elevation: e.elevation)
              : null;
        case 15:
        case 16:
          final handles = verticesOf(e);
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

    // the INSERT of each ATTRIB: its owner, or, for one written without an
    // owner (in model space, as LibreDWG does), the INSERT that lists it
    final attribOwner = <int, int>{};
    final attribHandles = [
      for (final e in _entities)
        if (e.type == 2) e.handle,
    ]..sort();
    for (final e in _entities) {
      if (e.type != 7 && e.type != 8) continue;
      for (final h in e.ownedAttribs) {
        attribOwner[h] = e.handle;
      }
      if (e.firstAttrib == 0 || e.lastAttrib < e.firstAttrib) continue;
      var lo = 0, hi = attribHandles.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (attribHandles[mid] < e.firstAttrib) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      for (var i = lo; i < attribHandles.length && attribHandles[i] <= e.lastAttrib; i++) {
        attribOwner[attribHandles[i]] = e.handle;
      }
    }
    int? insertOf(_Entity e) => e.type != 2 ? null : (e.entmode == 0 ? e.owner : attribOwner[e.handle]);
    // the attributes of each INSERT (invisible ones included), by its handle
    final attributesOf = <int, Map<String, String>>{};
    for (final e in _entities) {
      final ins = insertOf(e);
      if (ins != null && e.attribTag.isNotEmpty) (attributesOf[ins] ??= {})[e.attribTag] = e.text.trim();
    }
    DxfInsert toInsert(_Entity e) =>
        DxfInsert(
            name: _blocks[e.blockHandle]?.name ?? '',
            layer: layerOf(e),
            color: colorOf(e),
            position: e.points.first,
            scaleX: e.scaleX,
            scaleY: e.scaleY,
            rotation: e.rotation,
            cols: math.max(1, e.cols),
            rows: math.max(1, e.rows),
            colSpacing: e.colSpacing,
            rowSpacing: e.rowSpacing,
            ocsMirror: e.ocsMirror,
          )
          ..z = e.elevation
          ..xdata = e.xdata
          ..attributes.addAll(attributesOf[e.handle] ?? const {});
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
    // a surface with elevations (3D face, polyface or polygon mesh): its
    // corners as spot heights, each place once in model space
    Iterable<DxfEntity> surface(_Entity e, bool model) sync* {
      final layer = layerOf(e), color = colorOf(e);
      final List<(Pt, double)> pts;
      if (e.type == 28) {
        pts = [for (var k = 0; k < e.points.length && k < e.cornerZ.length; k++) (e.points[k], e.cornerZ[k])];
      } else {
        pts = [for (final h in verticesOf(e)) (_vertices[h]!, _vertexZ[h] ?? 0)];
      }
      for (final (p, z) in pts) {
        if (!p.x.isFinite || !p.y.isFinite || !z.isFinite) continue;
        if (model && !corners.add(((p.x * 1000).round(), (p.y * 1000).round()))) continue;
        yield DxfEntity(type: 'POINT', layer: layer, color: color, points: [p], elevation: z);
      }
    }

    // where each entity lives: model space, a block, or nowhere (paper space)
    bool inModelSpace(_Entity e) => e.entmode == 2 || (e.entmode == 0 && (e.owner == _modelSpaceHandle || (_modelSpaceHandle == 0 && !_blockHeaders.contains(e.owner))));
    final insertSpace = <int, _Block?>{}; // INSERT handle → its block (null: model space)
    final insertInModel = <int>{};
    for (final e in _entities) {
      if (e.type != 7 && e.type != 8) continue;
      if (inModelSpace(e)) {
        insertInModel.add(e.handle);
      } else if (e.entmode != 1) {
        insertSpace[e.handle] = blockFor(e);
      }
    }
    for (final e in _entities) {
      // invisible attributes are data (read above), not drawing
      if (e.type == 2 && e.invisible) continue;
      final isInsert = e.type == 7 || e.type == 8 || (e.type >= 20 && e.type <= 26);
      // attributes belong to their INSERT: drawn where it is
      final insert = insertOf(e);
      final ofInsert = insert != null && (insertInModel.contains(insert) || insertSpace.containsKey(insert));
      // model space: entmode 2, or entmode 0 owned by *Model_Space
      final inModel = ofInsert ? insertInModel.contains(insert) : inModelSpace(e);
      // hatch islands become closed polylines next to the hatch
      Iterable<DxfEntity> converted() sync* {
        if ((e.type == 28 && e.cornerZ.any((z) => z != 0)) || e.type == 29 || e.type == 30) {
          yield* surface(e, inModel);
          return;
        }
        DxfEntity world(DxfEntity x) => e.ocsMirror ? DxfReader.mirrorOcs(x) : x;
        final d = toDxf(e);
        if (d == null) return;
        // the hydraulic data of an item the app exported goes with the entity
        yield e.xdata == null ? world(d) : world(d).withXdata(e.xdata);
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
      if (e.entmode == 1 && !ofInsert) continue; // paper space
      final b = ofInsert ? insertSpace[insert] : blockFor(e);
      if (b == null) continue;
      if (isInsert) {
        blockInserts.putIfAbsent(b.handle, () => []).add(toInsert(e));
      } else {
        blockEntities.putIfAbsent(b.handle, () => []).addAll(converted());
      }
    }
    final blocksByName = {for (final b in _blocks.values) b.name: DxfBlock(b.name, b.base, blockEntities[b.handle] ?? const [], blockInserts[b.handle] ?? const [], xref: b.xref)};
    final notes = [..._notes];
    // the hydraulic items the app exported, restored by the import from their data
    final items = DxfReader.hydraulicItems(inserts, blocksByName);
    for (final it in items) {
      ents.addAll(it.fallback);
    }
    // survey points delivered as blocks with an elevation attribute
    final survey = DxfReader.surveyPoints(inserts, blocksByName);
    ents.addAll(survey);
    if (survey.isNotEmpty) notes.add('dxf_survey_points:${survey.length}');
    DxfReader.expandInserts(inserts, blocksByName, ents, warnings: notes);
    DxfReader.flatPointElevations(ents);
    for (final d in ents) {
      counts[d.type] = (counts[d.type] ?? 0) + 1;
    }
    if (_unsupported.isNotEmpty) notes.add('dxf_unsupported:${DxfReader.typeList(_unsupported)}');
    // the drawing's units ($INSUNITS); without them (R13/R14, a header that
    // does not read) metres are assumed and the user is told
    final insunits = _insunits();
    if (insunits == null) notes.add('dwg_units_unknown');
    debugLog.add(
      'blockHeaders=${_blockHeaders.length} blocks=${[for (final b in _blocks.values.take(12)) '${b.name}@${b.handle}:base=${b.base},first=${b.first},last=${b.last},owned=${b.owned.length},ents=${blockEntities[b.handle]?.length ?? 0}']} inserts=${[for (final i in inserts.take(8)) '${i.name}@${i.position} s=${i.scaleX},${i.scaleY} r=${i.rotation}']} nonModel=${_entities.where((e) => e.entmode != 2).map((e) => 'h${e.handle}:t${e.type}:m${e.entmode}:o${e.owner}').take(8).toList()}',
    );
    return DwgResult(
      document: DxfDocument(entities: ents, layers: layerList, unitScale: DxfReader.unitScaleOf(insunits ?? 0), warnings: notes, items: items),
      insunits: insunits,
      version: ver.name,
      warnings: warnings,
      typeCounts: counts,
      objectCount: objectCount,
      debugLog: debugLog,
    );
  }
}
