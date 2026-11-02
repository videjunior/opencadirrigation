# Relatórios, plotagem e exportação

## Painel de relatórios

Abas: resumo das zonas, tubos, emissores, linha principal e duty (com os acessórios), lista de
materiais, requisitos hídricos, linha piezométrica (gráfico do tubo, lateral ou válvula selecionada,
com a banda de pressão admissível), mensagens, perfil (terreno ao longo de um caminho, com tubo e
linha piezométrica), lavagem, golpe de aríete, agronomia (ETc, água prontamente disponível,
intervalo, lâminas, horas por evento), programação (calendário do controlador por turno), pivôs e
vãos do pivô, elétrico (estação, comprimento de rota e de fio, fio de estação e comum, válvulas
abertas juntas e tensão no solenoide de cada válvula; estações usadas, comprimento do comum e
corrente de pico de cada controlador), orçamento, valas (volumes e o cronograma de obra), materiais
por setor, comentários, revisões, alternativas, necessidade por cultura (com a categoria de
licenciamento), pacote do pivô (carta de bocais e temporizador), braço, VRI e elétrica, e aspersores
com válvula. As tabelas são virtualizadas, com colunas medidas pelo conteúdo, e servem de base para
todos os exportadores, de modo que PDF, Excel e CSV mostram os mesmos números.

## Pranchas em PDF

Arquivo → Exportar desenho → PDF abre as opções de plotagem: tamanho (A4 a A0, Letter, Tabloid),
orientação, escala (automática ou fixa), margem, raios molhados, rótulos, legenda de camadas, lista
de materiais na prancha, o mapa base da tela sob o desenho (com o crédito do provedor) e páginas de
relatório anexadas. Um PDF pode trazer um **conjunto de folhas**: uma folha, ou uma visão geral mais
uma folha por zona ou por área irrigada (cada uma enquadrada no seu assunto com os seus materiais,
as outras zonas em cinza ou ocultas), e a vista atual da tela como folha extra na sua própria
escala; depois os **detalhes construtivos** (vala, bloco de ancoragem, caixa de válvula, haste de
aspersor e junta articulada, conexão da linha gotejadora, ventosa, cabeçal de filtragem, sucção da
bomba) desenhados com os tubos, profundidades, modelos e pressões do próprio projeto; e os
**gráficos** (a linha piezométrica da linha principal em cada turno, o perfil do terreno e as
curvas das bombas com os pontos de operação). Nuvens de revisão e comentários em aberto saem nas
folhas, e a tabela de revisões os lista sob a legenda. A cena é montada em "espaço do papel": pena,
símbolos e textos em milímetros de papel, para que 1:500 e 1:2000 fiquem igualmente legíveis. O
carimbo traz os detalhes do projeto, a seta norte e a escala gráfica.

O escritor PDF é próprio (PDF 1.4, compressão Flate), sem dependências nativas: o texto que a
Helvetica representa fica em Helvetica, e qualquer outra escrita (cirílico, grego, vietnamita,
árabe, urdu, hindi, marati, bengali, panjabi, télugo, chinês, japonês) é composta com subconjuntos
embutidos das fontes Noto que acompanham o app, com a formação das letras e a ordem bidirecional
feitas pelo próprio app, de modo que copiar e buscar devolvem o texto. As imagens são embutidas
(JPEG direto, as demais com a sua transparência) e reduzidas ao tamanho em que são impressas. A
mesma prancha sai em **PNG** (Arquivo → Exportar desenho → PNG (imagem da prancha), de 96 a 300 dpi,
no máximo cerca de 40 megapixels).

## Orçamento comercial e alternativas

Projeto → Orçamento comercial… transforma a lista de materiais num orçamento: preços de venda com a
margem, mão de obra, escavação das valas (volumes a partir dos tubos enterrados e das medidas da
vala), linhas extras, desconto, impostos e frete, validade e condições; retorno (payback), VPL e TIR
a partir de um benefício anual; um cronograma de obra pelas equipes e pela produção de cada uma por
dia; os códigos FINAME (financiamento do BNDES) dos itens que os têm. Projeto → Alternativas do
projeto… guarda cópias nomeadas do projeto com os seus números principais, compara-as lado a lado e
restaura uma num único passo de desfazer.

## Exportações

| Formato | Conteúdo | Observações |
|---|---|---|
| DXF | R2000 (AC1015) com entidades nativas: polilinhas com arcos, splines, hachuras, cotas, chamadas, texto multilinha; símbolos e itens hidráulicos como blocos com atributos (NAME, ITEM, NOZZLE, ZONE, STATIONS); camadas com cores verdadeiras e tipos de linha tracejados; blocos do usuário como definições de bloco | Validado com ezdxf e LibreDWG e relido pelo leitor do app |
| DXF R12 | As primitivas simples da exportação anterior, um texto por linha | Para programas antigos |
| DWG | R2000 (AC1015), o mesmo desenho nativo (só índices de cor) | Escritor próprio, validado com LibreDWG e relido pelo leitor do app |
| PDF | Conjuntos de folhas com carimbo, legenda, seta norte, escala, detalhes, gráficos e, opcionalmente, relatórios | Todas as escritas da interface |
| PNG | A prancha como imagem, 96–300 dpi | |
| SVG | Folha em milímetros, um grupo por camada, imagens embutidas | Navegadores, Inkscape |
| KML / KMZ | Pastas por camada, coordenadas WGS84 | Google Earth; exige georreferência |
| GeoJSON | FeatureCollection com atributos | QGIS, web GIS; exige georreferência |
| Shapefile (zip) | Um shapefile por camada e tipo de geometria (com Z onde a elevação importa), atributos em UTF-8 com diâmetros, vazões, velocidades e pressões, um `.prj` | GIS; UTM em SIRGAS 2000 / WGS 84 quando georreferenciado, metros locais senão |
| GPX | Cada item pontual como waypoint (as saídas das laterais uma a uma) e os itens lineares como trilhas | Locação em campo com GPS; exige georreferência |
| LandXML 1.2 | O TIN do terreno e os seus dados de origem, os itens pontuais como CgPoints, uma rede de tubos por zona e uma da linha principal com cotas de geratriz inferior, diâmetros e vazões de projeto | Programas de topografia e de engenharia civil |
| IFC 4 | Terreno do local, tubos como sólidos de varredura na profundidade de enterro, terminais, válvulas, filtros, hidrômetros, bombas e reservatórios com conjuntos de propriedades e valores hidráulicos, um sistema de distribuição por zona | BIM; Reference View |
| EPANET (.inp) | A rede de um turno (ou com tudo aberto), com bombas, válvulas, emissores e os aspersores com válvula que esse turno aciona | EPANET 2.2; Hazen-Williams, Darcy-Weisbach ou Chezy-Manning |
| CSV, TXT, XLSX, PDF | Relatórios (todas as tabelas) | XLSX com uma planilha por tabela e números como números |
| CSV do controlador | Programa de irrigação: eventos por turno, dias e horários | Arquivo → Exportar relatório, ou o diálogo de turnos |
