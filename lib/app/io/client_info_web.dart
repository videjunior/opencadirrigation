import 'package:web/web.dart' as web;

String get clientUserAgent {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}
