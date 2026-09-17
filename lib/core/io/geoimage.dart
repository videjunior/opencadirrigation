/// Georeferenced raster import: JPG/PNG with a world file (.jgw/.pgw/.wld,
/// inside a .zip with the image), GeoTIFF (ModelPixelScale/ModelTiepoint or
/// ModelTransformation tags, UTM or geographic CRS) and plain images placed
/// by the user. TIFF pixels are re-encoded to PNG for the canvas.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'geo.dart';

class GeoImage {
  GeoImage({required this.bytes, required this.mime, required this.widthPx, required this.heightPx, this.worldTopLeft, this.pixelSizeX, this.pixelSizeY, this.rotationDeg = 0, this.geographic = false, this.utmZone, this.utmNorth, this.source = ''});

  /// Encoded PNG/JPEG bytes for display.
  final Uint8List bytes;
  final String mime;
  final int widthPx;
  final int heightPx;

  /// Coordinates of the top-left corner (map units) when georeferenced.
  final Pt? worldTopLeft;
  final double? pixelSizeX;
  final double? pixelSizeY;
  final double rotationDeg;
  final bool geographic;
  final int? utmZone;
  final bool? utmNorth;
  final String source;

  bool get georeferenced => worldTopLeft != null && pixelSizeX != null && pixelSizeY != null;

  /// Width/height in map units when georeferenced.
  double get worldWidth => (pixelSizeX ?? 1) * widthPx;
  double get worldHeight => (pixelSizeY ?? 1).abs() * heightPx;
}

class GeoImageReader {
  /// Reads an image (jpg/png/tif/tiff, or a zip with image + world file).
  static GeoImage read(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.zip')) {
      final arc = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? image, world, prj;
      for (final f in arc) {
        final l = f.name.toLowerCase();
        if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.tif') || l.endsWith('.tiff')) image ??= f;
        if (l.endsWith('.jgw') || l.endsWith('.pgw') || l.endsWith('.tfw') || l.endsWith('.wld') || l.endsWith('.jpgw') || l.endsWith('.pngw')) world ??= f;
        if (l.endsWith('.prj')) prj ??= f;
      }
      if (image == null) throw const FormatException('image_zip_no_image');
      final base = read(image.name, Uint8List.fromList(image.content as List<int>));
      if (world == null) return base;
      final w = parseWorldFile(String.fromCharCodes(world.content as List<int>));
      if (w == null) return base;
      final prjText = prj != null ? String.fromCharCodes(prj.content as List<int>) : '';
      final geo = prjText.contains('GEOGCS') && !prjText.contains('PROJCS');
      final zone = RegExp(r'UTM[_ ]zone[_ ](\d+)([NS])', caseSensitive: false).firstMatch(prjText);
      // x = A·col + B·row + C, y = D·col + E·row + F for pixel centres: the
      // column axis (A, D) gives the pixel size and rotation; the top-left
      // corner is half a pixel back along both axes
      final (a, d, b, e, c, f) = w;
      return GeoImage(bytes: base.bytes, mime: base.mime, widthPx: base.widthPx, heightPx: base.heightPx, worldTopLeft: Pt(c - a / 2 - b / 2, f - d / 2 - e / 2), pixelSizeX: math.sqrt(a * a + d * d), pixelSizeY: -math.sqrt(b * b + e * e), rotationDeg: radToDeg(atan2Safe(d, a)), geographic: geo, utmZone: zone != null ? int.parse(zone.group(1)!) : null, utmNorth: zone != null ? zone.group(2)!.toUpperCase() == 'N' : null, source: image.name);
    }
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return _readTiff(name, bytes);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('image_unreadable');
    final mime = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.jpg') || lower.endsWith('.jpeg') ? 'image/jpeg' : 'image/png');
    final out = mime == 'image/png' || mime == 'image/jpeg' ? bytes : Uint8List.fromList(img.encodePng(decoded));
    return GeoImage(bytes: out, mime: mime, widthPx: decoded.width, heightPx: decoded.height, source: name);
  }

  /// World file: A, D, B, E, C, F (pixel size x, rotations, −pixel size y,
  /// x/y of the centre of the top-left pixel).
  static (double, double, double, double, double, double)? parseWorldFile(String text) {
    final v = text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => double.tryParse(s.replaceAll(',', '.'))).toList();
    if (v.length < 6 || v.any((x) => x == null)) return null;
    return (v[0]!, v[1]!, v[2]!, v[3]!, v[4]!, v[5]!);
  }

  static GeoImage _readTiff(String name, Uint8List bytes) {
    final tags = readTiffTags(bytes);
    final decoded = img.decodeTiff(bytes);
    if (decoded == null) throw const FormatException('image_unreadable');
    final png = Uint8List.fromList(img.encodePng(decoded));
    final g = tiffGeo(tags);
    return GeoImage(bytes: png, mime: 'image/png', widthPx: decoded.width, heightPx: decoded.height, worldTopLeft: g.topLeft, pixelSizeX: g.sx, pixelSizeY: g.sy, rotationDeg: g.rot, geographic: g.geographic, utmZone: g.zone, utmNorth: g.north, source: name);
  }

  /// Georeference carried by the GeoTIFF tags (ModelTransformation or
  /// ModelPixelScale + ModelTiepoint, GeoKeys for the CRS).
  static TiffGeo tiffGeo(TiffTags tags) {
    Pt? topLeft;
    double? sx, sy;
    var rot = 0.0;
    final scale = tags.doubles[33550];
    final tie = tags.doubles[33922];
    final transform = tags.doubles[34264];
    if (transform != null && transform.length >= 16) {
      // [a b c d; e f g h; ...] with x = a*i + b*j + d, y = e*i + f*j + h:
      // the column axis (a, e) gives the pixel size and rotation
      final a = transform[0], b = transform[1], e = transform[4], f = transform[5];
      topLeft = Pt(transform[3], transform[7]);
      sx = math.sqrt(a * a + e * e);
      sy = -math.sqrt(b * b + f * f);
      rot = radToDeg(atan2Safe(e, a));
    } else if (scale != null && tie != null && scale.length >= 2 && tie.length >= 6) {
      sx = scale[0];
      sy = -scale[1];
      // tiepoint (I,J,K) ↔ (X,Y,Z): top-left = X − I·sx, Y + J·sy
      topLeft = Pt(tie[3] - tie[0] * sx, tie[4] - tie[1] * sy);
    }
    final keys = tags.shorts[34735];
    var geographic = false;
    int? zone;
    bool? north;
    if (keys != null && keys.length >= 4) {
      final n = keys[3];
      for (var k = 0; k < n; k++) {
        final o = 4 + k * 4;
        if (o + 3 >= keys.length) break;
        final id = keys[o], loc = keys[o + 1], value = keys[o + 3];
        if (loc != 0) continue;
        if (id == 1024 && value == 2) geographic = true;
        if (id == 3072) {
          if (value >= 32601 && value <= 32660) {
            zone = value - 32600;
            north = true;
          } else if (value >= 32701 && value <= 32760) {
            zone = value - 32700;
            north = false;
          }
        }
        if (id == 2048 && value == 4326 && zone == null) geographic = true;
      }
    }
    return TiffGeo(topLeft: topLeft, sx: sx, sy: sy, rot: rot, geographic: geographic, zone: zone, north: north);
  }

  /// Baseline TIFF IFD reader for the geo tags (first IFD only).
  static TiffTags readTiffTags(Uint8List bytes) {
    final out = TiffTags();
    if (bytes.length < 8) return out;
    final bd = ByteData.sublistView(bytes);
    final little = bytes[0] == 0x49 && bytes[1] == 0x49;
    final endian = little ? Endian.little : Endian.big;
    if (bd.getUint16(2, endian) != 42) return out; // BigTIFF (43) not supported
    final ifd = bd.getUint32(4, endian);
    if (ifd + 2 > bytes.length) return out;
    final count = bd.getUint16(ifd, endian);
    for (var i = 0; i < count; i++) {
      final e = ifd + 2 + i * 12;
      if (e + 12 > bytes.length) break;
      final tag = bd.getUint16(e, endian);
      final type = bd.getUint16(e + 2, endian);
      final n = bd.getUint32(e + 4, endian);
      final size = switch (type) { 1 || 2 || 6 || 7 => 1, 3 || 8 => 2, 4 || 9 || 11 => 4, 5 || 10 || 12 => 8, _ => 1 };
      final total = size * n;
      final off = total <= 4 ? e + 8 : bd.getUint32(e + 8, endian);
      if (off + total > bytes.length) continue;
      switch (type) {
        case 3:
          out.shorts[tag] = [for (var k = 0; k < n; k++) bd.getUint16(off + k * 2, endian)];
        case 4:
          out.longs[tag] = [for (var k = 0; k < n; k++) bd.getUint32(off + k * 4, endian)];
        case 12:
          out.doubles[tag] = [for (var k = 0; k < n; k++) bd.getFloat64(off + k * 8, endian)];
        case 2:
          out.strings[tag] = String.fromCharCodes(bytes.sublist(off, off + n).where((b) => b != 0));
        default:
          break;
      }
    }
    return out;
  }
}

/// Georeference read from GeoTIFF tags.
class TiffGeo {
  const TiffGeo({this.topLeft, this.sx, this.sy, this.rot = 0, this.geographic = false, this.zone, this.north});
  final Pt? topLeft;
  final double? sx;
  final double? sy;
  final double rot;
  final bool geographic;
  final int? zone;
  final bool? north;
  bool get georeferenced => topLeft != null && sx != null && sy != null;
}

class TiffTags {
  final Map<int, List<int>> shorts = {};
  final Map<int, List<int>> longs = {};
  final Map<int, List<double>> doubles = {};
  final Map<int, String> strings = {};
}

double atan2Safe(double y, double x) => (y == 0 && x == 0) ? 0 : math.atan2(y, x);

/// Places a georeferenced image in local drawing coordinates using (or
/// creating) the project georeference. Returns (bottom-left, width, height,
/// rotation, georef).
(Pt, double, double, double, GeoReference?) placeGeoImage(GeoImage g, GeoReference? georef) {
  if (!g.georeferenced) return (Pt.zero, g.widthPx.toDouble(), g.heightPx.toDouble(), 0, georef);
  final tl = g.worldTopLeft!;
  final sx = g.pixelSizeX!, sy = g.pixelSizeY!.abs();
  if (g.geographic) {
    // lon/lat degrees: convert the corners through the georef
    final lonTL = tl.x, latTL = tl.y;
    final lonBR = tl.x + sx * g.widthPx, latBR = tl.y - sy * g.heightPx;
    final ref = georef ?? GeoReference.fromLatLonOrigin((latTL + latBR) / 2, (lonTL + lonBR) / 2);
    Pt local(double lat, double lon) {
      final u = latLonToUtm(lat, lon, zone: ref.zone);
      var northing = u.northing;
      if (ref.north && lat < 0) northing -= 10000000;
      if (!ref.north && lat >= 0) northing += 10000000;
      return Pt(u.easting - ref.originEasting, northing - ref.originNorthing);
    }

    final bl = local(latBR, lonTL), br = local(latBR, lonBR), tlp = local(latTL, lonTL);
    final w = bl.distanceTo(br), h = bl.distanceTo(tlp);
    final rot = radToDeg((br - bl).angle);
    return (bl, w, h, rot, ref);
  }
  // projected metres (UTM when zone known): shift by the origin
  var ref = georef;
  if (ref == null && g.utmZone != null) {
    ref = GeoReference(zone: g.utmZone!, north: g.utmNorth ?? true, originEasting: (tl.x / 100).round() * 100.0, originNorthing: ((tl.y - sy * g.heightPx) / 100).round() * 100.0);
  }
  final big = tl.x.abs() > 100000 || tl.y.abs() > 100000;
  final ox = ref != null && big ? ref.originEasting : 0.0;
  final oy = ref != null && big ? ref.originNorthing : 0.0;
  final w = sx * g.widthPx, h = sy * g.heightPx;
  final rot = g.rotationDeg;
  // bottom-left from the top-left corner rotated
  final down = Pt.polar(h, degToRad(rot) - math.pi / 2);
  final bl = Pt(tl.x - ox, tl.y - oy) + down;
  return (bl, w, h, rot, ref);
}
