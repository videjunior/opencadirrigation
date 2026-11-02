/// The controller programme as a controller is set (1.6.0): the run of
/// every system flow on its days (agronomy.dart: the shortest interval of
/// its areas, the longest run time they need), laid out
/// - inside the daily irrigation window (start hour and hours; the flows of
///   a day one after another from its start, `schedule_over_window` when
///   they do not fit);
/// - with cycle and soak for the sprinkler zones whose application rate
///   their soil does not take: each event split into cycles no longer than
///   the run before runoff, with the soak pause before the next cycle of
///   the same flow (Rt = 60·ASA/(PR − IR) and the start-to-start time Da/IR
///   of the SWAT protocol, water_budget.dart), other flows running during
///   the pauses (the controller's cycle and soak);
/// - with the seasonal adjustment of every month: the share (%) of the
///   design month's daily run time the requirement of the month needs (the
///   programme built for that month, from the monthly requirement of the
///   areas; or the shares typed in the settings);
/// and, per controller station, the valve, the areas, the flow, the
/// application rate and the run time per event of every month (PRD-27).
library;

import 'dart:math' as math;

import '../model/agronomy_plan.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'agronomy.dart';
import 'area_water.dart';
import 'designer.dart' show areaRequirements;
import 'management.dart' show demandName;
import 'network_builder.dart';
import 'results.dart';
import 'soils.dart';
import 'system_capacity.dart' show areasOfZoneNominal;
import 'valve_in_head.dart';
import 'water_budget.dart';

/// One run of a system flow: a whole event, or one cycle of it.
class ProgrammeRun {
  const ProgrammeRun({
    required this.day,
    required this.flowId,
    required this.flowName,
    required this.zones,
    required this.startHour,
    required this.durationHours,
    this.cycle = 1,
    this.cycles = 1,
    this.flow = 0,
  });
  final DateTime day;
  final String flowId;
  final String flowName;
  final List<String> zones;

  /// Hours after the midnight that starts [day] (may pass 24).
  final double startHour;
  final double durationHours;

  /// Cycle number and cycles of the event (1 of 1 without cycle and soak).
  final int cycle;
  final int cycles;

  /// Flow of the system flow (m³/s), from the results.
  final double flow;
  double get endHour => startHour + durationHours;
}

/// The runs of one [day] of the [entries] of the programme from [startHour]:
/// one flow at a time, the cycle that can start first next (a flow waits
/// for the soak pause after its last cycle; ties go to the order of the
/// entries), each event in the cycles of [cycles] (one when absent).
List<ProgrammeRun> layoutProgrammeDay(DateTime day, List<ScheduleEntry> entries, Map<String, FlowCycles> cycles, double startHour) {
  final out = <ProgrammeRun>[];
  final left = [for (final e in entries) cycles[e.flowId]?.cycles ?? 1];
  final avail = List<double>.filled(entries.length, startHour);
  var cursor = startHour;
  while (left.any((n) => n > 0)) {
    var pick = -1;
    var at = double.infinity;
    for (var k = 0; k < entries.length; k++) {
      if (left[k] <= 0) continue;
      final t = math.max(cursor, avail[k]);
      if (t < at - 1e-9) {
        at = t;
        pick = k;
      }
    }
    final e = entries[pick];
    final n = cycles[e.flowId]?.cycles ?? 1;
    final run = e.durationHours / n;
    out.add(ProgrammeRun(day: day, flowId: e.flowId, flowName: e.flowName, zones: e.zones, startHour: at, durationHours: run, cycle: n - left[pick] + 1, cycles: n, flow: e.flow));
    cursor = at + run;
    avail[pick] = cursor + (cycles[e.flowId]?.soakMinutes ?? 0.0) / 60;
    left[pick]--;
  }
  return out;
}

/// The cycle and soak of one system flow.
class FlowCycles {
  const FlowCycles({required this.flowId, required this.cycles, required this.runMinutes, required this.soakMinutes, required this.runoffFree, this.areaId});
  final String flowId;
  final int cycles;
  final double runMinutes;
  final double soakMinutes;

  /// False when the cycles were merged (shortest cycle, most cycles) and
  /// some water still runs off.
  final bool runoffFree;

  /// The area that sets them.
  final String? areaId;
}

/// One station of a controller in the programme (PRD-27).
class ProgrammeStation {
  const ProgrammeStation({
    required this.controller,
    required this.station,
    required this.demandId,
    required this.name,
    required this.areas,
    required this.flowM3h,
    required this.rateMmH,
    required this.flowId,
    required this.minutesByMonth,
    required this.intervalDays,
    this.cycles,
  });

  /// Controller name ('' without the wiring) and station number.
  final String controller;
  final int station;
  final String demandId;
  final String name;
  final List<String> areas;
  final double flowM3h;

  /// Application rate over its areas (mm/h).
  final double rateMmH;
  final String flowId;

  /// Run time per event (minutes) in every month, January first.
  final List<double> minutesByMonth;

  /// Days between events in the design month.
  final int intervalDays;
  final FlowCycles? cycles;
}

/// The programme (see the library notes).
class IrrigationProgramme {
  const IrrigationProgramme({
    required this.base,
    required this.runs,
    required this.cycles,
    required this.seasonalPct,
    required this.windowStartHour,
    required this.windowHours,
    required this.warnings,
    required this.stations,
  });

  /// The programme of the flows by day (durations and intervals).
  final ControllerProgram base;
  final List<ProgrammeRun> runs;

  /// Cycle and soak by flow id (flows split in more than one cycle).
  final Map<String, FlowCycles> cycles;

  /// Seasonal adjustment of every month (%), January first.
  final List<double> seasonalPct;
  final double windowStartHour;
  final double windowHours;

  /// Codes `schedule_over_window:<date>`, `schedule_cycle_runoff:<flow>`
  /// and those of [base].
  final List<String> warnings;
  final List<ProgrammeStation> stations;

  /// Hours from the window start to the end of the last run of the busiest
  /// day (the pauses of cycle and soak included).
  double get maxDailyWindowHours {
    final end = <DateTime, double>{};
    for (final r in runs) {
      end[r.day] = math.max(end[r.day] ?? 0.0, r.endHour - windowStartHour);
    }
    return end.values.fold(0.0, math.max);
  }
}

/// The areas the members of a system flow water: zones ([results] when
/// given, else the nominal emitters), valve-in-head stations, machines.
List<AreaEntity> areasOfFlow(Project p, DesignResults? results, Iterable<String> members, {VihStations? vih, NetworkModel Function()? model}) {
  final stations = vih ?? VihStations.of(p);
  NetworkModel? net;
  final out = <String, AreaEntity>{};
  for (final v in members) {
    final e = p.byId(v);
    final List<AreaEntity> areas;
    if (stations.isStation(v)) {
      areas = areasOfStation(p, v, stations: stations);
    } else if (e is PivotEntity) {
      areas = areasOfMachine(p, e);
    } else if (e is ControlValveEntity) {
      areas = results != null ? areasOfZone(p, results, v) : areasOfZoneNominal(p, net ??= model?.call() ?? NetworkBuilder(p).build(), v);
    } else {
      areas = const [];
    }
    for (final a in areas) {
      out[a.id] = a;
    }
  }
  return out.values.toList();
}

/// Cycle and soak of a flow that runs [hours] per event over [areas]: the
/// sprinkler area whose soil asks for the most cycles (null when none needs
/// more than one).
FlowCycles? flowCycles(Project p, String flowId, double hours, List<AreaEntity> areas, Map<String, double> rates, ProgrammeSettings s) {
  FlowCycles? best;
  for (final a in areas) {
    if (areaIrrigationMethod(a) != 'sprinkler') continue;
    final soil = soilTable[a.soilKey];
    final pr = rates[a.id] ?? 0.0;
    if (soil == null || pr <= 0 || hours <= 0) continue;
    final cs = cycleAndSoakForSoil(precipitationRateMmH: pr, depthMm: pr * hours, texture: soil.texture, slopePct: a.slopePct, minCycleMinutes: s.minCycleMinutes, maxCycles: s.maxCycles);
    if (cs.cycles <= 1) continue;
    if (best == null || cs.cycles > best.cycles || (cs.cycles == best.cycles && cs.soakMinutes > best.soakMinutes)) {
      best = FlowCycles(flowId: flowId, cycles: cs.cycles, runMinutes: cs.runMinutesPerCycle, soakMinutes: cs.soakMinutes, runoffFree: cs.runoffFree, areaId: a.id);
    }
  }
  return best;
}

/// The daily run time (hours per day: per event over the interval) of the
/// flows of [prog].
double _dailyHours(ControllerProgram prog) {
  var h = 0.0;
  for (final e in prog.perFlowHours.entries) {
    h += e.value / math.max(1, prog.intervalDays[e.key] ?? 1);
  }
  return h;
}

/// The programme of every month (January first) of [p].
List<ControllerProgram> monthlyProgrammes(Project p, DesignResults? results) => [for (var m = 1; m <= 12; m++) buildControllerProgram(p, results, days: 1, month: m)];

/// Seasonal adjustment of every month (%) of [p]: the daily run time of the
/// programme of the month ([monthly]) over that of the design month
/// ([design]); the shares typed in the settings when they hold them.
List<double> seasonalAdjustment(Project p, DesignResults? results, {List<ControllerProgram>? monthly, ControllerProgram? design}) {
  final typed = p.agronomy.programme.seasonalPct;
  if (typed != null && typed.length == 12) return [for (final x in typed) x.clamp(0.0, 300.0).toDouble()];
  final d = _dailyHours(design ?? buildControllerProgram(p, results, days: 1));
  final months = monthly ?? monthlyProgrammes(p, results);
  return [for (final m in months) d > 0 ? (100 * _dailyHours(m) / d).clamp(0.0, 300.0).toDouble() : 100.0];
}

/// The programme of [p] for [days] from [startDate] (the design month of
/// every area, or [month]) with the settings of the project
/// (`Project.agronomy.programme`).
IrrigationProgramme buildIrrigationProgramme(Project p, DesignResults? results, {DateTime? startDate, int days = 14, int? month, bool withStations = true}) {
  final s = p.agronomy.programme;
  final window = s.effectiveWindowHours;
  final start = s.windowStartHour.clamp(0.0, 24.0).toDouble();
  final base = buildControllerProgram(p, results, startDate: startDate, days: days, dayStartHour: start, month: month);
  final warnings = [...base.warnings.where((w) => !w.startsWith('schedule_over_24h'))];
  final vih = VihStations.of(p);
  final flows = p.systemFlows.isNotEmpty
      ? [
          for (final f in p.systemFlows)
            if (f.valveIds.isNotEmpty) (f.id, f.valveIds),
        ]
      : [
          ('auto', {...p.entities.whereType<ControlValveEntity>().map((v) => v.id), ...vih.heads.keys}),
        ];
  NetworkModel? model;
  NetworkModel net() => model ??= NetworkBuilder(p).build();
  final rates = {for (final r in areaRequirements(p, results)) r.areaId: r.precipitationMmH};
  final cycles = <String, FlowCycles>{};
  if (s.cycleSoak) {
    for (final (id, members) in flows) {
      final c = flowCycles(p, id, base.perFlowHours[id] ?? 0.0, areasOfFlow(p, results, members, vih: vih, model: net), rates, s);
      if (c == null) continue;
      cycles[id] = c;
      if (!c.runoffFree) warnings.add('schedule_cycle_runoff:$id');
    }
  }
  // the runs of every day, laid out from the window start: the cycle that
  // can start first goes next (a flow waits for its soak pause)
  final byDay = <DateTime, List<ScheduleEntry>>{};
  for (final e in base.entries) {
    (byDay[e.day] ??= []).add(e);
  }
  final runs = <ProgrammeRun>[];
  final days0 = byDay.keys.toList()..sort();
  for (final day in days0) {
    final dayRuns = layoutProgrammeDay(day, byDay[day]!, cycles, start);
    runs.addAll(dayRuns);
    final end = dayRuns.fold(start, (m, r) => math.max(m, r.endHour));
    if (end - start > window + 1e-6) warnings.add('schedule_over_window:${day.toIso8601String().substring(0, 10)}');
  }
  final monthly = monthlyProgrammes(p, results);
  final seasonal = seasonalAdjustment(p, results, monthly: monthly, design: base);
  return IrrigationProgramme(
    base: base,
    runs: runs,
    cycles: cycles,
    seasonalPct: seasonal,
    windowStartHour: start,
    windowHours: window,
    warnings: warnings.toSet().toList(),
    stations: withStations ? programmeStations(p, results, base, monthly, cycles, rates, model: net) : const [],
  );
}

/// The stations of the controllers in the programme (PRD-27): every zone
/// valve, valve-in-head station and machine of the flows, its controller
/// and station number (from the wiring of [results], else in the order of
/// the flows), areas, flow, rate and the run time per event of every month.
List<ProgrammeStation> programmeStations(
  Project p,
  DesignResults? results,
  ControllerProgram base,
  List<ControllerProgram> monthly,
  Map<String, FlowCycles> cycles,
  Map<String, double> rates, {
  NetworkModel Function()? model,
}) {
  final vih = VihStations.of(p);
  final members = <String, String>{}; // demand id → flow id
  if (p.systemFlows.isNotEmpty) {
    for (final f in p.systemFlows) {
      for (final v in f.valveIds) {
        members.putIfAbsent(v, () => f.id);
      }
    }
  } else {
    for (final v in [...p.entities.whereType<ControlValveEntity>().map((v) => v.id), ...vih.heads.keys]) {
      members[v] = 'auto';
    }
  }
  if (members.isEmpty) return const [];
  final runs = results?.electrical?.runs ?? const [];
  final ctrlName = {
    for (final c in p.entities.whereType<ControllerEntity>()) c.id: c.name.isNotEmpty ? c.name : c.id,
  };
  final demandFlow = <String, double>{
    for (final z in results?.zones.values ?? const <ZoneResult>[]) z.valveId: z.totalFlow,
    for (final e in results?.pivots.entries ?? const <MapEntry<String, PivotResult>>[]) e.key: e.value.flow,
  };
  final out = <ProgrammeStation>[];
  var next = 1;
  for (final e in members.entries) {
    final id = e.key, flowId = e.value;
    final run = runs.where((r) => r.valveId == id).firstOrNull;
    final areas = areasOfFlow(p, results, [id], vih: vih, model: model);
    final rate = areas.isEmpty ? 0.0 : areas.map((a) => rates[a.id] ?? 0.0).fold(0.0, math.max);
    out.add(
      ProgrammeStation(
        controller: run == null ? '' : (ctrlName[run.controllerId] ?? run.controllerId),
        station: run?.station ?? next,
        demandId: id,
        name: demandName(p, id),
        areas: [for (final a in areas) a.name.isNotEmpty ? a.name : a.id],
        flowM3h: (demandFlow[id] ?? 0.0) * 3600,
        rateMmH: rate,
        flowId: flowId,
        minutesByMonth: [for (final m in monthly) 60 * (m.perFlowHours[flowId] ?? 0.0)],
        intervalDays: base.intervalDays[flowId] ?? 1,
        cycles: cycles[flowId],
      ),
    );
    if (run == null) next++;
  }
  out.sort((a, b) {
    final c = a.controller.compareTo(b.controller);
    return c != 0 ? c : a.station.compareTo(b.station);
  });
  return out;
}

/// CSV of the runs of [prog] (one line per run, cycles numbered).
String programmeRunsCsv(IrrigationProgramme prog, {required String Function(String key) t}) {
  final b = StringBuffer('﻿');
  b.writeln([t('sch.date'), t('sch.flow'), t('sch.zones'), t('prog.cycle'), t('sch.start'), t('sch.end'), t('sch.duration')].join(';'));
  for (final r in prog.runs) {
    b.writeln(
      [
        r.day.toIso8601String().substring(0, 10),
        r.flowName,
        r.zones.join(' + '),
        '${r.cycle}/${r.cycles}',
        clockText(r.startHour, t: t),
        clockText(r.endHour, t: t),
        r.durationHours.toStringAsFixed(2),
      ].join(';'),
    );
  }
  return b.toString();
}

/// CSV of the stations of [prog] (PRD-27): one line per station with the
/// run time per event (minutes) of every month, and the seasonal
/// adjustment (%) in the last line.
String programmeStationsCsv(IrrigationProgramme prog, {required String Function(String key) t}) {
  final b = StringBuffer('﻿');
  b.writeln(
    [
      t('prog.controller'),
      t('prog.station'),
      t('sch.zones'),
      t('rep.area'),
      '${t('rep.flow')} (m³/h)',
      '${t('rep.rate')} (mm/h)',
      t('rep.interval'),
      t('prog.cycleSoak'),
      for (var m = 1; m <= 12; m++) t('mon.$m'),
    ].join(';'),
  );
  String n(double v, [int d = 1]) => v.toStringAsFixed(d);
  for (final s in prog.stations) {
    final c = s.cycles;
    b.writeln(
      [
        s.controller,
        s.station,
        s.name,
        s.areas.join(' + '),
        n(s.flowM3h, 2),
        n(s.rateMmH, 1),
        s.intervalDays,
        c == null ? '' : '${c.cycles} × ${c.runMinutes.round()} min / ${c.soakMinutes.round()} min',
        for (final m in s.minutesByMonth) n(m, 0),
      ].join(';'),
    );
  }
  b.writeln([t('prog.seasonal'), '', '', '', '', '', '', '', for (final x in prog.seasonalPct) n(x, 0)].join(';'));
  return b.toString();
}
