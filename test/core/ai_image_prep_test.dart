import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/ai/image_prep.dart';

/// A [w] × [h] picture: a smooth gradient, with noise as a photo has.
img.Image picture(int w, int h, {bool noise = false, int seed = 1}) {
  final r = math.Random(seed);
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = noise ? r.nextInt(60) : 0;
      im.setPixelRgb(x, y, (x * 255 ~/ w + n).clamp(0, 255), (y * 255 ~/ h + n).clamp(0, 255), (128 + n).clamp(0, 255));
    }
  }
  return im;
}

/// Pictures the user attaches, as the models take them: the real type from
/// the bytes, as they are when they fit, otherwise upright, scaled into the
/// limits and as a JPEG within the size.
void main() {
  test('a picture that fits goes as it is, with the type its bytes have (not the one its name gave)', () {
    final png = img.encodePng(picture(300, 200));
    final p = prepareModelImage(png)!;
    expect(p.changed, isFalse);
    expect(identical(p.bytes, png), isTrue);
    expect((p.mediaType, p.width, p.height), ('image/png', 300, 200));
    final jpg = img.encodeJpg(picture(300, 200));
    expect(prepareModelImage(jpg)!.mediaType, 'image/jpeg');
    expect(sniffImageType(Uint8List.fromList('GIF89a....'.codeUnits)), 'image/gif');
    expect(sniffImageType(Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])), 'image/webp');
    expect(sniffImageType(Uint8List.fromList([1, 2, 3])), isNull);
    expect(prepareModelImage(Uint8List.fromList(List.filled(64, 7))), isNull, reason: 'not a picture');
  });

  test('too large a picture is scaled to 2000 px a side and the visual-token limit, as a JPEG', () {
    final p = prepareModelImage(img.encodePng(picture(3000, 1200)))!;
    expect(p.changed, isTrue);
    expect(p.mediaType, 'image/jpeg');
    expect(math.max(p.width, p.height), lessThanOrEqualTo(maxModelImageEdge));
    expect(visualTokens(p.width, p.height), lessThanOrEqualTo(maxModelImageTokens));
    expect(p.width / p.height, closeTo(2.5, 0.01), reason: 'the proportions stay');
    final back = img.decodeJpg(p.bytes)!;
    expect((back.width, back.height), (p.width, p.height));
    // a square one: the token limit, not the side, is what binds
    final (w, h) = fitModelImage(2000, 2000);
    expect(w, h);
    expect(visualTokens(w, h), lessThanOrEqualTo(maxModelImageTokens));
    expect(w, greaterThan(1850));
    expect(fitModelImage(800, 600), (800, 600), reason: 'never scaled up');
  });

  test('a photo turned by its EXIF orientation is turned upright (the models read no metadata)', () {
    final im = picture(400, 200)..exif.imageIfd.orientation = 6;
    final jpg = img.encodeJpg(im);
    expect(img.decodeJpgExif(jpg)!.imageIfd.orientation, 6);
    final p = prepareModelImage(jpg)!;
    expect(p.changed, isTrue);
    expect((p.width, p.height), (200, 400));
    expect(img.decodeJpgExif(p.bytes)?.imageIfd.orientation ?? 1, lessThanOrEqualTo(1));
  });

  test('other types (BMP), animations and transparency become a JPEG of the first frame on white', () {
    final bmp = prepareModelImage(img.encodeBmp(picture(120, 80)))!;
    expect(bmp.mediaType, 'image/jpeg');
    expect((bmp.width, bmp.height), (120, 80));

    final anim = img.Image(width: 40, height: 30, numChannels: 3)..frameType = img.FrameType.animation;
    img.fill(anim, color: img.ColorRgb8(200, 0, 0));
    final second = img.Image(width: 40, height: 30, numChannels: 3);
    img.fill(second, color: img.ColorRgb8(0, 0, 200));
    anim.addFrame(second);
    final gif = img.encodeGif(anim);
    expect(img.GifDecoder().startDecode(gif), isNotNull);
    final g = prepareModelImage(gif)!;
    expect(g.mediaType, 'image/jpeg');
    final red = img.decodeJpg(g.bytes)!.getPixel(20, 15);
    expect(red.r, greaterThan(150), reason: 'the first frame');

    final clear = img.Image(width: 64, height: 64, numChannels: 4);
    final p = prepareModelImage(img.encodePng(clear), maxEdge: 32)!;
    expect((p.mediaType, p.width, p.height), ('image/jpeg', 32, 32));
    final px = img.decodeJpg(p.bytes)!.getPixel(10, 10);
    expect(px.r, greaterThan(240), reason: 'transparent becomes white');
  });

  test('over the size limit: quality, then size come down until it fits', () {
    final png = img.encodePng(picture(1600, 1200, noise: true));
    expect(png.length, greaterThan(1000000));
    final p = prepareModelImage(png, maxBytes: 120000)!;
    expect(p.bytes.length, lessThanOrEqualTo(120000));
    expect(p.mediaType, 'image/jpeg');
  });

  test('a large lossless photo goes as a much smaller JPEG at its own size (positions on it hold)', () {
    final png = img.encodePng(picture(1200, 900, noise: true, seed: 3));
    expect(png.length, greaterThan(1500000));
    final p = prepareModelImage(png)!;
    expect(p.mediaType, 'image/jpeg');
    expect((p.width, p.height), (1200, 900));
    expect(p.bytes.length, lessThan(0.6 * png.length));
    // below the threshold it stays lossless
    expect(prepareModelImage(png, recodeAbove: png.length)!.mediaType, 'image/png');
  });

  test('the JPEG of a rendered picture (RGBA rows as dart:ui gives them)', () {
    final rgba = Uint8List(16 * 8 * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba
        ..[i] = 10
        ..[i + 1] = 200
        ..[i + 2] = 30
        ..[i + 3] = 255;
    }
    final jpg = encodeJpegRgba(rgba, 16, 8);
    final back = img.decodeJpg(jpg)!;
    expect((back.width, back.height), (16, 8));
    expect(back.getPixel(3, 3).g, greaterThan(180));
  });
}
