/// Tariff-aware scheduling of the system flows: a time-of-use tariff (energy
/// price by band of the day, demand charges, seasons) and an irrigation
/// discount in a window the consumer chooses, as in the Brazilian rule of
/// Portaria Normativa MME nº 137, de 8 de junho de 2026: up to 8 h 30 min a
/// day, continuous or in up to three blocks of whole half hours, never
/// between 17:00 and 21:30, possibly different by season, with the discount
/// percentages of Resolução Normativa ANEEL nº 1.000/2021, art. 186, which
/// apply to the consumption (energy) tariff. Given the jobs (system flows,
/// each with its daily duration and electrical power, precedences, a daily
/// limit of pumping hours), the scheduler chooses the start times and the
/// discount blocks that minimise the daily cost.
///
/// Method. The system flows run one at a time (the network is designed for
/// one flow at a time) and every day the same, inside a scheduling day that
/// starts at the end of the excluded interval (21:30) unless set otherwise;
/// no job runs across that instant. The day is cut into steps (15 min by
/// default): starts fall on steps and durations are rounded up to whole steps
/// for the packing, while the costs use the exact minutes. The discount is
/// decided per half hour. For a given job order a dynamic programme over the
/// steps, whose state is the job running (and how far it is), the discounted
/// half hours used, the blocks opened, whether the current half hour is
/// discounted and (when a block may cross the start of the day) whether the
/// first one was, finds the start times and the blocks together, exactly.
/// When the precedences leave few orders (24 by default) every order is
/// solved and the schedule is optimal for the model. With more jobs the
/// method is a documented heuristic. It starts from the given,
/// power-descending and power-ascending orders and, up to 8 jobs, from the
/// best order for one window of the whole discount at every place it fits;
/// from each it alternates (a) the best order for the blocks of the current
/// plan — exact over every order by a dynamic programme over subsets of jobs
/// up to 12 jobs, pairwise swaps and insertions beyond — and (b) the exact
/// joint programme for that order, while the cost falls, and keeps the best
/// plan. A peak demand charge (on the highest power drawn in peak bands) is
/// handled exactly by solving once per cap on the power allowed in the peak.
/// Everything is deterministic.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../hydraulics/pump.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'results.dart';

const int _day = 1440;

/// A band of the day with its energy price: from [startMinute] (inclusive)
/// to [endMinute] (exclusive), minutes after midnight; a band whose end is
/// not after its start wraps past midnight (equal: the whole day).
class TariffBand {
  const TariffBand({required this.startMinute, required this.endMinute, required this.pricePerKwh, this.peak = false});
  final int startMinute;
  final int endMinute;
  final double pricePerKwh;

  /// Peak band: the peak demand charge applies to the highest power drawn
  /// in it.
  final bool peak;

  bool covers(int minute) {
    final m = minute % _day, s = startMinute % _day, e = endMinute % _day;
    if (s == e) return true;
    return s < e ? m >= s && m < e : m >= s || m < e;
  }

  Map<String, dynamic> toJson() => {'s': startMinute, 'e': endMinute, 'p': pricePerKwh, if (peak) 'peak': true};
  static TariffBand fromJson(Map<String, dynamic> j) => TariffBand(startMinute: (j['s'] as num).toInt(), endMinute: (j['e'] as num).toInt(), pricePerKwh: (j['p'] as num?)?.toDouble() ?? 0, peak: j['peak'] as bool? ?? false);
}

/// Consumer groups of the Brazilian tariff (Group A: medium and high
/// voltage; Group B: low voltage).
enum BrazilConsumerGroup { a, b }

/// Regions of the irrigation discount: the Northeast and the other
/// municipalities in the area of SUDENE; the North, the Centre-West and the
/// other municipalities of Minas Gerais; the other regions.
enum BrazilDiscountRegion { northeastSudene, northCentreWestMinas, others }

/// Irrigation discount on the consumption tariff by group and region
/// (Resolução Normativa ANEEL nº 1.000/2021, art. 186).
const brazilIrrigationDiscounts = <BrazilConsumerGroup, Map<BrazilDiscountRegion, double>>{
  BrazilConsumerGroup.a: {BrazilDiscountRegion.northeastSudene: 0.90, BrazilDiscountRegion.northCentreWestMinas: 0.80, BrazilDiscountRegion.others: 0.70},
  BrazilConsumerGroup.b: {BrazilDiscountRegion.northeastSudene: 0.73, BrazilDiscountRegion.northCentreWestMinas: 0.67, BrazilDiscountRegion.others: 0.60},
};

/// A discount on the energy price inside a daily window the consumer
/// chooses: at most [windowMinutes] a day, in at most [maxBlocks] blocks of
/// whole [blockMinutes] aligned to the clock, none of them touching the
/// [excluded] clock intervals. The defaults are the Brazilian rule (8 h 30
/// min, three blocks, half hours, never 17:00–21:30).
class IrrigationDiscount {
  const IrrigationDiscount({required this.fraction, this.windowMinutes = 510, this.maxBlocks = 3, this.blockMinutes = 30, this.excluded = const [(1020, 1290)]});

  /// The Brazilian discount of [group] in [region].
  factory IrrigationDiscount.brazil(BrazilConsumerGroup group, BrazilDiscountRegion region) => IrrigationDiscount(fraction: brazilIrrigationDiscounts[group]![region]!);

  /// Share taken off the energy price (0.6 = 60 %).
  final double fraction;
  final int windowMinutes;
  final int maxBlocks;
  final int blockMinutes;

  /// (start, end) clock minutes never discounted.
  final List<(int, int)> excluded;

  Map<String, dynamic> toJson() => {'f': fraction, 'w': windowMinutes, 'b': maxBlocks, 'g': blockMinutes, 'x': [for (final (s, e) in excluded) [s, e]]};
  static IrrigationDiscount fromJson(Map<String, dynamic> j) => IrrigationDiscount(
    fraction: (j['f'] as num?)?.toDouble() ?? 0, windowMinutes: (j['w'] as num?)?.toInt() ?? 510, maxBlocks: (j['b'] as num?)?.toInt() ?? 3, blockMinutes: (j['g'] as num?)?.toInt() ?? 30,
    excluded: [for (final x in (j['x'] as List?) ?? const [[1020, 1290]]) (((x as List)[0] as num).toInt(), (x[1] as num).toInt())],
  );
}

/// The tariff of a season: energy price by band, demand charges and the
/// irrigation discount.
class TariffSeason {
  const TariffSeason({this.id = '', this.months = const {}, this.bands = const [], this.basePricePerKwh = 0, this.demandChargePerKw = 0, this.peakDemandChargePerKw = 0, this.daysPerMonth = 30, this.discount});
  final String id;

  /// Months (1–12) of the season; empty = the whole year.
  final Set<int> months;

  /// Price bands; a minute takes the price of the last band covering it, or
  /// [basePricePerKwh] when none does.
  final List<TariffBand> bands;
  final double basePricePerKwh;

  /// Monthly charges per kW of the highest power drawn at any time and in
  /// the peak bands; a day carries 1/[daysPerMonth] of them.
  final double demandChargePerKw;
  final double peakDemandChargePerKw;
  final double daysPerMonth;
  final IrrigationDiscount? discount;

  double priceAt(int minute) {
    var p = basePricePerKwh;
    for (final b in bands) {
      if (b.covers(minute)) p = b.pricePerKwh;
    }
    return p;
  }

  bool peakAt(int minute) {
    var peak = false;
    for (final b in bands) {
      if (b.covers(minute)) peak = b.peak;
    }
    return peak;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'months': months.toList()..sort(), 'bands': bands.map((b) => b.toJson()).toList(), 'base': basePricePerKwh, 'dem': demandChargePerKw, 'peakDem': peakDemandChargePerKw, 'days': daysPerMonth,
    if (discount != null) 'disc': discount!.toJson(),
  };
  static TariffSeason fromJson(Map<String, dynamic> j) => TariffSeason(
    id: j['id'] as String? ?? '', months: {for (final m in (j['months'] as List?) ?? []) (m as num).toInt()}, bands: [for (final b in (j['bands'] as List?) ?? []) TariffBand.fromJson(b as Map<String, dynamic>)],
    basePricePerKwh: (j['base'] as num?)?.toDouble() ?? 0, demandChargePerKw: (j['dem'] as num?)?.toDouble() ?? 0, peakDemandChargePerKw: (j['peakDem'] as num?)?.toDouble() ?? 0, daysPerMonth: (j['days'] as num?)?.toDouble() ?? 30,
    discount: j['disc'] is Map<String, dynamic> ? IrrigationDiscount.fromJson(j['disc'] as Map<String, dynamic>) : null,
  );
}

/// A tariff made of seasons.
class Tariff {
  const Tariff(this.seasons);
  final List<TariffSeason> seasons;

  /// The season of [month] (1–12): the first that lists it, else the first
  /// without months.
  TariffSeason? seasonFor(int month) {
    for (final s in seasons) {
      if (s.months.contains(month)) return s;
    }
    for (final s in seasons) {
      if (s.months.isEmpty) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'seasons': seasons.map((s) => s.toJson()).toList()};
  static Tariff fromJson(Map<String, dynamic> j) => Tariff([for (final s in (j['seasons'] as List?) ?? []) TariffSeason.fromJson(s as Map<String, dynamic>)]);
}

/// A job to schedule: a system flow running [hours] a day drawing
/// [powerKw] (electrical).
class TariffJob {
  const TariffJob({required this.id, required this.hours, required this.powerKw, this.after = const {}, this.startHour});
  final String id;
  final double hours;
  final double powerKw;

  /// Jobs that must end before this one starts, within the scheduling day.
  final Set<String> after;

  /// Current start (clock hour), for the comparison with the schedule as it
  /// is (e.g. SystemFlow.startHour); null = right after the previous job.
  final double? startHour;
}

/// Options of [scheduleJobs].
class ScheduleOptions {
  const ScheduleOptions({this.stepMinutes = 15, this.maxHoursPerDay = 0, this.dayStartMinute, this.keepOrder = false, this.noRunIntervals = const [], this.exhaustiveOrders = 24});

  /// Resolution of the start times (a divisor of the discount block; 15 min
  /// by default). Durations are rounded up to it for the packing only.
  final int stepMinutes;

  /// Most pumping hours a day (0 = no limit): a violation when exceeded.
  final double maxHoursPerDay;

  /// Clock minute the scheduling day starts (no job runs across it); null =
  /// the end of the first excluded interval of the discount, else midnight.
  final int? dayStartMinute;

  /// Run the jobs in the order given.
  final bool keepOrder;

  /// (start, end) clock intervals without pumping.
  final List<(int, int)> noRunIntervals;

  /// Every order is solved when the precedences leave at most this many.
  final int exhaustiveOrders;
}

/// A job in the schedule.
class ScheduledJob {
  ScheduledJob({required this.id, required this.startMinute, required this.minutes, required this.powerKw, required this.cost, required this.costWithoutDiscount, required this.windowMinutes, required this.peakMinutes});
  final String id;

  /// Start (clock minute, 0–1439) and duration (min).
  final int startMinute;
  final double minutes;
  final double powerKw;

  /// Daily energy cost with and without the discount.
  final double cost;
  final double costWithoutDiscount;

  /// Minutes inside the discount blocks and in peak bands.
  final double windowMinutes;
  final double peakMinutes;

  double get energyKwh => powerKw * minutes / 60;
  double get endMinute => (startMinute + minutes) % _day;
  double get startHour => startMinute / 60;

  Map<String, dynamic> toJson() => {'id': id, 's': startMinute, 'min': minutes, 'kw': powerKw, 'c': cost, 'c0': costWithoutDiscount, 'win': windowMinutes, 'peak': peakMinutes};
  static ScheduledJob fromJson(Map<String, dynamic> j) => ScheduledJob(
    id: j['id'] as String, startMinute: (j['s'] as num?)?.toInt() ?? 0, minutes: _d(j['min']), powerKw: _d(j['kw']), cost: _d(j['c']), costWithoutDiscount: _d(j['c0']), windowMinutes: _d(j['win']), peakMinutes: _d(j['peak']),
  );
}

/// A discount block (clock minutes; the end may be past midnight, i.e.
/// smaller than the start).
class DiscountBlock {
  const DiscountBlock(this.startMinute, this.endMinute);
  final int startMinute;
  final int endMinute;
  int get minutes => (endMinute - startMinute) % _day == 0 ? _day : (endMinute - startMinute) % _day;

  Map<String, dynamic> toJson() => {'s': startMinute, 'e': endMinute};
  static DiscountBlock fromJson(Map<String, dynamic> j) => DiscountBlock((j['s'] as num).toInt(), (j['e'] as num).toInt());
}

/// Outcome of [scheduleJobs].
class TariffSchedule {
  TariffSchedule({required this.seasonId, required this.jobs, required this.blocks, required this.energyCost, required this.energyCostWithoutDiscount, required this.demandCost, required this.baselineCost, required this.exact, required this.violations});
  final String seasonId;

  /// The jobs from the start of the scheduling day.
  final List<ScheduledJob> jobs;

  /// The discount blocks chosen.
  final List<DiscountBlock> blocks;

  /// Daily energy cost with the discount, the same schedule without it, and
  /// the daily share of the demand charges.
  final double energyCost;
  final double energyCostWithoutDiscount;
  final double demandCost;

  /// Daily cost of the jobs at their current starts with the best discount
  /// blocks for them (energy and demand); null without current starts.
  final double? baselineCost;

  /// The schedule is optimal for the model (every order solved).
  final bool exact;

  /// `tariff_hours_exceeded`, `tariff_day_overfull` (the jobs do not fit in
  /// the day: run back to back from the start of the day), `tariff_job_blocked:<id>`
  /// (no start avoids the no-run intervals), `tariff_precedence_cycle`
  /// (precedences ignored), `tariff_unknown_job:<id>` (a precedence names no
  /// job), `tariff_peak_use:<id>` (the job draws power in a peak band),
  /// `tariff_window_not_whole_blocks` (the window is not a whole number of
  /// blocks: rounded down), `tariff_job_empty:<id>` (no duration: left out).
  final List<String> violations;

  double get dailyCost => energyCost + demandCost;
  double get hoursInWindow => jobs.fold(0.0, (s, j) => s + j.windowMinutes) / 60;
  double get hoursOutsideWindow => jobs.fold(0.0, (s, j) => s + j.minutes - j.windowMinutes) / 60;
  double get energyKwh => jobs.fold(0.0, (s, j) => s + j.energyKwh);
  double get discountSaving => energyCostWithoutDiscount - energyCost;

  Map<String, dynamic> toJson() => {
    'season': seasonId, 'jobs': jobs.map((j) => j.toJson()).toList(), 'blocks': blocks.map((b) => b.toJson()).toList(), 'e': energyCost, 'e0': energyCostWithoutDiscount, 'd': demandCost,
    if (baselineCost != null) 'base': baselineCost, 'exact': exact, 'viol': violations,
  };
  static TariffSchedule fromJson(Map<String, dynamic> j) => TariffSchedule(
    seasonId: j['season'] as String? ?? '', jobs: [for (final x in (j['jobs'] as List?) ?? []) ScheduledJob.fromJson(x as Map<String, dynamic>)], blocks: [for (final x in (j['blocks'] as List?) ?? []) DiscountBlock.fromJson(x as Map<String, dynamic>)],
    energyCost: _d(j['e']), energyCostWithoutDiscount: _d(j['e0']), demandCost: _d(j['d']), baselineCost: (j['base'] as num?)?.toDouble(), exact: j['exact'] as bool? ?? false, violations: ((j['viol'] as List?) ?? []).cast<String>(),
  );
}

/// The daily schedule of [jobs] under [season] (see the library comment).
TariffSchedule scheduleJobs(List<TariffJob> jobs, TariffSeason season, {ScheduleOptions options = const ScheduleOptions()}) => _Scheduler(jobs, season, options).run();

/// Schedules for every season of [tariff], the jobs of each from [jobsFor].
List<TariffSchedule> scheduleSeasons(Tariff tariff, List<TariffJob> Function(TariffSeason season) jobsFor, {ScheduleOptions options = const ScheduleOptions()}) => [for (final s in tariff.seasons) scheduleJobs(jobsFor(s), s, options: options)];

/// Jobs for the system flows of [p] from the design [results]: the daily
/// duration of every flow and its power, the shaft power of the calculated
/// supplies at their required head (with the pump efficiency of the
/// parameters) plus that of the pumps (with their own efficiency), over
/// [motorEfficiency] (1 = the pump efficiency already stands for the whole
/// set, as in the annual energy of the design). Flows keep their current
/// start hours.
List<TariffJob> tariffJobsFromDesign(Project p, DesignResults results, {double motorEfficiency = 1}) {
  final out = <TariffJob>[];
  final starts = {for (final f in p.systemFlows) f.id: f.startHour};
  for (final f in results.systemFlows) {
    var watts = 0.0;
    for (final s in f.supplies) {
      if (s.calculated && s.requiredHead > 0 && s.flow > 0) watts += shaftPower(flow: s.flow, head: s.requiredHead, efficiency: p.params.pumpEfficiency);
    }
    for (final d in f.devices) {
      if (d.pumpHead <= 0 || d.flow <= 0) continue;
      final e = p.byId(d.entityId);
      final spec = e is PumpEntity ? p.catalog.pump(e.pumpSpecId) : null;
      watts += shaftPower(flow: d.flow, head: d.pumpHead, efficiency: spec?.efficiency ?? p.params.pumpEfficiency);
    }
    out.add(TariffJob(id: f.flowId, hours: f.durationHours, powerKw: watts / 1000 / math.max(motorEfficiency, 0.05), startHour: starts[f.flowId]));
  }
  return out;
}

/// A schedule found by a search: energy cost, start step of every job (by
/// job index) and the discount flag of every block of the scheduling day.
class _Plan {
  _Plan(this.cost, this.starts, this.flags);
  final double cost;
  final List<int> starts;
  final List<bool> flags;

  List<int> get order => List<int>.generate(starts.length, (i) => i)..sort((a, b) => starts[a] != starts[b] ? starts[a].compareTo(starts[b]) : a.compareTo(b));
}

class _Scheduler {
  _Scheduler(List<TariffJob> all, this.season, this.options) {
    final disc = season.discount;
    bm = disc != null && disc.blockMinutes > 0 && _day % disc.blockMinutes == 0 ? disc.blockMinutes : 30;
    g = _divisorAtMost(bm, math.max(1, options.stepMinutes));
    final ds = options.dayStartMinute ?? (disc != null && disc.excluded.isNotEmpty ? disc.excluded.first.$2 : 0);
    dayStart = (ds % _day) ~/ bm * bm;
    slots = _day ~/ g;
    perBlock = bm ~/ g;
    blockCount = _day ~/ bm;
    for (var m = 0; m < _day; m++) {
      price[m] = season.priceAt(m);
      if (season.peakAt(m)) peak[m] = 1;
      for (final (s, e) in options.noRunIntervals) {
        if (TariffBand(startMinute: s, endMinute: e, pricePerKwh: 0).covers(m) && s != e) blocked[m] = 1;
      }
    }
    for (var m = 0; m < _day; m++) {
      cum[m + 1] = cum[m] + price[m] / 60;
      peakCum[m + 1] = peakCum[m] + peak[m];
      blockedCum[m + 1] = blockedCum[m] + blocked[m];
    }
    delta = disc == null ? 0 : disc.fraction.clamp(0.0, 1.0);
    if (disc != null && delta > 0) {
      if (disc.windowMinutes % bm != 0) violations.add('tariff_window_not_whole_blocks');
      umax = math.max(0, disc.windowMinutes ~/ bm);
      rmax = math.max(0, disc.maxBlocks);
      for (var c = 0; c < blockCount; c++) {
        var ok = true;
        for (var m = 0; m < bm && ok; m++) {
          final clock = (dayStart + c * bm + m) % _day;
          for (final (s, e) in disc.excluded) {
            if (s != e && TariffBand(startMinute: s, endMinute: e, pricePerKwh: 0).covers(clock)) ok = false;
          }
        }
        allowed.add(ok);
      }
    } else {
      allowed.addAll(List.filled(blockCount, false));
    }
    if (umax == 0 || rmax == 0) {
      umax = 0;
      rmax = 0;
    }
    wrap = umax > 0 && allowed.first && allowed.last;
    // jobs
    for (final j in all) {
      if (!(j.hours > 0)) {
        violations.add('tariff_job_empty:${j.id}');
        continue;
      }
      jobs.add(j);
    }
    for (final j in jobs) {
      final m = j.hours * 60;
      minutes.add(m);
      len.add(math.max(1, (m / g - 1e-9).ceil()));
      power.add(math.max(0.0, j.powerKw));
    }
    final ids = {for (var i = 0; i < jobs.length; i++) jobs[i].id: i};
    for (final j in jobs) {
      final p = <int>{};
      for (final a in j.after) {
        final i = ids[a];
        if (i == null) {
          violations.add('tariff_unknown_job:$a');
        } else if (i != ids[j.id]) {
          p.add(i);
        }
      }
      preds.add(p);
    }
    if (_topological((i) => i.toDouble()) == null) {
      violations.add('tariff_precedence_cycle');
      for (final p in preds) {
        p.clear();
      }
    }
  }

  final List<TariffJob> jobs = [];
  final TariffSeason season;
  final ScheduleOptions options;
  final List<String> violations = [];
  late final int bm, g, dayStart, slots, perBlock, blockCount;
  final price = Float64List(_day);
  final peak = Uint8List(_day);
  final blocked = Uint8List(_day);
  final cum = Float64List(_day + 1);
  final peakCum = Int32List(_day + 1);
  final blockedCum = Int32List(_day + 1);
  late final double delta;
  int umax = 0, rmax = 0;
  late final bool wrap;

  /// Whether every half hour (block) of the scheduling day may be
  /// discounted.
  final List<bool> allowed = [];
  final List<double> minutes = [];
  final List<int> len = [];
  final List<double> power = [];
  final List<Set<int>> preds = [];

  /// Energy cost per kW from the absolute clock minute 0 to [x] (any x ≥ 0).
  double _price(double x) {
    final k = (x / _day).floor();
    final r = x - k * _day;
    final i = r.floor().clamp(0, _day - 1);
    return k * cum[_day] + cum[i] + (r - i) * price[i] / 60;
  }

  int _count(Int32List prefix, double a, double b) {
    int at(int x) => (x ~/ _day) * prefix[_day] + prefix[x % _day];
    return at(b.ceil()) - at(a.floor());
  }

  /// Cost per kW of slot [o] of job [k] run at step [t] of the day.
  double _slotCost(int k, int t, int o) {
    final a = dayStart + t * g.toDouble();
    final span = o == len[k] - 1 ? minutes[k] - (len[k] - 1) * g : g.toDouble();
    return _price(a + span) - _price(a);
  }

  bool _canStart(int k, int t, double cap) {
    if (t + len[k] > slots) return false;
    final a = dayStart + t * g.toDouble(), b = a + minutes[k];
    if (_count(blockedCum, a, b) > 0) return false;
    if (power[k] > cap + 1e-12 && _count(peakCum, a, b) > 0) return false;
    return true;
  }

  /// A topological order of the jobs, the available job with the smallest
  /// [key] first; null when the precedences have a cycle.
  List<int>? _topological(double Function(int) key) {
    final n = jobs.length;
    final placed = <int>{};
    final out = <int>[];
    while (out.length < n) {
      int? best;
      for (var i = 0; i < n; i++) {
        if (placed.contains(i) || !placed.containsAll(preds[i])) continue;
        if (best == null || key(i) < key(best) || (key(i) == key(best) && i < best)) best = i;
      }
      if (best == null) return null;
      placed.add(best);
      out.add(best);
    }
    return out;
  }

  bool _respects(List<int> order) {
    final seen = <int>{};
    for (final i in order) {
      if (!seen.containsAll(preds[i])) return false;
      seen.add(i);
    }
    return true;
  }

  /// Every order the precedences allow, up to [limit] + 1 of them.
  List<List<int>> _orders(int limit) {
    final out = <List<int>>[];
    final cur = <int>[];
    final used = <int>{};
    void rec() {
      if (out.length > limit) return;
      if (cur.length == jobs.length) {
        out.add([...cur]);
        return;
      }
      for (var i = 0; i < jobs.length; i++) {
        if (used.contains(i) || !used.containsAll(preds[i])) continue;
        used.add(i);
        cur.add(i);
        rec();
        cur.removeLast();
        used.remove(i);
        if (out.length > limit) return;
      }
    }

    rec();
    return out;
  }

  /// Energy cost of slot o of job k when it runs at step t (undiscounted),
  /// at [k][t·len[k] + o].
  late final List<Float64List> _slot = [
    for (var k = 0; k < jobs.length; k++) Float64List.fromList([for (var t = 0; t < slots; t++) for (var o = 0; o < len[k]; o++) power[k] * _slotCost(k, t, o)]),
  ];

  final Map<double, List<Uint8List>> _startOk = {};

  /// Whether job k may start at step t with the power [cap] in peak bands.
  List<Uint8List> _starts(double cap) => _startOk[cap] ??= [
    for (var k = 0; k < jobs.length; k++) Uint8List.fromList([for (var t = 0; t < slots; t++) _canStart(k, t, cap) ? 1 : 0]),
  ];

  // discount states ((discounted blocks used·nr + blocks opened)·2 + current
  // block discounted)·nf + first block discounted, and their moves
  late final int _nf = wrap ? 2 : 1;
  late final int _rcap = rmax + (wrap ? 1 : 0);
  late final int _nr = _rcap + 1;
  late final int _nd = (umax + 1) * _nr * 2 * _nf;
  int _encode(int u, int r, int d, int f) => ((u * _nr + r) * 2 + d) * _nf + f;
  late final Int32List _flag = Int32List.fromList([for (var ds = 0; ds < _nd; ds++) (ds ~/ _nf) % 2]);
  late final Int32List _next0 = Int32List.fromList([for (var ds = 0; ds < _nd; ds++) _encode(ds ~/ _nf ~/ 2 ~/ _nr, (ds ~/ _nf ~/ 2) % _nr, 0, ds % _nf)]);
  late final Int32List _next1 = Int32List.fromList([
    for (var ds = 0; ds < _nd; ds++)
      () {
        final f = ds % _nf, d = (ds ~/ _nf) % 2, r = (ds ~/ _nf ~/ 2) % _nr, u = ds ~/ _nf ~/ 2 ~/ _nr;
        if (u >= umax || (d == 0 && r >= _rcap)) return -1;
        return _encode(u + 1, d == 1 ? r : r + 1, 1, f);
      }(),
  ]);
  late final List<bool> _endOk = [
    for (var ds = 0; ds < _nd; ds++) (ds ~/ _nf ~/ 2) % _nr - (wrap && ds % _nf == 1 && (ds ~/ _nf) % 2 == 1 ? 1 : 0) <= rmax,
  ];

  /// Start times and discount blocks of [order], together and exactly (the
  /// dynamic programme of the library comment); null when the jobs do not
  /// fit. Jobs above [cap] kW stay out of the peak bands.
  _Plan? _joint(List<int> order, double cap) {
    final n = order.length;
    final runBase = List<int>.filled(n, 0);
    var nj = n + 1;
    for (var i = 0; i < n; i++) {
      runBase[i] = nj;
      nj += len[order[i]] - 1;
    }
    final jsPos = Int32List(nj), jsDone = Int32List(nj);
    for (var i = 0; i <= n; i++) {
      jsPos[i] = i;
      jsDone[i] = -1;
    }
    for (var i = 0; i < n; i++) {
      for (var o = 1; o < len[order[i]]; o++) {
        jsPos[runBase[i] + o - 1] = i;
        jsDone[runBase[i] + o - 1] = o;
      }
    }
    final nd = _nd;
    final size = nj * nd;
    final start = _starts(cap);
    final first1 = umax > 0 && _rcap > 0 ? _encode(1, 1, 1, wrap ? 1 : 0) : -1;
    final keep = 1 - delta;
    var cur = Float64List(size)..fillRange(0, size, double.infinity);
    var nxt = Float64List(size);
    cur[0] = 0;
    final pred = <Int32List>[];
    for (var t = 0; t < slots; t++) {
      nxt.fillRange(0, size, double.infinity);
      final from = Int32List(size);
      final boundary = t % perBlock == 0;
      final canDiscount = boundary && allowed[t ~/ perBlock];
      for (var js = 0; js < nj; js++) {
        final pos = jsPos[js], done = jsDone[js];
        final base = js * nd;
        // where the job state goes in this step, and at what cost
        var stay = -1, go = -1;
        var cost = 0.0;
        if (done < 0) {
          stay = base;
          if (pos < n) {
            final k = order[pos];
            if (start[k][t] == 1) {
              go = (len[k] == 1 ? pos + 1 : runBase[pos]) * nd;
              cost = _slot[k][t * len[k]];
            }
          }
        } else {
          final k = order[pos];
          go = (done + 1 == len[k] ? pos + 1 : js + 1) * nd;
          cost = _slot[k][t * len[k] + done];
        }
        for (var ds = 0; ds < nd; ds++) {
          final s = base + ds;
          final v = cur[s];
          if (v == double.infinity) continue;
          int plain, discounted;
          if (boundary) {
            plain = _next0[ds];
            discounted = canDiscount ? (t == 0 ? first1 : _next1[ds]) : -1;
          } else if (_flag[ds] == 0) {
            plain = ds;
            discounted = -1;
          } else {
            plain = -1;
            discounted = ds;
          }
          if (plain >= 0) {
            if (stay >= 0 && v < nxt[stay + plain]) {
              nxt[stay + plain] = v;
              from[stay + plain] = s;
            }
            if (go >= 0 && v + cost < nxt[go + plain]) {
              nxt[go + plain] = v + cost;
              from[go + plain] = s;
            }
          }
          if (discounted >= 0) {
            if (stay >= 0 && v < nxt[stay + discounted]) {
              nxt[stay + discounted] = v;
              from[stay + discounted] = s;
            }
            final w = v + cost * keep;
            if (go >= 0 && w < nxt[go + discounted]) {
              nxt[go + discounted] = w;
              from[go + discounted] = s;
            }
          }
        }
      }
      pred.add(from);
      final t2 = cur;
      cur = nxt;
      nxt = t2;
    }
    var best = double.infinity;
    var bestS = -1;
    for (var ds = 0; ds < nd; ds++) {
      final s = n * nd + ds;
      if (!(cur[s] < best) || !_endOk[ds]) continue;
      best = cur[s];
      bestS = s;
    }
    if (bestS < 0) return null;
    final states = List<int>.filled(slots + 1, 0);
    states[slots] = bestS;
    for (var t = slots - 1; t >= 0; t--) {
      states[t] = pred[t][states[t + 1]];
    }
    final starts = List<int>.filled(jobs.length, 0);
    for (var t = 0; t < slots; t++) {
      final a = states[t] ~/ nd, b = states[t + 1] ~/ nd;
      if (a <= n && b != a) starts[order[a]] = t;
    }
    final flags = [for (var c = 0; c < blockCount; c++) _flag[states[c * perBlock + 1] % nd] == 1];
    return _Plan(best, starts, flags);
  }

  /// Energy cost of every job and start for fixed discount [flags] (NaN
  /// where it cannot start).
  List<Float64List> _costTable(List<bool> flags, double cap) {
    final start = _starts(cap);
    return [
      for (var k = 0; k < jobs.length; k++)
        Float64List.fromList([
          for (var t = 0; t < slots; t++)
            if (start[k][t] == 0)
              double.nan
            else
              [for (var o = 0; o < len[k]; o++) _slot[k][(t + o) * len[k] + o] * (flags[(t + o) ~/ perBlock] ? 1 - delta : 1)].fold(0.0, (a, b) => a + b),
        ]),
    ];
  }

  /// Least energy cost of [order] with the blocks fixed (start times free).
  double _fixedOrderCost(List<int> order, List<Float64List> table) {
    final n = order.length;
    var g0 = List<double>.filled(n + 1, double.infinity)..[0] = 0;
    final ahead = List.generate(slots + 1, (_) => List<double>.filled(n + 1, double.infinity));
    for (var t = 0; t <= slots; t++) {
      for (var k = 0; k <= n; k++) {
        g0[k] = math.min(g0[k], ahead[t][k]);
      }
      if (t == slots) break;
      final next = List<double>.filled(n + 1, double.infinity);
      for (var k = 0; k <= n; k++) {
        final v = g0[k];
        if (v == double.infinity) continue;
        next[k] = math.min(next[k], v);
        if (k < n) {
          final j = order[k];
          final c = table[j][t];
          if (!c.isNaN) ahead[t + len[j]][k + 1] = math.min(ahead[t + len[j]][k + 1], v + c);
        }
      }
      g0 = next;
    }
    return g0[n];
  }

  /// The best order for fixed blocks over every order (dynamic programme
  /// over subsets of jobs), for up to 12 jobs.
  List<int>? _bestOrderForBlocks(List<Float64List> table) {
    final n = jobs.length;
    final full = (1 << n) - 1;
    final width = 1 << n;
    final f = Float64List((slots + 1) * width)..fillRange(0, (slots + 1) * width, double.infinity);
    final from = Int8List((slots + 1) * width)..fillRange(0, (slots + 1) * width, -2);
    final predMask = [for (final p in preds) p.fold(0, (m, i) => m | (1 << i))];
    f[0] = 0;
    for (var t = 0; t <= slots; t++) {
      for (var mask = 0; mask < width; mask++) {
        final v = f[t * width + mask];
        if (v == double.infinity) continue;
        if (t < slots && v < f[(t + 1) * width + mask]) {
          f[(t + 1) * width + mask] = v;
          from[(t + 1) * width + mask] = -1;
        }
        if (t == slots) continue;
        for (var j = 0; j < n; j++) {
          if (mask & (1 << j) != 0 || (predMask[j] & mask) != predMask[j]) continue;
          final c = table[j][t];
          if (c.isNaN) continue;
          final e = t + len[j];
          final idx = e * width + (mask | (1 << j));
          if (v + c < f[idx]) {
            f[idx] = v + c;
            from[idx] = j;
          }
        }
      }
    }
    if (f[slots * width + full] == double.infinity) return null;
    final startOf = List<int>.filled(n, 0);
    var t = slots, mask = full;
    while (t > 0 || mask != 0) {
      final fr = from[t * width + mask];
      if (fr == -1) {
        t--;
      } else if (fr >= 0) {
        t -= len[fr];
        mask &= ~(1 << fr);
        startOf[fr] = t;
      } else {
        break;
      }
    }
    return List<int>.generate(n, (i) => i)..sort((a, b) => startOf[a] != startOf[b] ? startOf[a].compareTo(startOf[b]) : a.compareTo(b));
  }

  /// Pairwise swaps and insertions while they lower the cost with the blocks
  /// fixed.
  List<int> _localSearch(List<int> order, List<Float64List> table) {
    var best = [...order];
    var bestCost = _fixedOrderCost(best, table);
    var improved = true;
    var passes = 0;
    while (improved && passes++ < 50) {
      improved = false;
      final n = best.length;
      for (var i = 0; i < n && !improved; i++) {
        for (var j = 0; j < n && !improved; j++) {
          if (i == j) continue;
          for (final swap in [true, false]) {
            if (swap && j < i) continue;
            final cand = [...best];
            if (swap) {
              final t = cand[i];
              cand[i] = cand[j];
              cand[j] = t;
            } else {
              final x = cand.removeAt(i);
              cand.insert(j, x);
            }
            if (!_respects(cand)) continue;
            final c = _fixedOrderCost(cand, table);
            if (c < bestCost - 1e-9) {
              best = cand;
              bestCost = c;
              improved = true;
              break;
            }
          }
        }
      }
    }
    return best;
  }

  /// The best plan for the power [cap] in peak bands: every order, or the
  /// heuristic of the library comment. Returns the plan and whether every
  /// order was solved.
  (_Plan?, bool) _search(double cap) {
    final n = jobs.length;
    if (options.keepOrder) {
      final given = List<int>.generate(n, (i) => i);
      final order = _respects(given) ? given : (_topological((i) => i.toDouble()) ?? given);
      return (_joint(order, cap), true);
    }
    final orders = _orders(options.exhaustiveOrders);
    if (orders.length <= options.exhaustiveOrders) {
      _Plan? best;
      for (final o in orders) {
        final p = _joint(o, cap);
        if (p != null && (best == null || p.cost < best.cost - 1e-12)) best = p;
      }
      return (best, true);
    }
    final candidates = <List<int>>[
      if (_respects(List<int>.generate(n, (i) => i))) List<int>.generate(n, (i) => i),
      _topological((i) => -power[i])!,
      _topological((i) => power[i])!,
    ];
    // starting orders: the candidates, and with up to 8 jobs the best order
    // for a single window of the whole discount at every place it fits
    final starts = <List<int>>[...candidates];
    if (n <= 8 && umax > 0) {
      for (var c = 0; c + umax <= blockCount; c++) {
        if (!List.generate(umax, (i) => allowed[c + i]).every((x) => x)) continue;
        final flags = List<bool>.generate(blockCount, (i) => i >= c && i < c + umax);
        final order = _bestOrderForBlocks(_costTable(flags, cap));
        if (order != null) starts.add(order);
      }
    }
    // alternate from every starting order: the best order for the blocks of
    // the plan, then the joint programme for that order, while it improves
    _Plan? best;
    final tried = <String>{};
    for (final o in starts) {
      if (!tried.add(o.join(','))) continue;
      var plan = _joint(o, cap);
      if (plan == null) continue;
      for (var round = 0; round < 10; round++) {
        final table = _costTable(plan!.flags, cap);
        final order = n <= 12 ? (_bestOrderForBlocks(table) ?? plan.order) : _localSearch(plan.order, table);
        final p = _joint(order, cap);
        if (p == null || p.cost >= plan.cost - 1e-9) break;
        plan = p;
      }
      if (best == null || plan!.cost < best.cost - 1e-12) best = plan;
    }
    return (best, false);
  }

  /// Discount flags per clock block that save the most for jobs placed at
  /// [startClock] minutes (circular dynamic programme over the clock blocks).
  List<bool> _bestBlocksFor(List<double> startClock) {
    final nb = blockCount;
    final flags = List<bool>.filled(nb, false);
    if (umax == 0 || delta == 0) return flags;
    final save = List<double>.filled(nb, 0);
    for (var k = 0; k < jobs.length; k++) {
      var x = startClock[k];
      final end = x + minutes[k];
      while (x < end - 1e-9) {
        final b = (x / bm).floor();
        final y = math.min(end, (b + 1) * bm.toDouble());
        save[b % nb] += delta * power[k] * (_price(y) - _price(x));
        x = y;
      }
    }
    // clock block c is horizon block (c − dayStart/bm) mod nb: reuse the
    // allowed list of the scheduling day
    final shift = dayStart ~/ bm;
    bool ok(int c) => allowed[(c - shift) % nb];
    final cyc = ok(0) && ok(nb - 1);
    final nf = cyc ? 2 : 1;
    final rcap = rmax + (cyc ? 1 : 0);
    // dp over (u, r, d, f): best saving, with the flags kept by back pointers
    final nr = rcap + 1, nu = umax + 1;
    final nd = nu * nr * 2 * nf;
    var cur = List<double>.filled(nd, double.negativeInfinity)..[0] = 0;
    final back = <List<int>>[];
    for (var c = 0; c < nb; c++) {
      final nxt = List<double>.filled(nd, double.negativeInfinity);
      final bk = List<int>.filled(nd, -1);
      for (var ds = 0; ds < nd; ds++) {
        final v = cur[ds];
        if (v == double.negativeInfinity) continue;
        final f = ds % nf;
        var rest = ds ~/ nf;
        final d = rest % 2;
        rest ~/= 2;
        final r = rest % nr;
        final u = rest ~/ nr;
        for (var disc = 0; disc < 2; disc++) {
          var u2 = u, r2 = r, f2 = f;
          if (disc == 1) {
            if (!ok(c) || u >= umax) continue;
            if (d == 0) {
              if (r >= rcap) continue;
              r2 = r + 1;
            }
            u2 = u + 1;
          }
          if (c == 0 && cyc) f2 = disc;
          final ds2 = ((u2 * nr + r2) * 2 + disc) * nf + f2;
          final nv = v + (disc == 1 ? save[c] : 0);
          if (nv > nxt[ds2] + 1e-15) {
            nxt[ds2] = nv;
            bk[ds2] = ds;
          }
        }
      }
      back.add(bk);
      cur = nxt;
    }
    var best = double.negativeInfinity;
    var bestS = -1;
    for (var ds = 0; ds < nd; ds++) {
      if (!(cur[ds] > best)) continue;
      final f = ds % nf;
      var rest = ds ~/ nf;
      final d = rest % 2;
      rest ~/= 2;
      final r = rest % nr;
      if (r - (cyc && f == 1 && d == 1 ? 1 : 0) > rmax) continue;
      best = cur[ds];
      bestS = ds;
    }
    var s = bestS;
    for (var c = nb - 1; c >= 0 && s >= 0; c--) {
      flags[c] = ((s ~/ nf) % 2) == 1;
      s = back[c][s];
    }
    return flags;
  }

  /// Costs of the jobs at [startClock] minutes with the clock-block discount
  /// [clockFlags].
  List<ScheduledJob> _evaluate(List<int> order, List<double> startClock, List<bool> clockFlags) => [
    for (final k in order)
      () {
        var x = startClock[k];
        final end = x + minutes[k];
        var cost = 0.0, cost0 = 0.0, win = 0.0;
        while (x < end - 1e-9) {
          final b = (x / bm).floor();
          final y = math.min(end, (b + 1) * bm.toDouble());
          final seg = power[k] * (_price(y) - _price(x));
          cost0 += seg;
          if (clockFlags[b % blockCount]) {
            cost += seg * (1 - delta);
            win += y - x;
          } else {
            cost += seg;
          }
          x = y;
        }
        final pk = _count(peakCum, startClock[k], end).toDouble().clamp(0.0, minutes[k]);
        return ScheduledJob(id: jobs[k].id, startMinute: startClock[k].round() % _day, minutes: minutes[k], powerKw: power[k], cost: cost, costWithoutDiscount: cost0, windowMinutes: win, peakMinutes: pk);
      }(),
  ];

  double _demand(List<ScheduledJob> js) {
    if (js.isEmpty) return 0;
    final days = season.daysPerMonth > 0 ? season.daysPerMonth : 30;
    final maxP = js.fold(0.0, (m, j) => math.max(m, j.powerKw));
    final peakP = js.where((j) => j.peakMinutes > 0).fold(0.0, (m, j) => math.max(m, j.powerKw));
    return (season.demandChargePerKw * maxP + season.peakDemandChargePerKw * peakP) / days;
  }

  List<DiscountBlock> _blocks(List<bool> clockFlags) {
    final nb = blockCount;
    if (!clockFlags.contains(true)) return const [];
    if (!clockFlags.contains(false)) return [DiscountBlock(0, 0)];
    // start from a block that is off so that runs do not wrap the loop
    final first = clockFlags.indexOf(false);
    final out = <DiscountBlock>[];
    var c = 0;
    while (c < nb) {
      final i = (first + c) % nb;
      if (!clockFlags[i]) {
        c++;
        continue;
      }
      var len = 0;
      while (c + len < nb && clockFlags[(first + c + len) % nb]) {
        len++;
      }
      out.add(DiscountBlock(i * bm % _day, (i + len) * bm % _day));
      c += len;
    }
    out.sort((a, b) => ((a.startMinute - dayStart) % _day).compareTo((b.startMinute - dayStart) % _day));
    return out;
  }

  TariffSchedule run() {
    final n = jobs.length;
    final total = minutes.fold(0.0, (a, b) => a + b);
    if (options.maxHoursPerDay > 0 && total / 60 > options.maxHoursPerDay + 1e-9) violations.add('tariff_hours_exceeded');
    for (var k = 0; k < n; k++) {
      if (!List.generate(slots, (t) => t).any((t) => _canStart(k, t, double.infinity))) violations.add('tariff_job_blocked:${jobs[k].id}');
    }
    // caps on the power drawn in the peak bands
    final peakBands = season.peakDemandChargePerKw > 0 && peakCum[_day] > 0;
    final caps = peakBands ? <double>[0, ...{...power}.toList()..sort()] : <double>[double.infinity];
    _Plan? best;
    var bestTotal = double.infinity;
    var exact = true;
    for (final cap in caps) {
      final (plan, ex) = _search(cap);
      if (plan == null) continue;
      final order = plan.order;
      final startClock = [for (var k = 0; k < n; k++) (dayStart + plan.starts[k] * g).toDouble()];
      final shift = dayStart ~/ bm;
      final clockFlags = [for (var c = 0; c < blockCount; c++) plan.flags[(c - shift) % blockCount]];
      final js = _evaluate(order, startClock, clockFlags);
      final totalCost = js.fold(0.0, (s, j) => s + j.cost) + _demand(js);
      if (totalCost < bestTotal - 1e-9) {
        bestTotal = totalCost;
        best = plan;
        exact = ex;
      }
    }
    // baseline: the jobs at their current starts
    double? baseline;
    if (jobs.any((j) => j.startHour != null)) {
      final start = <double>[];
      var cursor = dayStart.toDouble();
      for (var k = 0; k < n; k++) {
        final sh = jobs[k].startHour;
        final s = sh != null ? (sh * 60) % _day : cursor % _day;
        start.add(s);
        cursor = s + minutes[k];
      }
      final flags = _bestBlocksFor(start);
      final js = _evaluate(List<int>.generate(n, (i) => i), start, flags);
      baseline = js.fold(0.0, (s, j) => s + j.cost) + _demand(js);
    }
    List<ScheduledJob> js;
    List<bool> clockFlags;
    if (best == null) {
      // infeasible: back to back from the start of the day
      if (n > 0) violations.add('tariff_day_overfull');
      exact = false;
      final order = _topological((i) => i.toDouble()) ?? List<int>.generate(n, (i) => i);
      final start = List<double>.filled(n, 0);
      var cursor = dayStart.toDouble();
      for (final k in order) {
        start[k] = cursor;
        cursor += minutes[k];
      }
      clockFlags = _bestBlocksFor(start);
      js = _evaluate(order, start, clockFlags);
    } else {
      final startClock = [for (var k = 0; k < n; k++) (dayStart + best.starts[k] * g).toDouble()];
      final shift = dayStart ~/ bm;
      clockFlags = [for (var c = 0; c < blockCount; c++) best.flags[(c - shift) % blockCount]];
      js = _evaluate(best.order, startClock, clockFlags);
    }
    for (final j in js) {
      if (j.peakMinutes > 0) violations.add('tariff_peak_use:${j.id}');
    }
    return TariffSchedule(
      seasonId: season.id, jobs: js, blocks: _blocks(clockFlags), energyCost: js.fold(0.0, (s, j) => s + j.cost), energyCostWithoutDiscount: js.fold(0.0, (s, j) => s + j.costWithoutDiscount),
      demandCost: _demand(js), baselineCost: baseline, exact: exact && best != null, violations: violations,
    );
  }
}

/// The largest divisor of [n] not above [m].
int _divisorAtMost(int n, int m) {
  for (var d = math.min(n, m); d > 1; d--) {
    if (n % d == 0) return d;
  }
  return 1;
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
