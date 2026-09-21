/// Writes the public pages of the web site (web/index.html in English,
/// web/<code>/index.html for every other language, the redirect at
/// web/en/index.html, web/sitemap.xml, web/404.html) from tool/site.dart.
/// Run: dart run tool/gen_site.dart [--check]
/// With --check nothing is written; exit code 1 when a file would change.
library;

import 'dart:io';

import 'site.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  var changed = 0;
  for (final e in renderSite().entries) {
    final f = File('web/${e.key}');
    final current = f.existsSync() ? f.readAsStringSync() : null;
    if (current == e.value) {
      stdout.writeln('${f.path}: up to date');
      continue;
    }
    changed++;
    if (check) {
      stderr.writeln('${f.path}: out of date (run dart run tool/gen_site.dart)');
    } else {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(e.value);
      stdout.writeln('${f.path}: written (${(e.value.length / 1024).toStringAsFixed(1)} kB)');
    }
  }
  if (check && changed > 0) exit(1);
}
