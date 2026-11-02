/// LAS point clouds (laser scanning and photogrammetry) read as terrain:
/// LAS 1.0–1.4, point data record formats 0–10 with their scale and offset,
/// a classification filter (ground, class 2, by default; withheld points are
/// skipped) and decimation on a grid while reading ([PointGridDecimator]), so
/// the terrain stays within `Terrain.maxTinPoints` whatever the size of the
/// cloud. The reader is a stream: [LasStreamReader.add] takes the file in
/// chunks and keeps only the header, one partial record and the grid.
///
/// The CRS comes from the variable length records: the GeoKeyDirectoryTag
/// (projected or geographic EPSG code, linear and vertical units) or the OGC
/// WKT record (LAS 1.4, also in an extended VLR at the end of the file), and
/// is applied through datum.dart (SIRGAS 2000, SAD 69, Córrego Alegre…).
///
/// Compressed clouds (LAZ) are recognised by the compression bits (6 and 7)
/// of the point data format byte and refused with `las_laz_unsupported`.
///
/// Reference: ASPRS LAS Specification 1.4 – R15 (2019): public header block,
/// VLR / EVLR headers, point data record formats 0–10, GeoTIFF keys
/// (OGC GeoTIFF Standard 1.1) of the GeoKeyDirectoryTag record.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import '../model/terrain.dart';
import 'datum.dart';
import 'dem_tiff.dart' show DemSample;
import 'geo.dart';
import 'point_grid.dart';
import 'work_slicer.dart';

/// The public header block.
class LasHeader {
  LasHeader({
    required this.versionMajor,
    required this.versionMinor,
    required this.headerSize,
    required this.offsetToPoints,
    required this.vlrCount,
    required this.pointFormat,
    required this.recordLength,
    required this.pointCount,
    required this.scale,
    required this.offset,
    required this.min,
    required this.max,
    required this.globalEncoding,
    required this.systemId,
    required this.software,
    this.evlrStart = 0,
    this.evlrCount = 0,
  });
  final int versionMajor, versionMinor, headerSize, offsetToPoints, vlrCount, pointFormat, recordLength, pointCount, globalEncoding;
  final (double, double, double) scale, offset, min, max;
  final String systemId, software;
  final int evlrStart, evlrCount;
  String get version => '$versionMajor.$versionMinor';

  /// The CRS is given as WKT (global encoding bit 4).
  bool get wkt => globalEncoding & 0x10 != 0;

  /// Bytes of the standard part of each point record format.
  static const recordSizes = [20, 28, 26, 34, 57, 63, 30, 36, 38, 59, 67];

  /// Parses the header; throws a [FormatException] with a code
  /// (`las_not_las`, `las_truncated`, `las_version_unsupported`,
  /// `las_laz_unsupported`, `las_format_unsupported:<n>`).
  static LasHeader parse(Uint8List b) {
    if (b.length < 4 || b[0] != 0x4C || b[1] != 0x41 || b[2] != 0x53 || b[3] != 0x46) throw const FormatException('las_not_las');
    if (b.length < 227) throw const FormatException('las_truncated');
    final d = ByteData.sublistView(b);
    final major = b[24], minor = b[25];
    if (major != 1 || minor > 4) throw const FormatException('las_version_unsupported');
    final rawFormat = b[104];
    if (rawFormat & 0xC0 != 0) throw const FormatException('las_laz_unsupported');
    if (rawFormat > 10) throw FormatException('las_format_unsupported:$rawFormat');
    final recLen = d.getUint16(105, Endian.little);
    if (recLen < recordSizes[rawFormat]) throw FormatException('las_format_unsupported:$rawFormat');
    double f64(int o) => d.getFloat64(o, Endian.little);
    final headerSize = d.getUint16(94, Endian.little);
    var count = d.getUint32(107, Endian.little);
    var evlrStart = 0, evlrCount = 0;
    if (minor >= 4 && b.length >= 255 && headerSize >= 375) {
      evlrStart = _u64(d, 235);
      evlrCount = d.getUint32(243, Endian.little);
      final c64 = _u64(d, 247);
      if (c64 > 0) count = c64;
    }
    String str(int o, int n) => latin1.decode(b.sublist(o, o + n).takeWhile((c) => c != 0).toList()).trim();
    return LasHeader(
      versionMajor: major,
      versionMinor: minor,
      headerSize: headerSize,
      offsetToPoints: d.getUint32(96, Endian.little),
      vlrCount: d.getUint32(100, Endian.little),
      pointFormat: rawFormat,
      recordLength: recLen,
      pointCount: count,
      scale: (f64(131), f64(139), f64(147)),
      offset: (f64(155), f64(163), f64(171)),
      max: (f64(179), f64(195), f64(211)),
      min: (f64(187), f64(203), f64(219)),
      globalEncoding: d.getUint16(6, Endian.little),
      systemId: str(26, 32),
      software: str(58, 32),
      evlrStart: evlrStart,
      evlrCount: evlrCount,
    );
  }
}

/// Unsigned 64-bit little-endian read as two halves (exact to 2⁵³ on every
/// platform; 64-bit reads are not available on the web).
int _u64(ByteData d, int o) => d.getUint32(o, Endian.little) + d.getUint32(o + 4, Endian.little) * 4294967296;

class LasImportResult {
  LasImportResult({
    required this.header,
    required this.samples,
    required this.georef,
    required this.crs,
    required this.pointsRead,
    required this.classCounts,
    required this.cellSize,
    required this.warnings,
    required this.localOrigin,
  });
  final LasHeader header;

  /// Terrain samples in local coordinates (elevations in metres).
  final List<DemSample> samples;
  final GeoReference? georef;
  final CrsInfo crs;

  /// Records read (withheld ones included).
  final int pointsRead;

  /// Points per classification code (withheld points excluded).
  final Map<int, int> classCounts;

  /// Grid cell size (units of the file).
  final double cellSize;

  /// Message codes: CRS problems, `crs_datum_shift:…`, `las_no_class_points:<classes>`,
  /// `las_lowest_points`, `las_truncated_points:<read>:<expected>`,
  /// `las_points_capped:<n>` (a header without bounds: only the first points).
  final List<String> warnings;
  final Pt localOrigin;
}

/// Reads a LAS file given in chunks (any size) and decimates it on the fly.
class LasStreamReader {
  /// [classes] are the classification codes kept (null: every point); when
  /// no point has them and [fallbackToLowest] is set, the lowest point of
  /// each cell of the whole cloud is taken instead (bare ground from an
  /// unclassified cloud). [maxPoints] bounds the samples
  /// (`Terrain.maxTinPoints` by default).
  LasStreamReader({this.classes = const {2}, int? maxPoints, this.reduce = GridReduce.mean, this.fallbackToLowest = true}) : maxPoints = maxPoints ?? Terrain.maxTinPoints;

  final Set<int>? classes;
  final int maxPoints;
  final GridReduce reduce;
  final bool fallbackToLowest;

  LasHeader? _header;
  final _head = BytesBuilder(copy: true);
  Uint8List _carry = Uint8List(0);
  int _pos = 0; // absolute offset of the next byte to arrive
  int _read = 0;
  final _classes = <int, int>{};
  PointGridDecimator? _kept, _lowest;

  /// Points (x, y, z, of the kept classes) of a header without usable
  /// bounds, decimated at the end; at most [_maxUnbounded] of them.
  List<(double, double, double, bool)>? _unbounded;
  static const _maxUnbounded = 4000000;
  bool _capped = false;
  final _vlrs = <(String, int, Uint8List)>[];
  final _evlr = BytesBuilder(copy: true);
  static const _maxEvlrBytes = 16 << 20;

  LasHeader? get header => _header;

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    var data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    var start = _pos;
    _pos += data.length;
    if (_header == null) {
      _head.add(data);
      final h = _head.toBytes();
      if (h.length < 227) return;
      final hd = ByteData.sublistView(h);
      if (h.length >= 4 && (h[0] != 0x4C || h[1] != 0x41 || h[2] != 0x53 || h[3] != 0x46)) throw const FormatException('las_not_las');
      final offsetToPoints = hd.getUint32(96, Endian.little);
      if (h.length < offsetToPoints) return;
      final header = LasHeader.parse(h);
      _readVlrs(h, header);
      _header = header;
      _start(header);
      // what came after the header and VLRs is point data
      data = h.sublist(offsetToPoints);
      start = offsetToPoints;
    }
    _points(data, start);
  }

  void _readVlrs(Uint8List h, LasHeader header) {
    var o = header.headerSize;
    final d = ByteData.sublistView(h);
    for (var i = 0; i < header.vlrCount && o + 54 <= header.offsetToPoints; i++) {
      final user = latin1.decode(h.sublist(o + 2, o + 18).takeWhile((c) => c != 0).toList());
      final id = d.getUint16(o + 18, Endian.little);
      final len = d.getUint16(o + 20, Endian.little);
      final end = math.min(o + 54 + len, h.length);
      _vlrs.add((user, id, h.sublist(o + 54, end)));
      o += 54 + len;
    }
  }

  void _start(LasHeader h) {
    final (x0, y0, _) = h.min;
    final (x1, y1, _) = h.max;
    final ok = x0.isFinite && y0.isFinite && x1.isFinite && y1.isFinite && x1 >= x0 && y1 >= y0 && (x1 > x0 || y1 > y0);
    if (ok) {
      _kept = PointGridDecimator(minX: x0, minY: y0, maxX: x1, maxY: y1, maxCells: maxPoints, reduce: reduce);
      if (fallbackToLowest && classes != null) _lowest = PointGridDecimator(minX: x0, minY: y0, maxX: x1, maxY: y1, maxCells: maxPoints, reduce: GridReduce.lowest);
    } else {
      // no usable bounds in the header: keep the points, decimate at the end
      _unbounded = [];
    }
  }

  void _points(Uint8List data, int start) {
    final h = _header!;
    final rl = h.recordLength;
    final end = h.offsetToPoints + h.pointCount * rl;
    var buf = data;
    var bufStart = start;
    if (_carry.isNotEmpty) {
      buf = Uint8List(_carry.length + data.length)
        ..setAll(0, _carry)
        ..setAll(_carry.length, data);
      bufStart = start - _carry.length;
      _carry = Uint8List(0);
    }
    final d = ByteData.sublistView(buf);
    final (sx, sy, sz) = h.scale;
    final (ox, oy, oz) = h.offset;
    final modern = h.pointFormat >= 6;
    var o = 0;
    // bytes before the first record still to read (none once started)
    while (bufStart + o < end && o + rl <= buf.length && _read < h.pointCount) {
      final x = d.getInt32(o, Endian.little) * sx + ox;
      final y = d.getInt32(o + 4, Endian.little) * sy + oy;
      final z = d.getInt32(o + 8, Endian.little) * sz + oz;
      final int cls;
      final bool withheld;
      if (modern) {
        cls = buf[o + 16];
        withheld = buf[o + 15] & 0x04 != 0;
      } else {
        cls = buf[o + 15] & 0x1F;
        withheld = buf[o + 15] & 0x80 != 0;
      }
      _read++;
      o += rl;
      if (withheld) continue;
      _classes[cls] = (_classes[cls] ?? 0) + 1;
      final keep = classes == null || classes!.contains(cls);
      if (_unbounded != null) {
        if (_unbounded!.length >= _maxUnbounded) {
          _capped = true;
        } else if (keep || fallbackToLowest) {
          _unbounded!.add((x, y, z, keep));
        }
        continue;
      }
      if (keep) _kept!.add(x, y, z);
      _lowest?.add(x, y, z);
    }
    if (_read < h.pointCount && bufStart + o < end) {
      _carry = buf.sublist(o);
      return;
    }
    // past the points: extended VLRs (LAS 1.4) may follow
    if (h.evlrCount > 0 && h.evlrStart > 0) {
      final from = math.max(h.evlrStart - bufStart, o);
      if (from < buf.length && _evlr.length < _maxEvlrBytes) _evlr.add(buf.sublist(from));
    }
  }

  /// Finishes the read: the CRS from the (E)VLRs and the samples placed in
  /// the project frame (relative to [georef] when given).
  LasImportResult close({GeoReference? georef}) {
    final h = _header ?? (throw const FormatException('las_truncated'));
    final warnings = <String>[];
    if (_read < h.pointCount) warnings.add('las_truncated_points:$_read:${h.pointCount}');
    // extended VLRs
    final ev = _evlr.toBytes();
    if (ev.isNotEmpty) {
      final d = ByteData.sublistView(ev);
      var o = 0;
      for (var i = 0; i < h.evlrCount && o + 60 <= ev.length; i++) {
        final user = latin1.decode(ev.sublist(o + 2, o + 18).takeWhile((c) => c != 0).toList());
        final id = d.getUint16(o + 18, Endian.little);
        final len = _u64(d, o + 20);
        final end = math.min(o + 60 + len, ev.length);
        _vlrs.add((user, id, ev.sublist(o + 60, end)));
        o = o + 60 + len;
      }
    }
    final (crs, zUnit) = _crs(warnings);
    // the samples
    var pts = <(double, double, double)>[];
    double cell;
    if (_unbounded != null) {
      if (_capped) warnings.add('las_points_capped:$_maxUnbounded');
      final kept = _unbounded!.where((p) => p.$4).toList();
      final fallback = kept.isEmpty && fallbackToLowest && classes != null && _unbounded!.isNotEmpty;
      final use = fallback ? _unbounded! : kept;
      if (fallback) {
        warnings
          ..add('las_no_class_points:${(classes!.toList()..sort()).join(',')}')
          ..add('las_lowest_points');
      }
      if (use.isNotEmpty) {
        final b = Bounds.ofPoints(use.map((p) => Pt(p.$1, p.$2)));
        final dec = PointGridDecimator(minX: b.minX, minY: b.minY, maxX: b.maxX, maxY: b.maxY, maxCells: maxPoints, reduce: fallback ? GridReduce.lowest : reduce);
        for (final p in use) {
          dec.add(p.$1, p.$2, p.$3);
        }
        pts = dec.result();
        cell = dec.cell;
      } else {
        cell = 0;
      }
    } else {
      pts = _kept!.result();
      cell = _kept!.cell;
      if (pts.isEmpty && _lowest != null && _lowest!.cellCount > 0) {
        warnings
          ..add('las_no_class_points:${(classes!.toList()..sort()).join(',')}')
          ..add('las_lowest_points');
        pts = _lowest!.result();
        cell = _lowest!.cell;
      }
    }
    final placement = GeoPlacement.plan(crs, [for (final p in pts) (p.$1, p.$2)], georef: georef);
    warnings.addAll(placement.warnings);
    final samples = [for (final (x, y, z) in pts) DemSample(placement.place(x, y), z * zUnit)];
    return LasImportResult(
      header: h,
      samples: samples,
      georef: placement.georef,
      crs: placement.crs,
      pointsRead: _read,
      classCounts: Map.unmodifiable(_classes),
      cellSize: cell,
      warnings: warnings,
      localOrigin: placement.localOrigin,
    );
  }

  /// The CRS of the (E)VLRs (WKT first, then the GeoTIFF keys) and the
  /// metres per unit of the elevations.
  (CrsInfo?, double) _crs(List<String> warnings) {
    CrsInfo? fromWkt;
    for (final (user, id, data) in _vlrs) {
      if (user == 'LASF_Projection' && id == 2112) {
        final text = utf8.decode(data.takeWhile((c) => c != 0).toList(), allowMalformed: true);
        if (text.trim().isNotEmpty) fromWkt = parseCrs(text);
      }
    }
    // GeoKeyDirectoryTag
    Map<int, int>? keys;
    for (final (user, id, data) in _vlrs) {
      if (user != 'LASF_Projection' || id != 34735 || data.length < 8) continue;
      final d = ByteData.sublistView(data);
      final n = d.getUint16(6, Endian.little);
      keys = {};
      for (var k = 0; k < n && 8 + 8 * k + 8 <= data.length; k++) {
        final key = d.getUint16(8 + 8 * k, Endian.little), loc = d.getUint16(10 + 8 * k, Endian.little), value = d.getUint16(14 + 8 * k, Endian.little);
        if (loc == 0) keys[key] = value;
      }
    }
    double unitOf(int? code) => switch (code) {
      9002 => 0.3048,
      9003 => 1200 / 3937,
      _ => 1.0,
    };
    var zUnit = keys == null ? 1.0 : unitOf(keys[4099] ?? keys[3076]);
    CrsInfo? fromKeys;
    if (keys != null) {
      final model = keys[1024];
      final projected = keys[3072], geographic = keys[2048];
      if (projected != null && projected != 32767) {
        fromKeys = crsFromEpsg(projected);
      } else if (model == 2 && geographic != null && geographic != 32767) {
        fromKeys = crsFromEpsg(geographic);
      } else if (model == 3) {
        fromKeys = const CrsInfo(kind: CrsKind.unknown, name: 'geocentric', problem: 'crs_geocentric');
      } else if (model != null) {
        fromKeys = const CrsInfo(kind: CrsKind.unknown, name: 'user-defined', problem: 'crs_unparsed');
      }
      // projected coordinates in feet with an EPSG code in metres would be
      // inconsistent: the code wins; a user-defined system keeps the unit
      if (fromKeys != null && fromKeys.kind == CrsKind.unknown && keys[3076] != null && unitOf(keys[3076]) != 1) {
        fromKeys = CrsInfo(kind: CrsKind.unknown, name: fromKeys.name, unitM: unitOf(keys[3076]), problem: fromKeys.problem);
      }
    }
    if (fromWkt != null && fromWkt.recognised) {
      if (keys?[4099] == null) zUnit = fromWkt.unitM;
      return (fromWkt, zUnit);
    }
    if (fromKeys != null) return (fromKeys, zUnit);
    return (fromWkt, zUnit);
  }
}

class LasReader {
  /// Reads a whole file held in memory (through the stream reader).
  static LasImportResult read(Uint8List bytes, {GeoReference? georef, Set<int>? classes = const {2}, int? maxPoints, GridReduce reduce = GridReduce.mean, bool fallbackToLowest = true}) {
    if (bytes.length >= 4 && !(bytes[0] == 0x4C && bytes[1] == 0x41 && bytes[2] == 0x53 && bytes[3] == 0x46)) throw const FormatException('las_not_las');
    final r = LasStreamReader(classes: classes, maxPoints: maxPoints, reduce: reduce, fallbackToLowest: fallbackToLowest);
    // in pieces of 1 MB, as a file would arrive
    for (var o = 0; o < bytes.length; o += 1 << 20) {
      r.add(Uint8List.sublistView(bytes, o, math.min(o + (1 << 20), bytes.length)));
    }
    return r.close(georef: georef);
  }

  /// [read] in slices of [slicer] (the interface stays responsive and the
  /// user can cancel).
  static Future<LasImportResult> readAsync(Uint8List bytes, WorkSlicer slicer, {GeoReference? georef, Set<int>? classes = const {2}, int? maxPoints}) async {
    if (bytes.length >= 4 && !(bytes[0] == 0x4C && bytes[1] == 0x41 && bytes[2] == 0x53 && bytes[3] == 0x46)) throw const FormatException('las_not_las');
    final r = LasStreamReader(classes: classes, maxPoints: maxPoints);
    for (var o = 0; o < bytes.length; o += 1 << 18) {
      r.add(Uint8List.sublistView(bytes, o, math.min(o + (1 << 18), bytes.length)));
      if (slicer.due) await slicer.pause(0.9 * o / bytes.length);
    }
    return r.close(georef: georef);
  }

  /// The header alone (to show the point count, format and bounds before
  /// reading).
  static LasHeader readHeader(Uint8List bytes) => LasHeader.parse(bytes);
}
