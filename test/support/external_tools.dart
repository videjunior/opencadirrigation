/// External programs some tests check the output with (LibreDWG's dwgread).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Whether [tool] is on the PATH. When it is not, the test is skipped with a
/// note, unless `OCI_REQUIRE_TOOLS` (comma-separated) names it: then the
/// test fails, so that a CI job meant to run the check cannot lose it in
/// silence (the formats job sets `OCI_REQUIRE_TOOLS=dwgread`). Call it first
/// and return when it gives false.
Future<bool> hasTool(String tool) async {
  final found = (await Process.run(Platform.isWindows ? 'where' : 'which', [tool])).exitCode == 0;
  if (found) return true;
  final required = (Platform.environment['OCI_REQUIRE_TOOLS'] ?? '').split(',').map((s) => s.trim()).contains(tool);
  if (required) fail('$tool is not installed, and OCI_REQUIRE_TOOLS requires it here');
  markTestSkipped('$tool not installed');
  return false;
}
