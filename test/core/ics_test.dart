import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/irrigation_programme.dart';
import 'package:opencadirrigation/core/design/programme_calendar.dart';
import 'package:opencadirrigation/core/design/programme_playback.dart';
import 'package:opencadirrigation/core/io/ics.dart';

/// The programme as an iCalendar file (RFC 5545, 1.7.0): the format rules
/// (CRLF, folding at 75 octets without splitting a character, TEXT
/// escaping, UID and DTSTAMP on every event, floating local times,
/// DURATION and RRULE syntax) on hand-made calendars and on the calendar of
/// a designed example.
void main() {
  String t(String key) => switch (key) {
    'ply.ics.name' => 'Irrigation – {p}',
    'ply.ics.summary' => 'Irrigation: {flow}',
    'ply.ics.runTime' => 'Run time: {t}',
    'ply.ics.cycle' => 'Cycle {n} of {of}',
    'ply.ics.designMonth' => 'Run times of the design month',
    'ply.ics.month' => 'Run times of {m}',
    'ply.ics.from' => 'Programme of {p}',
    'sch.zones' => 'Zones',
    _ => key,
  };
  final day0 = DateTime(2026, 1, 5);
  final stamp = DateTime.utc(2026, 11, 10, 12, 30, 5);

  ProgrammeRun run(String flow, int day, double start, double hours, {int cycle = 1, int cycles = 1, List<String>? zones}) => ProgrammeRun(
    day: day0.add(Duration(days: day)),
    flowId: flow,
    flowName: 'Flow $flow',
    zones: zones ?? ['Zone $flow'],
    startHour: start,
    durationHours: hours,
    cycle: cycle,
    cycles: cycles,
  );

  ProgrammeTimeline timeline(List<ProgrammeRun> runs, int days, {int? period, int? month}) => programmeTimeline(
    IrrigationProgramme(
      base: ControllerProgram(perFlowHours: const {}, entries: const [], warnings: const [], month: month),
      runs: runs,
      cycles: const {},
      seasonalPct: List.filled(12, 100.0),
      windowStartHour: 6,
      windowHours: 24,
      warnings: const [],
      stations: const [],
    ),
    startDate: day0,
    days: days,
    periodDays: period,
  );

  /// The RFC rules every calendar of the program keeps.
  void checkFormat(String ics) {
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    // CRLF only: no bare LF and no bare CR
    expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
    expect(ics.replaceAll('\r\n', '').contains('\r'), isFalse);
    final physical = ics.split('\r\n')..removeLast();
    for (final l in physical) {
      expect(utf8.encode(l).length, lessThanOrEqualTo(75), reason: 'folded at 75 octets: "$l"');
    }
    final lines = icsUnfold(ics);
    expect(lines.sublist(0, 3), ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//OpenCADIrrigation//Irrigation programme//EN']);
    expect(lines.where((l) => l == 'BEGIN:VEVENT').length, lines.where((l) => l == 'END:VEVENT').length);
    final uids = <String>{};
    var inEvent = false;
    var seen = <String>{};
    for (final l in lines) {
      expect(RegExp(r'^[A-Z][A-Z0-9-]*[:;]').hasMatch(l), isTrue, reason: 'a content line is name:value: "$l"');
      if (l == 'BEGIN:VEVENT') {
        inEvent = true;
        seen = {};
        continue;
      }
      if (l == 'END:VEVENT') {
        inEvent = false;
        for (final k in ['UID', 'DTSTAMP', 'DTSTART', 'DURATION', 'SUMMARY']) {
          expect(seen, contains(k), reason: 'every event has $k');
        }
        continue;
      }
      if (!inEvent) continue;
      final name = l.substring(0, l.indexOf(':'));
      final value = l.substring(l.indexOf(':') + 1);
      expect(seen.add(name), isTrue, reason: '$name once per event');
      switch (name) {
        case 'UID':
          expect(uids.add(value), isTrue, reason: 'UIDs are unique: $value');
          expect(value, matches(RegExp(r'^[A-Za-z0-9_.-]+@opencadirrigation\.com$')));
        case 'DTSTAMP':
          expect(value, matches(RegExp(r'^\d{8}T\d{6}Z$')), reason: 'DTSTAMP in UTC');
        case 'DTSTART':
          expect(value, matches(RegExp(r'^\d{8}T\d{6}$')), reason: 'local floating time: no Z, no TZID');
        case 'DURATION':
          expect(value, matches(RegExp(r'^PT(\d+H)?(\d+M)?$')));
          expect(value, isNot('PT'));
        case 'RRULE':
          expect(value, matches(RegExp(r'^FREQ=DAILY(;INTERVAL=\d+)?;COUNT=\d+$')));
        case 'SUMMARY' || 'DESCRIPTION':
          // TEXT: commas and semicolons escaped, no raw line break
          expect(value.replaceAll(r'\\', '').replaceAll(r'\,', '').replaceAll(r'\;', '').contains(RegExp('[,;]')), isFalse, reason: value);
      }
    }
  }

  group('the format', () {
    test('TEXT escapes backslash, semicolon and comma, and writes line breaks as \\n', () {
      expect(icsText(r'a,b;c\d'), r'a\,b\;c\\d');
      expect(icsText('one\ntwo\r\nthree'), r'one\ntwo\nthree');
      expect(icsText('plain'), 'plain');
    });

    test('a long line is folded at 75 octets and unfolds to itself, UTF-8 kept whole', () {
      final ascii = 'DESCRIPTION:${'x' * 200}';
      final f = icsFold(ascii);
      expect(f.first.length, 75);
      expect(f.skip(1).every((l) => l.startsWith(' ') && l.length <= 75), isTrue);
      expect(icsUnfold('${f.join('\r\n')}\r\n').single, ascii);
      // two-, three- and four-byte characters near every cut
      final wide = 'SUMMARY:${'Irrigação – 💧 ' * 20}';
      final g = icsFold(wide);
      expect(g.length, greaterThan(3));
      for (final l in g) {
        expect(utf8.encode(l).length, lessThanOrEqualTo(75));
        expect(utf8.decode(utf8.encode(l)), l, reason: 'no character split across lines');
      }
      expect(icsUnfold('${g.join('\r\n')}\r\n').single, wide);
      expect(icsFold('SHORT:line'), ['SHORT:line']);
    });

    test('date-times, durations and the stable hash', () {
      expect(icsLocal(DateTime(2026, 11, 10, 6, 5)), '20261110T060500');
      expect(icsUtc(DateTime.utc(2026, 1, 2, 3, 4, 5)), '20260102T030405Z');
      expect(icsDuration(const Duration(minutes: 90)), 'PT1H30M');
      expect(icsDuration(const Duration(minutes: 45)), 'PT45M');
      expect(icsDuration(const Duration(hours: 2)), 'PT2H');
      expect(icsDuration(const Duration(hours: 26, minutes: 1)), 'PT26H1M');
      expect(icsDuration(Duration.zero), 'PT1M', reason: 'never an empty duration');
      // FNV-1a 32-bit test vectors (Fowler, Noll, Vo)
      expect(icsHash(''), '811c9dc5');
      expect(icsHash('a'), 'e40c292c');
      expect(icsHash('foobar'), 'bf9cf968');
    });

    test('a calendar holds VERSION, PRODID, the name and its events', () {
      final ics = writeIcs(
        prodId: '-//OpenCADIrrigation//Irrigation programme//EN',
        name: 'Rega, pomar; 2026',
        stamp: stamp,
        events: [
          IcsEvent(
            uid: 'a@opencadirrigation.com',
            start: DateTime(2026, 1, 5, 6),
            duration: const Duration(minutes: 30),
            summary: 'Rega: A, B',
            description: 'linha 1\nlinha 2',
            rrule: 'FREQ=DAILY;COUNT=3',
          ),
        ],
      );
      checkFormat(ics);
      final lines = icsUnfold(ics);
      expect(lines, contains(r'NAME:Rega\, pomar\; 2026'));
      expect(lines, contains(r'X-WR-CALNAME:Rega\, pomar\; 2026'));
      expect(lines, contains('DTSTAMP:20261110T123005Z'));
      expect(lines, contains('DTSTART:20260105T060000'));
      expect(lines, contains('DURATION:PT30M'));
      expect(lines, contains(r'SUMMARY:Rega: A\, B'));
      expect(lines, contains(r'DESCRIPTION:linha 1\nlinha 2'));
      expect(lines, contains('TRANSP:TRANSPARENT'));
    });
  });

  group('the programme as a calendar', () {
    test('a daily cycle: every run an event repeating every day for the horizon', () {
      final tl = timeline([
        run('A', 0, 6, 1.5, zones: ['North, east', 'South']),
        run('B', 0, 7.5, 0.5),
      ], 1);
      final ics = programmeCalendar(tl, projectName: 'Orchard', stamp: stamp, horizonDays: 30, t: t);
      checkFormat(ics);
      final lines = icsUnfold(ics);
      expect(lines, contains('X-WR-CALNAME:Irrigation – Orchard'));
      expect(lines.where((l) => l.startsWith('DTSTART:')), ['DTSTART:20260105T060000', 'DTSTART:20260105T073000']);
      expect(lines.where((l) => l.startsWith('DURATION:')), ['DURATION:PT1H30M', 'DURATION:PT30M']);
      expect(lines.where((l) => l.startsWith('RRULE:')), ['RRULE:FREQ=DAILY;COUNT=30', 'RRULE:FREQ=DAILY;COUNT=30']);
      expect(lines, contains('SUMMARY:Irrigation: Flow A'));
      expect(lines, contains(r'DESCRIPTION:Zones: North\, east\, South\nRun time: 1 h 30 min\nRun times of the design month\nProgramme of Orchard'));
    });

    test('a cycle of days: each run repeats every cycle, counted within the horizon', () {
      final tl = timeline([run('A', 0, 6, 2), run('B', 1, 6, 0.75), run('C', 1, 25, 1)], 2);
      final events = programmeEvents(tl, projectName: 'P', horizonDays: 30, t: t);
      // days 1, 3… 29 and 2, 4… 30 of 30; C starts on day 3 (past midnight), so 3… 29
      expect(events.map((e) => e.rrule), ['FREQ=DAILY;INTERVAL=2;COUNT=15', 'FREQ=DAILY;INTERVAL=2;COUNT=15', 'FREQ=DAILY;INTERVAL=2;COUNT=14']);
      expect(events.map((e) => e.start), [DateTime(2026, 1, 5, 6), DateTime(2026, 1, 6, 6), DateTime(2026, 1, 7, 1)], reason: 'a run past midnight starts on the next day');
      // a horizon of 4 days: day 1 → 1, 3; day 2 → 2, 4; C → day 3 only
      expect(programmeEvents(tl, projectName: 'P', horizonDays: 4, t: t).map((e) => e.rrule), ['FREQ=DAILY;INTERVAL=2;COUNT=2', 'FREQ=DAILY;INTERVAL=2;COUNT=2', null]);
      // one day: the run of the second day is not in it, the first happens once
      final one = programmeEvents(tl, projectName: 'P', horizonDays: 1, t: t);
      expect(one, hasLength(1));
      expect(one.single.rrule, isNull);
      checkFormat(programmeCalendar(tl, projectName: 'P', stamp: stamp, horizonDays: 30, t: t));
    });

    test('cycle and soak: one event per cycle, numbered; the month of the run times', () {
      final tl = timeline([run('A', 0, 6, 0.2, cycle: 1, cycles: 2), run('B', 0, 6.2, 0.5), run('A', 0, 7, 0.2, cycle: 2, cycles: 2)], 1, month: 3);
      final events = programmeEvents(tl, projectName: 'P', horizonDays: 7, t: t);
      expect(events.map((e) => e.summary), ['Irrigation: Flow A (1/2)', 'Irrigation: Flow B', 'Irrigation: Flow A (2/2)']);
      expect(events.first.description, contains('Cycle 1 of 2'));
      expect(events.first.description, contains('Run times of mon.3'));
      expect(events.map((e) => e.uid).toSet(), hasLength(3), reason: 'a UID per run');
      expect(events.first.duration, const Duration(minutes: 12));
    });

    test('a programme longer than the time line: every run once, no repeat', () {
      final tl = timeline([run('A', 0, 6, 1), run('B', 27, 6, 1)], 28, period: 35);
      expect(tl.exact, isFalse);
      final events = programmeEvents(tl, projectName: 'P', horizonDays: 60, t: t);
      expect(events.map((e) => e.rrule), [null, null]);
    });

    test('the UIDs stay the same when the file is made again', () {
      final tl = timeline([run('A', 0, 6, 1)], 1);
      final a = programmeEvents(tl, projectName: 'Pomar', t: t).single.uid;
      final b = programmeEvents(tl, projectName: 'Pomar', t: t).single.uid;
      expect(a, b);
      expect(programmeEvents(tl, projectName: 'Other', t: t).single.uid, isNot(a));
    });

    test('the calendar of a designed example keeps every rule', () {
      String id(String key, [Map<String, String>? args]) => key;
      for (final ex in [ExampleId.orchard, ExampleId.golf, ExampleId.garden]) {
        final p = buildExample(ex, id);
        final r = Designer(p, label: id).designAll();
        final tl = buildProgrammeTimeline(p, r, startDate: day0);
        final ics = programmeCalendar(tl, projectName: 'Projeto, teste; 1', stamp: stamp, horizonDays: 60, t: t);
        checkFormat(ics);
        final lines = icsUnfold(ics);
        expect(lines.where((l) => l == 'BEGIN:VEVENT').length, tl.runs.length, reason: ex.name);
        expect(lines.where((l) => l.startsWith('RRULE:')).every((l) => l.contains(tl.days > 1 ? 'INTERVAL=${tl.days};' : 'FREQ=DAILY;COUNT=')), isTrue, reason: ex.name);
      }
    });
  });
}
