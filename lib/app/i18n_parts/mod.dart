part of '../i18n.dart';

/// Strings added in 1.6.0 for model, catalogues, API and CLI: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _mod = <String, (String, String, String)>{
  // ---- reading a project file item by item (MOD-02, MOD-08)
  'read.newer': (
    'O arquivo vem de uma versão mais nova do app (formato {v}): o que esta versão não conhece fica guardado e é gravado de novo, mas não aparece.',
    'The file comes from a newer version of the app (format {v}): what this version does not know is kept and saved again, but not shown.',
    'El archivo viene de una versión más nueva de la app (formato {v}): lo que esta versión no conoce se guarda y se vuelve a grabar, pero no aparece.',
  ),
  'read.skipped': (
    '{n} item(ns) não puderam ser lidos e ficaram de lado; continuam no arquivo ao salvar.',
    '{n} item(s) could not be read and were set aside; they stay in the file when you save.',
    '{n} elemento(s) no se pudieron leer y quedaron aparte; siguen en el archivo al guardar.',
  ),
  'read.renumbered': (
    '{n} item(ns) com identificador repetido ou ausente receberam um novo.',
    '{n} item(s) with a repeated or missing id got a new one.',
    '{n} elemento(s) con identificador repetido o ausente recibieron uno nuevo.',
  ),
  'read.vertices': ('{n} vértice(s) sem coordenadas foram descartados.', '{n} vertex(es) without coordinates were dropped.', '{n} vértice(s) sin coordenadas se descartaron.'),
  'read.values': (
    '{n} opção(ões) desconhecida(s) passaram ao valor padrão ({v}).',
    '{n} unknown option(s) took the default value ({v}).',
    '{n} opción(es) desconocida(s) pasaron al valor predeterminado ({v}).',
  ),
  'imp.err.project_format': ('O arquivo não é um projeto do OpenCADIrrigation.', 'The file is not an OpenCADIrrigation project.', 'El archivo no es un proyecto de OpenCADIrrigation.'),
  'imp.err.project_json': (
    'O arquivo do projeto está danificado ou incompleto (não é um JSON válido).',
    'The project file is damaged or cut short (it is not valid JSON).',
    'El archivo del proyecto está dañado o incompleto (no es un JSON válido).',
  ),
};
