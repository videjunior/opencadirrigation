/// Budget by compositions of the works (1.6.0), in the way public works
/// are priced in Brazil (unit-cost compositions of the services, BDI and a
/// physical-financial schedule): every service of the construction
/// schedule (proposal.dart) gets a composition of the labour and equipment
/// one unit of it takes — the hours of every member of its crew over the
/// output of the crew per day, the productivities the schedule uses — at
/// their hourly costs; the materials of the bill of materials are a supply
/// of their own, at the catalogue prices; the BDI of the services and the
/// (lower) BDI of the supply of materials make the prices; the schedule
/// spreads the price of every service over the periods it runs in, and the
/// materials with the service that installs them.
///
/// BDI = ((1 + AC + S + G + R) × (1 + DF) × (1 + L) / (1 − I)) − 1, the
/// formula of Brazilian Federal Court of Accounts ruling Acórdão TCU
/// 2622/2013 (AC central administration, S + G insurance and guarantee, R
/// risk, DF financial costs, L profit, I taxes on the price); its reference
/// BDI for water-supply networks, sewerage and related works is 20.76 %
/// (first quartile) to 26.44 % (third quartile), median 24.18 %, and for the
/// mere supply of materials and equipment 11.10 % to 16.80 %, median
/// 14.02 % ([bdiReferenceRanges]).
///
/// The hourly costs of reference ([budgetResources]) are starting values in
/// Brazilian reais (converted to the project currency at the reference
/// rates of currency.dart): replace them with those of the official cost
/// table of the region and date of the budget (SINAPI in Brazil) in the
/// budget dialog.
library;

import 'dart:math' as math;

import '../io/tech_doc.dart';
import '../model/currency.dart';
import '../model/project.dart';
import '../units.dart';
import 'proposal.dart';
import 'report_tables.dart';
import 'results.dart';

/// A labour category or a piece of equipment of the compositions.
class BudgetResource {
  const BudgetResource(this.key, {required this.equipment, required this.referenceBrlPerHour});

  /// i18n `prb.res.<key>`.
  final String key;
  final bool equipment;

  /// Starting hourly cost (BRL), with the social charges of the labour and
  /// the operator and fuel of the equipment.
  final double referenceBrlPerHour;
}

/// The resources of the compositions and their starting hourly costs.
const budgetResources = [
  BudgetResource('surveyor', equipment: false, referenceBrlPerHour: 45),
  BudgetResource('plumber', equipment: false, referenceBrlPerHour: 32),
  BudgetResource('electrician', equipment: false, referenceBrlPerHour: 32),
  BudgetResource('helper', equipment: false, referenceBrlPerHour: 25),
  BudgetResource('backhoe', equipment: true, referenceBrlPerHour: 190),
  BudgetResource('compactor', equipment: true, referenceBrlPerHour: 25),
];

/// The crew of every service of the construction schedule: resource key →
/// how many of it work in the crew (8 h a day each).
const budgetCrews = <String, Map<String, int>>{
  'staking': {'surveyor': 1, 'helper': 1},
  'trench': {'backhoe': 1, 'helper': 1},
  'pipe': {'plumber': 1, 'helper': 2},
  'backfill': {'compactor': 1, 'helper': 2},
  'valves': {'plumber': 1, 'helper': 1},
  'wiring': {'electrician': 1, 'helper': 1},
  'laterals': {'helper': 2},
  'emitters': {'helper': 1},
  'station': {'plumber': 1, 'electrician': 1, 'helper': 1},
  'testing': {'plumber': 1, 'helper': 1},
};

/// Hours of a working day of a crew member.
const budgetHoursPerDay = 8.0;

/// Reference ranges of the BDI of Acórdão TCU 2622/2013 (fractions: first
/// quartile, median, third quartile): the services of water-supply
/// networks, sewerage and related works, and the mere supply of materials
/// and equipment.
const bdiReferenceRanges = (services: (0.2076, 0.2418, 0.2644), materials: (0.1110, 0.1402, 0.1680));

/// The service of the schedule that installs the materials of a category
/// of the bill of materials (in that order of preference).
const _materialTask = <String, List<String>>{
  'bom.pipes': ['pipe', 'laterals'],
  'bom.fittings': ['pipe', 'laterals'],
  'bom.tapes': ['laterals'],
  'bom.outlets': ['emitters', 'laterals'],
  'bom.risers': ['emitters', 'laterals'],
  'bom.takeoffs': ['laterals', 'pipe'],
  'bom.valves': ['valves'],
  'bom.devices': ['valves', 'station'],
  'bom.pumps': ['station'],
  'bom.pivots': ['station'],
  'bom.electrical': ['wiring', 'station'],
};

/// One input of a composition: a resource, the hours one unit of the
/// service takes of it and its hourly cost.
class BudgetInput {
  const BudgetInput({required this.resource, required this.coefficient, required this.hourlyCost});
  final BudgetResource resource;
  final double coefficient;
  final double hourlyCost;
  double get cost => coefficient * hourlyCost;
}

/// A priced service (or a free line of the quote, with no composition).
class BudgetService {
  BudgetService({required this.key, required this.code, required this.description, required this.unit, required this.quantity, required this.inputs, double? unitCost, this.start = 0, this.days = 0})
    : unitCost = unitCost ?? inputs.fold(0.0, (a, i) => a + i.cost);

  /// Task key of the schedule (`trench`…) or `extra`.
  final String key;
  final String code;
  final String description;
  final String unit;
  final double quantity;
  final List<BudgetInput> inputs;

  /// Direct cost of one unit.
  final double unitCost;

  /// Working days from the start of the works and its duration.
  final int start;
  final int days;
  double get total => quantity * unitCost;
}

/// A line of the supply of materials and the service that installs it.
class BudgetMaterial {
  const BudgetMaterial({required this.line, required this.taskKey});
  final BomLine line;
  final String taskKey;
  double get total => line.total;
}

/// The budget of a project.
class Budget {
  Budget({
    required this.services,
    required this.materials,
    required this.servicesBdi,
    required this.materialsBdi,
    required this.periodDays,
    required this.durationDays,
    required this.unpriced,
    required this.hourlyCosts,
  });
  final List<BudgetService> services;
  final List<BudgetMaterial> materials;

  /// BDI (fractions) of the services and of the supply of materials.
  final double servicesBdi;
  final double materialsBdi;

  /// Working days of a period of the schedule and of the whole works.
  final int periodDays;
  final int durationDays;

  /// Materials without a price (left at zero).
  final int unpriced;

  /// Hourly cost of every resource in use (project currency).
  final Map<String, double> hourlyCosts;

  double get directServices => services.fold(0.0, (a, s) => a + s.total);
  double get directMaterials => materials.fold(0.0, (a, m) => a + m.total);
  double get servicesPrice => directServices * (1 + servicesBdi);
  double get materialsPrice => directMaterials * (1 + materialsBdi);
  double get total => servicesPrice + materialsPrice;
  int get periods => math.max(1, (durationDays / periodDays).ceil());

  /// Share of a task running days [start] to [start] + [days] that falls
  /// in each period (adds up to 1; a task without days falls in the first).
  List<double> shares(int start, int days) {
    final n = periods;
    final out = List<double>.filled(n, 0);
    if (days <= 0) {
      out[math.min(n - 1, math.max(0, start ~/ periodDays))] = 1;
      return out;
    }
    for (var k = 0; k < n; k++) {
      final a = math.max(start, k * periodDays), b = math.min(start + days, (k + 1) * periodDays);
      if (b > a) out[k] = (b - a) / days;
    }
    return out;
  }

  /// The service of [key], or null.
  BudgetService? service(String key) => services.where((s) => s.key == key).firstOrNull;

  /// Price (with BDI) of every period: the services as they run, the
  /// materials with the service that installs them.
  List<double> periodValues() {
    final out = List<double>.filled(periods, 0);
    for (final s in services) {
      final sh = shares(s.start, s.days);
      for (var k = 0; k < out.length; k++) {
        out[k] += sh[k] * s.total * (1 + servicesBdi);
      }
    }
    for (final m in materials) {
      final s = service(m.taskKey);
      final sh = shares(s?.start ?? 0, s?.days ?? 0);
      for (var k = 0; k < out.length; k++) {
        out[k] += sh[k] * m.total * (1 + materialsBdi);
      }
    }
    return out;
  }
}

/// Hourly cost (project currency) of [res] in [p]: the one typed in the
/// budget settings, else the reference converted from reais.
double budgetHourlyCost(Project p, BudgetResource res) {
  final typed = p.deliverables.budget.rates[res.key];
  if (typed != null) return typed;
  final rate = exchangeRate(catalogPriceCurrency, p.params.currencyCode) ?? 1;
  return res.referenceBrlPerHour * rate;
}

/// The budget of [p]: the services of its construction schedule with their
/// compositions, the free lines of its quote and, with design results
/// [r], the supply of the materials of the bill of materials (and the
/// freight of the quote).
Budget buildBudget(Project p, DesignResults? r, {String Function(String key)? describe}) {
  final s = p.deliverables.budget;
  final resources = {for (final x in budgetResources) x.key: x};
  final costs = {for (final x in budgetResources) x.key: budgetHourlyCost(p, x)};
  final tasks = scheduleTasks(p, p.proposal);
  final services = <BudgetService>[];
  var n = 0;
  for (final task in tasks) {
    n++;
    final crew = budgetCrews[task.key] ?? const <String, int>{};
    final perDay = task.perDay > 0 ? task.perDay : 1.0;
    services.add(
      BudgetService(
        key: task.key,
        code: 'C${n.toString().padLeft(2, '0')}',
        description: describe?.call('works.${task.key}') ?? task.key,
        unit: task.unit,
        quantity: task.quantity,
        inputs: [
          for (final e in crew.entries)
            if (resources[e.key] case final res?) BudgetInput(resource: res, coefficient: e.value * budgetHoursPerDay / perDay, hourlyCost: costs[e.key]!),
        ],
        start: task.start,
        days: task.days,
      ),
    );
  }
  final duration = tasks.fold(0, (a, x) => math.max(a, x.end));
  for (final x in p.proposal.extras) {
    if (x.description.trim().isEmpty && x.total == 0) continue;
    n++;
    services.add(
      BudgetService(
        key: 'extra',
        code: 'C${n.toString().padLeft(2, '0')}',
        description: x.description,
        unit: x.unit,
        quantity: x.quantity,
        inputs: const [],
        unitCost: x.unitPrice,
        start: 0,
        days: duration,
      ),
    );
  }
  String taskFor(String category) {
    for (final k in _materialTask[category] ?? const ['station']) {
      if (tasks.any((x) => x.key == k)) return k;
    }
    return tasks.isEmpty ? '' : tasks.first.key;
  }

  final materials = <BudgetMaterial>[];
  var unpriced = 0;
  if (r != null) {
    for (final l in r.bom) {
      if (l.quantity <= 0) continue;
      if (l.unitCost <= 0) unpriced++;
      materials.add(BudgetMaterial(line: l, taskKey: taskFor(l.category)));
    }
    if (p.proposal.freight > 0) {
      materials.add(
        BudgetMaterial(
          line: BomLine(category: 'proposal.freight', description: describe?.call('proposal.freight') ?? 'freight', unit: 'vb', quantity: 1, unitCost: p.proposal.freight),
          taskKey: tasks.isEmpty ? '' : tasks.first.key,
        ),
      );
    }
  }
  return Budget(
    services: services,
    materials: materials,
    servicesBdi: s.servicesBdi,
    materialsBdi: s.materialsBdi,
    periodDays: math.max(1, s.periodDays),
    durationDays: duration,
    unpriced: unpriced,
    hourlyCosts: {
      for (final sv in services)
        for (final i in sv.inputs) i.resource.key: i.hourlyCost,
    },
  );
}

/// Whether [bdi] (fraction) lies within the reference range [range].
bool bdiWithin(double bdi, (double, double, double) range) => bdi >= range.$1 - 1e-9 && bdi <= range.$3 + 1e-9;

/// The budget as a document: the summary, the budget by items, the
/// compositions, the BDI, the hourly costs and the physical-financial
/// schedule.
TechDocument budgetDocument(Project p, Budget b, ReportLabels labels) {
  final t = labels.t;
  final s = p.deliverables.budget;
  final cur = p.params.currency;
  final m = p.meta;
  String money(double v) => '$cur ${fmt(v, 2)}';
  String pct(double f) => '${fmt(f * 100, 2)} %';
  // ---- budget by items
  final rows = <List<Object>>[];
  for (var i = 0; i < b.services.length; i++) {
    final x = b.services[i];
    rows.add([
      '1.${i + 1}',
      x.code,
      x.description,
      x.unit,
      RNum(x.quantity, x.unit == 'un' ? 0 : 2),
      RNum(x.unitCost, 2),
      RNum(b.servicesBdi * 100, 2),
      RNum(x.unitCost * (1 + b.servicesBdi), 2),
      RNum(x.total * (1 + b.servicesBdi), 2),
    ]);
  }
  rows.add([t('prb.bud.servicesTotal'), '', '', '', '', '', '', '', RNum(b.servicesPrice, 2)]);
  for (var i = 0; i < b.materials.length; i++) {
    final l = b.materials[i].line;
    rows.add([
      '2.${i + 1}',
      l.code,
      l.description,
      l.unit,
      RNum(l.quantity, l.unit == 'm' ? 1 : 0),
      RNum(l.unitCost, 2),
      RNum(b.materialsBdi * 100, 2),
      RNum(l.unitCost * (1 + b.materialsBdi), 2),
      RNum(l.total * (1 + b.materialsBdi), 2),
    ]);
  }
  if (b.materials.isNotEmpty) rows.add([t('prb.bud.materialsTotal'), '', '', '', '', '', '', '', RNum(b.materialsPrice, 2)]);
  rows.add([t('prb.bud.total'), '', '', '', '', '', '', '', RNum(b.total, 2)]);
  final items = ReportTable(
    key: 'budgetItems',
    title: t('prb.bud.items'),
    headers: [
      t('prb.bud.item'),
      t('rep.code'),
      t('rep.description'),
      t('rep.unit'),
      t('rep.quantity'),
      '${t('prb.bud.unitCost')} ($cur)',
      'BDI (%)',
      '${t('rep.unitPrice')} ($cur)',
      '${t('rep.total')} ($cur)',
    ],
    rows: rows,
    warn: [for (final r in rows) r[1] == '' && r[2] == ''],
  );
  // ---- compositions
  final comp = <List<Object>>[];
  final compWarn = <bool>[];
  for (final x in b.services.where((x) => x.inputs.isNotEmpty)) {
    comp.add(['${x.code} — ${x.description}', '', '', x.unit, '', '', '']);
    compWarn.add(true);
    for (final i in x.inputs) {
      comp.add(['', t(i.resource.equipment ? 'prb.bud.eq' : 'prb.bud.labour'), t('prb.res.${i.resource.key}'), 'h', RNum(i.coefficient, 4), RNum(i.hourlyCost, 2), RNum(i.cost, 2)]);
      compWarn.add(false);
    }
    comp.add([
      '',
      '',
      t('prb.bud.compTotal', {'u': x.unit}),
      '',
      '',
      '',
      RNum(x.unitCost, 2),
    ]);
    compWarn.add(false);
  }
  final compositions = ReportTable(
    key: 'budgetCompositions',
    title: t('prb.bud.compositions'),
    headers: [t('prb.bud.composition'), t('prb.bud.type'), t('prb.bud.input'), t('rep.unit'), t('prb.bud.coefficient'), '${t('prb.bud.unitCost')} ($cur)', '${t('rep.total')} ($cur)'],
    rows: comp,
    warn: compWarn,
  );
  // ---- BDI
  final bdi = ReportTable(
    key: 'budgetBdi',
    title: t('prb.bud.bdi'),
    headers: [t('prb.bud.component'), '%'],
    rows: [
      [t('prb.bud.ac'), RNum(s.centralAdminPct, 2)],
      [t('prb.bud.sg'), RNum(s.insuranceGuaranteePct, 2)],
      [t('prb.bud.risk'), RNum(s.riskPct, 2)],
      [t('prb.bud.df'), RNum(s.financialPct, 2)],
      [t('prb.bud.profit'), RNum(s.profitPct, 2)],
      ['PIS', RNum(s.pisPct, 2)],
      ['COFINS', RNum(s.cofinsPct, 2)],
      ['ISS', RNum(s.issPct, 2)],
      [t('prb.bud.cprb'), RNum(s.cprbPct, 2)],
      [t('prb.bud.servicesBdi'), RNum(b.servicesBdi * 100, 2)],
      [t('prb.bud.materialsBdi'), RNum(b.materialsBdi * 100, 2)],
    ],
    warn: [for (var i = 0; i < 9; i++) false, !bdiWithin(b.servicesBdi, bdiReferenceRanges.services), !bdiWithin(b.materialsBdi, bdiReferenceRanges.materials)],
  );
  // ---- hourly costs
  final res = ReportTable(
    key: 'budgetResources',
    title: t('prb.bud.resources'),
    headers: [t('prb.bud.input'), t('prb.bud.type'), '${t('prb.bud.hourly')} ($cur/h)', t('prb.bud.origin')],
    rows: [
      for (final x in budgetResources)
        if (b.hourlyCosts.containsKey(x.key))
          [t('prb.res.${x.key}'), t(x.equipment ? 'prb.bud.eq' : 'prb.bud.labour'), RNum(b.hourlyCosts[x.key]!, 2), s.rates.containsKey(x.key) ? t('prb.bud.typed') : t('prb.bud.reference')],
    ],
  );
  // ---- physical-financial schedule
  final n = b.periods;
  final values = b.periodValues();
  final schedRows = <List<Object>>[];
  for (final x in b.services) {
    final sh = b.shares(x.start, x.days);
    final price = x.total * (1 + b.servicesBdi);
    schedRows.add([x.description, RNum(price, 2), for (var k = 0; k < n; k++) sh[k] > 0 ? '${fmt(sh[k] * 100, 0)} % · ${fmt(sh[k] * price, 2)}' : '']);
  }
  final byTask = <String, double>{};
  for (final mt in b.materials) {
    byTask[mt.taskKey] = (byTask[mt.taskKey] ?? 0) + mt.total * (1 + b.materialsBdi);
  }
  for (final e in byTask.entries) {
    final sv = b.service(e.key);
    final sh = b.shares(sv?.start ?? 0, sv?.days ?? 0);
    schedRows.add([
      '${t('prb.bud.materialsOf')} ${sv?.description ?? ''}'.trim(),
      RNum(e.value, 2),
      for (var k = 0; k < n; k++) sh[k] > 0 ? '${fmt(sh[k] * 100, 0)} % · ${fmt(sh[k] * e.value, 2)}' : '',
    ]);
  }
  final total = values.fold(0.0, (a, v) => a + v);
  var acc = 0.0;
  final accRow = <Object>[];
  for (final v in values) {
    acc += v;
    accRow.add(RNum(acc, 2));
  }
  schedRows
    ..add([t('prb.bud.periodTotal'), RNum(total, 2), for (final v in values) RNum(v, 2)])
    ..add([t('prb.bud.periodPct'), RNum(100, 0), for (final v in values) RNum(total > 0 ? v / total * 100 : 0, 1)])
    ..add([t('prb.bud.accumulated'), '', ...accRow]);
  final schedule = ReportTable(
    key: 'budgetSchedule',
    title: t('prb.bud.schedule'),
    headers: [
      t('prb.bud.item'),
      '${t('rep.total')} ($cur)',
      for (var k = 1; k <= n; k++) t('prb.bud.period', {'n': '$k'}),
    ],
    rows: schedRows,
    warn: [for (var i = 0; i < schedRows.length; i++) i >= schedRows.length - 3],
  );
  return TechDocument(
    key: 'budget',
    title: t('prb.bud.title'),
    subtitle: [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].where((x) => x.isNotEmpty).join(' · '),
    landscape: true,
    sections: [
      TechSection(t('prb.bud.summary'), [
        TechFields([
          (t('prb.bud.directServices'), money(b.directServices)),
          (t('prb.bud.servicesBdi'), pct(b.servicesBdi)),
          (t('prb.bud.servicesPrice'), money(b.servicesPrice)),
          (t('prb.bud.directMaterials'), money(b.directMaterials)),
          (t('prb.bud.materialsBdi'), pct(b.materialsBdi)),
          (t('prb.bud.materialsPrice'), money(b.materialsPrice)),
          (t('prb.bud.total'), money(b.total)),
          (t('prb.bud.duration'), t('works.daysN', {'n': '${b.durationDays}'})),
        ]),
        if (b.materials.isEmpty) TechNote(t('prb.bud.noMaterials'), warning: true),
        if (b.unpriced > 0) TechNote(t('proposal.unpriced', {'n': '${b.unpriced}'}), warning: true),
      ], key: 'summary'),
      TechSection(t('prb.bud.items'), [TechTable(items)], key: 'items'),
      TechSection(t('prb.bud.compositions'), [
        TechParagraph(t('prb.bud.compositionsText', {'h': fmt(budgetHoursPerDay, 0)})),
        TechTable(compositions),
      ], key: 'compositions'),
      TechSection(t('prb.bud.bdi'), [
        TechFormula(
          t('prb.f.bdiExpr'),
          where: [('AC', t('prb.bud.ac')), ('S + G', t('prb.bud.sg')), ('R', t('prb.bud.risk')), ('DF', t('prb.bud.df')), ('L', t('prb.bud.profit')), ('I', t('prb.bud.taxes'))],
          source: t('prb.src.tcu'),
        ),
        TechTable(bdi),
        TechParagraph(
          t('prb.bud.bdiRange', {
            'a': fmt(bdiReferenceRanges.services.$1 * 100, 2),
            'b': fmt(bdiReferenceRanges.services.$2 * 100, 2),
            'c': fmt(bdiReferenceRanges.services.$3 * 100, 2),
            'd': fmt(bdiReferenceRanges.materials.$1 * 100, 2),
            'e': fmt(bdiReferenceRanges.materials.$2 * 100, 2),
            'f': fmt(bdiReferenceRanges.materials.$3 * 100, 2),
          }),
        ),
      ], key: 'bdi'),
      TechSection(t('prb.bud.resources'), [TechTable(res), TechNote(t('prb.bud.resourcesNote'))], key: 'resources'),
      TechSection(t('prb.bud.schedule'), [
        TechParagraph(t('prb.bud.scheduleText', {'d': '${b.periodDays}', 'n': '$n'})),
        TechTable(schedule),
      ], key: 'schedule'),
    ],
  );
}
