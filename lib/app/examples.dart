/// The example gallery: ready-to-design projects built in code (so their
/// names follow the interface language) and also shipped as `.oci.json`
/// files under `examples/` (written by `tool/gen_examples.dart`).
///
/// Pure Dart (no Flutter): the generator tool and the tests build them too.
library;

import 'dart:math' as math;

import '../core/design/block_generator.dart';
import '../core/design/pivot.dart';
import '../core/model/catalog.dart';
import '../core/model/entities.dart';
import '../core/model/geometry.dart';
import '../core/model/project.dart';
import '../core/units.dart';

/// Translator signature used by the builders (`I18n.call`).
typedef Tr = String Function(String key, [Map<String, String>? args]);

enum ExampleId { orchard, garden, sportsField, rowCrop, pivot, greenhouse, nursery, coffee, bananas, sugarcane, gravity, pasture, golf, sectorPivot, linear }

/// Gallery entry: what the card says and how to build the project.
class ExampleInfo {
  const ExampleInfo({required this.id, required this.build});
  final ExampleId id;
  final Project Function(Tr t, String lang) build;

  String get titleKey => 'exg.${id.name}.title';
  String get subtitleKey => 'exg.${id.name}.sub';
  String get tagsKey => 'exg.${id.name}.tags';
}

/// All examples, in gallery order.
const List<ExampleInfo> exampleGallery = [
  ExampleInfo(id: ExampleId.orchard, build: buildOrchardExample),
  ExampleInfo(id: ExampleId.garden, build: buildGardenExample),
  ExampleInfo(id: ExampleId.sportsField, build: buildSportsFieldExample),
  ExampleInfo(id: ExampleId.rowCrop, build: buildRowCropExample),
  ExampleInfo(id: ExampleId.pivot, build: buildPivotExample),
  ExampleInfo(id: ExampleId.greenhouse, build: buildGreenhouseExample),
  ExampleInfo(id: ExampleId.nursery, build: buildNurseryExample),
  ExampleInfo(id: ExampleId.coffee, build: buildCoffeeExample),
  ExampleInfo(id: ExampleId.bananas, build: buildBananaExample),
  ExampleInfo(id: ExampleId.sugarcane, build: buildSugarcaneExample),
  ExampleInfo(id: ExampleId.gravity, build: buildGravityExample),
  ExampleInfo(id: ExampleId.pasture, build: buildPastureExample),
  ExampleInfo(id: ExampleId.golf, build: buildGolfExample),
  ExampleInfo(id: ExampleId.sectorPivot, build: buildSectorPivotExample),
  ExampleInfo(id: ExampleId.linear, build: buildLinearExample),
];

ExampleInfo exampleInfo(ExampleId id) => exampleGallery.firstWhere((e) => e.id == id);

/// Builds the example [id] with names translated by [t].
Project buildExample(ExampleId id, Tr t, {String lang = 'en'}) => exampleInfo(id).build(t, lang);

/// The example named in a URL parameter (`?example=garden`), or null.
ExampleId? exampleIdFromName(String? name) {
  if (name == null) return null;
  final n = name.trim().toLowerCase();
  for (final id in ExampleId.values) {
    if (id.name.toLowerCase() == n) return id;
  }
  return null;
}

Project _newProject(Tr t, String lang, {required String name, required String client, required String site}) {
  final p = Project(catalog: Catalog.defaultCatalog(lang: lang));
  p.params.valveClosureTimeS = 3; // solenoid valves close in seconds: the surge check uses it
  p.meta
    ..name = t(name)
    ..client = t(client)
    ..site = t(site)
    ..designer = 'OpenCADIrrigation';
  return p;
}

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

// ---------------------------------------------------------------- orchard

/// An orchard with a micro-sprinkler block and a drip block fed by a well
/// with a pump, on a gentle slope.
Project buildOrchardExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.name', client: 'ex.client', site: 'ex.site');
  for (var i = 0; i < 5; i++) {
    final z = 100.0 + 0.5 * i;
    final x = -60.0 + 100.0 * i;
    p.entities.add(ContourEntity(id: p.newId(), points: [Pt(x, -30), Pt(x + 10, 20), Pt(x, 80)], elevation: z));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(-30, -15), const Pt(280, -15), const Pt(280, 70), const Pt(-30, 70)], closed: true, name: t('ex.boundary')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-28, 62), text: t('ex.title'), height: 2.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(270, 60), kind: SymbolKind.northArrow, size: 4));
  final a = generateBlock(p, BlockOptions(
    polygon: [const Pt(0, 0), const Pt(120, 0), const Pt(120, 45), const Pt(0, 45)],
    direction: const Pt(1, 0),
    lateralSpacing: 4,
    outletSpecId: 'micro',
    nozzleId: 'm50',
    outletSpacing: 3.5,
    headM: 15,
    submainPosition: SubmainPosition.start,
    valveSpecId: 'ev80',
    valvePosition: ValvePosition.centre,
    submainStub: 2,
    zoneName: t('ex.zoneA'),
    submainLabel: t('name.submain'),
    stubLabel: t('name.stub'),
    lateralPrefix: t('name.lateral'),
  ));
  p.entities.addAll(a.all);
  p.entities.add(AreaEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(120, 0), const Pt(120, 45), const Pt(0, 45)], name: t('ex.blockA'), crop: t('ex.citrus'), netDepthMmPerDay: 4.5, efficiency: 0.9, useWaterBalance: true, etoMmDay: 5.5, kc: 0.7, awcMmPerM: 120, rootDepthM: 0.8, mad: 0.5, emittersPerPlant: 1));
  final b = generateBlock(p, BlockOptions(
    polygon: [const Pt(150, 0), const Pt(260, 0), const Pt(260, 50), const Pt(150, 50)],
    direction: const Pt(1, 0),
    lateralSpacing: 3,
    isTape: true,
    tapeSpecId: 'drip16_16_50',
    tapeInletHeadM: 10,
    submainPosition: SubmainPosition.start,
    valveSpecId: 'ev80',
    valvePosition: ValvePosition.centre,
    submainStub: 2,
    zoneName: t('ex.zoneB'),
    submainLabel: t('name.submain'),
    stubLabel: t('name.stub'),
    lateralPrefix: t('name.lateral'),
  ));
  p.entities.addAll(b.all);
  p.entities.add(AreaEntity(id: p.newId(), points: [const Pt(150, 0), const Pt(260, 0), const Pt(260, 50), const Pt(150, 50)], name: t('ex.blockB'), crop: t('ex.grape'), netDepthMmPerDay: 4.0, efficiency: 0.92, useWaterBalance: true, etoMmDay: 5.5, kc: 0.7, awcMmPerM: 110, rootDepthM: 0.6, mad: 0.45, emittersPerPlant: 4, wettedFraction: 0.4));
  final va = a.valve!.position, vb = b.valve!.position;
  final well = Pt(va.x - 30, -8);
  final tee = Pt(va.x, -8);
  p.entities.add(PipeEntity(id: p.newId(), points: [well, tee], scope: HydraulicScope.mainline, name: t('ex.riser')));
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, va], scope: HydraulicScope.mainline, name: t('ex.branchA')));
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(vb.x, -8), vb], scope: HydraulicScope.mainline, name: t('ex.branchB')));
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: well, name: t('ex.well'), calculatePressure: true, waterLevelOffsetM: -12));
  p.entities.add(PumpEntity(id: p.newId(), position: Pt(well.x + 3, -8), pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: Pt(well.x + 8, -8), valveSpecId: 'filter_screen80'));
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.flow1'), valveIds: {a.valve!.id}, startHour: 6, durationHours: 3),
    SystemFlow(id: 'sf2', name: t('ex.flow2'), valveIds: {b.valve!.id}, startHour: 9, durationHours: 4),
  ]);
  return p;
}

// ---------------------------------------------------------------- residential garden

/// A 16 × 40 m lot: pop-up sprays on the front lawn, rotors on the back
/// lawn and dripline in the side beds, fed by the mains through a meter and
/// a backflow preventer.
Project buildGardenExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.g.name', client: 'ex.g.client', site: 'ex.g.site');
  p.params.currency = p.params.currency; // keep the default currency
  // terrain: gentle rise towards the back
  for (final (x, y, z) in [(0.0, 0.0, 100.0), (16.0, 0.0, 100.05), (0.0, 40.0, 100.6), (16.0, 40.0, 100.7), (8.0, -6.0, 99.9)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
  }
  // drawing: lot, street, house
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(0, 0, 16, 40), closed: true, name: t('ex.g.lot')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-6, -6), b: const Pt(22, -6), name: t('ex.g.street')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-4, -8.5), text: t('ex.g.street'), height: 1.2));
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(3, 12, 13, 24), closed: true, name: t('ex.g.house')));
  p.entities.add(HatchEntity(id: p.newId(), points: _rect(3, 12, 13, 24), angleDeg: 45, spacing: 0.8));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(6, 17.5), text: t('ex.g.house'), height: 1.2));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-4, 43), text: t('ex.g.title'), height: 1.4));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(19.5, 37), kind: SymbolKind.northArrow, size: 2));
  for (final y in [14.0, 18.0, 22.0]) {
    p.entities.add(SymbolEntity(id: p.newId(), position: Pt(1.5, y), kind: SymbolKind.tree, size: 1.1));
    p.entities.add(SymbolEntity(id: p.newId(), position: Pt(14.5, y), kind: SymbolKind.tree, size: 1.1));
  }

  // zone 1: front lawn 16 × 8 m, sprays every 4 m (head to head)
  final z1 = t('ex.g.zone1');
  final frontRows = [0.0, 4.0, 8.0];
  final cols = [0.0, 4.0, 8.0, 12.0, 16.0];
  for (final y in frontRows) {
    for (final x in cols) {
      final corner = (x == 0 || x == 16) && (y == 0 || y == 8);
      final edge = !corner && (x == 0 || x == 16 || y == 0 || y == 8);
      final nozzle = corner ? 's12q' : (edge ? 's12h' : 's12');
      final arc = corner ? 90.0 : (edge ? 180.0 : 360.0);
      // orientation: the arc opens towards the lawn
      var orient = 0.0;
      if (corner) {
        orient = x == 0 ? (y == 0 ? 0 : 270) : (y == 0 ? 90 : 180);
      } else if (edge) {
        orient = x == 0 ? 270 : (x == 16 ? 90 : (y == 0 ? 0 : 180));
      }
      p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, y), outletSpecId: 'spray', nozzleId: nozzle, headM: 20, arcDeg: arc, orientationDeg: orient, zoneName: z1));
    }
  }
  for (final y in frontRows) {
    p.entities.add(PipeEntity(id: p.newId(), points: [for (final x in cols) Pt(x, y)], scope: HydraulicScope.zone));
  }
  p.entities.add(PipeEntity(id: p.newId(), points: [for (final y in frontRows) Pt(0, y)], scope: HydraulicScope.zone));
  final v1 = ControlValveEntity(id: p.newId(), position: const Pt(-1, 4), valveSpecId: 'ev25', zoneName: z1, name: z1);
  p.entities.add(v1);
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-1, 4), const Pt(0, 4)], scope: HydraulicScope.zone));
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 0, 16, 10), name: t('ex.g.front'), crop: t('ex.g.grass'), netDepthMmPerDay: 5, efficiency: 0.75, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 100, rootDepthM: 0.3, mad: 0.5));

  // zone 2: back lawn 16 × 14 m, rotors 8 × 7 m
  final z2 = t('ex.g.zone2');
  final backRows = [26.0, 33.0, 40.0];
  final backCols = [0.0, 8.0, 16.0];
  for (final y in backRows) {
    for (final x in backCols) {
      final corner = (x == 0 || x == 16) && (y == 26 || y == 40);
      final edge = !corner && (x == 0 || x == 16 || y == 26 || y == 40);
      final nozzle = corner ? 'r3_90' : (edge ? 'r3_180' : 'r3');
      final arc = corner ? 90.0 : (edge ? 180.0 : 360.0);
      var orient = 0.0;
      if (corner) {
        orient = x == 0 ? (y == 26 ? 0 : 270) : (y == 26 ? 90 : 180);
      } else if (edge) {
        orient = x == 0 ? 270 : (x == 16 ? 90 : (y == 26 ? 0 : 180));
      }
      p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, y), outletSpecId: 'rotor', nozzleId: nozzle, headM: 25, arcDeg: arc, orientationDeg: orient, zoneName: z2));
    }
  }
  for (final y in backRows) {
    p.entities.add(PipeEntity(id: p.newId(), points: [for (final x in backCols) Pt(x, y)], scope: HydraulicScope.zone));
  }
  p.entities.add(PipeEntity(id: p.newId(), points: [for (final y in backRows) Pt(0, y)], scope: HydraulicScope.zone));
  final v2 = ControlValveEntity(id: p.newId(), position: const Pt(-1, 33), valveSpecId: 'ev25', zoneName: z2, name: z2);
  p.entities.add(v2);
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-1, 33), const Pt(0, 33)], scope: HydraulicScope.zone));
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 26, 16, 40), name: t('ex.g.back'), crop: t('ex.g.grass'), netDepthMmPerDay: 5, efficiency: 0.8, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 100, rootDepthM: 0.3, mad: 0.5));

  // zone 3: dripline in the two side beds (3 × 12 m each), fed along the house front
  final z3 = t('ex.g.zone3');
  final v3 = ControlValveEntity(id: p.newId(), position: const Pt(-1, 11), valveSpecId: 'ev25', zoneName: z3, name: z3);
  p.entities.add(v3);
  const dripX = [0.5, 1.5, 2.5, 13.5, 14.5, 15.5];
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-1, 11), const Pt(0, 11), for (final x in dripX) Pt(x, 11)], scope: HydraulicScope.zone));
  for (final x in dripX) {
    p.entities.add(TapeEntity(id: p.newId(), points: [Pt(x, 11), Pt(x, 24)], tapeSpecId: 'drip16_16_50', inletHeadM: 10, name: '${t('ex.g.bed')} ${x < 8 ? 1 : 2}'));
  }
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 12, 3, 24), name: '${t('ex.g.bed')} 1', crop: t('ex.g.shrubs'), netDepthMmPerDay: 3, efficiency: 0.9, useWaterBalance: true, etoMmDay: 5, kc: 0.6, awcMmPerM: 110, rootDepthM: 0.4, mad: 0.5, emittersPerPlant: 2, wettedFraction: 0.5));
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(13, 12, 16, 24), name: '${t('ex.g.bed')} 2', crop: t('ex.g.shrubs'), netDepthMmPerDay: 3, efficiency: 0.9, useWaterBalance: true, etoMmDay: 5, kc: 0.6, awcMmPerM: 110, rootDepthM: 0.4, mad: 0.5, emittersPerPlant: 2, wettedFraction: 0.5));

  // mains: meter and backflow preventer at the street, trunk along the side path, stubs to the valves
  const supply = Pt(8, -5), meter = Pt(8, -4), backflow = Pt(8, -3);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: supply, name: t('ex.g.supply'), calculatePressure: false, designHeadM: 35, maxHeadM: 40, designFlow: 6 * m3sPerM3h, maxFlow: 8 * m3sPerM3h));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: meter, valveSpecId: 'meter50'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: backflow, valveSpecId: 'backflow50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [supply, meter, backflow, const Pt(8, -2), const Pt(-2, -2), const Pt(-2, 4), const Pt(-2, 11), const Pt(-2, 33)], scope: HydraulicScope.mainline, name: t('ex.g.main')));
  for (final y in [4.0, 11.0, 33.0]) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-2, y), Pt(-1, y)], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': z1}), valveIds: {v1.id}, startHour: 5, durationHours: 0.5),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': z2}), valveIds: {v2.id}, startHour: 5.5, durationHours: 0.75),
    SystemFlow(id: 'sf3', name: t('ex.shift', {'n': '3', 'z': z3}), valveIds: {v3.id}, startHour: 6.5, durationHours: 1.5),
  ]);
  return p;
}

// ---------------------------------------------------------------- football pitch

/// A full-size pitch (105 × 68 m) watered by impact sprinklers on a 15 × 17 m
/// grid, one zone per row, reservoir and pump, night-time shifts.
Project buildSportsFieldExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.f.name', client: 'ex.f.client', site: 'ex.f.site');
  // terrain: 0.5 % fall from west to east
  for (final (x, y, z) in [(0.0, 0.0, 100.0), (105.0, 0.0, 99.5), (0.0, 68.0, 100.1), (105.0, 68.0, 99.6), (-6.0, -24.0, 100.2)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
  }
  // pitch markings
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(0, 0, 105, 68), closed: true, name: t('ex.f.pitch')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(52.5, 0), b: const Pt(52.5, 68)));
  p.entities.add(CircleEntity(id: p.newId(), center: const Pt(52.5, 34), radius: 9.15));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(0, 13.85), const Pt(16.5, 13.85), const Pt(16.5, 54.15), const Pt(0, 54.15)]));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(105, 13.85), const Pt(88.5, 13.85), const Pt(88.5, 54.15), const Pt(105, 54.15)]));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(0, 24.84), const Pt(5.5, 24.84), const Pt(5.5, 43.16), const Pt(0, 43.16)]));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(105, 24.84), const Pt(99.5, 24.84), const Pt(99.5, 43.16), const Pt(105, 43.16)]));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(0, 30.34), const Pt(-2, 30.34), const Pt(-2, 37.66), const Pt(0, 37.66)]));
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(105, 30.34), const Pt(107, 30.34), const Pt(107, 37.66), const Pt(105, 37.66)]));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(0, 74), text: t('ex.f.title'), height: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(112, 64), kind: SymbolKind.northArrow, size: 4));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-14, -21), kind: SymbolKind.pumpHouse, size: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-20, -27), text: t('ex.f.pumpHouse'), height: 1.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-14, -28), kind: SymbolKind.tank, size: 2.5));
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 0, 105, 68), name: t('ex.f.pitch'), crop: t('ex.f.grass'), netDepthMmPerDay: 6, efficiency: 0.8, useWaterBalance: true, etoMmDay: 6, kc: 0.9, awcMmPerM: 110, rootDepthM: 0.25, mad: 0.4));

  // sprinklers: 8 columns × 5 rows, one zone per row
  const cols = [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 105.0];
  const rows = [0.0, 17.0, 34.0, 51.0, 68.0];
  final valves = <ControlValveEntity>[];
  for (var r = 0; r < rows.length; r++) {
    final y = rows[r];
    final zone = t('ex.f.row', {'n': '${r + 1}'});
    for (final x in cols) {
      final corner = (x == 0 || x == 105) && (y == 0 || y == 68);
      final edge = !corner && (x == 0 || x == 105 || y == 0 || y == 68);
      final arc = corner ? 90.0 : (edge ? 180.0 : 360.0);
      var orient = 0.0;
      if (corner) {
        orient = x == 0 ? (y == 0 ? 0 : 270) : (y == 0 ? 90 : 180);
      } else if (edge) {
        orient = x == 0 ? 270 : (x == 105 ? 90 : (y == 0 ? 0 : 180));
      }
      p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, y), outletSpecId: 'impact34', nozzleId: 'i5.0', headM: 35, arcDeg: arc, orientationDeg: orient, riserHeight: 0, zoneName: zone));
    }
    final valve = ControlValveEntity(id: p.newId(), position: Pt(-3, y), valveSpecId: 'ev50', zoneName: zone, name: zone);
    valves.add(valve);
    p.entities.add(valve);
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-3, y), for (final x in cols) Pt(x, y)], scope: HydraulicScope.zone, name: zone));
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-6, y), Pt(-3, y)], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  // reservoir, pump, check valve and the trunk along the west side
  const tank = Pt(-6, -24), pump = Pt(-6, -21), check = Pt(-6, -18);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: tank, name: t('ex.f.tank'), calculatePressure: true, waterLevelOffsetM: 1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: check, valveSpecId: 'check100'));
  p.entities.add(PipeEntity(id: p.newId(), points: [tank, pump, check, for (final y in rows) Pt(-6, y)], scope: HydraulicScope.mainline, name: t('ex.f.main')));
  for (var i = 0; i < valves.length; i++) {
    p.systemFlows.add(SystemFlow(id: 'sf${i + 1}', name: t('ex.shift', {'n': '${i + 1}', 'z': valves[i].zoneName}), valveIds: {valves[i].id}, startHour: (21 + i) % 24, durationHours: 1));
  }
  return p;
}

// ---------------------------------------------------------------- drip row crop

/// Four 120 × 60 m tomato blocks on drip tape (laterals along the rows,
/// submains with valves at the outer edges, 4 m farm roads between the
/// blocks so the tapes of neighbouring blocks never touch), a trunk with
/// reservoir, pump and screen filter, two blocks per shift, 1 % slope.
Project buildRowCropExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.c.name', client: 'ex.c.client', site: 'ex.c.site');
  // terrain: rises 1 % eastwards and 0.5 % northwards
  for (final (x, y) in [(0.0, 0.0), (244.0, 0.0), (0.0, 124.0), (244.0, 124.0), (122.0, 62.0), (122.0, -40.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.01 * x + 0.005 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-12, -12, 256, 136), closed: true, name: t('ex.c.field')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-12, -50), b: const Pt(256, -50), name: t('ex.c.road')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-12, -56), b: const Pt(256, -56), name: t('ex.c.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(60, -54.5), text: t('ex.c.road'), height: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-10, 142), text: t('ex.c.title'), height: 5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(248, 128), kind: SymbolKind.northArrow, size: 6));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(134, -36), kind: SymbolKind.pumpHouse, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(134, -30), kind: SymbolKind.filterStation, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(134, -42), kind: SymbolKind.tank, size: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(139, -43), text: t('ex.c.reservoir'), height: 2));

  // four blocks: laterals along x, submain on the outer edge, valve 2 m
  // outward; 4 m roads keep the tape ends of neighbouring blocks apart
  final blocks = <(List<Pt>, SubmainPosition)>[
    (_rect(0, 0, 120, 60), SubmainPosition.start),
    (_rect(124, 0, 244, 60), SubmainPosition.end),
    (_rect(0, 64, 120, 124), SubmainPosition.start),
    (_rect(124, 64, 244, 124), SubmainPosition.end),
  ];
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < blocks.length; i++) {
    final (poly, pos) = blocks[i];
    final name = t('ex.c.block', {'n': '${i + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      lateralSpacing: 1.8,
      isTape: true,
      tapeSpecId: 'tape16_10_30',
      tapeInletHeadM: 8,
      submainPosition: pos,
      valveSpecId: 'ev80',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.c.tomato'), netDepthMmPerDay: 5.5, efficiency: 0.92, useWaterBalance: true, etoMmDay: 5.5, kc: 1.1, awcMmPerM: 130, rootDepthM: 0.5, mad: 0.4, plantSpacingM: 0.4, rowSpacingM: 1.8, wettedFraction: 0.6, emittersPerPlant: 1));
  }
  // trunk: reservoir → pump → filter → tee, then west and east branches with stubs to the valves
  const reservoir = Pt(122, -40), pump = Pt(122, -36), filter = Pt(122, -30), tee = Pt(122, -6);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: reservoir, name: t('ex.c.reservoir'), calculatePressure: true, waterLevelOffsetM: 1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_screen80'));
  p.entities.add(PipeEntity(id: p.newId(), points: [reservoir, pump, filter, tee], scope: HydraulicScope.mainline, name: t('ex.c.trunk')));
  final west = [valves[0].position, valves[2].position];
  final east = [valves[1].position, valves[3].position];
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(west[0].x - 4, -6), for (final v in west) Pt(v.x - 4, v.y)], scope: HydraulicScope.mainline, name: t('ex.c.west')));
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(east[0].x + 4, -6), for (final v in east) Pt(v.x + 4, v.y)], scope: HydraulicScope.mainline, name: t('ex.c.east')));
  for (final v in west) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(v.x - 4, v.y), v], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  for (final v in east) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(v.x + 4, v.y), v], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': '${valves[0].zoneName} + ${valves[3].zoneName}'}), valveIds: {valves[0].id, valves[3].id}, startHour: 6, durationHours: 5),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': '${valves[1].zoneName} + ${valves[2].zoneName}'}), valveIds: {valves[1].id, valves[2].id}, startHour: 11, durationHours: 5),
  ]);
  return p;
}

// ---------------------------------------------------------------- centre pivot

/// A 300 m centre pivot on maize fed by a well, a pump and a 340 m mainline,
/// on a 0.4 % slope.
Project buildPivotExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.p.name', client: 'ex.p.client', site: 'ex.p.site');
  const centre = Pt(400, 400);
  const radius = 300.0;
  // terrain: 0.4 % rise northwards (straight contours) and spot heights at the corners
  for (var i = 0; i <= 4; i++) {
    final y = 200.0 * i;
    p.entities.add(ContourEntity(id: p.newId(), points: [Pt(-20, y), Pt(820, y)], elevation: 100 + 0.004 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(0, 0, 800, 800), closed: true, name: t('ex.p.boundary')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-40, -30), b: const Pt(840, -30), name: t('ex.c.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(0, 830), text: t('ex.p.title'), height: 14));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(780, 770), kind: SymbolKind.northArrow, size: 15));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(60, 430), kind: SymbolKind.pumpHouse, size: 8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(40, 400), kind: SymbolKind.well, size: 6));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(20, 380), text: t('ex.p.well'), height: 6));
  final circle = [for (var i = 0; i < 48; i++) centre + Pt.polar(radius, 2 * math.pi * i / 48)];
  p.entities.add(AreaEntity(id: p.newId(), points: circle, name: t('ex.p.field'), crop: t('ex.p.maize'), netDepthMmPerDay: 6, efficiency: 0.85, useWaterBalance: true, etoMmDay: 6, kc: 1.15, awcMmPerM: 120, rootDepthM: 0.6, mad: 0.5));

  const well = Pt(60, 400), pump = Pt(66, 400), gate = Pt(72, 400);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: well, name: t('ex.p.well'), calculatePressure: true, waterLevelOffsetM: -25));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_big'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: gate, valveSpecId: 'gate100'));
  p.entities.add(PipeEntity(id: p.newId(), points: [well, pump, gate, centre], scope: HydraulicScope.mainline, name: t('ex.p.adductor')));
  final name = t('ex.p.pivot');
  p.entities.add(PivotEntity(
    id: p.newId(),
    center: centre,
    radiusM: radius,
    angleDeg: 30,
    kind: PivotKind.pivot,
    spanLengthM: 50,
    grossDepthMm: 8,
    hoursPerCycle: 24,
    endPressureM: 14,
    endThrowM: 8,
    name: name,
    zoneName: name,
    sprinklerSpacingM: 2.5,
    machineCost: 480000,
    towerCost: 0,
  ));
  return p;
}

// ---------------------------------------------------------------- greenhouse

/// Four 9 × 50 m tunnels of peppers on pressure-compensating dripline, one
/// zone per tunnel, a tank, a small pump and a disc filter; two tunnels per
/// shift.
Project buildGreenhouseExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.gh.name', client: 'ex.gh.client', site: 'ex.gh.site');
  for (final (x, y, z) in [(-14.0, -16.0, 100.2), (46.0, -16.0, 100.1), (-14.0, 56.0, 100.0), (46.0, 56.0, 99.9)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-14, -16, 46, 56), closed: true, name: t('ex.gh.lot')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-14, 59), text: t('ex.gh.title'), height: 1.8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(42, 52), kind: SymbolKind.northArrow, size: 2.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-12, -12), kind: SymbolKind.tank, size: 2));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-12, -6), kind: SymbolKind.filterStation, size: 1.6));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-13.5, -15), text: t('ex.gh.tank'), height: 0.9));
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < 4; i++) {
    final x0 = 11.0 * i;
    final poly = _rect(x0, 0, x0 + 9, 50);
    final name = t('ex.gh.tunnel', {'n': '${i + 1}'});
    p.entities.add(PolylineEntity(id: p.newId(), points: poly, closed: true, name: name));
    p.entities.add(TextEntity(id: p.newId(), position: Pt(x0 + 0.5, 51), text: name, height: 1));
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(0, 1),
      lateralSpacing: 1.5,
      firstLateralOffset: 0.75,
      isTape: true,
      tapeSpecId: 'drip16pc_16_50',
      tapeInletHeadM: 15,
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev25',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.gh.crop'), netDepthMmPerDay: 4, efficiency: 0.95, useWaterBalance: true, etoMmDay: 4, kc: 1.05, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.3, plantSpacingM: 0.4, rowSpacingM: 1.5, wettedFraction: 0.5, emittersPerPlant: 1));
  }
  const tank = Pt(-9, -12), pump = Pt(-9, -9), filter = Pt(-9, -6);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: tank, name: t('ex.gh.tank'), calculatePressure: true, waterLevelOffsetM: 2));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_small'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_disc50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [tank, pump, filter, for (final v in valves) Pt(v.position.x, -6)], scope: HydraulicScope.mainline, name: t('ex.gh.main')));
  for (final v in valves) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(v.position.x, -6), v.position], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': '${valves[0].zoneName} + ${valves[1].zoneName}'}), valveIds: {valves[0].id, valves[1].id}, startHour: 7, durationHours: 1),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': '${valves[2].zoneName} + ${valves[3].zoneName}'}), valveIds: {valves[2].id, valves[3].id}, startHour: 8, durationHours: 1),
  ]);
  return p;
}

// ---------------------------------------------------------------- coffee on contour lines

/// Three coffee blocks on a hillside whose laterals follow the contour
/// lines (a guided block: offset copies of a guide polyline), PC dripline,
/// well and pump at the foot of the slope; the mainline climbs the west side.
Project buildCoffeeExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.cf.name', client: 'ex.cf.client', site: 'ex.cf.site');
  // contour shape: one smooth hump between x = 0 and 150, flat outside. Each
  // contour and each block bottom is that hump shifted north by [shift]; the
  // laterals are perpendicular offsets (at most 60 m, well inside the hump's
  // 114 m radius of curvature) of their block's bottom, so every copy is a
  // single curve parallel to the others.
  double hump(double x) => x <= 0 || x >= 150 ? 0.0 : 5 * (1 - math.cos(2 * math.pi * x / 150));
  List<Pt> curve(double shift, double v, double x0, double x1) {
    final base = [for (var x = x0; x <= x1 + 1e-9; x += 5) Pt(x, shift + hump(x))];
    return v == 0 ? base : offsetPolyline(base, v);
  }
  // terrain: 7 % slope rising northwards, contours every 20 m parallel to the laterals
  for (var k = -2; k <= 12; k++) {
    final v = 20.0 * k;
    p.entities.add(ContourEntity(id: p.newId(), points: curve(v, 0, -40, 190), elevation: 100 + 0.07 * v));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: [const Pt(-14, -6), const Pt(164, -6), const Pt(164, 204), const Pt(-14, 204)], closed: true, name: t('ex.cf.boundary')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-14, 209), text: t('ex.cf.title'), height: 4));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(156, 196), kind: SymbolKind.northArrow, size: 5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-16, -26), kind: SymbolKind.well, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-16, -18), kind: SymbolKind.pumpHouse, size: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-20, -31), text: t('ex.cf.well'), height: 2));
  final valves = <ControlValveEntity>[];
  for (var k = 0; k < 3; k++) {
    final v0 = 64.0 * k;
    final bottom = curve(v0, 0, 0, 150), top = curve(v0, 60, 0, 150);
    final poly = [...bottom, ...top.reversed];
    final name = t('ex.cf.block', {'n': '${k + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      guide: curve(v0, 0, -12.5, 162.5), // vertices away from the block sides: no tiny clipped segments
      lateralSpacing: 3.5,
      isTape: true,
      tapeSpecId: 'drip16pc_16_50',
      tapeInletHeadM: 15,
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev40',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.cf.coffee'), netDepthMmPerDay: 4, efficiency: 0.92, useWaterBalance: true, etoMmDay: 4.5, kc: 0.95, awcMmPerM: 120, rootDepthM: 0.8, mad: 0.5, plantSpacingM: 0.7, rowSpacingM: 3.5, wettedFraction: 0.4, emittersPerPlant: 1));
  }
  const well = Pt(-8, -26), pump = Pt(-8, -18), filter = Pt(-8, -12);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: well, name: t('ex.cf.well'), calculatePressure: true, waterLevelOffsetM: -10));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_screen80'));
  p.entities.add(PipeEntity(id: p.newId(), points: [well, pump, filter, for (final v in valves) Pt(-8, v.position.y)], scope: HydraulicScope.mainline, name: t('ex.cf.main')));
  for (final v in valves) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-8, v.position.y), v.position], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': '${valves[0].zoneName} + ${valves[1].zoneName}'}), valveIds: {valves[0].id, valves[1].id}, startHour: 6, durationHours: 4),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': valves[2].zoneName}), valveIds: {valves[2].id}, startHour: 10, durationHours: 4),
  ]);
  return p;
}

// ---------------------------------------------------------------- pasture

/// Three 72 × 72 m paddocks watered by spray lines of impact sprinklers on a
/// 12 × 18 m grid (a lateral every 18 m, a sprinkler every 12 m), one zone
/// per paddock, reservoir, pump and check valve; one paddock per night shift.
Project buildPastureExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.pa.name', client: 'ex.pa.client', site: 'ex.pa.site');
  for (final (x, y) in [(-40.0, -50.0), (240.0, -50.0), (-40.0, 90.0), (240.0, 90.0), (100.0, 30.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.005 * x));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-8, -8, 230, 80), closed: true, name: t('ex.pa.fence')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-40, -46), b: const Pt(240, -46), name: t('ex.pa.road')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-40, -52), b: const Pt(240, -52), name: t('ex.pa.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(40, -50.5), text: t('ex.pa.road'), height: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-8, 84), text: t('ex.pa.title'), height: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(224, 74), kind: SymbolKind.northArrow, size: 4));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-32, -30), kind: SymbolKind.tank, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-32, -22), kind: SymbolKind.pumpHouse, size: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-40, -37), text: t('ex.pa.reservoir'), height: 1.8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(111, -8), kind: SymbolKind.gate, size: 3.0));
  for (final x in [10.0, 60.0, 110.0, 160.0, 210.0]) {
    p.entities.add(SymbolEntity(id: p.newId(), position: Pt(x, -18), kind: SymbolKind.tree, size: 3));
  }
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < 3; i++) {
    final x0 = 78.0 * i;
    final poly = _rect(x0, 0, x0 + 72, 72);
    final name = t('ex.pa.paddock', {'n': '${i + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      lateralSpacing: 18,
      firstLateralOffset: 9,
      outletSpecId: 'impact34',
      nozzleId: 'i4.0',
      outletSpacing: 12,
      outletOffsetHalf: true,
      headM: 30,
      lateralPipeSpecId: 'pvc50',
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev80',
      valvePosition: ValvePosition.centre,
      submainStub: 3,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.pa.grass'), netDepthMmPerDay: 5, efficiency: 0.75, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 110, rootDepthM: 0.5, mad: 0.55));
  }
  const tank = Pt(-24, -30), pump = Pt(-24, -24), check = Pt(-24, -18);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: tank, name: t('ex.pa.reservoir'), calculatePressure: true, waterLevelOffsetM: 1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: check, valveSpecId: 'check100'));
  p.entities.add(PipeEntity(id: p.newId(), points: [tank, pump, check, const Pt(-24, -12), for (final v in valves) Pt(v.position.x, -12)], scope: HydraulicScope.mainline, name: t('ex.pa.main')));
  for (final v in valves) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(v.position.x, -12), v.position], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  for (var i = 0; i < valves.length; i++) {
    p.systemFlows.add(SystemFlow(id: 'sf${i + 1}', name: t('ex.shift', {'n': '${i + 1}', 'z': valves[i].zoneName}), valveIds: {valves[i].id}, startHour: 20.0 + 2 * i, durationHours: 2));
  }
  return p;
}

// ---------------------------------------------------------------- golf hole

/// One golf hole: a tee with pop-up sprays, a fairway with rotors on a
/// triangular grid (two zones) and a green with rotors around its edge, all
/// fed from a pond by a pump; three night-time shifts.
Project buildGolfExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.go.name', client: 'ex.go.client', site: 'ex.go.site');
  for (final (x, y) in [(-60.0, -60.0), (170.0, -60.0), (-60.0, 50.0), (170.0, 50.0), (60.0, 0.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.01 * x));
  }
  // drawing: fairway, green, tee, bunker, pond, trees
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(0, 0, 100, 30), closed: true, name: t('ex.go.fairway')));
  p.entities.add(CircleEntity(id: p.newId(), center: const Pt(130, 15), radius: 10));
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-40, 12, -10, 18), closed: true, name: t('ex.go.tee')));
  final bunker = [const Pt(114, -2), const Pt(122, -6), const Pt(128, -3), const Pt(126, 3), const Pt(118, 4)];
  p.entities.add(PolylineEntity(id: p.newId(), points: List.of(bunker), closed: true, name: t('ex.go.bunker')));
  p.entities.add(HatchEntity(id: p.newId(), points: List.of(bunker), angleDeg: 0, spacing: 0.6));
  p.entities.add(CircleEntity(id: p.newId(), center: const Pt(60, -46), radius: 12));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(56, -47), text: t('ex.go.pond'), height: 1.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-40, 20), text: t('ex.go.tee'), height: 1.2));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(42, 33), text: t('ex.go.fairway'), height: 1.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(125, 27), text: t('ex.go.green'), height: 1.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-44, 46), text: t('ex.go.title'), height: 2.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(160, 40), kind: SymbolKind.northArrow, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(44, -32), kind: SymbolKind.pumpHouse, size: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(36, -37), text: t('ex.go.pumpHouse'), height: 1.2));
  for (final x in [10.0, 35.0, 60.0, 85.0, 110.0]) {
    p.entities.add(SymbolEntity(id: p.newId(), position: Pt(x, 40), kind: SymbolKind.tree, size: 3));
    p.entities.add(SymbolEntity(id: p.newId(), position: Pt(x + 12, -12), kind: SymbolKind.tree, size: 2.5));
  }

  // green: eight full-circle rotors around the edge on an open ring pipe
  final zg = t('ex.go.green');
  final heads = [for (var i = 0; i < 8; i++) const Pt(130, 15) + Pt.polar(10, math.pi * i / 4)];
  for (final h in heads) {
    p.entities.add(OutletEntity(id: p.newId(), position: h, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: zg));
  }
  p.entities.add(PipeEntity(id: p.newId(), points: List.of(heads), scope: HydraulicScope.zone, name: zg));
  final vg = ControlValveEntity(id: p.newId(), position: const Pt(145, 15), valveSpecId: 'ev25', zoneName: zg, name: zg);
  p.entities.add(vg);
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(145, 15), heads[0]], scope: HydraulicScope.zone, name: t('name.stub')));
  p.entities.add(AreaEntity(id: p.newId(), points: [for (var i = 0; i < 24; i++) const Pt(130, 15) + Pt.polar(10, math.pi * i / 12)], name: zg, crop: t('ex.go.turf'), netDepthMmPerDay: 6, efficiency: 0.8, useWaterBalance: true, etoMmDay: 6, kc: 0.9, awcMmPerM: 100, rootDepthM: 0.15, mad: 0.35));

  // tee: half-circle sprays along both long sides, facing inwards
  final zt = t('ex.go.tee');
  final teeX = [for (var i = 0; i <= 6; i++) -40.0 + 5 * i];
  for (final x in teeX) {
    p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, 12), outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 180, orientationDeg: 0, zoneName: zt));
    p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, 18), outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 180, orientationDeg: 180, zoneName: zt));
  }
  for (final y in [12.0, 18.0]) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-42, y), for (final x in teeX) Pt(x, y)], scope: HydraulicScope.zone, name: zt));
  }
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-42, 12), const Pt(-42, 15), const Pt(-42, 18)], scope: HydraulicScope.zone, name: t('name.submain')));
  final vt = ControlValveEntity(id: p.newId(), position: const Pt(-44, 15), valveSpecId: 'ev25', zoneName: zt, name: zt);
  p.entities.add(vt);
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-44, 15), const Pt(-42, 15)], scope: HydraulicScope.zone, name: t('name.stub')));
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(-40, 12, -10, 18), name: zt, crop: t('ex.go.turf'), netDepthMmPerDay: 5, efficiency: 0.75, useWaterBalance: true, etoMmDay: 6, kc: 0.9, awcMmPerM: 100, rootDepthM: 0.2, mad: 0.4));

  // fairway: rotors on a triangular grid (automatic head layout), one zone per pair of rows
  final grid = generateSprinklerGrid(p, SprinklerGridOptions(polygon: _rect(0, 0, 100, 30), outletSpecId: 'rotor', nozzleId: 'r3', spacingAlong: 10, spacingBetween: 10 * math.sqrt(3) / 2, pattern: GridPattern.triangular, headM: 25));
  final rowYs = grid.map((o) => o.position.y).toSet().toList()..sort();
  assert(rowYs.length == 4, 'four rows of rotors expected, got ${rowYs.length}');
  final fairwayValves = <ControlValveEntity>[];
  for (var z = 0; z < 2; z++) {
    final zone = t('ex.go.fairwayZone', {'n': '${z + 1}'});
    final ys = rowYs.sublist(2 * z, 2 * z + 2);
    for (final y in ys) {
      final row = grid.where((o) => o.position.y == y).toList()..sort((a, b) => a.position.x.compareTo(b.position.x));
      for (final o in row) {
        o.zoneName = zone;
        p.entities.add(o);
      }
      p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-2, y), for (final o in row) o.position], scope: HydraulicScope.zone, name: zone));
    }
    final mid = (ys[0] + ys[1]) / 2;
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-2, ys[0]), Pt(-2, mid), Pt(-2, ys[1])], scope: HydraulicScope.zone, name: t('name.submain')));
    final v = ControlValveEntity(id: p.newId(), position: Pt(-4, mid), valveSpecId: 'ev40', zoneName: zone, name: zone);
    p.entities.add(v);
    fairwayValves.add(v);
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-4, mid), Pt(-2, mid)], scope: HydraulicScope.zone, name: t('name.stub')));
  }
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 0, 100, 30), name: t('ex.go.fairway'), crop: t('ex.go.turf'), netDepthMmPerDay: 5, efficiency: 0.75, useWaterBalance: true, etoMmDay: 6, kc: 0.85, awcMmPerM: 100, rootDepthM: 0.25, mad: 0.45));

  // pond, pump and a header along the cart path with stubs to the valves
  const pond = Pt(60, -42), pump = Pt(60, -36);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: pond, name: t('ex.go.pond'), calculatePressure: true, waterLevelOffsetM: -1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  final mA = fairwayValves[0].position.y, mB = fairwayValves[1].position.y;
  p.entities.add(PipeEntity(id: p.newId(), points: [pond, pump, const Pt(60, -20)], scope: HydraulicScope.mainline, name: t('ex.go.main')));
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-44, -20), const Pt(-6, -20), const Pt(60, -20), const Pt(145, -20)], scope: HydraulicScope.mainline, name: t('ex.go.main')));
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-44, -20), const Pt(-44, 15)], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-6, -20), Pt(-6, mA), Pt(-6, mB)], scope: HydraulicScope.mainline, name: t('ex.go.main')));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-6, mA), Pt(-4, mA)], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-6, mB), Pt(-4, mB)], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(145, -20), const Pt(145, 15)], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': '$zg + $zt'}), valveIds: {vg.id, vt.id}, startHour: 22, durationHours: 0.5),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': fairwayValves[0].zoneName}), valveIds: {fairwayValves[0].id}, startHour: 22.5, durationHours: 0.75),
    SystemFlow(id: 'sf3', name: t('ex.shift', {'n': '3', 'z': fairwayValves[1].zoneName}), valveIds: {fairwayValves[1].id}, startHour: 23.25, durationHours: 0.75),
  ]);
  return p;
}

// ---------------------------------------------------------------- nursery

/// Three 12 × 48 m nursery beds under overhead micro-sprinklers on a 4 × 4 m
/// grid, one zone per bed, an elevated tank, a small pump and a disc filter;
/// short shifts.
Project buildNurseryExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.nu.name', client: 'ex.nu.client', site: 'ex.nu.site');
  for (final (x, y, z) in [(-16.0, -14.0, 100.3), (50.0, -14.0, 100.2), (-16.0, 54.0, 100.1), (50.0, 54.0, 100.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-16, -14, 50, 54), closed: true, name: t('ex.nu.lot')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-16, 57), text: t('ex.nu.title'), height: 1.8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(46, 50), kind: SymbolKind.northArrow, size: 2.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-13, -12), kind: SymbolKind.tank, size: 1.8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-13, -6), kind: SymbolKind.filterStation, size: 1.4));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-15.5, -13.7), text: t('ex.nu.tank'), height: 0.9));
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < 3; i++) {
    final x0 = 16.0 * i;
    final poly = _rect(x0, 0, x0 + 12, 48);
    final name = t('ex.nu.bed', {'n': '${i + 1}'});
    p.entities.add(PolylineEntity(id: p.newId(), points: poly, closed: true, name: name));
    p.entities.add(TextEntity(id: p.newId(), position: Pt(x0 + 0.5, 49), text: name, height: 1));
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(0, 1),
      lateralSpacing: 4,
      firstLateralOffset: 2,
      outletSpecId: 'micro',
      nozzleId: 'm70',
      outletSpacing: 4,
      outletOffsetHalf: true,
      headM: 15,
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev25',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.nu.crop'), netDepthMmPerDay: 6, efficiency: 0.8, useWaterBalance: true, etoMmDay: 5, kc: 1.0, awcMmPerM: 100, rootDepthM: 0.2, mad: 0.3));
  }
  const tank = Pt(-10, -12), pump = Pt(-10, -9), filter = Pt(-10, -6);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: tank, name: t('ex.nu.tank'), calculatePressure: true, waterLevelOffsetM: 2.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_small'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_disc50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [tank, pump, filter, for (final v in valves) Pt(v.position.x, -6)], scope: HydraulicScope.mainline, name: t('ex.nu.main')));
  for (final v in valves) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(v.position.x, -6), v.position], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  for (var i = 0; i < valves.length; i++) {
    p.systemFlows.add(SystemFlow(id: 'sf${i + 1}', name: t('ex.shift', {'n': '${i + 1}', 'z': valves[i].zoneName}), valveIds: {valves[i].id}, startHour: 6 + 0.5 * i, durationHours: 0.5));
  }
  return p;
}

// ---------------------------------------------------------------- subsurface drip sugarcane

/// Two sugarcane blocks on 20 mm PC dripline buried 0.3 m deep (180 m
/// laterals every 1.5 m), buried submains and mainline, reservoir, pump,
/// screen filter and an air valve; one block per shift.
Project buildSugarcaneExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.sc.name', client: 'ex.sc.client', site: 'ex.sc.site');
  for (final (x, y) in [(-20.0, -60.0), (390.0, -60.0), (-20.0, 110.0), (390.0, 110.0), (182.0, 45.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.003 * x + 0.002 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-16, -16, 380, 106), closed: true, name: t('ex.sc.field')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-16, -50), b: const Pt(380, -50), name: t('ex.sc.road')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-16, -56), b: const Pt(380, -56), name: t('ex.sc.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(60, -54.5), text: t('ex.sc.road'), height: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-16, 112), text: t('ex.sc.title'), height: 5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(372, 98), kind: SymbolKind.northArrow, size: 6));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(194, -44), kind: SymbolKind.tank, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(194, -38), kind: SymbolKind.pumpHouse, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(194, -32), kind: SymbolKind.filterStation, size: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(199, -45), text: t('ex.sc.reservoir'), height: 2));
  final blocks = <(List<Pt>, SubmainPosition)>[
    (_rect(0, 0, 180, 90), SubmainPosition.start),
    (_rect(184, 0, 364, 90), SubmainPosition.end),
  ];
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < blocks.length; i++) {
    final (poly, pos) = blocks[i];
    final name = t('ex.sc.block', {'n': '${i + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      lateralSpacing: 1.5,
      isTape: true,
      tapeSpecId: 'drip20pc_23_75',
      tapeInletHeadM: 15,
      submainPosition: pos,
      valveSpecId: 'ev80',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    for (final e in r.laterals) {
      if (e is TapeEntity) e.depth = 0.3;
    }
    r.submain?.depth = 0.6;
    r.stub?.depth = 0.6;
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.sc.cane'), netDepthMmPerDay: 6, efficiency: 0.95, useWaterBalance: true, etoMmDay: 6, kc: 1.2, awcMmPerM: 130, rootDepthM: 0.6, mad: 0.6, rowSpacingM: 1.5, wettedFraction: 0.5));
  }
  const reservoir = Pt(182, -44), pump = Pt(182, -38), filter = Pt(182, -32), air = Pt(182, -20), tee = Pt(182, -6);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: reservoir, name: t('ex.sc.reservoir'), calculatePressure: true, waterLevelOffsetM: 1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_mid'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_screen80'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: air, valveSpecId: 'air50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [reservoir, pump, filter, air, tee], scope: HydraulicScope.mainline, name: t('ex.sc.trunk'), depth: 0.8));
  final vw = valves[0].position, ve = valves[1].position;
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(vw.x - 4, -6), Pt(vw.x - 4, vw.y)], scope: HydraulicScope.mainline, name: t('ex.sc.west'), depth: 0.8));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(vw.x - 4, vw.y), vw], scope: HydraulicScope.mainline, name: t('name.stub'), depth: 0.8));
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(ve.x + 4, -6), Pt(ve.x + 4, ve.y)], scope: HydraulicScope.mainline, name: t('ex.sc.east'), depth: 0.8));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(ve.x + 4, ve.y), ve], scope: HydraulicScope.mainline, name: t('name.stub'), depth: 0.8));
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': valves[0].zoneName}), valveIds: {valves[0].id}, startHour: 6, durationHours: 6),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': valves[1].zoneName}), valveIds: {valves[1].id}, startHour: 12, durationHours: 6),
  ]);
  return p;
}

// ---------------------------------------------------------------- gravity-fed drip

/// A reservoir on a hilltop 40 m above two vegetable blocks on dripline: no
/// pump; a gate valve, a pressure reducing valve and a disc filter on the
/// mainline down the slope; one block per shift.
Project buildGravityExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.gr.name', client: 'ex.gr.client', site: 'ex.gr.site');
  // terrain: a 20 % slope from the field (y = 0, 100 m) up to the reservoir
  // (y = -225, 145 m); the field itself falls 0.5 % northwards
  for (var k = 0; k <= 9; k++) {
    final y = -25.0 * k;
    p.entities.add(ContourEntity(id: p.newId(), points: [Pt(-40, y), Pt(250, y)], elevation: 100 + 5.0 * k));
  }
  for (final (x, y) in [(-40.0, 80.0), (250.0, 80.0), (100.0, 40.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 - 0.005 * y));
  }
  p.entities.add(CircleEntity(id: p.newId(), center: const Pt(100, -212), radius: 8));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(100, -212), kind: SymbolKind.tank, size: 4));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(112, -214), text: t('ex.gr.reservoir'), height: 3));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(104, -22), text: t('ex.gr.prv'), height: 2));
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-8, 4, 212, 76), closed: true, name: t('ex.gr.field')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-8, 82), text: t('ex.gr.title'), height: 3.5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(206, 70), kind: SymbolKind.northArrow, size: 4));
  final blocks = <(List<Pt>, SubmainPosition)>[
    (_rect(0, 10, 100, 70), SubmainPosition.start),
    (_rect(104, 10, 204, 70), SubmainPosition.end),
  ];
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < blocks.length; i++) {
    final (poly, pos) = blocks[i];
    final name = t('ex.gr.block', {'n': '${i + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      lateralSpacing: 1.5,
      isTape: true,
      tapeSpecId: 'drip16_16_50',
      tapeInletHeadM: 10,
      submainPosition: pos,
      valveSpecId: 'ev40',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.gr.crop'), netDepthMmPerDay: 5, efficiency: 0.9, useWaterBalance: true, etoMmDay: 5, kc: 1.05, awcMmPerM: 120, rootDepthM: 0.4, mad: 0.45, plantSpacingM: 0.3, rowSpacingM: 1.5, wettedFraction: 0.5, emittersPerPlant: 2));
  }
  const reservoir = Pt(100, -210), gate = Pt(100, -204), prv = Pt(100, -20), filter = Pt(100, -14), tee = Pt(100, -6);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: reservoir, name: t('ex.gr.reservoir'), calculatePressure: true, waterLevelOffsetM: 2));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: gate, valveSpecId: 'gate50'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: prv, valveSpecId: 'prv50', settingM: 25));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_disc50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [reservoir, gate, prv, filter, tee], scope: HydraulicScope.mainline, name: t('ex.gr.main')));
  final vw = valves[0].position, ve = valves[1].position;
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(vw.x - 4, -6), Pt(vw.x - 4, vw.y)], scope: HydraulicScope.mainline, name: t('ex.gr.west')));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(vw.x - 4, vw.y), vw], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.entities.add(PipeEntity(id: p.newId(), points: [tee, Pt(ve.x + 4, -6), Pt(ve.x + 4, ve.y)], scope: HydraulicScope.mainline, name: t('ex.gr.east')));
  p.entities.add(PipeEntity(id: p.newId(), points: [Pt(ve.x + 4, ve.y), ve], scope: HydraulicScope.mainline, name: t('name.stub')));
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': valves[0].zoneName}), valveIds: {valves[0].id}, startHour: 6, durationHours: 3),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': valves[1].zoneName}), valveIds: {valves[1].id}, startHour: 9, durationHours: 3),
  ]);
  return p;
}

// ---------------------------------------------------------------- bananas

/// Two banana blocks under pressure-compensating micro-sprinklers at 5 × 5 m,
/// a well with a submersible pump, a disc filter and sloping ground; one
/// block per shift.
Project buildBananaExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.ba.name', client: 'ex.ba.client', site: 'ex.ba.site');
  for (final (x, y) in [(-40.0, -30.0), (120.0, -30.0), (-40.0, 140.0), (120.0, 140.0), (50.0, 60.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.01 * x + 0.004 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-36, -26, 116, 134), closed: true, name: t('ex.ba.field')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-36, -34), b: const Pt(116, -34), name: t('ex.ba.road')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-36, -40), b: const Pt(116, -40), name: t('ex.ba.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(30, -38.5), text: t('ex.ba.road'), height: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-36, 139), text: t('ex.ba.title'), height: 4));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(110, 128), kind: SymbolKind.northArrow, size: 5));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-30, -20), kind: SymbolKind.well, size: 3));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-24, -8), kind: SymbolKind.filterStation, size: 2.5));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-34, -25), text: t('ex.ba.well'), height: 2));
  final valves = <ControlValveEntity>[];
  for (var i = 0; i < 2; i++) {
    final y0 = 64.0 * i;
    final poly = _rect(0, y0, 100, y0 + 60);
    final name = t('ex.ba.block', {'n': '${i + 1}'});
    final r = generateBlock(p, BlockOptions(
      polygon: poly,
      direction: const Pt(1, 0),
      lateralSpacing: 5,
      firstLateralOffset: 2.5,
      outletSpecId: 'micro_pc',
      nozzleId: 'mpc70',
      outletSpacing: 5,
      outletOffsetHalf: true,
      headM: 20,
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev50',
      valvePosition: ValvePosition.centre,
      submainStub: 2,
      zoneName: name,
      submainLabel: t('name.submain'),
      stubLabel: t('name.stub'),
      lateralPrefix: t('name.lateral'),
    ));
    p.entities.addAll(r.all);
    valves.add(r.valve!);
    p.entities.add(AreaEntity(id: p.newId(), points: poly, name: name, crop: t('ex.ba.banana'), netDepthMmPerDay: 5.5, efficiency: 0.9, useWaterBalance: true, etoMmDay: 5.5, kc: 1.1, awcMmPerM: 130, rootDepthM: 0.6, mad: 0.35, plantSpacingM: 2.5, rowSpacingM: 5, wettedFraction: 0.7, emittersPerPlant: 1));
  }
  const well = Pt(-30, -20), pump = Pt(-30, -14), filter = Pt(-30, -8);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: well, name: t('ex.ba.well'), calculatePressure: true, waterLevelOffsetM: -30));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_sub'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: filter, valveSpecId: 'filter_disc50'));
  p.entities.add(PipeEntity(id: p.newId(), points: [well, pump, filter, const Pt(-6, -8), for (final v in valves) Pt(-6, v.position.y)], scope: HydraulicScope.mainline, name: t('ex.ba.main')));
  for (final v in valves) {
    p.entities.add(PipeEntity(id: p.newId(), points: [Pt(-6, v.position.y), v.position], scope: HydraulicScope.mainline, name: t('name.stub')));
  }
  p.systemFlows.addAll([
    SystemFlow(id: 'sf1', name: t('ex.shift', {'n': '1', 'z': valves[0].zoneName}), valveIds: {valves[0].id}, startHour: 6, durationHours: 3),
    SystemFlow(id: 'sf2', name: t('ex.shift', {'n': '2', 'z': valves[1].zoneName}), valveIds: {valves[1].id}, startHour: 9, durationHours: 3),
  ]);
  return p;
}

// ---------------------------------------------------------------- sector pivot with end gun

/// A 250 m pivot on soybean sweeping 270° so that the farmstead quadrant
/// stays free, with a 12 m³/h end gun; a pond, a 30 hp pump and a gate valve.
Project buildSectorPivotExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.sp.name', client: 'ex.sp.client', site: 'ex.sp.site');
  const centre = Pt(320, 320);
  const radius = 250.0;
  for (var i = 0; i <= 4; i++) {
    final y = 160.0 * i;
    p.entities.add(ContourEntity(id: p.newId(), points: [Pt(-20, y), Pt(660, y)], elevation: 100 + 0.004 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(0, 0, 640, 640), closed: true, name: t('ex.sp.boundary')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-40, -30), b: const Pt(680, -30), name: t('ex.sp.road')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(0, 668), text: t('ex.sp.title'), height: 12));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(620, 616), kind: SymbolKind.northArrow, size: 12));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(560, 60), kind: SymbolKind.building, size: 10));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(600, 60), kind: SymbolKind.building, size: 10));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(540, 36), text: t('ex.sp.farm'), height: 6));
  p.entities.add(CircleEntity(id: p.newId(), center: const Pt(480, 160), radius: 22));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(462, 124), text: t('ex.sp.pond'), height: 6));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(505, 190), kind: SymbolKind.pumpHouse, size: 7));
  final name = t('ex.sp.pivot');
  p.entities.add(AreaEntity(id: p.newId(), points: [centre, for (var i = 0; i <= 36; i++) centre + Pt.polar(radius + 8, 1.5 * math.pi * i / 36)], name: t('ex.sp.field'), crop: t('ex.sp.soy'), netDepthMmPerDay: 6, efficiency: 0.85, useWaterBalance: true, etoMmDay: 6, kc: 1.1, awcMmPerM: 120, rootDepthM: 0.5, mad: 0.5));
  p.entities.add(PivotEntity(
    id: p.newId(),
    center: centre,
    radiusM: radius,
    angleDeg: 135,
    kind: PivotKind.pivot,
    sectorDeg: 270,
    spanLengthM: 50,
    grossDepthMm: 8,
    hoursPerCycle: 24,
    endPressureM: 14,
    endThrowM: 8,
    endGunFlow: 12 * m3sPerM3h,
    endGunPressureM: 30,
    name: name,
    zoneName: name,
    sprinklerSpacingM: 2.5,
    machineCost: 380000,
  ));
  const pond = Pt(480, 160), pump = Pt(505, 160), gate = Pt(515, 160);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: pond, name: t('ex.sp.pond'), calculatePressure: true, waterLevelOffsetM: -1.5));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_big'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: gate, valveSpecId: 'gate100'));
  p.entities.add(PipeEntity(id: p.newId(), points: [pond, pump, gate, const Pt(430, 240), centre], scope: HydraulicScope.mainline, name: t('ex.sp.adductor')));
  return p;
}

// ---------------------------------------------------------------- linear move

/// A 392 m lateral-move machine on wheat travelling 800 m along a canal,
/// fed at the inlet end by a 30 hp pump with a check valve.
Project buildLinearExample(Tr t, String lang) {
  final p = _newProject(t, lang, name: 'ex.li.name', client: 'ex.li.client', site: 'ex.li.site');
  for (final (x, y) in [(-80.0, -40.0), (440.0, -40.0), (-80.0, 840.0), (440.0, 840.0), (200.0, 400.0)]) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.003 * x + 0.002 * y));
  }
  p.entities.add(PolylineEntity(id: p.newId(), points: _rect(-70, -20, 430, 820), closed: true, name: t('ex.li.boundary')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-50, -20), b: const Pt(-50, 820), name: t('ex.li.canal')));
  p.entities.add(LineEntity(id: p.newId(), a: const Pt(-44, -20), b: const Pt(-44, 820), name: t('ex.li.canal')));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-68, 400), text: t('ex.li.canal'), height: 6));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-70, 840), text: t('ex.li.title'), height: 14));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(410, 800), kind: SymbolKind.northArrow, size: 14));
  p.entities.add(SymbolEntity(id: p.newId(), position: const Pt(-36, 24), kind: SymbolKind.pumpHouse, size: 8));
  p.entities.add(TextEntity(id: p.newId(), position: const Pt(-30, 10), text: t('ex.li.intake'), height: 5));
  final name = t('ex.li.machine');
  p.entities.add(AreaEntity(id: p.newId(), points: _rect(0, 0, 400, 800), name: t('ex.li.field'), crop: t('ex.li.wheat'), netDepthMmPerDay: 5.5, efficiency: 0.85, useWaterBalance: true, etoMmDay: 5.5, kc: 1.15, awcMmPerM: 120, rootDepthM: 0.8, mad: 0.55));
  p.entities.add(PivotEntity(
    id: p.newId(),
    center: const Pt(0, 0),
    radiusM: 392,
    angleDeg: 0,
    kind: PivotKind.linear,
    travelM: 800,
    spanLengthM: 56,
    grossDepthMm: 8,
    hoursPerCycle: 24,
    endPressureM: 14,
    endThrowM: 8,
    name: name,
    zoneName: name,
    sprinklerSpacingM: 2.5,
    machineCost: 520000,
  ));
  const intake = Pt(-47, 0), pump = Pt(-40, 0), check = Pt(-32, 0);
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: intake, name: t('ex.li.intake'), calculatePressure: true, waterLevelOffsetM: -2));
  p.entities.add(PumpEntity(id: p.newId(), position: pump, pumpSpecId: 'pump_big'));
  p.entities.add(MiscHydraulicEntity(id: p.newId(), position: check, valveSpecId: 'check100'));
  p.entities.add(PipeEntity(id: p.newId(), points: [intake, pump, check, const Pt(0, 0)], scope: HydraulicScope.mainline, name: t('ex.li.main')));
  return p;
}
