/// Help → Manual (F1) and the "?" of the dialogs and panels: a short
/// explanation of each part of the program in the interface language, with
/// the full chapter of the manual (docs/manual in the repository, English
/// and Portuguese) one click away.
library;

import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../version.dart' show appRepositoryUrl;
import '../layout_mode.dart' show touchInput;

/// One subject of the manual: its text is `help.t.<id>` (title) and
/// `help.b.<id>` (body) in the string table.
class HelpTopic {
  const HelpTopic(this.id, this.chapter, {this.heading = '', this.headingPt = '', this.icon = Icons.help_outline, this.titleKeys = const []});
  final String id;

  /// The chapter of docs/manual (file name without `.md`).
  final String chapter;

  /// The section of the chapter: its heading in the English and in the
  /// Portuguese file ('' for the top of the chapter).
  final String heading, headingPt;
  final IconData icon;

  /// The i18n keys of the titles of the dialogs this subject explains: their
  /// "?" opens it.
  final List<String> titleKeys;
}

/// The subjects, in the order of a design.
const helpTopics = <HelpTopic>[
  HelpTopic('start', 'getting-started', icon: Icons.flag_outlined),
  HelpTopic('workflow', 'workflow', icon: Icons.route_outlined),
  HelpTopic('interface', 'interface', heading: 'Layout (wide screen)', headingPt: 'Layout (tela larga)', icon: Icons.dashboard_outlined, titleKeys: ['tools.units']),
  HelpTopic('shortcuts', 'interface', heading: 'Keyboard shortcuts', headingPt: 'Atalhos de teclado', icon: Icons.keyboard_outlined, titleKeys: ['sc.title']),
  HelpTopic('phone', 'interface', heading: 'Compact layout (phone and tablet)', headingPt: 'Layout compacto (celular e tablet)', icon: Icons.smartphone_outlined),
  HelpTopic(
    'drawing',
    'drawing',
    heading: 'Snaps',
    headingPt: 'Snaps',
    icon: Icons.draw_outlined,
    titleKeys: ['arr.title', 'lbl.title', 'tool.text', 'tool.leader', 'tool.comment', 'tool.revisionCloud'],
  ),
  HelpTopic('layers', 'drawing', heading: 'Layers', headingPt: 'Camadas', icon: Icons.layers_outlined),
  HelpTopic('history', 'drawing', heading: 'History', headingPt: 'Histórico', icon: Icons.history),
  HelpTopic('properties', 'hydraulic-network', heading: 'Hydraulic entities', headingPt: 'Entidades hidráulicas', icon: Icons.tune),
  HelpTopic(
    'network',
    'hydraulic-network',
    heading: 'Connection rules',
    headingPt: 'Regras de conexão',
    icon: Icons.account_tree_outlined,
    titleKeys: ['design.block', 'design.autohead', 'zone.deviceOnLaterals'],
  ),
  HelpTopic('auto', 'hydraulic-network', heading: 'Automatic design (Design → Automatic design)', headingPt: 'Projeto automático (Projeto → Projeto automático)', icon: Icons.auto_awesome_outlined),
  HelpTopic('catalog', 'catalogue', icon: Icons.inventory_2_outlined, titleKeys: ['design.catalog']),
  HelpTopic('terrain', 'terrain', icon: Icons.terrain_outlined, titleKeys: ['gimg.title']),
  HelpTopic(
    'params',
    'calculation',
    heading: 'Design parameters (Design → Design parameters)',
    headingPt: 'Parâmetros de projeto (Projeto → Parâmetros de projeto)',
    icon: Icons.tune_outlined,
    titleKeys: ['design.params'],
  ),
  HelpTopic('check', 'calculation', heading: 'Design check', headingPt: 'Verificação de projeto', icon: Icons.fact_check_outlined),
  HelpTopic('analyses', 'calculation', heading: 'Analyses of the mainline and of the operation', headingPt: 'Análises da linha principal e da operação', icon: Icons.waves_outlined),
  HelpTopic(
    'agronomy',
    'calculation',
    heading: 'Agronomy, mechanised machines and field calculators',
    headingPt: 'Agronomia, máquinas mecanizadas e calculadoras de campo',
    icon: Icons.eco_outlined,
    titleKeys: ['design.management', 'tools.lateral', 'tools.pump', 'tools.hammer'],
  ),
  HelpTopic('reports', 'reports-and-export', heading: 'Reports panel', headingPt: 'Painel de relatórios', icon: Icons.table_chart_outlined),
  HelpTopic('sheets', 'reports-and-export', heading: 'PDF sheets', headingPt: 'Pranchas em PDF', icon: Icons.print_outlined, titleKeys: ['plot.title', 'plot.pngTitle', 'file.details']),
  HelpTopic(
    'quote',
    'reports-and-export',
    heading: 'Commercial quote and alternatives',
    headingPt: 'Orçamento comercial e alternativas',
    icon: Icons.request_quote_outlined,
    titleKeys: ['design.proposal', 'design.scenarios'],
  ),
  HelpTopic('formats', 'file-formats', heading: 'Import', headingPt: 'Importação', icon: Icons.swap_horiz),
  HelpTopic('ai', 'ai-assistant', icon: Icons.smart_toy_outlined),
  HelpTopic('storage', 'privacy-and-network', icon: Icons.storage_outlined),
];

HelpTopic? helpTopicById(String id) => helpTopics.where((t) => t.id == id).firstOrNull;

/// The subject a dialog titled [title] is explained by (its title written in
/// the language of [t]), or null.
String? helpTopicForTitle(I18n t, String title) {
  String bare(String s) => s.trim().replaceFirst(RegExp(r'…$'), '').trim();
  final want = bare(title);
  if (want.isEmpty) return null;
  for (final topic in helpTopics) {
    for (final k in topic.titleKeys) {
      if (t.has(k) && bare(t(k)) == want) return topic.id;
    }
  }
  return null;
}

/// The anchor GitHub gives a Markdown heading: lower case, spaces as
/// hyphens, everything but letters, digits, `-` and `_` dropped.
String githubAnchor(String heading) {
  final b = StringBuffer();
  final keep = RegExp(r'[\p{L}\p{M}\p{N}_-]', unicode: true);
  for (final r in heading.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    if (ch == ' ') {
      b.write('-');
    } else if (keep.hasMatch(ch)) {
      b.write(ch);
    }
  }
  return b.toString();
}

/// Whether the manual has a chapter in [lang] (else the English one is
/// linked).
bool manualSpeaks(String lang) => lang == 'pt' || lang == 'en';

/// The address of the chapter (and section) of [topic] in the manual, in
/// Portuguese for a Portuguese interface, in English otherwise.
String helpChapterUrl(String lang, HelpTopic topic) {
  final pt = lang == 'pt';
  final heading = pt ? topic.headingPt : topic.heading;
  final anchor = heading.isEmpty ? '' : '#${githubAnchor(heading)}';
  return '$appRepositoryUrl/blob/main/docs/manual/${pt ? 'pt-BR/' : ''}${topic.chapter}.md$anchor';
}

/// The subject opened last in this session (F1 opens it again).
String _lastTopic = 'start';

/// Opens the manual at [topic] (the last one read when null).
Future<void> showHelpDialog(BuildContext context, ProjectController c, {String? topic}) {
  final id = helpTopicById(topic ?? _lastTopic)?.id ?? 'start';
  _lastTopic = id;
  c.track('help');
  return showDialog<void>(
    context: context,
    builder: (_) => HelpDialog(c: c, topic: id),
  );
}

class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key, required this.c, required this.topic});
  final ProjectController c;
  final String topic;

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  late String topic = widget.topic;
  final query = TextEditingController();

  ProjectController get c => widget.c;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  /// The subjects that match the search (title or text, in the interface
  /// language or in English).
  List<HelpTopic> get _shown {
    final q = _fold(query.text);
    if (q.isEmpty) return helpTopics;
    final en = I18n('en');
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final h in helpTopics)
        if (words.every(_fold('${c.t('help.t.${h.id}')} ${c.t('help.b.${h.id}')} ${en('help.t.${h.id}')} ${en('help.b.${h.id}')}').contains)) h,
    ];
  }

  void _pick(String id) {
    _lastTopic = id;
    setState(() => topic = id);
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 700;
    final inset = compact ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    final width = compact ? mq.size.width - inset.horizontal : (mq.size.width - inset.horizontal).clamp(280.0, 860.0).toDouble();
    final room = mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - inset.vertical;
    final height = (compact ? room : room.clamp(260.0, 620.0)).toDouble().clamp(200.0, 2000.0).toDouble();
    final shown = _shown;
    final current = helpTopicById(topic) ?? helpTopics.first;
    final search = TextField(
      key: const Key('help_search'),
      controller: query,
      decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: t('help.search')),
      style: const TextStyle(fontSize: 12.5),
      onChanged: (_) => setState(() {
        final s = _shown;
        if (s.isNotEmpty && !s.any((h) => h.id == topic)) topic = s.first.id;
      }),
    );
    final list = ListView(
      key: const Key('help_topics'),
      children: [
        for (final h in shown)
          ListTile(
            key: Key('help_topic_${h.id}'),
            dense: true,
            selected: h.id == current.id,
            leading: Icon(h.icon, size: 18),
            title: Text(t('help.t.${h.id}'), style: const TextStyle(fontSize: 12.5)),
            onTap: () => _pick(h.id),
          ),
      ],
    );
    final page = _TopicPage(c: c, topic: current);
    return Dialog(
      key: const Key('help_dialog'),
      insetPadding: inset,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 4),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 20, color: Cad.accentText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t('help.title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(key: const Key('help_close'), tooltip: t('close'), icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: search),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButton<String>(
                            key: const Key('help_topic_pick'),
                            isExpanded: true,
                            value: shown.any((h) => h.id == current.id) ? current.id : null,
                            items: [
                              for (final h in shown)
                                DropdownMenuItem(
                                  value: h.id,
                                  child: Text(t('help.t.${h.id}'), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) _pick(v);
                            },
                          ),
                        ),
                        Expanded(child: page),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 230,
                          child: Column(
                            children: [
                              Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), child: search),
                              Expanded(child: list),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: page),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The text of one subject and the link to its chapter.
class _TopicPage extends StatelessWidget {
  const _TopicPage({required this.c, required this.topic});
  final ProjectController c;
  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final url = helpChapterUrl(c.lang, topic);
    return SingleChildScrollView(
      key: ValueKey('help_page_${topic.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(topic.icon, size: 20, color: Cad.accentIcon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('help.t.${topic.id}'), key: const Key('help_page_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(t('help.b.${topic.id}'), key: const Key('help_page_body'), style: TextStyle(fontSize: 13, height: 1.5, color: Cad.bodyText)),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('help_chapter'),
              onPressed: () => openExternalLink(url),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(t('help.chapter')),
            ),
          ),
          if (!manualSpeaks(c.lang)) ...[
            const SizedBox(height: 6),
            Text(t('help.chapterLang'), style: TextStyle(fontSize: 11.5, color: Cad.fg54)),
          ],
        ],
      ),
    );
  }
}

/// The "?" of a dialog or panel: opens the manual at [topic].
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.c, required this.topic, this.panel = false});
  final ProjectController c;
  final String topic;

  /// A panel's button (its tooltip says "this panel").
  final bool panel;

  @override
  Widget build(BuildContext context) {
    final side = touchInput ? 48.0 : 32.0;
    return IconButton(
      key: Key('help_button_$topic'),
      tooltip: c.t(panel ? 'help.panelButton' : 'help.button'),
      constraints: BoxConstraints.tightFor(width: side, height: side),
      padding: EdgeInsets.zero,
      icon: Icon(Icons.help_outline, size: touchInput ? 22 : 17, color: Cad.fg60),
      onPressed: () => showHelpDialog(context, c, topic: topic),
    );
  }
}

/// The title of a dialog with its "?" when a subject of the manual explains
/// it ([topic], or the one found by the title).
Widget helpTitle(ProjectController c, String title, {TextStyle? style, String? topic}) {
  final id = topic ?? helpTopicForTitle(c.t, title);
  final text = Text(title, style: style);
  if (id == null) return text;
  return Row(
    children: [
      Expanded(child: text),
      HelpButton(c: c, topic: id),
    ],
  );
}

String _fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().trim();
}
