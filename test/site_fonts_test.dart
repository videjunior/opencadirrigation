import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/site.dart' show contentSecurityPolicy, renderSiteScript;
import '../tool/site_fonts.dart';

/// The fallback fonts of the engine served by the site itself (tool/site_fonts.dart): the addresses read from the
/// compiled engine, each file downloaded once into the cache and copied into the build with the licence, the address
/// handed to the engine through flutter_bootstrap.js, and nothing left that asks a font service (CSP, site.js,
/// service worker). The downloads are fakes: no network.
void main() {
  Uint8List font(String name) => Uint8List.fromList([...ascii.encode('wOF2'), ...utf8.encode(name)]);

  test('the font addresses the engine compiled in, once each and in order', () {
    const js = 'x="https://fonts.gstatic.com/s/";a("roboto/v32/KFOm.woff2");b=["notosanssc/v37/k3k.0.woff2","notosanssc/v37/k3k.1.woff2","roboto/v32/KFOm.woff2"];c="notosansarabic/v28/nwp.ttf"';
    expect(engineFontPaths(js), ['roboto/v32/KFOm.woff2', 'notosanssc/v37/k3k.0.woff2', 'notosanssc/v37/k3k.1.woff2', 'notosansarabic/v28/nwp.ttf']);
    expect(engineFontPaths('"assets/fonts/MaterialIcons-Regular.otf" "main.dart.js" "fonts/../x/v1/a.woff2"'), isEmpty, reason: 'only <family>/v<version>/<file>');
  });

  test('only font files pass, not an error page', () {
    expect(isFontFile(ascii.encode('wOF2....')), isTrue);
    expect(isFontFile(ascii.encode('wOFF....')), isTrue);
    expect(isFontFile(ascii.encode('OTTO....')), isTrue);
    expect(isFontFile(const [0, 1, 0, 0, 9]), isTrue);
    expect(isFontFile(ascii.encode('<!DOCTYPE html>')), isFalse);
    expect(isFontFile(const <int>[]), isFalse);
  });

  group('installing into a build', () {
    late Directory dir, build, cache;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('oci_fonts_');
      build = Directory('${dir.path}/web')..createSync();
      cache = Directory('${dir.path}/cache');
      File('${build.path}/main.dart.js').writeAsStringSync('var base="https://fonts.gstatic.com/s/";var f=["roboto/v32/A.woff2","notosansjp/v53/B.0.woff2","notosansjp/v53/B.1.woff2"];');
      File('web/flutter_bootstrap.js').copySync('${build.path}/flutter_bootstrap.js');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('downloads each file once, copies them into fonts/ with the licence and hands the address to the engine', () async {
      final asked = <String>[];
      Future<Uint8List> download(String path) async {
        asked.add(path);
        return font(path);
      }

      final r = await installSiteFonts(build, cache: cache, download: download);
      expect(r.files, 3);
      expect(r.downloaded, 3);
      expect(asked.toSet(), {'roboto/v32/A.woff2', 'notosansjp/v53/B.0.woff2', 'notosansjp/v53/B.1.woff2'});
      expect(File('${build.path}/fonts/notosansjp/v53/B.1.woff2').readAsBytesSync(), font('notosansjp/v53/B.1.woff2'));
      expect(File('${build.path}/fonts/OFL.txt').existsSync(), isTrue, reason: 'the licence travels with the fonts');
      expect(r.bytesByFamily.keys, unorderedEquals(['roboto', 'notosansjp']));
      expect(r.bytes, r.bytesByFamily.values.reduce((a, b) => a + b));
      final boot = File('${build.path}/flutter_bootstrap.js').readAsStringSync();
      expect(boot, contains("var fonts = 'fonts/';"));
      expect(boot, isNot(contains(fontsMarker)));
      await expectLater(installSiteFonts(build, cache: cache, download: download), throwsA(isA<SiteFontsError>()), reason: 'filled in once');
      // the next build takes them from the cache
      File('web/flutter_bootstrap.js').copySync('${build.path}/flutter_bootstrap.js');
      Directory('${build.path}/fonts').deleteSync(recursive: true);
      final again = await installSiteFonts(build, cache: cache, download: download);
      expect(again.downloaded, 0);
      expect(asked, hasLength(3));
      expect(File('${build.path}/fonts/roboto/v32/A.woff2').existsSync(), isTrue);
    });

    test('offline it uses the cache alone; an answer that is no font, or an engine without the addresses, stops the build', () async {
      await expectLater(installSiteFonts(build, cache: cache), throwsA(isA<SiteFontsError>()), reason: 'nothing in the cache, no download');
      await expectLater(installSiteFonts(build, cache: cache, download: (p) async => Uint8List.fromList(ascii.encode('<html>404</html>'))), throwsA(isA<SiteFontsError>()));
      expect(File('${build.path}/flutter_bootstrap.js').readAsStringSync(), contains(fontsMarker), reason: 'a failed build hands no address to the engine');
      File('${build.path}/main.dart.js').writeAsStringSync('var nothing = 1;');
      await expectLater(installSiteFonts(build, cache: cache, download: (p) async => font(p)), throwsA(isA<SiteFontsError>()));
    });
  });

  test('the bootstrap, the pages, the worker and the build: no font service left', () {
    final boot = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(boot, contains("var fonts = '$fontsMarker';"));
    expect(boot, contains('fontFallbackBaseUrl: fonts'));
    expect(RegExp(fontsMarker).allMatches(boot).length, 1, reason: 'one placeholder to fill in');
    expect(contentSecurityPolicy, isNot(contains('fonts.gstatic.com')));
    expect(contentSecurityPolicy, contains("font-src 'self' data:;"));
    expect(renderSiteScript(), isNot(contains('gstatic')), reason: 'no preconnect to a font service');
    final sw = File('web/sw.js').readAsStringSync();
    expect(sw, contains('function hostedFont(path)'));
    expect(sw, contains('if (hostedFont(path)) {'));
    expect(sw, isNot(contains("'https://fonts.gstatic.com'")));
    final script = File('tool/build_web.sh').readAsStringSync();
    final step = script.indexOf('dart run tool/site_fonts.dart "\$OUT"');
    expect(step, greaterThan(script.indexOf('flutter build web')));
    expect(step, lessThan(script.indexOf('dart run tool/gen_sw.dart')), reason: 'before the worker hashes the bootstrap');
  });
}
