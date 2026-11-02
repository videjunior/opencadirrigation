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
  'mech.armThrowOwn': ('Alcance do último aspersor do braço', 'Throw of the last sprinkler of the arm', 'Alcance del último aspersor del brazo'),
  'mech.armThrowHint': (
    'Com o braço de canto, a máquina principal rega só até a articulação na última torre: o balanço e o alcance dela não contam, e o braço rega daí em diante até o seu próprio alcance.',
    'With a corner arm the main machine waters only up to the hinge at its last tower: its overhang and throw do not count, and the arm waters from there out to its own throw.',
    'Con el brazo de esquina la máquina principal riega solo hasta la articulación en la última torre: su voladizo y su alcance no cuentan, y el brazo riega desde allí hasta su propio alcance.',
  ),
  'mech.armTower': ('braço', 'arm', 'brazo'),
  // area panel: localized irrigation and the crop table (AGR-01, 08, 09, 11)
  'area.kr': ('Kr digitado (0 = pela cobertura)', 'Kr typed (0 = from the cover)', 'Kr escrito (0 = por la cobertura)'),
  'area.krUsed': ('Kr usado (ETc,loc = Kr·Kc·ETo)', 'Kr used (ETc,loc = Kr·Kc·ETo)', 'Kr usado (ETc,loc = Kr·Kc·ETo)'),
  'area.designMonth': ('Mês de projeto', 'Design month', 'Mes de diseño'),
  'req.plantingRead': ('Lida como {d}', 'Read as {d}', 'Leída como {d}'),
  'req.plantingAmbiguous': ('Dia e mês podem estar trocados: lida como {d}', 'Day and month may be swapped: read as {d}', 'Día y mes pueden estar invertidos: leída como {d}'),
  'req.plantingInvalid': ('Não é uma data: usado {d}', 'Not a date: {d} is used', 'No es una fecha: se usa {d}'),
  'req.plantingDefault': (
    'Sem data: {d} (mês da tabela FAO-56, seis meses depois no hemisfério sul)',
    'No date: {d} (month of the FAO-56 table, six months later in the southern hemisphere)',
    'Sin fecha: {d} (mes de la tabla FAO-56, seis meses después en el hemisferio sur)',
  ),
  'req.yieldPotential': ('Potencial de rendimento (%)', 'Yield potential (%)', 'Potencial de rendimiento (%)'),
  'req.climateKc': (
    'Ajustar o Kc ao clima do local e à frequência das irrigações (FAO-56)',
    'Adjust Kc to the site climate and to how often it is irrigated (FAO-56)',
    'Ajustar el Kc al clima del sitio y a la frecuencia de los riegos (FAO-56)',
  ),
  // management: the month of the programme (AGR-05)
  'mgmt.month': ('Mês do programa', 'Month of the programme', 'Mes del programa'),
  'mgmt.monthDesign': ('Mês de projeto de cada área', 'Design month of each area', 'Mes de diseño de cada área'),
  // gated pipe with fixed holes (AGR-23)
  'gate.fixedHoles': ('Furos fixos (sem regulagem)', 'Fixed holes (not adjustable)', 'Orificios fijos (sin regulación)'),
  'gate.fixedHolesHint': (
    'Cada furo fica todo aberto: a vazão de cada sulco é a do furo na pressão que ele recebe, e o tubo é resolvido de novo com essas vazões.',
    'Every hole stays fully open: each furrow gets the flow of its hole at the pressure it sees, and the pipe is solved again with those flows.',
    'Cada orificio queda totalmente abierto: cada surco recibe el caudal de su orificio a la presión que tiene, y la tubería se resuelve de nuevo con esos caudales.',
  ),
  'gate.deliveredTotal': ('Vazão de entrada com os furos fixos', 'Inlet flow with the fixed holes', 'Caudal de entrada con los orificios fijos'),
  'gate.uniformity': ('Uniformidade entre sulcos', 'Uniformity among the furrows', 'Uniformidad entre surcos'),
  'gate.minOverMean': ('mínima/média', 'least/mean', 'mínima/media'),
  'gate.delivered': ('Vazão entregue', 'Flow delivered', 'Caudal entregado'),
  // site climate: humidity, wind and the normals of a station (AGR-05, 09, 13)
  'clim.tab.monthly': ('Valores mensais', 'Monthly values', 'Valores mensuales'),
  'clim.tab.station': ('Normais da estação', 'Station normals', 'Normales de la estación'),
  'clim.rhMin': ('UR mín.', 'RH min', 'HR mín.'),
  'clim.wind2m': ('Vento a 2 m', 'Wind at 2 m', 'Viento a 2 m'),
  'clim.src.station': (
    'ETo das normais de uma estação (Penman-Monteith FAO-56)',
    'ETo from the normals of a station (FAO-56 Penman-Monteith)',
    'ETo de las normales de una estación (Penman-Monteith FAO-56)',
  ),
  'clim.fillAreas': (
    'Pôr a ETo do mês de projeto ({e} mm/d) nas {n} área(s) com ETo digitada',
    'Put the ETo of the design month ({e} mm/d) on the {n} area(s) with a typed ETo',
    'Poner la ETo del mes de diseño ({e} mm/d) en las {n} área(s) con ETo escrita',
  ),
  'clim.station.hint': (
    'Normais mensais de uma estação meteorológica: médias das temperaturas máximas e mínimas, umidade relativa média, vento, insolação e chuva. Células em branco são estimadas como manda a FAO-56 (umidade pela Tmín, radiação pela amplitude térmica, vento de 2 m/s); a ETo sai pela equação de Penman-Monteith FAO-56 mês a mês.',
    'Monthly normals of a weather station: means of the daily maximum and minimum temperatures, mean relative humidity, wind, sunshine and rain. Blank cells are estimated as FAO-56 says (humidity from Tmin, radiation from the temperature range, 2 m/s of wind); the ETo comes from the FAO-56 Penman-Monteith equation month by month.',
    'Normales mensuales de una estación meteorológica: medias de las temperaturas máximas y mínimas, humedad relativa media, viento, insolación y lluvia. Las celdas en blanco se estiman como indica la FAO-56 (humedad por la Tmín, radiación por la amplitud térmica, viento de 2 m/s); la ETo sale de la ecuación de Penman-Monteith FAO-56 mes a mes.',
  ),
  'clim.station.lat': ('Latitude da estação (°, sul negativa)', 'Station latitude (°, south negative)', 'Latitud de la estación (°, sur negativa)'),
  'clim.station.elev': ('Altitude da estação (m)', 'Station elevation (m)', 'Altitud de la estación (m)'),
  'clim.station.windHeight': ('Altura do anemômetro (m)', 'Anemometer height (m)', 'Altura del anemómetro (m)'),
  'clim.station.coastal': ('Estação no litoral (kRs 0,19)', 'Coastal station (kRs 0.19)', 'Estación costera (kRs 0,19)'),
  'clim.station.tmax': ('Tmáx (°C)', 'Tmax (°C)', 'Tmáx (°C)'),
  'clim.station.tmin': ('Tmín (°C)', 'Tmin (°C)', 'Tmín (°C)'),
  'clim.station.rh': ('UR média (%)', 'Mean RH (%)', 'HR media (%)'),
  'clim.station.wind': ('Vento (m/s)', 'Wind (m/s)', 'Viento (m/s)'),
  'clim.station.sun': ('Insolação (h/d)', 'Sunshine (h/d)', 'Insolación (h/d)'),
  'clim.station.estimated': ('Estimado', 'Estimated', 'Estimado'),
  'clim.station.apply': ('Usar nos valores mensais', 'Use in the monthly values', 'Usar en los valores mensuales'),
  'clim.station.need': ('Preencha Tmáx e Tmín dos meses para calcular a ETo', 'Fill in Tmax and Tmin of the months to work out the ETo', 'Complete Tmáx y Tmín de los meses para calcular la ETo'),
  'clim.est.vapourPressureFromTmin': ('umidade pela Tmín', 'humidity from Tmin', 'humedad por la Tmín'),
  'clim.est.radiationFromTemperature': ('radiação pela amplitude térmica', 'radiation from the temperature range', 'radiación por la amplitud térmica'),
  'clim.est.radiationIsland': ('radiação de ilha', 'island radiation', 'radiación de isla'),
  'clim.est.radiationLimitedToClearSky': ('radiação limitada à de céu limpo', 'radiation limited to clear sky', 'radiación limitada a cielo despejado'),
  'clim.est.windDefault': ('vento de 2 m/s', 'wind of 2 m/s', 'viento de 2 m/s'),
  'clim.est.windLimited': ('vento elevado a 0,5 m/s', 'wind raised to 0.5 m/s', 'viento elevado a 0,5 m/s'),
  'clim.est.cloudinessLimited': ('nebulosidade limitada', 'cloudiness limited', 'nubosidad limitada'),
};
