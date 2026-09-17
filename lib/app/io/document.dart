/// Access to the host HTML document (no-op outside the browser).
library;

import 'document_stub.dart' if (dart.library.js_interop) 'document_web.dart' as impl;

/// Sets the `lang` attribute of the HTML document to the interface language,
/// so browsers, screen readers and translation tools follow the app.
void setDocumentLanguage(String lang) => impl.setDocumentLanguage(lang);
