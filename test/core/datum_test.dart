import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Abridged Molodensky shift (an independent, approximate formula) used to
/// cross-check the geocentric translation of [datumToWgs84].
(double, double) molodensky(double lat, double lon, Ellipsoid from, Ellipsoid to, double dx, double dy, double dz) {
  final phi = lat * math.pi / 180, lam = lon * math.pi / 180;
  final a = from.a, f = from.f;
  final da = to.a - from.a, df = to.f - from.f;
  final e2 = from.e2;
  final sp = math.sin(phi), cp = math.cos(phi), sl = math.sin(lam), cl = math.cos(lam);
  final rn = a / math.sqrt(1 - e2 * sp * sp);
  final rm = a * (1 - e2) / math.pow(1 - e2 * sp * sp, 1.5);
  final dphi = (-dx * sp * cl - dy * sp * sl + dz * cp + (a * df + f * da) * 2 * sp * cp) / rm;
  final dlam = (-dx * sl + dy * cl) / (rn * cp);
  return (lat + dphi * 180 / math.pi, lon + dlam * 180 / math.pi);
}

double metres(double lat1, double lon1, double lat2, double lon2) {
  final dy = (lat2 - lat1) * 111320;
  final dx = (lon2 - lon1) * 111320 * math.cos(lat1 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  group('transverse Mercator', () {
    test('UTM on WGS 84 matches the projection of geo.dart, both ways', () {
      for (final (lat, lon) in [(-15.78, -47.93), (-22.9, -43.17), (-3.1, -60.0), (40.4, -3.7), (-33.9, 151.2)]) {
        final u = latLonToUtm(lat, lon);
        final tm = TransverseMercator.utm(u.zone, u.north);
        final (e, n) = tm.forward(lat, lon);
        expect(e, closeTo(u.easting, 1e-6));
        expect(n, closeTo(u.northing, 1e-6));
        // the series (to n³, as geo.dart) round-trips to a fraction of a millimetre
        final (la, lo) = tm.inverse(e, n);
        expect(la, closeTo(lat, 1e-8));
        expect(lo, closeTo(lon, 1e-8));
        expect(tm.utmZone, u.zone);
      }
    });

    test('a transverse Mercator with a latitude of origin and other constants round-trips', () {
      const tm = TransverseMercator(centralMeridian: -54, scale: 0.999995, falseEasting: 150000, falseNorthing: 250000, latitudeOfOrigin: -20, ellipsoid: Ellipsoid.grs80);
      final (e, n) = tm.forward(-20, -54);
      expect(e, closeTo(150000, 1e-6));
      expect(n, closeTo(250000, 1e-6));
      final (e2, n2) = tm.forward(-20.1, -53.9);
      final (la, lo) = tm.inverse(e2, n2);
      expect(la, closeTo(-20.1, 1e-8));
      expect(lo, closeTo(-53.9, 1e-8));
      expect(tm.utmZone, isNull);
    });
  });

  group('datum shifts (IBGE)', () {
    test('SAD 69 and Córrego Alegre to SIRGAS 2000 agree with the Molodensky formula and round-trip', () {
      for (final (lat, lon) in [(-15.78, -47.93), (-23.55, -46.63), (-30.03, -51.23), (-8.05, -34.9)]) {
        for (final d in [GeodeticDatum.sad69, GeodeticDatum.corregoAlegre]) {
          final (la, lo) = datumToWgs84(lat, lon, d);
          final (ml, mo) = molodensky(lat, lon, d.ellipsoid, Ellipsoid.grs80, d.dx, d.dy, d.dz);
          expect(metres(la, lo, ml, mo), lessThan(0.5), reason: '$d $lat $lon');
          // heights are not carried: the way back is exact to about 1 mm
          final (bl, bo) = wgs84ToDatum(la, lo, d);
          expect(bl, closeTo(lat, 1e-8));
          expect(bo, closeTo(lon, 1e-8));
        }
      }
    });

    test('the shifts have the expected size in Brasília', () {
      // SAD 69 → SIRGAS 2000 moves positions some 65 m in central Brazil,
      // Córrego Alegre → SIRGAS 2000 some 50 m
      final (la, lo) = datumToWgs84(-15.78, -47.93, GeodeticDatum.sad69);
      expect(metres(-15.78, -47.93, la, lo), inInclusiveRange(55, 80));
      expect(la, lessThan(-15.78)); // SIRGAS latitude is south of the SAD 69 one in central Brazil
      final (lc, oc) = datumToWgs84(-15.78, -47.93, GeodeticDatum.corregoAlegre);
      expect(metres(-15.78, -47.93, lc, oc), inInclusiveRange(35, 65));
      // WGS 84 compatible datums are not shifted
      expect(datumToWgs84(-15.78, -47.93, GeodeticDatum.sirgas2000), (-15.78, -47.93));
    });

    test('geocentric conversion round-trips on every ellipsoid', () {
      for (final e in [Ellipsoid.wgs84, Ellipsoid.grs80, Ellipsoid.sad69, Ellipsoid.international1924]) {
        final (x, y, z) = geodeticToGeocentric(-22.5, -45.25, 812.4, e);
        final (lat, lon, h) = geocentricToGeodetic(x, y, z, e);
        expect(lat, closeTo(-22.5, 1e-10));
        expect(lon, closeTo(-45.25, 1e-10));
        expect(h, closeTo(812.4, 1e-5));
      }
    });
  });

  group('CRS recognition', () {
    test('ESRI .prj of SIRGAS 2000 / UTM 23S', () {
      final c = parseCrs(
        'PROJCS["SIRGAS_2000_UTM_Zone_23S",GEOGCS["GCS_SIRGAS_2000",DATUM["D_SIRGAS_2000",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],'
        'PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",10000000.0],PARAMETER["Central_Meridian",-45.0],PARAMETER["Scale_Factor",0.9996],PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]',
      );
      expect(c.recognised, isTrue);
      expect(c.kind, CrsKind.projected);
      expect(c.datum, GeodeticDatum.sirgas2000);
      expect(c.utmZone, 23);
      expect(c.north, isFalse);
      expect(c.epsgCode, 31983);
    });

    test('OGC WKT with authority codes, SAD69 and Córrego Alegre names, WKT 2', () {
      final ogc = parseCrs(
        'PROJCS["SAD69 / UTM zone 22S",GEOGCS["SAD69",DATUM["South_American_Datum_1969",SPHEROID["GRS 1967 Modified",6378160,298.25,AUTHORITY["EPSG","7050"]],TOWGS84[-57,1,-41,0,0,0,0],AUTHORITY["EPSG","6618"]],'
        'PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4618"]],PROJECTION["Transverse_Mercator"],PARAMETER["latitude_of_origin",0],'
        'PARAMETER["central_meridian",-51],PARAMETER["scale_factor",0.9996],PARAMETER["false_easting",500000],PARAMETER["false_northing",10000000],UNIT["metre",1,AUTHORITY["EPSG","9001"]],AXIS["Easting",EAST],AXIS["Northing",NORTH],AUTHORITY["EPSG","29192"]]',
      );
      expect(ogc.datum, GeodeticDatum.sad69);
      expect(ogc.utmZone, 22);
      expect(ogc.epsgCode, 29192);
      final ca = parseCrs(
        'PROJCS["Corrego_Alegre_UTM_Zone_23S",GEOGCS["GCS_Corrego_Alegre",DATUM["D_Corrego_Alegre",SPHEROID["International_1924",6378388.0,297.0]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],'
        'PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",10000000.0],PARAMETER["Central_Meridian",-45.0],PARAMETER["Scale_Factor",0.9996],PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]',
      );
      expect(ca.datum, GeodeticDatum.corregoAlegre);
      expect(ca.epsgCode, 22523);
      final wkt2 = parseCrs(
        'PROJCRS["SIRGAS 2000 / UTM zone 24S",BASEGEOGCRS["SIRGAS 2000",DATUM["Sistema de Referencia Geocentrico para las AmericaS 2000",ELLIPSOID["GRS 1980",6378137,298.257222101,LENGTHUNIT["metre",1]]],'
        'PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],ID["EPSG",4674]],CONVERSION["UTM zone 24S",METHOD["Transverse Mercator",ID["EPSG",9807]],PARAMETER["Latitude of natural origin",0,ANGLEUNIT["degree",0.0174532925199433]],'
        'PARAMETER["Longitude of natural origin",-39,ANGLEUNIT["degree",0.0174532925199433]],PARAMETER["Scale factor at natural origin",0.9996,SCALEUNIT["unity",1]],PARAMETER["False easting",500000,LENGTHUNIT["metre",1]],'
        'PARAMETER["False northing",10000000,LENGTHUNIT["metre",1]]],CS[Cartesian,2],AXIS["easting (E)",east,ORDER[1],LENGTHUNIT["metre",1]],AXIS["northing (N)",north,ORDER[2],LENGTHUNIT["metre",1]]]',
      );
      expect(wkt2.recognised, isTrue);
      expect(wkt2.datum, GeodeticDatum.sirgas2000);
      expect(wkt2.utmZone, 24);
      expect(wkt2.epsgCode, 31984);
      final geo = parseCrs('GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]');
      expect(geo.kind, CrsKind.geographic);
      expect(geo.datum, GeodeticDatum.wgs84);
      expect(
        parseCrs('GEOGCS["SAD69(96)",DATUM["South_American_Datum_1969_96",SPHEROID["GRS 1967 Modified",6378160,298.25]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]').datum,
        GeodeticDatum.sad69r96,
      );
    });

    test('EPSG codes and URNs', () {
      expect(parseCrs('EPSG:31983').utmZone, 23);
      expect(parseCrs('urn:ogc:def:crs:EPSG::32723').datum, GeodeticDatum.wgs84);
      expect(parseCrs('urn:ogc:def:crs:OGC:1.3:CRS84').kind, CrsKind.geographic);
      expect(parseCrs('urn:ogc:def:crs:EPSG::4674').datum, GeodeticDatum.sirgas2000);
      expect(crsFromEpsg(29193).datum, GeodeticDatum.sad69);
      expect(crsFromEpsg(29193).utmZone, 23);
      expect(crsFromEpsg(6210).north, isTrue);
      expect(crsFromEpsg(22522).datum, GeodeticDatum.corregoAlegre);
      expect(crsFromEpsg(25832).datum, GeodeticDatum.etrs89);
      for (final d in GeodeticDatum.values) {
        expect(crsFromEpsg(d.geographicEpsg).datum, d);
      }
    });

    test('unrecognised systems carry a problem code instead of a guess', () {
      expect(parseCrs('EPSG:3857').problem, 'crs_epsg_unknown'); // web Mercator
      final stereo = parseCrs(
        'PROJCS["Polar_Stereo",GEOGCS["GCS_SIRGAS_2000",DATUM["D_SIRGAS_2000",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],'
        'PROJECTION["Stereographic_South_Pole"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],PARAMETER["Standard_Parallel_1",-71.0],UNIT["Meter",1.0]]',
      );
      expect(stereo.recognised, isFalse);
      expect(stereo.problem, 'crs_projection_unsupported');
      final unknownDatum = parseCrs(
        'PROJCS["Local_UTM",GEOGCS["GCS_Unknown",DATUM["D_Unknown",SPHEROID["Clarke_1866",6378206.4,294.9786982]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],'
        'PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",-45.0],PARAMETER["Scale_Factor",0.9996],PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]',
      );
      expect(unknownDatum.problem, 'crs_datum_unknown');
      expect(parseCrs('not a crs [').problem, 'crs_unparsed');
      expect(parseCrs('GEOCCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["metre",1]]').problem, 'crs_geocentric');
    });

    test('ESRI and OGC WKT written for a project read back as the same CRS', () {
      for (final d in GeodeticDatum.values) {
        for (final c in [CrsInfo.utm(23, false, datum: d), CrsInfo.utm(19, true, datum: d), CrsInfo.geographic(d)]) {
          for (final wkt in [c.toEsriWkt(), c.toOgcWkt()]) {
            final back = parseCrs(wkt);
            expect(back.recognised, isTrue, reason: wkt);
            expect(back.datum, d, reason: wkt);
            expect(back.kind, c.kind);
            expect(back.utmZone, c.utmZone);
            expect(back.north, c.north);
          }
        }
      }
    });
  });

  group('placement in the project frame', () {
    test('UTM on SIRGAS 2000 in the project zone is a plain offset; another zone goes through lat/lon', () {
      const g = GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
      final pl = GeoPlacement.plan(CrsInfo.utm(23, false, datum: GeodeticDatum.sirgas2000), [(186056.581, 8253215.209)], georef: g);
      expect(pl.georefCreated, isFalse);
      final p = pl.place(186056.581, 8253215.209);
      expect(p.x, closeTo(56.581, 1e-9));
      expect(p.y, closeTo(15.209, 1e-9));
      // the same point in zone 22 coordinates lands in the same place
      final u22 = latLonToUtm(-15.78, -47.93, zone: 22);
      final pl22 = GeoPlacement.plan(CrsInfo.utm(22, false), [(u22.easting, u22.northing)], georef: g);
      final q = pl22.place(u22.easting, u22.northing);
      expect(q.distanceTo(p), lessThan(0.01));
    });

    test('SAD 69 UTM data is shifted to the SIRGAS 2000 position', () {
      // a SIRGAS 2000 point expressed in SAD 69 / UTM 23S, read back
      final sad = CrsInfo.utm(23, false, datum: GeodeticDatum.sad69);
      final (e, n) = sad.fromWgs84(-15.78, -47.93);
      const g = GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
      final pl = GeoPlacement.plan(sad, [(e, n)], georef: g);
      final p = pl.place(e, n);
      expect(p.distanceTo(const Pt(56.581, 15.209)), lessThan(0.01));
      expect(pl.warnings.single, startsWith('crs_datum_shift:sad69:'));
      // without the shift the point would be tens of metres away
      expect(Pt(e - g.originEasting, n - g.originNorthing).distanceTo(p), greaterThan(30));
    });

    test('a georeference is created from the data; geographic, local and unknown data', () {
      final pl = GeoPlacement.plan(CrsInfo.geographic(), [(-47.93, -15.78), (-47.92, -15.77)]);
      expect(pl.georefCreated, isTrue);
      expect(pl.georef!.zone, 23);
      expect(pl.place(-47.925, -15.775).length, lessThan(1000));
      final assumed = GeoPlacement.plan(null, [(-47.93123, -15.78456)]);
      expect(assumed.warnings, ['crs_assumed_wgs84']);
      final local = GeoPlacement.plan(null, [(10, 20), (30, 40)]);
      expect(local.warnings, ['crs_missing']);
      expect(local.place(10, 20), const Pt(10, 20));
      expect(local.georef, isNull);
      // web Mercator (Brazil Polyconic, 5880, is known since 1.6.0)
      final unknown = GeoPlacement.plan(parseCrs('EPSG:3857'), [(5123456.7, 8123456.7)]);
      expect(unknown.warnings, ['crs_epsg_unknown']);
      expect(unknown.georef, isNull);
      expect(unknown.localOrigin, const Pt(5123500, 8123500));
      expect(unknown.place(5123456.7, 8123456.7).distanceTo(const Pt(-43.3, -43.3)), lessThan(1e-6));
    });

    test('UTM south data placed in a northern-hemisphere reference of the same zone', () {
      const g = GeoReference(zone: 33, north: true, originEasting: 400000, originNorthing: 0);
      final pl = GeoPlacement.plan(CrsInfo.utm(33, false), [(400100, 9999900)], georef: g);
      // 9 999 900 m in the southern convention is 100 m south of the equator
      expect(pl.place(400100, 9999900).y, closeTo(-100, 1e-9));
    });
  });
}
