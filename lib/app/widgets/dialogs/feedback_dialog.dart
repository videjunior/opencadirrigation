/// Help → Report a problem or suggest a feature (PRD-25): the project has
/// no server and no account, so the report is a GitHub issue the user
/// reviews and sends from the browser (the form opened filled in), or text
/// to copy anywhere. It carries diagnostics without personal data: the
/// version, the language, the browser, the screen and the size of the
/// project — never its name, place, contents or any key; the project file
/// goes only if the user saves it and attaches it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../actions.dart' show saveProjectAction;
import '../../i18n.dart';
import '../../io/client_info.dart';
import '../../io/links.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../ui_prefs.dart';
import '../../version.dart';
import '../fields.dart' show ScrollBody;
import '../layout_mode.dart';
import 'terrain_dialogs.dart' show dialogWidth;

enum FeedbackKind { problem, idea }

/// "Chrome 131 · macOS" from a browser's user agent; '' when it names
/// nothing known.
String describeClient(String ua) {
  String? ver(String name) => RegExp('$name/(\\d+)').firstMatch(ua)?.group(1);
  final browser = switch (ua) {
    _ when ua.contains('Edg/') => 'Edge ${ver('Edg') ?? ''}',
    _ when ua.contains('OPR/') => 'Opera ${ver('OPR') ?? ''}',
    _ when ua.contains('SamsungBrowser/') => 'Samsung Internet ${ver('SamsungBrowser') ?? ''}',
    _ when ua.contains('FxiOS/') => 'Firefox ${ver('FxiOS') ?? ''}',
    _ when ua.contains('Firefox/') => 'Firefox ${ver('Firefox') ?? ''}',
    _ when ua.contains('CriOS/') => 'Chrome ${ver('CriOS') ?? ''}',
    _ when ua.contains('Chrome/') => 'Chrome ${ver('Chrome') ?? ''}',
    _ when ua.contains('Safari/') && ua.contains('Version/') => 'Safari ${ver('Version') ?? ''}',
    _ => '',
  }.trim();
  final system = switch (ua) {
    _ when ua.contains('iPhone') || ua.contains('iPad') => 'iOS',
    _ when ua.contains('Android') => 'Android',
    _ when ua.contains('Windows') => 'Windows',
    _ when ua.contains('CrOS') => 'ChromeOS',
    _ when ua.contains('Mac OS X') || ua.contains('Macintosh') => 'macOS',
    _ when ua.contains('Linux') => 'Linux',
    _ => '',
  };
  return [browser, system].where((s) => s.isNotEmpty).join(' · ');
}

/// The diagnostics of a report, in English (for the developer): nothing of
/// the user or of what the project holds beyond its size.
List<String> feedbackDiagnostics(ProjectController c, {String userAgent = '', Size? screen, double? pixelRatio, String layout = ''}) {
  final client = describeClient(userAgent);
  final u = c.units;
  return [
    '$appName $appVersionLabel',
    'Language: ${c.lang}',
    if (client.isNotEmpty) 'Browser: $client',
    if (screen != null) 'Screen: ${screen.width.round()} × ${screen.height.round()}${pixelRatio == null ? '' : ' at ×${(pixelRatio * 100).round() / 100}'}${layout.isEmpty ? '' : ', $layout layout'}',
    'Interface: ${Cad.isLight ? 'light' : 'dark'} theme, size ${(uiScale.value * 100).round()} %${uiHighContrast.value ? ', high contrast' : ''}',
    'Units: ${u.length.name}, ${u.flow.name}, ${u.pressure.name}, ${u.diameter.name}',
    'Project: ${c.project.entities.length} items, ${c.results == null ? 'not designed' : 'designed'}${c.project.meta.georef == null ? '' : ', georeferenced'}',
  ];
}

/// The text of the issue: what the user wrote under headings of their
/// language, then the diagnostics.
String feedbackBody(I18n t, FeedbackKind kind, {required String details, String steps = '', required List<String> diagnostics}) {
  final b = StringBuffer()
    ..writeln('### ${t(kind == FeedbackKind.problem ? 'fb.h.what' : 'fb.h.need')}')
    ..writeln(details.trim().isEmpty ? '…' : details.trim());
  if (kind == FeedbackKind.problem) {
    b
      ..writeln()
      ..writeln('### ${t('fb.h.steps')}')
      ..writeln(steps.trim().isEmpty ? '1. …' : steps.trim());
  }
  b
    ..writeln()
    ..writeln('### ${t('fb.h.diag')}');
  for (final d in diagnostics) {
    b.writeln('- $d');
  }
  return b.toString();
}

/// Longest body (encoded) that goes in the address of the issue form:
/// GitHub refuses addresses much over 8 KB.
const feedbackMaxEncodedBody = 6000;

/// The address of the GitHub form of a new issue with [title] and [body],
/// and whether the body had to be cut to fit it.
(String, bool) feedbackIssueUrl(FeedbackKind kind, String title, String body) {
  var text = body;
  var cut = false;
  if (Uri.encodeComponent(text).length > feedbackMaxEncodedBody) {
    cut = true;
    var lo = 0, hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (Uri.encodeComponent(text.substring(0, mid)).length <= feedbackMaxEncodedBody - 40) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    text = '${text.substring(0, lo)}\n…';
  }
  final problem = kind == FeedbackKind.problem;
  final uri = Uri.parse('$appRepositoryUrl/issues/new').replace(
    queryParameters: {'template': problem ? 'bug_report.md' : 'feature_request.md', 'labels': problem ? 'bug' : 'enhancement', 'title': title.trim(), 'body': text},
  );
  return (uri.toString(), cut);
}

/// Opens the report; [kind], [title] and [details] fill it in (the AI
/// assistant prepares one this way: the user still reviews and sends it).
Future<void> showFeedbackDialog(BuildContext context, ProjectController c, {FeedbackKind kind = FeedbackKind.problem, String title = '', String details = ''}) => showDialog<void>(
  context: context,
  builder: (_) => _FeedbackDialog(c: c, kind: kind, title: title, details: details),
);

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.c, required this.kind, required this.title, required this.details});
  final ProjectController c;
  final FeedbackKind kind;
  final String title, details;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late FeedbackKind kind = widget.kind;
  late final title = TextEditingController(text: widget.title);
  late final details = TextEditingController(text: widget.details);
  final steps = TextEditingController();
  bool needTitle = false;

  ProjectController get c => widget.c;

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    steps.dispose();
    super.dispose();
  }

  List<String> _diagnostics(BuildContext context) {
    final mq = MediaQuery.of(context);
    return feedbackDiagnostics(c, userAgent: clientUserAgent, screen: mq.size, pixelRatio: mq.devicePixelRatio, layout: shellLayoutOf(context).name);
  }

  String _body(BuildContext context) => feedbackBody(c.t, kind, details: details.text, steps: steps.text, diagnostics: _diagnostics(context));

  String _text(BuildContext context) => '${title.text.trim()}\n\n${_body(context)}';

  Future<void> _copy(BuildContext context, {bool notify = true}) async {
    await Clipboard.setData(ClipboardData(text: _text(context)));
    if (notify) c.notify(c.t('fb.copied'));
  }

  Future<void> _github(BuildContext context) async {
    if (title.text.trim().isEmpty) {
      setState(() => needTitle = true);
      return;
    }
    final (url, cut) = feedbackIssueUrl(kind, title.text, _body(context));
    if (cut) {
      await _copy(context, notify: false);
      c.notify(c.t('fb.long'));
    }
    openExternalLink(url);
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final diag = _diagnostics(context);
    InputDecoration box(String label) => InputDecoration(labelText: label, isDense: true, alignLabelWithHint: true);
    return AlertDialog(
      key: const Key('feedback'),
      title: Text(t('fb.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(context, 560),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('fb.intro'), style: TextStyle(fontSize: 12, color: Cad.fg70, height: 1.4)),
              const SizedBox(height: 10),
              // (chips that wrap on a narrow phone or with a large text)
              Wrap(
                key: const Key('feedback_kind'),
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (k, icon, label) in [(FeedbackKind.problem, Icons.bug_report_outlined, 'fb.problem'), (FeedbackKind.idea, Icons.lightbulb_outline, 'fb.idea')])
                    ChoiceChip(
                      key: Key('feedback_kind_${k.name}'),
                      avatar: Icon(icon, size: 16),
                      label: Text(t(label)),
                      selected: kind == k,
                      onSelected: (_) => setState(() => kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('feedback_title'),
                controller: title,
                decoration: box(t('fb.summary')).copyWith(errorText: needTitle && title.text.trim().isEmpty ? t('fb.needTitle') : null),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('feedback_details'),
                controller: details,
                minLines: 3,
                maxLines: 8,
                decoration: box(t(kind == FeedbackKind.problem ? 'fb.what' : 'fb.need')),
              ),
              if (kind == FeedbackKind.problem) ...[
                const SizedBox(height: 8),
                TextField(key: const Key('feedback_steps'), controller: steps, minLines: 2, maxLines: 6, decoration: box(t('fb.steps'))),
              ],
              const SizedBox(height: 12),
              Text(t('fb.diag'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                key: const Key('feedback_diag'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Cad.inset, borderRadius: BorderRadius.circular(6)),
                child: SelectableText(diag.join('\n'), style: TextStyle(fontSize: 11.5, height: 1.4, fontFamily: 'monospace', color: Cad.codeText)),
              ),
              const SizedBox(height: 4),
              Text(t('fb.diagNote'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('feedback_save'),
          onPressed: () => saveProjectAction(context, c),
          icon: const Icon(Icons.save_outlined, size: 16),
          label: Text(t('fb.saveProject')),
        ),
        TextButton.icon(key: const Key('feedback_copy'), onPressed: () => _copy(context), icon: const Icon(Icons.copy, size: 16), label: Text(t('fb.copy'))),
        TextButton(key: const Key('feedback_close'), onPressed: () => Navigator.pop(context), child: Text(t('close'))),
        Tooltip(
          message: t('fb.githubTip'),
          child: FilledButton.icon(key: const Key('feedback_github'), onPressed: () => _github(context), icon: const Icon(Icons.open_in_new, size: 16), label: Text(t('fb.github'))),
        ),
      ],
    );
  }
}
