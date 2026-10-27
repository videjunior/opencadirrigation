import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_ops_cad.dart';
import 'package:opencadirrigation/app/ai/agent_ops_engineering.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/agent_tools_ops.dart';
import 'package:opencadirrigation/app/ai/ai_coverage.dart';
import 'package:opencadirrigation/app/ai/ops_cad_commands.dart' show toolInstead;
import 'package:opencadirrigation/app/ai/ops_cad_settings.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/menu_bar.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/i18n/language_packs.dart' show uninstallLanguagePack;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Every function a user can reach has a route for the AI assistant: each
/// command action, drawing tool and command alias, each leaf item of the
/// desktop menu bar and of the phone menu and buttons (the menus are built
/// with a language pack that writes every label as its i18n key), and each
/// dialog of lib/app/widgets/dialogs has an entry in aiCoverage; every
/// target exists (tool, operation, command, setting); the names are unique;
/// and docs/AI_TOOLS.md is the table generated from all of it (write it
/// with UPDATE_AI_TOOLS_DOC=1).
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => null;
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => null;
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

/// The menus the CAD side owns (the rest is the engineering side's), by
/// the i18n key of the top menu or phone section.
const _cadMenus = {'menu.file', 'menu.edit', 'menu.view', 'menu.draw', 'menu.zone', 'menu.mainline', 'menu.help', 'gps.submenu', 'mobile.buttons'};

/// File menu items the engineering side owns (exports, sheets, sharing).
bool _engineeringFileItem(String key, String submenu) =>
    submenu == 'file.exportDrawing' ||
    submenu == 'file.exportReport' ||
    key.startsWith('file.exportDrawing+') ||
    key.startsWith('file.exportReport+') ||
    key == 'file.shareLink' ||
    key == 'file.exportReport' ||
    key == 'file.exportDrawing';

/// Dialogs the CAD side owns: whole files, or `stem.dialog`.
const _cadDialogFiles = {'basemap_dialogs', 'blocks_dialogs', 'vegetation_dialog', 'pdf_import_dialog', 'welcome_dialog', 'shortcuts_dialog', 'ai_assistant_dialog', 'ai_start_dialog'};
const _cadDialogs = {
  'dialogs.projectDetails',
  'dialogs.units',
  'dialogs.block',
  'dialogs.autohead',
  'dialogs.text',
  'dialogs.comment',
  'dialogs.revision',
  'dialogs.leader',
  'dialogs.aboutDialogApp',
  'dialogs.labelRules',
  'dialogs.selectionBom',
  'more_dialogs.array',
  'more_dialogs.dem',
  'more_dialogs.recovery',
  'more_dialogs.versions',
  'more_dialogs.imageGeoref',
  'more_dialogs.deviceOnLaterals',
  'terrain_dialogs.elevation',
  'terrain_dialogs.onlineDem',
  'terrain_dialogs.generateContours',
  'export_dialogs.georeference',
};

/// The functions found in the program: coverage key → (owner, English
/// label), owner "cad" or "engineering".
class _Found {
  final keys = <String, (String, String)>{};
  void add(String key, String owner, String label) => keys.putIfAbsent(key, () => (owner, label));
}

final I18n _en = I18n('en');

String _text(Widget? w) => w is Text ? (w.data ?? '') : '';

/// The coverage key of a label written with the key pack: the keys in it,
/// joined with "+"; a language name is the language menu.
String? _menuKey(String label) {
  final ks = [for (final m in RegExp(r'⟦([^⟧]+)⟧').allMatches(label)) m.group(1)!];
  if (ks.isNotEmpty) return ks.join('+');
  if (languageNames.values.contains(label.trim())) return 'view.language';
  return null;
}

String _enLabel(String key) => key.split('+').map((k) => _en.has(k) ? _en(k).replaceFirst(RegExp(r'…$'), '') : k).join(' · ');

Future<_Found> _enumerate(WidgetTester tester) async {
  final found = _Found();
  // ---- command actions, drawing tools, aliases
  for (final a in CadAction.values) {
    found.add('action:${a.name}', 'cad', _en(actionLabelKey(a)));
  }
  for (final t in ToolId.values) {
    found.add('tool:${t.name}', 'cad', _en.has('tool.${t.name}') ? _en('tool.${t.name}') : t.name);
  }
  for (final e in commandAliases.entries) {
    found.add('alias:${e.key}', 'cad', e.key);
  }
  // ---- dialogs: every show… function of the dialog files
  for (final f in Directory('lib/app/widgets/dialogs').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList()..sort((a, b) => a.path.compareTo(b.path))) {
    final stem = f.uri.pathSegments.last.replaceAll('.dart', '');
    for (final m in RegExp(r'^Future<.*?>\??\s+show([A-Z]\w*)\(', multiLine: true).allMatches(f.readAsStringSync())) {
      var n = m.group(1)!;
      if (n.endsWith('Dialog')) n = n.substring(0, n.length - 6);
      n = n[0].toLowerCase() + n.substring(1);
      found.add('dialog:$stem.$n', _cadDialogFiles.contains(stem) || _cadDialogs.contains('$stem.$n') ? 'cad' : 'engineering', '$stem.$n');
    }
  }
  // ---- menus, built with every label written as its key
  installLanguagePack('de', LanguagePack(strings: {for (final k in I18n.keys) k: '⟦$k⟧'}));
  addTearDown(() => uninstallLanguagePack('de'));
  LocalProjectStore().clearAll();
  TutorialController.markDone();
  final c = ProjectController()
    ..autosaveEnabled = false
    ..designRunner = InThreadDesignRunner();
  c.newProject();
  await c.setLanguage('de', persist: false);
  final ws = Workspace(systemClipboard: false, openBlankTab: false)..addTab(controller: c);
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCadTheme(),
      home: Scaffold(
        body: AppMenuBar(c: c, ws: ws, onStartTutorial: () {}, onShowWelcome: () {}, onCloseTab: () {}),
      ),
    ),
  );
  void walk(List<Widget> items, String top, String submenu) {
    for (final w in items) {
      switch (w) {
        case SubmenuButton s:
          walk(s.menuChildren, top, _menuKey(_text(s.child)) ?? submenu);
        case MenuItemButton m:
          _leaf(found, _text(m.child), top, submenu);
        case CheckboxMenuButton m:
          _leaf(found, _text(m.child), top, submenu);
        case RadioMenuButton m:
          _leaf(found, _text(m.child), top, submenu);
        default:
          break;
      }
    }
  }

  final bar = tester.widget<MenuBar>(find.byType(MenuBar));
  for (final top in bar.children.whereType<SubmenuButton>()) {
    walk(top.menuChildren, _menuKey(_text(top.child)) ?? '?', '');
  }
  // the phone layout: the ☰ sheet and the floating buttons (drawing, with
  // a selection, so every button shows)
  c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
  c.select([c.project.entities.first.id]);
  c.activeTool = ToolId.line;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCadTheme(),
      home: MobileShell(c: c, ws: ws, canvas: const SizedBox(), hint: '', onStartTutorial: () {}, onShowWelcome: () {}, onCloseTab: () {}, onDesignCheck: () {}),
    ),
  );
  for (final k in ['mobile_done', 'mobile_cancel', 'mobile_delete', 'mobile_undo', 'mobile_history', 'mobile_props', 'mobile_reports']) {
    final tip = tester.widget<Tooltip>(find.ancestor(of: find.byKey(Key(k)), matching: find.byType(Tooltip)).first);
    _leaf(found, tip.message ?? '', 'mobile.buttons', '');
  }
  await tester.tap(find.byKey(const Key('mobile_menu')));
  await tester.pumpAndSettle();
  for (final tile in tester.widgetList<ExpansionTile>(find.byType(ExpansionTile))) {
    final section = _menuKey(_text(tile.title)) ?? '?';
    for (final w in tile.children) {
      if (w is ListTile) _leaf(found, _text(w.title), section, '');
    }
  }
  await tester.pumpWidget(const SizedBox());
  return found;
}

/// Adds the menu item [label] found under [top] / [submenu].
void _leaf(_Found found, String label, String top, String submenu) {
  final key = _menuKey(label);
  if (key == null) return;
  final engineering = !_cadMenus.contains(top) || (top == 'menu.file' && _engineeringFileItem(key, submenu));
  found.add('menu:$key', engineering ? 'engineering' : 'cad', _enLabel(key));
}

/// What the targets of the coverage map can be.
class _Targets {
  _Targets(this.box) : tools = {for (final t in box.tools) t.name: t}, ops = {for (final o in box.operations) o.name: o}, settings = {for (final s in aiSettings(box)) s.key: s};
  final AgentToolbox box;
  final Map<String, AgentTool> tools;
  final Map<String, AgentTool> ops;
  final Map<String, AiSetting> settings;

  /// The problem of route [v], or null when its target exists.
  String? problem(String v) {
    final i = v.indexOf(':');
    if (i < 0) return 'no kind prefix';
    final kind = v.substring(0, i), name = v.substring(i + 1);
    return switch (kind) {
      'tool' => tools.containsKey(name) ? null : 'no tool "$name" in AgentToolbox.tools',
      'op' => ops.containsKey(name) ? null : 'no operation "$name" in AgentToolbox.operations',
      'command' => commandAliases.containsKey(name) ? null : 'no command alias "$name"',
      'setting' => settings.containsKey(name) ? null : 'no setting "$name" in the settings registry',
      'n/a' => name.trim().length < 8 ? 'n/a needs its reason' : null,
      _ => 'unknown kind "$kind"',
    };
  }
}

Future<AgentToolbox> _box(WidgetTester tester) async {
  LocalProjectStore().clearAll();
  final c = ProjectController()
    ..autosaveEnabled = false
    ..designRunner = InThreadDesignRunner();
  c.newProject();
  await c.setLanguage('en', persist: false);
  return AgentToolbox(c, host: _Host());
}

String _owner(String key) => coreCoverage.containsKey(key) || cadCoverage.containsKey(key) ? 'cad' : (engineeringCoverage.containsKey(key) ? 'engineering' : '?');

String _list(Iterable<String> xs) => xs.isEmpty ? '(none)' : xs.map((x) => '\n  $x').join();

void main() {
  testWidgets('every action, tool, alias, menu item and dialog has a route for the AI', (tester) async {
    final found = await _enumerate(tester);
    expect(found.keys.keys.where((k) => k.startsWith('menu:')).length, greaterThan(250), reason: 'the menus were walked');
    final missing = [
      for (final e in found.keys.entries)
        if (!aiCoverage.containsKey(e.key)) e,
    ];
    final cad = [for (final e in missing.where((e) => e.value.$1 == 'cad')) '${e.key}   (${e.value.$2})'];
    final eng = [for (final e in missing.where((e) => e.value.$1 == 'engineering')) '${e.key}   (${e.value.$2})'];
    expect(
      missing,
      isEmpty,
      reason:
          '${missing.length} user-reachable functions have no entry in aiCoverage.\nCAD side (ai_coverage.dart coreCoverage / agent_ops_cad.dart cadCoverage), ${cad.length}:${_list(cad)}\nEngineering side (agent_ops_engineering.dart engineeringCoverage), ${eng.length}:${_list(eng)}',
    );
  });

  testWidgets('every route exists: tools, operations, commands, settings; no key in two maps', (tester) async {
    final targets = _Targets(await _box(tester));
    final bad = <String, List<String>>{};
    for (final e in aiCoverage.entries) {
      final p = targets.problem(e.value);
      if (p != null) (bad[_owner(e.key)] ??= []).add('${e.key} → ${e.value}: $p');
    }
    expect(bad, isEmpty, reason: 'Routes without a target:\n${[for (final e in bad.entries) '${e.key} side:${_list(e.value)}'].join('\n')}');
    final maps = {'coreCoverage': coreCoverage, 'cadCoverage': cadCoverage, 'engineeringCoverage': engineeringCoverage};
    final twice = <String>[];
    final names = maps.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        for (final k in maps[names[i]]!.keys) {
          if (maps[names[j]]!.containsKey(k)) twice.add('$k in ${names[i]} (${maps[names[i]]![k]}) and ${names[j]} (${maps[names[j]]![k]})');
        }
      }
    }
    expect(twice, isEmpty, reason: 'Keys in two coverage maps (the owner keeps it, the other side removes it):${_list(twice)}');
    for (final k in aiCoverage.keys) {
      expect(RegExp(r'^(action|tool|alias|menu|dialog|panel|status|view):\S+$').hasMatch(k), isTrue, reason: 'malformed key "$k"');
    }
  });

  testWidgets('tool and operation names are unique, described, and every drawing tool says what to call', (tester) async {
    final box = await _box(tester);
    final names = [for (final t in box.tools) t.name, for (final o in box.operations) o.name];
    final dup = {
      for (final n in names)
        if (names.where((x) => x == n).length > 1) n,
    };
    expect(dup, isEmpty, reason: 'names used twice: $dup');
    for (final o in box.operations) {
      expect(o.description.length, greaterThan(40), reason: o.name);
      expect(o.inputSchema['type'], 'object', reason: o.name);
      expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(o.name), isTrue, reason: 'snake_case: ${o.name}');
    }
    for (final o in box.operations.whereType<OpTool>()) {
      expect(o.group, isNotEmpty);
      // every operation's approval line is translated
      expect(box.t.has('ai.op.${o.name}'), isTrue, reason: 'i18n key ai.op.${o.name}');
    }
    for (final t in ToolId.values) {
      expect(toolInstead.containsKey(t), isTrue, reason: 'run_command has no answer for the drawing tool ${t.name}');
    }
    final keys = {for (final s in aiSettings(box)) s.key};
    expect(keys.length, aiSettings(box).length, reason: 'settings keys are unique');
    for (final k in ['params.maxZoneVelocity', 'params.terrainMethod', 'units.system', 'view.overlay', 'view.language', 'snap.ortho', 'tool.outlet_spec', 'app.autosave', 'quote.markup_pct']) {
      expect(keys, contains(k));
    }
  });

  testWidgets('docs/AI_TOOLS.md is the table of the coverage map', (tester) async {
    final found = await _enumerate(tester);
    final targets = _Targets(await _box(tester));
    final doc = _document(found, targets);
    final file = File('docs/AI_TOOLS.md');
    if (Platform.environment['UPDATE_AI_TOOLS_DOC'] == '1') {
      file.writeAsStringSync(doc);
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'write it: UPDATE_AI_TOOLS_DOC=1 flutter test test/widget_ai_coverage_test.dart');
    final now = file.readAsStringSync();
    if (now != doc) {
      final a = now.split('\n'), b = doc.split('\n');
      var k = 0;
      while (k < a.length && k < b.length && a[k] == b[k]) {
        k++;
      }
      fail(
        'docs/AI_TOOLS.md is out of date (first difference at line ${k + 1}: "${k < a.length ? a[k] : ''}" ≠ "${k < b.length ? b[k] : ''}"). Regenerate it: UPDATE_AI_TOOLS_DOC=1 flutter test test/widget_ai_coverage_test.dart',
      );
    }
  });
}

// ---------------------------------------------------------------- the document

String _cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ').trim();

String _effect(AgentTool t) => t is FnTool && t.effectFor != null ? 'varies' : t.effect.name;

String _short(String s, [int max = 160]) {
  final x = firstSentence(s);
  return x.length <= max ? x : '${x.substring(0, max - 1)}…';
}

/// The notes of route [v]: what its target does.
String _notes(String v, _Targets t) {
  final i = v.indexOf(':');
  final kind = v.substring(0, i), name = v.substring(i + 1);
  return switch (kind) {
    'tool' => _short(t.tools[name]?.description ?? ''),
    'op' => _short(t.ops[name]?.description ?? ''),
    'setting' => _short(t.settings[name]?.description ?? ''),
    'command' =>
      'run_command "$name" (${() {
        final target = commandAliases[name];
        return target == null ? '?' : aiCoverage[coverageKeyOf(target)] ?? '?';
      }()})',
    _ => name,
  };
}

String _route(String v) {
  if (isNotApplicable(v)) return 'n/a';
  return '`$v`';
}

String _document(_Found found, _Targets t) {
  final out = StringBuffer()
    ..writeln('# AI tools and operations')
    ..writeln()
    ..writeln(
      '<!-- Generated by test/widget_ai_coverage_test.dart from lib/app/ai/ai_coverage.dart and the tool, operation and setting descriptions. Do not edit by hand: UPDATE_AI_TOOLS_DOC=1 flutter test test/widget_ai_coverage_test.dart -->',
    )
    ..writeln()
    ..writeln('How the AI assistant of OpenCADIrrigation reaches every function of the program. The model works with:')
    ..writeln()
    ..writeln('- **tools** sent with every request (`tool:`): reading the project, creating and changing items, the design, the automatic layouts, the view, the site;')
    ..writeln(
      '- **operations** (`op:`) that are not sent, so the requests stay small: the model looks them up with `find_operations` and runs them with `run_operation`, which takes the effect, confirmation and approval line of the operation it runs;',
    )
    ..writeln(
      '- **commands** (`command:`): `run_command` runs any alias of the command line or action by name; a command that opens a dialog runs the operation behind it headless (reads answer what the dialog would show; changes wait for their input), drawing tools that take the user\'s clicks are answered with what to call instead;',
    )
    ..writeln(
      '- **settings** (`setting:`): `get_setting` / `set_setting` over the design parameters, units, project details, quote, view, snapping, tool defaults and program options, typed and range-checked;',
    )
    ..writeln('- `n/a`: functions with no meaning for the AI, with the reason.')
    ..writeln()
    ..writeln(
      'Permissions: reads run freely; changes are undo steps and follow the user\'s mode (asked in "ask", refused in read-only and plan); exports and large deletions are confirmed by the user even when changes apply automatically; network requests (site search, terrain and climate downloads) are asked in "ask" and run freely when changes apply automatically. View, snapping, tool and program settings are not changes of the project.',
    )
    ..writeln();
  // ---- numbers
  const sources = ['action', 'tool', 'alias', 'menu', 'dialog', 'panel', 'status', 'view'];
  final optionKeys = {
    for (final k in aiCoverage.keys)
      if (k.startsWith('dialog:') && !found.keys.containsKey(k)) k,
  };
  out
    ..writeln('## Coverage')
    ..writeln()
    ..writeln('| Source | Functions | Covered | Not applicable | Missing |')
    ..writeln('|---|---:|---:|---:|---:|');
  var tf = 0, tc = 0, tn = 0, tm = 0;
  for (final s in [...sources, 'dialog options']) {
    final keys = s == 'dialog options'
        ? optionKeys.toList()
        : (const {'panel', 'status', 'view'}.contains(s)
              ? [
                  for (final k in aiCoverage.keys)
                    if (k.startsWith('$s:')) k,
                ]
              : [
                  for (final k in found.keys.keys)
                    if (k.startsWith('$s:')) k,
                ]);
    var covered = 0, na = 0, missing = 0;
    for (final k in keys) {
      final v = aiCoverage[k];
      if (v == null || t.problem(v) != null) {
        missing++;
      } else if (isNotApplicable(v)) {
        na++;
      } else {
        covered++;
      }
    }
    tf += keys.length;
    tc += covered;
    tn += na;
    tm += missing;
    final label = switch (s) {
      'action' => 'Command actions',
      'tool' => 'Drawing tools',
      'alias' => 'Command aliases',
      'menu' => 'Menu items (desktop and phone)',
      'dialog' => 'Dialogs',
      'dialog options' => 'Dialog options',
      'panel' => 'Panel fields',
      'status' => 'Status bar',
      _ => 'View options',
    };
    out.writeln('| $label | ${keys.length} | $covered | $na | $missing |');
  }
  out
    ..writeln('| **All** | **$tf** | **$tc** | **$tn** | **$tm** |')
    ..writeln()
    ..writeln('${t.tools.length} tools, ${t.ops.length} operations, ${t.settings.length} settings.')
    ..writeln();
  // ---- tools
  out
    ..writeln('## Tools sent with every request')
    ..writeln()
    ..writeln('| Tool | Effect | What it does |')
    ..writeln('|---|---|---|');
  for (final x in t.tools.values) {
    out.writeln('| `${x.name}` | ${_effect(x)} | ${_cell(_short(x.description, 220))} |');
  }
  // ---- operations
  final groups = <String, List<AgentTool>>{};
  for (final o in t.ops.values) {
    (groups[opGroup(o)] ??= []).add(o);
  }
  out
    ..writeln()
    ..writeln('## Operations (find_operations / run_operation)')
    ..writeln()
    ..writeln('| Operation | Group | Effect | What it does |')
    ..writeln('|---|---|---|---|');
  for (final g in groups.entries) {
    for (final o in g.value) {
      out.writeln('| `${o.name}` | ${g.key} | ${_effect(o)} | ${_cell(_short(o.description, 220))} |');
    }
  }
  // ---- settings
  out
    ..writeln()
    ..writeln('## Settings (get_setting / set_setting)')
    ..writeln()
    ..writeln('| Key | Type | Scope | What it sets |')
    ..writeln('|---|---|---|---|');
  for (final s in t.settings.values) {
    out.writeln('| `${s.key}` | ${_cell(s.delegated ? 'design parameter' : s.typeText)} | ${s.scope.name} | ${_cell(s.description)} |');
  }
  // ---- functions
  final aliases = <String, List<String>>{};
  for (final e in commandAliases.entries) {
    (aliases[coverageKeyOf(e.value)] ??= []).add(e.key);
  }
  void table(String title, Iterable<String> keys, {bool withAliases = false}) {
    out
      ..writeln()
      ..writeln('### $title')
      ..writeln()
      ..writeln(withAliases ? '| Function | Aliases | Route | Notes |' : '| Function | Route | Notes |')
      ..writeln(withAliases ? '|---|---|---|---|' : '|---|---|---|');
    for (final k in keys) {
      final v = aiCoverage[k];
      final label = found.keys[k]?.$2 ?? '';
      final fn = '`${k.substring(k.indexOf(':') + 1)}`${label.isEmpty || label == k.substring(k.indexOf(':') + 1) ? '' : ' ${_cell(label)}'}';
      final route = v == null ? '**missing**' : _route(v);
      final notes = v == null ? '' : _cell(_notes(v, t));
      out.writeln(withAliases ? '| $fn | ${(aliases[k] ?? const []).join(', ')} | $route | $notes |' : '| $fn | $route | $notes |');
    }
  }

  out
    ..writeln()
    ..writeln('## Functions → AI');
  table('Command actions', [for (final a in CadAction.values) 'action:${a.name}'], withAliases: true);
  table('Drawing tools', [for (final x in ToolId.values) 'tool:${x.name}'], withAliases: true);
  final menuKeys = [
    for (final k in found.keys.keys)
      if (k.startsWith('menu:')) k,
  ];
  table('Menu items', menuKeys);
  final dialogKeys = {
    for (final k in found.keys.keys)
      if (k.startsWith('dialog:')) k,
    ...optionKeys,
  }.toList()..sort();
  table('Dialogs and their options', dialogKeys);
  table('Panels', [
    for (final k in aiCoverage.keys)
      if (k.startsWith('panel:')) k,
  ]);
  table('Status bar', [
    for (final k in aiCoverage.keys)
      if (k.startsWith('status:')) k,
  ]);
  table('View options', [
    for (final k in aiCoverage.keys)
      if (k.startsWith('view:')) k,
  ]);
  return out.toString();
}
