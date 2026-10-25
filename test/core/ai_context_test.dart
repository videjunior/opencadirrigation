import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/core/ai/project_context.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The project data the AI assistant may send: built from the reports and
/// the advisor (the same numbers), in the user's language, bounded,
/// deterministic, limited to the parts the user ticked — and never holding
/// the API key.
void main() {
  final t = I18n('pt');
  ReportLabels labels(Project p) => ReportLabels(
    t: t.call,
    has: t.has,
    warning: (w) => t.warning(w),
    entityName: (id) {
      final n = p.byId(id)?.name ?? '';
      return n.isEmpty ? id : n;
    },
  );

  ContextSource sourceOf(Project p, DesignResults? r, {List<String> selection = const []}) => ContextSource(
    project: p,
    labels: labels(p),
    results: r,
    tables: buildReportTables(project: p, results: r, labels: labels(p)),
    advice: buildAdvice(p, results: r),
    selection: selection,
    siteLatLon: (-22.912345, -47.061234),
  );

  late Project p;
  late DesignResults r;
  setUp(() {
    p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
    r = Designer(p, label: t.call).designAll();
  });

  test('the context carries the project, the results of the reports, the messages and the costs', () {
    final ctx = buildProjectContext(sourceOf(p, r));
    final text = ctx.text;
    expect(text, startsWith(t('ai.ctx.header')));
    expect(text, contains('## ${t('ai.ctx.project')}'));
    expect(text, contains(p.meta.name));
    // zones as the zones report shows them (names and the warning marks)
    final zones = buildReportTables(project: p, results: r, labels: labels(p)).firstWhere((x) => x.key == 'zones');
    expect(text, contains('### ${zones.title}'));
    for (final z in r.zones.values.take(3)) {
      expect(text, contains(z.zoneName));
    }
    expect(text, contains('## ${t('ai.ctx.messages')}'));
    expect(text, contains('## ${t('ai.ctx.materials')}'));
    expect(text, contains(r.capitalCost.toStringAsFixed(2)));
    expect(text, contains('## ${t('ai.ctx.parameters')}'));
    expect(text, contains(t('dlg.frictionFormula')));
    expect(text, contains('## ${t('ai.ctx.catalog')}'));
    // the site rounded to about a kilometre
    expect(text, contains('-22.91, -47.06'));
    expect(text.contains('-22.912345'), isFalse);
    expect(ctx.parts, containsAll([ContextPart.project, ContextPart.results, ContextPart.messages, ContextPart.materials, ContextPart.parameters, ContextPart.catalog]));
    expect(ctx.approxTokens, greaterThan(200));
  });

  test('without results the context says so and leaves the result parts out', () {
    final ctx = buildProjectContext(sourceOf(p, null));
    expect(ctx.text, contains(t('ai.ctx.notDesigned')));
    expect(ctx.parts.contains(ContextPart.results), isFalse);
    expect(ctx.parts.contains(ContextPart.materials), isFalse);
  });

  test('it is deterministic, bounded and limited to the parts asked for', () {
    final a = buildProjectContext(sourceOf(p, r)).text;
    final b = buildProjectContext(sourceOf(p, r)).text;
    expect(a, b, reason: 'the preview is exactly what is sent');
    final small = buildProjectContext(sourceOf(p, r), maxChars: 3000);
    expect(small.text.length, lessThanOrEqualTo(3000 + 400));
    expect(small.truncated, isTrue);
    final only = buildProjectContext(sourceOf(p, r), parts: {ContextPart.parameters});
    expect(only.parts, [ContextPart.parameters]);
    expect(only.text.contains('## ${t('ai.ctx.messages')}'), isFalse);
    expect(only.text.contains(p.meta.name), isFalse);
    expect(buildProjectContext(sourceOf(p, r), parts: const {}).isEmpty, isTrue);
  });

  test('selected items come with their properties and the report rows that name them', () {
    final valve = p.entities.whereType<ControlValveEntity>().first;
    final ctx = buildProjectContext(sourceOf(p, r, selection: [valve.id]), parts: {ContextPart.selection});
    expect(ctx.text, contains(t('ai.ctx.selection', {'n': '1'})));
    expect(ctx.text, contains('id ${valve.id}'));
    expect(ctx.text, contains(t('ai.ctx.props')));
    expect(ctx.text, contains(valve.zoneName));
  });

  test('the API key never appears in the context or in the project file', () {
    const key = 'sk-ant-api03-NEVER-IN-PROJECT-0000';
    setPref('ai.key', key);
    addTearDown(() => removePref('ai.key'));
    final ctx = buildProjectContext(sourceOf(p, r));
    expect(ctx.text.contains(key), isFalse);
    expect(p.toJsonString().contains(key), isFalse);
    expect(p.toJsonString().contains('sk-ant'), isFalse);
  });

  test('the token estimate grows with the text and counts other scripts more densely', () {
    expect(estimateTokens(''), 0);
    expect(estimateTokens('a' * 400), 100);
    expect(estimateTokens('灌溉' * 100), greaterThan(estimateTokens('ab' * 100)));
  });
}
