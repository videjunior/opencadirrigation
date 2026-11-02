// 1.6.0 MOT+: pump stations (PRD-17) — pumps in parallel or in series, on
// duty or on standby, staged by the flow; the curves they join into, the
// duty of every pump, the energy, the bill of materials and the report.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// A tank at zero pressure, a pump item and one micro-sprinkler zone of
/// [width] × [height] metres 100 m away.
Project stationProject({required double width, required double height, PumpStation? station, String pump = 'pump_c1'}) {
  final p = Project();
  final block = generateBlock(
    p,
    BlockOptions(
      polygon: [Pt.zero, Pt(width, 0), Pt(width, height), Pt(0, height)],
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
  final supplyPos = valve.position + const Pt(-100, 0);
  p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
  p.entities.add(WaterSupplyEntity(id: 'tank', position: supplyPos, name: 'Tank', calculatePressure: false, designHeadM: 0, waterLevelOffsetM: 1.5));
  p.entities.add(PumpEntity(id: 'pump', position: supplyPos + const Pt(5, 0), pumpSpecId: pump, name: 'Station', station: station));
  return p;
}

StationDuty dutyOf(DesignResults r) => r.systemFlows.single.stations.single;

void main() {
  group('joined pump curves', () {
    final c1 = PumpCurve.fit([(0, 27), (2 * m3sPerM3h, 25), (4 * m3sPerM3h, 20), (6 * m3sPerM3h, 12)]);
    final c2 = PumpCurve.fit([(0, 37), (3.5 * m3sPerM3h, 34), (7 * m3sPerM3h, 28), (10 * m3sPerM3h, 18)]);

    test('the flow at a head is the inverse of the head at a flow, none above the top', () {
      for (final q in [0.5, 2.0, 4.0, 5.5]) {
        final qq = q * m3sPerM3h;
        expect(c1.flowAt(c1.head(qq)), closeTo(qq, 1e-7));
      }
      expect(c1.flowAt(c1.maxHead + 1), 0);
      expect(c1.flowAt(0), closeTo(c1.runoutFlow, 1e-9));
    });

    test('the same pump n times: n times the flow in parallel, n times the head in series, exactly', () {
      final par = PumpCurve.parallel([c1, c1, c1]);
      final ser = PumpCurve.series([c1, c1]);
      for (final q in [0.0, 1.0, 3.0, 5.0]) {
        final qq = q * m3sPerM3h;
        expect(par.head(3 * qq), closeTo(c1.head(qq), 1e-9));
        expect(ser.head(qq), closeTo(2 * c1.head(qq), 1e-9));
      }
      // the speed of a drive scales the joined curve as each of its pumps
      final w = c1.withSpeed(0.8);
      expect(PumpCurve.parallel([w, w]).head(2 * 3 * m3sPerM3h), closeTo(w.head(3 * m3sPerM3h), 1e-9));
    });

    test('different pumps in parallel add their flows at every head, the smaller one shut above its top', () {
      final par = PumpCurve.parallel([c1, c2]);
      expect(par.maxHead, closeTo(c2.maxHead, 1e-6));
      for (final h in [10.0, 18.0, 24.0]) {
        final q = c1.flowAt(h) + c2.flowAt(h);
        expect(par.head(q), closeTo(h, 0.02 * h), reason: 'at $h m');
      }
      // above the top of the smaller pump only the larger one delivers
      expect(par.flowAt(30), closeTo(c2.flowAt(30), 0.02 * c2.flowAt(30)));
    });

    test('different pumps in series add their heads at every flow', () {
      final ser = PumpCurve.series([c1, c2]);
      for (final q in [1.0, 3.0, 5.0]) {
        final qq = q * m3sPerM3h;
        expect(ser.head(qq), closeTo(c1.head(qq) + c2.head(qq), 0.02 * (c1.head(qq) + c2.head(qq))), reason: 'at $q m³/h');
      }
    });
  });

  group('the station in the project file', () {
    test('a single pump writes nothing new; a station round-trips with its units and keeps unknown fields', () {
      final single = PumpEntity(id: 'p', position: Pt.zero, pumpSpecId: 'pump_c1');
      expect(single.toJson().containsKey('stn'), isFalse);
      final s = PumpEntity(
        id: 'p',
        position: Pt.zero,
        pumpSpecId: 'pump_c1',
        station: PumpStation(
          units: [
            PumpUnit(),
            PumpUnit(specId: 'pump_c2', standby: true),
          ],
          arrangement: PumpArrangement.series,
          staged: false,
        ),
      );
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(j['stn'], {
        'units': [
          <String, dynamic>{},
          {'spec': 'pump_c2', 'sb': true},
        ],
        'arr': 'series',
        'staged': false,
      });
      (j['stn'] as Map)['future'] = 1;
      ((j['stn'] as Map)['units'] as List)[0] = {'later': 'x'};
      final back = Entity.fromJson(j) as PumpEntity;
      expect(back.station!.dutyCount, 2);
      expect(back.station!.standbyCount, 1);
      expect(back.station!.arrangement, PumpArrangement.series);
      expect(back.station!.staged, isFalse);
      expect((back.toJson()['stn'] as Map)['future'], 1);
      expect(((back.toJson()['stn'] as Map)['units'] as List)[0], {'later': 'x'});
      // a copy is independent
      final copy = back.clone();
      copy.station!.units.clear();
      expect(back.station!.units.length, 2);
    });
  });

  group('the design runs the station', () {
    test('two pumps in parallel, staged: the second starts when one cannot give the flow in its range', () {
      final p = stationProject(width: 60, height: 36, station: PumpStation(units: [PumpUnit()]));
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final d = dutyOf(r);
      final spec = p.catalog.pump('pump_c1')!;
      expect(f.totalFlow, greaterThan(spec.maxFlow), reason: 'the zone needs more than one pump gives in its range');
      expect(d.running, 2);
      expect(d.flow, closeTo(f.totalFlow, 1e-6));
      for (final u in d.units) {
        expect(u.running, isTrue);
        expect(u.flow, closeTo(d.flow / 2, 1e-6 * d.flow));
        expect(u.head, closeTo(d.head, 1e-9));
        expect(u.head, closeTo(spec.curve.head(u.flow), 0.01));
        expect(u.powerKw, closeTo(waterDensity * gravity * u.flow * u.head / u.efficiency / 1000, 1e-9));
      }
      // the pump item's own result is the station's
      final dev = f.devices.firstWhere((x) => x.entityId == 'pump');
      expect(dev.flow, closeTo(d.flow, 1e-9));
      expect(dev.pumpHead, closeTo(d.head, 1e-9));
      // the energy sums the pumps, each on its own curve
      expect(f.annualEnergyCost, closeTo(d.powerKw * p.params.hoursPerYear * p.params.powerCostPerKwh, 1e-6 * f.annualEnergyCost));
      expect(f.warnings.where((w) => w.startsWith('pump_out_of_range')), isEmpty);
    });

    test('a small flow starts one pump only; not staged, both run', () {
      final staged = Designer(stationProject(width: 30, height: 18, station: PumpStation(units: [PumpUnit()]))).designAll();
      expect(dutyOf(staged).running, 1);
      expect(dutyOf(staged).units[1].running, isFalse);
      expect(dutyOf(staged).units[1].flow, 0);
      final all = Designer(stationProject(width: 30, height: 18, station: PumpStation(units: [PumpUnit()], staged: false))).designAll();
      expect(dutyOf(all).running, 2);
      expect(dutyOf(all).units[0].flow, closeTo(dutyOf(all).flow / 2, 1e-9));
    });

    test('a standby pump never runs and is in the bill of materials', () {
      final p = stationProject(width: 60, height: 36, station: PumpStation(units: [PumpUnit(), PumpUnit(standby: true)]));
      final r = Designer(p).designAll();
      final d = dutyOf(r);
      expect(d.duty, 2);
      expect(d.standby, 1);
      expect(d.units.last.standby, isTrue);
      expect(d.units.last.running, isFalse);
      final name = p.catalog.pump('pump_c1')!.name;
      expect(r.bom.where((l) => l.category == 'bom.pumps' && l.description == name).single.quantity, 3);
    });

    test('in series every pump carries the flow and the heads add', () {
      final p = stationProject(
        width: 30,
        height: 18,
        station: PumpStation(units: [PumpUnit()], arrangement: PumpArrangement.series, staged: false),
      );
      final r = Designer(p).designAll();
      final d = dutyOf(r);
      final c = p.catalog.pump('pump_c1')!.curve;
      expect(d.running, 2);
      for (final u in d.units) {
        expect(u.flow, closeTo(d.flow, 1e-9));
        expect(u.head, closeTo(d.head / 2, 1e-6));
      }
      expect(d.head, closeTo(2 * c.head(d.flow), 0.01));
    });

    test('the results keep the stations; the report lists every pump', () {
      final p = stationProject(width: 60, height: 36, station: PumpStation(units: [PumpUnit(), PumpUnit(standby: true)]));
      final r = Designer(p).designAll();
      final back = DesignResults.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(back.systemFlows.single.stations.single.toJson()), jsonEncode(dutyOf(r).toJson()));
      final labels = ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w);
      final tb = buildReportTables(project: p, results: r, labels: labels).firstWhere((t) => t.key == 'stations');
      expect(tb.rows.length, 3);
      expect(tb.ids.toSet(), {'pump'});
      // a project without a station has no such table
      final single = Designer(stationProject(width: 30, height: 18)).designAll();
      expect(single.systemFlows.single.stations, isEmpty);
      expect(buildReportTables(project: stationProject(width: 30, height: 18), results: single, labels: labels).where((t) => t.key == 'stations'), isEmpty);
    });
  });
}
