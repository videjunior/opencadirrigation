import 'gps.dart';

bool get gpsSupported => false;

void Function() watchGps(void Function(GpsFix fix) onFix, void Function(String code) onError) {
  onError('unavailable');
  return () {};
}
