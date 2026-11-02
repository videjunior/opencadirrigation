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
  'props.notInCatalog': ('(fora do catálogo)', '(not in the catalog)', '(fuera del catálogo)'),
  'props.disabled': ('(desativado)', '(switched off)', '(desactivado)'),
  'props.noLayer': ('(camada inexistente)', '(no such layer)', '(capa inexistente)'),
  'cat.disabledInUse': (
    '{n} objetos do desenho usam este item: eles continuam com ele, que aparece nas propriedades como (desativado), mas ele sai das listas de escolha.',
    '{n} objects of the drawing use this item: they keep it, shown in their properties as (switched off), but it leaves the lists to choose from.',
    '{n} objetos del dibujo usan este ítem: lo conservan, mostrado en sus propiedades como (desactivado), pero sale de las listas para elegir.',
  ),
  // ---- UI-12 fractions typed as percentages or out of range
  'ui.fractionCut': ('{v} fica fora da faixa {r}: foi gravado {n}.', '{v} is outside {r}: {n} was kept.', '{v} está fuera del rango {r}: se guardó {n}.'),
  // ---- UI-21 labels whose unit follows the unit system (the unit is added after them)
  'ui.depth': ('Profundidade', 'Depth', 'Profundidad'),
  'ui.riser': ('Altura da haste', 'Riser height', 'Altura del tubo de subida'),
  'ui.waterLevel': ('Nível de água relativo ao solo', 'Water level relative to ground', 'Nivel de agua respecto al suelo'),
  'ui.pivotRadius': ('Comprimento da lateral', 'Span pipe length', 'Longitud de la lateral'),
  'ui.pivotSpan': ('Vão entre torres', 'Span between towers', 'Vano entre torres'),
  'ui.pivotTravel': ('Percurso da lateral móvel', 'Linear travel length', 'Recorrido de la lateral'),
  'ui.pivotPipeId': ('Diâmetro interno do tubo', 'Pipe inner diameter', 'Diámetro interior del tubo'),
  'ui.pivotHeight': ('Altura do tubo', 'Pipe height', 'Altura del tubo'),
  'ui.pivotThrow': ('Alcance além da ponta', 'Throw beyond the end', 'Alcance más allá de la punta'),
  'ui.pivotDepth': ('Lâmina bruta por ciclo', 'Gross depth per cycle', 'Lámina bruta por ciclo'),
  'ui.pivotWidth': ('Largura molhada na ponta', 'Wetted width at the end', 'Ancho mojado en la punta'),
  'ui.pivotLoss': ('Perdas da máquina', 'Machine losses', 'Pérdidas de la máquina'),
  'ui.pivotMaxRate': ('Taxa máx. do solo (0 = não verificar)', 'Soil max. rate (0 = no check)', 'Tasa máx. del suelo (0 = no verificar)'),
  'ui.pivotSprSpacing': ('Espaçamento dos aspersores', 'Sprinkler spacing', 'Espaciado de los aspersores'),
  'ui.textHeight': ('Altura do texto', 'Text height', 'Altura del texto'),
  'ui.radius': ('Raio', 'Radius', 'Radio'),
  'ui.hatchSpacing': ('Espaçamento da hachura', 'Hatch spacing', 'Espaciamiento del sombreado'),
  'ui.symbolSize': ('Tamanho', 'Size', 'Tamaño'),
  'ui.dimRadius': ('Raio do arco de cota', 'Dimension arc radius', 'Radio del arco de cota'),
  'ui.imageWidth': ('Largura', 'Width', 'Ancho'),
  'ui.imageHeight': ('Altura', 'Height', 'Alto'),
  // ---- UI-13 calculators with a small catalogue; UI-21 velocities in the unit system
  'msg.pumpCalcNeedsCatalog': (
    'A calculadora de bomba precisa de ao menos uma bomba e um tubo de linha principal ativos no catálogo.',
    'The pump calculator needs at least one pump and one main line pipe switched on in the catalog.',
    'La calculadora de bomba necesita al menos una bomba y una tubería de línea principal activas en el catálogo.',
  ),
  'msg.hammerCalcNeedsCatalog': (
    'O cálculo do golpe de aríete precisa de ao menos um tubo no catálogo.',
    'The water hammer calculator needs at least one pipe in the catalog.',
    'El cálculo del golpe de ariete necesita al menos una tubería en el catálogo.',
  ),
  'ui.velocityChange': ('Variação de velocidade', 'Velocity change', 'Variación de velocidad'),
  'ui.removeFlow': ('Remover este turno', 'Remove this shift', 'Quitar este turno'),
  // ---- UI-17 report tables: sort, filter, copy, CSV, locate
  'rt.filter': ('Filtrar linhas…', 'Filter rows…', 'Filtrar filas…'),
  'rt.highlighted': ('Só destacadas', 'Highlighted only', 'Solo destacadas'),
  'rt.count': ('{n} de {m}', '{n} of {m}', '{n} de {m}'),
  'rt.copy': ('Copiar as linhas visíveis (cole na planilha)', 'Copy the visible rows (paste into a spreadsheet)', 'Copiar las filas visibles (pegue en la hoja de cálculo)'),
  'rt.copied': ('{n} linhas copiadas', '{n} rows copied', '{n} filas copiadas'),
  'rt.csv': ('Salvar esta tabela em CSV', 'Save this table as CSV', 'Guardar esta tabla en CSV'),
  'rt.sortBy': ('Ordenar por {c}', 'Sort by {c}', 'Ordenar por {c}'),
  'rt.locate': ('Clique para localizar no desenho', 'Click to find it in the drawing', 'Haga clic para ubicarlo en el dibujo'),
  'ui.reportsClose': ('Fechar os relatórios', 'Close the reports', 'Cerrar los informes'),
  // ---- UI-23 the layer buttons say what they do
  'layer.toggleVis': ('Mostrar ou ocultar a camada {l}', 'Show or hide the layer {l}', 'Mostrar u ocultar la capa {l}'),
  'layer.toggleLock': ('Travar ou destravar a camada {l}', 'Lock or unlock the layer {l}', 'Bloquear o desbloquear la capa {l}'),
  'layer.colorOf': ('Cor da camada {l}', 'Colour of the layer {l}', 'Color de la capa {l}'),
  'layer.remove': ('Excluir a camada {l}', 'Delete the layer {l}', 'Eliminar la capa {l}'),
  // ---- UI-20 downloads that must not be left running out of sight
  'ui.downloadRunning': ('O download continua: use Cancelar para interrompê-lo.', 'The download is still running: use Cancel to stop it.', 'La descarga sigue: use Cancelar para detenerla.'),
  // ---- UI-26 the start-up screen never traps the user on a place it cannot find
  'start.notFoundGoOn': (
    'Nenhum lugar encontrado. Corrija o nome, ou toque de novo no botão para seguir sem localizar (dá para georreferenciar depois).',
    'No place found. Correct the name, or press the button again to go on without a place (you can georeference later).',
    'No se encontró ningún lugar. Corrija el nombre o pulse de nuevo el botón para seguir sin ubicar (puede georreferenciar después).',
  ),
  'start.searchFailedGoOn': (
    'A busca não respondeu (sem internet?). Tente de novo, ou toque outra vez no botão para seguir sem localizar.',
    'The search did not answer (no internet?). Try again, or press the button again to go on without a place.',
    'La búsqueda no respondió (¿sin internet?). Inténtelo de nuevo o pulse otra vez el botón para seguir sin ubicar.',
  ),
  'start.skipPlace': ('Continuar sem localizar', 'Go on without a place', 'Seguir sin ubicar'),
  // ---- UI-28 messages kept and read again; a file that is no project
  'ui.messages': ('Mensagens recentes', 'Recent messages', 'Mensajes recientes'),
  'ui.messagesMenu': ('Mensagens recentes…', 'Recent messages…', 'Mensajes recientes…'),
  'ui.messagesShort': ('Ver todas', 'See all', 'Ver todas'),
  'ui.noMessages': ('Nenhuma mensagem nesta sessão.', 'No messages in this session.', 'Ningún mensaje en esta sesión.'),
  'ui.copyAll': ('Copiar tudo', 'Copy all', 'Copiar todo'),
  'msg.notProject': (
    'Este arquivo não é um projeto do OpenCADIrrigation (.oci.json). Para trazer desenhos e dados (DXF, DWG, KML, SHP, CSV…) use {m}.',
    'This file is not an OpenCADIrrigation project (.oci.json). To bring in drawings and data (DXF, DWG, KML, SHP, CSV…) use {m}.',
    'Este archivo no es un proyecto de OpenCADIrrigation (.oci.json). Para traer dibujos y datos (DXF, DWG, KML, SHP, CSV…) use {m}.',
  ),
  // ---- UI-22 the hydraulic grade line chart
  'hgl.axis': ('cota e carga ({u})', 'elevation and head ({u})', 'cota y carga ({u})'),
  'hgl.readout': ('{d}: terreno {z}, carga {h}, pressão {p}', '{d}: ground {z}, head {h}, pressure {p}', '{d}: terreno {z}, carga {h}, presión {p}'),
  // ---- UI-23 / UI-14 the conditional label rules
  'ui.ruleColour': ('Cor da regra', 'Colour of the rule', 'Color de la regla'),
  'ui.removeRule': ('Remover esta regra', 'Remove this rule', 'Quitar esta regla'),
  'ui.removeNozzle': ('Remover este bocal', 'Remove this nozzle', 'Quitar esta boquilla'),
};
