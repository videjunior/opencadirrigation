/// Dictation into the AI chat box: a microphone button beside the box turns
/// speech into text with the browser's speech service ([speechEngine], see
/// lib/app/io/speech.dart), in the interface language. One press starts
/// listening (the button turns red and pulses), the next one stops. The
/// words being said show live in a small bubble above the button; the box
/// only receives a phrase once the service has recognised it for good,
/// inserted at the cursor, so the text typed, the cursor and an input
/// method's composition are never touched by guesses the service revises a
/// moment later (and a message sent never carries them). The dictation also
/// ends when the browser ends it (the last words heard still go in), when
/// the button goes away and when the box is emptied (the message was sent).
/// The first dictation asks before, saying where the voice goes. Desktop
/// builds and browsers without dictation (Firefox) show no button.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../i18n.dart' show languageNames;
import '../../io/prefs.dart';
import '../../io/speech.dart';
import '../../state/controller.dart';
import '../../theme.dart';

/// The microphone button of the chat box: a compact [IconButton] with a
/// 19 px icon, as big as the paperclip beside it, and nothing at all where
/// there is no dictation. Put it in the row of the box and hand it the box's
/// controller and focus:
///
/// ```dart
/// AiVoiceButton(c: c, input: input, focus: focus),
/// ```
///
/// It needs nothing more: the bubble with the words being said floats in
/// the nearest [Overlay], the notices go through `c.notify`, and the
/// dictation ends by itself (see the library comment). The assistant may be
/// working meanwhile: what is dictated waits in the box like typed text.
class AiVoiceButton extends StatefulWidget {
  const AiVoiceButton({super.key, required this.c, required this.input, this.focus, this.enabled = true});

  /// The tab's controller: the interface language (the dictation's), the
  /// strings and the notices (a refused microphone, nothing heard…).
  final ProjectController c;

  /// The chat box's text: each phrase goes in at its cursor; emptied while
  /// dictating (the message was sent), the dictation ends.
  final TextEditingController input;

  /// The chat box's focus: on computers, stopping the dictation with the
  /// button puts the cursor back in the box, so Enter sends (not on phones
  /// and tablets, where that would open the keyboard).
  final FocusNode? focus;

  /// False: the button is greyed, and a dictation under way stops (the
  /// phrase being said still goes in).
  final bool enabled;

  /// Set once the user was told where the voice goes (the first dictation).
  static const noticePref = 'ai.voiceNoticeSeen';

  @override
  State<AiVoiceButton> createState() => _AiVoiceButtonState();
}

enum _Phase { idle, listening, finishing }

class _AiVoiceButtonState extends State<AiVoiceButton> with SingleTickerProviderStateMixin {
  /// How long a stopped dictation may take to give its last phrase.
  static const _finishWait = Duration(seconds: 4);

  late final AnimationController _pulse;
  final _bubble = OverlayPortalController();
  _Phase _phase = _Phase.idle;
  SpeechSession? _session;

  /// Dictations started: the reports of an older one are dropped.
  int _run = 0;

  /// The service hears (the browser opened the microphone).
  bool _hearing = false;

  /// The words of the phrase being said, not in the box yet.
  String _interim = '';

  /// The box's text, to see it emptied.
  String _text = '';
  Timer? _finishing;

  TextEditingController get input => widget.input;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _text = input.text;
    input.addListener(_edited);
    // the bubble's place in the overlay, empty while no dictation runs
    _bubble.show();
  }

  @override
  void didUpdateWidget(AiVoiceButton old) {
    super.didUpdateWidget(old);
    if (!identical(old.input, input)) {
      old.input.removeListener(_edited);
      input.addListener(_edited);
      _text = input.text;
      // the words were for the other box
      _abort();
    }
    if (!widget.enabled) _stop();
  }

  @override
  void dispose() {
    input.removeListener(_edited);
    final s = _session;
    _idle(rebuild: false);
    s?.abort();
    _pulse.dispose();
    super.dispose();
  }

  /// The box changed: emptied while dictating (the message was sent, or the
  /// text cleared), the dictation ends and the words not in yet are dropped.
  void _edited() {
    final text = input.text;
    final emptied = text.isEmpty && _text.isNotEmpty;
    _text = text;
    if (emptied) _abort();
  }

  void _press() {
    switch (_phase) {
      case _Phase.idle:
        getPref(AiVoiceButton.noticePref) == '1' ? _start() : _askFirst();
      case _Phase.listening:
        _stop(byUser: true);
      case _Phase.finishing:
        break;
    }
  }

  /// The first dictation: where the voice goes, before any goes.
  void _askFirst() {
    final t = widget.c.t;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ai.voice.title')),
        content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Text(t('ai.voice.notice'))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t('cancel'))),
          FilledButton.icon(
            key: const Key('ai_voice_ok'),
            icon: const Icon(Icons.mic, size: 16),
            label: Text(t('ai.voice.start')),
            onPressed: () {
              setPref(AiVoiceButton.noticePref, '1');
              Navigator.of(ctx).pop();
              // within the press: some browsers open the microphone only then
              if (mounted && widget.enabled && _phase == _Phase.idle) _start();
            },
          ),
        ],
      ),
    );
  }

  void _start() {
    final c = widget.c;
    final run = ++_run;
    bool mine() => mounted && run == _run;
    setState(() {
      _phase = _Phase.listening;
      _hearing = false;
      _interim = '';
    });
    if (!MediaQuery.disableAnimationsOf(context)) _pulse.repeat(reverse: true);
    final SpeechSession session;
    try {
      session = speechEngine.start(
        speechLanguage(c.lang, _localeTags()),
        onListening: () {
          if (mine()) setState(() => _hearing = true);
        },
        onInterim: (words) {
          if (mine()) setState(() => _interim = words);
        },
        onFinal: (words) {
          if (!mine()) return;
          _insert(words);
          setState(() => _interim = '');
        },
        onError: (e) {
          if (mine()) _report(e);
        },
        onEnd: () {
          if (!mine()) return;
          // ended before the last words were final: they were heard, they go in
          _insert(_interim);
          _idle();
        },
      );
    } catch (_) {
      // an engine that would not start never leaves the button listening
      _report(SpeechError.other);
      _idle();
      return;
    }
    if (mine() && _phase != _Phase.idle) _session = session;
  }

  /// Stops listening; the phrase being said goes in when the browser gives
  /// it, or after [_finishWait] as it was last heard.
  void _stop({bool byUser = false}) {
    if (_phase != _Phase.listening) return;
    _pulse.reset();
    setState(() => _phase = _Phase.finishing);
    _session?.stop();
    _finishing = Timer(_finishWait, () {
      if (!mounted || _phase != _Phase.finishing) return;
      final s = _session;
      _insert(_interim);
      _idle();
      s?.abort();
    });
    if (byUser && !_touch) widget.focus?.requestFocus();
  }

  /// Ends the dictation at once; the words not in the box yet are dropped.
  void _abort() {
    if (_phase == _Phase.idle) return;
    final s = _session;
    _idle();
    s?.abort();
  }

  void _idle({bool rebuild = true}) {
    _run++;
    _finishing?.cancel();
    _finishing = null;
    _session = null;
    _phase = _Phase.idle;
    _hearing = false;
    _interim = '';
    _pulse.reset();
    if (rebuild) setState(() {});
  }

  void _report(SpeechError e) {
    final c = widget.c;
    final key = switch (e) {
      SpeechError.aborted => null,
      SpeechError.notAllowed => 'ai.voice.err.notAllowed',
      SpeechError.serviceNotAllowed => 'ai.voice.err.service',
      SpeechError.noMicrophone => 'ai.voice.err.noMic',
      SpeechError.noSpeech => 'ai.voice.err.noSpeech',
      SpeechError.network => 'ai.voice.err.network',
      SpeechError.language => 'ai.voice.err.language',
      SpeechError.other => 'ai.voice.err.other',
    };
    if (key != null) c.notify(c.t(key, {'l': languageNames[c.lang] ?? c.lang}));
  }

  /// Puts [words] in the box at its cursor (after a selection, which is not
  /// replaced), with a space on either side where the words need one; the
  /// cursor goes after them, so the next phrase follows.
  void _insert(String words) {
    final w = words.trim();
    if (w.isEmpty) return;
    final v = input.value;
    final text = v.text;
    final at = v.selection.isValid && v.selection.end <= text.length ? v.selection.end : text.length;
    final before = text.substring(0, at), after = text.substring(at);
    final lead = _spaced(before, w) ? ' ' : '';
    final trail = _spaced(w, after) ? ' ' : '';
    input.value = TextEditingValue(
      text: '$before$lead$w$trail$after',
      selection: TextSelection.collapsed(offset: at + lead.length + w.length),
      // an input method composing before the cursor goes on
      composing: v.composing.isValid && v.composing.end <= at ? v.composing : TextRange.empty,
    );
  }

  /// Whether [left] then [right] need a space between them: not at the start
  /// or the end of the box, beside a space, after an opening bracket or
  /// quote, before a closing mark, nor beside Chinese or Japanese (written
  /// without spaces).
  static bool _spaced(String left, String right) {
    if (left.isEmpty || right.isEmpty) return false;
    final a = left.runes.last, b = right.runes.first;
    if (_blank(a) || _blank(b) || _opening.contains(a) || _closing.contains(b)) return false;
    return !_unspaced(a) && !_unspaced(b);
  }

  static bool _blank(int r) => String.fromCharCode(r).trim().isEmpty;

  static final _opening = '([{¿¡«“‘„'.runes.toSet();
  static final _closing = '.,;:!?)]}»”’…%،؛؟।'.runes.toSet();

  /// CJK ideographs, kana, their punctuation and full-width forms.
  static bool _unspaced(int r) => (r >= 0x2E80 && r <= 0x9FFF) || (r >= 0xF900 && r <= 0xFAFF) || (r >= 0xFF00 && r <= 0xFFEF) || (r >= 0x20000 && r <= 0x3FFFF);

  /// Phones and tablets: the cursor in the box would open the keyboard.
  static bool get _touch => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
    _ => false,
  };

  /// The machine's preferred languages, as [ProjectController.systemLanguageTags]
  /// reads them (through the binding, which tests can set).
  static Iterable<String> _localeTags() {
    final d = WidgetsBinding.instance.platformDispatcher;
    return [
      for (final l in d.locales.isEmpty ? [d.locale] : d.locales) l.toLanguageTag(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!speechEngine.available) return const SizedBox.shrink();
    final t = widget.c.t;
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _bubble,
      overlayChildBuilder: _live,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final on = _phase != _Phase.idle;
          return IconButton(
            key: const Key('ai_voice'),
            tooltip: t(switch (_phase) {
              _Phase.idle => 'ai.voice',
              _Phase.listening => 'ai.voice.stop',
              _Phase.finishing => 'ai.voice.finishing',
            }),
            visualDensity: VisualDensity.compact,
            style: on
                ? IconButton.styleFrom(
                    foregroundColor: Cad.error,
                    backgroundColor: Cad.error.withValues(alpha: 0.10 + 0.20 * _pulse.value),
                  )
                : null,
            icon: Icon(on ? Icons.mic : Icons.mic_none, size: 19),
            onPressed: switch (_phase) {
              _Phase.idle => widget.enabled ? _press : null,
              _Phase.listening => _press,
              _Phase.finishing => null,
            },
          );
        },
      ),
    );
  }

  /// The words being said, in a bubble above the button (below it when
  /// there is no room above) that grows towards the middle of the screen.
  Widget _live(BuildContext context, OverlayChildLayoutInfo info) {
    if (_phase == _Phase.idle) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    final t = widget.c.t;
    final button = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final screen = info.overlaySize;
    const gap = 4.0, margin = 8.0;
    final rightward = button.center.dx <= screen.width / 2;
    final room = rightward ? screen.width - button.left - margin : button.right - margin;
    final above = button.top >= 72;
    final words = _interim.trim();
    final shown = words.isNotEmpty
        ? _tail(words)
        : t(switch (_phase) {
            _Phase.finishing => 'ai.voice.finishing',
            _ => _hearing ? 'ai.voice.speak' : 'ai.voice.opening',
          });
    return Positioned(
      left: rightward ? button.left : null,
      right: rightward ? null : screen.width - button.right,
      top: above ? null : button.bottom + gap,
      bottom: above ? screen.height - button.top + gap : null,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: room.clamp(80.0, 360.0)),
          child: Material(
            key: const Key('ai_voice_live'),
            elevation: 3,
            color: Cad.dialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: Cad.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq, size: 15, color: _phase == _Phase.listening ? Cad.error : Cad.fg38),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      shown,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: words.isEmpty ? Cad.fg54 : Cad.fg87, fontStyle: words.isEmpty ? FontStyle.italic : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The end of a long phrase: the newest words are the ones to see.
  static String _tail(String s) {
    final ch = s.characters;
    return ch.length <= 160 ? s : '…${ch.takeLast(159)}';
  }
}
