/// Shared helpers of the drawing-side operations of the AI assistant
/// (agent_ops_cad.dart): the operation builder, the checks every edit
/// starts with and compact text for the model.
library;

import '../../core/ai/agent_loop.dart';
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import 'agent_tools.dart';
import 'agent_tools_ops.dart';

/// Builds a drawing-side operation of [group]: the approval summary is the
/// i18n key `ai.op.<name>` with the arguments [args] gives (`{n}` and the
/// like), the handler gets the checked input.
OpTool cadOp(
  AgentToolbox b, {
  required String group,
  required String name,
  required String description,
  required Map<String, Object?> schema,
  ToolEffect effect = ToolEffect.read,
  ToolEffect Function(Map<String, dynamic> input)? effectFor,
  bool Function(Map<String, dynamic> input)? confirm,
  Map<String, String> Function(Map<String, dynamic> input)? args,
  Map<String, dynamic> Function(Map<String, dynamic> input)? binder,
  required Future<ToolOutput> Function(ToolArgs a, Map<String, dynamic> input) run,
}) => OpTool(
  group: group,
  name: name,
  description: description,
  inputSchema: schema,
  effect: effect,
  effectFor: effectFor,
  confirm: confirm,
  binder: binder,
  summary: (i) {
    Map<String, String>? x;
    try {
      x = args?.call(i);
    } catch (_) {
      x = null;
    }
    return b.t('ai.op.$name', x ?? const {'n': ''});
  },
  handler: (i) => run(ToolArgs(i), i),
);

/// Refuses while a design runs (its result replaces the hydraulic items).
void cadNotBusy(AgentToolbox b) {
  if (b.c.busy) throw ToolInputError('A design is running; wait until it finishes.');
}

/// The items [refs] (ids or names), refusing those on locked layers.
List<Entity> cadEditable(AgentToolbox b, Iterable<String> refs) {
  final es = b.findAll(refs);
  final locked = [
    for (final e in es)
      if (b.p.isLocked(e.layer)) e.id,
  ];
  if (locked.isNotEmpty) throw ToolInputError('Items on locked layers: ${locked.take(10).join(', ')}. Unlock the layer first (edit_layers action "unlock") or leave them.');
  return es;
}

/// The items of input "ids", or with "selected" true the current selection
/// (an import selects what it adds), refusing those on locked layers.
List<Entity> cadEditableOrSelection(AgentToolbox b, ToolArgs a) {
  if (a.flag('selected') ?? false) {
    if (b.c.selection.isEmpty) throw ToolInputError('Nothing is selected: give "ids".');
    return cadEditable(b, [...b.c.selection]);
  }
  if (!a.has('ids')) throw ToolInputError('Give "ids" (or "selected": true for the current selection).');
  return cadEditable(b, a.strings('ids', required: true));
}

/// [AgentTool.bind] of a call that takes "ids" or "selected": true (the
/// items of an import, which come in selected): the selection as ids, taken
/// when the call is planned, so the approval card names the items and
/// those are the ones that change, whatever the user selects meanwhile.
Map<String, dynamic> cadBindSelected(AgentToolbox b, Map<String, dynamic> i) {
  if (i['selected'] != true || b.c.selection.isEmpty) return i;
  return {
    for (final e in i.entries)
      if (e.key != 'selected') e.key: e.value,
    'ids': cadSelectionIds(b),
  };
}

/// [AgentTool.bind] of a call whose "ids" default to the selection: the
/// selection as ids, taken when the call is planned. [keep] picks the items
/// the call works on (e.g. only laterals).
Map<String, dynamic> cadBindDefaultIds(AgentToolbox b, Map<String, dynamic> i, {bool Function(Entity e)? keep}) {
  if (i['ids'] is List && (i['ids'] as List).isNotEmpty) return i;
  final ids = cadSelectionIds(b, keep: keep);
  return ids.isEmpty ? i : {...i, 'ids': ids};
}

/// The ids of the selected items, in the drawing's order.
List<String> cadSelectionIds(AgentToolbox b, {bool Function(Entity e)? keep}) => [
  for (final e in b.p.entities)
    if (b.c.selection.contains(e.id) && (keep == null || keep(e))) e.id,
];

/// Ids of the entities added to the project since [before] (the ids it
/// held then).
List<String> cadAdded(AgentToolbox b, Set<String> before) => [
  for (final e in b.p.entities)
    if (!before.contains(e.id)) e.id,
];

/// The ids of the project now.
Set<String> cadIds(AgentToolbox b) => {for (final e in b.p.entities) e.id};

/// "12 items (3 × Zone pipe, …); ids a, b…" for a list of new items.
String cadMade(AgentToolbox b, Iterable<String> ids, {String verb = 'Added'}) {
  final list = ids.toList();
  if (list.isEmpty) return '$verb nothing.';
  final counts = <String, int>{};
  for (final id in list) {
    final e = b.p.byId(id);
    if (e == null) continue;
    final k = b.kindOf(e);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return '$verb ${list.length} items (${[for (final e in counts.entries) '${e.value} × ${e.key}'].join(', ')}); ids ${list.take(60).join(', ')}${list.length > 60 ? '…' : ''}.';
}

/// A number for the model (no scientific notation).
String cadN(double v, [int d = 2]) => v.isFinite ? fmt(v, d) : '-';

/// A point for the model.
String cadPt(Pt p) => AgentToolbox.pt(p);

/// The schema of an optional point with a description.
Map<String, Object?> pointWith(String description) => {...point, 'description': description};

/// The schema of a list of points with a description.
Map<String, Object?> pointsWith(String description, {int? minItems, int? maxItems}) => {...points, 'description': description, 'minItems': ?minItems, 'maxItems': ?maxItems};

/// The schema of a list of ids with a description.
Map<String, Object?> idsWith(String description, {int? maxItems}) => arr(str(), description, maxItems);

/// Today as `YYYY-MM-DD` (comments, revision clouds).
String cadToday() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The nozzle [id] of emitter [o] exactly (OutletSpec.nozzle falls back to
/// the first nozzle), or null.
NozzleSpec? exactNozzle(OutletSpec? o, String? id) => o?.nozzles.where((n) => n.id == id).firstOrNull;
