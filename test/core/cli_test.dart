import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/version.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/epanet_inp.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

import '../../bin/oci.dart';

/// The command line (bin/oci.dart) run in-process on a shipped example.
void main() {
  const example = 'examples/pt/garden.oci.json';
  final home = Directory.current.path;
  late Directory tmp;

  setUpAll(() => tmp = Directory.systemTemp.createTempSync('oci_cli_'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> oci(List<String> args) async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runOci(args, out: out, err: err, home: home);
    return (code, out.toString(), err.toString());
  }

  String at(String name) => '${tmp.path}/$name';

  test('help, version and bad command lines', () async {
    var (code, out, _) = await oci(['--help']);
    expect(code, OciExit.ok);
    expect(out, contains('Usage: dart run bin/oci.dart <command>'));
    for (final c in ['design', 'analyze', 'check', 'export', 'bom']) {
      expect(out, contains('  $c '), reason: c);
    }
    (code, out, _) = await oci(['--version']);
    expect(out.trim(), '$appName $appVersionFull');
    expect((await oci([])).$1, OciExit.usage);
    expect((await oci(['size', example])).$1, OciExit.usage);
    expect((await oci(['design'])).$1, OciExit.usage);
    expect((await oci(['design', example, '--frobnicate'])).$1, OciExit.usage);
    expect((await oci(['design', example, '--lang', 'xx'])).$1, OciExit.usage);
    expect((await oci(['design', example, '--out'])).$1, OciExit.usage);
    final missing = await oci(['design', at('nothing.oci.json')]);
    expect(missing.$1, OciExit.io);
    expect(missing.$3, contains('no such file'));
    File(at('not_a_project.json')).writeAsStringSync('{"format": "something else"}');
    expect((await oci(['check', at('not_a_project.json')])).$1, OciExit.io);
  });

  test('design sizes the example, writes the project, the results and the report', () async {
    final (code, out, err) = await oci(['design', example, '--lang', 'pt', '--out', at('designed.oci.json'), '--results', at('results.json'), '--report', at('report.csv')]);
    expect(code, OciExit.ok, reason: err);
    expect(out, startsWith('$appName $appVersionFull · design · Jardim residencial'));
    expect(out, contains('RESUMO DAS ZONAS'));
    expect(out, contains('Zona 1'));
    expect(out, contains('Mensagens: 0 erro(s)'));
    // the same numbers as the engine called directly
    final direct = Project.fromJsonString(File(example).readAsStringSync());
    final r = Designer(direct).designAll();
    final written = DesignResults.fromJson(jsonDecode(File(at('results.json')).readAsStringSync()) as Map<String, dynamic>);
    expect(written.zones.keys, r.zones.keys);
    for (final z in r.zones.values) {
      expect(written.zones[z.valveId]!.totalFlow, closeTo(z.totalFlow, 1e-12));
      expect(written.zones[z.valveId]!.requiredUpstreamHead, closeTo(z.requiredUpstreamHead, 1e-9));
    }
    expect(written.capitalCost, closeTo(r.capitalCost, 1e-6));
    // the designed project opens and its computer-sized pipes have sizes
    final designed = Project.fromJsonString(File(at('designed.oci.json')).readAsStringSync());
    expect(designed.entities.length, direct.entities.length);
    final pipes = designed.entities.whereType<PipeEntity>().toList();
    expect(pipes, isNotEmpty);
    expect(pipes.every((p) => designed.catalog.pipe(p.pipeSpecId) != null), isTrue);
    // the report: every table, in Portuguese
    final csv = File(at('report.csv')).readAsStringSync();
    expect(csv, contains('RESUMO DAS ZONAS'));
    expect(csv, contains('LISTA DE MATERIAIS'));
    expect(err, contains('wrote ${at('report.csv')}'));
    // the project is written with its results, as the app saves it (MOD-31)
    final file = readProjectFile(File(at('designed.oci.json')).readAsStringSync());
    expect(file.results, isNotNull);
    expect(DesignResults.fromJson(file.results!).capitalCost, closeTo(r.capitalCost, 1e-6));
    final (bare, _, _) = await oci(['design', example, '--out', at('bare.oci.json'), '--no-results']);
    expect(bare, OciExit.ok);
    expect(readProjectFile(File(at('bare.oci.json')).readAsStringSync()).results, isNull);
  });

  test('validate lists what reading the file repaired (MOD-23)', () async {
    var (code, out, _) = await oci(['validate', example]);
    expect(code, OciExit.ok, reason: out);
    expect(out, contains('nothing to repair'));
    final j = jsonDecode(File(example).readAsStringSync()) as Map<String, dynamic>;
    j['version'] = 99;
    (j['entities'] as List).add({'type': 'futureThing', 'id': 'e999'});
    File(at('damaged.oci.json')).writeAsStringSync(jsonEncode(j));
    final String err;
    (code, out, err) = await oci(['validate', at('damaged.oci.json'), '--json']);
    expect(code, OciExit.problems);
    final v = jsonDecode(out) as Map<String, dynamic>;
    expect(v['newerVersion'], isTrue);
    expect(v['skipped'], {'entities': 1});
    expect(err, contains('could not be read'), reason: 'other commands report the repairs too');
    File(at('not_json.oci.json')).writeAsStringSync('{"format": "opencadirrigation", "entities": [');
    final broken = await oci(['validate', at('not_json.oci.json')]);
    expect(broken.$1, OciExit.io);
    expect(broken.$3, contains('not valid JSON'));
  });

  test('reports in every format; analyze keeps the drawing', () async {
    for (final ext in ['txt', 'xlsx', 'pdf']) {
      final (code, _, err) = await oci(['analyze', example, '--report', at('report.$ext')]);
      expect(code, OciExit.ok, reason: '$ext: $err');
    }
    expect(File(at('report.txt')).readAsStringSync(), contains('ZONE SUMMARY'));
    expect(File(at('report.xlsx')).readAsBytesSync().sublist(0, 2), 'PK'.codeUnits);
    expect(String.fromCharCodes(File(at('report.pdf')).readAsBytesSync().sublist(0, 5)), '%PDF-');
    expect((await oci(['analyze', example, '--out', at('x.oci.json')])).$1, OciExit.usage, reason: 'analysis changes nothing to save');
    expect((await oci(['analyze', example, '--report', at('report.doc')])).$1, OciExit.usage);
  });

  test('a language pack from assets/i18n labels the output', () async {
    final pack = jsonDecode(File('assets/i18n/de.json').readAsStringSync()) as Map<String, dynamic>;
    final title = (pack['strings'] as Map)['reports.zone'] as String;
    final (code, out, err) = await oci(['analyze', example, '--lang', 'de']);
    expect(code, OciExit.ok, reason: err);
    expect(out, contains(title.toUpperCase()));
  });

  test('check: exit code 1 on errors, explanations, JSON', () async {
    final ok = await oci(['check', example, '--design']);
    expect(ok.$1, OciExit.ok, reason: ok.$2);
    expect(ok.$2, contains('Design check: Jardim residencial'));
    // without its water supply the project cannot be designed
    final p = Project.fromJsonString(File(example).readAsStringSync());
    p.entities.removeWhere((e) => e is WaterSupplyEntity);
    File(at('no_supply.oci.json')).writeAsStringSync(p.toJsonString());
    final (code, out, _) = await oci(['check', at('no_supply.oci.json')]);
    expect(code, OciExit.problems);
    expect(out, contains('error'));
    expect(out, contains('How to fix:'));
    final (jsonCode, json, _) = await oci(['check', at('no_supply.oci.json'), '--json', '--lang', 'es']);
    expect(jsonCode, OciExit.problems);
    final j = jsonDecode(json) as Map<String, dynamic>;
    expect(j['errors'], greaterThan(0));
    final first = (j['messages'] as List).first as Map<String, dynamic>;
    expect(first['level'], 'error');
    expect(first['code'], 'no_supply');
    expect(first['how'], isNotEmpty);
  });

  test('export writes every drawing format', () async {
    const georef = ['--georef', '-22.9068,-43.1729'];
    final checks = <String, bool Function(Uint8List bytes)>{
      'dxf': (b) => DxfReader.parse(utf8.decode(b)).entities.isNotEmpty,
      'dwg': (b) => DwgReader.parse(b).document.entities.isNotEmpty,
      'pdf': (b) => String.fromCharCodes(b.sublist(0, 5)) == '%PDF-',
      'svg': (b) => utf8.decode(b).contains('<svg'),
      'kml': (b) => KmlReader.parse(utf8.decode(b)).placemarkCount > 0,
      'kmz': (b) => String.fromCharCodes(b.sublist(0, 2)) == 'PK',
      'geojson': (b) => (jsonDecode(utf8.decode(b)) as Map)['type'] == 'FeatureCollection',
      'shp': (b) => String.fromCharCodes(b.sublist(0, 2)) == 'PK',
      'gpx': (b) => utf8.decode(b).contains('<gpx'),
      'landxml': (b) => utf8.decode(b).contains('<LandXML'),
      'ifc': (b) => utf8.decode(b).startsWith('ISO-10303-21'),
      'inp': (b) => EpanetInpReader.parse(utf8.decode(b)).toNetwork().solve().converged,
    };
    for (final e in checks.entries) {
      final path = at('drawing.${e.key}');
      final (code, _, err) = await oci(['export', example, '--format', e.key, '--out', path, '--design', ...georef]);
      expect(code, OciExit.ok, reason: '${e.key}: $err');
      expect(e.value(File(path).readAsBytesSync()), isTrue, reason: e.key);
    }
    // geographic formats need a georeference
    final (code, _, err) = await oci(['export', example, '--format', 'kml', '--out', at('x.kml')]);
    expect(code, OciExit.failed);
    expect(err, contains('--georef'));
    expect((await oci(['export', example, '--format', 'kml', '--georef', 'nowhere'])).$1, OciExit.usage);
    expect((await oci(['export', example, '--format', 'doc'])).$1, OciExit.usage);
    expect((await oci(['export', example])).$1, OciExit.usage);
    // a sheet size and orientation
    final sheet = await oci(['export', example, '--format', 'svg', '--paper', 'a1', '--portrait', '--out', at('a1.svg')]);
    expect(sheet.$1, OciExit.ok, reason: sheet.$3);
    expect((await oci(['export', example, '--format', 'svg', '--paper', 'b5'])).$1, OciExit.usage);
  });

  test('export without --out writes next to the project', () async {
    final copy = File(at('copy.oci.json'))..writeAsStringSync(File(example).readAsStringSync());
    final (code, _, err) = await oci(['export', copy.path, '--format', 'dxf']);
    expect(code, OciExit.ok, reason: err);
    expect(File(at('copy.dxf')).existsSync(), isTrue);
  });

  test('bom prints the bill of materials and writes it', () async {
    final (code, out, err) = await oci(['bom', example, '--lang', 'pt', '--out', at('bom.xlsx')]);
    expect(code, OciExit.ok, reason: err);
    expect(out, contains('LISTA DE MATERIAIS'));
    expect(File(at('bom.xlsx')).readAsBytesSync().sublist(0, 2), 'PK'.codeUnits);
    final csv = await oci(['bom', example, '--out', at('bom.csv')]);
    expect(csv.$1, OciExit.ok);
    final text = File(at('bom.csv')).readAsStringSync();
    expect(text, contains('BILL OF MATERIALS'));
    expect(text, isNot(contains('ZONE SUMMARY')), reason: 'the bill of materials only');
  });

  test('the command line pulls in no Flutter', () {
    // every library bin/oci.dart reaches inside the package
    final seen = <String>{};
    final todo = ['bin/oci.dart'];
    final offenders = <String>[];
    while (todo.isNotEmpty) {
      final path = todo.removeLast();
      if (!seen.add(path)) continue;
      final text = File(path).readAsStringSync();
      for (final m in RegExp(r'''^(?:import|export)\s+'([^']+)'(?:\s|;)''', multiLine: true).allMatches(text)) {
        final uri = m.group(1)!;
        if (uri.startsWith('package:flutter') || uri == 'dart:ui') offenders.add('$path → $uri');
        if (uri.startsWith('package:opencadirrigation/')) {
          todo.add('lib/${uri.substring('package:opencadirrigation/'.length)}');
        } else if (!uri.contains(':')) {
          todo.add(File(path).parent.uri.resolve(uri).toFilePath().replaceFirst('${Directory.current.path}/', ''));
        }
      }
    }
    expect(offenders, isEmpty);
    expect(seen.where((p) => p.startsWith('lib/app/')).toSet(), {'lib/app/i18n.dart', 'lib/app/version.dart'}, reason: 'only the plain-Dart string table and version from lib/app');
  });
}
