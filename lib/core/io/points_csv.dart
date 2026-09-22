/// Survey points from text files (CSV / TXT / XYZ / PNEZD): X, Y, Z columns
/// detected from the header or by position; comma, semicolon, tab or space
/// separated; decimal comma tolerated. Geographic coordinates (lon/lat) are
/// recognised and projected through a [GeoReference].
library;

import '../model/geometry.dart';
import '../units.dart';
import 'dxf.dart';
import 'geo.dart';

class PointsImportResult {
  PointsImportResult({required this.document, required this.count, required this.georef, required this.geographic, required this.columns});
  final DxfDocument document;
  final int count;

  /// Georeference created for geographic input (null when metric input).
  final GeoReference? georef;
  final bool geographic;

  /// Detected column indices (x, y, z, name).
  final (int, int, int?, int?) columns;
}

class PointsCsvReader {
  static final _sep = RegExp(r'[;\t]|,(?=\s*[-+\d"a-zA-Z])|\s+');

  static List<String> _split(String line) {
    final l = line.trim();
    if (l.isEmpty) return const [];
    // prefer explicit separators; fall back to whitespace
    if (l.contains(';')) return l.split(';').map((s) => s.trim()).toList();
    if (l.contains('\t')) return l.split('\t').map((s) => s.trim()).toList();
    final commas = ','.allMatches(l).length;
    final dots = '.'.allMatches(l).length;
    if (commas >= 2 && (dots > 0 || !RegExp(r'\d,\d').hasMatch(l))) return l.split(',').map((s) => s.trim()).toList();
    if (commas >= 1 && dots > 0) return l.split(',').map((s) => s.trim()).toList();
    // whitespace-separated columns with decimal commas ("10,5 20,5 100,2"):
    // every column holds at most one comma, its decimal separator
    final words = l.split(RegExp(r'\s+'));
    if (words.length >= 2 && words.every((w) => ','.allMatches(w).length <= 1 && !w.startsWith(',') && !w.endsWith(','))) return words;
    return l.split(_sep).where((s) => s.isNotEmpty).toList();
  }

  static double? _num(String s) => parseNumber(s.replaceAll('"', ''));

  /// Parses the text. [georef] places geographic points relative to an
  /// existing origin; [layer] names the layer of the spot heights.
  static PointsImportResult parse(String text, {GeoReference? georef, String layer = 'SPOT_HEIGHTS'}) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#')).toList();
    if (lines.isEmpty) throw const FormatException('points_empty');
    var start = 0;
    final first = _split(lines.first);
    int? xi, yi, zi, ni;
    final header = first.map((h) => h.toLowerCase().replaceAll('"', '').trim()).toList();
    final numericFirst = first.where((c) => _num(c) != null).length >= 2;
    if (!numericFirst) {
      start = 1;
      int? find(List<String> names) {
        for (var i = 0; i < header.length; i++) {
          if (names.contains(header[i])) return i;
        }
        return null;
      }

      xi = find(['x', 'e', 'east', 'easting', 'este', 'lon', 'long', 'longitude', 'longitud', 'utm_e', 'coord_x']);
      yi = find(['y', 'n', 'north', 'northing', 'norte', 'lat', 'latitude', 'latitud', 'utm_n', 'coord_y']);
      zi = find(['z', 'elev', 'elevation', 'elevacao', 'elevação', 'cota', 'alt', 'altitude', 'altura', 'h', 'height']);
      ni = find(['id', 'name', 'nome', 'ponto', 'point', 'desc', 'descricao', 'descrição', 'code', 'codigo']);
    }
    // by position: PNEZD (id, N, E, Z, desc) when 5+ columns with a leading id, else X Y Z
    final sample = _split(lines[start]);
    if (xi == null || yi == null) {
      final nums = <int>[];
      for (var i = 0; i < sample.length; i++) {
        if (_num(sample[i]) != null) nums.add(i);
      }
      if (nums.length >= 4 && sample.length >= 4 && (nums.first == 0)) {
        // id N E Z [desc]
        ni = 0;
        yi = nums[1];
        xi = nums[2];
        zi = nums.length > 3 ? nums[3] : null;
      } else if (nums.length >= 2) {
        xi = nums[0];
        yi = nums[1];
        zi = nums.length > 2 ? nums[2] : null;
        // a text column ("P1 500 600 10") names the point
        ni ??= [for (var i = 0; i < sample.length; i++) if (!nums.contains(i)) i].firstOrNull;
      } else {
        throw const FormatException('points_no_columns');
      }
    }
    final rows = <(double, double, double?, String)>[];
    var manyDecimals = 0;
    int decimals(String s) {
      final t = s.replaceAll('"', '').trim().replaceAll(',', '.');
      final i = t.indexOf('.');
      return i < 0 ? 0 : t.length - i - 1;
    }

    for (var i = start; i < lines.length; i++) {
      final c = _split(lines[i]);
      if (c.length <= (xi > yi ? xi : yi)) continue;
      final x = _num(c[xi]), y = _num(c[yi]);
      if (x == null || y == null) continue;
      final z = zi != null && zi < c.length ? _num(c[zi]) : null;
      final name = ni != null && ni < c.length ? c[ni].replaceAll('"', '') : '';
      if (decimals(c[xi]) >= 5 && decimals(c[yi]) >= 5) manyDecimals++;
      rows.add((x, y, z, name));
    }
    if (rows.isEmpty) throw const FormatException('points_no_columns');
    // geographic? header names, or degree-like values (small, many decimals)
    final headerGeo = !numericFirst && (const ['lat', 'latitude', 'latitud', 'lon', 'long', 'longitude', 'longitud'].any(header.contains));
    final headerMetric = !numericFirst && (const ['x', 'y', 'e', 'n', 'east', 'north', 'easting', 'northing', 'este', 'norte'].any(header.contains));
    final inRange = rows.every((r) => r.$1.abs() <= 180 && r.$2.abs() <= 90);
    final geographic = inRange && (headerGeo || (!headerMetric && manyDecimals * 2 >= rows.length));
    GeoReference? ref;
    Pt Function(double, double) project;
    if (geographic) {
      // columns may be lat,lon or lon,lat: latitude is the one within ±90 with the smaller spread when both fit
      var lonI = 0; // x column is longitude by default
      if (rows.every((r) => r.$1.abs() <= 90) && !rows.every((r) => r.$2.abs() <= 90)) lonI = 1;
      double lonOf((double, double, double?, String) r) => lonI == 0 ? r.$1 : r.$2;
      double latOf((double, double, double?, String) r) => lonI == 0 ? r.$2 : r.$1;
      if (georef != null) {
        ref = georef;
      } else {
        var sLat = 0.0, sLon = 0.0;
        for (final r in rows) {
          sLat += latOf(r);
          sLon += lonOf(r);
        }
        final u = latLonToUtm(sLat / rows.length, sLon / rows.length);
        ref = GeoReference(zone: u.zone, north: u.north, originEasting: (u.easting / 100).round() * 100.0, originNorthing: (u.northing / 100).round() * 100.0);
      }
      final g = ref;
      project = (x, y) {
        final lat = lonI == 0 ? y : x, lon = lonI == 0 ? x : y;
        final u = latLonToUtm(lat, lon, zone: g.zone);
        var northing = u.northing;
        if (g.north && lat < 0) northing -= 10000000;
        if (!g.north && lat >= 0) northing += 10000000;
        return Pt(u.easting - g.originEasting, northing - g.originNorthing);
      };
    } else {
      // large projected coordinates: shift to the project origin when a georef
      // exists, else keep as-is (the user can georeference later)
      project = (x, y) => georef != null && x.abs() > 100000 ? Pt(x - georef.originEasting, y - georef.originNorthing) : Pt(x, y);
    }
    final doc = DxfDocument(layers: [DxfLayer(layer, color: 3)]);
    for (final r in rows) {
      final p = project(r.$1, r.$2);
      doc.entities.add(DxfEntity(type: 'POINT', layer: layer, points: [p], elevation: r.$3, name: r.$4));
    }
    return PointsImportResult(document: doc, count: rows.length, georef: geographic ? ref : null, geographic: geographic, columns: (xi, yi, zi, ni));
  }
}
