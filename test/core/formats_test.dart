import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:xml/xml.dart';

/// Every import format against files written by other software (ezdxf,
/// LibreDWG, pyshp, tifffile, Pillow, openpyxl, Google Earth style KML; see
/// tool/formats/make_fixtures.py) and every export format round-tripped
/// through our readers. The exports are also written to build/formats for
/// tool/formats/check_exports.py, which validates them with third-party
/// readers.
const e0 = 186056.581, n0 = 8253215.209; // Brasília, UTM 23S (metres)
final fixtures = Directory('test/fixtures/formats');
Uint8List fixture(String name) => File('${fixtures.path}/$name').readAsBytesSync();

ProjectController fresh() {
  final c = ProjectController();
  c.setLanguage('pt');
  c.newProject();
  return c;
}

(ProjectController, String) imported(String name) {
  final c = fresh();
  return (c, c.importFile(name, fixture(name)));
}

Matcher near(Pt p, [double tol = 0.01]) => predicate<Pt>((q) => q.distanceTo(p) < tol, 'within $tol of $p');

void main() {
  group('survey points', () {
    test('PNEZD without header: id, northing, easting, elevation, description', () {
      final (c, s) = imported('survey_pnezd.txt');
      expect(s, contains('4'));
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 4);
      expect(pts.first.position, near(const Pt(e0, n0), 1e-3));
      expect(pts.first.elevation, 1050);
      expect(pts.first.name, '1');
      expect(pts[3].position, near(const Pt(e0 + 75, n0 + 30), 1e-3));
      expect(pts[3].elevation, closeTo(1051.5, 1e-9));
      expect(c.project.meta.georef, isNull, reason: 'projected coordinates without a CRS stay as they are');
    });

    test('Windows-1252 CSV with header, semicolons and decimal commas', () {
      final (c, _) = imported('survey_header_cp1252.csv');
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 3);
      expect(pts.first.position, near(const Pt(186056.58, 8253215.21), 1e-6));
      expect(pts.map((p) => p.elevation), [1050, 1050.5, 1051]);
      expect(pts.first.name, 'P1');
    });

    test('lat/lon columns are projected and georeference the project', () {
      final (c, s) = imported('survey_latlon.csv');
      expect(s, contains('UTM 23S'));
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 3);
      expect(c.project.meta.georef!.zone, 23);
      expect(c.project.meta.georef!.north, isFalse);
      expect(pts[0].position.distanceTo(pts[1].position), closeTo(107.1, 0.5)); // 0.001° of longitude at 15.78° S
      expect(pts[0].position.distanceTo(pts[2].position), closeTo(110.6, 0.5)); // 0.001° of latitude
      expect(pts[1].elevation, 1051.5);
      expect(pts.map((p) => p.name), ['A', 'B', 'C']);
      final (lat, lon) = c.project.meta.georef!.toLatLon(pts[0].position.x, pts[0].position.y);
      expect(lat, closeTo(-15.78, 1e-7));
      expect(lon, closeTo(-47.93, 1e-7));
    });

    test('XYZ with spaces and comments, TXT with tabs and a header', () {
      final (c, _) = imported('survey_local.xyz');
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 4);
      expect(pts[2].position, near(const Pt(110, 210), 1e-9));
      expect(pts[3].elevation, 52);
      final (c2, _) = imported('survey_tab_header.txt');
      final tab = c2.project.entities.whereType<SpotHeightEntity>().toList();
      expect(tab.map((p) => p.name), ['TQ', 'POCO']);
      expect(tab.map((p) => p.elevation), [5.5, 6.0]);
      expect(tab[1].position, near(const Pt(30, 20), 1e-9));
    });
  });

  group('shapefiles (pyshp)', () {
    test('UTM polygons in a zip: parcels, attributes in UTF-8, georeference from the .prj', () {
      final (c, s) = imported('shp_parcels_utm.zip');
      expect(s, contains('SHP'));
      final g = c.project.meta.georef!;
      expect((g.zone, g.north), (23, false));
      final polys = c.project.entities.whereType<PolylineEntity>().toList();
      expect(polys.length, 2);
      expect(polys.every((p) => p.closed), isTrue);
      expect(polys.first.points.length, 4, reason: 'the repeated closing vertex is dropped');
      expect(polys.map((p) => p.name), ['Talhão 1', 'Talhão 2']);
      expect(polys.first.layer, 'talhoes');
      final b = polys.first.bounds;
      expect(b.width, closeTo(300, 1e-6));
      expect(b.height, closeTo(200, 1e-6));
      expect(b.minX + g.originEasting, closeTo(e0, 1e-6));
      expect(b.minY + g.originNorthing, closeTo(n0, 1e-6));
      expect(c.project.entities.whereType<ContourEntity>(), isEmpty);
    });

    test('PolylineZ contours with an ELEV attribute', () {
      final (c, _) = imported('shp_contours_z_utm.zip');
      final cs = c.project.entities.whereType<ContourEntity>().toList();
      expect(cs.length, 3);
      expect(cs.map((x) => x.elevation), [1050, 1052, 1054]);
      expect(cs.every((x) => x.points.length == 7), isTrue);
      final g = c.project.meta.georef!;
      expect(cs.first.points.first.x + g.originEasting, closeTo(e0, 1e-6));
      expect(cs.first.points.last.x + g.originEasting, closeTo(e0 + 300, 1e-6));
    });

    test('WGS84 points with COTA and NOME attributes', () {
      final (c, _) = imported('shp_wells_wgs84.zip');
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 3);
      expect(pts.map((p) => p.elevation), [1048.5, 1049, 1047.2]);
      expect(pts.map((p) => p.name), ['Poço 1', 'Poço 2', 'Poço 3']);
      expect(c.project.meta.georef!.zone, 23);
      expect(pts[0].position.distanceTo(pts[1].position), closeTo(107.1, 0.5));
    });

    test('MultiPointZ keeps one elevation per point', () {
      final (c, _) = imported('shp_stakes_multipointz.zip');
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.map((p) => p.elevation), [1060, 1061, 1062]);
      expect(pts[1].position.distanceTo(pts[0].position), closeTo(10, 1e-6));
    });

    test('a bare .shp in local coordinates keeps them', () {
      final (c, _) = imported('shp_lines_local.shp');
      final polys = c.project.entities.whereType<PolylineEntity>().toList();
      expect(polys.length, 2);
      expect(polys.first.points, [const Pt(0, 0), const Pt(50, 5), const Pt(100, 0)]);
      expect(polys.first.layer, 'shp_lines_local');
      expect(c.project.meta.georef, isNull);
    });
  });

  group('GeoTIFF (tifffile)', () {
    test('float32 UTM elevation raster becomes a grid of spot heights', () {
      final (c, s) = imported('dem_utm_float32.tif');
      expect(s, contains('GeoTIFF'));
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 40 * 30 - 1, reason: 'one nodata pixel');
      final g = c.project.meta.georef!;
      expect((g.zone, g.north), (23, false));
      final zs = pts.map((p) => p.elevation);
      expect(zs.reduce(math.min), closeTo(592.75, 1e-4));
      expect(zs.reduce(math.max), closeTo(619.5, 1e-4));
      final top = pts.reduce((a, b) => a.elevation >= b.elevation ? a : b);
      // pixel (39, 0): centre 197.5 m east and 2.5 m below the raster's top edge
      expect(top.position, near(Pt(e0 + 197.5 - g.originEasting, n0 + 150 - 2.5 - g.originNorthing), 1e-4));
      expect(c.project.entities.whereType<ImageEntity>(), isEmpty);
    });

    test('int16 geographic raster with nodata', () {
      final (c, _) = imported('dem_wgs84_int16.tif');
      final pts = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(pts.length, 20 * 19, reason: 'the nodata row is skipped');
      final zs = pts.map((p) => p.elevation);
      expect(zs.reduce(math.min), 882);
      expect(zs.reduce(math.max), 919);
      final g = c.project.meta.georef!;
      expect((g.zone, g.north), (23, false));
      // 0.0001° ≈ 10.71 m east-west and 11.06 m north-south at this latitude (UTM scale 1.0008)
      expect(pts[0].position.distanceTo(pts[1].position), closeTo(10.72, 0.05));
      expect(pts[0].position.distanceTo(pts[20].position), closeTo(11.07, 0.05));
    });

    test('an RGB orthophoto with UTM tags is a background image, not a DEM', () {
      final (c, s) = imported('ortho_utm_rgb.tif');
      expect(s, contains('64×48'));
      final im = c.project.entities.whereType<ImageEntity>().single;
      expect(c.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      expect(im.width, closeTo(32, 1e-6));
      expect(im.height, closeTo(24, 1e-6));
      expect(im.rotationDeg, 0);
      expect(im.mime, 'image/png');
      final g = c.project.meta.georef!;
      expect(im.origin, near(Pt(e0 - g.originEasting, n0 - g.originNorthing), 1e-6));
    });
  });

  group('images (Pillow)', () {
    test('PNG with a world file and .prj in a zip', () {
      final (c, s) = imported('ortho_world_utm.zip');
      expect(s, contains('UTM 23S'));
      final im = c.project.entities.whereType<ImageEntity>().single;
      final g = c.project.meta.georef!;
      expect(im.width, closeTo(32, 1e-6));
      expect(im.height, closeTo(24, 1e-6));
      expect(im.origin, near(Pt(e0 - g.originEasting, n0 - g.originNorthing), 1e-6));
      expect(im.mime, 'image/png');
      expect(im.source, 'ortho.png');
    });

    test('a rotated world file places the corners where the affine transform says', () {
      final (c, _) = imported('ortho_world_rotated.zip');
      final im = c.project.entities.whereType<ImageEntity>().single;
      final g = c.project.meta.georef!;
      // x' = A·col + B·row + C, y' = D·col + E·row + F for pixel centres; corners at ±0.5
      const s = 0.5, th = 30 * math.pi / 180;
      final a = s * math.cos(th), d = s * math.sin(th), b = s * math.sin(th), e = -s * math.cos(th);
      Pt world(double col, double row) => Pt(a * col + b * row + e0 - g.originEasting, d * col + e * row + n0 - g.originNorthing);
      final corners = im.corners; // bottom-left, bottom-right, top-right, top-left
      expect(corners[0], near(world(-0.5, 47.5), 1e-3));
      expect(corners[1], near(world(63.5, 47.5), 1e-3));
      expect(corners[2], near(world(63.5, -0.5), 1e-3));
      expect(corners[3], near(world(-0.5, -0.5), 1e-3));
      expect(im.rotationDeg, closeTo(30, 1e-6));
      expect(im.width, closeTo(32, 1e-6));
      expect(im.height, closeTo(24, 1e-6));
    });

    test('plain JPG and PNG are placed in the view with their bytes kept', () {
      final (c, s) = imported('photo.jpg');
      expect(s, contains('80×60'));
      final im = c.project.entities.whereType<ImageEntity>().single;
      expect(im.mime, 'image/jpeg');
      expect(im.data, fixture('photo.jpg'));
      expect(im.width / im.height, closeTo(80 / 60, 1e-9));
      expect(c.project.meta.georef, isNull);
      final (c2, _) = imported('plain.png');
      final png = c2.project.entities.whereType<ImageEntity>().single;
      expect(png.mime, 'image/png');
      expect(png.data, fixture('plain.png'));
    });
  });

  void checkClientDrawing(ProjectController c, {bool blocks = true, bool mtext = true, double tol = 1e-6}) {
    final ents = c.project.entities;
    for (final l in ['CURVAS', 'DIVISA', 'TEXTO']) {
      expect(c.project.layers.map((x) => x.name), contains(l));
    }
    final line = ents.whereType<LineEntity>().where((l) => l.layer == 'DIVISA').toList();
    expect(line.length, blocks ? 3 : 1, reason: 'one line plus one per inserted block');
    final boundary = ents.whereType<LineEntity>().firstWhere((l) => l.b.distanceTo(const Pt(100, 50)) < tol);
    expect(boundary.a, near(Pt.zero, tol));
    final contours = ents.whereType<ContourEntity>().toList();
    expect(contours.map((x) => x.elevation).toList()..sort(), [550, 555]);
    expect(contours.every((x) => x.points.length == 3), isTrue);
    final c550 = contours.firstWhere((x) => x.elevation == 550);
    expect(c550.points[1], near(const Pt(50, 12), tol));
    final polys = ents.whereType<PolylineEntity>().toList();
    final closed = polys.firstWhere((p) => p.closed);
    expect(closed.points.length, 4);
    expect(closed.points[2], near(const Pt(100, 80), tol));
    final circles = ents.whereType<CircleEntity>().toList();
    final main = circles.firstWhere((x) => (x.radius - 5).abs() < tol);
    expect(main.center, near(const Pt(50, 40), tol));
    final arc = ents.whereType<ArcEntity>().single;
    expect(arc.radius, closeTo(10, tol));
    expect(arc.startRad, closeTo(0, 1e-6));
    expect(arc.sweepRad, closeTo(math.pi / 2, 1e-6));
    final text = ents.whereType<TextEntity>().firstWhere((t) => t.text == 'Reservatório');
    expect(text.height, closeTo(2.5, tol));
    expect(text.rotationDeg, closeTo(30, 1e-6));
    expect(text.position, near(const Pt(10, 70), tol));
    expect(text.layer, 'TEXTO');
    if (mtext) expect(ents.whereType<TextEntity>().any((t) => t.text.contains('Linha 1') && t.text.contains('Linha 2')), isTrue);
    final spot = ents.whereType<SpotHeightEntity>().single;
    expect(spot.position, near(const Pt(30, 30), tol));
    expect(spot.elevation, closeTo(612.5, tol));
    if (blocks) {
      // the POCO block: a circle of radius 1 at (80, 60) and one scaled ×2 at (90, 60)
      expect(circles.where((x) => (x.radius - 1).abs() < tol && x.center.distanceTo(const Pt(80, 60)) < tol).length, 1);
      expect(circles.where((x) => (x.radius - 2).abs() < tol && x.center.distanceTo(const Pt(90, 60)) < tol).length, 1);
      final rotated = ents.whereType<LineEntity>().firstWhere((l) => l.a.distanceTo(Pt(90 - math.sqrt(2), 60 - math.sqrt(2))) < 1e-6);
      expect(rotated.b, near(Pt(90 + math.sqrt(2), 60 + math.sqrt(2)), 1e-6));
    }
  }

  group('DXF (ezdxf)', () {
    test('R2000 (cp1252): lines, polylines, contours, blocks, texts and points', () {
      final (c, s) = imported('client_r2000.dxf');
      expect(s, contains('DXF'));
      checkClientDrawing(c);
      // the polyline with a bulge is imported as an arc-approximated polyline
      final bulged = c.project.entities.whereType<PolylineEntity>().firstWhere((p) => !p.closed && p.points.first.distanceTo(const Pt(0, 60)) < 1e-6);
      expect(bulged.points.length, greaterThan(4));
      expect(bulged.points.last, near(const Pt(50, 78), 1e-6));
      // bulge 1 = a semicircle from (40,60) to (50,70), centred on the chord midpoint
      final arc = bulged.points.where((p) => p.distanceTo(const Pt(45, 65)) > 1e-6 && p.x > 40 && p.y < 70 && !(p.x == 50 && p.y == 78));
      expect(arc.length, greaterThanOrEqualTo(9));
      for (final p in arc) {
        expect(p.distanceTo(const Pt(45, 65)), closeTo(math.sqrt(50), 1e-6));
      }
    });

    test('R12 (POLYLINE/VERTEX, no drawing units header) and R2018 (UTF-8)', () {
      final (c12, _) = imported('client_r12.dxf');
      checkClientDrawing(c12, mtext: false);
      final (c18, _) = imported('client_r2018.dxf');
      checkClientDrawing(c18);
    });

    test('millimetre drawings are scaled to metres from the drawing units header', () {
      final (c, _) = imported('client_mm_r2010.dxf');
      checkClientDrawing(c, tol: 1e-6);
    });
  });

  group('DWG (LibreDWG)', () {
    test('R2000 written by LibreDWG from the ezdxf drawing', () {
      final (c, s) = imported('client_r2000.dwg');
      expect(s, contains('DWG R2000'));
      expect(s, isNot(contains('ignorados')));
      checkClientDrawing(c);
    });

    test('curves read back as from the DXF: hatch edges, bulges, splines, 2D polylines, scaled blocks, MINSERT', () {
      final dxf = DxfReader.parse(utf8.decode(fixture('curves_r2000.dxf'))).entities;
      final r = DwgReader.parse(fixture('curves_r2000.dwg'));
      expect(r.warnings, isEmpty);
      final dwg = r.document.entities;
      expect(dwg.map((e) => e.type).toList(), dxf.map((e) => e.type).toList());
      // the same geometry, whatever the arc tessellation step of each reader
      double gap(List<Pt> a, List<Pt> b, bool closed) {
        var worst = 0.0;
        for (final p in a) {
          var best = double.infinity;
          for (var i = 1; i < b.length + (closed ? 1 : 0); i++) {
            best = math.min(best, distanceToSegment(p, b[i - 1], b[i % b.length]));
          }
          worst = math.max(worst, best);
        }
        return worst;
      }

      for (var i = 0; i < dxf.length; i++) {
        final a = dxf[i], b = dwg[i];
        if (a.center != null) {
          expect(b.center, near(a.center!, 1e-9));
          expect(b.radius, closeTo(a.radius, 1e-9));
        }
        if (a.points.length >= 2) {
          expect(gap(a.points, b.points, a.closed), lessThan(0.05), reason: '${a.type} #$i');
          expect(gap(b.points, a.points, a.closed), lessThan(0.05), reason: '${a.type} #$i');
        }
        expect(b.closed, a.closed);
      }
      // edge boundary: line, arc to x = 15, elliptic arc to y = 12, spline to x = −1.5
      final edges = Bounds.ofPoints(dwg.first.points);
      expect(edges.maxX, closeTo(15, 1e-6));
      expect(edges.maxY, closeTo(12, 1e-6));
      expect(edges.minX, closeTo(-1.5, 0.01));
      expect(dwg.first.rotation, closeTo(75, 1e-9), reason: 'ANSI31 (45°) turned 30°');
      // the 2D polyline keeps its semicircle below the chord
      final heavy = dwg.firstWhere((e) => e.type == 'POLYLINE' && e.points.first.distanceTo(const Pt(0, 20)) < 1e-9);
      expect(heavy.points.map((p) => p.y).reduce(math.min), closeTo(15, 1e-6));
      // blocks: an uneven scale turns the circle into an ellipse, the array makes 3 × 2 copies
      final ellipse = dwg.firstWhere((e) => e.type == 'POLYLINE' && e.closed && e.points.length > 20 && e.points.first.x > 37);
      final eb = Bounds.ofPoints(ellipse.points);
      expect(eb.width, closeTo(4, 1e-6));
      expect(eb.height, closeTo(6, 1e-6));
      expect(dwg.where((e) => e.type == 'CIRCLE').map((e) => e.center), unorderedEquals([for (final y in [20.0, 25.0]) for (final x in [60.0, 64.0, 68.0]) Pt(x, y)]));
      // a left text sits on its insertion point, a centred one on its alignment point
      for (final doc in [dxf, dwg]) {
        expect(doc.singleWhere((e) => e.text == 'Esquerda').points.single, near(const Pt(0, -5), 1e-9));
        expect(doc.singleWhere((e) => e.text == 'Centro').points.single, near(const Pt(20, -5), 1e-9));
      }
    });

  });

  group('extrusion (0, 0, −1): mirrored object coordinates', () {
    // world positions as ezdxf's arbitrary axis algorithm gives them (see
    // ocs_drawing in tool/formats/make_fixtures.py)
    void checkOcs(DxfDocument d) {
      DxfEntity one(String type, bool Function(DxfEntity) where) => d.entities.where((e) => e.type == type && where(e)).single;
      final circle = one('CIRCLE', (_) => true);
      expect(circle.center, near(const Pt(-10, 5), 1e-9));
      expect(circle.radius, 2);
      final arc = one('ARC', (e) => e.radius == 4);
      expect(arc.center, near(const Pt(-10, 5), 1e-9));
      // clockwise from (−14, 5) to (−10, 9) = counter-clockwise from 90° to 180°
      expect(arc.startAngle, closeTo(90, 1e-9));
      expect(arc.endAngle, closeTo(180, 1e-9));
      // the bulge now bends to the world −X side
      final lw = one('POLYLINE', (e) => e.points.first.distanceTo(Pt.zero) < 1e-9 && e.points.length > 3);
      expect(lw.points[1], near(const Pt(-10, 0), 1e-9));
      expect(lw.points.last, near(const Pt(-10, 10), 1e-9));
      expect(lw.points.map((p) => p.x).reduce(math.min), closeTo(-15, 1e-6));
      final text = one('TEXT', (e) => e.text == 'OCS');
      expect(text.points.single, near(const Pt(-20, 5), 1e-9));
      // the quarter ellipse ends below its centre (minor axis = extrusion × major)
      final ellipse = one('POLYLINE', (e) => e.points.first.distanceTo(const Pt(6, -20)) < 1e-9);
      expect(ellipse.points.last, near(const Pt(0, -23), 1e-6));
      // the hatch (a solid fill by ezdxf's default) and the SOLID
      bool spans(DxfEntity e, double x) => e.points.any((p) => (p.x.abs() - x).abs() < 1e-6);
      final hatch = one('HATCH', (e) => spans(e, 44));
      expect(Bounds.ofPoints(hatch.points).minX, closeTo(-44, 1e-9));
      expect(Bounds.ofPoints(hatch.points).maxX, closeTo(-40, 1e-9));
      final solid = one('HATCH', (e) => spans(e, 52));
      expect(Bounds.ofPoints(solid.points).minX, closeTo(-52, 1e-9));
      expect(Bounds.ofPoints(solid.points).maxX, closeTo(-50, 1e-9));
      // the block inserted with the extrusion: the line runs to −X and the arc turns
      final blockLine = one('LINE', (e) => e.points.first.distanceTo(const Pt(-30, 0)) < 1e-9);
      expect(blockLine.points.last, near(const Pt(-32, 0), 1e-9));
      final blockArc = one('ARC', (e) => e.radius == 1);
      expect(blockArc.center, near(const Pt(-30, 0), 1e-9));
      expect(blockArc.startAngle, closeTo(90, 1e-9));
      expect(blockArc.endAngle, closeTo(180, 1e-9));
      // LINE and MTEXT are in world coordinates whatever the extrusion
      expect(one('LINE', (e) => e.points.first.distanceTo(Pt.zero) < 1e-9).points.last, near(const Pt(1, 1), 1e-9));
      expect(one('TEXT', (e) => e.text == 'WCS').points.single, near(const Pt(60, 0), 1e-9));
    }

    test('DXF written by ezdxf', () {
      checkOcs(DxfReader.parse(utf8.decode(fixture('ocs_mirrored_r2000.dxf'))));
    });

    test('DWG written by LibreDWG from it', () {
      final r = DwgReader.parse(fixture('ocs_mirrored_r2000.dwg'));
      expect(r.warnings.where((w) => w.startsWith('object_error')), isEmpty);
      checkOcs(r.document);
    });

    test('the imported arcs stay arcs on the mirrored side', () {
      final (c, _) = imported('ocs_mirrored_r2000.dwg');
      final arc = c.project.entities.whereType<ArcEntity>().firstWhere((a) => (a.radius - 4).abs() < 1e-9);
      expect(arc.startPoint, near(const Pt(-10, 9), 1e-9));
      expect(arc.endPoint, near(const Pt(-14, 5), 1e-9));
    });
  });

  test('a mirrored block keeps its circles and arcs, turned the other way', () {
    final d = DxfReader.parse([
      '0', 'SECTION', '2', 'BLOCKS', '0', 'BLOCK', '2', 'B', '10', '0', '20', '0',
      '0', 'ARC', '8', '0', '10', '0', '20', '0', '40', '1', '50', '0', '51', '90',
      '0', 'CIRCLE', '8', '0', '10', '2', '20', '0', '40', '0.5',
      '0', 'TEXT', '8', '0', '10', '0', '20', '0', '40', '1', '1', 'T', '50', '30',
      '0', 'ENDBLK', '0', 'ENDSEC',
      '0', 'SECTION', '2', 'ENTITIES', '0', 'INSERT', '8', 'L', '2', 'B', '10', '10', '20', '0', '41', '-2', '42', '2',
      '0', 'ENDSEC', '0', 'EOF',
    ].join('\n'));
    final arc = d.entities.singleWhere((e) => e.type == 'ARC');
    expect(arc.center, near(const Pt(10, 0), 1e-9));
    expect(arc.radius, 2);
    // x → −x: the quarter from 0° to 90° becomes the one from 90° to 180°
    expect(arc.startAngle, closeTo(90, 1e-9));
    expect(arc.endAngle, closeTo(180, 1e-9));
    final circle = d.entities.singleWhere((e) => e.type == 'CIRCLE');
    expect(circle.center, near(const Pt(6, 0), 1e-9));
    expect(circle.radius, 1);
    // a text at 30° now runs at 150°
    expect(d.entities.singleWhere((e) => e.type == 'TEXT').rotation, closeTo(150, 1e-9));
  });

  void checkFarm(ProjectController c) {
    expect(c.project.layers.map((l) => l.name), containsAll(['Infraestrutura', 'Adutora', 'Curvas', 'KML']));
    final well = c.project.entities.whereType<SpotHeightEntity>().single;
    expect(well.elevation, 1048.5);
    expect(well.name, 'Poço & casa de bombas');
    expect(well.layer, Layers.spotHeights);
    expect(c.project.entities.whereType<TextEntity>().single.text, 'Poço & casa de bombas');
    final contours = c.project.entities.whereType<ContourEntity>().toList();
    expect(contours.map((x) => x.elevation).toList()..sort(), [1050, 1055, 1055]);
    expect(contours.firstWhere((x) => x.elevation == 1050).points.length, 3);
    final polys = c.project.entities.whereType<PolylineEntity>().toList();
    final adutora = polys.firstWhere((p) => p.layer == 'Adutora');
    expect(adutora.points.length, 3);
    expect(adutora.closed, isFalse);
    expect(adutora.name, 'Adutora principal');
    final rings = polys.where((p) => p.closed).toList();
    expect(rings.length, 2, reason: 'outer and inner boundary of the parcel');
    expect(rings.every((r) => r.points.length == 4), isTrue);
    expect(rings.every((r) => r.layer == 'KML'), isTrue);
    final outer = rings.reduce((a, b) => a.bounds.width >= b.bounds.width ? a : b);
    final sides = [for (var i = 0; i < 4; i++) outer.points[i].distanceTo(outer.points[(i + 1) % 4])]..sort();
    expect(sides[3], closeTo(214.5, 0.5)); // 0.002° of longitude at 15.78° S
    expect(sides[0], closeTo(110.7, 0.5)); // 0.001° of latitude
    expect(c.project.meta.georef!.zone, 23);
    expect(well.position.x.abs(), lessThan(1000));
  }

  group('KML / KMZ (Google Earth style)', () {
    test('folders, nested folders, MultiGeometry, SchemaData elevation, inner rings, entities', () {
      final (c, s) = imported('earth_farm.kml');
      expect(s, contains('5 marcadores'));
      checkFarm(c);
    });

    test('KMZ with doc.kml and resources', () {
      final (c, s) = imported('earth_farm.kmz');
      expect(s, contains('KMZ'));
      checkFarm(c);
    });
  });

  group('catalogues', () {
    test('manufacturer CSV with BOM, semicolons, quotes and decimal commas', () {
      final r = CatalogIo.parse(utf8.decode(fixture('catalog_pipes.csv')));
      expect(r.group, CatalogGroup.pipes);
      expect(r.count, 3);
      final p = r.catalog.pipe('pvc50')!;
      expect(p.name, 'Tubo PVC PN60 DN50');
      expect(p.nominalMm, 50);
      expect(p.innerDiameterMm, closeTo(46.4, 1e-9));
      expect(p.costPerM, closeTo(8.9, 1e-9));
      expect(p.supplier, 'Fábrica X');
      expect(p.code, 'PVC-50-60');
      expect(p.pressureRatingM, 60);
      final pe = r.catalog.pipe('pe32')!;
      expect(pe.material.name, 'pehd');
      expect(pe.hazenC, 140);
    });

    test('XLSX written by openpyxl (shared strings): pipes and outlets with nozzles', () {
      final r = CatalogIo.parseXlsx(fixture('catalog.xlsx'));
      expect(r.count, 5);
      expect(r.catalog.pipes.map((p) => p.id), ['pvc50', 'pvc100']);
      expect(r.catalog.pipe('pvc100')!.innerDiameterMm, closeTo(93.6, 1e-9));
      expect(r.catalog.outlets.map((o) => o.id), ['asp1', 'mic1']);
      final asp = r.catalog.outlet('asp1')!;
      expect(asp.nozzles.length, 2);
      expect(asp.nozzles.map((n) => n.name), ['bocal 3.0', 'bocal 3.5']);
      expect(asp.nozzles[1].curve.flow(25) * 3.6e6, closeTo(1100, 1e-6)); // m³/s → L/h
      expect(asp.cost, closeTo(18.5, 1e-9));
      expect(r.catalog.outlet('mic1')!.kind.name, 'microSprinkler');
    });
  });

  group('exports', () {
    final out = Directory('build/formats')..createSync(recursive: true);
    void save(String name, Object data) {
      final f = File('${out.path}/$name');
      if (data is Uint8List) {
        f.writeAsBytesSync(data);
      } else {
        f.writeAsStringSync(data as String);
      }
    }

    test('the designed orchard in every drawing, report and catalogue format, round-tripped', () async {
      final c = fresh();
      loadExampleAction(c);
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      await c.runDesign();
      expect(c.results, isNotNull);
      final ex = c.exporter();
      const sheet = SheetOptions(page: PageSize.a3, includeReports: true);
      for (final f in DrawingFormat.values) {
        save('orchard.${f.extension}', ex.exportDrawing(f, sheet: sheet));
      }
      for (final f in ReportFormat.values) {
        save('orchard_report.${f.extension}', ex.exportReport(f));
      }
      save('orchard_schedule.csv', controllerProgramCsv(buildControllerProgram(c.project, c.results, days: 14), t: c.t.call));
      save('orchard.oci.json', c.saveJson());
      save('catalog.xlsx', CatalogIo.exportXlsx(c.project.catalog));
      save('catalog_pipes.csv', CatalogIo.exportCsv(c.project.catalog, CatalogGroup.pipes));
      save('catalog.oci.cat', CatalogIo.encodePack(const CatalogPackMeta(id: 'exemplo', brand: 'Exemplo'), c.project.catalog));

      // DXF: every entity the exporter emits reads back with its layer
      final doc = ex.dxfDocument();
      final dxf = DxfReader.parse(ex.dxf());
      expect(dxf.entities.length, doc.entities.length);
      expect(dxf.layers.map((l) => l.name).toSet(), doc.layers.map((l) => l.name).toSet());
      expect(dxf.unitScale, 1);
      for (var i = 0; i < doc.entities.length; i++) {
        expect(dxf.entities[i].type, doc.entities[i].type);
        expect(dxf.entities[i].layer, doc.entities[i].layer);
        expect(dxf.entities[i].points.length, doc.entities[i].points.length, reason: '${doc.entities[i].type} #$i');
        for (var k = 0; k < doc.entities[i].points.length; k++) {
          expect(dxf.entities[i].points[k], near(doc.entities[i].points[k], 1e-3));
        }
        if (doc.entities[i].type == 'TEXT') expect(dxf.entities[i].text, doc.entities[i].text);
      }
      // DWG: reads back without errors
      final dwg = DwgReader.parse(ex.dwg());
      expect(dwg.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof') || w.startsWith('handle_mismatch')), isEmpty);
      expect(dwg.document.layers.map((l) => l.name), containsAll(doc.layers.map((l) => l.name)));
      // KML / KMZ / GeoJSON
      final feats = ex.geoFeatures();
      expect(KmlReader.parse(ex.kml(), georef: c.project.meta.georef).placemarkCount, feats.length);
      expect(KmlReader.parseKmz(ex.kmz(), georef: c.project.meta.georef).placemarkCount, feats.length);
      final gj = jsonDecode(ex.geoJson()) as Map<String, dynamic>;
      final gfeats = (gj['features'] as List).cast<Map<String, dynamic>>();
      expect(gfeats.length, feats.length);
      for (final f in gfeats) {
        final geom = f['geometry'] as Map<String, dynamic>;
        final coords = geom['coordinates'];
        switch (geom['type']) {
          case 'Point':
            expect((coords as List).length, inInclusiveRange(2, 3));
          case 'LineString':
            expect((coords as List).length, greaterThanOrEqualTo(2));
          case 'Polygon':
            final ring = (coords as List).first as List;
            expect(ring.length, greaterThanOrEqualTo(4));
            expect(ring.first, ring.last);
        }
        expect(f['properties'], containsPair('layer', isA<String>()));
      }
      // SVG and PDF are well-formed
      final svg = XmlDocument.parse(ex.svg());
      expect(svg.rootElement.name.local, 'svg');
      expect(svg.rootElement.getAttribute('viewBox')!.split(' ').length, 4);
      final pdf = ex.pdfSheet(sheet);
      expect(latin1.decode(pdf.sublist(0, 8)), startsWith('%PDF-1.4'));
      expect(latin1.decode(pdf.sublist(pdf.length - 7)).trim(), endsWith('%%EOF'));
      // XLSX report reads back with our reader: same sheets, headers and numeric cells
      final tables = ex.reportTables();
      final sheets = XlsxReader.read(ex.reportXlsx());
      expect(sheets.length, tables.length);
      for (var i = 0; i < tables.length; i++) {
        expect(sheets[i].headers, tables[i].headers);
        expect(sheets[i].rows.length, tables[i].rows.length);
        for (var r = 0; r < tables[i].rows.length; r++) {
          for (var k = 0; k < tables[i].rows[r].length; k++) {
            final cell = tables[i].rows[r][k];
            if (cell is RNum) expect(sheets[i].rows[r][k], isA<double>(), reason: '${tables[i].key} r$r c$k');
          }
        }
      }
      // catalogue: XLSX and CSV round trips keep every group
      final cat = c.project.catalog;
      final back = CatalogIo.parseXlsx(CatalogIo.exportXlsx(cat)).catalog;
      expect(back.pipes.length, cat.pipes.length);
      expect(back.outlets.length, cat.outlets.length);
      expect(back.tapes.length, cat.tapes.length);
      expect(back.valves.length, cat.valves.length);
      expect(back.pumps.length, cat.pumps.length);
      expect(back.fittings.length, cat.fittings.length);
      expect(back.outlets.map((o) => o.nozzles.length).toList(), cat.outlets.map((o) => o.nozzles.length).toList());
      for (final g in CatalogGroup.values) {
        final csv = CatalogIo.parseCsv(CatalogIo.exportCsv(cat, g));
        expect(csv.group, g);
      }
      final pack = CatalogIo.parsePack(CatalogIo.encodePack(const CatalogPackMeta(id: 'exemplo', brand: 'Exemplo'), cat));
      expect(pack.catalog.itemCount, cat.itemCount);
      // project JSON keeps entities, georeference and results
      final n = c.project.entities.length;
      c.loadJson(c.saveJson());
      expect(c.project.entities.length, n);
      expect(c.project.meta.georef!.zone, 23);
      expect(c.results, isNotNull);
    });

    test('every gallery example exports as DXF, DWG, KML, GeoJSON and SVG that read back', () {
      final dir = Directory('${out.path}/examples')..createSync(recursive: true);
      for (final id in ExampleId.values) {
        final c = fresh();
        loadExampleAction(c, id);
        c.project.meta.georef ??= GeoReference.fromLatLonOrigin(-15.78, -47.93);
        final ex = c.exporter();
        final doc = ex.dxfDocument();
        final dxfText = ex.dxf();
        File('${dir.path}/${id.name}.dxf').writeAsStringSync(dxfText);
        expect(DxfReader.parse(dxfText).entities.length, doc.entities.length, reason: id.name);
        final dwgBytes = ex.dwg();
        File('${dir.path}/${id.name}.dwg').writeAsBytesSync(dwgBytes);
        final r = DwgReader.parse(dwgBytes);
        expect(r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof') || w.startsWith('handle_mismatch')), isEmpty, reason: '${id.name}: ${r.warnings.take(3)}');
        expect(r.document.entities.length, greaterThan(0), reason: id.name);
        final kml = ex.kml();
        File('${dir.path}/${id.name}.kml').writeAsStringSync(kml);
        expect(KmlReader.parse(kml, georef: c.project.meta.georef).placemarkCount, ex.geoFeatures().length, reason: id.name);
        final gj = ex.geoJson();
        File('${dir.path}/${id.name}.geojson').writeAsStringSync(gj);
        expect((jsonDecode(gj) as Map)['type'], 'FeatureCollection');
        final svg = ex.svg();
        File('${dir.path}/${id.name}.svg').writeAsStringSync(svg);
        expect(XmlDocument.parse(svg).rootElement.name.local, 'svg', reason: id.name);
      }
    });

    test('the import filter lists only the supported formats', () {
      expect(importAccept.split(','), unorderedEquals(['.dxf', '.dwg', '.kml', '.kmz', '.shp', '.zip', '.csv', '.txt', '.xyz', '.pts', '.pnezd', '.jpg', '.jpeg', '.png', '.tif', '.tiff']));
      final z = ZipDecoder().decodeBytes(fixture('earth_farm.kmz'));
      expect(z.files.map((f) => f.name), contains('doc.kml'));
    });
  });
}
