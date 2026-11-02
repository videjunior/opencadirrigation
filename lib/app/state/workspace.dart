/// Several open projects (tabs) and the clipboard used to copy entities
/// between them. The clipboard payload is also written to the system
/// clipboard as JSON so it can be pasted into another browser window.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/io/geo.dart';
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import 'controller.dart';

/// Entities copied from a project, with the layers and catalog items they use.
class ClipboardPayload {
  ClipboardPayload({required this.sourceTab, required this.entities, required this.layers, required this.catalog, this.georef});
  static const format = 'opencadirrigation-clipboard';
  final int sourceTab;
  final List<Map<String, dynamic>> entities;

  /// Layer name → ARGB colour.
  final Map<String, int> layers;

  /// Catalog subset: pipes/outlets/tapes/valves/pumps referenced by the entities.
  final Map<String, List<Map<String, dynamic>>> catalog;

  int get count => entities.length;

  /// Georeference of the project the entities were copied from (1.6.0):
  /// pasted into a project georeferenced elsewhere, they land on the same
  /// place of the map, not at the same drawing coordinates.
  final GeoReference? georef;

  /// The last [pasteInto] moved the entities to the same place of the map
  /// (the two projects have different origins).
  bool placedOnMap = false;

  Map<String, dynamic> toJson() => {'format': format, 'version': 1, 'source': sourceTab, 'entities': entities, 'layers': layers, 'catalog': catalog, if (georef != null) 'georef': georef!.toJson()};
  String encode() => jsonEncode(toJson());

  static ClipboardPayload? tryParse(String? text) {
    if (text == null || !text.contains(format)) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['format'] != format) return null;
      return ClipboardPayload(
        sourceTab: (j['source'] as num?)?.toInt() ?? 0,
        entities: (j['entities'] as List).cast<Map<String, dynamic>>(),
        layers: ((j['layers'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        catalog: ((j['catalog'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as List).cast<Map<String, dynamic>>())),
        georef: j['georef'] is Map ? GeoReference.fromJson((j['georef'] as Map).cast<String, dynamic>()) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Snapshot of the selected entities of [c].
  static ClipboardPayload fromSelection(ProjectController c) {
    final p = c.project;
    final ents = p.entities.where((e) => c.selection.contains(e.id)).toList();
    final pipes = <String>{}, outlets = <String>{}, tapes = <String>{}, valves = <String>{}, pumps = <String>{};
    for (final e in ents) {
      switch (e) {
        case PipeEntity x:
          if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
        case SpraylineEntity x:
          if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
          outlets.add(x.outletSpecId);
        case TapeEntity x:
          tapes.add(x.tapeSpecId);
        case OutletEntity x:
          outlets.add(x.outletSpecId);
        case ControlValveEntity x:
          if (x.valveSpecId != null) valves.add(x.valveSpecId!);
        case MiscHydraulicEntity x:
          if (x.valveSpecId != null) valves.add(x.valveSpecId!);
        case PumpEntity x:
          if (x.pumpSpecId != null) pumps.add(x.pumpSpecId!);
        case PivotEntity x:
          if (x.pipeSpecId != null) pipes.add(x.pipeSpecId!);
          if (x.sprinklerSpecId != null) outlets.add(x.sprinklerSpecId!);
          if (x.regulatorSpecId != null) valves.add(x.regulatorSpecId!);
        default:
          break;
      }
    }
    final cat = p.catalog;
    return ClipboardPayload(
      sourceTab: c.tabId,
      georef: p.meta.georef,
      entities: ents.map((e) => e.toJson()).toList(),
      layers: {for (final e in ents) e.layer: p.layerNamed(e.layer).color},
      catalog: {
        'pipes': [
          for (final id in pipes)
            if (cat.pipe(id) != null) cat.pipe(id)!.toJson(),
        ],
        'outlets': [
          for (final id in outlets)
            if (cat.outlet(id) != null) cat.outlet(id)!.toJson(),
        ],
        'tapes': [
          for (final id in tapes)
            if (cat.tape(id) != null) cat.tape(id)!.toJson(),
        ],
        'valves': [
          for (final id in valves)
            if (cat.valve(id) != null) cat.valve(id)!.toJson(),
        ],
        'pumps': [
          for (final id in pumps)
            if (cat.pump(id) != null) cat.pump(id)!.toJson(),
        ],
      },
    );
  }

  /// Adds the entities to [c] (new ids; missing layers and catalog items are
  /// created). Pasting back into the source project offsets the copies so
  /// they are visible. Returns the new ids, which become the selection.
  List<String> pasteInto(ProjectController c) {
    final same = sourceTab == c.tabId;
    final offset = same ? const Pt(2, -2) : Pt.zero;
    final ids = <String>[];
    // from the source drawing to this one: the same place of the map
    final place = same ? null : _placeIn(c.project);
    placedOnMap = place != null;
    final adopt = !same && georef != null && c.project.meta.georef == null && c.project.entities.isEmpty;
    c.mutate(() {
      final p = c.project;
      // a blank project takes the georeference of what is pasted into it
      if (adopt) p.meta.georef = georef;
      layers.forEach((name, color) {
        if (p.layers.every((l) => l.name != name)) p.layers.add(Layer(name: name, color: color));
      });
      final cat = p.catalog;
      for (final j in catalog['pipes'] ?? const []) {
        final s = PipeSpec.fromJson(j);
        if (cat.pipe(s.id) == null) cat.pipes.add(s);
      }
      for (final j in catalog['outlets'] ?? const []) {
        final s = OutletSpec.fromJson(j);
        if (cat.outlet(s.id) == null) cat.outlets.add(s);
      }
      for (final j in catalog['tapes'] ?? const []) {
        final s = TapeSpec.fromJson(j);
        if (cat.tape(s.id) == null) cat.tapes.add(s);
      }
      for (final j in catalog['valves'] ?? const []) {
        final s = ValveSpec.fromJson(j);
        if (cat.valve(s.id) == null) cat.valves.add(s);
      }
      for (final j in catalog['pumps'] ?? const []) {
        final s = PumpSpec.fromJson(j);
        if (cat.pump(s.id) == null) cat.pumps.add(s);
      }
      for (final j in entities) {
        var e = Entity.fromJson(j).clone(newId: p.newId());
        e = place == null ? e.translated(offset) : e.transformed(place);
        p.entities.add(e);
        ids.add(e.id);
      }
    }, label: 'hist.paste');
    // refused (a design is running): keep the selection
    if (ids.isNotEmpty) c.select(ids);
    return ids;
  }
}

extension on ClipboardPayload {
  /// The transform that puts the copied entities on the same place of the
  /// map in [target]: null when either project has no georeference or both
  /// share it. In the same UTM zone it is the shift between the origins;
  /// across zones, the affine fit through the corners of the copied
  /// items (exact enough at the size of a farm).
  Affine? _placeIn(Project target) {
    final from = georef, to = target.meta.georef;
    if (from == null || to == null) return null;
    if (from.zone == to.zone && from.north == to.north) {
      final d = Pt(from.originEasting - to.originEasting, from.originNorthing - to.originNorthing);
      return d.length < 1e-6 ? null : Affine.translation(d);
    }
    var b = Bounds.empty;
    for (final j in entities) {
      try {
        b = b.union(Entity.fromJson(j).bounds);
      } catch (_) {}
    }
    if (b.isEmpty) return null;
    final w = math.max(b.width, 1.0), h = math.max(b.height, 1.0);
    final p0 = Pt(b.minX, b.minY), p1 = Pt(b.minX + w, b.minY), p2 = Pt(b.minX, b.minY + h);
    Pt map(Pt p) {
      final (lat, lon) = from.toLatLon(p.x, p.y);
      final (x, y) = to.fromLatLon(lat, lon);
      return Pt(x, y);
    }

    final q0 = map(p0), q1 = map(p1), q2 = map(p2);
    final u1 = p1 - p0, u2 = p2 - p0, v1 = q1 - q0, v2 = q2 - q0;
    final det = u1.x * u2.y - u2.x * u1.y;
    final a = (v1.x * u2.y - v2.x * u1.y) / det, c = (v2.x * u1.x - v1.x * u2.x) / det;
    final bb = (v1.y * u2.y - v2.y * u1.y) / det, d = (v2.y * u1.x - v1.y * u2.x) / det;
    return Affine(a, bb, c, d, q0.x - (a * p0.x + c * p0.y), q0.y - (bb * p0.x + d * p0.y));
  }
}

/// Open project tabs plus the shared clipboard.
class Workspace extends ChangeNotifier {
  Workspace({this.systemClipboard = true, bool openBlankTab = true}) {
    if (openBlankTab) addTab();
  }

  /// Mirror copies to the OS clipboard (disabled in unit tests).
  final bool systemClipboard;
  final List<ProjectController> tabs = [];
  int _active = 0;
  int _seq = 0;

  /// Internal clipboard (last copy in this window).
  ClipboardPayload? clipboard;

  int get active => _active;
  ProjectController get current => tabs[_active];

  /// Adds a tab. A fresh controller starts as a blank project in the
  /// workspace language.
  ProjectController addTab({ProjectController? controller, bool select = true}) {
    final c = controller ?? ProjectController();
    c.tabId = ++_seq;
    if (tabs.isNotEmpty && c.lang != tabs.first.lang) c.setLanguage(tabs.first.lang, persist: false);
    c.onLanguageChanged = _propagateLanguage;
    // two tabs never work on the same project uid (a file opened twice, a version opened beside its project)
    c.uidTaken = (uid) => tabs.any((t) => !identical(t, c) && t.project.meta.uid == uid);
    if (controller == null) c.newProject();
    tabs.add(c);
    if (select) _active = tabs.length - 1;
    notifyListeners();
    return c;
  }

  void _propagateLanguage(String lang) {
    for (final t in tabs) {
      if (t.lang != lang) t.setLanguage(lang, persist: false);
    }
    notifyListeners();
  }

  void select(int i) {
    if (i < 0 || i >= tabs.length || i == _active) return;
    _active = i;
    notifyListeners();
  }

  void next() => select((_active + 1) % tabs.length);
  void previous() => select((_active - 1 + tabs.length) % tabs.length);

  /// Removes a tab; the workspace always keeps at least one. The tab's
  /// controller is disposed (its GPS, timers, design worker and window lock
  /// go with it; a copy being written still completes).
  void closeTab(int i) {
    if (i < 0 || i >= tabs.length) return;
    final c = tabs.removeAt(i);
    c.onLanguageChanged = null;
    c.uidTaken = null;
    if (tabs.isEmpty) {
      _active = 0;
      addTab();
    } else {
      if (i < _active || _active >= tabs.length) _active = (_active - 1).clamp(0, tabs.length - 1);
      notifyListeners();
    }
    // after the listeners let go of it
    scheduleMicrotask(c.dispose);
  }

  /// Copies (or cuts) the selection of the current tab. Returns the count.
  Future<int> copy({bool cut = false}) async {
    final c = current;
    if (c.selection.isEmpty) return 0;
    // a cut refused (a design running) copies nothing either
    if (cut && !c.editAllowed()) return 0;
    final p = ClipboardPayload.fromSelection(c);
    clipboard = p;
    if (cut) c.deleteSelected();
    await _writeSystem(p.encode());
    return p.count;
  }

  /// Pastes into the current tab: the system clipboard wins when it holds a
  /// newer payload (copied in another window), else the internal one.
  Future<int> paste() async {
    var p = ClipboardPayload.tryParse(await _readSystem());
    p ??= clipboard;
    if (p == null) return 0;
    lastPaste = p;
    return p.pasteInto(current).length;
  }

  /// The payload the last [paste] used.
  ClipboardPayload? lastPaste;

  Future<void> _writeSystem(String text) async {
    if (!systemClipboard) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // clipboard unavailable (permissions, tests): the internal copy is enough
    }
  }

  Future<String?> _readSystem() async {
    if (!systemClipboard) return null;
    try {
      // Reading may prompt for permission in the browser; do not block paste on it.
      final data = await Clipboard.getData(Clipboard.kTextPlain).timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
      return data?.text;
    } catch (_) {
      return null;
    }
  }
}
