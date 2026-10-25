/// Unicode character properties for text shaping and the bidirectional
/// algorithm, read from the generated tables of unicode_data.dart (Basic
/// Multilingual Plane) with coarse rules for the supplementary planes.
library;

import 'unicode_data.dart';

export 'unicode_data.dart' show Gc;

/// Script ids of [scriptOf] (indexes into the generated `scriptNames`).
abstract final class Script {
  static const common = 0, inherited = 1, latin = 2, greek = 3, cyrillic = 4, arabic = 5, devanagari = 6, bengali = 7, gurmukhi = 8, telugu = 9, han = 10, hiragana = 11, katakana = 12;
  static const bopomofo = 13, hangul = 14, hebrew = 15, thai = 16, other = 17;
}

/// Bidi class ids of [bidiClass] (UAX #9 table 4; indexes into the generated `bidiClassNames`).
abstract final class Bidi {
  static const l = 0, r = 1, al = 2, en = 3, es = 4, et = 5, an = 6, cs = 7, nsm = 8, bn = 9, b = 10, s = 11, ws = 12, on = 13;
  static const lre = 14, lro = 15, rle = 16, rlo = 17, pdf = 18, lri = 19, rli = 20, fsi = 21, pdi = 22;
}

/// Simplified general category ([Gc]) of [cp].
int generalCategory(int cp) {
  if (cp <= 0xFFFF) return rangeValue(generalCategoryRanges, cp);
  if (cp >= 0x20000 && cp <= 0x3FFFF) return Gc.letter; // CJK extensions
  if (cp >= 0xE0000 && cp <= 0xE0FFF) return cp >= 0xE0100 ? Gc.nonSpacingMark : Gc.format; // tags, variation selectors
  if (cp >= 0x1F000 && cp <= 0x1FBFF) return Gc.other; // symbols and emoji
  if (cp >= 0xF0000) return Gc.unassigned; // private use
  return Gc.letter;
}

/// Whether [cp] is a combining mark (Mn, Mc or Me).
bool isUnicodeMark(int cp) {
  final g = generalCategory(cp);
  return g == Gc.nonSpacingMark || g == Gc.spacingMark || g == Gc.enclosingMark;
}

/// Canonical combining class of [cp] (0 for non-marks).
int combiningClass(int cp) => cp <= 0xFFFF ? rangeValue(combiningClassRanges, cp, 256) : 0;

/// Combining class used to reorder marks before shaping: the canonical class
/// with the Arabic shadda sorted before the other harakat and the Telugu
/// length marks before the other vowel signs, as fonts expect.
int shapingCombiningClass(int cp) {
  final c = combiningClass(cp);
  return switch (c) {
    27 => 28, 28 => 29, 29 => 30, 30 => 31, 31 => 32, 32 => 33, 33 => 27, // fathatan..sukun: shadda first
    84 => 4, 91 => 5, // Telugu length marks
    _ => c,
  };
}

/// Bidi class ([Bidi]) of [cp].
int bidiClass(int cp) {
  if (cp <= 0xFFFF) return rangeValue(bidiClassRanges, cp);
  if ((cp >= 0x10800 && cp <= 0x10FFF) || (cp >= 0x1E800 && cp <= 0x1EDFF)) return Bidi.r;
  if (cp >= 0x1EE00 && cp <= 0x1EEFF) return Bidi.al;
  if (cp >= 0xE0000 && cp <= 0xE0FFF) return cp >= 0xE0100 ? Bidi.nsm : Bidi.bn;
  if (cp >= 0x1F000 && cp <= 0x1FBFF) return Bidi.on;
  return Bidi.l;
}

int _pairLookup(List<int> pairs, int key) {
  var lo = 0, hi = pairs.length ~/ 2 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final k = pairs[2 * mid];
    if (k == key) return pairs[2 * mid + 1];
    if (k < key) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}

/// Bidi_Mirroring_Glyph of [cp], or [cp] itself.
int mirrorOf(int cp) {
  final m = _pairLookup(bidiMirrorPairs, cp);
  return m < 0 ? cp : m;
}

Map<int, int>? _bracketOpenToClose;
Map<int, int>? _bracketCloseToOpen;

/// Closing bracket paired with the opening bracket [cp] (UAX #9 Bidi_Paired_Bracket), or -1.
int closingBracketOf(int cp) {
  _initBrackets();
  return _bracketOpenToClose![cp] ?? -1;
}

/// Opening bracket paired with the closing bracket [cp], or -1.
int openingBracketOf(int cp) {
  _initBrackets();
  return _bracketCloseToOpen![cp] ?? -1;
}

void _initBrackets() {
  if (_bracketOpenToClose != null) return;
  final o = <int, int>{}, c = <int, int>{};
  for (var i = 0; i + 1 < bidiBracketPairs.length; i += 2) {
    o[bidiBracketPairs[i]] = bidiBracketPairs[i + 1];
    c[bidiBracketPairs[i + 1]] = bidiBracketPairs[i];
  }
  // canonical equivalents of the angle brackets
  o[0x2329] = 0x232A;
  c[0x232A] = 0x2329;
  _bracketOpenToClose = o;
  _bracketCloseToOpen = c;
}

/// Canonical decomposition of [cp] into one or two characters, or null.
(int, int)? decompose(int cp) {
  var lo = 0, hi = canonicalDecompositions.length ~/ 3 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final k = canonicalDecompositions[3 * mid];
    if (k == cp) return (canonicalDecompositions[3 * mid + 1], canonicalDecompositions[3 * mid + 2]);
    if (k < cp) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return null;
}

Map<int, int>? _compositions;

/// Canonical composition of the pair ([a], [b]), or -1.
int compose(int a, int b) {
  final m = _compositions ??= () {
    final excluded = compositionExclusions.toSet();
    final out = <int, int>{};
    for (var i = 0; i + 2 < canonicalDecompositions.length; i += 3) {
      final c = canonicalDecompositions[i], x = canonicalDecompositions[i + 1], y = canonicalDecompositions[i + 2];
      if (y != 0 && !excluded.contains(c)) out[x * 0x200000 + y] = c;
    }
    return out;
  }();
  return m[a * 0x200000 + b] ?? -1;
}

/// Arabic joining types (ArabicShaping.txt).
abstract final class Joining {
  static const u = 0, l = 1, r = 2, d = 3, t = 6;
}

/// Joining type of [cp]: listed for the Arabic blocks and the joiners;
/// otherwise transparent for non-spacing and enclosing marks and format
/// characters, non-joining for anything else.
int joiningType(int cp) {
  if (cp <= 0xFFFF) {
    final v = rangeValue(arabicJoiningRanges, cp);
    if (v != 0) return v - 1;
  }
  final g = generalCategory(cp);
  return g == Gc.nonSpacingMark || g == Gc.enclosingMark || g == Gc.format ? Joining.t : Joining.u;
}

/// Script ([Script]) of [cp] (Scripts.txt).
int scriptOf(int cp) {
  if (cp <= 0xFFFF) return rangeValue(scriptRanges, cp);
  if (cp >= 0x20000 && cp <= 0x3FFFF) return Script.han;
  if (cp >= 0x1B000 && cp <= 0x1B16F) return cp <= 0x1B0FF || (cp >= 0x1B132 && cp <= 0x1B152) ? Script.hiragana : Script.katakana;
  if (cp >= 0x1F000 && cp <= 0x1FBFF) return Script.common;
  if (cp >= 0xE0100 && cp <= 0xE01EF) return Script.inherited;
  if (cp >= 0xE0000 && cp <= 0xE007F) return Script.common;
  return Script.other;
}

/// Indic syllabic category and position of [cp] (indic.dart).
(int, int) indicProperties(int cp) {
  if (cp > 0xFFFF) return (0, 14);
  final v = rangeValue(indicRanges, cp, 512);
  return (v >> 4, v & 15);
}

/// Default_Ignorable_Code_Point characters that shaping hides (joiners,
/// directional marks, soft hyphen, variation selectors...).
bool isDefaultIgnorable(int cp) {
  if (cp < 0x80) return false;
  if (cp <= 0xFFFF) {
    switch (cp >> 8) {
      case 0x00:
        return cp == 0x00AD;
      case 0x03:
        return cp == 0x034F;
      case 0x06:
        return cp == 0x061C;
      case 0x17:
        return cp >= 0x17B4 && cp <= 0x17B5;
      case 0x18:
        return cp >= 0x180B && cp <= 0x180F;
      case 0x20:
        return (cp >= 0x200B && cp <= 0x200F) || (cp >= 0x202A && cp <= 0x202E) || (cp >= 0x2060 && cp <= 0x206F);
      case 0xFE:
        return (cp >= 0xFE00 && cp <= 0xFE0F) || cp == 0xFEFF;
      case 0xFF:
        return cp >= 0xFFF0 && cp <= 0xFFF8;
      default:
        return false;
    }
  }
  return (cp >= 0x1D173 && cp <= 0x1D17A) || (cp >= 0xE0000 && cp <= 0xE0FFF);
}

/// Whether [cp] is a variation selector.
bool isVariationSelector(int cp) => (cp >= 0x180B && cp <= 0x180D) || cp == 0x180F || (cp >= 0xFE00 && cp <= 0xFE0F) || (cp >= 0xE0100 && cp <= 0xE01EF);
