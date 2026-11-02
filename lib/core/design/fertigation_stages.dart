/// Fertigation by growth stage of an irrigated area (1.6.0): the doses of
/// N, P₂O₅ and K₂O of the crop cycle split over the four stages of its
/// FAO-56 crop coefficient curve — in proportion to the crop's water use in
/// each stage (ETc = Kc·ETo of the typical year), or by the shares typed —
/// and given in the irrigations of the stage (the events of the daily soil
/// water balance, soil_water_balance.dart, every n-th of them): the
/// product of each event (the phosphate and potash products first, their
/// nitrogen counted, the nitrogen product for the rest), the stock
/// solution and its injection rate over the injection share of the event,
/// and the concentration the water carries while the product is injected.
///
/// The salts dissolved raise the electrical conductivity of the water:
/// ΔEC (dS/m) ≈ TDS (mg/L)/640 (Ayers & Westcot 1985, FAO-29, for EC
/// below 5 dS/m), the non-electrolytes (urea) left out; the water of the
/// injection (ECw of the area plus ΔEC) is set against the salinity of the
/// irrigation water the crop takes at full yield, ECe threshold/1.5
/// (FAO-29 Table 4 takes ECe = 1.5·ECw, a leaching fraction of 15–20 %).
library;

import 'dart:math' as math;

import '../model/agronomy_plan.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'area_water.dart';
import 'crops.dart';
import 'designer.dart' show areaRequirements;
import 'results.dart';
import 'soil_water_balance.dart';

/// Growth stage names (i18n keys `fert.stage.<name>`).
const fertStageNames = ['initial', 'development', 'mid', 'late'];

/// One stage of the plan.
class FertStage {
  const FertStage({
    required this.stage,
    required this.start,
    required this.end,
    required this.days,
    required this.etcMm,
    required this.sharePct,
    required this.kgHa,
    required this.irrigations,
    required this.fertigations,
    required this.productKgPerEvent,
    required this.stockLPerEvent,
    required this.injectionLph,
    required this.waterM3PerEvent,
    required this.concentrationGL,
    required this.ecRiseDsM,
  });

  /// 0 initial, 1 development, 2 mid-season, 3 late.
  final int stage;
  final DateTime start, end;
  final int days;

  /// ETc of the stage (mm), the share of every nutrient given in it (%) and
  /// the doses (kg/ha of N, P₂O₅, K₂O).
  final double etcMm;
  final List<double> sharePct;
  final List<double> kgHa;

  /// Irrigations of the stage and those that carry the products.
  final int irrigations;
  final int fertigations;

  /// Product of each nutrient (the plan's three products) per fertigation
  /// over the whole area (kg), stock solution (L) and its injection rate
  /// (L/h).
  final List<double> productKgPerEvent;
  final double stockLPerEvent;
  final double injectionLph;

  /// Water of one irrigation over the area (m³), the concentration of the
  /// products in it while they are injected (g/L) and the rise of its EC.
  final double waterM3PerEvent;
  final double concentrationGL;
  final double ecRiseDsM;
}

/// The plan of one area.
class FertigationSchedule {
  const FertigationSchedule({required this.areaId, required this.areaHa, required this.plan, required this.stages, required this.ecwDsM, this.ecwLimitDsM, required this.warnings});
  final String areaId;
  final double areaHa;
  final FertigationStagePlan plan;
  final List<FertStage> stages;

  /// ECw of the area and the ECw at which the crop keeps its full yield
  /// (null without salt tolerance data).
  final double ecwDsM;
  final double? ecwLimitDsM;

  /// Codes `fert_stage_no_irrigation:<stage>`, `fert_ec_high:<stage>`,
  /// `fert_no_stages`.
  final List<String> warnings;

  /// Products of the cycle over the area (kg).
  List<double> get productTotalsKg => [for (var k = 0; k < 3; k++) stages.fold(0.0, (s, x) => s + x.productKgPerEvent[k] * x.fertigations)];

  /// Largest ECw while the products are injected.
  double get peakEcwDsM => ecwDsM + stages.fold(0.0, (m, s) => math.max(m, s.ecRiseDsM));
}

/// Kilograms of the three products of [products] (N, P₂O₅, K₂O carriers)
/// that give [kg] of N, P₂O₅ and K₂O: the phosphate and potash products
/// first, their nitrogen counted, the nitrogen product for what is left.
List<double> productsForNutrients(List<double> kg, List<FertProduct> products) {
  final out = List<double>.filled(3, 0);
  var n = kg[0];
  final p = products[1], k = products[2];
  if (kg[1] > 0 && p.share(1) > 0) {
    out[1] = kg[1] / p.share(1);
    n -= out[1] * p.share(0);
  }
  if (kg[2] > 0 && k.share(2) > 0) {
    out[2] = kg[2] / k.share(2);
    n -= out[2] * k.share(0);
  }
  if (n > 0 && products[0].share(0) > 0) out[0] = n / products[0].share(0);
  return out;
}

/// The fertigation of area [a] of [p] by [plan] (the area's own plan when
/// null); null when the area has no crop curve with stages or no water
/// balance.
FertigationSchedule? fertigationSchedule(Project p, AreaEntity a, {FertigationStagePlan? plan, DesignResults? results}) {
  final pl = plan ?? p.agronomy.fertigation[a.id] ?? FertigationStagePlan();
  final input = balanceInputOf(p, a, settings: BalanceSettings());
  if (input == null) return null;
  final curve = input.curve;
  final st = curve.stages;
  final warnings = <String>[];
  final balance = soilWaterBalance(input);
  final ha = a.area / 1e4;
  final rate = areaRequirements(p, results).where((r) => r.areaId == a.id).firstOrNull?.precipitationMmH ?? 0.0;
  // the days of every stage in the balance
  final perStage = List.generate(4, (_) => <BalanceDay>[]);
  for (final d in balance.days) {
    if (d.stage >= 0 && d.stage < 4) perStage[d.stage].add(d);
  }
  if (st.total <= 0 || st.initial + st.development + st.late <= 0 || perStage.every((x) => x.isEmpty)) warnings.add('fert_no_stages');
  final etc = [for (final x in perStage) x.fold(0.0, (s, d) => s + d.etcMm)];
  final etcTotal = etc.fold(0.0, (s, v) => s + v);
  final ece = cropDataOf(p, a.cropKey)?.eceThreshold;
  final limit = ece == null ? null : ece / 1.5;
  final stages = <FertStage>[];
  for (var s = 0; s < 4; s++) {
    final days = perStage[s];
    if (days.isEmpty) continue;
    final share = [for (var k = 0; k < 3; k++) pl.sharePct != null ? pl.sharePct![s][k].clamp(0.0, 100.0).toDouble() : (etcTotal > 0 ? 100 * etc[s] / etcTotal : 25.0)];
    final kgHa = [for (var k = 0; k < 3; k++) pl.doseKgHa[k] * share[k] / 100];
    final events = [
      for (final d in days)
        if (d.netIrrigationMm > 0) d,
    ];
    final fert = events.isEmpty ? 0 : (events.length / math.max(1, pl.everyNth)).ceil();
    if (events.isEmpty && kgHa.any((x) => x > 0)) warnings.add('fert_stage_no_irrigation:${fertStageNames[s]}');
    final perEventKg = fert == 0 ? List<double>.filled(3, 0) : [for (final x in productsForNutrients(kgHa, pl.products)) x * ha / fert];
    final gross = events.isEmpty ? 0.0 : events.fold(0.0, (t, d) => t + d.grossIrrigationMm) / events.length;
    final water = gross / 1000 * a.area;
    final inject = (pl.injectionPct.clamp(5.0, 100.0) / 100).toDouble();
    final productKg = perEventKg.fold(0.0, (t, v) => t + v);
    final ionicKg = [
      for (var k = 0; k < 3; k++)
        if (pl.products[k].ionic) perEventKg[k],
    ].fold(0.0, (t, v) => t + v);
    final conc = water > 0 ? productKg / (water * inject) : 0.0;
    final ecRise = water > 0 ? 1000 * ionicKg / (water * inject) / 640 : 0.0;
    final hours = rate > 0 ? gross / rate : 0.0;
    final stock = productKg / math.max(pl.stockKgPerL, 1e-6);
    if (limit != null && fert > 0 && a.ecwDsM + ecRise > limit + 1e-9) warnings.add('fert_ec_high:${fertStageNames[s]}');
    stages.add(
      FertStage(
        stage: s,
        start: days.first.date,
        end: days.last.date,
        days: days.length,
        etcMm: etc[s],
        sharePct: share,
        kgHa: kgHa,
        irrigations: events.length,
        fertigations: fert,
        productKgPerEvent: perEventKg,
        stockLPerEvent: stock,
        injectionLph: hours > 0 ? stock / (hours * inject) : 0.0,
        waterM3PerEvent: water,
        concentrationGL: conc,
        ecRiseDsM: ecRise,
      ),
    );
  }
  return FertigationSchedule(areaId: a.id, areaHa: ha, plan: pl, stages: stages, ecwDsM: a.ecwDsM, ecwLimitDsM: limit, warnings: warnings);
}

/// The stage lengths of [curve] as days (for the interface).
List<double> stageLengths(KcCurve curve) => [curve.stages.initial, curve.stages.development, curve.stages.mid, curve.stages.late];
