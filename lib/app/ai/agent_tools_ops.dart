/// The way to the rest of the program: find_operations and run_operation
/// over [AgentToolbox.operations], run_command for the menu commands, and
/// get_setting / set_setting over the program's settings.
///
/// The operations (drawing edits, annotation, blocks, history, terrain,
/// analyses, calculators, sheets…) are not sent with every request, so the
/// requests stay small: the model looks them up with find_operations and
/// runs them with run_operation, whose effect, confirmation and approval
/// summary are those of the operation it runs.
library;

import '../../core/ai/agent_loop.dart';
import 'agent_tools.dart';
import 'ai_safety.dart';
import 'ops_cad_commands.dart';
import 'ops_cad_settings.dart';

/// An operation reached through run_operation, with the [group] that
/// find_operations filters by (edit, annotate, view, terrain…).
class OpTool extends FnTool {
  OpTool({
    required this.group,
    required super.name,
    required super.description,
    required super.inputSchema,
    super.effect,
    super.effectFor,
    super.summary,
    super.confirm,
    super.binder,
    required super.handler,
  });
  final String group;
}

/// The group of operation [t] (operations that are not an [OpTool] are
/// the engineering side's).
String opGroup(AgentTool t) => t is OpTool ? t.group : 'engineering';

/// [schema] in one line for the model: `{name*: type — description; …}`
/// (* = required).
String compactSchema(Map<String, Object?> schema) {
  final props = schema['properties'];
  if (props is! Map || props.isEmpty) return '{}';
  final req = {...?(schema['required'] as List?)};
  return '{${[for (final e in props.entries) _prop('${e.key}', e.value, req.contains(e.key))].join('; ')}}';
}

String _prop(String k, Object? v, bool required) {
  final m = v is Map ? v : const {};
  final d = m['description'];
  return '$k${required ? '*' : ''}: ${_type(m)}${d is String && d.isNotEmpty ? ' — $d' : ''}';
}

String _type(Map m) {
  final e = m['enum'];
  if (e is List) return e.map((x) => '"$x"').join('|');
  return switch (m['type']) {
    'array' => '[${m['items'] is Map ? _type(m['items'] as Map) : 'any'}]',
    'object' => m['properties'] is Map && (m['properties'] as Map).isNotEmpty ? compactSchema(Map<String, Object?>.from(m)) : 'object',
    null => 'any',
    final t => '$t',
  };
}

/// Words of [s] for the search (lower case, a plural "s" dropped).
List<String> _words(String s) => [
  for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (w.length > 1) w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w,
];

/// The first sentence of [s] (for listings): up to the first full stop
/// followed by a space or the end, not one of "e.g.", "i.e.", "etc.", "vs.".
String firstSentence(String s) {
  final x = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final m in RegExp(r'[.!?](?= |$)').allMatches(x)) {
    final head = x.substring(0, m.end);
    if (RegExp(r'(\be\.g|\bi\.e|\betc|\bvs|\bcf|\bapprox)\.$', caseSensitive: false).hasMatch(head)) continue;
    return head;
  }
  return x;
}

List<AgentTool> operationTools(AgentToolbox b) {
  final t = b.t;
  AgentTool? named(String? name) {
    if (name == null) return null;
    for (final o in b.operations) {
      if (o.name == name) return o;
    }
    for (final o in b.tools) {
      if (o.name == name && o.name != 'run_operation') return o;
    }
    return null;
  }

  Map<String, dynamic> inner(Map<String, dynamic> i) => i['input'] is Map ? Map<String, dynamic>.from(i['input'] as Map) : <String, dynamic>{};
  // the operation and its input when the call can run, else null
  (AgentTool, Map<String, dynamic>)? valid(Map<String, dynamic> i) {
    final op = named(i['name'] is String ? (i['name'] as String).trim() : null);
    if (op == null) return null;
    final input = inner(i);
    return schemaProblem(op.inputSchema, input) == null ? (op, input) : null;
  }

  final commands = CommandRunner(b);
  return [
    FnTool(
      name: 'find_operations',
      description: 'Finds the program\'s operations that are not sent as tools — drawing edits (offset, trim, extend, split, array, align, vertices), dimensions and revision clouds, blocks, layers, the view, undo/redo and the history, project tabs and files, terrain (contours, profiles, elevation downloads), georeference and images, vegetation detection, imports, and the engineering side (analyses, calculators, machines, catalogue, quote, sheets, exports) — with their description, effect and input. Call it with a query (words of what you want to do, e.g. "offset", "dimension", "undo", "contour") and/or a group; with no input it lists the groups and their operations. Then call run_operation with the name and the input. Reading costs nothing and changes nothing.',
      inputSchema: obj({
        'query': str('Words of the task, e.g. "trim pipe", "revision cloud", "georeference".'),
        'group': str('Only this group (e.g. edit, annotate, blocks, layers, view, history, tabs, file, terrain, site, import, zone, help, engineering…).'),
        'names': arr(str(), 'Exact operation names to describe (e.g. from an earlier listing).', 30),
        'limit': int_('Operations described in full, 1–25 (default 8); the other matches are listed by name.'),
      }),
      summary: (i) => t('ai.op.find_operations', {'n': '${i['query'] ?? i['group'] ?? ''}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final ops = b.operations;
        final query = a.str('query') ?? '';
        final group = a.str('group')?.toLowerCase();
        final names = a.strings('names');
        final limit = a.integer('limit', min: 1, max: 25) ?? 8;
        if (query.isEmpty && group == null && names.isEmpty) {
          final byGroup = <String, List<String>>{};
          for (final o in ops) {
            (byGroup[opGroup(o)] ??= []).add(o.name);
          }
          return ToolOutput(
            '${ops.length} operations in ${byGroup.length} groups (run them with run_operation; find_operations with a query, a group or names gives their descriptions and inputs):\n${[for (final e in byGroup.entries) '${e.key}: ${e.value.join(', ')}'].join('\n')}',
          );
        }
        final List<AgentTool> hits;
        if (names.isNotEmpty) {
          hits = [];
          final missing = <String>[];
          for (final n in names) {
            final o = named(n);
            o == null ? missing.add(n) : hits.add(o);
          }
          if (hits.isEmpty) throw ToolInputError('No operation ${missing.join(', ')}. Call find_operations with a query instead.');
        } else {
          final words = _words(query);
          final scored = <(AgentTool, int)>[];
          for (final o in ops) {
            final g = opGroup(o);
            if (group != null && g != group) continue;
            if (words.isEmpty) {
              scored.add((o, 1));
              continue;
            }
            final nameWords = _words(o.name.replaceAll('_', ' '));
            final desc = _words(o.description).toSet();
            var score = 0;
            for (final w in words) {
              if (nameWords.contains(w)) {
                score += 4;
              } else if (nameWords.any((n) => n.startsWith(w) || w.startsWith(n) && n.length > 3)) {
                score += 3;
              } else if (g == w) {
                score += 2;
              } else if (desc.contains(w) || desc.any((d) => d.length > 4 && d.startsWith(w))) {
                score += 1;
              }
            }
            if (score > 0) scored.add((o, score));
          }
          scored.sort((x, y) => y.$2 != x.$2 ? y.$2.compareTo(x.$2) : x.$1.name.compareTo(y.$1.name));
          hits = [for (final s in scored) s.$1];
        }
        if (hits.isEmpty) {
          final groups = {for (final o in ops) opGroup(o)}.toList();
          return ToolOutput(
            'No operation matches${query.isEmpty ? '' : ' "$query"'}${group == null ? '' : ' in group "$group"'}. Groups: ${groups.join(', ')}. Try other words, or no input for the whole list. What only the user can do (the tutorial, walking the field with the device\'s GPS, map keys) is in read_manual "interface", with the menu paths.',
          );
        }
        final out = StringBuffer('${hits.length} operation${hits.length == 1 ? '' : 's'} match${hits.length == 1 ? 'es' : ''}; run one with run_operation {name, input}.\n');
        for (final o in hits.take(limit)) {
          final e = o is FnTool && o.effectFor != null ? 'effect varies (${o.effect.name} by default)' : o.effect.name;
          out.writeln('\n## ${o.name} (${opGroup(o)}; $e)\n${o.description}\nInput: ${compactSchema(o.inputSchema)}');
        }
        if (hits.length > limit) out.writeln('\nAlso: ${hits.skip(limit).map((o) => o.name).join(', ')} (find_operations with names describes them).');
        return ToolOutput(out.toString());
      },
    ),
    FnTool(
      name: 'run_operation',
      effect: ToolEffect.write,
      description: 'Runs one of the operations found with find_operations, by name, with its input (an object checked against the operation\'s schema before anything changes). Its effect is the operation\'s: reads run at once; changes are one undo step and follow the user\'s permission mode; exports, network requests and large deletions are confirmed by the user. Returns the operation\'s result, or an error with the schema to correct the input.',
      inputSchema: obj(
        {
          'name': str('Operation name, e.g. "offset_entities".'),
          'input': {'type': 'object', 'description': 'The operation\'s input (see find_operations); {} when it takes none.'},
        },
        required: ['name'],
      ),
      effectFor: (i) {
        final v = valid(i);
        if (v == null) return ToolEffect.read; // refused before anything runs
        try {
          return v.$1.effectOf(v.$2);
        } catch (_) {
          return ToolEffect.write;
        }
      },
      confirm: (i) {
        final v = valid(i);
        if (v == null) return false;
        try {
          return v.$1.mustConfirm(v.$2);
        } catch (_) {
          return true;
        }
      },
      summary: (i) {
        final v = valid(i);
        if (v == null) return t('ai.op.run_operation', {'n': '${i['name'] ?? ''}'});
        try {
          return v.$1.describe(v.$2);
        } catch (_) {
          return t('ai.op.run_operation', {'n': v.$1.name});
        }
      },
      // the operation's own binding (the selection it works on, taken now)
      binder: (i) {
        final v = valid(i);
        if (v == null) return i;
        final bound = v.$1.bind(v.$2);
        return identical(bound, v.$2) ? i : {...i, 'input': bound};
      },
      handler: (i) async {
        final name = ToolArgs(i).str('name', required: true)!;
        final op = named(name);
        if (op == null) {
          final w = _words(name.replaceAll('_', ' '));
          final like = [
            for (final o in b.operations)
              if (w.any((x) => x.length > 3 && o.name.contains(x))) o.name,
          ];
          throw ToolInputError('Unknown operation "$name".${like.isEmpty ? '' : ' Similar: ${like.take(8).join(', ')}.'} Use find_operations to look it up.');
        }
        final input = inner(i);
        final problem = schemaProblem(op.inputSchema, input);
        if (problem != null) throw ToolInputError('$problem\nInput of ${op.name}: ${compactSchema(op.inputSchema)}');
        return op.run(input);
      },
    ),
    FnTool(
      name: 'run_command',
      effect: ToolEffect.write,
      description: 'Runs a command of the program by its typed alias (the command line of the canvas: "Z", "E", "U", "REDO", "OS", "ARRAY", "FE", "DENS", "CHK", "SURGE", "INSERT"…; Portuguese and Spanish spellings too) or by its action or tool name ("zoomAll", "feedEnvelope", "polyline"). Commands that open a dialog run headless: you get what the dialog would show, and with "input" the operation behind the dialog runs with it (one undo step); commands that act at once (erase, undo, the snap toggles…) act. Drawing tools that wait for the user\'s clicks are not run: the answer names the tool or operation to call instead (activate_tool selects the tool for the user). Effect and confirmation are those of what runs. run_command with "?" lists the commands.',
      inputSchema: obj(
        {
          'command': str('Alias, action or tool name, e.g. "TR", "ARRAY", "zoomAll"; "?" lists them.'),
          'input': {'type': 'object', 'description': 'Input of the operation behind a dialog (see the answer without it), e.g. {"rows": 2, "cols": 3} for ARRAY.'},
          'activate_tool': bool_('For a drawing tool: make it the user\'s active tool (default false).'),
        },
        required: ['command'],
      ),
      effectFor: commands.effectOf,
      confirm: commands.mustConfirm,
      summary: commands.describe,
      binder: commands.bind,
      handler: commands.run,
    ),
    FnTool(
      name: 'get_setting',
      description: 'Reads settings of the program by key or prefix: params.* (the design parameters of get_parameters), units.* (display units), project.* (details), quote.* (the quote), view.* (grid, labels, overlays, base map, theme, interface language, reports panel, active tool, visible area), snap.* (snap, grid snap, ortho, polar tracking), tool.* (defaults of the drawing tools: pipes, emitters, heads, text heights…) and app.* (autosave, automatic analysis). Each line: key = value (type, range, unit) — what it does. Without input it lists every key with its value only.',
      inputSchema: obj({'keys': arr(str(), 'Exact keys, e.g. ["snap.ortho", "units.flow"].', 100), 'prefix': str('Keys starting with this, e.g. "view." or "tool.pivot".')}),
      summary: (i) => t('ai.op.get_setting', {'n': '${i['prefix'] ?? (i['keys'] as List?)?.join(', ') ?? ''}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final all = aiSettings(b);
        final keys = a.strings('keys');
        final prefix = a.str('prefix');
        final byKey = {for (final s in all) s.key: s};
        final unknown = [
          for (final k in keys)
            if (!byKey.containsKey(k)) k,
        ];
        if (unknown.isNotEmpty) throw ToolInputError('Unknown settings ${unknown.join(', ')}. Prefixes: params, units, project, quote, view, snap, tool, app (get_setting with a prefix lists them).');
        final list = [
          for (final s in all)
            if ((keys.isEmpty || keys.contains(s.key)) && (prefix == null || s.key.startsWith(prefix))) s,
        ];
        if (list.isEmpty) return ToolOutput('No setting starts with "$prefix". Prefixes: params, units, project, quote, view, snap, tool, app.');
        // everything at once: values only (the full lines by prefix or key)
        if (keys.isEmpty && prefix == null) {
          return ToolOutput(
            '${list.length} settings, key = value (get_setting with a prefix or keys gives their types, ranges and what they do; set_setting changes them):\n${list.map((s) => '${s.key} = ${showValue(s.read())}').join('\n')}',
          );
        }
        return ToolOutput('${list.length} settings (set_setting changes them; project settings are one undo step, the others are not part of the project):\n${list.map((s) => s.line()).join('\n')}');
      },
    ),
    FnTool(
      name: 'set_setting',
      effect: ToolEffect.write,
      description: 'Changes settings by key (see get_setting), every value checked against its type and range before anything changes. Project settings (params.*, units.*, project.*, quote.*) are one undo step and need the user\'s approval like any change; params.* go through set_parameters and discard the design results. View, snap and tool settings (view.*, snap.*, tool.*) change the screen or the defaults of the user\'s drawing tools, not the project, and are allowed in every mode — except what this browser keeps: the interface language and the theme are changes (approval in "ask", refused in read-only), and the custom base map (view.custom_tile_url, view.base_map "custom": its tiles come from that address) and the program options (app.*) are always confirmed by the user. Setting tool.outlet_spec, tool.nozzle, tool.tape_spec or tool.misc_spec also sets the nozzle, head or setting that go with it (reported). Returns the old and new values.',
      inputSchema: obj(
        {
          'values': {'type': 'object', 'description': 'key → new value, e.g. {"snap.ortho": true, "view.overlay": "pressure", "units.flow": "m3h"}.'},
        },
        required: ['values'],
      ),
      // by key: the view's toggles are reads, the rest are changes (settingImpact)
      effectFor: (i) {
        final v = i['values'];
        if (v is! Map) return ToolEffect.read;
        return v.entries.any((e) => settingImpact('${e.key}', e.value) != null) ? ToolEffect.write : ToolEffect.read;
      },
      confirm: (i) {
        final v = i['values'];
        return v is Map && v.entries.any((e) => settingImpact('${e.key}', e.value)?.confirm ?? false);
      },
      summary: (i) {
        final v = (i['values'] as Map?) ?? const {};
        final text = t('ai.op.set_setting', {'n': v.entries.map((e) => '${e.key} = ${e.value}').join(', ')});
        // where the custom base map would fetch its tiles from, in plain sight
        final url = v['view.custom_tile_url'] is String ? v['view.custom_tile_url'] as String : (v['view.base_map'] == 'custom' ? b.c.customTileUrl : '');
        return url.trim().isEmpty ? text : '$text — ${t('ai.ask.tileHost', {'h': aiHost(url)})}';
      },
      handler: (i) async => ToolOutput(await setSettings(b, i['values'])),
    ),
  ];
}

/// Checks and applies [raw] (key → value): the text for the model.
Future<String> setSettings(AgentToolbox b, Object? raw) async {
  if (raw is! Map || raw.isEmpty) throw ToolInputError('"values" must be a non-empty object of key → value.');
  final values = <String, Object?>{for (final e in raw.entries) '${e.key}': e.value};
  final extra = settingFollowUps(b, values);
  final all = {
    for (final s in aiSettings(b, pending: {...values, ...extra})) s.key: s,
  };
  final plan = <(AiSetting, Object?)>[];
  final params = <String, Object?>{};
  for (final e in {...values, ...extra}.entries) {
    final s = all[e.key];
    if (s == null) {
      final near = [
        for (final k in all.keys)
          if (k.split('.').last == e.key.split('.').last || k.contains(e.key) || editDistance(k, e.key) <= 2) k,
      ];
      throw ToolInputError('Unknown setting "${e.key}".${near.isEmpty ? '' : ' Did you mean ${near.take(5).join(', ')}?'} get_setting lists them.');
    }
    final p = s.problem(e.value);
    if (p != null) throw ToolInputError(p);
    if (s.delegated) {
      params[e.key.substring('params.'.length)] = e.value;
    } else {
      plan.add((s, e.value));
    }
  }
  final before = {for (final (s, _) in plan) s.key: showValue(s.read())};
  final out = <String>[];
  if (params.isNotEmpty) {
    final setParams = b.tools.firstWhere((x) => x.name == 'set_parameters');
    final r = await setParams.run({'values': params});
    if (r.isError) throw ToolInputError(r.text);
    out.add(r.text);
  }
  final project = [
    for (final x in plan)
      if (x.$1.isProject) x,
  ];
  final others = [
    for (final x in plan)
      if (!x.$1.isProject) x,
  ];
  if (project.isNotEmpty) {
    if (b.c.busy) throw ToolInputError('A design is running; wait until it finishes.');
    b.change('set_setting', () {
      for (final (s, v) in project) {
        s.write!(v);
      }
      return project.length;
    }, invalidate: false);
  }
  for (final (s, v) in others) {
    s.write!(v);
  }
  b.c.refresh();
  for (final (s, _) in plan) {
    out.add(
      '${s.key}: ${before[s.key]} → ${showValue(s.read())}${extra.containsKey(s.key) && !values.containsKey(s.key) ? ' (follows ${values.keys.where((k) => k.startsWith('tool.')).join(', ')})' : ''}',
    );
  }
  final georefNote = values['view.base_map'] != null && values['view.base_map'] != 'none' && b.p.meta.georef == null
      ? '\nThe project has no georeference yet, so no map shows: call set_site (or set_georeference).'
      : '';
  return 'Changed:\n${out.join('\n')}$georefNote';
}

/// Levenshtein distance of [a] and [b] (for "did you mean").
int editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 3) return 99;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final x = prev[j] + 1, y = cur[j - 1] + 1, z = prev[j - 1] + cost;
      cur[j] = x < y ? (x < z ? x : z) : (y < z ? y : z);
    }
    prev = cur;
  }
  return prev[b.length];
}
