# Formatos de arquivo

## Projeto (`.oci.json`)

JSON legível com estas chaves de primeiro nível:

| Chave | Conteúdo |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `2` (arquivos da versão 1 são atualizados na leitura; o nome antigo `irrigationcad` ainda é aceito) |
| `meta` | uid estável, datas de criação e modificação, nome, cliente, obra, projetista, notas, georreferência (fuso UTM, hemisfério, origem E/N, e o datum quando escolhido), o carimbo profissional (`titleBlock`, só quando há algo nele; o logotipo vai no arquivo, não nos links de compartilhamento) |
| `params` | Todos os parâmetros de projeto e as unidades |
| `catalog` | O catálogo do projeto completo (o arquivo é autossuficiente) |
| `layers` | Nome, cor ARGB, visível, bloqueada |
| `entities` | Uma entrada por entidade, com `type`, `id`, `layer`, `name` e os campos próprios (pontos em metros; um pivô guarda os dados da máquina em `mach`; uma área irrigada guarda a direção das fileiras de plantio lida por Fileiras da imagem em `rdir`, em graus no sentido anti-horário a partir do leste dentro de [0, 180), ao lado dos espaçamentos entre fileiras e entre plantas `rsp` e `psp`, gravada só quando definida e girada e espelhada com a área) |
| `systemFlows` | Turnos: nome, válvulas (e pivôs e estações de aspersores com válvula), hora de início, duração |
| `proposal`, `scenarios`, `climate`, `labelRules`, `blocks`, `aiNotes` | Opcionais: configurações do orçamento, alternativas do projeto, clima do local (com a série diária de um arquivo de estação ou de um download), rótulos condicionais, blocos do usuário, as notas do assistente de IA sobre o projeto |
| `agronomy`, `agb`, `deliverables`, `dimStyle`, `layerStates` | Opcionais, gravados só quando diferem de um projeto novo: o plano agronômico (culturas do usuário, programa, balanço hídrico, fertirrigação por estágio, avaliações de campo), as configurações de energia, água e máquinas, as dos documentos técnicos, o estilo de cota e os estados de camadas com nome |
| `climateRisk` | Opcional: o resumo do último Risco climático ao longo dos anos (a fonte da série e o crédito dela, o local, o primeiro e o último ano, o dia em que foi calculado, a probabilidade e o período de pico escolhidos, alguns números por ano do local e por área e safra, e os valores que o projeto usou), nunca a série diária; um resumo danificado é descartado na leitura |
| `unreadable` | Itens que esta versão não conseguiu ler (danificados, ou de uma versão mais nova), guardados e gravados de volta para que uma versão posterior os recupere |
| `nextId`, `currentLayer` | Contador de ids e camada corrente |
| `results` | Opcional: resultados do último cálculo, para reabrir com relatórios sem recalcular |

O mesmo JSON é usado pelo autosave, pelas versões, pela área de transferência entre projetos, pelos
links de compartilhamento e pelo worker de cálculo. O arquivo abre item a item: um item que não pode
ser lido fica de lado (em `unreadable`), vértices sem coordenadas são descartados, uma cota
desconhecida nunca vira 0 m, ids repetidos ou ausentes são renumerados, opções desconhecidas caem no
padrão e campos de uma versão mais nova são preservados; o app então diz o que reparou. `oci schema`
imprime o JSON Schema do arquivo, gerado do modelo. Arquivo → Inserir projeto… mescla outro arquivo
de projeto no aberto, com ids novos (as referências entre os itens mantidas), os itens de catálogo
que ele usa (renomeados quando o projeto aberto tem outro item com o mesmo id, com preços na moeda
dele), as camadas que faltam, os turnos que rodam os itens dele e os seus blocos; com as duas
georreferências os itens caem no mesmo lugar do terreno, um projeto vazio sem georreferência adota a
do arquivo, senão eles entram como desenhados. A biblioteca de blocos é exportada num arquivo
`.oci-blocks.json`.

## Importação

| Formato | O que entra | Detalhes |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE e POLYLINE (com arcos de bulge), CIRCLE, ARC, ELLIPSE, SPLINE (pelos pontos de ajuste, ou a curva NURBS dos pontos de controle, nós e pesos), HATCH (contornos de polilinhas, linhas, arcos, elipses e splines; ângulo e espaçamento do padrão; ilhas como polilinhas), SOLID, TRACE, TEXT, MTEXT (com os seus parágrafos), ATTRIB, LEADER (a sua linha), MULTILEADER, MLINE, POINT, 3DFACE e malhas, camadas e blocos (INSERT, MINSERT e o bloco das cotas DIMENSION, inclusive aninhados) | R12 a 2018, lido grupo a grupo em fatias com progresso e Cancelar; a página de código do `$DWGCODEPAGE` (tabelas de byte simples e as páginas japonesa, chinesas e coreana 932, 936, 949 e 950), Latin-1 ou UTF-8; caracteres `\U+XXXX`, símbolos `%%c`/`%%d`/`%%p` e códigos de MTEXT decodificados; polilinhas com elevação (2D ou vértices 3D) viram curvas de nível e camadas de linhas de quebra, linhas de quebra; pontos com Z, faces 3D, malhas e blocos de levantamento (um INSERT cujo ATTRIB traz a cota, com vírgula decimal ou unidade, ou a cota da inserção) viram cotas; o XDATA hidráulico de um desenho exportado por este app traz de volta os seus tubos e itens como rede; escala pelas unidades do arquivo; camadas desligadas ou congeladas entram ocultas; o espaço papel fica de fora, e os tipos de entidade sem suporte são citados no aviso; a expansão de blocos tem teto contra ciclos e blocos explosivos, e uma referência externa ausente é avisada |
| DWG | Mesmas entidades (inclusive ELLIPSE, SPLINE, HATCH, SOLID, TRACE, LEADER, ATTRIB, 3DFACE e MLINE; polilinhas 2D com seus arcos), camadas com as suas cores, blocos (INSERT, MINSERT), cotas e o XDATA hidráulico; como no DXF, entidades espelhadas no programa de CAD (extrusão 0, 0, −1) ficam onde o CAD as mostra | R13/R14 (parcial), 2000, 2004, 2007, 2010, 2013 e 2018, em Dart puro, lido em fatias com progresso e Cancelar; unidades pelo `$INSUNITS`, a página de código do cabeçalho (CJK inclusive); mapas de handles lidos seja qual for a forma como o programa os codificou; objetos ignorados avisados, as classes deixadas de fora (MULTILEADER, IMAGE, WIPEOUT…) citadas |
| DGN V7 | Linhas, line strings, shapes, curvas, cadeias e shapes complexos, círculos, elipses, arcos, textos, células; níveis como camadas (`LEVEL_<n>`); arquivos 2D e 3D (um Z constante vira a elevação) | Unidades pela razão unidade mestra/subunidade e pela origem global do arquivo; DGN V8 é recusado pelo nome |
| PDF (planta) | Uma página como base de fundo: linhas, polilinhas e contornos, textos com altura e ângulo, imagens, camadas do PDF (as desligadas por padrão só se pedidas), uma camada por importação e opcionalmente uma por cor | Arquivo → Importar abre um diálogo: página com prévia, escala 1:N (lida da folha quando escrita nela, ou escolhida, ou metros por unidade do PDF), ponto de inserção, conteúdo; depois Alinhar por 2 pontos. Arquivos criptografados são recusados; imagens JPEG 2000 e JBIG2 ficam de fora; áreas preenchidas entram como contornos |
| KML / KMZ | Placemarks, pastas como camadas, trilhas de GPS (gx:Track), altitude ou atributo ELEV como elevação; as sobreposições de imagem de um KMZ (GroundOverlay com LatLonBox e rotação, ou um gx:LatLonQuad retangular) como fundo georreferenciado, com a transparência da cor e a ordem de desenho | WGS84 → UTM (fuso automático) com origem local; georreferencia o projeto; uma sobreposição cuja imagem vem da internet ou não pode ser lida é citada no aviso |
| SHP (+ DBF, PRJ, CPG em zip) | Pontos, linhas, polígonos, multipontos, variantes Z; um zip com vários shapefiles traz cada um na camada do seu nome | Lido registro a registro com progresso e Cancelar; elevação do Z ou de atributo ELEV/Z/COTA; nome de NAME/NOME/ID; atributos na página de código do `.cpg` (UTF-8, Latin-1, as páginas do Windows e as CJK); o `.prj` posiciona os dados (abaixo); sem ele, graus são reconhecidos pela faixa e pela precisão |
| GeoJSON | FeatureCollection, Feature, GeometryCollection ou uma geometria solta, todos os tipos de geometria; nome, elevação e camada pelas propriedades | Longitude/latitude RFC 7946 em WGS 84, ou o membro `crs` da especificação de 2008 (UTM em SIRGAS 2000, SAD 69 ou Córrego Alegre cai no lugar); pontos sem altura viram marcadores |
| GPX | Waypoints (com elevação: cotas), rotas e trilhas | GPX 1.1 e 1.0 |
| LandXML | CgPoints, superfícies (o TIN, ou curvas, linhas de quebra, pontos e contornos) e redes de tubos | Rarefeito até o limite do terreno; sistema de coordenadas do arquivo; unidades imperiais convertidas |
| LAS | Os pontos de terreno (classe 2) de uma nuvem de pontos como terreno, rarefeitos numa grade durante a leitura | LAS 1.0–1.4, formatos de ponto 0–10, sistema de coordenadas pelas chaves GeoTIFF ou pelo WKT; LAZ comprimido é recusado |
| EPANET (.inp) | A rede desenhada: tubos, bombas e válvulas como polilinhas nas camadas `EPANET_*`, nós com seus ids | Unidades US convertidas; posicionada pela georreferência ou em metros locais; o leitor do motor também monta a rede hidráulica ([docs/API.pt-BR.md](../../../docs/API.pt-BR.md)) |
| CSV, TXT, XYZ, PTS, PNEZD | Pontos de levantamento | Arquivo → Importar abre o assistente de pontos: as primeiras linhas numa tabela, o papel de cada coluna (ponto, este, norte, cota, latitude, longitude, descrição, ignorar), o separador, o separador decimal, um cabeçalho, linhas a pular, a codificação e o sistema de coordenadas (metros locais, a UTM do projeto, latitude e longitude, a UTM de um fuso num datum, um código EPSG), com um mapa do mundo que mostra onde os pontos caem (e, num anel, onde cairiam com latitude e longitude trocadas) e um aviso quando caem longe do projeto; colunas detectadas pelo cabeçalho ou posição, PENZ ou PNEZ pela grandeza dos valores UTM, vírgula decimal e separador de milhar aceitos; pontos sem cota viram marcadores |
| GeoTIFF de elevação | Grade de cotas | Uma banda de alturas, float ou inteiro, nodata ignorado; TIFF clássico, BigTIFF e GeoTIFF otimizado para a nuvem lidos por blocos (sem compressão, LZW, Deflate, PackBits, JPEG; preditores 2 e 3; os blocos vazios de arquivos esparsos) e amostrados na grade do modelo sem decodificar o resto |
| JPG, PNG, GeoTIFF, zip com world file | Imagem de fundo | Georreferenciada (world file, inclusive rotacionado; tags GeoTIFF, com uma projeção dada chave por chave) ou colocada à mão e alinhada por 2 pontos; rasters TIFF grandes (ortomosaicos de drone de centenas de megapixels, BigTIFF, GeoTIFF otimizado para a nuvem com as suas visões reduzidas, até 4 bilhões de pixels) são reduzidos por média durante a leitura, só com as linhas em andamento na memória; JPG, PNG e outras imagens com mais de 100 milhões de pixels são recusadas antes de decodificar |

**Sistemas de coordenadas.** Os leitores que trazem um sistema de coordenadas (`.prj` do shapefile,
`crs` do GeoJSON, LandXML, LAS, GeoTIFF) reconhecem WKT 1 (nas variantes ESRI e OGC), WKT 2, códigos
EPSG e URNs da OGC, com a transversa de Mercator (UTM) e as projeções cônica equivalente de Albers,
cônica conforme de Lambert e policônica (Snyder 1987), inclusive as grades nacionais dos EPSG 5880 e
29101 (Policônica do Brasil), 10857 (Albers do Brasil), 2154 (Lambert-93), 3034 (LCC Europa), 5070
(Albers dos EUA contíguos) e 6372 (LCC do México); o RGF93 é lido como ETRS89. Dados em SAD 69 e
Córrego Alegre são deslocados para o SIRGAS 2000 com as translações de três parâmetros do IBGE
(precisão de alguns metros); SIRGAS 2000, WGS 84, ETRS89 e NAD83 são tratados como idênticos na
precisão de um mapa de projeto. Um sistema não reconhecido é informado, não adivinhado. Um desenho em
UTM do fuso do projeto entra deslocado pela origem da georreferência, no lugar sobre o mapa de
satélite.

**Arquivos grandes** são lidos em fatias antes de a importação mudar o projeto, com progresso e
Cancelar (*Importação cancelada: o projeto não mudou*): DXF, DWG e LAS pelos seus próprios leitores,
GeoTIFF bloco a bloco, shapefiles registro a registro e KML/KMZ entre pausas; arquivos pequenos
dispensam o diálogo. Arquivos compactados (KMZ, XLSX, shapefiles e imagens em zip, links de
compartilhamento) são abertos entrada por entrada, até um teto cada, contra bombas de zip. Um link de
compartilhamento de um projeto grande pergunta antes de abrir.

## Catálogos e exemplos

Pacotes `.oci.cat` em [catalogs/](../../../catalogs/) (formato em [catalogs/README.md](../../../catalogs/README.md)) e
projetos de exemplo em [examples/](../../../examples/), regenerados por ferramentas e guardados por testes.
