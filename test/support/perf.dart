/// Wall-clock budgets of the speed tests.
///
/// The budgets are written for a developer machine. A shared CI runner with
/// a few vCPUs and several test files running at once is often 2–4× slower,
/// so `OCI_PERF_SCALE` (a number, default 1) multiplies every budget: CI runs
/// the tests tagged `perf` (dart_test.yaml) apart, one file at a time, with
/// a scale of 3. Locally: `flutter test --tags perf` or
/// `flutter test --exclude-tags perf`.
library;

import 'dart:io';

/// Tag of the tests that measure wall-clock time.
const perfTag = 'perf';

/// The factor `OCI_PERF_SCALE` gives the budgets (at least 1).
double get perfScale {
  final v = double.tryParse(Platform.environment['OCI_PERF_SCALE'] ?? '');
  return v == null || v < 1 ? 1 : v;
}

/// A budget of [ms] milliseconds on this machine.
int perfBudgetMs(int ms) => (ms * perfScale).ceil();

/// A duration of [ms] milliseconds scaled like the budgets, for the time
/// windows a test sets in the code it measures.
Duration perfDuration(int ms) => Duration(milliseconds: perfBudgetMs(ms));
