import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ops_cad_settings.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/model/project.dart';

import 'support/fake_claude.dart';

/// The permissions as a property (IA-15): every call the assistant may make
/// in read-only mode — every tool and operation with an input built from
/// its schema, every setting of set_setting with a valid value, every
/// command of run_command — is planned as the agent loop plans it (bound,
/// then its effect), and every one that counts as a read is run on a
/// project with a bit of everything: the project, this browser's
/// preferences and the network must be as they were. A call that changes
/// any of them is a hole in the permission model (as set_setting of the
/// custom base map and update_notes were). The loop then refuses the
/// changes in read-only mode, whatever the call.
class _Host implements AgentHost {
  _Host(this.c);

  /// The notes are the project's, as the app keeps them: writing them
  /// changes the project (an undo step).
  final ProjectController c;
  @override
  AgentPermission permission = AgentPermission.readOnly;
  @override
  bool stopped = false;
  @override
  String get notes => c.project.aiNotes;
  @override
  final Map<String, Uint8List> files = {'notes.txt': Uint8List.fromList(utf8.encode('line one\nline two'))};
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => [for (final _ in questions) ''];
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => null;
  @override
  void setNotes(String text) => c.mutate(() => c.project.aiNotes = text, invalidateResults: false);
  @override
  bool openTab(Project p) => false;
}

/// No network in this test: every request is recorded, then fails.
class _NoNetwork extends HttpOverrides {
  final seen = <String>[];
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(seen);
}

class _Client implements HttpClient {
  _Client(this.seen);
  final List<String> seen;
  Future<HttpClientRequest> _no(Uri u) {
    seen.add('$u');
    return Future.error(const SocketException('no network in this test'));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _no(url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _no(url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _no(url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A value of [schema] for property [name] (ids of the project's items
/// where a name says an id).
Object? _sample(Map? schema, String name, List<String> ids) {
  final s = schema ?? const {};
  final e = s['enum'];
  if (e is List && e.isNotEmpty) return e.first;
  return switch (s['type']) {
    'string' => name.contains('id') || name == 'area' || name == 'mainline' || name == 'name' ? ids.first : 'x',
    'number' => 1,
    'integer' => 1,
    'boolean' => true,
    'array' => s['items'] is Map && (s['items'] as Map)['type'] == 'number' ? [0, 0] : (name.contains('id') ? [ids.first] : const []),
    'object' => _input(s, ids),
    _ => null,
  };
}

/// An input of [schema]: its required fields.
Map<String, dynamic> _input(Map schema, List<String> ids) {
  final props = schema['properties'] is Map ? schema['properties'] as Map : const {};
  return {for (final r in (schema['required'] as List? ?? const [])) '$r': ?_sample(props[r] as Map?, '$r', ids)};
}

/// A valid value for setting [s].
Object? _settingValue(AiSetting s) {
  final now = s.read();
  return switch (s.type) {
    'boolean' => !(now == true),
    'enum' => s.options!.firstWhere((o) => o != now, orElse: () => s.options!.first),
    'number' || 'integer' => s.min ?? 1,
    _ => s.key == 'view.custom_tile_url' ? 'https://tiles.example/{z}/{x}/{y}.png?d=farm' : 'x',
  };
}

/// Reads that record a step in the undo history without changing the
/// project (the analysis takes a snapshot, as the user's Analyse does).
const _recordsHistory = {'analyse_design', 'run_operation run_analysis'};

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
    // a project with a bit of everything: pipes, valves, a supply, areas, emitters
    c.openProject(buildExample(ExampleId.garden, c.t.call));
    c.project.aiNotes = 'Client wants PVC.';
    box = AgentToolbox(c, host: _Host(c));
  });

  testWidgets('read-only: every call that counts as a read leaves the project, the preferences and the network as they were', (tester) async {
    final net = _NoNetwork();
    final ids = [for (final e in c.project.entities.take(3)) e.id];
    final calls = <(AgentTool, Map<String, dynamic>, String)>[];
    final setSetting = box.tools.firstWhere((t) => t.name == 'set_setting');
    final runCommand = box.tools.firstWhere((t) => t.name == 'run_command');
    final runOperation = box.tools.firstWhere((t) => t.name == 'run_operation');
    for (final t in box.tools) {
      calls.add((t, _input(t.inputSchema, ids), t.name));
    }
    for (final o in box.operations) {
      calls.add((runOperation, {'name': o.name, 'input': _input(o.inputSchema, ids)}, 'run_operation ${o.name}'));
    }
    for (final s in aiSettings(box)) {
      if (s.readOnly || s.delegated) continue;
      calls.add((
        setSetting,
        {
          'values': {s.key: _settingValue(s)},
        },
        'set_setting ${s.key}',
      ));
    }
    final commands = {...commandAliases.keys, for (final a in CadAction.values) a.name, for (final t in ToolId.values) t.name};
    for (final k in commands) {
      calls.add((runCommand, {'command': k}, 'run_command $k'));
    }
    expect(calls.length, greaterThan(500), reason: 'every tool, operation, setting and command');
    final holes = <String>[];
    var reads = 0;
    for (final (tool, input, label) in calls) {
      // planned as the loop plans it
      final problem = schemaProblem(tool.inputSchema, input);
      if (problem != null) continue;
      Map<String, dynamic> bound;
      ToolEffect effect;
      try {
        bound = tool.bind(input);
        effect = tool.effectOf(bound);
      } catch (_) {
        continue;
      }
      if (effect != ToolEffect.read) continue;
      reads++;
      final project = jsonEncode(c.project.toJson()), history = c.historyIndex, prefs = jsonEncode(debugPrefs());
      final before = net.seen.length;
      await tester.runAsync(
        () => HttpOverrides.runZoned(() async {
          try {
            await tool.run(bound).timeout(const Duration(seconds: 8));
          } catch (_) {
            // an input the tool refuses, a timeout: what counts is what changed
          }
        }, createHttpClient: net.createHttpClient),
      );
      final changed = [
        if (jsonEncode(c.project.toJson()) != project) 'the project',
        // an analysis records the drawing as a history step (as Design → Analyse does): nothing in it changes
        if (c.historyIndex != history && !_recordsHistory.contains(label)) 'the undo history',
        if (jsonEncode(debugPrefs()) != prefs) 'the preferences',
        if (net.seen.length > before) 'the network (${net.seen.skip(before).take(2).join(', ')})',
      ];
      if (changed.isNotEmpty) holes.add('$label ${jsonEncode(bound)} counts as a read but changed ${changed.join(', ')}');
      // the next call starts from the same project
      if (changed.contains('the project')) c.openProject(Project.fromJson(jsonDecode(project) as Map<String, dynamic>));
    }
    expect(reads, greaterThan(150), reason: 'the reads were run');
    expect(holes, isEmpty, reason: holes.join('\n'));
  });

  testWidgets('read-only through the loop: a change, the custom map, the program options and the notes are refused, the view\'s toggles run', (tester) async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        (
          'set_setting',
          {
            'values': {'view.custom_tile_url': 'https://evil.example/{z}/{x}/{y}.png'},
          },
        ),
        (
          'set_setting',
          {
            'values': {'app.auto_analyze': true},
          },
        ),
        ('update_notes', {'text': 'Injected.', 'mode': 'replace'}),
        (
          'delete_entities',
          {
            'ids': [c.project.entities.first.id],
          },
        ),
        (
          'set_setting',
          {
            'values': {'view.grid': false},
          },
        ),
      ]),
      (_) => FakeReply.text('done'),
    ]);
    final project = jsonEncode(c.project.toJson());
    final host = box.host! as _Host;
    AgentTurn? t;
    await tester.runAsync(() async {
      t = await AgentLoop(
        api: AnthropicClient(apiKey: 'sk-ant-test', transport: f.call, sleep: (_) async {}),
        tools: box.tools,
      ).run(model: AiModel.opus55, system: 's', history: const [], user: AnthropicFormat.user([const AiTextPart('go')]), permission: AgentPermission.readOnly, cancel: AiCancel());
    });
    expect(t!.calls.map((x) => x.state), [ToolCallState.refused, ToolCallState.refused, ToolCallState.refused, ToolCallState.refused, ToolCallState.done]);
    expect(jsonEncode(c.project.toJson()), project);
    expect(host.notes, 'Client wants PVC.');
    expect(c.customTileUrl, isEmpty);
    expect(c.autoAnalyze, isFalse);
    expect(c.showGrid, isFalse, reason: 'a toggle of the view');
  });
}
