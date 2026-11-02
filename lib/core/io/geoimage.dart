/// Georeferenced raster import: JPG/PNG with a world file (.jgw/.pgw/.wld,
/// inside a .zip with the image and, when there is one, its .prj), GeoTIFF
/// (ModelPixelScale/ModelTiepoint or ModelTransformation tags, the CRS of its
/// GeoKeys: any datum and UTM zone the app knows, SIRGAS 2000, SAD 69 and
/// Córrego Alegre included, and the projections given key by key: Albers,
/// Lambert conformal conic, polyconic) and plain images placed by the user.
/// TIFF pixels are re-encoded to PNG for the canvas; large GeoTIFFs
/// (BigTIFF, cloud-optimised GeoTIFF, drone orthomosaics of hundreds of
/// megapixels) are read block by block and reduced (see tiff_raster.dart).
/// A raster in another zone or datum than the project is moved through
/// latitude/longitude (see [GeoPlacement]).
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
import 'tiff_raster.dart';
import 'work_slicer.dart';

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
    // a BigTIFF, a raster of many megapixels or a COG: block by block, reduced
    if (isLargeTiff(bytes)) return readLargeTiffNow(name, bytes);
    final tags = readTiffTags(bytes);
    checkTiffSize(tags);
    // what the picture decoder reads wrongly without failing: the
    // floating-point predictor, the horizontal one of samples wider than a byte
    final f = TiffFile.open(bytes), m = f?.main;
    if (f != null && m != null && (m.predictor == 3 || (m.predictor == 2 && m.bitsPerSample > 8)) && TiffRaster(f, m).unsupported == null) return readLargeTiffNow(name, bytes);
    img.Image? decoded;
    try {
      decoded = decodeTiffSafe(bytes);
    } on FormatException {
      decoded = null;
    }
    // what the picture decoder does not take
    if (decoded == null && m != null) return readLargeTiffNow(name, bytes);
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
  /// their EPSG codes, or a projection given key by key ([userDefinedCrs]);
  /// a projection the app does not hold or a geocentric model is named as a
  /// problem.
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
    final keys = geoKeys(tags);
    final model = keys.ints[1024], geographicCode = keys.ints[2048], projectedCode = keys.ints[3072];
    CrsInfo? crs;
    if (projectedCode != null && projectedCode > 0 && projectedCode != 32767) {
      crs = crsFromEpsg(projectedCode);
    } else if (model == 3) {
      crs = const CrsInfo(kind: CrsKind.unknown, name: 'geocentric', problem: 'crs_geocentric');
    } else if (model == 1 || (projectedCode == 32767)) {
      // a projection defined key by key (ProjectedCSType 32767): the method
      // and its parameters (transverse Mercator, Albers, Lambert conformal
      // conic, polyconic) on the datum the geographic keys give
      crs = userDefinedCrs(keys);
    } else if (model == 2 || geographicCode != null) {
      crs = geographicCode != null && geographicCode > 0 && geographicCode != 32767 ? crsFromEpsg(geographicCode) : CrsInfo.geographic();
      // a code that is not geographic (a damaged key) gives no CRS
      if (crs.kind != CrsKind.geographic && crs.recognised) crs = CrsInfo.geographic();
    }
    final geographic = crs?.kind == CrsKind.geographic;
    final zone = crs?.utmZone;
    return TiffGeo(topLeft: topLeft, sx: sx, sy: sy, rot: rot, geographic: geographic, zone: zone, north: zone != null ? crs!.north : null, crs: crs);
  }

  /// The tags of the full-resolution image of a TIFF or BigTIFF (empty for
  /// other data): SHORT values in [TiffTags.shorts], LONG and LONG8 in
  /// [TiffTags.longs], DOUBLE, FLOAT and RATIONAL in [TiffTags.doubles],
  /// ASCII in [TiffTags.strings].
  static TiffTags readTiffTags(Uint8List bytes) => tagsOf(TiffFile.open(bytes)?.main);

  /// [readTiffTags] of one directory.
  static TiffTags tagsOf(TiffIfd? ifd) {
    final out = TiffTags();
    if (ifd == null) return out;
    for (final e in ifd.values.entries) {
      switch (ifd.types[e.key]) {
        case 3:
          out.shorts[e.key] = [for (final v in e.value) v.toInt()];
        case 4 || 13 || 16:
          out.longs[e.key] = [for (final v in e.value) v.toInt()];
        case 5 || 11 || 12:
          out.doubles[e.key] = [for (final v in e.value) v.toDouble()];
        default:
          break;
      }
    }
    out.strings.addAll(ifd.strings);
    return out;
  }

  /// Rasters above this size (pixels) are read block by block and reduced
  /// ([readLargeTiff]); smaller ones are decoded whole.
  static const reduceAbove = 4096 * 4096;

  /// The longer side (pixels) of a reduced raster.
  static const reducedSide = 4096;

  /// Whether the TIFF in [bytes] is read block by block: a BigTIFF, a
  /// raster above [reduceAbove] pixels, or one with overviews (a COG).
  static bool isLargeTiff(Uint8List bytes) {
    final f = TiffFile.open(bytes);
    final m = f?.main;
    if (f == null || m == null) return false;
    // a BigTIFF only this reader takes; a large raster or a COG when this
    // reader takes its layout (the picture decoder takes the others, fax
    // compressions or 1-bit scans of a plan, within its size limit)
    if (f.big) return true;
    final large = m.width.toDouble() * m.height > reduceAbove || f.overviewsOf(m).isNotEmpty;
    return large && TiffRaster(f, m).unsupported == null;
  }

  /// A large GeoTIFF (an orthomosaic of a drone survey) read block by block
  /// from its smallest overview that still holds [maxSide] pixels, reduced
  /// by averaging to at most [maxSide] on its longer side and encoded as
  /// JPEG (PNG when it has transparent parts), with its georeference
  /// scaled to the new pixels. [GeoImage.warnings] gets
  /// `image_reduced:<W>×<H> → <w>×<h>`.
  static Future<GeoImage> readLargeTiff(String name, Uint8List bytes, {int maxSide = reducedSide, WorkSlicer? slicer}) async {
    final (raster, main, nodata) = _largeRaster(bytes, maxSide);
    final (image, factor) = await raster.reduced(maxSide, nodata: nodata, slicer: slicer);
    if (slicer != null) await slicer.pause(0.97);
    return _reducedImage(name, main, raster.ifd, image, factor);
  }

  /// [readLargeTiff] at once (imports without a progress dialog).
  static GeoImage readLargeTiffNow(String name, Uint8List bytes, {int maxSide = reducedSide}) {
    final (raster, main, nodata) = _largeRaster(bytes, maxSide);
    final (image, factor) = raster.reducedNow(maxSide, nodata: nodata);
    return _reducedImage(name, main, raster.ifd, image, factor);
  }

  /// The raster [readLargeTiff] reads (the smallest image, the full one or
  /// an overview, still [maxSide] across), the full image and the value
  /// of the empty pixels.
  static (TiffRaster, TiffIfd, double?) _largeRaster(Uint8List bytes, int maxSide) {
    final f = TiffFile.open(bytes);
    final main = f?.main;
    if (f == null || main == null) throw const FormatException('image_unreadable');
    var use = main;
    for (final o in f.overviewsOf(main)) {
      if (math.max(o.width, o.height) >= maxSide) use = o;
    }
    final raster = TiffRaster(f, use);
    final problem = raster.unsupported;
    if (problem != null) throw FormatException(problem);
    final nd = main.strings[GeoTiffNoData.tag];
    return (raster, main, nd == null ? null : double.tryParse(nd.trim()));
  }

  static GeoImage _reducedImage(String name, TiffIfd main, TiffIfd use, img.Image image, int factor) {
    final tags = tagsOf(main);
    var opaque = true;
    for (final p in image) {
      if (p.a < 255) {
        opaque = false;
        break;
      }
    }
    final encoded = opaque ? Uint8List.fromList(img.encodeJpg(image, quality: 88)) : Uint8List.fromList(img.encodePng(image));
    final g = tiffGeo(tags);
    // the pixel size of the reduced image: of the image read, times the factor
    final k = main.width / use.width * factor;
    return GeoImage(
      bytes: encoded,
      mime: opaque ? 'image/jpeg' : 'image/png',
      widthPx: image.width,
      heightPx: image.height,
      worldTopLeft: g.topLeft,
      pixelSizeX: g.sx == null ? null : g.sx! * k,
      pixelSizeY: g.sy == null ? null : g.sy! * k,
      rotationDeg: g.rot,
      geographic: g.geographic,
      utmZone: g.zone,
      utmNorth: g.north,
      crs: g.crs,
      source: name,
      warnings: [if (g.georeferenced) ...crsNotes(g.crs), if (main.width != image.width) 'image_reduced:${main.width}×${main.height} → ${image.width}×${image.height}'],
    );
  }
}

/// The GDAL_NODATA tag: the value of the empty pixels, as text.
abstract final class GeoTiffNoData {
  static const tag = 42113;
}

/// The GeoKeys of a GeoTIFF (GeoKeyDirectoryTag 34735): integer values
/// (stored in the directory), doubles (GeoDoubleParamsTag 34736) and texts
/// (GeoAsciiParamsTag 34737), by key.
class GeoKeys {
  final Map<int, int> ints = {};
  final Map<int, double> doubles = {};
  final Map<int, String> texts = {};
}

/// The GeoKeys of [tags].
GeoKeys geoKeys(TiffTags tags) {
  final out = GeoKeys();
  final keys = tags.shorts[34735];
  if (keys == null || keys.length < 4) return out;
  final dbl = tags.doubles[34736] ?? const <double>[];
  final ascii = tags.strings[34737] ?? '';
  final n = keys[3];
  for (var k = 0; k < n; k++) {
    final o = 4 + k * 4;
    if (o + 3 >= keys.length) break;
    final id = keys[o], loc = keys[o + 1], count = keys[o + 2], value = keys[o + 3];
    if (loc == 0) {
      out.ints[id] = value;
    } else if (loc == 34736 && value < dbl.length) {
      out.doubles[id] = dbl[value];
    } else if (loc == 34737 && value < ascii.length) {
      out.texts[id] = ascii.substring(value, (value + count).clamp(value, ascii.length)).replaceAll('|', ' ').trim();
    }
  }
  return out;
}

/// The datum of the geographic keys: GeographicTypeGeoKey (2048) or
/// GeogGeodeticDatumGeoKey (2050) by EPSG code, else GRS 80 or WGS 84
/// ellipsoid parameters (7019, 7030 or the axis and flattening keys),
/// taken as WGS 84 at mapping accuracy; null when unknown.
GeodeticDatum? geoKeysDatum(GeoKeys k) {
  final gcs = k.ints[2048];
  if (gcs != null && gcs > 0 && gcs != 32767) {
    final c = crsFromEpsg(gcs);
    if (c.datum != null) return c.datum;
  }
  const datums = {
    6326: GeodeticDatum.wgs84,
    6674: GeodeticDatum.sirgas2000,
    6618: GeodeticDatum.sad69,
    1075: GeodeticDatum.sad69r96,
    // the code of its geographic system, which some writers put here
    5527: GeodeticDatum.sad69r96,
    6225: GeodeticDatum.corregoAlegre,
    6258: GeodeticDatum.etrs89,
    6171: GeodeticDatum.etrs89,
    6269: GeodeticDatum.nad83,
  };
  final d = datums[k.ints[2050]];
  if (d != null) return d;
  final citation = k.texts[2049] ?? k.texts[1026] ?? '';
  final named = datumFromName(citation);
  if (named != null) return named;
  final ellipsoid = k.ints[2056];
  if (ellipsoid == 7019 || ellipsoid == 7030) return GeodeticDatum.wgs84;
  final a = k.doubles[2057], rf = k.doubles[2059];
  if (a != null && (a - 6378137).abs() < 1e-3 && rf != null && (rf - 298.2572).abs() < 1e-3) return GeodeticDatum.wgs84;
  return null;
}

/// The CRS of a projection given key by key (ProjectedCSType 32767): the
/// coordinate transformation (ProjCoordTransGeoKey 3075: 1 transverse
/// Mercator, 8 and 9 Lambert conformal conic, 11 Albers, 22 polyconic), its
/// parameters (3078–3093, as GDAL and the GeoTIFF specification write them)
/// and the linear unit (3076/3077); a problem code when it cannot be used.
CrsInfo userDefinedCrs(GeoKeys k) {
  final name = k.texts[3073] ?? k.texts[1026] ?? 'user-defined';
  // a projection given by its EPSG code (ProjectionGeoKey 3074: 16001–16060 UTM north, 16101–16160 south)
  final conv = k.ints[3074];
  final datum = geoKeysDatum(k);
  if (conv != null && conv >= 16001 && conv <= 16160 && (conv - 16000) % 100 <= 60 && (conv - 16000) % 100 >= 1) {
    final zone = (conv - 16000) % 100, north = conv < 16100;
    if (datum == null) return CrsInfo(kind: CrsKind.projected, projection: TransverseMercator.utm(zone, north), name: name, problem: 'crs_datum_unknown');
    final c = CrsInfo.utm(zone, north, datum: datum);
    return CrsInfo(kind: c.kind, datum: datum, projection: c.projection, epsg: c.epsg, name: c.name);
  }
  final unitCode = k.ints[3076];
  final unit =
      k.doubles[3077] ??
      switch (unitCode) {
        9002 => 0.3048,
        9003 => 1200 / 3937,
        9036 => 1000.0,
        _ => 1.0,
      };
  final method = switch (k.ints[3075]) {
    1 => 'transverse_mercator',
    8 => 'lambert_conformal_conic_2sp',
    9 => 'lambert_conformal_conic_1sp',
    11 => 'albers',
    22 => 'polyconic',
    _ => '',
  };
  if (method.isEmpty) return CrsInfo(kind: CrsKind.unknown, datum: datum, name: name, problem: 'crs_projection_unsupported');
  final d = k.doubles;
  double? first(List<int> ids) {
    for (final id in ids) {
      final v = d[id];
      if (v != null) return v;
    }
    return null;
  }

  // the natural origin, the false origin or the centre, whichever is given
  final fe = first([3082, 3086]), fn = first([3083, 3087]);
  final params = <String, double>{
    'standardparallel1': ?d[3078],
    'standardparallel2': ?d[3079],
    'longitudeofnaturalorigin': ?first([3080, 3084, 3088]),
    'latitudeofnaturalorigin': ?first([3081, 3085, 3089]),
    'falseeasting': ?(fe == null ? null : fe * unit),
    'falsenorthing': ?(fn == null ? null : fn * unit),
    'scalefactor': ?first([3092, 3093]),
  };
  final ellipsoid = datum?.ellipsoid ?? (d[2057] != null && d[2059] != null ? Ellipsoid(d[2057]!, d[2059]!) : Ellipsoid.wgs84);
  final p = projectionFromParameters(method, params, ellipsoid);
  if (p == null) return CrsInfo(kind: CrsKind.unknown, datum: datum, name: name, problem: 'crs_projection_unsupported');
  if (datum == null) return CrsInfo(kind: CrsKind.projected, projection: p, name: name, unitM: unit, problem: 'crs_datum_unknown');
  final z = p.utmZone;
  return CrsInfo(kind: CrsKind.projected, datum: datum, projection: p, epsg: z != null ? datum.utmEpsg(z, p.north) : null, name: name, unitM: unit);
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
