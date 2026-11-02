import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/tariff.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

const _excludedStart = 17 * 60, _excludedEnd = 21 * 60 + 30;

/// Flat price 1.0 with the Brazilian discount of Group B, other regions (60 %).
TariffSeason _flat({int blocks = 3}) => TariffSeason(
  id: 'flat',
  basePricePerKwh: 1,
  discount: IrrigationDiscount(fraction: 0.6, maxBlocks: blocks),
);

void _checkBlocks(TariffSchedule s, {int maxBlocks = 3, int window = 510}) {
  expect(s.blocks.length, lessThanOrEqualTo(maxBlocks));
  var total = 0;
  for (final b in s.blocks) {
    expect(b.startMinute % 30, 0);
    expect(b.minutes % 30, 0);
    total += b.minutes;
    for (var m = 0; m < b.minutes; m++) {
      final clock = (b.startMinute + m) % 1440;
      expect(clock >= _excludedStart && clock < _excludedEnd, isFalse, reason: 'block ${b.startMinute}–${b.endMinute} touches 17:00–21:30');
    }
  }
  expect(total, lessThanOrEqualTo(window));
}

/// Independent check: every pair of starts on the half-hour grid of the
/// scheduling day (21:30 → 21:30) and the best blocks for each by a simple
/// dynamic programme; the least energy cost.
double _bruteForce(List<(double, int)> jobs, double Function(int clockMinute) price, double delta) {
  const start = 1290;
  final allowed = [for (var i = 0; i < 48; i++) !List.generate(30, (m) => (start + 30 * i + m) % 1440).any((c) => c >= _excludedStart && c < _excludedEnd)];
  final slotPrice = [for (var i = 0; i < 48; i++) List.generate(30, (m) => price((start + 30 * i + m) % 1440)).fold(0.0, (s, p) => s + p) / 60];
  var best = double.infinity;
  final (pa, la) = jobs[0];
  final (pb, lb) = jobs[1];
  for (var a = 0; a + la <= 48; a++) {
    for (var b = 0; b + lb <= 48; b++) {
      if (a < b + lb && b < a + la) continue;
      final e = List<double>.filled(48, 0);
      for (var i = a; i < a + la; i++) {
        e[i] += pa * slotPrice[i];
      }
      for (var i = b; i < b + lb; i++) {
        e[i] += pb * slotPrice[i];
      }
      // most saving with ≤ 3 runs of ≤ 17 slots in all
      var dp = <(int, int, int), double>{(0, 0, 0): 0};
      for (var i = 0; i < 48; i++) {
        final next = <(int, int, int), double>{};
        void put((int, int, int) k, double v) {
          if (v > (next[k] ?? double.negativeInfinity)) next[k] = v;
        }

        for (final en in dp.entries) {
          final (u, r, d) = en.key;
          put((u, r, 0), en.value);
          if (allowed[i] && u < 17 && (d == 1 || r < 3)) put((u + 1, d == 1 ? r : r + 1, 1), en.value + delta * e[i]);
        }
        dp = next;
      }
      final saving = dp.values.fold(0.0, math.max);
      best = math.min(best, e.fold(0.0, (s, x) => s + x) - saving);
    }
  }
  return best;
}

void main() {
  test('the Brazilian discounts and rule', () {
    expect(IrrigationDiscount.brazil(BrazilConsumerGroup.b, BrazilDiscountRegion.others).fraction, 0.60);
    expect(IrrigationDiscount.brazil(BrazilConsumerGroup.b, BrazilDiscountRegion.northCentreWestMinas).fraction, 0.67);
    expect(IrrigationDiscount.brazil(BrazilConsumerGroup.b, BrazilDiscountRegion.northeastSudene).fraction, 0.73);
    expect(IrrigationDiscount.brazil(BrazilConsumerGroup.a, BrazilDiscountRegion.others).fraction, 0.70);
    expect(IrrigationDiscount.brazil(BrazilConsumerGroup.a, BrazilDiscountRegion.northCentreWestMinas).fraction, 0.80);
    final d = IrrigationDiscount.brazil(BrazilConsumerGroup.a, BrazilDiscountRegion.northeastSudene);
    expect(d.fraction, 0.90);
    expect(d.windowMinutes, 510);
    expect(d.maxBlocks, 3);
    expect(d.blockMinutes, 30);
    expect(d.excluded, [(1020, 1290)]);
    final back = IrrigationDiscount.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
    expect(back.excluded, d.excluded);
    expect(back.fraction, d.fraction);
  });

  test('a job that fits the window runs inside it', () {
    final s = scheduleJobs(const [TariffJob(id: 'A', hours: 8.5, powerKw: 10)], _flat());
    expect(s.exact, isTrue);
    expect(s.violations, isEmpty);
    expect(s.energyCost, closeTo(10 * 8.5 * 0.4, 1e-9));
    expect(s.energyCostWithoutDiscount, closeTo(85, 1e-9));
    expect(s.discountSaving, closeTo(51, 1e-9));
    expect(s.hoursInWindow, closeTo(8.5, 1e-9));
    expect(s.hoursOutsideWindow, closeTo(0, 1e-9));
    expect(s.energyKwh, closeTo(85, 1e-9));
    _checkBlocks(s);
    // a longer job: 8.5 h discounted, the rest at full price
    final long = scheduleJobs(const [TariffJob(id: 'A', hours: 10, powerKw: 10)], _flat());
    expect(long.energyCost, closeTo(10 * (8.5 * 0.4 + 1.5), 1e-9));
    _checkBlocks(long);
  });

  test('the bigger job takes the window', () {
    final s = scheduleJobs(const [TariffJob(id: 'small', hours: 8.5, powerKw: 10), TariffJob(id: 'big', hours: 8.5, powerKw: 100)], _flat());
    expect(s.energyCost, closeTo(100 * 8.5 * 0.4 + 10 * 8.5, 1e-9));
    final big = s.jobs.firstWhere((j) => j.id == 'big');
    expect(big.windowMinutes, closeTo(510, 1e-9));
    // one at a time
    final a = s.jobs[0], b = s.jobs[1];
    final aStart = (a.startMinute - 1290) % 1440, bStart = (b.startMinute - 1290) % 1440;
    expect(aStart + a.minutes <= bStart || bStart + b.minutes <= aStart, isTrue);
  });

  test('up to three blocks: runs separated by no-run intervals', () {
    // runs of 3 h: 21:30–0:30, 1:30–4:30, 5:30–8:30 (and the undiscounted evening)
    const opts = ScheduleOptions(stepMinutes: 30, noRunIntervals: [(30, 90), (270, 330), (510, 1020)]);
    const jobs = [TariffJob(id: 'a', hours: 3, powerKw: 10), TariffJob(id: 'b', hours: 3, powerKw: 10), TariffJob(id: 'c', hours: 3, powerKw: 10)];
    final three = scheduleJobs(jobs, _flat(), options: opts);
    expect(three.energyCost, closeTo(10 * (8.5 * 0.4 + 0.5), 1e-9));
    expect(three.blocks.length, 3);
    _checkBlocks(three);
    final two = scheduleJobs(jobs, _flat(blocks: 2), options: opts);
    expect(two.energyCost, closeTo(10 * (7.5 * 0.4 + 1.5), 1e-9));
    _checkBlocks(two, maxBlocks: 2);
    final one = scheduleJobs(jobs, _flat(blocks: 1), options: opts);
    expect(one.energyCost, closeTo(10 * (6.5 * 0.4 + 2.5), 1e-9));
    _checkBlocks(one, maxBlocks: 1);
    for (final s in [three, two, one]) {
      for (final j in s.jobs) {
        for (var m = 0; m < j.minutes; m++) {
          final c = (j.startMinute + m) % 1440;
          expect((c >= 30 && c < 90) || (c >= 270 && c < 330) || (c >= 510 && c < 1020), isFalse, reason: '${j.id} runs at minute $c');
        }
      }
    }
  });

  test('exact against a brute force over every start and block choice', () {
    double price(int m) => m >= 1080 && m < 1260 ? 3.0 : (m >= 360 && m < 1020 ? 1.0 : 0.8);
    final season = TariffSeason(
      id: 'tou',
      basePricePerKwh: 0.8,
      bands: const [TariffBand(startMinute: 360, endMinute: 1020, pricePerKwh: 1.0), TariffBand(startMinute: 1080, endMinute: 1260, pricePerKwh: 3.0, peak: true)],
      discount: IrrigationDiscount.brazil(BrazilConsumerGroup.a, BrazilDiscountRegion.others),
    );
    for (final jobs in const [
      [(50.0, 10), (20.0, 13)],
      [(15.0, 20), (40.0, 6)],
      [(30.0, 17), (30.0, 17)],
    ]) {
      final s = scheduleJobs(
        [for (var i = 0; i < jobs.length; i++) TariffJob(id: 'j$i', hours: jobs[i].$2 / 2, powerKw: jobs[i].$1)],
        season,
        options: const ScheduleOptions(stepMinutes: 30),
      );
      expect(s.exact, isTrue);
      expect(s.energyCost, closeTo(_bruteForce(jobs, price, 0.7), 1e-6), reason: '$jobs');
      _checkBlocks(s);
    }
  });

  test('the start of the scheduling day matters: no job runs across it', () {
    const season = TariffSeason(basePricePerKwh: 1, bands: [TariffBand(startMinute: 1080, endMinute: 1260, pricePerKwh: 5, peak: true)]);
    const job = [TariffJob(id: 'long', hours: 20, powerKw: 1)];
    final midnight = scheduleJobs(job, season);
    expect(midnight.energyCost, closeTo(18 + 2 * 5, 1e-9));
    expect(midnight.violations, ['tariff_peak_use:long']);
    final evening = scheduleJobs(job, season, options: const ScheduleOptions(dayStartMinute: 1260));
    expect(evening.energyCost, closeTo(20, 1e-9));
    expect(evening.jobs.single.startMinute, 1260);
    expect(evening.violations, isEmpty);
  });

  test('peak demand charge: the small job takes the peak', () {
    const season = TariffSeason(
      basePricePerKwh: 1,
      bands: [TariffBand(startMinute: 1080, endMinute: 1260, pricePerKwh: 1, peak: true)],
      demandChargePerKw: 15,
      peakDemandChargePerKw: 30,
      daysPerMonth: 30,
    );
    final s = scheduleJobs(const [TariffJob(id: 'A', hours: 10, powerKw: 30), TariffJob(id: 'B', hours: 12, powerKw: 5)], season);
    expect(s.energyCost, closeTo(360, 1e-9));
    expect(s.demandCost, closeTo(15 + 5, 1e-9));
    expect(s.dailyCost, closeTo(380, 1e-9));
    expect(s.violations, ['tariff_peak_use:B']);
  });

  test('precedences, limits and impossible days', () {
    final s = scheduleJobs(const [
      TariffJob(id: 'A', hours: 5, powerKw: 10),
      TariffJob(id: 'B', hours: 2, powerKw: 50, after: {'A'}),
    ], _flat());
    final a = s.jobs.firstWhere((j) => j.id == 'A'), b = s.jobs.firstWhere((j) => j.id == 'B');
    expect((b.startMinute - 1290) % 1440, greaterThanOrEqualTo((a.startMinute - 1290) % 1440 + a.minutes - 1e-9));
    expect(s.energyCost, closeTo((50 + 100) * 0.4, 1e-9));
    final cyc = scheduleJobs(const [
      TariffJob(id: 'A', hours: 1, powerKw: 1, after: {'B'}),
      TariffJob(id: 'B', hours: 1, powerKw: 1, after: {'A', 'Z'}),
    ], _flat());
    expect(cyc.violations, containsAll(['tariff_precedence_cycle', 'tariff_unknown_job:Z']));
    final hours = scheduleJobs(
      const [TariffJob(id: 'A', hours: 7, powerKw: 1), TariffJob(id: 'B', hours: 5, powerKw: 1)],
      _flat(),
      options: const ScheduleOptions(maxHoursPerDay: 10),
    );
    expect(hours.violations, contains('tariff_hours_exceeded'));
    final full = scheduleJobs(const [TariffJob(id: 'A', hours: 13, powerKw: 1), TariffJob(id: 'B', hours: 12, powerKw: 1), TariffJob(id: 'C', hours: 0, powerKw: 1)], _flat());
    expect(full.violations, containsAll(['tariff_day_overfull', 'tariff_job_empty:C']));
    expect(full.exact, isFalse);
    expect(full.jobs.length, 2);
    final blocked = scheduleJobs(
      const [TariffJob(id: 'A', hours: 3, powerKw: 1)],
      _flat(),
      options: const ScheduleOptions(noRunIntervals: [(0, 1200)]),
    );
    expect(blocked.violations, contains('tariff_job_blocked:A'));
    final order = scheduleJobs(
      const [TariffJob(id: 'A', hours: 2, powerKw: 1), TariffJob(id: 'B', hours: 2, powerKw: 100)],
      _flat(),
      options: const ScheduleOptions(keepOrder: true),
    );
    expect(order.jobs.map((j) => j.id), ['A', 'B']);
  });

  test('the heuristic beyond the exhaustive orders', () {
    final six = scheduleJobs([for (var i = 0; i < 6; i++) TariffJob(id: 'j$i', hours: 1, powerKw: 10)], _flat());
    expect(six.exact, isFalse);
    expect(six.energyCost, closeTo(6 * 10 * 0.4, 1e-9));
    final many = scheduleJobs([for (var i = 0; i < 13; i++) TariffJob(id: 'j$i', hours: 0.5, powerKw: 10)], _flat());
    expect(many.energyCost, closeTo(6.5 * 10 * 0.4, 1e-9));
    // against every order on four jobs of different powers
    final season = TariffSeason(
      basePricePerKwh: 0.8,
      bands: const [TariffBand(startMinute: 360, endMinute: 1020, pricePerKwh: 1.0), TariffBand(startMinute: 1080, endMinute: 1260, pricePerKwh: 3.0, peak: true)],
      discount: IrrigationDiscount.brazil(BrazilConsumerGroup.b, BrazilDiscountRegion.others),
    );
    const jobs = [TariffJob(id: 'a', hours: 4, powerKw: 12), TariffJob(id: 'b', hours: 3.5, powerKw: 40), TariffJob(id: 'c', hours: 6, powerKw: 8), TariffJob(id: 'd', hours: 2.5, powerKw: 25)];
    final exact = scheduleJobs(jobs, season);
    final heur = scheduleJobs(jobs, season, options: const ScheduleOptions(exhaustiveOrders: 0));
    expect(exact.exact, isTrue);
    expect(heur.exact, isFalse);
    expect(heur.energyCost, greaterThanOrEqualTo(exact.energyCost - 1e-9));
    expect(heur.energyCost, lessThanOrEqualTo(exact.energyCost * 1.02));
  });

  test('baseline: the jobs at their current starts', () {
    final s = scheduleJobs(const [TariffJob(id: 'A', hours: 8.5, powerKw: 10, startHour: 17)], _flat());
    // 17:00–21:30 at full price, 21:30–01:30 discounted
    expect(s.baselineCost, closeTo(10 * (4.5 + 4 * 0.4), 1e-9));
    expect(s.dailyCost, closeTo(34, 1e-9));
    final back = TariffSchedule.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.baselineCost, s.baselineCost);
    expect(back.jobs.single.startMinute, s.jobs.single.startMinute);
    expect(back.blocks.length, s.blocks.length);
    expect(scheduleJobs(const [TariffJob(id: 'A', hours: 2, powerKw: 1)], _flat()).baselineCost, isNull);
  });

  test('seasons and the jobs of a design', () {
    final t = Tariff([
      TariffSeason(id: 'dry', months: const {6, 7, 8}, basePricePerKwh: 1),
      TariffSeason(id: 'rest', basePricePerKwh: 0.5),
    ]);
    expect(t.seasonFor(7)!.id, 'dry');
    expect(t.seasonFor(1)!.id, 'rest');
    final back = Tariff.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.seasons.first.months, {6, 7, 8});
    final all = scheduleSeasons(t, (s) => const [TariffJob(id: 'A', hours: 2, powerKw: 3)]);
    expect([for (final s in all) s.energyCost], [closeTo(6, 1e-9), closeTo(3, 1e-9)]);
    final p = Project()..systemFlows.add(SystemFlow(id: 'f1', name: 'F1', valveIds: {'v'}, startHour: 7, durationHours: 3));
    final r = DesignResults(timestamp: DateTime(2026))
      ..systemFlows.add(
        SystemFlowResult(
          flowId: 'f1',
          name: 'F1',
          converged: true,
          totalFlow: 0.01,
          durationHours: 3,
          pipes: const [],
          devices: const [],
          warnings: const [],
          supplies: [SupplyDuty(supplyId: 's', name: 's', flow: 0.01, head: 40, requiredHead: 40, elevation: 0, calculated: true)],
          valves: [ValveDuty(valveId: 'v', zoneName: 'v', flow: 0.01, availableHead: 20, requiredHead: 20, p: Pt.zero)],
        ),
      );
    final jobs = tariffJobsFromDesign(p, r);
    expect(jobs.single.id, 'f1');
    expect(jobs.single.hours, 3);
    expect(jobs.single.startHour, 7);
    expect(jobs.single.powerKw, closeTo(waterDensity * gravity * 0.01 * 40 / 0.65 / 1000, 1e-9));
  });
}
