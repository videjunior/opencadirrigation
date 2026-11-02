import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/site_links.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';

import '../tool/site.dart' show privacyUrl, siteLanguages, termsUrl;

/// The app points to the legal pages of the site (SIT-01, SIT-13): Help →
/// About links the privacy policy and the terms of use in the interface
/// language and says, in one line, that a professional checks and signs
/// the design.
void main() {
  test('the app links the same legal pages the site generates, in every language', () {
    for (final l in siteLanguages) {
      expect(privacyPolicyUrl(l.code), privacyUrl(l), reason: l.code);
      expect(termsOfUseUrl(l.code), termsUrl(l), reason: l.code);
    }
    expect(privacyPolicyUrl('en'), 'https://opencadirrigation.com/privacy/');
    expect(termsOfUseUrl('pt'), 'https://opencadirrigation.com/pt/terms/');
  });

  testWidgets('Help → About links the privacy policy and the terms of use and carries the responsibility line', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProjectController();
    await c.setLanguage('pt', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => showAboutDialogApp(context, c), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about_privacy')), findsOneWidget);
    expect(find.byKey(const Key('about_terms')), findsOneWidget);
    expect(find.text('Política de privacidade'), findsOneWidget);
    expect(find.text('https://opencadirrigation.com/pt/privacy/'), findsOneWidget);
    expect(find.text('https://opencadirrigation.com/pt/terms/'), findsOneWidget);
    final line = tester.widget<Text>(find.byKey(const Key('about_disclaimer'))).data!;
    expect(line, contains('profissional habilitado'));
  });
}
