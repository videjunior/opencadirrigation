import 'package:web/web.dart' as web;

void setDocumentLanguage(String lang) {
  final tag = switch (lang) { 'pt' => 'pt-BR', 'es' => 'es', _ => 'en' };
  web.document.documentElement?.setAttribute('lang', tag);
}
