/// Writes the public pages of the web site (web/index.html in English,
/// web/<code>/index.html for every other language, their manifests, the
/// privacy and terms pages, site.js, the redirect at web/en/index.html,
/// web/sitemap.xml, web/404.html, robots, llms.txt…) from tool/site.dart,
/// and the hosting configuration hosting/firebase.json.
/// Run: dart run tool/gen_site.dart [--check]
/// With --check nothing is written; exit code 1 when a file would change.
/// OCI_ANALYTICS_ID=G-… sets the measurement id of the visit statistics
/// (empty: no statistics and no consent notice).
library;

import 'dart:io';

import 'site.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  var changed = 0;
  final files = {for (final e in renderSite().entries) 'web/${e.key}': e.value, ...renderRepositoryFiles()};
  for (final e in files.entries) {
    final f = File(e.key);
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
