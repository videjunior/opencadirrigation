import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/proposal_settings.dart';

void main() {
  final t = I18n('pt');
  group('payback', paybackTests);
  group('materials by sector', bomZoneTests);
  group('alternatives', scenarioTests);

  DesignResults bom(List<BomLine> lines) => DesignResults(timestamp: DateTime(2026))..bom.addAll(lines);

  test('margin, labour, trenches, extras, discount, taxes and freight add up', () {
    final p = Project();
    p.entities.add(PipeEntity(id: 'm', points: [Pt.zero, const Pt(100, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc100', depth: 0.6));
    p.entities.add(PipeEntity(id: 'z', points: [Pt.zero, const Pt(0, 50)], scope: HydraulicScope.zone, pipeSpecId: 'pvc50', depth: 0.4));
    p.entities.add(PipeEntity(id: 'surface', points: [Pt.zero, const Pt(30, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pvc50'));
    final s = ProposalSettings(markupPct: 25, labourPct: 30, trenchCostPerM3: 40, beddingM: 0.1, discountPct: 10, taxPct: 8, freight: 150, extras: [ProposalExtra(description: 'Start-up', unit: 'h', quantity: 4, unitPrice: 80)]);
    final r = bom([
      BomLine(category: 'bom.pipes', description: 'PVC 100', unit: 'm', quantity: 100, unitCost: 24),
      BomLine(category: 'bom.pipes', description: 'PVC 50', unit: 'm', quantity: 80, unitCost: 7.2),
      BomLine(category: 'bom.fittings', description: 'Tee', unit: 'pc', quantity: 2, unitCost: 0),
    ]);
    final trenches = trenchRows(p, s);
    expect(trenches, hasLength(2)); // the surface pipe has no trench
    final main = trenches.firstWhere((x) => x.scope == HydraulicScope.mainline);
    expect(main.length, closeTo(100, 1e-9));
    expect(main.width, closeTo(0.3, 1e-9)); // 0.1 m pipe + 0.2 m, at least 0.3 m
    expect(main.depth, closeTo(0.6 + 0.05 + 0.1, 1e-9));
    final zone = trenches.firstWhere((x) => x.scope == HydraulicScope.zone);
    expect(zone.volume, closeTo(50 * 0.3 * (0.4 + 0.025 + 0.1), 1e-9));

    final q = buildProposal(p, r, s);
    const cost = 100 * 24 + 80 * 7.2; // 2976
    expect(q.materialsCost, closeTo(cost, 1e-9));
    expect(q.materialsSale, closeTo(cost * 1.25, 1e-9));
    expect(q.labour, closeTo(cost * 0.30, 1e-9));
    final volume = main.volume + zone.volume;
    expect(q.trenchVolume, closeTo(volume, 1e-9));
    expect(q.trenchCost, closeTo(volume * 40, 1e-9));
    expect(q.extras, closeTo(320, 1e-9));
    final subtotal = cost * 1.25 + cost * 0.3 + volume * 40 + 320;
    expect(q.subtotal, closeTo(subtotal, 1e-9));
    expect(q.discount, closeTo(subtotal * 0.1, 1e-9));
    expect(q.taxes, closeTo(subtotal * 0.9 * 0.08, 1e-9));
    expect(q.total, closeTo(subtotal * 0.9 * 1.08 + 150, 1e-9));
    expect(q.unpriced, 1);
    expect(q.lines, hasLength(4)); // three BOM lines and the extra
    expect(q.lines.first.unitPrice, closeTo(30, 1e-9));
  });

  test('settings survive the project file and convert with the currency', () {
    final p = Project();
    p.proposal = ProposalSettings(markupPct: 12, trenchCostPerM3: 50, freight: 200, validityDays: 30, paymentTerms: '30/60', notes: 'n', extras: [ProposalExtra(description: 'x', quantity: 2, unitPrice: 10)]);
    final back = Project.fromJsonString(p.toJsonString());
    expect(back.proposal.markupPct, 12);
    expect(back.proposal.validityDays, 30);
    expect(back.proposal.paymentTerms, '30/60');
    expect(back.proposal.extras.single.total, 20);
    back.scalePrices(2);
    expect(back.proposal.trenchCostPerM3, 100);
    expect(back.proposal.freight, 400);
    expect(back.proposal.extras.single.unitPrice, 20);
    // a project without a quote writes nothing for it
    expect(Project().toJson().containsKey('proposal'), isFalse);
    expect(Project.fromJson(Project().toJson()).proposal.isDefault, isTrue);
  });

  test('the report has a quote table and a trench table built from a real design', () {
    final p = buildExampleProject(t.call, lang: 'pt');
    for (final e in p.entities.whereType<PipeEntity>()) {
      e.depth = 0.5;
    }
    p.proposal = ProposalSettings(markupPct: 20, taxPct: 5);
    final r = Designer(p, label: (k) => t(k)).designAll();
    final tables = buildReportTables(project: p, results: r, labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w)));
    final quote = tables.firstWhere((x) => x.key == 'proposal');
    final trench = tables.firstWhere((x) => x.key == 'trench');
    final q = buildProposal(p, r, p.proposal);
    expect(q.materialsCost, closeTo(r.capitalCost, 1e-6));
    expect(quote.rows.length, greaterThan(r.bom.length));
    expect(trench.rows, isNotEmpty);
    expect(q.total, closeTo(q.materialsSale * 1.05, 1e-6));
  });
}

void paybackTests() {
  test('payback, NPV and IRR of an investment', () {
    final pb = Payback(total: 10000, annualBenefit: 3000, annualCost: 500, years: 10, rate: 0.1);
    expect(pb.annualNet, 2500);
    expect(pb.simpleYears, closeTo(4, 1e-12));
    // annuity factor (1 − 1.1^−10)/0.1 = 6.1446
    expect(pb.npv, closeTo(-10000 + 2500 * 6.144567, 0.01));
    final irr = pb.irr!;
    expect(Payback(total: 10000, annualBenefit: 3000, annualCost: 500, years: 10, rate: irr).npv, closeTo(0, 1e-6));
    expect(irr, closeTo(0.2141, 1e-3));
    expect(Payback(total: 10000, annualBenefit: 100, annualCost: 500, years: 10, rate: 0.1).irr, isNull);
    expect(Payback(total: 10000, annualBenefit: 100, annualCost: 500, years: 10, rate: 0.1).simpleYears, double.infinity);
  });
}

void bomZoneTests() {
  test('the materials split by sector add up to the bill of materials', () {
    final t = I18n('pt');
    final p = buildExampleProject(t.call, lang: 'pt');
    final r = Designer(p, label: (k) => t(k)).designAll();
    final valves = p.entities.whereType<ControlValveEntity>().map((v) => v.id).toSet();
    expect(r.bomByZone.keys.toSet(), containsAll({'', ...valves}));
    expect(r.bomByZone.containsKey('elec'), isTrue); // the example has its wiring
    double total(Iterable<BomLine> l) => l.fold(0.0, (a, x) => a + x.total);
    final split = r.bomByZone.values.fold(0.0, (a, l) => a + total(l));
    // fittings are rounded up sector by sector, so the split may round a few more
    expect(split, greaterThanOrEqualTo(r.capitalCost - 1e-6));
    expect(split, lessThan(r.capitalCost * 1.03));
    // every valve sits in its own sector, the pump on the mainline
    for (final id in valves) {
      final name = p.catalog.valve((p.byId(id) as ControlValveEntity).valveSpecId)!.name;
      expect(r.bomByZone[id]!.any((l) => l.description == name), isTrue);
    }
    final pump = p.catalog.pump(p.entities.whereType<PumpEntity>().first.pumpSpecId)!.name;
    expect(r.bomByZone['']!.any((l) => l.description == pump), isTrue);
    final back = DesignResults.fromJson(r.toJson());
    expect(back.bomByZone.length, r.bomByZone.length);
    final table = buildReportTables(project: p, results: r, labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w))).firstWhere((x) => x.key == 'bomZones');
    expect(table.rows.length, greaterThan(r.bomByZone.length));
  });
}

void scenarioTests() {
  test('alternatives: saved with their figures, compared, restored in one undo step', () {
    final t = I18n('en');
    final c = ProjectController()..autosaveEnabled = false;
    c.setLanguage('en');
    c.project = buildExampleProject(t.call, lang: 'en');
    c.results = Designer(c.project, label: (k) => t(k)).designAll();
    final first = c.saveScenario('LP')!;
    expect(first.metrics['capital'], closeTo(c.results!.capitalCost, 1e-6));
    expect(first.metrics.keys, containsAll(['capital', 'annualEnergy', 'annualTotal', 'peakFlow', 'pMin', 'euMin', 'mainlineM']));
    expect(c.results, isNotNull); // saving keeps the results
    // change the design: everything greedy
    c.project.params.sizingMethod = SizingMethod.greedy;
    c.results = Designer(c.project, label: (k) => t(k)).designAll();
    final greedyCapital = c.results!.capitalCost;
    final second = c.saveScenario('');
    expect(second!.name, 'Alternative 2');
    expect(c.project.scenarios, hasLength(2));
    // restore the first: method back to LP, results of then, the list kept
    expect(c.restoreScenario(first.id), isTrue);
    expect(c.project.params.sizingMethod, SizingMethod.lp);
    expect(c.results!.capitalCost, closeTo(first.metrics['capital']!, 1e-6));
    expect(c.project.scenarios, hasLength(2));
    c.undo();
    expect(c.project.params.sizingMethod, SizingMethod.greedy);
    // survive the file
    final back = Project.fromJsonString(c.project.toJsonString());
    expect(back.scenarios.map((s) => s.name), ['LP', 'Alternative 2']);
    expect(back.scenarios.last.metrics['capital'], closeTo(greedyCapital, 1e-6));
    final table = buildReportTables(project: back, results: null, labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w))).firstWhere((x) => x.key == 'scenarios');
    expect(table.rows, hasLength(2));
    c.deleteScenario(first.id);
    expect(c.project.scenarios.single.name, 'Alternative 2');
  });
}
