# Rede hidráulica

## Entidades hidráulicas

| Entidade | Alias | Camada | Papel no cálculo |
|---|---|---|---|
| Fonte de água | `WS` | WATER_SUPPLY | Origem da linha principal. Pressão calculada (poço com nível negativo, reservatório com altura positiva) ou fixa (rede pública com pressão e vazão de projeto e máximas). |
| Bomba | `PU` | PUMPS | Curva H(Q) do catálogo, com relação de velocidade, ou um inversor de frequência que mantém uma pressão alvo na saída entre uma rotação mínima e a máxima; curvas de rendimento e de NPSH requerido quando o catálogo as traz; ponto de operação no cálculo dos turnos; horímetro opcional. |
| Tubo principal | `MP` | MAINLINE_PIPES | Da fonte às válvulas; diâmetro fixo ou dimensionado (`computerSized`). |
| Válvula de zona | `V` | CONTROL_VALVES | Separa linha principal e zona; define o nome da zona; pode ter pressão de jusante fixa para análise detalhada. |
| Tubo de zona | `ZP` | ZONE_PIPES | Linhas de derivação e distribuidores a jusante da válvula. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Tubo com emissores igualmente espaçados: emissor e bocal do catálogo, espaçamento, deslocamento do primeiro, arco, altura da haste, profundidade. |
| Fita / tubo gotejador | `DT` | TAPES | Emissores integrados definidos pelo item do catálogo; pressão de entrada, regulada ou não, vazão de lavagem. |
| Emissor individual | `OUT` | OUTLETS | Aspersor, microaspersor, gotejador, borbulhador, canhão ou ponto de demanda sobre um tubo de zona. Desenhado na linha principal é um aspersor com válvula (valve-in-head): uma estação própria, ou uma estação junto com os aspersores que têm o mesmo nome de estação. |
| Acessório | `F` | MISC_HYDRAULIC | Registro, filtro, regulador de pressão (com ajuste), válvula sustentadora de pressão (ajuste a montante), hidrante com limitador de vazão (ajuste de vazão), válvula mestra, hidrômetro, anti-refluxo, ventosa, válvula de retenção; em zona ou linha principal. |
| Junção | `J` | JUNCTIONS | Nó explícito, com cota fixa opcional. |
| Área irrigada | `AR` | AREAS | Polígono com cultura (da tabela FAO-56 ou texto livre) e data de plantio, classe textural e declividade do solo, método de irrigação, cobertura do solo, salinidade da água, método de chuva efetiva, lâmina líquida ou balanço hídrico (ETo, Kc, CAD, profundidade radicular, fração de esgotamento), eficiência, fração molhada, emissores por planta e, no paisagismo, o uso de água das plantas da sua hidrozona. |
| Pivô central / linear | `PV` | PIVOTS | Máquina com raio, vãos, profundidade de lâmina, ciclo, pressão final, canhão final, custo. Demanda sobre a linha principal; os dados da máquina (pacote de aspersores, transmissão e temporizador, braço de canto, prescrição de taxa variável, alimentação elétrica) abrem pelas Propriedades. |
| Controlador | `CTRL` | CONTROLLERS | Programador de irrigação: estações, tensão de saída (24 V CA), máximo de estações juntas, custo, sensores e acessórios (sensores de chuva, umidade do solo, vazão, geada e vento, relé de partida da bomba, proteção contra surtos). Alimenta os solenoides das válvulas pelas rotas de fios. |
| Rota de fios | `WR` | WIRES | Caminho dos fios do controlador passando pelas válvulas (vala ou eletroduto), desenhado à mão ou pelas Rotas automáticas de fios. Rotas que compartilham um vértice se unem; um controlador ou válvula sobre um vértice ou sobre a rota entra nela. |

## Regras de conexão

- **Vértices coincidentes conectam.** Dois tubos que compartilham um vértice (dentro da tolerância
  de conexão, 0,05 m por padrão) formam um nó. Um tubo que termina no meio de outro é ligado por um
  tê automático. Emissores, válvulas, bombas e acessórios colocados sobre um tubo dividem o tubo.
- **A válvula separa os mundos.** Tudo a jusante de uma válvula de zona pertence àquela zona; a
  linha principal vai da fonte até as válvulas. Itens de zona não se ligam a itens de linha
  principal sem uma válvula entre eles.
- **Fitas e laterais não se tocam entre zonas.** Como vértices coincidentes conectam, as pontas de
  fitas de talhões vizinhos devem ficar afastadas (uma faixa de manejo entre blocos), ou as duas
  zonas serão calculadas como uma só. A verificação de projeto avisa sobre itens desconectados,
  tubos cruzados sem junção e pontas soltas.
- **Laterais são agrupadas.** Cada lateral vira, no grafo, uma sequência de nós com emissores
  agregados (até 100 nós por lateral por padrão, ajustável), o que mantém o cálculo rápido mesmo com
  centenas de emissores por linha.
- **Estações de aspersores com válvula entram nos turnos como válvulas.** Um aspersor na linha
  principal abre quando a sua estação está ligada. Os turnos listam as estações ao lado das válvulas
  de zona e dos pivôs; uma estação listada por algum turno só funciona nesses turnos, na pressão
  nominal, e uma que nenhum turno lista funciona em todos (e é apontada). O controlador liga cada
  estação como uma válvula, com os solenoides dos seus aspersores em paralelo.
- **Fios têm grafo próprio.** Rotas de fios não tocam a rede hidráulica: cada válvula alcançada a
  partir de um controlador pelas rotas recebe uma estação (a válvula mais próxima é a estação 1) e
  um fio de estação próprio; todas compartilham o fio comum ao longo das rotas. Uma válvula mestra
  abre junto com todas as zonas, na saída 0.

## Geradores

- **Bloco de laterais** (B): polígono, direção, espaçamento entre laterais, deslocamento da primeira,
  lateral com emissores ou fita, posição da linha de derivação (início, centro, fim), válvula (posição e modelo),
  comprimento do pé de válvula (stub), nomes. Se uma linha, polilinha, curva de nível ou spline
  estiver selecionada ao abrir o diálogo, ela pode servir de guia: as laterais seguem a curva
  (paralelas a uma curva de nível ou a uma divisa curva) e são recortadas pelo polígono. A linha de derivação
  passa pelo ponto de alimentação de cada fileira no lado escolhido, contornando por dentro do
  talhão onde uma fileira não alcança essa linha (talhão em L); fileiras que o polígono corta em
  vários pedaços (talhão em U, fileira curva recortada em dois) são alimentadas por ramais ligados
  a ele, e toda lateral fica conectada.
- **Grade de aspersores** (AH): polígono, aspersor e bocal, espaçamentos, padrão quadrado ou
  triangular, direção e pressão de projeto.
- **Densograma** (Zona → Densograma, `DENS`): mapa da água aplicada pelos aspersores e
  microaspersores como estão desenhados (posição, arco, orientação e, depois do cálculo, a pressão
  de cada um), com CU de Christiansen, DU do quarto inferior, coeficiente de programação (média
  sobre os 5 % mais secos) e pontos secos, medidos dentro de cada área irrigada contra a sua própria
  média (um gramado de sprays ao lado de um de rotores é julgado à parte); o perfil radial medido do
  bocal quando o catálogo o tem, senão um perfil triangular, elíptico ou uniforme; um vento opcional
  (velocidade e direção) que desloca a água a sotavento; tamanho da célula, zonas; o mapa aparece no
  desenho e a grade é exportada em CSV.
- **Envelope de posição da linha de derivação** (FE): para cada lateral selecionada, pinta em verde o trecho
  onde a linha de derivação pode alimentá-la respeitando a janela de pressão, considerando o terreno.

## Projeto automático (Projeto → Projeto automático)

Cada ferramenta mostra o resultado ao vivo e o gera num único passo de desfazer.

| Ferramenta | Alias | O que faz |
|---|---|---|
| Layout automático de aspersores | `LAYOUT` | Aspersores para um gramado ou canteiro (cantos, depois bordas, depois o interior, cabeça a cabeça, deixando de fora edificações e canteiros) com bocais de precipitação equivalente e a prévia de CU/DU/SC; opcionalmente zoneados por vazão (sem misturar classes de precipitação) e com o traçado: válvulas na linha principal, junto às zonas ou num cavalete, tubos de zona em árvore pelos aspersores e uma linha principal em árvore desde a fonte. |
| Modelos de gramado esportivo e golfe | `TPL` | Campo de futebol com 3, 4 ou 5 linhas de rotores, gramado interno de pista de atletismo, green de golfe cercado de setores, tee e fairway em malha triangular. |
| Dividir talhão em blocos | `SUBDIV` | Blocos de mesma área líquida, limitados por área ou por vazão, em faixas ou em grade, com carreadores, cada um com o lado da linha de derivação e a válvula, preenchidos pelo gerador de blocos e alimentados por uma linha principal. |
| Anéis de gotejamento em pomar | `RINGS` | Um anel de tubo gotejador ou de gotejadores em volta de cada árvore de uma malha de plantio ou de árvores levantadas, ligado a laterais ao longo das fileiras, a uma linha de derivação e à válvula. |
| Ajustar pivô ao talhão | `PFIT` | O maior círculo completo livre dos obstáculos, ou o pivô setorial que irriga a maior parte do talhão, com o comprimento da máquina em vãos padrão. |
| Detectar vegetação na imagem | `VEG` | Gramados, árvores e arbustos encontrados por processamento de imagem neste aparelho (sem serviço externo) no mapa base da tela ou numa foto aérea selecionada, criados como áreas irrigadas (com predefinições por classe) e exclusões. Confira se os termos de uso das imagens permitem traçar sobre elas. |
