/// Files into the AI chat without the paperclip: dragged onto the window
/// and dropped (on the AI panel, or anywhere while it is open), or pasted
/// into the chat box (a screenshot, files copied in the file manager). The
/// same checks as the paperclip's apply ([aiAttachFiles]). One router for
/// the app ([AiFileDrop.instance]): the shell installs it on the window, the
/// panel on screen registers as the place for drops ([AiDropZone], which
/// also shows the highlight while files are dragged over it) and its chat
/// box as the place for pastes.
library;

import 'package:flutter/material.dart';

import '../../ai/ai_assistant.dart';
import '../../io/file_drop.dart';
import '../../state/controller.dart';
import '../../theme.dart';

/// Attaches [files] to the message being written, as the paperclip does: a
/// file the assistant reads (picture, PDF, text) of up to 20 MB, or a
/// drawing to import of up to 60 MB, known by its name. The ones refused
/// get one notice (naming them when there were several), the others are
/// attached all the same; nothing is attached while the assistant works.
/// Notices go to [c]. Returns how many were attached.
Future<int> aiAttachFiles(ProjectController c, AiAssistant ai, List<DroppedFile> files) async {
  if (files.isEmpty) return 0;
  if (ai.busy) {
    c.notify(c.t('ai.attach.busy'));
    return 0;
  }
  final refused = <String>[];
  var added = 0;
  for (final f in files) {
    final mime = AiAttachment.mimeOf(f.name);
    // a file that cannot go is never read, however large
    final bytes = mime == null || f.size > AiAttachment.maxImportBytes ? null : await f.read();
    final a = bytes == null ? null : AiAttachment(f.name, mime!, bytes);
    if (a == null || a.bytes.length > a.limit) {
      refused.add(f.name);
      continue;
    }
    // the task started while the files were read
    if (ai.busy) {
      c.notify(c.t('ai.attach.busy'));
      return added;
    }
    ai.addAttachment(a);
    added++;
  }
  if (refused.isNotEmpty) c.notify(files.length == 1 ? c.t('ai.attach.bad') : '${refused.join(', ')}: ${c.t('ai.attach.bad')}');
  return added;
}

/// A place in the AI panel that takes files.
abstract interface class AiFileTarget {
  /// Attaches [files] to the conversation it shows.
  Future<void> take(List<DroppedFile> files);
}

/// The AI panel: takes files dropped on it.
abstract interface class AiDropTarget implements AiFileTarget {
  /// Where it is on screen (logical pixels); null when not laid out.
  Rect? get rect;
}

/// The chat box: takes files pasted while it has the cursor.
abstract interface class AiPasteTarget implements AiFileTarget {
  bool get focused;
}

/// Routes the window's file drags, drops and pastes to the AI panel on
/// screen. The shell installs it once ([install]); the panel and its chat
/// box register while they are mounted, so a closed panel, or the panel of
/// a tab no longer shown, holds nothing. Tests drive it with fake events
/// ([dragAt], [dropped], [pasted]).
class AiFileDrop implements FileDropSink {
  AiFileDrop._();

  /// The app's: there is one panel on screen at a time.
  static final instance = AiFileDrop._();

  ProjectController Function()? _active;
  void Function()? _stop;
  final List<AiDropTarget> _panels = [];
  final List<AiPasteTarget> _boxes = [];
  int _pasted = 0;

  /// The panel files are dragged over (it shows the drop highlight).
  final over = ValueNotifier<AiDropTarget?>(null);

  /// Starts taking the window's file drags, drops and pastes (the browser's
  /// listeners are installed once); [active] is the tab on screen, which
  /// shows the notices.
  void install(ProjectController Function() active) {
    _active = active;
    _stop ??= watchFileDrops(this);
  }

  /// Removes the listeners.
  void uninstall() {
    _stop?.call();
    _stop = null;
    _active = null;
    over.value = null;
  }

  /// The tab whose notices are on screen: the active one (a panel may show
  /// the assistant of a tab that works in the background), else [c].
  ProjectController noticesFor(ProjectController c) => _active?.call() ?? c;

  void addPanel(AiDropTarget p) {
    _panels
      ..remove(p)
      ..add(p);
  }

  void removePanel(AiDropTarget p) {
    _panels.remove(p);
    if (identical(over.value, p)) over.value = null;
  }

  void addBox(AiPasteTarget b) {
    _boxes
      ..remove(b)
      ..add(b);
  }

  void removeBox(AiPasteTarget b) {
    _boxes.remove(b);
  }

  /// The panel at [at], the newest first.
  AiDropTarget? _panelAt(Offset at) => _panels.reversed.where((p) => p.rect?.contains(at) ?? false).firstOrNull;

  @override
  void dragAt(Offset? at) => over.value = at == null ? null : _panelAt(at);

  @override
  void dropped(Offset at, List<DroppedFile> files) {
    over.value = null;
    if (files.isEmpty) return;
    // on the panel, or anywhere in the window while it is open
    final p = _panelAt(at) ?? _panels.lastOrNull;
    if (p != null) {
      p.take(files);
      return;
    }
    final c = _active?.call();
    c?.notify(c.t('ai.attach.noPanel'));
  }

  @override
  bool get takesPaste => _boxes.any((b) => b.focused);

  /// Pictures pasted without a name of their own become pasted-1.png,
  /// pasted-2.jpg… ([pastedName]).
  @override
  void pasted(List<DroppedFile> files) {
    final box = _boxes.reversed.where((b) => b.focused).firstOrNull;
    if (box == null || files.isEmpty) return;
    box.take([for (final f in files) f.renamed(pastedName(f.name, f.type, () => ++_pasted))]);
  }
}

/// Makes [child] (the AI panel) the place dropped files go to while it is
/// on screen, attached to [ai]; files dragged over it show a highlight.
class AiDropZone extends StatefulWidget {
  const AiDropZone({super.key, required this.c, required this.ai, required this.child, this.onAttached});
  final ProjectController c;
  final AiAssistant ai;
  final Widget child;

  /// Dropped files were attached (the panel shows the conversation).
  final VoidCallback? onAttached;

  @override
  State<AiDropZone> createState() => _AiDropZoneState();
}

class _AiDropZoneState extends State<AiDropZone> implements AiDropTarget {
  static AiFileDrop get _drops => AiFileDrop.instance;

  @override
  void initState() {
    super.initState();
    _drops.addPanel(this);
  }

  @override
  void dispose() {
    _drops.removePanel(this);
    super.dispose();
  }

  @override
  Rect? get rect {
    final box = mounted ? context.findRenderObject() as RenderBox? : null;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Future<void> take(List<DroppedFile> files) async {
    final ai = widget.ai;
    if (await aiAttachFiles(_drops.noticesFor(widget.c), ai, files) == 0 || !mounted) return;
    // the cursor in the box, to say what to do with them
    ai.focusInput = true;
    ai.refresh();
    widget.onAttached?.call();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      Positioned.fill(
        child: ValueListenableBuilder<AiDropTarget?>(
          valueListenable: _drops.over,
          builder: (context, over, _) => identical(over, this)
              ? IgnorePointer(
                  child: ListenableBuilder(listenable: widget.ai, builder: (context, _) => _highlight()),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ],
  );

  Widget _highlight() {
    // while the assistant works the paperclip is off: so are drops
    final busy = widget.ai.busy;
    final tone = busy ? Cad.fg60 : Cad.accentText;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const Key('ai_drop_overlay'),
        margin: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (busy ? Cad.dialog : Color.alphaBlend(Cad.accent.withValues(alpha: 0.14), Cad.dialog)).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: busy ? Cad.divider : Cad.accent, width: 2),
        ),
        // the message on a card of its own, clear of the conversation under it
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: Cad.dialog, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(busy ? Icons.hourglass_top : Icons.file_download_outlined, size: 40, color: tone),
              const SizedBox(height: 10),
              Text(
                widget.c.t(busy ? 'ai.attach.busy' : 'ai.attach.drop'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
