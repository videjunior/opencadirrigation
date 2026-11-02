/// Base map choice: the Google maps ask for the user's Map Tiles API key
/// on first use and the custom map for its XYZ template; both are kept in
/// the browser only.
library;

import 'package:flutter/material.dart';

import '../../canvas/basemap.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;
import '../../theme.dart';

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
  // a key typed now is kept between visits unless the user says otherwise
  var remember = c.googleMapsKey == null || c.googleKeyRemembered;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t('basemap.googleKey.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('basemap.googleKey.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
              const SizedBox(height: 6),
              Text(t('basemap.googleKey.steps'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(onPressed: () => openExternalLink(googleMapsConsoleUrl), icon: const Icon(Icons.open_in_new, size: 14), label: Text(t('basemap.googleKey.console'))),
                  TextButton.icon(onPressed: () => openExternalLink(googleMapsKeyDocsUrl), icon: const Icon(Icons.help_outline, size: 14), label: Text(t('basemap.googleKey.docs'))),
                ],
              ),
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
              Text(t('basemap.googleKey.privacy'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
              // 1.6.0 CAD: the key in this page only
              CheckboxListTile(
                key: const Key('google_key_remember'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: remember,
                onChanged: (v) => setState(() => remember = v ?? true),
                title: Text(t('basemap.googleKey.remember'), style: const TextStyle(fontSize: 12)),
                subtitle: Text(t('basemap.googleKey.rememberHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
              ),
            ],
          ),
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
    ),
  );
  if (saved == true) {
    c.setGoogleMapsKey(ctl.text, remember: remember);
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
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          if (!BaseMapLayer.isValidTemplate(ctl.text)) {
            setState(() => error = t(BaseMapLayer.isPlainHttp(ctl.text) ? 'basemap.httpBlocked' : 'basemap.customInvalid'));
            return;
          }
          Navigator.pop(ctx, true);
        }

        return AlertDialog(
          title: Text(t('basemap.custom.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('basemap.custom.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
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
                Text(t('basemap.custom.placeholders'), style: TextStyle(fontSize: 10.5, color: Cad.fg38)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
            FilledButton(key: const Key('custom_tiles_save'), onPressed: submit, child: Text(t('ok'))),
          ],
        );
      },
    ),
  );
  if (saved == true) c.setCustomTileUrl(ctl.text);
  return BaseMapLayer.isValidTemplate(c.customTileUrl);
}

// 1.6.0 CAD: the street map server and the terms of the maps

/// The usage policy of the OpenStreetMap Foundation's tile server.
const osmTilePolicyUrl = 'https://operations.osmfoundation.org/policies/tiles/';

/// View → Base map → Street map server: the tile server of the street map
/// (an XYZ template of OpenStreetMap tiles; empty for the OpenStreetMap
/// Foundation's own, whose usage policy asks for no heavy use). Returns
/// true when saved.
Future<bool> showStreetsServerDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final ctl = TextEditingController(text: c.streetsTileUrl);
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final v = ctl.text.trim();
          if (v.isNotEmpty && !BaseMapLayer.isValidTemplate(v)) {
            setState(() => error = t(BaseMapLayer.isPlainHttp(v) ? 'basemap.httpBlocked' : 'basemap.customInvalid'));
            return;
          }
          Navigator.pop(ctx, true);
        }

        return AlertDialog(
          title: Text(t('basemap.osm.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('basemap.osm.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                TextButton.icon(onPressed: () => openExternalLink(osmTilePolicyUrl), icon: const Icon(Icons.open_in_new, size: 14), label: Text(t('basemap.osm.policy'))),
                TextField(
                  key: const Key('osm_server_field'),
                  controller: ctl,
                  decoration: InputDecoration(labelText: t('basemap.osm.field'), hintText: BaseMapLayer.defaultStreetsTemplate, isDense: true, errorText: error),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('osm_server_default'),
              onPressed: () {
                ctl.clear();
                Navigator.pop(ctx, true);
              },
              child: Text(t('basemap.osm.default')),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
            FilledButton(key: const Key('osm_server_save'), onPressed: submit, child: Text(t('ok'))),
          ],
        );
      },
    ),
  );
  if (saved == true) c.setStreetsTileUrl(ctl.text);
  return saved == true;
}

/// View → Base map → Terms of the maps: who provides each base map, what
/// its terms allow, and the links to them.
Future<void> showBaseMapTermsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  Widget source(String title, String body, String url) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        Text(body, style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => openExternalLink(url),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: Text(url, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    ),
  );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('basemap.terms.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 600),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('basemap.terms.intro'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              source(t('view.baseMap.streets'), t('basemap.terms.osm'), osmTilePolicyUrl),
              source(t('view.baseMap.topo'), t('basemap.terms.topo'), BaseMapLayer.attributionUrl(BaseMap.topo)),
              source(t('view.baseMap.carto'), t('basemap.terms.carto'), BaseMapLayer.attributionUrl(BaseMap.carto)),
              source(t('view.baseMap.satellite'), t('basemap.terms.esri'), BaseMapLayer.attributionUrl(BaseMap.satellite)),
              source(t('view.baseMap.googleSatellite'), t('basemap.terms.google'), BaseMapLayer.attributionUrl(BaseMap.googleSatellite)),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
    ),
  );
}
