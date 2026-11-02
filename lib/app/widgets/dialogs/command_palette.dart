/// The command palette (Ctrl+K, Help → Search commands): any item of the
/// menus, any typed command and the switches of the screen, found by its
/// name in the interface language or in English (accents and case
/// ignored), and run from the keyboard or with a tap. On a phone the same
/// search sits at the top of the ☰ menu ([PhoneMenuSearch]).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n.dart';
import '../../shortcuts.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../ui_prefs.dart';
import '../menu_bar.dart' show AppMenuBar;

/// One thing the palette can run.
class PaletteEntry {
  PaletteEntry({required this.label, this.path = '', this.shortcut = '', this.icon, this.keywords = '', this.checked, this.run});

  /// What the menu calls it.
  final String label;

  /// Where it lives ("File › Export drawing").
  final String path;

  /// Its key or typed command ("Ctrl+S", "L ⏎").
  final String shortcut;
  final IconData? icon;

  /// Searched but not shown: the English name, the typed aliases.
  final String keywords;

  /// A switch or a choice: whether it is on (null for an action).
  final bool? checked;

  /// Null when it cannot run now (nothing selected, no results…).
  final VoidCallback? run;

  bool get enabled => run != null;

  late final String _label = foldSearch(label);
  late final String _all = foldSearch('$label $path $shortcut $keywords');
  late final Set<String> _aliases = {
    for (final w in keywords.split(RegExp(r'[\s·,]+')))
      if (w.isNotEmpty) foldSearch(w),
  };
}

/// [s] in lower case without accents, for searching.
String foldSearch(String s) {
  const from = 'àáâãäåāăąçćčèéêëēėęìíîïīñńòóôõöøōùúûüūýÿ';
  const to = 'aaaaaaaaaccceeeeeeeiiiiinnooooooouuuuuyy';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The entries matching [query], best first: every word must appear; a
/// label that starts with the query, a typed alias equal to it and a word
/// of the label that starts with it come first; what cannot run now goes
/// last.
List<PaletteEntry> rankPalette(List<PaletteEntry> all, String query) {
  final q = foldSearch(query);
  if (q.isEmpty) return all;
  final words = q.split(' ');
  final scored = <(int, PaletteEntry)>[];
  for (final e in all) {
    if (!words.every(e._all.contains)) continue;
    var s = 0;
    if (e._aliases.contains(q)) s += 120;
    if (e._label.startsWith(q)) s += 100;
    if (e._label.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).any((w) => w.startsWith(words.first))) s += 40;
    if (e._label.contains(q)) s += 25;
    if (e.enabled) s += 10;
    scored.add((s, e));
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.label.length.compareTo(b.$2.label.length);
  });
  return [for (final x in scored) x.$2];
}

String _textOf(Widget? w) => w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : '';

/// The leaves of [menus] (submenus, actions, switches and choices), with the
/// path of the submenus they are in; the English label of each comes from
/// the string table ([englishOf]).
List<PaletteEntry> paletteFromMenus(List<Widget> menus, {String Function(String label)? englishOf}) {
  final out = <PaletteEntry>[];
  void add(String label, List<String> path, {String shortcut = '', IconData? icon, bool? checked, VoidCallback? run}) {
    final l = label.trim();
    if (l.isEmpty) return;
    out.add(PaletteEntry(label: l, path: path.join(' › '), shortcut: shortcut, icon: icon, checked: checked, keywords: englishOf?.call(l) ?? '', run: run));
  }

  void walk(List<Widget> items, List<String> path) {
    for (final w in items) {
      if (w is SubmenuButton) {
        final label = _textOf(w.child);
        // the "⋯" of the menus that do not fit is no step of a path
        walk(w.menuChildren, w.key == const Key('menu_more') || label.isEmpty || label == '⋯' ? path : [...path, label]);
      } else if (w is MenuItemButton) {
        final lead = w.leadingIcon;
        add(_textOf(w.child), path, shortcut: _textOf(w.trailingIcon), icon: lead is Icon ? lead.icon : null, run: w.onPressed);
      } else if (w is CheckboxMenuButton) {
        final v = w.value ?? false;
        final on = w.onChanged;
        add(_textOf(w.child), path, checked: v, run: on == null ? null : () => on(!v));
      } else if (w is RadioMenuButton) {
        // (read without the static type: onChanged takes the choice's own type)
        final dynamic d = w;
        final dynamic on = d.onChanged;
        final dynamic value = d.value;
        add(_textOf(w.child), path, checked: value == d.groupValue, run: on == null ? null : () => on(value));
      }
    }
  }

  walk(menus, const []);
  return out;
}

/// What the interface language calls each key, read back to the key: the
/// English label of a translated one (a menu item written with a shortcut
/// after it, "Grid  (F7)", is found as well).
String Function(String label) englishLabels(I18n t) {
  if (t.lang == 'en') return (_) => '';
  final back = <String, String>{};
  for (final k in I18n.keys) {
    back.putIfAbsent(t(k).trim().replaceFirst(RegExp(r'…$'), ''), () => k);
  }
  final en = I18n('en');
  return (label) {
    final bare = label.trim().replaceFirst(RegExp(r'\s+\([^)]*\)$'), '').replaceFirst(RegExp(r'…$'), '').trim();
    final k = back[bare];
    return k == null ? '' : en(k);
  };
}

/// Every entry of the palette: the menu bar's items (when it is on the
/// screen), the typed commands ([runAlias] types one as the keyboard would)
/// and the switches of the drawing and of the interface.
List<PaletteEntry> buildPaletteEntries(ProjectController c, {void Function(String alias)? runAlias}) {
  final t = c.t;
  final englishOf = englishLabels(t);
  final out = <PaletteEntry>[];
  final bar = AppMenuBar.barKey.currentWidget;
  if (bar is MenuBar) out.addAll(paletteFromMenus(bar.children, englishOf: englishOf));
  final settings = t('pal.settings');
  void refresh() => c.refresh();
  PaletteEntry toggle(String label, bool value, void Function(bool v) set, {IconData? icon, String shortcut = ''}) => PaletteEntry(
    label: label,
    path: settings,
    shortcut: shortcut,
    icon: icon,
    checked: value,
    keywords: englishOf(label),
    run: () {
      set(!value);
      refresh();
    },
  );
  final polar = c.snap.polarStepDeg;
  out.addAll([
    toggle(t('status.snap'), c.snap.enabled, (v) => c.snap.enabled = v, icon: Icons.my_location, shortcut: 'F3'),
    toggle(t('status.ortho'), c.snap.ortho, (v) => c.snap.ortho = v, icon: Icons.square_foot, shortcut: 'F8'),
    toggle(t('mob.gridSnap'), c.snap.grid, (v) => c.snap.grid = v, icon: Icons.grid_4x4),
    PaletteEntry(
      label: t('mob.polar', {'s': polar > 0 ? '${polar.round()}°' : t('mob.off')}),
      path: settings,
      icon: Icons.track_changes,
      keywords: 'polar ${englishOf(t('status.polar'))}',
      run: () {
        c.snap.nextPolarStep();
        c.track('polar');
        refresh();
      },
    ),
    toggle(t('status.keepLinks'), c.toolSettings.keepConnections, (v) => c.toolSettings.keepConnections = v, icon: Icons.link),
    PaletteEntry(
      label: t('uiv.larger'),
      path: '$settings › ${t('uiv.menu')}',
      icon: Icons.zoom_in,
      shortcut: _percent(nextUiScale(up: true)),
      keywords: '${t('uiv.scale')} ${englishOf(t('uiv.larger'))}',
      run: uiScale.value >= uiScales.last - 1e-6 ? null : () => setUiScale(nextUiScale(up: true)),
    ),
    PaletteEntry(
      label: t('uiv.smaller'),
      path: '$settings › ${t('uiv.menu')}',
      icon: Icons.zoom_out,
      shortcut: _percent(nextUiScale(up: false)),
      keywords: '${t('uiv.scale')} ${englishOf(t('uiv.smaller'))}',
      run: uiScale.value <= uiScales.first + 1e-6 ? null : () => setUiScale(nextUiScale(up: false)),
    ),
    toggle(t('uiv.contrast'), uiHighContrast.value, setHighContrast, icon: Icons.contrast),
    toggle(t('uiv.focus'), uiFocusMode.value, setFocusMode, icon: Icons.fullscreen, shortcut: 'Ctrl+Alt+F'),
    toggle(t('uiv.side'), uiSideFolded.value, setSideFolded, icon: Icons.view_sidebar_outlined),
  ]);
  // the typed commands: those whose target a menu or a switch above already
  // holds lend it their aliases (one Snap entry, which switches it at once)
  if (runAlias != null) {
    final byTarget = <Object, List<String>>{};
    for (final e in commandAliases.entries) {
      (byTarget[e.value] ??= []).add(e.key);
    }
    final byLabel = <String, int>{for (var i = 0; i < out.length; i++) foldSearch(out[i].label): i};
    for (final e in byTarget.entries) {
      final target = e.key;
      final label = target is ToolId ? t('tool.${target.name}') : t(actionLabelKey(target as CadAction));
      final aliases = e.value;
      final at = byLabel[foldSearch(label.replaceFirst(RegExp(r'…$'), ''))] ?? byLabel[foldSearch(label)];
      if (at != null) {
        final m = out[at];
        out[at] = PaletteEntry(label: m.label, path: m.path, shortcut: m.shortcut, icon: m.icon, checked: m.checked, run: m.run, keywords: '${m.keywords} ${aliases.join(' ')}');
        continue;
      }
      out.add(
        PaletteEntry(
          label: label,
          path: t('pal.commands'),
          shortcut: '${aliases.take(3).join(' · ')} ⏎',
          icon: target is ToolId ? Icons.edit_outlined : Icons.terminal,
          keywords: '${aliases.join(' ')} ${englishOf(label)}',
          run: () => runAlias(aliases.first),
        ),
      );
    }
  }
  return out;
}

String _percent(double s) => '${(s * 100).round()} %';

/// Opens the palette over the shell: [entries] (by default
/// [buildPaletteEntries] with [runAlias]); what is chosen runs once the
/// palette is closed, so the dialog it opens stands on its own.
Future<void> showCommandPalette(BuildContext context, ProjectController c, {List<PaletteEntry>? entries, void Function(String alias)? runAlias}) {
  c.track('palette');
  final all = entries ?? buildPaletteEntries(c, runAlias: runAlias);
  return showDialog<void>(
    context: context,
    builder: (_) => CommandPalette(c: c, entries: all),
  );
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.c, required this.entries});
  final ProjectController c;
  final List<PaletteEntry> entries;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final query = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  late List<PaletteEntry> shown = widget.entries;
  int index = 0;

  static const rowHeight = 44.0;

  @override
  void dispose() {
    query.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _search(String q) => setState(() {
    shown = rankPalette(widget.entries, q);
    index = 0;
    if (scroll.hasClients) scroll.jumpTo(0);
  });

  void _move(int by) {
    if (shown.isEmpty) return;
    setState(() => index = (index + by).clamp(0, shown.length - 1));
    if (!scroll.hasClients) return;
    final top = index * rowHeight, view = scroll.position.viewportDimension;
    if (top < scroll.offset) {
      scroll.jumpTo(top);
    } else if (top + rowHeight > scroll.offset + view) {
      scroll.jumpTo(top + rowHeight - view);
    }
  }

  void _run(PaletteEntry e) {
    final run = e.run;
    if (run == null) return;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero, run);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    final mq = MediaQuery.of(context);
    final width = (mq.size.width - 24).clamp(240.0, 640.0).toDouble();
    final room = mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - 96;
    final listHeight = room.clamp(rowHeight * 2, rowHeight * 10).toDouble();
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: mq.padding.top + 48),
        child: Material(
          key: const Key('palette'),
          color: Cad.dialog,
          elevation: 16,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Focus(
                    onKeyEvent: _key,
                    child: TextField(
                      key: const Key('palette_query'),
                      controller: query,
                      focusNode: focus,
                      autofocus: true,
                      decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: t('pal.hint')),
                      style: const TextStyle(fontSize: 13.5),
                      onChanged: _search,
                      onSubmitted: (_) {
                        if (shown.isNotEmpty) _run(shown[index.clamp(0, shown.length - 1)]);
                      },
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      t('pal.none', {'q': query.text.trim()}),
                      key: const Key('palette_none'),
                      style: TextStyle(color: Cad.fg60),
                    ),
                  )
                else
                  SizedBox(
                    height: (shown.length * rowHeight).clamp(rowHeight, listHeight).toDouble(),
                    child: ListView.builder(
                      key: const Key('palette_results'),
                      controller: scroll,
                      itemExtent: rowHeight,
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _row(t, shown[i], i, i == index),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(t('pal.keys'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(I18n t, PaletteEntry e, int i, bool on) {
    final state = e.checked == null ? '' : (e.checked! ? t('pal.on') : t('mob.off'));
    final sub = [if (e.path.isNotEmpty) e.path, if (!e.enabled) t('pal.unavailable')].join(' · ');
    return Semantics(
      button: true,
      enabled: e.enabled,
      selected: on,
      toggled: e.checked,
      child: InkWell(
        key: Key('palette_row_$i'),
        onTap: e.enabled ? () => _run(e) : null,
        child: Container(
          color: on ? Cad.accent.withValues(alpha: 0.16) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(e.checked == true ? Icons.check : (e.icon ?? Icons.chevron_right), size: 18, color: e.enabled ? Cad.fg70 : Cad.fg30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: e.enabled ? Cad.fg : Cad.fg38),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: Cad.fg54),
                      ),
                  ],
                ),
              ),
              if (state.isNotEmpty || e.shortcut.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text([if (state.isNotEmpty) state, if (e.shortcut.isNotEmpty) e.shortcut].join(' · '), style: TextStyle(fontSize: 11, color: Cad.accentText)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone's ☰ menu with a search at the top: while something is typed,
/// the rows of every section that match it, in one list (each with its
/// section under it); otherwise the sections themselves.
class PhoneMenuSearch extends StatefulWidget {
  const PhoneMenuSearch({super.key, required this.c, required this.children, this.padding});
  final ProjectController c;

  /// The rows of the menu: its sections ([ExpansionTile]s of [ListTile]s)
  /// and whatever else it shows.
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<PhoneMenuSearch> createState() => _PhoneMenuSearchState();
}

class _PhoneMenuSearchState extends State<PhoneMenuSearch> {
  final query = TextEditingController();

  /// The search was used (the tutorial's step about it watches the count).
  bool _used = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    final field = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        key: const Key('mobile_menu_search'),
        controller: query,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: t('pal.phone'),
          suffixIcon: query.text.isEmpty ? null : IconButton(tooltip: t('pal.clear'), icon: const Icon(Icons.close, size: 18), onPressed: () => setState(query.clear)),
        ),
        style: const TextStyle(fontSize: 13.5),
        onChanged: (v) => setState(() {
          if (v.trim().isEmpty || _used) return;
          _used = true;
          widget.c.track('palette');
        }),
      ),
    );
    final q = foldSearch(query.text);
    if (q.isEmpty) return ListView(padding: widget.padding, children: [field, ...widget.children]);
    final words = q.split(' ');
    final englishOf = englishLabels(t);
    final rows = <Widget>[];
    for (final w in widget.children) {
      if (w is! ExpansionTile) continue;
      final section = _textOf(w.title);
      for (final r in w.children) {
        if (r is! ListTile) continue;
        final title = _textOf(r.title);
        final hay = foldSearch('$title $section ${englishOf(title)}');
        if (!words.every(hay.contains)) continue;
        rows.add(
          ListTile(
            dense: true,
            leading: r.leading,
            title: r.title,
            subtitle: Text(section, style: TextStyle(fontSize: 11, color: Cad.fg54)),
            trailing: r.trailing,
            selected: r.selected,
            enabled: r.enabled,
            onTap: r.onTap,
          ),
        );
      }
    }
    // (the same list as without a search, the field first: it keeps the focus and the keyboard while typing)
    return ListView(
      padding: widget.padding,
      children: [
        field,
        const SizedBox(key: Key('mobile_menu_results')),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t('pal.none', {'q': query.text.trim()}), style: TextStyle(color: Cad.fg60)),
          ),
        ...rows,
      ],
    );
  }
}
