/// Frequency analysis and trend test of yearly values (1.7.0 CLR, the
/// climate risk over the years):
///
/// - empirical non-exceedance probability with Weibull plotting positions,
///   F(x₍ᵢ₎) = i/(n + 1) for the i-th smallest of n values (Weibull 1939;
///   Chow, Maidment & Mays 1988, Applied Hydrology, section 12.5; the same
///   positions the dependable rain of effective_rain.dart uses), and the
///   value of a probability by linear interpolation between ranks, clamped
///   to the sample range (no distribution is fitted, so nothing is
///   extrapolated beyond the years observed);
/// - the trend of a yearly series: Sen's slope, the median of the slopes of
///   every pair of years (Sen 1968, J. Am. Stat. Assoc. 63:1379), and the
///   Mann-Kendall test (Mann 1945; Kendall 1975) with the variance
///   corrected for ties, Var(S) = [n(n−1)(2n+5) − Σ t(t−1)(2t+5)]/18, and
///   the continuity-corrected Z; two-sided at the 5 % level (|Z| > 1.96),
///   as Helsel & Hirsch (2002), Statistical Methods in Water Resources
///   (USGS TWRI 4-A3), chapter 12, describe it. The normal approximation
///   needs about ten values, so shorter series give no test. Serial
///   correlation is not removed.
library;

import 'dart:math' as math;

import 'effective_rain.dart' show rainExceededWithProbability;

/// Weibull plotting position of the value of [rank] (1 = the smallest) of
/// [n]: its empirical non-exceedance probability i/(n + 1).
double weibullPosition(int rank, int n) => n <= 0 ? 0 : rank / (n + 1);

/// The value not exceeded with probability [nonExceedance] (0.8 = in four
/// years out of five) in [sample] (Weibull positions, interpolated between
/// ranks, clamped to the range); null for an empty sample.
double? quantileAt(List<double> sample, double nonExceedance) => rainExceededWithProbability(sample, 1 - nonExceedance.clamp(0.0, 1.0));

/// The exceedance curve of [sample]: its values from the smallest up with
/// their non-exceedance probability (Weibull positions).
List<(double, double)> exceedanceCurve(List<double> sample) {
  final xs = [
    for (final x in sample)
      if (x.isFinite) x,
  ]..sort();
  return [for (var i = 0; i < xs.length; i++) (weibullPosition(i + 1, xs.length), xs[i])];
}

/// How many values of [sample] are above [x] (with a relative tolerance of
/// 10⁻⁹, so a value equal to [x] is not counted).
int countAbove(List<double> sample, double x) => sample.where((v) => v.isFinite && v > x + 1e-9 * math.max(1.0, x.abs())).length;

/// Median of [sample] (null when empty).
double? median(List<double> sample) {
  final xs = [
    for (final x in sample)
      if (x.isFinite) x,
  ]..sort();
  if (xs.isEmpty) return null;
  final m = xs.length ~/ 2;
  return xs.length.isOdd ? xs[m] : (xs[m - 1] + xs[m]) / 2;
}

/// Sen's slope and the Mann-Kendall test of a yearly series.
class TrendTest {
  const TrendTest({required this.n, required this.slopePerYear, required this.s, required this.varS, required this.z});

  /// Values in the series.
  final int n;

  /// Sen's slope (units of the values per year).
  final double slopePerYear;

  /// Mann-Kendall statistic S and its variance (ties corrected).
  final int s;
  final double varS;

  /// Standard normal statistic (continuity corrected).
  final double z;

  /// The trend is significant at the 5 % level (two-sided).
  bool get significant => z.abs() > 1.96;

  /// Slope per decade.
  double get slopePerDecade => slopePerYear * 10;
}

/// Least number of values for the Mann-Kendall normal approximation.
const minTrendYears = 10;

/// Sen's slope and the Mann-Kendall test of [values] at the times [years]
/// (same length); null with fewer than [minTrendYears] values.
TrendTest? senMannKendall(List<int> years, List<double> values) {
  final pts = [
    for (var i = 0; i < math.min(years.length, values.length); i++)
      if (values[i].isFinite) (years[i], values[i]),
  ];
  final n = pts.length;
  if (n < minTrendYears) return null;
  final slopes = <double>[];
  var s = 0;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final d = pts[j].$2 - pts[i].$2;
      final dt = pts[j].$1 - pts[i].$1;
      if (dt != 0) slopes.add(d / dt);
      // the sign follows time: a later value larger counts +1
      final later = dt >= 0 ? d : -d;
      s += later > 0 ? 1 : (later < 0 ? -1 : 0);
    }
  }
  // ties: groups of equal values
  final groups = <double, int>{};
  for (final p in pts) {
    groups.update(p.$2, (v) => v + 1, ifAbsent: () => 1);
  }
  var tie = 0.0;
  for (final t in groups.values) {
    if (t > 1) tie += t * (t - 1) * (2 * t + 5);
  }
  final varS = (n * (n - 1) * (2 * n + 5) - tie) / 18;
  final z = varS <= 0 ? 0.0 : (s > 0 ? (s - 1) / math.sqrt(varS) : (s < 0 ? (s + 1) / math.sqrt(varS) : 0.0));
  return TrendTest(n: n, slopePerYear: median(slopes) ?? 0, s: s, varS: varS, z: z);
}
