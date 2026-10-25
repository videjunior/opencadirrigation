import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_reader.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// An object of a hand-made PDF: its body and, for a stream, its data
/// (the /Length is added).
class Obj {
  Obj(this.body, [this.data]);
  final String body;
  final List<int>? data;
}

/// A PDF of [objects] (numbered from 1) with a classic cross-reference
/// table. [prefix] goes before the header (offsets count from the header).
Uint8List pdf(List<Obj> objects, {String trailer = '/Root 1 0 R', List<int> prefix = const []}) {
  final out = BytesBuilder()..add(prefix);
  final start = out.length;
  out.add(latin1.encode('%PDF-1.7\n%\xE2\xE3\xCF\xD3\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length - start);
    out.add(objectBytes(i + 1, objects[i]));
  }
  final xref = out.length - start;
  final b = StringBuffer('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write('trailer\n<< /Size ${objects.length + 1} $trailer >>\nstartxref\n$xref\n%%EOF\n');
  out.add(latin1.encode(b.toString()));
  return out.toBytes();
}

List<int> objectBytes(int n, Obj o) {
  final data = o.data;
  if (data == null) return latin1.encode('$n 0 obj\n${o.body}\nendobj\n');
  return [...latin1.encode('$n 0 obj\n${o.body.replaceFirst('<<', '<< /Length ${data.length}')}\nstream\n'), ...data, ...latin1.encode('\nendstream\nendobj\n')];
}

/// A one-page PDF ([w] × [h] points) drawing [content] (objects 1–4; [extra]
/// objects from 5).
Uint8List page(Object content, {double w = 200, double h = 100, String resources = '', String catalog = '', List<Obj> extra = const [], String trailer = '/Root 1 0 R'}) => pdf([
  Obj('<< /Type /Catalog /Pages 2 0 R $catalog >>'),
  Obj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  Obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] /Resources << $resources >> /Contents 4 0 R >>'),
  Obj('<< >>', content is String ? latin1.encode(content) : content as List<int>),
  ...extra,
], trailer: trailer);

PdfPageContent read(Uint8List bytes, [int index = 0]) => PdfReader.open(bytes).readPage(index);

Matcher near(Pt p, [double tol = 1e-6]) => predicate<Pt>((q) => q.distanceTo(p) <= tol, 'within $tol of $p');

Matcher refused(String code) => throwsA(isA<FormatException>().having((e) => e.message, 'message', code));

/// The pixels of an encoded image, RGBA.
List<List<int>> pixels(Uint8List bytes) {
  final im = img.decodeImage(bytes)!;
  return [
    for (var y = 0; y < im.height; y++)
      for (var x = 0; x < im.width; x++)
        () {
          final p = im.getPixel(x, y);
          return [p.r.toInt(), p.g.toInt(), p.b.toInt(), im.numChannels == 4 || im.numChannels == 2 ? p.a.toInt() : 255];
        }(),
  ];
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

Uint8List pngWithAlpha(int w, int h) {
  final im = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, x * 255 ~/ w, y * 255 ~/ h, 40, x * 255 ~/ w);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

// ---------------------------------------------------------------- encoders

List<int> zlib(List<int> data) => ZLibEncoder().encodeBytes(data);

List<int> asciiHex(List<int> data) => latin1.encode('${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}>');

List<int> ascii85(List<int> data) {
  final b = StringBuffer();
  for (var i = 0; i < data.length; i += 4) {
    final n = math.min(4, data.length - i);
    var v = 0;
    for (var k = 0; k < 4; k++) {
      v = v * 256 + (k < n ? data[i + k] : 0);
    }
    if (v == 0 && n == 4) {
      b.write('z');
      continue;
    }
    final digits = List.filled(5, 0);
    for (var k = 4; k >= 0; k--) {
      digits[k] = v % 85;
      v ~/= 85;
    }
    for (var k = 0; k <= n; k++) {
      b.writeCharCode(digits[k] + 33);
    }
  }
  b.write('~>');
  return latin1.encode(b.toString());
}

/// LZW with early change, as PDF writers do.
List<int> lzw(List<int> data) {
  final out = <int>[];
  var buf = 0, bits = 0, width = 9, next = 258;
  void emit(int code) {
    buf = (buf << width) | code;
    bits += width;
    while (bits >= 8) {
      out.add((buf >> (bits - 8)) & 0xFF);
      bits -= 8;
    }
    buf &= (1 << bits) - 1;
  }

  final dict = <String, int>{};
  emit(256);
  var w = <int>[];
  int codeOf(List<int> s) => s.length == 1 ? s[0] : dict[s.join(',')]!;
  for (final c in data) {
    final wc = [...w, c];
    if (w.isEmpty || dict.containsKey(wc.join(','))) {
      w = wc;
      continue;
    }
    emit(codeOf(w));
    dict[wc.join(',')] = next++;
    if (next >= (1 << width) && width < 12) width++;
    if (next >= 4000) {
      // the table is nearly full: cleared, as writers do
      emit(256);
      dict.clear();
      next = 258;
      width = 9;
    }
    w = [c];
  }
  if (w.isNotEmpty) emit(codeOf(w));
  emit(257);
  if (bits > 0) out.add((buf << (8 - bits)) & 0xFF);
  return out;
}

List<int> runLength(List<int> data) {
  final out = <int>[];
  var i = 0;
  while (i < data.length) {
    // a run of one byte repeated, else a literal chunk
    var run = 1;
    while (i + run < data.length && data[i + run] == data[i] && run < 128) {
      run++;
    }
    if (run >= 3) {
      out.addAll([257 - run, data[i]]);
      i += run;
      continue;
    }
    final n = math.min(128, data.length - i);
    out.add(n - 1);
    out.addAll(data.sublist(i, i + n));
    i += n;
  }
  out.add(128);
  return out;
}

/// Rows of [w] RGB pixels with a PNG filter byte before each (types 0–4 in turn).
List<int> pngRows(List<List<int>> rows, int bpp) {
  final out = <int>[];
  List<int>? prev;
  for (var r = 0; r < rows.length; r++) {
    final type = r % 5;
    final row = rows[r];
    out.add(type);
    for (var i = 0; i < row.length; i++) {
      final left = i >= bpp ? row[i - bpp] : 0, up = prev != null ? prev[i] : 0, upLeft = prev != null && i >= bpp ? prev[i - bpp] : 0;
      final pred = switch (type) {
        1 => left,
        2 => up,
        3 => (left + up) >> 1,
        4 => () {
          final p = left + up - upLeft;
          final pa = (p - left).abs(), pb = (p - up).abs(), pc = (p - upLeft).abs();
          return pa <= pb && pa <= pc ? left : (pb <= pc ? up : upLeft);
        }(),
        _ => 0,
      };
      out.add((row[i] - pred) & 0xFF);
    }
    prev = row;
  }
  return out;
}

void main() {
  group('the PDF writer of the app, read back', () {
    late Uint8List jpg, png;
    Uint8List sheet({bool compress = true}) {
      final doc = PdfDocument();
      final p = doc.addPage(widthPt: 595, heightPt: 842);
      p.strokeColor(0xFFFF0000);
      p.lineWidth(0.5);
      p.path([(100, 100), (200, 100), (200, 150)]);
      p.strokeColor(0xFF000000);
      p.circle(300, 400, 50);
      p.fillColor(0xFF808080);
      p.rect(50, 600, 100, 40, stroke: false, fill: true);
      p.fillColor(0xFF000000);
      p.text(100, 700, 'Planta baixa: área 1', size: 12);
      p.text(300, 300, 'Lateral', size: 10, rotationDeg: 30);
      p.image(doc.image(jpg)!, (400, 100), (464, 100), (400, 132));
      p.image(doc.image(png)!, (400, 200), (440, 200), (400, 240));
      doc.addPage(widthPt: 842, heightPt: 595).line(0, 0, 842, 595);
      return doc.build(compress: compress);
    }

    setUpAll(() {
      jpg = jpeg(32, 16);
      png = pngWithAlpha(8, 8);
    });

    for (final compress in [true, false]) {
      test('paths, curves, texts and images (${compress ? 'compressed' : 'plain'} streams)', () {
        final r = PdfReader.open(sheet(compress: compress));
        expect(r.pageCount, 2);
        expect((r.pages[0].width, r.pages[0].height), (595, 842));
        expect((r.pages[1].width, r.pages[1].height), (842, 595));
        expect(r.pages[0].widthMm, closeTo(209.9, 0.1));
        final c = r.readPage(0);
        expect(c.warnings, isEmpty);
        expect(c.truncated, isFalse);
        final poly = c.paths.firstWhere((p) => p.strokeRgb == 0xFF0000);
        expect(poly.points, [near(const Pt(100, 100)), near(const Pt(200, 100)), near(const Pt(200, 150))]);
        expect((poly.closed, poly.stroked, poly.filled, poly.lineWidth), (false, true, false, 0.5));
        // the circle: four Bézier curves flattened within the tolerance
        final circle = c.paths.firstWhere((p) => p.closed && p.stroked && p.points.length > 8);
        expect(circle.points.length, greaterThan(24));
        for (final q in circle.points) {
          expect(q.distanceTo(const Pt(300, 400)), closeTo(50, 0.15));
        }
        final box = c.paths.firstWhere((p) => p.filled);
        expect((box.stroked, box.closed, box.fillRgb, box.points.length), (false, true, 0x808080, 4));
        final title = c.texts.firstWhere((t) => t.text.startsWith('Planta'));
        expect(title.text, 'Planta baixa: área 1');
        expect(title.origin, near(const Pt(100, 700), 0.01));
        expect((title.height, title.angleDeg), (12, 0));
        final turned = c.texts.firstWhere((t) => t.text == 'Lateral');
        expect(turned.angleDeg, closeTo(30, 0.5));
        expect(turned.origin, near(const Pt(300, 300), 0.05));
        expect(c.images, hasLength(2));
        final photo = c.images.firstWhere((i) => i.mime == 'image/jpeg');
        expect(photo.bytes, jpg, reason: 'JPEG data passed through');
        expect((photo.widthPx, photo.heightPx), (32, 16));
        expect(photo.corners, [near(const Pt(400, 100)), near(const Pt(464, 100)), near(const Pt(464, 132)), near(const Pt(400, 132))]);
        final logo = c.images.firstWhere((i) => i.mime == 'image/png');
        expect((logo.widthPx, logo.heightPx), (8, 8));
        // the RGB samples and the soft mask come back together
        expect(pixels(logo.bytes!), pixels(png));
        final second = r.readPage(1);
        expect(second.paths.single.points, [near(Pt.zero), near(const Pt(842, 595))]);
      });
    }

    test('the corners of an image only, without decoding it', () {
      final c = PdfReader.open(sheet()).readPage(0, images: false);
      expect(c.images, hasLength(2));
      expect(c.images.every((i) => i.bytes == null), isTrue);
      expect(c.images.first.corners.first, near(const Pt(400, 100)));
    });

    test('Unicode text of the embedded fonts, through their ToUnicode maps', () {
      final fonts = PdfFonts();
      for (final name in BundledFonts.all) {
        expect(fonts.register(name, File('assets/fonts/$name').readAsBytesSync()), isTrue);
      }
      final doc = PdfDocument(fonts: fonts);
      final p = doc.addPage(widthPt: 300, heightPt: 200);
      p.text(20, 150, 'Irrigação por gotejamento', size: 10);
      p.text(20, 110, 'Ζώνη άρδευσης', size: 10);
      p.text(20, 70, 'Задвижка №3', size: 10);
      p.text(20, 30, '水泵 5 kW', size: 10);
      final texts = read(doc.build()).texts.map((t) => t.text).toList();
      expect(texts, containsAll(['Irrigação por gotejamento', 'Ζώνη άρδευσης', 'Задвижка №3', '水泵 5 kW']));
    });

    test('a damaged file never raises anything but a FormatException', () {
      final good = sheet();
      final rnd = math.Random(7);
      final cases = <Uint8List>[
        for (var i = 1; i <= 40; i++) Uint8List.sublistView(good, 0, good.length * i ~/ 41),
        for (var i = 0; i < 40; i++)
          () {
            final b = Uint8List.fromList(good);
            for (var k = 0; k < 1 + i % 8; k++) {
              b[rnd.nextInt(b.length)] = rnd.nextInt(256);
            }
            return b;
          }(),
      ];
      for (final b in cases) {
        try {
          final r = PdfReader.open(b);
          for (var i = 0; i < r.pageCount; i++) {
            r.readPage(i);
          }
        } on FormatException {
          // refused: fine
        }
      }
    });
  });

  group('file structure', () {
    test('cross-reference stream and object stream (PDF 1.5)', () {
      final content = zlib(latin1.encode('0 0 m 50 0 l 50 50 l S'));
      final objs = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>'];
      final head = StringBuffer();
      final body = StringBuffer();
      for (var i = 0; i < objs.length; i++) {
        head.write('${i + 1} ${body.length} ');
        body.write('${objs[i]}\n');
      }
      final stm = zlib(latin1.encode('$head$body'));
      final out = BytesBuilder()..add(latin1.encode('%PDF-1.5\n'));
      final off4 = out.length;
      out.add(objectBytes(4, Obj('<< /Filter /FlateDecode >>', content)));
      final off5 = out.length;
      out.add(objectBytes(5, Obj('<< /Type /ObjStm /N 3 /First ${head.length} /Filter /FlateDecode >>', stm)));
      final off6 = out.length;
      // entries of 1 + 4 + 2 bytes, PNG "up" predictor
      List<int> entry(int type, int a, int b) => [type, (a >> 24) & 0xFF, (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF, (b >> 8) & 0xFF, b & 0xFF];
      final rows = [entry(0, 0, 65535), entry(2, 5, 0), entry(2, 5, 1), entry(2, 5, 2), entry(1, off4, 0), entry(1, off5, 0), entry(1, off6, 0)];
      final predicted = <int>[];
      for (var r = 0; r < rows.length; r++) {
        predicted.add(2);
        for (var i = 0; i < 7; i++) {
          predicted.add((rows[r][i] - (r > 0 ? rows[r - 1][i] : 0)) & 0xFF);
        }
      }
      out.add(objectBytes(6, Obj('<< /Type /XRef /Size 7 /Root 1 0 R /W [1 4 2] /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >> >>', zlib(predicted))));
      out.add(latin1.encode('startxref\n$off6\n%%EOF\n'));
      final r = PdfReader.open(out.toBytes());
      expect(r.warnings, isEmpty, reason: 'read through the stream, not rebuilt');
      expect(r.readPage(0).paths.single.points, [near(Pt.zero), near(const Pt(50, 0)), near(const Pt(50, 50))]);
    });

    test('incremental update: the newest definition of an object wins', () {
      final base = page('0 0 m 10 0 l S');
      final text = latin1.decode(base);
      final prev = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
      final out = BytesBuilder()..add(base);
      final off = out.length;
      out.add(objectBytes(4, Obj('<< >>', latin1.encode('0 0 m 0 10 l S'))));
      final xref = out.length;
      out.add(latin1.encode('xref\n0 1\n0000000000 65535 f \n4 1\n${off.toString().padLeft(10, '0')} 00000 n \ntrailer\n<< /Size 5 /Root 1 0 R /Prev $prev >>\nstartxref\n$xref\n%%EOF\n'));
      expect(read(out.toBytes()).paths.single.points.last, near(const Pt(0, 10)));
    });

    test('a broken cross-reference table is rebuilt from the objects', () {
      final good = page('0 0 m 10 0 l S');
      // every object moved: the offsets of the table point beside them
      final shifted = Uint8List.fromList([...good.sublist(0, 9), ...List.filled(7, 0x20), ...good.sublist(9)]);
      final r = PdfReader.open(shifted);
      expect(r.warnings, contains('pdf_xref_rebuilt'));
      expect(r.readPage(0).paths.single.points.last, near(const Pt(10, 0)));
      // the table and trailer cut off: the catalog is found by its type
      final cut = Uint8List.sublistView(good, 0, latin1.decode(good).indexOf('xref'));
      expect(read(cut).paths, hasLength(1));
    });

    test('junk before the header shifts every offset', () {
      final b = pdf([
        Obj('<< /Type /Catalog /Pages 2 0 R >>'),
        Obj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
        Obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>'),
        Obj('<< >>', latin1.encode('1 1 m 2 2 l S')),
      ], prefix: latin1.encode('From a mail gateway\r\n'));
      final r = PdfReader.open(b);
      expect(r.warnings, isEmpty);
      expect(r.readPage(0).paths, hasLength(1));
    });

    test('encrypted, empty, non-PDF files and PDFs without pages are refused', () {
      expect(() => PdfReader.open(page('0 0 m 1 1 l S', trailer: '/Root 1 0 R /Encrypt << /Filter /Standard /V 1 /R 2 /O <00> /U <00> /P -4 >>')), refused('pdf_encrypted'));
      expect(() => PdfReader.open(Uint8List(0)), refused('pdf_not_pdf'));
      expect(() => PdfReader.open(Uint8List.fromList(utf8.encode('<!DOCTYPE html><html><body>obj</body></html>'))), refused('pdf_not_pdf'));
      expect(() => PdfReader.open(pdf([Obj('<< /Type /Catalog /Pages 2 0 R >>'), Obj('<< /Type /Pages /Kids [] /Count 0 >>')])), refused('pdf_no_pages'));
    });

    test('page tree: inherited media box, rotation and crop box, user unit', () {
      final b = pdf([
        Obj('<< /Type /Catalog /Pages 2 0 R >>'),
        Obj('<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R] /Count 3 /MediaBox [0 0 200 100] /Rotate 90 >>'),
        Obj('<< /Type /Page /Parent 2 0 R /CropBox [10 10 190 90] /Contents 4 0 R >>'),
        Obj('<< >>', latin1.encode('10 10 m 190 10 l S')),
        Obj('<< /Type /Page /Parent 2 0 R /Rotate 0 /Contents 6 0 R >>'),
        Obj('<< >>', latin1.encode('0 0 m 200 100 l S')),
        Obj('<< /Type /Page /Parent 2 0 R /Rotate -90 /UserUnit 2 /Contents 6 0 R >>'),
      ]);
      final r = PdfReader.open(b);
      expect(r.pageCount, 3);
      // turned clockwise: the crop box is 180 × 80, shown 80 × 180
      expect((r.pages[0].width, r.pages[0].height, r.pages[0].rotation), (80, 180, 90));
      expect(r.readPage(0).paths.single.points, [near(const Pt(0, 180)), near(Pt.zero)]);
      expect((r.pages[1].width, r.pages[1].height, r.pages[1].rotation), (200, 100, 0));
      expect(r.readPage(1).paths.single.points, [near(Pt.zero), near(const Pt(200, 100))]);
      // −90 is 270: the bottom-left corner of the sheet goes to the bottom right, units doubled
      expect((r.pages[2].width, r.pages[2].height, r.pages[2].rotation), (200, 400, 270));
      expect(r.readPage(2).paths.single.points, [near(const Pt(200, 0)), near(const Pt(0, 400))]);
    });
  });

  group('stream filters', () {
    const drawing = '0 0 m 100 0 l 100 50 l S';
    void expectDrawn(Uint8List b) => expect(read(b).paths.single.points, [near(Pt.zero), near(const Pt(100, 0)), near(const Pt(100, 50))]);

    test('ASCIIHex then Flate, ASCII85, LZW, RunLength', () {
      final raw = latin1.encode(drawing);
      Uint8List withFilter(String filter, List<int> data) => pdf([
        Obj('<< /Type /Catalog /Pages 2 0 R >>'),
        Obj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
        Obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Contents 4 0 R >>'),
        Obj('<< /Filter $filter >>', data),
      ]);
      expectDrawn(withFilter('[/ASCIIHexDecode /FlateDecode]', asciiHex(zlib(raw))));
      expectDrawn(withFilter('/ASCII85Decode', ascii85(raw)));
      expectDrawn(withFilter('/LZWDecode', lzw(raw)));
      expectDrawn(withFilter('/RunLengthDecode', runLength([...raw, ...List.filled(40, 0x20)])));
      // a long stream, so that the LZW codes widen to 12 bits (and the table is cleared)
      final long = latin1.encode(List.generate(3000, (i) => '${i % 97} ${i % 89} m ${i % 83 + 100} ${i % 79} l S').join('\n'));
      final plain = read(withFilter('[]', long)).paths;
      final packed = read(withFilter('/LZWDecode', lzw(long))).paths;
      expect(plain, hasLength(3000));
      expect([for (final p in packed) p.points], [for (final p in plain) p.points]);
    });

    test('the LZW example of the specification', () {
      // ISO 32000-1, 7.4.4.2: 80 0B 60 50 22 0C 0C 85 01 decodes to "-----A---B"
      final b = page(
        'q 10 0 0 1 0 0 cm /Im1 Do Q',
        resources: '/XObject << /Im1 5 0 R >>',
        extra: [
          Obj('<< /Type /XObject /Subtype /Image /Width 10 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /LZWDecode >>', [0x80, 0x0B, 0x60, 0x50, 0x22, 0x0C, 0x0C, 0x85, 0x01]),
        ],
      );
      final px = pixels(read(b).images.single.bytes!);
      expect(px.map((p) => p[0]), latin1.encode('-----A---B'));
    });

    test('PNG and TIFF predictors on image samples', () {
      final rows = [
        for (var y = 0; y < 6; y++)
          [
            for (var x = 0; x < 5; x++) ...[x * 50, y * 40, (x * y * 13) % 256],
          ],
      ];
      final tiff = <int>[
        for (final row in rows) ...[for (var i = 0; i < row.length; i++) (row[i] - (i >= 3 ? row[i - 3] : 0)) & 0xFF],
      ];
      for (final (parms, data) in [('/Predictor 15', pngRows(rows, 3)), ('/Predictor 2', tiff)]) {
        final b = page(
          'q 50 0 0 60 0 0 cm /Im1 Do Q',
          resources: '/XObject << /Im1 5 0 R >>',
          extra: [
            Obj('<< /Type /XObject /Subtype /Image /Width 5 /Height 6 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /DecodeParms << $parms /Colors 3 /Columns 5 >> >>', zlib(data)),
          ],
        );
        final px = pixels(read(b).images.single.bytes!);
        for (var y = 0; y < 6; y++) {
          for (var x = 0; x < 5; x++) {
            expect(px[y * 5 + x].sublist(0, 3), rows[y].sublist(3 * x, 3 * x + 3), reason: '$parms ($x, $y)');
          }
        }
      }
    });
  });

  group('content', () {
    test('Form XObjects: their matrix, their resources, nesting, and a form that draws itself', () {
      final b = page(
        'q 1 0 0 1 10 20 cm /Fm1 Do Q /Self Do',
        resources: '/XObject << /Fm1 5 0 R /Self 6 0 R >>',
        extra: [
          Obj('<< /Type /XObject /Subtype /Form /BBox [0 0 100 100] /Matrix [2 0 0 2 0 0] /Resources << /XObject << /Fm2 7 0 R >> >> >>', latin1.encode('0 0 m 10 0 l S /Fm2 Do')),
          Obj('<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /Resources << /XObject << /Self 6 0 R >> >> >>', latin1.encode('/Self Do 5 5 m 6 6 l S')),
          Obj('<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /Matrix [1 0 0 1 0 5] >>', latin1.encode('0 0 m 0 1 l S')),
        ],
      );
      final paths = read(b).paths;
      expect(paths, hasLength(3));
      expect(paths[0].points, [near(const Pt(10, 20)), near(const Pt(30, 20))]);
      expect(paths[1].points, [near(const Pt(10, 30)), near(const Pt(10, 32))]);
      expect(paths[1].lineWidth, 2, reason: 'scaled with the form');
      expect(paths[2].points, [near(const Pt(5, 5)), near(const Pt(6, 6))]);
    });

    test('optional content: layer names (UTF-16 too), layers off, XObjects in a layer', () {
      final b = page(
        '/OC /oc1 BDC 0 0 m 10 0 l S EMC /OC /oc2 BDC 0 10 m 10 10 l S EMC /Fm Do 20 20 m 30 30 l S /Span << /ActualText (x) >> BDC 40 40 m 50 50 l S EMC',
        catalog: '/OCProperties << /OCGs [5 0 R 6 0 R] /D << /Order [5 0 R 6 0 R] /OFF [6 0 R] >> >>',
        resources: '/Properties << /oc1 5 0 R /oc2 6 0 R >> /XObject << /Fm 7 0 R >>',
        extra: [
          Obj('<< /Type /OCG /Name (Paredes) >>'),
          Obj('<< /Type /OCG /Name <FEFF00C1006700750061007300> >>'),
          Obj('<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /OC 6 0 R >>', latin1.encode('0 0 m 5 5 l S')),
        ],
      );
      final r = PdfReader.open(b);
      expect([for (final l in r.layers) (l.name, l.visible)], [('Paredes', true), ('Águas', false)]);
      final c = r.readPage(0);
      expect([for (final p in c.paths) (p.layer, p.hidden)], [('Paredes', false), ('Águas', true), ('Águas', true), ('', false), ('', false)]);
      expect([for (final l in c.layers) l.name], ['Paredes', 'Águas']);
    });

    test('consecutive segments become one polyline; a change of colour starts another', () {
      final square = read(page('0 0 m 10 0 l S 10 0 m 10 10 l S 10 10 m 0 10 l S 0 10 m 0 0 l S'));
      expect(square.paths, hasLength(1));
      expect((square.paths.single.closed, square.paths.single.points.length), (true, 4));
      final two = read(page('0 0 m 10 0 l S 1 0 0 RG 10 0 m 10 10 l S'));
      expect(two.paths, hasLength(2));
      expect(two.paths.last.strokeRgb, 0xFF0000);
      // a filled rectangle and a clipping path that paints nothing
      final fill = read(page('0 0 1 rg 5 5 20 10 re f 0 0 50 50 re W n'));
      expect(fill.paths.single.points, [near(const Pt(5, 5)), near(const Pt(25, 5)), near(const Pt(25, 15)), near(const Pt(5, 15))]);
      expect((fill.paths.single.filled, fill.paths.single.fillRgb), (true, 0x0000FF));
    });

    test('clipping: the rectangle of the clip path, kept by q/Q, and the bounding box of forms', () {
      final b = page(
        'q 10 10 50 50 re W n 0 0 m 100 100 l S 0 30 m 100 30 l S 5 20 m 5 40 l S 20 20 m 30 20 l 30 30 l h f 50 50 m 70 50 l 70 70 l 50 70 l h f '
        'BT /F1 5 Tf 20 40 Td (dentro) Tj ET BT /F1 5 Tf 80 80 Td (fora) Tj ET q 100 0 0 10 70 70 cm /Im Do Q Q '
        '0 0 m 100 0 l S q 1 0 0 1 100 0 cm /Fm Do Q',
        w: 200,
        resources: '/Font << /F1 5 0 R >> /XObject << /Fm 6 0 R /Im 7 0 R >>',
        extra: [
          Obj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
          Obj('<< /Type /XObject /Subtype /Form /BBox [0 0 20 20] >>', latin1.encode('0 5 m 40 5 l S')),
          Obj('<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 >>', [0]),
        ],
      );
      final c = read(b);
      expect(
        [for (final p in c.paths) p.points],
        [
          [near(const Pt(10, 10)), near(const Pt(60, 60))],
          [near(const Pt(10, 30)), near(const Pt(60, 30))],
          [near(const Pt(20, 20)), near(const Pt(30, 20)), near(const Pt(30, 30))],
          hasLength(4),
          [near(Pt.zero), near(const Pt(100, 0))],
          [near(const Pt(100, 5)), near(const Pt(120, 5))],
        ],
      );
      // the filled square cut to the clip: its corner inside and three on the clip edges
      expect(c.paths[3].points, unorderedEquals([near(const Pt(50, 50)), near(const Pt(60, 50)), near(const Pt(60, 60)), near(const Pt(50, 60))]));
      expect(c.paths[3].closed, isTrue);
      expect([for (final t in c.texts) t.text], ['dentro']);
      expect(c.images, isEmpty);
      // a closed outline crossing the clip keeps its pieces, the last joined to the first
      final ring = read(page('q 0 0 50 100 re W n 20 10 m 80 10 l 80 90 l 20 90 l h S Q'));
      expect(
        [for (final p in ring.paths) p.points],
        [
          [near(const Pt(50, 90)), near(const Pt(20, 90)), near(const Pt(20, 10)), near(const Pt(50, 10))],
        ],
      );
    });

    test('colours: grey, RGB, CMYK, ICC, Lab, Indexed and spot colours with their tint transform', () {
      final b = page(
        '0.5 G 0 0 m 1 0 l S 1 0 0 RG 0 2 m 1 2 l S 0 1 1 0 K 0 4 m 1 4 l S /Icc CS 0 0 1 SC 0 6 m 1 6 l S /Lab CS 100 0 0 SC 0 8 m 1 8 l S /Pal CS 1 SC 0 10 m 1 10 l S /Spot CS 1 SCN 0 12 m 1 12 l S',
        resources: '/ColorSpace << /Icc [/ICCBased 5 0 R] /Lab [/Lab << /WhitePoint [0.9505 1 1.089] >>] /Pal [/Indexed /DeviceRGB 1 <FF000000FF00>] /Spot [/Separation /PANTONE#20300 /DeviceCMYK << /FunctionType 2 /Domain [0 1] /C0 [0 0 0 0] /C1 [1 0.5 0 0] /N 1 >>] >>',
        extra: [
          Obj('<< /N 3 >>', [0]),
        ],
      );
      expect([for (final p in read(b).paths) p.strokeRgb], [0x808080, 0xFF0000, 0xFF0000, 0x0000FF, 0xFFFFFF, 0x00FF00, 0x0080FF]);
    });

    test('text: encodings with differences, ToUnicode, spacing, turned and invisible text', () {
      final b = page(
        'BT /F1 10 Tf 10 90 Td (AB\\200) Tj ET '
        'BT /F1 10 Tf 10 75 Td [(Can) -50 (teiro)] TJ ET '
        'BT /F1 10 Tf 10 60 Td [(Linha) -400 (lateral)] TJ ET '
        'BT /F2 12 Tf 10 45 Td (ABC) Tj ET '
        'q BT 3 Tr /F1 10 Tf 10 30 Td (oculto) Tj ET Q '
        'BT /F1 8 Tf 0 1 -1 0 150 10 Tm (vertical) Tj ET '
        'BT /F1 10 Tf 10 15 Td (P1) Tj 100 0 Td (P2) Tj ET '
        'BT /F1 10 Tf 10 3 Td (Rua) Tj ( ) Tj (das Flores) Tj ET',
        resources: '/Font << /F1 5 0 R /F2 6 0 R >>',
        extra: [
          Obj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding << /BaseEncoding /WinAnsiEncoding /Differences [65 /ccedilla /atilde 128 /Euro] >> >>'),
          Obj('<< /Type /Font /Subtype /TrueType /BaseFont /ABCDEF+Arial /FirstChar 65 /LastChar 67 /Widths [667 667 722] /Encoding /WinAnsiEncoding /ToUnicode 7 0 R >>'),
          Obj(
            '<< >>',
            latin1.encode(
              '/CIDInit /ProcSet findresource begin 12 dict begin begincmap 1 begincodespacerange <00> <FF> endcodespacerange 1 beginbfchar <41> <00C9> endbfchar 1 beginbfrange <42> <43> <0391> endbfrange endcmap end end',
            ),
          ),
        ],
      );
      final texts = read(b).texts;
      String at(double y) => texts.firstWhere((t) => (t.origin.y - y).abs() < 0.5 && t.angleDeg == 0).text;
      expect(at(90), 'çã€');
      expect(at(75), 'Canteiro');
      expect(at(60), 'Linha lateral');
      expect(at(45), 'ÉΑΒ');
      expect(texts.where((t) => t.text == 'oculto'), isEmpty);
      final v = texts.firstWhere((t) => t.text == 'vertical');
      expect(v.angleDeg, closeTo(90, 1e-9));
      expect(v.height, closeTo(8, 1e-9));
      expect(v.origin, near(const Pt(150, 10)));
      expect(
        [
          for (final t in texts)
            if ((t.origin.y - 15).abs() < 0.5) t.text,
        ],
        ['P1', 'P2'],
      );
      expect(at(3), 'Rua das Flores');
    });

    test('the standard glyph names of the Latin encodings, Latin Extended-A and Greek', () {
      // U+00A1–U+00FF but the soft hyphen, in order
      const latin1 =
          'exclamdown cent sterling currency yen brokenbar section dieresis copyright ordfeminine guillemotleft logicalnot registered macron '
          'degree plusminus twosuperior threesuperior acute mu paragraph periodcentered cedilla onesuperior ordmasculine guillemotright onequarter onehalf threequarters questiondown '
          'Agrave Aacute Acircumflex Atilde Adieresis Aring AE Ccedilla Egrave Eacute Ecircumflex Edieresis Igrave Iacute Icircumflex Idieresis '
          'Eth Ntilde Ograve Oacute Ocircumflex Otilde Odieresis multiply Oslash Ugrave Uacute Ucircumflex Udieresis Yacute Thorn germandbls '
          'agrave aacute acircumflex atilde adieresis aring ae ccedilla egrave eacute ecircumflex edieresis igrave iacute icircumflex idieresis '
          'eth ntilde ograve oacute ocircumflex otilde odieresis divide oslash ugrave uacute ucircumflex udieresis yacute thorn ydieresis';
      final expected = StringBuffer(
        String.fromCharCodes([
          for (var c = 0xA1; c <= 0xFF; c++)
            if (c != 0xAD) c,
        ]),
      );
      const others = {
        'Euro': '€', 'endash': '–', 'emdash': '—', 'quotedblleft': '“', 'quotedblright': '”', 'quoteleft': '‘', 'quoteright': '’', 'bullet': '•', 'ellipsis': '…', 'fi': 'ﬁ', //
        'Lslash': 'Ł', 'lslash': 'ł', 'Scaron': 'Š', 'zcaron': 'ž', 'OE': 'Œ', 'oe': 'œ', 'Ccaron': 'Č', 'scedilla': 'ş', 'Ohungarumlaut': 'Ő', 'gbreve': 'ğ', 'Idotaccent': 'İ',
        'dotlessi': 'ı', 'Aogonek': 'Ą', 'nacute': 'ń', 'Zdotaccent': 'Ż', 'tcaron': 'ť', 'Uring': 'Ů', 'ecaron': 'ě', 'Racute': 'Ŕ', 'lcaron': 'ľ', 'eng': 'ŋ', 'alpha': 'α',
        'theta': 'θ', 'Psi': 'Ψ', 'omega': 'ω', 'sigma1': 'ς', 'Omega': 'Ω', 'Delta': 'Δ', 'minus': '−', 'uni2300': '⌀', 'u1F4A7': '💧', 'f_f_i': 'ffi', 'a.sc': 'a',
      };
      final names = [...latin1.split(' '), ...others.keys];
      others.values.forEach(expected.write);
      final codes = [for (var i = 0; i < names.length; i++) (i + 1).toRadixString(16).padLeft(2, '0')].join();
      final b = page(
        'BT /F1 2 Tf 0 50 Td <$codes> Tj ET',
        w: 1000,
        resources: '/Font << /F1 5 0 R >>',
        extra: [Obj('<< /Type /Font /Subtype /Type1 /BaseFont /ABCDEF+Custom /Encoding << /Differences [1 ${names.map((n) => '/$n').join(' ')}] >> >>')],
      );
      expect(read(b).texts.single.text, expected.toString());
    });

    test('images: Indexed, CMYK, 1-bit with a decode array, stencil mask, soft mask, inline image', () {
      final b = page(
        latin1.encode(
              'q 20 0 0 10 0 0 cm /Im1 Do Q q 10 0 0 10 30 0 cm /Im2 Do Q q 80 0 0 10 0 20 cm /Im3 Do Q '
              'q 0 0 1 rg 80 0 0 10 0 40 cm /Im4 Do Q q 20 0 0 10 0 60 cm /Im5 Do Q '
              'q 20 0 0 10 50 80 cm BI /W 2 /H 1 /CS /G /BPC 8 ID ',
            ) +
            [0x00, 0xFF] +
            latin1.encode(' EI Q 0 0 m 5 5 l S'),
        resources: '/XObject << /Im1 5 0 R /Im2 6 0 R /Im3 7 0 R /Im4 8 0 R /Im5 9 0 R >> /ColorSpace << /Pal [/Indexed /DeviceRGB 1 <FF000000FF00>] >>',
        extra: [
          Obj('<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /Pal /BitsPerComponent 8 >>', [0, 1]),
          Obj('<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceCMYK /BitsPerComponent 8 >>', [0, 255, 255, 0]),
          Obj('<< /Type /XObject /Subtype /Image /Width 8 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Decode [1 0] >>', [0xA0]),
          Obj('<< /Type /XObject /Subtype /Image /Width 8 /Height 1 /ImageMask true >>', [0xF0]),
          Obj('<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /SMask 10 0 R >>', [255, 0, 0, 0, 0, 255]),
          Obj('<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 >>', [255, 0]),
        ],
      );
      final c = read(b);
      expect(c.images, hasLength(6));
      expect(pixels(c.images[0].bytes!), [
        [255, 0, 0, 255],
        [0, 255, 0, 255],
      ]);
      expect(pixels(c.images[1].bytes!), [
        [255, 0, 0, 255],
      ]);
      expect([for (final p in pixels(c.images[2].bytes!)) p[0]], [0, 255, 0, 255, 255, 255, 255, 255]);
      expect(
        [for (final p in pixels(c.images[3].bytes!)) p],
        [
          ...List.filled(4, [0, 0, 255, 0]),
          ...List.filled(4, [0, 0, 255, 255]),
        ],
      );
      expect(pixels(c.images[4].bytes!), [
        [255, 0, 0, 255],
        [0, 0, 255, 0],
      ]);
      expect([for (final p in pixels(c.images[5].bytes!)) p[0]], [0, 255]);
      expect(c.images[5].corners.first, near(const Pt(50, 80)));
      expect(c.paths.single.points.last, near(const Pt(5, 5)), reason: 'content goes on after the inline image');
    });

    test('a CCITT Group 4 scan', () {
      // two rows of 8 pixels, white white black×4 white white: horizontal mode
      // (001 0111 011) and V0 (1) for the first row, three V0 for the second
      final b = page(
        'q 80 0 0 20 0 0 cm /Scan Do Q',
        resources: '/XObject << /Scan 5 0 R >>',
        extra: [
          Obj('<< /Type /XObject /Subtype /Image /Width 8 /Height 2 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter /CCITTFaxDecode /DecodeParms << /K -1 /Columns 8 /Rows 2 >> >>', [0x2E, 0xFC]),
        ],
      );
      final c = read(b);
      expect(c.warnings, isEmpty);
      final row = [255, 255, 0, 0, 0, 0, 255, 255];
      expect([for (final p in pixels(c.images.single.bytes!)) p[0]], [...row, ...row]);
    });

    test('JPEG 2000 images are left out with a warning', () {
      final b = page(
        'q 10 0 0 10 0 0 cm /Im Do Q',
        resources: '/XObject << /Im 5 0 R >>',
        extra: [
          Obj('<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /JPXDecode >>', [0, 0, 0, 12]),
        ],
      );
      final c = read(b);
      expect(c.images.single.bytes, isNull);
      expect(c.warnings, contains('pdf_image_format:JPX'));
    });

    test('the segment limit truncates the page and says so', () {
      final content = List.generate(1000, (i) => '$i 0 m $i 10 l S').join('\n');
      final c = PdfReader.open(page(content, w: 1000)).readPage(0, maxSegments: 100);
      expect(c.truncated, isTrue);
      expect(c.segments, lessThanOrEqualTo(100));
      expect(c.warnings, contains('pdf_truncated:100'));
    });

    test('malformed operators are skipped, the rest is read', () {
      final c = read(page('0 m 5 5 l S /X 3 cm 1 2 3 4 5 6 7 8 9 c (a) Tj ] } 10 10 m 20 20 l S BT /Missing 9 Tf 1 1 Td (ok) Tj ET'));
      expect(c.paths.last.points.last, near(const Pt(20, 20)));
      expect(c.texts.single.text, 'ok', reason: 'a font missing from the resources reads as WinAnsi');
    });
  });
}
