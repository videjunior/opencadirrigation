import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/test_failures.dart' hide main;

/// tool/test_failures.dart: the failed tests of a JSON report of the test
/// runner, as text, as GitHub annotations and as Markdown. The events here
/// have the shape `flutter test --file-reporter json:…` writes.
void main() {
  const root = '/work/repo';
  var time = 0;
  String event(String type, Map<String, dynamic> fields) => jsonEncode({...fields, 'type': type, 'time': time++});
  String suite(int id, String path) => event('suite', {
    'suite': {'id': id, 'platform': 'vm', 'path': '$root/$path'},
  });
  String start(int id, String name, {int suiteId = 0, int? line, String? url, int? rootLine, String? rootUrl}) => event('testStart', {
    'test': {'id': id, 'name': name, 'suiteID': suiteId, 'groupIDs': <int>[], 'line': line, 'column': 3, 'url': url, 'root_line': ?rootLine, 'root_url': ?rootUrl},
  });
  String done(int id, String result, {bool hidden = false, bool skipped = false}) => event('testDone', {'testID': id, 'result': result, 'skipped': skipped, 'hidden': hidden});
  String error(int id, String message, String stack, {bool failure = true}) => event('error', {'testID': id, 'error': message, 'stackTrace': stack, 'isFailure': failure});
  String printed(int id, String message) => event('print', {'testID': id, 'messageType': 'print', 'message': message});

  /// A run with a test that passes, one skipped, one whose expectation
  /// fails, one that throws and a widget test (what it caught is printed).
  List<String> run() => [
    event('start', {'protocolVersion': '0.1.1', 'pid': 1}),
    suite(0, 'test/a_test.dart'),
    start(1, 'loading $root/test/a_test.dart'),
    done(1, 'success', hidden: true),
    start(3, 'passes', line: 4, url: 'file://$root/test/a_test.dart'),
    printed(3, 'pivot: 0 zones, 1 flows'),
    done(3, 'success'),
    start(5, 'a group fails, with: a colon, a comma and 100 %', line: 6, url: 'file://$root/test/a_test.dart'),
    error(
      5,
      "Expected: 'c'\n  Actual: 'b'\nthe reason\n",
      'package:matcher                 expect\npackage:flutter_test/src/widget_tester.dart 473:18  expect\ntest/a_test.dart 6:59           main.<fn>.<fn>\n',
    ),
    done(5, 'failure'),
    start(6, 'throws', line: 7, url: 'file://$root/test/a_test.dart'),
    error(6, 'Bad state: boom', 'package:opencadirrigation/core/units.dart 12:3  fmt\ntest/a_test.dart 7:26  main.<fn>\ndart:async  _rootRun\n', failure: false),
    done(6, 'error'),
    start(7, 'skipped', line: 8, url: 'file://$root/test/a_test.dart'),
    done(7, 'success', skipped: true),
    suite(1, 'test/goldens/b_test.dart'),
    start(8, 'a widget test', suiteId: 1, line: 174, url: 'package:flutter_test/src/widget_tester.dart', rootLine: 10, rootUrl: 'file://$root/test/goldens/b_test.dart'),
    printed(
      8,
      '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════\n'
      'The following assertion was thrown running a test:\n'
      'Golden "images/x.png": Pixel test failed, 1.25%, 50px diff detected.\n'
      'Failure feedback can be found at $root/test/goldens/failures\n'
      '50 of 4000 pixels (1.25 %) have a channel off by more than 24 levels\n'
      '\n'
      'When the exception was thrown, this was the stack:\n'
      '#0      TolerantGoldenComparator.compare (file://$root/test/goldens/b_test.dart:275:5)\n'
      '<asynchronous suspension>\n'
      '#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:29)\n'
      '<asynchronous suspension>\n'
      '(elided one frame from package:stack_trace)\n'
      '\n'
      'The test description was:\n'
      '  a widget test\n'
      '════════════════════════════════════════════════════════',
    ),
    error(8, 'Test failed. See exception logs above.\nThe test description was: a widget test', '', failure: false),
    done(8, 'error'),
    start(9, '(tearDownAll)', suiteId: 1),
    done(9, 'success', hidden: true),
    event('done', {'success': false}),
  ];

  test('the failed tests of a report, with what they said and where', () {
    final r = TestReport()..read(run(), root: root);
    expect(r.complete, isTrue);
    expect(r.passed, 1);
    expect(
      [for (final f in r.failed) '${f.file}:${f.line} ${f.name} (${f.result})'],
      ['test/a_test.dart:6 a group fails, with: a colon, a comma and 100 % (failure)', 'test/a_test.dart:7 throws (error)', 'test/goldens/b_test.dart:10 a widget test (error)'],
    );
    // the message, then the stack lines of this repository only
    expect(r.failed[0].message, "Expected: 'c'\n  Actual: 'b'\nthe reason\ntest/a_test.dart 6:59           main.<fn>.<fn>");
    expect(r.failed[1].message, 'Bad state: boom\npackage:opencadirrigation/core/units.dart 12:3  fmt\ntest/a_test.dart 7:26  main.<fn>');
    // a widget test: what the framework caught, without its rules and its own frames, then its one line
    expect(
      r.failed[2].message,
      'The following assertion was thrown running a test:\n'
      'Golden "images/x.png": Pixel test failed, 1.25%, 50px diff detected.\n'
      'Failure feedback can be found at test/goldens/failures\n'
      '50 of 4000 pixels (1.25 %) have a channel off by more than 24 levels\n'
      '\n'
      'When the exception was thrown, this was the stack:\n'
      '#0      TolerantGoldenComparator.compare (test/goldens/b_test.dart:275:5)\n'
      '\n'
      'The test description was:\n'
      '  a widget test\n'
      '\n'
      'Test failed. See exception logs above.\n'
      'The test description was: a widget test',
    );
    final text = r.describe();
    expect(text, startsWith('3 tests did not pass (1 passed):'));
    expect(text, contains('\ntest/a_test.dart:7: throws (error)\n  Bad state: boom\n'));
    expect(text, isNot(contains('pivot: 0 zones')));
  });

  test('one annotation per failed test, in the escapes GitHub reads', () {
    final r = TestReport()..read(run(), root: root);
    final a = r.annotations();
    expect(a, hasLength(3));
    expect(
      a[0],
      "::error file=test/a_test.dart,line=6,title=a group fails%2C with%3A a colon%2C a comma and 100 %25 (failure)::Expected: 'c'%0A  Actual: 'b'%0Athe reason%0Atest/a_test.dart 6:59           main.<fn>.<fn>",
    );
    expect(
      a[2],
      startsWith(
        '::error file=test/goldens/b_test.dart,line=10,title=a widget test (error)::The following assertion was thrown running a test:%0AGolden "images/x.png": Pixel test failed, 1.25%25, 50px diff detected.%0A',
      ),
    );
    expect(a.every((l) => !l.contains('\n')), isTrue);
  });

  test('past ten failures the last annotation names the rest, and a long message keeps both ends', () {
    time = 0;
    final lines = [suite(0, 'test/many_test.dart')];
    for (var i = 1; i <= 14; i++) {
      lines
        ..add(start(i, 'test $i', line: i))
        ..add(error(i, i == 1 ? 'begin ${'x' * 9000} end' : 'no $i', ''))
        ..add(done(i, 'failure'));
    }
    lines.add(event('done', {'success': false}));
    final r = TestReport()..read(lines, root: root);
    expect(r.failed, hasLength(14));
    final a = r.annotations();
    expect(a, hasLength(TestReport.maxAnnotations));
    expect(a[8], '::error file=test/many_test.dart,line=9,title=test 9 (failure)::no 9');
    expect(a.last, '::error title=5 more tests did not pass::${[for (var i = 10; i <= 14; i++) 'test/many_test.dart: test $i (failure)'].join('%0A')}');
    final long = a.first.split('::').last;
    expect(long.length, lessThan(TestReport.maxMessage + 60));
    expect(long, startsWith('begin xxx'));
    expect(long, endsWith('xxx end'));
    expect(long, contains('characters left out'));
    expect(TestReport.shorten('short', 10), 'short');
  });

  test('a report cut short says so and names what was running', () {
    time = 0;
    final lines = [
      suite(0, 'test/a_test.dart'),
      start(1, 'loading $root/test/a_test.dart'),
      done(1, 'success', hidden: true),
      start(2, 'passes', line: 4),
      done(2, 'success'),
      start(3, 'never ends', line: 9),
      start(4, 'loading $root/test/c_test.dart'),
      '{"testID":3,"error":"cut in the mid', // the last line, not whole
    ];
    final r = TestReport()..read(lines, root: root);
    expect(r.complete, isFalse);
    expect([for (final f in r.failed) '${f.file}:${f.line} ${f.name} (${f.result})'], ['test/a_test.dart:9 never ends (unfinished)']);
    expect(r.describe(), startsWith('1 test did not pass (1 passed); the run ended before its last test:'));
    expect(r.annotations().last, startsWith('::warning title=The test report is incomplete::'));
    expect(r.markdown(), contains('The run ended before its last test'));
    // nothing failed and nothing was running: still not a clean run
    final empty = TestReport()..read([suite(0, 'test/a_test.dart')], root: root);
    expect(empty.describe(), 'No test failed in what the report holds, but the run ended before its last test.');
  });

  test('a clean report and the Markdown of a failed one', () {
    time = 0;
    final clean = TestReport()
      ..read([
        suite(0, 'test/a_test.dart'),
        start(1, 'passes'),
        done(1, 'success'),
        event('done', {'success': true}),
      ], root: root);
    expect(clean.failed, isEmpty);
    expect(clean.describe(), 'No test failed (1 passed).');
    expect(clean.annotations(), isEmpty);
    final md = (TestReport()..read(run(), root: root)).markdown();
    expect(md, startsWith('### Tests that did not pass\n\n<details><summary><code>test/a_test.dart</code>: a group fails, with: a colon, a comma and 100 % (failure)</summary>'));
    expect(md, contains('main.&lt;fn&gt;.&lt;fn&gt;</pre>'));
    expect('<details>'.allMatches(md), hasLength(3));
  });
}
