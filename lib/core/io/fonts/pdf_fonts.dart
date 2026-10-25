/// Font registry and text layout for the PDF writer: splits a line into
/// runs of one direction (simplified UAX #9), script and font, shapes the
/// runs of the embedded fonts and measures everything, so that pdf.dart can
/// draw what Helvetica (WinAnsi) cannot show and every caller measures text
/// the way it will be drawn.
///
/// Runs that WinAnsi can represent stay in Helvetica (exactly as before);
/// the others use the bundled Noto fonts of assets/fonts, which the caller
/// registers ([PdfFonts.register]) after asking which ones a set of strings
/// needs ([PdfFonts.requiredFor], [PdfFonts.missingFor]). A missing font
/// degrades to the next font of the chain, then to the WinAnsi
/// approximation of the character, finally to "?".
library;

import 'dart:typed_data';

import 'bidi.dart';
import 'shaper.dart';
import 'truetype.dart';
import 'unicode.dart';

/// File names of the fonts bundled in assets/fonts (see tool/fonts/build_fonts.py).
abstract final class BundledFonts {
  static const assetDirectory = 'assets/fonts/';
  static const latin = 'NotoSans-Regular.ttf';
  static const symbols = 'NotoSansMath-Regular.ttf';
  static const arabic = 'NotoSansArabic-Regular.ttf';
  static const devanagari = 'NotoSansDevanagari-Regular.ttf';
  static const bengali = 'NotoSansBengali-Regular.ttf';
  static const gurmukhi = 'NotoSansGurmukhi-Regular.ttf';
  static const telugu = 'NotoSansTelugu-Regular.ttf';
  static const simplifiedChinese = 'NotoSansSC-Regular.ttf';
  static const japanese = 'NotoSansJP-Regular.ttf';
  static const all = [latin, symbols, arabic, devanagari, bengali, gurmukhi, telugu, simplifiedChinese, japanese];

  /// Asset path of the bundled font [name].
  static String asset(String name) => '$assetDirectory$name';
}

/// A run of a laid-out line, in visual order.
class PdfTextSpan {
  PdfTextSpan.winAnsi(this.text, this.start, this.end, this.rtl)
      : fontName = null,
        glyphs = null,
        unitsPerEm = 1000;
  PdfTextSpan.glyphs(this.fontName, this.glyphs, this.unitsPerEm, this.text, this.start, this.end, this.rtl);

  /// Embedded font of the run, or null for Helvetica.
  final String? fontName;

  /// Helvetica runs: the characters in visual order (encode with WinAnsi);
  /// embedded runs: the logical text of the run.
  final String text;

  /// Shaped glyphs (embedded runs).
  final ShapedRun? glyphs;

  /// Units per em of the font of [glyphs].
  final int unitsPerEm;

  /// UTF-16 range of the run in the laid-out string.
  final int start, end;

  /// Whether the run is right to left (its characters or glyphs are already
  /// in visual order).
  final bool rtl;

  /// Whether the run is drawn with Helvetica.
  bool get isWinAnsi => fontName == null;

  /// Advance at size 1 (multiply by the font size for points).
  double unitWidth({bool bold = false}) => isWinAnsi ? helveticaWidth(text, bold: bold) / 1000 : glyphs!.advance / unitsPerEm;
}

/// A line laid out in spans (visual order).
class PdfTextLine {
  PdfTextLine(this.text, this.spans);
  final String text;
  final List<PdfTextSpan> spans;

  /// Width at [size] points.
  double width(double size, {bool bold = false}) {
    var w = 0.0;
    for (final s in spans) {
      w += s.unitWidth(bold: bold);
    }
    return w * size;
  }

  /// UTF-16 offsets where the line may be cut (cluster starts), ascending.
  List<int> breakPositions() {
    final out = <int>{};
    for (final s in spans) {
      if (s.isWinAnsi) {
        for (var i = s.start; i < s.end; i++) {
          final u = text.codeUnitAt(i);
          if (u < 0xDC00 || u > 0xDFFF) out.add(i);
        }
      } else {
        for (final c in s.glyphs!.clusters) {
          out.add(s.start + c);
        }
      }
    }
    return out.toList()..sort();
  }
}

/// Characters of WinAnsiEncoding (ISO 32000-1, annex D), the ones Helvetica
/// draws exactly.
bool isWinAnsi(int cp) => (cp <= 0xFF && !(cp >= 0x80 && cp <= 0x9F)) || winAnsiExtra.containsKey(cp) && winAnsiExtra[cp]! >= 0x80;

/// Characters of WinAnsiEncoding above U+00FF (codes 0x80-0x9F) and the
/// approximations used when no font has a character (codes < 0x80).
const winAnsiExtra = <int, int>{
  0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E,
  0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
  0x2212: 0x2D, 0x00A0: 0x20, 0x2192: 0x3E, 0x0394: 0x44, 0x221E: 0x38,
};

/// Maps [s] to WinAnsi codes (one code unit ≤ 0xFF per character; "?" for
/// characters without a code or an approximation).
String toWinAnsi(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r <= 0xFF && !(r >= 0x80 && r <= 0x9F)) {
      b.writeCharCode(r);
    } else {
      b.writeCharCode(winAnsiExtra[r] ?? 0x3F);
    }
  }
  return b.toString();
}

/// Advance of [s] in Helvetica (or Helvetica-Bold) in 1/1000 em, from the
/// standard AFM metrics.
double helveticaWidth(String s, {bool bold = false}) {
  var w = 0;
  for (final ch in toWinAnsi(s).codeUnits) {
    w += _helveticaCode(ch, bold);
  }
  return w.toDouble();
}

int _helveticaCode(int ch, bool bold) {
  if (ch >= 32 && ch <= 126) return (bold ? _helveticaBold : _helvetica)[ch - 32];
  if (ch >= 0xC0 && ch <= 0xFF) {
    final base = _latin1Base[ch - 0xC0];
    return (bold ? _helveticaBold : _helvetica)[base - 32];
  }
  return switch (ch) {
    0xB0 || 0xB2 || 0xB3 || 0xB9 => 333, // ° ² ³ ¹
    0x96 => 556, // en dash
    0x97 => 1000, // em dash
    0x85 => 1000, // ellipsis
    0x95 => 350, // bullet
    0xB7 => 278, // middle dot
    0xA0 => 278,
    _ => 556,
  };
}

// Base ASCII letter for Latin-1 accented characters 0xC0..0xFF.
const _latin1Base = [
  65, 65, 65, 65, 65, 65, 65, 67, 69, 69, 69, 69, 73, 73, 73, 73, // À-Ï
  68, 78, 79, 79, 79, 79, 79, 120, 79, 85, 85, 85, 85, 89, 84, 66, // Ð-ß
  97, 97, 97, 97, 97, 97, 97, 99, 101, 101, 101, 101, 105, 105, 105, 105, // à-ï
  100, 110, 111, 111, 111, 111, 111, 47, 111, 117, 117, 117, 117, 121, 116, 121, // ð-ÿ
];

// Helvetica AFM advance widths for code points 32..126.
const _helvetica = [
  278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
  1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
  333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
];
const _helveticaBold = [
  278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
  975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
  333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584,
];

// script groups of the itemiser
const _gLatin = 0, _gArabic = 1, _gDevanagari = 2, _gBengali = 3, _gGurmukhi = 4, _gTelugu = 5, _gCjk = 6, _gOther = 7;

int _groupOf(int script) => switch (script) {
  Script.arabic => _gArabic,
  Script.devanagari => _gDevanagari,
  Script.bengali => _gBengali,
  Script.gurmukhi => _gGurmukhi,
  Script.telugu => _gTelugu,
  Script.han || Script.hiragana || Script.katakana || Script.bopomofo => _gCjk,
  Script.latin || Script.greek || Script.cyrillic || Script.common || Script.inherited => _gLatin,
  _ => _gOther,
};

int _shapingScript(int group) => switch (group) {
  _gArabic => Script.arabic,
  _gDevanagari => Script.devanagari,
  _gBengali => Script.bengali,
  _gGurmukhi => Script.gurmukhi,
  _gTelugu => Script.telugu,
  _gCjk => Script.han,
  _ => Script.latin,
};

/// Static coverage of the bundled fonts (what [PdfFonts.requiredFor] can
/// tell before any font is loaded).
String? _bundledFontFor(int cp, bool japanese) {
  final s = scriptOf(cp);
  switch (s) {
    case Script.arabic:
      return BundledFonts.arabic;
    case Script.devanagari:
      return BundledFonts.devanagari;
    case Script.bengali:
      return BundledFonts.bengali;
    case Script.gurmukhi:
      return BundledFonts.gurmukhi;
    case Script.telugu:
      return BundledFonts.telugu;
    case Script.hiragana || Script.katakana:
      return BundledFonts.japanese;
    case Script.han || Script.bopomofo:
      return japanese ? BundledFonts.japanese : BundledFonts.simplifiedChinese;
    case Script.latin || Script.greek || Script.cyrillic:
      return BundledFonts.latin;
  }
  if (cp >= 0x0300 && cp <= 0x036F) return BundledFonts.latin;
  if ((cp >= 0x2190 && cp <= 0x23FF) || (cp >= 0x25A0 && cp <= 0x25FF) || cp == 0x2605 || cp == 0x2606 || cp == 0x2713) return BundledFonts.symbols;
  if ((cp >= 0x3000 && cp <= 0x303F) || (cp >= 0xFF00 && cp <= 0xFFEF)) return japanese ? BundledFonts.japanese : BundledFonts.simplifiedChinese;
  if ((cp >= 0x2000 && cp <= 0x215F) || (cp >= 0x02B0 && cp <= 0x02FF) || cp == 0x25CC || cp == 0xFFFD) return BundledFonts.latin;
  return null;
}

class _RegisteredFont {
  _RegisteredFont(this.name, this.font) : shaping = ShapingFont(font);
  final String name;
  final TrueTypeFont font;
  final ShapingFont shaping;
}

/// Registry of the fonts the PDF writer may embed, and text layout with them.
class PdfFonts {
  PdfFonts({this._language});

  /// The registry the PDF writer uses unless told otherwise.
  static final PdfFonts shared = PdfFonts();

  String? _language;

  /// BCP 47 language of the text, when known: selects OpenType language
  /// forms (Marathi, Urdu...) and the Japanese forms of Han characters.
  String? get language => _language;
  set language(String? value) {
    if (value == _language) return;
    _language = value;
    _cache.clear();
  }

  final Map<String, _RegisteredFont> _fonts = {};
  final Map<String, PdfTextLine> _cache = {};

  static String _baseName(String name) => name.split('/').last;

  /// Registers the font file [bytes] under [name] (a file name of
  /// [BundledFonts], or an asset path ending with it). Returns false (and
  /// keeps the registry unchanged) when the data is not a usable TrueType font.
  bool register(String name, Uint8List bytes) {
    try {
      final f = TrueTypeFont.parse(bytes);
      _fonts[_baseName(name)] = _RegisteredFont(_baseName(name), f);
      _cache.clear();
      return true;
    } on Object {
      return false;
    }
  }

  /// Whether a font is registered under [name] (file name or asset path).
  bool isRegistered(String name) => _fonts.containsKey(_baseName(name));

  /// Removes the font registered under [name].
  void unregister(String name) {
    if (_fonts.remove(_baseName(name)) != null) _cache.clear();
  }

  /// Names of the registered fonts.
  Iterable<String> get registered => _fonts.keys;

  /// The font registered under [name], or null.
  TrueTypeFont? font(String name) => _fonts[_baseName(name)]?.font;

  bool get _japanese => (language ?? '').toLowerCase().startsWith('ja');

  /// Bundled font files needed to draw [texts] exactly (beyond Helvetica),
  /// judged from the script of each character: asset names of
  /// [BundledFonts], in [BundledFonts.all] order.
  List<String> requiredFor(Iterable<String> texts) {
    final need = <String>{};
    for (final t in texts) {
      if (_allWinAnsi(t)) continue;
      final kana = t.runes.any((r) => r >= 0x3040 && r <= 0x30FF);
      for (final r in t.runes) {
        if (isWinAnsi(r)) continue;
        final f = _bundledFontFor(r, _japanese || kana);
        if (f != null) need.add(f);
      }
    }
    return [for (final f in BundledFonts.all) if (need.contains(f)) f];
  }

  /// Like [requiredFor] without the fonts already registered, and adding
  /// the fallback fonts for characters the registered fonts turned out to
  /// lack (call again after registering what it returned, until empty).
  List<String> missingFor(Iterable<String> texts) {
    final need = <String>{};
    for (final t in texts) {
      if (_allWinAnsi(t)) continue;
      final kana = t.runes.any((r) => r >= 0x3040 && r <= 0x30FF);
      for (final r in t.runes) {
        if (isWinAnsi(r) || isDefaultIgnorable(r)) continue;
        final first = _bundledFontFor(r, _japanese || kana);
        if (first == null) continue;
        final chain = [first, ..._fallbacks(first)];
        for (final f in chain) {
          final reg = _fonts[f];
          if (reg == null) {
            need.add(f);
            break;
          }
          if (reg.font.hasGlyph(r)) break;
        }
      }
    }
    return [for (final f in BundledFonts.all) if (need.contains(f)) f];
  }

  static List<String> _fallbacks(String first) => switch (first) {
    BundledFonts.simplifiedChinese => const [BundledFonts.japanese],
    BundledFonts.japanese => const [BundledFonts.simplifiedChinese],
    BundledFonts.latin => const [BundledFonts.symbols],
    BundledFonts.symbols => const [BundledFonts.latin, BundledFonts.simplifiedChinese],
    _ => const [BundledFonts.latin],
  };

  static bool _allWinAnsi(String s) {
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (u > 0xFF || (u >= 0x80 && u <= 0x9F)) {
        if (!isWinAnsi(u)) return false;
      }
    }
    return true;
  }

  /// Width of [s] at [size] points.
  double textWidth(String s, double size, {bool bold = false}) => _allWinAnsi(s) ? helveticaWidth(s, bold: bold) * size / 1000 : layout(s).width(size, bold: bold);

  /// [s] truncated at a cluster boundary with an ellipsis so that it fits
  /// in [maxWidth] points.
  String fit(String s, double maxWidth, double size, {bool bold = false}) {
    if (textWidth(s, size, bold: bold) <= maxWidth + 0.01) return s;
    final cuts = _allWinAnsi(s) ? [for (var i = 0; i < s.length; i++) i] : layout(s).breakPositions();
    // longest prefix (at a cut) that fits with the ellipsis
    var lo = 0, hi = cuts.length - 1, best = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cand = '${s.substring(0, cuts[mid])}…';
      if (cuts[mid] > 0 && textWidth(cand, size, bold: bold) <= maxWidth) {
        best = mid;
        lo = mid + 1;
      } else if (cuts[mid] == 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (best < 0) return '';
    return '${s.substring(0, cuts[best])}…';
  }

  /// Lays [s] out in spans (cached).
  PdfTextLine layout(String s) {
    final hit = _cache[s];
    if (hit != null) return hit;
    if (_cache.length > 4000) _cache.clear();
    return _cache[s] = _layout(s);
  }

  PdfTextLine _layout(String s) {
    if (_allWinAnsi(s)) return PdfTextLine(s, [PdfTextSpan.winAnsi(s, 0, s.length, false)]);
    final spans = <PdfTextSpan>[];
    final kana = s.runes.any((r) => r >= 0x3040 && r <= 0x30FF);
    for (final run in bidiVisualRuns(s)) {
      final sub = _itemize(s, run.start, run.end, run.rtl, _japanese || kana);
      spans.addAll(run.rtl ? sub.reversed : sub);
    }
    return PdfTextLine(s, spans);
  }

  /// Spans (logical order) of the level run [start, end) of [s].
  List<PdfTextSpan> _itemize(String s, int start, int end, bool rtl, bool japanese) {
    // code points of the run
    final cps = <int>[], at = <int>[];
    for (var i = start; i < end; i++) {
      var c = s.codeUnitAt(i);
      at.add(i);
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < end) {
        final lo = s.codeUnitAt(i + 1);
        if (lo >= 0xDC00 && lo <= 0xDFFF) {
          c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00);
          i++;
        }
      }
      cps.add(c);
    }
    at.add(end);
    final n = cps.length;
    // script of every character: marks and joiners follow their base, common
    // characters between two characters of one script take that script
    final script = [for (final c in cps) scriptOf(c)];
    for (var i = 0; i < n; i++) {
      if (script[i] == Script.inherited || ((cps[i] == 0x200C || cps[i] == 0x200D) && i > 0)) script[i] = i > 0 ? script[i - 1] : Script.common;
    }
    for (var i = 0; i < n; i++) {
      if (script[i] != Script.common) continue;
      var j = i;
      while (j < n && script[j] == Script.common) {
        j++;
      }
      if (i > 0 && j < n && _groupOf(script[i - 1]) == _groupOf(script[j]) && _groupOf(script[j]) != _gLatin) {
        for (var k = i; k < j; k++) {
          script[k] = script[j];
        }
      }
      i = j;
    }
    final group = [for (final sc in script) _groupOf(sc)];
    final out = <PdfTextSpan>[];
    var i = 0;
    while (i < n) {
      var j = i + 1;
      while (j < n && group[j] == group[i]) {
        j++;
      }
      out.addAll(_spansForGroup(s, cps, at, script, i, j, group[i], rtl, japanese));
      i = j;
    }
    return out;
  }

  /// Font chain of a script group.
  List<String> _chain(int group, bool japanese) => switch (group) {
    _gArabic => const [BundledFonts.arabic, BundledFonts.latin, BundledFonts.symbols],
    _gDevanagari => const [BundledFonts.devanagari, BundledFonts.latin, BundledFonts.symbols],
    _gBengali => const [BundledFonts.bengali, BundledFonts.latin, BundledFonts.symbols],
    _gGurmukhi => const [BundledFonts.gurmukhi, BundledFonts.latin, BundledFonts.symbols],
    _gTelugu => const [BundledFonts.telugu, BundledFonts.latin, BundledFonts.symbols],
    _gCjk => japanese ? const [BundledFonts.japanese, BundledFonts.simplifiedChinese, BundledFonts.latin] : const [BundledFonts.simplifiedChinese, BundledFonts.japanese, BundledFonts.latin],
    _gLatin => const [BundledFonts.latin, BundledFonts.symbols, BundledFonts.simplifiedChinese, BundledFonts.japanese],
    _ => [..._fonts.keys],
  };

  List<PdfTextSpan> _spansForGroup(String s, List<int> cps, List<int> at, List<int> script, int a, int b, int group, bool rtl, bool japanese) {
    // Latin, Greek and Cyrillic stay in Helvetica unless a letter needs another font
    var helvetica = false;
    if (group == _gLatin) {
      helvetica = true;
      for (var i = a; i < b; i++) {
        final c = cps[i];
        if (isWinAnsi(c)) continue;
        final sc = script[i];
        final letter = sc == Script.latin || sc == Script.cyrillic || (sc == Script.inherited) || isUnicodeMark(c);
        final greekWord = sc == Script.greek && ((i > a && script[i - 1] == Script.greek) || (i + 1 < b && script[i + 1] == Script.greek));
        if (letter || greekWord) {
          if (_fonts.containsKey(BundledFonts.latin)) helvetica = false;
          break;
        }
      }
    }
    // font of every character (null: Helvetica)
    final font = List<String?>.filled(b - a, null);
    final chain = _chain(group, japanese);
    for (var i = a; i < b; i++) {
      final c = cps[i];
      if (helvetica && isWinAnsi(c)) continue;
      String? f;
      if ((c == 0x200C || c == 0x200D || isUnicodeMark(c)) && i > a && font[i - a - 1] != null) {
        f = font[i - a - 1];
      } else {
        // first font of the chain that has the character; none: Helvetica
        // (its WinAnsi approximation, or "?")
        for (final name in chain) {
          final reg = _fonts[name];
          if (reg != null && reg.font.hasGlyph(c)) {
            f = name;
            break;
          }
        }
      }
      font[i - a] = f;
    }
    // group consecutive characters of one font
    final out = <PdfTextSpan>[];
    var i = a;
    while (i < b) {
      var j = i + 1;
      while (j < b && font[j - a] == font[i - a]) {
        j++;
      }
      final from = at[i], to = at[j];
      final text = s.substring(from, to);
      final f = font[i - a];
      if (f == null) {
        // Helvetica: characters in visual order, mirrored when right to left
        final chars = text.runes.toList();
        final vis = rtl ? [for (final r in chars.reversed) mirrorOf(r)] : chars;
        out.add(PdfTextSpan.winAnsi(String.fromCharCodes(vis), from, to, rtl));
      } else {
        final reg = _fonts[f]!;
        var sc = _shapingScript(group);
        if (group == _gLatin) {
          for (var k = i; k < j; k++) {
            if (script[k] == Script.cyrillic || script[k] == Script.greek || script[k] == Script.latin) {
              sc = script[k];
              break;
            }
          }
        }
        final shaped = reg.shaping.shape(text, script: sc, language: language, rtl: rtl);
        out.add(PdfTextSpan.glyphs(f, shaped, reg.font.unitsPerEm, text, from, to, rtl));
      }
      i = j;
    }
    return out;
  }
}
