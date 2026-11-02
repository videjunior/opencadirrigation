import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/mobile_shell.dart';
import 'package:opencadirrigation/app/widgets/properties_panel.dart';
import 'package:opencadirrigation/app/widgets/status_bar.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Records the colours the canvas painter draws with.
/// (as ARGB: a paint gives its colour back in single precision).
class _Recorder implements Canvas {
  final rects = <int>[];
  final lines = <int>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(paint.color.toARGB32());
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add(paint.color.toARGB32());

  /// Segments the painter gathers by paint.
  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) {
    if (mode == ui.PointMode.lines) lines.add(paint.color.toARGB32());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// WCAG contrast of [fg] (blended over [bg]) against [bg].
double _contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg).computeLuminance(), b = bg.computeLuminance();
  return (math.max(f, b) + 0.05) / (math.min(f, b) + 0.05);
}

/// View → Theme: dark (the original look), light and the system's, switched
/// in place; the canvas in light mode; plots unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    removePref('theme');
    Cad.use(Brightness.dark);
  });

  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1600, 1000), bool example = false}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, startExample: ExampleId.orchard));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c.autosaveEnabled = false;
    if (!example) c.newProject();
    await settle(tester);
    return c;
  }

  /// The colours of the texts under [of], each with the colour it is
  /// actually painted in (the default text style merged in).
  List<(String, Color)> texts(WidgetTester tester, Finder of) => [
    for (final e in find.descendant(of: of, matching: find.byType(RichText)).evaluate())
      if (e.renderObject case final RenderParagraph p when p.text.toPlainText().trim().isNotEmpty && p.text.style?.color != null) (p.text.toPlainText(), p.text.style!.color!),
  ];

  _Recorder paintCanvas(ProjectController c) {
    final r = _Recorder();
    CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(r, const Size(800, 600));
    return r;
  }

  test('the dark palette is the original look, colour for colour', () {
    const p = CadPalette.dark;
    for (final (token, original) in [
      (p.fg, Colors.white),
      (p.fg70, Colors.white70),
      (p.fg60, Colors.white60),
      (p.fg54, Colors.white54),
      (p.fg38, Colors.white38),
      (p.fg30, Colors.white30),
      (p.fg24, Colors.white24),
      (p.fg12, Colors.white12),
      (p.fg10, Colors.white10),
      (p.caution, Colors.orange),
      (p.attention, Colors.orangeAccent),
      (p.positive, Colors.lightGreenAccent),
      (p.amber, Colors.amber),
      (p.okAlt, Colors.green),
    ]) {
      expect(token.toARGB32(), original.toARGB32());
    }
    expect(p.scrim, Colors.black.withValues(alpha: 0.5));
    expect([p.canvas, p.gridMinor, p.gridMajor, p.axis, p.selection, p.hover, p.snap, p.preview, p.unconnected, p.warning, p.ok].map((x) => x.toARGB32()), [
      0xFF14171B, 0xFF20262D, 0xFF2B333C, 0xFF3B4650, 0xFFFFD54F, 0xFF80DEEA, 0xFF69F0AE, 0xFFB0BEC5, 0xFFFF1744, 0xFFFFA726, 0xFF66BB6A, //
    ]);
    final th = buildCadTheme(Brightness.dark);
    expect(th.brightness, Brightness.dark);
    expect(th.scaffoldBackgroundColor, const Color(0xFF14171B));
    expect(th.canvasColor, const Color(0xFF1B1F24));
    expect(th.dividerColor, const Color(0xFF2B3138));
    expect(th.dialogTheme.backgroundColor, const Color(0xFF1F2429));
    expect(th.colorScheme.surface, const Color(0xFF1B1F24));
    // the drawing shows its own colours on the dark canvas
    expect(Cad.ink(const Color(0xFFFFFFFF)), const Color(0xFFFFFFFF));
  });

  test('the light palette keeps WCAG AA for the text on its surfaces', () {
    const p = CadPalette.light;
    final surfaces = {
      'panel': p.panel,
      'panelAlt': p.panelAlt,
      'menu': p.menu,
      'dialog': p.dialog,
      'card': p.card,
      'cardHigh': p.cardHigh,
      'background': p.background,
      'raised': p.raised,
      'bubble': p.bubble,
      'tintInfo': p.tintInfo,
      'tintWarning': p.tintWarning,
    };
    final text = {
      'fg': p.fg, 'fg87': p.fg87, 'fg70': p.fg70, 'fg60': p.fg60, 'fg54': p.fg54, 'fg38': p.fg38, 'bodyText': p.bodyText, 'accentText': p.accentText, 'accentIcon': p.accentIcon, //
      'info': p.info, 'codeText': p.codeText, 'ok': p.ok, 'okAlt': p.okAlt, 'positive': p.positive, 'warning': p.warning, 'caution': p.caution, 'attention': p.attention, //
      'amber': p.amber, 'highlight': p.highlight, 'error': p.error, 'unconnected': p.unconnected,
    };
    for (final s in surfaces.entries) {
      for (final f in text.entries) {
        expect(_contrast(f.value, s.value), greaterThanOrEqualTo(4.5), reason: '${f.key} on ${s.key}');
      }
    }
    // the canvas: labels, grid figures and the result colours on white
    for (final f in [p.canvasText, p.gridLabel, p.warning, p.unconnected]) {
      expect(_contrast(f, p.canvas), greaterThanOrEqualTo(4.5));
    }
    for (final f in [p.selection, p.hover, p.snap, p.preview, p.gps, p.profilePath, p.stakeOut, p.wireOk]) {
      expect(_contrast(f, p.canvas), greaterThanOrEqualTo(3), reason: 'marks on the canvas');
    }
    // white on the filled accents
    for (final f in [p.accentFill, p.okFill, p.accent]) {
      expect(_contrast(Colors.white, f), greaterThanOrEqualTo(4.2));
    }
  });

  testWidgets('View → Theme switches in place: same shell, project and selection; dark text, light canvas', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    final shell = tester.state(find.byType(AppShell));
    final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(40, 0));
    c.addEntity(line);
    c.select([line.id]);
    c.zoomAll();
    await settle(tester);
    final entities = c.project.entities.length;
    expect(Cad.isLight, isFalse);
    expect(paintCanvas(c).rects.first, CadPalette.dark.canvas.toARGB32());

    await tester.tap(find.text(t('menu.view')).first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_theme')));
    await settle(tester, 2);
    expect(find.text(t('view.theme.system')), findsOneWidget);
    // (a radio menu item hands its key on to the button inside it)
    await tester.tap(find.byKey(const Key('menu_theme_light')).first);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(Cad.isLight, isTrue);
    expect(uiThemeMode.value, CadThemeMode.light);
    // nothing was rebuilt from scratch: the same shell, controller, project and selection
    expect(identical(tester.state(find.byType(AppShell)), shell), isTrue);
    expect(identical((shell as dynamic).c, c), isTrue);
    expect(c.project.entities.length, entities);
    expect(c.selection, contains(line.id));
    // the material theme and the panels follow
    final status = tester.element(find.byType(StatusBar));
    expect(Theme.of(status).brightness, Brightness.light);
    expect(Theme.of(status).scaffoldBackgroundColor, CadPalette.light.background);
    final panelTexts = [...texts(tester, find.byType(PropertiesPanel)), ...texts(tester, find.byType(StatusBar))];
    expect(panelTexts, isNotEmpty);
    // (white is only used on the filled accents, e.g. a toggle that is on)
    for (final (s, col) in panelTexts.where((x) => x.$2 != Colors.white)) {
      expect(Color.alphaBlend(col, Cad.panel).computeLuminance(), lessThan(0.25), reason: '"$s" is dark on the light panel');
      expect(_contrast(col, Cad.panel), greaterThanOrEqualTo(4.5), reason: '"$s"');
    }
    // the canvas: light background and grid, selection colour for a light background
    final light = paintCanvas(c);
    expect(light.rects.first, 0xFFFFFFFF);
    expect(light.lines, contains(CadPalette.light.selection.toARGB32()));
    final canvasPainter = tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CadPainter)).painter! as CadPainter;
    final shown = _Recorder();
    // (the canvas keeps its scene in a picture: ask for the scene itself)
    canvasPainter.paintScene(shown, const Size(400, 300));
    expect(shown.rects.first, CadPalette.light.canvas.toARGB32());

    // a dialog: light surface, dark text
    await tester.tap(find.text(t('menu.help')).first);
    await settle(tester, 2);
    await tester.tap(find.text(t('help.about')).last);
    await settle(tester);
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    final surface = Theme.of(tester.element(dialog)).dialogTheme.backgroundColor!;
    expect(surface.computeLuminance(), greaterThan(0.9));
    final dialogTexts = texts(tester, dialog);
    expect(dialogTexts, isNotEmpty);
    for (final (s, col) in dialogTexts) {
      expect(_contrast(col, surface), greaterThanOrEqualTo(4.5), reason: '"$s" in the About dialog');
    }
    await tester.tapAt(const Offset(5, 500));
    await settle(tester);

    // and back to dark, still in place
    setThemeMode(CadThemeMode.dark);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(Cad.isLight, isFalse);
    expect(Theme.of(tester.element(find.byType(StatusBar))).brightness, Brightness.dark);
    expect(identical(tester.state(find.byType(AppShell)), shell), isTrue);
    expect(c.selection, contains(line.id));
    expect(paintCanvas(c).rects.first, CadPalette.dark.canvas.toARGB32());
    for (final (s, col) in texts(tester, find.byType(StatusBar))) {
      expect(col.computeLuminance(), greaterThan(0.5), reason: '"$s" is light again on the dark panel');
    }
  });

  testWidgets('phone: the menu switches the theme; the sheets build in light', (tester) async {
    final c = await pumpShell(tester, size: const Size(420, 860), example: true);
    final t = c.t;
    expect(find.byType(MobileShell), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 2);
    Finder inMenu(Finder f) => find.descendant(of: find.byKey(const Key('mobile_menu_sheet')), matching: f);
    Future<void> choose(CadThemeMode m) async {
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
      await tester.tap(inMenu(find.text(t('menu.view'))));
      await settle(tester);
      final row = inMenu(find.text('${t('view.theme')}: ${t('view.theme.${m.name}')}'));
      await tester.ensureVisible(row);
      await settle(tester, 1);
      await tester.tap(row);
      await settle(tester);
    }

    await choose(CadThemeMode.light);
    expect(tester.takeException(), isNull);
    expect(Cad.isLight, isTrue);
    expect(getPref('theme'), 'light');
    expect(Theme.of(tester.element(find.byType(MobileShell))).brightness, Brightness.light);
    for (final sheet in ['mobile_props', 'mobile_reports']) {
      await tester.tap(find.byKey(Key(sheet)));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: sheet);
      await tester.tapAt(const Offset(200, 20));
      await settle(tester);
    }
    await choose(CadThemeMode.dark);
    expect(tester.takeException(), isNull);
    expect(Cad.isLight, isFalse);
    expect(c.project.entities, isNotEmpty);
  });

  testWidgets('a white layer draws near-black on the light canvas and plots unchanged', (tester) async {
    final c = await pumpShell(tester);
    c.project.layerNamed(Layers.drawing).color = 0xFFFFFFFF;
    c.project.layerNamed(Layers.text).color = 0xFFFFEE58;
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(40, 0)));
    c.addEntity(LineEntity(id: c.project.newId(), layer: Layers.text, a: const Pt(0, 10), b: const Pt(40, 10)));
    c.select(const []);
    c.showGrid = false;
    c.zoomAll();
    List<int> plotted() => [
      for (final i in buildPlotScene(c.project, unitsPerMm: 0.5).items)
        if (i.layer == Layers.drawing || i.layer == Layers.text) i.color,
    ];
    final darkPlot = plotted();
    final dark = paintCanvas(c).lines;
    expect(dark, containsAll([0xFFFFFFFF, 0xFFFFEE58]));

    setThemeMode(CadThemeMode.light);
    await settle(tester);
    expect(Cad.isLight, isTrue);
    final light = paintCanvas(c).lines;
    expect(light, isNot(contains(0xFFFFFFFF)));
    // white → near-black, light yellow → a darker yellow of the same hue
    final ink = Cad.ink(const Color(0xFFFFFFFF));
    expect(light, contains(ink.toARGB32()));
    expect(ink.computeLuminance(), lessThan(0.05));
    expect(ink.a, 1);
    final yellow = Cad.ink(const Color(0xFFFFEE58));
    expect(light, contains(yellow.toARGB32()));
    expect(yellow.computeLuminance(), lessThanOrEqualTo(0.205));
    expect(HSVColor.fromColor(yellow).hue, closeTo(HSVColor.fromColor(const Color(0xFFFFEE58)).hue, 2));
    // the layer itself keeps its colour, and the plot is paper: the same in both themes
    expect(c.project.layerNamed(Layers.drawing).color, 0xFFFFFFFF);
    expect(plotted(), darkPlot);
    expect(darkPlot, contains(printColor(0xFFFFFFFF)));
  });

  testWidgets('the choice is saved and applied at start-up', (tester) async {
    await pumpShell(tester);
    expect(getPref('theme'), isNull);
    setThemeMode(CadThemeMode.light);
    await settle(tester);
    expect(getPref('theme'), 'light');
    // a new start: the saved choice wins over the default
    await tester.pumpWidget(const SizedBox());
    uiThemeMode.value = CadThemeMode.dark;
    Cad.use(Brightness.dark);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, startExample: ExampleId.orchard));
    await settle(tester);
    expect(uiThemeMode.value, CadThemeMode.light);
    expect(Cad.isLight, isTrue);
    expect(Theme.of(tester.element(find.byType(StatusBar))).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
    // and an unknown saved value falls back to dark
    setPref('theme', 'sepia');
    expect(savedThemeMode(), CadThemeMode.dark);
  });

  testWidgets('Follow the system: the platform brightness decides, live', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final c = await pumpShell(tester);
    setThemeMode(CadThemeMode.system);
    await settle(tester);
    expect(Cad.isLight, isFalse);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(Cad.isLight, isTrue);
    expect(Theme.of(tester.element(find.byType(StatusBar))).brightness, Brightness.light);
    expect(paintCanvas(c).rects.first, CadPalette.light.canvas.toARGB32());
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await settle(tester);
    expect(Cad.isLight, isFalse);
    expect(Theme.of(tester.element(find.byType(StatusBar))).brightness, Brightness.dark);
    // an explicit choice ignores the platform
    setThemeMode(CadThemeMode.light);
    await settle(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await settle(tester);
    expect(Cad.isLight, isTrue);
    expect(getPref('theme'), 'light');
  });

  test('pictures for the AI assistant keep the dark canvas', () {
    Cad.use(Brightness.light);
    final c = ProjectController()..autosaveEnabled = false;
    final r = _Recorder();
    Cad.paintWith(CadPalette.dark, () => CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(r, const Size(200, 100)));
    expect(r.rects.first, CadPalette.dark.canvas.toARGB32());
    expect(Cad.isLight, isTrue, reason: 'the interface palette is restored');
  });
}
