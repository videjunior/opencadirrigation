/// The tools that make the assistant an agent rather than a chat: its to-do
/// list, questions to the user (the run waits for the answers), the plan
/// the user approves before any change in plan mode, the project's AI notes
/// (requirements and decisions kept between conversations), the design
/// playbooks and the example projects as references.
///
/// They reach the assistant around them through [AgentHost], so the cards,
/// the waiting and the storage live in the app; the tools only check inputs
/// and word what goes back to the model.
library;

import 'dart:typed_data';

import '../../core/ai/agent_loop.dart';
import '../../core/ai/project_context.dart';
import '../../core/io/project_export.dart';
import '../../core/model/project.dart';
import '../examples.dart';
import 'agent_tools.dart';
import 'playbooks.dart';

enum TodoStatus { pending, inProgress, done }

/// One item of the to-do list the model keeps.
class AiTodo {
  const AiTodo(this.content, this.status);
  final String content;
  final TodoStatus status;
}

class AiOption {
  const AiOption(this.label, [this.description = '']);
  final String label;
  final String description;
}

/// A question of `ask_user`: 2–4 options, and the user may always type an
/// answer of their own.
class AiQuestion {
  const AiQuestion({required this.question, required this.options, this.header = '', this.multi = false});
  final String question;
  final String header;
  final List<AiOption> options;

  /// Several options may be chosen.
  final bool multi;
}

/// The user's decision on a plan.
class PlanDecision {
  const PlanDecision.approved(AgentPermission this.mode) : feedback = '';
  const PlanDecision.revise(this.feedback) : mode = null;

  /// How changes apply once the plan is approved.
  final AgentPermission? mode;

  /// What the user wants changed in the plan.
  final String feedback;
  bool get approved => mode != null;
}

/// What the agent tools need from the assistant around them.
abstract class AgentHost {
  /// The mode changes follow now.
  AgentPermission get permission;

  /// The user stopped the assistant.
  bool get stopped;

  void setTodos(List<AiTodo> items);

  /// Shows [questions] and waits: the answers, one per question (empty when
  /// the user skipped them), or null when the user stopped the assistant.
  Future<List<String>?> ask(List<AiQuestion> questions);

  /// Shows [plan] for approval and waits; null when the user stopped.
  Future<PlanDecision?> reviewPlan(String plan);

  /// The project's AI notes.
  String get notes;
  void setNotes(String text);

  /// The user's standing instructions (from the settings).
  String get instructions;

  /// The files attached in this conversation, by name.
  Map<String, Uint8List> get files;

  /// Opens [p] in a new tab, in the background: the tab on screen and the
  /// assistant's own project stay; false where tabs are not available.
  bool openTab(Project p);
}

/// Longest notes kept.
const maxNotesChars = 8000;

List<AgentTool> agentTools(AgentToolbox b, AgentHost host) {
  final t = b.t;
  final c = b.c;
  final ids = [for (final p in playbooks) p.id];
  final exampleIds = [for (final e in ExampleId.values) e.name];
  ExampleId exampleOf(String? id) =>
      ExampleId.values.where((e) => e.name.toLowerCase() == (id ?? '').toLowerCase()).firstOrNull ?? (throw ToolInputError('Unknown example "$id". One of: ${exampleIds.join(', ')}.'));
  String? playbookOfExample(ExampleId id) => playbooks.where((p) => p.examples.contains(id)).firstOrNull?.id;
  return [
    FnTool(
      name: 'update_todo',
      description: 'Replaces your to-do list for the task; the user sees it above the conversation. Use it for any task of three or more steps: list the steps, keep exactly one in_progress while you work, mark each done as soon as it is, add the steps you discover. Items short (under 80 characters), in the user\'s language.',
      inputSchema: obj(
        {
          'items': arr(
            obj(
              {
                'content': str(),
                'status': str(null, ['pending', 'in_progress', 'done']),
              },
              required: ['content', 'status'],
            ),
            null,
            30,
          ),
        },
        required: ['items'],
      ),
      summary: (i) => t('ai.tool.todo'),
      handler: (i) async {
        final list = [
          for (final x in (i['items'] as List).cast<Map>())
            AiTodo(AgentToolbox.short('${x['content']}', 120), switch (x['status']) {
              'done' => TodoStatus.done,
              'in_progress' => TodoStatus.inProgress,
              _ => TodoStatus.pending,
            }),
        ];
        host.setTodos(list);
        final done = list.where((x) => x.status == TodoStatus.done).length;
        return ToolOutput('To-do list updated: $done of ${list.length} done.');
      },
    ),
    FnTool(
      name: 'ask_user',
      description: 'Asks the user one to four questions at once and waits for the answers. Each question has 2–4 options (short labels, an optional one-line description); the user can always type an answer of their own instead. Use it when the design depends on facts the project does not hold: crop and spacing, soil, the water source (available flow and pressure, or the water level), power, operating hours, budget, a preferred brand. Ask everything you need in one call, early.',
      inputSchema: obj(
        {
          'questions': arr(
            obj(
              {
                'question': str('The whole question, in the user\'s language.'),
                'header': str('A label of one to three words, e.g. "Soil".'),
                'options': {
                  ...arr(obj({'label': str(), 'description': str()}, required: ['label']), 'Two to four choices.', 4),
                  'minItems': 2,
                },
                'multi': bool_('Several options may be chosen.'),
              },
              required: ['question', 'options'],
            ),
            null,
            4,
          ),
        },
        required: ['questions'],
      ),
      summary: (i) => t('ai.tool.ask', {'n': '${(i['questions'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        final qs = [
          for (final q in (i['questions'] as List).cast<Map>())
            AiQuestion(
              question: '${q['question']}'.trim(),
              header: '${q['header'] ?? ''}'.trim(),
              multi: q['multi'] == true,
              options: [for (final o in (q['options'] as List).cast<Map>()) AiOption('${o['label']}'.trim(), '${o['description'] ?? ''}'.trim())],
            ),
        ];
        if (qs.isEmpty) throw ToolInputError('Ask at least one question.');
        final answers = await host.ask(qs);
        if (answers == null) return ToolOutput.error('Not answered: the user stopped the assistant.');
        if (answers.every((a) => a.trim().isEmpty)) return const ToolOutput('The user skipped the questions. Go on with sensible assumptions, say which, and record them with update_notes.');
        return ToolOutput([for (var k = 0; k < qs.length; k++) '${qs[k].question} → ${k < answers.length && answers[k].trim().isNotEmpty ? answers[k].trim() : '(no answer)'}'].join('\n'));
      },
    ),
    FnTool(
      name: 'present_plan',
      description: 'Shows your plan to the user for approval: what you will draw and change, the main choices and values, your assumptions, what you will check. In plan mode no change is allowed until the user approves it. The answer says whether they approved it (and how changes then apply) or what they want changed.',
      inputSchema: obj({'plan': str('The plan in Markdown, in the user\'s language: short headings and lists.')}, required: ['plan']),
      summary: (i) => t('ai.tool.plan'),
      handler: (i) async {
        final plan = ToolArgs(i).str('plan', required: true)!;
        final d = await host.reviewPlan(plan);
        if (d == null) return ToolOutput.error('Not answered: the user stopped the assistant.');
        if (!d.approved) {
          return ToolOutput('The user did not approve the plan yet and asks for changes: ${d.feedback.trim().isEmpty ? '(no details)' : d.feedback.trim()}\nRevise the plan and present it again.');
        }
        return ToolOutput(
          'The user approved the plan. Changes now ${d.mode == AgentPermission.auto ? 'apply automatically (exports and large deletions are still confirmed)' : 'need the user\'s approval one by one'}. Carry it out step by step and keep the to-do list current.',
        );
      },
    ),
    FnTool(
      name: 'get_notes',
      description: 'Reads the project\'s AI notes (the designer\'s preferences, the client\'s requirements, decisions taken in earlier conversations) and the user\'s standing instructions. Read them at the start of a task.',
      inputSchema: obj({}),
      summary: (i) => t('ai.tool.notes'),
      handler: (i) async {
        final notes = host.notes.trim(), ins = host.instructions.trim();
        return ToolOutput('Project notes:\n${notes.isEmpty ? '(none yet)' : notes}\n\nThe user\'s standing instructions:\n${ins.isEmpty ? '(none)' : ins}');
      },
    ),
    FnTool(
      name: 'update_notes',
      description: 'Writes the project\'s AI notes: requirements, the user\'s answers, assumptions and decisions worth keeping for later conversations (short and factual, a line each, in the user\'s language). The user can read and edit them in the settings. "append" adds lines; "replace" rewrites them all (keep what still holds).',
      inputSchema: obj(
        {
          'text': str(),
          'mode': str('Default "append".', ['append', 'replace']),
        },
        required: ['text'],
      ),
      summary: (i) => t('ai.tool.notesUpdate'),
      handler: (i) async {
        final a = ToolArgs(i);
        final text = a.str('text', required: true)!;
        final now = (a.str('mode') ?? 'append') == 'replace' ? text : [host.notes.trim(), text].where((s) => s.isNotEmpty).join('\n');
        if (now.length > maxNotesChars) throw ToolInputError('The notes would be ${now.length} characters; keep them under $maxNotesChars (replace them with a shorter version).');
        host.setNotes(now);
        return ToolOutput('Notes saved (${now.length} characters).');
      },
    ),
    FnTool(
      name: 'get_playbook',
      description: 'Reads the step-by-step workflow for one kind of project, written from how the program\'s examples are built: what to ask, the tools to use in order, typical values and checks. Read it before designing a new project of that kind.',
      inputSchema: obj({'id': str(null, ids)}, required: ['id']),
      summary: (i) => t('ai.tool.playbook', {'n': '${i['id']}'}),
      handler: (i) async {
        final p = playbookById(ToolArgs(i).str('id', required: true)!);
        if (p == null) throw ToolInputError('Unknown playbook. One of: ${ids.join(', ')}.');
        return ToolOutput('# ${p.title}\nExamples built this way: ${p.examples.map((e) => e.name).join(', ')}.\n\n${p.steps}');
      },
    ),
    FnTool(
      name: 'list_examples',
      description: 'Lists the example projects that come with the program (ids, titles, the playbook each follows).',
      inputSchema: obj({}),
      summary: (i) => t('ai.tool.examples'),
      handler: (i) async => ToolOutput(
        [for (final e in exampleGallery) '${e.id.name} | ${t(e.titleKey)} | ${t(e.subtitleKey)}${playbookOfExample(e.id) == null ? '' : ' | playbook ${playbookOfExample(e.id)}'}'].join('\n'),
      ),
    ),
    FnTool(
      name: 'read_example',
      description: 'Reads how an example project is built, without opening it: its items by kind (with ids, names and layers), system flows, design parameters and the catalogue items it uses. Use it as a reference for values and arrangement; the open project is not touched.',
      inputSchema: obj({'id': str(null, exampleIds), 'items': int_('Item lines to list (default 120, at most 400).')}, required: ['id']),
      summary: (i) => t('ai.tool.readExample', {'n': '${i['id']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final id = exampleOf(a.str('id', required: true));
        final p = buildExample(id, t.call, lang: c.lang);
        final labels = c.exporter().labels;
        final ctx = buildProjectContext(
          ContextSource(
            project: p,
            labels: labels,
            tables: ProjectExporter(project: p, labels: labels).reportTables(),
          ),
          parts: const {ContextPart.project, ContextPart.parameters, ContextPart.catalog},
          maxChars: 12000,
        );
        final max = a.integer('items', min: 1, max: 400) ?? 120;
        final lines = [for (final e in p.entities.take(max)) '${e.id} | ${e.type.name} | ${e.name.isEmpty ? '-' : e.name} | ${e.layer} | ${AgentToolbox.box(e.bounds)}'];
        final more = p.entities.length - lines.length;
        return ToolOutput(
          'Example "${id.name}" (${t('exg.${id.name}.title')}), playbook ${playbookOfExample(id) ?? '-'}.\n${ctx.text}\n\nItems (id | kind | name | layer | bbox [minX, minY, maxX, maxY]):\n${lines.join('\n')}${more > 0 ? '\n… $more more' : ''}',
        );
      },
    ),
    FnTool(
      name: 'open_example',
      description: 'Opens an example project in a new tab in the background for the user to look at: the screen and you stay on your own project (read_example gives you its contents).',
      inputSchema: obj({'id': str(null, exampleIds)}, required: ['id']),
      summary: (i) => t('ai.tool.openExample', {'n': '${i['id']}'}),
      handler: (i) async {
        final id = exampleOf(ToolArgs(i).str('id', required: true));
        if (!host.openTab(buildExample(id, t.call, lang: c.lang))) {
          return ToolOutput.error('Tabs cannot be opened from here; tell the user to open it from File → Examples, or use read_example.');
        }
        return ToolOutput(
          'Opened "${t('exg.${id.name}.title')}" in a new tab in the background: the screen and you stay on your own project. The user switches to that tab to look at it (tell them so); read_example gives you its contents.',
        );
      },
    ),
  ];
}
