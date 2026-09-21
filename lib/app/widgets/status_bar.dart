import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../shortcuts.dart';
import '../tutorial/tutorial.dart';
import '../version.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.c, required this.status, required this.hint});
  final ProjectController c;
  final String status;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    Widget toggle(String label, bool on, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: on ? const Color(0xFF2E7DD1) : Colors.transparent, borderRadius: BorderRadius.circular(3)),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
    return Container(
      height: 24,
      color: const Color(0xFF1B1F24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(hint, style: const TextStyle(fontSize: 11, color: Colors.white60), overflow: TextOverflow.ellipsis)),
          if (c.command.isNotEmpty) ...[
            Container(
              key: const Key('command_line'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF42A5F5)), borderRadius: BorderRadius.circular(3)),
              child: Text('${t('status.command')}: ${c.command}_${commandTargetLabel(t, c.command)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF90CAF9))),
            ),
            const SizedBox(width: 12),
          ],
          Text(status, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          if (c.angleLockActive) ...[
            Container(
              key: const Key('angle_lock'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF42A5F5).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)),
              child: const Text('⇧ 45°', style: TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
            ),
            const SizedBox(width: 12),
          ],
          Row(key: TutorialTargets.statusToggles, mainAxisSize: MainAxisSize.min, children: [
          toggle('${t('status.snap')} F3', c.snap.enabled, () {
            c.snap.enabled = !c.snap.enabled;
            c.refresh();
          }),
          toggle('${t('status.grid')} F9', c.snap.grid, () {
            c.snap.grid = !c.snap.grid;
            c.refresh();
          }),
          toggle('${t('status.ortho')} F8', c.snap.ortho, () {
            c.snap.ortho = !c.snap.ortho;
            c.refresh();
          }),
          Tooltip(
            message: t('status.keepLinksTip'),
            child: toggle(t('status.keepLinks'), c.toolSettings.keepConnections, () {
              c.toolSettings.keepConnections = !c.toolSettings.keepConnections;
              c.refresh();
            }),
          ),
          ]),
          const SizedBox(width: 8),
          Text('${c.project.entities.length} ent.  1:${(1 / c.camera.scale * 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(width: 12),
          Tooltip(
            message: '$appName ${t('about.version', {'v': appVersionLabel})}',
            child: Text('v$appVersionFull', key: const Key('status_version'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}
