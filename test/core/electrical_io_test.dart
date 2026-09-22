import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

ReportLabels _labels() => ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w);

/// A zone with one valve, a controller and its wire route.
Project _wired({double routeM = 30, int stations = 12}) {
  final p = Project();
  p.entities.addAll([
    WaterSupplyEntity(id: 'ws', position: const Pt(-20, 0), calculatePressure: false, designHeadM: 45, maxHeadM: 60, designFlow: 10 * m3sPerM3h, maxFlow: 12 * m3sPerM3h),
    PipeEntity(id: 'mp', points: const [Pt(-20, 0), Pt(-5, 0)], scope: HydraulicScope.mainline),
    ControlValveEntity(id: 'v', position: const Pt(-5, 0), zoneName: 'Z1', valveSpecId: 'ev40'),
    PipeEntity(id: 'zp', points: const [Pt(-5, 0), Pt(0, 0), Pt(20, 0)], scope: HydraulicScope.zone),
    OutletEntity(id: 'o1', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
    OutletEntity(id: 'o2', position: const Pt(20, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
    ControllerEntity(id: 'k', position: Pt(-5, routeM), name: 'K', stations: stations, cost: 500),
    WireEntity(id: 'w', points: [Pt(-5, routeM), const Pt(-5, 0)]),
  ]);
  return p;
}

void main() {
  group('design and reports', () {
    test('the Electrical report table lists every valve and the common of each controller', () {
      final p = _wired();
      final r = Designer(p).designAll();
      final tables = buildReportTables(project: p, results: r, labels: _labels());
      final el = tables.firstWhere((t) => t.key == 'electrical');
      expect(el.rows.length, 2);
      expect(el.rows.first.first, 'Z1');
      expect(el.rows.first[2], 1, reason: 'station 1');
      expect(el.rows.last.first, 'elec.commonRow');
      expect(el.warn, [false, false]);
      // results survive the project file
      final back = Designer(Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>)).designAll();
      expect(back.electrical!.runs.single.stationWireId, r.electrical!.runs.single.stationWireId);
    });

    test('without wiring there is no Electrical table and no electrical BOM', () {
      final p = _wired()..entities.removeWhere((e) => e is ControllerEntity || e is WireEntity);
      final r = Designer(p).designAll();
      expect(r.electrical, isNull);
      expect(buildReportTables(project: p, results: r, labels: _labels()).any((t) => t.key == 'electrical'), isFalse);
      expect(r.bom.any((l) => l.category == 'bom.electrical'), isFalse);
    });

    test('electrical parameters round-trip and old files get the defaults', () {
      final p = DesignParameters(solenoidInrushA: 0.5, solenoidHoldingA: 0.3, solenoidMinVolts: 19, wireSlackPct: 5);
      final back = DesignParameters.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect([back.solenoidInrushA, back.solenoidHoldingA, back.solenoidMinVolts, back.wireSlackPct], [0.5, 0.3, 19, 5]);
      final old = DesignParameters.fromJson({'units': null});
      expect([old.solenoidInrushA, old.solenoidHoldingA, old.solenoidMinVolts, old.wireSlackPct], [0.37, 0.22, 20, 10]);
    });

    test('standard controller sizes', () {
      expect(standardStations(3), 4);
      expect(standardStations(12), 12);
      expect(standardStations(13), 16);
      expect(standardStations(150), 150);
    });
  });

  group('check and assistant', () {
    test('the design check reports wiring problems before the design', () {
      // two valves on the route of a one-station controller, a third off the routes
      final p = _wired(stations: 1);
      p.entities.addAll([
        ControlValveEntity(id: 'v2', position: const Pt(-5, -40), zoneName: 'Z2'),
        WireEntity(id: 'w2', points: const [Pt(-5, 0), Pt(-5, -40)]),
        ControlValveEntity(id: 'v3', position: const Pt(60, 60), zoneName: 'Z3'),
      ]);
      final issues = runDesignCheck(p).issues;
      expect(issues.where((i) => i.code == 'elec_unwired').expand((i) => i.entityIds), ['v3']);
      final st = issues.firstWhere((i) => i.code == 'elec_stations');
      expect(st.severity, CheckSeverity.error);
      expect(st.entityIds, ['k']);
    });

    test('every wiring message is explained, and the stations fix picks a standard controller', () {
      for (final code in ['elec_no_controller', 'elec_unwired', 'elec_wire_orphan', 'elec_ctrl_unwired', 'elec_no_wires', 'elec_stations', 'elec_voltage', 'elec_simultaneous']) {
        expect(adviceCodes, contains(code));
      }
      final p = _wired(stations: 1);
      p.entities.addAll([
        ControlValveEntity(id: 'v2', position: const Pt(-5, 20), zoneName: 'Z2'),
        ControlValveEntity(id: 'v3', position: const Pt(-5, 10), zoneName: 'Z3'),
      ]);
      final r = Designer(p).designAll();
      final advice = buildAdvice(p, results: r);
      final a = advice.firstWhere((x) => x.code == 'elec_stations');
      expect(a.level, AdviceLevel.error);
      expect(a.fixes.first, FixKind.controllerStations);
      final res = applyFix(p, a, FixKind.controllerStations, results: r);
      expect(res.ok, isTrue);
      expect((p.byId('k') as ControllerEntity).stations, 4);
    });

    test('enable wires: the disabled thicker wires, or the defaults when the catalogue has none', () {
      final p = _wired(routeM: 3000);
      for (final w in p.catalog.wires) {
        w.enabled = w.id == 'w1';
      }
      final r = Designer(p).designAll();
      final advice = buildAdvice(p, results: r);
      final a = advice.firstWhere((x) => x.code == 'elec_voltage');
      expect(a.fixes, [FixKind.enableWires]);
      expect(applyFix(p, a, FixKind.enableWires, results: r).ok, isTrue);
      expect(p.catalog.wires.every((w) => w.enabled), isTrue);
      p.catalog.wires.clear();
      final noWires = Advice(code: 'elec_no_wires', raw: 'elec_no_wires', level: AdviceLevel.warning);
      expect(applyFix(p, noWires, FixKind.enableWires).ok, isTrue);
      expect(p.catalog.wires, isNotEmpty);
      // the defaults come with the AWG sizes disabled: enabled next
      expect(p.catalog.wires.any((w) => !w.enabled), isTrue);
      expect(applyFix(p, noWires, FixKind.enableWires).ok, isTrue);
      expect(applyFix(p, noWires, FixKind.enableWires).ok, isFalse, reason: 'nothing left to enable');
      expect(autoSafeFixes, containsAll([FixKind.enableWires, FixKind.controllerStations]));
    });
  });

  group('exports', () {
    test('DXF and DWG carry controllers, wires and the new dimensions', () {
      final p = _wired();
      p.entities.addAll([
        OrdinateDimensionEntity(id: 'od', point: const Pt(10, 5), leaderEnd: const Pt(10, 15)),
        RadialDimensionEntity(id: 'rd', center: Pt.zero, point: const Pt(2, 0), diameter: true),
      ]);
      final ex = ProjectExporter(project: p, labels: _labels());
      final doc = ex.dxfDocument();
      expect(doc.entities.where((e) => e.layer == Layers.wires && e.type == 'POLYLINE').length, 1);
      expect(doc.entities.any((e) => e.layer == Layers.controllers && e.closed), isTrue);
      expect(doc.entities.any((e) => e.type == 'TEXT' && e.text == 'K'), isTrue);
      expect(doc.entities.any((e) => e.type == 'TEXT' && e.text == 'X 10.00'), isTrue);
      expect(doc.entities.any((e) => e.type == 'TEXT' && e.text.startsWith('Ø 4')), isTrue);
      final dia = doc.entities.firstWhere((e) => e.type == 'LINE' && e.layer == Layers.dimensions);
      expect(dia.points.first, const Pt(-2, 0), reason: 'a diameter line crosses the circle');
      // the DWG writer takes the same document and reads back
      final back = DwgReader.parse(ex.dwg()).document;
      expect(back.entities.where((e) => e.layer == Layers.wires).length, 1);
    });

    test('GeoJSON lists controllers and wire routes', () {
      final p = _wired()..meta.georef = GeoReference.fromLatLonOrigin(-22.9, -47.06);
      final gj = jsonDecode(ProjectExporter(project: p, labels: _labels()).geoJson()) as Map<String, dynamic>;
      final types = [for (final f in gj['features'] as List) ((f as Map)['properties'] as Map)['type']];
      expect(types, containsAll(['controller', 'wire']));
    });

    test('plot: part circles open counter-clockwise from their orientation, as on the screen', () {
      final p = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3_90', headM: 25, arcDeg: 90, orientationDeg: 0));
      final scene = buildPlotScene(p, unitsPerMm: 0.5);
      final sector = scene.items.whereType<PlotPath>().firstWhere((x) => x.layer == Layers.wettedRadii);
      // the north-east quarter: every point has x ≥ 0 and y ≥ 0
      expect(sector.points.every((q) => q.x >= -1e-9 && q.y >= -1e-9), isTrue, reason: '${sector.points.take(4).toList()}');
      expect(sector.points.any((q) => q.y > 5), isTrue);
    });

    test('plot: controller symbol, dashed wires, ordinate and diameter dimensions', () {
      final p = _wired();
      p.entities.addAll([
        OrdinateDimensionEntity(id: 'od', point: const Pt(10, 5), leaderEnd: const Pt(20, 5), xAxis: false),
        RadialDimensionEntity(id: 'rd', center: Pt.zero, point: const Pt(2, 0), diameter: true),
      ]);
      final scene = buildPlotScene(p, unitsPerMm: 0.5, t: (k, [a]) => k);
      expect(scene.items.whereType<PlotPath>().any((x) => x.layer == Layers.wires && x.dashed), isTrue);
      expect(scene.items.whereType<PlotText>().any((x) => x.text == 'C'), isTrue);
      expect(scene.items.whereType<PlotText>().any((x) => x.text == 'Y 5.00'), isTrue, reason: 'a horizontal leader dimensions Y');
      expect(scene.items.whereType<PlotText>().any((x) => x.text.startsWith('Ø')), isTrue);
    });
  });
}
