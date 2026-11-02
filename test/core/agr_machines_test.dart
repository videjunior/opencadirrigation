import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/mechanised.dart';
import 'package:opencadirrigation/core/design/pivot_electrical.dart';
import 'package:opencadirrigation/core/design/pivot_package.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Machines after the sweep of 2026-11-01: a corner arm no longer doubles
/// the ring the main machine already waters (AGR-07), the average power of
/// a linear move counts every tower (AGR-18), the arm's drive tower is in
/// the electrical design (AGR-19) and a drive slower than the design cycle
/// is reported (AGR-22).
void main() {
  // pivot of 6 spans × 50 m (last tower at 300 m), 5 m end throw, 60 m arm
  // following a square field of 800 m set back 5 m; 10 mm in 24 h
  (Project, PivotEntity) cornerSystem({double? armThrow, double voltage = 0}) {
    final p = Project();
    final field = AreaEntity(id: 'field', points: const [Pt(-400, -400), Pt(400, -400), Pt(400, 400), Pt(-400, 400)]);
    final pv = PivotEntity(
      id: 'pv',
      center: Pt.zero,
      radiusM: 300,
      spanLengthM: 50,
      endThrowM: 5,
      grossDepthMm: 10,
      hoursPerCycle: 24,
      machine: PivotMachine(cornerArmLengthM: 60, guidePathId: 'field', guideOffsetM: 5, cornerArmThrowM: armThrow, voltage: voltage, towerSpeedMPerMin: 3),
    );
    p.entities.addAll([field, pv]);
    return (p, pv);
  }

  const rate = 10 / 1000 / (24 * 3600); // m/s

  group('corner arm and main machine (AGR-07)', () {
    test('with an arm the main package waters only to the hinge', () {
      final (p, pv) = cornerSystem();
      final m = analyzeMechanised(p, pv);
      final pkg = m.package;
      expect(pkg.lastTowerRadiusM, closeTo(300, 1e-9));
      // before: sized to 305 m (throw), the ring 300–305 m watered twice
      expect(pkg.effectiveRadiusM, closeTo(300, 1e-9));
      expect(pkg.systemFlow, closeTo(rate * math.pi * 300 * 300, 1e-12));
      // the last emitter no longer carries the throw ring: 5 915 L/h against 1 939 L/h before
      final last = pkg.outlets.last, prev = pkg.outlets[pkg.outlets.length - 2];
      expect(last.requiredFlow / prev.requiredFlow, lessThan(1.1));
      // the arm extended: the flow of an even depth to the hinge plus the arm's reach
      final arm = m.cornerArm!;
      final straight = arm.steps.reduce((a, b) => a.armDeg < b.armDeg ? a : b);
      expect(straight.banksOn, (1 << arm.banks.length) - 1);
      expect(straight.totalFlow, closeTo(rate * math.pi * math.pow(300 + 65, 2), rate * math.pi * 365 * 365 * 1e-6));
      // the same machine without the arm still throws its 5 m
      pv.machine.cornerArmLengthM = 0;
      expect(analyzeMechanised(p, pv).package.effectiveRadiusM, closeTo(305, 1e-9));
    });

    test('the arm has a throw of its own', () {
      final (p, pv) = cornerSystem(armThrow: 0);
      final arm = analyzeMechanised(p, pv).cornerArm!;
      final straight = arm.steps.reduce((a, b) => a.armDeg < b.armDeg ? a : b);
      expect(straight.totalFlow, closeTo(rate * math.pi * 360 * 360, rate * math.pi * 360 * 360 * 1e-6));
      // stored with the machine, and the machine's own throw kept
      expect(pv.endThrowM, 5);
      final back = PivotMachine.fromJson(jsonDecode(jsonEncode(pv.machine.toJson())) as Map<String, dynamic>);
      expect(back.cornerArmThrowM, 0);
      expect(PivotMachine().toJson().containsKey('cat'), isFalse);
    });
  });

  group('electrical design (AGR-18, AGR-19)', () {
    test('every tower of a linear move runs the timer fraction', () {
      const towers = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0];
      final pivot = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: towers, motorKw: 0.55, motorEfficiency: 0.7, voltage: 480));
      final linear = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: towers, motorKw: 0.55, motorEfficiency: 0.7, voltage: 480, linear: true));
      // pivot: Σ r/r_last = 4.5 towers' worth; linear: all 8 (it was 4.5, −44 %)
      expect(pivot.averagePowerKw, closeTo(4.5 * 0.55 / 0.7, 1e-9));
      expect(linear.averagePowerKw, closeTo(8 * 0.55 / 0.7, 1e-9));
      final half = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: towers, motorKw: 0.55, motorEfficiency: 0.7, voltage: 480, linear: true, timerPct: 50));
      expect(half.averagePowerKw, closeTo(4 * 0.55 / 0.7, 1e-9));
    });

    test('the drive tower of a corner arm is in the drops, the starting and the generator', () {
      final (p, pv) = cornerSystem(voltage: 480);
      final e = analyzeMechanised(p, pv).electrical!;
      expect(e.towers.length, 7);
      final arm = e.towers.last;
      expect(arm.arm, isTrue);
      expect(arm.radiusM, closeTo(360, 1e-9));
      expect(e.towers.where((t) => t.arm), hasLength(1));
      // the arm tower is the farthest load: the largest drop
      expect(arm.runningDropPct, greaterThanOrEqualTo(e.towers[5].runningDropPct));
      expect(e.connectedKw, closeTo(7 * 0.55, 1e-9));
      // and it counts in the average power like the last tower
      final mainOnly = designPivotElectrical(const PivotElectricalSpec(towerRadiiM: [50, 100, 150, 200, 250, 300], voltage: 480));
      expect(e.averagePowerKw, closeTo(mainOnly.averagePowerKw + 0.55 / 0.70, 1e-9));
      final back = PivotTowerElectrical.fromJson(jsonDecode(jsonEncode(arm.toJson())) as Map<String, dynamic>);
      expect(back.arm, isTrue);
    });
  });

  test('a drive slower than the design cycle is reported with the speed it needs (AGR-22)', () {
    final p = Project();
    final pv = PivotEntity(id: 'pv', center: Pt.zero, radiusM: 400, machine: PivotMachine(towerSpeedMPerMin: 1));
    p.entities.add(pv);
    final pkg = analyzeMechanised(p, pv).package;
    // 2π·400 m at 1 m/min: 41.9 h a revolution against the 24 h cycle
    expect(pkg.hoursAt100, closeTo(2 * math.pi * 400 / 60, 1e-9));
    expect(pkg.warnings, contains('pivot_pkg_slow_drive:pv'));
    expect(pkg.speedForCycleMPerMin, closeTo(2 * math.pi * 400 / (24 * 60), 1e-9));
    expect(pkg.depthAt100Mm, greaterThan(pv.grossDepthMm));
    expect(PivotPackageResult.fromJson(jsonDecode(jsonEncode(pkg.toJson())) as Map<String, dynamic>).speedForCycleMPerMin, closeTo(pkg.speedForCycleMPerMin, 1e-12));
    // fast enough: no message
    pv.machine.towerSpeedMPerMin = 3;
    expect(analyzeMechanised(p, pv).package.warnings.where((w) => w.startsWith('pivot_pkg_slow_drive')), isEmpty);
  });
}
