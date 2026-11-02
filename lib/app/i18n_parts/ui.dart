part of '../i18n.dart';

/// Strings added in 1.6.0 for interface, phone layout and accessibility: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _ui = <String, (String, String, String)>{
  // ---- UI-04 catalogue: factory catalogue, the user's default, forgetting it
  'cat.factory': ('Restaurar o catálogo de fábrica…', 'Restore the factory catalog…', 'Restaurar el catálogo de fábrica…'),
  'cat.loadDefault': ('Carregar meu padrão…', 'Load my default…', 'Cargar mi predeterminado…'),
  'cat.forgetDefault': ('Esquecer meu padrão…', 'Forget my default…', 'Olvidar mi predeterminado…'),
  'cat.forget': ('Esquecer', 'Forget', 'Olvidar'),
  'cat.forgetConfirm': (
    'O catálogo que você salvou como padrão para novos projetos será apagado deste navegador, e os próximos projetos começarão com o catálogo de fábrica. Isso não pode ser desfeito; o catálogo deste projeto não muda.',
    'The catalog you saved as the default for new projects will be deleted from this browser, and the next projects will start with the factory catalog. This cannot be undone; the catalog of this project does not change.',
    'El catálogo que guardó como predeterminado para proyectos nuevos se borrará de este navegador y los próximos proyectos empezarán con el catálogo de fábrica. No se puede deshacer; el catálogo de este proyecto no cambia.',
  ),
  'cat.replace': ('Substituir', 'Replace', 'Reemplazar'),
  'cat.replaceLoss': (
    'O catálogo deste projeto será substituído: {n} itens que o novo catálogo não tem sairão dele, e os dados dos demais (nomes, preços) voltarão aos do novo catálogo.',
    'The catalog of this project will be replaced: {n} items the new catalog does not have will leave it, and the data of the others (names, prices) will go back to those of the new catalog.',
    'El catálogo de este proyecto será reemplazado: {n} ítems que el nuevo catálogo no tiene saldrán de él, y los datos de los demás (nombres, precios) volverán a los del nuevo catálogo.',
  ),
  'cat.replaceNoLoss': (
    'O catálogo deste projeto será substituído. Todos os itens dele existem no novo catálogo, mas os dados (nomes, preços) voltarão aos do novo catálogo.',
    'The catalog of this project will be replaced. All its items exist in the new catalog, but their data (names, prices) will go back to those of the new catalog.',
    'El catálogo de este proyecto será reemplazado. Todos sus ítems existen en el nuevo catálogo, pero sus datos (nombres, precios) volverán a los del nuevo catálogo.',
  ),
  'cat.replaceInUse': (
    '{n} desses itens estão em uso por {m} objetos do desenho, que ficarão sem modelo até você escolher outro.',
    '{n} of those items are used by {m} objects of the drawing, which will be left without a model until you choose another.',
    '{n} de esos ítems están en uso por {m} objetos del dibujo, que quedarán sin modelo hasta que elija otro.',
  ),
  'cat.replaceUndo': (
    'Depois de fechar o catálogo, Ctrl+Z desfaz a substituição. O padrão salvo para novos projetos não muda.',
    'After closing the catalog, Ctrl+Z undoes the replacement. The default saved for new projects does not change.',
    'Tras cerrar el catálogo, Ctrl+Z deshace el reemplazo. El predeterminado guardado para proyectos nuevos no cambia.',
  ),
  'msg.catalogFactory': ('Catálogo de fábrica restaurado neste projeto', 'Factory catalog restored in this project', 'Catálogo de fábrica restaurado en este proyecto'),
  'msg.catalogDefaultLoaded': ('Seu catálogo padrão foi carregado neste projeto', 'Your default catalog was loaded into this project', 'Su catálogo predeterminado se cargó en este proyecto'),
  'msg.catalogDefaultForgotten': (
    'Padrão esquecido: novos projetos começam com o catálogo de fábrica',
    'Default forgotten: new projects start with the factory catalog',
    'Predeterminado olvidado: los proyectos nuevos empiezan con el catálogo de fábrica',
  ),
  // ---- UI-05 phone menu: tabs, recent projects and the toggles of the desktop menus
  'mob.tabs': ('Abas', 'Tabs', 'Pestañas'),
  'mob.gridSnap': ('Encaixe na grade (F9)', 'Snap to grid (F9)', 'Ajuste a la cuadrícula (F9)'),
  'mob.polar': ('Rastreamento polar: {s}', 'Polar tracking: {s}', 'Rastreo polar: {s}'),
  'mob.off': ('desligado', 'off', 'desactivado'),
  // ---- UI-06 typed commands on touch screens
  'cmd.open': ('Digitar comando ou coordenada', 'Type a command or a coordinate', 'Escribir un comando o una coordenada'),
  'cmd.hint': ('L, PL… ou 25,10  @5,0  @25<90  12', 'L, PL… or 25,10  @5,0  @25<90  12', 'L, PL… o 25,10  @5,0  @25<90  12'),
  'cmd.run': ('Executar (Enter)', 'Run (Enter)', 'Ejecutar (Intro)'),
  'cmd.letters': ('Letras (comandos)', 'Letters (commands)', 'Letras (comandos)'),
  'cmd.digits': ('Números (coordenadas)', 'Numbers (coordinates)', 'Números (coordenadas)'),
  'props.lengthNo': (
    'Esse comprimento não cabe: o último trecho ficaria com comprimento zero ou negativo.',
    'That length does not fit: the last segment would become zero or negative.',
    'Esa longitud no cabe: el último tramo quedaría con longitud cero o negativa.',
  ),
  // ---- UI-07 layout by width, height and pointer
  'ui.sideOpen': ('Mostrar propriedades, camadas e histórico', 'Show properties, layers and history', 'Mostrar propiedades, capas e historial'),
  'ui.sideClose': ('Recolher o painel', 'Fold the panel away', 'Recoger el panel'),
  // ---- UI-29 the real scale in the status bar
  'ui.scaleTip': (
    'Escala do desenho na tela (tela de 96 pontos por polegada)',
    'Scale of the drawing on the screen (a screen of 96 dots per inch)',
    'Escala del dibujo en la pantalla (pantalla de 96 puntos por pulgada)',
  ),
  // ---- UI-08 numbers in the notation of the language; UI-10 the item of an object outside the list
  'num.readAs': ('Lido como {v}. Toque aqui se era {alt}.', 'Read as {v}. Tap here if you meant {alt}.', 'Leído como {v}. Toque aquí si quiso decir {alt}.'),
  'num.negate': ('Trocar o sinal (±)', 'Change the sign (±)', 'Cambiar el signo (±)'),
  'props.notInList': ('(fora da lista)', '(not in the list)', '(fuera de la lista)'),
};
