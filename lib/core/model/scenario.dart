/// Design alternatives kept inside the project: a named copy of the project
/// with the key figures of its design, to compare side by side and restore.
library;

import 'dart:math' as math;

import '../design/results.dart';
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

/// Figures compared between alternatives (keys of [Scenario.metrics],
/// translated as `scn.<key>`).
const scenarioMetricKeys = ['capital', 'annualEnergy', 'annualTotal', 'peakFlow', 'pumpHead', 'pMin', 'pMax', 'euMin', 'cuMin', 'mainlineM', 'zonePipeM', 'messages'];

class Scenario {
  Scenario({required this.id, required this.name, required this.created, required this.metrics, required this.snapshot});
  final String id;
  String name;
  final DateTime created;

  /// Figures of the design when it was saved (see [scenarioMetricKeys]);
  /// SI or project currency.
  final Map<String, double> metrics;

  /// The project as it was (without its alternatives and results).
  final Map<String, dynamic> snapshot;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'created': created.toIso8601String(), 'metrics': metrics, 'project': snapshot};
  static Scenario fromJson(Map<String, dynamic> j) => Scenario(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
    metrics: {
      for (final e in ((j['metrics'] as Map?) ?? const {}).entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
    },
    snapshot: (j['project'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

/// Key figures of a designed project: investment and yearly costs, the peak
/// system flow and the highest pump head, the lowest and highest emitter
/// pressure and the worst zone uniformity, pipe lengths and the number of
/// design messages.
Map<String, double> scenarioMetrics(Project p, DesignResults r) {
  var pMin = double.infinity, pMax = 0.0, euMin = double.infinity, cuMin = double.infinity;
  for (final z in r.zones.values) {
    if (z.emitterCount == 0) continue;
    pMin = math.min(pMin, z.minOutletPressure);
    pMax = math.max(pMax, z.maxOutletPressure);
    euMin = math.min(euMin, z.uniformity.eu);
    cuMin = math.min(cuMin, z.uniformity.cu);
  }
  var peak = 0.0, head = 0.0;
  for (final f in r.systemFlows) {
    peak = math.max(peak, f.totalFlow);
    for (final d in f.devices) {
      head = math.max(head, d.pumpHead);
    }
  }
  var main = 0.0, zone = 0.0;
  for (final e in p.entities.whereType<PipeEntity>()) {
    final len = polylineLength(e.points);
    if (e.scope == HydraulicScope.mainline) {
      main += len;
    } else {
      zone += len;
    }
  }
  var messages = r.messages.length;
  for (final z in r.zones.values) {
    messages += z.warnings.length;
  }
  for (final f in r.systemFlows) {
    messages += f.warnings.length;
  }
  return {
    'capital': r.capitalCost,
    'annualEnergy': r.annualEnergyCost,
    'annualTotal': r.annualCapitalCost + r.annualEnergyCost,
    'peakFlow': peak,
    'pumpHead': head,
    if (pMin.isFinite) 'pMin': pMin,
    if (pMin.isFinite) 'pMax': pMax,
    if (euMin.isFinite) 'euMin': euMin,
    if (cuMin.isFinite) 'cuMin': cuMin,
    'mainlineM': main,
    'zonePipeM': zone,
    'messages': messages.toDouble(),
  };
}
