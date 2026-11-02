/// ESRI Shapefile reader (.shp, optionally with .dbf attributes and .prj
/// inside a .zip) producing a [DxfDocument]. Points, polylines, polygons and
/// multipoints, with Z variants; elevations come from Z values or from an
/// attribute named like ELEV / Z / COTA.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../model/geometry.dart';
import 'codepages.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';
import 'safe_archive.dart';
import 'work_slicer.dart';

class ShpImportResult {
  ShpImportResult({required this.document, required this.recordCount, required this.georef, required this.geographic, this.crs = '', this.warnings = const []});
  final DxfDocument document;
  final int recordCount;
  final GeoReference? georef;
  final bool geographic;
  final String crs;

  /// Placement codes (`crs_missing`, `crs_assumed_wgs84`, `crs_datum_shift:…`, CRS problems).
  final List<String> warnings;
}

class ShpReader {
  /// Parses a .shp (optionally with .dbf rows, .prj text and the .shx
  /// index). A record whose length is damaged ends the reading with the
  /// note `shp_truncated` (the index, when given, finds the records that
  /// follow it).
  static ShpImportResult parse(Uint8List shp, {Uint8List? dbf, String? prj, String? cpg, Uint8List? shx, GeoReference? georef, String layer = 'SHP'}) {
    final r = _ShpRecords(shp, shx);
    while (!r.step(1 << 30)) {}
    return _finish(r, dbf: dbf, prj: prj, cpg: cpg, georef: georef, layer: layer);
  }

  /// [parse] with the records read in slices of [slicer] (a large
  /// shapefile: the interface stays responsive and the user can cancel).
  static Future<ShpImportResult> parseAsync(Uint8List shp, WorkSlicer slicer, {Uint8List? dbf, String? prj, String? cpg, Uint8List? shx, GeoReference? georef, String layer = 'SHP'}) async {
    final r = _ShpRecords(shp, shx);
    while (!r.step(2000)) {
      if (slicer.due) await slicer.pause(0.8 * r.fraction);
    }
    await slicer.pause(0.85);
    return _finish(r, dbf: dbf, prj: prj, cpg: cpg, georef: georef, layer: layer);
  }

  static ShpImportResult _finish(_ShpRecords r, {Uint8List? dbf, String? prj, String? cpg, GeoReference? georef, required String layer}) {
    final attrs = dbf != null ? _readDbf(dbf, cpg: cpg) : const <Map<String, String>>[];
    final elevField = attrs.isEmpty ? null : _elevationField(attrs.first.keys);
    final nameField = attrs.isEmpty ? null : _nameField(attrs.first.keys);
    final notes = <String>[];
    final raw = r.raw;
    final rec = r.count;
    if (r.damaged) notes.add('shp_truncated');
    // the .prj (any datum, any UTM zone) or, without one, degrees recognised
    // by their range and precision; see GeoPlacement
    final allPts = raw.expand((s) => s.parts.expand((p) => p)).toList();
    final placement = GeoPlacement.plan(prj != null ? parseCrs(prj) : null, [for (final p in allPts) (p.x, p.y)], georef: georef);
    final isGeo = placement.crs.kind == CrsKind.geographic;
    final ref = placement.georef;
    Pt project(Pt p) => placement.place(p.x, p.y);
    final doc = DxfDocument(layers: [DxfLayer(layer, color: 3)]);
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      final a = i < attrs.length ? attrs[i] : const <String, String>{};
      final elevAttr = elevField != null ? double.tryParse((a[elevField] ?? '').replaceAll(',', '.').trim()) : null;
      final name = nameField != null ? (a[nameField] ?? '') : '';
      for (var k = 0; k < s.parts.length; k++) {
        final pts = s.parts[k].map(project).toList();
        final zs = s.z.length > k ? s.z[k] : const <double>[];
        final sameZ = zs.isNotEmpty && zs.every((z) => (z - zs.first).abs() < 1e-6);
        final elev = elevAttr ?? (sameZ ? zs.first : null);
        if (s.isPoint) {
          for (var j = 0; j < pts.length; j++) {
            doc.entities.add(DxfEntity(type: 'POINT', layer: layer, points: [pts[j]], elevation: elevAttr ?? (zs.length > j ? zs[j] : null), name: name));
          }
        } else if (pts.length >= 2) {
          var ring = pts;
          if (s.isPolygon && ring.length > 3 && ring.first.distanceTo(ring.last) < 1e-9) ring = ring.sublist(0, ring.length - 1);
          doc.entities.add(DxfEntity(type: 'POLYLINE', layer: layer, points: ring, closed: s.isPolygon, elevation: elev, name: name));
        }
      }
    }
    return ShpImportResult(document: doc, recordCount: rec, georef: ref, geographic: isGeo, crs: prj != null ? _crsName(prj) : '', warnings: [...placement.warnings, ...notes]);
  }

  /// True when every point fits the lat/lon range and at least half of them
  /// carry four or more decimals (survey coordinates in metres are rounded to
  /// millimetres at most; degrees need five decimals for metre precision).
  static bool looksLikeDegrees(List<Pt> pts) {
    if (pts.isEmpty || !pts.every((p) => p.x.abs() <= 180 && p.y.abs() <= 90)) return false;
    var fine = 0;
    for (final p in pts) {
      if (_decimals(p.x) >= 4 && _decimals(p.y) >= 4) fine++;
    }
    return fine * 2 >= pts.length;
  }

  static int _decimals(double v) {
    for (var d = 0; d <= 6; d++) {
      final s = v * math.pow(10, d);
      if ((s - s.roundToDouble()).abs() < 1e-6) return d;
    }
    return 7;
  }

  /// [parseAny] with the records read in slices of [slicer].
  static Future<ShpImportResult> parseAnyAsync(String name, Uint8List bytes, WorkSlicer slicer, {GeoReference? georef}) async {
    if (!name.toLowerCase().endsWith('.zip')) {
      final layer = name.split('/').last.replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
      return parseAsync(bytes, slicer, georef: georef, layer: layer.isEmpty ? 'SHP' : layer);
    }
    final arc = openZip(bytes);
    ArchiveFile? shp, dbf, prj, cpg, shx;
    for (final f in arc) {
      final l = f.name.toLowerCase();
      if (l.endsWith('.shp')) shp ??= f;
      if (l.endsWith('.dbf')) dbf ??= f;
      if (l.endsWith('.prj')) prj ??= f;
      if (l.endsWith('.cpg')) cpg ??= f;
      if (l.endsWith('.shx')) shx ??= f;
    }
    if (shp == null) throw const FormatException('shp_zip_no_shp');
    final layer = shp.name.split('/').last.replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
    await slicer.pause(0.02);
    return parseAsync(
      zipEntryBytes(shp),
      slicer,
      dbf: dbf != null ? zipEntryBytes(dbf) : null,
      prj: prj != null ? latin1.decode(zipEntryBytes(prj, maxBytes: 1 << 20)) : null,
      cpg: cpg != null ? latin1.decode(zipEntryBytes(cpg, maxBytes: 1 << 16)).trim() : null,
      shx: shx != null ? zipEntryBytes(shx) : null,
      georef: georef,
      layer: layer.isEmpty ? 'SHP' : layer,
    );
  }

  /// Parses a .zip holding .shp (+ .dbf, .prj, .cpg) or a raw .shp.
  static ShpImportResult parseAny(String name, Uint8List bytes, {GeoReference? georef}) {
    if (name.toLowerCase().endsWith('.zip')) {
      final arc = openZip(bytes);
      ArchiveFile? shp, dbf, prj, cpg, shx;
      for (final f in arc) {
        final l = f.name.toLowerCase();
        if (l.endsWith('.shp')) shp ??= f;
        if (l.endsWith('.dbf')) dbf ??= f;
        if (l.endsWith('.prj')) prj ??= f;
        if (l.endsWith('.cpg')) cpg ??= f;
        if (l.endsWith('.shx')) shx ??= f;
      }
      if (shp == null) throw const FormatException('shp_zip_no_shp');
      final layer = shp.name.split('/').last.replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
      // only the parts of the shapefile, each up to the ceiling of an entry
      return parse(
        zipEntryBytes(shp),
        dbf: dbf != null ? zipEntryBytes(dbf) : null,
        prj: prj != null ? latin1.decode(zipEntryBytes(prj, maxBytes: 1 << 20)) : null,
        cpg: cpg != null ? latin1.decode(zipEntryBytes(cpg, maxBytes: 1 << 16)).trim() : null,
        shx: shx != null ? zipEntryBytes(shx) : null,
        georef: georef,
        layer: layer.isEmpty ? 'SHP' : layer,
      );
    }
    final layer = name.split('/').last.replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
    return parse(bytes, georef: georef, layer: layer.isEmpty ? 'SHP' : layer);
  }

  static _Shape _parseShape(ByteData bd, int start, int type) {
    final parts = <List<Pt>>[];
    final zs = <List<double>>[];
    switch (type) {
      case 1 || 11 || 21: // point
        final p = Pt(bd.getFloat64(start + 4, Endian.little), bd.getFloat64(start + 12, Endian.little));
        parts.add([p]);
        if (type == 11) zs.add([bd.getFloat64(start + 20, Endian.little)]);
        return _Shape(parts, zs, isPoint: true);
      case 8 || 18 || 28: // multipoint
        final n = bd.getInt32(start + 36, Endian.little);
        final pts = <Pt>[];
        for (var i = 0; i < n; i++) {
          pts.add(Pt(bd.getFloat64(start + 40 + i * 16, Endian.little), bd.getFloat64(start + 48 + i * 16, Endian.little)));
        }
        parts.add(pts);
        if (type == 18) {
          final zOff = start + 40 + n * 16 + 16;
          zs.add([for (var i = 0; i < n; i++) bd.getFloat64(zOff + i * 8, Endian.little)]);
        }
        return _Shape(parts, zs, isPoint: true);
      case 3 || 5 || 13 || 15 || 23 || 25:
        final numParts = bd.getInt32(start + 36, Endian.little);
        final numPoints = bd.getInt32(start + 40, Endian.little);
        final partIdx = [for (var i = 0; i < numParts; i++) bd.getInt32(start + 44 + i * 4, Endian.little)];
        final ptsOff = start + 44 + numParts * 4;
        final all = [for (var i = 0; i < numPoints; i++) Pt(bd.getFloat64(ptsOff + i * 16, Endian.little), bd.getFloat64(ptsOff + 8 + i * 16, Endian.little))];
        List<double> allZ = const [];
        if (type == 13 || type == 15) {
          final zOff = ptsOff + numPoints * 16 + 16;
          if (zOff + numPoints * 8 <= bd.lengthInBytes) allZ = [for (var i = 0; i < numPoints; i++) bd.getFloat64(zOff + i * 8, Endian.little)];
        }
        for (var k = 0; k < numParts; k++) {
          final a = partIdx[k], b = k + 1 < numParts ? partIdx[k + 1] : numPoints;
          parts.add(all.sublist(a, b));
          if (allZ.isNotEmpty) zs.add(allZ.sublist(a, b));
        }
        return _Shape(parts, zs, isPolygon: type == 5 || type == 15 || type == 25);
      default:
        return _Shape(const [], const []);
    }
  }

  /// dBase III/IV: returns one map per record (field name → text). Text is
  /// decoded per the .cpg file when given, else as UTF-8 when valid (QGIS,
  /// GDAL) and Latin-1 otherwise (older GIS software).
  static List<Map<String, String>> _readDbf(Uint8List dbf, {String? cpg}) {
    if (dbf.length < 32) return const [];
    final c = (cpg ?? '').toUpperCase().trim();
    final forceUtf8 = c.contains('UTF') || c.contains('65001');
    // the code page the .cpg names ("1252", "CP1251", "ANSI 1250", "ISO-8859-1",
    // "GBK", "BIG5"), else the East Asian language driver of the header
    final page = codepageFromCpg(c) ?? codepageFromDbfLanguage(dbf[29]);
    final forced = page != null && supportedCodepages.contains(page) ? page : null;
    String decode(List<int> b) {
      if (forceUtf8) return utf8.decode(b, allowMalformed: true);
      if (forced != null) return decodeCodepage(b, forced);
      try {
        return utf8.decode(b);
      } catch (_) {
        // older GIS software: Windows' Western page (not Latin-1, which
        // turns "–" and the curly quotes into control characters)
        return decodeCodepage(b, 1252);
      }
    }

    final bd = ByteData.sublistView(dbf);
    final recCount = bd.getUint32(4, Endian.little);
    final headerLen = bd.getUint16(8, Endian.little);
    final recLen = bd.getUint16(10, Endian.little);
    final fields = <(String, int)>[];
    var off = 32;
    while (off + 32 <= headerLen && dbf[off] != 0x0D) {
      final nameBytes = dbf.sublist(off, off + 11).takeWhile((b) => b != 0).toList();
      final name = latin1.decode(nameBytes).trim();
      final len = dbf[off + 16];
      fields.add((name, len));
      off += 32;
    }
    final out = <Map<String, String>>[];
    // a record of no length would repeat for every count of a damaged header
    if (recLen <= 1) return out;
    var pos = headerLen;
    for (var r = 0; r < recCount && pos + recLen <= dbf.length; r++) {
      var p = pos + 1; // deletion flag
      final m = <String, String>{};
      for (final (name, len) in fields) {
        if (p + len > pos + recLen) break;
        m[name] = decode(dbf.sublist(p, p + len)).trim();
        p += len;
      }
      out.add(m);
      pos += recLen;
    }
    return out;
  }

  static String? _elevationField(Iterable<String> names) {
    const keys = ['ELEV', 'ELEVATION', 'Z', 'COTA', 'ALT', 'ALTITUDE', 'HEIGHT', 'CONTOUR', 'LEVEL', 'NIVEL'];
    for (final n in names) {
      if (keys.contains(n.toUpperCase())) return n;
    }
    for (final n in names) {
      final u = n.toUpperCase();
      if (u.contains('ELEV') || u.contains('COTA') || u.contains('ALT')) return n;
    }
    return null;
  }

  static String? _nameField(Iterable<String> names) {
    const keys = ['NAME', 'NOME', 'ID', 'LABEL', 'DESC', 'DESCRICAO', 'NOMBRE'];
    for (final n in names) {
      if (keys.contains(n.toUpperCase())) return n;
    }
    return null;
  }

  static String _crsName(String prj) {
    final m = RegExp(r'^(PROJCS|GEOGCS)\["([^"]+)"').firstMatch(prj.trim());
    return m?.group(2) ?? '';
  }
}

/// The records of a .shp read a number at a time: from the .shx index when
/// there is one, else one after the other (a length of zero or less, or one
/// past the end, stops the reading as damaged).
class _ShpRecords {
  _ShpRecords(this.shp, Uint8List? shx) : bd = ByteData.sublistView(shp) {
    if (shp.length < 100 || bd.getInt32(0, Endian.big) != 9994) throw const FormatException('shp_bad_header');
    fileLength = math.min(bd.getInt32(24, Endian.big) * 2, shp.length);
    index = shx != null && shx.length >= 100 && ByteData.sublistView(shx).getInt32(0, Endian.big) == 9994 ? ByteData.sublistView(shx) : null;
    indexLength = shx?.length ?? 0;
  }
  final Uint8List shp;
  final ByteData bd;
  late final int fileLength, indexLength;
  late final ByteData? index;
  final raw = <_Shape>[];
  var count = 0;
  var damaged = false;
  var _at = 100, _done = false;

  double get fraction => _done ? 1 : _at / math.max(1, index != null ? indexLength : fileLength);

  void _record(int start, int len) {
    if (len < 4 || start + len > shp.length) {
      damaged = true;
      return;
    }
    final type = bd.getInt32(start, Endian.little);
    try {
      raw.add(ShpReader._parseShape(ByteData.sublistView(shp, start, start + len), 0, type));
      count++;
    } on RangeError {
      // a record whose counts run past its length
      damaged = true;
    }
  }

  /// Reads up to [budget] records; true when the file is done.
  bool step(int budget) {
    final ix = index;
    for (var n = 0; n < budget && !_done; n++) {
      if (ix != null) {
        if (_at + 8 > indexLength) {
          _done = true;
          break;
        }
        final offset = ix.getInt32(_at, Endian.big) * 2, len = ix.getInt32(_at + 4, Endian.big) * 2;
        _at += 8;
        if (offset < 100 || offset + 8 > shp.length) {
          damaged = true;
          continue;
        }
        _record(offset + 8, len);
      } else {
        if (_at + 8 > fileLength) {
          _done = true;
          break;
        }
        final len = bd.getInt32(_at + 4, Endian.big) * 2;
        final start = _at + 8;
        // a length of zero or less would never move on: the file is damaged
        if (len <= 0 || start + len > shp.length) {
          damaged = true;
          _done = true;
          break;
        }
        _record(start, len);
        _at = start + len;
      }
    }
    return _done;
  }
}

class _Shape {
  _Shape(this.parts, this.z, {this.isPoint = false, this.isPolygon = false});
  final List<List<Pt>> parts;
  final List<List<double>> z;
  final bool isPoint;
  final bool isPolygon;
}
