/// Ageing and clogging of a designed project (1.6.0 MOT+): the project
/// analysed again with the pipes it was designed with, after years of use —
/// the pipes rougher (the Hazen-Williams C falling by so many points a year,
/// the Darcy-Weisbach roughness growing by so many millimetres a year) and
/// the emitters partly clogged (their flow coefficient down by a share,
/// their manufacturing variation up) — against the new design: flows,
/// emitter pressures, uniformity, the pressure the valves lack, what the
/// supplies and the pumps must give and the energy, to show the margin of
/// the design over its life.
///
/// The Hazen-Williams C of plastic pipes falls slowly (biofilm and deposits:
/// about 130–140 after decades from 150); metal pipes lose much more. The
/// clogging of drippers depends on the water and its treatment: a tenth of
/// the flow lost and a doubled variation are a common check. The defaults
/// are such a check, not a forecast.
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/emitter.dart';
import '../model/project.dart';
import 'analysis_control.dart';
import 'designer.dart';
import 'results.dart';

/// How the project ages.
class LifeOptions {
  const LifeOptions({this.years = 15, this.cLossPerYear = 0.5, this.roughnessMmPerYear = 0.01, this.clogging = 0.10, this.cvIncrease = 0.05});

  /// Years of use.
  final double years;

  /// Hazen-Williams C points lost a year (pipes and tapes).
  final double cLossPerYear;

  /// Darcy-Weisbach roughness gained a year (mm).
  final double roughnessMmPerYear;

  /// Share of the emitter flow lost to clogging (0–0.9).
  final double clogging;

  /// Added to the manufacturing coefficient of variation of the emitters.
  final double cvIncrease;

  /// Hazen-Williams C points lost over [years].
  double get cLoss => math.max(0, years * cLossPerYear);

  /// Darcy-Weisbach roughness gained over [years] (mm).
  double get roughnessGain => math.max(0, years * roughnessMmPerYear);

  Map<String, dynamic> toJson() => {'years': years, 'cLoss': cLossPerYear, 'rough': roughnessMmPerYear, 'clog': clogging, 'cv': cvIncrease};
}

/// The cases compared.
enum LifeCase {
  /// The project as designed.
  asNew,

  /// The pipes after [LifeOptions.years].
  aged,

  /// The emitters clogged.
  clogged,

  /// Both.
  agedClogged,
}

/// The key figures of one case.
class LifeFigures {
  LifeFigures({
    required this.lifeCase,
    required this.results,
    required this.peakFlow,
    required this.minEu,
    required this.minCu,
    required this.minPressure,
    required this.maxPressure,
    required this.worstDeficit,
    required this.supplyHead,
    required this.pumpHead,
    required this.annualEnergy,
    required this.zonesOutOfWindow,
    required this.zoneCount,
  });

  final LifeCase lifeCase;
  final DesignResults results;

  /// Largest system flow (m³/s).
  final double peakFlow;

  /// Worst zone emission uniformity and Christiansen uniformity (%).
  final double minEu;
  final double minCu;

  /// Lowest and highest emitter pressure (m).
  final double minPressure;
  final double maxPressure;

  /// Largest pressure a valve or pivot lacks (m; 0 = none lacks).
  final double worstDeficit;

  /// Largest pressure a supply needs (m) and highest pump head (m).
  final double supplyHead;
  final double pumpHead;

  /// Energy cost a year (project currency).
  final double annualEnergy;

  /// Zones whose emitters leave their pressure window, of [zoneCount].
  final int zonesOutOfWindow;
  final int zoneCount;
}

/// The figures of [r] for [lifeCase].
LifeFigures lifeFiguresOf(LifeCase lifeCase, DesignResults r) {
  var eu = double.infinity, cu = double.infinity, pMin = double.infinity, pMax = -double.infinity;
  var out = 0, zones = 0;
  for (final z in r.zones.values) {
    if (z.emitterCount == 0) continue;
    zones++;
    eu = math.min(eu, z.uniformity.eu);
    cu = math.min(cu, z.uniformity.cu);
    pMin = math.min(pMin, z.minOutletPressure);
    pMax = math.max(pMax, z.maxOutletPressure);
    if (!z.withinWindow) out++;
  }
  var peak = 0.0, deficit = 0.0, supply = 0.0, pump = 0.0;
  for (final f in r.systemFlows) {
    peak = math.max(peak, f.totalFlow);
    for (final v in f.valves) {
      deficit = math.max(deficit, v.deficit);
    }
    for (final s in f.supplies) {
      supply = math.max(supply, s.requiredHead);
    }
    for (final d in f.devices) {
      pump = math.max(pump, d.pumpHead);
    }
  }
  return LifeFigures(
    lifeCase: lifeCase,
    results: r,
    peakFlow: peak,
    minEu: eu.isFinite ? eu : 0,
    minCu: cu.isFinite ? cu : 0,
    minPressure: pMin.isFinite ? pMin : 0,
    maxPressure: pMax.isFinite ? pMax : 0,
    worstDeficit: deficit,
    supplyHead: supply,
    pumpHead: pump,
    annualEnergy: r.annualEnergyCost,
    zonesOutOfWindow: out,
    zoneCount: zones,
  );
}

/// A copy of [p] (a designed project: its pipes carry their sizes) in
/// [lifeCase] after [o]: the pipes and tapes aged (Hazen-Williams C down by
/// [LifeOptions.cLoss] points through the C offset of the parameters,
/// Darcy-Weisbach roughness up by [LifeOptions.roughnessGain] mm), the
/// emitters clogged (flow coefficients × (1 − [LifeOptions.clogging]),
/// variation + [LifeOptions.cvIncrease]).
Project lifeProject(Project p, LifeCase lifeCase, LifeOptions o) {
  final q = p.copy();
  final aged = lifeCase == LifeCase.aged || lifeCase == LifeCase.agedClogged;
  final clogged = lifeCase == LifeCase.clogged || lifeCase == LifeCase.agedClogged;
  if (aged) {
    q.params.hazenCOffset -= o.cLoss;
    for (final s in q.catalog.pipes) {
      s.roughnessMm += o.roughnessGain;
    }
    for (final t in q.catalog.tapes) {
      t.roughnessMm += o.roughnessGain;
    }
  }
  if (clogged) {
    final keep = (1 - o.clogging).clamp(0.1, 1.0);
    EmitterCurve clog(EmitterCurve c) => EmitterCurve(k: c.k * keep, x: c.x, radiusA: c.radiusA, radiusB: c.radiusB, compensationHead: c.compensationHead);
    for (final out in q.catalog.outlets) {
      for (final n in out.nozzles) {
        n.curve = clog(n.curve);
        n.cv += o.cvIncrease;
      }
    }
    for (final t in q.catalog.tapes) {
      t.emitter = clog(t.emitter);
      t.cv += o.cvIncrease;
    }
  }
  return q;
}

/// The messages of the comparison: `life_method_not_aged` when the friction
/// method is neither Hazen-Williams nor Darcy-Weisbach (their coefficients
/// are what ages), `life_no_design` without design results.
List<String> lifeNotes(Project p, DesignResults? asNew) => [
  if (asNew == null) 'life_no_design',
  if (p.params.frictionMethod == FrictionMethod.scobey || p.params.frictionMethod == FrictionMethod.manning) 'life_method_not_aged',
];

/// The steps of the comparison of [p]: one per case, [asNew] standing for
/// the new design when given (the results of the latest design), the
/// figures handed to [done] in the order of [LifeCase].
Iterable<AnalysisStep> lifeScenarioSteps(Project p, LifeOptions o, void Function(List<LifeFigures> figures) done, {DesignResults? asNew, String Function(String key)? label}) sync* {
  final out = <LifeFigures>[];
  const total = 4;
  for (final k in LifeCase.values) {
    yield (out.length, total);
    final r = k == LifeCase.asNew && asNew != null ? asNew : Designer(lifeProject(p, k, o), label: label).analyzeAll();
    out.add(lifeFiguresOf(k, r));
  }
  yield (total, total);
  done(out);
}

/// Every case of [LifeCase] for [p] at once (see [lifeScenarioSteps]).
List<LifeFigures> lifeScenarios(Project p, {LifeOptions options = const LifeOptions(), DesignResults? asNew, String Function(String key)? label}) {
  var out = const <LifeFigures>[];
  runSteps(lifeScenarioSteps(p, options, (f) => out = f, asNew: asNew, label: label));
  return out;
}

/// Every case of [LifeCase] for [p], a case at a time with the event loop
/// given a turn between them; [control] hears the progress and can stop it
/// ([AnalysisCancelled]).
Future<List<LifeFigures>> lifeScenariosAsync(Project p, {LifeOptions options = const LifeOptions(), DesignResults? asNew, String Function(String key)? label, AnalysisControl? control}) async {
  var out = const <LifeFigures>[];
  await runStepsAsync(lifeScenarioSteps(p, options, (f) => out = f, asNew: asNew, label: label), control);
  return out;
}
