import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_standards.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/project_export.dart';

/// The standards of the criteria of the reports (1.6.0 PRD): every table
/// that applies a criterion names its standards under its title, in the PDF,
/// the CSV and the text report.
void main() {
  final pt = I18n('pt');

  test('every criterion has its references and its name in pt, en and es', () {
    for (final cs in reportTableCriteria.values) {
      for (final c in cs) {
        expect(reportCriteria[c], isNotNull, reason: c);
      }
    }
    for (final e in reportCriteria.entries) {
      expect(e.value, isNotEmpty, reason: e.key);
      for (final lang in const ['pt', 'en', 'es']) {
        expect(I18n(lang).has('prd.std.${e.key}'), isTrue, reason: '${e.key} $lang');
      }
    }
    expect(standardsNote('bom', pt.call), isEmpty, reason: 'a list of materials follows no criterion');
    final zones = standardsNote('zones', pt.call);
    expect(zones, startsWith('Critérios e normas: '));
    expect(zones, allOf(contains('ISO 15886-3'), contains('ASABE EP405.1'), contains('UNE-EN 15097'), contains('ABNT NBR ISO 9261')));
    expect(standardsNote('pipes', pt.call), allOf(contains('ASAE S376.2'), contains('ABNT NBR 14312')));
    expect(standardsNote('licensing', pt.call), contains('CONAMA 284/2001'));
    expect(standardsNote('electrical', I18n('en').call), allOf(startsWith('Criteria and standards: '), contains('ABNT NBR 5410')));
  });

  test('the reports of a design carry them: PDF, CSV and text', () {
    final p = buildExample(ExampleId.orchard, pt.call, lang: 'pt');
    final r = Designer(p, label: (k) => pt(k)).designAll();
    final ex = ProjectExporter(
      project: p,
      results: r,
      labels: ReportLabels(t: pt.call, has: pt.has, warning: pt.warning),
    );
    final tables = ex.reportTables();
    final zones = tables.firstWhere((t) => t.key == 'zones');
    expect(zones.standards, contains('ASABE EP405.1'));
    expect(tables.firstWhere((t) => t.key == 'bom').standards, isEmpty);
    final csv = ex.reportCsv();
    expect(csv, contains('Critérios e normas: '));
    final txt = ex.reportTxt();
    expect(txt, contains(zones.standards));
    final doc = PdfDocument(title: 'x');
    ex.sheetBuilder().addReportPages(doc, tables);
    final raw = latin1.decode(doc.build(compress: false));
    expect(raw, contains('EP405.1'));
    expect(raw, contains('S376.2'));
  });
}
