/// The messages the program showed lately: the floating notices vanish in
/// a few seconds, so each one is also kept here, with its time and tab, and
/// Help → Recent messages (or "Messages" on a notice) shows them again.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/controller.dart';
import '../theme.dart';
import 'fields.dart' show localizeUi;

/// One message shown to the user.
class LoggedMessage {
  const LoggedMessage(this.time, this.tab, this.text);
  final DateTime time;

  /// Name of the project tab it came from.
  final String tab;
  final String text;
}

/// How many messages are kept (the oldest go first).
const messageLogLimit = 200;

/// The messages of this session, oldest first.
final List<LoggedMessage> messageLog = [];

/// Keeps [text], shown by the tab named [tab].
void logMessage(String tab, String text) {
  messageLog.add(LoggedMessage(DateTime.now(), tab, text));
  if (messageLog.length > messageLogLimit) messageLog.removeRange(0, messageLog.length - messageLogLimit);
}

String _hhmmss(DateTime t) => [t.hour, t.minute, t.second].map((v) => v.toString().padLeft(2, '0')).join(':');

/// The messages of this session, newest first, to read again or copy.
Future<void> showMessageLogDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final items = messageLog.reversed.toList();
      return AlertDialog(
        key: const Key('message_log'),
        title: Text(t('ui.messages'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: size.width < 700 ? size.width - 48 : 600,
          height: (size.height * 0.6).clamp(160.0, 480.0),
          child: items.isEmpty
              ? Center(
                  child: Text(t('ui.noMessages'), style: TextStyle(color: Cad.fg54)),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: Cad.fg12),
                  itemBuilder: (_, i) {
                    final m = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(localizeUi(m.text), style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text('${_hhmmss(m.time)} · ${m.tab}', style: TextStyle(fontSize: 11, color: Cad.fg54)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              key: const Key('message_log_copy'),
              onPressed: () => Clipboard.setData(ClipboardData(text: [for (final m in items) '${_hhmmss(m.time)} [${m.tab}] ${m.text}'].join('\n'))),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: Text(t('ui.copyAll')),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
        ],
      );
    },
  );
}
