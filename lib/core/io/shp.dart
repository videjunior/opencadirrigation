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
import 'dxf.dart';
import 'geo.dart';

class ShpImportResult {
  ShpImportResult({required this.document, required this.recordCount, required this.georef, required this.geographic, this.crs = ''});
  final DxfDocument document;
  final int recordCount;
  final GeoReference? georef;
  final bool geographic;
  final String crs;
}

class ShpReader {
  /// Parses a .shp (optionally with .dbf rows and .prj text).
  static ShpImportResult parse(Uint8List shp, {Uint8List? dbf, String? prj, String? cpg, GeoReference? georef, String layer = 'SHP'}) {
    final bd = ByteData.sublistView(shp);
    if (shp.length < 100 || bd.getInt32(0, Endian.big) != 9994) throw const FormatException('shp_bad_header');
    final fileLength = bd.getInt32(24, Endian.big) * 2;
    final attrs = dbf != null ? _readDbf(dbf, cpg: cpg) : const <Map<String, String>>[];
    final elevField = attrs.isEmpty ? null : _elevationField(attrs.first.keys);
    final nameField = attrs.isEmpty ? null : _nameField(attrs.first.keys);
    final geographic = prj != null ? (prj.contains('GEOGCS') && !prj.contains('PROJCS')) : null;
    // records
    final raw = <_Shape>[];
    var off = 100;
    var rec = 0;
    while (off + 8 <= fileLength && off + 8 <= shp.length) {
      final len = bd.getInt32(off + 4, Endian.big) * 2;
      final start = off + 8;
      if (start + 4 > shp.length) break;
      final type = bd.getInt32(start, Endian.little);
      raw.add(_parseShape(bd, start, type));
      rec++;
      off = start + len;
    }
    // without a .prj, degrees are recognised by their range and precision
    final allPts = raw.expand((s) => s.parts.expand((p) => p)).toList();
    final isGeo = geographic ?? looksLikeDegrees(allPts);
    GeoReference? ref;
    Pt Function(Pt) project;
    if (isGeo) {
      if (georef != null) {
        ref = georef;
      } else if (allPts.isNotEmpty) {
        var sLat = 0.0, sLon = 0.0;
        for (final p in allPts) {
          sLat += p.y;
          sLon += p.x;
        }
        final u = latLonToUtm(sLat / allPts.length, sLon / allPts.length);
        ref = GeoReference(zone: u.zone, north: u.north, originEasting: (u.easting / 100).round() * 100.0, originNorthing: (u.northing / 100).round() * 100.0);
      } else {
        ref = const GeoReference(zone: 23, north: false, originEasting: 0, originNorthing: 0);
      }
      final g = ref;
      project = (p) {
        final u = latLonToUtm(p.y, p.x, zone: g.zone);
        var northing = u.northing;
        if (g.north && p.y < 0) northing -= 10000000;
        if (!g.north && p.y >= 0) northing += 10000000;
        return Pt(u.easting - g.originEasting, northing - g.originNorthing);
      };
    } else {
      // projected: shift large coordinates to the project origin
      final big = allPts.isNotEmpty && allPts.first.x.abs() > 100000;
      if (big && georef == null && allPts.isNotEmpty) {
        final zone = _utmZoneFromPrj(prj);
        ref = GeoReference(zone: zone?.$1 ?? 23, north: zone?.$2 ?? false, originEasting: (allPts.first.x / 100).round() * 100.0, originNorthing: (allPts.first.y / 100).round() * 100.0);
      } else if (big) {
        ref = georef;
      }
      final g = ref;
      project = (p) => g != null && big ? Pt(p.x - g.originEasting, p.y - g.originNorthing) : p;
    }
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
    return ShpImportResult(document: doc, recordCount: rec, georef: ref, geographic: isGeo, crs: prj != null ? _crsName(prj) : '');
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

  /// Parses a .zip holding .shp (+ .dbf, .prj, .cpg) or a raw .shp.
  static ShpImportResult parseAny(String name, Uint8List bytes, {GeoReference? georef}) {
    if (name.toLowerCase().endsWith('.zip')) {
      final arc = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? shp, dbf, prj, cpg;
      for (final f in arc) {
        final l = f.name.toLowerCase();
        if (l.endsWith('.shp')) shp ??= f;
        if (l.endsWith('.dbf')) dbf ??= f;
        if (l.endsWith('.prj')) prj ??= f;
        if (l.endsWith('.cpg')) cpg ??= f;
      }
      if (shp == null) throw const FormatException('shp_zip_no_shp');
      final layer = shp.name.split('/').last.replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
      return parse(Uint8List.fromList(shp.content as List<int>), dbf: dbf != null ? Uint8List.fromList(dbf.content as List<int>) : null, prj: prj != null ? latin1.decode(prj.content as List<int>) : null, cpg: cpg != null ? latin1.decode(cpg.content as List<int>).trim() : null, georef: georef, layer: layer.isEmpty ? 'SHP' : layer);
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
    final c = (cpg ?? '').toUpperCase();
    final forceUtf8 = c.contains('UTF') || c.contains('65001');
    final forceLatin = c.contains('1252') || c.contains('8859') || c.contains('LATIN');
    String decode(List<int> b) {
      if (forceUtf8) return utf8.decode(b, allowMalformed: true);
      if (forceLatin) return latin1.decode(b);
      try {
        return utf8.decode(b);
      } catch (_) {
        return latin1.decode(b);
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
    var pos = headerLen;
    for (var r = 0; r < recCount && pos + recLen <= dbf.length; r++) {
      var p = pos + 1; // deletion flag
      final m = <String, String>{};
      for (final (name, len) in fields) {
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

  static (int, bool)? _utmZoneFromPrj(String? prj) {
    if (prj == null) return null;
    final m = RegExp(r'UTM[_ ]zone[_ ](\d+)([NS])', caseSensitive: false).firstMatch(prj);
    if (m == null) return null;
    return (int.parse(m.group(1)!), m.group(2)!.toUpperCase() == 'N');
  }

  static String _crsName(String prj) {
    final m = RegExp(r'^(PROJCS|GEOGCS)\["([^"]+)"').firstMatch(prj.trim());
    return m?.group(2) ?? '';
  }
}

class _Shape {
  _Shape(this.parts, this.z, {this.isPoint = false, this.isPolygon = false});
  final List<List<Pt>> parts;
  final List<List<double>> z;
  final bool isPoint;
  final bool isPolygon;
}
