import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/version.dart' show appReleaseDate, appVersion;

import '../../tool/gen_brand.dart' show renderBrand;
import '../../tool/site.dart' show siteLastMod;

/// Generated files whose generators had no guard: the brand images
/// (tool/gen_brand.dart) and the date the site pages declare.
void main() {
  test('the brand images are what tool/gen_brand.dart draws from web/brand', () {
    final stale = <String>[];
    for (final e in renderBrand().entries) {
      final f = File(e.key);
      if (!f.existsSync()) {
        stale.add('${e.key}: missing');
        continue;
      }
      final bytes = f.readAsBytesSync();
      final committed = e.key.endsWith('.ico') ? _icoFrames(bytes) : [img.decodePng(bytes)];
      if (committed.length != e.value.length) {
        stale.add('${e.key}: ${committed.length} images, the generator draws ${e.value.length}');
        continue;
      }
      for (var i = 0; i < committed.length; i++) {
        final why = _difference(committed[i], e.value[i]);
        if (why != null) stale.add('${e.key}${committed.length > 1 ? ' #$i' : ''}: $why');
      }
    }
    expect(stale, isEmpty, reason: 'out of date: run dart run tool/gen_brand.dart\n${stale.join('\n')}');
  });

  test('the site is not dated before the release it announces', () {
    // the pages carry the app version (footer, JSON-LD softwareVersion), so a
    // release changes them: sitemap lastmod and dateModified must follow
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(siteLastMod), isTrue, reason: siteLastMod);
    expect(
      siteLastMod.compareTo(appReleaseDate) >= 0,
      isTrue,
      reason: 'tool/site.dart siteLastMod $siteLastMod is older than the release date $appReleaseDate of $appVersion: bump it and run dart run tool/gen_site.dart',
    );
  });
}

List<img.Image?> _icoFrames(Uint8List bytes) {
  final dec = img.IcoDecoder();
  final info = dec.startDecode(bytes);
  if (info == null) return [null];
  return [for (var i = 0; i < info.numFrames; i++) dec.decodeFrame(i)];
}

/// Largest difference of a channel (colour premultiplied by alpha, 0-255)
/// still taken as the same image: the image package rounds its cubic
/// resampling and compositing a little differently from one release to
/// the next (±1 level, and any colour under a nearly transparent pixel),
/// while an edited logo moves hundreds of levels.
const _tolerance = 3;

/// Why [committed] is not [drawn] (size or the worst pixel), or null.
String? _difference(img.Image? committed, img.Image drawn) {
  if (committed == null) return 'not a readable image';
  if (committed.width != drawn.width || committed.height != drawn.height) return '${committed.width}x${committed.height}, the generator draws ${drawn.width}x${drawn.height}';
  var worst = 0, wx = 0, wy = 0;
  for (var y = 0; y < drawn.height; y++) {
    for (var x = 0; x < drawn.width; x++) {
      final a = committed.getPixel(x, y), b = drawn.getPixel(x, y);
      final aa = a.a.toInt(), ba = b.a.toInt();
      var d = (aa - ba).abs();
      for (final (ca, cb) in [(a.r, b.r), (a.g, b.g), (a.b, b.b)]) {
        final pa = ca.toInt() * aa ~/ 255, pb = cb.toInt() * ba ~/ 255;
        if ((pa - pb).abs() > d) d = (pa - pb).abs();
      }
      if (d > worst) (worst, wx, wy) = (d, x, y);
    }
  }
  if (worst <= _tolerance) return null;
  return 'pixel ($wx, $wy) is ${committed.getPixel(wx, wy).toList()}, the generator draws ${drawn.getPixel(wx, wy).toList()}';
}
