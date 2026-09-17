#!/usr/bin/env python3
"""Writes the import fixtures in test/fixtures/formats with independent
libraries (ezdxf, pyshp, tifffile, Pillow, openpyxl) and LibreDWG, so the
readers are exercised on files produced by other software, not by our own
writers. test/core/formats_test.dart imports every file here.

    pip install ezdxf pyshp openpyxl pillow tifffile numpy
    python3 tool/formats/make_fixtures.py

The fixtures are committed; rerun only when adding cases.
"""
import io
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

import ezdxf
import numpy as np
import openpyxl
import shapefile
import tifffile
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test' / 'fixtures' / 'formats'
OUT.mkdir(parents=True, exist_ok=True)

# Brasília, UTM zone 23S (metres) – the same reference point as the other tests
E0, N0 = 186056.581, 8253215.209
UTM23S_WKT = ('PROJCS["WGS 84 / UTM zone 23S",GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],'
              'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],'
              'PARAMETER["latitude_of_origin",0],PARAMETER["central_meridian",-45],PARAMETER["scale_factor",0.9996],'
              'PARAMETER["false_easting",500000],PARAMETER["false_northing",10000000],UNIT["metre",1]]')
WGS84_WKT = 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]'


def write(name, data):
    p = OUT / name
    if isinstance(data, str):
        p.write_text(data, encoding='utf-8')
    else:
        p.write_bytes(data)
    print(f'  {name} ({p.stat().st_size} bytes)')


# ----------------------------------------------------------------- survey points
print('survey points')
write('survey_pnezd.txt', ''.join(f'{i + 1},{N0 + 10 * i:.3f},{E0 + 25 * i:.3f},{1050 + 0.5 * i:.2f},EST{i + 1}\n' for i in range(4)))
# a Windows-1252 file with a header, semicolons and decimal commas
csv = 'Ponto;Este;Norte;Cota;Descrição\r\n' + ''.join(f'P{i + 1};{E0 + 25 * i:.2f};{N0 + 10 * i:.2f};{1050 + 0.5 * i:.2f};Cerca {i + 1}\r\n'.replace('.', ',') for i in range(3))
write('survey_header_cp1252.csv', csv.encode('cp1252'))
write('survey_latlon.csv', 'lat,lon,elev,name\n-15.7800,-47.9300,1050.0,A\n-15.7800,-47.9290,1051.5,B\n-15.7810,-47.9300,1049.0,C\n')
write('survey_local.xyz', '100.0 200.0 50.5\n110.0 200.0 51.0\n110.0 210.0 51.5\n# comment line\n100.0 210.0 52.0\n')
write('survey_tab_header.txt', 'x\ty\tz\tname\n10\t20\t5.5\tTQ\n30\t20\t6.0\tPOCO\n')

# ----------------------------------------------------------------- shapefiles
print('shapefiles')


def shp_zip(zip_name, base, build, prj=None):
    buf = {}
    w = shapefile.Writer(shp=io.BytesIO(), shx=io.BytesIO(), dbf=io.BytesIO(), shapeType=build[0])
    build[1](w)
    w.close()
    for ext, f in (('shp', w.shp), ('shx', w.shx), ('dbf', w.dbf)):
        buf[ext] = f.getvalue()
    z = io.BytesIO()
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        for ext, data in buf.items():
            zf.writestr(f'{base}.{ext}', data)
        if prj:
            zf.writestr(f'{base}.prj', prj)
    write(zip_name, z.getvalue())
    return buf


def parcels(w):
    w.field('NAME', 'C', size=40)
    w.field('AREA_HA', 'N', size=10, decimal=2)
    w.poly([[(E0, N0), (E0, N0 + 200), (E0 + 300, N0 + 200), (E0 + 300, N0), (E0, N0)]])
    w.record('Talhão 1', 6.0)
    w.poly([[(E0 + 320, N0), (E0 + 320, N0 + 100), (E0 + 420, N0 + 100), (E0 + 420, N0), (E0 + 320, N0)]])
    w.record('Talhão 2', 1.0)


shp_zip('shp_parcels_utm.zip', 'talhoes', (shapefile.POLYGON, parcels), UTM23S_WKT)


def contours(w):
    w.field('ELEV', 'N', size=10, decimal=2)
    for k, z in enumerate((1050.0, 1052.0, 1054.0)):
        w.linez([[(E0 + x, N0 + 30 * k + (x % 100) * 0.1, z) for x in range(0, 301, 50)]])
        w.record(z)


shp_zip('shp_contours_z_utm.zip', 'curvas', (shapefile.POLYLINEZ, contours), UTM23S_WKT)


def wells(w):
    w.field('NOME', 'C', size=20)
    w.field('COTA', 'N', size=10, decimal=2)
    for i, (lat, lon, z) in enumerate(((-15.7800, -47.9300, 1048.5), (-15.7800, -47.9290, 1049.0), (-15.7810, -47.9295, 1047.2))):
        w.point(lon, lat)
        w.record(f'Poço {i + 1}', z)


shp_zip('shp_wells_wgs84.zip', 'pocos', (shapefile.POINT, wells), WGS84_WKT)


def stakes(w):
    w.field('ID', 'C', size=10)
    w.multipointz([(E0 + 10, N0 + 10, 1060.0), (E0 + 20, N0 + 10, 1061.0), (E0 + 30, N0 + 10, 1062.0)])
    w.record('E1')


shp_zip('shp_stakes_multipointz.zip', 'estacas', (shapefile.MULTIPOINTZ, stakes), UTM23S_WKT)

# a bare .shp in local coordinates (no dbf, no prj)
w = shapefile.Writer(shp=io.BytesIO(), shx=io.BytesIO(), dbf=io.BytesIO(), shapeType=shapefile.POLYLINE)
w.field('X', 'N')
w.line([[(0, 0), (50, 5), (100, 0)]])
w.record(1)
w.line([[(0, 20), (50, 25), (100, 20)]])
w.record(2)
w.close()
write('shp_lines_local.shp', w.shp.getvalue())

# ----------------------------------------------------------------- GeoTIFF
print('GeoTIFF')


def geokeys(*keys):
    # KeyDirectoryVersion, KeyRevision, MinorRevision, NumberOfKeys, then (id, location, count, value)
    out = [1, 1, 0, len(keys)]
    for k, v in keys:
        out += [k, 0, 1, v]
    return tuple(out)


def tiff(name, arr, scale, tiepoint, keys, nodata=None, photometric='minisblack'):
    tags = [
        (33550, 'd', 3, tuple(scale), True),
        (33922, 'd', 6, tuple(tiepoint), True),
        (34735, 'H', len(keys), keys, True),
    ]
    if nodata is not None:
        tags.append((42113, 's', 0, nodata, True))
    buf = io.BytesIO()
    tifffile.imwrite(buf, arr, photometric=photometric, extratags=tags, metadata=None)
    write(name, buf.getvalue())


# 40×30 float DEM, 5 m pixels, UTM 23S, plane z = 600 + 0.5·col − 0.25·row, one nodata pixel
dem = np.fromfunction(lambda r, c: 600 + 0.5 * c - 0.25 * r, (30, 40), dtype=np.float64).astype(np.float32)
dem[0, 0] = -9999
tiff('dem_utm_float32.tif', dem, (5, 5, 0), (0, 0, 0, E0, N0 + 150, 0), geokeys((1024, 1), (1025, 1), (3072, 32723)), nodata='-9999')
# 20×20 int16 DEM in geographic coordinates (EPSG:4326), 0.0001° pixels, nodata −32768 on the last row
demi = np.fromfunction(lambda r, c: 900 + c - r, (20, 20), dtype=np.float64).astype(np.int16)
demi[19, :] = -32768
tiff('dem_wgs84_int16.tif', demi, (0.0001, 0.0001, 0), (0, 0, 0, -47.93, -15.78, 0), geokeys((1024, 2), (1025, 1), (2048, 4326)), nodata='-32768')
# an RGB orthophoto with UTM tags: a picture, not a DEM
rgb = np.zeros((48, 64, 3), dtype=np.uint8)
rgb[..., 0] = np.linspace(0, 255, 64, dtype=np.uint8)[None, :]
rgb[..., 1] = 120
rgb[:24, :, 2] = 200
tiff('ortho_utm_rgb.tif', rgb, (0.5, 0.5, 0), (0, 0, 0, E0, N0 + 24, 0), geokeys((1024, 1), (1025, 1), (3072, 32723)), photometric='rgb')

# ----------------------------------------------------------------- images
print('images')
im = Image.new('RGB', (64, 48), (200, 220, 240))
d = ImageDraw.Draw(im)
d.rectangle((8, 8, 56, 40), outline=(20, 90, 20), width=3)
png = io.BytesIO()
im.save(png, 'PNG')
write('plain.png', png.getvalue())
jpg = io.BytesIO()
Image.new('RGB', (80, 60), (90, 140, 60)).save(jpg, 'JPEG', quality=85)
write('photo.jpg', jpg.getvalue())


def world_zip(name, a, d, b, e, c, f, prj=UTM23S_WKT):
    z = io.BytesIO()
    with zipfile.ZipFile(z, 'w') as zf:
        zf.writestr('ortho.png', png.getvalue())
        zf.writestr('ortho.pgw', f'{a}\n{d}\n{b}\n{e}\n{c}\n{f}\n')
        zf.writestr('ortho.prj', prj)
    write(name, z.getvalue())


# 0.5 m pixels, north up: centre of the top-left pixel at (E0 + 0.25, N0 + 24 − 0.25)
world_zip('ortho_world_utm.zip', 0.5, 0, 0, -0.5, E0 + 0.25, N0 + 24 - 0.25)
# the same image rotated 30° counter-clockwise on the map (x' = A·col + B·row + C, y' = D·col + E·row + F)
import math
s, th = 0.5, math.radians(30)
world_zip('ortho_world_rotated.zip', s * math.cos(th), s * math.sin(th), s * math.sin(th), -s * math.cos(th), E0, N0)

# ----------------------------------------------------------------- DXF / DWG (ezdxf, LibreDWG)
print('DXF / DWG')


def client_drawing(version, units=6, scale=1.0):
    doc = ezdxf.new(version, setup=False)
    if version != 'R12':
        doc.header['$INSUNITS'] = units
    doc.layers.add('CURVAS', color=3)
    doc.layers.add('DIVISA', color=1)
    doc.layers.add('TEXTO', color=2)
    msp = doc.modelspace()
    S = scale
    msp.add_line((0, 0, 0), (100 * S, 50 * S, 0), dxfattribs={'layer': 'DIVISA'})
    if version == 'R12':
        msp.add_polyline2d([(0, 0), (100 * S, 0), (100 * S, 80 * S), (0, 80 * S)], close=True, dxfattribs={'layer': 'DIVISA'})
        msp.add_polyline2d([(0, 10 * S), (50 * S, 12 * S), (100 * S, 10 * S)], dxfattribs={'layer': 'CURVAS', 'elevation': (0, 0, 550 * S)})
    else:
        msp.add_lwpolyline([(0, 0), (100 * S, 0), (100 * S, 80 * S), (0, 80 * S)], close=True, dxfattribs={'layer': 'DIVISA'})
        msp.add_lwpolyline([(0, 10 * S), (50 * S, 12 * S), (100 * S, 10 * S)], dxfattribs={'layer': 'CURVAS', 'elevation': 550 * S})
        # a lateral with a curved corner: bulge = tan(θ/4) for a 90° arc
        msp.add_lwpolyline([(0, 60 * S, 0), (40 * S, 60 * S, 1.0), (50 * S, 70 * S, 0), (50 * S, 78 * S, 0)], format='xyb', dxfattribs={'layer': 'DIVISA'})
        msp.add_mtext('Linha 1\\PLinha 2', dxfattribs={'layer': 'TEXTO', 'char_height': 2 * S}).set_location((60 * S, 70 * S))
    msp.add_polyline3d([(0, 20 * S, 555 * S), (50 * S, 22 * S, 555 * S), (100 * S, 20 * S, 555 * S)], dxfattribs={'layer': 'CURVAS'})
    msp.add_circle((50 * S, 40 * S), 5 * S, dxfattribs={'layer': '0'})
    msp.add_arc((50 * S, 40 * S), 10 * S, 0, 90, dxfattribs={'layer': '0'})
    msp.add_text('Reservatório', dxfattribs={'layer': 'TEXTO', 'height': 2.5 * S, 'rotation': 30}).set_placement((10 * S, 70 * S))
    msp.add_point((30 * S, 30 * S, 612.5 * S), dxfattribs={'layer': 'CURVAS'})
    # a block (well symbol) inserted twice, one scaled and rotated
    blk = doc.blocks.new(name='POCO')
    blk.add_circle((0, 0), 1 * S)
    blk.add_line((-1 * S, 0), (1 * S, 0))
    msp.add_blockref('POCO', (80 * S, 60 * S), dxfattribs={'layer': 'DIVISA'})
    msp.add_blockref('POCO', (90 * S, 60 * S), dxfattribs={'layer': 'DIVISA', 'xscale': 2, 'yscale': 2, 'rotation': 45})
    return doc


for version, name in (('R2000', 'client_r2000.dxf'), ('R12', 'client_r12.dxf'), ('R2018', 'client_r2018.dxf')):
    doc = client_drawing(version)
    doc.saveas(OUT / name)
    print(f'  {name} ({(OUT / name).stat().st_size} bytes)')
# millimetres: $INSUNITS = 4 and every coordinate ×1000
client_drawing('R2010', units=4, scale=1000.0).saveas(OUT / 'client_mm_r2010.dxf')
print('  client_mm_r2010.dxf')

if shutil.which('dxf2dwg'):
    for ver in ('r2000',):
        target = OUT / f'client_{ver}.dwg'
        if target.exists():
            target.unlink()
        r = subprocess.run(['dxf2dwg', '--as', ver, '-y', '-o', str(target), str(OUT / 'client_r2000.dxf')], capture_output=True, text=True)
        if r.returncode == 0 and target.exists():
            print(f'  {target.name} ({target.stat().st_size} bytes)')
        else:
            print(f'  {target.name}: dxf2dwg failed ({r.returncode}) {r.stderr[-300:]}')
else:
    print('  dxf2dwg not installed: DWG fixtures not rewritten')

# ----------------------------------------------------------------- KML / KMZ
print('KML / KMZ')
kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
\t<name>Fazenda Boa Vista.kmz</name>
\t<Style id="s_ylw"><LineStyle><color>ff00ffff</color><width>2</width></LineStyle><PolyStyle><color>4d00ffff</color></PolyStyle></Style>
\t<Schema name="curvas" id="curvas_schema"><SimpleField name="cota" type="double"/></Schema>
\t<Folder>
\t\t<name>Infraestrutura</name>
\t\t<Placemark>
\t\t\t<name>Poço &amp; casa de bombas</name>
\t\t\t<description><![CDATA[Vazão 30 m³/h]]></description>
\t\t\t<styleUrl>#s_ylw</styleUrl>
\t\t\t<Point><altitudeMode>absolute</altitudeMode><coordinates>-47.9295,-15.7795,1048.5</coordinates></Point>
\t\t</Placemark>
\t\t<Folder>
\t\t\t<name>Adutora</name>
\t\t\t<Placemark>
\t\t\t\t<name>Adutora principal</name>
\t\t\t\t<LineString><tessellate>1</tessellate><coordinates>
\t\t\t\t\t-47.9295,-15.7795,0 -47.929,-15.779,0
\t\t\t\t\t-47.928,-15.779,0
\t\t\t\t</coordinates></LineString>
\t\t\t</Placemark>
\t\t</Folder>
\t</Folder>
\t<Folder>
\t\t<name>Curvas</name>
\t\t<Placemark>
\t\t\t<name>1050</name>
\t\t\t<LineString><coordinates>-47.9300,-15.7800,1050 -47.9290,-15.7800,1050 -47.9280,-15.7801,1050</coordinates></LineString>
\t\t</Placemark>
\t\t<Placemark>
\t\t\t<name>1055</name>
\t\t\t<ExtendedData><SchemaData schemaUrl="#curvas_schema"><SimpleData name="cota">1055</SimpleData></SchemaData></ExtendedData>
\t\t\t<MultiGeometry>
\t\t\t\t<LineString><coordinates>-47.9300,-15.7790 -47.9290,-15.7790</coordinates></LineString>
\t\t\t\t<LineString><coordinates>-47.9285,-15.7790 -47.9280,-15.7790</coordinates></LineString>
\t\t\t</MultiGeometry>
\t\t</Placemark>
\t</Folder>
\t<Placemark>
\t\t<name>Talhão 1</name>
\t\t<Polygon><outerBoundaryIs><LinearRing><coordinates>
\t\t\t-47.9300,-15.7800,0 -47.9280,-15.7800,0 -47.9280,-15.7790,0 -47.9300,-15.7790,0 -47.9300,-15.7800,0
\t\t</coordinates></LinearRing></outerBoundaryIs>
\t\t<innerBoundaryIs><LinearRing><coordinates>-47.9295,-15.7797,0 -47.9290,-15.7797,0 -47.9290,-15.7794,0 -47.9295,-15.7794,0 -47.9295,-15.7797,0</coordinates></LinearRing></innerBoundaryIs></Polygon>
\t</Placemark>
</Document>
</kml>
'''
write('earth_farm.kml', kml)
z = io.BytesIO()
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('doc.kml', kml)
    zf.writestr('files/logo.png', png.getvalue())
write('earth_farm.kmz', z.getvalue())

# ----------------------------------------------------------------- catalogues
print('catalogues')
write('catalog_pipes.csv', '﻿id;name;nominalMm;idMm;material;c;ratingM;cost;supplier;code\r\n'
      'pvc50;"Tubo PVC PN60 DN50";50;46,4;pvc;150;60;8,90;"Fábrica X";"PVC-50-60"\r\n'
      'pvc75;"Tubo PVC PN60 DN75";75;70,4;pvc;150;60;15,20;"Fábrica X";"PVC-75-60"\r\n'
      'pe32;"PE 32 PN4";32;28;pe;140;40;2,10;"Fábrica Y";"PE32"\r\n')
wb = openpyxl.Workbook()
ws = wb.active
ws.title = 'pipes'
ws.append(['id', 'name', 'nominalMm', 'idMm', 'material', 'c', 'ratingM', 'cost'])
ws.append(['pvc50', 'Tubo PVC PN60 DN50', 50, 46.4, 'pvc', 150, 60, 8.9])
ws.append(['pvc100', 'Tubo PVC PN80 DN100', 100, 93.6, 'pvc', 150, 80, 22.5])
ws2 = wb.create_sheet('outlets')
ws2.append(['id', 'name', 'kind', 'nozzle', 'qLph', 'headM', 'x', 'radiusM', 'cost'])
ws2.append(['asp1', 'Aspersor 1/2"', 'sprinkler', 'bocal 3.0', 850, 25, 0.5, 12, 18.5])
ws2.append(['asp1', 'Aspersor 1/2"', 'sprinkler', 'bocal 3.5', 1100, 25, 0.5, 13, 18.5])
ws2.append(['mic1', 'Microaspersor', 'micro', '', 70, 15, 0.5, 3.5, 2.3])
x = io.BytesIO()
wb.save(x)
write('catalog.xlsx', x.getvalue())
print('done')
