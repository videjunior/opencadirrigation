/// Operations added in 1.6.0 (MOT+) for the ageing and clogging scenarios
/// and the network analyses that can be cancelled (UI-19), joined to [opsMot].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/life_scenarios.dart';
import '../agent_tools.dart';
import '../ops_eng_common.dart';

List<AgentTool> opsMotScenarios(AgentToolbox b) {
  final c = b.c;
  return [
    engOp(
      b,
      name: 'life_scenarios',
      description:
          'Mainline → The design over its life: the designed project analysed again with the pipes it was designed with, (1) as new, (2) aged — the Hazen-Williams C down by c_loss_per_year points a year and the Darcy-Weisbach roughness up by roughness_mm_per_year (Scobey and Manning do not age here) — (3) with the emitters clogged — their flow down by clogging_pct and their manufacturing variation up by cv_increase — and (4) both, side by side: largest system flow, lowest and highest emitter pressure, worst EU and CU, zones out of their window, largest pressure a valve lacks, pressure the supplies need, highest pump head, energy a year. Shows the margin of the design over its life; changes nothing. Needs design results. Inputs: years (0–100, default 15), c_loss_per_year (0–10, default 0.5), roughness_mm_per_year (0–1, default 0.01), clogging_pct (0–90, default 10), cv_increase (0–0.5, default 0.05).',
      schema: obj({
        'years': num_('Years of use, 0–100 (default 15).'),
        'c_loss_per_year': num_('Hazen-Williams C points lost a year, 0–10 (default 0.5; plastics 0.2–1, metals more).'),
        'roughness_mm_per_year': num_('Darcy-Weisbach roughness gained a year, mm, 0–1 (default 0.01).'),
        'clogging_pct': num_('Share of the emitter flow lost to clogging, %, 0–90 (default 10).'),
        'cv_increase': num_('Added to the manufacturing coefficient of variation of the emitters, 0–0.5 (default 0.05).'),
      }),
      run: (a, _) async {
        engNeedResults(c);
        engNotBusy(c);
        final o = LifeOptions(
          years: a.number('years', min: 0, max: 100) ?? 15,
          cLossPerYear: a.number('c_loss_per_year', min: 0, max: 10) ?? 0.5,
          roughnessMmPerYear: a.number('roughness_mm_per_year', min: 0, max: 1) ?? 0.01,
          clogging: (a.number('clogging_pct', min: 0, max: 90) ?? 10) / 100,
          cvIncrease: a.number('cv_increase', min: 0, max: 0.5) ?? 0.05,
        );
        final f = await lifeScenariosAsync(b.p, options: o, asNew: c.results, label: b.t.call);
        String row(String name, String Function(LifeFigures x) cell) => [name, for (final x in f) cell(x)].join(' | ');
        final notes = lifeNotes(b.p, c.results);
        return ToolOutput(
          [
            'After ${engN(o.years, 0)} years: C −${engN(o.cLoss, 1)}, roughness +${engN(o.roughnessGain, 3)} mm; clogging ${engN(100 * o.clogging, 0)} % of the flow, CV +${engN(o.cvIncrease, 3)}.',
            'figure | new | aged | clogged | aged and clogged',
            row('largest system flow m³/h', (x) => engN(x.peakFlow * 3600, 2)),
            row('lowest emitter pressure m', (x) => engN(x.minPressure, 1)),
            row('highest emitter pressure m', (x) => engN(x.maxPressure, 1)),
            row('worst EU %', (x) => engN(x.minEu, 1)),
            row('worst CU %', (x) => engN(x.minCu, 1)),
            row('zones out of their window', (x) => '${x.zonesOutOfWindow} of ${x.zoneCount}'),
            row('largest pressure a valve lacks m', (x) => engN(x.worstDeficit, 1)),
            row('pressure the supplies need m', (x) => engN(x.supplyHead, 1)),
            row('highest pump head m', (x) => engN(x.pumpHead, 1)),
            row('energy a year (${b.p.params.currency})', (x) => engN(x.annualEnergy, 0)),
            if (notes.isNotEmpty) 'Notes: ${notes.map((n) => b.t('life.note.$n')).join('; ')}',
          ].join('\n'),
        );
      },
    ),
  ];
}
