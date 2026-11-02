import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart' show aciRgb;
import 'package:opencadirrigation/core/io/dem_tiff.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/geo_export.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/io/image_decode.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/io/shp.dart';
import 'package:opencadirrigation/core/io/shp_writer.dart' show ShapefileParts;
import 'package:opencadirrigation/core/io/work_slicer.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/io/xml_text.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Imports and exports against the cases of the 1 November 2026 sweep
/// (FMT-01, 03, 04, 06, 07, 09, 13–16, 23, 25, 28, 29, 31–33): small files
/// written here, hostile ones included.

ProjectController _fresh() {
  final c = ProjectController();
  c.setLanguage('en');
  c.newProject();
  return c;
}

/// Runs [f] and fails when it takes longer than [ms] milliseconds.
T _fast<T>(T Function() f, {int ms = 5000}) {
  final sw = Stopwatch()..start();
  final r = f();
  expect(sw.elapsedMilliseconds, lessThan(ms), reason: 'took ${sw.elapsedMilliseconds} ms');
  return r;
}

/// A zip of [files] whose entries then claim [declared] bytes each (a "zip
/// bomb" as its directory announces it; the data stays small).
Uint8List _claiming(Map<String, List<int>> files, int declared) {
  final arc = Archive();
  files.forEach((n, b) => arc.add(ArchiveFile.bytes(n, b)));
  final z = Uint8List.fromList(ZipEncoder().encodeBytes(arc));
  final bd = ByteData.sublistView(z);
  for (var i = 0; i + 30 < z.length; i++) {
    final sig = bd.getUint32(i, Endian.little);
    if (sig == 0x04034b50) bd.setUint32(i + 22, declared, Endian.little); // local header
    if (sig == 0x02014b50 && i + 28 < z.length) bd.setUint32(i + 24, declared, Endian.little); // central directory
  }
  return z;
}

/// TIFF LZW as libtiff writes it (codes of 9 to 12 bits, most significant
/// bit first, clear code at a full table).
Uint8List _lzw(Uint8List data) {
  final out = <int>[];
  var buf = 0, nbits = 0, width = 9, next = 258;
  void put(int code) {
    buf = (buf << width) | code;
    nbits += width;
    while (nbits >= 8) {
      out.add((buf >> (nbits - 8)) & 0xFF);
      nbits -= 8;
    }
    buf &= (1 << nbits) - 1;
  }

  final dict = <int, int>{};
  put(256);
  var omega = data[0];
  for (var i = 1; i < data.length; i++) {
    final k = data[i];
    final code = dict[(omega << 8) | k];
    if (code != null) {
      omega = code;
      continue;
    }
    put(omega);
    dict[(omega << 8) | k] = next++;
    if (next == 4094) {
      put(256);
      dict.clear();
      next = 258;
      width = 9;
    } else if (next > (1 << width) - 1) {
      width++;
    }
    omega = k;
  }
  put(omega);
  put(257);
  if (nbits > 0) out.add((buf << (8 - nbits)) & 0xFF);
  return Uint8List.fromList(out);
}

/// A one-band TIFF of [rows] (float32 with [predictor] 1 or 3, or 8-bit
/// grey with [grey]) in [compression] 1, 5 or 8, in strips or tiles of
/// [tile] pixels, georeferenced at (700000, 7500000) in EPSG [epsg].
Uint8List _tiff(List<List<double>> rows, {int predictor = 1, int compression = 8, int? tile, int epsg = 32723, bool grey = false}) {
  final w = rows.first.length, h = rows.length;
  final bps = grey ? 1 : 4;
  final bw = tile ?? w, bh = tile ?? h;
  final across = (w + bw - 1) ~/ bw, down = (h + bh - 1) ~/ bh;
  Uint8List block(int bx, int by) {
    final raw = BytesBuilder();
    for (var r = 0; r < bh; r++) {
      final row = Uint8List(bps * bw);
      final bd = ByteData.sublistView(row);
      for (var c = 0; c < bw; c++) {
        final y = by * bh + r, x = bx * bw + c;
        final v = y < h && x < w ? rows[y][x] : 0.0;
        if (grey) {
          row[c] = v.round().clamp(0, 255);
        } else {
          bd.setFloat32(4 * c, v, Endian.little);
        }
      }
      if (predictor == 3) {
        // byte planes, most significant first, then horizontal differencing
        final tmp = Uint8List(4 * bw);
        for (var c = 0; c < bw; c++) {
          for (var b = 0; b < 4; b++) {
            tmp[b * bw + c] = row[4 * c + (3 - b)];
          }
        }
        for (var k = tmp.length - 1; k > 0; k--) {
          tmp[k] = (tmp[k] - tmp[k - 1]) & 0xFF;
        }
        raw.add(tmp);
      } else {
        raw.add(row);
      }
    }
    final bytes = raw.toBytes();
    return switch (compression) {
      1 => bytes,
      5 => _lzw(bytes),
      _ => Uint8List.fromList(const ZLibEncoder().encode(bytes)),
    };
  }

  final blocks = [
    for (var by = 0; by < down; by++)
      for (var bx = 0; bx < across; bx++) block(bx, by),
  ];
  final tiled = tile != null;
  final entries = <(int, int, int, Object)>[
    (256, 3, 1, w),
    (257, 3, 1, h),
    (258, 3, 1, grey ? 8 : 32),
    (259, 3, 1, compression),
    (262, 3, 1, 1),
    (277, 3, 1, 1),
    if (!tiled) (278, 3, 1, h),
    (284, 3, 1, 1),
    if (predictor != 1) (317, 3, 1, predictor),
    (339, 3, 1, grey ? 1 : 3),
    if (tiled) ...[(322, 3, 1, bw), (323, 3, 1, bh)],
  ];
  // offsets and counts of the blocks, the georeference
  final extra = BytesBuilder();
  final n = entries.length + 2 + 3;
  final ifd = 8;
  final extraStart = ifd + 2 + n * 12 + 4;
  int addExtra(List<int> b) {
    final o = extraStart + extra.length;
    extra.add(b);
    if (extra.length.isOdd) extra.addByte(0);
    return o;
  }

  Uint8List longs(List<int> v) {
    final b = ByteData(4 * v.length);
    for (var i = 0; i < v.length; i++) {
      b.setUint32(4 * i, v[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }

  Uint8List doubles(List<double> v) {
    final b = ByteData(8 * v.length);
    for (var i = 0; i < v.length; i++) {
      b.setFloat64(8 * i, v[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }

  Uint8List shorts(List<int> v) {
    final b = ByteData(2 * v.length);
    for (var i = 0; i < v.length; i++) {
      b.setUint16(2 * i, v[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }

  final scaleOff = addExtra(doubles([10, 10, 0]));
  final tieOff = addExtra(doubles([0, 0, 0, 700000, 7500000, 0]));
  final keysOff = addExtra(shorts([1, 1, 0, 1, 3072, 0, 1, epsg]));
  final dataOffs = [for (final b in blocks) addExtra(b)];
  final offOff = addExtra(longs(dataOffs)), cntOff = addExtra(longs([for (final b in blocks) b.length]));
  final all = <(int, int, int, Object)>[
    ...entries,
    (tiled ? 324 : 273, 4, blocks.length, blocks.length == 1 ? dataOffs.single : offOff),
    (tiled ? 325 : 279, 4, blocks.length, blocks.length == 1 ? blocks.single.length : cntOff),
    (33550, 12, 3, scaleOff),
    (33922, 12, 6, tieOff),
    (34735, 3, 8, keysOff),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final head = ByteData(extraStart);
  head
    ..setUint8(0, 0x49)
    ..setUint8(1, 0x49)
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, ifd, Endian.little)
    ..setUint16(ifd, all.length, Endian.little);
  for (var i = 0; i < all.length; i++) {
    final e = ifd + 2 + 12 * i;
    final (tag, type, count, v) = all[i];
    head
      ..setUint16(e, tag, Endian.little)
      ..setUint16(e + 2, type, Endian.little)
      ..setUint32(e + 4, count, Endian.little);
    if (type == 3 && count == 1) {
      head.setUint16(e + 8, v as int, Endian.little);
    } else {
      head.setUint32(e + 8, v as int, Endian.little);
    }
  }
  return (BytesBuilder()
        ..add(head.buffer.asUint8List())
        ..add(extra.toBytes()))
      .toBytes();
}

void main() {
  group('zip and gzip bombs (FMT-06, 09)', () {
    const twoGb = 0x7FFFFFF0;
    test('KMZ, XLSX, shapefile and picture zips that claim gigabytes are refused before anything is decompressed', () {
      final kml = utf8.encode('<kml xmlns="http://www.opengis.net/kml/2.2"><Placemark><Point><coordinates>-47.1,-22.1,0</coordinates></Point></Placemark></kml>');
      Matcher bomb = throwsA(isA<FormatException>().having((e) => e.message, 'message', 'zip_too_large'));
      expect(() => _fast(() => KmlReader.parseKmz(_claiming({'doc.kml': kml}, twoGb))), bomb);
      expect(() => _fast(() => XlsxReader.read(_claiming({'xl/workbook.xml': utf8.encode('<workbook/>')}, twoGb))), bomb);
      expect(() => _fast(() => ShpReader.parseAny('lotes.zip', _claiming({'lotes.shp': Uint8List(200)}, twoGb))), bomb);
      expect(() => _fast(() => ShapefileParts.unzip(_claiming({'lotes.shp': Uint8List(200)}, twoGb))), bomb);
      expect(() => _fast(() => GeoImageReader.read('orto.zip', _claiming({'orto.png': img.encodePng(img.Image(width: 2, height: 2))}, twoGb))), bomb);
      expect(_fresh().describeError(const FormatException('zip_too_large')), contains('compressed file'));
      // the same files with honest sizes still read
      expect(KmlReader.parseKmz(Uint8List.fromList(ZipEncoder().encodeBytes(Archive()..add(ArchiveFile.bytes('doc.kml', kml))))).placemarkCount, 1);
    });

    test('a shapefile zip decompresses only the parts of shapefiles', () {
      final arc = Archive()
        ..add(ArchiveFile.bytes('a.shp', Uint8List(100)))
        ..add(ArchiveFile.bytes('leia-me.txt', utf8.encode('x')));
      final zip = Uint8List.fromList(ZipEncoder().encodeBytes(arc));
      // the text entry claims gigabytes: it is never read
      final patched = Uint8List.fromList(zip);
      final bd = ByteData.sublistView(patched);
      for (var i = 0; i + 46 < patched.length; i++) {
        if (bd.getUint32(i, Endian.little) == 0x02014b50 && utf8.decode(patched.sublist(i + 46, i + 46 + 11), allowMalformed: true) == 'leia-me.txt') bd.setUint32(i + 24, twoGb, Endian.little);
      }
      expect(ShapefileParts.unzip(patched).single.name, 'a');
    });

    test('a link whose project expands beyond 20 MB opens nothing, a normal one opens', () {
      final huge = '{"a":"${' ' * (25 * 1024 * 1024)}"}';
      final link = shareLinkFor(huge);
      expect(link.length, lessThan(shareLinkMaxLength), reason: 'it fits a link');
      expect(_fast(() => projectJsonFromLink(link)), isNull);
      final small = jsonEncode(Project().toJson());
      expect(projectJsonFromLink(shareLinkFor(small)), small);
    });
  });

  group('shapefiles (FMT-07)', () {
    test('a record of negative length ends the reading at once, with a note', () {
      final b = ByteData(100 + 8 + 20)
        ..setInt32(0, 9994)
        ..setInt32(24, (100 + 8 + 20) ~/ 2)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, 1, Endian.little)
        ..setInt32(100, 1)
        ..setInt32(104, -4)
        ..setInt32(108, 1, Endian.little)
        ..setFloat64(112, 500000, Endian.little)
        ..setFloat64(120, 7500000, Endian.little);
      final r = _fast(() => ShpReader.parse(b.buffer.asUint8List()), ms: 2000);
      expect(r.recordCount, 0);
      expect(r.warnings, contains('shp_truncated'));
    });

    test('attribute texts in the code page of the .cpg (1251), else 1252 rather than Latin-1', () {
      final shp = ByteData(100 + 28)
        ..setInt32(0, 9994)
        ..setInt32(24, (100 + 28) ~/ 2)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, 1, Endian.little)
        ..setInt32(100, 1)
        ..setInt32(104, 10)
        ..setInt32(108, 1, Endian.little)
        ..setFloat64(112, 1, Endian.little)
        ..setFloat64(120, 2, Endian.little);
      Uint8List dbf(List<int> name) {
        final b = ByteData(32 + 32 + 1 + 1 + 20);
        b
          ..setUint8(0, 3)
          ..setUint32(4, 1, Endian.little)
          ..setUint16(8, 32 + 32 + 1, Endian.little)
          ..setUint16(10, 1 + 20, Endian.little);
        final u = b.buffer.asUint8List();
        u.setRange(32, 36, latin1.encode('NAME'));
        u[32 + 11] = 0x43; // C
        u[32 + 16] = 20;
        u[64] = 0x0D;
        u[65] = 0x20;
        u.setRange(66, 66 + 20, [...name, ...List.filled(20 - name.length, 0x20)]);
        return u;
      }

      // "Скважина" in code page 1251
      final cyr = ShpReader.parse(shp.buffer.asUint8List(), dbf: dbf([0xD1, 0xEA, 0xE2, 0xE0, 0xE6, 0xE8, 0xED, 0xE0]), cpg: '1251');
      expect(cyr.document.entities.single.name, 'Скважина');
      // without a .cpg: not UTF-8, so 1252 ("–" is 0x96 there, a control character in Latin-1)
      final west = ShpReader.parse(shp.buffer.asUint8List(), dbf: dbf([0x50, 0x6F, 0xE7, 0x6F, 0x20, 0x96, 0x20, 0x31]));
      expect(west.document.entities.single.name, 'Poço – 1');
    });

    test('the .shx index finds the records after a damaged one', () {
      // two point records; the first record header says length 0
      final shp = ByteData(100 + 2 * 28)
        ..setInt32(0, 9994)
        ..setInt32(24, (100 + 2 * 28) ~/ 2)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, 1, Endian.little);
      final shx = ByteData(100 + 2 * 8)
        ..setInt32(0, 9994)
        ..setInt32(24, (100 + 2 * 8) ~/ 2);
      for (var k = 0; k < 2; k++) {
        final o = 100 + 28 * k;
        shp
          ..setInt32(o, k + 1)
          ..setInt32(o + 4, k == 0 ? 0 : 10)
          ..setInt32(o + 8, 1, Endian.little)
          ..setFloat64(o + 12, 10.0 + k, Endian.little)
          ..setFloat64(o + 20, 20.0 + k, Endian.little);
        shx
          ..setInt32(100 + 8 * k, o ~/ 2)
          ..setInt32(104 + 8 * k, 10);
      }
      final plain = ShpReader.parse(shp.buffer.asUint8List());
      expect(plain.recordCount, 0, reason: 'without the index the damaged length stops the reading');
      final indexed = ShpReader.parse(shp.buffer.asUint8List(), shx: shx.buffer.asUint8List());
      expect(indexed.recordCount, 2);
      expect(indexed.document.entities.map((e) => e.points.single), const [Pt(10, 20), Pt(11, 21)]);
    });
  });

  group('GeoTIFF (FMT-03, 04, 33)', () {
    final plane = [
      for (var r = 0; r < 8; r++) [for (var c = 0; c < 8; c++) 500.0 + r * 1.5 + c * 0.25],
    ];

    test('SIRGAS 2000, SAD 69 and other zones are placed through latitude and longitude', () {
      GeoImage at(int epsg) {
        final t = TiffTags()
          ..shorts[34735] = [1, 1, 0, 2, 1024, 0, 1, 1, 3072, 0, 1, epsg]
          ..doubles[33550] = [1, 1, 0]
          ..doubles[33922] = [0, 0, 0, 700000, 7500000, 0];
        final g = GeoImageReader.tiffGeo(t);
        return GeoImage(
          bytes: Uint8List(0),
          mime: 'image/png',
          widthPx: 100,
          heightPx: 100,
          worldTopLeft: g.topLeft,
          pixelSizeX: g.sx,
          pixelSizeY: g.sy,
          crs: g.crs,
          utmZone: g.zone,
          utmNorth: g.north,
        );
      }

      const project = GeoReference(zone: 23, north: false, originEasting: 699000, originNorthing: 7499000);
      for (final epsg in [32723, 31983]) {
        final g = at(epsg);
        expect(g.crs!.recognised, isTrue, reason: '$epsg');
        final (bl, w, h, _, ref) = placeGeoImage(g, project);
        expect(bl, predicate<Pt>((p) => p.distanceTo(const Pt(1000, 900)) < 1e-3), reason: '$epsg');
        expect(w, closeTo(100, 1e-6));
        expect(h, closeTo(100, 1e-6));
        expect(ref, project);
      }
      // SAD 69 sits some 65 m from SIRGAS 2000, and says so
      final sad = at(29193);
      final (blSad, _, _, _, _) = placeGeoImage(sad, project);
      expect(blSad.distanceTo(const Pt(1000, 900)), inInclusiveRange(30, 100));
      expect(crsNotes(sad.crs).single, startsWith('crs_datum_shift:sad69'));
      // zone 22S into a 23S project: the corner through lat/lon
      final (bl22, _, _, rot22, _) = placeGeoImage(at(31982), project);
      final (lat, lon) = utmToLatLon(700000, 7499900, 22, false);
      final (x, y) = project.fromLatLon(lat, lon);
      expect(bl22.distanceTo(Pt(x, y)), lessThan(0.05));
      expect(rot22.abs(), greaterThan(0.5), reason: 'grid convergence between the zones');
      // without a project georeference one is created in the raster's zone
      final (_, _, _, _, made) = placeGeoImage(at(31983), null);
      expect(made!.zone, 23);
      expect(made.north, isFalse);
      // a projection given key by key is not used, and said
      final user = GeoImageReader.tiffGeo(TiffTags()..shorts[34735] = [1, 1, 0, 2, 1024, 0, 1, 1, 3072, 0, 1, 32767]);
      expect(user.crs!.problem, 'crs_projection_unsupported');
    });

    test('a float DEM with the floating-point predictor reads as without it (Deflate, LZW, none, tiles)', () {
      // the LZW coder of this test against the picture decoder of the image package
      final greyRows = [
        for (var r = 0; r < 6; r++) [for (var c = 0; c < 7; c++) (r * 7 + c) * 3.0],
      ];
      final grey = img.decodeTiff(_tiff(greyRows, compression: 5, grey: true))!;
      expect(grey.getPixel(4, 3).r, 75);
      for (final (compression, tile) in [(8, null), (5, null), (1, null), (8, 4), (5, 4)]) {
        final dem = GeoTiffDemReader.read(_tiff(plane, predictor: 3, compression: compression, tile: tile), maxPoints: 64)!;
        final z = [for (final s in dem.samples) s.z]..sort();
        expect(z.length, 64, reason: 'compression $compression tile $tile');
        expect(z.first, closeTo(500, 1e-4));
        expect(z.last, closeTo(512.25, 1e-4));
        expect(dem.warnings, isEmpty);
      }
      // sampled: a 4 × 4 grid of the 8 × 8 pixels
      final coarse = GeoTiffDemReader.read(_tiff(plane, predictor: 3, compression: 5, tile: 4), maxPoints: 16)!;
      expect(coarse.samples.length, 16);
    });

    test('heights beyond ±10 km are left out and a raster of zeros is said', () {
      final wild = [
        for (var r = 0; r < 4; r++) [for (var c = 0; c < 4; c++) r == 0 && c < 2 ? 1e7 : 600.0],
      ];
      final dem = GeoTiffDemReader.read(_tiff(wild))!;
      expect(dem.samples.length, 14);
      expect(dem.warnings, contains('dem_out_of_range:2'));
      final zeros = GeoTiffDemReader.read(_tiff([for (var r = 0; r < 4; r++) List.filled(4, 0.0)]))!;
      expect(zeros.warnings, contains('dem_all_zero'));
    });

    test('the picture decoder\'s own errors become the app\'s codes', () {
      // a PNG header claiming 20 000 × 20 000 pixels
      final ihdr = ByteData(13)
        ..setUint32(0, 20000)
        ..setUint32(4, 20000)
        ..setUint8(8, 8)
        ..setUint8(9, 2);
      final crc = getCrc32([...latin1.encode('IHDR'), ...ihdr.buffer.asUint8List()]);
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0, 0, 0, 13, ...latin1.encode('IHDR'), ...ihdr.buffer.asUint8List(),
        (crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF,
      ]);
      expect(() => decodeImageSafe(png), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_too_large')));
      expect(() => GeoImageReader.read('orto.png', png), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_too_large')));
      expect(imageError(img.ImageException('Image dimensions 30000x30000 exceed the maximum of 268435456 pixels')).message, 'image_too_large');
      expect(imageError(img.ImageException('Invalid image data: RangeError')).message, 'image_unreadable');
    });
  });

  group('points from text files (FMT-14, 15, 25, 28)', () {
    test('P,E,N,Z without a header and headers with units', () {
      final penz = PointsCsvReader.parse('1,250000.123,7500000.456,600.1\n2,250010.5,7500010.25,601.3\n');
      expect(penz.document.entities.first.points.first, const Pt(250000.123, 7500000.456));
      expect(penz.warnings, contains('points_order:P, E, N, Z'));
      final pnez = PointsCsvReader.parse('1,7500000.456,250000.123,600.1\n2,7500010.25,250010.5,601.3\n');
      expect(pnez.document.entities.first.points.first, const Pt(250000.123, 7500000.456));
      expect(pnez.warnings, contains('points_order:P, N, E, Z'));
      for (final header in ['Ponto;E (m);N (m);Cota (m)', 'Ponto;Leste;Norte;Cota', 'Nº;Coord. E;Coord. N;Z [m]']) {
        final r = PointsCsvReader.parse('$header\n1;250000,123;7500000,456;600,1\n');
        expect(r.document.entities.first.points.first, const Pt(250000.123, 7500000.456), reason: header);
        expect(r.document.entities.first.elevation, closeTo(600.1, 1e-9), reason: header);
        expect(r.warnings, isEmpty, reason: header);
      }
    });

    test('latitude, longitude without a header (the order of map links) lands in Rio', () {
      final r = PointsCsvReader.parse('-22.906800,-43.172900,10.5\n-22.907100,-43.173400,11.2\n-22.906500,-43.172100,9.8\n');
      expect(r.georef!.zone, 23);
      expect(r.georef!.north, isFalse);
      expect(r.warnings, contains('points_latlon_assumed:lat, lon'));
      // longitude beyond 90°: no doubt, no note
      final asia = PointsCsvReader.parse('35.68120,139.76710,40\n35.68130,139.76720,41\n');
      expect(asia.georef!.zone, 54);
      expect(asia.warnings, isEmpty);
    });

    test('a text saved as "Unicode text" (UTF-16 with its mark) and UTF-8 with a mark import', () {
      const content = 'Ponto\tE\tN\tCota\r\n1\t250000,123\t7500000,456\t600,1\r\n2\t250010,123\t7500010,456\t601,1\r\n';
      final utf16 = <int>[0xFF, 0xFE];
      for (final u in content.codeUnits) {
        utf16
          ..add(u & 0xFF)
          ..add(u >> 8);
      }
      final c = _fresh();
      c.importFile('pontos.txt', Uint8List.fromList(utf16));
      final spots = c.project.entities.whereType<SpotHeightEntity>().toList();
      expect(spots.length, 2);
      expect(spots.first.elevation, closeTo(600.1, 1e-9));
      final g = _fresh();
      g.importFile(
        'area.geojson',
        Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode('{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"name":"Poço"},"geometry":{"type":"Point","coordinates":[-47.1,-22.1]}}]}'),
        ]),
      );
      expect(g.project.entities, isNotEmpty);
    });

    test('degrees and decimal minutes, letters before the values, degrees minutes seconds with spaces', () {
      Matcher near(double lat, double lon) => predicate<(double, double)?>((v) => v != null && (v.$1 - lat).abs() < 1e-6 && (v.$2 - lon).abs() < 1e-6, '($lat, $lon)');
      const rio = (-22.906805555555554, -43.172888888888885);
      expect(parseLatLon("22°54.408'S 43°10.373'W"), near(-22.9068, -43.172883333333335));
      expect(parseLatLon('S 22°54\'24.5" W 43°10\'22.4"'), near(rio.$1, rio.$2));
      expect(parseLatLon('S22 54 24.5 W43 10 22.4'), near(rio.$1, rio.$2));
      expect(parseLatLon('22 54 24.5 S, 43 10 22.4 W'), near(rio.$1, rio.$2));
      expect(parseLatLon('22°54\'24.5"S 43°10\'22.4"O'), near(rio.$1, rio.$2), reason: 'O for oeste');
      expect(parseLatLon('-22.9068 -43.1729 12'), near(-22.9068, -43.1729), reason: 'an altitude after the pair');
      // still the old forms
      expect(parseLatLon('-22.9068, -43.1729'), near(-22.9068, -43.1729));
      expect(parseLatLon('lat -22,9068 lon -43,1729'), near(-22.9068, -43.1729));
      expect(parseLatLon('22º 54\' S 43º 10\' W'), near(-22.9, -43.166666666666664));
      // what cannot be read one way only gives nothing
      expect(parseLatLon('22 54 S 23 10 S'), isNull, reason: 'two latitudes');
      expect(parseLatLon('22°75\'S 43°10\'W'), isNull, reason: 'minutes beyond 59');
      expect(parseLatLon('22 54 24'), isNull);
    });
  });

  group('points without an elevation (FMT-01)', () {
    test('KML pins, 2D DXF points and a point list without Z become markers, never 0 m spot heights', () {
      final c = _fresh();
      const kml =
          '<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document><Folder><name>Fazenda</name>'
          '<Placemark><name>Poço</name><Point><coordinates>-47.1000,-22.1000,0</coordinates></Point></Placemark>'
          '<Placemark><name>Reservatório</name><Point><coordinates>-47.1010,-22.1010,0</coordinates></Point></Placemark>'
          '</Folder></Document></kml>';
      c.importFile('fazenda.kml', Uint8List.fromList(utf8.encode(kml)));
      expect(c.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      expect(c.project.entities.whereType<CircleEntity>().map((e) => e.name), containsAll(['Poço', 'Reservatório']));
      final d = _fresh();
      const dxf = '0\nSECTION\n2\nENTITIES\n0\nPOINT\n8\nPOCOS\n10\n5\n20\n5\n30\n0.0\n0\nENDSEC\n0\nEOF\n';
      d.importFile('pocos.dxf', Uint8List.fromList(utf8.encode(dxf)));
      expect(d.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      expect(d.project.entities.whereType<CircleEntity>(), hasLength(1));
      final p = _fresh();
      p.importFile('estacas.csv', Uint8List.fromList(utf8.encode('x;y\n10;10\n20;10\n')));
      expect(p.project.entities.whereType<SpotHeightEntity>(), isEmpty);
      expect(p.project.entities.whereType<CircleEntity>(), hasLength(2));
      expect(p.project.buildTerrain().samples, isEmpty);
    });
  });

  group('drawings into the project (FMT-13, 16, 31)', () {
    test('a drawing in UTM is moved by the origin of a georeferenced project; without one, the note says so', () {
      const dxf = '0\nSECTION\n2\nENTITIES\n0\nLINE\n8\nLOTE\n10\n700000\n20\n7500000\n11\n700100\n21\n7500100\n0\nENDSEC\n0\nEOF\n';
      final c = _fresh();
      c.project.meta.georef = const GeoReference(zone: 23, north: false, originEasting: 699900, originNorthing: 7499900);
      final s = c.importFile('levantamento.dxf', Uint8List.fromList(utf8.encode(dxf)));
      expect(c.project.entities.whereType<LineEntity>().single.a, const Pt(100, 100));
      expect(s, contains(c.t('warn.cad_moved_to_georef')));
      final n = _fresh();
      final s2 = n.importFile('levantamento.dxf', Uint8List.fromList(utf8.encode(dxf)));
      expect(n.project.entities.whereType<LineEntity>().single.a, const Pt(700000, 7500000));
      expect(s2, contains(n.t('warn.cad_utm_no_georef')));
    });

    test('layers are matched without regard to case and keep the colour and state of the file', () {
      final c = _fresh();
      final before = c.project.layers.length;
      c.project.layers.add(Layer(name: 'TUBOS', color: 0xFF112233));
      const dxf =
          '0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n'
          '0\nLAYER\n2\nTubos\n70\n0\n62\n1\n'
          '0\nLAYER\n2\nCONSTRUCAO\n70\n0\n62\n-30\n'
          '0\nLAYER\n2\nCONGELADO\n70\n1\n62\n140\n'
          '0\nLAYER\n2\nCOR\n70\n0\n62\n5\n420\n1193046\n'
          '0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n'
          '0\nLINE\n8\nTubos\n10\n0\n20\n0\n11\n1\n21\n0\n'
          '0\nENDSEC\n0\nEOF\n';
      c.importFile('rede.dxf', Uint8List.fromList(utf8.encode(dxf)));
      expect(c.project.layers.where((l) => l.name.toLowerCase() == 'tubos'), hasLength(1));
      expect(c.project.entities.whereType<LineEntity>().single.layer, 'TUBOS');
      Layer layer(String n) => c.project.layers.firstWhere((l) => l.name == n);
      expect(layer('CONSTRUCAO').visible, isFalse, reason: 'off (negative colour)');
      expect(layer('CONSTRUCAO').color, 0xFF000000 | aciRgb(30));
      expect(layer('CONGELADO').visible, isFalse, reason: 'frozen');
      expect(layer('COR').color, 0xFF123456, reason: 'true colour');
      expect(c.project.layers.length, before + 4);
    });
  });

  group('reading in slices (FMT-23)', () {
    String bigDxf(int n) {
      final b = StringBuffer('0\nSECTION\n2\nENTITIES\n');
      for (var i = 0; i < n; i++) {
        b.write('0\nLINE\n8\nL\n10\n$i\n20\n0\n11\n$i\n21\n1\n');
      }
      b.write('0\nENDSEC\n0\nEOF\n');
      return b.toString();
    }

    test('a large DXF imports as the plain import does, telling its progress', () async {
      final bytes = Uint8List.fromList(utf8.encode(bigDxf(40000)));
      final c = _fresh();
      final seen = <double>[];
      final s = await c.importFileAsync('grande.dxf', bytes, WorkSlicer(sliceMs: 2, onProgress: seen.add));
      expect(c.project.entities.whereType<LineEntity>(), hasLength(40000));
      expect(s, contains('40000'));
      expect(seen.length, greaterThan(2));
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
      final sync = _fresh()..importFile('grande.dxf', bytes);
      expect(sync.project.entities.length, c.project.entities.length);
    });

    test('cancelled, it changes nothing', () async {
      final bytes = Uint8List.fromList(utf8.encode(bigDxf(40000)));
      final c = _fresh();
      final n = c.project.entities.length;
      late WorkSlicer slicer;
      slicer = WorkSlicer(sliceMs: 1, onProgress: (f) => slicer.cancel());
      await expectLater(c.importFileAsync('grande.dxf', bytes, slicer), throwsA(isA<ImportCancelled>()));
      expect(c.project.entities.length, n);
      expect(c.canUndo, isFalse);
    });
  });

  group('exports (FMT-29, 32)', () {
    test('XML of KML and spreadsheets leaves out the characters XML forbids', () {
      expect(xmlText('Válvula\u000b1 <a & "b">\u0001 \u{1F600} \uD800x'), 'Válvula1 &lt;a &amp; &quot;b&quot;&gt; \u{1F600} x');
      final kml = KmlWriter.write([
        GeoFeature(name: 'Válvula\u000b1', folder: 'V', type: 'Point', coords: [(-47.0, -22.0, 0.0)]),
      ]);
      expect(kml, isNot(contains('\u000b')));
      expect(kml, contains('Válvula1'));
      final x = XlsxWriter.write([
        XlsxSheet(
          name: 'T',
          headers: ['a'],
          rows: [
            ['x\u0001y'],
          ],
        ),
      ]);
      expect(XlsxReader.read(x).single.rows.single.single, 'xy');
    });

    test('GeoJSON carries numbers as numbers and its rings counter-clockwise', () {
      final clockwise = GeoFeature(
        name: 'Talhão',
        folder: 'AREAS',
        type: 'Polygon',
        coords: [(-47.0, -22.0, 0.0), (-47.0, -21.99, 0.0), (-46.99, -21.99, 0.0), (-46.99, -22.0, 0.0)],
        data: {'area_ha': '12.500', 'crop': '123'},
        numeric: const {'area_ha'},
      );
      final j = jsonDecode(GeoJsonWriter.write([clockwise])) as Map<String, dynamic>;
      final f = (j['features'] as List).single as Map<String, dynamic>;
      expect(f['properties']['area_ha'], 12.5);
      expect(f['properties']['crop'], '123', reason: 'text stays text');
      final ring = ((f['geometry']['coordinates'] as List).single as List).cast<List>();
      var area = 0.0;
      for (var i = 0; i + 1 < ring.length; i++) {
        area += (ring[i][0] as num) * (ring[i + 1][1] as num) - (ring[i + 1][0] as num) * (ring[i][1] as num);
      }
      expect(area, greaterThan(0));
    });
  });
}
