import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/units.dart';

/// The AI assistant's tools on their own: every input is checked before the
/// project changes, catalogue items from a data sheet are validated, items
/// get their usual layers and names, and the reads answer with the
/// program's numbers.
void main() {
  late ProjectController c;
  late AgentToolbox box;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    box = AgentToolbox(c);
  });

  AgentTool tool(String name) => box.tools.firstWhere((t) => t.name == name);

  Future<ToolOutput> run(WidgetTester tester, String name, Map<String, dynamic> input) async {
    Object? error;
    ToolOutput? out;
    await tester.runAsync(() async {
      try {
        out = await tool(name).run(input);
      } catch (e) {
        error = e;
      }
    });
    if (error != null) throw error!;
    return out!;
  }

  Future<String> refused(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final before = c.historyIndex;
    final count = c.project.entities.length;
    try {
      await run(tester, name, input);
    } on ToolInputError catch (e) {
      expect(c.historyIndex, before, reason: 'a refused call leaves no undo step');
      expect(c.project.entities.length, count);
      return e.message;
    }
    fail('$name accepted $input');
  }

  testWidgets('every tool has a unique name, a description and an object schema', (tester) async {
    final names = box.tools.map((t) => t.name).toList();
    expect(names.toSet().length, names.length);
    expect(names.length, greaterThan(40));
    for (final t in box.tools) {
      expect(t.description.length, greaterThan(40), reason: t.name);
      expect(t.inputSchema['type'], 'object', reason: t.name);
      // the same definition reaches both providers, and reads back unchanged
      final a = AnthropicFormat.tool(t.spec), o = OpenAiFormat.tool(t.spec);
      expect(a['eager_input_streaming'], isTrue);
      expect(o['strict'], isFalse);
      for (final back in [AnthropicFormat.specOf(a), OpenAiFormat.specOf(o)]) {
        expect(back.name, t.name);
        expect(jsonEncode(back.inputSchema), jsonEncode(t.inputSchema), reason: t.name);
      }
    }
    for (final t in box.operations) {
      expect(t.inputSchema['type'], 'object', reason: t.name);
      expect(jsonEncode(OpenAiFormat.tool(t.spec)), isNotEmpty);
    }
    expect(tool('export_file').mustConfirm({'format': 'dxf'}), isTrue, reason: 'files are always confirmed');
    expect(
      tool('delete_entities').mustConfirm({
        'ids': [for (var i = 0; i < 30; i++) 'e$i'],
      }),
      isTrue,
      reason: 'large deletions too',
    );
    expect(
      tool('delete_entities').mustConfirm({
        'ids': ['e1'],
      }),
      isFalse,
    );
  });

  testWidgets('items are created with their layers and zone names; bad references are refused first', (tester) async {
    expect(
      await refused(tester, 'create_entities', {
        'entities': [
          {
            'type': 'outlet',
            'p': [0, 0],
            'outlet': 'nope',
          },
        ],
      }),
      contains('unknown emitter "nope"'),
    );
    expect(
      await refused(tester, 'create_entities', {
        'entities': [
          {
            'type': 'pipe',
            'pts': [
              [0, 0],
              [10, 0],
            ],
          },
        ],
      }),
      contains('"scope"'),
    );
    expect(
      await refused(tester, 'create_entities', {
        'entities': [
          {
            'type': 'area',
            'pts': [
              [0, 0],
              [1, 1],
            ],
          },
        ],
      }),
      contains('at least 3 points'),
    );
    expect(
      await refused(tester, 'create_entities', {
        'entities': [
          {
            'type': 'controlValve',
            'p': [0, 0],
            'colour': 'red',
          },
        ],
      }),
      contains('unknown properties colour'),
    );
    final out = await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'pipe',
          'scope': 'mainline',
          'pts': [
            [0, 0],
            [50, 0],
          ],
        },
        {
          'type': 'controlValve',
          'p': [50, 0],
        },
        {
          'type': 'controlValve',
          'p': [50, 10],
        },
        {
          'type': 'outlet',
          'p': [60, 0],
          'outlet': 'rotor',
          'head': 30,
        },
      ],
    });
    expect(out.isError, isFalse);
    final p = c.project;
    expect(p.entities.whereType<PipeEntity>().single.layer, Layers.mainlinePipes);
    final valves = p.entities.whereType<ControlValveEntity>().toList();
    expect(valves.map((v) => v.layer).toSet(), {Layers.controlValves});
    expect(valves.map((v) => v.zoneName).toSet().length, 2, reason: 'each new valve gets its own zone name');
    expect(p.entities.whereType<OutletEntity>().single.headM, 30);
    expect(c.historyEntries.last.label, 'hist.aiTool|create_entities');
    // update: checked, then applied in one step
    final pipe = p.entities.whereType<PipeEntity>().single;
    expect(
      await refused(tester, 'update_entities', {
        'updates': [
          {
            'id': pipe.id,
            'set': {'spec': 'nope'},
          },
        ],
      }),
      contains('unknown pipe'),
    );
    await run(tester, 'update_entities', {
      'updates': [
        {
          'id': pipe.id,
          'set': {'spec': 'pvc50', 'auto': false, 'name': 'Main'},
        },
      ],
    });
    final updated = c.project.byId(pipe.id) as PipeEntity;
    expect(updated.pipeSpecId, 'pvc50');
    expect(updated.computerSized, isFalse);
    expect(updated.name, 'Main');
    // names work as ids
    final listed = await run(tester, 'list_entities', {
      'types': ['pipe'],
    });
    expect(listed.text, contains('Main'));
    final got = await run(tester, 'get_entity', {'id': 'Main'});
    expect(got.text, contains('"spec":"pvc50"'));
    await run(tester, 'delete_entities', {
      'ids': ['Main'],
    });
    expect(c.project.entities.whereType<PipeEntity>(), isEmpty);
  });

  testWidgets('parameters and system flows are checked, then set; results are discarded', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull);
    expect(
      await refused(tester, 'set_parameters', {
        'values': {'maxZoneVelocity': 9},
      }),
      contains('0.300 … 5.000'),
    );
    expect(
      await refused(tester, 'set_parameters', {
        'values': {'speedOfLight': 1},
      }),
      contains('Unknown parameter'),
    );
    final out = await run(tester, 'set_parameters', {
      'values': {'maxZoneVelocity': 1.8, 'sizingMethod': 'greedy'},
    });
    expect(out.text, contains('maxZoneVelocity 1.5 → 1.8'));
    expect(c.project.params.maxZoneVelocity, 1.8);
    expect(c.results, isNull);
    final params = await run(tester, 'get_parameters', {});
    expect(params.text, contains('maxZoneVelocity = 1.8 m/s'));
    final flows = await run(tester, 'set_system_flows', {'mode': 'one_at_a_time', 'first_start_hour': 5});
    expect(c.project.systemFlows, hasLength(2));
    expect(c.project.systemFlows.first.startHour, 5);
    expect(flows.text, contains('Zone A'));
    expect(
      await refused(tester, 'set_system_flows', {
        'mode': 'replace',
        'flows': [
          {
            'name': 'x',
            'demands': ['Well'],
          },
        ],
      }),
      contains('not a zone valve'),
    );
  });

  testWidgets('catalogue items read from a data sheet are validated before they enter the catalogue', (tester) async {
    final n0 = c.project.catalog.outlets.length;
    expect(
      await refused(tester, 'edit_catalog', {
        'action': 'add',
        'kind': 'emitter',
        'item': {
          'name': 'X',
          'kind': 'sprinkler',
          'nozzles': [
            {'name': 'n', 'flow_lph': 900, 'head_m': 30, 'min_head_m': 40, 'max_head_m': 20},
          ],
        },
      }),
      contains('min_head_m'),
    );
    expect(
      await refused(tester, 'edit_catalog', {
        'action': 'add',
        'kind': 'pump',
        'item': {
          'name': 'P',
          'curve': [
            [0, 40],
            [10, 35],
            [5, 20],
          ],
        },
      }),
      contains('rise'),
    );
    expect(
      await refused(tester, 'edit_catalog', {
        'action': 'add',
        'kind': 'pipe',
        'item': {'name': 'P', 'inner_diameter_mm': 0.5, 'pressure_rating_m': 60},
      }),
      contains('inner_diameter_mm'),
    );
    await run(tester, 'edit_catalog', {
      'action': 'add',
      'kind': 'emitter',
      'item': {
        'name': 'Rotor R5',
        'kind': 'sprinkler',
        'cost': 12.5,
        'nozzles': [
          {'name': '2.0', 'flow_lph': 450, 'head_m': 25, 'radius_m': 9.5, 'min_head_m': 20, 'max_head_m': 45},
          {'name': '3.0', 'flow_lph': 680, 'head_m': 25, 'radius_m': 10.7},
        ],
      },
    });
    final cat = c.project.catalog;
    expect(cat.outlets.length, n0 + 1);
    final o = cat.outlets.last;
    expect(o.name, 'Rotor R5');
    expect(o.nozzles, hasLength(2));
    expect(o.nozzles.first.curve.flow(25) / m3sPerLph, closeTo(450, 0.01));
    expect(o.nozzles.first.curve.radius(25), closeTo(9.5, 0.01));
    await run(tester, 'edit_catalog', {
      'action': 'add',
      'kind': 'pump',
      'item': {
        'name': 'Pump 7.5',
        'curve': [
          [0, 52],
          [20, 47],
          [40, 36],
        ],
        'efficiency': 0.68,
        'power_kw': 5.5,
      },
    });
    expect(cat.pumps.last.name, 'Pump 7.5');
    expect(cat.pumps.last.curve.head(20 * m3sPerM3h), closeTo(47, 1.5));
    // an item used by the drawing cannot be removed
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'outlet',
          'p': [0, 0],
          'outlet': o.id,
        },
      ],
    });
    expect(await refused(tester, 'edit_catalog', {'action': 'remove', 'kind': 'emitter', 'id': o.id}), contains('used by 1 items'));
    await run(tester, 'edit_catalog', {'action': 'disable', 'kind': 'emitter', 'id': o.id});
    expect(o.enabled, isFalse);
    final search = await run(tester, 'search_catalog', {'kind': 'emitter', 'query': 'R5', 'include_disabled': true});
    expect(search.text, contains('Rotor R5'));
  });

  testWidgets('reads answer with the program’s numbers and explain what is missing', (tester) async {
    expect(await refused(tester, 'get_report_table', {'table': 'zones'}), contains('run_design'));
    loadExampleAction(c, ExampleId.orchard);
    final before = await run(tester, 'get_design_messages', {});
    expect(before.text, contains(c.t('adv.noneYet')), reason: 'no message, and no results yet to check pressures');
    await tester.runAsync(() => c.runDesign());
    final zones = await run(tester, 'get_report_table', {'table': 'zones'});
    expect(zones.text, contains('Zone A'));
    final summary = await run(tester, 'get_project_summary', {
      'parts': ['results'],
    });
    expect(summary.text, contains('Zone B'));
    final m = await run(tester, 'measure', {
      'points': [
        [0, 0],
        [30, 0],
        [30, 40],
        [0, 40],
      ],
      'closed': true,
    });
    expect(m.text, contains('Area 1200.0 m²'));
    final elev = await run(tester, 'get_elevations', {
      'points': [
        [10, 10],
      ],
    });
    expect(elev.text, contains('m'));
    final run2 = await run(tester, 'run_analysis', {'kind': 'uniformity'});
    expect(run2.text, isNotEmpty);
  });

  testWidgets('pictures of the drawing come with their metre grid; the view is left as it was', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    box = AgentToolbox(c, snapshots: const CanvasSnapshots());
    final cam = c.camera;
    final before = (cam.center, cam.scale, cam.size);
    final out = await run(tester, 'view_snapshot', {'region': 'drawing', 'base_map': true, 'size': 600});
    expect(out.images, hasLength(1), reason: 'the drawing; no base map without a georeference');
    expect(out.images.single.mediaType, 'image/png');
    expect(out.images.single.base64.length, greaterThan(1000));
    expect(out.text, contains('No base map'));
    expect(out.text, contains('m per pixel'));
    expect((cam.center, cam.scale, cam.size), before);
    expect(await refused(tester, 'create_vegetation_areas', {}), contains('aerial base map'));
  });
}
