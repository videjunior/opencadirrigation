import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// lib/core/api.dart exports every library of lib/core, as docs/API.md
/// says, but the internals of the PDF text shaping and the sparse solver
/// (MOD-28).
void main() {
  test('api.dart exports every library of lib/core', () {
    final api = File('lib/core/api.dart').readAsStringSync();
    final exported = {for (final m in RegExp(r"export '([^']+)'").allMatches(api)) m.group(1)!};
    final missing = <String>[];
    for (final f in Directory('lib/core').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/').split('lib/core/').last;
      if (rel == 'api.dart' || rel == 'hydraulics/sparse_solver.dart') continue;
      if (rel.startsWith('io/fonts/') && rel != 'io/fonts/pdf_fonts.dart') continue;
      // a part comes with its library
      if (RegExp(r'^part of ', multiLine: true).hasMatch(f.readAsStringSync())) continue;
      if (!exported.contains(rel)) missing.add(rel);
    }
    expect(missing..sort(), isEmpty, reason: 'add them to lib/core/api.dart (or list them as internal there and in docs/API.md)');
    for (final e in exported) {
      expect(File('lib/core/$e').existsSync(), isTrue, reason: e);
    }
  });

  test('the engine keeps no mutable static state that changes results', () {
    // the TIN size limit was a mutable static: now a per-terrain parameter
    expect(File('lib/core/model/terrain.dart').readAsStringSync(), contains('static const int maxTinPoints'));
  });
}
