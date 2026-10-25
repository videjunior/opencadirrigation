/// Raster export of a drawing sheet: the sheet [PdfSheetBuilder.recordSheet]
/// records (the same layout as the PDF page: frame, drawing, legend, title
/// block) painted with dart:ui at a chosen resolution and encoded as PNG.
/// lib/core has no rasteriser, so this lives in the app layer.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/io/pdf.dart' show PdfAlign;
import '../../core/io/pdf_sheet.dart';
import '../../core/io/sheet_canvas.dart';
import '../state/controller.dart';
import '../widgets/dialogs/export_dialogs.dart';
import 'file_io.dart';

/// Largest raster the export makes (pixels); a sheet that would be larger
/// at the chosen resolution gets a lower one (an A0 sheet at 300 dpi would
/// need over half a gigabyte of memory).
const pngMaxPixels = 40e6;

/// Longest side of the raster (pixels): the largest texture many WebGL
/// implementations draw into, where the web build paints the sheet.
const pngMaxSide = 8192.0;

/// The resolution a sheet of [widthPt] × [heightPt] points gets for [dpi],
/// lowered to stay within [pngMaxPixels] and [pngMaxSide].
double pngDpiFor(double widthPt, double heightPt, double dpi) {
  var d = dpi;
  final px = (widthPt / 72 * d) * (heightPt / 72 * d);
  if (px > pngMaxPixels) d *= math.sqrt(pngMaxPixels / px);
  final side = math.max(widthPt, heightPt) / 72 * d;
  if (side > pngMaxSide) d *= pngMaxSide / side;
  return d;
}

/// Encodes [sheet] as a PNG at [dpi] on a white background.
Future<Uint8List> renderSheetPng(RecordedSheet sheet, {double dpi = 200}) async {
  final d = pngDpiFor(sheet.width, sheet.height, dpi);
  final scale = d / 72; // pixels per point
  final w = math.max(1, (sheet.width * scale).round()), h = math.max(1, (sheet.height * scale).round());
  // images first: dart:ui decodes asynchronously; each at the pixels it
  // needs at this resolution (the sheet asks for them at 250 dpi)
  final images = Map<Uint8List, ui.Image>.identity();
  for (final op in sheet.images) {
    if (images.containsKey(op.bytes)) continue;
    final im = await _decode(
      op.bytes,
      op.maxWidthPx == null ? null : (op.maxWidthPx! * d / PdfSheetBuilder.imageDpi).ceil(),
      op.maxHeightPx == null ? null : (op.maxHeightPx! * d / PdfSheetBuilder.imageDpi).ceil(),
    );
    if (im != null) images[op.bytes] = im;
  }
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  sheet.replay(UiSheetCanvas(canvas, sheet.width, sheet.height, scale, images));
  final picture = rec.endRecording();
  final image = await picture.toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
    for (final im in images.values) {
      im.dispose();
    }
  }
}

Future<ui.Image?> _decode(Uint8List bytes, int? maxW, int? maxH) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    var s = 1.0;
    if (maxW != null && maxW > 0 && desc.width > maxW) s = math.min(s, maxW / desc.width);
    if (maxH != null && maxH > 0 && desc.height > maxH) s = math.min(s, maxH / desc.height);
    final codec = await desc.instantiateCodec(targetWidth: math.max(1, (desc.width * s).round()), targetHeight: math.max(1, (desc.height * s).round()));
    final frame = await codec.getNextFrame();
    codec.dispose();
    desc.dispose();
    buffer.dispose();
    return frame.image;
  } on Object catch (e) {
    debugPrint('png export: image skipped ($e)');
    return null;
  }
}

/// [SheetCanvas] on a dart:ui canvas: points (y up, origin bottom-left) to
/// pixels (y down), with the PDF graphics state (colours, width, dash,
/// opacity) kept across save/restore.
class UiSheetCanvas implements SheetCanvas {
  UiSheetCanvas(this.canvas, this.width, this.height, this.scale, [Map<Uint8List, ui.Image>? images]) : images = images ?? Map.identity();
  final ui.Canvas canvas;
  @override
  final double width;
  @override
  final double height;

  /// Pixels per point.
  final double scale;

  /// Decoded images by the bytes the sheet holds (identity).
  final Map<Uint8List, ui.Image> images;

  int _stroke = 0xFF000000, _fill = 0xFF000000;
  double _lineWidth = 1, _dashOn = 3, _dashOff = 2, _alpha = 1;
  bool _dashed = false;
  final _stack = <(int, int, double, bool, double, double, double)>[];

  ui.Offset _p(double x, double y) => ui.Offset(x * scale, (height - y) * scale);
  ui.Color _c(int argb) => ui.Color.fromARGB((((argb >> 24) & 0xFF) * _alpha).round().clamp(0, 255), (argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

  ui.Paint get _strokePaint => ui.Paint()
    ..color = _c(_stroke)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = math.max(0.5, _lineWidth * scale)
    ..strokeJoin = ui.StrokeJoin.miter
    ..strokeCap = ui.StrokeCap.butt
    ..isAntiAlias = true;

  ui.Paint get _fillPaint => ui.Paint()
    ..color = _c(_fill)
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  void save() {
    canvas.save();
    _stack.add((_stroke, _fill, _lineWidth, _dashed, _dashOn, _dashOff, _alpha));
  }

  @override
  void restore() {
    canvas.restore();
    if (_stack.isEmpty) return;
    final (stroke, fill, width, dashed, on, off, alpha) = _stack.removeLast();
    _stroke = stroke;
    _fill = fill;
    _lineWidth = width;
    _dashed = dashed;
    _dashOn = on;
    _dashOff = off;
    _alpha = alpha;
  }

  @override
  void strokeColor(int argb) => _stroke = argb;
  @override
  void fillColor(int argb) => _fill = argb;
  @override
  void lineWidth(double pt) => _lineWidth = pt;
  @override
  void dash(bool on, [double dashPt = 3, double gapPt = 2]) {
    _dashed = on;
    _dashOn = dashPt;
    _dashOff = gapPt;
  }

  @override
  void opacity(double alpha) => _alpha = (_alpha * alpha).clamp(0.0, 1.0);

  @override
  void path(List<(double, double)> pts, {bool close = false, bool stroke = true, bool fill = false}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      canvas.drawCircle(_p(pts.first.$1, pts.first.$2), 0.5 * scale, _fillPaint);
      return;
    }
    final offsets = [for (final (x, y) in pts) _p(x, y)];
    final path = ui.Path()..addPolygon(offsets, close);
    if (fill) canvas.drawPath(path, _fillPaint);
    if (!stroke) return;
    if (_dashed) {
      _dashedLine(close ? [...offsets, offsets.first] : offsets);
    } else {
      canvas.drawPath(path, _strokePaint);
    }
  }

  /// Dashes along [pts] ([_dashOn] on, [_dashOff] off, in points).
  void _dashedLine(List<ui.Offset> pts) {
    final on = math.max(0.1, _dashOn * scale), off = math.max(0.1, _dashOff * scale);
    final paint = _strokePaint;
    var drawing = true;
    var left = on;
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1];
      final b = pts[i];
      var seg = (b - a).distance;
      if (seg <= 0) continue;
      final u = (b - a) / seg;
      while (seg > 0) {
        final step = math.min(left, seg);
        final next = a + u * step;
        if (drawing) canvas.drawLine(a, next, paint);
        a = next;
        seg -= step;
        left -= step;
        if (left <= 1e-9) {
          drawing = !drawing;
          left = drawing ? on : off;
        }
      }
    }
  }

  @override
  void line(double x1, double y1, double x2, double y2) => path([(x1, y1), (x2, y2)]);

  @override
  void rect(double x, double y, double w, double h, {bool stroke = true, bool fill = false}) => path([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], close: true, stroke: stroke, fill: fill);

  @override
  void circle(double cx, double cy, double r, {bool stroke = true, bool fill = false}) {
    final c = _p(cx, cy);
    if (fill) canvas.drawCircle(c, r * scale, _fillPaint);
    if (stroke) canvas.drawCircle(c, r * scale, _strokePaint);
  }

  @override
  void clipRect(double x, double y, double w, double h) => canvas.clipRect(ui.Rect.fromLTWH(x * scale, (height - y - h) * scale, w * scale, h * scale));

  @override
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left}) {
    if (s.isEmpty) return;
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: size * scale, fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal, maxLines: 1, textDirection: ui.TextDirection.ltr))
      ..pushStyle(ui.TextStyle(color: _c(_fill), fontSize: size * scale, fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal))
      ..addText(s);
    final p = b.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    final w = p.maxIntrinsicWidth;
    final dx = switch (align) {
      PdfAlign.center => -w / 2,
      PdfAlign.right => -w,
      PdfAlign.left => 0.0,
    };
    canvas.save();
    canvas.translate(x * scale, (height - y) * scale);
    if (rotationDeg != 0) canvas.rotate(-rotationDeg * math.pi / 180);
    canvas.drawParagraph(p, ui.Offset(dx, -p.alphabeticBaseline));
    canvas.restore();
    p.dispose();
  }

  @override
  void image(Uint8List bytes, String mime, (double, double) bottomLeft, (double, double) bottomRight, (double, double) topLeft, {double opacity = 1, int? maxWidthPx, int? maxHeightPx}) {
    final im = images[bytes];
    if (im == null) return;
    final iw = im.width.toDouble(), ih = im.height.toDouble();
    final (blx, bly) = bottomLeft;
    final (brx, bry) = bottomRight;
    final (tlx, tly) = topLeft;
    // image pixel (u, v), v down from the top row, to device pixels
    final a = scale * (brx - blx) / iw, b = -scale * (bry - bly) / iw;
    final c = -scale * (tlx - blx) / ih, d = scale * (tly - bly) / ih;
    final e = scale * tlx, f = scale * (height - tly);
    canvas.save();
    canvas.transform(Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]));
    canvas.drawImageRect(
      im,
      ui.Rect.fromLTWH(0, 0, iw, ih),
      ui.Rect.fromLTWH(0, 0, iw, ih),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = ui.Color.fromARGB((255 * (opacity * _alpha).clamp(0.0, 1.0)).round(), 0, 0, 0),
    );
    canvas.restore();
  }
}

/// PNG of the drawing sheet of [o] (the overview of a set) for [c].
Future<Uint8List> sheetPng(ProjectController c, SheetOptions o) => renderSheetPng(
  c.exporter().sheetBuilder().recordSheet(o.copyWith(split: SheetSplit.single, windows: const [], details: const [])),
  dpi: o.dpi,
);

/// File → Export drawing → PNG: asks the sheet options and resolution, then
/// saves the sheet as a PNG image.
Future<void> exportSheetPngAction(BuildContext context, ProjectController c) async {
  if (c.project.entities.isEmpty) {
    c.notify(c.t('msg.nothingToExport'));
    return;
  }
  final o = await showPlotDialog(context, c, raster: true);
  if (o == null) return;
  final name = c.project.meta.name.trim();
  final file = '${(name.isEmpty ? c.t('name.newProject') : name).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_')}.png';
  try {
    final png = await sheetPng(c, o);
    await saveBinaryFile(file, png, mime: 'image/png');
    c.notify(c.t('msg.exported', {'f': file}));
  } catch (e, st) {
    debugPrint('$e\n$st');
    c.notify(c.t('msg.error', {'e': c.describeError(e)}));
  }
}
