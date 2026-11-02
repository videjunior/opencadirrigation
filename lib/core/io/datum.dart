/// Coordinate reference systems for the readers and writers: the geodetic
/// datums of Brazil (SIRGAS 2000, SAD 69, Córrego Alegre) and WGS 84 (with
/// ETRS89 and NAD83, which agree with it at the accuracy of a project map),
/// recognition of the CRS of a file (.prj and other WKT strings in the ESRI
/// and OGC flavours, WKT 2, EPSG codes and OGC URNs), datum shifts by
/// geocentric translation, the map projections on any ellipsoid (transverse
/// Mercator and UTM, Albers equal-area conic, Lambert conformal conic,
/// American polyconic: [MapProjection]) and the placement of imported
/// coordinates in the local frame of a project ([GeoPlacement]).
///
/// SIRGAS 2000 is Brazil's official datum (IBGE, R.PR 1/2005). It was
/// realised on ITRF2000 at epoch 2000.4 and agrees with WGS 84 (realisations
/// G1150 onwards, aligned with the ITRF) to a few centimetres at that epoch;
/// the South American plate moves 1–2 cm a year, so a position observed today
/// in a current WGS 84 realisation differs from its SIRGAS 2000 coordinates
/// by up to about half a metre. At the accuracy of an irrigation project map
/// the two are treated as identical (no shift), with that tolerance
/// ([GeodeticDatum.toleranceM]).
///
/// References:
/// - IBGE, Resolução do Presidente nº 1, de 25/02/2005: SIRGAS 2000 as the
///   geodetic reference of the Brazilian Geodetic System, and the SAD 69 →
///   SIRGAS 2000 translation ΔX = −67.35 m, ΔY = +3.88 m, ΔZ = −38.22 m
///   (SAD 69 ellipsoid a = 6 378 160 m, f = 1/298.25; GRS 80 for SIRGAS 2000).
/// - IBGE, Resolução do Presidente nº 23, de 21/02/1989: Córrego Alegre →
///   SAD 69 translation ΔX = −138.70 m, ΔY = +164.40 m, ΔZ = +34.40 m
///   (International 1924 ellipsoid). Composed with R.PR 1/2005 it gives
///   Córrego Alegre → SIRGAS 2000 ΔX = −206.05 m, ΔY = +168.28 m,
///   ΔZ = −3.82 m. Both three-parameter shifts are accurate to a few metres:
///   the classical networks hold distortions of that order, which only a
///   grid-based transformation removes.
/// - OGC 01-009 (Coordinate Transformation Services, WKT 1), the ESRI
///   flavour of WKT 1 used by .prj files, ISO 19162:2019 (WKT 2), the EPSG
///   Geodetic Parameter Dataset (codes), OGC URNs (`urn:ogc:def:crs:EPSG::…`).
/// - Karney (2011), "Transverse Mercator with an accuracy of a few
///   nanometers", for the Krüger series (the same series as [latLonToUtm]).
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import 'geo.dart';

/// Reference ellipsoid: semi-major axis [a] (m) and inverse flattening.
class Ellipsoid {
  const Ellipsoid(this.a, this.inverseFlattening);
  final double a;
  final double inverseFlattening;
  double get f => 1 / inverseFlattening;

  /// First eccentricity squared.
  double get e2 => f * (2 - f);

  static const wgs84 = Ellipsoid(6378137.0, 298.257223563);
  static const grs80 = Ellipsoid(6378137.0, 298.257222101);

  /// SAD 69: the 1967 reference ellipsoid with the flattening rounded to 1/298.25.
  static const sad69 = Ellipsoid(6378160.0, 298.25);

  /// International 1924 (Hayford), Córrego Alegre.
  static const international1924 = Ellipsoid(6378388.0, 297.0);
}

/// Geodetic datums recognised in files. [dx], [dy], [dz] translate geocentric
/// coordinates on the datum to SIRGAS 2000 ≡ WGS 84 (metres); [toleranceM] is
/// the accuracy of that shift at mapping scale.
enum GeodeticDatum {
  wgs84(Ellipsoid.wgs84, 0, 0, 0, 4326, 0, 'WGS 84', 'WGS_1984', 'D_WGS_1984', 'GCS_WGS_1984', 'WGS_1984', 'WGS 84', 'WGS_1984'),
  sirgas2000(Ellipsoid.grs80, 0, 0, 0, 4674, 0.5, 'SIRGAS 2000', 'Sistema_de_Referencia_Geocentrico_para_las_AmericaS_2000', 'D_SIRGAS_2000', 'GCS_SIRGAS_2000', 'GRS_1980', 'GRS 1980', 'SIRGAS_2000'),
  sad69(
    Ellipsoid.sad69,
    -67.35,
    3.88,
    -38.22,
    4618,
    5,
    'SAD69',
    'South_American_Datum_1969',
    'D_South_American_1969',
    'GCS_South_American_1969',
    'GRS_1967_Truncated',
    'GRS 1967 Modified',
    'SAD_1969',
  ),
  sad69r96(
    Ellipsoid.sad69,
    -67.35,
    3.88,
    -38.22,
    5527,
    2,
    'SAD69(96)',
    'South_American_Datum_1969_96',
    'D_South_American_1969_96',
    'GCS_SAD_1969_96',
    'GRS_1967_Truncated',
    'GRS 1967 Modified',
    'SAD_1969_96',
  ),
  corregoAlegre(
    Ellipsoid.international1924,
    -206.05,
    168.28,
    -3.82,
    4225,
    5,
    'Corrego Alegre 1970-72',
    'Corrego_Alegre_1970_1972',
    'D_Corrego_Alegre',
    'GCS_Corrego_Alegre',
    'International_1924',
    'International 1924',
    'Corrego_Alegre',
  ),
  etrs89(Ellipsoid.grs80, 0, 0, 0, 4258, 1, 'ETRS89', 'European_Terrestrial_Reference_System_1989', 'D_ETRS_1989', 'GCS_ETRS_1989', 'GRS_1980', 'GRS 1980', 'ETRS_1989'),
  nad83(Ellipsoid.grs80, 0, 0, 0, 4269, 2, 'NAD83', 'North_American_Datum_1983', 'D_North_American_1983', 'GCS_North_American_1983', 'GRS_1980', 'GRS 1980', 'NAD_1983');

  const GeodeticDatum(
    this.ellipsoid,
    this.dx,
    this.dy,
    this.dz,
    this.geographicEpsg,
    this.toleranceM,
    this.ogcName,
    this.ogcDatumName,
    this.esriDatumName,
    this.esriGcsName,
    this.esriSpheroidName,
    this.ogcSpheroidName,
    this.esriProjectedPrefix,
  );
  final Ellipsoid ellipsoid;
  final double dx, dy, dz;

  /// EPSG code of the 2D geographic CRS.
  final int geographicEpsg;

  /// Accuracy (m) of the shift to WGS 84 / SIRGAS 2000 at mapping scale.
  final double toleranceM;

  /// Names in OGC WKT (CRS name, datum name) and in ESRI WKT (datum,
  /// geographic CRS, spheroid), the OGC spheroid name and the prefix of the
  /// ESRI projected CRS names (`SIRGAS_2000_UTM_Zone_23S`).
  final String ogcName, ogcDatumName, esriDatumName, esriGcsName, esriSpheroidName, ogcSpheroidName, esriProjectedPrefix;

  /// No shift is applied: identical to WGS 84 at mapping accuracy.
  bool get isWgs84Compatible => dx == 0 && dy == 0 && dz == 0;

  /// EPSG code of the UTM zone on this datum, when the dataset has one.
  int? utmEpsg(int zone, bool north) {
    if (zone < 1 || zone > 60) return null;
    switch (this) {
      case GeodeticDatum.wgs84:
        return (north ? 32600 : 32700) + zone;
      case GeodeticDatum.sirgas2000:
        if (north) {
          if (zone >= 11 && zone <= 22) return 31954 + zone;
          if (zone == 23) return 6210;
          if (zone == 24) return 6211;
          return null;
        }
        if (zone >= 17 && zone <= 25) return 31960 + zone;
        return zone == 26 ? 5396 : null;
      case GeodeticDatum.sad69:
        if (north) return zone >= 18 && zone <= 22 ? 29150 + zone : null;
        return zone >= 17 && zone <= 25 ? 29170 + zone : null;
      case GeodeticDatum.sad69r96:
        if (north) return null;
        return const {18: 5875, 19: 5876, 20: 5877, 21: 5531, 22: 5858}[zone];
      case GeodeticDatum.corregoAlegre:
        return !north && zone >= 21 && zone <= 25 ? 22500 + zone : null;
      case GeodeticDatum.etrs89:
        return north && zone >= 28 && zone <= 38 ? 25800 + zone : null;
      case GeodeticDatum.nad83:
        return north && zone >= 1 && zone <= 23 ? 26900 + zone : null;
    }
  }
}

// ------------------------------------------------------------------ datum shift

/// Geodetic latitude/longitude (degrees) and ellipsoidal height (m) to
/// geocentric X, Y, Z (m) on [e].
(double, double, double) geodeticToGeocentric(double lat, double lon, double h, Ellipsoid e) {
  final phi = lat * math.pi / 180, lam = lon * math.pi / 180;
  final s = math.sin(phi), c = math.cos(phi);
  final n = e.a / math.sqrt(1 - e.e2 * s * s);
  return ((n + h) * c * math.cos(lam), (n + h) * c * math.sin(lam), (n * (1 - e.e2) + h) * s);
}

/// Geocentric X, Y, Z (m) to geodetic (latitude, longitude in degrees,
/// ellipsoidal height in m) on [e] (Bowring's start, refined by iteration).
(double, double, double) geocentricToGeodetic(double x, double y, double z, Ellipsoid e) {
  final p = math.sqrt(x * x + y * y);
  final lon = math.atan2(y, x);
  final b = e.a * (1 - e.f);
  final ep2 = (e.a * e.a - b * b) / (b * b);
  final theta = math.atan2(z * e.a, p * b);
  var phi = math.atan2(z + ep2 * b * math.pow(math.sin(theta), 3), p - e.e2 * e.a * math.pow(math.cos(theta), 3));
  var h = 0.0;
  for (var i = 0; i < 4; i++) {
    final s = math.sin(phi);
    final n = e.a / math.sqrt(1 - e.e2 * s * s);
    h = p > 1e-9 ? p / math.cos(phi) - n : z.abs() - b;
    phi = math.atan2(z, p * (1 - e.e2 * n / (n + h)));
  }
  return (phi * 180 / math.pi, lon * 180 / math.pi, h);
}

/// Latitude/longitude on [datum] to WGS 84 ≡ SIRGAS 2000 (degrees), by the
/// geocentric translation of the datum. [h] is the ellipsoidal height when
/// known (it changes the result by millimetres only).
(double lat, double lon) datumToWgs84(double lat, double lon, GeodeticDatum datum, {double h = 0}) {
  if (datum.isWgs84Compatible) return (lat, lon);
  final (x, y, z) = geodeticToGeocentric(lat, lon, h, datum.ellipsoid);
  final (la, lo, _) = geocentricToGeodetic(x + datum.dx, y + datum.dy, z + datum.dz, Ellipsoid.grs80);
  return (la, lo);
}

/// Inverse of [datumToWgs84]: WGS 84 ≡ SIRGAS 2000 latitude/longitude to [datum].
(double lat, double lon) wgs84ToDatum(double lat, double lon, GeodeticDatum datum, {double h = 0}) {
  if (datum.isWgs84Compatible) return (lat, lon);
  final (x, y, z) = geodeticToGeocentric(lat, lon, h, Ellipsoid.grs80);
  final (la, lo, _) = geocentricToGeodetic(x - datum.dx, y - datum.dy, z - datum.dz, datum.ellipsoid);
  return (la, lo);
}

// ------------------------------------------------------------------ projection

/// A map projection on an ellipsoid: geodetic latitude/longitude (degrees,
/// on [ellipsoid]) to easting/northing (metres) and back. The transverse
/// Mercator (UTM and the other TM systems), the Albers equal-area conic,
/// the Lambert conformal conic (one and two standard parallels) and the
/// American polyconic are held: the projected systems of the national maps
/// of Brazil (the Albers and polyconic projections of IBGE), of statistical
/// and land-cover data (Albers, LCC) and of many national grids
/// (Lambert-93, LCC Europe).
///
/// References: Snyder, J. P. (1987), "Map Projections — A Working Manual",
/// USGS Professional Paper 1395 (chapters 14, 15 and 18, ellipsoidal
/// formulas); IOGP Publication 373-7-2, "Geomatics Guidance Note 7, part 2"
/// (EPSG methods 9801, 9802, 9818 and 9822).
abstract class MapProjection {
  const MapProjection();

  Ellipsoid get ellipsoid;

  /// Degrees.
  double get centralMeridian;

  /// Degrees.
  double get latitudeOfOrigin;

  /// Metres.
  double get falseEasting;
  double get falseNorthing;

  /// Latitude/longitude (degrees, on [ellipsoid]) to easting/northing (m).
  (double easting, double northing) forward(double lat, double lon);

  /// Easting/northing (m) to latitude/longitude (degrees, on [ellipsoid]).
  (double lat, double lon) inverse(double easting, double northing);

  /// The UTM zone these parameters describe, or null (any other projection).
  int? get utmZone => null;

  /// Northern-hemisphere UTM (no false northing); true for the other projections.
  bool get north => true;

  /// The method name in ESRI WKT (`PROJECTION["…"]`) and in OGC WKT 1.
  String get esriMethod;
  String get ogcMethod;

  /// The parameters of the method as WKT 1 writes them: (ESRI name, OGC
  /// name, value), angles in degrees and lengths in metres.
  List<(String, String, double)> get wktParameters;
}

/// [lon] − [lon0] (degrees) in (−180°, 180°], as radians.
double _lonDiffRad(double lon, double lon0) {
  var d = (lon - lon0) % 360;
  if (d > 180) d -= 360;
  return d * math.pi / 180;
}

/// Transverse Mercator projection on any ellipsoid (Krüger series to n³, as
/// in [latLonToUtm]; a few millimetres within a UTM zone).
class TransverseMercator extends MapProjection {
  const TransverseMercator({required this.centralMeridian, this.scale = 0.9996, this.falseEasting = 500000, this.falseNorthing = 0, this.latitudeOfOrigin = 0, this.ellipsoid = Ellipsoid.wgs84});

  /// The UTM zone [zone] (1–60) of the given hemisphere.
  factory TransverseMercator.utm(int zone, bool north, [Ellipsoid ellipsoid = Ellipsoid.wgs84]) =>
      TransverseMercator(centralMeridian: zone * 6.0 - 183, falseNorthing: north ? 0 : 10000000, ellipsoid: ellipsoid);

  /// Degrees.
  @override
  final double centralMeridian;
  final double scale;
  @override
  final double falseEasting;
  @override
  final double falseNorthing;

  /// Degrees.
  @override
  final double latitudeOfOrigin;
  @override
  final Ellipsoid ellipsoid;

  @override
  String get esriMethod => 'Transverse_Mercator';
  @override
  String get ogcMethod => 'Transverse_Mercator';
  @override
  List<(String, String, double)> get wktParameters => [
    ('Latitude_Of_Origin', 'latitude_of_origin', latitudeOfOrigin),
    ('Central_Meridian', 'central_meridian', centralMeridian),
    ('Scale_Factor', 'scale_factor', scale),
    ('False_Easting', 'false_easting', falseEasting),
    ('False_Northing', 'false_northing', falseNorthing),
  ];

  /// The UTM zone these parameters describe, or null (another transverse
  /// Mercator: a local or regional system).
  @override
  int? get utmZone {
    final z = (centralMeridian + 183) / 6;
    if ((z - z.round()).abs() > 1e-9 || z.round() < 1 || z.round() > 60) return null;
    if ((scale - 0.9996).abs() > 1e-9 || (falseEasting - 500000).abs() > 1e-6 || latitudeOfOrigin.abs() > 1e-9) return null;
    if (falseNorthing.abs() > 1e-6 && (falseNorthing - 10000000).abs() > 1e-6) return null;
    return z.round();
  }

  /// Northern-hemisphere UTM (no false northing).
  @override
  bool get north => falseNorthing.abs() < 1e-6;

  double get _n => ellipsoid.f / (2 - ellipsoid.f);
  double get _aBig {
    final n = _n;
    return ellipsoid.a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
  }

  /// Unscaled, unshifted (ξ·A, η·A) of a point.
  (double, double) _raw(double lat, double lon) {
    final n = _n;
    final alpha = [n / 2 - 2 * n * n / 3 + 5 * n * n * n / 16, 13 * n * n / 48 - 3 * n * n * n / 5, 61 * n * n * n / 240];
    final e2 = ellipsoid.e2;
    final phi = lat * math.pi / 180;
    final lam = (lon - centralMeridian) * math.pi / 180;
    final t = math.tan(phi);
    final sigma = _sinh(math.sqrt(e2) * _atanh(math.sqrt(e2) * math.sin(phi)));
    final tp = t * math.sqrt(1 + sigma * sigma) - sigma * math.sqrt(1 + t * t);
    final xiP = math.atan2(tp, math.cos(lam));
    final etaP = _asinh(math.sin(lam) / math.sqrt(tp * tp + math.cos(lam) * math.cos(lam)));
    var xi = xiP, eta = etaP;
    for (var j = 1; j <= 3; j++) {
      xi += alpha[j - 1] * math.sin(2 * j * xiP) * _cosh(2 * j * etaP);
      eta += alpha[j - 1] * math.cos(2 * j * xiP) * _sinh(2 * j * etaP);
    }
    return (xi * _aBig, eta * _aBig);
  }

  double get _northingOfOrigin => latitudeOfOrigin == 0 ? 0 : _raw(latitudeOfOrigin, centralMeridian).$1 * scale;

  /// Latitude/longitude (degrees, on [ellipsoid]) to easting/northing (m).
  @override
  (double easting, double northing) forward(double lat, double lon) {
    final (x, y) = _raw(lat, lon);
    return (falseEasting + scale * y, falseNorthing + scale * x - _northingOfOrigin);
  }

  /// Easting/northing (m) to latitude/longitude (degrees, on [ellipsoid]).
  @override
  (double lat, double lon) inverse(double easting, double northing) {
    final n = _n;
    final beta = [n / 2 - 2 * n * n / 3 + 37 * n * n * n / 96, n * n / 48 + n * n * n / 15, 17 * n * n * n / 480];
    final delta = [2 * n - 2 * n * n / 3 - 2 * n * n * n, 7 * n * n / 3 - 8 * n * n * n / 5, 56 * n * n * n / 15];
    final xi = (northing - falseNorthing + _northingOfOrigin) / (scale * _aBig);
    final eta = (easting - falseEasting) / (scale * _aBig);
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
    return (phi * 180 / math.pi, centralMeridian + lam * 180 / math.pi);
  }
}

/// Albers equal-area conic on an ellipsoid (EPSG method 9822; Snyder,
/// eqs. 14-1 to 14-21): the projection of the statistical and land-cover
/// maps (IBGE's "SIRGAS 2000 / Brazil Albers", the US national datasets).
class AlbersEqualArea extends MapProjection {
  AlbersEqualArea({
    required this.centralMeridian,
    required this.latitudeOfOrigin,
    required this.standardParallel1,
    required this.standardParallel2,
    this.falseEasting = 0,
    this.falseNorthing = 0,
    this.ellipsoid = Ellipsoid.grs80,
  }) {
    final p1 = standardParallel1 * math.pi / 180, p2 = standardParallel2 * math.pi / 180;
    final m1 = _m(p1), m2 = _m(p2), q1 = _q(p1), q2 = _q(p2);
    _n = (p1 - p2).abs() < 1e-10 ? math.sin(p1) : (m1 * m1 - m2 * m2) / (q2 - q1);
    _c = m1 * m1 + _n * q1;
    _rho0 = _rho(_q(latitudeOfOrigin * math.pi / 180));
  }

  @override
  final double centralMeridian, latitudeOfOrigin, falseEasting, falseNorthing;

  /// Degrees.
  final double standardParallel1, standardParallel2;
  @override
  final Ellipsoid ellipsoid;
  late final double _n, _c, _rho0;

  double get _e => math.sqrt(ellipsoid.e2);

  double _m(double phi) {
    final s = math.sin(phi);
    return math.cos(phi) / math.sqrt(1 - ellipsoid.e2 * s * s);
  }

  /// q of Snyder (3-12), the authalic function.
  double _q(double phi) {
    final s = math.sin(phi), e = _e, e2 = ellipsoid.e2;
    if (e < 1e-12) return 2 * s;
    return (1 - e2) * (s / (1 - e2 * s * s) - 1 / (2 * e) * math.log((1 - e * s) / (1 + e * s)));
  }

  double _rho(double q) => ellipsoid.a * math.sqrt(math.max(0.0, _c - _n * q)) / _n;

  @override
  String get esriMethod => 'Albers';
  @override
  String get ogcMethod => 'Albers_Conic_Equal_Area';
  @override
  List<(String, String, double)> get wktParameters => [
    ('False_Easting', 'false_easting', falseEasting),
    ('False_Northing', 'false_northing', falseNorthing),
    ('Central_Meridian', 'longitude_of_center', centralMeridian),
    ('Standard_Parallel_1', 'standard_parallel_1', standardParallel1),
    ('Standard_Parallel_2', 'standard_parallel_2', standardParallel2),
    ('Latitude_Of_Origin', 'latitude_of_center', latitudeOfOrigin),
  ];

  @override
  (double easting, double northing) forward(double lat, double lon) {
    final rho = _rho(_q(lat * math.pi / 180));
    final theta = _n * _lonDiffRad(lon, centralMeridian);
    return (falseEasting + rho * math.sin(theta), falseNorthing + _rho0 - rho * math.cos(theta));
  }

  @override
  (double lat, double lon) inverse(double easting, double northing) {
    final x = easting - falseEasting, y = _rho0 - (northing - falseNorthing);
    var rho = math.sqrt(x * x + y * y);
    final theta = _n >= 0 ? math.atan2(x, y) : math.atan2(-x, -y);
    if (_n < 0) rho = -rho;
    final a = ellipsoid.a, e = _e, e2 = ellipsoid.e2;
    final q = (_c - rho * rho * _n * _n / (a * a)) / _n;
    // the pole: q reaches its limit there
    final qPole = e < 1e-12 ? 2.0 : 1 - (1 - e2) / (2 * e) * math.log((1 - e) / (1 + e));
    double phi;
    if ((q.abs() - qPole).abs() < 1e-12) {
      phi = q.sign * math.pi / 2;
    } else {
      phi = math.asin((q / 2).clamp(-1.0, 1.0));
      for (var i = 0; i < 25; i++) {
        final s = math.sin(phi), c = math.cos(phi);
        final w = 1 - e2 * s * s;
        final d = e < 1e-12
            ? (q / 2 - s) / c
            : w * w / (2 * c) * (q / (1 - e2) - s / w + 1 / (2 * e) * math.log((1 - e * s) / (1 + e * s)));
        phi += d;
        if (d.abs() < 1e-14) break;
      }
    }
    return (phi * 180 / math.pi, centralMeridian + theta / _n * 180 / math.pi);
  }
}

/// Lambert conformal conic on an ellipsoid with two standard parallels
/// (EPSG method 9802; Snyder, eqs. 15-1 to 15-11) or one (method 9801, a
/// scale factor at the latitude of origin): Lambert-93, LCC Europe and many
/// state and national grids.
class LambertConformalConic extends MapProjection {
  LambertConformalConic({
    required this.centralMeridian,
    required this.latitudeOfOrigin,
    required this.standardParallel1,
    required this.standardParallel2,
    this.scale = 1,
    this.falseEasting = 0,
    this.falseNorthing = 0,
    this.ellipsoid = Ellipsoid.grs80,
  }) {
    final p1 = standardParallel1 * math.pi / 180, p2 = standardParallel2 * math.pi / 180;
    final m1 = _m(p1), m2 = _m(p2), t1 = _t(p1), t2 = _t(p2);
    _n = (p1 - p2).abs() < 1e-10 ? math.sin(p1) : (math.log(m1) - math.log(m2)) / (math.log(t1) - math.log(t2));
    _f = m1 / (_n * math.pow(t1, _n));
    _rho0 = _rho(latitudeOfOrigin * math.pi / 180);
  }

  /// One standard parallel: the latitude of origin, with [scale] there.
  factory LambertConformalConic.oneParallel({
    required double centralMeridian,
    required double latitudeOfOrigin,
    double scale = 1,
    double falseEasting = 0,
    double falseNorthing = 0,
    Ellipsoid ellipsoid = Ellipsoid.grs80,
  }) => LambertConformalConic(
    centralMeridian: centralMeridian,
    latitudeOfOrigin: latitudeOfOrigin,
    standardParallel1: latitudeOfOrigin,
    standardParallel2: latitudeOfOrigin,
    scale: scale,
    falseEasting: falseEasting,
    falseNorthing: falseNorthing,
    ellipsoid: ellipsoid,
  );

  @override
  final double centralMeridian, latitudeOfOrigin, falseEasting, falseNorthing;

  /// Degrees.
  final double standardParallel1, standardParallel2;

  /// Scale factor (1 with two standard parallels).
  final double scale;
  @override
  final Ellipsoid ellipsoid;
  late final double _n, _f, _rho0;

  bool get oneParallel => (standardParallel1 - standardParallel2).abs() < 1e-10 && (standardParallel1 - latitudeOfOrigin).abs() < 1e-10;

  double get _e => math.sqrt(ellipsoid.e2);

  double _m(double phi) {
    final s = math.sin(phi);
    return math.cos(phi) / math.sqrt(1 - ellipsoid.e2 * s * s);
  }

  /// t of Snyder (15-9).
  double _t(double phi) {
    final s = math.sin(phi), e = _e;
    return math.tan(math.pi / 4 - phi / 2) / math.pow((1 - e * s) / (1 + e * s), e / 2);
  }

  double _rho(double phi) {
    if ((phi.abs() - math.pi / 2).abs() < 1e-12 && phi * _n > 0) return 0;
    return ellipsoid.a * _f * math.pow(_t(phi), _n) * scale;
  }

  @override
  String get esriMethod => 'Lambert_Conformal_Conic';
  @override
  String get ogcMethod => oneParallel ? 'Lambert_Conformal_Conic_1SP' : 'Lambert_Conformal_Conic_2SP';
  @override
  List<(String, String, double)> get wktParameters => oneParallel
      ? [
          ('False_Easting', 'false_easting', falseEasting),
          ('False_Northing', 'false_northing', falseNorthing),
          ('Central_Meridian', 'central_meridian', centralMeridian),
          ('Standard_Parallel_1', 'latitude_of_origin', latitudeOfOrigin),
          ('Scale_Factor', 'scale_factor', scale),
          ('Latitude_Of_Origin', 'latitude_of_origin', latitudeOfOrigin),
        ]
      : [
          ('False_Easting', 'false_easting', falseEasting),
          ('False_Northing', 'false_northing', falseNorthing),
          ('Central_Meridian', 'central_meridian', centralMeridian),
          ('Standard_Parallel_1', 'standard_parallel_1', standardParallel1),
          ('Standard_Parallel_2', 'standard_parallel_2', standardParallel2),
          ('Scale_Factor', 'scale_factor', scale),
          ('Latitude_Of_Origin', 'latitude_of_origin', latitudeOfOrigin),
        ];

  @override
  (double easting, double northing) forward(double lat, double lon) {
    final rho = _rho(lat * math.pi / 180);
    final theta = _n * _lonDiffRad(lon, centralMeridian);
    return (falseEasting + rho * math.sin(theta), falseNorthing + _rho0 - rho * math.cos(theta));
  }

  @override
  (double lat, double lon) inverse(double easting, double northing) {
    final x = easting - falseEasting, y = _rho0 - (northing - falseNorthing);
    var rho = math.sqrt(x * x + y * y);
    final theta = _n >= 0 ? math.atan2(x, y) : math.atan2(-x, -y);
    if (_n < 0) rho = -rho;
    final e = _e;
    if (rho == 0) return (_n.sign * 90.0, centralMeridian);
    final t = math.pow(rho / (ellipsoid.a * _f * scale), 1 / _n).toDouble();
    var phi = math.pi / 2 - 2 * math.atan(t);
    for (var i = 0; i < 25; i++) {
      final s = math.sin(phi);
      final next = math.pi / 2 - 2 * math.atan(t * math.pow((1 - e * s) / (1 + e * s), e / 2));
      final d = next - phi;
      phi = next;
      if (d.abs() < 1e-14) break;
    }
    return (phi * 180 / math.pi, centralMeridian + theta / _n * 180 / math.pi);
  }
}

/// The American polyconic projection on an ellipsoid (EPSG method 9818;
/// Snyder, eqs. 18-1 to 18-19): IBGE's "Brazil Polyconic" of the national
/// systematic mapping (SIRGAS 2000 and SAD 69).
class Polyconic extends MapProjection {
  const Polyconic({required this.centralMeridian, this.latitudeOfOrigin = 0, this.falseEasting = 0, this.falseNorthing = 0, this.ellipsoid = Ellipsoid.grs80});

  @override
  final double centralMeridian, latitudeOfOrigin, falseEasting, falseNorthing;
  @override
  final Ellipsoid ellipsoid;

  /// The meridian distance from the equator to [phi] (Snyder 3-21).
  double _meridian(double phi) {
    final e2 = ellipsoid.e2, e4 = e2 * e2, e6 = e4 * e2;
    return ellipsoid.a *
        ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
            (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
            (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
            35 * e6 / 3072 * math.sin(6 * phi));
  }

  /// d(M/a)/dφ.
  double _meridianSlope(double phi) {
    final e2 = ellipsoid.e2, e4 = e2 * e2, e6 = e4 * e2;
    return 1 -
        e2 / 4 -
        3 * e4 / 64 -
        5 * e6 / 256 -
        2 * (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.cos(2 * phi) +
        4 * (15 * e4 / 256 + 45 * e6 / 1024) * math.cos(4 * phi) -
        6 * 35 * e6 / 3072 * math.cos(6 * phi);
  }

  @override
  String get esriMethod => 'Polyconic';
  @override
  String get ogcMethod => 'Polyconic';
  @override
  List<(String, String, double)> get wktParameters => [
    ('False_Easting', 'false_easting', falseEasting),
    ('False_Northing', 'false_northing', falseNorthing),
    ('Central_Meridian', 'central_meridian', centralMeridian),
    ('Latitude_Of_Origin', 'latitude_of_origin', latitudeOfOrigin),
  ];

  @override
  (double easting, double northing) forward(double lat, double lon) {
    final phi = lat * math.pi / 180, lam = _lonDiffRad(lon, centralMeridian);
    final m0 = _meridian(latitudeOfOrigin * math.pi / 180);
    if (phi.abs() < 1e-12) return (falseEasting + ellipsoid.a * lam, falseNorthing - m0);
    final s = math.sin(phi);
    final nu = ellipsoid.a / math.sqrt(1 - ellipsoid.e2 * s * s);
    final l = lam * s, cot = 1 / math.tan(phi);
    return (falseEasting + nu * cot * math.sin(l), falseNorthing + _meridian(phi) - m0 + nu * cot * (1 - math.cos(l)));
  }

  @override
  (double lat, double lon) inverse(double easting, double northing) {
    final a = ellipsoid.a, e2 = ellipsoid.e2;
    final x = easting - falseEasting, y = northing - falseNorthing;
    final m0 = _meridian(latitudeOfOrigin * math.pi / 180);
    if ((y + m0).abs() < 1e-9) return (0, centralMeridian + x / a * 180 / math.pi);
    final aa = (m0 + y) / a, bb = x * x / (a * a) + aa * aa;
    var phi = aa;
    var c = 0.0;
    for (var i = 0; i < 40; i++) {
      final s = math.sin(phi);
      c = math.sqrt(1 - e2 * s * s) * math.tan(phi);
      final ma = _meridian(phi) / a, mp = _meridianSlope(phi);
      final s2 = math.sin(2 * phi);
      final d = (aa * (c * ma + 1) - ma - 0.5 * (ma * ma + bb) * c) / (e2 * s2 * (ma * ma + bb - 2 * aa * ma) / (4 * c) + (aa - ma) * (c * mp - 2 / s2) - mp);
      phi -= d;
      if (d.abs() < 1e-14) break;
    }
    final s = math.sin(phi);
    c = math.sqrt(1 - e2 * s * s) * math.tan(phi);
    final lam = math.asin((x * c / a).clamp(-1.0, 1.0)) / s;
    return (phi * 180 / math.pi, centralMeridian + lam * 180 / math.pi);
  }
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));
double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

// ------------------------------------------------------------------ CRS

/// Kind of a coordinate reference system.
enum CrsKind {
  /// Longitude/latitude in degrees (x = longitude).
  geographic,

  /// A map projection (UTM or another transverse Mercator, Albers, Lambert
  /// conformal conic, polyconic) in metres.
  projected,

  /// Plain local metres (a site grid or a drawing without georeference).
  local,

  /// Given but not understood (see [CrsInfo.problem]).
  unknown,
}

/// The coordinate reference system of a file, as far as it was recognised.
/// Readers place data through [GeoPlacement]; an unrecognised CRS carries a
/// [problem] code (`crs_datum_unknown`, `crs_projection_unsupported`,
/// `crs_unparsed`, `crs_geocentric`) for the interface to warn about,
/// instead of the data being put silently in the wrong place.
class CrsInfo {
  const CrsInfo({required this.kind, this.datum, this.projection, this.epsg, this.name = '', this.unitM = 1, this.problem});

  /// Geographic coordinates (degrees) on [datum].
  factory CrsInfo.geographic([GeodeticDatum datum = GeodeticDatum.wgs84]) => CrsInfo(kind: CrsKind.geographic, datum: datum, epsg: datum.geographicEpsg, name: datum.ogcName);

  /// UTM zone [zone] of the given hemisphere on [datum].
  factory CrsInfo.utm(int zone, bool north, {GeodeticDatum datum = GeodeticDatum.wgs84}) => CrsInfo(
    kind: CrsKind.projected,
    datum: datum,
    projection: TransverseMercator.utm(zone, north, datum.ellipsoid),
    epsg: datum.utmEpsg(zone, north),
    name: '${datum.ogcName} / UTM zone $zone${north ? 'N' : 'S'}',
  );

  /// Local metres.
  static const local = CrsInfo(kind: CrsKind.local, name: 'local');

  final CrsKind kind;

  /// Null when the datum is not known.
  final GeodeticDatum? datum;

  /// The projection of a projected CRS.
  final MapProjection? projection;
  final int? epsg;
  final String name;

  /// Metres per unit of the projected or local coordinates (1, 0.3048…).
  final double unitM;

  /// Why the CRS cannot be used, as a message code; null when usable.
  final String? problem;

  /// Usable for placing data (a known datum and, if projected, a supported
  /// projection; or plain local metres).
  bool get recognised => problem == null && (kind == CrsKind.local || (datum != null && (kind == CrsKind.geographic || projection != null)));

  int? get utmZone => projection?.utmZone;
  bool get north => projection?.north ?? true;

  /// The EPSG code, or the matching one for a UTM zone or geographic CRS.
  int? get epsgCode {
    if (epsg != null) return epsg;
    final d = datum;
    if (d == null) return null;
    if (kind == CrsKind.geographic) return d.geographicEpsg;
    final z = utmZone;
    return z == null ? null : d.utmEpsg(z, north);
  }

  /// Coordinates of this CRS (x = easting or longitude, in its units) to
  /// WGS 84 ≡ SIRGAS 2000 latitude/longitude (degrees). Only for a
  /// [recognised] geographic or projected CRS.
  (double lat, double lon) toWgs84(double x, double y) {
    final d = datum ?? GeodeticDatum.wgs84;
    if (kind == CrsKind.geographic) return datumToWgs84(y, x, d);
    final pr = projection;
    if (pr == null) throw StateError('crs_not_projected');
    final (lat, lon) = pr.inverse(x * unitM, y * unitM);
    return datumToWgs84(lat, lon, d);
  }

  /// WGS 84 ≡ SIRGAS 2000 latitude/longitude to coordinates of this CRS.
  (double x, double y) fromWgs84(double lat, double lon) {
    final d = datum ?? GeodeticDatum.wgs84;
    final (la, lo) = wgs84ToDatum(lat, lon, d);
    if (kind == CrsKind.geographic) return (lo, la);
    final pr = projection;
    if (pr == null) throw StateError('crs_not_projected');
    final (e, n) = pr.forward(la, lo);
    return (e / unitM, n / unitM);
  }

  /// WKT 1 in the ESRI flavour (the text of a .prj file).
  String toEsriWkt() {
    final d = datum ?? GeodeticDatum.wgs84;
    final gcs =
        'GEOGCS["${d.esriGcsName}",DATUM["${d.esriDatumName}",SPHEROID["${d.esriSpheroidName}",${_wktNum(d.ellipsoid.a)},${_wktNum(d.ellipsoid.inverseFlattening)}]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]';
    final pr = projection;
    if (kind != CrsKind.projected || pr == null) return gcs;
    final z = pr.utmZone;
    if (pr is TransverseMercator) {
      final pname = z != null ? '${d.esriProjectedPrefix}_UTM_Zone_$z${pr.north ? 'N' : 'S'}' : '${d.esriProjectedPrefix}_Transverse_Mercator';
      return 'PROJCS["$pname",$gcs,PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",${_wktNum(pr.falseEasting)}],PARAMETER["False_Northing",${_wktNum(pr.falseNorthing)}],'
          'PARAMETER["Central_Meridian",${_wktNum(pr.centralMeridian)}],PARAMETER["Scale_Factor",${_wktNum(pr.scale)}],PARAMETER["Latitude_Of_Origin",${_wktNum(pr.latitudeOfOrigin)}],UNIT["Meter",1.0]]';
    }
    final pname = name.isNotEmpty ? name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_') : '${d.esriProjectedPrefix}_${pr.esriMethod}';
    final params = [for (final (esri, _, v) in pr.wktParameters) 'PARAMETER["$esri",${_wktNum(v)}]'].join(',');
    return 'PROJCS["$pname",$gcs,PROJECTION["${pr.esriMethod}"],$params,UNIT["Meter",1.0]]';
  }

  /// WKT 1 in the OGC flavour, with EPSG authority codes.
  String toOgcWkt() {
    final d = datum ?? GeodeticDatum.wgs84;
    final gcs =
        'GEOGCS["${d.ogcName}",DATUM["${d.ogcDatumName}",SPHEROID["${d.ogcSpheroidName}",${_wktNum(d.ellipsoid.a)},${_wktNum(d.ellipsoid.inverseFlattening)}],TOWGS84[${_wktNum(d.dx)},${_wktNum(d.dy)},${_wktNum(d.dz)},0,0,0,0]],'
        'PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","${d.geographicEpsg}"]]';
    final pr = projection;
    if (kind != CrsKind.projected || pr == null) return gcs;
    final code = epsgCode;
    final z = pr.utmZone;
    if (pr is TransverseMercator) {
      final pname = z != null ? '${d.ogcName} / UTM zone $z${pr.north ? 'N' : 'S'}' : '${d.ogcName} / Transverse Mercator';
      return 'PROJCS["$pname",$gcs,PROJECTION["Transverse_Mercator"],PARAMETER["latitude_of_origin",${_wktNum(pr.latitudeOfOrigin)}],PARAMETER["central_meridian",${_wktNum(pr.centralMeridian)}],'
          'PARAMETER["scale_factor",${_wktNum(pr.scale)}],PARAMETER["false_easting",${_wktNum(pr.falseEasting)}],PARAMETER["false_northing",${_wktNum(pr.falseNorthing)}],UNIT["metre",1,AUTHORITY["EPSG","9001"]],'
          'AXIS["Easting",EAST],AXIS["Northing",NORTH]${code != null ? ',AUTHORITY["EPSG","$code"]' : ''}]';
    }
    final pname = name.isNotEmpty ? name : '${d.ogcName} / ${pr.ogcMethod.replaceAll('_', ' ')}';
    // a parameter the method names once (the latitude of origin of a 1SP Lambert)
    final seen = <String>{};
    final params = [
      for (final (_, ogc, v) in pr.wktParameters)
        if (seen.add(ogc)) 'PARAMETER["$ogc",${_wktNum(v)}]',
    ].join(',');
    return 'PROJCS["${pname.replaceAll('"', '')}",$gcs,PROJECTION["${pr.ogcMethod}"],$params,UNIT["metre",1,AUTHORITY["EPSG","9001"]],'
        'AXIS["Easting",EAST],AXIS["Northing",NORTH]${code != null ? ',AUTHORITY["EPSG","$code"]' : ''}]';
  }

  @override
  String toString() => 'CrsInfo(${kind.name}, ${datum?.name}, ${utmZone ?? projection?.centralMeridian}, epsg $epsgCode${problem != null ? ', $problem' : ''})';
}

String _wktNum(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return '${v.toInt()}.0';
  return '$v';
}

/// The CRS of an EPSG code: geographic and UTM codes of the datums above.
/// Unknown codes give a CRS of kind [CrsKind.unknown] (`crs_epsg_unknown`).
CrsInfo crsFromEpsg(int code) {
  for (final d in GeodeticDatum.values) {
    if (code == d.geographicEpsg) return CrsInfo.geographic(d);
  }
  // 3D geographic and other aliases
  const geo3d = {4979: GeodeticDatum.wgs84, 4989: GeodeticDatum.sirgas2000, 4988: GeodeticDatum.sirgas2000, 4937: GeodeticDatum.etrs89, 5524: GeodeticDatum.corregoAlegre, 4291: GeodeticDatum.sad69};
  final g = geo3d[code];
  if (g != null) return CrsInfo(kind: CrsKind.geographic, datum: g, epsg: code, name: g.ogcName);
  for (final d in GeodeticDatum.values) {
    for (final north in [true, false]) {
      for (var z = 1; z <= 60; z++) {
        if (d.utmEpsg(z, north) == code) {
          final c = CrsInfo.utm(z, north, datum: d);
          return CrsInfo(kind: c.kind, datum: d, projection: c.projection, epsg: code, name: c.name);
        }
      }
    }
  }
  final national = _nationalProjected(code);
  if (national != null) return national;
  // deprecated SAD69 UTM codes (18N–22N, 17S–25S) and Córrego Alegre 1961 (21S–24S)
  if (code >= 29118 && code <= 29122) return _utmAlias(code, code - 29100, true, GeodeticDatum.sad69);
  if (code >= 29177 && code <= 29185) return _utmAlias(code, code - 29160, false, GeodeticDatum.sad69);
  if (code >= 5536 && code <= 5539) return _utmAlias(code, code - 5515, false, GeodeticDatum.corregoAlegre);
  return CrsInfo(kind: CrsKind.unknown, epsg: code, name: 'EPSG:$code', problem: 'crs_epsg_unknown');
}

CrsInfo _utmAlias(int code, int zone, bool north, GeodeticDatum d) {
  final c = CrsInfo.utm(zone, north, datum: d);
  return CrsInfo(kind: c.kind, datum: d, projection: c.projection, epsg: code, name: c.name);
}

/// Projected systems other than UTM of national maps and datasets, by
/// their EPSG codes: IBGE's Brazil Polyconic (SIRGAS 2000 and SAD 69) and
/// Brazil Albers, Lambert-93 (RGF93, which agrees with ETRS89), LCC Europe,
/// the US Conus Albers and Mexico's LCC (ITRF2008, which agrees with WGS 84).
CrsInfo? _nationalProjected(int code) {
  CrsInfo crs(GeodeticDatum d, MapProjection p, String name) => CrsInfo(kind: CrsKind.projected, datum: d, projection: p, epsg: code, name: name);
  switch (code) {
    case 5880:
      return crs(GeodeticDatum.sirgas2000, const Polyconic(centralMeridian: -54, falseEasting: 5000000, falseNorthing: 10000000), 'SIRGAS 2000 / Brazil Polyconic');
    case 29101:
      return crs(GeodeticDatum.sad69, const Polyconic(centralMeridian: -54, falseEasting: 5000000, falseNorthing: 10000000, ellipsoid: Ellipsoid.sad69), 'SAD69 / Brazil Polyconic');
    case 10857:
      return crs(
        GeodeticDatum.sirgas2000,
        AlbersEqualArea(centralMeridian: -54, latitudeOfOrigin: -12, standardParallel1: -2, standardParallel2: -22, falseEasting: 5000000, falseNorthing: 10000000),
        'SIRGAS 2000 / Brazil Albers',
      );
    case 2154:
      return crs(
        GeodeticDatum.etrs89,
        LambertConformalConic(centralMeridian: 3, latitudeOfOrigin: 46.5, standardParallel1: 49, standardParallel2: 44, falseEasting: 700000, falseNorthing: 6600000),
        'RGF93 v1 / Lambert-93',
      );
    case 3034:
      return crs(
        GeodeticDatum.etrs89,
        LambertConformalConic(centralMeridian: 10, latitudeOfOrigin: 52, standardParallel1: 35, standardParallel2: 65, falseEasting: 4000000, falseNorthing: 2800000),
        'ETRS89-extended / LCC Europe',
      );
    case 5070:
      return crs(GeodeticDatum.nad83, AlbersEqualArea(centralMeridian: -96, latitudeOfOrigin: 23, standardParallel1: 29.5, standardParallel2: 45.5), 'NAD83 / Conus Albers');
    case 6372:
      return crs(
        GeodeticDatum.wgs84,
        LambertConformalConic(centralMeridian: -102, latitudeOfOrigin: 12, standardParallel1: 17.5, standardParallel2: 29.5, falseEasting: 2500000),
        'Mexico ITRF2008 / LCC',
      );
  }
  return null;
}

/// The projection a WKT method name and its parameters describe (keys of
/// [params] in lower case, letters and digits only, lengths in metres), or
/// null when the method is not held. [zoneName] is a UTM zone found in the
/// CRS name (`… UTM zone 23S`).
MapProjection? projectionFromParameters(String method, Map<String, double> params, Ellipsoid ellipsoid, {(int, bool)? zoneName}) {
  final m = method.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  double? p(List<String> keys) {
    for (final k in keys) {
      final v = params[k];
      if (v != null) return v;
    }
    return null;
  }

  final fe = p(['falseeasting', 'eastingatfalseorigin', 'eastingatprojectioncentre']) ?? 0;
  final fn = p(['falsenorthing', 'northingatfalseorigin', 'northingatprojectioncentre']) ?? 0;
  final lat0 = p(['latitudeoforigin', 'latitudeofnaturalorigin', 'latitudeoffalseorigin', 'latitudeofcenter', 'latitudeofcentre', 'latitudeofprojectioncentre']) ?? 0;
  final lon0 = p(['centralmeridian', 'longitudeofnaturalorigin', 'longitudeoffalseorigin', 'longitudeoforigin', 'longitudeofcenter', 'longitudeofcentre', 'longitudeofprojectioncentre']);
  final sp1 = p(['standardparallel1', 'latitudeof1ststandardparallel']);
  final sp2 = p(['standardparallel2', 'latitudeof2ndstandardparallel']);
  final k0 = p(['scalefactor', 'scalefactoratnaturalorigin']);
  if (m.contains('transversemercator') || m.contains('gausskruger') || m == 'tm') {
    if (lon0 != null) return TransverseMercator(centralMeridian: lon0, scale: k0 ?? 1, falseEasting: fe, falseNorthing: fn, latitudeOfOrigin: lat0, ellipsoid: ellipsoid);
    if (zoneName != null) return TransverseMercator.utm(zoneName.$1, zoneName.$2, ellipsoid);
    return null;
  }
  if (m.contains('albers')) {
    if (lon0 == null || sp1 == null) return null;
    return AlbersEqualArea(centralMeridian: lon0, latitudeOfOrigin: lat0, standardParallel1: sp1, standardParallel2: sp2 ?? sp1, falseEasting: fe, falseNorthing: fn, ellipsoid: ellipsoid);
  }
  if (m.contains('lambertconformalconic') || m.contains('lambertconicconformal')) {
    if (lon0 == null) return null;
    final oneSp = m.contains('1sp') || (sp1 == null && sp2 == null) || (sp2 == null && sp1 != null && (sp1 - lat0).abs() < 1e-9);
    if (oneSp) {
      return LambertConformalConic.oneParallel(centralMeridian: lon0, latitudeOfOrigin: sp1 ?? lat0, scale: k0 ?? 1, falseEasting: fe, falseNorthing: fn, ellipsoid: ellipsoid);
    }
    return LambertConformalConic(
      centralMeridian: lon0,
      latitudeOfOrigin: lat0,
      standardParallel1: sp1 ?? lat0,
      standardParallel2: sp2 ?? sp1 ?? lat0,
      scale: k0 ?? 1,
      falseEasting: fe,
      falseNorthing: fn,
      ellipsoid: ellipsoid,
    );
  }
  if (m.contains('polyconic')) {
    if (lon0 == null) return null;
    return Polyconic(centralMeridian: lon0, latitudeOfOrigin: lat0, falseEasting: fe, falseNorthing: fn, ellipsoid: ellipsoid);
  }
  if ((m.isEmpty || m.contains('mercator')) && zoneName != null) return TransverseMercator.utm(zoneName.$1, zoneName.$2, ellipsoid);
  return null;
}

/// Recognises a CRS from its text: WKT 1 (ESRI .prj or OGC), WKT 2,
/// `EPSG:31983`, `urn:ogc:def:crs:EPSG::31983`, `urn:ogc:def:crs:OGC:1.3:CRS84`
/// or an EPSG URL. Returns a CRS of kind [CrsKind.unknown] with a [CrsInfo.problem]
/// when it cannot be used.
CrsInfo parseCrs(String text) {
  final t = text.trim();
  if (t.isEmpty) return const CrsInfo(kind: CrsKind.unknown, problem: 'crs_unparsed');
  if (RegExp(r'CRS:?84$', caseSensitive: false).hasMatch(t) || RegExp(r'OGC:(1\.3:)?CRS84', caseSensitive: false).hasMatch(t)) return CrsInfo.geographic();
  final code = RegExp(r'^(?:urn:ogc:def:crs:EPSG:[\d.]*:|EPSG:+|https?://www\.opengis\.net/def/crs/EPSG/[\d.]+/)(\d+)$', caseSensitive: false).firstMatch(t);
  if (code != null) return crsFromEpsg(int.parse(code.group(1)!));
  if (RegExp(r'^\d{4,5}$').hasMatch(t)) return crsFromEpsg(int.parse(t));
  final WktNode root;
  try {
    root = WktNode.parse(t);
  } on FormatException {
    return CrsInfo(kind: CrsKind.unknown, name: t.length > 60 ? t.substring(0, 60) : t, problem: 'crs_unparsed');
  }
  return crsFromWkt(root);
}

/// Recognises a parsed WKT 1 or WKT 2 tree.
CrsInfo crsFromWkt(WktNode root) {
  final kw = root.keyword;
  final name = root.stringArg(0) ?? '';
  if (kw == 'COMPD_CS' || kw == 'COMPOUNDCRS') {
    // horizontal component first
    for (final c in root.children) {
      if (_projectedKw.contains(c.keyword) || _geographicKw.contains(c.keyword)) return crsFromWkt(c);
    }
    return CrsInfo(kind: CrsKind.unknown, name: name, problem: 'crs_unparsed');
  }
  if (kw == 'LOCAL_CS' || kw == 'ENGCRS' || kw == 'ENGINEERINGCRS') {
    return CrsInfo(kind: CrsKind.local, name: name, unitM: _linearUnit(root) ?? 1);
  }
  if (kw == 'GEOCCS') return CrsInfo(kind: CrsKind.unknown, name: name, problem: 'crs_geocentric');
  final authority = _authorityCode(root);
  final projected = _projectedKw.contains(kw);
  final geographic = _geographicKw.contains(kw);
  if (!projected && !geographic) return CrsInfo(kind: CrsKind.unknown, name: name, problem: 'crs_unparsed');
  if (geographic && kw == 'GEODCRS' && root.find('CS')?.stringArg(0)?.toLowerCase() == 'cartesian') return CrsInfo(kind: CrsKind.unknown, name: name, problem: 'crs_geocentric');
  if (authority != null) {
    final c = crsFromEpsg(authority);
    if (c.recognised) return CrsInfo(kind: c.kind, datum: c.datum, projection: c.projection, epsg: authority, name: name.isEmpty ? c.name : name, unitM: c.unitM);
  }
  final geo = projected ? (root.children.where((c) => _geographicKw.contains(c.keyword)).firstOrNull ?? root) : root;
  final datum = _datumOf(geo, name);
  if (geographic) {
    if (datum == null) return CrsInfo(kind: CrsKind.geographic, name: name, problem: 'crs_datum_unknown');
    return CrsInfo(kind: CrsKind.geographic, datum: datum, epsg: authority ?? datum.geographicEpsg, name: name);
  }
  // projection: the method and its parameters (transverse Mercator, Albers,
  // Lambert conformal conic, polyconic), or a UTM zone in the name
  final method = root.find('PROJECTION')?.stringArg(0) ?? root.find('CONVERSION')?.find('METHOD')?.stringArg(0) ?? root.find('METHOD')?.stringArg(0) ?? '';
  final unit = _linearUnit(root) ?? 1;
  final params = <String, double>{};
  for (final p in root.findAll('PARAMETER')) {
    final k = (p.stringArg(0) ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final v = p.numArg(1);
    // eastings and northings are in the unit of the system
    if (v != null) params[k] = k.contains('easting') || k.contains('northing') ? v * unit : v;
  }
  final ellipsoid = datum?.ellipsoid ?? Ellipsoid.wgs84;
  final zoneMatch =
      RegExp(r'UTM[\s_]*(?:zone[\s_]*)?(\d{1,2})\s*([NS])\b', caseSensitive: false).firstMatch(name) ?? RegExp(r'UTM[\s_]*zone[\s_]*(\d{1,2})([NS])', caseSensitive: false).firstMatch(name);
  final tm = projectionFromParameters(method, params, ellipsoid, zoneName: zoneMatch == null ? null : (int.parse(zoneMatch.group(1)!), zoneMatch.group(2)!.toUpperCase() == 'N'));
  if (tm == null) return CrsInfo(kind: CrsKind.unknown, datum: datum, name: name, problem: 'crs_projection_unsupported');
  if (datum == null) return CrsInfo(kind: CrsKind.projected, projection: tm, name: name, unitM: unit, problem: 'crs_datum_unknown');
  final z = tm.utmZone;
  return CrsInfo(kind: CrsKind.projected, datum: datum, projection: tm, epsg: authority ?? (z != null ? datum.utmEpsg(z, tm.north) : null), name: name, unitM: unit);
}

const _projectedKw = {'PROJCS', 'PROJCRS', 'PROJECTEDCRS'};
const _geographicKw = {'GEOGCS', 'GEOGCRS', 'GEOGRAPHICCRS', 'BASEGEOGCRS', 'GEODCRS', 'GEODETICCRS', 'BASEGEODCRS'};

int? _authorityCode(WktNode n) {
  for (final c in n.children) {
    if ((c.keyword == 'AUTHORITY' || c.keyword == 'ID') && (c.stringArg(0) ?? '').toUpperCase() == 'EPSG') {
      final v = c.args.length > 1 ? c.args[1] : null;
      final code = v is num ? v.toInt() : int.tryParse('$v');
      if (code != null) return code;
    }
  }
  return null;
}

double? _linearUnit(WktNode n) {
  for (final c in n.children) {
    if (c.keyword == 'UNIT' || c.keyword == 'LENGTHUNIT') {
      final f = c.numArg(1);
      final nm = (c.stringArg(0) ?? '').toLowerCase();
      if (nm.contains('degree') || nm.contains('radian') || nm.contains('grad')) continue;
      if (f != null && f > 0) return f;
    }
  }
  final cs = n.find('CS');
  if (cs != null) {
    for (final a in n.findAll('AXIS')) {
      final u = a.find('LENGTHUNIT');
      final f = u?.numArg(1);
      if (f != null && f > 0) return f;
    }
  }
  return null;
}

/// The datum of a geographic WKT node, from the datum, CRS and ellipsoid names.
GeodeticDatum? _datumOf(WktNode geo, String crsName) {
  final datumNode = geo.find('DATUM') ?? geo.find('TRF') ?? geo.find('GEODETICDATUM') ?? geo.find('ENSEMBLE');
  final names = [datumNode?.stringArg(0) ?? '', geo.stringArg(0) ?? '', crsName];
  for (final raw in names) {
    final d = datumFromName(raw);
    if (d != null) return d;
  }
  // an unnamed datum with a zero TOWGS84 on GRS 80 / WGS 84 is WGS 84 in practice
  final towgs = datumNode?.find('TOWGS84');
  final sph = datumNode?.find('SPHEROID') ?? datumNode?.find('ELLIPSOID');
  final a = sph?.numArg(1), rf = sph?.numArg(2);
  if (towgs != null && towgs.args.whereType<num>().every((v) => v == 0) && a != null && (a - 6378137).abs() < 1e-3 && rf != null && (rf - 298.2572).abs() < 1e-3) return GeodeticDatum.wgs84;
  return null;
}

/// The datum named by [name] (WKT datum or CRS names in any flavour,
/// `SIRGAS 2000`, `D_South_American_1969`, `Corrego_Alegre`, `WGS84`…).
GeodeticDatum? datumFromName(String name) {
  final u = name.toUpperCase().replaceAll(RegExp(r'[ÓÒ]'), 'O').replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (u.isEmpty) return null;
  if (u.contains('SIRGAS') || u.contains('SISTEMADEREFERENCIAGEOCENTRICOPARALASAMERICAS')) {
    return u.contains('SIRGAS') && !u.contains('2000') && !u.contains('AMERICAS2000') ? null : GeodeticDatum.sirgas2000;
  }
  if (u.contains('SAD69') || u.contains('SAD1969') || u.contains('SOUTHAMERICAN1969') || u.contains('SOUTHAMERICANDATUM1969')) return u.contains('6996') ? GeodeticDatum.sad69r96 : GeodeticDatum.sad69;
  if (u.contains('CORREGOALEGRE')) return GeodeticDatum.corregoAlegre;
  if (u.contains('ETRS89') || u.contains('ETRS1989') || u.contains('EUROPEANTERRESTRIALREFERENCESYSTEM1989')) return GeodeticDatum.etrs89;
  // RGF93 (France) is a realisation of ETRS89
  if (u.contains('RGF93') || u.contains('RGF1993') || u.contains('RESEAUGEODESIQUEFRANCAIS1993')) return GeodeticDatum.etrs89;
  if (u.contains('NAD83') || u.contains('NAD1983') || u.contains('NORTHAMERICAN1983') || u.contains('NORTHAMERICANDATUM1983')) return GeodeticDatum.nad83;
  if (u.contains('WGS84') || u.contains('WGS1984') || u.contains('WORLDGEODETICSYSTEM1984')) return GeodeticDatum.wgs84;
  // the ITRF realisations agree with WGS 84 (G1150 onwards) to centimetres
  if (RegExp(r'ITRF(19|20)?\d\d').hasMatch(u)) return GeodeticDatum.wgs84;
  return null;
}

/// A node of a WKT tree: `KEYWORD[arg, arg, …]` where an argument is a
/// quoted string, a number, a bare word (`EAST`) or a nested node.
class WktNode {
  WktNode(this.keyword, this.args);
  final String keyword;
  final List<Object> args;

  Iterable<WktNode> get children => args.whereType<WktNode>();

  String? stringArg(int i) {
    if (i >= args.length) return null;
    final a = args[i];
    return a is String ? a : null;
  }

  double? numArg(int i) {
    if (i >= args.length) return null;
    final a = args[i];
    return a is num ? a.toDouble() : (a is String ? double.tryParse(a) : null);
  }

  /// First descendant (depth first) with [kw].
  WktNode? find(String kw) {
    for (final c in children) {
      if (c.keyword == kw) return c;
    }
    for (final c in children) {
      final f = c.find(kw);
      if (f != null) return f;
    }
    return null;
  }

  /// Every descendant with [kw] (not entering a match).
  List<WktNode> findAll(String kw) {
    final out = <WktNode>[];
    void walk(WktNode n) {
      for (final c in n.children) {
        if (c.keyword == kw) {
          out.add(c);
        } else {
          walk(c);
        }
      }
    }

    walk(this);
    return out;
  }

  /// Parses WKT text (square or round brackets, `""` inside strings).
  static WktNode parse(String text) {
    var i = 0;
    void ws() {
      while (i < text.length && ' \t\r\n'.contains(text[i])) {
        i++;
      }
    }

    late WktNode Function() node;
    Object value() {
      ws();
      if (i >= text.length) throw const FormatException('wkt_eof');
      final ch = text[i];
      if (ch == '"') {
        final b = StringBuffer();
        i++;
        while (i < text.length) {
          if (text[i] == '"') {
            if (i + 1 < text.length && text[i + 1] == '"') {
              b.write('"');
              i += 2;
              continue;
            }
            i++;
            return b.toString();
          }
          b.write(text[i++]);
        }
        throw const FormatException('wkt_string');
      }
      final m = RegExp(r'[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?').matchAsPrefix(text, i);
      if (m != null && (m.end >= text.length || !RegExp(r'[A-Za-z_]').hasMatch(text[m.end]))) {
        i = m.end;
        return num.parse(m.group(0)!);
      }
      final w = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(text, i);
      if (w == null) throw const FormatException('wkt_token');
      final after = w.end;
      var j = after;
      while (j < text.length && ' \t\r\n'.contains(text[j])) {
        j++;
      }
      if (j < text.length && (text[j] == '[' || text[j] == '(')) return node();
      i = after;
      return w.group(0)!;
    }

    node = () {
      ws();
      final w = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(text, i);
      if (w == null) throw const FormatException('wkt_keyword');
      i = w.end;
      ws();
      if (i >= text.length || (text[i] != '[' && text[i] != '(')) throw const FormatException('wkt_bracket');
      final close = text[i] == '[' ? ']' : ')';
      i++;
      final args = <Object>[];
      ws();
      if (i < text.length && text[i] == close) {
        i++;
        return WktNode(w.group(0)!.toUpperCase(), args);
      }
      while (true) {
        args.add(value());
        ws();
        if (i >= text.length) throw const FormatException('wkt_eof');
        if (text[i] == ',') {
          i++;
          continue;
        }
        if (text[i] == close || text[i] == ']' || text[i] == ')') {
          i++;
          break;
        }
        throw const FormatException('wkt_separator');
      }
      return WktNode(w.group(0)!.toUpperCase(), args);
    };
    final root = node();
    return root;
  }
}

// ------------------------------------------------------------------ placement

/// Places coordinates of a file in the local frame of a project:
/// local = UTM (of the project's zone) − origin of its [GeoReference].
///
/// - Geographic data and projected data on another datum, zone or
///   projection go through WGS 84 ≡ SIRGAS 2000 latitude/longitude (with the
///   datum shift) and the project's UTM zone.
/// - UTM data on a WGS 84 compatible datum in the project's zone is a plain
///   offset (exact).
/// - Without a project georeference one is created: the UTM zone of the
///   data (or of its centroid), origin rounded to 100 m.
/// - Local or unrecognised coordinates are kept; large ones (beyond 100 km)
///   are moved by a rounded [localOrigin] so the drawing stays near (0, 0),
///   and no georeference is created from them ([warnings] tells why).
class GeoPlacement {
  GeoPlacement._(this.crs, this.georef, this.georefCreated, this.localOrigin, this.warnings, this._place);

  /// The CRS the data was taken in (after any assumption).
  final CrsInfo crs;

  /// Georeference used (the project's, or a new one: [georefCreated]); null
  /// for local or unrecognised data.
  final GeoReference? georef;
  final bool georefCreated;

  /// Offset subtracted from local / unrecognised coordinates.
  final Pt localOrigin;

  /// Message codes: `crs_missing`, `crs_assumed_wgs84`, the CRS problem,
  /// `crs_datum_shift:<datum>:<tolerance m>`.
  final List<String> warnings;
  final Pt Function(double x, double y) _place;

  /// Local drawing coordinates of a point given in the file's CRS.
  Pt place(double x, double y) => _place(x, y);

  /// Plans the placement of data whose coordinates [sample] (x = easting or
  /// longitude) are in [crs] (null when the file names none: degrees are
  /// recognised by their range and precision) for a project with [georef].
  static GeoPlacement plan(CrsInfo? crs, Iterable<(double, double)> sample, {GeoReference? georef}) {
    final pts = [
      for (final p in sample)
        if (p.$1.isFinite && p.$2.isFinite) p,
    ];
    final warnings = <String>[];
    var c = crs;
    if (c == null) {
      final degrees = pts.isNotEmpty && looksLikeDegreePairs(pts);
      c = degrees ? CrsInfo.geographic() : CrsInfo.local;
      warnings.add(degrees ? 'crs_assumed_wgs84' : 'crs_missing');
    } else if (!c.recognised && c.problem != null) {
      warnings.add(c.problem!);
    }
    final d = c.datum;
    if (c.recognised && d != null && !d.isWgs84Compatible) warnings.add('crs_datum_shift:${d.name}:${d.toleranceM}');
    if (c.recognised && (c.kind == CrsKind.geographic || c.kind == CrsKind.projected)) {
      final cc = c;
      // UTM on a WGS 84 compatible datum: plain offsets within one zone
      final z = cc.utmZone;
      final plainUtm = cc.kind == CrsKind.projected && z != null && d!.isWgs84Compatible && cc.unitM == 1;
      var ref = georef;
      var created = false;
      if (ref == null) {
        created = true;
        if (plainUtm && pts.isNotEmpty) {
          final (e0, n0) = _centroid(pts);
          ref = GeoReference(zone: z, north: cc.north, originEasting: (e0 / 100).round() * 100.0, originNorthing: (n0 / 100).round() * 100.0);
        } else if (pts.isNotEmpty) {
          final (x0, y0) = _centroid(pts);
          final (lat, lon) = cc.toWgs84(x0, y0);
          final u = latLonToUtm(lat, lon);
          ref = GeoReference(zone: u.zone, north: u.north, originEasting: (u.easting / 100).round() * 100.0, originNorthing: (u.northing / 100).round() * 100.0);
        } else {
          ref = GeoReference(zone: z ?? 23, north: cc.north, originEasting: 0, originNorthing: 0);
        }
      }
      final g = ref;
      Pt viaLatLon(double x, double y) {
        final (lat, lon) = cc.toWgs84(x, y);
        final u = latLonToUtm(lat, lon, zone: g.zone);
        var northing = u.northing;
        if (g.north && lat < 0) northing -= 10000000;
        if (!g.north && lat >= 0) northing += 10000000;
        return Pt(u.easting - g.originEasting, northing - g.originNorthing);
      }

      if (plainUtm && z == g.zone) {
        // the same zone in the other hemisphere convention (false northing)
        final dn = cc.north == g.north ? 0.0 : (cc.north ? 10000000.0 : -10000000.0);
        return GeoPlacement._(cc, g, created, Pt.zero, warnings, (x, y) => Pt(x - g.originEasting, y + dn - g.originNorthing));
      }
      return GeoPlacement._(cc, g, created, Pt.zero, warnings, viaLatLon);
    }
    // local or unrecognised: keep the shape, near the origin
    final unit = c.kind == CrsKind.local ? c.unitM : 1.0;
    var origin = Pt.zero;
    if (pts.isNotEmpty) {
      final (x0, y0) = _centroid(pts);
      if (x0.abs() * unit > 100000 || y0.abs() * unit > 100000) {
        origin = georef != null && c.kind == CrsKind.local ? Pt(georef.originEasting, georef.originNorthing) : Pt((x0 * unit / 100).round() * 100.0, (y0 * unit / 100).round() * 100.0);
      }
    }
    final o = origin;
    return GeoPlacement._(c, c.kind == CrsKind.local && o != Pt.zero ? georef : null, false, o, warnings, (x, y) => Pt(x * unit - o.x, y * unit - o.y));
  }

  static (double, double) _centroid(List<(double, double)> pts) {
    var sx = 0.0, sy = 0.0;
    for (final (x, y) in pts) {
      sx += x;
      sy += y;
    }
    return (sx / pts.length, sy / pts.length);
  }
}

/// True when every pair fits the longitude/latitude range and at least half
/// of them carry four or more decimals (metres are rarely given that finely;
/// degrees need five decimals for metre precision).
bool looksLikeDegreePairs(List<(double, double)> pts) {
  if (pts.isEmpty || !pts.every((p) => p.$1.abs() <= 180 && p.$2.abs() <= 90)) return false;
  int decimals(double v) {
    for (var d = 0; d <= 6; d++) {
      final s = v * math.pow(10, d);
      if ((s - s.roundToDouble()).abs() < 1e-6) return d;
    }
    return 7;
  }

  var fine = 0;
  for (final (x, y) in pts) {
    if (decimals(x) >= 4 && decimals(y) >= 4) fine++;
  }
  return fine * 2 >= pts.length;
}

/// The CRS a project's coordinates are exported in: the UTM zone of its
/// georeference on [datum] (SIRGAS 2000 or WGS 84 give the same numbers).
CrsInfo projectUtmCrs(GeoReference g, {GeodeticDatum datum = GeodeticDatum.wgs84}) => CrsInfo.utm(g.zone, g.north, datum: datum);

// ------------------------------------------------------------------ 1.6.0 PRD: the datum of a project

/// Datums a project's georeference can name: those that agree with WGS 84
/// at the accuracy of a project map (no shift: [GeodeticDatum.isWgs84Compatible]),
/// so naming one changes no coordinate. A drawing on SAD 69 or Córrego
/// Alegre is brought in through the readers, which shift it.
const projectDatums = [GeodeticDatum.sirgas2000, GeodeticDatum.wgs84, GeodeticDatum.etrs89, GeodeticDatum.nad83];

/// The datum as the sheets name it: "SIRGAS 2000", "WGS84", "ETRS89", "NAD83".
String projectDatumLabel(GeodeticDatum d) => switch (d) {
  GeodeticDatum.wgs84 => 'WGS84',
  GeodeticDatum.sirgas2000 => 'SIRGAS 2000',
  GeodeticDatum.etrs89 => 'ETRS89',
  GeodeticDatum.nad83 => 'NAD83',
  _ => d.ogcName,
};

/// The official datum of the site at [lat], [lon] (degrees), for a
/// georeference that names none: SIRGAS 2000 in South and Central America
/// (Brazil's official datum, IBGE R.PR 1/2005, and the reference frame of
/// the SIRGAS countries; EPSG 4674 covers Latin America), ETRS89 in Europe
/// (the EUREF frame of the European national grids), WGS 84 elsewhere. The
/// regions are coarse outlines: near a border the user picks the datum.
GeodeticDatum defaultProjectDatum(double lat, double lon) {
  if (!lat.isFinite || !lon.isFinite) return GeodeticDatum.wgs84;
  final p = Pt(lon, lat);
  if (pointInPolygon(p, _sirgasRegion)) return GeodeticDatum.sirgas2000;
  if (pointInPolygon(p, _etrsRegion)) return GeodeticDatum.etrs89;
  return GeodeticDatum.wgs84;
}

/// South and Central America (from the Guatemala–Mexico border), with the
/// Brazilian islands of the Atlantic, the Galápagos and Juan Fernández;
/// (longitude, latitude).
const _sirgasRegion = [
  Pt(-92.3, 14.5), Pt(-91.0, 17.8), Pt(-89.15, 17.8), Pt(-88.3, 18.5), Pt(-87.5, 18.5), Pt(-83.0, 16.0), //
  Pt(-81.5, 12.6), Pt(-72.0, 12.5), Pt(-63.5, 11.0), Pt(-61.0, 10.9), Pt(-59.5, 9.0), Pt(-55.0, 6.0), //
  Pt(-28.5, 2.0), Pt(-28.5, -21.5), Pt(-50.0, -35.0), Pt(-63.0, -55.0), Pt(-68.0, -56.5), Pt(-76.0, -56.5), //
  Pt(-81.0, -34.0), Pt(-82.0, -5.0), Pt(-92.5, -1.8), Pt(-92.5, 1.8), Pt(-88.0, 5.0), Pt(-88.0, 12.0), Pt(-91.5, 13.8),
];

/// Europe west of Turkey, Belarus and Russia, without North Africa, the
/// Canaries, Madeira, the Azores and Iceland; (longitude, latitude).
const _etrsRegion = [
  Pt(-10.5, 36.0), Pt(-5.6, 35.8), Pt(-2.0, 36.5), Pt(0.0, 37.5), Pt(4.0, 38.3), Pt(8.0, 38.2), Pt(10.5, 37.6), //
  Pt(12.0, 36.3), Pt(13.0, 35.0), Pt(26.5, 34.5), Pt(26.5, 41.9), Pt(28.1, 42.0), Pt(28.7, 43.7), Pt(29.7, 45.2), //
  Pt(28.2, 45.5), Pt(26.6, 48.2), Pt(22.9, 48.5), Pt(22.6, 49.0), Pt(23.6, 51.5), Pt(23.5, 53.9), Pt(25.8, 54.0), //
  Pt(26.8, 55.3), Pt(26.8, 55.7), Pt(28.2, 56.2), Pt(27.8, 57.5), Pt(28.1, 59.4), Pt(27.8, 60.6), Pt(31.6, 62.9), Pt(30.0, 68.0), Pt(31.5, 70.5), //
  Pt(30.0, 71.5), Pt(-10.5, 71.5),
];
