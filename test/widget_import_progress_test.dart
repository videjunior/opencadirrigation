import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/import_progress_dialog.dart';
import 'package:opencadirrigation/core/model/entities.dart';

/// File → Import shows the progress of a long reading with a cancel button
/// (FMT-23); a quick import finishes without it.
Uint8List _dxf(int n) {
  final b = StringBuffer('0\nSECTION\n2\nENTITIES\n');
  for (var i = 0; i < n; i++) {
    b.write('0\nLINE\n8\nL\n10\n$i\n20\n0\n11\n$i\n21\n1\n');
  }
  b.write('0\nENDSEC\n0\nEOF\n');
  return Uint8List.fromList(utf8.encode(b.toString()));
}

void main() {
  Future<(ProjectController, BuildContext)> app(WidgetTester tester) async {
    final c = ProjectController()..newProject();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return (c, ctx);
  }

  testWidgets('a long import shows its progress and cancels', (tester) async {
    final (c, ctx) = await app(tester);
    final bytes = _dxf(400000);
    Future<String?>? result;
    await tester.runAsync(() async {
      result = showImportProgressDialog(ctx, c, 'levantamento.dxf', bytes);
      // the dialog comes after a moment
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });
    await tester.pump();
    expect(find.textContaining('levantamento.dxf'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text(c.t('cancel')));
    String? summary = 'not finished';
    await tester.runAsync(() async {
      summary = await result;
    });
    await tester.pumpAndSettle();
    expect(summary, isNull);
    expect(c.project.entities.whereType<LineEntity>(), isEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a quick import finishes without the dialog', (tester) async {
    final (c, ctx) = await app(tester);
    String? summary;
    await tester.runAsync(() async {
      summary = await showImportProgressDialog(ctx, c, 'pequeno.dxf', _dxf(10));
    });
    await tester.pumpAndSettle();
    expect(summary, contains('10'));
    expect(c.project.entities.whereType<LineEntity>(), hasLength(10));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
