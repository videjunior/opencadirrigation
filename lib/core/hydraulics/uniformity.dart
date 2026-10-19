/// Distribution-uniformity statistics.
library;

import 'dart:math' as math;

class UniformityStats {
  const UniformityStats({
    required this.count,
    required this.mean,
    required this.min,
    required this.max,
    required this.cu,
    required this.du,
    required this.eu,
    required this.us,
    required this.qvar,
    required this.cv,
  });

  final int count;
  final double mean;
  final double min;
  final double max;

  /// Christiansen coefficient of uniformity (%).
  final double cu;

  /// Low-quarter distribution uniformity (%).
  final double du;

  /// Keller-Karmeli emission uniformity (%), includes manufacturer CV.
  final double eu;

  /// Statistical uniformity 100·(1 − CV) (%).
  final double us;

  /// Flow variation (qmax − qmin)/qmax (%).
  final double qvar;

  /// Coefficient of variation of the sample (fraction).
  final double cv;

  static const empty = UniformityStats(
    count: 0, mean: 0, min: 0, max: 0, cu: 0, du: 0, eu: 0, us: 0, qvar: 0, cv: 0);

  /// Computes the statistics from a list of emitter flows.
  /// [manufacturerCv] fraction (e.g. 0.03), [emittersPerPlant] n.
  static UniformityStats compute(
    List<double> flows, {
    double manufacturerCv = 0,
    int emittersPerPlant = 1,
  }) {
    final q = flows.where((v) => v.isFinite).toList();
    if (q.isEmpty) return empty;
    final n = q.length;
    final mean = q.reduce((a, b) => a + b) / n;
    final sorted = List<double>.from(q)..sort();
    final min = sorted.first, max = sorted.last;
    if (mean <= 0) return UniformityStats(count: n, mean: mean, min: min, max: max, cu: 0, du: 0, eu: 0, us: 0, qvar: 0, cv: 0);
    final absDev = q.fold<double>(0, (s, v) => s + (v - mean).abs()) / n;
    final cu = 100 * (1 - absDev / mean);
    final lqCount = math.max(1, (n / 4).ceil());
    final lqMean = sorted.take(lqCount).reduce((a, b) => a + b) / lqCount;
    final du = 100 * lqMean / mean;
    final variance = q.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) / (n > 1 ? n - 1 : 1);
    final cv = math.sqrt(variance) / mean;
    // Keller & Karmeli (1974) design emission uniformity, as ASAE EP405 and
    // the technical study state it: the minimum emitter flow over the mean
    // (the low-quarter mean belongs to the field DU, and overstated it)
    final eu = 100 * (1 - 1.27 * manufacturerCv / math.sqrt(math.max(1, emittersPerPlant))) * (min / mean);
    final totalCv = math.sqrt(cv * cv + manufacturerCv * manufacturerCv);
    final us = 100 * (1 - totalCv);
    final qvar = max > 0 ? 100 * (max - min) / max : 0.0;
    return UniformityStats(count: n, mean: mean, min: min, max: max, cu: cu, du: du, eu: eu, us: us, qvar: qvar, cv: cv);
  }

  /// ASAE classification for EU / CU.
  static String classify(double value) {
    if (value >= 94) return 'excellent';
    if (value >= 90) return 'good';
    if (value >= 80) return 'fair';
    if (value >= 70) return 'poor';
    return 'unacceptable';
  }

  Map<String, dynamic> toJson() => {
    'count': count, 'mean': mean, 'min': min, 'max': max, 'cu': cu, 'du': du,
    'eu': eu, 'us': us, 'qvar': qvar, 'cv': cv,
  };

  static UniformityStats fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return UniformityStats(count: (j['count'] as num?)?.toInt() ?? 0, mean: d('mean'), min: d('min'), max: d('max'), cu: d('cu'), du: d('du'), eu: d('eu'), us: d('us'), qvar: d('qvar'), cv: d('cv'));
  }
}
