import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/irrigation_programme.dart';
import 'package:opencadirrigation/core/design/programme_playback.dart';
import 'package:opencadirrigation/core/design/reservoir.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The irrigation programme played on the plan (1.7.0): the time line of
/// the cycle (what runs when, across midnight, days that differ, the
/// period), the state of the system at a moment of a designed example, and
/// the level of a reservoir along the cycle against hand-computed values.
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  final day0 = DateTime(2026, 1, 5);

  ProgrammeRun run(String flow, int day, double start, double hours, {int cycle = 1, int cycles = 1}) => ProgrammeRun(
    day: day0.add(Duration(days: day)),
    flowId: flow,
    flowName: 'Flow $flow',
    zones: ['Zone $flow'],
    startHour: start,
    durationHours: hours,
    cycle: cycle,
    cycles: cycles,
  );

  IrrigationProgramme programme(List<ProgrammeRun> runs) => IrrigationProgramme(
    base: ControllerProgram(perFlowHours: const {}, entries: const [], warnings: const []),
    runs: runs,
    cycles: const {},
    seasonalPct: List.filled(12, 100.0),
    windowStartHour: 6,
    windowHours: 24,
    warnings: const [],
    stations: const [],
  );

  List<String> at(ProgrammeTimeline tl, double h) => [for (final s in tl.runningAt(h)) s.flowId];

  group('the period of the programme', () {
    test('the least common multiple of the intervals of the flows', () {
      expect(programmePeriodDays(const []), 1);
      expect(programmePeriodDays(const [1, 1]), 1);
      expect(programmePeriodDays(const [12, 6]), 12);
      expect(programmePeriodDays(const [2, 3]), 6);
      expect(programmePeriodDays(const [4, 6, 1]), 12);
      expect(programmePeriodDays(const [0, 5]), 5, reason: 'an interval below one day counts as daily');
    });
  });

  group('the time line of a cycle', () {
    test('one day: which group runs at a time, ends excluded, the next start wraps', () {
      final tl = programmeTimeline(programme([run('A', 0, 6, 2), run('B', 0, 8, 1.5)]), startDate: day0, days: 1);
      expect(tl.hours, 24);
      expect(tl.exact, isTrue);
      expect(at(tl, 5.99), isEmpty);
      expect(at(tl, 6), ['A']);
      expect(at(tl, 7.9), ['A']);
      expect(at(tl, 8), ['B'], reason: 'a run ends where the next starts');
      expect(at(tl, 9.5), isEmpty);
      expect(at(tl, 24 + 7), ['A'], reason: 'times are taken into the cycle');
      expect(at(tl, -17), ['A']);
      expect(tl.nextStart(6.5), 8);
      expect(tl.nextStart(9), 6, reason: 'after the last start, the first one of the next cycle');
      expect(tl.changes, [0, 6, 8, 9.5]);
      expect(tl.overlaps, isFalse);
      expect(tl.clockAt(7.25), '07:15', reason: 'a one-day cycle writes the time alone');
    });

    test('a run past midnight goes on from the start of the cycle', () {
      final tl = programmeTimeline(programme([run('A', 0, 22, 4), run('B', 0, 26.5, 1)]), startDate: day0, days: 1);
      // A 22:00–02:00 (two spans), B at 02:30 of the next day = 02:30 of the cycle
      expect(tl.spans.map((s) => (s.flowId, s.start, s.end, s.carried)).toList(), [('A', 0.0, 2.0, true), ('B', 2.5, 3.5, false), ('A', 22.0, 24.0, false)]);
      expect(at(tl, 1), ['A']);
      expect(at(tl, 23), ['A']);
      expect(at(tl, 2.2), isEmpty);
      expect(at(tl, 3), ['B']);
      expect(tl.nextStart(0.5), 2.5, reason: 'the part carried on from midnight is no start');
      expect(tl.nextStart(4), 22);
      expect(tl.overlaps, isFalse);
    });

    test('days that differ: the cycle holds every day, with the day in the clock', () {
      final tl = programmeTimeline(programme([run('A', 0, 6, 2), run('B', 1, 6, 2), run('C', 1, 23, 3), run('X', 2, 6, 1)]), startDate: day0, days: 2);
      expect(tl.hours, 48);
      expect(tl.runs.map((r) => r.flowId), ['A', 'B', 'C'], reason: 'the runs of later days are left out');
      expect(at(tl, 7), ['A']);
      expect(at(tl, 24 + 7), ['B']);
      expect(at(tl, 24 + 23.5), ['C']);
      expect(at(tl, 1), ['C'], reason: 'C goes on past the end of the second day into the first');
      expect(tl.clockAt(24 + 7, dayLabel: (d) => 'Day $d'), 'Day 2 07:00');
      expect(tl.clockAt(6, dayLabel: (d) => 'Day $d'), 'Day 1 06:00');
      expect(tl.clockAt(47.9999), 'D1 00:00', reason: 'rounded to the minute into the next day');
    });

    test('overlapping runs are found', () {
      final tl = programmeTimeline(programme([run('A', 0, 6, 3), run('B', 0, 8, 2)]), startDate: day0, days: 1);
      expect(at(tl, 8.5), ['A', 'B']);
      expect(tl.overlaps, isTrue);
    });

    test('the frames of an animation: even steps and one in every short run', () {
      final tl = programmeTimeline(programme([run('A', 0, 6, 2), run('B', 0, 8.1, 0.1)]), startDate: day0, days: 1);
      final times = playbackFrameTimes(tl, 12);
      expect(times.length, 13, reason: '12 steps of 2 h and the middle of B, which none falls in');
      expect(times, contains(closeTo(8.15, 1e-9)));
      expect(times, orderedEquals([...times]..sort()));
      expect(playbackDefaultFrames(1), 48);
      expect(playbackDefaultFrames(7), 84);
      expect(playbackDefaultFrames(28), 96);
    });
  });

  group('designed examples', () {
    test('the cycle is one period of the programme: the next period repeats it', () {
      for (final id in [ExampleId.golf, ExampleId.garden, ExampleId.greenhouse, ExampleId.orchard]) {
        final p = buildExample(id, t);
        final r = Designer(p, label: t).designAll();
        final tl = buildProgrammeTimeline(p, r, startDate: day0);
        final intervals = buildControllerProgram(p, r, startDate: day0, days: 1).intervalDays;
        expect(tl.periodDays, programmePeriodDays(intervals.values), reason: id.name);
        expect(tl.exact, isTrue, reason: id.name);
        expect(tl.spans, isNotEmpty, reason: id.name);
        // the programme over two periods: the second is the first again
        final twice = buildIrrigationProgramme(p, r, startDate: day0, days: 2 * tl.days, withStations: false);
        String key(ProgrammeRun x, int shift) => '${x.day.difference(day0).inDays - shift} ${x.flowId} ${x.startHour.toStringAsFixed(6)} ${x.durationHours.toStringAsFixed(6)}';
        final first = [
          for (final x in twice.runs)
            if (x.day.difference(day0).inDays < tl.days) key(x, 0),
        ];
        final second = [
          for (final x in twice.runs)
            if (x.day.difference(day0).inDays >= tl.days) key(x, tl.days),
        ];
        expect(second, first, reason: '${id.name}: period ${tl.days} days');
        expect(tl.runs.map((x) => key(x, 0)), first, reason: id.name);
      }
    });

    test('a daily programme is one day; one that differs by day takes its days', () {
      final gh = buildExample(ExampleId.greenhouse, t);
      final tlGh = buildProgrammeTimeline(gh, Designer(gh, label: t).designAll(), startDate: day0);
      expect(tlGh.days, 1);
      final golf = buildExample(ExampleId.golf, t);
      final tlGolf = buildProgrammeTimeline(golf, Designer(golf, label: t).designAll(), startDate: day0);
      expect(tlGolf.days, 2, reason: 'the fairways run every other day');
      expect(at(tlGolf, 7), ['sf3']);
      expect(at(tlGolf, 31), ['sf4']);
    });

    test('the state of the orchard at a moment: its group, flow, pump and supply from the results', () {
      final p = buildExample(ExampleId.orchard, t);
      final r = Designer(p, label: t).designAll();
      final pb = ProgrammePlayback.build(p, r, startDate: day0);
      final tl = pb.timeline;
      final first = tl.spans.first;
      final f = pb.frameAt(first.start + 0.5);
      expect(f.idle, isFalse);
      expect(f.running.map((s) => s.flowId), [first.flowId]);
      final sf = r.systemFlows.singleWhere((x) => x.flowId == first.flowId);
      expect(f.totalFlow, sf.totalFlow);
      expect(f.supplies.single.head, sf.supplies.single.head);
      final pump = p.entities.whereType<PumpEntity>().single;
      expect(f.pumpsOn, {pump.id});
      final pd = sf.devices.singleWhere((d) => d.entityId == pump.id);
      expect(f.pumpHeads[pump.id], pd.downstreamPressure);
      expect(f.overlap, isFalse);
      final view = f.flows.single;
      final members = p.systemFlows.singleWhere((x) => x.id == first.flowId).valveIds;
      // every emitter group of its zones is wet, every pipe with flow carries water
      final zones = [for (final v in members) r.zones[v]!];
      expect(view.wet.length, zones.fold(0, (n, z) => n + z.outlets.length));
      expect(view.pipes.where((x) => !x.mainline).length, zones.fold(0, (n, z) => n + z.pipes.where((s) => s.flow.abs() > 1e-9).length));
      expect(view.pipes.where((x) => x.mainline).length, sf.pipes.where((s) => s.flow.abs() > 1e-9).length);
      expect(view.pipes.every((x) => x.velocity >= 0 && x.flow > 0), isTrue);
      expect(view.areas, isNotEmpty);
      expect(view.solved, isTrue);
      // at rest before the first run of the day
      final rest = pb.frameAt(3);
      expect(rest.idle, isTrue);
      expect(rest.totalFlow, 0);
      expect(rest.pumpsOn, isEmpty);
      expect(rest.supplies, isEmpty);
      // the other group on its own day
      final other = tl.spans.firstWhere((s) => s.flowId != first.flowId);
      final g = pb.frameAt(other.start + 0.1);
      expect(g.running.single.flowId, other.flowId);
      expect(g.totalFlow, r.systemFlows.singleWhere((x) => x.flowId == other.flowId).totalFlow);
    });

    test('without system flows every zone runs together (the auto flow of the design)', () {
      final p = buildExample(ExampleId.greenhouse, t);
      p.systemFlows.clear();
      final r = Designer(p, label: t).designAll();
      final pb = ProgrammePlayback.build(p, r, startDate: day0);
      expect(pb.timeline.spans.map((s) => s.flowId).toSet(), {'auto'});
      final f = pb.frameAt(pb.timeline.spans.first.start + 0.1);
      expect(f.flows.single.demands.toSet(), {...p.entities.whereType<ControlValveEntity>().map((v) => v.id)});
      expect(f.totalFlow, r.systemFlows.singleWhere((x) => x.flowId == 'auto').totalFlow);
    });

    test('a project without runs gives an empty time line', () {
      final p = buildExample(ExampleId.pivot, t);
      final r = Designer(p, label: t).designAll();
      expect(ProgrammePlayback.build(p, r, startDate: day0).timeline.isEmpty, isTrue, reason: 'the pivot is in no system flow of the programme');
      expect(buildProgrammeTimeline(Project(), null, startDate: day0).isEmpty, isTrue);
    });
  });

  group('overlapping groups', () {
    test('their flows add up, the supply shows the higher pressure, both pumps run', () {
      final tl = programmeTimeline(programme([run('A', 0, 6, 3), run('B', 0, 8, 2)]), startDate: day0, days: 1);
      FlowView view(String id, double q, double head, String pump) => FlowView(
        flowId: id,
        name: id,
        demands: [id],
        areas: const [],
        machines: const [],
        wet: const [],
        pipes: const [],
        pumps: {pump},
        pumpHeads: {pump: head + 10},
        totalFlow: q,
        supplies: [SupplyDuty(supplyId: 'w', name: 'W', flow: q, head: head, requiredHead: head, elevation: 0, calculated: true)],
        bounds: Bounds.empty,
      );
      final pb = ProgrammePlayback(
        timeline: tl,
        flows: {'A': view('A', 0.01, 20, 'p1'), 'B': view('B', 0.004, 25, 'p2')},
        pumps: const [],
        reservoirs: const [],
        results: DesignResults(timestamp: day0),
      );
      final f = pb.frameAt(8.5);
      expect(f.overlap, isTrue);
      expect(f.totalFlow, closeTo(0.014, 1e-12));
      expect(f.supplies.single.flow, closeTo(0.014, 1e-12));
      expect(f.supplies.single.head, 25);
      expect(f.pumpsOn, {'p1', 'p2'});
      expect(pb.frameAt(7).overlap, isFalse);
    });
  });

  group('the reservoir along the cycle', () {
    // a basin with vertical walls: 1000 m² from the bottom at 100 m to the full level at 103 m
    ReservoirStudy basin({double initial = 102.5, double inflow = 0.002}) => ReservoirStudy(
      supplyId: 'w',
      curve: [for (var z = 0; z <= 3; z++) ReservoirStage(level: 100.0 + z, area: 1000, volume: 1000.0 * z)],
      bottom: 100,
      fullLevel: 103,
      minLevel: 100.5,
      initialLevel: initial,
      inflow: inflow,
    );
    // one group drawing 0.05 m³/s (180 m³/h) from 06:00 to 08:00
    final tl = programmeTimeline(programme([run('A', 0, 6, 2)]), startDate: day0, days: 1);
    double draw(String f) => f == 'A' ? 0.05 : 0;

    test('the volume follows the inflow less the draw (hand-computed)', () {
      final tr = reservoirTrace(basin(), tl, draw);
      // 2500 m³ at the start; +7.2 m³/h for 6 h; −172.8 m³/h for 2 h; +7.2 m³/h for 16 h
      expect(tr.volumeAt(0), closeTo(2500, 1e-9));
      expect(tr.volumeAt(6), closeTo(2543.2, 1e-9));
      expect(tr.volumeAt(8), closeTo(2197.6, 1e-9));
      expect(tr.volumeAt(24), closeTo(2312.8, 1e-9));
      expect(tr.levelAt(8), closeTo(102.1976, 1e-9));
      expect(tr.levelAt(7), closeTo(100 + (2543.2 - 172.8) / 1000, 1e-9));
      expect(tr.netChange, closeTo(7.2 * 24 - 180 * 2, 1e-9));
      expect(tr.dry, isFalse);
      expect(tr.spills, isFalse);
    });

    test('the intake runs dry at the lowest operating level, and the level waits there', () {
      final tr = reservoirTrace(basin(initial: 100.6), tl, draw);
      // 600 m³, 643.2 m³ at 06:00, the 500 m³ of the intake level after 143.2 / 172.8 h
      final dryAt = 6 + 143.2 / 172.8;
      expect(tr.dry, isTrue);
      expect(tr.volumeAt(dryAt), closeTo(500, 1e-9));
      expect(tr.levelAt(7.5), closeTo(100.5, 1e-9));
      expect(tr.levelAt(8), closeTo(100.5, 1e-9));
      expect(tr.volumeAt(24), closeTo(500 + 7.2 * 16, 1e-9));
    });

    test('a full reservoir with an inflow spills', () {
      final tr = reservoirTrace(basin(initial: 102.99), tl, draw);
      expect(tr.spills, isTrue);
      expect(tr.volumeAt(10 / 7.2), closeTo(3000, 1e-9));
      expect(tr.levelAt(5), closeTo(103, 1e-9));
    });

    test('the stage–volume curve read the other way', () {
      final s = basin();
      expect(reservoirLevelOf(s, 0), 100);
      expect(reservoirLevelOf(s, 1500), closeTo(101.5, 1e-12));
      expect(reservoirLevelOf(s, 3500), closeTo(103.5, 1e-12), reason: 'straight on beyond the full level');
      for (final z in [100.25, 101.0, 102.7]) {
        expect(reservoirLevelOf(s, s.volumeAt(z)), closeTo(z, 1e-12));
      }
    });

    test('a designed supply with a reservoir gets its level in every frame', () {
      final p = buildExample(ExampleId.orchard, t);
      final supply = p.entities.whereType<WaterSupplyEntity>().single;
      // a pond of 40 × 40 m around the supply, 2 m deep under its full level
      final c = supply.position;
      final pond = AreaEntity(id: p.newId(), points: [Pt(c.x - 20, c.y - 20), Pt(c.x + 20, c.y - 20), Pt(c.x + 20, c.y + 20), Pt(c.x - 20, c.y + 20)]);
      p.entities.add(pond);
      supply.reservoir = ReservoirSpec(outlineId: pond.id, kind: ReservoirKind.excavated, fullLevelM: 100, bottomM: 98, sideSlope: 0);
      final r = Designer(p, label: t).designAll();
      final pb = ProgrammePlayback.build(p, r, startDate: day0);
      expect(pb.reservoirs, hasLength(1));
      final tr = pb.reservoirs.single;
      final first = pb.timeline.spans.first;
      final f0 = pb.frameAt(first.start), f1 = pb.frameAt(first.end);
      expect(f0.levels[supply.id], closeTo(100, 1e-6), reason: 'full at the start of the day');
      final drawn = r.systemFlows.singleWhere((x) => x.flowId == first.flowId).supplies.single.flow * 3600 * (first.end - first.start);
      expect(tr.volumeAt(first.end), closeTo(tr.volumeAt(first.start) - drawn, 1e-6 * drawn), reason: 'no inflow: the volume drawn by the run');
      expect(f1.levels[supply.id]!, lessThan(f0.levels[supply.id]!));
    });
  });

  test('ProgrammeSettings stay as the project has them', () {
    final p = buildExample(ExampleId.greenhouse, t);
    p.agronomy.programme = ProgrammeSettings(windowStartHour: 20);
    final r = Designer(p, label: t).designAll();
    final tl = buildProgrammeTimeline(p, r, startDate: day0);
    expect(tl.spans.where((s) => !s.carried).first.start, 20, reason: 'the window opens at 20:00');
    expect(tl.spans.any((s) => s.carried), isFalse, reason: 'the two zones end before midnight');
  });
}
