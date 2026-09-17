import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../state/controller.dart';

/// Layer list: visibility, lock, colour, current layer, add / rename / delete.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key, required this.c});
  final ProjectController c;

  static const palette = <int>[
    0xFFB0BEC5, 0xFFECEFF1, 0xFFFF5252, 0xFFFFA726, 0xFFFFEB3B, 0xFF66BB6A, 0xFF26C6DA, 0xFF42A5F5, 0xFF1E88E5, 0xFF7E57C2, 0xFFE040FB, 0xFF8D6E63, 0xFF78909C, 0xFFAED581, 0xFFFFFFFF, 0xFF9E9E9E,
  ];

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final counts = <String, int>{};
    for (final e in c.project.entities) {
      counts[e.layer] = (counts[e.layer] ?? 0) + 1;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(children: [
            Expanded(child: Text(t('layer.hint'), style: const TextStyle(fontSize: 10, color: Colors.white38))),
            IconButton(key: const Key('layer_add'), tooltip: t('layer.add'), icon: const Icon(Icons.add, size: 16), onPressed: () => _addLayer(context)),
          ]),
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
                    padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(c.project.currentLayer == l.name ? Icons.radio_button_checked : Icons.radio_button_off, size: 12, color: c.project.currentLayer == l.name ? const Color(0xFF42A5F5) : Colors.white24),
                        const SizedBox(width: 4),
                        InkWell(
                          key: Key('layer_vis_${l.name}'),
                          onTap: () => c.toggleLayer(l.name),
                          child: Icon(l.visible ? Icons.visibility : Icons.visibility_off, size: 14, color: l.visible ? Colors.white70 : Colors.white24),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          key: Key('layer_lock_${l.name}'),
                          onTap: () => c.setLayerLocked(l.name, !l.locked),
                          child: Icon(l.locked ? Icons.lock : Icons.lock_open, size: 13, color: l.locked ? Colors.amber : Colors.white24),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          key: Key('layer_color_${l.name}'),
                          onTap: () => _pickColor(context, l.name, l.color),
                          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(l.color), borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.white24))),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(t.has('layer.${l.name}') ? '${t('layer.${l.name}')} · ${l.name}' : l.name, style: TextStyle(fontSize: 11, color: l.visible ? Colors.white : Colors.white38), overflow: TextOverflow.ellipsis)),
                        Text('${counts[l.name] ?? 0}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                        if (!Layers.all.contains(l.name))
                          InkWell(
                            key: Key('layer_del_${l.name}'),
                            onTap: () => c.removeLayer(l.name),
                            child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.close, size: 12, color: Colors.white38)),
                          ),
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
        content: SizedBox(width: 320, child: TextField(key: const Key('layer_name'), controller: ctl, autofocus: true, decoration: InputDecoration(labelText: c.t('layer.name'), isDense: true), onSubmitted: (v) => Navigator.pop(ctx, v))),
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
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final col in palette)
              InkWell(
                key: Key('color_${col.toRadixString(16)}'),
                onTap: () => Navigator.pop(ctx, col),
                child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Color(col), borderRadius: BorderRadius.circular(4), border: Border.all(color: col == current ? Colors.white : Colors.white24, width: col == current ? 2 : 1))),
              ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel')))],
      ),
    );
    if (picked != null) c.setLayerColor(layer, picked);
  }
}
