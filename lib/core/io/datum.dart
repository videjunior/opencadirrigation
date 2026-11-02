/// Coordinate reference systems for the readers and writers: the geodetic
/// datums of Brazil (SIRGAS 2000, SAD 69, Córrego Alegre) and WGS 84 (with
/// ETRS89 and NAD83, which agree with it at the accuracy of a project map),
/// recognition of the CRS of a file (.prj and other WKT strings in the ESRI
/// and OGC flavours, WKT 2, EPSG codes and OGC URNs), datum shifts by
/// geocentric translation, the transverse Mercator projection (UTM) on any
/// ellipsoid and the placement of imported coordinates in the local frame of
/// a project ([GeoPlacement]).
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

/// Transverse Mercator projection on any ellipsoid (Krüger series to n³, as
/// in [latLonToUtm]; a few millimetres within a UTM zone).
class TransverseMercator {
  const TransverseMercator({required this.centralMeridian, this.scale = 0.9996, this.falseEasting = 500000, this.falseNorthing = 0, this.latitudeOfOrigin = 0, this.ellipsoid = Ellipsoid.wgs84});

  /// The UTM zone [zone] (1–60) of the given hemisphere.
  factory TransverseMercator.utm(int zone, bool north, [Ellipsoid ellipsoid = Ellipsoid.wgs84]) =>
      TransverseMercator(centralMeridian: zone * 6.0 - 183, falseNorthing: north ? 0 : 10000000, ellipsoid: ellipsoid);

  /// Degrees.
  final double centralMeridian;
  final double scale;
  final double falseEasting;
  final double falseNorthing;

  /// Degrees.
  final double latitudeOfOrigin;
  final Ellipsoid ellipsoid;

  /// The UTM zone these parameters describe, or null (another transverse
  /// Mercator: a local or regional system).
  int? get utmZone {
    final z = (centralMeridian + 183) / 6;
    if ((z - z.round()).abs() > 1e-9 || z.round() < 1 || z.round() > 60) return null;
    if ((scale - 0.9996).abs() > 1e-9 || (falseEasting - 500000).abs() > 1e-6 || latitudeOfOrigin.abs() > 1e-9) return null;
    if (falseNorthing.abs() > 1e-6 && (falseNorthing - 10000000).abs() > 1e-6) return null;
    return z.round();
  }

  /// Northern-hemisphere UTM (no false northing).
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
  (double easting, double northing) forward(double lat, double lon) {
    final (x, y) = _raw(lat, lon);
    return (falseEasting + scale * y, falseNorthing + scale * x - _northingOfOrigin);
  }

  /// Easting/northing (m) to latitude/longitude (degrees, on [ellipsoid]).
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

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));
double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

// ------------------------------------------------------------------ CRS

/// Kind of a coordinate reference system.
enum CrsKind {
  /// Longitude/latitude in degrees (x = longitude).
  geographic,

  /// A transverse Mercator projection (UTM or another one) in metres.
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

  /// Transverse Mercator parameters of a projected CRS.
  final TransverseMercator? projection;
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
    final pname = z != null ? '${d.esriProjectedPrefix}_UTM_Zone_$z${pr.north ? 'N' : 'S'}' : '${d.esriProjectedPrefix}_Transverse_Mercator';
    return 'PROJCS["$pname",$gcs,PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",${_wktNum(pr.falseEasting)}],PARAMETER["False_Northing",${_wktNum(pr.falseNorthing)}],'
        'PARAMETER["Central_Meridian",${_wktNum(pr.centralMeridian)}],PARAMETER["Scale_Factor",${_wktNum(pr.scale)}],PARAMETER["Latitude_Of_Origin",${_wktNum(pr.latitudeOfOrigin)}],UNIT["Meter",1.0]]';
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
    final pname = z != null ? '${d.ogcName} / UTM zone $z${pr.north ? 'N' : 'S'}' : '${d.ogcName} / Transverse Mercator';
    return 'PROJCS["$pname",$gcs,PROJECTION["Transverse_Mercator"],PARAMETER["latitude_of_origin",${_wktNum(pr.latitudeOfOrigin)}],PARAMETER["central_meridian",${_wktNum(pr.centralMeridian)}],'
        'PARAMETER["scale_factor",${_wktNum(pr.scale)}],PARAMETER["false_easting",${_wktNum(pr.falseEasting)}],PARAMETER["false_northing",${_wktNum(pr.falseNorthing)}],UNIT["metre",1,AUTHORITY["EPSG","9001"]],'
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
  // projection: transverse Mercator parameters, or a UTM zone in the name
  final method = (root.find('PROJECTION')?.stringArg(0) ?? root.find('CONVERSION')?.find('METHOD')?.stringArg(0) ?? root.find('METHOD')?.stringArg(0) ?? '').toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );
  final unit = _linearUnit(root) ?? 1;
  final params = <String, double>{};
  for (final p in root.findAll('PARAMETER')) {
    final k = (p.stringArg(0) ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final v = p.numArg(1);
    if (v != null) params[k] = v;
  }
  final ellipsoid = datum?.ellipsoid ?? Ellipsoid.wgs84;
  TransverseMercator? tm;
  final zoneMatch =
      RegExp(r'UTM[\s_]*(?:zone[\s_]*)?(\d{1,2})\s*([NS])\b', caseSensitive: false).firstMatch(name) ?? RegExp(r'UTM[\s_]*zone[\s_]*(\d{1,2})([NS])', caseSensitive: false).firstMatch(name);
  if (method.contains('transversemercator') || method.contains('gausskruger') || method == 'tm') {
    final cm = params['centralmeridian'] ?? params['longitudeofnaturalorigin'] ?? params['longitudeoforigin'];
    if (cm != null) {
      tm = TransverseMercator(
        centralMeridian: cm,
        scale: params['scalefactor'] ?? params['scalefactoratnaturalorigin'] ?? 1,
        falseEasting: (params['falseeasting'] ?? 0) * unit,
        falseNorthing: (params['falsenorthing'] ?? 0) * unit,
        latitudeOfOrigin: params['latitudeoforigin'] ?? params['latitudeofnaturalorigin'] ?? 0,
        ellipsoid: ellipsoid,
      );
    }
  }
  if (tm == null && zoneMatch != null && (method.isEmpty || method.contains('mercator'))) {
    tm = TransverseMercator.utm(int.parse(zoneMatch.group(1)!), zoneMatch.group(2)!.toUpperCase() == 'N', ellipsoid);
  }
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
  if (u.contains('NAD83') || u.contains('NAD1983') || u.contains('NORTHAMERICAN1983') || u.contains('NORTHAMERICANDATUM1983')) return GeodeticDatum.nad83;
  if (u.contains('WGS84') || u.contains('WGS1984') || u.contains('WORLDGEODETICSYSTEM1984')) return GeodeticDatum.wgs84;
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
