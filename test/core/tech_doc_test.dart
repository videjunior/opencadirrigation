import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/tech_doc.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';

/// The technical documents and their writers: Markdown (escaped, tables as
/// pipe tables), CSV (semicolons, a BOM, quoted cells), XLSX (a text sheet
/// and a sheet per table, numbers as numbers) and PDF (A4 pages, running
/// header and page numbers, long tables over several pages with their
/// header again, bare pages for a package).
void main() {
  final t = I18n('pt');

  TechDocument sample({int rows = 3, bool landscape = false}) => TechDocument(
    key: 'sample',
    title: 'Documento de teste',
    subtitle: 'Projeto · Cliente',
    landscape: landscape,
    sections: [
      const TechSection('Primeira seção', [
        TechParagraph('Um parágrafo com | barra e *asterisco*.'),
        TechBullets(['item um', 'item dois'], numbered: true),
        TechFields([('Campo', 'valor; com ponto e vírgula'), ('Vazio', '')]),
        TechFormula('V = Q × h × d', where: [('Q', 'vazão (m³/h)')], source: 'Fonte'),
        TechNote('Uma nota de aviso', warning: true),
      ], key: 'first'),
      TechSection(
        'Tabelas',
        [
          TechTable(
            ReportTable(
              key: 'tb',
              title: 'Tabela A',
              headers: ['Nome', 'Valor (m)'],
              rows: [
                for (var i = 0; i < rows; i++) ['linha $i', RNum(i * 1.5, 1)],
              ],
            ),
            note: 'nota da tabela',
          ),
        ],
        level: 2,
        key: 'tables',
      ),
    ],
  );

  test('every text of the document, and its tables in order', () {
    final d = sample();
    final texts = d.texts.toList();
    expect(texts, containsAll(['Documento de teste', 'Primeira seção', 'item dois', 'Campo', 'V = Q × h × d', 'vazão (m³/h)', 'Uma nota de aviso', 'Tabela A', 'Nome', 'linha 2', 'nota da tabela']));
    expect(d.tables.map((x) => x.key), ['tb']);
  });

  test('Markdown: headings by level, escaped text, fields and tables as pipe tables', () {
    final md = sample().toMarkdown();
    expect(md, startsWith('# Documento de teste\n'));
    expect(md, contains('\n## Primeira seção\n'));
    expect(md, contains('\n### Tabelas\n'));
    expect(md, contains('com \\| barra e \\*asterisco\\*'));
    expect(md, contains('1. item um'));
    expect(md, contains('| Campo | valor; com ponto e vírgula |'));
    expect(md, contains('```\nV = Q × h × d\n```'));
    expect(md, contains('> **Uma nota de aviso**'));
    // a numeric column is right-aligned
    expect(md, contains('| Nome | Valor (m) |\n|---|---:|'));
    expect(md, contains('| linha 1 | 1.5 |'));
  });

  test('CSV: a BOM, the sections, the fields and the tables, cells quoted when needed', () {
    final csv = sample().toCsv();
    expect(csv.codeUnitAt(0), 0xFEFF);
    expect(csv, contains('PRIMEIRA SEÇÃO'));
    expect(csv, contains('Campo;"valor; com ponto e vírgula"'));
    expect(csv, contains('Nome;Valor (m)\nlinha 0;0.0\n'));
  });

  test('XLSX: the text sheet first, then a sheet per table with numbers', () {
    final sheets = XlsxReader.read(sample().toXlsx());
    expect(sheets.first.name, 'Documento de teste');
    expect(sheets.first.rows.any((r) => r.contains('Campo')), isTrue);
    final tb = sheets.firstWhere((s) => s.name == 'Tabela A');
    expect(tb.headers, ['Nome', 'Valor (m)']);
    expect(tb.rows[2][1], 3.0);
  });

  test('PDF: A4 pages with the running header and the page numbers', () {
    final doc = PdfDocument(title: 'x');
    final pages = addTechDocumentPages(doc, sample(rows: 220), t: t.call, date: DateTime(2026, 11, 2));
    expect(pages.length, greaterThan(2));
    expect(pages.first.width, closeTo(210 * ptPerMm, 1e-6));
    expect(pages.first.height, closeTo(297 * ptPerMm, 1e-6));
    final raw = latin1.decode(doc.build(compress: false));
    String drawn(String s) => '${PdfDocument.pdfString(s)} Tj';
    expect(raw, contains(drawn(t('pdf.page', {'i': '1', 'n': '${pages.length}'}))));
    expect(raw, contains(drawn(t('pdf.page', {'i': '${pages.length}', 'n': '${pages.length}'}))));
    // the table goes on over the pages with its header again
    expect(raw, contains(drawn('Tabela A ${t('pdf.cont')}')));
    expect(raw, contains(drawn('02/11/2026')));
    // landscape documents turn the page
    final wide = PdfDocument();
    final lp = addTechDocumentPages(wide, sample(landscape: true), t: t.call);
    expect(lp.first.width, closeTo(297 * ptPerMm, 1e-6));
  });

  test('PDF for a package: bare pages without header nor footer', () {
    final doc = PdfDocument();
    final pages = addTechDocumentPages(doc, sample(rows: 220), t: t.call, chrome: false);
    final raw = latin1.decode(doc.build(compress: false));
    expect(raw, isNot(contains(PdfDocument.pdfString(t('pdf.page', {'i': '1', 'n': '${pages.length}'})))));
    expect(raw, isNot(contains('Gerado por')));
    expect(pages, isNotEmpty);
  });

  test('a document of its own is a whole PDF', () {
    final bytes = techDocumentPdf(sample(), t: t.call, author: 'Eng.');
    expect(latin1.decode(bytes.sublist(0, 8)), '%PDF-1.4');
    expect(latin1.decode(bytes.sublist(bytes.length - 6)).trim(), '%%EOF');
  });
}
