/// Fields of the properties panel for the drawing functions of 1.6.0
/// (CAD+): a block reference (its block, place and attribute values), the
/// photo buttons of a review comment, the kinds of a mixed selection (each
/// edited on its own, with the fields the panel did not have) and the
/// settings of Lengthen and of the outline by a click inside.
library;

import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../../core/model/lengthen.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/cad_plus_commands.dart';
import '../tools/cad_plus_tools.dart';
import '../tools/insert_block_tool.dart';
import 'dialogs/cad_plus_dialogs.dart';
import 'fields.dart';

/// The block of the reference [r], where it is and the values of its
/// attributes (each a field; one undo step per value), with the commands
/// that edit the block in place and explode the reference.
List<Widget> blockRefFields(ProjectController c, BlockRefEntity r) {
  final t = c.t;
  final d = r.definition ?? c.project.blocks.byName(r.blockName);
  return [
    KV(t('blkref.block'), d == null ? t('blkref.missing', {'b': r.blockName}) : r.blockName),
    if (d != null && d.description.isNotEmpty) Text(d.description, style: TextStyle(fontSize: 11, color: Cad.fg54)),
    NumField(
      key: const Key('blkref_rotation'),
      label: t('props.rotation'),
      value: r.rotationDeg,
      onChanged: (v) => c.mutate(() => r.rotationDeg = v, invalidateResults: false, label: 'hist.blockAttributes'),
    ),
    NumField(
      key: const Key('blkref_scale'),
      label: t('blk.scale'),
      value: r.scale,
      decimals: 3,
      signed: false,
      onChanged: (v) {
        if (v > 0) c.mutate(() => r.scale = v, invalidateResults: false, label: 'hist.blockAttributes');
      },
    ),
    if (d != null && d.attributes.isNotEmpty) ...[
      SectionTitle(t('blkref.attributes')),
      for (final a in d.attributes)
        TextFieldRow(
          key: Key('blkref_field_${a.tag}'),
          label: a.prompt.isEmpty || a.prompt == a.tag ? a.tag : '${a.prompt} (${a.tag})',
          value: r.attribute(a.tag),
          onChanged: (v) => c.setBlockAttributes(r.id, {a.tag: v}),
        ),
    ],
    if (d != null && d.inBom) Text(t('blkref.inBom'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
    Wrap(
      spacing: 6,
      children: [
        TextButton.icon(
          key: const Key('blkref_edit'),
          icon: const Icon(Icons.edit_note, size: 16),
          label: Text(t('blkref.edit'), style: const TextStyle(fontSize: 12)),
          onPressed: d == null ? null : () => c.startBlockEdit(r.id),
        ),
        TextButton.icon(
          key: const Key('blkref_explode'),
          icon: const Icon(Icons.scatter_plot_outlined, size: 16),
          label: Text(t('blkref.explode'), style: const TextStyle(fontSize: 12)),
          onPressed: d == null ? null : () => c.explodeBlockRefs([r.id]),
        ),
      ],
    ),
  ];
}

/// The buttons that put a photo on the comment [cm] from the camera or a
/// file (PRD-08), or replace it; the second moves the comment to where
/// the photo's GPS says.
Widget commentPhotoButtons(ProjectController c, CommentEntity cm) {
  final t = c.t;
  return Wrap(
    key: const Key('comment_photo_buttons'),
    spacing: 6,
    children: [
      TextButton.icon(
        key: const Key('comment_photo_add'),
        icon: const Icon(Icons.add_a_photo_outlined, size: 16),
        label: Text(t(cm.photo.isEmpty ? 'photo.add' : 'photo.replace'), style: const TextStyle(fontSize: 12)),
        onPressed: () => commentPhotoAction(c, cm.id),
      ),
      if (c.project.meta.georef != null)
        TextButton.icon(
          key: const Key('comment_photo_gps'),
          icon: const Icon(Icons.gps_fixed, size: 16),
          label: Text(t('photo.addAtGps'), style: const TextStyle(fontSize: 12)),
          onPressed: () => commentPhotoAction(c, cm.id, move: true),
        ),
    ],
  );
}

/// The kind of a mixed selection the panel edits now, per tab (null: the
/// most numerous).
final _batchKinds = Expando<String>('batchKind');

extension BatchKind on ProjectController {
  /// The kind of the selection the batch editor shows: the one chosen if
  /// it is still selected, else the most numerous.
  String batchKind(List<(String, int)> kinds) {
    final chosen = _batchKinds[this];
    if (chosen != null && kinds.any((k) => k.$1 == chosen)) return chosen;
    return kinds.first.$1;
  }

  void chooseBatchKind(String kind) {
    _batchKinds[this] = kind;
    refresh();
  }
}

/// The kinds of a mixed selection as chips (choosing one edits that kind),
/// and "only these" that keeps them alone selected.
Widget batchKindChips(ProjectController c, List<(String, int)> kinds, String current) {
  final t = c.t;
  return Wrap(
    key: const Key('batch_kinds'),
    spacing: 4,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final (kind, n) in kinds)
        ChoiceChip(
          key: Key('batch_kind_$kind'),
          label: Text('$n × ${t('tool.$kind')}', style: const TextStyle(fontSize: 11.5)),
          selected: kind == current,
          onSelected: (_) => c.chooseBatchKind(kind),
        ),
      if (kinds.length > 1)
        TextButton(
          key: const Key('batch_only_kind'),
          onPressed: () => c.keepSelectedKind(current),
          child: Text(t('batch.onlyThese'), style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

/// More fields of the batch editor for the selected items of [kind] (the
/// panel had a few per kind): the depth, arc and riser of laterals, the
/// regulated tapes, the radius of circles, the size of symbols and texts…
List<Widget> batchExtraFields(ProjectController c, String kind) {
  final t = c.t;
  final u = c.units;
  final sel = [
    for (final e in c.project.entities)
      if (c.selection.contains(e.id) && ProjectController.toolKeyOf(e) == kind) e,
  ];
  if (sel.isEmpty) return const [];
  T? common<T>(Iterable<T> values) {
    final list = values.toList();
    return list.isNotEmpty && list.every((v) => v == list.first) ? list.first : null;
  }

  Widget numberField(String key, String label, Iterable<double> values, void Function(Entity e, double v) apply, {bool length = false, bool positive = false, bool? inv}) {
    final v = common(values);
    return NumField(
      key: Key('batch_${kind}_$key'),
      label: length ? '$label (${u.lengthLabel})' : label,
      value: v == null ? 0 : (length ? u.lengthFromSi(v) : v),
      mixed: v == null,
      onChanged: (x) {
        final si = length ? u.lengthToSi(x) : x;
        if (positive && si <= 0) return;
        c.editSelectedKind(kind, (e) => apply(e, si), invalidate: inv);
      },
    );
  }

  Widget flag(String key, String label, Iterable<bool> values, void Function(Entity e, bool v) apply) {
    final v = common(values);
    return CheckboxListTile(
      key: Key('batch_${kind}_$key'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      tristate: true,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: v,
      onChanged: (x) => c.editSelectedKind(kind, (e) => apply(e, x ?? false)),
    );
  }

  return switch (kind) {
    'sprayline' => [
      numberField('arc', t('props.arc'), sel.whereType<SpraylineEntity>().map((e) => e.arcDeg), (e, v) => (e as SpraylineEntity).arcDeg = v.clamp(1, 360).toDouble()),
      numberField('riser', t('batch.riser'), sel.whereType<SpraylineEntity>().map((e) => e.riserHeight), (e, v) => (e as SpraylineEntity).riserHeight = v, length: true),
      numberField('depth', t('ui.depth'), sel.whereType<SpraylineEntity>().map((e) => e.depth), (e, v) => (e as SpraylineEntity).depth = v, length: true),
      numberField('offset', t('batch.firstOutlet'), sel.whereType<SpraylineEntity>().map((e) => e.offset), (e, v) => (e as SpraylineEntity).offset = v < 0 ? 0 : v, length: true),
    ],
    'tape' => [
      flag('regulated', t('batch.regulated'), sel.whereType<TapeEntity>().map((e) => e.regulated), (e, v) => (e as TapeEntity).regulated = v),
      numberField('depth', t('ui.depth'), sel.whereType<TapeEntity>().map((e) => e.depth), (e, v) => (e as TapeEntity).depth = v, length: true),
    ],
    'outlet' => [
      numberField('riser', t('batch.riser'), sel.whereType<OutletEntity>().map((e) => e.riserHeight), (e, v) => (e as OutletEntity).riserHeight = v, length: true),
      numberField('rotation', t('props.rotation'), sel.whereType<OutletEntity>().map((e) => e.orientationDeg), (e, v) => (e as OutletEntity).orientationDeg = v),
    ],
    'valve' => [numberField('depth', t('ui.depth'), sel.whereType<ControlValveEntity>().map((e) => e.depth), (e, v) => (e as ControlValveEntity).depth = v, length: true)],
    'circle' => [numberField('radius', t('batch.radius'), sel.whereType<CircleEntity>().map((e) => e.radius), (e, v) => (e as CircleEntity).radius = v, length: true, positive: true, inv: false)],
    'symbol' => [
      numberField('size', t('props.symbolSize'), sel.whereType<SymbolEntity>().map((e) => e.size), (e, v) => (e as SymbolEntity).size = v, length: true, positive: true, inv: false),
      numberField('rotation', t('props.rotation'), sel.whereType<SymbolEntity>().map((e) => e.rotationDeg), (e, v) => (e as SymbolEntity).rotationDeg = v, inv: false),
    ],
    'text' => [numberField('rotation', t('props.rotation'), sel.whereType<TextEntity>().map((e) => e.rotationDeg), (e, v) => (e as TextEntity).rotationDeg = v, inv: false)],
    'dimension' => [numberField('offset', t('props.dimOffset'), sel.whereType<DimensionEntity>().map((e) => e.offset), (e, v) => (e as DimensionEntity).offset = v, length: true, inv: false)],
    _ => const [],
  };
}

/// The settings of the CAD+ tool [tool] in the panel shown while it is
/// active (nothing selected).
List<Widget> cadPlusToolFields(ProjectController c, ToolId tool) {
  final t = c.t;
  final u = c.units;
  final s = c.cadPlus;
  void upd(VoidCallback fn) {
    fn();
    c.refresh();
  }

  return switch (tool) {
    ToolId.lengthen => [
      SpecDropdown<LengthenMode>(
        key: const Key('tool_lengthen_mode'),
        label: t('cadp.lengthenMode'),
        value: s.lengthenMode.name,
        items: LengthenMode.values,
        labelOf: (m) => t('cadp.lengthen.${m.name}'),
        idOf: (m) => m.name,
        onChanged: (v) => upd(() => s.lengthenMode = LengthenMode.values.byName(v ?? 'delta')),
      ),
      NumField(
        key: const Key('tool_lengthen_value'),
        label: s.lengthenMode == LengthenMode.percent ? '${t('cadp.lengthenValue')} (%)' : '${t('cadp.lengthenValue')} (${u.lengthLabel})',
        value: s.lengthenMode == LengthenMode.percent ? s.lengthenValue : u.lengthFromSi(s.lengthenValue),
        decimals: 3,
        onChanged: (v) => upd(() => s.lengthenValue = s.lengthenMode == LengthenMode.percent ? v : u.lengthToSi(v)),
      ),
      Text(
        lengthenValueText(c),
        key: const Key('tool_lengthen_text'),
        style: TextStyle(fontSize: 11.5, color: Cad.fg54),
      ),
    ],
    ToolId.boundary => [
      SwitchListTile(
        key: const Key('tool_boundary_area'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('cadp.boundaryAsArea'), style: const TextStyle(fontSize: 12)),
        value: s.boundaryAsArea,
        onChanged: (v) => upd(() => s.boundaryAsArea = v),
      ),
    ],
    ToolId.fieldPhoto => [Text(pendingFieldPhotos[c]?.name ?? '', style: const TextStyle(fontSize: 12))],
    _ => const [],
  };
}
