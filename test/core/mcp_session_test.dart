// a session designs, exports and starts an isolate per call: slow when the
// machine is busy with the rest of the suite
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/mcp/json_schema.dart';
import 'package:opencadirrigation/core/mcp/mcp_server.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

import '../../bin/oci.dart';
import '../../bin/src/oci_mcp_io.dart';

/// The OpenCADIrrigation tools of the MCP server (`oci mcp`, docs/MCP.md)
/// driven through in-memory lines, as an AI application would: their
/// definitions, a whole session on a shipped example (copy, design, check,
/// bill of materials, report tables, DXF and PDF), the writing tools, the
/// read-only server and the paths kept inside the root.
void main() {
  final home = Directory.current.path;
  late Directory tmp;
  late List<Map<String, dynamic>> sent;
  late McpServer server;
  var nextId = 0;

  McpServer make({bool readOnly = false}) => ociMcpServer(root: McpRootDirectory.open(tmp.path), home: home, readOnly: readOnly, send: (m) => sent.add(jsonDecode(m) as Map<String, dynamic>));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('oci_mcp_');
    sent = [];
    server = make();
  });
  tearDown(() async {
    await server.close();
    tmp.deleteSync(recursive: true);
  });

  const meta = {
    'io.modelcontextprotocol/protocolVersion': '2026-07-28',
    'io.modelcontextprotocol/clientCapabilities': <String, Object?>{},
    'io.modelcontextprotocol/clientInfo': {'name': 'test', 'version': '1'},
  };

  Future<Map<String, dynamic>> request(String method, [Map<String, Object?> params = const {}]) async {
    final id = ++nextId;
    server.receive(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': {...params, '_meta': meta},
      }),
    );
    for (var i = 0; i < 6000; i++) {
      final hit = sent.where((m) => m['id'] == id);
      if (hit.isNotEmpty) return hit.first;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('no answer to $method');
  }

  late List<Map<String, dynamic>> toolDefs;

  /// Calls [name]; checks the result against the tool's output schema.
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> arguments, {bool error = false}) async {
    final m = await request('tools/call', {'name': name, 'arguments': arguments});
    expect(m['error'], isNull, reason: '$name: ${m['error']}');
    final r = m['result'] as Map<String, dynamic>;
    final text = (r['content'] as List).single['text'] as String;
    expect(r['isError'], error, reason: '$name: $text');
    if (error) return {'error': text};
    final def = toolDefs.where((t) => t['name'] == name).single;
    expect(schemaErrors(r['structuredContent'], def['outputSchema'], path: 'result'), isEmpty, reason: '$name: the result follows its output schema');
    expect(jsonDecode(text), r['structuredContent']);
    return (r['structuredContent'] as Map).cast<String, dynamic>();
  }

  Future<void> loadTools() async {
    toolDefs = ((await request('tools/list'))['result']['tools'] as List).cast<Map<String, dynamic>>();
  }

  const writing = ['create_project', 'copy_example', 'import_files', 'set_project', 'edit_entities', 'add_catalog_pack', 'design_project', 'export_drawing', 'export_report'];
  const reading = [
    'list_files',
    'read_project',
    'list_entities',
    'list_catalog',
    'analyze_project',
    'check_project',
    'validate_project',
    'bill_of_materials',
    'report_table',
    'project_schema',
    'list_examples',
    'list_catalog_packs',
  ];

  test('every tool has a valid name, a description, valid schemas and every hint', () async {
    await loadTools();
    expect([for (final t in toolDefs) t['name']], [...reading, ...writing]);
    for (final t in toolDefs) {
      final name = t['name'] as String;
      expect(RegExp(r'^[a-z_]{1,128}$').hasMatch(name), isTrue, reason: name);
      expect((t['description'] as String).length, greaterThan(80), reason: name);
      expect(t['title'], isNotEmpty);
      final input = t['inputSchema'] as Map<String, dynamic>;
      expect(input['type'], 'object', reason: name);
      expect(input['additionalProperties'], isFalse, reason: '$name: unknown arguments are refused');
      expect(schemaProblems(input, at: '$name.inputSchema'), isEmpty);
      expect(schemaProblems(t['outputSchema'], at: '$name.outputSchema'), isEmpty);
      for (final p in (input['properties'] as Map).values) {
        expect((p as Map)['description'], isNotNull, reason: '$name: every argument is described');
      }
      final hints = t['annotations'] as Map<String, dynamic>;
      expect(hints['readOnlyHint'], reading.contains(name), reason: name);
      expect(hints['openWorldHint'], isFalse, reason: '$name: nothing goes online');
      if (!reading.contains(name)) expect(hints.keys, containsAll(['destructiveHint', 'idempotentHint']));
    }
  });

  test('docs/MCP.md and its translation describe every tool, the revisions and the limits', () async {
    await loadTools();
    for (final doc in ['docs/MCP.md', 'docs/MCP.pt-BR.md']) {
      final text = File(doc).readAsStringSync();
      final headings = {for (final m in RegExp(r'^### (\w+)$', multiLine: true).allMatches(text)) m.group(1)!};
      expect(headings, {for (final t in toolDefs) t['name']}, reason: '$doc: a section per tool, and no other');
      for (final v in mcpSupportedVersions) {
        expect(text, contains(v), reason: '$doc names the revision $v');
      }
      expect(text, contains('256 MB'));
      expect(text, contains('15 min'));
    }
    final help = StringBuffer();
    await runOci(['--help'], out: help, home: home);
    expect('$help', allOf(contains('  mcp '), contains('--root <folder>'), contains('--read-only'), contains('docs/MCP.md')));
  });

  test('a whole session: an example copied, designed, checked, its bill of materials, tables, a DXF and a PDF', () async {
    await loadTools();
    final listed = await call('list_examples', {});
    expect([for (final e in listed['examples'] as List) e['id']], contains('garden'));
    final copy = await call('copy_example', {'example': 'garden', 'out': 'jobs/garden.oci.json'});
    expect(copy['project'], 'jobs/garden.oci.json');
    expect(copy['name'], 'Residential garden');
    expect((copy['zones'] as List).length, 3);
    expect(File('${tmp.path}/jobs/garden.oci.json').existsSync(), isTrue);
    // the copy is a project of its own
    final original = Project.fromJsonString(File('$home/examples/en/garden.oci.json').readAsStringSync());
    final copied = Project.fromJsonString(File('${tmp.path}/jobs/garden.oci.json').readAsStringSync());
    expect(copied.meta.uid, isNot(original.meta.uid));
    expect(copied.entities.length, original.entities.length);
    // not over itself
    expect((await call('copy_example', {'example': 'garden', 'out': 'jobs/garden.oci.json'}, error: true))['error'], contains('exists already'));

    final files = await call('list_files', {});
    expect(files['files'], [
      {'path': 'jobs/garden.oci.json', 'kind': 'project', 'bytes': File('${tmp.path}/jobs/garden.oci.json').lengthSync()},
    ]);
    final read = await call('read_project', {'project': 'jobs/garden.oci.json', 'parameters': true});
    expect((read['entities'] as Map)['byType'], containsPair('outlet', 24));
    expect((read['parameters'] as Map)['vZone'], isA<num>());

    final designed = await call('design_project', {'project': 'jobs/garden.oci.json'});
    expect(designed['sized'], isTrue);
    expect(designed['saved'], 'jobs/garden.oci.json');
    final zones = (designed['tables'] as Map)['zones'] as Map;
    expect(zones['rows'], hasLength(3));
    expect((zones['headers'] as List)[1], contains('(L/h)'), reason: 'the units of the project in the headers');
    // the same numbers as the engine called directly
    final direct = Designer(Project.fromJsonString(File('$home/examples/en/garden.oci.json').readAsStringSync())).designAll();
    expect((designed['totals'] as Map)['capitalCost'], closeTo(direct.capitalCost, 0.01));
    final saved = jsonDecode(File('${tmp.path}/jobs/garden.oci.json').readAsStringSync()) as Map<String, dynamic>;
    expect(saved['results'], isNotNull, reason: 'saved with its results, as the app saves it');
    final pipes = Project.fromJson(saved).entities.whereType<PipeEntity>();
    expect(pipes.every((p) => p.pipeSpecId != null), isTrue);

    final check = await call('check_project', {'project': 'jobs/garden.oci.json'});
    expect(check['designed'], isTrue);
    expect(check['errors'], 0);
    expect(check['messages'], isA<List>());
    for (final m in check['messages'] as List) {
      expect((m as Map).keys, containsAll(['level', 'code', 'message']));
    }
    final terse = await call('check_project', {'project': 'jobs/garden.oci.json', 'run': 'none', 'explain': false});
    expect(terse['designed'], isFalse);
    expect([for (final m in terse['messages'] as List) ...(m as Map).keys], isNot(contains('why')));

    final bom = await call('bill_of_materials', {'project': 'jobs/garden.oci.json'});
    expect(bom['currency'], 'USD');
    expect(bom['totalRows'], greaterThan(5));
    expect(bom['headers'], isNotEmpty);
    expect((bom['rows'] as List).first, isA<List>());
    expect(bom['capitalCost'], closeTo(direct.capitalCost, 0.01));

    final tables = await call('report_table', {'project': 'jobs/garden.oci.json'});
    final keys = [for (final t in tables['tables'] as List) t['key']];
    expect(keys, containsAll(['zones', 'pipes', 'bom']));
    final pipeRows = await call('report_table', {'project': 'jobs/garden.oci.json', 'table': 'pipes', 'limit': 3});
    expect((pipeRows['rows'] as List).length, 3);
    expect(pipeRows['totalRows'], greaterThan(3));
    expect((await call('report_table', {'project': 'jobs/garden.oci.json', 'table': 'nope'}, error: true))['error'], contains('no table "nope"'));

    final dxf = await call('export_drawing', {'project': 'jobs/garden.oci.json', 'format': 'dxf'});
    expect(dxf, {'written': 'jobs/garden.dxf', 'bytes': File('${tmp.path}/jobs/garden.dxf').lengthSync(), 'format': 'dxf'});
    expect(DxfReader.parse(File('${tmp.path}/jobs/garden.dxf').readAsStringSync()).entities, isNotEmpty);
    final pdf = await call('export_drawing', {'project': 'jobs/garden.oci.json', 'format': 'pdf', 'out': 'sheets/garden-a1.pdf', 'paper': 'a1'});
    expect(pdf['written'], 'sheets/garden-a1.pdf');
    expect(String.fromCharCodes(File('${tmp.path}/sheets/garden-a1.pdf').readAsBytesSync().take(5)), '%PDF-');
    // an export does not replace a file unless told to
    expect((await call('export_drawing', {'project': 'jobs/garden.oci.json', 'format': 'dxf'}, error: true))['error'], contains('overwrite'));
    await call('export_drawing', {'project': 'jobs/garden.oci.json', 'format': 'dxfR12', 'out': 'jobs/garden.dxf', 'overwrite': true, 'calculate': 'none'});
    // a map format needs a georeference
    expect((await call('export_drawing', {'project': 'jobs/garden.oci.json', 'format': 'kml'}, error: true))['error'], contains('georeference'));
    final kml = await call('export_drawing', {
      'project': 'jobs/garden.oci.json',
      'format': 'kml',
      'georef': {'lat': -22.9, 'lon': -43.2},
    });
    expect(kml['written'], 'jobs/garden.kml');
    final xlsx = await call('export_report', {'project': 'jobs/garden.oci.json', 'format': 'xlsx'});
    expect(xlsx['written'], 'jobs/garden.report.xlsx');
    final csv = await call('export_report', {'project': 'jobs/garden.oci.json', 'format': 'csv', 'tables': 'bom'});
    expect(File('${tmp.path}/${csv['written']}').readAsStringSync(), contains(';'));
    expect((await call('export_report', {'project': 'jobs/garden.oci.json', 'format': 'pdf', 'out': 'jobs/report.xlsx'}, error: true))['error'], contains('.pdf files only'));
  });

  test('a project made from nothing: georeference, settings, items drawn, a pack, analysis and validation', () async {
    await loadTools();
    final made = await call('create_project', {
      'out': 'lawn.oci.json',
      'name': 'Lawn',
      'units': 'us',
      'currency': 'eur',
      'mains_hz': 50,
      'georef': {'lat': -15.79, 'lon': -47.88},
    });
    expect(made['name'], 'Lawn');
    expect(made['currency'], 'EUR');
    expect(made['mainsHz'], 50);
    expect((made['units'] as Map)['system'], 'us');
    expect(((made['georef'] as Map)['origin'] as Map)['lat'], closeTo(-15.79, 1e-6));
    expect((await call('create_project', {'out': 'lawn.oci.json'}, error: true))['error'], contains('exists already'));
    expect((await call('create_project', {'out': 'lawn.json'}, error: true))['error'], contains('.oci.json'));

    final set = await call('set_project', {
      'project': 'lawn.oci.json',
      'client': 'Ana',
      'units': 'metric',
      'parameters': {'vZone': 1.2, 'sizing': 'greedy', 'latSizes': 2},
    });
    expect(set['client'], 'Ana');
    final p = Project.fromJsonString(File('${tmp.path}/lawn.oci.json').readAsStringSync());
    expect(p.params.maxZoneVelocity, 1.2);
    expect(p.params.sizingMethod, SizingMethod.greedy);
    expect(p.params.maxLateralSizes, 2);
    expect(p.params.mainsHz, 50);
    final bad = (await call('set_project', {
      'project': 'lawn.oci.json',
      'parameters': {'vZone': 'fast', 'nope': 1, 'sizing': 'magic', 'latSizes': 1.5},
    }, error: true))['error'];
    expect(
      bad,
      allOf(contains('parameters.vZone: a number'), contains('parameters.nope: not a design parameter'), contains('parameters.sizing: one of lp, greedy'), contains('latSizes: a whole number')),
    );
    expect((await call('set_project', {'project': 'lawn.oci.json'}, error: true))['error'], contains('nothing to change'));

    // nothing to design yet
    expect((await call('analyze_project', {'project': 'lawn.oci.json'}, error: true))['error'], isNotEmpty);

    final catalog = await call('list_catalog', {'project': 'lawn.oci.json', 'kind': 'outlets', 'limit': 50});
    final spray = (catalog['items'] as List).cast<Map>().firstWhere((o) => o['kind'] == 'spray' || o['kind'] == 'sprinkler');
    final pipe = ((await call('list_catalog', {'project': 'lawn.oci.json', 'kind': 'pipes', 'enabled_only': true}))['items'] as List).cast<Map>().first;
    final edit = await call('edit_entities', {
      'project': 'lawn.oci.json',
      'add': [
        {
          'type': 'waterSupply',
          'p': [0, 0],
          'calc': true,
        },
        {
          'type': 'pipe',
          'pts': [
            [0, 0],
            [10, 0],
          ],
          'scope': 'mainline',
          'spec': pipe['id'],
        },
        {
          'type': 'controlValve',
          'id': 'v1',
          'p': [10, 0],
          'zone': 'Front',
        },
        {
          'type': 'pipe',
          'pts': [
            [10, 0],
            [20, 0],
          ],
          'scope': 'zone',
          'auto': true,
        },
        {
          'type': 'outlet',
          'p': [20, 0],
          'outlet': spray['id'],
        },
        {
          'type': 'text',
          'p': [5, 5],
          'text': 'to be deleted',
          'h': 1,
        },
      ],
    });
    expect(edit['added'], hasLength(6));
    expect(edit['added'], contains('v1'));
    final drawn = Project.fromJsonString(File('${tmp.path}/lawn.oci.json').readAsStringSync());
    expect(drawn.entities.length, 6);
    expect(drawn.entities.whereType<PipeEntity>().map((e) => e.layer).toSet(), {Layers.mainlinePipes, Layers.zonePipes}, reason: 'the usual layer of each type');
    final text = drawn.entities.whereType<TextEntity>().single;
    // no id collides afterwards
    expect(drawn.newId(), isNot(anyOf([for (final e in drawn.entities) e.id])));
    final changed = await call('edit_entities', {
      'project': 'lawn.oci.json',
      'update': [
        {
          'id': 'v1',
          'set': {'zone': 'Front lawn'},
        },
      ],
      'delete': [text.id],
    });
    expect(changed['updated'], ['v1']);
    expect(changed['deleted'], [text.id]);
    expect(changed['entities'], 5);
    // refused as a whole: the file stays as it was
    final before = File('${tmp.path}/lawn.oci.json').readAsStringSync();
    final refused = (await call('edit_entities', {
      'project': 'lawn.oci.json',
      'add': [
        {'type': 'teleporter'},
        {
          'type': 'pipe',
          'pts': [
            [0, 0],
          ],
        },
        {
          'type': 'outlet',
          'id': 'v1',
          'p': [1, 1],
        },
      ],
      'update': [
        {
          'id': 'v1',
          'set': {'type': 'pipe'},
        },
        {'id': 'ghost', 'set': {}},
      ],
      'delete': ['ghost'],
    }, error: true))['error'];
    expect(
      refused,
      allOf(contains('nothing was changed'), contains('unknown type teleporter'), contains('at least 2 points'), contains('id v1 is taken'), contains('cannot change'), contains('no item ghost')),
    );
    expect(File('${tmp.path}/lawn.oci.json').readAsStringSync(), before);

    final analysed = await call('analyze_project', {'project': 'lawn.oci.json', 'size_pipes': true});
    expect(((analysed['tables'] as Map)['zones'] as Map)['rows'], hasLength(1));
    expect(((analysed['tables'] as Map)['zones'] as Map)['rows'][0][0], 'Front lawn');
    expect(File('${tmp.path}/lawn.oci.json').readAsStringSync(), before, reason: 'analyze writes nothing');

    final packs = await call('list_catalog_packs', {'search': 'netafim'});
    expect([for (final p in packs['packs'] as List) p['id']], ['netafim']);
    final pipesBefore = drawn.catalog.pipes.length + drawn.catalog.tapes.length + drawn.catalog.outlets.length;
    final added = await call('add_catalog_pack', {
      'project': 'lawn.oci.json',
      'packs': ['netafim'],
      'out': 'lawn-netafim.oci.json',
    });
    expect(added['project'], 'lawn-netafim.oci.json');
    expect((added['log'] as List).first, contains('items added'));
    final c = added['catalog'] as Map;
    expect((c['pipes'] as int) + (c['tapes'] as int) + (c['outlets'] as int), greaterThan(pipesBefore));
    expect(
      (await call('add_catalog_pack', {
        'project': 'lawn.oci.json',
        'packs': ['no-such-pack'],
      }, error: true))['error'],
      contains('no-such-pack'),
    );

    final valid = await call('validate_project', {'project': 'lawn.oci.json'});
    expect(valid['repairs'], isEmpty);
    expect(valid['name'], 'Lawn');

    final schema = await call('project_schema', {'part': 'entity.pipe'});
    expect((schema['schema'] as Map)['title'], 'pipe');
    final overview = await call('project_schema', {});
    expect((overview['schema'] as Map)['parts'], contains('params'));
    expect(((await call('project_schema', {'part': 'params'}))['schema'] as Map)['properties'], contains('vZone'));

    final entities = await call('list_entities', {
      'project': 'lawn.oci.json',
      'types': ['pipe'],
    });
    expect(entities['total'], 2);
    expect(entities['columns'], ['id', 'type', 'name', 'layer', 'spec', 'x', 'y', 'length_m', 'area_m2', 'zone']);
    expect([for (final r in entities['rows'] as List) r[7]], [10.0, 10.0]);
    final full = await call('list_entities', {
      'project': 'lawn.oci.json',
      'ids': ['v1'],
      'full': true,
    });
    expect((full['entities'] as List).single['zone'], 'Front lawn');
  });

  test('a deleted valve leaves the system flows it ran in', () async {
    await loadTools();
    await call('copy_example', {'example': 'garden', 'out': 'g.oci.json'});
    await call('edit_entities', {
      'project': 'g.oci.json',
      'delete': ['e39'],
      'out': 'g2.oci.json',
    });
    final read = await call('read_project', {'project': 'g2.oci.json'});
    expect(
      [for (final f in read['systemFlows'] as List) f['runs']],
      [
        <String>[],
        ['e55'],
        ['e58'],
      ],
    );
    expect((await call('read_project', {'project': 'g.oci.json'}))['zones'], hasLength(3), reason: 'out leaves the project as it was');
  });

  test('import makes a project of drawings and adds others to it', () async {
    await loadTools();
    // a drawing of the garden, exported and read back
    await call('copy_example', {'example': 'garden', 'out': 'g.oci.json'});
    await call('export_drawing', {'project': 'g.oci.json', 'format': 'dxf', 'out': 'survey/site.dxf', 'calculate': 'none'});
    final imported = await call('import_files', {
      'files': ['survey/site.dxf'],
      'currency': 'BRL',
    });
    expect(imported['project'], 'survey/site.oci.json');
    expect(imported['name'], 'site');
    expect(imported['currency'], 'BRL');
    expect((imported['log'] as List).first, contains('survey/site.dxf: dxf'));
    expect((imported['entities'] as Map)['total'], greaterThan(10));
    final again = await call('import_files', {
      'files': ['survey/site.dxf'],
      'into': 'survey/site.oci.json',
    });
    expect((again['entities'] as Map)['total'], greaterThan((imported['entities'] as Map)['total'] as int));
    expect(
      (await call('import_files', {
        'files': ['survey/site.dxf'],
        'into': 'survey/site.oci.json',
        'currency': 'USD',
      }, error: true))['error'],
      contains('set_project'),
    );
    expect(
      (await call('import_files', {
        'files': ['g.oci.json'],
        'out': 'x.oci.json',
      }, error: true))['error'],
      isNotEmpty,
    );
  });

  test('a read-only server has no tool that writes and refuses them as unknown', () async {
    await server.close();
    server = make(readOnly: true);
    await loadTools();
    expect([for (final t in toolDefs) t['name']], reading);
    final m = await request('tools/call', {
      'name': 'create_project',
      'arguments': {'out': 'x.oci.json'},
    });
    expect(m['error'], {'code': -32602, 'message': 'Unknown tool: create_project'});
    expect(Directory(tmp.path).listSync(), isEmpty);
    final init = await request('server/discover');
    expect(init['result']['instructions'], contains('read-only'));
  });

  test('paths stay inside the root: traversal, absolute paths and links out of it are refused', () async {
    await loadTools();
    final outside = Directory.systemTemp.createTempSync('oci_mcp_out_');
    try {
      File('${outside.path}/secret.oci.json').writeAsStringSync(File('$home/examples/en/garden.oci.json').readAsStringSync());
      for (final path in ['../secret.oci.json', 'a/../../secret.oci.json', '${outside.path}/secret.oci.json', '~/secret.oci.json']) {
        expect((await call('read_project', {'project': path}, error: true))['error'], anyOf(contains('".."'), contains('outside the root'), contains('"~"')), reason: path);
      }
      Link('${tmp.path}/link.oci.json').createSync('${outside.path}/secret.oci.json');
      Link('${tmp.path}/out').createSync(outside.path);
      expect((await call('read_project', {'project': 'link.oci.json'}, error: true))['error'], contains('outside the root'));
      expect((await call('copy_example', {'example': 'garden', 'out': 'out/new.oci.json'}, error: true))['error'], contains('outside the root'));
      expect(File('${outside.path}/new.oci.json').existsSync(), isFalse);
      expect((await call('export_drawing', {'project': 'link.oci.json', 'format': 'dxf'}, error: true))['error'], contains('outside the root'));
      // the listing leaves the links out
      expect((await call('list_files', {}))['files'], isEmpty);
      // an absolute path inside the root is fine
      await call('copy_example', {'example': 'garden', 'out': '${tmp.path}/inside.oci.json'});
      expect((await call('read_project', {'project': 'inside.oci.json'}))['name'], 'Residential garden');
      // a project that is not one
      File('${tmp.path}/notes.txt').writeAsStringSync('hello');
      expect((await call('read_project', {'project': 'notes.txt'}, error: true))['error'], contains('notes.txt'));
      expect((await call('read_project', {'project': 'missing.oci.json'}, error: true))['error'], contains('no such project'));
    } finally {
      outside.deleteSync(recursive: true);
    }
  });
}
