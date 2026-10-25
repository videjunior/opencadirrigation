/// Fills in the offline service worker of a web build: `sw.js` (copied by
/// `flutter build web` from the template `web/sw.js`) gets the build name and
/// the list of files every start may need, with their SHA-256; `offline.js`
/// gets the address of the worker it registers. Used by `tool/gen_sw.dart`,
/// which `tool/build_web.sh` runs after the Flutter build.
///
/// What a start may need: the root page, the JavaScript at the top of the
/// build (bootstrap, `main.dart.js` and its deferred parts, the design
/// worker, offline.js), the manifest, the favicons and icons, every Flutter
/// asset (language packs, PDF fonts, catalogues, icon fonts, shaders…), the
/// logo of the entry page and CanvasKit, one variant per browser family.
/// The language pages, the site's text files, the screenshots and the other
/// brand images stay on the network: the worker keeps a language page once
/// it is opened and falls back to the root page offline.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A file of the build kept by the service worker.
class ShellFile {
  const ShellFile(this.path, this.sha256, this.bytes);

  /// Address relative to the site root ('./' for the root page).
  final String path;
  final String sha256;
  final int bytes;

  List<Object> toJson() => [path, sha256, bytes];
}

/// CanvasKit files of each variant the Flutter loader can pick for a
/// JavaScript build: `chromium` (browsers with V8's break iterators) and
/// `full` (the others).
const canvasKitVariants = {
  'chromium': ['canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm'],
  'full': ['canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm'],
};

/// Top-level scripts that are not part of the app: Flutter's loader (inlined
/// in flutter_bootstrap.js), its deprecated worker and ours.
const _notShellScripts = {'flutter.js', 'flutter_service_worker.js', 'sw.js'};

/// Whether the build file at [path] (relative, '/'-separated) is kept by the
/// service worker (CanvasKit apart, see [canvasKitVariants]).
bool isShellPath(String path) {
  if (path.split('/').any((s) => s.startsWith('.'))) return false;
  if (path == 'index.html' || path == 'manifest.json') return true;
  if (!path.contains('/')) {
    if (RegExp(r'\.(m?js|wasm)$').hasMatch(path)) return !_notShellScripts.contains(path);
    return RegExp(r'^favicon[^/]*\.(png|ico)$').hasMatch(path);
  }
  if (path.startsWith('assets/') || path.startsWith('icons/')) return true;
  return RegExp(r'^brand/logo-horizontal-\d+\.webp$').hasMatch(path);
}

String _relative(Directory root, File f) {
  final rel = f.path.substring(root.path.length).replaceAll(r'\', '/');
  return rel.startsWith('/') ? rel.substring(1) : rel;
}

ShellFile _shellFile(String path, File f) {
  final bytes = f.readAsBytesSync();
  return ShellFile(path == 'index.html' ? './' : path, sha256Hex(bytes), bytes.length);
}

/// The files of the build in [dir] that every start may need, by path.
List<ShellFile> shellFiles(Directory dir) {
  final out = <ShellFile>[];
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    final path = _relative(dir, f);
    if (isShellPath(path)) out.add(_shellFile(path, f));
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

/// The CanvasKit files of every variant present in the build in [dir].
Map<String, List<ShellFile>> canvasKitFiles(Directory dir) => {
  for (final v in canvasKitVariants.entries)
    if (v.value.every((p) => File('${dir.path}/$p').existsSync())) v.key: [for (final p in v.value) _shellFile(p, File('${dir.path}/$p'))],
};

/// Name of the build: the app version, the git commit and date given to the
/// build, and a hash of every kept file, so that a rebuild with changes (even
/// of an uncommitted tree on the same day) is a new build and a rebuild
/// without changes is not.
String buildName({required String version, required String commit, required String date, required List<ShellFile> files, required Map<String, List<ShellFile>> canvasKit}) {
  final listing = StringBuffer();
  for (final f in [...files, for (final v in canvasKit.values) ...v]) {
    listing.write('${f.path}\u0000${f.sha256}\n');
  }
  final hash = sha256Hex(utf8.encode(listing.toString())).substring(0, 10);
  return [version, if (commit.isNotEmpty) commit, if (date.isNotEmpty) date, hash].join('-');
}

/// Thrown when a template lacks one of the markers the generator fills in.
class TemplateMarkerMissing implements Exception {
  const TemplateMarkerMissing(this.file, this.marker);
  final String file;
  final String marker;
  @override
  String toString() => '$file has no $marker (was it already filled in?)';
}

String _replaceOnce(String text, String marker, String value, String file) {
  final i = text.indexOf(marker);
  if (i < 0) throw TemplateMarkerMissing(file, marker);
  return text.replaceRange(i, i + marker.length, value);
}

/// The service worker template [template] (web/sw.js) for [build].
String fillServiceWorker(String template, {required String build, required List<ShellFile> files, required Map<String, List<ShellFile>> canvasKit}) {
  var s = _replaceOnce(template, "'__OCI_BUILD__'", jsonEncode(build), 'sw.js');
  s = _replaceOnce(s, '[/*__OCI_FILES__*/]', _jsonLines([for (final f in files) f.toJson()]), 'sw.js');
  s = _replaceOnce(s, '{/*__OCI_CANVASKIT__*/}', jsonEncode({for (final e in canvasKit.entries) e.key: [for (final f in e.value) f.toJson()]}), 'sw.js');
  return s;
}

/// One entry per line: readable in the browser's sources panel.
String _jsonLines(List<Object> items) => items.isEmpty ? '[]' : '[\n${items.map((i) => '  ${jsonEncode(i)}').join(',\n')},\n]';

/// The registration script template [template] (web/offline.js), pointed at
/// the worker [workerUrl].
String fillOfflineScript(String template, {String workerUrl = 'sw.js'}) => _replaceOnce(template, "'__OCI_SW_URL__'", jsonEncode(workerUrl), 'offline.js');

/// What [generateServiceWorker] did.
class ServiceWorkerBuild {
  const ServiceWorkerBuild(this.build, this.files, this.canvasKit);
  final String build;
  final List<ShellFile> files;
  final Map<String, List<ShellFile>> canvasKit;

  /// Bytes a browser keeps: the files plus its CanvasKit variant ([variant]).
  int bytesFor(String variant) => files.fold(0, (s, f) => s + f.bytes) + (canvasKit[variant] ?? const []).fold(0, (s, f) => s + f.bytes);
}

/// Fills in `offline.js` and `sw.js` of the build in [dir]. offline.js goes
/// first: it is one of the kept files.
ServiceWorkerBuild generateServiceWorker(Directory dir, {required String version, String commit = '', String date = ''}) {
  final offline = File('${dir.path}/offline.js');
  final worker = File('${dir.path}/sw.js');
  if (!offline.existsSync() || !worker.existsSync()) throw FileSystemException('offline.js and sw.js must be in the build (copied from web/)', dir.path);
  offline.writeAsStringSync(fillOfflineScript(offline.readAsStringSync()));
  final files = shellFiles(dir);
  final canvasKit = canvasKitFiles(dir);
  final build = buildName(version: version, commit: commit, date: date, files: files, canvasKit: canvasKit);
  worker.writeAsStringSync(fillServiceWorker(worker.readAsStringSync(), build: build, files: files, canvasKit: canvasKit));
  return ServiceWorkerBuild(build, files, canvasKit);
}

/// `version:` of pubspec.yaml (`1.0.1+6`).
String pubspecVersion(String pubspec) => RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1) ?? '0.0.0';

// ------------------------------------------------------------------ SHA-256

const _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

/// SHA-256 of [data] in lower-case hex (FIPS 180-4), as the worker computes
/// it with `crypto.subtle` (the package has no dependency on package:crypto).
String sha256Hex(List<int> data) {
  final h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  final length = data.length;
  final padded = Uint8List(((length + 9 + 63) ~/ 64) * 64)..setRange(0, length, data);
  padded[length] = 0x80;
  final bits = length * 8;
  final view = ByteData.sublistView(padded);
  view.setUint32(padded.length - 8, (bits ~/ 0x100000000) & 0xffffffff);
  view.setUint32(padded.length - 4, bits & 0xffffffff);
  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < padded.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = view.getUint32(chunk + 4 * i);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}
