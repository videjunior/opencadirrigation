/// The page going to the background or away (conditional import): the
/// browser's `visibilitychange` and `pagehide` events; nothing elsewhere.
///
/// A phone may discard a page in the background without another event, and
/// a closed or reloaded page runs only what `pagehide` does at once, so the
/// copies of the projects are written when the page is hidden (in the
/// background, the way every copy is) and once more, synchronously, when it
/// goes away.
library;

import 'page_lifecycle_stub.dart' if (dart.library.js_interop) 'page_lifecycle_web.dart' as impl;

/// Calls [hidden] whenever the page is hidden (another tab, another app,
/// the screen locked) and [closing] when it is being unloaded (closed,
/// reloaded, navigated away). Calling it again replaces the callbacks.
void watchPageLifecycle({required void Function() hidden, required void Function() closing}) => impl.watchPageLifecycle(hidden: hidden, closing: closing);
