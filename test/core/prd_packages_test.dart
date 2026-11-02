import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/doc_package.dart';
import 'package:opencadirrigation/core/io/doc_pdf.dart';
import 'package:opencadirrigation/core/io/doc_sections.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/title_block.dart';

final en = I18n('en');

/// The orchard example in Brazil, designed, with its title block.
(Project, DesignResults) orchard() {
  final p = buildExample(ExampleId.orchard, en.call, lang: 'en')..meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
  p.meta.client = 'Boa Vista Farms';
  p.meta.titleBlock
    ..responsible = 'Ana Souza'
    ..council = 'CREA'
    ..registration = 'MG 1412345678'
    ..responsibilityRecord = 'MG20260123456'
    ..municipality = 'Uberaba/MG';
  return (p, Designer(p, label: (k) => en(k)).designAll());
}

DocContext contextOf(Project p, DesignResults? r, DocProfile profile) =>
    DocContext(project: p, results: r, labels: ReportLabels(t: en.call, has: en.has, warning: en.warning), profile: profile, date: DateTime(2026, 11, 2));

int pages(List<int> pdf) => int.parse(RegExp(r'/Count (\d+)').firstMatch(latin1.decode(pdf))!.group(1)!);

/// The document packages by reader (1.6.0 PRD, PRD-04).
void main() {
  test('every section is unique, named in pt, en and es, and placed in some package', () {
    final ids = <String>{};
    for (final s in documentSections()) {
      expect(ids.add(s.id), isTrue, reason: 'one id each: ${s.id}');
      expect(s.profiles, isNotEmpty, reason: s.id);
      for (final lang in const ['pt', 'en', 'es']) {
        expect(I18n(lang).has(s.titleKey), isTrue, reason: '${s.titleKey} $lang');
      }
    }
    for (final p in DocProfile.values) {
      expect(I18n('pt').has('prd.doc.profile.${p.name}'), isTrue);
      final list = profileSections(p);
      expect(list.first.id, 'prd.identification', reason: '${p.name} starts with the identification');
      expect(list.last.id, 'prd.signature', reason: '${p.name} ends with the signature');
    }
  });

  test('each package: a cover, the contents, its sections in order and the signature', () {
    final (p, r) = orchard();
    for (final profile in DocProfile.values) {
      final ctx = contextOf(p, r, profile);
      final pack = buildDocumentPackage(ctx, DocPackageOptions(profile: profile), compress: false);
      final raw = latin1.decode(pack.bytes);
      expect(raw, startsWith('%PDF-'));
      expect(pages(pack.bytes), pack.pageCount);
      expect(pack.pageCount, greaterThanOrEqualTo(4), reason: profile.name);
      expect(pack.sections.map((s) => s.id), [
        for (final s in profileSections(profile))
          if (defaultSectionIds(profile, ctx).contains(s.id)) s.id,
      ]);
      // the contents: the sections numbered in order, after the cover and the contents page
      final level1 = [for (final e in pack.contents) if (!e.$1.contains('.')) e];
      expect([for (final e in level1) e.$1], [for (var i = 1; i <= level1.length; i++) '$i']);
      expect(level1.first.$3, greaterThanOrEqualTo(3));
      for (var i = 1; i < pack.contents.length; i++) {
        expect(pack.contents[i].$3, greaterThanOrEqualTo(pack.contents[i - 1].$3), reason: 'pages in order');
      }
      expect(level1.last.$2, en('prd.doc.sec.signature'));
      expect(raw, contains('(Ana Souza)'), reason: 'the technical lead on the cover and the signature');
      expect(raw, contains('(${en('prd.doc.contents')})'));
      expect(raw, contains('(${en('prd.doc.profile.${profile.name}')})'), reason: 'the title on the cover');
    }
  });

  test('the proposal is for the client; the permit carries the abstraction points in SIRGAS 2000', () {
    final (p, r) = orchard();
    final proposal = buildDocumentPackage(contextOf(p, r, DocProfile.proposal), const DocPackageOptions(profile: DocProfile.proposal, recipient: 'Mr Silva'), compress: false);
    final ids = proposal.sections.map((s) => s.id).toList();
    expect(ids, containsAll(['prd.summary', 'prd.bom', 'prd.quote', 'prd.sheets', 'prd.signature']));
    expect(ids, isNot(contains('prd.hydraulics')), reason: 'no hydraulic tables for the client');
    final raw = latin1.decode(proposal.bytes);
    expect(raw, contains('(Mr Silva)'));
    expect(raw, contains('(${en('prd.doc.acceptance')})'), reason: 'the client signs the proposal');
    final ctx = contextOf(p, r, DocProfile.permit);
    final sources = sourcesTable(ctx)!;
    expect(sources.title, contains('SIRGAS 2000 / UTM 23S'));
    expect(sources.rows.first.join(' '), contains('"S'), reason: 'latitude in degrees, minutes and seconds');
    final permit = buildDocumentPackage(ctx, const DocPackageOptions(profile: DocProfile.permit), compress: false);
    expect(permit.sections.map((s) => s.id), contains('prd.sources'));
    expect(docSheetOptions(ctx).grid, SheetGrid.both, reason: 'the plans of a permit carry the coordinate grid');
  });

  test('without results the sections that need them are left out; chosen sections only', () {
    final (p, _) = orchard();
    final ctx = contextOf(p, null, DocProfile.memorial);
    final hydraulics = documentSection('prd.hydraulics')!;
    expect(hydraulics.canBuild(ctx), isFalse);
    expect(defaultSectionIds(DocProfile.memorial, ctx), isNot(contains('prd.hydraulics')));
    final pack = buildDocumentPackage(ctx, const DocPackageOptions(profile: DocProfile.memorial, sections: ['prd.identification', 'prd.hydraulics', 'prd.signature']));
    expect(pack.sections.map((s) => s.id), ['prd.identification', 'prd.signature']);
  });

  test('another part of the program adds its sections', () {
    final (p, r) = orchard();
    registerDocumentSection(
      DocSection(
        id: 'test.memorial',
        titleKey: 'prd.doc.sec.criteria',
        profiles: const {DocProfile.memorial: 150, DocProfile.permit: 210},
        build: (c) => const [DocHeading('Descriptive memorial'), DocParagraph('The system irrigates the orchard.'), DocBullets(['first', 'second'])],
      ),
    );
    addTearDown(() => unregisterDocumentSection('test.memorial'));
    final ids = profileSections(DocProfile.memorial).map((s) => s.id).toList();
    expect(ids.indexOf('test.memorial'), ids.indexOf('prd.identification') + 1, reason: 'placed by its order');
    final pack = buildDocumentPackage(contextOf(p, r, DocProfile.memorial), const DocPackageOptions(profile: DocProfile.memorial), compress: false);
    expect(pack.contents.map((e) => e.$2), contains('Descriptive memorial'));
    expect(pack.contents.firstWhere((e) => e.$2 == 'Descriptive memorial').$1, '2.1');
    expect(latin1.decode(pack.bytes), contains('(The system irrigates the orchard.)'));
  });

  test('the cover shows the logo and the company', () {
    final (p, r) = orchard();
    p.meta.titleBlock.company = 'Irriga Projetos';
    final ctx = contextOf(p, r, DocProfile.proposal);
    final raw = latin1.decode(buildDocumentPackage(ctx, const DocPackageOptions(profile: DocProfile.proposal), compress: false).bytes);
    expect(raw, contains('(Irriga Projetos)'));
    expect(TitleBlock().isProfessional, isFalse);
    expect(p.entities.whereType<ControlValveEntity>(), isNotEmpty);
  });
}
