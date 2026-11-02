import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/body_store.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/io/window_locks.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// A store that answers with futures, as the browser database does: its
/// own kind, its own quota and failures on demand.
class _AsyncBodies implements BodyStore {
  final Map<String, String> values = {};
  int? quotaChars;
  bool failing = false;
  int puts = 0;

  @override
  String get kind => 'indexeddb';

  @override
  bool get synchronous => false;

  @override
  int get maxEntryChars => 1000000;

  @override
  int get maxTotalChars => 100000000;

  @override
  Future<void> open() async {}

  @override
  Future<bool> put(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    puts++;
    if (failing) return false;
    final q = quotaChars;
    final used = values.entries.where((e) => e.key != key).fold(0, (s, e) => s + e.value.length);
    if (q != null && used + value.length > q) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<String?> get(String key) async {
    await Future<void>.delayed(Duration.zero);
    return values[key];
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

String _project(String name, int size) => jsonEncode({'name': name, 'pad': 'x' * size});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    LocalProjectStore().clearAll();
    LocalProjectStore.debugResetPrepared();
  });

  group('browser store (CAD-03, CAD-04)', () {
    test('a full storage: the save says so and the index never claims a copy that was not kept', () async {
      final bodies = MemoryBodyStore(quotaChars: 3000);
      final store = LocalProjectStore(bodies: bodies);
      expect((await store.save('a', 'A', _project('A', 1000), kind: 'autosave')).ok, isTrue);
      final first = store.entry('a')!.savedAt;
      final out = await store.save('a', 'A', _project('A', 5000), kind: 'autosave');
      expect(out.status, StoreStatus.full);
      expect(store.entry('a')!.savedAt, first, reason: 'the index keeps the time of the copy that is there');
      expect(jsonDecode((await store.load('a'))!)['pad'], hasLength(1000), reason: 'the older copy is still the one kept');
      bodies.failing = true;
      expect((await store.save('b', 'B', _project('B', 10), kind: 'autosave')).status, StoreStatus.full);
      expect(store.has('b'), isFalse);
    });

    test('room is made from the versions of the same project first, never from a copy with unsaved changes', () async {
      final bodies = MemoryBodyStore(quotaChars: 10000);
      final store = LocalProjectStore(bodies: bodies);
      // another project with unsaved changes (a recovery) and one saved to a file
      await store.save('other', 'Other', _project('O', 2000), kind: 'autosave');
      await store.save('saved', 'Saved', _project('S', 1000));
      for (var i = 0; i < 3; i++) {
        await store.save('me', 'Me', _project('M$i', 1000));
      }
      expect(store.versions('me').length, 3);
      // a larger copy: the oldest versions of "me" go, the recovery stays
      final out = await store.save('me', 'Me', _project('big', 3500), kind: 'autosave');
      expect(out.ok, isTrue);
      expect(out.dropped, greaterThan(0));
      expect(store.recoverable().map((e) => e.uid), contains('other'));
      expect(await store.load('other'), isNotNull);
      expect(store.versions('me'), isNotEmpty, reason: 'the newest version of the project stays');
    });

    test('the copy is written before the version: a version that does not fit still leaves the copy', () async {
      final bodies = MemoryBodyStore(quotaChars: 2500);
      final store = LocalProjectStore(bodies: bodies);
      final out = await store.save('p', 'P', _project('P', 1500));
      expect(out.ok, isTrue);
      expect(out.versionKept, isFalse);
      expect(store.versions('p'), isEmpty);
      expect(store.entry('p')!.kind, 'saved');
      expect(await store.load('p'), contains('"P"'));
    });

    test('Discard in the recovery drops only the unsaved changes: the versions and the recent entry stay', () async {
      final store = LocalProjectStore();
      await store.save('p', 'Farm', _project('v1', 10));
      await store.save('p', 'Farm', _project('v2', 10));
      await store.save('p', 'Farm', _project('unsaved', 10), kind: 'autosave');
      expect(store.recoverable().map((e) => e.uid), ['p']);
      await store.discardAutosave('p');
      expect(store.recoverable(), isEmpty);
      expect(store.versions('p').length, 2);
      expect(store.list().map((e) => e.uid), ['p'], reason: 'still a recent project');
      expect(jsonDecode((await store.load('p'))!)['name'], 'v2', reason: 'back to the last saved version');
      // a project never saved to a file is forgotten
      await store.save('n', 'New', _project('n', 10), kind: 'autosave');
      await store.discardAutosave('n');
      expect(store.has('n'), isFalse);
    });

    test('the copies written while the page closed become the copies of their projects at the next start', () async {
      final store = LocalProjectStore();
      final old = DateTime(2026, 1, 1);
      await store.save('p', 'Farm', _project('older', 10), kind: 'saved', edited: old);
      expect(store.rescue('p', 'Farm', _project('rescued', 10), bytes: 40, edited: DateTime(2026, 1, 2)), isTrue);
      // a rescue older than what the store has is dropped
      await store.save('q', 'Field', _project('newer', 10), kind: 'autosave', edited: DateTime(2026, 3, 1));
      store.rescue('q', 'Field', _project('stale', 10), bytes: 40, edited: DateTime(2026, 2, 1));
      await store.prepare();
      expect(jsonDecode((await store.load('p'))!)['name'], 'rescued');
      expect(store.entry('p')!.kind, 'autosave', reason: 'offered by the recovery');
      expect(jsonDecode((await store.load('q'))!)['name'], 'newer');
      expect(getPref('store.rescue'), isNull);
    });

    test('an older version\'s texts move out of localStorage into the database once', () async {
      // as 1.5 left them: the texts in prefs under the index's keys
      setPref('store.index', jsonEncode([StoredProject(uid: 'old', name: 'Old', savedAt: DateTime(2026, 5, 1), kind: 'saved', bytes: 10).toJson()]));
      setPref('store.old', _project('legacy', 10));
      final bodies = _AsyncBodies();
      final store = LocalProjectStore(bodies: bodies, locks: LoneWindowLocks());
      expect(jsonDecode((await store.load('old'))!)['name'], 'legacy', reason: 'readable before it moves');
      await store.prepare();
      expect(bodies.values['store.old'], contains('legacy'));
      expect(getPref('store.old'), isNull);
      expect(jsonDecode((await store.load('old'))!)['name'], 'legacy');
    });

    test('saves of a store that answers later run one after the other: no index entry is lost', () async {
      final store = LocalProjectStore(bodies: _AsyncBodies(), locks: LoneWindowLocks());
      await Future.wait([for (var i = 0; i < 6; i++) store.save('p$i', 'P$i', _project('P$i', 10), kind: 'autosave')]);
      expect(store.list().map((e) => e.uid).toSet(), {for (var i = 0; i < 6; i++) 'p$i'});
    });
  });

  group('copies of the controller (CAD-02, CAD-03)', () {
    ProjectController fresh(LocalProjectStore store) {
      setPref('lang', 'en');
      final c = ProjectController(store: store);
      c.newProject();
      return c;
    }

    test('a copy that cannot be kept stays shown until one is kept again', () async {
      final bodies = MemoryBodyStore();
      final store = LocalProjectStore(bodies: bodies);
      final c = fresh(store);
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0)));
      // a storage that never keeps anything: blocked
      bodies.failing = true;
      await c.autosaveNow();
      expect(c.storeProblem, c.t('store.err.unavailable'));
      bodies.failing = false;
      await c.autosaveNow();
      expect(c.storeProblem, isNull);
      // a storage that kept things and is full now
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(2, 0)));
      bodies.failing = true;
      await c.autosaveNow();
      expect(c.storeProblem, c.t('store.err.full'));
      expect(c.lastMessage, c.t('store.err.full'), reason: 'told once');
      final seq = c.messageSeq;
      await c.autosaveNow();
      expect(c.messageSeq, seq, reason: 'not again while it lasts');
      bodies.failing = false;
      await c.autosaveNow();
      expect(c.storeProblem, isNull);
      expect(c.unsavedInBrowser, isFalse);
    });

    test('the last edits of a burst get their copy once the interval has passed', () async {
      final saved = ProjectController.trailingAutosave, interval = ProjectController.autosaveInterval;
      ProjectController.trailingAutosave = true;
      ProjectController.autosaveInterval = const Duration(milliseconds: 60);
      addTearDown(() {
        ProjectController.trailingAutosave = saved;
        ProjectController.autosaveInterval = interval;
      });
      final store = LocalProjectStore();
      final c = fresh(store);
      c.addEntity(LineEntity(id: 'a', a: Pt.zero, b: const Pt(1, 0)));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // within the interval: not copied at once…
      c.addEntity(LineEntity(id: 'b', a: Pt.zero, b: const Pt(2, 0)));
      c.addEntity(LineEntity(id: 'c', a: Pt.zero, b: const Pt(3, 0)));
      expect(c.unsavedInBrowser, isTrue);
      // …but once the interval has passed, with nothing else edited
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.unsavedInBrowser, isFalse);
      final kept = jsonDecode((await store.load(c.project.meta.uid))!) as Map<String, dynamic>;
      expect((kept['entities'] as List).length, 3);
      c.dispose();
    });

    test('Save records a version and keeps the copy; Save as copy gives a project of its own', () async {
      final store = LocalProjectStore();
      final c = fresh(store);
      c.addEntity(LineEntity(id: 'a', a: Pt.zero, b: const Pt(1, 0)));
      final (_, compact) = c.fileJson();
      c.markSaved(compact: compact);
      await Future<void>.delayed(Duration.zero);
      expect(c.dirty, isFalse);
      expect(store.versions(c.project.meta.uid).length, 1);
      final uid = c.project.meta.uid;
      c.renewUid();
      expect(c.project.meta.uid, isNot(uid));
      expect(c.dirty, isTrue);
      expect(store.versions(c.project.meta.uid), isEmpty, reason: 'the copy has no versions of the original');
    });
  });
}
