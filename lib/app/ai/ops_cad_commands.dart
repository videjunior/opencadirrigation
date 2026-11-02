/// run_command: any command of the canvas command line (the aliases of
/// shortcuts.dart, or an action or tool by name) executed without the
/// interface. Commands that open a dialog run the operation behind the
/// dialog (the one its coverage entry names, see ai_coverage.dart): read
/// operations answer what the dialog would show, operations that change
/// the project run when the model gives their input, otherwise the answer
/// says what they need. Commands that act at once act. Drawing tools wait
/// for the user's clicks, so the answer names what to call instead.
library;

import '../../core/ai/agent_loop.dart';
import '../../core/design/network_ops.dart' show routeProjectWires;
import '../../core/design/wire_routing.dart' show WireRoutingOptions;
import '../../core/model/entities.dart';
import '../../core/units.dart';
import '../i18n.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import 'agent_tools.dart';
import 'agent_tools_ops.dart' show compactSchema;
import 'ai_coverage.dart';

/// The dialog (`dialog:` coverage key without the prefix) each action
/// opens; its coverage target is what run_command runs.
const commandDialogs = <CadAction, String>{
  CadAction.array: 'more_dialogs.array',
  CadAction.densogram: 'densogram_dialog.densogram',
  CadAction.autoLayout: 'auto_design_dialogs.autoLayout',
  CadAction.template: 'auto_design_dialogs.template',
  CadAction.fieldBlocks: 'auto_design_dialogs.fieldSubdivision',
  CadAction.treeRings: 'auto_design_dialogs.treeRings',
  CadAction.pivotFit: 'auto_design_dialogs.pivotFit',
  CadAction.vegetation: 'vegetation_dialog.vegetation',
  CadAction.onDemand: 'network_ops_dialogs.onDemand',
  CadAction.tariff: 'network_ops_dialogs.tariff',
  CadAction.energyGroups: 'network_ops_dialogs.energyGrouping',
  CadAction.wireRoutes: 'network_ops_dialogs.wireRouting',
  CadAction.criticality: 'network_ops_dialogs.criticality',
  CadAction.calibration: 'network_ops_dialogs.calibration',
  CadAction.fertigation: 'network_ops_dialogs.fertigation',
  CadAction.transients: 'transient_dialogs.transient',
  CadAction.airValves: 'transient_dialogs.airValve',
  CadAction.eps: 'transient_dialogs.eps',
  CadAction.insertBlock: 'blocks_dialogs.insertBlock',
  CadAction.saveBlock: 'blocks_dialogs.saveBlock',
};

/// What a dialog action runs when its coverage entry names no tool or
/// operation (yet): the tool or operation and its default input.
const _fallbacks = <CadAction, (String, Map<String, Object?>)>{
  CadAction.array: ('array_entities', {}),
  CadAction.densogram: ('run_analysis', {'kind': 'uniformity'}),
  CadAction.autoLayout: ('layout_sprinklers', {}),
  CadAction.template: ('sports_template', {}),
  CadAction.fieldBlocks: ('subdivide_field', {}),
  CadAction.treeRings: ('tree_rings', {}),
  CadAction.pivotFit: ('fit_pivot', {}),
  CadAction.vegetation: ('detect_vegetation', {}),
  CadAction.onDemand: ('run_analysis', {'kind': 'on_demand'}),
  CadAction.energyGroups: ('run_analysis', {'kind': 'energy_grouping'}),
  CadAction.criticality: ('run_analysis', {'kind': 'criticality'}),
  CadAction.transients: ('run_analysis', {'kind': 'transients'}),
  CadAction.eps: ('run_analysis', {'kind': 'eps'}),
  CadAction.airValves: ('suggest_air_valves', {}),
  CadAction.insertBlock: ('insert_block', {}),
  CadAction.saveBlock: ('save_block', {}),
};

/// How the user's drawing tools are done without the pointer.
const toolInstead = <ToolId, String>{
  ToolId.select: 'select_entities {ids}',
  ToolId.pan: 'zoom_to {bbox | ids | all} or run_operation zoom_view',
  ToolId.line: 'create_entities {type: "line", a: [x, y], b: [x, y]}',
  ToolId.polyline: 'create_entities {type: "polyline", pts: [[x, y], …], closed}',
  ToolId.rect: 'create_entities {type: "polyline", closed: true, pts: the four corners}',
  ToolId.circle: 'create_entities {type: "circle", p: centre, r: radius m}',
  ToolId.arc: 'create_entities {type: "arc", p: centre, r, s: start angle rad, w: counter-clockwise sweep rad}',
  ToolId.spline: 'create_entities {type: "spline", pts, closed}',
  ToolId.hatch: 'create_entities {type: "hatch", pts (≥3), ang: deg, sp: spacing m, solid}',
  ToolId.symbol: 'create_entities {type: "symbol", p, kind, size m, rot deg}',
  ToolId.text: 'create_entities {type: "text", p, text, h: height m, rot deg}',
  ToolId.dimension: 'run_operation add_dimension {kind: "linear", a, b, offset_m}',
  ToolId.dimAngular: 'run_operation add_dimension {kind: "angular", vertex, a, b}',
  ToolId.dimRadial: 'run_operation add_dimension {kind: "radial", center, point, diameter}',
  ToolId.dimOrdinate: 'run_operation add_dimension {kind: "ordinate", point, leader_end}',
  ToolId.leader: 'create_entities {type: "leader", pts (arrow first), text, h}',
  ToolId.contour: 'create_entities {type: "contour", pts, z: elevation m}',
  ToolId.breakline: 'create_entities {type: "breakline", pts, zs: [elevation per vertex or null]}',
  ToolId.spot: 'create_entities {type: "spotHeight", p, z}',
  ToolId.area: 'create_entities {type: "area", pts (≥3), crop, …}',
  ToolId.zonePipe: 'create_entities {type: "pipe", scope: "zone", pts}',
  ToolId.mainPipe: 'create_entities {type: "pipe", scope: "mainline", pts}',
  ToolId.sprayline: 'create_entities {type: "sprayline", pts, outlet, nozzle, head, sp}',
  ToolId.tape: 'create_entities {type: "tape", pts, spec, inlet}',
  ToolId.outlet: 'create_entities {type: "outlet", p, outlet, nozzle, head, arc, rot, scope}',
  ToolId.valve: 'create_entities {type: "controlValve", p, spec, zone}',
  ToolId.supply: 'create_entities {type: "waterSupply", p, calc, dh, dq}',
  ToolId.pump: 'create_entities {type: "pump", p, spec, scope}',
  ToolId.misc: 'create_entities {type: "misc", p, spec, scope, set}',
  ToolId.junction: 'create_entities {type: "junction", p, scope}',
  ToolId.block: 'generate_block {area, lateral, lateral_spacing_m} or run_operation fill_block (every option of the block dialog)',
  ToolId.autohead: 'run_operation sprinkler_grid {pts | area} or layout_sprinklers {area}',
  ToolId.measure: 'measure {points, closed}',
  ToolId.rotate: 'transform_entities {ids, operation: "rotate", angle_deg, center}',
  ToolId.mirror: 'transform_entities {ids, operation: "mirror", axis_from, axis_to, keep_original}',
  ToolId.scale: 'transform_entities {ids, operation: "scale", factor, center}',
  ToolId.offset: 'run_operation offset_entities {ids, distance_m, side}',
  ToolId.trim: 'run_operation trim_entity {id, at}',
  ToolId.extend: 'run_operation extend_entity {id, at}',
  ToolId.cutPipe: 'run_operation split_entity {id, at}',
  ToolId.profile: 'terrain_profile {pts} for the numbers, or run_operation show_profile {pts} to show it to the user',
  ToolId.pivot: 'create_entities {type: "pivot", p: centre, r, ang} or fit_pivot {area}',
  ToolId.alignImage: 'run_operation align_entities {ids, from_a, to_a, from_b, to_b}',
  ToolId.controller: 'create_entities {type: "controller", p, st: stations}',
  ToolId.wire: 'create_entities {type: "wire", pts} or route_wires',
  ToolId.comment: 'create_entities {type: "comment", p, text, author}',
  ToolId.revisionCloud: 'run_operation add_revision_cloud {pts, revision, description}',
  ToolId.insertBlock: 'run_operation insert_block {name, at}',
  ToolId.aiMarkPoint: 'nothing to call: these are the user\'s marks for the AI, read in the user\'s message and seen in your pictures (orange, labelled A, B…)',
  ToolId.aiMarkLine: 'nothing to call: these are the user\'s marks for the AI, read in the user\'s message and seen in your pictures (orange, labelled A, B…)',
  // 1.6.0 EDT
  ToolId.move: 'transform_entities {ids, operation: "move", dx, dy}',
  ToolId.copy: 'transform_entities {ids, operation: "copy", dx, dy} (once per copy)',
  ToolId.lasso: 'list_entities {bbox, types, layer} to find the items, then select_entities {ids}',
  ToolId.fence: 'list_entities {bbox, types, layer} to find the items, then select_entities {ids}',
  ToolId.stretch: 'update_entities {updates: [{id, set: {pts}}]} with the vertices inside the window moved (one entry per item)',
  ToolId.fillet: 'update_entities {updates: [{id, set: {pts}}]} with the corner vertex replaced by the arc vertices (or create_entities an arc between two lines)',
  ToolId.chamfer: 'update_entities {updates: [{id, set: {pts}}]} with the corner vertex replaced by the two cut points',
  ToolId.breakTwo: 'run_operation split_entity {id, at} at both points, then delete_entities the piece between',
};

/// English names for the model.
final I18n _en = I18n('en');

String _label(Object target) => (target is ToolId ? _en('tool.${target.name}') : _en(actionLabelKey(target as CadAction))).replaceFirst(RegExp(r'…$'), '');

/// The tool or action [command] names: an alias (any case), a [CadAction]
/// name or a [ToolId] name; null when none.
Object? resolveCommand(String command) {
  final raw = command.trim();
  final byAlias = commandAliases[raw.toUpperCase()];
  if (byAlias != null) return byAlias;
  final low = raw.toLowerCase();
  for (final a in CadAction.values) {
    if (a.name.toLowerCase() == low) return a;
  }
  for (final t in ToolId.values) {
    if (t.name.toLowerCase() == low) return t;
  }
  return null;
}

/// Every command with its aliases and what the assistant calls for it.
String commandsListing() {
  final aliases = <Object, List<String>>{};
  for (final e in commandAliases.entries) {
    (aliases[e.value] ??= []).add(e.key);
  }
  String route(String key) => aiCoverage[key] ?? '?';
  final out = StringBuffer(
    'Commands of the command line (run_command takes an alias, the action or the tool name). Drawing tools wait for the user\'s clicks: the route says what to call instead.\n\nActions:\n',
  );
  for (final a in CadAction.values) {
    out.writeln('${a.name} (${_label(a)}): ${(aliases[a] ?? const []).join(', ')} → ${route('action:${a.name}')}');
  }
  out.writeln('\nDrawing tools:');
  for (final t in ToolId.values) {
    out.writeln('${t.name} (${_label(t)}): ${(aliases[t] ?? const ['—']).join(', ')} → ${toolInstead[t] ?? route('tool:${t.name}')}');
  }
  return out.toString();
}

/// What one run_command call does: its effect, whether it is confirmed,
/// the approval line and the work (run only once approved).
class _Plan {
  _Plan({required this.effect, required this.summary, required this.run, this.confirm = false});
  final ToolEffect effect;
  final bool confirm;
  final String summary;
  final Future<ToolOutput> Function() run;
}

class CommandRunner {
  CommandRunner(this.b);
  final AgentToolbox b;

  ProjectController get c => b.c;

  ToolEffect effectOf(Map<String, dynamic> i) {
    try {
      return _plan(i).effect;
    } catch (_) {
      return ToolEffect.read;
    }
  }

  bool mustConfirm(Map<String, dynamic> i) {
    try {
      return _plan(i).confirm;
    } catch (_) {
      return false;
    }
  }

  String describe(Map<String, dynamic> i) {
    try {
      return _plan(i).summary;
    } catch (_) {
      return b.t('ai.op.run_command', {'n': '${i['command'] ?? ''}'});
    }
  }

  Future<ToolOutput> run(Map<String, dynamic> i) => _plan(i).run();

  AgentTool? _named(String name) {
    for (final o in b.operations) {
      if (o.name == name) return o;
    }
    for (final o in b.tools) {
      if (o.name == name) return o;
    }
    return null;
  }

  /// A plan that only answers [text] (reads nothing, changes nothing).
  _Plan _say(String cmd, String text) => _Plan(effect: ToolEffect.read, summary: b.t('ai.op.run_command', {'n': cmd}), run: () async => ToolOutput(text));

  /// A plan that acts on the screen at once (no project change).
  _Plan _act(String cmd, String Function() f) => _Plan(effect: ToolEffect.read, summary: b.t('ai.op.run_command', {'n': cmd}), run: () async => ToolOutput(f()));

  /// A plan that runs [tool] with [input] (its effect, confirmation and
  /// approval line).
  _Plan _delegate(AgentTool tool, Map<String, dynamic> input) {
    final problem = schemaProblem(tool.inputSchema, input);
    if (problem != null) {
      return _say(tool.name, '$problem\nInput of ${tool.name}: ${compactSchema(tool.inputSchema)}');
    }
    return _Plan(
      effect: tool.effectOf(input),
      confirm: tool.mustConfirm(input),
      summary: tool.describe(input),
      run: () async {
        final out = await tool.run(input);
        return out;
      },
    );
  }

  List<String> get _selection => [
    for (final e in b.p.entities)
      if (c.selection.contains(e.id)) e.id,
  ];

  _Plan _plan(Map<String, dynamic> i) {
    final cmd = '${i['command'] ?? ''}'.trim();
    final given = i['input'] is Map;
    final input = given ? Map<String, dynamic>.from(i['input'] as Map) : <String, dynamic>{};
    if (cmd.isEmpty || cmd == '?') return _say(cmd, commandsListing());
    final target = resolveCommand(cmd);
    if (target == null) {
      return _Plan(
        effect: ToolEffect.read,
        summary: b.t('ai.op.run_command', {'n': cmd}),
        run: () async => throw ToolInputError('Unknown command "$cmd". run_command with "?" lists the commands (aliases such as L, PL, TR, ARRAY, U).'),
      );
    }
    if (target is ToolId) return _tool(cmd, target, i['activate_tool'] == true);
    final a = target as CadAction;
    bool? on() => input['on'] is bool ? input['on'] as bool : null;
    String toggle(String what, bool now) => '$what is now ${now ? 'on' : 'off'}.';
    switch (a) {
      case CadAction.select:
        return _act(cmd, () {
          c.setTool(ToolId.select);
          return 'The selection tool is active for the user. To select items yourself call select_entities.';
        });
      case CadAction.zoomAll:
        return _act(cmd, () {
          c.zoomAll();
          return 'The view shows the whole drawing ${AgentToolbox.box(b.p.bounds)}.';
        });
      case CadAction.zoomIn || CadAction.zoomOut:
        return _act(cmd, () {
          c.zoomBy(a == CadAction.zoomIn ? 1.25 : 0.8);
          return 'Zoomed ${a == CadAction.zoomIn ? 'in' : 'out'}; the view shows ${AgentToolbox.box(c.camera.visible)}.';
        });
      case CadAction.erase:
        final ids = input['ids'] is List ? [for (final x in input['ids'] as List) '$x'] : _selection;
        if (ids.isEmpty) return _say(cmd, 'Nothing is selected. Call delete_entities with the ids, or select_entities first.');
        return _delegate(_named('delete_entities')!, {'ids': ids});
      case CadAction.copy || CadAction.cut || CadAction.paste:
        final op = _named('clipboard');
        if (op == null) return _say(cmd, 'The clipboard is not available here.');
        return _delegate(op, {'action': a.name, ...input});
      case CadAction.undo || CadAction.redo:
        return _delegate(_named(a.name)!, input);
      case CadAction.selectAll:
        return _act(cmd, () {
          c.selectAll();
          return '${c.selection.length} items selected.';
        });
      case CadAction.duplicate:
        final ids = input['ids'] is List ? [for (final x in input['ids'] as List) '$x'] : _selection;
        if (ids.isEmpty) {
          return _say(cmd, 'Nothing is selected. Duplicate copies the selection 2 m east and 2 m south; with transform_entities {ids, operation: "copy", dx, dy} you choose the offset.');
        }
        return _delegate(_named('transform_entities')!, {'ids': ids, 'operation': 'copy', 'dx': 2, 'dy': -2});
      case CadAction.feedEnvelope:
        return _delegate(_named('feed_envelope')!, {if (_selection.isNotEmpty) 'ids': _selection, ...input});
      case CadAction.run:
        return _delegate(_named('run_design')!, input);
      case CadAction.check:
        return _act(cmd, () {
          final r = c.runDesignCheckReport();
          return 'Design check: ${r.issues.length} issues (unconnected items are marked on the drawing).\n${messagesText(b)}';
        });
      case CadAction.autoFix:
        return _say(cmd, _autoFixText());
      case CadAction.optimize:
        final opt = _named('optimize_design')!;
        return given
            ? _delegate(opt, input)
            : _say(cmd, 'The optimise dialog looks for the lowest annual cost without new errors. Run it with optimize_design ${compactSchema(opt.inputSchema)} (or run_command OPT with that input).');
      case CadAction.assistant:
        return _say(cmd, 'That command opens this assistant: nothing to do.');
      case CadAction.snap:
        return _act(cmd, () => toggle('Object snap', c.snap.enabled = on() ?? !c.snap.enabled));
      case CadAction.ortho:
        return _act(cmd, () => toggle('Ortho', c.snap.ortho = on() ?? !c.snap.ortho));
      case CadAction.gridSnap:
        return _act(cmd, () => toggle('Grid snap', c.snap.grid = on() ?? !c.snap.grid));
      case CadAction.gridDisplay:
        return _act(cmd, () {
          c.showGrid = on() ?? !c.showGrid;
          c.refresh();
          return toggle('The grid', c.showGrid);
        });
      case CadAction.reports:
        return _act(cmd, () {
          c.showReports = on() ?? !c.showReports;
          c.refresh();
          return '${toggle('The reports panel', c.showReports)} Read the tables with get_report_table.';
        });
      case CadAction.save:
        return _delegate(_named('export_file')!, {'format': 'project'});
      case CadAction.open:
        return _say(
          cmd,
          'Opening a file needs the user\'s file picker. Ask the user to attach the project file to the conversation, then call run_operation open_attached_project {name}; drawings and GIS files go through import_attachment. Projects kept in this browser open with open_recent_project.',
        );
      case CadAction.wireRoutes:
        final t = _dialogTool(a);
        if (t != null && t.$1.name != 'route_wires') return _dialogPlan(cmd, a, t, input, given);
        return given ? _delegate(_named('route_wires')!, input) : _act(cmd, _wirePreview);
      default:
        final t = _dialogTool(a);
        if (t == null) return _say(cmd, 'The ${_label(a)} dialog has no operation for the assistant yet. Try find_operations {query: "${_label(a)}"}.');
        return _dialogPlan(cmd, a, t, input, given);
    }
  }

  /// The tool or operation behind the dialog of [a] and its default input.
  (AgentTool, Map<String, Object?>)? _dialogTool(CadAction a) {
    final key = commandDialogs[a];
    final fb = _fallbacks[a];
    final cov = key == null ? null : aiCoverage['dialog:$key'];
    final name = cov != null && (cov.startsWith('tool:') || cov.startsWith('op:')) ? cov.substring(cov.indexOf(':') + 1) : fb?.$1;
    if (name == null) return null;
    final tool = _named(name);
    if (tool == null) return fb == null ? null : (_named(fb.$1) == null ? null : (_named(fb.$1)!, fb.$2));
    return (tool, fb != null && fb.$1 == name ? fb.$2 : const <String, Object?>{});
  }

  _Plan _dialogPlan(String cmd, CadAction a, (AgentTool, Map<String, Object?>) target, Map<String, dynamic> input, bool given) {
    final (tool, defaults) = target;
    final props = (tool.inputSchema['properties'] as Map?) ?? const {};
    final eff = <String, dynamic>{...defaults, ...input};
    // the selection stands in for the items or the area the dialog works on
    final sel = _selection;
    if (props.containsKey('ids') && !eff.containsKey('ids') && sel.isNotEmpty) eff['ids'] = sel;
    if (props.containsKey('area') && !eff.containsKey('area') && sel.length == 1) eff['area'] = sel.first;
    ToolEffect effect;
    try {
      effect = tool.effectOf(eff);
    } catch (_) {
      effect = tool.effect;
    }
    final problem = schemaProblem(tool.inputSchema, eff);
    // a dialog that changes the project waits for its input, as the user
    // would fill it in before pressing its button
    if (problem != null || (effect != ToolEffect.read && !given)) {
      return _say(
        cmd,
        'The ${_label(a)} dialog runs ${tool.name}: ${firstLine(tool.description)}\n${problem ?? 'It changes the project: give its input (run_command with "input", or call ${tool.name} directly).'}\nInput: ${compactSchema(tool.inputSchema)}${sel.isEmpty ? '' : '\nSelected now: ${sel.take(20).join(', ')}.'}',
      );
    }
    return _delegate(tool, eff);
  }

  String _autoFixText() {
    final adv = c.advice;
    final fixable = [
      for (var k = 0; k < adv.length; k++)
        if (adv[k].fixes.isNotEmpty) k,
    ];
    if (fixable.isEmpty) return 'No message offers an automatic correction now${c.results == null ? ' (run_design first: most corrections need results)' : ''}.';
    return 'The fix-automatically dialog applies the safe corrections of these messages, designing again in rounds: ${fixable.take(30).map((k) => '#$k [${adv[k].code}] ${adv[k].fixes.map((f) => f.name).join('/')}').join('; ')}. Run auto_fix to apply them all, or apply_fix one by one (get_design_messages explains each).';
  }

  String _wirePreview() {
    final r = routeProjectWires(b.p, options: WireRoutingOptions(tolerance: b.p.params.connectTolerance > 0.1 ? b.p.params.connectTolerance : 0.1));
    if (r.routes.isEmpty) {
      return 'No wire route: the drawing needs a controller and zone valves joined by pipes.${r.warnings.isEmpty ? '' : ' (${r.warnings.map((w) => b.t.warning(w, entityName: c.entityName)).join('; ')})'}';
    }
    return 'Wire routing would lay ${r.routes.length} routes, ${fmt(r.totalRouteM, 0)} m in all, for ${r.stations.length} stations (replacing the wires drawn). route_wires applies it.${r.warnings.isEmpty ? '' : '\nMessages: ${r.warnings.map((w) => b.t.warning(w, entityName: c.entityName)).join('; ')}'}';
  }

  _Plan _tool(String cmd, ToolId id, bool activate) {
    final how = toolInstead[id] ?? aiCoverage['tool:${id.name}'] ?? 'create_entities';
    final text = '${_label(id)} is a drawing tool that takes its points from the user\'s clicks; do it with $how.';
    if (!activate) return _say(cmd, text);
    return _act(cmd, () {
      if (id == ToolId.pump || id == ToolId.misc) c.toolSettings.pointScope = HydraulicScope.mainline;
      if (id == ToolId.outlet || id == ToolId.valve) c.toolSettings.pointScope = HydraulicScope.zone;
      c.setTool(id);
      return '$text It is now the user\'s active tool.';
    });
  }
}

/// The first line of [s].
String firstLine(String s) {
  final i = s.indexOf('\n');
  return i < 0 ? s : s.substring(0, i);
}
