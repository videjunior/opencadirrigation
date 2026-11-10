/// The weather forecast of the site for the irrigation forecast (1.7.0 FCT): the GET of this platform (fetch in the
/// browser, HttpClient on the desktop), how the client identifies itself, and where the answers are kept (the memory
/// of the page in front of File → Saved downloaded data, kind `forecast`). Nothing is fetched unless the user (or the
/// assistant, with the user's approval) asks.
library;

import '../../core/io/forecast_online.dart';
import '../state/controller.dart';
import '../version.dart';
import 'data_cache_store.dart';
import 'forecast_http_stub.dart' if (dart.library.js_interop) 'forecast_http_web.dart' as impl;

export '../../core/io/forecast_online.dart';

/// The GET the forecast uses (tests swap it for canned answers).
ForecastGet forecastUrlLoader = impl.forecastGet;

/// The clock of the forecast (tests set it).
DateTime Function() forecastClock = DateTime.now;

/// Whether the requests come from a browser page: then no header is added (MET Norway answers no CORS preflight; the
/// page identifies itself by its Origin, and the browser's cache revalidates with `If-Modified-Since`).
bool forecastFromBrowser = impl.isBrowser;

/// The User-Agent of the desktop builds (MET Norway asks every client to identify itself with a contact).
String get forecastUserAgent => '$appName/$appVersion github.com/videjunior/opencadirrigation';

final MemoryForecastKeeper _memory = MemoryForecastKeeper();

/// Where this page keeps the answers.
ForecastKeeper appForecastKeeper() => DataCacheForecastKeeper(appDataCache(), memory: _memory);

/// Forgets the answers this page keeps in memory (tests).
void debugClearForecastMemory() => _memory.values.clear();

/// The forecast of [source] at the site of [c] (the centre of the drawing on its georeference); throws
/// [ForecastException] `fc_no_site` without a georeference. [refresh] asks the service again when it allows.
Future<ForecastSeries> fetchSiteForecast(ProjectController c, ForecastSource source, {bool refresh = false}) {
  final site = c.siteLatLon;
  if (site == null) throw const ForecastException('fc_no_site');
  return fetchForecast(
    source,
    latitudeDeg: site.$1,
    longitudeDeg: site.$2,
    get: forecastUrlLoader,
    keeper: appForecastKeeper(),
    clock: forecastClock,
    refresh: refresh,
    conditional: !forecastFromBrowser,
    userAgent: forecastFromBrowser ? null : forecastUserAgent,
  );
}

/// The answer kept for the site of [c] from [source] (memory or device), without asking the service; null when none
/// is kept (the dialog shows the last forecast when it opens).
Future<ForecastSeries?> keptSiteForecast(ProjectController c, ForecastSource source) async {
  final site = c.siteLatLon;
  if (site == null) return null;
  try {
    return await fetchForecast(
      source,
      latitudeDeg: site.$1,
      longitudeDeg: site.$2,
      get: (url, headers) async => throw const ForecastException('fc_kept_only'),
      keeper: appForecastKeeper(),
      clock: () => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  } on ForecastException {
    return null;
  }
}
