part of '../i18n.dart';

/// Strings added in 1.6.0 for engine and hydraulic analyses: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _mot = <String, (String, String, String)>{
  // 1.6.0 MOT+ (wave 2): the parts below, each in a map of its own
  ..._motReservoir,
  ..._motScenarios,
  ..._motPlus,
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

/// 1.6.0 MOT+: reservoirs and dams drawn in the project, their
/// stage–area–volume curve, and the air vessel (PRD-16, PRD-31).
const _motReservoir = <String, (String, String, String)>{
  // ---- reservoir or dam behind a water supply (PRD-16)
  'res.title': ('Reservatório ou açude', 'Reservoir or dam', 'Embalse o represa'),
  'res.edit': ('Reservatório ou açude…', 'Reservoir or dam…', 'Embalse o represa…'),
  'res.none': ('Nenhum (nível fixo)', 'None (fixed level)', 'Ninguno (nivel fijo)'),
  'res.set': ('Definido', 'Set', 'Definido'),
  'res.noOutline': ('Sem contorno fechado', 'No closed outline', 'Sin contorno cerrado'),
  'res.hint': (
    'A fonte tira a água de um reservatório ou açude: escolha a polilinha fechada ou a área que marca a água no nível cheio. O volume sai do modelo do terreno (o chão dentro do contorno, num açude; o fundo plano com os taludes, num reservatório escavado). O projeto bombeia do nível mínimo; a simulação de 24 horas deixa o nível baixar com o que a fonte entrega e subir com a vazão que entra.',
    'The supply takes its water from a reservoir or dam: choose the closed polyline or the area that marks the water at the full level. The volume comes from the terrain model (the ground inside the outline for a dam; the flat bottom with its side slopes for an excavated reservoir). The design pumps from the lowest level; the 24-hour simulation lets the level fall with what the supply delivers and rise with the inflow.',
    'La fuente toma el agua de un embalse o represa: elija la polilínea cerrada o el área que marca el agua en el nivel lleno. El volumen sale del modelo del terreno (el suelo dentro del contorno en una represa; el fondo plano con los taludes en un embalse excavado). El proyecto bombea desde el nivel mínimo; la simulación de 24 horas deja bajar el nivel con lo que la fuente entrega y subir con el caudal que entra.',
  ),
  'res.outline': ('Contorno (nível cheio)', 'Outline (full level)', 'Contorno (nivel lleno)'),
  'res.kind': ('Tipo', 'Kind', 'Tipo'),
  'res.kind.terrain': ('Açude ou lagoa (fundo do terreno)', 'Dam or pond (the ground is the bottom)', 'Represa o laguna (fondo del terreno)'),
  'res.kind.excavated': ('Escavado (fundo plano e taludes)', 'Excavated (flat bottom and side slopes)', 'Excavado (fondo plano y taludes)'),
  'res.full': ('Cota do nível cheio', 'Full level elevation', 'Cota del nivel lleno'),
  'res.min': ('Cota do nível mínimo (0 = o fundo)', 'Lowest level elevation (0 = the bottom)', 'Cota del nivel mínimo (0 = el fondo)'),
  'res.initial': ('Cota no início do dia (0 = cheio)', 'Elevation at the start of the day (0 = full)', 'Cota al inicio del día (0 = lleno)'),
  'res.bottom': ('Cota do fundo (0 = 3 m abaixo do cheio)', 'Bottom elevation (0 = 3 m below full)', 'Cota del fondo (0 = 3 m bajo el lleno)'),
  'res.slope': ('Talude (horizontal por vertical)', 'Side slope (horizontal per vertical)', 'Talud (horizontal por vertical)'),
  'res.inflow': ('Vazão que entra', 'Inflow', 'Caudal que entra'),
  'res.study': ('Cota, área e volume', 'Elevation, area and volume', 'Cota, área y volumen'),
  'res.bottomFound': ('Fundo', 'Bottom', 'Fondo'),
  'res.surface': ('Área do espelho', 'Water surface', 'Área del espejo'),
  'res.volume': ('Volume', 'Volume', 'Volumen'),
  'res.usable': ('Volume útil (do mínimo ao cheio)', 'Usable volume (lowest to full)', 'Volumen útil (del mínimo al lleno)'),
  'res.cut': ('Volume de corte (escavação)', 'Cut volume (excavation)', 'Volumen de corte (excavación)'),
  'res.daily': ('Água tirada por dia (turnos do projeto)', 'Water drawn a day (system flows of the design)', 'Agua extraída por día (turnos del proyecto)'),
  'res.needDesign': ('calcule o projeto', 'run the design', 'calcule el proyecto'),
  'res.autonomy': ('Dias de demanda (com a vazão que entra)', 'Days of demand (with the inflow)', 'Días de demanda (con el caudal que entra)'),
  'res.fill': ('Tempo para encher o volume útil', 'Time to fill the usable volume', 'Tiempo para llenar el volumen útil'),
  'res.level': ('Nível do reservatório', 'Reservoir level', 'Nivel del embalse'),
  'res.remove': ('Tirar o reservatório', 'Remove the reservoir', 'Quitar el embalse'),
  'hist.reservoir': ('Reservatório', 'Reservoir', 'Embalse'),
  'warn.reservoir_no_outline': ('Reservatório sem contorno fechado', 'Reservoir without a closed outline', 'Embalse sin contorno cerrado'),
  'warn.reservoir_full_below_bottom': (
    'O nível cheio do reservatório está abaixo do fundo',
    'The full level of the reservoir is below its bottom',
    'El nivel lleno del embalse está por debajo del fondo',
  ),
  'warn.eps_reservoir_empty': ('O reservatório esvaziou durante o dia', 'The reservoir ran dry during the day', 'El embalse se vació durante el día'),
  'warn.eps_reservoir_full': ('O reservatório encheu e verteu durante o dia', 'The reservoir filled and spilled during the day', 'El embalse se llenó y vertió durante el día'),
  'ai.op.set_reservoir': ('Definir o reservatório da fonte {n}', 'Set the reservoir of the supply {n}', 'Definir el embalse de la fuente {n}'),
  'ai.op.reservoir_study': ('Ler a curva cota–área–volume do reservatório', 'Read the stage–area–volume curve of the reservoir', 'Leer la curva cota–área–volumen del embalse'),
  // ---- air vessel at a junction of the mainline (PRD-31)
  'vessel.item': ('Vaso de ar (reservatório hidropneumático)', 'Air vessel (hydropneumatic tank)', 'Depósito hidroneumático (calderín)'),
  'vessel.volume': ('Vaso de ar: volume (L; 0 = nenhum)', 'Air vessel: volume (L; 0 = none)', 'Depósito hidroneumático: volumen (L; 0 = ninguno)'),
  'vessel.gas': ('Vaso de ar: ar em regime (L; 0 = um terço)', 'Air vessel: gas in the steady state (L; 0 = a third)', 'Depósito hidroneumático: aire en régimen (L; 0 = un tercio)'),
  'vessel.connection': ('Vaso de ar: diâmetro da ligação (mm)', 'Air vessel: connection bore (mm)', 'Depósito hidroneumático: diámetro de la conexión (mm)'),
  'vessel.cost': ('Vaso de ar: preço', 'Air vessel: price', 'Depósito hidroneumático: precio'),
};

/// 1.6.0 MOT+: ageing and clogging scenarios against the new design, and
/// the progress and cancel of the network analyses (UI-19).
const _motScenarios = <String, (String, String, String)>{
  'life.menu': ('O projeto ao longo da vida (envelhecimento e entupimento)…', 'The design over its life (ageing and clogging)…', 'El proyecto a lo largo de su vida (envejecimiento y obstrucción)…'),
  'life.title': ('O projeto ao longo da vida', 'The design over its life', 'El proyecto a lo largo de su vida'),
  'life.hint': (
    'O projeto calculado é analisado de novo, com os mesmos tubos, depois de anos de uso: os tubos mais rugosos (o C de Hazen-Williams caindo tantos pontos por ano, a rugosidade de Darcy-Weisbach crescendo) e os emissores parcialmente entupidos (menos vazão e mais variação), lado a lado com o projeto novo. Mostra a folga do projeto; nada no projeto muda.',
    'The designed project is analysed again, with the same pipes, after years of use: the pipes rougher (the Hazen-Williams C falling so many points a year, the Darcy-Weisbach roughness growing) and the emitters partly clogged (less flow and more variation), side by side with the new design. It shows the margin of the design; nothing in the project changes.',
    'El proyecto calculado se analiza de nuevo, con las mismas tuberías, tras años de uso: las tuberías más rugosas (la C de Hazen-Williams cayendo tantos puntos por año, la rugosidad de Darcy-Weisbach creciendo) y los emisores parcialmente obstruidos (menos caudal y más variación), junto al proyecto nuevo. Muestra el margen del proyecto; nada en el proyecto cambia.',
  ),
  'life.years': ('Anos de uso', 'Years of use', 'Años de uso'),
  'life.cLoss': ('Perda de C por ano', 'C lost a year', 'Pérdida de C por año'),
  'life.roughness': ('Rugosidade ganha por ano (mm)', 'Roughness gained a year (mm)', 'Rugosidad ganada por año (mm)'),
  'life.clogging': ('Vazão perdida no entupimento (%)', 'Flow lost to clogging (%)', 'Caudal perdido por obstrucción (%)'),
  'life.cv': ('Aumento do CV de fabricação', 'Rise of the manufacturing CV', 'Aumento del CV de fabricación'),
  'life.run': ('Comparar', 'Compare', 'Comparar'),
  'life.case.asNew': ('Novo', 'New', 'Nuevo'),
  'life.case.aged': ('Envelhecido', 'Aged', 'Envejecido'),
  'life.case.clogged': ('Entupido', 'Clogged', 'Obstruido'),
  'life.case.agedClogged': ('Envelhecido e entupido', 'Aged and clogged', 'Envejecido y obstruido'),
  'life.peakFlow': ('Maior vazão de turno', 'Largest system flow', 'Mayor caudal de turno'),
  'life.minPressure': ('Menor pressão nos emissores', 'Lowest emitter pressure', 'Menor presión en los emisores'),
  'life.maxPressure': ('Maior pressão nos emissores', 'Highest emitter pressure', 'Mayor presión en los emisores'),
  'life.outOfWindow': ('Setores fora da faixa de pressão', 'Zones out of their pressure window', 'Sectores fuera del rango de presión'),
  'life.deficit': ('Maior falta de pressão numa válvula', 'Largest pressure a valve lacks', 'Mayor falta de presión en una válvula'),
  'life.supplyHead': ('Pressão que as fontes precisam dar', 'Pressure the supplies must give', 'Presión que deben dar las fuentes'),
  'life.pumpHead': ('Maior altura de bomba', 'Highest pump head', 'Mayor altura de bomba'),
  'life.energy': ('Energia por ano', 'Energy a year', 'Energía por año'),
  'life.note.life_no_design': (
    'Calcule o projeto primeiro: a comparação parte dos tubos do projeto.',
    'Run the design first: the comparison starts from the pipes of the design.',
    'Calcule el proyecto primero: la comparación parte de las tuberías del proyecto.',
  ),
  'life.note.life_method_not_aged': (
    'Com Scobey ou Manning a perda nos tubos não envelhece aqui (só o C de Hazen-Williams e a rugosidade de Darcy-Weisbach); o entupimento vale.',
    'With Scobey or Manning the pipe losses do not age here (only the Hazen-Williams C and the Darcy-Weisbach roughness do); the clogging applies.',
    'Con Scobey o Manning la pérdida en las tuberías no envejece aquí (solo la C de Hazen-Williams y la rugosidad de Darcy-Weisbach); la obstrucción vale.',
  ),
  'ai.op.life_scenarios': ('Comparar o projeto envelhecido e entupido com o novo', 'Compare the aged and clogged design with the new one', 'Comparar el proyecto envejecido y obstruido con el nuevo'),
};

/// 1.6.0 MOT+: pump stations, the real operation of the zones, pilot
/// valves, and the profile, surge class and looped mainlines in the sizing.
const _motPlus = <String, (String, String, String)>{
  // ---- pump stations (PRD-17)
  'pumpStation.title': ('Estação de bombeamento', 'Pump station', 'Estación de bombeo'),
  'pumpStation.edit': ('Estação de bombeamento…', 'Pump station…', 'Estación de bombeo…'),
  'pumpStation.single': ('Bomba única', 'Single pump', 'Bomba única'),
  'pumpStation.summary': ('{duty} em serviço + {standby} de reserva, {arr}', '{duty} on duty + {standby} on standby, {arr}', '{duty} en servicio + {standby} de reserva, {arr}'),
  'pumpStation.hint': (
    'O item de bomba passa a representar uma estação: a bomba do item (bomba 1) e as que vêm depois dela. O cálculo resolve a estação pela curva das bombas que funcionam juntas e mostra o ponto de operação de cada uma; as bombas de reserva não funcionam e entram na lista de materiais.',
    'The pump item stands for a station: its own pump (pump 1) and the ones after it. The design solves the station on the curve of the pumps that run together and shows the operating point of each one; standby pumps do not run and go in the bill of materials.',
    'El elemento de bomba representa una estación: su propia bomba (bomba 1) y las que vienen después. El cálculo resuelve la estación con la curva de las bombas que funcionan juntas y muestra el punto de operación de cada una; las bombas de reserva no funcionan y entran en la lista de materiales.',
  ),
  'pumpStation.arrangement': ('Ligação das bombas em serviço', 'How the duty pumps are joined', 'Conexión de las bombas en servicio'),
  'pumpStation.parallel': ('em paralelo (somam a vazão)', 'in parallel (their flows add)', 'en paralelo (suman el caudal)'),
  'pumpStation.series': ('em série (somam a altura)', 'in series (their heads add)', 'en serie (suman la altura)'),
  'pumpStation.staged': ('Partida escalonada pela vazão de cada turno', 'Staged start by the flow of each system flow', 'Arranque escalonado por el caudal de cada turno'),
  'pumpStation.stagedHint': (
    'As bombas em serviço partem uma após a outra, na ordem da lista, até a estação dar a vazão do turno dentro da faixa de cada bomba e a pressão que as válvulas pedem (com fonte de pressão calculada, só a faixa conta). Desligado: todas as bombas em serviço funcionam em todos os turnos.',
    'The duty pumps start one after another, in the order of the list, until the station gives the flow of the system flow within the range of every pump and the pressure the valves need (with a calculated supply, the range alone). Off: every duty pump runs in every system flow.',
    'Las bombas en servicio arrancan una tras otra, en el orden de la lista, hasta que la estación da el caudal del turno dentro del rango de cada bomba y la presión que piden las válvulas (con fuente de presión calculada, solo cuenta el rango). Apagado: todas las bombas en servicio funcionan en todos los turnos.',
  ),
  'pumpStation.pumps': ('Bombas', 'Pumps', 'Bombas'),
  'pumpStation.lead': ('Bomba 1 (a do item)', 'Pump 1 (the item\'s own)', 'Bomba 1 (la del elemento)'),
  'pumpStation.unit': ('Bomba {n}', 'Pump {n}', 'Bomba {n}'),
  'pumpStation.sameModel': ('O mesmo modelo da bomba 1', 'The model of pump 1', 'El mismo modelo de la bomba 1'),
  'pumpStation.standby': ('Reserva', 'Standby', 'Reserva'),
  'pumpStation.add': ('Acrescentar bomba', 'Add a pump', 'Añadir bomba'),
  'pumpStation.remove': ('Tirar esta bomba', 'Remove this pump', 'Quitar esta bomba'),
  'pumpStation.duty': ('Operação em cada turno (último cálculo)', 'Operation in each system flow (latest design)', 'Operación en cada turno (último cálculo)'),
  'pumpStation.noResults': (
    'Calcule o projeto para ver o ponto de operação de cada bomba.',
    'Run the design to see the operating point of each pump.',
    'Calcule el proyecto para ver el punto de operación de cada bomba.',
  ),
  'pumpStation.running': ('{n} de {duty} bombas em serviço ligadas', '{n} of {duty} duty pumps on', '{n} de {duty} bombas en servicio encendidas'),
  'pumpStation.on': ('ligada', 'on', 'encendida'),
  'pumpStation.off': ('desligada', 'off', 'apagada'),
  'pumpStation.efficiency': ('Rendimento do fio à água', 'Wire-to-water efficiency', 'Rendimiento del cable al agua'),
  'pumpStation.power': ('Potência elétrica', 'Electric power', 'Potencia eléctrica'),
  'reports.stations': ('Estações de bombeamento', 'Pump stations', 'Estaciones de bombeo'),
  'hist.pumpStation': ('Estação de bombeamento', 'Pump station', 'Estación de bombeo'),
  'props.flywheel': ('Volante de inércia (kg·m², contra o golpe)', 'Flywheel (kg·m², against the water hammer)', 'Volante de inercia (kg·m², contra el golpe)'),
  'ai.op.set_pump_station': ('Configurar a estação de bombeamento {n}', 'Set up the pump station {n}', 'Configurar la estación de bombeo {n}'),
  'ai.op.pump_stations': ('Ler as estações de bombeamento', 'Read the pump stations', 'Leer las estaciones de bombeo'),
  // ---- real operation of the zones at the pressure the mainline gives them
  'dlg.realZoneOperation': (
    'Operação real dos setores (pela pressão que a linha principal entrega)',
    'Real operation of the zones (at the pressure the mainline delivers)',
    'Operación real de los sectores (con la presión que entrega la línea principal)',
  ),
  'dlg.realZoneOperationHint': (
    'Depois do cálculo, cada setor e pivô de cada turno também funciona com a pressão que de fato chega à válvula: os emissores entregam o que essa pressão permite, uma válvula que não regula passa a sobra adiante, e a linha e as bombas se acomodam nas vazões que resultam. O resultado sai na tabela de operação real.',
    'After the design, every zone and pivot of each system flow also runs at the pressure that really reaches its valve: the emitters deliver what that pressure allows, a valve that does not regulate passes the surplus on, and the line and the pumps settle at the flows that follow. The result is in the real operation table.',
    'Después del cálculo, cada sector y pivote de cada turno también funciona con la presión que de hecho llega a la válvula: los emisores entregan lo que esa presión permite, una válvula que no regula pasa el sobrante, y la línea y las bombas se acomodan en los caudales resultantes. El resultado sale en la tabla de operación real.',
  ),
  'reports.operation': ('Operação real dos setores', 'Real operation of the zones', 'Operación real de los sectores'),
  'zoneOp.designFlow': ('Vazão de projeto', 'Design flow', 'Caudal de proyecto'),
  'zoneOp.realFlow': ('Vazão real', 'Real flow', 'Caudal real'),
  'zoneOp.delivered': ('Entregue %', 'Delivered %', 'Entregado %'),
  'zoneOp.short': ('falta pressão', 'short of pressure', 'falta presión'),
  'zoneOp.excess': ('acima da faixa (a válvula não regula)', 'above the window (the valve does not regulate)', 'por encima del rango (la válvula no regula)'),
  'ai.op.real_zone_operation': ('Calcular a operação real dos setores', 'Work out the real operation of the zones', 'Calcular la operación real de los sectores'),
  // ---- pilot valves (reducing, sustaining)
  'props.pilot': ('Piloto da válvula', 'Valve pilot', 'Piloto de la válvula'),
  'valvePilot.none': ('Sem piloto', 'No pilot', 'Sin piloto'),
  'valvePilot.reducing': ('Redutor de pressão', 'Pressure reducing', 'Reductor de presión'),
  'valvePilot.sustaining': ('Sustentador de pressão', 'Pressure sustaining', 'Sostenedor de presión'),
  'valvePilot.reducingSustaining': ('Redutor e sustentador', 'Reducing and sustaining', 'Reductor y sostenedor'),
  'props.pilotReduce': (
    'Pressão mantida a jusante (piloto redutor; 0 = a do cálculo)',
    'Pressure held after the valve (reducing pilot; 0 = the design\'s)',
    'Presión mantenida aguas abajo (piloto reductor; 0 = la del cálculo)',
  ),
  'props.pilotSustain': ('Pressão mantida a montante (piloto sustentador)', 'Pressure kept before the valve (sustaining pilot)', 'Presión mantenida aguas arriba (piloto sostenedor)'),
  // ---- the profile of the mainline in the design: high points and air valves
  'warn.air_valve_missing': ('Ponto alto da linha principal sem ventosa', 'High point of the mainline without an air valve', 'Punto alto de la línea principal sin ventosa'),
  'adv.air_valve_missing.why': (
    'A linha sobe até um ponto mais alto que os vizinhos e desce depois dele: o ar que a água traz se junta ali, estrangula a passagem, faz a vazão cair e provoca golpes quando sai de uma vez. Ao esvaziar, o ponto alto também precisa deixar o ar entrar para o tubo não ficar em vácuo.',
    'The line climbs to a point higher than its neighbours and falls after it: the air the water carries gathers there, chokes the bore, cuts the flow and causes surges when it leaves at once. When the line drains, the high point must also let air in so the pipe is not left under vacuum.',
    'La línea sube hasta un punto más alto que sus vecinos y baja después de él: el aire que trae el agua se junta allí, estrangula el paso, hace caer el caudal y provoca golpes cuando sale de una vez. Al vaciarse, el punto alto también debe dejar entrar aire para que la tubería no quede en vacío.',
  ),
  'adv.air_valve_missing.how': (
    'Ponha uma ventosa de duplo efeito no ponto alto (Linha principal → Ventosas sugere o lugar e o tamanho), ou mude o traçado para não ter o ponto alto.',
    'Fit a combination air valve at the high point (Mainline → Air valves suggests where and what size), or route the line without the high point.',
    'Ponga una ventosa de doble efecto en el punto alto (Línea principal → Ventosas sugiere el lugar y el tamaño), o cambie el trazado para no tener el punto alto.',
  ),
};
