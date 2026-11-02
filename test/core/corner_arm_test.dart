import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/corner_arm.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

List<Pt> circle(Pt c, double r, [int n = 1440]) => [for (var i = 0; i < n; i++) c + Pt.polar(r, 2 * math.pi * i / n)];

double distanceToPath(Pt p, List<Pt> path) {
  var best = double.infinity;
  for (var i = 0; i < path.length; i++) {
    best = math.min(best, distanceToSegment(p, path[i], path[(i + 1) % path.length]));
  }
  return best;
}

void main() {
  const c = Pt(1000, 2000);

  group('circular guide path: constant arm angle (analytic)', () {
    // R0 = 300 m, Lc = 100 m, path radius 350 m: cos φ = (350² − 300² − 100²)/(2·300·100) = 0.375
    final spec = CornerArmSpec(center: c, hingeRadiusM: 300, armLengthM: 100, guidePath: circle(c, 350), grossDepthMm: 10, hoursPerRev: 20, stepDeg: 1);
    final r = analyzeCornerArm(spec, id: 'ca');
    final phi = math.acos(0.375);
    final kappa = 2 * math.pi * 0.010 / (20 * 3600);

    test('arm angle and tip radius', () {
      for (final st in r.steps) {
        expect(st.state, CornerArmState.tracking);
        expect(st.armDeg, closeTo(radToDeg(phi), 0.01));
        expect(st.tipRadiusM, closeTo(350, 0.01));
      }
      expect(r.warnings, isEmpty);
    });

    test('a rigid configuration turning about the pivot sweeps annuli: bank duties (r₁² − r₀²)/((R0+s₁)² − (R0+s₀)²)', () {
      double r2(double s) => 300 * 300 + s * s + 2 * 300 * s * 0.375;
      final edges = <double>[0, 25, 50, 75, 100];
      for (var b = 0; b < 4; b++) {
        final design = kappa * (math.pow(300 + edges[b + 1], 2) - math.pow(300 + edges[b], 2)) / 2;
        expect(r.banks[b].designFlow, closeTo(design, 1e-15));
      }
      final duties = [for (var b = 0; b < 4; b++) (r2(edges[b + 1]) - r2(edges[b])) / (math.pow(300 + edges[b + 1], 2) - math.pow(300 + edges[b], 2))];
      expect(duties[0], closeTo(0.4, 1e-12));
      expect(duties[3], closeTo(10000 / 19375, 1e-12));
      // only the outer bank reaches half its design flow
      final st = r.steps[10];
      expect(st.banksOn, 8);
      expect(st.banksOnCount, 1);
      expect(st.armFlow, closeTo(r.banks[3].designFlow, 1e-15));
      // pulsed banks deliver exactly the swept area times κ
      expect(st.pulsedFlow, closeTo(kappa * (r2(100) - r2(0)) / 2, kappa * (r2(100) - r2(0)) / 2 * 1e-4));
      expect(r.banks[3].onFraction, closeTo(1, 1e-12));
      expect(r.banks[0].onFraction, 0);
    });

    test('coverage: the arm end runs on the path circle', () {
      expect(r.totalAreaM2, closeTo(math.pi * 350 * 350, math.pi * 350 * 350 * 1e-4));
      expect(r.armAreaM2, closeTo(math.pi * (350 * 350 - 300 * 300), 30));
      expect(r.addedAreaM2, closeTo(r.totalAreaM2 - math.pi * 300 * 300, 1e-6));
      expect(r.maxTipSpeedRatio, closeTo(350 / 300, 0.01));
      expect(r.mainFlow, closeTo(0.010 / (20 * 3600) * math.pi * 300 * 300, 1e-12));
      expect(r.peakFlow, closeTo(r.mainFlow + r.banks[3].designFlow, 1e-12));
    });

    test('clockwise travel mirrors the trailing side', () {
      final cw = analyzeCornerArm(CornerArmSpec(center: c, hingeRadiusM: 300, armLengthM: 100, guidePath: circle(c, 350), grossDepthMm: 10, hoursPerRev: 20, stepDeg: 1, clockwise: true));
      final st = cw.steps[5];
      expect(st.armDeg, closeTo(radToDeg(phi), 0.01));
      // the tip trails: clockwise travel puts it at a larger azimuth than the hinge
      expect(((st.tipAzimuthDeg - st.pivotDeg) % 360 + 360) % 360, lessThan(180));
      final ccw = r.steps[5];
      expect(((ccw.tipAzimuthDeg - ccw.pivotDeg) % 360 + 360) % 360, greaterThan(180));
    });

    test('a path closer than the folded arm reaches: folded at the limit and flagged', () {
      final f = analyzeCornerArm(
        CornerArmSpec(center: c, hingeRadiusM: 300, armLengthM: 100, guidePath: circle(c, 310), maxArmAngleDeg: 80, grossDepthMm: 10, hoursPerRev: 20, stepDeg: 2),
        id: 'ca',
      );
      expect(f.steps.every((s) => s.state == CornerArmState.folded), isTrue);
      expect(f.steps.first.armDeg, closeTo(80, 1e-9));
      expect(f.maxOverrunM, closeTo(math.sqrt(100000 + 60000 * math.cos(degToRad(80))) - 310, 0.05));
      expect(f.warnings, contains('corner_arm_overrun:ca'));
    });
  });

  group('square field', () {
    // 800 m square, guide wire 20 m inside the boundary, hinge at 350 m, 60 m arm
    final field = [c + const Pt(-400, -400), c + const Pt(400, -400), c + const Pt(400, 400), c + const Pt(-400, 400)];
    final path = guidancePathFromBoundary(field, 20);
    final spec = CornerArmSpec(center: c, hingeRadiusM: 350, armLengthM: 60, tipThrowM: 15, guidePath: path, grossDepthMm: 12, hoursPerRev: 24, stepDeg: 0.5, bankCount: 3);
    final r = analyzeCornerArm(spec, id: 'sq');

    test('guidance path: the boundary offset inwards, either orientation', () {
      expect(path.length, 4);
      for (final p in path) {
        expect((p - c).x.abs(), closeTo(380, 1e-9));
        expect((p - c).y.abs(), closeTo(380, 1e-9));
      }
      final cw = guidancePathFromBoundary(field.reversed.toList(), 20);
      expect(polygonArea(cw).abs(), closeTo(760.0 * 760, 1e-6));
    });

    test('mid-side: the tip on the wire 30 m beyond the hinge, arm at 60°', () {
      final s0 = r.steps.first;
      expect(s0.pivotDeg, closeTo(0, 1e-9));
      expect(s0.state, CornerArmState.tracking);
      expect(s0.armDeg, closeTo(60, 1e-6));
      expect(s0.tipRadiusM, closeTo(math.sqrt(380 * 380 + 3600 - 900), 1e-6));
      for (final st in r.steps.where((s) => s.state == CornerArmState.tracking)) {
        final tip = c + Pt.polar(st.tipRadiusM, degToRad(st.tipAzimuthDeg));
        expect(distanceToPath(tip, path), lessThan(1e-6));
        final hinge = c + Pt.polar(350, degToRad(st.pivotDeg));
        expect(tip.distanceTo(hinge), closeTo(60, 1e-6));
        expect(st.armDeg, inInclusiveRange(0, 120));
      }
    });

    test('corner: the straight arm falls short of the wire', () {
      final diag = r.steps.firstWhere((s) => (s.pivotDeg - 45).abs() < 1e-9);
      expect(diag.state, CornerArmState.extended);
      expect(diag.armDeg, 0);
      expect(diag.tipRadiusM, closeTo(410, 1e-9));
      expect(r.maxShortfallM, closeTo(380 - 410 / math.sqrt(2), 1e-6));
      expect(r.warnings, contains('corner_arm_short:sq'));
      // straight arm: every bank on, as designed
      expect(diag.banksOnCount, 3);
      final designTotal = r.banks.fold(0.0, (s, b) => s + b.designFlow);
      expect(diag.pulsedFlow, closeTo(designTotal, designTotal * 1e-4));
    });

    test('flow versus angle: peak in the corners, symmetric about the diagonals', () {
      expect(r.peakFlow, closeTo(r.mainFlow + r.banks.fold(0.0, (s, b) => s + b.designFlow), 1e-12));
      expect(r.minFlow, lessThan(r.peakFlow));
      expect(r.peakPulsedFlow, closeTo(r.peakFlow, r.peakFlow * 1e-4));
      double armAt(double deg) => r.steps.firstWhere((s) => (s.pivotDeg - deg).abs() < 1e-9).armDeg;
      expect(armAt(30), closeTo(armAt(120), 1e-6));
      expect(armAt(10), closeTo(armAt(190), 1e-6));
      // the tip runs faster than the hinge when the arm swings out
      expect(r.maxTipSpeedRatio, greaterThan(1.1));
    });

    test('coverage between the hinge circle and the path reach', () {
      expect(r.totalAreaM2, greaterThan(math.pi * 365 * 365));
      expect(r.totalAreaM2, lessThan(800.0 * 800));
      expect(r.armAreaM2, closeTo(r.totalAreaM2 - math.pi * 350 * 350, 1e-6));
      expect(r.addedAreaM2, closeTo(r.totalAreaM2 - math.pi * 365 * 365, 1e-6));
      expect(r.outline.length, r.steps.length - 1);
    });

    test('JSON round trip', () {
      final back = CornerArmResult.fromJson(r.toJson());
      expect(back.steps.length, r.steps.length);
      expect(back.steps[90].state, r.steps[90].state);
      expect(back.steps[10].banksOn, r.steps[10].banksOn);
      expect(back.banks.length, 3);
      expect(back.outline.length, r.outline.length);
      expect(back.peakFlow, closeTo(r.peakFlow, 1e-15));
      expect(back.warnings, r.warnings);
    });

    test('invalid data', () {
      final bad = analyzeCornerArm(
        CornerArmSpec(center: c + const Pt(5000, 0), hingeRadiusM: 350, armLengthM: 60, guidePath: path),
        id: 'x',
      );
      expect(bad.warnings, contains('corner_arm_no_path:x'));
      expect(bad.steps, isEmpty);
      final noRate = analyzeCornerArm(CornerArmSpec(center: c, hingeRadiusM: 350, armLengthM: 60, guidePath: path, stepDeg: 5));
      expect(noRate.warnings, contains('corner_arm_no_rate'));
    });

    test('rate from the main machine flow and custom bank edges', () {
      final q = 0.012 / (24 * 3600) * math.pi * 365 * 365;
      final b = analyzeCornerArm(CornerArmSpec(center: c, hingeRadiusM: 350, armLengthM: 60, tipThrowM: 15, guidePath: path, mainFlow: q, mainRadiusM: 365, bankEdgesM: const [20, 45], stepDeg: 1));
      expect(b.banks.length, 3);
      expect(b.banks[1].startM, 20);
      expect(b.banks[2].endM, 75);
      expect(b.banks[0].designFlow, closeTo(2 * math.pi * 0.012 / (24 * 3600) * (370 * 370 - 350 * 350) / 2, 1e-15));
    });
  });
}
