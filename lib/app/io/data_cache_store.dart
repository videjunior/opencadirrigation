/// Where the app keeps the downloads of the online elevation models and of
/// the climate series ([DataCache], lib/core/io/data_cache.dart), by
/// platform (conditional import): the IndexedDB database
/// `opencadirrigation-cache` of this site in the browser, files in the
/// cache folder of the user on the desktop, nothing in the tests (a test
/// that wants a cache makes its own).
library;

import '../../core/io/data_cache.dart';
import 'data_cache_store_stub.dart' if (dart.library.js_interop) 'data_cache_store_web.dart' if (dart.library.io) 'data_cache_store_io.dart' as impl;
import 'prefs.dart';

export '../../core/io/data_cache.dart';

/// The store of this platform (one per page).
DataCacheStore platformDataCacheStore() => _store ??= impl.platformDataCacheStore();
DataCacheStore? _store;

/// The key of the setting "keep what is downloaded".
const dataCachePref = 'oci.dataCache';

/// The cache of the downloads of this page, on or off as the user left it.
DataCache appDataCache() => _cache ??= DataCache(platformDataCacheStore())..enabled = getPref(dataCachePref) != 'off';
DataCache? _cache;

/// Turns the keeping of downloads on or off (remembered).
void setDataCacheEnabled(bool on) {
  appDataCache().enabled = on;
  if (on) {
    removePref(dataCachePref);
  } else {
    setPref(dataCachePref, 'off');
  }
}

/// Replaces the cache of the page (tests).
set debugAppDataCache(DataCache? c) => _cache = c;
