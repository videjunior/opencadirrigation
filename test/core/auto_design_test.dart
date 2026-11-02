import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/field_subdivision.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/routing.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/design/zoning.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// A fresh project with the default catalogue, solenoid valves closing in
/// 3 s (as the gallery examples).
Project _project() => Project(catalog: Catalog.defaultCatalog())..params.valveClosureTimeS = 3;

/// Mains at [at] (fixed pressure), the mainline [pipes], one system flow per
/// valve.
void _supply(Project p, Pt at, List<RoutedPipe> pipes, {double headM = 45}) {
  for (final m in pipes) {
    p.entities.add(PipeEntity(id: p.newId(), points: m.points, scope: HydraulicScope.mainline));
  }
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: at, calculatePressure: false, designHeadM: headM, maxHeadM: headM + 5));
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  for (var i = 0; i < valves.length; i++) {
    p.systemFlows.add(SystemFlow(id: 'sf${i + 1}', name: 'F${i + 1}', valveIds: {valves[i].id}, startHour: i.toDouble(), durationHours: 1));
  }
}

/// Connected, checked without errors, designed with every zone in its
/// pressure window, every flow without deficit and every pipe sized.
DesignResults _designs(Project p) {
  final m = NetworkBuilder(p).build();
  expect(m.unconnectedEntities, isEmpty, reason: m.unconnectedEntities.map((id) => '${p.byId(id)?.type}').join(', '));
  expect(m.warnings.where((w) => w.startsWith('zone_overlap')), isEmpty);
  final check = runDesignCheck(p);
  expect(check.issues.where((i) => i.severity == CheckSeverity.error).map((i) => i.code), isEmpty);
  final r = Designer(p).designAll();
  expect(r.unconnected, isEmpty);
  expect(r.zones, hasLength(p.entities.whereType<ControlValveEntity>().length));
  for (final z in r.zones.values) {
    expect(z.converged, isTrue, reason: z.zoneName);
    expect(z.withinWindow, isTrue, reason: '${z.zoneName}: ${z.warnings}');
  }
  for (final f in r.systemFlows) {
    expect(f.converged, isTrue, reason: f.name);
    expect(f.maxDeficit, lessThan(0.05), reason: '${f.name}: ${f.warnings}');
  }
  for (final e in p.entities.whereType<PipeEntity>()) {
    expect(e.pipeSpecId, isNotNull);
  }
  expect(r.bom, isNotEmpty);
  return r;
}

void main() {
  test('a lawn laid out, zoned and routed designs without errors', () {
    final p = _project();
    final family = p.catalog.outlet('rotor')!;
    final lawn = _rect(0, 0, 40, 30), house = _rect(12, 10, 26, 20);
    final layout = layoutLandscape(outline: lawn, exclusions: [house], family: family);
    expect(layout.metrics!.cu, greaterThan(85));
    final zoning = zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: 3 * m3sPerM3h));
    const poc = Pt(-8, -6);
    final routing = routeZones([
      for (final z in zoning.zones) [for (final i in z.items) layout.heads[i].position],
    ], RouteOptions(pointOfConnection: poc, exclusions: [house], direction: layout.direction));
    final names = [for (var z = 0; z < zoning.zones.length; z++) 'Zone ${z + 1}'];
    p.entities.addAll(layout.toOutlets(p, zoneName: (i) => names[zoning.zoneOf[i]]));
    p.entities.addAll(routing.toEntities(p, zoneNames: names, valveSpecIds: [for (final z in zoning.zones) pickZoneValve(p.catalog, z.flow)?.id]));
    _supply(p, poc, routing.mainline);
    p.entities.add(AreaEntity(id: p.newId(), points: lawn, name: 'Lawn'));
    final r = _designs(p);
    expect(r.zones.length, zoning.zones.length);
    // every zone draws what the zoning planned, at the nominal pressure
    for (var z = 0; z < zoning.zones.length; z++) {
      final valve = p.entities.whereType<ControlValveEntity>().firstWhere((v) => v.zoneName == names[z]);
      expect(r.zones[valve.id]!.totalFlow, closeTo(zoning.zones[z].flow, 0.06 * zoning.zones[z].flow));
    }
  });

  test('sprays on an L-shaped front lawn fed from a mainline along the street', () {
    final p = _project();
    final family = p.catalog.outlet('spray')!;
    const lawn = [Pt(0, 0), Pt(20, 0), Pt(20, 8), Pt(8, 8), Pt(8, 18), Pt(0, 18)];
    final layout = layoutLandscape(outline: lawn, family: family);
    final zoning = zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: 4 * m3sPerM3h));
    const main = [Pt(-3, -2), Pt(22, -2)];
    final routing = routeZones([
      for (final z in zoning.zones) [for (final i in z.items) layout.heads[i].position],
    ], RouteOptions(mainline: main, direction: layout.direction));
    final names = [for (var z = 0; z < zoning.zones.length; z++) 'Zone ${z + 1}'];
    p.entities.addAll(layout.toOutlets(p));
    p.entities.addAll(routing.toEntities(p, zoneNames: names, valveSpecIds: [for (final z in zoning.zones) pickZoneValve(p.catalog, z.flow)?.id]));
    _supply(p, main.first, [RoutedPipe(main, HydraulicScope.mainline)], headM: 40);
    _designs(p);
  });

  test('a field cut into blocks of drip tape, fed by a mainline tree', () {
    final p = _project();
    // a test-sized model of the tapes (the gallery uses the default 100)
    p.params.maxNodesPerLateral = 12;
    final tape = p.catalog.tape('tape16_10_30')!;
    // tape every 1.8 m: emitter flow per hectare
    final perHa = tape.emitter.flow(8) * 1e4 / (tape.emitterSpacingM * 1.8);
    const field = [Pt(0, 0), Pt(160, 0), Pt(160, 40), Pt(110, 60), Pt(0, 60)];
    const poc = Pt(-20, 30);
    final s = subdivideField(
      field,
      FieldSubdivisionOptions(direction: const Pt(1, 0), mode: SubdivisionMode.grid, maxBlockFlow: 8 * m3sPerM3h, flowPerHectare: perHa, maxLateralLength: 80, roadWidth: 4, pointOfConnection: poc),
    );
    expect(s.blocks.length, greaterThanOrEqualTo(2));
    expect(s.messages.where((m) => !m.startsWith('field_block_narrow')), isEmpty);
    final valves = <Pt>[];
    for (var i = 0; i < s.blocks.length; i++) {
      final b = s.blocks[i];
      final res = generateBlock(
        p,
        blockOptionsFor(
          b,
          s.direction,
          lateralSpacing: 1.8,
          isTape: true,
          tapeSpecId: tape.id,
          tapeInletHeadM: 8,
          valveSpecId: pickZoneValve(p.catalog, b.flow)?.id,
          submainStub: 2,
          zoneName: 'Block ${i + 1}',
        ),
      );
      p.entities.addAll(res.all);
      valves.add(res.valve!.position);
    }
    _supply(p, poc, routeMainline(poc, valves), headM: 30);
    _designs(p);
  });

  test('tree rings in an orchard block design without errors', () {
    final p = _project();
    final rings = layoutTreeRings(area: _rect(0, 0, 42, 28), options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, ringRadius: 0.75));
    expect(rings.trees, hasLength(28));
    p.entities.addAll(rings.toEntities(p, tapeSpecId: 'drip16_16_50', tapeInletHeadM: 10, valveSpecId: 'ev25', zoneName: 'Orchard'));
    const poc = Pt(-15, 14);
    _supply(p, poc, routeMainline(poc, [rings.valve!]), headM: 30);
    final r = _designs(p);
    expect(r.zones.values.single.emitterCount, greaterThan(28 * 4));
  });
}
