import 'dart:math' as math;

import '../../core/model/geometry.dart';
import '../../core/units.dart';

/// A point typed on the command line while a tool waits for one, as in
/// the programs of CAD: `x,y` absolute, `@dx,dy` relative to the previous point,
/// `@d<a` polar (distance and angle in degrees, counter-clockwise from +x)
/// and a bare distance `d` along the direction from the previous point to
/// the cursor ("direct distance entry"). Values are in the display unit
/// ([toSi] converts them); the separator is `,` with decimal points, or `;`
/// with decimal points or commas. Null when [text] is none of these.
Pt? parseTypedPoint(String text, {Pt? reference, Pt? cursor, double Function(double v) toSi = _same}) {
  var s = text.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  final relative = s.startsWith('@');
  if (relative) s = s.substring(1);
  double? num(String v) => v.isEmpty ? null : parseNumber(v);
  if (s.contains('<')) {
    if (reference == null) return null;
    final parts = s.split('<');
    if (parts.length != 2) return null;
    final d = num(parts[0]), a = num(parts[1]);
    if (d == null || a == null) return null;
    return reference + Pt.polar(toSi(d), a * math.pi / 180);
  }
  final sep = s.contains(';') ? ';' : ',';
  final parts = s.split(sep);
  if (parts.length == 2) {
    final x = num(parts[0]), y = num(parts[1]);
    if (x == null || y == null) return null;
    final v = Pt(toSi(x), toSi(y));
    if (!relative) return v;
    return reference == null ? null : reference + v;
  }
  if (parts.length == 1 && !relative) {
    // direct distance: along the rubber band
    final d = num(parts[0]);
    if (d == null || reference == null || cursor == null) return null;
    final dir = cursor - reference;
    if (dir.length < 1e-12) return null;
    return reference + dir.normalized * toSi(d);
  }
  return null;
}

double _same(double v) => v;

/// A bare number typed on the command line (an angle, a factor, a
/// distance), in the display unit; null for a point (`x,y`, `@…`, `d<a`)
/// or anything that is not a number.
double? parseTypedValue(String text) {
  final s = text.trim().replaceAll(' ', '');
  if (s.isEmpty || RegExp(r'[,;<@]').hasMatch(s)) return null;
  final v = parseNumber(s);
  return v != null && v.isFinite ? v : null;
}
