import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/speech.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_voice.dart';

/// Dictation into the AI chat box, with a fake speech engine standing in
/// for the browser's: no button without dictation; as big as the paperclip;
/// a press starts, the next stops, the browser's end brings it back;
/// interim words only in the bubble, final ones at the cursor with the
/// typed text kept and spaces where the words need them (none in Chinese);
/// the last words heard go in when the browser ends without making them
/// final; the dictation ends when the box is emptied by sending, when the
/// button goes away, when it is greyed, and when the browser never ends a
/// stopped one; errors (and an engine that will not start) become notices;
/// the bubble stays on screen, towards the middle; the one-time notice on
/// where the voice goes; the language and region asked for.
void main() {
  final browserless = speechEngine;
  late FakeSpeech speech;
  late ProjectController c;
  late TextEditingController input;
  late FocusNode focus;

  setUp(() async {
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    speechEngine = speech = FakeSpeech();
    setPref(AiVoiceButton.noticePref, '1');
    input = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    speechEngine = browserless;
    removePref(AiVoiceButton.noticePref);
    input.dispose();
    focus.dispose();
  });

  final button = find.byKey(const Key('ai_voice'));
  final bubble = find.byKey(const Key('ai_voice_live'));
  String tip(WidgetTester tester) => tester.widget<IconButton>(button).tooltip!;
  bool pressable(WidgetTester tester) => tester.widget<IconButton>(button).onPressed != null;
  Finder said(String words) => find.descendant(of: bubble, matching: find.text(words));

  /// The chat box's row as the panel lays it out: the paperclip, the
  /// microphone and the box.
  Future<void> pumpBox(WidgetTester tester, {bool enabled = true}) => tester.pumpWidget(
    MaterialApp(
      theme: buildCadTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(key: const Key('paperclip'), tooltip: 'paperclip', visualDensity: VisualDensity.compact, icon: const Icon(Icons.attach_file, size: 19), onPressed: () {}),
              AiVoiceButton(c: c, input: input, focus: focus, enabled: enabled),
              Expanded(
                child: TextField(key: const Key('box'), controller: input, focusNode: focus, maxLines: 5, minLines: 1),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<FakeSession> startDictation(WidgetTester tester) async {
    final before = speech.sessions.length;
    await tester.tap(button);
    await tester.pump();
    expect(speech.sessions, hasLength(before + 1), reason: 'a press starts a dictation');
    return speech.last;
  }

  void cursorAt(int offset) => input.selection = TextSelection.collapsed(offset: offset);

  testWidgets('no button where there is no dictation (the desktop builds, Firefox, these tests by default)', (tester) async {
    expect(browserless.available, isFalse, reason: 'the stub engine of the VM');
    speechEngine = browserless;
    await pumpBox(tester);
    expect(button, findsNothing);
    expect(find.byKey(const Key('box')), findsOneWidget);

    speechEngine = FakeSpeech(available: false);
    await pumpBox(tester);
    expect(button, findsNothing);
    expect(tester.getSize(find.byType(AiVoiceButton)), Size.zero, reason: 'it takes no room in the row');
  });

  testWidgets('as big as the paperclip; one press starts listening, the next stops, the end of the dictation brings it back', (tester) async {
    await pumpBox(tester);
    final size = tester.getSize(find.byKey(const Key('paperclip')));
    expect(tester.getSize(button), size);
    expect(tip(tester), c.t('ai.voice'));
    expect(bubble, findsNothing);

    final s = await startDictation(tester);
    expect(tip(tester), c.t('ai.voice.stop'));
    expect(said(c.t('ai.voice.opening')), findsOneWidget, reason: 'the browser may be asking for the microphone');
    s.listening!();
    await tester.pump(const Duration(milliseconds: 400));
    expect(said(c.t('ai.voice.speak')), findsOneWidget);
    expect(tester.getSize(button), size, reason: 'the pulse changes no size');
    final red = tester.widget<IconButton>(button).style!.foregroundColor!.resolve({});
    expect(red, Cad.error);

    await tester.tap(button);
    await tester.pump();
    expect(s.stops, 1);
    expect(s.aborts, 0);
    expect(tip(tester), c.t('ai.voice.finishing'));
    expect(pressable(tester), isFalse, reason: 'waiting for the last phrase');
    expect(said(c.t('ai.voice.finishing')), findsOneWidget);

    s.end();
    await tester.pump();
    expect(tip(tester), c.t('ai.voice'));
    expect(pressable(tester), isTrue);
    expect(bubble, findsNothing);
    expect(input.text, isEmpty);
  });

  testWidgets('interim words show in the bubble only; final ones go in at the cursor, the typed text kept, spaced where needed', (tester) async {
    await pumpBox(tester);
    input.text = 'Size the pipes';
    cursorAt(4);
    final s = await startDictation(tester);

    s.interim('main');
    await tester.pump();
    expect(input.text, 'Size the pipes', reason: 'a guess never goes in the box');
    expect(said('main'), findsOneWidget);
    s.interim('main lie');
    await tester.pump();
    expect(said('main lie'), findsOneWidget);

    s.finalText(' main line');
    await tester.pump();
    expect(input.text, 'Size main line the pipes');
    expect(input.selection, const TextSelection.collapsed(offset: 14));
    expect(said('main line'), findsNothing);

    // the next phrase follows the last one
    s.finalText('and the laterals');
    await tester.pump();
    expect(input.text, 'Size main line and the laterals the pipes');

    // at the end, before and after punctuation, after a space and a bracket
    cursorAt(input.text.length);
    s.finalText('please');
    s.finalText('?');
    await tester.pump();
    expect(input.text, 'Size main line and the laterals the pipes please?');
    input.text = 'Flow (';
    cursorAt(6);
    s.finalText('litres');
    await tester.pump();
    expect(input.text, 'Flow (litres');
    input.text = 'Zone 3 ';
    cursorAt(7);
    s.finalText('first');
    await tester.pump();
    expect(input.text, 'Zone 3 first');

    // a selection is kept: the words go after it
    input.text = 'pump well';
    input.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    s.finalText('the');
    await tester.pump();
    expect(input.text, 'pump the well');

    // no cursor (never focused): at the end
    input.value = const TextEditingValue(text: 'Open');
    s.finalText('the project');
    await tester.pump();
    expect(input.text, 'Open the project');

    // Chinese and Japanese are written without spaces
    input.text = '打开项目';
    cursorAt(4);
    s.finalText('显示流量');
    await tester.pump();
    expect(input.text, '打开项目显示流量');
    input.text = 'Bomba';
    cursorAt(5);
    s.finalText('ポンプ');
    await tester.pump();
    expect(input.text, 'Bombaポンプ');
    s.end();
    await tester.pump();
  });

  testWidgets('the last words heard go in when the browser ends without making them final; a stopped dictation it never ends is let go', (tester) async {
    await pumpBox(tester);
    input.text = 'Pipe';
    var s = await startDictation(tester);
    s.interim('fifty millimetres');
    await tester.pump();
    s.error(SpeechError.network);
    s.end();
    await tester.pump();
    expect(input.text, 'Pipe fifty millimetres');
    expect(tip(tester), c.t('ai.voice'));

    // stopped, and the browser neither gives the phrase nor ends: after a while
    // the words go in as last heard and the dictation is abandoned
    s = await startDictation(tester);
    s.interim('PVC');
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(s.stops, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(tip(tester), c.t('ai.voice.finishing'));
    await tester.pump(const Duration(seconds: 2));
    expect(s.aborts, 1);
    expect(input.text, 'Pipe fifty millimetres PVC');
    expect(tip(tester), c.t('ai.voice'));
    // the reports of the abandoned dictation come too late
    s.finalText('PVC pipe');
    s.end();
    await tester.pump();
    expect(input.text, 'Pipe fifty millimetres PVC');
  });

  testWidgets('the dictation ends when the box is emptied by sending, and when the button goes away', (tester) async {
    await pumpBox(tester);
    var s = await startDictation(tester);
    s.finalText('show the flow of zone 2');
    await tester.pump();
    s.interim('and the pressure');
    await tester.pump();
    // what the panel does when the message is sent
    input.clear();
    await tester.pump();
    expect(s.aborts, 1, reason: 'the words not in yet are dropped, not left for the next message');
    expect(tip(tester), c.t('ai.voice'));
    expect(bubble, findsNothing);
    s.finalText('and the pressure');
    s.end();
    await tester.pump();
    expect(input.text, isEmpty, reason: 'nothing from the old dictation lands in the empty box');

    // starting with an empty box is not an emptying
    s = await startDictation(tester);
    s.finalText('size the main line');
    await tester.pump();
    expect(s.aborts, 0);
    expect(input.text, 'size the main line');

    // the panel is closed (the button goes away)
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(s.aborts, 1);
    expect(s.stops, 0);
  });

  testWidgets('a greyed button starts nothing; greyed while listening, the dictation stops and its phrase still goes in', (tester) async {
    await pumpBox(tester, enabled: false);
    expect(pressable(tester), isFalse);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(speech.sessions, isEmpty);

    await pumpBox(tester);
    final s = await startDictation(tester);
    s.interim('flush');
    await pumpBox(tester, enabled: false);
    expect(s.stops, 1);
    expect(s.aborts, 0);
    s.finalText('flush the laterals');
    s.end();
    await tester.pump();
    expect(input.text, 'flush the laterals');
    expect(pressable(tester), isFalse);
  });

  testWidgets('errors become a short notice; an abort says nothing', (tester) async {
    await pumpBox(tester);
    final cases = {
      SpeechError.notAllowed: 'ai.voice.err.notAllowed',
      SpeechError.serviceNotAllowed: 'ai.voice.err.service',
      SpeechError.noMicrophone: 'ai.voice.err.noMic',
      SpeechError.noSpeech: 'ai.voice.err.noSpeech',
      SpeechError.network: 'ai.voice.err.network',
      SpeechError.language: 'ai.voice.err.language',
      SpeechError.other: 'ai.voice.err.other',
    };
    for (final MapEntry(key: error, value: key) in cases.entries) {
      final s = await startDictation(tester);
      final seq = c.messageSeq;
      s.error(error);
      s.end();
      await tester.pump();
      expect(c.messageSeq, seq + 1, reason: '$error');
      expect(c.lastMessage, c.t(key, {'l': 'English'}));
      expect(tip(tester), c.t('ai.voice'));
    }
    expect(c.t('ai.voice.err.language', {'l': 'English'}), contains('English'));

    final s = await startDictation(tester);
    final seq = c.messageSeq;
    s.error(SpeechError.aborted);
    s.end();
    await tester.pump();
    expect(c.messageSeq, seq);

    // an engine that throws instead of starting never leaves the button listening
    speech.fails = true;
    await tester.tap(button);
    await tester.pump();
    expect(c.messageSeq, seq + 1);
    expect(c.lastMessage, c.t('ai.voice.err.other'));
    expect(tip(tester), c.t('ai.voice'));
    expect(bubble, findsNothing);
  });

  testWidgets('the bubble grows towards the middle of the screen, above the button, below it where there is no room above', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final where in [Alignment.bottomLeft, Alignment.bottomRight, Alignment.topLeft, Alignment.topRight]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCadTheme(),
          home: Scaffold(
            body: Align(
              alignment: where,
              child: AiVoiceButton(c: c, input: input, focus: focus),
            ),
          ),
        ),
      );
      final s = await startDictation(tester);
      s.interim('size the main line for the whole orchard and then show the flow of every zone with its pressure');
      await tester.pump();
      final b = tester.getRect(button), w = tester.getRect(bubble);
      expect(w.left >= 0 && w.right <= 800 && w.top >= 0 && w.bottom <= 600, isTrue, reason: '$where: on screen ($w)');
      expect(w.width, lessThanOrEqualTo(360));
      if (where.x < 0) {
        expect(w.left, moreOrLessEquals(b.left), reason: '$where');
      } else {
        expect(w.right, moreOrLessEquals(b.right), reason: '$where');
      }
      if (where.y > 0) {
        expect(w.bottom, lessThanOrEqualTo(b.top), reason: '$where: above');
      } else {
        expect(w.top, greaterThanOrEqualTo(b.bottom), reason: '$where: below');
      }
      s.end();
      await tester.pump();
    }
  });

  testWidgets('the first dictation says where the voice goes, and starts only once accepted', (tester) async {
    removePref(AiVoiceButton.noticePref);
    await pumpBox(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(c.t('ai.voice.notice')), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
    expect(speech.sessions, isEmpty, reason: 'nothing is heard before the notice is accepted');
    await tester.tap(find.text(c.t('cancel')));
    await tester.pumpAndSettle();
    expect(speech.sessions, isEmpty);
    expect(getPref(AiVoiceButton.noticePref), isNull, reason: 'cancelled: asked again next time');

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_voice_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(speech.sessions, hasLength(1), reason: 'accepting starts the dictation at once');
    expect(getPref(AiVoiceButton.noticePref), '1');
    expect(tip(tester), c.t('ai.voice.stop'));
    speech.last.end();
    await tester.pump();

    // told once
    await tester.tap(button);
    await tester.pump();
    expect(find.text(c.t('ai.voice.notice')), findsNothing);
    expect(speech.sessions, hasLength(2));
    speech.last.end();
    await tester.pump();
  });

  testWidgets('stopping with the button puts the cursor back in the box on computers, not on phones', (tester) async {
    await pumpBox(tester);
    var s = await startDictation(tester);
    await tester.tap(button);
    await tester.pump();
    expect(focus.hasFocus, isFalse, reason: 'a phone would open its keyboard');
    s.end();
    await tester.pump();

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      s = await startDictation(tester);
      await tester.tap(button);
      await tester.pump();
      expect(focus.hasFocus, isTrue, reason: 'Enter then sends');
      s.end();
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the dictation is in the interface language, with the region of the user\'s locale when it has one', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpBox(tester);
    const expected = {'en': 'en-GB', 'pt': 'pt-BR', 'es': 'es-MX', 'zh': 'zh-CN', 'ar': 'ar-SA', 'hi': 'hi-IN', 'fr': 'fr-FR', 'ja': 'ja-JP'};
    for (final MapEntry(key: lang, value: tag) in expected.entries) {
      await c.setLanguage(lang, persist: false);
      final s = await startDictation(tester);
      expect(speech.langs.last, tag, reason: lang);
      s.end();
      await tester.pump();
    }
    tester.platformDispatcher.localesTestValue = const [Locale('es', 'AR'), Locale('en', 'US')];
    await c.setLanguage('es', persist: false);
    final s = await startDictation(tester);
    expect(speech.langs.last, 'es-AR');
    s.end();
    await tester.pump();
  });

  test('speechLanguage: a region for every interface language, the user\'s where a locale gives one', () {
    for (final l in supportedLanguages) {
      expect(speechLanguage(l), matches(RegExp('^$l-[A-Z]{2}\$')), reason: l);
    }
    expect(speechLanguage('pt', ['pt-PT']), 'pt-PT');
    expect(speechLanguage('pt', ['en-US', 'pt']), 'pt-BR', reason: 'a bare language gives no region');
    expect(speechLanguage('en', ['pt-BR', 'en_IN']), 'en-IN');
    expect(speechLanguage('zh', ['zh-Hant-TW']), 'zh-TW');
    expect(speechLanguage('es', ['es-419']), 'es-MX', reason: 'a numeric region is not one of the services\'');
    expect(speechLanguage('sw', ['sw-KE']), 'sw-KE');
    expect(speechLanguage('xx'), 'xx');
  });

  test('the browser\'s error codes', () {
    expect(SpeechError.fromCode('not-allowed'), SpeechError.notAllowed);
    expect(SpeechError.fromCode('service-not-allowed'), SpeechError.serviceNotAllowed);
    expect(SpeechError.fromCode('audio-capture'), SpeechError.noMicrophone);
    expect(SpeechError.fromCode('no-speech'), SpeechError.noSpeech);
    expect(SpeechError.fromCode('network'), SpeechError.network);
    expect(SpeechError.fromCode('language-not-supported'), SpeechError.language);
    expect(SpeechError.fromCode('aborted'), SpeechError.aborted);
    expect(SpeechError.fromCode('bad-grammar'), SpeechError.other);
  });
}

/// Stands in for the browser's speech service: records each dictation and
/// lets the test report what the browser would.
class FakeSpeech implements SpeechEngine {
  FakeSpeech({this.available = true});

  @override
  bool available;

  /// Throws instead of starting.
  bool fails = false;

  final langs = <String>[];
  final sessions = <FakeSession>[];
  FakeSession get last => sessions.last;

  @override
  SpeechSession start(
    String lang, {
    void Function()? onListening,
    required void Function(String text) onInterim,
    required void Function(String text) onFinal,
    required void Function(SpeechError error) onError,
    required void Function() onEnd,
  }) {
    if (fails) throw StateError('no recognition');
    langs.add(lang);
    final s = FakeSession(onListening, onInterim, onFinal, onError, onEnd);
    sessions.add(s);
    return s;
  }
}

class FakeSession implements SpeechSession {
  FakeSession(this.listening, this.interim, this.finalText, this.error, this.end);

  final void Function()? listening;
  final void Function(String text) interim, finalText;
  final void Function(SpeechError error) error;
  final void Function() end;
  int stops = 0, aborts = 0;

  @override
  void stop() => stops++;

  @override
  void abort() => aborts++;
}
