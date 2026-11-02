import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';

/// The interactive tutorial covers the AI assistant (SIT-23): a chapter of
/// its own before the closing step says how to open it, the key and the
/// modes, how to ask, approve and undo, and the review, marks and voice; it
/// only explains (no step sends anything to an AI service), in the three
/// compiled languages, and the welcome text counts its steps.
void main() {
  const ids = ['aiOpen', 'aiKey', 'aiAsk', 'aiReview'];

  test('the AI chapter comes before the closing step and only explains', () {
    final steps = buildTutorialSteps('en');
    final at = [for (final id in ids) steps.indexWhere((s) => s.id == id)];
    expect(at.every((i) => i >= 0), isTrue);
    expect(at, [for (var i = 0; i < ids.length; i++) at.first + i], reason: 'one chapter, in order');
    expect(steps[at.last + 1].id, 'shortcuts', reason: 'the closing step stays last');
    for (final i in at) {
      expect(steps[i].interactive, isFalse, reason: '${steps[i].id}: no demo, nothing sent');
      expect(steps[i].demo, isNull);
      expect(steps[i].chapter, 'AI assistant');
    }
    final text = [for (final i in at) steps[i].body].join(' ');
    for (final needle in ['?ai=1', 'Send', 'Remember the key on this device', 'Ask before each change'.toLowerCase(), 'Rewind to here', '/review', 'Mark a point']) {
      expect(text.toLowerCase(), contains(needle.toLowerCase()), reason: needle);
    }
  });

  test('in Portuguese and Spanish, with the labels the panel shows', () {
    for (final lang in ['pt', 'es']) {
      final t = I18n(lang);
      final steps = buildTutorialSteps(lang);
      final english = buildTutorialSteps('en');
      for (final id in ids) {
        final s = steps.firstWhere((s) => s.id == id);
        final e = english.firstWhere((s) => s.id == id);
        expect(s.title, isNot(e.title), reason: '$lang $id');
        expect(s.body, isNot(e.body), reason: '$lang $id');
      }
      final text = [for (final id in ids) steps.firstWhere((s) => s.id == id).body].join(' ');
      for (final key in ['ai.key.remember', 'ai.rewind', 'ai.marks.point', 'ai.marks.line', 'ai.send']) {
        expect(text, contains(t(key)), reason: '$lang: $key');
      }
    }
  });

  test('the welcome text counts the steps of the tutorial', () {
    final n = buildTutorialSteps('en').length;
    for (final lang in ['pt', 'en', 'es']) {
      expect(I18n(lang)('welcome.body'), contains(' $n '), reason: lang);
    }
  });
}
