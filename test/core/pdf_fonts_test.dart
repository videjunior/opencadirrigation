import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/fonts/bidi.dart';
import 'package:opencadirrigation/core/io/fonts/shaper.dart';
import 'package:opencadirrigation/core/io/fonts/subset.dart';
import 'package:opencadirrigation/core/io/fonts/truetype.dart';
import 'package:opencadirrigation/core/io/fonts/unicode.dart';
import 'package:opencadirrigation/core/io/pdf.dart';

Uint8List fontBytes(String name) => File('assets/fonts/$name').readAsBytesSync();

PdfFonts allFonts({String? language}) {
  final f = PdfFonts(language: language);
  for (final name in BundledFonts.all) {
    expect(f.register(name, fontBytes(name)), isTrue, reason: name);
  }
  return f;
}

/// Objects of an uncompressed PDF, by number.
Map<int, String> pdfObjects(String pdf) => {for (final m in RegExp(r'(\d+) 0 obj\n(.*?)\nendobj', dotAll: true).allMatches(pdf)) int.parse(m.group(1)!): m.group(2)!};

/// Checks the cross-reference table: every entry points at its object.
void checkXref(String text) {
  expect(text, startsWith('%PDF-1.4'));
  final startxref = int.parse(RegExp(r'startxref\n(\d+)\n%%EOF').firstMatch(text)!.group(1)!);
  expect(text.substring(startxref, startxref + 4), 'xref');
  final count = int.parse(RegExp(r'xref\n0 (\d+)\n').firstMatch(text.substring(startxref))!.group(1)!);
  final entries = RegExp(r'(\d{10}) (\d{5}) ([nf])').allMatches(text.substring(startxref)).toList();
  expect(entries.length, count);
  for (var i = 1; i < count; i++) {
    final off = int.parse(entries[i].group(1)!);
    expect(text.substring(off, off + '$i 0 obj'.length), '$i 0 obj', reason: 'object $i offset');
  }
}

/// Bytes of a stream object (uncompressed document).
Uint8List streamBytes(String obj) {
  final start = obj.indexOf('stream\n') + 7;
  final end = obj.lastIndexOf('\nendstream');
  return Uint8List.fromList(latin1.encode(obj.substring(start, end)));
}

/// ToUnicode entries (CID → text) of a CMap.
Map<int, String> toUnicode(String cmap) => {
  for (final m in RegExp(r'<([0-9A-F]{4})> <([0-9A-F]*)>').allMatches(cmap))
    int.parse(m.group(1)!, radix: 16): String.fromCharCodes([for (var i = 0; i + 4 <= m.group(2)!.length; i += 4) int.parse(m.group(2)!.substring(i, i + 4), radix: 16)]),
};

void main() {
  group('TrueType reader', () {
    test('metrics, cmap and composite glyphs of the bundled fonts', () {
      final latin = TrueTypeFont.parse(fontBytes(BundledFonts.latin));
      expect(latin.unitsPerEm, 1000);
      expect(latin.numGlyphs, 2335);
      expect(latin.postScriptName, 'NotoSans-Regular');
      expect((latin.ascender, latin.descender, latin.capHeight), (1069, -293, 714));
      expect((latin.xMin, latin.yMin, latin.xMax, latin.yMax), (-602, -389, 1498, 1067));
      expect(latin.glyphId(0x41), 34);
      expect(latin.advanceWidth(34), 639);
      expect(latin.glyphId(0x416), 428); // Ж
      expect(latin.advanceWidth(428), 905);
      expect(latin.glyphId(0x01A1), 575); // ơ
      expect(latin.glyphId(0x20AC), 536); // €
      expect(latin.glyphId(0x0627), 0, reason: 'no Arabic in the Latin font');
      expect(latin.components(128), [34, 65]);
      expect(latin.components(34), isEmpty);
      final sc = TrueTypeFont.parse(fontBytes(BundledFonts.simplifiedChinese));
      expect(sc.numGlyphs, 4161);
      expect(sc.glyphId(0x6C34), 2066); // 水
      expect(sc.advanceWidth(sc.glyphId(0x4E2D)), 1000);
      final arabic = TrueTypeFont.parse(fontBytes(BundledFonts.arabic));
      expect(arabic.glyphId(0x0628), 590);
      expect(arabic.advanceWidth(590), 993);
    });

    test('rejects what is not a TrueType font', () {
      expect(() => TrueTypeFont.parse(Uint8List.fromList(utf8.encode('not a font at all'))), throwsA(isA<FontFormatException>()));
      expect(() => TrueTypeFont.parse(Uint8List.fromList([0x4F, 0x54, 0x54, 0x4F, ...List.filled(20, 0)])), throwsA(isA<FontFormatException>()));
    });
  });

  group('subsetter', () {
    test('keeps the used glyphs and their components, empties the others, appends copies', () {
      final font = TrueTypeFont.parse(fontBytes(BundledFonts.latin));
      final sub = FontSubset.build(font, [34, 128, 428], copies: [428, 34]);
      final back = TrueTypeFont.parse(sub.bytes);
      expect(back.numGlyphs, font.numGlyphs + 2);
      expect(sub.glyphs, containsAll([0, 34, 65, 128, 428]));
      int len(TrueTypeFont f, int g) => f.glyphRange(g).$2 - f.glyphRange(g).$1;
      List<int> outline(TrueTypeFont f, int g, int n) => f.bytes.sublist(f.glyphRange(g).$1, f.glyphRange(g).$1 + n);
      for (final g in [0, 34, 65, 128, 428]) {
        // same outline (the subset pads glyphs to 4 bytes)
        expect(len(back, g), inInclusiveRange(len(font, g), len(font, g) + 3), reason: 'glyph $g');
        expect(outline(back, g, len(font, g)), outline(font, g, len(font, g)), reason: 'glyph $g');
        expect(back.advanceWidth(g), font.advanceWidth(g));
      }
      expect(len(back, 35), 0, reason: 'unused glyphs are emptied');
      expect(back.components(128), [34, 65], reason: 'glyph ids are kept');
      // copies past the end of the font
      expect(outline(back, font.numGlyphs, len(font, 428)), outline(font, 428, len(font, 428)));
      expect(back.advanceWidth(font.numGlyphs + 1), font.advanceWidth(34));
      // whole-file checksum per the OpenType specification
      var sum = 0;
      for (var i = 0; i < sub.bytes.length; i += 4) {
        sum = (sum + ByteData.sublistView(sub.bytes).getUint32(i)) % 0x100000000;
      }
      expect(sum, 0xB1B0AFBA);
      // without copies the glyph count stops after the last glyph used
      expect(TrueTypeFont.parse(FontSubset.build(font, [34]).bytes).numGlyphs, 35);
    });
  });

  group('bidirectional text', () {
    List<String> visual(String s) => [for (final r in bidiVisualRuns(s)) '${r.level}:${s.substring(r.start, r.end)}'];

    test('paragraph level from the first strong character', () {
      expect(paragraphLevel('abc شبكة'), 0);
      expect(paragraphLevel('  شبكة abc'), 1);
      expect(paragraphLevel('123'), 0);
    });

    test('numbers and Latin keep their order inside right-to-left text', () {
      // Arabic, then a European number and a Latin unit: R, EN (level 2), L (level 2)
      expect(visual('أنبوب 32 mm'), ['2:mm', '1: ', '2:32', '1:أنبوب ']);
      // Arabic-Indic digits are Arabic numbers (level 2)
      expect(visual('خط ١٢٣'), ['2:١٢٣', '1:خط ']);
      // in a left-to-right paragraph the Arabic word is a level-1 run, and a
      // number after it belongs to the right-to-left part (shown on its left)
      expect(visual('Zone A: مضخة 5'), ['0:Zone A: ', '2:5', '1:مضخة ']);
      expect(visual('Zone مضخة, ok'), ['0:Zone ', '1:مضخة', '0:, ok']);
    });

    test('paired brackets take the direction of their content and context', () {
      final levels = bidiLevels('شبكة (ري) مياه');
      expect(levels.every((l) => l == 1), isTrue);
      final ltr = bidiLevels('pipe (ري) 2');
      // the brackets around an Arabic word in a left-to-right line stay left to right
      expect([ltr[5], ltr[9]], [0, 0]);
    });

    test('pure left-to-right text is one run', () {
      expect(bidiVisualRuns('Bomba centrífuga 5 cv'), hasLength(1));
      expect(bidiVisualRuns(''), isEmpty);
    });
  });

  group('unicode data', () {
    test('properties used by the shaper', () {
      expect(generalCategory(0x0915), Gc.letter);
      expect(generalCategory(0x093F), Gc.spacingMark);
      expect(generalCategory(0x064E), Gc.nonSpacingMark);
      expect(generalCategory(0x0020), Gc.space);
      expect(shapingCombiningClass(0x0651), 27, reason: 'shadda sorts before fatha (31)');
      expect(shapingCombiningClass(0x064E), 31);
      expect(decompose(0x09CB), (0x09C7, 0x09BE));
      expect(compose(0x0065, 0x0301), 0x00E9);
      expect(compose(0x0915, 0x093C), -1, reason: 'composition exclusion (U+0958)');
      expect(joiningType(0x0628), Joining.d);
      expect(joiningType(0x0627), Joining.r);
      expect(joiningType(0x064E), Joining.t);
      expect(joiningType(0x0020), Joining.u);
      expect(mirrorOf(0x28), 0x29);
      expect(scriptOf(0x0915), Script.devanagari);
      expect(scriptOf(0x30A2), Script.katakana);
      expect(scriptOf(0x0031), Script.common);
      expect(isDefaultIgnorable(0x200D), isTrue);
      // Indic categories: consonant, pre-base matra, virama, Ra
      expect(indicProperties(0x0915), (1, 4));
      expect(indicProperties(0x093F), (7, 2));
      expect(indicProperties(0x0930).$1, 15);
    });
  });

  group('font registry and layout', () {
    test('which bundled fonts a set of strings needs', () {
      final f = PdfFonts();
      expect(f.requiredFor(['Bomba centrífuga 5 cv – 18 m³/h', 'Olá']), isEmpty);
      expect(f.requiredFor(['Труба', 'हिन्दी', 'العربية']), [BundledFonts.latin, BundledFonts.arabic, BundledFonts.devanagari]);
      expect(f.requiredFor(['管道', 'ポンプ']), [BundledFonts.simplifiedChinese, BundledFonts.japanese]);
      expect(f.requiredFor(['水']), [BundledFonts.simplifiedChinese]);
      expect(PdfFonts(language: 'ja').requiredFor(['水']), [BundledFonts.japanese]);
      expect(f.requiredFor(['Zone → 2']), [BundledFonts.symbols]);
      expect(f.requiredFor(['বাংলা', 'ਪੰਜਾਬੀ', 'తెలుగు']), [BundledFonts.bengali, BundledFonts.gurmukhi, BundledFonts.telugu]);
      expect(BundledFonts.asset(BundledFonts.latin), 'assets/fonts/NotoSans-Regular.ttf');
    });

    test('missingFor drops registered fonts and adds fallbacks for characters a font lacks', () {
      final f = PdfFonts();
      expect(f.missingFor(['Труба']), [BundledFonts.latin]);
      f.register(BundledFonts.latin, fontBytes(BundledFonts.latin));
      expect(f.missingFor(['Труба']), isEmpty);
      // a CJK character outside the Chinese subset falls back to the Japanese font
      f.register(BundledFonts.simplifiedChinese, fontBytes(BundledFonts.simplifiedChinese));
      final sc = f.font(BundledFonts.simplifiedChinese)!;
      final jp = TrueTypeFont.parse(fontBytes(BundledFonts.japanese));
      final onlyJp = jp.characters.firstWhere((c) => c >= 0x4E00 && c <= 0x9FFF && !sc.hasGlyph(c));
      expect(f.missingFor([String.fromCharCode(onlyJp)]), [BundledFonts.japanese]);
      expect(f.register('broken.ttf', Uint8List(10)), isFalse);
      expect(f.isRegistered('broken.ttf'), isFalse);
      expect(f.isRegistered('assets/fonts/NotoSans-Regular.ttf'), isTrue, reason: 'asset paths are accepted');
    });

    test('WinAnsi text stays in Helvetica with the standard widths', () {
      final f = allFonts();
      final line = f.layout('Bomba – 5 cv');
      expect(line.spans, hasLength(1));
      expect(line.spans.single.isWinAnsi, isTrue);
      expect(f.textWidth('Hello', 10), closeTo((722 + 556 + 222 + 222 + 556) / 100, 1e-9));
      expect(f.textWidth('Hello', 10, bold: true), closeTo((722 + 556 + 278 + 278 + 611) / 100, 1e-9));
    });

    test('a Hindi word and "25 m" switch fonts per run', () {
      final f = allFonts(language: 'hi');
      final line = f.layout('पाइप 25 m');
      expect(line.spans.map((s) => s.fontName).toList(), [BundledFonts.devanagari, null]);
      expect(line.spans.last.text, ' 25 m');
      final deva = ShapingFont(TrueTypeFont.parse(fontBytes(BundledFonts.devanagari)));
      final shaped = deva.shape('पाइप', script: Script.devanagari, language: 'hi');
      expect(line.width(10), closeTo(shaped.advance / 1000 * 10 + f.textWidth(' 25 m', 10), 1e-9));
      // digits between Devanagari words stay in the Devanagari run (the font has them)
      expect(f.layout('पानी 25 मीटर').spans, hasLength(1));
    });

    test('Turkish, Vietnamese and Cyrillic lines use the Latin font as a whole', () {
      final f = allFonts();
      for (final s in ['Boru çapı 25 mm', 'Đường ống chính', 'Труба PVC 32 мм']) {
        final spans = f.layout(s).spans;
        expect(spans.map((x) => x.fontName).toSet(), {BundledFonts.latin}, reason: s);
      }
      // an isolated Greek letter or an arrow in a Portuguese line does not switch the line
      final spans = f.layout('Perda ΔP → 2 m').spans;
      expect(spans.where((x) => x.isWinAnsi).map((x) => x.text).join('|'), 'Perda |P | 2 m');
      expect(spans.where((x) => !x.isWinAnsi).map((x) => x.fontName).toList(), [BundledFonts.latin, BundledFonts.symbols]);
    });

    test('right-to-left lines come out in visual order', () {
      final f = allFonts(language: 'ar');
      final line = f.layout('أنبوب (PVC) 32');
      // visual: the number, the Latin run in brackets (mirrored), then the Arabic word
      final texts = [for (final s in line.spans) s.text];
      expect(texts.first, '32');
      expect(line.spans.last.fontName, BundledFonts.arabic);
      expect(line.spans.last.rtl, isTrue);
      expect(texts.join(), contains('PVC'));
    });

    test('without the fonts the text degrades to WinAnsi approximations and "?"', () {
      final f = PdfFonts();
      expect(f.layout('हिन्दी').spans.single.isWinAnsi, isTrue);
      expect(PdfDocument.winAnsi('हिन्दी → x'), '?????? > x');
      // a font registered for one script does not help another
      f.register(BundledFonts.arabic, fontBytes(BundledFonts.arabic));
      expect(f.layout('हिन्दी').spans.every((s) => s.isWinAnsi), isTrue);
      expect(f.layout('سلام').spans.single.fontName, BundledFonts.arabic);
    });

    test('fit truncates at cluster boundaries', () {
      final f = allFonts(language: 'hi');
      const s = 'क्षेत्रफल हिन्दी डिज़ाइन रिपोर्ट';
      final full = f.textWidth(s, 10);
      final cut = f.fit(s, full * 0.5, 10);
      expect(cut, endsWith('…'));
      expect(f.textWidth(cut, 10), lessThanOrEqualTo(full * 0.5));
      final prefix = cut.substring(0, cut.length - 1);
      expect(s.startsWith(prefix), isTrue);
      // the cut never separates a virama or a matra from its syllable
      expect(prefix.endsWith('्'), isFalse);
      expect(f.layout(prefix).breakPositions(), isNotEmpty);
      expect(f.fit(s, full + 1, 10), s);
      expect(f.fit(s, 1, 10), '');
    });
  });

  group('PDF with embedded fonts', () {
    test('Type0 / CIDFontType2 with Identity-H, a subset and an exact ToUnicode', () {
      final fonts = allFonts(language: 'ru');
      final doc = PdfDocument(title: 'Проект', fonts: fonts);
      final page = doc.addPage(widthPt: 300, heightPt: 200);
      page.text(10, 150, 'Труба PVC Ø 32 мм', size: 12);
      page.text(10, 120, 'Труба', size: 12, bold: true);
      page.text(10, 90, 'Olá – ³', size: 10);
      final text = latin1.decode(doc.build(compress: false));
      checkXref(text);
      final objs = pdfObjects(text);
      expect(text, contains('/Title <FEFF'), reason: 'non-Latin titles are UTF-16');
      final type0 = objs.values.firstWhere((o) => o.contains('/Subtype /Type0'));
      expect(type0, contains('/Encoding /Identity-H'));
      expect(type0, contains('NotoSans-Regular'));
      expect(RegExp(r'/BaseFont /[A-Z]{6}\+NotoSans-Regular').hasMatch(type0), isTrue, reason: 'subset tag');
      final cid = objs.values.firstWhere((o) => o.contains('/Subtype /CIDFontType2'));
      expect(cid, contains('/CIDToGIDMap /Identity'));
      expect(cid, contains('/W ['));
      expect(cid, contains('/Ordering (Identity)'));
      final descriptor = objs.values.firstWhere((o) => o.contains('/Type /FontDescriptor'));
      expect(descriptor, contains('/FontFile2'));
      final fileId = int.parse(RegExp(r'/FontFile2 (\d+) 0 R').firstMatch(descriptor)!.group(1)!);
      final fontFile = objs[fileId]!;
      final length1 = int.parse(RegExp(r'/Length1 (\d+)').firstMatch(fontFile)!.group(1)!);
      final embedded = TrueTypeFont.parse(streamBytes(fontFile));
      expect(streamBytes(fontFile).length, length1);
      final source = TrueTypeFont.parse(fontBytes(BundledFonts.latin));
      final te = source.glyphId(0x0440); // р
      final teLength = source.glyphRange(te).$2 - source.glyphRange(te).$1;
      expect(embedded.glyphRange(te).$2 - embedded.glyphRange(te).$1, inInclusiveRange(teLength, teLength + 3));
      expect(embedded.glyphRange(source.glyphId(0x0416)).$2, embedded.glyphRange(source.glyphId(0x0416)).$1, reason: 'Ж is not used');
      final tuId = int.parse(RegExp(r'/ToUnicode (\d+) 0 R').firstMatch(type0)!.group(1)!);
      final map = toUnicode(latin1.decode(streamBytes(objs[tuId]!)));
      expect(map[te], 'р');
      expect(map[source.glyphId(0x0422)], 'Т');
      // the WinAnsi line is still drawn with Helvetica, exactly as before
      expect(text, contains('(Ol\\341 \\226 \\263) Tj'));
      // embedded runs are shown with TJ; bold is simulated with fill + stroke
      expect(text, contains('] TJ'));
      expect(text, contains('2 Tr'));
    });

    test('a glyph standing for different texts gets one CID per text', () {
      final fonts = allFonts(language: 'ar');
      final doc = PdfDocument(fonts: fonts);
      final page = doc.addPage(widthPt: 300, heightPt: 100);
      // ب, ت and ن share their dotless skeleton in this font
      page.text(10, 50, 'ب ت ن', size: 12);
      final text = latin1.decode(doc.build(compress: false));
      checkXref(text);
      final objs = pdfObjects(text);
      final type0 = objs.values.firstWhere((o) => o.contains('/Subtype /Type0'));
      final tuId = int.parse(RegExp(r'/ToUnicode (\d+) 0 R').firstMatch(type0)!.group(1)!);
      final map = toUnicode(latin1.decode(streamBytes(objs[tuId]!)));
      expect(map.values.where((v) => v == 'ب' || v == 'ت' || v == 'ن').toSet(), {'ب', 'ت', 'ن'});
      final arabic = TrueTypeFont.parse(fontBytes(BundledFonts.arabic));
      expect(map.keys.any((c) => c >= arabic.numGlyphs), isTrue, reason: 'copies past the end of the font');
      final descriptor = objs.values.firstWhere((o) => o.contains('/Type /FontDescriptor'));
      final fileId = int.parse(RegExp(r'/FontFile2 (\d+) 0 R').firstMatch(descriptor)!.group(1)!);
      final embedded = TrueTypeFont.parse(streamBytes(objs[fileId]!));
      expect(embedded.numGlyphs, greaterThan(arabic.numGlyphs));
    });

    test('every script of the interface embeds and the document stays valid', () {
      final fonts = allFonts();
      final doc = PdfDocument(fonts: fonts);
      final page = doc.addPage(widthPt: 600, heightPt: 400);
      const lines = ['हिन्दी', 'मराठी', 'বাংলা', 'ਪੰਜਾਬੀ', 'తెలుగు', 'العربية', 'اردو', '中文', 'ひらがな', 'Русский', 'Tiếng Việt', 'Türkçe ğış', 'Hausa ɓɗƙƴ', '≥ ≤ ≈ →'];
      var y = 380.0;
      for (final l in lines) {
        page.text(10, y, l, size: 10);
        y -= 25;
      }
      final pdf = doc.build();
      final text = latin1.decode(pdf);
      checkXref(text);
      expect(RegExp(r'/Subtype /Type0').allMatches(text).length, BundledFonts.all.length, reason: 'one Type0 font per bundled font used');
    });
  });
}
