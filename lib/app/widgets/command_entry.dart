/// The command line for a finger: what a keyboard types into the status bar
/// — a command alias (L, PL, MP, ROTATE…), a point (`x,y`, `@dx,dy`,
/// `@d<a`) or a distance along the rubber band — typed in a field that opens
/// the on-screen keyboard. The numeric keyboard of phones has no `@`, `<`,
/// `,` or `;` (the iPhone's not even a minus), so they have keys of their
/// own; "ABC" switches to the letters for the aliases.
library;

import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../theme.dart';

class CommandEntry extends StatefulWidget {
  const CommandEntry({super.key, required this.c, required this.onRun, required this.onClose});
  final ProjectController c;

  /// Runs the text as the keyboard's command line would (Enter).
  final ValueChanged<String> onRun;
  final VoidCallback onClose;

  /// The keys the numeric keyboard lacks.
  static const punctuation = ['@', '<', ',', ';', '-', '.'];

  @override
  State<CommandEntry> createState() => _CommandEntryState();
}

class _CommandEntryState extends State<CommandEntry> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _letters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _insert(String s) {
    final v = _text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    _text.value = TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, s),
      selection: TextSelection.collapsed(offset: sel.start + s.length),
    );
    _focus.requestFocus();
  }

  void _run() {
    final s = _text.text.trim();
    _text.clear();
    if (s.isNotEmpty) widget.onRun(s);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    Widget key(String label, VoidCallback onTap, {Key? k, String? tip}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tip ?? label,
        child: Material(
          color: Cad.cardHigh,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            key: k,
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Material(
      key: const Key('command_entry'),
      color: Cad.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('command_entry_field'),
                    controller: _text,
                    focusNode: _focus,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: _letters ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textInputAction: TextInputAction.go,
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    decoration: InputDecoration(isDense: true, labelText: t('status.command'), hintText: t('cmd.hint')),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                IconButton(key: const Key('command_entry_run'), tooltip: t('cmd.run'), icon: const Icon(Icons.keyboard_return), onPressed: _run),
                IconButton(key: const Key('command_entry_close'), tooltip: t('close'), icon: const Icon(Icons.close), onPressed: widget.onClose),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in CommandEntry.punctuation) key(p, () => _insert(p), k: Key('command_key_$p')),
                  key(
                    _letters ? '123' : 'ABC',
                    () {
                      setState(() => _letters = !_letters);
                      // the platform keyboard follows the new type when the field is focused again
                      _focus.unfocus();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _focus.requestFocus();
                      });
                    },
                    k: const Key('command_key_letters'),
                    tip: t(_letters ? 'cmd.digits' : 'cmd.letters'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
