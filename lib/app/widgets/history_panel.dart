import 'package:flutter/material.dart';

import '../state/controller.dart';

/// Photoshop-style history: every action since the file was opened, the
/// current state highlighted, undone actions dimmed. Clicking a row jumps
/// back (or forward) to that state; a new edit discards the rows after it.
class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key, required this.c});
  final ProjectController c;

  static IconData iconFor(String key) => switch (key) {
    'hist.start' => Icons.flag_outlined,
    'hist.add' => Icons.add_circle_outline,
    'hist.addMany' => Icons.playlist_add,
    'hist.delete' => Icons.delete_outline,
    'hist.move' => Icons.open_with,
    'hist.rotate' => Icons.rotate_right,
    'hist.scale' => Icons.open_in_full,
    'hist.mirror' => Icons.flip,
    'hist.transform' => Icons.transform,
    'hist.copy' => Icons.copy_outlined,
    'hist.array' => Icons.grid_view,
    'hist.block' => Icons.grid_on,
    'hist.grid' => Icons.apps,
    'hist.props' => Icons.tune,
    'hist.import' => Icons.upload_file,
    'hist.design' => Icons.play_arrow,
    'hist.contours' => Icons.gesture,
    'hist.dem' => Icons.cloud_download_outlined,
    'hist.paste' => Icons.content_paste,
    'hist.elevation' => Icons.landscape_outlined,
    'hist.align' => Icons.control_camera,
    'hist.layer' => Icons.layers_outlined,
    _ => Icons.edit_outlined,
  };

  /// Translated row text for a `hist.*|argument` label.
  static String labelText(ProjectController c, String label) {
    final i = label.indexOf('|');
    final key = i < 0 ? label : label.substring(0, i);
    final arg = i < 0 ? '' : label.substring(i + 1);
    final t = c.t;
    if (arg.isEmpty) return t(key);
    // argument: a tool key (entity kind) or a count
    final n = t.has('tool.$arg') ? t('tool.$arg') : arg;
    return t(key, {'n': n});
  }

  static String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final entries = c.historyEntries;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
        child: Row(children: [
          Expanded(child: Text(t('hist.hint'), style: const TextStyle(fontSize: 10, color: Colors.white38), maxLines: 3)),
          IconButton(key: const Key('hist_undo'), tooltip: t('edit.undo'), icon: const Icon(Icons.undo, size: 16), onPressed: c.canUndo ? c.undo : null),
          IconButton(key: const Key('hist_redo'), tooltip: t('edit.redo'), icon: const Icon(Icons.redo, size: 16), onPressed: c.canRedo ? c.redo : null),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          key: const Key('hist_list'),
          padding: const EdgeInsets.all(4),
          itemCount: entries.length,
          itemBuilder: (ctx, i) {
            final e = entries[i];
            final color = e.current ? Colors.white : (e.future ? Colors.white30 : Colors.white70);
            return InkWell(
              key: Key('hist_row_${e.index}'),
              onTap: e.current ? null : () => c.jumpToHistory(e.index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: BoxDecoration(color: e.current ? const Color(0xFF2E7DD1).withValues(alpha: 0.35) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                child: Row(children: [
                  Icon(iconFor(e.label.split('|').first), size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(labelText(c, e.label), style: TextStyle(fontSize: 11.5, color: color, fontStyle: e.future ? FontStyle.italic : FontStyle.normal), overflow: TextOverflow.ellipsis)),
                  Text(_time(e.time), style: TextStyle(fontSize: 9.5, color: e.future ? Colors.white24 : Colors.white38)),
                  if (e.current) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_left, size: 12, color: Color(0xFF90CAF9))),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
