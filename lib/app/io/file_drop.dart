/// Files dragged onto the window and dropped, or pasted into a text box
/// (conditional import). In the browser, listeners on the window keep a
/// file dropped anywhere from replacing the app (the browser's default is
/// to leave the page and show the file, and the work is lost) and hand the
/// files to a [FileDropSink]; elsewhere nothing is installed (desktop
/// builds open files through their own dialog).
library;

import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'file_drop_stub.dart' if (dart.library.js_interop) 'file_drop_web.dart' as impl;

/// A file of a drop or a paste: its name, the media type the browser gives
/// it ('' unknown) and its size, the content read on demand (a file that
/// cannot be used is never read).
class DroppedFile {
  DroppedFile(this.name, this.size, Future<Uint8List> Function() read, {this.type = ''}) : _read = read;

  /// A file already in memory (the paperclip's, tests).
  DroppedFile.bytes(this.name, Uint8List bytes, {this.type = ''}) : size = bytes.length, _read = (() async => bytes);

  final String name;
  final String type;
  final int size;
  final Future<Uint8List> Function() _read;

  /// The same file under another name.
  DroppedFile renamed(String to) => to == name ? this : DroppedFile(to, size, _read, type: type);

  /// The content; null when it cannot be read (a folder, a file moved away).
  Future<Uint8List?> read() async {
    try {
      return await _read();
    } catch (_) {
      return null;
    }
  }
}

/// Where the window's file drags, drops and pastes go.
abstract interface class FileDropSink {
  /// Files are dragged over the window at [at] (logical pixels of the
  /// view); null: the drag left the window or was cancelled.
  void dragAt(Offset? at);

  /// Files were dropped at [at] (the drag is over).
  void dropped(Offset at, List<DroppedFile> files);

  /// A text box that takes pasted files has the cursor: a paste carrying
  /// files then goes to [pasted], and nothing is typed in the box.
  bool get takesPaste;

  void pasted(List<DroppedFile> files);
}

/// Starts handing the window's file drags, drops and pastes to [sink];
/// returns the function that stops it.
void Function() watchFileDrops(FileDropSink sink) => impl.watchFileDrops(sink);

/// Whether a paste carrying files of [types] (their media types) is a paste
/// of those files, given the [text] it also carries and whether it carries
/// rich text (HTML, RTF). Office programs put a picture of the copied cells
/// or paragraph beside the text, and then the text is what was copied; a
/// file copied in the file manager comes with its name as text and a
/// picture copied from a web page with its address, and then the file is.
bool pasteIsFiles(List<String> types, {String text = '', bool richText = false}) {
  if (types.isEmpty) return false;
  final t = text.trim();
  if (t.isEmpty || !richText || !types.every((m) => m.startsWith('image/'))) return true;
  return !t.contains(RegExp(r'\s')) && RegExp(r'^(https?|file|data|blob):', caseSensitive: false).hasMatch(t);
}

/// The name a pasted file goes by. A picture on the clipboard has no name
/// of its own (or the browser's generic `image.png`): it is called
/// `pasted-<n>` ([next] gives n) with the extension of its real [type]. A
/// name without an extension gets the type's.
String pastedName(String name, String type, int Function() next) {
  final ext = _extensionOf(type);
  final base = name.trim();
  final generic = base.isEmpty || (type.startsWith('image/') && RegExp(r'^image\.\w+$', caseSensitive: false).hasMatch(base));
  if (generic) return ext == null ? 'pasted-${next()}' : 'pasted-${next()}.$ext';
  return base.contains('.') || ext == null ? base : '$base.$ext';
}

String? _extensionOf(String type) => switch (type.toLowerCase().split(';').first.trim()) {
  'image/png' => 'png',
  'image/jpeg' || 'image/jpg' || 'image/pjpeg' => 'jpg',
  'image/gif' => 'gif',
  'image/webp' => 'webp',
  'image/tiff' => 'tiff',
  'image/bmp' => 'bmp',
  'image/svg+xml' => 'svg',
  'application/pdf' => 'pdf',
  'text/plain' => 'txt',
  'text/csv' => 'csv',
  'application/json' => 'json',
  _ => null,
};
