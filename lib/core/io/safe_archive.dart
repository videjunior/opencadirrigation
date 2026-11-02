/// Archives and compressed data from files of other people, read with a
/// ceiling on what they may expand to: a zip of a few megabytes can declare
/// gigabytes ("zip bomb") and would exhaust the memory of the browser tab.
/// An entry that declares more than its ceiling is refused before anything
/// is decompressed (the archive package stops every entry at the size it
/// declares), and a gzip stream stops at its ceiling: both as
/// `zip_too_large`.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Ceiling of one entry of an archive (bytes).
const maxArchiveEntryBytes = 128 * 1024 * 1024;

/// The entries of the zip [bytes] (only the directory is read here).
Archive openZip(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

/// The content of the zip entry [f], refused (`zip_too_large`) when it
/// declares more than [maxBytes].
Uint8List zipEntryBytes(ArchiveFile f, {int maxBytes = maxArchiveEntryBytes}) {
  if (f.size < 0 || f.size > maxBytes) throw const FormatException('zip_too_large');
  final b = f.readBytes();
  if (b == null) return Uint8List(0);
  if (b.length > maxBytes) throw const FormatException('zip_too_large');
  return b;
}

/// The gzip stream [data] decompressed, refused (`zip_too_large`) past
/// [maxBytes].
Uint8List gunzipCapped(List<int> data, {required int maxBytes}) {
  try {
    return const GZipDecoder().decodeBytes(data, maxOutputSize: maxBytes);
  } on ArchiveLimitException {
    throw const FormatException('zip_too_large');
  }
}
