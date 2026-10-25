/// Shared helpers of the engineering operations of the AI assistant
/// (agent_ops_engineering.dart): the operation builder, the file sink the
/// exports write through, compact text tables, message codes translated
/// for the model and the checks every analysis starts with.
library;

import 'dart:async';
import 'dart:math' as math;

import '../../core/api.dart';
import '../actions.dart' show deliverExport;
import '../state/controller.dart';
import 'agent_tools.dart';

/// Where the engineering operations hand their files: the app's own
/// download helper (a browser download, the save dialog on the desktop),
/// as File → Export does. Tests replace it to read the files. The data is
/// a [String] (text) or a `Uint8List` (binary).
Future<void> Function(ProjectController c, String filename, String mime, Object data) engFileSink = (c, filename, mime, data) => deliverExport(c, filename, mime, () => data);

/// Builds an engineering operation: the approval summary is the i18n key
/// `ai.op.<name>` unless [summary] is given; [run] gets the checked input.
FnTool engOp(
  AgentToolbox b, {
  required String name,
  required String description,
  required Map<String, Object?> schema,
  ToolEffect effect = ToolEffect.read,
  ToolEffect Function(Map<String, dynamic> input)? effectFor,
  bool Function(Map<String, dynamic> input)? confirm,
  String Function(Map<String, dynamic> input)? summary,
  required Future<ToolOutput> Function(ToolArgs a, Map<String, dynamic> input) run,
}) => FnTool(
  name: name,
  description: description,
  inputSchema: schema,
  effect: effect,
  effectFor: effectFor,
  confirm: confirm,
  summary: summary ?? (_) => b.t('ai.op.$name'),
  handler: (i) => run(ToolArgs(i), i),
);

/// The approval summary [key] when it exists (it names the action of the
/// call), else [fallback].
String engSummary(AgentToolbox b, String key, String fallback, [Map<String, String>? args]) => b.t.has(key) ? b.t(key, args) : b.t(fallback, args);

/// The file name stem of the project ("Orchard_2026"), as the menus name files.
String engStem(ProjectController c) {
  final n = c.project.meta.name.trim();
  return (n.isEmpty ? c.t('name.newProject') : n).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
}

/// Refuses when the project has no design results.
void engNeedResults(ProjectController c) {
  if (c.results == null) throw ToolInputError('This needs design results: call run_design (or analyse_design) first.');
}

/// Refuses while a design runs.
void engNotBusy(ProjectController c) {
  if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
}

/// Runs [f] after giving the interface a frame (the analyses are long
/// synchronous computations).
Future<T> engSoon<T>(T Function() f) async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return f();
}

/// [v] with [d] decimals (no scientific notation).
String engN(double v, [int d = 2]) => v.isFinite ? fmt(v, d) : (v.isNaN ? '-' : (v > 0 ? '∞' : '-∞'));

/// A flow (m³/s) in m³/h.
String engQ(double m3s, [int d = 2]) => '${engN(m3s * 3600, d)} m³/h';

/// Hours and minutes of [hours] ("2:05").
String engHm(double hours) {
  final m = (hours * 60).round();
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

/// A compact table: a header line and one line per row, cells joined by
/// " | "; at most [max] rows (the rest counted).
String engTable(List<String> headers, List<List<Object?>> rows, {int max = 200}) {
  final out = StringBuffer(headers.join(' | '));
  for (final r in rows.take(max)) {
    out.write('\n${[for (final c in r) c is double ? engN(c) : '${c ?? '-'}'].join(' | ')}');
  }
  if (rows.length > max) out.write('\n(${rows.length - max} more rows)');
  return out.toString();
}

/// The engine message codes translated for the model, each line once
/// (`warn.<code>`, the item named by [name]); empty when there is none.
String engCodes(AgentToolbox b, Iterable<String> codes, {String Function(String id)? name, String title = 'Messages'}) {
  final lines = <String>{for (final w in codes) b.t.warning(w, entityName: name ?? b.c.entityName)};
  return lines.isEmpty ? '' : '\n$title: ${lines.join('; ')}';
}

/// A readable name of item [id]: its name (the zone of a valve); else its
/// kind and id, with the catalogue item of a pump or a device.
String engItemName(AgentToolbox b, String? id) {
  if (id == null || id.isEmpty) return '-';
  final e = b.p.byId(id);
  if (e == null) return id;
  if (e.name.isNotEmpty) return e.name;
  if (e is ControlValveEntity && e.zoneName.isNotEmpty) return e.zoneName;
  final spec = switch (e) {
    PumpEntity x => b.p.catalog.pump(x.pumpSpecId)?.name,
    MiscHydraulicEntity x => b.p.catalog.valve(x.valveSpecId)?.name,
    _ => null,
  };
  return '${b.kindOf(e)} $id${spec == null || spec.isEmpty ? '' : ' ($spec)'}';
}

/// Names for the ids of tables and messages: the zone of a valve or pivot,
/// an item by [engItemName], a link of the designer's network by its item.
String Function(String id) engNamer(AgentToolbox b, [Designer? d]) {
  final links = d == null ? const <String, GLink>{} : modelLinks(d);
  final p = b.p;
  return (id) {
    final e = p.byId(id);
    if (e is ControlValveEntity || e is PivotEntity) return demandName(p, id);
    if (e != null) return engItemName(b, id);
    final l = links[id];
    return l != null ? engItemName(b, l.entityId) : id;
  };
}

/// The system flow with the largest total flow in [r] (the worst case of
/// the analyses that look at one flow).
String engLargestFlow(List<SystemFlow> flows, DesignResults r) {
  var best = flows.first.id;
  var q = -1.0;
  for (final f in flows) {
    final x = r.systemFlows.where((s) => s.flowId == f.id).firstOrNull?.totalFlow ?? 0;
    if (x > q) {
      q = x;
      best = f.id;
    }
  }
  return best;
}

/// The system flow named by [ref] (id or name, case-insensitive) among
/// [flows], else the largest of [r].
SystemFlow engFlowOf(List<SystemFlow> flows, DesignResults r, String? ref) {
  if (flows.isEmpty) throw ToolInputError('The project has no system flow to analyse.');
  if (ref == null) return flows.firstWhere((f) => f.id == engLargestFlow(flows, r));
  final low = ref.toLowerCase();
  final f = flows.where((x) => x.id == ref || x.name.toLowerCase() == low).firstOrNull;
  if (f == null) throw ToolInputError('No system flow "$ref". Flows: ${flows.map((x) => '${x.id} (${x.name})').join(', ')}.');
  return f;
}

/// A list of numbers from [v] (an array of numbers), or null.
List<double>? engNumbers(Object? v, String what, {int? length, double? min, double? max}) {
  if (v == null) return null;
  if (v is! List || v.any((x) => x is! num || !x.isFinite)) throw ToolInputError('"$what" must be a list of numbers.');
  if (length != null && v.length != length) throw ToolInputError('"$what" needs $length numbers (got ${v.length}).');
  final out = [for (final x in v) (x as num).toDouble()];
  for (final x in out) {
    if ((min != null && x < min) || (max != null && x > max)) throw ToolInputError('"$what" has $x, outside ${min ?? '-∞'} … ${max ?? '∞'}.');
  }
  return out;
}

/// Pairs `[[a, b], …]` from [v], or null.
List<(double, double)>? engPairs(Object? v, String what, {int minItems = 1, int maxItems = 1000}) {
  if (v == null) return null;
  if (v is! List || v.length < minItems || v.length > maxItems) throw ToolInputError('"$what" must be a list of $minItems to $maxItems pairs [a, b].');
  return [
    for (var i = 0; i < v.length; i++)
      () {
        final r = v[i];
        if (r is! List || r.length < 2 || r[0] is! num || r[1] is! num) throw ToolInputError('"$what[$i]" must be a pair of numbers [a, b].');
        return ((r[0] as num).toDouble(), (r[1] as num).toDouble());
      }(),
  ];
}

/// Twelve monthly values, January first.
const engMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The largest of [v] (0 when empty).
double engMax(Iterable<double> v) => v.fold(0.0, math.max);

/// The schema of an array of [n] numbers.
Map<String, Object?> numbers(String description, {int? n}) => {
  'type': 'array',
  'items': {'type': 'number'},
  'description': description,
  'minItems': ?n,
  'maxItems': ?n,
};
