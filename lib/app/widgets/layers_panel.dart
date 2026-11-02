import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/edit_commands.dart';
import 'layout_mode.dart';

/// Layer list: visibility, lock, colour, current layer, add / rename / delete.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key, required this.c});
  final ProjectController c;

  static const palette = <int>[
    0xFFB0BEC5,
    0xFFECEFF1,
    0xFFFF5252,
    0xFFFFA726,
    0xFFFFEB3B,
    0xFF66BB6A,
    0xFF26C6DA,
    0xFF42A5F5,
    0xFF1E88E5,
    0xFF7E57C2,
    0xFFE040FB,
    0xFF8D6E63,
    0xFF78909C,
    0xFFAED581,
    0xFFFFFFFF,
    0xFF9E9E9E,
  ];

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final counts = c.layerCounts;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(t('layer.hint'), style: TextStyle(fontSize: 10, color: Cad.fg54)),
              ),
              IconButton(key: const Key('layer_add'), tooltip: t('layer.add'), icon: const Icon(Icons.add, size: 16), onPressed: () => _addLayer(context)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(4),
            children: [
              for (final l in c.project.layers)
                InkWell(
                  key: Key('layer_row_${l.name}'),
                  onTap: () => c.setCurrentLayer(l.name),
                  onDoubleTap: () => _renameLayer(context, l.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: [
                        Semantics(
                          selected: c.project.currentLayer == l.name,
                          label: t('layer.current'),
                          child: Icon(
                            c.project.currentLayer == l.name ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 12,
                            color: c.project.currentLayer == l.name ? Cad.accent : Cad.fg54,
                          ),
                        ),
                        // targets a finger can hit, each saying what it does and to which layer
                        _iconButton(
                          Key('layer_vis_${l.name}'),
                          t('layer.toggleVis', {'l': l.name}),
                          l.visible ? Icons.visibility : Icons.visibility_off,
                          l.visible ? Cad.fg70 : Cad.fg54,
                          () => c.toggleLayer(l.name),
                          toggled: l.visible,
                        ),
                        _iconButton(
                          Key('layer_lock_${l.name}'),
                          t('layer.toggleLock', {'l': l.name}),
                          l.locked ? Icons.lock : Icons.lock_open,
                          l.locked ? Cad.amber : Cad.fg54,
                          () => c.setLayerLocked(l.name, !l.locked),
                          toggled: l.locked,
                        ),
                        _target(
                          Key('layer_color_${l.name}'),
                          t('layer.colorOf', {'l': l.name}),
                          () => _pickColor(context, l.name, l.color),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Color(l.color),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: Cad.fg54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            t.has('layer.${l.name}') ? '${t('layer.${l.name}')} · ${l.name}' : l.name,
                            style: TextStyle(fontSize: 11, color: l.visible ? Cad.fg : Cad.fg54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 1.6.0 EDT: select the items of the layer (CAD-25)
                        _iconButton(Key('layer_select_${l.name}'), t('sel.onLayer'), Icons.select_all, Cad.fg54, () => c.selectOnLayer(l.name)),
                        Text('${counts[l.name] ?? 0}', style: TextStyle(fontSize: 10, color: Cad.fg54)),
                        if (!Layers.all.contains(l.name)) _iconButton(Key('layer_del_${l.name}'), t('layer.remove', {'l': l.name}), Icons.close, Cad.fg54, () => c.removeLayer(l.name)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// A tap target of at least 40 px (48 with a finger) with [tip] as its
  /// tooltip and its name for screen readers.
  static Widget _target(Key key, String tip, VoidCallback onTap, Widget child, {bool? toggled}) {
    final size = touchInput ? 48.0 : 40.0;
    return Semantics(
      button: true,
      toggled: toggled,
      label: tip,
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        child: InkWell(
          key: key,
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  static Widget _iconButton(Key key, String tip, IconData icon, Color color, VoidCallback onTap, {bool? toggled}) => _target(key, tip, onTap, Icon(icon, size: 16, color: color), toggled: toggled);

  Future<void> _addLayer(BuildContext context) async {
    final name = await _askName(context, c.t('layer.add'), '');
    if (name == null || name.trim().isEmpty) return;
    if (!c.addLayer(name)) c.notify(c.t('layer.exists'));
  }

  Future<void> _renameLayer(BuildContext context, String from) async {
    if (Layers.all.contains(from)) return; // default layers keep their keys
    final name = await _askName(context, c.t('layer.rename'), from);
    if (name == null || name.trim().isEmpty || name == from) return;
    if (!c.renameLayer(from, name)) c.notify(c.t('layer.exists'));
  }

  Future<String?> _askName(BuildContext context, String title, String initial) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 320,
          child: TextField(
            key: const Key('layer_name'),
            controller: ctl,
            autofocus: true,
            decoration: InputDecoration(labelText: c.t('layer.name'), isDense: true),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text(c.t('ok'))),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, String layer, int current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.t('layer.color'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 260,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final col in palette)
                InkWell(
                  key: Key('color_${col.toRadixString(16)}'),
                  onTap: () => Navigator.pop(ctx, col),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Color(col),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: col == current ? Cad.fg : Cad.fg24, width: col == current ? 2 : 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel')))],
      ),
    );
    if (picked != null) c.setLayerColor(layer, picked);
  }
}
