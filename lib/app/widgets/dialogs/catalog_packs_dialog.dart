/// Manufacturer catalogue packs: the packs bundled with the app, packs
/// imported from `.oci.cat` files or loaded from a URL (a single pack or an
/// `index.json` of a community repository), and the export of the current
/// catalogue as a pack.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/io/catalog_io.dart';
import '../../../core/model/catalog_packs.dart';
import '../../io/catalog_packs.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

Future<void> showCatalogPacksDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final urlCtl = TextEditingController();
  final loaded = <CatalogPack>[];
  String? error;
  var busy = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final cat = c.project.catalog;

      Future<void> addPacks(Future<List<CatalogPack>> Function() load) async {
        setState(() {
          busy = true;
          error = null;
        });
        try {
          final packs = await load();
          for (final p in packs) {
            loaded.removeWhere((x) => x.id == p.id);
            loaded.add(p);
          }
          if (packs.isNotEmpty) c.notify(t('cat.packLoaded', {'n': '${packs.length}'}));
        } catch (e) {
          error = t('cat.packLoadError', {'e': c.describeError(e)});
        } finally {
          if (ctx.mounted) setState(() => busy = false);
        }
      }

      Widget tile(CatalogPack pack) {
        final present = pack.isMergedInto(cat);
        final origin = pack.origin.isEmpty ? '' : '  ·  ${t('cat.packFrom', {'o': pack.origin.split('/').last})}';
        return ListTile(
          dense: true,
          title: Text('${pack.brand}  ·  ${t('cat.packItems', {'n': '${pack.itemCount}'})}$origin', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          subtitle: pack.description.isEmpty ? null : Text(pack.description, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          trailing: FilledButton.tonal(
            key: Key('pack_${pack.id}'),
            onPressed: present
                ? null
                : () {
                    final n = c.mutate(() => mergeCatalogPack(cat, pack.catalog));
                    if (n == null) return;
                    c.notify(t('cat.packAdded', {'n': '$n', 'b': pack.brand}));
                    setState(() {});
                  },
            child: Text(present ? '✓' : t('cat.packAdd')),
          ),
        );
      }

      return AlertDialog(
        title: Text(t('cat.packs'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 640),
          height: 500,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('cat.packsExplain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(t('cat.packFormat'), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                key: const Key('pack_import'),
                onPressed: busy
                    ? null
                    : () => addPacks(() async {
                          final f = await openBinaryFile(accept: '.cat,.json');
                          if (f == null) return const [];
                          return [CatalogPack.parse(utf8.decode(f.$2, allowMalformed: true), origin: f.$1)];
                        }),
                icon: const Icon(Icons.file_open_outlined, size: 15),
                label: Text(t('cat.packImport'), style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('pack_url'),
                  controller: urlCtl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(labelText: t('cat.packUrl'), isDense: true, hintText: 'https://…/index.json'),
                  onSubmitted: (_) => addPacks(() => loadCatalogPacksFromUrl(urlCtl.text)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const Key('pack_load_url'),
                onPressed: busy ? null : () => addPacks(() => loadCatalogPacksFromUrl(urlCtl.text)),
                child: Text(busy ? t('cat.packLoading') : t('cat.packLoad'), style: const TextStyle(fontSize: 12)),
              ),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, key: const Key('pack_error'), style: const TextStyle(fontSize: 11.5, color: CadColors.warning))),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  if (loaded.isNotEmpty) ...[
                    SectionTitle(t('cat.packsLoaded')),
                    for (final p in loaded.reversed) tile(p),
                  ],
                  SectionTitle(t('cat.packsBundled')),
                  FutureBuilder<List<CatalogPack>>(
                    future: loadBundledCatalogPacks(),
                    builder: (ctx, snap) {
                      if (snap.hasError) return Padding(padding: const EdgeInsets.all(8), child: Text(t('cat.packLoadError', {'e': '${snap.error}'}), style: const TextStyle(fontSize: 11.5, color: CadColors.warning)));
                      final packs = snap.data;
                      if (packs == null) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                      return Column(children: [for (final p in packs) tile(p)]);
                    },
                  ),
                ],
              ),
            ),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
      );
    }),
  );
}

/// Exports the project catalogue as a pack file (`<id>.oci.cat`).
Future<void> showExportCatalogPackDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  var brand = c.project.meta.client.trim().isEmpty ? c.project.meta.name : c.project.meta.client;
  var name = '', description = '', source = '';
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final id = CatalogPackMeta.idFrom(name.isEmpty ? brand : name);
      return AlertDialog(
        title: Text(t('cat.packExportTitle'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 460),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('cat.packExportExplain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 8),
            TextFieldRow(label: t('cat.packBrand'), value: brand, onChanged: (v) => setState(() => brand = v)),
            TextFieldRow(label: t('cat.packName'), value: name, onChanged: (v) => setState(() => name = v)),
            TextFieldRow(label: t('cat.packDescription'), value: description, onChanged: (v) => description = v),
            TextFieldRow(label: t('cat.packSource'), value: source, onChanged: (v) => source = v),
            const SizedBox(height: 6),
            Text('$id$catalogPackExtension  ·  ${t('cat.packItems', {'n': '${cat.itemCount}'})}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          FilledButton(
            key: const Key('pack_export_ok'),
            onPressed: () async {
              final meta = CatalogPackMeta(id: id, brand: brand.trim().isEmpty ? id : brand.trim(), name: name.trim(), description: description.trim(), source: source.trim(), updated: DateTime.now().toIso8601String().substring(0, 10), author: c.project.meta.designer);
              final file = '$id$catalogPackExtension';
              await saveTextFile(file, CatalogIo.encodePack(meta, cat));
              c.notify(t('cat.packExported', {'f': file, 'n': '${cat.itemCount}'}));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(t('ok')),
          ),
        ],
      );
    }),
  );
}
