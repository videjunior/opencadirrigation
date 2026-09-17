/// Platform choice of the design runner: a Web Worker in the browser, an
/// isolate on the desktop, the UI thread elsewhere.
library;

import 'design_job.dart';
import 'design_runner_thread.dart' if (dart.library.js_interop) 'design_runner_web.dart' if (dart.library.isolate) 'design_runner_io.dart' as impl;

export 'design_job.dart' show DesignRunner, InThreadDesignRunner, DesignJobException, DesignRequest, DesignResponse, DesignProgress, DesignStage, applyDesignResponse;

DesignRunner createDesignRunner() => impl.createDesignRunner();
