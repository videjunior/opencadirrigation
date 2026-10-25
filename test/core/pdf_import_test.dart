import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_import.dart';
import 'package:opencadirrigation/core/io/pdf_reader.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

PdfPageContent pageOf({List<PdfPathItem> paths = const [], List<PdfTextItem> texts = const [], List<PdfImageItem> images = const [], double w = 595, double h = 842}) => PdfPageContent(
  page: PdfPageInfo(index: 0, width: w, height: h),
  paths: paths,
  texts: texts,
  images: images,
  layers: const [],
  warnings: const [],
);

PdfImportResult convert(PdfPageContent page, [PdfImportOptions o = const PdfImportOptions()]) {
  var n = 0;
  return pdfPageEntities(page, o, () => 'e${++n}');
}

Matcher near(Pt p, [double tol = 1e-9]) => predicate<Pt>((q) => q.distanceTo(p) <= tol, 'within $tol of $p');

/// A 2 × 2 PNG: red over green (top row red).
Uint8List redOverGreen() {
  final im = img.Image(width: 2, height: 2);
  for (var x = 0; x < 2; x++) {
    im.setPixelRgb(x, 0, 255, 0, 0);
    im.setPixelRgb(x, 1, 0, 255, 0);
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  test('paper scale, insertion point and rotation', () {
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(72, 0)]),
      ],
    );
    // one inch on paper is 2.54 m at 1:100
    final a = convert(page).entities.single as LineEntity;
    expect(a.a, near(Pt.zero));
    expect(a.b, near(const Pt(2.54, 0), 1e-9));
    final b = convert(page, PdfImportOptions(metresPerUnit: PdfImportOptions.atScale(500), origin: const Pt(100, 200), rotationDeg: 90)).entities.single as LineEntity;
    expect(b.a, near(const Pt(100, 200)));
    expect(b.b, near(const Pt(100, 212.7), 1e-9));
    // a plan in metres: one unit, one metre
    final c = convert(page, const PdfImportOptions(metresPerUnit: 1)).entities.single as LineEntity;
    expect(c.b, near(const Pt(72, 0)));
  });

  test('lines, polylines and outlines; paper-white masks and page backgrounds are left out', () {
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]),
        PdfPathItem(points: [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)], closed: true),
        PdfPathItem(points: [const Pt(20, 20), const Pt(40, 20), const Pt(40, 30)], closed: true, stroked: false, filled: true, fillRgb: 0x000000),
        PdfPathItem(points: [const Pt(50, 50), const Pt(90, 50), const Pt(90, 60), const Pt(50, 60)], closed: true, stroked: false, filled: true, fillRgb: 0xFFFFFF),
        PdfPathItem(points: [Pt.zero, const Pt(595, 0), const Pt(595, 842), const Pt(0, 842)], closed: true, stroked: false, filled: true, fillRgb: 0xEEEEDD),
        PdfPathItem(points: [Pt.zero, const Pt(595, 0), const Pt(595, 842), const Pt(0, 842)], closed: true, fillRgb: 0xFFFFFF),
      ],
    );
    final r = convert(page, const PdfImportOptions(metresPerUnit: 1));
    expect(
      [for (final e in r.entities) (e.runtimeType, e is PolylineEntity && e.closed)],
      [
        (PolylineEntity, false),
        (PolylineEntity, true),
        (PolylineEntity, true),
        (PolylineEntity, true), // the sheet frame: stroked, kept
      ],
    );
    expect((r.lines, r.polylines, r.texts, r.images), (0, 4, 0, 0));
  });

  test('layers: one for the import, one per PDF layer, one per colour; colours that show on the dark canvas', () {
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(1, 0)], layer: 'Paredes'),
        PdfPathItem(points: [Pt.zero, const Pt(0, 1)]),
        PdfPathItem(points: [Pt.zero, const Pt(1, 1)], strokeRgb: 0xFF0000, layer: 'Paredes'),
      ],
      texts: [PdfTextItem(text: 'Sala', origin: Pt.zero, height: 10)],
    );
    final plain = convert(page, const PdfImportOptions(layer: 'PDF-casa'));
    expect([for (final e in plain.entities) e.layer], ['PDF-casa-Paredes', 'PDF-casa', 'PDF-casa-Paredes', 'PDF-casa']);
    expect({for (final l in plain.layers) l.name: l.color}, {'PDF-casa-Paredes': 0xFFD9D9D9, 'PDF-casa': 0xFFD9D9D9});
    final flat = convert(page, const PdfImportOptions(layer: 'PDF-casa', useLayers: false));
    expect(flat.entities.map((e) => e.layer).toSet(), {'PDF-casa'});
    final colours = convert(page, const PdfImportOptions(layer: 'PDF-casa', byColour: true));
    expect([for (final e in colours.entities) e.layer], ['PDF-casa-Paredes-000000', 'PDF-casa-000000', 'PDF-casa-Paredes-FF0000', 'PDF-casa-000000']);
    final red = colours.layers.firstWhere((l) => l.name.endsWith('FF0000')).color;
    expect((red >> 16) & 0xFF, 255);
    expect((red >> 8) & 0xFF, lessThan(0x80));
  });

  test('layers that are off come in only on request', () {
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(1, 0)], layer: 'Cotas', hidden: true),
      ],
      texts: [PdfTextItem(text: '3,20', origin: Pt.zero, height: 5, layer: 'Cotas', hidden: true)],
    );
    expect(convert(page).entities, isEmpty);
    expect(convert(page, const PdfImportOptions(hiddenLayers: true)).entities, hasLength(2));
  });

  test('what to import: lines, texts, images', () {
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(1, 0)]),
      ],
      texts: [PdfTextItem(text: 'A', origin: Pt.zero, height: 5)],
      images: [
        PdfImageItem(corners: const [Pt.zero, Pt(10, 0), Pt(10, 10), Pt(0, 10)], widthPx: 2, heightPx: 2, bytes: redOverGreen()),
      ],
    );
    expect(convert(page).entities, hasLength(3));
    expect(convert(page, const PdfImportOptions(vectors: false)).entities.whereType<LineEntity>(), isEmpty);
    expect(convert(page, const PdfImportOptions(texts: false)).entities.whereType<TextEntity>(), isEmpty);
    expect(convert(page, const PdfImportOptions(images: false)).entities.whereType<ImageEntity>(), isEmpty);
  });

  test('texts keep their height and angle, scaled and turned with the plan', () {
    final page = pageOf(
      texts: [PdfTextItem(text: 'Lote 12', origin: const Pt(100, 50), height: 12, angleDeg: 30)],
    );
    final t = convert(page, const PdfImportOptions(metresPerUnit: 0.5, origin: Pt(10, 0), rotationDeg: 340)).entities.single as TextEntity;
    expect(t.text, 'Lote 12');
    expect(t.height, 6);
    expect(t.rotationDeg, closeTo(10, 1e-9));
    expect(t.position, near(const Pt(10, 0) + const Pt(50, 25).rotate(340 * 3.141592653589793 / 180), 1e-9));
  });

  test('images keep their corners; one drawn mirrored is flipped to read the right way', () {
    final png = redOverGreen();
    final page = pageOf(
      images: [
        PdfImageItem(corners: const [Pt.zero, Pt(100, 0), Pt(100, 50), Pt(0, 50)], widthPx: 2, heightPx: 2, bytes: png),
        // the raster's bottom row at the top of the frame
        PdfImageItem(corners: const [Pt(200, 50), Pt(300, 50), Pt(300, 0), Pt(200, 0)], widthPx: 2, heightPx: 2, bytes: png),
      ],
    );
    final r = convert(page, const PdfImportOptions(metresPerUnit: 0.1));
    final a = r.entities[0] as ImageEntity, b = r.entities[1] as ImageEntity;
    expect(a.origin, near(Pt.zero));
    expect([a.width, a.height, a.rotationDeg], [closeTo(10, 1e-9), closeTo(5, 1e-9), closeTo(0, 1e-9)]);
    expect(a.data, png);
    expect(b.origin, near(const Pt(20, 0)));
    expect([b.width, b.height, b.rotationDeg], [closeTo(10, 1e-9), closeTo(5, 1e-9), closeTo(0, 1e-9)]);
    final flipped = img.decodePng(b.data!)!;
    expect(flipped.getPixel(0, 0).g, 255, reason: 'green on top once flipped');
    expect(flipped.getPixel(0, 1).r, 255);
    // a turned image: its rotation follows the bottom edge
    final turned =
        convert(
              pageOf(
                images: [
                  PdfImageItem(corners: const [Pt(10, 0), Pt(10, 20), Pt(0, 20), Pt(0, 0)], widthPx: 2, heightPx: 2, bytes: png),
                ],
              ),
              const PdfImportOptions(metresPerUnit: 1),
            ).entities.single
            as ImageEntity;
    expect([turned.width, turned.height, turned.rotationDeg], [closeTo(20, 1e-9), closeTo(10, 1e-9), closeTo(90, 1e-9)]);
    expect(turned.corners[2], near(const Pt(0, 20), 1e-9));
    expect(turned.corners[3], near(Pt.zero, 1e-9));
  });

  test('a PDF of the app imported into a project: one call adds the entities and the layers it lacks', () {
    final doc = PdfDocument();
    final p = doc.addPage(widthPt: 400, heightPt: 300);
    p.path([(10, 10), (110, 10), (110, 60)]);
    p.rect(200, 100, 50, 50);
    p.text(20, 250, 'Planta de irrigação — ESCALA 1:250', size: 9);
    final content = PdfReader.open(doc.build()).readPage(0);
    expect(pdfScaleOnSheet(content), 250);
    final project = Project();
    final layers = project.layers.length;
    final o = PdfImportOptions(metresPerUnit: PdfImportOptions.atScale(250), layer: pdfLayerName('planta baixa.pdf'));
    final r = addPdfPage(project, content, o);
    expect(r.entities, hasLength(3));
    expect(project.entities, hasLength(3));
    expect(project.layers.length, layers + 1);
    expect(project.findLayer('PDF-planta baixa'), isNotNull);
    final poly = project.entities.whereType<PolylineEntity>().firstWhere((e) => !e.closed);
    final k = 250 * 0.0254 / 72;
    expect(poly.points, [near(const Pt(10, 10) * k, 1e-9), near(const Pt(110, 10) * k, 1e-9), near(const Pt(110, 60) * k, 1e-9)]);
    expect(project.entities.whereType<TextEntity>().single.height, closeTo(9 * k, 1e-12));
    // imported again: no second layer
    addPdfPage(project, content, o);
    expect(project.layers.length, layers + 1);
    expect(project.entities, hasLength(6));
  });

  test('images go under the drawing', () {
    final project = Project()..entities.add(LineEntity(id: 'x', a: Pt.zero, b: const Pt(1, 1)));
    final page = pageOf(
      paths: [
        PdfPathItem(points: [Pt.zero, const Pt(1, 0)]),
      ],
      images: [
        PdfImageItem(corners: const [Pt.zero, Pt(10, 0), Pt(10, 10), Pt(0, 10)], widthPx: 2, heightPx: 2, bytes: redOverGreen()),
      ],
    );
    addPdfPage(project, page, const PdfImportOptions());
    expect(project.entities.first, isA<ImageEntity>());
    expect(project.entities[1].id, 'x');
    expect(project.entities.last, isA<LineEntity>());
  });

  test('the scale written on the sheet', () {
    PdfPageContent withTexts(List<String> s) => pageOf(
      texts: [for (final t in s) PdfTextItem(text: t, origin: Pt.zero, height: 3)],
    );
    expect(pdfScaleOnSheet(withTexts(['PLANTA BAIXA', 'ESCALA 1:500'])), 500);
    expect(pdfScaleOnSheet(withTexts(['Esc. 1/200'])), 200);
    expect(pdfScaleOnSheet(withTexts(['1:250'])), 250);
    expect(pdfScaleOnSheet(withTexts(['Scale 1 : 1000', 'Escala 1:1000', 'Detail scale 1:50', 'Situação 1:2000'])), 1000);
    expect(pdfScaleOnSheet(withTexts(['Data 01/12/2024', 'Início 14:30', 'Folha 1/20', 'Lote 1:30 m'])), isNull);
    expect(pdfScaleOnSheet(withTexts([])), isNull);
  });

  test('the layer named after the file', () {
    expect(pdfLayerName('Planta baixa.pdf'), 'PDF-Planta baixa');
    expect(pdfLayerName('/home/u/levantamento:topo.PDF'), 'PDF-levantamento_topo');
    expect(pdfLayerName(''), 'PDF');
    expect(pdfLayerName('${'x' * 80}.pdf').length, lessThanOrEqualTo(44));
  });

  test('plan colours on the dark canvas', () {
    expect(pdfCanvasColour(0x000000), 0xFFD9D9D9);
    expect(pdfCanvasColour(0xFFFFFF), 0xFF666666);
    expect(pdfCanvasColour(0x808080), 0xFF9F9F9F);
    final navy = pdfCanvasColour(0x000080);
    expect(pdfLuminance(navy & 0xFFFFFF), greaterThanOrEqualTo(0.35));
    expect(navy & 0xFF, greaterThan((navy >> 16) & 0xFF), reason: 'still blue');
    expect(pdfCanvasColour(0xFF0000), 0xFFFF3333);
  });
}
