/// Browser: capture-phase listeners on `window` for drags that carry files
/// and for pastes. A file drag is default-prevented over the whole window
/// (the browser would otherwise leave the app for the dropped file): its
/// position goes to the sink while it moves over the window, its files when
/// it drops. A paste goes to the sink only when a box that takes files has
/// the cursor and the clipboard holds files or a picture ([pasteIsFiles]);
/// nothing is then typed. Text pastes are never touched, nor drags of text
/// or links.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' show Offset;

import 'package:web/web.dart' as web;

import 'file_drop.dart';

void Function() watchFileDrops(FileDropSink sink) {
  Timer? quiet;
  void gone() {
    quiet?.cancel();
    quiet = null;
    sink.dragAt(null);
  }

  void over(web.Event e) {
    final d = e as web.DragEvent;
    final dt = d.dataTransfer;
    if (!_carries(dt, 'Files')) return;
    // the file lands in the app, never in a page of its own
    e.preventDefault();
    // the copy cursor, where the source allows a copy (else the browser's choice)
    if (const {'all', 'copy', 'copyLink', 'copyMove', 'uninitialized'}.contains(dt!.effectAllowed)) dt.dropEffect = 'copy';
    sink.dragAt(_at(d));
    // dragover comes at least every 350 ms while the drag is over the page:
    // without it, the drag went away unannounced
    quiet?.cancel();
    quiet = Timer(const Duration(seconds: 1), gone);
  }

  void leave(web.Event e) {
    final d = e as web.DragEvent;
    // out of the window, or cancelled (Esc); between two elements of the
    // page, the dragenter and dragover of the next one follow at once
    if (d.relatedTarget == null && _carries(d.dataTransfer, 'Files')) gone();
  }

  void drop(web.Event e) {
    final d = e as web.DragEvent;
    final dt = d.dataTransfer;
    if (!_carries(dt, 'Files')) return;
    e.preventDefault();
    quiet?.cancel();
    quiet = null;
    final list = dt!.files;
    sink.dropped(_at(d), [
      for (var i = 0; i < list.length; i++)
        if (list.item(i) case final f?) _dropped(f),
    ]);
  }

  void paste(web.Event e) {
    if (!sink.takesPaste) return;
    final cd = (e as web.ClipboardEvent).clipboardData;
    if (cd == null) return;
    final files = _clipboardFiles(cd);
    if (!pasteIsFiles([for (final f in files) f.type], text: cd.getData('text/plain'), richText: _carries(cd, 'text/html') || _carries(cd, 'text/rtf'))) return;
    e.preventDefault();
    sink.pasted([for (final f in files) _dropped(f)]);
  }

  final listeners = <(String, JSFunction)>[('dragenter', over.toJS), ('dragover', over.toJS), ('dragleave', leave.toJS), ('drop', drop.toJS), ('paste', paste.toJS)];
  for (final (type, f) in listeners) {
    web.window.addEventListener(type, f, true.toJS);
  }
  return () {
    quiet?.cancel();
    for (final (type, f) in listeners) {
      web.window.removeEventListener(type, f, true.toJS);
    }
  };
}

/// The drag or the clipboard holds data of [type] (`Files`: files).
bool _carries(web.DataTransfer? dt, String type) {
  if (dt == null) return false;
  final types = dt.types;
  for (var i = 0; i < types.length; i++) {
    if (types[i].toDart == type) return true;
  }
  return false;
}

/// The files of a paste: its file list, or its items of kind file where a
/// browser lists them only there.
List<web.File> _clipboardFiles(web.DataTransfer cd) {
  final out = <web.File>[];
  final list = cd.files;
  for (var i = 0; i < list.length; i++) {
    if (list.item(i) case final f?) out.add(f);
  }
  if (out.isNotEmpty) return out;
  final items = cd.items;
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    if (it.kind == 'file') {
      if (it.getAsFile() case final f?) out.add(f);
    }
  }
  return out;
}

DroppedFile _dropped(web.File f) => DroppedFile(f.name, f.size, () async => (await f.arrayBuffer().toDart).toDart.asUint8List(), type: f.type);

/// Where [e] happened in the view's logical pixels, which are CSS pixels
/// from the corner of the Flutter view (the app fills the page: its corner).
Offset _at(web.MouseEvent e) {
  final p = _Pointer(e);
  final view = web.document.querySelector('flutter-view')?.getBoundingClientRect();
  return Offset(p.clientX - (view?.left ?? 0), p.clientY - (view?.top ?? 0));
}

/// A mouse event's position with its fractions (package:web reads it as an
/// integer).
extension type _Pointer(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}
