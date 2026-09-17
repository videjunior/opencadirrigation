/// Opens an external page (project repository, site) in a new browser tab;
/// a no-op on platforms without a browser window.
library;

import 'links_stub.dart' if (dart.library.js_interop) 'links_web.dart' as impl;

void openExternalLink(String url) => impl.openExternalLink(url);
