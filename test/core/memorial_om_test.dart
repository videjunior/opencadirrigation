import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/memorial.dart';
import 'package:opencadirrigation/core/design/om_plan.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/io/tech_doc.dart';
import 'package:opencadirrigation/core/model/entities.dart';

/// The memorial (PRD-03) and the operation and maintenance plan (PRD-12):
/// documents built from the project alone, the same project giving the
/// same text, with every section, the formulas of the friction law in use,
/// the figures of the design, and what is missing without results.
void main() {
  final t = I18n('pt');
  final labels = ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w));
  final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
  final r = Designer(p, label: (k) => t(k)).designAll();

  group('memorial', () {
    test('every section, built from the project and its results', () {
      final doc = buildMemorial(p, r, labels);
      expect(doc.key, 'memorial');
      expect(doc.title, t('prb.mem.title'));
      // (the notes of the project, when it has any, come before the references)
      expect(doc.sections.map((s) => s.key).where((k) => k != 'notes'), [
        'identification',
        'objective',
        'areas',
        'climate',
        'source',
        'criteria',
        'formulas',
        'zones',
        'network',
        'pumping',
        'operation',
        'checks',
        'materials',
        'references',
      ]);
      final zones = doc.tables.firstWhere((x) => x.key == 'memZones');
      expect(zones.rows, hasLength(r.zones.length));
      final bom = doc.tables.firstWhere((x) => x.key == 'memBom');
      expect((bom.rows.last.last as RNum).value, closeTo(r.capitalCost, 1e-6));
      expect(doc.tables.any((x) => x.key == 'memAreas'), isTrue);
      expect(doc.tables.any((x) => x.key == 'memPumps'), isTrue);
    });

    test('the same project gives the same text', () {
      expect(buildMemorial(p, r, labels).toMarkdown(), buildMemorial(p, r, labels).toMarkdown());
    });

    test('the formulas of the friction law in use, with their sources', () {
      String formulas(FrictionMethod m) {
        final q = p.copy()..params.frictionMethod = m;
        final doc = buildMemorial(q, r, labels);
        return doc.sections.firstWhere((s) => s.key == 'formulas').blocks.whereType<TechFormula>().map((f) => '${f.expression} ${f.source}').join('\n');
      }

      expect(formulas(FrictionMethod.hazenWilliams), contains(t('prb.f.hwExpr')));
      expect(formulas(FrictionMethod.darcyWeisbach), contains(t('prb.f.dwExpr')));
      expect(formulas(FrictionMethod.darcyWeisbach), isNot(contains(t('prb.f.hwExpr'))));
      expect(formulas(FrictionMethod.manning), contains(t('prb.src.manning')));
      expect(formulas(FrictionMethod.hazenWilliams), contains(t('prb.f.euExpr')));
    });

    test('the objective and the notes of the designer go into the text', () {
      final q = p.copy();
      q.deliverables.memorial
        ..objective = 'Projeto executivo para o edital 12/2026.'
        ..notes = 'Válido com a análise de água anexa.';
      final doc = buildMemorial(q, r, labels);
      final objective = doc.sections.firstWhere((s) => s.key == 'objective').blocks.first as TechParagraph;
      expect(objective.text, 'Projeto executivo para o edital 12/2026.');
      expect(doc.sections.firstWhere((s) => s.key == 'notes').texts(), contains('Válido com a análise de água anexa.'));
    });

    test('without results the sections of the results say to run the design', () {
      final doc = buildMemorial(p, null, labels);
      for (final k in ['zones', 'network', 'materials']) {
        final s = doc.sections.firstWhere((x) => x.key == k);
        expect(s.blocks.whereType<TechNote>().map((n) => n.text), contains(t('prb.mem.needDesign')), reason: k);
      }
    });

    test('Markdown and PDF of the memorial', () {
      final doc = buildMemorial(p, r, labels);
      final md = doc.toMarkdown();
      expect(md, startsWith('# ${t('prb.mem.title')}'));
      expect(md, contains('## ${t('prb.mem.formulas')}'));
      final pdf = techDocumentPdf(doc, t: t.call);
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    });
  });

  group('operation and maintenance plan', () {
    test('the chlorine injection rate and the test pressure', () {
      // 50 m³/h at 2 mg/L with a 10 % product: 50 × 2 / (10 × 10) = 1 L/h
      expect(chlorineInjectionLph(flowM3h: 50, doseMgL: 2, productPct: 10), closeTo(1, 1e-12));
      expect(chlorineInjectionLph(flowM3h: 50, doseMgL: 2, productPct: 0), 0);
      expect(testPressure(40, 80), closeTo(60, 1e-12));
      expect(testPressure(40, 50), 50);
      expect(testPressure(40, 0), closeTo(60, 1e-12));
    });

    test('every section, with the figures of the design', () {
      final doc = buildOmPlan(p, r, labels);
      expect(doc.key, 'om');
      expect(doc.sections.map((s) => s.key), ['system', 'startup', 'pressures', 'flushing', 'filters', 'chemical', 'offSeason', 'equipment', 'schedule', 'monitoring', 'spares']);
      final sheet = doc.tables.firstWhere((x) => x.key == 'omPressures');
      expect(sheet.rows, hasLength(r.zones.length));
      // the field columns are left blank to be filled in
      expect(sheet.rows.first.sublist(4), ['', '', '', '']);
      final cl = doc.tables.firstWhere((x) => x.key == 'omChlorine');
      expect(cl.rows, hasLength(r.systemFlows.where((f) => f.totalFlow > 0).length));
      final q = r.systemFlows.first.totalFlow * 3600;
      expect((cl.rows.first[2] as RNum).value, closeTo(q * 1 / (10 * 10), 1e-9));
      expect(doc.tables.any((x) => x.key == 'omTest'), isTrue);
      expect(doc.tables.any((x) => x.key == 'omFilters'), isTrue);
      expect(doc.tables.any((x) => x.key == 'omFlushing'), isTrue);
      expect(doc.tables.any((x) => x.key.startsWith('permitLog')), isTrue);
      final spares = doc.tables.firstWhere((x) => x.key == 'omSpares');
      for (final row in spares.rows) {
        expect((row[4] as RNum).value, greaterThanOrEqualTo(1));
      }
    });

    test('the schedule marks the months of the irrigation season', () {
      final doc = buildOmPlan(p, r, labels);
      final s = doc.tables.firstWhere((x) => x.key == 'omSchedule');
      expect(s.headers, hasLength(15));
      // the readings of the meters every month of the year
      final meter = s.rows.firstWhere((row) => row[0] == t('prb.om.c.meter'));
      expect(meter.sublist(3), List.filled(12, 'X'));
    });

    test('a filter is asked for when the design has none', () {
      final q = p.copy()..entities.removeWhere((e) => e is MiscHydraulicEntity);
      final doc = buildOmPlan(q, null, labels);
      final filters = doc.sections.firstWhere((s) => s.key == 'filters');
      expect(filters.blocks.whereType<TechNote>().map((n) => n.text), contains(t('prb.om.noFilters')));
      expect(doc.sections.firstWhere((s) => s.key == 'pressures').blocks.whereType<TechNote>(), isNotEmpty);
    });
  });
}

extension on TechSection {
  List<String> texts() => [for (final b in blocks) ...b.texts];
}
