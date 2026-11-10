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

import '../../core/ai/llm.dart' show AiModel, AiProvider;
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

/// The largest picture the model of a request reads as it is, pixel for
/// pixel: what the picture tools may draw for it.
class PictureLimits {
  const PictureLimits(this.maxSide, this.maxPixels, {this.maxShortSide});
  final int maxSide, maxPixels;

  /// The shorter side at most (null: no limit of its own).
  final int? maxShortSide;

  /// What Claude reads unscaled.
  static const standard = PictureLimits(maxPictureSide, maxPicturePixels);

  /// OpenAI's models at high detail scale a picture so that its shorter
  /// side is at most 768 px (and read tiles of it): a picture within that
  /// is read pixel for pixel.
  static const openai = PictureLimits(maxPictureSide, maxPicturePixels, maxShortSide: 768);

  /// Claude's high-resolution models: 2576 px and 4784 visual tokens of
  /// 28 × 28 pixels a picture (a request with more than 20 pictures takes
  /// them up to 3000 px a side, and a conversation sends every earlier
  /// picture again); 3.6 megapixels stays within the tokens whatever the
  /// proportions.
  static const high = PictureLimits(2576, 3600000);

  /// The Claude models reached through OpenRouter that read pictures at
  /// the high resolution (Claude Opus 4.7 and later).
  static final _routedHigh = RegExp(r'^anthropic/claude-(fable|mythos|opus-(4\.[789]|[5-9])|sonnet-[5-9]|haiku-[5-9])');

  static PictureLimits of(AiModel? m) => switch (m) {
    null => standard,
    AiModel(highResVision: true) => high,
    AiModel(provider: AiProvider.openai) => openai,
    AiModel(provider: AiProvider.openrouter, :final id) when _routedHigh.hasMatch(id) => high,
    AiModel(provider: AiProvider.openrouter, :final id) when id.startsWith('openai/') => openai,
    _ => standard,
  };

  /// Visual tokens of a picture of the largest size, about (for the
  /// descriptions): w·h / 784.
  int get maxTokens => (maxPixels / 784).round();
}

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

  /// The frame for [world] with its longest side at most [maxSide] pixels,
  /// its shorter one at most [maxShort] and at most [maxPixels] in all: the
  /// size in pixels and the rectangle grown around the same centre to
  /// square pixels.
  static PictureFrame fit(Bounds world, int maxSide, {int maxPixels = maxPicturePixels, int? maxShort}) {
    final ww = math.max(world.width, 1e-3), wh = math.max(world.height, 1e-3);
    final ar = ww / wh;
    var w = ar >= 1 ? maxSide.toDouble() : maxSide * ar;
    var h = ar >= 1 ? maxSide / ar : maxSide.toDouble();
    if (maxShort != null && math.min(w, h) > maxShort) {
      final f = maxShort / math.min(w, h);
      w *= f;
      h *= f;
    }
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
  const SnapshotMapping(this.id, super.world, super.width, super.height, {this.what = 'the drawing', this.geo = ''});
  final String id;

  /// What it shows ("the drawing over Esri World Imagery").
  final String what;

  /// The georeference the picture was drawn in (its plane coordinates are
  /// the project's only while it is the same).
  final String geo;

  /// Decimals that keep the metres per pixel exact to well under a pixel
  /// across the image.
  int get _decimals => mpp < 0.01 ? 6 : (mpp < 1 ? 5 : 4);

  /// The mapping in words, for the model.
  String describe() {
    String m(double v) => fmt(v, 2);
    final s = fmt(mpp, _decimals);
    return 'Picture $id: $what; $width×$height px, north up (the y axis of the project grid), square pixels. World bbox [minX, minY, maxX, maxY] = [${m(world.minX)}, ${m(world.minY)}, ${m(world.maxX)}, ${m(world.maxY)}] m; '
        's = $s m per pixel. Pixel (px, py) counted from the top-left corner of the image (px right, py down; the top-left pixel spans 0–1, its centre is (0.5, 0.5)) ↔ world x = minX + px·s = ${m(world.minX)} + px·$s, y = maxY − py·s = ${m(world.maxY)} − py·$s. '
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

  SnapshotMapping add(String id, PictureFrame f, String what, {String geo = ''}) {
    final m = SnapshotMapping(id, f.world, f.width, f.height, what: what, geo: geo);
    _pictures[id] = m;
    while (_pictures.length > keep) {
      _pictures.remove(_pictures.keys.first);
    }
    return m;
  }

  SnapshotMapping? operator [](String id) => _pictures[id.trim().toLowerCase()];

  Iterable<String> get ids => _pictures.keys;

  /// The mappings of the pictures and the id counter as JSON, to keep a
  /// conversation in the browser (the tiles are not kept).
  Map<String, Object?> toJson() => {
    'seq': _seq,
    'pictures': [
      for (final m in _pictures.values)
        {
          'id': m.id,
          'bbox': [m.world.minX, m.world.minY, m.world.maxX, m.world.maxY],
          'w': m.width,
          'h': m.height,
          'what': m.what,
          if (m.geo.isNotEmpty) 'geo': m.geo,
        },
    ],
  };

  /// Takes back the pictures of [toJson] (a conversation kept in the
  /// browser): an id already here is replaced, and new ids go on after the
  /// ones it used.
  void restore(Object? j) {
    if (j is! Map) return;
    final pictures = j['pictures'];
    for (final p in pictures is List ? pictures : const []) {
      final b = p is Map ? p['bbox'] : null;
      if (p is! Map || b is! List || b.length != 4 || !b.every((x) => x is num) || p['id'] is! String || p['w'] is! num || p['h'] is! num) continue;
      final id = p['id'] as String;
      final world = Bounds((b[0] as num).toDouble(), (b[1] as num).toDouble(), (b[2] as num).toDouble(), (b[3] as num).toDouble());
      _pictures.remove(id);
      add(id, PictureFrame(world, (p['w'] as num).toInt(), (p['h'] as num).toInt()), '${p['what'] ?? 'the drawing'}', geo: '${p['geo'] ?? ''}');
    }
    final seq = j['seq'];
    if (seq is num && seq > _seq) _seq = seq.toInt();
  }

  static final Expando<VisionSession> _of = Expando<VisionSession>('vision');

  /// The session of [owner]: an AgentToolbox (one conversation) or a
  /// ProjectController (the pictures the user attached in that tab).
  static VisionSession of(Object owner) => _of[owner] ??= VisionSession();
}
