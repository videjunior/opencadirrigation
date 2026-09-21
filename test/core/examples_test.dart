import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
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

      test('is connected and passes the design check without errors', () {
        final m = NetworkBuilder(p).build();
        expect(m.unconnectedEntities, isEmpty, reason: m.unconnectedEntities.map((id) => '${p.byId(id)?.type} ${p.byId(id)?.name}').join(', '));
        final rep = runDesignCheck(p);
        final errors = rep.issues.where((i) => i.severity == CheckSeverity.error).toList();
        expect(errors, isEmpty, reason: errors.map((i) => '${i.code} ${i.entityIds}').join('; '));
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
          // a pump inlet sees at worst the suction of the well (water level
          // below ground), never a fictitious negative supply pressure
          final lowestWater = p.entities.whereType<WaterSupplyEntity>().map((s) => s.waterLevelOffsetM).fold(0.0, (a, b) => a < b ? a : b);
          for (final d in f.devices) {
            expect(d.upstreamPressure, greaterThanOrEqualTo(lowestWater - 1), reason: '${f.name}: ${p.byId(d.entityId)?.name}');
          }
        }
        expect(r.bom, isNotEmpty);
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
