/// The user's marks for the AI assistant above the chat box of its panel
/// (ai_marks.dart): two buttons start the mark tools (a point at each
/// click, or a line), a chip per mark with its label and note (tap it to
/// write the note, × removes it), Clear marks, and a line on what the marks
/// are for. The marks are the tab's, not the project's: no undo step,
/// nothing saved; the assistant gets them with the next message and sees
/// them in its pictures, orange as on the drawing.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai/ai_assistant.dart';
import '../../state/ai_marks.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../tools/ai_mark_tool.dart' show aiMarkColor;
import '../dialogs/ai_assistant_dialog.dart' show showAiAssistantDialog;

class AiMarksBar extends StatelessWidget {
  const AiMarksBar({super.key, required this.c, this.input});
  final ProjectController c;

  /// The chat's input box: when marking closes the assistant's sheet (on a
  /// phone), what was typed there comes back with the assistant.
  final TextEditingController? input;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.aiMarks]),
    builder: (context, _) {
      final t = c.t;
      final marks = c.aiMarks.marks;
      return Padding(
        key: const Key('ai_marks_bar'),
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _toolButton(context, ToolId.aiMarkPoint, Icons.place_outlined, t('ai.marks.point'), t('ai.marks.pointTip')),
                _toolButton(context, ToolId.aiMarkLine, Icons.timeline, t('ai.marks.line'), t('ai.marks.lineTip')),
              ],
            ),
            if (marks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final m in marks) _chip(context, m),
                    TextButton.icon(
                      key: const Key('ai_marks_clear'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: c.aiMarks.clear,
                      icon: const Icon(Icons.layers_clear_outlined, size: 16),
                      label: Text(t('ai.marks.clear')),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                t('ai.marks.hint'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Cad.fg54),
              ),
            ),
          ],
        ),
      );
    },
  );

  /// Starts the mark tool [id], or leaves it when it is the active one.
  Widget _toolButton(BuildContext context, ToolId id, IconData icon, String label, String tip) {
    final on = c.activeTool == id;
    return Tooltip(
      message: tip,
      child: Semantics(
        selected: on,
        child: OutlinedButton.icon(
          key: Key(id == ToolId.aiMarkPoint ? 'ai_mark_point' : 'ai_mark_line'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w600 : FontWeight.normal),
            backgroundColor: on ? aiMarkColor.withValues(alpha: 0.24) : null,
            side: BorderSide(color: on ? aiMarkColor : Cad.divider, width: on ? 1.5 : 1),
          ),
          onPressed: on ? () => stopAiMarking(c) : () => startAiMarking(context, c, id, input: input),
          icon: Icon(on ? Icons.check : icon, size: 16, color: aiMarkColor),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, AiMark m) {
    final t = c.t;
    final note = m.note.trim().characters;
    return InputChip(
      key: Key('ai_mark_${m.label}'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(m.isPoint ? Icons.place : Icons.timeline, size: 15, color: aiMarkColor),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          if (note.isEmpty)
            Icon(Icons.edit_outlined, size: 12, color: Cad.fg54)
          else
            // shortened, and shorter still where the chip has less room (wide scripts)
            Flexible(
              child: Text(note.length > 24 ? '${note.take(23)}…' : '$note', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
      tooltip: t('ai.marks.edit'),
      onPressed: () => _editNote(context, m),
      onDeleted: () => c.aiMarks.remove(m.label),
      deleteButtonTooltipMessage: t('ai.marks.remove'),
    );
  }

  Future<void> _editNote(BuildContext context, AiMark m) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(c: c, mark: m),
    );
    if (note != null) c.aiMarks.setNote(m.label, note);
  }
}

/// Writes the note of a mark ("pump", "well"): pops with it, or with null.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.c, required this.mark});
  final ProjectController c;
  final AiMark mark;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final text = TextEditingController(text: widget.mark.note);

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(text.text.trim());

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    return AlertDialog(
      title: Text(t('ai.marks.note', {'l': widget.mark.label}), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const Key('ai_mark_note_field'),
          controller: text,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: t('ai.marks.noteHint'), isDense: true),
          onSubmitted: (_) => _ok(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('cancel'))),
        FilledButton(key: const Key('ai_mark_note_ok'), onPressed: _ok, child: Text(t('ok'))),
      ],
    );
  }
}

/// Starts the mark tool [id] for the assistant of [c] from its panel at
/// [context]. Where the panel covers the drawing (the assistant's bottom
/// sheet on a phone, its dialog) it closes so the drawing takes the clicks,
/// the text typed in [input] waiting in the assistant, and opens again once
/// the marking is over.
void startAiMarking(BuildContext context, ProjectController c, ToolId id, {TextEditingController? input}) {
  c.setTool(id);
  final route = ModalRoute.of(context);
  final ai = AiAssistant.of(c);
  // closing the assistant's dialog stops its work; its sheet does not
  if (route is! PopupRoute || !route.isCurrent || (ai.busy && route is! ModalBottomSheetRoute)) return;
  final draft = input?.text.trim() ?? '';
  if (draft.isNotEmpty) ai.rewound = [if ((ai.rewound ?? '').trim().isNotEmpty) ai.rewound!, draft].join('\n\n');
  final nav = Navigator.of(context);
  final home = nav.context;
  nav.pop();
  _reopenWhenDone(c, home);
}

/// Ends the marking from the panel: the tool back at Select, and the
/// assistant, open already, not opened again.
void stopAiMarking(ProjectController c) {
  _stopWatching(c);
  c.setTool(ToolId.select);
}

/// The tabs whose assistant closed for marking: the listener that opens it
/// again.
final _closedForMarking = Expando<VoidCallback>('aiMarking');

/// Opens the assistant of [c] again from [home] once the marking is over,
/// the tool back at Select (Done, Enter, Esc), unless something the user
/// opened meanwhile covers the drawing (the assistant itself). A user who
/// picks another tool went on drawing: it stays closed.
void _reopenWhenDone(ProjectController c, BuildContext home) {
  _stopWatching(c);
  void watch() {
    final tool = c.activeTool;
    if (tool.isAiMark) return;
    _stopWatching(c);
    if (tool != ToolId.select) return;
    scheduleMicrotask(() {
      if (home.mounted && !Navigator.of(home).canPop()) showAiAssistantDialog(home, c);
    });
  }

  _closedForMarking[c] = watch;
  c.addListener(watch);
}

void _stopWatching(ProjectController c) {
  final watch = _closedForMarking[c];
  if (watch == null) return;
  c.removeListener(watch);
  _closedForMarking[c] = null;
}
