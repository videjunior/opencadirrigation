// The new functions of 1.6.0 for file formats (wave 2): large and
// cloud-optimised GeoTIFFs read block by block (PRD-23), projections given
// key by key in GeoTIFF, KMZ ground overlays, survey points delivered as
// blocks, hydraulic data in the extended data of DXF/DWG, the layers and
// PDF/A of the PDF, a sheet of custom size, stake-out points, the cache of
// downloads, the East Asian code pages (FMT-12), the classes of DWG
// entities left out (FMT-20), shapefiles read in slices (FMT-23) and the
// choices of the points import wizard (FMT-15). Fixtures from other
// programs are written by tool/formats/make_fixtures_1102.py.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart';
import 'package:opencadirrigation/core/io/cad_xdata.dart';
import 'package:opencadirrigation/core/io/codepages.dart';
import 'package:opencadirrigation/core/io/data_cache.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/dem_tiff.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dwg_writer.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/io/icc_srgb.dart';
import 'package:opencadirrigation/core/io/import_async.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_reader.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/io/shp.dart';
import 'package:opencadirrigation/core/io/stakeout.dart';
import 'package:opencadirrigation/core/io/tiff_raster.dart';
import 'package:opencadirrigation/core/io/work_slicer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart' show Layer;

Uint8List _fixture(String name) => File('test/fixtures/formats/$name').readAsBytesSync();

ProjectController _controller() {
  final c = ProjectController()..autosaveEnabled = false;
  c.newProject();
  return c;
}

/// A little-endian TIFF (classic or BigTIFF) of 8-bit RGB pixels [rgb]
/// (rows of width × 3 bytes) in tiles of [tile] pixels, Deflate-compressed
/// with the horizontal predictor, followed by an overview IFD of [overview]
/// (half the size, every pixel that colour).
Uint8List _rgbTiff(int w, int h, List<int> Function(int x, int y) rgb, {int tile = 16, bool big = false, List<int>? overview}) {
  final out = BytesBuilder();
  final images = <(int, int, List<int> Function(int, int), int)>[(w, h, rgb, 0), if (overview != null) (w ~/ 2, h ~/ 2, (x, y) => overview, 1)];
  // pixel data first, the directories after it
  final blocks = <List<(int, int)>>[];
  var at = big ? 16 : 8;
  out.add(Uint8List(at));
  for (final (iw, ih, f, _) in images) {
    final list = <(int, int)>[];
    for (var ty = 0; ty < ih; ty += tile) {
      for (var tx = 0; tx < iw; tx += tile) {
        final raw = Uint8List(tile * tile * 3);
        for (var y = 0; y < tile; y++) {
          for (var x = 0; x < tile; x++) {
            final c = tx + x < iw && ty + y < ih ? f(tx + x, ty + y) : const [0, 0, 0];
            raw.setRange((y * tile + x) * 3, (y * tile + x) * 3 + 3, c);
          }
          // horizontal differencing, sample by sample
          for (var x = tile - 1; x > 0; x--) {
            for (var s = 0; s < 3; s++) {
              final p = (y * tile + x) * 3 + s;
              raw[p] = (raw[p] - raw[p - 3]) & 0xFF;
            }
          }
        }
        final z = const ZLibEncoder().encode(raw);
        list.add((at, z.length));
        out.add(z);
        at += z.length;
      }
    }
    blocks.add(list);
  }
  final ifdAt = <int>[];
  final dirs = BytesBuilder();
  var pos = at;
  for (var i = 0; i < images.length; i++) {
    final (iw, ih, _, subfile) = images[i];
    final offs = blocks[i];
    // the arrays of offsets and counts, then the directory
    final arrays = BytesBuilder();
    final offAt = pos, countAt = pos + offs.length * (big ? 8 : 4);
    for (final (o, _) in offs) {
      arrays.add(_int(o, big ? 8 : 4));
    }
    for (final (_, n) in offs) {
      arrays.add(_int(n, big ? 8 : 4));
    }
    final bpsAt = pos + arrays.length;
    arrays.add([..._int(8, 2), ..._int(8, 2), ..._int(8, 2)]);
    dirs.add(arrays.toBytes());
    pos += arrays.length;
    final entries = <(int, int, int, int)>[
      (254, 4, 1, subfile),
      (256, 3, 1, iw),
      (257, 3, 1, ih),
      // three shorts: in the entry of a BigTIFF (8 bytes), at an offset in a classic one
      (258, 3, 3, big ? 8 + 8 * 65536 + 8 * 4294967296 : bpsAt),
      (259, 3, 1, 8),
      (262, 3, 1, 2),
      (277, 3, 1, 3),
      (284, 3, 1, 1),
      (317, 3, 1, 2),
      (322, 3, 1, tile),
      (323, 3, 1, tile),
      (324, big ? 16 : 4, offs.length, offs.length == 1 ? offs.first.$1 : offAt),
      (325, big ? 16 : 4, offs.length, offs.length == 1 ? offs.first.$2 : countAt),
    ];
    ifdAt.add(pos);
    final d = BytesBuilder()..add(_int(entries.length, big ? 8 : 2));
    for (final (tag, type, count, value) in entries) {
      d
        ..add(_int(tag, 2))
        ..add(_int(type, 2))
        ..add(_int(count, big ? 8 : 4))
        ..add(_int(value, big ? 8 : 4));
    }
    final nextAt = pos + d.length;
    d.add(_int(0, big ? 8 : 4));
    final bytes = d.toBytes();
    dirs.add(bytes);
    pos += bytes.length;
    if (i > 0) {
      // the previous directory points to this one
      final prev = ifdAt[i - 1];
      final prevNext = prev + (big ? 8 : 2) + entries.length * (big ? 20 : 12);
      final all = dirs.toBytes();
      final w = big ? 8 : 4;
      all.setRange(prevNext - at, prevNext - at + w, _int(ifdAt[i], w));
      dirs
        ..clear()
        ..add(all);
    }
    expect(nextAt, greaterThan(0));
  }
  final file = Uint8List.fromList([...out.toBytes(), ...dirs.toBytes()]);
  // header
  file.setRange(0, 4, [0x49, 0x49, big ? 43 : 42, 0]);
  if (big) {
    file.setRange(4, 8, [8, 0, 0, 0]);
    file.setRange(8, 16, _int(ifdAt.first, 8));
  } else {
    file.setRange(4, 8, _int(ifdAt.first, 4));
  }
  return file;
}

List<int> _int(int v, int bytes) => [for (var i = 0; i < bytes; i++) (v >> (8 * i)) & 0xFF];

void main() {
  group('large GeoTIFFs block by block (PRD-23)', () {
    test('a tiled RGB TIFF with the horizontal predictor and an overview reads by its directories', () {
      final t = _rgbTiff(64, 48, (x, y) => x < 32 ? const [255, 0, 0] : const [0, 0, 255], overview: const [0, 255, 0]);
      final f = TiffFile.open(t)!;
      expect(f.ifds, hasLength(2));
      expect(f.main!.width, 64);
      expect(f.overviewsOf(f.main!).single.width, 32);
      final raster = TiffRaster(f, f.main!);
      expect(raster.unsupported, isNull);
      final (image, factor) = raster.reducedNow(4096);
      expect(factor, 1);
      expect(image.width, 64);
      expect(image.getPixel(5, 5).r, 255);
      expect(image.getPixel(60, 40).b, 255);
      // reduced by 4: a box straddling the two halves averages them
      final (small, f4) = raster.reducedNow(16);
      expect(f4, 4);
      expect(small.width, 16);
      expect(small.getPixel(2, 2).r, 255);
      expect(small.getPixel(14, 2).b, 255);
    });

    test('a BigTIFF opens: its directories and its blocks', () {
      final t = _rgbTiff(40, 24, (x, y) => [x * 6, y * 10, 128], big: true);
      final f = TiffFile.open(t)!;
      expect(f.big, isTrue);
      expect(GeoImageReader.readTiffTags(t).shorts[256], [40]);
      final (image, _) = TiffRaster(f, f.main!).reducedNow(4096);
      expect(image.getPixel(10, 20).r, 60);
      expect(image.getPixel(10, 20).g, 200);
      expect(GeoImageReader.isLargeTiff(t), isTrue);
    });

    test('a cloud-optimised GeoTIFF is read from the smallest overview that holds the size asked for', () async {
      final bytes = _fixture('ortho_cog_rgb.tif');
      expect(GeoImageReader.isLargeTiff(bytes), isTrue);
      // the full image: the four quadrants, its georeference (SIRGAS 2000 / UTM 23S)
      final full = await GeoImageReader.readLargeTiff('ortho.tif', bytes);
      expect(full.widthPx, 512);
      expect(full.mime, 'image/jpeg');
      expect(full.crs!.epsg, 31983);
      expect(full.pixelSizeX, closeTo(0.1, 1e-12));
      final pic = img.decodeJpg(full.bytes)!;
      expect(pic.getPixel(100, 100).r, greaterThan(230));
      expect(pic.getPixel(400, 300).g, greaterThan(230));
      // 200 px: the first overview (painted cyan), halved again
      final small = GeoImageReader.readLargeTiffNow('ortho.tif', bytes, maxSide: 200);
      expect(small.widthPx, 128);
      expect(small.pixelSizeX, closeTo(0.4, 1e-12));
      expect(small.worldWidth, closeTo(51.2, 1e-9));
      final p = img.decodeJpg(small.bytes)!.getPixel(64, 48);
      expect(p.r, lessThan(30));
      expect(p.g, greaterThan(230));
      expect(p.b, greaterThan(230));
      expect(small.warnings.any((w) => w.startsWith('image_reduced:512×384')), isTrue);
    });

    test('a BigTIFF with an alpha band keeps its transparent part (PNG)', () {
      final g = GeoImageReader.read('ortho.tif', _fixture('ortho_bigtiff_rgba.tif'));
      expect(g.mime, 'image/png');
      expect(g.widthPx, 300);
      final pic = img.decodePng(g.bytes)!;
      expect(pic.getPixel(10, 10).a, 0);
      final p = pic.getPixel(200, 100);
      expect([p.r, p.g, p.b, p.a], [20, 160, 90, 255]);
      expect(g.georeferenced, isTrue);
    });

    test('an elevation model is sampled from an overview when the grid needs no more', () {
      // 64 × 48 heights of 500 m, an overview of 32 × 24 marked 700 m
      final w = 64, h = 48;
      final tiff = _floatDem(w, h, (x, y) => 500, overview: 700);
      final fine = GeoTiffDemReader.read(tiff, maxPoints: 4000)!;
      expect(fine.samples.every((s) => s.z == 500), isTrue);
      expect(fine.samples, hasLength(w * h));
      // 100 points: a step of 6 pixels, the overview holds that grid
      final coarse = GeoTiffDemReader.read(tiff, maxPoints: 100)!;
      expect(coarse.samples.every((s) => s.z == 700), isTrue);
      expect(coarse.step, 6);
    });

    test('a DEM read in slices can be cancelled', () async {
      final tiff = _floatDem(64, 48, (x, y) => 500.0 + x);
      final slicer = WorkSlicer(sliceMs: 0)..cancel();
      expect(() => GeoTiffDemReader.readAsync(tiff, slicer), throwsA(isA<ImportCancelled>()));
      final done = await readImportAsync('dem.tif', tiff, WorkSlicer());
      expect(done, isA<GeoTiffDem>());
    });
  });

  group('projections given key by key in GeoTIFF', () {
    test('an Albers elevation model on SIRGAS 2000 (ProjectedCSType 32767) lands at its place', () {
      final dem = GeoTiffDemReader.read(_fixture('dem_albers_float32.tif'))!;
      expect(dem.warnings.where((w) => w.startsWith('crs_projection') || w.startsWith('crs_datum_unknown')), isEmpty);
      expect(dem.samples, hasLength(64 * 48));
      final (lo, hi) = dem.range;
      expect(lo, closeTo(800, 1e-3));
      expect(hi, closeTo(806.3, 1e-3));
      final g = dem.georef!;
      expect(g.zone, 23);
      expect(g.north, isFalse);
      // the first sample is the centre of the top-left pixel, 15 m into the raster
      final (lat, lon) = g.toLatLon(dem.samples.first.p.x, dem.samples.first.p.y);
      expect(lat, closeTo(-15.78, 0.0005));
      expect(lon, closeTo(-47.93, 0.0005));
      expect(dem.samples[1].p.distanceTo(dem.samples.first.p), closeTo(30, 0.6));
    });

    test('the keys of a Lambert conformal conic and of a polyconic projection', () {
      TiffTags tags(int method, List<double> d) => TiffTags()
        ..shorts[34735] = [1, 1, 0, 9, 1024, 0, 1, 1, 3072, 0, 1, 32767, 2050, 0, 1, 6674, 3075, 0, 1, method, 3078, 34736, 1, 0, 3079, 34736, 1, 1, 3080, 34736, 1, 2, 3081, 34736, 1, 3, 3082, 34736, 1, 4]
        ..doubles[34736] = d;
      final lcc = GeoImageReader.tiffGeo(tags(8, [49, 44, 3, 46.5, 700000])).crs!;
      expect(lcc.recognised, isTrue);
      expect(lcc.projection, isA<LambertConformalConic>());
      expect(lcc.datum, GeodeticDatum.sirgas2000);
      final poly = GeoImageReader.tiffGeo(tags(22, [0, 0, -54, 0, 5000000])).crs!;
      expect(poly.projection, isA<Polyconic>());
      expect(poly.projection!.falseEasting, 5000000);
      final unknown = GeoImageReader.tiffGeo(tags(15, [0, 0, 0, 0, 0])).crs!;
      expect(unknown.problem, 'crs_projection_unsupported');
    });
  });

  group('KMZ ground overlays', () {
    test('the overlays of a KMZ come as pictures on their boxes, the web one is named', () {
      final r = KmlReader.parseKmz(_fixture('overlay_farm.kmz'));
      expect(r.placemarkCount, 1);
      expect(r.overlays.map((o) => o.name), ['Ortofoto', 'Quadra', 'Croqui'], reason: 'by their drawing order');
      expect(r.warnings, contains('kml_overlay_missing:https://example.com/overlay.png'));
      expect(r.warnings, isNot(contains('kml_overlay_quad')));
      final ortho = r.overlays.first;
      expect(ortho.mime, 'image/png');
      expect(ortho.opacity, closeTo(191 / 255, 1e-9));
      // 0.002° of longitude and 0.001° of latitude at 15.78° S
      expect(ortho.width, closeTo(214.3, 1.5));
      expect(ortho.height, closeTo(110.6, 1.5));
      expect(ortho.rotationDeg.abs(), lessThan(1));
      final sketch = r.overlays.last;
      expect(sketch.mime, 'image/jpeg');
      expect(sketch.rotationDeg, closeTo(30, 1));
      final images = KmlReader.overlayImages(r.overlays, () => 'x');
      expect(images.first.data, isNotNull);
      expect(images.first.origin, ortho.corners.first);
    });

    test('the import puts the overlays under the drawing, with the placemarks', () {
      final c = _controller();
      final summary = c.importFile('fazenda.kmz', _fixture('overlay_farm.kmz'));
      final images = c.project.entities.whereType<ImageEntity>().toList();
      expect(images, hasLength(3));
      expect(c.project.entities.indexOf(images.first), 0, reason: 'pictures under the drawing');
      expect(summary, contains(c.t('warn.kml_overlay_missing')));
      expect(c.project.meta.georef, isNotNull);
    });
  });

  group('survey points in blocks', () {
    void check(DxfDocument doc) {
      final pts = doc.entities.where((e) => e.type == 'POINT').toList();
      expect(pts.map((e) => e.elevation), unorderedEquals([612.35, 613.10, 611.80, 615.2]));
      expect(pts.map((e) => e.name), containsAll(['1 MARCO', '2 CERCA', '3 POCO']));
      expect(pts.firstWhere((e) => e.elevation == 615.2).points.single, const Pt(170, 210));
      expect(doc.warnings, contains('dxf_survey_points:4'));
      // the symbol of a tree is no survey point
      expect(pts.any((e) => e.points.single == const Pt(140, 220)), isFalse);
    }

    test('ATTRIB elevations (a decimal comma and the unit) and the Z of the insertion, in DXF', () => check(DxfReader.parseBytes(_fixture('survey_blocks_r2000.dxf'))));

    test('the same survey in DWG (written by LibreDWG)', () => check(DwgReader.parse(_fixture('survey_blocks_r2000.dwg')).document));

    test('they become spot heights of the terrain, not markers', () {
      final c = _controller();
      c.importFile('levantamento.dxf', _fixture('survey_blocks_r2000.dxf'));
      final spots = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(spots.map((s) => s.elevation), unorderedEquals([612.35, 613.10, 611.80, 615.2]));
    });
  });

  group('hydraulic data in the extended data of DXF and DWG', () {
    ProjectController project() {
      final c = _controller();
      final cat = c.project.catalog;
      c.addEntity(PipeEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(50, 0), Pt(50, 30)], scope: HydraulicScope.mainline, pipeSpecId: cat.pipes.first.id));
      c.addEntity(OutletEntity(id: c.project.newId(), name: 'A1', position: const Pt(10, 10), outletSpecId: cat.outlets.first.id, headM: 25));
      c.addEntity(ControlValveEntity(id: c.project.newId(), position: const Pt(0, 0), zoneName: 'Z1'));
      c.addEntity(SpraylineEntity(id: c.project.newId(), name: 'L1', points: const [Pt(0, 40), Pt(30, 40)], outletSpecId: cat.outlets.first.id, spacing: 6));
      c.addEntity(WaterSupplyEntity(id: c.project.newId(), name: 'Poço Sul', position: const Pt(-10, 0)));
      return c;
    }

    test('pipes and items carry their data, and the DXF registers the application', () {
      final c = project();
      final dxf = c.exportDxf();
      expect(dxf, contains('1001\n$xdataApp'));
      expect(dxf, contains('DN_MM'));
      expect(dxf, contains('LENGTH_M'));
      final doc = DxfReader.parse(dxf);
      final pipe = doc.entities.firstWhere((e) => e.type == 'POLYLINE' && e.xdata?['KIND'] == 'mainline_pipe');
      expect(pipe.xdata!['ITEM'], isNotEmpty);
      // its label says whose it is
      expect(doc.entities.where((e) => e.type == 'TEXT' && e.xdata?['PART_OF'] == pipe.xdata!['ID']), hasLength(1));
      expect(double.parse(pipe.xdata!['LENGTH_M']!), closeTo(80, 1e-6));
      expect(doc.items.map((i) => i.xdata['KIND']), containsAll(['outlet', 'zone_valve']));
    });

    test('a DXF and a DWG of the app come back as pipes and items', () {
      final c = project();
      for (final (name, bytes) in [('round.dxf', Uint8List.fromList(utf8.encode(c.exportDxf()))), ('round.dwg', c.exporter().dwg())]) {
        final d = _controller();
        d.importFile(name, bytes);
        final pipe = d.project.entities.whereType<PipeEntity>().single;
        expect(pipe.scope, HydraulicScope.mainline, reason: name);
        expect(pipe.pipeSpecId, c.project.catalog.pipes.first.id, reason: name);
        expect(pipe.points.last, const Pt(50, 30), reason: name);
        final outlet = d.project.entities.whereType<OutletEntity>().single;
        expect(outlet.name, 'A1', reason: name);
        expect(outlet.headM, 25, reason: name);
        expect(outlet.position, const Pt(10, 10), reason: name);
        expect(d.project.entities.whereType<ControlValveEntity>().single.zoneName, 'Z1', reason: name);
        final lateral = d.project.entities.whereType<SpraylineEntity>().single;
        expect(lateral.name, 'L1', reason: name);
        expect(lateral.spacing, 6, reason: name);
        // a name with a space and an accent comes back whole
        expect(d.project.entities.whereType<WaterSupplyEntity>().single.name, 'Poço Sul', reason: name);
        // the drawing of their blocks, their labels and the outlet symbols of
        // the lateral are not added beside them
        expect(d.project.entities.whereType<CircleEntity>(), isEmpty, reason: name);
        expect(d.project.entities.whereType<TextEntity>(), isEmpty, reason: name);
        expect(d.project.entities.whereType<PolylineEntity>(), isEmpty, reason: name);
      }
      // a reader of the drawing still sees it whole: the blocks of the items and the labels
      final doc = DxfReader.parse(c.exportDxf());
      expect(doc.entities.where((e) => e.type == 'TEXT').map((e) => e.text), containsAll(['Z1', 'Poço Sul']));
      expect(doc.entities.where((e) => e.type == 'CIRCLE' && e.center!.distanceTo(const Pt(10, 10)) < 1e-6), isNotEmpty);
      expect(doc.items.where((i) => i.xdata['PART_OF'] != null), hasLength(5), reason: 'the outlet symbols of the lateral');
    });

    test('an item whose catalogue entry the project lacks keeps the plain drawing', () {
      final data = readHydraulicXdata([(1001, xdataApp), (1000, xdataSignature), (1000, 'JSON'), (1002, '{'), (1000, '{"type":"outlet","id":"e9","spec":"no-such-outlet"}'), (1002, '}')])!;
      final c = _controller();
      expect(restoreHydraulic(data, c.project, position: Pt.zero, id: 'n1'), isNull);
      expect(readHydraulicXdata([(1001, 'OTHERAPP'), (1000, 'x')]), isNull);
    });

    test('the EED bytes of the DWG writer read back as the same groups', () {
      final groups = <(int, Object)>[(1000, xdataSignature), (1000, 'KIND'), (1000, 'outlet'), (1000, 'FLOW_M3H'), (1040, 1.25), (1002, '{'), (1000, 'x'), (1002, '}')];
      final bytes = DwgWriter.eedBytes(groups);
      expect(bytes.first, 0);
      expect(bytes.contains(40), isTrue);
      final d = CadDrawing(layers: [const CadLayer('0')], entities: [const CadLine('0', Pt(0, 0), Pt(1, 0))]);
      final line = d.entities.first;
      final drawing = CadDrawing(layers: d.layers, entities: d.entities, xdata: {line: groups});
      final r = DwgReader.parse(DwgWriter.writeDrawing(drawing));
      expect(r.warnings.where((w) => w.startsWith('object_error')), isEmpty);
    });
  });

  group('PDF: layers of the viewer and PDF/A-2b', () {
    test('each layer of the project is an optional content group, read back by the PDF reader', () {
      final c = _controller();
      c.project.layers.add(Layer(name: 'Tubos', color: 0xFF2255AA));
      c.addEntity(LineEntity(id: c.project.newId(), layer: 'Tubos', a: Pt.zero, b: const Pt(40, 0)));
      c.addEntity(LineEntity(id: c.project.newId(), a: const Pt(0, 10), b: const Pt(40, 10)));
      final bytes = c.exporter().pdfSheet(const SheetOptions(pdfLayers: true, legend: false));
      final text = latin1.decode(bytes);
      expect(text, startsWith('%PDF-1.7'));
      expect(text, contains('/OCProperties'));
      final page = PdfReader.open(bytes).readPage(0);
      expect(page.layers.map((l) => l.name), contains('Tubos'));
      expect(page.paths.any((p) => p.layer == 'Tubos'), isTrue);
      // without the option the file stays as it was
      expect(latin1.decode(c.exporter().pdfSheet()), isNot(contains('/OCProperties')));
    });

    test('PDF/A-2b: identifier, metadata, output intent and no font left out', () {
      final fonts = PdfFonts()..register(BundledFonts.latin, File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync());
      final doc = PdfDocument(title: 'Projeto São João', author: 'Eng.', subject: 'Irrigação', fonts: fonts, pdfA: true, now: DateTime.utc(2026, 11, 2, 12, 30));
      doc.addPage(widthPt: 200, heightPt: 100).text(10, 50, 'Válvula Z1', size: 10, bold: true);
      final bytes = doc.build();
      final text = latin1.decode(bytes);
      expect(text, startsWith('%PDF-1.7'));
      expect(text, contains('/GTS_PDFA1'));
      expect(text, contains('/OutputIntents'));
      expect(text, contains('<pdfaid:part>2</pdfaid:part>'));
      expect(text, contains('<pdfaid:conformance>B</pdfaid:conformance>'));
      expect(text, contains('/CreationDate (D:20261102123000Z)'));
      expect(text, contains('<xmp:CreateDate>2026-11-02T12:30:00Z</xmp:CreateDate>'));
      expect(RegExp(r'/ID \[<[0-9A-F]{32}> <[0-9A-F]{32}>\]').hasMatch(text), isTrue);
      expect(text, isNot(contains('/BaseFont /Helvetica')));
      expect(doc.fontsAllEmbedded, isTrue);
      // the text is still the text (copy and search)
      expect(PdfReader.open(bytes).readPage(0).texts.map((t) => t.text).join(), contains('Válvula Z1'));
      // a character the Latin font lacks prints as Helvetica would ("?"), not as an empty glyph
      final odd = PdfDocument(fonts: fonts, pdfA: true)..addPage(widthPt: 200, heightPt: 100).text(10, 50, 'A ☃ B', size: 10);
      expect(PdfReader.open(odd.build()).readPage(0).texts.map((t) => t.text).join(), contains('A ? B'));
      // without the Latin font the file does not claim PDF/A
      final plain = PdfDocument(fonts: PdfFonts(), pdfA: true)..addPage(widthPt: 200, heightPt: 100).text(10, 50, 'Válvula', size: 10);
      final plainText = latin1.decode(plain.build());
      expect(plain.fontsAllEmbedded, isFalse);
      expect(plainText, isNot(contains('pdfaid')));
      expect(plainText, startsWith('%PDF-1.4'));
    });

    test('the sRGB profile is a valid ICC version 2 display profile', () {
      final p = srgbIccProfile();
      final bd = ByteData.sublistView(p);
      expect(bd.getUint32(0), p.length);
      expect(String.fromCharCodes(p.sublist(12, 16)), 'mntr');
      expect(String.fromCharCodes(p.sublist(16, 20)), 'RGB ');
      expect(String.fromCharCodes(p.sublist(20, 24)), 'XYZ ');
      expect(String.fromCharCodes(p.sublist(36, 40)), 'acsp');
      expect(bd.getUint32(128), 9, reason: 'nine tags');
      for (var i = 0; i < 9; i++) {
        final offset = bd.getUint32(132 + 12 * i + 4), size = bd.getUint32(132 + 12 * i + 8);
        expect(offset % 4, 0);
        expect(offset + size, lessThanOrEqualTo(p.length));
      }
    });
  });

  group('sheet of custom size', () {
    test('a plotter roll: its size, the PDF page and the title block', () {
      const o = SheetOptions(page: PageSize.custom, customWidthMm: 914, customHeightMm: 2500);
      expect(o.widthMm, 914);
      expect(o.heightMm, 2500);
      expect(const SheetOptions(page: PageSize.custom, customWidthMm: 10, customHeightMm: 99999).heightMm, PageSize.maxCustomMm);
      expect(const SheetOptions(page: PageSize.a1x3).widthMm, 1783);
      final c = _controller();
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(100, 400)));
      final bytes = c.exporter().pdfSheet(o);
      final info = PdfReader.open(bytes).readPage(0).page;
      expect(info.width, closeTo(914 * 72 / 25.4, 0.5));
      expect(info.height, closeTo(2500 * 72 / 25.4, 0.5));
    });
  });

  group('stake-out points (PNEZD)', () {
    test('valves, devices, outlets and pipe vertices with UTM coordinates and terrain elevations', () {
      final c = _controller();
      c.setGeoreference(const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253000));
      final cat = c.project.catalog;
      for (final (p, z) in [(const Pt(-10, -10), 600.0), (const Pt(110, -10), 600.0), (const Pt(-10, 110), 610.0), (const Pt(110, 110), 610.0)]) {
        c.addEntity(SpotHeightEntity(id: c.project.newId(), position: p, elevation: z));
      }
      c.addEntity(ControlValveEntity(id: c.project.newId(), position: const Pt(0, 0), zoneName: 'Z1'));
      c.addEntity(PipeEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(0, 100)], scope: HydraulicScope.mainline, pipeSpecId: cat.pipes.first.id));
      c.addEntity(OutletEntity(id: c.project.newId(), position: const Pt(50, 50), outletSpecId: cat.outlets.first.id));
      final pts = stakeoutPoints(c.project, firstNumber: 101, label: (k, _) => k.name.toUpperCase());
      // the valve sits on the first vertex of the pipe: one point there
      expect(pts, hasLength(3));
      expect(pts.first.number, 101);
      final valve = pts.firstWhere((p) => p.kind == StakeoutKind.valves);
      expect(valve.easting, 186000);
      expect(valve.northing, 8253000);
      expect(valve.description, 'VALVES Z1');
      expect(valve.elevation, closeTo(601, 1.5));
      final outlet = pts.firstWhere((p) => p.kind == StakeoutKind.outlets);
      expect(outlet.elevation, closeTo(605, 1));
      final csv = stakeoutCsv(pts, decimals: 2);
      final line = csv.split('\r\n').firstWhere((l) => l.contains('VALVES'));
      expect(line.split(','), ['${valve.number}', '8253000.00', '186000.00', valve.elevation!.toStringAsFixed(2), 'VALVES Z1']);
      expect(stakeoutCsv(pts, order: StakeoutOrder.penzd, decimals: 2).split('\r\n').firstWhere((l) => l.contains('VALVES')).split(',')[1], '186000.00');
    });

    test('without terrain the elevation is left empty; descriptions lose the separator', () {
      final pts = [const StakeoutPoint(1, 10, 20, null, 'A, B', StakeoutKind.valves)];
      expect(stakeoutCsv(pts), '1,20.000,10.000,,A  B\r\n');
    });
  });

  group('downloads kept on the device', () {
    test('a download is read from the store the second time, by kind', () async {
      final dc = DataCache(MemoryDataCacheStore());
      var calls = 0;
      Future<String> fetch(String url) async {
        calls++;
        return '{"elevation":[$calls]}';
      }

      final dem = dc.text(fetch, 'dem');
      expect(await dem('https://dem/a'), '{"elevation":[1]}');
      expect(await dem('https://dem/a'), '{"elevation":[1]}');
      expect(calls, 1);
      expect(dc.hits, 1);
      final climate = dc.bytes((url) async => [1, 2, 3], 'climate');
      expect(await climate('https://climate/x'), [1, 2, 3]);
      expect((await dc.stats('dem')).count, 1);
      expect((await dc.stats('climate')).bytes, 3);
      expect(await dc.clear('dem'), 1);
      expect((await dc.stats()).count, 1);
      // turned off: neither read nor kept
      dc.enabled = false;
      await dem('https://dem/a');
      expect(calls, 2);
      expect((await dc.stats('dem')).count, 0);
    });

    test('past its size the oldest downloads go', () async {
      var t = DateTime.utc(2026);
      final store = MemoryDataCacheStore();
      final dc = DataCache(store, maxBytes: 4000, clock: () => t = t.add(const Duration(minutes: 1)));
      for (var i = 0; i < 10; i++) {
        await dc.bytes((url) async => List.filled(900, i), 'dem')('tile/$i');
      }
      final kept = await store.entries();
      expect(kept.fold<int>(0, (s, e) => s + e.bytes), lessThanOrEqualTo(4000));
      expect(kept.map((e) => e.key), contains('dem:tile/9'));
      expect(kept.map((e) => e.key), isNot(contains('dem:tile/0')));
    });
  });

  group('East Asian code pages (FMT-12)', () {
    setUpAll(loadCjkCodepages);

    test('the four double-byte pages decode, single bytes included', () {
      expect(cjkCodepagesLoaded, isTrue);
      expect(supportedCodepages, containsAll([932, 936, 949, 950]));
      expect(decodeCodepage([0x82, 0xA0, 0xB1], 932), 'あｱ');
      expect(decodeCodepage([0xC4, 0xE3, 0xBA, 0xC3, 0x80], 936), '你好€');
      expect(decodeCodepage([0xC7, 0xD1, 0xB1, 0xDB], 949), '한글');
      expect(decodeCodepage([0xA4, 0xA4, 0xA4, 0xE5, 0x41], 950), '中文A');
      // a lead byte without its trail byte
      expect(decodeCodepage([0x41, 0xC4], 936), 'A�');
    });

    test('a DXF and a DWG in ANSI_936, and the .cpg and language driver of a DBF', () {
      final dxf = DxfReader.parseBytes(_fixture('cp936_r2000.dxf'));
      expect(dxf.layers.single.name, '管道');
      expect(dxf.entities.firstWhere((e) => e.type == 'TEXT').text, '阀门1号');
      expect(dxf.warnings.where((w) => w.startsWith('dxf_codepage')), isEmpty);
      final dwg = DwgReader.parse(_fixture('cp936_r2000.dwg')).document;
      expect(dwg.layers.map((l) => l.name), contains('管道'));
      expect(dwg.entities.firstWhere((e) => e.type == 'TEXT').text, '阀门1号');
      expect(codepageFromCpg('GBK'), 936);
      expect(codepageFromCpg('BIG5'), 950);
      expect(codepageFromCpg('Shift_JIS'), 932);
      expect(codepageFromCpg('CP1251'), 1251);
      expect(codepageFromDbfLanguage(0x4D), 936);
    });

    test('a file that names an East Asian page asks for the tables', () {
      // (already loaded here: nothing more is needed)
      expect(needsCjkCodepages('a.dxf', _fixture('cp936_r2000.dxf')), isFalse);
    });
  });

  group('DWG entities of classes left out (FMT-20)', () {
    test('IMAGE and WIPEOUT are named in the import note', () {
      final r = DwgReader.parse(_fixture('classes_r2000.dwg'));
      final note = r.document.warnings.firstWhere((w) => w.startsWith('dxf_unsupported:'));
      expect(note, contains('IMAGE'));
      expect(note, contains('WIPEOUT'));
      expect(r.document.entities.where((e) => e.type == 'LINE'), hasLength(1));
    });
  });

  group('shapefiles in slices (FMT-23)', () {
    Uint8List shp(int n) {
      // a point shapefile of [n] records
      final b = BytesBuilder();
      final head = ByteData(100)
        ..setInt32(0, 9994)
        ..setInt32(24, (100 + n * 28) ~/ 2)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, 1, Endian.little);
      b.add(head.buffer.asUint8List());
      for (var i = 0; i < n; i++) {
        final r = ByteData(28)
          ..setInt32(0, i + 1)
          ..setInt32(4, 10)
          ..setInt32(8, 1, Endian.little)
          ..setFloat64(12, 100.0 + i, Endian.little)
          ..setFloat64(20, 200.0, Endian.little);
        b.add(r.buffer.asUint8List());
      }
      return b.toBytes();
    }

    test('the same points as at once, and Cancel stops it', () async {
      final bytes = shp(5000);
      final now = ShpReader.parse(bytes);
      final sliced = await ShpReader.parseAsync(bytes, WorkSlicer(sliceMs: 0));
      expect(sliced.recordCount, now.recordCount);
      expect(sliced.document.entities.length, now.document.entities.length);
      expect(sliced.document.entities.last.points.single, now.document.entities.last.points.single);
      final slicer = WorkSlicer(sliceMs: 0)..cancel();
      expect(() => ShpReader.parseAsync(bytes, slicer), throwsA(isA<ImportCancelled>()));
    });
  });

  group('the choices of the points import wizard (FMT-15)', () {
    // five decimals: degrees, not metres, to the reader
    const latLon = '-22.90681,-43.17291,10\n-22.90702,-43.17313,12\n-22.90724,-43.17305,11\n';

    test('the reader\'s own choices are the starting point', () {
      final o = PointsCsvReader.detect(latLon);
      expect(o.separator, PointsSeparator.comma);
      expect(o.header, isFalse);
      expect(o.roles, [PointsRole.lat, PointsRole.lon, PointsRole.z]);
      expect(o.crs, PointsCrsKind.geographic);
      final r = PointsCsvReader.parseWith(latLon, o);
      expect(r.count, 3);
      expect(r.georef!.zone, 23);
    });

    test('the order swapped puts them elsewhere (lat/lon of Rio as lon/lat)', () {
      final o = PointsCsvReader.detect(latLon).copyWith(roles: [PointsRole.lon, PointsRole.lat, PointsRole.z]);
      final r = PointsCsvReader.parseWith(latLon, o);
      expect(r.georef!.zone, isNot(23));
    });

    test('a UTM zone on SAD 69, a comma decimal mark, a header and lines to skip', () {
      const text = 'Levantamento de 2026\nPonto;E;N;Cota\nP1;686000,5;7465000,25;10,5\nP2;686010,5;7465010,25;11\n';
      final o = PointsCsvReader.detect(text).copyWith(
        separator: PointsSeparator.semicolon,
        decimal: PointsDecimal.comma,
        skip: 1,
        header: true,
        roles: [PointsRole.name, PointsRole.x, PointsRole.y, PointsRole.z],
        crs: PointsCrsKind.utm,
        zone: 23,
        north: false,
        datum: GeodeticDatum.sad69,
      );
      final r = PointsCsvReader.parseWith(text, o);
      expect(r.count, 2);
      expect(r.document.entities.first.name, 'P1');
      expect(r.document.entities.first.elevation, 10.5);
      expect(r.warnings.any((w) => w.startsWith('crs_datum_shift')), isTrue);
      // SAD 69 → SIRGAS 2000: some tens of metres
      final p1 = r.document.entities.first.points.single, p2 = r.document.entities.last.points.single;
      expect(p2.distanceTo(p1), closeTo(14.142, 0.01));
    });

    test('an EPSG code, and the UTM of the project needs a georeference', () {
      const text = 'x y z\n5641804.98 9568677.47 800\n5641834.98 9568677.47 801\n';
      final r = PointsCsvReader.parseWith(text, const PointsImportOptions(separator: PointsSeparator.space, header: true, roles: [PointsRole.x, PointsRole.y, PointsRole.z], crs: PointsCrsKind.epsg, epsg: 10857));
      final (lat, lon) = r.georef!.toLatLon(r.document.entities.first.points.single.x, r.document.entities.first.points.single.y);
      expect(lat, closeTo(-15.78, 1e-5));
      expect(lon, closeTo(-47.93, 1e-5));
      expect(
        () => PointsCsvReader.parseWith(text, const PointsImportOptions(header: true, roles: [PointsRole.x, PointsRole.y, PointsRole.z], crs: PointsCrsKind.projectUtm)),
        throwsA(isA<FormatException>().having((e) => e.message, 'code', 'points_no_georef')),
      );
    });

    test('a separator and lines to skip chosen without the columns: the roles follow the columns they split', () {
      // tab separated, a title line, a header in Portuguese
      const text = 'Levantamento\nPonto\tLeste\tNorte\tCota\nP1\t686000.5\t7465000.25\t10.5\nP2\t686010.5\t7465010.25\t11\n';
      const o = PointsImportOptions(separator: PointsSeparator.tab, skip: 1, crs: PointsCrsKind.local);
      expect(PointsCsvReader.rolesFor(text, o), [PointsRole.name, PointsRole.x, PointsRole.y, PointsRole.z]);
      final r = PointsCsvReader.parseWith(text, o);
      expect(r.count, 2);
      expect(r.document.entities.first.name, 'P1');
      expect(r.document.entities.first.points.single, const Pt(686000.5, 7465000.25));
      // without a header: the point, then northing and easting told by their size
      const plain = 'P1 7465000.25 686000.5 10.5\nP2 7465010.25 686010.5 11\n';
      expect(PointsCsvReader.rolesFor(plain, const PointsImportOptions(separator: PointsSeparator.space, header: false)), [PointsRole.name, PointsRole.y, PointsRole.x, PointsRole.z]);
      // the lines to skip are skipped even with everything else automatic
      final skipped = PointsCsvReader.parseWith('título\n1;2;3\n4;5;6\n', const PointsImportOptions(skip: 1));
      expect(skipped.count, 2);
    });

    test('rows without both coordinates are counted, not imported', () {
      const text = 'x;y;z\n1;2;3\n;;\nabc;5;6\n4;5;6\n';
      final r = PointsCsvReader.parseWith(text, const PointsImportOptions(separator: PointsSeparator.semicolon, header: true, roles: [PointsRole.x, PointsRole.y, PointsRole.z], crs: PointsCrsKind.local));
      expect(r.count, 2);
      expect(r.warnings, contains('points_skipped:2'));
    });

    test('the controller imports with the choices, as one undo step with its georeference', () {
      final c = _controller();
      final o = PointsCsvReader.detect(latLon);
      final summary = c.importPointsWith(latLon, o);
      expect(summary, contains('3'));
      expect(c.project.entities.whereType<SpotHeightEntity>(), hasLength(3));
      expect(c.project.meta.georef, isNotNull);
      c.undo();
      expect(c.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      expect(c.project.meta.georef, isNull);
    });
  });
}

/// A little-endian float32 elevation TIFF of [w] × [h] heights in one
/// uncompressed strip, and an overview of half the size all [overview].
Uint8List _floatDem(int w, int h, double Function(int x, int y) z, {double? overview}) {
  final images = <(int, int, double Function(int, int), int)>[(w, h, z, 0), if (overview != null) (w ~/ 2, h ~/ 2, (x, y) => overview, 1)];
  final out = BytesBuilder()..add(Uint8List(8));
  var at = 8;
  final data = <(int, int)>[];
  for (final (iw, ih, f, _) in images) {
    final b = ByteData(iw * ih * 4);
    for (var y = 0; y < ih; y++) {
      for (var x = 0; x < iw; x++) {
        b.setFloat32((y * iw + x) * 4, f(x, y), Endian.little);
      }
    }
    data.add((at, iw * ih * 4));
    out.add(b.buffer.asUint8List());
    at += iw * ih * 4;
  }
  final ifds = <int>[];
  final dirs = <Uint8List>[];
  for (var i = 0; i < images.length; i++) {
    final (iw, ih, _, subfile) = images[i];
    final entries = <(int, int, int, int)>[
      (254, 4, 1, subfile),
      (256, 3, 1, iw),
      (257, 3, 1, ih),
      (258, 3, 1, 32),
      (259, 3, 1, 1),
      (262, 3, 1, 1),
      (273, 4, 1, data[i].$1),
      (277, 3, 1, 1),
      (278, 3, 1, ih),
      (279, 4, 1, data[i].$2),
      (339, 3, 1, 3),
    ];
    ifds.add(at);
    final d = BytesBuilder()..add(_int(entries.length, 2));
    for (final (tag, type, count, value) in entries) {
      d
        ..add(_int(tag, 2))
        ..add(_int(type, 2))
        ..add(_int(count, 4))
        ..add(_int(value, 4));
    }
    d.add(_int(0, 4));
    final bytes = d.toBytes();
    dirs.add(bytes);
    at += bytes.length;
  }
  for (var i = 0; i + 1 < dirs.length; i++) {
    dirs[i].setRange(dirs[i].length - 4, dirs[i].length, _int(ifds[i + 1], 4));
  }
  final file = Uint8List.fromList([...out.toBytes(), for (final d in dirs) ...d]);
  file.setRange(0, 8, [0x49, 0x49, 42, 0, ..._int(ifds.first, 4)]);
  return file;
}
