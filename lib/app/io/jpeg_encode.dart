/// JPEG encoding of a picture of the app (conditional import): in the
/// browser by its own image encoder (a canvas), which takes a fraction of
/// the time of an encoder written in Dart and compiled to JavaScript (a
/// 12-megapixel sheet base map held the window for seconds); elsewhere by
/// the Dart encoder of package:image.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'jpeg_encode_stub.dart' if (dart.library.js_interop) 'jpeg_encode_web.dart' as impl;

/// [rgba] (straight RGBA, [width] × [height] pixels, opaque) as a JPEG of
/// [quality] (1–100).
Future<Uint8List> encodeJpegRgba(Uint8List rgba, int width, int height, {int quality = 85}) async {
  final fast = await impl.encodeJpegByPlatform(rgba, width, height, quality: quality);
  if (fast != null) return fast;
  final image = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, bytesOffset: rgba.offsetInBytes, numChannels: 4, order: img.ChannelOrder.rgba);
  return img.encodeJpg(image, quality: quality);
}
