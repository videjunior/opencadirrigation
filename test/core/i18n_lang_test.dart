import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';

/// Interface language: follows the machine's preferred languages, English
/// when none is spoken; URL languages apply to the visit only.
void main() {
  group('languageFromTags', () {
    test('first supported language of the preference list wins', () {
      expect(languageFromTags(['pt-BR', 'en-US']), 'pt');
      expect(languageFromTags(['pt_PT']), 'pt');
      expect(languageFromTags(['es-MX', 'pt-BR']), 'es');
      expect(languageFromTags(['nl-BE', 'es-419', 'en']), 'es');
      expect(languageFromTags(['it-IT', 'pt']), 'pt');
      expect(languageFromTags(['EN-GB']), 'en');
      expect(languageFromTags([' es ']), 'es');
    });

    test('English when the machine speaks none of the three or nothing is known', () {
      expect(languageFromTags(['nl', 'ko', 'it']), 'en');
      expect(languageFromTags(['fr', 'de', 'ja']), 'fr');
      expect(languageFromTags(['zh-Hans-CN']), 'zh');
      expect(languageFromTags(['pa-Guru-IN']), 'pa');
      expect(languageFromTags(['ko-KR', 'ar-EG']), 'ar');
      expect(languageFromTags(const []), 'en');
      expect(languageFromTags(['und', '']), 'en');
    });
  });

  test('languageFromPath reads the /en/ and /es/ entry pages', () {
    expect(languageFromPath(['en', '']), 'en');
    expect(languageFromPath(['es', 'index.html']), 'es');
    expect(languageFromPath(['pt']), 'pt');
    expect(languageFromPath(['']), isNull);
    expect(languageFromPath(const []), isNull);
    expect(languageFromPath(['app', 'v2']), isNull);
    expect(languageFromPath(Uri.parse('https://opencadirrigation.com/en/?example=garden').pathSegments), 'en');
    expect(languageFromPath(Uri.parse('https://opencadirrigation.com/').pathSegments), isNull);
  });

  test('a saved choice wins over the machine; URL languages are not saved', () {
    removePref('lang');
    final c = ProjectController();
    expect(supportedLanguages, contains(c.lang));
    c.setLanguage('es', persist: false);
    expect(c.lang, 'es');
    expect(c.t('menu.file'), 'Archivo');
    expect(getPref('lang'), isNull, reason: 'a ?lang= or /es/ visit does not change the saved preference');
    c.setLanguage('pt');
    expect(getPref('lang'), 'pt');
    expect(ProjectController().lang, 'pt', reason: 'the explicit choice is remembered');
    c.setLanguage('xx');
    expect(c.lang, 'pt', reason: 'unknown languages are ignored');
    removePref('lang');
    final fresh = ProjectController();
    expect(fresh.lang, languageFromTags(ProjectController.systemLanguageTags()));
  });
}
