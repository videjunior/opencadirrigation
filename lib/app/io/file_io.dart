/// Browser/desktop file helpers (conditional import).
library;

import 'dart:typed_data';

import 'file_io_stub.dart' if (dart.library.js_interop) 'file_io_web.dart' as impl;

Future<void> saveTextFile(String filename, String content, {String mime = 'application/json'}) => impl.saveTextFile(filename, content, mime: mime);

/// How the save of a project file went.
enum FileSaveResult {
  /// Written: the system said so (a file chosen in its save dialog, or the
  /// same file written again).
  saved,

  /// Handed to the browser as a download, which tells nothing back (a save
  /// dialog the user cancels is not seen).
  downloaded,

  /// The user closed the save dialog.
  cancelled,

  /// The file could not be written.
  failed,
}

/// Saves the project file [content] as [filename]. Where the browser gives
/// file system access (Chromium on the computer) through its save dialog,
/// or straight into [handle] (the file this project was last saved to)
/// unless [saveAs]; [onHandle] gets the file written, for the next save.
/// Elsewhere it is a download (on the desktop build, the app's own dialog).
Future<FileSaveResult> saveProjectFile(String filename, String content, {Object? handle, bool saveAs = false, void Function(Object handle)? onHandle}) =>
    impl.saveProjectFile(filename, content, handle: handle, saveAs: saveAs, onHandle: onHandle);

/// Whether project files are saved through the system's dialog with a real
/// confirmation (file system access).
bool get confirmedFileSaves => impl.confirmedFileSaves;

/// Downloads/saves binary content (PDF, KMZ, XLSX…).
Future<void> saveBinaryFile(String filename, Uint8List bytes, {String mime = 'application/octet-stream'}) => impl.saveBinaryFile(filename, bytes, mime: mime);

/// Opens a file picker; returns (filename, content) or null.
Future<(String, String)?> openTextFile({String accept = '.json,.icad,.dxf'}) => impl.openTextFile(accept: accept);

/// Opens a file picker; returns (filename, bytes) or null.
Future<(String, Uint8List)?> openBinaryFile({String accept = '.dxf,.dwg,.kml,.kmz'}) => impl.openBinaryFile(accept: accept);
