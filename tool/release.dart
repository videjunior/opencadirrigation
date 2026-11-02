/// The release checklist of opencadirrigation.com as commands, run from the
/// repository root. A release goes:
///
///   1. dart run tool/release.dart prepare --minor     (or --patch, --major)
///        refuses a dirty tree and another Flutter than the pinned one;
///        bumps the pubspec version and its build number, runs
///        tool/gen_version.dart (release date = today), moves siteLastMod in
///        tool/site.dart to the release date and runs tool/gen_site.dart,
///        warns when the About text (about.text, 20 languages) has not
///        changed since the last release, rebuilds the design worker, then
///        runs the analysis, the format check and the whole suite
///        (--skip-tests leaves the suite out). It changes files and commits
///        nothing: review them, update the About lines when it says so,
///        and commit on the versao-X.Y.Z branch ("Versão X.Y.Z+N: …").
///   2. dart run tool/release.dart build
///        on the clean, committed tree: tool/build_web.sh into build/web
///        (the commit baked into the version label), the source maps kept
///        outside the deploy (`~/Documents/irrigationcad_cloud/sourcemaps/<build>`,
///        to read the stack traces users send), then verify-build.
///   3. dart run tool/release.dart publish
///        shows what rsync would add, change and delete in the deploy folder
///        (~/Documents/irrigationcad_cloud/public), asks, copies, and prints
///        the deploy commands. It never deploys: the owner runs
///        `firebase hosting:channel:deploy preview` (a preview URL) and then
///        `firebase deploy --only hosting` in ~/Documents/irrigationcad_cloud.
///   4. dart run tool/release.dart live
///        once deployed: checks that https://opencadirrigation.com/version.json
///        is this build, then announces the pages to IndexNow
///        (tool/indexnow.dart). IndexNow only ever runs after the deploy.
///
///   dart run tool/release.dart verify-build [build/web] [--release]
///        the checks of a build folder alone (CI runs them on every build):
///        the service worker and offline.js filled in, version.json of this
///        version with a commit (with --release: the clean HEAD commit), the
///        worker the committed one, no source map left or pointed at.
///   dart run tool/release.dart status
///        the version, the toolchain, the tree and what the next step is.
///
/// --yes answers yes to the questions (for scripts); --to and --from change
/// the deploy folder and the build folder.
library;

import 'dart:convert';
import 'dart:io';

import 'site.dart' show siteUrl;

const deployRoot = '~/Documents/irrigationcad_cloud';

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'help' : args.first;
  final opts = Options(args.skip(1).toList());
  try {
    switch (command) {
      case 'status':
        await status();
      case 'prepare':
        await prepare(opts);
      case 'build':
        await build(opts);
      case 'verify-build':
        final problems = verifyBuild(opts.positional.isEmpty ? 'build/web' : opts.positional.first, release: opts.flag('--release'));
        report(problems);
      case 'publish':
        await publish(opts);
      case 'live':
        await live(opts);
      default:
        stdout.writeln('usage: dart run tool/release.dart status | prepare --major|--minor|--patch [--skip-tests] | build | verify-build [dir] [--release] | publish | live');
        stdout.writeln('(the steps are described at the top of tool/release.dart)');
        if (command != 'help') exitCode = 2;
    }
  } on ReleaseStop catch (e) {
    stderr.writeln('release: ${e.message}');
    exitCode = 1;
  }
}

/// A precondition that stops the release, with what to do.
class ReleaseStop implements Exception {
  ReleaseStop(this.message);
  final String message;
}

class Options {
  Options(this.args);
  final List<String> args;
  bool flag(String name) => args.contains(name);
  String? value(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  List<String> get positional => [
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && !(i > 0 && const {'--to', '--from', '--maps'}.contains(args[i - 1]))) args[i],
  ];
}

// ---------------------------------------------------------------- the steps

Future<void> status() async {
  final (version, build) = pubspecVersion();
  stdout.writeln('version      $version+$build (pubspec.yaml)');
  stdout.writeln('flutter      ${flutterVersion().$1} (pinned ${pinnedFlutter()})');
  stdout.writeln('branch       ${git(['rev-parse', '--abbrev-ref', 'HEAD'])} at ${git(['rev-parse', '--short', 'HEAD'])}');
  final dirty = dirtyFiles();
  stdout.writeln('tree         ${dirty.isEmpty ? 'clean' : '${dirty.length} changed file(s)'}');
  final last = lastRelease();
  stdout.writeln('last release ${last ?? 'none found'}');
  final out = File('build/web/version.json');
  if (out.existsSync()) stdout.writeln('build/web    ${out.readAsStringSync().trim()}');
}

Future<void> prepare(Options o) async {
  final part = o.flag('--major')
      ? 0
      : o.flag('--minor')
      ? 1
      : o.flag('--patch')
      ? 2
      : -1;
  if (part < 0) throw ReleaseStop('say which part goes up: --major, --minor (features) or --patch (fixes)');
  requireCleanTree();
  requirePinnedFlutter();
  final (version, build) = pubspecVersion();
  final v = version.split('.').map(int.parse).toList();
  v[part]++;
  for (var i = part + 1; i < 3; i++) {
    v[i] = 0;
  }
  final next = v.join('.'), nextBuild = build + 1;
  final branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != 'versao-$next') stdout.writeln('note: the release is usually committed on the branch versao-$next (this is $branch)');
  step('version $version+$build → $next+$nextBuild');
  final pubspec = File('pubspec.yaml');
  pubspec.writeAsStringSync(pubspec.readAsStringSync().replaceFirst(RegExp(r'^version:.*$', multiLine: true), 'version: $next+$nextBuild'));
  await run('dart', ['run', 'tool/gen_version.dart']);
  final date = RegExp(r"^const appReleaseDate = '([\d-]+)';", multiLine: true).firstMatch(File('lib/app/version.dart').readAsStringSync())!.group(1)!;
  step('siteLastMod → $date, site pages regenerated');
  final site = File('tool/site.dart');
  final text = site.readAsStringSync();
  final updated = text.replaceFirst(RegExp(r"^const siteLastMod = '[\d-]+';", multiLine: true), "const siteLastMod = '$date';");
  if (updated == text && !text.contains("const siteLastMod = '$date';")) throw ReleaseStop('tool/site.dart: no "const siteLastMod = \'YYYY-MM-DD\';" line');
  site.writeAsStringSync(updated);
  await run('dart', ['run', 'tool/gen_site.dart']);
  aboutReminder(o);
  step('design worker');
  await run('sh', ['tool/build_worker.sh']);
  step('analysis and format');
  await run('dart', ['analyze', '--fatal-infos', 'lib', 'test', 'tool', 'bin']);
  await run('dart', ['format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool', 'bin']);
  if (o.flag('--skip-tests')) {
    stdout.writeln('suite skipped (--skip-tests): run flutter test before committing');
  } else {
    step('the whole suite');
    await run('flutter', ['test']);
  }
  stdout
    ..writeln()
    ..writeln('Prepared $next+$nextBuild. Next:')
    ..writeln('  - review the changes (git status, git diff) and update the About lines if warned above;')
    ..writeln('  - commit on versao-$next: git commit -am "Versão $next+$nextBuild: …";')
    ..writeln('  - dart run tool/release.dart build');
}

Future<void> build(Options o) async {
  requireCleanTree();
  requirePinnedFlutter();
  final out = o.value('--from') ?? 'build/web';
  final maps = expandHome(o.value('--maps') ?? '$deployRoot/sourcemaps');
  step('production build into $out (source maps kept in $maps)');
  await run('sh', ['tool/build_web.sh'], environment: {'OCI_WEB_OUT': out, 'OCI_SOURCE_MAPS': maps});
  report(verifyBuild(out, release: true));
  stdout.writeln('Next: dart run tool/release.dart publish');
}

Future<void> publish(Options o) async {
  final from = o.value('--from') ?? 'build/web';
  final to = expandHome(o.value('--to') ?? '$deployRoot/public');
  report(verifyBuild(from, release: true));
  if (!Directory(to).existsSync()) throw ReleaseStop('$to does not exist (--to <deploy folder>)');
  step('what rsync would change in $to');
  final preview = await Process.run('rsync', ['-a', '--delete', '--dry-run', '--itemize-changes', '$from/', '$to/']);
  if (preview.exitCode != 0) throw ReleaseStop('rsync: ${preview.stderr}');
  final lines = const LineSplitter().convert(preview.stdout as String).where((l) => l.trim().isNotEmpty).toList();
  final deleted = lines.where((l) => l.startsWith('*deleting')).toList();
  final created = lines.where((l) => l.startsWith('>f+')).toList();
  final changed = lines.where((l) => l.startsWith('>f') && !l.startsWith('>f+')).toList();
  stdout.writeln('${created.length} new, ${changed.length} changed, ${deleted.length} deleted');
  for (final l in deleted.take(40)) {
    stdout.writeln('  delete ${l.substring(l.indexOf(' ') + 1).trim()}');
  }
  if (deleted.length > 40) stdout.writeln('  … and ${deleted.length - 40} more');
  if (lines.isEmpty) {
    stdout.writeln('the deploy folder already holds this build');
  } else {
    if (!confirm(o, 'Copy the build into $to?')) throw ReleaseStop('nothing copied');
    await run('rsync', ['-a', '--delete', '$from/', '$to/']);
  }
  final v = jsonDecode(File('$from/version.json').readAsStringSync()) as Map<String, dynamic>;
  stdout
    ..writeln()
    ..writeln('The deploy folder holds ${v['version']}+${v['build_number']} (git ${v['commit']}). Deploy it yourself:')
    ..writeln('  cd $deployRoot')
    ..writeln('  firebase hosting:channel:deploy preview --expires 7d     # a preview URL to try first')
    ..writeln('  firebase deploy --only hosting --non-interactive')
    ..writeln('then: dart run tool/release.dart live   (checks the live version, then IndexNow)');
}

Future<void> live(Options o) async {
  final from = o.value('--from') ?? 'build/web';
  final local = jsonDecode(File('$from/version.json').readAsStringSync()) as Map<String, dynamic>;
  final url = Uri.parse('${siteUrl}version.json');
  final client = HttpClient();
  Map<String, dynamic> remote;
  try {
    final res = await (await client.getUrl(url.replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'}))).close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw ReleaseStop('$url: HTTP ${res.statusCode}');
    remote = jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
  String id(Map<String, dynamic> j) => '${j['version']}+${j['build_number']} git ${j['commit'] ?? '?'}';
  stdout.writeln('live:  ${id(remote)}');
  stdout.writeln('build: ${id(local)}');
  if (id(remote) != id(local)) throw ReleaseStop('the site does not serve this build yet: deploy it, wait a minute and run live again (IndexNow waits for it)');
  step('IndexNow');
  await run('dart', ['run', 'tool/indexnow.dart']);
}

// ---------------------------------------------------------------- the checks

/// What is wrong with the build in [dir]; with [release], also a commit
/// that is not the clean HEAD.
List<String> verifyBuild(String dir, {bool release = false}) {
  final problems = <String>[];
  String? read(String path) {
    final f = File('$dir/$path');
    if (!f.existsSync()) {
      problems.add('$path is missing');
      return null;
    }
    return f.readAsStringSync();
  }

  final (version, build) = pubspecVersion();
  final vj = read('version.json');
  if (vj != null) {
    final v = jsonDecode(vj) as Map<String, dynamic>;
    if (v['version'] != version || '${v['build_number']}' != '$build') problems.add('version.json is ${v['version']}+${v['build_number']}, pubspec.yaml says $version+$build');
    final commit = '${v['commit'] ?? ''}';
    if (commit.isEmpty) problems.add('version.json has no commit (not built by tool/build_web.sh)');
    if (v['flutter_version'] != pinnedFlutter()) problems.add('built with Flutter ${v['flutter_version']}, the pin is ${pinnedFlutter()}');
    if (release) {
      final head = git(['rev-parse', '--short', 'HEAD']);
      if (commit.endsWith('-dirty')) problems.add('built from a tree with uncommitted changes ($commit)');
      if (commit.replaceAll('-dirty', '') != head) problems.add('built from $commit, HEAD is $head: build again');
    }
  }
  final sw = read('sw.js');
  if (sw != null) {
    if (sw.contains("'__OCI_BUILD__'")) problems.add('sw.js is the template (a plain flutter build web): it would unregister itself and drop every user\'s offline copy');
    if (!RegExp('const BUILD = "${RegExp.escape('$version+$build')}').hasMatch(sw)) problems.add('sw.js does not name the build $version+$build');
  }
  final offline = read('offline.js');
  if (offline != null && offline.contains('__OCI_SW_URL__')) problems.add('offline.js still has the service worker placeholder');
  for (final f in ['flutter_bootstrap.js', 'flutter.js', 'main.dart.js']) {
    final t = read(f);
    if (t != null && RegExp(r'^//# sourceMappingURL=', multiLine: true).hasMatch(t)) problems.add('$f points at a source map the site does not serve');
  }
  final index = read('index.html');
  // the entry page loads site.js (no inline script, the CSP), which starts flutter_bootstrap.js on demand
  final siteFile = File('$dir/site.js');
  final siteJs = siteFile.existsSync() ? siteFile.readAsStringSync() : null;
  final boots = index != null && (index.contains('flutter_bootstrap.js') || (index.contains('src="site.js') && (siteJs?.contains('flutter_bootstrap.js') ?? false)));
  if (index != null && !boots) problems.add('index.html does not load flutter_bootstrap.js (directly or through site.js)');
  if (!Directory('$dir/canvaskit').existsSync()) problems.add('canvaskit/ is missing (the app must not depend on the CDN)');
  final worker = File('$dir/design_worker.js');
  if (worker.existsSync()) {
    final a = worker.readAsBytesSync(), b = File('web/design_worker.js').readAsBytesSync();
    var same = a.length == b.length;
    for (var i = 0; same && i < a.length; i++) {
      same = a[i] == b[i];
    }
    if (!same) problems.add('design_worker.js is not web/design_worker.js');
  } else {
    problems.add('design_worker.js is missing');
  }
  final maps = Directory(dir).existsSync() ? Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.map')).toList() : <File>[];
  if (maps.isNotEmpty) problems.add('source maps in the deploy: ${maps.map((f) => f.path).take(3).join(', ')}');
  return problems;
}

void report(List<String> problems) {
  if (problems.isEmpty) {
    stdout.writeln('build ok');
    return;
  }
  throw ReleaseStop('the build is not fit to publish:\n  - ${problems.join('\n  - ')}');
}

/// Warns about the languages whose About text (about.text) is still the one
/// of the last release commit: the About box (20 languages) lists what each
/// release brings. Formatting changes of lib/app/i18n.dart do not count.
void aboutReminder(Options o) {
  final last = lastRelease();
  if (last == null) return;
  final before = aboutTexts(last.split(' ').first), now = aboutTexts();
  final same = [
    for (final e in now.entries)
      if (before[e.key] == e.value) e.key,
  ]..sort();
  if (same.isEmpty) {
    stdout.writeln('About: about.text changed in every language since $last');
    return;
  }
  stdout
    ..writeln()
    ..writeln('!! about.text is the one of the last release ($last) in ${same.length} of ${now.length}: ${same.join(', ')}')
    ..writeln('   Add the lines of this release to the About text in every language')
    ..writeln('   (lib/app/i18n.dart for pt/en/es, assets/i18n/<code>.json; keys about.text and about.credits).')
    ..writeln();
  if (!confirm(o, 'Go on without it for now?')) throw ReleaseStop('stopped to update the About text; run prepare again after committing it');
}

/// about.text by language at the commit [rev] (the working tree when null):
/// pt/en/es from lib/app/i18n.dart (whitespace collapsed), the others from
/// the packs of assets/i18n.
Map<String, String> aboutTexts([String? rev]) {
  String? read(String path) {
    if (rev == null) {
      final f = File(path);
      return f.existsSync() ? f.readAsStringSync() : null;
    }
    final r = Process.runSync('git', ['show', '$rev:$path']);
    return r.exitCode == 0 ? r.stdout as String : null;
  }

  final out = <String, String>{};
  final table = read('lib/app/i18n.dart');
  final m = table == null ? null : RegExp(r"'about\.text':\s*\((.*?)\),\s*\n\s*'", dotAll: true).firstMatch(table);
  if (m != null) out['pt/en/es'] = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r',$'), '');
  final dir = Directory('assets/i18n');
  final packs = dir.existsSync() ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList() : <File>[];
  for (final f in packs) {
    final code = f.uri.pathSegments.last.replaceAll('.json', '');
    final text = read('assets/i18n/$code.json');
    if (text == null) continue;
    try {
      final strings = (jsonDecode(text) as Map<String, dynamic>)['strings'];
      final s = strings is Map ? strings['about.text'] : null;
      if (s is String) out[code] = s;
    } on FormatException {
      // a pack that does not parse at that commit: nothing to compare
    }
  }
  return out;
}

// ---------------------------------------------------------------- helpers

void step(String what) => stdout.writeln('\n== $what');

(String, int) pubspecVersion() {
  final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
  if (m == null) throw ReleaseStop('pubspec.yaml: no "version: x.y.z+n" line (run from the repository root)');
  return (m.group(1)!, int.parse(m.group(2)!));
}

String pinnedFlutter() {
  final m = RegExp(r'''^  flutter:\s*["']?(\d+\.\d+\.\d+)["']?\s*$''', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
  if (m == null) throw ReleaseStop('pubspec.yaml: no exact environment.flutter pin');
  return m.group(1)!;
}

/// (Flutter, Dart) of the `flutter` on the PATH.
(String, String) flutterVersion() {
  final r = Process.runSync('flutter', ['--version', '--machine'], runInShell: Platform.isWindows);
  if (r.exitCode != 0) throw ReleaseStop('flutter --version failed: ${r.stderr}');
  final text = r.stdout as String;
  final j = jsonDecode(text.substring(text.indexOf('{'))) as Map<String, dynamic>;
  return ('${j['frameworkVersion']}', '${j['dartSdkVersion']}');
}

void requirePinnedFlutter() {
  final (flutter, dart) = flutterVersion();
  final pinned = pinnedFlutter();
  if (flutter != pinned) throw ReleaseStop('this is Flutter $flutter (Dart $dart); the project is pinned to Flutter $pinned (pubspec.yaml)');
}

String git(List<String> args) {
  final r = Process.runSync('git', args);
  if (r.exitCode != 0) throw ReleaseStop('git ${args.join(' ')}: ${r.stderr}');
  return (r.stdout as String).trim();
}

List<String> dirtyFiles() {
  final r = Process.runSync('git', ['status', '--porcelain', '--untracked-files=no']);
  if (r.exitCode != 0) throw ReleaseStop('git status: ${r.stderr}');
  return const LineSplitter().convert(r.stdout as String).where((l) => l.trim().isNotEmpty).toList();
}

void requireCleanTree() {
  final dirty = dirtyFiles();
  if (dirty.isNotEmpty) throw ReleaseStop('uncommitted changes (commit or set them aside first):\n  ${dirty.take(20).join('\n  ')}');
}

/// The last release commit ("Versão x.y.z…"), as "hash subject", or null.
String? lastRelease() {
  final s = git(['log', '-1', '--format=%h %s', '--grep=^Versão ']);
  return s.isEmpty ? null : s;
}

String expandHome(String path) => path.startsWith('~/') ? '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? ''}${path.substring(1)}' : path;

bool confirm(Options o, String question) {
  if (o.flag('--yes')) return true;
  if (!stdin.hasTerminal) return false;
  stdout.write('$question [y/N] ');
  final answer = (stdin.readLineSync() ?? '').trim().toLowerCase();
  return answer == 'y' || answer == 'yes' || answer == 's' || answer == 'sim';
}

Future<void> run(String exe, List<String> args, {Map<String, String>? environment}) async {
  stdout.writeln('\$ $exe ${args.join(' ')}');
  final p = await Process.start(exe, args, mode: ProcessStartMode.inheritStdio, environment: environment, runInShell: Platform.isWindows);
  final code = await p.exitCode;
  if (code != 0) throw ReleaseStop('$exe ${args.join(' ')} failed (exit code $code)');
}
