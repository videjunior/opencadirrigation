/// Geographic exporters: KML / KMZ (Google Earth) and GeoJSON (QGIS, web
/// GIS). Features carry WGS84 coordinates produced from the project's
/// [GeoReference].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One exported geographic feature (a KML Placemark / GeoJSON Feature).
class GeoFeature {
  GeoFeature({required this.name, required this.folder, required this.type, required this.coords, this.color = 0xFFFFFFFF, this.widthPx = 2, this.description = '', Map<String, String>? data, this.fillAlpha = 0.3})
      : data = data ?? {};

  final String name;

  /// Folder (KML) – normally the layer name.
  final String folder;

  /// 'Point', 'LineString' or 'Polygon'.
  final String type;

  /// (lon, lat, altitude) triplets, degrees / metres.
  final List<(double, double, double)> coords;
  final int color;
  final double widthPx;
  final String description;

  /// Extra attributes (ExtendedData / GeoJSON properties).
  final Map<String, String> data;
  final double fillAlpha;
}

class KmlWriter {
  static String write(List<GeoFeature> features, {String documentName = '', String description = ''}) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('<Document>')
      ..writeln('<name>${_esc(documentName)}</name>');
    if (description.isNotEmpty) b.writeln('<description>${_esc(description)}</description>');
    // styles, one per (colour, width, type)
    final styles = <String, String>{};
    String styleId(GeoFeature f) {
      final key = '${f.type}|${f.color}|${f.widthPx}|${f.fillAlpha}';
      return styles.putIfAbsent(key, () => 's${styles.length + 1}');
    }

    for (final f in features) {
      styleId(f);
    }
    styles.forEach((key, id) {
      final parts = key.split('|');
      final type = parts[0];
      final color = int.parse(parts[1]);
      final width = double.parse(parts[2]);
      final fillAlpha = double.parse(parts[3]);
      b.writeln('<Style id="$id">');
      if (type == 'Point') {
        b.writeln('<IconStyle><color>${_abgr(color)}</color><scale>0.9</scale><Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle>');
        b.writeln('<LabelStyle><scale>0.8</scale></LabelStyle>');
      } else {
        b.writeln('<LineStyle><color>${_abgr(color)}</color><width>${_n(width)}</width></LineStyle>');
        if (type == 'Polygon') b.writeln('<PolyStyle><color>${_abgr(color, alpha: fillAlpha)}</color><fill>${fillAlpha > 0 ? 1 : 0}</fill><outline>1</outline></PolyStyle>');
      }
      b.writeln('</Style>');
    });
    // folders
    final byFolder = <String, List<GeoFeature>>{};
    for (final f in features) {
      byFolder.putIfAbsent(f.folder, () => []).add(f);
    }
    byFolder.forEach((folder, list) {
      b.writeln('<Folder><name>${_esc(folder)}</name>');
      for (final f in list) {
        b.writeln('<Placemark>');
        if (f.name.isNotEmpty) b.writeln('<name>${_esc(f.name)}</name>');
        if (f.description.isNotEmpty) b.writeln('<description>${_esc(f.description)}</description>');
        b.writeln('<styleUrl>#${styleId(f)}</styleUrl>');
        if (f.data.isNotEmpty) {
          b.write('<ExtendedData>');
          f.data.forEach((k, v) => b.write('<Data name="${_esc(k)}"><value>${_esc(v)}</value></Data>'));
          b.writeln('</ExtendedData>');
        }
        final coords = f.coords.map((c) => '${_deg(c.$1)},${_deg(c.$2)},${_n(c.$3)}').join(' ');
        switch (f.type) {
          case 'Point':
            b.writeln('<Point><coordinates>$coords</coordinates></Point>');
          case 'Polygon':
            final ring = f.coords.isNotEmpty && f.coords.first != f.coords.last ? '$coords ${_deg(f.coords.first.$1)},${_deg(f.coords.first.$2)},${_n(f.coords.first.$3)}' : coords;
            b.writeln('<Polygon><tessellate>1</tessellate><outerBoundaryIs><LinearRing><coordinates>$ring</coordinates></LinearRing></outerBoundaryIs></Polygon>');
          default:
            b.writeln('<LineString><tessellate>1</tessellate><coordinates>$coords</coordinates></LineString>');
        }
        b.writeln('</Placemark>');
      }
      b.writeln('</Folder>');
    });
    b.writeln('</Document>');
    b.writeln('</kml>');
    return b.toString();
  }

  /// Zips [kml] as `doc.kml` (KMZ).
  static Uint8List writeKmz(String kml) {
    final bytes = utf8.encode(kml);
    final archive = Archive()..addFile(ArchiveFile.bytes('doc.kml', bytes));
    return ZipEncoder().encodeBytes(archive);
  }

  /// KML colour: aabbggrr hex.
  static String _abgr(int argb, {double? alpha}) {
    final a = alpha != null ? (alpha * 255).round().clamp(0, 255) : (argb >> 24) & 0xFF;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(a)}${h(argb & 0xFF)}${h((argb >> 8) & 0xFF)}${h((argb >> 16) & 0xFF)}';
  }
}

class GeoJsonWriter {
  static String write(List<GeoFeature> features, {String name = ''}) {
    final feats = <Map<String, dynamic>>[];
    for (final f in features) {
      List<double> pos((double, double, double) c) => [_round(c.$1, 8), _round(c.$2, 8), if (c.$3 != 0) _round(c.$3, 3)];
      Map<String, dynamic> geometry;
      switch (f.type) {
        case 'Point':
          geometry = {'type': 'Point', 'coordinates': pos(f.coords.first)};
        case 'Polygon':
          final ring = f.coords.map(pos).toList();
          if (ring.isNotEmpty && (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) ring.add(ring.first);
          geometry = {'type': 'Polygon', 'coordinates': [ring]};
        default:
          geometry = {'type': 'LineString', 'coordinates': f.coords.map(pos).toList()};
      }
      feats.add({
        'type': 'Feature',
        'properties': {'name': f.name, 'layer': f.folder, if (f.description.isNotEmpty) 'description': f.description, ...f.data},
        'geometry': geometry,
      });
    }
    return const JsonEncoder.withIndent(' ').convert({'type': 'FeatureCollection', if (name.isNotEmpty) 'name': name, 'features': feats});
  }
}

double _round(double v, int d) => double.parse(v.toStringAsFixed(d));
String _deg(double v) => v.toStringAsFixed(8);
String _n(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
}

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
