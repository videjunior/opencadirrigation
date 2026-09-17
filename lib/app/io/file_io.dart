/// Browser/desktop file helpers (conditional import).
library;

import 'dart:typed_data';

import 'file_io_stub.dart' if (dart.library.js_interop) 'file_io_web.dart' as impl;

Future<void> saveTextFile(String filename, String content, {String mime = 'application/json'}) => impl.saveTextFile(filename, content, mime: mime);

/// Downloads/saves binary content (PDF, KMZ, XLSX…).
Future<void> saveBinaryFile(String filename, Uint8List bytes, {String mime = 'application/octet-stream'}) => impl.saveBinaryFile(filename, bytes, mime: mime);

/// Opens a file picker; returns (filename, content) or null.
Future<(String, String)?> openTextFile({String accept = '.json,.icad,.dxf'}) => impl.openTextFile(accept: accept);

/// Opens a file picker; returns (filename, bytes) or null.
Future<(String, Uint8List)?> openBinaryFile({String accept = '.dxf,.dwg,.kml,.kmz'}) => impl.openBinaryFile(accept: accept);
