part of 'shaper.dart';

// Arabic script shaping ("Developing OpenType Fonts for Arabic Script"):
// joining analysis with the joining types of ArabicShaping.txt selects one
// of the positional features (isol, fina, medi, init) for every letter; the
// features are applied one stage at a time in the order of the
// specification, then rlig (lam-alef), calt, liga; GPOS mark positioning
// with mark advances zeroed afterwards.

const _arabicFeatures = ['isol', 'fina', 'fin2', 'fin3', 'medi', 'med2', 'init'];
const _aIsol = 0, _aFina = 1, _aFin2 = 2, _aFin3 = 3, _aMedi = 4, _aMed2 = 5, _aInit = 6, _aNone = 7;

/// Joining state machine: [state][joining type column] = (action for the
/// previous letter, action for this letter, next state). Columns: U, L, R,
/// D, Alaph, Dalath-Rish (the last two only occur in Syriac).
const _arabicStates = <List<(int, int, int)>>[
  // 0: previous letter was U, not willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aNone, _aIsol, 1), (_aNone, _aIsol, 2), (_aNone, _aIsol, 1), (_aNone, _aIsol, 6)],
  // 1: previous was R or isolated Alaph, not willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aNone, _aIsol, 1), (_aNone, _aIsol, 2), (_aNone, _aFin2, 5), (_aNone, _aIsol, 6)],
  // 2: previous was D or L in isolated form, willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aInit, _aFina, 1), (_aInit, _aFina, 3), (_aInit, _aFina, 4), (_aInit, _aFina, 6)],
  // 3: previous was D in final form, willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aMedi, _aFina, 1), (_aMedi, _aFina, 3), (_aMedi, _aFina, 4), (_aMedi, _aFina, 6)],
  // 4: previous was final Alaph, not willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aMed2, _aIsol, 1), (_aMed2, _aIsol, 2), (_aMed2, _aFin2, 5), (_aMed2, _aIsol, 6)],
  // 5: previous was fin2/fin3 Alaph, not willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aIsol, _aIsol, 1), (_aIsol, _aIsol, 2), (_aIsol, _aFin2, 5), (_aIsol, _aIsol, 6)],
  // 6: previous was Dalath or Rish, not willing to join
  [(_aNone, _aNone, 0), (_aNone, _aIsol, 2), (_aNone, _aIsol, 1), (_aNone, _aIsol, 2), (_aNone, _aFin3, 5), (_aNone, _aIsol, 6)],
];

void _collectArabicFeatures(_PlanBuilder b) {
  b.enable('stch');
  b.pauseGsub();
  b.enable('ccmp', _fManualZwj);
  b.enable('locl', _fManualZwj);
  b.pauseGsub();
  for (final f in _arabicFeatures) {
    // the Syriac-only forms (fin2, fin3, med2) have no fallback
    final syriac = f.endsWith('2') || f.endsWith('3');
    b.add(f, _fManualZwj | (syriac ? 0 : _fHasFallback));
    b.pauseGsub();
  }
  b.pauseGsub();
  b.enable('rlig', _fManualZwj | _fHasFallback);
  b.pauseGsub();
  b.enable('calt', _fManualZwj);
  if (!b.hasFeature('rclt')) b.pauseGsub();
  b.enable('liga', _fManualZwj);
  b.enable('clig', _fManualZwj);
  b.enable('mset', _fManualZwj);
}

void _setupArabicMasks(_Ctx c) {
  final buf = c.buf;
  var prev = -1, state = 0;
  for (var i = 0; i < buf.length; i++) {
    final t = joiningType(buf[i].cp);
    if (t == Joining.t) {
      buf[i].pos = _aNone;
      continue;
    }
    final entry = _arabicStates[state][t];
    if (entry.$1 != _aNone && prev >= 0) buf[prev].pos = entry.$1;
    buf[i].pos = entry.$2;
    prev = i;
    state = entry.$3;
  }
  final masks = [for (final f in _arabicFeatures) c.plan.mask(f), 0];
  for (final i in buf) {
    i.mask |= masks[i.pos];
  }
}

/// Modifier combining marks (UAX #53): kept next to their base when marks are reordered.
const _modifierCombiningMarks = {0x0654, 0x0655, 0x0658, 0x06DC, 0x06E3, 0x06E7, 0x06E8, 0x08CA, 0x08CB, 0x08CD, 0x08CE, 0x08CF, 0x08D3, 0x08F3};

/// Moves the modifier combining marks of classes 220 and 230 to the start of
/// the mark sequence [start, end) (UAX #53 "Arabic Mark Rendering").
void _reorderArabicMarks(List<_Info> buf, int start, int end) {
  int cc(_Info i) => i.isUnicodeMark ? i.ccc : 0;
  var i = start;
  for (var klass = 220; klass <= 230; klass += 10) {
    while (i < end && cc(buf[i]) < klass) {
      i++;
    }
    if (i == end) break;
    if (cc(buf[i]) > klass) continue;
    var j = i;
    while (j < end && cc(buf[j]) == klass && _modifierCombiningMarks.contains(buf[j].cp)) {
      j++;
    }
    if (i == j) continue;
    _mergeClusters(buf, start, j);
    final moved = buf.sublist(i, j);
    final before = buf.sublist(start, i);
    buf.setRange(start, start + moved.length, moved);
    buf.setRange(start + moved.length, j, before);
    final newStart = start + j - i;
    final newCc = klass == 220 ? 25 : 26;
    while (start < newStart) {
      if (buf[start].isUnicodeMark) buf[start].ccc = newCc;
      start++;
    }
    i = j;
  }
}
