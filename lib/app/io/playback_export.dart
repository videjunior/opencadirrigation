/// The irrigation programme played on the plan, exported (1.7.0): a moment
/// as a PNG and the cycle as an animated GIF, rendered off screen.
///
/// The drawing under the frames is drawn once, as the assistant's pictures
/// draw it (vision_render.dart: the canvas painter through a camera set for
/// the picture, on the dark canvas, with the base map's tiles when asked
/// and its credit in the corner); every frame is that image with the moment
/// painted over it (playback_overlay.dart), so a frame costs the overlay
/// alone. The GIF is assembled frame by frame (core/io/gif_animation.dart):
/// the memory of one frame, progress after each, and a cancel between them.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/design/programme_playback.dart';
import '../../core/io/gif_animation.dart';
import '../../core/model/geometry.dart';
import '../ai/vision_render.dart';
import '../ai/vision_mapping.dart' show PictureFrame;
import '../canvas/playback_overlay.dart';
import '../project_name.dart';
import '../state/controller.dart';
import '../theme.dart';

/// Longest side (pixels) of the animation by default, and the choices.
const playbackGifSide = 480;
const playbackGifSides = [320, 480, 640, 800];

/// Longest side (pixels) of a frame exported as a PNG.
const playbackPngSide = 1600;

/// Time a frame of the animation shows (hundredths of a second).
const playbackGifDelayCs = 25;

/// The file name of an export of the programme of [c] with [ext].
String playbackFileName(ProjectController c, String ext) => '${projectFileStem(c.t, c.project.meta.name)}_${c.t('ply.file')}.$ext';

/// An animation made.
class PlaybackGif {
  const PlaybackGif(this.bytes, this.frames, this.width, this.height);
  final Uint8List bytes;
  final int frames, width, height;
}

/// The drawing under the frames over [world], [maxSide] pixels at most,
/// with the base map on screen when [baseMap] (and a georeference).
Future<(ui.Image, PictureFrame)> _base(ProjectController c, Bounds world, int maxSide, {required bool baseMap, VisionRenderer? renderer}) async {
  final r = renderer ?? const CanvasSnapshots();
  final map = baseMap && c.baseMap != BaseMap.none && c.project.meta.georef != null;
  final shot = await r.render(
    c,
    VisionSpec(
      world: world,
      maxSide: maxSide,
      maxPixels: maxSide * maxSide,
      maps: map ? [c.baseMap] : const [],
      grid: GridDensity.none,
      background: true,
      mapOpacity: c.baseMapOpacity,
      onScreenFallback: false,
      overlay: OverlayMode.none,
      showLabels: false,
    ),
  );
  final codec = await ui.instantiateImageCodec(shot.png);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return (frame.image, shot.frame);
}

/// Moment [hour] of [pb] over [base]: the picture of one frame, the band
/// of the moment over the drawing ([playbackBandHeight] pixels).
ui.Picture _frame(ProjectController c, ProgrammePlayback pb, ui.Image base, PictureFrame f, double hour, {required bool timeBar}) {
  final rec = ui.PictureRecorder();
  final band = playbackBandHeight(f.width, timeBar: timeBar);
  final size = Size(f.width.toDouble(), f.height.toDouble());
  final canvas = Canvas(rec, Rect.fromLTWH(0, 0, size.width, size.height + band));
  final frame = pb.frameAt(hour);
  final view = PlaybackPaintView(toScreen: f.toPx, scale: 1 / f.mpp, visible: f.world, size: size);
  // the dark canvas of the drawing under it
  Cad.paintWith(CadPalette.dark, () {
    canvas.save();
    canvas.translate(0, band);
    canvas.drawImage(base, Offset.zero, Paint());
    paintPlayback(canvas, view, c, pb, frame, look: const PlaybackLook(panel: false));
    canvas.restore();
    paintPlaybackBand(canvas, Size(size.width, band), c, pb, frame, timeBar: timeBar);
  });
  return rec.endRecording();
}

/// Height in pixels of a frame of [f] with its band.
int _height(PictureFrame f, {required bool timeBar}) => f.height + playbackBandHeight(f.width, timeBar: timeBar).round();

/// Moment [hour] of [pb] as a PNG over [world] (the groups by default).
Future<Uint8List> playbackPng(ProjectController c, ProgrammePlayback pb, double hour, {int maxSide = playbackPngSide, bool baseMap = false, Bounds? world, VisionRenderer? renderer}) async {
  final (base, f) = await _base(c, world ?? playbackWorld(c, pb), maxSide, baseMap: baseMap, renderer: renderer);
  final pic = _frame(c, pb, base, f, hour, timeBar: false);
  final im = await pic.toImage(f.width, _height(f, timeBar: false));
  try {
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    im.dispose();
    pic.dispose();
    base.dispose();
  }
}

/// The cycle of [pb] as an animated GIF of about [frames] frames
/// (`playbackFrameTimes`) over [world], [maxSide] pixels at most;
/// [onProgress] after every frame; null when [cancelled] says so between
/// two frames.
Future<PlaybackGif?> playbackGif(
  ProjectController c,
  ProgrammePlayback pb, {
  int maxSide = playbackGifSide,
  int? frames,
  bool baseMap = false,
  Bounds? world,
  VisionRenderer? renderer,
  void Function(int done, int total)? onProgress,
  bool Function()? cancelled,
}) async {
  final times = playbackFrameTimes(pb.timeline, frames ?? playbackDefaultFrames(pb.timeline.days));
  final (base, f) = await _base(c, world ?? playbackWorld(c, pb), maxSide, baseMap: baseMap, renderer: renderer);
  try {
    final h = _height(f, timeBar: true);
    final gif = GifAnimation(width: f.width, height: h, delayCs: playbackGifDelayCs);
    for (var k = 0; k < times.length; k++) {
      if (cancelled?.call() ?? false) return null;
      final pic = _frame(c, pb, base, f, times[k], timeBar: true);
      final im = await pic.toImage(f.width, h);
      try {
        final data = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
        gif.add(data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      } finally {
        im.dispose();
        pic.dispose();
      }
      onProgress?.call(k + 1, times.length);
      // a frame for the progress and the Cancel button
      await Future<void>.delayed(Duration.zero);
    }
    if (cancelled?.call() ?? false) return null;
    final bytes = gif.finish();
    return bytes == null ? null : PlaybackGif(bytes, gif.frames, f.width, h);
  } finally {
    base.dispose();
  }
}
