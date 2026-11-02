/// Help → Terms of the data (1.6.0, PRD-06): the third-party data of this project with the credit each source asks
/// for (the sheets and the report print them), then every source of elevation, climate and address search the app
/// can reach: its credit, what its free use allows in professional work and the page of its terms; the base maps have
/// their own terms (View → Base map → Terms of the maps).
library;

import 'package:flutter/material.dart';

import '../../../core/io/data_credits.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'basemap_dialogs.dart' show showBaseMapTermsDialog;
import 'terrain_dialogs.dart' show dialogWidth;

Future<void> showDataTermsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final used = projectDataCredits(c.project);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      Widget source(DataSource s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.name} · ${t('src.kind.${s.kind.name}')}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(t('terms.src.${s.id}'), style: TextStyle(fontSize: 11.5, color: s.use == DataUse.nonCommercial ? Cad.warning : Cad.fg70)),
            Text('${t('src.credit')}: ${s.credit}', style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => openExternalLink(s.url),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(s.url, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      );

      return AlertDialog(
        title: Text(t('terms.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 620),
          child: ScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('terms.intro'), style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                Text(t('terms.used'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (used.isEmpty) Text(t('terms.usedNone'), style: TextStyle(fontSize: 11.5, color: Cad.fg54)),
                for (final u in used)
                  Text(
                    '• ${t('src.kind.${u.kind.name}')} — ${u.source}: ${u.credit} (${t('src.use.${u.use.name}')})',
                    key: ValueKey('terms_used_${u.kind.name}'),
                    style: TextStyle(fontSize: 11.5, color: u.use == DataUse.nonCommercial ? Cad.warning : null),
                  ),
                const SizedBox(height: 12),
                for (final s in dataSources) source(s),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('terms_maps'),
                    onPressed: () => showBaseMapTermsDialog(ctx, c),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: Text(t('basemap.terms.menu')),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
      );
    },
  );
}
