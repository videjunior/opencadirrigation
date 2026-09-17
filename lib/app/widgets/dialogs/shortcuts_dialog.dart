import 'package:flutter/material.dart';

import '../../shortcuts.dart';
import '../../state/controller.dart';
import '../fields.dart';

/// Help → Keyboard shortcuts: keys and command aliases, grouped.
Future<void> showShortcutsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('sc.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('sc.intro'), style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35)),
            const SizedBox(height: 8),
            Expanded(
              child: ScrollBody(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final g in shortcutGroups)
                      SizedBox(
                        width: 330,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t(g.titleKey).toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1, color: Colors.white54, fontWeight: FontWeight.bold))),
                            for (final (keys, label) in g.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 150, child: Text(keys, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF90CAF9)))),
                                    Expanded(child: Text(t(label), style: const TextStyle(fontSize: 11.5))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
    ),
  );
}
