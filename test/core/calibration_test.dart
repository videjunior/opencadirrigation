import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/calibration.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

double _hf(double q, double d, double l, double c) => hazenWilliamsLoss(flow: q, diameter: d, length: l, c: c);

void main() {
  test('one global factor: golden section recovers C = 120 from a pipe built with 150', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'J', demand: 0.01));
    net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.1, length: 500, hazenC: 150));
    final measured = 40 - _hf(0.01, 0.1, 500, 120);
    final r = calibrateRoughness(
      net,
      pressures: [PressureMeasurement(nodeId: 'J', pressure: measured)],
    );
    expect(r.converged, isTrue);
    expect(r.scales.single, closeTo(0.8, 1e-4));
    expect(r.objective, lessThan(1e-6));
    expect(r.initialObjective, greaterThan(1));
    final res = r.residuals.single;
    expect(res.before, closeTo(40 - _hf(0.01, 0.1, 500, 150), 1e-4));
    expect(res.after, closeTo(measured, 1e-3));
    expect(r.rmsePressure, lessThan(1e-3));
    // the network keeps its C
    expect(net.links.single.hazenC, 150);
    // one measurement, one factor: no redundancy for a standard error
    expect(r.codes, contains('calibration_no_redundancy'));
    expect(r.standardErrors.single.isNaN, isTrue);
    final back = CalibrationResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.scales.single, r.scales.single);
    expect(back.standardErrors.single.isNaN, isTrue);
  });

  test('two groups in series: Levenberg–Marquardt recovers both factors', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 60))
      ..addNode(HNode(id: 'J1', demand: 0.004))
      ..addNode(HNode(id: 'J2', elevation: 5, demand: 0.004));
    net.addLink(HLink(id: 'p1', from: 'R', to: 'J1', diameter: 0.1, length: 800, hazenC: 150));
    net.addLink(HLink(id: 'p2', from: 'J1', to: 'J2', diameter: 0.075, length: 600, hazenC: 150));
    final p1 = 60 - _hf(0.008, 0.1, 800, 150 * 0.9);
    final p2 = p1 - 5 - _hf(0.004, 0.075, 600, 150 * 0.7);
    final r = calibrateRoughness(
      net,
      pressures: [
        PressureMeasurement(nodeId: 'J1', pressure: p1),
        PressureMeasurement(nodeId: 'J2', pressure: p2),
      ],
      groups: 2,
      groupOf: const {'p1': 0, 'p2': 1},
    );
    expect(r.converged, isTrue);
    expect(r.scales[0], closeTo(0.9, 1e-3));
    expect(r.scales[1], closeTo(0.7, 1e-3));
    expect(r.objective, lessThan(1e-4));
    expect(r.evaluations, greaterThan(3));
  });

  test('flows split between parallel pipes tell their roughness apart', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'J', demand: 0.02));
    net.addLink(HLink(id: 'a', from: 'R', to: 'J', diameter: 0.1, length: 300, hazenC: 140));
    net.addLink(HLink(id: 'b', from: 'R', to: 'J', diameter: 0.1, length: 300, hazenC: 140));
    // truth: a at C 140, b at C 84 (factor 0.6): the flows split as C
    final truth = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'J', demand: 0.02));
    truth.addLink(HLink(id: 'a', from: 'R', to: 'J', diameter: 0.1, length: 300, hazenC: 140));
    truth.addLink(HLink(id: 'b', from: 'R', to: 'J', diameter: 0.1, length: 300, hazenC: 84));
    final t = truth.solve();
    expect(t.links['a']!.flow / t.links['b']!.flow, closeTo(140 / 84, 1e-3));
    final r = calibrateRoughness(
      net,
      groups: 2,
      groupOf: const {'a': 0, 'b': 1},
      pressures: [PressureMeasurement(nodeId: 'J', pressure: t.nodes['J']!.pressure, sigma: 0.05)],
      flows: [
        FlowMeasurement(linkId: 'a', flow: t.links['a']!.flow),
        FlowMeasurement(linkId: 'b', flow: t.links['b']!.flow),
      ],
    );
    expect(r.scales[0], closeTo(1.0, 2e-3));
    expect(r.scales[1], closeTo(0.6, 2e-3));
    expect(r.rmseFlow, lessThan(2e-5));
    expect(r.standardErrors.every((s) => s.isFinite), isTrue);
  });

  test('a group no measurement depends on stays at 1; codes', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'J', demand: 0.01))
      ..addNode(HNode(id: 'D'));
    net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.1, length: 500, hazenC: 150));
    net.addLink(HLink(id: 'dead', from: 'J', to: 'D', diameter: 0.05, length: 50, hazenC: 150));
    final measured = 40 - _hf(0.01, 0.1, 500, 135);
    final r = calibrateRoughness(
      net,
      pressures: [
        PressureMeasurement(nodeId: 'J', pressure: measured),
        const PressureMeasurement(nodeId: 'nope', pressure: 1),
      ],
      flows: const [FlowMeasurement(linkId: 'zz', flow: 1)],
      groups: 3,
      groupOf: const {'p': 0, 'dead': 1},
    );
    expect(r.codes, containsAll(['calibration_insensitive:1', 'calibration_empty_group:2', 'calibration_unknown_node:nope', 'calibration_unknown_link:zz']));
    expect(r.scales[0], closeTo(0.9, 1e-4));
    expect(r.scales[1], 1);
    expect(r.scales[2], 1);
    final dw = HydraulicNetwork(options: const NetworkOptions(method: FrictionMethod.darcyWeisbach))
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'J', demand: 0.01));
    dw.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.1, length: 500));
    expect(calibrateRoughness(dw, pressures: const [PressureMeasurement(nodeId: 'J', pressure: 20)]).codes, contains('calibration_not_hazen_williams'));
    expect(calibrateRoughness(net).codes, contains('calibration_no_measurements'));
  });

  test('material groups of a designer network', () {
    final p = Project();
    p.entities.addAll([
      WaterSupplyEntity(id: 'ws', position: const Pt(0, 0), calculatePressure: false, designHeadM: 40),
      PipeEntity(id: 'm1', points: const [Pt(0, 0), Pt(100, 0)], scope: HydraulicScope.mainline, pipeSpecId: p.catalog.pipes.firstWhere((s) => s.material.name == 'pvc').id, computerSized: false),
      PipeEntity(id: 'm2', points: const [Pt(100, 0), Pt(150, 0)], scope: HydraulicScope.mainline, pipeSpecId: p.catalog.pipes.firstWhere((s) => s.material.name != 'pvc').id, computerSized: false),
    ]);
    final d = Designer(p);
    final net = HydraulicNetwork();
    for (final l in d.model.links) {
      net.addLink(HLink(id: l.id, from: l.from, to: l.to, length: l.length, tag: l));
    }
    final (groups, names) = materialGroups(net, p.catalog);
    expect(names.first, 'pvc');
    expect(names.length, 2);
    expect(groups['m1_0'], 0);
    expect(groups['m2_0'], 1);
    final (one, oneNames) = materialGroups(net, p.catalog, maxGroups: 1);
    expect(oneNames, ['other']);
    expect(one.values.toSet(), {0});
  });
}
