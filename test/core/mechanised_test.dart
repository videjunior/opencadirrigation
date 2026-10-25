import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/corner_arm.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/mechanised.dart';
import 'package:opencadirrigation/core/design/pivot_electrical.dart';
import 'package:opencadirrigation/core/design/pivot_package.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// A square field of half side [h] around the origin.
List<Pt> square(double h) => [Pt(-h, -h), Pt(h, -h), Pt(h, h), Pt(-h, h)];

/// A project with one pivot `pv` at the origin.
(Project, PivotEntity) pivotProject({double radius = 400, PivotMachine? machine}) {
  final p = Project();
  final pv = PivotEntity(id: 'pv', center: const Pt(0, 0), radiusM: radius, name: 'PV', machine: machine);
  p.entities.add(pv);
  return (p, pv);
}

/// The machine analyses of a pivot as the dialog and the designer run them
/// (`core/design/mechanised.dart`), the machine data on the entity and in
/// the files, and the results in the design, its JSON and the reports.
void main() {
  group('analyzeMechanised', () {
    test('the default machine: a regulated package and nothing else', () {
      final (p, pv) = pivotProject();
      final r = analyzeMechanised(p, pv);
      expect(r.pivotId, 'pv');
      final pk = r.package;
      // eight 50 m spans with outlets every 2.5 m from 1.25 m
      expect(pk.outlets.length, 160);
      expect(pk.outlets.first.distanceM, closeTo(1.25, 1e-9));
      expect(pk.lastTowerRadiusM, closeTo(400, 1e-9));
      // 8 mm a day over the circle watered to the 5 m throw of the last sprinkler
      expect(pk.effectiveRadiusM, closeTo(405, 1e-9));
      expect(pk.systemFlow, closeTo(math.pi * 405 * 405 * 0.008 / 86400, 1e-12));
      expect(pk.designFlow, closeTo(pk.systemFlow, 1e-12), reason: 'no end gun: the outlets share the system flow');
      expect(pk.outlets.fold(0.0, (s, o) => s + o.requiredFlow), closeTo(pk.systemFlow, 1e-12));
      // the standard regulator nearest the 14 m end pressure is 20 psi; it needs 5 psi more
      expect(pk.regulatorM, closeTo(20 / psiPerMeterHead, 1e-9));
      expect(pk.requiredInletHeadM, greaterThan(pk.regulatorM + 5 / psiPerMeterHead + 3.5 + 2));
      expect(pk.sprinklerCount, lessThanOrEqualTo(160));
      // no drive train: no timer chart
      expect(pk.timer, isEmpty);
      expect(r.warnings, contains('pivot_pkg_no_drive:pv'));
      expect(r.cornerArm, isNull);
      expect(r.vri, isNull);
      expect(r.electrical, isNull);
    });

    test('the timer chart from the speed of the last tower or from the drive train', () {
      final (p, pv) = pivotProject(machine: PivotMachine(towerSpeedMPerMin: 3));
      final pk = analyzeMechanised(p, pv).package;
      expect(pk.speedAt100MPerMin, 3);
      expect(pk.hoursAt100, closeTo(2 * math.pi * 400 / 3 / 60, 1e-9));
      final area = math.pi * 405 * 405;
      expect(pk.depthAt100Mm, closeTo(pk.systemFlow * pk.hoursAt100 * 3600 / area * 1000, 1e-9));
      expect(pk.timer.map((t) => t.timerPct), defaultTimerSettings);
      final half = pk.timer.firstWhere((t) => t.timerPct == 50);
      expect(half.depthMm, closeTo(2 * pk.depthAt100Mm, 1e-9));
      expect(pk.warnings, isNot(contains('pivot_pkg_no_drive:pv')));
      // a timer setting outside the default list joins the chart
      pv.machine.timerPct = 35;
      expect(analyzeMechanised(p, pv).package.timer.map((t) => t.timerPct), contains(35));
      // motor 1740 rpm, 40:1 and 52:1 gearboxes, 1.43 m tyre
      pv.machine
        ..towerSpeedMPerMin = 0
        ..motorRpm = 1740
        ..centerGearRatio = 40
        ..wheelGearRatio = 52
        ..tyreRollingDiameterM = 1.43;
      expect(analyzeMechanised(p, pv).package.speedAt100MPerMin, closeTo(1740 / (40 * 52) * math.pi * 1.43, 1e-9));
    });

    test('a corner arm whose tip follows the field outline set back 20 m', () {
      final p = Project();
      final field = AreaEntity(id: 'field', points: square(335));
      // last tower at 300 m, a 150 m arm: it reaches the 315 m guide square in the corners (315·√2 < 450)
      final pv = PivotEntity(
        id: 'pv',
        center: const Pt(0, 0),
        radiusM: 300,
        machine: PivotMachine(cornerArmLengthM: 150, guidePathId: 'field', guideOffsetM: 20, towerSpeedMPerMin: 3),
      );
      p.entities.addAll([field, pv]);
      final r = analyzeMechanised(p, pv);
      final a = r.cornerArm!;
      // the tip stays on the guide all the way round, but at the corners it
      // passes from one branch of the guide to the other far faster than an
      // arm drive moves: the design messages say so
      expect(a.maxTipSpeedRatio, greaterThan(cornerArmMaxTipSpeed));
      expect(a.warnings, ['corner_arm_jump:pv']);
      expect(a.steps, isNotEmpty);
      expect(a.steps.where((s) => s.state != CornerArmState.tracking), isEmpty);
      // the tip is on the guide square of half side 315 at every position
      final guide = square(315);
      for (final s in a.steps) {
        final tip = Pt.polar(s.tipRadiusM, degToRad(s.tipAzimuthDeg));
        var gap = double.infinity;
        for (var i = 0; i < 4; i++) {
          gap = math.min(gap, distanceToSegment(tip, guide[i], guide[(i + 1) % 4]));
        }
        expect(gap, lessThan(0.01), reason: 'machine at ${s.pivotDeg}°');
      }
      final tips = [for (final s in a.steps) s.tipRadiusM];
      expect(tips.reduce(math.min), closeTo(315, 0.5));
      expect(tips.reduce(math.max), greaterThan(400), reason: 'the arm reaches out towards the corners');
      // the arm opens in the corners and folds back along the sides
      final angles = [for (final s in a.steps) s.armDeg];
      expect(angles.reduce(math.max) - angles.reduce(math.min), greaterThan(60));
      expect(a.banks.length, 4);
      expect(a.addedAreaM2, greaterThan(0));
      expect(a.totalAreaM2, inInclusiveRange(math.pi * 305 * 305, 670 * 670));
      expect(a.mainFlow, closeTo(r.package.systemFlow, 1e-12));
      expect(a.peakFlow, greaterThan(a.mainFlow));
      expect(a.outline, isNotEmpty);
      // without the guide, no arm; a linear move has none either
      pv.machine.guidePathId = null;
      expect(analyzeMechanised(p, pv).cornerArm, isNull);
      pv.machine.guidePathId = 'field';
      pv.kind = PivotKind.linear;
      pv.travelM = 500;
      expect(analyzeMechanised(p, pv).cornerArm, isNull);
      // a guide that does not surround the pivot point
      pv.kind = PivotKind.pivot;
      field.points = [const Pt(500, 500), const Pt(600, 500), const Pt(600, 600)];
      expect(analyzeMechanised(p, pv).cornerArm!.warnings, contains('corner_arm_no_path:pv'));
    });

    test('variable rate from a sectors table: timer = 100·d100/d', () {
      final (p, pv) = pivotProject(machine: PivotMachine(towerSpeedMPerMin: 3));
      final d100 = analyzeMechanised(p, pv).package.depthAt100Mm;
      expect(d100, greaterThan(0));
      pv.machine.vriSectors.addAll([VriSectorDepth(0, 180, 2 * d100), VriSectorDepth(180, 360, d100)]);
      final v = analyzeMechanised(p, pv).vri!;
      expect(v.depthAt100Mm, closeTo(d100, 1e-12));
      expect(v.rows.length, 2);
      expect(v.rows[0].startDeg, 0);
      expect(v.rows[0].endDeg, 180);
      expect(v.rows[0].timerPct, closeTo(50, 1e-9));
      expect(v.rows[0].depthMm, closeTo(2 * d100, 1e-9));
      expect(v.rows[1].timerPct, closeTo(100, 1e-9));
      expect(v.maxDepthMm, closeTo(d100 * 100 / 5, 1e-9), reason: 'the slowest setting is 5 %');
      expect(v.toCsv().split('\n').first, 'start_deg,end_deg,timer_pct,depth_mm,target_mm');
      expect(v.warnings, isEmpty);
      // no drive: no depth at 100 %, no prescription
      pv.machine.towerSpeedMPerMin = 0;
      expect(analyzeMechanised(p, pv).vri, isNull);
    });

    test('variable rate from zones of the drawing, with bank control', () {
      final (p, pv) = pivotProject(machine: PivotMachine(towerSpeedMPerMin: 3));
      final east = AreaEntity(id: 'east', points: [const Pt(0, -600), const Pt(600, -600), const Pt(600, 600), const Pt(0, 600)]);
      p.entities.add(east);
      final d100 = analyzeMechanised(p, pv).package.depthAt100Mm;
      pv.machine.vriZones['east'] = 2 * d100;
      final v = analyzeMechanised(p, pv).vri!;
      // east of the pivot point (−90° to 90°) at half speed, the west at full speed
      expect(v.rows.length, 3);
      expect(v.rows.first.endDeg, closeTo(90, 1e-9));
      expect(v.rows.first.timerPct, closeTo(50, 1e-9));
      expect(v.rows[1].startDeg, closeTo(90, 1e-9));
      expect(v.rows[1].endDeg, closeTo(270, 1e-9));
      expect(v.rows[1].timerPct, closeTo(100, 1e-9));
      expect(v.rows.last.timerPct, closeTo(50, 1e-9));
      // zones win over a sectors table
      pv.machine.vriSectors.add(VriSectorDepth(0, 360, 4 * d100));
      expect(analyzeMechanised(p, pv).vri!.rows.length, 3);
      // a zone that is no closed shape of the drawing is left out: the sectors apply
      pv.machine.vriZones
        ..clear()
        ..['nothing'] = 3;
      expect(analyzeMechanised(p, pv).vri!.rows.single.timerPct, closeTo(25, 1e-9));
      // zone control: two banks, each with its duty
      pv.machine
        ..vriSectors.clear()
        ..vriZones.clear()
        ..vriZones['east'] = 2 * d100
        ..vriBankEdgesM.add(200);
      final zv = analyzeMechanised(p, pv).vri!;
      expect(zv.bankEdgesM.length, 3);
      expect(zv.rows.every((r) => r.bankDutyPct.length == 2), isTrue);
    });

    test('electrical design of the tower motors on 480 V', () {
      final (p, pv) = pivotProject(machine: PivotMachine(voltage: 480, supplyCableM: 200));
      final e = analyzeMechanised(p, pv).electrical!;
      expect(e.towers.map((t) => t.radiusM), [for (var i = 1; i <= 8; i++) 50.0 * i]);
      expect(e.motorCurrentA, closeTo(motorCurrent(kw: 0.55, voltage: 480, efficiency: 0.70, powerFactor: 0.72), 1e-12));
      expect(e.connectedKw, closeTo(8 * 0.55, 1e-12));
      expect(e.warnings, isEmpty, reason: 'a section of the list keeps both drops within the limits');
      expect(e.maxRunningDropPct, lessThanOrEqualTo(5 + 1e-9));
      expect(e.maxStartingDropPct, lessThanOrEqualTo(15 + 1e-9));
      expect(e.supplyCableMm2, e.cableMm2, reason: '0 = the section of the span cable');
      expect(e.towers.last.volts, lessThan(e.towers.first.volts));
      expect(e.generatorKva, greaterThanOrEqualTo(e.generatorKvaRequired));
      // a booster pump at the end of the machine adds its motor
      pv.machine
        ..endGun = 'fullCircle'
        ..endGunRadiusM = 30
        ..endGunBooster = true;
      pv.endGunPressureM = 40;
      final r = analyzeMechanised(p, pv);
      expect(r.package.boosterHeadM, greaterThan(0));
      expect(r.electrical!.boosterMotorKw, greaterThan(0));
      expect(r.electrical!.connectedKw, greaterThan(8 * 0.55));
    });
  });

  group('machine data', () {
    test('PivotMachine round-trips through JSON, on the pivot entity under "mach"', () {
      expect(PivotMachine().isDefault, isTrue);
      expect(PivotMachine().toJson(), isEmpty);
      final m = PivotMachine(
        regulated: false,
        nozzleHeightM: 1.8,
        spanArchM: 0.6,
        dropInnerMm: 22,
        minNozzleNumber: 6,
        maxNozzleNumber: 50,
        endGun: 'fullCircle',
        endGunRadiusM: 30,
        endGunSpecId: 'gun',
        endGunBooster: true,
        motorRpm: 1740,
        centerGearRatio: 40,
        wheelGearRatio: 52,
        tyreRollingDiameterM: 1.43,
        towerSpeedMPerMin: 2.5,
        timerPct: 60,
        minTimerPct: 8,
        cornerArmLengthM: 120,
        cornerArmOverhangM: 6,
        cornerArmMaxDeg: 110,
        cornerArmBanks: 6,
        guidePathId: 'field',
        guideOffsetM: 15,
        clockwise: true,
        vriStepDeg: 3,
        vriBankEdgesM: [150, 300],
        vriZones: {'z1': 12, 'z2': 6},
        vriSectors: [const VriSectorDepth(330, 30, 10)],
        voltage: 480,
        towerMotorKw: 0.75,
        supplyCableM: 300,
        supplyCableMm2: 16,
      );
      expect(m.isDefault, isFalse);
      expect(m.hasCornerArm && m.hasVri && m.hasElectrical, isTrue);
      final back = PivotMachine.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), jsonEncode(m.toJson()));
      expect(back.vriZones, {'z1': 12.0, 'z2': 6.0});
      expect(back.vriSectors.single.startDeg, 330);
      expect(back.vriSectors.single.endDeg, 30);
      expect(back.vriBankEdgesM, [150.0, 300.0]);
      final pv = PivotEntity(id: 'pv', center: const Pt(10, 20), machine: m);
      final j = jsonDecode(jsonEncode(pv.toJson())) as Map<String, dynamic>;
      expect(j['mach'], isA<Map<String, dynamic>>());
      final again = Entity.fromJson(j) as PivotEntity;
      expect(jsonEncode(again.machine.toJson()), jsonEncode(m.toJson()));
      expect(
        PivotEntity(id: 'p2', center: const Pt(0, 0)).toJson().containsKey('mach'),
        isFalse,
        reason: 'default machines stay out of the file',
      );
      expect((Entity.fromJson(PivotEntity(id: 'p3', center: const Pt(0, 0)).toJson()) as PivotEntity).machine.isDefault, isTrue);
      // tolerant reading
      expect(PivotMachine.fromJson({'gun': 'sometimes'}).endGun, 'auto');
      expect(
        PivotMachine.fromJson({
          'vri': [
            [1, 2],
            'x',
            [0, 90, 12],
          ],
        }).vriSectors.single.depthMm,
        12,
      );
      expect(PivotMachine.fromJson(null).isDefault, isTrue);
    });

    test('a copied pivot has its own machine', () {
      final pv = PivotEntity(
        id: 'pv',
        center: const Pt(0, 0),
        machine: PivotMachine(vriSectors: [const VriSectorDepth(0, 90, 10)], vriZones: {'a': 5}, vriBankEdgesM: [100]),
      );
      final copy = pv.clone();
      expect(identical(copy.machine, pv.machine), isFalse);
      copy.machine
        ..voltage = 400
        ..vriSectors.add(const VriSectorDepth(90, 180, 8))
        ..vriZones['b'] = 7
        ..vriBankEdgesM.add(200);
      expect(pv.machine.voltage, 0);
      expect(pv.machine.vriSectors.length, 1);
      expect(pv.machine.vriZones.keys, ['a']);
      expect(pv.machine.vriBankEdgesM, [100]);
      expect(copy.clone(newId: 'other').machine.vriZones, {'a': 5.0, 'b': 7.0});
      final moved = pv.translated(const Pt(5, 5));
      moved.machine.timerPct = 50;
      expect(pv.machine.timerPct, 100);
      expect(pv.machine.clone().toJson(), pv.machine.toJson());
    });
  });

  group('design', () {
    test('the designer fills results.mechanised, its JSON keeps it and the reports list the package and the timer', () {
      final p = Project();
      final field = AreaEntity(id: p.newId(), points: square(335));
      p.entities.add(field);
      final pivot = PivotEntity(
        id: p.newId(),
        center: const Pt(0, 0),
        radiusM: 300,
        name: 'PV',
        machine: PivotMachine(towerSpeedMPerMin: 3, cornerArmLengthM: 150, guidePathId: field.id, guideOffsetM: 20, voltage: 480, vriSectors: [const VriSectorDepth(0, 180, 10)]),
      );
      p.entities.add(pivot);
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-400, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-400, 0), calculatePressure: true));
      final r = Designer(p).designAll();
      final m = r.mechanised[pivot.id]!;
      expect(m.package.outlets, isNotEmpty);
      expect(m.package.timer, isNotEmpty);
      expect(m.cornerArm, isNotNull);
      expect(m.vri, isNotNull);
      expect(m.electrical, isNotNull);
      // the mainline is fed with the flow of the package
      expect(r.pivots[pivot.id]!.flow, closeTo(m.package.designFlow, 1e-9));
      expect(r.pivots[pivot.id]!.inletHead, greaterThanOrEqualTo(m.package.regulatorM));
      final back = DesignResults.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      final mb = back.mechanised[pivot.id]!;
      expect(mb.package.outlets.length, m.package.outlets.length);
      expect(mb.package.timer.length, m.package.timer.length);
      expect(mb.package.requiredInletHeadM, closeTo(m.package.requiredInletHeadM, 1e-9));
      expect(mb.package.outlets.last.nozzleNumber, m.package.outlets.last.nozzleNumber);
      expect(mb.cornerArm!.banks.length, m.cornerArm!.banks.length);
      expect(mb.cornerArm!.peakFlow, closeTo(m.cornerArm!.peakFlow, 1e-12));
      expect(mb.vri!.rows.length, m.vri!.rows.length);
      expect(mb.electrical!.towers.length, m.electrical!.towers.length);
      expect(mb.warnings, m.warnings);
      final tables = buildReportTables(
        project: p,
        results: back,
        labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w),
      );
      expect(tables.map((t) => t.key), containsAll(['pivotPackage', 'pivotTimer', 'pivotPackageSummary', 'cornerArm', 'vri', 'pivotElectrical']));
      expect(tables.firstWhere((t) => t.key == 'pivotPackage').rows.length, m.package.outlets.length);
      expect(tables.firstWhere((t) => t.key == 'pivotTimer').rows.length, m.package.timer.length);
      expect(tables.firstWhere((t) => t.key == 'pivotPackageSummary').rows.single.first, 'PV');
    });
  });
}
