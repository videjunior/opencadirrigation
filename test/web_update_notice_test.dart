import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/update_notice.dart';

/// The banner of a newer build (SIT-07): the installed app and a tab open
/// for days run the build they started with while the service worker
/// installs the next one; the banner offers to reload into it, and asks
/// first when a reload would lose unsaved work, which then goes to the
/// autosave. The worker side is in test/web_offline_test.dart.
void main() {
  Future<Workspace> pump(WidgetTester tester) async {
    final ws = Workspace(systemClipboard: false);
    await ws.current.setLanguage('pt', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    return ws;
  }

  BuildContext shell(WidgetTester tester) => tester.element(find.byType(SizedBox).last);

  testWidgets('a newer build: the banner reloads into it, or waits for later', (tester) async {
    final ws = await pump(tester);
    var reloads = 0;
    showUpdateBanner(shell(tester), ws, unsaved: () => false, reload: () => reloads++);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update_banner')), findsOneWidget);
    expect(find.text('Há uma versão nova do OpenCADIrrigation pronta.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('update_later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update_banner')), findsNothing, reason: 'Later hides it');
    expect(reloads, 0);
    showUpdateBanner(shell(tester), ws, unsaved: () => false, reload: () => reloads++);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update_reload')));
    await tester.pumpAndSettle();
    expect(reloads, 1, reason: 'nothing to lose: it reloads at once');
  });

  testWidgets('with unsaved work it asks first, and the work goes to the autosave', (tester) async {
    final ws = await pump(tester);
    var reloads = 0;
    showUpdateBanner(shell(tester), ws, unsaved: () => true, reload: () => reloads++);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update_reload')));
    await tester.pumpAndSettle();
    expect(find.text('Recarregar agora?'), findsOneWidget);
    expect(find.textContaining('autossalvamento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(reloads, 0, reason: 'cancelled');
    await tester.tap(find.byKey(const Key('update_reload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update_reload_confirm')));
    await tester.pumpAndSettle();
    expect(reloads, 1);
  });
}
