/// The reference manual of the AI assistant, read on demand with
/// read_manual so the system prompt stays small: the exact connection
/// rules, every item property, design parameter, message code, tool and
/// operation, the values the engine uses, units, terrain, agronomy,
/// machines, wiring, reports, the playbooks, common mistakes and a worked
/// example.
///
/// The tables are generated from the program when a topic is read (entity
/// formats and defaults, the parameter table, the advisor codes and their
/// explanations, the catalogue, the tools and operations, the defaults of
/// the engine), so they follow it; the prose is written in manual_text.dart
/// and checked by test/widget_ai_manual_test.dart, which also replays the
/// worked example.
library;

import '../../core/ai/agent_loop.dart';
import 'agent_tools.dart';
import 'manual_entities.dart';
import 'manual_example.dart';
import 'manual_reference.dart';
import 'manual_text.dart';
import 'manual_tools.dart';

/// One topic of the manual.
class ManualTopic {
  const ManualTopic(this.id, this.summary, this.render, {this.items = ''});
  final String id;

  /// What it holds, one line, for the index in the system prompt.
  final String summary;

  /// The text of the topic, narrowed to an item where [items] says it can.
  final String Function(AgentToolbox b, String? item) render;

  /// What an item of this topic is ('' = the topic has no items).
  final String items;
}

/// Every topic, in the order of the index in the system prompt.
final manualTopics = <ManualTopic>[
  ManualTopic('drawing', 'coordinates, angles, layers, the two scopes and the exact rules of what joins what', (b, _) => drawingTopic(b)),
  ManualTopic('entities', 'every item type with every key: unit, default, values, panel label', entitiesTopic, items: 'a type, e.g. "pipe" or "tape, outlet"'),
  ManualTopic('parameters', 'every design parameter: project-file key, default, unit, range, effect', parametersTopic, items: 'a parameter name'),
  ManualTopic('catalog', 'how the catalogue works (ids, usages, nozzles, packs) and this project\'s items', catalogTopic),
  ManualTopic('design', 'what run_design does: sizing, zone pressure windows, the mainline per system flow, supply pressure, results and costs', (b, _) => designTopic(b)),
  ManualTopic('flows', 'system flows (shifts): grouping, the auto limit, durations, valve-in-head stations', (b, _) => flowsTopic(b)),
  ManualTopic('messages', 'every design-check and assistant message: severity, title, why, how, the corrections', messagesTopic, items: 'a message code'),
  ManualTopic('verification', 'how to check a design and when it is finished', (b, _) => verificationTopic(b)),
  ManualTopic(
    'values',
    'the values the engine uses: velocity limits, pressure windows, emitter and valve ranges, spacing rules, automation and economic defaults, uniformity classes',
    (b, _) => valuesTopic(b),
  ),
  ManualTopic('units', 'SI in the tools, display units in the reports, the conversions', (b, _) => unitsTopic(b)),
  ManualTopic('terrain', 'terrain model, elevations, georeference, base maps, elevation and climate downloads', (b, _) => terrainTopic(b)),
  ManualTopic('agronomy', 'areas, FAO-56 crops and their Kc, soils, water requirement, rain, hydrozones', (b, _) => agronomyTopic(b)),
  ManualTopic('machines', 'centre pivots and linear moves: flow, pressure, application rate, workflow', (b, _) => machinesTopic(b)),
  ManualTopic('electrical', 'controllers, wire routes, stations, voltage at the solenoids', (b, _) => electricalTopic(b)),
  ManualTopic('reports', 'every report table and export format', (b, _) => reportsTopic(b)),
  ManualTopic('tools', 'every tool with its purpose; with an item, its inputs and example calls', toolsTopic, items: 'a tool name'),
  ManualTopic('operations', 'the other functions of the program, reached with run_operation', operationsTopic, items: 'an operation name'),
  ManualTopic('playbooks', 'the design playbooks and the examples they come from', (b, _) => playbooksTopic(b)),
  ManualTopic(
    'interface',
    'the menus the user works with: the tutorial, walking the field with the device\'s GPS and the other functions only the user runs, with their menu paths; the interface language',
    (b, _) => interfaceTopic(b),
  ),
  ManualTopic('mistakes', 'common mistakes and the messages that reveal them', (b, _) => mistakesTopic(b)),
  ManualTopic('example', 'a small project designed end to end: the calls and what they return', (b, _) => exampleTopic(b)),
];

/// The topic [id] (case forgiven), or null.
ManualTopic? manualTopic(String id) {
  final k = id.trim().toLowerCase();
  for (final t in manualTopics) {
    if (t.id == k) return t;
  }
  return null;
}

/// The text of [topic], narrowed to [item] where the topic has items.
String manualText(AgentToolbox b, String topic, [String? item]) {
  final t = manualTopic(topic);
  if (t == null) throw ToolInputError('No topic "$topic". Topics: ${manualTopics.map((x) => x.id).join(', ')}.');
  final it = item?.trim();
  if (it != null && it.isNotEmpty && t.items.isEmpty) throw ToolInputError('Topic "${t.id}" has no items; read it without one.');
  return t.render(b, it == null || it.isEmpty ? null : it);
}

List<AgentTool> manualTools(AgentToolbox b) => [
  FnTool(
    name: 'read_manual',
    description:
        'Reads a topic of the program\'s reference manual: the exact rules, every item key, design parameter, message, tool and operation, the values the engine uses, and a worked example. Its tables are generated from the program itself, so they are current; read the topic before relying on a detail you are not sure of. Topics: ${[for (final t in manualTopics) t.id].join(', ')} (the system prompt says what each holds). ${[for (final t in manualTopics)
          if (t.items.isNotEmpty) t.id].join(', ')} narrow to an item; without one they give an index. Read-only.',
    inputSchema: obj(
      {
        'topic': str(null, [for (final t in manualTopics) t.id]),
        'item': str(
          'For ${[for (final t in manualTopics)
            if (t.items.isNotEmpty) '${t.id}: ${t.items}'].join('; ')}.',
        ),
      },
      required: ['topic'],
    ),
    summary: (i) => b.t('ai.tool.manual', {'n': '${i['topic']}${i['item'] == null ? '' : ' · ${i['item']}'}'}),
    handler: (i) async {
      final a = ToolArgs(i);
      return ToolOutput(manualText(b, a.str('topic', required: true)!, a.str('item')));
    },
  ),
];
