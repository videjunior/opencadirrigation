/// Geographic helpers: WGS84 latitude/longitude to UTM (metres).
library;

import 'dart:math' as math;

class UtmPoint {
  const UtmPoint(this.easting, this.northing, this.zone, this.north);
  final double easting;
  final double northing;
  final int zone;
  final bool north;
}

/// Converts WGS84 lat/lon (degrees) to UTM using the Krüger series as
/// formulated by Karney (2011); accuracy of a few millimetres within the zone.
UtmPoint latLonToUtm(double lat, double lon, {int? zone}) {
  const a = 6378137.0;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  final z = zone ?? utmZoneFor(lat, lon);
  final lon0 = (z - 1) * 6 - 180 + 3;
  final north = lat >= 0;
  final phi = lat * math.pi / 180;
  final lam = (lon - lon0) * math.pi / 180;
  final n = f / (2 - f);
  final aBig = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
  final alpha = [
    n / 2 - 2 * n * n / 3 + 5 * n * n * n / 16,
    13 * n * n / 48 - 3 * n * n * n / 5,
    61 * n * n * n / 240,
  ];
  final e2 = 2 * f - f * f;
  final t = math.tan(phi);
  // conformal latitude
  final sigma = _sinh(math.sqrt(e2) * _atanh(math.sqrt(e2) * math.sin(phi)));
  final tp = t * math.sqrt(1 + sigma * sigma) - sigma * math.sqrt(1 + t * t);
  final xiP = math.atan2(tp, math.cos(lam));
  final etaP = _asinh(math.sin(lam) / math.sqrt(tp * tp + math.cos(lam) * math.cos(lam)));
  var xi = xiP, eta = etaP;
  for (var j = 1; j <= 3; j++) {
    xi += alpha[j - 1] * math.sin(2 * j * xiP) * _cosh(2 * j * etaP);
    eta += alpha[j - 1] * math.cos(2 * j * xiP) * _sinh(2 * j * etaP);
  }
  final easting = 500000 + k0 * aBig * eta;
  var northing = k0 * aBig * xi;
  if (!north) northing += 10000000;
  return UtmPoint(easting, northing, z, north);
}

int utmZoneFor(double lat, double lon) {
  var zone = ((lon + 180) / 6).floor() + 1;
  if (lat >= 56 && lat < 64 && lon >= 3 && lon < 12) zone = 32;
  if (lat >= 72 && lat < 84) {
    if (lon >= 0 && lon < 9) {
      zone = 31;
    } else if (lon >= 9 && lon < 21) {
      zone = 33;
    } else if (lon >= 21 && lon < 33) {
      zone = 35;
    } else if (lon >= 33 && lon < 42) {
      zone = 37;
    }
  }
  return zone.clamp(1, 60);
}

/// Inverse of [latLonToUtm]: UTM easting/northing (metres, with the usual
/// false easting and, for the southern hemisphere, false northing) to WGS84
/// latitude/longitude in degrees.
(double lat, double lon) utmToLatLon(double easting, double northing, int zone, bool north) {
  const a = 6378137.0;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  final lon0 = (zone - 1) * 6 - 180 + 3;
  final n = f / (2 - f);
  final aBig = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
  final beta = [
    n / 2 - 2 * n * n / 3 + 37 * n * n * n / 96,
    n * n / 48 + n * n * n / 15,
    17 * n * n * n / 480,
  ];
  final delta = [
    2 * n - 2 * n * n / 3 - 2 * n * n * n,
    7 * n * n / 3 - 8 * n * n * n / 5,
    56 * n * n * n / 15,
  ];
  final y = north ? northing : northing - 10000000;
  final xi = y / (k0 * aBig);
  final eta = (easting - 500000) / (k0 * aBig);
  var xiP = xi, etaP = eta;
  for (var j = 1; j <= 3; j++) {
    xiP -= beta[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
    etaP -= beta[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
  }
  final chi = math.asin(math.sin(xiP) / _cosh(etaP));
  var phi = chi;
  for (var j = 1; j <= 3; j++) {
    phi += delta[j - 1] * math.sin(2 * j * chi);
  }
  final lam = math.atan2(_sinh(etaP), math.cos(xiP));
  return (phi * 180 / math.pi, lon0 + lam * 180 / math.pi);
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

/// Georeference of a project: world (x, y) = (easting − originE, northing − originN).
class GeoReference {
  const GeoReference({required this.zone, required this.north, required this.originEasting, required this.originNorthing});
  final int zone;
  final bool north;
  final double originEasting;
  final double originNorthing;
  String get crsName => 'WGS84 / UTM $zone${north ? 'N' : 'S'}';

  /// Georeference whose local origin (0, 0) sits at the given WGS84 position.
  static GeoReference fromLatLonOrigin(double lat, double lon) {
    final u = latLonToUtm(lat, lon);
    return GeoReference(zone: u.zone, north: u.north, originEasting: u.easting, originNorthing: u.northing);
  }

  /// Local drawing coordinates (metres) to WGS84 (lat, lon) in degrees.
  (double lat, double lon) toLatLon(double x, double y) => utmToLatLon(x + originEasting, y + originNorthing, zone, north);

  /// UTM coordinates (in this reference's zone/hemisphere) of a local point.
  (double easting, double northing) toUtm(double x, double y) => (x + originEasting, y + originNorthing);
  Map<String, dynamic> toJson() => {'zone': zone, 'north': north, 'e0': originEasting, 'n0': originNorthing};
  static GeoReference fromJson(Map<String, dynamic> j) => GeoReference(zone: (j['zone'] as num).toInt(), north: j['north'] as bool? ?? true, originEasting: (j['e0'] as num).toDouble(), originNorthing: (j['n0'] as num).toDouble());
}

/// Reads a coordinate typed or pasted by the user and returns (lat, lon) in
/// degrees, or null when the text is not understood. Accepted forms:
/// - decimal degrees separated by a comma, a space or a semicolon, with a
///   dot or a comma as decimal separator: `-22.9068, -43.1729`,
///   `-22,9068 -43,1729`;
/// - hemisphere letters instead of signs: `22.9068 S 43.1729 W`;
/// - degrees, minutes and seconds: `22°54'24.5"S 43°10'22.4"W`;
/// - Google Maps / Earth links and `geo:` URIs (`@-22.9068,-43.1729,17z`,
///   `q=-22.9,-43.1`).
/// Values are (lat, lon); when the first is out of the latitude range and
/// the pair makes sense swapped (KML-style lon, lat), it is swapped.
(double lat, double lon)? parseLatLon(String text) {
  var t = text.trim();
  if (t.isEmpty) return null;
  // links: prefer the `@lat,lon` or `q=lat,lon` part
  final at = RegExp(r'[@=]\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (at != null) t = '${at.group(1)} ${at.group(2)}';
  t = t.replaceFirst(RegExp(r'^geo:', caseSensitive: false), '');

  final dms = RegExp(r'''(\d{1,3})\s*[°º]\s*(\d{1,2})\s*['′’]\s*(\d{1,2}(?:[.,]\d+)?)?\s*(?:["″”])?\s*([NSEWnsew])''');
  final dmsMatches = dms.allMatches(t).toList();
  double? lat, lon;
  if (dmsMatches.length >= 2) {
    for (final m in dmsMatches.take(2)) {
      final d = double.parse(m.group(1)!), mi = double.parse(m.group(2)!);
      final se = double.tryParse((m.group(3) ?? '0').replaceAll(',', '.')) ?? 0;
      var v = d + mi / 60 + se / 3600;
      final h = m.group(4)!.toUpperCase();
      if (h == 'S' || h == 'W') v = -v;
      if (h == 'N' || h == 'S') {
        lat = v;
      } else {
        lon = v;
      }
    }
    if (lat == null || lon == null) return null;
    return _validLatLon(lat, lon);
  }

  // decimal numbers: dot decimals first, then comma decimals, then integers
  List<RegExpMatch> nums = RegExp(r'[-+]?\d+\.\d+').allMatches(t).toList();
  if (nums.length < 2) nums = RegExp(r'[-+]?\d+,\d+').allMatches(t).toList();
  if (nums.length < 2) nums = RegExp(r'[-+]?\d+').allMatches(t).toList();
  if (nums.length < 2) return null;
  final vals = <double>[];
  for (var i = 0; i < 2; i++) {
    final m = nums[i];
    var v = double.parse(m.group(0)!.replaceAll(',', '.'));
    // hemisphere letter right after the number (or just before it)
    final after = t.substring(m.end, i + 1 < nums.length ? nums[i + 1].start : t.length);
    final before = t.substring(i > 0 ? nums[i - 1].end : 0, m.start);
    // a standalone letter only ("22.9 S", "S 22.9"), not the n of "lon"
    final letter = RegExp(r'(?<![A-Za-z])[NSEWnsew](?![A-Za-z])').firstMatch(after)?.group(0) ?? RegExp(r'(?<![A-Za-z])[NSEWnsew](?![A-Za-z])(?=\s*$)').firstMatch(before)?.group(0);
    final h = letter?.toUpperCase();
    if (h == 'S' || h == 'W') v = -v.abs();
    if (h == 'N' || h == 'E') v = v.abs();
    vals.add(v);
  }
  return _validLatLon(vals[0], vals[1]);
}

(double, double)? _validLatLon(double lat, double lon) {
  if (lat.abs() <= 90 && lon.abs() <= 180) return (lat, lon);
  if (lon.abs() <= 90 && lat.abs() <= 180) return (lon, lat); // lon, lat order
  return null;
}
