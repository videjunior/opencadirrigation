/// Translation hook used by the pure-Dart layers (reports, plots) so they can
/// label their output without depending on the Flutter UI.
library;

typedef Translate = String Function(String key, [Map<String, String>? args]);
