/// Elevation rasters (GeoTIFF DEM: one band of float or integer heights,
/// as exported by QGIS, drone photogrammetry or public DEMs) imported as a
/// grid of spot heights for the terrain model. Pure Dart.
///
/// The raster is never decoded whole: the heights are sampled on a regular
/// grid, from the smallest overview of a cloud-optimised GeoTIFF that still
/// holds the grid, decoding only the strips or tiles the grid crosses
/// (tiff_raster.dart: classic TIFF and BigTIFF, uncompressed, LZW, Deflate
/// or PackBits, with the horizontal or the floating-point predictor), so a
/// drone elevation model of hundreds of megapixels takes the memory of one
/// block. The heights taken are checked: values beyond ±10 km are left out
/// and a raster that is all zero is reported.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'geo.dart';
import 'geoimage.dart';
import 'image_decode.dart';
import 'tiff_raster.dart';
import 'work_slicer.dart';

class DemSample {
  const DemSample(this.p, this.z);
  final Pt p;
  final double z;
}

class GeoTiffDem {
  GeoTiffDem({required this.widthPx, required this.heightPx, required this.samples, required this.georef, required this.step, this.geographic = false, this.crsName = '', this.warnings = const []});
  final int widthPx;
  final int heightPx;

  /// Sampled elevations in local drawing coordinates.
  final List<DemSample> samples;

  /// Project georeference used (created from the raster when none existed).
  final GeoReference? georef;

  /// Pixel step used when sampling (pixels of the full-resolution raster).
  final int step;
  final bool geographic;
  final String crsName;

  /// Notes for the import message: the CRS problems, `dem_out_of_range:<n>`
  /// (heights beyond ±10 km left out), `dem_all_zero`.
  final List<String> warnings;

  (double, double) get range {
    var lo = double.infinity, hi = -double.infinity;
    for (final s in samples) {
      lo = math.min(lo, s.z);
      hi = math.max(hi, s.z);
    }
    return samples.isEmpty ? (0, 0) : (lo, hi);
  }
}

/// What [GeoTiffDemReader] reads from: the raster of the grid (the full
/// image or an overview) and the step on it.
class _DemPlan {
  _DemPlan(this.tags, this.width, this.height, this.raster, this.step, this.fullStep);
  final TiffTags tags;

  /// Size of the full-resolution raster.
  final int width, height;

  /// Null: decoded by the picture decoder (a layout the block reader does
  /// not take).
  final TiffRaster? raster;

  /// The grid step on [raster] and on the full-resolution raster.
  final int step, fullStep;
}

class GeoTiffDemReader {
  /// GDAL_NODATA tag.
  static const nodataTag = 42113;

  /// Heights beyond this (metres, either sign) are not of the Earth's
  /// surface: damaged or undecoded values.
  static const maxAbsElevation = 10000.0;

  /// Largest elevation raster read (pixels): beyond it a size field is
  /// damaged, or the file far beyond what a browser holds.
  static const maxPixels = TiffRaster.maxPixels;

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

  static int _stepFor(int w, int h, int maxPoints) => math.max(1, math.sqrt(w * h / math.max(maxPoints, 1)).ceil());

  static _DemPlan? _plan(Uint8List bytes, int maxPoints) {
    if (!looksLikeDem(bytes)) return null;
    final f = TiffFile.open(bytes);
    final main = f?.main;
    if (f == null || main == null) return null;
    final tags = GeoImageReader.tagsOf(main);
    final w = main.width, h = main.height;
    if (w <= 0 || h <= 0) return null;
    if (w.toDouble() * h > maxPixels) throw const FormatException('image_too_large');
    final full = _stepFor(w, h, maxPoints);
    // the smallest overview that still has a pixel for every point of the grid
    var use = main;
    for (final o in f.overviewsOf(main)) {
      if (o.width * full >= w && o.height * full >= h) use = o;
    }
    var raster = TiffRaster(f, use);
    if (raster.unsupported != null && !identical(use, main)) raster = TiffRaster(f, main);
    if (raster.unsupported != null) {
      if (raster.unsupported == 'tiff_block_too_large') throw const FormatException('image_too_large');
      // the picture decoder takes the rest (within its own pixel limit)
      GeoImageReader.checkTiffSize(tags);
      if (main.predictor == 3) throw const FormatException('tiff_predictor_unsupported');
      return _DemPlan(tags, w, h, null, full, full);
    }
    final k = w / raster.width;
    return _DemPlan(tags, w, h, raster, math.max(1, (full / k).round()), full);
  }

  /// Reads the raster and samples at most about [maxPoints] elevations on a
  /// regular pixel step. Returns null when the file is not an elevation
  /// raster.
  static GeoTiffDem? read(Uint8List bytes, {GeoReference? georef, int maxPoints = 4000}) {
    final plan = _plan(bytes, maxPoints);
    if (plan == null) return null;
    final values = <(double, double, double)>[];
    final raster = plan.raster;
    if (raster != null) {
      if (!raster.sampleGridNow(plan.step, (c, r, z) => values.add(((c + 0.5) / raster.width, (r + 0.5) / raster.height, z)))) throw const FormatException('file_corrupt');
    } else {
      if (!_decodeWhole(bytes, plan, values)) return null;
    }
    return _finish(plan, values, georef);
  }

  /// [read] in slices of [slicer] (the interface stays responsive and the
  /// user can cancel).
  static Future<GeoTiffDem?> readAsync(Uint8List bytes, WorkSlicer slicer, {GeoReference? georef, int maxPoints = 4000}) async {
    final plan = _plan(bytes, maxPoints);
    if (plan == null) return null;
    final values = <(double, double, double)>[];
    final raster = plan.raster;
    if (raster != null) {
      final ok = await raster.sampleGrid(plan.step, (c, r, z) => values.add(((c + 0.5) / raster.width, (r + 0.5) / raster.height, z)), slicer: slicer);
      if (!ok) throw const FormatException('file_corrupt');
    } else {
      if (!_decodeWhole(bytes, plan, values)) return null;
    }
    await slicer.pause(0.95);
    return _finish(plan, values, georef);
  }

  /// The grid of [plan] from the picture decoder (the whole raster at once).
  static bool _decodeWhole(Uint8List bytes, _DemPlan plan, List<(double, double, double)> values) {
    final decoded = decodeTiffSafe(bytes);
    if (decoded == null || decoded.numChannels < 1) return false;
    final w = decoded.width, h = decoded.height;
    if (w == 0 || h == 0) return false;
    final s = plan.fullStep;
    for (var row = s ~/ 2; row < h; row += s) {
      for (var col = s ~/ 2; col < w; col += s) {
        values.add(((col + 0.5) / w, (row + 0.5) / h, decoded.getPixel(col, row).r.toDouble()));
      }
    }
    return true;
  }

  /// The spot heights of [values] ((fraction across, fraction down, z) of
  /// pixel centres) placed through the georeference of the raster.
  static GeoTiffDem? _finish(_DemPlan plan, List<(double, double, double)> values, GeoReference? georef) {
    final tags = plan.tags;
    final w = plan.width, h = plan.height;
    final format = tags.shorts[339]?.firstOrNull ?? 1;
    final bits = tags.shorts[258]?.firstOrNull ?? 8;
    final geo = GeoImageReader.tiffGeo(tags);
    // placement (bottom-left, width, height, rotation) through the image placer
    final shell = GeoImage(
      bytes: Uint8List(0),
      mime: 'image/tiff',
      widthPx: w,
      heightPx: h,
      worldTopLeft: geo.topLeft,
      pixelSizeX: geo.sx,
      pixelSizeY: geo.sy,
      rotationDeg: geo.rot,
      geographic: geo.geographic,
      utmZone: geo.zone,
      utmNorth: geo.north,
      crs: geo.crs,
    );
    final (bl, worldW, worldH, rot, ref) = placeGeoImage(shell, georef);
    final u = Pt.polar(1, degToRad(rot)), v = u.perpendicular;
    double? nodata;
    final nd = tags.strings[nodataTag];
    if (nd != null) nodata = double.tryParse(nd.trim());
    final out = <DemSample>[];
    var outOfRange = 0;
    for (final (fx, fyDown, z) in values) {
      if (!z.isFinite) continue;
      if (nodata != null && (z - nodata).abs() < 1e-6) continue;
      if (z <= -9990) continue; // common sentinel values
      if (format != 3 && bits == 16 && (z == 32767 || z == 65535 || z == -32768)) continue;
      if (format != 3 && bits == 32 && (z >= 2147483647 || z <= -2147483647)) continue;
      if (z.abs() > maxAbsElevation) {
        outOfRange++;
        continue;
      }
      // pixel centre → world: columns along u from the bottom-left origin, rows from the top
      final p = bl + u * (worldW * fx) + v * (worldH * (1 - fyDown));
      out.add(DemSample(p, z));
    }
    final warnings = <String>[
      if (geo.georeferenced) ...crsNotes(geo.crs),
      if (outOfRange > 0) 'dem_out_of_range:$outOfRange',
      // a raster of zeros is a raster that was not read (or no terrain at all)
      if (out.isNotEmpty && out.every((s) => s.z.abs() < 1e-3)) 'dem_all_zero',
    ];
    if (out.isEmpty) return null;
    return GeoTiffDem(
      widthPx: w,
      heightPx: h,
      samples: out,
      georef: ref,
      step: plan.fullStep,
      geographic: geo.geographic,
      crsName: ref?.crsName ?? (geo.georeferenced ? 'local' : '-'),
      warnings: warnings,
    );
  }
}
