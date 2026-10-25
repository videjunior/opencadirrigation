import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';

/// BNDES FINAME codes of credentialed items: kept in the catalogue, carried
/// by the bill of materials (a column and the financeable subtotal) and the
/// quote, and through the catalogue tables.
void main() {
  test('codes travel from the catalogue to the bill of materials and the quote', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.orchard);
    final r0 = Designer(c.project).designAll();
    final item = r0.bom.firstWhere((l) => l.specId != null && l.total > 0);
    c.project.catalog.finame[item.specId!] = '12345678';
    final r = Designer(c.project).designAll();
    c.results = r;
    final line = r.bom.firstWhere((l) => l.specId == item.specId);
    expect(line.finame, '12345678');
    expect(jsonDecode(jsonEncode(line.toJson()))['finame'], '12345678');
    final bom = c.reportTables().firstWhere((t) => t.key == 'bom');
    expect(bom.headers, contains('FINAME'));
    expect(bom.rows.any((row) => row.contains('12345678')), isTrue);
    expect(bom.rows.any((row) => row.first == c.t('rep.finameTotal')), isTrue);
    final quote = c.reportTables().firstWhere((t) => t.key == 'proposal');
    expect(quote.rows.any((row) => row.first == c.t('proposal.finame')), isTrue);
  });

  test('without codes the bill of materials keeps its columns', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.orchard);
    c.results = Designer(c.project).designAll();
    expect(c.reportTables().firstWhere((t) => t.key == 'bom').headers, isNot(contains('FINAME')));
  });

  test('the codes round-trip through the project JSON and the catalogue tables', () {
    final cat = Catalog.defaultCatalog();
    final id = cat.pipes.first.id;
    cat.finame[id] = 'F-001';
    expect(Catalog.fromJson(jsonDecode(jsonEncode(cat.toJson())) as Map<String, dynamic>).finame[id], 'F-001');
    final csv = CatalogIo.exportCsv(cat, CatalogGroup.pipes);
    expect(csv.split('\n').first, endsWith(';finame'));
    final back = CatalogIo.parse(csv, group: CatalogGroup.pipes);
    expect(back.catalog.finame[id], 'F-001');
    final mine = Catalog();
    mine.merge(back.catalog);
    expect(mine.finame[id], 'F-001');
    final xlsx = CatalogIo.parseXlsx(CatalogIo.exportXlsx(cat));
    expect(xlsx.catalog.finame[id], 'F-001');
  });
}
