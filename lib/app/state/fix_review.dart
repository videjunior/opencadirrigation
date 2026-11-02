/// 1.6.0 AUT: the review item by item of "fix automatically" and of
/// "optimise". Both run as before (every correction or change made, one
/// undo step) and then list what they did, each with a box: the user leaves
/// out the ones they do not want. Keeping only some puts the project back
/// as it was before and makes just those again — the corrections in rounds
/// with the design between them, so a correction that only comes up after
/// another one left out does not happen; the changes of the optimisation as
/// they were (the same valves, the pump chosen for the same duties) and one
/// design — still one undo step.
library;

import '../../core/design/auto_fix.dart';
import 'controller.dart';

extension FixReview on ProjectController {
  /// Keeps of "fix automatically" (whose [report] is the last thing done)
  /// only the corrections whose [FixStep.id] is in [keep]: the report
  /// itself when all are kept, null when none is (the project as it was) or
  /// when it cannot run now, else the report of the corrections made again.
  Future<AutoFixReport?> keepAutoFixSteps(AutoFixReport report, Set<String> keep) async {
    final all = {for (final s in report.steps) s.id};
    if (all.difference(keep).isEmpty) return report;
    if (!editAllowed()) return null;
    undo();
    if (!keep.any(all.contains)) return null;
    return autoFixAll(skip: onlyFixSteps(keep));
  }

  /// Keeps of "optimise" (whose [report] is the last thing done) only the
  /// changes whose [OptimizeChange.id] is in [keep]: the report itself when
  /// all are kept (or nothing was kept by the optimisation), null when none
  /// is (the project as it was) or when it cannot run now, else the report
  /// of the changes made again and designed.
  Future<OptimizeReport?> keepOptimizeChanges(OptimizeReport report, Set<String> keep) async {
    if (!report.improved || report.changes.isEmpty) return report;
    final chosen = [
      for (final ch in report.changes)
        if (keep.contains(ch.id)) ch,
    ];
    if (chosen.length == report.changes.length) return report;
    if (!editAllowed()) return null;
    undo();
    if (chosen.isEmpty) return null;
    return optimizeDesign(OptimizeOptions(replay: chosen));
  }
}
