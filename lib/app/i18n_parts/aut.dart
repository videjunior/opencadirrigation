part of '../i18n.dart';

/// Strings added in 1.6.0 for automatic design and the design assistant: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _aut = <String, (String, String, String)>{
  // ---- live summaries of the automatic tools
  'auto.step.layout': ('Distribuindo os aspersores…', 'Laying out the heads…', 'Distribuyendo los aspersores…'),
  'auto.step.zoning': ('Agrupando em zonas…', 'Grouping into zones…', 'Agrupando en zonas…'),
  'auto.step.routing': ('Traçando os tubos: zona {n} de {m}…', 'Routing the pipes: zone {n} of {m}…', 'Trazando las tuberías: zona {n} de {m}…'),
  'auto.exclusionsLeftOut': (
    '{n} forma(s) fechada(s) selecionada(s) dentro do contorno ficam de fora (lago, galpão, poço)',
    '{n} selected closed shape(s) inside the outline are left out (a pond, a shed, a well)',
    '{n} forma(s) cerrada(s) seleccionada(s) dentro del contorno quedan fuera (laguna, galpón, pozo)',
  ),
  'autolay.noSupplyFlow': (
    'A fonte não tem vazão de projeto: as zonas partem de {q}, a vazão usual de uma zona desta família. Informe a vazão da fonte para zonear por ela.',
    'The supply has no design flow: the zones start from {q}, the usual flow of a zone of this family. Enter the supply flow to zone by it.',
    'La fuente no tiene caudal de diseño: las zonas parten de {q}, el caudal usual de una zona de esta familia. Indique el caudal de la fuente para zonificar por él.',
  ),
  // ---- block generator
  'warn.block_uncovered': (
    'Parte do polígono a mais de uma entrelinha de qualquer lateral',
    'Part of the polygon farther than one lateral spacing from every lateral',
    'Parte del polígono a más de una separación entre laterales de cualquier lateral',
  ),
  // ---- outlines that cross themselves
  'warn.layout_self_intersect': (
    'O contorno cruza a si mesmo: cada laço foi tratado como uma área à parte',
    'The outline crosses itself: each of its loops was taken as an area of its own',
    'El contorno se cruza a sí mismo: cada lazo se trató como un área aparte',
  ),
  'warn.field_self_intersect': (
    'O contorno do talhão cruza a si mesmo: cada laço foi subdividido à parte',
    'The field outline crosses itself: each of its loops was subdivided on its own',
    'El contorno de la parcela se cruza a sí mismo: cada lazo se subdividió aparte',
  ),
  'check.area_self_intersect': ('Contorno da área cruza a si mesmo', 'Area outline crosses itself', 'Contorno del área que se cruza a sí mismo'),
  'adv.area_self_intersect.why': (
    'O contorno desta área irrigada passa por cima de si mesmo (forma de gravata ou de oito), em geral porque um vértice foi arrastado por cima de outro lado ou porque veio assim de um arquivo DXF ou SHP. A área calculada sai errada (pode chegar a zero), e com ela a necessidade de água, o volume, o licenciamento e o cronograma.',
    'The outline of this irrigated area runs over itself (a bow tie or a figure of eight), usually because a vertex was dragged across another side or because it came so from a DXF or SHP file. Its computed area comes out wrong (it can drop to zero), and with it the water need, the volume, the permit and the schedule.',
    'El contorno de esta área regada pasa por encima de sí mismo (forma de corbatín o de ocho), en general porque un vértice se arrastró por encima de otro lado o porque llegó así de un archivo DXF o SHP. El área calculada sale mal (puede llegar a cero), y con ella la necesidad de agua, el volumen, la licencia y el cronograma.',
  ),
  'adv.area_self_intersect.how': (
    'Use a correção para dividir a área nas áreas simples que o contorno fecha (cada uma com a mesma cultura e os mesmos dados), ou mova os vértices para desfazer o cruzamento.',
    'Use the correction to split the area into the simple areas the outline encloses (each with the same crop and data), or move the vertices so it no longer crosses.',
    'Use la corrección para dividir el área en las áreas simples que encierra el contorno (cada una con el mismo cultivo y los mismos datos), o mueva los vértices para deshacer el cruce.',
  ),
  'fix.splitArea': ('Dividir em áreas simples', 'Split into simple areas', 'Dividir en áreas simples'),
  'fixed.splitArea': ('área dividida em {n} áreas simples', 'area split into {n} simple areas', 'área dividida en {n} áreas simples'),
  // ---- overlapping pipes and laterals
  'check.pipes_overlap': ('Tubos ou laterais sobrepostos', 'Pipes or laterals on top of each other', 'Tuberías o laterales superpuestos'),
  'adv.pipes_overlap.why': (
    'Dois tubos, laterais ou fitas do mesmo escopo correm um sobre o outro num trecho (um tubo colado duas vezes, dois trechos desenhados no mesmo lugar, uma lateral que volta sobre si mesma). O cálculo os trata como tubos em paralelo, subestimando a perda de carga, e a lista de materiais conta o trecho em dobro.',
    'Two pipes, laterals or tapes of one scope run on top of each other over a stretch (a pipe pasted twice, two pieces drawn over the same place, a lateral that doubles back). The design takes them as pipes in parallel, with too little friction, and the bill of materials counts the stretch twice.',
    'Dos tuberías, laterales o cintas del mismo alcance corren una sobre la otra en un tramo (una tubería pegada dos veces, dos tramos dibujados en el mismo lugar, un lateral que vuelve sobre sí mismo). El cálculo las trata como tuberías en paralelo, subestimando la pérdida de carga, y la lista de materiales cuenta el tramo dos veces.',
  ),
  'adv.pipes_overlap.how': (
    'Quando são o mesmo item desenhado duas vezes, use a correção para manter só um. Senão apague ou apare o trecho repetido, ou desloque um dos tubos se forem de fato duas linhas na mesma vala.',
    'When they are the same item drawn twice, use the correction to keep only one. Otherwise delete or trim the repeated stretch, or move one of the pipes aside if they really are two lines in one trench.',
    'Cuando son el mismo elemento dibujado dos veces, use la corrección para dejar solo uno. Si no, borre o recorte el tramo repetido, o desplace una de las tuberías si de verdad son dos líneas en la misma zanja.',
  ),
  // ---- sprinkler spacing and uniformity
  'check.zone_spacing_wide': (
    'Aspersores mais espaçados do que o alcance permite',
    'Sprinklers spaced farther apart than their throw allows',
    'Aspersores más espaciados de lo que permite su alcance',
  ),
  'adv.zone_spacing_wide.why': (
    'Os aspersores de círculo inteiro desta zona estão mais afastados do que o raio molhado permite: entre eles fica uma faixa que recebe muito menos água, e nenhum tempo de rega compensa sem encharcar o resto. Cabeça a cabeça é 50 % do diâmetro molhado; com pouco vento aceita-se até cerca de 60 % em malha quadrada ou triangular, e 50–55 % por 60–65 % em malha retangular (Keller e Bliesner), menos com vento.',
    'The full-circle sprinklers of this zone stand farther apart than their wetted radius allows: a band between them gets far less water, and no run time makes up for it without soaking the rest. Head to head is 50 % of the wetted diameter; in light wind about 60 % is accepted on a square or triangular grid, and 50–55 % by 60–65 % on a rectangular one (Keller and Bliesner), less in wind.',
    'Los aspersores de círculo completo de esta zona están más separados de lo que permite su radio mojado: entre ellos queda una franja que recibe mucha menos agua, y ningún tiempo de riego lo compensa sin encharcar el resto. Cabeza a cabeza es el 50 % del diámetro mojado; con poco viento se acepta hasta cerca del 60 % en malla cuadrada o triangular, y 50–55 % por 60–65 % en malla rectangular (Keller y Bliesner), menos con viento.',
  ),
  'adv.zone_spacing_wide.how': (
    'Use um bocal de raio maior (a mensagem mostra o espaçamento máximo para o raio atual), aproxime as linhas ou os aspersores, ou acrescente uma fila entre as atuais. O Layout automático e os gabaritos espaçam cabeça a cabeça.',
    'Use a nozzle with a larger radius (the message shows the largest spacing for the present one), bring the lines or the heads closer, or add a row between the present ones. The automatic layout and the templates space head to head.',
    'Use una boquilla de mayor radio (el mensaje muestra la separación máxima para el radio actual), acerque las líneas o los aspersores, o agregue una fila entre las actuales. El trazado automático y las plantillas espacian cabeza a cabeza.',
  ),
  'check.area_uniformity_low': ('Área regada de forma desigual', 'Area watered unevenly', 'Área regada de forma desigual'),
  'adv.area_uniformity_low.why': (
    'O densograma dos aspersores (com a pressão nominal de cada um, todos os que jogam água sobre a área) mostra uma distribuição pobre: CU de Christiansen abaixo de 75 %, DU do quarto mais seco abaixo de 60 % ou mais de 5 % da área recebendo menos da metade da média. As partes secas obrigam a regar mais tempo, desperdiçando água no resto.',
    'The densogram of the sprinklers (each at its nominal pressure, every one that throws onto the area) shows a poor distribution: a Christiansen CU below 75 %, a low-quarter DU below 60 % or more than 5 % of the area getting less than half the mean. The dry parts force longer run times that waste water on the rest.',
    'El densograma de los aspersores (cada uno a su presión nominal, todos los que lanzan agua sobre el área) muestra una distribución pobre: CU de Christiansen por debajo del 75 %, DU del cuarto más seco por debajo del 60 % o más del 5 % del área recibiendo menos de la mitad de la media. Las partes secas obligan a regar más tiempo, desperdiciando agua en el resto.',
  ),
  'adv.area_uniformity_low.how': (
    'Abra o densograma para ver onde falta água. Aproxime as cabeças (espaçamento até o raio), troque os bocais para casar a precipitação (meio círculo com metade da vazão), ponha arcos parciais nas bordas ou refaça a área com o Layout automático ou um gabarito.',
    'Open the densogram to see where water is short. Bring the heads closer (spacing up to the radius), change the nozzles to match the precipitation (a half circle with half the flow), put part circles on the edges, or lay the area out again with the automatic layout or a template.',
    'Abra el densograma para ver dónde falta agua. Acerque las cabezas (separación hasta el radio), cambie las boquillas para igualar la precipitación (medio círculo con la mitad del caudal), ponga arcos parciales en los bordes o rehaga el área con el trazado automático o una plantilla.',
  ),
  // ---- fix automatically and optimise
  'fixed.connectPipe': (
    'tubo de {d} m ligando o aspersor ao tubo mais próximo (o aspersor ficou no lugar)',
    '{d} m pipe joining the head to the nearest pipe (the head stays where it was)',
    'tubería de {d} m que une el aspersor a la tubería más cercana (el aspersor queda en su lugar)',
  ),
  'fixfail.flowsPastDay': (
    'os {n} turnos somariam {h} h, mais que um dia: reduza as durações ou aumente a vazão da fonte',
    'the {n} system flows would take {h} h, more than a day: shorten them or raise the supply flow',
    'los {n} turnos sumarían {h} h, más de un día: acorte las duraciones o aumente el caudal de la fuente',
  ),
  'fix.capSupplyDesign': ('Usar os máximos da fonte no projeto', 'Design with the supply maximums', 'Usar los máximos de la fuente en el diseño'),
  'fixed.capSupplyDesign': (
    'vazão e pressão de projeto da fonte reduzidas aos máximos que ela fornece',
    'supply design flow and pressure lowered to the maximums it gives',
    'caudal y presión de diseño de la fuente reducidos a los máximos que entrega',
  ),
  'adv.decisions': ('Precisa da sua decisão (não foi aplicado sozinho):', 'Needs your decision (not applied on its own):', 'Necesita su decisión (no se aplicó solo):'),
  'opt.newWarnings': ('Avisos novos que impediram mudanças: {w}', 'New warnings that held changes back: {w}', 'Avisos nuevos que impidieron cambios: {w}'),
  'opt.rejected': ('{n} mudança(s) desfeita(s) porque pioravam o projeto', '{n} change(s) taken back because they made the design worse', '{n} cambio(s) deshecho(s) porque empeoraban el diseño'),
  // ---- templates
  'warn.template_centreline_turn': (
    'A linha central volta sobre si mesma (curva de mais de 150°): desenhe o fairway em dois trechos',
    'The centreline turns back on itself (a bend of more than 150°): draw the fairway as two stretches',
    'La línea central vuelve sobre sí misma (curva de más de 150°): dibuje el fairway en dos tramos',
  ),
  // ================================================================ wave 2 (1.6.0 AUT+)
  // ---- guided blocks whose rows go past the bends of the guide (MOD-26)
  'warn.block_guide_offset': (
    'Linhas de laterais mais afastadas da guia do que o raio das curvas dela, ou contornando um canto vivo: cantos arredondados ou laços cortados, não são cópias paralelas da guia',
    'Rows of laterals farther from the guide than the radius of its bends, or going round a sharp corner of it: their corners were rounded or their loops cut off, so they are not plain parallel copies of the guide',
    'Filas de laterales más alejadas de la guía que el radio de sus curvas, o rodeando una esquina viva: esquinas redondeadas o lazos cortados, no son copias paralelas de la guía',
  ),
  // ---- tree rings round exclusions (AUT-19)
  'warn.rings_detour': (
    'A lateral contorna uma exclusão ou um recorte da área entre duas árvores',
    'The lateral goes round an exclusion or a notch of the area between two trees',
    'La lateral rodea una exclusión o un entrante del área entre dos árboles',
  ),
  // ---- default burial depths of the quote (AUT-25)
  'proposal.mainlineDepth': ('Profundidade da adutora sem a sua (m)', 'Depth of mainline pipes without their own (m)', 'Profundidad de la tubería principal sin la suya (m)'),
  'proposal.zoneDepth': (
    'Profundidade dos tubos de setor sem a sua (m; 0 = na superfície)',
    'Depth of zone pipes without their own (m; 0 = on the surface)',
    'Profundidad de las tuberías de sector sin la suya (m; 0 = en la superficie)',
  ),
  // ---- an area drawn or edited crossing itself (AUT-05)
  'aut.areaCrosses': (
    'O contorno da área “{n}” cruza a si mesmo: a área calculada sai errada (e com ela a necessidade de água). Mova os vértices ou use a correção “Dividir em áreas simples” nas Mensagens.',
    'The outline of the area “{n}” crosses itself: its computed area comes out wrong (and with it the water need). Move the vertices or use the correction “Split into simple areas” in the Messages.',
    'El contorno del área “{n}” se cruza a sí mismo: el área calculada sale mal (y con ella la necesidad de agua). Mueva los vértices o use la corrección “Dividir en áreas simples” en los Mensajes.',
  ),
  // ---- the computed maximum lateral length (B, SUBDIV, LAYOUT)
  'latmax.title': ('Comprimento máximo da lateral', 'Longest lateral', 'Longitud máxima del lateral'),
  'latmax.variation': ('Variação de vazão admitida ao longo da lateral (%)', 'Flow variation allowed along the lateral (%)', 'Variación de caudal admitida a lo largo del lateral (%)'),
  'latmax.noLateral': (
    'Escolha a fita ou o emissor (e o tubo da lateral) para calcular o comprimento máximo.',
    'Choose the tape or the emitter (and the lateral pipe) to compute the longest lateral.',
    'Elija la cinta o el emisor (y la tubería del lateral) para calcular la longitud máxima.',
  ),
  'latmax.slope': ('Declive do terreno ao longo das laterais', 'Slope of the ground along the laterals', 'Pendiente del terreno a lo largo de los laterales'),
  'latmax.noTerrain': ('sem terreno: em nível', 'no terrain: level', 'sin terreno: a nivel'),
  'latmax.pipe': ('Tubo da lateral na estimativa', 'Lateral pipe of the estimate', 'Tubería del lateral en la estimación'),
  'latmax.none': ('nenhum emissor funciona nesses limites', 'no emitter works within these limits', 'ningún emisor funciona en esos límites'),
  'latmax.run': ('{l} · {n} emissores · entrada {p} · vazão ±{q}', '{l} · {n} emitters · inlet {p} · flow ±{q}', '{l} · {n} emisores · entrada {p} · caudal ±{q}'),
  'latmax.level': ('Lateral máxima (em nível)', 'Longest lateral (level)', 'Lateral máximo (a nivel)'),
  'latmax.uphill': ('Lateral máxima subindo', 'Longest lateral uphill', 'Lateral máximo en subida'),
  'latmax.downhill': ('Lateral máxima descendo', 'Longest lateral downhill', 'Lateral máximo en bajada'),
  'latmax.by.flowVariation': ('Limitada pela variação de vazão dos emissores.', 'Limited by the flow variation of the emitters.', 'Limitado por la variación de caudal de los emisores.'),
  'latmax.by.pressure': (
    'Limitada pela faixa de pressão do emissor (ou da fita).',
    'Limited by the pressure range of the emitter (or the tape).',
    'Limitado por el rango de presión del emisor (o de la cinta).',
  ),
  'latmax.by.velocity': ('Limitada pela velocidade máxima da água no tubo.', 'Limited by the highest water velocity in the pipe.', 'Limitado por la velocidad máxima del agua en la tubería.'),
  'latmax.by.maxLength': ('Sem limite prático até 1000 m.', 'No practical limit up to 1000 m.', 'Sin límite práctico hasta 1000 m.'),
  'latmax.by.none': ('Nenhum emissor fica dentro dos limites.', 'No emitter stays within the limits.', 'Ningún emisor queda dentro de los límites.'),
  'latmax.longest': ('Lateral mais longa do desenho', 'Longest lateral of the drawing', 'Lateral más largo del dibujo'),
  'latmax.tooLong': (
    'A lateral mais longa ({l}) passa do máximo calculado ({m}): alimente pelo meio, use um tubo ou fita de diâmetro maior, aceite mais variação ou divida o bloco.',
    'The longest lateral ({l}) is longer than the computed limit ({m}): feed it from the middle, use a larger pipe or tape, accept more variation or split the block.',
    'El lateral más largo ({l}) supera el máximo calculado ({m}): aliméntelo por el medio, use una tubería o cinta de mayor diámetro, acepte más variación o divida el bloque.',
  ),
  'latmax.use': ('Usar o máximo calculado ({l})', 'Use the computed limit ({l})', 'Usar el máximo calculado ({l})'),
  // ---- review of "fix automatically" and "optimise" item by item
  'adv.reviewHint': (
    'As correções já estão no desenho. Desmarque as que não quer: o projeto volta ao que era e só as marcadas são feitas de novo.',
    'The corrections are already on the drawing. Untick the ones you do not want: the project goes back to what it was and only the ticked ones are made again.',
    'Las correcciones ya están en el dibujo. Desmarque las que no quiere: el proyecto vuelve a como estaba y solo las marcadas se hacen de nuevo.',
  ),
  'opt.reviewHint': (
    'As mudanças já estão no projeto. Desmarque as que não quer: o projeto volta ao que era e só as marcadas são feitas de novo.',
    'The changes are already in the project. Untick the ones you do not want: the project goes back to what it was and only the ticked ones are made again.',
    'Los cambios ya están en el proyecto. Desmarque los que no quiere: el proyecto vuelve a como estaba y solo los marcados se hacen de nuevo.',
  ),
  'adv.keepChecked': ('Manter só as marcadas ({n})', 'Keep only the ticked ones ({n})', 'Mantener solo las marcadas ({n})'),
  'adv.keptNone': ('Nada foi mantido: o projeto está como era antes.', 'Nothing was kept: the project is as it was before.', 'No se mantuvo nada: el proyecto está como antes.'),
  'adv.keptSome': ('{n} correção(ões) mantida(s), {m} deixada(s) de fora.', '{n} correction(s) kept, {m} left out.', '{n} corrección(es) mantenida(s), {m} dejada(s) fuera.'),
  'opt.keptSome': (
    '{n} mudança(s) mantida(s), {m} deixada(s) de fora; custo anual {a} (antes {b}).',
    '{n} change(s) kept, {m} left out; annual cost {a} (before {b}).',
    '{n} cambio(s) mantenido(s), {m} dejado(s) fuera; costo anual {a} (antes {b}).',
  ),
  'adv.showOnDrawing': ('Mostrar no desenho', 'Show on the drawing', 'Mostrar en el dibujo'),
  // ---- the outline traced on the satellite image (PRD-05)
  'tool.traceImage': ('Contornar pela imagem', 'Trace on the image', 'Contornear por la imagen'),
  'hint.traceImage': (
    'Clique dentro de um talhão, gramado ou açude no mapa: o contorno sai da imagem de satélite. Enter (✓) cria a área, Esc descarta; digite um número para a tolerância, A ou P para área ou polilinha, V para todos os talhões da vista.',
    'Click inside a field, a lawn or a pond on the map: the outline comes from the satellite image. Enter (✓) makes the area, Esc drops it; type a number for the tolerance, A or P for an area or a polyline, V for every field of the view.',
    'Haga clic dentro de una parcela, un césped o una laguna en el mapa: el contorno sale de la imagen satelital. Enter (✓) crea el área, Esc la descarta; escriba un número para la tolerancia, A o P para área o polilínea, V para todas las parcelas de la vista.',
  ),
  'hist.traceImage': ('Contornar pela imagem ({n})', 'Trace on the image ({n})', 'Contornear por la imagen ({n})'),
  'wand.tracing': ('Contornando pela imagem de satélite…', 'Tracing on the satellite image…', 'Contorneando por la imagen satelital…'),
  'wand.noGeoref': (
    'O projeto não tem georreferência: defina-a (Arquivo → Georreferência) para ver a imagem de satélite.',
    'The project has no georeference: set it (File → Georeference) to see the satellite image.',
    'El proyecto no tiene georreferencia: defínala (Archivo → Georreferencia) para ver la imagen satelital.',
  ),
  'wand.noImagery': (
    'A imagem de satélite não carregou aqui (sem internet ou sem imagem nesta região): nada a contornar.',
    'The satellite image did not load here (offline, or no imagery in this region): nothing to trace.',
    'La imagen satelital no cargó aquí (sin internet o sin imagen en esta región): nada que contornear.',
  ),
  'wand.noData': (
    'O ponto está onde a imagem não tem dados: clique bem dentro da região.',
    'The point lies where the image has no data: click well inside the region.',
    'El punto está donde la imagen no tiene datos: haga clic bien dentro de la región.',
  ),
  'wand.tooSmall': (
    'A região tem só alguns pixels: clique bem dentro dela ou aumente a tolerância.',
    'The region is only a few pixels: click well inside it or raise the tolerance.',
    'La región tiene solo algunos píxeles: haga clic bien dentro de ella o aumente la tolerancia.',
  ),
  'wand.viewTooLarge': (
    'A vista passa de {m} m: aproxime o mapa para contornar os talhões dela.',
    'The view is wider than {m} m: zoom in to trace its fields.',
    'La vista supera {m} m: acerque el mapa para contornear sus parcelas.',
  ),
  'wand.failed': ('Não foi possível contornar: {m}', 'Could not trace: {m}', 'No se pudo contornear: {m}'),
  'wand.unclear': (
    'Sem borda nítida (as cores mudam aos poucos): confira e ajuste a tolerância.',
    'No clear boundary (the colours change gradually): check it and set the tolerance.',
    'Sin borde nítido (los colores cambian de a poco): revíselo y ajuste la tolerancia.',
  ),
  'wand.edge': (
    'A região chega à borda da área analisada: pode continuar além.',
    'The region reaches the edge of the area searched: it may go on beyond.',
    'La región llega al borde del área analizada: puede seguir más allá.',
  ),
  'wand.gaps': (
    'Parte da imagem não carregou: o contorno pode parar onde faltam blocos.',
    'Part of the image did not load: the outline may stop where tiles are missing.',
    'Parte de la imagen no cargó: el contorno puede detenerse donde faltan teselas.',
  ),
  'wand.holes': (
    '{n} buraco(s) dentro (árvores, construções, água) foram preenchidos.',
    '{n} hole(s) inside (trees, buildings, water) were filled.',
    '{n} hueco(s) dentro (árboles, construcciones, agua) se rellenaron.',
  ),
  'wand.onEdge': (
    'O clique parece estar numa borda: clique bem dentro da região.',
    'The click seems to lie on an edge: click well inside the region.',
    'El clic parece estar en un borde: haga clic bien dentro de la región.',
  ),
  'wand.traced': ('Contorno: {a}, {n} vértices, tolerância {t} ΔE.', 'Outline: {a}, {n} vertices, tolerance {t} ΔE.', 'Contorno: {a}, {n} vértices, tolerancia {t} ΔE.'),
  'wand.next': ('Enter (✓) cria, Esc descarta.', 'Enter (✓) makes it, Esc drops it.', 'Enter (✓) lo crea, Esc lo descarta.'),
  'wand.created': ('{n} contorno(s) adicionado(s) ao projeto.', '{n} outline(s) added to the project.', '{n} contorno(s) añadido(s) al proyecto.'),
  'wand.noFields': ('Nenhum talhão inteiro encontrado na vista.', 'No whole field found in the view.', 'No se encontró ninguna parcela entera en la vista.'),
  'wand.fieldsFound': ('{n} talhão(ões) na vista: Enter (✓) cria as áreas.', '{n} field(s) in the view: Enter (✓) makes the areas.', '{n} parcela(s) en la vista: Enter (✓) crea las áreas.'),
  'wand.output': ('O contorno vira', 'The outline becomes', 'El contorno se convierte en'),
  'wand.output.area': ('Área irrigada', 'Irrigated area', 'Área regada'),
  'wand.output.polyline': ('Polilinha fechada', 'Closed polyline', 'Polilínea cerrada'),
  'wand.tolerance': ('Tolerância de cor (ΔE; 0 = automática)', 'Colour tolerance (ΔE; 0 = automatic)', 'Tolerancia de color (ΔE; 0 = automática)'),
  'wand.blur': ('Suavização das cores (m; 3–6 em pomares)', 'Colour smoothing (m; 3–6 in orchards)', 'Suavizado de colores (m; 3–6 en huertos)'),
  'wand.detail': ('Simplificação do contorno (m; 0 = um pixel)', 'Outline simplification (m; 0 = a pixel)', 'Simplificación del contorno (m; 0 = un píxel)'),
  'wand.commit': ('Criar', 'Make it', 'Crear'),
  'wand.discard': ('Descartar', 'Drop', 'Descartar'),
  'wand.view': ('Todos os talhões da vista', 'Every field of the view', 'Todas las parcelas de la vista'),
  // ---- operations of the AI assistant
  'ai.op.max_lateral_length': ('Calcular o comprimento máximo da lateral', 'Compute the longest lateral', 'Calcular la longitud máxima del lateral'),
  'ai.op.preview_auto_fix': ('Prever as correções automáticas', 'Preview the automatic corrections', 'Previsualizar las correcciones automáticas'),
  'ai.op.auto_fix_selected': ('Aplicar {n} correção(ões) escolhida(s)', 'Apply {n} chosen correction(s)', 'Aplicar {n} corrección(es) elegida(s)'),
  'ai.op.preview_optimize': ('Prever as mudanças da otimização', 'Preview the changes of the optimisation', 'Previsualizar los cambios de la optimización'),
  'ai.op.optimize_selected': ('Otimizar mantendo {n} mudança(s)', 'Optimise keeping {n} change(s)', 'Optimizar manteniendo {n} cambio(s)'),
  'ai.op.outline_from_image': ('Contornar pela imagem de satélite', 'Trace on the satellite image', 'Contornear por la imagen satelital'),
  'ai.op.set_trench_depths': ('Mudar as profundidades padrão das valas', 'Change the default trench depths', 'Cambiar las profundidades por defecto de las zanjas'),
};
