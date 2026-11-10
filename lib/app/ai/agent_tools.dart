/// The tools of the AI assistant: what the model can read in the open
/// project (this file), change (agent_tools_edit.dart) and run
/// (agent_tools_design.dart). Each is a thin wrapper over the controller and
/// the engine, so the model works with the program's own numbers and every
/// change is an ordinary undo step.
///
/// Conventions the descriptions tell the model: coordinates in metres with
/// x east and y north; entity properties in SI (m, m³/s, metres of head) as
/// in the project file; reports in the project's display units.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../core/ai/agent_loop.dart';
import '../../core/ai/project_context.dart';
import '../../core/design/advisor.dart';
import '../../core/design/auto_fix.dart' show addsBoosterToMains;
import '../../core/design/report_tables.dart';
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../i18n.dart';
import '../state/controller.dart';
import '../widgets/advice_panel.dart' show adviceTitle;
import 'agent_ops_cad.dart';
import 'agent_ops_engineering.dart';
import 'agent_tools_agent.dart';
import 'agent_tools_design.dart';
import 'agent_tools_edit.dart';
import 'agent_tools_manual.dart';
import 'agent_tools_ops.dart';
import 'agent_tools_site.dart';
import 'agent_tools_vision.dart';
import 'op_parts/mot.dart';
import 'op_parts/aut.dart';
import 'op_parts/agr.dart';
import 'op_parts/agb.dart';
import 'op_parts/fmt.dart';
import 'op_parts/mod.dart';
import 'op_parts/ia.dart';
import 'op_parts/cad.dart';
import 'op_parts/ui.dart';
import 'op_parts/sit.dart';
import 'op_parts/eng.dart';
import 'op_parts/prd.dart';
import 'op_parts/prb.dart';
import 'op_parts/scr.dart'; // 1.7.0 SCR
import 'op_parts/ply.dart';
import 'op_parts/dgz.dart';
import 'op_parts/fct.dart'; // 1.7.0 FCT
import 'view_snapshot.dart';
import 'vision_marks.dart' show ChangeTracker;

/// Deletions of more items than this are confirmed even when changes apply
/// automatically (the default of [AgentToolbox.largeDelete]).
const defaultLargeDelete = 20;

/// Shared state and helpers of the tools of one conversation.
class AgentToolbox {
  AgentToolbox(this.c, {this.snapshots, this.largeDelete = defaultLargeDelete, this.host, this.pictures = PictureLimits.standard});
  final ProjectController c;

  /// Pictures of the drawing and the base map (null where nothing can be
  /// rendered).
  final ViewSnapshots? snapshots;

  /// Deletions of more items than this are confirmed even when changes
  /// apply automatically.
  final int largeDelete;

  /// The assistant around the tools (the to-do list, questions, the plan,
  /// notes, attached files); the agent tools need it.
  final AgentHost? host;

  /// The largest picture the model in use reads as it is (set for each
  /// request by the assistant).
  PictureLimits pictures;

  /// The drawing before this task's changes and this round's, for the
  /// pictures that mark them.
  late final ChangeTracker changes = ChangeTracker(c);

  /// Items the assistant removed in this task so far, by every tool (the
  /// assistant counts them after each change): deleting more than
  /// [largeDelete] in a task is confirmed, however the deletions are split.
  int removedThisTask = 0;

  I18n get t => c.t;
  Project get p => c.project;
  Units get u => p.params.units;

  /// Every tool sent with each request, in a fixed order (the definitions
  /// are part of the cached prefix of every request of a conversation).
  late final List<AgentTool> tools = [
    ...readTools(this),
    ...editTools(this),
    ...designTools(this),
    ...visionTools(this),
    ...siteTools(this),
    if (host != null) ...agentTools(this, host!),
    ...manualTools(this),
    ...operationTools(this),
  ];

  /// The program's other operations (drawing edits, analyses, machines,
  /// sheets, settings…), not sent as tools: the model finds them with
  /// find_operations and runs them with run_operation, under the same
  /// permissions.
  /// (with those of 1.6.0, one list per area in lib/app/ai/op_parts)
  late final List<AgentTool> operations = [
    ...cadOperations(this),
    ...engineeringOperations(this),
    ...opsMot(this),
    ...opsAut(this),
    ...opsAgr(this),
    ...opsAgb(this),
    ...opsFmt(this),
    ...opsMod(this),
    ...opsIa(this),
    ...opsCad(this),
    ...opsUi(this),
    ...opsSit(this),
    ...opsEng(this),
    ...opsPrd(this),
    ...opsPrb(this),
    ...opsScr(this), // 1.7.0 SCR
    ...opsPly(this),
    ...opsDgz(this),
    ...opsFct(this),
  ];

  ContextSource source() => ContextSource(
    project: p,
    labels: c.exporter().labels,
    results: c.results,
    tables: c.reportTables(),
    advice: c.advice,
    adviceTitle: (a) => adviceTitle(c, a),
    selection: [...c.selection],
    siteLatLon: c.siteLatLon,
    kindOf: kindOf,
  );

  /// Translated kind of [e] ("Valve", "Zone pipe"…).
  String kindOf(Entity e) {
    final k = ProjectController.toolKeyOf(e);
    return t.has('tool.$k') ? t('tool.$k').split('/').first.trim() : k;
  }

  String nameOf(Entity e) => e.name.isNotEmpty ? e.name : (e is ControlValveEntity && e.zoneName.isNotEmpty ? e.zoneName : e.id);

  /// The entity with id [ref], else the one named so (or the valve of that
  /// zone); an error the model can act on otherwise.
  Entity find(String ref) {
    final r = ref.trim();
    final byId = p.byId(r);
    if (byId != null) return byId;
    final lower = r.toLowerCase();
    final named = [
      for (final e in p.entities)
        if (e.name.toLowerCase() == lower || (e is ControlValveEntity && e.zoneName.toLowerCase() == lower)) e,
    ];
    if (named.length == 1) return named.first;
    if (named.length > 1) throw ToolInputError('"$r" names ${named.length} items (ids ${named.take(10).map((e) => e.id).join(', ')}); use an id.');
    throw ToolInputError('No item "$r". Use list_entities to find ids.');
  }

  List<Entity> findAll(Iterable<String> refs) => [for (final r in refs) find(r)];

  Terrain? _terrain;
  int _terrainSeq = -1;
  Project? _terrainOf;

  /// The terrain model of the drawing, rebuilt after changes.
  Terrain get terrain {
    if (_terrain == null || _terrainSeq != c.editSeq || !identical(_terrainOf, p)) {
      _terrain = p.buildTerrain();
      _terrainSeq = c.editSeq;
      _terrainOf = p;
    }
    return _terrain!;
  }

  /// Runs [fn] as one undo step (folded with the rest of the turn by the
  /// assistant); refused while a design runs.
  R change<R extends Object>(String tool, R Function() fn, {bool invalidate = true}) {
    if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
    changes.beforeWrite();
    final r = c.mutate(fn, label: 'hist.aiTool|$tool', invalidateResults: invalidate);
    if (r == null) throw ToolInputError('The change was refused: a design is running.');
    return r;
  }

  static String n(double v, [int d = 2]) => fmt(v, d);
  static String pt(Pt q) => '[${fmt(q.x, 2)}, ${fmt(q.y, 2)}]';
  static String box(Bounds b) => b.isEmpty ? 'empty' : '[${fmt(b.minX, 1)}, ${fmt(b.minY, 1)}, ${fmt(b.maxX, 1)}, ${fmt(b.maxY, 1)}]';
  static String short(String s, int max) {
    final x = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x.length <= max ? x : '${x.substring(0, max - 1)}…';
  }

  static double lengthOf(List<Pt> pts) {
    var l = 0.0;
    for (var i = 1; i < pts.length; i++) {
      l += (pts[i] - pts[i - 1]).length;
    }
    return l;
  }

  static String m3h(double m3s) => '${fmt(m3s * 3600, 2)} m³/h';

  /// One line describing [e] for listings.
  String brief(Entity e) {
    final cat = p.catalog;
    String len(List<Pt> pts) => '${n(lengthOf(pts), 1)} m, ${pts.length} vertices, ${pt(pts.first)} → ${pt(pts.last)}';
    return switch (e) {
      PipeEntity x => '${x.scope.name}, ${x.pipeSpecId == null ? 'size by the design' : 'pipe ${x.pipeSpecId}${x.computerSized ? ' (the design may resize)' : ' (fixed)'}'}, ${len(x.points)}',
      SpraylineEntity x => 'emitter ${x.outletSpecId}/${x.nozzleId ?? '-'} every ${n(x.spacing)} m at ${n(x.headM, 1)} m head${x.pipeSpecId == null ? '' : ', pipe ${x.pipeSpecId}'}, ${len(x.points)}',
      TapeEntity x => 'tape ${x.tapeSpecId}, inlet ${n(x.inletHeadM, 1)} m, ${len(x.points)}',
      OutletEntity x =>
        'at ${pt(x.position)}, ${x.outletSpecId}/${x.nozzleId ?? '-'} at ${n(x.headM, 1)} m, arc ${n(x.arcDeg, 0)}° from ${n(x.orientationDeg, 0)}°, ${x.scope.name}${x.zoneName.isEmpty ? '' : ', zone "${x.zoneName}"'}',
      ControlValveEntity x => 'at ${pt(x.position)}, valve ${x.valveSpecId ?? 'none (no valve loss counted; optimize_design picks one)'}, zone "${x.zoneName}"',
      WaterSupplyEntity x =>
        'at ${pt(x.position)}, ${x.calculatePressure ? 'pressure calculated by the design' : 'head ${n(x.designHeadM, 1)} m'}${x.maxHeadM > 0 ? ', max ${n(x.maxHeadM, 1)} m' : ''}${x.designFlow > 0 ? ', design flow ${m3h(x.designFlow)}' : ''}${x.maxFlow > 0 ? ', max ${m3h(x.maxFlow)}' : ''}',
      PumpEntity x => 'at ${pt(x.position)}, pump ${x.pumpSpecId ?? '-'}, ${x.scope.name}${x.speedRatio != 1 ? ', speed ${n(x.speedRatio)}' : ''}',
      MiscHydraulicEntity x => 'at ${pt(x.position)}, device ${x.valveSpecId ?? '-'} (${cat.valve(x.valveSpecId)?.kind.name ?? '?'}), ${x.scope.name}',
      JunctionEntity x => 'at ${pt(x.position)}, ${x.scope.name}',
      PivotEntity x => '${x.kind.name}, centre ${pt(x.center)}, ${x.kind == PivotKind.linear ? 'length' : 'radius'} ${n(x.radiusM, 1)} m${x.sectorDeg < 360 ? ', sector ${n(x.sectorDeg, 0)}°' : ''}',
      // 1.6.0 MOD: the irrigated surface, the islands left out
      AreaEntity x =>
        '${x.points.length} vertices, ${n(x.area / 1e4, 4)} ha${x.holes.isEmpty ? '' : ' irrigated (${x.holes.length} islands left out)'}${x.crop.isEmpty ? '' : ', crop "${x.crop}"'}${x.cropKey.isEmpty ? '' : ' (${x.cropKey})'}, bounds ${box(x.bounds)}',
      ContourEntity x => 'z ${n(x.elevation, 2)} m, ${x.points.length} vertices${x.derived ? ' (generated)' : ''}',
      SpotHeightEntity x => 'at ${pt(x.position)}, z ${n(x.elevation, 2)} m',
      TextEntity x => 'at ${pt(x.position)}, "${short(x.text, 60)}"',
      SymbolEntity x => '${x.kind.name} at ${pt(x.position)}',
      ControllerEntity x => 'at ${pt(x.position)}, ${x.stations} stations',
      _ => 'bounds ${box(e.bounds)}',
    };
  }
}

// ---------------------------------------------------------------- schemas

Map<String, Object?> obj(Map<String, Object?> props, {List<String> required = const []}) => {
  'type': 'object',
  'properties': props,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};
Map<String, Object?> str([String? description, List<String>? options]) => {'type': 'string', 'description': ?description, 'enum': ?options};
Map<String, Object?> num_([String? description]) => {'type': 'number', 'description': ?description};
Map<String, Object?> int_([String? description]) => {'type': 'integer', 'description': ?description};
Map<String, Object?> bool_([String? description]) => {'type': 'boolean', 'description': ?description};
Map<String, Object?> arr(Map<String, Object?> items, [String? description, int? maxItems]) => {'type': 'array', 'items': items, 'description': ?description, 'maxItems': ?maxItems};
final Map<String, Object?> point = {
  'type': 'array',
  'items': {'type': 'number'},
  'description': '[x, y] in metres',
};
final Map<String, Object?> points = {'type': 'array', 'items': point, 'description': '[[x, y], …] in metres'};
final Map<String, Object?> bbox = {
  'type': 'array',
  'items': {'type': 'number'},
  'description': '[minX, minY, maxX, maxY] in metres',
};

Bounds bboxOf(Object? v) {
  if (v is List && v.length == 4 && v.every((x) => x is num && x.isFinite)) {
    final a = [for (final x in v) (x as num).toDouble()];
    return Bounds(math.min(a[0], a[2]), math.min(a[1], a[3]), math.max(a[0], a[2]), math.max(a[1], a[3]));
  }
  throw ToolInputError('"bbox" must be [minX, minY, maxX, maxY] in metres.');
}

// ---------------------------------------------------------------- read tools

List<AgentTool> readTools(AgentToolbox b) {
  final c = b.c;
  return [
    FnTool(
      name: 'get_project_summary',
      description: 'Overview of the open project as the program computed it, in the project\'s display units: details, units and georeference; what the drawing holds; the selection; system flows; design results (zones with flow, pressures against their window and uniformity, the supply duty of each system flow, pumps, pivots, flagged pipes); design-check and assistant messages with why and how; costs and materials; design parameters; the catalogue items in use. Use it at the start of a task and after large changes; "parts" narrows it, and each part is trimmed to fit (about 15 000 characters in all). Read-only.',
      inputSchema: obj({
        'parts': arr(str(null, [for (final p in ContextPart.values) p.name]), 'Sections to include (all when omitted).'),
      }),
      summary: (_) => b.t('ai.tool.summary'),
      handler: (i) async {
        final names = ToolArgs(i).strings('parts');
        final parts = names.isEmpty ? {...ContextPart.values} : {for (final n in names) ContextPart.values.byName(n)};
        final ctx = buildProjectContext(b.source(), parts: parts, maxChars: 15000);
        return ToolOutput(ctx.isEmpty ? 'The project is empty.' : ctx.text);
      },
    ),
    FnTool(
      name: 'list_entities',
      description: 'Lists items of the drawing, one line each: id | type (translated kind) | name | layer | main properties (catalogue ids, positions or first → last vertex, length, pressures set). Filters combine (all must hold). Use it to find ids and coordinates before get_entity, update_entities or drawing something that must join an existing item. Coordinates in metres (x east, y north). Pages of up to 200 lines; the first line says how many match and the next offset. Read-only.',
      inputSchema: obj({
        'types': arr(str(null, [for (final t in EntityType.values) t.name]), 'Entity types to list (all when omitted).'),
        'scope': str('Hydraulic scope ("zone" also takes spraylines and tapes; valves have none).', ['zone', 'mainline']),
        'layer': str('Layer name, exact.'),
        'zone': str('Zone name: its valve and outlets and, after a design, its pipes and laterals.'),
        'name': str('Text the name must contain (case-insensitive).'),
        'bbox': {...bbox, 'description': '[minX, minY, maxX, maxY] in metres: items whose bounds meet it.'},
        'selected_only': bool_('Only the items the user selected.'),
        'offset': int_('Skip this many matches (paging, default 0).'),
        'limit': int_('Lines, 1–200 (default 60).'),
      }),
      summary: (_) => b.t('ai.tool.list'),
      handler: (i) async {
        final a = ToolArgs(i);
        final types = a.strings('types').toSet();
        final scope = a.str('scope');
        final layer = a.str('layer');
        final zone = a.str('zone')?.toLowerCase();
        final name = a.str('name')?.toLowerCase();
        final box = a.has('bbox') ? bboxOf(i['bbox']) : null;
        final offset = a.integer('offset', min: 0) ?? 0;
        final limit = a.integer('limit', min: 1, max: 200) ?? 60;
        final selected = a.flag('selected_only') ?? false;
        Set<String>? inZone;
        if (zone != null) {
          inZone = {};
          for (final e in b.p.entities) {
            final name = switch (e) {
              ControlValveEntity v => v.zoneName,
              OutletEntity o => o.zoneName,
              PivotEntity p => p.zoneName,
              _ => null,
            };
            if (name?.toLowerCase() == zone) inZone.add(e.id);
          }
          for (final z in c.results?.zones.values ?? const <ZoneResult>[]) {
            if (z.zoneName.toLowerCase() != zone) continue;
            inZone
              ..add(z.valveId)
              ..addAll(z.pipes.map((x) => x.entityId))
              ..addAll(z.outlets.map((x) => x.entityId));
          }
        }
        final hits = [
          for (final e in b.p.entities)
            if ((types.isEmpty || types.contains(e.type.name)) &&
                (scope == null || e.hydraulicScope?.name == scope) &&
                (layer == null || e.layer == layer) &&
                (inZone == null || inZone.contains(e.id)) &&
                (name == null || e.name.toLowerCase().contains(name)) &&
                (box == null || e.bounds.intersects(box)) &&
                (!selected || c.selection.contains(e.id)))
              e,
        ];
        if (hits.isEmpty) return const ToolOutput('No items match.');
        final page = hits.skip(offset).take(limit).toList();
        final out = StringBuffer(
          '${hits.length} items match${hits.length > page.length ? '; ${offset + 1}–${offset + page.length} shown (next: offset ${offset + page.length})' : ''}.\nid | kind | name | layer | details\n',
        );
        for (final e in page) {
          out.writeln('${e.id} | ${e.type.name} (${b.kindOf(e)}) | ${AgentToolbox.short(e.name, 40)} | ${e.layer} | ${b.brief(e)}');
        }
        return ToolOutput(out.toString());
      },
    ),
    FnTool(
      name: 'get_entity',
      description: 'One item by id or name (a zone name finds its valve): the report rows that mention it (after a design: flows, pressures, sizes), its stored keys as JSON in SI units (the keys update_entities takes), its vertices (the first 400) with length and area, or its position, and its bounds. Read an item before updating it. Fails with the matching ids when a name is ambiguous. Read-only.',
      inputSchema: obj({'id': str('Id or name of the item.')}, required: ['id']),
      summary: (i) => b.t('ai.tool.entity', {'n': '${i['id']}'}),
      handler: (i) async {
        final e = b.find(ToolArgs(i).str('id', required: true)!);
        final s = b.source();
        final out = <String>[...itemLines(s, e, maxRows: 40), '${b.t('ai.ctx.props')}: ${jsonEncode(entityJson(e))}'];
        final pts = e.linearPoints;
        if (pts != null) {
          out.add(
            'Vertices (${pts.length}${pts.length > 400 ? ', first 400' : ''}): ${jsonEncode([
              for (final q in pts.take(400)) [roundTo(q.x, 2), roundTo(q.y, 2)],
            ])}',
          );
          out.add('Length ${AgentToolbox.n(AgentToolbox.lengthOf(pts), 2)} m');
          if (e.isClosedShape) out.add('Area ${AgentToolbox.n(polygonArea(pts).abs(), 1)} m² (${AgentToolbox.n(polygonArea(pts).abs() / 1e4, 4)} ha)');
        } else if (e is PointEntity) {
          out.add('Position ${AgentToolbox.pt(e.position)}');
        }
        out.add('Bounds ${AgentToolbox.box(e.bounds)}');
        return ToolOutput(out.join('\n'));
      },
    ),
    FnTool(
      name: 'get_parameters',
      description: 'The design parameters with their current values, units, allowed ranges and what each does: friction and local losses, velocity limits, sizing method and telescoping, zone pressure variation, connection tolerance, terrain model, flushing, surge, fittings, wiring, economics. set_parameters takes the same names. Read-only.',
      inputSchema: obj({}),
      summary: (_) => b.t('ai.tool.params'),
      handler: (_) async => ToolOutput(parametersText(b)),
    ),
    FnTool(
      name: 'search_catalog',
      description: 'Searches the project catalogue and returns a table with the ids other tools take: pipes (inner Ø, class in metres of head, material, C, price, usage), emitters (kind and every nozzle: flow at its default pressure, pressure range, wetted radius, arc, PC), tapes (Ø, emitter spacing and flow, pressure range), valves and in-line devices (kind, size, flow range, loss), pumps (curve points in m³/h and m, efficiency, power, submersible), fittings and wires. Disabled items are hidden unless include_disabled; the design never uses them. Prices are in the project currency. Read-only.',
      inputSchema: obj(
        {
          'kind': str('Item kind ("valve" also lists filters, meters, PRVs and the other in-line devices).', ['pipe', 'emitter', 'tape', 'valve', 'pump', 'fitting', 'wire']),
          'query': str('Text in the id, name, supplier or code (case-insensitive).'),
          'usage': str('Pipes for this use only.', ['lateral', 'zone', 'mainline']),
          'include_disabled': bool_('Also list disabled items (default false).'),
          'limit': int_('Rows, 1–100 (default 40).'),
        },
        required: ['kind'],
      ),
      summary: (i) => b.t('ai.tool.catalog', {'n': '${i['kind']}'}),
      handler: (i) async => ToolOutput(catalogText(b, ToolArgs(i))),
    ),
    FnTool(
      name: 'get_report_table',
      description:
          'Reads one report table exactly as the reports panel shows it, in the project\'s display units; ⚠ marks the rows the program highlights (out of window, over the limit). Keys: ${reportTableKeys.join(', ')} (read_manual "reports" says what each holds). Tables of hydraulic results exist only after a design; an unknown or absent key fails with the keys available now. Read-only.',
      inputSchema: obj(
        {
          'table': str('Table key.'),
          'filter': str('Only rows with a cell containing this text (case-insensitive), e.g. a zone or pipe name.'),
          'offset': int_('Skip this many rows (paging, default 0).'),
          'limit': int_('Rows, 1–300 (default 100).'),
        },
        required: ['table'],
      ),
      summary: (i) => b.t('ai.tool.table', {'n': '${i['table']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final key = a.str('table', required: true)!;
        final tables = c.reportTables();
        final tb = tables.where((x) => x.key == key).firstOrNull;
        if (tb == null) {
          throw ToolInputError(
            'No table "$key" now. Available: ${tables.map((x) => x.key).join(', ')}${c.results == null ? ' (the design has not been run: run_design gives the hydraulic tables)' : ''}.',
          );
        }
        return ToolOutput(pagedTable(tb, filter: a.str('filter'), offset: a.integer('offset', min: 0) ?? 0, limit: a.integer('limit', min: 1, max: 300) ?? 100));
      },
    ),
    FnTool(
      name: 'get_design_messages',
      description: 'The design check and design-assistant messages, errors first: number (#), severity, code, title, the items involved, why it matters and how to solve it (once per code), and the automatic corrections offered (apply_fix takes the number, the code and the correction; auto_fix applies all the safe ones). Without design results only drawing and settings problems appear; pressures and flows are checked after run_design. At most 80 listed. read_manual "messages" explains every code. Read-only.',
      inputSchema: obj({}),
      summary: (_) => b.t('ai.tool.messages'),
      handler: (_) async => ToolOutput(messagesText(b)),
    ),
    FnTool(
      name: 'get_elevations',
      description: 'Ground elevation (m) at points from the terrain model the design uses (contours, spot heights, breaklines and downloaded elevation points, interpolated by terrainMethod). Without terrain data it says so: every elevation is then 0 m. Read-only.',
      inputSchema: obj(
        {
          'points': {...points, 'maxItems': 500, 'description': '[[x, y], …] in metres, 1 to 500.'},
        },
        required: ['points'],
      ),
      summary: (i) => b.t('ai.tool.elevations', {'n': '${(i['points'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        final pts = ToolArgs(i).points('points', max: 500, required: true)!;
        final tr = b.terrain;
        if (tr.isEmpty) return ToolOutput(noTerrainText(b));
        return ToolOutput([for (final q in pts) '${AgentToolbox.pt(q)} → ${AgentToolbox.n(tr.elevationAt(q), 2)} m'].join('\n'));
      },
    ),
    FnTool(
      name: 'measure',
      description: 'Length and bounds of a polyline given as points in metres and, when closed, its perimeter, area (m² and ha) and centroid. Read-only.',
      inputSchema: obj(
        {
          'points': {...points, 'description': '[[x, y], …] in metres, at least 2.'},
          'closed': bool_('Treat the points as a polygon (needs 3).'),
        },
        required: ['points'],
      ),
      summary: (_) => b.t('ai.tool.measure'),
      handler: (i) async {
        final a = ToolArgs(i);
        final pts = a.points('points', min: 2, required: true)!;
        final closed = a.flag('closed') ?? false;
        final out = <String>['Length ${AgentToolbox.n(AgentToolbox.lengthOf(pts), 2)} m', 'Bounds ${AgentToolbox.box(Bounds.ofPoints(pts))}'];
        if (closed && pts.length >= 3) {
          final area = polygonArea(pts).abs();
          out
            ..add('Perimeter ${AgentToolbox.n(AgentToolbox.lengthOf([...pts, pts.first]), 2)} m')
            ..add('Area ${AgentToolbox.n(area, 1)} m² = ${AgentToolbox.n(area / 1e4, 4)} ha')
            ..add('Centroid ${AgentToolbox.pt(polygonCentroid(pts))}');
        }
        return ToolOutput(out.join('\n'));
      },
    ),
  ];
}

/// What get_elevations answers without terrain data, with the next step.
String noTerrainText(AgentToolbox b) =>
    'The drawing has no terrain data (no contours, spot heights, breaklines or downloaded elevations): every elevation is taken as 0 m. Next: ${b.p.meta.georef == null ? 'set_site (the project has no georeference yet), then download_terrain' : 'download_terrain'} adds online elevations; import_attachment takes the user\'s survey; or create spot heights the user gives (create_entities type "spot").';

/// The next step when the catalogue has no usable item of [kind] (a
/// search_catalog kind; null: the kind of the item in question): a
/// disabled one, a manufacturer's pack, a data sheet or the program's own
/// catalogue.
String catalogNextStep([String? kind]) =>
    'Next: search_catalog {${kind == null ? 'kind' : 'kind "$kind"'}, include_disabled true} shows disabled items (edit_catalog action "enable" brings one back); run_operation list_catalog_packs, then add_catalog_pack, adds a manufacturer\'s models; edit_catalog action "add" adds one from a data sheet; run_operation catalog_default {action "factory"} puts the program\'s own catalogue back ({action "load"}: the user\'s saved default).';

/// Stored properties of [e] without its id, type, image data and photo.
Map<String, Object?> entityJson(Entity e) {
  final j = Map<String, Object?>.of(e.toJson())..remove('data');
  if (j['photo'] is String) j['photo'] = photoNote(j['photo'] as String);
  if (j['pts'] is List && (j['pts'] as List).length > 400) j['pts'] = '${(j['pts'] as List).length} vertices (see Vertices)';
  return j;
}

/// Keys of the report tables get_report_table reads (a test keeps the list
/// in step with `buildReportTables`).
const reportTableKeys = [
  'zones',
  'pipes',
  'outlets',
  'mainline',
  'devices',
  // 1.6.0 MOT
  'stations',
  'operation',
  'vih',
  'flushing',
  'surge',
  'bom',
  'bomZones',
  'proposal',
  'trench',
  'works',
  'electrical',
  'pivots',
  'pivotSpans',
  'pivotPackage',
  'pivotPackageSummary',
  'pivotTimer',
  'cornerArm',
  'vri',
  'pivotElectrical',
  'crop',
  'schedule',
  'requirement',
  'requirementTotals',
  'water',
  'licensing',
  // 1.6.0 SIT
  'sources',
  'scenarios',
  'comments',
  'revisions',
  'scorecard', // 1.7.0 SCR
  'messages',
];

/// Rows [offset]… of [tb] matching [filter].
String pagedTable(ReportTable tb, {String? filter, int offset = 0, int limit = 100}) {
  final f = filter?.toLowerCase();
  final idx = [
    for (var i = 0; i < tb.rows.length; i++)
      if (f == null || tb.rows[i].any((x) => cellText(x).toLowerCase().contains(f))) i,
  ];
  if (idx.isEmpty) return 'Table "${tb.title}" (${tb.key}): no rows${f == null ? '' : ' containing "$filter"'}.';
  final page = idx.skip(offset).take(limit).toList();
  final out = StringBuffer('### ${tb.title} (${tb.key}): rows ${page.isEmpty ? 0 : offset + 1}–${offset + page.length} of ${idx.length}${f == null ? '' : ' matching "$filter"'}\n');
  out.writeln(tb.headers.join(' | '));
  for (final i in page) {
    out.writeln('${tb.warn[i] ? '⚠ ' : ''}${[for (final x in tb.rows[i]) cellText(x)].join(' | ')}');
  }
  if (offset + page.length < idx.length) out.writeln('(more: offset ${offset + page.length})');
  return out.toString();
}

String messagesText(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  final adv = c.advice;
  if (adv.isEmpty) return c.results == null ? t('adv.noneYet') : t('adv.none');
  final out = StringBuffer();
  int count(AdviceLevel l) => adv.where((a) => a.level == l).length;
  out.writeln(
    '${adv.length} messages: ${count(AdviceLevel.error)} errors, ${count(AdviceLevel.warning)} warnings, ${count(AdviceLevel.info)} notes. ${c.results == null ? 'No design results yet: pressures and flows are not checked until run_design.' : 'Design results present.'}',
  );
  final explained = <String>{};
  for (var i = 0; i < adv.length && i < 80; i++) {
    final a = adv[i];
    out.writeln('#$i ${a.level.name} [${a.code}] ${adviceTitle(c, a)}${a.entityIds.isEmpty ? '' : ' — items ${a.entityIds.take(12).join(', ')}${a.entityIds.length > 12 ? '…' : ''}'}');
    if (explained.add(a.code)) {
      if (t.has('adv.${a.code}.why')) out.writeln('   why: ${t('adv.${a.code}.why')}');
      if (t.has('adv.${a.code}.how')) out.writeln('   how: ${t('adv.${a.code}.how')}');
    }
    if (a.fixes.isNotEmpty) {
      final booster = a.fixes.contains(FixKind.choosePump) && addsBoosterToMains(b.p, a, FixKind.choosePump, c.results);
      out.writeln('   corrections: ${a.fixes.map((k) => k.name).join(', ')}${booster ? ' (choosePump adds a booster pump to the mains connection: ask the user first)' : ''}');
    }
  }
  if (adv.length > 80) out.writeln('(${adv.length - 80} more)');
  return out.toString();
}

String catalogText(AgentToolbox b, ToolArgs a) {
  final cat = b.p.catalog;
  final kind = a.str('kind', required: true)!;
  final q = a.str('query')?.toLowerCase();
  final usage = a.str('usage');
  final all = a.flag('include_disabled') ?? false;
  final limit = a.integer('limit', min: 1, max: 100) ?? 40;
  bool hit(String id, String name, String sup, String code, bool enabled) => (all || enabled) && (q == null || '$id $name $sup $code'.toLowerCase().contains(q));
  String n(double v, [int d = 2]) => fmt(v, d);
  final rows = <String>[];
  switch (kind) {
    case 'pipe':
      rows.add('id | name | inner Ø mm | nominal mm | rating m | material | C | cost/m | usage | enabled');
      for (final x in cat.pipes) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled) || (usage != null && !x.usage.any((u) => u.name == usage))) continue;
        rows.add(
          '${x.id} | ${x.name} | ${n(x.innerDiameterMm, 1)} | ${n(x.nominalMm, 0)} | ${n(x.pressureRatingM, 0)} | ${x.material.name} | ${n(x.hazenC, 0)} | ${n(x.costPerM)} | ${x.usage.map((u) => u.name).join('+')} | ${x.enabled}',
        );
      }
    case 'emitter':
      rows.add('id | name | kind | cost | nozzles (id: flow at default head, head range, wetted radius, arc)');
      for (final o in cat.outlets) {
        if (!hit(o.id, o.name, o.supplier, o.code, o.enabled)) continue;
        final nz = [
          for (final z in o.nozzles)
            '${z.id}: ${n(z.curve.flow(z.defaultHeadM) * 3.6e6, 1)} L/h at ${n(z.defaultHeadM, 1)} m (${n(z.minHeadM, 0)}–${n(z.maxHeadM, 0)} m)${z.curve.radius(z.defaultHeadM) > 0 ? ', r ${n(z.curve.radius(z.defaultHeadM), 1)} m' : ''}${z.arcDeg < 360 ? ', ${n(z.arcDeg, 0)}°' : ''}${z.curve.isPressureCompensating ? ', PC' : ''}',
        ];
        rows.add('${o.id} | ${o.name} | ${o.kind.name} | ${n(o.cost)} | ${nz.join('; ')}');
      }
    case 'tape':
      rows.add('id | name | inner Ø mm | emitter spacing m | emitter flow L/h at inlet head | head range m | rating m | cost/m');
      for (final x in cat.tapes) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled)) continue;
        rows.add(
          '${x.id} | ${x.name} | ${n(x.innerDiameterMm, 1)} | ${n(x.emitterSpacingM)} | ${n(x.emitter.flow(x.defaultInletHeadM) * 3.6e6, 2)} at ${n(x.defaultInletHeadM, 1)} m${x.emitter.isPressureCompensating ? ' (PC)' : ''} | ${n(x.minHeadM, 0)}–${n(x.maxHeadM, 0)} | ${n(x.pressureRatingM, 0)} | ${n(x.costPerM)}',
        );
      }
    case 'valve':
      rows.add('id | name | kind | size mm | flow range m³/h | loss at max flow m | cost');
      for (final x in cat.valves) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled)) continue;
        rows.add('${x.id} | ${x.name} | ${x.kind.name} | ${n(x.sizeMm, 0)} | ${n(x.minFlow * 3600, 1)}–${n(x.maxFlow * 3600, 1)} | ${n(x.loss.loss(x.maxFlow), 2)} | ${n(x.cost)}');
      }
    case 'pump':
      rows.add('id | name | curve (m³/h, m) | efficiency | kW | submersible | flow range m³/h | cost');
      for (final x in cat.pumps) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled)) continue;
        rows.add(
          '${x.id} | ${x.name} | ${[for (final (q, h) in x.points) '(${n(q * 3600, 1)}, ${n(h, 1)})'].join(' ')} | ${n(x.efficiency)} | ${x.powerKw > 0 ? n(x.powerKw, 1) : '-'} | ${x.submersible} | ${n(x.minFlow * 3600, 1)}–${n(x.maxFlow * 3600, 1)} | ${n(x.cost)}',
        );
      }
    case 'fitting':
      rows.add('id | name | kind | size mm | cost');
      for (final x in cat.fittings) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled)) continue;
        rows.add('${x.id} | ${x.name} | ${x.kind.name} | ${n(x.sizeMm, 0)}${x.size2Mm > 0 ? '×${n(x.size2Mm, 0)}' : ''} | ${n(x.cost)}');
      }
    case 'wire':
      rows.add('id | name | section mm² | Ω/km | cost/m');
      for (final x in cat.wires) {
        if (!hit(x.id, x.name, x.supplier, x.code, x.enabled)) continue;
        rows.add('${x.id} | ${x.name} | ${n(x.sectionMm2, 1)} | ${n(x.ohmPerKm, 2)} | ${n(x.costPerM)}');
      }
  }
  if (rows.length <= 1) return 'No $kind matches.';
  final total = rows.length - 1;
  final shown = rows.take(limit + 1).join('\n');
  return total > limit ? '$shown\n($total matches, $limit shown: refine the query)' : shown;
}
