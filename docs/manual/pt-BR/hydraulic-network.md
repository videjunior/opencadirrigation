# Rede hidráulica

## Entidades hidráulicas

| Entidade | Alias | Camada | Papel no cálculo |
|---|---|---|---|
| Fonte de água | `WS` | WATER_SUPPLY | Origem da linha principal. Pressão calculada (poço com nível negativo, reservatório com altura positiva) ou fixa (rede pública com pressão e vazão de projeto e máximas). *Reservatório ou açude…* nas Propriedades a liga a um reservatório: o contorno fechado da água no nível cheio, um açude (o terreno dentro do contorno) ou um reservatório escavado (fundo plano e taludes), os níveis cheio, mínimo e de início e a vazão que entra; dá a curva cota–área–volume pelo terreno, o volume útil, o corte de uma escavação, os dias de demanda e o tempo de enchimento, o projeto bombeia a partir do nível mínimo e a simulação de 24 horas deixa o nível descer e subir. |
| Bomba | `PU` | PUMPS | Curva H(Q) do catálogo, com relação de velocidade, ou um inversor de frequência que mantém uma pressão alvo na saída entre uma rotação mínima e a máxima; curvas de rendimento e de NPSH requerido quando o catálogo as traz; rendimento do motor e do inversor; ponto de operação no cálculo dos turnos; horímetro opcional; um volante de inércia (kg·m²) que torna mais lenta a parada da bomba nos transientes. *Estação de bombeamento…* faz do item uma estação: a bomba dele e as que vêm depois, ligadas em paralelo (somam a vazão) ou em série (somam a altura), em serviço ou de reserva, com partida escalonada pela vazão de cada turno; o cálculo resolve a curva das bombas que funcionam juntas e dá o ponto de cada uma, e as bombas de reserva vão para a lista de materiais. |
| Tubo principal | `MP` | MAINLINE_PIPES | Da fonte às válvulas; diâmetro fixo ou dimensionado (`computerSized`). |
| Válvula de zona | `V` | CONTROL_VALVES | Separa linha principal e zona; define o nome da zona; pode ter pressão de jusante fixa para análise detalhada, e um piloto: redutor de pressão (a pressão mantida a jusante), sustentador de pressão (a pressão mantida a montante) ou os dois. |
| Tubo de zona | `ZP` | ZONE_PIPES | Linhas de derivação e distribuidores a jusante da válvula. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Tubo com emissores igualmente espaçados: emissor e bocal do catálogo, espaçamento, deslocamento do primeiro, arco, altura da haste, profundidade. |
| Fita / tubo gotejador | `DT` | TAPES | Emissores integrados definidos pelo item do catálogo; pressão de entrada, regulada ou não, vazão de lavagem. |
| Emissor individual | `OUT` | OUTLETS | Aspersor, microaspersor, gotejador, borbulhador, canhão ou ponto de demanda sobre um tubo de zona. Desenhado na linha principal é um aspersor com válvula (valve-in-head): uma estação própria, ou uma estação junto com os aspersores que têm o mesmo nome de estação. |
| Acessório | `F` | MISC_HYDRAULIC | Registro, filtro, regulador de pressão (com ajuste), válvula sustentadora de pressão (ajuste a montante), hidrante com limitador de vazão (ajuste de vazão), válvula mestra, hidrômetro, anti-refluxo, ventosa, válvula de retenção; em zona ou linha principal. Válvulas mestras, de bloqueio e outras também podem ter piloto redutor ou sustentador. |
| Junção | `J` | JUNCTIONS | Nó explícito, com cota fixa opcional. Na linha principal, um vaso de ar (reservatório hidropneumático: volume, ar em regime, diâmetro da ligação, preço) que os transientes e a lista de materiais levam em conta. |
| Área irrigada | `AR` | AREAS | Polígono com cultura (da tabela FAO-56 ou texto livre) e data de plantio, classe textural e declividade do solo, método de irrigação, cobertura do solo, salinidade da água, método de chuva efetiva, lâmina líquida ou balanço hídrico (ETo, Kc, CAD, profundidade radicular, fração de esgotamento), eficiência, fração molhada, emissores por planta e, no paisagismo, o uso de água das plantas da sua hidrozona. Pode ter ilhas que não são irrigadas (Editar → Geometria → Subtrair da área): a sua área e a sua água são líquidas, as ferramentas automáticas ficam fora delas e as exportações as levam. Um contorno desenhado ou editado cruzando a si mesmo é avisado na hora. |
| Pivô central / linear | `PV` | PIVOTS | Máquina com raio, vãos, profundidade de lâmina, ciclo, pressão final, canhão final, custo. Demanda sobre a linha principal; os dados da máquina (pacote de aspersores, transmissão e temporizador, braço de canto, prescrição de taxa variável, alimentação elétrica) abrem pelas Propriedades. |
| Controlador | `CTRL` | CONTROLLERS | Programador de irrigação: estações, tensão de saída (24 V CA), máximo de estações juntas, custo, sensores e acessórios (sensores de chuva, umidade do solo, vazão, geada e vento, relé de partida da bomba, proteção contra surtos). Alimenta os solenoides das válvulas pelas rotas de fios. |
| Rota de fios | `WR` | WIRES | Caminho dos fios do controlador passando pelas válvulas (vala ou eletroduto), desenhado à mão ou pelas Rotas automáticas de fios. Rotas que compartilham um vértice se unem; um controlador ou válvula sobre um vértice ou sobre a rota entra nela. |
| Faixa de carretel | | TRAVELLERS | Uma faixa de carretel enrolador a partir do hidrante na linha principal (Linha principal → Faixas de carretel…): um ponto de demanda da linha principal na vazão e na pressão que o canhão pede ([Energia, água e máquinas](power-water-machines.md#faixas-de-carretel-e-sulcos)). |
| Conjunto de sulcos | | SURFACE_IRRIGATION | Sulcos alimentados por um tubo janelado a partir de uma entrada na linha principal (Linha principal → Sulcos com tubo janelado…): um ponto de demanda na vazão dos sulcos irrigados juntos e na pressão do tubo janelado. |

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
  a ele, e toda lateral fica conectada. Fileiras mais longe da guia do que o raio das curvas dela,
  ou que contornam um canto vivo dela, são arredondadas ou cortadas, e o bloco avisa. A seção
  **Comprimento máximo da lateral** calcula até onde uma lateral pode ir a partir da entrada antes que
  a vazão dos emissores varie mais que o admitido (10 % por padrão, a regra usual; cerca de 20 % da
  pressão nos aspersores), subindo e descendo, no declive do terreno ajustado sobre o bloco (em nível
  sem terreno), dentro da janela de pressão do emissor e do limite de velocidade, para a fita ou o
  emissor e o tubo de lateral escolhidos; diz o que a limita e avisa quando a lateral mais longa do
  desenho passa do máximo.
- **Grade de aspersores** (AH): polígono, aspersor e bocal, espaçamentos, padrão quadrado ou
  triangular, direção e pressão de projeto.
- **Densograma** (Zona → Densograma, `DENS`): mapa da água aplicada pelos aspersores e
  microaspersores como estão desenhados (posição, arco, orientação e, depois do cálculo, a pressão
  de cada um), com CU de Christiansen, DU do quarto inferior, coeficiente de programação (média
  sobre os 5 % mais secos) e pontos secos, medidos dentro de cada área irrigada contra a sua própria
  média (um gramado de sprays ao lado de um de rotores é julgado à parte); o perfil radial medido do
  bocal quando o catálogo o tem, senão um perfil triangular, elíptico ou uniforme; um vento opcional
  (velocidade e direção) que desloca a água a sotavento; tamanho da célula, zonas; o mapa aparece no
  desenho e a grade é exportada em CSV. O coeficiente de programação usa a janela contígua mais seca
  de 5 % da área, e Projeto → Agronomia → Uniformidade no campo mostra a lâmina de um evento do
  programa no lugar da intensidade ([Agronomia e manejo da irrigação](agronomy.md#uniformidade-no-campo)).
- **Envelope de posição da linha de derivação** (FE): para cada lateral selecionada, pinta em verde o trecho
  onde a linha de derivação pode alimentá-la respeitando a janela de pressão, considerando o terreno.

## Projeto automático (Projeto → Projeto automático)

Cada ferramenta mostra o resultado depois de uma pausa, em etapas com progresso e Cancelar, e o gera
num único passo de desfazer. As ilhas de uma área irrigada e as formas fechadas selecionadas dentro do
contorno (um lago, um galpão, um poço) são exclusões: laterais, anéis e aspersores as contornam, e os
blocos têm áreas líquidas. SUBDIV e LAYOUT têm o mesmo comprimento máximo da lateral do gerador de
blocos (o SUBDIV preenche o comprimento com *Usar o máximo calculado*; o LAYOUT o compara com o
caminho mais longo das zonas traçadas); as zonas traçadas nunca dividem uma válvula entre áreas de
uso de água diferente (hidrozonas), e os tubos ficam dentro do contorno do lote.

| Ferramenta | Alias | O que faz |
|---|---|---|
| Layout automático de aspersores | `LAYOUT` | Aspersores para um gramado ou canteiro (cantos, depois bordas, depois o interior, cabeça a cabeça, deixando de fora edificações e canteiros) com bocais de precipitação equivalente e a prévia de CU/DU/SC; opcionalmente zoneados por vazão (sem misturar classes de precipitação) e com o traçado: válvulas na linha principal, junto às zonas ou num cavalete, tubos de zona em árvore pelos aspersores e uma linha principal em árvore desde a fonte. |
| Modelos de gramado esportivo e golfe | `TPL` | Campo de futebol com 3, 4 ou 5 linhas de rotores, gramado interno de pista de atletismo, green de golfe cercado de setores, tee e fairway em malha triangular. |
| Dividir talhão em blocos | `SUBDIV` | Blocos de mesma área líquida, limitados por área ou por vazão, em faixas ou em grade, com carreadores, cada um com o lado da linha de derivação e a válvula, preenchidos pelo gerador de blocos e alimentados por uma linha principal. |
| Anéis de gotejamento em pomar | `RINGS` | Um anel de tubo gotejador ou de gotejadores em volta de cada árvore de uma malha de plantio ou de árvores levantadas, ligado a laterais ao longo das fileiras, a uma linha de derivação e à válvula. |
| Ajustar pivô ao talhão | `PFIT` | O maior círculo completo livre dos obstáculos, ou o pivô setorial que irriga a maior parte do talhão, com o comprimento da máquina em vãos padrão. |
| Vários pivôs na propriedade | | O arranjo de pivôs centrais de vãos padronizados que irriga a maior parte do contorno selecionado, dentro da vazão permitida, com a linha principal comum ([Energia, água e máquinas](power-water-machines.md#vários-pivôs-na-propriedade)). |
| Fileiras da imagem | | A direção, o espaçamento e o número das fileiras de plantio de um pomar, cafezal, vinhedo, citros ou olival lidos na imagem de satélite ou numa foto aérea colocada no desenho, com o espaçamento entre plantas e a cobertura do solo pela copa quando a imagem os mostra; viram o padrão de Dividir talhão em blocos, Anéis de gotejamento em pomar e Bloco de laterais sobre a área ([abaixo](#fileiras-da-imagem)). |
| Detectar vegetação na imagem | `VEG` | Gramados, árvores e arbustos encontrados por processamento de imagem neste aparelho (sem serviço externo) no mapa base da tela ou numa foto aérea selecionada, criados como áreas irrigadas (com predefinições por classe) e exclusões. Confira se os termos de uso das imagens permitem traçar sobre elas. |
| Contornar pela imagem (menu Desenhar) | `WAND` | Clique dentro de um talhão, gramado ou lago no mapa: o contorno cresce pelos pixels de cor parecida dos blocos de satélite, com uma prévia da área e da borda; a tolerância de cor (0 = automática), a suavização das cores (3–6 m em pomares) e a simplificação do contorno o mudam sem baixar de novo; Enter cria uma área irrigada ou uma polilinha fechada (um passo de desfazer), Esc o descarta e `V` contorna todos os talhões da vista. Precisa de georreferência e de internet. |

### Fileiras da imagem

As laterais de gotejamento num pomar, num cafezal, num vinhedo, em citros ou num olival seguem as fileiras de plantio
que já existem no campo. **Projeto → Projeto automático → Fileiras da imagem…** (no celular, ☰ → Projeto, com o mesmo
nome) lê essas fileiras na imagem aérea em vez de medi-las à mão. Selecione a área irrigada do campo plantado (ou um
contorno fechado; com uma só área no projeto não é preciso selecionar) e abra a ferramenta. A imagem de satélite
precisa de um projeto georreferenciado (Arquivo → Georreferência); uma foto aérea colocada sobre o campo pode ser
escolhida em *Imagem*. A ferramenta baixa a imagem do campo e a lê neste aparelho, sem chave de IA e sem outro
serviço:

- **Direção das fileiras**, em graus no sentido anti-horário a partir do leste, de 0 a 180 (a mesma *Direção das
  fileiras (°)* de Dividir talhão em blocos e Anéis de gotejamento em pomar);
- **Espaçamento entre fileiras**, **Fileiras no campo** e a **Confiança** (fileiras claras a partir de 35 %, incerta a
  partir de 15 %, nenhuma fileira abaixo);
- o **Espaçamento entre plantas** (quando aparecem copas separadas) e a **Cobertura do solo pela copa** (quando a copa
  se distingue do solo); senão, "não visível na imagem".

A imagem mostra o campo (ciano) e as fileiras encontradas (âmbar), com um detalhe do meio do campo em tamanho real, e
as fileiras aparecem sobre o desenho enquanto o diálogo está aberto; **Parar** encerra uma leitura longa. Se as linhas
caíram nas entrelinhas e não nas plantas (copa fechada com entrelinhas na sombra, cobertura verde tão verde quanto a
cultura), ligue **Fileiras na outra faixa**, que as move meio espaçamento. *Espaçamento mínimo* e *Espaçamento máximo*
limitam a busca (1,5 a 12 m por padrão); o mínimo também define o tamanho de pixel pedido à imagem. **Aplicar** grava,
num só passo de desfazer, a direção das fileiras (o `rdir` da área) e o espaçamento, e o espaçamento entre plantas, na
área, de onde Dividir talhão em blocos, Anéis de gotejamento em pomar e Bloco de laterais (e os layouts do assistente)
partem sobre essa área; a cobertura do solo da área (usada no Kr da irrigação localizada); e, se marcado, as fileiras
como linhas-guia na camada `CROP_ROWS`. O assistente faz o mesmo com `detect_crop_rows` (uma leitura que não muda nada)
e `apply_crop_rows`.

**Método.** A cor do campo passa por um filtro passa-alta (subtrai-se a média numa janela de 1,25 × o maior
espaçamento: somem o sombreamento e as manchas, ficam as listras), é dividida pelo seu RMS local para que partes
escuras e claras pesem igual e é projetada na sua primeira componente principal, com o sinal que deixa positiva a faixa
mais verde e mais escura. Para cada direção (passos de no máximo 1°) os pixels de blocos quadrados do campo são
agrupados pela distância medida transversalmente a essa direção (uma projeção de Radon discreta), e a parcela da
variância que os grupos explicam (R²) é a média dos blocos: as fileiras dão um máximo agudo na sua direção. O
espaçamento é o primeiro pico da autocorrelação dos perfis dos blocos; a direção é então refinada no campo inteiro
(até cerca de 0,1° num campo de cem espaçamentos de comprimento) e o espaçamento na potência de Fourier do perfil do
campo inteiro (dentro de ±6 %, por uma parábola no logaritmo da potência), cuja fase posiciona as fileiras. Confiança =
destaque angular (1 − R² mediano ÷ maior R²) × periodicidade (a autocorrelação no espaçamento). O espaçamento entre
plantas é o primeiro pico da autocorrelação ao longo do centro das fileiras; a cobertura do solo é a fração do campo
acima do limiar de Otsu do sinal suavizado, dada só quando o histograma tem duas populações (coeficiente de
bimodalidade acima de 5/9). O método e as referências estão no [estudo técnico](../../PESQUISA.pt-BR.md#201-fileiras-de-plantio).

**Limites.** As fileiras precisam ser retas na área (fileiras em nível que curvam dão uma direção média e um aviso:
desenhe áreas menores), igualmente espaçadas e visíveis, com pelo menos uns três pixels da imagem por espaçamento: a
imagem Esri tem cerca de 0,3–0,6 m por pixel na maior parte das lavouras, então fileiras a menos de cerca de 1–2 m não
aparecem, e a ferramenta avisa. Qual faixa é a cultura é decidido pela cor (a mais verde e escura, ou a mais larga
quando as duas são verdes e a outra é claramente mais larga): confira o detalhe e use *Fileiras na outra faixa* quando
preciso. Sombras contam como copa na cobertura do solo. Um campo maior que o orçamento de pixels (2,5 milhões de
pixels) é lido numa janela no meio dele e as fileiras são estendidas ao campo todo. A imagem pode ter anos: confira que
ela mostra o plantio de hoje e que os termos de uso dela permitem tirar dados dela.
