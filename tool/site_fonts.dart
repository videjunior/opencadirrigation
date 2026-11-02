/// The fallback fonts of the Flutter engine, served by the site itself, so that no page and no start of the app
/// asks a font service for anything (the privacy policy says so, and the Content Security Policy of the pages has no
/// font host). Flutter bundles Roboto; the glyphs of the other scripts (Chinese, Japanese, Korean, Arabic, the Indian
/// scripts…), the symbols and the emoji come from fonts the engine fetches the first time a screen needs them, at
/// `<fontFallbackBaseUrl><family>/v<version>/<file>`, by default from Google's font server ([googleFontsBase]).
///
/// After `flutter build web`, tool/build_web.sh runs this tool, which
/// - reads those addresses from the engine compiled into the build's `main.dart.js` (they change with the Flutter
///   release, so they are never written down here);
/// - downloads each file once into a cache folder (`build/web_fonts_cache`, reused by the next builds; `--offline`
///   uses the cache alone and stops when a file is missing);
/// - copies them into the build at `fonts/<family>/v<version>/<file>`, with the licence of the fonts;
/// - writes the address of that folder into the build's `flutter_bootstrap.js` (the placeholder [fontsMarker] of
///   web/flutter_bootstrap.js), which hands it to the engine as `fontFallbackBaseUrl`.
///
///   dart run tool/site_fonts.dart [build/web] [--cache <dir>] [--offline]
///
/// The service worker (web/sw.js) keeps a font once a start used it: the address carries the version, so one copy
/// serves every build. With Flutter 3.47.9 the engine knows 725 files, 21.8 MB, of which a visitor downloads only
/// the slices the text on screen needs (docs/manual/languages-and-site.md).
library;

import 'dart:io';
import 'dart:typed_data';

/// Where the engine fetches its fallback fonts unless told otherwise.
const googleFontsBase = 'https://fonts.gstatic.com/s/';

/// Where the site serves them: a folder of the build, relative to the base address of the pages (`<base href="/">`).
const siteFontsFolder = 'fonts/';

/// The placeholder of web/flutter_bootstrap.js that [fillBootstrap] fills in.
const fontsMarker = '__OCI_FONTS__';

/// The licence copied next to the fonts: the Noto fonts and Roboto are under the SIL Open Font License.
const fontsLicence = 'assets/fonts/OFL.txt';

/// A font address as the engine writes it: `"<family>/v<version>/<file>"`.
final _fontAddress = RegExp(r'"([a-z0-9]+/v\d+/[A-Za-z0-9_\-.]+\.(?:woff2|woff|ttf|otf))"');

/// The font paths (`<family>/v<version>/<file>`) the engine compiled into [mainJs] may ask for, in the order they
/// appear, each once.
List<String> engineFontPaths(String mainJs) {
  final seen = <String>{};
  return [
    for (final m in _fontAddress.allMatches(mainJs))
      if (seen.add(m.group(1)!)) m.group(1)!,
  ];
}

/// Whether [bytes] hold a font file: WOFF2, WOFF, OpenType or TrueType (not an error page).
bool isFontFile(List<int> bytes) {
  if (bytes.length < 4) return false;
  final tag = String.fromCharCodes(bytes.sublist(0, 4));
  return tag == 'wOF2' || tag == 'wOFF' || tag == 'OTTO' || tag == 'true' || (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0);
}

/// What [installSiteFonts] did.
class SiteFonts {
  const SiteFonts({required this.files, required this.bytes, required this.downloaded, required this.bytesByFamily});

  /// Font files copied into the build, and their size in bytes.
  final int files, bytes;

  /// Files that were not in the cache yet.
  final int downloaded;

  /// Bytes of each font family.
  final Map<String, int> bytesByFamily;
}

/// The build or the fonts are not what this tool expects.
class SiteFontsError implements Exception {
  const SiteFontsError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copies the fallback fonts of the engine in [build]`/main.dart.js` into [build]`/fonts/`, each from [cache] or,
/// when it is not there yet, from [download] (given the path below [googleFontsBase]; null: the cache alone), at most
/// [parallel] downloads at a time; then fills in their address in [build]`/flutter_bootstrap.js`.
Future<SiteFonts> installSiteFonts(Directory build, {required Directory cache, Future<Uint8List> Function(String path)? download, int parallel = 6}) async {
  final main = File('${build.path}/main.dart.js');
  if (!main.existsSync()) throw SiteFontsError('${main.path} not found: run flutter build web first');
  final js = main.readAsStringSync();
  if (!js.contains(googleFontsBase)) throw const SiteFontsError('main.dart.js does not name $googleFontsBase: the engine finds its fonts another way now');
  final paths = engineFontPaths(js);
  if (paths.isEmpty) throw const SiteFontsError('no font address found in main.dart.js');
  final bootstrap = File('${build.path}/flutter_bootstrap.js');
  if (!bootstrap.existsSync() || !bootstrap.readAsStringSync().contains(fontsMarker)) throw SiteFontsError('${bootstrap.path} has no $fontsMarker (filled in already?)');
  final byFamily = <String, int>{};
  var total = 0, downloaded = 0, next = 0;
  Future<void> worker() async {
    while (next < paths.length) {
      final path = paths[next++];
      final kept = File('${cache.path}/$path');
      final Uint8List bytes;
      if (kept.existsSync()) {
        bytes = kept.readAsBytesSync();
        if (!isFontFile(bytes)) throw SiteFontsError('${kept.path} is not a font file: delete it and build again');
      } else {
        if (download == null) throw SiteFontsError('$path is not in ${cache.path} (--offline)');
        bytes = await download(path);
        if (!isFontFile(bytes)) throw SiteFontsError('$googleFontsBase$path did not answer with a font file');
        kept.parent.createSync(recursive: true);
        kept.writeAsBytesSync(bytes);
        downloaded++;
      }
      final out = File('${build.path}/$siteFontsFolder$path');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes);
      total += bytes.length;
      final family = path.substring(0, path.indexOf('/'));
      byFamily[family] = (byFamily[family] ?? 0) + bytes.length;
    }
  }

  await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
  final licence = File(fontsLicence);
  if (licence.existsSync()) licence.copySync('${build.path}/${siteFontsFolder}OFL.txt');
  fillBootstrap(bootstrap);
  return SiteFonts(files: paths.length, bytes: total, downloaded: downloaded, bytesByFamily: byFamily);
}

/// Writes the address of the hosted fonts into the build's [bootstrap] in place of [fontsMarker].
void fillBootstrap(File bootstrap) {
  final text = bootstrap.readAsStringSync();
  if (!text.contains(fontsMarker)) throw SiteFontsError('${bootstrap.path} has no $fontsMarker (filled in already?)');
  bootstrap.writeAsStringSync(text.replaceAll(fontsMarker, siteFontsFolder));
}

/// One file below [googleFontsBase], tried three times.
Future<Uint8List> _download(HttpClient client, String path) async {
  final uri = Uri.parse('$googleFontsBase$path');
  Object? last;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = BytesBuilder(copy: false);
      await for (final chunk in response) {
        body.add(chunk);
      }
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: uri);
      return body.takeBytes();
    } on IOException catch (e) {
      last = e;
      await Future<void>.delayed(Duration(seconds: 1 + attempt));
    }
  }
  throw SiteFontsError('$uri: $last');
}

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--cache') {
      i++;
    } else if (!args[i].startsWith('--')) {
      positional.add(args[i]);
    }
  }
  final build = Directory(positional.isEmpty ? 'build/web' : positional.first);
  final cache = Directory(option('--cache') ?? 'build/web_fonts_cache');
  final offline = args.contains('--offline');
  final client = HttpClient()..userAgent = 'OpenCADIrrigation build (tool/site_fonts.dart)';
  try {
    final r = await installSiteFonts(build, cache: cache, download: offline ? null : (path) => _download(client, path));
    String mb(int b) => (b / 1e6).toStringAsFixed(1);
    final biggest = (r.bytesByFamily.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((e) => '${e.key} ${mb(e.value)} MB').join(', ');
    stdout.writeln('fonts: ${r.files} files, ${mb(r.bytes)} MB in ${build.path}/$siteFontsFolder (${r.downloaded} downloaded, the others from ${cache.path}); largest: $biggest');
  } on SiteFontsError catch (e) {
    stderr.writeln('site_fonts: $e');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
