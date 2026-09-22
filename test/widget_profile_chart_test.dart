import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/widgets/profile_chart.dart';
import 'package:opencadirrigation/core/units.dart';

/// The terrain profile chart: ground, pipe and hydraulic grade line, and the
/// readout that follows the mouse, a tap or a drag.
void main() {
  const ground = [(0.0, 100.0), (50.0, 104.0), (100.0, 101.0)];
  const pipe = [(0.0, 99.2), (50.0, 103.2), (100.0, 100.2)];
  const hgl = [(0.0, 130.0), (100.0, 124.0)];

  Future<void> pumpChart(WidgetTester tester, {List<(double, double)> samples = ground, List<(double, double)>? pipeLine = pipe, List<(double, double)>? head = hgl}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 300,
            child: ProfileChart(samples: samples, units: Units.metric, title: 'Perfil', pipe: pipeLine, hgl: head, legendGround: 'Terreno', legendPipe: 'Tubo', legendHgl: 'LP', stationLabel: 'Est.', pressureLabel: 'P'),
          ),
        ),
      ),
    ));
  }

  /// Where the painter shows the readout (null when hidden).
  Offset? hoverOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(ProfileChart), matching: find.byType(CustomPaint)));
    return (paint.painter as dynamic).hover as Offset?;
  }

  testWidgets('the readout follows the mouse and hides when it leaves', (tester) async {
    await pumpChart(tester);
    final box = tester.getRect(find.byType(ProfileChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: box.center + const Offset(0, 400));
    await tester.pump();
    await mouse.moveTo(box.center);
    await tester.pump();
    expect(hoverOf(tester), box.center - box.topLeft);
    // near the right edge the label flips to the left of the cursor
    await mouse.moveTo(box.centerRight - const Offset(20, 0));
    await tester.pump();
    expect(hoverOf(tester)!.dx, closeTo(box.width - 20, 1e-9));
    await mouse.moveTo(box.center + const Offset(0, 400));
    await tester.pump();
    expect(hoverOf(tester), isNull);
    await mouse.removePointer();
  });

  testWidgets('a tap or a drag places the readout (touch screens)', (tester) async {
    await pumpChart(tester, head: null);
    final box = tester.getRect(find.byType(ProfileChart));
    await tester.tapAt(box.center);
    await tester.pump();
    expect(hoverOf(tester), box.center - box.topLeft);
    await tester.dragFrom(box.center, const Offset(80, 0));
    await tester.pump();
    expect(hoverOf(tester)!.dx, greaterThan(box.width / 2 + 40));
    // outside the plot area (the axis margin) nothing is read
    await tester.tapAt(box.topLeft + const Offset(4, 4));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flat or a one-sample profile still draws', (tester) async {
    await pumpChart(tester, samples: const [(0.0, 50.0), (10.0, 50.0)], pipeLine: null, head: null);
    expect(tester.takeException(), isNull);
    await tester.tapAt(tester.getCenter(find.byType(ProfileChart)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await pumpChart(tester, samples: const [(0.0, 50.0)]);
    expect(find.text('—'), findsOneWidget);
  });
}
