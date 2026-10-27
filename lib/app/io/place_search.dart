/// Finding a place from an address or place name with OpenStreetMap
/// Nominatim, for the start-up screen and the AI assistant's find_site:
/// at most one request a second (Nominatim's terms), answers cached, the
/// application named outside the browser, the data attributed. The query
/// goes to nominatim.openstreetmap.org only when the user (or the assistant,
/// with the user's approval) asks for it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../version.dart';
import 'http.dart';

/// GET [url] with [headers], the body as text (tests replace it).
typedef SiteFetch = Future<String> Function(Uri url, Map<String, String> headers);

/// How the search reaches Nominatim.
SiteFetch siteFetch = (url, headers) => httpRequest('GET', url.toString(), headers: headers);

/// Nominatim's terms: one request a second at most, the application named,
/// the results cached, the data attributed.
const nominatimAttribution = 'Search results © OpenStreetMap contributors (ODbL), by Nominatim.';
const _nominatimGap = Duration(milliseconds: 1100);
DateTime? _lastSearch;
final Map<String, String> _searchCache = {};

/// A place found: its name, WGS84 position, bounding box (south, north,
/// west, east) when given, and its kind ("place/town", "highway/residential").
class PlaceHit {
  const PlaceHit(this.name, this.lat, this.lon, {this.bbox, this.kind = ''});
  final String name;
  final double lat, lon;
  final List<double>? bbox;
  final String kind;
}

/// The search could not be made or gave no usable answer; [status] is the
/// HTTP status when the service answered.
class PlaceSearchError implements Exception {
  const PlaceSearchError(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Up to [limit] places for [query], names in [lang]; [countryCodes] limits
/// the search (ISO 3166-1 alpha-2, comma separated).
Future<List<PlaceHit>> searchPlaces(String query, {String lang = 'en', String? countryCodes, int limit = 5}) async {
  final url = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'limit': '$limit',
    'accept-language': lang,
    if ((countryCodes ?? '').isNotEmpty) 'countrycodes': countryCodes!.toLowerCase(),
  });
  var body = _searchCache[url.toString()];
  if (body == null) {
    final last = _lastSearch;
    if (last != null) {
      final wait = _nominatimGap - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastSearch = DateTime.now();
    try {
      // browsers send the page as the referrer; elsewhere the application names itself
      body = await siteFetch(url, kIsWeb ? const {} : {'User-Agent': 'OpenCADIrrigation/$appVersion (+https://opencadirrigation.com)'});
    } on HttpStatusException catch (e) {
      throw PlaceSearchError('The search service answered ${e.status}${e.status == 429 ? ' (too many searches)' : ''}.', status: e.status);
    } catch (e) {
      throw PlaceSearchError('The search service could not be reached ($e).');
    }
    _searchCache[url.toString()] = body;
  }
  final Object? j;
  try {
    j = jsonDecode(body);
  } catch (_) {
    throw const PlaceSearchError('The search service gave no usable answer.');
  }
  double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
  return [
    if (j is List)
      for (final h in j)
        if (h is Map && n(h['lat']) != null && n(h['lon']) != null)
          PlaceHit(
            '${h['display_name'] ?? ''}',
            n(h['lat'])!,
            n(h['lon'])!,
            bbox: h['boundingbox'] is List && (h['boundingbox'] as List).length == 4 ? [for (final v in h['boundingbox'] as List) n(v) ?? 0] : null,
            kind: '${h['category'] ?? h['class'] ?? ''}/${h['type'] ?? ''}',
          ),
  ];
}
