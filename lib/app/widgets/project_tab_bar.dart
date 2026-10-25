import 'package:flutter/material.dart';

import '../state/workspace.dart';
import '../theme.dart';

/// Row of open project tabs under the menu bar.
class ProjectTabBar extends StatelessWidget {
  const ProjectTabBar({super.key, required this.ws, required this.onClose, required this.onAdd});
  final Workspace ws;
  final void Function(int index) onClose;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = ws.current.t;
    return Container(
      height: 28,
      color: Cad.panelAlt,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < ws.tabs.length; i++) _tab(context, i, t),
                ],
              ),
            ),
          ),
          Tooltip(
            message: t('tab.new'),
            child: InkWell(
              key: const Key('tab_add'),
              onTap: onAdd,
              child: SizedBox(width: 30, height: 28, child: Icon(Icons.add, size: 16, color: Cad.fg70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int i, dynamic t) {
    final c = ws.tabs[i];
    final active = i == ws.active;
    final name = c.project.meta.name.trim().isEmpty ? c.t('name.newProject') : c.project.meta.name;
    return InkWell(
      key: Key('tab_$i'),
      onTap: () => ws.select(i),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: active ? Cad.panel : Colors.transparent,
          border: Border(bottom: BorderSide(color: active ? Cad.accent : Colors.transparent, width: 2), right: BorderSide(color: Cad.divider)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text('${c.dirty ? '• ' : ''}$name', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: active ? Cad.fg : Cad.fg60))),
            const SizedBox(width: 4),
            Tooltip(
              message: c.t('tab.close'),
              child: InkWell(
                key: Key('tab_close_$i'),
                onTap: () => onClose(i),
                child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 12, color: Cad.fg54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
