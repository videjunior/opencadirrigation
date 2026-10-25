/// Paper drawing surface of the sheet builders, in points with the origin at
/// the bottom-left corner of the page and y up (the PDF convention), so one
/// sheet layout serves every output: [PdfSheetCanvas] draws on a PDF page,
/// [SheetRecorder] keeps the drawing as a list of operations that other
/// writers replay (the PNG export of the app paints it with dart:ui).
library;

import 'dart:typed_data';

import 'pdf.dart';

/// Drawing operations of a sheet (the subset of [PdfPage] the sheets use).
abstract interface class SheetCanvas {
  /// Page size in points.
  double get width;
  double get height;
  void save();
  void restore();
  void strokeColor(int argb);
  void fillColor(int argb);
  void lineWidth(double pt);
  void dash(bool on, [double dashPt = 3, double gapPt = 2]);

  /// Fill and stroke opacity of what follows (inside save/restore).
  void opacity(double alpha);
  void path(List<(double, double)> pts, {bool close = false, bool stroke = true, bool fill = false});
  void line(double x1, double y1, double x2, double y2);
  void rect(double x, double y, double w, double h, {bool stroke = true, bool fill = false});
  void circle(double cx, double cy, double r, {bool stroke = true, bool fill = false});

  /// Rectangular clip of what follows (inside save/restore).
  void clipRect(double x, double y, double w, double h);

  /// [s] with its baseline at (x, y); [size] in points.
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left});

  /// Encoded image [bytes] on the parallelogram of [bottomLeft],
  /// [bottomRight] and [topLeft]; [maxWidthPx] × [maxHeightPx] are the pixels
  /// it needs at its printed size (larger images may be downsampled).
  void image(Uint8List bytes, String mime, (double, double) bottomLeft, (double, double) bottomRight, (double, double) topLeft, {double opacity = 1, int? maxWidthPx, int? maxHeightPx});
}

/// [SheetCanvas] on a PDF page: every call goes straight to the page, so a
/// sheet drawn through it is the same PDF as one drawn on the page itself.
class PdfSheetCanvas implements SheetCanvas {
  PdfSheetCanvas(this.page);
  final PdfPage page;

  @override
  double get width => page.width;
  @override
  double get height => page.height;
  @override
  void save() => page.save();
  @override
  void restore() => page.restore();
  @override
  void strokeColor(int argb) => page.strokeColor(argb);
  @override
  void fillColor(int argb) => page.fillColor(argb);
  @override
  void lineWidth(double pt) => page.lineWidth(pt);
  @override
  void dash(bool on, [double dashPt = 3, double gapPt = 2]) => page.dash(on, dashPt, gapPt);
  @override
  void opacity(double alpha) => page.opacity(alpha);
  @override
  void path(List<(double, double)> pts, {bool close = false, bool stroke = true, bool fill = false}) => page.path(pts, close: close, stroke: stroke, fill: fill);
  @override
  void line(double x1, double y1, double x2, double y2) => page.line(x1, y1, x2, y2);
  @override
  void rect(double x, double y, double w, double h, {bool stroke = true, bool fill = false}) => page.rect(x, y, w, h, stroke: stroke, fill: fill);
  @override
  void circle(double cx, double cy, double r, {bool stroke = true, bool fill = false}) => page.circle(cx, cy, r, stroke: stroke, fill: fill);
  @override
  void clipRect(double x, double y, double w, double h) => page.clipRect(x, y, w, h);
  @override
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left}) =>
      page.text(x, y, s, size: size, bold: bold, rotationDeg: rotationDeg, align: align);
  @override
  void image(Uint8List bytes, String mime, (double, double) bottomLeft, (double, double) bottomRight, (double, double) topLeft, {double opacity = 1, int? maxWidthPx, int? maxHeightPx}) {
    final doc = page.document;
    if (doc == null) return;
    final im = doc.image(bytes, mime: mime, maxWidthPx: maxWidthPx, maxHeightPx: maxHeightPx);
    if (im == null) return;
    page.image(im, bottomLeft, bottomRight, topLeft, opacity: opacity);
  }
}

/// One recorded drawing operation.
sealed class SheetOp {
  const SheetOp();

  /// Performs the operation on [c].
  void replay(SheetCanvas c);
}

class SheetSaveOp extends SheetOp {
  const SheetSaveOp();
  @override
  void replay(SheetCanvas c) => c.save();
}

class SheetRestoreOp extends SheetOp {
  const SheetRestoreOp();
  @override
  void replay(SheetCanvas c) => c.restore();
}

class SheetStrokeColorOp extends SheetOp {
  const SheetStrokeColorOp(this.color);
  final int color;
  @override
  void replay(SheetCanvas c) => c.strokeColor(color);
}

class SheetFillColorOp extends SheetOp {
  const SheetFillColorOp(this.color);
  final int color;
  @override
  void replay(SheetCanvas c) => c.fillColor(color);
}

class SheetLineWidthOp extends SheetOp {
  const SheetLineWidthOp(this.width);
  final double width;
  @override
  void replay(SheetCanvas c) => c.lineWidth(width);
}

class SheetDashOp extends SheetOp {
  const SheetDashOp(this.on, this.dash, this.gap);
  final bool on;
  final double dash, gap;
  @override
  void replay(SheetCanvas c) => c.dash(on, dash, gap);
}

class SheetOpacityOp extends SheetOp {
  const SheetOpacityOp(this.alpha);
  final double alpha;
  @override
  void replay(SheetCanvas c) => c.opacity(alpha);
}

class SheetPathOp extends SheetOp {
  const SheetPathOp(this.points, {this.close = false, this.stroke = true, this.fill = false});
  final List<(double, double)> points;
  final bool close, stroke, fill;
  @override
  void replay(SheetCanvas c) => c.path(points, close: close, stroke: stroke, fill: fill);
}

class SheetRectOp extends SheetOp {
  const SheetRectOp(this.x, this.y, this.w, this.h, {this.stroke = true, this.fill = false});
  final double x, y, w, h;
  final bool stroke, fill;
  @override
  void replay(SheetCanvas c) => c.rect(x, y, w, h, stroke: stroke, fill: fill);
}

class SheetCircleOp extends SheetOp {
  const SheetCircleOp(this.cx, this.cy, this.r, {this.stroke = true, this.fill = false});
  final double cx, cy, r;
  final bool stroke, fill;
  @override
  void replay(SheetCanvas c) => c.circle(cx, cy, r, stroke: stroke, fill: fill);
}

class SheetClipOp extends SheetOp {
  const SheetClipOp(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  @override
  void replay(SheetCanvas c) => c.clipRect(x, y, w, h);
}

class SheetTextOp extends SheetOp {
  const SheetTextOp(this.x, this.y, this.text, {this.size = 10, this.bold = false, this.rotationDeg = 0, this.align = PdfAlign.left});
  final double x, y;
  final String text;
  final double size;
  final bool bold;
  final double rotationDeg;
  final PdfAlign align;
  @override
  void replay(SheetCanvas c) => c.text(x, y, text, size: size, bold: bold, rotationDeg: rotationDeg, align: align);
}

class SheetImageOp extends SheetOp {
  const SheetImageOp(this.bytes, this.mime, this.bottomLeft, this.bottomRight, this.topLeft, {this.opacity = 1, this.maxWidthPx, this.maxHeightPx});
  final Uint8List bytes;
  final String mime;
  final (double, double) bottomLeft, bottomRight, topLeft;
  final double opacity;
  final int? maxWidthPx, maxHeightPx;
  @override
  void replay(SheetCanvas c) => c.image(bytes, mime, bottomLeft, bottomRight, topLeft, opacity: opacity, maxWidthPx: maxWidthPx, maxHeightPx: maxHeightPx);
}

/// A sheet kept as its drawing operations.
class RecordedSheet {
  const RecordedSheet(this.width, this.height, this.ops);

  /// Page size in points.
  final double width, height;
  final List<SheetOp> ops;

  /// Draws the sheet on [c] (a PDF page, a raster canvas…).
  void replay(SheetCanvas c) {
    for (final op in ops) {
      op.replay(c);
    }
  }

  /// Every text drawn, in order.
  Iterable<String> get texts => ops.whereType<SheetTextOp>().map((o) => o.text);

  /// The images, in drawing order (a raster writer decodes them first).
  Iterable<SheetImageOp> get images => ops.whereType<SheetImageOp>();
}

/// [SheetCanvas] that records what is drawn on it.
class SheetRecorder implements SheetCanvas {
  SheetRecorder(this.width, this.height);
  @override
  final double width;
  @override
  final double height;
  final List<SheetOp> _ops = [];

  RecordedSheet get sheet => RecordedSheet(width, height, List.unmodifiable(_ops));

  @override
  void save() => _ops.add(const SheetSaveOp());
  @override
  void restore() => _ops.add(const SheetRestoreOp());
  @override
  void strokeColor(int argb) => _ops.add(SheetStrokeColorOp(argb));
  @override
  void fillColor(int argb) => _ops.add(SheetFillColorOp(argb));
  @override
  void lineWidth(double pt) => _ops.add(SheetLineWidthOp(pt));
  @override
  void dash(bool on, [double dashPt = 3, double gapPt = 2]) => _ops.add(SheetDashOp(on, dashPt, gapPt));
  @override
  void opacity(double alpha) => _ops.add(SheetOpacityOp(alpha));
  @override
  void path(List<(double, double)> pts, {bool close = false, bool stroke = true, bool fill = false}) => _ops.add(SheetPathOp(List.unmodifiable(pts), close: close, stroke: stroke, fill: fill));
  @override
  void line(double x1, double y1, double x2, double y2) => path([(x1, y1), (x2, y2)]);
  @override
  void rect(double x, double y, double w, double h, {bool stroke = true, bool fill = false}) => _ops.add(SheetRectOp(x, y, w, h, stroke: stroke, fill: fill));
  @override
  void circle(double cx, double cy, double r, {bool stroke = true, bool fill = false}) => _ops.add(SheetCircleOp(cx, cy, r, stroke: stroke, fill: fill));
  @override
  void clipRect(double x, double y, double w, double h) => _ops.add(SheetClipOp(x, y, w, h));
  @override
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left}) {
    if (s.isEmpty) return;
    _ops.add(SheetTextOp(x, y, s, size: size, bold: bold, rotationDeg: rotationDeg, align: align));
  }

  @override
  void image(Uint8List bytes, String mime, (double, double) bottomLeft, (double, double) bottomRight, (double, double) topLeft, {double opacity = 1, int? maxWidthPx, int? maxHeightPx}) =>
      _ops.add(SheetImageOp(bytes, mime, bottomLeft, bottomRight, topLeft, opacity: opacity, maxWidthPx: maxWidthPx, maxHeightPx: maxHeightPx));
}
