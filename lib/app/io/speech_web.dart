/// Browser: the Web Speech API. The recognition is `SpeechRecognition` where
/// the browser has it unprefixed, else `webkitSpeechRecognition` (Chrome,
/// Edge, Safari), and only on https pages (the microphone needs one).
/// Continuous with interim results, except on Android: there the continuous
/// mode repeats the words of a phrase in the next one, and the recognition
/// ends after a pause all the same, so a dictation is one phrase. The words
/// of a result are its first alternative. A failure to start is reported
/// once [_WebSpeech.start] has returned, as the browser's own errors are.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'speech.dart';

SpeechEngine createSpeechEngine() => _WebSpeech();

class _WebSpeech implements SpeechEngine {
  /// The browser's recognition class; null without one.
  late final JSFunction? _recognition = _find();

  static JSFunction? _find() {
    try {
      if (!web.window.isSecureContext) return null;
      final JSObject w = web.window;
      for (final name in const ['SpeechRecognition', 'webkitSpeechRecognition']) {
        final f = w[name];
        if (f != null && f.isA<JSFunction>()) return f as JSFunction;
      }
    } catch (_) {}
    return null;
  }

  @override
  bool get available => _recognition != null;

  @override
  SpeechSession start(
    String lang, {
    void Function()? onListening,
    required void Function(String text) onInterim,
    required void Function(String text) onFinal,
    required void Function(SpeechError error) onError,
    required void Function() onEnd,
  }) => _WebSession(onListening, onInterim, onFinal, onError, onEnd).._open(_recognition, lang);
}

class _WebSession implements SpeechSession {
  _WebSession(this._onListening, this._onInterim, this._onFinal, this._onError, this._onEnd);

  final void Function()? _onListening;
  final void Function(String text) _onInterim, _onFinal;
  final void Function(SpeechError error) _onError;
  final void Function() _onEnd;

  web.SpeechRecognition? _rec;
  bool _ended = false;

  /// One phrase a dictation (Android), and whether its final words came.
  bool _single = false, _given = false;

  /// Results given as final (continuous mode): the browser lists the final
  /// results of the whole dictation first, then the interim ones.
  int _finals = 0;

  void _open(JSFunction? recognition, String lang) {
    try {
      final rec = recognition!.callAsConstructor<web.SpeechRecognition>();
      _single = _android;
      rec
        ..lang = lang
        ..continuous = !_single
        ..interimResults = true
        ..maxAlternatives = 1
        ..onstart = ((web.Event _) {
          if (!_ended) _onListening?.call();
        }).toJS
        ..onresult = ((web.SpeechRecognitionEvent e) {
          if (!_ended) _results(e.results);
        }).toJS
        ..onerror = ((web.SpeechRecognitionErrorEvent e) {
          if (!_ended) _onError(SpeechError.fromCode(e.error));
        }).toJS
        ..onend = ((web.Event _) => _end()).toJS;
      _rec = rec;
      rec.start();
    } catch (_) {
      scheduleMicrotask(() {
        if (_ended) return;
        _onError(SpeechError.other);
        _end();
      });
    }
  }

  void _results(web.SpeechRecognitionResultList list) {
    if (_single) {
      // one phrase: its newest guess, given as final once
      if (_given || list.length == 0) return;
      final r = list.item(list.length - 1);
      if (r.length == 0) return;
      final best = r.item(0);
      // Chrome on Android also marks passing guesses final, with no
      // confidence: those stay interim (the last one goes in at the end)
      if (r.isFinal && best.confidence > 0) {
        _given = true;
        _onFinal(best.transcript);
      } else {
        _onInterim(best.transcript);
      }
      return;
    }
    final interim = StringBuffer();
    for (var i = _finals; i < list.length; i++) {
      final r = list.item(i);
      final words = r.length == 0 ? '' : r.item(0).transcript;
      if (r.isFinal && interim.isEmpty) {
        _finals = i + 1;
        if (words.trim().isNotEmpty) _onFinal(words);
      } else {
        interim.write(words);
      }
    }
    _onInterim(interim.toString());
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    final rec = _rec;
    _rec = null;
    rec
      ?..onstart = null
      ..onresult = null
      ..onerror = null
      ..onend = null;
    _onEnd();
  }

  @override
  void stop() {
    if (_ended) return;
    try {
      _rec?.stop();
    } catch (_) {}
  }

  @override
  void abort() {
    if (_ended) return;
    try {
      _rec?.abort();
    } catch (_) {}
  }
}

/// Android: its user agent, or its client hints where the user asked for
/// the desktop site.
bool get _android {
  try {
    final nav = web.window.navigator;
    if (nav.userAgent.contains('Android')) return true;
    return (nav as _Navigator).userAgentData?.platform == 'Android';
  } catch (_) {
    return false;
  }
}

/// `navigator.userAgentData` (Chromium), which package:web does not have.
extension type _Navigator(JSObject _) implements JSObject {
  external _ClientHints? get userAgentData;
}

extension type _ClientHints(JSObject _) implements JSObject {
  external String get platform;
}
