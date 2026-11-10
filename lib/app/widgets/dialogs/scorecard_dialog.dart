/// Design → Design scorecard (1.7.0 SCR): the quality of the designed
/// project on one page (`core/design/scorecard.dart`) — the overall grade,
/// a radar of the categories, what to improve first with a button to the
/// tool that does it, the indicator table (value, target, source, score,
/// grade, weight, points to gain), the comparison with a saved alternative
/// or with a score remembered before a change, the ageing test that scores
/// the robustness, and the export of the scorecard as CSV, XLSX or PDF.
/// Nothing in the project changes.
library;

import 'package:flutter/material.dart';

import '../../../core/design/analysis_control.dart';
import '../../../core/design/life_scenarios.dart';
import '../../../core/design/report_tables.dart';
import '../../../core/design/scorecard.dart';
import '../../../core/io/pdf.dart';
import '../../../core/io/project_export.dart' show ReportFormat;
import '../../../core/io/scorecard_chart.dart';
import '../../../core/io/xlsx.dart';
import '../../actions.dart' show deliverExport;
import '../../io/pdf_font_loader.dart';
import '../../project_name.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../advice_panel.dart' show showAutoFixDialog;
import '../fields.dart';
import '../reports_panel.dart' show ReportTableView;
import '../scorecard_radar.dart';
import 'deliverables_dialogs.dart' show showLifeCycleDialog;
import 'densogram_dialog.dart';
import 'dialogs.dart' show showDesignParamsDialog, showManagementDialog;
import 'more_dialogs.dart' show showCatalogEditorDialog, showPumpSelectionDialog;
import 'terrain_dialogs.dart' show dialogWidth;
import 'transient_dialogs.dart' show showAirValveDialog;
import 'water_balance_dialogs.dart' show showIrrigationProgrammeDialog;

/// What the scorecard keeps while the program runs, by project: the ageing
/// test of the current results (dropped when the results change) and a
/// score remembered to compare with after a change.
abstract final class ScorecardMemory {
  static final Map<String, (Object, List<LifeFigures>)> _life = {};
  static final Map<String, (DesignScorecard, DateTime)> _remembered = {};

  /// The ageing test of the results on screen, or null.
  static List<LifeFigures>? lifeOf(ProjectController c) {
    final e = _life[c.project.meta.uid];
    return e != null && identical(e.$1, c.results) ? e.$2 : null;
  }

  static void keepLife(ProjectController c, List<LifeFigures> f) {
    final r = c.results;
    if (r != null) _life[c.project.meta.uid] = (r, f);
  }

  /// The score remembered for this project and when.
  static (DesignScorecard, DateTime)? rememberedOf(ProjectController c) => _remembered[c.project.meta.uid];

  static void remember(ProjectController c, DesignScorecard s) => _remembered[c.project.meta.uid] = (s, DateTime.now());

  /// Forgets everything (tests).
  static void clear() {
    _life.clear();
    _remembered.clear();
  }
}

/// The scorecard of the project on screen (null without design results):
/// its Messages list, the ageing test when it ran, the display units.
DesignScorecard? projectScorecard(ProjectController c) {
  final r = c.results;
  if (r == null) return null;
  return designScorecard(c.project, r, advice: c.advice, life: ScorecardMemory.lifeOf(c), units: c.units);
}

/// Runs the ageing test of the project (life_scenarios.dart with its
/// defaults) for the robustness of the scorecard, and keeps it.
Future<List<LifeFigures>> runScorecardAgeing(ProjectController c, {AnalysisControl? control}) async {
  final f = await lifeScenariosAsync(c.project, asNew: c.results, label: (k) => c.t(k), control: control);
  ScorecardMemory.keepLife(c, f);
  return f;
}

/// What the scorecard can be compared with: the remembered score and the
/// alternatives saved with their results, as (id, label).
List<(String, String)> scorecardComparisons(ProjectController c) {
  final rem = ScorecardMemory.rememberedOf(c);
  String two(int v) => v.toString().padLeft(2, '0');
  return [
    if (rem != null) ('remembered', c.t('scr.remembered', {'d': '${two(rem.$2.hour)}:${two(rem.$2.minute)}'})),
    for (final sc in c.project.scenarios)
      if (sc.snapshot['results'] is Map) (sc.id, sc.name),
  ];
}

/// The scorecard compared with: the remembered one or an alternative's.
DesignScorecard? scorecardToCompare(ProjectController c, String id) {
  if (id == 'remembered') return ScorecardMemory.rememberedOf(c)?.$1;
  final sc = c.project.scenarios.where((s) => s.id == id || s.name == id).firstOrNull;
  return sc == null ? null : scenarioScorecard(sc);
}

Future<void> showScorecardDialog(BuildContext context, ProjectController c) => showDialog<void>(context: context, builder: (ctx) => _ScorecardDialog(c));

class _ScorecardDialog extends StatefulWidget {
  const _ScorecardDialog(this.c);
  final ProjectController c;

  @override
  State<_ScorecardDialog> createState() => _ScorecardDialogState();
}

class _ScorecardDialogState extends State<_ScorecardDialog> {
  ProjectController get c => widget.c;
  DesignScorecard? _card;
  ReportTable? _table;
  String _sig = '';
  String _compare = '';
  DesignScorecard? _other;
  bool _ageing = false;
  double? _progress;
  AnalysisControl? _control;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _control?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// The scorecard, built again only when the results, the messages, the
  /// ageing test, the language or the units changed.
  DesignScorecard? _current() {
    final r = c.results;
    if (r == null || c.busy) return null;
    final adv = c.advice;
    final life = ScorecardMemory.lifeOf(c);
    final u = c.units;
    final sig = '${identityHashCode(r)}|${identityHashCode(adv)}|${identityHashCode(life)}|${c.lang}|${u.pressure}|${u.flow}|${u.length}|${c.project.params.currency}';
    if (_card == null || sig != _sig) {
      final s = _card = designScorecard(c.project, r, advice: adv, life: life, units: u);
      _table = scorecardTable(s, t: c.t.call, units: u, currency: c.project.params.currency);
      _sig = sig;
    }
    return _card;
  }

  Future<void> _runAgeing() async {
    if (_ageing || c.results == null) return;
    setState(() {
      _ageing = true;
      _progress = null;
    });
    late final AnalysisControl ctl;
    ctl = _control = AnalysisControl(
      onProgress: (done, total) {
        if (!mounted) {
          ctl.cancel();
          return;
        }
        if (total > 0) setState(() => _progress = done / total);
      },
    );
    try {
      await runScorecardAgeing(c, control: ctl);
    } on AnalysisCancelled {
      // stopped by the user: nothing kept
    } finally {
      if (mounted) setState(() => _ageing = false);
    }
  }

  void _setCompare(String id) {
    setState(() {
      _compare = id;
      _other = id.isEmpty ? null : scorecardToCompare(c, id);
    });
  }

  Future<void> _open(ScoreIndicator i) async {
    final ctx = context;
    switch (i.tool) {
      case 'params':
        await showDesignParamsDialog(ctx, c);
      case 'autofix':
        await showAutoFixDialog(ctx, c);
      case 'pumpSelect':
        await showPumpSelectionDialog(ctx, c);
      case 'densogram':
        await showDensogramDialog(ctx, c);
      case 'programme':
        await showIrrigationProgrammeDialog(ctx, c);
      case 'management':
        await showManagementDialog(ctx, c);
      case 'lcc':
        await showLifeCycleDialog(ctx, c);
      case 'airValves':
        await showAirValveDialog(ctx, c);
      case 'catalog':
        await showCatalogEditorDialog(ctx, c);
      case 'life':
        await _runAgeing();
      case 'messages':
        Navigator.pop(ctx);
        c.reportTab = ProjectController.messagesReportTab;
        c.showReports = true;
        c.refresh();
    }
  }

  void _locate(String id) {
    if (c.project.byId(id) == null) return;
    Navigator.pop(context);
    c.select([id]);
    c.zoomToEntity(id);
  }

  Future<void> _export(DesignScorecard s, ReportFormat f) async {
    final t = c.t;
    final tb = scorecardTable(s, t: t.call, units: c.units, currency: c.project.params.currency);
    final name = '${projectFileStem(t, c.project.meta.name)}_scorecard.${f.extension}';
    switch (f) {
      case ReportFormat.pdf:
        await preparePdfFonts([
          tb.title,
          ...tb.headers,
          for (final r in tb.rows)
            for (final x in r)
              if (x is String) x,
          for (final k in ScoreCategory.values) t('scr.c.${k.name}'),
          t('scr.overall'),
          t('scr.improvements'),
        ], language: c.lang);
        final r = c.results;
        if (r == null) return;
        await deliverExport(c, name, f.mime, () {
          final b = c.exporter().sheetBuilder();
          final doc = PdfDocument(title: tb.title, author: c.project.meta.designer, subject: tb.title, fonts: b.fonts);
          b.addReportPages(
            doc,
            [tb],
            charts: [scorecardChart(c.project, r, t: t.call, scorecard: s)],
          );
          return doc.build();
        });
      case ReportFormat.xlsx:
        await deliverExport(
          c,
          name,
          f.mime,
          () => XlsxWriter.write([
            XlsxSheet(
              name: tb.title,
              headers: tb.headers,
              rows: [
                for (final r in tb.rows) [for (final x in r) x is RNum ? double.parse(x.value.toStringAsFixed(x.decimals)) : x],
              ],
            ),
          ]),
        );
      case ReportFormat.csv:
      case ReportFormat.txt:
        await deliverExport(c, name, f.mime, () => f == ReportFormat.csv ? reportTablesToCsv([tb]) : reportTablesToText([tb]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final s = _current();
    final body = <Widget>[Text(t('scr.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg70))];
    if (c.busy) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            t('scr.busy'),
            key: const Key('scr_busy'),
            style: TextStyle(color: Cad.caution),
          ),
        ),
      );
    } else if (s == null) {
      body.addAll([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            t('scr.needDesign'),
            key: const Key('scr_need_design'),
            style: TextStyle(color: Cad.caution),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            key: const Key('scr_design'),
            onPressed: c.project.entities.isEmpty ? null : () => c.runDesign(),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: Text(t('design.all')),
          ),
        ),
      ]);
    } else {
      body.addAll(_content(context, s));
    }
    return AlertDialog(
      title: Text(t('scr.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(context, 920),
        child: ScrollBody(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        ),
      ),
      actions: [TextButton(key: const Key('scr_close'), onPressed: () => Navigator.pop(context), child: Text(t('close')))],
    );
  }

  List<Widget> _content(BuildContext context, DesignScorecard s) {
    final t = c.t;
    final other = _compare.isEmpty ? null : _other;
    final choices = scorecardComparisons(c);
    if (_compare.isNotEmpty && !choices.any((x) => x.$1 == _compare)) _compare = '';
    final o = s.overall;
    String delta(double? now, double? before) {
      if (now == null || before == null) return '';
      final d = now - before;
      return ' (${d >= 0 ? '+' : '−'}${fmtUi(d.abs(), 1)})';
    }

    final axes = [for (final cat in s.categories) (label: t('scr.c.${cat.category.name}'), score: cat.score, compare: other?.categoryOf(cat.category).score)];
    final radarLabel = [for (final a in axes) '${a.label} ${a.score == null ? t('scr.na.none') : fmtUi(a.score!, 0)}'].join(', ');
    final table = _table ?? scorecardTable(s, t: t.call, units: c.units, currency: c.project.params.currency);
    final improvements = s.improvements;
    return [
      const SizedBox(height: 10),
      // ---- the overall grade
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _GradeBadge(grade: s.grade, key: const Key('scr_grade')),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('scr.overall')}: ${o == null ? '–' : '${fmtUi(o, 1)} / 100'}${delta(o, other?.overall)}',
                key: const Key('scr_overall'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(t('scr.assessed', {'k': '${s.assessed.length}', 'n': '${s.categories.length}'}), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      // ---- the ageing test, a remembered score, the comparison, the export
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(key: const Key('scr_ageing'), onPressed: _ageing ? null : _runAgeing, icon: const Icon(Icons.hourglass_bottom, size: 16), label: Text(t('scr.ageing'))),
          if (_ageing) SizedBox(width: 100, child: LinearProgressIndicator(value: _progress)),
          if (_ageing) TextButton(key: const Key('scr_ageing_cancel'), onPressed: () => _control?.cancel(), child: Text(t('cancel'))),
          OutlinedButton.icon(
            key: const Key('scr_remember'),
            onPressed: () {
              ScorecardMemory.remember(c, s);
              setState(() {});
            },
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: Text(t('scr.remember')),
          ),
          if (choices.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: DropdownButton<String>(
                key: const Key('scr_compare'),
                value: _compare,
                isDense: true,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text('${t('scr.compare')}: –', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  for (final (id, label) in choices)
                    DropdownMenuItem(
                      value: id,
                      child: Text('${t('scr.compare')}: $label', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => _setCompare(v ?? ''),
              ),
            ),
          PopupMenuButton<ReportFormat>(
            key: const Key('scr_export'),
            tooltip: t('file.exportReport'),
            onSelected: (f) => _export(s, f),
            itemBuilder: (_) => [
              for (final f in const [ReportFormat.csv, ReportFormat.xlsx, ReportFormat.pdf]) PopupMenuItem(value: f, child: Text(t(f == ReportFormat.pdf ? 'exp.reportPdf' : 'exp.${f.name}'))),
            ],
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(t('file.exportReport'), style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      // ---- the radar and the categories
      LayoutBuilder(
        builder: (ctx, box) {
          final wide = box.maxWidth >= 600;
          final radar = ScorecardRadar(key: const Key('scr_radar'), axes: axes, size: wide ? 300 : box.maxWidth.clamp(200.0, 320.0).toDouble(), semanticLabel: radarLabel);
          final list = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final cat in s.categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t('scr.c.${cat.category.name}')} (${t('scr.col.weight').toLowerCase()} ${fmtUi(cat.weight, 0)})',
                          style: TextStyle(fontSize: 12.5, color: cat.score == null ? Cad.fg54 : Cad.fg87),
                        ),
                      ),
                      Text(
                        cat.score == null ? t('scr.na.none') : '${fmtUi(cat.score!, 0)}${delta(cat.score, other?.categoryOf(cat.category).score)}',
                        key: Key('scr_cat_${cat.category.name}'),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cat.score == null ? Cad.fg54 : Cad.fg87),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 26, child: _GradeBadge(grade: cat.grade, small: true)),
                    ],
                  ),
                ),
            ],
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    radar,
                    const SizedBox(width: 16),
                    Expanded(child: list),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: radar),
                    list,
                  ],
                );
        },
      ),
      const SizedBox(height: 12),
      // ---- what to improve first
      Text(t('scr.improvements'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      if (improvements.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            t('scr.nothing'),
            key: const Key('scr_nothing'),
            style: TextStyle(fontSize: 12, color: Cad.ok),
          ),
        ),
      for (final (i, g) in improvements.take(8)) _improvement(i, g),
      const SizedBox(height: 12),
      // ---- every indicator
      SizedBox(
        height: ReportTableView.minHeight(MediaQuery.textScalerOf(context), 10),
        child: ReportTableView(
          key: const Key('scr_table'),
          headers: table.headers,
          rows: table.rows,
          rowColors: [for (final w in table.warn) w ? Cad.tintWarning : null],
          rowIds: table.ids,
          onLocate: _locate,
          title: table.title,
          tools: true,
        ),
      ),
      // ---- the method
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('scr_method'),
          tilePadding: EdgeInsets.zero,
          title: Text(t('scr.methodTitle'), style: const TextStyle(fontSize: 13)),
          children: [Text(t('scr.method'), style: TextStyle(fontSize: 11.5, color: Cad.fg70))],
        ),
      ),
    ];
  }

  Widget _improvement(ScoreIndicator i, double gain) {
    final t = c.t;
    final value = scoreValueText(i, c.units, currency: c.project.params.currency, yr: t('prb.lcc.yr'));
    return Padding(
      key: Key('scr_imp_${i.key}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Cad.tintWarning, borderRadius: BorderRadius.circular(4)),
            child: Text(
              '+${fmtUi(gain, 1)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cad.fg87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t('scr.i.${i.key}')}: ${localizeUi(value)} → ${i.target}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (i.detail.isNotEmpty) Text(localizeUi(i.detail), style: TextStyle(fontSize: 11, color: Cad.fg60)),
                Text(t('scr.h.${i.key}'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
              ],
            ),
          ),
          if (i.tool != null) TextButton(key: Key('scr_open_${i.key}'), onPressed: () => _open(i), child: Text(t('scr.open'))),
        ],
      ),
    );
  }
}

/// A grade letter in its colour (A–B green, C amber, D–E red; "–" not assessed).
class _GradeBadge extends StatelessWidget {
  const _GradeBadge({super.key, required this.grade, this.small = false});
  final String? grade;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final g = grade;
    final color = switch (g) {
      'A' || 'B' => Cad.ok,
      'C' => Cad.caution,
      null => Cad.fg38,
      _ => Cad.error,
    };
    final side = small ? 22.0 : 48.0;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color, width: small ? 1 : 2),
        borderRadius: BorderRadius.circular(small ? 4 : 10),
      ),
      child: Text(
        g ?? '–',
        style: TextStyle(fontSize: small ? 12 : 26, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
