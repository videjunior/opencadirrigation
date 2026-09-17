/// KML / KMZ reader producing a [DxfDocument]-compatible drawing in local
/// metric coordinates (UTM, offset to a local origin).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../model/geometry.dart';
import 'dxf.dart';
import 'geo.dart';

class KmlImportResult {
  KmlImportResult({required this.document, required this.georef, required this.placemarkCount});
  final DxfDocument document;
  final GeoReference georef;
  final int placemarkCount;
}

class KmlReader {
  /// Parses KML text. If [georef] is given, coordinates are placed relative to
  /// that existing origin so the import lines up with previous data.
  static KmlImportResult parse(String xml, {GeoReference? georef}) {
    final doc = XmlDocument.parse(xml);
    final raw = <_RawPlacemark>[];
    _walk(doc.rootElement, 'KML', raw);
    // projection origin: centroid of all coordinates
    var sumLat = 0.0, sumLon = 0.0, n = 0;
    for (final p in raw) {
      for (final g in p.geoms) {
        for (final c in g.coords) {
          sumLat += c.$2;
          sumLon += c.$1;
          n++;
        }
      }
    }
    GeoReference ref;
    if (georef != null) {
      ref = georef;
    } else if (n > 0) {
      final lat = sumLat / n, lon = sumLon / n;
      final u = latLonToUtm(lat, lon);
      ref = GeoReference(zone: u.zone, north: u.north, originEasting: (u.easting / 100).round() * 100.0, originNorthing: (u.northing / 100).round() * 100.0);
    } else {
      ref = const GeoReference(zone: 23, north: false, originEasting: 0, originNorthing: 0);
    }
    Pt project(double lon, double lat) {
      // Same zone and hemisphere convention as the origin (false northing
      // included), so the local coordinates are a plain offset.
      final u = latLonToUtm(lat, lon, zone: ref.zone);
      var northing = u.northing;
      if (ref.north && lat < 0) northing -= 10000000;
      if (!ref.north && lat >= 0) northing += 10000000;
      return Pt(u.easting - ref.originEasting, northing - ref.originNorthing);
    }

    final entities = <DxfEntity>[];
    final layers = <String, DxfLayer>{};
    for (final p in raw) {
      final layer = p.folder.isEmpty ? 'KML' : p.folder;
      layers.putIfAbsent(layer, () => DxfLayer(layer, color: 3));
      for (final g in p.geoms) {
        final pts = g.coords.map((c) => project(c.$1, c.$2)).toList();
        final alts = g.coords.map((c) => c.$3).toList();
        final hasAlt = alts.any((z) => z != 0);
        final sameAlt = hasAlt && alts.every((z) => (z - alts.first).abs() < 1e-6);
        final elev = p.elevation ?? (sameAlt ? alts.first : null);
        switch (g.type) {
          case 'Point':
            if (pts.isEmpty) break;
            entities.add(DxfEntity(type: 'POINT', layer: layer, points: [pts.first], elevation: elev ?? (hasAlt ? alts.first : null), name: p.name));
            if (p.name.isNotEmpty) entities.add(DxfEntity(type: 'TEXT', layer: layer, points: [pts.first + const Pt(1, 1)], text: p.name, height: 1.5));
          case 'LineString':
            if (pts.length >= 2) entities.add(DxfEntity(type: 'POLYLINE', layer: layer, points: pts, elevation: elev, name: p.name));
          case 'Polygon':
            if (pts.length >= 3) {
              if (pts.first.distanceTo(pts.last) < 1e-9) pts.removeLast();
              entities.add(DxfEntity(type: 'POLYLINE', layer: layer, points: pts, closed: true, elevation: elev, name: p.name));
            }
        }
      }
    }
    return KmlImportResult(document: DxfDocument(entities: entities, layers: layers.values.toList()), georef: ref, placemarkCount: raw.length);
  }

  /// Parses a KMZ archive (first .kml inside).
  static KmlImportResult parseKmz(Uint8List bytes, {GeoReference? georef}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? kml;
    for (final f in archive.files) {
      if (f.name.toLowerCase() == 'doc.kml') kml = f;
    }
    kml ??= archive.files.where((f) => f.name.toLowerCase().endsWith('.kml')).firstOrNull;
    if (kml == null) throw const FormatException('kmz_no_kml');
    final content = kml.content as List<int>;
    return parse(utf8.decode(content, allowMalformed: true), georef: georef);
  }

  static void _walk(XmlElement el, String folder, List<_RawPlacemark> out) {
    for (final child in el.childElements) {
      final name = child.name.local;
      if (name == 'Folder' || name == 'Document') {
        final fname = child.getElement('name')?.innerText.trim() ?? '';
        _walk(child, name == 'Folder' && fname.isNotEmpty ? fname : folder, out);
      } else if (name == 'Placemark') {
        out.add(_placemark(child, folder));
      } else {
        _walk(child, folder, out);
      }
    }
  }

  static _RawPlacemark _placemark(XmlElement pm, String folder) {
    final name = pm.getElement('name')?.innerText.trim() ?? '';
    final geoms = <_RawGeom>[];
    _collectGeoms(pm, geoms);
    // elevation hint from ExtendedData (ELEV, elevation, cota, Z)
    double? elev;
    for (final d in pm.findAllElements('Data')) {
      final key = (d.getAttribute('name') ?? '').toLowerCase();
      if (key.contains('elev') || key == 'z' || key.contains('cota') || key.contains('alt')) {
        elev = double.tryParse(d.getElement('value')?.innerText.trim().replaceAll(',', '.') ?? '');
      }
    }
    for (final d in pm.findAllElements('SimpleData')) {
      final key = (d.getAttribute('name') ?? '').toLowerCase();
      if (elev == null && (key.contains('elev') || key == 'z' || key.contains('cota') || key.contains('alt'))) {
        elev = double.tryParse(d.innerText.trim().replaceAll(',', '.'));
      }
    }
    return _RawPlacemark(name: name, folder: folder, geoms: geoms, elevation: elev);
  }

  static void _collectGeoms(XmlElement el, List<_RawGeom> out) {
    for (final child in el.childElements) {
      final n = child.name.local;
      if (n == 'Point' || n == 'LineString') {
        final c = child.getElement('coordinates');
        if (c != null) out.add(_RawGeom(n, _coords(c.innerText)));
      } else if (n == 'Polygon') {
        final outer = child.getElement('outerBoundaryIs')?.getElement('LinearRing')?.getElement('coordinates');
        if (outer != null) out.add(_RawGeom('Polygon', _coords(outer.innerText)));
        for (final inner in child.findElements('innerBoundaryIs')) {
          final c = inner.getElement('LinearRing')?.getElement('coordinates');
          if (c != null) out.add(_RawGeom('Polygon', _coords(c.innerText)));
        }
      } else if (n == 'LinearRing') {
        final c = child.getElement('coordinates');
        if (c != null) out.add(_RawGeom('Polygon', _coords(c.innerText)));
      } else if (n == 'MultiGeometry' || n == 'MultiTrack' || n == 'Track') {
        _collectGeoms(child, out);
      }
    }
  }

  static List<(double, double, double)> _coords(String text) {
    final out = <(double, double, double)>[];
    for (final tok in text.trim().split(RegExp(r'\s+'))) {
      if (tok.isEmpty) continue;
      final parts = tok.split(',');
      if (parts.length < 2) continue;
      final lon = double.tryParse(parts[0]), lat = double.tryParse(parts[1]);
      final alt = parts.length > 2 ? (double.tryParse(parts[2]) ?? 0) : 0.0;
      if (lon == null || lat == null) continue;
      out.add((lon, lat, alt));
    }
    return out;
  }
}

class _RawPlacemark {
  _RawPlacemark({required this.name, required this.folder, required this.geoms, this.elevation});
  final String name;
  final String folder;
  final List<_RawGeom> geoms;
  final double? elevation;
}

class _RawGeom {
  _RawGeom(this.type, this.coords);
  final String type;
  final List<(double, double, double)> coords;
}
