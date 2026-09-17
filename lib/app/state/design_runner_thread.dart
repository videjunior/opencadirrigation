/// Default design runner: the UI thread (platforms without workers or isolates).
library;

import 'design_job.dart';

DesignRunner createDesignRunner() => InThreadDesignRunner();
