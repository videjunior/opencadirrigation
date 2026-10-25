import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/ifc.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

String tr(String key, [Map<String, String>? args]) => key;

/// Instances of a STEP file: id → (type, raw attribute text).
Map<int, (String, String)> instances(String step) {
  final out = <int, (String, String)>{};
  for (final m in RegExp(r'^#(\d+)=([A-Z0-9]+)\((.*)\);$', multiLine: true).allMatches(step)) {
    out[int.parse(m.group(1)!)] = (m.group(2)!, m.group(3)!);
  }
  return out;
}

void main() {
  final p = buildExample(ExampleId.sportsField, tr)..meta.georef = const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
  final results = Designer(p).designAll();
  final x = IfcWriter.write(p, results: results, fileName: 'sports.ifc', time: DateTime.utc(2026, 10, 25, 12), applicationVersion: '1.0.1');
  final inst = instances(x.text);

  test('a STEP physical file of the IFC4 schema', () {
    expect(x.text, startsWith('ISO-10303-21;\nHEADER;\n'));
    expect(x.text, contains("FILE_SCHEMA(('IFC4'));"));
    expect(x.text.trimRight(), endsWith('END-ISO-10303-21;'));
    expect(x.text, contains("FILE_NAME('sports.ifc','2026-10-25T12:00:00'"));
    // every reference points at an instance of the file
    for (final (_, args) in inst.values) {
      for (final r in RegExp(r'#(\d+)').allMatches(args)) {
        expect(inst.containsKey(int.parse(r.group(1)!)), isTrue, reason: args);
      }
    }
    // reals carry a decimal point
    expect(RegExp(r'IFCCARTESIANPOINT\(\((-?\d+\.\d*(E-?\d+)?,){2}-?\d+\.\d*(E-?\d+)?\)\)').hasMatch(x.text), isTrue);
  });

  test('unique, well-formed GlobalIds', () {
    // the first attribute of every rooted instance (objects, relations, property sets)
    final rooted = RegExp(r"^#\d+=(IFCPROJECT|IFCSITE|IFCREL[A-Z]+|IFCPROPERTYSET|IFCPIPESEGMENT|IFCFLOWTERMINAL|IFCVALVE|IFCFILTER|IFCFLOWMETER|IFCPUMP|IFCTANK|IFCDISTRIBUTIONSYSTEM)\('([^']*)'", multiLine: true);
    final ids = rooted.allMatches(x.text).map((m) => m.group(2)!).toList();
    for (final g in ids) {
      expect(RegExp(r'^[0-3][0-9A-Za-z_$]{21}$').hasMatch(g), isTrue, reason: g);
    }
    expect(ids.length, greaterThan(100));
    expect(ids.toSet().length, ids.length);
    // the same project gives the same ids
    final again = IfcWriter.write(p, results: results, fileName: 'sports.ifc', time: DateTime.utc(2026, 10, 25, 12), applicationVersion: '1.0.1');
    expect(again.text, x.text);
    expect(ifcGuid('a'), isNot(ifcGuid('b')));
    expect(ifcGuid('a'), hasLength(22));
  });

  test('project, site, georeference and the element classes', () {
    Iterable<(String, String)> of(String t) => inst.values.where((v) => v.$1 == t);
    expect(of('IFCPROJECT'), hasLength(1));
    expect(of('IFCSITE'), hasLength(1));
    final crs = of('IFCPROJECTEDCRS').single.$2;
    expect(crs, startsWith("'EPSG:31983'"));
    expect(crs, contains("'SIRGAS2000'"));
    expect(crs, contains("'23S'"));
    expect(of('IFCMAPCONVERSION').single.$2, contains('186000.,8253200.,0.,1.,0.,1.'));
    // site latitude/longitude as degrees, minutes, seconds, millionths (all negative)
    expect(RegExp(r'\(-15,-\d+,-\d+,-\d+\),\(-47,').hasMatch(of('IFCSITE').single.$2), isTrue);
    expect(of('IFCTRIANGULATEDFACESET'), hasLength(1));
    final linear = p.entities.where((e) => e.isLinearHydraulic).length;
    expect(x.counts['IFCPIPESEGMENT'], linear);
    expect(of('IFCSWEPTDISKSOLID'), hasLength(linear));
    expect(x.counts['IFCFLOWTERMINAL'], p.entities.whereType<OutletEntity>().length);
    expect(x.counts['IFCVALVE'], p.entities.whereType<ControlValveEntity>().length + 1); // and the check valve
    expect(x.counts['IFCPUMP'], 1);
    expect(x.counts['IFCTANK'], 1);
    expect(x.counts['IFCDISTRIBUTIONSYSTEM'], 1 + p.entities.whereType<ControlValveEntity>().length);
    // zone valves are user-defined with their object type, the check valve CHECK
    expect(of('IFCVALVE').where((v) => v.$2.contains("'ZONECONTROL'") && v.$2.endsWith('.USERDEFINED.')), hasLength(5));
    expect(of('IFCVALVE').where((v) => v.$2.endsWith('.CHECK.')), hasLength(1));
    expect(of('IFCFLOWTERMINAL').every((t) => t.$2.contains("'IRRIGATION_SPRINKLER'")), isTrue);
    // standard and custom property sets
    final psets = of('IFCPROPERTYSET').map((v) => RegExp(r"^'[^']*',\$,'([^']*)'").firstMatch(v.$2)!.group(1)).toSet();
    expect(psets, containsAll(['Pset_PipeSegmentTypeCommon', 'Pset_PipeSegmentOccurrence', 'Pset_ValveTypeCommon', 'Pset_ManufacturerTypeInformation', 'OCI_Hydraulics']));
    expect(x.text, contains("IFCPROPERTYSINGLEVALUE('DesignFlow',\$,IFCVOLUMETRICFLOWRATEMEASURE("));
    // the design chose fittings for the bill of materials, without positions
    expect(x.warnings, ['ifc_fittings_not_exported']);
  });

  test('pipes follow the ground at their burial depth', () {
    final terrain = p.buildTerrain();
    final pipe = p.entities.whereType<PipeEntity>().first;
    final a = pipe.points.first;
    final z = terrain.elevationAt(a) - pipe.depth;
    final point = RegExp(r'IFCCARTESIANPOINT\(\(([^,]+),([^,]+),([^)]+)\)\)').allMatches(x.text).map((m) => (double.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!)));
    expect(point.any((q) => (q.$1 - a.x).abs() < 1e-6 && (q.$2 - a.y).abs() < 1e-6 && (q.$3 - z).abs() < 1e-6), isTrue);
  });

  test('without georeference, lateral outlets, non-ASCII names', () {
    final q = buildExample(ExampleId.orchard, tr);
    q.entities.whereType<ControlValveEntity>().first.zoneName = 'Talhão Ñandú "1"';
    final y = IfcWriter.write(q, terrain: false);
    expect(y.warnings, contains('ifc_no_georef'));
    expect(y.text, isNot(contains('IFCMAPCONVERSION')));
    final outlets = q.entities.whereType<SpraylineEntity>().fold<int>(0, (s, l) => s + l.outletCount) + q.entities.whereType<OutletEntity>().length;
    expect(y.counts['IFCFLOWTERMINAL'], outlets);
    expect(y.text, contains(r"""'Talh\X2\00E3\X0\o \X2\00D1\X0\and\X2\00FA\X0\ "1"'"""));
    final capped = IfcWriter.write(q, terrain: false, maxTerminals: 10);
    expect(capped.counts['IFCFLOWTERMINAL'], 10);
    expect(capped.warnings, contains('ifc_terminals_limited:10'));
    expect(IfcWriter.write(Project()).counts, isEmpty);
  });
}
