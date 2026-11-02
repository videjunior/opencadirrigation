/// Long readers run on the thread that also draws the interface (in the
/// browser there is no other): they work in slices of a few milliseconds and
/// let the screen breathe between them, report how far they got and stop
/// when the user cancels.
library;

/// The import was cancelled by the user.
class ImportCancelled implements Exception {
  const ImportCancelled();
  @override
  String toString() => 'import_cancelled';
}

/// Time slices of a long job: [due] tells the job to call [pause], which
/// reports the progress, yields to the event loop (input, painting) and
/// throws [ImportCancelled] once [cancel] was called.
class WorkSlicer {
  WorkSlicer({this.sliceMs = 24, this.onProgress});

  /// Work between two pauses (milliseconds).
  final int sliceMs;

  /// Fraction done (0–1), called at every pause.
  final void Function(double fraction)? onProgress;

  final _clock = Stopwatch()..start();
  bool _cancelled = false;

  /// Progress is reported in [_from]–[_to] of the whole (see [stage]).
  double _from = 0, _to = 1;

  bool get cancelled => _cancelled;

  /// Asks the job to stop at its next pause.
  void cancel() => _cancelled = true;

  /// True when the current slice has used its time.
  bool get due => _clock.elapsedMilliseconds >= sliceMs;

  /// The following fractions are of the part [from]–[to] of the whole job.
  void stage(double from, double to) {
    _from = from;
    _to = to;
  }

  /// Reports [fraction] of the current stage, lets the interface run and
  /// throws [ImportCancelled] when the job was cancelled.
  Future<void> pause([double? fraction]) async {
    if (fraction != null) onProgress?.call((_from + (_to - _from) * fraction.clamp(0.0, 1.0)).clamp(0.0, 1.0));
    await Future<void>.delayed(Duration.zero);
    if (_cancelled) throw const ImportCancelled();
    _clock.reset();
  }

  /// [pause] only when the slice is [due].
  Future<void> maybePause(double Function() fraction) async {
    if (due) await pause(fraction());
  }
}
