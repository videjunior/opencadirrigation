import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/pivot_electrical.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  test('motor current P/(√3·U·η·cos φ)', () {
    expect(motorCurrent(kw: 0.55, voltage: 480, efficiency: 0.70, powerFactor: 0.72), closeTo(550 / (math.sqrt(3) * 480 * 0.70 * 0.72), 1e-12));
    expect(motorCurrent(kw: 0, voltage: 480), 0);
  });

  group('three towers on 2.5 mm² (hand calculation)', () {
    const spec = PivotElectricalSpec(towerRadiiM: [50, 100, 150], voltage: 480, cableSlack: 0, cables: [CableOption(2.5, 7.41)]);
    final r = designPivotElectrical(spec, id: 'pv');
    final i = 550 / (math.sqrt(3) * 480 * 0.70 * 0.72);
    final ip = i * 0.72, iq = i * math.sqrt(1 - 0.72 * 0.72);
    const ohm = 7.41 * 1.25;
    double seg(int motors, {double startP = 0, double startQ = 0}) => math.sqrt(3) * 0.05 * (ohm * (motors * ip + startP) + 0.08 * (motors * iq + startQ));

    test('drop span by span with the motors beyond each span running (IEC 60364-5-52 Annex G)', () {
      final d1 = seg(3), d2 = d1 + seg(2), d3 = d2 + seg(1);
      expect(r.towers[0].runningDropPct, closeTo(100 * d1 / 480, 1e-9));
      expect(r.towers[1].runningDropPct, closeTo(100 * d2 / 480, 1e-9));
      expect(r.towers[2].runningDropPct, closeTo(100 * d3 / 480, 1e-9));
      expect(r.towers[2].volts, closeTo(480 - d3, 1e-9));
      expect(r.maxRunningDropPct, closeTo(100 * d3 / 480, 1e-9));
      expect(r.towers[0].spanCurrentA, closeTo(3 * i, 1e-9));
      expect(r.motorCurrentA, closeTo(i, 1e-12));
      expect(r.cableMm2, 2.5);
    });

    test('the last motor starting with the others running', () {
      final si = 6 * i;
      final sp = si * 0.4 - ip, sq = si * math.sqrt(1 - 0.16) - iq; // its running current replaced by the starting one
      final d = seg(3, startP: sp, startQ: sq) + seg(2, startP: sp, startQ: sq) + seg(1, startP: sp, startQ: sq);
      expect(r.towers[2].startingDropPct, closeTo(100 * d / 480, 1e-9));
      expect(r.maxStartingDropPct, closeTo(100 * d / 480, 1e-9));
    });

    test('generator: running kVA over the loading or the size that limits the starting dip', () {
      const kva = 0.55 / (0.70 * 0.72);
      expect(r.runningKva, closeTo(3 * kva, 1e-12));
      expect(r.largestStartingKva, closeTo(6 * kva, 1e-12));
      final need = math.max(3 * kva / 0.8, 0.2 * 6 * kva * 0.8 / 0.2);
      expect(r.generatorKvaRequired, closeTo(need, 1e-12));
      expect(r.generatorKva, 7.5);
      expect(generatorKvaForStart(startingKva: 100, reactance: 0.15, dip: 0.15), closeTo(85, 1e-9));
    });

    test('average power at a timer setting: towers run in proportion to their radius', () {
      final half = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: [50, 100, 150], timerPct: 50, cables: [CableOption(2.5, 7.41)]));
      expect(half.averagePowerKw, closeTo(0.55 / 0.70 * 0.5 * (50 + 100 + 150) / 150, 1e-12));
      expect(half.connectedKw, closeTo(3 * 0.55, 1e-12));
    });
  });

  group('cable choice, booster and long machines', () {
    test('the smallest section that keeps both drops within the limits', () {
      const radii = <double>[55, 110, 165, 220, 275, 330, 385, 440];
      final r = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: radii, voltage: 400, maxRunningDropPct: 3, maxStartingDropPct: 10));
      expect(r.maxRunningDropPct, lessThanOrEqualTo(3 + 1e-9));
      expect(r.maxStartingDropPct, lessThanOrEqualTo(10 + 1e-9));
      final smaller = iecCopperCables.where((c) => c.sectionMm2 < r.cableMm2).toList();
      expect(smaller, isNotEmpty);
      final prev = designPivotElectrical(PivotElectricalSpec(towerRadiiM: radii, voltage: 400, cables: [smaller.last], maxRunningDropPct: 3, maxStartingDropPct: 10));
      expect(prev.maxRunningDropPct > 3 || prev.maxStartingDropPct > 10, isTrue);
      expect(prev.warnings, isNotEmpty);
      expect(r.warnings, isEmpty);
      expect(r.towers.length, 8);
      expect(r.towers.last.cableM, closeTo(440 * 1.02, 1e-9));
    });

    test('end-gun booster: 120 gpm × 58 ft at 65 % (NEH 623 ch. 11) needs a 3 kW motor with the service factor', () {
      final r = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: [60, 120, 180, 240, 300, 360], boosterFlow: 120 * m3sPerGpm, boosterHeadM: 58 * metersPerFoot));
      expect(r.boosterShaftKw / 0.7457, closeTo(2.7, 0.05));
      expect(r.boosterMotorKw, 3);
      expect(r.boosterCurrentA, closeTo(motorCurrent(kw: 3, voltage: 480, efficiency: 0.8, powerFactor: 0.8), 1e-12));
      expect(r.connectedKw, closeTo(6 * 0.55 + 3, 1e-12));
      // the booster at the end tower dominates the drop and the start
      final without = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: [60, 120, 180, 240, 300, 360]));
      expect(r.cableMm2, greaterThanOrEqualTo(without.cableMm2));
      expect(r.largestStartingKva, closeTo(6 * 3 / 0.64, 1e-9));
    });

    test('supply cable and loads at the pivot point', () {
      final r = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: [100, 200], supplyCableM: 200, supplyCableMm2: 16, auxiliaryKw: 0.5, otherMotorKw: 15));
      expect(r.supplyCableMm2, 16);
      // the pump starting at the pivot point sets the starting drop
      expect(r.maxStartingDropPct, greaterThan(r.maxRunningDropPct));
      expect(r.largestStartingKva, closeTo(6 * 15 / (0.9 * 0.85), 1e-9));
      expect(r.generatorKva, greaterThanOrEqualTo(r.generatorKvaRequired));
      final back = PivotElectricalResult.fromJson(r.toJson());
      expect(back.towers.length, 2);
      expect(back.generatorKva, r.generatorKva);
      expect(back.maxStartingDropPct, closeTo(r.maxStartingDropPct, 1e-12));
    });

    test('a long low-voltage machine fails even on the largest cable', () {
      final r = designPivotElectrical(
        PivotElectricalSpec(towerRadiiM: [for (var i = 1; i <= 20; i++) 60.0 * i], voltage: 220, motorKw: 1.1, cables: const [CableOption(1.5, 12.1), CableOption(2.5, 7.41)]),
        id: 'pv',
      );
      expect(r.cableMm2, 2.5);
      expect(r.warnings, contains('pivot_elec_drop:pv'));
      expect(designPivotElectrical(const PivotElectricalSpec(towerRadiiM: []), id: 'x').warnings, contains('pivot_elec_no_towers:x'));
    });
  });
}
