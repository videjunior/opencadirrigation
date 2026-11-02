import 'dart:io' show Platform;

/// True under `flutter test`, which sets FLUTTER_TEST.
bool get underFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
