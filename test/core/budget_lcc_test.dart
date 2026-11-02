import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/budget.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/life_cycle.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/scenario.dart';

/// The budget by compositions (PRD-21) and the life-cycle cost of the
/// alternatives (PRD-20).
void main() {
  final t = I18n('pt');
  final labels = ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w));
  final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
  final r = Designer(p, label: (k) => t(k)).designAll();

  group('budget by compositions', () {
    test('a composition: the hours of every member of the crew over the output of the crew a day', () {
      final q = p.copy();
      q.deliverables.budget.rates
        ..['plumber'] = 20
        ..['helper'] = 10;
      final b = buildBudget(q, r, describe: t.call);
      final pipe = b.service('pipe')!;
      final perDay = defaultProductivity['pipe']!;
      final plumber = pipe.inputs.firstWhere((i) => i.resource.key == 'plumber');
      final helper = pipe.inputs.firstWhere((i) => i.resource.key == 'helper');
      expect(plumber.coefficient, closeTo(1 * budgetHoursPerDay / perDay, 1e-12));
      expect(helper.coefficient, closeTo(2 * budgetHoursPerDay / perDay, 1e-12));
      expect(pipe.unitCost, closeTo(8 / perDay * 20 + 16 / perDay * 10, 1e-9));
      final task = scheduleTasks(q, q.proposal).firstWhere((x) => x.key == 'pipe');
      expect(pipe.quantity, task.quantity);
      expect(pipe.total, closeTo(task.quantity * pipe.unitCost, 1e-9));
      // a productivity of the project changes the composition
      q.proposal.productivity['pipe'] = 150;
      expect(buildBudget(q, r).service('pipe')!.inputs.first.coefficient, closeTo(8 / 150, 1e-12));
    });

    test('the materials are the bill of materials, with the supply BDI', () {
      final b = buildBudget(p, r);
      expect(b.materials.length, r.bom.where((l) => l.quantity > 0).length);
      expect(b.directMaterials, closeTo(r.capitalCost, 1e-6));
      expect(b.materialsPrice, closeTo(r.capitalCost * (1 + b.materialsBdi), 1e-6));
      expect(b.servicesPrice, closeTo(b.directServices * (1 + b.servicesBdi), 1e-6));
      expect(b.total, closeTo(b.servicesPrice + b.materialsPrice, 1e-6));
      // each material goes with the service that installs it
      expect(b.materials.where((m) => m.line.category == 'bom.pipes').every((m) => m.taskKey == 'pipe'), isTrue);
      expect(b.materials.where((m) => m.line.category == 'bom.pumps').every((m) => m.taskKey == 'station'), isTrue);
      // without results: the services only
      final none = buildBudget(p, null);
      expect(none.materials, isEmpty);
      expect(none.services, isNotEmpty);
    });

    test('the schedule spreads every service over its periods, and the periods add up to the total', () {
      final q = p.copy()..deliverables.budget.periodDays = 2;
      final b = buildBudget(q, r);
      expect(b.periods, (b.durationDays / 2).ceil());
      for (final s in b.services) {
        final sh = b.shares(s.start, s.days);
        expect(sh.fold(0.0, (a, x) => a + x), closeTo(1, 1e-9), reason: s.key);
      }
      final values = b.periodValues();
      expect(values, hasLength(b.periods));
      expect(values.fold(0.0, (a, v) => a + v), closeTo(b.total, 1e-6));
      // a task of no days goes in the period it starts in
      expect(b.shares(3, 0), [for (var k = 0; k < b.periods; k++) k == 1 ? 1.0 : 0.0]);
    });

    test('the reference hourly costs follow the currency of the project', () {
      final q = p.copy()..setCurrency('USD', rate: exchangeRate(catalogPriceCurrency, 'USD'));
      final helper = budgetResources.firstWhere((x) => x.key == 'helper');
      expect(budgetHourlyCost(q, helper), closeTo(helper.referenceBrlPerHour * exchangeRate('BRL', 'USD')!, 1e-9));
      q.deliverables.budget.rates['helper'] = 7;
      expect(budgetHourlyCost(q, helper), 7);
    });

    test('the BDI against the reference ranges of the ruling', () {
      expect(bdiWithin(0.2085, bdiReferenceRanges.services), isTrue);
      expect(bdiWithin(0.30, bdiReferenceRanges.services), isFalse);
      expect(bdiWithin(0.1110, bdiReferenceRanges.materials), isTrue);
    });

    test('the document: summary, items, compositions, BDI, hourly costs and schedule', () {
      final b = buildBudget(p, r, describe: t.call);
      final doc = budgetDocument(p, b, labels);
      expect(doc.key, 'budget');
      expect(doc.sections.map((s) => s.key), ['summary', 'items', 'compositions', 'bdi', 'resources', 'schedule']);
      final items = doc.tables.firstWhere((x) => x.key == 'budgetItems');
      expect((items.rows.last.last as RNum).value, closeTo(b.total, 1e-6));
      expect(items.rows.first[1], 'C01');
      expect(items.rows.first[2], t('works.${b.services.first.key}'));
      final sched = doc.tables.firstWhere((x) => x.key == 'budgetSchedule');
      expect(sched.headers, hasLength(2 + b.periods));
      final sheets = XlsxReader.read(doc.toXlsx());
      expect(sheets.map((s) => s.name), contains(t('prb.bud.compositions').substring(0, math.min(31, t('prb.bud.compositions').length))));
    });
  });

  group('life-cycle cost', () {
    test('present values: replacements in the study, the residual value, energy and maintenance', () {
      final q = p.copy()..deliverables.lifeCycle.discountPct = 10;
      final upv = (1 - math.pow(1.1, -20)) / 0.1; // uniform present worth, 20 years at 10 %
      final ten = lifeCycleOfAlternative(
        q,
        name: 'a',
        items: const [LifeCycleItem(category: 'x', cost: 1000, lifeYears: 10, maintenancePct: 2)],
        investment: 1000,
        annualEnergy: 100,
        annualWaterM3: 0,
        areaHa: 2,
      );
      // replaced in year 10, nothing left at the end of year 20
      expect(ten.replacements, closeTo(1000 / math.pow(1.1, 10), 1e-6));
      expect(ten.residual, closeTo(0, 1e-9));
      expect(ten.maintenance, closeTo(20 * upv, 1e-6));
      expect(ten.energy, closeTo(100 * upv, 1e-6));
      expect(ten.lcc, closeTo(1000 + 1000 / math.pow(1.1, 10) + 120 * upv, 1e-6));
      final crf = 0.1 * math.pow(1.1, 20) / (math.pow(1.1, 20) - 1);
      expect(ten.eac, closeTo(ten.lcc * crf, 1e-6));
      expect(ten.perHaYear, closeTo(ten.eac / 2, 1e-9));
      // a life of 15 years: replaced in year 15, two thirds of it left at year 20
      final fifteen = lifeCycleOfAlternative(
        q,
        name: 'b',
        items: const [LifeCycleItem(category: 'x', cost: 1000, lifeYears: 15, maintenancePct: 0)],
        investment: 1000,
        annualEnergy: 0,
        annualWaterM3: 0,
        areaHa: 0,
      );
      expect(fifteen.replacements, closeTo(1000 / math.pow(1.1, 15), 1e-6));
      expect(fifteen.residual, closeTo(1000 * 10 / 15 / math.pow(1.1, 20), 1e-6));
      expect(fifteen.cashFlow[15].capital, 1000);
      expect(fifteen.cashFlow[20].residual, closeTo(-1000 * 10 / 15, 1e-9));
      // without the residual credit
      q.deliverables.lifeCycle.residual = false;
      expect(
        lifeCycleOfAlternative(
          q,
          name: 'c',
          items: const [LifeCycleItem(category: 'x', cost: 1000, lifeYears: 15, maintenancePct: 0)],
          investment: 1000,
          annualEnergy: 0,
          annualWaterM3: 0,
          areaHa: 0,
        ).residual,
        0,
      );
    });

    test('the energy escalates and the water is priced', () {
      final q = p.copy()
        ..deliverables.lifeCycle.discountPct = 8
        ..deliverables.lifeCycle.energyEscalationPct = 3
        ..deliverables.lifeCycle.waterPrice = 0.5
        ..deliverables.lifeCycle.years = 5;
      final a = lifeCycleOfAlternative(q, name: 'a', items: const [], investment: 0, annualEnergy: 100, annualWaterM3: 1000, areaHa: 1);
      var e = 0.0, w = 0.0;
      for (var y = 1; y <= 5; y++) {
        e += 100 * math.pow(1.03, y - 1) / math.pow(1.08, y);
        w += 500 / math.pow(1.08, y);
      }
      expect(a.energy, closeTo(e, 1e-9));
      expect(a.water, closeTo(w, 1e-9));
      expect(a.perM3, closeTo(a.eac / 1000, 1e-12));
    });

    test('the parts of a design by category of its bill of materials, at the reference lives', () {
      final a = designAlternative(p, r, 'atual');
      final cats = {for (final l in r.bom) l.category};
      expect(a.items.map((i) => i.category).toSet(), cats.where((c) => r.bom.where((l) => l.category == c).fold(0.0, (s, l) => s + l.total) > 0).toSet());
      final tapes = a.items.firstWhere((i) => i.category == 'bom.tapes');
      expect(tapes.lifeYears, lifeCycleReference['bom.tapes']!.$1);
      expect(a.investment, closeTo(r.capitalCost, 1e-6));
      expect(a.annualEnergy, r.annualEnergyCost);
      // a life typed in the settings
      final q = p.copy()..deliverables.lifeCycle.life['bom.tapes'] = 3;
      expect(designAlternative(q, r, 'x').items.firstWhere((i) => i.category == 'bom.tapes').lifeYears, 3);
      // a quote: the investment is its total
      final s = p.copy()..proposal.labourPct = 20;
      expect(designAlternative(s, r, 'x').investment, closeTo(buildProposal(s, r, s.proposal).total, 1e-6));
    });

    test('the alternatives saved with their results compare with the current design', () {
      final q = p.copy();
      // an alternative with dearer energy: same parts, more energy
      final dear = p.copy()..params.powerCostPerKwh = p.params.powerCostPerKwh * 2;
      final rd = Designer(dear, label: (k) => t(k)).designAll();
      q.scenarios
        ..add(Scenario(id: 's1', name: 'Energia cara', created: DateTime(2026), metrics: scenarioMetrics(dear, rd), snapshot: scenarioSnapshot(dear, rd)))
        ..add(Scenario(id: 's2', name: 'Sem resultados', created: DateTime(2026), metrics: {'capital': 10000, 'annualEnergy': 500}, snapshot: scenarioSnapshot(dear)));
      final st = buildLifeCycleStudy(q, r, currentName: t('prb.lcc.current'));
      expect(st.alternatives.map((a) => a.name), [t('prb.lcc.current'), 'Energia cara', 'Sem resultados']);
      expect(st.alternatives[1].energy, greaterThan(st.alternatives[0].energy));
      expect(st.alternatives[2].approximate, isTrue);
      expect(st.alternatives[2].items.single.category, 'other');
      expect(st.best, isNotNull);
      final doc = lifeCycleDocument(q, st, labels);
      expect(doc.sections.map((s) => s.key), ['method', 'categories', 'compare', 'cashFlow']);
      final cmp = doc.tables.firstWhere((x) => x.key == 'lccCompare');
      expect(cmp.rows, hasLength(3));
      expect(cmp.rows[2].first, 'Sem resultados *');
      expect(cmp.rows.map((row) => row.last).toSet(), {1, 2, 3});
    });

    test('nothing to compare without results nor alternatives', () {
      final st = buildLifeCycleStudy(p, null);
      expect(st.alternatives, isEmpty);
      expect(st.best, isNull);
      final doc = lifeCycleDocument(p, st, labels);
      expect(doc.sections.map((s) => s.key), ['method', 'categories', 'compare']);
    });
  });
}
