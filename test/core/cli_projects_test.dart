/// The command line making and changing projects (1.6.0 MOD, MOD-22):
/// import of drawings and maps, a new project from a boundary with its
/// layout, settings and catalogue packs, and several projects in one run.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/drawing_import.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import '../../bin/oci.dart';

/// A lawn of about 43 × 33 m near Brasília, as a GeoJSON polygon.
const _lawn =
    '{"type": "FeatureCollection", "features": [{"type": "Feature", "properties": {"name": "Lawn"}, "geometry": {"type": "Polygon", "coordinates": '
    '[[[-47.9300, -15.7800], [-47.9296, -15.7800], [-47.9296, -15.7797], [-47.9300, -15.7797], [-47.9300, -15.7800]]]}}]}';

void main() {
  final home = Directory.current.path;
  late Directory tmp;
  setUpAll(() => tmp = Directory.systemTemp.createTempSync('oci_projects_'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> oci(List<String> args) async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runOci(args, out: out, err: err, home: home);
    return (code, out.toString(), err.toString());
  }

  String at(String name) => '${tmp.path}/$name';
  Project read(String path) => readProjectFile(File(path).readAsStringSync()).project;

  test('the engine imports by extension; what it does not read says so', () {
    final p = Project();
    final r = importFileInto(p, 'lawn.geojson', Uint8List.fromList(utf8.encode(_lawn)));
    expect(r.kind, 'geojson');
    expect(r.georefTaken, isTrue);
    expect(p.meta.georef, isNotNull);
    expect(r.entities.whereType<PolylineEntity>().single.closed, isTrue);
    expect(p.entities.length, r.entities.length);
    expect(() => importFileInto(p, 'plan.pdf', Uint8List(4)), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'import_format')));
  });

  test('import makes a project of maps; new makes one of a boundary and lays the heads', () async {
    File(at('lawn.geojson')).writeAsStringSync(_lawn);
    var (code, out, err) = await oci(['import', at('lawn.geojson'), '--out', at('lawn.oci.json')]);
    expect(code, OciExit.ok, reason: err);
    expect(out, contains('geojson, 1 items'));
    final imported = read(at('lawn.oci.json'));
    expect(imported.meta.georef, isNotNull);
    expect(imported.entities.whereType<PolylineEntity>(), hasLength(1));
    (code, out, err) = await oci(['new', '--out', at('new.oci.json'), '--boundary', at('lawn.geojson'), '--layout', '--currency', 'USD', '--hz', '50', '--name', 'Front lawn']);
    expect(code, OciExit.ok, reason: err);
    final p = read(at('new.oci.json'));
    expect(p.meta.name, 'Front lawn');
    expect(p.params.currencyCode, 'USD');
    expect(p.params.mainsHz, 50);
    final area = p.entities.whereType<AreaEntity>().single;
    expect(area.area, inInclusiveRange(1000, 2000));
    expect(p.entities.whereType<PolylineEntity>(), isEmpty, reason: 'the outline became the area');
    expect(p.entities.whereType<OutletEntity>(), isNotEmpty);
    expect(out, contains('layout: '));
    // a polygon with a hole: the hole is an island of the area
    File(at('pond.geojson')).writeAsStringSync(
      '{"type": "FeatureCollection", "features": [{"type": "Feature", "properties": {}, "geometry": {"type": "Polygon", "coordinates": ['
      '[[-47.9300, -15.7800], [-47.9296, -15.7800], [-47.9296, -15.7797], [-47.9300, -15.7797], [-47.9300, -15.7800]], '
      '[[-47.9299, -15.7799], [-47.9299, -15.7798], [-47.9298, -15.7798], [-47.9298, -15.7799], [-47.9299, -15.7799]]]}}]}',
    );
    (code, out, err) = await oci(['new', '--out', at('pond.oci.json'), '--boundary', at('pond.geojson')]);
    expect(code, OciExit.ok, reason: err);
    final pond = read(at('pond.oci.json')).entities.whereType<AreaEntity>().single;
    expect(pond.holes, hasLength(1));
    expect(pond.area, lessThan(pond.grossArea));
    // nothing closed to make an area of
    File(at('line.geojson')).writeAsStringSync(
      '{"type": "FeatureCollection", "features": [{"type": "Feature", "properties": {}, "geometry": {"type": "LineString", "coordinates": [[-47.93, -15.78], [-47.9296, -15.78]]}}]}',
    );
    expect((await oci(['new', '--out', at('none.oci.json'), '--boundary', at('line.geojson')])).$1, OciExit.failed);
    expect((await oci(['new', '--out', at('none.oci.json'), '--layout'])).$1, OciExit.usage);
    expect((await oci(['import', at('nothing.dxf'), '--out', at('x.oci.json')])).$1, OciExit.io);
  });

  test('set changes units, currency and frequency; pack add brings a catalogue in', () async {
    File(at('lawn.geojson')).writeAsStringSync(_lawn);
    expect((await oci(['import', at('lawn.geojson'), '--out', at('farm.oci.json')])).$1, OciExit.ok);
    final before = read(at('farm.oci.json'));
    final price = before.catalog.pipes.first.costPerM;
    var (code, _, err) = await oci(['set', at('farm.oci.json'), '--units', 'us', '--currency', 'USD', '--hz', '60', '--out', at('farm_us.oci.json')]);
    expect(code, OciExit.ok, reason: err);
    final us = read(at('farm_us.oci.json'));
    expect(us.params.units.toJson(), Units.us.toJson());
    expect(us.params.currencyCode, 'USD');
    expect(us.params.mainsHz, 60);
    if (before.params.currencyCode != 'USD' && price > 0) expect(us.catalog.pipes.first.costPerM, isNot(price), reason: 'prices follow the currency');
    expect((await oci(['set', at('farm.oci.json'), '--hz', '55'])).$1, OciExit.usage);
    expect((await oci(['set', at('farm.oci.json'), '--currency', 'XYZ'])).$1, OciExit.usage);
    (code, _, err) = await oci(['pack', 'add', at('farm_us.oci.json'), 'iso1452']);
    expect(code, OciExit.ok, reason: err);
    final packed = read(at('farm_us.oci.json'));
    expect(packed.catalog.pipe('iso1452_pn10_110'), isNotNull);
    expect((await oci(['pack', 'add', at('farm_us.oci.json'), 'no_such_pack'])).$1, OciExit.io);
    expect((await oci(['pack', 'remove', at('farm_us.oci.json'), 'iso1452'])).$1, OciExit.usage);
  });

  test('several projects in one run: each one designed into --out-dir, the worst exit code', () async {
    const a = 'examples/pt/garden.oci.json', b = 'examples/pt/orchard.oci.json';
    var (code, out, err) = await oci(['design', a, b, '--out-dir', at('designed'), '--report', 'csv']);
    expect(code, OciExit.ok, reason: err);
    expect(out, contains('2 projects: 2 done'));
    expect(File(at('designed/garden.oci.json')).existsSync(), isTrue);
    expect(File(at('designed/orchard.oci.json')).existsSync(), isTrue);
    expect(File(at('designed/garden.report.csv')).existsSync(), isTrue);
    expect(jsonDecode(File(at('designed/garden.oci.json')).readAsStringSync()), containsPair('results', isA<Map<String, dynamic>>()));
    // a folder of projects, one of them damaged: the others still run
    final dir = Directory(at('batch'))..createSync();
    File(a).copySync('${dir.path}/garden.oci.json');
    File('${dir.path}/broken.oci.json').writeAsStringSync('{"format": "nothing"}');
    (code, out, err) = await oci(['validate', dir.path]);
    expect(code, OciExit.io);
    expect(out, contains('2 projects: '));
    expect(err, contains('broken.oci.json'));
    expect((await oci(['design', a, b, '--out', at('one.oci.json')])).$1, OciExit.usage, reason: 'several projects take --out-dir');
    expect((await oci(['check', at('empty_folder')])).$1, isNot(OciExit.ok));
  });
}
