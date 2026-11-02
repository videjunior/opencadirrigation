import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/landxml.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:xml/xml.dart';

String tr(String key, [Map<String, String>? args]) => key;

const georef = GeoReference(zone: 23, north: false, originEasting: 245000, originNorthing: 7480000);

void main() {
  final p = buildExample(ExampleId.gravity, tr)..meta.georef = georef;
  final results = Designer(p).designAll();
  final xml = LandXmlWriter.write(p, results: results, applicationVersion: '1.0.1', time: DateTime(2026, 10, 25, 9, 30));
  final doc = XmlDocument.parse(xml);
  final root = doc.rootElement;
  Iterable<XmlElement> all(String n) => root.findAllElements(n);

  test('the document follows the LandXML 1.2 structure', () {
    expect(root.name.local, 'LandXML');
    expect(root.namespaceUri, 'http://www.landxml.org/schema/LandXML-1.2');
    expect(root.getAttribute('version'), '1.2');
    expect(root.getAttribute('date'), '2026-10-25');
    expect(root.getAttribute('time'), '09:30:00');
    final metric = all('Metric').single;
    for (final a in ['areaUnit', 'linearUnit', 'volumeUnit', 'temperatureUnit', 'pressureUnit']) {
      expect(metric.getAttribute(a), isNotNull, reason: a);
    }
    final cs = all('CoordinateSystem').single;
    expect(cs.getAttribute('epsgCode'), '31983');
    expect(parseCrs(cs.getAttribute('ogcWktCode')!).utmZone, 23);
    // the TIN of the project, every vertex and triangle
    final tin = p.buildTerrain().tin;
    expect(all('P').length, tin.pointCount);
    expect(all('F').length, tin.triangles.length);
    final def = all('Definition').single;
    expect(def.getAttribute('surfType'), 'TIN');
    expect(double.parse(def.getAttribute('elevMin')!), lessThan(double.parse(def.getAttribute('elevMax')!)));
    // the surface keeps SourceData before Definition, Structs before Pipes
    final surface = all('Surface').single;
    expect(surface.childElements.map((e) => e.name.local).toList(), ['SourceData', 'Definition']);
    expect(all('Contour').length, p.entities.whereType<ContourEntity>().length);
    for (final net in all('PipeNetwork')) {
      expect(net.childElements.map((e) => e.name.local).toList(), ['Structs', 'Pipes']);
      expect(net.getAttribute('pipeNetType'), 'water');
      expect(net.findAllElements('Struct').length, greaterThanOrEqualTo(2));
    }
    // document-wide unique names (StructKey, PipeKey) and valid references
    final structs = {for (final s in all('Struct')) s.getAttribute('name')!: s};
    final pipes = {for (final s in all('Pipe')) s.getAttribute('name')!: s};
    expect(structs.length, all('Struct').length);
    expect(pipes.length, all('Pipe').length);
    for (final pp in pipes.values) {
      expect(structs.containsKey(pp.getAttribute('refStart')), isTrue);
      expect(structs.containsKey(pp.getAttribute('refEnd')), isTrue);
      expect(pp.childElements.first.name.local, 'CircPipe');
    }
    for (final s in structs.values) {
      expect(s.childElements.map((e) => e.name.local).take(2).toList(), ['Center', 'Connection']);
      final inv = s.findElements('Invert').toList();
      expect(inv, isNotEmpty);
      for (final i in inv) {
        expect(pipes.containsKey(i.getAttribute('refPipe')), isTrue);
        expect(['in', 'out'], contains(i.getAttribute('flowDir')));
      }
    }
    // CgPoint names unique within their group
    for (final g in all('CgPoints')) {
      final names = g.findElements('CgPoint').map((e) => e.getAttribute('name')).toList();
      expect(names.toSet().length, names.length);
    }
  });

  test('inverts are the ground minus the burial depth minus half the inner diameter', () {
    final terrain = p.buildTerrain();
    final pipe = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline && e.depth > 0, orElse: () => p.entities.whereType<PipeEntity>().first);
    final spec = p.catalog.pipe(pipe.pipeSpecId)!;
    final a = pipe.points.first;
    final (e, n) = georef.toUtm(a.x, a.y);
    final s = all('Struct').firstWhere((s) {
      final c = s.getElement('Center')!.innerText.split(' ').map(double.parse).toList();
      return (c[0] - n).abs() < 1e-3 && (c[1] - e).abs() < 1e-3;
    });
    // a struct where several pipes meet has one invert per pipe
    final zs = [for (final i in s.findElements('Invert')) double.parse(i.getAttribute('elev')!)];
    final expected = terrain.elevationAt(a) - pipe.depth - spec.innerDiameterMm / 2000;
    expect(zs.any((z) => (z - expected).abs() < 1e-3), isTrue, reason: '$zs vs $expected');
    expect(double.parse(s.getAttribute('elevRim')!), closeTo(terrain.elevationAt(a), 1e-3));
    // design flow and hydraulic grade carried by PipeFlow
    expect(all('PipeFlow'), isNotEmpty);
  });

  test('read back: CgPoints, the surface source data and TIN, the pipes', () {
    final r = LandXmlReader.parse(xml, georef: georef);
    expect(r.crs.datum, GeodeticDatum.sirgas2000);
    expect(r.warnings, isEmpty);
    final hydraulic = p.entities
        .where((e) => e is OutletEntity || e is ControlValveEntity || e is WaterSupplyEntity || e is PumpEntity || e is MiscHydraulicEntity || e is JunctionEntity || e is ControllerEntity)
        .toList();
    expect(r.cgPointCount, hydraulic.length);
    for (final e in hydraulic.cast<PointEntity>()) {
      expect(r.document.entities.any((d) => d.layer == 'HYDRAULICS' && d.points.first.distanceTo(e.position) < 1e-3), isTrue, reason: e.id);
    }
    // the surface has source data: contours and spot heights come back as such
    final contours = p.entities.whereType<ContourEntity>().toList();
    final polys = r.document.entities.where((d) => d.type == 'POLYLINE' && d.layer == 'TERRAIN').toList();
    expect(polys.length, contours.length);
    for (final c in contours) {
      final d = polys.firstWhere((d) => d.points.first.distanceTo(c.points.first) < 1e-3);
      expect(d.elevation, closeTo(c.elevation, 1e-3));
    }
    final spots = p.entities.whereType<SpotHeightEntity>().toList();
    final pts = r.document.entities.where((d) => d.type == 'POINT' && d.layer == 'TERRAIN').toList();
    expect(pts.length, spots.length);
    for (final s in spots) {
      expect(pts.firstWhere((d) => d.points.first.distanceTo(s.position) < 1e-3).elevation, closeTo(s.elevation, 1e-3));
    }
    // the TIN itself
    final tin = p.buildTerrain().tin;
    final surf = r.surfaces.single;
    expect(surf.points.length, tin.pointCount);
    expect(surf.faces.length, tin.triangles.length);
    final t0 = tin.triangles.first;
    final (f0, f1, f2) = surf.faces.first;
    expect([f0, f1, f2], [t0.a, t0.b, t0.c]);
    expect(surf.points[t0.a].$1.distanceTo(tin.vertex(t0.a)), lessThan(1e-3));
    // pipes with their inner diameter
    expect(r.pipeCount, all('Pipe').length);
    final first = r.pipes.first;
    expect(first.diameter, isNotNull);
    expect(first.invertStart, isNotNull);
  });

  test('a surface read from its Definition is decimated to the terrain limit', () {
    final r = LandXmlReader.parse(xml, georef: georef, source: LandXmlSurfaceSource.definition, maxPoints: 20);
    final pts = r.document.entities.where((d) => d.type == 'POINT' && d.layer == 'TERRAIN').toList();
    expect(pts.length, lessThanOrEqualTo(20));
    expect(r.warnings.single, startsWith('landxml_decimated:TERRAIN:'));
    final full = LandXmlReader.parse(xml, georef: georef, source: LandXmlSurfaceSource.definition);
    expect(full.document.entities.where((d) => d.type == 'POINT' && d.layer == 'TERRAIN').length, p.buildTerrain().tin.pointCount);
  });

  test('a file from survey software: imperial units, breaklines, boundary, grid faces, no CRS', () {
    const text = '''<?xml version="1.0"?>
<LandXML xmlns="http://www.landxml.org/schema/LandXML-1.2" date="2026-01-01" time="00:00:00" version="1.2">
  <Units><Imperial areaUnit="squareFoot" linearUnit="foot" volumeUnit="cubicFeet" temperatureUnit="fahrenheit" pressureUnit="inchHG" diameterUnit="inch"/></Units>
  <CgPoints name="Survey"><CgPoint name="BM1" code="BM">1000 2000 330</CgPoint><CgPoint name="REF" pntRef="BM1"/></CgPoints>
  <Surfaces><Surface name="EG">
    <SourceData>
      <Breaklines><Breakline name="ditch"><PntList3D>1000 2000 330 1010 2000 329 1020 2005 328</PntList3D></Breakline></Breaklines>
      <Boundaries><Boundary bndType="outer" edgeTrim="true"><PntList2D>990 1990 990 2030 1030 2030 1030 1990</PntList2D></Boundary></Boundaries>
    </SourceData>
    <Definition surfType="grid"><Pnts><P id="1">1000 2000 330</P><P id="2">1000 2010 331</P><P id="3">1010 2010 332</P><P id="4">1010 2000 331</P></Pnts><Faces><F>1 2 3 4</F></Faces></Definition>
  </Surface></Surfaces>
  <PipeNetworks><PipeNetwork name="W" pipeNetType="water"><Structs>
    <Struct name="A"><Center>1000 2000</Center><Connection/><Invert elev="325" flowDir="out" refPipe="P"/></Struct>
    <Struct name="B"><Center>1000 2100</Center><Connection/><Invert elev="324" flowDir="in" refPipe="P"/></Struct>
  </Structs><Pipes><Pipe name="P" refStart="A" refEnd="B"><CircPipe diameter="6"/></Pipe></Pipes></PipeNetwork></PipeNetworks>
</LandXML>''';
    final r = LandXmlReader.parse(text);
    expect(r.georef, isNull);
    expect(r.warnings, ['crs_missing']);
    expect(r.cgPointCount, 1); // the point by reference has no coordinates
    final bm = r.document.entities.firstWhere((d) => d.name == 'BM1');
    expect(bm.elevation, closeTo(330 * 0.3048, 1e-9));
    // northing easting order and feet: BM1 is 2000 ft east, 1000 ft north
    final ditch = r.document.entities.firstWhere((d) => d.name == 'ditch');
    expect(ditch.elevation, isNull); // a sloping breakline
    expect((ditch.points[1] - ditch.points[0]).y, closeTo(10 * 0.3048, 1e-9));
    expect((ditch.points[1] - ditch.points[0]).x, closeTo(0, 1e-9));
    expect(r.document.entities.where((d) => d.type == 'POINT' && d.layer == 'EG').map((d) => d.elevation), [330 * 0.3048, 329 * 0.3048, 328 * 0.3048]);
    expect(r.document.entities.where((d) => d.closed), hasLength(1));
    expect(r.surfaces.single.faces, hasLength(2)); // the grid face split in two
    final pipe = r.pipes.single;
    expect(pipe.diameter, closeTo(6 * 0.0254, 1e-12));
    expect(pipe.invertEnd, closeTo(324 * 0.3048, 1e-9));
    expect(pipe.points.last.distanceTo(pipe.points.first), closeTo(100 * 0.3048, 1e-9));
    expect(() => LandXmlReader.parse('<other/>'), throwsA(isA<FormatException>()));
  });

  test('a project without georeference is written in local metres', () {
    final q = Project.fromJson(p.toJson())..meta.georef = null;
    final text = LandXmlWriter.write(q);
    expect(XmlDocument.parse(text).rootElement.findAllElements('CoordinateSystem'), isEmpty);
    final r = LandXmlReader.parse(text);
    expect(r.georef, isNull);
    final s = q.entities.whereType<SpotHeightEntity>().first;
    expect(r.document.entities.any((d) => d.type == 'POINT' && d.points.first.distanceTo(s.position) < 1e-3), isTrue);
    expect(r.localOrigin, Pt.zero);
  });
}
