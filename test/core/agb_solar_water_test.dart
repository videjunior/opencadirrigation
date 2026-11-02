import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/agb_design.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/solar_design.dart';
import 'package:opencadirrigation/core/design/water_quality.dart';
import 'package:opencadirrigation/core/model/agb_settings.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// PRD-19 (solar pumping in the design, the report, the bill and the
/// energy cost), PRD-22 (water quality, filtration and treatment) and
/// PRD-31 (two-wire in the bill of materials).
void main() {
  final t = I18n('pt');
  ReportLabels labels() => ReportLabels(t: t.call, has: t.has, warning: t.warning);

  group('solar', () {
    test('the Fio B of Lei 14.300/2022 art. 27 by the year billed', () {
      expect(fioBSharePaid(2022), 0);
      expect(fioBSharePaid(2023), closeTo(0.15, 1e-12));
      expect(fioBSharePaid(2026), closeTo(0.60, 1e-12));
      expect(fioBSharePaid(2028), closeTo(0.90, 1e-12));
      expect(fioBSharePaid(2029), 1);
      expect(fioBSharePaid(2030, grandfathered: true), 0);
    });

    test('grid-tied: the array of the yearly pumping energy, the bill compensated', () {
      final p = buildExample(ExampleId.pivot, t.call, lang: 'pt');
      final grid = Designer(p, label: t.call).designAll();
      p.agb.solar.mode = SolarMode.gridTied;
      final r = Designer(p, label: t.call).designAll();
      final s = r.agb!.solar!;
      expect(s.modules, greaterThan(0));
      expect(s.arrayKWp, closeTo(s.modules * s.moduleWp / 1000, 1e-9));
      // as much generated as the pumping uses (one module more at most)
      expect(s.generationKWh, greaterThanOrEqualTo(s.consumptionKWh - 1e-6));
      expect(s.generationKWh - s.yieldKWhPerKWp * s.moduleWp / 1000, lessThan(s.consumptionKWh));
      expect(s.consumptionKWh, closeTo(grid.annualEnergyCost / p.params.powerCostPerKwh, 1e-6));
      // nothing used as generated: every credit pays the Fio B of 2026
      expect(s.fioBPaidPct, closeTo(60, 1e-9));
      expect(s.netCost, closeTo(s.compensatedKWh * (s.gridCost / s.consumptionKWh) * 0.28 * 0.6 + (s.consumptionKWh - s.compensatedKWh) * s.gridCost / s.consumptionKWh, 1e-6));
      expect(r.annualEnergyCost, closeTo(s.netCost, 1e-9), reason: 'the design energy cost carries the compensation');
      expect(r.annualEnergyCost, lessThan(grid.annualEnergyCost));
      expect(s.gridCost, closeTo(grid.annualEnergyCost, 1e-6));
      final lines = [
        for (final l in r.bom)
          if (l.category == 'bom.solar') l,
      ];
      expect(lines.where((l) => l.description.startsWith(t('agb.bom.module'))).single.quantity, s.modules);
      expect(lines.where((l) => l.description.startsWith(t('agb.bom.inverter'))), hasLength(1));
      final tables = buildReportTables(project: p, results: r, labels: labels());
      expect(tables.where((x) => x.key == 'solar'), hasLength(1));
      expect(tables.where((x) => x.key == 'solarMonths').single.rows, hasLength(12));
    });

    test('off-grid: no energy bought, the array large enough for the motor', () {
      final p = buildExample(ExampleId.pivot, t.call, lang: 'pt');
      p.agb.solar.mode = SolarMode.offGrid;
      final r = Designer(p, label: t.call).designAll();
      final s = r.agb!.solar!;
      expect(r.annualEnergyCost, 0);
      expect(s.netCost, 0);
      expect(s.criticalMonth, isNotNull);
      expect(s.inverterKw, greaterThan(0));
      // the array gives the motor its input at full sun (IEC 62253)
      expect(s.arrayKWp * (1 - 0.03) * (1 - 0.02) * (1 - 0.02) * 0.95, greaterThanOrEqualTo(s.inverterKw * 0.99));
      expect(
        [
          for (final l in r.bom)
            if (l.category == 'bom.solar') l.description,
        ].any((d) => d.startsWith(t('agb.bom.pumpDrive'))),
        isTrue,
      );
      final back = AgbResults.fromJson(jsonDecode(jsonEncode(r.agb!.toJson())) as Map<String, dynamic>);
      expect(back.solar!.modules, s.modules);
      expect(back.solar!.months.length, 12);
    });
  });

  group('water quality', () {
    test('the clogging classes of Nakayama (1982)', () {
      expect(clogRiskOf('tss', 49), ClogRisk.low);
      expect(clogRiskOf('tss', 50), ClogRisk.moderate);
      expect(clogRiskOf('tss', 100), ClogRisk.moderate);
      expect(clogRiskOf('tss', 101), ClogRisk.severe);
      expect(clogRiskOf('ph', 6.9), ClogRisk.low);
      expect(clogRiskOf('ph', 8.1), ClogRisk.severe);
      expect(clogRiskOf('fe', 0.8), ClogRisk.moderate);
      expect(clogRiskOf('h2s', 2.5), ClogRisk.severe);
      expect(clogRiskOf('bact', 20000), ClogRisk.moderate);
    });

    test('Langelier index, acid of a closed carbonate system, sieves and media rates', () {
      // TDS 576 mg/L (EC 0.9 dS/m), Ca 80, HCO3 250 mg/L, 25 °C: pHs 7.35
      expect(langelierIndex(ph: 7.9, tdsMgL: 576, calciumMgL: 80, bicarbonateMgL: 250), closeTo(0.548, 0.002));
      expect(langelierIndex(ph: 7.9, tdsMgL: 576, calciumMgL: null, bicarbonateMgL: 250), isNull);
      expect(acidToLowerPh(250 / 61.02, 7.9, 6.5), closeTo(1.632, 0.002));
      expect(acidToLowerPh(4, 6.0, 6.5), 0);
      expect(acidMlPerM3(AcidProduct.sulfuric, 1), closeTo(27.2, 0.05));
      expect(acidMlPerM3(AcidProduct.hydrochloric, 1), closeTo(95.2, 0.1));
      expect(meshFor(114), (140, 106.0));
      expect(meshFor(130), (120, 125.0));
      expect(meshFor(20), (200, 75.0));
      expect(mediaFluxM3hM2(150), closeTo(15 * 2.4448, 1e-9));
      expect(mediaFluxM3hM2(5), closeTo(25 * 2.4448, 1e-9));
      expect(mediaFluxM3hM2(null), closeTo(20 * 2.4448, 1e-9));
    });

    test('an analysis on a designed orchard: hazards, filters, chlorine and acid in the report and the bill', () {
      final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
      expect(designWaterQuality(p, null), isNull, reason: 'no analysis, nothing to say');
      p.agb.water
        ..source = WaterSource.reservoir
        ..ph = 7.9
        ..ecDsM = 0.9
        ..tssMgL = 70
        ..ironMgL = 0.8
        ..manganeseMgL = 0.05
        ..calciumMgL = 80
        ..bicarbonateMgL = 250;
      final r = Designer(p, label: t.call).designAll();
      final w = r.agb!.water!;
      expect(w.overall, ClogRisk.moderate);
      expect(w.tdsMgL, closeTo(576, 1e-9));
      expect(w.lsi, closeTo(0.548, 0.002));
      expect(w.warnings, contains('water_scaling'));
      expect(w.media, isTrue, reason: 'reservoir water with suspended solids');
      expect(w.mediaTanks, greaterThanOrEqualTo(2));
      expect(w.mesh, greaterThanOrEqualTo(120));
      expect(w.chlorination, ChlorinationMode.continuous);
      expect(w.chlorineDemandMgL, closeTo(0.64 * 0.8 + 1.3 * 0.05, 1e-9));
      expect(w.chlorineDoseMgL, closeTo(w.chlorineDemandMgL + 1, 1e-9));
      expect(w.hypochloriteLph, closeTo(w.designFlowM3h * w.chlorineDoseMgL / 100, 1e-9));
      expect(w.acidTargetPh, 6.5);
      expect(w.acidMlM3, closeTo(acidMlPerM3(AcidProduct.sulfuric, w.acidMeqL), 1e-9));
      expect(w.drawnFilters, greaterThan(0), reason: 'the orchard has its filter drawn');
      final water = [
        for (final l in r.bom)
          if (l.category == 'bom.water') l.description,
      ];
      expect(water.where((d) => d.startsWith(t('agb.bom.injector'))), hasLength(2), reason: 'chlorine and acid');
      expect(water.where((d) => d.startsWith(t('agb.bom.media'))), isEmpty, reason: 'filters drawn: the station is the designer\'s');
      final tables = buildReportTables(project: p, results: r, labels: labels());
      expect(tables.where((x) => x.key == 'waterQuality').single.rows.length, greaterThanOrEqualTo(6));
      expect(tables.where((x) => x.key == 'waterTreatment'), hasLength(1));
      expect(tables.where((x) => x.key == 'water').every((x) => x.title != t('agb.rep.water')), isTrue, reason: 'the water requirement table keeps its key');
    });
  });

  test('two-wire: decoders, the pair and the surge protection replace the station wires in the bill', () {
    final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
    final before = Designer(p, label: t.call).designAll();
    final wire = p.catalog.wire(before.electrical!.wireMeters.keys.first)!;
    expect(before.bom.any((l) => l.description == wire.name), isTrue, reason: 'the station wire of the conventional wiring');
    p.agb.twoWire
      ..enabled = true
      ..decoderPrices[1] = 100
      ..arresterPrice = 50;
    final r = Designer(p, label: t.call).designAll();
    final tw = r.agb!.twoWire!;
    expect(tw.decoders, isNotEmpty);
    expect(r.bom.any((l) => l.description == wire.name), isFalse, reason: 'no station wires any more');
    final decoders = r.bom.where((l) => l.description.startsWith(t('agb.bom.decoder'))).toList();
    expect(decoders.fold(0.0, (s, l) => s + l.quantity), tw.decoders.length);
    expect(r.bom.where((l) => l.description.startsWith(t('agb.bom.pair'))), isNotEmpty);
    final arresters = r.bom.where((l) => l.description == t('agb.bom.arrester')).single;
    expect(arresters.quantity, tw.grounds.length);
    expect(arresters.unitCost, 50);
    expect(r.bom.any((l) => l.description.startsWith(t('tool.controller'))), isTrue, reason: 'the controller stays');
    final tables = buildReportTables(project: p, results: r, labels: labels());
    expect(tables.where((x) => x.key == 'twoWire').single.rows, hasLength(tw.paths.length));
    // the setting goes with the file and leaves the others alone
    final back = Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.agb.twoWire.enabled, isTrue);
    expect(back.agb.twoWire.decoderPrices[1], 100);
    expect(back.agb.pumpHouse.isDefault, isTrue);
    expect(twoWireOn(back), isTrue);
    expect(p.entities.whereType<ControllerEntity>(), isNotEmpty);
  });
}
