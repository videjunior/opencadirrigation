import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart' show AgentHost;
import 'package:opencadirrigation/app/ai/agent_tools_design.dart' show designTools;
import 'package:opencadirrigation/app/ai/agent_tools_edit.dart';
import 'package:opencadirrigation/app/ai/agent_tools_manual.dart';
import 'package:opencadirrigation/app/ai/ai_prompt.dart';
import 'package:opencadirrigation/app/ai/manual_entities.dart';
import 'package:opencadirrigation/app/ai/manual_example.dart';
import 'package:opencadirrigation/app/ai/manual_reference.dart';
import 'package:opencadirrigation/app/ai/manual_text.dart';
import 'package:opencadirrigation/app/ai/manual_tools.dart';
import 'package:opencadirrigation/app/ai/playbooks.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A host the agent tools can be built with (nothing in these tests calls
/// it).
class _Host implements AgentHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The manual and the system prompt of the AI assistant stay in step with
/// the program: every item type and key, design parameter, message code,
/// report table and tool is there, the defaults written by hand are the
/// ones the model assumes, the tool names the prose mentions exist, the
/// example calls fit the tools' schemas, and the worked example still
/// gives what it says when replayed on a new project.
void main() {
  late ProjectController c;
  late AgentToolbox box;
  final en = I18n('en');
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    box = AgentToolbox(c, host: _Host());
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

  // every topic, and every item of the topics that have items
  List<(String, String?)> everyRead() => [
    for (final t in manualTopics) (t.id, null),
    for (final type in EntityType.values) ('entities', type.name),
    for (final p in designParameters) ('parameters', p.name),
    for (final code in adviceCodes) ('messages', code),
    for (final t in box.tools) ('tools', t.name),
    for (final o in box.operations) ('operations', o.name),
  ];

  testWidgets('every topic and item reads, within the size a tool result keeps, on an empty and on a designed project', (tester) async {
    for (final designed in [false, true]) {
      if (designed) {
        loadExampleAction(c, ExampleId.orchard);
        await tester.runAsync(() => c.runDesign());
        expect(c.results, isNotNull);
      }
      for (final (topic, item) in everyRead()) {
        final out = await run(tester, 'read_manual', {'topic': topic, 'item': ?item});
        expect(out.isError, isFalse, reason: '$topic $item');
        expect(out.text.length, inInclusiveRange(50, 15000), reason: '$topic ${item ?? ''} is ${out.text.length} characters');
      }
    }
    expect(() => manualText(box, 'nope'), throwsA(isA<ToolInputError>()));
    expect(() => manualText(box, 'design', 'x'), throwsA(isA<ToolInputError>()));
    expect(() => manualText(box, 'entities', 'nope'), throwsA(isA<ToolInputError>()));
    expect(manualText(box, 'entities', 'pipe, controlValve'), allOf(contains('## pipe'), contains('## controlValve')));
  });

  testWidgets('the system prompt indexes every topic and playbook, names the steering prefix and stays small', (tester) async {
    final prompt = aiSystemPrompt(c, instructions: 'Prices without taxes.');
    for (final t in manualTopics) {
      expect(prompt, contains('- ${t.id}: '), reason: t.id);
    }
    for (final p in playbooks) {
      expect(prompt, contains('- ${p.id}: ${p.when}'), reason: p.id);
    }
    expect(prompt, contains('[Message from the user, written while you were working]'));
    expect(prompt, contains('<user_instructions>\nPrices without taxes.\n</user_instructions>'));
    expect(prompt, contains('English (en)'));
    expect(aiSystemPrompt(c), isNot(contains('user_instructions')));
    // about 4 characters a token
    debugPrint('system prompt: ${prompt.length} characters, about ${prompt.length ~/ 4} tokens');
    expect(prompt.length, lessThan(24000));
    final read = tool('read_manual');
    expect(read.effect, ToolEffect.read);
    expect(read.describe({'topic': 'entities', 'item': 'pipe'}), 'Read the manual (entities · pipe)');
  });

  testWidgets('every item type and key has its meaning; the defaults written by hand are those of Entity.fromJson', (tester) async {
    for (final type in EntityType.values) {
      final name = type.name;
      expect(entityDocs.containsKey(name), isTrue, reason: 'no manual entry for the entity type $name');
      expect(entitySamples.containsKey(name), isTrue, reason: 'no sample of $name');
      final doc = entityDocs[name]!;
      final json = sampleEntity(name).toJson();
      // every key the project file writes is explained
      for (final k in json.keys) {
        if (const {'type', 'id', 'layer', 'name'}.contains(k)) continue;
        expect(doc.fields.containsKey(k), isTrue, reason: '$name.$k has no meaning in manual_entities.dart');
      }
      // every key create_entities takes is explained; the required ones are in the sample
      final keys = entityKeys[name];
      if (keys != null) {
        for (final k in keys) {
          expect(doc.fields.containsKey(k), isTrue, reason: '$name.$k (create_entities) has no meaning in manual_entities.dart');
        }
        for (final k in entityRequired[name] ?? const <String>[]) {
          expect(keys, contains(k), reason: '$name requires $k');
          expect(entitySamples[name]!.containsKey(k), isTrue, reason: 'the sample of $name lacks the required $k');
        }
        // the legend of create_entities lists every key
        final m = RegExp('\\b$name \\{([^}]*)\\}').firstMatch(entityLegend);
        expect(m, isNotNull, reason: 'the entity legend has no line for $name');
        final listed = RegExp(r'[A-Za-z]+').allMatches(m!.group(1)!).map((x) => x.group(0)).toSet();
        for (final k in keys) {
          expect(listed, contains(k), reason: 'the entity legend does not list $name.$k');
        }
      }
      for (final e in doc.fields.entries) {
        final f = e.value;
        if (f.panel != null) expect(en.has(f.panel!), isTrue, reason: '$name.${e.key}: no string ${f.panel}');
        // writing the default changes nothing
        if (f.def != null) {
          expect(sampleEntity(name, {e.key: f.def}).toJson(), json, reason: '$name.${e.key}: the default ${f.def} is not the one Entity.fromJson assumes');
        }
        // the values of a closed list are accepted as they are
        for (final v in f.values ?? const <String>[]) {
          if (keys == null || !keys.contains(e.key)) continue;
          final round = sampleEntity(name, {e.key: v}).toJson()[e.key];
          expect(round == null || round == v, isTrue, reason: '$name.${e.key} = "$v" did not round-trip ($round)');
        }
      }
      expect(() => fieldDefault(name, typeKeys(name).first), returnsNormally);
    }
  });

  testWidgets('every design parameter of the project file is in the manual, with the key it really has', (tester) async {
    final keys = DesignParameters(mainsHz: 50).toJson().keys.toSet();
    final known = {for (final p in designParameters) p.jsonKey, ...otherParameterKeys.keys};
    expect(keys.difference(known), isEmpty, reason: 'parameters missing from designParameters / otherParameterKeys');
    expect(known.difference(keys), isEmpty, reason: 'keys that are not in DesignParameters.toJson');
    final text = manualText(box, 'parameters');
    for (final x in designParameters) {
      expect(text, contains('- ${x.name} (${x.jsonKey}) = '), reason: x.name);
      // the key is the one this parameter writes: another value shows there
      final p = DesignParameters();
      final before = p.toJson()[x.jsonKey];
      final Object other = x.options != null
          ? x.options!.firstWhere((o) => o != x.get(p))
          : x.isBool
          ? !(x.get(p) as bool)
          : (x.get(p) == x.max! ? x.min! : x.max!);
      x.set(p, other);
      expect(p.toJson()[x.jsonKey], isNot(before), reason: '${x.name} does not write "${x.jsonKey}"');
      expect(x.get(DesignParameters()), isNotNull);
    }
  });

  testWidgets('every message code the engine raises has its explanation, title and severity in the manual', (tester) async {
    // codes written in the files that report to the advisor; the few other
    // snake_case strings there are listed
    const notCodes = {'depth_mm', 'end_deg', 'start_deg', 'target_mm', 'timer_pct'};
    const files = ['designer', 'design_check', 'advisor', 'network_builder', 'pivot', 'mechanised', 'pivot_package', 'corner_arm', 'vri', 'pivot_electrical', 'electrical', 'valve_in_head'];
    final raw = <String>{};
    for (final f in files) {
      final src = File('lib/core/design/$f.dart').readAsStringSync();
      raw.addAll(RegExp(r"'([a-z]+(?:_[a-z0-9]+)+)(?=[:'])").allMatches(src).map((m) => m.group(1)!));
    }
    expect(raw.length, greaterThan(80));
    for (final r in raw.difference(notCodes)) {
      expect(adviceCodes, contains(adviceCode(r)), reason: 'message "$r" has no explanation code (adviceCodes / adviceCode in advisor.dart), so the manual lacks it');
    }
    final levels = adviceLevels();
    final text = manualText(box, 'messages');
    for (final code in adviceCodes) {
      expect(en.has('adv.$code.why') && en.has('adv.$code.how'), isTrue, reason: code);
      expect(levels[code], isNotNull, reason: 'no severity for $code');
      expect(text, contains('- $code (${levels[code]!.name}): '), reason: code);
      expect(adviceTitleEn(code).length, greaterThan(5), reason: code);
    }
    for (final f in FixKind.values) {
      expect(text, contains('- ${f.name}'), reason: f.name);
    }
    expect(manualText(box, 'messages', 'no_water_supply'), contains('## no_supply (error)'), reason: 'raw codes find their explanation');
  });

  testWidgets('the report tables, the tools and the example calls are in the manual and fit the tools', (tester) async {
    final src = File('lib/core/design/report_tables.dart').readAsStringSync();
    final keys = RegExp(r"key: '([a-zA-Z]+)'").allMatches(src).map((m) => m.group(1)!).toSet();
    expect(reportTableKeys.toSet(), keys, reason: 'reportTableKeys (agent_tools.dart) and buildReportTables differ');
    expect(reportTableNotes.keys.toSet(), keys);
    final tools = {for (final t in box.tools) t.name: t};
    final text = manualText(box, 'tools');
    for (final t in box.tools) {
      expect(text, contains('- ${t.name} ['), reason: t.name);
      expect(manualText(box, 'tools', t.name), contains(t.description), reason: t.name);
    }
    for (final e in toolExamples.entries) {
      final t = tools[e.key];
      expect(t, isNotNull, reason: 'example of the unknown tool ${e.key}');
      for (final x in e.value) {
        expect(schemaProblem(t!.inputSchema, x.input), isNull, reason: '${e.key} ${x.input}');
      }
    }
    for (final s in workedExample) {
      expect(tools[s.tool], isNotNull, reason: s.tool);
      expect(schemaProblem(tools[s.tool]!.inputSchema, s.input), isNull, reason: '${s.tool} ${s.input}');
    }
  });

  testWidgets('the tool names the prompt and the written topics mention exist', (tester) async {
    final tools = {for (final t in box.tools) t.name};
    final known = <String>{...tools, ...adviceCodes, for (final p in playbooks) p.id, for (final t in manualTopics) t.id};
    void collect(Object? schema) {
      if (schema is Map) {
        final props = schema['properties'];
        if (props is Map) {
          known.addAll(props.keys.cast<String>());
          props.values.forEach(collect);
        }
        final options = schema['enum'];
        if (options is List) known.addAll(options.whereType<String>());
        collect(schema['items']);
      }
    }

    for (final t in [...box.tools, ...box.operations]) {
      collect(t.inputSchema);
      known.add(t.name);
    }
    final prefixes = {for (final t in tools) t.split('_').first};
    final texts = {
      'prompt': aiSystemPrompt(c),
      'drawing': drawingTopic(box),
      'design': designTopic(box),
      'flows': flowsTopic(box),
      'verification': verificationTopic(box),
      'terrain': terrainTopic(box),
      'machines': machinesTopic(box),
      'electrical': electricalTopic(box),
      'mistakes': mistakesTopic(box),
      'example': manualText(box, 'example'),
      'legend': entityLegend,
      // the descriptions of the tools of agent_tools*.dart and the manual
      for (final t in [...readTools(box), ...editTools(box), ...designTools(box), ...manualTools(box)]) 'tool ${t.name}': t.description,
    };
    for (final e in texts.entries) {
      for (final m in RegExp(r'\b[a-z]+(?:_[a-z0-9]+)+\b').allMatches(e.value)) {
        final w = m.group(0)!;
        if (!prefixes.contains(w.split('_').first)) continue;
        expect(known, contains(w), reason: '${e.key} mentions "$w", which is no tool, input or code');
      }
    }
    // the parameters the prose names exist
    final params = {for (final p in designParameters) p.name};
    for (final e in texts.entries) {
      for (final m in RegExp(
        r'\b(max[A-Z]\w+|min[A-Z]\w+|connectTolerance|tradeCapitalVsRunning|sizingMethod|terrainMethod|terrainDensify|valveClosureTimeS|powerCostPerKwh|hoursPerYear|zoneHoursPerYear|interestRate|termYears|pumpEfficiency|flushing[A-Z]\w+|solenoid[A-Z]\w+|wireSlackPct|checkSurge|selectFittings|pipeStickLengthM)\b',
      ).allMatches(e.value)) {
        expect(params, contains(m.group(0)), reason: '${e.key} names the parameter ${m.group(0)}');
      }
    }
  });

  testWidgets('the worked example gives what it says when replayed on a new project', (tester) async {
    for (var k = 0; k < workedExample.length; k++) {
      final s = workedExample[k];
      final out = await run(tester, s.tool, Map<String, dynamic>.from(s.input));
      expect(out.isError, isFalse, reason: 'step ${k + 1} ${s.tool}: ${out.text}');
      for (final x in s.shows) {
        expect(showPattern(x).hasMatch(out.text), isTrue, reason: 'step ${k + 1} ${s.tool} no longer shows "$x":\n${out.text}');
      }
    }
    expect(c.results, isNotNull);
    expect(c.advice.where((a) => a.level == AdviceLevel.error), isEmpty, reason: 'the example ends without errors');
  });

  testWidgets('generate_block follows a guide line and picks the valve by flow; set_system_flows says when no flow limit is known; route_wires reports the stations', (tester) async {
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'area',
          'name': 'Band',
          'pts': [
            [0, 0],
            [60, 0],
            [60, 20],
            [0, 20],
          ],
        },
        {
          'type': 'polyline',
          'name': 'Guide',
          'pts': [
            [-5, 0],
            [30, 4],
            [65, 0],
          ],
        },
      ],
    });
    final out = await run(tester, 'generate_block', {'area': 'Band', 'lateral': 'tape', 'lateral_spacing_m': 2, 'tape': 'drip16_16_50', 'guide': 'Guide', 'zone_name': 'Band zone'});
    final tapes = c.project.entities.whereType<TapeEntity>().toList();
    expect(tapes.length, greaterThan(5));
    expect(tapes.any((x) => x.points.length > 2), isTrue, reason: 'laterals follow the bend of the guide');
    final valve = c.project.entities.whereType<ControlValveEntity>().single;
    final spec = c.project.catalog.valve(valve.valveSpecId)!;
    expect(out.text, contains('Zone "Band zone"'));
    final flow = RegExp(r'nominal block flow ([\d.]+) m³/h').firstMatch(out.text);
    expect(flow, isNotNull);
    final q = double.parse(flow!.group(1)!) / 3600;
    expect(q, inInclusiveRange(spec.minFlow, spec.maxFlow), reason: 'the valve range holds the block flow');
    final bad = await tester.runAsync(() => tool('generate_block').run({'area': 'Band', 'lateral': 'tape', 'lateral_spacing_m': 2, 'guide': 'Band'}).then((_) => '', onError: (Object e) => '$e'));
    expect(bad, contains('not a line'));
    // two more zones and a supply without a design flow
    loadExampleAction(c, ExampleId.orchard);
    for (final s in c.project.entities.whereType<WaterSupplyEntity>()) {
      s.designFlow = 0;
    }
    final flows = await run(tester, 'set_system_flows', {'mode': 'auto'});
    expect(flows.text, contains('No flow limit was known'));
    final limited = await run(tester, 'set_system_flows', {'mode': 'auto', 'max_flow_m3h': 0.5});
    expect(limited.text, contains('Flow limit'));
    // wiring
    final valves = c.project.entities.whereType<ControlValveEntity>().toList();
    c.project.entities.removeWhere((e) => e is ControllerEntity || e is WireEntity);
    await run(tester, 'create_entities', {
      'entities': [
        {
          'type': 'controller',
          'p': [valves.first.position.x, valves.first.position.y],
          'st': 1,
        },
      ],
    });
    final wires = await run(tester, 'route_wires', {});
    expect(wires.text, contains('stations used of 1'));
    expect(wires.text, contains('more than it has'), reason: '${valves.length} valves on a 1-station controller');
    expect(wires.text, contains('station 1'));
  });
}
