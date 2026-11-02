import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_check.dart';
import 'package:opencadirrigation/core/units.dart';

/// Physical plausibility of the default catalogue and of the manufacturer
/// packs (MOD-05, MOD-16, MOD-17, MOD-25).
void main() {
  final packs = [
    for (final f in Directory('catalogs').listSync().whereType<File>().where((f) => f.path.endsWith(catalogPackExtension)).toList()..sort((a, b) => a.path.compareTo(b.path)))
      (f.uri.pathSegments.last, CatalogIo.parsePack(f.readAsStringSync())),
  ];

  group('the rules', () {
    test('hoop stress against the PN of ISO 4065: PE 100 SDR 11 is PN 16 at 8 MPa', () {
      // OD 110 mm, wall 10 mm (SDR 11), 16 bar
      final pe = PipeSpec(id: 'x', name: 'x', nominalMm: 110, innerDiameterMm: 90, wallThicknessMm: 10, material: PipeMaterial.pehd, pressureRatingM: 1.6e6 / (waterDensity * gravity));
      expect(pipeHoopStressMpa(pe), closeTo(8.0, 1e-9));
      expect(pipeDesignStressMpa(PipeMaterial.pehd), 8.0);
      expect(pipeDesignStressMpa(PipeMaterial.steel), isNull);
    });

    test('an ideal orifice has a discharge coefficient of 1 (q = A·√(2gH))', () {
      final q = math.pi / 4 * 0.01 * 0.01 * math.sqrt(2 * gravity * 10);
      expect(nozzleDischargeCoefficient(const [10], q, 10), closeTo(1, 1e-12));
      expect(nozzleBoresMm('Nozzle 2.5 mm (0.41 m³/h)'), [2.5]);
      expect(nozzleBoresMm('Bocal 4,0 mm'), [4.0]);
      expect(nozzleBoresMm('3.0 × 1.8 mm red (dual)'), [3.0, 1.8]);
      expect(nozzleBoresMm('Taper bore 0.50" (12.7 mm)'), [12.7]);
      expect(nozzleBoresMm('#3 (0.70 m³/h, R 10 m)'), isEmpty);
    });

    test('motor service factors of NEMA MG 1', () {
      expect(motorServiceFactor(0.75, submersible: true), 1.4);
      expect(motorServiceFactor(1.1, submersible: true), 1.3);
      expect(motorServiceFactor(1.47, submersible: true), 1.25);
      expect(motorServiceFactor(3.7, submersible: true), 1.15);
      expect(motorServiceFactor(0.75), 1.15);
    });

    test('the values the default catalogue had are caught', () {
      // "PVC DN 100 PN 80" with the bore and wall of a PN 40-60 pipe
      final thin = PipeSpec(id: 'pvc100', name: 'PVC DN 100 PN 80', nominalMm: 100, innerDiameterMm: 96, wallThicknessMm: 2.5, pressureRatingM: 80);
      final cat = Catalog(pipes: [thin]);
      expect(catalogPlausibility(cat).single, startsWith('pipe_wall:pvc100'));
      // 2.5 mm nozzle rated at 0.46 m³/h @ 30 m (Cd 1.07)
      final noz = NozzleSpec(
        id: 'i2.5',
        name: 'Nozzle 2.5 mm',
        curve: EmitterCurve.fromNominal(flow: 460 * m3sPerLph, head: 30, x: 0.5),
        defaultHeadM: 30,
      );
      final o = OutletSpec(id: 'imp', name: 'impact', kind: OutletKind.sprinkler, nozzles: [noz]);
      expect(catalogPlausibility(Catalog(outlets: [o])).single, startsWith('nozzle_cd:imp/i2.5'));
      // 120 m³/h @ 55 m on a 22 kW (30 cv) motor
      final big = PumpSpec(id: 'pump_big', name: 'x', points: [(0, 70), (60 * m3sPerM3h, 64), (120 * m3sPerM3h, 55), (180 * m3sPerM3h, 38)], efficiency: 0.72, powerKw: 22);
      expect(pumpCurveShaftKw(big), greaterThan(25));
      // a 1 cv pump with the curve of a 3 cv one
      final sub = PumpSpec(id: 's', name: 's', points: [(0, 150), (5 * m3sPerM3h, 100), (8 * m3sPerM3h, 60)], efficiency: 0.6, powerKw: 0.74, submersible: true);
      expect(catalogPlausibility(Catalog(pumps: [sub])).single, startsWith('pump_power:s'));
    });
  });

  group('default catalogue', () {
    final c = Catalog.defaultCatalog();

    test('passes every plausibility rule', () {
      expect(catalogPlausibility(c), isEmpty);
    });

    test('PVC PN 80 has the bores and walls of NBR 14312 (as the manufacturer packs)', () {
      final ref = packs.firstWhere((p) => p.$1 == 'multilit.oci.cat').$2.catalog;
      for (final dn in [35, 50, 75, 100, 125, 150]) {
        final mine = c.pipe('pvc$dn')!, theirs = ref.pipe('mlt_irr_pn80_dn$dn')!;
        expect(mine.pressureRatingM, 80);
        expect(mine.innerDiameterMm, theirs.innerDiameterMm, reason: 'DN $dn');
        expect(mine.wallThicknessMm, theirs.wallThicknessMm, reason: 'DN $dn');
      }
      // above DN 150: ISO 1452-2 S 12.5 (PN 8), OD 200 and 250
      for (final (id, od, e) in [('pvc200', 200.0, 7.7), ('pvc250', 250.0, 9.6)]) {
        final p = c.pipe(id)!;
        expect(p.wallThicknessMm, e);
        expect(p.innerDiameterMm + 2 * p.wallThicknessMm, closeTo(od, 1e-9));
      }
    });

    test('PE PN 6 has the walls of PE 80 SDR 21 (2 mm least)', () {
      for (final (id, od) in [('pe25', 25.0), ('pe32', 32.0), ('pe40', 40.0), ('pe50', 50.0)]) {
        final p = c.pipe(id)!;
        expect(p.pressureRatingM, 60);
        expect(p.innerDiameterMm + 2 * p.wallThicknessMm, closeTo(od, 1e-9), reason: id);
        expect(p.wallThicknessMm == 2.0 || od / p.wallThicknessMm >= 20.5, isTrue, reason: '$id: SDR ${od / p.wallThicknessMm}');
      }
    });

    test('impact sprinkler nozzles pass what a round nozzle can (Cd 0.9 to 1)', () {
      final o = c.outlet('impact34')!;
      for (final n in o.nozzles) {
        final cd = nozzleDischargeCoefficient(nozzleBoresMm(n.name), n.curve.flow(n.defaultHeadM), n.defaultHeadM);
        expect(cd, inInclusiveRange(0.9, 1.0), reason: n.id);
        // the name gives the flow at the default head
        final m3h = double.parse(RegExp(r'\((\d+[.,]\d+) m³/h').firstMatch(n.name)!.group(1)!.replaceAll(',', '.'));
        expect(n.curve.flow(n.defaultHeadM) * 3600, closeTo(m3h, 0.006), reason: n.id);
      }
    });

    test('the shaft power along every pump curve stays within its motor', () {
      for (final p in c.pumps) {
        // (1 % for the rounding of the curve points)
        expect(pumpCurveShaftKw(p), lessThanOrEqualTo(p.powerKw * 1.01), reason: p.id);
      }
    });
  });

  test('manufacturer packs pass every plausibility rule', () {
    for (final (name, pack) in packs) {
      expect(catalogPlausibility(pack.catalog), isEmpty, reason: name);
    }
  });
}
