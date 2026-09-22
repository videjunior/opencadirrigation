import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/export_dialogs.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/main.dart';

/// The georeference dialog (latitude/longitude, UTM, pasted pairs, invalid
/// input, removal) and the PDF plot options.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    await settle(tester);
    return c;
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(AppShell));

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final f = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));
    await tester.enterText(f.first, value);
    await settle(tester, 1);
  }

  testWidgets('georeference: UTM origin, invalid input, a pasted pair and removal', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    c.project.meta.georef = null;
    // UTM mode: an invalid zone is refused with a message, a valid one is set
    var result = showGeoreferenceDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text(t('geo.modeUtm')));
    await settle(tester, 1);
    await enter(tester, t('geo.zone'), '61');
    await enter(tester, t('geo.easting'), '186 056,58');
    await enter(tester, t('geo.northing'), '8253215.21');
    await tester.tap(find.byKey(const Key('geo_ok')));
    await settle(tester, 1);
    expect(find.text(t('geo.invalid')), findsOneWidget);
    await enter(tester, t('geo.zone'), '23');
    await tester.tap(find.widgetWithText(SwitchListTile, t('geo.north')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('geo_ok')));
    await settle(tester);
    expect(await result, isTrue);
    final g = c.project.meta.georef!;
    expect((g.zone, g.north, g.originEasting, g.originNorthing), (23, true, 186056.58, 8253215.21));

    // latitude and longitude pasted as one pair in the first field
    result = showGeoreferenceDialog(ctx(tester), c);
    await settle(tester);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('UTM 23N')), findsOneWidget, reason: 'the current georeference is shown');
    await tester.tap(find.text(t('geo.modeLatLon')));
    await settle(tester, 1);
    await enter(tester, t('geo.lat'), '-22.9068, -43.1729');
    await enter(tester, t('geo.lon'), '');
    await tester.tap(find.byKey(const Key('geo_ok')));
    await settle(tester);
    expect(await result, isTrue);
    final (lat, lon) = c.project.meta.georef!.toLatLon(0, 0);
    expect(lat, closeTo(-22.9068, 1e-6));
    expect(lon, closeTo(-43.1729, 1e-6));
    expect(c.project.meta.georef!.zone, 23);

    // cancel keeps it; remove drops it
    result = showGeoreferenceDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text(t('cancel')));
    await settle(tester);
    expect(await result, isTrue);
    result = showGeoreferenceDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text(t('geo.remove')));
    await settle(tester);
    expect(await result, isFalse);
    expect(c.project.meta.georef, isNull);
    expect(c.dirty, isTrue);
  });

  testWidgets('plot options: page, orientation, a typed scale and the check boxes', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    var result = showPlotDialog(ctx(tester), c);
    await settle(tester);
    // page A1 in portrait
    await tester.tap(find.byType(DropdownButtonFormField<PageSize>));
    await settle(tester, 2);
    await tester.tap(find.textContaining('A1  (').last);
    await settle(tester, 2);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await settle(tester, 2);
    await tester.tap(find.text(t('plot.portrait')).last);
    await settle(tester, 2);
    // a scale typed in full once "fit to sheet" is off
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.scaleAuto')));
    await settle(tester, 1);
    await enter(tester, t('plot.scale'), '1:750');
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.labels')));
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.wetted')));
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.legend')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o = (await result)!;
    expect((o.page, o.landscape, o.scale), (PageSize.a1, false, 750.0));
    expect((o.labels, o.wettedRadii, o.legend), (false, false, false));

    // "fit to sheet" back on: the scale field shows the automatic one and is ignored
    result = showPlotDialog(ctx(tester), c, initial: const SheetOptions(scale: 200));
    await settle(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.scaleAuto')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    expect((await result)!.scale, isNull);
    // nonsense in the field fits the sheet too; cancel returns nothing
    result = showPlotDialog(ctx(tester), c, initial: const SheetOptions(scale: 200));
    await settle(tester);
    await enter(tester, t('plot.scale'), 'abc');
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    expect((await result)!.scale, isNull);
    result = showPlotDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.text(t('cancel')));
    await settle(tester);
    expect(await result, isNull);
  });
}
