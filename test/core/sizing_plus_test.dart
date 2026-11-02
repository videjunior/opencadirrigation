// 1.6.0 MOT+: what the sizing takes in besides the operating pressures —
// the surge of a closure in the class of every pipe, the profile of the
// mainline (the grade line over its high points, air valves there) and the
// energy balance of the loops of a looped mainline.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/lp_sizing.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// One micro-sprinkler zone fed through a mainline of [mainPts] from a
/// calculated supply at its first point (the valve at its last).
(Project, ControlValveEntity) zoneProject({List<Pt> Function(Pt valve)? mainPts}) {
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
  final valve = block.valve!;
  final pts = mainPts?.call(valve.position) ?? [valve.position + const Pt(-300, 0), valve.position];
  p.entities.add(PipeEntity(id: 'main', points: pts, scope: HydraulicScope.mainline, name: 'Main'));
  p.entities.add(WaterSupplyEntity(id: 'src', position: pts.first, name: 'Pump'));
  return (p, valve);
}

void main() {
  group('the class of the pipes holds the surge', () {
    Project surgeProject({required bool surge}) {
      final (p, _) = zoneProject();
      // the mainline from three pipes of its own: a thin cheap class, a
      // thick class of about the same bore and a wider thin one
      for (final s in p.catalog.pipes) {
        s.usage.remove(PipeUsage.mainline);
      }
      p.catalog.pipes.addAll([
        PipeSpec(id: 'mA', name: 'A', nominalMm: 35, innerDiameterMm: 32, pressureRatingM: 40, wallThicknessMm: 1.5, costPerM: 5, usage: {PipeUsage.mainline}),
        PipeSpec(id: 'mB', name: 'B', nominalMm: 35, innerDiameterMm: 30, pressureRatingM: 120, wallThicknessMm: 2.5, costPerM: 8, usage: {PipeUsage.mainline}),
        PipeSpec(id: 'mC', name: 'C', nominalMm: 60, innerDiameterMm: 54, pressureRatingM: 40, wallThicknessMm: 1.8, costPerM: 30, usage: {PipeUsage.mainline}),
      ]);
      p.params
        ..tradeCapitalVsRunning = false
        ..valveClosureTimeS = 0
        ..checkSurge = surge;
      return p;
    }

    String mainSpec(Project p, Designer d) => d.results.systemFlows.single.pipes.firstWhere((x) => x.entityId == 'main').pipeSpecId!;

    test('without the surge the cheapest class carries the flow; with it the class holds the static pressure plus the surge', () {
      final off = surgeProject(surge: false);
      final d0 = Designer(off)..designAll();
      expect(mainSpec(off, d0), 'mA');
      final on = surgeProject(surge: true);
      final d1 = Designer(on);
      final r = d1.designAll();
      expect(mainSpec(on, d1), isNot('mA'));
      expect(r.surge.where((s) => s.exceeds), isEmpty, reason: r.surge.map((s) => '${s.pipeName} ${s.totalHead} > ${s.rating}').join('; '));
      expect(r.messages.where((m) => m.startsWith('surge_rating_exceeded')), isEmpty);
      // the cheap class would not have held it
      final a = on.catalog.pipe('mA')!;
      final main = r.surge.firstWhere((s) => s.entityId == 'main');
      expect(main.maxStaticHead + main.surgeHead, lessThanOrEqualTo(main.rating + 1e-6));
      expect(a.pressureRatingM, lessThan(main.maxStaticHead + main.surgeHead));
    });
  });

  group('the profile of the mainline', () {
    /// A mainline over a ridge 25 m high halfway, the ground from spot
    /// heights; [airValve] puts an air valve 5 m past the top.
    Project ridge({bool airValve = false}) {
      final (p, v) = zoneProject(mainPts: (v) => [v + const Pt(-100, 0), v + const Pt(-50, 0), v]);
      final x0 = v.position.x, y0 = v.position.y;
      for (final (dx, z) in [(-150.0, 0.0), (-50.0, 25.0), (0.0, 0.0), (100.0, 0.0)]) {
        for (final dy in [-100.0, 100.0]) {
          p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x0 + dx, y0 + dy), elevation: z));
        }
      }
      if (airValve) p.entities.add(MiscHydraulicEntity(id: 'air', position: Pt(x0 - 45, y0), valveSpecId: 'air50'));
      return p;
    }

    test('a calculated supply lifts the grade line over the ridge, and the ridge asks for an air valve', () {
      final p = ridge();
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      expect(f.warnings.where((w) => w.startsWith('pressure_below_atmospheric')), isEmpty, reason: '${f.warnings}');
      final top = f.pipes.where((x) => x.entityId == 'main').map((x) => x.pressureEnd).reduce((a, b) => a < b ? a : b);
      expect(top, greaterThanOrEqualTo(-0.1 - 1e-3));
      expect(r.messages, contains('air_valve_missing:main'));
      // with an air valve by the top the message goes
      final withValve = Designer(ridge(airValve: true)).designAll();
      expect(withValve.messages.where((m) => m.startsWith('air_valve_missing')), isEmpty);
    });

    test('flat ground has no high point that needs an air valve', () {
      final (p, _) = zoneProject();
      final r = Designer(p).designAll();
      expect(r.messages.where((m) => m.startsWith('air_valve_missing')), isEmpty);
    });
  });

  group('looped mainlines in the LP', () {
    test('the loop balance makes the LP pick sizes that keep the flows it assumed', () {
      final small = PipeSpec(id: 's', name: 's', nominalMm: 50, innerDiameterMm: 50, costPerM: 1);
      final large = PipeSpec(id: 'l', name: 'l', nominalMm: 100, innerDiameterMm: 100, costPerM: 3);
      LpAssignment size({required bool loop}) => lpSize(
        LpSizingInput(
          units: ['A', 'B'],
          candidates: {
            'A': [small, large],
            'B': [small, large],
          },
          unitLength: {'A': 100, 'B': 100},
          maxSizes: {'A': 1, 'B': 1},
          headVars: [LpHeadVar(fixedValue: 10)],
          // the demand after A needs 5 m: A cannot be the small pipe
          constraints: [
            LpHeadConstraint(
              headVar: 0,
              lossByUnitSpec: {
                'A': {'s': 10, 'l': 2},
              },
              minPressure: 5,
            ),
          ],
          crf: 1,
          tradeCapital: false,
          // round the loop: A forwards, B backwards, with the same flow
          loops: loop
              ? [
                  LpLoopConstraint(
                    lossByUnitSpec: {
                      'A': {'s': 10, 'l': 2},
                      'B': {'s': -10, 'l': -2},
                    },
                  ),
                ]
              : const [],
        ),
      );
      final tree = size(loop: false);
      expect(tree.feasible, isTrue);
      expect(tree.fractions['A']!.first.$1.id, 'l');
      expect(tree.fractions['B']!.first.$1.id, 's', reason: 'sized as a tree, B takes the cheapest pipe');
      final looped = size(loop: true);
      expect(looped.feasible, isTrue);
      expect(looped.fractions['B']!.first.$1.id, 'l', reason: 'the balance of the loop asks B for the loss of A');
    });

    test('a looped mainline is sized with the balance of its loop and the flows settle', () {
      // the supply, a ring of four pipes and the valve at the far corner
      final (p, v) = zoneProject(mainPts: (v) => [v + const Pt(-200, 0), v]);
      final s = v.position + const Pt(-200, 0);
      p.entities.add(PipeEntity(id: 'ring', points: [s, s + const Pt(0, 80), v.position + const Pt(0, 80), v.position], scope: HydraulicScope.mainline, name: 'Ring'));
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      expect(f.converged, isTrue);
      expect(f.maxDeficit, lessThan(0.05));
      expect(r.messages.where((m) => m.startsWith('lp_infeasible')), isEmpty);
      expect(r.messages, isNot(contains('lp_loops_approx')));
      // both ways round carry water
      expect(f.pipes.where((x) => x.entityId == 'main').first.flow.abs(), greaterThan(0));
      expect(f.pipes.where((x) => x.entityId == 'ring').first.flow.abs(), greaterThan(0));
    });
  });
}
