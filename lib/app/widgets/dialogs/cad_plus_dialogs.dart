/// Dialogs and actions of the drawing functions of 1.6.0 (CAD+): the
/// object snaps one by one, the named layer states, the dimension style,
/// the comparison with another copy of the project (a version, an open
/// tab, a file) and the comments brought back from a copy, the attributes
/// of a block reference, the block library as a file, the field photo.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/design/results.dart';
import '../../../core/model/blocks.dart';
import '../../../core/model/dim_style.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/layer_states.dart';
import '../../../core/model/project.dart';
import '../../../core/model/project_compare.dart';
import '../../../core/units.dart';
import '../../actions.dart' show openJsonInTab;
import '../../ai/ai_assistant.dart' show AiAssistant;
import '../../canvas/compare_overlay.dart';
import '../../canvas/snapping.dart' show snapModeKey;
import '../../io/file_io.dart';
import '../../io/project_store.dart' show StoredProject;
import '../../state/controller.dart';
import '../../theme.dart';
import '../../tools/cad_plus_commands.dart';
import '../../tools/cad_plus_tools.dart';
import '../../tools/insert_block_tool.dart';
import '../fields.dart';

Future<T?> _show<T>(BuildContext context, ProjectController c, String title, Widget body, {List<Widget>? actions, double width = 520}) => showDialog<T>(
  context: context,
  builder: (ctx) {
    final compact = MediaQuery.sizeOf(ctx).width < 700;
    // the content always scrolls (see the dialogs.dart helper)
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: compact ? MediaQuery.sizeOf(ctx).width - 48 : width,
        child: body is ScrollBody ? body : ScrollBody(child: body),
      ),
      actions: actions ?? [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
    );
  },
);

Widget _switch(String label, bool value, ValueChanged<bool> onChanged, {Key? key}) => SwitchListTile(
  key: key,
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontSize: 12)),
  value: value,
  onChanged: onChanged,
);

// ---------------------------------------------------------------- snaps

/// View → Snaps: every object snap on or off, the snap distance, the polar
/// steps and the grid, the length and angle beside the cursor and the
/// magnifier of the touch screen (remembered for the next visits).
Future<void> showSnapSettingsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final s = c.snap;
  return _show(
    context,
    c,
    t('snap.settings'),
    StatefulBuilder(
      builder: (ctx, setState) {
        void upd(VoidCallback fn) {
          setState(fn);
          c.refresh();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _switch('${t('status.snap')} (F3)', s.enabled, (v) => upd(() => s.enabled = v), key: const Key('snap_enabled')),
            SectionTitle(t('snap.modes')),
            Wrap(
              spacing: 4,
              children: [
                for (final m in snapModes)
                  FilterChip(
                    key: Key('snap_mode_$m'),
                    label: Text(t(snapModeKey(m)), style: const TextStyle(fontSize: 12)),
                    selected: s.modes.contains(m),
                    onSelected: (v) => upd(() => v ? s.modes.add(m) : s.modes.remove(m)),
                  ),
              ],
            ),
            Row(
              children: [
                TextButton(key: const Key('snap_all'), onPressed: () => upd(() => s.modes.addAll(snapModes)), child: Text(t('snap.all'))),
                TextButton(key: const Key('snap_none'), onPressed: () => upd(s.modes.clear), child: Text(t('snap.none'))),
              ],
            ),
            Text(t('snap.onceHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            SectionTitle(t('snap.options')),
            NumField(
              key: const Key('snap_tolerance'),
              label: t('snap.tolerance'),
              value: s.tolerancePx,
              decimals: 0,
              signed: false,
              onChanged: (v) => upd(() => s.tolerancePx = v.clamp(1, 50).toDouble()),
            ),
            SpecDropdown<double>(
              key: const Key('snap_polar'),
              label: t('status.polar'),
              value: '${s.polarStepDeg}',
              items: {...SnapSettings.polarSteps, s.polarStepDeg}.toList(),
              labelOf: (v) => v == 0 ? t('snap.polarOff') : '${v.round()}°',
              idOf: (v) => '$v',
              onChanged: (v) => upd(() => s.polarStepDeg = double.tryParse(v ?? '0') ?? 0),
            ),
            _switch('${t('status.ortho')} (F8)', s.ortho, (v) => upd(() => s.ortho = v), key: const Key('snap_ortho')),
            _switch('${t('status.grid')} (F9)', s.grid, (v) => upd(() => s.grid = v), key: const Key('snap_grid')),
            NumField(
              key: const Key('snap_grid_size'),
              label: '${t('snap.gridSize')} (${c.units.lengthLabel})',
              value: c.units.lengthFromSi(s.gridSize),
              decimals: 3,
              signed: false,
              onChanged: (v) {
                if (v > 0) upd(() => s.gridSize = c.units.lengthToSi(v));
              },
            ),
            SectionTitle(t('snap.input')),
            _switch(t('cadp.dynamicInput'), c.cadPlus.dynamicInput, (v) => upd(() => c.cadPlus.dynamicInput = v), key: const Key('snap_dynamic')),
            Text(t('cadp.dynamicInputHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            _switch(t('cadp.touchLoupe'), c.cadPlus.touchLoupe, (v) => upd(() => c.cadPlus.touchLoupe = v), key: const Key('snap_loupe')),
            SectionTitle(t('cadp.designSection')),
            _switch(t('cadp.editDuringDesign'), c.editDuringDesign, (v) => upd(() => c.editDuringDesign = v), key: const Key('snap_edit_during_design')),
            Text(t('cadp.editDuringDesignHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            Text(t('snap.remembered'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          ],
        );
      },
    ),
    width: 460,
  );
}

// ---------------------------------------------------------------- layer states

/// View → Layers → Layer states: keep how the layers are shown and locked
/// under a name, put it back, delete it; isolate the layers of the
/// selection and show them all again.
Future<void> showLayerStatesDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final name = TextEditingController(text: t('layer.stateDefault', {'n': '${c.project.layerStates.length + 1}'}));
  return _show(
    context,
    c,
    t('layer.states'),
    StatefulBuilder(
      builder: (ctx, setState) {
        final states = c.project.layerStates;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (states.isEmpty) Text(t('layer.statesNone'), key: const Key('layer_states_none'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
            for (final st in states)
              ListTile(
                key: Key('layer_state_${st.name}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(st.name, style: const TextStyle(fontSize: 12.5)),
                subtitle: Text(
                  t('layer.stateSummary', {'v': '${st.layers.values.where((x) => x.$1).length}', 'n': '${st.layers.length}', 'l': '${st.layers.values.where((x) => x.$2).length}'}),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(key: Key('layer_state_restore_${st.name}'), onPressed: () => setState(() => c.restoreLayerState(st.name)), child: Text(t('layer.stateRestore'))),
                    IconButton(
                      key: Key('layer_state_delete_${st.name}'),
                      tooltip: t('layer.stateDelete'),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => setState(() => c.deleteLayerState(st.name)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('layer_state_name'),
                    controller: name,
                    decoration: InputDecoration(labelText: t('layer.stateName'), isDense: true),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('layer_state_save'),
                  onPressed: () => setState(() {
                    if (c.saveLayerState(name.text)) name.text = t('layer.stateDefault', {'n': '${c.project.layerStates.length + 1}'});
                  }),
                  child: Text(t('layer.stateSave')),
                ),
              ],
            ),
            SectionTitle(t('layer.isolateTitle')),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('layer_isolate'),
                  icon: const Icon(Icons.filter_center_focus, size: 16),
                  label: Text(t('layer.isolate')),
                  onPressed: () => setState(() => c.isolateLayers()),
                ),
                OutlinedButton.icon(
                  key: const Key('layer_unisolate'),
                  icon: const Icon(Icons.layers_outlined, size: 16),
                  label: Text(t('layer.unisolate')),
                  onPressed: () => setState(c.unisolateLayers),
                ),
              ],
            ),
            Text(t('layer.isolateHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          ],
        );
      },
    ),
    width: 480,
  );
}

// ---------------------------------------------------------------- dimension style

/// Draw → Dimension style: text height, arrowheads, decimals and unit of
/// every dimension of the project (one undo step).
Future<void> showDimStyleDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final u = c.units;
  var st = c.project.dimStyle;
  final ok = await _show<bool>(
    context,
    c,
    t('dim.style'),
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumField(
            key: const Key('dim_text_height'),
            label: '${t('dim.textHeight')} (${u.lengthLabel})',
            value: u.lengthFromSi(st.textHeightM),
            decimals: 3,
            signed: false,
            onChanged: (v) => setState(() => st = st.copyWith(textHeightM: v <= 0 ? 0 : u.lengthToSi(v))),
          ),
          Text(t('dim.textHeightHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          const SizedBox(height: 6),
          Text(t('dim.arrows'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
          const SizedBox(height: 4),
          SegmentedButton<DimArrow>(
            key: const Key('dim_arrow'),
            segments: [
              for (final a in DimArrow.values)
                ButtonSegment(
                  value: a,
                  label: Text(t('dim.arrow.${a.name}'), style: const TextStyle(fontSize: 11)),
                ),
            ],
            selected: {st.arrow},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => st = st.copyWith(arrow: v.first)),
          ),
          NumField(
            key: const Key('dim_arrow_size'),
            label: '${t('dim.arrowSize')} (${u.lengthLabel})',
            value: u.lengthFromSi(st.arrowSizeM),
            decimals: 3,
            signed: false,
            onChanged: (v) => setState(() => st = st.copyWith(arrowSizeM: v <= 0 ? 0 : u.lengthToSi(v))),
          ),
          NumField(
            key: const Key('dim_decimals'),
            label: t('dim.decimals'),
            value: st.decimals.toDouble(),
            decimals: 0,
            signed: false,
            onChanged: (v) => setState(() => st = st.copyWith(decimals: v.round().clamp(0, 6))),
          ),
          SpecDropdown<LengthUnit?>(
            key: const Key('dim_unit'),
            label: t('dim.unit'),
            value: st.unit?.name ?? '',
            items: [null, ...LengthUnit.values],
            labelOf: (x) => x == null ? t('dim.unitProject', {'u': u.lengthLabel}) : Units(length: x).lengthLabel,
            idOf: (x) => x?.name ?? '',
            onChanged: (v) => setState(() => st = v == null || v.isEmpty ? st.copyWith(clearUnit: true) : st.copyWith(unit: LengthUnit.values.byName(v))),
          ),
          _switch(t('dim.showUnit'), st.showUnit, (v) => setState(() => st = st.copyWith(showUnit: v)), key: const Key('dim_show_unit')),
          const SizedBox(height: 4),
          Text(t('dim.sample', {'v': st.length(12.5, u)}), key: const Key('dim_sample'), style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
    width: 440,
    actions: [
      Builder(builder: (ctx) => TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel')))),
      Builder(
        builder: (ctx) => TextButton(key: const Key('dim_reset'), onPressed: () => Navigator.pop(ctx, false), child: Text(t('dim.reset'))),
      ),
      Builder(
        builder: (ctx) => FilledButton(key: const Key('dim_ok'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('ok'))),
      ),
    ],
  );
  if (ok == true && c.setDimStyle(st)) c.notify(t('dim.styleSet'));
  if (ok == false && resetDimStyle(c)) c.notify(t('dim.styleSet'));
}

/// Draw → Dimension style → back to the program's style.
bool resetDimStyle(ProjectController c) => c.setDimStyle(DimStyle.standard);

// ---------------------------------------------------------------- comparison

/// What a copy to compare with is: a label, its project and its results.
typedef _Copy = (String label, Project project, DesignResults? results);

DesignResults? _resultsOf(Map<String, dynamic> j) {
  final r = j['results'];
  if (r is! Map) return null;
  try {
    return DesignResults.fromJson(r.cast<String, dynamic>());
  } on Object {
    return null;
  }
}

/// Reads a project file's text with its saved results (null: not a project).
_Copy? _copyOf(String label, String json) {
  try {
    final j = jsonDecode(json);
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    return (label, Project.fromJson(m), _resultsOf(m));
  } on Object {
    return null;
  }
}

/// File → Compare with…: another copy of this project — a version kept in
/// the browser, another open tab, or a file — against the drawing open:
/// the items added, removed and changed, the settings that differ and the
/// main figures of both; shown on the drawing on request. [version] opens
/// straight on that version.
Future<void> showCompareDialog(BuildContext context, ProjectController c, {StoredProject? version}) async {
  final t = c.t;
  final ws = AiAssistant.workspace;
  Future<_Copy?> pick(BuildContext ctx) {
    final tabs = [
      for (final x in ws?.tabs ?? const <ProjectController>[])
        if (!identical(x, c)) x,
    ];
    final versions = c.store.versions(c.project.meta.uid);
    // one row per copy (48 px high: a finger reaches it); the dialog closes with it
    Widget option(BuildContext q, Key key, String label, Future<_Copy?> Function() copy) => ListTile(
      key: key,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: () async {
        final x = await copy();
        if (q.mounted) Navigator.pop(q, x);
      },
    );
    return _show<_Copy>(
      ctx,
      c,
      t('cmp.pick'),
      Builder(
        builder: (q) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final x in tabs) option(q, Key('cmp_tab_${x.tabId}'), t('cmp.tab', {'n': x.project.meta.name}), () async => (t('cmp.tab', {'n': x.project.meta.name}), x.project, x.results)),
            for (final v in versions)
              option(q, Key('cmp_version_${v.version}'), t('cmp.version', {'v': '${v.version}'}), () async {
                final json = await c.store.load(v.uid, version: v.version);
                return json == null ? null : _copyOf(t('cmp.version', {'v': '${v.version}'}), json);
              }),
            option(q, const Key('cmp_file'), t('cmp.file'), () async {
              final f = await openTextFile(accept: '.json,.oci,.icad');
              return f == null ? null : _copyOf(f.$1, f.$2);
            }),
          ],
        ),
      ),
      width: 420,
    );
  }

  _Copy? other;
  if (version != null) {
    final json = await c.store.load(version.uid, version: version.version);
    if (json != null) other = _copyOf(t('cmp.version', {'v': '${version.version}'}), json);
  } else {
    if (!context.mounted) return;
    other = await pick(context);
  }
  if (other == null) return;
  final cmp = compareProjects(other.$2, c.project, beforeResults: other.$3, afterResults: c.results);
  c.track('compare');
  if (!context.mounted) return;
  await showComparisonDialog(context, c, cmp, other.$1);
}

/// The result of a comparison (see [showCompareDialog]).
Future<void> showComparisonDialog(BuildContext context, ProjectController c, ProjectComparison cmp, String label) {
  final t = c.t;
  final u = c.units;
  String fig(ComparedFigure f, double? v) {
    if (v == null) return '—';
    return switch (f.key) {
      'pipeLength' || 'lateralLength' => '${fmtUi(u.lengthFromSi(v), 1)} ${u.lengthLabel}',
      'minPressure' || 'maxPressure' => '${fmtUi(u.pressureFromHead(v), 1)} ${u.pressureLabel}',
      'flow' => '${fmtUi(u.flowFromSi(v / 3600), 2)} ${u.flowLabel}',
      'areaHa' => '${fmtUi(v, 3)} ha',
      'cost' => fmtUi(v, 2),
      _ => fmtUi(v, 0),
    };
  }

  return _show(
    context,
    c,
    t('cmp.title', {'n': label}),
    StatefulBuilder(
      builder: (ctx, setState) {
        final shown = c.shownComparison != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cmp.isEmpty
                  ? t('cmp.same')
                  : t('cmp.summary', {'a': '${cmp.count(ChangeKind.added)}', 'r': '${cmp.count(ChangeKind.removed)}', 'c': '${cmp.count(ChangeKind.changed)}'}),
              key: const Key('cmp_summary'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            if (cmp.settings.isNotEmpty) Text(t('cmp.settings', {'s': cmp.settings.map((s) => t('cmp.part.$s')).join(', ')}), style: const TextStyle(fontSize: 12)),
            SectionTitle(t('cmp.figures')),
            Table(
              columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.3)},
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    Text(t('cmp.before'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                    Text(t('cmp.now'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  ],
                ),
                for (final f in cmp.figures)
                  TableRow(
                    children: [
                      Text(t('cmp.fig.${f.key}'), style: const TextStyle(fontSize: 11.5)),
                      Text(fig(f, f.before), style: const TextStyle(fontSize: 11.5)),
                      Text(fig(f, f.after), style: TextStyle(fontSize: 11.5, fontWeight: f.differs ? FontWeight.bold : FontWeight.normal, color: f.differs ? Cad.attention : null)),
                    ],
                  ),
              ],
            ),
            if (cmp.changes.isNotEmpty) ...[
              SectionTitle(t('cmp.items')),
              _switch(t('cmp.show'), shown, (v) => setState(() => c.showComparison(v ? cmp : null)), key: const Key('cmp_show')),
              for (final ch in cmp.changes.take(200))
                ListTile(
                  key: Key('cmp_item_${ch.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (ch.kind) {
                      ChangeKind.added => Icons.add_circle_outline,
                      ChangeKind.removed => Icons.remove_circle_outline,
                      ChangeKind.changed => Icons.change_circle_outlined,
                    },
                    size: 18,
                    color: switch (ch.kind) {
                      ChangeKind.added => Cad.ok,
                      ChangeKind.removed => Cad.error,
                      ChangeKind.changed => Cad.attention,
                    },
                  ),
                  title: Text('${t('cmp.kind.${ch.kind.name}')} · ${ch.name.isEmpty ? ch.id : ch.name}', style: const TextStyle(fontSize: 12)),
                  subtitle: Text([ch.type, if (ch.keys.isNotEmpty) ch.keys.take(6).join(', ')].join(' — '), style: const TextStyle(fontSize: 10.5)),
                  onTap: ch.bounds.isEmpty
                      ? null
                      : () {
                          c.showComparison(cmp);
                          c.camera.fit(ch.bounds.inflate(framePadding(ch.bounds)));
                          c.refresh();
                          Navigator.pop(ctx);
                        },
                ),
              if (cmp.changes.length > 200) Text(t('cmp.more', {'n': '${cmp.changes.length - 200}'}), style: const TextStyle(fontSize: 11)),
            ],
          ],
        );
      },
    ),
    width: 560,
  );
}

/// A margin round [b] to frame it: a fifth of its size, at least 5 m.
double framePadding(Bounds b) => (b.width > b.height ? b.width : b.height) * 0.2 + 5;

/// Versions → Open in a new tab: the version as a copy of its own (its
/// own uid and name), beside the project open.
Future<bool> openVersionInTabAction(ProjectController c, StoredProject v) async {
  final ws = AiAssistant.workspace;
  if (ws == null) return false;
  final json = await c.store.load(v.uid, version: v.version);
  if (json == null) {
    c.notify(c.t('store.err.read'));
    return false;
  }
  final opened = openJsonInTab(ws, json, asCopy: true);
  if (opened == null) return false;
  opened.project.meta.name = c.t('cmp.versionName', {'n': opened.project.meta.name, 'v': '${v.version}'});
  opened.refresh();
  return true;
}

/// File → Bring back the comments of a copy: the review comments and
/// revision clouds of a copy sent for review and returned (one undo step).
Future<void> importReviewAction(BuildContext context, ProjectController c) async {
  final f = await openTextFile(accept: '.json,.oci,.icad');
  if (f == null) return;
  final other = _copyOf(f.$1, f.$2);
  if (other == null) {
    c.notify(c.t('cmt.notProject', {'n': f.$1}));
    return;
  }
  c.importReview(other.$2);
}

extension ReviewCommands on ProjectController {
  /// Brings the comments and revision clouds of [copy] into the project
  /// (see [mergeReview]). One undo step; returns what it did (null when
  /// refused or nothing came).
  ReviewMerge? importReview(Project copy) {
    final probe = mergeReview(Project.fromJson(project.toJson()), copy);
    if (probe.isEmpty) {
      notify(t('cmt.nothing', {'n': '${probe.unchanged}'}));
      return null;
    }
    final r = mutate(() => mergeReview(project, copy), invalidateResults: false, label: 'hist.importReview|${probe.added + probe.updated}');
    if (r == null) return null;
    select(r.ids);
    notify(t('cmt.imported', {'a': '${r.added}', 'u': '${r.updated}', 'k': '${r.unchanged}'}));
    return r;
  }
}

// ---------------------------------------------------------------- block references

/// The attribute values of the block reference [ref] (one undo step).
Future<void> showBlockAttributesDialog(BuildContext context, ProjectController c, BlockRefEntity ref) async {
  final t = c.t;
  final d = ref.definition ?? c.project.blocks.byName(ref.blockName);
  if (d == null || d.attributes.isEmpty) {
    c.notify(t('blkref.noAttributes', {'b': ref.blockName}));
    return;
  }
  final ctls = {for (final a in d.attributes) a.tag: TextEditingController(text: ref.attribute(a.tag))};
  final ok = await _show<bool>(
    context,
    c,
    t('blkref.attributesOf', {'b': d.name}),
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in d.attributes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              key: Key('blkref_attr_${a.tag}'),
              controller: ctls[a.tag],
              decoration: InputDecoration(labelText: a.prompt.isEmpty || a.prompt == a.tag ? a.tag : '${a.prompt} (${a.tag})', isDense: true),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    ),
    width: 420,
    actions: [
      Builder(builder: (ctx) => TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel')))),
      Builder(
        builder: (ctx) => FilledButton(key: const Key('blkref_attr_ok'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('ok'))),
      ),
    ],
  );
  if (ok == true) c.setBlockAttributes(ref.id, {for (final e in ctls.entries) e.key: e.value.text});
}

/// Blocks → Export the library: every block of the project in a file of
/// its own, to bring into other projects.
Future<void> exportBlockLibraryAction(ProjectController c) async {
  final blocks = c.project.blocks.blocks;
  if (blocks.isEmpty) {
    c.notify(c.t('blk.none'));
    return;
  }
  final name = c.project.meta.name.trim().isEmpty ? 'blocks' : c.project.meta.name.trim();
  await saveTextFile('$name.oci-blocks.json', const JsonEncoder.withIndent(' ').convert(blockLibraryToJson(blocks)));
  c.notify(c.t('blk.libraryExported', {'n': '${blocks.length}'}));
}

/// Blocks → Import a library: the blocks of a library file (or of a
/// project file) into the project's library; a block of a name already
/// there is redefined (its references follow). One undo step.
Future<void> importBlockLibraryAction(ProjectController c) async {
  final f = await openTextFile(accept: '.json');
  if (f == null) return;
  try {
    c.importBlockLibrary(blockLibraryFromJson(jsonDecode(f.$2)));
  } on Object {
    c.notify(c.t('blk.libraryInvalid', {'n': f.$1}));
  }
}

extension BlockLibraryCommands on ProjectController {
  /// Puts [blocks] into the project's library (one undo step); returns how
  /// many came. A block of a name already there replaces it.
  int importBlockLibrary(List<BlockDefinition> blocks) {
    if (blocks.isEmpty) {
      notify(t('blk.none'));
      return 0;
    }
    final replaced = blocks.where((b) => project.blocks.byName(b.name) != null).length;
    final done = mutate(
      () {
        for (final b in blocks) {
          project.blocks.put(b);
          b.addLayersTo(project);
        }
        return true;
      },
      invalidateResults: blocks.any((b) => b.inBom && blockRefsOf(b.name).isNotEmpty),
      label: 'hist.importBlocks|${blocks.length}',
    );
    if (done != true) return 0;
    entitiesChanged();
    notify(t('blk.libraryImported', {'n': '${blocks.length}', 'r': '$replaced'}));
    return blocks.length;
  }
}

// ---------------------------------------------------------------- field photo

/// Draw → Field photo: a photo of the camera or of a file pinned to the
/// drawing as a review comment, where its GPS says, else where the device
/// is, else where the user clicks (no AI needed).
Future<void> fieldPhotoAction(ProjectController c) async {
  final f = await openBinaryFile(accept: 'image/*,.jpg,.jpeg,.png,.webp,.heic');
  if (f == null) return;
  c.addFieldPhoto(f.$2, f.$1);
}

/// The photo of the comment [id] added or replaced from the camera or a
/// file; with [move] the comment goes where the photo's GPS says.
Future<void> commentPhotoAction(ProjectController c, String id, {bool move = false}) async {
  final f = await openBinaryFile(accept: 'image/*,.jpg,.jpeg,.png,.webp,.heic');
  if (f == null) return;
  c.setCommentPhoto(id, f.$2, f.$1, move: move);
}
