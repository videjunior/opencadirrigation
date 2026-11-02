import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/scene_cache.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The canvas keeps its drawing between frames: recorded once per scene,
/// moved with the view while a heavy scene pans, drawn sharp once it rests.
///
/// The cache reads the time from a clock the test owns: a scene takes as
/// long to draw as the test says, and the view rests as long as the test
/// says, however loaded the machine is (with the wall clock, a light scene
/// whose rasterising took over 20 ms on a busy runner turned heavy).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(120, 80);

  late SceneCache cache;
  var records = 0;
  var slowMs = 0;
  var now = Duration.zero;

  void record(Canvas canvas, Size s) {
    records++;
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF204060));
    now += Duration(milliseconds: slowMs);
  }

  void paint(Object key, Pt center, double scale) {
    final rec = ui.PictureRecorder();
    cache.paint(Canvas(rec), size, 1, key, center, scale, const Color(0xFF000000), record);
    rec.endRecording().dispose();
  }

  setUp(() {
    records = 0;
    slowMs = 0;
    now = const Duration(minutes: 5);
    cache = SceneCache(clock: () => now);
  });
  tearDown(() => cache.dispose());

  test('one recording per scene; the content or the view changing records it again', () {
    paint('a', Pt.zero, 1);
    paint('a', Pt.zero, 1);
    paint('a', Pt.zero, 1);
    expect(records, 1, reason: 'the cursor moved, the scene did not');
    paint('b', Pt.zero, 1);
    expect(records, 2, reason: 'an edit, a selection...');
    paint('b', const Pt(3, 0), 1);
    paint('b', const Pt(3, 0), 2);
    expect(records, 4, reason: 'a light scene is drawn again at every step of a pan or a zoom');
    expect(cache.heavy, isFalse);
    cache.clear();
    paint('b', const Pt(3, 0), 2);
    expect(records, 5);
  });

  test('a scene is heavy past heavyMs of drawing, light up to it', () {
    slowMs = SceneCache.heavyMs.toInt();
    paint('a', Pt.zero, 1);
    expect(cache.heavy, isFalse, reason: 'exactly the limit is still light');
    slowMs++;
    paint('b', Pt.zero, 1);
    expect(cache.heavy, isTrue);
    slowMs = 0;
    paint('c', Pt.zero, 1);
    expect(cache.heavy, isFalse, reason: 'measured again at every recording');
  });

  test('a heavy scene follows the view as a picture and is drawn sharp once the view rests', () async {
    var settled = 0;
    cache.onSettle = () => settled++;
    slowMs = 30;
    paint('a', Pt.zero, 1);
    paint('a', Pt.zero, 1);
    expect(cache.heavy, isTrue);
    expect(records, 1);
    // a pan and a zoom: the picture moves, nothing is recorded
    paint('a', const Pt(2, 1), 1);
    paint('a', const Pt(4, 1), 1.5);
    expect(records, 1);
    // the settle timer runs on real time; it fires before this longer delay
    await Future<void>.delayed(SceneCache.settleAfter + const Duration(milliseconds: 80));
    expect(settled, 1, reason: 'the canvas is asked for a frame');
    paint('a', const Pt(4, 1), 1.5);
    expect(records, 2, reason: 'drawn sharp at the view it rests at');
    // a change of content is never shown moved
    paint('b', const Pt(6, 1), 1.5);
    expect(records, 3);
  });

  test('while the view keeps moving, a moved picture is drawn again every refreshAfter', () {
    slowMs = 30;
    paint('a', Pt.zero, 1);
    paint('a', const Pt(1, 0), 1);
    expect(records, 1, reason: 'moved');
    now += const Duration(milliseconds: SceneCache.refreshAfter - 1);
    paint('a', const Pt(2, 0), 1);
    expect(records, 1, reason: 'still within the refresh interval');
    now += const Duration(milliseconds: 1);
    paint('a', const Pt(3, 0), 1);
    expect(records, 2, reason: 'the parts that came into view fill in');
    // a very slow scene waits five times its drawing time instead
    slowMs = 100;
    paint('b', Pt.zero, 1);
    paint('b', const Pt(1, 0), 1);
    now += const Duration(milliseconds: 499);
    paint('b', const Pt(2, 0), 1);
    expect(records, 3, reason: 'moved: 499 ms < 5 × 100 ms');
    now += const Duration(milliseconds: 1);
    paint('b', const Pt(3, 0), 1);
    expect(records, 4);
  });

  test('without a clock of its own the cache records and reuses the scene', () {
    final c = SceneCache();
    addTearDown(c.dispose);
    var n = 0;
    for (var i = 0; i < 3; i++) {
      final rec = ui.PictureRecorder();
      c.paint(Canvas(rec), size, 1, 'k', Pt.zero, 1, const Color(0xFF000000), (canvas, s) {
        n++;
        canvas.drawRect(Offset.zero & s, Paint());
      });
      rec.endRecording().dispose();
    }
    expect(n, 1);
  });
}
