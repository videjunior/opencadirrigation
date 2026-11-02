# Agronomia e manejo da irrigação

Projeto → Agronomia reúne o trabalho agronômico de um projeto além da necessidade mensal de
[Cálculo e dimensionamento](calculation.md#agronomia-máquinas-mecanizadas-e-calculadoras-de-campo): o balanço hídrico
diário do solo, o programa de rega do controlador, o escoamento potencial da aspersão, a fertirrigação por estágio da
cultura, a uniformidade no campo e as culturas que a tabela da FAO-56 não tem. Os diálogos leem o que o projeto já
traz: o clima do local (Projeto → Clima do local…), a cultura, o solo, o método de irrigação e a cobertura do solo de
cada área irrigada, os turnos e, quando importa, os resultados do cálculo. **Salvar**, em cada um deles, guarda as
configurações no projeto num passo de desfazer que mantém os resultados do cálculo; o arquivo do projeto as grava em
`agronomy` só quando diferem das de um projeto novo. As tabelas ficam na aba **Agronomia** no fim do painel de
relatórios e em toda exportação de relatório (PDF, Excel, CSV, TXT).

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
