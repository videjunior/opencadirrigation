{{flutter_js}}
{{flutter_build_config}}

// Started by the entry page (tool/site.dart) when the app is wanted. No
// service worker: Flutter's is deprecated and only unregisters itself, and
// waiting for it delayed every start.
_flutter.loader.load();
