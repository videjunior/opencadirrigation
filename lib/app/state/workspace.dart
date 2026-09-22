/// Several open projects (tabs) and the clipboard used to copy entities
/// between them. The clipboard payload is also written to the system
/// clipboard as JSON so it can be pasted into another browser window.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project.dart';
import 'controller.dart';

/// Entities copied from a project, with the layers and catalog items they use.
class ClipboardPayload {
  ClipboardPayload({required this.sourceTab, required this.entities, required this.layers, required this.catalog});
  static const format = 'opencadirrigation-clipboard';
  final int sourceTab;
  final List<Map<String, dynamic>> entities;

  /// Layer name → ARGB colour.
  final Map<String, int> layers;

  /// Catalog subset: pipes/outlets/tapes/valves/pumps referenced by the entities.
  final Map<String, List<Map<String, dynamic>>> catalog;

  int get count => entities.length;

  Map<String, dynamic> toJson() => {'format': format, 'version': 1, 'source': sourceTab, 'entities': entities, 'layers': layers, 'catalog': catalog};
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
      entities: ents.map((e) => e.toJson()).toList(),
      layers: {for (final e in ents) e.layer: p.layerNamed(e.layer).color},
      catalog: {
        'pipes': [for (final id in pipes) if (cat.pipe(id) != null) cat.pipe(id)!.toJson()],
        'outlets': [for (final id in outlets) if (cat.outlet(id) != null) cat.outlet(id)!.toJson()],
        'tapes': [for (final id in tapes) if (cat.tape(id) != null) cat.tape(id)!.toJson()],
        'valves': [for (final id in valves) if (cat.valve(id) != null) cat.valve(id)!.toJson()],
        'pumps': [for (final id in pumps) if (cat.pump(id) != null) cat.pump(id)!.toJson()],
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
    c.mutate(() {
      final p = c.project;
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
        final e = Entity.fromJson(j).clone(newId: p.newId()).translated(offset);
        p.entities.add(e);
        ids.add(e.id);
      }
    }, label: 'hist.paste');
    c.select(ids);
    return ids;
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

  /// Removes a tab; the workspace always keeps at least one.
  void closeTab(int i) {
    if (i < 0 || i >= tabs.length) return;
    final c = tabs.removeAt(i);
    c.onLanguageChanged = null;
    if (tabs.isEmpty) {
      _active = 0;
      addTab();
      return;
    }
    if (i < _active || _active >= tabs.length) _active = (_active - 1).clamp(0, tabs.length - 1);
    notifyListeners();
  }

  /// Copies (or cuts) the selection of the current tab. Returns the count.
  Future<int> copy({bool cut = false}) async {
    final c = current;
    if (c.selection.isEmpty) return 0;
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
    return p.pasteInto(current).length;
  }

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
