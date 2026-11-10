part of '../i18n.dart';

/// Strings added in 1.7.0 for the climate risk over the years (Design →
/// Agronomy): (pt, en, es), merged into the table after the base strings
/// (a key repeated in another part is a compile-time error).
const _clr = <String, (String, String, String)>{
  'clr.menu': ('Risco climático ao longo dos anos…', 'Climate risk over the years…', 'Riesgo climático a lo largo de los años…'),
  'clr.title': ('Risco climático ao longo dos anos', 'Climate risk over the years', 'Riesgo climático a lo largo de los años'),
  'clr.hint': (
    'Como o sistema, tal como projetado, teria se saído em cada um dos últimos anos reais: o balanço hídrico diário de cada área com a série diária de clima do local, sem limite e com a capacidade do sistema. Mostra a distribuição da necessidade de irrigação e da demanda de pico, a confiabilidade, os piores anos e a tendência, ao lado dos valores que o projeto usa.',
    'How the system as designed would have done in each of the last real years: the daily water balance of every area with the site\'s daily weather series, without a limit and with the system\'s capacity. It shows the spread of the irrigation requirement and of the peak demand, the reliability, the worst years and the trend, beside the figures the design uses.',
    'Cómo le habría ido al sistema, tal como está diseñado, en cada uno de los últimos años reales: el balance hídrico diario de cada área con la serie diaria de clima del sitio, sin límite y con la capacidad del sistema. Muestra la distribución de la necesidad de riego y de la demanda punta, la confiabilidad, los peores años y la tendencia, junto a los valores que usa el diseño.',
  ),
  'clr.noAreas': (
    'Nenhuma área irrigada com balanço hídrico (uma cultura, ou ETo e Kc). Desenhe uma área e escolha a cultura.',
    'No irrigated area with a water balance (a crop, or ETo and Kc). Draw an area and choose its crop.',
    'Ninguna área regada con balance hídrico (un cultivo, o ETo y Kc). Dibuje un área y elija su cultivo.',
  ),
  'clr.source': ('Série diária de clima', 'Daily weather series', 'Serie diaria de clima'),
  'clr.src.nasaPower': (
    'NASA POWER, {a}–{b} (baixa alguns MB uma vez e guarda no aparelho)',
    'NASA POWER, {a}–{b} (downloads a few MB once and keeps them on this device)',
    'NASA POWER, {a}–{b} (descarga unos MB una vez y los guarda en el equipo)',
  ),
  'clr.src.site': ('Série do clima do local: {s}, {a}–{b}', 'The site climate\'s series: {s}, {a}–{b}', 'Serie del clima del sitio: {s}, {a}–{b}'),
  'clr.probability': ('Probabilidade de não excedência', 'Non-exceedance probability', 'Probabilidad de no excedencia'),
  'clr.peakDays': ('Período de pico (dias)', 'Peak period (days)', 'Período punta (días)'),
  'clr.run': ('Analisar', 'Analyse', 'Analizar'),
  'clr.progress': ('Baixando: {d} de {n} partes', 'Downloading: {d} of {n} parts', 'Descargando: {d} de {n} partes'),
  'clr.saved': ('Risco climático guardado no projeto (só o resumo).', 'Climate risk kept in the project (the summary only).', 'Riesgo climático guardado en el proyecto (solo el resumen).'),
  'clr.stored': (
    'Calculado em {d} com {s}, {a}–{b}. Refaça depois de mudar o projeto.',
    'Computed on {d} with {s}, {a}–{b}. Run it again after changing the design.',
    'Calculado el {d} con {s}, {a}–{b}. Repítalo después de cambiar el diseño.',
  ),
  'clr.view': ('Mostrar', 'Show', 'Mostrar'),
  'clr.project': ('Projeto (todas as áreas)', 'Project (every area)', 'Proyecto (todas las áreas)'),
  'clr.season': ('Safra', 'Season', 'Temporada'),
  'clr.crosses': ('entra no ano seguinte', 'runs into the next year', 'entra en el año siguiente'),
  'clr.capacityTitle': ('Capacidade do sistema', 'System capacity', 'Capacidad del sistema'),
  'clr.capacity': ('capacidade {v}', 'capacity {v}', 'capacidad {v}'),
  'clr.capacityUnknown': (
    'capacidade desconhecida (sem emissores na área, ou fora dos fluxos do sistema)',
    'capacity unknown (no emitters in the area, or outside the system flows)',
    'capacidad desconocida (sin emisores en el área, o fuera de los flujos del sistema)',
  ),
  'clr.designEto': (
    'não excedida em {p} % dos anos: {v}; o projeto usa {w}',
    'not exceeded in {p} % of the years: {v}; the design uses {w}',
    'no excedida en el {p} % de los años: {v}; el diseño usa {w}',
  ),
  'clr.designPeak': (
    'não excedida em {p} % dos anos: {v}; o projeto usa {w}; capacidade {c}',
    'not exceeded in {p} % of the years: {v}; the design uses {w}; capacity {c}',
    'no excedida en el {p} % de los años: {v}; el diseño usa {w}; capacidad {c}',
  ),
  'clr.exceeded': ('excedido em {k} de {n} anos', 'exceeded in {k} of {n} years', 'excedido en {k} de {n} años'),
  'clr.reliability': ('{k} de {n} anos sem dia de déficit ({p} %)', '{k} of {n} years without a deficit day ({p} %)', '{k} de {n} años sin día de déficit ({p} %)'),
  'clr.worst': ('Piores anos', 'Worst years', 'Peores años'),
  'clr.drySpell': ('{n} dias a partir de {d}', '{n} days from {d}', '{n} días desde el {d}'),
  'clr.trend.title': ('Tendência', 'Trend', 'Tendencia'),
  'clr.trend': (
    '{v} por década (declive de Sen; teste de Mann-Kendall a 5 %: {s})',
    '{v} per decade (Sen\'s slope; Mann-Kendall test at 5 %: {s})',
    '{v} por década (pendiente de Sen; prueba de Mann-Kendall al 5 %: {s})',
  ),
  'clr.trend.sig': ('significativa', 'significant', 'significativa'),
  'clr.trend.ns': ('não significativa', 'not significant', 'no significativa'),
  // ---- quantities (the unit follows in brackets)
  'clr.q.eto': ('ETo do pico de {n} dias', 'Peak {n}-day ETo', 'ETo punta de {n} días'),
  'clr.q.peak': ('Demanda bruta do pico de {n} dias', 'Peak {n}-day gross demand', 'Demanda bruta punta de {n} días'),
  'clr.q.gross': ('Lâmina bruta necessária no ano', 'Gross irrigation needed in the year', 'Lámina bruta necesaria en el año'),
  'clr.q.volume': ('Volume bruto necessário no ano', 'Gross volume needed in the year', 'Volumen bruto necesario en el año'),
  'clr.q.pumped': ('Volume bombeado no ano (com a capacidade)', 'Volume pumped in the year (with the capacity)', 'Volumen bombeado en el año (con la capacidad)'),
  'clr.q.deficit': ('Dias abaixo da depleção permitida', 'Days past the allowed depletion', 'Días más allá del agotamiento permitido'),
  'clr.q.dry': ('Maior veranico', 'Longest dry spell', 'Mayor veranillo'),
  // ---- charts and tables
  'clr.chart.years': ('Ano a ano', 'Year by year', 'Año por año'),
  'clr.chart.curve': ('Curva de excedência (posições de Weibull)', 'Exceedance curve (Weibull positions)', 'Curva de excedencia (posiciones de Weibull)'),
  'clr.leg.year': ('ano', 'year', 'año'),
  'clr.leg.deficit': ('ano com déficit', 'year with a deficit', 'año con déficit'),
  'clr.tbl.stats': ('Risco climático: distribuição dos anos', 'Climate risk: spread of the years', 'Riesgo climático: distribución de los años'),
  'clr.tbl.years': ('Risco climático: ano a ano', 'Climate risk: year by year', 'Riesgo climático: año por año'),
  'clr.col.quantity': ('Grandeza', 'Quantity', 'Magnitud'),
  'clr.col.max': ('máx.', 'max', 'máx.'),
  'clr.col.project': ('Valor do projeto', 'Design figure', 'Valor del diseño'),
  'clr.col.note': ('Observação', 'Note', 'Observación'),
  'clr.col.year': ('Ano', 'Year', 'Año'),
  'clr.col.areas': ('Áreas com déficit', 'Areas with a deficit', 'Áreas con déficit'),
  // ---- notes on the data and the method
  'clr.reanalysis': (
    'Dados de reanálise (NASA POWER: MERRA-2 em células de cerca de 50 km) suavizam os extremos locais: uma estação no local pode mostrar picos de ETo maiores e veranicos mais longos. Os valores são uma referência, não uma garantia.',
    'Reanalysis data (NASA POWER: MERRA-2 over cells of about 50 km) smooth the local extremes: a station on the site may show higher peaks of ETo and longer dry spells. The figures are a reference, not a guarantee.',
    'Los datos de reanálisis (NASA POWER: MERRA-2 en celdas de unos 50 km) suavizan los extremos locales: una estación en el sitio puede mostrar picos de ETo mayores y veranillos más largos. Los valores son una referencia, no una garantía.',
  ),
  'clr.method': (
    'Método: ETo diária de Penman-Monteith e balanço hídrico do solo do FAO-56 (Allen et al. 1998, cap. 8); probabilidades com posições de Weibull i/(n+1); tendência pelo declive de Sen e pelo teste de Mann-Kendall; veranico = dias seguidos com menos de 1 mm (índice CDD do ETCCDI). Dias sem dados: ETo média do mês e chuva zero; anos com mais de 10 % de falhas ficam de fora.',
    'Method: FAO-56 daily Penman-Monteith ETo and soil water balance (Allen et al. 1998, ch. 8); probabilities with Weibull positions i/(n+1); trend by Sen\'s slope and the Mann-Kendall test; dry spell = consecutive days with less than 1 mm (ETCCDI index CDD). Days without data: the month\'s mean ETo and no rain; years with more than 10 % missing are left out.',
    'Método: ETo diaria de Penman-Monteith y balance hídrico del suelo de FAO-56 (Allen et al. 1998, cap. 8); probabilidades con posiciones de Weibull i/(n+1); tendencia por la pendiente de Sen y la prueba de Mann-Kendall; veranillo = días seguidos con menos de 1 mm (índice CDD de ETCCDI). Días sin datos: ETo media del mes y lluvia cero; los años con más del 10 % de faltas quedan fuera.',
  ),
  // ---- warnings ({n}: the area)
  'clr.w.clr_short': (
    'Menos de 10 anos completos: as probabilidades e a tendência são pouco firmes.',
    'Fewer than 10 complete years: the probabilities and the trend are weak.',
    'Menos de 10 años completos: las probabilidades y la tendencia son poco firmes.',
  ),
  'clr.w.clr_no_eto': ('A série não tem ETo (faltam temperaturas).', 'The series has no ETo (temperatures missing).', 'La serie no tiene ETo (faltan temperaturas).'),
  'clr.w.clr_no_areas': ('Nenhuma área com balanço hídrico.', 'No area with a water balance.', 'Ninguna área con balance hídrico.'),
  'clr.w.clr_fixed': (
    '{n}: lâmina diária fixa, sem balanço hídrico; fica de fora.',
    '{n}: a fixed daily depth, no water balance; left out.',
    '{n}: lámina diaria fija, sin balance hídrico; queda fuera.',
  ),
  'clr.w.clr_rainfed': (
    '{n}: o balanço salvo é de sequeiro; avaliado irrigando na depleção permitida.',
    '{n}: the balance kept is rainfed; evaluated irrigating at the allowed depletion.',
    '{n}: el balance guardado es de secano; evaluado regando en el agotamiento permitido.',
  ),
  'clr.w.clr_cycles': ('{n}: só o primeiro ciclo de cultivo é avaliado.', '{n}: only the first crop cycle is evaluated.', '{n}: solo se evalúa el primer ciclo de cultivo.'),
  'clr.w.clr_no_capacity': (
    '{n}: capacidade do sistema desconhecida; a confiabilidade reflete só a programação.',
    '{n}: system capacity unknown; the reliability reflects only the programme.',
    '{n}: capacidad del sistema desconocida; la confiabilidad refleja solo la programación.',
  ),
  'clr.w.clr_no_seasons': ('{n}: a série não cobre nenhuma safra completa.', '{n}: the series covers no complete season.', '{n}: la serie no cubre ninguna temporada completa.'),
  // ---- errors
  'clr.err.clr_no_areas': ('Nada a analisar: nenhuma área com balanço hídrico.', 'Nothing to analyse: no area with a water balance.', 'Nada que analizar: ningún área con balance hídrico.'),
  'clr.err.clr_no_series': (
    'O clima do local não tem série diária: baixe-o em Projeto → Clima do local ou use a NASA POWER.',
    'The site climate has no daily series: download it in Design → Site climate, or use NASA POWER.',
    'El clima del sitio no tiene serie diaria: descárguelo en Diseño → Clima del sitio o use NASA POWER.',
  ),
  'clr.err.clr_busy': ('Um cálculo está em andamento; aguarde o fim.', 'A design is running; wait until it ends.', 'Hay un cálculo en curso; espere a que termine.'),
  'clr.ai.op': ('Analisar o risco climático ao longo dos anos', 'Analyse the climate risk over the years', 'Analizar el riesgo climático a lo largo de los años'),
  'hist.clr': ('Risco climático', 'Climate risk', 'Riesgo climático'),
};
