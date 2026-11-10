/// Animated GIF (GIF89a) from frames of RGBA pixels, with the encoder of
/// the `image` package: every frame its own palette of up to 256 colours
/// (octree quantizer), no dithering (flat drawings stay flat and compress
/// well under LZW), the animation looping for ever. The same frames give
/// the same bytes.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Adds frames one by one ([add]) and gives the file ([finish]); the frames
/// are not kept, so a long animation needs the memory of one.
class GifAnimation {
  GifAnimation({required this.width, required this.height, this.delayCs = 25})
    : _enc = img.GifEncoder(delay: delayCs, repeat: 0, quantizerType: img.QuantizerType.octree, dither: img.DitherKernel.none, numColors: 256);
  final int width, height;

  /// Time each frame shows (hundredths of a second).
  final int delayCs;
  final img.GifEncoder _enc;
  int _frames = 0;

  int get frames => _frames;

  /// Adds a frame of [rgba] (straight alpha, row by row from the top, 4
  /// bytes a pixel).
  void add(Uint8List rgba, {int? delayCs}) {
    if (rgba.length != width * height * 4) throw ArgumentError('a frame of ${width}x$height needs ${width * height * 4} bytes, not ${rgba.length}');
    final frame = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, bytesOffset: rgba.offsetInBytes, numChannels: 4, order: img.ChannelOrder.rgba);
    _enc.addFrame(frame, duration: delayCs ?? this.delayCs);
    _frames++;
  }

  /// The file; null without a frame.
  Uint8List? finish() => _frames == 0 ? null : _enc.finish();
}
