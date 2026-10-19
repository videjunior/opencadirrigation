import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';

/// Runs around every test file: a file fails when the interface asked for a
/// string key the table does not have, which the user would see as the key
/// itself (as `welcome.open` once showed on every card of the welcome dialog).
/// A test that wants an unknown key on purpose clears [missingKeys].
final missingKeys = <String>{};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  onMissingI18nKey = missingKeys.add;
  tearDownAll(() {
    expect(missingKeys, isEmpty, reason: 'keys used by the app but missing from lib/app/i18n.dart');
  });
  await testMain();
}
