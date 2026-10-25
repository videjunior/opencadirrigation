/// The pixel ↔ world mapping of the pictures the AI assistant is shown, and
/// the pictures of a conversation by id ("s1", "s2"…; "u1"… for the ones the
/// user attaches), so that a position the model picks on an image becomes
/// project coordinates without the model doing the arithmetic.
///
/// Every picture is north up with square pixels: pixel (0, 0) is the
/// top-left corner of its world rectangle, px grows to the right (east) and
/// py downwards (south), so world x = minX + px·s and y = maxY − py·s, with
/// s the metres per pixel.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../core/model/geometry.dart';
import '../../core/units.dart';
import 'vision_tiles.dart';

/// Pixels of a picture at most. Both providers take an image of about this
/// size as it is; a larger one is scaled down on their side, and the model
/// would then read positions on another pixel grid than the one described.
const maxPicturePixels = 1150000;

/// Longest side of a picture (the providers' limit) and its default.
const maxPictureSide = 1568;
const defaultPictureSide = 1024;

/// A world rectangle drawn on [width] × [height] square pixels, north up.
class PictureFrame {
  const PictureFrame(this.world, this.width, this.height);

  /// Exactly the area of the image: left = minX, top = maxY.
  final Bounds world;
  final int width, height;

  /// Metres per pixel, the same along x and y.
  double get mpp => world.width / width;

  Pt toWorld(double px, double py) => Pt(world.minX + px * mpp, world.maxY - py * mpp);
  (double, double) toPixel(Pt p) => ((p.x - world.minX) / mpp, (world.maxY - p.y) / mpp);
  Offset toPx(Pt p) => Offset((p.x - world.minX) / mpp, (world.maxY - p.y) / mpp);
  bool contains(double px, double py) => px >= 0 && py >= 0 && px <= width && py <= height;

  /// The frame for [world] with its longest side at most [maxSide] pixels
  /// and at most [maxPixels] in all: the size in pixels and the rectangle
  /// grown around the same centre to square pixels.
  static PictureFrame fit(Bounds world, int maxSide, {int maxPixels = maxPicturePixels}) {
    final ww = math.max(world.width, 1e-3), wh = math.max(world.height, 1e-3);
    final ar = ww / wh;
    var w = ar >= 1 ? maxSide.toDouble() : maxSide * ar;
    var h = ar >= 1 ? maxSide / ar : maxSide.toDouble();
    if (w * h > maxPixels) {
      final f = math.sqrt(maxPixels / (w * h));
      w *= f;
      h *= f;
    }
    final iw = math.max(64, w.round()), ih = math.max(64, h.round());
    final s = math.max(ww / iw, wh / ih);
    final c = world.center;
    return PictureFrame(Bounds(c.x - iw * s / 2, c.y - ih * s / 2, c.x + iw * s / 2, c.y + ih * s / 2), iw, ih);
  }
}

/// A picture the model was shown, by its id.
class SnapshotMapping extends PictureFrame {
  const SnapshotMapping(this.id, super.world, super.width, super.height, {this.what = 'the drawing'});
  final String id;

  /// What it shows ("the drawing over Esri World Imagery").
  final String what;

  /// Decimals that keep the metres per pixel exact to well under a pixel
  /// across the image.
  int get _decimals => mpp < 0.01 ? 6 : (mpp < 1 ? 5 : 4);

  /// The mapping in words, for the model.
  String describe() {
    String m(double v) => fmt(v, 2);
    final s = fmt(mpp, _decimals);
    return 'Picture $id: $what; $width×$height px PNG, north up, square pixels. World bbox [minX, minY, maxX, maxY] = [${m(world.minX)}, ${m(world.minY)}, ${m(world.maxX)}, ${m(world.maxY)}] m; '
        's = $s m per pixel. Pixel (px, py) counted from the top-left corner (px right, py down) ↔ world x = minX + px·s = ${m(world.minX)} + px·$s, y = maxY − py·s = ${m(world.maxY)} − py·$s. '
        'Use image_to_world {snapshot "$id", pixels [[px, py], …]} rather than computing.';
  }
}

/// The pictures and the downloaded map tiles of one conversation (or, for
/// the pictures the user attaches, of one project tab).
class VisionSession {
  final Map<String, SnapshotMapping> _pictures = {};
  int _seq = 0;

  /// Map tiles already downloaded in this conversation.
  final TileCache tiles = TileCache();

  /// Mapping of the last picture of the drawing shown after a change.
  String? lastFeedback;

  /// Pictures kept (the oldest are forgotten first).
  static const keep = 80;

  /// A new picture id with [prefix] ("s" for the tools, "u" for the user's).
  String nextId(String prefix) => '$prefix${++_seq}';

  SnapshotMapping add(String id, PictureFrame f, String what) {
    final m = SnapshotMapping(id, f.world, f.width, f.height, what: what);
    _pictures[id] = m;
    while (_pictures.length > keep) {
      _pictures.remove(_pictures.keys.first);
    }
    return m;
  }

  SnapshotMapping? operator [](String id) => _pictures[id.trim().toLowerCase()];

  Iterable<String> get ids => _pictures.keys;

  static final Expando<VisionSession> _of = Expando<VisionSession>('vision');

  /// The session of [owner]: an AgentToolbox (one conversation) or a
  /// ProjectController (the pictures the user attached in that tab).
  static VisionSession of(Object owner) => _of[owner] ??= VisionSession();
}
