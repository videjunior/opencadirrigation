part of '../i18n.dart';

/// Strings added in 1.6.0 for site, PWA, translations and documentation: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _sit = <String, (String, String, String)>{
  // Help → About: the legal pages of the site and the technical responsibility (SIT-01, SIT-13)
  'about.privacy': ('Política de privacidade', 'Privacy policy', 'Política de privacidad'),
  'about.terms': ('Termos de uso', 'Terms of use', 'Términos de uso'),
  'about.disclaimer': (
    'Ferramenta de apoio ao projeto: confira os resultados; o projeto deve ser revisado e assinado por um profissional habilitado.',
    'A design aid: check the results; the design must be reviewed and signed by a qualified professional.',
    'Herramienta de apoyo al proyecto: revise los resultados; el proyecto debe revisarlo y firmarlo un profesional habilitado.',
  ),
  // a newer build of the web app is installed while this page runs the older one (SIT-07)
  'update.ready': ('Há uma versão nova do OpenCADIrrigation pronta.', 'A new version of OpenCADIrrigation is ready.', 'Hay una versión nueva de OpenCADIrrigation lista.'),
  'update.reload': ('Recarregar', 'Reload', 'Recargar'),
  'update.later': ('Depois', 'Later', 'Más tarde'),
  'update.unsavedTitle': ('Recarregar agora?', 'Reload now?', '¿Recargar ahora?'),
  'update.unsaved': (
    'Há alterações não salvas. Elas ficam no autossalvamento deste navegador, e o app oferece recuperá-las quando abrir de novo; uma conversa da IA em andamento é interrompida.',
    'There are unsaved changes. They stay in this browser\'s autosave, and the app offers to recover them when it opens again; an AI conversation in progress is stopped.',
    'Hay cambios sin guardar. Quedan en el guardado automático de este navegador, y la aplicación ofrece recuperarlos cuando se abra de nuevo; una conversación de la IA en curso se interrumpe.',
  ),
};
