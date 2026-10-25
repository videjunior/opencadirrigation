import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/gps.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The device GPS in the field: the first fix georeferences a new project,
/// a walk becomes an area or a line in one undo step, imprecise fixes are
/// left out, and the distance and bearing to a designed item guide the
/// staking out.
void main() {
  late void Function(GpsFix) feed;
  late void Function(String) fail;
  var stopped = 0;

  setUp(() {
    stopped = 0;
    ProjectController.gpsWatcher = (onFix, onError) {
      feed = onFix;
      fail = onError;
      return () => stopped++;
    };
  });

  ProjectController fresh() {
    final c = ProjectController();
    c.setLanguage('pt');
    c.newProject();
    return c;
  }

  GpsFix fix(double lat, double lon, {double acc = 3}) => GpsFix(lat: lat, lon: lon, accuracyM: acc, time: DateTime(2026, 10, 25, 9, 30));

  test('the first fix georeferences the project at the device', () {
    final c = fresh();
    expect(c.project.meta.georef, isNull);
    c.startGps();
    expect(c.gpsActive, isTrue);
    feed(fix(-15.78, -47.93));
    expect(c.project.meta.georef!.zone, 23);
    expect(c.gpsPoint!.length, lessThan(1e-6));
    c.stopGps();
    expect(stopped, 1);
    expect(c.gpsPoint, isNull);
  });

  test('a walk becomes an irrigated area; imprecise fixes are left out', () {
    final c = fresh();
    c.startGps();
    feed(fix(-15.78, -47.93));
    c.startGpsTrack();
    // a square of about 100 m, every 0.0001° (≈ 11 m)
    for (var i = 1; i <= 9; i++) {
      feed(fix(-15.78, -47.93 + i * 0.0001));
    }
    feed(fix(-15.779, -47.9291, acc: 40)); // a jump in a poor fix
    for (var i = 1; i <= 9; i++) {
      feed(fix(-15.78 + i * 0.0001, -47.9291));
    }
    for (var i = 8; i >= 0; i--) {
      feed(fix(-15.7791, -47.93 + i * 0.0001));
    }
    final walked = c.gpsTrack!.length;
    expect(walked, 28);
    final before = c.historyIndex;
    final area = c.finishGpsTrack(asArea: true) as AreaEntity;
    expect(c.gpsTrack, isNull);
    expect(area.points.length, walked);
    expect(area.area, closeTo(96 * 100, 1500));
    expect(c.historyIndex, before + 1);
    c.undo();
    expect(c.project.entities.whereType<AreaEntity>(), isEmpty);
  });

  test('a short walk adds nothing; a point is marked at the device', () {
    final c = fresh();
    c.startGps();
    feed(fix(-15.78, -47.93));
    c.startGpsTrack();
    expect(c.finishGpsTrack(), isNull);
    final m = c.markGpsPoint() as CircleEntity;
    expect(m.center.length, lessThan(1e-6));
    expect(m.name, startsWith('Ponto GPS'));
  });

  test('distance and bearing to a designed item for staking out', () {
    final c = fresh();
    c.startGps();
    feed(fix(-15.78, -47.93));
    final p = c.gpsPoint!;
    final (d, b) = c.gpsTo(p + const Pt(10, 0))!;
    expect(d, closeTo(10, 1e-9));
    expect(b, closeTo(90, 1e-9));
    expect(c.gpsTo(p + const Pt(0, -5))!.$2, closeTo(180, 1e-9));
    expect(c.gpsTo(p + const Pt(-3, 3))!.$2, closeTo(315, 1e-9));
  });

  test('a refused permission stops the GPS with a message', () {
    final c = fresh();
    c.startGps();
    fail('denied');
    expect(c.gpsActive, isFalse);
    expect(c.lastMessage, contains('negada'));
  });
}
