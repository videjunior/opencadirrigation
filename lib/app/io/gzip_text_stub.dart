import 'dart:convert';
import 'dart:io';

/// Desktop and tests: the zlib of the Dart VM.
Future<String?> gzipBase64(String text) async => base64Encode(gzip.encode(utf8.encode(text)));
