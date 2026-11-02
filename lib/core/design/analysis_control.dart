/// Progress and cancel of the long analyses of a designed project (1.6.0
/// MOT+, UI-19): an analysis written as a sequence of steps runs to its end
/// at once ([runSteps]), or a step at a time with the event loop given a turn
/// between them ([runStepsAsync]), so that an interface keeps painting, shows
/// how far it got and can stop it. Pure Dart: the dialogs, the assistant, the
/// tests and a worker can use it.
library;

import 'dart:async';

/// The analysis was cancelled before its end ([AnalysisControl.cancel]).
class AnalysisCancelled implements Exception {
  const AnalysisCancelled();

  @override
  String toString() => 'AnalysisCancelled';
}

/// What an interface gives a long analysis: [onProgress] hears the steps
/// done out of the total (the total may grow as the analysis finds more to
/// do), [cancel] stops it at the next step.
class AnalysisControl {
  AnalysisControl({this.onProgress, this.slice = const Duration(milliseconds: 30)});

  final void Function(int done, int total)? onProgress;

  /// Longest run of steps between two turns of the event loop.
  final Duration slice;

  bool _cancelled = false;

  /// Asks the analysis to stop: it throws [AnalysisCancelled] at its next step.
  void cancel() => _cancelled = true;

  bool get cancelled => _cancelled;

  /// Throws [AnalysisCancelled] once [cancel] was called.
  void check() {
    if (_cancelled) throw const AnalysisCancelled();
  }
}

/// One step of an analysis: how many are done and how many there are.
typedef AnalysisStep = (int done, int total);

/// Runs every step of [steps] at once (the synchronous analyses).
void runSteps(Iterable<AnalysisStep> steps) {
  for (final _ in steps) {}
}

/// Runs the steps of [steps], reporting each to [control] and giving the
/// event loop a turn whenever [AnalysisControl.slice] has passed; throws
/// [AnalysisCancelled] at the first step after [AnalysisControl.cancel].
Future<void> runStepsAsync(Iterable<AnalysisStep> steps, AnalysisControl? control) async {
  final clock = Stopwatch()..start();
  final slice = control?.slice ?? const Duration(milliseconds: 30);
  // a first turn, so that the interface shows the analysis started
  await Future<void>.delayed(Duration.zero);
  for (final (done, total) in steps) {
    control?.check();
    control?.onProgress?.call(done, total);
    if (clock.elapsed >= slice) {
      await Future<void>.delayed(Duration.zero);
      control?.check();
      clock.reset();
    }
  }
}
