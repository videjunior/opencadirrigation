import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/lateral.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/dem_tiff.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/split.dart';
import 'package:opencadirrigation/core/units.dart';

/// Defects found by the 2026-09-22 sweep, each pinned by a test that fails
/// without its fix.

/// Records the wetted-radius arcs and circles the painter draws.
class _SectorCanvas implements Canvas {
  final arcs = <double>[];
  var circles = 0;
  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) => arcs.add(sweepAngle);
  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (radius > 20) circles++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ProjectController _fresh() {
  final c = ProjectController()..autosaveEnabled = false;
  c.setLanguage('en');
  c.newProject();
  return c;
}

/// Minimal little-endian TIFF: one IFD with SHORT/LONG tags.
Uint8List _tiff(Map<int, (int, int)> tags) {
  final entries = tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final b = BytesBuilder();
  final head = ByteData(8)
    ..setUint8(0, 0x49)
    ..setUint8(1, 0x49)
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, 8, Endian.little);
  b.add(head.buffer.asUint8List());
  final ifd = ByteData(2 + entries.length * 12 + 4)..setUint16(0, entries.length, Endian.little);
  for (var i = 0; i < entries.length; i++) {
    final o = 2 + i * 12;
    final (type, value) = entries[i].value;
    ifd
      ..setUint16(o, entries[i].key, Endian.little)
      ..setUint16(o + 2, type, Endian.little)
      ..setUint32(o + 4, 1, Endian.little);
    if (type == 3) {
      ifd.setUint16(o + 8, value, Endian.little);
    } else {
      ifd.setUint32(o + 8, value, Endian.little);
    }
  }
  b.add(ifd.buffer.asUint8List());
  b.add(Uint8List(64));
  return b.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cutting a lateral', () {
    List<Pt> outletsOf(List<Entity> pieces) => [for (final p in pieces) ...(p as SpraylineEntity).outletPositions()];

    test('a cut right on an outlet keeps every outlet once', () {
      final s = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(20, 0)], outletSpecId: 'micro', spacing: 5);
      final before = s.outletPositions();
      expect(before.length, 4);
      var seq = 0;
      final pieces = splitLinearEntity(s, [10], () => 'n${seq++}');
      final after = outletsOf(pieces);
      expect(after.length, before.length, reason: '$after');
      for (var i = 0; i < before.length; i++) {
        expect(after[i].distanceTo(before[i]), lessThan(1e-9));
      }
      // the outlet on the cut is the last one of the upstream piece
      expect((pieces.first as SpraylineEntity).outletPositions().last.distanceTo(const Pt(10, 0)), lessThan(1e-9));
    });

    test('several cuts on outlets of a bent lateral with a first-outlet offset', () {
      final s = SpraylineEntity(id: 's', points: [Pt.zero, const Pt(9, 0), const Pt(9, 12)], outletSpecId: 'micro', spacing: 1.5, offset: 0.75);
      final before = s.outletPositions();
      var seq = 0;
      // 3.75, 9.75 and 15.75 m are outlets; 6 m is between two
      final pieces = splitLinearEntity(s, [3.75, 6, 9.75, 15.75], () => 'n${seq++}');
      expect(pieces.length, 5);
      final after = outletsOf(pieces);
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].distanceTo(before[i]), lessThan(1e-6));
      }
    });

    test('the cut tool on an outlet does not add a sprinkler to the design', () {
      final c = _fresh();
      final s = SpraylineEntity(id: c.project.newId(), points: [Pt.zero, const Pt(20, 0)], outletSpecId: 'micro', nozzleId: 'm50', spacing: 4);
      c.addEntity(s);
      expect(c.cutAt(s.id, const Pt(8, 0.1)), isTrue);
      final n = c.project.entities.whereType<SpraylineEntity>().fold(0, (a, e) => a + e.outletCount);
      expect(n, 5);
    });

    test('a generated contour cut in two stays generated (it never feeds the terrain)', () {
      final c = ContourEntity(id: 'c', points: [Pt.zero, const Pt(10, 0)], elevation: 100, derived: true);
      final pieces = splitLinearEntity(c, [4], () => 'c2').cast<ContourEntity>();
      expect(pieces.length, 2);
      expect(pieces.every((p) => p.derived), isTrue);
      final survey = splitLinearEntity(ContourEntity(id: 'd', points: [Pt.zero, const Pt(10, 0)], elevation: 90), [4], () => 'd2').cast<ContourEntity>();
      expect(survey.any((p) => p.derived), isFalse);
    });
  });

  group('lateral blocks on irregular fields', () {
    // an L and a U with the laterals along x
    const lShape = [Pt(0, 0), Pt(100, 0), Pt(100, 50), Pt(30, 50), Pt(30, 25), Pt(0, 25)];
    const uShape = [Pt(0, 0), Pt(100, 0), Pt(100, 50), Pt(80, 50), Pt(80, 20), Pt(20, 20), Pt(20, 50), Pt(0, 50)];

    /// Unconnected entities once a supply feeds the valve.
    Set<String> unconnected(Project p, BlockResult r) {
      p.entities.addAll(r.all);
      final v = r.valve!.position;
      p.entities.addAll([
        WaterSupplyEntity(id: 'ws', position: v + const Pt(-5, 0)),
        PipeEntity(id: 'main', points: [v + const Pt(-5, 0), v], scope: HydraulicScope.mainline),
      ]);
      return NetworkBuilder(p).build().unconnectedEntities;
    }

    bool inside(List<Pt> poly, List<Pt> line) {
      for (var k = 1; k < line.length; k++) {
        for (var s = 1; s < 8; s++) {
          final q = Pt.lerp(line[k - 1], line[k], s / 8);
          final onEdge = [for (var i = 0; i < poly.length; i++) distanceToSegment(q, poly[i], poly[(i + 1) % poly.length])].reduce(math.min) < 1e-6;
          if (!pointInPolygon(q, poly) && !onEdge) return false;
        }
      }
      return true;
    }

    for (final pos in SubmainPosition.values) {
      test('L and U fields, submain at the ${pos.name}: every lateral is fed, the submain stays in the field', () {
        for (final (name, poly) in [('L', lShape), ('U', uShape)]) {
          final p = Project();
          final r = generateBlock(p, BlockOptions(polygon: poly, direction: const Pt(1, 0), lateralSpacing: 4, outletSpecId: 'micro', nozzleId: 'm50', submainPosition: pos));
          expect(unconnected(p, r), isEmpty, reason: '$name ${pos.name}');
          for (final line in [r.submain!.points, for (final b in r.branches) b.points]) {
            expect(inside(poly, line), isTrue, reason: '$name ${pos.name}: $line');
          }
        }
      });
    }

    test('the L submain steps along the inner corner instead of cutting across', () {
      final r = generateBlock(Project(), BlockOptions(polygon: lShape, direction: const Pt(1, 0), lateralSpacing: 4, outletSpecId: 'micro', nozzleId: 'm50'));
      expect(r.submain!.points, [const Pt(0, 2), const Pt(0, 24), const Pt(30, 24), const Pt(30, 46)]);
      expect(r.branches, isEmpty);
    });

    test('a U fed from one side gets a branch up the other arm', () {
      final r = generateBlock(Project(), BlockOptions(polygon: uShape, direction: const Pt(1, 0), lateralSpacing: 4, outletSpecId: 'micro', nozzleId: 'm50'));
      expect(r.submain!.points, [const Pt(0, 2), const Pt(0, 46)]);
      expect(r.branches.single.points, [const Pt(0, 20), const Pt(80, 20), const Pt(80, 46)]);
    });

    test('curved rows clipped in two feed from a branch, not a zigzag', () {
      final r = generateBlock(Project(), BlockOptions(polygon: uShape, direction: const Pt(1, 0), lateralSpacing: 4, outletSpecId: 'micro', nozzleId: 'm50', guide: const [Pt(0, 0), Pt(50, 5), Pt(100, 0)]));
      final sub = r.submain!.points;
      for (var k = 1; k < sub.length; k++) {
        expect(sub[k].y, greaterThanOrEqualTo(sub[k - 1].y - 1e-9), reason: 'the main line crosses the rows once');
      }
      expect(r.branches, isNotEmpty);
      expect(unconnected(Project(), r), isEmpty);
    });
  });

  group('telescoped mainline', () {
    /// A 400 m mainline to one zone, drawn from the supply or from the valve.
    List<(double, double, double)> pieces({required bool reversed}) {
      final p = Project();
      const valvePos = Pt(400, 0);
      final pts = [Pt.zero, const Pt(200, 0), valvePos];
      p.entities.addAll([
        PipeEntity(id: 'main', points: reversed ? pts.reversed.toList() : pts, scope: HydraulicScope.mainline),
        WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: 40),
        ControlValveEntity(id: 'v', position: valvePos, zoneName: 'Z', valveSpecId: 'ev50'),
        PipeEntity(id: 'sub', points: [valvePos, valvePos + const Pt(0, 30)], scope: HydraulicScope.zone),
        for (var i = 0; i < 8; i++) SpraylineEntity(id: 's$i', points: [valvePos + Pt(0, 2 + i * 4.0), valvePos + Pt(40, 2 + i * 4.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2),
      ]);
      p.params.maxMainlineSizes = 3;
      final r = Designer(p).designAll();
      expect(r.systemFlows.single.maxDeficit, lessThan(0.05));
      return [
        for (final m in p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline))
          (math.min(m.points.first.x, m.points.last.x), math.max(m.points.first.x, m.points.last.x), p.catalog.pipe(m.pipeSpecId)!.innerDiameterMm),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
    }

    test('the larger diameter is on the supply side whichever way the pipe was drawn', () {
      final forward = pieces(reversed: false), backward = pieces(reversed: true);
      expect(forward.length, 2, reason: 'the design telescopes this line: $forward');
      expect(forward.first.$3, greaterThan(forward.last.$3));
      expect(backward.length, forward.length);
      for (var i = 0; i < forward.length; i++) {
        expect(backward[i].$1, closeTo(forward[i].$1, 1e-6));
        expect(backward[i].$2, closeTo(forward[i].$2, 1e-6));
        expect(backward[i].$3, forward[i].$3);
      }
    });
  });

  group('opening project files', () {
    Map<String, dynamic> file() {
      final p = Project();
      for (var i = 0; i < 3; i++) {
        p.entities.add(LineEntity(id: p.newId(), a: Pt.zero, b: Pt(i + 1.0, 0)));
      }
      return jsonDecode(p.toJsonString()) as Map<String, dynamic>;
    }

    test('without the id counter, new ids do not repeat the ones in the file', () {
      final p = Project.fromJson(file()..remove('nextId'));
      final ids = p.entities.map((e) => e.id).toSet();
      final fresh = p.newId();
      expect(ids.contains(fresh), isFalse, reason: '$fresh already in $ids');
      expect(fresh, 'e4');
    });

    test('a stale counter is raised past the highest id; other ids are ignored', () {
      final j = file()..['nextId'] = 2;
      (j['entities'] as List).add(LineEntity(id: 'imported-7', a: Pt.zero, b: const Pt(1, 1)).toJson());
      (j['entities'] as List).add(LineEntity(id: 'e10', a: Pt.zero, b: const Pt(1, 1)).toJson());
      expect(Project.fromJson(j).newId(), 'e11');
      // a larger counter is kept
      expect(Project.fromJson(file()..['nextId'] = 50).newId(), 'e50');
    });

    test('layer colours written as decimals or left out still load', () {
      final j = file();
      final layers = (j['layers'] as List).cast<Map<String, dynamic>>();
      layers[0]['color'] = 4289774276.0;
      layers[1].remove('color');
      final p = Project.fromJson(j);
      expect(p.layers[0].color, 4289774276);
      expect(p.layers[1].color, Layers.defaultColors[p.layers[1].name]);
    });
  });

  group('mirroring part-circle sprinklers', () {
    // directions (degrees) watered by a sector
    bool waters(SpraySource s, double deg) => s.covers(degToRad(deg));
    SpraySource sectorOf(OutletEntity o, double arc) => SpraySource(entityId: o.id, p: o.position, flow: 1, radius: 5, startRad: degToRad(o.orientationDeg), sweepRad: degToRad(arc));

    test('the wetted sector goes to the mirrored side', () {
      // the north-east quarter (0° to 90°) mirrored about the Y axis is the north-west one
      final o = OutletEntity(id: 'o', position: const Pt(3, 0), outletSpecId: 'rotor', nozzleId: 'r3_90', arcDeg: 90, orientationDeg: 0);
      final m = o.transformed(Affine.mirror(Pt.zero, const Pt(0, 1)));
      expect(m.position, const Pt(-3, 0));
      final s = sectorOf(m, 90);
      expect(waters(s, 135), isTrue);
      expect(waters(s, 45), isFalse);
      // mirrored about the X axis (a line at 0°): the south-east quarter
      final m2 = o.transformed(Affine.mirror(Pt.zero, const Pt(1, 0)));
      expect(waters(sectorOf(m2, 90), -45), isTrue);
      expect(waters(sectorOf(m2, 90), 45), isFalse);
      // rotations keep the sense of the sweep
      final r = o.transformed(Affine.rotation(math.pi / 2));
      expect(waters(sectorOf(r, 90), 135), isTrue);
      // a full circle is not touched by the mirror
      final full = OutletEntity(id: 'f', position: Pt.zero, outletSpecId: 'rotor', orientationDeg: 30);
      expect(full.transformed(Affine.mirror(Pt.zero, const Pt(0, 1))).arcDeg, 360);
    });

    test('Mirror command: a full-circle head with a half-circle nozzle turns its half', () {
      final c = _fresh();
      final o = OutletEntity(id: c.project.newId(), position: const Pt(2, 0), outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 360, orientationDeg: 0);
      c.addEntity(o);
      c.select([o.id]);
      c.mirrorSelected(Pt.zero, const Pt(0, 1), keepSource: false);
      final m = c.project.entities.whereType<OutletEntity>().single;
      final d = computeDensogram(c.project, options: DensogramOptions(useResults: false));
      final s = d.sources.single;
      expect(m.position, const Pt(-2, 0));
      // the original half watered 0°..180° (north); mirrored about a vertical line it still does
      expect(s.covers(degToRad(90)), isTrue);
      expect(s.covers(degToRad(-90)), isFalse);
      // a half mirrored about a horizontal line waters the south instead
      c.select([m.id]);
      c.mirrorSelected(Pt.zero, const Pt(1, 0), keepSource: false);
      final s2 = computeDensogram(c.project, options: DensogramOptions(useResults: false)).sources.single;
      expect(s2.covers(degToRad(-90)), isTrue);
      expect(s2.covers(degToRad(90)), isFalse);
    });
  });

  group('part-circle nozzles on a full-circle head', () {
    OutletEntity half() => OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 360);

    test('the plot draws the nozzle half, as the densogram waters it', () {
      final p = Project()..entities.add(half());
      final scene = buildPlotScene(p, unitsPerMm: 0.5);
      expect(scene.items.whereType<PlotCircle>().where((x) => x.layer == Layers.wettedRadii), isEmpty);
      final sector = scene.items.whereType<PlotPath>().firstWhere((x) => x.layer == Layers.wettedRadii);
      expect(sector.points.every((q) => q.y >= -1e-9), isTrue, reason: 'the northern half, counter-clockwise from 0°');
      final src = spraySources(p).single;
      expect(src.sweepRad, closeTo(math.pi, 1e-12));
    });

    test('the canvas draws the half too', () {
      final c = _fresh();
      c.project.entities.add(half());
      c.camera
        ..size = const Size(1200, 800)
        ..center = Pt.zero
        ..scale = 20;
      final canvas = _SectorCanvas();
      CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(canvas, const Size(1200, 800));
      expect(canvas.circles, 0);
      expect(canvas.arcs, isNotEmpty);
      expect(canvas.arcs.first, closeTo(math.pi, 1e-9));
    });
  });

  group('survey point files', () {
    test('columns separated by spaces with decimal commas', () {
      final r = PointsCsvReader.parse('10,5 20,5 100,2\n11,25 21,75 101\n');
      final pts = [for (final e in r.document.entities) (e.points.single, e.elevation)];
      expect(pts[0].$1, const Pt(10.5, 20.5));
      expect(pts[0].$2, 100.2);
      expect(pts[1].$1, const Pt(11.25, 21.75));
      expect(pts[1].$2, 101);
      final h = PointsCsvReader.parse('x y z\n10,5 20,5 100,2\n');
      expect(h.document.entities.single.points.single, const Pt(10.5, 20.5));
      final named = PointsCsvReader.parse('P1 500,25 600,75 10,5\n');
      expect(named.document.entities.single.points.single, const Pt(500.25, 600.75));
      expect(named.document.entities.single.name, 'P1');
    });

    test('comma-separated files keep working', () {
      expect(PointsCsvReader.parse('500, 600\n501, 601\n').document.entities.first.points.single, const Pt(500, 600));
      expect(PointsCsvReader.parse('1,500,600,10\n2,510,610,11\n').document.entities.first.elevation, 10);
      expect(PointsCsvReader.parse('10.5,20.5,3.5\n').document.entities.single.points.single, const Pt(10.5, 20.5));
    });
  });

  group('KML', () {
    test('a gx:Track (GPS walk) becomes a line, a single-fix track a point', () {
      const track = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
 <Placemark><name>Walk</name><gx:Track>
  <when>2026-09-01T10:00:00Z</when><when>2026-09-01T10:01:00Z</when><when>2026-09-01T10:02:00Z</when>
  <gx:coord>-47.9300 -15.7800 1050</gx:coord><gx:coord>-47.9290 -15.7800 1051</gx:coord><gx:coord>-47.9290 -15.7790 1052</gx:coord>
 </gx:Track></Placemark>
 <Placemark><name>Fix</name><gx:MultiTrack><gx:Track><when>2026-09-01T10:05:00Z</when><gx:coord>-47.9295 -15.7795 1049</gx:coord></gx:Track></gx:MultiTrack></Placemark>
</Document></kml>''';
      final r = KmlReader.parse(track);
      final line = r.document.entities.singleWhere((e) => e.type == 'POLYLINE');
      expect(line.points.length, 3);
      expect(line.name, 'Walk');
      // 0.001° of longitude at 15.78° S ≈ 107 m
      expect(line.points[0].distanceTo(line.points[1]), closeTo(107.1, 0.5));
      final fix = r.document.entities.singleWhere((e) => e.type == 'POINT');
      expect(fix.elevation, 1049);
      expect(fix.name, 'Fix');
    });
  });

  group('rasters too large to decode', () {
    test('a TIFF whose size field claims billions of pixels is refused before decoding', () {
      // 3 623 878 676 × 20 pixels of 16 bits: the decoder would ask for 145 GB
      final t = _tiff({256: (4, 3623878676), 257: (3, 20), 258: (3, 16), 259: (3, 1), 262: (3, 1), 273: (4, 100), 277: (3, 1), 278: (3, 20), 279: (4, 800)});
      expect(GeoTiffDemReader.looksLikeDem(t), isTrue);
      expect(() => GeoTiffDemReader.read(t), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_too_large')));
      expect(() => GeoImageReader.read('dem.tif', t), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_too_large')));
    });

    test('a PNG header of 50 000 × 50 000 pixels is refused', () {
      final png = img.encodePng(img.Image(width: 2, height: 2));
      final bd = ByteData.sublistView(png);
      // IHDR data at 16..24, its CRC over type + data at 29..33
      bd.setUint32(16, 50000);
      bd.setUint32(20, 50000);
      bd.setUint32(29, getCrc32(png.sublist(12, 29)));
      expect(() => GeoImageReader.read('big.png', png), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_too_large')));
      // a normal picture still opens
      expect(GeoImageReader.read('ok.png', img.encodePng(img.Image(width: 4, height: 3))).widthPx, 4);
    });

    test('the messages exist in every language', () {
      final c = _fresh();
      for (final k in ['imp.err.image_too_large', 'imp.err.file_corrupt']) {
        expect(c.t.has(k), isTrue, reason: k);
      }
      expect(c.describeError(const FormatException('image_too_large')), contains('100'));
    });
  });

  group('damaged files', () {
    test('an index error inside a reader becomes "file damaged", not a raw error', () {
      final c = _fresh();
      // a .shp header with a valid code but records that run past the end
      final shp = ByteData(100 + 8 + 4)
        ..setUint32(0, 9994)
        ..setUint32(24, 200)
        ..setUint32(28, 1000, Endian.little)
        ..setUint32(32, 3, Endian.little)
        ..setUint32(100, 1)
        ..setUint32(104, 500)
        ..setUint32(108, 3, Endian.little);
      Object? error;
      try {
        c.importFile('broken.shp', shp.buffer.asUint8List());
      } catch (e) {
        error = e;
      }
      expect(error, isA<FormatException>().having((e) => e.message, 'message', 'file_corrupt'));
      expect(c.describeError(error!), 'The file is damaged or not in the expected format');
      expect(c.project.entities, isEmpty);
    });
  });

  group('numbers typed or read in local notation', () {
    test('decimal comma or point, thousands separators, currency around it', () {
      final cases = <String, double?>{
        '12.5': 12.5, '12,5': 12.5, '-3,25': -3.25, '1.234,56': 1234.56, '1,234.56': 1234.56, '1.234.567': 1234567, '1,234,567': 1234567,
        '1 234,5': 1234.5, '1\u00A0234,5': 1234.5, '1e-3': 0.001, ' 7 ': 7, '': null, 'abc': null, 'P1': null, '12 m': null,
      };
      cases.forEach((text, v) => expect(parseNumber(text), v == null ? isNull : closeTo(v, 1e-12), reason: text));
      expect(parseNumber('R\$ 1.234,56', lenient: true), closeTo(1234.56, 1e-12));
      expect(parseNumber('35 m', lenient: true), 35);
      expect(parseNumber('—', lenient: true), isNull);
    });

    test('a catalogue CSV with Brazilian prices keeps them', () {
      final r = CatalogIo.parseCsv('id;name;dn;di;c;price\np1;PVC 50;50;46;150;1.234,56\np2;PVC 75;75;70;150;R\$ 12,50\n');
      expect(r.catalog.pipes.map((p) => p.costPerM), [closeTo(1234.56, 1e-9), closeTo(12.5, 1e-9)]);
    });

    test('pump curve points with decimal commas, in the importer and the catalogue editor', () {
      expect(CatalogIo.parseCurvePoints('10@30; 20,5@25,5 | 30@18'), [(10.0, 30.0), (20.5, 25.5), (30.0, 18.0)]);
      expect(CatalogIo.parseCurvePoints('12.5@30.0, 20.0@25.0'), [(12.5, 30.0), (20.0, 25.0)]);
      expect(CatalogIo.parseCurvePoints('10@30,20@25,30@18'), [(10.0, 30.0), (20.0, 25.0), (30.0, 18.0)]);
      expect(CatalogIo.parseCurvePoints('10,5@30 20@25'), [(10.5, 30.0), (20.0, 25.0)]);
      expect(CatalogIo.parseCurvePoints('x@y; 5'), isEmpty);
    });
  });

  group('values that break the calculation or the saving', () {
    test('"NaN" and "Infinity" typed in a field are not numbers', () {
      for (final v in ['NaN', 'Infinity', '-Infinity', ' nan ']) {
        expect(parseNumber(v), isNull, reason: v);
      }
    });

    Project zone(Entity lateral) => Project()
      ..entities.addAll([
        WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: 30),
        PipeEntity(id: 'm', points: [Pt.zero, const Pt(20, 0)], scope: HydraulicScope.mainline),
        ControlValveEntity(id: 'v', position: const Pt(20, 0), zoneName: 'Z', valveSpecId: 'ev25'),
        PipeEntity(id: 's', points: [const Pt(20, 0), const Pt(20, 10)], scope: HydraulicScope.zone),
        lateral,
      ]);

    test('a lateral with no outlet spacing keeps one outlet: design, exports and cuts still work', () {
      final lat = SpraylineEntity(id: 'l', points: [const Pt(20, 10), const Pt(40, 10)], outletSpecId: 'micro', nozzleId: 'm50', spacing: 0);
      expect(lat.outletCount, 1);
      expect(lat.outletPositions().single, const Pt(20, 10));
      expect(SpraylineEntity(id: 'n', points: [Pt.zero, const Pt(5, 0)], outletSpecId: 'micro', spacing: double.nan).outletCount, 0);
      final p = zone(lat)..meta.georef = GeoReference.fromLatLonOrigin(-22.9, -47.06);
      final r = Designer(p).designAll();
      expect(r.zones['v']!.outlets.fold(0, (n, o) => n + o.count), 1);
      final ex = ProjectExporter(project: p, results: r, labels: ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w));
      for (final f in DrawingFormat.values) {
        expect(() => ex.exportDrawing(f), returnsNormally, reason: f.name);
      }
      // cut before and after the outlet: it stays once, where it was
      var seq = 0;
      final pieces = splitLinearEntity(SpraylineEntity(id: 'c', points: [Pt.zero, const Pt(20, 0)], outletSpecId: 'micro', spacing: 0, offset: 8), [5, 12], () => 'x${seq++}');
      expect([for (final e in pieces) ...(e as SpraylineEntity).outletPositions()], [const Pt(8, 0)]);
    });

    test('lateral calculator and tapes with no emitter spacing', () {
      final spec = LateralSpec(length: 50, diameter: 0.016, spacing: 0, emitter: EmitterCurve.fromNominal(flow: 2 * m3sPerLph, head: 10));
      expect(spec.outletCount, 1);
      expect(maxLateralLength(spec, nominalPressure: 10, minPressure: 9, maxPressure: 11), 0);
      final p = zone(TapeEntity(id: 't', points: [const Pt(20, 10), const Pt(40, 10)], tapeSpecId: 'tape16_10_30'));
      p.catalog.tape('tape16_10_30')!.emitterSpacingM = 0;
      expect(() => Designer(p).designAll(), returnsNormally);
      // a CSV with a zero spacing takes the usual one
      final cat = CatalogIo.parseCsv('id;name;idmm;spacing;qlph;hm\nt1;Tape;15.6;0;1.0;8\n', group: CatalogGroup.tapes).catalog;
      expect(cat.tapes.single.emitterSpacingM, 0.5);
    });

    test('blocks and sprinkler grids with no spacing (or a tiny one) are empty, not endless', () {
      const square = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];
      for (final sp in [0.0, -4.0, double.nan, 1e-6]) {
        final r = generateBlock(Project(), BlockOptions(polygon: square, direction: const Pt(1, 0), lateralSpacing: sp, outletSpecId: 'micro'));
        expect(r.laterals, isEmpty, reason: '$sp');
        expect(r.valve, isNull);
        expect(generateSprinklerGrid(Project(), SprinklerGridOptions(polygon: square, outletSpecId: 'rotor', spacingAlong: sp, spacingBetween: 10)), isEmpty, reason: '$sp');
      }
      final guided = generateBlock(Project(), BlockOptions(polygon: square, direction: const Pt(1, 0), lateralSpacing: 1e-6, outletSpecId: 'micro', guide: const [Pt(0, 0), Pt(100, 5)]));
      expect(guided.laterals, isEmpty);
    });

    test('a drawing with NaN coordinates imports without them; a NaN still saves', () {
      final c = _fresh();
      final dxf = ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE', '8', 'A', '10', 'NaN', '20', '0', '11', '5', '21', '5', '0', 'LINE', '8', 'A', '10', '0', '20', '0', '11', '5', '21', '5', '0', 'POINT', '8', 'CURVAS', '10', '1', '20', '1', '30', 'NaN', '0', 'ENDSEC', '0', 'EOF'].join('\n');
      expect(c.importDxf(dxf), 2);
      final spot = c.project.entities.whereType<SpotHeightEntity>().single;
      expect(spot.elevation, 0);
      // whatever gets in, saving does not fail: the value is written as null
      spot.elevation = double.nan;
      final text = c.saveJson();
      expect(text, contains('"z": null'));
      expect(Project.fromJsonString(text).entities.whereType<SpotHeightEntity>().single.elevation, 0);
      expect(encodeJson({'a': double.infinity, 'b': 1.5}), '{"a":null,"b":1.5}');
    });
  });

  group('pressure units', () {
    test('psi, kPa and bar agree with each other', () {
      const bar = Units(pressure: PressureUnit.bar), psi = Units(pressure: PressureUnit.psi), kpa = Units(pressure: PressureUnit.kPa);
      // 1 bar = 14.503774 psi, 1 psi = 6.894757 kPa
      expect(psi.pressureFromHead(bar.pressureToHead(1)), closeTo(14.503774, 1e-6));
      expect(kpa.pressureFromHead(psi.pressureToHead(1)), closeTo(6.894757, 1e-6));
      expect(psiPerMeterHead, closeTo(1.4223343, 1e-7));
    });
  });

  group('sprinkler grid CU', () {
    // every head of the (large enough) grid, as a reference
    double reference(double r, double sa, double sb, {bool tri = false, int samples = 24}) {
      final n = (r / math.min(sa, sb)).ceil() + 3;
      final depths = <double>[];
      for (var i = 0; i < samples; i++) {
        for (var j = 0; j < samples; j++) {
          final px = (i + 0.5) / samples * sa, py = (j + 0.5) / samples * sb;
          var d = 0.0;
          for (var a = -n; a <= n; a++) {
            for (var b = -n; b <= n; b++) {
              final sx = a * sa + (tri && b.isOdd ? sa / 2 : 0), sy = b * sb;
              final dist = math.sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy));
              if (dist < r) d += 1 - dist / r;
            }
          }
          depths.add(d);
        }
      }
      final mean = depths.reduce((a, b) => a + b) / depths.length;
      return 100 * (1 - depths.fold(0.0, (s, d) => s + (d - mean).abs()) / depths.length / mean);
    }

    test('heads more than two spacings away count (micro-sprinklers set close)', () {
      for (final (r, sa, sb, tri) in [(3.5, 1.0, 1.0, false), (3.5, 1.0, 3.0, false), (10.0, 2.5, 4.0, true), (12.0, 12.0, 12.0, false), (10.0, 18.0, 18.0, false)]) {
        expect(gridOverlapCU(radius: r, spacingAlong: sa, spacingBetween: sb, triangular: tri), closeTo(reference(r, sa, sb, tri: tri), 1e-9), reason: 'R $r, $sa × $sb');
      }
      // close spacing is very uniform
      expect(gridOverlapCU(radius: 3.5, spacingAlong: 1, spacingBetween: 1), greaterThan(97));
      expect(gridOverlapCU(radius: 3.5, spacingAlong: 1, spacingBetween: 1, samples: 0), 0);
    });
  });

  group('editing', () {
    test('Duplicate names its history step with the number of copies', () {
      final c = _fresh();
      final a = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
      final b = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(0, 1));
      c.addEntities([a, b]);
      c.select([a.id, b.id]);
      c.duplicateSelected();
      expect(c.historyEntries.last.label, 'hist.copy|2');
    });

    test('Paste refused while a design runs keeps the selection', () async {
      final ws = Workspace(systemClipboard: false);
      final c = ws.current..autosaveEnabled = false;
      final a = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
      c.addEntity(a);
      c.select([a.id]);
      expect(await ws.copy(), 1);
      c.busy = true;
      expect(await ws.paste(), 0);
      expect(c.selection, {a.id});
      c.busy = false;
      expect(await ws.paste(), 1);
      expect(c.selection.single, isNot(a.id));
    });

    test('Duplicate refused while a design runs keeps the selection', () {
      final c = _fresh();
      final a = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
      c.addEntity(a);
      c.select([a.id]);
      c.busy = true;
      c.duplicateSelected();
      expect(c.selection, {a.id});
      expect(c.project.entities.length, 1);
      c.busy = false;
    });
  });
}
