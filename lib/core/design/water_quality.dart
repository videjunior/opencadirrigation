/// Water quality, filtration and chemical treatment of the irrigation
/// water: the clogging hazard of the analysis, the filters the emitters
/// need and the chlorine and acid doses.
///
/// * Clogging hazard of drip and micro irrigation water (Nakayama 1982;
///   Nakayama & Bucks 1986): suspended solids < 50 / 50–100 / > 100 mg/L,
///   pH < 7 / 7–8 / > 8, dissolved solids < 500 / 500–2000 / > 2000 mg/L,
///   manganese and iron < 0.1 / 0.1–1.5 / > 1.5 mg/L, hydrogen sulfide
///   < 0.5 / 0.5–2 / > 2 mg/L, bacteria < 10 000 / 10 000–50 000 / > 50 000
///   per mL: none, slight to moderate, severe. Dissolved solids from the
///   conductivity, TDS ≈ 640·ECw (FAO Irrigation and Drainage Paper 29).
/// * Carbonate scaling: Langelier saturation index LSI = pH − pHs with
///   pHs = (9.3 + A + B) − (C + D), A = (log TDS − 1)/10,
///   B = −13.12·log(T + 273) + 34.55, C = log(Ca as CaCO₃) − 0.4,
///   D = log(alkalinity as CaCO₃); LSI > 0 tends to deposit calcium
///   carbonate.
/// * Filtration: the filter opening a fraction of the smallest passage of
///   the emitters (1/7 by default, as the makers ask), the mesh of the
///   ASTM E11 sieve series; media (sand) filters for surface water and for
///   loads of suspended solids or bacteria, sized at 15 gpm/ft²
///   (≈ 37 m³/h/m²) for dirty water (≥ 100 mg/L), 20 (≈ 49) for average and
///   25 (≈ 61) for clean water (< 10 mg/L), at least two tanks so one
///   backflushes with the water of the others (UC ANR, Maintenance of
///   Microirrigation Systems; Haman, Smajstrla & Zazueta, UF/IFAS WI008),
///   with a screen or disc filter of the mesh after them.
/// * Chlorination (UC ANR): continuous to keep 1–2 mg/L of free chlorine at
///   the end of the last lateral, or 10–20 mg/L for 30–60 minutes now and
///   then; the oxidation demand of 0.64 mg/L per mg/L of ferrous iron,
///   1.3 per mg/L of manganese (which oxidises only at pH ≥ 9.5) and 4–8
///   (6 taken) per mg/L of hydrogen sulfide; injected ahead of the filters
///   so they hold the precipitate. Injection rate q = Q·C/(10·%) of a
///   hypochlorite with % available chlorine.
/// * Acid: the amount that brings the water to the target pH in a closed
///   carbonate system, acid = HCO₃⁻·(f(pH₁) − f(pH₀))/(1 − f(pH₀)) meq/L with
///   f = 1/(1 + 10^(pH − pKa₁)), pKa₁ = 6.35 (25 °C); a titration of the
///   water confirms it.
library;

import 'dart:math' as math;

import '../model/agb_settings.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'results.dart';

/// Hazard classes of the analysis.
enum ClogRisk { low, moderate, severe }

/// One parameter of the analysis with its class.
class WaterHazard {
  const WaterHazard(this.key, this.value, this.risk);

  /// `tss`, `ph`, `tds`, `mn`, `fe`, `h2s` or `bact`.
  final String key;
  final double value;
  final ClogRisk risk;

  Map<String, dynamic> toJson() => {'k': key, 'v': value, 'r': risk.name};
  static WaterHazard fromJson(Map<String, dynamic> j) => WaterHazard(j['k'] as String? ?? '', (j['v'] as num?)?.toDouble() ?? 0, ClogRisk.values.asNameMap()[j['r']] ?? ClogRisk.low);
}

/// Class bounds of Nakayama (1982): (moderate from, severe above).
const clogBounds = <String, (double, double)>{'tss': (50, 100), 'ph': (7, 8), 'tds': (500, 2000), 'mn': (0.1, 1.5), 'fe': (0.1, 1.5), 'h2s': (0.5, 2), 'bact': (10000, 50000)};

ClogRisk clogRiskOf(String key, double v) {
  final b = clogBounds[key]!;
  return v > b.$2 ? ClogRisk.severe : (v >= b.$1 ? ClogRisk.moderate : ClogRisk.low);
}

/// ASTM E11 sieves: (mesh number, opening in µm).
const sieveSeries = <(int, double)>[(20, 850), (30, 600), (40, 425), (50, 300), (60, 250), (70, 212), (80, 180), (100, 150), (120, 125), (140, 106), (170, 90), (200, 75)];

/// The coarsest sieve whose opening is at most [microns] (the finest when
/// none is).
(int, double) meshFor(double microns) {
  for (final s in sieveSeries) {
    if (s.$2 <= microns + 1e-9) return s;
  }
  return sieveSeries.last;
}

/// Usual inner diameters of media filter tanks (m: 16, 20, 24, 30, 36 and 48 in).
const mediaTankDiameters = <double>[0.406, 0.508, 0.610, 0.762, 0.914, 1.219];

/// Filtration rate of a media filter (m³/h per m² of media) for the
/// suspended solids (mg/L; null = average water).
double mediaFluxM3hM2(double? tssMgL) {
  const gpmPerFt2 = 2.4448; // m³/h/m²
  if (tssMgL == null) return 20 * gpmPerFt2;
  if (tssMgL >= 100) return 15 * gpmPerFt2;
  if (tssMgL < 10) return 25 * gpmPerFt2;
  return 20 * gpmPerFt2;
}

/// Langelier saturation index of a water (null when a value is missing).
double? langelierIndex({required double? ph, required double? tdsMgL, required double? calciumMgL, required double? bicarbonateMgL, double temperatureC = 25}) {
  if (ph == null || tdsMgL == null || calciumMgL == null || bicarbonateMgL == null || tdsMgL <= 0 || calciumMgL <= 0 || bicarbonateMgL <= 0) return null;
  double log10(double x) => math.log(x) / math.ln10;
  final a = (log10(tdsMgL) - 1) / 10;
  final b = -13.12 * log10(temperatureC + 273) + 34.55;
  final c = log10(calciumMgL * 2.497) - 0.4;
  final d = log10(bicarbonateMgL * 0.8202);
  return ph - ((9.3 + a + b) - (c + d));
}

/// Acid (meq/L) that brings a water of [alkalinityMeqL] from [ph0] to
/// [ph1] in a closed carbonate system (0 when it is already there).
double acidToLowerPh(double alkalinityMeqL, double ph0, double ph1, {double pKa1 = 6.35}) {
  if (alkalinityMeqL <= 0 || ph1 >= ph0) return 0;
  double f(double ph) => 1 / (1 + math.pow(10, ph - pKa1));
  final f0 = f(ph0), f1 = f(ph1);
  return alkalinityMeqL * (f1 - f0) / (1 - f0);
}

/// Product of each acid: (equivalent weight mg/meq, purity, density g/mL).
const acidData = <AcidProduct, (double, double, double)>{
  AcidProduct.sulfuric: (49.04, 0.98, 1.84),
  AcidProduct.hydrochloric: (36.46, 0.33, 1.16),
  AcidProduct.nitric: (63.01, 0.60, 1.37),
  AcidProduct.phosphoric: (97.99, 0.85, 1.685),
};

/// Commercial acid (mL per m³ of water) for [meqL] of acid.
double acidMlPerM3(AcidProduct acid, double meqL) {
  final (ew, purity, density) = acidData[acid]!;
  return meqL * ew / (purity * density);
}

/// Filters of the analysis and the treatment.
class WaterQualityResult {
  WaterQualityResult({
    required this.hazards,
    required this.overall,
    required this.tdsMgL,
    required this.lsi,
    required this.designFlowM3h,
    required this.passageMm,
    required this.openingUm,
    required this.mesh,
    required this.media,
    required this.discFilter,
    required this.mediaTanks,
    required this.tankDiameterM,
    required this.mediaFlux,
    required this.drawnCapacityM3h,
    required this.drawnFilters,
    required this.safetyFilterId,
    required this.safetyFilters,
    required this.chlorination,
    required this.chlorineDemandMgL,
    required this.chlorineDoseMgL,
    required this.hypochloriteLph,
    required this.hypochloriteLYear,
    required this.acidTargetPh,
    required this.acidMeqL,
    required this.acidMlM3,
    required this.acidLph,
    required this.acidLYear,
    this.warnings = const [],
  });
  final List<WaterHazard> hazards;
  final ClogRisk overall;

  /// Dissolved solids used (mg/L; 0 = unknown) and the Langelier index.
  final double tdsMgL;
  final double? lsi;

  /// Flow the station filters (m³/h): the largest system flow.
  final double designFlowM3h;

  /// Emitter passage (mm), filter opening (µm) and its mesh.
  final double passageMm;
  final double openingUm;
  final int mesh;

  /// Media filters ahead of the safety filter, and whether the safety
  /// filter is a disc filter (else a screen): tanks, diameter (m) and rate
  /// (m³/h/m²).
  final bool media;
  final bool discFilter;
  final int mediaTanks;
  final double tankDiameterM;
  final double mediaFlux;

  /// Filters drawn in the project: their capacity (m³/h) and number.
  final double drawnCapacityM3h;
  final int drawnFilters;

  /// Catalogue filter proposed for the safety stage and how many.
  final String? safetyFilterId;
  final int safetyFilters;

  /// Chlorination applied, the oxidation demand and the dose (mg/L), the
  /// hypochlorite injection (L/h at the design flow) and its yearly use (L).
  final ChlorinationMode chlorination;
  final double chlorineDemandMgL;
  final double chlorineDoseMgL;
  final double hypochloriteLph;
  final double hypochloriteLYear;

  /// Acid: the target pH (null = none), meq/L, mL of product per m³, the
  /// injection (L/h) and the yearly use (L).
  final double? acidTargetPh;
  final double acidMeqL;
  final double acidMlM3;
  final double acidLph;
  final double acidLYear;

  /// Codes `water_*`.
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'haz': [for (final h in hazards) h.toJson()],
    'risk': overall.name,
    'tds': tdsMgL,
    if (lsi != null) 'lsi': lsi,
    'q': designFlowM3h,
    'pass': passageMm,
    'um': openingUm,
    'mesh': mesh,
    'media': media,
    'disc': discFilter,
    'tanks': mediaTanks,
    'dt': tankDiameterM,
    'flux': mediaFlux,
    'drawn': drawnCapacityM3h,
    'ndrawn': drawnFilters,
    if (safetyFilterId != null) 'safe': safetyFilterId,
    'nsafe': safetyFilters,
    'cl': chlorination.name,
    'cld': chlorineDemandMgL,
    'cldose': chlorineDoseMgL,
    'cllph': hypochloriteLph,
    'cly': hypochloriteLYear,
    if (acidTargetPh != null) 'acidph': acidTargetPh,
    'meq': acidMeqL,
    'mlm3': acidMlM3,
    'alph': acidLph,
    'aly': acidLYear,
    if (warnings.isNotEmpty) 'warn': warnings,
  };
  static WaterQualityResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return WaterQualityResult(
      hazards: [for (final h in (j['haz'] as List?) ?? const []) WaterHazard.fromJson((h as Map).cast<String, dynamic>())],
      overall: ClogRisk.values.asNameMap()[j['risk']] ?? ClogRisk.low,
      tdsMgL: d('tds'),
      lsi: (j['lsi'] as num?)?.toDouble(),
      designFlowM3h: d('q'),
      passageMm: d('pass'),
      openingUm: d('um'),
      mesh: (j['mesh'] as num?)?.toInt() ?? 0,
      media: j['media'] as bool? ?? false,
      discFilter: j['disc'] as bool? ?? true,
      mediaTanks: (j['tanks'] as num?)?.toInt() ?? 0,
      tankDiameterM: d('dt'),
      mediaFlux: d('flux'),
      drawnCapacityM3h: d('drawn'),
      drawnFilters: (j['ndrawn'] as num?)?.toInt() ?? 0,
      safetyFilterId: j['safe'] as String?,
      safetyFilters: (j['nsafe'] as num?)?.toInt() ?? 0,
      chlorination: ChlorinationMode.values.asNameMap()[j['cl']] ?? ChlorinationMode.none,
      chlorineDemandMgL: d('cld'),
      chlorineDoseMgL: d('cldose'),
      hypochloriteLph: d('cllph'),
      hypochloriteLYear: d('cly'),
      acidTargetPh: (j['acidph'] as num?)?.toDouble(),
      acidMeqL: d('meq'),
      acidMlM3: d('mlm3'),
      acidLph: d('alph'),
      acidLYear: d('aly'),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Smallest water passage (mm) of the emitters of [p]: drippers and tapes
/// 0.8, micro-sprinklers 1.0, sprays and sprinklers 2.0.
double emitterPassageOf(Project p) {
  if (p.agb.water.emitterPassageMm > 0) return p.agb.water.emitterPassageMm;
  var best = double.infinity;
  for (final e in p.entities) {
    final kind = switch (e) {
      TapeEntity _ => OutletKind.dripper,
      OutletEntity o => p.catalog.outlet(o.outletSpecId)?.kind,
      SpraylineEntity s => p.catalog.outlet(s.outletSpecId)?.kind,
      _ => null,
    };
    final mm = switch (kind) {
      OutletKind.dripper => 0.8,
      OutletKind.microSprinkler || OutletKind.bubbler => 1.0,
      OutletKind.sprinkler || OutletKind.gun => 2.0,
      _ => double.infinity,
    };
    best = math.min(best, mm);
  }
  return best.isFinite ? best : 0.8;
}

/// Flow the filter station passes (m³/h): the largest system flow of
/// [results], else every zone together.
double filterDesignFlowM3h(DesignResults? results) {
  var q = 0.0;
  for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) {
    q = math.max(q, f.totalFlow);
  }
  if (q <= 0) {
    for (final z in results?.zones.values ?? const <ZoneResult>[]) {
      q += z.totalFlow;
    }
  }
  return q * 3600;
}

/// Water quality design of [p]; null when no value of the analysis was
/// given.
WaterQualityResult? designWaterQuality(Project p, DesignResults? results) {
  final w = p.agb.water;
  if (!w.analysed) return null;
  final warnings = <String>[];
  final tds = w.tdsMgL ?? (w.ecDsM != null ? 640 * w.ecDsM! : null);
  final hazards = <WaterHazard>[
    if (w.tssMgL != null) WaterHazard('tss', w.tssMgL!, clogRiskOf('tss', w.tssMgL!)),
    if (w.ph != null) WaterHazard('ph', w.ph!, clogRiskOf('ph', w.ph!)),
    if (tds != null) WaterHazard('tds', tds, clogRiskOf('tds', tds)),
    if (w.manganeseMgL != null) WaterHazard('mn', w.manganeseMgL!, clogRiskOf('mn', w.manganeseMgL!)),
    if (w.ironMgL != null) WaterHazard('fe', w.ironMgL!, clogRiskOf('fe', w.ironMgL!)),
    if (w.sulfideMgL != null) WaterHazard('h2s', w.sulfideMgL!, clogRiskOf('h2s', w.sulfideMgL!)),
    if (w.bacteriaPerMl != null) WaterHazard('bact', w.bacteriaPerMl!, clogRiskOf('bact', w.bacteriaPerMl!)),
  ];
  final overall = hazards.fold(ClogRisk.low, (a, h) => h.risk.index > a.index ? h.risk : a);
  if (overall == ClogRisk.severe) warnings.add('water_risk_severe');
  ClogRisk riskOf(String k) => hazards.where((h) => h.key == k).firstOrNull?.risk ?? ClogRisk.low;
  final lsi = langelierIndex(ph: w.ph, tdsMgL: tds, calciumMgL: w.calciumMgL, bicarbonateMgL: w.bicarbonateMgL, temperatureC: w.temperatureC);
  if (lsi != null && lsi > 0) warnings.add('water_scaling');

  // ---- filtration
  final q = filterDesignFlowM3h(results);
  final passage = emitterPassageOf(p);
  final opening = passage * 1000 / math.max(w.meshRatio, 1);
  final (mesh, meshUm) = meshFor(opening);
  final surface = w.source == WaterSource.surface || w.source == WaterSource.reservoir;
  final media = surface || riskOf('tss').index >= ClogRisk.moderate.index || riskOf('bact').index >= ClogRisk.moderate.index;
  final disc = media || mesh >= 120;
  var tanks = 0;
  var diameter = 0.0;
  final flux = mediaFluxM3hM2(w.tssMgL);
  if (media && q > 0) {
    final need = q / flux;
    // the fewest tanks, then the least media area
    var bestArea = double.infinity;
    var bestN = 1 << 30;
    for (final d in mediaTankDiameters) {
      final a = math.pi / 4 * d * d;
      final n = math.max(2, (need / a - 1e-9).ceil());
      final total = n * a;
      if (n < bestN || (n == bestN && total < bestArea - 1e-9)) {
        bestN = n;
        bestArea = total;
        tanks = n;
        diameter = d;
      }
    }
  }
  // the filters drawn and a catalogue safety filter for the flow
  var drawn = 0.0;
  var nDrawn = 0;
  for (final e in p.entities.whereType<MiscHydraulicEntity>()) {
    final s = p.catalog.valve(e.valveSpecId);
    if (s == null || s.kind != ValveKind.filter) continue;
    nDrawn++;
    drawn += s.maxFlow * 3600;
  }
  if (nDrawn > 0 && q > drawn + 1e-6) warnings.add('water_filter_small');
  String? safeId;
  var nSafe = 0;
  if (q > 0) {
    final filters = p.catalog.valves.where((v) => v.enabled && v.kind == ValveKind.filter && v.maxFlow > 0).toList();
    final typed = filters.where((v) => v.id.contains(disc ? 'disc' : 'screen')).toList();
    final pool = typed.isNotEmpty ? typed : filters;
    var bestN = 1 << 30;
    var bestCost = double.infinity;
    for (final f in pool) {
      final n = (q / (f.maxFlow * 3600) - 1e-9).ceil().clamp(1, 1 << 20);
      final cost = n * f.cost;
      if (n < bestN || (n == bestN && cost < bestCost)) {
        bestN = n;
        bestCost = cost;
        safeId = f.id;
      }
    }
    nSafe = safeId == null ? 0 : bestN;
  }

  // ---- chlorination
  final fe = w.ironMgL ?? 0, mn = w.manganeseMgL ?? 0, h2s = w.sulfideMgL ?? 0;
  final demand = 0.64 * fe + 1.3 * mn + 6 * h2s;
  var mode = w.chlorination;
  if (mode == ChlorinationMode.auto) {
    final oxidise = fe >= 0.1 || mn >= 0.1 || h2s >= 0.5;
    mode = oxidise || riskOf('bact').index >= ClogRisk.moderate.index ? ChlorinationMode.continuous : (surface ? ChlorinationMode.intermittent : ChlorinationMode.none);
  }
  if (mn >= 0.1 && mode != ChlorinationMode.none) warnings.add('water_mn_ph');
  if ((w.ph ?? 0) > 7.5 && mode != ChlorinationMode.none) warnings.add('water_cl_ph');
  final hours = p.params.hoursPerYear;
  final strength = math.max(w.hypochloritePct, 0.1) * 10; // g/L
  double dose = 0, lph = 0, lYear = 0;
  switch (mode) {
    case ChlorinationMode.continuous:
      dose = demand + w.chlorineResidualMgL;
      lph = q * dose / strength;
      lYear = lph * hours;
    case ChlorinationMode.intermittent:
      dose = demand + w.shockMgL;
      lph = q * dose / strength;
      lYear = lph * w.shockMinutes / 60 * w.shocksPerMonth * 12;
    case ChlorinationMode.none || ChlorinationMode.auto:
      break;
  }

  // ---- acid
  var target = w.acidTargetPh;
  if (target == null && w.ph != null && ((lsi != null && lsi > 0) || (w.ph! > 7.5 && mode != ChlorinationMode.none))) target = 6.5;
  var meq = 0.0, mlm3 = 0.0;
  if (target != null && w.ph != null) {
    if (w.bicarbonateMgL == null) {
      warnings.add('water_acid_titrate');
    } else {
      meq = acidToLowerPh(w.bicarbonateMgL! / 61.02, w.ph!, target);
      mlm3 = acidMlPerM3(w.acid, meq);
    }
  }
  final alph = q * mlm3 / 1000;
  return WaterQualityResult(
    hazards: hazards,
    overall: overall,
    tdsMgL: tds ?? 0,
    lsi: lsi,
    designFlowM3h: q,
    passageMm: passage,
    openingUm: meshUm,
    mesh: mesh,
    media: media,
    discFilter: disc,
    mediaTanks: tanks,
    tankDiameterM: diameter,
    mediaFlux: flux,
    drawnCapacityM3h: drawn,
    drawnFilters: nDrawn,
    safetyFilterId: safeId,
    safetyFilters: nSafe,
    chlorination: mode,
    chlorineDemandMgL: demand,
    chlorineDoseMgL: dose,
    hypochloriteLph: lph,
    hypochloriteLYear: lYear,
    acidTargetPh: target,
    acidMeqL: meq,
    acidMlM3: mlm3,
    acidLph: alph,
    acidLYear: alph * hours,
    warnings: warnings,
  );
}
