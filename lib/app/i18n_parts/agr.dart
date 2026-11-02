part of '../i18n.dart';

/// Strings added in 1.6.0 for agronomy, machines and electrical design: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _agr = <String, (String, String, String)>{
  // controller programme: an end after midnight (AGR-17)
  'sch.plusDays': ('+{n} d', '+{n} d', '+{n} d'),
  'warn.schedule_uneven_areas': (
    'Turno com áreas que pedem tempos muito diferentes: uma recebe água demais',
    'System flow whose areas need very different run times: one gets too much water',
    'Turno con áreas que piden tiempos muy diferentes: una recibe agua de más',
  ),
  // design check: agronomy of the areas (AGR-05, 08, 10, 11)
  'check.area_rate_exceeds_soil': (
    'Intensidade de aplicação acima da que o solo absorve',
    'Application rate above what the soil takes in',
    'Intensidad de aplicación por encima de la que el suelo absorbe',
  ),
  'adv.area_rate_exceeds_soil.why': (
    'Os aspersores da área aplicam água mais depressa do que o solo, com a sua declividade, consegue infiltrar (USDA NEH 15, cap. 11, Tabela 11-4). A água empoça e escorre: entra no solo menos do que o calculado e há erosão.',
    'The sprinklers of the area apply water faster than the soil, on its slope, can take it in (USDA NEH 15, ch. 11, Table 11-4). The water ponds and runs off: less than the design depth enters the soil and the ground erodes.',
    'Los aspersores del área aplican el agua más rápido de lo que el suelo, con su pendiente, puede infiltrar (USDA NEH 15, cap. 11, Tabla 11-4). El agua se encharca y escurre: entra en el suelo menos de lo calculado y hay erosión.',
  ),
  'adv.area_rate_exceeds_soil.how': (
    'Divida cada irrigação em ciclos curtos com pausas para infiltrar (ciclo e pausa: a mensagem dá o número de ciclos, os minutos de cada um e a pausa), ou use bocais de menor vazão, aspersores rotativos ou um espaçamento maior.',
    'Split every irrigation into short cycles with pauses for the water to soak in (cycle and soak: the message gives the cycles, the minutes of each and the pause), or use nozzles of lower flow, rotors or a wider spacing.',
    'Divida cada riego en ciclos cortos con pausas para infiltrar (ciclo y pausa: el mensaje da el número de ciclos, los minutos de cada uno y la pausa), o use boquillas de menor caudal, rotores o un espaciamiento mayor.',
  ),
  'check.area_eto_climate': ('ETo da área diferente da do clima do local', 'ETo of the area differs from the site climate', 'ETo del área distinta de la del clima del sitio'),
  'adv.area_eto_climate.why': (
    'A área calcula a lâmina com a ETo digitada nela, mas o clima do local tem outra ETo no mês de maior demanda. A lâmina, as horas e o programa do controlador ficam abaixo (ou acima) do que o clima pede.',
    'The area works out its depth with the ETo typed on it, but the site climate has another ETo in the month of highest demand. The depth, the run times and the controller programme fall short of (or beyond) what the climate asks for.',
    'El área calcula la lámina con la ETo escrita en ella, pero el clima del sitio tiene otra ETo en el mes de mayor demanda. La lámina, las horas y el programa del controlador quedan por debajo (o por encima) de lo que pide el clima.',
  ),
  'adv.area_eto_climate.how': (
    'Digite na área a ETo do mês de projeto do clima (o valor depois da barra) ou escolha a cultura da tabela FAO-56, que usa o clima mês a mês.',
    'Type on the area the ETo of the design month of the climate (the value after the slash), or choose the crop of the FAO-56 table, which uses the climate month by month.',
    'Escriba en el área la ETo del mes de diseño del clima (el valor después de la barra) o elija el cultivo de la tabla FAO-56, que usa el clima mes a mes.',
  ),
  'check.area_planting_date': ('Data de plantio ambígua ou inválida', 'Planting date ambiguous or not a date', 'Fecha de siembra ambigua o no válida'),
  'adv.area_planting_date.why': (
    'A data de plantio digitada não é uma data, ou dia e mês poderiam ser trocados (05/09 é 5 de setembro ou 9 de maio). A data decide os meses em que a cultura está no campo, o mês de pico, os volumes e a vazão.',
    'The planting date typed is not a date, or its day and month could be swapped (05/09 is 5 September or 9 May). The date sets the months the crop is in the field, the peak month, the volumes and the flow.',
    'La fecha de siembra escrita no es una fecha, o el día y el mes podrían invertirse (05/09 es 5 de septiembre o 9 de mayo). La fecha decide los meses con el cultivo en el campo, el mes de pico, los volúmenes y el caudal.',
  ),
  'adv.area_planting_date.how': (
    'Digite a data como DD/MM com o dia maior que 12, como MM-DD ou com o nome do mês (15 set). O painel da área mostra como a data foi lida.',
    'Type the date as DD/MM with a day above 12, as MM-DD or with the month name (15 Sep). The area panel shows how the date was read.',
    'Escriba la fecha como DD/MM con un día mayor que 12, como MM-DD o con el nombre del mes (15 sep). El panel del área muestra cómo se leyó la fecha.',
  ),
  'check.area_leaching_infeasible': ('Água salina demais para a cultura', 'Water too saline for the crop', 'Agua demasiado salina para el cultivo'),
  'adv.area_leaching_infeasible.why': (
    'A salinidade da água de irrigação é tão alta para a cultura que nenhuma fração de lixiviação mantém o potencial de rendimento pedido (5·CEes ≤ CEa, FAO-29). A lâmina bruta e o volume desses meses ficam fora dos totais.',
    'The irrigation water is so saline for the crop that no leaching fraction keeps the yield potential asked for (5·ECe ≤ ECw, FAO-29). The gross depth and the volume of those months stay out of the totals.',
    'El agua de riego es tan salina para el cultivo que ninguna fracción de lavado mantiene el potencial de rendimiento pedido (5·CEe ≤ CEa, FAO-29). La lámina bruta y el volumen de esos meses quedan fuera de los totales.',
  ),
  'adv.area_leaching_infeasible.how': (
    'Baixe o potencial de rendimento da área, escolha uma cultura mais tolerante ou use outra água (ou uma mistura de águas) menos salina.',
    'Lower the yield potential of the area, choose a more tolerant crop or use another water (or a blend of waters) of lower salinity.',
    'Baje el potencial de rendimiento del área, elija un cultivo más tolerante o use otra agua (o una mezcla de aguas) menos salina.',
  ),
  // valve wiring: what the controller delivers (AGR-12)
  'warn.elec_station_current': (
    'Estação pede mais corrente que uma saída do controlador fornece',
    'Station draws more current than a controller output gives',
    'La estación pide más corriente de la que da una salida del controlador',
  ),
  'adv.elec_station_current.why': (
    'Os solenoides de uma estação abrem juntos e a corrente de partida deles passa da que uma saída do controlador fornece (sem dado do controlador, 0,56 A, típico de controladores de 24 V CA). A válvula pode não abrir e a saída pode queimar.',
    'The solenoids of a station open together and their inrush current is more than one controller output gives (without the controller\'s data, 0.56 A, typical of 24 V AC controllers). The valve may not open and the output may burn out.',
    'Los solenoides de una estación abren juntos y su corriente de arranque supera la que da una salida del controlador (sin datos del controlador, 0,56 A, típico de controladores de 24 V CA). La válvula puede no abrir y la salida puede quemarse.',
  ),
  'adv.elec_station_current.how': (
    'Use um relé de estação alimentado à parte, divida a estação em duas ou informe no controlador a corrente por estação que o fabricante garante.',
    'Use a station relay with its own supply, split the station in two, or enter on the controller the current per station its maker states.',
    'Use un relé de estación con alimentación propia, divida la estación en dos o indique en el controlador la corriente por estación que garantiza el fabricante.',
  ),
  'warn.elec_overcurrent': (
    'Corrente do turno acima do que o controlador fornece',
    'Current of a system flow above what the controller delivers',
    'Corriente del turno por encima de lo que da el controlador',
  ),
  'adv.elec_overcurrent.why': (
    'No pior instante de um turno (uma estação abrindo com as outras ligadas, ou a válvula mestra abrindo junto com a primeira estação) a corrente total passa da que o controlador fornece (sem dado do controlador, 1,5 A, um transformador de cerca de 40 VA).',
    'At the worst instant of a system flow (a station opening with the others on, or the master valve opening with the first station) the total current is more than the controller delivers (without the controller\'s data, 1.5 A, a transformer of about 40 VA).',
    'En el peor instante de un turno (una estación abriendo con las otras encendidas, o la válvula maestra abriendo con la primera estación) la corriente total supera la que da el controlador (sin datos del controlador, 1,5 A, un transformador de unos 40 VA).',
  ),
  'adv.elec_overcurrent.how': (
    'Abra menos estações juntas (mais turnos ou um limite de estações simultâneas), ponha relés na válvula mestra e nas estações maiores, ou informe a corrente total do controlador escolhido.',
    'Open fewer stations together (more system flows or a limit of stations at once), put relays on the master valve and the largest stations, or enter the total current of the controller chosen.',
    'Abra menos estaciones a la vez (más turnos o un límite de estaciones simultáneas), ponga relés en la válvula maestra y en las estaciones mayores, o indique la corriente total del controlador elegido.',
  ),
  'props.stationMaxA': ('Corrente máx. por estação (A; 0 = típica)', 'Largest current per station (A; 0 = typical)', 'Corriente máx. por estación (A; 0 = típica)'),
  'props.totalMaxA': ('Corrente máx. do controlador (A; 0 = típica)', 'Largest current of the controller (A; 0 = typical)', 'Corriente máx. del controlador (A; 0 = típica)'),
  'elec.stationPeak': ('Maior estação', 'Largest station', 'Mayor estación'),
  // machines (AGR-07, AGR-22)
  'warn.pivot_pkg_slow_drive': ('Volta a 100 % mais longa que o ciclo de projeto', 'Revolution at 100 % longer than the design cycle', 'Vuelta al 100 % más larga que el ciclo de diseño'),
  'adv.pivot_pkg_slow_drive.why': (
    'Na velocidade da última torre a 100 %, a volta leva mais horas que o ciclo de projeto: a menor lâmina por volta passa da lâmina de projeto e as irrigações leves ficam fora de alcance.',
    'At the speed of the last tower at 100 %, a revolution takes more hours than the design cycle: the lightest depth per revolution is more than the design depth and light irrigations are out of reach.',
    'A la velocidad de la última torre al 100 %, la vuelta lleva más horas que el ciclo de diseño: la menor lámina por vuelta supera la lámina de diseño y los riegos ligeros quedan fuera de alcance.',
  ),
  'adv.pivot_pkg_slow_drive.how': (
    'Use um motorredutor ou relações de engrenagem mais rápidos ou pneus maiores (a velocidade que cumpre o ciclo aparece no percentímetro), ou aumente as horas por ciclo e a lâmina de projeto.',
    'Use a faster gear motor or gearbox ratios or larger tyres (the speed that keeps the cycle is shown with the timer chart), or raise the hours per cycle and the design depth.',
    'Use un motorreductor o relaciones de engranaje más rápidos o neumáticos mayores (la velocidad que cumple el ciclo aparece en el percentímetro), o aumente las horas por ciclo y la lámina de diseño.',
  ),
  'mech.speedForCycle': ('Velocidade para o ciclo de projeto', 'Speed for the design cycle', 'Velocidad para el ciclo de diseño'),
  'mech.armThrow': (
    'Alcance do último aspersor do braço (m; vazio = o da máquina)',
    'Throw of the last sprinkler of the arm (m; empty = the machine\'s)',
    'Alcance del último aspersor del brazo (m; vacío = el de la máquina)',
  ),
  'mech.armTower': ('braço', 'arm', 'brazo'),
};
