import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/svg.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:xml/xml.dart';

/// Objects of an uncompressed PDF, by number.
Map<int, String> pdfObjects(String pdf) => {for (final m in RegExp(r'(\d+) 0 obj\n(.*?)\nendobj', dotAll: true).allMatches(pdf)) int.parse(m.group(1)!): m.group(2)!};

Uint8List streamBytes(String obj) {
  final start = obj.indexOf('stream\n') + 7;
  final end = obj.lastIndexOf('\nendstream');
  return Uint8List.fromList(latin1.encode(obj.substring(start, end)));
}

/// A PNG of [w] × [h] pixels: red to the right, green downwards, alpha
/// growing to the right when [alpha].
Uint8List png(int w, int h, {bool alpha = true}) {
  final im = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha) {
        im.setPixelRgba(x, y, x * 255 ~/ w, y * 255 ~/ h, 40, x * 255 ~/ w);
      } else {
        im.setPixelRgb(x, y, x * 255 ~/ w, y * 255 ~/ h, 40);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

Uint8List jpeg(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, (x ~/ 8) % 2 * 255, 128, (y ~/ 8) % 2 * 255);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

ProjectExporter exporter(Project p) => ProjectExporter(project: p, results: null, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));

void main() {
  group('PDF images', () {
    test('a PNG with alpha becomes an RGB image with a soft mask', () {
      final doc = PdfDocument();
      final page = doc.addPage(widthPt: 200, heightPt: 200);
      final im = doc.image(png(12, 8))!;
      expect((im.width, im.height), (12, 8));
      page.image(im, (10, 20), (110, 20), (10, 80));
      final text = latin1.decode(doc.build(compress: false));
      final objs = pdfObjects(text);
      final xobj = objs.values.firstWhere((o) => o.contains('/Subtype /Image') && o.contains('/SMask'));
      expect(xobj, contains('/Width 12 /Height 8 /ColorSpace /DeviceRGB /BitsPerComponent 8'));
      expect(xobj, contains('/Filter /FlateDecode'));
      final rgb = ZLibDecoder().decodeBytes(streamBytes(xobj));
      expect(rgb.length, 12 * 8 * 3);
      expect(rgb.sublist(0, 3), [0, 0, 40]);
      final maskId = int.parse(RegExp(r'/SMask (\d+) 0 R').firstMatch(xobj)!.group(1)!);
      expect(objs[maskId], contains('/ColorSpace /DeviceGray'));
      final alpha = ZLibDecoder().decodeBytes(streamBytes(objs[maskId]!));
      expect(alpha.length, 12 * 8);
      expect(alpha[11], greaterThan(alpha[0]));
      // placed by the unit square → page matrix, inside its own graphics state
      expect(text, contains('q\n100 0 0 60 10 20 cm /Im1 Do\nQ'));
      expect(text, contains('/XObject << /Im1 '));
      expect(text, contains('/ImageC'));
    });

    test('JPEG data is passed through with DCTDecode; opaque PNGs have no mask', () {
      final doc = PdfDocument();
      final page = doc.addPage(widthPt: 200, heightPt: 200);
      final j = jpeg(64, 32);
      final a = doc.image(j)!;
      final b = doc.image(png(10, 10, alpha: false))!;
      page.image(a, (0, 0), (64, 0), (0, 32));
      page.image(b, (0, 50), (10, 50), (0, 60));
      final objs = pdfObjects(latin1.decode(doc.build(compress: false)));
      final dct = objs.values.firstWhere((o) => o.contains('/DCTDecode'));
      expect(dct, contains('/Width 64 /Height 32'));
      expect(streamBytes(dct), j);
      expect(objs.values.where((o) => o.contains('/SMask')), isEmpty);
      expect(PdfDocument.jpegInfo(j), (64, 32, 3));
      expect(PdfDocument.jpegInfo(png(2, 2)), isNull);
    });

    test('large images are downsampled to the size they are printed at', () {
      final doc = PdfDocument();
      final big = doc.image(png(400, 200), maxWidthPx: 100, maxHeightPx: 100)!;
      expect((big.width, big.height), (100, 50));
      final bigJpeg = doc.image(jpeg(400, 400), maxWidthPx: 120)!;
      expect(bigJpeg.filter, 'DCTDecode');
      expect((bigJpeg.width, bigJpeg.height), (120, 120));
      final small = doc.image(jpeg(40, 40), maxWidthPx: 120)!;
      expect((small.width, small.height), (40, 40));
    });

    test('gray and 16-bit images become 8-bit RGB samples', () {
      final gray = img.Image(width: 3, height: 2, numChannels: 1);
      img.fill(gray, color: img.ColorRgb8(200, 200, 200));
      final deep = img.Image(width: 3, height: 2, format: img.Format.uint16);
      for (final p in deep) {
        p.setRgb(65535, 0, 32768);
      }
      for (final (bytes, rgb) in [(Uint8List.fromList(img.encodePng(gray)), [200, 200, 200]), (Uint8List.fromList(img.encodePng(deep)), [255, 0, 128])]) {
        final doc = PdfDocument();
        final page = doc.addPage(widthPt: 50, heightPt: 50);
        final im = doc.image(bytes)!;
        expect((im.width, im.height, im.alpha), (3, 2, null));
        page.image(im, (0, 0), (30, 0), (0, 20));
        final xobj = pdfObjects(latin1.decode(doc.build(compress: false))).values.firstWhere((o) => o.contains('/Subtype /Image'));
        final samples = ZLibDecoder().decodeBytes(streamBytes(xobj));
        expect(samples.length, 3 * 2 * 3);
        expect(samples.sublist(0, 3), rgb);
      }
    });

    test('opacity uses an ExtGState; the same bytes make one image; bad data is skipped', () {
      final doc = PdfDocument();
      final page = doc.addPage(widthPt: 100, heightPt: 100);
      final bytes = png(4, 4);
      final a = doc.image(bytes)!;
      expect(identical(doc.image(bytes), a), isTrue);
      expect(doc.image(Uint8List.fromList(utf8.encode('no image here'))), isNull);
      page.image(a, (0, 0), (10, 0), (0, 10), opacity: 0.4);
      final text = latin1.decode(doc.build(compress: false));
      expect(RegExp(r'/Subtype /Image').allMatches(text).length, 2, reason: 'the image and its mask');
      expect(text, contains('/GS1 gs'));
      expect(text, contains('<< /Type /ExtGState /ca 0.4 /CA 0.4 >>'));
    });
  });

  group('images and rasters on sheets', () {
    Project withImage({Uint8List? data}) {
      final p = Project();
      p.entities.addAll([
        LineEntity(id: 'l', a: const Pt(0, 0), b: const Pt(60, 30)),
        ImageEntity(id: 'img', origin: const Pt(5, 5), width: 40, height: 20, rotationDeg: 10, opacity: 0.6, data: data, mime: 'image/png', source: 'photo.png'),
      ]);
      return p;
    }

    test('the plot scene carries image entities with data as images', () {
      final p = withImage(data: png(20, 10));
      final scene = buildPlotScene(p, unitsPerMm: 0.5);
      final im = scene.items.whereType<PlotImage>().single;
      expect(im.layer, Layers.images);
      expect(im.opacity, 0.6);
      expect(im.corners, (p.entities[1] as ImageEntity).corners);
      expect(scene.bounds.contains(im.corners[2]), isTrue);
      // without data the frame is drawn, as before
      final frame = buildPlotScene(withImage(), unitsPerMm: 0.5);
      expect(frame.items.whereType<PlotImage>(), isEmpty);
      expect(frame.items.whereType<PlotPath>().where((x) => x.layer == Layers.images && x.closed), hasLength(1));
      // rasters and attribution pass through and do not change the extent
      final raster = PlotRaster.bounds(png(8, 8), const Bounds(-500, -500, 500, 500));
      final withRaster = buildPlotScene(p, unitsPerMm: 0.5, rasters: [raster], attribution: '© OpenStreetMap contributors');
      expect(withRaster.rasters, [raster]);
      expect(withRaster.attribution, '© OpenStreetMap contributors');
      List<double> box(Bounds b) => [b.minX, b.minY, b.maxX, b.maxY];
      expect(box(withRaster.bounds), box(scene.bounds));
    });

    test('PDF sheet: image entity, background raster and attribution', () {
      final p = withImage(data: png(20, 10));
      final raster = PlotRaster.bounds(jpeg(32, 32), p.bounds.inflate(50), opacity: 0.8);
      const credit = '© OpenStreetMap contributors';
      final o = SheetOptions(page: PageSize.a4, rasters: [raster], attribution: credit);
      final pdf = exporter(p).sheetBuilder().buildSheet(o);
      final text = latin1.decode(pdf);
      expect(text, startsWith('%PDF-1.4'));
      expect(RegExp(r'/Subtype /Image').allMatches(text).length, 3, reason: 'raster (JPEG), image and its soft mask');
      expect(text, contains('/DCTDecode'));
      expect(text, contains('/ca 0.8'), reason: 'raster opacity');
      expect(text, contains('/ca 0.6'), reason: 'image opacity');
      expect(o.copyWith(attribution: 'x').rasters, [raster]);
      expect(o.copyWith().attribution, credit);
    });

    test('SVG: images as data URIs with a transform, rasters underneath, attribution', () {
      final p = withImage(data: png(20, 10));
      final raster = PlotRaster.bounds(png(8, 8, alpha: false), p.bounds.inflate(10));
      final svg = exporter(p).svg(SheetOptions(rasters: [raster], attribution: '© OpenStreetMap contributors'));
      final doc = XmlDocument.parse(svg);
      final images = doc.findAllElements('image').toList();
      expect(images, hasLength(2));
      expect(images.first.parentElement!.getAttribute('id'), 'background');
      for (final im in images) {
        expect(im.getAttribute('xlink:href'), startsWith('data:image/png;base64,'));
        expect(im.getAttribute('transform'), startsWith('matrix('));
        expect(im.getAttribute('preserveAspectRatio'), 'none');
      }
      expect(images.last.getAttribute('opacity'), '0.6');
      expect(svg, contains('xmlns:xlink="http://www.w3.org/1999/xlink"'));
      expect(doc.findAllElements('text').any((t) => t.innerText == '© OpenStreetMap contributors'), isTrue);
      // the image group comes before the drawing layers
      final groups = doc.rootElement.findElements('g').map((g) => g.getAttribute('id')).toList();
      expect(groups.indexOf(Layers.images), lessThan(groups.indexOf(Layers.drawing)));
      // a large image is downsampled for its printed size
      final huge = withImage(data: png(3000, 1500));
      final svgHuge = SvgWriter.write(buildPlotScene(huge, unitsPerMm: 0.5));
      final uri = XmlDocument.parse(svgHuge).findAllElements('image').single.getAttribute('xlink:href')!;
      final decoded = img.decodePng(base64Decode(uri.substring(uri.indexOf(',') + 1)))!;
      expect(decoded.width, lessThan(3000));
    });
  });
}
