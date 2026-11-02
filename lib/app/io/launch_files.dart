/// What the installed web app is handed by the system (1.6.0): the files it is asked to open ("Open with" on a
/// project or a drawing: the file handlers of its manifest), the launches of its window already open (a shortcut,
/// a file: the manifest asks the browser to focus that window rather than open another) and what is shared with it
/// (the share target of the manifest: web/sw.js keeps the files until the page reads them at `?share=<id>`).
/// web/flutter_bootstrap.js queues them from the very start of the page; [watchLaunches] takes them.
library;

import 'dart:typed_data';

import 'launch_files_stub.dart' if (dart.library.js_interop) 'launch_files_web.dart' as impl;

/// One file of a launch or a share.
class LaunchFile {
  const LaunchFile(this.name, this.bytes, {this.type = ''});
  final String name;
  final Uint8List bytes;

  /// MIME type the browser gave (may be empty).
  final String type;
}

/// What a launch brings: files, a shared text or address and, for a launch into a window already open, the address
/// it was launched with (empty for the launch that opened the page: the app reads that address at start).
class LaunchRequest {
  const LaunchRequest({this.files = const [], this.text = '', this.url = '', this.shared = false, this.failed = false});
  final List<LaunchFile> files;
  final String text;
  final String url;

  /// Sent with the share target (`?share=<id>`).
  final bool shared;

  /// A share the worker could not read or keep (`?share=failed`), or one already gone (read before, or dropped).
  final bool failed;

  bool get isEmpty => files.isEmpty && text.trim().isEmpty && url.isEmpty && !failed;
}

/// Calls [onLaunch] for every launch and share, those queued before the app started first. Nothing happens on the
/// other platforms (the desktop builds open files through their menus).
void watchLaunches(void Function(LaunchRequest r) onLaunch) => impl.watchLaunches(onLaunch);

/// Whether the page was opened with files to open ("Open with", the share target), as its address said when
/// [watchLaunches] first ran: the app then asks nothing at start.
bool openedWithFiles() => impl.openedWithFiles();
