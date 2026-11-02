import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_markdown.dart';

/// The Markdown of the assistant's answers: the blocks the models write
/// (headings, lists with nesting and numbers, tables with alignment, fenced
/// code, quotes, rules) and the inline styles, rendered selectable, with
/// wide tables scrolling sideways, also right to left.
void main() {
  group('blocks', () {
    test('headings, paragraphs (lines kept), rules and quotes', () {
      final b = parseAiMarkdown('## Result\nZone A is within its window.\nZone B is not.\n\n---\n> Check the valve.\n> Then design again.');
      expect(b, hasLength(4));
      expect((b[0] as MdHeading).level, 2);
      expect((b[0] as MdHeading).text, 'Result');
      expect((b[1] as MdParagraph).text, 'Zone A is within its window.\nZone B is not.');
      expect(b[2], isA<MdRule>());
      expect((b[3] as MdQuote).text, 'Check the valve.\nThen design again.');
    });

    test('lists: bullets and numbers, nesting by indentation, continuation lines', () {
      final b = parseAiMarkdown('1. Find the site\n2. Lay out heads\n   - rotors on the edge\n   - sprays in the beds\n     with matched precipitation\n3. Design\n\n* one\n* two');
      final items = b.cast<MdListItem>();
      expect([for (final i in items) i.marker], ['1.', '2.', '–', '–', '3.', '•', '•']);
      expect([for (final i in items) i.depth], [0, 0, 1, 1, 0, 0, 0]);
      expect(items[3].text, 'sprays in the beds\nwith matched precipitation');
      // a 4-space indent is still one level in, and **bold** lines are not bullets
      final c = parseAiMarkdown('- a\n    - b\n**Bold** line');
      expect([for (final x in c.whereType<MdListItem>()) x.depth], [0, 1]);
      expect(c.last, isA<MdParagraph>());
    });

    test('tables with alignment, ragged rows and escaped pipes', () {
      final b = parseAiMarkdown('| Zone | Flow (m³/h) | OK |\n|:--|--:|:-:|\n| A | 4.2 | yes |\n| B \\| C | 5.0 |\n\nAfter.');
      final t = b.first as MdTable;
      expect(t.header, ['Zone', 'Flow (m³/h)', 'OK']);
      expect(t.align, [TextAlign.start, TextAlign.end, TextAlign.center]);
      expect(t.rows, [
        ['A', '4.2', 'yes'],
        ['B | C', '5.0'],
      ]);
      expect((b.last as MdParagraph).text, 'After.');
    });

    test('fenced code keeps its text; an open fence (still streaming) shows what came so far', () {
      final b = parseAiMarkdown('```json\n{"a": 1}\n  "b"\n```\nDone.');
      expect((b.first as MdCode).code, '{"a": 1}\n  "b"');
      expect((b.last as MdParagraph).text, 'Done.');
      expect((parseAiMarkdown('```\nline 1\nline 2').single as MdCode).code, 'line 1\nline 2');
    });
  });

  test('plain text for the drawing: no marks, markers kept, tables tab-separated', () {
    final text = aiPlainText('## Summary\n**Zone A** uses *PC* drippers, see [the sheet](https://example.org).\n- one\n  - two\n\n| Zone | Flow |\n|---|---|\n| A | 4.2 |\n\n```\nrun_design\n```');
    expect(text, 'Summary\nZone A uses PC drippers, see the sheet.\n• one\n  – two\nZone\tFlow\nA\t4.2\nrun_design');
    expect(aiTextDirection('Zona A'), TextDirection.ltr);
    expect(aiTextDirection('  123 المنطقة'), TextDirection.rtl);
    expect(aiTextDirection('123 — 4.5'), isNull);
  });

  group('rendering', () {
    Future<void> pump(WidgetTester tester, String md, {TextDirection dir = TextDirection.ltr, double width = 360}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCadTheme(),
          home: Directionality(
            textDirection: dir,
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: SingleChildScrollView(child: AiMarkdown(md)),
              ),
            ),
          ),
        ),
      );
    }

    List<InlineSpan> spansOf(WidgetTester tester, String containing) {
      final text = tester.widget<Text>(find.textContaining(containing));
      return (text.textSpan! as TextSpan).children!;
    }

    testWidgets('inline styles, links and selectable text', (tester) async {
      await pump(tester, 'The **pump** gives *32 m* at `q_max`; see [the manual](https://opencadirrigation.com/llms-full.txt) or https://example.org/a.');
      expect(find.byType(SelectionArea), findsOneWidget);
      final spans = spansOf(tester, 'The ').cast<TextSpan>();
      TextSpan span(String t) => spans.firstWhere((s) => s.text == t);
      expect(span('pump').style!.fontWeight, FontWeight.bold);
      expect(span('32 m').style!.fontStyle, FontStyle.italic);
      expect(span('q_max').style!.fontFamily, 'monospace');
      expect(span('the manual').recognizer, isA<TapGestureRecognizer>());
      expect(span('https://example.org/a').recognizer, isA<TapGestureRecognizer>(), reason: 'the full stop stays out of the address');
      // snake_case and 2*3*4 are not emphasis
      await pump(tester, 'Set flow_rate_m3h to 2*3*4.');
      expect(spansOf(tester, 'Set').cast<TextSpan>().every((s) => s.style?.fontStyle != FontStyle.italic), isTrue);
    });

    testWidgets('a wide table scrolls sideways in a narrow panel, with its cells as text', (tester) async {
      await pump(
        tester,
        '| Zone | Flow | Pressure | Velocity | Uniformity | Status |\n|---|--:|--:|--:|--:|---|\n| Zone A | 4.2 m³/h | 21.0 m | 1.4 m/s | 93 % | within window |\n| Zone B | 5.1 m³/h | 19.5 m | 1.6 m/s | 88 % | needs a bigger submain |',
        width: 300,
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('needs a bigger submain'), findsOneWidget);
      expect(find.text('Zone B'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final scroll = find.ancestor(of: find.byType(Table), matching: find.byType(SingleChildScrollView)).first;
      expect(tester.widget<SingleChildScrollView>(scroll).scrollDirection, Axis.horizontal);
    });

    testWidgets('lists, code, quote and rule render; right to left too', (tester) async {
      const md = '### خطوات\n1. حدد الموقع\n   - رشاشات على الحافة\n2. صمم الشبكة\n\n```\nrun_design\n```\n> راجع الصمام\n\n---\nتم.';
      await pump(tester, md, dir: TextDirection.rtl);
      expect(tester.takeException(), isNull);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
      expect(find.text('run_design'), findsOneWidget);
      expect(find.textContaining('راجع الصمام'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      // the nested item starts further from the start edge, which is the right in RTL
      final outer = tester.getTopRight(find.text('1.'));
      final inner = tester.getTopRight(find.text('–'));
      expect(inner.dx, lessThan(outer.dx));
    });
  });
}
