/// The irrigation programme played on the plan (1.7.0): the time line of
/// one cycle of the programme (`irrigation_programme.dart`), what runs at
/// every moment of it and the state of the system then — the zones that
/// water, the pipes that carry water with their flow and velocity, the
/// pumps on and off with the pressure at their outlet, the total flow and
/// the pressure at the supply, and the level of the reservoirs.
///
/// Method and assumptions:
/// - The cycle is the programme's own period: every system flow runs every
///   few days (its interval, `buildControllerProgram`) on staggered days, so
///   the programme repeats after the least common multiple of the intervals
///   (one day when every flow runs daily). The cycle is shown for at most
///   [playbackMaxDays] days; a longer period is cut there ([ProgrammeTimeline.exact]
///   false) and its wrap from the last day to the first is approximate.
/// - The cycle is circular: a run that passes the end of the cycle (a day's
///   runs that go past midnight) goes on from its start, as it does when
///   the programme repeats.
/// - The hydraulic state of a moment is the design result of the system
///   flow that runs then (`DesignResults.systemFlows`, and the zone results
///   of its zones): the flows, velocities, pressures and pumps of the steady
///   solution of that group, held for the whole run (no transient at the
///   starts and stops). When two flows overlap (a programme that does not
///   fit its window), their flows are added on the pipes they share and the
///   supply shows the higher of their pressures ([PlaybackFrame.overlap]):
///   the design did not solve them together.
/// - The level of a reservoir behind a supply follows the continuity of
///   its volume, dV/dt = Q_in − Q_out, with the flow every running group
///   draws from that supply (`SupplyDuty.flow`) and the stage–volume curve
///   of the reservoir study (`reservoir.dart`), from the level at the start
///   of the day of the reservoir settings at the start of the cycle; the
///   level stops at the lowest operating level (the intake runs dry) and at
///   the full level (the reservoir spills). It is the same balance the
///   24-hour simulation makes for a tank, along the times of the programme.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'agronomy.dart' show buildControllerProgram, clockTime;
import 'irrigation_programme.dart';
import 'reservoir.dart';
import 'results.dart';
import 'valve_in_head.dart';

/// Most days the player shows.
const playbackMaxDays = 28;

int _gcd(int a, int b) {
  while (b != 0) {
    final r = a % b;
    a = b;
    b = r;
  }
  return a;
}

/// The days after which a programme whose flows run every [intervals] days
/// repeats: their least common multiple (1 without any).
int programmePeriodDays(Iterable<int> intervals) {
  var p = 1;
  for (final i in intervals) {
    final n = math.max(1, i);
    p = p ~/ _gcd(p, n) * n;
    if (p > 1000000) return p;
  }
  return p;
}

/// One run of the programme on the time line of the cycle.
class PlaybackSpan {
  const PlaybackSpan({required this.run, required this.dayIndex, required this.start, required this.end, this.carried = false});
  final ProgrammeRun run;

  /// Day of the cycle (0 = the first) the run belongs to.
  final int dayIndex;

  /// Hours from the start of the cycle: 0 ≤ start < end ≤ the hours of the
  /// cycle (a run that passes the end goes on from 0 in a second span).
  final double start, end;

  /// The second span of a run that passes the end of the cycle (it carries
  /// the run on from 0; it is no start of a run).
  final bool carried;

  String get flowId => run.flowId;
  bool contains(double h) => h >= start - 1e-9 && h < end - 1e-9;
}

/// The cycle of the programme as a time line.
class ProgrammeTimeline {
  ProgrammeTimeline({required this.programme, required this.startDate, required this.days, required this.periodDays, required this.runs, required this.spans});

  /// The programme the cycle comes from.
  final IrrigationProgramme programme;

  /// Midnight of the first day of the cycle.
  final DateTime startDate;

  /// Days the cycle shows, and the days after which the programme repeats.
  final int days, periodDays;

  /// The runs of the days of the cycle, as the programme lays them out.
  final List<ProgrammeRun> runs;

  /// The runs on the time line, by start.
  final List<PlaybackSpan> spans;

  double get hours => days * 24.0;
  bool get isEmpty => spans.isEmpty;

  /// The cycle is the whole period of the programme (it repeats as shown).
  bool get exact => periodDays == days;

  /// [h] brought into the cycle, [0, hours).
  double wrap(double h) {
    final x = h % hours;
    return x < 0 ? x + hours : x;
  }

  /// The runs going on at [h].
  List<PlaybackSpan> runningAt(double h) {
    final x = wrap(h);
    return [
      for (final s in spans)
        if (s.contains(x)) s,
    ];
  }

  /// The next start of a run after [h], within the cycle (the first one of
  /// the cycle after the last); null without runs.
  double? nextStart(double h) {
    final starts = [
      for (final s in spans)
        if (!s.carried) s.start,
    ];
    if (starts.isEmpty) return null;
    final x = wrap(h);
    for (final s in starts) {
      if (s > x + 1e-6) return s;
    }
    return starts.first;
  }

  /// The times at which what runs changes, sorted, in [0, hours).
  List<double> get changes {
    final out = <double>{0};
    for (final s in spans) {
      out.add(s.start);
      if (s.end < hours - 1e-9) out.add(s.end);
    }
    return out.toList()..sort();
  }

  /// Whether two runs ever go on at the same time.
  bool get overlaps {
    for (var i = 0; i < spans.length; i++) {
      for (var j = i + 1; j < spans.length; j++) {
        final a = spans[i], b = spans[j];
        if (a.start < b.end - 1e-9 && b.start < a.end - 1e-9) return true;
      }
    }
    return false;
  }

  /// "06:30" or, on a cycle of several days, "{day} 06:30" with the day
  /// written by [dayLabel] (1 = the first).
  String clockAt(double h, {String Function(int day)? dayLabel}) {
    final x = wrap(h);
    final day = (x / 24).floor();
    final (hhmm, carry) = clockTime(x - 24 * day);
    if (days <= 1) return hhmm;
    final d = (day + carry) % days;
    return '${dayLabel?.call(d + 1) ?? 'D${d + 1}'} $hhmm';
  }
}

/// The time line of [prog] for [days] days from [startDate] (the runs of
/// later days are left out), the programme repeating every [periodDays].
ProgrammeTimeline programmeTimeline(IrrigationProgramme prog, {required DateTime startDate, required int days, int? periodDays}) {
  final day0 = DateTime(startDate.year, startDate.month, startDate.day);
  final n = math.max(1, days);
  final hours = n * 24.0;
  final runs = <ProgrammeRun>[];
  final spans = <PlaybackSpan>[];
  for (final r in prog.runs) {
    final d = DateTime(r.day.year, r.day.month, r.day.day).difference(day0).inHours;
    final index = (d / 24).round();
    if (index < 0 || index >= n || !(r.durationHours > 0)) continue;
    runs.add(r);
    final dur = math.min(r.durationHours, hours);
    var s = (index * 24 + r.startHour) % hours;
    if (s < 0) s += hours;
    final e = s + dur;
    if (e <= hours + 1e-9) {
      spans.add(PlaybackSpan(run: r, dayIndex: index, start: s, end: math.min(e, hours)));
    } else {
      spans.add(PlaybackSpan(run: r, dayIndex: index, start: s, end: hours));
      spans.add(PlaybackSpan(run: r, dayIndex: index, start: 0, end: e - hours, carried: true));
    }
  }
  spans.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : a.end.compareTo(b.end));
  return ProgrammeTimeline(programme: prog, startDate: day0, days: n, periodDays: periodDays ?? n, runs: runs, spans: spans);
}

/// The time line of the programme of [p] (the design month of every area,
/// or [month]) from [startDate] (today): one period of it, at most
/// [playbackMaxDays] days.
ProgrammeTimeline buildProgrammeTimeline(Project p, DesignResults? results, {DateTime? startDate, int? month}) {
  final s = startDate ?? DateTime.now();
  final day0 = DateTime(s.year, s.month, s.day);
  final intervals = buildControllerProgram(p, results, startDate: day0, days: 1, month: month).intervalDays;
  final period = programmePeriodDays(intervals.values);
  final days = math.min(period, playbackMaxDays);
  final prog = buildIrrigationProgramme(p, results, startDate: day0, days: days, month: month, withStations: false);
  return programmeTimeline(prog, startDate: day0, days: days, periodDays: period);
}

// ---------------------------------------------------------------- what a group shows

/// An emitter or sprinkler that waters while its group runs: a lumped group
/// of [count] emitters of a drip line at [p], or a sprinkler with the
/// wetted [radius] (m) of its pressure over its arc.
class WetPoint {
  const WetPoint({required this.p, this.count = 1, this.radius = 0, this.arcDeg = 360, this.orientationDeg = 0});
  final Pt p;
  final int count;
  final double radius, arcDeg, orientationDeg;
}

/// A pipe segment carrying water while its group runs.
class PipeFlow {
  const PipeFlow({required this.a, required this.b, required this.flow, required this.velocity, required this.maxVelocity, this.mainline = false});
  final Pt a, b;

  /// Flow (m³/s, its size) and velocity (m/s); the largest velocity the
  /// design allows on it (m/s).
  final double flow, velocity, maxVelocity;
  final bool mainline;
}

/// What one system flow (group of zones) shows while it runs, from the
/// design results.
class FlowView {
  const FlowView({
    required this.flowId,
    required this.name,
    required this.demands,
    required this.areas,
    required this.machines,
    required this.wet,
    required this.pipes,
    required this.pumps,
    required this.totalFlow,
    required this.supplies,
    required this.bounds,
    this.pumpHeads = const {},
    this.solved = true,
  });
  final String flowId, name;

  /// Zone valves, valve-in-head stations and machines of the group.
  final List<String> demands;
  final List<AreaEntity> areas;
  final List<PivotEntity> machines;
  final List<WetPoint> wet;
  final List<PipeFlow> pipes;

  /// Pumps that run in the group, and the pressure head at the outlet of
  /// each (m).
  final Set<String> pumps;
  final Map<String, double> pumpHeads;

  /// Flow of the group (m³/s) and the duty of its supplies.
  final double totalFlow;
  final List<SupplyDuty> supplies;
  final Bounds bounds;

  /// The design results hold this group (false: the areas alone, no
  /// hydraulics).
  final bool solved;
}

/// The members of system flow [flowId] of [p] ('auto': every zone valve and
/// valve-in-head station, as the programme takes them without flows).
Set<String> flowMembers(Project p, String flowId, {VihStations? vih}) {
  for (final f in p.systemFlows) {
    if (f.id == flowId) return f.valveIds;
  }
  if (flowId != 'auto') return const {};
  final st = vih ?? VihStations.of(p);
  return {...p.entities.whereType<ControlValveEntity>().map((v) => v.id), ...st.heads.keys};
}

/// The wetted radius (m) and arc of the sprinkler [o] at [head] (m), from
/// its catalogue nozzle (0 without one).
(double, double) _throw(Project p, OutletEntity o, double head) {
  final nz = p.catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
  if (nz == null) return (0, 360);
  final h = head > 0 ? head : o.headM;
  return (math.max(0, nz.curve.radius(h)).toDouble(), nz.effectiveArcDeg(o.arcDeg));
}

/// What system flow [flowId] ([name]) of [p] shows while it runs, from
/// [results].
FlowView flowView(Project p, DesignResults results, String flowId, String name, {VihStations? vih}) {
  final st = vih ?? VihStations.of(p);
  final members = flowMembers(p, flowId, vih: st);
  final sf = results.systemFlows.where((f) => f.flowId == flowId).firstOrNull;
  final params = p.params;
  final areas = areasOfFlow(p, results, members, vih: st);
  final machines = <PivotEntity>[];
  final wet = <WetPoint>[];
  final pipes = <PipeFlow>[];
  final pumps = <String>{};
  final pumpHeads = <String, double>{};
  var b = Bounds.empty;
  bool isPump(String id) => p.byId(id) is PumpEntity;
  void device(DeviceResult d) {
    if (!(d.flow.abs() > 1e-7) || d.status == 'closed' || !isPump(d.entityId)) return;
    pumps.add(d.entityId);
    pumpHeads[d.entityId] = math.max(pumpHeads[d.entityId] ?? -double.infinity, d.downstreamPressure);
  }

  for (final id in members) {
    final e = p.byId(id);
    if (e is PivotEntity) {
      machines.add(e);
      b = b.union(Bounds.ofPoints(e.outline()));
      continue;
    }
    final z = results.zones[id];
    if (z == null) continue;
    for (final s in z.pipes) {
      if (!(s.flow.abs() > 1e-9)) continue;
      pipes.add(PipeFlow(a: s.a, b: s.b, flow: s.flow.abs(), velocity: s.velocity.abs(), maxVelocity: params.maxZoneVelocity));
      b = b.include(s.a).include(s.b);
    }
    for (final o in z.outlets) {
      final head = p.byId(o.entityId);
      if (head is OutletEntity) {
        final (r, arc) = _throw(p, head, o.pressure);
        wet.add(WetPoint(p: o.p, count: o.count, radius: r, arcDeg: arc, orientationDeg: head.orientationDeg));
      } else {
        wet.add(WetPoint(p: o.p, count: o.count));
      }
      b = b.include(o.p);
    }
    z.devices.forEach(device);
  }
  // valve-in-head stations: their heads on the mainline
  for (final s in st.runningIn(members)) {
    for (final hid in st.heads[s] ?? const <String>[]) {
      final h = p.byId(hid);
      if (h is! OutletEntity) continue;
      final (r, arc) = _throw(p, h, h.headM);
      wet.add(WetPoint(p: h.position, radius: r, arcDeg: arc, orientationDeg: h.orientationDeg));
      b = b.include(h.position);
    }
  }
  if (sf != null) {
    for (final s in sf.pipes) {
      if (!(s.flow.abs() > 1e-9)) continue;
      pipes.add(PipeFlow(a: s.a, b: s.b, flow: s.flow.abs(), velocity: s.velocity.abs(), maxVelocity: params.maxMainlineVelocity, mainline: true));
      b = b.include(s.a).include(s.b);
    }
    sf.devices.forEach(device);
    for (final s in sf.stations) {
      if (s.running > 0 && s.flow > 1e-7) pumps.add(s.entityId);
    }
  }
  for (final a in areas) {
    b = b.union(Bounds.ofPoints(a.points));
  }
  return FlowView(
    flowId: flowId,
    name: name,
    demands: [...members],
    areas: areas,
    machines: machines,
    wet: wet,
    pipes: pipes,
    pumps: pumps,
    pumpHeads: pumpHeads,
    totalFlow: sf?.totalFlow ?? 0,
    supplies: sf?.supplies ?? const [],
    bounds: b,
    solved: sf != null,
  );
}

// ---------------------------------------------------------------- reservoirs

/// The level of the reservoir of one supply along the cycle.
class ReservoirTrace {
  ReservoirTrace({required this.supplyId, required this.study, required this.times, required this.volumes, required this.dry, required this.spills});
  final String supplyId;
  final ReservoirStudy study;

  /// Breakpoints (hours from the start of the cycle) and the volume then
  /// (m³); the volume goes straight between them.
  final List<double> times, volumes;

  /// The level reached the lowest operating level (the intake ran dry) or
  /// the full level (the water spilled) at some time of the cycle.
  final bool dry, spills;

  /// Volume (m³) at [h] (hours from the start of the cycle).
  double volumeAt(double h) {
    if (times.isEmpty) return 0;
    if (h <= times.first) return volumes.first;
    for (var i = 1; i < times.length; i++) {
      if (h <= times[i]) {
        final t0 = times[i - 1], t1 = times[i];
        final f = t1 > t0 ? (h - t0) / (t1 - t0) : 1.0;
        return volumes[i - 1] + f * (volumes[i] - volumes[i - 1]);
      }
    }
    return volumes.last;
  }

  /// Water level (m, elevation) at [h].
  double levelAt(double h) => reservoirLevelOf(study, volumeAt(h));

  /// Change of the volume over the cycle (m³; negative: it empties).
  double get netChange => volumes.isEmpty ? 0 : volumes.last - volumes.first;
}

/// The level (m) that holds [volume] (m³) in [study]: the stage–volume
/// curve read the other way (straight between its stages).
double reservoirLevelOf(ReservoirStudy study, double volume) {
  final c = study.curve;
  if (c.isEmpty) return study.fullLevel;
  if (volume <= c.first.volume) return c.first.level;
  for (var i = 1; i < c.length; i++) {
    if (volume <= c[i].volume) {
      final a = c[i - 1], b = c[i];
      final f = b.volume > a.volume ? (volume - a.volume) / (b.volume - a.volume) : 1.0;
      return a.level + f * (b.level - a.level);
    }
  }
  final last = c.last;
  return last.area > 0 ? last.level + (volume - last.volume) / last.area : last.level;
}

/// The level of [study] along [tl]: the volume at the start of the cycle
/// that of its initial level, then the inflow less what the running groups
/// draw from supply [study.supplyId] ([drawOf]: m³/s of each flow id),
/// between the lowest operating level and the full level.
ReservoirTrace reservoirTrace(ReservoirStudy study, ProgrammeTimeline tl, double Function(String flowId) drawOf) {
  final vMin = study.volumeAt(study.minLevel), vMax = study.volume;
  var v = study.volumeAt(study.initialLevel).clamp(math.min(vMin, vMax), vMax).toDouble();
  final times = <double>[0], volumes = <double>[v];
  var dry = false, spills = false;
  final cuts = [...tl.changes, tl.hours];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final t0 = cuts[i], t1 = cuts[i + 1];
    if (t1 - t0 < 1e-9) continue;
    final mid = (t0 + t1) / 2;
    final out = {for (final s in tl.runningAt(mid)) s.flowId}.fold(0.0, (q, f) => q + drawOf(f));
    final rate = (study.inflow - out) * 3600; // m³ per hour
    var t = t0;
    if (rate < 0) {
      // drawn down: dry once it reaches the intake
      final hit = v <= vMin + 1e-9 ? t0 : t0 + (v - vMin) / -rate;
      if (hit < t1 - 1e-9) {
        if (hit > t0) {
          times.add(hit);
          volumes.add(vMin);
        }
        v = vMin;
        t = hit;
        dry = true;
      }
    } else if (rate > 0) {
      // filled by the inflow: it spills once full
      final hit = v >= vMax - 1e-9 ? t0 : t0 + (vMax - v) / rate;
      if (hit < t1 - 1e-9) {
        if (hit > t0) {
          times.add(hit);
          volumes.add(vMax);
        }
        v = vMax;
        t = hit;
        spills = true;
      }
    }
    v = (v + rate * (t1 - t)).clamp(math.min(vMin, vMax), vMax).toDouble();
    times.add(t1);
    volumes.add(v);
  }
  return ReservoirTrace(supplyId: study.supplyId, study: study, times: times, volumes: volumes, dry: dry, spills: spills);
}

// ---------------------------------------------------------------- the player

/// A pump of the drawing.
class PumpMark {
  const PumpMark({required this.id, required this.name, required this.p});
  final String id, name;
  final Pt p;
}

/// The duty of one supply at a moment.
class SupplyState {
  const SupplyState({required this.id, required this.name, required this.head, required this.flow});
  final String id, name;

  /// Pressure head available at the supply (m) and the flow it gives (m³/s).
  final double head, flow;
}

/// The system at one moment of the cycle.
class PlaybackFrame {
  const PlaybackFrame({
    required this.hour,
    required this.running,
    required this.flows,
    required this.totalFlow,
    required this.supplies,
    required this.pumpsOn,
    required this.levels,
    required this.overlap,
    this.pumpHeads = const {},
  });

  /// Hours from the start of the cycle.
  final double hour;
  final List<PlaybackSpan> running;

  /// What the running groups show (one per group).
  final List<FlowView> flows;

  /// Flow delivered (m³/s).
  final double totalFlow;
  final List<SupplyState> supplies;
  final Set<String> pumpsOn;

  /// Pressure head (m) at the outlet of every pump on.
  final Map<String, double> pumpHeads;

  /// Level (m) of the reservoir of every supply that has one.
  final Map<String, double> levels;

  /// Two groups run at the same time (see the library notes).
  final bool overlap;

  bool get idle => running.isEmpty;
  int get day => (hour / 24).floor();
}

/// The programme ready to play: the time line, what every group shows,
/// the pumps and the reservoirs.
class ProgrammePlayback {
  ProgrammePlayback({required this.timeline, required this.flows, required this.pumps, required this.reservoirs, required this.results});
  final ProgrammeTimeline timeline;
  final Map<String, FlowView> flows;
  final List<PumpMark> pumps;
  final List<ReservoirTrace> reservoirs;

  /// The results it was built from (the player follows the design).
  final DesignResults results;

  /// The area every group shows.
  Bounds get bounds => flows.values.fold(Bounds.empty, (b, f) => b.union(f.bounds));

  /// The state of the system at [hour] (taken into the cycle).
  PlaybackFrame frameAt(double hour) {
    final h = timeline.wrap(hour);
    final running = timeline.runningAt(h);
    final views = <String, FlowView>{};
    for (final s in running) {
      final v = flows[s.flowId];
      if (v != null) views.putIfAbsent(s.flowId, () => v);
    }
    final supplies = <String, SupplyState>{};
    final pumpsOn = <String>{};
    final pumpHeads = <String, double>{};
    var q = 0.0;
    for (final v in views.values) {
      q += v.totalFlow;
      pumpsOn.addAll(v.pumps);
      for (final e in v.pumpHeads.entries) {
        pumpHeads[e.key] = math.max(pumpHeads[e.key] ?? -double.infinity, e.value);
      }
      for (final d in v.supplies) {
        final was = supplies[d.supplyId];
        supplies[d.supplyId] = SupplyState(id: d.supplyId, name: d.name, head: was == null ? d.head : math.max(was.head, d.head), flow: (was?.flow ?? 0) + d.flow);
      }
    }
    return PlaybackFrame(
      hour: h,
      running: running,
      flows: views.values.toList(),
      totalFlow: q,
      supplies: supplies.values.toList(),
      pumpsOn: pumpsOn,
      pumpHeads: pumpHeads,
      levels: {for (final r in reservoirs) r.supplyId: r.levelAt(h)},
      overlap: views.length > 1,
    );
  }

  /// The programme of [p] played with [results] (see
  /// [buildProgrammeTimeline]); [withReservoirs] studies the reservoir of
  /// every supply that has one (a grid over its basin).
  static ProgrammePlayback build(Project p, DesignResults results, {DateTime? startDate, int? month, bool withReservoirs = true}) {
    final tl = buildProgrammeTimeline(p, results, startDate: startDate, month: month);
    return of(p, results, tl, withReservoirs: withReservoirs);
  }

  /// [tl] played with [results].
  static ProgrammePlayback of(Project p, DesignResults results, ProgrammeTimeline tl, {bool withReservoirs = true}) {
    final vih = VihStations.of(p);
    final flows = <String, FlowView>{};
    for (final s in tl.spans) {
      flows.putIfAbsent(s.flowId, () => flowView(p, results, s.flowId, s.run.flowName, vih: vih));
    }
    final pumps = [
      for (final e in p.entities)
        if (e is PumpEntity) PumpMark(id: e.id, name: e.name.isNotEmpty ? e.name : e.id, p: e.position),
    ];
    final traces = <ReservoirTrace>[];
    if (withReservoirs && !tl.isEmpty) {
      for (final s in p.entities.whereType<WaterSupplyEntity>()) {
        if (s.reservoir == null) continue;
        final study = reservoirStudy(p, s, results: results);
        if (study == null || study.curve.isEmpty) continue;
        double draw(String flowId) => (flows[flowId]?.supplies ?? const <SupplyDuty>[]).where((d) => d.supplyId == s.id).fold(0.0, (q, d) => q + math.max(0.0, d.flow));
        traces.add(reservoirTrace(study, tl, draw));
      }
    }
    return ProgrammePlayback(timeline: tl, flows: flows, pumps: pumps, reservoirs: traces, results: results);
  }
}

/// The times of the frames of an animation of [tl] in [count] steps: one
/// every hours/count from the start, and the middle of every run no step
/// falls in (a short cycle of cycle and soak is not skipped), sorted.
List<double> playbackFrameTimes(ProgrammeTimeline tl, int count) {
  final n = math.max(1, count);
  final step = tl.hours / n;
  final times = [for (var k = 0; k < n; k++) k * step];
  final extra = <double>[];
  for (final s in tl.spans) {
    if (!times.any(s.contains) && !extra.any(s.contains)) extra.add((s.start + s.end) / 2);
  }
  return [...times, ...extra]..sort();
}

/// Frames of an animation of a cycle of [days] days that keep the file
/// small: every half hour of a day, every two hours of a week (24 to 96).
int playbackDefaultFrames(int days) => days <= 1 ? 48 : (days * 12).clamp(24, 96);
