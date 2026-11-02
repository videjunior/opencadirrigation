import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release.dart' show aboutTexts, pinnedFlutter, pubspecVersion, verifyBuild;

/// tool/release.dart: the checks of a build folder that stop a bad publish,
/// and the About texts it compares with the last release.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('oci_release_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void write(String path, String text) => File('${dir.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  /// A build folder as tool/build_web.sh leaves it.
  void goodBuild() {
    final (version, build) = pubspecVersion();
    write(
      'version.json',
      '{"app_name":"opencadirrigation","version":"$version","build_number":"$build","flutter_version":"${pinnedFlutter()}","dart_version":"3.13.7","commit":"abc1234","build_date":"2026-11-02"}',
    );
    write('sw.js', "const BUILD = \"$version+$build-abc1234-2026-11-02-0123456789\";\n");
    write('offline.js', "var script = 'sw.js?b=1';\n");
    write('flutter_bootstrap.js', '_flutter.loader.load();\n');
    write('flutter.js', '// loader\n');
    write('main.dart.js', 'main();\n');
    write('index.html', '<script src="flutter_bootstrap.js" async></script>\n');
    write('canvaskit/canvaskit.wasm', '');
    File('${dir.path}/design_worker.js').writeAsBytesSync(File('web/design_worker.js').readAsBytesSync());
  }

  test('a complete build passes', () {
    goodBuild();
    expect(verifyBuild(dir.path), isEmpty);
  });

  test('the entry page may start the app through site.js (no inline script under the CSP)', () {
    goodBuild();
    write('index.html', '<script src="site.js?v=1" defer></script>\n');
    write('site.js', "boot.src = 'flutter_bootstrap.js';\n");
    expect(verifyBuild(dir.path), isEmpty);
    write('site.js', '// no app\n');
    expect(verifyBuild(dir.path).join('\n'), contains('does not load flutter_bootstrap.js'));
  });

  test('a plain flutter build web, stale parts and source maps are refused', () {
    goodBuild();
    write('sw.js', "const BUILD = '__OCI_BUILD__';\n");
    write('offline.js', "var script = '__OCI_SW_URL__';\n");
    write('main.dart.js', 'main();\n//# sourceMappingURL=main.dart.js.map\n');
    write('main.dart.js.map', '{}');
    write('design_worker.js', 'old worker');
    final problems = verifyBuild(dir.path);
    expect(
      problems.join('\n'),
      allOf(contains('sw.js is the template'), contains('offline.js'), contains('main.dart.js points at a source map'), contains('source maps in the deploy'), contains('design_worker.js is not')),
    );
  });

  test('another version, no commit or another Flutter are refused', () {
    goodBuild();
    write('version.json', '{"version":"0.0.1","build_number":"1","flutter_version":"1.0.0","commit":""}');
    final problems = verifyBuild(dir.path).join('\n');
    expect(problems, allOf(contains('version.json is 0.0.1+1'), contains('no commit'), contains('Flutter 1.0.0')));
  });

  test('the About texts of every language are read', () {
    final texts = aboutTexts();
    expect(texts.keys, contains('pt/en/es'));
    expect(texts.length, greaterThanOrEqualTo(18), reason: 'pt/en/es and the 17 packs');
    expect(texts.values.every((t) => t.length > 40), isTrue);
  });
}
