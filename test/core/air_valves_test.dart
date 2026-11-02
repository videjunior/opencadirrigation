import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/air_valves.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

List<ProfilePoint> profile(List<(double, double)> xz, {List<double>? hgl, List<double>? minHgl}) => [
  for (var i = 0; i < xz.length; i++) ProfilePoint(chainage: xz[i].$1, pipe: xz[i].$2, ground: xz[i].$2 + 1, hgl: hgl?[i], minHgl: minHgl?[i], position: Pt(xz[i].$1, 0)),
];

List<double> at(AirValvePlan p) => [for (final s in p.suggestions) s.chainage];

void main() {
  group('air valve placement (AWWA M51)', () {
    test('a hill: high point, line end and valves on the long ascent and descent', () {
      final plan = suggestAirValves(PipelineProfile(points: profile([(0, 0), (1000, 20), (2000, 0)]), diameter: 0.3, designFlow: 0.05));
      expect(at(plan), [500, 1000, 1500, 2000]);
      final top = plan.suggestions[1];
      expect(top.reason, AirValveReason.highPoint);
      expect(top.code, 'air_valve_high_point');
      expect(top.type, AirValveType.combination);
      expect(top.pipe, closeTo(20, 1e-12));
      expect(top.ground, closeTo(21, 1e-12));
      expect(top.position!.x, closeTo(1000, 1e-9));
      expect(plan.suggestions[0].reason, AirValveReason.longAscent);
      expect(plan.suggestions[2].reason, AirValveReason.longDescent);
      expect(plan.suggestions[3].reason, AirValveReason.lineEnd);
      expect(plan.suggestions[0].pipe, closeTo(10, 1e-12));
      expect(plan.messages, isEmpty);
      // the high point drains both ways: twice the flow of one 2 % slope
      final q = gravityDrainageFlow(diameter: 0.3, slope: 0.02, hazenC: 140);
      expect(top.sizing.drainFlow, closeTo(2 * q, 1e-12));
      expect(plan.suggestions[0].sizing.drainFlow, closeTo(q, 1e-12), reason: 'mid-ascent: only the lower side drains away');
    });

    test('long runs are split into equal intervals no longer than the maximum', () {
      final plan = suggestAirValves(PipelineProfile(points: profile([(0, 0), (3000, 30)]), diameter: 0.2));
      // the end at 3000 m; 3000 m of ascent in four parts of 750 m
      expect(at(plan), [750, 1500, 2250, 3000]);
      expect(plan.suggestions.take(3).every((s) => s.reason == AirValveReason.longAscent), isTrue);
      final flat = suggestAirValves(PipelineProfile(points: profile([(0, 5), (1700, 5.1)]), diameter: 0.2), options: const AirValveOptions(preferCombination: false));
      expect(at(flat), [closeTo(566.67, 0.01), closeTo(1133.33, 0.01), 1700]);
      expect(flat.suggestions.first.reason, AirValveReason.longHorizontal);
      expect(flat.suggestions.first.type, AirValveType.airRelease);
      for (var i = 1; i < flat.suggestions.length; i++) {
        final gap = flat.suggestions[i].chainage - flat.suggestions[i - 1].chainage;
        expect(gap, inInclusiveRange(400, 800));
      }
    });

    test('a steeper descent takes an air/vacuum valve, a flatter ascent an air-release valve', () {
      const opts = AirValveOptions(preferCombination: false);
      final down = suggestAirValves(PipelineProfile(points: profile([(0, 50), (300, 47), (600, 32)]), diameter: 0.25), options: opts);
      final sd = down.suggestions.firstWhere((s) => s.reasons.contains(AirValveReason.steeperDescent));
      expect(sd.chainage, 300);
      expect(sd.type, AirValveType.airVacuum);
      expect(sd.sizing.smallOrifice, 0);
      expect(sd.sizing.largeOrifice, greaterThan(0));
      final up = suggestAirValves(PipelineProfile(points: profile([(0, 0), (300, 15), (600, 18), (700, 17)]), diameter: 0.25, designFlow: 0.04), options: opts);
      final fa = up.suggestions.firstWhere((s) => s.reasons.contains(AirValveReason.flatterAscent));
      expect(fa.chainage, 300);
      expect(fa.type, AirValveType.airRelease);
      expect(fa.sizing.largeOrifice, 0);
      expect(fa.sizing.smallOrifice, greaterThan(0));
      expect(airReleaseSizes, contains(fa.sizing.nominalSize));
      expect(up.suggestions.map((s) => s.reason), contains(AirValveReason.highPoint));
      // a steeper ascent or a gentler descent is no reason
      for (final xz in [
        [(0.0, 0.0), (300.0, 3.0), (600.0, 18.0)],
        [(0.0, 20.0), (300.0, 10.0), (600.0, 8.0)],
      ]) {
        final none = suggestAirValves(PipelineProfile(points: profile(xz), diameter: 0.25), options: opts);
        expect(at(none), [600], reason: '$xz: only the line end');
      }
    });

    test('a flat top gets a valve at both ends; a small bump is ignored', () {
      final plan = suggestAirValves(PipelineProfile(points: profile([(0, 0), (300, 12), (600, 12), (900, 0)]), diameter: 0.2));
      final highs = [
        for (final s in plan.suggestions)
          if (s.reasons.contains(AirValveReason.highPoint)) s.chainage,
      ];
      expect(highs, [300, 600]);
      final bump = suggestAirValves(PipelineProfile(points: profile([(0, 0), (200, 10), (210, 10.05), (220, 10.04), (400, 20), (600, 0)]), diameter: 0.2));
      final bumpHighs = [
        for (final s in bump.suggestions)
          if (s.reasons.contains(AirValveReason.highPoint)) s.chainage,
      ];
      expect(bumpHighs, [400], reason: 'a 1 cm dip is below the 0.1 m relief');
    });

    test('pump discharge, check valves, grade lines and transient vacuum', () {
      final plan = suggestAirValves(
        PipelineProfile(
          points: profile([(0, 0), (400, 4), (800, 1), (1200, 6)], hgl: [40, 20, 2.5, 9], minHgl: [30, 2, -3, 4]),
          diameter: 0.2,
          designFlow: 0.03,
          pumpDischarges: const [0],
          checkValves: const [100],
        ),
      );
      expect(plan.suggestions.first.chainage, 0);
      expect(plan.suggestions.first.type, AirValveType.airVacuum);
      expect(plan.suggestions.first.reason, AirValveReason.pumpDischarge);
      final cv = plan.suggestions.firstWhere((s) => s.reasons.contains(AirValveReason.checkValve));
      expect(cv.chainage, 101);
      // at 800 m the grade line is 1.5 m above the pipe and the transient
      // minimum 4 m below it: both reasons, one combination valve
      final low = plan.suggestions.firstWhere((s) => s.chainage == 800);
      expect(low.reasons, containsAll([AirValveReason.transientVacuum, AirValveReason.hglClose]));
      expect(low.type, AirValveType.combination);
      expect(low.reason, AirValveReason.transientVacuum);
      expect(at(plan), [0, 101, 400, 800, 1200]);
      expect(plan.suggestions[2].reason, AirValveReason.highPoint);
      expect(plan.suggestions.last.reasons, [AirValveReason.lineEnd]);
      expect(plan.messages, isEmpty);
      // a grade line under the pipe is a hydraulic problem
      final below = suggestAirValves(PipelineProfile(points: profile([(0, 0), (500, 12), (1000, 0)], hgl: [30, 10, 0.5]), diameter: 0.2));
      expect(below.messages, ['air_hgl_below_pipe:500.0']);
      expect(suggestAirValves(PipelineProfile(points: profile([(0, 0)]), diameter: 0.2)).messages, ['air_profile_too_short']);
    });

    test('orifice sizing by compressible flow, gravity drainage by Hazen-Williams', () {
      // Hazen-Williams for a full pipe: Q ≈ 0.278·C·D^2.63·S^0.54
      final q = gravityDrainageFlow(diameter: 0.3, slope: 0.02, hazenC: 140);
      expect(q, closeTo(0.2785 * 140 * math.pow(0.3, 2.63) * math.pow(0.02, 0.54), 0.005 * q));
      expect(gravityDrainageFlow(diameter: 0.3, slope: 0, hazenC: 140), 0);
      // subsonic inflow at 5 psi: ṁ = Cd·A·√(7·pa·ρa·(r^1.4286 − r^1.7143)) = ρ(p)·Q
      final pa = waterDensity * gravity * 10.33, p = pa - 34474, rt = 287.05 * 293.15;
      final r = p / pa;
      final flux = math.sqrt(7 * pa * (pa / rt) * (math.pow(r, 1 / 0.7) - math.pow(r, 1.2 / 0.7)));
      final area = p / rt * 0.1 / (0.6 * flux);
      final d = airInflowOrificeDiameter(waterFlow: 0.1, differential: 34474);
      expect(d, closeTo(math.sqrt(4 * area / math.pi), 1e-9));
      expect(d, inInclusiveRange(0.02, 0.04));
      // a larger differential needs a smaller orifice; choked beyond 0.472·pa
      expect(airInflowOrificeDiameter(waterFlow: 0.1, differential: 60000), lessThan(d));
      final choked = airInflowOrificeDiameter(waterFlow: 0.1, differential: 0.6 * pa);
      final pc = 0.4 * pa;
      final fluxChoked = 0.6847 * pa / math.sqrt(rt);
      expect(choked, closeTo(math.sqrt(4 * (pc / rt * 0.1 / (0.6 * fluxChoked)) / math.pi), 1e-4 * choked));
      // exhaust at 2 psi: from p = pa + 13.8 kPa to the atmosphere
      final pe = pa + 13790;
      final re = pa / pe;
      final fluxE = math.sqrt(7 * pe * (pe / rt) * (math.pow(re, 1 / 0.7) - math.pow(re, 1.2 / 0.7)));
      expect(airExhaustOrificeDiameter(waterFlow: 0.05, differential: 13790), closeTo(math.sqrt(4 * (pe / rt * 0.05 / (0.6 * fluxE)) / math.pi), 1e-9));
      // air release: 2 % of 0.1 m³/s at 30 m, choked: a few millimetres
      final dr = airReleaseOrificeDiameter(waterFlow: 0.1, pressureHead: 30);
      final pr = pa + waterDensity * gravity * 30;
      final arR = pa / rt * 0.002 / (0.6 * 0.6847 * pr / math.sqrt(rt));
      expect(dr, closeTo(math.sqrt(4 * arR / math.pi), 1e-4 * dr));
      expect(dr, inInclusiveRange(0.0015, 0.005));
      // the valve takes the larger of the drainage and filling orifices, rounded to a standard size
      final plan = suggestAirValves(PipelineProfile(points: profile([(0, 0), (500, 10), (1000, 0)]), diameter: 0.3, fillFlow: 0.02));
      final top = plan.suggestions.firstWhere((s) => s.reason == AirValveReason.highPoint);
      final dIn = airInflowOrificeDiameter(waterFlow: top.sizing.drainFlow, differential: 34474);
      final dOut = airExhaustOrificeDiameter(waterFlow: 0.02, differential: 13790);
      expect(top.sizing.largeOrifice, closeTo(math.max(dIn, dOut), 1e-12));
      expect(airValveSizes, contains(top.sizing.nominalSize));
      expect(top.sizing.nominalSize, greaterThanOrEqualTo(top.sizing.largeOrifice));
      expect(top.sizing.fillFlow, 0.02);
      // a telescoped line: each side drains with its own bore
      final tele = suggestAirValves(
        PipelineProfile(points: const [ProfilePoint(chainage: 0, pipe: 0, diameter: 0.3), ProfilePoint(chainage: 500, pipe: 10, diameter: 0.2), ProfilePoint(chainage: 1000, pipe: 0)], diameter: 0.25),
      );
      final tTop = tele.suggestions.firstWhere((s) => s.reason == AirValveReason.highPoint);
      expect(tTop.sizing.drainFlow, closeTo(gravityDrainageFlow(diameter: 0.3, slope: 0.02) + gravityDrainageFlow(diameter: 0.2, slope: 0.02), 1e-12));
      expect(tTop.sizing.fillFlow, closeTo(0.3 * math.pi * 0.09 / 4, 1e-12), reason: 'filling at 0.3 m/s in the larger bore');
      // a given drainage flow (a burst downstream) replaces the gravity estimate
      final burst = suggestAirValves(PipelineProfile(points: profile([(0, 0), (500, 10), (1000, 0)]), diameter: 0.3, drainFlow: 0.5));
      expect(burst.suggestions.firstWhere((s) => s.reason == AirValveReason.highPoint).sizing.drainFlow, 0.5);
    });
  });
}
