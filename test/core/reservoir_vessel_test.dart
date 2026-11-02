// 1.6.0 MOT+: the reservoir or dam behind a water supply (PRD-16) — its
// stage–area–volume curve from the terrain, the days of demand it holds,
// its level through the 24-hour simulation — and the air vessel drawn at a
// junction of the mainline (PRD-31), in the bill of materials and in the
// transient study.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/reservoir.dart';
import 'package:opencadirrigation/core/design/transient_analysis.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A closed square outline of side [side] centred at [c].
PolylineEntity square(String id, Pt c, double side) => PolylineEntity(
  id: id,
  points: [c + Pt(-side / 2, -side / 2), c + Pt(side / 2, -side / 2), c + Pt(side / 2, side / 2), c + Pt(-side / 2, side / 2)],
  closed: true,
);

/// A micro-sprinkler zone fed by a pump from a supply 100 m away; [onSupply]
/// sets the supply up, [vessel] puts an air vessel just after the pump.
Project pumped({void Function(Project p, WaterSupplyEntity s)? onSupply, double vessel = 0, double mainLength = 100}) {
  final p = Project();
  final block = generateBlock(
    p,
    BlockOptions(
      polygon: [Pt.zero, const Pt(40, 0), const Pt(40, 24), const Pt(0, 24)],
      direction: const Pt(1, 0),
      lateralSpacing: 4,
      outletSpecId: 'micro',
      nozzleId: 'm50',
      outletSpacing: 3.5,
      headM: 15,
      valveSpecId: 'ev50',
      zoneName: 'Zona 1',
    ),
  );
  p.entities.addAll(block.all);
  final v = block.valve!;
  final src = v.position + Pt(-mainLength, 0);
  p.entities.add(PipeEntity(id: 'main', points: [src, v.position], scope: HydraulicScope.mainline, name: 'Main'));
  final s = WaterSupplyEntity(id: 'src', position: src, name: 'Pond', calculatePressure: false, designHeadM: 0);
  p.entities.add(s);
  p.entities.add(PumpEntity(id: 'pump', position: src + const Pt(3, 0), pumpSpecId: 'pump_c2', name: 'Pump'));
  if (vessel > 0) p.entities.add(JunctionEntity(id: 'vessel', position: src + const Pt(6, 0), scope: HydraulicScope.mainline, vesselLiters: vessel, vesselCost: 900));
  onSupply?.call(p, s);
  return p;
}

void main() {
  group('the basin of a reservoir', () {
    test('an excavated reservoir: vertical walls hold the box, sloping sides the frustum', () {
      final p = Project()..entities.add(PolylineEntity(id: 'pond', points: const [Pt(0, 0), Pt(40, 0), Pt(40, 20), Pt(0, 20)], closed: true));
      final s = WaterSupplyEntity(
        id: 'src',
        position: const Pt(20, 10),
        reservoir: ReservoirSpec(outlineId: 'pond', kind: ReservoirKind.excavated, fullLevelM: 100, bottomM: 97, sideSlope: 0),
      );
      p.entities.add(s);
      final box = reservoirStudy(p, s)!;
      expect(box.messages, isEmpty);
      expect(box.bottom, closeTo(97, 1e-9));
      expect(box.volume, closeTo(40 * 20 * 3, 0.01 * 2400));
      expect(box.surfaceArea, closeTo(800, 0.01 * 800));
      // sides of 2 horizontal per vertical: ∫ depth × perimeter of the inset
      s.reservoir!.sideSlope = 2;
      final sloped = reservoirStudy(p, s)!;
      expect(sloped.volume, closeTo(1464, 0.02 * 1464));
      // the ground at the full level all round: the cut is the water held
      expect(sloped.cut, closeTo(sloped.volume, 0.02 * sloped.volume));
      expect(sloped.curve.first.volume, 0);
      expect(sloped.curve.last.level, closeTo(100, 1e-9));
      for (var i = 1; i < sloped.curve.length; i++) {
        expect(sloped.curve[i].volume, greaterThanOrEqualTo(sloped.curve[i - 1].volume));
      }
    });

    test('a dam: the ground inside the outline is the basin', () {
      // an inverted pyramid 10 m deep under a square of 100 m
      final p = Project();
      for (final (x, y, z) in [(0.0, 0.0, 105.0), (100.0, 0.0, 105.0), (100.0, 100.0, 105.0), (0.0, 100.0, 105.0), (50.0, 50.0, 95.0)]) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
      }
      p.entities.add(PolylineEntity(id: 'dam', points: const [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)], closed: true));
      final s = WaterSupplyEntity(id: 'src', position: const Pt(50, 50), reservoir: ReservoirSpec(outlineId: 'dam', fullLevelM: 105, minLevelM: 99));
      p.entities.add(s);
      final st = reservoirStudy(p, s)!;
      expect(st.bottom, closeTo(95, 0.2));
      expect(st.volume, closeTo(100 * 100 * 10 / 3, 0.02 * 3333));
      expect(st.usableVolume, closeTo(st.volume - st.volumeAt(99), 1e-9));
      // the supply draws from the lowest operating level
      final m = NetworkBuilder(p).build();
      expect(m.nodes[m.supplyNodes['src']]!.elevation, closeTo(99, 1e-9));
    });

    test('days of demand and filling time; the file keeps the reservoir', () {
      final st = ReservoirStudy(
        supplyId: 's',
        curve: const [ReservoirStage(level: 0, area: 1000, volume: 0), ReservoirStage(level: 2, area: 1000, volume: 2000)],
        bottom: 0,
        fullLevel: 2,
        minLevel: 0.5,
        initialLevel: 2,
        inflow: 10 / 3600,
        dailyDemand: 500,
      );
      expect(st.usableVolume, closeTo(1500, 1e-9));
      // 500 m³ drawn, 240 m³ flowing in a day
      expect(st.autonomyDays, closeTo(1500 / 260, 1e-9));
      expect(st.fillHours, closeTo(150, 1e-9));
      final s = WaterSupplyEntity(id: 's', position: Pt.zero, reservoir: ReservoirSpec(outlineId: 'o', kind: ReservoirKind.excavated, fullLevelM: 12, minLevelM: 10, inflow: 0.01));
      final back = Entity.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>) as WaterSupplyEntity;
      expect(back.reservoir!.kind, ReservoirKind.excavated);
      expect(back.reservoir!.minLevelM, 10);
      expect(back.reservoir!.inflow, 0.01);
      expect(WaterSupplyEntity(id: 's', position: Pt.zero).toJson().containsKey('res'), isFalse);
    });
  });

  group('the level of a reservoir through the day', () {
    Project pond({double inflow = 0, double? initial}) => pumped(
      onSupply: (p, s) {
        p.entities.add(square('pond', s.position, 10));
        s.reservoir = ReservoirSpec(outlineId: 'pond', kind: ReservoirKind.excavated, fullLevelM: 0, minLevelM: -2.9, initialLevelM: initial, bottomM: -3, sideSlope: 0, inflow: inflow / 3600);
        p.systemFlows.add(SystemFlow(id: 'f1', name: 'Turno 1', valveIds: {p.entities.whereType<ControlValveEntity>().single.id}, startHour: 6, durationHours: 8));
      },
    );

    test('it falls by what the supply delivers over the area of the water', () {
      final p = pond();
      final r = Designer(p).designAll();
      final day = simulateDay(p, results: r);
      final lv = day.levels['src'];
      expect(lv, isNotNull);
      expect(lv!.length, day.times.length);
      expect(lv.first, closeTo(0, 1e-9));
      // 100 m² of water: the volume of the day over the area
      expect(lv.last, closeTo(-day.volume / 100, 0.02 * day.volume / 100));
      expect(lv.reduce(math.min), lessThan(-0.05));
    });

    test('an inflow fills it again, up to the full level', () {
      final p = pond(inflow: 6, initial: -1);
      final r = Designer(p).designAll();
      final day = simulateDay(p, results: r);
      final lv = day.levels['src']!;
      expect(lv.first, closeTo(-1, 1e-9));
      // 6 m³/h in, about 3.6 m³/h out for 8 hours: full before midnight
      expect(lv.last, closeTo(0, 1e-6));
      expect(lv.reduce(math.max), lessThanOrEqualTo(1e-9));
      expect(jsonEncode(EpsDay.fromJson(jsonDecode(jsonEncode(day.toJson())) as Map<String, dynamic>).levels['src']), jsonEncode(lv));
    });
  });

  group('an air vessel at a junction of the mainline', () {
    test('kept in the file only when there is one, and in the bill of materials', () {
      expect(JunctionEntity(id: 'j', position: Pt.zero).toJson().keys, isNot(contains('vl')));
      final j = JunctionEntity(id: 'j', position: Pt.zero, scope: HydraulicScope.mainline, vesselLiters: 500, vesselGasLiters: 200, vesselConnectionMm: 80, vesselCost: 900);
      final back = Entity.fromJson(jsonDecode(jsonEncode(j.toJson())) as Map<String, dynamic>) as JunctionEntity;
      expect([back.vesselLiters, back.vesselGasLiters, back.vesselConnectionMm, back.vesselCost], [500, 200, 80, 900]);
      expect(back.clone().vesselLiters, 500);
      final r = Designer(pumped(vessel: 500)).designAll();
      final line = r.bom.where((l) => l.category == 'bom.devices' && l.description.contains('500 L')).single;
      expect(line.unitCost, 900);
    });

    test('the transient study puts it into the model: a pump trip falls less after it', () {
      double lowest(Project p) {
        final r = Designer(p).designAll();
        final a = TransientStudy(p, results: r, options: const TransientStudyOptions(scenarios: {TransientScenario.pumpTrip})).analyze();
        return a.pipes.where((e) => e.entityId == 'main').map((e) => e.minPressure).reduce(math.min);
      }

      final without = lowest(pumped(mainLength: 800));
      final withVessel = lowest(pumped(mainLength: 800, vessel: 800));
      expect(withVessel, greaterThan(without));
    });
  });
}
