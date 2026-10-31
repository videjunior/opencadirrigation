/// Gzip of large texts done by the platform (conditional import): in the
/// browser by its own compression streams, which run beside the app's
/// code instead of blocking it the way a deflate written in Dart does.
library;

import 'gzip_text_stub.dart' if (dart.library.js_interop) 'gzip_text_web.dart' as impl;

/// [text] encoded as UTF-8, gzipped and base64-encoded by the platform;
/// null when the platform cannot do it (the caller compresses in Dart).
Future<String?> gzipBase64(String text) => impl.gzipBase64(text);
