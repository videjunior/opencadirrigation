/// Base map choice: the Google maps ask for the user's Map Tiles API key
/// on first use and the custom map for its XYZ template; both are kept in
/// the browser only.
library;

import 'package:flutter/material.dart';

import '../../canvas/basemap.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import 'terrain_dialogs.dart' show dialogWidth;

const googleMapsConsoleUrl = 'https://console.cloud.google.com/google/maps-apis/api-list';
const googleMapsKeyDocsUrl = 'https://developers.google.com/maps/documentation/tile/get-api-key';

/// Switches to [m], first asking for what it needs (Google key, custom
/// template); the choice is kept when the user cancels.
Future<void> selectBaseMap(BuildContext context, ProjectController c, BaseMap m) async {
  if (m.isGoogle && c.googleMapsKey == null) {
    if (!await showGoogleMapsKeyDialog(context, c)) return;
  } else if (m == BaseMap.custom && !BaseMapLayer.isValidTemplate(c.customTileUrl)) {
    if (!await showCustomTilesDialog(context, c)) return;
  }
  c.baseMap = m;
  if (m != BaseMap.none && c.project.meta.georef == null) c.notify(c.t('view.baseMapNeedsGeo'));
  c.refresh();
}

/// Asks for the Google Maps Platform API key. Returns true when a key is
/// set on return.
Future<bool> showGoogleMapsKeyDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final ctl = TextEditingController(text: c.googleMapsKey ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('basemap.googleKey.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 560),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('basemap.googleKey.explain'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(t('basemap.googleKey.steps'), style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed: () => openExternalLink(googleMapsConsoleUrl), icon: const Icon(Icons.open_in_new, size: 14), label: Text(t('basemap.googleKey.console'))),
            TextButton.icon(onPressed: () => openExternalLink(googleMapsKeyDocsUrl), icon: const Icon(Icons.help_outline, size: 14), label: Text(t('basemap.googleKey.docs'))),
          ]),
          const SizedBox(height: 4),
          TextField(
            key: const Key('google_key_field'),
            controller: ctl,
            autofocus: true,
            decoration: InputDecoration(labelText: t('basemap.googleKey.field'), hintText: 'AIza…', isDense: true),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 6),
          Text(t('basemap.googleKey.privacy'), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
        ]),
      ),
      actions: [
        if (c.googleMapsKey != null)
          TextButton(
            key: const Key('google_key_remove'),
            onPressed: () {
              ctl.clear();
              Navigator.pop(ctx, true);
            },
            child: Text(t('basemap.googleKey.remove')),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton(key: const Key('google_key_save'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('ok'))),
      ],
    ),
  );
  if (saved == true) {
    c.setGoogleMapsKey(ctl.text);
    if (c.googleMapsKey == null && c.baseMap.isGoogle) {
      c.baseMap = BaseMap.none;
      c.refresh();
    }
  }
  return c.googleMapsKey != null;
}

/// Asks for the XYZ template of the custom base map. Returns true when a
/// valid template is set on return.
Future<bool> showCustomTilesDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final ctl = TextEditingController(text: c.customTileUrl);
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      void submit() {
        if (!BaseMapLayer.isValidTemplate(ctl.text)) {
          setState(() => error = t('basemap.customInvalid'));
          return;
        }
        Navigator.pop(ctx, true);
      }

      return AlertDialog(
        title: Text(t('basemap.custom.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 560),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('basemap.custom.explain'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('custom_tiles_field'),
              controller: ctl,
              autofocus: true,
              decoration: InputDecoration(labelText: t('basemap.custom.field'), hintText: 'https://example.com/tiles/{z}/{x}/{y}.png', isDense: true, errorText: error),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 6),
            Text(t('basemap.custom.placeholders'), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          FilledButton(key: const Key('custom_tiles_save'), onPressed: submit, child: Text(t('ok'))),
        ],
      );
    }),
  );
  if (saved == true) c.setCustomTileUrl(ctl.text);
  return BaseMapLayer.isValidTemplate(c.customTileUrl);
}
