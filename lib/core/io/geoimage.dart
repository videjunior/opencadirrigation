/// Georeferenced raster import: JPG/PNG with a world file (.jgw/.pgw/.wld,
/// inside a .zip with the image and, when there is one, its .prj), GeoTIFF
/// (ModelPixelScale/ModelTiepoint or ModelTransformation tags, the CRS of its
/// GeoKeys: any datum and UTM zone the app knows, SIRGAS 2000, SAD 69 and
/// Córrego Alegre included) and plain images placed by the user. TIFF pixels
/// are re-encoded to PNG for the canvas. A raster in another zone or datum
/// than the project is moved through latitude/longitude (see [GeoPlacement]).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'datum.dart';
import 'geo.dart';
import 'image_decode.dart';
import 'safe_archive.dart';

class GeoImage {
  GeoImage({
    required this.bytes,
    required this.mime,
    required this.widthPx,
    required this.heightPx,
    this.worldTopLeft,
    this.pixelSizeX,
    this.pixelSizeY,
    this.rotationDeg = 0,
    this.geographic = false,
    this.utmZone,
    this.utmNorth,
    this.crs,
    this.source = '',
    this.warnings = const [],
  });

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

  /// The CRS of the coordinates when the file names one (GeoKeys, .prj);
  /// without it [geographic] and [utmZone] say what is known.
  final CrsInfo? crs;
  final String source;

  /// Notes for the import message (`crs_*` codes).
  final List<String> warnings;

  bool get georeferenced => worldTopLeft != null && pixelSizeX != null && pixelSizeY != null;

  /// Width/height in map units when georeferenced.
  double get worldWidth => (pixelSizeX ?? 1) * widthPx;
  double get worldHeight => (pixelSizeY ?? 1).abs() * heightPx;

  /// The coordinate system the placement uses: [crs], else WGS 84 degrees
  /// or its UTM zone, else none (plain metres).
  CrsInfo? get placementCrs => crs ?? (geographic ? CrsInfo.geographic() : (utmZone != null ? CrsInfo.utm(utmZone!, utmNorth ?? true) : null));
}

class GeoImageReader {
  /// Reads an image (jpg/png/tif/tiff, or a zip with image + world file).
  static GeoImage read(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.zip')) {
      final arc = openZip(bytes);
      ArchiveFile? image, world, prj;
      for (final f in arc) {
        final l = f.name.toLowerCase();
        if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.tif') || l.endsWith('.tiff')) image ??= f;
        if (l.endsWith('.jgw') || l.endsWith('.pgw') || l.endsWith('.tfw') || l.endsWith('.wld') || l.endsWith('.jpgw') || l.endsWith('.pngw')) world ??= f;
        if (l.endsWith('.prj')) prj ??= f;
      }
      if (image == null) throw const FormatException('image_zip_no_image');
      // only the picture and its side files, each up to the ceiling of an entry
      final base = read(image.name, zipEntryBytes(image));
      if (world == null) return base;
      final w = parseWorldFile(latin1.decode(zipEntryBytes(world, maxBytes: 1 << 20)));
      if (w == null) return base;
      final prjText = prj != null ? latin1.decode(zipEntryBytes(prj, maxBytes: 1 << 20)) : '';
      // the .prj names the CRS (any datum, zone or projection the app knows)
      final crs = prjText.trim().isEmpty ? null : parseCrs(prjText);
      // x = A·col + B·row + C, y = D·col + E·row + F for pixel centres: the
      // column axis (A, D) gives the pixel size and rotation; the top-left
      // corner is half a pixel back along both axes
      final (a, d, b, e, c, f) = w;
      return GeoImage(
        bytes: base.bytes,
        mime: base.mime,
        widthPx: base.widthPx,
        heightPx: base.heightPx,
        worldTopLeft: Pt(c - a / 2 - b / 2, f - d / 2 - e / 2),
        pixelSizeX: math.sqrt(a * a + d * d),
        pixelSizeY: -math.sqrt(b * b + e * e),
        rotationDeg: radToDeg(atan2Safe(d, a)),
        geographic: crs?.kind == CrsKind.geographic,
        utmZone: crs?.utmZone,
        utmNorth: crs?.utmZone != null ? crs!.north : null,
        crs: crs,
        source: image.name,
        warnings: crsNotes(crs),
      );
    }
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return _readTiff(name, bytes);
    // the decoder refuses headers beyond its own pixel limit by itself
    final info = pictureInfo(bytes);
    if (info != null) checkPixels(info.width, info.height);
    final decoded = decodeImageSafe(bytes);
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

  /// Largest raster decoded (pixels): more would exhaust the browser's
  /// memory, and a damaged size field can claim billions of pixels.
  static const maxPixels = 100000000;

  /// Throws `image_too_large` when a raster of [width] × [height] pixels
  /// exceeds [maxPixels].
  static void checkPixels(int width, int height) {
    if (width < 0 || height < 0 || width.toDouble() * height > maxPixels) throw const FormatException('image_too_large');
  }

  /// [checkPixels] for the size declared in the first IFD of a TIFF.
  static void checkTiffSize(TiffTags tags) {
    int dim(int tag) => tags.shorts[tag]?.firstOrNull ?? tags.longs[tag]?.firstOrNull ?? 0;
    checkPixels(dim(256), dim(257));
  }

  static GeoImage _readTiff(String name, Uint8List bytes) {
    final tags = readTiffTags(bytes);
    checkTiffSize(tags);
    final decoded = decodeTiffSafe(bytes);
    if (decoded == null) throw const FormatException('image_unreadable');
    final png = Uint8List.fromList(img.encodePng(decoded));
    final g = tiffGeo(tags);
    return GeoImage(
      bytes: png,
      mime: 'image/png',
      widthPx: decoded.width,
      heightPx: decoded.height,
      worldTopLeft: g.topLeft,
      pixelSizeX: g.sx,
      pixelSizeY: g.sy,
      rotationDeg: g.rot,
      geographic: g.geographic,
      utmZone: g.zone,
      utmNorth: g.north,
      crs: g.crs,
      source: name,
      warnings: g.georeferenced ? crsNotes(g.crs) : const [],
    );
  }

  /// Georeference carried by the GeoTIFF tags (ModelTransformation or
  /// ModelPixelScale + ModelTiepoint) and its CRS from the GeoKeys: the
  /// projected CRS (key 3072) or the geographic one (2048, model type 2) by
  /// their EPSG codes; a user-defined projection or a geocentric model is
  /// named as a problem.
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
    int? model, geographicCode, projectedCode;
    if (keys != null && keys.length >= 4) {
      final n = keys[3];
      for (var k = 0; k < n; k++) {
        final o = 4 + k * 4;
        if (o + 3 >= keys.length) break;
        final id = keys[o], loc = keys[o + 1], value = keys[o + 3];
        if (loc != 0) continue;
        if (id == 1024) model = value;
        if (id == 2048) geographicCode = value;
        if (id == 3072) projectedCode = value;
      }
    }
    CrsInfo? crs;
    if (projectedCode != null && projectedCode > 0 && projectedCode != 32767) {
      crs = crsFromEpsg(projectedCode);
    } else if (model == 3) {
      crs = const CrsInfo(kind: CrsKind.unknown, name: 'geocentric', problem: 'crs_geocentric');
    } else if (model == 1 || (projectedCode == 32767)) {
      // a projection defined key by key (not by a code): not supported
      crs = const CrsInfo(kind: CrsKind.unknown, name: 'user-defined', problem: 'crs_projection_unsupported');
    } else if (model == 2 || geographicCode != null) {
      crs = geographicCode != null && geographicCode > 0 && geographicCode != 32767 ? crsFromEpsg(geographicCode) : CrsInfo.geographic();
      // a code that is not geographic (a damaged key) gives no CRS
      if (crs.kind != CrsKind.geographic && crs.recognised) crs = CrsInfo.geographic();
    }
    final geographic = crs?.kind == CrsKind.geographic;
    final zone = crs?.utmZone;
    return TiffGeo(topLeft: topLeft, sx: sx, sy: sy, rot: rot, geographic: geographic, zone: zone, north: zone != null ? crs!.north : null, crs: crs);
  }

  /// Baseline TIFF IFD reader for the geo tags (first IFD only).
  static TiffTags readTiffTags(Uint8List bytes) {
    final out = TiffTags();
    if (bytes.length < 8) return out;
    final bd = ByteData.sublistView(bytes);
    final little = bytes[0] == 0x49 && bytes[1] == 0x49;
    final endian = little ? Endian.little : Endian.big;
    final version = bd.getUint16(2, endian);
    // BigTIFF (64-bit offsets) is not read: say so rather than fail later
    // with an unreadable image
    if (version == 43 && (little || (bytes[0] == 0x4D && bytes[1] == 0x4D))) throw const FormatException('tiff_bigtiff');
    if (version != 42) return out;
    final ifd = bd.getUint32(4, endian);
    if (ifd + 2 > bytes.length) return out;
    final count = bd.getUint16(ifd, endian);
    for (var i = 0; i < count; i++) {
      final e = ifd + 2 + i * 12;
      if (e + 12 > bytes.length) break;
      final tag = bd.getUint16(e, endian);
      final type = bd.getUint16(e + 2, endian);
      final n = bd.getUint32(e + 4, endian);
      final size = switch (type) {
        1 || 2 || 6 || 7 => 1,
        3 || 8 => 2,
        4 || 9 || 11 => 4,
        5 || 10 || 12 => 8,
        _ => 1,
      };
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
  const TiffGeo({this.topLeft, this.sx, this.sy, this.rot = 0, this.geographic = false, this.zone, this.north, this.crs});
  final Pt? topLeft;
  final double? sx;
  final double? sy;
  final double rot;
  final bool geographic;
  final int? zone;
  final bool? north;

  /// The CRS of the GeoKeys (null when the file has none).
  final CrsInfo? crs;
  bool get georeferenced => topLeft != null && sx != null && sy != null;
}

class TiffTags {
  final Map<int, List<int>> shorts = {};
  final Map<int, List<int>> longs = {};
  final Map<int, List<double>> doubles = {};
  final Map<int, String> strings = {};
}

double atan2Safe(double y, double x) => (y == 0 && x == 0) ? 0 : math.atan2(y, x);

/// Notes for the import of a raster in [crs]: why it cannot be used (it is
/// then read as plain metres), or the datum shift applied to place it.
List<String> crsNotes(CrsInfo? crs) {
  if (crs == null) return const [];
  if (!crs.recognised) return [crs.problem ?? 'crs_unparsed'];
  final d = crs.datum;
  if (d != null && !d.isWgs84Compatible) return ['crs_datum_shift:${d.name}:${d.toleranceM}'];
  return const [];
}

/// Places a georeferenced image in local drawing coordinates using (or
/// creating) the project georeference. Returns (bottom-left, width, height,
/// rotation, georef).
///
/// With a recognised CRS (geographic or projected, any datum and zone the
/// app knows) the corners go through latitude/longitude into the project's
/// zone, with the datum shift: a SIRGAS 2000 or SAD 69 raster, or one of
/// another zone, lands where it belongs. Without a project georeference one
/// is created from the bottom-left corner (origin rounded to 100 m). Other
/// rasters keep their coordinates as metres, moved by the project origin
/// when they are large.
(Pt, double, double, double, GeoReference?) placeGeoImage(GeoImage g, GeoReference? georef) {
  if (!g.georeferenced) return (Pt.zero, g.widthPx.toDouble(), g.heightPx.toDouble(), 0, georef);
  final tl = g.worldTopLeft!;
  final sx = g.pixelSizeX!, sy = g.pixelSizeY!.abs();
  final w = sx * g.widthPx, h = sy * g.heightPx;
  final rot = g.rotationDeg;
  // corners in the file's coordinates: the column axis turned by the rotation
  final u = Pt.polar(1, degToRad(rot)), v = u.perpendicular;
  final blF = tl - v * h, brF = blF + u * w;
  final crs = g.placementCrs;
  if (crs != null && crs.recognised && crs.kind != CrsKind.local) {
    final plan = GeoPlacement.plan(crs, [(blF.x, blF.y)], georef: georef);
    final bl = plan.place(blF.x, blF.y), br = plan.place(brF.x, brF.y), tlp = plan.place(tl.x, tl.y);
    return (bl, bl.distanceTo(br), bl.distanceTo(tlp), radToDeg((br - bl).angle), plan.georef ?? georef);
  }
  // projected metres of no known CRS: shift by the origin when large
  final big = tl.x.abs() > 100000 || tl.y.abs() > 100000;
  final ox = georef != null && big ? georef.originEasting : 0.0;
  final oy = georef != null && big ? georef.originNorthing : 0.0;
  return (Pt(blF.x - ox, blF.y - oy), w, h, rot, georef);
}
