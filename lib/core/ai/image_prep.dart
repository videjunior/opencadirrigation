/// Pictures as the models take them. A picture a user attaches is read from
/// its own bytes (a file name can lie), kept as it is when it already fits,
/// and otherwise turned and scaled down into the limits and encoded as a
/// JPEG: at most [maxModelImageEdge] pixels a side and [maxModelImageTokens]
/// visual tokens, at most [maxModelImageBytes], in a type every provider
/// reads (JPEG, PNG, GIF, WebP). The pictures the tools draw go as JPEG
/// when they are photos ([encodeJpegRgba]): a fraction of their PNG, which
/// keeps a conversation's requests small, since every earlier picture is
/// sent again with each request.
///
/// Pure Dart (package:image): the same code runs in the browser, on the
/// desktop and in the tests.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest side of a picture sent to a model. Claude reads up to 2576 px,
/// but once a request holds more than 20 pictures (a conversation sends
/// every earlier one again) each must be at most 2000 px a side, or the
/// request is refused.
const maxModelImageEdge = 2000;

/// Visual tokens (28 × 28-pixel patches) Claude's high-resolution models
/// read of one picture; a larger one is scaled down on the server.
const maxModelImageTokens = 4784;

/// Largest picture sent: 3.75 MB, 5 MB in base64 (the Claude API takes up
/// to 10 MB in base64 per picture, some platforms 5 MB).
const maxModelImageBytes = 3750000;

/// JPEG quality of the pictures this program encodes.
const modelJpegQuality = 85;

/// The media types every provider reads.
const modelImageTypes = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};

/// The media type of [b] from its first bytes (JPEG, PNG, GIF, WebP, BMP,
/// TIFF), or null when it is none of them.
String? sniffImageType(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (at(0, 'GIF87a'.codeUnits) || at(0, 'GIF89a'.codeUnits)) return 'image/gif';
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  if (at(0, 'BM'.codeUnits)) return 'image/bmp';
  if (at(0, const [0x49, 0x49, 0x2A, 0x00]) || at(0, const [0x4D, 0x4D, 0x00, 0x2A])) return 'image/tiff';
  return null;
}

/// Visual tokens of a [w] × [h] picture for Claude.
int visualTokens(int w, int h) => ((w + 27) ~/ 28) * ((h + 27) ~/ 28);

/// The size [w] × [h] scaled down (never up) to at most [maxEdge] pixels a
/// side and [maxTokens] visual tokens, keeping its proportions.
(int, int) fitModelImage(int w, int h, {int maxEdge = maxModelImageEdge, int maxTokens = maxModelImageTokens}) {
  if (w <= 0 || h <= 0) return (math.max(1, w), math.max(1, h));
  var s = math.min(1.0, maxEdge / math.max(w, h));
  (int, int) at(double f) => (math.max(1, (w * f).floor()), math.max(1, (h * f).floor()));
  var (tw, th) = at(s);
  while (visualTokens(tw, th) > maxTokens && s > 0.01) {
    s *= 0.98;
    (tw, th) = at(s);
  }
  return s >= 1 ? (w, h) : (tw, th);
}

/// A picture ready for a model.
class ModelImage {
  const ModelImage(this.bytes, this.mediaType, this.width, this.height, {this.changed = false});
  final Uint8List bytes;
  final String mediaType;

  /// Its size in pixels.
  final int width, height;

  /// Turned, scaled down or encoded anew (false: the bytes as given).
  final bool changed;
}

/// [bytes], a picture to show a model (whatever media type its file name
/// gave), as the model takes it; null when it cannot be read as a picture.
///
/// A picture in a type the models read, within the limits and not turned
/// by its EXIF orientation (the models read no metadata, so they would see
/// it on its side) goes as it is: its real media type, the same bytes. A
/// lossless one over [recodeAbove] bytes goes as a JPEG when that is much
/// smaller (a photo, an aerial image), still at its own size, so positions
/// on it hold. Anything else is decoded (the first frame of an animation),
/// turned upright, scaled down into [maxEdge] and [maxTokens], set on white
/// where transparent, and encoded as a JPEG at [quality], lower and then
/// smaller until it fits [maxBytes].
ModelImage? prepareModelImage(
  Uint8List bytes, {
  int maxEdge = maxModelImageEdge,
  int maxTokens = maxModelImageTokens,
  int maxBytes = maxModelImageBytes,
  int quality = modelJpegQuality,
  int recodeAbove = 1500000,
}) {
  final type = sniffImageType(bytes);
  img.Decoder? decoder;
  img.DecodeInfo? info;
  try {
    decoder = img.findDecoderForData(bytes);
    info = decoder?.startDecode(bytes);
  } catch (_) {
    return null;
  }
  if (decoder == null || info == null || info.width <= 0 || info.height <= 0) return null;
  final w = info.width, h = info.height;
  var turned = false;
  if (type == 'image/jpeg') {
    try {
      final o = img.decodeJpgExif(bytes)?.imageIfd.orientation;
      turned = o != null && o > 1;
    } catch (_) {}
  }
  var animated = false;
  if (type == 'image/gif') {
    try {
      animated = decoder.numFrames() > 1;
    } catch (_) {}
  }
  final fits = math.max(w, h) <= maxEdge && visualTokens(w, h) <= maxTokens;
  if (type != null && modelImageTypes.contains(type) && fits && !turned && !animated && bytes.length <= maxBytes) {
    if (type == 'image/jpeg' || bytes.length <= recodeAbove) return ModelImage(bytes, type, w, h);
    // a large lossless picture: as a JPEG when that saves much
    final im = _decode(bytes);
    if (im == null) return ModelImage(bytes, type, w, h);
    final jpg = img.encodeJpg(_flat(im), quality: quality);
    return jpg.length < 0.6 * bytes.length ? ModelImage(jpg, 'image/jpeg', im.width, im.height, changed: true) : ModelImage(bytes, type, w, h);
  }
  var im = _decode(bytes);
  if (im == null) return null;
  im = _flat(im);
  var (tw, th) = fitModelImage(im.width, im.height, maxEdge: maxEdge, maxTokens: maxTokens);
  for (var round = 0; round < 12; round++) {
    final scaled = tw == im.width && th == im.height ? im : img.copyResize(im, width: tw, height: th, interpolation: img.Interpolation.average);
    for (final q in [quality, 75, 65, 50]) {
      if (q > quality) continue;
      final jpg = img.encodeJpg(scaled, quality: q);
      if (jpg.length <= maxBytes) return ModelImage(jpg, 'image/jpeg', scaled.width, scaled.height, changed: true);
    }
    (tw, th) = (math.max(1, (tw * 0.8).floor()), math.max(1, (th * 0.8).floor()));
  }
  return null;
}

/// The first frame of [bytes], upright (the JPEG decoder applies the EXIF
/// orientation), 8 bits a channel, without a palette; null when unreadable.
img.Image? _decode(Uint8List bytes) {
  try {
    var im = img.decodeImage(bytes, frame: 0);
    if (im == null) return null;
    if (im.hasPalette || im.format != img.Format.uint8) im = im.convert(format: img.Format.uint8, numChannels: im.hasAlpha ? 4 : 3);
    return im;
  } catch (_) {
    return null;
  }
}

/// [im] on white where it is transparent (JPEG has no transparency).
img.Image _flat(img.Image im) {
  if (!im.hasAlpha) return im;
  final white = img.Image(width: im.width, height: im.height, numChannels: 3);
  img.fill(white, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(white, im);
}

/// A JPEG of [rgba] (8-bit RGBA rows of a [width] × [height] opaque
/// picture, as `dart:ui` gives them), at [quality].
Uint8List encodeJpegRgba(Uint8List rgba, int width, int height, {int quality = modelJpegQuality}) {
  final im = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, bytesOffset: rgba.offsetInBytes, numChannels: 4, order: img.ChannelOrder.rgba);
  return img.encodeJpg(im, quality: quality);
}
