part of '../i18n.dart';

/// Strings added in 1.7.0 for the irrigation forecast (how long each area should run in the coming days, from the
/// weather forecast of the site): (pt, en, es), merged into the table after the base strings (a key repeated in another
/// part is a compile-time error). The keys `src.kind.forecast`, `terms.src.*` and `cache.forecast` follow the schemes of
/// Help → Terms of the data and File → Saved downloaded data, which build them from the source and the kind.
const _fct = <String, (String, String, String)>{
  // ---- menu and dialog
  'fct.menu': ('Previsão de irrigação…', 'Irrigation forecast…', 'Pronóstico de riego…'),
  'fct.title': ('Previsão de irrigação dos próximos dias', 'Irrigation forecast for the next days', 'Pronóstico de riego de los próximos días'),
  'fct.hint': (
    'Busca a previsão do tempo do local e diz, para cada área irrigada, em quais dos próximos dias irrigar, com que lâmina e por quanto tempo (com a taxa de aplicação do projeto), e o ajuste em % sobre a programação do projeto — o número que se digita no controlador (water budget). Nada é buscado sem você pedir.',
    'Fetches the weather forecast of the site and tells, for each irrigated area, on which of the next days to irrigate, with what depth and for how long (at the application rate of the design), and the adjustment in % of the design programme — the figure typed into the controller (water budget). Nothing is fetched until you ask.',
    'Busca el pronóstico del tiempo del sitio y dice, para cada área regada, en cuáles de los próximos días regar, con qué lámina y por cuánto tiempo (con la tasa de aplicación del diseño), y el ajuste en % sobre la programación del diseño — el número que se escribe en el controlador (water budget). No se busca nada sin que usted lo pida.',
  ),
  'fct.noAreas': (
    'O projeto não tem áreas irrigadas: desenhe as áreas com a cultura e o solo para prever a irrigação.',
    'The project has no irrigated areas: draw the areas with their crop and soil to forecast the irrigation.',
    'El proyecto no tiene áreas regadas: dibuje las áreas con su cultivo y suelo para pronosticar el riego.',
  ),
  'fct.source': ('Fonte da previsão', 'Forecast source', 'Fuente del pronóstico'),
  'fct.src.metNorway': ('MET Norway — livre para qualquer uso, com o crédito', 'MET Norway — free for any use, with the credit', 'MET Norway — libre para cualquier uso, con el crédito'),
  'fct.src.openMeteo': ('Open-Meteo — só uso não comercial', 'Open-Meteo — non-commercial use only', 'Open-Meteo — solo uso no comercial'),
  'fct.start': ('Solo no início', 'Soil at the start', 'Suelo al inicio'),
  'fct.start.full': ('Cheio hoje (acabou de irrigar ou de chover bem)', 'Full today (just irrigated, or after a good rain)', 'Lleno hoy (recién regado o tras una buena lluvia)'),
  'fct.start.last': ('Última irrigação ou chuva há alguns dias', 'Last irrigation or rain some days ago', 'Último riego o lluvia hace unos días'),
  'fct.daysAgo': ('Há quantos dias (0 = hoje)', 'How many days ago (0 = today)', 'Hace cuántos días (0 = hoy)'),
  'fct.depth': ('Lâmina que entrou no solo (0 = encheu)', 'Depth into the soil (0 = it filled it)', 'Lámina que entró en el suelo (0 = lo llenó)'),
  'fct.fetch': ('Buscar a previsão', 'Get the forecast', 'Obtener el pronóstico'),
  'fct.refresh': ('Buscar de novo', 'Fetch again', 'Buscar de nuevo'),
  'fct.refreshAfter': ('O serviço pede para não buscar de novo antes das {t}.', 'The service asks not to fetch again before {t}.', 'El servicio pide no buscar de nuevo antes de las {t}.'),
  'fct.fetched': ('Previsão obtida em', 'Forecast fetched at', 'Pronóstico obtenido el'),
  'fct.kept': ('guardada neste aparelho', 'kept on this device', 'guardado en este dispositivo'),
  'fct.etoBy.service': ('ETo publicada pelo serviço (FAO-56)', 'ETo as published by the service (FAO-56)', 'ETo publicada por el servicio (FAO-56)'),
  'fct.etoBy.pm': (
    'ETo pela equação FAO Penman-Monteith, com a radiação estimada pela amplitude térmica (FAO-56 eq. 50): o serviço não dá radiação.',
    'ETo by the FAO Penman-Monteith equation, the radiation estimated from the temperature range (FAO-56 eq. 50): the service gives no radiation.',
    'ETo por la ecuación FAO Penman-Monteith, con la radiación estimada por la amplitud térmica (FAO-56 ec. 50): el servicio no da radiación.',
  ),
  'fct.assume': (
    'Previsão é incerteza, e cresce depois dos três primeiros dias: confira antes de irrigar e busque de novo amanhã. Supõe-se o solo como você disse no início (sem chuva desde a última irrigação) e nenhuma chuva depois do último dia da previsão. Chuva abaixo de 0,2·ETo do dia não conta; acima da capacidade de campo, percola. Irriga-se quando o solo perde o que um evento da programação repõe (ou a água facilmente disponível, se menor), repondo o que faltou. O ajuste (%) é o uso de água da cultura menos a chuva que o solo guarda, sobre o que a programação do projeto aplica nos mesmos dias.',
    'A forecast is uncertain, more so after the first three days: check it before irrigating and fetch again tomorrow. The soil is taken as you said at the start (no rain since the last irrigation) and no rain after the last day of the forecast. Rain below 0.2·ETo of the day does not count; above field capacity it percolates. An area is irrigated when the soil has lost what one event of the programme replaces (or the readily available water, if less), refilling what is missing. The adjustment (%) is the water the crop uses less the rain the soil keeps, over what the design programme applies in as many days.',
    'Un pronóstico es incierto, y más después de los tres primeros días: revíselo antes de regar y vuelva a buscarlo mañana. Se toma el suelo como usted dijo al inicio (sin lluvia desde el último riego) y ninguna lluvia después del último día del pronóstico. La lluvia por debajo de 0,2·ETo del día no cuenta; por encima de la capacidad de campo, percola. Se riega cuando el suelo pierde lo que repone un evento de la programación (o el agua fácilmente disponible, si es menor), reponiendo lo que falta. El ajuste (%) es el agua que usa el cultivo menos la lluvia que guarda el suelo, sobre lo que aplica la programación del diseño en los mismos días.',
  ),
  'fct.table.plan': ('Previsão de irrigação', 'Irrigation forecast', 'Pronóstico de riego'),
  'fct.table.days': ('Previsão de irrigação dia a dia', 'Irrigation forecast day by day', 'Pronóstico de riego día a día'),
  'fct.programme': ('Programação por evento', 'Programme per event', 'Programación por evento'),
  'fct.budget': ('Ajuste (water budget)', 'Adjustment (water budget)', 'Ajuste (water budget)'),
  'fct.skip': ('não irrigar', 'skip', 'no regar'),
  'fct.irrigate': ('irrigar', 'irrigate', 'regar'),
  'fct.decision': ('Decisão', 'Decision', 'Decisión'),
  'fct.runTime': ('Tempo de funcionamento', 'Run time', 'Tiempo de funcionamiento'),
  'fct.ofEvent': ('Do evento programado', 'Of the programmed event', 'Del evento programado'),
  'fct.offSeason': ('Fora do ciclo', 'Off season', 'Fuera del ciclo'),
  'fct.file': ('previsao_irrigacao', 'irrigation_forecast', 'pronostico_riego'),
  // ---- messages of the plan (codes of lib/core/design/irrigation_forecast.dart)
  'fct.w.fct_today_estimated': (
    'Hoje (*): a previsão tem poucas horas restantes; a ETo de hoje é a de amanhã.',
    'Today (*): few hours of today are left in the forecast; today\'s ETo is tomorrow\'s.',
    'Hoy (*): al pronóstico le quedan pocas horas de hoy; la ETo de hoy es la de mañana.',
  ),
  'fct.w.fct_starts_later': ('A previsão começa depois de hoje.', 'The forecast starts after today.', 'El pronóstico empieza después de hoy.'),
  'fct.w.fct_stale': (
    'O serviço não respondeu agora: esta é a previsão guardada da última busca.',
    'The service did not answer now: this is the forecast kept from the last fetch.',
    'El servicio no respondió ahora: este es el pronóstico guardado de la última búsqueda.',
  ),
  'fct.w.fct_no_results': (
    'Sem resultados do projeto: tempos com a vazão nominal dos emissores. Calcule o projeto (F5) para os tempos reais.',
    'No design results: run times at the nominal flow of the emitters. Run the design (F5) for the real ones.',
    'Sin resultados del diseño: tiempos con el caudal nominal de los emisores. Calcule el diseño (F5) para los reales.',
  ),
  'fct.w.fct_no_days': ('A previsão não tem dias a partir de hoje.', 'The forecast has no days from today on.', 'El pronóstico no tiene días a partir de hoy.'),
  'fct.w.fct_no_areas': ('Nenhuma área irrigada.', 'No irrigated area.', 'Ninguna área regada.'),
  'fct.w.fct_no_rate': ('sem emissores na área: só a lâmina, sem tempo', 'no emitters in the area: the depth only, no run time', 'sin emisores en el área: solo la lámina, sin tiempo'),
  'fct.w.fct_off_season': ('fora do ciclo da cultura nestes dias', 'the crop is out of season these days', 'el cultivo está fuera de ciclo estos días'),
  'fct.w.fct_start_dry': (
    'começa abaixo da água facilmente disponível (cultura em estresse)',
    'starts below the readily available water (the crop is stressed)',
    'empieza por debajo del agua fácilmente disponible (cultivo en estrés)',
  ),
  'fct.w.fct_fixed_depth': ('lâmina diária fixa: a previsão não a altera', 'fixed daily depth: the forecast does not change it', 'lámina diaria fija: el pronóstico no la cambia'),
  'fct.w.fct_gap_estimated': (
    'sem clima do local: os dias desde a última irrigação usam a ETo do primeiro dia da previsão',
    'no site climate: the days since the last irrigation take the ETo of the first forecast day',
    'sin clima del sitio: los días desde el último riego toman la ETo del primer día del pronóstico',
  ),
  // ---- errors of the fetch (codes of lib/core/io/forecast_online.dart)
  'fct.err.fc_no_site': (
    'O projeto não tem georreferência: defina o local do projeto para buscar a previsão do tempo.',
    'The project has no georeference: set the site of the project to fetch its weather forecast.',
    'El proyecto no tiene georreferencia: defina el sitio del proyecto para buscar su pronóstico del tiempo.',
  ),
  'fct.err.fc_bad_request': ('Coordenadas do local inválidas.', 'The site coordinates are not valid.', 'Las coordenadas del sitio no son válidas.'),
  'fct.err.fc_network': ('Sem conexão com o serviço de previsão.', 'Could not reach the forecast service.', 'No se pudo conectar con el servicio de pronóstico.'),
  'fct.err.fc_rate_limited': (
    'O serviço de previsão pediu para esperar (muitos pedidos). Tente mais tarde.',
    'The forecast service asked to wait (too many requests). Try later.',
    'El servicio de pronóstico pidió esperar (demasiadas peticiones). Inténtelo más tarde.',
  ),
  'fct.err.fc_forbidden': ('O serviço de previsão recusou o pedido.', 'The forecast service refused the request.', 'El servicio de pronóstico rechazó la petición.'),
  'fct.err.fc_service_error': ('O serviço de previsão respondeu com erro', 'The forecast service answered with an error', 'El servicio de pronóstico respondió con un error'),
  'fct.err.fc_bad_response': ('Resposta inesperada do serviço de previsão.', 'Unexpected answer from the forecast service.', 'Respuesta inesperada del servicio de pronóstico.'),
  // ---- Help → Terms of the data, File → Saved downloaded data, the assistant
  'src.kind.forecast': ('Previsão do tempo', 'Weather forecast', 'Pronóstico del tiempo'),
  'terms.src.metNorway': (
    'Dados abertos do instituto meteorológico da Noruega (CC BY 4.0), livres para qualquer uso, também comercial, com o crédito. O app pede a previsão só quando você pede, com as coordenadas do local, e não pede de novo antes da hora que o serviço indica. É a fonte de previsão padrão.',
    'Open data of the Norwegian Meteorological Institute (CC BY 4.0), free for any use, commercial included, with the credit. The app asks for the forecast only when you ask, with the coordinates of the site, and not again before the time the service gives. The default forecast source.',
    'Datos abiertos del instituto meteorológico de Noruega (CC BY 4.0), libres para cualquier uso, también comercial, con el crédito. La aplicación pide el pronóstico solo cuando usted lo pide, con las coordenadas del sitio, y no vuelve a pedirlo antes de la hora que indica el servicio. Es la fuente de pronóstico por defecto.',
  ),
  'terms.src.openMeteoForecast': (
    'A API gratuita é só para uso não comercial (até 10 000 pedidos por dia); o uso comercial pede uma chave do plano pago. Os dados (CC BY 4.0) pedem o crédito.',
    'The free API is for non-commercial use only (up to 10 000 requests a day); commercial use needs a key of its paid plan. The data (CC BY 4.0) ask for the credit.',
    'La API gratuita es solo para uso no comercial (hasta 10 000 peticiones al día); el uso comercial requiere una clave de su plan de pago. Los datos (CC BY 4.0) piden el crédito.',
  ),
  'cache.forecast': ('Previsão do tempo', 'Weather forecast', 'Pronóstico del tiempo'),
  'ai.op.irrigation_forecast': (
    'Buscar a previsão do tempo do local e calcular a irrigação dos próximos dias',
    'Fetch the weather forecast of the site and work out the irrigation of the next days',
    'Buscar el pronóstico del tiempo del sitio y calcular el riego de los próximos días',
  ),
};
