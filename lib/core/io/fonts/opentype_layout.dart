/// OpenType layout tables (pure Dart): GDEF, GSUB and GPOS as described in
/// the OpenType specification 1.9, chapters "OpenType Layout Common Table
/// Formats" (script, feature and lookup lists, coverage and class
/// definition tables, contextual rules), "GDEF", "GSUB" (lookup types 1 to
/// 8) and "GPOS" (lookup types 1 to 9). Subtables are parsed once, on first
/// use; device and variation tables are ignored (PDF text is scaled, not
/// hinted).
library;

import 'dart:typed_data';

int _u16(ByteData d, int o) => d.getUint16(o);
int _i16(ByteData d, int o) => d.getInt16(o);
int _u32(ByteData d, int o) => d.getUint32(o);
String _tag(ByteData d, int o) => String.fromCharCodes([d.getUint8(o), d.getUint8(o + 1), d.getUint8(o + 2), d.getUint8(o + 3)]);

/// Coverage table: glyph → coverage index.
class Coverage {
  Coverage._(this._glyphs, this._ranges);

  factory Coverage.parse(ByteData d, int o) {
    final format = _u16(d, o);
    if (format == 1) {
      final n = _u16(d, o + 2);
      return Coverage._(Uint16List.fromList([for (var i = 0; i < n; i++) _u16(d, o + 4 + 2 * i)]), null);
    }
    if (format == 2) {
      final n = _u16(d, o + 2);
      final r = Int32List(3 * n);
      for (var i = 0; i < n; i++) {
        r[3 * i] = _u16(d, o + 4 + 6 * i);
        r[3 * i + 1] = _u16(d, o + 6 + 6 * i);
        r[3 * i + 2] = _u16(d, o + 8 + 6 * i);
      }
      return Coverage._(null, r);
    }
    return Coverage._(Uint16List(0), null);
  }

  final Uint16List? _glyphs;
  final Int32List? _ranges;

  /// Coverage index of [glyph], or -1.
  int index(int glyph) {
    final g = _glyphs;
    if (g != null) {
      var lo = 0, hi = g.length - 1;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        final v = g[mid];
        if (v == glyph) return mid;
        if (v < glyph) {
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      return -1;
    }
    final r = _ranges!;
    var lo = 0, hi = r.length ~/ 3 - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (glyph < r[3 * mid]) {
        hi = mid - 1;
      } else if (glyph > r[3 * mid + 1]) {
        lo = mid + 1;
      } else {
        return r[3 * mid + 2] + glyph - r[3 * mid];
      }
    }
    return -1;
  }

  bool covers(int glyph) => index(glyph) >= 0;

  /// Covered glyph ranges (first, last), in coverage order.
  Iterable<(int, int)> ranges() sync* {
    final g = _glyphs;
    if (g != null) {
      for (final v in g) {
        yield (v, v);
      }
      return;
    }
    final r = _ranges!;
    for (var i = 0; i + 2 < r.length; i += 3) {
      yield (r[i], r[i + 1]);
    }
  }
}

/// Class definition table: glyph → class (0 when not listed).
class ClassDef {
  ClassDef._(this._start, this._values, this._ranges);

  factory ClassDef.parse(ByteData d, int o) {
    final format = _u16(d, o);
    if (format == 1) {
      final start = _u16(d, o + 2), n = _u16(d, o + 4);
      return ClassDef._(start, Uint16List.fromList([for (var i = 0; i < n; i++) _u16(d, o + 6 + 2 * i)]), null);
    }
    if (format == 2) {
      final n = _u16(d, o + 2);
      final r = Int32List(3 * n);
      for (var i = 0; i < n; i++) {
        r[3 * i] = _u16(d, o + 4 + 6 * i);
        r[3 * i + 1] = _u16(d, o + 6 + 6 * i);
        r[3 * i + 2] = _u16(d, o + 8 + 6 * i);
      }
      return ClassDef._(0, null, r);
    }
    return ClassDef._(0, Uint16List(0), null);
  }

  /// An empty class definition (every glyph in class 0).
  static final ClassDef empty = ClassDef._(0, Uint16List(0), null);

  final int _start;
  final Uint16List? _values;
  final Int32List? _ranges;

  int classOf(int glyph) {
    final v = _values;
    if (v != null) {
      final i = glyph - _start;
      return i >= 0 && i < v.length ? v[i] : 0;
    }
    final r = _ranges!;
    var lo = 0, hi = r.length ~/ 3 - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (glyph < r[3 * mid]) {
        hi = mid - 1;
      } else if (glyph > r[3 * mid + 1]) {
        lo = mid + 1;
      } else {
        return r[3 * mid + 2];
      }
    }
    return 0;
  }
}

/// Glyph classes of GDEF.
abstract final class GlyphClass {
  static const base = 1, ligature = 2, mark = 3, component = 4;
}

/// GDEF: glyph classes, mark attachment classes and mark glyph sets.
class Gdef {
  Gdef._(this.glyphClasses, this.markAttachClasses, this.markGlyphSets);

  factory Gdef.parse(ByteData d) {
    final version = _u32(d, 0);
    final gc = _u16(d, 4), mac = _u16(d, 10);
    final sets = <Coverage>[];
    if (version >= 0x00010002 && d.lengthInBytes >= 14) {
      final mgs = _u16(d, 12);
      if (mgs != 0) {
        final n = _u16(d, mgs + 2);
        for (var i = 0; i < n; i++) {
          sets.add(Coverage.parse(d, mgs + _u32(d, mgs + 4 + 4 * i)));
        }
      }
    }
    return Gdef._(gc == 0 ? null : ClassDef.parse(d, gc), mac == 0 ? null : ClassDef.parse(d, mac), sets);
  }

  final ClassDef? glyphClasses;
  final ClassDef? markAttachClasses;
  final List<Coverage> markGlyphSets;

  bool get hasGlyphClasses => glyphClasses != null;

  int glyphClass(int glyph) => glyphClasses?.classOf(glyph) ?? 0;

  int markAttachClass(int glyph) => markAttachClasses?.classOf(glyph) ?? 0;

  bool markSetCovers(int set, int glyph) => set < markGlyphSets.length && markGlyphSets[set].covers(glyph);
}

/// Language system: required feature and feature indices.
class LangSys {
  const LangSys(this.requiredFeature, this.featureIndices);
  final int requiredFeature; // 0xFFFF when none
  final List<int> featureIndices;
}

/// Contextual lookup record: apply lookup [lookupIndex] at input position [sequenceIndex].
class LookupRecord {
  const LookupRecord(this.sequenceIndex, this.lookupIndex);
  final int sequenceIndex;
  final int lookupIndex;
}

/// Positioning value (ValueRecord; device tables ignored).
class ValueRecord {
  const ValueRecord(this.xPlacement, this.yPlacement, this.xAdvance, this.yAdvance);
  final int xPlacement, yPlacement, xAdvance, yAdvance;
  static const zero = ValueRecord(0, 0, 0, 0);
  bool get isZero => xPlacement == 0 && yPlacement == 0 && xAdvance == 0 && yAdvance == 0;
}

/// Anchor point (formats 1 to 3; contour points and device tables ignored).
class Anchor {
  const Anchor(this.x, this.y);
  final int x, y;
}

int _valueSize(int format) {
  var n = 0;
  for (var f = format & 0xFF; f != 0; f >>= 1) {
    if (f & 1 != 0) n += 2;
  }
  return n;
}

ValueRecord _value(ByteData d, int o, int format) {
  if (format == 0) return ValueRecord.zero;
  var p = o;
  int read(int bit) {
    if (format & bit == 0) return 0;
    final v = _i16(d, p);
    p += 2;
    return v;
  }

  final xp = read(1), yp = read(2), xa = read(4), ya = read(8);
  return ValueRecord(xp, yp, xa, ya);
}

Anchor? _anchor(ByteData d, int o) {
  if (o == 0) return null;
  return Anchor(_i16(d, o + 2), _i16(d, o + 4));
}

/// Mark record: class and anchor.
class MarkRecord {
  const MarkRecord(this.markClass, this.anchor);
  final int markClass;
  final Anchor anchor;
}

List<MarkRecord> _markArray(ByteData d, int o) {
  final n = _u16(d, o);
  return [for (var i = 0; i < n; i++) MarkRecord(_u16(d, o + 2 + 4 * i), _anchor(d, o + _u16(d, o + 4 + 4 * i)) ?? const Anchor(0, 0))];
}

/// Anchor matrix (base array, ligature attach, mark2 array): [row][class].
List<List<Anchor?>> _anchorMatrix(ByteData d, int o, int classCount) {
  final rows = _u16(d, o);
  return [
    for (var r = 0; r < rows; r++)
      [
        for (var c = 0; c < classCount; c++)
          () {
            final off = _u16(d, o + 2 + 2 * (r * classCount + c));
            return off == 0 ? null : _anchor(d, o + off);
          }(),
      ],
  ];
}

/// Base class of parsed subtables.
sealed class Subtable {
  const Subtable(this.coverage);

  /// Coverage of the first glyph, or null when the subtable has none (format 3 contexts use their first input coverage).
  final Coverage? coverage;
}

// ---------------------------------------------------------------- GSUB

class SingleSubst extends Subtable {
  SingleSubst(super.coverage, this.delta, this.substitutes);
  final int delta;
  final Uint16List? substitutes;

  int substitute(int glyph, int index) => substitutes != null ? (index < substitutes!.length ? substitutes![index] : glyph) : (glyph + delta) & 0xFFFF;
}

class MultipleSubst extends Subtable {
  MultipleSubst(super.coverage, this.sequences);
  final List<List<int>> sequences;
}

class AlternateSubst extends Subtable {
  AlternateSubst(super.coverage, this.alternates);
  final List<List<int>> alternates;
}

class Ligature {
  const Ligature(this.glyph, this.components);
  final int glyph;

  /// Components after the first one.
  final List<int> components;
}

class LigatureSubst extends Subtable {
  LigatureSubst(super.coverage, this.sets);
  final List<List<Ligature>> sets;
}

class ReverseChainSubst extends Subtable {
  ReverseChainSubst(super.coverage, this.backtrack, this.lookahead, this.substitutes);
  final List<Coverage> backtrack;
  final List<Coverage> lookahead;
  final List<int> substitutes;
}

// ---------------------------------------------------------------- contexts

/// Rule of a context (format 1: glyphs, format 2: classes).
class ContextRule {
  const ContextRule(this.input, this.lookups);

  /// Input sequence after the first glyph.
  final List<int> input;
  final List<LookupRecord> lookups;
}

class ChainRule {
  const ChainRule(this.backtrack, this.input, this.lookahead, this.lookups);
  final List<int> backtrack;
  final List<int> input;
  final List<int> lookahead;
  final List<LookupRecord> lookups;
}

class ContextSubtable extends Subtable {
  ContextSubtable(super.coverage, this.format, {this.ruleSets = const [], this.classDef, this.coverages = const [], this.lookups = const []});
  final int format;

  /// Formats 1 and 2: rule sets by coverage index / class.
  final List<List<ContextRule>?> ruleSets;
  final ClassDef? classDef;

  /// Format 3: one coverage per input position.
  final List<Coverage> coverages;
  final List<LookupRecord> lookups;
}

class ChainContextSubtable extends Subtable {
  ChainContextSubtable(
    super.coverage,
    this.format, {
    this.ruleSets = const [],
    this.backtrackClassDef,
    this.inputClassDef,
    this.lookaheadClassDef,
    this.backtrackCoverages = const [],
    this.inputCoverages = const [],
    this.lookaheadCoverages = const [],
    this.lookups = const [],
  });
  final int format;
  final List<List<ChainRule>?> ruleSets;
  final ClassDef? backtrackClassDef, inputClassDef, lookaheadClassDef;
  final List<Coverage> backtrackCoverages, inputCoverages, lookaheadCoverages;
  final List<LookupRecord> lookups;
}

// ---------------------------------------------------------------- GPOS

class SinglePos extends Subtable {
  SinglePos(super.coverage, this.values);
  final List<ValueRecord> values; // one value (format 1) or one per coverage index

  ValueRecord valueFor(int index) => values.length == 1 ? values[0] : (index < values.length ? values[index] : ValueRecord.zero);
}

class PairPos extends Subtable {
  PairPos(
    super.coverage,
    this.format,
    this.valueFormat1,
    this.valueFormat2, {
    this.pairSets = const [],
    this.classDef1,
    this.classDef2,
    this.class1Count = 0,
    this.class2Count = 0,
    this.classValues = const [],
  });
  final int format;
  final int valueFormat1, valueFormat2;

  /// Format 1: per first-glyph coverage index, second glyph → (value1, value2).
  final List<Map<int, (ValueRecord, ValueRecord)>> pairSets;
  final ClassDef? classDef1, classDef2;
  final int class1Count, class2Count;

  /// Format 2: (class1 * class2Count + class2) → (value1, value2).
  final List<(ValueRecord, ValueRecord)> classValues;
}

class CursivePos extends Subtable {
  CursivePos(super.coverage, this.entryExit);
  final List<(Anchor?, Anchor?)> entryExit;
}

class MarkBasePos extends Subtable {
  MarkBasePos(super.coverage, this.baseCoverage, this.classCount, this.marks, this.bases);
  final Coverage baseCoverage;
  final int classCount;
  final List<MarkRecord> marks;
  final List<List<Anchor?>> bases;
}

class MarkLigPos extends Subtable {
  MarkLigPos(super.coverage, this.ligatureCoverage, this.classCount, this.marks, this.ligatures);
  final Coverage ligatureCoverage;
  final int classCount;
  final List<MarkRecord> marks;

  /// Per ligature: [component][class].
  final List<List<List<Anchor?>>> ligatures;
}

class MarkMarkPos extends Subtable {
  MarkMarkPos(super.coverage, this.mark2Coverage, this.classCount, this.marks, this.marks2);
  final Coverage mark2Coverage;
  final int classCount;
  final List<MarkRecord> marks;
  final List<List<Anchor?>> marks2;
}

class UnsupportedSubtable extends Subtable {
  const UnsupportedSubtable() : super(null);
}

/// Lookup flags (OpenType "Lookup table").
abstract final class LookupFlag {
  static const rightToLeft = 0x0001, ignoreBaseGlyphs = 0x0002, ignoreLigatures = 0x0004, ignoreMarks = 0x0008, ignoreFlags = 0x000E;
  static const useMarkFilteringSet = 0x0010, markAttachmentType = 0xFF00;
}

/// A lookup with its parsed subtables.
class Lookup {
  Lookup(this.type, this.flag, this.markFilteringSet, this.subtables);

  /// Lookup type after resolving extension subtables.
  final int type;
  final int flag;
  final int markFilteringSet;
  final List<Subtable> subtables;

  /// Lookup flag with the mark filtering set in the high half, as the
  /// matching code expects it.
  int get props => (flag & 0xFFFF) | (markFilteringSet << 16);
}

/// A GSUB or GPOS table.
class LayoutTable {
  LayoutTable._(this.data, this.isGpos, this._scripts, this._featureTags, this._featureOffsets, this._lookupOffsets);

  factory LayoutTable.parse(ByteData d, {required bool gpos}) {
    final scriptList = _u16(d, 4), featureList = _u16(d, 6), lookupList = _u16(d, 8);
    final scripts = <String, int>{};
    for (var i = 0, n = _u16(d, scriptList); i < n; i++) {
      scripts[_tag(d, scriptList + 2 + 6 * i)] = scriptList + _u16(d, scriptList + 6 + 6 * i);
    }
    final fn = _u16(d, featureList);
    final tags = <String>[], offs = <int>[];
    for (var i = 0; i < fn; i++) {
      tags.add(_tag(d, featureList + 2 + 6 * i));
      offs.add(featureList + _u16(d, featureList + 6 + 6 * i));
    }
    final ln = _u16(d, lookupList);
    final lookups = [for (var i = 0; i < ln; i++) lookupList + _u16(d, lookupList + 2 + 2 * i)];
    return LayoutTable._(d, gpos, scripts, tags, offs, lookups);
  }

  final ByteData data;
  final bool isGpos;
  final Map<String, int> _scripts;
  final List<String> _featureTags;
  final List<int> _featureOffsets;
  final List<int> _lookupOffsets;
  late final List<Lookup?> _lookups = List<Lookup?>.filled(_lookupOffsets.length, null);

  int get lookupCount => _lookupOffsets.length;

  bool hasScript(String tag) => _scripts.containsKey(tag);

  /// Language system of [script] for [language] (or the default one).
  LangSys? langSys(String script, String? language) {
    final so = _scripts[script];
    if (so == null) return null;
    final d = data;
    if (language != null) {
      for (var i = 0, n = _u16(d, so + 2); i < n; i++) {
        if (_tag(d, so + 4 + 6 * i) == language) return _parseLangSys(so + _u16(d, so + 8 + 6 * i));
      }
    }
    final def = _u16(d, so);
    return def == 0 ? null : _parseLangSys(so + def);
  }

  /// Whether the script has a language system tagged [language].
  bool hasLanguage(String script, String language) {
    final so = _scripts[script];
    if (so == null) return false;
    for (var i = 0, n = _u16(data, so + 2); i < n; i++) {
      if (_tag(data, so + 4 + 6 * i) == language) return true;
    }
    return false;
  }

  LangSys _parseLangSys(int o) {
    final d = data;
    final req = _u16(d, o + 2), n = _u16(d, o + 4);
    return LangSys(req, [for (var i = 0; i < n; i++) _u16(d, o + 6 + 2 * i)]);
  }

  String featureTag(int index) => index < _featureTags.length ? _featureTags[index] : '';

  /// Lookup indices of feature [index].
  List<int> featureLookups(int index) {
    if (index >= _featureOffsets.length) return const [];
    final o = _featureOffsets[index];
    final n = _u16(data, o + 2);
    return [for (var i = 0; i < n; i++) _u16(data, o + 4 + 2 * i)];
  }

  /// Lookup [index], parsed on first use.
  Lookup? lookup(int index) {
    if (index < 0 || index >= _lookups.length) return null;
    return _lookups[index] ??= _parseLookup(_lookupOffsets[index]);
  }

  Lookup _parseLookup(int o) {
    final d = data;
    final declared = _u16(d, o);
    final flag = _u16(d, o + 2), n = _u16(d, o + 4);
    final mfs = flag & LookupFlag.useMarkFilteringSet != 0 ? _u16(d, o + 6 + 2 * n) : 0;
    final subs = <Subtable>[];
    final extType = isGpos ? 9 : 7;
    var type = declared;
    for (var i = 0; i < n; i++) {
      var so = o + _u16(d, o + 6 + 2 * i);
      var t = declared;
      try {
        if (declared == extType) {
          t = _u16(d, so + 2);
          so = so + _u32(d, so + 4);
          if (i == 0) type = t;
        }
        subs.add(isGpos ? _parseGpos(t, so) : _parseGsub(t, so));
      } on RangeError {
        subs.add(const UnsupportedSubtable());
      }
    }
    return Lookup(type, flag, mfs, subs);
  }

  Coverage _cov(int base, int rel) => Coverage.parse(data, base + _u16(data, rel));

  List<LookupRecord> _lookupRecords(int o, int n) => [for (var i = 0; i < n; i++) LookupRecord(_u16(data, o + 4 * i), _u16(data, o + 4 * i + 2))];

  Subtable _parseGsub(int type, int o) {
    final d = data;
    final format = _u16(d, o);
    switch (type) {
      case 1:
        final cov = _cov(o, o + 2);
        if (format == 1) return SingleSubst(cov, _i16(d, o + 4), null);
        final n = _u16(d, o + 4);
        return SingleSubst(cov, 0, Uint16List.fromList([for (var i = 0; i < n; i++) _u16(d, o + 6 + 2 * i)]));
      case 2 || 3:
        final cov = _cov(o, o + 2);
        final n = _u16(d, o + 4);
        final seqs = <List<int>>[];
        for (var i = 0; i < n; i++) {
          final so = o + _u16(d, o + 6 + 2 * i);
          final k = _u16(d, so);
          seqs.add([for (var j = 0; j < k; j++) _u16(d, so + 2 + 2 * j)]);
        }
        return type == 2 ? MultipleSubst(cov, seqs) : AlternateSubst(cov, seqs);
      case 4:
        final cov = _cov(o, o + 2);
        final n = _u16(d, o + 4);
        final sets = <List<Ligature>>[];
        for (var i = 0; i < n; i++) {
          final so = o + _u16(d, o + 6 + 2 * i);
          final k = _u16(d, so);
          final ligs = <Ligature>[];
          for (var j = 0; j < k; j++) {
            final lo = so + _u16(d, so + 2 + 2 * j);
            final cc = _u16(d, lo + 2);
            ligs.add(Ligature(_u16(d, lo), [for (var c = 1; c < cc; c++) _u16(d, lo + 2 + 2 * c)]));
          }
          sets.add(ligs);
        }
        return LigatureSubst(cov, sets);
      case 5:
        return _parseContext(o);
      case 6:
        return _parseChainContext(o);
      case 8:
        final cov = _cov(o, o + 2);
        final nb = _u16(d, o + 4);
        final back = [for (var i = 0; i < nb; i++) _cov(o, o + 6 + 2 * i)];
        final la = o + 6 + 2 * nb;
        final nl = _u16(d, la);
        final ahead = [for (var i = 0; i < nl; i++) _cov(o, la + 2 + 2 * i)];
        final sb = la + 2 + 2 * nl;
        final ns = _u16(d, sb);
        return ReverseChainSubst(cov, back, ahead, [for (var i = 0; i < ns; i++) _u16(d, sb + 2 + 2 * i)]);
    }
    return const UnsupportedSubtable();
  }

  ContextSubtable _parseContext(int o) {
    final d = data;
    final format = _u16(d, o);
    if (format == 1 || format == 2) {
      final cov = _cov(o, o + 2);
      final classDef = format == 2 ? ClassDef.parse(d, o + _u16(d, o + 4)) : null;
      final countAt = format == 2 ? o + 6 : o + 4;
      final n = _u16(d, countAt);
      final sets = <List<ContextRule>?>[];
      for (var i = 0; i < n; i++) {
        final off = _u16(d, countAt + 2 + 2 * i);
        if (off == 0) {
          sets.add(null);
          continue;
        }
        final so = o + off;
        final k = _u16(d, so);
        final rules = <ContextRule>[];
        for (var j = 0; j < k; j++) {
          final ro = so + _u16(d, so + 2 + 2 * j);
          final glyphCount = _u16(d, ro), lookupCount = _u16(d, ro + 2);
          final input = [for (var c = 1; c < glyphCount; c++) _u16(d, ro + 4 + 2 * (c - 1))];
          rules.add(ContextRule(input, _lookupRecords(ro + 4 + 2 * (glyphCount - 1), lookupCount)));
        }
        sets.add(rules);
      }
      return ContextSubtable(cov, format, ruleSets: sets, classDef: classDef);
    }
    if (format == 3) {
      final glyphCount = _u16(d, o + 2), lookupCount = _u16(d, o + 4);
      final covs = [for (var i = 0; i < glyphCount; i++) _cov(o, o + 6 + 2 * i)];
      return ContextSubtable(covs.isEmpty ? null : covs.first, 3, coverages: covs, lookups: _lookupRecords(o + 6 + 2 * glyphCount, lookupCount));
    }
    return ContextSubtable(null, 0);
  }

  ChainContextSubtable _parseChainContext(int o) {
    final d = data;
    final format = _u16(d, o);
    if (format == 1 || format == 2) {
      final cov = _cov(o, o + 2);
      ClassDef? bcd, icd, lcd;
      var countAt = o + 4;
      if (format == 2) {
        ClassDef cd(int rel) {
          final off = _u16(d, rel);
          return off == 0 ? ClassDef.empty : ClassDef.parse(d, o + off);
        }

        bcd = cd(o + 4);
        icd = cd(o + 6);
        lcd = cd(o + 8);
        countAt = o + 10;
      }
      final n = _u16(d, countAt);
      final sets = <List<ChainRule>?>[];
      for (var i = 0; i < n; i++) {
        final off = _u16(d, countAt + 2 + 2 * i);
        if (off == 0) {
          sets.add(null);
          continue;
        }
        final so = o + off;
        final k = _u16(d, so);
        final rules = <ChainRule>[];
        for (var j = 0; j < k; j++) {
          var p = so + _u16(d, so + 2 + 2 * j);
          final nb = _u16(d, p);
          final back = [for (var c = 0; c < nb; c++) _u16(d, p + 2 + 2 * c)];
          p += 2 + 2 * nb;
          final ni = _u16(d, p);
          final input = [for (var c = 1; c < ni; c++) _u16(d, p + 2 + 2 * (c - 1))];
          p += 2 + 2 * (ni > 0 ? ni - 1 : 0);
          final nl = _u16(d, p);
          final ahead = [for (var c = 0; c < nl; c++) _u16(d, p + 2 + 2 * c)];
          p += 2 + 2 * nl;
          final lc = _u16(d, p);
          rules.add(ChainRule(back, input, ahead, _lookupRecords(p + 2, lc)));
        }
        sets.add(rules);
      }
      return ChainContextSubtable(cov, format, ruleSets: sets, backtrackClassDef: bcd, inputClassDef: icd, lookaheadClassDef: lcd);
    }
    if (format == 3) {
      var p = o + 2;
      final nb = _u16(d, p);
      final back = [for (var i = 0; i < nb; i++) _cov(o, p + 2 + 2 * i)];
      p += 2 + 2 * nb;
      final ni = _u16(d, p);
      final input = [for (var i = 0; i < ni; i++) _cov(o, p + 2 + 2 * i)];
      p += 2 + 2 * ni;
      final nl = _u16(d, p);
      final ahead = [for (var i = 0; i < nl; i++) _cov(o, p + 2 + 2 * i)];
      p += 2 + 2 * nl;
      final lc = _u16(d, p);
      return ChainContextSubtable(input.isEmpty ? null : input.first, 3, backtrackCoverages: back, inputCoverages: input, lookaheadCoverages: ahead, lookups: _lookupRecords(p + 2, lc));
    }
    return ChainContextSubtable(null, 0);
  }

  Subtable _parseGpos(int type, int o) {
    final d = data;
    final format = _u16(d, o);
    switch (type) {
      case 1:
        final cov = _cov(o, o + 2);
        final vf = _u16(d, o + 4);
        if (format == 1) return SinglePos(cov, [_value(d, o + 6, vf)]);
        final n = _u16(d, o + 6), size = _valueSize(vf);
        return SinglePos(cov, [for (var i = 0; i < n; i++) _value(d, o + 8 + i * size, vf)]);
      case 2:
        final cov = _cov(o, o + 2);
        final vf1 = _u16(d, o + 4), vf2 = _u16(d, o + 6);
        final s1 = _valueSize(vf1), s2 = _valueSize(vf2);
        if (format == 1) {
          final n = _u16(d, o + 8);
          final sets = <Map<int, (ValueRecord, ValueRecord)>>[];
          for (var i = 0; i < n; i++) {
            final so = o + _u16(d, o + 10 + 2 * i);
            final k = _u16(d, so);
            final m = <int, (ValueRecord, ValueRecord)>{};
            for (var j = 0; j < k; j++) {
              final r = so + 2 + j * (2 + s1 + s2);
              m[_u16(d, r)] = (_value(d, r + 2, vf1), _value(d, r + 2 + s1, vf2));
            }
            sets.add(m);
          }
          return PairPos(cov, 1, vf1, vf2, pairSets: sets);
        }
        final cd1 = ClassDef.parse(d, o + _u16(d, o + 8)), cd2 = ClassDef.parse(d, o + _u16(d, o + 10));
        final c1 = _u16(d, o + 12), c2 = _u16(d, o + 14);
        final values = <(ValueRecord, ValueRecord)>[];
        for (var i = 0; i < c1 * c2; i++) {
          final r = o + 16 + i * (s1 + s2);
          values.add((_value(d, r, vf1), _value(d, r + s1, vf2)));
        }
        return PairPos(cov, 2, vf1, vf2, classDef1: cd1, classDef2: cd2, class1Count: c1, class2Count: c2, classValues: values);
      case 3:
        final cov = _cov(o, o + 2);
        final n = _u16(d, o + 4);
        return CursivePos(cov, [
          for (var i = 0; i < n; i++)
            (() {
              final en = _u16(d, o + 6 + 4 * i), ex = _u16(d, o + 8 + 4 * i);
              return (en == 0 ? null : _anchor(d, o + en), ex == 0 ? null : _anchor(d, o + ex));
            })(),
        ]);
      case 4 || 6:
        final cov = _cov(o, o + 2);
        final cov2 = _cov(o, o + 4);
        final classCount = _u16(d, o + 6);
        final marks = _markArray(d, o + _u16(d, o + 8));
        final matrix = _anchorMatrix(d, o + _u16(d, o + 10), classCount);
        return type == 4 ? MarkBasePos(cov, cov2, classCount, marks, matrix) : MarkMarkPos(cov, cov2, classCount, marks, matrix);
      case 5:
        final cov = _cov(o, o + 2);
        final ligCov = _cov(o, o + 4);
        final classCount = _u16(d, o + 6);
        final marks = _markArray(d, o + _u16(d, o + 8));
        final la = o + _u16(d, o + 10);
        final n = _u16(d, la);
        return MarkLigPos(cov, ligCov, classCount, marks, [for (var i = 0; i < n; i++) _anchorMatrix(d, la + _u16(d, la + 2 + 2 * i), classCount)]);
      case 7:
        return _parseContext(o);
      case 8:
        return _parseChainContext(o);
    }
    return const UnsupportedSubtable();
  }
}
