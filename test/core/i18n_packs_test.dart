/// The language packs (assets/i18n/<code>.json) of the seventeen languages
/// that are not compiled in: one per supported language, complete against
/// the string table, the tutorial texts and the default catalogue names,
/// with the same placeholders as the English source.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/i18n/language_packs.dart';
import 'package:opencadirrigation/core/model/catalog.dart';

import '../flutter_test_config.dart' show missingKeys;
import '../support/language_packs.dart';

final _placeholder = RegExp(r'\{[^}]+\}');

/// English source texts of `fn('pt', 'en', 'es')` calls in a Dart file.
Set<String> _sourceTexts(String path, String fn) {
  final src = File(path).readAsStringSync();
  const str = r"'((?:[^'\\]|\\.)*)'";
  // A trailing comma is allowed: multi-line calls end with `'es',\n)`.
  final re = RegExp('(?<![\\w.])$fn\\(\\s*$str\\s*,\\s*$str\\s*,\\s*$str\\s*,?\\s*\\)', dotAll: true);
  String un(String s) => s.replaceAll(r"\'", "'").replaceAll(r'\n', '\n').replaceAll(r'\$', r'$').replaceAll(r'\\', r'\');
  return {for (final m in re.allMatches(src)) un(m.group(2)!)};
}

void main() {
  final extra = supportedLanguages.where((l) => !baseLanguages.contains(l)).toList();
  final en = I18n('en');

  test('the twenty languages are distinct, named and tagged', () {
    expect(supportedLanguages.length, 20);
    expect(supportedLanguages.toSet().length, 20);
    expect(baseLanguages.every(supportedLanguages.contains), isTrue);
    for (final l in supportedLanguages) {
      expect(languageNames[l], isNotNull, reason: l);
      expect(languageNames[l], isNotEmpty, reason: l);
      expect(languageTag(l), startsWith(l), reason: l);
    }
    expect(languageTag('pt'), 'pt-BR');
    expect(languageTag('zh'), 'zh-CN');
    expect(rtlLanguages, containsAll(['ar', 'ur']));
  });

  test('every extra language ships a pack file', () {
    for (final l in extra) {
      expect(File('assets/i18n/$l.json').existsSync(), isTrue, reason: 'assets/i18n/$l.json');
    }
    final onDisk = Directory('assets/i18n').listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.json')).toList();
    expect(onDisk.length, extra.length, reason: 'a pack for a language that is not in supportedLanguages: $onDisk');
  });

  final tutorialTexts = _sourceTexts('lib/app/tutorial/tutorial.dart', 't').union(_sourceTexts('lib/app/tutorial/tutorial.dart', '_T'));
  final catalogTexts = _sourceTexts('lib/core/model/catalog.dart', 'n');

  test('the source-text extraction sees the tutorial and catalogue strings', () {
    expect(tutorialTexts, contains('Start tutorial'));
    expect(tutorialTexts, contains('Navigation'));
    expect(tutorialTexts.length, greaterThan(150));
    expect(catalogTexts, contains('Coupler'));
    expect(catalogTexts.length, greaterThan(50));
  });

  for (final l in extra) {
    group('pack $l', () {
      late Map<String, dynamic> json;
      late LanguagePack pack;
      setUpAll(() {
        json = jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, dynamic>;
        pack = LanguagePack.fromJson(json);
      });

      test('names itself', () {
        expect(json['language'], l);
        expect(json['name'], languageNames[l]);
      });

      test('covers every key of the string table with the same placeholders', () {
        final missing = <String>[];
        final badPlaceholders = <String>[];
        for (final k in I18n.keys) {
          final v = pack.strings[k];
          if (v == null || v.trim().isEmpty) {
            missing.add(k);
            continue;
          }
          final want = _placeholder.allMatches(en(k)).map((m) => m.group(0)).toSet();
          final got = _placeholder.allMatches(v).map((m) => m.group(0)).toSet();
          if (want.length != got.length || !want.every(got.contains)) badPlaceholders.add(k);
        }
        expect(missing, isEmpty, reason: 'missing keys');
        expect(badPlaceholders, isEmpty, reason: 'placeholder mismatch');
        final unknown = pack.strings.keys.where((k) => !I18n('en').has(k)).toList();
        expect(unknown, isEmpty, reason: 'keys that are not in the table');
      });

      test('translates the tutorial and the default catalogue', () {
        expect(tutorialTexts.where((t) => !pack.tutorial.containsKey(t)).toList(), isEmpty, reason: 'tutorial texts without translation');
        expect(pack.tutorial.keys.where((t) => !tutorialTexts.contains(t)).toList(), isEmpty, reason: 'tutorial entries whose English source no longer exists');
        expect(catalogTexts.where((t) => !pack.catalog.containsKey(t)).toList(), isEmpty, reason: 'catalogue names without translation');
        expect(pack.catalog.keys.where((t) => !catalogTexts.contains(t)).toList(), isEmpty, reason: 'catalogue entries whose English source no longer exists');
        for (final e in pack.tutorial.entries) {
          final want = _placeholder.allMatches(e.key).map((m) => m.group(0)).toSet();
          final got = _placeholder.allMatches(e.value).map((m) => m.group(0)).toSet();
          expect(got, want, reason: 'tutorial placeholders of "${e.key}"');
        }
      });

      test('is mostly not English', () {
        var translated = 0, translatable = 0;
        for (final k in I18n.keys) {
          if (I18n('pt')(k) == en(k)) continue; // symbols, units, product names
          translatable++;
          if (pack.strings[k] != en(k)) translated++;
        }
        expect(translated / translatable, greaterThan(0.85), reason: '$translated of $translatable keys differ from English');
      });
    });
  }

  group('installed packs', () {
    setUpAll(installLanguagePacksFromDisk);
    tearDownAll(() {
      for (final l in extra) {
        uninstallLanguagePack(l);
      }
    });

    test('I18n reads the pack and falls back to English for unknown keys', () {
      for (final l in extra) {
        final t = I18n(l);
        expect(t('menu.file'), languagePack(l)!.strings['menu.file'], reason: l);
        expect(t('menu.file'), isNot('File'), reason: l);
        expect(t('no.such.key'), 'no.such.key');
        expect(missingKeys.remove('no.such.key'), isTrue, reason: 'reported as missing');
        expect(t('design.progress.zones', {'i': '2', 'n': '5'}), isNot(contains('{i}')), reason: l);
      }
    });

    test('the tutorial and the default catalogue speak the pack language', () {
      for (final l in extra) {
        expect(tutorialText('start', l), languagePack(l)!.tutorial['Start tutorial'], reason: l);
        final steps = buildTutorialSteps(l);
        final english = buildTutorialSteps('en');
        var differ = 0;
        for (var i = 0; i < steps.length; i++) {
          if (steps[i].title != english[i].title) differ++;
        }
        expect(differ, greaterThan(steps.length * 0.8), reason: '$l: $differ of ${steps.length} step titles translated');
        final cat = Catalog.defaultCatalog(lang: l);
        final coupler = cat.fittings.firstWhere((f) => f.id.startsWith('cpl'));
        expect(coupler.name, startsWith(languagePack(l)!.catalog['Coupler']!), reason: l);
      }
    });
  });

  group('on-demand loading', () {
    setUp(() {
      languageLoader = loadLanguagePackFromDisk;
      for (final l in extra) {
        uninstallLanguagePack(l);
      }
    });
    tearDown(() {
      languageLoader = null;
      for (final l in extra) {
        uninstallLanguagePack(l);
      }
    });

    test('setLanguage shows English until the pack arrives, then the language', () async {
      final c = ProjectController();
      final l = extra.first;
      expect(isLanguageLoaded(l), isFalse);
      final done = c.setLanguage(l, persist: false);
      expect(c.lang, l);
      expect(c.t('menu.file'), 'File', reason: 'English while loading');
      await done;
      expect(isLanguageLoaded(l), isTrue);
      expect(c.t('menu.file'), languagePack(l)!.strings['menu.file']);
    });

    test('base languages need no loading; unknown codes are ignored', () async {
      expect(isLanguageLoaded('pt'), isTrue);
      await ensureLanguageLoaded('pt');
      await ensureLanguageLoaded('xx');
      expect(isLanguageLoaded('xx'), isFalse);
    });

    test('a failed load is not remembered', () async {
      var calls = 0;
      languageLoader = (code) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return loadLanguagePackFromDisk(code);
      };
      final l = extra.last;
      await ensureLanguageLoaded(l);
      expect(isLanguageLoaded(l), isFalse);
      await ensureLanguageLoaded(l);
      expect(isLanguageLoaded(l), isTrue);
      expect(calls, 2);
    });
  });
}
