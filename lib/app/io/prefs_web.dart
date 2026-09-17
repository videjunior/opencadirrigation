import 'package:web/web.dart' as web;

String? getPref(String key) {
  try {
    return web.window.localStorage.getItem('opencadirrigation.$key');
  } catch (_) {
    return null;
  }
}

void setPref(String key, String value) {
  try {
    web.window.localStorage.setItem('opencadirrigation.$key', value);
  } catch (_) {}
}

void removePref(String key) {
  try {
    web.window.localStorage.removeItem('opencadirrigation.$key');
  } catch (_) {}
}
