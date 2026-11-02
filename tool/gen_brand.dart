/// Generates the icon set and in-app brand assets from web/brand/*.png.
/// Run: dart run tool/gen_brand.dart
///
/// test/guards/generated_files_test.dart compares the committed images with
/// [renderBrand] pixel by pixel, so an edited logo without a rerun fails.
library;

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  for (final e in renderBrand().entries) {
    final bytes = encodeBrand(e.key, e.value);
    File(e.key).writeAsBytesSync(bytes);
    stdout.writeln('${e.key} ${[for (final i in e.value) '${i.width}x${i.height}'].join(' ')} (${bytes.length} bytes)');
  }
}

/// The brand images, by file (repository paths): one image per PNG, the
/// three sizes of the ICO. Read from web/brand/logo-square.png and
/// web/brand/logo-horizontal.png.
Map<String, List<img.Image>> renderBrand() {
  final square = img.decodePng(File('web/brand/logo-square.png').readAsBytesSync())!;
  final wide = img.decodePng(File('web/brand/logo-horizontal.png').readAsBytesSync())!;
  // the drop mark: opaque pixels above the wordmark (lower ~24 % of the square logo)
  final limit = (square.height * 0.76).round();
  var minX = square.width, minY = square.height, maxX = 0, maxY = 0;
  for (var y = 0; y < limit; y++) {
    for (var x = 0; x < square.width; x++) {
      if (square.getPixel(x, y).a > 40) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final mark = img.copyCrop(square, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);

  img.Image onSquare(img.Image src, int size, {double fill = 0.86, img.Color? background}) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: background ?? img.ColorRgba8(0, 0, 0, 0));
    final scale = (size * fill) / (src.width > src.height ? src.width : src.height);
    final w = (src.width * scale).round(), h = (src.height * scale).round();
    final r = img.copyResize(src, width: w, height: h, interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, r, dstX: (size - w) ~/ 2, dstY: (size - h) ~/ 2);
    return canvas;
  }

  final white = img.ColorRgba8(255, 255, 255, 255);
  final brand = img.ColorRgba8(13, 71, 161, 255); // #0D47A1
  return {
    // transparent mark for the app and the site
    'assets/brand/logo-mark.png': [onSquare(mark, 256, fill: 1.0)],
    'web/brand/logo-mark.png': [onSquare(mark, 512, fill: 1.0)],
    'web/brand/logo-mark-1024.png': [onSquare(mark, 1024, fill: 1.0)],
    // wordmark for the app (About, welcome, README)
    'assets/brand/logo-horizontal.png': [img.copyResize(wide, width: 1000, interpolation: img.Interpolation.cubic)],
    // PWA icons: white background, mark centred; maskable keeps the safe zone
    'web/icons/Icon-192.png': [onSquare(mark, 192, fill: 0.84, background: white)],
    'web/icons/Icon-512.png': [onSquare(mark, 512, fill: 0.84, background: white)],
    'web/icons/Icon-maskable-192.png': [onSquare(mark, 192, fill: 0.62, background: white)],
    'web/icons/Icon-maskable-512.png': [onSquare(mark, 512, fill: 0.62, background: white)],
    'web/apple-touch-icon.png': [onSquare(mark, 180, fill: 0.82, background: white)],
    'web/favicon.png': [onSquare(mark, 64, fill: 1.0)],
    'web/favicon-32.png': [onSquare(mark, 32, fill: 1.0)],
    'web/favicon-16.png': [onSquare(mark, 16, fill: 1.0)],
    'web/favicon.ico': [onSquare(mark, 16, fill: 1.0), onSquare(mark, 32, fill: 1.0), onSquare(mark, 48, fill: 1.0)],
    // brand-blue tile for social/pinned sites
    'web/brand/logo-tile-512.png': [onSquare(mark, 512, fill: 0.7, background: brand)],
  };
}

/// The file bytes of [images] for [path]: an ICO with every size, else a PNG.
List<int> encodeBrand(String path, List<img.Image> images) => path.endsWith('.ico') ? img.IcoEncoder().encodeImages(images) : img.encodePng(images.single, level: 9);
