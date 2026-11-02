import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/data_terms_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/field_map_dialog.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// Help → Terms of the data (PRD-06) and View → Base map → Keep the map of the area for the field (PRD-09): what
/// the project carries from other sources and what each source allows, what the base map on screen allows for a map
/// kept for the field; both lay out on a phone, right to left and with the text twice as big.
void main() {
  Future<(ProjectController, BuildContext)> pump(WidgetTester tester, {Size size = const Size(1280, 800), bool rtl = false, double textScale = 1}) async {
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    // (the right-to-left layout itself: a pack loaded from the assets is slow in a widget test)
    await c.setLanguage('en', persist: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        builder: (context, child) => Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: child ?? const SizedBox()),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    return (c, tester.element(find.byType(SizedBox).last));
  }

  testWidgets('the terms of the data: what this project carries, and each source', (tester) async {
    final (c, context) = await pump(tester);
    c.project.climate = SiteClimate(etoMmDay: List.filled(12, 5), rainMm: List.filled(12, 60), source: 'openMeteo', attribution: ClimateSource.openMeteo.attribution, retrieved: '2026-11-02');
    showDataTermsDialog(context, c);
    await tester.pumpAndSettle();
    expect(find.text(c.t('terms.title')), findsOneWidget);
    expect(find.byKey(const ValueKey('terms_used_climate')), findsOneWidget, reason: 'the downloaded climate and its credit');
    expect(find.textContaining('Open-Meteo'), findsWidgets);
    expect(find.text(c.t('terms.src.nasaPower')), findsOneWidget);
    // the base maps' own terms open from here
    await tester.ensureVisible(find.byKey(const Key('terms_maps')));
    await tester.tap(find.byKey(const Key('terms_maps')));
    await tester.pumpAndSettle();
    expect(find.text(c.t('basemap.terms.title')), findsOneWidget);
  });

  testWidgets('the field map: refused for Google, explained for a shared server, disabled without a georeference', (tester) async {
    final (c, context) = await pump(tester);
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-20.3, -47.4);
    c.baseMap = BaseMap.googleSatellite;
    showFieldMapDialog(context, c);
    await tester.pumpAndSettle();
    expect(find.text(c.t('fieldmap.err.google')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('fieldmap_keep'))).onPressed, isNull);
    await tester.tap(find.text(c.t('cancel')));
    await tester.pumpAndSettle();
    c.baseMap = BaseMap.streets;
    showFieldMapDialog(context, c);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('fieldmap_what'))).data, contains('OpenStreetMap'));
    expect(tester.widget<FilledButton>(find.byKey(const Key('fieldmap_keep'))).onPressed, isNotNull);
    await tester.tap(find.text(c.t('cancel')));
    await tester.pumpAndSettle();
    c.project.meta.georef = null;
    showFieldMapDialog(context, c);
    await tester.pumpAndSettle();
    expect(find.text(c.t('fieldmap.err.noGeo')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('fieldmap_keep'))).onPressed, isNull);
  });

  for (final (name, size, rtl, scale) in const [('phone', Size(360, 640), false, 1.0), ('right to left', Size(360, 640), true, 1.0), ('text twice as big', Size(1280, 800), false, 2.0)]) {
    testWidgets('both dialogs lay out: $name', (tester) async {
      final (c, context) = await pump(tester, size: size, rtl: rtl, textScale: scale);
      c.baseMap = BaseMap.streets;
      for (final show in [showDataTermsDialog, showFieldMapDialog]) {
        show(context, c);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        expect(find.byType(Dialog), findsOneWidget);
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
