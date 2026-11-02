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
};
