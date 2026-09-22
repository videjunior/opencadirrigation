import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/widgets/fields.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';

void main() {
  Future<void> type(WidgetTester tester, String text) async {
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // focus leaves the field (as when the user clicks elsewhere)
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  }

  String shown(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('a number the model rejects is replaced by the value it keeps', (tester) async {
    var value = 5.0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (ctx, setState) => NumField(label: 'R', value: value, onChanged: (v) => setState(() => value = v <= 0 ? value : v.clamp(0, 360).toDouble()))),
      ),
    ));
    await type(tester, '-3');
    expect(value, 5);
    expect(shown(tester), '5.0', reason: 'the field must not keep showing the rejected number');
    await type(tester, '400');
    expect(value, 360);
    expect(shown(tester), '360.0');
    await type(tester, '12,5');
    expect(value, 12.5);
    expect(shown(tester), '12.50', reason: 'an accepted number is shown formatted');
    await type(tester, 'abc');
    expect(value, 12.5);
    expect(shown(tester), '12.50');
  });

  test('report cells: counts without decimals, other numbers with two', () {
    expect(reportCellText(3), '3');
    expect(reportCellText(2.345), '2.35');
    expect(reportCellText('x'), 'x');
  });
}
