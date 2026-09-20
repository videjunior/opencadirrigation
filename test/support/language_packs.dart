/// Installs every `assets/i18n/<code>.json` pack from the repository, so
/// core tests (which run without the asset bundle) see the twenty languages
/// exactly as the app does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:opencadirrigation/app/i18n.dart';

/// The pack codes found on disk (the languages beyond pt/en/es).
List<String> installLanguagePacksFromDisk() {
  final dir = Directory('assets/i18n');
  if (!dir.existsSync()) return const [];
  final codes = <String>[];
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final code = f.uri.pathSegments.last.replaceAll('.json', '');
    installLanguagePack(code, LanguagePack.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>));
    codes.add(code);
  }
  return codes..sort();
}

/// A [languageLoader] that reads the packs from disk, for tests of the
/// on-demand loading path.
Future<Map<String, dynamic>> loadLanguagePackFromDisk(String code) async =>
    jsonDecode(await File('assets/i18n/$code.json').readAsString()) as Map<String, dynamic>;
