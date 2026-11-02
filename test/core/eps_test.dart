import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/eps.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('extended-period simulation', () {
    test('a tank filled at constant inflow reaches the analytic level', () {
      HydraulicNetwork build() {
        final net = HydraulicNetwork();
        net.addNode(HNode(id: 'J', demand: -0.01));
        net.addNode(HNode(id: 'T', elevation: 5));
        net.addLink(HLink(id: 'P', from: 'J', to: 'T', diameter: 0.15, length: 50, hazenC: 130));
        return net;
      }

      final net = build();
      final r = simulateEps(
        net,
        tanks: const [EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 6, area: 50)],
        options: const EpsOptions(duration: 5 * 3600),
      );
      expect(r.times, [0, 3600, 7200, 10800, 14400, 18000]);
      for (var i = 0; i < r.times.length; i++) {
        expect(r.tankLevels['T']![i], closeTo(1 + 0.01 * r.times[i] / 50, 1e-9));
        // the head of the tank node is its bottom plus the level
        expect(r.nodeHeads['T']![i], closeTo(5 + r.tankLevels['T']![i], 1e-9));
      }
      expect(r.messages, isEmpty);
      expect(net.nodes['T']!.kind, HNodeKind.junction, reason: 'the network is not changed');
      // a tank of variable section, by its volume curve
      const curve = [(0.0, 0.0), (2.0, 50.0), (4.0, 150.0), (6.0, 300.0)];
      final r2 = simulateEps(
        build(),
        tanks: const [EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 6, volumeCurve: curve)],
        options: const EpsOptions(duration: 5 * 3600),
      );
      const tank = EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 6, volumeCurve: curve);
      for (var i = 0; i < r2.times.length; i++) {
        final v = 25 + 0.01 * r2.times[i];
        expect(r2.tankVolumes['T']![i], closeTo(v, 1e-9));
        expect(r2.tankLevels['T']![i], closeTo(tank.levelAt(v), 1e-12));
      }
      expect(tank.levelAt(100), closeTo(3, 1e-12));
      expect(tank.volumeAt(5), closeTo(225, 1e-12));
    });

    test('a full tank closes the link that fills it and the pump stops delivering', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addNode(HNode(id: 'D'));
      net.addNode(HNode(id: 'T', elevation: 20));
      net.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -2000, b: 0, c: 40)));
      net.addLink(HLink(id: 'P', from: 'D', to: 'T', diameter: 0.15, length: 200, hazenC: 130));
      final r = simulateEps(
        net,
        tanks: const [EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 4, area: 20)],
        options: const EpsOptions(duration: 6 * 3600, hydraulicStep: 600),
      );
      final full = r.tankFullTimes['T'];
      expect(r.messages, contains('eps_tank_full:T'));
      expect(full, isNotNull);
      expect(r.times, contains(full!.first), reason: 'the step is cut when the tank fills');
      final i = r.times.indexOf(full.first);
      expect(r.tankLevels['T']![i], closeTo(4, 1e-9));
      for (var k = 0; k < r.times.length; k++) {
        // the pipe into the tank closes while it is full (EPANET), the pump
        // is left against it with no flow
        expect(r.linkOpen['P']![k], k < i, reason: 't ${r.times[k]}');
        if (k >= i) {
          expect(r.linkFlows['P']![k], 0);
          expect(r.linkFlows['PU']![k].abs(), lessThan(1e-5));
          expect(r.tankLevels['T']![k], closeTo(4, 1e-9));
          expect(r.pumps['PU']!.power[k], 0);
        }
      }
      expect(r.pumps['PU']!.hoursOn, closeTo(full.first / 3600, 1e-9));
      // the volume pumped fills the tank from 1 to 4 m
      expect(r.pumps['PU']!.volume, closeTo(3 * 20, 1e-6));
    });

    test('a tank draining through a pipe follows the analytic curve with a small step', () {
      // A·dh/dt = −(h/r)^(1/1.852): h^0.46 = h0^0.46 − 0.46·r^−0.54·t/A
      HydraulicNetwork build() {
        final net = HydraulicNetwork();
        net.addNode(HNode(id: 'T', elevation: 10));
        net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 10));
        net.addLink(HLink(id: 'P', from: 'T', to: 'O', diameter: 0.1, length: 200, hazenC: 130));
        return net;
      }

      const area = 20.0, h0 = 4.0;
      final rr = hazenWilliamsResistance(diameter: 0.1, length: 200, c: 130);
      const n = 1 / 1.852;
      double exact(double t) => math.pow(math.pow(h0, 1 - n) - (1 - n) * math.pow(rr, -n) * t / area, 1 / (1 - n)).toDouble();
      const tank = EpsTank(nodeId: 'T', initialLevel: h0, maxLevel: 5, minLevel: 0.5, area: area);
      double worstError(EpsIntegration method, double step) {
        final r = simulateEps(
          build(),
          tanks: const [tank],
          options: EpsOptions(duration: 3 * 3600, hydraulicStep: step, integration: method),
        );
        var worst = 0.0;
        for (var i = 0; i < r.times.length; i++) {
          final h = exact(r.times[i]);
          if (h <= 0.5) break;
          worst = math.max(worst, (r.tankLevels['T']![i] - h).abs() / h);
        }
        return worst;
      }

      // explicit Euler (EPANET) converges with the step, to first order;
      // Heun's predictor-corrector to second order
      final e60 = worstError(EpsIntegration.euler, 60), e10 = worstError(EpsIntegration.euler, 10);
      final h60 = worstError(EpsIntegration.heun, 60), h10 = worstError(EpsIntegration.heun, 10);
      expect(e60, lessThan(0.02));
      expect(e10, lessThan(0.003));
      expect(e60 / e10, inInclusiveRange(4.5, 7.5));
      expect(h60, lessThan(1e-3));
      expect(h60 / h10, greaterThan(20));
      // it empties at 0.5 m and the outflow stops
      final r = simulateEps(
        build(),
        tanks: const [tank],
        options: const EpsOptions(duration: 4 * 3600, hydraulicStep: 10, integration: EpsIntegration.heun),
      );
      expect(r.messages, contains('eps_tank_empty:T'));
      final te = r.tankEmptyTimes['T']!.first;
      final analytic = (math.pow(h0, 1 - n) - math.pow(0.5, 1 - n)) * area / ((1 - n) * math.pow(rr, -n));
      expect(te, closeTo(analytic, 0.002 * analytic));
      expect(r.tankLevels['T']!.last, closeTo(0.5, 1e-9));
      expect(r.linkFlows['P']!.last.abs(), lessThan(1e-5));
    });

    test('schedules open the zone valves at their hours (irrigation shifts)', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50));
      net.addNode(HNode(id: 'M'));
      net.addNode(HNode(id: 'Z1', emitter: const EmitterCurve(k: 0.002, x: 0.5)));
      net.addNode(HNode(id: 'Z2', emitter: const EmitterCurve(k: 0.003, x: 0.5)));
      net.addLink(HLink(id: 'main', from: 'R', to: 'M', diameter: 0.15, length: 300, hazenC: 140));
      net.addLink(HLink(id: 'V1', from: 'M', to: 'Z1', kind: HLinkKind.device, device: const DeviceLossCurve(k: 2000)));
      net.addLink(HLink(id: 'V2', from: 'M', to: 'Z2', kind: HLinkKind.device, device: const DeviceLossCurve(k: 2000)));
      final r = simulateEps(
        net,
        schedules: const [
          EpsSchedule.intervals('V1', [(0, 5400)]),
          EpsSchedule.intervals('V2', [(5400, 5400)]),
        ],
        options: const EpsOptions(duration: 4 * 3600),
      );
      expect(r.times, [0, 3600, 5400, 7200, 10800, 14400]);
      for (var i = 0; i < r.times.length; i++) {
        final t = r.times[i];
        final q1 = r.linkFlows['V1']![i], q2 = r.linkFlows['V2']![i];
        if (t < 5400) {
          expect(q1, greaterThan(0.005));
          expect(q2.abs(), lessThan(1e-5));
        } else if (t < 10800) {
          expect(q1.abs(), lessThan(1e-5));
          expect(q2, greaterThan(0.005));
        } else {
          expect(q1.abs() + q2.abs(), lessThan(1e-5));
        }
        expect(r.linkOpen['V1']![i], t < 5400);
        expect(r.linkOpen['V2']![i], t >= 5400 && t < 10800);
      }
      // the second zone, with the larger emitter, draws more
      expect(r.linkFlows['V2']![2], greaterThan(r.linkFlows['V1']![0]));
      // a daily repeating shift
      final daily = EpsSchedule.intervals('V1', const [(6 * 3600, 2 * 3600)], period: 86400);
      expect(daily.openAt(86400 + 7 * 3600), isTrue);
      expect(daily.openAt(86400 + 9 * 3600), isFalse);
      expect(daily.nextChange(86400 + 7 * 3600), 86400 + 8 * 3600);
      final ev = EpsSchedule.events('V1', const [(100, false), (200, true)]);
      expect(ev.openAt(50), isNull);
      expect(ev.openAt(150), isFalse);
      expect(ev.openAt(250), isTrue);
    });

    test('demand schedules: the shifts of a mainline, zones as the demands of their valve nodes', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addNode(HNode(id: 'D'));
      net.addNode(HNode(id: 'A', elevation: 2, demand: 0.01));
      net.addNode(HNode(id: 'B', elevation: 4, demand: 0.02));
      net.addNode(HNode(id: 'C', elevation: 1, emitter: const EmitterCurve(k: 0.003, x: 0.5), emitterCount: 2));
      net.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -5000, b: 0, c: 60)));
      net.addLink(HLink(id: 'm1', from: 'D', to: 'A', diameter: 0.15, length: 400, hazenC: 140));
      net.addLink(HLink(id: 'm2', from: 'A', to: 'B', diameter: 0.15, length: 300, hazenC: 140));
      net.addLink(HLink(id: 'm3', from: 'A', to: 'C', diameter: 0.1, length: 200, hazenC: 140));
      // shift 1 from 6:00 for 2 h (zone A), shift 2 from 8:00 for 3 h (B and C)
      final r = simulateEps(
        net,
        demandSchedules: const [
          EpsDemandSchedule('A', [(6 * 3600, 2 * 3600)]),
          EpsDemandSchedule('B', [(8 * 3600, 3 * 3600)]),
          EpsDemandSchedule('C', [(8 * 3600, 3 * 3600)]),
        ],
        options: const EpsOptions(duration: 12 * 3600, pumpEfficiency: {'PU': 0.7}),
      );
      for (var i = 0; i < r.times.length; i++) {
        final t = r.times[i];
        final q = r.linkFlows['PU']![i];
        final qc = r.linkFlows['m3']![i];
        if (t < 6 * 3600 || t >= 11 * 3600) {
          expect(q.abs(), lessThan(1e-9), reason: 'idle at $t');
        } else if (t < 8 * 3600) {
          expect(q, closeTo(0.01, 1e-7), reason: 'shift 1 at $t');
          expect(qc.abs(), lessThan(1e-9));
        } else {
          expect(qc, greaterThan(0.005), reason: 'the emitters of C run in shift 2');
          expect(q, closeTo(0.02 + qc, 1e-7), reason: 'shift 2 at $t');
        }
      }
      expect(r.pumps['PU']!.hoursOn, closeTo(5, 1e-9));
      // with every zone off the pump has nothing to deliver: it is off and
      // the solves converge (the steady solver cycles at the shutoff head)
      expect(r.converged, isTrue);
      expect(r.messages, isEmpty);
      for (var i = 0; i < r.times.length; i++) {
        final t = r.times[i];
        expect(r.linkOpen['PU']![i], t >= 6 * 3600 && t < 11 * 3600, reason: 't $t');
      }
      expect(net.nodes['A']!.demand, 0.01, reason: 'the network is not changed');
      expect(net.nodes['C']!.emitterCount, 2);
    });

    test('a pump switched by the tank level, patterns and clock controls', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addNode(HNode(id: 'D'));
      net.addNode(HNode(id: 'T', elevation: 20));
      net.addNode(HNode(id: 'C', demand: 0.004));
      net.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -2000, b: 0, c: 40)));
      net.addLink(HLink(id: 'P', from: 'D', to: 'T', diameter: 0.15, length: 200, hazenC: 130));
      net.addLink(HLink(id: 'Q', from: 'T', to: 'C', diameter: 0.1, length: 100, hazenC: 130));
      final r = simulateEps(
        net,
        tanks: const [EpsTank(nodeId: 'T', initialLevel: 2, maxLevel: 5, area: 30)],
        controls: const [
          EpsControl.levelBelow('PU', tankId: 'T', level: 1, open: true),
          EpsControl.levelAbove('PU', tankId: 'T', level: 4, open: false),
        ],
        options: const EpsOptions(duration: 24 * 3600),
      );
      final open = r.linkOpen['PU']!;
      var switches = 0;
      for (var i = 1; i < r.times.length; i++) {
        if (open[i] != open[i - 1]) {
          switches++;
          // switched exactly at the control level
          expect(r.tankLevels['T']![i], closeTo(open[i] ? 1 : 4, 1e-6), reason: 't ${r.times[i]}');
        }
      }
      expect(switches, greaterThanOrEqualTo(3));
      expect(r.tankLevels['T']!.reduce(math.max), closeTo(4, 1e-6));
      expect(r.tankLevels['T']!.reduce(math.min), closeTo(1, 1e-6));
      // the off period drains 3 m · 30 m² at 4 L/s (plus the ΔH/10⁸ trickle
      // the steady solver lets back through the closed pump, ~1 s here)
      final offStart = r.times[open.indexOf(false)];
      final onAgain = r.times[open.indexOf(true, open.indexOf(false))];
      expect(onAgain - offStart, closeTo(90 / 0.004, 3));

      // demand pattern: hourly multipliers
      final pnet = HydraulicNetwork();
      pnet.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30));
      pnet.addNode(HNode(id: 'J', demand: 0.01));
      pnet.addLink(HLink(id: 'P', from: 'R', to: 'J', diameter: 0.15, length: 300, hazenC: 140));
      final rp = simulateEps(
        pnet,
        options: const EpsOptions(duration: 5 * 3600, defaultDemandPattern: EpsPattern([1, 2, 0.5])),
      );
      expect(rp.linkFlows['P'], [
        for (final m in [1, 2, 0.5, 1, 2, 0.5]) closeTo(0.01 * m, 1e-7),
      ]);

      // clock controls: the pump stops at 18:00 and starts at 06:00
      final cnet = HydraulicNetwork();
      cnet.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      cnet.addNode(HNode(id: 'D'));
      cnet.addNode(HNode(id: 'T', kind: HNodeKind.reservoir, fixedHead: 20));
      cnet.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -2000, b: 0, c: 40)));
      cnet.addLink(HLink(id: 'P', from: 'D', to: 'T', diameter: 0.15, length: 200, hazenC: 130));
      final rc = simulateEps(
        cnet,
        controls: const [EpsControl.atClockTime('PU', hour: 18, open: false), EpsControl.atClockTime('PU', hour: 6, open: true)],
        options: const EpsOptions(duration: 24 * 3600, startHour: 16, hydraulicStep: 7200),
      );
      for (var i = 0; i < rc.times.length; i++) {
        final clock = (16 + rc.times[i] / 3600) % 24;
        final on = clock < 18 && clock >= 6;
        expect(rc.linkOpen['PU']![i], on, reason: 'clock $clock');
      }
      expect(rc.times, containsAll([7200.0, 14 * 3600.0]));
      expect(rc.pumps['PU']!.hoursOn, closeTo(12, 1e-9));
    });

    test('pump energy and its cost match the hand calculation', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addNode(HNode(id: 'D'));
      net.addNode(HNode(id: 'T', kind: HNodeKind.reservoir, fixedHead: 30));
      net.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -1000, b: 0, c: 50)));
      net.addLink(HLink(id: 'P', from: 'D', to: 'T', diameter: 0.2, length: 1000, hazenC: 130));
      final steady = net.solve();
      final q = steady.links['PU']!.flow, hp = steady.links['PU']!.pumpHead;
      final kw = waterDensity * gravity * q * hp / 0.75 / 1000;
      double price(double hour) => hour < 6 ? 0.1 : 0.2;
      final r = simulateEps(
        net,
        options: EpsOptions(duration: 24 * 3600, pumpEfficiency: const {'PU': 0.75}, tariff: price),
      );
      final e = r.pumps['PU']!;
      expect(e.energyKwh, closeTo(kw * 24, 1e-6 * kw * 24));
      expect(e.cost, closeTo(kw * (6 * 0.1 + 18 * 0.2), 1e-6 * kw));
      expect(r.totalEnergyKwh, e.energyKwh);
      expect(e.volume, closeTo(q * 86400, 1e-6 * q * 86400));
      expect(e.hoursOn, closeTo(24, 1e-9));
      expect(e.maxPowerKw, closeTo(kw, 1e-9 * kw));
      expect(e.power.every((p) => (p - kw).abs() < 1e-6 * kw), isTrue);
      // the price follows the clock: starting at 03:00 three cheap hours remain
      final r3 = simulateEps(
        net,
        options: EpsOptions(duration: 24 * 3600, pumpEfficiency: const {'PU': 0.75}, tariff: price, startHour: 3),
      );
      expect(r3.pumps['PU']!.cost, closeTo(kw * (6 * 0.1 + 18 * 0.2), 1e-6 * kw));
      final r4 = simulateEps(
        net,
        options: EpsOptions(duration: 6 * 3600, pumpEfficiency: const {'PU': 0.75}, tariff: price, startHour: 3),
      );
      expect(r4.pumps['PU']!.cost, closeTo(kw * (3 * 0.1 + 3 * 0.2), 1e-6 * kw));
    });

    test('unknown references are reported', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30));
      net.addNode(HNode(id: 'J', demand: 0.01));
      net.addLink(HLink(id: 'P', from: 'R', to: 'J', diameter: 0.15, length: 300, hazenC: 140));
      final r = simulateEps(
        net,
        tanks: const [EpsTank(nodeId: 'X', initialLevel: 1, maxLevel: 2)],
        schedules: const [
          EpsSchedule.intervals('Y', [(0, 10)]),
        ],
        controls: const [EpsControl.levelBelow('P', tankId: 'Z', level: 1, open: true)],
        options: const EpsOptions(duration: 3600),
      );
      expect(r.messages, containsAll(['eps_unknown_node:X', 'eps_unknown_link:Y', 'eps_unknown_node:Z']));
      expect(r.converged, isTrue);
      expect(r.indexAt(1800), 0);
      expect(r.indexAt(3600), 1);
    });
  });
}
