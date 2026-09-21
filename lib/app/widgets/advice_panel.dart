import 'package:flutter/material.dart';

import '../../core/design/advisor.dart';
import '../../core/design/auto_fix.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'dialogs/terrain_dialogs.dart' show dialogWidth;
import 'reports_panel.dart' show toolNameOfEntity;

/// The design assistant: every problem of the project with what it means,
/// how to solve it and one-click corrections, plus "fix automatically" and
/// "optimise design". Shown in the Messages tab and in the design check.
class AdvicePanel extends StatelessWidget {
  const AdvicePanel({super.key, required this.c, this.listKey, this.onLocated});
  final ProjectController c;

  /// Key of the list (tests look the design check list up by it).
  final Key? listKey;

  /// Called after a problem was located on the drawing (a dialog may close).
  final VoidCallback? onLocated;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = c.t;
        final advice = c.advice;
        final counts = {for (final l in AdviceLevel.values) l: advice.where((a) => a.level == l).length};
        final canFix = advice.any((a) => a.autoFixable);
        final working = c.assistantProgress.isNotEmpty || c.busy;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final l in AdviceLevel.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(adviceIcon(l), size: 15, color: adviceColor(l)),
                  const SizedBox(width: 3),
                  Text('${counts[l]} ${t('adv.level.${l.name}')}', style: TextStyle(fontSize: 11.5, color: adviceColor(l))),
                ]),
              Tooltip(
                message: t('adv.fixAllHint'),
                child: FilledButton.icon(
                  key: const Key('advice_fix_all'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
                  onPressed: canFix && !working ? () => showAutoFixDialog(context, c) : null,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(t('adv.fixAll')),
                ),
              ),
              Tooltip(
                message: t('opt.explain'),
                child: OutlinedButton.icon(
                  key: const Key('advice_optimize'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
                  onPressed: working || counts[AdviceLevel.error]! > 0 && c.results == null ? null : () => showOptimizeDialog(context, c),
                  icon: const Icon(Icons.savings_outlined, size: 16),
                  label: Text(t('adv.optimize')),
                ),
              ),
              if (working)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  Text(c.assistantProgress.isNotEmpty ? c.assistantProgress : t('adv.designing'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                ]),
            ]),
          ),
          if (c.results == null && advice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text(t('adv.runHint'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ),
          Expanded(
            child: ListView.builder(
              key: listKey,
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              itemCount: advice.isEmpty ? 1 : advice.length,
              itemBuilder: (context, i) {
                if (advice.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle_outline, color: CadColors.ok, size: 18),
                      const SizedBox(width: 6),
                      Flexible(child: Text(c.results == null ? t('adv.noneYet') : t('adv.none'), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    ]),
                  );
                }
                final a = advice[i];
                // the explanation opens on the first problem of each kind
                final first = !advice.take(i).any((b) => b.code == a.code);
                return AdviceCard(key: ValueKey(a.key), c: c, advice: a, expanded: first && a.level != AdviceLevel.info, onLocated: onLocated);
              },
            ),
          ),
        ]);
      },
    );
  }
}

IconData adviceIcon(AdviceLevel l) => switch (l) { AdviceLevel.error => Icons.error_outline, AdviceLevel.warning => Icons.warning_amber_outlined, AdviceLevel.info => Icons.info_outline };
Color adviceColor(AdviceLevel l) => switch (l) { AdviceLevel.error => CadColors.unconnected, AdviceLevel.warning => CadColors.warning, AdviceLevel.info => Colors.white60 };

/// Title of a problem: its message, the zone / flow it belongs to and the
/// items involved.
String adviceTitle(ProjectController c, Advice a) {
  final t = c.t;
  final base = t.has('check.${a.raw}') ? t('check.${a.raw}') : (t.has('warn.${a.raw}') ? t('warn.${a.raw}') : (t.has('adv.${a.code}.title') ? t('adv.${a.code}.title') : a.raw));
  final names = <String>[];
  for (final id in a.entityIds.take(3)) {
    final e = c.project.byId(id);
    if (e == null) continue;
    names.add(e.name.isNotEmpty ? e.name : t('tool.${toolNameOfEntity(e)}'));
  }
  if (a.entityIds.length > 3) names.add('+${a.entityIds.length - 3}');
  // the check gives the internal kind of an unconnected / duplicated item:
  // its name (below) already says what it is
  final value = switch (a.code) {
    'unconnected' || 'duplicate_item' => '',
    'no_pipes_for_usage' when t.has('adv.use.${a.value}') => t('adv.use.${a.value}'),
    _ => a.value,
  };
  final extra = [if (value.isNotEmpty) value, if (names.isNotEmpty) names.join(', ')].join(' · ');
  final head = a.context.isEmpty ? base : '${a.context}: $base';
  return extra.isEmpty ? head : '$head ($extra)';
}

/// One problem: title, "why", "how to fix", locate and correction buttons.
class AdviceCard extends StatefulWidget {
  const AdviceCard({super.key, required this.c, required this.advice, this.expanded = true, this.onLocated});
  final ProjectController c;
  final Advice advice;
  final bool expanded;
  final VoidCallback? onLocated;

  @override
  State<AdviceCard> createState() => _AdviceCardState();
}

class _AdviceCardState extends State<AdviceCard> {
  late bool open = widget.expanded;

  bool get _locatable {
    final a = widget.advice;
    return a.entityIds.isNotEmpty || a.at != null || (a.contextId != null && widget.c.project.byId(a.contextId!) != null);
  }

  void _locate() {
    final c = widget.c;
    final a = widget.advice;
    final ids = a.entityIds.where((id) => c.project.byId(id) != null).toList();
    if (ids.isEmpty && a.contextId != null && c.project.byId(a.contextId!) != null) ids.add(a.contextId!);
    if (ids.isNotEmpty) c.select(ids);
    if (a.at != null) {
      c.camera.center = a.at!;
      c.camera.scale = c.camera.scale < 3 ? 3 : c.camera.scale;
      c.refresh();
    } else if (ids.isNotEmpty) {
      c.zoomToEntity(ids.first);
    }
    widget.onLocated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = c.t;
    final a = widget.advice;
    final color = adviceColor(a.level);
    final reach = fmt(connectReach(c.project), 1);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F24),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: _locatable ? _locate : () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(adviceIcon(a.level), size: 16, color: color)),
              const SizedBox(width: 6),
              Expanded(child: Text(adviceTitle(c, a), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              InkWell(
                onTap: () => setState(() => open = !open),
                child: Padding(padding: const EdgeInsets.all(2), child: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white54)),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 8, 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            if (_locatable)
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11.5)),
                onPressed: _locate,
                icon: const Icon(Icons.center_focus_strong, size: 15),
                label: Text(t('adv.locate')),
              ),
            for (final k in a.fixes)
              FilledButton.tonalIcon(
                key: Key('fix_${k.name}_${a.key.hashCode}'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11.5)),
                onPressed: c.busy || c.assistantProgress.isNotEmpty ? null : () => c.applyAdviceFix(a, k),
                icon: const Icon(Icons.build_circle_outlined, size: 15),
                label: Text(t('fix.${k.name}', {'d': reach})),
              ),
          ]),
        ),
        if (open) ...[
          if (t.has('adv.${a.code}.why')) _para(t('adv.why'), t('adv.${a.code}.why'), Colors.white70),
          if (t.has('adv.${a.code}.how')) _para(t('adv.how'), t('adv.${a.code}.how'), Colors.white),
        ],
        const SizedBox(height: 2),
      ]),
    );
  }

  Widget _para(String label, String text, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(30, 0, 10, 4),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white60)),
      TextSpan(text: text),
    ]), style: TextStyle(fontSize: 11.5, color: color, height: 1.3)),
  );
}

// ---------------------------------------------------------------- dialogs

Future<void> _progress(BuildContext context, ProjectController c, String title) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    content: AnimatedBuilder(
      animation: c,
      builder: (_, _) => Row(children: [
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text(c.assistantProgress.isNotEmpty ? c.assistantProgress : c.t('adv.designing'), style: const TextStyle(fontSize: 12.5))),
      ]),
    ),
  ),
);

/// Runs "fix automatically" with a progress dialog, then lists what changed
/// and what is left.
Future<void> showAutoFixDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final nav = Navigator.of(context);
  final progress = _progress(context, c, t('adv.fixAll'));
  AutoFixReport? report;
  try {
    report = await c.autoFixAll();
  } finally {
    nav.pop();
    await progress;
  }
  if (report == null || !context.mounted) return;
  final r = report;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('adv.summaryTitle'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 520),
        child: SingleChildScrollView(
          key: const Key('autofix_summary'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(r.applied.isEmpty ? t('adv.summaryNone') : t('adv.summaryApplied', {'n': '${r.applied.length}'}), style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 6),
            for (final f in r.applied)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check, size: 15, color: CadColors.ok),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t(f.key, f.args), style: const TextStyle(fontSize: 12))),
                ]),
              ),
            const SizedBox(height: 10),
            Text(r.errors + r.warnings == 0 ? t('adv.allClear') : t('adv.remaining', {'e': '${r.errors}', 'w': '${r.warnings}'}), style: TextStyle(fontSize: 12.5, color: r.errors == 0 ? CadColors.ok : CadColors.warning)),
            const SizedBox(height: 6),
            Text(t('adv.undoHint'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      ),
      actions: [
        if (r.applied.isNotEmpty)
          TextButton(onPressed: () {
            c.undo();
            Navigator.pop(ctx);
          }, child: Text(t('adv.undoAll'))),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
      ],
    ),
  );
}

/// Options, run and before / after comparison of the design optimisation.
Future<void> showOptimizeDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  var resizeAll = false, pumps = true, valves = true;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(t('opt.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t('opt.explain'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: pumps, onChanged: (v) => setState(() => pumps = v ?? true), title: Text(t('opt.pumps'), style: const TextStyle(fontSize: 12))),
          CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: valves, onChanged: (v) => setState(() => valves = v ?? true), title: Text(t('opt.valves'), style: const TextStyle(fontSize: 12))),
          CheckboxListTile(key: const Key('opt_resize_all'), dense: true, contentPadding: EdgeInsets.zero, value: resizeAll, onChanged: (v) => setState(() => resizeAll = v ?? false), title: Text(t('opt.resizeAll'), style: const TextStyle(fontSize: 12))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton.icon(key: const Key('opt_run'), onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.savings_outlined, size: 16), label: Text(t('opt.run'))),
      ],
    )),
  );
  if (go != true || !context.mounted) return;
  final nav = Navigator.of(context);
  final progress = _progress(context, c, t('opt.title'));
  OptimizeReport? report;
  try {
    report = await c.optimizeDesign(OptimizeOptions(resizeFixedPipes: resizeAll, choosePumps: pumps, resizeValves: valves));
  } finally {
    nav.pop();
    await progress;
  }
  if (report == null || !context.mounted) return;
  final r = report;
  final cur = c.project.params.currency;
  String money(double v) => '$cur ${fmt(v, 0)}';
  TableRow row(String label, String before, String after, {bool better = false}) => TableRow(children: [
    Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(label, style: const TextStyle(fontSize: 12))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(before, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(after, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: better ? CadColors.ok : null))),
  ]);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('opt.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 520),
        child: SingleChildScrollView(
          key: const Key('optimize_summary'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(r.improved ? t('opt.kept') : t('opt.reverted'), style: TextStyle(fontSize: 12.5, color: r.improved ? CadColors.ok : Colors.white70)),
            const SizedBox(height: 8),
            Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)}, children: [
              TableRow(children: [const SizedBox(), Text(t('opt.before'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Colors.white54)), Text(t('opt.after'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Colors.white54))]),
              row(t('opt.capital'), money(r.before.capital), money(r.after.capital), better: r.after.capital < r.before.capital - 0.5),
              row(t('opt.energy'), money(r.before.energy), money(r.after.energy), better: r.after.energy < r.before.energy - 0.5),
              row(t('opt.annual'), money(r.before.annualTotal), money(r.after.annualTotal), better: r.after.annualTotal < r.before.annualTotal - 0.5),
              row(t('opt.problems'), '${r.before.errors} / ${r.before.warnings}', '${r.after.errors} / ${r.after.warnings}', better: r.after.errors < r.before.errors),
            ]),
            if (r.improved && r.applied.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final f in r.applied)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check, size: 15, color: CadColors.ok),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t(f.key, f.args), style: const TextStyle(fontSize: 12))),
                  ]),
                ),
            ],
            const SizedBox(height: 8),
            Text(t('opt.note'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      ),
      actions: [
        if (r.improved)
          TextButton(onPressed: () {
            c.undo();
            Navigator.pop(ctx);
          }, child: Text(t('opt.undo'))),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
      ],
    ),
  );
}
