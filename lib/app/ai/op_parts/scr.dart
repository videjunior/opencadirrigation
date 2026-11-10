/// Operations (find_operations / run_operation) added in 1.7.0 for the
/// design scorecard (lib/core/design/scorecard.dart): [OpTool]s built like
/// those of lib/app/ai/ops_cad_*.dart, joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/scorecard.dart';
import '../../widgets/dialogs/scorecard_dialog.dart' show projectScorecard, runScorecardAgeing, scorecardComparisons, scorecardToCompare;
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../ops_eng_common.dart' show engN, engNeedResults, engNotBusy, engTable;

/// The scorecard of the previous call, by project, so the next one says
/// what a change did to it.
final Map<String, (DesignScorecard, DateTime)> _previous = {};

/// Forgets the previous calls (tests).
void forgetScorecardCalls() => _previous.clear();

/// The operations or tools that improve each indicator (the dialog's
/// buttons, `ScoreIndicator.tool`).
const _aiTools = <String, String>{
  'params': 'set_parameters',
  'autofix': 'preview_auto_fix, then auto_fix',
  'pumpSelect': 'rank_pumps, then apply_pump',
  'densogram': 'densogram',
  'programme': 'irrigation_programme',
  'management': 'set_system_flows',
  'lcc': 'life_cycle_cost',
  'life': 'design_scorecard with run_ageing true',
  'messages': 'get_design_messages, then apply_fix',
  'airValves': 'suggest_air_valves, then insert_air_valves',
  'catalog': 'edit_catalog',
};

String _n(double? v, [int d = 1]) => v == null ? '-' : engN(v, d);

String _delta(double? now, double? before) {
  if (now == null || before == null) return '';
  final d = now - before;
  return '${_n(before)} → ${_n(now)} (${d >= 0 ? '+' : ''}${engN(d, 1)})';
}

/// The scorecard as text for the model: the score, what changed since
/// [before], the categories, every indicator, what to improve first, what
/// is not assessed and the scoring functions.
String scorecardAiText(AgentToolbox b, DesignScorecard s, {DesignScorecard? before, String beforeName = ''}) {
  final t = b.t;
  final u = b.u;
  final cur = b.p.params.currency;
  final out = StringBuffer(
    'Design scorecard: overall ${_n(s.overall)}/100, grade ${s.grade ?? '-'} (${s.assessed.length} of ${s.categories.length} categories assessed). '
    'Each category is the weighted mean of its assessed indicators and the overall score the weighted mean of the assessed categories (every weight 1); grades A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, E below. '
    'An indicator without data is not assessed and left out of the averages; one without a reference value is reported only.',
  );
  if (before != null) {
    final parts = [
      'overall ${_delta(s.overall, before.overall)}',
      for (final c in s.categories)
        if (c.score != null && before.categoryOf(c.category).score != null && (c.score! - before.categoryOf(c.category).score!).abs() > 0.05)
          '${c.category.name} ${_delta(c.score, before.categoryOf(c.category).score)}',
    ];
    out.write('\nCompared with $beforeName: ${parts.join('; ')}.');
  }
  out.write('\n\n');
  out.write(
    engTable(
      const ['category', 'name', 'score', 'grade', 'weight'],
      [
        for (final c in s.categories) [c.category.name, t('scr.c.${c.category.name}'), _n(c.score), c.grade ?? 'not assessed', engN(c.weight, 0)],
      ],
    ),
  );
  out.write('\n\n');
  out.write(
    engTable(
      const ['indicator', 'name', 'value', 'target', 'source', 'score', 'grade', 'points to gain', 'weakest point'],
      [
        for (final i in s.indicators)
          [
            '${i.category.name}/${i.key}',
            t('scr.i.${i.key}'),
            i.assessed ? scoreValueText(i, u, currency: cur) : 'not assessed (${i.gap})',
            i.target.isEmpty ? 'reported only' : i.target,
            [for (final x in i.sources) scoreSourceText(x, t.call)].join('; '),
            i.score == null ? '-' : engN(i.score!, 0),
            i.score == null ? '-' : scoreGrade(i.score!),
            i.score == null ? '-' : engN(s.gainOf(i), 1),
            i.detail.isEmpty ? '-' : i.detail,
          ],
      ],
    ),
  );
  final imp = s.improvements;
  out.write('\n\nImprove first (points the overall score gains if the indicator reaches 100):');
  if (imp.isEmpty) out.write(' nothing, every assessed indicator is at 100.');
  for (var k = 0; k < imp.length && k < 10; k++) {
    final (i, g) = imp[k];
    final how = _aiTools[i.tool];
    out.write(
      '\n${k + 1}. +${engN(g, 1)} ${i.category.name}/${i.key} "${t('scr.i.${i.key}')}" ${scoreValueText(i, u, currency: cur)} (target ${i.target})${i.detail.isEmpty ? '' : ', weakest: ${i.detail}${i.entityId == null ? '' : ' [${i.entityId}]'}'}: ${t('scr.h.${i.key}')}${how == null ? '' : ' Operation: $how.'}',
    );
  }
  final gaps = [
    for (final i in s.indicators)
      if (!i.assessed) '${i.category.name}/${i.key} (${t('scr.na.${i.gap}')})',
  ];
  if (gaps.isNotEmpty) out.write('\nNot assessed: ${gaps.join('; ')}.');
  out.write(
    '\nScoring functions (value → score, linear between): EU 0→0, 70→60, 80→70, 90→80, 94→90, 100→100 (ASABE EP405.1 classes); overlap CU 0→0, 75→60, 85→80, 100→100; q_var 0→100, 10→90, 20→70, 100→0; a share that must be 100 % scores its value; a count that must be 0 scores 100 at 0 and 0 from 1. Read the same table with get_report_table "scorecard"; Design → Design scorecard shows it with a radar.',
  );
  return out.toString();
}

List<AgentTool> opsScr(AgentToolbox b) {
  final c = b.c;
  return [
    cadOp(
      b,
      group: 'engineering',
      name: 'design_scorecard',
      description:
          'Design → Design scorecard: the quality of the designed project in one transparent index, built only from what the design results, the design check, the Messages list and the analyses compute. Seven categories, each scored 0–100 with a grade A–E: uniformity (EU of the drip and micro zones, sprinkler overlap CU, emitter flow variation q_var, flow-weighted over the zones), hydraulics (pipe length within the velocity limit and within its pressure class, emitters within their pressure window, zones and pivots given the pressure they need), energy (pump duties within the catalogue range and near their best efficiency, the share of the pump head the critical zone uses; kWh per m³ and per ha·mm reported), water and soil (sprinkler rate within the soil intake, water infiltrated without runoff, the peak FAO-56 demand met in the irrigation window), economy (life-cycle cost against the cheapest saved alternative; cost per area reported), robustness (pipes within their class with water hammer, NPSH margin and suction lift, and after the ageing test the emitters within the window and the EU aged and clogged) and completeness (errors and warnings of the Messages list, mainline high points without an air valve, priced bill of materials). Every indicator gives its value, target, the standard or design parameter the target comes from, its score by a stated piecewise-linear function and the points the overall score gains at 100, sorted into what to improve first with the operation that does it. Needs design results; changes nothing. '
          'Inputs: compare_with (an alternative saved with its results, by name or id, or "remembered" for the score remembered in the dialog; omitted: the previous call of this operation for this project, so calling it before and after a change shows what the change did), run_ageing (true runs the ageing test first: three more analyses, slow on large projects).',
      schema: obj({
        'compare_with': str('An alternative (name or id) saved with its results, or "remembered"; omitted: the previous call of this operation.'),
        'run_ageing': bool_('Run the ageing test first so the robustness over the life of the design is assessed (three more analyses).'),
      }),
      run: (a, _) async {
        engNeedResults(c);
        engNotBusy(c);
        if (a.flag('run_ageing') ?? false) await runScorecardAgeing(c);
        final s = projectScorecard(c)!;
        final uid = b.p.meta.uid;
        DesignScorecard? before;
        var name = '';
        final ref = a.str('compare_with');
        if (ref != null && ref.isNotEmpty) {
          before = scorecardToCompare(c, ref);
          if (before == null) {
            final choices = scorecardComparisons(c);
            throw ToolInputError(
              'Nothing to compare named "$ref". ${choices.isEmpty ? 'No alternative is saved with its results and no score is remembered.' : 'Choices: ${[for (final (id, label) in choices) '$id ($label)'].join(', ')}.'}',
            );
          }
          name = ref == 'remembered' ? 'the remembered score' : 'the alternative "$ref"';
        } else if (_previous[uid] case final prev?) {
          before = prev.$1;
          final d = DateTime.now().difference(prev.$2);
          name = 'the previous design_scorecard call (${d.inMinutes} min ago)';
        }
        _previous[uid] = (s, DateTime.now());
        return ToolOutput(scorecardAiText(b, s, before: before, beforeName: name));
      },
    ),
  ];
}
