import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/model/proposal_settings.dart';

/// The construction schedule of the quote: tasks from the quantities of
/// the drawing, in working days, following each other, shorter with more
/// crews, and the settings kept in the project.
void main() {
  test('tasks follow the works and more crews shorten them', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.orchard);
    final tasks = scheduleTasks(c.project, c.project.proposal);
    final keys = [for (final t in tasks) t.key];
    expect(keys.first, 'staking');
    expect(keys.last, 'testing');
    expect(keys, containsAll(['laterals', 'valves']));
    final byKey = {for (final t in tasks) t.key: t};
    final end = tasks.fold(0, (m, t) => t.end > m ? t.end : m);
    expect(byKey['testing']!.end, end, reason: 'the test closes the works');
    expect(byKey['laterals']!.start, greaterThanOrEqualTo(byKey['staking']!.end));
    for (final t in tasks) {
      expect(t.days, greaterThanOrEqualTo(1));
    }
    final two = scheduleTasks(c.project, ProposalSettings(crews: 2));
    expect(two.fold(0, (m, t) => t.end > m ? t.end : m), lessThanOrEqualTo(end));
    final table = c.reportTables().firstWhere((t) => t.key == 'works');
    expect(table.rows.length, tasks.length + 1);
    expect(table.rows.first.first, c.t('works.staking'));
  });

  test('the timeline: characters in the text reports, bars in the PDF (no glyph the PDF fonts lack)', () {
    final c = ProjectController()..setLanguage('pt');
    loadExampleAction(c, ExampleId.orchard);
    final table = c.reportTables().firstWhere((t) => t.key == 'works');
    final bars = [
      for (final r in table.rows)
        if (r.last is RBar) r.last as RBar,
    ];
    expect(bars, hasLength(table.rows.length - 1), reason: 'every task but the total');
    expect(const RBar(0, 3, 6).toString(), '█' * 15);
    expect(const RBar(2, 3, 6).toString(), '${'·' * 10}${'█' * 5}');
    expect(c.exporter().reportCsv(), contains('█'));
    final doc = PdfDocument();
    c.exporter().sheetBuilder().addReportPages(doc, [table]);
    final pdf = latin1.decode(doc.build(compress: false));
    final shown = [for (final m in RegExp(r'\(((?:[^()\\]|\\.)*)\) Tj').allMatches(pdf)) m.group(1)!];
    expect(shown, contains('Locação da obra'.replaceAll('ç', r'\347').replaceAll('ã', r'\343')));
    expect(shown.where((s) => s.contains('?')), isEmpty);
    // one bar per task, as long as its days on a common scale
    final drawn = [for (final m in RegExp(r'0\.12 0\.53 0\.9 rg\n([-\d.]+) [-\d.]+ ([-\d.]+) [-\d.]+ re f').allMatches(pdf)) (double.parse(m.group(1)!), double.parse(m.group(2)!))];
    expect(drawn, hasLength(bars.length));
    final perDay = drawn.first.$2 / (bars.first.end - bars.first.start);
    for (var i = 0; i < bars.length; i++) {
      // (the PDF keeps two decimals)
      expect(drawn[i].$2, closeTo(math.max(1.5, perDay * (bars[i].end - bars[i].start)), 0.06));
      expect(drawn[i].$1 - drawn.first.$1, closeTo(perDay * bars[i].start, 0.06));
    }
  });

  test('crews and productivities are kept in the project', () {
    final s = ProposalSettings(crews: 3, productivity: {'trench': 25});
    final back = ProposalSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.crews, 3);
    expect(back.productivity['trench'], 25);
    expect(ProposalSettings().isDefault, isTrue);
    expect(s.isDefault, isFalse);
  });
}
