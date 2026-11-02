part of '../i18n.dart';

/// Strings added in 1.6.0 for the drawing and editing tools: (pt, en, es),
/// merged into the table after the base strings (a key repeated in another
/// part is a compile-time error).
const _edt = <String, (String, String, String)>{
  // ---- move and copy by base point (CAD-06)
  'tool.move': ('Mover', 'Move', 'Mover'),
  // (the clipboard copy of the Edit menu is "Copiar" too: this one says how it works)
  'tool.copy': ('Copiar com ponto-base', 'Copy with base point', 'Copiar con punto base'),
  'hint.move': (
    'Seleção: clique no ponto-base e no destino, ou digite @dx,dy, @d<ângulo ou a distância (Ctrl = copiar)',
    'Selection: click the base point and the destination, or type @dx,dy, @d<angle or the distance (Ctrl = copy)',
    'Selección: clic en el punto base y en el destino, o escriba @dx,dy, @d<ángulo o la distancia (Ctrl = copiar)',
  ),
  'hint.copy': (
    'Seleção: clique no ponto-base e em cada destino, ou digite @dx,dy, @d<ângulo ou a distância; Esc ou Enter termina',
    'Selection: click the base point and each destination, or type @dx,dy, @d<angle or the distance; Esc or Enter ends',
    'Selección: clic en el punto base y en cada destino, o escriba @dx,dy, @d<ángulo o la distancia; Esc o Intro termina',
  ),
  // ---- coordinates in the properties panel (CAD-06)
  'xy.position': ('Posição', 'Position', 'Posición'),
  'xy.start': ('Início', 'Start', 'Inicio'),
  'xy.end': ('Fim', 'End', 'Fin'),
  'xy.center': ('Centro', 'Centre', 'Centro'),
  'xy.vertices': ('Vértices', 'Vertices', 'Vértices'),
  'xy.vertex': ('Vértice {n}', 'Vertex {n}', 'Vértice {n}'),
  'xy.more': ('… mais {n} vértices: arraste as alças na prancheta', '… {n} more vertices: drag the grips on the drawing', '… {n} vértices más: arrastre los pinzamientos en el dibujo'),
  // ---- values typed at the step of a tool (CAD-09)
  'edt.typeAngle': (
    'Digite o ângulo em graus e Enter, ou clique no ponto de referência',
    'Type the angle in degrees and press Enter, or click the reference point',
    'Escriba el ángulo en grados y pulse Intro, o haga clic en el punto de referencia',
  ),
  'edt.typeFactor': (
    'Digite o fator de escala e Enter, ou clique no ponto de referência',
    'Type the scale factor and press Enter, or click the reference point',
    'Escriba el factor de escala y pulse Intro, o haga clic en el punto de referencia',
  ),
  'edt.typeDistance': ('digite outra distância e Enter', 'type another distance and press Enter', 'escriba otra distancia y pulse Intro'),
  'edt.offsetSet': ('Distância do offset: {d}', 'Offset distance: {d}', 'Distancia del desfase: {d}'),
  'edt.badValue': ('Valor inválido: digite um número maior que zero', 'Invalid value: type a number greater than zero', 'Valor no válido: escriba un número mayor que cero'),
  // ---- polyline in progress (CAD-10)
  'edt.closeNeeds3': ('Para fechar, clique ao menos 3 pontos', 'Click at least 3 points to close', 'Haga clic en al menos 3 puntos para cerrar'),
  // ---- several items on a touch screen (CAD-17)
  'sel.addMode': ('Somar à seleção', 'Add to selection', 'Añadir a la selección'),
  'sel.addModeOn': (
    'Somar à seleção: cada toque soma um item; tocar num item selecionado o retira',
    'Add to selection: each tap adds an item; tapping a selected item takes it out',
    'Añadir a la selección: cada toque añade un elemento; tocar uno seleccionado lo quita',
  ),
  'sel.addModeOff': ('Cada toque substitui a seleção', 'Each tap replaces the selection', 'Cada toque reemplaza la selección'),
  // ---- selection by what the items are (CAD-25)
  'sel.menu': ('Selecionar', 'Select', 'Seleccionar'),
  'sel.similar': ('Selecionar semelhantes', 'Select similar', 'Seleccionar similares'),
  'sel.similarDone': ('{n} itens semelhantes selecionados', '{n} similar items selected', '{n} elementos similares seleccionados'),
  'sel.quick': ('Seleção rápida…', 'Quick select…', 'Selección rápida…'),
  'sel.layer': ('Selecionar tudo na camada atual', 'Select all on the current layer', 'Seleccionar todo en la capa actual'),
  'sel.onLayer': ('Selecionar os itens desta camada', 'Select the items of this layer', 'Seleccionar los elementos de esta capa'),
  'sel.layerHidden': ('A camada está oculta', 'The layer is hidden', 'La capa está oculta'),
  'sel.lassoCrossing': ('Pegar também o que o laço cruza', 'Also take what the lasso crosses', 'Tomar también lo que cruza el lazo'),
  'tool.lasso': ('Selecionar por laço', 'Lasso selection', 'Selección por lazo'),
  'tool.fence': ('Selecionar por cerca', 'Fence selection', 'Selección por cerco'),
  'hint.lasso': (
    'Arraste em volta dos itens, ou clique nos vértices e Enter; Shift soma à seleção',
    'Drag around the items, or click the vertices and press Enter; Shift adds to the selection',
    'Arrastre alrededor de los elementos, o haga clic en los vértices y pulse Intro; Mayús añade a la selección',
  ),
  'hint.fence': (
    'Clique nos pontos da cerca e Enter: seleciona o que ela cruza; Shift soma à seleção',
    'Click the points of the fence and press Enter: selects what it crosses; Shift adds to the selection',
    'Haga clic en los puntos del cerco y pulse Intro: selecciona lo que cruza; Mayús añade a la selección',
  ),
  'qs.title': ('Seleção rápida', 'Quick select', 'Selección rápida'),
  'qs.kind': ('Tipo de item', 'Kind of item', 'Tipo de elemento'),
  'qs.any': ('Qualquer', 'Any', 'Cualquiera'),
  'qs.spec': ('Item do catálogo', 'Catalogue item', 'Elemento del catálogo'),
  'qs.property': ('Faixa de valor', 'Range of a value', 'Rango de un valor'),
  'qs.prop.none': ('Nenhuma', 'None', 'Ninguno'),
  'qs.prop.length': ('Comprimento', 'Length', 'Longitud'),
  'qs.prop.area': ('Área', 'Area', 'Área'),
  'qs.prop.elevation': ('Elevação', 'Elevation', 'Elevación'),
  'qs.prop.head': ('Pressão', 'Pressure', 'Presión'),
  'qs.prop.diameter': ('Diâmetro interno', 'Inner diameter', 'Diámetro interior'),
  'qs.min': ('Mínimo', 'Minimum', 'Mínimo'),
  'qs.max': ('Máximo', 'Maximum', 'Máximo'),
  'qs.mode': ('O que fazer com eles', 'What to do with them', 'Qué hacer con ellos'),
  'qs.mode.replace': ('Substituir a seleção', 'Replace the selection', 'Reemplazar la selección'),
  'qs.mode.add': ('Somar à seleção', 'Add to the selection', 'Añadir a la selección'),
  'qs.mode.remove': ('Retirar da seleção', 'Take them out of the selection', 'Quitarlos de la selección'),
  'qs.mode.within': ('Manter só eles na seleção atual', 'Keep only them in the current selection', 'Dejar solo ellos en la selección actual'),
  'qs.matches': ('{n} itens atendem', '{n} items match', '{n} elementos cumplen'),
  'qs.apply': ('Selecionar', 'Select', 'Seleccionar'),
};
