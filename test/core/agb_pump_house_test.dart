import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/agb_design.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/pump_house.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/agb_settings.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// PRD-13: the pump house electrics (motor, starter, feeder by NBR 5410,
/// transformer, short circuit, tariff group) and the pivots' supply, in the
/// design, the report and the bill of materials; the settings in the file.
void main() {
  final t = I18n('pt');

  group('NBR 5410 tables and motor data', () {
    test('ampacity of Tabelas 36 to 39 (copper, three loaded conductors)', () {
      expect(cableAmpacity(2.5, CableInsulation.pvc, CableMethod.b1), 21);
      expect(cableAmpacity(240, CableInsulation.pvc, CableMethod.b1), 370);
      expect(cableAmpacity(16, CableInsulation.pvc, CableMethod.d), 67);
      expect(cableAmpacity(50, CableInsulation.pvc, CableMethod.e), 153);
      expect(cableAmpacity(240, CableInsulation.xlpe, CableMethod.b1), 481);
      expect(cableAmpacity(35, CableInsulation.xlpe, CableMethod.e), 158);
      expect(cableAmpacity(7, CableInsulation.pvc, CableMethod.c), 0, reason: 'no such section');
    });

    test('temperature factors of Tabela 40, protective conductor of Tabela 58', () {
      expect(cableTemperatureFactor(CableInsulation.pvc, CableMethod.b1, null), 1);
      expect(cableTemperatureFactor(CableInsulation.pvc, CableMethod.b1, 40), closeTo(0.87, 1e-12));
      expect(cableTemperatureFactor(CableInsulation.xlpe, CableMethod.d, 30), closeTo(0.93, 1e-12));
      expect(cableTemperatureFactor(CableInsulation.pvc, CableMethod.c, 32.5), closeTo(0.97, 1e-12));
      expect(protectiveConductorMm2(10), 10);
      expect(protectiveConductorMm2(25), 16);
      expect(protectiveConductorMm2(95), 50);
      expect(cableResistanceHot(10, CableInsulation.pvc), closeTo(1.83 * (1 + 0.00393 * 50), 1e-12));
    });

    test('IE3 efficiency, starting methods and the transformer series', () {
      expect(ie3Efficiency(7.5), closeTo(0.917, 1e-12));
      expect(ie3Efficiency(75, hz: 50), closeTo(0.950, 1e-12));
      expect(recommendedStarter(kw: 4, directMaxKw: 5.5), StarterKind.direct);
      expect(recommendedStarter(kw: 30, directMaxKw: 5.5), StarterKind.starDelta);
      expect(recommendedStarter(kw: 30, directMaxKw: 5.5, submersible: true), StarterKind.softStarter);
      expect(recommendedStarter(kw: 90, directMaxKw: 5.5), StarterKind.softStarter);
      expect(recommendedStarter(kw: 2, directMaxKw: 5.5, speedControlled: true), StarterKind.vfd);
      expect(startingMultipleOf(StarterKind.starDelta, lockedRotor: 7.5), closeTo(2.5, 1e-12));
      expect(gentlerStarter(StarterKind.direct, submersible: true), StarterKind.softStarter);
      expect(gentlerStarter(StarterKind.vfd), isNull);
      expect(standardTransformerKva.take(8), [15, 30, 45, 75, 112.5, 150, 225, 300]);
      expect(transformerLoadLossPct(75), closeTo(100 * 1100 / 75000, 1e-9));
    });
  });

  test('a 75 kW pump 200 m away: star-delta, 95 mm² by the current, 150 kVA by the start', () {
    final p = Project();
    p.catalog.pumps.add(PumpSpec(id: 'p75', name: 'P75', points: [(0, 80), (100 * m3sPerM3h, 60), (200 * m3sPerM3h, 30)], efficiency: 0.75, powerKw: 75));
    p.entities.add(PumpEntity(id: 'e1', position: Pt.zero, pumpSpecId: 'p75'));
    p.agb.pumpHouse
      ..enabled = true
      ..pumps['e1'] = PumpFeeder(lengthM: 200);
    final r = designPumpHouse(p, null);
    final c = r.circuits.single;
    // I = 75 kW / (√3 · 380 V · 0.954 · 0.87)
    expect(c.currentA, closeTo(137.3, 0.1));
    expect(c.designCurrentA, closeTo(c.currentA * 1.15, 1e-9));
    expect(c.starter, StarterKind.starDelta);
    expect(c.startCurrentA, closeTo(c.currentA * 7 / 3, 1e-9));
    // 70 mm² carries 151 A buried (Tabela 36, D): below the 158 A of the design current
    expect(c.sectionMm2, 95);
    expect(c.peMm2, 50);
    expect(c.ampacityA, greaterThanOrEqualTo(c.designCurrentA));
    expect(c.runningDropPct, closeTo(3.01, 0.01));
    expect(c.runningLimitPct, 7.5, reason: '7 % plus 0.005 %/m beyond 100 m (NBR 5410 6.2.7.1)');
    expect(c.startingDropPct, lessThanOrEqualTo(10));
    expect(c.warnings, isEmpty);
    // 112.5 kVA carries the load but lets the start dip more than 10 %
    expect(r.sourceKvaRequired, closeTo(75 / (0.954 * 0.87), 0.01));
    expect(r.sourceKva, 150);
    expect(r.ukPct, 3.5);
    expect(r.ik3SourceKa, closeTo(6.84, 0.02));
    expect(r.tariffGroup, 'B');
    expect(r.warnings, isEmpty);
  });

  test('a diesel pump stays out; a pump without power is reported', () {
    final p = Project();
    // pumps without a catalogue pump: no power to size a motor for
    p.entities.addAll([PumpEntity(id: 'e1', position: Pt.zero), PumpEntity(id: 'e2', position: const Pt(5, 0))]);
    p.agb.pumpHouse
      ..enabled = true
      ..pumps['e2'] = PumpFeeder(electric: false);
    final r = designPumpHouse(p, null);
    expect(r.circuits, isEmpty);
    expect(r.warnings, contains('agb_pump_no_power:e1'));
    expect(r.warnings.where((w) => w.endsWith(':e2')), isEmpty);
  });

  test('the gallery pivot: off by default; on, the circuits enter the design, the report and the bill', () {
    final p = buildExample(ExampleId.pivot, t.call, lang: 'pt');
    final before = Designer(p, label: t.call).designAll();
    expect(before.agb, isNull, reason: 'nothing of the area runs unless asked');
    expect(p.toJson().containsKey('agb'), isFalse);
    p.agb.pumpHouse.enabled = true;
    final r = Designer(p, label: t.call).designAll();
    final ph = r.agb!.pumpHouse!;
    expect(ph.circuits, isNotEmpty);
    for (final c in ph.circuits) {
      expect(c.ampacityA, greaterThanOrEqualTo(c.designCurrentA - 1e-9));
      expect(c.runningDropPct, lessThanOrEqualTo(c.runningLimitPct + 1e-9));
      expect(c.startingDropPct, lessThanOrEqualTo(10 + 1e-9));
      expect(powerCableSections, contains(c.sectionMm2));
    }
    expect(ph.sourceKva, greaterThanOrEqualTo(ph.sourceKvaRequired - 1e-9));
    expect(standardTransformerKva, contains(ph.sourceKva));
    // the bill: feeder, protective conductor, panel and transformer
    final elec = [for (final l in r.bom) if (l.category == 'bom.electrical') l.description];
    expect(elec.where((d) => d.startsWith(t('agb.bom.feeder'))), hasLength(ph.circuits.length));
    expect(elec.where((d) => d.startsWith(t('agb.bom.panel'))), hasLength(ph.circuits.length));
    expect(elec.where((d) => d.startsWith(t('agb.bom.transformer'))), hasLength(1));
    expect(r.bom.length, greaterThan(before.bom.length));
    expect(r.annualEnergyCost, closeTo(before.annualEnergyCost, 1e-6), reason: 'the electrics change no energy');
    // the report tables
    final tables = buildReportTables(project: p, results: r, labels: ReportLabels(t: t.call, has: t.has, warning: t.warning));
    expect(tables.where((x) => x.key == 'pumpHouse').single.rows, hasLength(ph.circuits.length));
    expect(tables.where((x) => x.key == 'pumpHouseSupply'), hasLength(1));
    // the results and the settings survive their files
    final back = DesignResults.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.agb!.pumpHouse!.circuits.first.sectionMm2, ph.circuits.first.sectionMm2);
    expect(back.agb!.pumpHouse!.sourceKva, ph.sourceKva);
    final file = Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(file.agb.pumpHouse.enabled, isTrue);
  });

  test('settings: only what differs is written, unknown fields are kept, a damaged section is set aside', () {
    final s = AgbSettings();
    expect(s.isDefault, isTrue);
    expect(s.toJson(), isEmpty);
    s.pumpHouse
      ..enabled = true
      ..voltage = 440
      ..pumps['e1'] = PumpFeeder(lengthM: 120, starter: StarterKind.softStarter);
    s.solar.mode = SolarMode.gridTied;
    s.water.ironMgL = 0.6;
    s.twoWire.decoderPrices[2] = 90;
    final round = AgbSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(round.toJson()), jsonEncode(s.toJson()));
    final future = AgbSettings.fromJson({
      'newPart': 1,
      'pumpHouse': {'on': true, 'zz': 2},
    });
    expect(future.toJson()['newPart'], 1);
    expect((future.toJson()['pumpHouse'] as Map)['zz'], 2);
    final j = Project().toJson()..['agb'] = {'pumpHouse': 'not an object'};
    final p = Project.fromJson(j);
    expect(p.agb.pumpHouse.enabled, isFalse);
  });

  test('pivots with an electrical design report their supply even with the pump house off', () {
    final p = buildExample(ExampleId.pivot, t.call, lang: 'pt');
    final pivot = p.entities.whereType<PivotEntity>().first;
    pivot.machine.voltage = 440;
    final r = Designer(p, label: t.call).designAll();
    final s = r.agb!.pumpHouse!.pivots.single;
    expect(s.pivotId, pivot.id);
    expect(s.spanCurrentA, greaterThan(0));
    expect(s.collectorRingA, s.spanCurrentA);
    expect(s.spanAmpacityA, cableAmpacity(s.spanCableMm2, CableInsulation.pvc, CableMethod.e));
    expect(s.awg, awgFor(s.spanMinMm2 > s.spanCableMm2 ? s.spanMinMm2 : s.spanCableMm2));
    expect(r.agb!.pumpHouse!.circuits, isEmpty, reason: 'the pump house itself stays off');
    final pivotLines = [for (final l in r.bom) if (l.category == 'bom.pivots') l.description];
    expect(pivotLines.where((d) => d.contains(t('agb.bom.ring'))), hasLength(1));
    expect(pivotLines.where((d) => d.contains(t('agb.bom.endTower'))), hasLength(1));
    expect(agbEnergyCost(r), r.annualEnergyCost);
  });
}
