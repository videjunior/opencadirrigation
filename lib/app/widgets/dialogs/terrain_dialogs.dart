/// Terrain and checking dialogs: elevation prompt for contours / spot
/// heights, online DEM download, contour generation, the design check and
/// the manufacturer catalogue packs.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/io/dem_online.dart';
import '../../../core/io/geo.dart' show parseLatLon;
import '../../../core/io/project_export.dart' show GeoReferenceMissing;
import '../../../core/model/entities.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../advice_panel.dart';
import '../fields.dart';
import 'export_dialogs.dart';

Widget _row(List<Widget> children) => Row(children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])]]);

/// Dialog width that fits phones as well as desktops.
double dialogWidth(BuildContext context, double preferred) {
  final w = MediaQuery.sizeOf(context).width;
  return preferred.clamp(200, w - 32).toDouble();
}

// ---------------------------------------------------------------- elevation prompt

/// Asks the elevation of a contour or spot height that was just drawn.
/// Cancel removes the entity again (undo).
Future<void> showElevationDialog(BuildContext context, ProjectController c, Entity e) async {
  final t = c.t;
  final s = c.toolSettings;
  final isContour = e is ContourEntity;
  final initial = isContour ? e.elevation : (e as SpotHeightEntity).elevation;
  final ctl = TextEditingController(text: fmt(initial, 2));
  final intervalCtl = TextEditingController(text: fmt(s.contourInterval, 2));
  var autoInc = s.contourAutoIncrement;
  var ask = s.askElevation;
  void apply(BuildContext ctx) {
    final z = double.tryParse(ctl.text.replaceAll(',', '.'));
    if (z == null) return;
    final interval = double.tryParse(intervalCtl.text.replaceAll(',', '.')) ?? s.contourInterval;
    c.mutate(() {
      if (e is ContourEntity) e.elevation = z;
      if (e is SpotHeightEntity) e.elevation = z;
    }, label: 'hist.elevation');
    s.askElevation = ask;
    if (isContour) {
      s.contourInterval = interval;
      s.contourAutoIncrement = autoInc;
      s.contourElevation = autoInc ? z + interval : z;
    } else {
      s.spotElevation = z;
    }
    c.track('elevation');
    Navigator.pop(ctx);
  }

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(t(isContour ? 'elev.contourTitle' : 'elev.spotTitle'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 380),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t(isContour ? 'elev.explainContour' : 'elev.explainSpot'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 10),
            TextField(
              key: const Key('elev_value'),
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
              decoration: InputDecoration(labelText: t('elev.value'), isDense: true),
              onSubmitted: (_) => apply(ctx),
              onTap: () => ctl.selection = TextSelection(baseOffset: 0, extentOffset: ctl.text.length),
            ),
            if (isContour) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('elev_interval'),
                controller: intervalCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t('elev.interval'), isDense: true),
                onSubmitted: (_) => apply(ctx),
              ),
              SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('elev.autoIncrement'), style: const TextStyle(fontSize: 12)), value: autoInc, onChanged: (v) => setState(() => autoInc = v)),
            ],
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('elev.ask'), style: const TextStyle(fontSize: 12)), value: ask, onChanged: (v) => setState(() => ask = v)),
          ]),
        ),
        actions: [
          TextButton(key: const Key('elev_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          FilledButton(key: const Key('elev_ok'), onPressed: () => apply(ctx), child: Text(t('ok'))),
        ],
      );
    }),
  );
  if (ok == false) c.undo();
}

// ---------------------------------------------------------------- online DEM

Future<void> showOnlineDemDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  // sources the platform can reach (OpenTopoData has no CORS header)
  final sources = DemSource.values.where((s) => s.browserOk || !kIsWeb).toList();
  var source = DemSource.terrainTiles;
  var spacing = 25.0;
  var maxPoints = 5000.0;
  var useView = c.project.bounds.isEmpty;
  var replace = true;
  // the user's own contours / spot heights (survey, typed, example data)
  // are usually on another datum than the DEM: replaced by default
  var own = c.ownTerrainData();
  var replaceExisting = own.isNotEmpty;
  var busy = false;
  var cancel = false;
  var done = 0, total = 0;
  Duration? waiting;
  String? error;
  // "type a coordinate": georeference an empty drawing at a pasted position
  final coordCtl = TextEditingController();
  var areaSize = 500.0;
  String? coordError;
  // contours drawn from the downloaded model when the download finishes
  var contours = c.terrainIsEmpty || replaceExisting;
  var contourInterval = 0.0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final geo = c.project.meta.georef;
      var b = useView ? c.camera.visible : c.project.bounds;
      if (b.isEmpty) b = c.camera.visible;
      final grid = geo == null || b.isEmpty ? const <DemGridPoint>[] : demGrid(b, spacing, geo, maxPoints: maxPoints.round());
      final n = grid.length;
      final requests = source.requestCount(grid, demGridStep(grid, spacing));
      final eta = source.estimateDuration(n, requests: requests);
      String etaText() => eta.inSeconds >= 90 ? '≈ ${(eta.inSeconds / 60).ceil()} min' : '≈ ${eta.inSeconds} s';
      void useCoordinate() {
        final pair = parseLatLon(coordCtl.text);
        if (pair == null) {
          setState(() => coordError = t('dem.online.coordInvalid'));
          return;
        }
        c.setGeoreferenceAt(pair.$1, pair.$2, viewSizeM: areaSize);
        setState(() {
          coordError = null;
          if (c.project.bounds.isEmpty) useView = true;
        });
      }

      return AlertDialog(
        title: Text(t('dem.online.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 460),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('dem.online.explain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 8),
            if (geo == null) ...[
              Text(t('dem.online.coordExplain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
              const SizedBox(height: 4),
              TextField(
                key: const Key('dem_coord'),
                controller: coordCtl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(labelText: t('dem.online.coord'), hintText: t('dem.online.coordHint'), isDense: true, errorText: coordError),
                onSubmitted: (_) => useCoordinate(),
              ),
              const SizedBox(height: 4),
              _row([
                if (c.project.bounds.isEmpty) NumField(label: t('dem.online.areaSize'), value: areaSize, decimals: 0, onChanged: (v) => setState(() => areaSize = v.clamp(50, 20000))),
                FilledButton.tonal(key: const Key('dem_use_coord'), onPressed: useCoordinate, child: Text(t('dem.online.useCoord'), style: const TextStyle(fontSize: 12))),
                OutlinedButton.icon(
                  key: const Key('dem_georef'),
                  onPressed: () async {
                    await showGeoreferenceDialog(ctx, c);
                    setState(() {});
                  },
                  icon: const Icon(Icons.public, size: 16),
                  label: Text(t('file.georef'), style: const TextStyle(fontSize: 12)),
                ),
              ]),
            ] else ...[
              Text(geo.crsName, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              SpecDropdown<DemSource>(label: t('dem.online.source'), value: source.name, items: sources, labelOf: (x) => x.label, idOf: (x) => x.name, onChanged: (v) => setState(() => source = DemSource.values.byName(v!))),
              _row([
                NumField(label: t('dem.online.spacing'), value: spacing, onChanged: (v) => setState(() => spacing = v <= 1 ? 1 : v)),
                NumField(label: t('dem.online.maxPoints'), value: maxPoints, decimals: 0, onChanged: (v) => setState(() => maxPoints = v.clamp(100, 20000))),
              ]),
              SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dem.online.useView'), style: const TextStyle(fontSize: 12)), value: useView, onChanged: (v) => setState(() => useView = v)),
              SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dem.online.replace'), style: const TextStyle(fontSize: 12)), value: replace, onChanged: (v) => setState(() => replace = v)),
              if (own.isNotEmpty) ...[
                Text(t('dem.online.existing', {'n': '${own.spots}', 'm': '${own.contours}', 'a': fmt(own.lo, 1), 'b': fmt(own.hi, 1)}), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                SwitchListTile(key: const Key('dem_replace_existing'), dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dem.online.replaceExisting'), style: const TextStyle(fontSize: 12)), value: replaceExisting, onChanged: (v) => setState(() => replaceExisting = v)),
                if (!replaceExisting) Text(t('dem.online.keepWarn'), style: const TextStyle(fontSize: 11, color: CadColors.warning)),
              ],
              Text(b.isEmpty ? t('dem.online.empty') : t('dem.online.extent', {'w': fmt(b.width, 0), 'h': fmt(b.height, 0), 'n': '$n', 'r': '$requests'}) + (eta.inSeconds >= 10 ? ' · ${t('dem.online.estimate', {'t': etaText()})}' : ''), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
              if (source.pointsPerMinute != null && n > source.pointsPerMinute!) Text(t('dem.online.limitHint'), style: const TextStyle(fontSize: 11, color: CadColors.warning)),
              Text('${source.attribution} · ${t('dem.online.layerHint')}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              SwitchListTile(key: const Key('dem_contours'), dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dem.online.contours'), style: const TextStyle(fontSize: 12)), value: contours, onChanged: (v) => setState(() => contours = v)),
              if (contours) NumField(label: t('dem.online.contourInterval'), value: contourInterval, onChanged: (v) => setState(() => contourInterval = v < 0 ? 0 : v)),
            ],
            if (busy) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: total == 0 ? null : done / total),
              Text(t('dem.online.progress', {'i': '$done', 'n': '$total'}) + (waiting != null ? ' · ${t('dem.online.wait', {'s': '${waiting!.inSeconds}'})}' : ''), key: const Key('dem_progress'), style: const TextStyle(fontSize: 11)),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('dem.online.error', {'e': error!}), style: const TextStyle(fontSize: 11.5, color: CadColors.unconnected))),
          ]),
        ),
        actions: [
          TextButton(
            key: const Key('dem_close'),
            onPressed: busy ? (cancel ? null : () => setState(() => cancel = true)) : () => Navigator.pop(ctx),
            child: Text(busy ? t('cancel') : t('close')),
          ),
          FilledButton.icon(
            key: const Key('dem_run'),
            onPressed: geo == null || busy || n == 0
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      cancel = false;
                      waiting = null;
                      error = null;
                    });
                    try {
                      final res = await c.importOnlineDem(
                        source,
                        spacing: spacing,
                        useView: useView,
                        replacePrevious: replace,
                        replaceExisting: replaceExisting,
                        maxPoints: maxPoints.round(),
                        cancelled: () => cancel,
                        onWait: (w) {
                          waiting = w;
                          if (ctx.mounted) setState(() {});
                        },
                        onProgress: (d, tot) {
                          done = d;
                          total = tot;
                          waiting = null;
                          if (ctx.mounted) setState(() {});
                        },
                      );
                      final count = res.count;
                      if (res.datumMismatch && ctx.mounted) {
                        // kept data on another datum: offer to drop it now
                        final remove = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: Text(t('dem.online.mismatchTitle'), style: const TextStyle(fontSize: 15)),
                            content: SizedBox(width: dialogWidth(d, 420), child: Text(t('dem.online.mismatch', {'a': fmt(res.ownRange.$1, 1), 'b': fmt(res.ownRange.$2, 1), 'c': fmt(res.range.$1, 1), 'd': fmt(res.range.$2, 1)}), style: const TextStyle(fontSize: 12))),
                            actions: [
                              TextButton(key: const Key('dem_mismatch_keep'), onPressed: () => Navigator.pop(d, false), child: Text(t('dem.online.mismatchKeep'))),
                              FilledButton(key: const Key('dem_mismatch_remove'), onPressed: () => Navigator.pop(d, true), child: Text(t('dem.online.mismatchRemove'))),
                            ],
                          ),
                        );
                        if (remove == true) c.removeOwnTerrainData();
                      }
                      final noData = res.noData > 0 ? ' · ${t('dem.online.noData', {'n': '${res.noData}'})}' : '';
                      if (contours && count > 0) {
                        final interval = contourInterval > 0 ? contourInterval : c.autoContourInterval();
                        final drawn = c.generateContours(interval);
                        c.notify(t('dem.online.doneContours', {'n': '$count', 's': source.attribution, 'c': '$drawn', 'i': fmt(interval, 2)}) + noData);
                      } else {
                        c.notify(t('dem.online.done', {'n': '$count', 's': source.attribution}) + noData);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } on DemCancelled {
                      c.notify(t('dem.online.cancelled'));
                      if (ctx.mounted) setState(() => busy = false);
                    } catch (e) {
                      error = e is GeoReferenceMissing ? t('geo.none') : c.describeError(e);
                      if (ctx.mounted) setState(() => busy = false);
                    }
                  },
            icon: const Icon(Icons.cloud_download_outlined, size: 16),
            label: Text(t('dem.online.run')),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------- contour generation

Future<void> showGenerateContoursDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final terrain = c.project.buildTerrain();
  if (terrain.isEmpty) {
    c.notify(t('dem.noData'));
    return Future.value();
  }
  final (lo, hi) = terrain.elevationRange;
  var interval = (hi - lo) > 20 ? 5.0 : ((hi - lo) > 5 ? 1.0 : 0.5);
  var replace = true;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final preview = interval > 0 ? terrain.generateContours(interval) : const <(double, List<Object>)>[];
      return AlertDialog(
        title: Text(t('cgen.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('cgen.explain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(t('terrain.stats', {'n': '${terrain.sampleCount}', 'a': fmt(lo, 1), 'b': fmt(hi, 1)}), style: const TextStyle(fontSize: 11.5)),
            NumField(label: t('cgen.interval'), value: interval, onChanged: (v) => setState(() => interval = v <= 0 ? interval : v)),
            SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('cgen.replace'), style: const TextStyle(fontSize: 12)), value: replace, onChanged: (v) => setState(() => replace = v)),
            Text(t('cgen.preview', {'n': '${preview.length}', 'a': fmt(lo, 1), 'b': fmt(hi, 1)}), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          FilledButton(
            key: const Key('cgen_run'),
            onPressed: () {
              final n = c.generateContours(interval, replacePrevious: replace);
              c.notify(t('cgen.done', {'n': '$n'}));
              Navigator.pop(ctx);
            },
            child: Text(t('cgen.run')),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------- design check

Future<void> showDesignCheckDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  c.runDesignCheckReport();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('check.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 620),
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('check.explain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 4),
          // the same assistant as the Messages tab: why, how to fix, corrections
          Expanded(child: AdvicePanel(c: c, listKey: const Key('check_list'))),
        ]),
      ),
      actions: [
        TextButton.icon(key: const Key('check_rerun'), onPressed: c.runDesignCheckReport, icon: const Icon(Icons.refresh, size: 16), label: Text(t('check.run'))),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
      ],
    ),
  );
}

/// Convenience row helper shared with other dialog files.
Widget dialogRow(List<Widget> children) => _row(children);
