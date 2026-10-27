/// SVG writer for a [PlotScene]: a fixed-scale sheet in millimetres, usable
/// in browsers, vector drawing programs and as an embeddable figure. Images and background
/// rasters are embedded as data URIs (downsampled to [SvgWriter.imageDpi] at
/// their printed size) and placed with a transform.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'plot.dart';

class SvgWriter {
  /// Print resolution of embedded images, dots per inch on paper.
  static const imageDpi = 250.0;

  /// Renders [scene] with a [marginMm] border. User units are millimetres.
  static String write(PlotScene scene, {double marginMm = 10, String title = '', Map<String, String>? layerNames}) {
    final b = scene.bounds.isEmpty ? const Bounds(0, 0, 100, 100) : scene.bounds;
    final mm = scene.unitsPerMm;
    final w = b.width / mm + 2 * marginMm;
    final h = b.height / mm + 2 * marginMm;
    double sx(double x) => (x - b.minX) / mm + marginMm;
    double sy(double y) => (b.maxY - y) / mm + marginMm;
    String n(double v) {
      final s = v.toStringAsFixed(3);
      return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
    }

    String hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    String fillOpacity(double alpha) => alpha < 1 ? ' fill-opacity="${n(alpha)}"' : '';
    final hasImages = scene.rasters.isNotEmpty || scene.items.any((it) => it is PlotImage);
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg"${hasImages ? ' xmlns:xlink="http://www.w3.org/1999/xlink"' : ''} width="${n(w)}mm" height="${n(h)}mm" viewBox="0 0 ${n(w)} ${n(h)}" font-family="Helvetica, Arial, sans-serif">');
    if (title.isNotEmpty) out.writeln('<title>${_esc(title)}</title>');
    out.writeln('<desc>OpenCADIrrigation · 1:${scene.scaleDenominator.round()} · mm</desc>');
    out.writeln('<rect width="100%" height="100%" fill="#ffffff"/>');

    void image(Uint8List bytes, String mime, List<Pt> corners, double opacity) {
      if (corners.length < 4) return;
      final tl = (sx(corners[3].x), sy(corners[3].y)), tr = (sx(corners[2].x), sy(corners[2].y)), bl = (sx(corners[0].x), sy(corners[0].y));
      final wMm = math.sqrt(math.pow(tr.$1 - tl.$1, 2) + math.pow(tr.$2 - tl.$2, 2)), hMm = math.sqrt(math.pow(bl.$1 - tl.$1, 2) + math.pow(bl.$2 - tl.$2, 2));
      final data = _dataUri(bytes, mime, (wMm / 25.4 * imageDpi).ceil(), (hMm / 25.4 * imageDpi).ceil());
      if (data == null) return;
      final op = opacity < 1 ? ' opacity="${n(opacity)}"' : '';
      out.writeln('<image x="0" y="0" width="1" height="1" preserveAspectRatio="none" transform="matrix(${n(tr.$1 - tl.$1)} ${n(tr.$2 - tl.$2)} ${n(bl.$1 - tl.$1)} ${n(bl.$2 - tl.$2)} ${n(tl.$1)} ${n(tl.$2)})"$op xlink:href="$data"/>');
    }

    if (scene.rasters.isNotEmpty) {
      out.writeln('<g id="background">');
      for (final r in scene.rasters) {
        image(r.bytes, r.mime, r.corners, r.opacity);
      }
      out.writeln('</g>');
    }
    // one group per layer: image layers, then filled layers (areas, wetted
    // radii) so their fills stay under the linework, then layers in order of
    // first appearance
    final order = <String>[];
    for (final it in scene.items) {
      if (!order.contains(it.layer)) order.add(it.layer);
    }
    final images = order.where((l) => scene.items.any((it) => it.layer == l && it is PlotImage)).toList();
    final filled = order
        .where((l) => !images.contains(l) && scene.items.any((it) => it.layer == l && ((it is PlotPath && it.fillColor != null && it.points.length > 2) || (it is PlotCircle && it.fillColor != null && it.radius / mm > 3))))
        .toList();
    final ordered = [...images, ...filled, ...order.where((l) => !filled.contains(l) && !images.contains(l))];
    for (final layer in ordered) {
      out.writeln('<g id="${_esc(_id(layer))}" data-layer="${_esc(layerNames?[layer] ?? layer)}" stroke-linecap="round" stroke-linejoin="round">');
      for (final it in scene.items) {
        if (it.layer != layer) continue;
        switch (it) {
          case PlotImage im:
            image(im.bytes, im.mime, im.corners, im.opacity);
          case PlotPath p:
            final d = StringBuffer();
            for (var i = 0; i < p.points.length; i++) {
              d.write('${i == 0 ? 'M' : 'L'}${n(sx(p.points[i].x))} ${n(sy(p.points[i].y))}');
            }
            if (p.closed) d.write('Z');
            final fill = p.fillColor != null ? hex(p.fillColor!) : 'none';
            final dash = p.dashed ? ' stroke-dasharray="${n(p.widthMm * 6)} ${n(p.widthMm * 4)}"' : '';
            out.writeln('<path d="$d" fill="$fill"${fillOpacity(p.fillOpacity)} stroke="${hex(p.color)}" stroke-width="${n(p.widthMm)}"$dash/>');
          case PlotCircle c:
            final fill = c.fillColor != null ? hex(c.fillColor!) : 'none';
            final stroke = c.stroke ? ' stroke="${hex(c.color)}" stroke-width="${n(c.widthMm)}"' : '';
            out.writeln('<circle cx="${n(sx(c.center.x))}" cy="${n(sy(c.center.y))}" r="${n(c.radius / mm)}" fill="$fill"${fillOpacity(c.fillOpacity)}$stroke/>');
          case PlotText t:
            final size = t.heightMm * 1.35; // font size so that cap height ≈ heightMm
            final anchor = switch (t.anchor) { PlotAnchor.bottomCenter || PlotAnchor.center => 'middle', PlotAnchor.bottomRight => 'end', _ => 'start' };
            final baseline = switch (t.anchor) { PlotAnchor.center || PlotAnchor.centerLeft => ' dominant-baseline="middle"', _ => '' };
            final x = sx(t.position.x), y = sy(t.position.y);
            final rot = t.rotationDeg != 0 ? ' transform="rotate(${n(-t.rotationDeg)} ${n(x)} ${n(y)})"' : '';
            final weight = t.bold ? ' font-weight="bold"' : '';
            out.writeln('<text x="${n(x)}" y="${n(y)}" font-size="${n(size)}" fill="${hex(t.color)}" text-anchor="$anchor"$baseline$weight$rot>${_esc(t.text)}</text>');
        }
      }
      out.writeln('</g>');
    }
    if (scene.attribution.isNotEmpty) {
      out.writeln('<text x="${n(w - marginMm / 2)}" y="${n(h - marginMm / 3)}" font-size="1.8" fill="#8a8f94" text-anchor="end">${_esc(scene.attribution)}</text>');
    }
    out.writeln('</svg>');
    return out.toString();
  }

  /// Data URI of an image, re-encoded smaller when it has more pixels than
  /// [maxW] × [maxH] needs; null when the data cannot be decoded.
  static String? _dataUri(Uint8List bytes, String mime, int maxW, int maxH) {
    final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    var data = bytes;
    var type = isJpeg ? 'image/jpeg' : (isPng ? 'image/png' : mime);
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      final tooBig = info != null && maxW > 0 && maxH > 0 && (info.width > maxW * 1.25 || info.height > maxH * 1.25);
      if (tooBig || !(isJpeg || isPng)) {
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return null;
        var im = decoded;
        if (tooBig) {
          final s = math.min(maxW / im.width, maxH / im.height);
          im = img.copyResize(im, width: math.max(1, (im.width * s).round()), height: math.max(1, (im.height * s).round()), interpolation: img.Interpolation.average);
        }
        if (isJpeg) {
          data = Uint8List.fromList(img.encodeJpg(im, quality: 88));
          type = 'image/jpeg';
        } else {
          data = Uint8List.fromList(img.encodePng(im));
          type = 'image/png';
        }
      }
    } on Object {
      return null;
    }
    return 'data:$type;base64,${base64Encode(data)}';
  }

  static String _id(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
