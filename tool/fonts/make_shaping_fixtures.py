#!/usr/bin/env python3
"""Writes the shaping fixtures in test/fixtures/shaping/<lang>.json: the
glyphs and positions that HarfBuzz (through uharfbuzz) produces with the
fonts of assets/fonts for runs of the real interface strings of
assets/i18n/{ar,ur,hi,mr,bn,pa,te}.json. test/core/text_shaping_test.dart
shapes the same runs with lib/core/io/fonts/shaper.dart and requires the
same glyph ids, advances and offsets.

A run is what the PDF text layout hands to the shaper: one or more words of
the script (letters, marks, joiners, dandas) joined by spaces and by the
punctuation the font itself covers (Indic runs also keep ASCII digits, which
are left to right and therefore split Arabic runs). The fixture keeps a
selection of the distinct words (the most frequent ones plus every word that
brings a character pair not seen yet) and of the multi-word runs (the
longest ones plus a deterministic sample); --all keeps every word and run.

    ~/venvs/ocifonts/bin/python -I tool/fonts/make_shaping_fixtures.py [--all] [--out DIR]

(see tool/fonts/build_fonts.py for the virtual environment). Rerun after
rebuilding the fonts: glyph ids change with the subsets.

Glyph encoding, space separated, in visual order: "gid" when the advance is
the font's hmtx advance and the offsets are zero, else "gid:advance" or
"gid:advance:xOffset:yOffset" (font units, y up).
"""
import argparse
import json
import random
import re
import sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / 'assets' / 'fonts'


def cls(*ranges):
    """Regular-expression class body for code point ranges (a, b) or single code points."""
    out = []
    for r in ranges:
        a, b = r if isinstance(r, tuple) else (r, r)
        out.append(re.escape(chr(a)) if a == b else f'{re.escape(chr(a))}-{re.escape(chr(b))}')
    return ''.join(out)


JOINERS = cls(0x200C, 0x200D)
# Arabic letters, marks and punctuation; the digits (0660-0669, 06F0-06F9) and
# separators (066B, 066C) are left to right in bidi and form their own runs
ARABIC = cls((0x0600, 0x065F), 0x066A, (0x066D, 0x06EF), (0x06FA, 0x06FF), (0x0750, 0x077F), (0x0870, 0x08FF), (0xFB50, 0xFDFF), (0xFE70, 0xFEFC))
DEVANAGARI = cls((0x0900, 0x097F), (0x1CD0, 0x1CFF), (0xA8E0, 0xA8FF))
SHARED_INDIC = cls(0x0951, 0x0952, 0x0964, 0x0965)
LANGS = {
    # language: (font, script, direction, script characters)
    'ar': ('NotoSansArabic-Regular.ttf', 'Arab', 'rtl', ARABIC + JOINERS),
    'ur': ('NotoSansArabic-Regular.ttf', 'Arab', 'rtl', ARABIC + JOINERS),
    'hi': ('NotoSansDevanagari-Regular.ttf', 'Deva', 'ltr', DEVANAGARI + JOINERS),
    'mr': ('NotoSansDevanagari-Regular.ttf', 'Deva', 'ltr', DEVANAGARI + JOINERS),
    'bn': ('NotoSansBengali-Regular.ttf', 'Beng', 'ltr', cls((0x0980, 0x09FF)) + SHARED_INDIC + JOINERS),
    'pa': ('NotoSansGurmukhi-Regular.ttf', 'Guru', 'ltr', cls((0x0A00, 0x0A7F)) + SHARED_INDIC + JOINERS),
    'te': ('NotoSansTelugu-Regular.ttf', 'Telu', 'ltr', cls((0x0C00, 0x0C7F)) + SHARED_INDIC + JOINERS),
}
ZW = {chr(0x200C), chr(0x200D)}
TOP_WORDS = 250     # most frequent words always kept
MAX_WORDS = 700     # cap of the selection
LONGEST_RUNS = 20   # longest multi-word runs always kept
MAX_RUNS = 300      # multi-word runs per language


def strings_of(obj, out):
    if isinstance(obj, dict):
        for v in obj.values():
            strings_of(v, out)
    elif isinstance(obj, list):
        for v in obj:
            strings_of(v, out)
    elif isinstance(obj, str):
        out.append(obj)
    return out


def neutral_class(cmap, rtl):
    """Characters that may join two words of a run: spaces and the ASCII
    punctuation the font covers (and digits in left-to-right scripts)."""
    chars = [c for c in ' !"#%&\'*+,-./:;=?@_~' if ord(c) in cmap]
    if not rtl:
        chars += [c for c in '0123456789' if ord(c) in cmap]
    return ''.join(re.escape(c) for c in chars)


def encode(font_tt, infos, positions):
    hmtx = font_tt['hmtx'].metrics
    order = font_tt.getGlyphOrder()
    out = []
    for info, pos in zip(infos, positions):
        g = info.codepoint
        adv = hmtx[order[g]][0]
        if pos.x_offset or pos.y_offset:
            out.append(f'{g}:{pos.x_advance}:{pos.x_offset}:{pos.y_offset}')
        elif pos.x_advance != adv:
            out.append(f'{g}:{pos.x_advance}')
        else:
            out.append(str(g))
    return ' '.join(out)


def select_words(words):
    """The most frequent words, then every word bringing a new character pair."""
    ordered = sorted(words, key=lambda w: (-words[w], w))
    chosen = ordered[:TOP_WORDS]
    seen = set()
    for w in chosen:
        seen.update(w[i:i + 2] for i in range(len(w) - 1))
    for w in sorted(ordered[TOP_WORDS:], key=lambda w: (-len(w), w)):
        if len(chosen) >= MAX_WORDS:
            break
        pairs = {w[i:i + 2] for i in range(len(w) - 1)}
        if pairs - seen:
            chosen.append(w)
            seen |= pairs
    return chosen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true', help='keep every distinct word and run')
    ap.add_argument('--out', type=Path, default=ROOT / 'test' / 'fixtures' / 'shaping')
    args = ap.parse_args()
    out_dir = args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    total = 0
    for lang, (font_name, script, direction, script_chars) in LANGS.items():
        data = (FONTS / font_name).read_bytes()
        font_tt = TTFont(FONTS / font_name)
        cmap = font_tt.getBestCmap()
        font = hb.Font(hb.Face(hb.Blob(data)))
        strings = strings_of(json.loads((ROOT / 'assets' / 'i18n' / f'{lang}.json').read_text(encoding='utf-8')), [])
        word = f'[{script_chars}]+'
        neutral = neutral_class(cmap, direction == 'rtl')
        run_re = re.compile(f'{word}(?:[{neutral}]+{word})*')
        words, runs = {}, {}
        for s in strings:
            for m in run_re.finditer(s):
                run = m.group(0)
                if not set(run) - ZW:  # a joiner alone is not a word
                    continue
                runs[run] = runs.get(run, 0) + 1
                for w in re.findall(word, run):
                    if set(w) - ZW:
                        words[w] = words.get(w, 0) + 1
        multi = sorted((r for r in runs if r not in words), key=lambda r: (-len(r), r))
        if args.all:
            chosen_words = sorted(words, key=lambda w: (-words[w], w))
        else:
            chosen_words = select_words(words)
            if len(multi) > MAX_RUNS:
                rng = random.Random(20261025)
                multi = multi[:LONGEST_RUNS] + sorted(rng.sample(multi[LONGEST_RUNS:], MAX_RUNS - LONGEST_RUNS), key=lambda r: (-len(r), r))
        cases = []
        for text in chosen_words + multi:
            buf = hb.Buffer()
            buf.add_str(text)
            buf.direction = direction
            buf.script = script
            buf.language = lang
            hb.shape(font, buf, {})
            cases.append([text, encode(font_tt, buf.glyph_infos, buf.glyph_positions)])
        head = {
            'generator': f'tool/fonts/make_shaping_fixtures.py, HarfBuzz {hb.version_string()} (uharfbuzz)',
            'font': font_name,
            'script': script,
            'language': lang,
            'direction': direction,
            'words': len(chosen_words),
            'runs': len(multi),
        }
        lines = ['{'] + [f'{json.dumps(k)}: {json.dumps(v, ensure_ascii=False)},' for k, v in head.items()] + ['"cases": [']
        lines += [json.dumps(c, ensure_ascii=False, separators=(',', ':')) + (',' if i + 1 < len(cases) else '') for i, c in enumerate(cases)]
        lines += [']', '}', '']
        path = out_dir / f'{lang}.json'
        path.write_text('\n'.join(lines), encoding='utf-8')
        size = path.stat().st_size
        total += size
        print(f'{lang}: {len(chosen_words)} of {len(words)} words, {len(multi)} runs, {size / 1024:.0f} KB')
    print(f'total {total / 1024:.0f} KB')


if __name__ == '__main__':
    sys.exit(main())
