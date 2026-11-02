/// KML / KMZ reader producing a [DxfDocument]-compatible drawing in local
/// metric coordinates (UTM, offset to a local origin), and the ground
/// overlays of the file (a sketch or an orthophoto laid over the virtual
/// globe: `GroundOverlay` with a `LatLonBox`, rotation included, or a
/// `gx:LatLonQuad`) as georeferenced pictures, their images taken from the
/// KMZ archive.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

import '../model/entities.dart' show ImageEntity;
import '../model/geometry.dart';
import 'dxf.dart';
import 'geo.dart';
import 'geoimage.dart';
import 'image_decode.dart';
import 'safe_archive.dart';
import 'tiff_raster.dart' show TiffFile;

class KmlImportResult {
  KmlImportResult({required this.document, required this.georef, required this.placemarkCount, this.overlays = const [], this.warnings = const []});
  final DxfDocument document;
  final GeoReference georef;
  final int placemarkCount;

  /// The ground overlays whose picture the file holds (KMZ).
  final List<KmlOverlay> overlays;

  /// Notes for the import message: `kml_overlay_missing:<href>` (a picture
  /// the file does not hold: a KML beside its images, a web address),
  /// `kml_overlay_quad` (a quadrilateral drawn as the rectangle of its
  /// first three corners), `image_too_large:<href>`,
  /// `kml_overlay_unreadable:<href>`.
  final List<String> warnings;
}

/// A picture laid over the ground: its encoded image and where its corners
/// fall in the local coordinates of the import.
class KmlOverlay {
  KmlOverlay({required this.name, required this.href, required this.bytes, required this.mime, required this.corners, this.opacity = 1, this.drawOrder = 0});
  final String name;

  /// The path of the picture in the file.
  final String href;

  /// Encoded PNG or JPEG.
  final Uint8List bytes;
  final String mime;

  /// Bottom-left, bottom-right, top-right, top-left (local metres).
  final List<Pt> corners;

  /// From the alpha of the overlay's colour (`<color>aabbggrr</color>`).
  final double opacity;

  /// Overlays with a higher order are drawn above the others.
  final int drawOrder;

  double get width => corners[0].distanceTo(corners[1]);
  double get height => corners[0].distanceTo(corners[3]);

  /// Direction of the bottom edge (degrees, counter-clockwise from east).
  double get rotationDeg => radToDeg((corners[1] - corners[0]).angle);
}

class KmlReader {
  /// Parses KML text. If [georef] is given, coordinates are placed relative to
  /// that existing origin so the import lines up with previous data.
  /// [images] gives the pictures of the ground overlays by their path in
  /// the file (the entries of a KMZ).
  static KmlImportResult parse(String xml, {GeoReference? georef, Uint8List? Function(String href)? images}) {
    final doc = XmlDocument.parse(xml);
    final raw = <_RawPlacemark>[];
    final overlays = <_RawOverlay>[];
    _walk(doc.rootElement, 'KML', raw, overlays);
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
    for (final o in overlays) {
      for (final (lon, lat) in o.cornersLonLat) {
        sumLat += lat;
        sumLon += lon;
        n++;
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
    // the ground overlays: corners projected, the rotation of a box turned
    // about its centre in the plane of the drawing
    final placed = <KmlOverlay>[];
    final warnings = <String>[];
    for (final o in overlays) {
      final pts = [for (final (lon, lat) in o.cornersLonLat) project(lon, lat)];
      if (o.rotationDeg != 0) {
        final c = (pts[0] + pts[2]) * 0.5;
        final r = degToRad(o.rotationDeg);
        for (var i = 0; i < 4; i++) {
          pts[i] = c + (pts[i] - c).rotate(r);
        }
      }
      if (o.quad && !_rectangular(pts)) warnings.add('kml_overlay_quad');
      final data = o.href.isEmpty ? null : images?.call(o.href);
      if (data == null || data.isEmpty) {
        warnings.add('kml_overlay_missing:${o.href.isEmpty ? o.name : o.href}');
        continue;
      }
      final (picture, mime, problem) = _picture(o.href, data);
      if (picture == null) {
        warnings.add('$problem:${o.href}');
        continue;
      }
      placed.add(KmlOverlay(name: o.name, href: o.href, bytes: picture, mime: mime, corners: pts, opacity: o.opacity, drawOrder: o.drawOrder));
    }
    placed.sort((a, b) => a.drawOrder.compareTo(b.drawOrder));
    return KmlImportResult(
      document: DxfDocument(entities: entities, layers: layers.values.toList()),
      georef: ref,
      placemarkCount: raw.length,
      overlays: placed,
      warnings: warnings,
    );
  }

  /// The pictures of [overlays] as image entities (ids from [newId]), in
  /// their drawing order.
  static List<ImageEntity> overlayImages(List<KmlOverlay> overlays, String Function() newId) => [
    for (final o in overlays)
      ImageEntity(
        id: newId(),
        name: o.name.isEmpty ? o.href.split('/').last : o.name,
        origin: o.corners[0],
        width: o.width,
        height: o.height,
        rotationDeg: o.rotationDeg,
        opacity: o.opacity.clamp(0.05, 1.0).toDouble(),
        mime: o.mime,
        data: o.bytes,
        source: o.href,
      ),
  ];

  /// The four corners make a rectangle within 1 % of its size.
  static bool _rectangular(List<Pt> c) {
    final size = math.max(c[0].distanceTo(c[2]), 1e-9);
    // a rectangle: the diagonals bisect each other and are equally long
    final mid = (c[0] + c[2]) * 0.5, mid2 = (c[1] + c[3]) * 0.5;
    return mid.distanceTo(mid2) < 0.01 * size && (c[0].distanceTo(c[2]) - c[1].distanceTo(c[3])).abs() < 0.01 * size;
  }

  /// The picture of an overlay as PNG or JPEG for the drawing (a TIFF or
  /// another format re-encoded, a large TIFF reduced), with its type; or no
  /// picture and why (`image_too_large`, `kml_overlay_unreadable`).
  static (Uint8List?, String, String?) _picture(String href, Uint8List data) {
    final lower = href.toLowerCase();
    try {
      final isJpeg = data.length > 3 && data[0] == 0xFF && data[1] == 0xD8;
      final isPng = data.length > 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47;
      final info = isJpeg || isPng ? pictureInfo(data) : null;
      if (info != null) {
        // passed through as they are, within the pixels the canvas decodes
        GeoImageReader.checkPixels(info.width, info.height);
        return (data, isJpeg ? 'image/jpeg' : 'image/png', null);
      }
      // a TIFF (by its signature or its name): read as the GeoTIFFs are, a large one reduced
      if (TiffFile.open(data) != null || lower.endsWith('.tif') || lower.endsWith('.tiff')) {
        final g = GeoImageReader.read(lower.endsWith('.tif') || lower.endsWith('.tiff') ? lower : '$lower.tif', data);
        return (g.bytes, g.mime, null);
      }
      // another format (GIF, BMP, WebP…): re-encoded as PNG, its size checked first
      final head = pictureInfo(data);
      if (head == null) return (null, '', 'kml_overlay_unreadable');
      GeoImageReader.checkPixels(head.width, head.height);
      final im = decodeImageSafe(data);
      if (im == null) return (null, '', 'kml_overlay_unreadable');
      return (Uint8List.fromList(img.encodePng(im)), 'image/png', null);
    } on FormatException catch (e) {
      return (null, '', e.message == 'image_too_large' ? 'image_too_large' : 'kml_overlay_unreadable');
    }
  }

  /// Parses a KMZ archive (first .kml inside), with the pictures of its
  /// ground overlays.
  static KmlImportResult parseKmz(Uint8List bytes, {GeoReference? georef}) {
    final archive = openZip(bytes);
    ArchiveFile? kml;
    for (final f in archive.files) {
      if (f.name.toLowerCase() == 'doc.kml') kml = f;
    }
    kml ??= archive.files.where((f) => f.name.toLowerCase().endsWith('.kml')).firstOrNull;
    if (kml == null) throw const FormatException('kmz_no_kml');
    // the paths of the overlays are relative to the document
    final base = kml.name.contains('/') ? kml.name.substring(0, kml.name.lastIndexOf('/') + 1) : '';
    String norm(String p) => p.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '').toLowerCase();
    final byName = {for (final f in archive.files) norm(f.name): f};
    Uint8List? image(String href) {
      var h = href.trim();
      if (h.contains('://') && !h.toLowerCase().startsWith('file://')) return null;
      h = h.replaceFirst(RegExp(r'^file://', caseSensitive: false), '');
      try {
        h = Uri.decodeFull(h);
      } on ArgumentError {
        // a path with a stray % stays as it is
      } on FormatException {
        // so does one whose escapes are not UTF-8
      }
      final f = byName[norm('$base$h')] ?? byName[norm(h)];
      // only the pictures the overlays name, each up to the ceiling of an entry
      return f == null ? null : zipEntryBytes(f);
    }

    // the document only, and only up to the ceiling of an entry
    return parse(utf8.decode(zipEntryBytes(kml), allowMalformed: true), georef: georef, images: image);
  }

  static void _walk(XmlElement el, String folder, List<_RawPlacemark> out, List<_RawOverlay> overlays) {
    for (final child in el.childElements) {
      final name = child.name.local;
      if (name == 'Folder' || name == 'Document') {
        final fname = child.getElement('name')?.innerText.trim() ?? '';
        _walk(child, name == 'Folder' && fname.isNotEmpty ? fname : folder, out, overlays);
      } else if (name == 'Placemark') {
        out.add(_placemark(child, folder));
      } else if (name == 'GroundOverlay') {
        final o = _overlay(child);
        if (o != null) overlays.add(o);
      } else {
        _walk(child, folder, out, overlays);
      }
    }
  }

  static double? _num(XmlElement? e) => e == null ? null : double.tryParse(e.innerText.trim());

  /// A ground overlay: its picture path, opacity and corners (longitude,
  /// latitude) from a `LatLonBox` (north, south, east, west and a rotation
  /// about the centre, counter-clockwise) or a `gx:LatLonQuad` (four corners
  /// from the bottom-left, counter-clockwise).
  static _RawOverlay? _overlay(XmlElement el) {
    XmlElement? child(XmlElement e, String local) => e.childElements.where((c) => c.name.local == local).firstOrNull;
    final name = child(el, 'name')?.innerText.trim() ?? '';
    final icon = child(el, 'Icon');
    final href = icon == null ? '' : (child(icon, 'href')?.innerText.trim() ?? '');
    // aabbggrr: the alpha first
    final colour = child(el, 'color')?.innerText.trim() ?? '';
    final alpha = colour.length == 8 ? int.tryParse(colour.substring(0, 2), radix: 16) : null;
    final order = int.tryParse(child(el, 'drawOrder')?.innerText.trim() ?? '') ?? 0;
    final box = child(el, 'LatLonBox');
    if (box != null) {
      final north = _num(child(box, 'north')), south = _num(child(box, 'south')), east = _num(child(box, 'east')), west = _num(child(box, 'west'));
      if (north == null || south == null || east == null || west == null) return null;
      final rotation = _num(child(box, 'rotation')) ?? 0;
      return _RawOverlay(name, href, alpha == null ? 1 : alpha / 255, order, [(west, south), (east, south), (east, north), (west, north)], rotationDeg: rotation);
    }
    final quad = child(el, 'LatLonQuad');
    final coords = quad == null ? null : child(quad, 'coordinates');
    if (coords == null) return null;
    final c = _coords(coords.innerText);
    if (c.length < 4) return null;
    return _RawOverlay(name, href, alpha == null ? 1 : alpha / 255, order, [for (final p in c.take(4)) (p.$1, p.$2)], quad: true);
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
      } else if (n == 'Track') {
        // gx:Track (a GPS walk): one "lon lat alt" per gx:coord
        final pts = <(double, double, double)>[];
        for (final c in child.childElements.where((e) => e.name.local == 'coord')) {
          final v = c.innerText.trim().split(RegExp(r'\s+')).map(double.tryParse).toList();
          if (v.length >= 2 && v[0] != null && v[1] != null) pts.add((v[0]!, v[1]!, v.length > 2 ? v[2] ?? 0 : 0));
        }
        if (pts.isNotEmpty) out.add(_RawGeom(pts.length == 1 ? 'Point' : 'LineString', pts));
      } else if (n == 'MultiGeometry' || n == 'MultiTrack') {
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

class _RawOverlay {
  _RawOverlay(this.name, this.href, this.opacity, this.drawOrder, this.cornersLonLat, {this.rotationDeg = 0, this.quad = false});
  final String name;
  final String href;
  final double opacity;
  final int drawOrder;

  /// Bottom-left, bottom-right, top-right, top-left (longitude, latitude).
  final List<(double, double)> cornersLonLat;
  final double rotationDeg;

  /// Given as a quadrilateral (gx:LatLonQuad).
  final bool quad;
}
