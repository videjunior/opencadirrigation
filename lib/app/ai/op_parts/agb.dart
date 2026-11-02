/// Operations (find_operations / run_operation) added in 1.6.0 for machines, electrical and water (pump house and pivot electrics, traveller and furrows as design, several pivots, solar pumping, water quality and filtration, two-wire):
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../agent_tools.dart';

List<AgentTool> opsAgb(AgentToolbox b) => const [];
