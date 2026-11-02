part of '../i18n.dart';

/// Strings added in 1.6.0 for automatic design and the design assistant: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _aut = <String, (String, String, String)>{
  // ---- live summaries of the automatic tools
  'auto.step.layout': ('Distribuindo os aspersores…', 'Laying out the heads…', 'Distribuyendo los aspersores…'),
  'auto.step.zoning': ('Agrupando em zonas…', 'Grouping into zones…', 'Agrupando en zonas…'),
  'auto.step.routing': ('Traçando os tubos: zona {n} de {m}…', 'Routing the pipes: zone {n} of {m}…', 'Trazando las tuberías: zona {n} de {m}…'),
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
};
