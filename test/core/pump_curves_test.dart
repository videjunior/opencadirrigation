/// Pump curves (MOT-01): the least-squares parabola of a data sheet with a
/// flat top rose from its shutoff to a hump (68 of the 83 pumps of one
/// manufacturer pack), and the solver closed the pump whenever the gain asked
/// for passed the shutoff head, also right of the hump: designs that did not
/// converge, valves with twice the head the pump gives, tanks the pump could
/// fill reported without flow. Such curves now go through the points
/// (monotone cubic), and the status test uses the top of the curve.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A data sheet of a small centrifugal pump at 60 Hz (flat top: 17 m at no
/// flow, 16 m at 15.5 m³/h).
const _flatTop = [(0.0, 17.0), (0.00430556, 16.0), (0.00583333, 14.0), (0.00697222, 12.0), (0.00744444, 11.0), (0.00788889, 10.0), (0.00833333, 9.0), (0.00872222, 8.0)];

/// Every pump of the default catalogue and of the packs in catalogs/.
List<(String, PumpSpec)> _allPumps() => [
  for (final p in Catalog.defaultCatalog().pumps) ('default', p),
  for (final f in Directory('catalogs').listSync().whereType<File>().where((f) => f.path.endsWith(catalogPackExtension)))
    for (final p in CatalogIo.parsePack(f.readAsStringSync()).catalog.pumps) (f.uri.pathSegments.last, p),
];

HydraulicNetwork _lift(PumpCurve c, double lift, {double diameter = 0.1, double length = 20}) => HydraulicNetwork()
  ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 0))
  ..addNode(HNode(id: 'S', elevation: 0))
  ..addNode(HNode(id: 'T', kind: HNodeKind.reservoir, elevation: lift, fixedHead: lift))
  ..addLink(HLink(id: 'pump', from: 'R', to: 'S', kind: HLinkKind.pump, pump: c))
  ..addLink(HLink(id: 'p', from: 'S', to: 'T', diameter: diameter, length: length));

void main() {
  test('monotone slopes: Fritsch-Butland harmonic mean inside, the three-point formula at the ends', () {
    // hand values: secants 1 and 0.5 over steps 1 and 2; inside
    // (w1 + w2) / (w1/δ0 + w2/δ1) with w1 = 2·2 + 1, w2 = 2 + 2·1 → 9/13;
    // ends ((2h0 + h1)δ0 − h0δ1)/(h0 + h1) → 7/6 and 1/6 (as MATLAB's pchip)
    final d = PumpCurve.monotoneSlopes([0, 1, 3], [0, 1, 2]);
    expect(d[0], closeTo(7 / 6, 1e-12));
    expect(d[1], closeTo(9 / 13, 1e-12));
    expect(d[2], closeTo(1 / 6, 1e-12));
    // a local extreme or a flat piece gets a zero slope
    expect(PumpCurve.monotoneSlopes([0, 1, 2], [0, 1, 0])[1], 0);
    expect(PumpCurve.monotoneSlopes([0, 1, 2, 3], [5, 5, 4, 2])[1], 0);
  });

  test('the default catalogue keeps its parabolas; a flat-top data sheet goes through its points', () {
    for (final p in Catalog.defaultCatalog().pumps) {
      expect(p.curve.throughPoints, isFalse, reason: '${p.id}: the parabola stands for the generic curves');
    }
    final c = PumpCurve.fit(_flatTop);
    expect(c.throughPoints, isTrue);
    for (final (q, h) in _flatTop) {
      expect(c.head(q), closeTo(h, 1e-9), reason: 'through the point at $q');
    }
    // it never rises: the parabola gave 17.36 m at 7.2 m³/h, above its shutoff
    expect(c.head(0.002), lessThan(17));
    expect(c.head(0.002), greaterThan(16));
    expect(c.maxHead, closeTo(17, 1e-9));
    expect(c.peakFlow, 0);
    expect(c.b, lessThanOrEqualTo(0), reason: 'the closed-form parabola does not rise either');
    // speed: affinity laws
    final s = c.withSpeed(0.8);
    expect(s.head(0.8 * 0.005), closeTo(0.64 * c.head(0.005), 1e-9));
    expect(s.runoutFlow, closeTo(0.8 * c.runoutFlow, 1e-12));
    expect(c.runoutFlow, greaterThan(0.00872222));
    expect(c.runoutFlow.isFinite, isTrue);
    // saved and read back
    final back = PumpCurve.fromJson(c.toJson());
    expect(back.throughPoints, isTrue);
    for (final q in [0.0, 0.001, 0.005, 0.0087, 0.01]) {
      expect(back.head(q), closeTo(c.head(q), 1e-12));
      expect(back.gradient(q), closeTo(c.gradient(q), 1e-9));
    }
  });

  test('rising data are held at their top; a curve turning up without reaching zero head goes through its points', () {
    final c = PumpCurve.fit([(0, 40), (0.005, 42), (0.01, 41), (0.02, 30)]);
    expect(c.throughPoints, isTrue);
    expect(c.shutoffHead, closeTo(42, 1e-9));
    expect(c.maxHead, closeTo(42, 1e-9));
    for (var q = 0.0; q < c.runoutFlow; q += c.runoutFlow / 200) {
      expect(c.gradient(q), lessThanOrEqualTo(1e-9), reason: 'falls at $q');
    }
    // the parabola through (0, 50), (0.01, 35), (0.02, 25) turns up at 19.4 m
    final convex = PumpCurve.fit([(0, 50), (0.01, 35), (0.02, 25)]);
    expect(convex.throughPoints, isTrue);
    expect(convex.runoutFlow.isFinite, isTrue);
    final open = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 0))
      ..addNode(HNode(id: 'S', elevation: 0))
      ..addNode(HNode(id: 'D', elevation: 0))
      ..addNode(HNode(id: 'R2', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 0))
      ..addLink(HLink(id: 'pump', from: 'R', to: 'S', kind: HLinkKind.pump, pump: convex))
      ..addLink(HLink(id: 'p', from: 'S', to: 'D', diameter: 0.3, length: 10))
      ..addLink(HLink(id: 'p2', from: 'D', to: 'R2', diameter: 0.3, length: 10));
    final r = open.solve();
    expect(r.converged, isTrue, reason: 'the heads ran off to 10³⁰ m');
    expect(r.links['pump']!.flow, inInclusiveRange(0.02, convex.runoutFlow));
  });

  test('a pump runs right of the top of its curve (status by the highest head, not the shutoff head)', () {
    // a parabola that rises from 40 m to 42.04 m at 5.8 L/s
    const humped = PumpCurve(a: -60000, b: 700, c: 40);
    expect(humped.maxHead, closeTo(42.0417, 1e-3));
    for (final lift in [40.5, 41.0]) {
      final r = _lift(humped, lift, diameter: 0.2, length: 50).solve();
      expect(r.converged, isTrue);
      expect(r.links['pump']!.status, LinkStatus.open, reason: 'lift $lift');
      expect(r.links['pump']!.flow, greaterThan(0.006), reason: 'on the falling part');
    }
    // a demand above the shutoff head but below the top
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 0))
      ..addNode(HNode(id: 'S', elevation: 0))
      ..addNode(HNode(id: 'D', elevation: 40.5, demand: 0.008))
      ..addLink(HLink(id: 'pump', from: 'R', to: 'S', kind: HLinkKind.pump, pump: humped))
      ..addLink(HLink(id: 'p', from: 'S', to: 'D', diameter: 0.2, length: 50));
    final r = net.solve();
    expect(r.converged, isTrue);
    expect(r.nodes['D']!.pressure, inInclusiveRange(0, 2), reason: 'it was -800 000 m');
  });

  test('the flat-top pump fills a tank below its shutoff head and feeds fixed duties', () {
    final c = PumpCurve.fit(_flatTop);
    for (final lift in [16.5, 16.9]) {
      final r = _lift(c, lift).solve();
      expect(r.converged, isTrue);
      expect(r.links['pump']!.flow, greaterThan(0), reason: 'lift $lift');
    }
    expect(_lift(c, 17.1).solve().links['pump']!.status, LinkStatus.closed, reason: 'above the shutoff head');
    for (final (q, z) in [(0.002, 14.0), (0.002, 16.5), (0.0035, 15.5)]) {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 0))
        ..addNode(HNode(id: 'S', elevation: 0))
        ..addNode(HNode(id: 'D', elevation: z, demand: q))
        ..addLink(HLink(id: 'pump', from: 'R', to: 'S', kind: HLinkKind.pump, pump: c))
        ..addLink(HLink(id: 'p', from: 'S', to: 'D', diameter: 0.1, length: 20));
      final r = net.solve();
      expect(r.converged, isTrue, reason: '$q m³/s at $z m');
      expect(r.links['pump']!.status, LinkStatus.open);
      expect(r.nodes['D']!.pressure, closeTo(c.head(q) - z, 0.05));
    }
  });

  test('a design fed by the flat-top pump converges with the head the pump gives', () {
    for (final width in [20.0, 70.0]) {
      final p = Project();
      p.params.mainsHz = 60;
      p.catalog.pumps.add(PumpSpec(id: 'flat', name: 'flat top', points: _flatTop, efficiency: 0.62, maxFlow: 0.00872222, powerKw: 1.47, ratedHz: 60));
      final block = generateBlock(
        p,
        BlockOptions(
          polygon: [const Pt(0, 0), Pt(width, 0), Pt(width, 30), const Pt(0, 30)],
          direction: const Pt(1, 0),
          lateralSpacing: 4,
          outletSpecId: 'micro',
          nozzleId: 'm50',
          outletSpacing: 3.5,
          headM: 10,
          submainPosition: SubmainPosition.start,
          valveSpecId: 'ev50',
          valvePosition: ValvePosition.centre,
          submainStub: 1.5,
          zoneName: 'Z',
        ),
      );
      p.entities.addAll(block.all);
      final valve = block.valve!;
      final supplyPos = valve.position + const Pt(-30, 0);
      p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supplyPos, name: 'Tank', calculatePressure: false, designHeadM: 0.5, waterLevelOffsetM: 0));
      p.entities.add(PumpEntity(id: 'pump', position: Pt(supplyPos.x + 3, supplyPos.y), pumpSpecId: 'flat', name: 'Pump'));
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      expect(f.converged, isTrue, reason: '$width m');
      expect(f.warnings, isNot(contains('not_converged')));
      final pump = f.devices.firstWhere((d) => d.entityId == 'pump');
      expect(pump.status, 'open');
      // the valve cannot have more than the tank and the pump give (it had 31–38 m)
      expect(f.valves.single.availableHead, lessThan(0.5 + 17 + 1e-6));
      expect(f.valves.single.availableHead, greaterThan(r.zones.values.single.requiredUpstreamHead - 0.01));
    }
  });

  test('every catalogue pump curve falls from its top to a finite runout and stays within 3 % of its points', () {
    final pumps = _allPumps();
    expect(pumps.length, greaterThan(80));
    var through = 0;
    for (final (src, p) in pumps) {
      final why = '$src ${p.id}';
      final c = p.curve;
      if (c.throughPoints) through++;
      expect(c.runoutFlow.isFinite, isTrue, reason: '$why: runout');
      expect(c.maxHead, lessThanOrEqualTo(c.shutoffHead * (1 + PumpCurve.humpTolerance) + 1e-9), reason: '$why: hardly above its shutoff head');
      final top = p.points.fold(0.0, (m, e) => math.max(m, e.$2));
      for (final (q, h) in p.points) {
        expect(c.head(q), closeTo(h, PumpCurve.fitTolerance * top + 1e-9), reason: '$why at $q');
      }
      var last = c.head(0);
      for (var i = 1; i <= 100; i++) {
        final q = c.runoutFlow * i / 100;
        final h = c.head(q);
        expect(h, lessThanOrEqualTo(last + PumpCurve.humpTolerance * c.shutoffHead), reason: '$why rises at $q');
        last = h;
      }
    }
    expect(through, greaterThan(50), reason: 'the flat-top data sheets');
  });

  test('the transient pump element uses the tangent parabola of a curve through points', () {
    final c = PumpCurve.fit(_flatTop).withSpeed(0.9);
    for (final q in [0.002, 0.006]) {
      final (a, b, cc) = c.localParabola(q);
      expect(a * q * q + b * q + cc, closeTo(c.head(q), 1e-9));
      expect(2 * a * q + b, closeTo(c.gradient(q), 1e-6));
    }
    const p = PumpCurve(a: -2000, b: -50, c: 40, speedRatio: 0.9);
    final (a, b, cc) = p.localParabola(0.01);
    expect(a, -2000);
    expect(b, closeTo(-45, 1e-12));
    expect(cc, closeTo(40 * 0.81, 1e-12));
  });
}
