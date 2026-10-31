import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/scene_cache.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The canvas keeps its drawing between frames: recorded once per scene,
/// moved with the view while a heavy scene pans, drawn sharp once it rests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(120, 80);

  late SceneCache cache;
  var records = 0;
  var slowMs = 0;

  void record(Canvas canvas, Size s) {
    records++;
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF204060));
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < slowMs) {}
  }

  void paint(Object key, Pt center, double scale) {
    final rec = ui.PictureRecorder();
    cache.paint(Canvas(rec), size, 1, key, center, scale, const Color(0xFF000000), record);
    rec.endRecording().dispose();
  }

  setUp(() {
    records = 0;
    slowMs = 0;
    cache = SceneCache();
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
    await Future<void>.delayed(SceneCache.settleAfter + const Duration(milliseconds: 80));
    expect(settled, 1, reason: 'the canvas is asked for a frame');
    paint('a', const Pt(4, 1), 1.5);
    expect(records, 2, reason: 'drawn sharp at the view it rests at');
    // a change of content is never shown moved
    paint('b', const Pt(6, 1), 1.5);
    expect(records, 3);
  });
}
