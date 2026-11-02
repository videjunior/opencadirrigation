/// The Flutter release the project is pinned to (`environment: flutter:` in
/// pubspec.yaml) and the SDK the tests run on, for the guards whose output
/// depends on the exact toolchain (the compiled worker, the formatter).
library;

import 'dart:convert';
import 'dart:io';

/// The exact Flutter version pubspec.yaml pins (`environment: flutter: x.y.z`).
String pinnedFlutterVersion([String? pubspec]) {
  final text = pubspec ?? File('pubspec.yaml').readAsStringSync();
  final env = RegExp(r'^environment:\s*\n((?:[ \t]+.*\n?|\s*\n)*)', multiLine: true).firstMatch(text);
  final m = env == null ? null : RegExp(r'''^[ \t]+flutter:\s*["']?(\d+\.\d+\.\d+)["']?\s*$''', multiLine: true).firstMatch(env.group(1)!);
  if (m == null) throw StateError('pubspec.yaml: no exact "environment: flutter: x.y.z" pin');
  return m.group(1)!;
}

/// The Flutter SDK running the tests: `FLUTTER_ROOT` (set by `flutter test`)
/// and its bin/cache/flutter.version.json.
class FlutterSdk {
  FlutterSdk(this.root, this.flutterVersion, this.dartVersion);
  final String root;
  final String flutterVersion;
  final String dartVersion;

  /// The `dart` executable bundled with this Flutter SDK.
  String get dart => '$root/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}';

  /// The SDK of this test run, or null when it cannot be told.
  static FlutterSdk? current() {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null || root.isEmpty) return null;
    final f = File('$root/bin/cache/flutter.version.json');
    if (!f.existsSync()) return null;
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final flutter = (j['frameworkVersion'] ?? j['flutterVersion']) as String?;
      final dart = j['dartSdkVersion'] as String?;
      if (flutter == null || dart == null) return null;
      return FlutterSdk(root, flutter, dart);
    } on FormatException {
      return null;
    }
  }
}

/// Why a toolchain-exact guard cannot run here (another Flutter than the
/// pinned one, or an SDK it cannot find), or null when it can.
String? toolchainMismatch() {
  final pinned = pinnedFlutterVersion();
  final sdk = FlutterSdk.current();
  if (sdk == null) return 'skipped: FLUTTER_ROOT/bin/cache/flutter.version.json not found (run through `flutter test`)';
  if (sdk.flutterVersion != pinned) {
    return 'skipped: this is Flutter ${sdk.flutterVersion}, the project is pinned to Flutter $pinned '
        '(pubspec.yaml environment.flutter); the output depends on the exact SDK';
  }
  if (!File(sdk.dart).existsSync()) return 'skipped: ${sdk.dart} not found';
  return null;
}
