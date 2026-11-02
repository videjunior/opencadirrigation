import '../../core/io/data_cache.dart';

/// Neither the browser nor a file system: nothing is kept.
DataCacheStore platformDataCacheStore() => const NoDataCacheStore();
