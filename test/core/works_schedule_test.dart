import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
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

  test('crews and productivities are kept in the project', () {
    final s = ProposalSettings(crews: 3, productivity: {'trench': 25});
    final back = ProposalSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.crews, 3);
    expect(back.productivity['trench'], 25);
    expect(ProposalSettings().isDefault, isTrue);
    expect(s.isDefault, isFalse);
  });
}
