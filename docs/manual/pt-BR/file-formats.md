# Formatos de arquivo

## Projeto (`.oci.json`)

JSON legível com estas chaves de primeiro nível:

| Chave | Conteúdo |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `1` (o nome antigo `irrigationcad` ainda é aceito) |
| `meta` | uid estável, datas de criação e modificação, nome, cliente, obra, projetista, notas, georreferência (fuso UTM, hemisfério, origem E/N) |
| `params` | Todos os parâmetros de projeto e as unidades |
| `catalog` | O catálogo do projeto completo (o arquivo é autossuficiente) |
| `layers` | Nome, cor ARGB, visível, bloqueada |
| `entities` | Uma entrada por entidade, com `type`, `id`, `layer`, `name` e os campos próprios (pontos em metros; um pivô guarda os dados da máquina em `mach`) |
| `systemFlows` | Turnos: nome, válvulas (e pivôs e estações de aspersores com válvula), hora de início, duração |
| `proposal`, `scenarios`, `climate`, `labelRules`, `blocks`, `aiNotes` | Opcionais: configurações do orçamento, alternativas do projeto, clima do local, rótulos condicionais, blocos do usuário, as notas do assistente de IA sobre o projeto |
| `nextId`, `currentLayer` | Contador de ids e camada corrente |
| `results` | Opcional: resultados do último cálculo, para reabrir com relatórios sem recalcular |

O mesmo JSON é usado pelo autosave, pelas versões, pela área de transferência entre projetos, pelos
links de compartilhamento e pelo worker de cálculo.

## Importação

| Formato | O que entra | Detalhes |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE e POLYLINE (com arcos de bulge), CIRCLE, ARC, ELLIPSE, SPLINE (pelos pontos de ajuste, ou a curva NURBS dos pontos de controle, nós e pesos), HATCH (contornos de polilinhas, linhas, arcos, elipses e splines; ângulo e espaçamento do padrão; ilhas como polilinhas), SOLID, TRACE, TEXT, MTEXT, ATTRIB, LEADER (a sua linha), POINT, camadas e blocos (INSERT, MINSERT e o bloco das cotas DIMENSION, inclusive aninhados) | R12 a 2018, Latin-1 ou UTF-8; caracteres `\U+XXXX`, símbolos `%%c`/`%%d`/`%%p` e códigos de MTEXT decodificados; polilinhas com elevação (2D ou vértices 3D) viram curvas de nível e camadas de linhas de quebra, linhas de quebra; pontos com Z viram cotas; escala pelas unidades do arquivo |
| DWG | Mesmas entidades (inclusive ELLIPSE, SPLINE, HATCH, SOLID, TRACE e LEADER; polilinhas 2D com seus arcos), camadas, blocos (INSERT, MINSERT) e cotas; como no DXF, entidades espelhadas no programa de CAD (extrusão 0, 0, −1) ficam onde o CAD as mostra | R13/R14 (parcial), 2000, 2004, 2007, 2010, 2013 e 2018, em Dart puro; mapas de handles lidos seja qual for a forma como o programa os codificou; avisa objetos ignorados |
| DGN V7 | Linhas, line strings, shapes, curvas, cadeias e shapes complexos, círculos, elipses, arcos, textos, células; níveis como camadas (`LEVEL_<n>`); arquivos 2D e 3D (um Z constante vira a elevação) | Unidades pela razão unidade mestra/subunidade e pela origem global do arquivo; DGN V8 é recusado pelo nome |
| PDF (planta) | Uma página como base de fundo: linhas, polilinhas e contornos, textos com altura e ângulo, imagens, camadas do PDF (as desligadas por padrão só se pedidas), uma camada por importação e opcionalmente uma por cor | Arquivo → Importar abre um diálogo: página com prévia, escala 1:N (lida da folha quando escrita nela, ou escolhida, ou metros por unidade do PDF), ponto de inserção, conteúdo; depois Alinhar por 2 pontos. Arquivos criptografados são recusados; imagens JPEG 2000 e JBIG2 ficam de fora; áreas preenchidas entram como contornos |
| KML / KMZ | Placemarks, pastas como camadas, trilhas de GPS (gx:Track), altitude ou atributo ELEV como elevação | WGS84 → UTM (fuso automático) com origem local; georreferencia o projeto |
| SHP (+ DBF, PRJ, CPG em zip) | Pontos, linhas, polígonos, multipontos, variantes Z; um zip com vários shapefiles traz cada um na camada do seu nome | Elevação do Z ou de atributo ELEV/Z/COTA; nome de NAME/NOME/ID; atributos em UTF-8 ou Latin-1 (.cpg); o `.prj` posiciona os dados (abaixo); sem ele, graus são reconhecidos pela faixa e pela precisão |
| GeoJSON | FeatureCollection, Feature, GeometryCollection ou uma geometria solta, todos os tipos de geometria; nome, elevação e camada pelas propriedades | Longitude/latitude RFC 7946 em WGS 84, ou o membro `crs` da especificação de 2008 (UTM em SIRGAS 2000, SAD 69 ou Córrego Alegre cai no lugar); pontos sem altura viram marcadores |
| GPX | Waypoints (com elevação: cotas), rotas e trilhas | GPX 1.1 e 1.0 |
| LandXML | CgPoints, superfícies (o TIN, ou curvas, linhas de quebra, pontos e contornos) e redes de tubos | Rarefeito até o limite do terreno; sistema de coordenadas do arquivo; unidades imperiais convertidas |
| LAS | Os pontos de terreno (classe 2) de uma nuvem de pontos como terreno, rarefeitos numa grade durante a leitura | LAS 1.0–1.4, formatos de ponto 0–10, sistema de coordenadas pelas chaves GeoTIFF ou pelo WKT; LAZ comprimido é recusado |
| EPANET (.inp) | A rede desenhada: tubos, bombas e válvulas como polilinhas nas camadas `EPANET_*`, nós com seus ids | Unidades US convertidas; posicionada pela georreferência ou em metros locais; o leitor do motor também monta a rede hidráulica ([docs/API.pt-BR.md](../../../docs/API.pt-BR.md)) |
| CSV, TXT, XYZ, PNEZD | Pontos de levantamento | Colunas detectadas pelo cabeçalho ou posição; vírgula decimal aceita (também em colunas separadas por espaço), separador de milhar também; uma coluna de texto dá nome aos pontos; lat/lon reconhecidos |
| GeoTIFF de elevação | Grade de cotas | Uma banda de alturas, float ou inteiro, nodata ignorado; BigTIFF é recusado pelo nome |
| JPG, PNG, GeoTIFF, zip com world file | Imagem de fundo | Georreferenciada (world file, inclusive rotacionado; tags GeoTIFF) ou colocada à mão e alinhada por 2 pontos; rasters com mais de 100 milhões de pixels são recusados antes de decodificar |

**Sistemas de coordenadas.** Os leitores que trazem um sistema de coordenadas (`.prj` do shapefile,
`crs` do GeoJSON, LandXML, LAS) reconhecem WKT 1 (nas variantes ESRI e OGC), WKT 2, códigos EPSG e
URNs da OGC. Dados em SAD 69 e Córrego Alegre são deslocados para o SIRGAS 2000 com as translações
de três parâmetros do IBGE (precisão de alguns metros); SIRGAS 2000, WGS 84, ETRS89 e NAD83 são
tratados como idênticos na precisão de um mapa de projeto. Um sistema não reconhecido é informado,
não adivinhado.

## Catálogos e exemplos

Pacotes `.oci.cat` em [catalogs/](../../../catalogs/) (formato em [catalogs/README.md](../../../catalogs/README.md)) e
projetos de exemplo em [examples/](../../../examples/), regenerados por ferramentas e guardados por testes.
