import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs_stub.dart';

/// The key/value store of the desktop builds: one file per key in the app's
/// support folder, so preferences and autosaves survive a restart.
void main() {
  test('the support folder of each system', () {
    expect(desktopPrefsFolder({'HOME': '/Users/ana'}, os: 'macos'), '/Users/ana/Library/Application Support/OpenCADIrrigation/prefs');
    expect(desktopPrefsFolder({'APPDATA': r'C:\Users\ana\AppData\Roaming'}, os: 'windows'), r'C:\Users\ana\AppData\Roaming\OpenCADIrrigation\prefs');
    expect(desktopPrefsFolder({'HOME': '/home/ana'}, os: 'linux'), '/home/ana/.config/opencadirrigation/prefs');
    expect(desktopPrefsFolder({'HOME': '/home/ana', 'XDG_CONFIG_HOME': '/cfg'}, os: 'linux'), '/cfg/opencadirrigation/prefs');
    expect(desktopPrefsFolder({}, os: 'macos'), isNull);
    expect(desktopPrefsFolder({'HOME': ''}, os: 'linux'), isNull);
    expect(desktopPrefsFolder({'HOME': '/x'}, os: 'android'), isNull);
  });

  test('values written to files come back in a new session', () {
    final dir = Directory.systemTemp.createTempSync('oci_prefs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final folder = Directory('${dir.path}/prefs');
    final a = PrefsStore.files(folder);
    expect(a.get('lang'), isNull);
    const odd = r'store.u1/../..\:*?"<>|.v3';
    final big = 'x' * 3000000;
    a
      ..set('lang', 'pt')
      ..set(odd, 'ação ✓')
      ..set('store.big', big);
    expect(a.get('lang'), 'pt');
    // the next start of the app
    final b = PrefsStore.files(folder);
    expect(b.get('lang'), 'pt');
    expect(b.get(odd), 'ação ✓');
    expect(b.get('store.big'), big);
    expect(
      folder.listSync().whereType<File>().map((f) => f.path.split(Platform.pathSeparator).last).every((n) => RegExp(r'^[A-Za-z0-9_-]+\.txt$').hasMatch(n)),
      isTrue,
      reason: 'file names are safe on every system',
    );
    b.remove('lang');
    expect(b.get('lang'), isNull);
    expect(PrefsStore.files(folder).get('lang'), isNull);
    b.set('lang', 'es');
    expect(PrefsStore.files(folder).get('lang'), 'es');
    expect(folder.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test('a folder that cannot be written leaves the store in memory', () {
    final dir = Directory.systemTemp.createTempSync('oci_prefs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // a file where the folder should be
    final blocker = File('${dir.path}/prefs')..writeAsStringSync('');
    final s = PrefsStore.files(Directory(blocker.path));
    s.set('k', 'v');
    expect(s.get('k'), 'v');
    s.remove('k');
    expect(s.get('k'), isNull);
  });

  test('in memory (tests and plain Dart)', () {
    final s = PrefsStore.memory();
    expect(s.get('k'), isNull);
    s.set('k', 'v');
    expect(s.get('k'), 'v');
    s.remove('k');
    expect(s.get('k'), isNull);
  });
}
