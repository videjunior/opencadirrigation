/// Effective rainfall: the part of the monthly rain stored in the root zone
/// and used by the crop (no runoff, no deep percolation). Methods:
///
/// - USDA-SCS (1970), Technical Release 21, as given in USDA-NRCS National
///   Engineering Handbook Part 623, Chapter 2 (1993), eqs. 2-84 and 2-85 and
///   Table 2-43: Pe = SF·(0.70917·Pt^0.82416 − 0.11556)·10^(0.02426·ETc) in
///   inches, with the soil water storage factor
///   SF = 0.531747 + 0.295164·D − 0.057697·D² + 0.003804·D³ (D = usable soil
///   water storage, the net depth of application, in inches; SF = 1 at
///   D = 3 in). Pe never exceeds the rain nor ETc;
/// - USDA-SCS simplified (rain only), as used by FAO Irrigation and Drainage
///   Paper 46 (Smith 1992): Pe = P·(125 − 0.2·P)/125 for P ≤ 250 mm,
///   125 + 0.1·P above;
/// - FAO/AGLW dependable rain (FAO Irrigation and Drainage Paper 46): the
///   80 % probability rain less runoff and percolation in arid and
///   sub-humid climates, Pe = 0.6·P − 10 for P ≤ 70 mm, 0.8·P − 24 above;
/// - FAO empirical formula of Brouwer & Heibloem (1986), FAO Irrigation Water
///   Management Training Manual No. 3, section 4.2 (slopes up to 4–5 %):
///   Pe = 0.6·P − 10 for P < 75 mm, 0.8·P − 25 above;
/// - a fixed percentage of the rain (0.7–0.9 usual).
///
/// All work on monthly totals in mm (the methods were fitted to months); for
/// part of a month compute the whole-month value and prorate it by days.
library;

import 'dart:math' as math;

enum EffectiveRainMethod {
  /// USDA-SCS TR-21 with the soil storage factor (rain and ETc).
  usdaScs,

  /// USDA-SCS simplified formula (rain only).
  usdaScsSimplified,

  /// FAO/AGLW dependable rain (80 % probability).
  faoDependable,

  /// FAO empirical formula (Brouwer & Heibloem 1986).
  faoEmpirical,

  /// Fixed share of the rain.
  fixedPercentage,

  /// All the rain counts (no reduction).
  total,

  /// Rain ignored.
  none,
}

/// TR-21 soil water storage factor SF for a usable storage D (mm), NEH 623
/// eq. 2-85. D is limited to the range of NEH 623 Table 2-43 (0.75–7 in,
/// 19–178 mm), outside which the cubic is not meant to be used.
double usdaScsStorageFactor(double netDepthMm) {
  final d = (netDepthMm / 25.4).clamp(0.75, 7.0);
  return 0.531747 + 0.295164 * d - 0.057697 * d * d + 0.003804 * d * d * d;
}

/// TR-21 monthly effective rain (mm) for a monthly rain [rainMm], a monthly
/// crop evapotranspiration [etcMm] and a usable soil water storage
/// [netDepthMm] (75 mm = 3 in gives SF ≈ 1), NEH 623 eqs. 2-84 and 2-85.
double effectiveRainUsdaScsMm(double rainMm, double etcMm, {double netDepthMm = 75}) {
  if (rainMm <= 0) return 0;
  final pt = rainMm / 25.4, etc = math.max(etcMm, 0.0) / 25.4;
  final pe = usdaScsStorageFactor(netDepthMm) * (0.70917 * math.pow(pt, 0.82416) - 0.11556) * math.pow(10, 0.02426 * etc);
  return (pe * 25.4).clamp(0.0, math.min(rainMm, math.max(etcMm, 0.0)));
}

/// USDA-SCS simplified monthly effective rain (mm), FAO-46 form.
double effectiveRainUsdaScsSimplifiedMm(double rainMm) {
  if (rainMm <= 0) return 0;
  return rainMm <= 250 ? rainMm * (125 - 0.2 * rainMm) / 125 : 125 + 0.1 * rainMm;
}

/// FAO/AGLW dependable monthly effective rain (mm).
double effectiveRainFaoDependableMm(double rainMm) => math.max(rainMm <= 70 ? 0.6 * rainMm - 10 : 0.8 * rainMm - 24, 0.0);

/// FAO empirical monthly effective rain (mm), Brouwer & Heibloem (1986).
double effectiveRainFaoEmpiricalMm(double rainMm) => math.max(rainMm < 75 ? 0.6 * rainMm - 10 : 0.8 * rainMm - 25, 0.0);

/// Monthly effective rain (mm) by [method]. [etcMm] is used by
/// [EffectiveRainMethod.usdaScs] (without it the simplified USDA-SCS formula
/// is used) and caps every method but [EffectiveRainMethod.total] when
/// given, since a crop cannot use more rain than it evaporates in the month;
/// [fraction] is the share kept by [EffectiveRainMethod.fixedPercentage].
double effectiveRainMm(EffectiveRainMethod method, double rainMm, {double? etcMm, double netDepthMm = 75, double fraction = 0.8}) {
  final p = math.max(rainMm, 0.0);
  final pe = switch (method) {
    EffectiveRainMethod.usdaScs => etcMm == null ? effectiveRainUsdaScsSimplifiedMm(p) : effectiveRainUsdaScsMm(p, etcMm, netDepthMm: netDepthMm),
    EffectiveRainMethod.usdaScsSimplified => effectiveRainUsdaScsSimplifiedMm(p),
    EffectiveRainMethod.faoDependable => effectiveRainFaoDependableMm(p),
    EffectiveRainMethod.faoEmpirical => effectiveRainFaoEmpiricalMm(p),
    EffectiveRainMethod.fixedPercentage => p * fraction.clamp(0.0, 1.0),
    EffectiveRainMethod.total => p,
    EffectiveRainMethod.none => 0.0,
  };
  final cap = etcMm == null || method == EffectiveRainMethod.total ? p : math.min(p, math.max(etcMm, 0.0));
  return pe.clamp(0.0, cap);
}

/// Rain (mm) exceeded with probability [probability] (0.8 = in four years
/// out of five, the FAO "dependable" level) in a sample of monthly totals:
/// empirical quantile with Weibull plotting positions m/(n + 1) and linear
/// interpolation between ranks (clamped to the sample range). Null for an
/// empty sample.
double? rainExceededWithProbability(List<double> monthlyTotals, double probability) {
  final xs = [for (final x in monthlyTotals) if (x.isFinite) x]..sort();
  if (xs.isEmpty) return null;
  final n = xs.length;
  // non-exceedance F = 1 − probability; rank r (1-based, ascending) where r/(n+1) = F
  final r = (1 - probability.clamp(0.0, 1.0)) * (n + 1);
  if (r <= 1) return xs.first;
  if (r >= n) return xs.last;
  final lo = r.floor();
  final t = r - lo;
  return xs[lo - 1] + t * (xs[lo] - xs[lo - 1]);
}

/// Effective rain (mm) over [days] days of a month of [monthDays] days:
/// the whole-month value of [method] (with the monthly ETc extrapolated
/// from [etcMmInPeriod] when given) prorated by the share of days.
double effectiveRainForPartOfMonthMm(EffectiveRainMethod method, {required double monthRainMm, required int days, required int monthDays, double? etcMmInPeriod, double netDepthMm = 75, double fraction = 0.8}) {
  if (days <= 0 || monthDays <= 0) return 0;
  final share = (days / monthDays).clamp(0.0, 1.0);
  final etcMonth = etcMmInPeriod == null ? null : etcMmInPeriod / share;
  return effectiveRainMm(method, monthRainMm, etcMm: etcMonth, netDepthMm: netDepthMm, fraction: fraction) * share;
}

/// Convenience for reports in US units: inches of rain and ETc to inches of
/// effective rain with TR-21 (NEH 623 Table 2-43 is in inches).
double effectiveRainUsdaScsInches(double rainIn, double etcIn, {double netDepthIn = 3}) => effectiveRainUsdaScsMm(rainIn * 25.4, etcIn * 25.4, netDepthMm: netDepthIn * 25.4) / 25.4;
