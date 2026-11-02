/// Elevation rasters (GeoTIFF DEM: one band of float or integer heights,
/// as exported by QGIS, drone photogrammetry or public DEMs) imported as a
/// grid of spot heights for the terrain model. Pure Dart.
///
/// Float rasters written with the floating-point predictor (TIFF tag 317 =
/// 3, the compression GIS libraries recommend for elevations) are decoded
/// here, strip by strip or tile by tile (uncompressed, LZW or Deflate): the
/// picture decoder leaves that predictor in place and its heights would be
/// noise. The heights taken are checked: values beyond ±10 km are left out
/// and a raster that is all zero is reported.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../model/geometry.dart';
import 'geo.dart';
import 'geoimage.dart';
import 'image_decode.dart';

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

  /// Pixel step used when sampling.
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

class GeoTiffDemReader {
  /// GDAL_NODATA tag.
  static const nodataTag = 42113;

  /// Heights beyond this (metres, either sign) are not of the Earth's
  /// surface: damaged or undecoded values.
  static const maxAbsElevation = 10000.0;

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
    final predictor = tags.shorts[317]?.firstOrNull ?? 1;
    final format = tags.shorts[339]?.firstOrNull ?? 1;
    final bits = tags.shorts[258]?.firstOrNull ?? 8;
    int dim(int tag) => tags.shorts[tag]?.firstOrNull ?? tags.longs[tag]?.firstOrNull ?? 0;
    // the heights at the sampled pixels (column, row, value)
    final values = <(int, int, double)>[];
    int w, h;
    int stepFor(int w, int h) => math.max(1, math.sqrt(w * h / math.max(maxPoints, 1)).ceil());
    if (predictor == 3) {
      w = dim(256);
      h = dim(257);
      if (w <= 0 || h <= 0) return null;
      final s = stepFor(w, h);
      if (!_FloatPredictorRaster(bytes, tags).sample(s, (c, r, z) => values.add((c, r, z)))) throw const FormatException('tiff_predictor_unsupported');
    } else {
      final decoded = decodeTiffSafe(bytes);
      if (decoded == null || decoded.numChannels < 1) return null;
      w = decoded.width;
      h = decoded.height;
      if (w == 0 || h == 0) return null;
      final s = stepFor(w, h);
      for (var row = s ~/ 2; row < h; row += s) {
        for (var col = s ~/ 2; col < w; col += s) {
          values.add((col, row, decoded.getPixel(col, row).r.toDouble()));
        }
      }
    }
    final step = stepFor(w, h);
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
    // nodata
    double? nodata;
    final nd = tags.strings[nodataTag];
    if (nd != null) nodata = double.tryParse(nd.trim());
    final out = <DemSample>[];
    var outOfRange = 0;
    for (final (col, row, z) in values) {
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
      final fx = (col + 0.5) / w, fy = 1 - (row + 0.5) / h;
      final p = bl + u * (worldW * fx) + v * (worldH * fy);
      out.add(DemSample(p, z));
    }
    final warnings = <String>[
      if (geo.georeferenced) ...crsNotes(geo.crs),
      if (outOfRange > 0) 'dem_out_of_range:$outOfRange',
      // a raster of zeros is a raster that was not read (or no terrain at all)
      if (out.isNotEmpty && out.every((s) => s.z.abs() < 1e-3)) 'dem_all_zero',
    ];
    if (out.isEmpty) return null;
    return GeoTiffDem(widthPx: w, heightPx: h, samples: out, georef: ref, step: step, geographic: geo.geographic, crsName: ref?.crsName ?? (geo.georeferenced ? 'local' : '-'), warnings: warnings);
  }
}

/// A single-band float raster written with the floating-point predictor
/// (TIFF Technical Note 3): each row (of the image, or of a tile) holds the
/// bytes of its samples as planes, most significant byte first, and every
/// byte is stored as the difference from the one before it.
class _FloatPredictorRaster {
  _FloatPredictorRaster(this.bytes, this.tags);
  final Uint8List bytes;
  final TiffTags tags;

  int _one(int tag, [int def = 0]) => tags.shorts[tag]?.firstOrNull ?? tags.longs[tag]?.firstOrNull ?? def;
  List<int> _many(int tag) => tags.longs[tag] ?? tags.shorts[tag] ?? const [];

  /// Calls [emit] for the pixels on a grid of [step] (from step/2); false
  /// when the raster is not one this reader takes (band count, sample size,
  /// compression).
  bool sample(int step, void Function(int col, int row, double z) emit) {
    final w = _one(256), h = _one(257);
    final bits = _one(258, 32), spp = _one(277, 1), planar = _one(284, 1), compression = _one(259, 1);
    if (spp != 1 || planar != 1 || (bits != 32 && bits != 64) || w <= 0 || h <= 0) return false;
    if (compression != 1 && compression != 5 && compression != 8 && compression != 32946) return false;
    final bps = bits ~/ 8;
    final tiled = tags.shorts.containsKey(322) || tags.longs.containsKey(322);
    final bw = tiled ? _one(322) : w;
    final bh = tiled ? _one(323) : math.min(h, math.max(1, _one(278, h)));
    final offsets = _many(tiled ? 324 : 273), counts = _many(tiled ? 325 : 279);
    if (bw <= 0 || bh <= 0 || offsets.isEmpty || counts.length < offsets.length) return false;
    final across = tiled ? (w + bw - 1) ~/ bw : 1;
    final value = ByteData(8);
    for (var k = 0; k < offsets.length; k++) {
      final x0 = tiled ? (k % across) * bw : 0, y0 = tiled ? (k ~/ across) * bh : k * bh;
      if (y0 >= h || x0 >= w) continue;
      // only blocks that hold sampled rows and columns are decoded
      bool sampled(int a, int n) {
        final first = a <= step ~/ 2 ? step ~/ 2 : ((a - step ~/ 2 + step - 1) ~/ step) * step + step ~/ 2;
        return first < a + n;
      }

      if (!sampled(y0, bh) || !sampled(x0, bw)) continue;
      final off = offsets[k], n = counts[k];
      if (off < 0 || n <= 0 || off + n > bytes.length) return false;
      final raw = Uint8List.sublistView(bytes, off, off + n);
      final rowBytes = bw * bps;
      final need = rowBytes * bh;
      final Uint8List data;
      switch (compression) {
        case 1:
          data = raw;
        case 5:
          data = _lzw(raw, need);
        default:
          try {
            data = const ZLibDecoder().decodeBytes(raw, maxOutputSize: need);
          } on ArchiveLimitException {
            return false;
          }
      }
      final rows = math.min(bh, data.length ~/ rowBytes);
      final tmp = Uint8List(rowBytes);
      for (var r = 0; r < rows; r++) {
        final row = y0 + r;
        if (row >= h || (row - step ~/ 2) % step != 0 || row < step ~/ 2) continue;
        // undo the byte differencing of the row, then put the planes back together
        tmp.setRange(0, rowBytes, data, r * rowBytes);
        for (var i = 1; i < rowBytes; i++) {
          tmp[i] = (tmp[i] + tmp[i - 1]) & 0xFF;
        }
        for (var c = 0; c < bw; c++) {
          final col = x0 + c;
          if (col >= w || col < step ~/ 2 || (col - step ~/ 2) % step != 0) continue;
          for (var b = 0; b < bps; b++) {
            value.setUint8(b, tmp[b * bw + c]);
          }
          emit(col, row, bps == 4 ? value.getFloat32(0, Endian.big) : value.getFloat64(0, Endian.big));
        }
      }
    }
    return true;
  }

  /// TIFF LZW (codes of 9 to 12 bits, most significant bit first, the code
  /// width growing one code early), at most [size] bytes.
  static Uint8List _lzw(Uint8List src, int size) {
    final out = Uint8List(size);
    final prefix = Int32List(4096), suffix = Uint8List(4096), first = Uint8List(4096), length = Int32List(4096);
    for (var i = 0; i < 256; i++) {
      prefix[i] = -1;
      suffix[i] = i;
      first[i] = i;
      length[i] = 1;
    }
    var o = 0, p = 0, buf = 0, nbits = 0, width = 9, next = 258;
    var old = -1;
    int read() {
      while (nbits < width) {
        if (p >= src.length) return 257;
        buf = ((buf << 8) | src[p++]) & 0xFFFFFF;
        nbits += 8;
      }
      nbits -= width;
      return (buf >> nbits) & ((1 << width) - 1);
    }

    void emit(int code) {
      final n = length[code];
      var c = code;
      for (var k = n - 1; k >= 0; k--) {
        if (o + k < size) out[o + k] = suffix[c];
        c = prefix[c];
        if (c < 0) break;
      }
      o += n;
    }

    while (o < size) {
      final code = read();
      if (code == 257) break;
      if (code == 256) {
        width = 9;
        next = 258;
        old = -1;
        continue;
      }
      if (old < 0) {
        if (code > 255) break;
        emit(code);
        old = code;
        continue;
      }
      if (code < next) {
        emit(code);
        if (next < 4096) {
          prefix[next] = old;
          suffix[next] = first[code];
          first[next] = first[old];
          length[next] = length[old] + 1;
          next++;
        }
      } else {
        if (next >= 4096 || code > next) break;
        prefix[next] = old;
        suffix[next] = first[old];
        first[next] = first[old];
        length[next] = length[old] + 1;
        next++;
        emit(next - 1);
      }
      old = code;
      if (next >= (1 << width) - 1 && width < 12) width++;
    }
    return out;
  }
}
