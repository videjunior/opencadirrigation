import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/fertigation.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/model/entities.dart';

double _vol(double d, double l) => math.pi * d * d / 4 * l;

void main() {
  test('one pipe: travel time is volume over flow', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'J', demand: 0.002));
    net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.05, length: 120));
    final r = net.solve();
    final t = fertigationTravel(net, r, 'R');
    expect(t.codes, isEmpty);
    expect(t.outlets, ['J']);
    expect(t.nodes['J']!.earliest, closeTo(_vol(0.05, 120) / 0.002, 1e-6));
    expect(t.nodes['J']!.latest, closeTo(_vol(0.05, 120) / 0.002, 1e-6));
    expect(t.farthestArrival, closeTo(_vol(0.05, 120) / 0.002, 1e-6));
    expect(t.fullArrival, t.farthestArrival);
    expect(t.farthestOutlet, 'J');
    expect(t.volume, closeTo(_vol(0.05, 120), 1e-12));
    // real lengths: explicit, or from the designer's link (the solver's
    // length carries the minor-loss allowance)
    expect(fertigationTravel(net, r, 'R', lengths: const {'p': 60}).nodes['J']!.earliest, closeTo(_vol(0.05, 60) / 0.002, 1e-6));
    final tagged = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'J', demand: 0.002));
    tagged.addLink(
      HLink(
        id: 'p',
        from: 'R',
        to: 'J',
        diameter: 0.05,
        length: 105,
        tag: GLink(id: 'p', from: 'R', to: 'J', kind: GLinkKind.pipe, scope: HydraulicScope.mainline, entityId: 'e', length: 100),
      ),
    );
    expect(fertigationTravel(tagged, tagged.solve(), 'R').nodes['J']!.earliest, closeTo(_vol(0.05, 100) / 0.002, 1e-6));
    // offset: chained after the travel to the injection point
    expect(fertigationTravel(net, r, 'R', offsetSeconds: 30).nodes['J']!.earliest, closeTo(30 + _vol(0.05, 120) / 0.002, 1e-6));
    final back = FertigationTravel.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.nodes['J']!.earliest, t.nodes['J']!.earliest);
  });

  test('two paths: first appearance by the fast one, full concentration by the slow one', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'A'))
      ..addNode(HNode(id: 'B', demand: 0.004))
      ..addNode(HNode(id: 'C'));
    net.addLink(HLink(id: 'ra', from: 'R', to: 'A', diameter: 0.1, length: 100));
    net.addLink(HLink(id: 'ab', from: 'A', to: 'B', diameter: 0.05, length: 100));
    net.addLink(HLink(id: 'ac', from: 'A', to: 'C', diameter: 0.075, length: 50));
    net.addLink(HLink(id: 'cb', from: 'C', to: 'B', diameter: 0.075, length: 50));
    final r = net.solve();
    double q(String id) => r.links[id]!.flow;
    final t0 = _vol(0.1, 100) / q('ra');
    final t1 = _vol(0.05, 100) / q('ab');
    final t2 = _vol(0.075, 50) / q('ac') + _vol(0.075, 50) / q('cb');
    final t = fertigationTravel(net, r, 'R');
    expect(t.nodes['B']!.earliest, closeTo(t0 + math.min(t1, t2), 1e-6));
    expect(t.nodes['B']!.latest, closeTo(t0 + math.max(t1, t2), 1e-6));
    expect(t.fullArrival, greaterThan(t.farthestArrival));
  });

  test('outlets with no path from the injection point are reported', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'A'))
      ..addNode(HNode(id: 'B', demand: 0.002))
      ..addNode(HNode(id: 'C', demand: 0.001));
    net.addLink(HLink(id: 'ra', from: 'R', to: 'A', diameter: 0.1, length: 100));
    net.addLink(HLink(id: 'ab', from: 'A', to: 'B', diameter: 0.05, length: 100));
    net.addLink(HLink(id: 'rc', from: 'R', to: 'C', diameter: 0.05, length: 100));
    final t = fertigationTravel(net, net.solve(), 'A');
    expect(t.outlets, ['B']);
    expect(t.unreached, ['C']);
    expect(t.codes, ['fertigation_unreached']);
    expect(fertigationTravel(net, net.solve(), 'X').codes, ['fertigation_unknown_node']);
    expect(fertigationTravel(net, net.solve(), 'B').codes, contains('fertigation_no_flow'));
  });

  test('plan: quarters of the irrigation, amounts by hand', () {
    final travel = FertigationTravel(
      injectionNode: 'R',
      nodes: const {'J': TravelTime(nodeId: 'J', earliest: 900, latest: 1800)},
      outlets: const ['J'],
      unreached: const [],
      volume: 1,
      codes: const [],
    );
    final plan = planFertigation(const FertigationInput(irrigationHours: 4, flow: 0.01, areaHa: 2, doseKgPerHa: 50, nutrientFraction: 0.5, stockKgPerL: 0.25, tankLitres: 1000), travel);
    expect(plan.preWetting, 3600);
    expect(plan.flushing, 3600);
    expect(plan.injection, 7200);
    expect(plan.productKg, closeTo(200, 1e-12));
    expect(plan.stockLitres, closeTo(800, 1e-9));
    expect(plan.injectionRate, closeTo(0.8 / 7200, 1e-15));
    expect(plan.concentration, closeTo(200 / (0.01 * 7200), 1e-9));
    expect(plan.dilution, closeTo(0.01 / (0.8 / 7200), 1e-6));
    expect(plan.codes, isEmpty);
    // a long travel lengthens the flushing
    final slow = FertigationTravel(
      injectionNode: 'R',
      nodes: const {'J': TravelTime(nodeId: 'J', earliest: 3600, latest: 7200)},
      outlets: const ['J'],
      unreached: const [],
      volume: 1,
      codes: const [],
    );
    final p2 = planFertigation(const FertigationInput(irrigationHours: 4, flow: 0.01, areaHa: 2, doseKgPerHa: 50, stockKgPerL: 0.25, tankLitres: 300), slow);
    expect(p2.flushing, 7200);
    expect(p2.injection, 3600);
    expect(p2.codes, ['fertigation_tank_small']);
    // too short to inject
    final p3 = planFertigation(const FertigationInput(irrigationHours: 2, flow: 0.01, areaHa: 1, doseKgPerHa: 10, stockKgPerL: 0.2), slow);
    expect(p3.injection, 0);
    expect(p3.codes, ['fertigation_too_short']);
    expect(p3.preWetting + p3.flushing, 7200);
    final back = FertigationPlan.fromJson(jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
    expect(back.dilution, closeTo(plan.dilution, 1e-9));
  });

  test('venturi: from a suction curve or the typical share of the inlet pressure', () {
    const spec = VenturiSpec(curve: [(5, 0.0001), (10, 0.0003), (20, 0.0006)]);
    final ok = checkVenturi(spec, injectionRate: 0.0002, inletPressure: 30, availableDifferential: 8);
    expect(ok.requiredDifferential, closeTo(7.5, 1e-9));
    expect(ok.suctionCapacity, closeTo(0.0003 - 0.0002 * 2 / 5, 1e-12));
    expect(ok.ok, isTrue);
    final low = checkVenturi(spec, injectionRate: 0.0002, inletPressure: 30, availableDifferential: 6);
    expect(low.ok, isFalse);
    expect(low.codes, ['venturi_insufficient_differential']);
    final big = checkVenturi(spec, injectionRate: 0.001, inletPressure: 30, availableDifferential: 25);
    expect(big.codes, contains('venturi_capacity_exceeded'));
    expect(big.ok, isFalse);
    final typical = checkVenturi(const VenturiSpec(), injectionRate: 0.0002, inletPressure: 30, availableDifferential: 5);
    expect(typical.requiredDifferential, closeTo(6, 1e-12));
    expect(typical.ok, isFalse);
    expect(typical.suctionCapacity.isNaN, isTrue);
    expect(jsonEncode(typical.toJson()), contains('"cap":null'));
  });
}
