/// The translation rules of tool/i18n/glossary.json (SIT-04, SIT-05, SIT-16,
/// SIT-17): the keys that are the same in every language (names, symbols,
/// formulas) are listed, and every other key must be translated: a pack in
/// a non-Latin script never shows an English label, and the Latin-script
/// packs, where many words are the same as in English, may not leave more
/// keys in English than they do now. One name per concept and language: the
/// avoided words (the English "submain" in Portuguese and Spanish, "Emitter"
/// beside "Auslass" in German…) appear in no string of that language.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';

final _glossary = jsonDecode(File('tool/i18n/glossary.json').readAsStringSync()) as Map<String, dynamic>;

Set<String> _keys(String name) => (_glossary[name] as Map<String, dynamic>).keys.toSet();

/// The packs, by language code.
final _packs = {
  for (final f in Directory('assets/i18n').listSync().whereType<File>().where((f) => f.path.endsWith('.json')))
    f.uri.pathSegments.last.replaceAll('.json', ''): jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
};

const _nonLatin = {'ar', 'bn', 'hi', 'ja', 'mr', 'pa', 'ru', 'te', 'ur', 'zh'};

/// Portuguese (column 1) or Spanish (column 3) texts of the tutorial's
/// `t('pt', 'en', 'es')` and `_T(…)` calls.
List<String> _tutorialTexts(int column) {
  final src = File('lib/app/tutorial/tutorial.dart').readAsStringSync();
  const str = r"'((?:[^'\\]|\\.)*)'";
  final re = RegExp('(?<![\\w.])(?:t|_T)\\(\\s*$str\\s*,\\s*$str\\s*,\\s*$str\\s*,?\\s*\\)', dotAll: true);
  return [for (final m in re.allMatches(src)) m.group(column)!.replaceAll(r"\'", "'")];
}

void main() {
  final pt = I18n('pt'), en = I18n('en'), es = I18n('es');
  final untranslatable = _keys('untranslatable');
  final allowed = _keys('sameAsEnglishAllowed');
  final provisional = _keys('provisionalEnglish');
  final perLanguage = {for (final e in (_glossary['perLanguageAllowed'] as Map<String, dynamic>).entries) e.key: (e.value as List).cast<String>().toSet()};

  test('every key the glossary names exists, and no key is in two lists', () {
    for (final k in [...untranslatable, ...allowed, ...provisional, for (final s in perLanguage.values) ...s]) {
      expect(I18n.keys, contains(k), reason: k);
    }
    expect(untranslatable.intersection(allowed), isEmpty);
    expect(untranslatable.intersection(provisional), isEmpty);
    expect(allowed.intersection(provisional), isEmpty);
  });

  test('the untranslatable keys read the same in every language', () {
    for (final k in untranslatable) {
      expect(pt(k), en(k), reason: '$k in Portuguese');
      expect(es(k), en(k), reason: '$k in Spanish');
      for (final e in _packs.entries) {
        expect((e.value['strings'] as Map)[k], en(k), reason: '$k in ${e.key}');
      }
    }
  });

  test('a pack in a non-Latin script shows no English label', () {
    for (final e in _packs.entries.where((e) => _nonLatin.contains(e.key))) {
      final ok = {...untranslatable, ...allowed, ...provisional, ...?perLanguage[e.key]};
      final english = [
        for (final s in (e.value['strings'] as Map<String, dynamic>).entries)
          if (I18n('en').has(s.key) && s.value == en(s.key) && !ok.contains(s.key)) s.key,
      ];
      expect(english, isEmpty, reason: '${e.key}: keys still in English');
    }
  });

  test('the Latin-script packs leave no more keys in English than the glossary allows', () {
    final limits = (_glossary['maxSameAsEnglish'] as Map<String, dynamic>).cast<String, int>();
    for (final e in _packs.entries.where((e) => !_nonLatin.contains(e.key))) {
      final ok = {...untranslatable, ...allowed, ...provisional, ...?perLanguage[e.key]};
      final english = [
        for (final s in (e.value['strings'] as Map<String, dynamic>).entries)
          if (I18n('en').has(s.key) && s.value == en(s.key) && !ok.contains(s.key)) s.key,
      ];
      expect(limits, contains(e.key), reason: '${e.key}: no limit in the glossary');
      expect(english.length, lessThanOrEqualTo(limits[e.key]!), reason: '${e.key}: ${english.length} keys equal to English: translate the new ones');
    }
  });

  test('one name per concept: the avoided words appear in no string of that language', () {
    final terms = _glossary['terms'] as Map<String, dynamic>;
    for (final lang in terms.keys) {
      final texts = switch (lang) {
        'pt' => {for (final k in I18n.keys) k: pt(k), for (final (i, s) in _tutorialTexts(1).indexed) 'tutorial #$i': s},
        'es' => {for (final k in I18n.keys) k: es(k), for (final (i, s) in _tutorialTexts(3).indexed) 'tutorial #$i': s},
        _ => {
          ...(_packs[lang]!['strings'] as Map).cast<String, String>(),
          for (final t in (_packs[lang]!['tutorial'] as Map).entries) 'tutorial: ${t.key}': t.value as String,
        },
      };
      for (final concept in (terms[lang] as List).cast<Map<String, dynamic>>()) {
        for (final word in (concept['avoid'] as List).cast<String>()) {
          final re = RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(word)}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);
          final hits = [
            for (final t in texts.entries)
              if (re.hasMatch(t.value)) t.key,
          ];
          expect(hits, isEmpty, reason: '$lang: "$word" where the glossary says "${concept['use']}"');
        }
      }
    }
  });

  test('the report totals, the pump curve points and the submain name are translated (SIT-04)', () {
    for (final e in _packs.entries) {
      final s = e.value['strings'] as Map;
      for (final k in ['rep.totalRow', 'dlg.shutoffRunout', 'cat.qNom', 'status.entities', 'rep.ok']) {
        if (const {'fr', 'id', 'de'}.contains(e.key) && k != 'dlg.shutoffRunout' && k != 'cat.qNom') continue; // the same word there
        expect(s[k], isNot(en(k)), reason: '${e.key}: $k');
      }
    }
    expect(pt('dlg.shutoffRunout'), isNot(en('dlg.shutoffRunout')));
    expect(es('dlg.shutoffRunout'), isNot(en('dlg.shutoffRunout')));
    expect(pt('reports.mainline'), 'Linha principal / ponto de trabalho');
    expect(es('reports.mainline'), 'Línea principal / punto de trabajo');
  });
}
