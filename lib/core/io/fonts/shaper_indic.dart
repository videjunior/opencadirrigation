part of 'shaper.dart';

// Indic shaping (the "Developing OpenType Fonts for Devanagari / Bengali /
// Gurmukhi / Telugu Script" documents, OpenType new-spec script tags dev2,
// bng2, gur2, tel2): characters are grouped into syllables, the base
// consonant is found, pre-base matras, reph and pre-base-reordering forms
// are moved to their visual positions, the basic shaping features (nukt,
// akhn, rphf, rkrf, pref, blwf, abvf, half, pstf, vatu, cjct) are applied
// one by one within each syllable, matras and reph get their final
// positions, then the presentation features (init, pres, abvs, blws,
// psts, haln, calt) and GPOS (abvm, blwm, dist, kern, mark).

// syllabic categories (indexes of the generated indicCategoryNames)
const _cC = 1, _cV = 2, _cN = 3, _cH = 4, _cZWNJ = 5, _cZWJ = 6, _cM = 7, _cSM = 8, _cA = 9, _cPlaceholder = 10, _cDottedCircle = 11, _cRS = 12, _cMPst = 13;
const _cRepha = 14, _cRa = 15, _cCM = 16, _cSymbol = 17, _cCS = 18, _cSMPst = 19;

// positions (indexes of the generated indicPositionNames)
const _pStart = 0, _pRaToBecomeReph = 1, _pPreM = 2, _pPreC = 3, _pBaseC = 4, _pAfterMain = 5, _pBeforeSub = 7, _pBelowC = 8, _pAfterSub = 9, _pBeforePost = 10;
const _pPostC = 11, _pAfterPost = 12, _pSmvd = 13, _pEnd = 14;

// syllable types
const _sConsonant = 0, _sVowel = 1, _sStandalone = 2, _sSymbol = 3, _sBroken = 4, _sNonIndic = 5;

const _rephImplicit = 0, _rephExplicit = 1;

int _flag(int cat) => 1 << cat;
final int _consonantFlags = _flag(_cC) | _flag(_cCS) | _flag(_cRa) | _flag(_cCM) | _flag(_cV) | _flag(_cPlaceholder) | _flag(_cDottedCircle);
final int _joinerFlags = _flag(_cZWJ) | _flag(_cZWNJ);

bool _isOneOf(_Info i, int flags) => !i.ligated && (_flag(i.cat) & flags) != 0;
bool _isConsonant(_Info i) => _isOneOf(i, _consonantFlags);
bool _isJoiner(_Info i) => _isOneOf(i, _joinerFlags);
bool _isHalant(_Info i) => _isOneOf(i, _flag(_cH));

class _IndicConfig {
  const _IndicConfig(this.virama, this.rephPos, this.rephMode, this.blwfPreAndPost);
  final int virama;
  final int rephPos;
  final int rephMode;
  final bool blwfPreAndPost;
}

const _indicConfigs = <int, _IndicConfig>{
  Script.devanagari: _IndicConfig(0x094D, _pBeforePost, _rephImplicit, true),
  Script.bengali: _IndicConfig(0x09CD, _pAfterSub, _rephImplicit, true),
  Script.gurmukhi: _IndicConfig(0x0A4D, _pBeforeSub, _rephImplicit, true),
  Script.telugu: _IndicConfig(0x0C4D, _pAfterPost, _rephExplicit, false),
};

class _IndicPlan {
  _IndicPlan(this.font, _Plan plan, int script)
      : config = _indicConfigs[script]!,
        rphf = plan.mask('rphf'),
        pref = plan.mask('pref'),
        blwf = plan.mask('blwf'),
        abvf = plan.mask('abvf'),
        half = plan.mask('half'),
        pstf = plan.mask('pstf'),
        init = plan.mask('init'),
        _stageLookups = {for (final t in const ['rphf', 'pref', 'blwf', 'pstf', 'vatu']) t: _lookupsOf(plan, t)};

  final ShapingFont font;
  final _IndicConfig config;
  final int rphf, pref, blwf, abvf, half, pstf, init;
  final Map<String, List<int>> _stageLookups;
  final Map<int, int> _positionCache = {};
  late final int viramaGlyph = font.glyphOf(config.virama);

  /// Lookups of the GSUB stage of [tag] (each basic feature has its own stage).
  static List<int> _lookupsOf(_Plan plan, String tag) {
    final stage = plan.featureStage[tag];
    if (stage == null || stage >= plan.gsubStages.length) return const [];
    return [for (final l in plan.gsubStages[stage].lookups) l.index];
  }

  /// Whether a lookup of [feature]'s stage would substitute [glyphs] (no context allowed).
  bool wouldSubstitute(String feature, List<int> glyphs) {
    for (final li in _stageLookups[feature]!) {
      if (_lookupWouldSubstitute(font, li, glyphs, true)) return true;
    }
    return false;
  }

  /// Position of a consonant from the font: below-base or post-base when
  /// its halant forms are substituted by blwf/vatu or pstf/pref.
  int consonantPosition(int consonant) => _positionCache[consonant] ??= () {
    final v = viramaGlyph;
    final a = [v, consonant], b = [consonant, v];
    if (wouldSubstitute('blwf', a) || wouldSubstitute('blwf', b) || wouldSubstitute('vatu', a) || wouldSubstitute('vatu', b)) return _pBelowC;
    if (wouldSubstitute('pstf', a) || wouldSubstitute('pstf', b)) return _pPostC;
    if (wouldSubstitute('pref', a) || wouldSubstitute('pref', b)) return _pPostC;
    return _pBaseC;
  }();
}

/// Whether GSUB lookup [index] would apply to [glyphs] at their start.
bool _lookupWouldSubstitute(ShapingFont font, int index, List<int> glyphs, bool zeroContext) {
  if (glyphs.isEmpty) return false;
  final l = font.gsub?.lookup(index);
  if (l == null || !font._digest(index).mayHave(glyphs[0])) return false;
  final g0 = glyphs[0], len = glyphs.length;
  for (final s in l.subtables) {
    switch (s) {
      case SingleSubst() || MultipleSubst() || AlternateSubst() || ReverseChainSubst():
        if (len == 1 && s.coverage!.covers(g0)) return true;
      case LigatureSubst t:
        final i = t.coverage!.index(g0);
        if (i < 0 || i >= t.sets.length) break;
        for (final lig in t.sets[i]) {
          if (lig.components.length + 1 != len) continue;
          var ok = true;
          for (var k = 1; k < len; k++) {
            if (glyphs[k] != lig.components[k - 1]) ok = false;
          }
          if (ok) return true;
        }
      case ContextSubtable t:
        if (t.format == 3) {
          if (t.coverages.length != len) break;
          var ok = true;
          for (var k = 1; k < len; k++) {
            if (!t.coverages[k].covers(glyphs[k])) ok = false;
          }
          if (ok) return true;
          break;
        }
        final setIndex = t.format == 1 ? t.coverage!.index(g0) : t.classDef!.classOf(g0);
        if (setIndex < 0 || setIndex >= t.ruleSets.length) break;
        for (final r in t.ruleSets[setIndex] ?? const <ContextRule>[]) {
          if (r.input.length + 1 != len) continue;
          var ok = true;
          for (var k = 1; k < len; k++) {
            if ((t.format == 1 ? glyphs[k] : t.classDef!.classOf(glyphs[k])) != r.input[k - 1]) ok = false;
          }
          if (ok) return true;
        }
      case ChainContextSubtable t:
        if (t.format == 3) {
          if (zeroContext && (t.backtrackCoverages.isNotEmpty || t.lookaheadCoverages.isNotEmpty)) break;
          if (t.inputCoverages.length != len) break;
          var ok = true;
          for (var k = 1; k < len; k++) {
            if (!t.inputCoverages[k].covers(glyphs[k])) ok = false;
          }
          if (ok) return true;
          break;
        }
        final setIndex = t.format == 1 ? t.coverage!.index(g0) : t.inputClassDef!.classOf(g0);
        if (setIndex < 0 || setIndex >= t.ruleSets.length) break;
        for (final r in t.ruleSets[setIndex] ?? const <ChainRule>[]) {
          if (zeroContext && (r.backtrack.isNotEmpty || r.lookahead.isNotEmpty)) continue;
          if (r.input.length + 1 != len) continue;
          var ok = true;
          for (var k = 1; k < len; k++) {
            if ((t.format == 1 ? glyphs[k] : t.inputClassDef!.classOf(glyphs[k])) != r.input[k - 1]) ok = false;
          }
          if (ok) return true;
        }
      default:
        break;
    }
  }
  return false;
}

void _collectIndicFeatures(_PlanBuilder b) {
  b.pauseGsub(_setupSyllables);
  b.enable('locl', _fPerSyllable);
  b.enable('ccmp', _fPerSyllable);
  b.pauseGsub(_initialReordering);
  const basic = [
    ('nukt', _fGlobal), ('akhn', _fGlobal), ('rphf', 0), ('rkrf', _fGlobal), ('pref', 0), ('blwf', 0), ('abvf', 0), ('half', 0), ('pstf', 0), ('vatu', _fGlobal),
    ('cjct', _fGlobal),
  ];
  for (final (tag, f) in basic) {
    b.add(tag, f | _fManualJoiners | _fPerSyllable);
    b.pauseGsub();
  }
  b.pauseGsub(_finalReordering);
  const other = [('init', 0), ('pres', _fGlobal), ('abvs', _fGlobal), ('blws', _fGlobal), ('psts', _fGlobal), ('haln', _fGlobal)];
  for (final (tag, f) in other) {
    b.add(tag, f | _fManualJoiners | _fPerSyllable);
  }
}

void _setupIndicMasks(_Ctx c) {
  for (final i in c.buf) {
    final (cat, pos) = indicProperties(i.cp);
    i.cat = cat;
    i.pos = pos;
  }
}

/// Invalid vowel sequences (a vowel letter followed by a vowel sign that
/// makes it look like another vowel letter) get a dotted circle between
/// them, as in the Unicode "do not use" tables of the Indic scripts.
const _vowelConstraints = <int, Map<int, Set<int>>>{
  Script.devanagari: {
    0x0905: {0x093A, 0x093B, 0x093E, 0x0945, 0x0946, 0x0949, 0x094A, 0x094B, 0x094C, 0x094F, 0x0956, 0x0957},
    0x0906: {0x093A, 0x0945, 0x0946, 0x0947, 0x0948},
    0x0909: {0x0941},
    0x090F: {0x0945, 0x0946, 0x0947},
  },
  Script.bengali: {
    0x0985: {0x09BE},
    0x098B: {0x09C3},
    0x098C: {0x09E2},
  },
  Script.gurmukhi: {
    0x0A05: {0x0A3E, 0x0A48, 0x0A4C},
    0x0A72: {0x0A3F, 0x0A40, 0x0A47},
    0x0A73: {0x0A41, 0x0A42, 0x0A4B},
  },
  Script.telugu: {
    0x0C12: {0x0C4C, 0x0C55},
    0x0C3F: {0x0C55},
    0x0C46: {0x0C55},
    0x0C4A: {0x0C55},
  },
};

void _indicVowelConstraints(_Ctx c) {
  final table = _vowelConstraints[c.script];
  if (table == null) return;
  final buf = c.buf;
  final out = <_Info>[];
  var i = 0;
  while (i + 1 < buf.length) {
    final cur = buf[i];
    var matched = false;
    final seconds = table[cur.cp];
    if (seconds != null && seconds.contains(buf[i + 1].cp)) matched = true;
    if (c.script == Script.devanagari && cur.cp == 0x0930 && buf[i + 1].cp == 0x094D && i + 2 < buf.length && buf[i + 2].cp == 0x0907) {
      out.add(cur);
      i++;
      matched = true;
    }
    out.add(buf[i]);
    i++;
    if (matched) {
      // the dotted circle takes the place (and the properties) of the vowel sign
      final dc = buf[i].copy()..cp = 0x25CC;
      dc.uflags &= ~_U.continuation;
      out.add(dc);
      out.add(buf[i]);
      i++;
    }
  }
  while (i < buf.length) {
    out.add(buf[i++]);
  }
  c.buf = out;
}

// ------------------------------------------------------------ syllables

/// Regular expressions over syllabic categories, compiled to one NFA that
/// finds the longest syllable at each position (earlier patterns win ties).
class _Nfa {
  final List<List<(int, int)>> edges = []; // (category or -1 for epsilon, target)
  final Map<int, int> accept = {}; // state → pattern

  int state() {
    edges.add([]);
    return edges.length - 1;
  }

  void edge(int from, int sym, int to) => edges[from].add((sym, to));
}

sealed class _Re {
  const _Re();

  /// Adds this expression between [from] and a new state, returned.
  int build(_Nfa n, int from);
}

class _Sym extends _Re {
  const _Sym(this.cats);
  final List<int> cats;
  @override
  int build(_Nfa n, int from) {
    final to = n.state();
    for (final c in cats) {
      n.edge(from, c, to);
    }
    return to;
  }
}

class _Seq extends _Re {
  const _Seq(this.parts);
  final List<_Re> parts;
  @override
  int build(_Nfa n, int from) {
    var s = from;
    for (final p in parts) {
      s = p.build(n, s);
    }
    return s;
  }
}

class _Alt extends _Re {
  const _Alt(this.alts);
  final List<_Re> alts;
  @override
  int build(_Nfa n, int from) {
    final to = n.state();
    for (final a in alts) {
      final s = n.state();
      n.edge(from, -1, s);
      n.edge(a.build(n, s), -1, to);
    }
    return to;
  }
}

class _Star extends _Re {
  const _Star(this.r);
  final _Re r;
  @override
  int build(_Nfa n, int from) {
    final loop = n.state();
    n.edge(from, -1, loop);
    final s = n.state();
    n.edge(loop, -1, s);
    n.edge(r.build(n, s), -1, loop);
    return loop;
  }
}

class _Opt extends _Re {
  const _Opt(this.r);
  final _Re r;
  @override
  int build(_Nfa n, int from) {
    final to = n.state();
    n.edge(from, -1, to);
    final s = n.state();
    n.edge(from, -1, s);
    n.edge(r.build(n, s), -1, to);
    return to;
  }
}

_Re _s(List<int> cats) => _Sym(cats);
_Re _q(_Re r) => _Opt(r);
_Re _seq(List<_Re> p) => _Seq(p);
_Re _or(List<_Re> a) => _Alt(a);
_Re _star(_Re r) => _Star(r);

final _Nfa _syllableNfa = () {
  final c = _s([_cC, _cRa]);
  final n = _seq([_q(_seq([_q(_s([_cZWNJ])), _s([_cRS])])), _q(_seq([_s([_cN]), _q(_s([_cN]))]))]);
  final z = _s([_cZWJ, _cZWNJ]);
  final reph = _or([_seq([_s([_cRa]), _s([_cH])]), _s([_cRepha])]);
  final sm = _s([_cSM, _cSMPst]);
  final cn = _seq([c, _q(_s([_cZWJ])), _q(n)]);
  final symbol = _seq([_s([_cSymbol]), _q(_s([_cN]))]);
  final matraGroup = _seq([_star(z), _or([_s([_cM]), _seq([_q(sm), _s([_cMPst])])]), _q(_s([_cN])), _q(_s([_cH]))]);
  final syllableTail = _seq([_q(_seq([_q(z), sm, _q(sm), _q(_s([_cZWNJ]))])), _star(_s([_cA]))]);
  final halantGroup = _seq([_q(z), _s([_cH]), _q(_seq([_s([_cZWJ]), _q(_s([_cN]))]))]);
  final finalHalantGroup = _or([halantGroup, _seq([_s([_cH]), _s([_cZWNJ])])]);
  final medialGroup = _q(_s([_cCM]));
  final halantOrMatraGroup = _or([finalHalantGroup, _star(matraGroup)]);
  final complexTail = _seq([_star(_seq([halantGroup, cn])), medialGroup, halantOrMatraGroup, syllableTail]);
  final consonantSyllable = _seq([_q(_s([_cRepha, _cCS])), cn, complexTail]);
  final vowelSyllable = _seq([_q(reph), _s([_cV]), _q(n), _or([_s([_cZWJ]), complexTail])]);
  final standalone = _seq([
    _or([_seq([_q(_s([_cRepha, _cCS])), _s([_cPlaceholder])]), _seq([_q(reph), _s([_cDottedCircle])])]),
    _q(n),
    complexTail,
  ]);
  final symbolCluster = _seq([symbol, syllableTail]);
  final broken = _seq([_q(reph), _q(n), complexTail]);
  final any = _s(List<int>.generate(32, (i) => i));
  // patterns in priority order with their syllable types
  final patterns = [consonantSyllable, vowelSyllable, standalone, symbolCluster, _s([_cSMPst]), broken, any];
  final nfa = _Nfa();
  final start = nfa.state();
  for (var i = 0; i < patterns.length; i++) {
    final s = nfa.state();
    nfa.edge(start, -1, s);
    nfa.accept[patterns[i].build(nfa, s)] = i;
  }
  return nfa;
}();

const _patternTypes = [_sConsonant, _sVowel, _sStandalone, _sSymbol, _sNonIndic, _sBroken, _sNonIndic];

Set<int> _closure(Set<int> states) {
  final out = {...states};
  final todo = [...states];
  while (todo.isNotEmpty) {
    final s = todo.removeLast();
    for (final (sym, to) in _syllableNfa.edges[s]) {
      if (sym == -1 && out.add(to)) todo.add(to);
    }
  }
  return out;
}

void _setupSyllables(_Ctx c) {
  final buf = c.buf;
  var serial = 1;
  var p = 0;
  while (p < buf.length) {
    var states = _closure({0});
    var bestLen = 0, bestPattern = 6;
    for (var k = p; k <= buf.length; k++) {
      for (final s in states) {
        final pat = _syllableNfa.accept[s];
        if (pat != null && k - p > 0 && (k - p > bestLen || (k - p == bestLen && pat < bestPattern))) {
          bestLen = k - p;
          bestPattern = pat;
        }
      }
      if (k == buf.length) break;
      final cat = buf[k].cat;
      final next = <int>{};
      for (final s in states) {
        for (final (sym, to) in _syllableNfa.edges[s]) {
          if (sym == cat) next.add(to);
        }
      }
      if (next.isEmpty) break;
      states = _closure(next);
    }
    if (bestLen == 0) bestLen = 1;
    final type = _patternTypes[bestPattern];
    if (type == _sBroken) c.hasBrokenSyllable = true;
    for (var k = p; k < p + bestLen; k++) {
      buf[k].syllable = (serial << 4) | type;
    }
    serial++;
    if (serial == 16) serial = 1;
    p += bestLen;
  }
}

Iterable<(int, int)> _syllableRanges(List<_Info> buf) sync* {
  var start = 0;
  while (start < buf.length) {
    var end = start + 1;
    while (end < buf.length && buf[end].syllable == buf[start].syllable) {
      end++;
    }
    yield (start, end);
    start = end;
  }
}

// ------------------------------------------------------------ initial reordering

void _initialReordering(_Ctx c) {
  final ip = c.plan.indic!;
  // consonant positions from the font's below-base / post-base forms
  if (ip.viramaGlyph != 0) {
    for (final i in c.buf) {
      if (i.pos == _pBaseC) i.pos = ip.consonantPosition(i.cp);
    }
  }
  if (c.hasBrokenSyllable) _insertDottedCircles(c);
  final ranges = _syllableRanges(c.buf).toList();
  for (final (start, end) in ranges) {
    final type = c.buf[start].syllable & 0x0F;
    if (type == _sConsonant || type == _sVowel || type == _sStandalone || type == _sBroken) _reorderConsonantSyllable(c, ip, start, end);
  }
}

void _insertDottedCircles(_Ctx c) {
  final glyph = c.font.glyphOf(0x25CC);
  if (glyph == 0) return;
  final buf = c.buf;
  final out = <_Info>[];
  var last = 0;
  var i = 0;
  while (i < buf.length) {
    final syl = buf[i].syllable;
    if (last != syl && (syl & 0x0F) == _sBroken) {
      last = syl;
      final dc = _Info(glyph, buf[i].cluster)
        ..mask = buf[i].mask
        ..syllable = syl
        ..cat = _cDottedCircle
        ..pos = _pEnd
        ..gc = Gc.control;
      while (i < buf.length && buf[i].syllable == last && buf[i].cat == _cRepha) {
        out.add(buf[i++]);
      }
      out.add(dc);
    } else {
      out.add(buf[i++]);
    }
  }
  c.buf = out;
}

void _stableSortByPos(List<_Info> buf, int start, int end) {
  for (var i = start + 1; i < end; i++) {
    final t = buf[i];
    var j = i;
    while (j > start && buf[j - 1].pos > t.pos) {
      buf[j] = buf[j - 1];
      j--;
    }
    buf[j] = t;
  }
}

void _reverseRange(List<_Info> buf, int start, int end) {
  for (var a = start, b = end - 1; a < b; a++, b--) {
    final t = buf[a];
    buf[a] = buf[b];
    buf[b] = t;
  }
}

void _reorderConsonantSyllable(_Ctx c, _IndicPlan ip, int start, int end) {
  final buf = c.buf;
  final cfg = ip.config;
  var base = end;
  var hasReph = false;
  var limit = start;
  if (ip.rphf != 0 && start + 3 <= end && ((cfg.rephMode == _rephImplicit && !_isJoiner(buf[start + 2])) || (cfg.rephMode == _rephExplicit && buf[start + 2].cat == _cZWJ))) {
    final glyphs = [buf[start].cp, buf[start + 1].cp];
    if (ip.wouldSubstitute('rphf', glyphs) || (cfg.rephMode == _rephExplicit && ip.wouldSubstitute('rphf', [...glyphs, buf[start + 2].cp]))) {
      limit += 2;
      while (limit < end && _isJoiner(buf[limit])) {
        limit++;
      }
      base = start;
      hasReph = true;
    }
  }
  // find the base consonant: from the end, the first consonant without a
  // below-base or post-base form
  {
    var i = end;
    var seenBelow = false;
    do {
      i--;
      if (_isConsonant(buf[i])) {
        if (buf[i].pos != _pBelowC && (buf[i].pos != _pPostC || seenBelow)) {
          base = i;
          break;
        }
        if (buf[i].pos == _pBelowC) seenBelow = true;
        base = i;
      } else if (start < i && buf[i].cat == _cZWJ && buf[i - 1].cat == _cH) {
        // halant + ZWJ requests an explicit half form: stop
        break;
      }
    } while (i > limit);
  }
  if (hasReph && base == start && limit - base <= 2) hasReph = false;

  for (var i = start; i < base; i++) {
    if (buf[i].pos > _pPreC) buf[i].pos = _pPreC;
  }
  if (base < end) buf[base].pos = _pBaseC;
  if (hasReph) buf[start].pos = _pRaToBecomeReph;

  // marks and joiners move with the preceding character
  {
    var lastPos = _pStart;
    for (var i = start; i < end; i++) {
      final cat = buf[i].cat;
      if ((_flag(cat) & (_joinerFlags | _flag(_cN) | _flag(_cRS) | _flag(_cCM) | _flag(_cH))) != 0) {
        buf[i].pos = lastPos;
        if (cat == _cH && buf[i].pos == _pPreM) {
          // a halant does not move with a left matra
          for (var j = i; j > start; j--) {
            if (buf[j - 1].pos != _pPreM) {
              buf[i].pos = buf[j - 1].pos;
              break;
            }
          }
        }
      } else if (buf[i].pos != _pSmvd) {
        if (cat == _cMPst && i > start && buf[i - 1].cat == _cSM) buf[i - 1].pos = buf[i].pos;
        lastPos = buf[i].pos;
      }
    }
  }
  // post-base consonants own what comes before them since the last consonant or matra
  {
    var last = base;
    for (var i = base + 1; i < end; i++) {
      if (_isConsonant(buf[i])) {
        for (var j = last + 1; j < i; j++) {
          if (buf[j].pos < _pSmvd) buf[j].pos = buf[i].pos;
        }
        last = i;
      } else if (buf[i].cat == _cM || buf[i].cat == _cMPst) {
        last = i;
      }
    }
  }
  {
    final syllable = buf[start].syllable;
    for (var i = start; i < end; i++) {
      buf[i].syllable = i - start;
    }
    _stableSortByPos(buf, start, end);
    var firstLeftMatra = end, lastLeftMatra = end;
    base = end;
    for (var i = start; i < end; i++) {
      if (buf[i].pos == _pBaseC) {
        base = i;
        break;
      } else if (buf[i].pos == _pPreM) {
        if (firstLeftMatra == end) firstLeftMatra = i;
        lastLeftMatra = i;
      }
    }
    if (firstLeftMatra < lastLeftMatra) {
      // several left matras: keep them in logical order
      _reverseRange(buf, firstLeftMatra, lastLeftMatra + 1);
      var i = firstLeftMatra;
      for (var j = i; j <= lastLeftMatra; j++) {
        if (buf[j].cat == _cM || buf[j].cat == _cMPst) {
          _reverseRange(buf, i, j + 1);
          i = j + 1;
        }
      }
    }
    if (end - start > 127) {
      _mergeClusters(buf, base, end);
    } else {
      for (var i = base; i < end; i++) {
        if (buf[i].syllable != 255) {
          var lo = i, hi = i;
          var j = start + buf[i].syllable;
          while (j != i) {
            if (j < lo) lo = j;
            if (j > hi) hi = j;
            final next = start + buf[j].syllable;
            buf[j].syllable = 255;
            j = next;
          }
          _mergeClusters(buf, base > lo ? base : lo, hi + 1);
        }
      }
    }
    for (var i = start; i < end; i++) {
      buf[i].syllable = syllable;
    }
  }
  // feature masks
  for (var i = start; i < end && buf[i].pos == _pRaToBecomeReph; i++) {
    buf[i].mask |= ip.rphf;
  }
  var mask = ip.half;
  if (cfg.blwfPreAndPost) mask |= ip.blwf;
  for (var i = start; i < base; i++) {
    buf[i].mask |= mask;
  }
  mask = ip.blwf | ip.abvf | ip.pstf;
  for (var i = base + 1; i < end; i++) {
    buf[i].mask |= mask;
  }
  if (ip.pref != 0 && base + 2 < end) {
    for (var i = base + 1; i + 1 < end; i++) {
      if (ip.wouldSubstitute('pref', [buf[i].cp, buf[i + 1].cp])) {
        buf[i].mask |= ip.pref;
        buf[i + 1].mask |= ip.pref;
        break;
      }
    }
  }
  // ZWNJ disables the half forms before it
  for (var i = start + 1; i < end; i++) {
    if (_isJoiner(buf[i])) {
      final nonJoiner = buf[i].cat == _cZWNJ;
      var j = i;
      do {
        j--;
        if (nonJoiner) buf[j].mask &= ~ip.half;
      } while (j > start && !_isConsonant(buf[j]));
    }
  }
}

// ------------------------------------------------------------ final reordering

void _finalReordering(_Ctx c) {
  final ip = c.plan.indic!;
  for (final (start, end) in _syllableRanges(c.buf).toList()) {
    _finalReorderSyllable(c, ip, start, end);
  }
}

void _moveInfo(List<_Info> buf, int from, int to) {
  final t = buf[from];
  if (from < to) {
    for (var k = from; k < to; k++) {
      buf[k] = buf[k + 1];
    }
  } else {
    for (var k = from; k > to; k--) {
      buf[k] = buf[k - 1];
    }
  }
  buf[to] = t;
}

void _finalReorderSyllable(_Ctx c, _IndicPlan ip, int start, int end) {
  final buf = c.buf;
  final virama = ip.viramaGlyph;
  if (virama != 0) {
    for (var i = start; i < end; i++) {
      if (buf[i].cp == virama && buf[i].ligated && buf[i].multiplied) {
        buf[i].cat = _cH;
        buf[i].glyphProps &= ~(_G.ligated | _G.multiplied);
      }
    }
  }
  var tryPref = ip.pref != 0;
  var base = start;
  for (; base < end; base++) {
    if (buf[base].pos >= _pBaseC) {
      if (tryPref && base + 1 < end) {
        for (var i = base + 1; i < end; i++) {
          if (buf[i].mask & ip.pref != 0) {
            if (!(buf[i].substituted && buf[i].ligatedAndDidntMultiply)) {
              // a pref candidate that did not form: the base is around here
              base = i;
              while (base < end && _isHalant(buf[base])) {
                base++;
              }
              if (base < end) buf[base].pos = _pBaseC;
              tryPref = false;
            }
            break;
          }
        }
        if (base == end) break;
      }
      if (start < base && buf[base].pos > _pBaseC) base--;
      break;
    }
  }
  if (base == end && start < base && _isOneOf(buf[base - 1], _flag(_cZWJ))) base--;
  if (base < end) {
    while (start < base && _isOneOf(buf[base], _flag(_cN) | _flag(_cH))) {
      base--;
    }
  }

  // pre-base matras: after the last standalone halant before the base
  if (start + 1 < end && start < base) {
    var newPos = base == end ? base - 2 : base - 1;
    while (true) {
      while (newPos > start && !_isOneOf(buf[newPos], _flag(_cM) | _flag(_cMPst) | _flag(_cH))) {
        newPos--;
      }
      if (_isHalant(buf[newPos]) && buf[newPos].pos != _pPreM) {
        if (newPos + 1 < end && buf[newPos + 1].cat == _cZWJ && newPos > start) {
          // halant + ZWJ: keep looking
          newPos--;
          continue;
        }
      } else {
        newPos = start;
      }
      break;
    }
    if (start < newPos && buf[newPos].pos != _pPreM) {
      for (var i = newPos; i > start; i--) {
        if (buf[i - 1].pos == _pPreM) {
          final oldPos = i - 1;
          if (oldPos < base && base <= newPos) base--;
          _moveInfo(buf, oldPos, newPos);
          _mergeClusters(buf, newPos, end < base + 1 ? end : base + 1);
          newPos--;
        }
      }
    } else {
      for (var i = start; i < base; i++) {
        if (buf[i].pos == _pPreM) {
          _mergeClusters(buf, i, end < base + 1 ? end : base + 1);
          break;
        }
      }
    }
  }

  // reph
  if (start + 1 < end && buf[start].pos == _pRaToBecomeReph && ((buf[start].cat == _cRepha) != buf[start].ligatedAndDidntMultiply)) {
    final rephPos = ip.config.rephPos;
    int newRephPos;
    int step2or5() {
      var p = start + 1;
      while (p < base && !_isHalant(buf[p])) {
        p++;
      }
      if (p < base && _isHalant(buf[p])) {
        if (p + 1 < base && _isJoiner(buf[p + 1])) p++;
        return p;
      }
      return -1;
    }

    newRephPos = -1;
    if (rephPos != _pAfterPost) {
      newRephPos = step2or5();
      if (newRephPos < 0 && rephPos == _pAfterMain) {
        var p = base;
        while (p + 1 < end && buf[p + 1].pos <= _pAfterMain) {
          p++;
        }
        if (p < end) newRephPos = p;
      }
      if (newRephPos < 0 && rephPos == _pAfterSub) {
        var p = base;
        while (p + 1 < end && !(buf[p + 1].pos == _pPostC || buf[p + 1].pos == _pAfterPost || buf[p + 1].pos == _pSmvd)) {
          p++;
        }
        if (p < end) newRephPos = p;
      }
    }
    if (newRephPos < 0) newRephPos = step2or5();
    if (newRephPos < 0) {
      // step 6: end of the syllable, before syllable modifiers
      var p = end - 1;
      while (p > start && buf[p].pos == _pSmvd) {
        p--;
      }
      if (_isHalant(buf[p])) {
        for (var i = base + 1; i < p; i++) {
          if (buf[i].cat == _cM || buf[i].cat == _cMPst) p--;
        }
      }
      newRephPos = p;
    }
    _mergeClusters(buf, start, newRephPos + 1);
    _moveInfo(buf, start, newRephPos);
    if (start < base && base <= newRephPos) base--;
  }

  // pre-base-reordering consonants
  if (tryPref && base + 1 < end) {
    for (var i = base + 1; i < end; i++) {
      if (buf[i].mask & ip.pref != 0) {
        if (buf[i].ligatedAndDidntMultiply) {
          var newPos = base;
          while (newPos > start && !_isOneOf(buf[newPos - 1], _flag(_cM) | _flag(_cMPst) | _flag(_cH))) {
            newPos--;
          }
          if (newPos > start && _isHalant(buf[newPos - 1])) {
            if (newPos < end && _isJoiner(buf[newPos])) newPos++;
          }
          final oldPos = i;
          _mergeClusters(buf, newPos, oldPos + 1);
          _moveInfo(buf, oldPos, newPos);
          if (newPos <= base && base < oldPos) base++;
        }
        break;
      }
    }
  }

  // init on a left matra at the start of a word
  if (buf[start].pos == _pPreM) {
    if (start == 0) {
      buf[start].mask |= ip.init;
    } else {
      final g = buf[start - 1].gc;
      final wordish = g == Gc.format || g == Gc.unassigned || g == Gc.letter || g == Gc.spacingMark || g == Gc.enclosingMark || g == Gc.nonSpacingMark;
      if (!wordish) buf[start].mask |= ip.init;
    }
  }
}
