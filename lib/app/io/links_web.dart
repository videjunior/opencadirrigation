import 'package:web/web.dart' as web;

void openExternalLink(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

void clearAddressFragment() {
  try {
    final l = web.window.location;
    web.window.history.replaceState(null, '', '${l.pathname}${l.search}');
  } catch (_) {}
}
