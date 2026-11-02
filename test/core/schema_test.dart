import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/schema.dart';

import '../../bin/oci.dart';

/// The JSON Schema of the project file (MOD-23), built from the model.
void main() {
  final schema = projectJsonSchema();

  test('every entity type has its shape; every key a shipped example writes is in it', () {
    final kinds = ((schema['properties'] as Map)['entities'] as Map)['items']['oneOf'] as List;
    expect([for (final k in kinds) k['title']], [for (final t in EntityType.values) t.name]);
    final byType = {for (final k in kinds) k['title'] as String: (k['properties'] as Map).keys.toSet()};
    for (final f in Directory('examples/en').listSync().whereType<File>().where((f) => f.path.endsWith('.oci.json'))) {
      final p = Project.fromJsonString(f.readAsStringSync());
      for (final e in p.entities) {
        final keys = e.toJson().keys.toSet();
        // keys written only when set (a fixed elevation, a photo…) may be
        // absent from the sample of a new entity
        final missing = keys.difference(byType[e.type.name]!).where((k) => !_optional.contains(k));
        expect(missing, isEmpty, reason: '${f.path} ${e.type.name}');
      }
    }
  });

  test('defaults are those of a new project, units are documented', () {
    final params = (schema['properties'] as Map)['params']['properties'] as Map;
    final fresh = DesignParameters().toJson();
    for (final k in ['temp', 'vZone', 'kwh', 'terrain', 'densify']) {
      expect(params[k]['default'], fresh[k], reason: k);
    }
    expect(params['vZone']['description'], contains('m/s'));
    expect(params['terrain']['default'], 'tin');
    expect(schema['properties']['version']['default'], Project.formatVersion);
    // valid JSON, as the command line prints it
    expect(jsonDecode(jsonEncode(schema)), isA<Map<String, dynamic>>());
  });

  test('the command line prints it', () async {
    final out = StringBuffer(), err = StringBuffer();
    expect(
      await runOci(['schema'], out: out, err: err, home: Directory.current.path),
      OciExit.ok,
      reason: '$err',
    );
    expect((jsonDecode(out.toString()) as Map)['title'], contains('OpenCADIrrigation'));
  });
}

/// Entity keys written only when they hold something.
const _optional = {
  'name',
  'spec',
  'nozzle',
  'fixed',
  'z',
  'zs',
  'gen',
  'hm',
  'data',
  'src',
  'mir',
  'photo',
  'mach',
  'sspec',
  'rspec',
  'acc',
  'o',
  'cost',
  'tcost',
  'zone',
  'flush',
  'submin',
  'reg',
  'set',
  'setq',
  'vfd',
  'vmin',
  'wb',
  'ck',
  'pd',
  'soil',
  'erm',
  'dep',
  'pwu',
  'epp',
  'psp',
  'rsp',
  'wf',
  'eto',
  'kc',
  'awc',
  'root',
  'mad',
  'slope',
  'im',
  'gc',
  'ecw',
  'crop',
  'qg',
  'hg',
  'imax',
  'travel',
  'sector',
};
