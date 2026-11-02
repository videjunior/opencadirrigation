/// The catalogue editor in the units of the project (1.6.0 MOD, MOD-20):
/// a project in US units shows the pipes in inches, psi and price per foot
/// and the pump curves in gpm; a metric one as before.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/more_dialogs.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  Future<ProjectController> open(WidgetTester tester, Units units) async {
    setPref('lang', 'en');
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.project.params.units = units;
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(onPressed: () => showCatalogEditorDialog(ctx, c), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return c;
  }

  testWidgets('US units: inches, psi, price per foot; the pump curve in gpm', (tester) async {
    final c = await open(tester, Units.us);
    expect(find.text(c.t('cat.idU', {'u': 'in'})), findsOneWidget);
    expect(find.text(c.t('cat.pnU', {'u': 'psi'})), findsOneWidget);
    expect(find.text(c.t('cat.costFt', {'c': c.project.params.currency})), findsOneWidget);
    expect(find.textContaining(c.t('cat.unitsNote').substring(0, 20)), findsOneWidget);
    await tester.tap(find.text(c.t('cat.pumps')).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text(c.t('cat.pointsU', {'q': 'gpm', 'h': 'psi'})), findsOneWidget);
    await tester.tap(find.byKey(const Key('cat_cancel')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('metric units: the columns as they were', (tester) async {
    final c = await open(tester, Units.metric);
    expect(find.text(c.t('cat.idmm')), findsOneWidget);
    expect(find.text(c.t('cat.pn')), findsOneWidget);
    expect(find.text(c.t('cat.costM', {'c': c.project.params.currency})), findsOneWidget);
    expect(find.textContaining(c.t('cat.unitsNote').substring(0, 20)), findsNothing);
    await tester.tap(find.byKey(const Key('cat_cancel')));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
