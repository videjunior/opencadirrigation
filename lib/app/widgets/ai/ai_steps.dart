/// The costs of an answer by step: each request (and each request a tool
/// made to a reading model of its own) with its tokens — read from the
/// cache, written to it, the input outside it, the output —, what the
/// request carried (its size, the pictures and the PDFs in it), the effort
/// and the cost, and what made a step dear: a cache that did not serve, a
/// change of model or effort, many pictures, a large request.
library;

import 'package:flutter/material.dart';

import '../../../core/ai/agent_loop.dart';
import '../../ai/ai_assistant.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';

/// A request this large (characters, about bytes) is pointed out.
const aiLargeRequest = 5000000;

/// Steps without the cache read from below this many input tokens are not
/// pointed out (the shortest prefixes are not cached at all).
const aiCacheFloor = 4096;

/// [n] tokens for the user (12 300 → "12,3k" in pt).
String _k(int n) => n < 1000 ? '$n' : '${fmtUi(n / 1000, n < 10000 ? 1 : 0)}k';

String _bytes(int b) => b < 1000000 ? '${fmtUi(b / 1000, 0)} KB' : '${fmtUi(b / 1000000, 1)} MB';

/// The model [id] as the user knows it.
String _model(String id) => AiModel.all.where((m) => m.id == id || id.startsWith('${m.id}-')).firstOrNull?.label ?? id;

/// One line of step [k] (0-based) of [steps].
String aiStepText(ProjectController c, List<AgentStep> steps, int k) {
  final t = c.t;
  final s = steps[k];
  final u = s.usage;
  // the step before of the main model (the reading model's are apart)
  AgentStep? before;
  for (var j = k - 1; j >= 0; j--) {
    if (!steps[j].subagent) {
      before = steps[j];
      break;
    }
  }
  final notes = <String>[
    if (s.failed) t('ai.steps.failed'),
    if (s.subagent) t('ai.steps.subagent'),
    if (s.compacted) t('ai.steps.compacted'),
    if (!s.subagent && !s.failed && before != null && u.cacheRead == 0 && u.totalInput >= aiCacheFloor) t('ai.steps.noCache'),
    if (!s.subagent && before != null && before.model != s.model) t('ai.steps.modelChange'),
    if (!s.subagent && before != null && before.effort != null && s.effort != null && before.effort != s.effort) t('ai.steps.effortChange', {'e': t('ai.effort.${s.effort!.name}')}),
    if (s.bytes >= aiLargeRequest) t('ai.steps.large'),
  ];
  return [
    '#${k + 1} ${_model(s.model)}',
    t('ai.steps.tokens', {'r': _k(u.cacheRead), 'w': _k(u.cacheWrite + u.cacheWriteHour), 'i': _k(u.input), 'o': _k(u.output)}),
    if (u.cacheWriteHour > 0) t('ai.steps.hour', {'n': _k(u.cacheWriteHour)}),
    if (s.images > 0) t('ai.pictures', {'n': '${s.images}'}),
    if (s.documents > 0) t('ai.steps.pdfs', {'n': '${s.documents}'}),
    if (s.bytes > 0) '≈ ${_bytes(s.bytes)}',
    if (s.effort != null) t('ai.effort.${s.effort!.name}'),
    'US\$ ${fmtUi(s.cost, s.cost < 0.01 ? 4 : 3)}',
    if (notes.isNotEmpty) '(${notes.join('; ')})',
  ].join(' · ');
}

/// The steps of the answer [it], folded under a line with their number and
/// the share of the input read from the cache.
class AiStepCosts extends StatefulWidget {
  const AiStepCosts({super.key, required this.c, required this.item});
  final ProjectController c;
  final AiItem item;

  @override
  State<AiStepCosts> createState() => _AiStepCostsState();
}

class _AiStepCostsState extends State<AiStepCosts> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    final steps = widget.item.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    var input = 0, read = 0;
    for (final s in steps) {
      input += s.usage.totalInput;
      read += s.usage.cacheRead;
    }
    final share = input == 0 ? 0.0 : 100 * read / input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('ai_steps_toggle'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
          onPressed: () => setState(() => open = !open),
          icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 15),
          label: Text(t('ai.steps.title', {'n': '${steps.length}', 'p': fmtUi(share, 0)}), style: const TextStyle(fontSize: 10.5)),
        ),
        if (open)
          Padding(
            key: const Key('ai_steps'),
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < steps.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      aiStepText(widget.c, steps, k),
                      style: TextStyle(fontSize: 10.5, color: steps[k].failed ? Cad.warning : Cad.fg60),
                    ),
                  ),
                Text(t('ai.steps.hint'), style: TextStyle(fontSize: 10, color: Cad.fg54)),
              ],
            ),
          ),
      ],
    );
  }
}
