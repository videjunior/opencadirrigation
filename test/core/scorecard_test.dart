import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/life_scenarios.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/scorecard.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/plot_charts.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/scenario.dart';
import 'package:opencadirrigation/core/units.dart';

/// The design scorecard (1.7.0 SCR): the scoring functions at their anchors
/// and between them, the grades, the weights and the means without the
/// indicators that are not assessed, a designed example within its range, a
/// deliberately worse variant of it lower in the right categories, the
/// ageing test, the alternatives, the report table and the chart.
void main() {
  final t = I18n('en');
  Project example(ExampleId id) => buildExample(id, t.call, lang: 'en');
  DesignResults design(Project p) => Designer(p, label: t.call).designAll();

  group('scoring functions', () {
    test('EU: the ASABE EP405.1 classes at their anchors and linear between them', () {
      for (final (x, s) in const [(0.0, 0.0), (70.0, 60.0), (80.0, 70.0), (90.0, 80.0), (94.0, 90.0), (100.0, 100.0)]) {
        expect(euCurve.at(x), closeTo(s, 1e-9), reason: 'EU $x');
      }
      // between the anchors: 92 % is half way from 90 (80) to 94 (90)
      expect(euCurve.at(92), closeTo(85, 1e-9));
      expect(euCurve.at(85), closeTo(75, 1e-9));
      expect(euCurve.at(35), closeTo(30, 1e-9));
      expect(euCurve.at(97), closeTo(95, 1e-9));
      // held beyond the ends
      expect(euCurve.at(-5), 0);
      expect(euCurve.at(120), 100);
      expect(euCurve.at(double.nan), 0);
    });

    test('overlap CU: 85 % satisfactory, 75 % the limit of the design check', () {
      expect(sprinklerCuCurve.at(75), closeTo(60, 1e-9));
      expect(sprinklerCuCurve.at(85), closeTo(80, 1e-9));
      expect(sprinklerCuCurve.at(100), closeTo(100, 1e-9));
      expect(sprinklerCuCurve.at(80), closeTo(70, 1e-9));
      expect(sprinklerCuCurve.at(92.5), closeTo(90, 1e-9));
      expect(sprinklerCuCurve.at(37.5), closeTo(30, 1e-9));
    });

    test('q_var: ≤ 10 % desirable, ≤ 20 % acceptable, lower is better', () {
      for (final (x, s) in const [(0.0, 100.0), (10.0, 90.0), (20.0, 70.0), (100.0, 0.0)]) {
        expect(flowVariationCurve.at(x), closeTo(s, 1e-9), reason: 'q_var $x');
      }
      expect(flowVariationCurve.at(5), closeTo(95, 1e-9));
      expect(flowVariationCurve.at(15), closeTo(80, 1e-9));
      expect(flowVariationCurve.at(60), closeTo(35, 1e-9));
      expect(flowVariationCurve.at(150), 0);
    });

    test('shares score their value, counts that must be zero score all or nothing', () {
      expect(shareCurve.at(37.5), closeTo(37.5, 1e-9));
      expect(shareCurve.at(100), 100);
      expect(noneCurve.at(0), 100);
      expect(noneCurve.at(1), 0);
      expect(noneCurve.at(3), 0);
    });

    test('grades at their limits', () {
      expect(scoreGrade(100), 'A');
      expect(scoreGrade(90), 'A');
      expect(scoreGrade(89.9), 'B');
      expect(scoreGrade(80), 'B');
      expect(scoreGrade(79.9), 'C');
      expect(scoreGrade(70), 'C');
      expect(scoreGrade(60), 'D');
      expect(scoreGrade(59.9), 'E');
      expect(scoreGrade(0), 'E');
    });
  });

  group('means and weights', () {
    ScoreIndicator ind(String key, ScoreCategory c, double? v, {ScoreCurve? curve = shareCurve, double w = 1}) => ScoreIndicator(key: key, category: c, curve: curve, value: v, weight: w);
    DesignScorecard card(List<ScoreIndicator> xs, {Map<ScoreCategory, double> weights = defaultScoreWeights}) => DesignScorecard([
      for (final c in ScoreCategory.values)
        ScoreCategoryResult(c, weights[c] ?? 1, [
          for (final i in xs)
            if (i.category == c) i,
        ]),
    ]);

    test('an indicator without data and one reported only stay out of the means', () {
      final s = card([
        ind('a', ScoreCategory.uniformity, 80),
        ind('b', ScoreCategory.uniformity, null), // not assessed
        ind('c', ScoreCategory.uniformity, 1234, curve: null), // reported only
        ind('d', ScoreCategory.hydraulics, 50),
        ind('e', ScoreCategory.hydraulics, 100),
      ]);
      expect(s.categoryOf(ScoreCategory.uniformity).score, 80);
      expect(s.categoryOf(ScoreCategory.hydraulics).score, 75);
      expect(s.categoryOf(ScoreCategory.energy).score, isNull);
      expect(s.assessed, hasLength(2));
      expect(s.overall, closeTo(77.5, 1e-9));
      expect(s.grade, 'C');
      expect(s.indicator('b')!.assessed, isFalse);
      expect(s.indicator('c')!.informative, isTrue);
      expect(s.indicator('c')!.score, isNull);
      expect(s.gainOf(s.indicator('b')!), 0);
      expect(s.gainOf(s.indicator('c')!), 0);
    });

    test('the points to gain: (100 − s) × the share of the indicator, the largest first', () {
      final s = card([ind('a', ScoreCategory.uniformity, 80), ind('d', ScoreCategory.hydraulics, 50), ind('e', ScoreCategory.hydraulics, 100)]);
      // a: a whole category of two → (100 − 80) / 2; d: half of the other
      expect(s.gainOf(s.indicator('a')!), closeTo(10, 1e-9));
      expect(s.gainOf(s.indicator('d')!), closeTo(12.5, 1e-9));
      expect(s.gainOf(s.indicator('e')!), 0);
      expect([for (final (i, _) in s.improvements) i.key], ['d', 'a']);
      // raising an indicator to 100 adds exactly its points
      final better = card([ind('a', ScoreCategory.uniformity, 80), ind('d', ScoreCategory.hydraulics, 100), ind('e', ScoreCategory.hydraulics, 100)]);
      expect(better.overall! - s.overall!, closeTo(12.5, 1e-9));
    });

    test('the weights of the categories and of the indicators', () {
      final xs = [ind('a', ScoreCategory.uniformity, 80), ind('d', ScoreCategory.hydraulics, 50, w: 3), ind('e', ScoreCategory.hydraulics, 100)];
      // indicator weights: (3 × 50 + 100) / 4
      expect(card(xs).categoryOf(ScoreCategory.hydraulics).score, closeTo(62.5, 1e-9));
      // category weights: uniformity counts twice
      final s = card(xs, weights: {...defaultScoreWeights, ScoreCategory.uniformity: 2});
      expect(s.overall, closeTo((2 * 80 + 62.5) / 3, 1e-9));
      expect(s.shareOf(s.indicator('a')!), closeTo(2 / 3, 1e-9));
      expect(s.shareOf(s.indicator('d')!), closeTo(3 / 4 / 3, 1e-9));
      // a category of weight 0 is left out
      final zero = card(xs, weights: {...defaultScoreWeights, ScoreCategory.hydraulics: 0});
      expect(zero.overall, closeTo(80, 1e-9));
    });

    test('nothing assessed: no overall score and no grade', () {
      final s = card([ind('a', ScoreCategory.uniformity, null)]);
      expect(s.overall, isNull);
      expect(s.grade, isNull);
      expect(s.improvements, isEmpty);
    });
  });

  group('a designed project', () {
    late Project p;
    late DesignResults r;
    late DesignScorecard s;
    setUp(() {
      p = example(ExampleId.orchard);
      r = design(p);
      s = designScorecard(p, r);
    });

    test('the orchard example scores A, between 90 and 100, with every value from its results', () {
      expect(s.overall, inInclusiveRange(90, 100));
      expect(s.grade, 'A');
      // no alternative saved: the economy is not assessed, nor the ageing
      expect(s.categoryOf(ScoreCategory.economy).score, isNull);
      expect(s.indicator('lccRank')!.gap, ScoreGap.alternatives);
      expect(s.indicator('agedEu')!.gap, ScoreGap.life);
      // the examples carry no soil: the rate and the runoff are not assessed
      expect(s.indicator('rateIntake')!.gap, ScoreGap.soil);
      expect(s.indicator('runoff')!.assessed, isFalse);
      // the catalogue pumps have no efficiency curve
      expect(s.indicator('pumpBep')!.gap, ScoreGap.curve);
      expect(s.assessed.length, 6);
      // EU: the flow-weighted mean of the drip and micro zones
      final micro = [
        for (final z in r.zones.values)
          if (z.emitterCount > 0 && !sprinklerZone(p, z)) z,
      ];
      expect(micro, isNotEmpty);
      final q = micro.fold(0.0, (a, z) => a + z.totalFlow);
      expect(s.indicator('eu')!.value, closeTo(micro.fold(0.0, (a, z) => a + z.uniformity.eu * z.totalFlow) / q, 1e-9));
      expect(s.indicator('eu')!.score, closeTo(euCurve.at(s.indicator('eu')!.value!), 1e-9));
      // the pump head used: 1 − surplus / pump boost, by flow × hours
      var sum = 0.0, den = 0.0;
      for (final f in r.systemFlows) {
        for (final d in f.supplies) {
          final boost = d.pumpBoost!;
          final w = d.flow * f.durationHours;
          sum += 100 * (1 - d.surplusHead.clamp(0.0, boost) / boost) * w;
          den += w;
        }
      }
      expect(s.indicator('headUse')!.value, closeTo(sum / den, 1e-9));
      expect(s.indicator('headUse')!.value, lessThan(100), reason: 'the orchard pump gives more head than its zones need');
      // the hydraulics of a design within its limits
      expect(s.categoryOf(ScoreCategory.hydraulics).score, 100);
      expect(s.indicator('errors')!.value, 0);
      // kWh per m³: the energy of the flows over their volume, reported only
      final (kwh, m3) = pumpingEnergy(p, r);
      expect(s.indicator('specificEnergy')!.value, closeTo(kwh / m3, 1e-12));
      expect(s.indicator('specificEnergy')!.score, isNull);
      // the first improvement is the one with the most points
      final imp = s.improvements;
      expect(imp.first.$2, greaterThanOrEqualTo(imp.last.$2));
      expect(imp.first.$1.key, 'headUse');
    });

    test('pipes forced to the smallest size: lower in uniformity and hydraulics', () {
      final q = p.copy();
      final small = q.catalog.pipesFor(PipeUsage.zone).reduce((a, b) => a.innerDiameterMm < b.innerDiameterMm ? a : b);
      for (final e in q.entities) {
        if (e is PipeEntity && e.scope == HydraulicScope.zone) {
          e
            ..pipeSpecId = small.id
            ..computerSized = false;
        }
      }
      final bad = designScorecard(q, Designer(q, label: t.call).analyzeAll());
      expect(bad.overall!, lessThan(s.overall!));
      expect(bad.categoryOf(ScoreCategory.uniformity).score!, lessThan(s.categoryOf(ScoreCategory.uniformity).score! - 10));
      expect(bad.categoryOf(ScoreCategory.hydraulics).score!, lessThan(s.categoryOf(ScoreCategory.hydraulics).score! - 5));
      expect(bad.indicator('window')!.value!, lessThan(100));
      expect(bad.indicator('qvar')!.value!, greaterThan(s.indicator('qvar')!.value!));
      // the weakest point names the zone and the improvement list puts uniformity on top
      expect(bad.indicator('window')!.detail, isNotEmpty);
      expect(bad.improvements.first.$1.category, anyOf(ScoreCategory.uniformity, ScoreCategory.hydraulics));
    });

    test('the ageing test scores the robustness over the life of the design', () {
      final life = lifeScenarios(p, asNew: r, label: t.call);
      final aged = designScorecard(p, r, life: life);
      expect(aged.indicator('agedEu')!.assessed, isTrue);
      expect(aged.indicator('agedWindow')!.assessed, isTrue);
      // clogging takes flow and adds variation: the EU falls
      expect(aged.indicator('agedEu')!.value!, lessThan(aged.indicator('eu')!.value!));
      expect(aged.indicator('agedEu')!.score, closeTo(euCurve.at(aged.indicator('agedEu')!.value!), 1e-9));
      expect(aged.categoryOf(ScoreCategory.robustness).score!, lessThanOrEqualTo(s.categoryOf(ScoreCategory.robustness).score!));
    });

    test('an alternative: the life-cycle cost against the cheapest, and its own scorecard', () {
      final q = p.copy();
      q.params.powerCostPerKwh *= 3; // the same design with dearer energy
      final rq = design(q);
      p.scenarios.add(Scenario(id: 'alt', name: 'Dear energy', created: DateTime(2026), metrics: scenarioMetrics(q, rq), snapshot: scenarioSnapshot(q, rq)));
      final withAlt = designScorecard(p, r);
      final lcc = withAlt.indicator('lccRank')!;
      expect(lcc.assessed, isTrue);
      // the current design is the cheapest over its life
      expect(lcc.value, closeTo(100, 1e-6));
      expect(withAlt.categoryOf(ScoreCategory.economy).score, closeTo(100, 1e-6));
      // the alternative read back from its snapshot scores like a design of its own
      final alt = scenarioScorecard(p.scenarios.single)!;
      expect(alt.overall, closeTo(designScorecard(q, rq, alternatives: false).overall!, 1e-9));
      expect(alt.indicator('lccRank')!.assessed, isFalse);
      // a scenario saved without results has no scorecard
      expect(scenarioScorecard(Scenario(id: 'x', name: 'x', created: DateTime(2026), metrics: const {}, snapshot: scenarioSnapshot(q))), isNull);
    });

    test('no pump: the energy category is not assessed and the overall score leaves it out', () {
      final g = example(ExampleId.garden);
      final gs = designScorecard(g, design(g));
      expect(gs.categoryOf(ScoreCategory.energy).score, isNull);
      expect(gs.indicator('pumpRange')!.assessed, isFalse);
      expect(gs.indicator('specificEnergy')!.assessed, isFalse);
      final mean = gs.assessed.fold(0.0, (a, c) => a + c.score!) / gs.assessed.length;
      expect(gs.overall, closeTo(mean, 1e-9));
    });

    test('a gravity mainline without air valves at its high points loses its completeness (AWWA M51)', () {
      final g = example(ExampleId.gravity);
      final gr = design(g);
      final gs = designScorecard(g, gr);
      final missing = gr.messages.where((m) => m.startsWith('air_valve_missing')).length;
      expect(missing, greaterThan(0));
      expect(gs.indicator('airValves')!.value, missing);
      expect(gs.indicator('airValves')!.score, 0);
      expect(gs.improvements.first.$1.key, 'airValves');
    });

    test('the report table: overall, every category, every indicator with its source', () {
      final tb = scorecardTable(s, t: t.call, units: p.params.units, currency: p.params.currency);
      expect(tb.key, 'scorecard');
      expect(tb.headers, hasLength(10));
      expect(tb.rows, hasLength(1 + ScoreCategory.values.length + s.indicators.length));
      expect(tb.rows.first.first, t('scr.overall'));
      expect((tb.rows.first[5] as RNum).value, closeTo(s.overall!, 1e-9));
      final eu = tb.rows.firstWhere((row) => row[1] == t('scr.i.eu'));
      expect(eu[3], '≥ 94 %');
      expect(eu[4], contains('ASABE EP405.1'));
      expect(tb.ids[tb.rows.indexOf(eu)], s.indicator('eu')!.entityId);
      final na = tb.rows.firstWhere((row) => row[1] == t('scr.i.agedEu'));
      expect(na[2], t('scr.na.life'));
      final info = tb.rows.firstWhere((row) => row[1] == t('scr.i.specificEnergy'));
      expect(info[2], contains('kWh/m³'));
      expect(info[9], t('scr.reported'));
      expect(reportTablesToCsv([tb]), contains(t('scr.i.headUse')));
      // in US units the cost per area is per acre
      final us = scorecardTable(s, t: t.call, units: Units.us, currency: '\$');
      expect(us.rows.firstWhere((row) => row[1] == t('scr.i.capitalPerHa'))[2], contains('/ac'));
    });

    test('the report tables carry the scorecard, built when it is read', () {
      final labels = ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w));
      final tables = ProjectExporter(project: p, results: r, labels: labels).reportTables();
      final tb = tables.firstWhere((x) => x.key == 'scorecard');
      expect(tb, isA<LazyReportTable>());
      expect(tb.rows, isNotEmpty);
      expect(tb.warn, hasLength(tb.rows.length));
      expect((tb.rows.first[5] as RNum).value, closeTo(s.overall!, 1e-9));
      // without results there is none
      expect(ProjectExporter(project: p, labels: labels).reportTables().any((x) => x.key == 'scorecard'), isFalse);
    });

    test('the radar goes with the charts of the sheets, inside its frame', () {
      final charts = designCharts(p, r, t: t.call, u: p.params.units);
      final radar = charts.last;
      expect(radar.title, t('scr.title'));
      expect(radar.isEmpty, isFalse);
      final scene = chartScene(radar, widthMm: 273, heightMm: 74);
      final texts = [for (final x in scene.items.whereType<PlotText>()) x.text];
      for (final c in ScoreCategory.values) {
        expect(texts.any((x) => x.startsWith(t('scr.c.${c.name}'))), isTrue, reason: c.name);
      }
      for (final it in scene.items.whereType<PlotPath>()) {
        for (final q in it.points) {
          expect(q.x >= -1e-9 && q.x <= 273 + 1e-9 && q.y >= -1e-9 && q.y <= 74 + 1e-9, isTrue);
        }
      }
      expect(designCharts(p, null, t: t.call).any((c) => c.title == t('scr.title')), isFalse);
    });
  });
}
