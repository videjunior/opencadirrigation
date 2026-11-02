import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/body_store.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The seam between the editing and the browser storage, in the app as it
/// runs: the shell, its tabs and the store of the platform (the copies of
/// every project, their versions and the index, in memory under the VM as in
/// the browser's database), with the storage running out of room. Room is
/// made from what may go (versions, projects saved to a file) and never from
/// another project's unsaved work; when even that is not enough the status
/// bar says so until a copy is kept again, the storage dialog shows the
/// problem with Save at hand, what the browser keeps is the last copy that
/// fitted, and the index never lists a text that is gone.
void main() {
  late MemoryBodyStore bodies;
  late LocalProjectStore store;

  String doc(String name, int pad) => jsonEncode({
    'format': 'opencadirrigation',
    'meta': {'name': name},
    'pad': 'x' * pad,
  });

  int entitiesKept(String? json) => ((jsonDecode(json!) as Map<String, dynamic>)['entities'] as List).length;

  /// Everything the index lists can be read back.
  Future<void> expectIndexReadable() async {
    for (final p in store.list()) {
      expect(await store.load(p.uid), isNotNull, reason: 'the index lists ${p.name}, whose text is gone');
      for (final v in store.versions(p.uid)) {
        expect(await store.load(p.uid, version: v.version), isNotNull, reason: '${p.name} v${v.version}');
      }
    }
    final listed = {
      for (final p in store.list()) p.uid,
    };
    expect(store.storedChars, lessThanOrEqualTo(bodies.usedChars), reason: 'the index counts only texts that are kept (${listed.length} projects)');
  }

  Future<ProjectController> pumpApp(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false, startExample: ExampleId.orchard));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    return shell.c as ProjectController;
  }

  Future<void> edit(WidgetTester tester, ProjectController c, String text) async {
    c.addEntity(TextEntity(id: c.project.newId(), position: Pt(0, -60.0 - c.project.entities.length), text: text));
    await c.autosaveNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    LocalProjectStore.debugResetPrepared();
    bodies = platformBodyStore() as MemoryBodyStore;
    bodies
      ..quotaChars = null
      ..failing = false;
    store = LocalProjectStore();
    // what the browser kept before: a project with unsaved changes (its copy
    // is what the recovery brings back) and one saved to a file twice
    await store.save('field-unsaved', 'Field with unsaved changes', doc('u', 30000), kind: 'autosave');
    await store.save('field-saved', 'Field saved to a file', doc('s1', 20000));
    await store.save('field-saved', 'Field saved to a file', doc('s2', 20001));
    expect(store.versions('field-saved'), hasLength(2));
  });

  tearDown(() {
    bodies
      ..quotaChars = null
      ..failing = false;
    LocalProjectStore().clearAll();
  });

  testWidgets('a full storage: room from what may go, then the status bar, the dialog with Save, and the copy again once there is room', (tester) async {
    final c = await pumpApp(tester);
    final uid = c.project.meta.uid;
    // 1. room enough: the copy is kept, nothing is said
    await edit(tester, c, 'one');
    expect(c.storeProblem, isNull);
    expect(c.unsavedInBrowser, isFalse);
    expect(entitiesKept(await store.load(uid)), c.project.entities.length);

    // 2. nearly full: the next copy fits once the oldest version of the
    // project saved to a file goes; the other project's unsaved work stays
    bodies.quotaChars = bodies.usedChars - 15000;
    await edit(tester, c, 'two');
    expect(c.storeProblem, isNull, reason: 'room was made');
    expect(find.byKey(const Key('store_problem_chip')), findsNothing);
    expect(entitiesKept(await store.load(uid)), c.project.entities.length);
    expect(store.versions('field-saved'), hasLength(1), reason: 'the oldest version went first');
    expect(await store.load('field-unsaved'), isNotNull, reason: 'never a copy with unsaved changes');
    await expectIndexReadable();
    final keptBefore = c.project.entities.length;

    // 3. full: nothing more fits, even after dropping all that may go
    bodies.quotaChars = 10;
    await edit(tester, c, 'three');
    expect(c.storeProblem, c.t('store.err.full'));
    expect(c.unsavedInBrowser, isTrue);
    expect(find.byKey(const Key('store_problem_chip')), findsOneWidget, reason: 'the status bar says so until a copy is kept');
    expect(find.text(c.t('store.err.full')), findsWidgets, reason: 'and the message said it once');
    // what the browser keeps: the last copy that fitted (the recovery offers it), the other project's work
    expect(entitiesKept(await store.load(uid)), keptBefore);
    expect(store.recoverable().map((p) => p.uid), containsAll([uid, 'field-unsaved']));
    expect(await store.load('field-unsaved'), isNotNull);
    await expectIndexReadable();
    // told once while it lasts
    c.addEntity(TextEntity(id: c.project.newId(), position: const Pt(0, -90), text: 'four'));
    await tester.pump();
    final seq = c.messageSeq;
    await c.autosaveNow();
    await tester.pump();
    expect(c.messageSeq, seq);
    // the message goes after its time (it would cover the status bar); the chip stays
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('store_problem_chip')), findsOneWidget);

    // 4. the chip opens the storage dialog: the problem, with Save at hand
    await tester.tap(find.byKey(const Key('store_problem_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('storage_problem')), findsOneWidget);
    expect(find.byKey(const Key('storage_save_file')), findsOneWidget);
    expect(find.textContaining(c.t('storage.thisTab')), findsOneWidget, reason: 'the copy of this tab is listed');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(c.t('close'))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('storage_problem')), findsNothing);

    // 5. room again (the user freed the browser's storage): the next copy is
    // kept, everything edited meanwhile included, and the chip goes
    bodies.quotaChars = null;
    await c.autosaveNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.storeProblem, isNull);
    expect(c.unsavedInBrowser, isFalse);
    expect(find.byKey(const Key('store_problem_chip')), findsNothing);
    expect(entitiesKept(await store.load(uid)), c.project.entities.length);
    await expectIndexReadable();
  });

  testWidgets('on a phone the full storage shows in the top bar and opens the same dialog', (tester) async {
    final c = await pumpApp(tester, size: const Size(390, 844));
    bodies.quotaChars = 10;
    await edit(tester, c, 'one');
    expect(c.storeProblem, c.t('store.err.full'));
    expect(find.byKey(const Key('mobile_store_problem')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile_store_problem')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('storage_problem')), findsOneWidget);
    expect(find.byKey(const Key('storage_save_file')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
