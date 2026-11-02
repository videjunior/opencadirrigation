/// Agronomic management: crop water requirement, soil water balance
/// (readily available water, irrigation interval), irrigation time per
/// event and a calendar / controller programme for the system flows. The
/// depths come from area_water.dart, the rule the water table and the
/// FAO-56 requirement table share (ETc,loc = Kr·Kc·ETo for localized
/// irrigation, the wetted fraction only in the readily available water).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'area_water.dart';
import 'designer.dart';
import 'results.dart';
import 'valve_in_head.dart';

/// Typical single crop coefficients (FAO-56 mid-season values) offered in
/// the area properties. Keys are i18n keys (`crop.*`).
const cropKcTable = <String, (double, double, double)>{
  'crop.citrus': (0.70, 0.65, 0.70),
  'crop.grape': (0.30, 0.70, 0.45),
  'crop.coffee': (0.90, 0.95, 0.95),
  'crop.banana': (0.50, 1.10, 1.00),
  'crop.mango': (0.60, 0.85, 0.80),
  'crop.apple': (0.45, 0.95, 0.70),
  'crop.tomato': (0.60, 1.15, 0.80),
  'crop.maize': (0.30, 1.20, 0.60),
  'crop.sugarcane': (0.40, 1.25, 0.75),
  'crop.vegetables': (0.70, 1.05, 0.95),
  'crop.turf': (0.80, 0.85, 0.85),
  'crop.pasture': (0.40, 0.90, 0.85),
};

class CropWaterResult {
  const CropWaterResult({
    required this.areaId,
    required this.name,
    required this.etcMmDay,
    required this.rawMm,
    required this.intervalDays,
    required this.netDepthMm,
    required this.grossDepthMm,
    required this.applicationRateMmH,
    required this.hoursPerEvent,
    required this.volumePerEventM3,
    required this.dailyHours,
    this.kr = 1,
    this.wettedFraction = 1,
    this.localized = false,
    this.machine = false,
    this.month,
    this.source = AreaWaterSource.balance,
    this.warnings = const [],
  });
  final String areaId;
  final String name;

  /// Crop evapotranspiration over the whole area, ETc,loc = Kr·Kc·ETo
  /// (mm/day; the typed net depth without the water balance).
  final double etcMmDay;

  /// Readily available water p·TAW·Pw (mm).
  final double rawMm;

  /// Days between irrigations (RAW / ETc,loc, at least 1; 1 for an area a
  /// machine waters, which passes every day).
  final double intervalDays;

  /// Net and gross depth per event (mm).
  final double netDepthMm;
  final double grossDepthMm;
  final double applicationRateMmH;
  final double hoursPerEvent;
  final double volumePerEventM3;

  /// Average daily run time (hours per event / interval).
  final double dailyHours;

  /// Localized reduction factor and wetted fraction used.
  final double kr;
  final double wettedFraction;
  final bool localized;

  /// Watered by a centre pivot or linear move: the event is the day.
  final bool machine;

  /// Month (1–12) of the crop table row used (null without a crop of the table).
  final int? month;
  final AreaWaterSource source;

  /// Message codes of the crop table row (`req_*`).
  final List<String> warnings;
}

/// Crop water requirement and irrigation timing for every area, in the
/// design period or in [month] (1–12).
List<CropWaterResult> cropWaterRequirements(Project project, DesignResults? results, {int? month}) {
  final reqs = {for (final r in areaRequirements(project, results)) r.areaId: r};
  final out = <CropWaterResult>[];
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    final req = reqs[a.id];
    final rate = req?.precipitationMmH ?? 0;
    final b = areaWaterBasis(project, a, month: month);
    // a machine passes continuously: its area gets the daily need every day
    // and the run time is hours per day
    final machine = req != null && req.flow > 0 && req.machineFlow >= 0.5 * req.flow;
    final interval = machine ? 1 : b.intervalDays;
    final net = b.netMmDay * interval;
    final gross = b.grossMmDay * interval;
    final hours = rate > 0 ? gross / rate : 0.0;
    out.add(
      CropWaterResult(
        areaId: a.id,
        name: a.name.isEmpty ? a.id : a.name,
        etcMmDay: b.etcMmDay,
        rawMm: b.rawMm,
        intervalDays: interval.toDouble(),
        netDepthMm: net,
        grossDepthMm: gross,
        applicationRateMmH: rate,
        hoursPerEvent: hours,
        volumePerEventM3: gross / 1000 * a.area,
        dailyHours: hours / interval,
        kr: b.kr,
        wettedFraction: b.pw,
        localized: b.localized,
        machine: machine,
        month: b.month,
        source: b.source,
        warnings: b.warnings,
      ),
    );
  }
  return out;
}

class ScheduleEntry {
  const ScheduleEntry({required this.day, required this.flowId, required this.flowName, required this.startHour, required this.durationHours, required this.zones, required this.flow});
  final DateTime day;
  final String flowId;
  final String flowName;
  final double startHour;
  final double durationHours;
  final List<String> zones;

  /// Total flow of the system flow (m³/s), when results are available.
  final double flow;
  double get endHour => startHour + durationHours;
}

class ControllerProgram {
  ControllerProgram({required this.perFlowHours, required this.entries, required this.warnings, this.intervalDays = const {}, this.month});

  /// Required run time per system flow per irrigation day (hours), from the
  /// areas irrigated by its zones.
  final Map<String, double> perFlowHours;

  /// Days between the irrigations of every system flow.
  final Map<String, int> intervalDays;
  final List<ScheduleEntry> entries;
  final List<String> warnings;

  /// Month (1–12) the programme was built for (null: the design month of
  /// every area).
  final int? month;

  /// Hours of pumping on the busiest day.
  double get maxDailyHours {
    final byDay = <String, double>{};
    for (final e in entries) {
      final k = e.day.toIso8601String();
      byDay[k] = (byDay[k] ?? 0) + e.durationHours;
    }
    return byDay.values.fold(0.0, math.max);
  }
}

/// Areas that hold at least a fifth of the emitters of the zone of [valveId]
/// (by emitter count, so a zone shared by a few beds belongs to each of them
/// and an area it only grazes is left out; heads on an area's outline count
/// when their arc opens into it).
List<AreaEntity> areasOfZone(Project project, DesignResults results, String valveId) {
  final z = results.zones[valveId];
  if (z == null || z.outlets.isEmpty) return const [];
  final heads = {
    for (final e in project.entities)
      if (e is OutletEntity) e.id: e,
  };
  final total = z.outlets.fold(0, (s, o) => s + o.count);
  final out = <AreaEntity>[];
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    var inside = 0;
    for (final o in z.outlets) {
      final head = heads[o.entityId];
      if (head != null ? project.outletWatersArea(head, a.points) : watersArea(o.p, a.points)) inside += o.count;
    }
    if (inside * 5 >= total) out.add(a);
  }
  return out;
}

/// Areas that hold at least a fifth of the heads of the valve-in-head
/// station [stationId] (`valve_in_head.dart`), as [areasOfZone] counts the
/// emitters of a zone.
List<AreaEntity> areasOfStation(Project project, String stationId, {VihStations? stations}) {
  final ids = (stations ?? VihStations.of(project)).heads[stationId];
  if (ids == null || ids.isEmpty) return const [];
  final heads = [
    for (final e in project.entities)
      if (e is OutletEntity && ids.contains(e.id)) e,
  ];
  return [
    for (final a in project.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && heads.where((h) => project.outletWatersArea(h, a.points)).length * 5 >= heads.length) a,
  ];
}

/// Areas that hold at least a fifth of the ground the centre pivot or
/// linear move [machine] waters.
List<AreaEntity> areasOfMachine(Project project, PivotEntity machine) {
  final outline = machine.outline();
  return [
    for (final a in project.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && _shareInside(outline, a.points) >= 0.2) a,
  ];
}

/// Share of the polygon [src] that lies inside [area], sampled on a 40 × 40
/// grid over [src].
double _shareInside(List<Pt> src, List<Pt> area) {
  final b = Bounds.ofPoints(src);
  const n = 40;
  var inSrc = 0, inBoth = 0;
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final p = Pt(b.minX + (i + 0.5) * b.width / n, b.minY + (j + 0.5) * b.height / n);
      if (!pointInPolygon(p, src)) continue;
      inSrc++;
      if (pointInPolygon(p, area)) inBoth++;
    }
  }
  return inSrc == 0 ? 0 : inBoth / inSrc;
}

/// An area of a system flow gets more than this many times the water it
/// needs when the flow runs for the area that needs the most.
const unevenAreasRatio = 1.3;

/// Builds the controller programme for the design month of every area, or
/// for [month] (1–12). Each system flow runs every few days: the shortest
/// interval of the areas its zones, valve-in-head stations and machines
/// water (a machine runs every day), for the longest run time those areas
/// need in that interval (the daily run time of each times the interval),
/// so that no area goes longer than its readily available water allows;
/// an area that then gets far more than it needs is reported
/// (`schedule_uneven_areas`). Flows start at [startDate] for [days] days
/// (flows that run every few days start on staggered days so that they do
/// not pile up), one after another from [dayStartHour], or at their own
/// start hour when [keepStartHours]. Without system flows every zone and
/// station runs together.
ControllerProgram buildControllerProgram(Project project, DesignResults? results, {DateTime? startDate, int days = 14, double dayStartHour = 6, bool keepStartHours = false, int? month}) {
  final warnings = <String>[];
  final crops = {for (final c in cropWaterRequirements(project, results, month: month)) c.areaId: c};
  final vih = VihStations.of(project);
  // flows without any zone have nothing to water (an empty project gets no
  // automatic flow either)
  final all = project.systemFlows.isNotEmpty
      ? project.systemFlows
      : [
          SystemFlow(id: 'auto', name: 'all', valveIds: {...project.entities.whereType<ControlValveEntity>().map((v) => v.id), ...vih.heads.keys}),
        ];
  final flows = [
    for (final f in all)
      if (f.valveIds.isNotEmpty) f,
  ];
  final perFlow = <String, double>{};
  final intervalOf = <String, int>{};
  final zoneNames = <String, List<String>>{};
  for (final f in flows) {
    final names = <String>[];
    final watered = <String, CropWaterResult>{};
    var machines = false;
    for (final vid in f.valveIds) {
      final station = vih.isStation(vid);
      final e = station ? null : project.byId(vid);
      if (e is ControlValveEntity) names.add(e.zoneName);
      if (e is PivotEntity) names.add(e.name.isNotEmpty ? e.name : (e.zoneName.isNotEmpty ? e.zoneName : e.id));
      if (station) names.add(vih.nameOf(vid));
      if (results == null) continue;
      final List<AreaEntity> areas;
      if (station) {
        areas = areasOfStation(project, vid, stations: vih);
      } else if (e is PivotEntity) {
        areas = areasOfMachine(project, e);
        if (areas.isNotEmpty) machines = true;
      } else {
        areas = areasOfZone(project, results, vid);
      }
      for (final a in areas) {
        final c = crops[a.id];
        if (c != null) watered[a.id] = c;
      }
    }
    var hours = 0.0;
    var interval = 1;
    if (watered.isEmpty) {
      hours = f.durationHours;
      if (results != null && f.valveIds.isNotEmpty) warnings.add('schedule_no_area:${f.id}');
    } else {
      interval = machines ? 1 : watered.values.map((c) => c.intervalDays.round()).fold(1 << 30, math.min);
      interval = math.max(1, interval);
      hours = watered.values.fold(0.0, (m, c) => math.max(m, c.dailyHours * interval));
      // the areas of one flow open and close together: one that needs much
      // less water than the others gets the surplus (deep percolation)
      final needs = [
        for (final c in watered.values)
          if (c.applicationRateMmH > 0 && c.dailyHours > 0) c.dailyHours,
      ];
      if (needs.length > 1 && needs.reduce(math.max) > unevenAreasRatio * needs.reduce(math.min)) warnings.add('schedule_uneven_areas:${f.id}');
    }
    perFlow[f.id] = hours;
    intervalOf[f.id] = interval;
    zoneNames[f.id] = names;
  }
  // A flow that runs every few days starts on the day that keeps the busiest
  // of its days lightest: all of them on the first day would stack up (two
  // 20-hour events on one day although the next days are free).
  final load = List<double>.filled(math.max(days, 0), 0);
  final offset = <String, int>{};
  for (final f in flows) {
    final interval = math.max(1, intervalOf[f.id]!);
    final dur = math.max(perFlow[f.id]!, 0.0);
    var best = 0;
    var bestPeak = double.infinity;
    for (var o = 0; o < math.min(interval, days); o++) {
      var peak = 0.0;
      for (var d = o; d < days; d += interval) {
        peak = math.max(peak, load[d] + dur);
      }
      if (peak < bestPeak - 1e-9) {
        bestPeak = peak;
        best = o;
      }
    }
    offset[f.id] = best;
    for (var d = best; d < days; d += interval) {
      load[d] += dur;
    }
  }
  final entries = <ScheduleEntry>[];
  final start = startDate ?? DateTime.now();
  final day0 = DateTime(start.year, start.month, start.day);
  for (var d = 0; d < days; d++) {
    final day = day0.add(Duration(days: d));
    var cursor = dayStartHour;
    for (final f in flows) {
      final interval = intervalOf[f.id]!;
      if (interval > 1 && (d - offset[f.id]!) % interval != 0) continue;
      final dur = perFlow[f.id]!;
      if (dur <= 0) continue;
      final startH = keepStartHours ? f.startHour : cursor;
      final q = results?.systemFlows.where((r) => r.flowId == f.id).firstOrNull?.totalFlow ?? 0;
      entries.add(ScheduleEntry(day: day, flowId: f.id, flowName: f.name, startHour: startH, durationHours: dur, zones: zoneNames[f.id]!, flow: q));
      if (!keepStartHours) cursor += dur;
    }
    if (cursor - dayStartHour > 24 + 1e-9) warnings.add('schedule_over_24h:${day.toIso8601String().substring(0, 10)}');
  }
  return ControllerProgram(perFlowHours: perFlow, intervalDays: intervalOf, entries: entries, warnings: warnings.toSet().toList(), month: month);
}

/// Clock time of [hours] after the midnight that starts the event's day:
/// `HH:MM`, rounded to the minute before hours and minutes are split (so
/// 1.9999 h after 06:00 is 08:00, not 07:60), and the days it runs into
/// (1 for an end after midnight).
(String, int) clockTime(double hours) {
  final minutes = (hours * 60).round();
  final dayMinutes = minutes % (24 * 60);
  final hh = dayMinutes ~/ 60, mm = dayMinutes % 60;
  return ('${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}', minutes ~/ (24 * 60));
}

/// [clockTime] as text, with "+n d" (translated as `sch.plusDays`) when the
/// time falls on a later day.
String clockText(double hours, {String Function(String key)? t}) {
  final (hhmm, days) = clockTime(hours);
  if (days <= 0) return hhmm;
  final suffix = t == null ? '+{n} d' : t('sch.plusDays');
  return '$hhmm ${suffix.replaceAll('{n}', '$days')}';
}

/// CSV export of a controller programme (one line per event).
String controllerProgramCsv(ControllerProgram p, {String Function(String key)? t}) {
  String tr(String k) => t?.call(k) ?? k;
  final b = StringBuffer('﻿');
  b.writeln([tr('sch.date'), tr('sch.flow'), tr('sch.zones'), tr('sch.start'), tr('sch.end'), tr('sch.duration')].join(';'));
  for (final e in p.entries) {
    b.writeln([e.day.toIso8601String().substring(0, 10), e.flowName, e.zones.join(' + '), clockText(e.startHour, t: t), clockText(e.endHour, t: t), e.durationHours.toStringAsFixed(2)].join(';'));
  }
  return b.toString();
}
