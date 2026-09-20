import 'package:web/web.dart' as web;

import '../i18n.dart' show languageTag;

void setDocumentLanguage(String lang) {
  web.document.documentElement?.setAttribute('lang', languageTag(lang));
}
