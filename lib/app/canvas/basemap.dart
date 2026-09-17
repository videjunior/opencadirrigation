/// Background map tiles drawn under the drawing when the project is
/// georeferenced: OpenStreetMap, OpenTopoMap, CARTO, Esri (imagery, streets,
/// topographic), the Google Map Tiles API (with the user's own key) or a
/// custom XYZ template. Tiles are Web Mercator; each tile is placed by its
/// lat/lon corners converted to local UTM coordinates (an affine fit per
/// tile), which is accurate at field scale.
///
/// Where a server has no tile at the requested zoom (imagery ends at z17–18
/// over most farmland while a close view asks for z19–20) the layer draws
/// the nearest ancestor tile, scaled, instead of the provider's "map data
/// not yet available" placeholder. The ArcGIS services say which tiles
/// exist through their `tilemap` resource (32×32 blocks, asked before the
/// tiles); other servers answer 404 (or, on the web, a fetch error when the
/// error page carries no CORS header), which is recorded the same way.
/// Ancestors already in the cache are also shown while the finer tiles
/// load, and the Google maps follow the maximum zoom the Map Tiles API
/// reports for the viewport.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/io/geo.dart';
import '../../core/model/geometry.dart';
import '../io/http.dart';
import '../state/controller.dart';
import 'camera.dart';

/// What the layer needs from the app state to fetch and draw tiles.
class BaseMapOptions {
  const BaseMapOptions(this.map, {this.opacity = 0.8, this.googleKey, this.customUrl = '', this.lang = 'en', this.epoch = 0});
  final BaseMap map;
  final double opacity;

  /// Google Maps Platform API key (Map Tiles API); null when not set.
  final String? googleKey;

  /// XYZ template of [BaseMap.custom].
  final String customUrl;

  /// Interface language: labels of the Google maps follow it.
  final String lang;

  /// Bumped when the key or the template is saved again, so that sessions
  /// and errors are retried even when the text did not change.
  final int epoch;
}

class _GoogleSession {
  _GoogleSession(this.token, this.expiry);
  final String token;
  final DateTime expiry;
  bool get valid => DateTime.now().isBefore(expiry);
}

/// One answer of an ArcGIS `tilemap` request: which tiles of a block exist
/// at a zoom level (the server may clip the block to its tile bundles, so
/// the answered rectangle can be smaller than the 32×32 asked for).
class TileBlock {
  TileBlock(this.top, this.left, this.width, this.height, this.data);
  final int top, left, width, height;

  /// 1 where the tile exists; null while the answer is pending.
  final List<int>? data;

  bool get pending => data == null;
  bool contains(int x, int y) => x >= left && y >= top && x < left + width && y < top + height;

  bool has(int x, int y) {
    final d = data;
    if (d == null) return true;
    final i = (y - top) * width + (x - left);
    return i >= 0 && i < d.length && d[i] == 1;
  }

  /// Parses the JSON answer for a block asked at ([top], [left]); an error
  /// or invalid answer means no tiles there.
  static TileBlock parse(String text, int top, int left, {int size = 32}) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final raw = j['data'];
    if (raw is! List || j['error'] != null || j['valid'] == false) return TileBlock(top, left, size, size, List.filled(size * size, 0));
    final loc = j['location'];
    int at(String k, int d) => loc is Map ? ((loc[k] as num?)?.toInt() ?? d) : d;
    return TileBlock(at('top', top), at('left', left), at('width', size), at('height', size), [for (final v in raw) v is num && v.toInt() == 1 ? 1 : 0]);
  }
}

class BaseMapLayer extends ChangeNotifier {
  BaseMapLayer({this.maxTiles = 240});
  final int maxTiles;
  final Map<String, ui.Image> _tiles = {};
  final Set<String> _loading = {};

  /// Tiles the server answered 404 for (no data at that zoom there).
  final Set<String> _missing = {};
  final List<String> _order = [];

  /// ArcGIS tilemap blocks per '${map}/${z}'.
  final Map<String, List<TileBlock>> _blocks = {};
  int _failures = 0;
  DateTime _lastFailure = DateTime.fromMillisecondsSinceEpoch(0);
  BaseMap? _lastMap;
  String _customUrl = '';
  int _epoch = 0;

  // Google Map Tiles API: one session per map type, the key and language
  // that created them, the copyright of the current viewport and the last
  // error (invalid key, API not enabled on the project...).
  final Map<BaseMap, _GoogleSession> _sessions = {};
  final Set<BaseMap> _sessionPending = {};
  String? _sessionKey;
  String _sessionLang = '';
  String _googleCopyright = '';
  int? _googleMaxZoom;
  String? _googleError;
  String _viewportKey = '';
  Timer? _viewportTimer;

  static const googleTilesHost = 'https://tile.googleapis.com';

  /// Tile URL. Google maps need the [session] token of the map type and the
  /// user's [key]; the custom map its [custom] template.
  static String url(BaseMap m, int z, int x, int y, {String session = '', String key = '', String custom = ''}) => switch (m) {
    BaseMap.none => '',
    BaseMap.streets => 'https://tile.openstreetmap.org/$z/$x/$y.png',
    BaseMap.topo => 'https://tile.opentopomap.org/$z/$x/$y.png',
    BaseMap.carto => 'https://basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png',
    BaseMap.satellite => _esri('World_Imagery', z, x, y),
    BaseMap.esriStreets => _esri('World_Street_Map', z, x, y),
    BaseMap.esriTopo => _esri('World_Topo_Map', z, x, y),
    BaseMap.googleRoads || BaseMap.googleSatellite || BaseMap.googleHybrid || BaseMap.googleTerrain =>
      '$googleTilesHost/v1/2dtiles/$z/$x/$y?session=${Uri.encodeQueryComponent(session)}&key=${Uri.encodeQueryComponent(key)}',
    BaseMap.custom => customUrl(custom, z, x, y),
  };

  /// `blankTile=false` makes the ArcGIS server answer 404 where it has no
  /// tile at that zoom instead of a "map data not yet available" image
  /// (the tilemap is asked first, so this is only a safety net).
  static String _esri(String service, int z, int x, int y) => 'https://server.arcgisonline.com/ArcGIS/rest/services/$service/MapServer/tile/$z/$y/$x?blankTile=false';

  static String? _esriService(BaseMap m) => switch (m) {
    BaseMap.satellite => 'World_Imagery',
    BaseMap.esriStreets => 'World_Street_Map',
    BaseMap.esriTopo => 'World_Topo_Map',
    _ => null,
  };

  /// The `tilemap` resource of an ArcGIS service: a JSON block saying which
  /// tiles exist from row [top], column [left] ([size] × [size]).
  static String esriTilemapUrl(BaseMap m, int z, int top, int left, {int size = 32}) => 'https://server.arcgisonline.com/ArcGIS/rest/services/${_esriService(m)}/MapServer/tilemap/$z/$top/$left/$size/$size';

  /// Fills an XYZ template: `{z}` `{x}` `{y}`, `{-y}` (TMS row, counted
  /// from the south) and `{s}` (subdomain a/b/c, or the letters given as
  /// `{s:abcd}`).
  static String customUrl(String template, int z, int x, int y) {
    var u = template.trim();
    final sub = RegExp(r'\{s(?::([a-z0-9]+))?\}').firstMatch(u);
    if (sub != null) {
      final letters = sub.group(1) ?? 'abc';
      u = u.replaceAll(sub.group(0)!, letters[(x + y) % letters.length]);
    }
    return u.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{-y}', '${(1 << z) - 1 - y}').replaceAll('{y}', '$y');
  }

  /// A usable template: http(s) with the three tile placeholders.
  static bool isValidTemplate(String t) {
    final s = t.trim();
    return s.startsWith(RegExp(r'https?://')) && s.contains('{z}') && s.contains('{x}') && (s.contains('{y}') || s.contains('{-y}'));
  }

  /// Fixed attribution of each source; the Google maps show the copyright
  /// the API reports for the viewport (see [attributionText]).
  static String attribution(BaseMap m) => switch (m) {
    BaseMap.none || BaseMap.custom => '',
    BaseMap.streets => '© OpenStreetMap contributors',
    BaseMap.topo => '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
    BaseMap.carto => '© OpenStreetMap contributors · © CARTO',
    BaseMap.satellite => 'Esri, Maxar, Earthstar Geographics',
    BaseMap.esriStreets || BaseMap.esriTopo => 'Esri, HERE, Garmin, FAO, NOAA, USGS, © OpenStreetMap contributors',
    BaseMap.googleRoads || BaseMap.googleSatellite || BaseMap.googleHybrid || BaseMap.googleTerrain => 'Google',
  };

  /// Highest zoom requested from each source; closer views scale the tiles
  /// up (and the 404 fallback covers areas whose imagery stops earlier).
  static int maxZoom(BaseMap m) => switch (m) {
    BaseMap.none => 0,
    BaseMap.topo => 17,
    BaseMap.streets || BaseMap.esriStreets || BaseMap.esriTopo || BaseMap.custom => 19,
    BaseMap.carto || BaseMap.satellite => 20,
    BaseMap.googleRoads || BaseMap.googleSatellite || BaseMap.googleHybrid || BaseMap.googleTerrain => 21,
  };

  /// Body of the Map Tiles API `createSession` request for a map type.
  static Map<String, Object> googleSessionRequest(BaseMap m, String lang) => {
    'mapType': switch (m) {
      BaseMap.googleSatellite || BaseMap.googleHybrid => 'satellite',
      BaseMap.googleTerrain => 'terrain',
      _ => 'roadmap',
    },
    if (m == BaseMap.googleHybrid || m == BaseMap.googleTerrain) 'layerTypes': ['layerRoadmap'],
    'language': switch (lang) { 'pt' => 'pt-BR', 'es' => 'es-419', _ => 'en-US' },
    if (lang == 'pt') 'region': 'BR',
  };

  /// Zoom level whose tile pixel is close to one screen pixel.
  static int zoomFor(double metresPerPixel, double lat, {int maxZoom = 19}) {
    final ground = 156543.03392 * math.cos(lat * math.pi / 180); // m/px at z=0
    final z = (math.log(ground / math.max(metresPerPixel, 1e-6)) / math.ln2).round();
    return z.clamp(1, math.max(1, maxZoom));
  }

  /// Part of the ancestor tile [k] levels up that covers tile (x, y), in
  /// the ancestor's pixels.
  static ui.Rect ancestorSource(int x, int y, int k, int w, int h) {
    final n = 1 << k;
    final sw = w / n, sh = h / n;
    return ui.Rect.fromLTWH((x & (n - 1)) * sw, (y & (n - 1)) * sh, sw, sh);
  }

  static (double, double) _tileXY(double lat, double lon, int z) {
    final n = math.pow(2, z).toDouble();
    final x = (lon + 180) / 360 * n;
    final latR = lat * math.pi / 180;
    final y = (1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n;
    return (x, y);
  }

  static (double, double) _latLonOf(double x, double y, int z) {
    final n = math.pow(2, z).toDouble();
    final lon = x / n * 360 - 180;
    final latR = math.atan(_sinh(math.pi * (1 - 2 * y / n)));
    return (latR * 180 / math.pi, lon);
  }

  static double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;

  static String _key(BaseMap m, int z, int x, int y) => '${m.name}/$z/$x/$y';

  /// Last error of the Google Map Tiles API (key rejected, API not enabled,
  /// quota...), cleared when the map is selected again or the key changes.
  String? get googleError => _googleError;

  /// Attribution to draw for [m]: the source's fixed credit, or for Google
  /// the copyright reported for the current viewport.
  String attributionText(BaseMap m) {
    if (!m.isGoogle) return attribution(m);
    return _googleCopyright.isEmpty ? attribution(m) : _googleCopyright;
  }

  int get tileCount => _tiles.length;

  void _store(String key, ui.Image img) {
    _tiles[key] = img;
    _order.add(key);
    while (_order.length > maxTiles) {
      _tiles.remove(_order.removeAt(0))?.dispose();
    }
  }

  void _evict(bool Function(String key) test) {
    for (final k in _tiles.keys.where(test).toList()) {
      _tiles.remove(k)?.dispose();
    }
    _order.removeWhere(test);
    _missing.removeWhere(test);
    _blocks.removeWhere((k, _) => test(k));
  }

  void _markMissing(String key) {
    if (_missing.length > 4000) _missing.clear();
    _missing.add(key);
  }

  /// After many failed downloads (offline, blocked) the layer pauses its
  /// requests for a while instead of hammering the server.
  bool get _paused {
    if (_failures <= 40) return false;
    if (DateTime.now().difference(_lastFailure) < const Duration(seconds: 20)) return true;
    _failures = 0;
    _missing.clear();
    return false;
  }

  void _request(BaseMap m, int z, int x, int y, String session, String apiKey, String custom) {
    final key = _key(m, z, x, y);
    if (_tiles.containsKey(key) || _loading.contains(key) || _missing.contains(key) || _paused) return;
    _loading.add(key);
    httpBytes(url(m, z, x, y, session: session, key: apiKey, custom: custom)).then((bytes) => ui.instantiateImageCodec(Uint8List.fromList(bytes))).then((codec) => codec.getNextFrame()).then((frame) {
      _loading.remove(key);
      _store(key, frame.image);
      notifyListeners();
    }).catchError((Object e) {
      _loading.remove(key);
      if (m.isGoogle && e is HttpStatusException && (e.status == 400 || e.status == 403)) {
        _googleError = e.message;
      } else {
        // 404 (no tile there), or a network/CORS failure: fall back to the
        // parent tile either way, but count the failures
        _markMissing(key);
        if (e is! HttpStatusException || e.status != 404) {
          _failures++;
          _lastFailure = DateTime.now();
        }
      }
      notifyListeners(); // the next paint asks for the parent tile
    });
  }

  /// Whether the ArcGIS service has tile (z, x, y) according to its
  /// tilemap: true/false, or null while the block covering it is fetched.
  bool? _esriHas(BaseMap m, int z, int x, int y) {
    final list = _blocks.putIfAbsent('${m.name}/$z', () => []);
    for (final b in list) {
      if (b.contains(x, y)) return b.pending ? null : b.has(x, y);
    }
    if (_paused) return true;
    if (list.length > 400) list.clear();
    // ask from this tile on: a block clipped by the server leaves the tiles
    // past its edge uncovered, and they start the next request
    final top = y, left = x;
    final pending = TileBlock(top, left, 32, 32, null);
    list.add(pending);
    httpRequest('GET', esriTilemapUrl(m, z, top, left)).then((text) {
      list.remove(pending);
      list.add(TileBlock.parse(text, top, left));
    }).catchError((Object _) {
      // unknown: try the tiles themselves
      list.remove(pending);
      list.add(TileBlock(top, left, 32, 32, List.filled(32 * 32, 1)));
      _failures++;
      _lastFailure = DateTime.now();
    }).whenComplete(notifyListeners);
    return null;
  }

  /// Whether tile (z, x, y) can be asked for: false when known to be
  /// missing, null while the ArcGIS tilemap is being consulted.
  bool? _available(BaseMap m, int z, int x, int y) {
    final key = _key(m, z, x, y);
    if (_missing.contains(key)) return false;
    if (_esriService(m) == null) return true;
    final has = _esriHas(m, z, x, y);
    if (has == false) _markMissing(key);
    return has;
  }

  /// Session token of the Google map type [m], created on first use (and
  /// again after it expires); null while the request is pending or after an
  /// error ([googleError]).
  String? _googleSession(BaseMap m, String key, String lang) {
    if (_sessionKey != key || _sessionLang != lang) {
      _resetGoogle();
      _sessionKey = key;
      _sessionLang = lang;
    }
    final s = _sessions[m];
    if (s != null && s.valid) return s.token;
    if (_googleError != null || _sessionPending.contains(m)) return null;
    _sessionPending.add(m);
    final body = jsonEncode(googleSessionRequest(m, lang));
    httpRequest('POST', '$googleTilesHost/v1/createSession?key=${Uri.encodeQueryComponent(key)}', headers: const {'Content-Type': 'application/json'}, body: body).then((text) {
      if (_sessionKey != key || _sessionLang != lang) return;
      final j = jsonDecode(text) as Map<String, dynamic>;
      final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiry = int.tryParse('${j['expiry']}') ?? (nowS + 3600);
      _sessions[m] = _GoogleSession('${j['session']}', DateTime.fromMillisecondsSinceEpoch(expiry * 1000).subtract(const Duration(minutes: 5)));
    }).catchError((Object e) {
      if (_sessionKey != key || _sessionLang != lang) return;
      _googleError = e is HttpStatusException ? e.message : '$e';
    }).whenComplete(() {
      _sessionPending.remove(m);
      notifyListeners();
    });
    return null;
  }

  void _resetGoogle() {
    _sessions.clear();
    _sessionPending.clear();
    _googleError = null;
    _googleCopyright = '';
    _googleMaxZoom = null;
    _viewportKey = '';
    _viewportTimer?.cancel();
    _evict((k) => k.startsWith('google'));
  }

  /// Highest zoom the Map Tiles API reports for the rectangles that touch
  /// the viewport (the lowest of them, so no tile is asked past the data).
  static int? maxZoomFromViewport(String text, double north, double south, double east, double west) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final rects = j['maxZoomRects'];
    if (rects is! List) return null;
    int? best;
    for (final r in rects) {
      if (r is! Map) continue;
      double d(String k, double def) => (r[k] as num?)?.toDouble() ?? def;
      final mz = (r['maxZoom'] as num?)?.toInt();
      if (mz == null) continue;
      final overlaps = d('south', -90) <= north && d('north', 90) >= south && d('west', -180) <= east && d('east', 180) >= west;
      if (overlaps && (best == null || mz < best)) best = mz;
    }
    return best;
  }

  /// Fetches the copyright and the maximum zoom the API reports for the
  /// visible area (debounced; Google asks for the copyright to be shown
  /// with the tiles).
  void _scheduleViewport(BaseMap m, String key, String session, int z, double north, double south, double east, double west) {
    final k = '${m.name}/$z/${north.toStringAsFixed(3)}/${south.toStringAsFixed(3)}/${east.toStringAsFixed(3)}/${west.toStringAsFixed(3)}';
    if (k == _viewportKey) return;
    _viewportKey = k;
    _viewportTimer?.cancel();
    _viewportTimer = Timer(const Duration(milliseconds: 600), () {
      final q = 'session=${Uri.encodeQueryComponent(session)}&key=${Uri.encodeQueryComponent(key)}&zoom=$z&north=$north&south=$south&east=$east&west=$west';
      httpRequest('GET', '$googleTilesHost/tile/v1/viewport?$q').then((text) {
        if (_viewportKey != k) return;
        final j = jsonDecode(text) as Map<String, dynamic>;
        final c = '${j['copyright'] ?? ''}';
        final mz = maxZoomFromViewport(text, north, south, east, west);
        if (c != _googleCopyright || mz != _googleMaxZoom) {
          _googleCopyright = c;
          _googleMaxZoom = mz;
          notifyListeners();
        }
      }).catchError((Object _) {});
    });
  }

  void _prepare(BaseMapOptions o) {
    if (_lastMap != o.map) {
      _lastMap = o.map;
      _failures = 0;
      if (o.map.isGoogle) _googleError = null;
    }
    if (_epoch != o.epoch) {
      _epoch = o.epoch;
      _resetGoogle();
      _evict((k) => k.startsWith('custom/'));
    }
    if (_customUrl != o.customUrl) {
      _customUrl = o.customUrl;
      _evict((k) => k.startsWith('custom/'));
    }
  }

  /// Draws the visible tiles. Returns the number of tiles drawn (ancestor
  /// tiles standing in for missing or loading ones included).
  int paint(ui.Canvas canvas, Camera cam, GeoReference g, BaseMapOptions o) {
    final m = o.map;
    if (m == BaseMap.none) return 0;
    _prepare(o);
    var session = '', apiKey = '';
    if (m.isGoogle) {
      apiKey = o.googleKey ?? '';
      if (apiKey.isEmpty) return 0;
      final s = _googleSession(m, apiKey, o.lang);
      if (s == null) return 0;
      session = s;
    } else if (m == BaseMap.custom && !isValidTemplate(o.customUrl)) {
      return 0;
    }
    final vis = cam.visible;
    final (latC, _) = g.toLatLon(vis.center.x, vis.center.y);
    final z = zoomFor(cam.metersPerPixel, latC, maxZoom: math.min(maxZoom(m), m.isGoogle ? (_googleMaxZoom ?? 99) : 99));
    // tile range covering the view (from the corners)
    final corners = [Pt(vis.minX, vis.minY), Pt(vis.maxX, vis.minY), Pt(vis.maxX, vis.maxY), Pt(vis.minX, vis.maxY)];
    var xMin = double.infinity, xMax = -double.infinity, yMin = double.infinity, yMax = -double.infinity;
    var latMin = double.infinity, latMax = -double.infinity, lonMin = double.infinity, lonMax = -double.infinity;
    for (final c in corners) {
      final (lat, lon) = g.toLatLon(c.x, c.y);
      final (tx, ty) = _tileXY(lat, lon, z);
      xMin = math.min(xMin, tx);
      xMax = math.max(xMax, tx);
      yMin = math.min(yMin, ty);
      yMax = math.max(yMax, ty);
      latMin = math.min(latMin, lat);
      latMax = math.max(latMax, lat);
      lonMin = math.min(lonMin, lon);
      lonMax = math.max(lonMax, lon);
    }
    final n = math.pow(2, z).toInt();
    final x0 = xMin.floor().clamp(0, n - 1), x1 = xMax.floor().clamp(0, n - 1);
    final y0 = yMin.floor().clamp(0, n - 1), y1 = yMax.floor().clamp(0, n - 1);
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 64) return 0; // too many tiles: zoom in first
    if (m.isGoogle) _scheduleViewport(m, apiKey, session, z, latMax, latMin, lonMax, lonMin);
    var drawn = 0;
    final paint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: o.opacity.clamp(0.05, 1.0))
      ..filterQuality = ui.FilterQuality.low;
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        final key = _key(m, z, x, y);
        var img = _tiles[key];
        ui.Rect? src;
        if (img == null) {
          // ask for the tile, or where the server has none for its nearest
          // ancestor that may exist (unknown yet: wait for the tilemap)
          var rz = z, rx = x, ry = y;
          bool? avail;
          while ((avail = _available(m, rz, rx, ry)) == false && rz > 1) {
            rz--;
            rx >>= 1;
            ry >>= 1;
          }
          if (avail == true && z - rz <= 8) _request(m, rz, rx, ry, session, apiKey, o.customUrl);
          // meanwhile draw the nearest ancestor already in the cache
          for (var k = 1; k <= 8 && z - k >= 1; k++) {
            final a = _tiles[_key(m, z - k, x >> k, y >> k)];
            if (a != null) {
              img = a;
              src = ancestorSource(x, y, k, a.width, a.height);
              break;
            }
          }
          if (img == null) continue;
        }
        // local coordinates of the tile corners: top-left, top-right, bottom-left
        Pt local(double tx, double ty) {
          final (lat, lon) = _latLonOf(tx, ty, z);
          final u = latLonToUtm(lat, lon, zone: g.zone);
          var northing = u.northing;
          if (g.north && lat < 0) northing -= 10000000;
          if (!g.north && lat >= 0) northing += 10000000;
          return Pt(u.easting - g.originEasting, northing - g.originNorthing);
        }

        final tl = cam.toScreen(local(x.toDouble(), y.toDouble()));
        final tr = cam.toScreen(local(x + 1.0, y.toDouble()));
        final bl = cam.toScreen(local(x.toDouble(), y + 1.0));
        final w = img.width.toDouble(), h = img.height.toDouble();
        // affine: image (0,0)→tl, (w,0)→tr, (0,h)→bl
        final a = (tr.dx - tl.dx) / w, b = (tr.dy - tl.dy) / w;
        final c2 = (bl.dx - tl.dx) / h, d = (bl.dy - tl.dy) / h;
        canvas.save();
        canvas.transform(Float64List.fromList([a, b, 0, 0, c2, d, 0, 0, 0, 0, 1, 0, tl.dx, tl.dy, 0, 1]));
        if (src == null) {
          canvas.drawImage(img, ui.Offset.zero, paint);
        } else {
          canvas.drawImageRect(img, src, ui.Rect.fromLTWH(0, 0, w, h), paint);
        }
        canvas.restore();
        drawn++;
      }
    }
    return drawn;
  }

  @override
  void dispose() {
    _viewportTimer?.cancel();
    for (final t in _tiles.values) {
      t.dispose();
    }
    _tiles.clear();
    super.dispose();
  }
}
