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
licenciamento), pacote do pivô (carta de bocais e temporizador), braço, VRI e elétrica, aspersores
com válvula, energia, água e máquinas ([Energia, água e máquinas](power-water-machines.md)) e uma
aba *Manejo da irrigação* com o balanço hídrico diário, o escoamento potencial, a capacidade contra o
pico, o programa por estação, a fertirrigação por estágio, as avaliações de campo e as duas tabelas do risco climático
ao longo dos anos ([Agronomia e manejo da irrigação](agronomy.md)). O boletim de qualidade do projeto também é uma
tabela de relatório (`scorecard`, em toda exportação; [Cálculo e dimensionamento](calculation.md#boletim-de-qualidade-do-projeto)),
e o radar dele vai nas páginas de gráficos das pranchas. A aba da linha principal também traz as estações de
bombeamento (o ponto de cada bomba em cada turno) e a operação real dos setores; a aba de requisitos
hídricos traz *Declividade por área irrigada*, e a de necessidade por cultura as *Fontes de dados e
créditos*. Sob o seu título, cada tabela cita os critérios que mostra e as normas que eles seguem
([Carimbo e documentos técnicos](technical-documents.md#normas-nos-relatórios)).

As tabelas são virtualizadas, com colunas medidas pelo conteúdo, e servem de base para todos os
exportadores, de modo que PDF, Excel e CSV mostram os mesmos números. Um clique no cabeçalho ordena a
tabela (de novo inverte, na terceira volta à ordem do relatório), um filtro mantém as linhas com um
texto ou só as destacadas, as linhas visíveis são copiadas para a área de transferência (para colar
numa planilha) e a aba é salva em CSV; uma linha de zonas, tubos, emissores, comentários ou revisões
seleciona e enquadra o seu item no desenho. Exportar relatório funciona sem cálculo para as tabelas
que não dependem dele (água, cultura, comentários, revisões, requisitos…).

## Pranchas em PDF

Arquivo → Exportar desenho → PDF abre as opções de plotagem: tamanho (A4 a A0, Letter, Tabloid, as
folhas alongadas da ISO 5457 de A3×3 a A0×2, ANSI C, D e E, ou um tamanho personalizado de 100 a
5000 mm por lado para rolos de plotter), orientação, escala (automática ou fixa; "1.500" digitado é
1500), margem, raios molhados, rótulos, legenda de camadas, lista
de materiais na prancha, o mapa base da tela sob o desenho (com o crédito do provedor e, abaixo, os
das imagens de mapa guardadas para o campo e da elevação online mostrada) e páginas de
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
carimbo traz os detalhes do projeto, a seta norte e a escala gráfica; com os campos de Arquivo →
Carimbo e responsável técnico… ele vira o carimbo profissional, e as opções acrescentam uma
quadrícula de coordenadas UTM ou geográfica e folhas a mais de declividade e de exposição
([Carimbo e documentos técnicos](technical-documents.md)). O diálogo mostra uma **prévia** de cada
folha do conjunto, refeita depois de cada opção. Mais duas opções: **camadas no PDF**, uma por camada
do projeto e uma para o mapa base, ligadas e desligadas no visualizador, e **PDF/A-2b** para
arquivamento (órgãos públicos), um PDF 1.7 com o seu identificador, o XMP das suas informações, uma
intenção de saída sRGB e todas as fontes embutidas (o texto em Helvetica desenhado com a Noto Sans na
largura da Helvetica; sem a fonte o arquivo não se diz PDF/A).

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
vala, com a profundidade padrão da adutora, 0,6 m, e dos tubos de setor, 0 = na superfície, para os
que não têm a sua, que as ferramentas automáticas também usam), linhas extras, desconto, impostos e
frete, validade e condições; retorno (payback), VPL e TIR a partir de um benefício anual; um
cronograma de obra pelas equipes e pela produção de cada uma por dia; os códigos FINAME
(financiamento do BNDES) dos itens que os têm. Projeto → Alternativas do projeto… guarda cópias
nomeadas do projeto com os seus números principais, compara-as lado a lado e restaura uma num único
passo de desfazer.

## Exportações

| Formato | Conteúdo | Observações |
|---|---|---|
| DXF | R2000 (AC1015) com entidades nativas: polilinhas com arcos, splines, hachuras, cotas, chamadas, texto multilinha; símbolos e itens hidráulicos como blocos com atributos (NAME, ITEM, NOZZLE, ZONE, STATIONS); camadas com cores verdadeiras e tipos de linha tracejados; blocos do usuário como definições de bloco e referências de bloco como INSERT com ATTRIB; as ilhas das áreas como hachuras; os dados hidráulicos de cada tubo, lateral, fita e item hidráulico como dados estendidos (XDATA da aplicação registrada OPENCADIRRIGATION: tipo, item do catálogo, diâmetros, comprimento e, com resultados, vazões, velocidade, perda de carga e pressões) | Validado com ezdxf e LibreDWG e relido pelo leitor do app, que traz a rede de volta pelo XDATA; outros leitores veem o desenho inteiro |
| DXF R12 | As primitivas simples da exportação anterior, um texto por linha | Para programas antigos |
| DWG | R2000 (AC1015), o mesmo desenho nativo (só índices de cor) com o mesmo XDATA | Escritor próprio, validado com LibreDWG e relido pelo leitor do app |
| PDF | Conjuntos de folhas com carimbo, legenda, seta norte, escala, detalhes, gráficos e, opcionalmente, relatórios, a quadrícula de coordenadas, folhas de declividade e de exposição, camadas e PDF/A-2b | Todas as escritas da interface |
| Pacote de documentos (PDF) | Arquivo → Exportar pacote de documentos: uma proposta, uma pasta de outorga e licenciamento, uma pasta de instalação, um memorial técnico ou uma pasta de operação e manutenção, com capa, sumário, seções numeradas, plantas e assinatura | [Carimbo e documentos técnicos](technical-documents.md#pacotes-de-documentos) |
| PNG | A prancha como imagem, 96–300 dpi | |
| SVG | Folha em milímetros, um grupo por camada, imagens embutidas | Navegadores, Inkscape |
| KML / KMZ | Pastas por camada, coordenadas WGS84 | Google Earth; exige georreferência |
| GeoJSON | FeatureCollection com atributos | QGIS, web GIS; exige georreferência |
| Shapefile (zip) | Um shapefile por camada e tipo de geometria (com Z onde a elevação importa), atributos em UTF-8 com diâmetros, vazões, velocidades e pressões, um `.prj`, as ilhas das áreas como anéis internos | GIS; UTM no datum da georreferência (SIRGAS 2000, ETRS89, WGS84 ou NAD83; por padrão o do local) quando georreferenciado, metros locais senão |
| GPX | Cada item pontual como waypoint (as saídas das laterais uma a uma) e os itens lineares como trilhas | Locação em campo com GPS; exige georreferência |
| Pontos para locação (CSV) | Arquivo → Exportar desenho → Pontos para locação (PNEZD): número, coordenadas UTM do projeto (as locais sem georreferência), cota do terreno e descrição dos emissores e aspersores, válvulas, bombas, captações e dispositivos, vértices das tubulações e início e fim das linhas laterais, em P,N,E,Z,D ou P,E,N,Z,D, com o primeiro número e as casas decimais escolhidos | A lista que a estação total ou o receptor GNSS RTK carrega direto |
| LandXML 1.2 | O TIN do terreno e os seus dados de origem, os itens pontuais como CgPoints, uma rede de tubos por zona e uma da linha principal com cotas de geratriz inferior, diâmetros e vazões de projeto | Programas de topografia e de engenharia civil |
| IFC 4 | Terreno do local, tubos como sólidos de varredura na profundidade de enterro, terminais, válvulas, filtros, hidrômetros, bombas e reservatórios com conjuntos de propriedades e valores hidráulicos, um sistema de distribuição por zona | BIM; Reference View |
| EPANET (.inp) | A rede de um turno (ou com tudo aberto), com bombas, válvulas, emissores e os aspersores com válvula que esse turno aciona | EPANET 2.2; Hazen-Williams, Darcy-Weisbach ou Chezy-Manning |
| CSV, TXT, XLSX, PDF | Relatórios (todas as tabelas), com as normas de cada tabela no PDF, no CSV e no TXT | XLSX com uma planilha por tabela e números como números |
| PDF, XLSX, CSV, Markdown | Os documentos técnicos de Relatórios → Documentos técnicos (quadro de outorga, memorial, plano de operação e manutenção, orçamento por composições, custo do ciclo de vida) | Markdown para editar o texto |
| CSV do controlador | Programa de irrigação: eventos por turno, dias e horários | Arquivo → Exportar relatório, ou o diálogo de turnos |
