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
///
/// 1.6.0 CAD: the angle of `@d<a` may be an azimuth (`A120`, `AZ120`:
/// degrees clockwise from north) or a bearing of field surveys (`N45E`,
/// `S30W`, `N45.5L`, `45NE`: degrees from north or south towards east or
/// west; L and O are east and west in Portuguese), see [parseTypedAngle].
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
    final d = num(parts[0]), a = parseTypedAngle(parts[1]);
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

/// 1.6.0 CAD: an angle typed after `<`, in degrees counter-clockwise from
/// east: a plain number, an azimuth (`A120`, `AZ120`, clockwise from north)
/// or a bearing (`N45E`, `S30W`, `N45L`, `S10O`, `45NE`, `30SW`); null when
/// it is none of these.
double? parseTypedAngle(String text) {
  final s = text.trim().toUpperCase().replaceAll(' ', '').replaceAll('°', '');
  if (s.isEmpty) return null;
  final az = RegExp(r'^AZ?([0-9]+(?:[.,][0-9]+)?)$').firstMatch(s);
  if (az != null) {
    final v = parseNumber(az.group(1)!);
    return v == null || v > 360 ? null : 90 - v;
  }
  String? ns, ew;
  double? v;
  final lead = RegExp(r'^([NS])([0-9]+(?:[.,][0-9]+)?)([EWLO])$').firstMatch(s);
  final tail = RegExp(r'^([0-9]+(?:[.,][0-9]+)?)([NS])([EWLO])$').firstMatch(s);
  if (lead != null) {
    (ns, v, ew) = (lead.group(1), parseNumber(lead.group(2)!), lead.group(3));
  } else if (tail != null) {
    (v, ns, ew) = (parseNumber(tail.group(1)!), tail.group(2), tail.group(3));
  }
  if (ns != null && ew != null) {
    if (v == null || v > 90) return null;
    final east = ew == 'E' || ew == 'L';
    // azimuth of the bearing, then counter-clockwise from east
    final azimuth = ns == 'N' ? (east ? v : 360 - v) : (east ? 180 - v : 180 + v);
    return 90 - azimuth;
  }
  return parseNumber(s);
}

/// A bare number typed on the command line (an angle, a factor, a
/// distance), in the display unit; null for a point (`x,y`, `@…`, `d<a`)
/// or anything that is not a number.
double? parseTypedValue(String text) {
  final s = text.trim().replaceAll(' ', '');
  if (s.isEmpty || RegExp(r'[,;<@]').hasMatch(s)) return null;
  final v = parseNumber(s);
  return v != null && v.isFinite ? v : null;
}
