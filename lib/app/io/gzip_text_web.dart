import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's gzip (CompressionStream) and base64 (FileReader): the
/// text goes into a Blob as UTF-8 and comes back as a data URL.
Future<String?> gzipBase64(String text) async {
  try {
    final gz = web.CompressionStream('gzip');
    final packed = web.Blob([text.toJS].toJS).stream().pipeThrough(web.ReadableWritablePair(readable: gz.readable, writable: gz.writable));
    final blob = await web.Response(packed).blob().toDart;
    final reader = web.FileReader();
    final done = Completer<String?>();
    reader.onload = ((web.Event _) => done.complete((reader.result as JSString?)?.toDart)).toJS;
    reader.onerror = ((web.Event _) => done.complete(null)).toJS;
    reader.readAsDataURL(blob);
    final url = await done.future;
    if (url == null) return null;
    return url.substring(url.indexOf(',') + 1);
  } catch (_) {
    // no compression streams (an old browser)
    return null;
  }
}
