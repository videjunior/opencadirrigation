// 1.6.0 MOT+ (UI-19): the network analyses run a step at a time, report how
// far they got and stop when cancelled; run at once they give the same
// results as before. And the ageing and clogging scenarios of a design.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/analysis_control.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/calibration.dart';
import 'package:opencadirrigation/core/design/criticality.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/energy_grouping.dart';
import 'package:opencadirrigation/core/design/life_scenarios.dart';
import 'package:opencadirrigation/core/design/on_demand.dart';
import 'package:opencadirrigation/core/design/tariff.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A reservoir feeding four demand nodes through a ring and a branch.
HydraulicNetwork ring() {
  final net = HydraulicNetwork()
    ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
    ..addNode(HNode(id: 'A', demand: 0.004))
    ..addNode(HNode(id: 'B', demand: 0.003))
    ..addNode(HNode(id: 'C', demand: 0.003))
    ..addNode(HNode(id: 'D', demand: 0.002));
  for (final (id, a, b, len) in [('ra', 'R', 'A', 300.0), ('ab', 'A', 'B', 200.0), ('bc', 'B', 'C', 250.0), ('ca', 'C', 'A', 220.0), ('cd', 'C', 'D', 150.0)]) {
    net.addLink(HLink(id: id, from: a, to: b, diameter: 0.1, length: len, hazenC: 140));
  }
  return net;
}

/// A control that cancels itself once [after] steps were reported.
AnalysisControl cancelAfter(int after, List<(int, int)> seen) {
  late final AnalysisControl c;
  c = AnalysisControl(
    onProgress: (done, total) {
      seen.add((done, total));
      if (seen.length >= after) c.cancel();
    },
  );
  return c;
}

void main() {
  group('progress and cancel of the network analyses', () {
    final required = {'A': 20.0, 'B': 20.0, 'C': 20.0, 'D': 20.0};

    test('criticality: the same result a step at a time, progress up to the total, and a cancel stops it', () async {
      final sync = analyzeCriticality(ring(), requiredPressure: required);
      final seen = <(int, int)>[];
      final async = await analyzeCriticalityAsync(
        ring(),
        requiredPressure: required,
        control: AnalysisControl(onProgress: (d, t) => seen.add((d, t))),
      );
      expect(jsonEncode(async.toJson()), jsonEncode(sync.toJson()));
      expect(seen.map((s) => s.$1), [0, 1, 2, 3, 4]);
      expect(seen.every((s) => s.$2 == 5), isTrue);
      final partial = <(int, int)>[];
      await expectLater(analyzeCriticalityAsync(ring(), requiredPressure: required, control: cancelAfter(2, partial)), throwsA(isA<AnalysisCancelled>()));
      expect(partial.length, 2);
    });

    test('random demand check: the same configurations a step at a time', () async {
      final hydrants = [
        for (final id in ['A', 'B', 'C', 'D']) Hydrant(id: id, nodeId: id, discharge: 0.004, minPressure: 20, hoursPerDay: 10),
      ];
      final net = ring();
      for (final n in net.nodes.values) {
        n.demand = 0;
      }
      const options = RandomCheckOptions(configurations: 40);
      final sync = checkRandomConfigurations(net, hydrants, options: options);
      final steps = <int>[];
      final async = await checkRandomConfigurationsAsync(
        net,
        hydrants,
        options: options,
        control: AnalysisControl(onProgress: (d, _) => steps.add(d)),
      );
      expect(jsonEncode(async.toJson()), jsonEncode(sync.toJson()));
      expect(steps.length, 40);
      await expectLater(checkRandomConfigurationsAsync(net, hydrants, options: options, control: cancelAfter(5, [])), throwsA(isA<AnalysisCancelled>()));
    });

    test('calibration: the fit of the C factor a step at a time', () async {
      // readings made with every C at 120 (a factor of 120/140)
      final truth = ring();
      for (final l in truth.links) {
        l.hazenC = 120;
      }
      final r = truth.solve();
      final pressures = [
        for (final id in ['B', 'D']) PressureMeasurement(nodeId: id, pressure: r.nodes[id]!.pressure, sigma: 0.1),
      ];
      final sync = calibrateRoughness(ring(), pressures: pressures);
      final async = await calibrateRoughnessAsync(ring(), pressures: pressures, control: AnalysisControl());
      expect(async.scales.single, closeTo(sync.scales.single, 1e-12));
      expect(sync.scales.single, closeTo(120 / 140, 1e-3));
      await expectLater(calibrateRoughnessAsync(ring(), pressures: pressures, control: cancelAfter(1, [])), throwsA(isA<AnalysisCancelled>()));
    });

    test('energy grouping and the tariff schedule a step at a time', () async {
      final zones = [for (var i = 0; i < 6; i++) EnergyZone(id: 'z$i', flow: 0.002 + 0.001 * i, requiredHead: 20 + 3.0 * i, hours: 2)];
      const options = GroupingOptions(maxFlow: 0.01);
      final g = groupZonesForEnergy(zones, options: options);
      final ga = await groupZonesForEnergyAsync(zones, options: options, control: AnalysisControl());
      expect([for (final x in ga.groups) x.zoneIds], [for (final x in g.groups) x.zoneIds]);
      const season = TariffSeason(basePricePerKwh: 1, bands: [TariffBand(startMinute: 1080, endMinute: 1260, pricePerKwh: 5, peak: true)]);
      const jobs = [TariffJob(id: 'a', hours: 6, powerKw: 10), TariffJob(id: 'b', hours: 5, powerKw: 20)];
      final s = scheduleJobs(jobs, season);
      final sa = await scheduleJobsAsync(jobs, season, control: AnalysisControl());
      expect(jsonEncode(sa.toJson()), jsonEncode(s.toJson()));
    });
  });

  group('ageing and clogging', () {
    Project designed() {
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
      p.entities.add(PipeEntity(id: 'main', points: [v.position + const Pt(-200, 0), v.position], scope: HydraulicScope.mainline));
      // a pump-less supply at the pressure the new design needs, plus a little
      p.entities.add(WaterSupplyEntity(id: 'src', position: v.position + const Pt(-200, 0)));
      Designer(p).designAll();
      return p;
    }

    test('aged pipes lose more head, clogged emitters give less flow and less uniformity', () {
      final p = designed();
      final asNew = Designer(p).analyzeAll();
      final figs = lifeScenarios(p, asNew: asNew, options: const LifeOptions(years: 20, cLossPerYear: 1, clogging: 0.2, cvIncrease: 0.05));
      expect(figs.map((f) => f.lifeCase), LifeCase.values);
      final n = figs[LifeCase.asNew.index], aged = figs[LifeCase.aged.index], clogged = figs[LifeCase.clogged.index], both = figs[LifeCase.agedClogged.index];
      // a calculated supply: the aged line asks for more pressure at the same flow
      expect(aged.supplyHead, greaterThan(n.supplyHead + 0.05));
      expect(aged.peakFlow, closeTo(n.peakFlow, 0.02 * n.peakFlow));
      // the clogged emitters pass less water at the same pressure, less evenly
      expect(clogged.peakFlow, lessThan(0.85 * n.peakFlow));
      expect(clogged.minEu, lessThan(n.minEu));
      expect(both.supplyHead, greaterThan(clogged.supplyHead));
      // the project itself is not touched
      expect(p.params.hazenCOffset, 0);
    });

    test('a step at a time, cancellable, with the same figures', () async {
      final p = designed();
      final asNew = Designer(p).analyzeAll();
      const o = LifeOptions(years: 10);
      final sync = lifeScenarios(p, asNew: asNew, options: o);
      final async = await lifeScenariosAsync(p, asNew: asNew, options: o, control: AnalysisControl());
      for (var i = 0; i < sync.length; i++) {
        expect(async[i].supplyHead, closeTo(sync[i].supplyHead, 1e-9));
        expect(async[i].minEu, closeTo(sync[i].minEu, 1e-9));
      }
      await expectLater(lifeScenariosAsync(p, asNew: asNew, options: o, control: cancelAfter(2, [])), throwsA(isA<AnalysisCancelled>()));
      expect(lifeNotes(p, null), contains('life_no_design'));
    });
  });
}
