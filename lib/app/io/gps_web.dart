import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'gps.dart';

bool get gpsSupported {
  try {
    return web.window.navigator.geolocation.isA<web.Geolocation>();
  } catch (_) {
    return false;
  }
}

void Function() watchGps(void Function(GpsFix fix) onFix, void Function(String code) onError) {
  final geo = web.window.navigator.geolocation;
  final id = geo.watchPosition(
    ((web.GeolocationPosition p) {
      final c = p.coords;
      onFix(GpsFix(lat: c.latitude, lon: c.longitude, accuracyM: c.accuracy, altitudeM: c.altitude?.toDouble(), altitudeAccuracyM: c.altitudeAccuracy?.toDouble(), time: DateTime.fromMillisecondsSinceEpoch(p.timestamp.toInt())));
    }).toJS,
    ((web.GeolocationPositionError e) {
      onError(switch (e.code) {
        1 => 'denied',
        3 => 'timeout',
        _ => 'unavailable',
      });
    }).toJS,
    web.PositionOptions(enableHighAccuracy: true, maximumAge: 2000, timeout: 30000),
  );
  return () => geo.clearWatch(id);
}
