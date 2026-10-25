import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/pdf_import_dialog.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/main.dart';

/// File → Import of a PDF plan: the dialog on a phone and on a desktop,
/// its page, scale and content choices, and the import as one undo step.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, Size size) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    for (final k in ['pdfimp.choice', 'pdfimp.scale', 'pdfimp.factor']) {
      removePref(k);
    }
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  /// A landscape A4 plan (two lines, a rectangle, the scale in the title)
  /// and a portrait A4 page with one line.
  Uint8List plan() {
    final doc = PdfDocument();
    final p = doc.addPage(widthPt: 842, heightPt: 595);
    p.path([(100, 100), (300, 100), (300, 250)]);
    p.rect(400, 300, 120, 80);
    p.text(100, 500, 'Planta de situação — ESCALA 1:500', size: 10);
    doc.addPage(widthPt: 595, heightPt: 842).line(0, 0, 100, 100);
    return doc.build();
  }

  Uint8List encrypted() {
    final objs = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>'];
    final b = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objs.length; i++) {
      offsets.add(b.length);
      b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
    }
    final xref = b.length;
    b.write('xref\n0 4\n0000000000 65535 f \n');
    for (final o in offsets) {
      b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    b.write('trailer\n<< /Size 4 /Root 1 0 R /Encrypt << /Filter /Standard /V 1 /R 2 /O <00> /U <00> /P -4 >> >>\nstartxref\n$xref\n%%EOF\n');
    return Uint8List.fromList(latin1.encode(b.toString()));
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(AppShell));

  testWidgets('on a 390 × 844 phone the dialog lays out, reads the scale on the sheet and imports in one undo step', (tester) async {
    final c = await pumpShell(tester, const Size(390, 844));
    unawaited(importPdfAction(ctxOf(tester), c, 'situação.pdf', plan()));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Importar planta em PDF'), findsOneWidget);
    expect(find.byKey(const Key('pdfimp_preview')), findsOneWidget);
    expect(find.text('2 linhas, 1 textos, 0 imagens'), findsOneWidget);
    expect(find.text('Escala escrita na folha: 1:500'), findsOneWidget);
    // 297 × 210 mm at 1:500
    expect(find.text('No desenho: 148.5 × 105.0 m'), findsOneWidget);
    final history = c.historyIndex;
    await tester.tap(find.byKey(const Key('pdfimp_ok')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Importar planta em PDF'), findsNothing);
    expect(c.historyIndex, history + 1);
    expect(c.historyEntries.last.label, 'hist.importPdf');
    expect(c.project.entities, hasLength(3));
    expect(c.selection, hasLength(3), reason: 'left selected for the align tool');
    expect(c.project.findLayer('PDF-situação'), isNotNull);
    expect(c.lastMessage, 'Importado: PDF: 3 entidades em 1 camadas');
    final text = c.project.entities.whereType<TextEntity>().single;
    expect(text.position.x, closeTo(100 * 500 * 0.0254 / 72, 1e-9));
    c.undo();
    await settle(tester);
    expect(c.project.entities, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page, scale and contents chosen in the dialog; the scale is remembered', (tester) async {
    final c = await pumpShell(tester, const Size(1280, 800));
    unawaited(importPdfAction(ctxOf(tester), c, 'situação.pdf', plan()));
    await settle(tester);
    // the second page
    await tester.tap(find.byKey(const Key('pdfimp_page')));
    await settle(tester, 2);
    await tester.tap(find.text('Página 2: 210 × 297 mm').last);
    await settle(tester);
    expect(find.text('1 linhas, 0 textos, 0 imagens'), findsOneWidget);
    expect(find.byKey(const Key('pdfimp_found')), findsNothing);
    // another scale: 1:2000
    await tester.tap(find.byKey(const Key('pdfimp_scale')));
    await settle(tester, 2);
    await tester.tap(find.text('Outra escala').last);
    await settle(tester, 2);
    final field = find.descendant(of: find.byKey(const Key('pdfimp_denominator')), matching: find.byType(TextField));
    await tester.tap(field);
    await tester.enterText(field, '2000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    // 209.9 × 297.0 mm (595 × 842 points) at 1:2000
    expect(find.text('No desenho: 419.8 × 594.1 m'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdfimp_ok')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    final line = c.project.entities.single as LineEntity;
    expect(line.b.x, closeTo(100 * 2000 * 0.0254 / 72, 1e-9));
    expect(getPref('pdfimp.choice'), 'other');
    // opened again: the scale typed last time
    unawaited(importPdfAction(ctxOf(tester), c, 'situação.pdf', plan()));
    await settle(tester);
    expect(find.text('Escala escrita na folha: 1:500'), findsOneWidget, reason: 'the first page states its scale');
    // nothing chosen: said so, the dialog stays, no undo step
    final steps = c.historyIndex;
    await tester.tap(find.byKey(const Key('pdfimp_texts')));
    await tester.tap(find.byKey(const Key('pdfimp_vectors')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('pdfimp_ok')));
    await settle(tester);
    expect(find.text('Nada para importar nesta página com as opções escolhidas'), findsOneWidget);
    expect(c.historyIndex, steps);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(c.project.entities, hasLength(1), reason: 'cancelled: nothing added');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an encrypted or broken file says why instead of opening the dialog', (tester) async {
    final c = await pumpShell(tester, const Size(1280, 800));
    await importPdfAction(ctxOf(tester), c, 'protegido.pdf', encrypted());
    await settle(tester);
    expect(find.text('Importar planta em PDF'), findsNothing);
    expect(c.lastMessage, startsWith('Erro: PDF protegido'));
    await importPdfAction(ctxOf(tester), c, 'nada.pdf', Uint8List.fromList(utf8.encode('<html></html>')));
    expect(c.lastMessage, 'Erro: O arquivo não é um PDF');
    expect(tester.takeException(), isNull);
  });
}
