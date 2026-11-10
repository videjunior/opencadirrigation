import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/canvas/playback_overlay.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/programme_player_dialogs.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/ics.dart';
import 'package:opencadirrigation/main.dart';

/// Records the colours of the lines a painter draws in batches.
class _Lines implements Canvas {
  final colours = <int>[];
  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) {
    if (mode == ui.PointMode.lines) colours.add(paint.color.toARGB32());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The irrigation programme played on the plan (1.7.0) in the app: what the
/// player says without results or runs, play, pause, seek and the next
/// start over the drawing (the scene of the canvas is not recorded again),
/// the phone layout and the light theme, the exports (PNG, GIF with its
/// progress, calendar) and the assistant's operations.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1400, 900), String lang = 'en'}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c.autosaveEnabled = false;
    return c;
  }

  Future<void> designed(WidgetTester tester, ProjectController c, [ExampleId id = ExampleId.orchard]) async {
    loadExampleAction(c, id);
    await settle(tester, 2);
    await tester.runAsync(() => c.runDesign());
    await settle(tester, 2);
    expect(c.results, isNotNull, reason: c.lastMessage);
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  /// Waits (real time) until [done], pumping frames meanwhile.
  Future<void> waitFor(WidgetTester tester, bool Function() done, {int tries = 600}) async {
    for (var i = 0; i < tries && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('without results or without runs the player says what is missing and does not open', (tester) async {
    final c = await pumpShell(tester);
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    expect(c.results, isNull);
    showProgrammePlayer(ctxOf(tester), c);
    await settle(tester);
    expect(text(tester, 'ply_missing'), c.t('ply.needResults'));
    expect(find.byKey(const Key('ply_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('ply_missing_close')));
    await settle(tester);
    // a pivot in no system flow: the programme has no run
    await designed(tester, c, ExampleId.pivot);
    showProgrammePlayer(ctxOf(tester), c);
    await settle(tester);
    expect(text(tester, 'ply_missing'), c.t('ply.noRuns'));
    await tester.tap(find.byKey(const Key('ply_missing_close')));
    await settle(tester);
    expect(c.programmePlayer.shown, isFalse);
    // an empty project
    c.newProject();
    await settle(tester);
    showProgrammePlayer(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('ply_missing')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play, pause, seek and next start over the drawing; the scene is not recorded again', (tester) async {
    final c = await pumpShell(tester);
    await designed(tester, c);
    showProgrammePlayer(ctxOf(tester), c);
    await settle(tester);
    final pl = c.programmePlayer;
    final tl = pl.playback!.timeline;
    expect(pl.shown, isTrue);
    expect(find.byKey(const Key('ply_panel')), findsOneWidget);
    expect(tl.days, 12, reason: 'the orchard repeats after 12 days (flows every 12 and every 6 days)');
    expect(text(tester, 'ply_clock'), 'Day 1 06:00', reason: 'it opens at the first start');
    expect(text(tester, 'ply_cycle'), c.t('ply.cycleDays', {'n': '12'}));
    expect(text(tester, 'ply_running'), contains(pl.frame!.running.single.run.flowName));
    final seq = c.notifySeq;
    // the canvas draws the moment over its scene; a picture made off screen does not
    final onScreen = tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CadPainter)).painter! as CadPainter;
    final shown = _Lines();
    onScreen.paintOverlay(shown, const Size(800, 600));
    final velocity = {
      for (final g in pl.frame!.flows)
        for (final p in g.pipes) playbackVelocityColor(p.velocity, p.maxVelocity).toARGB32(),
    };
    expect(shown.colours.toSet().intersection(velocity), isNotEmpty, reason: 'the pipes that carry water, by velocity');
    final offScreen = _Lines();
    CadPainter(c: c, tool: null, snapResult: null, repaint: c).paintOverlay(offScreen, const Size(800, 600));
    expect(offScreen.colours.toSet().intersection(velocity), isEmpty);
    // play
    await tester.tap(find.byKey(const Key('ply_play')));
    await tester.pump();
    final speed = playbackSpeedFor(tl.hours);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(pl.hour, closeTo(6 + speed, 0.25 * speed), reason: 'a second of play is $speed h of the programme');
    expect(text(tester, 'ply_clock'), isNot('Day 1 06:00'));
    expect(c.notifySeq, seq, reason: 'playing repaints the overlay alone: the cached scene stays');
    // pause
    await tester.tap(find.byKey(const Key('ply_play')));
    await tester.pump();
    final paused = pl.hour;
    await settle(tester, 5);
    expect(pl.hour, paused);
    // seek with the slider: the second day, the other group
    tester.widget<Slider>(find.byKey(const Key('ply_slider'))).onChanged!(30.5);
    await tester.pump();
    expect(text(tester, 'ply_clock'), 'Day 2 06:30');
    expect(pl.frame!.running.single.flowId, isNot(tl.spans.first.flowId));
    // an idle moment
    tester.widget<Slider>(find.byKey(const Key('ply_slider'))).onChanged!(50);
    await tester.pump();
    expect(text(tester, 'ply_running'), c.t('ply.idle'));
    expect(pl.frame!.idle, isTrue);
    // the next start, and back to the start of the cycle
    await tester.tap(find.byKey(const Key('ply_next')));
    await tester.pump();
    expect(pl.hour, tl.nextStart(50));
    await tester.tap(find.byKey(const Key('ply_restart')));
    await tester.pump();
    expect(pl.hour, 0);
    expect(c.notifySeq, seq);
    // a new design: the player follows its results
    final before = pl.playback;
    await tester.runAsync(() => c.runDesign());
    await settle(tester, 2);
    expect(identical(pl.playback, before), isFalse);
    expect(identical(pl.playback!.results, c.results), isTrue);
    // an edit drops the results: the panel says so, and plays again after the next design
    c.mutate(() => c.project.params.maxZoneVelocity = 1.4);
    await settle(tester, 2);
    if (c.results == null) {
      expect(find.byKey(const Key('ply_stale')), findsOneWidget);
      expect(pl.shown, isFalse);
      await tester.runAsync(() => c.runDesign());
      await settle(tester, 2);
      expect(find.byKey(const Key('ply_stale')), findsNothing);
      expect(pl.shown, isTrue);
      expect(identical(pl.playback!.results, c.results), isTrue);
    }
    // another tab: the panel steps aside; back, it is there again
    final ws = (tester.state(find.byType(AppShell)) as dynamic).ws as Workspace;
    ws.addTab();
    await settle(tester);
    expect(find.byKey(const Key('ply_panel')), findsNothing);
    ws.select(0);
    await settle(tester);
    expect(find.byKey(const Key('ply_panel')), findsOneWidget);
    // close
    await tester.tap(find.byKey(const Key('ply_close')));
    await settle(tester);
    expect(find.byKey(const Key('ply_panel')), findsNothing);
    expect(pl.shown, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone layout and the light theme: the panel and the dialogs fit', (tester) async {
    final c = await pumpShell(tester, size: const Size(360, 740), lang: 'pt');
    addTearDown(() => setThemeMode(CadThemeMode.dark));
    setThemeMode(CadThemeMode.light);
    await designed(tester, c, ExampleId.golf);
    showProgrammePlayer(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('ply_panel')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('ply_panel'))).width, lessThanOrEqualTo(360));
    expect(text(tester, 'ply_clock'), 'Dia 1 06:00');
    await tester.tap(find.byKey(const Key('ply_gif')));
    await settle(tester);
    expect(find.byKey(const Key('ply_gif_export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ply_gif_cancel')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ply_ics')));
    await settle(tester);
    expect(find.byKey(const Key('ply_ics_export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ply_ics_cancel')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ply_close')));
    await settle(tester);
  });

  group('exports', () {
    final files = <String, Object>{};
    final saved = playbackFileSink;
    setUp(() {
      files.clear();
      playbackFileSink = (c, name, mime, data) async => files[name] = data;
    });
    tearDown(() => playbackFileSink = saved);

    testWidgets('the frame as a PNG, the cycle as a GIF with its progress, the programme as a calendar', (tester) async {
      final c = await pumpShell(tester);
      await designed(tester, c, ExampleId.greenhouse);
      showProgrammePlayer(ctxOf(tester), c);
      await settle(tester);
      // the frame shown, as a PNG
      await tester.tap(find.byKey(const Key('ply_png')));
      await waitFor(tester, () => files.keys.any((f) => f.endsWith('.png')));
      final png = files.values.whereType<Uint8List>().single;
      expect(String.fromCharCodes(png.sublist(1, 4)), 'PNG');
      // the animation: a few frames, the smallest size
      await tester.tap(find.byKey(const Key('ply_gif')));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byKey(const Key('ply_gif_frames')), matching: find.byType(TextField)), '6');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ply_gif_size')));
      await settle(tester);
      await tester.tap(find.text('320 px').last);
      await settle(tester);
      await tester.tap(find.byKey(const Key('ply_gif_export')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('ply_gif_progress')), findsOneWidget);
      await waitFor(tester, () => files.keys.any((f) => f.endsWith('.gif')));
      await settle(tester);
      final gif = img.decodeGif(files.entries.firstWhere((e) => e.key.endsWith('.gif')).value as Uint8List)!;
      expect(gif.numFrames, greaterThanOrEqualTo(6));
      expect(gif.numFrames, lessThanOrEqualTo(8), reason: 'six steps and one in each run they miss');
      // the drawing 320 px on its longest side, the band of the moment over it
      expect(gif.width == 320 || gif.height - playbackBandHeight(gif.width) == 320, isTrue, reason: '${gif.width}×${gif.height}');
      expect(find.byKey(const Key('ply_gif_export')), findsNothing, reason: 'the dialog closes when the file is made');
      // the calendar
      await tester.tap(find.byKey(const Key('ply_ics')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('ply_ics_export')));
      await waitFor(tester, () => files.keys.any((f) => f.endsWith('.ics')));
      await settle(tester);
      final ics = files.entries.firstWhere((e) => e.key.endsWith('.ics')).value as String;
      final lines = icsUnfold(ics);
      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines.where((l) => l == 'BEGIN:VEVENT').length, c.programmePlayer.playback!.timeline.runs.length);
      expect(lines.where((l) => l.startsWith('RRULE:')), everyElement('RRULE:FREQ=DAILY;COUNT=30'), reason: 'the greenhouse runs every day');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel stops the animation between two frames', (tester) async {
      final c = await pumpShell(tester);
      await designed(tester, c, ExampleId.greenhouse);
      showProgrammePlayer(ctxOf(tester), c);
      await settle(tester);
      await tester.tap(find.byKey(const Key('ply_gif')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('ply_gif_export')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ply_gif_cancel')));
      await waitFor(tester, () => find.byKey(const Key('ply_gif_export')).evaluate().isEmpty);
      expect(files.keys.where((f) => f.endsWith('.gif')), isEmpty);
      expect(c.lastMessage, c.t('ply.gif.cancelled'));
    });
  });

  group('the assistant', () {
    final files = <String, Object>{};
    final saved = engFileSink;
    setUp(() {
      files.clear();
      engFileSink = (c, name, mime, data) async => files[name] = data;
    });
    tearDown(() => engFileSink = saved);

    testWidgets('a picture at a moment, the animation, a frame and the calendar', (tester) async {
      final c = await pumpShell(tester);
      final box = AgentToolbox(c, snapshots: const CanvasSnapshots());
      AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);
      Future<(ToolOutput?, Object?)> run(String name, Map<String, dynamic> input) async {
        ToolOutput? out;
        Object? error;
        await tester.runAsync(() async {
          try {
            out = await op(name).run(input);
          } catch (e) {
            error = e;
          }
        });
        return (out, error);
      }

      expect(op('programme_picture').effect, ToolEffect.read);
      expect(op('export_programme_animation').effect, ToolEffect.export);
      expect(op('export_programme_calendar').effect, ToolEffect.export);
      // nothing to play yet
      loadExampleAction(c, ExampleId.orchard);
      await settle(tester, 2);
      final (_, noResults) = await run('programme_picture', {});
      expect('$noResults', contains('run_design'));
      await designed(tester, c);
      // the plan at 07:00 of the first day
      final (pic, e1) = await run('programme_picture', {'day': 1, 'time': '07:00', 'size': 512});
      expect(e1, isNull);
      expect(pic!.images, hasLength(1));
      final sf1 = c.project.systemFlows.first;
      expect(pic.text, contains('Moment day 1 07:00'));
      expect(pic.text, contains('running ${sf1.id}'));
      expect(pic.text, contains('Pumps: '));
      expect(pic.text, contains('Cycle: 12 days'));
      expect(pic.text, contains('How to read it'));
      // a day alone: its first start
      final (day2, _) = await run('programme_picture', {'day': 2, 'size': 400});
      expect(day2!.text, contains('Moment day 2 06:00'));
      // at rest
      final (rest, _) = await run('programme_picture', {'day': 1, 'time': '03:00'});
      expect(rest!.text, contains('the system is at rest'));
      // a bad time
      final (_, bad) = await run('programme_picture', {'time': '25:10'});
      expect('$bad', contains('"time"'));
      // the animation and a frame
      final (gifOut, e2) = await run('export_programme_animation', {'frames': 4, 'size': 200});
      expect(e2, isNull, reason: '$e2');
      expect(gifOut!.text, startsWith('Saved '));
      final gif = img.decodeGif(files.entries.firstWhere((e) => e.key.endsWith('.gif')).value as Uint8List)!;
      expect(gif.numFrames, greaterThanOrEqualTo(4));
      expect(gif.width == 200 || gif.height - playbackBandHeight(gif.width) == 200, isTrue, reason: '${gif.width}×${gif.height}');
      final (pngOut, e3) = await run('export_programme_animation', {'format': 'png', 'day': 2, 'time': '08:00', 'size': 400});
      expect(e3, isNull, reason: '$e3');
      expect(pngOut!.text, contains('day 2 08:00'));
      expect(files.keys.where((f) => f.endsWith('.png')), hasLength(1));
      // the calendar
      final (calOut, e4) = await run('export_programme_calendar', {'days': 60});
      expect(e4, isNull, reason: '$e4');
      final ics = files.entries.firstWhere((e) => e.key.endsWith('.ics')).value as String;
      expect(icsUnfold(ics).where((l) => l == 'BEGIN:VEVENT').length, 3);
      expect(calOut!.text, contains('3 events'));
      expect(calOut.text, contains('INTERVAL=12'));
      expect(c.programmePlayer.shown, isFalse, reason: 'the operations leave the user\'s screen as it is');
    });
  });
}
