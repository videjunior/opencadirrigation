part of '../i18n.dart';

/// Strings added in 1.6.0 for automatic design and the design assistant: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _aut = <String, (String, String, String)>{
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
  // ---- templates
  'warn.template_centreline_turn': (
    'A linha central volta sobre si mesma (curva de mais de 150°): desenhe o fairway em dois trechos',
    'The centreline turns back on itself (a bend of more than 150°): draw the fairway as two stretches',
    'La línea central vuelve sobre sí misma (curva de más de 150°): dibuje el fairway en dos tramos',
  ),
};
