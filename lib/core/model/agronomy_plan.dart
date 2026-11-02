/// Agronomy settings kept in the project (1.6.0): the user's own crops
/// (crops the FAO-56 table does not have, with their stages), the settings
/// of the controller programme (irrigation window, cycle and soak, seasonal
/// adjustment), the daily soil water balance and the fertigation by crop
/// stage of each irrigated area, and the field evaluations of uniformity
/// (catch cans or emitter flows measured on site).
///
/// Every part is written only when it differs from a new project's, so an
/// older file reads and writes back unchanged; fields a newer version adds
/// are kept as read ([KeyLog]).
library;

import 'dart:math' as math;

import '../design/crops.dart';
import 'geometry.dart';
import 'read_report.dart';

double _d(Object? v, double fallback) => v is num && v.isFinite ? v.toDouble() : fallback;
int _i(Object? v, int fallback) => v is num && v.isFinite ? v.toInt() : fallback;
String _s(Object? v, [String fallback = '']) => v is String ? v : fallback;
bool _b(Object? v, bool fallback) => v is bool ? v : fallback;
List<double>? _doubles(Object? v, {int? length}) {
  if (v is! List || (length != null && v.length != length)) return null;
  return [for (final x in v) x is num && x.isFinite ? x.toDouble() : 0.0];
}

Map<String, dynamic>? _map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

// ---------------------------------------------------------------- user crops

/// A crop the FAO-56 table does not have (passion fruit, papaya, acerola,
/// guava, açaí, cocoa, black pepper, eucalyptus, rubber…), typed by the
/// designer with the single crop coefficient curve of FAO-56 (Kc ini, Kc
/// mid, Kc end and the four stage lengths, eq. 66), the root depth and the
/// depletion fraction for irrigation scheduling, and, when known, the
/// maximum height (Kc climatic adjustment, eqs. 62 and 65), the salt
/// tolerance (FAO-29 Table 4 style: ECe at 100 % and at zero yield) and
/// the seasonal yield response factor Ky (FAO-33). [source] says where the
/// values come from (a local study, an extension bulletin), as a water
/// permit asks.
class UserCrop {
  UserCrop({
    required this.id,
    required this.name,
    this.kcIni = 0.6,
    this.kcMid = 1.0,
    this.kcEnd = 0.8,
    this.initialDays = 30,
    this.developmentDays = 40,
    this.midDays = 60,
    this.lateDays = 30,
    this.plantingMonth = 1,
    this.rootDepthM = 0.6,
    this.depletionFraction = 0.5,
    this.maxHeightM = 0,
    this.perennial = false,
    this.eceThreshold = 0,
    this.eceMax = 0,
    this.ky = 0,
    this.source = '',
  });

  /// Short identifier, unique in the project (letters, digits, `_`, `-`).
  String id;
  String name;
  double kcIni, kcMid, kcEnd;

  /// Stage lengths (days); all zero = evergreen (Kc mid all year).
  double initialDays, developmentDays, midDays, lateDays;

  /// Usual planting (or green-up) month, 1–12, when the area gives no date.
  int plantingMonth;
  double rootDepthM;
  double depletionFraction;

  /// Maximum crop height (m); 0 = unknown (no climatic adjustment of Kc).
  double maxHeightM;
  bool perennial;

  /// Soil salinity ECe (dS/m) at 100 % and at zero yield; 0 = unknown.
  double eceThreshold, eceMax;

  /// Seasonal yield response factor (FAO-33); 0 = unknown.
  double ky;
  String source;
  Map<String, dynamic>? extra;

  /// Crop key of the areas that use it (`user.<id>`).
  String get key => '$userCropPrefix$id';

  double get seasonDays => initialDays + developmentDays + midDays + lateDays;

  /// The crop as a row of the crop table (not tabulated by FAO-56).
  CropData toCropData() => CropData(
    key: key,
    kcIni: kcIni.clamp(0.0, 2.0).toDouble(),
    kcMid: kcMid.clamp(0.0, 2.0).toDouble(),
    kcEnd: kcEnd.clamp(0.0, 2.0).toDouble(),
    maxHeightM: maxHeightM > 0 ? maxHeightM : null,
    stages: seasonDays > 0 ? CropStages(initialDays.clamp(0, 400).toDouble(), developmentDays.clamp(0, 400).toDouble(), midDays.clamp(0, 400).toDouble(), lateDays.clamp(0, 400).toDouble()) : null,
    plantingMonth: plantingMonth.clamp(1, 12),
    rootDepthMinM: rootDepthM > 0 ? rootDepthM : null,
    rootDepthMaxM: rootDepthM > 0 ? rootDepthM : null,
    depletionFraction: depletionFraction > 0 ? depletionFraction.clamp(0.05, 0.95).toDouble() : null,
    eceThreshold: eceThreshold > 0 ? eceThreshold : null,
    eceMax: eceMax > eceThreshold && eceThreshold > 0 ? eceMax : null,
    perennial: perennial,
    tabulated: false,
  );

  UserCrop copy() => UserCrop(
    id: id,
    name: name,
    kcIni: kcIni,
    kcMid: kcMid,
    kcEnd: kcEnd,
    initialDays: initialDays,
    developmentDays: developmentDays,
    midDays: midDays,
    lateDays: lateDays,
    plantingMonth: plantingMonth,
    rootDepthM: rootDepthM,
    depletionFraction: depletionFraction,
    maxHeightM: maxHeightM,
    perennial: perennial,
    eceThreshold: eceThreshold,
    eceMax: eceMax,
    ky: ky,
    source: source,
  )..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'kc': [kcIni, kcMid, kcEnd],
    'days': [initialDays, developmentDays, midDays, lateDays],
    'pm': plantingMonth,
    'zr': rootDepthM,
    'p': depletionFraction,
    if (maxHeightM > 0) 'h': maxHeightM,
    if (perennial) 'per': true,
    if (eceThreshold > 0) 'ece': [eceThreshold, eceMax],
    if (ky > 0) 'ky': ky,
    if (source.isNotEmpty) 'src': source,
  };

  static UserCrop fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final kc = _doubles(j['kc'], length: 3) ?? const [0.6, 1.0, 0.8];
    final days = _doubles(j['days'], length: 4) ?? const [30.0, 40.0, 60.0, 30.0];
    final ece = _doubles(j['ece'], length: 2) ?? const [0.0, 0.0];
    final id = _s(j['id']);
    if (!validUserCropId(id)) throw const FormatException('user_crop_id');
    return UserCrop(
      id: id,
      name: _s(j['name'], id),
      kcIni: kc[0],
      kcMid: kc[1],
      kcEnd: kc[2],
      initialDays: days[0],
      developmentDays: days[1],
      midDays: days[2],
      lateDays: days[3],
      plantingMonth: _i(j['pm'], 1).clamp(1, 12),
      rootDepthM: _d(j['zr'], 0.6),
      depletionFraction: _d(j['p'], 0.5),
      maxHeightM: _d(j['h'], 0),
      perennial: _b(j['per'], false),
      eceThreshold: ece[0],
      eceMax: ece[1],
      ky: _d(j['ky'], 0),
      source: _s(j['src']),
    )..extra = j.unread;
  }
}

/// Prefix of the crop keys of the user's crops.
const userCropPrefix = 'user.';

/// Whether [id] can name a user crop.
bool validUserCropId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(id);

/// A free identifier for a crop named [name] among [taken] ids.
String userCropIdFor(String name, Iterable<String> taken) {
  final used = taken.toSet();
  const accents = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n'};
  var base = name.toLowerCase().split('').map((c) => accents[c] ?? c).join().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (base.isEmpty) base = 'crop';
  if (base.length > 32) base = base.substring(0, 32);
  var id = base;
  for (var k = 2; used.contains(id); k++) {
    id = '${base}_$k';
  }
  return id;
}

// ---------------------------------------------------------------- programme

/// Settings of the controller programme: the daily irrigation window the
/// system flows must fit in (also the operating hours the design check
/// compares the peak demand with), cycle and soak for the sprinkler zones
/// whose rate the soil does not take, and the seasonal adjustment.
class ProgrammeSettings {
  ProgrammeSettings({this.windowStartHour = 6, this.windowHours = 24, this.cycleSoak = false, this.minCycleMinutes = 5, this.maxCycles = 6, this.seasonalPct, this.inReports = false});

  /// Hour the irrigation window opens (0–24) and its length (hours, 1–24;
  /// 24 = the whole day, no window).
  double windowStartHour;
  double windowHours;

  /// Split every event of a zone whose application rate runs off into
  /// cycles with soak pauses (the controller's cycle and soak).
  bool cycleSoak;

  /// Shortest cycle a controller is set to (minutes) and the most cycles of
  /// one event.
  double minCycleMinutes;
  int maxCycles;

  /// Seasonal adjustment (% of the run times of the design month) of every
  /// month, January first; null = from the monthly requirement of the
  /// areas.
  List<double>? seasonalPct;

  /// Put the programme by station and month and the runs in the reports
  /// (CSV, XLSX, PDF).
  bool inReports;
  Map<String, dynamic>? extra;

  /// Hours the irrigation window holds (1–24).
  double get effectiveWindowHours => windowHours.clamp(1.0, 24.0).toDouble();

  bool get isDefault => windowStartHour == 6 && windowHours == 24 && !cycleSoak && minCycleMinutes == 5 && maxCycles == 6 && seasonalPct == null && !inReports && (extra?.isEmpty ?? true);

  ProgrammeSettings copy() => ProgrammeSettings(
    windowStartHour: windowStartHour,
    windowHours: windowHours,
    cycleSoak: cycleSoak,
    minCycleMinutes: minCycleMinutes,
    maxCycles: maxCycles,
    seasonalPct: seasonalPct == null ? null : List.of(seasonalPct!),
    inReports: inReports,
  )..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (windowStartHour != 6) 'start': windowStartHour,
    if (windowHours != 24) 'hours': windowHours,
    if (cycleSoak) 'cs': true,
    if (minCycleMinutes != 5) 'minCycle': minCycleMinutes,
    if (maxCycles != 6) 'maxCycles': maxCycles,
    'season': ?seasonalPct,
    if (inReports) 'reports': true,
  };

  static ProgrammeSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProgrammeSettings();
    final j = KeyLog(json);
    return ProgrammeSettings(
      windowStartHour: _d(j['start'], 6).clamp(0.0, 24.0).toDouble(),
      windowHours: _d(j['hours'], 24).clamp(1.0, 24.0).toDouble(),
      cycleSoak: _b(j['cs'], false),
      minCycleMinutes: _d(j['minCycle'], 5).clamp(1.0, 120.0).toDouble(),
      maxCycles: _i(j['maxCycles'], 6).clamp(1, 24),
      seasonalPct: _doubles(j['season'], length: 12),
      inReports: _b(j['reports'], false),
    )..extra = j.unread;
  }
}

// ---------------------------------------------------------------- daily water balance

/// When the daily soil water balance of an area irrigates.
enum BalanceTrigger {
  /// When the depletion reaches the allowed depletion of the stage (the
  /// readily available water unless a deficit is set).
  depletion,

  /// Every [BalanceSettings.intervalDays] days, refilling the root zone.
  interval,

  /// Never (rain only): the stress the crop would suffer.
  rainfed,
}

/// Settings of the daily soil water balance of one irrigated area.
class BalanceSettings {
  BalanceSettings({
    this.trigger = BalanceTrigger.depletion,
    this.intervalDays = 3,
    List<double>? allowedDepletion,
    this.refillPct = 100,
    this.initialDepletionPct = 0,
    this.rainEventsPerMonth = 4,
    this.year = 0,
    this.ky = 0,
  }) : allowedDepletion = allowedDepletion ?? [0, 0, 0, 0];

  BalanceTrigger trigger;
  int intervalDays;

  /// Depletion allowed before irrigating, as a fraction of the total
  /// available water, in the initial, development, mid-season and late
  /// stages; 0 = the depletion fraction p of the crop (no stress). Above p
  /// the crop is stressed: regulated deficit irrigation.
  final List<double> allowedDepletion;

  /// Share of the depletion every irrigation refills (%).
  double refillPct;

  /// Depletion at the start of the period (% of the total available water).
  double initialDepletionPct;

  /// Typical year from the monthly normals: the rain of each month falls in
  /// this many equal events.
  int rainEventsPerMonth;

  /// Year of the daily series of the site climate; 0 = the typical year of
  /// the monthly normals.
  int year;

  /// Seasonal yield response factor; 0 = the crop's (FAO-33).
  double ky;
  Map<String, dynamic>? extra;

  bool get deficit => allowedDepletion.any((x) => x > 0);

  bool get isDefault =>
      trigger == BalanceTrigger.depletion &&
      intervalDays == 3 &&
      !deficit &&
      refillPct == 100 &&
      initialDepletionPct == 0 &&
      rainEventsPerMonth == 4 &&
      year == 0 &&
      ky == 0 &&
      (extra?.isEmpty ?? true);

  BalanceSettings copy() => BalanceSettings(
    trigger: trigger,
    intervalDays: intervalDays,
    allowedDepletion: List.of(allowedDepletion),
    refillPct: refillPct,
    initialDepletionPct: initialDepletionPct,
    rainEventsPerMonth: rainEventsPerMonth,
    year: year,
    ky: ky,
  )..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (trigger != BalanceTrigger.depletion) 'trigger': trigger.name,
    if (intervalDays != 3) 'every': intervalDays,
    if (deficit) 'mad': allowedDepletion,
    if (refillPct != 100) 'refill': refillPct,
    if (initialDepletionPct != 0) 'dr0': initialDepletionPct,
    if (rainEventsPerMonth != 4) 'rainEvents': rainEventsPerMonth,
    if (year != 0) 'year': year,
    if (ky != 0) 'ky': ky,
  };

  static BalanceSettings fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return BalanceSettings(
      trigger: enumByName(BalanceTrigger.values, j['trigger'] ?? BalanceTrigger.depletion.name, BalanceTrigger.depletion, report: report, key: 'balance.trigger'),
      intervalDays: _i(j['every'], 3).clamp(1, 60),
      allowedDepletion: [for (final x in _doubles(j['mad'], length: 4) ?? const [0.0, 0.0, 0.0, 0.0]) x.clamp(0.0, 0.95).toDouble()],
      refillPct: _d(j['refill'], 100).clamp(10.0, 100.0).toDouble(),
      initialDepletionPct: _d(j['dr0'], 0).clamp(0.0, 100.0).toDouble(),
      rainEventsPerMonth: _i(j['rainEvents'], 4).clamp(1, 31),
      year: _i(j['year'], 0),
      ky: _d(j['ky'], 0).clamp(0.0, 3.0).toDouble(),
    )..extra = j.unread;
  }
}

// ---------------------------------------------------------------- fertigation by stage

/// A fertilizer and its grade: % N, % P₂O₅, % K₂O by weight; [ionic]
/// salts raise the electrical conductivity of the water (urea does not).
class FertProduct {
  const FertProduct({required this.name, this.nPct = 0, this.p2o5Pct = 0, this.k2oPct = 0, this.ionic = true});
  final String name;
  final double nPct, p2o5Pct, k2oPct;
  final bool ionic;

  /// Share (0–1) of nutrient [k] (0 = N, 1 = P₂O₅, 2 = K₂O).
  double share(int k) => (switch (k) {
    0 => nPct,
    1 => p2o5Pct,
    _ => k2oPct,
  }).clamp(0.0, 100.0) / 100;

  Map<String, dynamic> toJson() => {'name': name, 'g': [nPct, p2o5Pct, k2oPct], if (!ionic) 'ionic': false};

  static FertProduct fromJson(Map<String, dynamic> j) {
    final g = _doubles(j['g'], length: 3) ?? const [0.0, 0.0, 0.0];
    return FertProduct(name: _s(j['name']), nPct: g[0], p2o5Pct: g[1], k2oPct: g[2], ionic: _b(j['ionic'], true));
  }
}

/// Fertigation of one irrigated area over its crop cycle: the doses of N,
/// P₂O₅ and K₂O of the cycle (kg/ha), the share given in each growth stage
/// (null = in proportion to the crop's water use in the stage, the Kc
/// curve times ETo), the product that carries each nutrient, every how
/// many irrigations a product is injected and the strength of the stock
/// solution.
class FertigationStagePlan {
  FertigationStagePlan({List<double>? doseKgHa, this.sharePct, List<FertProduct>? products, this.everyNth = 1, this.stockKgPerL = 0.25, this.injectionPct = 50})
    : doseKgHa = doseKgHa ?? [0, 0, 0],
      products = products ?? List.of(defaultFertProducts);

  /// N, P₂O₅ and K₂O for the cycle (kg/ha).
  final List<double> doseKgHa;

  /// Share of each nutrient (%) in the initial, development, mid-season and
  /// late stages: 4 rows of N, P₂O₅, K₂O; null = by the water use.
  List<List<double>>? sharePct;

  /// The product of N, of P₂O₅ and of K₂O (three entries).
  final List<FertProduct> products;
  int everyNth;
  double stockKgPerL;

  /// Share of the event's run time the product is injected in (the rest
  /// wets the soil before and flushes the pipes after, fertigation.dart).
  double injectionPct;
  Map<String, dynamic>? extra;

  bool get isEmpty => doseKgHa.every((d) => d <= 0);

  FertigationStagePlan copy() => FertigationStagePlan(
    doseKgHa: List.of(doseKgHa),
    sharePct: sharePct == null ? null : [for (final r in sharePct!) List.of(r)],
    products: List.of(products),
    everyNth: everyNth,
    stockKgPerL: stockKgPerL,
    injectionPct: injectionPct,
  )..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'dose': doseKgHa,
    'share': ?sharePct,
    'products': [for (final p in products) p.toJson()],
    if (everyNth != 1) 'every': everyNth,
    if (stockKgPerL != 0.25) 'stock': stockKgPerL,
    if (injectionPct != 50) 'inject': injectionPct,
  };

  static FertigationStagePlan fromJson(Map<String, dynamic> json) {
    final j = KeyLog(json);
    final share = j['share'];
    List<List<double>>? rows;
    if (share is List && share.length == 4) {
      rows = [for (final r in share) _doubles(r, length: 3) ?? const [25.0, 25.0, 25.0]];
    }
    final prods = j['products'];
    return FertigationStagePlan(
      doseKgHa: [for (final x in _doubles(j['dose'], length: 3) ?? const [0.0, 0.0, 0.0]) x.clamp(0.0, 5000.0).toDouble()],
      sharePct: rows,
      products: prods is List && prods.length == 3 ? [for (final p in prods) FertProduct.fromJson(_map(p) ?? const {})] : null,
      everyNth: _i(j['every'], 1).clamp(1, 30),
      stockKgPerL: _d(j['stock'], 0.25).clamp(0.01, 2.0).toDouble(),
      injectionPct: _d(j['inject'], 50).clamp(5.0, 100.0).toDouble(),
    )..extra = j.unread;
  }
}

/// Common fertilizers for N, P₂O₅ and K₂O, by their usual grades: urea
/// (45-0-0, a non-electrolyte), monoammonium phosphate (11-52-0) and
/// potassium chloride (0-0-60). Grades vary with the maker: the label wins.
const defaultFertProducts = [
  FertProduct(name: 'urea', nPct: 45, ionic: false),
  FertProduct(name: 'map', nPct: 11, p2o5Pct: 52),
  FertProduct(name: 'kcl', k2oPct: 60),
];

// ---------------------------------------------------------------- field evaluation

/// What a field evaluation measured.
enum FieldTestKind {
  /// Catch cans on a grid under the sprinklers (water caught, mL).
  cans,

  /// Emitter flows (L/h) sampled in a drip or micro-sprinkler zone.
  emitters,
}

/// A field evaluation of uniformity: catch cans laid on a grid of [cols]
/// columns from [origin] (the first can) every [spacingXM] along x and
/// [spacingYM] along y, rotated by [angleDeg], read after [durationH]
/// hours, with mouths [canMouthMm] wide; or emitter flows measured in a
/// zone. [values] are row by row (null = a can that was lost).
class FieldTest {
  FieldTest({
    required this.id,
    this.name = '',
    this.date = '',
    this.kind = FieldTestKind.cans,
    this.zoneId = '',
    this.areaId = '',
    this.canMouthMm = 100,
    this.durationH = 1,
    this.spacingXM = 3,
    this.spacingYM = 3,
    this.origin = Pt.zero,
    this.angleDeg = 0,
    this.cols = 0,
    List<double?>? values,
  }) : values = values ?? [];

  String id;
  String name;
  String date;
  FieldTestKind kind;

  /// Valve of the zone tested ('' = every zone over the cans).
  String zoneId;

  /// Irrigated area the cans stand in ('' = none).
  String areaId;
  double canMouthMm;
  double durationH;
  double spacingXM, spacingYM;
  Pt origin;
  double angleDeg;
  int cols;
  final List<double?> values;
  Map<String, dynamic>? extra;

  /// Position of value [index] on the grid (cans).
  Pt position(int index) {
    final c = cols <= 0 ? 1 : cols;
    final local = Pt((index % c) * spacingXM, (index ~/ c) * spacingYM);
    return origin + local.rotate(angleDeg * math.pi / 180);
  }

  FieldTest copy() => FieldTest(
    id: id,
    name: name,
    date: date,
    kind: kind,
    zoneId: zoneId,
    areaId: areaId,
    canMouthMm: canMouthMm,
    durationH: durationH,
    spacingXM: spacingXM,
    spacingYM: spacingYM,
    origin: origin,
    angleDeg: angleDeg,
    cols: cols,
    values: List.of(values),
  )..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    if (name.isNotEmpty) 'name': name,
    if (date.isNotEmpty) 'date': date,
    if (kind != FieldTestKind.cans) 'kind': kind.name,
    if (zoneId.isNotEmpty) 'zone': zoneId,
    if (areaId.isNotEmpty) 'area': areaId,
    'mouth': canMouthMm,
    'hours': durationH,
    'dx': spacingXM,
    'dy': spacingYM,
    'at': origin.toList(),
    if (angleDeg != 0) 'deg': angleDeg,
    'cols': cols,
    'v': values,
  };

  static FieldTest fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    final at = j['at'];
    final v = j['v'];
    return FieldTest(
      id: _s(j['id'], 'ft'),
      name: _s(j['name']),
      date: _s(j['date']),
      kind: enumByName(FieldTestKind.values, j['kind'] ?? FieldTestKind.cans.name, FieldTestKind.cans, report: report, key: 'fieldTest.kind'),
      zoneId: _s(j['zone']),
      areaId: _s(j['area']),
      canMouthMm: _d(j['mouth'], 100).clamp(10.0, 1000.0).toDouble(),
      durationH: _d(j['hours'], 1).clamp(0.01, 48.0).toDouble(),
      spacingXM: _d(j['dx'], 3).clamp(0.1, 100.0).toDouble(),
      spacingYM: _d(j['dy'], 3).clamp(0.1, 100.0).toDouble(),
      origin: Pt.tryFromList(at) ?? Pt.zero,
      angleDeg: _d(j['deg'], 0),
      cols: _i(j['cols'], 0).clamp(0, 10000),
      values: v is List ? [for (final x in v) x is num && x.isFinite ? x.toDouble() : null] : null,
    )..extra = j.unread;
  }
}

// ---------------------------------------------------------------- the plan

/// The agronomy settings of a project (see the library notes).
class AgronomyPlan {
  AgronomyPlan({List<UserCrop>? userCrops, ProgrammeSettings? programme, Map<String, BalanceSettings>? balance, Map<String, FertigationStagePlan>? fertigation, List<FieldTest>? fieldTests})
    : userCrops = userCrops ?? [],
      programme = programme ?? ProgrammeSettings(),
      balance = balance ?? {},
      fertigation = fertigation ?? {},
      fieldTests = fieldTests ?? [];

  final List<UserCrop> userCrops;
  ProgrammeSettings programme;

  /// Water balance settings by area id.
  final Map<String, BalanceSettings> balance;

  /// Fertigation by stage by area id.
  final Map<String, FertigationStagePlan> fertigation;
  final List<FieldTest> fieldTests;
  Map<String, dynamic>? extra;

  /// The user crop of crop key [key] (`user.<id>`), or null.
  UserCrop? userCrop(String key) {
    if (!key.startsWith(userCropPrefix)) return null;
    final id = key.substring(userCropPrefix.length);
    return userCrops.where((u) => u.id == id).firstOrNull;
  }

  bool get isDefault => userCrops.isEmpty && programme.isDefault && balance.values.every((b) => b.isDefault) && fertigation.values.every((f) => f.isEmpty) && fieldTests.isEmpty && (extra?.isEmpty ?? true);

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (userCrops.isNotEmpty) 'crops': [for (final u in userCrops) u.toJson()],
    if (!programme.isDefault) 'programme': programme.toJson(),
    if (balance.values.any((b) => !b.isDefault))
      'balance': {
        for (final e in balance.entries)
          if (!e.value.isDefault) e.key: e.value.toJson(),
      },
    if (fertigation.values.any((f) => !f.isEmpty))
      'fertigation': {
        for (final e in fertigation.entries)
          if (!e.value.isEmpty) e.key: e.value.toJson(),
      },
    if (fieldTests.isNotEmpty) 'fieldTests': [for (final f in fieldTests) f.toJson()],
  };

  /// Reads the plan; an item that cannot be read is left out (noted in
  /// [report] under `agronomy`), the rest opens.
  static AgronomyPlan fromJson(Map<String, dynamic>? json, {ProjectReadReport? report}) {
    if (json == null) return AgronomyPlan();
    final j = KeyLog(json);
    List<T> each<T>(Object? list, T Function(Map<String, dynamic>) read) {
      final out = <T>[];
      if (list is! List) return out;
      for (final x in list) {
        try {
          out.add(read(_map(x)!));
        } catch (_) {
          report?.skip('agronomy');
        }
      }
      return out;
    }

    Map<String, T> byId<T>(Object? m, T Function(Map<String, dynamic>) read) {
      final out = <String, T>{};
      if (m is! Map) return out;
      for (final e in m.entries) {
        try {
          out['${e.key}'] = read(_map(e.value)!);
        } catch (_) {
          report?.skip('agronomy');
        }
      }
      return out;
    }

    final crops = each(j['crops'], UserCrop.fromJson);
    // one crop per id (the first)
    final seen = <String>{};
    crops.retainWhere((u) => seen.add(u.id));
    return AgronomyPlan(
      userCrops: crops,
      programme: ProgrammeSettings.fromJson(_map(j['programme'])),
      balance: byId(j['balance'], (m) => BalanceSettings.fromJson(m, report: report)),
      fertigation: byId(j['fertigation'], FertigationStagePlan.fromJson),
      fieldTests: each(j['fieldTests'], (m) => FieldTest.fromJson(m, report: report)),
    )..extra = j.unread;
  }
}
