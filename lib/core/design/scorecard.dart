/// Design scorecard (1.7.0 SCR): the quality of a designed project in one
/// page — a transparent index built only from what the design results, the
/// design check, the advisor and the analyses already compute.
///
/// Method (reproducible from the table it prints):
///
/// - Every **indicator** has a value, a target, the source of that target
///   and a score from 0 to 100 given by a **piecewise-linear function**
///   between stated anchors (value → score), held at the end scores beyond
///   the first and the last anchor ([ScoreCurve]). The anchors are class
///   limits of the standards and references the program already cites in its
///   checks and tables, or limits of the project's own design parameters;
///   nothing else:
///   - emission uniformity EU (Keller & Karmeli; the ASAE classes of
///     ASABE EP405.1 as the technical study §9 states them: > 94 %
///     excellent, 90–94 % good, 80–90 % fair, 70–80 % poor, below 70 %
///     unacceptable): 0 → 0, 70 → 60, 80 → 70, 90 → 80, 94 → 90, 100 → 100
///     ([euCurve]);
///   - sprinkler overlap CU (Christiansen; ≥ 85 % satisfactory, Keller &
///     Bliesner 1990 and ISO 15886-3; below 75 % the design check warns,
///     `area_uniformity_low`): 0 → 0, 75 → 60, 85 → 80, 100 → 100
///     ([sprinklerCuCurve]);
///   - emitter flow variation q_var (≤ 10 % desirable, ≤ 20 % acceptable,
///     technical study §9): 0 → 100, 10 → 90, 20 → 70, 100 → 0
///     ([flowVariationCurve]);
///   - a criterion that must hold everywhere (velocity limit, pressure
///     class, pressure window, pump range…) is scored by the share that
///     meets it, weighted by pipe length, by the water the emitters deliver,
///     by flow (times the hours of the system flow for the pumps), by area
///     or by count: 0 % → 0, 100 % → 100 ([shareCurve]);
///   - a count that must be zero (errors, high points without an air
///     valve): 0 → 100, 1 or more → 0 ([noneCurve]).
///
///   The anchor scores follow one convention, the grade bands: A ≥ 90,
///   B ≥ 80, C ≥ 70, D ≥ 60, E below ([scoreGrade]) — the top class of a
///   standard ends at the A limit, the next at B, and so on.
/// - An indicator that cannot be computed (no zone of that kind, no prices,
///   an analysis not run, a pump without an efficiency curve) is **not
///   assessed** and left out of every average; an indicator without any
///   reference target (energy per m³, cost per hectare) is **reported
///   only** and never scored.
/// - A **category** score is the weighted mean of its assessed indicators
///   (every indicator weighs 1); the **overall** score is the weighted mean
///   of the assessed categories (every category weighs 1,
///   [defaultScoreWeights]). The points an indicator would add to the
///   overall score at 100 are (100 − s)·(w / Σw of its category)·(W / ΣW of
///   the assessed categories) ([DesignScorecard.gainOf]); the improvement
///   list is sorted by them.
///
/// The categories and their indicators (see [designScorecard]):
/// uniformity (EU of the drip and micro zones, overlap CU of the sprinkler
/// zones, q_var of every zone, each the flow-weighted mean of the zones),
/// hydraulics (pipe length within the velocity limit of its use and within
/// its pressure class at the water temperature, the water the emitters
/// deliver within their pressure window, zones and pivots given the
/// pressure they need), energy
/// (pump duties within the catalogue range and, with an efficiency curve,
/// within 70–120 % of the best-efficiency flow; the share of the pump head
/// the critical zone needs, the rest being burnt in the valves; kWh per m³
/// and per ha·mm reported), water (sprinkler rate within the soil intake of
/// NEH 15-11, water infiltrated without runoff, share of the peak FAO-56
/// demand the system applies in its irrigation window), economy
/// (life-cycle cost against the cheapest saved alternative; cost per
/// hectare, equivalent annual cost per hectare and energy share of the
/// life-cycle cost reported), robustness (pipes within their class with the
/// Joukowsky surge, pumps with their NPSH margin and suction lift, and,
/// once the ageing test ran, the water within the window and the EU of
/// the design aged and clogged) and completeness (errors and warnings of the
/// Messages list, high points of the mainline without an air valve, priced
/// bill of materials).
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../model/scenario.dart';
import '../translate.dart';
import '../units.dart';
import 'advisor.dart';
import 'area_water.dart' show areaIrrigationMethod, soilRateLimitMmH;
import 'designer.dart' show areaRequirements;
import 'life_cycle.dart' show buildLifeCycleStudy, designAlternative;
import 'life_scenarios.dart' show LifeCase, LifeFigures, LifeOptions;
import 'pump_selection.dart' show wireToWaterEfficiency;
import 'report_tables.dart' show RNum, ReportTable;
import 'results.dart';
import 'runoff_potential.dart' show machineRunoff, zoneRunoff;
import 'system_capacity.dart' show systemCapacity;

/// The categories of the scorecard, in the order they are shown.
enum ScoreCategory { uniformity, hydraulics, energy, water, economy, robustness, completeness }

/// A piecewise-linear scoring function: [anchors] (value, score) with the
/// values ascending; linear between them, the end scores beyond them.
class ScoreCurve {
  const ScoreCurve(this.anchors);
  final List<(double, double)> anchors;

  double at(double x) {
    if (!x.isFinite) return x.isNaN ? 0 : (x > 0 ? anchors.last.$2 : anchors.first.$2);
    if (x <= anchors.first.$1) return anchors.first.$2;
    for (var i = 1; i < anchors.length; i++) {
      final (x1, s1) = anchors[i];
      if (x <= x1) {
        final (x0, s0) = anchors[i - 1];
        return x1 > x0 ? s0 + (s1 - s0) * (x - x0) / (x1 - x0) : s1;
      }
    }
    return anchors.last.$2;
  }
}

/// Emission uniformity EU (%): the ASAE classes of ASABE EP405.1 (technical
/// study §9).
const euCurve = ScoreCurve([(0, 0), (70, 60), (80, 70), (90, 80), (94, 90), (100, 100)]);

/// Overlap CU of sprinklers (%): 85 % satisfactory (Keller & Bliesner 1990;
/// ISO 15886-3), 75 % the limit of the design check.
const sprinklerCuCurve = ScoreCurve([(0, 0), (75, 60), (85, 80), (100, 100)]);

/// Emitter flow variation q_var (%): ≤ 10 % desirable, ≤ 20 % acceptable.
const flowVariationCurve = ScoreCurve([(0, 100), (10, 90), (20, 70), (100, 0)]);

/// Share (%) of what meets a criterion that must hold everywhere.
const shareCurve = ScoreCurve([(0, 0), (100, 100)]);

/// A count that must be zero.
const noneCurve = ScoreCurve([(0, 100), (1, 0)]);

/// Grade of a score: A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, E below.
String scoreGrade(double score) => score >= 90 - 1e-9
    ? 'A'
    : score >= 80 - 1e-9
    ? 'B'
    : score >= 70 - 1e-9
    ? 'C'
    : score >= 60 - 1e-9
    ? 'D'
    : 'E';

/// Every category weighs the same.
const defaultScoreWeights = <ScoreCategory, double>{
  ScoreCategory.uniformity: 1,
  ScoreCategory.hydraulics: 1,
  ScoreCategory.energy: 1,
  ScoreCategory.water: 1,
  ScoreCategory.economy: 1,
  ScoreCategory.robustness: 1,
  ScoreCategory.completeness: 1,
};

/// How the value of an indicator is written.
enum ScoreUnit {
  /// Per cent (uniformities, shares).
  percent,

  /// A count.
  count,

  /// kWh per m³ (with kWh per ha·mm = 10 m³ beside it).
  kwhPerM3,

  /// Money per hectare (per acre in US units).
  moneyPerArea,

  /// Money per hectare a year.
  moneyPerAreaYear,
}

/// Why an indicator is not assessed (`scr.na.<reason>`).
abstract final class ScoreGap {
  /// Nothing in this design for it (no zone of that kind, no pump…).
  static const none = 'none';

  /// The ageing test has not run.
  static const life = 'life';

  /// No saved alternative to compare with.
  static const alternatives = 'alternatives';

  /// No area with a soil class.
  static const soil = 'soil';

  /// No pump with an efficiency curve.
  static const curve = 'curve';

  /// No prices.
  static const prices = 'prices';
}

/// One indicator of the scorecard.
class ScoreIndicator {
  ScoreIndicator({
    required this.key,
    required this.category,
    this.curve,
    this.value,
    this.unit = ScoreUnit.percent,
    this.target = '',
    this.sources = const [],
    this.weight = 1,
    this.detail = '',
    this.entityId,
    this.tool,
    this.gap = ScoreGap.none,
  });

  /// Key: the name is `scr.i.<key>`, the way to improve it `scr.h.<key>`.
  final String key;
  final ScoreCategory category;

  /// The scoring function; null for an indicator reported only.
  final ScoreCurve? curve;

  /// The value in [unit] (null: not assessed).
  final double? value;
  final ScoreUnit unit;

  /// The target, language-neutral ("≥ 94 %", "100 %", "0"); empty when
  /// reported only.
  final String target;

  /// Where the target comes from: standards and references as they are
  /// written, or `scr.src.<key>` (translated; `scr.src.study:9` names a
  /// section of the technical study).
  final List<String> sources;
  final double weight;

  /// The weakest point, language-neutral: "Zone B 87.6 %".
  final String detail;

  /// The item of the weakest point (to select and frame it).
  final String? entityId;

  /// The tool that improves it (see `scorecard_dialog.dart`): `params`,
  /// `autofix`, `pumpSelect`, `densogram`, `programme`, `management`,
  /// `lcc`, `life`, `messages`, `airValves`, `catalog`.
  final String? tool;

  /// Why it is not assessed ([ScoreGap]).
  final String gap;

  /// Reported only: no reference target to score it against.
  bool get informative => curve == null;

  /// The score, or null when not assessed or reported only.
  double? get score {
    final v = value, c = curve;
    if (v == null || c == null || !v.isFinite) return null;
    return c.at(v).clamp(0.0, 100.0).toDouble();
  }

  bool get assessed => value != null && value!.isFinite;

  Map<String, dynamic> toJson() => {
    'key': key,
    'cat': category.name,
    if (value != null) 'v': value,
    'unit': unit.name,
    if (target.isNotEmpty) 't': target,
    if (score != null) 's': score,
    'w': weight,
    if (detail.isNotEmpty) 'd': detail,
    if (!assessed) 'gap': gap,
  };
}

/// One category: its indicators and score.
class ScoreCategoryResult {
  ScoreCategoryResult(this.category, this.weight, this.indicators);
  final ScoreCategory category;
  final double weight;
  final List<ScoreIndicator> indicators;

  /// The indicators with a score.
  List<ScoreIndicator> get scored => [
    for (final i in indicators)
      if (i.score != null && i.weight > 0) i,
  ];

  /// Weighted mean of the scored indicators; null when none is.
  double? get score {
    final s = scored;
    if (s.isEmpty) return null;
    final w = s.fold(0.0, (a, i) => a + i.weight);
    return w > 0 ? s.fold(0.0, (a, i) => a + i.weight * i.score!) / w : null;
  }

  String? get grade => score == null ? null : scoreGrade(score!);
}

/// The scorecard of a design.
class DesignScorecard {
  DesignScorecard(this.categories);
  final List<ScoreCategoryResult> categories;

  List<ScoreIndicator> get indicators => [for (final c in categories) ...c.indicators];

  /// The categories with a score.
  List<ScoreCategoryResult> get assessed => [
    for (final c in categories)
      if (c.score != null && c.weight > 0) c,
  ];

  /// Weighted mean of the assessed categories (null: none is assessed).
  double? get overall {
    final a = assessed;
    if (a.isEmpty) return null;
    final w = a.fold(0.0, (s, c) => s + c.weight);
    return w > 0 ? a.fold(0.0, (s, c) => s + c.weight * c.score!) / w : null;
  }

  String? get grade => overall == null ? null : scoreGrade(overall!);

  ScoreCategoryResult categoryOf(ScoreCategory c) => categories.firstWhere((x) => x.category == c);

  ScoreIndicator? indicator(String key) => indicators.where((i) => i.key == key).firstOrNull;

  /// Share of the overall score indicator [i] stands for: its weight in its
  /// category times its category's weight among the assessed ones (0 when
  /// it is not scored).
  double shareOf(ScoreIndicator i) {
    if (i.score == null || i.weight <= 0) return 0;
    final cat = categoryOf(i.category);
    final iw = cat.scored.fold(0.0, (s, x) => s + x.weight);
    final cw = assessed.fold(0.0, (s, c) => s + c.weight);
    if (iw <= 0 || cw <= 0) return 0;
    return i.weight / iw * cat.weight / cw;
  }

  /// Points the overall score gains when [i] reaches 100 (the others as
  /// they are).
  double gainOf(ScoreIndicator i) => i.score == null ? 0 : (100 - i.score!) * shareOf(i);

  /// The scored indicators below 100, the most points to gain first.
  List<(ScoreIndicator, double)> get improvements {
    final out = [
      for (final i in indicators)
        if (gainOf(i) > 0.05) (i, gainOf(i)),
    ];
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  Map<String, dynamic> toJson() => {
    if (overall != null) 'overall': overall,
    'categories': [
      for (final c in categories)
        {
          'cat': c.category.name,
          'w': c.weight,
          if (c.score != null) 's': c.score,
          'ind': [for (final i in c.indicators) i.toJson()],
        },
    ],
  };
}

// ---------------------------------------------------------------- inputs

/// Weighted mean of (value, weight) pairs; null when they weigh nothing.
double? _mean(Iterable<(double, double)> xs) {
  var s = 0.0, w = 0.0;
  for (final (v, k) in xs) {
    if (!v.isFinite || !(k > 0)) continue;
    s += v * k;
    w += k;
  }
  return w > 0 ? s / w : null;
}

String _pct(double v) => '${fmt(v, 1)} %';

String _nameOf(Project p, String id) {
  final e = p.byId(id);
  if (e is ControlValveEntity && e.zoneName.trim().isNotEmpty) return e.zoneName;
  final n = e?.name ?? '';
  return n.isEmpty ? id : n;
}

/// Whether the emitters of zone [z] are mostly sprinklers or guns (scored by
/// the overlap CU) rather than drippers, tapes, bubblers or
/// micro-sprinklers (scored by the EU of ASABE EP405.1).
bool sprinklerZone(Project p, ZoneResult z) {
  var spr = 0, other = 0;
  for (final o in z.outlets) {
    final e = p.byId(o.entityId);
    final kind = switch (e) {
      OutletEntity x => p.catalog.outlet(x.outletSpecId)?.kind,
      SpraylineEntity x => p.catalog.outlet(x.outletSpecId)?.kind,
      _ => null,
    };
    if (kind == OutletKind.sprinkler || kind == OutletKind.gun) {
      spr += o.count;
    } else {
      other += o.count;
    }
  }
  return spr > other;
}

/// The share (%) of the water of [zones] their emitters deliver within
/// their pressure window (each group of lumped emitters weighs its flow),
/// the zone with the most emitters out of it and "Zone A 306 / 374" (out
/// of the window / emitters of that zone); null without any flow.
(double?, ZoneResult?, String) windowShare(List<ZoneResult> zones) {
  var ok = 0.0, all = 0.0, wOut = 0;
  ZoneResult? w;
  var detail = '';
  for (final z in zones) {
    var outside = 0, count = 0;
    for (final o in z.outlets) {
      final q = o.flow > 0 ? o.flow * o.count : 0.0;
      all += q;
      count += o.count;
      if (o.inWindow) {
        ok += q;
      } else {
        outside += o.count;
      }
    }
    if (outside > wOut) {
      wOut = outside;
      w = z;
      detail = '${z.zoneName} $outside / $count';
    }
  }
  return (all > 0 ? 100 * ok / all : null, w, detail);
}

/// Hours a system flow stands for in the weights (its duration, 1 when not set).
double _hours(SystemFlowResult f) => f.durationHours > 0 ? f.durationHours : 1;

/// One pump duty in a system flow: the pump item, its flow, head, speed and
/// the flow's warnings.
typedef _Duty = ({SystemFlowResult flow, String id, double q, double h, double speed, double weight});

List<_Duty> _pumpDuties(Project p, DesignResults r) => [
  for (final f in r.systemFlows)
    for (final d in f.devices)
      if (d.flow > 1e-12 && p.byId(d.entityId) is PumpEntity) (flow: f, id: d.entityId, q: d.flow, h: d.pumpHead, speed: d.speedRatio, weight: d.flow * _hours(f)),
];

/// A pump of [p] by item id (its catalogue model).
PumpSpec? _specOf(Project p, String id) {
  final e = p.byId(id);
  return e is PumpEntity ? p.catalog.pump(e.pumpSpecId) : null;
}

/// The flow of best efficiency (m³/s, full speed) of [spec]'s efficiency
/// curve; null without a curve of two points or more.
double? bestEfficiencyFlow(PumpSpec spec) {
  if (spec.efficiencyPoints.length < 2) return null;
  var best = spec.efficiencyPoints.first;
  for (final x in spec.efficiencyPoints) {
    if (x.$2 > best.$2) best = x;
  }
  return best.$1 > 0 ? best.$1 : null;
}

/// Energy (kWh) and volume (m³) of one hour of every system flow of [r],
/// times its duration: the pumps on their efficiency curves with their
/// motors and drives, the pump stations by their running pumps, and the
/// calculated supplies at the pump efficiency of the parameters, as the
/// design prices the energy.
(double, double) pumpingEnergy(Project p, DesignResults r) {
  var kwh = 0.0, m3 = 0.0;
  for (final f in r.systemFlows) {
    final hours = _hours(f);
    var w = 0.0;
    for (final s in f.supplies) {
      if (s.calculated && s.requiredHead > 0) w += waterDensity * gravity * s.flow * s.requiredHead / math.max(p.params.pumpEfficiency, 0.05);
    }
    final stations = {for (final s in f.stations) s.entityId: s};
    for (final d in f.devices) {
      if (!(d.pumpHead > 0) || !(d.flow > 0)) continue;
      final st = stations[d.entityId];
      if (st != null) {
        w += 1000 * st.powerKw;
        continue;
      }
      final e = p.byId(d.entityId);
      final eta = wireToWaterEfficiency(_specOf(p, d.entityId), e is PumpEntity ? e : null, d.flow, speed: d.speedRatio, fallback: p.params.pumpEfficiency);
      w += waterDensity * gravity * d.flow * d.pumpHead / math.max(eta, 0.05);
    }
    kwh += w / 1000 * hours;
    m3 += f.totalFlow * 3600 * hours;
  }
  return (kwh, m3);
}

/// Irrigated area (m²) of [p]: its areas with an outline.
double _irrigatedM2(Project p) => p.entities.whereType<AreaEntity>().where((a) => a.points.length >= 3).fold(0.0, (s, a) => s + a.area);

// ---------------------------------------------------------------- the scorecard

/// The scorecard of project [p] designed with results [r].
///
/// [advice] is the Messages list of the project (the design check, the
/// settings and the results, [buildAdvice]; built here when null);
/// [life] the four cases of the ageing test (life_scenarios.dart, run
/// with [lifeOptions]) when it ran; [weights] the weight of every
/// category ([defaultScoreWeights]); [units] write the weakest points.
DesignScorecard designScorecard(
  Project p,
  DesignResults r, {
  List<Advice>? advice,
  List<LifeFigures>? life,
  LifeOptions lifeOptions = const LifeOptions(),
  Map<ScoreCategory, double> weights = defaultScoreWeights,
  Units? units,
  bool alternatives = true,
}) {
  final u = units ?? p.params.units;
  final adv = advice ?? buildAdvice(p, results: r);
  final out = <ScoreIndicator>[];
  String pr(double head) => '${fmt(u.pressureFromHead(head), 1)} ${u.pressureLabel}';

  // ---- uniformity: the zones with emitters, weighted by their flow
  final zones = [
    for (final z in r.zones.values)
      if (z.emitterCount > 0 && z.totalFlow > 0) z,
  ];
  final micro = [
    for (final z in zones)
      if (!sprinklerZone(p, z)) z,
  ];
  final sprink = [
    for (final z in zones)
      if (sprinklerZone(p, z) && z.overlapCu > 0) z,
  ];
  ZoneResult? worst(List<ZoneResult> zs, double Function(ZoneResult z) v, {bool low = true}) => zs.isEmpty ? null : zs.reduce((a, b) => (low ? v(b) < v(a) : v(b) > v(a)) ? b : a);
  {
    final w = worst(micro, (z) => z.uniformity.eu);
    out.add(
      ScoreIndicator(
        key: 'eu',
        category: ScoreCategory.uniformity,
        curve: euCurve,
        value: _mean([for (final z in micro) (z.uniformity.eu, z.totalFlow)]),
        target: '≥ 94 %',
        sources: const ['ASABE EP405.1', 'Keller & Karmeli (1974)'],
        detail: w == null ? '' : '${w.zoneName} ${_pct(w.uniformity.eu)}',
        entityId: w?.valveId,
        tool: 'params',
      ),
    );
  }
  {
    final w = worst(sprink, (z) => z.overlapCu);
    out.add(
      ScoreIndicator(
        key: 'cu',
        category: ScoreCategory.uniformity,
        curve: sprinklerCuCurve,
        value: _mean([for (final z in sprink) (z.overlapCu, z.totalFlow)]),
        target: '≥ 85 %',
        sources: const ['ISO 15886-3', 'Keller & Bliesner (1990)', 'scr.src.check'],
        detail: w == null ? '' : '${w.zoneName} ${_pct(w.overlapCu)}',
        entityId: w?.valveId,
        tool: 'densogram',
      ),
    );
  }
  {
    final w = worst(zones, (z) => z.uniformity.qvar, low: false);
    out.add(
      ScoreIndicator(
        key: 'qvar',
        category: ScoreCategory.uniformity,
        curve: flowVariationCurve,
        value: _mean([for (final z in zones) (z.uniformity.qvar, z.totalFlow)]),
        target: '≤ 10 %',
        sources: const ['Keller & Bliesner (1990)', 'scr.src.study:9'],
        detail: w == null ? '' : '${w.zoneName} ${_pct(w.uniformity.qvar)}',
        entityId: w?.valveId,
        tool: 'params',
      ),
    );
  }

  // ---- hydraulics
  final segs = [for (final l in r.pipesByEntity.values) ...l];
  {
    var ok = 0.0, all = 0.0;
    PipeSegmentResult? w;
    for (final s in segs) {
      final len = s.slopeLength > 0 ? s.slopeLength : s.length;
      all += len;
      if (!s.overVelocity) {
        ok += len;
      } else if (w == null || s.velocity > w.velocity) {
        w = s;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'velocity',
        category: ScoreCategory.hydraulics,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['scr.src.params', 'ASAE S376.2'],
        detail: w == null ? '' : '${_nameOf(p, w.entityId)} ${fmt(u.velocityFromSi(w.velocity), 2)} ${u.velocityLabel}',
        entityId: w?.entityId,
        tool: 'autofix',
      ),
    );
  }
  {
    var ok = 0.0, all = 0.0;
    PipeSegmentResult? w;
    for (final s in segs) {
      if (!(s.pressureRating > 0)) continue;
      final len = s.slopeLength > 0 ? s.slopeLength : s.length;
      all += len;
      if (!s.overPressure) {
        ok += len;
      } else if (w == null || math.max(s.pressureStart, s.pressureEnd) / s.pressureRating > math.max(w.pressureStart, w.pressureEnd) / w.pressureRating) {
        w = s;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'pipeClass',
        category: ScoreCategory.hydraulics,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['ISO 1452-2', 'ISO 4427-2', 'ABNT NBR 14312'],
        detail: w == null ? '' : '${_nameOf(p, w.entityId)} ${pr(math.max(w.pressureStart, w.pressureEnd))} / ${pr(w.pressureRating)}',
        entityId: w?.entityId,
        tool: 'autofix',
      ),
    );
  }
  {
    final (share, w, detail) = windowShare(zones);
    out.add(
      ScoreIndicator(
        key: 'window',
        category: ScoreCategory.hydraulics,
        curve: shareCurve,
        value: share,
        target: '100 %',
        sources: const ['scr.src.params', 'ASABE EP405.1', 'UNE-EN 13742-1'],
        detail: detail,
        entityId: w?.valveId,
        tool: 'autofix',
      ),
    );
  }
  {
    var ok = 0.0, all = 0.0;
    (String, String, double)? w; // id, name, deficit
    void duty(String id, String name, double q, double deficit) {
      if (!deficit.isFinite) return;
      final k = q > 0 ? q : 1e-9;
      all += k;
      if (deficit <= 0.01) {
        ok += k;
      } else if (w == null || deficit > w!.$3) {
        w = (id, name, deficit);
      }
    }

    for (final f in r.systemFlows) {
      for (final v in f.valves) {
        duty(v.valveId, v.zoneName, v.flow, v.deficit);
      }
      for (final h in f.heads) {
        duty(h.stationId, h.name, h.flow, h.deficit);
      }
    }
    out.add(
      ScoreIndicator(
        key: 'valvePressure',
        category: ScoreCategory.hydraulics,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['scr.src.design'],
        detail: w == null ? '' : '${w!.$2.isEmpty ? _nameOf(p, w!.$1) : w!.$2} −${pr(w!.$3)}',
        entityId: w?.$1,
        tool: 'pumpSelect',
      ),
    );
  }

  // ---- energy
  final duties = _pumpDuties(p, r);
  {
    var ok = 0.0, all = 0.0;
    String? w;
    for (final d in duties) {
      all += d.weight;
      final bad = d.flow.warnings.contains('pump_out_of_range:${d.id}') || d.flow.warnings.contains('pump_below_min_flow:${d.id}');
      if (!bad) {
        ok += d.weight;
      } else {
        w ??= d.id;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'pumpRange',
        category: ScoreCategory.energy,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['scr.src.catalog'],
        detail: w == null ? '' : _nameOf(p, w),
        entityId: w,
        tool: 'pumpSelect',
      ),
    );
  }
  {
    // each pump at its homologous full-speed flow q/ω against the flow of
    // its best efficiency; a pump station by its running pumps
    var ok = 0.0, all = 0.0, any = false;
    (String, double)? w;
    void duty(String id, PumpSpec? spec, double q, double speed, double weight) {
      if (spec == null || !(q > 0)) return;
      final qb = bestEfficiencyFlow(spec);
      if (qb == null) return;
      any = true;
      final ratio = q / math.max(speed, 0.05) / qb;
      all += weight;
      if (ratio >= 0.7 - 1e-9 && ratio <= 1.2 + 1e-9) {
        ok += weight;
      } else if (w == null || (ratio - 1).abs() > (w!.$2 - 1).abs()) {
        w = (id, ratio);
      }
    }

    for (final d in duties) {
      final st = d.flow.stations.where((s) => s.entityId == d.id).firstOrNull;
      if (st != null) {
        for (final x in st.units) {
          if (x.running) duty(d.id, p.catalog.pump(x.specId), x.flow, x.speedRatio, x.flow * _hours(d.flow));
        }
      } else {
        duty(d.id, _specOf(p, d.id), d.q, d.speed, d.weight);
      }
    }
    out.add(
      ScoreIndicator(
        key: 'pumpBep',
        category: ScoreCategory.energy,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '70–120 %',
        sources: const ['scr.src.study:12'],
        detail: w == null ? '' : '${_nameOf(p, w!.$1)} ${fmt(100 * w!.$2, 0)} %',
        entityId: w?.$1,
        tool: 'pumpSelect',
        gap: duties.isEmpty || any ? ScoreGap.none : ScoreGap.curve,
      ),
    );
  }
  {
    // the head the pumps add on the way to the critical zone against the
    // surplus left at the supply (burnt in the valves, or passed on to the
    // zones by a valve that does not regulate)
    final xs = <(double, double)>[];
    (String, double)? w;
    for (final f in r.systemFlows) {
      for (final s in f.supplies) {
        final boost = s.pumpBoost ?? f.devices.fold<double>(0, (a, d) => a + math.max(0, d.pumpHead));
        if (!(boost > 1e-6)) continue;
        final waste = math.min(s.surplusHead, boost);
        xs.add((100 * (1 - waste / boost), s.flow * _hours(f)));
        if (waste > 0.01 && (w == null || waste > w.$2)) w = (f.name, waste);
      }
    }
    out.add(
      ScoreIndicator(
        key: 'headUse',
        category: ScoreCategory.energy,
        curve: shareCurve,
        value: _mean(xs),
        target: '100 %',
        sources: const ['scr.src.design'],
        detail: w == null ? '' : '${w.$1} +${pr(w.$2)}',
        tool: 'pumpSelect',
      ),
    );
  }
  {
    final (kwh, m3) = pumpingEnergy(p, r);
    out.add(ScoreIndicator(key: 'specificEnergy', category: ScoreCategory.energy, value: kwh > 0 && m3 > 0 ? kwh / m3 : null, unit: ScoreUnit.kwhPerM3));
  }

  // ---- water
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3) a,
  ];
  final reqs = areas.isEmpty ? const <String, double>{} : {for (final x in areaRequirements(p, r)) x.areaId: x.precipitationMmH};
  {
    var ok = 0.0, all = 0.0;
    var soils = false;
    (AreaEntity, double, double)? w;
    for (final a in areas) {
      final limit = soilRateLimitMmH(a);
      if (limit == null || areaIrrigationMethod(a) != 'sprinkler') continue;
      soils = true;
      final rate = reqs[a.id] ?? 0;
      if (!(rate > 0)) continue;
      all += a.area;
      if (rate <= limit * (1 + 1e-6)) {
        ok += a.area;
      } else if (w == null || rate / limit > w.$2 / w.$3) {
        w = (a, rate, limit);
      }
    }
    out.add(
      ScoreIndicator(
        key: 'rateIntake',
        category: ScoreCategory.water,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['NRCS NEH 15-11'],
        detail: w == null ? '' : '${w.$1.name.isEmpty ? w.$1.id : w.$1.name} ${fmt(w.$2, 1)} / ${fmt(w.$3, 1)} mm/h',
        entityId: w?.$1.id,
        tool: 'programme',
        gap: soils ? ScoreGap.none : ScoreGap.soil,
      ),
    );
  }
  {
    // the depth a sprinkler event (without a pause) or a machine pass sheds,
    // weighted by the area it waters
    final xs = <(double, double)>[];
    (String, String, double)? w; // id, name, runoff %
    final byId = {for (final a in areas) a.id: a};
    for (final z in zoneRunoff(p, results: r)) {
      final pct = z.runoffPct.clamp(0.0, 100.0).toDouble();
      xs.add((100 - pct, byId[z.areaId]?.area ?? 1));
      if (pct > 0.05 && (w == null || pct > w.$3)) w = (z.areaId, z.name, pct);
    }
    for (final m in p.entities.whereType<PivotEntity>()) {
      final mr = machineRunoff(p, m, results: r);
      if (mr == null || mr.rows.isEmpty) continue;
      final pct = mr.worst.runoffPct.clamp(0.0, 100.0).toDouble();
      xs.add((100 - pct, r.pivots[m.id]?.areaM2 ?? 1));
      if (pct > 0.05 && (w == null || pct > w.$3)) w = (m.id, mr.name, pct);
    }
    out.add(
      ScoreIndicator(
        key: 'runoff',
        category: ScoreCategory.water,
        curve: shareCurve,
        value: _mean(xs),
        target: '100 %',
        sources: const ['NRCS NEH 623 ch. 4', 'SWAT/EPA'],
        detail: w == null ? '' : '${w.$2} ${_pct(w.$3)}',
        entityId: w?.$1,
        tool: 'programme',
        gap: xs.isEmpty ? ScoreGap.soil : ScoreGap.none,
      ),
    );
  }
  {
    // the share of the peak gross demand the system applies in its window:
    // the flows one after another, and every machine on its own
    final cap = areas.isEmpty ? null : systemCapacity(p, results: r);
    final shares = <(String?, String, double)>[];
    if (cap != null) {
      if (cap.flows.isNotEmpty && cap.totalHours > 0) {
        final busiest = cap.flows.reduce((a, b) => b.hours > a.hours ? b : a);
        shares.add((busiest.areaId, '${fmt(cap.totalHours, 1)} / ${fmt(cap.windowHours, 1)} h', math.min(1.0, cap.windowHours / cap.totalHours)));
      }
      for (final m in cap.machines) {
        if (m.peakGrossMmDay > 0) shares.add((m.pivotId, '${m.name} ${fmt(m.capacityMmDay, 1)} / ${fmt(m.peakGrossMmDay, 1)} mm/d', math.min(1.0, m.capacityMmDay / m.peakGrossMmDay)));
      }
    }
    final w = shares.isEmpty ? null : shares.reduce((a, b) => b.$3 < a.$3 ? b : a);
    out.add(
      ScoreIndicator(
        key: 'capacity',
        category: ScoreCategory.water,
        curve: shareCurve,
        value: w == null ? null : 100 * w.$3,
        target: '100 %',
        sources: const ['FAO 56', 'scr.src.window'],
        detail: w == null || w.$3 >= 1 ? '' : w.$2,
        entityId: w?.$1,
        tool: 'management',
      ),
    );
  }

  // ---- economy
  {
    double? value;
    var detail = '';
    var gap = ScoreGap.alternatives;
    if (!(r.capitalCost > 0)) {
      gap = ScoreGap.prices;
    } else if (alternatives && p.scenarios.isNotEmpty) {
      final st = buildLifeCycleStudy(p, r);
      final cur = st.alternatives.isEmpty ? null : st.alternatives.first;
      final others = st.alternatives.skip(1).where((a) => a.lcc > 0).toList();
      if (cur != null && cur.lcc > 0 && others.isNotEmpty) {
        final best = [cur, ...others].reduce((a, b) => b.lcc < a.lcc ? b : a);
        value = 100 * best.lcc / cur.lcc;
        if (!identical(best, cur)) detail = best.name;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'lccRank',
        category: ScoreCategory.economy,
        curve: shareCurve,
        value: value,
        target: '100 %',
        sources: const ['NIST Handbook 135', 'scr.src.alternatives'],
        detail: detail,
        tool: 'lcc',
        gap: gap,
      ),
    );
    // reported only: no reference value to score them against
    final alt = r.capitalCost > 0 ? designAlternative(p, r, 'current') : null;
    final ha = _irrigatedM2(p) / 10000;
    final perHa = alt != null && alt.investment > 0 && ha > 0;
    out.add(ScoreIndicator(key: 'capitalPerHa', category: ScoreCategory.economy, value: perHa ? alt.investment / ha : null, unit: ScoreUnit.moneyPerArea, gap: ScoreGap.prices));
    out.add(
      ScoreIndicator(
        key: 'eacPerHa',
        category: ScoreCategory.economy,
        value: perHa && alt.lcc > 0 ? alt.eac / ha : null,
        unit: ScoreUnit.moneyPerAreaYear,
        sources: const ['NIST Handbook 135'],
        gap: ScoreGap.prices,
      ),
    );
    out.add(
      ScoreIndicator(
        key: 'energyShare',
        category: ScoreCategory.economy,
        value: alt != null && alt.lcc > 0 ? 100 * alt.energy / alt.lcc : null,
        sources: const ['NIST Handbook 135'],
        gap: ScoreGap.prices,
      ),
    );
  }

  // ---- robustness
  {
    final checked = [
      for (final s in r.surge)
        if (s.rating > 0) s,
    ];
    final bad = checked.where((s) => s.exceeds).toList()..sort((a, b) => (b.totalHead / b.rating).compareTo(a.totalHead / a.rating));
    final w = bad.firstOrNull;
    out.add(
      ScoreIndicator(
        key: 'surge',
        category: ScoreCategory.robustness,
        curve: shareCurve,
        value: checked.isEmpty ? null : 100 * (checked.length - bad.length) / checked.length,
        target: '100 %',
        sources: const ['AWWA M23', 'AWWA M55'],
        detail: w == null ? '' : '${w.pipeName.isEmpty ? _nameOf(p, w.entityId) : w.pipeName} ${pr(w.totalHead)} / ${pr(w.rating)}',
        entityId: w?.entityId,
        tool: 'params',
      ),
    );
  }
  {
    var ok = 0.0, all = 0.0;
    String? w;
    for (final d in duties) {
      final spec = _specOf(p, d.id);
      if (spec == null || spec.submersible) continue;
      all += d.weight;
      final bad = d.flow.warnings.contains('pump_npsh:${d.id}') || d.flow.warnings.contains('pump_suction_lift:${d.id}');
      if (!bad) {
        ok += d.weight;
      } else {
        w ??= d.id;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'suction',
        category: ScoreCategory.robustness,
        curve: shareCurve,
        value: all > 0 ? 100 * ok / all : null,
        target: '100 %',
        sources: const ['ANSI/HI 9.6.1', 'scr.src.study:12'],
        detail: w == null ? '' : _nameOf(p, w),
        entityId: w,
        tool: 'autofix',
      ),
    );
  }
  {
    final aged = life?.where((f) => f.lifeCase == LifeCase.agedClogged).firstOrNull;
    final opt = 'scr.src.life:${fmt(lifeOptions.years, 0)}|${fmt(lifeOptions.cLoss, 1)}|${fmt(100 * lifeOptions.clogging, 0)}';
    double? window;
    var wd = '';
    String? wid;
    double? eu;
    var ed = '';
    String? eid;
    if (aged != null) {
      final zs = [
        for (final z in aged.results.zones.values)
          if (z.emitterCount > 0 && z.totalFlow > 0) z,
      ];
      final (share, w0, detail) = windowShare(zs);
      window = share;
      wd = detail;
      wid = w0?.valveId;
      final mz = [
        for (final z in zs)
          if (!sprinklerZone(p, z)) z,
      ];
      eu = _mean([for (final z in mz) (z.uniformity.eu, z.totalFlow)]);
      final w = worst(mz, (z) => z.uniformity.eu);
      if (w != null) {
        ed = '${w.zoneName} ${_pct(w.uniformity.eu)}';
        eid = w.valveId;
      }
    }
    out.add(
      ScoreIndicator(
        key: 'agedWindow',
        category: ScoreCategory.robustness,
        curve: shareCurve,
        value: window,
        target: '100 %',
        sources: [opt],
        detail: wd,
        entityId: wid,
        tool: 'life',
        gap: aged == null ? ScoreGap.life : ScoreGap.none,
      ),
    );
    out.add(
      ScoreIndicator(
        key: 'agedEu',
        category: ScoreCategory.robustness,
        curve: euCurve,
        value: eu,
        target: '≥ 94 %',
        sources: ['ASABE EP405.1', opt],
        detail: ed,
        entityId: eid,
        tool: 'life',
        gap: aged == null ? ScoreGap.life : ScoreGap.none,
      ),
    );
  }

  // ---- completeness: the Messages list
  {
    final errors = adv.where((a) => a.level == AdviceLevel.error).toList();
    out.add(
      ScoreIndicator(
        key: 'errors',
        category: ScoreCategory.completeness,
        curve: noneCurve,
        value: errors.length.toDouble(),
        unit: ScoreUnit.count,
        target: '0',
        sources: const ['scr.src.check'],
        detail: errors.isEmpty ? '' : errors.map((a) => a.code).toSet().take(3).join(', '),
        entityId: errors.isEmpty ? null : (errors.first.entityIds.firstOrNull ?? errors.first.contextId),
        tool: 'messages',
      ),
    );
    // the items no warning names; a warning about no item counts as one
    final items = {
      for (final e in p.entities)
        if (e.isHydraulic) e.id,
    };
    final flagged = <String>{};
    var loose = 0;
    final warns = adv.where((a) => a.level == AdviceLevel.warning).toList();
    for (final a in warns) {
      final ids = [
        for (final id in [...a.entityIds, ?a.contextId])
          if (items.contains(id)) id,
      ];
      if (ids.isEmpty) {
        loose++;
      } else {
        flagged.addAll(ids);
      }
    }
    final total = items.length + loose;
    out.add(
      ScoreIndicator(
        key: 'warnings',
        category: ScoreCategory.completeness,
        curve: shareCurve,
        value: items.isEmpty ? null : 100 * (1 - (flagged.length + loose) / total),
        target: '100 %',
        sources: const ['scr.src.check'],
        detail: warns.isEmpty ? '' : '${warns.length}: ${warns.map((a) => a.code).toSet().take(3).join(', ')}',
        entityId: warns.isEmpty ? null : (warns.first.entityIds.firstOrNull ?? warns.first.contextId),
        tool: 'messages',
      ),
    );
    final mainline = r.systemFlows.any((f) => f.pipes.isNotEmpty);
    final missing = [
      for (final m in r.messages)
        if (m.startsWith('air_valve_missing')) m.split(':').skip(1).firstOrNull ?? '',
    ];
    out.add(
      ScoreIndicator(
        key: 'airValves',
        category: ScoreCategory.completeness,
        curve: noneCurve,
        value: mainline ? missing.length.toDouble() : null,
        unit: ScoreUnit.count,
        target: '0',
        sources: const ['AWWA M51'],
        detail: missing.isEmpty ? '' : missing.take(3).map((id) => _nameOf(p, id)).join(', '),
        entityId: missing.firstOrNull,
        tool: 'airValves',
      ),
    );
    final lines = [
      for (final l in r.bom)
        if (l.specId != null && l.quantity > 0 && p.catalog.outlet(l.specId)?.kind != OutletKind.demandPoint) l,
    ];
    final unpriced = lines.where((l) => !(l.unitCost > 0)).toList();
    out.add(
      ScoreIndicator(
        key: 'priced',
        category: ScoreCategory.completeness,
        curve: shareCurve,
        value: lines.isEmpty ? null : 100 * (lines.length - unpriced.length) / lines.length,
        target: '100 %',
        sources: const ['scr.src.bom'],
        detail: unpriced.isEmpty ? '' : '${unpriced.length} / ${lines.length}',
        tool: 'catalog',
      ),
    );
  }
  return DesignScorecard([
    for (final c in ScoreCategory.values)
      ScoreCategoryResult(c, weights[c] ?? 1, [
        for (final i in out)
          if (i.category == c) i,
      ]),
  ]);
}

/// The scorecard of the alternative [sc] (saved with Design → Alternatives
/// with its results), or null when it was saved without them or cannot be
/// read. Its life-cycle comparison is left out (it would compare the
/// alternative with itself).
DesignScorecard? scenarioScorecard(Scenario sc) {
  try {
    final res = sc.snapshot['results'];
    if (res is! Map) return null;
    final q = Project.fromJson(Map<String, dynamic>.of(sc.snapshot)..remove('results'));
    final r = DesignResults.fromJson(res.cast<String, dynamic>());
    if (r.zones.isEmpty && r.systemFlows.isEmpty && r.pivots.isEmpty) return null;
    return designScorecard(q, r, alternatives: false);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------- text

/// The source [s] of an indicator in words: a standard as it is written, or
/// a `scr.src.<key>` (with its arguments after ':').
String scoreSourceText(String s, Translate t) {
  if (!s.startsWith('scr.src.')) return s;
  final i = s.indexOf(':');
  final key = i < 0 ? s : s.substring(0, i);
  final arg = i < 0 ? '' : s.substring(i + 1);
  if (key == 'scr.src.life') {
    final a = arg.split('|');
    return t(key, {'y': a.elementAtOrNull(0) ?? '', 'c': a.elementAtOrNull(1) ?? '', 'k': a.elementAtOrNull(2) ?? ''});
  }
  return t(key, {'s': arg});
}

/// The value of [i] as the scorecard writes it, in [u] ([currency] for
/// money; [yr] the word for a year).
String scoreValueText(ScoreIndicator i, Units u, {String currency = '', String yr = 'yr'}) {
  final v = i.value;
  if (v == null || !v.isFinite) return '';
  final perArea = u.areaFromSi(10000) > 0 ? u.areaFromSi(10000) : 1.0; // area units in a hectare
  return switch (i.unit) {
    ScoreUnit.percent => _pct(v),
    ScoreUnit.count => '${v.round()}',
    ScoreUnit.kwhPerM3 => '${fmt(v, 3)} kWh/m³ · ${fmt(10 * v, 2)} kWh/(ha·mm)',
    ScoreUnit.moneyPerArea => '$currency ${fmt(v / perArea, 0)}/${u.areaLabel}',
    ScoreUnit.moneyPerAreaYear => '$currency ${fmt(v / perArea, 0)}/${u.areaLabel}·$yr',
  };
}

/// A report table built the first time its rows are read: the scorecard
/// in the report tables costs nothing until a report, an export or the
/// assistant reads it (the reports panel rebuilds its tables after every
/// edit).
class LazyReportTable extends ReportTable {
  LazyReportTable({required super.key, required super.title, required super.headers, required this.build}) : super(rows: const []);

  /// Builds the table (once).
  final ReportTable Function() build;
  late final ReportTable _table = build();

  @override
  List<List<Object>> get rows => _table.rows;

  @override
  List<bool> get warn => _table.warn;

  @override
  List<String?> get ids => _table.ids;
}

/// The columns of [scorecardTable].
List<String> scorecardHeaders(Translate t) => [
  t('scr.col.category'),
  t('scr.col.indicator'),
  t('scr.col.value'),
  t('scr.col.target'),
  t('scr.col.source'),
  t('scr.col.score'),
  t('scr.col.grade'),
  t('scr.col.weight'),
  t('scr.col.gain'),
  t('scr.col.improve'),
];

/// The scorecard as a report table (key `scorecard`): the overall score,
/// then each category and its indicators — value, target, source, score,
/// grade, weight, the points to gain and how to improve it.
ReportTable scorecardTable(DesignScorecard s, {required Translate t, required Units units, String currency = ''}) {
  final yr = t('prb.lcc.yr');
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  final o = s.overall;
  rows.add([t('scr.overall'), '', '', '', '', o == null ? '-' : RNum(o, 1), s.grade ?? '-', '', '', '']);
  warn.add(o != null && o < 60);
  ids.add(null);
  for (final c in s.categories) {
    final cs = c.score;
    rows.add([t('scr.c.${c.category.name}'), '', '', '', '', cs == null ? '-' : RNum(cs, 1), c.grade ?? t('scr.na.${ScoreGap.none}'), RNum(c.weight, 0), '', '']);
    warn.add(cs != null && cs < 60);
    ids.add(null);
    for (final i in c.indicators) {
      final sc = i.score;
      rows.add([
        '',
        t('scr.i.${i.key}'),
        i.assessed ? scoreValueText(i, units, currency: currency, yr: yr) : t('scr.na.${i.gap}'),
        i.target.isEmpty ? '-' : i.target,
        [for (final x in i.sources) scoreSourceText(x, t)].join('; '),
        sc == null ? '-' : RNum(sc, 0),
        sc == null ? '-' : scoreGrade(sc),
        i.informative ? '-' : RNum(i.weight, 0),
        sc == null ? '-' : RNum(s.gainOf(i), 1),
        if (i.informative && i.assessed) t('scr.reported') else if (sc == null || sc >= 99.95) i.detail else '${i.detail.isEmpty ? '' : '${i.detail} — '}${t('scr.h.${i.key}')}',
      ]);
      warn.add(sc != null && sc < 60);
      ids.add(i.entityId);
    }
  }
  return ReportTable(key: 'scorecard', title: t('scr.title'), headers: scorecardHeaders(t), rows: rows, warn: warn, ids: ids);
}
