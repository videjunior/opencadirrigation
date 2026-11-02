/// The docked AI agent panel: beside the drawing on wide screens and in a
/// bottom sheet on phones, it stays open while the agent works so the user
/// watches the drawing change, types more instructions (they reach the
/// agent at its next step) and stops it at any time. It shows the active
/// tab's assistant; the conversation of each tab is its own. Files dropped
/// on it are attached to the conversation (ai_drop.dart).
library;

import 'package:flutter/material.dart';

import '../../ai/ai_assistant.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../layout_mode.dart';
import 'ai_drop.dart';
import 'ai_views.dart';

enum AiPanelView { chat, data, settings }

/// Default width of the docked panel.
const aiPanelWidth = 400.0;

class AiAgentPanel extends StatefulWidget {
  const AiAgentPanel({super.key, required this.c, this.onClose, this.prompt, this.onShowTab});
  final ProjectController c;

  /// Closes the panel (null: no close button).
  final VoidCallback? onClose;

  /// The assistant shown works (or waits) in another tab than the visible
  /// one: a bar says so, and this shows that tab.
  final VoidCallback? onShowTab;

  /// Fills the input box (nothing is sent before the user sends it).
  final String? prompt;

  @override
  State<AiAgentPanel> createState() => _AiAgentPanelState();
}

class _AiAgentPanelState extends State<AiAgentPanel> {
  late final input = TextEditingController(text: widget.prompt ?? '');
  late AiPanelView view = AiAssistant.of(widget.c).hasKey ? AiPanelView.chat : AiPanelView.settings;

  ProjectController get c => widget.c;
  AiAssistant get ai => AiAssistant.of(c);

  @override
  void didUpdateWidget(AiAgentPanel old) {
    super.didUpdateWidget(old);
    if (widget.prompt != null && widget.prompt != old.prompt) input.text = widget.prompt!;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _newConversation() async {
    if (await aiConfirmNew(context, c, ai)) ai.clear();
  }

  @override
  Widget build(BuildContext context) => AiDropZone(
    c: c,
    ai: ai,
    // dropped files show in the conversation
    onAttached: () => setState(() => view = AiPanelView.chat),
    child: _panel(),
  );

  Widget _panel() => Material(
    key: const Key('ai_panel'),
    color: Cad.dialog,
    child: AnimatedBuilder(
      animation: Listenable.merge([ai, c]),
      builder: (context, _) {
        final compact = MediaQuery.of(context).size.width < 700;
        // a request arrived (Ask the AI, the start-up question): show the conversation
        if (ai.rewound != null && view != AiPanelView.chat && ai.hasKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => view = AiPanelView.chat);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const Divider(height: 1),
            if (widget.onShowTab != null)
              Container(
                key: const Key('ai_other_tab'),
                color: Cad.tintInfo,
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(ai.waiting ? Icons.pan_tool_outlined : Icons.sync, size: 15, color: ai.waiting ? Cad.warning : Cad.accentText),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.t(ai.waiting ? 'ai.tab.waiting' : 'ai.tab.working', {'n': c.project.meta.name}), style: const TextStyle(fontSize: 11.5))),
                    TextButton(key: const Key('ai_other_tab_show'), onPressed: widget.onShowTab, child: Text(c.t('ai.tab.show'))),
                  ],
                ),
              ),
            Expanded(
              child: switch (view) {
                AiPanelView.chat => AiChatView(c: c, ai: ai, input: input, compact: true, onSettings: () => setState(() => view = AiPanelView.settings)),
                AiPanelView.data => AiDataView(c: c, ai: ai, input: input),
                AiPanelView.settings => AiSettingsView(c: c, ai: ai, onSaved: () => setState(() => view = AiPanelView.chat)),
              },
            ),
            if (compact) SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : MediaQuery.of(context).padding.bottom),
          ],
        );
      },
    ),
  );

  Widget _header() {
    final t = c.t;
    Widget tab(AiPanelView v, IconData icon, String label) => IconButton(
      key: Key('ai_view_${v.name}'),
      tooltip: label,
      visualDensity: VisualDensity.compact,
      isSelected: view == v,
      color: view == v ? Cad.accentText : Cad.fg60,
      icon: Icon(icon, size: 18),
      onPressed: () => setState(() => view = v),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 2),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 19, color: Cad.accentText),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('ai.title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
          tab(AiPanelView.chat, Icons.forum_outlined, t('ai.view.chat')),
          tab(AiPanelView.data, Icons.fact_check_outlined, t('ai.view.data')),
          tab(AiPanelView.settings, Icons.settings_outlined, t('ai.view.settings')),
          IconButton(
            key: const Key('ai_new'),
            tooltip: t('ai.new'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            onPressed: ai.items.isEmpty ? null : _newConversation,
          ),
          if (widget.onClose != null)
            IconButton(key: const Key('ai_panel_close'), tooltip: t('close'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose),
        ],
      ),
    );
  }
}

/// The panel as a bottom sheet (phones): the drawing stays visible above.
Future<void> showAiAgentSheet(BuildContext context, ProjectController c, {String? prompt}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  barrierColor: Colors.black12,
  showDragHandle: true,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
    child: SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.62,
      child: AiAgentPanel(c: c, prompt: prompt, onClose: () => Navigator.of(ctx).pop()),
    ),
  ),
);

/// A button that shows or hides the docked panel (for the status bar or a
/// toolbar); it spins while the assistant of [c] works.
class AiPanelButton extends StatelessWidget {
  const AiPanelButton({super.key, required this.c, this.size = 18, this.onPressed});
  final ProjectController c;
  final double size;

  /// What a tap does (null: show or hide the docked panel).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AiAssistant.panelOpen,
    builder: (context, open, _) => AnimatedBuilder(
      animation: AiAssistant.of(c),
      builder: (context, _) {
        final ai = AiAssistant.of(c);
        final busy = ai.busy;
        return IconButton(
          key: const Key('ai_panel_button'),
          tooltip: ai.waiting ? c.t('ai.panel.waiting') : c.t(open ? 'ai.panel.hide' : 'ai.panel.show'),
          // (48 px for a finger, compact for a mouse)
          visualDensity: touchInput ? VisualDensity.standard : VisualDensity.compact,
          isSelected: onPressed == null && open,
          color: onPressed == null && open ? Cad.accentText : Cad.fg60,
          onPressed: onPressed ?? AiAssistant.togglePanel,
          icon: Badge(
            // the task waits for an approval, an answer or a plan decision
            isLabelVisible: ai.waiting,
            smallSize: 8,
            backgroundColor: Cad.warning,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.smart_toy_outlined, size: size),
                if (busy) SizedBox(width: size + 8, height: size + 8, child: const CircularProgressIndicator(strokeWidth: 1.5)),
              ],
            ),
          ),
        );
      },
    ),
  );
}
