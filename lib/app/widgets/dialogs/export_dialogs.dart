/// Dialogs used by the exporters: project georeference and the plot sheet
/// options of the PDF (and of the PNG image of the sheet).
library;

import 'package:flutter/material.dart';

import '../../../core/io/datum.dart' show GeodeticDatum, projectDatumLabel, projectDatums;
import '../../../core/io/details.dart' show DetailContext, detailTitleKey;
import '../../../core/io/geo.dart';
import '../../../core/io/pdf_sheet.dart';
import '../../../core/io/sheet_set.dart' show areaZones, zoneMembers;
import '../../../core/model/entities.dart' show PumpEntity;
import '../../../core/units.dart';
import '../../io/sheet_basemap.dart';
import '../../state/controller.dart';
import '../fields.dart' show ScrollBody, ScrollSizedBox, signedNumberKeyboard;
import 'terrain_dialogs.dart' show dialogWidth;
import '../../theme.dart';

/// Lets the user define (or edit/remove) the project's georeference.
/// Returns true when a georeference is set on exit.
Future<bool?> showGeoreferenceDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final g = c.project.meta.georef;
  var useUtm = g != null;
  final lat = TextEditingController(text: g != null ? g.toLatLon(0, 0).$1.toStringAsFixed(6) : '');
  final lon = TextEditingController(text: g != null ? g.toLatLon(0, 0).$2.toStringAsFixed(6) : '');
  final zone = TextEditingController(text: g?.zone.toString() ?? '23');
  final east = TextEditingController(text: g?.originEasting.toStringAsFixed(2) ?? '');
  final north = TextEditingController(text: g?.originNorthing.toStringAsFixed(2) ?? '');
  var northern = g?.north ?? false;
  // 1.6.0 PRD: the datum the coordinates are named on (null: by the site)
  GeodeticDatum? datum = g?.datum;
  String? error;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        double? num(TextEditingController tc) => parseNumber(tc.text);
        GeoReference? parse() {
          if (useUtm) {
            final z = int.tryParse(zone.text.trim()), e = num(east), n = num(north);
            if (z == null || z < 1 || z > 60 || e == null || n == null) return null;
            return GeoReference(zone: z, north: northern, originEasting: e, originNorthing: n, datum: datum);
          }
          var la = num(lat), lo = num(lon);
          if (la == null || lo == null) {
            // a pasted pair ("-22.9068, -43.1729", a Google Maps link, DMS)
            final pair = parseLatLon('${lat.text} ${lon.text}');
            if (pair != null) {
              la = pair.$1;
              lo = pair.$2;
            }
          }
          if (la == null || lo == null || la.abs() > 84 || lo.abs() > 180) return null;
          return GeoReference.fromLatLonOrigin(la, lo).withDatum(datum);
        }

        Widget field(TextEditingController tc, String label, {String? suffix}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            key: Key('geo_${label.hashCode}'),
            controller: tc,
            decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true),
            keyboardType: signedNumberKeyboard,
            style: const TextStyle(fontSize: 12),
          ),
        );
        return AlertDialog(
          title: Text(t('geo.title'), style: const TextStyle(fontSize: 15)),
          content: ScrollSizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('geo.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70, height: 1.35)),
                const SizedBox(height: 8),
                Text(
                  g == null ? t('geo.none') : t('geo.current', {'crs': g.crsName, 'e': g.originEasting.toStringAsFixed(0), 'n': g.originNorthing.toStringAsFixed(0)}),
                  style: TextStyle(fontSize: 11.5, color: Cad.fg54),
                ),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(t('geo.modeLatLon'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: true, label: Text(t('geo.modeUtm'), style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {useUtm},
                  onSelectionChanged: (s) => setState(() => useUtm = s.first),
                ),
                if (!useUtm) ...[
                  Row(
                    children: [
                      Expanded(child: field(lat, t('geo.lat'))),
                      const SizedBox(width: 8),
                      Expanded(child: field(lon, t('geo.lon'))),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: field(zone, t('geo.zone'))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t('geo.north'), style: const TextStyle(fontSize: 12)),
                          value: northern,
                          onChanged: (v) => setState(() => northern = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: field(east, t('geo.easting'), suffix: 'm')),
                      const SizedBox(width: 8),
                      Expanded(child: field(north, t('geo.northing'), suffix: 'm')),
                    ],
                  ),
                ],
                // 1.6.0 PRD: the datum named on the sheets and in the files
                DropdownButtonFormField<GeodeticDatum?>(
                  key: const Key('geo_datum'),
                  isExpanded: true,
                  initialValue: datum,
                  decoration: InputDecoration(labelText: t('prd.geo.datum'), isDense: true),
                  style: TextStyle(fontSize: 12, color: Cad.fg),
                  items: [
                    DropdownMenuItem<GeodeticDatum?>(value: null, child: Text(t('prd.geo.datumAuto'), style: const TextStyle(fontSize: 12))),
                    for (final d in projectDatums) DropdownMenuItem<GeodeticDatum?>(value: d, child: Text(projectDatumLabel(d), style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => datum = v),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(t('prd.geo.datumHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error!, style: TextStyle(fontSize: 12, color: Cad.attention)),
                  ),
              ],
            ),
          ),
          actions: [
            if (g != null)
              TextButton(
                key: const Key('geo_remove'),
                onPressed: () async {
                  // the base map, the online DEM and the geographic exports need it: asked first (and one undo step)
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (q) => AlertDialog(
                      title: Text(t('geo.remove')),
                      content: Text(t('geo.removeConfirm')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(q, false), child: Text(t('cancel'))),
                        FilledButton(key: const Key('geo_remove_ok'), onPressed: () => Navigator.pop(q, true), child: Text(t('ok'))),
                      ],
                    ),
                  );
                  if (ok != true || !c.setGeoreference(null)) return;
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(t('geo.remove')),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, c.project.meta.georef != null), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('geo_ok'),
              onPressed: () {
                final ref = parse();
                if (ref == null) {
                  setState(() => error = t('geo.invalid'));
                  return;
                }
                // one undo step
                if (!c.setGeoreference(ref)) return;
                c.notify(t('msg.georefSet', {'crs': ref.crsName}));
                Navigator.pop(ctx, true);
              },
              child: Text(t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

/// Plot sheet options for the PDF export (with [raster], for the PNG image
/// of the sheet: no extra sheets, details, charts or reports, and a
/// resolution). Returns null when cancelled.
Future<SheetOptions?> showPlotDialog(BuildContext context, ProjectController c, {SheetOptions initial = const SheetOptions(), bool raster = false}) {
  final t = c.t;
  var o = initial;
  var fit = o.scale == null;
  final builder = c.exporter().sheetBuilder();
  final scaleCtl = TextEditingController(text: (o.scale ?? builder.sheetScale(o)).round().toString());
  // the base map on screen can go under the drawing (a snapshot of the view)
  final mapAvailable = c.project.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
  var withMap = mapAvailable;
  var busy = false;
  // what the sets of sheets would hold (counted once)
  final zoneCount = raster ? 0 : zoneMembers(c.project, c.results).length;
  final areaCount = raster ? 0 : areaZones(c.project, const {}).length;
  final view = c.camera.size.isEmpty ? null : c.camera.visible;
  var withView = !raster && o.windows.isNotEmpty;
  final details = {...o.details};
  final detailCtx = raster ? null : DetailContext.of(c.project, c.results);
  final chartsAvailable = c.results != null || c.profilePath != null || c.project.entities.any((e) => e is PumpEntity && c.project.catalog.pump(e.pumpSpecId) != null);
  // 1.6.0 PRD: the coordinate grid needs a georeference for its geographic part; the terrain sheets need terrain data
  final georef = c.project.meta.georef != null;
  final terrain = !raster && !c.project.buildTerrain().isEmpty;
  return showDialog<SheetOptions>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final autoScale = builder.sheetScale(o.copyWith(clearScale: true));
        final wide = MediaQuery.sizeOf(ctx).width >= 760;
        Widget check(String label, bool value, ValueChanged<bool> on, {bool enabled = true, Key? key}) => CheckboxListTile(
          key: key,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: enabled ? (v) => on(v ?? false) : null,
        );
        SheetOptions result() {
          // "500", or the whole ratio typed ("1:500", "1/500")
          final s = parseNumber(scaleCtl.text.split(RegExp(r'[:/]')).last);
          var res = fit || s == null || s <= 0 ? o.copyWith(clearScale: true) : o.copyWith(scale: s);
          if (raster) return res.copyWith(split: SheetSplit.single, windows: const [], details: const [], charts: false, includeReports: false, clearProfilePath: true, themes: const []);
          res = res.copyWith(
            windows: withView && view != null ? [SheetWindow(bounds: view, title: t('sheet.view'))] : const [],
            details: [
              for (final k in DetailKind.values)
                if (details.contains(k)) k,
            ],
            charts: o.charts && chartsAvailable,
            profilePath: o.charts ? c.profilePath : null,
            clearProfilePath: !o.charts || c.profilePath == null,
          );
          return res;
        }

        final extra = raster ? 0 : (o.split == SheetSplit.zones ? zoneCount : (o.split == SheetSplit.areas ? areaCount : 0)) + (withView && view != null ? 1 : 0) + (terrain ? o.themes.length : 0);
        final sheetsTotal = 1 + extra + (raster ? 0 : builder.detailSheets(o.copyWith(details: details.toList())).length);
        final page = <Widget>[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<PageSize>(
                  isExpanded: true,
                  initialValue: o.page,
                  decoration: InputDecoration(labelText: t('plot.page'), isDense: true),
                  style: TextStyle(fontSize: 12, color: Cad.fg),
                  items: [
                    for (final p in PageSize.values)
                      DropdownMenuItem(
                        value: p,
                        child: Text('${p.label}  (${p.shortMm.round()} × ${p.longMm.round()} mm)', style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() => o = o.copyWith(page: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  isExpanded: true,
                  initialValue: o.landscape,
                  decoration: InputDecoration(labelText: t('plot.orientation'), isDense: true),
                  style: TextStyle(fontSize: 12, color: Cad.fg),
                  items: [
                    DropdownMenuItem(value: true, child: Text(t('plot.landscape'), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: false, child: Text(t('plot.portrait'), style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => o = o.copyWith(landscape: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: check(
                  t('plot.scaleAuto'),
                  fit,
                  (v) => setState(() {
                    fit = v;
                    if (v) scaleCtl.text = autoScale.round().toString();
                  }),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: scaleCtl,
                  enabled: !fit,
                  decoration: InputDecoration(labelText: t('plot.scale'), isDense: true),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(t('plot.fits', {'n': autoScale.round().toString()}), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          ),
          if (raster) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<double>(
              key: const Key('plot_dpi'),
              isExpanded: true,
              initialValue: pngResolutionsOffered.contains(o.dpi) ? o.dpi : 200,
              decoration: InputDecoration(labelText: t('plot.dpi'), isDense: true),
              style: TextStyle(fontSize: 12, color: Cad.fg),
              items: [
                for (final d in pngResolutionsOffered)
                  DropdownMenuItem(
                    value: d,
                    child: Text('${d.round()} dpi', style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (v) => setState(() => o = o.copyWith(dpi: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(t('plot.pngHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
          ],
          const Divider(height: 14),
          check(t('plot.labels'), o.labels, (v) => setState(() => o = o.copyWith(labels: v))),
          check(t('plot.wetted'), o.wettedRadii, (v) => setState(() => o = o.copyWith(wettedRadii: v))),
          check(t('plot.legend'), o.legend, (v) => setState(() => o = o.copyWith(legend: v))),
          check(t('plot.bomOnSheet'), o.bomOnSheet && c.results != null, (v) => setState(() => o = o.copyWith(bomOnSheet: v)), enabled: c.results != null),
          if (!raster) check(t('plot.reports'), o.includeReports && c.results != null, (v) => setState(() => o = o.copyWith(includeReports: v)), enabled: c.results != null),
          check(t('plot.baseMap'), withMap, (v) => setState(() => withMap = v), enabled: mapAvailable),
          if (mapAvailable && withMap)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(t('plot.baseMapHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
          // 1.6.0 PRD: the coordinate grid
          const SizedBox(height: 4),
          DropdownButtonFormField<SheetGrid>(
            key: const Key('plot_grid'),
            isExpanded: true,
            initialValue: o.grid,
            decoration: InputDecoration(labelText: t('prd.plot.grid'), isDense: true),
            style: TextStyle(fontSize: 12, color: Cad.fg),
            items: [
              for (final gr in SheetGrid.values)
                DropdownMenuItem(
                  value: gr,
                  enabled: georef || !gr.hasGeographic,
                  child: Text(t(gr == SheetGrid.utm && !georef ? 'prd.plot.grid.local' : 'prd.plot.grid.${gr.name}'), style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: (v) => setState(() => o = o.copyWith(grid: v)),
          ),
        ];
        final sheets = raster
            ? const <Widget>[]
            : <Widget>[
                DropdownButtonFormField<SheetSplit>(
                  key: const Key('plot_split'),
                  isExpanded: true,
                  initialValue: o.split,
                  decoration: InputDecoration(labelText: t('plot.sheets'), isDense: true),
                  style: TextStyle(fontSize: 12, color: Cad.fg),
                  items: [
                    DropdownMenuItem(
                      value: SheetSplit.single,
                      child: Text(t('plot.split.single'), style: const TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: SheetSplit.zones,
                      enabled: zoneCount > 0,
                      child: Text(t('plot.split.zones', {'n': '$zoneCount'}), style: const TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: SheetSplit.areas,
                      enabled: areaCount > 0,
                      child: Text(t('plot.split.areas', {'n': '$areaCount'}), style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (v) => setState(() => o = o.copyWith(split: v)),
                ),
                check(t('plot.dimOthers'), o.dimOthers, (v) => setState(() => o = o.copyWith(dimOthers: v)), enabled: o.split != SheetSplit.single),
                check(t('plot.currentView'), withView && view != null, (v) => setState(() => withView = v), enabled: view != null),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(t('plot.details'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                    ),
                    TextButton(
                      key: const Key('plot_details_all'),
                      onPressed: () => setState(() => details.length == DetailKind.values.length ? details.clear() : details.addAll(DetailKind.values)),
                      child: Text(details.length == DetailKind.values.length ? t('plot.detailsNone') : t('plot.detailsAll'), style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final k in DetailKind.values)
                      FilterChip(
                        key: Key('plot_detail_${k.name}'),
                        label: Text(t(detailTitleKey(k, detailCtx!)), style: const TextStyle(fontSize: 11)),
                        selected: details.contains(k),
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) => setState(() => v ? details.add(k) : details.remove(k)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                check(
                  t('plot.charts'),
                  o.charts && chartsAvailable,
                  (v) => setState(() => o = o.copyWith(charts: v)),
                  enabled: chartsAvailable,
                  key: const Key('plot_charts'),
                ),
                // 1.6.0 PRD: the thematic sheets of the terrain
                for (final th in SheetTheme.values)
                  check(
                    t('prd.plot.theme.${th.name}'),
                    terrain && o.themes.contains(th),
                    (v) => setState(() => o = o.copyWith(themes: [for (final x in SheetTheme.values) if (x == th ? v : o.themes.contains(x)) x])),
                    enabled: terrain,
                    key: Key('plot_theme_${th.name}'),
                  ),
                if (!terrain)
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(t('prd.plot.themeNoTerrain'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    t('plot.sheetCount', {'n': '$sheetsTotal'}),
                    key: const Key('plot_sheet_count'),
                    style: TextStyle(fontSize: 11, color: Cad.fg54),
                  ),
                ),
              ];
        return AlertDialog(
          title: Text(raster ? t('plot.pngTitle') : t('plot.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, raster ? 440 : (wide ? 760 : 440)),
            child: ScrollBody(
              child: wide && !raster
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: page),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: sheets),
                        ),
                      ],
                    )
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [...page, if (sheets.isNotEmpty) const Divider(height: 14), ...sheets]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('plot_ok'),
              onPressed: busy
                  ? null
                  : () async {
                      var res = result();
                      if (withMap && mapAvailable) {
                        setState(() => busy = true);
                        res = await withSheetBaseMap(c, res, dpi: raster ? res.dpi : sheetMapDpi);
                      }
                      if (ctx.mounted) Navigator.pop(ctx, res);
                    },
              child: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('plot.export')),
            ),
          ],
        );
      },
    ),
  );
}

/// Resolutions offered for the PNG image of a sheet (dots per inch).
const pngResolutionsOffered = [96.0, 150.0, 200.0, 300.0];
