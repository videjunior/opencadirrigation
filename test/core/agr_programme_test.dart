import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/irrigation_programme.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The controller programme (1.6.0 AGR, PRD-27): the daily irrigation
/// window, cycle and soak (SWAT protocol), the seasonal adjustment and the
/// programme by station.
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];

  group('one day of the programme', () {
    test('cycles of one flow leave room for the next flow during the soak', () {
      final day = DateTime(2026, 1, 5);
      ScheduleEntry entry(String id, double hours) => ScheduleEntry(day: day, flowId: id, flowName: id, startHour: 0, durationHours: hours, zones: [id], flow: 0);
      final runs = layoutProgrammeDay(day, [entry('A', 1.5), entry('B', 0.5)], {
        'A': const FlowCycles(flowId: 'A', cycles: 3, runMinutes: 30, soakMinutes: 60, runoffFree: true),
      }, 6);
      // A1 06:00–06:30, B 06:30–07:00 while A soaks, A2 at 07:30, A3 at 09:00
      expect([for (final r in runs) '${r.flowId}${r.cycle}/${r.cycles}'], ['A1/3', 'B1/1', 'A2/3', 'A3/3']);
      expect([for (final r in runs) r.startHour], [6.0, 6.5, 7.5, 9.0]);
      expect(runs.every((r) => (r.durationHours - 0.5).abs() < 1e-12), isTrue);
      expect(runs.last.endHour, 9.5);
      // without cycles the flows follow one another from the window start
      final plain = layoutProgrammeDay(day, [entry('A', 1.5), entry('B', 0.5)], const {}, 20);
      expect([for (final r in plain) r.startHour], [20.0, 21.5]);
      expect(plain.last.endHour, 22.0);
      expect(clockText(plain.last.endHour + 3, t: (k) => '+{n} d'), '01:00 +1 d');
    });
  });

  group('cycle and soak of a flow', () {
    // an area on [soil]; its rate is passed in (24 mm/h: four 12F sprays at 20 m on 100 m²)
    Project sprays(String soil) => Project(
      entities: [AreaEntity(id: 'a', points: square, soilKey: soil, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.5)],
    );

    test('sprays on clay: the event split so each cycle stays below the runoff', () {
      final p = sprays('soil.clay');
      final a = p.entities.single as AreaEntity;
      // 24 mm in an hour; clay takes 2.54 mm/h and holds 5.08 mm: cycles of at most 14.2 min
      final c = flowCycles(p, 'f', 1, [a], {'a': 24.0}, ProgrammeSettings(cycleSoak: true))!;
      expect(c.cycles, 5);
      expect(c.runMinutes, closeTo(12, 1e-9));
      expect(c.soakMinutes, closeTo(60 * 4.8 / 2.54 - 12, 1e-6));
      expect(c.runoffFree, isTrue);
      expect(c.areaId, 'a');
      // fewer cycles than the soil asks for: some water still runs off
      final few = flowCycles(p, 'f', 1, [a], {'a': 24.0}, ProgrammeSettings(cycleSoak: true, maxCycles: 3))!;
      expect(few.cycles, 3);
      expect(few.runoffFree, isFalse);
    });

    test('a sandy soil, drip or no soil need no cycles', () {
      final sand = sprays('soil.sand');
      expect(flowCycles(sand, 'f', 1, [sand.entities.single as AreaEntity], {'a': 24.0}, ProgrammeSettings()), isNull);
      final none = sprays('');
      expect(flowCycles(none, 'f', 1, [none.entities.single as AreaEntity], {'a': 24.0}, ProgrammeSettings()), isNull);
      final drip = sprays('soil.clay');
      (drip.entities.single as AreaEntity).irrigationMethod = 'localized';
      expect(flowCycles(drip, 'f', 1, [drip.entities.single as AreaEntity], {'a': 24.0}, ProgrammeSettings()), isNull);
    });
  });

  group('programme of a designed project', () {
    late Project p;
    late DesignResults r;
    setUpAll(() {
      p = buildExample(ExampleId.orchard, t);
      r = Designer(p, label: t).designAll();
    });

    test('by default the runs are the flows of every day, one after another', () {
      p.agronomy.programme = ProgrammeSettings();
      final prog = buildIrrigationProgramme(p, r, startDate: DateTime(2026, 1, 1), days: 7);
      expect(prog.runs, hasLength(prog.base.entries.length));
      for (final e in prog.base.entries) {
        final run = prog.runs.singleWhere((x) => x.day == e.day && x.flowId == e.flowId);
        expect(run.startHour, closeTo(e.startHour, 1e-9));
        expect(run.durationHours, closeTo(e.durationHours, 1e-9));
        expect(run.cycles, 1);
      }
      expect(prog.cycles, isEmpty);
      expect(prog.windowHours, 24);
      expect(prog.warnings.where((w) => w.startsWith('schedule_over')), isEmpty);
      expect(prog.seasonalPct, hasLength(12));
      expect(prog.seasonalPct.every((x) => x >= 0 && x <= 300), isTrue);
      // one station per zone valve of the flows, a run time for every month
      final valves = {for (final f in p.systemFlows) ...f.valveIds};
      expect(prog.stations.map((s) => s.demandId).toSet(), valves);
      expect(prog.stations.every((s) => s.minutesByMonth.length == 12), isTrue);
      final csv = programmeStationsCsv(prog, t: t).split('\n').where((l) => l.isNotEmpty).toList();
      expect(csv, hasLength(prog.stations.length + 2), reason: 'titles, stations and the seasonal line');
      expect(csv.first, startsWith('\u{FEFF}prog.controller;prog.station'));
      final runsCsv = programmeRunsCsv(prog, t: t).split('\n').where((l) => l.isNotEmpty).toList();
      expect(runsCsv, hasLength(prog.runs.length + 1));
    });

    test('a short window starts at its hour and warns when the day does not fit', () {
      p.agronomy.programme = ProgrammeSettings(windowStartHour: 20, windowHours: 1);
      final prog = buildIrrigationProgramme(p, r, startDate: DateTime(2026, 1, 1), days: 3);
      final firstOfDay = <DateTime, double>{};
      for (final run in prog.runs) {
        firstOfDay[run.day] = firstOfDay[run.day] == null || run.startHour < firstOfDay[run.day]! ? run.startHour : firstOfDay[run.day]!;
      }
      expect(firstOfDay.values.every((h) => h == 20), isTrue);
      expect(prog.maxDailyWindowHours, greaterThan(1));
      expect(prog.warnings.any((w) => w.startsWith('schedule_over_window:')), isTrue);
      p.agronomy.programme = ProgrammeSettings();
    });

    test('seasonal shares typed in the settings win, kept between 0 and 300 %', () {
      p.agronomy.programme = ProgrammeSettings(seasonalPct: [for (var m = 1; m <= 12; m++) m == 12 ? 350.0 : 10.0 * m]);
      final s = seasonalAdjustment(p, r);
      expect(s.first, 10);
      expect(s[10], 110);
      expect(s.last, 300);
      p.agronomy.programme = ProgrammeSettings();
    });
  });
}
