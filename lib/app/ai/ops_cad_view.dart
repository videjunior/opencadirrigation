/// View, history, project tabs and files for the AI assistant (groups
/// "view", "history", "tabs", "file" and "help"): zoom, undo and redo and
/// the history timeline, the open tabs, new projects, attached project
/// files, the projects and versions kept in this browser, and the command
/// list. The open tabs live in the app's workspace, which the controller
/// does not know: the assistant's host provides them through
/// [AiWorkspaceHost] (without it only new tabs open, through
/// [AgentHost.openTab]). Tabs the assistant opens open in the background:
/// the screen and the assistant stay on the assistant's own project.
library;

import 'dart:convert';

import '../../core/ai/agent_loop.dart';
import '../../core/model/currency.dart';
import '../../core/model/project.dart';
import '../i18n.dart';
import '../state/controller.dart';
import 'agent_tools.dart';
import 'ops_cad_commands.dart' show commandsListing;
import 'ops_cad_common.dart';

/// One open project tab.
class AiTab {
  const AiTab({required this.name, this.dirty = false, this.active = false, this.own = false});
  final String name;

  /// Unsaved changes.
  final bool dirty;

  /// The tab on screen.
  final bool active;

  /// The tab of the project the assistant works on.
  final bool own;
}

/// What the tab and clipboard operations need from the app's workspace;
/// the assistant's [AgentHost] implements it where tabs exist.
abstract class AiWorkspaceHost {
  /// The open tabs, in order.
  List<AiTab> get tabs;

  /// Shows tab [index]; false when there is none.
  bool selectTab(int index);

  /// Closes tab [index] (the workspace keeps at least one); false when
  /// there is none or it is the assistant's own.
  bool closeTab(int index);

  /// Opens a blank project in a new tab (as File → New project tab), in the
  /// background: the tab on screen stays.
  bool newTab();

  /// Copies (or cuts) the selection of the assistant's project to the
  /// workspace clipboard: the number copied.
  Future<int> copySelection({bool cut = false});

  /// Pastes the workspace clipboard into the assistant's project: the
  /// number pasted.
  Future<int> paste();
}

final I18n _en = I18n('en');

/// What a tab opened for the user means for the assistant.
const _background =
    'in the background: the screen and you stay on your own project, which you keep working on. To work on the new tab, the user switches to it and opens the assistant there (tell the user so if they want it).';

/// The history label `hist.*|argument` in English (as the history panel
/// words it).
String historyLabel(String label) {
  final i = label.indexOf('|');
  final key = i < 0 ? label : label.substring(0, i);
  final arg = i < 0 ? '' : label.substring(i + 1);
  if (!_en.has(key)) return label;
  if (arg.isEmpty) return _en(key);
  final n = _en.has('tool.$arg') ? _en('tool.$arg') : arg;
  return _en(key, {'n': n});
}

/// A blank project as File → New project makes it (default catalogue and
/// currency of the user).
Project blankProject(ProjectController c, {String? name}) {
  final code = c.defaultCurrency();
  final p = Project(catalog: c.defaultCatalog(code));
  final defaults = DesignParameters();
  final rate = exchangeRate(defaults.currencyCode, code);
  p.params.powerCostPerKwh = defaults.powerCostPerKwh * (rate ?? 1);
  p.params.currencyCode = code;
  p.params.currency = currencySymbol(code);
  p.meta.name = (name ?? '').trim().isEmpty ? c.t('name.newProject') : name!.trim();
  return p;
}

List<AgentTool> viewOperations(AgentToolbox b) {
  final c = b.c;
  AiWorkspaceHost? ws() => b.host is AiWorkspaceHost ? b.host as AiWorkspaceHost : null;
  String historyLine(HistoryEntry e) => '#${e.index} ${historyLabel(e.label)} [${e.label}]${e.current ? ' ← current' : ''}${e.future ? ' (undone: redo brings it back)' : ''}';
  bool opened(Project p) {
    final host = b.host;
    return host != null && host.openTab(p);
  }

  return [
    cadOp(
      b,
      group: 'view',
      name: 'zoom_view',
      description: 'Zooms the user\'s view like View → Zoom in / Zoom out (ZI, ZO, + and −): "factor" above 1 zooms in, below 1 out (1.25 is one step in), about the centre of the screen or about "center" (the view moves there first). A view change, not a project change; zoom_to frames items or a bbox. Returns the area now on screen.',
      schema: obj({'factor': num_('Zoom factor, 0.01–100 (default 1.25; 0.8 zooms out).'), 'center': pointWith('Move the centre of the view here first (m).')}),
      run: (a, i) async {
        final p = a.point('center');
        if (p != null) c.camera.center = p;
        c.zoomBy(a.number('factor', min: 0.01, max: 100) ?? 1.25);
        return ToolOutput('The view shows ${AgentToolbox.box(c.camera.visible)} (${cadN(c.camera.scale, 3)} px/m).');
      },
    ),
    // ------------------------------------------------ history
    cadOp(
      b,
      group: 'history',
      name: 'get_history',
      description: 'The history panel: every action since the project was opened (#0 is the opening state), the current state marked, the undone actions that redo brings back. jump_to_history goes to any of them; undo and redo step. Each AI turn is one step once it ends.',
      schema: obj({'limit': int_('The last N entries, 1–300 (default 60).')}),
      run: (a, i) async {
        final all = c.historyEntries;
        final limit = a.integer('limit', min: 1, max: 300) ?? 60;
        final list = all.length > limit ? all.sublist(all.length - limit) : all;
        return ToolOutput(
          '${all.length} states (${c.canUndo ? 'undo possible' : 'nothing to undo'}, ${c.canRedo ? 'redo possible' : 'nothing to redo'})${all.length > limit ? '; the last $limit' : ''}:\n${list.map(historyLine).join('\n')}',
        );
      },
    ),
    cadOp(
      b,
      group: 'history',
      name: 'undo',
      effect: ToolEffect.write,
      description: 'Edit → Undo (Ctrl+Z, U): takes back the last action, or "steps" actions, of the project (the user\'s or yours). The design results are discarded. Returns the state reached; redo brings the steps back while nothing new is done.',
      schema: obj({'steps': int_('Actions to undo, 1–100 (default 1).')}),
      args: (i) => {'n': '${i['steps'] ?? 1}'},
      run: (a, i) async {
        cadNotBusy(b);
        final n = a.integer('steps', min: 1, max: 100) ?? 1;
        if (!c.canUndo) throw ToolInputError('Nothing to undo.');
        var k = 0;
        while (k < n && c.canUndo) {
          c.undo();
          k++;
        }
        final cur = c.historyEntries.where((e) => e.current).firstOrNull;
        return ToolOutput('Undid $k step${k == 1 ? '' : 's'}; now at ${cur == null ? 'the start' : historyLine(cur)}.');
      },
    ),
    cadOp(
      b,
      group: 'history',
      name: 'redo',
      effect: ToolEffect.write,
      description: 'Edit → Redo (Ctrl+Y, REDO): brings back the last undone action, or "steps" of them. Returns the state reached.',
      schema: obj({'steps': int_('Actions to redo, 1–100 (default 1).')}),
      args: (i) => {'n': '${i['steps'] ?? 1}'},
      run: (a, i) async {
        cadNotBusy(b);
        final n = a.integer('steps', min: 1, max: 100) ?? 1;
        if (!c.canRedo) throw ToolInputError('Nothing to redo.');
        var k = 0;
        while (k < n && c.canRedo) {
          c.redo();
          k++;
        }
        final cur = c.historyEntries.where((e) => e.current).firstOrNull;
        return ToolOutput('Redid $k step${k == 1 ? '' : 's'}; now at ${cur == null ? 'the start' : historyLine(cur)}.');
      },
    ),
    cadOp(
      b,
      group: 'history',
      name: 'jump_to_history',
      effect: ToolEffect.write,
      description: 'Goes back (or forward) to state #index of get_history, as a click in the history panel: the actions after it are undone (redo brings them back until something new is done). The design results are discarded.',
      schema: obj({'index': int_('State number from get_history (0 = when the project was opened).')}, required: ['index']),
      args: (i) => {'n': '${i['index']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final all = c.historyEntries;
        final index = a.integer('index', min: 0, required: true)!;
        if (index >= all.length) throw ToolInputError('There are ${all.length} states (0–${all.length - 1}).');
        c.jumpToHistory(index);
        final cur = c.historyEntries.where((e) => e.current).firstOrNull;
        return ToolOutput('Now at ${cur == null ? 'the start' : historyLine(cur)}.');
      },
    ),
    // ------------------------------------------------ tabs
    cadOp(
      b,
      group: 'tabs',
      name: 'list_tabs',
      description: 'The open project tabs: number, name, unsaved changes, which one is on screen and which one is yours (you always work on your own project; the others are the user\'s).',
      schema: obj({}),
      run: (a, i) async {
        final w = ws();
        if (w == null) return ToolOutput('Only this project is open here (no tabs are available to the assistant): "${b.p.meta.name}".');
        final tabs = w.tabs;
        return ToolOutput(
          '${tabs.length} tabs:\n${[for (var k = 0; k < tabs.length; k++) '$k: ${tabs[k].name}${tabs[k].dirty ? ' (unsaved)' : ''}${tabs[k].active ? ' — on screen' : ''}${tabs[k].own ? ' — yours' : ''}'].join('\n')}',
        );
      },
    ),
    cadOp(
      b,
      group: 'tabs',
      name: 'switch_tab',
      description: 'Shows another project tab to the user (Ctrl+Alt+→ / ←, a click on the tab). You keep working on your own project: the tools still read and change it, not the tab shown.',
      schema: obj({'index': int_('Tab number from list_tabs.')}, required: ['index']),
      args: (i) => {'n': '${i['index']}'},
      run: (a, i) async {
        final w = ws();
        if (w == null) throw ToolInputError('Tabs are not available to the assistant here.');
        final k = a.integer('index', min: 0, required: true)!;
        if (!w.selectTab(k)) throw ToolInputError('No tab $k (list_tabs).');
        return ToolOutput('Tab $k "${w.tabs[k].name}" is on screen.');
      },
    ),
    cadOp(
      b,
      group: 'tabs',
      name: 'close_tab',
      effect: ToolEffect.write,
      confirm: (_) => true,
      description: 'File → Close tab (Ctrl+Alt+W) for another tab of the user (never your own): its unsaved changes stay only in this browser\'s autosave, so the user always confirms.',
      schema: obj({'index': int_('Tab number from list_tabs.')}, required: ['index']),
      args: (i) => {'n': '${i['index']}'},
      run: (a, i) async {
        final w = ws();
        if (w == null) throw ToolInputError('Tabs are not available to the assistant here.');
        final k = a.integer('index', min: 0, required: true)!;
        final tabs = w.tabs;
        if (k >= tabs.length) throw ToolInputError('No tab $k (list_tabs).');
        if (tabs[k].own) throw ToolInputError('That is your own project: it cannot be closed from here.');
        if (!w.closeTab(k)) throw ToolInputError('Tab $k was not closed.');
        return ToolOutput('Closed tab $k "${tabs[k].name}".');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'new_project',
      effectFor: (i) => i['in_new_tab'] == false ? ToolEffect.write : ToolEffect.read,
      confirm: (i) => i['in_new_tab'] == false,
      description: 'File → New project tab (Ctrl+Alt+N): a blank project with the user\'s default catalogue and currency opens in a new tab in the background: the screen and you stay on your own project (to design the new one, the user switches to its tab and opens the assistant there). Your own project is where you design: when it is empty (a new project the user started with you), design in it; no new tab is needed. With in_new_tab false it replaces your project instead (File → New): the drawing and its undo history are lost unless saved, so the user always confirms, and unsaved changes need discard_changes.',
      schema: obj({'name': str('Name of the new project.'), 'in_new_tab': bool_('Default true.'), 'discard_changes': bool_('Replace a project with unsaved changes (in_new_tab false).')}),
      args: (i) => {'n': '${i['name'] ?? ''}'},
      run: (a, i) async {
        final name = a.str('name');
        if (a.flag('in_new_tab') ?? true) {
          final w = ws();
          if (w != null && (name ?? '').isEmpty) {
            if (!w.newTab()) throw ToolInputError('No tab could be opened.');
            return const ToolOutput('A blank project opened in a new tab $_background');
          }
          if (!opened(blankProject(c, name: name))) throw ToolInputError('Tabs cannot be opened from here; tell the user to use File → New project tab.');
          return ToolOutput('A blank project${name == null ? '' : ' "$name"'} opened in a new tab $_background');
        }
        cadNotBusy(b);
        if (c.dirty && !(a.flag('discard_changes') ?? false)) throw ToolInputError('The project has unsaved changes: save it (export_file "project") or pass discard_changes after the user agrees.');
        c.newProject();
        if (name != null) c.project.meta.name = name;
        return ToolOutput('Your project is now a blank one${name == null ? '' : ' "$name"'} (the undo history started again).');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'open_attached_project',
      description: 'File → Open for a project file (.oci.json) the user attached to the conversation: it opens in a new tab in the background (the screen and you stay on your own project; to work on it, the user switches to its tab and opens the assistant there). Drawings and GIS files go through import_attachment instead.',
      schema: obj({'name': str('File name as attached.')}, required: ['name']),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        final files = b.host?.files ?? const {};
        final name = a.str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        final Project p;
        try {
          p = Project.fromJson(jsonDecode(utf8.decode(bytes, allowMalformed: true)) as Map<String, dynamic>);
        } catch (_) {
          throw ToolInputError('"$name" is not a project file (OpenCADIrrigation .oci.json). Drawings and GIS files go through import_attachment.');
        }
        if (!opened(p)) throw ToolInputError('Tabs cannot be opened from here; tell the user to open it with File → Open.');
        return ToolOutput('Opened "${p.meta.name}" (${p.entities.length} items) in a new tab $_background');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'list_recent_projects',
      description: 'File → Recent projects: the projects kept in this browser (saved or autosaved), newest first, with their ids for open_recent_project. Autosaved ones are what the recovery offers after a crash.',
      schema: obj({}),
      run: (a, i) async {
        final list = c.store.list()..sort((x, y) => y.savedAt.compareTo(x.savedAt));
        if (list.isEmpty) return const ToolOutput('No project is kept in this browser.');
        return ToolOutput(
          '${list.length} projects:\n${[for (final p in list) '${p.uid} | ${p.name.isEmpty ? '(no name)' : p.name} | ${p.kind} | ${p.savedAt.toIso8601String().substring(0, 16)} | ${(p.bytes / 1024).toStringAsFixed(0)} kB${p.uid == c.project.meta.uid ? ' | this project' : ''}'].join('\n')}',
        );
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'open_recent_project',
      description: 'Opens a project kept in this browser (list_recent_projects) in a new tab in the background, as File → Recent projects does: the screen and you stay on your own project (to work on it, the user switches to its tab and opens the assistant there).',
      schema: obj({'id': str('Project id (uid) or name from list_recent_projects.')}, required: ['id']),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        final ref = a.str('id', required: true)!;
        final list = c.store.list();
        final hit = list.where((p) => p.uid == ref).firstOrNull ?? list.where((p) => p.name.toLowerCase() == ref.toLowerCase()).firstOrNull;
        if (hit == null) throw ToolInputError('No kept project "$ref" (list_recent_projects).');
        final json = await c.store.load(hit.uid);
        if (json == null) throw ToolInputError('The copy of "${hit.name}" could not be read.');
        final p = Project.fromJson(jsonDecode(json) as Map<String, dynamic>);
        // the kept copy itself (not a copy of it): acknowledged before it opens
        if (hit.kind == 'autosave') c.store.acknowledge(hit.uid);
        if (!opened(p)) throw ToolInputError('Tabs cannot be opened from here; tell the user to use File → Recent projects.');
        return ToolOutput('Opened "${p.meta.name}" in a new tab $_background');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'list_versions',
      description: 'File → Versions: the saved versions of this project kept in this browser (every save keeps one), newest first.',
      schema: obj({}),
      run: (a, i) async {
        final vs = c.store.versions(c.project.meta.uid);
        if (vs.isEmpty) return const ToolOutput('No saved version of this project yet (each save keeps one).');
        return ToolOutput(
          '${vs.length} versions:\n${[for (final v in vs) 'v${v.version} | ${v.savedAt.toIso8601String().substring(0, 16)} | ${(v.bytes / 1024).toStringAsFixed(0)} kB${v.label.isEmpty ? '' : ' | ${v.label}'}'].join('\n')}',
        );
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'restore_version',
      effectFor: (i) => i['in_new_tab'] == false ? ToolEffect.write : ToolEffect.read,
      confirm: (i) => i['in_new_tab'] == false,
      description: 'Opens a saved version (list_versions) in a new tab in the background (default; the screen and you stay on your own project; the tab is a copy with an id of its own), or with in_new_tab false replaces your project with it as File → Versions → Restore does (one undo step, so the user can undo it; the user always confirms).',
      schema: obj({'version': int_('Version number from list_versions.'), 'in_new_tab': bool_('Default true.')}, required: ['version']),
      args: (i) => {'n': '${i['version']}'},
      run: (a, i) async {
        final v = a.integer('version', min: 0, required: true)!;
        final json = await c.store.load(c.project.meta.uid, version: v);
        if (json == null) throw ToolInputError('No version $v of this project (list_versions).');
        if (a.flag('in_new_tab') ?? true) {
          final p = Project.fromJson(jsonDecode(json) as Map<String, dynamic>);
          if (!opened(p)) throw ToolInputError('Tabs cannot be opened from here; pass in_new_tab false (after the user agrees) or tell the user to use File → Versions.');
          return ToolOutput('Version $v of "${p.meta.name}" opened in a new tab $_background');
        }
        cadNotBusy(b);
        if (!c.restoreVersionJson(json, version: v)) throw ToolInputError('Version $v could not be restored.');
        return ToolOutput('Your project is now version $v (${c.project.entities.length} items; one undo step brings back the work as it was).');
      },
    ),
    // ------------------------------------------------ help
    cadOp(
      b,
      group: 'help',
      name: 'list_commands',
      description: 'Help → Keyboard shortcuts: every command of the command line with its aliases (Portuguese and Spanish spellings included) and what you call for it. run_command runs them.',
      schema: obj({}),
      run: (a, i) async => ToolOutput(commandsListing()),
    ),
  ];
}
