import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The browser's JPEG encoder: the pixels into a canvas (an offscreen one
/// where the browser has it), then the canvas as a JPEG blob; null when the
/// browser cannot (the Dart encoder is used then).
Future<Uint8List?> encodeJpegByPlatform(Uint8List rgba, int width, int height, {int quality = 85}) async {
  try {
    final pixels = web.ImageData(Uint8ClampedList.view(rgba.buffer, rgba.offsetInBytes, rgba.length).toJS, width, height.toJS);
    final q = quality.clamp(1, 100) / 100;
    web.Blob? blob;
    try {
      final canvas = web.OffscreenCanvas(width, height);
      (canvas.getContext('2d') as web.OffscreenCanvasRenderingContext2D).putImageData(pixels, 0, 0);
      blob = await canvas.convertToBlob(web.ImageEncodeOptions(type: 'image/jpeg', quality: q)).toDart;
    } catch (_) {
      // no OffscreenCanvas (an older Safari): a canvas of the page
      final canvas = web.HTMLCanvasElement()
        ..width = width
        ..height = height;
      (canvas.getContext('2d') as web.CanvasRenderingContext2D).putImageData(pixels, 0, 0);
      final done = Completer<web.Blob?>();
      canvas.toBlob(((web.Blob? b) => done.complete(b)).toJS, 'image/jpeg', q.toJS);
      blob = await done.future;
    }
    if (blob == null || blob.type != 'image/jpeg') return null;
    final buf = await blob.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
