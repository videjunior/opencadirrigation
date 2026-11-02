import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/fonts/pdf_fonts.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/io/sheet_canvas.dart';
import 'package:opencadirrigation/core/io/sheet_check.dart';
import 'package:opencadirrigation/core/io/title_block_sheet.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/title_block.dart';

final i18n = I18n('pt');

/// A small PNG [w] × [h] (a logo).
Uint8List png(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h, numChannels: 4)..clear(img.ColorRgba8(30, 136, 229, 255))));

/// The orchard example in Brazil with every field of the title block set.
Project professional() {
  final p = buildExample(ExampleId.orchard, i18n.call, lang: 'pt');
  p.meta
    ..client = 'Agropecuária Boa Vista Ltda.'
    ..site = 'Fazenda Santa Rita'
    ..georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
  p.meta.titleBlock
    ..company = 'Irriga Projetos'
    ..responsible = 'Ana Souza'
    ..council = 'CREA'
    ..registration = 'MG 1412345678'
    ..responsibilityRecord = 'MG20260123456'
    ..car = 'MG-3170107-0A1B2C3D'
    ..waterPermit = 'Portaria IGAM 1234/2026'
    ..municipality = 'Uberaba/MG'
    ..stage = ProjectStage.executive
    ..drawingNumber = 'IRR-2026-014'
    ..issueDate = '2026-11-02'
    ..revisions.add(TitleRevision(revision: '0', date: '2026-10-20', description: 'Emissão inicial', author: 'AS'))
    ..logo = png(240, 120)
    ..logoMime = 'image/png';
  return p;
}

void main() {
  group('the model', () {
    test('a project without a title block keeps its file as it was', () {
      final p = Project();
      expect(p.meta.titleBlock.isDefault, isTrue);
      expect(p.meta.toJson().containsKey('titleBlock'), isFalse);
      final old = Project().toJson();
      final again = Project.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).toJson();
      expect((again['meta'] as Map).containsKey('titleBlock'), isFalse);
    });

    test('every field goes to the file and back, the logo as Base64 shared by every copy', () {
      final p = professional();
      final j = p.meta.toJson();
      final tb = j['titleBlock'] as Map<String, dynamic>;
      expect(tb['council'], 'CREA');
      expect(tb['stage'], 'executive');
      expect(tb['logoMime'], 'image/png');
      expect(identical(tb['logo'], p.meta.toJson()['titleBlock']['logo']), isTrue, reason: 'one Base64 text for every undo step');
      final back = Project.fromJsonString(p.toJsonString()).meta.titleBlock;
      expect(back.company, 'Irriga Projetos');
      expect(back.responsible, 'Ana Souza');
      expect(back.registrationText, 'CREA MG 1412345678');
      expect(back.recordName, 'ART');
      expect(back.responsibilityRecord, 'MG20260123456');
      expect(back.car, 'MG-3170107-0A1B2C3D');
      expect(back.waterPermit, 'Portaria IGAM 1234/2026');
      expect(back.municipality, 'Uberaba/MG');
      expect(back.stage, ProjectStage.executive);
      expect(back.drawingNumber, 'IRR-2026-014');
      expect(back.issued, DateTime(2026, 11, 2));
      expect(back.revisions.single.author, 'AS');
      expect(back.logo, p.meta.titleBlock.logo);
      expect(back.isProfessional, isTrue);
    });

    test('fields of a newer version are kept; a damaged logo is dropped, the rest read', () {
      final p = Project.fromJson({
        'format': Project.formatName,
        'version': Project.formatVersion,
        'meta': {
          'name': 'X',
          'titleBlock': {
            'company': 'C',
            'future': 42,
            'logo': '***not base64***',
            'revisions': [
              {'rev': 'A', 'date': 'd', 'desc': 'x', 'extra': true},
            ],
          },
        },
      });
      final tb = p.meta.titleBlock;
      expect(tb.company, 'C');
      expect(tb.logo, isNull);
      expect(tb.toJson()['future'], 42);
      expect(tb.revisions.single.toJson()['extra'], isTrue);
    });

    test('council records, dates and the owner part', () {
      expect(responsibilityRecordOf('CREA-SP'), 'ART');
      expect(responsibilityRecordOf('cau'), 'RRT');
      expect(responsibilityRecordOf('CFTA'), 'TRT');
      expect(responsibilityRecordOf('CRT-04'), 'TRT');
      expect(responsibilityRecordOf('Colegio de Ingenieros'), '');
      expect(TitleBlock(council: 'Ordem').recordName, 'ART/RRT/TRT');
      expect(parseTitleDate('2026-02-28'), DateTime(2026, 2, 28));
      expect(parseTitleDate('02/11/2026'), DateTime(2026, 11, 2));
      expect(parseTitleDate('31/02/2026'), isNull, reason: 'no such day');
      expect(parseTitleDate('amanhã'), isNull);
      expect(titleDateText(DateTime(2026, 3, 7)), '2026-03-07');
      final p = professional();
      final owner = p.meta.titleBlock.ownerPart();
      expect((owner.company, owner.responsible, owner.registration, owner.car), ('Irriga Projetos', 'Ana Souza', 'MG 1412345678', ''));
      final fresh = TitleBlock(company: 'Mine')..adoptOwner(owner);
      expect((fresh.company, fresh.responsible, fresh.council), ('Mine', 'Ana Souza', 'CREA'), reason: 'only empty fields are filled');
      expect(fresh.logo, isNotNull);
    });

    test('a logo is checked, and a large picture scaled down to PNG', () {
      final small = png(100, 50);
      expect(normalizeLogo(small)!.$2, 'image/png');
      expect(identical(normalizeLogo(small)!.$1, small), isTrue);
      final big = normalizeLogo(png(2000, 1000))!;
      expect(PdfDocumentSize.of(big.$1), (512, 256));
      expect(normalizeLogo(Uint8List.fromList(utf8.encode('not a picture'))), isNull);
      final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 32)));
      expect(normalizeLogo(jpg)!.$2, 'image/jpeg');
    });

    test('the share link leaves the logo out', () {
      final p = professional();
      final shared = jsonDecode(shareableProjectJson(p.toJson())) as Map<String, dynamic>;
      final tb = (shared['meta'] as Map)['titleBlock'] as Map;
      expect(tb.containsKey('logo'), isFalse);
      expect(tb['responsible'], 'Ana Souza');
    });
  });

  group('the sheets', () {
    PdfSheetBuilder builder(Project p) => PdfSheetBuilder(
      project: p,
      results: Designer(p, label: (k) => i18n(k)).designAll(),
      t: i18n.call,
      units: p.params.units,
    );

    test('the professional title block prints every field, the logo and SIRGAS 2000', () {
      final p = professional();
      final b = builder(p);
      final sheet = b.recordSheet(const SheetOptions());
      final texts = sheet.texts.toList();
      const fields = ['Agropecuária Boa Vista Ltda.', 'Fazenda Santa Rita', 'Uberaba/MG', 'MG-3170107-0A1B2C3D', 'Portaria IGAM 1234/2026', 'Ana Souza'];
      for (final s in [...fields, 'CREA MG 1412345678', 'MG20260123456', 'IRR-2026-014', '02/11/2026', 'Irriga Projetos']) {
        expect(texts, contains(s));
      }
      expect(texts, contains(i18n('prd.stage.executive')));
      expect(texts, contains('ART'), reason: 'the caption of the record names the council\'s record');
      expect(texts.any((s) => s.startsWith('SIRGAS 2000 / UTM 23S')), isTrue);
      expect(texts.any((s) => s.contains('EPSG:31983')), isTrue);
      expect(sheet.images, isNotEmpty, reason: 'the logo');
      expect(b.titleMm, proTitleBlockMm);
      // nothing of the title block overlaps, nothing leaves the frame
      final review = SheetReview(sheet, fonts: PdfFonts.shared);
      final own = review.overlaps().where((o) => o.texts.every((x) => x.region < 0));
      expect(own, isEmpty, reason: [for (final o in own) o.texts.map((x) => x.text).join(' / ')].join('; '));
      final frame = Bounds(10, 10, sheet.width / 2.834645669 - 10, sheet.height / 2.834645669 - 10);
      expect(review.beyond(frame, tolMm: 0.5), isEmpty);
      // the PDF itself
      final pdf = b.buildSheet(const SheetOptions());
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    });

    test('a set of sheets numbers them with the drawing number; details take the same title block', () {
      final p = professional();
      final b = builder(p);
      const o = SheetOptions(split: SheetSplit.zones, details: [DetailKind.trench]);
      final count = b.sheetCount(o);
      expect(count, greaterThan(2));
      final second = b.recordSheet(o, index: 1).texts.toList();
      expect(second, contains('IRR-2026-014-02'));
      expect(second.any((s) => s.startsWith('2/$count')), isTrue, reason: 'the sheet of the set under the drawing number');
      final details = b.recordSheet(o, index: count - 1).texts.toList();
      expect(details, contains('IRR-2026-014-${count.toString().padLeft(2, '0')}'));
    });

    test('without any of it the sheet keeps the plain title block, with the datum of the site', () {
      final p = buildExample(ExampleId.orchard, i18n.call, lang: 'pt')..meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
      final b = builder(p);
      expect(b.titleMm, SheetLayout.titleBlockMm);
      final texts = b.recordSheet(const SheetOptions()).texts.toList();
      expect(texts, contains('OpenCADIrrigation'));
      expect(texts, contains('SIRGAS 2000 / UTM 23S'));
      expect(texts, isNot(contains('WGS84 / UTM 23S')));
    });

    test('the revision table joins the title block\'s revisions and the clouds', () {
      final p = professional();
      p.entities.add(RevisionCloudEntity(id: p.newId(), points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10)], revision: 'A', date: '2026-10-28', description: 'Válvula deslocada'));
      final revs = sheetRevisions(p);
      expect([for (final r in revs) r.revision], ['0', 'A']);
      expect(revs.first.author, 'AS');
      final texts = builder(p).recordSheet(const SheetOptions()).texts.join(' ');
      expect(texts, allOf(contains('Emissão inicial'), contains('Válvula deslocada')));
    });

    test('a recorded professional sheet replays to the same page', () {
      final p = professional();
      final b = builder(p);
      final rec = b.recordSheet(const SheetOptions());
      final page = SheetRecorder(rec.width, rec.height);
      rec.replay(page);
      expect(page.sheet.texts.toList(), rec.texts.toList());
    });
  });
}

/// Width and height of a PNG from its header.
abstract final class PdfDocumentSize {
  static (int, int) of(Uint8List b) {
    int u32(int p) => (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
    return (u32(16), u32(20));
  }
}
