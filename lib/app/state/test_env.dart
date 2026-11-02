/// Whether the program runs under `flutter test` (1.6.0 CAD): the settings
/// remembered between visits stay out of the tests.
library;

export 'test_env_io.dart' if (dart.library.js_interop) 'test_env_web.dart';
