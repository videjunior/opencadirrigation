import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import '../support/language_packs.dart';

/// The example gallery: every project builds, is fully connected, designs
/// without errors and matches the `.oci.json` files under examples/.
void main() {
  setUpAll(installLanguagePacksFromDisk);
  final t = I18n('pt');

  Map<String, dynamic> normalised(Project p) {
    final j = p.toJson();
    (j['meta'] as Map<String, dynamic>)
      ..['uid'] = 'x'
      ..['created'] = '2026-01-01T00:00:00.000Z'
      ..remove('modified');
    return j;
  }

  for (final ex in exampleGallery) {
    group('example ${ex.id.name}', () {
      final p = buildExample(ex.id, t.call, lang: 'pt');

      test('builds in every language with translated names and survives a JSON round trip', () {
        for (final lang in supportedLanguages) {
          final q = buildExample(ex.id, I18n(lang).call, lang: lang);
          expect(q.entities, isNotEmpty);
          expect(q.meta.name, isNot(startsWith('ex.')), reason: 'missing i18n key');
          for (final e in q.entities) {
            expect(e.name, isNot(startsWith('ex.')), reason: '${e.id} ${e.name}');
          }
          for (final k in ['title', 'sub', 'tags']) {
            expect(I18n(lang).has('exg.${ex.id.name}.$k'), isTrue, reason: 'exg.${ex.id.name}.$k');
          }
          final back = Project.fromJson(jsonDecode(q.toJsonString()) as Map<String, dynamic>);
          expect(back.entities.length, q.entities.length);
          expect(jsonEncode(normalised(back)), jsonEncode(normalised(q)));
        }
      });

      test('is connected and passes the design check without errors or warnings', () {
        final m = NetworkBuilder(p).build();
        expect(m.unconnectedEntities, isEmpty, reason: m.unconnectedEntities.map((id) => '${p.byId(id)?.type} ${p.byId(id)?.name}').join(', '));
        final rep = runDesignCheck(p);
        final issues = rep.issues.where((i) => i.severity != CheckSeverity.info || i.code == 'area_no_emitters').toList();
        expect(issues, isEmpty, reason: issues.map((i) => '${i.code} ${i.entityIds}').join('; '));
      });

      test('designs: zones converge within the pressure window, supplies cope', () {
        final r = Designer(p, label: (k) => t(k)).designAll();
        expect(r.unconnected, isEmpty);
        final hasPivot = p.entities.any((e) => e is PivotEntity);
        if (hasPivot) {
          expect(r.pivots, isNotEmpty);
          for (final pv in r.pivots.values) {
            expect(pv.deficit, lessThan(0.05), reason: 'pivot deficit ${pv.deficit}');
          }
        } else {
          expect(r.zones, isNotEmpty);
        }
        for (final z in r.zones.values) {
          expect(z.converged, isTrue, reason: z.zoneName);
          expect(z.withinWindow, isTrue, reason: '${z.zoneName}: ${z.warnings}');
        }
        expect(r.systemFlows, isNotEmpty);
        for (final f in r.systemFlows) {
          expect(f.converged, isTrue, reason: f.name);
          expect(f.maxDeficit, lessThan(0.05), reason: '${f.name}: deficit ${f.maxDeficit} m, ${f.warnings}');
          expect(f.totalFlow / m3sPerM3h, greaterThan(0));
          // the pump of the example works inside its range and is not grossly
          // oversized; a calculated supply never runs at a negative pressure
          expect(f.warnings.where((w) => w.startsWith('pump_out_of_range')), isEmpty, reason: f.name);
          for (final s in f.supplies) {
            expect(s.head, greaterThanOrEqualTo(0), reason: '${f.name}: ${s.name}');
            expect(s.surplusHead, lessThan(35), reason: '${f.name}: ${s.name} surplus ${s.surplusHead} m');
          }
          // pumps work within their practical suction lift: a submersible
          // sits at the water level, a surface pump lifts from a shallow
          // source; no device sees a fictitious negative pressure
          expect(f.warnings.where((w) => w.startsWith('pump_suction_lift')), isEmpty, reason: f.name);
          for (final d in f.devices) {
            final e = p.byId(d.entityId);
            final surfacePump = e is PumpEntity && !(p.catalog.pump(e.pumpSpecId)?.submersible ?? false);
            expect(d.upstreamPressure, greaterThanOrEqualTo(surfacePump ? -maxSuctionLift(d.elevation) : -0.5), reason: '${f.name}: ${e?.name}');
          }
        }
        expect(r.bom, isNotEmpty);
        // every example with solenoid valves has its electrical part: each
        // valve wired to a controller with stations to spare, the solenoid
        // voltage kept while it opens, wires and controller in the BOM
        final valves = p.entities.whereType<ControlValveEntity>().toList();
        if (valves.isNotEmpty) {
          final el = r.electrical;
          expect(el, isNotNull, reason: 'no controller or wire route');
          expect(el!.warnings, isEmpty);
          expect({for (final w in el.runs) w.valveId}, {for (final v in valves) v.id});
          for (final w in el.runs) {
            expect(w.ok, isTrue, reason: '${w.zoneName}: ${w.volts} V');
          }
          for (final c in el.controllers) {
            expect(c.overloaded, isFalse, reason: c.name);
          }
          expect(r.bom.where((b) => b.category == 'bom.electrical'), isNotEmpty);
        }
        // nothing else the reports show is a warning either: no water hammer
        // over a pipe class, flushing converges, every zone is uniform, every
        // area gets water within the day and the programme fits the days
        expect(r.surge.where((s) => s.exceeds).map((s) => '${s.pipeName} ${s.totalHead}'), isEmpty);
        for (final fl in r.flushing) {
          expect(fl.converged, isTrue, reason: 'flushing ${fl.zoneName}');
          expect(fl.minEndHead, closeTo(p.params.flushingMinEndHeadM, 0.05), reason: 'flushing ${fl.zoneName}');
        }
        for (final z in r.zones.values) {
          expect(z.uniformity.eu, greaterThan(85), reason: '${z.zoneName}: EU ${z.uniformity.eu}');
        }
        for (final a in areaRequirements(p, r)) {
          expect(a.flow, greaterThan(0), reason: '${a.name} gets no water');
          expect(a.hoursPerDay, lessThan(24), reason: '${a.name}: ${a.hoursPerDay} h a day');
        }
        final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1));
        expect(prog.warnings, isEmpty);
        expect(prog.maxDailyHours, lessThan(24));
        // the design assistant finds no error nor warning, and every message
        // it shows has an explanation
        final advice = buildAdvice(p, results: r);
        expect(advice.where((a) => a.level != AdviceLevel.info).map((a) => '${a.code} ${a.entityIds}'), isEmpty);
        for (final a in advice) {
          expect(adviceCodes, contains(a.code), reason: a.raw);
        }
        // every report cell (PDF/CSV/TXT share these strings) is a plain
        // positional number: no scientific notation, no "-0.00"
        final labels = ReportLabels(t: t.call, has: t.has, warning: (w) => w, entityName: (id) => p.byId(id)?.name ?? id);
        final tables = buildReportTables(project: p, results: r, labels: labels);
        expect(tables, isNotEmpty);
        final sci = RegExp(r'\d[eE][+-]?\d');
        for (final tb in tables) {
          for (final row in tb.rows) {
            for (final cell in row) {
              if (cell is! RNum) continue;
              final txt = '$cell';
              expect(sci.hasMatch(txt), isFalse, reason: '${tb.key}: $txt');
              expect(txt.startsWith('-0') && !txt.contains(RegExp(r'[1-9]')), isFalse, reason: '${tb.key}: $txt');
            }
          }
        }
        // ignore: avoid_print
        print('${ex.id.name}: ${r.zones.length} zones, ${r.systemFlows.length} flows, ${p.entities.length} entities, capital ${r.capitalCost.toStringAsFixed(0)}');
      });

      test('matches the shipped .oci.json files of every language', () {
        for (final lang in supportedLanguages) {
          final f = File('examples/$lang/${ex.id.name}.oci.json');
          expect(f.existsSync(), isTrue, reason: 'run dart run tool/gen_examples.dart');
          final shipped = Project.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
          final built = buildExample(ex.id, I18n(lang).call, lang: lang);
          expect(jsonEncode(normalised(shipped)), jsonEncode(normalised(built)), reason: '${f.path} is out of date: run dart run tool/gen_examples.dart');
        }
      }, skip: !Directory('examples').existsSync());
    });
  }

  test('gallery lookups', () {
    expect(exampleIdFromName('garden'), ExampleId.garden);
    expect(exampleIdFromName('SportsField'), ExampleId.sportsField);
    expect(exampleIdFromName('nope'), isNull);
    expect(exampleIdFromName(null), isNull);
    expect(exampleGallery.map((e) => e.id).toSet().length, ExampleId.values.length);
  });
}
