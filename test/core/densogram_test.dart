import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Integral of the map (m³/s): Σ rate · cell area.
double _volume(Densogram d) {
  var s = 0.0;
  for (final v in d.rate) {
    s += v / 1000 / 3600 * d.cell * d.cell;
  }
  return s;
}

OutletEntity _rotor(Project p, Pt at, {double arc = 360, double rot = 0, String nozzle = 'r3'}) =>
    OutletEntity(id: p.newId(), position: at, outletSpecId: 'rotor', nozzleId: nozzle, headM: 25, arcDeg: arc, orientationDeg: rot);

/// Square grid of rotors (R 10 m at 25 m) with spacing [s].
Project _grid(double s, {int n = 5, bool area = false}) {
  final p = Project();
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      p.entities.add(_rotor(p, Pt(i * s, j * s)));
    }
  }
  if (area) p.entities.add(AreaEntity(id: p.newId(), points: [Pt(s, s), Pt(3 * s, s), Pt(3 * s, 3 * s), Pt(s, 3 * s)]));
  return p;
}

void main() {
  group('spray source', () {
    test('every profile spreads the whole flow over the wetted circle', () {
      for (final profile in SprayProfile.values) {
        final p = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25));
        final d = computeDensogram(p, options: DensogramOptions(cellSize: 0.1, profile: profile));
        final q = d.sources.single.flow;
        expect(q, closeTo(700 * m3sPerLph, 1e-9));
        expect(_volume(d), closeTo(q, q * 0.01), reason: profile.name);
      }
    });

    test('a half circle waters only its sector, twice as hard', () {
      final full = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25));
      final half = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, arcDeg: 180, orientationDeg: 90));
      final opts = DensogramOptions(cellSize: 0.25);
      final df = computeDensogram(full, options: opts), dh = computeDensogram(half, options: opts);
      // orientation 90° sweeps 90°→270°: the west half
      expect(dh.rateAt(const Pt(-4, 0.1)), greaterThan(0));
      expect(dh.rateAt(const Pt(4, 0.1)), 0);
      expect(dh.rateAt(const Pt(-4, 0.1)), closeTo(2 * df.rateAt(const Pt(-4, 0.1)), 0.02 * df.rateAt(const Pt(-4, 0.1))));
      expect(_volume(dh), closeTo(dh.sources.single.flow, dh.sources.single.flow * 0.02));
    });

    test('a part-circle nozzle on a full-circle head keeps its own arc', () {
      final p = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3_90', headM: 25));
      final s = spraySources(p).single;
      expect(s.sweepRad, closeTo(math.pi / 2, 1e-9));
      expect(s.covers(math.pi / 4), isTrue);
      expect(s.covers(math.pi), isFalse);
    });

    test('rate profiles fall to zero at the wetted radius', () {
      const s = SpraySource(entityId: 'x', p: Pt.zero, flow: 1e-3, radius: 10);
      expect(s.rateAt(10, SprayProfile.triangular), 0);
      expect(s.rateAt(0, SprayProfile.triangular), closeTo(1e-3 / (100 * 2 * math.pi / 6), 1e-15));
      expect(s.rateAt(5, SprayProfile.uniform), closeTo(s.rateAt(9.9, SprayProfile.uniform), 1e-15));
      expect(s.rateAt(5, SprayProfile.elliptical), lessThan(s.rateAt(0, SprayProfile.elliptical)));
    });
  });

  group('uniformity', () {
    test('head-to-head spacing is uniform, wide spacing is not', () {
      final close = computeDensogram(_grid(10), options: DensogramOptions(cellSize: 0.5));
      final wide = computeDensogram(_grid(16), options: DensogramOptions(cellSize: 0.5));
      // interior of the grid (the edge heads only get half the overlap)
      double cuInside(Densogram d, double s) {
        final values = <double>[];
        for (var j = 0; j < d.ny; j++) {
          for (var i = 0; i < d.nx; i++) {
            final c = d.cellCenter(i, j);
            if (c.x > s && c.x < 3 * s && c.y > s && c.y < 3 * s) values.add(d.rate[j * d.nx + i]);
          }
        }
        return densogramStats(values, d.cell * d.cell).cu;
      }

      expect(cuInside(close, 10), greaterThan(85));
      expect(cuInside(wide, 16), lessThan(cuInside(close, 10) - 10));
    });

    test('an irrigated area around the sprinklers is the target', () {
      final d = computeDensogram(_grid(10, area: true), options: DensogramOptions(cellSize: 0.5));
      expect(d.masked, isTrue);
      expect(d.stats.areaM2, closeTo(20 * 20, 20));
      expect(d.stats.cu, greaterThan(85));
      // mean rate: 4 heads' worth of water on each 10 × 10 m square
      expect(d.stats.mean, closeTo(700 / 1000 / 100 * 1000, 1.5));
    });

    test('areas of different rates are judged and coloured against their own mean', () {
      // sprays (fast) on one lawn, rotors (slow) on the other
      final p = Project();
      for (final (x, y) in [(0.0, 0.0), (4.0, 0.0), (0.0, 4.0), (4.0, 4.0)]) {
        p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20));
      }
      for (final (x, y) in [(30.0, 0.0), (40.0, 0.0), (30.0, 10.0), (40.0, 10.0)]) {
        p.entities.add(OutletEntity(id: p.newId(), position: Pt(x, y), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25));
      }
      p.entities.add(AreaEntity(id: 'a1', name: 'Sprays', points: [Pt.zero, const Pt(4, 0), const Pt(4, 4), const Pt(0, 4)]));
      p.entities.add(AreaEntity(id: 'a2', name: 'Rotors', points: [const Pt(30, 0), const Pt(40, 0), const Pt(40, 10), const Pt(30, 10)]));
      final d = computeDensogram(p, options: DensogramOptions(cellSize: 0.25));
      expect(d.areas.map((a) => a.name), ['Sprays', 'Rotors']);
      final sprays = d.areas[0].stats, rotors = d.areas[1].stats;
      expect(sprays.mean, greaterThan(2 * rotors.mean));
      // each lawn is fairly uniform, the mix is not
      expect(sprays.cu, greaterThan(d.stats.cu));
      expect(rotors.cu, greaterThan(d.stats.cu));
      // a cell in the middle of each lawn is compared with its own mean
      int cellAt(Pt w) => ((w.y - d.origin.y) / d.cell).floor() * d.nx + ((w.x - d.origin.x) / d.cell).floor();
      expect(d.meanAt(cellAt(const Pt(2, 2))), sprays.mean);
      expect(d.meanAt(cellAt(const Pt(35, 5))), rotors.mean);
      expect(d.areaOf[cellAt(const Pt(20, 5))], -1);
    });

    test('without areas the wetted cells are evaluated', () {
      final d = computeDensogram(_grid(10), options: DensogramOptions(cellSize: 1));
      expect(d.masked, isFalse);
      expect(d.inside.where((v) => v == 1).length, d.rate.where((v) => v > 0).length);
    });

    test('statistics of known values', () {
      final even = densogramStats([4, 4, 4, 4], 1);
      expect(even.cu, closeTo(100, 1e-9));
      expect(even.du, closeTo(100, 1e-9));
      expect(even.sc, closeTo(1, 1e-9));
      expect(even.dryPct, 0);
      final uneven = densogramStats([0, 2, 4, 6], 2);
      expect(uneven.mean, 3);
      expect(uneven.cu, closeTo(100 * (1 - 2 / 3), 1e-9));
      expect(uneven.du, 0);
      expect(uneven.sc, double.infinity);
      expect(uneven.dryPct, 25);
      expect(uneven.areaM2, 8);
      expect(densogramStats(const [], 1).cells, 0);
    });

    test('the grid respects the cell budget', () {
      final d = computeDensogram(_grid(10, n: 12), options: DensogramOptions(cellSize: 0.05, maxCells: 5000));
      expect(d.nx * d.ny, lessThanOrEqualTo(5000));
      expect(d.cell, greaterThan(0.05));
    });
  });

  group('sources', () {
    test('lateral outlets become sources; part circles open to the left', () {
      final p = Project();
      p.entities.add(SpraylineEntity(id: 'sl', points: const [Pt(0, 0), Pt(40, 0)], outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, spacing: 10, arcDeg: 180));
      final src = spraySources(p);
      expect(src.length, 4);
      expect(src.first.p.x, closeTo(10, 1e-9));
      // left of an eastbound lateral is north: the sector is centred on +y
      expect(src.first.covers(math.pi / 2), isTrue);
      expect(src.first.covers(-math.pi / 2), isFalse);
    });

    test('drippers and tapes have no wetted radius and are ignored', () {
      final p = Project();
      p.entities.add(OutletEntity(id: 'd', position: Pt.zero, outletSpecId: 'drip_turb', nozzleId: 't4', headM: 10));
      p.entities.add(TapeEntity(id: 't', points: const [Pt(0, 0), Pt(10, 0)], tapeSpecId: 'drip16_16_50'));
      final d = computeDensogram(p);
      expect(d.isEmpty, isTrue);
      expect(d.stats.cells, 0);
    });

    test('design results give every emitter its own pressure', () {
      final p = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25));
      final r = DesignResults(timestamp: DateTime(2026));
      final nominal = spraySources(p).single;
      r.zones['v'] = ZoneResult(
        valveId: 'v', zoneName: 'Z', converged: true, totalFlow: 0, downstreamHead: 0, valveLoss: 0, requiredUpstreamHead: 0, minOutletPressure: 36, maxOutletPressure: 36,
        allowedMin: 0, allowedMax: 99, nominalPressure: 25, uniformity: UniformityStats.empty, pipes: const [], devices: const [], warnings: const [], valveElevation: 0,
        outlets: [OutletResult(entityId: 'o', index: -1, p: Pt.zero, elevation: 0, pressure: 36, flow: nominal.flow * 1.2, nominalFlow: nominal.flow, count: 1, allowedMin: 0, allowedMax: 99, label: '')],
      );
      final withRes = spraySources(p, results: r).single;
      expect(withRes.flow, closeTo(nominal.flow * 1.2, 1e-12));
      expect(withRes.radius, greaterThan(nominal.radius));
      expect(computeDensogram(p, results: r).fromResults, isTrue);
      expect(computeDensogram(p, results: r, options: DensogramOptions(useResults: false)).fromResults, isFalse);
    });

    test('a zone filter keeps the sprinklers downstream of the chosen valve', () {
      final p = Project();
      for (final (name, y) in [('A', 0.0), ('B', 50.0)]) {
        final v = ControlValveEntity(id: 'v$name', position: Pt(0, y), zoneName: name);
        p.entities.add(v);
        p.entities.add(PipeEntity(id: 'p$name', points: [Pt(0, y), Pt(20, y)], scope: HydraulicScope.zone));
        p.entities.add(OutletEntity(id: 'o$name', position: Pt(20, y), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25));
      }
      expect(spraySources(p).length, 2);
      final only = spraySources(p, valveIds: {'vB'});
      expect(only.map((s) => s.entityId), ['oB']);
    });

    test('a designed garden gives a densogram from the design', () {
      final p = Project();
      final v = ControlValveEntity(id: 'v', position: const Pt(-5, 0), zoneName: 'Z', valveSpecId: 'ev40');
      p.entities.addAll([
        WaterSupplyEntity(id: 'ws', position: const Pt(-20, 0), calculatePressure: false, designHeadM: 45, maxHeadM: 60, designFlow: 10 * m3sPerM3h, maxFlow: 12 * m3sPerM3h),
        PipeEntity(id: 'mp', points: const [Pt(-20, 0), Pt(-5, 0)], scope: HydraulicScope.mainline),
        v,
        PipeEntity(id: 'zp', points: const [Pt(-5, 0), Pt(0, 0), Pt(20, 0)], scope: HydraulicScope.zone),
        _rotor(p, Pt.zero),
        _rotor(p, const Pt(10, 0)),
        _rotor(p, const Pt(20, 0)),
      ]);
      final r = Designer(p).designAll();
      final d = computeDensogram(p, results: r);
      expect(d.fromResults, isTrue);
      expect(d.sources.length, 3);
      expect(d.stats.mean, greaterThan(0));
    });
  });

  group('drawing', () {
    test('colours run from dry red through green to purple', () {
      expect(densogramColor(0, 10), densogramStops.first.$2);
      expect(densogramColor(10, 10), 0xFF66BB6A);
      expect(densogramColor(50, 10), densogramStops.last.$2);
      expect(densogramColor(5, 0), densogramStops.first.$2);
      // halfway between two stops
      final mid = densogramColor(9, 10);
      expect(mid, isNot(0xFF66BB6A));
      expect((mid >> 24) & 0xFF, 0xFF);
    });

    test('pixels: one per cell, top row first, dry cells transparent', () {
      final p = Project()..entities.add(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, arcDeg: 90, orientationDeg: 0));
      final d = computeDensogram(p, options: DensogramOptions(cellSize: 1));
      final px = densogramPixels(d);
      expect(px.length, d.nx * d.ny * 4);
      int alphaAt(Pt w) {
        final i = ((w.x - d.origin.x) / d.cell).floor(), j = ((w.y - d.origin.y) / d.cell).floor();
        return px[((d.ny - 1 - j) * d.nx + i) * 4 + 3];
      }

      // the head waters its north-east quarter only
      expect(alphaAt(const Pt(3, 3)), greaterThan(0));
      expect(alphaAt(const Pt(-3, -3)), 0);
      expect(alphaAt(const Pt(3, -3)), 0);
    });

    test('CSV lists the wetted cells', () {
      final d = computeDensogram(_grid(10, n: 2), options: DensogramOptions(cellSize: 2));
      final lines = d.toCsv().trim().split('\n');
      expect(lines.first, 'x;y;mm_h;target');
      expect(lines.length - 1, d.rate.where((v) => v > 0).length);
      expect(sprayProfileKey(SprayProfile.uniform), 'dens.profile.uniform');
    });
  });
}
