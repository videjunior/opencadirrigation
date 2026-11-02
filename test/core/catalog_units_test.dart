/// The catalogue tables in the units of the project (1.6.0 MOD, MOD-20): the
/// CSV of a project in US units names each column's unit and converts its
/// values; the import reads such columns (and those of price lists in
/// inches, psi, feet and gpm); a metric project writes the CSV as before.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  final cat = Catalog.defaultCatalog();

  test('a metric project writes the CSV as before', () {
    for (final g in CatalogGroup.values) {
      expect(CatalogIo.exportCsv(cat, g, units: Units.metric), CatalogIo.exportCsv(cat, g), reason: g.name);
    }
  });

  test('pipes in inches, psi and price per foot: named, converted and read back', () {
    final csv = CatalogIo.exportCsv(cat, CatalogGroup.pipes, units: Units.us);
    final header = csv.replaceFirst('﻿', '').split('\n').first;
    expect(header, contains('nominal_in'));
    expect(header, contains('id_in'));
    expect(header, contains('rating_psi'));
    expect(header, contains('cost_per_ft'));
    final back = CatalogIo.parseCsv(csv).catalog;
    expect(back.pipes.length, cat.pipes.length);
    for (final p in cat.pipes) {
      final q = back.pipe(p.id)!;
      expect(q.nominalMm, closeTo(p.nominalMm, 1e-6), reason: p.id);
      expect(q.innerDiameterMm, closeTo(p.innerDiameterMm, 1e-6), reason: p.id);
      expect(q.pressureRatingM, closeTo(p.pressureRatingM, 1e-6), reason: p.id);
      expect(q.costPerM, closeTo(p.costPerM, 1e-6), reason: p.id);
      expect(q.name, p.name);
    }
  });

  test('every group survives the trip through US units', () {
    for (final g in CatalogGroup.values) {
      final csv = CatalogIo.exportCsv(cat, g, units: Units.us);
      final back = CatalogIo.parseCsv(csv, group: g).catalog;
      switch (g) {
        case CatalogGroup.tapes:
          for (final t in cat.tapes) {
            final b = back.tape(t.id)!;
            expect(b.emitterSpacingM, closeTo(t.emitterSpacingM, 1e-6), reason: t.id);
            expect(b.minHeadM, closeTo(t.minHeadM, 1e-6), reason: t.id);
            expect(b.costPerM, closeTo(t.costPerM, 1e-6), reason: t.id);
          }
        case CatalogGroup.valves:
          for (final v in cat.valves) {
            expect(back.valve(v.id)!.maxFlow, closeTo(v.maxFlow, 1e-9), reason: v.id);
            expect(back.valve(v.id)!.sizeMm, closeTo(v.sizeMm, 1e-6), reason: v.id);
          }
        case CatalogGroup.pumps:
          for (final p in cat.pumps) {
            final b = back.pump(p.id)!;
            expect(b.points.length, p.points.length, reason: p.id);
            for (var i = 0; i < p.points.length; i++) {
              // the curve of the CSV has two decimals in m³/h and m
              expect(b.points[i].$1, closeTo(p.points[i].$1, 0.006 * m3sPerM3h), reason: '${p.id} Q$i');
              expect(b.points[i].$2, closeTo(p.points[i].$2, 0.006), reason: '${p.id} H$i');
            }
          }
        case CatalogGroup.outlets:
          for (final o in cat.outlets) {
            final n = back.outlet(o.id)!.nozzles.first;
            expect(n.defaultHeadM, closeTo(o.nozzles.first.defaultHeadM, 1e-6), reason: o.id);
          }
        case CatalogGroup.fittings || CatalogGroup.wires || CatalogGroup.pipes:
          expect(back.itemCount, greaterThan(0), reason: g.name);
      }
    }
  });

  test('a price list in inches, psi, feet and gpm', () {
    const pipes = 'name;DN (in);ID (in);PN (psi);Cost (per ft)\nPVC SDR 21 2 in;2;2.149;200;1.5\n';
    final p = CatalogIo.parseCsv(pipes, group: CatalogGroup.pipes).catalog.pipes.single;
    expect(p.nominalMm, closeTo(50.8, 1e-9));
    expect(p.innerDiameterMm, closeTo(2.149 * 25.4, 1e-9));
    expect(p.pressureRatingM, closeTo(200 / psiPerMeterHead, 1e-9));
    expect(p.costPerM, closeTo(1.5 / metersPerFoot, 1e-9));
    const pumps = 'name;points_gpm_ft;kw\nP1;"100@150|200@120|300@80";7.5\n';
    final pump = CatalogIo.parseCsv(pumps).catalog.pumps.single;
    expect(pump.points.first.$1, closeTo(100 * m3sPerGpm, 1e-12));
    expect(pump.points.first.$2, closeTo(150 * metersPerFoot, 1e-9));
    const valves = 'name;kind;dn_in;k;maxQ_gpm\nV2;control;2;5000;80\n';
    final v = CatalogIo.parseCsv(valves).catalog.valves.single;
    expect(v.sizeMm, closeTo(50.8, 1e-9));
    expect(v.maxFlow, closeTo(80 * m3sPerGpm, 1e-12));
    const tapes = 'name;id_in;spacing_ft;q_gph;head_psi\nT;0.62;1;0.24;10\n';
    final t = CatalogIo.parseCsv(tapes).catalog.tapes.single;
    expect(t.innerDiameterMm, closeTo(0.62 * 25.4, 1e-9));
    expect(t.emitterSpacingM, closeTo(metersPerFoot, 1e-9));
    expect(t.defaultInletHeadM, closeTo(10 / psiPerMeterHead, 1e-9));
    expect(t.emitter.flow(t.defaultInletHeadM), closeTo(0.24 * m3sPerGpm / 60, 1e-12));
  });
}
