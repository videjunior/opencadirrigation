import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_io.dart' show FileSaveResult;

Future<void> saveTextFile(String filename, String content, {String mime = 'application/json'}) => _download(filename, web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: mime)));

Future<void> saveBinaryFile(String filename, Uint8List bytes, {String mime = 'application/octet-stream'}) => _download(filename, web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime)));

Future<void> _download(String filename, web.Blob blob) async {
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(a);
  a.click();
  a.remove();
  // some browsers still read the address after the click: released later
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

/// The browser's file system access (Chromium on the computer).
bool get confirmedFileSaves {
  try {
    return globalContext.has('showSaveFilePicker');
  } catch (_) {
    return false;
  }
}

Future<FileSaveResult> saveProjectFile(String filename, String content, {Object? handle, bool saveAs = false, void Function(Object handle)? onHandle}) async {
  if (confirmedFileSaves) {
    try {
      var h = !saveAs && handle != null && (handle as JSAny).isA<web.FileSystemFileHandle>() ? handle as web.FileSystemFileHandle : null;
      if (h != null && !await _mayWrite(h)) h = null;
      h ??= await _pickSaveFile(filename);
      if (h == null) return FileSaveResult.cancelled;
      final w = await h.createWritable().toDart;
      await w.write(content.toJS).toDart;
      await w.close().toDart;
      onHandle?.call(h);
      return FileSaveResult.saved;
    } catch (e) {
      if (_isAbort(e)) return FileSaveResult.cancelled;
      // file system access refused (a policy, no user gesture left): a download instead
    }
  }
  try {
    await _download(filename, web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: 'application/json')));
    return FileSaveResult.downloaded;
  } catch (_) {
    return FileSaveResult.failed;
  }
}

/// The system's save dialog; null when the user closes it.
Future<web.FileSystemFileHandle?> _pickSaveFile(String filename) async {
  final options = <String, Object>{
    'suggestedName': filename,
    'types': [
      {
        'description': 'OpenCADIrrigation',
        'accept': {
          'application/json': ['.json'],
        },
      },
    ],
  }.jsify()!;
  try {
    final r = await (globalContext.callMethod<JSPromise<JSAny?>>('showSaveFilePicker'.toJS, options)).toDart;
    return r as web.FileSystemFileHandle?;
  } catch (e) {
    if (_isAbort(e)) return null;
    rethrow;
  }
}

/// Whether file [h] may be written without the save dialog (asked again
/// when the browser forgot the permission).
Future<bool> _mayWrite(web.FileSystemFileHandle h) async {
  try {
    final opts = {'mode': 'readwrite'}.jsify()!;
    var state = ((await (h as JSObject).callMethod<JSPromise<JSAny?>>('queryPermission'.toJS, opts).toDart) as JSString?)?.toDart;
    if (state == 'prompt') state = ((await (h as JSObject).callMethod<JSPromise<JSAny?>>('requestPermission'.toJS, opts).toDart) as JSString?)?.toDart;
    return state == 'granted';
  } catch (_) {
    return false;
  }
}

/// The user closed the dialog (a DOMException named AbortError).
bool _isAbort(Object e) => '$e'.contains('AbortError');

Future<web.File?> _pick(String accept) {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  web.document.body!.append(input);
  final completer = Completer<web.File?>();
  input.onchange = ((web.Event _) {
    final files = input.files;
    completer.complete(files == null || files.length == 0 ? null : files.item(0));
    input.remove();
  }).toJS;
  input.click();
  return completer.future;
}

Future<(String, String)?> openTextFile({String accept = ''}) async {
  final file = await _pick(accept);
  if (file == null) return null;
  final reader = web.FileReader();
  final completer = Completer<(String, String)?>();
  reader.onload = ((web.Event _) => completer.complete((file.name, (reader.result as JSString?)?.toDart ?? ''))).toJS;
  reader.onerror = ((web.Event _) => completer.complete(null)).toJS;
  reader.readAsText(file);
  return completer.future;
}

Future<(String, Uint8List)?> openBinaryFile({String accept = ''}) async {
  final file = await _pick(accept);
  if (file == null) return null;
  final reader = web.FileReader();
  final completer = Completer<(String, Uint8List)?>();
  reader.onload = ((web.Event _) {
    final buf = reader.result as JSArrayBuffer?;
    completer.complete(buf == null ? null : (file.name, buf.toDart.asUint8List()));
  }).toJS;
  reader.onerror = ((web.Event _) => completer.complete(null)).toJS;
  reader.readAsArrayBuffer(file);
  return completer.future;
}
