/// The conversations of a project kept in this browser: the list (the
/// latest first, by their first message), a new conversation that leaves the
/// one on screen in the list, opening or deleting one, and a conversation
/// exported to a file (for another browser or device, or a report of a
/// problem: no API key, no photo of the user's) or brought in from one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ai/ai_assistant.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';

/// [d] as 2026-11-02 14:05.
String _when(DateTime d) {
  String two(int v) => '$v'.padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// Saves the conversation on screen as a file and says so.
Future<void> aiExportConversation(ProjectController c, AiAssistant ai) async {
  final ok = await ai.saveConversationFile();
  c.notify(c.t(ok ? 'ai.conv.exported' : 'ai.conv.exportNone'));
}

/// Asks for a conversation file and brings it in as a new conversation of
/// the project; true when it went in.
Future<bool> aiImportConversation(ProjectController c, AiAssistant ai) async {
  final f = await openTextFile(accept: '.json');
  if (f == null) return false;
  final problem = ai.importConversation(f.$2, name: f.$1);
  c.notify(problem ?? c.t('ai.conv.importedShort'));
  return problem == null;
}

/// The list of the project's conversations, with what can be done to them.
Future<void> showAiConversations(BuildContext context, ProjectController c, AiAssistant ai) => showDialog<void>(
  context: context,
  builder: (ctx) => _Conversations(c: c, ai: ai),
);

class _Conversations extends StatefulWidget {
  const _Conversations({required this.c, required this.ai});
  final ProjectController c;
  final AiAssistant ai;

  @override
  State<_Conversations> createState() => _ConversationsState();
}

class _ConversationsState extends State<_Conversations> {
  late Future<List<AiConversationInfo>> list = widget.ai.projectConversations();

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;

  // a block, not an arrow: the callback of setState may not return the future
  void _reload() => setState(() {
    list = ai.projectConversations();
  });

  Future<void> _delete(AiConversationInfo x) async {
    final t = c.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('ai.conv.delete'), style: const TextStyle(fontSize: 15)),
        content: Text(t('ai.conv.deleteConfirm', {'n': x.title.isEmpty ? t('ai.conv.untitled') : x.title}), style: const TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t('cancel'))),
          FilledButton(key: const Key('ai_conv_delete_ok'), onPressed: () => Navigator.pop(d, true), child: Text(t('ai.conv.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await ai.deleteConversation(x.key);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final width = math.min(MediaQuery.sizeOf(context).width - 32, 520.0);
    final busy = ai.busy;
    return AlertDialog(
      key: const Key('ai_conversations_dialog'),
      title: Text(t('ai.conv.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t(ai.keepsConversations ? 'ai.conv.hint' : 'ai.conv.notKept'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<AiConversationInfo>>(
                future: list,
                builder: (context, snap) {
                  final items = snap.data;
                  if (items == null) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  if (items.isEmpty) {
                    return Text(
                      t('ai.conv.none'),
                      key: const Key('ai_conv_none'),
                      style: TextStyle(fontSize: 12, color: Cad.fg54),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (k, x) in items.indexed)
                        ListTile(
                          key: Key('ai_conv_$k'),
                          dense: true,
                          contentPadding: const EdgeInsetsDirectional.only(start: 4),
                          selected: x.current,
                          leading: Icon(x.current ? Icons.chat_bubble : Icons.chat_bubble_outline, size: 18),
                          title: Text(x.title.isEmpty ? t('ai.conv.untitled') : x.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                          subtitle: Text([_when(x.saved), if (x.current) t('ai.conv.current')].join(' · '), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                          onTap: x.current || busy
                              ? null
                              : () async {
                                  final ok = await ai.openConversation(x.key);
                                  if (!context.mounted) return;
                                  if (ok) {
                                    Navigator.of(context).pop();
                                  } else {
                                    c.notify(t('ai.conv.openFailed'));
                                  }
                                },
                          trailing: IconButton(
                            key: Key('ai_conv_delete_$k'),
                            tooltip: t('ai.conv.delete'),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: busy ? null : () => _delete(x),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: const Key('ai_conv_import'),
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await aiImportConversation(c, ai);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.file_open_outlined, size: 16),
              label: Text(t('ai.conv.import')),
            ),
            TextButton.icon(
              key: const Key('ai_conv_export'),
              onPressed: busy || !ai.items.any((it) => it.kind != AiItemKind.notice) ? null : () => aiExportConversation(c, ai),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: Text(t('ai.conv.export')),
            ),
            FilledButton.icon(
              key: const Key('ai_conv_new'),
              onPressed: busy
                  ? null
                  : () {
                      ai.newConversation();
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.add_comment_outlined, size: 16),
              label: Text(t('ai.new')),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('close'))),
          ],
        ),
      ],
    );
  }
}
