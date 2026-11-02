import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/field_machines.dart';
import 'package:opencadirrigation/core/design/multi_pivot.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// PRD-18 (several pivots in a property with their common mainline) and
/// PRD-14 (traveller lanes and furrow sets as parts of the design: demands
/// on the mainline, times and depths, the report and the bill).
void main() {
  final t = I18n('pt');
  const field = [Pt(0, 0), Pt(2000, 0), Pt(2000, 1500), Pt(0, 1500)];

  group('several pivots', () {
    test('a 2000 × 1500 m field: machines apart and inside, most of it irrigated', () {
      final l = layoutPivots(field, const MultiPivotOptions(supply: Pt(0, 0)));
      expect(l.pivots.length, greaterThanOrEqualTo(4));
      expect(l.coverage, greaterThan(0.7));
      expect(l.fieldAreaM2, closeTo(3e6, 1));
      for (var i = 0; i < l.pivots.length; i++) {
        final a = l.pivots[i];
        expect(a.fullCircle, isTrue);
        // inside the field with the clearance
        expect(math.min(math.min(a.center.x, 2000 - a.center.x), math.min(a.center.y, 1500 - a.center.y)), greaterThanOrEqualTo(a.irrigatedRadius + 5 - 1e-6));
        expect(a.flow, closeTo(pivotDesignFlow(a.areaM2, 8, 21), 1e-12));
        for (var j = i + 1; j < l.pivots.length; j++) {
          final b = l.pivots[j];
          expect(a.center.distanceTo(b.center), greaterThanOrEqualTo(a.irrigatedRadius + b.irrigatedRadius + 5 - 1e-6), reason: 'pivots $i and $j');
        }
      }
      // the mainline joins the supply and every pivot point
      expect(l.mainline, hasLength(l.pivots.length));
      expect(l.mainline.first.$1, const Pt(0, 0));
    });

    test('the flow allowed drops the smallest machines; an obstacle is kept clear of', () {
      final all = layoutPivots(field, const MultiPivotOptions());
      final limited = layoutPivots(field, MultiPivotOptions(maxTotalFlow: all.totalFlow * 0.6));
      expect(limited.totalFlow, lessThanOrEqualTo(all.totalFlow * 0.6 + 1e-12));
      expect(limited.messages, contains('mpivot_flow_limit'));
      const pond = [Pt(900, 650), Pt(1100, 650), Pt(1100, 850), Pt(900, 850)];
      final withPond = layoutPivots(field, const MultiPivotOptions(obstacles: [pond]));
      for (final p in withPond.pivots) {
        for (final q in pond) {
          expect(p.center.distanceTo(q), greaterThan(p.irrigatedRadius - 1e-6));
        }
      }
      expect(layoutPivots(const [Pt(0, 0), Pt(50, 0), Pt(50, 50)], const MultiPivotOptions()).messages, contains('mpivot_none'));
    });

    test('the minimum spanning tree of a square is three sides', () {
      final tree = minimumSpanningTree(const [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)]);
      expect(tree, hasLength(3));
      final pts = const [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];
      expect(tree.fold(0.0, (s, e) => s + pts[e.$1].distanceTo(pts[e.$2])), closeTo(300, 1e-9));
    });
  });

  group('traveller lanes and furrow sets', () {
    test('lanes across a 600 × 400 m field: the wind table spacing, hydrants on the edge', () {
      final p = Project();
      final template = TravellerEntity(id: '', start: Pt.zero, end: const Pt(100, 0));
      var n = 0;
      final lanes = layoutTravellerLanes(p, const [Pt(0, 0), Pt(600, 0), Pt(600, 400), Pt(0, 400)], template, angleDeg: 90, newId: () => 'l${n++}');
      // 80 m wetted diameter, light wind, tapered nozzle: 75 % → 60 m, ten lanes over 600 m
      expect(lanes, hasLength(10));
      final xs = [for (final l in lanes) l.start.x]..sort();
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], closeTo(60, 1e-6));
      }
      for (final l in lanes) {
        expect(l.start.y, closeTo(0, 1e-6));
        // the run stops a wetted radius short of the far edge
        expect(l.runLengthM, closeTo(400 - 40, 1e-6));
        expect(l.id, startsWith('l'));
      }
    });

    Project lanesAndFurrows() {
      final p = Project();
      final main = p.catalog.pipesFor(PipeUsage.mainline).last;
      p.entities.addAll([
        WaterSupplyEntity(id: p.newId(), position: Pt.zero, designHeadM: 80, calculatePressure: false),
        PipeEntity(id: p.newId(), points: const [Pt(0, 0), Pt(400, 0), Pt(800, 0)], scope: HydraulicScope.mainline, pipeSpecId: main.id, computerSized: false),
        TravellerEntity(id: p.newId(), name: 'Faixa 1', start: const Pt(400, 0), end: const Pt(400, 300)),
        TravellerEntity(id: p.newId(), name: 'Faixa 2', start: const Pt(800, 0), end: const Pt(800, 300)),
        FurrowEntity(id: p.newId(), name: 'Sulcos', points: [const Pt(800, 0), const Pt(800, -100)], furrowsPerSet: 40),
      ]);
      final ids = [for (final e in p.entities) e.id];
      p.systemFlows.addAll([
        SystemFlow(id: 'f1', name: 'Faixa 1', valveIds: {ids[2]}, durationHours: 10),
        SystemFlow(id: 'f2', name: 'Faixa 2', valveIds: {ids[3]}, durationHours: 10),
        SystemFlow(id: 'f3', name: 'Sulcos', valveIds: {ids[4]}, durationHours: 10),
      ]);
      return p;
    }

    test('the items keep every field in the file', () {
      final p = lanesAndFurrows();
      final back = Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), jsonEncode(p.toJson()));
      final lane = back.entities.whereType<TravellerEntity>().first;
      expect(lane.isHydraulic, isTrue);
      expect(lane.hydraulicScope, HydraulicScope.mainline);
      final moved = lane.translated(const Pt(10, 5));
      expect(moved.start, const Pt(410, 5));
      final f = back.entities.whereType<FurrowEntity>().single;
      expect(f.furrowCount, (100 / 0.9).floor());
      expect(f.transformed(Affine.mirror(const Pt(0, 0), const Pt(0, 1))).leftSide, isFalse, reason: 'a mirror turns the side over');
    });

    test('each lane and the furrow set take their water from the mainline in their system flow', () {
      final p = lanesAndFurrows();
      final r = Designer(p, label: t.call).designAll(sizeZones: false, sizeMain: false);
      expect(r.unconnected, isEmpty);
      final a = r.agb!;
      expect(a.travellers, hasLength(2));
      for (final l in a.travellers) {
        // 45 m³/h of the default gun; 25 mm on the 60 m lane
        expect(l.flow * 3600, closeTo(45, 1e-9));
        expect(l.result.laneSpacingM, closeTo(60, 1e-9));
        expect(l.result.grossDepthMm, closeTo(25, 1e-9));
        expect(l.availableHead, isNotNull);
        expect(l.availableHead!, greaterThan(l.requiredHead));
        expect(l.requiredHead, closeTo(50 + l.result.hoseFrictionM + 7 + 2.5, 1e-9));
      }
      final f = a.furrows.single;
      expect(f.furrows, 111);
      expect(f.perSet, 40);
      expect(f.sets, 3);
      expect(f.setFlow, closeTo(f.inflow * 40, 1e-12));
      expect(f.cutoffS, greaterThan(f.advanceS));
      expect(f.availableHead, isNotNull);
      for (final flow in r.systemFlows) {
        expect(flow.totalFlow, greaterThan(0), reason: flow.name);
        expect(flow.valves, hasLength(1));
      }
      expect(r.systemFlows.firstWhere((x) => x.flowId == 'f3').totalFlow, closeTo(f.setFlow, 1e-6));
      // the bill: one reel for both lanes, two hydrants, the gated pipe and its gates
      final trav = [for (final l in r.bom) if (l.category == 'bom.travellers') l];
      expect(trav.where((l) => l.description.startsWith(t('agb.bom.traveller'))).single.quantity, 1);
      expect(trav.where((l) => l.description == t('agb.bom.hydrant')).single.quantity, 2);
      final surface = [for (final l in r.bom) if (l.category == 'bom.surface') l];
      expect(surface.where((l) => l.description.startsWith(t('agb.bom.gatedPipe'))).single.quantity, closeTo(100, 1e-9));
      expect(surface.where((l) => l.description == t('agb.bom.gate')).single.quantity, 111);
      final tables = buildReportTables(project: p, results: r, labels: ReportLabels(t: t.call, has: t.has, warning: t.warning));
      expect(tables.where((x) => x.key == 'travellers').single.rows, hasLength(2));
      expect(tables.where((x) => x.key == 'furrows').single.rows, hasLength(1));
      final back = DesignResults.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.agb!.travellers.first.availableHead, closeTo(a.travellers.first.availableHead!, 1e-9));
      expect(back.agb!.furrows.single.sets, 3);
    });

    test('a lane off the mainline is unconnected and asks nothing', () {
      final p = lanesAndFurrows();
      final lane = TravellerEntity(id: p.newId(), start: const Pt(400, 50), end: const Pt(400, 300));
      p.entities.add(lane);
      final r = Designer(p, label: t.call).designAll(sizeZones: false, sizeMain: false);
      expect(r.unconnected, contains(lane.id));
      expect(r.agb!.travellers.where((l) => l.laneId == lane.id), isEmpty);
      expect(fieldMachineDemand(p, lane), isNotNull);
      expect(fieldMachineDemand(p, PumpEntity(id: 'x', position: Pt.zero)), isNull);
    });
  });
}
