import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart' show loadExampleAction;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_coverage.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart' show engFileSink;
import 'package:opencadirrigation/app/examples.dart' show ExampleId;
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/widgets/dialogs/basemap_dialogs.dart' show osmTilePolicyUrl;
import 'package:opencadirrigation/app/widgets/dialogs/more_dialogs.dart' show hasSavedDefaultCatalog;
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The operations that wave 1 of 1.6.0 left without a way for the
/// assistant (lib/app/ai/op_parts/ia.dart, and the options added to the
/// engineering operations): the geometry edits of the drawing, Save as copy
/// and the browser storage, the terms of the base maps and the street map
/// server, the default catalogue's separate actions, the site climate with
/// the humidity and wind of the Kc adjustment and from the normals of a
/// station, the programme month, the corner arm's throw, the gated pipe with
/// fixed holes, and the automatic layout that keeps to the hydrozones and
/// to the lot.
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
  Future<List<String>?> ask(List<AiQuestion> questions) async => [for (final _ in questions) ''];
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => const PlanDecision.approved(AgentPermission.auto);
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

const _ops = [
  'stretch_entities',
  'fillet_corner',
  'chamfer_corner',
  'break_entity',
  'join_entities',
  'explode_entities',
  'convert_to_area',
  'save_as_copy',
  'browser_storage',
  'download_stored_projects',
  'persist_storage',
  'base_map_terms',
  'eto_from_station_normals',
];

void main() {
  late ProjectController c;
  late AgentToolbox box;
  final files = <String, Object>{};
  final saveFiles = engFileSink;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    box = AgentToolbox(c, host: _Host());
    files.clear();
    engFileSink = (c, name, mime, data) async => files[name] = data;
  });
  tearDown(() => engFileSink = saveFiles);

  AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);

  Future<ToolOutput> call(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final tool = [...box.tools, ...box.operations].firstWhere((t) => t.name == name);
    Object? error;
    ToolOutput? out;
    await tester.runAsync(() async {
      try {
        out = await tool.run(input);
      } catch (e) {
        error = e;
      }
    });
    if (error != null) throw error!;
    return out!;
  }

  Future<String> fails(WidgetTester tester, String name, Map<String, dynamic> input) async {
    try {
      final out = await call(tester, name, input);
      if (out.isError) return out.text;
    } on ToolInputError catch (e) {
      return e.message;
    }
    fail('$name accepted $input');
  }

  T add<T extends Entity>(T e) {
    c.project.entities.add(e);
    c.entitiesChanged();
    return e;
  }

  String id() => c.project.newId();

  List<double> m12(double v) => List<double>.filled(12, v);

  testWidgets('the operations of wave 1: described, their approval lines translated, their effects and confirmations, every pending route given one', (tester) async {
    for (final n in _ops) {
      final o = op(n);
      expect(o.description.length, greaterThan(100), reason: n);
      expect(o.inputSchema['type'], 'object', reason: n);
      expect(box.t.has('ai.op.$n'), isTrue, reason: n);
      expect(
        o.describe(const {
          'ids': ['a', 'b'],
          'id': 'x',
        }),
        isNot(startsWith('ai.op.')),
        reason: n,
      );
    }
    for (final n in ['stretch_entities', 'fillet_corner', 'chamfer_corner', 'break_entity', 'join_entities', 'explode_entities', 'convert_to_area']) {
      expect(op(n).effectOf(const {}), ToolEffect.write, reason: n);
      expect(op(n).mustConfirm(const {}), isFalse, reason: n);
    }
    expect(op('save_as_copy').effectOf(const {}), ToolEffect.export);
    expect(op('save_as_copy').mustConfirm(const {}), isTrue);
    expect(op('download_stored_projects').mustConfirm(const {}), isTrue);
    expect(op('persist_storage').effectOf(const {}), ToolEffect.write);
    expect(op('persist_storage').mustConfirm(const {}), isTrue, reason: 'a choice about the user\'s browser');
    expect(op('browser_storage').effectOf(const {}), ToolEffect.read);
    expect(op('base_map_terms').effectOf(const {}), ToolEffect.read);
    expect(op('eto_from_station_normals').effectOf(const {}), ToolEffect.read);
    expect(op('eto_from_station_normals').effectOf(const {'apply': true}), ToolEffect.write);
    // through run_operation, as the model reaches them
    final runOp = box.tools.firstWhere((t) => t.name == 'run_operation');
    expect(runOp.effectOf(const {'name': 'save_as_copy', 'input': <String, dynamic>{}}), ToolEffect.export);
    expect(runOp.mustConfirm(const {'name': 'persist_storage', 'input': <String, dynamic>{}}), isTrue);
    expect(runOp.effectOf(const {'name': 'browser_storage', 'input': <String, dynamic>{}}), ToolEffect.read);
    // the coverage entries that waited for them route to them now
    final routes = {
      for (final v in aiCoverage.values)
        if (v.startsWith('op:')) v.substring(3),
    };
    for (final n in _ops) {
      expect(routes, contains(n), reason: 'a function routes to $n');
    }
    expect(aiCoverage.values.where((v) => v.contains('pending-ai')), isEmpty);
    expect(aiCoverage['menu:basemap.osm.menu'], 'setting:view.streets_tile_url');
    expect(aiCoverage['dialog:more_dialogs.catalogEditor.loadDefault'], 'op:catalog_default');
  });

  testWidgets('geometry edits: stretch, fillet, chamfer, break at two points, join, explode and outlines into areas, each one undo step', (tester) async {
    // stretch: the vertices inside the window move, those outside stay; a line wholly inside moves whole
    final poly = add(PolylineEntity(id: id(), points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]));
    final inside = add(LineEntity(id: id(), a: const Pt(9, 4), b: const Pt(11, 6)));
    final away = add(LineEntity(id: id(), a: const Pt(50, 50), b: const Pt(60, 50)));
    c.select([away.id]);
    final s = await call(tester, 'stretch_entities', {
      'bbox': [8, -1, 12, 11],
      'dx': 5,
      'dy': 0,
    });
    expect(s.text, contains('Stretched 2 items'));
    final stretched = (c.project.byId(poly.id)! as PolylineEntity).points;
    expect(stretched[0].distanceTo(Pt.zero), lessThan(1e-9));
    expect(stretched[1].distanceTo(const Pt(15, 0)), lessThan(1e-9));
    expect(stretched[2].distanceTo(const Pt(15, 10)), lessThan(1e-9));
    expect((c.project.byId(inside.id)! as LineEntity).a.distanceTo(const Pt(14, 4)), lessThan(1e-9));
    expect(identical(c.project.byId(away.id), away), isTrue);
    expect(c.selection, {away.id}, reason: 'the user\'s selection comes back');
    c.undo();
    expect((c.project.byId(poly.id)! as PolylineEntity).points[1].distanceTo(const Pt(10, 0)), lessThan(1e-9));
    // "ids" limit it as a selection does for the tool
    final only = await call(tester, 'stretch_entities', {
      'bbox': [8, -1, 12, 11],
      'dx': 0,
      'dy': 3,
      'ids': [inside.id],
    });
    expect(only.text, contains('Stretched 1 item'));
    expect((c.project.byId(poly.id)! as PolylineEntity).points[1].distanceTo(const Pt(10, 0)), lessThan(1e-9));
    expect(
      await fails(tester, 'stretch_entities', {
        'bbox': [100, 100, 110, 110],
        'dx': 1,
        'dy': 0,
      }),
      contains('Nothing stretched'),
    );
    // fillet: the corner of one polyline becomes an arc 4 m from it on both sides (a right angle: T = R)
    final corner = add(PolylineEntity(id: id(), points: [const Pt(0, 100), const Pt(20, 100), const Pt(20, 120)]));
    final f = await call(tester, 'fillet_corner', {
      'id': corner.id,
      'at': [10, 100],
      'other_at': [20, 110],
      'radius_m': 4,
    });
    expect(f.text, contains('Rounded the corner'));
    final rounded = (c.project.byId(corner.id)! as PolylineEntity).points;
    expect(rounded.length, greaterThan(3));
    expect(rounded.first.distanceTo(const Pt(0, 100)), lessThan(1e-9));
    expect(rounded.last.distanceTo(const Pt(20, 120)), lessThan(1e-9));
    expect(rounded.any((q) => q.distanceTo(const Pt(16, 100)) < 1e-6), isTrue, reason: '$rounded');
    expect(rounded.any((q) => q.distanceTo(const Pt(20, 104)) < 1e-6), isTrue, reason: '$rounded');
    expect(rounded.any((q) => q.distanceTo(const Pt(20, 100)) < 1e-3), isFalse, reason: 'the sharp corner is gone');
    expect(c.editSettings.filletRadius, 1, reason: 'the tool keeps its own radius');
    expect(
      await fails(tester, 'fillet_corner', {
        'id': away.id,
        'at': [52, 50],
        'other_at': [58, 50],
      }),
      contains('No fillet'),
    );
    // chamfer: the corner cut 2 m along the first side and 3 m along the second
    final cut = add(PolylineEntity(id: id(), points: [const Pt(0, 200), const Pt(10, 200), const Pt(10, 210)]));
    await call(tester, 'chamfer_corner', {
      'id': cut.id,
      'at': [5, 200],
      'other_at': [10, 205],
      'd1_m': 2,
      'd2_m': 3,
    });
    final cp = (c.project.byId(cut.id)! as PolylineEntity).points;
    expect(cp, hasLength(4));
    expect(cp[1].distanceTo(const Pt(8, 200)), lessThan(1e-9));
    expect(cp[2].distanceTo(const Pt(10, 203)), lessThan(1e-9));
    expect(c.editSettings.chamferDistance1, 1);
    // break at two points: the part between them goes, two pieces stay
    final run = add(PolylineEntity(id: id(), points: [const Pt(0, 300), const Pt(10, 300), const Pt(20, 300)]));
    final br = await call(tester, 'break_entity', {
      'id': run.id,
      'from': [3, 300],
      'to': [6, 300],
    });
    expect(br.text, contains('pieces now'));
    final pieces = [for (final x in c.selection) c.project.byId(x)!];
    expect(pieces, hasLength(2));
    expect(pieces.fold(0.0, (sum, e) => sum + polylineLength(e.linearPoints!)), closeTo(17, 1e-6));
    // join the selection: two lines that meet become one polyline, with the first one's id
    final j1 = add(LineEntity(id: id(), a: const Pt(0, 400), b: const Pt(10, 400)));
    final j2 = add(LineEntity(id: id(), a: const Pt(10, 400), b: const Pt(20, 405)));
    c.select([j1.id, j2.id]);
    final jo = await call(tester, 'join_entities', {'selected': true});
    expect(jo.text, contains('Joined 2 items into 1'));
    final joined = c.project.byId(j1.id);
    expect(joined, isA<PolylineEntity>());
    expect((joined! as PolylineEntity).points, hasLength(3));
    expect(c.project.byId(j2.id), isNull);
    c.undo();
    expect(c.project.byId(j2.id), isA<LineEntity>());
    expect(await fails(tester, 'join_entities', {}), contains('"ids"'));
    expect(
      await fails(tester, 'join_entities', {
        'ids': ['nope'],
      }),
      contains('No item'),
    );
    // explode: a polyline into its lines, the first keeping the id
    final ex = add(PolylineEntity(id: id(), points: [const Pt(0, 500), const Pt(10, 500), const Pt(10, 510)]));
    final xo = await call(tester, 'explode_entities', {
      'ids': [ex.id],
    });
    expect(xo.text, contains('Exploded 1 item into 2 items'));
    expect(c.project.byId(ex.id), isA<LineEntity>());
    // a closed outline into an irrigated area, with its id
    final sq = add(PolylineEntity(id: id(), points: [const Pt(0, 600), const Pt(10, 600), const Pt(10, 610), const Pt(0, 610)], closed: true));
    final ar = await call(tester, 'convert_to_area', {
      'ids': [sq.id],
    });
    expect(ar.text, contains('Made 1 items'));
    expect(c.project.byId(sq.id), isA<AreaEntity>());
    expect(
      await fails(tester, 'explode_entities', {
        'ids': [sq.id],
      }),
      contains('Nothing exploded'),
    );
  });

  testWidgets('save as copy: a uid of its own, the copy\'s name, the file through the sink; the browser storage read, zipped and kept', (tester) async {
    expect(await fails(tester, 'download_stored_projects', {}), contains('keeps no project'));
    c.project.meta.name = 'Farm';
    add(LineEntity(id: id(), a: Pt.zero, b: const Pt(10, 0)));
    final uid = c.project.meta.uid;
    final out = await call(tester, 'save_as_copy', {});
    expect(c.project.meta.uid, isNot(uid));
    expect(c.project.meta.name, c.t('file.copyName', {'n': 'Farm'}));
    expect(out.text, contains(uid));
    final name = files.keys.single;
    expect(name, endsWith('.oci.json'));
    final saved = jsonDecode(files[name]! as String) as Map<String, dynamic>;
    expect((saved['meta'] as Map)['uid'], c.project.meta.uid);
    expect(c.dirty, isFalse);
    // what the browser keeps
    await tester.runAsync(() => c.store.save(c.project.meta.uid, c.project.meta.name, c.saveJson(markClean: false)));
    final st = await call(tester, 'browser_storage', {});
    expect(st.text, contains('Kept in'));
    expect(st.text, contains('Storage used'));
    expect(st.text, contains(c.project.meta.uid));
    expect(st.text, contains('this tab'));
    final zipped = await call(tester, 'download_stored_projects', {});
    final zipName = files.keys.firstWhere((k) => k.endsWith('.zip'));
    expect(zipped.text, contains('Saved $zipName'));
    final archive = ZipDecoder().decodeBytes(files[zipName]! as Uint8List);
    expect(archive.files.map((f) => f.name), anyElement(contains(c.project.meta.uid)));
    // a browser that cannot be asked (the test platform): said so
    expect((await call(tester, 'persist_storage', {})).text, contains('cannot be asked'));
  });

  testWidgets('the base maps: their terms read; the street map server a confirmed setting that names its host', (tester) async {
    final terms = await call(tester, 'base_map_terms', {});
    expect(terms.text, contains(osmTilePolicyUrl));
    expect(terms.text, contains('view.base_map "satellite"'));
    expect(terms.text, contains('Street map server: the OpenStreetMap Foundation'));
    final set = box.tools.firstWhere((t) => t.name == 'set_setting');
    const url = 'https://tiles.example.com/osm/{z}/{x}/{y}.png';
    final input = <String, dynamic>{
      'values': {'view.streets_tile_url': url},
    };
    expect(set.effectOf(input), ToolEffect.write);
    expect(set.mustConfirm(input), isTrue);
    expect(set.describe(input), contains('tiles.example.com'));
    await call(tester, 'set_setting', input);
    expect(c.streetsTileUrl, url);
    expect((await call(tester, 'base_map_terms', {})).text, contains(url));
    expect(
      await fails(tester, 'set_setting', {
        'values': {'view.streets_tile_url': 'http://tiles.example.com/{z}/{x}/{y}.png'},
      }),
      contains('https://'),
    );
    await call(tester, 'set_setting', {
      'values': {'view.streets_tile_url': ''},
    });
    expect(c.streetsTileUrl, '');
  });

  testWidgets('the default catalogue: saved, the saved one loaded, the factory one put in keeping it, forgotten; reset is the factory one', (tester) async {
    c.clearDefaultCatalog();
    expect(await fails(tester, 'catalog_default', {'action': 'load'}), contains('No default catalogue is saved'));
    final pipes = c.project.catalog.pipes.length;
    expect(pipes, greaterThan(2));
    await call(tester, 'catalog_default', {'action': 'save'});
    expect(hasSavedDefaultCatalog(), isTrue);
    c.project.catalog.pipes.removeRange(1, pipes);
    final load = await call(tester, 'catalog_default', {'action': 'load'});
    expect(load.text, contains('saved on this browser'));
    expect(c.project.catalog.pipes, hasLength(pipes));
    c.undo();
    expect(c.project.catalog.pipes, hasLength(1), reason: 'one undo step');
    final factory = await call(tester, 'catalog_default', {'action': 'factory'});
    expect(factory.text, contains('default'));
    expect(c.project.catalog.pipes.length, greaterThan(1));
    expect(hasSavedDefaultCatalog(), isTrue, reason: 'the factory catalogue keeps the saved default');
    await call(tester, 'catalog_default', {'action': 'reset'});
    expect(hasSavedDefaultCatalog(), isTrue);
    await call(tester, 'catalog_default', {'action': 'forget'});
    expect(hasSavedDefaultCatalog(), isFalse);
    expect((await call(tester, 'catalog_default', {'action': 'forget'})).text, contains('No default catalogue was saved'));
    expect(op('catalog_default').describe(const {'action': 'load'}), c.t('ai.op.catalog_default.load'));
    expect(op('catalog_default').describe(const {'action': 'factory'}), c.t('ai.op.catalog_default.factory'));
    expect(op('catalog_default').mustConfirm(const {'action': 'load'}), isTrue);
  });

  testWidgets('the site climate: RHmin and wind of the Kc adjustment typed in; the ETo from the normals of a station, read, then kept as one undo step', (tester) async {
    final set = await call(tester, 'set_site_climate', {'rh_min_pct': m12(45), 'wind_2m_ms': m12(2.5)});
    expect(set.text, contains('RHmin %'));
    expect(c.project.climate!.rhMinPct, m12(45));
    expect(c.project.climate!.windSpeed2mMs, m12(2.5));
    c.undo();
    expect(c.project.climate, isNull);
    final normals = <String, dynamic>{
      'tmax_c': m12(30),
      'tmin_c': m12(18),
      'rh_mean_pct': m12(65),
      'wind_ms': m12(2),
      'sunshine_h': m12(7),
      'rain_mm': m12(100),
      'latitude_deg': -18.6,
      'elevation_m': 800,
    };
    final read = await call(tester, 'eto_from_station_normals', normals);
    expect(read.text, contains('12 of 12 months'));
    expect(read.text, contains('Not stored'));
    expect(c.project.climate, isNull);
    final applied = await call(tester, 'eto_from_station_normals', {...normals, 'apply': true});
    expect(applied.text, contains('Stored in the site climate'));
    final sc = c.project.climate!;
    expect(sc.source, 'station');
    expect(sc.etoMmDay.every((e) => e > 2 && e < 8), isTrue, reason: '${sc.etoMmDay}');
    expect(sc.rainMm, everyElement(100));
    expect(sc.windSpeed2mMs, everyElement(closeTo(2, 1e-9)));
    expect(sc.rhMinPct!.every((x) => x > 20 && x < 65), isTrue, reason: '${sc.rhMinPct}');
    c.undo();
    expect(c.project.climate, isNull);
    expect(await fails(tester, 'eto_from_station_normals', {'tmax_c': m12(30), 'tmin_c': m12(18)}), contains('latitude_deg'));
    expect(
      await fails(tester, 'eto_from_station_normals', {
        'tmax_c': [30, 31],
        'tmin_c': m12(18),
        'latitude_deg': 0,
      }),
      contains('12 monthly values'),
    );
    expect(await fails(tester, 'eto_from_station_normals', {'tmax_c': List<double?>.filled(12, null), 'tmin_c': m12(18), 'latitude_deg': 0}), contains('No month has both'));
  });

  testWidgets('the month of the programme, the gated pipe with fixed holes, the corner arm\'s own throw', (tester) async {
    final prog = await call(tester, 'controller_program', {'month': 7});
    expect(prog.text, contains('Run times for the requirement of Jul.'));
    expect(await fails(tester, 'controller_program', {'month': 13}), contains('month'));
    const pipe = {'gates': 60, 'pipe_bore_mm': 200, 'slope_pct': 0.1, 'inlet_head_m': 0.6};
    final adjustable = await call(tester, 'gated_pipe', pipe);
    expect(adjustable.text, isNot(contains('delivered L/s')));
    final fixed = await call(tester, 'gated_pipe', {...pipe, 'fixed_holes': true});
    expect(fixed.text, contains('Fixed holes, fully open'));
    expect(fixed.text, contains('delivered L/s'));
    loadExampleAction(c, ExampleId.pivot);
    await tester.runAsync(() => c.runDesign());
    final pivot = c.project.entities.whereType<PivotEntity>().first;
    await call(tester, 'set_pivot_machine', {'pivot': pivot.id, 'corner_arm_throw_m': 22});
    expect((c.project.byId(pivot.id)! as PivotEntity).machine.cornerArmThrowM, 22);
    await call(tester, 'set_pivot_machine', {'pivot': pivot.id, 'corner_arm_throw_m': -1});
    expect((c.project.byId(pivot.id)! as PivotEntity).machine.cornerArmThrowM, isNull, reason: 'back to the end throw of the machine');
    expect(await fails(tester, 'set_pivot_machine', {'pivot': pivot.id, 'corner_arm_throw_m': 150}), contains('corner_arm_throw_m'));
  });

  testWidgets('automatic layout: no zone mixes two hydrozones, and the routed pipes stay inside the lot', (tester) async {
    // two beds side by side with different plant water use, laid out at once
    add(AreaEntity(id: id(), name: 'West', points: [Pt.zero, const Pt(20, 0), const Pt(20, 20), const Pt(0, 20)], plantWaterUse: 'high'));
    add(AreaEntity(id: id(), name: 'East', points: [const Pt(20, 0), const Pt(40, 0), const Pt(40, 20), const Pt(20, 20)], plantWaterUse: 'low'));
    final lot = add(PolylineEntity(id: id(), points: [Pt.zero, const Pt(40, 0), const Pt(40, 20), const Pt(0, 20)], closed: true));
    await call(tester, 'layout_sprinklers', {'area': lot.id, 'outlet': 'spray', 'zoning': true, 'max_zone_flow_m3h': 1000});
    final heads = c.project.entities.whereType<OutletEntity>().toList();
    expect(heads, isNotEmpty);
    final sides = <String, Set<String>>{};
    for (final h in heads) {
      if ((h.position.x - 20).abs() < 0.5) continue;
      (sides[h.zoneName] ??= {}).add(h.position.x < 20 ? 'west' : 'east');
    }
    expect(sides.values.where((s) => s.length > 1), isEmpty, reason: 'a zone mixes the two hydrozones: $sides');
    // an L-shaped lot fed from the top of its arm: the pipes go round the inner corner, never across it
    final l = [const Pt(100, 0), const Pt(130, 0), const Pt(130, 8), const Pt(108, 8), const Pt(108, 30), const Pt(100, 30)];
    final lshape = add(PolylineEntity(id: id(), points: l, closed: true));
    add(WaterSupplyEntity(id: id(), position: const Pt(104, 29)));
    final before = {for (final e in c.project.entities) e.id};
    c.select(const []);
    await call(tester, 'layout_sprinklers', {'area': lshape.id, 'outlet': 'spray', 'routing': true});
    final pipes = [
      for (final e in c.project.entities)
        if (e is PipeEntity && !before.contains(e.id)) e,
    ];
    expect(pipes, isNotEmpty);
    bool inLot(Pt q) => pointInPolygon(q, l) || [for (var k = 0; k < l.length; k++) distanceToSegment(q, l[k], l[(k + 1) % l.length])].reduce(math.min) < 0.3;
    for (final p in pipes) {
      for (var k = 0; k < p.points.length; k++) {
        expect(inLot(p.points[k]), isTrue, reason: '${p.id} vertex ${p.points[k]}');
        if (k > 0) expect(inLot((p.points[k - 1] + p.points[k]) * 0.5), isTrue, reason: '${p.id} segment $k');
      }
    }
  });
}
