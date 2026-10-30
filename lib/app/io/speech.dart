/// Dictation: speech turned into text by the browser's speech service, the
/// Web Speech API's `SpeechRecognition` (`webkitSpeechRecognition` in
/// Chrome, Edge and Safari; conditional import). The sound of the voice goes
/// to that service, never to the app: Chrome sends it to Google's servers,
/// Edge to Microsoft's, Safari to Apple's. Firefox, pages that are not https
/// and the desktop builds have none: [speechEngine] is then not
/// [SpeechEngine.available]. Tests put a fake engine in [speechEngine].
library;

import '../i18n.dart' show languageTag;
import 'speech_stub.dart' if (dart.library.js_interop) 'speech_web.dart' as impl;

/// Why a dictation ended before it was stopped (the browser's error codes).
enum SpeechError {
  /// `not-allowed`: the microphone was refused, by the user or by the site
  /// settings.
  notAllowed,

  /// `service-not-allowed`: the browser or the system does not allow its
  /// speech service (Safari with Dictation turned off, a company policy).
  serviceNotAllowed,

  /// `audio-capture`: no microphone, or it could not be opened.
  noMicrophone,

  /// `no-speech`: nothing was heard.
  noSpeech,

  /// `network`: the speech service could not be reached.
  network,

  /// `language-not-supported`: the service has no dictation in the language.
  language,

  /// `aborted`: ended by [SpeechSession.abort], or by the browser.
  aborted,

  /// Anything else (`bad-grammar`, a browser that would not start).
  other;

  /// The error of a Web Speech API code (`not-allowed`, `no-speech`…).
  static SpeechError fromCode(String code) => switch (code) {
    'not-allowed' => notAllowed,
    'service-not-allowed' => serviceNotAllowed,
    'audio-capture' => noMicrophone,
    'no-speech' => noSpeech,
    'network' => network,
    'language-not-supported' => language,
    'aborted' => aborted,
    _ => other,
  };
}

/// A dictation under way, from [SpeechEngine.start] to its end.
abstract interface class SpeechSession {
  /// Stops listening: the words heard so far still come as final text, then
  /// the end.
  void stop();

  /// Stops listening at once, dropping the words not final yet; the end
  /// follows.
  void abort();
}

/// A speech-to-text service.
abstract interface class SpeechEngine {
  /// Whether dictation can be offered here.
  bool get available;

  /// Starts a dictation in [lang] (a BCP 47 tag, see [speechLanguage]) that
  /// goes on until it is stopped or the browser ends it (after a long
  /// silence; on Android after each phrase). It reports, never before
  /// [start] has returned:
  ///  * [onListening], once the service hears (the first time, the browser
  ///    asks for the microphone before);
  ///  * [onInterim], the words of the phrase being said as they are
  ///    recognised, each call replacing the last ('' when there are none);
  ///  * [onFinal], each phrase once it is recognised for good (its words are
  ///    no longer interim);
  ///  * [onError], what went wrong, if anything;
  ///  * [onEnd], last and once, however it ended.
  SpeechSession start(
    String lang, {
    void Function()? onListening,
    required void Function(String text) onInterim,
    required void Function(String text) onFinal,
    required void Function(SpeechError error) onError,
    required void Function() onEnd,
  });
}

/// The app's dictation: the browser's, or none (desktop builds); tests
/// replace it.
SpeechEngine speechEngine = impl.createSpeechEngine();

/// The tag a dictation in the interface language [lang] asks for: the
/// language with the region of the first of the user's locale [tags] in it
/// (`es-AR`, `pt-PT`, `en-IN`: the accent and the spelling the user has),
/// else with the region of its most spoken variety the speech services of
/// Chrome, Edge and Safari offer (`pt-BR`, `es-MX`, `zh-CN`). The services
/// want a region: some refuse a bare `pt`, others hear a bare `en` as
/// another variety. Tags come as the browser reports them (`pt-BR`, `en_US`,
/// `zh-Hant-TW`); a region given as a number (`es-419`) is not one of theirs.
String speechLanguage(String lang, [Iterable<String> tags = const []]) {
  for (final tag in tags) {
    final parts = tag.trim().split(RegExp(r'[-_]'));
    if (parts.first.toLowerCase() != lang) continue;
    for (final p in parts.skip(1)) {
      if (RegExp(r'^[A-Za-z]{2}$').hasMatch(p)) return '$lang-${p.toUpperCase()}';
    }
  }
  final region = _speechRegions[lang];
  return region == null ? languageTag(lang) : '$lang-$region';
}

/// Region of the variety each interface language is dictated in when the
/// user's locales name none: the country with the most speakers (as the
/// default currencies), Arabic as in Saudi Arabia, the variety offered most
/// widely.
const _speechRegions = <String, String>{
  'id': 'ID',
  'de': 'DE',
  'en': 'US',
  'es': 'MX',
  'fr': 'FR',
  'ha': 'NG',
  'sw': 'TZ',
  'pt': 'BR',
  'vi': 'VN',
  'tr': 'TR',
  'ru': 'RU',
  'ar': 'SA',
  'ur': 'PK',
  'hi': 'IN',
  'mr': 'IN',
  'bn': 'BD',
  'pa': 'IN',
  'te': 'IN',
  'zh': 'CN',
  'ja': 'JP',
};
