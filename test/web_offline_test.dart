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
    for (final p in [
      'index.html',
      'flutter_bootstrap.js',
      'main.dart.js',
      'main.dart.js_1.part.js',
      'design_worker.js',
      'offline.js',
      'site.js',
      'manifest.json',
      'favicon.ico',
      'favicon-32.png',
      'icons/Icon-192.png',
      'assets/FontManifest.json',
      'assets/fonts/MaterialIcons-Regular.otf',
      'assets/fonts/fallback/Roboto-Regular.ttf',
      'assets/catalogs/index.json',
      'assets/catalogs/netafim.oci.cat',
      'assets/assets/brand/logo-horizontal.png',
      'brand/logo-horizontal-520.webp',
    ]) {
      expect(isShellPath(p), isTrue, reason: p);
      expect(isLazyPath(p), isFalse, reason: p);
    }
    for (final p in [
      'pt/index.html',
      'en/index.html',
      '404.html',
      'robots.txt',
      'sitemap.xml',
      'llms.txt',
      'flutter.js',
      'flutter_service_worker.js',
      'sw.js',
      'version.json',
      'canvaskit/canvaskit.wasm',
      'canvaskit/chromium/canvaskit.js',
      'screenshots/design-720.webp',
      'og-image.png',
      'brand/logo-square.png',
      '.DS_Store',
      'assets/.DS_Store',
      'CNAME',
      'pt/manifest.json',
      'privacy/index.html',
      // documentation a folder of assets brings along: never read by the app
      'assets/catalogs/README.md',
      'assets/assets/fonts/OFL.txt',
    ]) {
      expect(isShellPath(p), isFalse, reason: p);
      expect(isLazyPath(p), isFalse, reason: p);
    }
  });

  test('the language packs, the PDF fonts and the licence list are kept only once used (ENG-13)', () {
    for (final p in ['assets/assets/i18n/de.json', 'assets/assets/i18n/zh.json', 'assets/assets/fonts/NotoSansJP-Regular.ttf', 'assets/assets/fonts/NotoSans-Regular.ttf', 'assets/NOTICES']) {
      expect(isLazyPath(p), isTrue, reason: p);
      expect(isShellPath(p), isFalse, reason: '$p is not downloaded at install');
    }
    // the worker carries forward the ones a browser kept, fetching a new version when they changed
    final sw = File('web/sw.js').readAsStringSync();
    expect(sw, contains('await carryLazy(cache, previous);'));
    expect(sw.indexOf('await carryLazy(cache, previous);'), lessThan(sw.indexOf('await cache.put(MANIFEST_URL')), reason: 'before the build counts as complete');
    expect(sw, contains("(await sha256(kept.clone())) === hash ? kept : await fetchChecked(url, hash)"));
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
      expect([for (final f in r.files) f.path], ['./', 'flutter_bootstrap.js', 'main.dart.js', 'offline.js']);
      expect([for (final f in r.lazy) f.path], ['assets/assets/i18n/de.json']);
      expect(r.files.first.sha256, sha256Hex(utf8.encode('<html></html>')));
      expect(r.canvasKit.keys, unorderedEquals(['chromium', 'full']));
      final sw = File('${build.path}/sw.js').readAsStringSync();
      expect(sw, contains("const BUILD = \"${r.build}\";"));
      expect(sw, contains('["main.dart.js","${sha256Hex(utf8.encode('// app'))}",6]'));
      expect(sw, contains('"chromium":[["canvaskit/chromium/canvaskit.js"'));
      expect(sw, contains('["assets/assets/i18n/de.json","${sha256Hex(utf8.encode('{}'))}",2]'));
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
      final second = name();
      expect(second, isNot(first));
      File('${build.path}/assets/assets/i18n/de.json').writeAsStringSync('{"strings": {}}');
      expect(name(), isNot(second), reason: 'a changed language pack is a new build too (its new version is fetched)');
    });

    test('the version comes from pubspec.yaml', () {
      expect(pubspecVersion('name: x\nversion: 1.0.1+6\n'), '1.0.1+6');
      expect(pubspecVersion(File('pubspec.yaml').readAsStringSync()), matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
    });
  });

  test('templates: a worker that removes itself until filled in, registered only after the first frame', () {
    final sw = File('web/sw.js').readAsStringSync();
    for (final marker in ["'__OCI_BUILD__'", '[/*__OCI_FILES__*/]', '{/*__OCI_CANVASKIT__*/}', '[/*__OCI_LAZY__*/]']) {
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

  test('a newer build is announced to the app, which reloads into it on request (SIT-07)', () {
    final offline = File('web/offline.js').readAsStringSync();
    // the window learns of it: a flag for an app that starts listening late, and an event
    expect(offline, contains('window.ociUpdateReady = true;'));
    expect(offline, contains("new Event('oci-update-ready')"));
    // a waiting build (browsers that cannot tell pages apart), one that took over, or a page older than the worker
    expect(offline, contains('if (reg.waiting && controlled) announce();'));
    expect(offline, contains("reg.addEventListener('updatefound'"));
    expect(offline, contains("worker.postMessage({ type: 'oci-build' }, [channel.port2]);"));
    expect(offline, contains('d.page !== d.build'));
    // only for a page the worker served: the first visit already runs the newest build
    expect(offline, contains('var controlled = !!sw.controller;'));
    // a page open for days looks again
    expect(offline, contains('setInterval(check, 3600 * 1000);'));
    expect(offline, contains("'visibilitychange'"));
    // the reload: the open pages keep their build, the waiting one takes over, then the page reloads
    expect(offline, contains("reg.active.postMessage({ type: 'oci-pin-open' }, [channel.port2]);"));
    expect(offline, contains("waiting.postMessage({ type: 'oci-skip-waiting' });"));
    expect(offline, contains("sw.addEventListener('controllerchange', reload);"));
    final sw = File('web/sw.js').readAsStringSync();
    expect(sw, contains("data.type === 'oci-pin-open'"));
    expect(sw, contains('page: (event.source && pins.get(event.source.id)) || null'));
    // the app listens (lib/app/io/app_update_web.dart) and offers the reload (lib/app/widgets/update_notice.dart)
    final web = File('lib/app/io/app_update_web.dart').readAsStringSync();
    expect(web, contains("'oci-update-ready'"));
    expect(web, contains("'ociUpdateReady'"));
    expect(web, contains("'ociApplyUpdate'"));
    expect(File('lib/main.dart').readAsStringSync(), contains('watchForAppUpdate('));
  });

  test('the production build serves CanvasKit itself and fills in the worker', () {
    final script = File('tool/build_web.sh').readAsStringSync();
    expect(script, contains('--no-web-resources-cdn'));
    expect(script.indexOf('flutter build web'), lessThan(script.indexOf('dart run tool/gen_sw.dart')));
    expect(script.indexOf('sourceMappingURL'), lessThan(script.indexOf('dart run tool/gen_sw.dart')), reason: 'hashes the files as served');
  });
}
