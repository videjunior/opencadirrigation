/// The irrigation programme as a calendar file (1.7.0): one event per start
/// of every group of zones (a run of a system flow, or one cycle of it with
/// cycle and soak) at its local clock time, for its run time, repeating
/// every period of the programme, so that the grower has the schedule on
/// the phone's calendar. Written by `io/ics.dart` (RFC 5545).
///
/// The programme repeats after its period (`programme_playback.dart`): a
/// run on day d of the cycle comes back on days d + P, d + 2P… — an RRULE
/// `FREQ=DAILY;INTERVAL=P` with the COUNT of the repeats that start within
/// [horizonDays]. A programme whose period is longer than the days the time
/// line holds ([ProgrammeTimeline.exact] false) gets its runs once each,
/// without repeats. The run times are those of the month the programme was
/// built for (the design month of every area unless one was chosen); the
/// seasonal adjustment of the other months is not applied.
library;

import 'dart:math' as math;

import '../io/ics.dart';
import 'programme_playback.dart';

/// The text of an .ics file of [tl] for project [projectName], stamped at
/// [stamp], repeating for [horizonDays] days from the first day of the time
/// line. [t] gives the translated templates (`ply.ics.*`, `sch.zones`,
/// `mon.<m>`).
String programmeCalendar(ProgrammeTimeline tl, {required String projectName, required DateTime stamp, int horizonDays = 30, required String Function(String key) t}) => writeIcs(
  prodId: '-//OpenCADIrrigation//Irrigation programme//EN',
  name: t('ply.ics.name').replaceAll('{p}', projectName),
  events: programmeEvents(tl, projectName: projectName, horizonDays: horizonDays, t: t),
  stamp: stamp,
);

/// "1 h 30 min", "45 min".
String _runTime(double hours) {
  final m = math.max(1, (hours * 60).round());
  final h = m ~/ 60, r = m % 60;
  if (h == 0) return '$r min';
  return r == 0 ? '$h h' : '$h h $r min';
}

/// The events of [programmeCalendar].
List<IcsEvent> programmeEvents(ProgrammeTimeline tl, {required String projectName, int horizonDays = 30, required String Function(String key) t}) {
  final horizon = math.max(1, horizonDays);
  final period = tl.days;
  final month = tl.programme.base.month;
  final monthText = month == null ? t('ply.ics.designMonth') : t('ply.ics.month').replaceAll('{m}', t('mon.$month'));
  final out = <IcsEvent>[];
  final dayIndex = <Object, int>{for (final s in tl.spans) s.run: s.dayIndex};
  for (final r in tl.runs) {
    final d = dayIndex[r] ?? 0;
    final minutes = (r.startHour * 60).round();
    // the day it starts on (a run laid out past midnight starts the next day)
    final first = d + minutes ~/ (24 * 60);
    if (first >= horizon) continue;
    // calendar arithmetic on the fields (a day of a change to summer time
    // keeps its clock times)
    final clock = minutes % (24 * 60);
    final start = DateTime(tl.startDate.year, tl.startDate.month, tl.startDate.day + first, clock ~/ 60, clock % 60);
    final repeats = tl.exact ? (horizon - 1 - first) ~/ period + 1 : 1;
    final rule = repeats <= 1 ? null : 'FREQ=DAILY${period > 1 ? ';INTERVAL=$period' : ''};COUNT=$repeats';
    final cycle = r.cycles > 1 ? ' (${r.cycle}/${r.cycles})' : '';
    final lines = [
      if (r.zones.isNotEmpty) '${t('sch.zones')}: ${r.zones.join(', ')}',
      t('ply.ics.runTime').replaceAll('{t}', _runTime(r.durationHours)),
      if (r.cycles > 1) t('ply.ics.cycle').replaceAll('{n}', '${r.cycle}').replaceAll('{of}', '${r.cycles}'),
      monthText,
      t('ply.ics.from').replaceAll('{p}', projectName),
    ];
    final safeFlow = r.flowId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    out.add(
      IcsEvent(
        uid: 'irrigation-${icsHash('$projectName|${r.flowId}')}-$safeFlow-d${d + 1}-c${r.cycle}@opencadirrigation.com',
        start: start,
        duration: Duration(minutes: math.max(1, (r.durationHours * 60).round())),
        summary: '${t('ply.ics.summary').replaceAll('{flow}', r.flowName)}$cycle',
        description: lines.join('\n'),
        rrule: rule,
      ),
    );
  }
  return out;
}
