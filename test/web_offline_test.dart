import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sw_manifest.dart';

/// The offline start of the web app: the service worker template
/// (web/sw.js), its registration (web/offline.js, loaded by
/// web/flutter_bootstrap.js after the first frame), the generator that fills
/// them in for a build (tool/gen_sw.dart) and the build script.
void main() {
  test('SHA-256 as the worker computes it with crypto.subtle', () {
    expect(sha256Hex(const []), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    // the padding boundaries: 55, 56 and 64 bytes
    expect(sha256Hex(List.filled(55, 0x61)), '9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318');
    expect(sha256Hex(List.filled(56, 0x61)), 'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a');
    expect(sha256Hex(List.filled(64, 0x61)), 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb');
  });

  test('what a start needs is kept; the site files stay on the network', () {
    for (final p in ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'main.dart.js_1.part.js', 'design_worker.js', 'offline.js', 'manifest.json', 'favicon.ico', 'favicon-32.png', 'icons/Icon-192.png', 'assets/FontManifest.json', 'assets/assets/i18n/de.json', 'assets/assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/fallback/Roboto-Regular.ttf', 'assets/catalogs/index.json', 'brand/logo-horizontal-520.webp']) {
      expect(isShellPath(p), isTrue, reason: p);
    }
    for (final p in ['pt/index.html', 'en/index.html', '404.html', 'robots.txt', 'sitemap.xml', 'llms.txt', 'flutter.js', 'flutter_service_worker.js', 'sw.js', 'version.json', 'canvaskit/canvaskit.wasm', 'canvaskit/chromium/canvaskit.js', 'screenshots/design-720.webp', 'og-image.png', 'brand/logo-square.png', '.DS_Store', 'assets/.DS_Store', 'CNAME']) {
      expect(isShellPath(p), isFalse, reason: p);
    }
  });

  group('the generator', () {
    late Directory build;
    setUp(() {
      build = Directory.systemTemp.createTempSync('oci_sw_');
      void put(String path, String text) => File('${build.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      put('index.html', '<html></html>');
      put('pt/index.html', '<html lang="pt-BR"></html>');
      put('flutter_bootstrap.js', '// bootstrap');
      put('main.dart.js', '// app');
      put('assets/assets/i18n/de.json', '{}');
      put('canvaskit/canvaskit.js', '// ck');
      put('canvaskit/canvaskit.wasm', 'wasm');
      put('canvaskit/chromium/canvaskit.js', '// ck chromium');
      put('canvaskit/chromium/canvaskit.wasm', 'wasm chromium');
      put('robots.txt', 'User-agent: *');
      File('web/sw.js').copySync('${build.path}/sw.js');
      File('web/offline.js').copySync('${build.path}/offline.js');
    });
    tearDown(() => build.deleteSync(recursive: true));

    test('fills in the worker and its registration', () {
      final r = generateServiceWorker(build, version: '1.0.1+6', commit: 'abc1234', date: '2026-10-25');
      expect(r.build, matches(RegExp(r'^1\.0\.1\+6-abc1234-2026-10-25-[0-9a-f]{10}$')));
      expect([for (final f in r.files) f.path], ['./', 'assets/assets/i18n/de.json', 'flutter_bootstrap.js', 'main.dart.js', 'offline.js']);
      expect(r.files.first.sha256, sha256Hex(utf8.encode('<html></html>')));
      expect(r.canvasKit.keys, unorderedEquals(['chromium', 'full']));
      final sw = File('${build.path}/sw.js').readAsStringSync();
      expect(sw, contains("const BUILD = \"${r.build}\";"));
      expect(sw, contains('["main.dart.js","${sha256Hex(utf8.encode('// app'))}",6]'));
      expect(sw, contains('"chromium":[["canvaskit/chromium/canvaskit.js"'));
      expect(sw, isNot(contains('__OCI_')));
      final offline = File('${build.path}/offline.js').readAsStringSync();
      expect(offline, contains('var script = "sw.js";'));
      // a second run finds no template left to fill
      expect(() => generateServiceWorker(build, version: '1.0.1+6'), throwsA(isA<TemplateMarkerMissing>()));
    });

    test('a build is named by its files: same files, same build; any change, a new one', () {
      String name() {
        File('web/sw.js').copySync('${build.path}/sw.js');
        File('web/offline.js').copySync('${build.path}/offline.js');
        return generateServiceWorker(build, version: '1.0.1+6', commit: 'abc1234', date: '2026-10-25').build;
      }

      final first = name();
      expect(name(), first, reason: 'nothing changed');
      File('${build.path}/robots.txt').writeAsStringSync('changed');
      expect(name(), first, reason: 'not a file of the app');
      File('${build.path}/main.dart.js').writeAsStringSync('// app, rebuilt');
      expect(name(), isNot(first));
    });

    test('the version comes from pubspec.yaml', () {
      expect(pubspecVersion('name: x\nversion: 1.0.1+6\n'), '1.0.1+6');
      expect(pubspecVersion(File('pubspec.yaml').readAsStringSync()), matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
    });
  });

  test('templates: a worker that removes itself until filled in, registered only after the first frame', () {
    final sw = File('web/sw.js').readAsStringSync();
    for (final marker in ["'__OCI_BUILD__'", '[/*__OCI_FILES__*/]', '{/*__OCI_CANVASKIT__*/}']) {
      expect(sw, contains(marker));
    }
    expect(sw, contains('self.registration.unregister()'), reason: 'template mode: removes itself');
    expect(sw, contains("url.origin === 'https://fonts.gstatic.com'"), reason: "the engine's fonts are kept");
    final offline = File('web/offline.js').readAsStringSync();
    expect(offline, contains("var script = '__OCI_SW_URL__';"));
    expect(offline, contains('register(script'));
    // the bootstrap: Flutter's loader, then offline.js once the first frame is on screen and the browser idle
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap.indexOf('_flutter.loader.load();'), lessThan(bootstrap.indexOf("'flutter-first-frame'")));
    expect(bootstrap, contains("s.src = 'offline.js';"));
    expect(bootstrap, contains('requestIdleCallback'));
    expect(bootstrap, isNot(contains('serviceWorker')), reason: "no service worker of Flutter's");
  });

  test('the production build serves CanvasKit itself and fills in the worker', () {
    final script = File('tool/build_web.sh').readAsStringSync();
    expect(script, contains('--no-web-resources-cdn'));
    expect(script.indexOf('flutter build web'), lessThan(script.indexOf('dart run tool/gen_sw.dart')));
    expect(script.indexOf('sourceMappingURL'), lessThan(script.indexOf('dart run tool/gen_sw.dart')), reason: 'hashes the files as served');
  });
}
