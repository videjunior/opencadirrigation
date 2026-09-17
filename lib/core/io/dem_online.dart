/// Online digital elevation models (the "elevation from the internet" of
/// Google Earth workflows): builds the request URLs for a grid of points
/// over the project and parses the answers. Pure Dart; the HTTP call is
/// done by the app layer.
///
/// Sources (both free, keyless and CORS-enabled):
/// - Open-Meteo Elevation API (Copernicus GLO-90), up to 100 points/call.
/// - OpenTopoData (SRTM 30 m, ASTER 30 m…), up to 100 points/call, 1 call/s.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../model/geometry.dart';
import 'geo.dart';

enum DemSource {
  openMeteo('Open-Meteo (Copernicus DEM 90 m)', 100),
  openTopoSrtm('OpenTopoData SRTM 30 m', 100),
  openTopoAster('OpenTopoData ASTER 30 m', 100);

  const DemSource(this.label, this.batch);
  final String label;

  /// Points per request.
  final int batch;

  String get attribution => switch (this) {
    DemSource.openMeteo => 'Open-Meteo.com / Copernicus DEM GLO-90',
    DemSource.openTopoSrtm => 'OpenTopoData / NASA SRTM',
    DemSource.openTopoAster => 'OpenTopoData / ASTER GDEM',
  };
}

class DemGridPoint {
  const DemGridPoint(this.local, this.lat, this.lon);
  final Pt local;
  final double lat;
  final double lon;
}

/// Regular grid of sample points over [bounds] every [spacing] metres,
/// converted to WGS84 with the project georeference.
List<DemGridPoint> demGrid(Bounds bounds, double spacing, GeoReference geo, {int maxPoints = 2500}) {
  if (bounds.isEmpty || spacing <= 0) return const [];
  var s = spacing;
  // cap the number of points: widen the spacing when the area is large
  final n = ((bounds.width / s).floor() + 1) * ((bounds.height / s).floor() + 1);
  if (n > maxPoints) s = spacing * math.sqrt(n / maxPoints);
  final out = <DemGridPoint>[];
  for (var y = bounds.minY; y <= bounds.maxY + 1e-9; y += s) {
    for (var x = bounds.minX; x <= bounds.maxX + 1e-9; x += s) {
      final (lat, lon) = geo.toLatLon(x, y);
      out.add(DemGridPoint(Pt(x, y), lat, lon));
    }
  }
  return out;
}

/// Request URLs, one per batch of points, in the same order as [points].
List<String> demRequestUrls(DemSource source, List<DemGridPoint> points) {
  final urls = <String>[];
  String f(double v) => v.toStringAsFixed(6);
  for (var i = 0; i < points.length; i += source.batch) {
    final chunk = points.sublist(i, math.min(i + source.batch, points.length));
    switch (source) {
      case DemSource.openMeteo:
        urls.add('https://api.open-meteo.com/v1/elevation?latitude=${chunk.map((p) => f(p.lat)).join(',')}&longitude=${chunk.map((p) => f(p.lon)).join(',')}');
      case DemSource.openTopoSrtm:
      case DemSource.openTopoAster:
        final ds = source == DemSource.openTopoSrtm ? 'srtm30m' : 'aster30m';
        urls.add('https://api.opentopodata.org/v1/$ds?locations=${chunk.map((p) => '${f(p.lat)},${f(p.lon)}').join('|')}');
    }
  }
  return urls;
}

/// Elevations (metres) of one batch answer; null where the source has no data.
List<double?> demParseResponse(DemSource source, String body) {
  final j = jsonDecode(body);
  if (j is! Map<String, dynamic>) throw const FormatException('dem_bad_response');
  switch (source) {
    case DemSource.openMeteo:
      final list = j['elevation'];
      if (list is! List) throw FormatException(j['reason'] as String? ?? 'dem_bad_response');
      return [for (final v in list) v == null ? null : (v as num).toDouble()];
    case DemSource.openTopoSrtm:
    case DemSource.openTopoAster:
      if (j['status'] != 'OK') throw FormatException(j['error'] as String? ?? 'dem_bad_response');
      final list = j['results'];
      if (list is! List) throw const FormatException('dem_bad_response');
      return [for (final r in list) (r as Map)['elevation'] == null ? null : (r['elevation'] as num).toDouble()];
  }
}
