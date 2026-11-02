/// File → Browser storage: what this browser keeps of the projects (the
/// copy of each one, when it was taken, its saved versions and their size),
/// how much of the site's storage that takes, whether the browser keeps it
/// when it runs short of space, and what to do: download every project kept
/// here at once (a ZIP of their files), or ask the browser to keep the
/// storage. These copies are not a backup: the project file is.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../../io/file_io.dart';
import '../../io/project_store.dart';
import '../../io/storage_info.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../actions.dart' show saveProjectAction;
import '../fields.dart';

String _mb(int bytes) => (bytes / 1e6).toStringAsFixed(bytes < 1e7 ? 1 : 0);

String _when(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Every project kept in [store] as its file (the copy, and with [versions]
/// each saved version), zipped: `<name> (<uid>).oci.json`, the versions in
/// `versions/`.
Future<Uint8List> zipStoredProjects(LocalProjectStore store, {bool versions = true}) async {
  final archive = Archive();
  String safe(String s) => (s.trim().isEmpty ? 'project' : s.trim()).replaceAll(RegExp(r'[^\w\- ]+', unicode: true), '_');
  for (final p in store.list()) {
    final json = await store.load(p.uid);
    if (json != null) {
      final bytes = utf8.encode(json);
      archive.addFile(ArchiveFile('${safe(p.name)} (${p.uid}).oci.json', bytes.length, bytes));
    }
    if (!versions) continue;
    for (final v in store.versions(p.uid)) {
      final vj = await store.load(p.uid, version: v.version);
      if (vj == null) continue;
      final bytes = utf8.encode(vj);
      archive.addFile(ArchiveFile('versions/${safe(p.name)} (${p.uid}) v${v.version}.oci.json', bytes.length, bytes));
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<void> showStorageDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final store = c.store;
  var estimate = await storageEstimate();
  var persisted = await storagePersisted();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final kept = store.list();
        final problem = c.storeProblem;
        final where = switch (store.bodies.kind) {
          'indexeddb' => t('storage.whereDb'),
          'localstorage' => t('storage.whereLocal'),
          _ => t('storage.whereMemory'),
        };
        return AlertDialog(
          title: Text(t('storage.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: 520,
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('store.notBackup'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  if (browserIsSafari) ...[
                    const SizedBox(height: 6),
                    Text(
                      t('storage.safari'),
                      key: const Key('storage_safari'),
                      style: TextStyle(fontSize: 11.5, color: Cad.attention),
                    ),
                  ],
                  if (problem != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('storage_problem'),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Cad.attention),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Cad.attention),
                          const SizedBox(width: 8),
                          Expanded(child: Text(problem, style: const TextStyle(fontSize: 11.5))),
                          TextButton(
                            key: const Key('storage_save_file'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              saveProjectAction(context, c);
                            },
                            child: Text(t('file.save')),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(t('storage.where', {'w': where}), style: const TextStyle(fontSize: 11.5)),
                  if (estimate != null) Text(t('storage.used', {'u': _mb(estimate!.$1), 'q': _mb(estimate!.$2)}), key: const Key('storage_used'), style: const TextStyle(fontSize: 11.5)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          persisted == null ? t('storage.persistUnknown') : (persisted! ? t('storage.persistYes') : t('storage.persistNo')),
                          key: const Key('storage_persist'),
                          style: TextStyle(fontSize: 11.5, color: persisted == false ? Cad.attention : null),
                        ),
                      ),
                      if (persisted == false)
                        TextButton(
                          key: const Key('storage_persist_ask'),
                          onPressed: () async {
                            final r = await requestPersistentStorage();
                            final e = await storageEstimate();
                            setState(() {
                              persisted = r ?? persisted;
                              estimate = e ?? estimate;
                            });
                          },
                          child: Text(t('storage.persistAsk')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t('storage.kept', {'n': '${kept.length}'}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  for (final p in kept)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '• ${p.name.isEmpty ? p.uid : p.name} — ${p.kind == 'autosave' ? t('storage.kindAutosave') : t('storage.kindSaved')} · ${_when(p.savedAt)} · ${_mb(p.stored + store.versions(p.uid).fold(0, (s, v) => s + v.stored))} MB · ${t('storage.versions', {'n': '${store.versions(p.uid).length}'})}${p.uid == c.project.meta.uid ? ' · ${t('storage.thisTab')}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              key: const Key('storage_zip'),
              onPressed: kept.isEmpty
                  ? null
                  : () async {
                      final zip = await zipStoredProjects(store);
                      final d = DateTime.now();
                      await saveBinaryFile('opencadirrigation-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.zip', zip, mime: 'application/zip');
                      c.notify(t('storage.zipped', {'n': '${kept.length}'}));
                    },
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: Text(t('storage.zip')),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
          ],
        );
      },
    ),
  );
}
