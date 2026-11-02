/// Operations (find_operations / run_operation) added in 1.6.0 for the interface:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import 'dart:async';

import '../../../core/ai/agent_loop.dart';
import '../../i18n.dart';
import '../../io/app_keys.dart' show appNavigatorKey;
import '../../ui_prefs.dart';
import '../../version.dart' show appVersionLabel;
import '../../widgets/dialogs/feedback_dialog.dart';
import '../../widgets/dialogs/help_dialog.dart';
import '../../widgets/dialogs/whats_new_dialog.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;

List<AgentTool> opsUi(AgentToolbox b) {
  final en = I18n('en');
  String state() =>
      'Interface: size ${uiScale.value} (${(uiScale.value * 100).round()} %), high contrast ${uiHighContrast.value ? 'on' : 'off'}, focus mode ${uiFocusMode.value ? 'on' : 'off'}, side panel ${uiSideFolded.value ? 'folded away' : 'docked, ${uiSideWidth.value.round()} px wide'}.';
  return [
    cadOp(
      b,
      group: 'view',
      name: 'interface_settings',
      description: 'View → Interface: ui_scale, the size of the whole interface (0.75–2, 1 = as designed; the menu offers 0.85, 1, 1.15, 1.3 and 1.5), independent of the browser zoom; high_contrast (stronger text, borders and accents in the dark and the light theme); focus_mode (menus, tabs, tool palette, panels and status bar hidden: the drawing board alone, Ctrl+Alt+F leaves it); side_panel_folded (the Properties / Layers / History panel folded into a strip). Options of this browser, not of the project, and not undone with undo. With no input: the current values.',
      schema: obj({
        'ui_scale': num_('Size of the interface, 0.75–2 (1 = as designed).'),
        'high_contrast': bool_('The high-contrast palette.'),
        'focus_mode': bool_('Focus mode: the drawing board alone.'),
        'side_panel_folded': bool_('The side panel folded away.'),
      }),
      effectFor: (i) => i.isEmpty ? ToolEffect.read : ToolEffect.write,
      args: (i) => {
        'n': [for (final e in i.entries) '${e.key} ${e.value}'].join(', '),
      },
      run: (a, i) async {
        if (a.has('ui_scale')) setUiScale(a.number('ui_scale', min: uiScaleMin, max: uiScaleMax, required: true)!);
        if (a.flag('high_contrast') case final v?) setHighContrast(v);
        if (a.flag('focus_mode') case final v?) setFocusMode(v);
        if (a.flag('side_panel_folded') case final v?) setSideFolded(v);
        return ToolOutput(state());
      },
    ),
    cadOp(
      b,
      group: 'help',
      name: 'manual_topic',
      description: 'The manual of the program as the user reads it (Help → Manual, F1; the "?" of the dialogs and panels): with no topic, its topics (id — title); with a topic, its text (in English) and the address of the full chapter in docs/manual. show true also opens it on the user\'s screen at that topic, when the user asks where something is explained.',
      schema: obj({
        'topic': str('Topic id (no input lists them).', [for (final h in helpTopics) h.id]),
        'show': bool_('Open it on the user\'s screen too.'),
      }),
      args: (i) => {'n': '${i['topic'] ?? ''}'},
      run: (a, i) async {
        final id = a.str('topic');
        if (id == null) return ToolOutput([for (final h in helpTopics) '${h.id} — ${en('help.t.${h.id}')}'].join('\n'));
        final h = helpTopicById(id);
        if (h == null) throw ToolInputError('No topic "$id"; the topics are ${helpTopics.map((h) => h.id).join(', ')}.');
        if (a.flag('show') ?? false) {
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null) unawaited(showHelpDialog(ctx, b.c, topic: h.id));
        }
        return ToolOutput('${en('help.t.${h.id}')}\n${en('help.b.${h.id}')}\nFull chapter: ${helpChapterUrl('en', h)}');
      },
    ),
    cadOp(
      b,
      group: 'help',
      name: 'whats_new',
      description: 'Help → What\'s new: the highlights of this version of the program (in English) and the address of the full history of changes, for when the user asks what is new or what changed.',
      schema: obj({}),
      run: (a, i) async {
        final v = whatsNewVersion;
        return ToolOutput('Version $v (this build: $appVersionLabel):\n${[for (final k in whatsNewKeys(v)) '- ${en(k)}'].join('\n')}\nFull history: ${changelogUrl('en')}');
      },
    ),
    cadOp(
      b,
      group: 'help',
      name: 'prepare_feedback',
      effect: ToolEffect.write,
      description: 'Help → Report a problem or suggest a feature: opens the report form on the user\'s screen filled in with kind ("problem", the default, or "idea"), title and details, and the diagnostics (version, language, browser, screen, size of the project; no personal data, never the project itself). Nothing is sent: the user reviews it and opens the GitHub issue form from it, or copies the text. For when the user wants to report a problem of the program or ask the project for a function.',
      schema: obj(
        {
          'kind': str('problem (default) or idea.', ['problem', 'idea']),
          'title': str('A short title.'),
          'details': str('What happened and what was expected, or what is needed and how it is done today.'),
        },
        required: ['title'],
      ),
      args: (i) => {'n': '${i['title'] ?? ''}'},
      run: (a, i) async {
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null) throw ToolInputError('The report form cannot be opened here: tell the user to use Help → Report a problem or suggest a feature.');
        final kind = a.str('kind') == 'idea' ? FeedbackKind.idea : FeedbackKind.problem;
        unawaited(showFeedbackDialog(ctx, b.c, kind: kind, title: a.str('title', required: true)!, details: a.str('details') ?? ''));
        return ToolOutput('The report form is open on the user\'s screen, filled in; the user reviews it and sends it (nothing was sent).');
      },
    ),
  ];
}
