/// Dialogs used by the exporters: project georeference and PDF plot options.
library;

import 'package:flutter/material.dart';

import '../../../core/io/geo.dart';
import '../../../core/io/pdf_sheet.dart';
import '../../state/controller.dart';

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
  String? error;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      double? num(TextEditingController tc) => double.tryParse(tc.text.trim().replaceAll(',', '.'));
      GeoReference? parse() {
        if (useUtm) {
          final z = int.tryParse(zone.text.trim()), e = num(east), n = num(north);
          if (z == null || z < 1 || z > 60 || e == null || n == null) return null;
          return GeoReference(zone: z, north: northern, originEasting: e, originNorthing: n);
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
        return GeoReference.fromLatLonOrigin(la, lo);
      }

      Widget field(TextEditingController tc, String label, {String? suffix}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(key: Key('geo_${label.hashCode}'), controller: tc, decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), style: const TextStyle(fontSize: 12)),
      );
      return AlertDialog(
        title: Text(t('geo.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('geo.explain'), style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35)),
            const SizedBox(height: 8),
            Text(g == null ? t('geo.none') : t('geo.current', {'crs': g.crsName, 'e': g.originEasting.toStringAsFixed(0), 'n': g.originNorthing.toStringAsFixed(0)}), style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: [ButtonSegment(value: false, label: Text(t('geo.modeLatLon'), style: const TextStyle(fontSize: 12))), ButtonSegment(value: true, label: Text(t('geo.modeUtm'), style: const TextStyle(fontSize: 12)))],
              selected: {useUtm},
              onSelectionChanged: (s) => setState(() => useUtm = s.first),
            ),
            if (!useUtm) ...[
              Row(children: [Expanded(child: field(lat, t('geo.lat'))), const SizedBox(width: 8), Expanded(child: field(lon, t('geo.lon')))]),
            ] else ...[
              Row(children: [
                Expanded(child: field(zone, t('geo.zone'))),
                const SizedBox(width: 8),
                Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('geo.north'), style: const TextStyle(fontSize: 12)), value: northern, onChanged: (v) => setState(() => northern = v))),
              ]),
              Row(children: [Expanded(child: field(east, t('geo.easting'), suffix: 'm')), const SizedBox(width: 8), Expanded(child: field(north, t('geo.northing'), suffix: 'm'))]),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(fontSize: 12, color: Colors.orangeAccent))),
          ]),
        ),
        actions: [
          if (g != null)
            TextButton(
              onPressed: () {
                c.project.meta.georef = null;
                c.dirty = true;
                c.refresh();
                Navigator.pop(ctx, false);
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
              c.project.meta.georef = ref;
              c.dirty = true;
              c.notify(t('msg.georefSet', {'crs': ref.crsName}));
              Navigator.pop(ctx, true);
            },
            child: Text(t('ok')),
          ),
        ],
      );
    }),
  );
}

/// Plot sheet options for the PDF export. Returns null when cancelled.
Future<SheetOptions?> showPlotDialog(BuildContext context, ProjectController c, {SheetOptions initial = const SheetOptions()}) {
  final t = c.t;
  var o = initial;
  var fit = o.scale == null;
  final scaleCtl = TextEditingController(text: (o.scale ?? c.exporter().sheetBuilder().sheetScale(o)).round().toString());
  return showDialog<SheetOptions>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final autoScale = c.exporter().sheetBuilder().sheetScale(o.copyWith(clearScale: true));
      Widget check(String label, bool value, ValueChanged<bool> on, {bool enabled = true}) => CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text(label, style: const TextStyle(fontSize: 12)), value: value, onChanged: enabled ? (v) => on(v ?? false) : null);
      return AlertDialog(
        title: Text(t('plot.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<PageSize>(
                  isExpanded: true,
                  initialValue: o.page,
                  decoration: InputDecoration(labelText: t('plot.page'), isDense: true),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  items: [for (final p in PageSize.values) DropdownMenuItem(value: p, child: Text('${p.label}  (${p.shortMm.round()} × ${p.longMm.round()} mm)', style: const TextStyle(fontSize: 12)))],
                  onChanged: (v) => setState(() => o = o.copyWith(page: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  isExpanded: true,
                  initialValue: o.landscape,
                  decoration: InputDecoration(labelText: t('plot.orientation'), isDense: true),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  items: [DropdownMenuItem(value: true, child: Text(t('plot.landscape'), style: const TextStyle(fontSize: 12))), DropdownMenuItem(value: false, child: Text(t('plot.portrait'), style: const TextStyle(fontSize: 12)))],
                  onChanged: (v) => setState(() => o = o.copyWith(landscape: v)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: check(t('plot.scaleAuto'), fit, (v) => setState(() {
                fit = v;
                if (v) scaleCtl.text = autoScale.round().toString();
              }))),
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
            ]),
            Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(t('plot.fits', {'n': autoScale.round().toString()}), style: const TextStyle(fontSize: 11, color: Colors.white54))),
            const Divider(height: 14),
            check(t('plot.labels'), o.labels, (v) => setState(() => o = o.copyWith(labels: v))),
            check(t('plot.wetted'), o.wettedRadii, (v) => setState(() => o = o.copyWith(wettedRadii: v))),
            check(t('plot.legend'), o.legend, (v) => setState(() => o = o.copyWith(legend: v))),
            check(t('plot.bomOnSheet'), o.bomOnSheet && c.results != null, (v) => setState(() => o = o.copyWith(bomOnSheet: v)), enabled: c.results != null),
            check(t('plot.reports'), o.includeReports && c.results != null, (v) => setState(() => o = o.copyWith(includeReports: v)), enabled: c.results != null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          FilledButton(
            key: const Key('plot_ok'),
            onPressed: () {
              final s = double.tryParse(scaleCtl.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, fit || s == null || s <= 0 ? o.copyWith(clearScale: true) : o.copyWith(scale: s));
            },
            child: Text(t('plot.export')),
          ),
        ],
      );
    }),
  );
}
