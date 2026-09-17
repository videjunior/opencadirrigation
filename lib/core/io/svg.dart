/// SVG writer for a [PlotScene]: a fixed-scale sheet in millimetres, usable
/// in browsers, Inkscape and as an embeddable figure.
library;

import '../model/geometry.dart';
import 'plot.dart';

class SvgWriter {
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
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" width="${n(w)}mm" height="${n(h)}mm" viewBox="0 0 ${n(w)} ${n(h)}" font-family="Helvetica, Arial, sans-serif">');
    if (title.isNotEmpty) out.writeln('<title>${_esc(title)}</title>');
    out.writeln('<desc>OpenCADIrrigation · 1:${scene.scaleDenominator.round()} · mm</desc>');
    out.writeln('<rect width="100%" height="100%" fill="#ffffff"/>');
    // one group per layer: filled layers (areas, wetted radii) first so their
    // fills stay under the linework, then layers in order of first appearance
    final order = <String>[];
    for (final it in scene.items) {
      if (!order.contains(it.layer)) order.add(it.layer);
    }
    final filled = order.where((l) => scene.items.any((it) => it.layer == l && ((it is PlotPath && it.fillColor != null && it.points.length > 2) || (it is PlotCircle && it.fillColor != null && it.radius / mm > 3)))).toList();
    final ordered = [...filled, ...order.where((l) => !filled.contains(l))];
    for (final layer in ordered) {
      out.writeln('<g id="${_esc(_id(layer))}" data-layer="${_esc(layerNames?[layer] ?? layer)}" stroke-linecap="round" stroke-linejoin="round">');
      for (final it in scene.items) {
        if (it.layer != layer) continue;
        switch (it) {
          case PlotPath p:
            final d = StringBuffer();
            for (var i = 0; i < p.points.length; i++) {
              d.write('${i == 0 ? 'M' : 'L'}${n(sx(p.points[i].x))} ${n(sy(p.points[i].y))}');
            }
            if (p.closed) d.write('Z');
            final fill = p.fillColor != null ? hex(p.fillColor!) : 'none';
            final dash = p.dashed ? ' stroke-dasharray="${n(p.widthMm * 6)} ${n(p.widthMm * 4)}"' : '';
            out.writeln('<path d="$d" fill="$fill" stroke="${hex(p.color)}" stroke-width="${n(p.widthMm)}"$dash/>');
          case PlotCircle c:
            final fill = c.fillColor != null ? hex(c.fillColor!) : 'none';
            final stroke = c.stroke ? ' stroke="${hex(c.color)}" stroke-width="${n(c.widthMm)}"' : '';
            out.writeln('<circle cx="${n(sx(c.center.x))}" cy="${n(sy(c.center.y))}" r="${n(c.radius / mm)}" fill="$fill"$stroke/>');
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
    out.writeln('</svg>');
    return out.toString();
  }

  static String _id(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
