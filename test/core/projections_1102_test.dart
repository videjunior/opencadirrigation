// Projections beyond the transverse Mercator (1.6.0): Albers equal-area
// conic, Lambert conformal conic (one and two parallels) and the American
// polyconic, checked against the worked examples of Snyder (1987, USGS PP
// 1395, appendix A) and of the EPSG guidance note 7-2, and against the
// national systems of Brazil (IBGE's Brazil Polyconic and Brazil Albers).
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';

/// Clarke 1866, the ellipsoid of Snyder's examples.
const clarke1866 = Ellipsoid(6378206.4, 294.9786982);

void roundTrip(MapProjection p, double lat, double lon) {
  final (e, n) = p.forward(lat, lon);
  final (la, lo) = p.inverse(e, n);
  expect(la, closeTo(lat, 1e-9), reason: '${p.runtimeType} latitude at ($lat, $lon)');
  expect(lo, closeTo(lon, 1e-9), reason: '${p.runtimeType} longitude at ($lat, $lon)');
}

void main() {
  group('worked examples', () {
    test('Albers equal-area conic (Snyder, p. 292)', () {
      final p = AlbersEqualArea(centralMeridian: -96, latitudeOfOrigin: 23, standardParallel1: 29.5, standardParallel2: 45.5, ellipsoid: clarke1866);
      final (x, y) = p.forward(35, -75);
      expect(x, closeTo(1885472.7, 0.1));
      expect(y, closeTo(1535925.0, 0.1));
      roundTrip(p, 35, -75);
    });

    test('Lambert conformal conic, two parallels (Snyder, p. 296; EPSG 9802 Texas South Central)', () {
      final p = LambertConformalConic(centralMeridian: -96, latitudeOfOrigin: 23, standardParallel1: 33, standardParallel2: 45, ellipsoid: clarke1866);
      final (x, y) = p.forward(35, -75);
      expect(x, closeTo(1894410.9, 0.1));
      expect(y, closeTo(1564649.5, 0.1));
      roundTrip(p, 35, -75);
      // EPSG guidance note 7-2: E = 2 963 503.91 US ft, N = 254 759.80 US ft
      final texas = LambertConformalConic(
        centralMeridian: -99,
        latitudeOfOrigin: 27 + 50 / 60,
        standardParallel1: 28 + 23 / 60,
        standardParallel2: 30 + 17 / 60,
        falseEasting: 2000000 * 1200 / 3937,
        ellipsoid: clarke1866,
      );
      final (e, n) = texas.forward(28.5, -96);
      expect(e / (1200 / 3937), closeTo(2963503.91, 0.01));
      expect(n / (1200 / 3937), closeTo(254759.80, 0.01));
    });

    test('Lambert conformal conic, one parallel (EPSG 9801 Jamaica National Grid)', () {
      final p = LambertConformalConic.oneParallel(centralMeridian: -77, latitudeOfOrigin: 18, falseEasting: 250000, falseNorthing: 150000, ellipsoid: clarke1866);
      expect(p.oneParallel, isTrue);
      final (e, n) = p.forward(17 + 55 / 60 + 55.80 / 3600, -(76 + 56 / 60 + 37.26 / 3600));
      expect(e, closeTo(255966.58, 0.01));
      expect(n, closeTo(142493.51, 0.01));
    });

    test('American polyconic (Snyder, p. 303)', () {
      const p = Polyconic(centralMeridian: -96, latitudeOfOrigin: 30, ellipsoid: clarke1866);
      final (x, y) = p.forward(40, -75);
      expect(x, closeTo(1776774.5, 0.1));
      expect(y, closeTo(1319657.8, 0.1));
      roundTrip(p, 40, -75);
      // on the equator and back
      roundTrip(p, 0.5, -90);
      final (x0, y0) = p.forward(0, -90);
      final (la, lo) = p.inverse(x0, y0);
      expect(la, closeTo(0, 1e-9));
      expect(lo, closeTo(-90, 1e-9));
    });
  });

  group('national systems by EPSG code', () {
    test('SIRGAS 2000 / Brazil Polyconic (5880) and SAD69 / Brazil Polyconic (29101)', () {
      final c = crsFromEpsg(5880);
      expect(c.recognised, isTrue);
      expect(c.datum, GeodeticDatum.sirgas2000);
      final (e, n) = c.projection!.forward(-15.78, -47.93);
      expect(e, closeTo(5650314.885, 0.01));
      expect(n, closeTo(8245332.935, 0.01));
      final (e2, n2) = c.projection!.forward(-3.1, -60.0);
      expect(e2, closeTo(4333057.474, 0.01));
      expect(n2, closeTo(9655327.895, 0.01));
      final sad = crsFromEpsg(29101);
      expect(sad.datum, GeodeticDatum.sad69);
      final (e3, n3) = sad.projection!.forward(-22.9, -43.17);
      expect(e3, closeTo(6110137.720, 0.01));
      expect(n3, closeTo(7425683.223, 0.01));
    });

    test('SIRGAS 2000 / Brazil Albers (10857)', () {
      final c = crsFromEpsg(10857);
      expect(c.recognised, isTrue);
      final (e, n) = c.projection!.forward(-15.78, -47.93);
      expect(e, closeTo(5641804.980, 0.01));
      expect(n, closeTo(9568677.470, 0.01));
      final (e2, n2) = c.projection!.forward(-29.0, -51.0);
      expect(e2, closeTo(5301580.786, 0.01));
      expect(n2, closeTo(8115547.171, 0.01));
    });

    test('Lambert-93, LCC Europe, Conus Albers and Mexico LCC', () {
      for (final (code, lat, lon, e, n) in [
        (2154, 48.8566, 2.3522, 652469.023, 6862035.259),
        (3034, 40.4168, -3.7038, 2865882.327, 1656297.398),
        (5070, 39.74, -104.99, -762375.215, 1893930.440),
        (6372, 19.4326, -99.1332, 2800163.326, 829057.519),
      ]) {
        final c = crsFromEpsg(code);
        expect(c.recognised, isTrue, reason: '$code');
        final (x, y) = c.projection!.forward(lat, lon);
        expect(x, closeTo(e, 0.01), reason: '$code easting');
        expect(y, closeTo(n, 0.01), reason: '$code northing');
        roundTrip(c.projection!, lat, lon);
      }
    });
  });

  group('WKT', () {
    const gcsSirgas = 'GEOGCS["GCS_SIRGAS_2000",DATUM["D_SIRGAS_2000",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]';

    test('an ESRI .prj of the Brazil Polyconic places points as the EPSG code does', () {
      final poly = parseCrs(
        'PROJCS["SIRGAS_2000_Brazil_Polyconic",$gcsSirgas,'
        'PROJECTION["Polyconic"],PARAMETER["False_Easting",5000000.0],PARAMETER["False_Northing",10000000.0],PARAMETER["Central_Meridian",-54.0],PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]',
      );
      expect(poly.recognised, isTrue);
      expect(poly.projection, isA<Polyconic>());
      final (lat, lon) = poly.toWgs84(5650314.885410829, 8245332.935142694);
      expect(lat, closeTo(-15.78, 1e-8));
      expect(lon, closeTo(-47.93, 1e-8));
    });

    test('ESRI Albers and OGC Albers_Conic_Equal_Area with latitude_of_center', () {
      final esri = parseCrs(
        'PROJCS["South_America_Albers_Equal_Area_Conic",$gcsSirgas,PROJECTION["Albers"],PARAMETER["False_Easting",5000000.0],PARAMETER["False_Northing",10000000.0],'
        'PARAMETER["Central_Meridian",-54.0],PARAMETER["Standard_Parallel_1",-2.0],PARAMETER["Standard_Parallel_2",-22.0],PARAMETER["Latitude_Of_Origin",-12.0],UNIT["Meter",1.0]]',
      );
      final ogc = parseCrs(
        'PROJCS["SIRGAS 2000 / Brazil Albers",GEOGCS["SIRGAS 2000",DATUM["Sistema_de_Referencia_Geocentrico_para_las_AmericaS_2000",SPHEROID["GRS 1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],'
        'PROJECTION["Albers_Conic_Equal_Area"],PARAMETER["latitude_of_center",-12],PARAMETER["longitude_of_center",-54],PARAMETER["standard_parallel_1",-2],PARAMETER["standard_parallel_2",-22],'
        'PARAMETER["false_easting",5000000],PARAMETER["false_northing",10000000],UNIT["metre",1]]',
      );
      for (final c in [esri, ogc]) {
        expect(c.recognised, isTrue);
        final (x, y) = c.fromWgs84(-15.78, -47.93);
        expect(x, closeTo(5641804.980, 0.01));
        expect(y, closeTo(9568677.470, 0.01));
      }
    });

    test('WKT 2 Lambert Conic Conformal (2SP) with false-origin parameters', () {
      final c = parseCrs(
        'PROJCRS["RGF93 v1 / Lambert-93",BASEGEOGCRS["RGF93 v1",DATUM["Reseau Geodesique Francais 1993 v1",ELLIPSOID["GRS 1980",6378137,298.257222101,LENGTHUNIT["metre",1]]],'
        'PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]]],CONVERSION["Lambert-93",METHOD["Lambert Conic Conformal (2SP)",ID["EPSG",9802]],'
        'PARAMETER["Latitude of false origin",46.5,ANGLEUNIT["degree",0.0174532925199433]],PARAMETER["Longitude of false origin",3,ANGLEUNIT["degree",0.0174532925199433]],'
        'PARAMETER["Latitude of 1st standard parallel",49,ANGLEUNIT["degree",0.0174532925199433]],PARAMETER["Latitude of 2nd standard parallel",44,ANGLEUNIT["degree",0.0174532925199433]],'
        'PARAMETER["Easting at false origin",700000,LENGTHUNIT["metre",1]],PARAMETER["Northing at false origin",6600000,LENGTHUNIT["metre",1]]],'
        'CS[Cartesian,2],AXIS["easting (X)",east],AXIS["northing (Y)",north],LENGTHUNIT["metre",1]]',
      );
      expect(c.recognised, isTrue);
      expect(c.datum, GeodeticDatum.etrs89);
      final (x, y) = c.fromWgs84(48.8566, 2.3522);
      expect(x, closeTo(652469.023, 0.01));
      expect(y, closeTo(6862035.259, 0.01));
    });

    test('the ESRI and OGC WKT written for each projection read back the same', () {
      for (final code in [5880, 29101, 10857, 2154, 3034, 5070, 6372]) {
        final c = crsFromEpsg(code);
        for (final wkt in [c.toEsriWkt(), c.toOgcWkt()]) {
          final back = parseCrs(wkt);
          expect(back.recognised, isTrue, reason: wkt);
          expect(back.projection.runtimeType, c.projection.runtimeType, reason: wkt);
          final (x, y) = c.fromWgs84(-10, -50);
          final (bx, by) = back.fromWgs84(-10, -50);
          expect(bx, closeTo(x, 1e-3), reason: wkt);
          expect(by, closeTo(y, 1e-3), reason: wkt);
        }
      }
    });
  });

  test('data in the Brazil Polyconic lands in the project UTM zone where it belongs', () {
    // a point of a SIRGAS 2000 polyconic map, placed in a project of zone 23S
    final c = crsFromEpsg(5880);
    final (x, y) = c.fromWgs84(-15.78, -47.93);
    final u = latLonToUtm(-15.78, -47.93);
    final plan = GeoPlacement.plan(c, [(x, y)], georef: GeoReference(zone: u.zone, north: u.north, originEasting: 186000, originNorthing: 8253000));
    final p = plan.place(x, y);
    expect(p.x, closeTo(u.easting - 186000, 1e-3));
    expect(p.y, closeTo(u.northing - 8253000, 1e-3));
  });
}
