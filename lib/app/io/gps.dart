/// The device's position (browser geolocation): a stream of fixes while
/// watching; nothing on platforms without one.
library;

import 'gps_stub.dart' if (dart.library.js_interop) 'gps_web.dart' as impl;

/// One position of the device.
class GpsFix {
  const GpsFix({required this.lat, required this.lon, required this.accuracyM, this.altitudeM, this.altitudeAccuracyM, required this.time});
  final double lat, lon;

  /// Radius of the 95 % circle of the horizontal position (m).
  final double accuracyM;

  /// Height above the WGS84 ellipsoid (m) when the device reports it.
  final double? altitudeM, altitudeAccuracyM;
  final DateTime time;
}

/// Whether the platform can give positions.
bool get gpsSupported => impl.gpsSupported;

/// Starts watching the position: [onFix] for every new fix, [onError] with
/// `denied`, `unavailable` or `timeout`. Returns a function that stops it.
void Function() watchGps(void Function(GpsFix fix) onFix, void Function(String code) onError) => impl.watchGps(onFix, onError);
