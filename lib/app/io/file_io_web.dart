import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
  web.URL.revokeObjectURL(url);
}

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
