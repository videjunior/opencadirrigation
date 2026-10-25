/// The AI assistant as a dialog: the same conversation, data and settings
/// views as the docked panel (lib/app/widgets/ai/), in a plain [Dialog]
/// sized from the screen (no intrinsic sizing), so it works on phones as
/// well as desktops. Where the app docks the panel ([AiAssistant.dockable]),
/// [showAiAssistantDialog] opens the panel instead (a bottom sheet on
/// phones).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/advisor.dart';
import '../../ai/ai_assistant.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../advice_panel.dart' show adviceTitle;
import '../ai/ai_panel.dart';
import '../ai/ai_views.dart';

/// Opens the assistant of [c]; [prompt] prefills the question (nothing is
/// sent before the user sends it).
Future<void> showAiAssistantDialog(BuildContext context, ProjectController c, {String? prompt}) {
  final ai = AiAssistant.of(c);
  if (AiAssistant.dockable) {
    if (MediaQuery.of(context).size.width < 700) return showAiAgentSheet(context, c, prompt: prompt);
    if (prompt != null) ai.rewound = prompt;
    AiAssistant.panelOpen.value = true;
    ai.refresh();
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (_) => AiAssistantDialog(c: c, ai: ai, prompt: prompt),
  );
}

/// "Ask the AI" about a design message.
Future<void> askAiAboutAdvice(BuildContext context, ProjectController c, Advice a) => showAiAssistantDialog(context, c, prompt: c.t('ai.q.advice', {'m': adviceTitle(c, a), 'code': a.code}));

enum _View { chat, data, settings }

class AiAssistantDialog extends StatefulWidget {
  const AiAssistantDialog({super.key, required this.c, required this.ai, this.prompt});
  final ProjectController c;
  final AiAssistant ai;
  final String? prompt;

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog> {
  late final input = TextEditingController(text: widget.prompt ?? '');
  late _View view = widget.ai.hasKey ? _View.chat : _View.settings;

  ProjectController get c => widget.c;
  AiAssistant get ai => widget.ai;

  @override
  void dispose() {
    // the assistant works only while the conversation is on screen (after
    // the tree is gone: stopping notifies its listeners)
    if (ai.busy && !AiAssistant.panelOpen.value) Future.microtask(ai.stop);
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 700;
    final inset = compact ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    final width = compact ? mq.size.width - inset.horizontal : math.min(880.0, mq.size.width - inset.horizontal);
    final room = mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - inset.vertical;
    final height = math.max(260.0, compact ? room : math.min(room, 840.0));
    return Dialog(
      key: const Key('ai_dialog'),
      insetPadding: inset,
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: Listenable.merge([ai, c]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(compact),
              const Divider(height: 1),
              Expanded(
                child: switch (view) {
                  _View.chat => AiChatView(c: c, ai: ai, input: input, compact: compact, onSettings: () => setState(() => view = _View.settings)),
                  _View.data => AiDataView(c: c, ai: ai, input: input),
                  _View.settings => AiSettingsView(c: c, ai: ai, onSaved: () => setState(() => view = _View.chat)),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool compact) {
    final t = c.t;
    Widget tab(_View v, IconData icon, String label) {
      final on = view == v;
      final color = on ? Cad.accentText : Cad.fg60;
      return Tooltip(
        message: label,
        child: InkWell(
          key: Key('ai_view_${v.name}'),
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => view = v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: on ? Cad.accent : Colors.transparent, width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                if (!compact) ...[const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: color))],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 4),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 20, color: Cad.accentText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('ai.title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  aiMeterText(c, ai),
                  key: const Key('ai_meter'),
                  style: TextStyle(fontSize: 10.5, color: Cad.fg54),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          tab(_View.chat, Icons.forum_outlined, t('ai.view.chat')),
          tab(_View.data, Icons.fact_check_outlined, t('ai.view.data')),
          tab(_View.settings, Icons.settings_outlined, t('ai.view.settings')),
          IconButton(key: const Key('ai_close'), tooltip: t('close'), icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
