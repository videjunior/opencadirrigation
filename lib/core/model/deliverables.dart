/// Settings of the technical documents built from the project (1.6.0): the
/// water-use permit table of every water source with its self-monitoring
/// sheet (design/permit.dart), the descriptive and calculation memorial
/// (design/memorial.dart), the operation and maintenance plan
/// (design/om_plan.dart), the budget by compositions with its BDI and
/// physical-financial schedule (design/budget.dart) and the life-cycle cost
/// of the alternatives (design/life_cycle.dart).
///
/// Stored in the project file under `deliverables`, and only what differs
/// from a new project (a file that never used them does not change); the
/// fields of a newer version are kept as read and written back.
library;

import 'read_report.dart';

double _num(Object? v, double def) => v is num && v.isFinite ? v.toDouble() : def;

String _str(Object? v, [String def = '']) => v is String ? v : def;

/// Positive numbers of a JSON object by key (anything else dropped).
Map<String, double> _numbers(Object? v) => {
  if (v is Map)
    for (final e in v.entries)
      if (e.key is String && e.value is num && (e.value as num).isFinite && (e.value as num) >= 0) e.key as String: (e.value as num).toDouble(),
};

/// What the permit of one water source says about it, beyond the drawing:
/// the kind of source, the water body it takes from, its basin, the
/// municipality, the register and permit numbers and whether it is a
/// project or in operation (the fields of the permit forms of the water
/// agencies).
class SourcePermitInfo {
  SourcePermitInfo({this.kind = 'surface', this.waterBody = '', this.basin = '', this.municipality = '', this.registry = '', this.permitNumber = '', this.status = 'project'});

  /// `surface` (river, stream, reservoir) or `groundwater` (well).
  String kind;

  /// Water body (river, stream, reservoir, aquifer of a well).
  String waterBody;

  /// River basin or water-management unit.
  String basin;

  /// Municipality and state.
  String municipality;

  /// Number in the national register of water users (CNARH in Brazil) or in
  /// the state register.
  String registry;

  /// Number of the permit, or of its application.
  String permitNumber;

  /// `project` (to be built) or `operation`.
  String status;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  static const kinds = ['surface', 'groundwater'];
  static const statuses = ['project', 'operation'];

  bool get isDefault => kind == 'surface' && waterBody.isEmpty && basin.isEmpty && municipality.isEmpty && registry.isEmpty && permitNumber.isEmpty && status == 'project' && (extra?.isEmpty ?? true);

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (kind != 'surface') 'kind': kind,
    if (waterBody.isNotEmpty) 'body': waterBody,
    if (basin.isNotEmpty) 'basin': basin,
    if (municipality.isNotEmpty) 'city': municipality,
    if (registry.isNotEmpty) 'reg': registry,
    if (permitNumber.isNotEmpty) 'permit': permitNumber,
    if (status != 'project') 'status': status,
  };

  static SourcePermitInfo fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final kind = _str(j['kind'], 'surface');
    final status = _str(j['status'], 'project');
    return SourcePermitInfo(
      kind: kinds.contains(kind) ? kind : 'surface',
      waterBody: _str(j['body']),
      basin: _str(j['basin']),
      municipality: _str(j['city']),
      registry: _str(j['reg']),
      permitNumber: _str(j['permit']),
      status: statuses.contains(status) ? status : 'project',
    )..extra = j.unread;
  }
}

/// How the permit table sets the operating regime of every month, and the
/// checks it makes.
class PermitSettings {
  PermitSettings({Map<String, SourcePermitInfo>? sources, this.fixedHoursPerDay = 0, this.maxHoursPerDay = 21, this.federalFloor = false, this.monitoringUnit = ''}) : sources = sources ?? {};

  /// The permit data of each water source, by entity id.
  final Map<String, SourcePermitInfo> sources;

  /// Pumping hours a day written in every month (the days of the month then
  /// follow from the volume); 0 = the days of the month with irrigation and
  /// the hours they need.
  double fixedHoursPerDay;

  /// Most pumping hours a day the installed flow may need in the month of
  /// highest demand (21 h: the day without the 3 h of the peak tariff).
  double maxHoursPerDay;

  /// The floor of 300 m³ per hectare of the months with irrigation of the
  /// federal electronic processing (Resolution ANA 1.939/2017, Annex I).
  bool federalFloor;

  /// Key of the management unit of the self-monitoring thresholds of
  /// Resolution ANA 188/2024, Annex I ('' = the other federal and the state
  /// units).
  String monitoringUnit;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  /// The permit data of [supplyId], created when missing.
  SourcePermitInfo source(String supplyId) => sources.putIfAbsent(supplyId, SourcePermitInfo.new);

  bool get isDefault => sources.values.every((s) => s.isDefault) && fixedHoursPerDay == 0 && maxHoursPerDay == 21 && !federalFloor && monitoringUnit.isEmpty && (extra?.isEmpty ?? true);

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (sources.values.any((s) => !s.isDefault))
      'sources': {
        for (final e in sources.entries)
          if (!e.value.isDefault) e.key: e.value.toJson(),
      },
    if (fixedHoursPerDay != 0) 'hours': fixedHoursPerDay,
    if (maxHoursPerDay != 21) 'maxHours': maxHoursPerDay,
    if (federalFloor) 'floor': true,
    if (monitoringUnit.isNotEmpty) 'unit': monitoringUnit,
  };

  static PermitSettings fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final s = j['sources'];
    return PermitSettings(
      sources: {
        if (s is Map)
          for (final e in s.entries)
            if (e.key is String && e.value is Map) e.key as String: SourcePermitInfo.fromJson((e.value as Map).cast<String, dynamic>()),
      },
      fixedHoursPerDay: _num(j['hours'], 0).clamp(0, 24).toDouble(),
      maxHoursPerDay: _num(j['maxHours'], 21).clamp(1, 24).toDouble(),
      federalFloor: j['floor'] == true,
      monitoringUnit: _str(j['unit']),
    )..extra = j.unread;
  }
}

/// The texts the designer adds to the memorial (the rest comes from the
/// project).
class MemorialSettings {
  MemorialSettings({this.objective = '', this.notes = ''});

  /// Objective and scope, written before the generated one.
  String objective;

  /// Remarks closing the memorial (conditions, assumptions).
  String notes;

  Map<String, dynamic>? extra;

  bool get isDefault => objective.isEmpty && notes.isEmpty && (extra?.isEmpty ?? true);

  Map<String, dynamic> toJson() => {...?extra, if (objective.isNotEmpty) 'objective': objective, if (notes.isNotEmpty) 'notes': notes};

  static MemorialSettings fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    return MemorialSettings(objective: _str(j['objective']), notes: _str(j['notes']))..extra = j.unread;
  }
}

/// Figures of the operation and maintenance plan the project does not
/// hold.
class OmSettings {
  OmSettings({this.filterDeltaM = 5, this.chlorineProductPct = 10, this.chlorineContinuousMgL = 1, this.chlorineShockMgL = 10, this.sparesPct = 2});

  /// Rise of the pressure loss of a filter over its clean loss (m) that
  /// calls for its cleaning or backwash (5 m = 0.5 bar).
  double filterDeltaM;

  /// Available chlorine of the product injected (%, sodium hypochlorite).
  double chlorineProductPct;

  /// Free chlorine at the far end of the system: continuous treatment and
  /// shock treatment (mg/L).
  double chlorineContinuousMgL;
  double chlorineShockMgL;

  /// Share of the emitters, laterals and small parts kept as spares (%).
  double sparesPct;

  Map<String, dynamic>? extra;

  bool get isDefault => filterDeltaM == 5 && chlorineProductPct == 10 && chlorineContinuousMgL == 1 && chlorineShockMgL == 10 && sparesPct == 2 && (extra?.isEmpty ?? true);

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (filterDeltaM != 5) 'filterDp': filterDeltaM,
    if (chlorineProductPct != 10) 'clProduct': chlorineProductPct,
    if (chlorineContinuousMgL != 1) 'clCont': chlorineContinuousMgL,
    if (chlorineShockMgL != 10) 'clShock': chlorineShockMgL,
    if (sparesPct != 2) 'spares': sparesPct,
  };

  static OmSettings fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    return OmSettings(
      filterDeltaM: _num(j['filterDp'], 5).clamp(0.1, 50).toDouble(),
      chlorineProductPct: _num(j['clProduct'], 10).clamp(0.1, 100).toDouble(),
      chlorineContinuousMgL: _num(j['clCont'], 1).clamp(0, 100).toDouble(),
      chlorineShockMgL: _num(j['clShock'], 10).clamp(0, 500).toDouble(),
      sparesPct: _num(j['spares'], 2).clamp(0, 100).toDouble(),
    )..extra = j.unread;
  }
}

/// Rates of the budget by compositions: the parts of the BDI (indirect
/// costs and profit over the direct cost) of the services and the BDI of
/// the supply of materials, the hourly costs of labour and equipment where
/// they differ from the reference ones, and the period of the schedule.
/// The default rates are the first quartile of Brazilian Federal Court of
/// Accounts ruling (Acórdão TCU) 2622/2013 for water-supply networks,
/// sewerage and related works (central administration 3.43 %, insurance and
/// guarantee 0.28 %, risk 1.00 %, financial costs 0.94 %, profit 6.74 %;
/// supply of materials and equipment 11.10 %), with PIS 0.65 %, COFINS
/// 3.00 % and a municipal ISS of 3.00 %.
class BudgetSettings {
  BudgetSettings({
    this.centralAdminPct = 3.43,
    this.insuranceGuaranteePct = 0.28,
    this.riskPct = 1.00,
    this.financialPct = 0.94,
    this.profitPct = 6.74,
    this.pisPct = 0.65,
    this.cofinsPct = 3.00,
    this.issPct = 3.00,
    this.cprbPct = 0,
    this.materialsBdiPct = 11.10,
    Map<String, double>? rates,
    this.periodDays = 22,
  }) : rates = rates ?? {};

  /// Indirect costs (% of the direct cost): central administration,
  /// insurance and guarantee, risk; financial costs; profit.
  double centralAdminPct;
  double insuranceGuaranteePct;
  double riskPct;
  double financialPct;
  double profitPct;

  /// Taxes on the price (%): PIS, COFINS, municipal ISS and the payroll
  /// contribution on revenue (CPRB) of companies under the payroll relief of
  /// Law 13.161/2015 (0 when not under it).
  double pisPct;
  double cofinsPct;
  double issPct;
  double cprbPct;

  /// BDI of the supply of materials and equipment (%); a negative value
  /// applies the BDI of the services to them too.
  double materialsBdiPct;

  /// Hourly cost of a labour category or a piece of equipment (key of
  /// `budget.dart` → project currency per hour), where it differs from the
  /// reference.
  final Map<String, double> rates;

  /// Working days of a period of the physical-financial schedule (22 ≈ a
  /// month, 5 = a week).
  int periodDays;

  Map<String, dynamic>? extra;

  /// Total of the taxes on the price (fraction).
  double get taxes => (pisPct + cofinsPct + issPct + cprbPct) / 100;

  /// BDI of the services (fraction): ((1 + AC + S + G + R)(1 + DF)(1 + L) /
  /// (1 − I)) − 1, the formula of Acórdão TCU 2622/2013.
  double get servicesBdi {
    final i = taxes.clamp(0.0, 0.9);
    return (1 + (centralAdminPct + insuranceGuaranteePct + riskPct) / 100) * (1 + financialPct / 100) * (1 + profitPct / 100) / (1 - i) - 1;
  }

  /// BDI of the supply of materials and equipment (fraction).
  double get materialsBdi => materialsBdiPct < 0 ? servicesBdi : materialsBdiPct / 100;

  bool get isDefault =>
      centralAdminPct == 3.43 &&
      insuranceGuaranteePct == 0.28 &&
      riskPct == 1.00 &&
      financialPct == 0.94 &&
      profitPct == 6.74 &&
      pisPct == 0.65 &&
      cofinsPct == 3.00 &&
      issPct == 3.00 &&
      cprbPct == 0 &&
      materialsBdiPct == 11.10 &&
      rates.isEmpty &&
      periodDays == 22 &&
      (extra?.isEmpty ?? true);

  /// Multiplies the hourly costs typed by [factor] (currency conversion).
  void scalePrices(double factor) => rates.updateAll((_, v) => v * factor);

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (centralAdminPct != 3.43) 'ac': centralAdminPct,
    if (insuranceGuaranteePct != 0.28) 'sg': insuranceGuaranteePct,
    if (riskPct != 1.00) 'risk': riskPct,
    if (financialPct != 0.94) 'df': financialPct,
    if (profitPct != 6.74) 'profit': profitPct,
    if (pisPct != 0.65) 'pis': pisPct,
    if (cofinsPct != 3.00) 'cofins': cofinsPct,
    if (issPct != 3.00) 'iss': issPct,
    if (cprbPct != 0) 'cprb': cprbPct,
    if (materialsBdiPct != 11.10) 'matBdi': materialsBdiPct,
    if (rates.isNotEmpty) 'rates': rates,
    if (periodDays != 22) 'period': periodDays,
  };

  static BudgetSettings fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    double pct(String k, double def) => _num(j[k], def).clamp(0, 100).toDouble();
    return BudgetSettings(
      centralAdminPct: pct('ac', 3.43),
      insuranceGuaranteePct: pct('sg', 0.28),
      riskPct: pct('risk', 1.00),
      financialPct: pct('df', 0.94),
      profitPct: pct('profit', 6.74),
      pisPct: pct('pis', 0.65),
      cofinsPct: pct('cofins', 3.00),
      issPct: pct('iss', 3.00),
      cprbPct: pct('cprb', 0),
      materialsBdiPct: _num(j['matBdi'], 11.10).clamp(-1, 100).toDouble(),
      rates: _numbers(j['rates']),
      periodDays: _num(j['period'], 22).round().clamp(1, 260),
    )..extra = j.unread;
  }
}

/// Horizon and rates of the life-cycle cost of the alternatives, and the
/// life and yearly maintenance of each category of the bill of materials
/// where they differ from the reference ones (design/life_cycle.dart).
class LifeCycleSettings {
  LifeCycleSettings({this.years = 20, this.discountPct, this.energyEscalationPct = 0, this.waterPrice = 0, this.residual = true, Map<String, double>? life, Map<String, double>? maintenance})
    : life = life ?? {},
      maintenance = maintenance ?? {};

  /// Years of the study.
  int years;

  /// Discount rate (% a year); null takes the interest rate of the design
  /// parameters.
  double? discountPct;

  /// Yearly rise of the energy price above inflation (%).
  double energyEscalationPct;

  /// Price of the water (bulk water or the charge for its use; project
  /// currency per m³).
  double waterPrice;

  /// Credit the value left in the parts at the end of the study (straight
  /// line over their life).
  bool residual;

  /// Life (years) and yearly maintenance (% of its cost) by category of the
  /// bill of materials (`bom.pipes`…), where they differ from the reference.
  final Map<String, double> life;
  final Map<String, double> maintenance;

  Map<String, dynamic>? extra;

  bool get isDefault => years == 20 && discountPct == null && energyEscalationPct == 0 && waterPrice == 0 && residual && life.isEmpty && maintenance.isEmpty && (extra?.isEmpty ?? true);

  /// Multiplies the water price by [factor] (currency conversion).
  void scalePrices(double factor) => waterPrice *= factor;

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (years != 20) 'years': years,
    'rate': ?discountPct,
    if (energyEscalationPct != 0) 'esc': energyEscalationPct,
    if (waterPrice != 0) 'water': waterPrice,
    if (!residual) 'residual': false,
    if (life.isNotEmpty) 'life': life,
    if (maintenance.isNotEmpty) 'maint': maintenance,
  };

  static LifeCycleSettings fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final rate = j['rate'];
    return LifeCycleSettings(
      years: _num(j['years'], 20).round().clamp(1, 100),
      discountPct: rate is num && rate.isFinite ? rate.toDouble().clamp(0, 100).toDouble() : null,
      energyEscalationPct: _num(j['esc'], 0).clamp(-50, 50).toDouble(),
      waterPrice: _num(j['water'], 0).clamp(0, double.infinity).toDouble(),
      residual: j['residual'] != false,
      life: {
        for (final e in _numbers(j['life']).entries)
          if (e.value >= 1) e.key: e.value,
      },
      maintenance: _numbers(j['maint']),
    )..extra = j.unread;
  }
}

/// Every setting of the technical documents of a project.
class DeliverableSettings {
  DeliverableSettings({PermitSettings? permit, MemorialSettings? memorial, OmSettings? om, BudgetSettings? budget, LifeCycleSettings? lifeCycle})
    : permit = permit ?? PermitSettings(),
      memorial = memorial ?? MemorialSettings(),
      om = om ?? OmSettings(),
      budget = budget ?? BudgetSettings(),
      lifeCycle = lifeCycle ?? LifeCycleSettings();

  PermitSettings permit;
  MemorialSettings memorial;
  OmSettings om;
  BudgetSettings budget;
  LifeCycleSettings lifeCycle;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => permit.isDefault && memorial.isDefault && om.isDefault && budget.isDefault && lifeCycle.isDefault && (extra?.isEmpty ?? true);

  /// Multiplies every amount of money by [factor] (currency conversion):
  /// the hourly costs of the budget and the price of the water.
  void scalePrices(double factor) {
    if (factor == 1) return;
    budget.scalePrices(factor);
    lifeCycle.scalePrices(factor);
  }

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (!permit.isDefault) 'permit': permit.toJson(),
    if (!memorial.isDefault) 'memorial': memorial.toJson(),
    if (!om.isDefault) 'om': om.toJson(),
    if (!budget.isDefault) 'budget': budget.toJson(),
    if (!lifeCycle.isDefault) 'lcc': lifeCycle.toJson(),
  };

  /// Reads the settings; a section that cannot be read takes the defaults
  /// (and is kept in [extra] as it was).
  static DeliverableSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return DeliverableSettings();
    final j = KeyLog(json);
    final kept = <String, dynamic>{};
    T section<T>(String key, T Function(Map<String, dynamic>) read, T Function() def) {
      final v = j[key];
      if (v == null) return def();
      if (v is Map) {
        try {
          return read(v.cast<String, dynamic>());
        } catch (_) {
          // damaged: the defaults, the section kept below
        }
      }
      kept[key] = v;
      return def();
    }

    final d = DeliverableSettings(
      permit: section('permit', PermitSettings.fromJson, PermitSettings.new),
      memorial: section('memorial', MemorialSettings.fromJson, MemorialSettings.new),
      om: section('om', OmSettings.fromJson, OmSettings.new),
      budget: section('budget', BudgetSettings.fromJson, BudgetSettings.new),
      lifeCycle: section('lcc', LifeCycleSettings.fromJson, LifeCycleSettings.new),
    );
    final unread = {...?j.unread, ...kept};
    return d..extra = unread.isEmpty ? null : unread;
  }
}
