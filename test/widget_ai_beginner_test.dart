import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/agent_tools_manual.dart';
import 'package:opencadirrigation/app/ai/ai_prompt.dart';
import 'package:opencadirrigation/app/ai/playbooks.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/advisor.dart' show FixKind;
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A host with attached files that records the tabs it opens.
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  final opened = <Project>[];
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
  bool openTab(Project p) {
    opened.add(p);
    return true;
  }
}

/// Satellite tiles without a network: the left half green, the right half
/// grey, every request recorded.
class _Tiles extends TileFetcher {
  _Tiles() : png = img.encodePng(_tile());
  final Uint8List png;
  final urls = <String>[];

  static img.Image _tile() {
    final t = img.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        t.setPixelRgb(x, y, x < 128 ? 40 : 128, x < 128 ? 170 : 128, x < 128 ? 50 : 128);
      }
    }
    return t;
  }

  @override
  Future<Uint8List> bytes(String url) async {
    urls.add(url);
    return png;
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404);
}

/// A DXF of one closed boundary in metres.
String _dxf(List<(double, double)> pts, {String layer = 'FIELD'}) => [
  '0', 'SECTION', '2', 'HEADER', '9', r'$INSUNITS', '70', '6', '0', 'ENDSEC', //
  '0', 'SECTION', '2', 'ENTITIES', '0', 'LWPOLYLINE', '8', layer, '90', '${pts.length}', '70', '1',
  for (final (x, y) in pts) ...['10', '$x', '20', '$y'],
  '0', 'ENDSEC', '0', 'EOF', '',
].join('\n');

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// What a beginner's first project with the assistant needs from the tools:
/// the interface language as a setting, CAD imports placed on the map with
/// the next step said, a pivot fitted over a field drawn twice, no booster
/// pump on a mains connection without the user, catalogue gaps answered
/// with what to do, the satellite imagery for the vegetation, tabs opened
/// in the background, and the manual, prompt and playbooks in step.
void main() {
  late ProjectController c;
  late _Host host;
  late AgentToolbox box;
  late _Tiles tiles;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    host = _Host();
    tiles = _Tiles();
    box = AgentToolbox(
      c,
      host: host,
      snapshots: CanvasSnapshots(tiles: tiles),
    );
  });

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

  List<List<double>> square(double a, double b) => [
    [a, a],
    [b, a],
    [b, b],
    [a, b],
  ];

  testWidgets('the interface language is a setting the assistant changes, as View → Language does', (tester) async {
    final get = await call(tester, 'get_setting', {
      'keys': ['view.language'],
    });
    expect(get.text, contains('view.language = "en"'));
    expect(get.text, contains('pt Português'));
    final before = c.historyIndex;
    final set = await call(tester, 'set_setting', {
      'values': {'view.language': 'es'},
    });
    expect(c.lang, 'es', reason: set.text);
    expect(c.t('menu.file'), 'Archivo');
    expect(c.historyIndex, before, reason: 'the language is not a project change');
    expect(
      await fails(tester, 'set_setting', {
        'values': {'view.language': 'xx'},
      }),
      contains('view.language must be one of'),
    );
    await c.setLanguage('en');
  });

  testWidgets('a DXF in UTM coordinates without a georeference: its extent and set_georeference "utm"', (tester) async {
    host.files['field.dxf'] = _bytes(_dxf([(350000, 7650000), (350400, 7650000), (350400, 7650300), (350000, 7650300)]));
    final out = await call(tester, 'import_attachment', {'name': 'field.dxf'});
    expect(out.text, contains('1 item, now selected; extent [350000.0, 7650000.0, 350400.0, 7650300.0]'));
    expect(out.text, contains('set_georeference {mode "utm", zone, north, easting_m 0, northing_m 0}'));
    expect(out.text, contains('zone = floor((longitude + 180) / 6) + 1'));
    expect(c.selection, hasLength(1));
    // the next step works as written: the drawing is read as UTM 23S where it is
    await call(tester, 'set_georeference', {'mode': 'utm', 'zone': 23, 'north': false, 'easting_m': 0, 'northing_m': 0});
    final (lat, lon) = c.project.meta.georef!.toLatLon(350000, 7650000);
    expect(lat, closeTo(-21.2, 0.2));
    expect(lon, closeTo(-46.4, 0.2));
  });

  testWidgets('a DXF in local coordinates: set_site, then align_entities on the selection; IFC and project files are refused', (tester) async {
    host.files['plan.dxf'] = _bytes(_dxf([(0, 0), (200, 0), (200, 100), (0, 100)]));
    final out = await call(tester, 'import_attachment', {'name': 'plan.dxf'});
    expect(out.text, contains('no georeference'));
    expect(out.text, contains('set_site'));
    expect(out.text, contains('align_entities {selected true, from_a, to_a, from_b, to_b, keep_scale true}'));
    final aligned = await call(tester, 'align_entities', {
      'selected': true,
      'from_a': [0, 0],
      'to_a': [10, 10],
      'from_b': [200, 0],
      'to_b': [210, 10],
    });
    expect(aligned.text, contains('Aligned 1 items'));
    expect(c.project.entities.whereType<PolylineEntity>().single.points.first.distanceTo(const Pt(10, 10)), lessThan(1e-6));
    // export-only and project formats say where they go instead
    host.files['model.ifc'] = _bytes('ISO-10303-21;');
    host.files['farm.oci.json'] = _bytes(jsonEncode(Project().toJson()));
    expect(await fails(tester, 'import_attachment', {'name': 'model.ifc'}), allOf(contains('IFC'), contains('DXF, DWG or PDF')));
    expect(await fails(tester, 'import_attachment', {'name': 'farm.oci.json'}), contains('open_attached_project'));
    expect(c.project.entities, hasLength(1));
  });

  testWidgets('a UTM drawing in a project georeferenced at the site: the move that puts it in place', (tester) async {
    c.setGeoreferenceAt(-18.6, -46.5);
    final g = c.project.meta.georef!;
    final e0 = g.originEasting, n0 = g.originNorthing;
    host.files['survey.dxf'] = _bytes(_dxf([(e0 + 100, n0 + 100), (e0 + 300, n0 + 100), (e0 + 300, n0 + 250), (e0 + 100, n0 + 250)]));
    final out = await call(tester, 'import_attachment', {'name': 'survey.dxf'});
    // the import itself moves a drawing in UTM coordinates of the project's
    // zone by the origin, and says so
    expect(out.text, contains(c.t('warn.cad_moved_to_georef')));
    expect(c.project.entities.whereType<PolylineEntity>().single.points.first.distanceTo(const Pt(100, 100)), lessThan(1e-6));
    // a local drawing next to the origin only gets the check
    host.files['local.dxf'] = _bytes(_dxf([(0, 0), (50, 0), (50, 50), (0, 50)]));
    final local = await call(tester, 'import_attachment', {'name': 'local.dxf'});
    expect(local.text, contains('A CAD drawing keeps its own coordinates'));
  });

  testWidgets('a GIS file lands in place by its coordinate system: no placement advice, nothing selected', (tester) async {
    host.files['field.geojson'] = _bytes(
      jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'name': 'Field'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [-46.500, -18.600],
                  [-46.497, -18.600],
                  [-46.497, -18.597],
                  [-46.500, -18.597],
                  [-46.500, -18.600],
                ],
              ],
            },
          },
        ],
      }),
    );
    final out = await call(tester, 'import_attachment', {'name': 'field.geojson'});
    expect(c.project.meta.georef, isNotNull, reason: out.text);
    expect(out.text, isNot(contains('Next:')));
    expect(out.text, isNot(contains('now selected')));
    expect(c.selection, isEmpty);
  });

  testWidgets('fit_pivot: a second outline of the field is no obstacle; a shape that blocks it is named', (tester) async {
    await call(tester, 'create_entities', {
      'entities': [
        {'type': 'area', 'name': 'Field', 'pts': square(0, 800)},
        {'type': 'polyline', 'name': 'Boundary', 'pts': square(0, 800), 'closed': true},
        {'type': 'hatch', 'name': 'Fill', 'pts': square(0, 800)},
      ],
    });
    final ok = await call(tester, 'fit_pivot', {'area': 'Field'});
    expect(ok.text, contains('Pivot '), reason: ok.text);
    expect(c.project.entities.whereType<PivotEntity>(), hasLength(1));
    // a shape over nearly all of the field is in the way: named, with the way out
    c.project.entities.removeWhere((e) => e is PivotEntity);
    await call(tester, 'create_entities', {
      'entities': [
        {'type': 'polyline', 'name': 'Crop', 'pts': square(10, 790), 'closed': true},
      ],
    });
    final crop = c.project.entities.whereType<PolylineEntity>().firstWhere((e) => e.name == 'Crop');
    final why = await fails(tester, 'fit_pivot', {'area': 'Field'});
    expect(why, allOf(contains('Shapes kept clear of: ${crop.id} (Polyline "Crop", '), contains(' % of the field)')));
    expect(why, contains('fit_pivot_advanced {area, obstacles []}'));
    final adv = await call(tester, 'fit_pivot_advanced', {'area': 'Field', 'obstacles': <String>[]});
    expect(adv.text, contains('Pivot '), reason: adv.text);
  });

  testWidgets('auto_fix leaves a booster pump on a mains connection to the user; so does Fix automatically', (tester) async {
    void shortMains(ProjectController x) {
      loadExampleAction(x, ExampleId.garden);
      x.project.entities.whereType<WaterSupplyEntity>().first
        ..designHeadM = 18
        ..maxHeadM = 40;
      x.entitiesChanged();
    }

    shortMains(c);
    expect(c.project.entities.whereType<WaterSupplyEntity>().first.calculatePressure, isFalse);
    final out = await call(tester, 'auto_fix', {});
    expect(c.project.entities.whereType<PumpEntity>(), isEmpty, reason: out.text);
    expect(out.text, contains('Left for the user to decide: a booster pump on the mains connection'));
    final m = RegExp(r'would fix #(\d+) \[(\w+)\]').firstMatch(out.text);
    expect(m, isNotNull, reason: out.text);
    final messages = await call(tester, 'get_design_messages', {});
    expect(messages.text, contains('(choosePump adds a booster pump to the mains connection: ask the user first)'));
    // after the user agrees, the model applies it
    final fixed = await call(tester, 'apply_fix', {'index': int.parse(m!.group(1)!), 'code': m.group(2)!, 'fix': 'choosePump'});
    expect(fixed.isError, isFalse, reason: fixed.text);
    expect(c.project.entities.whereType<PumpEntity>(), hasLength(1));
    // the program's own command leaves it to the user as well (1.6.0 AUT:
    // it added the pump on its own before), listing it among the decisions
    final app = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    app.newProject();
    await app.setLanguage('en', persist: false);
    shortMains(app);
    final report = await tester.runAsync(() => app.autoFixAll());
    expect(app.project.entities.whereType<PumpEntity>(), isEmpty);
    expect(report!.decisions.map((a) => a.fixes.first), contains(FixKind.choosePump));
  });

  testWidgets('missing catalogue items end with what to do: pumps, sprinklers, driplines and drippers', (tester) async {
    loadExampleAction(c, ExampleId.garden);
    c.project.entities.whereType<WaterSupplyEntity>().first
      ..designHeadM = 18
      ..maxHeadM = 40;
    await tester.runAsync(() => c.runDesign());
    for (final p in c.project.catalog.pumps) {
      p.enabled = false;
    }
    final rank = await call(tester, 'rank_pumps', {});
    expect(rank.text, allOf(contains('No catalogue pump fits this duty'), contains('add_catalog_pack'), contains('edit_catalog')));
    final pump = await fails(tester, 'apply_pump', {});
    expect(pump, contains('list_catalog_packs'));
    // a fresh project without sprinklers, driplines or drippers
    c.newProject();
    final cat = c.project.catalog;
    for (final o in cat.outlets) {
      o.enabled = false;
    }
    for (final x in cat.tapes) {
      x.enabled = false;
    }
    await call(tester, 'create_entities', {
      'entities': [
        {'type': 'area', 'name': 'Orchard', 'pts': square(0, 60)},
      ],
    });
    expect(await fails(tester, 'layout_sprinklers', {'area': 'Orchard'}), allOf(contains('no enabled sprinkler or micro-sprinkler'), contains('list_catalog_packs')));
    expect(await fails(tester, 'tree_rings', {'area': 'Orchard'}), allOf(contains('no enabled dripline'), contains('add_catalog_pack')));
    expect(await fails(tester, 'tree_rings', {'area': 'Orchard', 'kind': 'drippers'}), allOf(contains('no enabled dripper'), contains('edit_catalog')));
    expect(await fails(tester, 'tree_rings_advanced', {'area': 'Orchard'}), allOf(contains('no enabled dripline'), contains('list_catalog_packs')));
    expect(await fails(tester, 'generate_block', {'area': 'Orchard', 'lateral': 'tape', 'lateral_spacing_m': 1.5}), contains('no enabled drip tape'));
    expect(c.project.entities.whereType<TapeEntity>(), isEmpty, reason: 'nothing made without a model');
    // with a dripline the rings carry flow
    for (final x in cat.tapes) {
      x.enabled = true;
    }
    final rings = await call(tester, 'tree_rings', {'area': 'Orchard', 'tape': 'drip16_16_50'});
    final q = double.parse(RegExp(r'zone flow ([\d.]+) m³/h').firstMatch(rings.text)!.group(1)!);
    expect(q, greaterThan(0), reason: rings.text);
    expect(c.project.entities.whereType<TapeEntity>().every((x) => cat.tape(x.tapeSpecId) != null), isTrue);
  });

  testWidgets('without terrain, get_elevations says how to get it; the vegetation reads the satellite imagery', (tester) async {
    final none = await call(tester, 'get_elevations', {
      'points': [
        [0, 0],
      ],
    });
    expect(none.text, allOf(contains('set_site'), contains('download_terrain')));
    c.setGeoreferenceAt(-18.6, -46.5);
    c.baseMap = BaseMap.none;
    String text;
    try {
      text = (await call(tester, 'detect_vegetation', {
        'bbox': [0, 0, 60, 60],
        'preview_only': true,
      })).text;
    } on ToolInputError catch (e) {
      text = e.message;
    }
    expect(tiles.urls, isNotEmpty, reason: text);
    expect(tiles.urls.every((u) => u.contains('World_Imagery')), isTrue, reason: 'the satellite imagery, not the map on screen');
    expect(c.baseMap, BaseMap.none, reason: 'the user\'s base map is left alone');
    expect(text, isNot(contains('No aerial image')));
  });

  testWidgets('tabs the assistant opens open in the background', (tester) async {
    final blank = await call(tester, 'new_project', {'name': 'Second'});
    expect(blank.text, allOf(contains('in the background'), contains('opens the assistant there')));
    final ex = await call(tester, 'open_example', {'id': 'garden'});
    expect(ex.text, contains('in the background'));
    expect(host.opened.map((p) => p.meta.name), contains('Second'));
  });

  testWidgets('the manual, the prompt and the playbooks say what the tools do', (tester) async {
    final ui = manualText(box, 'interface');
    expect(ui, contains('Help → Interactive tutorial'));
    expect(ui, contains('Draw → GPS in the field → Record a walk'));
    expect(ui, contains('View → Language'));
    expect(ui, contains('"view.language"'));
    expect(manualText(box, 'terrain'), contains('set_georeference {mode "utm"'));
    expect(manualText(box, 'reports'), contains('export_sheet_pdf'));
    final prompt = aiSystemPrompt(c);
    expect(prompt, contains('homeowner'));
    expect(prompt, contains('bucket test'));
    expect(prompt, contains('On a new, empty project start with the site'));
    expect(prompt, isNot(contains('look before drawing: view_snapshot with base_map "satellite" and terrain_picture')), reason: 'no terrain picture before the terrain exists');
    final all = playbooks.map((p) => p.steps).join('\n');
    for (final stale in ['last-used valve', 'last-used dripline', 'does not limit the lateral length', 'set_base_map "satellite" first', 'every spot height', 'an enclosing boundary']) {
      expect(all, isNot(contains(stale)), reason: stale);
    }
    for (final p in playbooks) {
      expect(p.steps, contains('export_sheet_pdf'), reason: p.id);
      expect(p.steps, isNot(contains('run_design again')), reason: '${p.id}: auto_fix designs again itself');
    }
    final edit = box.tools.firstWhere((t) => t.name == 'export_file');
    expect(edit.description, contains('export_sheet_pdf'));
    expect(ValveKind.values.map((k) => k.name), contains('airRelease'), reason: 'insert_air_valves names the kind');
  });
}
