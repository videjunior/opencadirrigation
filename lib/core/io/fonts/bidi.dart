/// Simplified Unicode Bidirectional Algorithm (UAX #9) for single-line
/// labels: paragraph level (P2, P3), weak types (W1 to W7), paired brackets
/// (N0), neutrals (N1, N2), implicit levels (I1, I2), trailing whitespace
/// (L1) and reordering into visual runs (L2). Explicit embeddings,
/// overrides and isolates are not interpreted: their formatting characters
/// are ignored (embeddings, overrides, BN) or treated as neutrals
/// (isolates). Mirroring (L4) is left to the caller (the shaper mirrors the
/// right-to-left runs it shapes).
library;

import 'unicode.dart';

/// A run of one embedding level: UTF-16 indexes [start, end) of the text.
class BidiRun {
  const BidiRun(this.start, this.end, this.level);
  final int start;
  final int end;
  final int level;
  bool get rtl => level.isOdd;
  @override
  String toString() => 'BidiRun($start, $end, $level)';
}

bool _strongOrNumber(int t) => t == Bidi.l || t == Bidi.r || t == Bidi.al || t == Bidi.en || t == Bidi.an;

/// Paragraph embedding level of [text] (P2, P3): 1 when the first strong
/// character is right-to-left, otherwise 0.
int paragraphLevel(String text) {
  for (final r in text.runes) {
    final t = bidiClass(r);
    if (t == Bidi.l) return 0;
    if (t == Bidi.r || t == Bidi.al) return 1;
  }
  return 0;
}

/// Resolved level of every code point of [text] (in code point order).
List<int> bidiLevels(String text, {int? baseLevel}) {
  final cps = text.runes.toList();
  final n = cps.length;
  final para = baseLevel ?? paragraphLevel(text);
  final original = [for (final c in cps) bidiClass(c)];
  final t = [...original];
  final e = para.isOdd ? Bidi.r : Bidi.l; // embedding direction, also sos and eos
  bool removed(int k) => k == Bidi.bn || (k >= Bidi.lre && k <= Bidi.pdf);
  for (var i = 0; i < n; i++) {
    if (t[i] >= Bidi.lri && t[i] <= Bidi.pdi) t[i] = Bidi.on;
  }
  // indexes that take part in resolution (X9: formatting characters removed)
  final idx = [
    for (var i = 0; i < n; i++)
      if (!removed(t[i])) i,
  ];
  final m = idx.length;
  // W1: NSM takes the type of the previous character
  for (var k = 0; k < m; k++) {
    if (t[idx[k]] == Bidi.nsm) t[idx[k]] = k == 0 ? e : t[idx[k - 1]];
  }
  // W2: EN after AL becomes AN
  var lastStrong = e;
  for (var k = 0; k < m; k++) {
    final v = t[idx[k]];
    if (v == Bidi.l || v == Bidi.r || v == Bidi.al) {
      lastStrong = v;
    } else if (v == Bidi.en && lastStrong == Bidi.al) {
      t[idx[k]] = Bidi.an;
    }
  }
  // W3: AL becomes R
  for (final i in idx) {
    if (t[i] == Bidi.al) t[i] = Bidi.r;
  }
  // W4: a single separator between two numbers of the same type
  for (var k = 1; k + 1 < m; k++) {
    final v = t[idx[k]], a = t[idx[k - 1]], b = t[idx[k + 1]];
    if (v == Bidi.es && a == Bidi.en && b == Bidi.en) {
      t[idx[k]] = Bidi.en;
    } else if (v == Bidi.cs && a == b && (a == Bidi.en || a == Bidi.an)) {
      t[idx[k]] = a;
    }
  }
  // W5: terminators next to European numbers
  for (var k = 0; k < m; k++) {
    if (t[idx[k]] != Bidi.et) continue;
    var j = k;
    while (j < m && t[idx[j]] == Bidi.et) {
      j++;
    }
    final touches = (k > 0 && t[idx[k - 1]] == Bidi.en) || (j < m && t[idx[j]] == Bidi.en);
    if (touches) {
      for (var q = k; q < j; q++) {
        t[idx[q]] = Bidi.en;
      }
    }
    k = j - 1;
  }
  // W6: remaining separators and terminators are neutral
  for (final i in idx) {
    final v = t[i];
    if (v == Bidi.es || v == Bidi.et || v == Bidi.cs) t[i] = Bidi.on;
  }
  // W7: EN after L becomes L
  lastStrong = e;
  for (var k = 0; k < m; k++) {
    final v = t[idx[k]];
    if (v == Bidi.l || v == Bidi.r) {
      lastStrong = v;
    } else if (v == Bidi.en && lastStrong == Bidi.l) {
      t[idx[k]] = Bidi.l;
    }
  }
  // N0: paired brackets
  int dir(int v) => v == Bidi.l ? Bidi.l : (v == Bidi.r || v == Bidi.en || v == Bidi.an ? Bidi.r : -1);
  final pairs = <(int, int)>[];
  final stack = <(int, int)>[]; // (closing bracket wanted, position in idx)
  for (var k = 0; k < m; k++) {
    final i = idx[k];
    if (t[i] != Bidi.on) continue;
    final cp = cps[i];
    final close = closingBracketOf(cp);
    if (close >= 0) {
      if (stack.length == 63) break;
      stack.add((close, k));
      continue;
    }
    final open = openingBracketOf(cp);
    if (open < 0) continue;
    for (var s = stack.length - 1; s >= 0; s--) {
      final want = stack[s].$1;
      if (want == cp || (want == 0x232A && cp == 0x3009) || (want == 0x3009 && cp == 0x232A)) {
        pairs.add((stack[s].$2, k));
        stack.removeRange(s, stack.length);
        break;
      }
    }
  }
  pairs.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (o, c) in pairs) {
    var foundE = false, foundOpposite = false;
    for (var k = o + 1; k < c; k++) {
      final d = dir(t[idx[k]]);
      if (d == e) {
        foundE = true;
        break;
      }
      if (d >= 0) foundOpposite = true;
    }
    int? set;
    if (foundE) {
      set = e;
    } else if (foundOpposite) {
      var context = e;
      for (var k = o - 1; k >= 0; k--) {
        final d = dir(t[idx[k]]);
        if (d >= 0) {
          context = d;
          break;
        }
      }
      set = context != e ? context : e;
    }
    if (set != null) {
      for (final k in [o, c]) {
        t[idx[k]] = set;
        // non-spacing marks after a bracket follow it
        for (var q = k + 1; q < m && original[idx[q]] == Bidi.nsm; q++) {
          t[idx[q]] = set;
        }
      }
    }
  }
  // N1, N2: neutrals take the direction of the surrounding strong types,
  // otherwise the embedding direction
  bool neutral(int v) => v == Bidi.on || v == Bidi.ws || v == Bidi.s || v == Bidi.b;
  for (var k = 0; k < m; k++) {
    if (!neutral(t[idx[k]])) continue;
    var j = k;
    while (j < m && neutral(t[idx[j]])) {
      j++;
    }
    final before = k == 0 ? e : dir(t[idx[k - 1]]);
    final after = j == m ? e : dir(t[idx[j]]);
    final v = before == after && before >= 0 ? before : e;
    for (var q = k; q < j; q++) {
      t[idx[q]] = v;
    }
    k = j - 1;
  }
  // I1, I2: implicit levels
  final levels = List<int>.filled(n, para);
  for (final i in idx) {
    final v = t[i];
    if (para.isEven) {
      if (v == Bidi.r) {
        levels[i] = para + 1;
      } else if (v == Bidi.an || v == Bidi.en) {
        levels[i] = para + 2;
      }
    } else if (v == Bidi.l || v == Bidi.en || v == Bidi.an) {
      levels[i] = para + 1;
    }
  }
  // removed characters take the level of the preceding character
  for (var i = 0; i < n; i++) {
    if (removed(original[i])) levels[i] = i == 0 ? para : levels[i - 1];
  }
  // L1: separators and trailing whitespace go back to the paragraph level
  bool ws(int v) => v == Bidi.ws || removed(v) || (v >= Bidi.lri && v <= Bidi.pdi);
  for (var i = 0; i < n; i++) {
    final v = original[i];
    if (v == Bidi.s || v == Bidi.b) {
      levels[i] = para;
      for (var j = i - 1; j >= 0 && ws(original[j]); j--) {
        levels[j] = para;
      }
    }
  }
  for (var j = n - 1; j >= 0 && ws(original[j]); j--) {
    levels[j] = para;
  }
  return levels;
}

/// Runs of [text] in visual order (left to right), one per level change
/// (UAX #9 rule L2).
List<BidiRun> bidiVisualRuns(String text, {int? baseLevel}) {
  if (text.isEmpty) return const [];
  final levels = bidiLevels(text, baseLevel: baseLevel);
  // code point levels → runs over UTF-16 indexes
  final runs = <BidiRun>[];
  var unit = 0, k = 0, start = 0;
  var level = levels.isEmpty ? 0 : levels[0];
  for (final r in text.runes) {
    final l = levels[k];
    if (l != level) {
      runs.add(BidiRun(start, unit, level));
      start = unit;
      level = l;
    }
    unit += r > 0xFFFF ? 2 : 1;
    k++;
  }
  runs.add(BidiRun(start, unit, level));
  var maxLevel = 0, minOdd = 1 << 30;
  for (final r in runs) {
    if (r.level > maxLevel) maxLevel = r.level;
    if (r.level.isOdd && r.level < minOdd) minOdd = r.level;
  }
  for (var lv = maxLevel; lv >= minOdd && lv > 0; lv--) {
    var i = 0;
    while (i < runs.length) {
      if (runs[i].level >= lv) {
        var j = i;
        while (j < runs.length && runs[j].level >= lv) {
          j++;
        }
        final rev = runs.sublist(i, j).reversed.toList();
        runs.setRange(i, j, rev);
        i = j;
      } else {
        i++;
      }
    }
  }
  return runs;
}

/// Whether [cp] can make text right to left (bidi class R or AL).
bool isRightToLeft(int cp) {
  final t = bidiClass(cp);
  return t == Bidi.r || t == Bidi.al;
}

/// Whether [cp] is strong left-to-right, strong right-to-left or a number.
bool hasDirection(int cp) => _strongOrNumber(bidiClass(cp));
