import 'dart:math' as math;
import 'dart:ui';

import '../../core/model/geometry.dart';

/// World (metres, Y up) <-> screen (pixels, Y down) transform.
class Camera {
  Camera({this.center = Pt.zero, this.scale = 4, this.size = Size.zero});
  Pt center;

  /// Pixels per metre.
  double scale;
  Size size;

  Offset toScreen(Pt w) => Offset((w.x - center.x) * scale + size.width / 2, -(w.y - center.y) * scale + size.height / 2);
  Pt toWorld(Offset s) => Pt((s.dx - size.width / 2) / scale + center.x, -(s.dy - size.height / 2) / scale + center.y);

  Bounds get visible {
    final a = toWorld(Offset.zero), b = toWorld(Offset(size.width, size.height));
    return Bounds(a.x, b.y, b.x, a.y);
  }

  double get metersPerPixel => 1 / scale;

  void zoomAt(Offset screen, double factor) {
    final before = toWorld(screen);
    scale = (scale * factor).clamp(0.01, 5000);
    final after = toWorld(screen);
    center = center + (before - after);
  }

  void panPixels(Offset delta) {
    center = center - Pt(delta.dx / scale, -delta.dy / scale);
  }

  void fit(Bounds b, {double padding = 40}) {
    if (b.isEmpty || size.isEmpty) return;
    final w = b.width <= 0 ? 10.0 : b.width;
    final h = b.height <= 0 ? 10.0 : b.height;
    final sx = (size.width - 2 * padding) / w;
    final sy = (size.height - 2 * padding) / h;
    scale = math.min(sx, sy).clamp(0.01, 5000);
    center = b.center;
  }

  /// A nice grid spacing (metres) for the current zoom (~80 px apart).
  double gridStep() {
    final target = 80 / scale;
    final exp = (math.log(target) / math.ln10).floor();
    final base = math.pow(10.0, exp).toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (base * m >= target) return base * m;
    }
    return base * 10;
  }
}
