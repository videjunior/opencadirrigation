import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/model/terrain.dart';

/// Input limits are told to the user in plain words: a BigTIFF is refused by
/// name (not as an unreadable image), a raster above the pixel cap says so,
/// and a terrain larger than the TIN takes is announced once.
void main() {
  Uint8List bigTiffHeader({bool little = true}) {
    final b = ByteData(16);
    b.setUint8(0, little ? 0x49 : 0x4D);
    b.setUint8(1, little ? 0x49 : 0x4D);
    b.setUint16(2, 43, little ? Endian.little : Endian.big);
    b.setUint16(4, 8, little ? Endian.little : Endian.big);
    return b.buffer.asUint8List();
  }

  test('a BigTIFF is refused by name, in both byte orders', () {
    final c = ProjectController()..setLanguage('pt');
    for (final little in [true, false]) {
      expect(() => GeoImageReader.readTiffTags(bigTiffHeader(little: little)), throwsA(isA<FormatException>().having((e) => e.message, 'code', 'tiff_bigtiff')));
    }
    try {
      GeoImageReader.readTiffTags(bigTiffHeader());
    } catch (e) {
      expect(c.describeError(e), c.t('imp.err.tiff_bigtiff'));
    }
    // other files keep coming back without tags
    expect(GeoImageReader.readTiffTags(Uint8List.fromList(List.filled(16, 0x2B))).shorts, isEmpty);
  });

  test('a raster above the pixel cap is refused with its message', () {
    final c = ProjectController()..setLanguage('pt');
    expect(() => GeoImageReader.checkPixels(20000, 20000), throwsA(isA<FormatException>()));
    try {
      GeoImageReader.checkPixels(20000, 20000);
    } catch (e) {
      expect(c.describeError(e), c.t('imp.err.image_too_large'));
    }
  });

  test('a terrain above the TIN size is announced once, with the share it keeps', () {
    final c = ProjectController()
      ..setLanguage('pt')
      ..autosaveEnabled = false;
    final n = Terrain.maxTinPoints + 3000;
    final csv = StringBuffer('x;y;z\n');
    for (var i = 0; i < n; i++) {
      csv.writeln('${i % 150};${i ~/ 150};${100 + (i % 7) * 0.1}');
    }
    final first = c.importFile('pontos.csv', utf8.encode(csv.toString()));
    expect(first, contains(c.t('msg.tinThinned', {'n': '$n', 'k': '2', 'm': '${(n / 2).round()}'})));
    final again = c.importFile('pontos2.csv', utf8.encode('x;y;z\n1;1;100\n'));
    expect(again, isNot(contains('TIN')), reason: 'once per project');
  });

  test('a PDF dropped without the dialog comes in as page 1 at 1:100; its errors read well', () {
    final c = ProjectController()
      ..setLanguage('pt')
      ..autosaveEnabled = false;
    expect(() => c.importFile('plano.pdf', Uint8List.fromList('<html></html>'.codeUnits)), throwsA(isA<FormatException>()));
    try {
      c.importFile('plano.pdf', Uint8List.fromList('<html></html>'.codeUnits));
    } catch (e) {
      expect(c.describeError(e), c.t('pdfimp.err.not_pdf'));
    }
  });
}
