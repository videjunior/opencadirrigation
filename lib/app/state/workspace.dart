/// Several open projects (tabs) and the clipboard used to copy entities
/// between them. The clipboard payload is also written to the system
/// clipboard as JSON so it can be pasted into another browser window.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/model/geometry.dart';
import '../../core/model/paste.dart';
import 'controller.dart';

/// Entities copied from a project, with the layers and catalog items they use.
class ClipboardPayload {
  ClipboardPayload({required this.sourceTab, required this.entities, required this.layers, required this.catalog, this.currency = '', this.projectUid = ''});
  static const format = 'opencadirrigation-clipboard';
  final int sourceTab;
  final List<Map<String, dynamic>> entities;

  /// Layer name → ARGB colour.
  final Map<String, int> layers;

  /// Catalog subset: pipes/outlets/tapes/valves/pumps referenced by the entities.
  final Map<String, List<Map<String, dynamic>>> catalog;

  /// ISO code of the prices of the source project (converted on paste).
  final String currency;

  /// The project copied from: a paste into it keeps the references to the
  /// entities left behind.
  final String projectUid;

  int get count => entities.length;

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': 1,
    'source': sourceTab,
    'entities': entities,
    'layers': layers,
    'catalog': catalog,
    if (currency.isNotEmpty) 'currency': currency,
    if (projectUid.isNotEmpty) 'project': projectUid,
  };
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
        currency: j['currency'] as String? ?? '',
        projectUid: j['project'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Snapshot of the selected entities of [c].
  static ClipboardPayload fromSelection(ProjectController c) {
    final p = c.project;
    final ents = p.entities.where((e) => c.selection.contains(e.id)).toList();
    return ClipboardPayload(
      sourceTab: c.tabId,
      entities: ents.map((e) => e.toJson()).toList(),
      layers: {for (final e in ents) e.layer: p.layerNamed(e.layer).color},
      // the items the entities use, the end gun of a pivot included
      catalog: catalogSubset(p.catalog, ents),
      currency: p.params.currencyCode,
      projectUid: p.meta.uid,
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
      // an item of the same id but other data is renamed, prices follow the
      // currency, references between the copies follow them
      final r = pasteEntities(
        c.project,
        entities,
        layers: layers,
        catalog: catalog,
        currency: currency,
        offset: offset,
        sameProject: same || (projectUid.isNotEmpty && projectUid == c.project.meta.uid),
      );
      ids.addAll(r.ids);
    }, label: 'hist.paste');
    // refused (a design is running): keep the selection
    if (ids.isNotEmpty) c.select(ids);
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
