import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/two_wire.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A controller at the origin and one route along x to [length], valves at
/// [xs].
Project _line(List<double> xs, {double length = 1000, int stations = 12, bool route = true}) {
  final p = Project();
  p.entities.add(ControllerEntity(id: 'ctl', position: Pt.zero, name: 'Ctrl', stations: stations));
  if (route) p.entities.add(WireEntity(id: 'w', points: [Pt.zero, Pt(length, 0)]));
  for (var i = 0; i < xs.length; i++) {
    p.entities.add(ControlValveEntity(id: 'v${i + 1}', position: Pt(xs[i], 0), zoneName: 'Z${i + 1}'));
  }
  return p;
}

void main() {
  const xs = [200.0, 400.0, 600.0, 800.0, 1000.0];
  const all = [
    {'v1', 'v2', 'v3', 'v4', 'v5'},
  ];
  // drop per Ω/m of conductor at the farthest decoder while its station
  // opens and the other four hold: I = idle 1 mA per decoder + 0.37 / 0.22 A
  // on each 200 m stretch, both conductors, 10 % slack
  const worstDrop = 2 * 200 * 1.1 * (1.255 + 1.034 + 0.813 + 0.592 + 0.371);

  test('voltage along the pair by hand, the cheapest wire that keeps 24 V', () {
    final p = _line(xs);
    final r = designTwoWire(p, flows: all)!;
    expect(r.warnings, isEmpty);
    final path = r.paths.single;
    expect(path.wireId, 'w4');
    expect(path.worstVolts, closeTo(34 - worstDrop * copperOhmPerKm(4) / 1000, 1e-9));
    expect(path.routeM, closeTo(1000, 1e-9));
    expect(path.cableM, closeTo(1100, 1e-9));
    expect(path.decoders, 5);
    expect(path.maxOpen, 5);
    expect(path.peakCurrentA, closeTo(0.005 + 0.37 + 4 * 0.22, 1e-12));
    expect(r.wireMeters['w4'], closeTo(2200, 1e-9));
    // every size on the path: thinner ones fail, and how far each could go
    final w6 = path.sizes.firstWhere((s) => s.wireId == 'w6');
    expect(w6.ok, isTrue);
    expect(w6.maxDistanceM, closeTo(1000 * 10 / (worstDrop * copperOhmPerKm(6) / 1000), 1e-6));
    expect(path.sizes.firstWhere((s) => s.wireId == 'w2.5').ok, isFalse);
    // stations along the path, one decoder each
    expect([for (final s in r.stations) s.station], [1, 2, 3, 4, 5]);
    expect([for (final s in r.stations) s.routeM], [200, 400, 600, 800, 1000]);
    final v1 = r.stationOf('v1')!;
    expect(v1.volts, closeTo(34 - 2 * 200 * 1.1 * 1.255 * copperOhmPerKm(4) / 1000, 1e-9));
    expect(v1.solenoidCableM, 0);
    expect(v1.openTogether, 5);
    expect(r.decoders.map((d) => d.capacity), [1, 1, 1, 1, 1]);
    expect(r.decoders.last.volts, closeTo(path.worstVolts, 1e-9));
    final back = TwoWireResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.paths.single.worstVolts, path.worstVolts);
    expect(back.stationOf('v5')!.decoderId, r.stationOf('v5')!.decoderId);
    expect(back.grounds.length, r.grounds.length);
  });

  test('only a thin wire: the far stations fall below the minimum', () {
    final p = _line(xs);
    for (final w in p.catalog.wires) {
      w.enabled = w.id == 'w1.5';
    }
    final r = designTwoWire(p, flows: all)!;
    final ohm = copperOhmPerKm(1.5) / 1000;
    expect(r.paths.single.worstVolts, closeTo(34 - worstDrop * ohm, 1e-9));
    // v2 opening: 0.371 A at its decoder plus three holding beyond it
    expect(r.stationOf('v2')!.volts, closeTo(34 - 2 * 200 * 1.1 * (1.255 + 1.034) * ohm, 1e-9));
    expect(r.stationOf('v1')!.ok, isTrue);
    expect(r.warnings, containsAll(['twowire_voltage:v2', 'twowire_voltage:v5']));
    expect(r.warnings, isNot(contains('twowire_voltage:v1')));
  });

  test('valves within the solenoid cable share a decoder of the next size', () {
    final r = designTwoWire(
      _line([1000, 1010, 1020, 1100], length: 1200),
      flows: const [
        {'v1'},
        {'v2'},
        {'v3'},
        {'v4'},
      ],
    )!;
    expect(r.decoders.length, 2);
    expect(r.decoders.first.valveIds, ['v1', 'v2', 'v3']);
    expect(r.decoders.first.capacity, 4);
    expect(r.decoders.last.capacity, 1);
    expect(r.stationOf('v3')!.solenoidCableM, closeTo(22, 1e-9));
    expect(r.stationOf('v3')!.routeM, closeTo(1000, 1e-9));
    expect(r.paths.single.maxOpen, 1);
    final single = designTwoWire(_line([1000, 1010, 1020, 1100], length: 1200), spec: const TwoWireSpec(decoderCapacities: [1]))!;
    expect(single.decoders.length, 4);
  });

  test('grounding points: every 150 m or 12 decoders, the controller and the ends', () {
    final r = designTwoWire(_line(xs), flows: all)!;
    expect([for (final g in r.grounds) g.p.x], [0, 150, 300, 450, 600, 750, 900, 1000]);
    expect(r.grounds.first.kind, GroundKind.controller);
    expect(r.grounds.last.kind, GroundKind.end);
    expect(r.grounds.where((g) => g.decoderId != null).length, 2);
    final byCount = designTwoWire(_line(xs), flows: all, spec: const TwoWireSpec(groundEveryDecoders: 2, groundEveryM: 0))!;
    expect([for (final g in byCount.grounds) g.p.x], [0, 400, 800, 1000]);
  });

  test('routes passed in, codes', () {
    final r = designTwoWire(
      _line(xs, route: false),
      flows: all,
      routes: const [
        [Pt.zero, Pt(1000, 0)],
      ],
    )!;
    expect(r.warnings, isEmpty);
    expect(r.paths.single.wireId, 'w4');
    final few = designTwoWire(_line(xs, stations: 4), flows: all)!;
    expect(few.warnings, contains('twowire_stations:ctl'));
    final off = _line(xs)..entities.add(ControlValveEntity(id: 'far', position: const Pt(0, 500)));
    expect(designTwoWire(off, flows: all)!.warnings, contains('twowire_unwired:far'));
    final none = Project()..entities.add(WireEntity(id: 'w', points: const [Pt.zero, Pt(10, 0)]));
    expect(designTwoWire(none)!.warnings, ['twowire_no_controller']);
    expect(designTwoWire(Project()), isNull);
    final idle = Project()..entities.add(ControllerEntity(id: 'c', position: Pt.zero));
    expect(designTwoWire(idle)!.paths.single.used, 0);
  });
}
