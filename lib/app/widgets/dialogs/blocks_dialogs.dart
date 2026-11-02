/// Dialogs of the user blocks: save the selection as a block (name,
/// description, base point) and insert a block of the project (preview,
/// rotation, scale, picked or typed insertion point).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/model/blocks.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../tools/insert_block_tool.dart';
import 'cad_plus_dialogs.dart' show exportBlockLibraryAction, importBlockLibraryAction;
import '../fields.dart' show ScrollBody;
import 'terrain_dialogs.dart' show dialogWidth;
import '../../theme.dart';

enum _Base { corner, center, typed }

TextField _field(TextEditingController ctl, String label, {Key? key, bool number = false, bool enabled = true}) => TextField(
  key: key,
  controller: ctl,
  enabled: enabled,
  decoration: InputDecoration(labelText: label, isDense: true),
  keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
  style: const TextStyle(fontSize: 12),
);

/// Asks the name, description and base point of a block made of the
/// selection of [c]; returns the block (not yet in [library]: hand it to
/// [BlockCommands.saveBlock]) or null. With nothing selected it only says so.
Future<BlockDefinition?> showSaveBlockDialog(BuildContext context, ProjectController c, BlockLibrary library) async {
  final t = c.t;
  final selected = [
    for (final e in c.project.entities)
      if (c.selection.contains(e.id)) e,
  ];
  if (selected.isEmpty) {
    c.notify(t('blk.empty'));
    return null;
  }
  final b = selected.fold(Bounds.empty, (a, e) => a.union(e.bounds));
  final name = TextEditingController(text: library.uniqueName(t('blk.default')));
  final desc = TextEditingController();
  final bx = TextEditingController(text: fmt(c.units.lengthFromSi(b.minX), 3)), by = TextEditingController(text: fmt(c.units.lengthFromSi(b.minY), 3));
  var base = _Base.corner;
  String? error;
  // 1.6.0 CAD: the attributes found in the selection ({TAG} texts), the
  // bill of materials, and whether a reference takes the selection's place
  final tags = [
    for (final e in selected)
      if (e is TextEntity && attributeTextPattern.hasMatch(e.text.trim())) BlockAttributeDef.tagOf(attributeTextPattern.firstMatch(e.text.trim())!.group(1)!),
  ];
  final referenceable = selected.every((e) => isReferenceable(e) || e is BlockRefEntity);
  var inBom = library.byName(name.text)?.inBom ?? false;
  var replace = false;
  return showDialog<BlockDefinition>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final exists = library.byName(name.text) != null;
        return AlertDialog(
          title: Text(t('blk.save'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 420),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('blk.count', {'n': '${selected.length}'}), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('blk_name'),
                    controller: name,
                    decoration: InputDecoration(labelText: t('blk.name'), isDense: true),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) => setState(() => error = null),
                  ),
                  if (exists)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t('blk.replace'), style: TextStyle(fontSize: 11, color: Cad.attention)),
                    ),
                  const SizedBox(height: 6),
                  _field(desc, t('blk.description'), key: const Key('blk_desc')),
                  const SizedBox(height: 10),
                  Text(t('blk.base'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 4),
                  SegmentedButton<_Base>(
                    segments: [
                      ButtonSegment(
                        value: _Base.corner,
                        label: Text(t('blk.baseCorner'), style: const TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: _Base.center,
                        label: Text(t('blk.baseCenter'), style: const TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: _Base.typed,
                        label: Text(t('blk.baseTyped'), style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {base},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => base = s.first),
                  ),
                  if (base == _Base.typed)
                    Row(
                      children: [
                        Expanded(child: _field(bx, 'X (${c.units.lengthLabel})', key: const Key('blk_bx'), number: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _field(by, 'Y (${c.units.lengthLabel})', key: const Key('blk_by'), number: true)),
                      ],
                    ),
                  // 1.6.0 CAD
                  const SizedBox(height: 6),
                  Text(
                    tags.isEmpty ? t('blkref.noTags') : t('blkref.tags', {'t': tags.join(', ')}),
                    key: const Key('blk_tags'),
                    style: TextStyle(fontSize: 11, color: Cad.fg54),
                  ),
                  CheckboxListTile(
                    key: const Key('blk_in_bom'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('blkref.countInBom'), style: const TextStyle(fontSize: 12)),
                    value: inBom,
                    onChanged: (v) => setState(() => inBom = v ?? false),
                  ),
                  if (referenceable)
                    CheckboxListTile(
                      key: const Key('blk_replace'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('blkref.replaceSelection'), style: const TextStyle(fontSize: 12)),
                      value: replace,
                      onChanged: (v) => setState(() => replace = v ?? false),
                    )
                  else
                    Text(t('blkref.copiesOnly'), key: const Key('blk_copies_only'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  if (exists && c.blockRefsOf(name.text.trim()).isNotEmpty)
                    Text(t('blkref.redefineNote', {'n': '${c.blockRefsOf(name.text.trim()).length}'}), style: TextStyle(fontSize: 11, color: Cad.attention)),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(error!, style: TextStyle(fontSize: 12, color: Cad.attention)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('blk_save_ok'),
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  setState(() => error = t('blk.nameMissing'));
                  return;
                }
                Pt at;
                switch (base) {
                  case _Base.corner:
                    at = Pt(b.minX, b.minY);
                  case _Base.center:
                    at = b.center;
                  case _Base.typed:
                    final x = parseNumber(bx.text), y = parseNumber(by.text);
                    if (x == null || y == null) {
                      setState(() => error = t('blk.invalid'));
                      return;
                    }
                    at = Pt(c.units.lengthToSi(x), c.units.lengthToSi(y));
                }
                final def = BlockDefinition.fromEntities(n, selected, at, description: desc.text.trim(), project: c.project, inBom: inBom);
                // 1.6.0 CAD: where the reference that takes the selection's place goes
                if (replace && def.canBeReferenced) _replacing[def] = at;
                Navigator.pop(ctx, def);
              },
              child: Text(t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

/// Lets the user pick a block of [library], its rotation and scale, and
/// where it goes (picked on the drawing, or typed coordinates). [onDelete]
/// removes a block (e.g. [BlockCommands.deleteBlock]); returns the request
/// or null.
Future<BlockInsertRequest?> showInsertBlockDialog(BuildContext context, ProjectController c, BlockLibrary library, {bool Function(String name)? onDelete}) {
  final t = c.t;
  var selected = library.isEmpty ? -1 : 0;
  final rot = TextEditingController(text: '0'), scale = TextEditingController(text: '1');
  final centre = c.camera.center;
  final ax = TextEditingController(text: fmt(c.units.lengthFromSi(centre.x), 3)), ay = TextEditingController(text: fmt(c.units.lengthFromSi(centre.y), 3));
  var pick = true;
  String? error;
  // 1.6.0 CAD: as a reference (a block of drawing items), and the values of its attributes
  var asReference = true;
  final values = <String, TextEditingController>{};
  TextEditingController valueOf(BlockAttributeDef a) => values.putIfAbsent(a.tag, () => TextEditingController(text: a.defaultValue));
  return showDialog<BlockInsertRequest>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final blocks = library.blocks;
        if (selected >= blocks.length) selected = blocks.length - 1;
        return AlertDialog(
          title: Text(t('blk.insert'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 460),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (blocks.isEmpty)
                    Text(
                      t('blk.none'),
                      key: const Key('blk_none'),
                      style: TextStyle(fontSize: 12, color: Cad.fg70),
                    )
                  else ...[
                    for (var i = 0; i < blocks.length; i++)
                      Material(
                        color: i == selected ? Cad.fg.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          key: Key('blk_item_$i'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() => selected = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                            child: Row(
                              children: [
                                SizedBox(width: 64, height: 44, child: CustomPaint(painter: BlockPreviewPainter(blocks[i]))),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(blocks[i].name, style: TextStyle(fontSize: 12.5, fontWeight: i == selected ? FontWeight.bold : FontWeight.w500)),
                                      Text(
                                        [
                                          if (blocks[i].description.isNotEmpty) blocks[i].description,
                                          t('blk.count', {'n': '${blocks[i].entities.length}'}),
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 11, color: Cad.fg54),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i == selected && onDelete != null)
                                  IconButton(
                                    key: const Key('blk_delete'),
                                    tooltip: t('blk.delete'),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => setState(() => onDelete(blocks[i].name)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _field(rot, t('blk.rotation'), key: const Key('blk_rot'), number: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _field(scale, t('blk.scale'), key: const Key('blk_scale'), number: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(t('blk.pick'), style: const TextStyle(fontSize: 11))),
                        ButtonSegment(value: false, label: Text(t('blk.at'), style: const TextStyle(fontSize: 11))),
                      ],
                      selected: {pick},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => pick = s.first),
                    ),
                    if (!pick)
                      Row(
                        children: [
                          Expanded(child: _field(ax, 'X (${c.units.lengthLabel})', key: const Key('blk_ax'), number: true)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(ay, 'Y (${c.units.lengthLabel})', key: const Key('blk_ay'), number: true)),
                        ],
                      ),
                    // 1.6.0 CAD
                    if (selected >= 0) ...[
                      const SizedBox(height: 8),
                      if (blocks[selected].canBeReferenced)
                        SegmentedButton<bool>(
                          key: const Key('blk_as'),
                          segments: [
                            ButtonSegment(value: true, label: Text(t('blkref.asReference'), style: const TextStyle(fontSize: 11))),
                            ButtonSegment(value: false, label: Text(t('blkref.asCopies'), style: const TextStyle(fontSize: 11))),
                          ],
                          selected: {asReference},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() => asReference = s.first),
                        )
                      else
                        Text(t('blkref.copiesOnly'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                      for (final a in blocks[selected].attributes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _field(valueOf(a), a.prompt.isEmpty || a.prompt == a.tag ? a.tag : '${a.prompt} (${a.tag})', key: Key('blk_attr_${a.tag}')),
                        ),
                    ],
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          key: const Key('blk_library_import'),
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: Text(t('blk.libraryImport'), style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await importBlockLibraryAction(c);
                            if (ctx.mounted) setState(() {});
                          },
                        ),
                        if (blocks.isNotEmpty)
                          TextButton.icon(
                            key: const Key('blk_library_export'),
                            icon: const Icon(Icons.file_download_outlined, size: 16),
                            label: Text(t('blk.libraryExport'), style: const TextStyle(fontSize: 12)),
                            onPressed: () => exportBlockLibraryAction(c),
                          ),
                      ],
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(error!, style: TextStyle(fontSize: 12, color: Cad.attention)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            if (blocks.isNotEmpty)
              FilledButton(
                key: const Key('blk_insert_ok'),
                onPressed: selected < 0
                    ? null
                    : () {
                        final r = parseNumber(rot.text), s = parseNumber(scale.text);
                        final x = parseNumber(ax.text), y = parseNumber(ay.text);
                        if (r == null || s == null || s <= 0 || (!pick && (x == null || y == null))) {
                          setState(() => error = t('blk.invalid'));
                          return;
                        }
                        final at = pick ? null : Pt(c.units.lengthToSi(x!), c.units.lengthToSi(y!));
                        Navigator.pop(
                          ctx,
                          BlockInsertRequest(
                            block: blocks[selected],
                            rotationDeg: r,
                            scale: s,
                            at: at,
                            values: {for (final a in blocks[selected].attributes) a.tag: valueOf(a).text},
                            asReference: asReference,
                          ),
                        );
                      },
                child: Text(t('blk.insert')),
              ),
          ],
        );
      },
    ),
  );
}

/// Small drawing of a block (outlines of its entities fitted to the box).
class BlockPreviewPainter extends CustomPainter {
  BlockPreviewPainter(this.block);
  final BlockDefinition block;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)), Paint()..color = Cad.inset);
    final b = block.bounds;
    if (b.isEmpty) return;
    final s = math.min((size.width - 8) / math.max(b.width, 1e-6), (size.height - 8) / math.max(b.height, 1e-6));
    Offset o(Pt p) => Offset(size.width / 2 + (p.x - b.center.x) * s, size.height / 2 - (p.y - b.center.y) * s);
    final paint = Paint()
      ..color = Cad.accentText
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var n = 0;
    for (final e in block.entities) {
      if (++n > 300) break;
      final pts = e.linearPoints;
      if (pts != null && pts.length >= 2) {
        final path = Path()..addPolygon([for (final p in pts) o(p)], e.isClosedShape);
        canvas.drawPath(path, paint);
      } else if (e is CircleEntity) {
        canvas.drawCircle(o(e.center), math.max(1, e.radius * s), paint);
      } else if (e is PointEntity) {
        canvas.drawCircle(o(e.position), 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
    }
    // base point
    final z = o(Pt.zero);
    final red = Paint()
      ..color = Cad.error
      ..strokeWidth = 1;
    canvas.drawLine(z + const Offset(-3, 0), z + const Offset(3, 0), red);
    canvas.drawLine(z + const Offset(0, -3), z + const Offset(0, 3), red);
  }

  @override
  bool shouldRepaint(covariant BlockPreviewPainter old) => !identical(old.block, block);
}

/// Edit → Save selection as block: asks the name and base point, then
/// keeps the block in [library] (the project's).
Future<void> saveBlockAction(BuildContext context, ProjectController c, BlockLibrary library) async {
  final b = await showSaveBlockDialog(context, c, library);
  if (b == null) return;
  // 1.6.0 CAD: the selection becomes a reference to the block when asked
  final at = _replacing[b];
  c.saveBlock(
    library,
    b,
    replace: at == null
        ? const []
        : [
            for (final e in c.project.entities)
              if (c.selection.contains(e.id)) e,
          ],
    at: at,
  );
}

/// 1.6.0 CAD: the base point of a block saved to replace the selection by
/// a reference to it (set by the save dialog).
final _replacing = Expando<Pt>('blockReplacing');

/// Insert → Block: asks which block, how it is turned and scaled and
/// where; a typed point inserts at once, otherwise the insert tool
/// ([pickTool], ToolId.insertBlock) places it at every click until Esc.
Future<void> insertBlockAction(BuildContext context, ProjectController c, BlockLibrary library, {required ToolId pickTool}) async {
  final r = await showInsertBlockDialog(context, c, library, onDelete: (name) => c.deleteBlock(library, name));
  if (r == null) return;
  if (r.at != null) {
    c.insertBlock(r.block, r.at!, rotationDeg: r.rotationDeg, scale: r.scale, values: r.values, asReference: r.asReference, mirrored: r.mirrored);
    return;
  }
  pendingBlockInserts[c] = r;
  c.setTool(pickTool);
}
