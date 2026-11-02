/// The design over its life (1.6.0 MOT+): the designed project analysed
/// again with its pipes aged (the Hazen-Williams C falling with the years,
/// the Darcy-Weisbach roughness growing) and its emitters clogged (less
/// flow, more variation), each against the new design (`life_scenarios.dart`).
/// The analyses run a case at a time, with their progress and a Cancel
/// button; nothing in the project changes.
library;

import 'package:flutter/material.dart';

import '../../../core/design/analysis_control.dart';
import '../../../core/design/life_scenarios.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The last options of each project (kept while the program runs).
final Map<String, LifeOptions> _lastOptions = {};

Future<void> showLifeScenariosDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  var o = _lastOptions[c.project.meta.uid] ?? const LifeOptions();
  List<LifeFigures>? figures;
  AnalysisControl? control;
  double? progress;
  var busy = false;
  final cur = c.project.params.currency;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void change(LifeOptions next) => setState(() {
          o = next;
          _lastOptions[c.project.meta.uid] = next;
          figures = null;
        });
        Future<void> run() async {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            busy = true;
            progress = null;
          });
          late final AnalysisControl ctl;
          ctl = control = AnalysisControl(
            onProgress: (done, total) {
              if (!ctx.mounted) {
                ctl.cancel();
                return;
              }
              if (total > 0) setState(() => progress = done / total);
            },
          );
          try {
            final f = await lifeScenariosAsync(c.project, options: o, asNew: c.results, label: (k) => t(k), control: ctl);
            if (ctx.mounted) {
              setState(() {
                figures = f;
                busy = false;
              });
            }
          } on AnalysisCancelled {
            if (ctx.mounted) setState(() => busy = false);
          }
        }

        final f = figures;
        String p(double v) => fmtUi(u.pressureFromHead(v), 1);
        final rows = f == null
            ? const <(String, List<String>)>[]
            : <(String, List<String>)>[
                ('${t('life.peakFlow')} (${u.flowLabel})', [for (final x in f) fmtUi(u.flowFromSi(x.peakFlow), 2)]),
                ('${t('life.minPressure')} (${u.pressureLabel})', [for (final x in f) p(x.minPressure)]),
                ('${t('life.maxPressure')} (${u.pressureLabel})', [for (final x in f) p(x.maxPressure)]),
                ('EU %', [for (final x in f) fmtUi(x.minEu, 1)]),
                ('CU %', [for (final x in f) fmtUi(x.minCu, 1)]),
                (t('life.outOfWindow'), [for (final x in f) '${x.zonesOutOfWindow} / ${x.zoneCount}']),
                ('${t('life.deficit')} (${u.pressureLabel})', [for (final x in f) p(x.worstDeficit)]),
                ('${t('life.supplyHead')} (${u.pressureLabel})', [for (final x in f) p(x.supplyHead)]),
                ('${t('life.pumpHead')} (${u.pressureLabel})', [for (final x in f) p(x.pumpHead)]),
                ('${t('life.energy')} ($cur)', [for (final x in f) fmtUi(x.annualEnergy, 0)]),
              ];
        final notes = lifeNotes(c.project, c.results);
        return AlertDialog(
          title: Text(t('life.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 720),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('life.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
                  for (final n in notes) Text(t('life.note.$n'), style: TextStyle(fontSize: 11, color: Cad.warning)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 150,
                        child: NumField(
                          key: const Key('life_years'),
                          label: t('life.years'),
                          value: o.years,
                          decimals: 0,
                          onChanged: (v) => change(_with(o, years: v.clamp(0, 100).toDouble())),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: NumField(
                          key: const Key('life_closs'),
                          label: t('life.cLoss'),
                          value: o.cLossPerYear,
                          decimals: 2,
                          onChanged: (v) => change(_with(o, cLoss: v.clamp(0, 10).toDouble())),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: NumField(
                          key: const Key('life_rough'),
                          label: t('life.roughness'),
                          value: o.roughnessMmPerYear,
                          decimals: 3,
                          onChanged: (v) => change(_with(o, rough: v.clamp(0, 1).toDouble())),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: NumField(
                          key: const Key('life_clog'),
                          label: t('life.clogging'),
                          value: 100 * o.clogging,
                          decimals: 0,
                          onChanged: (v) => change(_with(o, clog: (v / 100).clamp(0, 0.9).toDouble())),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: NumField(
                          key: const Key('life_cv'),
                          label: t('life.cv'),
                          value: o.cvIncrease,
                          decimals: 3,
                          onChanged: (v) => change(_with(o, cv: v.clamp(0, 0.5).toDouble())),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('life_run'),
                          onPressed: busy || c.results == null ? null : run,
                          icon: const Icon(Icons.hourglass_bottom, size: 16),
                          label: Text(t('life.run')),
                        ),
                        if (busy) SizedBox(width: 120, child: LinearProgressIndicator(value: progress)),
                        if (busy) TextButton(key: const Key('life_cancel'), onPressed: () => control?.cancel(), child: Text(t('cancel'))),
                      ],
                    ),
                  ),
                  if (rows.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        children: [
                          TableRow(children: [const SizedBox.shrink(), for (final k in LifeCase.values) _cell(t('life.case.${k.name}'), bold: true)]),
                          for (final (label, cells) in rows) TableRow(children: [_cell(label), for (final x in cells) _cell(x)]),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

Widget _cell(String s, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(s, style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null)),
);

LifeOptions _with(LifeOptions o, {double? years, double? cLoss, double? rough, double? clog, double? cv}) =>
    LifeOptions(years: years ?? o.years, cLossPerYear: cLoss ?? o.cLossPerYear, roughnessMmPerYear: rough ?? o.roughnessMmPerYear, clogging: clog ?? o.clogging, cvIncrease: cv ?? o.cvIncrease);
