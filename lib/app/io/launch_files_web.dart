import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'launch_files.dart';

/// A launch or a share as web/flutter_bootstrap.js hands it over.
extension type _Launch(JSObject _) implements JSObject {
  external String? get url;
  external String? get text;
  external JSArray<web.File>? get files;
}

bool _watching = false;

/// The page was opened with files (a file handler's `?source=file`, the share target's `?share=<id>`), as its
/// address said when [watchLaunches] first ran (the share leaves the address once taken).
bool _withFiles = false;

bool openedWithFiles() => _withFiles;

void watchLaunches(void Function(LaunchRequest r) onLaunch) {
  if (_watching) return;
  _watching = true;
  final start = Uri.base.queryParameters;
  _withFiles = start.containsKey('share') || start['source'] == 'file';
  final launches = globalContext.getProperty<JSAny?>('ociLaunches'.toJS);
  if (launches.isA<JSFunction>()) {
    (launches as JSFunction).callAsFunction(null, ((JSObject item) => _deliver(item, onLaunch)).toJS);
  }
  // the page the share target opened: ?share=<id>, the files web/sw.js keeps under that id
  final id = start['share'];
  if (id != null && id.isNotEmpty) _takeShare(id, onLaunch);
}

void _deliver(JSObject item, void Function(LaunchRequest r) onLaunch) {
  _read(_Launch(item)).then(onLaunch);
}

/// Takes `share` out of the address, so that a reload or a restored tab does not ask for the share again.
void _forgetShare() {
  final l = web.window.location;
  final rest = [
    for (final e in Uri.parse(l.href).queryParametersAll.entries)
      if (e.key != 'share')
        for (final v in e.value) '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(v)}',
  ];
  web.window.history.replaceState(null, '', '${l.pathname}${rest.isEmpty ? '' : '?${rest.join('&')}'}${l.hash}');
}

Future<void> _takeShare(String id, void Function(LaunchRequest r) onLaunch) async {
  const failed = LaunchRequest(shared: true, failed: true);
  _forgetShare();
  if (id == 'failed') {
    onLaunch(failed);
    return;
  }
  final take = globalContext.getProperty<JSAny?>('ociShared'.toJS);
  if (!take.isA<JSFunction>()) return;
  try {
    final promise = (take as JSFunction).callAsFunction(null, id.toJS);
    if (promise == null) return;
    final value = await (promise as JSPromise<JSAny?>).toDart;
    if (value == null || !value.isA<JSObject>()) {
      // read already (a reload of the page), or dropped by the worker
      onLaunch(failed);
      return;
    }
    onLaunch(await _read(_Launch(value as JSObject), shared: true));
  } catch (_) {
    onLaunch(failed);
  }
}

Future<LaunchRequest> _read(_Launch item, {bool shared = false}) async {
  final files = <LaunchFile>[];
  for (final f in item.files?.toDart ?? const <web.File>[]) {
    try {
      final buffer = await f.arrayBuffer().toDart;
      files.add(LaunchFile(f.name, buffer.toDart.asUint8List(), type: f.type));
    } catch (_) {
      // a file the browser no longer lets the page read: left out
    }
  }
  return LaunchRequest(files: files, text: item.text ?? '', url: item.url ?? '', shared: shared);
}
