import 'dart:async';

import 'speech.dart';

SpeechEngine createSpeechEngine() => const _NoSpeech();

/// Desktop builds and tests: no dictation (the button is not shown); a
/// dictation started all the same ends at once.
class _NoSpeech implements SpeechEngine {
  const _NoSpeech();

  @override
  bool get available => false;

  @override
  SpeechSession start(
    String lang, {
    void Function()? onListening,
    required void Function(String text) onInterim,
    required void Function(String text) onFinal,
    required void Function(SpeechError error) onError,
    required void Function() onEnd,
  }) {
    scheduleMicrotask(() {
      onError(SpeechError.other);
      onEnd();
    });
    return const _Ended();
  }
}

class _Ended implements SpeechSession {
  const _Ended();

  @override
  void stop() {}

  @override
  void abort() {}
}
