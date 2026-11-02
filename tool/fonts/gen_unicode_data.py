#!/usr/bin/env python3
"""Generates lib/core/io/fonts/unicode_data.dart, the Unicode character
properties the text shaper (lib/core/io/fonts/shaper.dart) and the
bidirectional algorithm (lib/core/io/fonts/bidi.dart) look up, from the
files of the Unicode Character Database:

    UnicodeData.txt             general category, combining class, bidi class, canonical decompositions
    CompositionExclusions.txt   characters never recomposed
    ArabicShaping.txt           joining types
    IndicSyllabicCategory.txt   Indic syllabic categories
    IndicPositionalCategory.txt Indic positional categories (matra placement)
    BidiMirroring.txt           mirrored glyph pairs (UAX #9 rule L4)
    BidiBrackets.txt            paired brackets (UAX #9 rule N0)
    Scripts.txt                 script of each character (text itemisation)

Download them from https://www.unicode.org/Public/UCD/latest/ucd/ into a
directory outside the repository and run, from the repository root:

    python3 -I tool/fonts/gen_unicode_data.py --ucd ~/tmp/ucd

Tables are lists of range starts with a value packed as start * base + value
(arithmetic only, so that they also decode in JavaScript), searched by
bisection. The Indic categories follow the OpenType Indic shaping model
(the "Developing OpenType fonts for Devanagari script" family of documents):
consonants, vowels, matras with their reordering position, virama, nukta,
syllable modifiers, joiners and placeholders.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'lib' / 'core' / 'io' / 'fonts' / 'unicode_data.dart'

# simplified general categories (only the distinctions the shaper makes)
GC = {'O': 0, 'Cc': 1, 'Cf': 2, 'Cn': 3, 'L': 4, 'Mc': 5, 'Me': 6, 'Mn': 7, 'Nd': 8, 'Zs': 9}
BIDI = ['L', 'R', 'AL', 'EN', 'ES', 'ET', 'AN', 'CS', 'NSM', 'BN', 'B', 'S', 'WS', 'ON', 'LRE', 'LRO', 'RLE', 'RLO', 'PDF', 'LRI', 'RLI', 'FSI', 'PDI']
JOINING = {'U': 0, 'L': 1, 'R': 2, 'D': 3, 'C': 3, 'T': 6}
SCRIPTS = ['Common', 'Inherited', 'Latin', 'Greek', 'Cyrillic', 'Arabic', 'Devanagari', 'Bengali', 'Gurmukhi', 'Telugu', 'Han', 'Hiragana', 'Katakana', 'Bopomofo',
           'Hangul', 'Hebrew', 'Thai', 'Other']

# Indic categories and positions (values shared with lib/core/io/fonts/indic.dart)
ICAT = ['X', 'C', 'V', 'N', 'H', 'ZWNJ', 'ZWJ', 'M', 'SM', 'A', 'PLACEHOLDER', 'DOTTEDCIRCLE', 'RS', 'MPst', 'Repha', 'Ra', 'CM', 'Symbol', 'CS', 'SMPst', 'VS']
IPOS = ['START', 'RA_TO_BECOME_REPH', 'PRE_M', 'PRE_C', 'BASE_C', 'AFTER_MAIN', 'ABOVE_C', 'BEFORE_SUB', 'BELOW_C', 'AFTER_SUB', 'BEFORE_POST', 'POST_C', 'AFTER_POST',
        'SMVD', 'END']
INDIC_BLOCKS = [(0x0900, 0x097F, 'Devanagari'), (0x0980, 0x09FF, 'Bengali'), (0x0A00, 0x0A7F, 'Gurmukhi'), (0x0A80, 0x0AFF, 'Gujarati'), (0x0B00, 0x0B7F, 'Oriya'),
                (0x0B80, 0x0BFF, 'Tamil'), (0x0C00, 0x0C7F, 'Telugu'), (0x0C80, 0x0CFF, 'Kannada'), (0x0D00, 0x0D7F, 'Malayalam'), (0x1CD0, 0x1CFF, 'Vedic'),
                (0xA8E0, 0xA8FF, 'Devanagari')]
CATEGORY_MAP = {
    'Other': 'X', 'Avagraha': 'Symbol', 'Bindu': 'SM', 'Brahmi_Joining_Number': 'PLACEHOLDER', 'Cantillation_Mark': 'A', 'Consonant': 'C', 'Consonant_Dead': 'C',
    'Consonant_Final': 'CM', 'Consonant_Head_Letter': 'C', 'Consonant_Initial_Postfixed': 'C', 'Consonant_Killer': 'M', 'Consonant_Medial': 'CM',
    'Consonant_Placeholder': 'PLACEHOLDER', 'Consonant_Preceding_Repha': 'Repha', 'Consonant_Prefixed': 'X', 'Consonant_Subjoined': 'CM',
    'Consonant_Succeeding_Repha': 'CM', 'Consonant_With_Stacker': 'CS', 'Gemination_Mark': 'SM', 'Invisible_Stacker': 'H', 'Joiner': 'ZWJ', 'Modifying_Letter': 'X',
    'Non_Joiner': 'ZWNJ', 'Nukta': 'N', 'Number': 'PLACEHOLDER', 'Number_Joiner': 'PLACEHOLDER', 'Pure_Killer': 'M', 'Register_Shifter': 'RS',
    'Syllable_Modifier': 'SM', 'Tone_Letter': 'X', 'Tone_Mark': 'N', 'Virama': 'H', 'Visarga': 'SM', 'Vowel': 'V', 'Vowel_Dependent': 'M', 'Vowel_Independent': 'V',
    'Reordering_Killer': 'M',
}
POSITION_MAP = {
    'Not_Applicable': 'END', 'Left': 'PRE_C', 'Top': 'ABOVE_C', 'Bottom': 'BELOW_C', 'Right': 'POST_C',
    # split matras take the position of their last part
    'Bottom_And_Right': 'POST_C', 'Left_And_Right': 'POST_C', 'Top_And_Bottom': 'BELOW_C', 'Top_And_Bottom_And_Left': 'BELOW_C',
    'Top_And_Bottom_And_Right': 'POST_C', 'Top_And_Left': 'ABOVE_C', 'Top_And_Left_And_Right': 'POST_C', 'Top_And_Right': 'POST_C',
    'Overstruck': 'AFTER_MAIN', 'Visual_Order_Left': 'PRE_M',
}
# characters outside the Indic data, or treated differently by the shaping model
CATEGORY_OVERRIDES = {
    # spaces, dashes, multiplication sign, bullet, squares, digits: consonant placeholders
    0x00A0: 'PLACEHOLDER', 0x00D7: 'PLACEHOLDER', 0x2010: 'PLACEHOLDER', 0x2011: 'PLACEHOLDER', 0x2012: 'PLACEHOLDER', 0x2013: 'PLACEHOLDER',
    0x2014: 'PLACEHOLDER', 0x2015: 'PLACEHOLDER', 0x2022: 'PLACEHOLDER', 0x25FB: 'PLACEHOLDER', 0x25FC: 'PLACEHOLDER', 0x25FD: 'PLACEHOLDER',
    0x25FE: 'PLACEHOLDER', 0x002D: 'PLACEHOLDER', **{c: 'PLACEHOLDER' for c in range(0x30, 0x3A)},
    0x00B2: 'SMPst', 0x00B3: 'SMPst', 0x2074: 'SMPst', 0x2082: 'SMPst', 0x2083: 'SMPst', 0x2084: 'SMPst',
    0x25CC: 'DOTTEDCIRCLE',
    0x200C: 'ZWNJ', 0x200D: 'ZWJ',
    **{c: 'VS' for c in range(0xFE00, 0xFE10)},
    # Ra of the scripts with reph (or pre-base Ra)
    0x0930: 'Ra', 0x09B0: 'Ra', 0x09F0: 'Ra', 0x0A30: 'Ra', 0x0AB0: 'Ra', 0x0B30: 'Ra', 0x0BB0: 'Ra', 0x0C30: 'Ra', 0x0CB0: 'Ra', 0x0D30: 'Ra',
    # these act like bindus
    0x0953: 'SM', 0x0954: 'SM',
    # Gurmukhi addak behaves like a syllable modifier; vowel sign II may follow it;
    # udaat is a below-base matra; iri and ura are bases for vowel signs
    0x0A71: 'SM', 0x0A40: 'MPst', 0x0A51: 'M', 0x0A72: 'C', 0x0A73: 'C',
    # spacing anusvara / candrabindu letters stand alone like placeholders
    0x09FC: 'PLACEHOLDER', 0x0C80: 'PLACEHOLDER', 0x0D04: 'PLACEHOLDER',
    # Gujarati shadda and Oriya overline attach like nuktas
    0x0AFB: 'N', 0x0B55: 'N',
    # Vedic tone marks and signs
    **{c: 'A' for c in range(0x1CE2, 0x1CE9)}, 0x1CED: 'A',
    **{c: 'Symbol' for c in list(range(0x1CE9, 0x1CED)) + list(range(0x1CEE, 0x1CF2)) + list(range(0xA8F2, 0xA8F8))},
    # Kannada and Telugu archaic signs
    0x0CF1: 'CS', 0x0CF2: 'CS',
    # Vedic signs that carry the tone of the following consonant
    0x1CF5: 'CS', 0x1CF6: 'CS',
}
POSITION_OVERRIDES = {
    0x0A51: 'BELOW_C',  # Gurmukhi udaat
    0x0B01: 'BEFORE_SUB',  # Oriya candrabindu
}
CONSONANT_CATS = ('C', 'CS', 'Ra', 'CM', 'V', 'PLACEHOLDER', 'DOTTEDCIRCLE')
MATRA_CATS = ('M', 'MPst')
SMVD_CATS = ('SM', 'SMPst', 'A', 'Symbol')
POSITIONED_CATS = ('CM', 'SM', 'RS', 'H', 'M', 'MPst')


def matra_position(u, pos, block):
    """Reordering position of a matra (OpenType Indic shaping model, per script)."""
    if pos == 'PRE_C':
        return 'PRE_M'
    if pos == 'POST_C':
        return {'Devanagari': 'AFTER_SUB', 'Bengali': 'AFTER_POST', 'Gurmukhi': 'AFTER_POST', 'Gujarati': 'AFTER_POST', 'Oriya': 'AFTER_POST',
                'Tamil': 'AFTER_POST', 'Telugu': 'BEFORE_SUB' if u <= 0x0C42 else 'AFTER_SUB',
                'Kannada': 'BEFORE_SUB' if u < 0x0CC3 or u > 0x0CD6 else 'AFTER_SUB', 'Malayalam': 'AFTER_POST'}.get(block, 'AFTER_SUB')
    if pos == 'ABOVE_C':
        return {'Devanagari': 'AFTER_SUB', 'Gurmukhi': 'AFTER_POST', 'Gujarati': 'AFTER_SUB', 'Oriya': 'AFTER_MAIN', 'Tamil': 'AFTER_SUB', 'Telugu': 'BEFORE_SUB',
                'Kannada': 'BEFORE_SUB'}.get(block, 'AFTER_SUB')
    if pos == 'BELOW_C':
        return {'Devanagari': 'AFTER_SUB', 'Bengali': 'AFTER_SUB', 'Gurmukhi': 'AFTER_POST', 'Gujarati': 'AFTER_POST', 'Oriya': 'AFTER_SUB', 'Tamil': 'AFTER_POST',
                'Telugu': 'BEFORE_SUB', 'Kannada': 'BEFORE_SUB', 'Malayalam': 'AFTER_POST'}.get(block, 'BELOW_C')
    return pos


def parse_ranges(path, value_index=1):
    out = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        fields = [f.strip() for f in line.split(';')]
        a, _, b = fields[0].partition('..')
        for c in range(int(a, 16), int(b or a, 16) + 1):
            out[c] = fields[value_index]
    return out


def unicode_data(ucd):
    gc, ccc, bidi, decomp = {}, {}, {}, {}
    lines = (ucd / 'UnicodeData.txt').read_text(encoding='utf-8').splitlines()
    i = 0
    while i < len(lines):
        f = lines[i].split(';')
        cp = int(f[0], 16)
        if f[1].endswith(', First>'):
            end = int(lines[i + 1].split(';')[0], 16)
            for c in range(cp, end + 1):
                gc[c], ccc[c], bidi[c] = f[2], int(f[3]), f[4]
            i += 2
            continue
        gc[cp], ccc[cp], bidi[cp] = f[2], int(f[3]), f[4]
        if f[5] and not f[5].startswith('<'):
            decomp[cp] = [int(x, 16) for x in f[5].split()]
        i += 1
    return gc, ccc, bidi, decomp


def default_bidi(c):
    """Bidi class of unassigned code points (DerivedBidiClass.txt defaults)."""
    if 0x0590 <= c <= 0x05FF or 0x07C0 <= c <= 0x085F or 0xFB1D <= c <= 0xFB4F or 0x10800 <= c <= 0x10CFF or 0x10D40 <= c <= 0x10EBF or 0x10F00 <= c <= 0x10F2F \
            or 0x10F70 <= c <= 0x10FFF or 0x1E800 <= c <= 0x1EC6F or 0x1ED50 <= c <= 0x1EDFF or 0x1EF00 <= c <= 0x1EFFF:
        return 'R'
    if 0x0600 <= c <= 0x07BF or 0x0860 <= c <= 0x08FF or 0xFB50 <= c <= 0xFDCF or 0xFDF0 <= c <= 0xFDFF or 0xFE70 <= c <= 0xFEFF or 0x10D00 <= c <= 0x10D3F \
            or 0x10EC0 <= c <= 0x10EFF or 0x10F30 <= c <= 0x10F6F or 0x1EC70 <= c <= 0x1ECBF or 0x1ED00 <= c <= 0x1ED4F or 0x1EE00 <= c <= 0x1EEFF:
        return 'AL'
    if 0x20A0 <= c <= 0x20CF:
        return 'ET'
    return 'L'


def simple_gc(g):
    if g is None or g in ('Cn', 'Co', 'Cs'):
        return 'Cn'
    if g[0] == 'L':
        return 'L'
    if g in GC:
        return g
    return 'O'


def runs(values, lo=0, hi=0x10FFFF):
    """[(start, value)] where the value changes."""
    out = []
    prev = None
    for c in range(lo, hi + 1):
        v = values(c)
        if v != prev:
            out.append((c, v))
            prev = v
    return out


def packed(rs, base=64):
    assert all(0 <= v < base for _, v in rs)
    return [start * base + v for start, v in rs]


def dart_list(name, doc, values, per_line=16):
    lines = [f'/// {doc}', f'const List<int> {name} = [']
    for i in range(0, len(values), per_line):
        lines.append('  ' + ', '.join(str(v) for v in values[i:i + per_line]) + ',')
    lines.append('];')
    return '\n'.join(lines)


def indic_table(ucd, gc):
    syll = parse_ranges(ucd / 'IndicSyllabicCategory.txt')
    posc = parse_ranges(ucd / 'IndicPositionalCategory.txt')
    blocks = {}
    for a, b, name in INDIC_BLOCKS:
        for c in range(a, b + 1):
            blocks[c] = name
    data = {}
    for c in set(syll) | set(posc) | set(CATEGORY_OVERRIDES) | set(POSITION_OVERRIDES):
        cat = CATEGORY_MAP.get(syll.get(c, 'Other'), 'X')
        pos = POSITION_MAP.get(posc.get(c, 'Not_Applicable'), 'END')
        if c in CATEGORY_OVERRIDES:
            cat = CATEGORY_OVERRIDES[c]
        if cat not in POSITIONED_CATS:
            pos = 'END'
        block = blocks.get(c, '')
        if cat in CONSONANT_CATS:
            pos = 'BASE_C'
        elif cat in MATRA_CATS:
            pos = matra_position(c, pos, block)
        elif cat in SMVD_CATS:
            pos = 'SMVD'
        if c in POSITION_OVERRIDES:
            pos = POSITION_OVERRIDES[c]
        data[c] = (cat, pos)
    # only the scripts handled by the Indic shaper (and the characters they meet)
    return {c: v for c, v in data.items() if c < 0x0D80 or 0x1CD0 <= c <= 0x1CFF or 0x2000 <= c <= 0x209F or 0x25C0 <= c <= 0x25FF or 0xA8E0 <= c <= 0xA8FF
            or 0xFE00 <= c <= 0xFE0F}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ucd', required=True, type=Path)
    ap.add_argument('--dump-indic', type=Path, help='also write "cp category position" lines for checking')
    args = ap.parse_args()
    ucd = args.ucd.expanduser()
    version = re.search(r'# Scripts-([\d.]+)\.txt', (ucd / 'Scripts.txt').read_text(encoding='utf-8')).group(1)
    gc, ccc, bidi, decomp = unicode_data(ucd)

    # the tables cover the Basic Multilingual Plane; lib/core/io/fonts/unicode.dart
    # answers for the supplementary planes with coarse rules
    gc_runs = runs(lambda c: GC[simple_gc(gc.get(c))], 0, 0xFFFF)
    ccc_runs = runs(lambda c: ccc.get(c, 0) if gc.get(c, 'Cn')[0] == 'M' else 0, 0, 0xFFFF)
    bidi_runs = runs(lambda c: BIDI.index(bidi[c] if c in bidi else default_bidi(c)), 0, 0xFFFF)

    mirror = []
    for line in (ucd / 'BidiMirroring.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            a, b = [int(x.strip(), 16) for x in line.split(';')]
            mirror += [a, b]
    brackets = []
    for line in (ucd / 'BidiBrackets.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            a, b, t = [x.strip() for x in line.split(';')]
            if t == 'o':
                brackets += [int(a, 16), int(b, 16)]

    # canonical decompositions of the scripts the fonts cover (Latin, Greek,
    # Cyrillic, Arabic, Indic, symbols); CJK compatibility singletons are left out
    def wanted(c):
        return c < 0x3000 or 0xFB1D <= c <= 0xFB4F
    dec = []
    for c in sorted(decomp):
        if wanted(c):
            d = decomp[c]
            dec += [c, d[0], d[1] if len(d) > 1 else 0]
    exclusions = set(int(x, 16) for x in re.findall(r'^([0-9A-F]{4,6})\s', (ucd / 'CompositionExclusions.txt').read_text(encoding='utf-8'), re.M))
    # full composition exclusion: listed exclusions, singletons and non-starter decompositions
    excluded = sorted(c for c in decomp if wanted(c) and (c in exclusions or len(decomp[c]) == 1 or ccc.get(c, 0) != 0 or ccc.get(decomp[c][0], 0) != 0))

    joining = {}
    for line in (ucd / 'ArabicShaping.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            f = [x.strip() for x in line.split(';')]
            joining[int(f[0], 16)] = f[2]

    # joining types listed for the Arabic blocks and the joiners; anything else
    # is transparent when a non-spacing or enclosing mark or a format character
    # and non-joining otherwise (decided at run time from the general category)
    def arabic_block(c):
        return 0x0600 <= c <= 0x08FF or 0xFB50 <= c <= 0xFEFF or 0x200C <= c <= 0x200D
    join_runs = runs(lambda c: JOINING[joining[c]] + 1 if c in joining and arabic_block(c) else 0, 0, 0xFFFF)

    script = parse_ranges(ucd / 'Scripts.txt')
    script_runs = runs(lambda c: SCRIPTS.index(script[c]) if script.get(c) in SCRIPTS else (SCRIPTS.index('Other') if c in script else 0), 0, 0xFFFF)

    indic = indic_table(ucd, gc)
    indic_runs = runs(lambda c: ICAT.index(indic[c][0]) * 16 + IPOS.index(indic[c][1]) if c in indic else ICAT.index('X') * 16 + IPOS.index('END'), 0, 0xFFFF)
    if args.dump_indic:
        args.dump_indic.write_text(''.join(f'{c:04X} {indic.get(c, ("X", "END"))[0]} {indic.get(c, ("X", "END"))[1]}\n' for c in range(0, 0x20000)))

    parts = [
        f'// GENERATED by tool/fonts/gen_unicode_data.py from the Unicode Character Database {version}. Do not edit.',
        '// dart format off',
        '',
        '/// Unicode character properties of the Basic Multilingual Plane used by',
        '/// the text shaper and the bidirectional algorithm (see unicode.dart for',
        '/// the accessors). Range tables hold `start * base + value` for every code',
        '/// point where the value changes (search them with [rangeValue]); pair',
        '/// tables are flat lists.',
        'library;',
        '',
        '/// Simplified general categories: only the distinctions the shaper makes.',
        'abstract final class Gc {',
        '  static const other = 0, control = 1, format = 2, unassigned = 3, letter = 4, spacingMark = 5, enclosingMark = 6, nonSpacingMark = 7, decimal = 8, space = 9;',
        '}',
        '',
        '/// Bidi classes (UAX #9, table 4), in this order.',
        'const List<String> bidiClassNames = [' + ', '.join(f"'{b}'" for b in BIDI) + '];',
        '',
        '/// Scripts the text itemiser tells apart, in this order.',
        'const List<String> scriptNames = [' + ', '.join(f"'{s}'" for s in SCRIPTS) + '];',
        '',
        '/// Indic syllabic categories and positions (lib/core/io/fonts/indic.dart), in this order.',
        'const List<String> indicCategoryNames = [' + ', '.join(f"'{s}'" for s in ICAT) + '];',
        'const List<String> indicPositionNames = [' + ', '.join(f"'{s}'" for s in IPOS) + '];',
        '',
        '/// Value of [cp] in a range table packed with [base].',
        'int rangeValue(List<int> table, int cp, [int base = 64]) {',
        '  var lo = 0, hi = table.length - 1;',
        '  final key = cp * base + base - 1;',
        '  while (lo < hi) {',
        '    final mid = (lo + hi + 1) ~/ 2;',
        '    if (table[mid] <= key) {',
        '      lo = mid;',
        '    } else {',
        '      hi = mid - 1;',
        '    }',
        '  }',
        '  return table[lo] % base;',
        '}',
        '',
        dart_list('generalCategoryRanges', 'Simplified general category ([Gc]) ranges.', packed(gc_runs)),
        '',
        dart_list('combiningClassRanges', 'Canonical combining class ranges (marks only; the value is the class, which can exceed 63: stored as start * 256 + class).',
                  packed(ccc_runs, 256)),
        '',
        dart_list('bidiClassRanges', 'Bidi class ranges (index into [bidiClassNames]).', packed(bidi_runs)),
        '',
        dart_list('bidiMirrorPairs', 'Bidi_Mirroring_Glyph pairs: character, mirror.', mirror),
        '',
        dart_list('bidiBracketPairs', 'Paired brackets: opening, closing.', brackets),
        '',
        dart_list('canonicalDecompositions', 'Canonical decompositions: character, first, second (0 for singletons), sorted.', dec),
        '',
        dart_list('compositionExclusions', 'Characters never produced by canonical composition, sorted.', excluded),
        '',
        dart_list('arabicJoiningRanges', 'Arabic joining type + 1 ranges for the Arabic blocks (0 not listed; 1 U, 2 L, 3 R, 4 D and C, 7 T).', packed(join_runs)),
        '',
        dart_list('scriptRanges', 'Script ranges (index into [scriptNames]).', packed(script_runs)),
        '',
        dart_list('indicRanges', 'Indic category * 16 + position ranges (indexes into [indicCategoryNames] and [indicPositionNames]), packed with base 512.',
                  packed(indic_runs, 512)),
        '',
    ]
    OUT.write_text('\n'.join(parts), encoding='utf-8')
    print(f'{OUT.relative_to(ROOT)}: gc {len(gc_runs)}, ccc {len(ccc_runs)}, bidi {len(bidi_runs)}, mirror {len(mirror) // 2}, brackets {len(brackets) // 2}, '
          f'decompositions {len(dec) // 3}, exclusions {len(excluded)}, joining {len(join_runs)}, scripts {len(script_runs)}, indic {len(indic_runs)}')


if __name__ == '__main__':
    main()
