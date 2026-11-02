import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/doc_package.dart';
import 'package:opencadirrigation/core/io/doc_pdf.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/tech_doc.dart';
import 'package:opencadirrigation/core/io/tech_doc_sections.dart';
import 'package:opencadirrigation/core/model/project.dart';

final en = I18n('en');

/// The orchard example in Brazil, designed.
(Project, DesignResults) orchard() {
  final p = buildExample(ExampleId.orchard, en.call, lang: 'en')..meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
  return (p, Designer(p, label: (k) => en(k)).designAll());
}

DocContext contextOf(Project p, DesignResults? r, DocProfile profile) => DocContext(
  project: p,
  results: r,
  labels: ReportLabels(t: en.call, has: en.has, warning: en.warning),
  profile: profile,
  date: DateTime(2026, 11, 2),
);

/// The technical documents of 1.6.0 PRB (permit table, memorial, operation
/// and maintenance plan, budget by compositions, life-cycle cost) as
/// sections of the document packages (tech_doc_sections.dart).
void main() {
  test('the five documents join the packages where they belong', () {
    final ids = {for (final s in documentSections()) s.id};
    expect(ids, containsAll(['prb.permit', 'prb.memorial', 'prb.om', 'prb.budget', 'prb.lcc']));
    for (final s in prbDocumentSections) {
      for (final lang in const ['pt', 'en', 'es']) {
        expect(I18n(lang).has(s.titleKey), isTrue, reason: '${s.titleKey} $lang');
      }
    }
    final (p, r) = orchard();
    List<String> defaults(DocProfile profile) => defaultSectionIds(profile, contextOf(p, r, profile));
    expect(defaults(DocProfile.permit), contains('prb.permit'));
    expect(defaults(DocProfile.permit), isNot(contains('prb.memorial')), reason: 'offered in the permit package, not ticked');
    expect(defaults(DocProfile.memorial), contains('prb.memorial'));
    expect(defaults(DocProfile.operation), contains('prb.om'));
    expect(defaults(DocProfile.proposal), isNot(contains('prb.budget')), reason: 'the quote stays the price of the proposal');
    expect(defaults(DocProfile.proposal), isNot(contains('prb.lcc')));
    final permit = profileSections(DocProfile.permit).map((s) => s.id).toList();
    expect(permit.indexOf('prb.permit'), permit.indexOf('prd.sources') + 1, reason: 'right after the abstraction points');
    final proposal = profileSections(DocProfile.proposal).map((s) => s.id).toList();
    expect(proposal.indexOf('prb.budget'), proposal.indexOf('prd.quote') + 1, reason: 'right after the quote');
    // without a water supply there is no permit table to make
    final empty = Project();
    expect(documentSection('prb.permit')!.canBuild(contextOf(empty, null, DocProfile.permit)), isFalse);
  });

  test('a package holds each document with its sections as sub-headings', () {
    final (p, r) = orchard();
    final permit = buildDocumentPackage(contextOf(p, r, DocProfile.permit), const DocPackageOptions(profile: DocProfile.permit), compress: false);
    final n = permit.contents.firstWhere((e) => e.$2 == en('prb.permit.title')).$1;
    expect(permit.contents.firstWhere((e) => e.$2 == en('prb.permit.enterprise')).$1, '$n.1');
    expect(permit.contents.map((e) => e.$2), contains(en('prb.permit.monitoring')));
    final memorial = buildDocumentPackage(contextOf(p, r, DocProfile.memorial), const DocPackageOptions(profile: DocProfile.memorial), compress: false);
    final m = memorial.contents.firstWhere((e) => e.$2 == en('prb.mem.title')).$1;
    final titles = [
      for (final e in memorial.contents)
        if (e.$1.startsWith('$m.')) e.$2,
    ];
    expect(titles, containsAll([en('prb.mem.formulas'), en('prb.mem.references')]));
    expect(titles.first, en('prb.mem.objective'), reason: 'without its own identification: the package has one');
    final operation = buildDocumentPackage(contextOf(p, r, DocProfile.operation), const DocPackageOptions(profile: DocProfile.operation), compress: false);
    expect(operation.contents.map((e) => e.$2), containsAll([en('prb.om.title'), en('prb.om.flushing'), en('prb.om.schedule')]));
    // the budget and the life-cycle cost when the user ticks them
    final ctx = contextOf(p, r, DocProfile.proposal);
    final chosen = buildDocumentPackage(ctx, DocPackageOptions(profile: DocProfile.proposal, sections: [...defaultSectionIds(DocProfile.proposal, ctx), 'prb.budget', 'prb.lcc']), compress: false);
    final ids = chosen.sections.map((s) => s.id).toList();
    expect(ids.indexOf('prb.budget'), ids.indexOf('prd.quote') + 1);
    expect(ids, contains('prb.lcc'));
    expect(chosen.contents.map((e) => e.$2), containsAll([en('prb.bud.compositions'), en('prb.lcc.compare')]));
  });

  test('the blocks of a document: numbered lists, formulas, notes, levels and sections left out', () {
    const doc = TechDocument(
      key: 'x',
      title: 'X',
      sections: [
        TechSection('One', [
          TechBullets(['a', 'b'], numbered: true),
          TechFormula('q = k H^x', where: [('q', 'flow')], source: 'Keller'),
          TechNote('Mind it', warning: true),
          TechNote('By the way'),
        ], key: 'one'),
        TechSection('Two', [TechParagraph('text')], key: 'two'),
        TechSection('Two and a half', [TechParagraph('more')], level: 2, key: 'half'),
      ],
    );
    final blocks = techDocumentBlocks(doc, skip: const {'two'});
    expect(blocks.first, isA<DocHeading>().having((h) => h.text, 'text', 'One'));
    expect(blocks.whereType<DocHeading>().map((h) => h.text), ['One'], reason: '"Two" left out, "Two and a half" a bold line');
    final paragraphs = blocks.whereType<DocParagraph>().toList();
    expect(paragraphs.map((x) => x.text), ['1. a', '2. b', 'q = k H^x', 'Mind it', 'Two and a half', 'more']);
    expect(paragraphs.where((x) => x.bold).map((x) => x.text), ['q = k H^x', 'Mind it', 'Two and a half']);
    expect(blocks.whereType<DocFields>().single.fields, [('q', 'flow')]);
    expect(blocks.whereType<DocNote>().map((x) => x.text), ['Keller', 'By the way']);
  });
}
