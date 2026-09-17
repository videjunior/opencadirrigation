import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/terrain.dart';

/// Coordinates typed or pasted by the user, and the automatic contour interval.
void main() {
  group('parseLatLon', () {
    void ok(String text, double lat, double lon) {
      final r = parseLatLon(text);
      expect(r, isNotNull, reason: text);
      expect(r!.$1, closeTo(lat, 1e-4), reason: text);
      expect(r.$2, closeTo(lon, 1e-4), reason: text);
    }

    test('decimal degrees in the usual separators and decimal marks', () {
      ok('-22.9068, -43.1729', -22.9068, -43.1729);
      ok('-22.9068 -43.1729', -22.9068, -43.1729);
      ok('-22.9068;-43.1729', -22.9068, -43.1729);
      ok('  -22,9068  -43,1729 ', -22.9068, -43.1729);
      ok('-22,9068, -43,1729', -22.9068, -43.1729);
      ok('-22, -43', -22, -43);
      ok('40.7128, -74.0060', 40.7128, -74.006);
      ok('lat -22.9068 lon -43.1729', -22.9068, -43.1729);
    });

    test('hemisphere letters, DMS and links', () {
      ok('22.9068 S 43.1729 W', -22.9068, -43.1729);
      ok('22.9068S, 43.1729W', -22.9068, -43.1729);
      ok('S 22.9068 W 43.1729', -22.9068, -43.1729);
      ok('40.7128 N 74.0060 W', 40.7128, -74.006);
      ok('22°54\'24.5"S 43°10\'22.4"W', -(22 + 54 / 60 + 24.5 / 3600), -(43 + 10 / 60 + 22.4 / 3600));
      ok('43°10′22″W 22°54′24″S', -(22 + 54 / 60 + 24 / 3600), -(43 + 10 / 60 + 22 / 3600));
      ok('https://www.google.com/maps/@-22.9068,-43.1729,17z/data=!3m1', -22.9068, -43.1729);
      ok('https://maps.google.com/?q=-22.9068,-43.1729', -22.9068, -43.1729);
      ok('geo:-22.9068,-43.1729', -22.9068, -43.1729);
    });

    test('lon, lat order (KML) is swapped when only that makes sense; junk is refused', () {
      ok('-100.5, 30.2', 30.2, -100.5);
      ok('120.5, 30.2', 30.2, 120.5);
      ok('-43.1729, -22.9068', -43.1729, -22.9068); // both valid latitudes: kept as typed
      expect(parseLatLon(''), isNull);
      expect(parseLatLon('hello'), isNull);
      expect(parseLatLon('12'), isNull);
      expect(parseLatLon('95, 200'), isNull);
      expect(parseLatLon('-100, -100'), isNull);
    });
  });

  test('niceContourInterval keeps about twenty contours', () {
    expect(niceContourInterval(3), 0.25);
    expect(niceContourInterval(8), 0.5);
    expect(niceContourInterval(15), 1);
    expect(niceContourInterval(35), 2);
    expect(niceContourInterval(90), 5);
    expect(niceContourInterval(150), 10);
    expect(niceContourInterval(5000), 100);
    expect(niceContourInterval(0), 1);
    expect(niceContourInterval(double.nan), 1);
    expect(niceContourInterval(40, maxContours: 10), 5);
  });
}
