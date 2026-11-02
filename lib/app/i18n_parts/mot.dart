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
};
