import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The seam between two open projects (tabs): a whole project copied into
/// a tab priced in another currency and georeferenced elsewhere (a farm
/// merged into the project of its neighbour), through the workspace
/// clipboard the menus use. What is pasted lands on the same ground, is
/// priced in the target's currency at the reference rate, designs the same
/// and comes out with one undo; pasted back into its own project it is only
/// offset, and into a blank tab it brings its georeference.
void main() {
  String t(String key, [Map<String, String>? args]) => key;

  setUp(() => setPref('lang', 'en'));

  // the orchard of the gallery priced in reais, near Brasília (UTM 23S)
  Project source({double lat = -15.78, double lon = -47.93}) {
    final p = buildExample(ExampleId.orchard, t, lang: 'pt');
    expect(p.params.currencyCode, 'BRL');
    // the programme is a setting of the project, not of its entities: without
    // flows both projects run every zone together and design alike
    p.systemFlows.clear();
    p.meta.georef = GeoReference.fromLatLonOrigin(lat, lon);
    return p;
  }

  // the neighbour: the same settings (catalogue, parameters, terrain method),
  // its own drawing, its prices in dollars and its origin at [georef]
  Project neighbour(Project src, GeoReference georef) {
    final p = src.copy()
      ..entities.clear()
      ..meta = ProjectMeta(name: 'Neighbour', georef: georef);
    p.setCurrency('USD', rate: exchangeRate('BRL', 'USD'));
    p.entities.add(TextEntity(id: p.newId(), position: const Pt(-500, -500), text: 'neighbour'));
    p.entities.add(LineEntity(id: p.newId(), a: const Pt(-500, -490), b: const Pt(-400, -490)));
    return p;
  }

  /// Distance (m) between where [copy] lies in [to] and where [original] lies in [from].
  double offGround(Entity original, GeoReference from, Entity copy, GeoReference to) {
    var worst = 0.0;
    final a = original.grips, b = copy.grips;
    expect(b.length, a.length, reason: '${original.type.name} ${original.id}');
    for (var i = 0; i < a.length; i++) {
      final (lat, lon) = from.toLatLon(a[i].x, a[i].y);
      final (x, y) = to.fromLatLon(lat, lon);
      worst = math.max(worst, (Pt(x, y) - b[i]).length);
    }
    return worst;
  }

  Map<String, BomLine> bomOf(DesignResults r) => {for (final l in r.bom) '${l.category}|${l.description}|${l.specId ?? ''}': l};

  /// The source in the first tab, its neighbour at [target] in a second
  /// one, everything of the source copied and pasted into the neighbour;
  /// the neighbour's project as it was before the paste.
  Future<(ProjectController, ProjectController, List<String>, Map<String, dynamic>)> merge(Workspace w, GeoReference target) async {
    final a = w.current;
    a.openProject(source(), dirty: true);
    final b = w.addTab();
    b.openProject(neighbour(a.project, target), dirty: true);
    final before = jsonDecode(jsonEncode(b.project.toJson())) as Map<String, dynamic>;
    w.select(0);
    a.selectAll();
    expect(await w.copy(), a.project.entities.length);
    w.select(1);
    final ids = w.clipboard!.pasteInto(b);
    return (a, b, ids, before);
  }

  test('a whole project pasted next door, same UTM zone: same ground, same design, prices at the rate, one undo', () async {
    final w = Workspace(systemClipboard: false);
    final from = GeoReference.fromLatLonOrigin(-15.78, -47.93);
    final to = GeoReference.fromLatLonOrigin(-15.78, -47.915); // about 1.6 km east
    expect((from.zone, from.north), (to.zone, to.north));
    final (a, b, ids, before) = await merge(w, to);
    final rate = exchangeRate('BRL', 'USD')!;
    const own = 2;
    expect(ids, hasLength(a.project.entities.length));
    expect(b.project.entities, hasLength(a.project.entities.length + own));
    expect(w.clipboard!.placedOnMap, isTrue);
    expect(b.project.meta.georef!.originEasting, to.originEasting, reason: 'the target keeps its georeference');
    // same ground: the origin difference (checked through latitude and
    // longitude, so within the round trip of the UTM formulas: a millimetre)
    for (var i = 0; i < ids.length; i++) {
      expect(offGround(a.project.entities[i], from, b.project.byId(ids[i])!, to), lessThan(1e-3), reason: a.project.entities[i].id);
    }
    // the catalogue items of the copy are the target's (same technical data, prices already in dollars)
    for (final pipe in a.project.catalog.pipes) {
      final there = b.project.catalog.pipe(pipe.id);
      if (there != null) expect(there.costPerM, closeTo(pipe.costPerM * rate, 1e-9 * math.max(1, pipe.costPerM)), reason: pipe.id);
    }
    expect(b.project.catalog.pipes.where((p) => p.id.contains('~')), isEmpty, reason: 'nothing renamed: the same products');

    // one undo takes the whole paste back, catalogue and layers included; redo brings it again
    final pasted = jsonEncode(b.project.toJson()['entities']);
    b.undo();
    final after = jsonDecode(jsonEncode(b.project.toJson())) as Map<String, dynamic>;
    for (final k in ['entities', 'catalog', 'layers', 'params']) {
      expect(jsonEncode(after[k]), jsonEncode(before[k]), reason: k);
    }
    expect(jsonEncode((after['meta'] as Map)['georef']), jsonEncode((before['meta'] as Map)['georef']));
    b.redo();
    expect(jsonEncode(b.project.toJson()['entities']), pasted);

    // the same design, the bill in dollars
    await a.runDesign();
    await b.runDesign();
    final ra = a.results!, rb = b.results!;
    final valves = [
      for (var i = 0; i < ids.length; i++)
        if (a.project.entities[i] is ControlValveEntity) (a.project.entities[i].id, ids[i]),
    ];
    expect(valves, isNotEmpty);
    expect(rb.zones.length, ra.zones.length);
    for (final (va, vb) in valves) {
      final za = ra.zones[va]!, zb = rb.zones[vb]!;
      expect(zb.totalFlow, closeTo(za.totalFlow, 1e-9 + 1e-7 * za.totalFlow), reason: va);
      expect(zb.minOutletPressure, closeTo(za.minOutletPressure, 1e-6), reason: va);
      expect(zb.maxOutletPressure, closeTo(za.maxOutletPressure, 1e-6), reason: va);
      expect(zb.requiredUpstreamHead, closeTo(za.requiredUpstreamHead, 1e-6), reason: va);
    }
    final ba = bomOf(ra), bb = bomOf(rb);
    expect(bb.keys.toSet(), ba.keys.toSet());
    for (final k in ba.keys) {
      expect(bb[k]!.quantity, closeTo(ba[k]!.quantity, 1e-6 * math.max(1, ba[k]!.quantity)), reason: k);
      expect(bb[k]!.unitCost, closeTo(ba[k]!.unitCost * rate, 1e-6 * math.max(1, ba[k]!.unitCost)), reason: k);
    }
    expect(rb.capitalCost, closeTo(ra.capitalCost * rate, 1e-6 * math.max(1, ra.capitalCost)));
  });

  test('across a UTM zone line the copy still lands on the same ground and designs alike', () async {
    final w = Workspace(systemClipboard: false);
    final a = w.current;
    a.openProject(source(lat: -15.78, lon: -47.995), dirty: true); // zone 23, 0.5 km east of the zone line
    final from = a.project.meta.georef!;
    final to = GeoReference.fromLatLonOrigin(-15.78, -48.01); // zone 22
    expect((from.zone, to.zone), (23, 22));
    final b = w.addTab();
    b.openProject(neighbour(a.project, to), dirty: true);
    w.select(0);
    a.selectAll();
    await w.copy();
    w.select(1);
    final ids = w.clipboard!.pasteInto(b);
    expect(w.clipboard!.placedOnMap, isTrue);
    var worst = 0.0;
    for (var i = 0; i < ids.length; i++) {
      worst = math.max(worst, offGround(a.project.entities[i], from, b.project.byId(ids[i])!, to));
    }
    // the affine fit through the corners of the copy: the grids differ by the
    // convergence of the meridians (about 0.8° here), the ground by millimetres
    expect(worst, lessThan(0.01));
    await a.runDesign();
    await b.runDesign();
    final ra = a.results!, rb = b.results!;
    for (var i = 0; i < ids.length; i++) {
      if (a.project.entities[i] is! ControlValveEntity) continue;
      final za = ra.zones[a.project.entities[i].id]!, zb = rb.zones[ids[i]]!;
      expect(zb.totalFlow, closeTo(za.totalFlow, 1e-4 * za.totalFlow), reason: ids[i]);
      expect(zb.minOutletPressure, closeTo(za.minOutletPressure, 0.01), reason: ids[i]);
    }
    expect(rb.capitalCost, closeTo(ra.capitalCost * exchangeRate('BRL', 'USD')!, 1e-3 * ra.capitalCost * exchangeRate('BRL', 'USD')!));
  });

  test('a blank tab takes the georeference of what is pasted into it, and its own currency', () async {
    final w = Workspace(systemClipboard: false);
    final a = w.current;
    a.openProject(source(), dirty: true);
    a.selectAll();
    await w.copy();
    final blank = w.addTab();
    expect(blank.project.entities, isEmpty);
    expect(blank.project.meta.georef, isNull);
    final code = blank.project.params.currencyCode;
    final ids = w.clipboard!.pasteInto(blank);
    expect(ids, hasLength(a.project.entities.length));
    expect(w.clipboard!.placedOnMap, isFalse, reason: 'nothing to move: the blank tab adopts the origin');
    expect(blank.project.meta.georef!.toJson(), a.project.meta.georef!.toJson());
    // same drawing coordinates, prices converted to the blank tab's currency
    expect(blank.project.byId(ids.first)!.grips, a.project.entities.first.grips);
    final rate = exchangeRate('BRL', code)!;
    final ctl = a.project.entities.whereType<ControllerEntity>().firstOrNull;
    if (ctl != null) {
      final i = a.project.entities.indexOf(ctl);
      expect((blank.project.byId(ids[i]) as ControllerEntity).cost, closeTo(ctl.cost * rate, 1e-9 * math.max(1, ctl.cost)));
    }
  });

  test('pasted back into its own project the copy is offset, not moved nor repriced', () async {
    final w = Workspace(systemClipboard: false);
    final a = w.current;
    a.openProject(source(), dirty: true);
    final n = a.project.entities.length;
    final pipes = a.project.catalog.toJson();
    a.selectAll();
    await w.copy();
    final ids = w.clipboard!.pasteInto(a);
    expect(a.project.entities, hasLength(2 * n));
    expect(w.clipboard!.placedOnMap, isFalse);
    for (var i = 0; i < n; i++) {
      final g0 = a.project.entities[i].grips, g1 = a.project.byId(ids[i])!.grips;
      for (var k = 0; k < g0.length; k++) {
        expect((g1[k] - g0[k] - const Pt(2, -2)).length, lessThan(1e-9), reason: a.project.entities[i].id);
      }
    }
    expect(jsonEncode(a.project.catalog.toJson()), jsonEncode(pipes), reason: 'the same project: nothing added, nothing repriced');
  });

  test('from another window: the clipboard text with the same tab number but another georeference is another project', () async {
    final w1 = Workspace(systemClipboard: false);
    w1.current.openProject(source(), dirty: true);
    w1.current.selectAll();
    await w1.copy();
    final text = w1.clipboard!.encode();
    // the other window: its first tab has the same number
    final w2 = Workspace(systemClipboard: false);
    final c = w2.current;
    expect(c.tabId, w1.current.tabId);
    c.openProject(neighbour(w1.current.project, GeoReference.fromLatLonOrigin(-15.78, -47.915)), dirty: true);
    final payload = ClipboardPayload.tryParse(text)!;
    expect(payload.currency, 'BRL');
    final ids = payload.pasteInto(c);
    expect(payload.placedOnMap, isTrue, reason: 'moved to the same ground, not offset by (2, -2)');
    final from = w1.current.project.meta.georef!, to = c.project.meta.georef!;
    for (var i = 0; i < ids.length; i++) {
      expect(offGround(w1.current.project.entities[i], from, c.project.byId(ids[i])!, to), lessThan(1e-3));
    }
  });
}
