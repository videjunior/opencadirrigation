/// The "tools" and "operations" topics of the AI assistant's manual: every
/// tool sent to the model and every operation run_operation reaches, with
/// their descriptions and inputs read from the tools themselves, and
/// curated example calls for the main ones (a test checks every example
/// against the tool's input schema, so they stay valid).
library;

import 'dart:convert';

import '../../core/ai/agent_loop.dart';
import 'agent_tools.dart';

/// An example call of a tool.
class ToolExample {
  const ToolExample(this.input, this.note);
  final Map<String, Object?> input;

  /// What the call does.
  final String note;
}

/// Example calls of the main tools (names as in the toolbox).
const toolExamples = <String, List<ToolExample>>{
  'get_project_summary': [
    ToolExample({
      'parts': ['results', 'messages'],
    }, 'the design results and the messages only'),
  ],
  'list_entities': [
    ToolExample({
      'types': ['controlValve'],
    }, 'every zone valve with its position and zone'),
    ToolExample({'zone': 'Block 1'}, 'the valve, outlets and (after a design) the pipes and laterals of one zone'),
    ToolExample({
      'types': ['pipe'],
      'scope': 'mainline',
      'bbox': [0, 0, 200, 100],
    }, 'mainline pipes inside a window'),
  ],
  'get_entity': [
    ToolExample({'id': 'Block 1'}, 'a zone valve by its zone name: report rows, keys, position'),
  ],
  'search_catalog': [
    ToolExample({'kind': 'pipe', 'usage': 'mainline'}, 'the pipes the design may use on the mainline'),
    ToolExample({'kind': 'emitter', 'query': 'rotor'}, 'rotors with every nozzle'),
    ToolExample({'kind': 'valve', 'query': 'filter'}, 'filters (devices are valves of other kinds)'),
  ],
  'get_report_table': [
    ToolExample({'table': 'zones'}, 'every zone against its pressure window'),
    ToolExample({'table': 'pipes', 'filter': 'Block 1'}, 'the pipe segments of one zone'),
  ],
  'get_elevations': [
    ToolExample({
      'points': [
        [0, 0],
        [100, 0],
        [100, 80],
      ],
    }, 'ground elevation at three points'),
  ],
  'measure': [
    ToolExample({
      'points': [
        [0, 0],
        [50, 0],
        [50, 30],
        [0, 30],
      ],
      'closed': true,
    }, 'area, perimeter and centroid of a polygon'),
  ],
  'create_entities': [
    ToolExample({
      'entities': [
        {
          'type': 'waterSupply',
          'name': 'Well',
          'p': [-40, 15],
          'calc': true,
          'wl': -4,
        },
        {
          'type': 'pipe',
          'name': 'Main',
          'scope': 'mainline',
          'pts': [
            [-40, 15],
            [-1.5, 15],
          ],
        },
        {
          'type': 'misc',
          'name': 'Filter',
          'spec': 'filter_disc50',
          'p': [-35, 15],
        },
      ],
    }, 'a well, a mainline ending where a valve stands and a filter on it (the filter splits the pipe)'),
    ToolExample({
      'entities': [
        {
          'type': 'area',
          'name': 'Tomatoes',
          'pts': [
            [0, 0],
            [50, 0],
            [50, 30],
            [0, 30],
          ],
          'crop': 'Tomato',
          'ck': 'crop.tomato',
          'im': 'localized',
          'wb': true,
          'kc': 1.15,
          'root': 0.7,
          'mad': 0.4,
          'eff': 0.9,
        },
      ],
    }, 'an irrigated area with its crop data'),
    ToolExample({
      'entities': [
        {
          'type': 'controlValve',
          'p': [20, 0],
          'spec': 'ev40',
          'zone': 'Lawn 1',
        },
        {
          'type': 'pipe',
          'scope': 'zone',
          'pts': [
            [20, 0],
            [20, 24],
          ],
        },
        {
          'type': 'outlet',
          'p': [20, 12],
          'outlet': 'rotor',
          'nozzle': 'r3',
          'head': 25,
        },
      ],
    }, 'a valve, the zone pipe starting at it and a rotor on that pipe'),
  ],
  'update_entities': [
    ToolExample({
      'updates': [
        {
          'id': 'Main',
          'set': {'spec': 'pvc75', 'auto': false},
        },
      ],
    }, 'fix a pipe\'s size'),
    ToolExample({
      'updates': [
        {
          'id': 'Main',
          'set': {'spec': null, 'auto': true},
        },
      ],
    }, 'let the design size it again'),
  ],
  'delete_entities': [
    ToolExample({
      'ids': ['Filter'],
    }, 'delete an item by name'),
  ],
  'transform_entities': [
    ToolExample({
      'ids': ['Tomatoes'],
      'operation': 'copy',
      'dx': 60,
    }, 'a copy 60 m east'),
    ToolExample({
      'ids': ['Head 1'],
      'operation': 'array',
      'rows': 3,
      'cols': 4,
      'row_spacing': 12,
      'col_spacing': 12,
    }, 'a 3 × 4 grid 12 m apart'),
  ],
  'set_parameters': [
    ToolExample({
      'values': {'maxZoneVelocity': 1.8, 'valveClosureTimeS': 3},
    }, 'two limits at once'),
  ],
  'edit_catalog': [
    ToolExample({
      'action': 'add',
      'kind': 'pipe',
      'item': {
        'name': 'PE 63 PN 6',
        'inner_diameter_mm': 55.4,
        'pressure_rating_m': 60,
        'material': 'pehd',
        'hazen_c': 145,
        'cost_per_m': 9.5,
        'usage': ['zone', 'mainline'],
      },
    }, 'a pipe from a data sheet'),
    ToolExample({
      'action': 'add',
      'kind': 'emitter',
      'item': {
        'name': 'Rotor R5',
        'kind': 'sprinkler',
        'nozzles': [
          {'name': '2.0', 'flow_lph': 450, 'head_m': 25, 'radius_m': 9.5, 'min_head_m': 20, 'max_head_m': 45},
        ],
      },
    }, 'a sprinkler with one nozzle'),
  ],
  'set_system_flows': [
    ToolExample({'mode': 'auto', 'max_flow_m3h': 30, 'first_start_hour': 6, 'duration_hours': 2}, 'pack the zones under the source\'s 30 m³/h'),
    ToolExample({
      'mode': 'replace',
      'flows': [
        {
          'name': 'Shift 1',
          'demands': ['Block 1', 'Block 2'],
          'start_hour': 6,
          'duration_hours': 3,
        },
        {
          'name': 'Shift 2',
          'demands': ['Block 3'],
          'start_hour': 9,
          'duration_hours': 3,
        },
      ],
    }, 'two shifts as the user wants them'),
  ],
  'run_design': [
    ToolExample({}, 'size and analyse everything'),
    ToolExample({'mode': 'mainline'}, 'resize the mainline only'),
  ],
  'apply_fix': [
    ToolExample({'index': 0, 'code': 'unconnected', 'fix': 'connect'}, 'the correction offered by message #0'),
  ],
  'optimize_design': [
    ToolExample({'resize_fixed_pipes': true}, 'also free the pipes sized by hand'),
  ],
  'layout_sprinklers': [
    ToolExample({'area': 'Lawn', 'outlet': 'rotor', 'pattern': 'triangular', 'zoning': true, 'routing': true}, 'heads, zones, valves, pipes and the mainline in one call'),
  ],
  'generate_block': [
    ToolExample({
      'area': 'Tomatoes',
      'lateral': 'tape',
      'lateral_spacing_m': 1.5,
      'tape': 'tape16_10_30',
      'direction_deg': 0,
      'submain': 'start',
      'zone_name': 'Block 1',
    }, 'drip tape every 1.5 m running east, the submain on the west side'),
    ToolExample({
      'area': 'Coffee 1',
      'lateral': 'tape',
      'lateral_spacing_m': 3.5,
      'tape': 'drip16pc_16_50',
      'inlet_head_m': 15,
      'guide': 'Contour 104',
      'valve': 'ev40',
    }, 'PC dripline following a contour line'),
    ToolExample({
      'area': 'Orchard',
      'lateral': 'sprayline',
      'lateral_spacing_m': 6,
      'outlet': 'micro',
      'nozzle': 'm50',
      'emitter_spacing_m': 4,
      'submain': 'centre',
    }, 'micro-sprinkler laterals fed from the middle'),
  ],
  'subdivide_field': [
    ToolExample({'area': 'Field', 'mode': 'strips', 'max_block_flow_m3h': 25, 'lateral': 'tape', 'lateral_spacing_m': 1.5, 'mainline': true}, 'blocks of at most 25 m³/h, filled, with the mainline'),
  ],
  'tree_rings': [
    ToolExample({'area': 'Young orchard', 'plant_spacing_m': 4, 'row_spacing_m': 6, 'ring_radius_m': 0.5}, 'a dripline ring round every tree of a 6 × 4 m planting'),
  ],
  'sports_template': [
    ToolExample({
      'kind': 'pitch',
      'center': [0, 0],
      'rotation_deg': 0,
    }, 'a 105 × 68 m football pitch'),
  ],
  'fit_pivot': [
    ToolExample({'area': 'Field', 'sector': true}, 'the largest pivot, a part circle if it covers more'),
  ],
  'rank_pumps': [ToolExample({}, 'pumps for the first supply\'s duty')],
  'apply_pump': [
    ToolExample({'pump': 'pump_c5'}, 'install that model at the first supply'),
  ],
  'suggest_air_valves': [ToolExample({}, 'air valves the mainline needs')],
  'run_analysis': [
    ToolExample({'kind': 'eps'}, 'the day hour by hour'),
    ToolExample({'kind': 'transients'}, 'water hammer'),
  ],
  'route_wires': [
    ToolExample({}, 'wiring from every controller'),
    ToolExample({'mode': 'steiner'}, 'a two-wire path'),
  ],
  'export_file': [
    ToolExample({'format': 'report_xlsx'}, 'every report table in a workbook (only when the user asks)'),
  ],
  'read_manual': [
    ToolExample({'topic': 'entities', 'item': 'pipe, controlValve'}, 'every key of two item types'),
    ToolExample({'topic': 'messages', 'item': 'cannot_meet_pressure_window'}, 'why and how for one message'),
  ],
};

/// What [e] means for the user's permission modes.
String effectText(ToolEffect e) => switch (e) {
  ToolEffect.read => 'reads only: runs in every mode',
  ToolEffect.write => 'changes the project: an undo step; approved one by one in ask mode, refused in read-only and plan modes',
  ToolEffect.export => 'saves a file: always confirmed by the user, refused in read-only and plan modes',
  ToolEffect.network => 'asks an online service: allowed in every mode, approved by the user unless changes apply automatically',
};

/// First sentence of [text], at most about [max] characters.
String firstSentence(String text, [int max = 150]) {
  final line = text.split('\n').first.trim();
  final m = RegExp(r'^(.+?\.)(\s|$)').firstMatch(line);
  final s = m == null ? line : m.group(1)!;
  if (s.length <= max) return s;
  final cut = s.lastIndexOf(' ', max - 5);
  return '${s.substring(0, cut > max ~/ 2 ? cut : max - 5)}…';
}

String _type(Map<String, Object?> s) {
  final t = s['type'];
  final options = s['enum'];
  if (options is List) return '${t ?? 'string'}: ${options.map((x) => '"$x"').join(' | ')}';
  if (t == 'array') {
    final items = s['items'];
    if (items is Map<String, Object?>) {
      final props = items['properties'];
      if (items['type'] == 'object' && props is Map && props.isNotEmpty) return 'array of {${_props(items)}}';
      return 'array of ${_type(items)}';
    }
  }
  return '$t';
}

String _props(Map<String, Object?> schema) {
  final props = (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
  final req = (schema['required'] as List?)?.cast<String>() ?? const [];
  return [
    for (final e in props.entries)
      if (e.value is Map) '${e.key}${req.contains(e.key) ? '*' : ''}: ${_type((e.value as Map).cast<String, Object?>())}',
  ].join('; ');
}

/// The inputs of [schema], one line each.
String schemaText(Map<String, Object?> schema) {
  final props = (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
  if (props.isEmpty) return '(no inputs)';
  final req = (schema['required'] as List?)?.cast<String>() ?? const [];
  return [
    for (final e in props.entries)
      if (e.value is Map)
        () {
          final s = (e.value as Map).cast<String, Object?>();
          final d = s['description'];
          return '- ${e.key}${req.contains(e.key) ? ' (required)' : ''}: ${_type(s)}${d is String && d.isNotEmpty ? ' — $d' : ''}';
        }(),
  ].join('\n');
}

String _detail(AgentTool t, {bool operation = false}) {
  final ex = toolExamples[t.name] ?? const <ToolExample>[];
  return [
    '## ${t.name} (${effectText(t.effect)})',
    t.description,
    'Inputs (* or "required" = needed):',
    schemaText(t.inputSchema),
    if (ex.isNotEmpty) 'Examples:',
    for (final x in ex) '- ${operation ? jsonEncode({'name': t.name, 'input': x.input}) : jsonEncode(x.input)} — ${x.note}',
  ].join('\n');
}

AgentTool? _named(List<AgentTool> tools, String name) {
  final n = name.trim().toLowerCase();
  for (final t in tools) {
    if (t.name.toLowerCase() == n) return t;
  }
  return null;
}

/// The "tools" topic: every tool with its purpose, or the tools named in
/// [item] in full.
String toolsTopic(AgentToolbox b, String? item) {
  final tools = b.tools;
  if (item != null && item.trim().isNotEmpty) {
    final out = <String>[];
    for (final n in item.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty).take(4)) {
      final t = _named(tools, n);
      if (t == null) {
        final op = _named(b.operations, n);
        if (op != null) {
          out.add('$n is an operation, run with run_operation:\n${_detail(op, operation: true)}');
          continue;
        }
        throw ToolInputError('No tool "$n". Tools: ${tools.map((t) => t.name).join(', ')}.');
      }
      out.add(_detail(t));
    }
    return out.join('\n\n');
  }
  return [
    '# Tools\nEvery tool, in the order they are sent. Tools that change the project are undo steps; the user\'s mode decides whether they need approval (read_manual "tools" with an item gives one tool\'s inputs and examples). The program\'s other functions are operations: find_operations and run_operation reach them.',
    for (final t in tools) '- ${t.name} [${t.effect.name}]: ${firstSentence(t.description)}',
  ].join('\n');
}

/// The "operations" topic: every operation run_operation reaches, or the
/// operations named in [item] in full.
String operationsTopic(AgentToolbox b, String? item) {
  final ops = b.operations;
  if (item != null && item.trim().isNotEmpty) {
    final out = <String>[];
    for (final n in item.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty).take(4)) {
      final t = _named(ops, n);
      if (t == null) throw ToolInputError(ops.isEmpty ? 'No operation is registered.' : 'No operation "$n". Operations: ${ops.map((t) => t.name).join(', ')}.');
      out.add(_detail(t, operation: true));
    }
    return out.join('\n\n');
  }
  if (ops.isEmpty) return '# Operations\nNo operation is registered in this version: every function the assistant reaches is a tool (read_manual "tools").';
  final byEffect = <ToolEffect, List<String>>{};
  for (final t in ops) {
    (byEffect[t.effect] ??= []).add(t.name);
  }
  return [
    '# Operations\nThe program\'s other functions, not sent as tools (${ops.length}): find_operations searches them by words and describes them, run_operation {"name", "input"} runs one under the same permissions as a tool. read_manual "operations" with an item gives one operation\'s description, inputs and examples. By their usual effect:',
    for (final e in byEffect.entries) '- ${effectText(e.key)}: ${e.value.join(', ')}',
  ].join('\n');
}
