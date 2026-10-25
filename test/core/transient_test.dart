import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/hydraulics/transient.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/units.dart';

/// Reservoir → pipe → valve discharging to the atmosphere, the classic
/// water hammer system (Wylie & Streeter 1993).
(HydraulicNetwork, NetworkResult) reservoirPipeValve({double head = 100, double length = 1000, double diameter = 0.5, double velocity = 1, double hazenC = 1e7}) {
  final net = HydraulicNetwork();
  net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: head));
  net.addNode(HNode(id: 'N'));
  net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
  final area = math.pi * diameter * diameter / 4;
  final q = velocity * area;
  net.addLink(HLink(id: 'P', from: 'R', to: 'N', diameter: diameter, length: length, hazenC: hazenC));
  net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: DeviceLossCurve(k: head / (q * q))));
  return (net, net.solve());
}

void main() {
  group('method of characteristics', () {
    test('without an event the steady state does not move', () {
      final (net, steady) = reservoirPipeValve(hazenC: 120);
      final model = TransientModel.fromNetwork(net, steady);
      final r = model.simulate(options: const TransientOptions(duration: 10, probes: [TransientProbe.node('N'), TransientProbe.link('P')]));
      final n = r.nodes['N']!;
      expect(n.maxHead - n.steadyHead, lessThan(1e-6));
      expect(n.steadyHead - n.minHead, lessThan(1e-6));
      final q = r.seriesOf('P')!.flows;
      expect(q.last, closeTo(steady.links['P']!.flow, 1e-9));
      expect(r.messages, isEmpty);
    });

    test('instantaneous closure: Joukowsky surge a·ΔV/g and the 4L/a period', () {
      final (net, steady) = reservoirPipeValve();
      const a = 1000.0;
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: a)});
      final r = model.simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 12, probes: [TransientProbe.node('N')]));
      final v0 = steady.links['P']!.flow / (math.pi * 0.25 * 0.25);
      final dh = a * v0 / gravity;
      final n = r.nodes['N']!;
      expect(n.maxHead - n.steadyHead, closeTo(dh, 1e-6 * dh));
      expect(n.steadyHead - n.minHead, closeTo(dh, 1e-6 * dh));
      final s = r.seriesOf('N')!;
      for (var i = 0; i < r.times.length; i++) {
        final t = r.times[i];
        final phase = t % 4.0;
        if (t > 1e-9 && phase > 0.05 && phase < 1.95) expect(s.heads[i], closeTo(n.steadyHead + dh, 1e-6 * dh), reason: 't $t');
        if (phase > 2.05 && phase < 3.95) expect(s.heads[i], closeTo(n.steadyHead - dh, 1e-6 * dh), reason: 't $t');
      }
    });

    test('slow demand stop: Michaud surge 2·L·V/(g·tc)', () {
      final net = HydraulicNetwork();
      const d = 0.5, len = 1000.0, a = 1000.0;
      final q0 = math.pi * d * d / 4;
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 100));
      net.addNode(HNode(id: 'N', demand: q0));
      net.addLink(HLink(id: 'P', from: 'R', to: 'N', diameter: d, length: len, hazenC: 1e7));
      final steady = net.solve();
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: a)});
      for (final tc in [4.0, 6.0, 10.0]) {
        final r = model.simulate(events: [TransientEvent.demandStop('N', stopTime: tc)], options: const TransientOptions(duration: 20));
        final n = r.nodes['N']!;
        final michaud = 2 * len * 1.0 / (gravity * tc);
        expect(n.maxHead - n.steadyHead, closeTo(michaud, 1e-3 * michaud));
      }
    });

    test('slow valve closure: first-interval orifice solution, below Joukowsky, rigid column when very slow', () {
      final (net, steady) = reservoirPipeValve();
      const a = 1000.0, len = 1000.0;
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: a)});
      final v0 = steady.links['P']!.flow / (math.pi * 0.25 * 0.25);
      final jouk = a * v0 / gravity;
      final h0 = steady.nodes['N']!.head;
      for (final tc in [8.0, 20.0, 80.0]) {
        final r = model.simulate(events: [TransientEvent.valveClosure('V', closureTime: tc)], options: TransientOptions(duration: tc + 10, probes: const [TransientProbe.node('N')]));
        final surge = r.nodes['N']!.maxHead - h0;
        expect(surge, lessThan(jouk));
        // up to 2L/a the C+ characteristic still carries the steady state:
        // ΔH = (a/g)·(V0 − V) with V = τ·V0·√(1 + ΔH/H0) (Wylie & Streeter 1993)
        final s = r.seriesOf('N')!;
        final rr = h0 / jouk;
        for (var i = 0; i < r.times.length; i++) {
          final t = r.times[i];
          if (t > 2 * len / a + 1e-9) break;
          final tau = 1 - t / tc;
          final sq = (-tau + math.sqrt(tau * tau + 4 * rr * (1 + rr))) / (2 * rr);
          expect(s.heads[i] - h0, closeTo(h0 * (sq * sq - 1), 1e-6 * jouk), reason: 't $t');
        }
        // rigid column theory for a uniform closure: ΔH/H0 = K/2 + √(K + K²/4),
        // K = (L·V0/(g·H0·tc))² (Wylie & Streeter 1993); the elastic solution
        // oscillates around the rigid one with the period 4L/a, so a slow
        // closure is compared through the averages over that period
        final k = math.pow(len * v0 / (gravity * h0 * tc), 2).toDouble();
        final rigidMax = h0 * (k / 2 + math.sqrt(k + k * k / 4));
        if (tc == 8) {
          // the same stroke as a τ(t) table gives the same transient
          final rt = model.simulate(events: [TransientEvent.valveClosure('V', table: const [(0, 1), (8, 0)])], options: TransientOptions(duration: tc + 10, probes: const [TransientProbe.node('N')]));
          expect(rt.seriesOf('N')!.heads, s.heads);
          // a fast first stage to 20 % then a slow one: a larger surge than the uniform stroke
          final two = model.simulate(events: [TransientEvent.valveClosure('V', table: const [(0, 1), (1, 0.2), (8, 0)])], options: TransientOptions(duration: tc + 10));
          expect(two.nodes['N']!.maxHead - h0, greaterThan(surge));
          expect(two.nodes['N']!.maxHead - h0, lessThan(jouk));
        }
        if (tc >= 80) {
          final area = math.pi * 0.25 * 0.25, q0 = steady.links['P']!.flow;
          const step = 1e-3;
          var q = q0;
          final rigid = <double>[];
          for (var t = step; t <= tc - 4 + 1e-9; t += step) {
            final tau = 1 - t / tc;
            var qn = q;
            for (var i = 0; i < 30; i++) {
              final hv = h0 * (qn / (tau * q0)) * (qn / (tau * q0));
              final f = len / (gravity * area) * (qn - q) / step - (100 - hv);
              final df = len / (gravity * area) / step + 2 * h0 * qn / (tau * tau * q0 * q0);
              qn -= f / df;
            }
            q = qn;
            rigid.add(h0 * (q / (tau * q0)) * (q / (tau * q0)) - h0);
          }
          for (final w0 in [40.0, 56.0, 68.0, 72.0]) {
            var sm = 0.0, n = 0, sr = 0.0, nr = 0;
            for (var i = 0; i < r.times.length; i++) {
              if (r.times[i] > w0 && r.times[i] <= w0 + 4) {
                sm += s.heads[i] - h0;
                n++;
              }
            }
            for (var i = 0; i < rigid.length; i++) {
              final t = (i + 1) * step;
              if (t > w0 && t <= w0 + 4) {
                sr += rigid[i];
                nr++;
              }
            }
            expect(sm / n, closeTo(sr / nr, 0.03 * sr / nr), reason: 'window from $w0 s');
            // and the rigid column holds the closed-form surge
            expect(sr / nr, closeTo(rigidMax, 1e-3 * rigidMax));
          }
        }
      }
    });

    test('friction damps the oscillation', () {
      final (net, steady) = reservoirPipeValve(diameter: 0.3, velocity: 1, hazenC: 100, head: 200);
      const a = 1000.0;
      final hEnd = 200.0;
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: a)});
      final r = model.simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 40, probes: [TransientProbe.node('N')]));
      expect(r.messages.where((m) => m.startsWith('transient_column')), isEmpty);
      final s = r.seriesOf('N')!;
      final peaks = List<double>.filled(10, 0);
      for (var i = 0; i < r.times.length; i++) {
        final k = (r.times[i] / 4).floor();
        if (k < 10) peaks[k] = math.max(peaks[k], (s.heads[i] - hEnd).abs());
      }
      for (var k = 1; k < 10; k++) {
        expect(peaks[k], lessThan(peaks[k - 1]), reason: 'period $k');
      }
      expect(peaks[9], lessThan(0.9 * peaks[0]));
      // the frictionless case keeps its amplitude
      final (net2, steady2) = reservoirPipeValve(diameter: 0.3, velocity: 1, hazenC: 1e7, head: 200);
      final r2 = TransientModel.fromNetwork(net2, steady2, linkData: const {'P': TransientLinkData(celerity: a)}).simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 40, probes: [TransientProbe.node('N')]));
      final s2 = r2.seriesOf('N')!;
      var first = 0.0, last = 0.0;
      for (var i = 0; i < r2.times.length; i++) {
        if (r2.times[i] < 4) first = math.max(first, (s2.heads[i] - hEnd).abs());
        if (r2.times[i] > 36) last = math.max(last, (s2.heads[i] - hEnd).abs());
      }
      expect(last, closeTo(first, 1e-6 * first));
    });

    test('mass is conserved at a branching junction', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 60));
      net.addNode(HNode(id: 'J', elevation: 2));
      net.addNode(HNode(id: 'B', elevation: 1));
      net.addNode(HNode(id: 'C', elevation: 3));
      net.addNode(HNode(id: 'O1', kind: HNodeKind.reservoir, fixedHead: 1));
      net.addNode(HNode(id: 'O2', kind: HNodeKind.reservoir, fixedHead: 3));
      net.addLink(HLink(id: 'A', from: 'R', to: 'J', diameter: 0.25, length: 500, hazenC: 130));
      net.addLink(HLink(id: 'PB', from: 'J', to: 'B', diameter: 0.2, length: 300, hazenC: 130));
      net.addLink(HLink(id: 'PC', from: 'C', to: 'J', diameter: 0.15, length: 400, hazenC: 130));
      net.addLink(HLink(id: 'VB', from: 'B', to: 'O1', kind: HLinkKind.device, device: const DeviceLossCurve(k: 8000)));
      net.addLink(HLink(id: 'VC', from: 'C', to: 'O2', kind: HLinkKind.device, device: const DeviceLossCurve(k: 30000)));
      final steady = net.solve();
      expect(steady.converged, isTrue);
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'A': TransientLinkData(celerity: 1000), 'PB': TransientLinkData(celerity: 1000), 'PC': TransientLinkData(celerity: 1000)});
      final r = model.simulate(
        events: [TransientEvent.valveClosure('VB', closureTime: 0.5)],
        options: const TransientOptions(duration: 15, probes: [TransientProbe.link('A', fraction: 1), TransientProbe.link('PB', fraction: 0), TransientProbe.link('PC', fraction: 1), TransientProbe.link('VB')]),
      );
      final qa = r.seriesOf('A')!.flows, qb = r.seriesOf('PB')!.flows, qc = r.seriesOf('PC')!.flows;
      var worst = 0.0;
      for (var i = 0; i < r.times.length; i++) {
        worst = math.max(worst, (qa[i] + qc[i] - qb[i]).abs());
      }
      expect(worst, lessThan(1e-9));
      expect(r.maxWaveSpeedAdjustment, lessThanOrEqualTo(0.1 + 1e-12));
      expect(r.seriesOf('VB')!.flows.last, 0, reason: 'the closed valve passes nothing');
    });

    test('column separation: vapour cavity at the valve after the downsurge', () {
      final (net, steady) = reservoirPipeValve(head: 20);
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: 1000)});
      final r = model.simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 20, probes: [TransientProbe.node('N')]));
      final n = r.nodes['N']!;
      expect(n.minPressure, closeTo(0.24 - 10.33, 1e-6));
      expect(n.maxCavityVolume, greaterThan(0));
      expect(r.messages, containsAll(['transient_column_separation:N', 'transient_vacuum:N']));
      final s = r.seriesOf('N')!;
      var collapses = 0;
      for (var i = 1; i < s.volumes.length; i++) {
        if (s.volumes[i - 1] > 0 && s.volumes[i] == 0) collapses++;
      }
      expect(collapses, greaterThan(0), reason: 'the cavity collapses');
      // a cavity emptied by the inflow of the last step but opened again by
      // this one stays at the vapour head: nothing falls below it
      for (final e in r.links.values) {
        expect(e.minPressure, greaterThanOrEqualTo(0.24 - 10.33 - 1e-9), reason: e.linkId);
      }
      for (final e in r.nodes.entries) {
        expect(e.value.minPressure, greaterThanOrEqualTo(0.24 - 10.33 - 1e-9), reason: e.key);
      }
      // the collapse of the cavity surges above the Joukowsky upsurge
      // (Bergant, Simpson & Tijsseling 2006)
      expect(n.maxHead, greaterThan(20 + 1000 / gravity * steady.links['P']!.flow / (math.pi * 0.0625)));
      // without the cavity model the pressure falls to H0 − a·V/g
      final r2 = model.simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 20, columnSeparation: false));
      expect(r2.nodes['N']!.minHead, closeTo(20 - 1000 / gravity * steady.links['P']!.flow / (math.pi * 0.0625), 1e-6));
      expect(r2.messages, isNot(contains('transient_column_separation:N')));
      expect(r2.messages, contains('transient_vacuum:N'));
    });

    test('a combination air valve admits air at a high point when the head drops below the pipe', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40));
      net.addNode(HNode(id: 'U2'));
      net.addNode(HNode(id: 'HP', elevation: 30));
      net.addNode(HNode(id: 'E'));
      net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addLink(HLink(id: 'U', from: 'R', to: 'U2', kind: HLinkKind.device, device: const DeviceLossCurve(k: 100)));
      net.addLink(HLink(id: 'P1', from: 'U2', to: 'HP', diameter: 0.3, length: 300, hazenC: 140));
      net.addLink(HLink(id: 'P2', from: 'HP', to: 'E', diameter: 0.3, length: 700, hazenC: 140));
      net.addLink(HLink(id: 'VE', from: 'E', to: 'O', kind: HLinkKind.device, device: const DeviceLossCurve(k: 7000)));
      final steady = net.solve();
      expect(steady.nodes['HP']!.pressure, greaterThan(5));
      const data = {'P1': TransientLinkData(celerity: 400), 'P2': TransientLinkData(celerity: 400)};
      const opts = TransientOptions(duration: 30, probes: [TransientProbe.node('HP')]);
      final bare = TransientModel.fromNetwork(net, steady, linkData: data).simulate(events: [TransientEvent.valveClosure('U')], options: opts);
      final prot = TransientModel.fromNetwork(net, steady, linkData: data, airValves: const [AirValve(nodeId: 'HP', inflowDiameter: 0.1, outflowDiameter: 0.01)]).simulate(events: [TransientEvent.valveClosure('U')], options: opts);
      final b = bare.nodes['HP']!, p = prot.nodes['HP']!;
      expect(b.minPressure, closeTo(0.24 - 10.33, 1e-6), reason: 'unprotected, the high point reaches the vapour pressure');
      expect(bare.messages, contains('transient_column_separation:HP'));
      expect(prot.messages, contains('transient_air_admitted:HP'));
      expect(prot.messages, isNot(contains('transient_column_separation:HP')));
      expect(p.maxAirVolume, greaterThan(0));
      expect(p.minPressure, greaterThan(-1.0), reason: 'a large inflow orifice keeps the pocket near atmospheric');
      final s = prot.seriesOf('HP')!;
      final first = s.volumes.indexWhere((v) => v > 0);
      expect(first, greaterThan(0));
      expect(s.pressures[first], lessThan(0), reason: 'air enters only below atmospheric pressure');
    });

    group('pump trip', () {
      // suction reservoir at 0 m, pump H = 80 − 750·Q², 2 km frictionless pipe
      // to a reservoir at 50 m: operating point 0.2 m³/s at 50 m
      (HydraulicNetwork, NetworkResult) pumpLine() {
        final net = HydraulicNetwork();
        net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
        net.addNode(HNode(id: 'D'));
        net.addNode(HNode(id: 'T', kind: HNodeKind.reservoir, fixedHead: 50));
        net.addLink(HLink(id: 'PU', from: 'S', to: 'D', kind: HLinkKind.pump, pump: const PumpCurve(a: -750, b: 0, c: 80)));
        net.addLink(HLink(id: 'P', from: 'D', to: 'T', diameter: 0.4, length: 2000, hazenC: 1e7));
        return (net, net.solve());
      }

      test('run-down follows the pump boundary condition until the reflection returns; the check valve closes', () {
        final (net, steady) = pumpLine();
        expect(steady.links['PU']!.flow, closeTo(0.2, 1e-6));
        const a = 300.0, inertia = 5.0, rpm = 1480.0, eff = 0.75, beta0 = 0.5;
        final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: a)});
        final r = model.simulate(
          events: [TransientEvent.pumpTrip('PU', inertia: inertia, speedRpm: rpm, efficiency: eff, shutoffTorqueRatio: beta0)],
          options: const TransientOptions(duration: 30, maxTimeStep: 0.01, probes: [TransientProbe.node('D'), TransientProbe.link('PU')]),
        );
        // independent integration: H_D = H_D0 − B·(Q0 − Q) (C− from the pipe,
        // still steady), H_D = −750·Q² + 80·α² and I·ω·dα/dt = −T_R·β, with the
        // wave speed the grid uses
        const q0 = 0.2, h0 = 50.0;
        final aUsed = r.waveSpeeds['P']!;
        expect(aUsed, closeTo(a, 1e-3 * a));
        final area = math.pi * 0.04, bb = aUsed / (gravity * area);
        final omega = rpm * 2 * math.pi / 60;
        final tr = waterDensity * gravity * q0 * h0 / (eff * omega);
        final kk = tr / (inertia * omega);
        double flowAt(double al) {
          final c0 = h0 - bb * q0 - 80 * al * al;
          final disc = bb * bb - 3000 * c0;
          final q = (-bb + math.sqrt(math.max(disc, 0))) / 1500;
          return math.max(q, 0);
        }

        double dAlpha(double al) => -kk * (beta0 * al * al + (1 - beta0) * al * flowAt(al) / q0);
        var al = 1.0, t = 0.0;
        var closed = -1.0;
        final sd = r.seriesOf('D')!, sq = r.seriesOf('PU')!;
        var worstH = 0.0, worstQ = 0.0, compared = 0;
        for (var i = 1; i < r.times.length && r.times[i] < 2 * 2000 / a - 0.1; i++) {
          // RK4 up to the sample time
          while (t < r.times[i] - 1e-12) {
            final h = math.min(1e-4, r.times[i] - t);
            final k1 = dAlpha(al), k2 = dAlpha(al + h / 2 * k1), k3 = dAlpha(al + h / 2 * k2), k4 = dAlpha(al + h * k3);
            al += h / 6 * (k1 + 2 * k2 + 2 * k3 + k4);
            t += h;
            if (flowAt(al) <= 0 && closed < 0) closed = t;
          }
          final q = flowAt(al);
          if (closed > 0 && (t - closed).abs() < 0.05) continue;
          worstH = math.max(worstH, (sd.heads[i] - (h0 - bb * (q0 - q))).abs());
          worstQ = math.max(worstQ, (sq.flows[i] - q).abs());
          compared++;
        }
        expect(compared, greaterThan(1000));
        expect(worstH, lessThan(0.02));
        expect(worstQ, lessThan(1e-4));
        expect(r.checkValveClosures['PU'], closeTo(closed, 0.02));
        // once the check valve is shut the discharge head is H0 − B·Q0 (Joukowsky)
        expect(r.nodes['D']!.minHead, closeTo(h0 - bb * q0, 1e-3));
        expect(sq.flows.every((q) => q >= 0), isTrue, reason: 'no reverse flow through the check valve');
        // against a closed check valve the torque is β₀·α²: α falls as 1/t
        expect(sq.speeds.last, lessThan(0.1), reason: 'the set runs down');
        expect(sq.speeds.last, greaterThan(0));
      });

      test('the inertia estimate grows with the power and falls with the speed', () {
        // Thorley & Faithfull (1992): 0.03768·(P/N³)^0.9556 + 0.0043·(P/N)^1.48
        expect(estimatePumpInertia(powerKw: 30, speedRpm: 1450), closeTo(0.03768 * math.pow(30 / math.pow(1.45, 3), 0.9556) + 0.0043 * math.pow(30 / 1.45, 1.48), 1e-12));
        expect(estimatePumpInertia(powerKw: 30, speedRpm: 1450), inInclusiveRange(0.5, 1.0));
        expect(estimatePumpInertia(powerKw: 60, speedRpm: 1450), greaterThan(estimatePumpInertia(powerKw: 30, speedRpm: 1450)));
        expect(estimatePumpInertia(powerKw: 30, speedRpm: 2900), lessThan(estimatePumpInertia(powerKw: 30, speedRpm: 1450)));
      });

      test('an air vessel at the discharge limits the downsurge', () {
        final (net, steady) = pumpLine();
        const data = {'P': TransientLinkData(celerity: 1000)};
        final trip = [TransientEvent.pumpTrip('PU', inertia: 2, speedRpm: 1480)];
        const opts = TransientOptions(duration: 60, probes: [TransientProbe.node('D')]);
        final bare = TransientModel.fromNetwork(net, steady, linkData: data).simulate(events: trip, options: opts);
        final prot = TransientModel.fromNetwork(net, steady, linkData: data, surgeVessels: const [SurgeVessel(nodeId: 'D', gasVolume: 2, totalVolume: 6, connectionDiameter: 0.25)]).simulate(events: trip, options: opts);
        final b = bare.nodes['D']!, p = prot.nodes['D']!;
        expect(bare.messages, contains('transient_column_separation:D'));
        expect(b.minPressure, closeTo(0.24 - 10.33, 1e-6));
        expect(prot.messages, isEmpty);
        expect(p.minHead, greaterThan(10));
        expect(p.maxGasVolume, greaterThan(2.5));
        // mass-spring period of the column and the gas, 2π·√(L·∀/(g·A·n·H*))
        final s = prot.seriesOf('D')!;
        final peaks = <double>[];
        for (var i = 1; i < s.volumes.length - 1; i++) {
          if (s.volumes[i] > s.volumes[i - 1] && s.volumes[i] >= s.volumes[i + 1]) peaks.add(prot.times[i]);
        }
        const hStar = 50 + 10.33;
        final period = 2 * math.pi * math.sqrt(2000 * 2 / (gravity * math.pi * 0.04 * 1.2 * hStar));
        expect(peaks.length, greaterThanOrEqualTo(2));
        expect(peaks[1] - peaks[0], closeTo(period, 0.1 * period));
      });
    });

    test('series pipes merge into one grid that keeps the profile, whatever their orientation', () {
      // R → a → J1 (z 5) ← b ← J2 (z 12) → c → N, frictionless, then a valve
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 100));
      net.addNode(HNode(id: 'J1', elevation: 5));
      net.addNode(HNode(id: 'J2', elevation: 12));
      net.addNode(HNode(id: 'N'));
      net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      const d = 0.5;
      final q = math.pi * d * d / 4;
      net.addLink(HLink(id: 'a', from: 'R', to: 'J1', diameter: d, length: 300, hazenC: 1e7));
      net.addLink(HLink(id: 'b', from: 'J2', to: 'J1', diameter: d, length: 450, hazenC: 1e7));
      net.addLink(HLink(id: 'c', from: 'J2', to: 'N', diameter: d, length: 250, hazenC: 1e7));
      net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: DeviceLossCurve(k: 100 / (q * q))));
      final steady = net.solve();
      const data = {'a': TransientLinkData(celerity: 1000), 'b': TransientLinkData(celerity: 1000), 'c': TransientLinkData(celerity: 1000)};
      final r = TransientModel.fromNetwork(net, steady, linkData: data).simulate(
        events: [TransientEvent.valveClosure('V')],
        options: const TransientOptions(duration: 8, probes: [TransientProbe.node('J2'), TransientProbe.link('b', fraction: 0.25)]),
      );
      final dh = 1000 / gravity * steady.links['a']!.flow / q;
      // one grid of 1000 m: Δt = 1 s / 8
      expect(r.timeStep, closeTo(0.125, 1e-12));
      expect(r.reaches, 8);
      expect(r.links['b']!.treatment, TransientLinkTreatment.grid);
      for (final id in ['a', 'b', 'c']) {
        final env = r.links[id]!;
        expect(env.points.length, greaterThan(2), reason: id);
        for (var i = 1; i < env.points.length; i++) {
          expect(env.points[i].chainage, greaterThan(env.points[i - 1].chainage), reason: id);
        }
        for (final p in env.points) {
          // the wave of a·ΔV/g passes every point but the reservoir
          if (id == 'a' && p.chainage == 0) continue;
          expect(p.maxHead, closeTo(steady.nodes['R']!.head + dh, 1e-6 * dh), reason: '$id at ${p.chainage}');
        }
      }
      // b runs from J2 (z 12) to J1 (z 5): its points carry the elevations in its own direction
      final b = r.links['b']!;
      expect(b.points.first.elevation, 12);
      expect(b.points.last.elevation, 5);
      expect(b.points[1].elevation, closeTo(12 - 7 * b.points[1].chainage / 450, 1e-9));
      final j2 = r.nodes['J2']!;
      expect(j2.maxHead, closeTo(100 + dh, 1e-6 * dh));
      expect(j2.maxPressure, closeTo(100 + dh - 12, 1e-6 * dh));
      expect(r.seriesOf('J2')!.heads.first, closeTo(steady.nodes['J2']!.head, 1e-9));
      // link b is oriented against the grid: its flow is negative (the grid
      // takes the steady flow of a; the solver balances them to ~1e-5)
      expect(r.seriesOf('b')!.flows.first, closeTo(steady.links['b']!.flow, 1e-5 * steady.links['b']!.flow.abs()));
      expect(steady.links['b']!.flow, lessThan(0));
    });

    test('short pipes are lumped, misfits interpolated, adjustments reported', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 150));
      net.addNode(HNode(id: 'J'));
      net.addNode(HNode(id: 'N'));
      net.addNode(HNode(id: 'S', demand: 0.002));
      net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addLink(HLink(id: 'main', from: 'R', to: 'J', diameter: 0.3, length: 1000, hazenC: 140));
      net.addLink(HLink(id: 'stub', from: 'J', to: 'S', diameter: 0.05, length: 0.5, hazenC: 140));
      net.addLink(HLink(id: 'tail', from: 'J', to: 'N', diameter: 0.25, length: 137, hazenC: 140));
      net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: const DeviceLossCurve(k: 16875)));
      final steady = net.solve();
      const data = {'main': TransientLinkData(celerity: 1000), 'stub': TransientLinkData(celerity: 1000), 'tail': TransientLinkData(celerity: 1000)};
      final model = TransientModel.fromNetwork(net, steady, linkData: data);
      final auto = model.simulate(events: [TransientEvent.valveClosure('V', closureTime: 3)], options: const TransientOptions(duration: 10, probes: [TransientProbe.link('main', fraction: 1), TransientProbe.link('stub', fraction: 0), TransientProbe.link('tail', fraction: 0)]));
      expect(auto.messages, isEmpty, reason: 'no cavity: the liquid alone balances at J');
      expect(auto.lumpedLinks, ['stub']);
      expect(auto.interpolatedLinks, isEmpty);
      expect(auto.maxWaveSpeedAdjustment, lessThanOrEqualTo(0.1 + 1e-12));
      expect(auto.links['stub']!.treatment, TransientLinkTreatment.lumped);
      // continuity at J with the lumped stub
      final qm = auto.seriesOf('main')!.flows, qs = auto.seriesOf('stub')!.flows, qt = auto.seriesOf('tail')!.flows;
      for (var i = 0; i < auto.times.length; i++) {
        expect(qm[i] - qs[i] - qt[i], closeTo(0, 1e-9));
      }
      // a fixed step with a strict tolerance: the tail cannot be fitted and is interpolated
      final fixed = model.simulate(events: [TransientEvent.valveClosure('V', closureTime: 3)], options: const TransientOptions(duration: 10, timeStep: 0.01, maxWaveSpeedAdjustment: 0.001));
      expect(fixed.interpolatedLinks, ['tail']);
      expect(fixed.links['tail']!.reaches, 13);
      expect(fixed.links['tail']!.celerity, 1000, reason: 'interpolation keeps the wave speed');
      expect(fixed.nodes['N']!.maxHead, closeTo(auto.nodes['N']!.maxHead, 0.03 * (auto.nodes['N']!.maxHead - steady.nodes['N']!.head)));
    });

    test('a closed valve opening starts the flow towards the open steady state', () {
      HydraulicNetwork build(HLinkKind kind) {
        final net = HydraulicNetwork();
        net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30));
        net.addNode(HNode(id: 'N'));
        net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
        net.addLink(HLink(id: 'P', from: 'R', to: 'N', diameter: 0.2, length: 400, hazenC: 120));
        net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: kind, device: const DeviceLossCurve(k: 5000)));
        return net;
      }

      final closedNet = build(HLinkKind.closed);
      final steady = closedNet.solve();
      expect(steady.links['V']!.flow.abs(), lessThan(1e-6));
      final open = build(HLinkKind.device).solve();
      final r = TransientModel.fromNetwork(closedNet, steady, linkData: const {'P': TransientLinkData(celerity: 400)}).simulate(
        events: [TransientEvent.valveOpening('V', openingTime: 3)],
        options: const TransientOptions(duration: 120, probes: [TransientProbe.link('V')]),
      );
      final q = r.seriesOf('V')!.flows;
      expect(q.first, 0);
      // the pipe had no steady flow: its constant friction factor is the one
      // at 1 m/s (quasi-steady friction), the open flow runs at 2 m/s
      expect(q.last, closeTo(open.links['V']!.flow, 0.03 * open.links['V']!.flow));
      expect(r.nodes['N']!.minHead, lessThan(steady.nodes['N']!.head - 1), reason: 'opening sends a downsurge');
    });

    test('a check valve device closes on reverse flow; ratings raise messages', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 60));
      net.addNode(HNode(id: 'A'));
      net.addNode(HNode(id: 'B'));
      net.addNode(HNode(id: 'N'));
      net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addLink(HLink(id: 'P1', from: 'R', to: 'A', diameter: 0.25, length: 600, hazenC: 130));
      net.addLink(HLink(id: 'CV', from: 'A', to: 'B', kind: HLinkKind.device, device: const DeviceLossCurve(k: 50), checkValve: true));
      net.addLink(HLink(id: 'P2', from: 'B', to: 'N', diameter: 0.25, length: 900, hazenC: 130));
      net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: const DeviceLossCurve(k: 9000)));
      final steady = net.solve();
      final data = {
        'P1': const TransientLinkData(celerity: 900, rating: 100),
        'P2': const TransientLinkData(celerity: 900, rating: 100, minRating: -3),
      };
      final r = TransientModel.fromNetwork(net, steady, linkData: data).simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 20, probes: [TransientProbe.link('CV')]));
      expect(r.checkValveClosures.keys, contains('CV'));
      expect(r.seriesOf('CV')!.flows.every((q) => q >= 0), isTrue);
      expect(r.messages, contains('transient_overpressure:P2'));
      expect(r.links['P2']!.maxPressure, greaterThan(100));
      if (r.links['P2']!.minPressure < -3) expect(r.messages, contains('transient_underpressure:P2'));
    });

    test('demand stop on emitters as orifices, unknown ids and determinism', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40));
      net.addNode(HNode(id: 'J', elevation: 2));
      net.addNode(HNode(id: 'E', elevation: 1, emitter: const EmitterCurve(k: 0.0005, x: 0.5), emitterCount: 20));
      net.addLink(HLink(id: 'P', from: 'R', to: 'J', diameter: 0.15, length: 700, hazenC: 140));
      net.addLink(HLink(id: 'Q', from: 'J', to: 'E', diameter: 0.1, length: 300, hazenC: 140));
      final steady = net.solve();
      final q0 = steady.nodes['E']!.emitterFlow;
      expect(q0, greaterThan(0));
      final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: 450), 'Q': TransientLinkData(celerity: 450)});
      final events = [
        TransientEvent.demandStop('E', stopTime: 2, mode: DemandStopMode.orifice),
        TransientEvent.valveClosure('nope'),
        TransientEvent.pumpTrip('P'),
        TransientEvent.demandStop('J'),
      ];
      const opts = TransientOptions(duration: 15, probes: [TransientProbe.node('E'), TransientProbe.node('missing')]);
      final r1 = model.simulate(events: events, options: opts);
      final r2 = model.simulate(events: events, options: opts);
      expect(r1.messages, containsAll(['transient_unknown_link:nope', 'transient_not_a_pump:P', 'transient_no_demand:J', 'transient_unknown_node:missing']));
      final s = r1.seriesOf('E')!;
      expect(s.flows.first, closeTo(q0, 1e-12));
      expect(s.flows.last, 0);
      expect(r1.nodes['E']!.maxHead, greaterThan(steady.nodes['E']!.head));
      for (final id in net.nodes.keys) {
        expect(r2.nodes[id]!.maxHead, r1.nodes[id]!.maxHead);
        expect(r2.nodes[id]!.minHead, r1.nodes[id]!.minHead);
      }
      expect(r2.seriesOf('E')!.heads, r1.seriesOf('E')!.heads);
    });

    test('a valve closing at the end of a pipe: surge upstream, downsurge downstream; a τ(t) table', () {
      // frictionless pipes A and B, the flow set by a device at the outlet
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 150));
      net.addNode(HNode(id: 'J'));
      net.addNode(HNode(id: 'N'));
      net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addLink(HLink(id: 'A', from: 'R', to: 'J', diameter: 0.4, length: 1000, hazenC: 1e7));
      net.addLink(HLink(id: 'B', from: 'J', to: 'N', diameter: 0.4, length: 1000, hazenC: 1e7));
      final qv = math.pi * 0.04;
      net.addLink(HLink(id: 'D', from: 'N', to: 'O', kind: HLinkKind.device, device: DeviceLossCurve(k: 150 / (qv * qv))));
      final steady = net.solve();
      const data = {'A': TransientLinkData(celerity: 1000), 'B': TransientLinkData(celerity: 1000)};
      final model = TransientModel.fromNetwork(net, steady, linkData: data);
      final r = model.simulate(events: [TransientEvent.valveClosure('A')], options: const TransientOptions(duration: 1.9, probes: [TransientProbe.link('A', fraction: 1), TransientProbe.node('J')]));
      final q0 = steady.links['A']!.flow;
      final dh = 1000 / gravity * q0 / (math.pi * 0.04);
      final hj = steady.nodes['J']!.head;
      // the valve sits at the end of A, J is just downstream of it
      expect(r.links['A']!.points.last.maxHead, closeTo(hj + dh, 1e-6 * dh));
      expect(r.nodes['J']!.minHead, closeTo(hj - dh, 1e-5 * dh), reason: 'B starts from its own steady flow, equal to A to ~1e-6');
      expect(r.seriesOf('A')!.flows.last, 0);
      // a valve added to a pipe has the small open loss of a gate valve: it
      // throttles only at the very end of its stroke, so even a 3 s stroke
      // closes almost at once
      final slow = model.simulate(events: [TransientEvent.valveClosure('A', table: const [(0, 1), (1, 0.4), (3, 0)])], options: const TransientOptions(duration: 6));
      expect(slow.links['A']!.points.last.maxHead - hj, greaterThan(0.95 * dh));
      // a check valve on a pipe: the downstream reservoir rises above the upstream one
      final cnet = HydraulicNetwork();
      cnet.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 100));
      cnet.addNode(HNode(id: 'J'));
      cnet.addNode(HNode(id: 'N'));
      cnet.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
      cnet.addLink(HLink(id: 'A', from: 'R', to: 'J', diameter: 0.3, length: 800, hazenC: 140, checkValve: true));
      cnet.addLink(HLink(id: 'B', from: 'J', to: 'N', diameter: 0.3, length: 800, hazenC: 140));
      cnet.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: const DeviceLossCurve(k: 3000)));
      final cs = cnet.solve();
      final cr = TransientModel.fromNetwork(cnet, cs, linkData: const {'A': TransientLinkData(celerity: 1000), 'B': TransientLinkData(celerity: 1000)}).simulate(events: [TransientEvent.valveClosure('V')], options: const TransientOptions(duration: 20, probes: [TransientProbe.link('B', fraction: 0)]));
      expect(cr.checkValveClosures['A'], closeTo(2.5, 0.2), reason: 'the wave reflected by R returns to the valve at 2.4 s');
      // the check valve sits at the end of A: the flow through it, into B, never reverses
      expect(cr.seriesOf('B')!.flows.every((q) => q >= -1e-12), isTrue);
      expect(cr.links['A']!.treatment, TransientLinkTreatment.grid);
      // celerity from the wall, by the Korteweg formula of water_hammer.dart
      final pvc = TransientLinkData.fromPipe(diameter: 0.1, wallThickness: 0.005, material: PipeMaterial.pvc, rating: 100);
      expect(pvc.celerity, closeTo(waveCelerity(diameter: 0.1, wallThickness: 0.005, material: PipeMaterial.pvc), 1e-12));
      expect(pvc.celerity, inInclusiveRange(350, 450));
    });

    test('a mainline shaped like the designer\'s keeps its steady state, then trips cleanly', () {
      // well below ground, pump at a reduced speed, filter, check valve, PRV,
      // a closed branch, zone valve demands and a mainline emitter with the
      // 1 cm satellite link the designer adds for a second emitter kind
      final net = HydraulicNetwork(options: const NetworkOptions(method: FrictionMethod.darcyWeisbach));
      net.addNode(HNode(id: 'W', kind: HNodeKind.reservoir, elevation: -15, fixedHead: -15));
      net.addNode(HNode(id: 'P1', elevation: 0));
      net.addNode(HNode(id: 'F1', elevation: 0));
      net.addNode(HNode(id: 'C1', elevation: 0));
      net.addNode(HNode(id: 'M1', elevation: 3));
      net.addNode(HNode(id: 'M2', elevation: 8));
      net.addNode(HNode(id: 'M2b', elevation: 8));
      net.addNode(HNode(id: 'Z1', elevation: 5, demand: 0.006));
      net.addNode(HNode(id: 'Z2', elevation: 9, demand: 0.004));
      net.addNode(HNode(id: 'X', elevation: 6, emitter: const EmitterCurve(k: 0.0004, x: 0.5), emitterOffset: 1));
      net.addNode(HNode(id: 'Xs', elevation: 6, emitter: const EmitterCurve(k: 0.0002, x: 0.46)));
      net.addNode(HNode(id: 'K', elevation: 4));
      net.addLink(HLink(id: 'pump', from: 'W', to: 'P1', kind: HLinkKind.pump, pump: const PumpCurve(a: -60000, b: -100, c: 70, speedRatio: 0.95)));
      net.addLink(HLink(id: 'filter', from: 'P1', to: 'F1', kind: HLinkKind.device, device: const DeviceLossCurve(k: 15000)));
      net.addLink(HLink(id: 'check', from: 'F1', to: 'C1', kind: HLinkKind.device, device: const DeviceLossCurve(k: 2000), checkValve: true));
      net.addLink(HLink(id: 'm1', from: 'C1', to: 'M1', diameter: 0.125, length: 420, roughness: 1.5e-5, minorK: 0.5));
      net.addLink(HLink(id: 'm2', from: 'M1', to: 'M2', diameter: 0.125, length: 380, roughness: 1.5e-5));
      net.addLink(HLink(id: 'prv', from: 'M2', to: 'M2b', kind: HLinkKind.prv, prvSetting: 8, device: const DeviceLossCurve(k: 800)));
      net.addLink(HLink(id: 'z1', from: 'M1', to: 'Z1', diameter: 0.1, length: 150, roughness: 1.5e-5));
      net.addLink(HLink(id: 'z2', from: 'M2b', to: 'Z2', diameter: 0.075, length: 120, roughness: 1.5e-5));
      net.addLink(HLink(id: 'x', from: 'M2', to: 'X', diameter: 0.05, length: 30, roughness: 1.5e-5));
      net.addLink(HLink(id: 'sat_Xs', from: 'X', to: 'Xs', diameter: 0.5, length: 0.01, hazenC: 150));
      net.addLink(HLink(id: 'iso', from: 'M1', to: 'K', kind: HLinkKind.closed, diameter: 0.05));
      final steady = net.solve();
      expect(steady.converged, isTrue);
      expect(steady.links['prv']!.status, LinkStatus.active);
      final data = {
        for (final id in ['m1', 'm2', 'z1', 'z2', 'x', 'sat_Xs']) id: TransientLinkData.fromPipe(diameter: 0.1, wallThickness: 0.006, material: PipeMaterial.pehd, rating: 100),
      };
      final model = TransientModel.fromNetwork(net, steady, linkData: data);
      // nothing moves beyond the tolerance of the steady solution
      final quiet = model.simulate(options: const TransientOptions(duration: 20));
      for (final e in quiet.nodes.values) {
        expect(e.maxHead - e.steadyHead, lessThan(1e-4), reason: e.nodeId);
        expect(e.steadyHead - e.minHead, lessThan(1e-4), reason: e.nodeId);
      }
      for (final l in quiet.links.values) {
        for (final p in l.points) {
          expect(p.maxHead - p.minHead, lessThan(1e-4), reason: '${l.linkId} at ${p.chainage}');
        }
      }
      expect(quiet.lumpedLinks, contains('sat_Xs'));
      expect(quiet.messages, isEmpty);
      final trip = model.simulate(events: [TransientEvent.pumpTrip('pump', powerKw: 5.5, speedRpm: 2900 * 0.95), TransientEvent.demandStop('Z1', stopTime: 2, startTime: 5)], options: const TransientOptions(duration: 40, probes: [TransientProbe.link('pump'), TransientProbe.link('check')]));
      expect(trip.messages.where((m) => m.startsWith('transient_not_converged')), isEmpty);
      expect(trip.checkValveClosures.keys, anyOf(contains('pump'), contains('check')));
      expect(trip.seriesOf('check')!.flows.every((q) => q >= 0), isTrue);
      expect(trip.nodes['C1']!.minHead, lessThan(steady.nodes['C1']!.head));
      // a demand fed only through a closed link is flagged: the steady
      // solver passed it through the closed link's 10⁻⁸ conductance
      net.nodes['K']!.demand = 0.003;
      final bad = TransientModel.fromNetwork(net, net.solve(), linkData: data).simulate(options: const TransientOptions(duration: 1));
      expect(bad.messages, contains('transient_closed_link_flow:iso'));
    });

    test('a farm mainline of a few hundred pipes runs tens of seconds quickly', () {
      // pump from a well, a 3 km trunk telescoping 250/200/150 mm in 50 m pieces
      // with 30 m elevation changes, 24 submains of 10 × 40 m pieces with a
      // 1.5 m riser and a zone demand each, a PRV and a filter on the trunk
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'W', kind: HNodeKind.reservoir, fixedHead: -20, elevation: -20));
      net.addNode(HNode(id: 'P0', elevation: 0));
      net.addLink(HLink(id: 'pump', from: 'W', to: 'P0', kind: HLinkKind.pump, pump: const PumpCurve(a: -2500, b: -50, c: 110)));
      net.addNode(HNode(id: 'F0', elevation: 0));
      net.addLink(HLink(id: 'filter', from: 'P0', to: 'F0', kind: HLinkKind.device, device: const DeviceLossCurve(k: 300)));
      var prev = 'F0';
      final data = <String, TransientLinkData>{};
      var pipes = 0;
      for (var i = 1; i <= 60; i++) {
        final id = 'T$i';
        final dia = i <= 20 ? 0.25 : (i <= 40 ? 0.2 : 0.15);
        net.addNode(HNode(id: id, elevation: 15 * math.sin(i / 7) + 0.2 * i));
        net.addLink(HLink(id: 'm$i', from: prev, to: id, diameter: dia, length: 50, hazenC: 145));
        data['m$i'] = TransientLinkData(celerity: dia > 0.2 ? 420 : 380, rating: 100);
        pipes++;
        if (i == 30) {
          net.addNode(HNode(id: 'T30b', elevation: net.nodes[id]!.elevation));
          net.addLink(HLink(id: 'prv', from: id, to: 'T30b', kind: HLinkKind.prv, prvSetting: 45, device: const DeviceLossCurve(k: 100)));
          prev = 'T30b';
        } else {
          prev = id;
        }
        if (i % 3 == 0 || i == 58) {
          var sub = prev;
          for (var k = 1; k <= 10; k++) {
            final sid = 'S$i-$k';
            net.addNode(HNode(id: sid, elevation: net.nodes[prev]!.elevation + 0.3 * k));
            net.addLink(HLink(id: 's$i-$k', from: sub, to: sid, diameter: k <= 5 ? 0.1 : 0.075, length: 40, hazenC: 145));
            data['s$i-$k'] = const TransientLinkData(celerity: 350, rating: 80);
            pipes++;
            sub = sid;
          }
          final zid = 'Z$i';
          net.addNode(HNode(id: zid, elevation: net.nodes[sub]!.elevation + 1.5, demand: 0.004));
          net.addLink(HLink(id: 'r$i', from: sub, to: zid, diameter: 0.075, length: 1.5, hazenC: 145));
          data['r$i'] = const TransientLinkData(celerity: 350);
          pipes++;
        }
      }
      final steady = net.solve();
      expect(steady.converged, isTrue);
      final model = TransientModel.fromNetwork(net, steady, linkData: data);
      final watch = Stopwatch()..start();
      final r = model.simulate(events: [TransientEvent.pumpTrip('pump', powerKw: 30, speedRpm: 2900)], options: const TransientOptions(duration: 60));
      watch.stop();
      expect(pipes, greaterThan(250));
      expect(r.maxWaveSpeedAdjustment, lessThanOrEqualTo(0.1 + 1e-12));
      expect(watch.elapsedMilliseconds, lessThan(20000));
      expect(r.checkValveClosures.keys, contains('pump'));
      // a fine grid up to the work budget
      final watch2 = Stopwatch()..start();
      final fine = model.simulate(events: [TransientEvent.pumpTrip('pump', powerKw: 30, speedRpm: 2900)], options: const TransientOptions(duration: 60, maxTimeStep: 0.002));
      watch2.stop();
      expect(fine.steps * fine.reaches, lessThanOrEqualTo(4.4e7));
      expect(watch2.elapsedMilliseconds, lessThan(60000));
      // the coarse and fine envelopes agree at the pump discharge
      expect(fine.nodes['F0']!.minHead, closeTo(r.nodes['F0']!.minHead, 3));
      expect(fine.nodes['F0']!.maxHead, closeTo(r.nodes['F0']!.maxHead, 0.1 * (r.nodes['F0']!.maxHead - r.nodes['F0']!.minHead)));
    });
  });
}
