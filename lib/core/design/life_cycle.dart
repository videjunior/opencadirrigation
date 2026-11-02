/// Life-cycle cost of the design alternatives (1.6.0): the investment, the
/// replacements of every part at the end of its life, the value left in
/// the parts at the end of the study, the energy, the water and the yearly
/// maintenance over N years, brought to the present at a discount rate,
/// for the current design and every alternative saved with its results —
/// so that drip, micro-sprinklers and a pivot, or a larger pipe against a
/// larger pump, compare over their lives and not only by what they cost to
/// buy.
///
/// LCC = I + Repl − Res + E + W + OM&R, every term a present value (NIST
/// Handbook 135, Fuller & Petersen 1996, Life-Cycle Costing Manual for the
/// Federal Energy Management Program): PV = C / (1 + i)^t of an amount C in
/// year t; the energy of year t is that of the design raised by the
/// escalation e: E1·(1 + e)^(t−1); a part of life L is replaced in years L,
/// 2L… within the study, and the residual value is the share of the life of
/// its last replacement still ahead at the end of the study (straight
/// line). The equivalent annual cost EAC = LCC × i(1 + i)^N / ((1 + i)^N −
/// 1) gives the cost per hectare a year and per m³ of water.
///
/// Reference lives and maintenance by category of the bill of materials
/// ([lifeCycleReference], editable): pipelines and fittings 25 years (civil
/// works) and pumps, machines and drip lines 15 years (mechanical and
/// specialised parts), as Goulburn Broken CMA (2015, Comparing total costs
/// of irrigation systems) assumed; drip lines and sprinklers 10 years and
/// yearly maintenance of 1 % (permanent sprinkler systems), 3–5 % (drip),
/// 4 % (portable sprinklers) and 5 % (centre pivots) of the capital, from the
/// ARC Irrigation User's Manual as SASRI (2023, Information Sheet 5.15)
/// quotes it.
library;

import 'dart:math' as math;

import '../io/tech_doc.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../units.dart';
import 'permit.dart' show areaMonthlyNeed;
import 'proposal.dart';
import 'report_tables.dart';
import 'results.dart';

/// Reference life (years) and yearly maintenance (% of the cost) by
/// category of the bill of materials.
const lifeCycleReference = <String, (double, double)>{
  'bom.pipes': (25, 1),
  'bom.fittings': (25, 1),
  'bom.takeoffs': (15, 2),
  'bom.risers': (15, 2),
  'bom.tapes': (10, 5),
  'bom.outlets': (10, 4),
  'bom.valves': (15, 2),
  'bom.devices': (15, 3),
  'bom.pumps': (15, 5),
  'bom.pivots': (15, 5),
  'bom.electrical': (15, 2),
};

/// Life and maintenance of a category not in [lifeCycleReference] (and of
/// the capital of an alternative saved without its bill of materials).
const lifeCycleOther = (15.0, 2.0);

/// Life (years) and yearly maintenance (%) of [category] in [p]: typed in
/// the settings, else the reference.
(double, double) lifeCycleOf(Project p, String category) {
  final s = p.deliverables.lifeCycle;
  final ref = lifeCycleReference[category] ?? lifeCycleOther;
  return (s.life[category] ?? ref.$1, s.maintenance[category] ?? ref.$2);
}

/// One category of the parts of an alternative.
class LifeCycleItem {
  const LifeCycleItem({required this.category, required this.cost, required this.lifeYears, required this.maintenancePct});
  final String category;

  /// Cost of the parts (at their sale price), replaced at the end of each life.
  final double cost;
  final double lifeYears;
  final double maintenancePct;
}

/// The present values of one alternative.
class LifeCycleAlternative {
  LifeCycleAlternative({
    required this.name,
    required this.items,
    required this.investment,
    required this.replacements,
    required this.residual,
    required this.energy,
    required this.water,
    required this.maintenance,
    required this.annualEnergy,
    required this.annualWaterM3,
    required this.areaHa,
    required this.years,
    required this.rate,
    required this.approximate,
    required this.cashFlow,
  });
  final String name;
  final List<LifeCycleItem> items;

  /// I (year 0), and the present values of the replacements, of the
  /// residual value (a credit), of the energy, of the water and of the
  /// maintenance.
  final double investment;
  final double replacements;
  final double residual;
  final double energy;
  final double water;
  final double maintenance;

  /// Energy cost of the first year and water used a year (m³).
  final double annualEnergy;
  final double annualWaterM3;
  final double areaHa;
  final int years;
  final double rate;

  /// Saved without its bill of materials: one category for the whole
  /// capital.
  final bool approximate;

  /// Cost of every year 0…N (not discounted): investment and
  /// replacements, energy, water, maintenance, residual (negative).
  final List<({int year, double capital, double energy, double water, double maintenance, double residual})> cashFlow;

  double get lcc => investment + replacements - residual + energy + water + maintenance;

  /// Capital recovery factor i(1 + i)^N / ((1 + i)^N − 1) (1/N at i = 0).
  double get crf => rate <= 0 ? 1 / years : rate * math.pow(1 + rate, years) / (math.pow(1 + rate, years) - 1);
  double get eac => lcc * crf;
  double get perHaYear => areaHa > 0 ? eac / areaHa : 0;
  double get perM3 => annualWaterM3 > 0 ? eac / annualWaterM3 : 0;
}

/// The life-cycle cost study of a project.
class LifeCycleStudy {
  LifeCycleStudy({required this.alternatives, required this.years, required this.rate, required this.escalation, required this.waterPrice, required this.residual});
  final List<LifeCycleAlternative> alternatives;
  final int years;
  final double rate, escalation, waterPrice;
  final bool residual;

  /// The alternative of lowest LCC (null without any).
  LifeCycleAlternative? get best => alternatives.isEmpty ? null : alternatives.reduce((a, b) => b.lcc < a.lcc ? b : a);
}

/// The present values of an alternative whose parts are [items] and whose
/// investment is [investment], under the settings of [p].
LifeCycleAlternative lifeCycleOfAlternative(
  Project p, {
  required String name,
  required List<LifeCycleItem> items,
  required double investment,
  required double annualEnergy,
  required double annualWaterM3,
  required double areaHa,
  bool approximate = false,
}) {
  final s = p.deliverables.lifeCycle;
  final n = math.max(1, s.years);
  final i = (s.discountPct ?? p.params.interestRate * 100) / 100;
  final e = s.energyEscalationPct / 100;
  double pv(double c, int t) => c / math.pow(1 + i, t);
  final capital = List<double>.filled(n + 1, 0),
      energy = List<double>.filled(n + 1, 0),
      water = List<double>.filled(n + 1, 0),
      maint = List<double>.filled(n + 1, 0),
      res = List<double>.filled(n + 1, 0);
  capital[0] = investment;
  var repl = 0.0, residual = 0.0, pvE = 0.0, pvW = 0.0, pvM = 0.0;
  for (var t = 1; t <= n; t++) {
    energy[t] = annualEnergy * math.pow(1 + e, t - 1);
    water[t] = annualWaterM3 * s.waterPrice;
    pvE += pv(energy[t], t);
    pvW += pv(water[t], t);
  }
  for (final it in items) {
    final life = math.max(1.0, it.lifeYears);
    for (var t = 1; t <= n; t++) {
      maint[t] += it.cost * it.maintenancePct / 100;
      pvM += pv(it.cost * it.maintenancePct / 100, t);
    }
    // replacements within the study (not in its last year)
    var last = 0.0;
    for (var k = 1; k * life < n - 1e-9; k++) {
      final t = (k * life).round();
      capital[t] += it.cost;
      repl += pv(it.cost, t);
      last = k * life;
    }
    if (s.residual) {
      final left = (last + life - n) / life;
      if (left > 1e-9) {
        res[n] += it.cost * left;
        residual += pv(it.cost * left, n);
      }
    }
  }
  return LifeCycleAlternative(
    name: name,
    items: items,
    investment: investment,
    replacements: repl,
    residual: residual,
    energy: pvE,
    water: pvW,
    maintenance: pvM,
    annualEnergy: annualEnergy,
    annualWaterM3: annualWaterM3,
    areaHa: areaHa,
    years: n,
    rate: i,
    approximate: approximate,
    cashFlow: [for (var t = 0; t <= n; t++) (year: t, capital: capital[t], energy: energy[t], water: water[t], maintenance: maint[t], residual: -res[t])],
  );
}

/// Irrigated area (ha) and the gross water a year (m³) of [p].
(double, double) _areaAndWater(Project p) {
  var ha = 0.0, m3 = 0.0;
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    ha += a.area / 10000;
    m3 += areaMonthlyNeed(p, a).annualM3;
  }
  return (ha, m3);
}

/// The alternative of project [p] with its design results [r]: its parts by
/// category of the bill of materials (at the sale price of the quote) and
/// its investment (the total of the quote, the materials when no quote is
/// set).
LifeCycleAlternative designAlternative(Project p, DesignResults r, String name, {Project? settings}) {
  final cfg = settings ?? p;
  final markup = 1 + p.proposal.markupPct / 100;
  final byCat = <String, double>{};
  for (final l in r.bom) {
    byCat[l.category] = (byCat[l.category] ?? 0) + l.total * markup;
  }
  final items = [
    for (final e in byCat.entries)
      if (e.value > 0) LifeCycleItem(category: e.key, cost: e.value, lifeYears: lifeCycleOf(cfg, e.key).$1, maintenancePct: lifeCycleOf(cfg, e.key).$2),
  ];
  final investment = p.proposal.isDefault ? r.capitalCost : buildProposal(p, r, p.proposal).total;
  final (ha, m3) = _areaAndWater(p);
  return lifeCycleOfAlternative(cfg, name: name, items: items, investment: investment, annualEnergy: r.annualEnergyCost, annualWaterM3: m3, areaHa: ha);
}

/// The study of [p]: the current design (with results [r]) and every saved
/// alternative (from its results, or approximately from its figures when
/// it was saved without them), under the settings of [p].
LifeCycleStudy buildLifeCycleStudy(Project p, DesignResults? r, {String currentName = 'current'}) {
  final s = p.deliverables.lifeCycle;
  final out = <LifeCycleAlternative>[];
  if (r != null) out.add(designAlternative(p, r, currentName));
  for (final sc in p.scenarios) {
    Project? q;
    DesignResults? qr;
    try {
      q = Project.fromJson(Map<String, dynamic>.of(sc.snapshot)..remove('results'));
      final res = sc.snapshot['results'];
      if (res is Map) qr = DesignResults.fromJson(res.cast<String, dynamic>());
    } catch (_) {
      q = null;
      qr = null;
    }
    if (q != null && qr != null && qr.bom.isNotEmpty) {
      out.add(designAlternative(q, qr, sc.name, settings: p));
      continue;
    }
    final capital = sc.metrics['capital'] ?? 0;
    if (capital <= 0) continue;
    final (ha, m3) = q == null ? (0.0, 0.0) : _areaAndWater(q);
    out.add(
      lifeCycleOfAlternative(
        p,
        name: sc.name,
        items: [LifeCycleItem(category: 'other', cost: capital, lifeYears: s.life['other'] ?? lifeCycleOther.$1, maintenancePct: s.maintenance['other'] ?? lifeCycleOther.$2)],
        investment: capital,
        annualEnergy: sc.metrics['annualEnergy'] ?? 0,
        annualWaterM3: m3,
        areaHa: ha,
        approximate: true,
      ),
    );
  }
  return LifeCycleStudy(
    alternatives: out,
    years: math.max(1, s.years),
    rate: (s.discountPct ?? p.params.interestRate * 100) / 100,
    escalation: s.energyEscalationPct / 100,
    waterPrice: s.waterPrice,
    residual: s.residual,
  );
}

/// The study as a document: the method and its settings, the life and
/// maintenance of every category, the comparison of the alternatives and
/// the yearly costs of the one of lowest LCC.
TechDocument lifeCycleDocument(Project p, LifeCycleStudy st, ReportLabels labels) {
  final t = labels.t;
  final cur = p.params.currency;
  final m = p.meta;
  final s = p.deliverables.lifeCycle;
  final best = st.best;
  final sorted = [...st.alternatives]..sort((a, b) => a.lcc.compareTo(b.lcc));
  final rank = {for (var i = 0; i < sorted.length; i++) sorted[i]: i + 1};
  final cats = <String>{
    ...lifeCycleReference.keys,
    for (final a in st.alternatives)
      for (final it in a.items) it.category,
  }.toList();
  final comparison = ReportTable(
    key: 'lccCompare',
    title: t('prb.lcc.compare'),
    headers: [
      t('scn.name'),
      '${t('prb.lcc.investment')} ($cur)',
      '${t('prb.lcc.replacements')} ($cur)',
      '${t('prb.lcc.residual')} ($cur)',
      '${t('prb.lcc.energy')} ($cur)',
      '${t('prb.lcc.water')} ($cur)',
      '${t('prb.lcc.maintenance')} ($cur)',
      'LCC ($cur)',
      '${t('prb.lcc.eac')} ($cur/${t('prb.lcc.yr')})',
      '$cur/ha·${t('prb.lcc.yr')}',
      '$cur/m³',
      t('prb.lcc.rank'),
    ],
    rows: [
      for (final a in st.alternatives)
        [
          a.approximate ? '${a.name} *' : a.name,
          RNum(a.investment, 0),
          RNum(a.replacements, 0),
          RNum(-a.residual, 0),
          RNum(a.energy, 0),
          RNum(a.water, 0),
          RNum(a.maintenance, 0),
          RNum(a.lcc, 0),
          RNum(a.eac, 0),
          a.areaHa > 0 ? RNum(a.perHaYear, 0) : '-',
          a.annualWaterM3 > 0 ? RNum(a.perM3, 3) : '-',
          rank[a]!,
        ],
    ],
    warn: [for (final a in st.alternatives) identical(a, best) && st.alternatives.length > 1],
  );
  final categories = ReportTable(
    key: 'lccCategories',
    title: t('prb.lcc.categories'),
    headers: [t('rep.category'), '${t('prb.lcc.life')} (${t('prb.lcc.years')})', '${t('prb.lcc.maintPct')} (%/${t('prb.lcc.yr')})', t('prb.bud.origin')],
    rows: [
      for (final c in cats)
        [
          c == 'other' ? t('prb.lcc.other') : labels.category(c),
          RNum(lifeCycleOf(p, c).$1, 0),
          RNum(lifeCycleOf(p, c).$2, 1),
          s.life.containsKey(c) || s.maintenance.containsKey(c) ? t('prb.bud.typed') : t('prb.bud.reference'),
        ],
    ],
  );
  final flows = best == null
      ? null
      : ReportTable(
          key: 'lccCashFlow',
          title: t('prb.lcc.cashFlow', {'n': best.name}),
          headers: [
            t('prb.lcc.year'),
            '${t('prb.lcc.capital')} ($cur)',
            '${t('prb.lcc.energy')} ($cur)',
            '${t('prb.lcc.water')} ($cur)',
            '${t('prb.lcc.maintenance')} ($cur)',
            '${t('prb.lcc.residual')} ($cur)',
            '${t('prb.lcc.pv')} ($cur)',
          ],
          rows: [
            for (final c in best.cashFlow)
              [
                c.year,
                RNum(c.capital, 0),
                RNum(c.energy, 0),
                RNum(c.water, 0),
                RNum(c.maintenance, 0),
                RNum(c.residual, 0),
                RNum((c.capital + c.energy + c.water + c.maintenance + c.residual) / math.pow(1 + best.rate, c.year), 0),
              ],
          ],
        );
  return TechDocument(
    key: 'lcc',
    title: t('prb.lcc.title'),
    subtitle: [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].where((x) => x.isNotEmpty).join(' · '),
    landscape: true,
    sections: [
      TechSection(t('prb.lcc.method'), [
        TechParagraph(t('prb.lcc.methodText')),
        TechFormula(
          t('prb.f.lccExpr'),
          where: [
            ('I', t('prb.lcc.investment')),
            ('Repl', t('prb.lcc.replacements')),
            ('Res', t('prb.lcc.residual')),
            ('E', t('prb.lcc.energy')),
            ('W', t('prb.lcc.water')),
            ('OM&R', t('prb.lcc.maintenance')),
          ],
          source: t('prb.src.nist'),
        ),
        TechFormula(t('prb.f.pvExpr'), where: [('i', t('prb.lcc.rate')), ('t', t('prb.lcc.year')), ('N', t('prb.lcc.horizon'))]),
        TechFields([
          (t('prb.lcc.horizon'), '${st.years} ${t('prb.lcc.years')}'),
          (t('prb.lcc.rate'), '${fmt(st.rate * 100, 2)} %'),
          (t('prb.lcc.escalation'), '${fmt(st.escalation * 100, 2)} %'),
          (t('prb.lcc.waterPrice'), '$cur ${fmt(st.waterPrice, 4)}/m³'),
          (t('prb.lcc.residualOn'), st.residual ? t('prb.yes') : t('prb.no')),
        ]),
      ], key: 'method'),
      TechSection(t('prb.lcc.categories'), [TechTable(categories), TechParagraph(t('prb.lcc.refs'))], key: 'categories'),
      TechSection(t('prb.lcc.compare'), [
        if (st.alternatives.isEmpty) TechNote(t('prb.lcc.none'), warning: true) else TechTable(comparison),
        if (st.alternatives.any((a) => a.approximate)) TechNote(t('prb.lcc.approximate')),
        if (best != null && st.alternatives.length > 1) TechParagraph(t('prb.lcc.bestText', {'n': best.name, 'v': '$cur ${fmt(best.lcc, 0)}'})),
      ], key: 'compare'),
      if (flows != null) TechSection(t('prb.lcc.cashFlow', {'n': best!.name}), [TechTable(flows)], key: 'cashFlow'),
    ],
  );
}
