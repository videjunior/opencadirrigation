part of '../i18n.dart';

/// Strings added in 1.7.0 for the irrigation programme played on the plan
/// (the player over the drawing, the animation as a GIF, a frame as a PNG
/// and the programme as a calendar file): (pt, en, es), merged into the
/// table after the base strings (a key repeated in another part is a
/// compile-time error).
const _ply = <String, (String, String, String)>{
  // ---- menus and the player
  'ply.menu': ('Reproduzir o programa na planta…', 'Play the programme on the plan…', 'Reproducir el programa en el plano…'),
  'ply.title': ('Programa de rega na planta', 'Irrigation programme on the plan', 'Programa de riego en el plano'),
  'ply.play': ('Reproduzir', 'Play', 'Reproducir'),
  'ply.pause': ('Pausar', 'Pause', 'Pausar'),
  'ply.restart': ('Voltar ao início do ciclo', 'Back to the start of the cycle', 'Volver al inicio del ciclo'),
  'ply.next': ('Ir ao próximo início de turno', 'Go to the next start of a group', 'Ir al próximo inicio de turno'),
  'ply.speed': ('Velocidade (horas do programa por segundo)', 'Speed (hours of the programme per second)', 'Velocidad (horas del programa por segundo)'),
  'ply.idle': ('Sistema em repouso', 'System at rest', 'Sistema en reposo'),
  'ply.day': ('Dia {n}', 'Day {n}', 'Día {n}'),
  'ply.cycleDay': ('Ciclo de um dia: todo dia igual', 'One-day cycle: every day alike', 'Ciclo de un día: todos los días iguales'),
  'ply.cycleDays': ('Ciclo de {n} dias, depois o programa se repete', 'Cycle of {n} days, then the programme repeats', 'Ciclo de {n} días, luego el programa se repite'),
  'ply.cycleCut': (
    'O programa só se repete a cada {p} dias: aparecem os primeiros {n}.',
    'The programme repeats only every {p} days: the first {n} are shown.',
    'El programa solo se repite cada {p} días: se muestran los primeros {n}.',
  ),
  'ply.overlap': (
    'Turnos ao mesmo tempo: as vazões somadas, sem novo cálculo hidráulico',
    'Groups at the same time: their flows added, not solved together',
    'Turnos a la vez: caudales sumados, sin nuevo cálculo hidráulico',
  ),
  'ply.supplyP': ('Pressão na fonte', 'Pressure at the supply', 'Presión en la fuente'),
  'ply.pumpP': ('Pressão na saída da bomba', 'Pressure at the pump outlet', 'Presión a la salida de la bomba'),
  'ply.pumps': ('Bombas ligadas: {on} de {n}', 'Pumps on: {on} of {n}', 'Bombas encendidas: {on} de {n}'),
  'ply.dry': ('chega ao nível mínimo', 'reaches its lowest level', 'llega a su nivel mínimo'),
  'ply.spills': ('enche e verte', 'fills up and spills', 'se llena y vierte'),
  'ply.needResults': (
    'Calcule o projeto primeiro (F5): o reprodutor mostra as vazões, as pressões e as bombas dos resultados de cada turno.',
    'Run the design first (F5): the player shows the flows, pressures and pumps of the results of every group.',
    'Calcule el diseño primero (F5): el reproductor muestra los caudales, las presiones y las bombas de los resultados de cada turno.',
  ),
  'ply.noRuns': (
    'O programa de rega não tem nenhuma rega: ponha as zonas em turnos (Projeto → Turnos de operação) sobre áreas com cultura e clima, calcule o projeto e confira em Projeto → Agronomia → Programa de rega.',
    'The irrigation programme has no run: put the zones in system flows (Design → System flows) over areas with their crop and climate, run the design and check it in Design → Agronomy → Irrigation programme.',
    'El programa de riego no tiene ningún riego: ponga las zonas en turnos (Diseño → Turnos de operación) sobre áreas con cultivo y clima, calcule el diseño y revíselo en Diseño → Agronomía → Programa de riego.',
  ),
  'ply.stale': (
    'O projeto mudou: calcule de novo (F5) para reproduzir o programa.',
    'The design changed: run it again (F5) to play the programme.',
    'El diseño cambió: calcúlelo de nuevo (F5) para reproducir el programa.',
  ),
  // ---- exports
  'ply.png': ('Quadro (PNG)', 'Frame (PNG)', 'Cuadro (PNG)'),
  'ply.gif': ('Animação (GIF)…', 'Animation (GIF)…', 'Animación (GIF)…'),
  'ply.ics': ('Calendário (.ics)…', 'Calendar (.ics)…', 'Calendario (.ics)…'),
  'ply.file': ('programa_rega', 'irrigation_programme', 'programa_riego'),
  'ply.gif.title': ('Exportar a animação do programa (GIF)', 'Export the animation of the programme (GIF)', 'Exportar la animación del programa (GIF)'),
  'ply.gif.hint': (
    'A animação passa pelo ciclo do programa, um quadro a cada intervalo e um em cada rega curta, com o relógio, a vazão e a pressão. O tamanho padrão cabe numa mensagem de celular.',
    'The animation runs through the cycle of the programme, a frame at every step and one in every short run, with the clock, the flow and the pressure. The default size fits a phone message.',
    'La animación recorre el ciclo del programa, un cuadro en cada paso y uno en cada riego corto, con el reloj, el caudal y la presión. El tamaño por defecto cabe en un mensaje de celular.',
  ),
  'ply.gif.size': ('Lado maior (px)', 'Longest side (px)', 'Lado mayor (px)'),
  'ply.gif.frames': ('Quadros', 'Frames', 'Cuadros'),
  'ply.gif.map': ('Com o mapa de fundo (baixa os mosaicos do mapa)', 'With the base map (downloads the map tiles)', 'Con el mapa de fondo (descarga los mosaicos del mapa)'),
  'ply.gif.progress': ('Desenhando o quadro {n} de {of}…', 'Drawing frame {n} of {of}…', 'Dibujando el cuadro {n} de {of}…'),
  'ply.gif.done': ('Exportado: {f} ({kb} KB, {n} quadros)', 'Exported: {f} ({kb} KB, {n} frames)', 'Exportado: {f} ({kb} KB, {n} cuadros)'),
  'ply.gif.cancelled': ('Exportação da animação cancelada', 'Export of the animation cancelled', 'Exportación de la animación cancelada'),
  'ply.ics.title': ('Exportar o programa como calendário (.ics)', 'Export the programme as a calendar (.ics)', 'Exportar el programa como calendario (.ics)'),
  'ply.ics.hint': (
    'Um evento por início de cada turno, na hora local, com as zonas e o tempo de rega, repetindo nos dias do programa a partir de hoje. Abra o arquivo no celular para pôr a rega na agenda.',
    'One event per start of every group, at local time, with its zones and run time, repeating on the days of the programme from today. Open the file on the phone to put the irrigation in its calendar.',
    'Un evento por inicio de cada turno, a la hora local, con sus zonas y el tiempo de riego, repitiendo en los días del programa desde hoy. Abra el archivo en el celular para poner el riego en su agenda.',
  ),
  'ply.ics.days': ('Repetir por (dias)', 'Repeat for (days)', 'Repetir durante (días)'),
  'ply.ics.done': ('Exportado: {f} ({n} eventos)', 'Exported: {f} ({n} events)', 'Exportado: {f} ({n} eventos)'),
  // ---- the calendar file ({p} project, {flow} system flow, {t} run time, {m} month)
  'ply.ics.name': ('Rega – {p}', 'Irrigation – {p}', 'Riego – {p}'),
  'ply.ics.summary': ('Rega: {flow}', 'Irrigation: {flow}', 'Riego: {flow}'),
  'ply.ics.runTime': ('Tempo de rega: {t}', 'Run time: {t}', 'Tiempo de riego: {t}'),
  'ply.ics.cycle': ('Ciclo {n} de {of} (ciclo e pausa)', 'Cycle {n} of {of} (cycle and soak)', 'Ciclo {n} de {of} (ciclo y pausa)'),
  'ply.ics.designMonth': ('Tempos do mês de projeto de cada área', 'Run times of the design month of each area', 'Tiempos del mes de diseño de cada área'),
  'ply.ics.month': ('Tempos de rega de {m}', 'Run times of {m}', 'Tiempos de riego de {m}'),
  'ply.ics.from': (
    'Programa de rega do projeto {p}, feito no OpenCADIrrigation',
    'Irrigation programme of the project {p}, made with OpenCADIrrigation',
    'Programa de riego del proyecto {p}, hecho con OpenCADIrrigation',
  ),
  // ---- the assistant's approval lines
  'ai.op.programme_picture': ('Ver a planta em {n} do programa de rega', 'Look at the plan at {n} of the irrigation programme', 'Ver el plano en {n} del programa de riego'),
  'ai.op.export_programme_animation': ('Exportar o programa de rega na planta ({n})', 'Export the irrigation programme on the plan ({n})', 'Exportar el programa de riego en el plano ({n})'),
  'ai.op.export_programme_calendar': ('Exportar o programa de rega como calendário', 'Export the irrigation programme as a calendar', 'Exportar el programa de riego como calendario'),
};
