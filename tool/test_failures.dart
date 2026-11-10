/// The tests that failed in a run of `flutter test`, where they can be read
/// without opening the log.
///
///   flutter test --file-reporter json:build/test-report.json
///   dart run tool/test_failures.dart build/test-report.json [--summary file.md]
///
/// Reads the events the JSON reporter of the test runner wrote and prints,
/// for every test that did not pass, its file, its name, what it said and
/// the lines of the stack inside this repository. On GitHub Actions
/// (GITHUB_ACTIONS=true) each one is also an `::error` command, which the
/// page of the run and its API show as an annotation, and --summary appends
/// the list in Markdown to a file (CI gives $GITHUB_STEP_SUMMARY). The exit
/// code is always 0: the step that ran the tests has already failed the job.
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? summary;
  final files = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--summary' && i + 1 < args.length) {
      summary = args[++i];
    } else {
      files.add(args[i]);
    }
  }
  if (files.isEmpty) {
    stderr.writeln('usage: dart run tool/test_failures.dart <report.json>... [--summary file.md]');
    exit(2);
  }
  final report = TestReport();
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) {
      stdout.writeln('$f: no report (the tests did not start)');
      continue;
    }
    report.read(file.readAsLinesSync(), root: Directory.current.path);
  }
  stdout.writeln(report.describe());
  if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
    for (final line in report.annotations()) {
      stdout.writeln(line);
    }
  }
  if (summary != null && (report.failed.isNotEmpty || !report.complete)) {
    File(summary).writeAsStringSync(report.markdown(), mode: FileMode.append);
  }
}

/// A test that did not pass.
class FailedTest {
  FailedTest({required this.file, required this.name, required this.line, required this.result, required this.errors});

  /// The test file, relative to the repository when it is inside it.
  final String file;
  final String name;

  /// Line of the test in [file], or null when the runner did not say.
  final int? line;

  /// `failure` (an expectation), `error` (an exception or a time-out) or
  /// `unfinished` (the run ended while it was running).
  final String result;

  /// What the test said, each with the stack lines of this repository.
  final List<String> errors;

  String get message => errors.isEmpty ? 'no message' : errors.join('\n\n');
}

/// The failed tests of one or more JSON reports of the test runner.
class TestReport {
  final failed = <FailedTest>[];
  var passed = 0;

  /// False when a report ends without the runner's closing event: the run
  /// was cut short (a crash, the time limit of the job).
  var complete = true;

  /// GitHub shows at most 10 error annotations of a step.
  static const maxAnnotations = 10;

  /// Characters of a message kept in an annotation.
  static const maxMessage = 3600;

  void read(Iterable<String> lines, {required String root}) {
    final suites = <int, String>{};
    final tests = <int, Map<String, dynamic>>{};
    final errors = <int, List<String>>{};
    final caught = <int, List<String>>{};
    var done = false;
    String relative(String path) {
      final p = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      return p.startsWith('$root/') ? p.substring(root.length + 1) : p;
    }

    FailedTest failure(int id, String result) {
      final t = tests[id] ?? const <String, dynamic>{};
      final file = suites[t['suiteID']] ?? relative('${t['root_url'] ?? t['url'] ?? '?'}');
      // a widget test only says "see exception logs above": what it caught comes first
      return FailedTest(file: file, name: '${t['name'] ?? '?'}', line: (t['root_line'] ?? t['line']) as int?, result: result, errors: [...?caught[id], ...?errors[id]]);
    }

    for (final line in lines) {
      if (!line.startsWith('{')) continue;
      final Map<String, dynamic> e;
      try {
        e = jsonDecode(line) as Map<String, dynamic>;
      } on FormatException {
        continue; // a line cut by the end of the run
      }
      switch (e['type']) {
        case 'suite':
          final s = e['suite'] as Map<String, dynamic>;
          suites[s['id'] as int] = relative('${s['path']}');
        case 'testStart':
          final t = e['test'] as Map<String, dynamic>;
          tests[t['id'] as int] = t;
        case 'print':
          // the report of an exception the Flutter test framework caught
          final m = '${e['message']}';
          if (m.contains('╡ EXCEPTION CAUGHT BY ')) (caught[e['testID'] as int] ??= []).add(_caught(m, root));
        case 'error':
          (errors[e['testID'] as int] ??= []).add(_error('${e['error']}', '${e['stackTrace'] ?? ''}', root));
        case 'testDone':
          final id = e['testID'] as int;
          if (e['result'] == 'success') {
            if (e['hidden'] != true && e['skipped'] != true) passed++;
          } else {
            failed.add(failure(id, '${e['result']}'));
          }
          tests.remove(id);
        case 'done':
          done = true;
      }
    }
    if (!done) {
      complete = false;
      // what was running when the report stopped
      for (final id in tests.keys) {
        if ((tests[id]!['name'] as String? ?? '').startsWith('loading ') && errors[id] == null) continue;
        failed.add(failure(id, 'unfinished'));
      }
    }
  }

  /// The message of an error and the stack lines that are in this
  /// repository (the others are the test framework's).
  static String _error(String error, String stack, String root) {
    final own = [
      for (final l in stack.split('\n'))
        if (l.contains('package:opencadirrigation/') || l.contains('$root/') || RegExp(r'^(test|tool|bin|lib)/').hasMatch(l.trim())) l.trim().replaceAll('$root/', ''),
    ];
    return [error.trimRight(), ...own.take(8)].join('\n');
  }

  /// The report the Flutter test framework prints for an exception, without
  /// its rules and without the stack lines of the framework.
  static String _caught(String block, String root) {
    final out = <String>[];
    for (final raw in block.split('\n')) {
      final l = raw.replaceAll('file://$root/', '').replaceAll('$root/', '').trimRight();
      if (l.startsWith('══') || l == '<asynchronous suspension>' || l.startsWith('(elided ')) continue;
      if (RegExp(r'^#\d+ ').hasMatch(l) && !l.contains('package:opencadirrigation/') && !RegExp(r'\((test|tool|bin|lib)/').hasMatch(l)) continue;
      if (l.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
      out.add(l);
    }
    return out.join('\n').trimRight();
  }

  /// The list as plain text, for the log.
  String describe() {
    final b = StringBuffer();
    if (failed.isEmpty) {
      b.write(complete ? 'No test failed ($passed passed).' : 'No test failed in what the report holds, but the run ended before its last test.');
      return b.toString();
    }
    b.writeln('${failed.length} test${failed.length == 1 ? '' : 's'} did not pass ($passed passed)${complete ? '' : '; the run ended before its last test'}:');
    for (final f in failed) {
      b.writeln('\n${f.file}${f.line == null ? '' : ':${f.line}'}: ${f.name} (${f.result})');
      b.writeln(f.message.split('\n').map((l) => '  $l').join('\n'));
    }
    return b.toString().trimRight();
  }

  /// One `::error` workflow command per failed test; past the number GitHub
  /// shows, the last one names the rest.
  List<String> annotations() {
    final out = <String>[];
    final shown = failed.length > maxAnnotations ? maxAnnotations - 1 : failed.length;
    for (final f in failed.take(shown)) {
      final where = 'file=${_property(f.file)}${f.line == null ? '' : ',line=${f.line}'}';
      out.add('::error $where,title=${_property('${f.name} (${f.result})')}::${_data(shorten(f.message, maxMessage))}');
    }
    if (failed.length > shown) {
      final rest = [for (final f in failed.skip(shown)) '${f.file}: ${f.name} (${f.result})'];
      out.add('::error title=${_property('${rest.length} more tests did not pass')}::${_data(shorten(rest.join('\n'), maxMessage))}');
    }
    if (!complete) out.add('::warning title=${_property('The test report is incomplete')}::${_data('The run ended before its last test: a crash or the time limit of the job.')}');
    return out;
  }

  /// The list in Markdown, for the summary of the job.
  String markdown() {
    final b = StringBuffer('### Tests that did not pass\n\n');
    if (!complete) b.writeln('The run ended before its last test (a crash or the time limit of the job).\n');
    for (final f in failed) {
      b.writeln('<details><summary><code>${_html(f.file)}</code>: ${_html(f.name)} (${f.result})</summary>\n');
      b.writeln('<pre>${_html(shorten(f.message, 12000))}</pre>\n');
      b.writeln('</details>\n');
    }
    return b.toString();
  }

  /// [text] in at most [max] characters: the beginning and the end, which
  /// is where a failure says what it expected and where it was.
  static String shorten(String text, int max) {
    if (text.length <= max) return text;
    final head = (max * 0.7).floor(), tail = max - head - 40;
    return '${text.substring(0, head)}\n… (${text.length - head - tail} characters left out) …\n${text.substring(text.length - tail)}';
  }

  static String _data(String s) => s.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');
  static String _property(String s) => _data(s).replaceAll(':', '%3A').replaceAll(',', '%2C');
  static String _html(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
