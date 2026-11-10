# Agronomia e manejo da irrigação

Projeto → Agronomia reúne o trabalho agronômico de um projeto além da necessidade mensal de
[Cálculo e dimensionamento](calculation.md#agronomia-máquinas-mecanizadas-e-calculadoras-de-campo): o balanço hídrico
diário do solo, o programa de rega do controlador e o programa reproduzido na planta, a previsão de irrigação dos
próximos dias, o risco climático ao longo dos anos, o escoamento potencial da aspersão, a fertirrigação por estágio da
cultura, a uniformidade no campo e as culturas que a tabela da FAO-56 não tem. Os diálogos leem o que o projeto já
traz: o clima do local (Projeto → Clima do local…), a cultura, o solo, o método de irrigação e a cobertura do solo de
cada área irrigada, os turnos e, quando importa, os resultados do cálculo. **Salvar**, em cada um deles, guarda as
configurações no projeto num passo de desfazer que mantém os resultados do cálculo; o arquivo do projeto as grava em
`agronomy` só quando diferem das de um projeto novo. As tabelas ficam na aba **Agronomia** no fim do painel de
relatórios e em toda exportação de relatório (PDF, Excel, CSV, TXT). A previsão de irrigação e o reprodutor nunca
alteram o projeto; o risco climático guarda nele o seu resumo. No celular, todos os itens ficam em ☰ → Projeto, com o
mesmo nome.

Todas as tabelas do app aplicam a mesma regra à irrigação localizada: ETc,loc = Kr·Kc·ETo sobre a área inteira, com o
Kr pela cobertura do solo da área (ou digitado) e a fração molhada só na água facilmente disponível. O Kc médio e o
Kc final seguem a umidade mínima e o vento do clima do local (equações 62 e 65 da FAO-56), e o Kc inicial o intervalo
e a lâmina das irrigações na aspersão e na superfície (anexo 7 da FAO-56).

## Balanço hídrico diário do solo

*Balanço hídrico diário…* acompanha dia a dia a zona das raízes de uma área irrigada, pelo capítulo 8 da FAO-56 com o
coeficiente de cultura único da sua cultura: a cultura consome Kr·Kc·ETo, o coeficiente de estresse Ks corta o
consumo quando o esgotamento passa da água facilmente disponível, a chuva abaixo de 0,2·ETo evapora e o excesso
percola. A área precisa do balanço hídrico ligado nas suas Propriedades, com uma cultura (ou ETo e Kc digitados).

- **Quando irrigar**: no esgotamento permitido, a cada N dias, ou nunca (só chuva). Com *Déficit controlado por
  estágio*, cada um dos quatro estágios de desenvolvimento tem o seu esgotamento permitido como fração da água total
  disponível: até o fator p da cultura não há estresse, acima dele a cultura fica em déficit controlado.
- **Reposição** do esgotamento (%), o esgotamento no início e o clima: o ano típico das normais (com o número de
  chuvas por mês) ou um ano da série diária baixada ou lida de um arquivo de estação.
- **Resultados**: o período, as irrigações, a percolação profunda, os dias com estresse e o rendimento relativo pelo
  Ky sazonal da FAO-33 (0 usa o da cultura), com um gráfico do esgotamento contra a água facilmente disponível (RAW)
  e a água total disponível (TAW).

## Programa de rega

*Programa de rega…* distribui o funcionamento de cada turno como num controlador: os turnos rodam um após o outro a
partir do início da **janela diária de rega** (hora de início e duração; 24 h é sem janela), e a mensagem
`schedule_over_window` avisa quando os turnos de um dia não cabem nela. Com **ciclo e pausa**, o evento de uma zona
de aspersores cujo solo não absorve a sua intensidade é dividido em ciclos não mais longos que o tempo antes do
escoamento (com um ciclo mínimo e um máximo de ciclos por evento), e outros turnos rodam nas pausas. O **ajuste
sazonal** dá a cada mês a fração do tempo de rega do mês de projeto, pela necessidade mensal ou digitado. O resultado
é o programa por estação do controlador e por mês e os eventos do dia, ambos exportados em CSV, e a janela usada no
dia mais cheio contra as horas de pico; *Pôr o programa por estação e os eventos nos relatórios* os acrescenta aos
relatórios.

## Reproduzir o programa de rega na planta

*Reproduzir o programa na planta…* (ou **Reproduzir** no diálogo do Programa de rega) mostra o programa funcionando
no desenho. Ele precisa de um projeto calculado (F5) e de um programa com regas; senão, uma mensagem diz o que falta.
Um painel na parte de baixo tem *Voltar ao início do ciclo*, reproduzir e pausar, *Ir ao próximo início de turno*, a
velocidade (de 0,25 a 24 horas do programa por segundo), o relógio e o que está rodando, um controle deslizante sobre
o ciclo com as regas em blocos e as exportações. O desenho continua utilizável por baixo (mover, zoom, atalhos); o
painel sai da frente, e pausa, enquanto um diálogo está aberto ou outra aba é mostrada, e acompanha um cálculo novo no
mesmo momento.

A cada momento o desenho mostra as áreas dos turnos em operação destacadas, o alcance dos aspersores e os emissores
molhados, os tubos que levam água com a cor da velocidade (azul devagar, verde na metade da velocidade admitida,
laranja nela, vermelho a uma vez e meia ela) e mais grossos com mais vazão, as bombas ligadas (anel verde com raios
girando) ou desligadas (anel cinza com duas barras) e um painel com o relógio, os turnos em operação, a vazão total, a
pressão na saída das bombas ligadas (ou na fonte quando nenhuma bomba roda), as bombas ligadas e o nível de cada
reservatório. Entre as regas o sistema fica em repouso, com o desenho escurecido.

- **Quadro (PNG)**: o momento mostrado, com 1600 pixels no lado maior e uma faixa em cima com o relógio e os números.
- **Animação (GIF)…**: o ciclo inteiro, com 480 pixels no lado maior por padrão (de 320 a 800), um quadro a cada meia
  hora de um ciclo de um dia (48 quadros) ou a cada duas horas de um ciclo maior, mais um em cada rega curta demais
  para um passo; com o mapa de fundo quando escolhido (os mosaicos dele são baixados como os das imagens do
  assistente, do mapa da tela); progresso e Cancelar. A paleta tem até 256 cores por quadro (quantizador octree, sem
  pontilhado) e a animação se repete sem fim.
- **Calendário (.ics)…**: o programa para a agenda do celular do produtor (RFC 5545): um evento por início de cada
  turno (ou de cada ciclo do ciclo e pausa), na hora local onde quer que o celular esteja (hora "flutuante"), com a
  duração da rega, repetindo a cada ciclo do programa a partir de hoje pelos dias escolhidos (30 por padrão), com as
  zonas e o tempo de rega na descrição; os tempos são os do mês de projeto de cada área, ou de um mês escolhido.

**Método.** O ciclo é o período do próprio programa: cada turno roda a cada tantos dias, em dias escalonados, então o
programa se repete depois do mínimo múltiplo comum dos intervalos, um dia quando todos rodam diariamente (no máximo 28
dias são mostrados; um período maior é cortado, e o painel avisa). O ciclo é circular: uma rega que passa da
meia-noite do último dia continua no início. O estado de um momento é o resultado do cálculo para o turno que roda nele
(vazões, velocidades, pressões e bombas da solução em regime permanente daquele turno), mantido durante toda a rega.
Dois turnos sobrepostos no tempo (um programa que não cabe na janela) têm as vazões somadas nos tubos comuns e a maior
pressão na fonte, com aviso: o cálculo não os resolveu juntos. Um reservatório atrás de uma fonte segue a continuidade
do volume, dV/dt = entrada − saída, com a vazão que cada turno em operação tira e a curva cota–volume do estudo do
reservatório, a partir do nível definido para o início do dia; ele para no nível mínimo de operação (a captação seca) e
no nível cheio (verte), e o painel avisa.

**Limites.** O reprodutor mostra o regime permanente de cada turno, não o enchimento dos tubos nem os golpes nas trocas
de válvula (veja os transientes). O calendário não aplica o ajuste sazonal mês a mês: exporte de novo para outro mês.
As exportações são desenhadas na prancheta escura, enquadradas nos turnos, qualquer que seja o tema do app. O
assistente vê qualquer momento do programa com `programme_picture` e exporta a animação e o calendário com
`export_programme_animation` e `export_programme_calendar`.

## Previsão de irrigação

*Previsão de irrigação…* mantém o projeto útil depois da entrega do desenho: usa a previsão do tempo do local e diz,
para cada área irrigada e cada um dos próximos dias, se é para irrigar, a lâmina líquida e bruta, o tempo de
funcionamento com a taxa de aplicação do projeto e o **ajuste (water budget)**, em %, para digitar no controlador. Ela
precisa de um projeto georreferenciado com áreas irrigadas (cultura, solo e método, como para a tabela de
necessidade); calcule o projeto (F5) antes, para as taxas de aplicação reais, senão usa-se a vazão nominal dos
emissores e o diálogo avisa. O projeto nunca é alterado.

1. Escolha a fonte: *MET Norway* (o padrão; dados abertos livres para qualquer uso, também o profissional, com o
   crédito) ou *Open-Meteo* (a API gratuita dele é só para uso não comercial, e o diálogo avisa).
2. Diga como está o solo: *Cheio hoje* (acabou de irrigar ou de chover bem: o padrão) ou *Última irrigação ou chuva
   há alguns dias*, com há quantos dias e, se souber, a lâmina que entrou no solo.
3. Clique em **Buscar a previsão**. Nada é buscado antes disso. A resposta fica guardada neste aparelho enquanto o
   serviço diz que vale (no mínimo três horas para o MET Norway, uma para o Open-Meteo), e **Buscar de novo** espera
   até o serviço permitir outro pedido (o MET Norway pede para não repetir um pedido antes da hora de validade dele).
4. Leia a tabela: os dias nas colunas, a ETo e a chuva de cada dia no topo, depois cada área com o tempo programado por
   evento, o ajuste destes dias e, para cada dia, o tempo em minutos ou "não irrigar". A tabela dia a dia dá o
   estágio, o Kc, a ETc, a chuva efetiva, o esgotamento, as lâminas líquida e bruta e a fração de um evento
   programado. As duas tabelas exportam em CSV, XLSX ou PDF; a fonte, o crédito dela e a hora da busca aparecem com
   elas.

O assistente responde "quanto devo irrigar hoje?" com o mesmo plano (operação `irrigation_forecast`).

**Método.** O MET Norway dá valores horários nos dois ou três primeiros dias e de seis em seis horas depois (cerca de
nove dias e meio ao todo); eles viram dias solares locais (UTC + longitude/15): as temperaturas extremas, o ponto de
orvalho médio, o vento médio a 10 m levado a 2 m (eq. 47 da FAO-56) e a chuva de cada período contada uma vez. A ETo é
a Penman-Monteith da FAO-56 desses valores diários, com a radiação solar tirada da amplitude térmica (eq. 50 da
FAO-56, kRs 0,16), o procedimento da FAO-56 para radiação ausente, já que o MET Norway não publica radiação. O
Open-Meteo dá 16 dias de valores diários com a própria ETo FAO-56, usada como vem. A cultura é a da tabela de
necessidade e do balanço hídrico diário da área (a curva de Kc em cada data a partir da data de plantio lida para o
hemisfério do local, ETc,loc = Kr·Kc·ETo, TAW = AWC·Zr·Pw, RAW = p·TAW com p ajustado à ETc do dia, Ks quando o
esgotamento passa da RAW, eq. 84 da FAO-56); a chuva abaixo de 0,2·ETo só molha a superfície e a que passa da
capacidade de campo percola. Uma área é irrigada no dia em que o esgotamento chega à lâmina líquida de um evento da
programação do projeto, ou ao esgotamento permitido do estágio se for menor; a irrigação repõe o esgotamento (a fração
de reposição do balanço dela), a lâmina bruta é a líquida sobre a eficiência (com a lixiviação do mês) e o tempo é a
lâmina bruta sobre a taxa de aplicação. O ajuste é a água que a cultura usa nos dias da previsão menos a chuva que a
zona das raízes guarda, sobre o que a programação do projeto aplica em tantos dias do mês de projeto (de 0 a 300 %).

**Hipóteses e limites.** Previsão é incerta, e mais depois dos três primeiros dias: confira antes de irrigar e busque
de novo no dia seguinte. O solo é tomado como você disse (sem chuva desde a última irrigação; os dias entre elas usam a
ETo do mês do clima do local, ou a do primeiro dia da previsão quando o projeto não tem clima), e nenhuma chuva cai
depois do último dia da previsão. Quando restam poucas horas de hoje na previsão, a ETo de hoje é a de amanhã (o dia
fica marcado). Áreas com lâmina diária fixa não mudam com o tempo. Os dias são dias solares locais, que podem diferir
uma ou duas horas do relógio do local. A radiação tirada da amplitude térmica erra em dias nublados de grande
amplitude.

## Risco climático ao longo dos anos

*Risco climático ao longo dos anos…* (abaixo de *Balanço hídrico diário…*) mostra como o sistema, tal como projetado,
teria se saído em cada um dos últimos trinta a quarenta anos reais, ao lado do único valor para o qual foi
dimensionado (a ETo do mês de pico das normais, ou uma ETo de pico digitada). Ele precisa de um projeto
georreferenciado e de áreas irrigadas com cultura, solo e balanço hídrico ligado; não é preciso calcular o projeto
(F5), mas com o cálculo a capacidade usa as vazões dos emissores do projeto em vez das nominais.

1. Escolha a série diária: *NASA POWER*, a série diária pontual do local de 1984 até o último ano completo
   (temperatura, umidade, vento a 2 m, radiação solar, chuva), baixada só quando você clica em **Analisar** (cerca de
   2 MB em 9 partes, com barra de progresso e Cancelar) e guardada neste aparelho (Arquivo → Dados baixados
   guardados), de modo que a próxima análise a lê na hora, também sem rede; ou a *Série do clima do local*, a série
   diária guardada em Projeto → Clima do local (um arquivo de estação ou um download anterior), sem nada baixado. O
   crédito da série (o agradecimento que a NASA pede, para a NASA POWER) aparece com os resultados e fica com o resumo.
2. Escolha a **Probabilidade de não excedência** dos valores de projeto (50, 80, 90 ou 95 %; 80 % não é excedido em
   quatro anos de cada cinco) e o **Período de pico** (7, 10, 15 ou 30 dias; 30 compara com as normais mensais, 7 a 15
   com o armazenamento do solo).
3. Clique em **Analisar**. O resumo fica no projeto num passo de desfazer (a série, não) e aparece na aba *Manejo da
   irrigação* dos relatórios e em todas as exportações (as tabelas *Risco climático: distribuição dos anos* e *Risco climático: ano a
   ano*); refaça a análise depois de mudar o projeto, porque o resumo guardado não acompanha as mudanças.

Para o projeto e para cada área (**Mostrar**): P50, P80, P90, P95 e máximo da necessidade bruta anual de irrigação,
da demanda bruta do período de pico e da ETo do período de pico, ao lado do valor que o projeto usa e da capacidade do
sistema, com os anos em que o valor do projeto foi excedido; a confiabilidade (as safras em que o sistema projetado
manteve o solo acima do esgotamento permitido todos os dias, e os dias por ano em que não manteve); os piores anos, os
maiores veranicos, o volume bombeado por ano; a tendência do período (declive de Sen com o teste de Mann-Kendall a
5 %); um gráfico ano a ano (os anos com dias de déficit destacados) e a curva de excedência. O assistente roda a mesma
análise com `climate_risk`.

**Método.** A ETo de cada dia é a Penman-Monteith FAO (eq. 6 da FAO-56), com umidade, radiação ou vento ausentes
estimados como manda o capítulo 3 dela. Cada área roda o balanço hídrico diário do solo de *Balanço hídrico diário…*
(a cultura, a curva de Kc, a data de plantio, a profundidade das raízes, o p, o solo, o Kr e a fração molhada, a
eficiência e a lixiviação, e o critério salvo para ela; um balanço de sequeiro é avaliado irrigando no esgotamento
permitido), safra a safra e duas vezes: sem limite, o que dá a necessidade, e limitado à lâmina bruta que o sistema
aplica por dia, o que dá o que ele teria aplicado e os dias de déficit (dias de cultura que terminam com o esgotamento
acima do permitido: a RAW, ou o déficit controlado do estágio). A capacidade sob um pivô central ou linear é a lâmina
por volta sobre as horas de uma volta vezes a janela da programação; nas demais áreas é a intensidade de aplicação dos
emissores sobre a área vezes as horas que o turno dela pode funcionar, com a janela dividida entre os turnos na
proporção das horas que cada um precisa no dia de pico do projeto; uma irrigação a cada n dias pode aplicar n dias de
capacidade. A demanda do período de pico é a maior média, nos dias escolhidos, da ETc,loc menos a chuva retida na zona
das raízes, sobre a relação bruta/líquida do mês. Culturas de ciclo contam a partir da data de plantio (uma safra pode
entrar no ano seguinte, "2019/20"); culturas o ano todo, e os valores do próprio local, por ano agrícola, a partir do
primeiro dia do mês cuja chuva média mais supera a ETo média. As probabilidades são empíricas (posições de plotagem de
Weibull i/(n+1), interpoladas entre as posições, dentro dos anos observados: nenhuma distribuição ajustada, nada
extrapolado); a tendência é o declive de Sen e o teste de Mann-Kendall com a variância corrigida para empates, a
partir de 10 anos, sem remover a autocorrelação; um veranico é o maior número de dias seguidos com menos de 1 mm de
chuva (o índice CDD do ETCCDI). Um dia sem dados recebe a ETo média do mês da própria série e chuva zero, e uma safra
ou ano com mais de 10 % dos dias faltando fica de fora.

**Limites.** Dados de reanálise (NASA POWER: MERRA-2 em células de cerca de 50 km) suavizam os extremos locais: uma
estação no local pode mostrar picos de ETo maiores e veranicos mais longos. Os valores são uma referência, não uma
garantia. Só o primeiro ciclo de cultivo de uma área é avaliado; a percolação do arroz inundado não é somada;
escoamento superficial e ascensão capilar são tomados como zero, como no balanço diário. A capacidade é um limite
diário dividido na proporção das horas de pico do projeto, não uma programação do controlador setor a setor; com
reposições parciais o solo guarda espaço para a chuva, então o volume bombeado pode ficar abaixo da necessidade com
reposição total mesmo sem dias de déficit.

## Escoamento potencial

*Escoamento potencial…* compara a aplicação dos aspersores com o solo:

- **Pivôs centrais e lineares**, vão a vão: o padrão elíptico dos aspersores (o pico é 4/π da intensidade média,
  qualquer que seja a velocidade) contra a família de infiltração do NRCS do solo da área sob a máquina e o seu
  armazenamento superficial (NEH 623 cap. 4, NEH 652), com a primeira irrigação após o preparo do solo; dá a lâmina
  de cada passagem, o seu escoamento, a maior lâmina por passagem sem escoamento e o menor ajuste do percentímetro.
- **Áreas de aspersão**: a intensidade das zonas contra a infiltração básica do solo, com o tempo de um evento e o
  maior tempo sem escoamento.

## Fertirrigação por estágio

*Fertirrigação por estágio…* reparte as doses de N, P₂O₅ e K₂O do ciclo da cultura pelos quatro estágios da curva de
Kc (pelo consumo de água de cada estágio no ano típico, ou por frações digitadas) e as aplica nas irrigações do
estágio encontradas pelo balanço hídrico diário, a cada N delas: o produto de cada evento (primeiro os produtos de
fósforo e de potássio, com o nitrogênio deles contado, e o produto de nitrogênio para o resto), a solução estoque, a
sua taxa de injeção na parte do evento que injeta e a concentração ao injetar. O aumento da condutividade elétrica da
água vem dos sais dissolvidos (CE ≈ SDT/640, FAO-29; a ureia fica de fora) e é comparado com o que a cultura tolera
sem perda. A análise de Fertirrigação do menu Linha principal (tempos de chegada, plano de injeção, venturi) continua
como antes.

## Uniformidade no campo

*Uniformidade no campo…* tem três partes:

- **Lâmina de um evento do programa**: a intensidade de cada aspersor vezes as horas que a sua zona roda num evento,
  somada sobre as zonas, que é o que uma lata coletora mede; pode ser mostrada no desenho no lugar da intensidade do
  densograma.
- **Latas coletoras virtuais** dispostas numa grade sobre uma área (espaçamentos, rotação, diâmetro da boca, duração
  do teste), com a leitura que o projeto espera em cada lata, exportadas em CSV para montar um ensaio de campo.
- **Avaliações de campo**: os volumes lidos nas latas (linha a linha; `-` para lata perdida) ou as vazões de
  emissores medidas, com CU, DU e uniformidade estatística comparados com os do projeto. As avaliações ficam no
  projeto.

## Culturas do usuário

*Culturas do usuário…* acrescenta culturas que a tabela da FAO-56 não tem (maracujá, mamão, açaí, cacau,
pimenta-do-reino, eucalipto…) com a curva de coeficiente de cultura único da FAO-56: Kc inicial, médio e final, a
duração dos quatro estágios (todos 0 é uma perene com Kc médio o ano todo), o mês de plantio, a profundidade das
raízes, o fator p, a altura, o limite de salinidade, o Ky e a fonte dos valores. As áreas irrigadas as escolhem
depois das culturas da FAO-56 na sua lista de culturas e ganham a tabela mensal, o programa e o balanço hídrico.

## Arquivos de estação meteorológica

Projeto → Clima do local… → *Importar arquivo de estação…* lê os arquivos CSV das estações automáticas do INMET
(Instituto Nacional de Meteorologia: os arquivos horários do portal de dados históricos, um por estação e ano, ou um
zip com vários anos) e as exportações do BDMEP (linhas diárias ou horárias). As horas, em UTC, vão para o dia local
pela longitude, os dias com poucas horas ficam de fora, o vento a 10 m é levado a 2 m (equação 47 da FAO-56) e a ETo
diária sai por Penman-Monteith; o arquivo dá as normais mensais da estação e a série diária do balanço hídrico. A aba
*Normais da estação* do mesmo diálogo recebe as médias mensais de qualquer estação (temperaturas, umidade, vento,
insolação, chuva; células vazias estimadas como manda a FAO-56) e calcula a ETo delas por Penman-Monteith.

## Verificações

A verificação do projeto e a aba Mensagens também comparam o sistema com as culturas:

| Código | Significado |
|---|---|
| `capacity_below_peak` | O sistema não aplica a necessidade bruta do mês de maior demanda dentro da janela de rega (24 h quando não há janela): os turnos rodam um após o outro, cada um pelo tempo da área das suas zonas que mais precisa de horas |
| `pivot_capacity_below_peak` | Um pivô central ou linear cuja lâmina por volta nas horas da janela fica abaixo da necessidade bruta de pico da área sob ele |
| `pivot_runoff` | Escoamento sob a máquina: na ponta, a intensidade de pico dos aspersores passa da infiltração do solo além do que a superfície retém |
| `area_rate_exceeds_soil`, `area_eto_climate`, `area_planting_date`, `area_leaching_infeasible` | Aspersores de uma área aplicando mais do que o solo e a sua declividade absorvem (com o ciclo e pausa que o evita), uma ETo digitada numa área diferente da do clima do local, uma data de plantio ambígua ou inválida, água salina demais para a cultura |

## Os exemplos da galeria

As áreas de gotejamento e de microaspersão da galeria de exemplos levam a cobertura do solo da sua cultura em vez de
uma cobertura total, pela equação 76 da FAO-56 com o Kcb médio e a altura da cultura e Kr = 0,1·√Pd (Keller e
Bliesner): uva 0,25 (Kr 0,50), tomate 0,88 (0,94), pimentão 0,75 (0,87), café 0,6 (0,77), as hortaliças do exemplo
por gravidade 0,73 (0,85) e banana 0,68 (0,82). As lâminas e os tempos de rega delas são menores que nas versões
anteriores; o jardim (regado pelo fator de planta das suas hidrozonas) e a cana (cobertura total) ficam em 1.
