#!/usr/bin/env python3
"""Writes the import fixtures of the new functions of 1.6.0 in
test/fixtures/formats with independent libraries (ezdxf, tifffile, Pillow)
and LibreDWG, as make_fixtures.py does for the others:

- survey_blocks_r2000.dxf/.dwg: survey points as block references with
  attributes (number, elevation, description) and one by the Z of its
  insertion point, beside a block that is no survey point;
- overlay_farm.kmz: ground overlays (a LatLonBox, a rotated LatLonBox, a
  gx:LatLonQuad, one whose picture is a web address);
- ortho_cog_rgb.tif: a tiled, Deflate-compressed RGB GeoTIFF (SIRGAS 2000 /
  UTM 23S) with two overviews (reduced-resolution images of the file);
- ortho_bigtiff_rgba.tif: a BigTIFF RGBA picture in strips, a third of it
  transparent;
- dem_albers_float32.tif: an elevation model whose projection is given key
  by key (ProjectedCSType 32767: Albers equal-area conic of IBGE on
  SIRGAS 2000);
- classes_r2000.dwg: a DWG with entities of classes the reader does not
  draw (IMAGE, WIPEOUT) beside a line;
- cp936_r2000.dxf/.dwg: a drawing in the Simplified Chinese code page
  ANSI_936 (GBK).

    ~/venvs/ociformats/bin/python -I tool/formats/make_fixtures_1102.py

The fixtures are committed; rerun only when adding cases.
"""
import io
import shutil
import subprocess
import zipfile
from pathlib import Path

import ezdxf
import numpy as np
import tifffile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test' / 'fixtures' / 'formats'
OUT.mkdir(parents=True, exist_ok=True)


def write(name, data):
    p = OUT / name
    p.write_bytes(data if isinstance(data, bytes) else data.encode('utf-8'))
    print(f'  {name} ({p.stat().st_size} bytes)')


def dxf2dwg(source, target):
    if not shutil.which('dxf2dwg'):
        print(f'  {target}: dxf2dwg not installed, not rewritten')
        return
    t = OUT / target
    if t.exists():
        t.unlink()
    r = subprocess.run(['dxf2dwg', '--as', 'r2000', '-y', '-o', str(t), str(OUT / source)], capture_output=True, text=True)
    print(f'  {target} ({t.stat().st_size} bytes)' if r.returncode == 0 and t.exists() else f'  {target}: dxf2dwg failed ({r.returncode}) {r.stderr[-300:]}')


# ----------------------------------------------------------------- survey blocks
print('survey blocks')
doc = ezdxf.new('R2000', setup=False)
doc.header['$INSUNITS'] = 6
doc.layers.add('PONTOS', color=1)
doc.layers.add('VEGETACAO', color=3)
blk = doc.blocks.new(name='PONTO')
blk.add_circle((0, 0), 0.25)
blk.add_point((0, 0))
blk.add_attdef('PT', (0.4, 0.2), dxfattribs={'height': 0.3})
cota = blk.add_attdef('COTA', (0.4, -0.2), dxfattribs={'height': 0.3})
cota.dxf.flags = 1  # invisible: the elevation is data
blk.add_attdef('DESC', (0.4, -0.6), dxfattribs={'height': 0.3})
msp = doc.modelspace()
for i, (x, y, z, desc) in enumerate([(100.0, 200.0, 612.35, 'MARCO'), (130.0, 205.0, 613.10, 'CERCA'), (150.0, 198.0, 611.80, 'POCO')]):
    ref = msp.add_blockref('PONTO', (x, y, z), dxfattribs={'layer': 'PONTOS'})
    # the elevation as surveyors type it: a decimal comma and the unit
    ref.add_auto_attribs({'PT': str(i + 1), 'COTA': f'{z:.2f}'.replace('.', ',') + ' m', 'DESC': desc})
# the elevation only in the Z of the insertion point
blk2 = doc.blocks.new(name='PT_COTADO')
blk2.add_point((0, 0))
blk2.add_line((-0.2, 0), (0.2, 0))
msp.add_blockref('PT_COTADO', (170.0, 210.0, 615.2), dxfattribs={'layer': 'PONTOS'})
# a symbol, not a survey point
blk3 = doc.blocks.new(name='ARVORE')
blk3.add_circle((0, 0), 1.5)
msp.add_blockref('ARVORE', (140.0, 220.0), dxfattribs={'layer': 'VEGETACAO'})
doc.saveas(OUT / 'survey_blocks_r2000.dxf')
print('  survey_blocks_r2000.dxf')
dxf2dwg('survey_blocks_r2000.dxf', 'survey_blocks_r2000.dwg')

# ----------------------------------------------------------------- KMZ ground overlays
print('KMZ ground overlays')


def picture(size, colour, fmt):
    b = io.BytesIO()
    Image.new('RGB', size, colour).save(b, fmt, **({'quality': 85} if fmt == 'JPEG' else {}))
    return b.getvalue()


kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
\t<name>Fazenda com imagens</name>
\t<Placemark><name>Poço</name><Point><coordinates>-47.9290,-15.7795,1050</coordinates></Point></Placemark>
\t<Folder>
\t\t<name>Imagens</name>
\t\t<GroundOverlay>
\t\t\t<name>Ortofoto</name>
\t\t\t<color>bfffffff</color>
\t\t\t<Icon><href>files/ortho.png</href></Icon>
\t\t\t<LatLonBox><north>-15.7790</north><south>-15.7800</south><east>-47.9280</east><west>-47.9300</west></LatLonBox>
\t\t</GroundOverlay>
\t\t<GroundOverlay>
\t\t\t<name>Croqui</name>
\t\t\t<drawOrder>2</drawOrder>
\t\t\t<Icon><href>files/croqui.jpg</href></Icon>
\t\t\t<LatLonBox><north>-15.7792</north><south>-15.7798</south><east>-47.9286</east><west>-47.9294</west><rotation>30</rotation></LatLonBox>
\t\t</GroundOverlay>
\t\t<GroundOverlay>
\t\t\t<name>Quadra</name>
\t\t\t<drawOrder>1</drawOrder>
\t\t\t<Icon><href>files/quad.png</href></Icon>
\t\t\t<gx:LatLonQuad><coordinates>-47.9299,-15.7799 -47.9295,-15.7799 -47.9295,-15.7796 -47.9299,-15.7796</coordinates></gx:LatLonQuad>
\t\t</GroundOverlay>
\t\t<GroundOverlay>
\t\t\t<name>Da web</name>
\t\t\t<Icon><href>https://example.com/overlay.png</href></Icon>
\t\t\t<LatLonBox><north>-15.7790</north><south>-15.7800</south><east>-47.9280</east><west>-47.9300</west></LatLonBox>
\t\t</GroundOverlay>
\t</Folder>
</Document>
</kml>
'''
z = io.BytesIO()
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('doc.kml', kml)
    zf.writestr('files/ortho.png', picture((40, 20), (30, 140, 40), 'PNG'))
    zf.writestr('files/croqui.jpg', picture((30, 20), (220, 200, 60), 'JPEG'))
    zf.writestr('files/quad.png', picture((20, 15), (200, 60, 60), 'PNG'))
write('overlay_farm.kmz', z.getvalue())

# ----------------------------------------------------------------- large GeoTIFFs
print('large GeoTIFFs')
E0, N0 = 186056.581, 8253215.209


def keys(*entries):
    """GeoKeyDirectory: (id, location, count, value) after the header."""
    out = [1, 1, 0, len(entries)]
    for e in entries:
        out += list(e)
    return tuple(out)


def geotags(scale, tie, key_dir, doubles=None):
    tags = [(33550, 'd', 3, tuple(scale), True), (33922, 'd', 6, tuple(tie), True), (34735, 'H', len(key_dir), key_dir, True)]
    if doubles:
        tags.append((34736, 'd', len(doubles), tuple(doubles), True))
    return tags


# 512 × 384, four quadrants: red, green / blue, white; the overviews are
# painted cyan and magenta so that a test tells which image was read
full = np.zeros((384, 512, 3), dtype=np.uint8)
full[:192, :256] = (255, 0, 0)
full[:192, 256:] = (0, 255, 0)
full[192:, :256] = (0, 0, 255)
full[192:, 256:] = (255, 255, 255)
half = np.zeros((192, 256, 3), dtype=np.uint8)
half[...] = (0, 255, 255)
quarter = np.zeros((96, 128, 3), dtype=np.uint8)
quarter[...] = (255, 0, 255)
utm23s = keys((1024, 0, 1, 1), (1025, 0, 1, 1), (3072, 0, 1, 31983))
buf = io.BytesIO()
with tifffile.TiffWriter(buf) as tw:
    tw.write(full, photometric='rgb', tile=(128, 128), compression='zlib', extratags=geotags((0.1, 0.1, 0), (0, 0, 0, E0, N0 + 38.4, 0), utm23s), metadata=None)
    tw.write(half, photometric='rgb', tile=(64, 64), compression='zlib', subfiletype=1, metadata=None)
    tw.write(quarter, photometric='rgb', tile=(32, 32), compression='zlib', subfiletype=1, metadata=None)
write('ortho_cog_rgb.tif', buf.getvalue())

# BigTIFF RGBA 300 × 200 in strips of 16 rows, the left third transparent
rgba = np.zeros((200, 300, 4), dtype=np.uint8)
rgba[..., 0] = 20
rgba[..., 1] = 160
rgba[..., 2] = 90
rgba[..., 3] = 255
rgba[:, :100, 3] = 0
buf = io.BytesIO()
tifffile.imwrite(buf, rgba, bigtiff=True, photometric='rgb', extrasamples=[2], rowsperstrip=16, compression='zlib', extratags=geotags((0.2, 0.2, 0), (0, 0, 0, E0, N0 + 40, 0), utm23s), metadata=None)
write('ortho_bigtiff_rgba.tif', buf.getvalue())

# 64 × 48 float DEM, 30 m pixels, in the Albers equal-area conic of IBGE
# (SIRGAS 2000 / Brazil Albers) given key by key; the top-left corner at
# the Albers coordinates of 15.78° S 47.93° W; z = 800 + 0.1·col
dem = np.fromfunction(lambda r, c: 800 + 0.1 * c, (48, 64), dtype=np.float64).astype(np.float32)
albers = keys(
    (1024, 0, 1, 1), (1025, 0, 1, 1), (3072, 0, 1, 32767), (2048, 0, 1, 4674), (3074, 0, 1, 32767), (3075, 0, 1, 11), (3076, 0, 1, 9001),
    (3078, 34736, 1, 0), (3079, 34736, 1, 1), (3081, 34736, 1, 2), (3080, 34736, 1, 3), (3082, 34736, 1, 4), (3083, 34736, 1, 5),
)
doubles = (-2.0, -22.0, -12.0, -54.0, 5000000.0, 10000000.0)
buf = io.BytesIO()
tifffile.imwrite(buf, dem, photometric='minisblack', extratags=geotags((30, 30, 0), (0, 0, 0, 5641804.97972613, 9568677.46976268, 0), albers, doubles), metadata=None)
write('dem_albers_float32.tif', buf.getvalue())

# ----------------------------------------------------------------- DWG class entities
print('DWG classes')
doc = ezdxf.new('R2000', setup=False)
doc.header['$INSUNITS'] = 6
msp = doc.modelspace()
msp.add_line((0, 0), (10, 0))
image_def = doc.add_image_def(filename='ortho.png', size_in_pixel=(640, 480))
msp.add_image(image_def, insert=(0, 0), size_in_units=(6.4, 4.8))
msp.add_wipeout([(20, 0), (25, 0), (25, 5), (20, 5)])
doc.saveas(OUT / 'classes_r2000.dxf')
print('  classes_r2000.dxf')
dxf2dwg('classes_r2000.dxf', 'classes_r2000.dwg')

# ----------------------------------------------------------------- East Asian code page
print('code page 936')
CP936_DXF = '\n'.join([
    '  0', 'SECTION', '  2', 'HEADER', '  9', '$ACADVER', '  1', 'AC1015', '  9', '$DWGCODEPAGE', '  3', 'ANSI_936', '  9', '$INSUNITS', ' 70', '6', '  0', 'ENDSEC',
    '  0', 'SECTION', '  2', 'TABLES', '  0', 'TABLE', '  2', 'LAYER', ' 70', '1', '  0', 'LAYER', '  2', '管道', ' 70', '0', ' 62', '3', '  6', 'CONTINUOUS', '  0', 'ENDTAB', '  0', 'ENDSEC',
    '  0', 'SECTION', '  2', 'ENTITIES',
    '  0', 'LINE', '  8', '管道', ' 10', '0', ' 20', '0', ' 30', '0', ' 11', '10', ' 21', '0', ' 31', '0',
    '  0', 'TEXT', '  8', '管道', ' 10', '0', ' 20', '5', ' 30', '0', ' 40', '1', '  1', '阀门1号',
    '  0', 'ENDSEC', '  0', 'EOF', '',
])
write('cp936_r2000.dxf', CP936_DXF.encode('gbk'))
dxf2dwg('cp936_r2000.dxf', 'cp936_r2000.dwg')
print('done')
