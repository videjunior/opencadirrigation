/// "Unsaved changes" guard when the browser tab is closed or reloaded.
library;

import 'unload_stub.dart' if (dart.library.js_interop) 'unload_web.dart' as impl;

/// Installs a beforeunload handler that asks for confirmation while
/// [isDirty] returns true. Calling it again replaces the previous handler.
void setUnloadGuard(bool Function() isDirty) => impl.setUnloadGuard(isDirty);
