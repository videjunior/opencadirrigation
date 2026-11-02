/// Large TIFF rasters read block by block: orthomosaics and elevation models
/// of drone surveys (hundreds of megapixels, GeoTIFF or cloud-optimised
/// GeoTIFF) are never decoded whole. The file is read IFD by IFD (classic
/// TIFF and BigTIFF, every image of the file: the reduced-resolution
/// overviews of a COG among them), and each strip or tile is decompressed
/// on its own (none, LZW, Deflate, PackBits, JPEG), its predictor undone
/// (horizontal differencing of integers, the floating-point predictor of
/// TIFF Technical Note 3). A picture is reduced by box averaging into a
/// band of output rows that moves down the raster, from the smallest
/// overview that still holds the size asked for; an elevation model is
/// sampled on a grid, decoding only the blocks the grid crosses. Memory
/// stays at one block plus the output, whatever the size of the raster.
///
/// References: TIFF 6.0 (Adobe, 1992), sections 7 (PackBits), 13 (LZW),
/// 14 (predictor), 15 (tiles) and 22 (JPEG, as revised by Technical Note 2);
/// BigTIFF (64-bit offsets, version 43); Adobe Photoshop TIFF Technical
/// Note 3 (floating-point predictor); OGC 21-026 (Cloud Optimized GeoTIFF).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import 'image_decode.dart';
import 'work_slicer.dart';

/// One image file directory: the tags of one image of the file.
class TiffIfd {
  TiffIfd(this.offset);

  /// Byte offset of the directory in the file.
  final int offset;

  /// Numeric values by tag (integers as int; RATIONAL, FLOAT and DOUBLE as
  /// double).
  final Map<int, List<num>> values = {};

  /// ASCII values by tag.
  final Map<int, String> strings = {};

  /// TIFF type of each tag as stored (3 SHORT, 4 LONG, 16 LONG8, 12 DOUBLE…).
  final Map<int, int> types = {};

  int one(int tag, [int def = 0]) {
    final v = values[tag];
    return v == null || v.isEmpty ? def : v.first.toInt();
  }

  List<int> ints(int tag) => [for (final v in values[tag] ?? const <num>[]) v.toInt()];
  List<double> doubles(int tag) => [for (final v in values[tag] ?? const <num>[]) v.toDouble()];

  int get width => one(256);
  int get height => one(257);
  int get samplesPerPixel => one(277, 1);
  int get bitsPerSample => one(258, 1);

  /// 1 unsigned integer, 2 signed integer, 3 floating point.
  int get sampleFormat => one(339, 1);
  int get compression => one(259, 1);
  int get predictor => one(317, 1);
  int get photometric => one(262, 1);

  /// 1 chunky (samples of a pixel together), 2 planar (one plane per sample).
  int get planar => one(284, 1);

  /// A reduced-resolution version of another image of the file (an overview).
  bool get reduced => one(254) & 1 == 1;

  /// A transparency mask (of another image), not a picture.
  bool get mask => one(254) & 4 == 4;

  bool get tiled => values.containsKey(322);
  int get blockWidth => tiled ? one(322) : width;
  int get blockHeight => tiled ? one(323) : math.max(1, math.min(height, one(278, height)));
  int get blocksAcross => tiled ? (width + blockWidth - 1) ~/ math.max(1, blockWidth) : 1;
  int get blocksDown => (height + blockHeight - 1) ~/ math.max(1, blockHeight);
  List<int> get blockOffsets => ints(tiled ? 324 : 273);
  List<int> get blockCounts => ints(tiled ? 325 : 279);

  /// Index of the alpha channel among the samples (ExtraSamples 1 or 2), or null.
  int? get alphaChannel {
    final extra = ints(338);
    for (var i = 0; i < extra.length; i++) {
      if (extra[i] == 1 || extra[i] == 2) return samplesPerPixel - extra.length + i;
    }
    // RGBA or grey + alpha without the tag
    if (extra.isEmpty && ((photometric == 2 && samplesPerPixel == 4) || (photometric <= 1 && samplesPerPixel == 2))) return samplesPerPixel - 1;
    return null;
  }
}

/// A TIFF or BigTIFF file and its image directories.
class TiffFile {
  TiffFile._(this.bytes, this.little, this.big);

  final Uint8List bytes;
  final bool little;

  /// BigTIFF (64-bit offsets).
  final bool big;
  final List<TiffIfd> ifds = [];

  Endian get endian => little ? Endian.little : Endian.big;

  /// Most directories read (a damaged chain of offsets could loop or run on).
  static const maxIfds = 64;

  /// Most values of one tag (a damaged count would claim gigabytes).
  static const maxValues = 1 << 24;

  /// The file in [bytes], or null when it is not a TIFF.
  static TiffFile? open(Uint8List bytes) {
    if (bytes.length < 8) return null;
    final little = bytes[0] == 0x49 && bytes[1] == 0x49;
    if (!little && !(bytes[0] == 0x4D && bytes[1] == 0x4D)) return null;
    final bd = ByteData.sublistView(bytes);
    final e = little ? Endian.little : Endian.big;
    final version = bd.getUint16(2, e);
    if (version != 42 && version != 43) return null;
    final f = TiffFile._(bytes, little, version == 43);
    var next = f.big ? (bytes.length >= 16 ? f._u64(bd, 8) : 0) : bd.getUint32(4, e);
    final seen = <int>{};
    while (next > 0 && next < bytes.length && f.ifds.length < maxIfds && seen.add(next)) {
      next = f._readIfd(bd, next);
    }
    return f;
  }

  int _u64(ByteData bd, int at) {
    final a = bd.getUint32(at, endian), b = bd.getUint32(at + 4, endian);
    return little ? a + b * 4294967296 : b + a * 4294967296;
  }

  /// Reads the directory at [at]; returns the offset of the next one (0 at the end).
  int _readIfd(ByteData bd, int at) {
    final n = bytes.length;
    final entrySize = big ? 20 : 12;
    final countSize = big ? 8 : 2;
    if (at + countSize > n) return 0;
    final count = big ? _u64(bd, at) : bd.getUint16(at, endian);
    final ifd = TiffIfd(at);
    final first = at + countSize;
    for (var i = 0; i < count && i < 4096; i++) {
      final e = first + i * entrySize;
      if (e + entrySize > n) break;
      final tag = bd.getUint16(e, endian);
      final type = bd.getUint16(e + 2, endian);
      final cnt = big ? _u64(bd, e + 4) : bd.getUint32(e + 4, endian);
      final size = switch (type) {
        1 || 2 || 6 || 7 => 1,
        3 || 8 => 2,
        4 || 9 || 11 || 13 => 4,
        5 || 10 || 12 || 16 || 17 || 18 => 8,
        _ => 0,
      };
      if (size == 0 || cnt <= 0 || cnt > maxValues) continue;
      final total = size * cnt;
      final inline = big ? 8 : 4;
      final off = total <= inline ? e + (big ? 12 : 8) : (big ? _u64(bd, e + 12) : bd.getUint32(e + 8, endian));
      if (off < 0 || off + total > n) continue;
      ifd.types[tag] = type;
      if (type == 2) {
        final s = StringBuffer();
        for (var k = 0; k < cnt; k++) {
          final c = bytes[off + k];
          if (c != 0) s.writeCharCode(c);
        }
        ifd.strings[tag] = s.toString();
        continue;
      }
      final out = <num>[];
      for (var k = 0; k < cnt; k++) {
        final p = off + k * size;
        out.add(switch (type) {
          1 || 7 => bytes[p],
          6 => bd.getInt8(p),
          3 => bd.getUint16(p, endian),
          8 => bd.getInt16(p, endian),
          4 || 13 => bd.getUint32(p, endian),
          9 => bd.getInt32(p, endian),
          11 => bd.getFloat32(p, endian),
          12 => bd.getFloat64(p, endian),
          5 => bd.getUint32(p + 4, endian) == 0 ? 0.0 : bd.getUint32(p, endian) / bd.getUint32(p + 4, endian),
          10 => bd.getInt32(p + 4, endian) == 0 ? 0.0 : bd.getInt32(p, endian) / bd.getInt32(p + 4, endian),
          _ => _u64(bd, p),
        });
      }
      ifd.values[tag] = out;
    }
    ifds.add(ifd);
    final nextAt = first + count * entrySize;
    if (nextAt + (big ? 8 : 4) > n) return 0;
    return big ? _u64(bd, nextAt) : bd.getUint32(nextAt, endian);
  }

  /// The full-resolution image (the first directory that is not an
  /// overview or a mask), or null.
  TiffIfd? get main {
    for (final d in ifds) {
      if (!d.reduced && !d.mask && d.width > 0 && d.height > 0) return d;
    }
    return ifds.isEmpty ? null : ifds.first;
  }

  /// The overviews of [main] (same bands, smaller), largest first.
  List<TiffIfd> overviewsOf(TiffIfd main) => [
    for (final d in ifds)
      if (!identical(d, main) && !d.mask && d.width > 0 && d.width < main.width && d.samplesPerPixel == main.samplesPerPixel && d.bitsPerSample == main.bitsPerSample) d,
  ]..sort((a, b) => b.width.compareTo(a.width));
}

/// The pixels of one image of a TIFF, block by block.
class TiffRaster {
  TiffRaster(this.file, this.ifd);
  final TiffFile file;
  final TiffIfd ifd;

  /// Largest decompressed block (bytes): a raster stored as one huge
  /// compressed strip cannot be read in pieces.
  static const maxBlockBytes = 256 << 20;

  int get width => ifd.width;
  int get height => ifd.height;
  int get bands => ifd.samplesPerPixel;
  bool get _jpeg => ifd.compression == 7;

  // what every block and sample reads, taken from the directory once
  late final int _bps = math.max(1, ifd.bitsPerSample ~/ 8);
  late final List<int> _offs = ifd.blockOffsets, _counts = ifd.blockCounts, _jpegTables = ifd.ints(347);
  late final int _format = ifd.sampleFormat;

  /// The byte order of the samples of a block: floating-point predicted
  /// data comes back most significant byte first.
  late final Endian _sampleEndian = ifd.predictor == 3 ? Endian.big : file.endian;

  /// Whether block [k] is left out of the file (offset and size 0: a sparse
  /// raster, whose empty blocks hold no data), not damaged.
  bool sparse(int k) => k >= 0 && k < _offs.length && _offs[k] == 0 && (k >= _counts.length || _counts[k] == 0);

  /// Largest raster read (pixels): beyond it a size field is damaged, or the
  /// file far beyond what a browser holds.
  static const maxPixels = 4e9;

  /// Why this reader cannot decode the image (a message code), or null.
  String? get unsupported {
    final f = ifd;
    if (f.width <= 0 || f.height <= 0) return 'image_unreadable';
    if (f.width.toDouble() * f.height > maxPixels) return 'image_too_large';
    if (!const {1, 5, 7, 8, 32946, 32773}.contains(f.compression)) return 'tiff_compression_unsupported';
    if (_jpeg) return f.bitsPerSample == 8 && (f.samplesPerPixel == 1 || f.samplesPerPixel == 3) ? null : 'tiff_compression_unsupported';
    if (!const {8, 16, 32, 64}.contains(f.bitsPerSample)) return 'tiff_layout_unsupported';
    if (f.photometric == 6 || f.photometric == 5 || f.photometric > 6) return 'tiff_layout_unsupported';
    if (f.blockOffsets.isEmpty || f.blockCounts.length < f.blockOffsets.length) return 'image_unreadable';
    if (f.blockWidth <= 0 || f.blockHeight <= 0) return 'image_unreadable';
    if (f.blockWidth * f.blockHeight * (f.planar == 2 ? 1 : f.samplesPerPixel) * _bps > maxBlockBytes) return 'tiff_block_too_large';
    return null;
  }

  int get _blocksPerPlane => ifd.blocksAcross * ifd.blocksDown;

  /// The decompressed bytes of block [k] (predictor undone): rows of
  /// blockWidth pixels of [bands] samples (one sample per pixel for planar
  /// rasters), in the file's byte order (big-endian for floating-point
  /// predicted data, which [sample] knows). Null for a missing block.
  Uint8List? block(int k) {
    final offs = _offs, counts = _counts;
    if (k < 0 || k >= offs.length || k >= counts.length) return null;
    final off = offs[k], n = counts[k];
    if (off <= 0 || n <= 0 || off + n > file.bytes.length) return null;
    final raw = Uint8List.sublistView(file.bytes, off, off + n);
    final spp = ifd.planar == 2 ? 1 : bands;
    final rowBytes = ifd.blockWidth * spp * _bps;
    final need = rowBytes * ifd.blockHeight;
    Uint8List data;
    switch (ifd.compression) {
      case 1:
        data = raw;
      case 5:
        data = tiffLzw(raw, need);
      case 32773:
        data = _packBits(raw, need);
      default:
        try {
          data = const ZLibDecoder().decodeBytes(raw, maxOutputSize: need);
        } on ArchiveLimitException {
          return null;
        } on Object {
          return null;
        }
    }
    final p = ifd.predictor;
    if (p == 2 || p == 3) {
      // the predictor works on a copy (the uncompressed data is the file)
      if (identical(data, raw)) data = Uint8List.fromList(raw);
      final rows = data.length ~/ rowBytes;
      for (var r = 0; r < rows; r++) {
        if (p == 2) {
          _undoHorizontal(data, r * rowBytes, ifd.blockWidth, spp, _bps);
        } else {
          _undoFloat(data, r * rowBytes, ifd.blockWidth * spp, _bps, spp);
        }
      }
    }
    return data;
  }

  void _undoHorizontal(Uint8List d, int at, int w, int spp, int bps) {
    if (bps == 1) {
      for (var i = spp; i < w * spp; i++) {
        d[at + i] = (d[at + i] + d[at + i - spp]) & 0xFF;
      }
      return;
    }
    final bd = ByteData.sublistView(d);
    final e = file.endian;
    for (var i = spp; i < w * spp; i++) {
      final p = at + i * bps, q = at + (i - spp) * bps;
      if (p + bps > d.length) return;
      switch (bps) {
        case 2:
          bd.setUint16(p, (bd.getUint16(p, e) + bd.getUint16(q, e)) & 0xFFFF, e);
        case 4:
          bd.setUint32(p, (bd.getUint32(p, e) + bd.getUint32(q, e)) % 4294967296, e);
        default:
          return;
      }
    }
  }

  /// Floating-point predictor: undo the byte differencing of a row of [n]
  /// samples ([stride] samples per pixel: each byte follows the same byte of
  /// the pixel before), then put the byte planes back together (most
  /// significant byte first), as libtiff does.
  static void _undoFloat(Uint8List d, int at, int n, int bps, int stride) {
    final len = n * bps;
    if (at + len > d.length || stride < 1) return;
    for (var i = stride; i < len; i++) {
      d[at + i] = (d[at + i] + d[at + i - stride]) & 0xFF;
    }
    final tmp = Uint8List.sublistView(d, at, at + len).sublist(0);
    for (var c = 0; c < n; c++) {
      for (var b = 0; b < bps; b++) {
        d[at + c * bps + b] = tmp[b * n + c];
      }
    }
  }

  /// The value of sample [s] of the pixel at [index] (pixel number within
  /// the block, row-major) of block data [d] ([bd] a view of it, made once
  /// per block).
  double sample(Uint8List d, int index, int s, {int? spp, ByteData? bd}) {
    final n = spp ?? (ifd.planar == 2 ? 1 : bands);
    final bps = _bps;
    final p = (index * n + s) * bps;
    if (p + bps > d.length) return double.nan;
    final fmt = _format;
    if (bps == 1) return fmt == 2 ? (d[p] >= 128 ? d[p] - 256.0 : d[p].toDouble()) : d[p].toDouble();
    final v = bd ?? ByteData.sublistView(d);
    final e = _sampleEndian;
    switch (bps) {
      case 2:
        return (fmt == 2 ? v.getInt16(p, e) : v.getUint16(p, e)).toDouble();
      case 4:
        if (fmt == 3) return v.getFloat32(p, e);
        return (fmt == 2 ? v.getInt32(p, e) : v.getUint32(p, e)).toDouble();
      case 8:
        if (fmt == 3) return v.getFloat64(p, e);
        // 64-bit integers by halves (the web has no 64-bit integer reads)
        final lo = v.getUint32(e == Endian.little ? p : p + 4, e), hi = e == Endian.little ? v.getInt32(p + 4, e) : v.getInt32(p, e);
        return hi * 4294967296.0 + lo;
    }
    return double.nan;
  }

  /// A JPEG-compressed block as pixels (the shared tables of tag 347
  /// joined to the block's own stream).
  img.Image? _jpegBlock(int k) {
    final offs = _offs, counts = _counts;
    if (k < 0 || k >= offs.length || k >= counts.length) return null;
    final off = offs[k], n = counts[k];
    if (off <= 0 || n <= 4 || off + n > file.bytes.length) return null;
    var data = Uint8List.sublistView(file.bytes, off, off + n);
    final tables = _jpegTables;
    if (tables.length > 4) {
      // tables without their end marker, the block without its start marker
      final t = Uint8List.fromList([for (final v in tables) v & 0xFF]);
      final head = t.length >= 2 && t[t.length - 2] == 0xFF && t[t.length - 1] == 0xD9 ? t.sublist(0, t.length - 2) : t;
      final body = data.length >= 2 && data[0] == 0xFF && data[1] == 0xD8 ? Uint8List.sublistView(data, 2) : data;
      data = Uint8List.fromList([...head, ...body]);
    }
    try {
      return decodeJpgSafe(data);
    } on FormatException {
      return null;
    }
  }

  /// The picture reduced to at most [maxSide] pixels on its longer side
  /// (see [TiffReducer]), the interface breathing between blocks of
  /// [slicer]. Returns the image and its factor.
  Future<(img.Image, int)> reduced(int maxSide, {double? nodata, WorkSlicer? slicer}) async {
    final r = TiffReducer(this, maxSide, nodata: nodata);
    while (!r.step(1)) {
      if (slicer != null && slicer.due) await slicer.pause(r.fraction);
    }
    return (r.image, r.factor);
  }

  /// [reduced] at once.
  (img.Image, int) reducedNow(int maxSide, {double? nodata}) {
    final r = TiffReducer(this, maxSide, nodata: nodata);
    while (!r.step(1 << 30)) {}
    return (r.image, r.factor);
  }

  double _lo = 0;

  /// The scale that brings the samples of a 16-bit or floating-point
  /// picture to 0–255 (from their range on a coarse grid of blocks; the
  /// low end in [_lo]).
  double _range() {
    var lo = double.infinity, hi = -double.infinity;
    final across = ifd.blocksAcross, down = ifd.blocksDown;
    final step = math.max(1, (math.sqrt(across * down / 16.0)).ceil());
    final spp = ifd.planar == 2 ? 1 : bands;
    final colour = math.min(bands, 3);
    for (var by = 0; by < down; by += step) {
      for (var bx = 0; bx < across; bx += step) {
        final d = block(by * across + bx);
        if (d == null) continue;
        final view = ByteData.sublistView(d);
        final n = math.min(ifd.blockWidth * ifd.blockHeight, d.length ~/ (spp * _bps));
        for (var i = 0; i < n; i += 7) {
          for (var s = 0; s < (spp == 1 ? 1 : colour); s++) {
            final v = sample(d, i, s, spp: spp, bd: view);
            if (!v.isFinite) continue;
            if (v < lo) lo = v;
            if (v > hi) hi = v;
          }
        }
      }
    }
    if (!lo.isFinite || hi <= lo) {
      _lo = 0;
      return ifd.bitsPerSample == 16 ? 255 / 65535 : 1;
    }
    // 16-bit pictures that use the whole range keep it
    if (ifd.sampleFormat != 3 && ifd.bitsPerSample == 16 && hi > 4096) {
      _lo = 0;
      return 255 / 65535;
    }
    _lo = lo;
    return 255 / (hi - lo);
  }

  /// Calls [emit] with band 0 of the pixels on a grid of [step] pixels (from
  /// step / 2), decoding only the blocks the grid crosses, the interface
  /// breathing between blocks of [slicer]. False when a block could not be
  /// read.
  Future<bool> sampleGrid(int step, void Function(int col, int row, double z) emit, {WorkSlicer? slicer}) async {
    final s = TiffGridSampler(this, step, emit);
    while (!s.step(1)) {
      if (slicer != null && slicer.due) await slicer.pause(s.fraction);
    }
    return s.ok;
  }

  /// [sampleGrid] at once.
  bool sampleGridNow(int step, void Function(int col, int row, double z) emit) {
    final s = TiffGridSampler(this, step, emit);
    while (!s.step(1 << 30)) {}
    return s.ok;
  }
}

/// The reduction of a picture: boxes of f × f pixels (f the smallest whole
/// factor that brings the longer side within the size asked for) averaged
/// into RGBA output pixels, the pixels the raster marks as empty (alpha 0,
/// or [nodata] in every band) transparent. The blocks are taken row of
/// blocks by row of blocks, so only the output rows the current row of
/// blocks crosses are held as sums.
class TiffReducer {
  TiffReducer(this.raster, int maxSide, {this.nodata}) {
    final w = raster.width, h = raster.height;
    factor = math.max(1, ((math.max(w, h)) / math.max(1, maxSide)).ceil());
    ow = (w + factor - 1) ~/ factor;
    oh = (h + factor - 1) ~/ factor;
    image = img.Image(width: ow, height: oh, numChannels: 4);
    // the range of the samples, to bring 16-bit and float pictures to 8 bits
    if (raster._bps > 1 && !raster._jpeg) {
      _scale = raster._range();
      _lo = raster._lo;
    }
  }

  final TiffRaster raster;
  final double? nodata;
  late final int factor, ow, oh;
  late final img.Image image;
  double _scale = 1, _lo = 0;
  int _by = 0, _bx = 0;

  /// Output rows in progress: per row, [r·a, g·a, b·a, a, count] per column.
  final _acc = <int, Float64List>{};

  TiffIfd get _ifd => raster.ifd;

  double get fraction => (_by * _ifd.blocksAcross + _bx) / math.max(1, _ifd.blocksAcross * _ifd.blocksDown);

  Float64List _rowOf(int oy) => _acc[oy] ??= Float64List(ow * 5);

  void _add(Float64List row, int x, double r, double g, double b, double a) {
    final i = (x ~/ factor) * 5;
    row[i] += r * a;
    row[i + 1] += g * a;
    row[i + 2] += b * a;
    row[i + 3] += a;
    row[i + 4] += 1;
  }

  /// Writes the output rows that lie wholly above input row [belowRow].
  void _flush(int belowRow) {
    final h = raster.height;
    for (final oy in [..._acc.keys]) {
      if ((oy + 1) * factor > belowRow && belowRow < h) continue;
      final row = _acc.remove(oy)!;
      for (var ox = 0; ox < ow; ox++) {
        final i = ox * 5;
        final n = row[i + 4], a = row[i + 3];
        if (n <= 0 || a <= 0) {
          image.setPixelRgba(ox, oy, 0, 0, 0, 0);
        } else {
          image.setPixelRgba(ox, oy, (row[i] / a).round().clamp(0, 255), (row[i + 1] / a).round().clamp(0, 255), (row[i + 2] / a).round().clamp(0, 255), (a / n * 255).round().clamp(0, 255));
        }
      }
    }
  }

  /// Reduces up to [budget] blocks; true when the picture is done.
  bool step(int budget) {
    final ifd = _ifd;
    final across = ifd.blocksAcross, down = ifd.blocksDown;
    for (var n = 0; n < budget; n++) {
      if (_by >= down) {
        _flush(raster.height);
        return true;
      }
      _block(_by * across + _bx, _bx * ifd.blockWidth, _by * ifd.blockHeight);
      _bx++;
      if (_bx >= across) {
        // the rows above the next row of blocks are complete
        _flush(math.min(raster.height, (_by + 1) * ifd.blockHeight));
        _bx = 0;
        _by++;
      }
    }
    if (_by >= down) {
      _flush(raster.height);
      return true;
    }
    return false;
  }

  void _block(int k, int x0, int y0) {
    final ifd = _ifd;
    final w = raster.width, h = raster.height, bands = raster.bands;
    final bw = ifd.blockWidth, bh = ifd.blockHeight, f = factor;
    final alpha = ifd.alphaChannel;
    final grey = ifd.photometric <= 1 && bands <= 2;
    final palette = ifd.photometric == 3 ? ifd.ints(320) : const <int>[];
    final whiteIsZero = ifd.photometric == 0;
    final planes = ifd.planar == 2 ? bands : 1;
    final lo = _lo, scale = _scale;
    double to8(double v) => ((v - lo) * scale).clamp(0.0, 255.0);
    // a strip spans the width: its output rows are written as soon as they
    // are complete (a raster of one large strip is not held as sums)
    final strips = ifd.blocksAcross == 1;
    void rowDone(int y) {
      if (strips && (y0 + y + 1) % f == 0) _flush(y0 + y + 1);
    }

    if (raster._jpeg) {
      final im = raster._jpegBlock(k);
      if (im == null) return;
      for (var y = 0; y < math.min(bh, im.height) && y0 + y < h; y++) {
        final row = _rowOf((y0 + y) ~/ f);
        for (var x = 0; x < math.min(bw, im.width) && x0 + x < w; x++) {
          final p = im.getPixel(x, y);
          _add(row, x0 + x, p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), 1);
        }
        rowDone(y);
      }
      return;
    }
    final data = [for (var pl = 0; pl < planes; pl++) raster.block(pl * raster._blocksPerPlane + k)];
    if (data.first == null) return;
    final spp = planes > 1 ? 1 : bands;
    if (raster._bps == 1 && planes == 1 && palette.isEmpty && (bands >= 3 || grey)) {
      // 8-bit grey or colour, one plane: the common orthomosaic
      final d = data.first!;
      final nd = nodata?.round();
      for (var y = 0; y < bh && y0 + y < h; y++) {
        final row = _rowOf((y0 + y) ~/ f);
        for (var x = 0; x < bw && x0 + x < w; x++) {
          final p = (y * bw + x) * spp;
          if (p + spp > d.length) break;
          final r = d[p], g = grey ? r : d[p + 1], b = grey ? r : d[p + 2];
          var a = alpha == null ? 1.0 : d[p + alpha] / 255;
          if (nd != null && r == nd && g == nd && b == nd) a = 0;
          if (whiteIsZero) {
            _add(row, x0 + x, 255.0 - r, 255.0 - g, 255.0 - b, a);
          } else {
            _add(row, x0 + x, r.toDouble(), g.toDouble(), b.toDouble(), a);
          }
        }
        rowDone(y);
      }
      return;
    }
    final views = [for (final d in data) d == null ? null : ByteData.sublistView(d)];
    double band(int idx, int s) {
      if (planes > 1) {
        final d = data[s];
        return d == null ? double.nan : raster.sample(d, idx, 0, spp: 1, bd: views[s]);
      }
      return raster.sample(data.first!, idx, s, spp: spp, bd: views.first);
    }

    final maxAlpha = ifd.sampleFormat == 3 ? 1.0 : math.pow(2, ifd.bitsPerSample) - 1.0;
    for (var y = 0; y < bh && y0 + y < h; y++) {
      final row = _rowOf((y0 + y) ~/ f);
      for (var x = 0; x < bw && x0 + x < w; x++) {
        final idx = y * bw + x;
        double r, g, b, a = 1;
        if (palette.isNotEmpty) {
          final v = band(idx, 0);
          final third = palette.length ~/ 3;
          if (!v.isFinite || v < 0 || v >= third) continue;
          final i = v.toInt();
          r = palette[i] / 257;
          g = palette[third + i] / 257;
          b = palette[2 * third + i] / 257;
        } else if (grey) {
          final v = band(idx, 0);
          if (!v.isFinite || (nodata != null && v == nodata)) {
            a = 0;
            r = g = b = 0;
          } else {
            r = g = b = whiteIsZero ? 255 - to8(v) : to8(v);
          }
        } else {
          final rv = band(idx, 0), gv = band(idx, math.min(1, bands - 1)), bv = band(idx, math.min(2, bands - 1));
          if ((nodata != null && rv == nodata && gv == nodata && bv == nodata) || !rv.isFinite) {
            a = 0;
            r = g = b = 0;
          } else {
            r = to8(rv);
            g = to8(gv);
            b = to8(bv);
          }
        }
        if (alpha != null && a > 0) {
          // 8 and 16-bit alpha over their whole range, float alpha 0–1
          final av = band(idx, alpha);
          a = av.isFinite ? (av / maxAlpha).clamp(0.0, 1.0) : 0;
        }
        _add(row, x0 + x, r, g, b, a);
      }
      rowDone(y);
    }
  }
}

/// The sampling of band 0 of a raster on a grid of [step] pixels (from
/// step / 2): only the blocks the grid crosses are decoded.
class TiffGridSampler {
  TiffGridSampler(this.raster, int step, this.emit) : s = math.max(1, step);
  final TiffRaster raster;
  final int s;
  final void Function(int col, int row, double z) emit;
  int _k = 0;

  /// False once a block could not be read.
  bool ok = true;

  TiffIfd get _ifd => raster.ifd;
  int get _count => _ifd.blocksAcross * _ifd.blocksDown;
  double get fraction => _k / math.max(1, _count);

  bool _crosses(int a, int n) {
    final half = s ~/ 2;
    final first = a <= half ? half : ((a - half + s - 1) ~/ s) * s + half;
    return first < a + n;
  }

  /// Samples up to [budget] blocks; true when done.
  bool step(int budget) {
    final ifd = _ifd;
    final across = ifd.blocksAcross;
    var n = 0;
    while (_k < _count && n < budget) {
      final k = _k++;
      final x0 = (k % across) * ifd.blockWidth, y0 = (k ~/ across) * ifd.blockHeight;
      if (!_crosses(y0, ifd.blockHeight) || !_crosses(x0, ifd.blockWidth)) continue;
      n++;
      _block(k, x0, y0);
    }
    return _k >= _count;
  }

  void _block(int k, int x0, int y0) {
    final ifd = _ifd;
    final bw = ifd.blockWidth, bh = ifd.blockHeight, half = s ~/ 2;
    final width = raster.width, height = raster.height;
    if (raster._jpeg) {
      final im = raster._jpegBlock(k);
      if (im == null) {
        // an empty block of a sparse raster holds no points
        if (!raster.sparse(k)) ok = false;
        return;
      }
      for (var y = 0; y < bh && y0 + y < height; y++) {
        final row = y0 + y;
        if (row < half || (row - half) % s != 0) continue;
        for (var x = 0; x < bw && x0 + x < width; x++) {
          final col = x0 + x;
          if (col < half || (col - half) % s != 0 || x >= im.width || y >= im.height) continue;
          emit(col, row, im.getPixel(x, y).r.toDouble());
        }
      }
      return;
    }
    final d = raster.block(k);
    if (d == null) {
      if (!raster.sparse(k)) ok = false;
      return;
    }
    final spp = ifd.planar == 2 ? 1 : raster.bands;
    final view = ByteData.sublistView(d);
    for (var y = 0; y < bh && y0 + y < height; y++) {
      final row = y0 + y;
      if (row < half || (row - half) % s != 0) continue;
      for (var x = 0; x < bw && x0 + x < width; x++) {
        final col = x0 + x;
        if (col < half || (col - half) % s != 0) continue;
        emit(col, row, raster.sample(d, y * bw + x, 0, spp: spp, bd: view));
      }
    }
  }
}

/// PackBits (TIFF 6.0, section 9), at most [size] bytes.
Uint8List _packBits(Uint8List src, int size) {
  final out = Uint8List(size);
  var o = 0, p = 0;
  while (p < src.length && o < size) {
    final n = src[p++];
    if (n < 128) {
      for (var k = 0; k <= n && p < src.length && o < size; k++) {
        out[o++] = src[p++];
      }
    } else if (n > 128) {
      if (p >= src.length) break;
      final v = src[p++];
      for (var k = 0; k < 257 - n && o < size; k++) {
        out[o++] = v;
      }
    }
  }
  return out;
}

/// TIFF LZW (codes of 9 to 12 bits, most significant bit first, the code
/// width growing one code early), at most [size] bytes.
Uint8List tiffLzw(Uint8List src, int size) {
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
