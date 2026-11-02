import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/area_requirement.dart';
import 'package:opencadirrigation/core/design/area_water.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/irrigation_requirement.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/valve_in_head.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The seam between the agronomy reports and the controller, for every
/// example of the gallery: the FAO-56 requirement table, the water table,
/// the crop water table and the controller programme are one computation
/// seen four ways (the rule of area_water.dart), so that what the
/// controller is told to run is the water the tables say the field needs.
///
/// test/core/agronomy_rules_test.dart checks the rule itself on small cases
/// and the daily volume across the gallery; this file follows the numbers
/// of every area through to the programme: which flow waters it, how often
/// and how long, what the events add up to over four weeks, the month of
/// the programme and its CSV.
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  const days = 28;

  for (final ex in exampleGallery) {
    group(ex.id.name, () {
      late Project p;
      late DesignResults r;
      late Map<String, AreaRequirement> water;
      late Map<String, CropWaterResult> crops;
      late Map<String, RequirementTable> tables;
      late ControllerProgram prog;
      late Map<String, Set<String>> wateredBy;
      late Set<String> machineFlows;

      setUpAll(() {
        p = buildExample(ex.id, t);
        r = Designer(p, label: t).designAll();
        water = {for (final w in areaRequirements(p, r)) w.areaId: w};
        crops = {for (final c in cropWaterRequirements(p, r)) c.areaId: c};
        tables = areaRequirementTables(p, r);
        prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1), days: days);
        (wateredBy, machineFlows) = _wateredBy(p, r);
      });

      test('the water table, the crop table and the FAO-56 table give one requirement per area', () {
        expect(crops.keys.toSet(), water.keys.toSet(), reason: 'the same areas in both tables');
        for (final c in crops.values) {
          final w = water[c.areaId]!;
          final why = '${ex.id.name} ${c.name}';
          // per day: the event over the interval
          expect(c.grossDepthMm / c.intervalDays, closeTo(w.grossDepthMm, 1e-9), reason: why);
          expect(c.volumePerEventM3 / c.intervalDays, closeTo(w.dailyVolumeM3, 1e-6), reason: why);
          expect(c.applicationRateMmH, closeTo(w.precipitationMmH, 1e-9), reason: why);
          if (c.applicationRateMmH > 0) {
            // hours per day of the water table = hours per event / interval
            expect(c.dailyHours, closeTo(w.hoursPerDay, 1e-6), reason: why);
            expect(c.hoursPerEvent * c.applicationRateMmH, closeTo(c.grossDepthMm, 1e-6), reason: why);
          }
          expect(c.netDepthMm, lessThanOrEqualTo(c.grossDepthMm + 1e-9), reason: why);
          final table = tables[c.areaId];
          if (table == null || c.source != AreaWaterSource.cropTable) {
            expect(c.month, isNull, reason: '$why: no crop of the FAO-56 table in the balance, no month');
            // the report table of a crop on an area that waters a typed depth gives the same day too
            if (table != null) expect(w.dailyVolumeM3, closeTo(designRow(table)!.dailyVolumeM3, 1e-6), reason: why);
            continue;
          }
          final row = designRow(table)!;
          expect(c.month, row.start.month, reason: why);
          expect(w.grossDepthMm, closeTo(row.grossMmDay, 1e-9), reason: why);
          expect(w.dailyVolumeM3, closeTo(row.dailyVolumeM3, 1e-6), reason: why);
          expect(c.rawMm, closeTo(row.rawMm, 1e-9), reason: why);
          expect(c.kr, closeTo(row.kr, 1e-12), reason: why);
          if (!c.machine) expect(c.intervalDays, row.intervalDays, reason: why);
        }
      });

      test('every flow runs for its thirstiest area, as often as its shortest interval', () {
        expect(prog.warnings, isEmpty);
        for (final e in wateredBy.entries) {
          final areas = [for (final id in e.value) crops[id]!];
          final interval = prog.intervalDays[e.key]!;
          final hours = prog.perFlowHours[e.key]!;
          final why = '${ex.id.name} flow ${e.key}';
          final shortest = machineFlows.contains(e.key) ? 1 : areas.map((c) => c.intervalDays.round()).fold(1 << 30, math.min);
          expect(interval, math.max(1, shortest), reason: why);
          expect(hours, closeTo(areas.fold(0.0, (m, c) => math.max(m, c.dailyHours * interval)), 1e-9), reason: why);
          for (final c in areas) {
            // (an area that needs nothing this month takes what its flow gives)
            if (c.applicationRateMmH <= 0 || c.dailyHours <= 0) continue;
            // every area of the flow gets at least what it needs over the interval…
            expect(hours * c.applicationRateMmH, greaterThanOrEqualTo(c.grossDepthMm / c.intervalDays * interval - 1e-6), reason: '$why ${c.name}');
            // …within the uneven-areas allowance (no schedule_uneven_areas)…
            expect(hours * c.applicationRateMmH, lessThanOrEqualTo(unevenAreasRatio * c.grossDepthMm / c.intervalDays * interval + 1e-6), reason: '$why ${c.name}');
            // …and none waits past its readily available water
            if (!c.machine && interval > 1) expect(interval * c.etcMmDay, lessThanOrEqualTo(c.rawMm + 1e-9), reason: '$why ${c.name}');
          }
        }
      });

      test('the events of four weeks: every interval days, the same run time, within the day', () {
        for (final f in wateredBy.keys) {
          final events = prog.entries.where((e) => e.flowId == f).toList();
          final interval = prog.intervalDays[f]!;
          final hours = prog.perFlowHours[f]!;
          final why = '${ex.id.name} flow $f';
          if (hours <= 0) {
            expect(events, isEmpty, reason: why);
            continue;
          }
          expect(events, isNotEmpty, reason: why);
          final first = events.first.day.difference(DateTime(2026, 1, 1)).inDays;
          expect(first, lessThan(interval), reason: '$why: starts within its first interval');
          expect(events.length, ((days - first) / interval).ceil(), reason: why);
          for (var i = 0; i < events.length; i++) {
            expect(events[i].durationHours, hours, reason: why);
            if (i > 0) expect(events[i].day.difference(events[i - 1].day).inDays, interval, reason: why);
          }
          // the water of the period: as many events as the period holds, each the flow's need
          for (final id in wateredBy[f]!) {
            final c = crops[id]!;
            if (c.applicationRateMmH <= 0) continue;
            final applied = events.length * hours * c.applicationRateMmH;
            final need = c.grossDepthMm / c.intervalDays * events.length * interval;
            expect(applied, greaterThanOrEqualTo(need - 1e-6), reason: '$why ${c.name}');
          }
        }
        expect(prog.maxDailyHours, lessThanOrEqualTo(24 + 1e-9), reason: 'no schedule_over_24h, so no day runs past 24 h');
      });

      test('every area the zones and stations water is in the programme', () {
        final scheduled = {for (final s in wateredBy.values) ...s};
        final machineAreas = {
          for (final m in p.entities.whereType<PivotEntity>())
            for (final a in areasOfMachine(p, m)) a.id,
        };
        for (final w in water.values) {
          if (w.flow <= 0 || w.dailyVolumeM3 <= 0) continue;
          // a machine outside every system flow is not on the controller (it has its own panel)
          if (w.machineFlow >= 0.5 * w.flow && machineAreas.contains(w.areaId) && p.systemFlows.isEmpty) continue;
          expect(scheduled, contains(w.areaId), reason: '${ex.id.name} ${w.name}: watered by the design, missing from the controller programme');
        }
      });

      test('a programme for one month follows the FAO-56 row of that month', () {
        // the month farthest from the design month of the first area of the table
        final designMonth = crops.values.map((c) => c.month).whereType<int>().firstOrNull ?? 1;
        final month = (designMonth + 5) % 12 + 1;
        final monthly = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1), days: days, month: month);
        expect(monthly.month, month);
        final inMonth = {for (final c in cropWaterRequirements(p, r, month: month)) c.areaId: c};
        for (final c in inMonth.values) {
          final table = tables[c.areaId];
          if (table == null) continue;
          final row = designRow(table, month: month);
          final why = '${ex.id.name} ${c.name} month $month';
          if (row == null) {
            expect(c.grossDepthMm, 0, reason: '$why: the crop is not in the field');
            continue;
          }
          expect(c.month, month, reason: why);
          expect(c.grossDepthMm / c.intervalDays, closeTo(row.grossMmDay, 1e-9), reason: why);
        }
        for (final e in wateredBy.entries) {
          final areas = [
            for (final id in e.value)
              if (inMonth[id] case final c?) c,
          ];
          if (areas.isEmpty) continue;
          final interval = monthly.intervalDays[e.key]!;
          expect(monthly.perFlowHours[e.key], closeTo(areas.fold(0.0, (m, c) => math.max(m, c.dailyHours * interval)), 1e-9), reason: '${ex.id.name} flow ${e.key} month $month');
        }
      });

      test('the CSV of the programme is its events, one line each', () {
        final csv = controllerProgramCsv(prog);
        final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines, hasLength(prog.entries.length + 1));
        for (var i = 0; i < prog.entries.length; i++) {
          final e = prog.entries[i];
          final cells = lines[i + 1].split(';');
          expect(cells.first, e.day.toIso8601String().substring(0, 10));
          expect(cells[1], e.flowName);
          expect(double.parse(cells.last), closeTo(e.durationHours, 0.005 + 1e-9));
        }
      });
    });
  }
}

/// The areas each flow of the programme waters, as buildControllerProgram
/// finds them (its zones, its valve-in-head stations, its machines), keyed
/// by flow id; and the flows that run a machine (every day).
(Map<String, Set<String>>, Set<String>) _wateredBy(Project p, DesignResults r) {
  final vih = VihStations.of(p);
  final flows = p.systemFlows.isNotEmpty
      ? p.systemFlows
      : [
          SystemFlow(id: 'auto', name: 'all', valveIds: {...p.entities.whereType<ControlValveEntity>().map((v) => v.id), ...vih.heads.keys}),
        ];
  final out = <String, Set<String>>{};
  final machines = <String>{};
  for (final f in flows) {
    if (f.valveIds.isEmpty) continue;
    final areas = <String>{};
    for (final id in f.valveIds) {
      final e = vih.isStation(id) ? null : p.byId(id);
      if (vih.isStation(id)) {
        areas.addAll(areasOfStation(p, id, stations: vih).map((a) => a.id));
      } else if (e is PivotEntity) {
        final m = areasOfMachine(p, e);
        if (m.isNotEmpty) machines.add(f.id);
        areas.addAll(m.map((a) => a.id));
      } else {
        areas.addAll(areasOfZone(p, r, id).map((a) => a.id));
      }
    }
    if (areas.isNotEmpty) out[f.id] = areas;
  }
  return (out, machines);
}
