/// Elevation rasters (GeoTIFF DEM: one band of float or integer heights,
/// as exported by QGIS, drone photogrammetry or public DEMs) imported as a
/// grid of spot heights for the terrain model. Pure Dart.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'geo.dart';
import 'geoimage.dart';

class DemSample {
  const DemSample(this.p, this.z);
  final Pt p;
  final double z;
}

class GeoTiffDem {
  GeoTiffDem({required this.widthPx, required this.heightPx, required this.samples, required this.georef, required this.step, this.geographic = false, this.crsName = ''});
  final int widthPx;
  final int heightPx;

  /// Sampled elevations in local drawing coordinates.
  final List<DemSample> samples;

  /// Project georeference used (created from the raster when none existed).
  final GeoReference? georef;

  /// Pixel step used when sampling.
  final int step;
  final bool geographic;
  final String crsName;

  (double, double) get range {
    var lo = double.infinity, hi = -double.infinity;
    for (final s in samples) {
      lo = math.min(lo, s.z);
      hi = math.max(hi, s.z);
    }
    return samples.isEmpty ? (0, 0) : (lo, hi);
  }
}

class GeoTiffDemReader {
  /// GDAL_NODATA tag.
  static const nodataTag = 42113;

  /// True when the TIFF looks like an elevation raster: a single band of
  /// floating point or 16/32-bit integer samples (not an 8-bit picture).
  static bool looksLikeDem(Uint8List bytes) {
    final tags = GeoImageReader.readTiffTags(bytes);
    final spp = tags.shorts[277]?.firstOrNull ?? tags.longs[277]?.firstOrNull ?? 1;
    final bits = tags.shorts[258]?.firstOrNull ?? 8;
    final format = tags.shorts[339]?.firstOrNull ?? 1; // 1 uint, 2 int, 3 float
    final photometric = tags.shorts[262]?.firstOrNull ?? 1;
    if (spp != 1) return false;
    if (photometric == 2 || photometric == 3) return false; // RGB / palette
    return format == 3 || bits >= 16;
  }

  /// Reads the raster and samples at most [maxPoints] elevations on a regular
  /// pixel step. Returns null when the file is not an elevation raster.
  static GeoTiffDem? read(Uint8List bytes, {GeoReference? georef, int maxPoints = 4000}) {
    if (!looksLikeDem(bytes)) return null;
    final tags = GeoImageReader.readTiffTags(bytes);
    GeoImageReader.checkTiffSize(tags);
    final decoded = img.decodeTiff(bytes);
    if (decoded == null || decoded.numChannels < 1) return null;
    final w = decoded.width, h = decoded.height;
    if (w == 0 || h == 0) return null;
    final geo = GeoImageReader.tiffGeo(tags);
    // placement (bottom-left, width, height, rotation) through the image placer
    final shell = GeoImage(bytes: Uint8List(0), mime: 'image/tiff', widthPx: w, heightPx: h, worldTopLeft: geo.topLeft, pixelSizeX: geo.sx, pixelSizeY: geo.sy, rotationDeg: geo.rot, geographic: geo.geographic, utmZone: geo.zone, utmNorth: geo.north);
    final (bl, worldW, worldH, rot, ref) = placeGeoImage(shell, georef);
    final u = Pt.polar(1, degToRad(rot)), v = u.perpendicular;
    // nodata
    double? nodata;
    final nd = tags.strings[nodataTag];
    if (nd != null) nodata = double.tryParse(nd.trim());
    final format = tags.shorts[339]?.firstOrNull ?? 1;
    final bits = tags.shorts[258]?.firstOrNull ?? 8;
    final step = math.max(1, math.sqrt(w * h / math.max(maxPoints, 1)).ceil());
    final out = <DemSample>[];
    for (var row = step ~/ 2; row < h; row += step) {
      for (var col = step ~/ 2; col < w; col += step) {
        final px = decoded.getPixel(col, row);
        final z = px.r.toDouble();
        if (!z.isFinite) continue;
        if (nodata != null && (z - nodata).abs() < 1e-6) continue;
        if (z <= -9990) continue; // common sentinel values
        if (format != 3 && bits == 16 && (z == 32767 || z == 65535 || z == -32768)) continue;
        if (format != 3 && bits == 32 && (z >= 2147483647 || z <= -2147483647)) continue;
        // pixel centre → world: columns along u from the bottom-left origin, rows from the top
        final fx = (col + 0.5) / w, fy = 1 - (row + 0.5) / h;
        final p = bl + u * (worldW * fx) + v * (worldH * fy);
        out.add(DemSample(p, z));
      }
    }
    if (out.isEmpty) return null;
    return GeoTiffDem(widthPx: w, heightPx: h, samples: out, georef: ref, step: step, geographic: geo.geographic, crsName: ref?.crsName ?? (geo.georeferenced ? 'local' : '-'));
  }
}
