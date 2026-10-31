import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/model/geometry.dart';

/// The drawing of the canvas kept between frames.
///
/// Moving the cursor repaints the canvas for the snap marker, the tool
/// preview, the crosshair and the item under the cursor, while the drawing
/// itself (base map, entities, results, labels) stays as it was. The scene
/// is therefore recorded once per change of what it shows (the content
/// key: the project, the selection, the base map...; and the view) and,
/// from the second frame on that shows the same scene, drawn from a picture
/// of it: a project of tens of thousands of items then costs one image per
/// frame instead of every item.
///
/// A scene that takes long to draw is not drawn again on every frame of a
/// pan or a zoom either: its picture is moved and scaled with the view (as
/// map viewers do) and the scene is drawn sharp once the view rests for a
/// moment, or every [refreshAfter] while it keeps moving.
class SceneCache {
  SceneCache({this.onSettle});

  /// Asks for a frame (the canvas repaints) once the view has rested after
  /// a move shown with the moved picture.
  VoidCallback? onSettle;

  Object? _key;
  Pt? _center;
  double _scale = 0;
  ui.Picture? _picture;
  ui.Image? _image;
  double _dpr = 1;
  Size _size = Size.zero;

  /// Milliseconds the last scene took to record and to rasterise.
  double _recordMs = 0, _rasterMs = 0;
  final Stopwatch _sinceDrawn = Stopwatch();
  Timer? _settle;
  bool _drawNow = false;

  /// Pictures larger than this many device pixels are not rasterised (the
  /// copy would cost more memory than it saves time).
  static const maxPixels = 16 * 1024 * 1024;

  /// A scene that takes longer than this (milliseconds) follows the view
  /// as a picture while the view moves.
  static const heavyMs = 20.0;

  /// The view must rest this long before a moved picture is drawn again.
  static const settleAfter = Duration(milliseconds: 120);

  /// While the view keeps moving, a moved picture is drawn again after this
  /// long (milliseconds; at least five times what the scene takes), so the
  /// parts that came into view fill in.
  static const refreshAfter = 300;

  static final _imagePaint = Paint()..filterQuality = FilterQuality.low;

  /// True when drawing the scene takes long enough to move its picture
  /// instead of drawing it on every frame of a pan or a zoom.
  bool get heavy => _recordMs + _rasterMs > heavyMs;

  /// Draws the scene for [key] seen from [center] at [scale] into
  /// [canvas], recording it with [record] when the cached one does not
  /// fit. [background] fills what a moved picture leaves uncovered.
  void paint(Canvas canvas, Size size, double devicePixelRatio, Object key, Pt center, double scale, Color background, void Function(Canvas canvas, Size size) record) {
    final same = _picture != null && key == _key && size == _size && devicePixelRatio == _dpr;
    if (same && center == _center && scale == _scale) {
      // the same scene again: from now on it is drawn as one image
      if (_image == null) _rasterise();
      _draw(canvas);
      return;
    }
    if (same && !_drawNow && heavy && _sinceDrawn.elapsedMilliseconds < math.max(refreshAfter, 5 * (_recordMs + _rasterMs))) {
      // only the view moved: move the picture, draw the scene sharp later
      if (_image == null) _rasterise();
      final img = _image;
      if (img != null) {
        _settle?.cancel();
        _settle = Timer(settleAfter, () {
          _drawNow = true;
          onSettle?.call();
        });
        final a = scale / _scale;
        canvas.drawRect(Offset.zero & size, Paint()..color = background);
        canvas.save();
        canvas.translate(size.width / 2 + (_center!.x - center.x) * scale, size.height / 2 - (_center!.y - center.y) * scale);
        canvas.scale(a);
        canvas.translate(-size.width / 2, -size.height / 2);
        _draw(canvas);
        canvas.restore();
        return;
      }
    }
    _drawNow = false;
    _settle?.cancel();
    final sw = Stopwatch()..start();
    final rec = ui.PictureRecorder();
    record(Canvas(rec), size);
    _replace(rec.endRecording(), key, center, scale, size, devicePixelRatio);
    _recordMs = sw.elapsedMicroseconds / 1000;
    _sinceDrawn
      ..reset()
      ..start();
    // drawn as recorded: it becomes an image on the next frame that shows
    // it again or moves it (the copy costs a read back from the GPU, not
    // worth paying for a scene that is about to change again)
    canvas.drawPicture(_picture!);
  }

  void _draw(Canvas canvas) {
    final img = _image;
    if (img == null) {
      canvas.drawPicture(_picture!);
      return;
    }
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(0, 0, img.width / _dpr, img.height / _dpr), _imagePaint);
  }

  void _replace(ui.Picture picture, Object key, Pt center, double scale, Size size, double dpr) {
    _picture?.dispose();
    _image?.dispose();
    _image = null;
    _picture = picture;
    _key = key;
    _center = center;
    _scale = scale;
    _size = size;
    _dpr = dpr;
  }

  void _rasterise() {
    final pic = _picture;
    if (pic == null) return;
    final w = (_size.width * _dpr).ceil(), h = (_size.height * _dpr).ceil();
    if (w <= 0 || h <= 0 || w * h > maxPixels) return;
    final sw = Stopwatch()..start();
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..scale(_dpr)
      ..drawPicture(pic);
    final scaled = rec.endRecording();
    try {
      _image = scaled.toImageSync(w, h);
    } catch (_) {
      // no rasteriser here (some test hosts): keep drawing the picture
      _image = null;
    } finally {
      scaled.dispose();
    }
    _rasterMs = sw.elapsedMicroseconds / 1000;
  }

  /// Forgets the scene (it is recorded again on the next frame).
  void clear() {
    _settle?.cancel();
    _picture?.dispose();
    _image?.dispose();
    _picture = null;
    _image = null;
    _key = null;
    _center = null;
  }

  void dispose() {
    onSettle = null;
    clear();
  }
}
