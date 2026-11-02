#!/usr/bin/env python3
"""Builds the subset fonts in assets/fonts/ that the PDF writer embeds for the
text the standard Helvetica (WinAnsi) font cannot show.

Fonts (all SIL Open Font License 1.1, regular weight, TrueType outlines):

    NotoSans-Regular.ttf            Latin (Turkish, Vietnamese, Hausa...), Greek, Cyrillic
    NotoSansMath-Regular.ttf        arrows, mathematical operators, geometric shapes
    NotoSansArabic-Regular.ttf      Arabic, Urdu (GSUB/GPOS/GDEF kept)
    NotoSansDevanagari-Regular.ttf  Hindi, Marathi (GSUB/GPOS/GDEF kept)
    NotoSansBengali-Regular.ttf     Bengali (GSUB/GPOS/GDEF kept)
    NotoSansGurmukhi-Regular.ttf    Punjabi (GSUB/GPOS/GDEF kept)
    NotoSansTelugu-Regular.ttf      Telugu (GSUB/GPOS/GDEF kept)
    NotoSansSC-Regular.ttf          Simplified Chinese: GB 2312 level 1 hanzi + every hanzi of the strings
    NotoSansJP-Regular.ttf          Japanese: kana + JIS X 0208 level 1 kanji + every kanji of the strings

Each font keeps its script ranges, every character of that script used in
assets/i18n/*.json and lib/app/i18n.dart, and the digits and punctuation the
source font has. The complex-script fonts keep the OpenType layout tables
(GSUB, GPOS, GDEF) of the features the shaper in lib/core/io/fonts applies;
the others keep only the glyphs (plain cmap mapping). Hinting, glyph names and
vertical metrics are dropped. The two CJK sources are variable fonts: they are
instanced at wght=400 into static glyf fonts first. OFL.txt collects the
copyright lines of every family followed by the licence text.

Sources (downloaded into --downloads unless the files are already there),
at fixed commits of the two repositories and checked against the SHA-256 in
SOURCES below, so that a rebuild gives the same subsets:

    https://github.com/notofonts/notofonts.github.io   fonts/<Family>/unhinted/ttf/<Family>-Regular.ttf  (static TrueType)
    https://github.com/google/fonts                    ofl/notosanssc/NotoSansSC[wght].ttf, ofl/notosansjp/NotoSansJP[wght].ttf
    https://github.com/google/fonts                    ofl/<family>/OFL.txt (licence texts)

Moving to newer fonts: change NOTO_COMMIT / GOOGLE_COMMIT, run with
--update-hashes (it prints the new SOURCES table to paste here), rebuild and
look at the size and coverage changes before committing.

Setup, once, outside the repository (fontTools does the subsetting and
instancing; uharfbuzz is only needed by make_shaping_fixtures.py), with the
versions of tool/fonts/requirements.txt:

    python3 -m venv ~/venvs/ocifonts
    ~/venvs/ocifonts/bin/pip install -r tool/fonts/requirements.txt

Run from the repository root, with a download directory outside the repository
(downloaded files are data: the script never executes anything from there):

    ~/venvs/ocifonts/bin/python -I tool/fonts/build_fonts.py --downloads ~/tmp/ocifonts-src

Then regenerate the shaping fixtures (test/fixtures/shaping) with
tool/fonts/make_shaping_fixtures.py, since glyph ids change with the subsets.
test/guards/pdf_font_coverage_test.dart fails when a string of any language
has a character the subsets cannot draw: rerun both scripts after adding
translations.
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'fonts'

# Commits of the source repositories (2026-11-02) and the SHA-256 of every
# file taken from them.
NOTO_COMMIT = '5c82cef0a8f08806f932062e18c02be62be278f0'
GOOGLE_COMMIT = '6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec'
NOTO = 'https://raw.githubusercontent.com/notofonts/notofonts.github.io/' + NOTO_COMMIT + '/fonts/{0}/unhinted/ttf/{0}-Regular.ttf'
GOOGLE = 'https://raw.githubusercontent.com/google/fonts/' + GOOGLE_COMMIT + '/ofl/{0}/{1}'
SOURCES = {
    'NotoSans-Regular.ttf': 'f3961a9cde016d41a4879aecda1474d3a36d6bf54fa0e4643de029cc2248b0e8',
    'NotoSansArabic-Regular.ttf': 'bd86ca02f087d7f3c3788ba458fb6b73744c7639ed276b8d870dba6def6c40d0',
    'NotoSansBengali-Regular.ttf': '5dceda02816fece18ea6796f474f5d3170f1d862f21b1e809cdc94b1caa4b6ec',
    'NotoSansDevanagari-Regular.ttf': '9c7d935139ea6a1e6ad9dbac4f6d27ece1e04bca8123c8888d00a0f9df4724cd',
    'NotoSansGurmukhi-Regular.ttf': '2454c944fda799d2861f11c03e492c453e33083dd1e8d99bd6baac8de71ad0f0',
    'NotoSansJP[wght].ttf': 'c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f',
    'NotoSansMath-Regular.ttf': 'b127e84699212b6b2ef50aff58e0ebebeec04ffe6db1b9eb9e209c8c3d97b4aa',
    'NotoSansSC[wght].ttf': 'a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da',
    'NotoSansTelugu-Regular.ttf': 'dcb86a5da09365a2d73d725e429403dca988e6d50c1b1d564579a25dbc18bd29',
    'OFL-notosans.txt': 'cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a',
    'OFL-notosansarabic.txt': '07fc70bfeb985cc1a87a8587d0a0c80bab11c86c9dc3fd95b6f0cb332f983e96',
    'OFL-notosansbengali.txt': '754f0e221aa7d5a915489f3bf1f20fe53ddc35ab2834a4d91656d78f9622de70',
    'OFL-notosansdevanagari.txt': 'a216f6f8d85c7228093e0ee5e258d9d377e6671f68acb4db1930b29583d0f331',
    'OFL-notosansgurmukhi.txt': '3f7451b7e2c8381be0c5712f7b0dd5c2d75fe787ae16a99f18b7fa45627a0fde',
    'OFL-notosansjp.txt': '1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9',
    'OFL-notosansmath.txt': '403a95275b469061b7d4371c328e0ada3bc7d63328abe2e88aad5cd243b2fe21',
    'OFL-notosanssc.txt': '1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9',
    'OFL-notosanstelugu.txt': '481c72a8f1b4f645a7e6b10326be41b2da2c15cb470ff48a07fab773eed00102',
}


def r(a, b=None):
    return range(a, (b if b is not None else a) + 1)


# digits, punctuation, spaces, joiners and symbols every font keeps when it has them
COMMON = [r(0x20, 0x7E), r(0xA0, 0xBF), r(0xD7), r(0xF7), r(0x2000, 0x2027), r(0x202F, 0x205F), r(0x20B9), r(0x2212), r(0x25CC), r(0x034F), r(0xFEFF)]

# Features applied by lib/core/io/fonts/shaper.dart (anything else is dropped,
# so that e.g. 'aalt' does not pull every alternate glyph into the subset).
INDIC_FEATURES = ['locl', 'ccmp', 'nukt', 'akhn', 'rphf', 'rkrf', 'pref', 'blwf', 'abvf', 'half', 'pstf', 'vatu', 'cjct', 'init', 'pres', 'abvs', 'blws', 'psts', 'haln',
                  'rlig', 'calt', 'clig', 'liga', 'rclt', 'abvm', 'blwm', 'dist', 'kern', 'mark', 'mkmk', 'curs']
ARABIC_FEATURES = ['ccmp', 'locl', 'isol', 'fina', 'fin2', 'fin3', 'medi', 'med2', 'init', 'rlig', 'rclt', 'calt', 'liga', 'clig', 'mset', 'rtlm', 'curs', 'kern', 'mark', 'mkmk', 'stch']
LATIN_FEATURES = ['ccmp', 'locl', 'rlig', 'liga', 'clig', 'calt', 'rclt', 'kern', 'mark', 'mkmk', 'curs', 'dist', 'abvm', 'blwm']


def gb2312_level1():
    out = set()
    for row in range(0xB0, 0xD8):
        for col in range(0xA1, 0xFF):
            if row == 0xD7 and col > 0xF9:
                continue
            out.add(ord(bytes([row, col]).decode('gb2312')))
    return out


def jis_level1():
    out = set()
    for row in range(0xB0, 0xD0):
        for col in range(0xA1, 0xFF):
            if row == 0xCF and col > 0xD3:
                continue
            out.add(ord(bytes([row, col]).decode('euc_jp')))
    return out


def jis_symbols():
    """Rows 1-8 of JIS X 0208 (symbols, digits, Latin, kana, Greek, Cyrillic, box drawing)."""
    out = set()
    for row in range(0xA1, 0xA9):
        for col in range(0xA1, 0xFF):
            try:
                out.add(ord(bytes([row, col]).decode('euc_jp')))
            except UnicodeDecodeError:
                pass
    return out


HAN = [r(0x2E80, 0x2FDF), r(0x3400, 0x4DBF), r(0x4E00, 0x9FFF), r(0xF900, 0xFAFF), r(0x20000, 0x3134F)]
KANA = [r(0x3040, 0x30FF), r(0x31F0, 0x31FF), r(0xFF65, 0xFF9F)]
CJK_PUNCT = [r(0x3000, 0x303F), r(0xFF01, 0xFF64), r(0xFFE0, 0xFFEE), r(0x2190, 0x2193), r(0x2460, 0x2473), r(0x25A0, 0x25FF), r(0x2605, 0x2606), r(0x2103), r(0x2116)]

# (output, source, Unicode ranges of the script, extra set builder, layout features or None, i18n languages)
FONTS = [
    ('NotoSans-Regular.ttf', 'NotoSans-Regular.ttf',
     [r(0x20, 0x7E), r(0xA0, 0x24F), r(0x250, 0x2FF), r(0x300, 0x36F), r(0x370, 0x3FF), r(0x400, 0x52F), r(0x1AB0, 0x1AFF), r(0x1DC0, 0x1DFF), r(0x1E00, 0x1EFF), r(0x2000, 0x206F),
      r(0x2070, 0x209F), r(0x20A0, 0x20CF), r(0x20D0, 0x20FF), r(0x2100, 0x215F), r(0x2C60, 0x2C7F), r(0xA720, 0xA7FF), r(0xFB00, 0xFB06), r(0xFE20, 0xFE2F), r(0xFFFD)],
     None, LATIN_FEATURES, None),
    ('NotoSansMath-Regular.ttf', 'NotoSansMath-Regular.ttf',
     [r(0x2190, 0x21FF), r(0x2200, 0x22FF), r(0x2300, 0x23FF), r(0x25A0, 0x25FF), r(0x2605, 0x2606), r(0x2713), r(0x27E8, 0x27E9)],
     None, None, None),
    ('NotoSansArabic-Regular.ttf', 'NotoSansArabic-Regular.ttf',
     [r(0x600, 0x6FF), r(0x750, 0x77F), r(0x870, 0x8FF), r(0xFB50, 0xFDFF), r(0xFE70, 0xFEFF), r(0x200B, 0x200F), r(0x2E41)],
     None, ARABIC_FEATURES, ['ar', 'ur']),
    ('NotoSansDevanagari-Regular.ttf', 'NotoSansDevanagari-Regular.ttf',
     [r(0x900, 0x97F), r(0x1CD0, 0x1CFF), r(0xA8E0, 0xA8FF), r(0x200B, 0x200D)],
     None, INDIC_FEATURES, ['hi', 'mr']),
    ('NotoSansBengali-Regular.ttf', 'NotoSansBengali-Regular.ttf',
     [r(0x980, 0x9FF), r(0x951, 0x952), r(0x964, 0x965), r(0x1CD0, 0x1CFF), r(0x200B, 0x200D)],
     None, INDIC_FEATURES, ['bn']),
    ('NotoSansGurmukhi-Regular.ttf', 'NotoSansGurmukhi-Regular.ttf',
     [r(0xA00, 0xA7F), r(0x951, 0x952), r(0x964, 0x965), r(0x200B, 0x200D)],
     None, INDIC_FEATURES, ['pa']),
    ('NotoSansTelugu-Regular.ttf', 'NotoSansTelugu-Regular.ttf',
     [r(0xC00, 0xC7F), r(0x951, 0x952), r(0x964, 0x965), r(0x1CD0, 0x1CFF), r(0x200B, 0x200D)],
     None, INDIC_FEATURES, ['te']),
    ('NotoSansSC-Regular.ttf', 'NotoSansSC[wght].ttf', CJK_PUNCT, 'sc', None, ['zh']),
    ('NotoSansJP-Regular.ttf', 'NotoSansJP[wght].ttf', KANA + CJK_PUNCT, 'jp', None, ['ja']),
]

# Ranges a font keeps only the characters the strings use from.
USED_ONLY = {
    # modifier letters of the formulas (the ᵇ of R = a·Hᵇ) and other phonetic extensions
    'NotoSans-Regular.ttf': [r(0x1D00, 0x1DBF)],
}

OFL_FAMILIES = [('notosans', 'Noto Sans'), ('notosansmath', 'Noto Sans Math'), ('notosansarabic', 'Noto Sans Arabic'), ('notosansdevanagari', 'Noto Sans Devanagari'),
                ('notosansbengali', 'Noto Sans Bengali'), ('notosansgurmukhi', 'Noto Sans Gurmukhi'), ('notosanstelugu', 'Noto Sans Telugu'), ('notosanssc', 'Noto Sans SC'),
                ('notosansjp', 'Noto Sans JP')]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fetch(url, dest, update_hashes=False):
    if not (dest.exists() and dest.stat().st_size > 0):
        print('download', url)
        with urllib.request.urlopen(url, timeout=300) as resp:
            dest.write_bytes(resp.read())
    digest = sha256(dest)
    if update_hashes:
        SOURCES[dest.name] = digest
    elif SOURCES.get(dest.name) != digest:
        sys.exit(f'{dest}: SHA-256 {digest} is not the one in SOURCES ({SOURCES.get(dest.name)}); '
                 'delete the file to download it again, or run with --update-hashes after changing the commits')


def download(dl, update_hashes=False):
    dl.mkdir(parents=True, exist_ok=True)
    for name in ['NotoSans', 'NotoSansMath', 'NotoSansArabic', 'NotoSansDevanagari', 'NotoSansBengali', 'NotoSansGurmukhi', 'NotoSansTelugu']:
        fetch(NOTO.format(name), dl / f'{name}-Regular.ttf', update_hashes)
    fetch(GOOGLE.format('notosanssc', 'NotoSansSC%5Bwght%5D.ttf'), dl / 'NotoSansSC[wght].ttf', update_hashes)
    fetch(GOOGLE.format('notosansjp', 'NotoSansJP%5Bwght%5D.ttf'), dl / 'NotoSansJP[wght].ttf', update_hashes)
    for fam, _ in OFL_FAMILIES:
        fetch(GOOGLE.format(fam, 'OFL.txt'), dl / f'OFL-{fam}.txt', update_hashes)
    if update_hashes:
        print('SOURCES = {')
        for name in sorted(SOURCES):
            print(f"    '{name}': '{SOURCES[name]}',")
        print('}')


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


def used_chars(langs):
    """Every character of the language packs (all of them when langs is None) and of lib/app/i18n.dart."""
    chars = set()
    for path in sorted((ROOT / 'assets' / 'i18n').glob('*.json')):
        if langs is not None and path.stem not in langs:
            continue
        for s in strings_of(json.loads(path.read_text(encoding='utf-8')), []):
            chars.update(ord(c) for c in s)
    chars.update(ord(c) for c in (ROOT / 'lib' / 'app' / 'i18n.dart').read_text(encoding='utf-8'))
    for part in sorted((ROOT / 'lib' / 'app' / 'i18n_parts').glob('*.dart')):
        chars.update(ord(c) for c in part.read_text(encoding='utf-8'))
    return chars


def in_ranges(cp, ranges):
    return any(cp in rg for rg in ranges)


def build(dl):
    OUT.mkdir(parents=True, exist_ok=True)
    gb1, jis1, jissym = gb2312_level1(), jis_level1(), jis_symbols()
    total = 0
    for out_name, src_name, ranges, extra, features, langs in FONTS:
        # recalcTimestamp=False: saving keeps head.modified of the source, so
        # that two runs write the same bytes
        font = TTFont(dl / src_name, recalcTimestamp=False)
        if 'fvar' in font:
            print('instancing', src_name, 'at wght=400')
            font = instancer.instantiateVariableFont(font, {'wght': 400}, inplace=False, updateFontNames=True)
            font.recalcTimestamp = False
        cmap = font.getBestCmap()
        wanted = set()
        for rg in ranges + COMMON:
            wanted.update(rg)
        used = used_chars(langs)
        if extra == 'sc':
            wanted |= gb1
            wanted |= {c for c in used if in_ranges(c, HAN)}
            wanted |= {c for c in used_chars(['ja']) if in_ranges(c, HAN)} & gb1
        elif extra == 'jp':
            wanted |= jis1 | jissym
            wanted |= {c for c in used if in_ranges(c, HAN + KANA)}
        else:
            wanted |= {c for c in used if in_ranges(c, ranges + USED_ONLY.get(out_name, []))}
        unicodes = sorted(c for c in wanted if c in cmap)
        opts = subset.Options()
        opts.layout_features = features or []
        opts.layout_scripts = ['*']
        opts.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
        opts.name_languages = [0x409]
        opts.hinting = False
        opts.glyph_names = False
        opts.legacy_kern = False
        opts.notdef_outline = True
        opts.recalc_bounds = True
        opts.recalc_timestamp = False
        opts.prune_unicode_ranges = True
        opts.drop_tables += ['DSIG', 'BASE', 'STAT', 'vhea', 'vmtx', 'VORG', 'gasp', 'meta', 'MATH', 'JSTF', 'prep', 'fpgm', 'cvt ', 'kern', 'HVAR', 'MVAR']
        if features is None:
            opts.drop_tables += ['GSUB', 'GPOS', 'GDEF']
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=unicodes)
        sub.subset(font)
        dest = OUT / out_name
        font.save(dest)
        size = dest.stat().st_size
        total += size
        print(f'{out_name:34s} {len(unicodes):6d} characters {font["maxp"].numGlyphs:6d} glyphs {size / 1024:8.1f} KB')
    print(f'total {total / 1024 / 1024:.2f} MB')
    write_licence(dl)


def write_licence(dl):
    lines = ['Fonts in this folder (subsets built by tool/fonts/build_fonts.py) and their copyright notices:', '']
    body = None
    for fam, title in OFL_FAMILIES:
        text = (dl / f'OFL-{fam}.txt').read_text(encoding='utf-8')
        first = text.split('\n', 1)[0].strip()
        lines.append(f'{title}: {first}')
        # the licence proper starts at its dashed title; the line before it
        # only differs in the address of the licence FAQ
        rest = text[text.index('-----'):]
        if body is None:
            body = rest
        elif re.sub(r'\s+', ' ', rest) != re.sub(r'\s+', ' ', body):
            sys.exit(f'licence text of {fam} differs from the others')
    lines += ['', 'These Font Software are licensed under the SIL Open Font License, Version 1.1.',
              'This license is copied below, and is also available with a FAQ at:', 'https://openfontlicense.org', '', '', body.strip(), '']
    (OUT / 'OFL.txt').write_text('\n'.join(lines), encoding='utf-8')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--downloads', required=True, type=Path, help='directory for the source fonts (outside the repository)')
    ap.add_argument('--update-hashes', action='store_true', help='take the SHA-256 of the downloaded files as they are and print the new SOURCES table')
    args = ap.parse_args()
    dl = args.downloads.expanduser().resolve()
    if ROOT in dl.parents or dl == ROOT:
        sys.exit('keep --downloads outside the repository')
    download(dl, args.update_hashes)
    build(dl)


if __name__ == '__main__':
    main()
