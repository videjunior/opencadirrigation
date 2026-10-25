/// OpenType text shaper (pure Dart): turns a run of text of one script and
/// direction into positioned glyphs of one font, applying the font's own
/// GSUB and GPOS lookups.
///
/// The pipeline follows the OpenType specification ("OpenType Layout
/// Common Table Formats", "GSUB", "GPOS" and the script development
/// documents: "Developing OpenType Fonts for Standard Scripts", "for
/// Arabic Script" and "for Devanagari / Bengali / Gurmukhi / Telugu
/// Script"): characters are normalised against the font (canonical
/// decomposition and composition, mark reordering by combining class),
/// mapped to glyphs, the script shaper sets per-glyph feature masks
/// (Arabic joining forms; Indic syllables, reordering and basic forms),
/// GSUB features are applied stage by stage (lookups of one stage in
/// lookup-list order), then GPOS (kerning, mark attachment) with mark
/// advances zeroed where the script model asks for it. Right-to-left runs
/// come out in visual order (left to right).
library;

import 'opentype_layout.dart';
import 'truetype.dart';
import 'unicode.dart';

part 'shaper_arabic.dart';
part 'shaper_indic.dart';

/// Positioned glyphs of a shaped run, in visual order. Advances and offsets
/// are in font units; y offsets grow upwards.
class ShapedRun {
  ShapedRun(this.glyphs, this.advances, this.xOffsets, this.yOffsets, this.clusters);
  final List<int> glyphs;
  final List<int> advances;
  final List<int> xOffsets;
  final List<int> yOffsets;

  /// Index (UTF-16 code unit) in the shaped text of the first character of
  /// each glyph's cluster.
  final List<int> clusters;

  int get length => glyphs.length;

  /// Sum of the advances (font units).
  int get advance {
    var s = 0;
    for (final a in advances) {
      s += a;
    }
    return s;
  }
}

/// A font prepared for shaping: the TrueType data plus its layout tables
/// and the compiled feature plans.
class ShapingFont {
  ShapingFont(this.font);
  final TrueTypeFont font;

  late final Gdef? gdef = () {
    final t = font.table('GDEF');
    return t == null ? null : Gdef.parse(t);
  }();
  late final LayoutTable? gsub = () {
    final t = font.table('GSUB');
    return t == null ? null : LayoutTable.parse(t, gpos: false);
  }();
  late final LayoutTable? gpos = () {
    final t = font.table('GPOS');
    return t == null ? null : LayoutTable.parse(t, gpos: true);
  }();

  final Map<String, _Plan> _plans = {};
  final Map<int, _Digest> _digests = {};

  /// Design units per em of the font (advances and offsets are in these units).
  int get unitsPerEm => font.unitsPerEm;

  /// Nominal glyph of the character [cp] (0 when the font lacks it).
  int glyphOf(int cp) => font.glyphId(cp);

  /// Shapes [text] (one script, one direction) with this font.
  ///
  /// [script] is a [Script] id, [language] a BCP 47 code (selects the
  /// OpenType language system, e.g. Marathi or Urdu forms) and [rtl] the
  /// direction of the run.
  ShapedRun shape(String text, {required int script, String? language, bool rtl = false}) => _shape(this, text, script, language, rtl);

  _Digest _digest(int lookupIndex) => _digests[lookupIndex] ??= () {
    final d = _Digest();
    final l = gsub?.lookup(lookupIndex);
    if (l != null) {
      for (final s in l.subtables) {
        final c = switch (s) {
          ContextSubtable c when c.format == 3 => c.coverages.isEmpty ? null : c.coverages.first,
          ChainContextSubtable c when c.format == 3 => c.inputCoverages.isEmpty ? null : c.inputCoverages.first,
          _ => s.coverage,
        };
        if (c == null) {
          d.addAll();
        } else {
          d.addCoverage(c);
        }
      }
    }
    return d;
  }();
}

/// Glyph-set digest used to pre-filter lookups (three 64-bit masks of the
/// glyph id shifted by 4, 0 and 6 bits).
class _Digest {
  final List<List<bool>> _masks = List.generate(3, (_) => List<bool>.filled(64, false));
  final List<bool> _all = [false, false, false];
  static const _shifts = [4, 0, 6];

  void addAll() {
    for (var i = 0; i < 3; i++) {
      _all[i] = true;
    }
  }

  void addRange(int a, int b) {
    for (var i = 0; i < 3; i++) {
      if (_all[i]) continue;
      final s = _shifts[i];
      if ((b >> s) - (a >> s) >= 63) {
        _all[i] = true;
        continue;
      }
      final ma = (a >> s) & 63, mb = (b >> s) & 63;
      var k = ma;
      while (true) {
        _masks[i][k] = true;
        if (k == mb) break;
        k = (k + 1) & 63;
      }
    }
  }

  void addCoverage(Coverage c) {
    for (final (a, b) in c.ranges()) {
      addRange(a, b);
    }
  }

  bool mayHave(int g) {
    for (var i = 0; i < 3; i++) {
      if (_all[i]) continue;
      if (!_masks[i][(g >> _shifts[i]) & 63]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- buffer

/// Unicode property flags of a glyph info.
abstract final class _U {
  static const ignorable = 1, hidden = 2, continuation = 4, zwj = 8, zwnj = 16;
}

/// Glyph property bits (low byte: the lookup-flag ignore bits).
abstract final class _G {
  static const base = 0x02, ligature = 0x04, mark = 0x08, substituted = 0x10, ligated = 0x20, multiplied = 0x40;
  static const preserve = substituted | ligated | multiplied;
}

class _Info {
  _Info(this.cp, this.cluster);

  /// Character, then glyph id after mapping.
  int cp;
  int cluster;
  int mask = 0;
  int gc = 0;
  int ccc = 0;
  int uflags = 0;
  int glyphProps = 0;
  int ligProps = 0;
  int syllable = 0;

  /// Shaper variables (Indic category and position, Arabic action).
  int cat = 0, pos = 0;
  int normGlyph = 0;

  /// Width rule of a space drawn with the space glyph (see [_spaceFallback]), or null.
  int? spaceFallback;

  _Info copy() => _Info(cp, cluster)
    ..mask = mask
    ..gc = gc
    ..ccc = ccc
    ..uflags = uflags
    ..glyphProps = glyphProps
    ..ligProps = ligProps
    ..syllable = syllable
    ..cat = cat
    ..pos = pos
    ..normGlyph = normGlyph
    ..spaceFallback = spaceFallback;

  bool get isMark => glyphProps & _G.mark != 0;
  bool get isBaseGlyph => glyphProps & _G.base != 0;
  bool get isLigature => glyphProps & _G.ligature != 0;
  bool get substituted => glyphProps & _G.substituted != 0;
  bool get ligated => glyphProps & _G.ligated != 0;
  bool get multiplied => glyphProps & _G.multiplied != 0;
  bool get ligatedAndDidntMultiply => ligated && !multiplied;
  bool get isDefaultIgnorable => uflags & _U.ignorable != 0 && !substituted;
  bool get isZwj => gc == Gc.format && uflags & _U.zwj != 0;
  bool get isZwnj => gc == Gc.format && uflags & _U.zwnj != 0;
  bool get isHidden => uflags & _U.hidden != 0;
  bool get isContinuation => uflags & _U.continuation != 0;
  bool get isUnicodeMark => gc == Gc.nonSpacingMark || gc == Gc.spacingMark || gc == Gc.enclosingMark;

  // ligature properties: lig id (3 bits) << 5 | IS_LIG_BASE (0x10) | component (4 bits)
  int get ligId => ligProps >> 5;
  bool get _ligBase => ligProps & 0x10 != 0;
  int get ligComp => _ligBase ? 0 : ligProps & 0x0F;
  int get ligNumComps => (glyphProps & _G.ligature != 0) && _ligBase ? ligProps & 0x0F : 1;
  int get ligNumCompsInLigation => multiplied && ligComp != 0 ? 0 : ligNumComps;
  void setLigPropsForLigature(int id, int comps) => ligProps = (id << 5) | 0x10 | (comps & 0x0F);
  void setLigPropsForMark(int id, int comp) => ligProps = (id << 5) | (comp & 0x0F);
}

class _Pos {
  int xAdvance = 0, yAdvance = 0, xOffset = 0, yOffset = 0;
  int attachChain = 0, attachType = 0;
}

const _attachMark = 1, _attachCursive = 2;

void _setUnicodeProps(_Info info) {
  final u = info.cp;
  info.gc = generalCategory(u);
  info.uflags = 0;
  info.ccc = 0;
  if (u >= 0x80) {
    if (isDefaultIgnorable(u)) {
      info.uflags |= _U.ignorable;
      if (u == 0x200C) {
        info.uflags |= _U.zwnj;
      } else if (u == 0x200D) {
        info.uflags |= _U.zwj;
      } else if ((u >= 0x180B && u <= 0x180D) || u == 0x180F || (u >= 0xE0020 && u <= 0xE007F) || u == 0x034F) {
        info.uflags |= _U.hidden;
      }
    }
    if (info.isUnicodeMark) {
      info.uflags |= _U.continuation;
      info.ccc = shapingCombiningClass(u);
    }
  }
}

/// Clusters of [start, end) merged into the smallest one (extending over
/// neighbours that share a cluster with the edges).
void _mergeClusters(List<_Info> buf, int start, int end) {
  if (end - start < 2) return;
  var cluster = buf[start].cluster;
  for (var i = start + 1; i < end; i++) {
    if (buf[i].cluster < cluster) cluster = buf[i].cluster;
  }
  if (cluster != buf[end - 1].cluster) {
    while (end < buf.length && buf[end - 1].cluster == buf[end].cluster) {
      end++;
    }
  }
  if (cluster != buf[start].cluster) {
    while (start > 0 && buf[start - 1].cluster == buf[start].cluster) {
      start--;
    }
  }
  for (var i = start; i < end; i++) {
    buf[i].cluster = cluster;
  }
}

// ---------------------------------------------------------------- plan

const _fGlobal = 1, _fHasFallback = 2, _fManualZwnj = 4, _fManualZwj = 8, _fPerSyllable = 16;
const _fManualJoiners = _fManualZwnj | _fManualZwj;
const _globalBit = 1 << 30;

typedef _Pause = void Function(_Ctx c);

class _FeatureInfo {
  _FeatureInfo(this.tag, this.flags, this.value, this.stage, this.seq);
  final String tag;
  int flags;
  int value;
  int stage;
  final int seq;
}

class _LookupMap {
  _LookupMap(this.index, this.mask, this.autoZwnj, this.autoZwj, this.perSyllable);
  final int index;
  int mask;
  bool autoZwnj, autoZwj;
  final bool perSyllable;
}

class _Stage {
  _Stage(this.lookups, this.pause);
  final List<_LookupMap> lookups;
  final _Pause? pause;
}

enum _ShaperKind { simple, arabic, indic }

class _Plan {
  _Plan(this.kind, this.globalMask, this.masks, this.featureStage, this.gsubStages, this.gposStages, this.gsubScript, this.indic);
  final _ShaperKind kind;
  final int globalMask;

  /// GSUB stage of each feature found.
  final Map<String, int> featureStage;

  /// Mask of each feature found (global features use the global bit).
  final Map<String, int> masks;
  final List<_Stage> gsubStages;
  final List<_Stage> gposStages;
  final String? gsubScript;
  final _IndicPlan? indic;

  int mask(String tag) => masks[tag] ?? 0;
}

class _PlanBuilder {
  _PlanBuilder(this.font, this.scriptTags, this.languageTag) {
    for (final t in [font.gsub, font.gpos]) {
      String? chosen;
      LangSys? ls;
      if (t != null) {
        for (final s in [...scriptTags, 'DFLT', 'dflt', 'latn']) {
          if (t.hasScript(s)) {
            chosen = s;
            break;
          }
        }
        if (chosen != null) {
          ls = t.langSys(chosen, languageTag != null && t.hasLanguage(chosen, languageTag!) ? languageTag : (t.hasLanguage(chosen, 'dflt') ? 'dflt' : null));
        }
      }
      chosenScripts.add(chosen);
      langSys.add(ls);
    }
  }

  final ShapingFont font;
  final List<String> scriptTags;
  final String? languageTag;
  final List<String?> chosenScripts = [];
  final List<LangSys?> langSys = [];
  final List<_FeatureInfo> features = [];
  final List<List<(int, _Pause?)>> pauses = [[], []];
  final List<int> stage = [0, 0];

  void add(String tag, [int flags = 0, int value = 1]) => features.add(_FeatureInfo(tag, flags, value, stage[0], features.length)..stage = stage[0]);
  void enable(String tag, [int flags = 0]) => add(tag, flags | _fGlobal, 1);
  void disable(String tag) => add(tag, _fGlobal, 0);

  /// Pause after the current GSUB stage, running [fn].
  void pauseGsub([_Pause? fn]) {
    pauses[0].add((stage[0], fn));
    stage[0]++;
  }

  /// Whether the chosen language system of GSUB or GPOS has [tag].
  bool hasFeature(String tag) => _featureIndex(0, tag) >= 0 || _featureIndex(1, tag) >= 0;

  int _featureIndex(int table, String tag) {
    final t = table == 0 ? font.gsub : font.gpos;
    final ls = langSys[table];
    if (t == null || ls == null) return -1;
    for (final i in ls.featureIndices) {
      if (t.featureTag(i) == tag) return i;
    }
    return -1;
  }

  _Plan compile(_ShaperKind kind) {
    // merge features by tag (stable by insertion order)
    final sorted = [...features]..sort((a, b) => a.tag != b.tag ? a.tag.compareTo(b.tag) : a.seq.compareTo(b.seq));
    final merged = <_FeatureInfo>[];
    for (final f in sorted) {
      if (merged.isNotEmpty && merged.last.tag == f.tag) {
        final j = merged.last;
        if (f.flags & _fGlobal != 0) {
          j.flags |= _fGlobal;
          j.value = f.value;
        } else {
          if (j.flags & _fGlobal != 0) j.flags ^= _fGlobal;
          if (f.value > j.value) j.value = f.value;
        }
        j.flags |= f.flags & _fHasFallback;
        if (f.stage < j.stage) j.stage = f.stage;
      } else {
        merged.add(_FeatureInfo(f.tag, f.flags, f.value, f.stage, f.seq));
      }
    }
    var nextBit = 1;
    var globalMask = _globalBit;
    final masks = <String, int>{};
    final featureStage = <String, int>{};
    final active = <(_FeatureInfo, int, int, int)>[]; // feature, mask, gsub index, gpos index
    for (final f in merged) {
      if (f.value == 0) continue;
      final gi = _featureIndex(0, f.tag), pi = _featureIndex(1, f.tag);
      if (gi < 0 && pi < 0 && f.flags & _fHasFallback == 0) continue;
      int mask;
      if (f.flags & _fGlobal != 0 && f.value == 1) {
        mask = _globalBit;
      } else {
        if (nextBit >= 30) continue;
        mask = 1 << nextBit;
        nextBit++;
        if (f.flags & _fGlobal != 0) globalMask |= mask;
      }
      masks[f.tag] = mask;
      if (gi >= 0) featureStage[f.tag] = f.stage;
      active.add((f, mask, gi, pi));
    }
    // close the last stages
    pauses[0].add((stage[0], null));
    stage[0]++;
    final gsubStages = _stages(0, active, stage[0], pauses[0]);
    final gposStages = _stages(1, active, 1, [(0, null)]);
    return _Plan(kind, globalMask, masks, featureStage, gsubStages, gposStages, chosenScripts[0], null);
  }

  List<_Stage> _stages(int table, List<(_FeatureInfo, int, int, int)> active, int stageCount, List<(int, _Pause?)> pauseList) {
    final t = table == 0 ? font.gsub : font.gpos;
    final out = <_Stage>[];
    final ls = langSys[table];
    for (var s = 0; s < stageCount; s++) {
      final lookups = <_LookupMap>[];
      if (t != null && ls != null) {
        if (s == 0 && ls.requiredFeature != 0xFFFF) {
          for (final li in t.featureLookups(ls.requiredFeature)) {
            if (li < t.lookupCount) lookups.add(_LookupMap(li, _globalBit, true, true, false));
          }
        }
        for (final (f, mask, gi, pi) in active) {
          final fs = table == 0 ? f.stage : 0;
          if (fs != s) continue;
          final idx = table == 0 ? gi : pi;
          if (idx < 0) continue;
          for (final li in t.featureLookups(idx)) {
            if (li < t.lookupCount) lookups.add(_LookupMap(li, mask, f.flags & _fManualZwnj == 0, f.flags & _fManualZwj == 0, f.flags & _fPerSyllable != 0));
          }
        }
      }
      lookups.sort((a, b) => a.index.compareTo(b.index));
      final mergedLookups = <_LookupMap>[];
      for (final l in lookups) {
        if (mergedLookups.isNotEmpty && mergedLookups.last.index == l.index) {
          final j = mergedLookups.last;
          j.mask |= l.mask;
          j.autoZwnj &= l.autoZwnj;
          j.autoZwj &= l.autoZwj;
        } else {
          mergedLookups.add(l);
        }
      }
      _Pause? pause;
      for (final (ps, fn) in pauseList) {
        if (ps == s) pause = fn;
      }
      out.add(_Stage(mergedLookups, pause));
    }
    return out;
  }
}

/// OpenType script tags tried for a [Script] id, newest first.
List<String> _scriptTags(int script) => switch (script) {
  Script.arabic => const ['arab'],
  Script.devanagari => const ['dev3', 'dev2', 'deva'],
  Script.bengali => const ['bng3', 'bng2', 'beng'],
  Script.gurmukhi => const ['gur3', 'gur2', 'guru'],
  Script.telugu => const ['tel3', 'tel2', 'telu'],
  Script.latin => const ['latn'],
  Script.greek => const ['grek'],
  Script.cyrillic => const ['cyrl'],
  Script.han => const ['hani'],
  Script.hiragana || Script.katakana => const ['kana'],
  Script.hangul => const ['hang'],
  Script.hebrew => const ['hebr'],
  Script.thai => const ['thai'],
  Script.bopomofo => const ['bopo'],
  _ => const [],
};

/// OpenType language system tag of a BCP 47 language code.
String? openTypeLanguage(String? code) {
  if (code == null || code.isEmpty) return null;
  final base = code.toLowerCase().split(RegExp('[-_]')).first;
  return const {
    'ar': 'ARA ', 'bn': 'BEN ', 'ca': 'CAT ', 'de': 'DEU ', 'en': 'ENG ', 'es': 'ESP ', 'fr': 'FRA ', 'ha': 'HAU ', 'hi': 'HIN ', 'id': 'IND ', 'ja': 'JAN ',
    'kok': 'KOK ', 'ks': 'KSH ', 'ku': 'KUR ', 'mh': 'MAH ', 'mk': 'MKD ', 'mo': 'MOL ', 'mr': 'MAR ', 'ne': 'NEP ', 'nv': 'NAV ', 'pa': 'PAN ', 'pi': 'PAL ',
    'pt': 'PTG ', 'ro': 'ROM ', 'ru': 'RUS ', 'sa': 'SAN ', 'sat': 'SAT ', 'sd': 'SND ', 'sr': 'SRB ', 'sw': 'SWK ', 'te': 'TEL ', 'tr': 'TRK ', 'ur': 'URD ',
    'vi': 'VIT ', 'zh': 'ZHS ',
  }[base];
}

_Plan _planFor(ShapingFont font, int script, String? language, bool rtl) {
  final key = '$script|${language ?? ''}|$rtl';
  return font._plans[key] ??= () {
    final b = _PlanBuilder(font, _scriptTags(script), openTypeLanguage(language));
    final gsubScript = b.chosenScripts[0];
    final indicScript = script == Script.devanagari || script == Script.bengali || script == Script.gurmukhi || script == Script.telugu;
    final kind = script == Script.arabic
        ? _ShaperKind.arabic
        : indicScript && gsubScript != null && gsubScript != 'DFLT' && gsubScript != 'latn' && !gsubScript.endsWith('3')
            ? _ShaperKind.indic
            : _ShaperKind.simple;
    b.enable('rvrn');
    b.pauseGsub();
    if (rtl) {
      b.enable('rtla');
      b.add('rtlm');
    } else {
      b.enable('ltra');
      b.enable('ltrm');
    }
    b.add('frac');
    b.add('numr');
    b.add('dnom');
    b.enable('rand');
    switch (kind) {
      case _ShaperKind.arabic:
        _collectArabicFeatures(b);
      case _ShaperKind.indic:
        _collectIndicFeatures(b);
      case _ShaperKind.simple:
        break;
    }
    for (final (t, f) in const [('abvm', _fGlobal), ('blwm', _fGlobal), ('ccmp', _fGlobal), ('locl', _fGlobal), ('mark', _fGlobal | _fManualJoiners), ('mkmk', _fGlobal | _fManualJoiners), ('rlig', _fGlobal)]) {
      b.add(t, f);
    }
    for (final (t, f) in const [('calt', _fGlobal), ('clig', _fGlobal), ('curs', _fGlobal), ('dist', _fGlobal), ('kern', _fGlobal | _fHasFallback), ('liga', _fGlobal), ('rclt', _fGlobal)]) {
      b.add(t, f);
    }
    if (kind == _ShaperKind.indic) {
      b.disable('liga');
      b.pauseGsub(_clearSyllables);
    }
    final plan = b.compile(kind);
    if (kind == _ShaperKind.indic) {
      return _Plan(kind, plan.globalMask, plan.masks, plan.featureStage, plan.gsubStages, plan.gposStages, plan.gsubScript, _IndicPlan(font, plan, script));
    }
    return plan;
  }();
}

void _clearSyllables(_Ctx c) {
  for (final i in c.buf) {
    i.syllable = 0;
  }
}

// ---------------------------------------------------------------- shaping

class _Ctx {
  _Ctx(this.font, this.plan, this.buf, this.rtl, this.script);
  final ShapingFont font;
  final _Plan plan;
  List<_Info> buf;
  final bool rtl;
  final int script;
  List<_Pos> pos = const [];
  int ligSerial = 0;
  bool hasBrokenSyllable = false;

  int allocateLigId() {
    ligSerial = (ligSerial + 1) & 7;
    if (ligSerial == 0) ligSerial = 1;
    return ligSerial;
  }
}

ShapedRun _shape(ShapingFont font, String text, int script, String? language, bool rtl) {
  final plan = _planFor(font, script, language, rtl);
  final buf = <_Info>[];
  for (var i = 0; i < text.length; i++) {
    var cp = text.codeUnitAt(i);
    final start = i;
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < text.length) {
      final lo = text.codeUnitAt(i + 1);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
        i++;
      }
    }
    buf.add(_Info(cp, start));
  }
  final c = _Ctx(font, plan, buf, rtl, script);
  if (buf.isEmpty) return ShapedRun(const [], const [], const [], const [], const []);
  // unicode properties and grapheme clusters
  for (final i in buf) {
    i.mask = plan.globalMask;
    _setUnicodeProps(i);
  }
  for (var i = 1; i < buf.length; i++) {
    if (buf[i].isZwj) buf[i].uflags |= _U.continuation;
  }
  _formClusters(buf);
  if (plan.kind == _ShaperKind.indic) _indicVowelConstraints(c);
  // substitute: mirroring, normalisation, masks, glyphs
  if (rtl) {
    final rtlm = plan.mask('rtlm');
    for (final i in c.buf) {
      final m = mirrorOf(i.cp);
      if (m != i.cp && font.glyphOf(m) != 0) {
        i.cp = m;
      } else {
        i.mask |= rtlm;
      }
    }
  }
  _normalize(c);
  switch (plan.kind) {
    case _ShaperKind.arabic:
      _setupArabicMasks(c);
    case _ShaperKind.indic:
      _setupIndicMasks(c);
    case _ShaperKind.simple:
      break;
  }
  final gdef = font.gdef;
  for (final i in c.buf) {
    i.cp = i.normGlyph;
    i.glyphProps = _gdefProps(gdef, i.cp, i);
    i.ligProps = 0;
  }
  final gsub = font.gsub;
  for (final stage in plan.gsubStages) {
    if (gsub != null) {
      for (final l in stage.lookups) {
        final lookup = gsub.lookup(l.index);
        if (lookup != null) _applyLookup(c, false, lookup, l);
      }
    }
    stage.pause?.call(c);
  }
  // position
  final buf2 = c.buf;
  c.pos = [for (final i in buf2) _Pos()..xAdvance = font.font.advanceWidth(i.cp)];
  for (var i = 0; i < buf2.length; i++) {
    final rule = buf2[i].spaceFallback;
    if (rule != null) c.pos[i].xAdvance = _fallbackSpaceAdvance(font, rule, c.pos[i].xAdvance);
  }
  final gpos = font.gpos;
  for (final stage in plan.gposStages) {
    if (gpos != null) {
      for (final l in stage.lookups) {
        final lookup = gpos.lookup(l.index);
        if (lookup != null) _applyLookup(c, true, lookup, l);
      }
    }
  }
  if (plan.kind != _ShaperKind.indic) {
    for (var i = 0; i < buf2.length; i++) {
      if (buf2[i].isMark) {
        c.pos[i].xAdvance = 0;
        c.pos[i].yAdvance = 0;
      }
    }
  }
  for (var i = 0; i < buf2.length; i++) {
    if (buf2[i].isDefaultIgnorable) {
      c.pos[i].xAdvance = 0;
      c.pos[i].yAdvance = 0;
      c.pos[i].xOffset = 0;
    }
  }
  for (var i = 0; i < buf2.length; i++) {
    _propagateAttachment(c, i, 64);
  }
  // hide default ignorables behind the space glyph
  final space = font.glyphOf(0x20);
  for (final i in buf2) {
    if (i.isDefaultIgnorable) i.cp = space;
  }
  final order = rtl ? [for (var i = buf2.length - 1; i >= 0; i--) i] : [for (var i = 0; i < buf2.length; i++) i];
  return ShapedRun([for (final i in order) buf2[i].cp], [for (final i in order) c.pos[i].xAdvance], [for (final i in order) c.pos[i].xOffset], [for (final i in order) c.pos[i].yOffset], [
    for (final i in order) buf2[i].cluster,
  ]);
}

int _gdefProps(Gdef? gdef, int glyph, _Info info) {
  if (gdef != null && gdef.hasGlyphClasses) {
    return switch (gdef.glyphClass(glyph)) {
      GlyphClass.base => _G.base,
      GlyphClass.ligature => _G.ligature,
      GlyphClass.mark => _G.mark | (gdef.markAttachClass(glyph) << 8),
      _ => 0,
    };
  }
  // no GDEF classes: synthesise from the general category
  return info.gc == Gc.nonSpacingMark && !info.isDefaultIgnorable ? _G.mark : _G.base;
}

void _formClusters(List<_Info> buf) {
  var start = 0;
  for (var i = 1; i <= buf.length; i++) {
    if (i == buf.length || !buf[i].isContinuation) {
      if (i - start > 1) _mergeClusters(buf, start, i);
      start = i;
    }
  }
}

void _propagateAttachment(_Ctx c, int i, int nesting) {
  final pos = c.pos;
  final chain = pos[i].attachChain, type = pos[i].attachType;
  if (chain == 0) return;
  pos[i].attachChain = 0;
  final j = i + chain;
  if (j < 0 || j >= pos.length || nesting == 0) return;
  _propagateAttachment(c, j, nesting - 1);
  if (type & _attachCursive != 0) {
    pos[i].yOffset += pos[j].yOffset;
  } else {
    pos[i].xOffset += pos[j].xOffset;
    pos[i].yOffset += pos[j].yOffset;
    if (!c.rtl) {
      for (var k = j; k < i; k++) {
        pos[i].xOffset -= pos[k].xAdvance;
        pos[i].yOffset -= pos[k].yAdvance;
      }
    } else {
      for (var k = j + 1; k < i + 1; k++) {
        pos[i].xOffset += pos[k].xAdvance;
        pos[i].yOffset += pos[k].yAdvance;
      }
    }
  }
}

// ---------------------------------------------------------------- normalisation

/// Space characters the font may lack, drawn with the space glyph and this
/// width: 0 the space's own width, n > 0 one n-th of the em, -1 a digit's
/// width (figure space), -2 a full stop's (punctuation space), -3 half the
/// space (narrow space), -4 four eighteenths of the em.
const _spaceFallback = <int, int>{
  0x0020: 0, 0x00A0: 0, 0x2000: 2, 0x2001: 1, 0x2002: 2, 0x2003: 1, 0x2004: 3, 0x2005: 4, 0x2006: 6, 0x2007: -1, 0x2008: -2, 0x2009: 5, 0x200A: 16, 0x202F: -3,
  0x205F: -4, 0x3000: 1,
};

int _fallbackSpaceAdvance(ShapingFont font, int rule, int advance) {
  final upem = font.unitsPerEm;
  if (rule > 0) return (upem + rule ~/ 2) ~/ rule;
  switch (rule) {
    case -1:
      for (var d = 0x30; d <= 0x39; d++) {
        final g = font.glyphOf(d);
        if (g != 0) return font.font.advanceWidth(g);
      }
      return advance;
    case -2:
      final g = font.glyphOf(0x2E) != 0 ? font.glyphOf(0x2E) : font.glyphOf(0x2C);
      return g != 0 ? font.font.advanceWidth(g) : advance;
    case -3:
      return advance ~/ 2;
    case -4:
      return upem * 4 ~/ 18;
  }
  return advance;
}

int _nominal(_Ctx c, int cp) => c.font.glyphOf(cp);

bool _decomposeChar(_Ctx c, int ab, List<int> out) {
  if (c.plan.kind == _ShaperKind.indic && (ab == 0x0931 || ab == 0x09DC || ab == 0x09DD || ab == 0x0B94)) return false;
  final d = decompose(ab);
  if (d == null) return false;
  out
    ..clear()
    ..add(d.$1)
    ..add(d.$2);
  return true;
}

int _composeChars(_Ctx c, int a, int b) {
  if (c.plan.kind == _ShaperKind.indic) {
    if (isUnicodeMark(a)) return -1;
    if (a == 0x09AF && b == 0x09BC) return 0x09DF;
  }
  return compose(a, b);
}

/// Normalises the buffer against the font (decompose, reorder marks,
/// recompose), recording each character's glyph in [_Info.normGlyph].
void _normalize(_Ctx c) {
  final input = c.buf;
  if (input.isEmpty) return;
  final shortCircuit = c.plan.kind != _ShaperKind.indic;
  final out = <_Info>[];
  var allSimple = true;
  final tmp = <int>[];

  _Info outChar(_Info cur, int cp, int glyph) {
    final n = cur.copy()
      ..cp = cp
      ..normGlyph = glyph;
    _setUnicodeProps(n);
    out.add(n);
    return n;
  }

  int decomposeRec(_Info cur, bool shortest, int ab) {
    if (!_decomposeChar(c, ab, tmp)) return 0;
    final a = tmp[0], b = tmp[1];
    final bGlyph = b != 0 ? _nominal(c, b) : 0;
    if (b != 0 && bGlyph == 0) return 0;
    final aGlyph = _nominal(c, a);
    final hasA = aGlyph != 0;
    if (shortest && hasA) {
      outChar(cur, a, aGlyph);
      if (b != 0) {
        outChar(cur, b, bGlyph);
        return 2;
      }
      return 1;
    }
    final ret = decomposeRec(cur, shortest, a);
    if (ret > 0) {
      if (b != 0) {
        outChar(cur, b, bGlyph);
        return ret + 1;
      }
      return ret;
    }
    if (hasA) {
      outChar(cur, a, aGlyph);
      if (b != 0) {
        outChar(cur, b, bGlyph);
        return 2;
      }
      return 1;
    }
    return 0;
  }

  void decomposeCurrent(_Info cur, bool shortest) {
    final u = cur.cp;
    var glyph = _nominal(c, u);
    if (shortest && glyph != 0) {
      out.add(cur..normGlyph = glyph);
      return;
    }
    if (decomposeRec(cur, shortest, u) > 0) return;
    if (!shortest && glyph != 0) {
      out.add(cur..normGlyph = glyph);
      return;
    }
    if (cur.gc == Gc.space && _spaceFallback.containsKey(u)) {
      final space = _nominal(c, 0x20);
      if (space != 0) {
        cur.spaceFallback = _spaceFallback[u];
        out.add(cur..normGlyph = space);
        return;
      }
    }
    if (u == 0x2011) {
      final g = _nominal(c, 0x2010);
      if (g != 0) {
        out.add(cur..normGlyph = g);
        return;
      }
    }
    out.add(cur..normGlyph = glyph);
  }

  var i = 0;
  final count = input.length;
  while (i < count) {
    var end = i + 1;
    while (end < count && !input[end].isUnicodeMark) {
      end++;
    }
    if (end < count) end--; // leave one base for the marks
    while (i < end) {
      decomposeCurrent(input[i], shortCircuit);
      i++;
    }
    if (i == count) break;
    allSimple = false;
    end = i + 1;
    while (end < count && input[end].isUnicodeMark) {
      end++;
    }
    // one non-simple cluster (a base and its marks)
    var hasVs = false;
    for (var k = i; k < end; k++) {
      if (isVariationSelector(input[k].cp)) hasVs = true;
    }
    if (hasVs) {
      for (var k = i; k < end; k++) {
        input[k].normGlyph = _nominal(c, input[k].cp);
        out.add(input[k]);
      }
    } else {
      for (var k = i; k < end; k++) {
        decomposeCurrent(input[k], false);
      }
    }
    i = end;
  }
  var buf = out;
  // reorder marks by combining class
  if (!allSimple) {
    for (var k = 0; k < buf.length; k++) {
      if (buf[k].ccc == 0 || !buf[k].isUnicodeMark) continue;
      var end = k + 1;
      while (end < buf.length && buf[end].isUnicodeMark && buf[end].ccc != 0) {
        end++;
      }
      if (end - k <= 32) {
        _stableSortByCcc(buf, k, end);
        if (c.plan.kind == _ShaperKind.arabic) _reorderArabicMarks(buf, k, end);
      }
      k = end;
    }
  }
  // recompose
  if (!allSimple) {
    final res = <_Info>[];
    var starter = 0;
    res.add(buf[0]);
    for (var k = 1; k < buf.length; k++) {
      final cur = buf[k];
      if (cur.isUnicodeMark) {
        final prev = res.last;
        final prevCc = prev.isUnicodeMark ? prev.ccc : 0;
        if (starter == res.length - 1 || prevCc < (cur.isUnicodeMark ? cur.ccc : 0)) {
          final composed = _composeChars(c, res[starter].cp, cur.cp);
          if (composed >= 0) {
            final glyph = _nominal(c, composed);
            if (glyph != 0) {
              final st = res[starter];
              if (cur.cluster < st.cluster) st.cluster = cur.cluster;
              for (var m = starter + 1; m < res.length; m++) {
                if (res[m].cluster < st.cluster) st.cluster = res[m].cluster;
              }
              st.cp = composed;
              st.normGlyph = glyph;
              _setUnicodeProps(st);
              continue;
            }
          }
        }
      }
      res.add(cur);
      if (!(cur.isUnicodeMark && cur.ccc != 0)) starter = res.length - 1;
    }
    buf = res;
  }
  c.buf = buf;
}

void _stableSortByCcc(List<_Info> buf, int start, int end) {
  for (var i = start + 1; i < end; i++) {
    final t = buf[i];
    var j = i;
    while (j > start && buf[j - 1].ccc > t.ccc) {
      buf[j] = buf[j - 1];
      j--;
    }
    if (j != i) {
      buf[j] = t;
      _mergeClusters(buf, j, i + 1);
    }
  }
}

// ---------------------------------------------------------------- lookups

class _Matcher {
  _Matcher(this.c, this.gpos, this.lookupProps, this.lookupMask, this.autoZwnj, this.autoZwj, this.perSyllable);
  final _Ctx c;
  final bool gpos;
  int lookupProps;
  final int lookupMask;
  final bool autoZwnj, autoZwj, perSyllable;

  bool checkGlyphProperty(_Info info, int matchProps) {
    final gp = info.glyphProps;
    if (gp & matchProps & LookupFlag.ignoreFlags != 0) return false;
    if (gp & _G.mark != 0) {
      if (matchProps & LookupFlag.useMarkFilteringSet != 0) return c.font.gdef?.markSetCovers(matchProps >> 16, info.cp) ?? false;
      if (matchProps & LookupFlag.markAttachmentType != 0) return (matchProps & LookupFlag.markAttachmentType) == (gp & LookupFlag.markAttachmentType);
    }
    return true;
  }

  static const _skipNo = 0, _skipYes = 1, _skipMaybe = 2;
  static const match = 0, notMatch = 1, skip = 2;

  int _maySkip(_Info info, bool context, int props) {
    if (!checkGlyphProperty(info, props)) return _skipYes;
    final ignoreZwnj = gpos || (context && autoZwnj);
    final ignoreZwj = context || autoZwj;
    if (info.isDefaultIgnorable && (ignoreZwnj || !info.isZwnj) && (ignoreZwj || !info.isZwj) && (gpos || !info.isHidden)) return _skipMaybe;
    return _skipNo;
  }

  /// Match status of [info]: [pred] decides the glyph (null: any glyph).
  int matchInfo(_Info info, bool context, int syllable, bool Function(int glyph)? pred, [int? props]) {
    final skipState = _maySkip(info, context, props ?? lookupProps);
    if (skipState == _skipYes) return skip;
    final mask = context ? -1 : lookupMask;
    bool? m;
    if ((info.mask & mask) == 0 || (!gpos && perSyllable && syllable != 0 && syllable != info.syllable)) {
      m = false;
    } else if (pred != null) {
      m = pred(info.cp);
    }
    if (m == true || (m == null && skipState == _skipNo)) return match;
    if (skipState == _skipNo) return notMatch;
    return skip;
  }

  /// Next matching position after [from], or -1.
  int next(int from, bool context, int syllable, bool Function(int glyph)? pred, [int? props]) {
    final buf = c.buf;
    for (var i = from + 1; i < buf.length; i++) {
      final r = matchInfo(buf[i], context, syllable, pred, props);
      if (r == match) return i;
      if (r == notMatch) return -1;
    }
    return -1;
  }

  /// Previous matching position before [from], or -1.
  int prev(int from, bool context, int syllable, bool Function(int glyph)? pred, [int? props]) {
    final buf = c.buf;
    for (var i = from - 1; i >= 0; i--) {
      final r = matchInfo(buf[i], context, syllable, pred, props);
      if (r == match) return i;
      if (r == notMatch) return -1;
    }
    return -1;
  }
}

class _Apply {
  _Apply(this.c, this.gpos, this.table, this.m);
  final _Ctx c;
  final bool gpos;
  final LayoutTable table;
  final _Matcher m;
  int idx = 0;
  int nesting = 64;

  // GPOS: last base found for mark attachment
  int lastBase = -1, lastBaseUntil = 0;

  List<_Info> get buf => c.buf;

  void setGlyphClass(_Info info, int glyph, {int classGuess = 0, bool ligature = false, bool component = false}) {
    var props = info.glyphProps | _G.substituted;
    if (ligature) {
      props |= _G.ligated;
      props &= ~_G.multiplied;
    }
    if (component) props |= _G.multiplied;
    final gdef = c.font.gdef;
    if (gdef != null && gdef.hasGlyphClasses) {
      info.glyphProps = (props & _G.preserve) | _gdefProps(gdef, glyph, info);
    } else if (classGuess != 0) {
      info.glyphProps = (props & _G.preserve) | classGuess;
    } else {
      info.glyphProps = props;
    }
  }

  void replaceGlyph(int glyph) {
    final cur = buf[idx];
    setGlyphClass(cur, glyph);
    cur.cp = glyph;
    idx++;
  }

  /// Applies the subtables of [lookup] at [idx] (first one that applies wins).
  bool applyOnce(Lookup lookup) {
    for (final s in lookup.subtables) {
      if (gpos ? _applyGpos(s) : _applyGsub(s, lookup)) return true;
    }
    return false;
  }

  bool recurse(int lookupIndex) {
    if (nesting == 0) return false;
    final l = table.lookup(lookupIndex);
    if (l == null) return false;
    final savedProps = m.lookupProps;
    m.lookupProps = l.props;
    nesting--;
    final r = applyOnce(l);
    nesting++;
    m.lookupProps = savedProps;
    return r;
  }

  // ------------------------------------------------------------ input matching

  /// Matches [count] glyphs (including the current one) with [pred] for the
  /// following ones; returns the positions (and sets [matchEnd] and
  /// [totalComponents]) or null.
  List<int>? matchInput(int count, bool Function(int i, int glyph) pred) {
    final positions = <int>[idx];
    final cur = buf[idx];
    if (count == 1) {
      matchEnd = idx + 1;
      totalComponents = cur.ligNumComps;
      return positions;
    }
    final syllable = cur.syllable;
    var total = 0;
    final firstLigId = cur.ligId, firstLigComp = cur.ligComp;
    var ligbase = 0; // 0 not checked, 1 may not skip, 2 may skip
    var p = idx;
    for (var i = 1; i < count; i++) {
      final k = i - 1;
      p = m.next(p, false, syllable, (g) => pred(k, g));
      if (p < 0) return null;
      positions.add(p);
      final info = buf[p];
      final thisLigId = info.ligId, thisLigComp = info.ligComp;
      if (firstLigId != 0 && firstLigComp != 0) {
        if (firstLigId != thisLigId || firstLigComp != thisLigComp) {
          if (ligbase == 0) {
            var found = false;
            var j = idx;
            while (j > 0 && buf[j - 1].ligId == firstLigId) {
              if (buf[j - 1].ligComp == 0) {
                j--;
                found = true;
                break;
              }
              j--;
            }
            ligbase = found && m._maySkip(buf[j], false, m.lookupProps) == _Matcher._skipYes ? 2 : 1;
          }
          if (ligbase == 1) return null;
        }
      } else if (thisLigId != 0 && thisLigComp != 0 && thisLigId != firstLigId) {
        return null;
      }
      total += info.ligNumCompsInLigation;
    }
    matchEnd = p + 1;
    totalComponents = total + cur.ligNumComps;
    return positions;
  }

  int matchEnd = 0;
  int totalComponents = 0;

  bool matchBacktrack(int count, bool Function(int i, int glyph) pred) {
    var p = idx;
    final syllable = buf[idx].syllable;
    for (var i = 0; i < count; i++) {
      final k = i;
      p = m.prev(p, true, syllable, (g) => pred(k, g));
      if (p < 0) return false;
    }
    return true;
  }

  bool matchLookahead(int count, bool Function(int i, int glyph) pred, int start) {
    var p = start - 1;
    final syllable = buf[idx].syllable;
    for (var i = 0; i < count; i++) {
      final k = i;
      p = m.next(p, true, syllable, (g) => pred(k, g));
      if (p < 0) return false;
    }
    return true;
  }

  /// Applies the nested lookups of a matched context and moves to its end.
  void applyLookupRecords(List<int> positions, List<LookupRecord> records, int end) {
    var count = positions.length;
    final mp = [...positions];
    for (final r in records) {
      final i = r.sequenceIndex;
      if (i >= count) continue;
      final origLen = buf.length;
      if (mp[i] >= origLen) continue;
      idx = mp[i];
      final ok = recurse(r.lookupIndex);
      if (!ok) continue;
      final newLen = buf.length;
      var delta = newLen - origLen;
      if (delta == 0) continue;
      end += delta;
      if (end < mp[i]) {
        delta += mp[i] - end;
        end = mp[i];
      }
      // glyphs added after the current position, or removed after it
      var next = i + 1;
      if (delta < 0) {
        delta = delta > next - count ? delta : next - count;
        next -= delta;
      }
      // shift
      final tail = mp.sublist(next, count);
      final newCount = count + delta;
      while (mp.length < newCount) {
        mp.add(0);
      }
      for (var k = 0; k < tail.length; k++) {
        mp[next + delta + k] = tail[k];
      }
      next += delta;
      count = newCount;
      for (var j = i + 1; j < next; j++) {
        mp[j] = mp[j - 1] + 1;
      }
      for (; next < count; next++) {
        mp[next] += delta;
      }
    }
    idx = end;
  }

  // ------------------------------------------------------------ GSUB

  bool _applyGsub(Subtable s, Lookup lookup) {
    final cur = buf[idx];
    switch (s) {
      case SingleSubst t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0) return false;
        replaceGlyph(t.substitute(cur.cp, index));
        return true;
      case MultipleSubst t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0 || index >= t.sequences.length) return false;
        final seq = t.sequences[index];
        if (seq.length == 1) {
          replaceGlyph(seq[0]);
          return true;
        }
        if (seq.isEmpty) {
          _deleteGlyph();
          return true;
        }
        final klass = cur.isLigature ? _G.base : 0;
        final ligId = cur.ligId;
        final outs = <_Info>[];
        for (var i = 0; i < seq.length; i++) {
          if (ligId == 0) cur.setLigPropsForMark(0, i);
          setGlyphClass(cur, seq[i], classGuess: klass, component: true);
          outs.add(cur.copy()..cp = seq[i]);
        }
        buf.replaceRange(idx, idx + 1, outs);
        idx += outs.length;
        return true;
      case AlternateSubst t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0 || index >= t.alternates.length || t.alternates[index].isEmpty) return false;
        replaceGlyph(t.alternates[index][0]);
        return true;
      case LigatureSubst t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0 || index >= t.sets.length) return false;
        for (final lig in t.sets[index]) {
          if (lig.components.isEmpty) {
            replaceGlyph(lig.glyph);
            return true;
          }
          final comps = lig.components;
          final positions = matchInput(comps.length + 1, (i, g) => g == comps[i]);
          if (positions == null) continue;
          _ligate(positions, matchEnd, lig.glyph, totalComponents);
          return true;
        }
        return false;
      case ContextSubtable t:
        return _applyContext(t);
      case ChainContextSubtable t:
        return _applyChainContext(t);
      case ReverseChainSubst _:
        return false; // applied by [_applyReverse]
      case UnsupportedSubtable _:
        return false;
      default:
        return false;
    }
  }

  void _deleteGlyph() {
    final cluster = buf[idx].cluster;
    if (idx + 1 < buf.length && buf[idx + 1].cluster != cluster && idx > 0 && buf[idx - 1].cluster != cluster) {
      if (cluster < buf[idx - 1].cluster) {
        final old = buf[idx - 1].cluster;
        for (var i = idx; i > 0 && buf[i - 1].cluster == old; i--) {
          buf[i - 1].cluster = cluster;
        }
      }
    } else if (idx == 0 && idx + 1 < buf.length && buf[idx + 1].cluster != cluster) {
      _mergeClusters(buf, idx, idx + 2);
    }
    buf.removeAt(idx);
  }

  void _ligate(List<int> mp, int end, int ligGlyph, int totalComponentCount) {
    final count = mp.length;
    _mergeClusters(buf, idx, end);
    var isBaseLigature = buf[mp[0]].isBaseGlyph;
    var isMarkLigature = buf[mp[0]].isMark;
    for (var i = 1; i < count; i++) {
      if (!buf[mp[i]].isMark) {
        isBaseLigature = false;
        isMarkLigature = false;
        break;
      }
    }
    final isLigature = !isBaseLigature && !isMarkLigature;
    final klass = isLigature ? _G.ligature : 0;
    final ligId = isLigature ? c.allocateLigId() : 0;
    final cur = buf[idx];
    var lastLigId = cur.ligId;
    var lastNumComponents = cur.ligNumComps;
    var componentsSoFar = lastNumComponents;
    if (isLigature) {
      cur.setLigPropsForLigature(ligId, totalComponentCount);
      if (cur.gc == Gc.nonSpacingMark) cur.gc = Gc.letter;
    }
    setGlyphClass(cur, ligGlyph, classGuess: klass, ligature: true);
    cur.cp = ligGlyph;
    // walk the matched span: keep the glyphs between components, drop the components
    final kept = <_Info>[cur];
    var p = mp[0] + 1;
    for (var i = 1; i < count; i++) {
      while (p < mp[i]) {
        final g = buf[p];
        if (isLigature) {
          var thisComp = g.ligComp;
          if (thisComp == 0) thisComp = lastNumComponents;
          final newLigComp = componentsSoFar - lastNumComponents + (thisComp < lastNumComponents ? thisComp : lastNumComponents);
          g.setLigPropsForMark(ligId, newLigComp);
        }
        kept.add(g);
        p++;
      }
      final comp = buf[mp[i]];
      lastLigId = comp.ligId;
      lastNumComponents = comp.ligNumCompsInLigation;
      componentsSoFar += lastNumComponents;
      p = mp[i] + 1;
    }
    buf.replaceRange(mp[0], mp[count - 1] + 1, kept);
    idx = mp[0] + kept.length;
    if (!isMarkLigature && lastLigId != 0) {
      for (var i = idx; i < buf.length; i++) {
        if (buf[i].ligId != lastLigId) break;
        final thisComp = buf[i].ligComp;
        if (thisComp == 0) break;
        final newLigComp = componentsSoFar - lastNumComponents + (thisComp < lastNumComponents ? thisComp : lastNumComponents);
        buf[i].setLigPropsForMark(ligId, newLigComp);
      }
    }
  }

  bool _applyContext(ContextSubtable t) {
    final cur = buf[idx];
    switch (t.format) {
      case 1 || 2:
        final index = t.coverage!.index(cur.cp);
        if (index < 0) return false;
        final setIndex = t.format == 1 ? index : t.classDef!.classOf(cur.cp);
        if (setIndex >= t.ruleSets.length) return false;
        final rules = t.ruleSets[setIndex];
        if (rules == null) return false;
        final cd = t.classDef;
        for (final r in rules) {
          final input = r.input;
          final positions = matchInput(input.length + 1, t.format == 1 ? (i, g) => g == input[i] : (i, g) => cd!.classOf(g) == input[i]);
          if (positions == null) continue;
          applyLookupRecords(positions, r.lookups, matchEnd);
          return true;
        }
        return false;
      case 3:
        if (t.coverages.isEmpty || t.coverages[0].index(cur.cp) < 0) return false;
        final covs = t.coverages;
        final positions = matchInput(covs.length, (i, g) => covs[i + 1].covers(g));
        if (positions == null) return false;
        applyLookupRecords(positions, t.lookups, matchEnd);
        return true;
    }
    return false;
  }

  bool _applyChainContext(ChainContextSubtable t) {
    final cur = buf[idx];
    switch (t.format) {
      case 1 || 2:
        final index = t.coverage!.index(cur.cp);
        if (index < 0) return false;
        final setIndex = t.format == 1 ? index : t.inputClassDef!.classOf(cur.cp);
        if (setIndex >= t.ruleSets.length) return false;
        final rules = t.ruleSets[setIndex];
        if (rules == null) return false;
        for (final r in rules) {
          final bool Function(int, int) mi, mb, ml;
          if (t.format == 1) {
            mi = (i, g) => g == r.input[i];
            mb = (i, g) => g == r.backtrack[i];
            ml = (i, g) => g == r.lookahead[i];
          } else {
            mi = (i, g) => t.inputClassDef!.classOf(g) == r.input[i];
            mb = (i, g) => t.backtrackClassDef!.classOf(g) == r.backtrack[i];
            ml = (i, g) => t.lookaheadClassDef!.classOf(g) == r.lookahead[i];
          }
          final positions = matchInput(r.input.length + 1, mi);
          if (positions == null) continue;
          final end = matchEnd;
          if (!matchLookahead(r.lookahead.length, ml, end)) continue;
          if (!matchBacktrack(r.backtrack.length, mb)) continue;
          applyLookupRecords(positions, r.lookups, end);
          return true;
        }
        return false;
      case 3:
        final ic = t.inputCoverages;
        if (ic.isEmpty || ic[0].index(cur.cp) < 0) return false;
        final positions = matchInput(ic.length, (i, g) => ic[i + 1].covers(g));
        if (positions == null) return false;
        final end = matchEnd;
        if (!matchLookahead(t.lookaheadCoverages.length, (i, g) => t.lookaheadCoverages[i].covers(g), end)) return false;
        if (!matchBacktrack(t.backtrackCoverages.length, (i, g) => t.backtrackCoverages[i].covers(g))) return false;
        applyLookupRecords(positions, t.lookups, end);
        return true;
    }
    return false;
  }

  // ------------------------------------------------------------ GPOS

  void _applyValue(_Pos p, ValueRecord v) {
    p.xOffset += v.xPlacement;
    p.yOffset += v.yPlacement;
    p.xAdvance += v.xAdvance;
  }

  bool _applyGpos(Subtable s) {
    final cur = buf[idx];
    final pos = c.pos;
    switch (s) {
      case SinglePos t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0) return false;
        if (t.values.length > 1 && index >= t.values.length) return false;
        _applyValue(pos[idx], t.valueFor(index));
        idx++;
        return true;
      case PairPos t:
        final index = t.coverage!.index(cur.cp);
        if (index < 0) return false;
        final j = m.next(idx, false, 0, null);
        if (j < 0) return false;
        final second = buf[j].cp;
        (ValueRecord, ValueRecord)? v;
        if (t.format == 1) {
          if (index >= t.pairSets.length) return false;
          v = t.pairSets[index][second];
          if (v == null) return false;
        } else {
          final k1 = t.classDef1!.classOf(cur.cp), k2 = t.classDef2!.classOf(second);
          if (k1 >= t.class1Count || k2 >= t.class2Count) return false;
          v = t.classValues[k1 * t.class2Count + k2];
        }
        _applyValue(pos[idx], v.$1);
        _applyValue(pos[j], v.$2);
        idx = t.valueFormat2 != 0 ? j + 1 : j;
        return true;
      case CursivePos t:
        return _applyCursive(t);
      case MarkBasePos t:
        final markIndex = t.coverage!.index(cur.cp);
        if (markIndex < 0) return false;
        if (lastBaseUntil > idx) {
          lastBaseUntil = 0;
          lastBase = -1;
        }
        for (var j = idx; j > lastBaseUntil; j--) {
          var r = m.matchInfo(buf[j - 1], false, 0, null, LookupFlag.ignoreMarks);
          if (r == _Matcher.match && !_acceptBase(j - 1) && t.baseCoverage.index(buf[j - 1].cp) < 0) r = _Matcher.skip;
          if (r == _Matcher.match) {
            lastBase = j - 1;
            break;
          }
        }
        lastBaseUntil = idx;
        if (lastBase < 0) return false;
        final b = lastBase;
        final baseIndex = t.baseCoverage.index(buf[b].cp);
        if (baseIndex < 0) return false;
        return _markAttach(t.marks, markIndex, t.bases, baseIndex, b);
      case MarkLigPos t:
        final markIndex = t.coverage!.index(cur.cp);
        if (markIndex < 0) return false;
        if (lastBaseUntil > idx) {
          lastBaseUntil = 0;
          lastBase = -1;
        }
        for (var j = idx; j > lastBaseUntil; j--) {
          final r = m.matchInfo(buf[j - 1], false, 0, null, LookupFlag.ignoreMarks);
          if (r == _Matcher.match) {
            lastBase = j - 1;
            break;
          }
        }
        lastBaseUntil = idx;
        if (lastBase < 0) return false;
        final b = lastBase;
        final ligIndex = t.ligatureCoverage.index(buf[b].cp);
        if (ligIndex < 0 || ligIndex >= t.ligatures.length) return false;
        final attach = t.ligatures[ligIndex];
        final compCount = attach.length;
        if (compCount == 0) return false;
        final ligId = buf[b].ligId, markId = cur.ligId, markComp = cur.ligComp;
        final compIndex = ligId != 0 && ligId == markId && markComp > 0 ? (compCount < markComp ? compCount : markComp) - 1 : compCount - 1;
        return _markAttach(t.marks, markIndex, attach, compIndex, b);
      case MarkMarkPos t:
        final markIndex = t.coverage!.index(cur.cp);
        if (markIndex < 0) return false;
        final j = m.prev(idx, false, 0, null, m.lookupProps & ~LookupFlag.ignoreFlags);
        if (j < 0 || !buf[j].isMark) return false;
        final id1 = cur.ligId, id2 = buf[j].ligId, comp1 = cur.ligComp, comp2 = buf[j].ligComp;
        var good = false;
        if (id1 == id2) {
          good = id1 == 0 || comp1 == comp2;
        } else {
          good = (id1 > 0 && comp1 == 0) || (id2 > 0 && comp2 == 0);
        }
        if (!good) return false;
        final mark2Index = t.mark2Coverage.index(buf[j].cp);
        if (mark2Index < 0) return false;
        return _markAttach(t.marks, markIndex, t.marks2, mark2Index, j);
      case ContextSubtable t:
        return _applyContext(t);
      case ChainContextSubtable t:
        return _applyChainContext(t);
      default:
        return false;
    }
  }

  bool _acceptBase(int i) {
    final info = buf[i];
    return !info.multiplied ||
        info.ligComp == 0 ||
        i == 0 ||
        buf[i - 1].isMark ||
        !buf[i - 1].multiplied ||
        info.ligId != buf[i - 1].ligId ||
        info.ligComp != buf[i - 1].ligComp + 1;
  }

  bool _markAttach(List<MarkRecord> marks, int markIndex, List<List<Anchor?>> matrix, int row, int glyphPos) {
    if (markIndex >= marks.length || row >= matrix.length) return false;
    final rec = marks[markIndex];
    if (rec.markClass >= matrix[row].length) return false;
    final baseAnchor = matrix[row][rec.markClass];
    if (baseAnchor == null) return false;
    final p = c.pos[idx];
    p.xOffset = baseAnchor.x - rec.anchor.x;
    p.yOffset = baseAnchor.y - rec.anchor.y;
    p.attachType = _attachMark;
    p.attachChain = glyphPos - idx;
    idx++;
    return true;
  }

  /// Cursive attachment is not used by the bundled fonts; such lookups are skipped.
  bool _applyCursive(CursivePos t) => false;
}

void _applyLookup(_Ctx c, bool gpos, Lookup lookup, _LookupMap lm) {
  final table = gpos ? c.font.gpos! : c.font.gsub!;
  final m = _Matcher(c, gpos, lookup.props, lm.mask, lm.autoZwnj, lm.autoZwj, lm.perSyllable);
  final a = _Apply(c, gpos, table, m);
  if (!gpos && lookup.type == 8) {
    // reverse chaining: from the end, in place
    for (var i = c.buf.length - 1; i >= 0; i--) {
      final cur = c.buf[i];
      if ((cur.mask & lm.mask) == 0 || !m.checkGlyphProperty(cur, m.lookupProps)) continue;
      a.idx = i;
      for (final s in lookup.subtables) {
        if (s is! ReverseChainSubst) continue;
        final index = s.coverage!.index(cur.cp);
        if (index < 0 || index >= s.substitutes.length) continue;
        if (!a.matchBacktrack(s.backtrack.length, (k, g) => s.backtrack[k].covers(g))) continue;
        if (!a.matchLookahead(s.lookahead.length, (k, g) => s.lookahead[k].covers(g), i + 1)) continue;
        a.setGlyphClass(cur, s.substitutes[index]);
        cur.cp = s.substitutes[index];
        break;
      }
    }
    return;
  }
  a.idx = 0;
  while (a.idx < c.buf.length) {
    final cur = c.buf[a.idx];
    var applied = false;
    if ((cur.mask & lm.mask) != 0 && m.checkGlyphProperty(cur, m.lookupProps)) {
      applied = a.applyOnce(lookup);
    }
    if (!applied) a.idx++;
  }
}
