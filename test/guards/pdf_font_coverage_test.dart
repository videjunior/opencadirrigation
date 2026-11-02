import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart' show I18n, baseLanguages, supportedLanguages;
import 'package:opencadirrigation/core/io/fonts/pdf_fonts.dart';
import 'package:opencadirrigation/core/io/fonts/unicode.dart' show isDefaultIgnorable;

/// The PDF writer draws what Helvetica (WinAnsi) cannot with the Noto
/// subsets of assets/fonts, which tool/fonts/build_fonts.py cuts to the
/// characters of the string tables. A translation added after the fonts
/// were built prints its new characters as "?" (in 2026-11 ten hanzi of the
/// crop names and three kanji did), and nothing else notices: here every
/// string of every language is laid out the way a PDF lays it out (the
/// fonts registered as lib/app/io/pdf_font_loader.dart registers them) and
/// any character left to Helvetica that Helvetica cannot draw fails.
void main() {
  test('every character of the string tables prints in a PDF, in every language', () {
    final fontBytes = {for (final name in BundledFonts.all) name: File('assets/fonts/$name').readAsBytesSync()};
    final problems = <String>[];
    var checked = 0;
    for (final lang in supportedLanguages) {
      final strings = stringsOf(lang);
      expect(strings, isNotEmpty, reason: lang);
      final texts = [
        for (final s in strings.values)
          if (s.runes.any((r) => !isWinAnsi(r))) s,
      ];
      // as preparePdfFonts: the fonts the texts need, then the fallbacks of
      // characters those fonts lack
      final fonts = PdfFonts(language: lang);
      for (var round = 0; round < 4; round++) {
        final missing = fonts.missingFor(texts);
        if (missing.isEmpty) break;
        for (final name in missing) {
          expect(fonts.register(name, fontBytes[name]!), isTrue, reason: name);
        }
      }
      final bad = <int, String>{};
      for (final e in strings.entries) {
        if (!e.value.runes.any((r) => !isWinAnsi(r))) continue;
        checked++;
        for (final span in fonts.layout(e.value).spans) {
          if (!span.isWinAnsi) continue;
          for (final r in span.text.runes) {
            if (isWinAnsi(r) || isDefaultIgnorable(r) || r < 0x20 || interfaceOnly.containsKey(r)) continue;
            bad.putIfAbsent(r, () => e.key);
          }
        }
      }
      for (final e in bad.entries) {
        problems.add('$lang: U+${e.key.toRadixString(16).toUpperCase().padLeft(4, '0')} ${String.fromCharCode(e.key)} (first in "${e.value}")');
      }
    }
    expect(checked, greaterThan(10000), reason: 'the string tables were not read');
    expect(
      problems,
      isEmpty,
      reason:
          'characters no bundled font draws (a PDF shows "?"): rebuild the subsets with tool/fonts/build_fonts.py, '
          'then tool/fonts/make_shaping_fixtures.py (see the docstring of build_fonts.py)\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('punctuation of a script at the edge of its run takes a font that has it', () {
    // common characters (Arabic comma, semicolon and question mark, tatweel,
    // the danda) next to Latin words or at the end of the text used to fall
    // into the Latin chain and print as "?"
    final cases = {
      'ar': ['هل تريد المتابعة؟', 'خط، PL خط متعدد', 'للإطار؛ Shift يضيف', 'الأسعار بـ {c}'],
      'hi': ['सब दिखाएँ)। Esc टाइप', 'काम करती हैं।'],
      'bn': ['মুছে দেয়। Ctrl সংমিশ্রণ', 'কাজ করে।'],
    };
    for (final e in cases.entries) {
      final fonts = PdfFonts(language: e.key);
      for (final name in BundledFonts.all) {
        fonts.register(name, File('assets/fonts/$name').readAsBytesSync());
      }
      for (final text in e.value) {
        final lost = [
          for (final span in fonts.layout(text).spans)
            if (span.isWinAnsi) ...span.text.runes.where((r) => !isWinAnsi(r)).map((r) => 'U+${r.toRadixString(16)}'),
        ];
        expect(lost, isEmpty, reason: '${e.key}: $text');
      }
    }
  });

  test('the interface-only characters are still used, and only by the interface', () {
    for (final e in interfaceOnly.entries) {
      final users = <String>{};
      for (final lang in baseLanguages) {
        for (final s in stringsOf(lang).entries) {
          if (s.value.runes.contains(e.key)) users.add(s.key);
        }
      }
      expect(users, isNotEmpty, reason: 'U+${e.key.toRadixString(16)} is no longer used: drop it from interfaceOnly');
      expect(users.difference(e.value.$2), isEmpty, reason: 'U+${e.key.toRadixString(16)} (${e.value.$1}) is now also used by ${users.difference(e.value.$2)}: a PDF may print it');
    }
  });
}

/// Characters the bundled fonts leave out on purpose: they appear only in
/// strings of the interface that no PDF prints, by key.
const interfaceOnly = <int, (String, Set<String>)>{
  0x2630: ('the ☰ menu button of the phone layout', {'sc.mobile'}),
  0x2715: ('the ✕ cancel button of the drawing hint on touch screens', {'hint.touchKeys'}),
  0x2328: ('the ⌨ command button of the drawing hint on touch screens', {'hint.touchKeys'}),
};

/// Every string of [lang], by key: the compiled table for pt, en and es, the
/// JSON pack of assets/i18n for the others (nested values joined by dots).
Map<String, String> stringsOf(String lang) {
  if (baseLanguages.contains(lang)) {
    final t = I18n(lang);
    return {for (final k in I18n.keys) k: t(k)};
  }
  final out = <String, String>{};
  void walk(Object? v, String path) {
    if (v is String) {
      out[path.startsWith('strings.') ? path.substring(8) : path] = v;
    } else if (v is Map) {
      v.forEach((k, x) => walk(x, path.isEmpty ? '$k' : '$path.$k'));
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        walk(v[i], '$path[$i]');
      }
    }
  }

  walk(jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()), '');
  return out;
}
