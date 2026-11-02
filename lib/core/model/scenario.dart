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

  /// The project as it was ([scenarioSnapshot]: with the results of its
  /// design, without its own alternatives nor the pictures of its images
  /// and comments, which restoring takes from the current project).
  final Map<String, dynamic> snapshot;

  /// Metrics in the project currency (converted with the prices).
  static const moneyMetricKeys = {'capital', 'annualEnergy', 'annualTotal'};

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'created': created.toIso8601String(), 'metrics': metrics, 'project': snapshot};

  /// Reads an alternative; the pictures embedded in alternatives saved by
  /// earlier versions (a copy of every image in each) are dropped here.
  static Scenario fromJson(Map<String, dynamic> j) => Scenario(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
    metrics: {
      for (final e in ((j['metrics'] as Map?) ?? const {}).entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
    },
    snapshot: Map<String, dynamic>.of(withoutMedia((j['project'] as Map?)?.cast<String, dynamic>() ?? const {})),
  );

  /// The project this alternative keeps, with the pictures of its images and
  /// comments taken from [current] (the same entity ids) and without
  /// results; null when the snapshot cannot be read.
  Project? restoredInto(Project current) {
    final Project p;
    try {
      p = Project.fromJson(Map<String, dynamic>.of(snapshot)..remove('results'));
    } catch (_) {
      return null;
    }
    for (final e in p.entities) {
      final now = current.byId(e.id);
      if (e is ImageEntity && e.data == null && now is ImageEntity) e.data = now.data;
      if (e is CommentEntity && e.photo.isEmpty && now is CommentEntity) e.photo = now.photo;
    }
    return p;
  }

  /// Switches the alternative to currency [code] ([symbol]); with [rate]
  /// (units of the new currency per unit of the old) its money metrics and
  /// the prices of its project are converted, and its results, priced in
  /// the old currency, are dropped (restoring it then asks for a design).
  void convertCurrency(String code, String symbol, {double? rate}) {
    if (rate != null && rate != 1) {
      for (final k in moneyMetricKeys) {
        final v = metrics[k];
        if (v != null) metrics[k] = v * rate;
      }
    }
    if (snapshot.isEmpty) return;
    final Project p;
    try {
      p = Project.fromJson(Map<String, dynamic>.of(snapshot)..remove('results'));
    } catch (_) {
      return;
    }
    if (rate != null) p.scalePrices(rate);
    p.params
      ..currencyCode = code
      ..currency = symbol;
    final keepResults = rate == null || rate == 1;
    final results = snapshot['results'];
    snapshot
      ..clear()
      ..addAll(scenarioSnapshot(p))
      ..remove('scenarios');
    if (keepResults && results != null) snapshot['results'] = results;
  }
}

/// What an alternative keeps of [p]: the project as it is, with [results]
/// when given, but without its own alternatives and without the pictures
/// embedded in images and the photos of comments. Those stay in the project
/// ([Scenario.restoredInto] takes them back), so alternatives neither
/// multiply the size of the file nor carry photos into shared links.
Map<String, dynamic> scenarioSnapshot(Project p, [DesignResults? results]) {
  final j = withoutMedia(p.toJson()..remove('scenarios'));
  if (results != null) j['results'] = results.toJson();
  return j;
}

/// [project] (project JSON) without the bytes of its images nor the photos
/// of its comments.
Map<String, dynamic> withoutMedia(Map<String, dynamic> project) {
  final ents = project['entities'];
  if (ents is! List || !ents.any((e) => e is Map && ((e['type'] == 'image' && e['data'] != null) || (e['type'] == 'comment' && e['photo'] != null)))) return project;
  return {
    ...project,
    'entities': [
      for (final e in ents)
        if (e is Map && e['type'] == 'image' && e['data'] != null)
          (Map<String, dynamic>.of(e.cast<String, dynamic>())..remove('data'))
        else if (e is Map && e['type'] == 'comment' && e['photo'] != null)
          (Map<String, dynamic>.of(e.cast<String, dynamic>())..remove('photo'))
        else
          e,
    ],
  };
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
