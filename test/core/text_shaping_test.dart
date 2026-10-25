import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/fonts/shaper.dart';
import 'package:opencadirrigation/core/io/fonts/truetype.dart';
import 'package:opencadirrigation/core/io/fonts/unicode.dart';

/// The fixtures in test/fixtures/shaping hold, for runs of the real
/// interface strings, the glyphs and positions of a reference OpenType
/// shaping engine (HarfBuzz through uharfbuzz, see
/// tool/fonts/make_shaping_fixtures.py) with the fonts of assets/fonts.
/// SHAPING_FIXTURES may point at another directory (e.g. a --all run).
final fixtureDir = Platform.environment['SHAPING_FIXTURES'] ?? 'test/fixtures/shaping';

const scripts = {
  'Arab': Script.arabic, 'Deva': Script.devanagari, 'Beng': Script.bengali, 'Guru': Script.gurmukhi, 'Telu': Script.telugu, 'Latn': Script.latin, 'Cyrl': Script.cyrillic,
  'Grek': Script.greek,
};

/// Required share of exact matches per language.
const minimumMatch = 0.99;

String encode(TrueTypeFont font, ShapedRun r) => [
  for (var i = 0; i < r.length; i++)
    if (r.xOffsets[i] != 0 || r.yOffsets[i] != 0)
      '${r.glyphs[i]}:${r.advances[i]}:${r.xOffsets[i]}:${r.yOffsets[i]}'
    else if (r.advances[i] != font.advanceWidth(r.glyphs[i]))
      '${r.glyphs[i]}:${r.advances[i]}'
    else
      '${r.glyphs[i]}',
].join(' ');

void main() {
  final fonts = <String, ShapingFont>{};
  final names = Platform.environment.containsKey('SHAPING_FIXTURES')
      ? [for (final f in Directory(fixtureDir).listSync()) if (f.path.endsWith('.json')) f.uri.pathSegments.last.replaceAll('.json', '')]
      : ['ar', 'ur', 'hi', 'mr', 'bn', 'pa', 'te'];
  for (final name in names) {
    test('$name runs shape like the reference engine', () {
      final fx = jsonDecode(File('$fixtureDir/$name.json').readAsStringSync()) as Map<String, dynamic>;
      final lang = fx['language'] as String;
      final font = fonts[fx['font'] as String] ??= ShapingFont(TrueTypeFont.parse(File('assets/fonts/${fx['font']}').readAsBytesSync()));
      final script = scripts[fx['script']]!;
      final rtl = fx['direction'] == 'rtl';
      final cases = (fx['cases'] as List).cast<List>();
      var ok = 0;
      final bad = <String>[];
      for (final c in cases) {
        final text = c[0] as String, want = c[1] as String;
        final got = encode(font.font, font.shape(text, script: script, language: lang, rtl: rtl));
        if (got == want) {
          ok++;
        } else if (bad.length < 12) {
          bad.add('${jsonEncode(text)} [${text.runes.map((r) => r.toRadixString(16)).join(' ')}]\n    want $want\n    got  $got');
        }
      }
      final rate = ok / cases.length;
      // ignore: avoid_print
      print('$name: ${(rate * 100).toStringAsFixed(2)} % ($ok of ${cases.length})${bad.isEmpty ? '' : '\n  ${bad.join('\n  ')}'}');
      expect(rate, greaterThanOrEqualTo(minimumMatch));
    });
  }
}
