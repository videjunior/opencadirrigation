import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart';

import '../tool/site.dart';

/// lib/app/version.dart is generated from pubspec.yaml by
/// tool/gen_version.dart and identifies the build everywhere the app shows
/// it (start-up log, welcome dialog, status bar, Help → About, site JSON-LD).
void main() {
  test('version.dart matches the pubspec version (run dart run tool/gen_version.dart)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml needs "version: x.y.z+n"');
    expect(appVersion, m!.group(1));
    expect(appBuild, int.parse(m.group(2)!));
    expect(appVersionFull, '${m.group(1)}+${m.group(2)}');
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(appReleaseDate), isTrue, reason: appReleaseDate);
    expect(DateTime.tryParse(appReleaseDate), isNotNull);
  });

  test('the label carries version, build number and date (and the commit when defined)', () {
    expect(appVersionLabel, startsWith('$appVersion (build $appBuild) · $appBuildDate'));
    if (appCommit.isEmpty) {
      expect(appVersionLabel, isNot(contains('git')));
    } else {
      expect(appVersionLabel, endsWith(' · git $appCommit'));
    }
    expect(appSiteUrl, 'https://opencadirrigation.com');
  });

  test('the public pages declare the same software version', () {
    for (final e in renderSite().entries) {
      if (!e.key.endsWith('.html') || e.key == '404.html') continue;
      expect(e.value, contains('"softwareVersion": "$appVersion"'), reason: e.key);
    }
  });
}
