/// Agronomic management: crop water requirement (ETo·Kc), soil water
/// balance (readily available water, irrigation interval), irrigation time
/// per event and a calendar / controller programme for the system flows.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/project.dart';
import 'designer.dart';
import 'results.dart';

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
  });
  final String areaId;
  final String name;

  /// Crop evapotranspiration ETo·Kc (mm/day).
  final double etcMmDay;

  /// Readily available water AWC·Zr·MAD (mm).
  final double rawMm;

  /// Days between irrigations (RAW / ETc, at least 1 when RAW > ETc).
  final double intervalDays;

  /// Net and gross depth per event (mm).
  final double netDepthMm;
  final double grossDepthMm;
  final double applicationRateMmH;
  final double hoursPerEvent;
  final double volumePerEventM3;

  /// Average daily run time (hours per event / interval).
  final double dailyHours;
}

/// Crop water requirement and irrigation timing for every area.
List<CropWaterResult> cropWaterRequirements(Project project, DesignResults? results) {
  final reqs = {for (final r in areaRequirements(project, results)) r.areaId: r};
  final out = <CropWaterResult>[];
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    final req = reqs[a.id];
    final rate = req?.precipitationMmH ?? 0;
    final etc = a.useWaterBalance ? a.etcMmDay : a.netDepthMmPerDay;
    final raw = a.useWaterBalance ? a.awcMmPerM * a.rootDepthM * a.mad.clamp(0.05, 0.95) : etc;
    double interval;
    if (!a.useWaterBalance || etc <= 0) {
      interval = 1;
    } else {
      interval = math.max(1, (raw / etc).floorToDouble());
    }
    final net = etc * interval;
    final gross = net / math.max(a.efficiency, 0.05);
    final hours = rate > 0 ? gross * a.wettedFraction.clamp(0.05, 1.0) / rate : 0.0;
    final volume = gross / 1000 * a.area * a.wettedFraction.clamp(0.05, 1.0);
    out.add(CropWaterResult(
      areaId: a.id,
      name: a.name.isEmpty ? a.id : a.name,
      etcMmDay: etc,
      rawMm: raw,
      intervalDays: interval,
      netDepthMm: net,
      grossDepthMm: gross,
      applicationRateMmH: rate,
      hoursPerEvent: hours,
      volumePerEventM3: volume,
      dailyHours: interval > 0 ? hours / interval : hours,
    ));
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
  ControllerProgram({required this.perFlowHours, required this.entries, required this.warnings});

  /// Required run time per system flow per irrigation day (hours), from the
  /// areas irrigated by its zones.
  final Map<String, double> perFlowHours;
  final List<ScheduleEntry> entries;
  final List<String> warnings;

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

/// Areas whose polygon contains the outlets/laterals of the zone of [valveId].
List<AreaEntity> areasOfZone(Project project, DesignResults results, String valveId) {
  final z = results.zones[valveId];
  if (z == null || z.outlets.isEmpty) return const [];
  final out = <AreaEntity>[];
  for (final a in project.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    var inside = 0;
    for (final o in z.outlets) {
      if (pointInPolygonSafe(o.p, a.points)) inside++;
    }
    if (inside * 2 >= z.outlets.length) out.add(a);
  }
  return out;
}

/// Builds the controller programme: each system flow runs for the longest
/// event time of the areas its zones irrigate, every interval days, starting
/// at [startDate] for [days] days. Flows run one after another from
/// [dayStartHour], or at their own start hour when [keepStartHours].
ControllerProgram buildControllerProgram(Project project, DesignResults? results, {DateTime? startDate, int days = 14, double dayStartHour = 6, bool keepStartHours = false}) {
  final warnings = <String>[];
  final crops = {for (final c in cropWaterRequirements(project, results)) c.areaId: c};
  final flows = project.systemFlows.isNotEmpty ? project.systemFlows : [SystemFlow(id: 'auto', name: 'all', valveIds: project.entities.whereType<ControlValveEntity>().map((v) => v.id).toSet())];
  final perFlow = <String, double>{};
  final intervalOf = <String, double>{};
  final zoneNames = <String, List<String>>{};
  for (final f in flows) {
    var hours = 0.0;
    var interval = 1.0;
    var any = false;
    final names = <String>[];
    for (final vid in f.valveIds) {
      final v = project.byId(vid);
      if (v is ControlValveEntity) names.add(v.zoneName);
      if (results == null) continue;
      for (final a in areasOfZone(project, results, vid)) {
        final c = crops[a.id];
        if (c == null) continue;
        any = true;
        hours = math.max(hours, c.hoursPerEvent);
        interval = math.max(interval, c.intervalDays);
      }
    }
    if (!any) {
      hours = f.durationHours;
      if (results != null && f.valveIds.isNotEmpty) warnings.add('schedule_no_area:${f.id}');
    }
    perFlow[f.id] = hours;
    intervalOf[f.id] = interval;
    zoneNames[f.id] = names;
  }
  final entries = <ScheduleEntry>[];
  final start = startDate ?? DateTime.now();
  final day0 = DateTime(start.year, start.month, start.day);
  for (var d = 0; d < days; d++) {
    final day = day0.add(Duration(days: d));
    var cursor = dayStartHour;
    for (final f in flows) {
      final interval = intervalOf[f.id]!.round();
      if (interval > 1 && d % interval != 0) continue;
      final dur = perFlow[f.id]!;
      if (dur <= 0) continue;
      final startH = keepStartHours ? f.startHour : cursor;
      final q = results?.systemFlows.where((r) => r.flowId == f.id).firstOrNull?.totalFlow ?? 0;
      entries.add(ScheduleEntry(day: day, flowId: f.id, flowName: f.name, startHour: startH, durationHours: dur, zones: zoneNames[f.id]!, flow: q));
      if (!keepStartHours) cursor += dur;
    }
    if (cursor - dayStartHour > 24 + 1e-9) warnings.add('schedule_over_24h:${day.toIso8601String().substring(0, 10)}');
  }
  return ControllerProgram(perFlowHours: perFlow, entries: entries, warnings: warnings.toSet().toList());
}

/// CSV export of a controller programme (one line per event).
String controllerProgramCsv(ControllerProgram p, {String Function(String key)? t}) {
  String tr(String k) => t?.call(k) ?? k;
  final b = StringBuffer('﻿');
  b.writeln([tr('sch.date'), tr('sch.flow'), tr('sch.zones'), tr('sch.start'), tr('sch.end'), tr('sch.duration')].join(';'));
  String hhmm(double h) {
    final hh = h.floor() % 24, mm = ((h - h.floor()) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  for (final e in p.entries) {
    b.writeln([e.day.toIso8601String().substring(0, 10), e.flowName, e.zones.join(' + '), hhmm(e.startHour), hhmm(e.endHour), e.durationHours.toStringAsFixed(2)].join(';'));
  }
  return b.toString();
}
