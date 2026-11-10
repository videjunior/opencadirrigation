import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/io/gif_animation.dart';

/// The animated GIF of the programme (1.7.0): frames of RGBA pixels go in,
/// a looping GIF89a comes out that decodes back to as many frames of the
/// same size and colours, with the frame time asked for, and the same
/// frames always give the same bytes.
void main() {
  const w = 40, h = 30;

  /// A frame: a dark background with a block of [colour] at column [x].
  Uint8List frame(int x, int colour) {
    final b = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var i = 0; i < w; i++) {
        final o = (y * w + i) * 4;
        final inBlock = i >= x && i < x + 10 && y >= 10 && y < 20;
        final c = inBlock ? colour : 0xFF1E1E1E;
        b[o] = (c >> 16) & 0xFF;
        b[o + 1] = (c >> 8) & 0xFF;
        b[o + 2] = c & 0xFF;
        b[o + 3] = 0xFF;
      }
    }
    return b;
  }

  Uint8List make() {
    final g = GifAnimation(width: w, height: h, delayCs: 25);
    g.add(frame(0, 0xFF4FC3F7));
    g.add(frame(10, 0xFF66BB6A));
    g.add(frame(20, 0xFFFFA726), delayCs: 50);
    expect(g.frames, 3);
    return g.finish()!;
  }

  test('the animation decodes back: frames, size, colours, timing and loop', () {
    final bytes = make();
    expect(String.fromCharCodes(bytes.sublist(0, 6)), 'GIF89a');
    expect(String.fromCharCodes(bytes), contains('NETSCAPE2.0'), reason: 'the loop extension');
    final anim = img.decodeGif(bytes)!;
    expect(anim.numFrames, 3);
    expect(anim.width, w);
    expect(anim.height, h);
    expect(anim.loopCount, 0, reason: 'loops for ever');
    expect([for (final f in anim.frames) f.frameDuration], [250, 250, 500]);
    // flat colours come back exactly (fewer than 256 in a frame)
    final p0 = anim.frames[0].getPixel(5, 15), p2 = anim.frames[2].getPixel(25, 15), bg = anim.frames[1].getPixel(0, 0);
    expect([p0.r, p0.g, p0.b], [0x4F, 0xC3, 0xF7]);
    expect([p2.r, p2.g, p2.b], [0xFF, 0xA7, 0x26]);
    expect([bg.r, bg.g, bg.b], [0x1E, 0x1E, 0x1E]);
  });

  test('the same frames give the same bytes', () {
    expect(make(), make());
  });

  test('a frame of the wrong size is refused; no frame, no file', () {
    final g = GifAnimation(width: w, height: h);
    expect(() => g.add(Uint8List(10)), throwsArgumentError);
    expect(g.finish(), isNull);
  });
}
