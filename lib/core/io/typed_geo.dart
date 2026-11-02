/// Coordinates of the field typed on the command line (1.6.0 CAD, PRD-26):
/// UTM easting and northing with or without their zone, and latitude and
/// longitude (decimal degrees, degrees-minutes-seconds, hemisphere
/// letters), turned into the drawing's local coordinates through the
/// project's georeference. Plain `x,y` stays a local point: a geographic
/// pair needs the `LL` prefix, degree marks or hemisphere letters.
///
/// * `23S 456789 7654321`, `23S,456789,7654321`, `UTM 23K 456789 7654321`:
///   zone, hemisphere (N, S) or latitude band (C–X), easting, northing;
/// * `UTM 456789,7654321`: easting and northing in the project's zone;
/// * `LL -22.5,-47.1`, `GEO -22.5 -47.1`, `LATLON 22 30 00 S 47 06 00 W`;
/// * `22°30'S 47°06'W`, `-22.5°, -47.1°`, `22.5S 47.1W`.
library;

import 'geo.dart';
import '../model/geometry.dart';

/// What [parseTypedGeoPoint] read: the local point, or the i18n key of the
/// reason it cannot give one.
class TypedGeo {
  const TypedGeo.point(Pt this.point) : error = null;
  const TypedGeo.error(String this.error) : point = null;
  final Pt? point;
  final String? error;
}

const _num = r'([-+]?\d+(?:[.,]\d+)?)';
final _utmZoned = RegExp('^(?:UTM[\\s:]*)?(\\d{1,2})\\s*([C-HJ-NP-X])[\\s,;:]+$_num[\\s,;]+$_num\$', caseSensitive: false);
final _utmPlain = RegExp('^UTM[\\s:]*$_num[\\s,;]+$_num\$', caseSensitive: false);
final _llPrefix = RegExp(r'^(?:LL|GEO|LATLONG?|LATLNG)[\s:]*(.+)$', caseSensitive: false);
final _marks = RegExp(r'''[°º˚'′’"″”]''');
final _hemiLetters = RegExp(r'''^[-+\d\s.,;°º˚'′’"″”NSEWOL]+$''', caseSensitive: false);
final _hemi = RegExp(r'(?<![A-Za-z])[NSEWOL](?![A-Za-z])', caseSensitive: false);

/// The separator of the numbers of [s]: `;` when there is one, else the
/// spaces (a comma is then the decimal mark), else the comma.
String _separatorOf(String s) => s.contains(';') ? ';' : (RegExp(r'\d[\s]+[-+\d]').hasMatch(s) ? ' ' : ',');

double? _number(String s, String sep) => double.tryParse(sep == ',' ? s : s.replaceAll(',', '.'));

/// Reads [text] as a coordinate of the field (see the library doc); null
/// when it is none (a local point, an alias…). Without a georeference
/// [georef] the answer is the error `cmd.geoNoGeoref`; a position that does
/// not exist (latitude beyond 90°, a northing out of range) gives
/// `cmd.geoInvalid`.
TypedGeo? parseTypedGeoPoint(String text, GeoReference? georef) {
  final s = text.trim();
  if (s.isEmpty) return null;
  // ---- UTM with its zone
  final z = _utmZoned.firstMatch(s);
  if (z != null) {
    final zone = int.parse(z.group(1)!);
    final letter = z.group(2)!.toUpperCase();
    final sep = _separatorOf(s);
    final e = _number(z.group(3)!, sep), n = _number(z.group(4)!, sep);
    if (georef == null) return const TypedGeo.error('cmd.geoNoGeoref');
    if (zone < 1 || zone > 60 || e == null || n == null || e < 0 || e > 1000000 || n < 0 || n > 10000000) return const TypedGeo.error('cmd.geoInvalid');
    // N and S are the hemispheres (as in "UTM 23S"); in a project of the
    // northern hemisphere an S is the latitude band S (32°–40° N)
    final north = switch (letter) {
      'N' => true,
      'S' => georef.north,
      _ => letter.compareTo('N') > 0,
    };
    return TypedGeo.point(_fromUtm(georef, e, n, zone, north));
  }
  // ---- UTM in the project's zone
  final u = _utmPlain.firstMatch(s);
  if (u != null) {
    final sep = _separatorOf(s.substring(3));
    final e = _number(u.group(1)!, sep), n = _number(u.group(2)!, sep);
    if (georef == null) return const TypedGeo.error('cmd.geoNoGeoref');
    if (e == null || n == null) return const TypedGeo.error('cmd.geoInvalid');
    return TypedGeo.point(Pt(e - georef.originEasting, n - georef.originNorthing));
  }
  // ---- latitude and longitude
  String? geo;
  final ll = _llPrefix.firstMatch(s);
  if (ll != null) {
    geo = ll.group(1)!;
  } else if (_marks.hasMatch(s) || (_hemiLetters.hasMatch(s) && _hemi.hasMatch(s) && RegExp(r'\d').hasMatch(s))) {
    geo = s;
  }
  if (geo == null) return null;
  final latLon = parseLatLon(geo);
  if (latLon == null) return const TypedGeo.error('cmd.geoInvalid');
  if (georef == null) return const TypedGeo.error('cmd.geoNoGeoref');
  final (x, y) = georef.fromLatLon(latLon.$1, latLon.$2);
  return TypedGeo.point(Pt(x, y));
}

/// The local point of UTM [e], [n] in [zone] of the hemisphere [north]:
/// subtracted from the origin in the project's own zone, else through its
/// latitude and longitude.
Pt _fromUtm(GeoReference g, double e, double n, int zone, bool north) {
  if (zone == g.zone && north == g.north) return Pt(e - g.originEasting, n - g.originNorthing);
  final (lat, lon) = utmToLatLon(e, n, zone, north);
  final (x, y) = g.fromLatLon(lat, lon);
  return Pt(x, y);
}

/// Whether a space typed after [typed] on the canvas belongs to a field
/// coordinate being typed (`23S 456789 …`, `UTM …`, `LL …`) instead of
/// running the command.
bool typedGeoWantsSpace(String typed) {
  final s = typed.trimLeft();
  if (RegExp(r'^(?:UTM|LL|GEO|LATLONG?|LATLNG)\b', caseSensitive: false).hasMatch(s)) return true;
  return RegExp(r'^\d{1,2}[C-HJ-NP-X](?:\s+[-+]?\d+(?:[.,]\d*)?)?\s*$', caseSensitive: false).hasMatch(s);
}
