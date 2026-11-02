/// File → Saved downloaded data: what this device keeps of the downloads of
/// the online elevation models and of the climate series (count, size and
/// since when, per kind), where it is kept, whether new downloads are kept,
/// and buttons to clear each kind or everything.
library;

import 'package:flutter/material.dart';

import '../../io/data_cache_store.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The kinds of downloads the dialog lists.
const dataCacheKinds = ['dem', 'climate'];

String _size(int bytes) => bytes < 1e6 ? '${fmtUi(bytes / 1e3, 0)} kB' : '${fmtUi(bytes / 1e6, bytes < 1e7 ? 1 : 0)} MB';

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> showDataCacheDialog(BuildContext context, ProjectController c, {DataCache? cache}) async {
  final t = c.t;
  final dc = cache ?? appDataCache();
  Future<Map<String, DataCacheStats>> load() async => {for (final k in dataCacheKinds) k: await dc.stats(k)};
  var stats = await load();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> clear([String? kind]) async {
          await dc.clear(kind);
          final s = await load();
          if (!ctx.mounted) return;
          setState(() => stats = s);
          c.notify(t('cache.cleared'));
        }

        final where = switch (dc.store.kind) {
          'indexeddb' => t('cache.where.web'),
          'files' => t('cache.where.files', {'p': dc.store.location}),
          _ => t('cache.where.none'),
        };
        return AlertDialog(
          title: Text(t('cache.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 480),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('cache.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 6),
                  Text(where, key: const Key('cache_where'), style: const TextStyle(fontSize: 11.5)),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    key: const Key('cache_use'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('cache.use'), style: const TextStyle(fontSize: 12)),
                    value: dc.enabled,
                    onChanged: (v) => setState(() {
                      if (identical(dc, appDataCache())) {
                        setDataCacheEnabled(v);
                      } else {
                        dc.enabled = v;
                      }
                    }),
                  ),
                  for (final k in dataCacheKinds)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${t('cache.$k')}: ',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text:
                                        t('cache.entries', {'n': '${stats[k]!.count}', 's': _size(stats[k]!.bytes)}) +
                                        (stats[k]!.oldest == null ? '' : ' · ${t('cache.oldest', {'d': _day(stats[k]!.oldest!)})}'),
                                  ),
                                ],
                              ),
                              key: Key('cache_stats_$k'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(key: Key('cache_clear_$k'), onPressed: stats[k]!.count == 0 ? null : () => clear(k), child: Text(t('cache.clear'))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(key: const Key('cache_clear_all'), onPressed: stats.values.every((s) => s.count == 0) ? null : () => clear(), child: Text(t('cache.clearAll'))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
          ],
        );
      },
    ),
  );
}
