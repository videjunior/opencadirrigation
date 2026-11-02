part of '../i18n.dart';

/// Strings added in 1.6.0 for engine and hydraulic analyses: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _mot = <String, (String, String, String)>{
  // ---- zone held by a PRV, PSV or FCV (MOT-06)
  'warn.zone_pressure_unreachable': (
    'Os emissores do setor não chegam à pressão nominal: um regulador do setor segura a pressão',
    'The zone emitters cannot reach their nominal pressure: a regulating device of the zone holds the pressure',
    'Los emisores del sector no llegan a la presión nominal: un regulador del sector retiene la presión',
  ),
  'adv.zone_pressure_unreachable.why': (
    'Uma válvula redutora (PRV), sustentadora (PSV) ou limitadora de vazão (FCV) dentro do setor não deixa a pressão dos emissores subir até a nominal, por mais pressão que a válvula do setor receba. A análise usa a menor pressão na válvula que já dá ao setor tudo o que ele pode receber.',
    'A pressure reducing (PRV), pressure sustaining (PSV) or flow control valve (FCV) inside the zone keeps the emitter pressure below nominal however much pressure the zone valve gets. The analysis takes the lowest valve pressure that already gives the zone all it can get.',
    'Una válvula reductora (PRV), sostenedora (PSV) o limitadora de caudal (FCV) dentro del sector no deja que la presión de los emisores suba hasta la nominal, por más presión que reciba la válvula del sector. El análisis usa la menor presión en la válvula que ya da al sector todo lo que puede recibir.',
  ),
  'adv.zone_pressure_unreachable.how': (
    'Ajuste a pressão (ou a vazão) do regulador acima da necessidade dos emissores mais as perdas depois dele, ou aumente os tubos entre o regulador e os emissores.',
    'Set the regulator pressure (or flow) above what the emitters need plus the losses after it, or enlarge the pipes between the regulator and the emitters.',
    'Ajuste la presión (o el caudal) del regulador por encima de lo que necesitan los emisores más las pérdidas después de él, o agrande las tuberías entre el regulador y los emisores.',
  ),
  // ---- pump operating range (MOT-11)
  'warn.pump_below_min_flow': (
    'Bomba abaixo da vazão mínima da curva (perto do fechamento)',
    'Pump below the minimum flow of its curve (close to shut-off)',
    'Bomba por debajo del caudal mínimo de su curva (cerca del cierre)',
  ),
  'adv.pump_below_min_flow.why': (
    'A bomba trabalha com menos vazão que a mínima do fabricante (na rotação em que gira): perto do fechamento a água recircula no rotor, esquenta e a bomba vibra, com rendimento baixo.',
    'The pump runs below the manufacturer\'s minimum flow (at the speed it turns): near shut-off the water recirculates in the impeller, heats up and the pump vibrates, at a poor efficiency.',
    'La bomba trabaja con menos caudal que el mínimo del fabricante (a la velocidad a la que gira): cerca del cierre el agua recircula en el rodete, se calienta y la bomba vibra, con bajo rendimiento.',
  ),
  'adv.pump_below_min_flow.how': (
    'Escolha uma bomba menor, junte mais setores no turno, use um inversor de frequência ou uma derivação de recirculação.',
    'Choose a smaller pump, open more zones in the system flow, use a variable-speed drive or a bypass line.',
    'Elija una bomba más pequeña, junte más sectores en el turno, use un variador de frecuencia o una derivación de recirculación.',
  ),
  // ---- LP sizing that stops at its iteration limit (MOT-08)
  'warn.lp_iteration_limit': (
    'LP interrompido no limite de iterações (método guloso usado)',
    'LP stopped at its iteration limit (greedy method used)',
    'LP detenido en el límite de iteraciones (se usó el método voraz)',
  ),
  'adv.lp_iteration_limit.why': (
    'O dimensionamento por programação linear parou no limite de iterações antes de achar a solução: isso não quer dizer que não haja solução. O programa usou o método guloso (aumenta os tubos passo a passo), que dá um bom resultado, mas talvez não o mais barato.',
    'The linear-programming sizing stopped at its iteration limit before it found the solution: that does not mean there is none. The program used the greedy method (upsizing step by step), which gives a good result but perhaps not the cheapest.',
    'El dimensionamiento por programación lineal se detuvo en el límite de iteraciones antes de hallar la solución: eso no quiere decir que no haya solución. El programa usó el método voraz (aumenta las tuberías paso a paso), que da un buen resultado, pero quizá no el más barato.',
  ),
  'adv.lp_iteration_limit.how': (
    'Divida o setor ou a linha principal em partes menores, ou habilite menos diâmetros candidatos no catálogo para o uso.',
    'Split the zone or the mainline into smaller parts, or enable fewer candidate diameters in the catalogue for the use.',
    'Divida el sector o la línea principal en partes menores, o habilite menos diámetros candidatos en el catálogo para el uso.',
  ),
  // ---- zone whose ground alone exceeds the pressure window (MOT-09)
  'warn.zone_slope_exceeds_window': (
    'O desnível do setor sozinho passa da janela de pressão dos emissores',
    'The elevation range of the zone alone exceeds the emitter pressure window',
    'El desnivel del sector por sí solo supera la ventana de presión de los emisores',
  ),
  'adv.zone_slope_exceeds_window.why': (
    'A diferença de cota entre os emissores mais alto e mais baixo do setor é maior que a faixa de pressão permitida: mesmo sem perda nenhuma nos tubos, uns ficariam fora da janela. Tubos maiores não resolvem, por isso o programa manteve os tubos mais baratos.',
    'The elevation difference between the highest and the lowest emitter of the zone is larger than the allowed pressure range: even with no loss at all in the pipes some would be outside the window. Larger pipes do not help, so the program kept the cheaper pipes.',
    'La diferencia de cota entre el emisor más alto y el más bajo del sector es mayor que el rango de presión permitido: aun sin pérdida alguna en las tuberías, algunos quedarían fuera de la ventana. Tuberías mayores no lo resuelven, por eso el programa mantuvo las tuberías más baratas.',
  ),
  'adv.zone_slope_exceeds_window.how': (
    'Use emissores autocompensantes, ponha as linhas laterais em nível (seguindo as curvas), divida o setor por faixas de cota ou instale reguladores de pressão nas laterais.',
    'Use pressure-compensating emitters, lay the laterals along the contours, split the zone by elevation bands or fit pressure regulators on the laterals.',
    'Use emisores autocompensantes, ponga las laterales a nivel (siguiendo las curvas), divida el sector por franjas de cota o instale reguladores de presión en las laterales.',
  ),
  // ---- surge screening over the water path (MOT-10)
  'rep.surgePath': ('Caminho da onda (triagem; ver estudo de transientes)', 'Wave path (screening; see the transient study)', 'Camino de la onda (estimación; ver el estudio de transitorios)'),
  // ---- pipe below the atmosphere (MOT-12)
  'warn.pressure_below_atmospheric': (
    'Pressão abaixo da atmosférica no tubo (linha piezométrica abaixo do tubo)',
    'Pressure below the atmosphere in the pipe (hydraulic grade line below the pipe)',
    'Presión por debajo de la atmosférica en la tubería (línea piezométrica por debajo del tubo)',
  ),
  'adv.pressure_below_atmospheric.why': (
    'Num ponto alto do traçado a linha de energia passa abaixo do tubo: a água corre em sifão, com vácuo. O ar sai da água e se acumula, a vazão cai ou para, e um tubo de parede fina (PE, PVC de classe baixa) pode amassar.',
    'At a high point of the route the hydraulic grade line runs below the pipe: the water flows as a siphon, under vacuum. Air comes out of the water and gathers, the flow falls or stops, and a thin-walled pipe (PE, low-class PVC) may collapse.',
    'En un punto alto del trazado la línea de energía pasa por debajo del tubo: el agua corre en sifón, con vacío. El aire sale del agua y se acumula, el caudal cae o se detiene, y una tubería de pared delgada (PE, PVC de clase baja) puede aplastarse.',
  ),
  'adv.pressure_below_atmospheric.how': (
    'Dê mais pressão na fonte (ou uma bomba antes do ponto alto), desvie o traçado do morro ou aumente o tubo antes dele para perder menos carga; ponha uma ventosa no ponto alto.',
    'Give the supply more pressure (or a pump before the high point), route the line around the hill or enlarge the pipe before it to lose less head; fit an air valve at the high point.',
    'Dé más presión en la fuente (o una bomba antes del punto alto), desvíe el trazado del cerro o agrande la tubería antes de él para perder menos carga; ponga una ventosa en el punto alto.',
  ),
  // ---- surplus at a valve that does not regulate (MOT-13)
  'warn.valve_pressure_excess': (
    'Pressão de sobra numa válvula de setor que não regula',
    'Surplus pressure at a zone valve that does not regulate',
    'Presión de sobra en una válvula de sector que no regula',
  ),
  'adv.valve_pressure_excess.why': (
    'A linha principal entrega na válvula bem mais pressão que o setor precisa (mais de 5 m e de 20 %). Uma válvula solenoide comum não segura a pressão: o setor trabalha acima da pressão de projeto, os emissores dão mais vazão, e a vazão da linha e a da bomba mudam.',
    'The mainline delivers far more pressure at the valve than the zone needs (more than 5 m and 20 %). A plain solenoid valve does not hold the pressure: the zone runs above its design pressure, the emitters give more flow, and so the flow of the line and of the pump change.',
    'La línea principal entrega en la válvula mucha más presión que la que el sector necesita (más de 5 m y del 20 %). Una válvula solenoide común no retiene la presión: el sector trabaja por encima de su presión de diseño, los emisores dan más caudal, y el caudal de la línea y el de la bomba cambian.',
  ),
  'adv.valve_pressure_excess.how': (
    'Use uma válvula reguladora de pressão (com piloto redutor) ou informe a pressão de saída na válvula, ou ponha um regulador na entrada do setor.',
    'Use a pressure regulating valve (with a reducing pilot) or set the outlet pressure of the valve, or fit a regulator at the inlet of the zone.',
    'Use una válvula reguladora de presión (con piloto reductor) o indique la presión de salida de la válvula, o ponga un regulador a la entrada del sector.',
  ),
  // ---- motor and drive efficiency of a pump (MOT-15)
  'props.motorEfficiency': ('Rendimento do motor e do inversor (0–1)', 'Motor and drive efficiency (0–1)', 'Rendimiento del motor y del variador (0–1)'),
};
