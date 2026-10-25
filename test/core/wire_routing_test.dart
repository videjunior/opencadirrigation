import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/two_wire.dart';
import 'package:opencadirrigation/core/design/wire_routing.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A mainline 0→100 along x, a zone pipe up from its end and a branch up
/// from its middle (a tee without a shared vertex); the controller off the
/// pipes, three valves.
Project _site({int stations = 12}) {
  final p = Project();
  p.entities.addAll([
    ControllerEntity(id: 'ctl', position: const Pt(-20, -10), stations: stations),
    PipeEntity(id: 'm1', points: const [Pt(0, 0), Pt(100, 0)], scope: HydraulicScope.mainline),
    PipeEntity(id: 'z1', points: const [Pt(100, 0), Pt(100, 50)], scope: HydraulicScope.zone),
    PipeEntity(id: 'z2', points: const [Pt(50, 0), Pt(50, 40)], scope: HydraulicScope.zone),
    ControlValveEntity(id: 'vA', position: const Pt(100, 50), zoneName: 'A'),
    ControlValveEntity(id: 'vB', position: const Pt(50, 40), zoneName: 'B'),
    ControlValveEntity(id: 'vC', position: const Pt(70, 0.03), zoneName: 'C'),
  ]);
  return p;
}

final _stub = math.sqrt(20 * 20 + 10 * 10);

void main() {
  test('shortest paths along the trenches, stations by distance', () {
    final p = _site();
    final r = autoRouteWires(p);
    expect(r.warnings, isEmpty);
    final st = {for (final s in r.stations) s.entityId: s};
    expect(st['vC']!.station, 1);
    expect(st['vB']!.station, 2);
    expect(st['vA']!.station, 3);
    expect(st['vC']!.routeM, closeTo(_stub + 70, 1e-9));
    expect(st['vB']!.routeM, closeTo(_stub + 90, 1e-9));
    expect(st['vA']!.routeM, closeTo(_stub + 150, 1e-9));
    expect(r.totalRouteM, closeTo(_stub + 190, 1e-9));
    expect(r.routeLengthOf('ctl'), closeTo(_stub + 190, 1e-9));
    // polylines between branch points, sharing their end vertices
    expect(r.routes.length, 3);
    expect(r.routes.first.points.first, const Pt(-20, -10));
    final ends = [for (final w in r.routes) ...[w.points.first, w.points.last]];
    expect(ends.where((e) => e == const Pt(50, 0)).length, 3);
    // the valve wiring connects them: every valve reached at those lengths
    for (var i = 0; i < r.routes.length; i++) {
      p.entities.add(WireEntity(id: 'wr$i', points: r.routes[i].points));
    }
    final e = designElectrical(p, flows: const [{'vA', 'vB', 'vC'}])!;
    expect(e.warnings.where((w) => w.startsWith('elec_unwired') || w.startsWith('elec_wire_orphan') || w.startsWith('elec_ctrl_unwired')), isEmpty);
    final runs = {for (final x in e.runs) x.valveId: x};
    expect(runs['vC']!.routeM, closeTo(_stub + 70, 1e-6));
    expect(runs['vA']!.routeM, closeTo(_stub + 150, 1e-6));
    expect([for (final x in e.runs) x.station], [1, 2, 3]);
    final back = WireRoutingResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.totalRouteM, closeTo(r.totalRouteM, 1e-9));
    expect(back.stations.first.kind, StationKind.zoneValve);
  });

  test('a Steiner-like tree for a two-wire path is shorter than the shortest paths', () {
    const pipes = [
      [Pt(0, 0), Pt(100, 0)], [Pt(100, 0), Pt(100, 10)], [Pt(100, 0), Pt(100, -10)],
      [Pt(0, 0), Pt(100, 10)], [Pt(0, 0), Pt(100, -10)],
    ];
    const valves = {'vA': Pt(100, 10), 'vB': Pt(100, -10)};
    final spt = routeWires(controllers: const {'c': Pt.zero}, valves: valves, pipes: pipes);
    final diag = math.sqrt(100 * 100 + 10 * 10);
    expect(spt.totalRouteM, closeTo(2 * diag, 1e-9));
    final steiner = routeWires(controllers: const {'c': Pt.zero}, valves: valves, pipes: pipes, options: const WireRoutingOptions(mode: RoutingMode.steiner));
    expect(steiner.totalRouteM, closeTo(diag + 20, 1e-9));
    expect(steiner.stations.firstWhere((s) => s.entityId == 'vB').routeM, closeTo(diag + 20, 1e-9));
    // the two-wire design runs on those routes
    final p = Project()
      ..entities.addAll([
        ControllerEntity(id: 'c', position: Pt.zero),
        for (final v in valves.entries) ControlValveEntity(id: v.key, position: v.value),
      ]);
    final tw = designTwoWire(p, routes: [for (final w in steiner.routes) w.points])!;
    expect(tw.warnings, isEmpty);
    expect(tw.paths.single.routeM, closeTo(diag + 20, 1e-9));
  });

  test('master valve and pump-start relay after the zone valves', () {
    final p = _site(stations: 4);
    final control = p.catalog.valves.firstWhere((v) => v.kind == ValveKind.control);
    p.entities.addAll([
      MiscHydraulicEntity(id: 'mv', position: const Pt(30, 0), valveSpecId: control.id),
      PumpEntity(id: 'pump', position: const Pt(5, 0)),
    ]);
    final r = autoRouteWires(p);
    final st = {for (final s in r.stations) s.entityId: s};
    expect(st['mv']!.kind, StationKind.masterValve);
    expect(st['mv']!.station, 4);
    expect(st['mv']!.routeM, closeTo(_stub + 30, 1e-9));
    expect(st['pump']!.kind, StationKind.pumpRelay);
    expect(st['pump']!.station, 5);
    expect(r.warnings, ['wire_route_stations:ctl']);
    final dedicated = autoRouteWires(p, options: const WireRoutingOptions(masterValveStations: false, pumpRelayStations: false));
    expect(dedicated.stations.where((s) => s.kind != StationKind.zoneValve).every((s) => s.station == 0), isTrue);
    expect(dedicated.warnings, isEmpty);
  });

  test('crossing trenches join; codes', () {
    const pipes = [[Pt(0, 50), Pt(100, 50)], [Pt(50, 0), Pt(50, 100)]];
    final joined = routeWires(controllers: const {'c': Pt(0, 50)}, valves: const {'v': Pt(50, 100)}, pipes: pipes);
    expect(joined.warnings, isEmpty);
    expect(joined.stations.single.routeM, closeTo(100, 1e-9));
    final apart = routeWires(controllers: const {'c': Pt(0, 50)}, valves: const {'v': Pt(50, 100)}, pipes: pipes, options: const WireRoutingOptions(connectCrossings: false));
    expect(apart.warnings, ['wire_route_unreachable:v']);
    final stub = routeWires(controllers: const {'c': Pt.zero}, valves: const {'v': Pt(50, 80)}, pipes: const [[Pt.zero, Pt(100, 0)]]);
    expect(stub.warnings, ['wire_route_long_stub:v']);
    expect(stub.stations.single.routeM, closeTo(130, 1e-9));
    expect(routeWires(controllers: const {}, valves: const {'v': Pt.zero}, pipes: const []).warnings, ['wire_route_no_controller']);
    final bare = routeWires(controllers: const {'c': Pt.zero}, valves: const {'v': Pt(5, 5)}, pipes: const []);
    expect(bare.warnings, containsAll(['wire_route_no_pipes', 'wire_route_unreachable:v']));
    // two controllers: each valve to the nearest along the trenches
    final two = routeWires(controllers: const {'a': Pt.zero, 'b': Pt(100, 0)}, valves: const {'v1': Pt(20, 0), 'v2': Pt(90, 0)}, pipes: const [[Pt.zero, Pt(100, 0)]]);
    expect({for (final s in two.stations) s.entityId: s.controllerId}, {'v1': 'a', 'v2': 'b'});
  });
}
