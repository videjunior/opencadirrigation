<p align="center"><img src="web/brand/logo-horizontal.png" width="560" alt="OpenCADIrrigation"></p>

<p align="center"><a href="https://opencadirrigation.com">opencadirrigation.com</a> · <a href="https://opencadirrigation.com/pt/">Português</a> · <a href="https://opencadirrigation.com/es/">Español</a> · <a href="LICENSE.md">Licença MIT</a></p>

<p align="center"><a href="README.md">English (canonical)</a> · <strong>Português</strong></p>

# OpenCADIrrigation

CAD de código aberto, escrito em Flutter/Dart, para projeto de sistemas de irrigação
pressurizada: desenho, rede hidráulica, dimensionamento, relatórios e plotagem, direto no
navegador, sem instalação, sem servidor e sem cadastro, mais um assistente de IA opcional (Claude
ou GPT, com a sua própria chave) que desenha e projeta com você. Os projetos ficam no seu
computador. Distribuído sob a [licença MIT](LICENSE.md).

<p align="center"><img src="web/screenshots/design-1440x900.png" width="900" alt="Um projeto de irrigação dimensionado, com diâmetros, pressões e resultados por zona"></p>

> Esta é a tradução em português do README. A versão canônica, mantida em inglês, é
> [README.md](README.md). O estudo técnico está em [docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md)
> (inglês) e [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md) (português); a API do motor, em
> [docs/API.md](docs/API.md) (inglês) e [docs/API.pt-BR.md](docs/API.pt-BR.md) (português). O código
> e seus comentários são em inglês. A interface existe em 20 idiomas ([seção 13](#13-idiomas-e-site)).

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Começando em cinco minutos](#2-começando-em-cinco-minutos)
3. [Fluxo de projeto](#3-fluxo-de-projeto)
4. [Interface](#4-interface)
5. [Desenho e edição](#5-desenho-e-edição)
6. [Rede hidráulica](#6-rede-hidráulica)
7. [Catálogo de componentes](#7-catálogo-de-componentes)
8. [Terreno](#8-terreno)
9. [Cálculo e dimensionamento](#9-cálculo-e-dimensionamento)
10. [Relatórios, plotagem e exportação](#10-relatórios-plotagem-e-exportação)
11. [Formatos de arquivo](#11-formatos-de-arquivo)
12. [Armazenamento, privacidade e rede](#12-armazenamento-privacidade-e-rede)
13. [Idiomas e site](#13-idiomas-e-site)
14. [Arquitetura do código](#14-arquitetura-do-código)
15. [Desenvolvimento](#15-desenvolvimento)
16. [Testes](#16-testes)
17. [Limitações conhecidas e roteiro](#17-limitações-conhecidas-e-roteiro)
18. [Contribuindo](#18-contribuindo)
19. [Referências](#19-referências)
20. [Licença, componentes e dados de terceiros](#20-licença-componentes-e-dados-de-terceiros)

---

## 1. Visão geral

### O que é

Um único aplicativo que cobre o ciclo completo de um projeto de irrigação pressurizada:

- **Agente de IA opcional**: o Claude (Anthropic) ou o GPT (OpenAI), com a sua própria chave de
  API, trabalha no projeto aberto com as ferramentas do próprio programa: responde perguntas,
  pergunta o que falta, planeja, desenha, projeta, verifica e escreve o memorial, com a sua
  aprovação e um desfazer para cada resposta ([seção 9](#assistente-de-ia-opcional)); nada é
  enviado antes de você clicar em Enviar.
- **Desenho CAD 2D** com camadas, snaps, coordenadas digitadas, cotas, hachuras, símbolos, blocos
  do usuário, comentários de revisão e nuvens de revisão, e aliases de comando digitados (L, PL, C,
  ZE…) como nos programas de CAD.
- **Rede hidráulica** desenhada sobre o CAD: fontes de água, bombas (de rotação fixa ou com
  inversor), linha principal, válvulas de zona, laterais com emissores, fitas e tubos gotejadores,
  filtros, reguladores de pressão, válvulas sustentadoras de pressão, hidrantes com limitador de
  vazão, hidrômetros, junções, aspersores com válvula (valve-in-head), pivôs centrais e lineares.
- **Motor hidráulico** em Dart puro: perda de carga por Hazen-Williams, Darcy-Weisbach, Scobey ou
  Manning, perdas localizadas (fração do comprimento ou as curvas e tês do desenho), emissores
  `q = k·H^x`, solver de rede pelo Global Gradient Algorithm (o mesmo do EPANET), bombas, válvulas
  redutoras, sustentadoras e controladoras de vazão, lavagem de fitas, golpe de aríete pelo método
  das características e simulação de período estendido de 24 horas.
- **Dimensionamento automático** de laterais, submains e linha principal por programação linear
  (custo anualizado de tubos + energia, janela de pressão dos emissores, classe de pressão dos tubos
  na temperatura da água, telescopagem) ou pelo método clássico de velocidade máxima.
- **Projeto automático**: layout de aspersores em paisagismo com zoneamento e traçado de tubos e
  válvulas, divisão de talhões em blocos, anéis de gotejamento em pomares, modelos de campos
  esportivos e golfe, ajuste de pivô ao talhão e vegetação detectada em imagem aérea.
- **Agronomia e operação**: clima do local (baixado ou digitado), culturas da FAO-56 com fases de
  desenvolvimento, solos, chuva efetiva e lixiviação, tabelas de necessidade, fiação das válvulas
  (convencional ou dois fios), tarifa horária, redes sob demanda, fertirrigação, máquinas
  mecanizadas e irrigação por superfície.
- **Terreno**: curvas de nível, cotas, linhas de quebra, modelo digital por triangulação, nuvens
  de pontos LAS e superfícies LandXML, elevação baixada da internet a partir de uma coordenada,
  mapas de declividade, perfis e linha piezométrica.
- **Saídas**: relatórios de zonas, tubos, emissores, turnos, lista de materiais com conexões,
  requisitos hídricos e programa do controlador; pranchas em PDF em todas as escritas da interface
  (conjuntos por zona, detalhes construtivos, gráficos); orçamento comercial; DXF e DWG (R2000,
  entidades nativas), SVG, PNG, KML, KMZ, GeoJSON, shapefile, GPX, LandXML, IFC 4, EPANET,
  Excel, CSV.
- **Catálogos abertos** de fabricantes em JSON, carregáveis por arquivo ou URL.
- **Linha de comando e API do motor**: `bin/oci.dart` projeta, verifica e exporta projetos sem
  navegador; `lib/core/api.dart` traz o motor inteiro numa importação
  ([docs/API.pt-BR.md](docs/API.pt-BR.md)).

### Para quem

Projetistas de irrigação agrícola e paisagística, agrônomos, engenheiros, revendas, professores e
estudantes. O tutorial interativo e a galeria de exemplos permitem começar sem ler manual.

### Princípios

| Princípio | O que significa na prática |
|---|---|
| Aberto | Código, formato de projeto (`.oci.json`), catálogos (`.oci.cat`) e exemplos são arquivos legíveis, documentados neste repositório. |
| No navegador | Chrome, Edge, Firefox e Safari, em computador, tablet e celular; instalável como PWA, que abre sem rede depois da primeira visita. Também compila para desktop (macOS, Windows, Linux). Não há builds nativos para Android e iOS: no celular e no tablet use o app web. |
| Sem servidor | Não há servidor por trás do app nem cadastro. Projetos ficam no navegador e em arquivos locais. A internet só é usada para o que você pede (mapas base, elevação e clima online, catálogos por URL e o assistente de IA opcional, o único recurso que envia dados do projeto, para o provedor de IA que você escolher); veja a [seção 12](#12-armazenamento-privacidade-e-rede). |
| Motor transparente | Cada fórmula está documentada no código e no [estudo técnico](docs/PESQUISA.pt-BR.md), com testes que a comparam a valores de referência. |
| 20 idiomas | Interface em português, inglês, espanhol, chinês, hindi, árabe, francês, bengali, russo, urdu, indonésio, alemão, japonês, marati, vietnamita, télugo, hauçá, turco, panjabi e suaíli; o app abre no idioma do sistema, e em árabe e urdu a interface é da direita para a esquerda. |

---

## 2. Começando em cinco minutos

1. Abra [opencadirrigation.com](https://opencadirrigation.com) e clique em **Abrir o app** (ou abra
   um exemplo ou o tutorial direto da página). Nas visitas seguintes o app abre sozinho, num projeto
   vazio, com uma tela de início que pergunta duas coisas: **onde fica a área** (um endereço buscado
   no OpenStreetMap, ou coordenadas; o projeto é georreferenciado ali, no mapa de satélite) e **se
   você quer projetar com o assistente de IA**.
2. Desenhe a área, deixe o assistente projetar ou abra um exemplo pronto: Ajuda → Boas-vindas e
   galeria de exemplos (com o **tutorial interativo**, 76 passos) ou Arquivo → Exemplos.
3. Pressione **F5** (ou o botão ▶ no canto superior direito). O cálculo roda fora da thread da
   interface; um cartão de progresso mostra a etapa atual (zona a zona, linha principal, lavagem,
   golpe de aríete, materiais). A tela continua utilizável durante o cálculo.
4. Leia os resultados no painel de **Relatórios** (F2): resumo das zonas, tubos com diâmetros e
   pressões, emissores, linha principal e duty das fontes, lista de materiais, requisitos hídricos,
   linha piezométrica, mensagens.
5. Passe o mouse sobre um tubo para ver diâmetro, vazão, velocidade e perda; selecione uma lateral
   e abra a aba **Linha piezométrica**; troque a sobreposição do desenho em Ver (velocidade,
   pressão, diâmetros, mínimos e máximos, densograma, declividade e exposição do terreno). Toda
   sobreposição desenha os mesmos itens e muda só as cores: os emissores das fitas e tubos
   gotejadores são pontinhos sobre a linha (um a cada poucos com o zoom afastado), na cor da linha
   ou, na sobreposição de pressão, na cor da própria pressão.
6. Exporte: Arquivo → Exportar desenho (pranchas em PDF, DXF, DWG, PNG…) ou Exportar relatório
   (PDF, Excel, CSV, TXT). Salve o projeto com **Ctrl+S** (`.oci.json`) ou envie-o como link
   (Arquivo → Compartilhar por link…).

### Galeria de exemplos

| id | Projeto | Conteúdo | Zonas |
|---|---|---|---|
| `orchard` | Pomar | Microaspersão em citros e gotejamento em uva, poço, bomba e filtro, terreno em declive | 2 |
| `garden` | Jardim residencial | Sprays pop-up no gramado da frente, rotores atrás, gotejamento nos canteiros; rede pública com hidrômetro e anti-refluxo | 3 |
| `sportsField` | Campo de futebol | 105 × 68 m, aspersores de impacto em cinco linhas com bocais equivalentes nas linhas do campo, reservatório, bomba, turnos noturnos | 5 |
| `rowCrop` | Lavoura gotejada | Quatro talhões de tomate com fita, submains com válvulas, filtro de tela, bomba, declive de 1 % | 4 |
| `pivot` | Pivô central | Pivô de 300 m em milho, adutora, poço e bomba; relatório de torres, vãos e bocais | 1 pivô |
| `greenhouse` | Estufa de hortaliças | Quatro túneis de pimentão com tubo gotejador autocompensante, reservatório, bomba pequena e filtro de discos | 4 |
| `nursery` | Viveiro de mudas | Três canteiros com microaspersores suspensos em malha 4 × 4 m, caixa d’água elevada, bomba pequena e filtro de discos | 3 |
| `coffee` | Cafezal em curvas de nível | Três talhões em encosta com laterais curvas que seguem as curvas de nível (bloco guiado), tubo gotejador PC, poço e bomba | 3 |
| `bananas` | Bananal | Dois talhões com microaspersores autocompensantes em 5 × 5 m, poço com bomba submersa e filtro de discos | 2 |
| `sugarcane` | Cana-de-açúcar subsuperficial | Tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, filtro de tela e ventosa | 2 |
| `gravity` | Gotejamento por gravidade | Reservatório 40 m acima dos talhões, sem bomba: registro, válvula reguladora de pressão e filtro na adutora | 2 |
| `pasture` | Pastagem em aspersão | Três piquetes com linhas de aspersores de impacto em 12 × 18 m, reservatório, bomba e válvula de retenção | 3 |
| `golf` | Buraco de golfe | Tee com sprays, fairway com rotores em malha triangular e green com rotores no perímetro, lago e bomba | 4 |
| `sectorPivot` | Pivô setorial com canhão | Pivô de 250 m que gira 270° com canhão final de 12 m³/h, lago, bomba de 20 cv e registro | 1 pivô |
| `linear` | Pivô linear | Lateral móvel de 392 m percorrendo 800 m ao longo de um canal, captação com bomba de 30 cv | 1 linear |

Todo exemplo com válvulas tem também a parte elétrica: um controlador junto à bomba (ou ao
cabeçal de controle) e as rotas de fios ao lado da linha principal até cada válvula. O cálculo dá
a cada válvula uma estação e uma bitola, verifica a tensão no solenoide e põe fios, controlador e
conectores na lista de materiais (aba Elétrico). Os exemplos de pivô e linear não têm válvulas
solenoides para ligar.

Os exemplos abrem pela tela de boas-vindas (Ajuda → Boas-vindas e galeria de exemplos…), pelo
menu Arquivo → Exemplos e pela URL. Os mesmos projetos estão em [examples/](examples/) como
`.oci.json`, uma pasta por idioma da interface (`examples/de/`, `examples/ja/`, … 20 ao todo): o
mesmo desenho em todas, com nomes, culturas e itens de catálogo no idioma da pasta.

### Parâmetros de URL

| Parâmetro | Efeito |
|---|---|
| `?example=garden` | Abre o exemplo indicado (`orchard`, `garden`, `sportsField`, `rowCrop`, `pivot`, `greenhouse`, `nursery`, `coffee`, `bananas`, `sugarcane`, `gravity`, `pasture`, `golf`, `sectorPivot`, `linear`). |
| `?design=1` | Projeta ao carregar. |
| `?ai=1` | Abre o assistente de IA ao lado do desenho (o botão "Abrir o assistente de IA" do site e o atalho do app). |
| `?tutorial=N` | Abre o tutorial interativo no passo N (de 1 a 76). |
| `?lang=pt` (qualquer código da seção 13) | Idioma desta visita (não altera a preferência salva). |
| `/pt/`, `/es/`, `/de/`, … | Página de entrada de cada idioma sob o seu código (os 20), com o mesmo efeito de `?lang` (a página raiz é a inglesa). |
| `#p=…` | Um projeto compartilhado por link (Arquivo → Compartilhar por link…): abre como cópia numa aba nova. A parte depois do `#` nunca é enviada a nenhum servidor. |

---

## 3. Fluxo de projeto

O fluxo segue a prática consolidada de projeto de irrigação (inventário e terreno, layout,
zonas, gerenciamento, linha principal, materiais e plotagem), adaptada a um app de navegador.

1. **Detalhes do projeto** (Arquivo → Detalhes do projeto…): nome, cliente, obra, projetista e
   notas, que vão para o carimbo da prancha e para os relatórios. Unidades (métrico ou US) em
   Ferramentas → Unidades.
2. **Informações de fundo**: importe a base (DXF, DWG, DGN, uma planta em PDF, KML/KMZ, SHP,
   GeoJSON, GPX, CSV de topografia, GeoTIFF, imagem de satélite), desenhe limites, edificações e
   estradas, ou percorra-os com o GPS do aparelho (Desenhar → GPS no campo). Imagens e plantas fora
   de escala se ajustam com Alinhar por 2 pontos (AL). Georreferencie o projeto (Arquivo →
   Georreferência…) quando quiser mapas base, elevação e clima online ou exportação
   KML/GeoJSON/GPX. Projeto → Projeto automático → Detectar vegetação na imagem… transforma os
   gramados e as copas de uma vista aérea em áreas irrigadas.
3. **Terreno**: desenhe curvas de nível (CT), linhas de quebra (BRK) e cotas de ponto (SP),
   importe um levantamento, uma nuvem de pontos LAS, uma superfície LandXML ou um GeoTIFF de
   elevação, ou baixe a elevação da internet a partir de uma coordenada. Gere curvas de nível do
   modelo e confira em 3D ou no mapa de declividade.
4. **Layout hidráulico**: fonte de água (WS), bomba (PU), linha principal (MP), válvulas de zona (V),
   e, a jusante de cada válvula, tubos de zona (ZP), laterais (SL), fitas (DT), emissores (OUT),
   acessórios (F). Os geradores de **bloco de laterais** (B) e de **grade de aspersores** (AH) e as
   ferramentas de **projeto automático** (Projeto → Projeto automático) fazem o trabalho
   repetitivo: aspersores distribuídos, zoneados e ligados por tubos, talhões divididos em blocos,
   anéis de gotejamento, modelos de gramado, pivôs ajustados ao talhão. Áreas irrigadas (AR) trazem
   cultura, solo, eficiência e balanço hídrico; Projeto → Clima do local… dá a elas o clima mensal.
5. **Gerenciamento** (Projeto → Turnos de operação): turnos (quais válvulas, pivôs e estações de
   aspersores com válvula abrem juntos, horário e duração). Sem turnos definidos, considera-se que
   todas as válvulas abrem juntas (o pior caso para a linha principal e a fonte). *Automático…*
   agrupa as zonas no menor número de turnos que cabe na vazão da fonte (ou numa vazão e num número
   de zonas que você escolhe), as maiores demandas primeiro; Projeto → Agrupar zonas por energia…
   junta zonas de altura parecida, e Tarifa horária e horários dos turnos… escolhe os horários de
   menor custo de energia.
   **Fiação**: um controlador (CTRL) e as rotas de fios (WR) até as válvulas, desenhadas à mão ou
   ao longo das valas dos tubos (Zona → Rotas automáticas de fios…), dimensionadas no cálculo.
6. **Verificação** (Projeto → Verificação do projeto…): itens desconectados, tubos que se cruzam
   sem junção, pontas soltas, zonas sem emissores ou que misturam tipos de emissor, catálogo
   faltando, terreno ausente.
7. **Projetar** (F5): zonas, linha principal, telescopagem, lavagem, golpe de aríete, máquinas
   mecanizadas e materiais. Também é possível projetar só as zonas, só a linha principal, ou
   apenas analisar com os diâmetros atuais (inclusive automaticamente a cada edição). O menu Linha
   principal confere a linha principal mais a fundo: transientes hidráulicos, ventosas, simulação
   de 24 horas, operação sob demanda, criticidade dos tubos, calibração da rugosidade e
   fertirrigação.
8. **Relatórios e plotagem**: painel de relatórios, pranchas em PDF (uma folha, ou uma visão geral
   e uma folha por zona ou por área) com carimbo, legenda, seta norte, escala gráfica, lista de
   materiais, detalhes construtivos e gráficos; orçamento comercial; exportações para outros CADs,
   GIS, BIM, EPANET e planilhas.

---

## 4. Interface

### Layout (tela larga)

- **Barra de menus** no topo; à direita, os botões ▶ Projetar e Salvar (âmbar quando há alterações).
- **Abas de projeto** logo abaixo: vários projetos abertos ao mesmo tempo (Ctrl+Alt+N nova aba,
  Ctrl+Alt+W fecha, Ctrl+Alt+←/→ alterna). Copiar e colar (Ctrl+C/X/V) funciona entre abas e
  entre janelas do navegador, levando camadas e itens de catálogo que faltem no destino.
- **Paleta de ferramentas** à esquerda, por grupos (navegação, desenho, edição, terreno, zona,
  linha principal, elétrica, revisão).
- **Canvas** ao centro, com grade, snaps, sobreposições e cartão de progresso do cálculo.
- **Painel lateral** à direita com três abas: **Propriedades** do item selecionado (com resultados
  hidráulicos após o cálculo e o envelope de posição do submain para laterais), **Camadas**
  (visibilidade, bloqueio, cor, renomear, criar, remover) e **Histórico** (linha do tempo de
  estados, como no Photoshop: clique para voltar ou avançar).
- **Relatórios** embaixo do canvas (F2), redimensionável.
- **Painel do assistente de IA** (opcional, [seção 9](#assistente-de-ia-opcional)) encaixado ao lado
  do canvas, aberto e fechado por Projeto → Assistente de IA… ou pelo botão dele na barra de status.
- **Barra de status** com coordenadas do cursor, snap ativo, comando ou coordenadas digitadas, dica
  da ferramenta, interruptores (snap, orto, grade, rastreamento polar, manter conexões), a precisão
  do GPS enquanto o GPS do aparelho está ligado, o indicador de análise automática, o botão do
  assistente de IA e a versão do app.

Em árabe e urdu todo o layout é espelhado (menus, painéis e diálogos da direita para a esquerda);
o desenho mantém as suas coordenadas.

**Tema**: Ver → Tema → Escuro (o padrão), Claro ou Seguir o sistema (também no menu do celular). A
escolha fica salva e troca na hora, sem perder os projetos abertos, a seleção nem os diálogos
abertos. No canvas claro (branco) as cores do desenho seguem a regra usual dos CADs: branco e
quase branco são desenhados quase pretos e as demais cores claras são escurecidas mantendo o
matiz, para que nada desapareça no fundo; os dados mantêm as suas cores, e a seleção aparece em
magenta em vez de amarelo. Plotagens e exportações (pranchas em PDF, SVG, PNG) são papel e não
mudam com o tema.

### Layout compacto (celular e tablet)

Abaixo de 700 px de largura a tela muda: menu ☰ no topo, barra de ferramentas por grupos embaixo,
botões Concluir/Cancelar no lugar de Enter/Esc, propriedades, relatórios e o assistente de IA em
painéis deslizantes. Pinça para zoom, dois dedos para mover, um dedo desenha.

### Menus

| Menu | Itens |
|---|---|
| Arquivo | Novo projeto, Nova aba de projeto, Fechar aba, Abrir projeto, Projetos recentes ▸, Salvar projeto, Histórico de versões, Salvar automaticamente no navegador (liga/desliga), Exemplos ▸, Importar (DXF, DWG, DGN, PDF, KML/KMZ, SHP, GeoJSON, GPX, LandXML, LAS, EPANET, CSV/XYZ, imagens, GeoTIFF), Georreferenciar imagem selecionada, Alinhar por 2 pontos, Exportar desenho ▸ (DXF, DXF R12, DWG, PDF, SVG, KML, KMZ, GeoJSON, Shapefile, GPX, LandXML, IFC 4, EPANET, PNG), Exportar relatório ▸ (CSV, TXT, XLSX, PDF, programação do controlador), Compartilhar por link, Detalhes do projeto, Georreferência |
| Editar | Desfazer, Refazer, Selecionar tudo, Copiar, Recortar, Colar, Duplicar seleção, Excluir seleção, Materiais da seleção, Salvar seleção como bloco, Inserir bloco, Modificar ▸ (rotacionar, espelhar, escalar, deslocar, aparar, estender, cortar tubo, alinhar por 2 pontos, matriz) |
| Ver | Enquadrar tudo, Aproximar/Afastar, Grade, Rótulos, Raios molhados, Alças de edição, Rótulos condicionais, GPS do aparelho, Sobreposição (nenhuma, velocidade, pressão, diâmetros, pressão mín/máx por zona, densograma, declividade do terreno, exposição do terreno), Mapa base ▸ (nenhum, OpenStreetMap, OpenTopoMap, CARTO, Esri imagem/ruas/topográfico, Google Maps mapa/satélite/híbrido/relevo com a sua própria chave de API, URL XYZ ou WMS personalizada; exige georreferência), Chave da API do Google Maps…, URL do mapa personalizado…, Idioma ▸, Tema ▸ (escuro, claro, seguir o sistema) |
| Desenhar | Linha, Polilinha, Retângulo, Círculo, Arco, Spline, Hachura, Símbolo, Texto, Cota, Cota angular, Cota radial, Cota de ordenada, Chamada (leader), Curva de nível, Cota de ponto, Área irrigada, Medir, Perfil de elevação, Comentário, Nuvem de revisão, GPS no campo ▸ (gravar trajeto a pé; terminá-lo como área irrigada, contorno fechado ou linha; marcar ponto na posição atual) |
| Zona | Tubo de zona, Lateral (sprayline), Fita/tubo gotejador, Emissor, Válvula de controle, Acessório hidráulico, Junção, Bloco de laterais, Grade de aspersores, Envelope de posição do submain, Densograma, Dispositivo nas laterais selecionadas, Converter laterais selecionadas em tubo cego, Controlador, Rota de fios, Rotas automáticas de fios |
| Linha principal | Fonte de água, Tubo principal, Bomba, Acessório hidráulico, emissor e junção na linha principal, Selecionar bomba, Transientes hidráulicos, Ventosas, Simulação de 24 horas, Operação sob demanda (Clément), Criticidade dos tubos, Calibrar rugosidade com medições, Fertirrigação, Pivô central / lateral móvel |
| Projeto | Parâmetros de projeto, Catálogo de componentes, Turnos de operação, Tarifa horária e horários dos turnos, Agrupar zonas por energia, Orçamento comercial, Alternativas do projeto, Clima do local, Terreno ▸ (curva de nível, linha de quebra, cota de ponto, perfil de elevação, baixar elevação da internet, gerar curvas de nível do modelo, vista 3D do terreno, limpar perfil, interpolação TIN ou IDW), Projeto automático ▸ (layout automático de aspersores, modelos de gramado esportivo e golfe, dividir talhão em blocos, anéis de gotejamento em pomar, ajustar pivô ao talhão, detectar vegetação na imagem), Verificação do projeto, Corrigir automaticamente, Otimizar projeto, Assistente de IA, Dimensionar zonas, Dimensionar linha principal, Projetar tudo, Analisar (tamanhos atuais), Analisar automaticamente ao editar, Vista 3D do terreno, Limpar resultados |
| Relatórios | As abas do painel |
| Ferramentas | Calculadora de lateral, Bomba e curva do sistema, Golpe de aríete, Bombeamento solar, Bulbo molhado, Orçamento hídrico do paisagismo, Autopropelido (carretel enrolador), Irrigação por superfície (sulcos, faixas, bacias), Tubo janelado, Unidades |
| Ajuda | Tutorial interativo, Boas-vindas e galeria de exemplos, Atalhos de teclado, Sobre |

### Atalhos de teclado

Com o desenho em foco, digite o alias e **Enter** ou **Espaço**; um alias completo também executa
sozinho após uma pausa. Os aliases aceitam nomes em português, inglês e espanhol (por exemplo
`LINHA`, `LINE`, `LINEA`). A lista completa está em Ajuda → Atalhos de teclado.

| Grupo | Aliases |
|---|---|
| Navegação | `S` seleção · `P` pan · `Z` / `ZE` enquadrar · `ZI` / `ZO` zoom |
| Desenho | `L` linha · `PL` polilinha · `REC` retângulo · `C` círculo · `A` arco · `SPL` spline · `H` hachura · `SY` / `I` símbolo · `T` / `MT` texto · `D` cota · `DAN` cota angular · `DRA` cota radial / de diâmetro · `DOR` cota de ordenada · `LE` chamada · `ME` / `DI` medir · `NOTE` / `NOTA` comentário · `RC` / `NUVEM` nuvem de revisão |
| Terreno | `CT` curva de nível · `BRK` / `QUEBRA` linha de quebra · `SP` cota de ponto · `PR` perfil · `AR` área irrigada |
| Edição | `RO` rotacionar · `MI` espelhar · `SC` escalar · `O` deslocar · `TR` aparar · `EX` estender · `CUT` / `BR` cortar tubo · `ARRAY` matriz · `E` apagar · `CO` copiar · `PA` colar · `U` desfazer · `REDO` · `ALL` selecionar tudo · `DUP` duplicar · `AL` alinhar por 2 pontos · `WBLOCK` / `SB` salvar seleção como bloco · `INSERT` / `INSERIR` inserir bloco |
| Zona | `ZP` tubo de zona · `SL` lateral · `DT` fita · `OUT` / `EM` emissor · `V` válvula · `F` acessório · `J` junção · `B` bloco · `AH` grade de aspersores · `FE` envelope do submain · `DENS` densograma |
| Elétrica | `CTRL` controlador · `WR` rota de fios · `WROUTE` / `ROTAS` rotas automáticas de fios |
| Linha principal | `MP` tubo principal · `WS` fonte · `PU` bomba · `PV` pivô |
| Projeto automático | `LAYOUT` layout de aspersores · `TPL` / `MODELO` modelos de gramado e golfe · `SUBDIV` / `TALHAO` blocos do talhão · `RINGS` / `ANEIS` anéis de gotejamento · `PFIT` ajuste do pivô · `VEG` vegetação |
| Análises | `SURGE` / `GOLPE` transientes · `AV` / `VENTOSA` ventosas · `EPS` simulação de 24 horas · `DEMAND` / `DEMANDA` operação sob demanda · `CRIT` criticidade · `CALIB` calibração da rugosidade · `FERT` fertirrigação · `TARIFF` / `TARIFA` horários pela tarifa · `EGROUP` / `ENERGIA` agrupamento por energia |
| Projeto e arquivos | `RUN` projetar · `CHK` verificar · `FIX` corrigir automaticamente · `OPT` otimizar · `IA` / `AI` / `ASK` assistente de IA · `REP` relatórios · `SAVE` · `OPEN` · `OS` snap · `OR` orto · `GS` snap à grade · `GR` grade |

| Tecla | Ação |
|---|---|
| F2 | Mostra/oculta relatórios |
| F3 | Liga/desliga snap a objetos |
| F5 | Projetar tudo |
| F7 | Grade |
| F8 | Orto |
| F9 | Snap à grade |
| F10 | Passo do rastreamento polar: desligado, 15°, 30°, 45°, 90° |
| Home | Enquadrar |
| Enter | Conclui a polilinha/lateral em desenho; ao selecionar, repete a última ferramenta |
| Esc | Cancela a ferramenta ou limpa a seleção |
| Del | Apaga a seleção |
| Shift (segurado) | Trava o segmento em 0°, 45°, 90° |
| Ctrl+Z / Ctrl+Y | Desfazer / refazer |
| Ctrl+A, Ctrl+D | Selecionar tudo, duplicar |
| Ctrl+C / X / V | Copiar, recortar, colar (também entre abas e janelas) |
| Ctrl+S, Ctrl+O, Ctrl+I | Salvar, abrir, importar |
| Ctrl+Alt+N / W / ← / → | Nova aba, fechar aba, alternar abas |

Enquanto uma ferramenta espera um ponto, a mesma linha de comando aceita coordenadas na unidade de
exibição: `x,y` absoluto, `@dx,dy` relativo ao ponto anterior, `@d<a` polar (distância e ângulo em
graus, anti-horário a partir do leste) ou só uma distância na direção do cursor, e Enter (`;`
separa números escritos com vírgula decimal).

Os atalhos são capturados nativamente (listener de teclado da janela no navegador,
`HardwareKeyboard` no desktop) e funcionam com qualquer widget em foco, exceto quando um menu ou
um diálogo está aberto.

---

## 5. Desenho e edição

### Entidades de desenho

Linha, polilinha (aberta ou fechada), retângulo, círculo, arco, spline (curva suave pelos pontos),
hachura (linhas ou sólida), símbolo (seta norte, árvore, edificação, tanque, poço, caixa de válvula,
casa de bombas, portão, estação de filtragem), texto, cota linear, angular, radial e de diâmetro (Ø),
cota de ordenada (o X ou o Y de um ponto a partir da origem do desenho: chamada vertical cota o X,
horizontal o Y), chamada (leader), imagem (raster georreferenciada, planta em PDF ou figura
colocada à mão), curva de nível, linha de quebra, cota de ponto e área irrigada. Entidades de
revisão: **comentários** (uma nota com autor, data e indicação de resolvido) e **nuvens de
revisão** (contorno em arcos com a marca, a data e a descrição da revisão; a tabela de revisões da
prancha as lista), cada uma com a sua aba de relatório.

### Snaps

Extremidades, pontos médios, centros, quadrantes, interseções (linhas, arcos e círculos),
perpendicular e tangente a partir do ponto anterior, extensão além da ponta de uma linha, nós
hidráulicos, "sobre" tubos e laterais (o ponto mais próximo do segmento), perímetro de círculos,
grade, orto, rastreamento polar (F10) e travamento em 45° com Shift. A tolerância é em pixels,
portanto independe do zoom. O marcador muda de forma conforme o tipo de snap.

### Seleção e grips

Clique seleciona; Shift+clique alterna; janela da esquerda para a direita seleciona o que está
inteiro dentro dela e da direita para a esquerda o que ela cruza (a convenção usual dos programas de CAD). Até 60
entidades selecionadas mostram **grips**: arraste um vértice para movê-lo, arraste o ponto médio
de um segmento para inserir um vértice, Ctrl+clique num vértice para removê-lo. Com *manter
conexões* (ligado por padrão), arrastar um nó de tubo leva junto as válvulas, os itens e as rotas de
fios que o compartilham; arrastar um vértice de fio move só os fios.

### Transformações

Mover (arraste), rotacionar, espelhar (mantendo ou não a origem), escalar, deslocar (offset),
aparar e estender contra as entidades selecionadas ou visíveis, cortar tubos, matriz retangular ou
polar e alinhamento por dois pontos (move, gira e escala uma imagem ou um desenho importado de uma
vez). Inserir válvula, junção, bomba ou acessório sobre um tubo divide o tubo no ponto. Zona →
Dispositivo nas laterais selecionadas… coloca o mesmo dispositivo (regulador, registro…) na entrada
de cada lateral e fita selecionada; Converter laterais selecionadas em tubo cego mantém o traçado
sem os emissores.

### Blocos do usuário

Editar → Salvar seleção como bloco (`WBLOCK`) guarda a seleção como um bloco com nome e ponto base
(um cavalete de válvulas, um arranjo padrão de aspersores, um carimbo); Inserir bloco (`INSERT`)
coloca cópias com rotação e escala num ponto clicado ou digitado, cada inserção um passo de
desfazer, com ids novos e as camadas que faltarem. A biblioteca vai no arquivo do projeto e é
exportada como definições de bloco no DXF/DWG.

### Camadas

Cada tipo de entidade nasce na sua camada padrão (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Camadas importadas de DXF/DWG/KML/PDF são
preservadas. Uma camada pode ficar oculta (sai do desenho, do snap e da seleção) ou bloqueada
(aparece, mas não se edita).

### Rótulos

Ver → Rótulos mostra nomes e diâmetros; Ver → Rótulos condicionais… cria regras que escrevem um
resultado junto aos tubos (velocidade, vazão, pressão, perda de carga, diâmetro), emissores
(pressão, vazão) ou válvulas (vazão, pressão, pressão a jusante) onde ele fica acima ou abaixo de um
valor, ou sempre, numa cor própria (velocidade acima de 1,5 m/s em vermelho, por exemplo). As regras
vão com o projeto.

### Histórico

Cada ação gera um estado nomeado (adicionar linha, mover 3 itens, projetar, importar…). Desfazer e
refazer percorrem até 150 estados (menos em desenhos muito grandes: as cópias guardadas ficam abaixo
de 400 000 entidades); o painel Histórico permite saltar para qualquer um deles. Os diálogos que
editam o projeto no lugar (detalhes, parâmetros, unidades, catálogo, gerenciamento) também geram um
passo de desfazer cada, seja qual for a forma de fechar (OK, Esc ou um clique fora): as edições
ficam, o projeto é marcado como alterado e os resultados calculados com as configurações antigas
são descartados. Um diálogo que gera algo (um layout, um bloco de laterais, as rotas dos fios) e
cada resposta do assistente de IA que alterou o projeto também são um passo.

---

## 6. Rede hidráulica

### Entidades hidráulicas

| Entidade | Alias | Camada | Papel no cálculo |
|---|---|---|---|
| Fonte de água | `WS` | WATER_SUPPLY | Origem da linha principal. Pressão calculada (poço com nível negativo, reservatório com altura positiva) ou fixa (rede pública com pressão e vazão de projeto e máximas). |
| Bomba | `PU` | PUMPS | Curva H(Q) do catálogo, com relação de velocidade, ou um inversor de frequência que mantém uma pressão alvo na saída entre uma rotação mínima e a máxima; curvas de rendimento e de NPSH requerido quando o catálogo as traz; ponto de operação no cálculo dos turnos; horímetro opcional. |
| Tubo principal | `MP` | MAINLINE_PIPES | Da fonte às válvulas; diâmetro fixo ou dimensionado (`computerSized`). |
| Válvula de zona | `V` | CONTROL_VALVES | Separa linha principal e zona; define o nome da zona; pode ter pressão de jusante fixa para análise detalhada. |
| Tubo de zona | `ZP` | ZONE_PIPES | Submains e distribuidores a jusante da válvula. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Tubo com emissores igualmente espaçados: emissor e bocal do catálogo, espaçamento, deslocamento do primeiro, arco, altura da haste, profundidade. |
| Fita / tubo gotejador | `DT` | TAPES | Emissores integrados definidos pelo item do catálogo; pressão de entrada, regulada ou não, vazão de lavagem. |
| Emissor individual | `OUT` | OUTLETS | Aspersor, microaspersor, gotejador, borbulhador, canhão ou ponto de demanda sobre um tubo de zona. Desenhado na linha principal é um aspersor com válvula (valve-in-head): uma estação própria, ou uma estação junto com os aspersores que têm o mesmo nome de estação. |
| Acessório | `F` | MISC_HYDRAULIC | Registro, filtro, regulador de pressão (com ajuste), válvula sustentadora de pressão (ajuste a montante), hidrante com limitador de vazão (ajuste de vazão), válvula mestra, hidrômetro, anti-refluxo, ventosa, válvula de retenção; em zona ou linha principal. |
| Junção | `J` | JUNCTIONS | Nó explícito, com cota fixa opcional. |
| Área irrigada | `AR` | AREAS | Polígono com cultura (da tabela FAO-56 ou texto livre) e data de plantio, classe textural e declividade do solo, método de irrigação, cobertura do solo, salinidade da água, método de chuva efetiva, lâmina líquida ou balanço hídrico (ETo, Kc, CAD, profundidade radicular, fração de esgotamento), eficiência, fração molhada, emissores por planta e, no paisagismo, o uso de água das plantas da sua hidrozona. |
| Pivô central / linear | `PV` | PIVOTS | Máquina com raio, vãos, profundidade de lâmina, ciclo, pressão final, canhão final, custo. Demanda sobre a linha principal; os dados da máquina (pacote de aspersores, transmissão e temporizador, braço de canto, prescrição de taxa variável, alimentação elétrica) abrem pelas Propriedades. |
| Controlador | `CTRL` | CONTROLLERS | Programador de irrigação: estações, tensão de saída (24 V CA), máximo de estações juntas, custo, sensores e acessórios (sensores de chuva, umidade do solo, vazão, geada e vento, relé de partida da bomba, proteção contra surtos). Alimenta os solenoides das válvulas pelas rotas de fios. |
| Rota de fios | `WR` | WIRES | Caminho dos fios do controlador passando pelas válvulas (vala ou eletroduto), desenhado à mão ou pelas Rotas automáticas de fios. Rotas que compartilham um vértice se unem; um controlador ou válvula sobre um vértice ou sobre a rota entra nela. |

### Regras de conexão

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

### Geradores

- **Bloco de laterais** (B): polígono, direção, espaçamento entre laterais, deslocamento da primeira,
  lateral com emissores ou fita, posição do submain (início, centro, fim), válvula (posição e modelo),
  comprimento do pé de válvula (stub), nomes. Se uma linha, polilinha, curva de nível ou spline
  estiver selecionada ao abrir o diálogo, ela pode servir de guia: as laterais seguem a curva
  (paralelas a uma curva de nível ou a uma divisa curva) e são recortadas pelo polígono. O submain
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
- **Envelope de posição do submain** (FE): para cada lateral selecionada, pinta em verde o trecho
  onde o submain pode alimentá-la respeitando a janela de pressão, considerando o terreno.

### Projeto automático (Projeto → Projeto automático)

Cada ferramenta mostra o resultado ao vivo e o gera num único passo de desfazer.

| Ferramenta | Alias | O que faz |
|---|---|---|
| Layout automático de aspersores | `LAYOUT` | Aspersores para um gramado ou canteiro (cantos, depois bordas, depois o interior, cabeça a cabeça, deixando de fora edificações e canteiros) com bocais de precipitação equivalente e a prévia de CU/DU/SC; opcionalmente zoneados por vazão (sem misturar classes de precipitação) e com o traçado: válvulas na linha principal, junto às zonas ou num cavalete, tubos de zona em árvore pelos aspersores e uma linha principal em árvore desde a fonte. |
| Modelos de gramado esportivo e golfe | `TPL` | Campo de futebol com 3, 4 ou 5 linhas de rotores, gramado interno de pista de atletismo, green de golfe cercado de setores, tee e fairway em malha triangular. |
| Dividir talhão em blocos | `SUBDIV` | Blocos de mesma área líquida, limitados por área ou por vazão, em faixas ou em grade, com carreadores, cada um com o lado do submain e a válvula, preenchidos pelo gerador de blocos e alimentados por uma linha principal. |
| Anéis de gotejamento em pomar | `RINGS` | Um anel de tubo gotejador ou de gotejadores em volta de cada árvore de uma malha de plantio ou de árvores levantadas, ligado a laterais ao longo das fileiras, a um submain e à válvula. |
| Ajustar pivô ao talhão | `PFIT` | O maior círculo completo livre dos obstáculos, ou o pivô setorial que irriga a maior parte do talhão, com o comprimento da máquina em vãos padrão. |
| Detectar vegetação na imagem | `VEG` | Gramados, árvores e arbustos encontrados por processamento de imagem neste aparelho (sem serviço externo) no mapa base da tela ou numa foto aérea selecionada, criados como áreas irrigadas (com predefinições por classe) e exclusões. Confira se os termos de uso das imagens permitem traçar sobre elas. |

---

## 7. Catálogo de componentes

O catálogo do projeto tem sete grupos: **tubos**, **emissores** (com bocais), **fitas**, **válvulas
e acessórios**, **bombas**, **conexões** e **fios**. Todos os valores hidráulicos internos estão em SI.

| Grupo | Campos principais |
|---|---|
| Tubos | DN, diâmetro interno, material (que define os coeficientes de Scobey e de Manning e a redução da classe de pressão do PVC e do PE com água quente), C de Hazen-Williams, rugosidade, classe de pressão, uso (lateral, zona, linha principal), custo por metro, fornecedor, código |
| Emissores e bocais | Tipo (aspersor, microaspersor, gotejador, borbulhador, canhão, ponto de demanda), curva `q = k·H^x`, raio molhado `R = a·H^b`, arco, pressão padrão, mínima e máxima, CV de fabricação, tolerância de vazão, diâmetro de entrada, altura da haste, custo; a curva de um bocal pode ser ajustada pelas linhas da tabela do fabricante (pressão, vazão e raio colados como tabela), e um perfil radial medido (ensaio de coletores) alimenta o densograma |
| Fitas | Diâmetro interno, espaçamento e curva do emissor, coeficiente de barb, CV, pressão de entrada padrão, mínima e máxima, tolerâncias acima e abaixo, classe, custo por metro |
| Válvulas e acessórios | Tipo (zona, mestra, PRV, sustentadora de pressão, controladora de vazão, registro, retenção, anti-refluxo, filtro, hidrômetro, ventosa, outro), diâmetro, perda `h = K·Q^n + C`, vazões mínima e máxima, ajuste padrão, custo |
| Bombas | Pontos (Q, H) ajustados a uma parábola, rendimento (ou uma curva de rendimento), curva de NPSH requerido, potência, vazão máxima, submersa ou de superfície, a frequência da rede em que a curva foi medida, custo |
| Conexões | Tipo (luva, cotovelo 90° e 45°, tê, cruzeta, redução, tampão, adaptador, derivação de lateral, final de fita, haste), diâmetros, custo |
| Fios | Seção do condutor (mm²), resistência (Ω/km), custo por metro, fornecedor, código; colunas CSV `mm2` ou `awg`, `ohmKm` (supõe-se cobre quando só a seção é dada) |

Qualquer item também pode trazer o código FINAME com que está credenciado para financiamento no
BNDES; a lista de materiais e o orçamento o mostram.

O **catálogo padrão** traz 17 tubos (PE 16–50 mm, PVC DN 35–250, PEAD 110 e 160, aço 6"), 10 famílias
de emissores (gotejadores PC e turbulentos, microaspersores, borbulhador PC, aspersor de impacto,
canhão, rotor e spray de jardim, ponto de demanda), 6 fitas e tubos gotejadores, 36 válvulas e
acessórios (1" a 6", entre eles válvulas mestras, sustentadoras de pressão e hidrantes com limitador
de vazão), 18 bombas (centrífugas de 1 a 100 cv, submersas de 3 a 30 cv) e cerca de 330 conexões
geradas para cada diâmetro nominal (luvas, cotovelos de 90° e 45°, tês, cruzetas, tampões,
adaptadores e reduções, mais conectores de lateral, finais de linha e tubos de subida) e 12 fios de
cobre (1 a 10 mm² habilitados, AWG 18 a 8 desabilitados: habilite-os onde a bitola AWG é a norma),
com nomes traduzidos e preços ilustrativos.

O editor (Projeto → Catálogo de componentes…) edita, duplica e remove itens, importa e exporta JSON,
CSV por grupo e **Excel** (exporte, preencha preços na planilha e importe de volta), define o
catálogo padrão para novos projetos e restaura o original.

### Preços e moeda

Todos os preços de um projeto (catálogo, tarifa de energia, máquinas de pivô) estão em uma única
moeda, guardada como código ISO 4217 junto com o símbolo mostrado nas tabelas e relatórios
(Projeto → Parâmetros de projeto → Moeda). Um projeto novo usa a moeda da região da máquina quando a
localidade do sistema no idioma da interface indica uma (`pt-PT` → EUR, `en-IN` → INR, `de-CH` → CHF);
senão, a moeda do país mais populoso do idioma (pt BRL, en USD, es MXN, de/fr EUR, ja JPY, zh CNY,
hi/mr/te/pa INR, bn BDT, ur PKR, ar EGP, ru RUB, tr TRY, id IDR, vi VND, ha NGN, sw TZS). Os preços
ilustrativos do catálogo padrão e a tarifa de energia padrão (0,75 R$/kWh) estão em reais e são
convertidos por câmbios de referência (Banco Central Europeu e exchangerate-api.com, 21/09/2026), de
modo que todos os idiomas chegam ao mesmo projeto; eles só ordenam as opções do dimensionamento
econômico e devem ser trocados pela tabela de preços local. Escolher outra moeda pergunta se todos os
preços devem ser convertidos, com o câmbio de referência sugerido e editável, e ela passa a ser a
moeda dos novos projetos. O catálogo padrão salvo guarda a sua moeda e é convertido para projetos em
outra. Os exemplos da galeria usam a moeda do seu idioma (no app, a moeda do usuário). A lista inclui
a UF chilena (`CLF`), a unidade corrigida pela inflação em que os concursos de subsídio público do
Chile pedem orçamentos (tomada como CLP 40 000; digite o valor do dia ao converter).

Itens sem preço (os pacotes de fabricantes vêm sem preço) são apontados pelo assistente de projeto
(`bom_unpriced`); a lista de materiais os deixa fora dos totais e o dimensionamento econômico dá a um
tubo sem custo um preço proporcional à seção da parede, calibrado pelos tubos com preço do mesmo
material, para que os diâmetros mantenham a ordem.

### Catálogos de fabricantes (`.oci.cat`)

Quatorze pacotes acompanham o app (259 itens): Hunter, Rain Bird, Toro, Netafim, Rivulis,
NaanDanJain, Jain, Nelson e Senninger (aspersores, microaspersores, gotejadores, fitas e tubos
gotejadores, emissores de pivô, canhões, válvulas e reguladores), Irritec (tubos gotejadores e
gotejadores), Bermad (válvulas hidráulicas), Schneider (bombas centrífugas e submersas 4", com curvas
medidas em 60 Hz) e Amanco Wavin e Multilit (tubos de PVC para irrigação, NBR 14312). Os dados vêm
das tabelas publicadas pelos fabricantes: curvas dos bocais `q = k·H^x` e raios `R = a·H^b`
ajustados por mínimos quadrados às linhas de pressão, vazão e raio (o raio ancorado na pressão de
projeto), constantes, expoentes, diâmetros internos e perdas no gotejador (Kd) como impressos,
faixas de pressão e classes de parede, perdas das válvulas ajustadas às tabelas de perda (ou tiradas
do Kv) e curvas das bombas das tabelas de seleção (eficiência estimada pela potência nominal, já que
as tabelas não a trazem). Cada pacote lista os documentos de origem (`sources`). Os preços ficam em
zero; um pacote com preços informa a moeda (`currency`) e é convertido para a moeda do projeto ao
ser adicionado; uma bomba informa a frequência em que a sua curva foi medida (`hz`), de modo que em
outra rede (Parâmetros de projeto) uma bomba de rotação fixa gira na proporção. Eles ficam em
[catalogs/](catalogs/) como arquivos JSON, um por fabricante, mais um `index.json`. Pelo diálogo
*Catálogos de fabricantes…* você adiciona um pacote ao projeto, importa um arquivo `.oci.cat` ou
carrega um pacote ou um índice inteiro por URL, o que permite a qualquer revenda ou comunidade manter
o próprio repositório. O catálogo do projeto também é exportado nesse formato. O formato completo,
com os campos de cada grupo e as regras de contribuição, está em [catalogs/README.md](catalogs/README.md);
`dart run tool/gen_catalogs.dart` valida os pacotes (ids únicos, curvas plausíveis) e refaz o índice.

---

## 8. Terreno

- **Fontes de elevação**: curvas de nível desenhadas (com incremento automático e opção de
  suavizar), linhas de quebra (`BRK`: cristas, canais e taludes em que a superfície deve dobrar),
  cotas de ponto (a elevação é pedida a cada clique), pontos de levantamento (CSV, TXT, XYZ, PNEZD),
  DXF/DWG/DGN com elevação (polilinhas em camadas de contorno ou com cota), KML com altitude,
  shapefile com Z ou atributo de elevação, waypoints de GPX, nuvens de pontos LAS (a classe de
  terreno), superfícies e pontos LandXML, GeoTIFF de elevação (raster de uma banda) e a
  **elevação da internet**.
- **Modelo digital**: triangulação de Delaunay (TIN) restrita pelas linhas de quebra, com
  interpolação linear nos triângulos, exata em rampas planas, e interpolação por inverso da
  distância como alternativa e como complemento fora do casco convexo. As curvas de nível são
  amostradas a cada 5 m (ajustável). O TIN aceita até 12 000 amostras: um terreno maior é
  triangulado a partir de um subconjunto uniforme, o que o app avisa uma vez por projeto (a
  interpolação IDW usa todas); nuvens de pontos e superfícies LandXML são rarefeitas numa grade ao
  serem lidas.
- **Elevação da internet** (Projeto → Terreno → Baixar elevação da internet (MDT)…): uma grade de
  pontos sobre o projeto ou sobre a área visível é consultada em serviços públicos e gratuitos, sem
  chave: Terrain Tiles no AWS Open Data (SRTM 30 m, GMTED, ETOPO1; o padrão), Open-Meteo (Copernicus
  GLO-90; 600 coordenadas por minuto) e, nos builds para desktop, OpenTopoData (SRTM 30 m, ASTER
  30 m; a sua API pública não envia cabeçalho CORS, então navegadores não podem usá-la). Por padrão
  o download substitui as cotas que você informou, que costumam estar em outro datum que o modelo.
  Num projeto vazio basta colar a coordenada do local (decimal, link do Google Maps ou
  graus/minutos/segundos): a origem do desenho vai para lá e a elevação é baixada num quadrado ao
  redor. Ao terminar, as curvas de nível podem ser geradas automaticamente com intervalo escolhido a
  partir do desnível.
- **Ferramentas**: gerar curvas de nível do modelo (curvas derivadas, que não realimentam o modelo),
  vista 3D do terreno com os tubos drapejados, mapas de declividade e de exposição (Ver →
  sobreposição, com a fração da área em cada classe de declividade), perfil ao longo de um caminho
  (com o tubo e a linha piezométrica quando há resultados), e a pressão de cada emissor considera a
  cota do terreno mais a altura da haste menos a profundidade de enterro.

---

## 9. Cálculo e dimensionamento

### Parâmetros de projeto (Projeto → Parâmetros de projeto)

| Grupo | Parâmetros e padrões |
|---|---|
| Hidráulica | Fórmula de perda de carga: Hazen-Williams (padrão), Darcy-Weisbach, Scobey ou Manning; temperatura da água 20 °C (viscosidade, pressão de vapor e a redução da classe de pressão do PVC e do PE); perdas localizadas como 5 % do comprimento (padrão) ou o K das curvas e tês encontrados no desenho, ligadas; escala e deslocamento do C (envelhecimento); tolerância de conexão 0,05 m; máximo de 100 nós agregados por lateral |
| Velocidades máximas | 2,0 m/s em laterais, 1,5 m/s em zona, 2,0 m/s em linha principal |
| Dimensionamento | Método LP (padrão) ou velocidade + janela de pressão (greedy); diâmetros por lateral (1), por submain (3) e por linha principal (3); variação máxima de pressão na zona (0 = derivada da tolerância de vazão do emissor); emissores por planta (1) |
| Economia | Juros 10 %, prazo 10 anos, energia 0,75 por kWh, eficiência da bomba 65 %, 2000 h/ano de linha principal e 500 h/ano por zona, balanço capital × energia ligado, moeda da região ou do idioma (veja *Preços e moeda*); frequência da rede elétrica 60 Hz (uma bomba de rotação fixa cuja curva foi medida em outra frequência gira na proporção: uma curva de 60 Hz numa rede de 50 Hz roda a 5/6 da rotação e 69 % da altura) |
| Lavagem e segurança | Velocidade de lavagem das fitas 0,3 m/s com pressão mínima de 1 m na ponta aberta; verificação de golpe de aríete ligada com tempo de fechamento de válvula (0 = instantâneo) |
| Materiais | Seleção automática de conexões ligada; barra de tubo de 6 m para contar luvas |
| Terreno | Interpolação por triangulação (padrão) ou inverso da distância; densificação das curvas 5 m |
| Elétrica | Solenoides de 24 V CA: corrente de partida 0,37 A, de retenção 0,22 A, tensão mínima no solenoide 20 V; folga de fio de 10 % sobre o comprimento da rota |

### Etapas do cálculo

1. **Construção do grafo**: entidades → nós e trechos; vértices coincidentes fundidos; itens
   pontuais inseridos nos tubos; laterais agregadas; cotas do terreno em cada nó; zonas
   identificadas a partir de cada válvula; conexões (curvas e tês) encontradas quando as perdas
   localizadas vêm delas.
2. **Zonas**, uma a uma:
   - dimensionamento inicial por velocidade máxima, que também fornece as vazões nominais;
   - **LP**: cada trecho dimensionável pode ser composto por frações dos diâmetros candidatos; o
     programa linear minimiza o custo anualizado dos tubos mais o custo de energia da pressão de
     entrada, sujeito à janela de pressão dos emissores críticos (ponta, ponto mais alto e mais
     baixo de cada lateral, cada emissor isolado). Se a análise não confirmar a janela, os emissores
     de pressão mínima e máxima entram como restrições e o LP roda de novo (até quatro rodadas);
   - **classe de pressão**: o LP e os passos gulosos oferecem a cada trecho só os tubos cuja classe,
     na temperatura da água, suporta a pressão que a análise encontrou ali (o PVC perde parte da
     classe acima de 25 °C e o PE acima de 20 °C); quando uma passada termina com um tubo abaixo da
     sua pressão, a exigência do trecho sobe e a zona é dimensionada de novo (até três passadas).
     Se nada no catálogo for resistente o bastante, o trecho é dimensionado como antes e a classe
     aparece como excedida;
   - **reparo**: aumento guloso de diâmetro ao longo do caminho crítico até a janela ser atendida;
   - **racionalização**: diâmetros decrescentes de montante para jusante e telescopagem dentro do
     limite de diâmetros por unidade;
   - **análise detalhada**: rede não linear com emissores dependentes da pressão; a pressão a
     jusante da válvula é escolhida por bissecção para que a pressão média dos emissores seja a
     nominal (ou, para fitas reguladas, para garantir a pressão mínima de submain);
   - resultados: vazão da zona, pressões mínima e máxima e admissíveis, variação admissível e real,
     pressão requerida na válvula, perda na válvula, uniformidade (CU de Christiansen, DU do quartil
     inferior, EU de Keller-Karmeli com o CV do fabricante e emissores por planta, uniformidade
     estatística, variação de vazão), CU de sobreposição para aspersores com raio molhado, tabela de
     tubos com pressões, cotas e velocidades, tabela de emissores.
3. **Linha principal**, por turno: demanda e pressão requerida de cada válvula, pivô (o que o seu
   pacote de aspersores pede) e estação de aspersores com válvula programada, LP sobre todos os
   turnos com custo de energia ponderado pelas horas de cada um e as mesmas passadas de classe de
   pressão; numa linha principal em anel os diâmetros decidem como a vazão se divide, então o LP é
   resolvido de novo com as vazões dos novos diâmetros até a escolha se firmar (até mais quatro
   vezes). Depois, a análise de cada turno com bombas (ponto de operação; um inversor encontra a
   rotação que mantém a pressão alvo na saída; o NPSH disponível é comparado com a curva da bomba),
   válvulas redutoras, sustentadoras e controladoras de vazão, válvulas de retenção e fontes de
   pressão fixa ou calculada; duty de cada fonte (vazão, pressão disponível, requerida, déficit) e
   energia anual.
4. **Telescopagem**: tubos com mais de um diâmetro são divididos em entidades, maior diâmetro a
   montante, e as zonas afetadas são reanalisadas.
5. **Lavagem**: cada zona com fitas é analisada com as pontas abertas na velocidade de lavagem;
   reporta vazão de lavagem, pressão necessária na válvula e a montante, número de fitas, pressão
   mínima na ponta e velocidade máxima.
6. **Golpe de aríete**: para o pior trecho de cada tubo, celeridade da onda pelo material e parede,
   sobrepressão de Joukowsky para a velocidade de operação, tempo crítico 2L/a e comparação da
   pressão estática máxima mais sobrepressão com a classe do tubo, considerando o tempo de
   fechamento (a análise completa de transientes fica em Linha principal → Transientes
   hidráulicos…, adiante).
7. **Máquinas mecanizadas**: o pacote de aspersores e a tabela do temporizador de cada pivô central
   e linear e, quando os dados são informados, o braço de canto, a prescrição de taxa variável e o
   projeto elétrico (veja *Agronomia, máquinas mecanizadas e calculadoras de campo*).
8. **Fiação das válvulas** (quando o desenho tem controlador ou rota de fios): menor caminho de cada
   controlador até cada válvula, estações em ordem de distância e, para cada controlador, o fio
   comum e o fio de estação de cada válvula de menor custo tal que cada solenoide, ao abrir
   (corrente de partida) com as outras válvulas do seu turno já ligadas (corrente de retenção), tenha
   pelo menos a tensão mínima. A queda é `I·R·L` no fio de estação mais, em cada trecho do comum, a
   corrente das válvulas além dele; os comprimentos incluem a folga. Sem turnos, todas as válvulas
   ficam ligadas juntas, como no cálculo hidráulico. Uma válvula mestra fica ligada com todas as
   zonas (saída 0, fio próprio, a sua corrente no comum), e cada estação de aspersores com válvula
   ocupa uma estação com os aspersores em paralelo. Informa estações, comprimentos de rota e de fio,
   bitolas, tensões nos solenoides e a corrente de pico de cada controlador; avisa sobre válvulas
   sem fio, rotas que não chegam a um controlador, controladores com poucas estações ou abrindo
   mais válvulas do que acionam juntas e tensões abaixo da mínima.
9. **Materiais**: tubos por diâmetro e classe, emissores, fitas, válvulas, acessórios, bombas
   (com seleção automática a partir do catálogo e motor padrão IEC; horímetros das bombas), pivôs
   com torres, aspersores e reguladores, **conexões selecionadas automaticamente** da geometria
   (luvas por barra, cotovelos, tês, cruzetas, reduções, tampões, derivações de lateral, finais de
   fita, hastes) e os itens elétricos (fios por bitola, controladores e os seus acessórios, dois
   conectores à prova d'água por válvula), com custos, códigos FINAME quando o catálogo os traz,
   custo anualizado (fator de recuperação de capital) mais energia; também separados por setor
   (Materiais por setor) e para a seleção atual (Editar → Materiais da seleção…).

O cálculo roda num **Web Worker** no navegador (ou num isolate no desktop) e devolve à interface as
entidades redimensionadas e os resultados; enquanto ele roda, a edição é bloqueada para não perder
alterações, mas navegação, relatórios e outras abas seguem livres. Com Projeto → Analisar
automaticamente ao editar, um instante depois de cada edição o projeto é analisado de novo sem
redimensionar, e pressões, vazões e mensagens acompanham o desenho (um indicador na barra de status
mostra isso).

### Verificação de projeto

| Código | Gravidade | Significado |
|---|---|---|
| `unconnected` | erro | Item hidráulico sem ligação com a rede |
| `no_supply` | erro | Nenhuma fonte de água |
| `no_valves` | erro | Nenhuma válvula de zona (nem pivô) |
| `zone_no_emitters` | erro | Válvula sem emissores a jusante |
| `spec_missing` | erro | Item referencia um componente que não está no catálogo |
| `zero_length` | erro | Tubo de comprimento nulo |
| `pivot_unconnected` | erro | Pivô fora de um nó da linha principal |
| `pipes_cross` | aviso | Tubos que se cruzam sem junção |
| `mainline_dead_end` | aviso | Ponta solta na linha principal |
| `duplicate_item`, `duplicate_zone_name` | aviso | Itens sobrepostos; zonas com o mesmo nome |
| `tiny_segment` | aviso | Segmento menor que a tolerância |
| `supply_no_head` | aviso | Fonte de pressão fixa sem pressão informada |
| `zone_mixed_emitters` | aviso | Zona que mistura gotejamento com aspersão, ou aspersores cujas taxas de aplicação diferem mais de 1,8 vez (sprays com rotores, setores sem bocais equivalentes) |
| `zone_dead_end`, `area_no_emitters`, `no_terrain`, `looped_mainline`, `no_hydraulics` | informação | Situações que merecem atenção mas não impedem o cálculo |
| `elec_stations`, `elec_voltage` | erro | Controlador com menos estações que válvulas ligadas a ele; tensão no solenoide abaixo da mínima mesmo com o fio mais grosso habilitado |
| `elec_unwired`, `elec_wire_orphan`, `elec_ctrl_unwired`, `elec_no_controller`, `elec_no_wires`, `elec_simultaneous` | aviso | Válvula sem fio até um controlador; rota que não chega a nenhum controlador; controlador fora das rotas; rotas sem controlador; nenhum fio habilitado no catálogo; turno que abre mais válvulas do que o controlador aciona juntas |

### Mensagens do cálculo

Cada zona, turno e etapa pode emitir avisos, mostrados na aba Mensagens e junto ao item: pressão
fora da janela, velocidade excedida, classe de pressão excedida (em operação ou por golpe de aríete),
válvula fora da faixa de vazão, bomba fora da curva, NPSH disponível abaixo do que a bomba exige,
inversor que não alcança a pressão alvo ou que precisaria de rotação abaixo da mínima, fonte com
vazão ou pressão excedida, déficit de pressão na válvula, no pivô ou numa estação de aspersores com
válvula (ou estação acima da janela, ou fora de todos os turnos), LP inviável (com o método guloso
assumindo), linha principal em anel (o LP a dimensiona por caminhos em árvore e repete; a análise
final confere), componentes de catálogo ausentes, taxa de aplicação do pivô acima do limite do
solo, entre outras.

### Assistente de projeto: explicações e correção com um clique

A aba Mensagens e a verificação do projeto mostram cada problema num cartão: o que aconteceu,
**por que importa** e **como resolver**, um botão para mostrar o item no desenho, **Perguntar à IA**
(que abre o assistente de IA com uma pergunta sobre aquela mensagem; nada é enviado antes de você
clicar em Enviar) e, quando existe, um botão que corrige (cada correção é um passo de desfazer).
Além do desenho e dos resultados, o assistente confere **configurações impossíveis**: velocidade,
horas, parâmetros econômicos, tolerância, variação na zona ou temperatura da água fora das faixas
físicas, nenhum tubo habilitado no catálogo para um uso, máximos da fonte abaixo dos valores de
projeto, zonas fora de todos os turnos, turnos vazios, pressão do emissor fora da faixa do bocal,
rotação da bomba fora da faixa.

- **Correções**: ligar um item solto ao lado do tubo, remover tubos de comprimento zero, vértices
  repetidos e duplicados, renomear zonas repetidas, escolher (ou inserir) a bomba de menor custo de
  ciclo de vida, trocar por submersa a bomba de superfície que não consegue succionar, tubo de
  classe de pressão maior, válvula do tamanho certo, dividir as zonas em mais turnos, voltar aos
  parâmetros padrão, pôr num turno as zonas esquecidas, a pressão nominal do emissor, controlador com
  estações suficientes (o próximo tamanho padrão), habilitar os fios do catálogo, entre outras.
- **Corrigir automaticamente** (menu Projeto, `FIX`): correções seguras e cálculos em rodadas até
  não haver mais o que corrigir, tudo num único passo de desfazer, com um resumo do que mudou e do
  que depende de uma decisão sua.
- **Otimizar projeto** (menu Projeto, `OPT`): menor custo anual (investimento anualizado + energia)
  que atende todos os requisitos — dimensionamento LP, as menores válvulas adequadas e a bomba de
  menor custo de ciclo de vida; só fica se melhorar, com comparação antes / depois.
- Depois de um cálculo com erros a aba Mensagens abre sozinha e mostra quantos problemas há.

### Análises da linha principal e da operação

Rodam sobre o projeto calculado (cada uma diz o que falta quando não há cálculo ou fonte de água);
o que propõem (ventosas inseridas, horários, turnos, rotas de fios, um fator de C) é aplicado num
único passo de desfazer.

| Análise | Menu, alias | O que faz |
|---|---|---|
| Transientes hidráulicos | Linha principal, `SURGE` | Método das características na linha principal de cada turno: as válvulas de zona fechando no tempo de fechamento, uma queda de energia desligando as bombas (inércia estimada pela potência e pela rotação, retenções fechando no fluxo reverso) e um registro fechando; celeridade da onda pela parede de cada tubo, cavidades de vapor (separação de coluna), as ventosas desenhadas agindo como ventosas combinadas; envoltórias de carga e de pressão por tubo contra a classe e contra o vácuo, o perfil ao longo do caminho crítico, séries temporais na bomba e no pior ponto, e as constatações. |
| Ventosas | Linha principal, `AV` | Perfil de cada caminho de uma fonte até uma ponta da linha principal e as ventosas que a prática do manual AWWA M51 pede (pontos altos, mudanças de declividade, trechos longos, recalque da bomba, retenções, pontas da linha, linha piezométrica baixa, vácuo do transiente), dimensionadas pela vazão de ar no orifício e inseridas com o item de catálogo que serve. |
| Simulação de 24 horas | Linha principal, `EPS` | Os turnos ao longo de um dia nos seus horários e durações, cada bomba ligada enquanto um turno que ela atende está rodando; energia e custo por bomba e por hora na tarifa dos parâmetros, com um horário de ponta opcional. |
| Operação sob demanda | Linha principal, `DEMAND` | Vazões de projeto de uma rede ramificada de hidrantes pela fórmula de Clément e a verificação contra configurações aleatórias de hidrantes abertos (FAO 59): confiabilidade e déficit de pressão por hidrante; os hidrantes podem ter limitador de vazão. |
| Criticidade dos tubos | Linha principal, `CRIT` | Cada tubo fechado por vez (N−1): a demanda cortada e a demanda que as pressões restantes não atendem, com os tubos ordenados. |
| Calibração da rugosidade | Linha principal, `CALIB` | Fatores do C de Hazen-Williams (um só, ou um por grupo de material) ajustados a pressões e vazões medidas no campo, por mínimos quadrados ponderados com o solver de rede no laço. |
| Fertirrigação | Linha principal, `FERT` | Tempos de chegada de um produto injetado na fonte ou na bomba até cada válvula e até o emissor mais distante, o plano de injeção (pré-molhamento, injeção, lavagem), as quantidades para uma dose por hectare e a verificação de um injetor venturi. |
| Tarifa horária e horários dos turnos | Projeto, `TARIFF` | Preço da energia por faixa do dia, demanda contratada e estações do ano, e o desconto da irrigação rural brasileira (uma janela de até 8 h 30 min por dia em até três blocos, nunca entre 17h00 e 21h30, Resolução Normativa ANEEL nº 1.000/2021, art. 186, e Portaria Normativa MME nº 137/2026); os horários de menor custo diário. |
| Agrupar zonas por energia | Projeto, `EGROUP` | Zonas (e pivôs e estações de aspersores com válvula) agrupadas em turnos de altura requerida parecida, para que a bomba não dê a cada zona a pressão da mais exigente; comparado com o agrupamento por vazão. |
| Rotas automáticas de fios | Zona, `WROUTE` | Rotas de fios ao longo das valas dos tubos de cada controlador até as suas válvulas, válvulas mestras e relés de partida de bomba (menores caminhos na fiação convencional, uma árvore do tipo Steiner num percurso de dois fios), e o dimensionamento de um sistema de dois fios (decodificadores) sobre elas: decodificadores, cabo, tensão em cada decodificador, pontos de aterramento. |

### Agronomia, máquinas mecanizadas e calculadoras de campo

- **Clima do local** (Projeto → Clima do local…): normais mensais de ETo (Penman-Monteith FAO),
  chuva (média e provável) e radiação solar, baixadas para o local do Open-Meteo (histórico
  meteorológico, ERA5) ou da NASA POWER, ou digitadas, guardadas no projeto com a sua origem.
- **Necessidade por cultura** (aba de relatório): cada área irrigada com uma cultura da tabela
  FAO-56 ganha a sua tabela por mês e fase de desenvolvimento a partir do clima do local, do solo
  (12 classes texturais do USDA), do método de chuva efetiva (USDA-SCS, FAO/AGLW, empírico da FAO,
  uma fração da chuva), da necessidade de lixiviação para a salinidade da água (FAO-29) e, no
  gotejamento, da redução do Kc pela cobertura do solo; totais por área e a categoria de
  licenciamento da Resolução CONAMA 284/2001 por método e área (informativa).
- **Máquinas mecanizadas**: as Propriedades de um pivô central ou linear abrem **Pacote,
  temporizador, braço, VRI e elétrica…**: o pacote de aspersores (vazão por saída para uma lâmina
  uniforme, reguladores, pendurais, bocais numerados ou do catálogo, canhão final e booster), a
  tabela do temporizador pela transmissão, um braço de canto que segue um caminho guia (com o aviso
  de salto), uma prescrição de taxa variável por zonas ou setores (CSV) e o projeto elétrico (queda
  no cabo vão a vão, partida dos motores, tamanho do gerador). As abas Pacote do pivô e Braço, VRI e
  elétrica os listam.
- **Calculadoras** (menu Ferramentas): lateral (comprimento máximo, perdas e uniformidade de uma
  lateral ou fita em declive); bomba e curva do sistema (ponto de operação, potência e energia
  anual); golpe de aríete (sobrepressão de Joukowsky contra a classe do tubo); bombeamento solar
  (gerador fotovoltaico para o volume diário de cada mês, com a comparação com a rede); bulbo
  molhado de um gotejador e a fração molhada da área; orçamento hídrico do paisagismo (MAWA e ETWU,
  com tempos de ciclo e infiltração); autopropelido (espaçamento entre faixas, velocidade, lâmina,
  perda na mangueira, pressão de entrada); irrigação por superfície (sulcos, faixas e bacias por
  balanço de volume: avanço, corte, eficiências); tubo janelado (aberturas das janelas ou diâmetros
  dos furos para uma vazão por sulco).

### Assistente de IA (opcional)

Projeto → Assistente de IA… (`IA`, `AI`, `ASK`), o botão dele na barra de status ou **Perguntar à
IA** em qualquer cartão de mensagem abre um agente de IA que trabalha no projeto aberto num painel
encaixado ao lado do desenho (uma folha inferior no celular), para você ver o desenho mudar enquanto
ele trabalha. Ele usa um modelo da Anthropic (Claude, pela API Messages) ou da OpenAI (GPT, pela API
Responses), com a sua própria chave de API dessa empresa: o navegador (ou o app de desktop) chama a
API da empresa diretamente, sem servidor deste projeto no meio, e a empresa cobra o uso na sua
conta. O painel mostra os tokens de cada resposta e da conversa, com uma estimativa em US$ pelos
preços de tabela abaixo, que podem mudar.

| Empresa | Nível | Modelo | Id | US$ por milhão de tokens, entrada / saída |
|---|---|---|---|---|
| Anthropic | topo | Claude Fable 5.1 | `claude-fable-5-1` | 10 / 50 |
| Anthropic | topo | Claude Opus 5.5 (o padrão) | `claude-opus-5-5` | 4 / 20 |
| Anthropic | intermediário | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 |
| Anthropic | rápido | Claude Haiku 5.5 | `claude-haiku-5-5` | 0,10 / 0,50 (5 × acima de 100 000 tokens de entrada) |
| OpenAI | topo | GPT-6 Astra | `gpt-6-astra` | 10 / 50 |
| OpenAI | intermediário | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 |
| OpenAI | intermediário, versões anteriores | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 |
| OpenAI | rápido | GPT-6 Luna | `gpt-6-luna` | 0,10 / 0,50 |

Pedidos à OpenAI com mais de 272 000 tokens de entrada custam 2 × na entrada e 1,5 × na saída; as
configurações também mostram os preços de cache de cada modelo. Todos os modelos aceitam cinco
profundidades de raciocínio, de rápido a máximo (equilibrado por padrão). O Claude Fable 5.1 e o
GPT-6 Astra podem pensar vários minutos num só passo, e o Claude Fable 5.1 só é oferecido a
organizações com retenção de dados de 30 dias (senão o app explica e sugere o Claude Opus 5.5). No
Claude Fable 5.1, no Opus 5.5 e no Sonnet 5.5 um pedido que um classificador de segurança recusa é
respondido por outro modelo do lado da Anthropic, cobrado pelo modelo que respondeu. Trocar para um
modelo da outra empresa, ou entre modelos da OpenAI, começa uma conversa nova; entre modelos Claude
a conversa continua.

**Começar com a IA.** O app abre num projeto vazio, com uma tela de início que pergunta onde fica a
área a irrigar e se você quer projetar com o assistente (não quando o endereço já diz o que abrir, um
exemplo, o tutorial ou um projeto compartilhado, nem depois de recuperar trabalho; "Não mostrar esta
tela ao iniciar" e uma chave nas configurações do assistente a desligam). O local é um endereço ou
nome de lugar buscado no OpenStreetMap (você escolhe entre os resultados) ou coordenadas em qualquer
formato usual; o projeto é georreferenciado ali e o mapa de satélite aparece. **Projetar com a IA**
abre o assistente ao lado do desenho com o local e a sua descrição, ou um pedido para começar um
projeto novo, esperando na caixa; nada é enviado antes de você clicar em Enviar. **Começar sem IA**
deixa você no projeto vazio, já georreferenciado. No celular o assistente tem um botão na barra superior, que gira enquanto ele trabalha e mostra
um ponto quando ele espera uma aprovação, uma resposta ou uma decisão sobre o plano (o botão do painel
encaixado faz o mesmo).

**Como funciona.** O agente mantém uma lista de tarefas, faz perguntas em cartões com opções quando
falta algo (a tarefa espera as respostas), apresenta o seu plano e trabalha pelas ferramentas do
próprio programa: 73 ferramentas enviadas em todo pedido, mais 102 operações que ele encontra e
executa (`find_operations`, `run_operation`), qualquer comando dos menus (`run_command`, com os
diálogos executados sem abrir) e 134 configurações (`get_setting`, `set_setting`). Ele lê os mesmos
números dos relatórios, altera o projeto pelas mesmas funções dos menus e diálogos (desenho, rede,
catálogo, turnos, o cálculo, as suas correções, os layouts automáticos, as análises, o orçamento,
exportações), mantém as **notas de IA** do projeto (requisitos, as suas respostas e decisões,
gravadas no arquivo do projeto e editáveis nas configurações, cada atualização um passo de
desfazer), lê o manual de procedimentos do tipo de projeto (12, escritos a partir dos exemplos da
galeria) e os projetos de exemplo, encontra o local a partir de um endereço (Nominatim do
OpenStreetMap: no máximo uma busca por segundo e 8 por conversa), define a georreferência e o mapa
base, baixa o terreno e o clima pelos downloads do próprio app e importa os desenhos e arquivos de
GIS que você anexar. Ele também lê uma ficha técnica anexada (PDF, imagem ou texto, até 20 MB) e põe
os itens dela no catálogo, conferidos antes de entrar, e escreve o memorial descritivo do projeto,
que pode ser copiado ou posto no desenho como texto. [docs/AI_TOOLS.md](docs/AI_TOOLS.md), gerado a
partir do mapa de cobertura, lista o que ele alcança: das 1677 funções que um usuário alcança (ações
de comando, ferramentas de desenho, aliases, itens de menu, diálogos e suas opções, campos dos
painéis, barra de status, opções de vista), 1637 estão cobertas, 40 não fazem sentido para a IA
(cada uma com o motivo) e nenhuma falta; um teste falha quando um comando, ferramenta, item de menu
ou diálogo novo não tem rota. O prompt de sistema traz as regras da rede, o cálculo e as permissões
e indexa um manual de referência que o modelo lê quando precisa (`read_manual`, 20 tópicos gerados a
partir do código: itens e seus campos, parâmetros de projeto, códigos de mensagem, ferramentas e
operações, os valores do motor, e um exemplo resolvido refeito com as ferramentas reais); o prompt e
as definições das ferramentas ficam em cache entre os pedidos.

**Visão.** `view_snapshot` tira uma imagem do desenho sobre um mapa base: por padrão a imagem de
satélite sempre que o projeto está georreferenciado (Esri World Imagery, ou o Google com a sua chave),
para o modelo desenhar sobre o que existe de fato no terreno, e, sem georreferência, o mapa da tela; o
modelo também pode pedir o mapa da tela, um mapa de ruas ou nenhum. Os tiles são baixados fora da
tela, então a sua vista e o seu mapa base nunca mudam. O modelo também escolhe pelo que o desenho é
colorido na imagem dele (cores das camadas, pressões, velocidades, diâmetros, a menor e a maior
pressão de cada zona, ou cada zona na sua cor com o nome na válvula) e o que fica marcado nela: as
mensagens do projeto nos seus itens, numeradas como na lista de Mensagens, e as próprias alterações
da tarefa (acréscimos em ciano, mudanças em âmbar, remoções em contorno tracejado vermelho), para
conferir o que fez; a sua tela continua como está. Cada imagem informa a correspondência exata entre
pixel e mundo, e `image_to_world` converte as posições que o modelo lê nela, podendo imantá-las nas
pontas e linhas de itens existentes para que os tubos novos encontrem os antigos; uma imagem feita
antes de a georreferência mudar é recusada. `trace_region` contorna um talhão, gramado, lago ou
telhado a partir de um ponto dentro dele por análise da imagem aérea (a região cresce sobre cores e
textura semelhantes até a tolerância em que a área para de crescer, antes de vazar para o talhão
vizinho), com muito mais exatidão do que cantos escolhidos a olho, e `trace_fields` contorna todos os
talhões de uma área de uma vez (estradas, cercas vivas, manchas pequenas e regiões cortadas pela borda
da área ficam de fora). O modelo pode ampliar uma parte,
rotular os itens, desenhar formas propostas com `preview_geometry` antes de criar qualquer coisa e ler
o terreno com `terrain_picture` (sombreamento, cores por elevação, curvas de nível, declividade,
exposição), `terrain_profile` e `terrain_info`. As imagens têm o tamanho que o modelo lê pixel a
pixel: até 2000 pixels e cerca de 3,6 megapixels no Claude Opus 5.5, Sonnet 5.5 e Fable 5.1, senão
1568 pixels e cerca de 1,15 megapixel, com o lado menor de no máximo 768 pixels nos modelos da
OpenAI; imagens aéreas e de relevo vão em JPEG, o que mantém conversas longas dentro do tamanho de
uma solicitação, e fotos anexadas são endireitadas e reduzidas a no máximo 2000 pixels de lado. No
Claude Opus 5.5, Sonnet 5.5 e Fable 5.1 a linha de status mostra as notas curtas de progresso do
modelo entre as etapas. O painel tem um botão que anexa uma imagem da sua vista; imagens e arquivos
também podem ser colados na caixa de mensagem (Ctrl+V) ou soltos sobre o painel. Uma configuração
(ligada por padrão) envia, depois de cada rodada de alterações, uma imagem enquadrada no que mudou,
com as alterações marcadas. Uma foto anexada que traz a posição do GPS (como os celulares gravam)
chega com o lugar onde foi tirada no projeto e o item mais próximo, e o modelo pode fixá-la no desenho
com `add_photo_comment`: um comentário de revisão naquele ponto, com uma cópia pequena da foto e o que
o modelo leu nela (a placa de uma bomba, o estado de uma caixa de válvula), mostrado nas propriedades.
Antes de exportar uma prancha de desenho, o modelo a olha com `preview_sheet`: a prancha como vai ser
impressa, com uma verificação de textos sobrepostos, pequenos demais ou cortados, de um desenho que
ocupa pouco da área de desenho ou sai dela, dos campos vazios do carimbo e do norte, da escala gráfica
e da legenda, cada achado com o lugar onde está, para corrigi-los antes.

**Apontar.** "Marcar ponto" e "Marcar linha", acima da caixa de mensagem, mostram ao assistente onde:
cada clique no desenho acrescenta uma marca laranja com rótulo A, B, C… (uma linha termina com duplo
clique ou Enter; Esc a descarta), cada uma com uma nota opcional ("bomba", "adutora até aqui"). As
marcas vão com a sua próxima mensagem, com as coordenadas, e aparecem nas imagens do assistente,
então "a bomba em A, a adutora por B" é entendido com exatidão; o assistente também pode pedir que
você marque um lugar. Elas não fazem parte do projeto (nenhum passo de desfazer, nada salvo) e somem
quando você as limpa ou abre outro projeto; no celular, a janela do assistente fecha enquanto você
marca e volta quando você termina. Os comandos `MK` e `MKL` também as iniciam.

**Voz.** Um botão de microfone ao lado da caixa de mensagem dita a mensagem pelo serviço de voz do
navegador, no idioma da interface (Chrome, Edge e Safari; não há no Firefox nem no app de desktop): as
palavras sendo reconhecidas aparecem num pequeno balão acima do botão e cada frase confirmada entra
na caixa no lugar do cursor, para ser lida e enviada como se fosse digitada. No primeiro uso, o app
diz para onde vai a voz.

**Conversas guardadas.** Recarregar a página, ou abrir o projeto de novo mais tarde no mesmo
navegador, traz a conversa dele de volta como estava, e o modelo continua com o histórico exato de
antes; uma resposta que o fechamento da página interrompeu aparece como parada, com **Tentar de
novo**. Voltar no tempo numa conversa restaurada desfaz só a conversa (o histórico de desfazer do
projeto não sobrevive a uma recarga).

**Controle.** O que ele pode fazer é definido nas configurações: **somente leitura**; **planejar
primeiro** (ele explora só com leituras e apresenta um plano; as alterações começam depois que você
o aprovar); **perguntar antes de cada alteração** (o padrão: um cartão com Aplicar, Pular e Parar,
também para cada consulta a outro serviço); ou **aplicar alterações automaticamente** (salvar um
arquivo, definir a georreferência e excluir mais de 20 itens continuam pedindo confirmação). Você
pode escrever enquanto ele trabalha (a mensagem chega a ele na próxima etapa) e pará-lo a qualquer
momento. Aprovar um plano com "aplicar automaticamente" roda aquela tarefa sem perguntar; o modo
escolhido nas configurações continua valendo para as próximas. Depois de um erro ou de uma parada, a
resposta oferece **Tentar de novo** (a mesma mensagem, quando nada dela chegou ao modelo) ou
**Continuar**, e as configurações quando a correção está lá (uma chave recusada, um modelo que a chave
não pode usar). Cada resposta que alterou o projeto é uma entrada do histórico com **Desfazer estas
alterações**, e cada mensagem tem **Voltar a este ponto**, que leva o projeto (pelo histórico de
desfazer) e a conversa de volta a antes dela. Uma tarefa termina no limite de etapas (50 por padrão,
até 200) ou no teto de gasto (US$ 2 por padrão a preços de lista, com aviso em 80 % e um botão
**Continuar** para mais um teto). O teto é do próprio app: o modelo não vê nenhuma contagem de
tokens (um orçamento de tarefa fazia ele parar cedo e sugerir uma conversa nova), e as instruções
dele dizem que há contexto de sobra. Conversas longas são resumidas no servidor da
empresa (na Anthropic a partir de 150 000 tokens de entrada, depois de limpar resultados antigos de
ferramentas a partir de 80 000, guardando as notas, o plano e a lista de tarefas; na OpenAI a partir
de 200 000, tirando do pedido as imagens mais antigas); uma configuração desliga isso. Comandos
rápidos: `/new`, `/design`, `/check`, `/review`, `/report`, `/quote`, `/export`, `/plan`, `/clear` e
`/cost`. `/review` roda em modo somente leitura qualquer que seja o modo: o modelo olha as zonas, as
mensagens marcadas nos itens e as pressões e velocidades sobre o desenho, lê as mensagens e as tabelas
de relatório e responde com uma lista de verificação (OK, atenção ou problema, com os números e onde
corrigir cada ponto), sem alterar nada.
Instruções permanentes nas configurações valem para todas as conversas ("sempre PVC PN 80 na
adutora"), e a conversa pode ser salva em Markdown. As conversas não são salvas com o projeto, de
modo que arquivos e links compartilhados nunca levam a conversa nem as suas imagens. O que é
enviado, quando, e como as chaves são guardadas: [seção 12](#12-armazenamento-privacidade-e-rede).

---

## 10. Relatórios, plotagem e exportação

### Painel de relatórios

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

### Pranchas em PDF

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

### Orçamento comercial e alternativas

Projeto → Orçamento comercial… transforma a lista de materiais num orçamento: preços de venda com a
margem, mão de obra, escavação das valas (volumes a partir dos tubos enterrados e das medidas da
vala), linhas extras, desconto, impostos e frete, validade e condições; retorno (payback), VPL e TIR
a partir de um benefício anual; um cronograma de obra pelas equipes e pela produção de cada uma por
dia; os códigos FINAME (financiamento do BNDES) dos itens que os têm. Projeto → Alternativas do
projeto… guarda cópias nomeadas do projeto com os seus números principais, compara-as lado a lado e
restaura uma num único passo de desfazer.

### Exportações

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

---

## 11. Formatos de arquivo

### Projeto (`.oci.json`)

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

### Importação

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
| EPANET (.inp) | A rede desenhada: tubos, bombas e válvulas como polilinhas nas camadas `EPANET_*`, nós com seus ids | Unidades US convertidas; posicionada pela georreferência ou em metros locais; o leitor do motor também monta a rede hidráulica ([docs/API.pt-BR.md](docs/API.pt-BR.md)) |
| CSV, TXT, XYZ, PNEZD | Pontos de levantamento | Colunas detectadas pelo cabeçalho ou posição; vírgula decimal aceita (também em colunas separadas por espaço), separador de milhar também; uma coluna de texto dá nome aos pontos; lat/lon reconhecidos |
| GeoTIFF de elevação | Grade de cotas | Uma banda de alturas, float ou inteiro, nodata ignorado; BigTIFF é recusado pelo nome |
| JPG, PNG, GeoTIFF, zip com world file | Imagem de fundo | Georreferenciada (world file, inclusive rotacionado; tags GeoTIFF) ou colocada à mão e alinhada por 2 pontos; rasters com mais de 100 milhões de pixels são recusados antes de decodificar |

**Sistemas de coordenadas.** Os leitores que trazem um sistema de coordenadas (`.prj` do shapefile,
`crs` do GeoJSON, LandXML, LAS) reconhecem WKT 1 (nas variantes ESRI e OGC), WKT 2, códigos EPSG e
URNs da OGC. Dados em SAD 69 e Córrego Alegre são deslocados para o SIRGAS 2000 com as translações
de três parâmetros do IBGE (precisão de alguns metros); SIRGAS 2000, WGS 84, ETRS89 e NAD83 são
tratados como idênticos na precisão de um mapa de projeto. Um sistema não reconhecido é informado,
não adivinhado.

### Catálogos e exemplos

Pacotes `.oci.cat` em [catalogs/](catalogs/) (formato em [catalogs/README.md](catalogs/README.md)) e
projetos de exemplo em [examples/](examples/), regenerados por ferramentas e guardados por testes.

---

## 12. Armazenamento, privacidade e rede

- **Autosave** no armazenamento do navegador, no máximo a cada 3 segundos de atividade e ao fechar
  uma aba; **projetos recentes** (os 8 últimos) em Arquivo → Projetos recentes; **versões** (as 10
  últimas gravações de cada projeto) em Arquivo → Histórico de versões; **recuperação** ao abrir o
  app quando há autosaves não salvos. Projetos acima de 256 KB de JSON são guardados comprimidos; o
  limite por projeto é de cerca de 3,5 MB depois da compressão. Quando nem assim cabe, as imagens
  embutidas ficam de fora da cópia automática, e o app avisa uma vez por projeto (ou avisa que o
  projeto não cabe ali: salve-o num arquivo). A cópia automática é feita em segundo plano: o
  navegador a comprime ao lado do app, então um projeto grande não trava a janela depois de um
  cálculo nem durante a edição. Um aviso do navegador aparece ao fechar a aba com alterações.
- **Arquivos**: Salvar gera `.oci.json` para download; Abrir lê do disco. Nada é enviado a servidores.
- **Compartilhar por link** (Arquivo → Compartilhar por link…): o projeto inteiro, comprimido, vai
  dentro do endereço, depois do `#`, parte que o navegador não envia a nenhum servidor; quem abre o
  link recebe uma cópia numa aba nova. Imagens, fotos de comentários e resultados ficam de fora (quem recebe calcula de
  novo); um link com mais de cerca de 60 000 caracteres pode ser cortado por aplicativos de e-mail e
  de mensagem, e um projeto grande demais para um link vai como arquivo.
- **Sem rede**: depois que o app rodou num navegador, o service worker dele guarda uma cópia do app
  (cerca de 24 MB, uma vez por versão) e a próxima abertura, do app instalado ou do site, funciona
  sem rede. Mapas base, elevação e clima online, catálogos carregados por URL e o assistente de IA
  continuam precisando dela. Uma versão nova é baixada em segundo plano e usada a partir da abertura
  seguinte.
- **Acesso à internet**, só quando você pede: elevação online (Terrain Tiles na AWS, Open-Meteo,
  OpenTopoData nos builds para desktop), clima do local (histórico meteorológico do Open-Meteo, NASA
  POWER), mapas base (OpenStreetMap, OpenTopoMap, CARTO, Esri, Google Maps com a sua própria chave
  ou uma URL XYZ ou WMS personalizada), catálogos carregados por URL e o assistente de IA. Os
  pedidos de elevação e de clima levam as coordenadas do local, nada do projeto. A chave do Google
  Maps fica só no navegador e é enviada apenas ao Google; onde o servidor não tem imagem no zoom
  atual, o app amplia o tile mais próximo em vez de mostrar um aviso de "dados indisponíveis". As
  fontes da interface para escritas que o app não traz são baixadas do Google Fonts na primeira vez
  em que são necessárias.
- **Assistente de IA** (opcional, [seção 9](#assistente-de-ia-opcional)): o único recurso que envia
  dados do projeto a terceiros, e só por ação sua. Nada sai antes de você enviar uma mensagem; então
  os pedidos vão só para a empresa do modelo que você escolheu, a Anthropic (`api.anthropic.com`)
  ou a OpenAI (`api.openai.com`, com `store: false`), com a sua chave dela: a sua mensagem, os
  arquivos anexados, os dados do projeto que você marcou (um texto compacto montado das tabelas dos
  relatórios e das mensagens do projeto, com a posição do local arredondada a cerca de um
  quilômetro; a vista *Dados enviados* mostra o texto exato da próxima mensagem), as mensagens
  anteriores da conversa e, enquanto o modelo trabalha, os resultados das ferramentas que ele chama:
  tabelas, itens e imagens do desenho sobre o mapa base, inclusive a imagem de satélite (valem os
  termos do provedor das imagens, Esri ou Google, para o que sai; as imagens baixam os seus tiles
  como a tela faz, sem perguntar). Uma busca do local por endereço envia o endereço ao Nominatim do
  OpenStreetMap (`nominatim.openstreetmap.org`), com a sua aprovação, a não ser que as alterações
  sejam aplicadas automaticamente. Cada chave fica na memória enquanto a página está aberta; com
  *Lembrar a chave neste dispositivo* ela é guardada no armazenamento do navegador, onde scripts que
  rodam na página (como o de estatística de visitas do site) poderiam lê-la. As chaves nunca entram
  no arquivo do projeto, no autosave, nos links de compartilhamento nem nas exportações, e cada uma
  só vai para a sua própria empresa. O ditado por voz envia o som da sua voz ao serviço de voz do
  navegador (o Chrome usa os servidores do Google, o Edge os da Microsoft e o Safari os da Apple),
  que devolve o texto; o app não grava nem guarda o áudio, e o texto só chega à IA quando você o
  envia. Uma foto fixada com `add_photo_comment` guarda uma cópia pequena (cerca de 480 pixels) no
  arquivo do projeto, fora dos links de compartilhamento; o modelo lê só o tamanho dela. As notas de IA fazem parte do arquivo do projeto, então vão
  com ele e com os links de compartilhamento. As conversas ficam no armazenamento deste navegador
  (IndexedDB), por projeto, com as imagens e os arquivos pequenos anexados, mas nunca as chaves, de
  modo que recarregar a página ou abrir o projeto de novo as traz de volta; as 12 mais recentes são
  guardadas, e *Guardar as conversas neste navegador*, nas configurações do assistente, desliga isso
  e as apaga. O que cada empresa faz com os pedidos é regido pelo seu acordo com ela.
- **Estatística de visitas**: as páginas de opencadirrigation.com carregam o Google Analytics
  (gtag.js), que conta as visitas; o app não envia a ele nada dos projetos.
- **Idioma e preferências** (idioma escolhido, tema, catálogo padrão, tutorial concluído, as
  configurações do assistente) ficam nas preferências do navegador.

---

## 13. Idiomas e site

A interface está em **20 idiomas**, os mais falados do mundo. Português, inglês e espanhol vêm
compilados no app; chinês (`zh`), hindi (`hi`), árabe (`ar`), francês (`fr`), bengali (`bn`), russo
(`ru`), urdu (`ur`), indonésio (`id`), alemão (`de`), japonês (`ja`), marati (`mr`), vietnamita
(`vi`), télugo (`te`), hauçá (`ha`), turco (`tr`), panjabi (`pa`, escrita gurmukhi) e suaíli (`sw`)
são pacotes de idioma em `assets/i18n/<código>.json`, baixados só quando o idioma é escolhido (a
interface mostra inglês até o pacote chegar, uma fração de segundo). Cada pacote traduz toda a tabela
de textos, o tutorial interativo e os nomes do catálogo padrão; o worker de projeto recebe o pacote
junto com o pedido, então relatórios e plotagens também saem no idioma escolhido. O app abre no
primeiro idioma da lista de idiomas preferidos do sistema (do navegador ou do sistema operacional)
que ele fala, e em inglês quando nenhum deles é falado; a troca em Ver → Idioma (cada idioma com o
próprio nome) fica salva. As páginas de idioma (`/pt/`, `/de/`, …) e o parâmetro `?lang=` valem só para a visita.
O atributo `lang` do documento acompanha o idioma do app (`pt-BR`, `zh-CN`, senão o código). Em
árabe e urdu a interface é montada da direita para a esquerda. Os PDFs imprimem todas essas
escritas (seção 10): antes de gravar um PDF, as fontes Noto de que os seus textos precisam são
carregadas uma vez por sessão. Os projetos de exemplo distribuídos existem nos 20 idiomas
(`examples/<código>/`).

Um pacote é um JSON simples com três seções: `strings` (chave → texto), `tutorial` e `catalog`
(texto de origem em inglês → texto). Tradutores podem revisá-lo sem tocar no código;
`test/core/i18n_packs_test.dart` verifica que cada pacote cobre todas as chaves com os mesmos
marcadores.

O site é gerado por `dart run tool/gen_site.dart` a partir de `tool/site.dart`: `web/index.html`
(inglês, a página de quem chega sem idioma escolhido), um `web/<código>/index.html` para cada um
dos outros 19 idiomas da interface (`web/pt/`, `web/es/`, `web/de/`, `web/zh/`, …; a lista segue
`supportedLanguages`, então um idioma novo no app precisa da sua página), um redirecionamento em
`web/en/index.html` para o endereço que o inglês tinha antes, `web/sitemap.xml` e `web/404.html`
(no idioma do navegador quando o site o tem). Os textos das páginas ficam em `tool/site.dart`
(português, inglês, espanhol) e em `tool/site/<código>.dart` (os demais, com a galeria de exemplos
tirada dos pacotes de idioma); as páginas em árabe e urdu são da direita para a esquerda. Como o
Flutter desenha em canvas, cada página traz o conteúdo em HTML real (título, recursos, exemplos,
perguntas frequentes), com canônica própria, `hreflang` entre todas as versões, Open Graph e JSON-LD
(aplicativo, perguntas frequentes, como funciona e galeria de exemplos, no idioma da página, com o
assunto ligado à Wikipédia/Wikidata). O teste `test/web_metadata_test.dart` falha quando os arquivos
gerados divergem do template.

Esse HTML é tudo o que uma primeira visita baixa (e o que buscadores e o PageSpeed medem): o app,
de vários megabytes, só é baixado quando o visitante o abre (os botões e os links de exemplo da
página o iniciam ali mesmo), chega por um endereço do app (`?example=`, `?tutorial=`, `?design=`, `?ai=`,
`?lang=`, o `?source=pwa` do app instalado) ou já o usou naquele navegador (qualquer chave
`opencadirrigation.` no `localStorage`); a página fica então escondida sob o app.
`web/flutter_bootstrap.js` é o carregador do Flutter sem o service worker obsoleto do Flutter, e
`tool/build_web.sh` tira a referência ao `flutter.js.map` que o build não gera e compila com
`--no-web-resources-cdn`: o CanvasKit e a fonte Roboto vêm do próprio site, não da CDN do Google. O
logo do topo é WebP em três larguras (`web/brand/logo-horizontal-{520,780,1040}.webp`, feitos de
`logo-horizontal.png`), com o endereço versionado por um hash do arquivo. O site é servido pelo
Firebase Hosting a partir de uma pasta de publicação fora deste repositório (`firebase.json` +
`public/`, cópia de `build/web`). O `firebase.json` não tem rewrite genérico, então um endereço
inexistente recebe o `404.html` com status 404 em vez da página do app (o que fazia o PageSpeed ver
`/.well-known/ai-catalog.json` como um catálogo de IA quebrado); as páginas, `flutter_bootstrap.js`,
`manifest.json`, `version.json`, `sw.js` e `offline.js` vão com `no-cache`, e as imagens de `brand/`,
`icons/`, `screenshots/` e da raiz ficam 30 dias em cache.

**Abertura sem rede.** Quando o primeiro quadro já está na tela e o navegador está ocioso,
`flutter_bootstrap.js` carrega `web/offline.js`, que registra o service worker do próprio app,
`web/sw.js`; assim a primeira visita nunca fica mais lenta por causa dele. `tool/build_web.sh`
termina com `dart run tool/gen_sw.dart`, que grava no `sw.js` do build o nome do build (versão,
commit git, data e um hash dos arquivos) e os arquivos de que uma abertura pode precisar, com seus
SHA-256: a página raiz, o bootstrap, `main.dart.js`, o worker de cálculo, o manifest e os ícones,
todos os assets do Flutter (pacotes de idioma e fontes do PDF incluídos), o logo e o CanvasKit (só a
variante do navegador), cerca de 24 MB descompactados, 3,7 MB transferidos. Na instalação o worker
preenche um cache por build (`oci-shell-<build>`): os arquivos que não mudaram desde o build
anterior são copiados do cache dele, os outros são baixados passando por cima do cache HTTP e
conferidos pelo hash. Ele responde primeiro pelo cache e revalida a página de abertura depois do
primeiro quadro; guarda as fontes de fallback que o motor baixa de fonts.gstatic.com; tiles de mapa,
elevação, clima e analytics vão direto para a rede. Um build novo é instalado em segundo plano e
assumido na próxima abertura (uma janela nova ou um recarregamento); uma página já aberta continua
com o build com que abriu, e o cache de um build é apagado quando nenhuma página o usa mais. Um
`sw.js` que não foi preenchido (`flutter run`, um `flutter build web` simples) só remove a si mesmo
e os seus caches.

O gerador também escreve o que buscadores e assistentes de IA leem além das páginas:
`web/robots.txt` (tudo liberado, com os robôs de busca e de IA nomeados: GPTBot, OAI-SearchBot,
ClaudeBot, PerplexityBot, Google-Extended, Applebot-Extended, CCBot, bingbot e outros),
`web/llms.txt` (o resumo do [llmstxt.org](https://llmstxt.org): o que é o app, fatos principais e
links para a página de cada idioma e cada exemplo) e `web/llms-full.txt` (a referência completa em
Markdown: recursos, fluxo de projeto, métodos hidráulicos, dimensionamento, catálogos, formatos,
links diretos, limitações, perguntas frequentes; as seções técnicas ficam em `tool/site/llms.dart` e
seguem o README em inglês), `web/humans.txt` e a chave IndexNow `web/<chave>.txt`. Depois de publicar,
`dart run tool/indexnow.dart` pede ao Bing, ao Yandex e aos outros buscadores do IndexNow que
rastreiem as páginas de novo (o índice do Bing também responde ao Copilot e à busca do ChatGPT);
`--dry-run` mostra a requisição sem enviá-la.

---

## 14. Arquitetura do código

```
bin/oci.dart                linha de comando: design, analyze, check, export e bom de projetos .oci.json
lib/
  core/                     Dart puro, sem Flutter (roda no worker, no isolate, nas ferramentas e na CLI)
    api.dart                o motor inteiro numa importação (docs/API.pt-BR.md)
    hydraulics/             fórmulas e solvers
      friction.dart           Hazen-Williams, Darcy-Weisbach (Swamee-Jain, Colebrook, Blasius, laminar,
                              transição), Scobey, Manning
      minor_losses.dart       K de acessórios, comprimento equivalente, curva h = K·Q^n + C
      emitter.dart            q = k·H^x, raio molhado, ajuste pela tabela do fabricante, janela de
                              pressão, CU de sobreposição
      lateral.dart            análise passo a passo de laterais, comprimento máximo, posições de alimentação
      network.dart            solver de rede (Global Gradient Algorithm) com emissores, bombas, PRV, PSV,
                              FCV, retenção
      sparse_solver.dart      LDLᵀ esparso com ordenação por grau mínimo
      pump.dart               curvas de bomba e do sistema, ponto de operação, potência, NPSH, CRF, energia
      uniformity.dart         CU, DU, EU, Us, variação de vazão
      water_hammer.dart       celeridade, Joukowsky, tempo crítico
      transient.dart          transientes pelo método das características (desligamento de bomba,
                              ventosas, reservatórios hidropneumáticos, cavidades de vapor)
      eps.dart                simulação de período estendido: reservatórios, horários, padrões,
                              controles, energia
    model/                  dados
      geometry.dart           Pt, Bounds, segmentos, polígonos, offsets, casco convexo, transformações afins
      entities.dart           entidades de desenho e hidráulicas (JSON, clone, transformar, grips, distância)
      catalog.dart            catálogo de componentes e base padrão, redução da classe dos tubos
      catalog_packs.dart      pacotes de fabricantes (em memória) e fusão
      currency.dart           moedas, padrão por idioma/região, câmbios de referência, conversão de preços
      project.dart            projeto: meta, parâmetros, catálogo, camadas, entidades, turnos
      terrain.dart, tin.dart  modelo do terreno: TIN de Delaunay restrito por linhas de quebra, IDW,
                              curvas de nível
      slope_map.dart          declividade e exposição numa grade
      spatial_index.dart      R-tree STR para culling, seleção e snap
      split.dart              divisão de entidades lineares
      blocks.dart, label_rules.dart, scenario.dart, proposal_settings.dart, site_climate.dart,
      pivot_machine.dart      blocos do usuário, rótulos condicionais, alternativas, configurações do
                              orçamento, clima do local, dados da máquina do pivô
    design/                 projetista
      network_builder.dart    entidades → grafo hidráulico (nós, trechos, zonas, agregação de emissores,
                              conexões)
      designer.dart           orquestração: zonas, linha principal, classes de pressão, telescopagem,
                              lavagem, golpe de aríete, máquinas, fiação, BOM
      lp.dart, lp_sizing.dart simplex denso de duas fases e formulação do dimensionamento
      block_generator.dart    blocos de laterais (retos e guiados) e grades de aspersores
      auto_layout.dart, zoning.dart, routing.dart, templates.dart, field_subdivision.dart,
      tree_rings.dart, pivot_fit.dart, vegetation.dart
                              projeto automático: aspersores, zonas, árvores de tubos e da linha
                              principal, modelos de gramado, blocos, anéis, ajuste de pivô, vegetação
                              em imagem aérea
      pivot.dart              hidráulica de pivô central e linear
      mechanised.dart, pivot_package.dart, corner_arm.dart, vri.dart, pivot_electrical.dart
                              pacote de aspersores e temporizador, braço de canto, taxa variável,
                              elétrica do pivô
      traveller.dart, surface_irrigation.dart, gated_pipe.dart
                              autopropelidos, sulcos, faixas e bacias, tubo janelado
      fittings.dart           seleção automática de conexões
      pump_selection.dart     escolha de bomba e motor
      agronomy.dart           ETc, balanço hídrico, programa do controlador
      climate.dart, crops.dart, soils.dart, effective_rain.dart, irrigation_requirement.dart,
      area_requirement.dart   ETo e culturas da FAO-56, solos do USDA, chuva efetiva, tabelas de necessidade
      solar_pumping.dart, wetted_bulb.dart, water_budget.dart
                              bombeamento fotovoltaico, bulbo molhado, orçamento hídrico do paisagismo
      management.dart         demandas das zonas, pivôs e estações, turnos automáticos
      valve_in_head.dart      estações de aspersores com válvula
      densogram.dart          água aplicada pelos aspersores como desenhados, uniformidade por área, vento
      electrical.dart         fiação das válvulas: rotas, estações, bitolas pela tensão no solenoide
      two_wire.dart, wire_routing.dart
                              dimensionamento de dois fios (decodificadores), rotas de fios pelas valas
      transient_analysis.dart, air_valves.dart
                              transientes da linha principal, ventosas (AWWA M51), simulação de 24 horas
      network_ops.dart, on_demand.dart, tariff.dart, energy_grouping.dart, criticality.dart,
      calibration.dart, fertigation.dart
                              operação: vazões de Clément, horários pela tarifa, agrupamento por
                              energia, N−1, calibração, fertirrigação
      proposal.dart           orçamento comercial, valas, retorno, cronograma de obra
      design_check.dart       verificação de projeto
      advisor.dart            problemas explicados, configurações impossíveis, correções aplicáveis
      auto_fix.dart           correções, corrigir automaticamente, otimização
      results.dart, report_tables.dart  resultados serializáveis e tabelas dos relatórios
    io/                     leitura e escrita de formatos
      dxf.dart, dwg.dart, dgn.dart, kml.dart, shp.dart, geojson_reader.dart, gpx.dart, landxml.dart,
      las.dart, epanet_inp.dart, points_csv.dart, point_grid.dart, geoimage.dart, dem_tiff.dart
                              leitores (os de EPANET, GPX e LandXML também escrevem)
      cad_drawing.dart, cad_export.dart, dxf_r2000.dart, dwg_writer.dart
                              DXF e DWG R2000 com entidades nativas
      pdf_reader.dart, pdf_reader_fonts.dart, pdf_reader_images.dart, pdf_import.dart
                              plantas em PDF como base de fundo
      plot.dart, pdf.dart, pdf_sheet.dart, sheet_set.dart, sheet_canvas.dart, details.dart,
      plot_charts.dart, svg.dart
                              cena de plotagem, escritor PDF, conjuntos de folhas, detalhes
                              construtivos, gráficos, SVG
      fonts/                  leitor e subconjunto de TrueType, formatação OpenType (árabe, índicas),
                              bidi, dados Unicode, o registro de fontes do PDF
      shp_writer.dart, geo_export.dart, ifc.dart, xlsx.dart, catalog_io.dart, project_export.dart
                              shapefile, KML/GeoJSON, IFC 4, Excel, catálogos, despacho das exportações
      geo.dart, datum.dart    UTM, datums (SIRGAS 2000, SAD 69, Córrego Alegre), reconhecimento de sistemas
      dem_online.dart, climate_online.dart, share_link.dart
                              elevação e clima online, projetos num link
    ai/                     assistente de IA opcional, duas empresas atrás de uma só interface
      llm.dart                modelos com seus níveis e preços de tabela, tokens e custo, erros, o
                              cliente que cada empresa implementa
      llm_formats.dart        conversão de mensagens, ferramentas e resultados para o formato de cada empresa
      claude_api.dart         API Messages da Anthropic: streaming, raciocínio adaptativo, esforço,
                              cache, fallback de recusa, orçamento da tarefa, compactação, limpeza de
                              resultados antigos de ferramentas
      openai_api.dart         API Responses da OpenAI: streaming, ferramentas de função, esforço de
                              raciocínio, store: false, compactação
      agent_loop.dart         o laço do agente: ferramentas, aprovações por modo, limite de etapas,
                              teto de gasto
      project_context.dart    os dados do projeto enviados com uma mensagem
    units.dart              unidades (métrico/US), viscosidade da água, tabelas digitadas
    translate.dart          gancho de tradução para relatórios e plotagens rotularem a saída sem Flutter
    i18n/language_packs.dart registro dos pacotes de idioma (textos, tutorial, nomes do catálogo)
  app/                      Flutter
    state/                  ProjectController (projeto, seleção, câmera, undo, índice espacial, cálculo),
                            Workspace (abas e área de transferência), DesignRunner (worker/isolate/thread)
    canvas/                 CadCanvas, CadPainter, Camera, Snapper, mapa base
    tools/                  ferramentas de desenho, edição e hidráulica, pontos digitados, inserção de blocos
    keys/                   despachador de atalhos e listener nativo
    widgets/                menus, paleta, painéis, relatórios, gráficos, diálogos, layout compacto, e
                            ai/: o painel encaixado da IA e as suas vistas (conversa, dados enviados,
                            configurações)
    ai/                     o agente de uma aba: 73 ferramentas e 102 operações sobre o controller e o
                            motor (agent_tools*, agent_ops*, ops_*), o mapa de cobertura
                            (ai_coverage.dart), o prompt de sistema, o manual e os procedimentos,
                            visão (imagens, tiles, terreno), transportes (fetch, HttpClient),
                            aprovações, voltar e desfazer
    tutorial/               tutorial interativo
    io/                     arquivos, preferências, HTTP, armazenamento local, documento HTML, links externos,
                            GPS, fontes do PDF, exportação PNG de uma prancha
    actions.dart            ações de arquivo, área de transferência e exportação compartilhadas por menus, paleta e atalhos
    examples.dart           galeria de exemplos
    i18n.dart               tabela de textos pt/en/es, lista de idiomas e carregamento sob demanda dos pacotes
    i18n_assets.dart        lê assets/i18n/<código>.json para o idioma escolhido
    shortcuts.dart          aliases de comando (pt/en/es) e tabela de atalhos
    theme.dart              paletas escura e clara (CadPalette, 76 cores lidas por Cad.*), a regra de
                            cores CAD do canvas claro, troca de tema (CadThemeHost)
    version.dart            versão do app gerada (tool/gen_version.dart)
  worker/design_worker.dart entrada do Web Worker
assets/                     pacotes de idioma (i18n/) e os subconjuntos Noto dos PDFs (fonts/)
catalogs/                   pacotes de fabricantes (JSON) e índice
docs/                       estudo técnico, a API do motor (API.md, API.pt-BR.md) e o que a IA alcança
                            (AI_TOOLS.md, gerado)
examples/                   projetos de exemplo, uma pasta por idioma da interface (20)
tool/                       geradores: site, catálogos, exemplos, marca, versão, service worker; builds do
                            worker e da web; fontes e fixtures de formatação de texto (tool/fonts)
test/                       testes do motor, do modelo, dos formatos e da interface
web/                        páginas, manifest, ícones, robots, sitemap, worker compilado, abertura sem rede
                            (sw.js, offline.js)
```

### Decisões de projeto

- **Motor em Dart puro.** `lib/core` não importa Flutter, por isso roda no Web Worker, no isolate,
  em `dart run` (ferramentas e linha de comando) e em testes rápidos. A interface só monta
  requisições e mostra resultados.
- **Um controller por projeto.** `ProjectController` guarda o projeto, a seleção, a câmera, a pilha
  de desfazer (snapshots das entidades), o índice espacial e o estado do cálculo. Toda edição passa
  por `mutate`, que tira o snapshot, marca o projeto como sujo, invalida resultados e o índice,
  notifica a interface e agenda o autosave.
- **Cálculo fora da thread.** O projeto vai serializado ao worker; o worker devolve resultados e as
  entidades redimensionadas; um contador de edições descarta resultados de um projeto que mudou
  enquanto calculava.
- **Índice espacial.** R-tree empacotada por STR reconstruída a cada edição; a pintura consulta só a
  janela visível e seleção, snap e janela de seleção consultam o índice (consulta em microssegundos
  com dezenas de milhares de entidades).
- **Desenho na tela.** A prancheta guarda o desenho entre um quadro e outro (`SceneCache`): ele só é
  gravado de novo quando muda algo que ele mostra (uma edição, a seleção, a vista, o mapa base, os
  resultados), de modo que mover o cursor repinta só o marcador de snap, a prévia da ferramenta e o
  item sob o cursor sobre uma imagem da cena. Uma cena demorada de desenhar acompanha o arrasto e o
  zoom como imagem deslocada e é redesenhada nítida quando a vista para. O painter agrupa as chamadas
  de desenho por estilo (algumas centenas de chamadas para dezenas de milhares de itens) e omite
  vértices a menos de um pixel; linhas de até um pixel físico são desenhadas como hairlines e as mais
  largas segmento a segmento (no navegador um traço largo é rasterizado na CPU), e uma vista lotada
  de linhas numa tela de alta densidade desenha as linhas de 1 px com um pixel físico. Só a barra de
  status escuta as coordenadas do cursor, então a janela não é reconstruída a cada movimento.
- **Formatos próprios em Dart puro.** Leitores e escritores de DWG, PDF (com as suas fontes e a
  formatação do texto), XLSX, SHP, GeoTIFF, LAS, IFC etc. não dependem de bibliotecas nativas, o que
  mantém o app 100 % web.
- **Textos centralizados.** Todas as strings da interface são chaves de `i18n.dart`, com os textos
  em português, inglês e espanhol compilados e os outros 17 idiomas nos pacotes de `assets/i18n`; o
  motor devolve códigos (`velocity_exceeded:e12`) que a interface traduz. Todo arquivo de teste
  falha quando a interface pede uma chave que a tabela não tem (`test/flutter_test_config.dart`),
  que de outro modo apareceria crua na tela.
- **A IA usa o programa, não uma cópia dele.** As ferramentas do assistente são invólucros finos
  sobre o controller e o motor, toda alteração passa por `mutate` (um grupo de desfazer por
  resposta), e um mapa de cobertura leva cada função que o usuário alcança a uma ferramenta, uma
  operação, um comando ou uma configuração. As duas empresas ficam atrás de uma só interface
  (`llm.dart`), com a conversão de formatos num só lugar (`llm_formats.dart`) e um só laço do
  agente; o código das requisições recebe a troca HTTP como parâmetro, então os testes o executam
  contra imitações programadas.

---

## 15. Desenvolvimento

Requisitos: Flutter estável recente (desenvolvido com 3.47, Dart 3.13). Sem dependências nativas.

```bash
git clone https://github.com/videjunior/opencadirrigation.git
cd opencadirrigation
flutter pub get
flutter run -d chrome              # desenvolvimento no navegador
flutter test                       # 1.752 testes: motor, modelo, formatos, interface
flutter analyze                    # lints
tool/build_worker.sh               # recompila web/design_worker.js após mudar lib/core (o app cai
                                   # para a thread da interface quando o arquivo não existe)
tool/build_web.sh                  # build de publicação: worker + flutter build web com o commit git e a data
                                   # gravados na versão (boas-vindas, barra de status, Ajuda → Sobre, console),
                                   # CanvasKit servido pelo site e o service worker da abertura sem rede
                                   # preenchido (tool/gen_sw.dart); OCI_WEB_OUT=<pasta> grava o build em outro lugar
flutter build web --release        # build simples (sem commit/data, CanvasKit da CDN do Google, sem abertura sem
                                   # rede: o sw.js dele remove a si mesmo; build/web, web/CNAME guarda o domínio)
dart run bin/oci.dart --help       # linha de comando: design, analyze, check, export, bom de projetos .oci.json
dart run tool/gen_version.dart     # regenera lib/app/version.dart após mudar `version:` no pubspec.yaml
dart run tool/gen_site.dart        # páginas do site (index em inglês, /pt/, /es/, /de/, … sitemap, 404, robots, llms.txt)
dart run tool/indexnow.dart        # depois de publicar: pede aos buscadores do IndexNow (Bing…) novo rastreio
dart run tool/gen_catalogs.dart    # valida e normaliza catalogs/*.oci.cat e refaz index.json
dart run tool/gen_examples.dart    # regenera examples/<lang>/*.oci.json a partir de lib/app/examples.dart
dart run tool/gen_brand.dart       # ícones e ativos de marca a partir de web/brand
python3 tool/formats/make_fixtures.py   # regrava test/fixtures/formats com ezdxf, pyshp, tifffile, Pillow, openpyxl e LibreDWG
python3 tool/formats/check_exports.py   # valida build/formats (escrito por flutter test) com leitores independentes
python3 tool/fonts/build_fonts.py       # refaz os subconjuntos Noto de assets/fonts a partir dos textos da interface
python3 tool/fonts/gen_unicode_data.py  # regenera lib/core/io/fonts/unicode_data.dart a partir do Unicode Character Database
python3 tool/fonts/make_shaping_fixtures.py  # regrava test/fixtures/shaping com o HarfBuzz (uharfbuzz)
UPDATE_AI_TOOLS_DOC=1 flutter test test/widget_ai_coverage_test.dart  # regenera docs/AI_TOOLS.md a partir do mapa de cobertura
```

A linha de comando roda o motor do app na VM do Dart, sem Flutter nem navegador: `design`
dimensiona e analisa um projeto (e grava o projeto dimensionado, os resultados e todas as tabelas
dos relatórios), `analyze` mantém os diâmetros como desenhados, `check` lista os problemas e
termina com código 1 quando há um erro, `export` grava qualquer formato de desenho e `bom` mostra a
lista de materiais, em qualquer um dos 20 idiomas (`--lang`).

Os geradores têm testes de guarda: quando um arquivo gerado diverge da fonte, o teste
correspondente falha com a instrução de qual comando rodar. Builds para desktop
(`flutter run -d macos|windows|linux`) usam o isolate para o cálculo. As pastas `android/` e `ios/`
são os modelos de projeto que o Flutter gerou; builds nativos para celular nunca foram compilados
nem testados, e celulares e tablets usam o app web (instalável como PWA).

### Como estender

- **Nova entidade**: classe em `entities.dart` (JSON, clone, transformar, grips, distância, bounds),
  `EntityType`, camada padrão, pintura em `painter.dart`, propriedades em `properties_panel.dart`,
  ferramenta em `tools.dart` e alias em `shortcuts.dart`, exportação em `plot.dart`/`cad_export.dart`.
- **Novo relatório**: tabela em `report_tables.dart` (os exportadores CSV/TXT/XLSX/PDF e o painel a
  recebem automaticamente) e textos em `i18n.dart`.
- **Novo formato**: leitor ou escritor em `lib/core/io`, entrada em `importFile` do controller ou em
  `DrawingFormat`/`ReportFormat`, e um teste de ida e volta.
- **Nova fórmula**: em `lib/core/hydraulics`, com um teste contra um valor de referência.
- **Nova ferramenta da IA**: uma ferramenta em `lib/app/ai/agent_tools*.dart` (enviada em todo
  pedido) ou uma operação em `lib/app/ai/ops_*.dart` (encontrada por `find_operations`), sobre o
  controller, com o seu esquema de entrada e o seu efeito (leitura, alteração, exportação ou
  consulta a outro serviço), e a sua rota em `lib/app/ai/ai_coverage.dart`.
  `test/widget_ai_tools_test.dart` confere nomes e esquemas, `test/widget_ai_coverage_test.dart`
  falha quando um comando, ferramenta, item de menu ou diálogo não tem rota, e
  `test/widget_ai_manual_test.dart` quando o manual não traz uma chave de item, um parâmetro de
  projeto ou um código de mensagem.
- **Cores da interface**: tire-as de `Cad.*` (`lib/app/theme.dart`), acrescentando uma cor às duas
  paletas quando nenhuma servir; `test/widget_theme_test.dart` confere o contraste das cores de
  texto claras (4,5:1 sobre cada superfície clara).

---

## 16. Testes

`flutter test` roda 1.752 testes em alguns minutos. O que cada grupo garante:

| Arquivo | Cobertura |
|---|---|
| `core/hydraulics_test.dart` | Hazen-Williams contra valor de livro-texto; Darcy-Weisbach ≈ Hazen-Williams em PVC liso; fator laminar; Swamee-Jain ≈ Colebrook; continuidade na transição; tabela do fator F de Christiansen e ajuste de Scaloppi; diâmetro equivalente; lei do emissor e ajuste; taxa de aplicação; CU de sobreposição; CU/DU e a EU de Keller-Karmeli (o exemplo resolvido do estudo técnico); ajuste de curva de bomba, ponto de operação, CRF; K → forma de vazão; celeridade em PVC; números sem notação científica |
| `core/network_test.dart` | Solver esparso; tubo simples; anéis; conservação de massa; emissores dependentes da pressão; bomba; PRV; curva de acessório; convergência em Darcy-Weisbach; rede ramificada grande rápida; comparação com Christiansen; laterais em declive; comprimento máximo; posições de alimentação; emissores acima da carga disponível ficam fechados (sem refluxo) |
| `core/network_robustness_test.dart` | Bomba perto do shutoff alimentando cem emissores perto de pressão zero (contra uma bisseção independente); bomba que um passo ruim travava fechada; emissores autocompensantes num morro, secos acima da linha piezométrica e famintos abaixo dela; válvula redutora logo acima do ajuste continua aberta; retenção instalada como acessório impede fluxo reverso; 300 redes em árvore aleatórias (bombas, retenções, demandas, todo expoente de emissor) convergem para soluções que satisfazem continuidade e leis de perda de carga; uma linha parada atrás de uma bomba desligada |
| `core/valves_formulas_test.dart`, `core/pressure_class_test.dart`, `core/minor_fittings_test.dart`, `core/mains_frequency_test.dart` | Leis de Scobey e Manning no solver; a válvula sustentadora mantém o ajuste a montante e a controladora a sua vazão, limitadores de vazão de hidrantes num projeto; bomba com inversor mantém a pressão de saída turno a turno, com curvas de NPSH e de rendimento; redução da classe do PVC e do PE com a temperatura e a classe como restrição do dimensionamento (uma fonte de 95 m nunca recebe PVC PN 80, água quente reprova um tubo que passa a 20 °C); as perdas das conexões desenhadas; bomba de 60 Hz numa rede de 50 Hz e a seleção de bombas na rotação da rede |
| `core/invariance_test.dart` | Mover o projeto (inclusive para coordenadas UTM), desenhar os tubos no sentido contrário, salvar e reabrir ou trocar o idioma deixam o projeto igual; o terreno por inverso da distância conta cada cota uma vez |
| `core/regressions_1017_test.dart` | Defeitos corrigidos na varredura de 2026-10-17: curvas de bomba e de acessório digitadas com vazões repetidas, bomba só com carga de shutoff, posições de alimentação de laterais que pedem mais de três vezes a pressão nominal |
| `core/lp_test.dart` | Simplex: ≤/≥, igualdades, inviável, ilimitado, problema com a forma do dimensionamento |
| `core/design_test.dart`, `core/sizing_features_test.dart`, `core/gaps_test.dart` | Gerador de blocos; grafo conectado; análise e dimensionamento completos; LP não pior que o guloso; telescopagem; conexões; lavagem; golpe de aríete; CU de sobreposição e emissores por planta; agronomia e programa do controlador; seleção de bomba e motor; DEM GeoTIFF; pivô (vãos, custos); linha principal em anel |
| `core/transient_test.dart`, `core/transient_analysis_test.dart`, `core/air_valves_test.dart`, `core/eps_test.dart` | Método das características: o regime permanente não se move sem um evento, sobrepressão de Joukowsky e o período 4L/a, sobrepressão de Michaud numa parada lenta, amortecimento pelo atrito, separação de coluna, ventosa combinada, desligamento de bomba com retenção, inércia e reservatório hidropneumático, tubos fundidos e agrupados; a linha principal de cada exemplo roda todos os cenários com o regime permanente dentro das envoltórias; posicionamento de ventosas pela prática do AWWA M51 e dimensionamento dos orifícios; período estendido com reservatórios, horários, padrões e controles, e a energia, contra curvas analíticas e cálculos à mão |
| `core/terrain_pivot_test.dart`, `core/breakline_test.dart`, `core/slope_map_test.dart` | TIN de Delaunay exato em planos; TIN vs IDW; geração de curvas; encadeamento de segmentos; geometria de alinhamento e recorte; blocos guiados; hidráulica de pivô (inclusive setorial); verificação de projeto; catálogo Excel e pacotes; linhas de quebra forçadas na triangulação; mapas de declividade e exposição |
| `core/advisor_test.dart` | Itens soltos ligados (a válvula volta ao início da zona), configurações impossíveis restauradas, pressão do emissor fora da faixa do bocal, zonas fora dos turnos, bomba de superfície em poço fundo → submersa, booster para rede pública sem pressão, turnos divididos pela vazão da fonte, corrigir automaticamente num projeto com vários erros, otimização que nunca aumenta o custo anual |
| `widget_advice_test.dart` | A aba Mensagens explica e corrige com um clique (um passo de desfazer), cálculo com erros abre Mensagens, corrigir automaticamente num passo do histórico, otimização e itens de menu, fonte ausente com correção de um clique |
| `core/auto_layout_test.dart`, `core/zoning_test.dart`, `core/routing_test.dart`, `core/templates_test.dart`, `core/field_subdivision_test.dart`, `core/tree_rings_test.dart`, `core/pivot_fit_test.dart`, `core/auto_design_test.dart`, `core/vegetation_test.dart` | Layouts de retângulos, formas em L, canteiros curvos e gramados em volta de uma casa com o seu CU, setores com bocais equivalentes; zonas dentro da vazão que nunca misturam classes de precipitação; árvores de tubos de zona e da linha principal contornando edificações; modelos de campo, pista, green, tee e fairway; blocos de mesma área com carreadores; anéis ligados às suas laterais; o maior círculo e o melhor setor de um talhão; gramados, talhões e pomares distribuídos, zoneados e com traçado que projetam sem erros; a vegetação de uma cena aérea sintética (gramados, copas, sombra, piscina, piso) com erro de poucos por cento; cada um bem abaixo de um segundo com milhares de aspersores |
| `core/climate_test.dart`, `core/climate_online_test.dart`, `core/crops_test.dart`, `core/soils_test.dart`, `core/effective_rain_test.dart`, `core/irrigation_requirement_test.dart`, `core/solar_pumping_test.dart`, `core/wetted_bulb_test.dart`, `core/water_budget_test.dart` | Exemplos resolvidos da FAO-56 (pressão, pressão de vapor, radiação, ETo em Bangkok, Uccle e Lyon), curvas de Kc, Anexo 7 e cobertura esparsa; lixiviação da FAO-29 e os citros gotejados do Módulo 9 da FAO; chuva efetiva do NEH 623 e as fórmulas da FAO; a tabela de solos contra o NEH 652, Rawls et al., a Tabela 19 da FAO-56 e a tabela SWAT/EPA; geometria solar contra Duffie & Beckman e o Exemplo 8 da FAO-56; Schwartzman & Zur; orçamentos MWELO e ciclo e infiltração; pedidos, leitura, ritmo, novas tentativas e normais do Open-Meteo e da NASA POWER |
| `core/mechanised_test.dart`, `core/pivot_package_test.dart`, `core/corner_arm_test.dart`, `core/vri_test.dart`, `core/pivot_electrical_test.dart`, `core/traveller_test.dart`, `core/surface_irrigation_test.dart`, `core/gated_pipe_test.dart` | Cálculo exemplo 11-18 do NEH 623 (capacidade do sistema, vazão por saída, canhão final, atrito, volta e booster), pacotes regulados com bocais numerados ou do catálogo, temporizador pela transmissão; braço de canto contra casos analíticos; taxa variável por setores e zonas; motores das torres e queda no cabo pela IEC 60364-5-52, tamanho do gerador; cálculo exemplo 11-17 do autopropelido; os exemplos de sulco, faixa e bacia da FAO 45; saídas do tubo janelado |
| `core/network_ops_test.dart`, `core/on_demand_test.dart`, `core/tariff_test.dart`, `core/energy_grouping_test.dart`, `core/criticality_test.dart`, `core/calibration_test.dart`, `core/fertigation_test.dart` | Vazões de Clément contra o Box 1 da FAO 59 e a verificação por configurações aleatórias (quantis AS 241, sequência de referência do MRG32k3a); a regra brasileira do desconto e o agendador exato contra força bruta; agrupamento por energia 30 % abaixo do primeiro encaixe por vazão; N−1 em árvores e anéis; seção áurea e Levenberg–Marquardt recuperando o C; tempos de chegada, plano e venturi da fertirrigação; tudo sobre um projeto calculado |
| `core/valve_in_head_test.dart`, `core/two_wire_test.dart`, `core/wire_routing_test.dart`, `core/round_1025_test.dart`, `widget_valve_in_head_test.dart` | Estações de aspersores com válvula programadas pelos turnos (pressões, 24 horas, fiação, dois fios, EPANET, altura estática da bomba, programa do controlador, transientes, fertirrigação) e os resultados de projetos que nunca as programaram; tensão no par de dois fios à mão, decodificadores e aterramento; rotas pelas valas (menores caminhos, árvore do tipo Steiner), válvulas mestras e relés de bomba; válvula mestra e acessórios na lista de materiais, armazenamento comprimido no navegador, um dispositivo em cada lateral selecionada, links de compartilhamento, comentários e nuvens de revisão, curvas de bocal ajustadas por tabelas coladas |
| `core/dwg_test.dart`, `core/dwg_writer_test.dart`, `core/cad_export_test.dart` | Leitura de amostras R2000–R2018 e R2007, com blocos e cotas expandidos; rejeição de versões desconhecidas; CRC; ida e volta do escritor; validação com LibreDWG quando instalado; DXF e DWG R2000 com entidades nativas, blocos das cotas, camadas com cores verdadeiras e tipos de linha, definições de atributo e blocos do usuário, para cada exemplo da galeria, relidos iguais |
| `core/formats_test.dart`, `core/formats_app_test.dart` | Cada formato de importação contra arquivos gravados por outros programas (ezdxf, LibreDWG, pyshp, tifffile, Pillow, openpyxl e KML no estilo do Google Earth; fixtures em `test/fixtures/formats`, gerados por `tool/formats/make_fixtures.py`) com posições, elevações, nomes e camadas conferidos; todas as exportações relidas pelos próprios leitores e gravadas em `build/formats` para `tool/formats/check_exports.py`, que as valida com ezdxf, LibreDWG, lxml, openpyxl e pypdf; os formatos novos pelo app (GeoJSON, GPX, LAS, DGN, EPANET, zips de shapefiles) |
| `core/epanet_inp_test.dart`, `core/shp_writer_test.dart`, `core/gpx_test.dart`, `core/landxml_test.dart`, `core/ifc_test.dart`, `core/geojson_reader_test.dart`, `core/las_test.dart`, `core/dgn_test.dart`, `core/datum_test.dart` | Arquivos EPANET de projetos calculados batendo com a nossa análise zona a zona e turno a turno, e o leitor; shapefiles, GPX, LandXML e IFC pelas suas especificações e relidos; GeoJSON com todas as geometrias e o `crs`; formatos 0–10 do LAS, rarefação e recusas; DGN V7 2D e 3D; Mercator transversa, as translações de datum do IBGE e o reconhecimento de sistemas |
| `core/pdf_reader_test.dart`, `core/pdf_import_test.dart`, `core/pdf_fonts_test.dart`, `core/pdf_images_test.dart`, `core/text_shaping_test.dart`, `core/sheets_test.dart`, `widget_sheets_test.dart` | O leitor de PDF nos nossos arquivos e em estruturas de arquivo, filtros, cores, textos, imagens e camadas de outros programas, plantas importadas em escala; leitura e subconjunto de TrueType, ordem bidirecional, fontes embutidas em todas as escritas da interface; formatação idêntica à do HarfBuzz nos textos da interface (fixtures por `tool/fonts/make_shaping_fixtures.py`); imagens no PDF e no SVG; conjuntos de folhas, detalhes, gráficos e a tabela de revisões; PNG de uma prancha |
| `core/export_test.dart`, `core/kml_test.dart` | UTM ida e volta; georreferência; KML ida e volta; GeoJSON; cena de plotagem; SVG; PDF válido e comprimido; prancha e páginas de relatório; mesmas tabelas em CSV/TXT/XLSX |
| `core/catalog_packs_test.dart` | Todos os pacotes em `catalogs/` carregam, ids únicos sem colidir com o catálogo padrão, arquivos normalizados e índice coerente; formato do pacote; carregadores (assets e URL) |
| `core/examples_test.dart` | Cada exemplo, nos 20 idiomas, constrói, é conectado, passa na verificação, projeta com zonas dentro da janela e sem déficit, imprime cada célula de relatório como número simples e bate com os arquivos em `examples/` |
| `core/spatial_index_test.dart` | Índice contra força bruta, ordem de desenho, casos degenerados, invalidação no controller, seleção e snap, entidades por id e contagem por camada |
| `core/painter_test.dart`, `core/scene_cache_test.dart` | Sobreposições de resultados (os mesmos pontos dos emissores em toda sobreposição, recoloridos pela pressão), entidades de desenho, textos sobre as linhas, a cor do item sob o cursor, hairlines numa vista lotada de linhas em tela 2×; uma gravação por cena, cena pesada deslocada com a vista e redesenhada nítida quando ela para |
| `core/geo_parse_test.dart`, `core/i18n_lang_test.dart` | Coordenadas coladas (decimais, vírgula, hemisférios, DMS, links); intervalo de curvas; escolha de idioma pelo sistema e pela URL |
| `core/i18n_packs_test.dart` | Cada pacote de idioma cobre todas as chaves da tabela, do tutorial e dos nomes do catálogo com os mesmos marcadores e não é majoritariamente inglês; pacotes instalados chegam aos textos, ao tutorial e ao catálogo; `setLanguage` carrega o pacote sob demanda com inglês enquanto isso e repete um carregamento que falhou |
| `core/editing_test.dart`, `core/model_test.dart`, `core/workspace_test.dart`, `core/design_job_test.dart`, `core/app_io_test.dart`, `core/entities_roundtrip_test.dart` | Edição (grips, transformações, aparar, estender, cortar), JSON das entidades, abas e área de transferência, protocolo do worker, HTTP local, armazenamento de projetos, câmera e snap (a área de transferência leva os itens de catálogo dos pivôs e a fiação) |
| `core/blocks_test.dart`, `core/label_rules_test.dart`, `core/snapping_extra_test.dart`, `core/gps_test.dart`, `core/auto_analysis_test.dart`, `core/selection_bom_test.dart`, `core/proposal_test.dart`, `core/finame_test.dart`, `core/licensing_test.dart`, `core/works_schedule_test.dart`, `core/limits_test.dart` | Blocos do usuário no arquivo e no histórico; rótulos condicionais; snaps de interseção, perpendicular, tangente, quadrante e extensão e o rastreamento polar, também em curvas de nível longas que se cruzam junto ao cursor; trajetos, marcas e locação pelo GPS; análise automática depois das edições; materiais da seleção; o orçamento (da margem ao frete, valas, retorno, VPL e TIR, setores, alternativas); códigos FINAME; categorias do CONAMA; cronograma de obra; os limites que o app informa ao usuário (BigTIFF, o teto de pixels, a rarefação do TIN, um PDF solto sem o diálogo) |
| `core/cli_test.dart`, `core/api_examples_test.dart` | `test/core/cli_test.dart` executa a linha de comando num exemplo distribuído; `test/core/api_examples_test.dart` executa cada trecho de docs/API.md e falha quando os documentos mostram código que ele não executa |
| `core/ai_agent_test.dart`, `core/ai_openai_test.dart`, `core/ai_formats_test.dart`, `core/ai_context_test.dart` | Os pedidos seguem cada API: Anthropic (endpoint, cabeçalhos, streaming, raciocínio adaptativo, sempre ligado no Fable 5.1, esforço, cache, fallback de recusa, orçamento da tarefa, compactação, limpeza de resultados antigos de ferramentas; sem o cabeçalho de navegador no desktop) e OpenAI (API Responses, chave bearer, instruções, ferramentas de função, esforço de raciocínio, sem armazenamento, compactação, imagens mais antigas retiradas); rodadas de ferramentas, entradas inválidas como resultados de erro, os quatro modos e a aprovação do plano, exportações confirmadas, o limite de etapas e o teto de gasto, mensagens escritas enquanto ele trabalha, Parar, novas tentativas e erros que nunca mostram uma chave, a recusa do Fable 5.1 por retenção de dados, recusas e fallbacks cobrados pelo modelo que respondeu, preços de tabela com as regras de pedidos longos; os dois formatos se convertem um no outro sem perda; o contexto do projeto é determinístico, limitado e nunca contém uma chave |
| `widget_ai_agent_test.dart`, `widget_ai_assistant_test.dart`, `widget_ai_tools_test.dart`, `widget_ai_vision_test.dart` | GPT com a chave da OpenAI, conversa nova quando a empresa muda e nenhuma chave chegando à outra empresa, um modelo Claude assumindo a conversa de outro; um projeto pequeno inteiro feito pelo agente (perguntas, plano, desenho, cálculo, verificação, correções, memorial, lista de tarefas); mensagens escritas enquanto ele trabalha, voltar a um ponto, o teto de gasto e Continuar, comandos rápidos, avisos de compactação, imagens, a conversa em Markdown, o painel encaixado, o seu botão e a folha do celular; chaves na memória a menos que sejam lembradas, nada enviado antes de Enviar, fichas técnicas conferidas antes de entrar no catálogo; a correspondência entre pixel e mundo, a imagem de satélite tirada fora da tela sem mudar a vista nem o mapa do usuário, imagens do Google com chave, geometria proposta, imagens e perfis do terreno contra valores exatos |
| `widget_ai_coverage_test.dart`, `widget_ai_manual_test.dart`, `widget_ai_ops_cad_test.dart`, `widget_ai_ops_eng_test.dart` | Toda ação, ferramenta, alias, item de menu e diálogo tem rota para a IA e toda rota existe, e `docs/AI_TOOLS.md` é a tabela do mapa; cada tópico do manual é lido num projeto vazio e num calculado, cada chave de item, parâmetro de projeto e código de mensagem tem a sua explicação, e o exemplo resolvido é refeito; as operações do lado do desenho e da engenharia (edição, anotação, blocos, vista e histórico, arquivos, terreno e local, importações; calculadoras, análises da rede, catálogo e pacotes, exportações, projeto automático), cada uma com as suas aprovações e passos de desfazer. Imitações programadas das duas APIs (`test/support/fake_claude.dart`, `test/support/fake_openai.dart`) fazem o papel das empresas: nenhum teste acessa a rede |
| `densogram_test.dart`, `electrical_test.dart`, `electrical_io_test.dart`, `management_test.dart` (em `core/`) | Todo perfil de aspersão devolve a vazão inteira, setores, áreas contra a própria média, perfis medidos e vento; rotas, estações, tensão no solenoide à mão, fios mais baratos contra força bruta, catálogo de fios, lista de materiais e relatório Elétrico, códigos da verificação, saída DXF/DWG/GeoJSON e prancha; demandas e turnos automáticos com pivôs e estações |
| `core/import_curves_test.dart` | NURBS racional e fixada; SPLINE do DXF por pontos de controle ou de ajuste, HATCH com bordas de polilinha, linha, arco (nos dois sentidos), elipse e spline e ilhas, SOLID/TRACE, hachuras dentro de blocos; splines, hachuras, sólidos e a elipse do DWG R2000–R2018 iguais aos lidos pelo LibreDWG |
| `core/controller_extra_test.dart` | Abrir arquivo ou exemplo descarta marcas, perfil, verificação e histórico antigos; edições de diálogo como um passo de desfazer (mutações incorporadas, unidades mantêm os resultados); desfazer sem nada a desfazer; grips arrastam fios com os nós de tubo; pintura das novas entidades e do densograma |
| `core/regressions_test.dart` | Cada defeito corrigido na varredura de 2026-09-22, cada um falhando sem a sua correção: lateral cortada sobre um emissor o mantém uma vez só; curvas geradas continuam geradas; arquivos sem o contador de ids; aspersores de setor espelhados e cabeças de 360° com bocal de setor (também no PDF e na tela); arquivos de levantamento com espaço e vírgula decimal; imagens grandes demais para decodificar; arquivos danificados informados como tal; psi, kPa e bar; CU da grade com aspersores próximos; blocos em talhões em L e em U e fileiras guiadas recortadas em dois; telescopagem desenhada nos dois sentidos; números com separador de milhar, preços e curvas de bomba; espaçamentos 0 e valores NaN que travavam ou impediam salvar; trilhas de GPS no KML |
| `core/hotkeys_dispatch_test.dart` | O despachante de teclado isolado: teclas do aplicativo, de edição e do canvas, coordenadas digitadas, o que diálogos e menus bloqueiam, cada alias de comando digitado |
| `widget_*.dart` | Interface real: tela inicial e tutorial, galeria, menus e diálogos, painéis, edição no canvas, atalhos, histórico, terreno e layout compacto; gerenciamento com pivôs e turnos automáticos, diálogos fechados por fora, densograma, ferramentas de controlador e fio com a aba Elétrico, cotas de ordenada e de diâmetro, a aba Fios do catálogo, campos numéricos que rejeitam um valor; as propriedades de cada tipo de entidade, edição em lote e os resultados da seleção; a leitura do gráfico de perfil; navegação por roda, trackpad, botão do meio e dois dedos; diálogos de georreferência e de plotagem; menus da linha principal e do celular; o diálogo de turnos; os diálogos de projeto automático, agronomia, máquinas mecanizadas, operação da rede, transientes, importação de PDF, folhas e blocos e vegetação, cada um aplicando num passo de desfazer e cabendo num celular de 390 × 844; o layout da direita para a esquerda do árabe e do urdu, os rótulos condicionais, o indicador do GPS, a ferramenta de linha de quebra e os materiais da seleção |
| `widget_theme_test.dart` | A paleta escura é o visual original, cor por cor; a paleta clara mantém o contraste WCAG AA dos textos sobre as suas superfícies; Ver → Tema troca no lugar (mesma janela, projeto e seleção), também pelo menu do celular, e as folhas são montadas no tema claro; uma camada branca é desenhada quase preta no canvas claro enquanto as plotagens ficam iguais; a escolha é salva e aplicada na abertura; Seguir o sistema acompanha o brilho da plataforma ao vivo; as imagens para o assistente de IA mantêm o canvas escuro |
| `web_metadata_test.dart`, `version_test.dart`, `web_offline_test.dart` | Páginas do site geradas, SEO, JSON-LD, manifest, ícones, robots, sitemap, 404, llms.txt; as páginas de entrada carregam o app sob demanda; versão do app coerente com o pubspec.yaml, o gerador e o site; `test/web_offline_test.dart` cobre o gerador do service worker, os templates e o script de build |
| `flutter_test_config.dart` | Roda em volta de cada arquivo de teste: o arquivo falha quando a interface pediu uma chave de texto que a tabela não tem |

Armadilhas conhecidas ao escrever testes de widget: o cálculo é assíncrono de verdade e deve rodar
dentro de `tester.runAsync`; títulos de diálogo podem estar em maiúsculas; o canvas precisa de um
tamanho de janela definido; o carregamento de assets (catálogos) usa `rootBundle` e funciona em
`flutter test`.

---

## 17. Limitações conhecidas e roteiro

- **Redes malhadas**: o LP dimensiona malhas por caminhos em árvore (aproximação) e é resolvido de
  novo com as vazões dos novos diâmetros até eles se firmarem; a análise final confere, e o método
  guloso é a alternativa segura.
- **Solver de rede**: emissores autocompensantes em redes grosseiramente subdimensionadas (vazões
  muitas vezes maiores do que os tubos comportam) ainda podem não convergir; o projeto então
  informa `not_converged` em vez de números.
- **Transientes**: a análise cobre a linha principal de cada turno, com as zonas vistas dela como
  orifícios nas suas válvulas; o atrito é quase-permanente (um fator constante por tubo);
  reservatórios hidropneumáticos são modelados pelo motor, mas ainda não podem ser colocados num
  projeto.
- **Simulação de 24 horas**: um projeto não tem reservatório cujo nível varie ao longo do dia (as
  fontes mantêm o nível); reservatórios, padrões e controles por nível existem na simulação de
  período estendido do motor ([docs/API.pt-BR.md](docs/API.pt-BR.md)).
- **Elétrica**: o cálculo liga as válvulas da forma convencional (um fio de estação por válvula e um
  comum compartilhado) com solenoides de 24 V CA; o dimensionamento de dois fios (decodificadores)
  das Rotas automáticas de fios é uma análise à parte, cujos decodificadores e cabo não entram na
  lista de materiais.
- **DWG e DXF**: o leitor cobre as entidades típicas de uma planta (linhas, polilinhas, círculos,
  arcos, elipses, splines, hachuras, sólidos, chamadas, pontos, textos, blocos e cotas), com R13/R14
  lidos em parte; os escritores gravam só R2000 (DWG com índices de cor; cores verdadeiras no
  DXF), e as imagens saem como a sua moldura, sem o raster.
- **Plantas em PDF**: degradês, preenchimentos com padrão (desenhados em cinza), grupos de
  transparência, anotações e glifos Type 3 não são interpretados; o recorte é aproximado por
  retângulos; áreas preenchidas entram como contornos; arquivos criptografados e imagens JPEG 2000
  ou JBIG2 ficam de fora; o trabalho por página tem um teto, e uma página truncada avisa.
- **Outros arquivos**: nuvens LAZ comprimidas, DGN V8 e BigTIFF são recusados pelo nome; rasters
  acima de 100 milhões de pixels são recusados; um terreno acima de 12 000 amostras é triangulado a
  partir de um subconjunto uniforme.
- **Datums**: SAD 69 e Córrego Alegre são deslocados por translações de três parâmetros (precisão
  de alguns metros); não se aplica uma transformação por grade.
- **Densograma**: um único perfil de aspersão para todas as cabeças sem perfil medido (escolhido no
  diálogo: sprays ficam mais perto do uniforme, aspersores de impacto de bocal único do
  triangular); o vento é um deslocamento de primeira ordem do padrão sem vento, que não substitui
  medições em dia de vento.
- **Agronomia e modelos de campo**: os valores de solo são os típicos da classe textural; a fórmula
  do bulbo molhado vem de dois solos e dois gotejadores e extrapola fora deles; o braço de canto
  supõe terreno plano, braço rígido e caminho guia convexo; a irrigação por superfície usa o
  balanço de volume, não um modelo hidrodinâmico.
- **Detecção de vegetação**: processamento simples das cores e da textura de uma imagem: gramados
  secos, sombra forte ou telhados verdes podem ser mal interpretados, então os contornos precisam
  de conferência; valem os termos de uso das imagens.
- **Cópia automática no navegador**: cerca de 3,5 MB por projeto depois da compressão; projetos
  maiores ficam só no arquivo (o app avisa uma vez).
- **Colaboração**: não há edição simultânea; projetos são compartilhados pelo arquivo `.oci.json`
  ou por um link, que deixa de fora imagens e resultados e é recusado quando o projeto é grande
  demais.
- **Desempenho**: projetos com centenas de fitas por zona levam alguns segundos por zona; a etapa de
  lavagem é a mais pesada.
- **Abertura sem rede**: testada em navegadores baseados no Chromium; mapas base, elevação e clima
  online, catálogos por URL e o assistente de IA precisam da rede.
- **Celular nativo**: as pastas `android/` e `ios/` são os modelos do Flutter e não são compiladas
  nem testadas; celulares e tablets usam o app web.
- **Assistente de IA**: precisa da rede e de uma conta com crédito na API da Anthropic ou da OpenAI
  (o Claude Fable 5.1 também de retenção de dados de 30 dias); no navegador uma chave da OpenAI
  recusada aparece como falha de rede, porque as respostas de erro da OpenAI não trazem cabeçalho
  CORS; as imagens não pedem aprovação, embora baixem tiles do mapa base; posições lidas de imagens
  são aproximadas; as análises que ele roda (transientes, simulação de 24 horas e afins) rodam na
  thread da interface; as conversas não são salvas (de propósito). Ele foi testado contra
  imitações programadas das duas APIs, não contra os serviços reais. As respostas podem conter
  erros, como as de qualquer modelo: as alterações passam pela aprovação, pelo desfazer e pelo
  voltar a um ponto da seção 9, e o projeto deve ser conferido.

Roteiro sugerido: sistemas de dois fios na lista de materiais do cálculo; reservatórios
hidropneumáticos e de armazenamento colocados num projeto; catálogos adicionais da comunidade;
testes de navegador da abertura sem rede no Firefox e no Safari; testes de navegador automatizados
para a troca de idioma em tempo de execução.

---

## 18. Contribuindo

- **Issues e pull requests** são bem-vindos no
  [GitHub](https://github.com/videjunior/opencadirrigation). Antes de um pull request rode
  `flutter analyze` e `flutter test`; recompile `web/design_worker.js` com `tool/build_worker.sh`
  depois de mudar `lib/core` ou `i18n.dart`, e rode o gerador que um teste de guarda apontar.
  As contribuições são aceitas sob a licença MIT do projeto.
- **Catálogos**: siga [catalogs/README.md](catalogs/README.md), rode `dart run tool/gen_catalogs.dart`
  e abra um pull request; os testes garantem ids únicos e curvas plausíveis.
- **Exemplos**: adicione um construtor em `lib/app/examples.dart`, textos em `i18n.dart` e rode
  `dart run tool/gen_examples.dart`; o teste projeta o exemplo e exige zonas dentro da janela.
- **Traduções**: cada chave de `i18n.dart` é uma tupla (pt, en, es), e cada outro idioma é um pacote
  em `assets/i18n/<código>.json` (strings, tutorial e nomes do catálogo; os testes falham com chave ou
  placeholder faltando); as páginas do site ficam em `tool/site.dart` e `tool/site/<código>.dart`.
  Um texto com caracteres que as fontes do PDF ainda não cobrem pede `tool/fonts/build_fonts.py`.
  A documentação é mantida em inglês (`README.md`, `docs/TECHNICAL_STUDY.md`, `docs/API.md`) e
  traduzida para o português (`README.pt-BR.md`, `docs/PESQUISA.pt-BR.md`, `docs/API.pt-BR.md`):
  altere primeiro a versão em inglês. Os trechos dos documentos da API são executados por
  `test/core/api_examples_test.dart`.
- **Motor**: toda fórmula nova vem com um teste contra um valor de referência publicado.
- **Interface**: as cores vêm de `Cad.*` (`lib/app/theme.dart`), que mudam com o tema: leia-as em
  `build` e `paint`, nunca em expressões `const` nem em campos que sobrevivam a uma reconstrução.
  Um comando, ferramenta, item de menu ou diálogo novo precisa da sua rota para o assistente de IA
  em `lib/app/ai/ai_coverage.dart` (o teste de cobertura diz qual falta).
- **Regra editorial**: produtos concorrentes de projeto de irrigação e as empresas que os fazem nunca
  são citados, em nenhum lugar do repositório (código, comentários, textos, testes, documentação e
  mensagens de commit), nem os produtos de CAD: um formato de arquivo é chamado pelo nome do formato
  (DXF, DWG R2000). Fabricantes de componentes aparecem apenas como origem dos dados de catálogo; o
  EPANET pode ser citado como referência de algoritmo; os provedores de dados e mapas (OpenStreetMap,
  Esri, Open-Meteo…) e de IA (Anthropic, OpenAI) aparecem como fontes e créditos; outros programas
  (planilhas, SIG, globos virtuais, navegadores) só como destino de um formato de arquivo.
  `test/editorial_names_test.dart` confere os nomes proibidos pelo SHA-256, sem citar nenhum.

---

## 19. Referências

O estudo que orientou o projeto, com o que um projetista espera de um CAD de irrigação, as fórmulas
do motor, as formulações de dimensionamento, agronomia, pivôs, terreno, os formatos de arquivo e a
bibliografia, está em [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md) (original em inglês em
[docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md)). Os módulos acrescentados depois dele citam as
suas fontes nos comentários de documentação, com os números de equações e tabelas que usam:

| Tema | Fontes |
|---|---|
| Transientes | Wylie, E. B.; Streeter, V. L. (1993), *Fluid Transients in Systems*; Chaudhry, M. H. (2014), *Applied Hydraulic Transients*; Thorley, A. R. D.; Faithfull, E. M. (1992), *Inertias of pumps and their driving motors* (também Thorley 2004, *Fluid Transients in Pipeline Systems*); Bergant, A.; Simpson, A. R.; Tijsseling, A. S. (2006), "Water hammer with column separation: a historical review", *Journal of Fluids and Structures* 22(2) (modelo de cavidade de vapor) |
| Ventosas | Manual AWWA M51, *Air-Release, Air/Vacuum, and Combination Air Valves* |
| Período estendido, arquivos EPANET | Rossman, L. A. (2000), *EPANET 2 Users Manual*, e os algoritmos de análise do EPANET 2.2; EPANET 2.2 Users Manual, EPA/600/R-20/133 (formato do arquivo de entrada) |
| Dimensionamento e tubos | Alperovits, E.; Shamir, U. (1977), *Water Resources Research* 13(6) (redes malhadas); Scobey (1930), segundo Keller & Bliesner (1990); Chow (1959) (n de Manning); ISO 1452-2 e ISO 4427-1 anexo A, NBR 14312 (redução da classe de pressão com a temperatura); ANSI/HI 9.6.1 (margem de NPSH) |
| Redes sob demanda | Clément, R. (1966), "Calcul des débits dans les réseaux d'irrigation fonctionnant à la demande", *La Houille Blanche* 5; Lamaddalena, N.; Sagardoy, J. A. (2000), *Performance analysis of on-demand pressurized irrigation systems*, FAO Irrigation and Drainage Paper 59; Wichura (1988), AS 241; L'Ecuyer (1999), MRG32k3a |
| Criticidade, calibração | Wagner, J. M.; Shamir, U.; Marks, D. H. (1988), *J. Water Resources Planning and Management* 114(3); Kiefer (1953); Levenberg (1944); Marquardt (1963) |
| Energia e tarifas | Jiménez-Bello, M. A. et al. (2010), *Biosystems Engineering* 105(4); Carrillo Cobo, M. T. et al. (2011), *Irrigation Science* 29; Resolução Normativa ANEEL nº 1.000/2021, art. 186; Portaria Normativa MME nº 137, de 8 de junho de 2026 |
| Traçado e fiação | Alpert, C. J. et al. (1995), *IEEE Trans. Computer-Aided Design* 14(7); Takahashi, H.; Matsuyama, A. (1980), *Math. Japonica* 24; Dijkstra (1959) |
| Agronomia | Allen, R. G.; Pereira, L. S.; Raes, D.; Smith, M. (1998), FAO Irrigation and Drainage Paper 56; Ayers, R. S.; Westcot, D. W. (1985), FAO-29 Rev. 1; Smith (1992), FAO-46; Brouwer & Heibloem (1986), FAO Training Manual 3; Savva & Frenken (2002), FAO Irrigation Manual Module 9; USDA-SCS (1970) TR-21 e NRCS NEH Part 623 cap. 2; Keller & Bliesner (1990); Keller, J.; Karmeli, D. (1974); Rawls, Brakensiek & Saxton (1982), *Trans. ASAE* 25(5); NRCS NEH Part 652 (1997); USDA-SCS NEH Section 15 cap. 11 (1983); protocolo SWAT da Irrigation Association (2008) e US EPA WaterSense (2011); Schwartzman & Zur (1986), *J. Irrig. Drain. Eng.* 112(3); MWELO da Califórnia (CCR Title 23, §§ 490–495, 2015); Burt, O'Connor & Ruehr (1995), *Fertigation* |
| Bombeamento solar | IEC 62253:2011; IEC 61724-1; Duffie & Beckman, *Solar Engineering of Thermal Processes* (Liu & Jordan; Erbs, Klein & Duffie 1982) |
| Irrigação mecanizada e por superfície | Heermann & Hein (1968); NRCS NEH Part 623 caps. 4 e 11; Kansas State University MF3608 (2022); Evans, R. G. et al. (2013), *Irrigation Science* 31; IEC 60364-5-52 anexo G, IEC 60228, IEEE Std 399 e 446; Walker & Skogerboe (1987) e Walker (1989), FAO-45; Elliott & Walker (1982); Strelkoff (1977); U.S. Bureau of Reclamation, *Water Measurement Manual* |
| Layout e gramados | Irrigation Association (2014), *Landscape Irrigation Best Management Practices*; Keller & Bliesner (1990); IFAB Regra 1, recomendações da World Athletics e da USGA para campos, pistas e greens; Garcia-Castellanos & Lombardo (2007), *Scottish Geographical Journal* 123; Seginer, Kantz & Nir (1991) (aspersores com vento) |
| Detecção de vegetação | Woebbecke et al. (1995) (excesso de verde); Otsu (1979); Meyer & Neto (2008); Gitelson et al. (2002); Taubin (1995); Douglas & Peucker (1973) |
| Terreno e coordenadas | Sloan (1993), *Computers & Structures* 47(3) (Delaunay restrito); ASPRS LAS 1.4 R15 (2019); LandXML 1.2 (2008); IBGE R.PR 1/2005 e R.PR 23/1989 (SIRGAS 2000, SAD 69, Córrego Alegre); OGC 01-009 (WKT 1), ISO 19162:2019 (WKT 2), EPSG; Karney (2011) |
| Formatos e detalhes | ISO 32000-1 (PDF); OpenType e Unicode (UAX #9, Character Database); RFC 7946 e a especificação GeoJSON de 2008; GPX 1.1; ISO 16739-1:2018 (IFC4) e ISO 10303-21; ESRI Shapefile Technical Description (1998); ISFF (DGN V7); ASAE S376.2 (recobrimento de tubulações termoplásticas enterradas de irrigação); Azevedo Netto, *Manual de Hidráulica* (submergência da sucção); Resolução CONAMA 284/2001 (categorias de licenciamento) |

---

## 20. Licença, componentes e dados de terceiros

O OpenCADIrrigation é distribuído sob a [licença MIT](LICENSE.md). É uma ferramenta de apoio à
engenharia: os resultados dependem dos dados informados e dos valores do catálogo, e um projetista
qualificado deve conferir o projeto antes da execução (a licença não dá garantia).

| Componente | Usado para | Licença |
|---|---|---|
| Flutter e o SDK do Dart | framework e linguagem | BSD-3-Clause |
| [`web`](https://pub.dev/packages/web) | APIs do navegador (arquivos, armazenamento, workers, geolocalização, requisições em streaming) | BSD-3-Clause |
| [`xml`](https://pub.dev/packages/xml) | KML, GPX, LandXML e XLSX | MIT |
| [`archive`](https://pub.dev/packages/archive) | KMZ, XLSX, shapefiles compactados, streams do PDF, links de compartilhamento e projetos guardados comprimidos | MIT |
| [`image`](https://pub.dev/packages/image) | imagens raster, imagens nos PDFs, detecção de vegetação e os arquivos da marca | MIT |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | fonte de ícones | MIT |
| CanvasKit (Skia) | renderização, servida pelo site junto com o app | BSD-3-Clause |
| Material Icons, Roboto, Noto | fontes da interface (Roboto servida com o app; Noto baixada sob demanda para outras escritas e guardada para uso sem rede) | Apache-2.0, SIL OFL 1.1 |
| Subconjuntos Noto Sans em `assets/fonts` (latino, Math, árabe, devanágari, bengali, gurmukhi, télugo, SC, JP) | texto dos PDFs em todas as escritas da interface | SIL OFL 1.1 ([assets/fonts/OFL.txt](assets/fonts/OFL.txt)) |

Os serviços online, acessados só quando você pede, têm seus próprios termos, e o app mostra os
créditos: mapas base (© colaboradores do OpenStreetMap sob a ODbL, OpenTopoMap sob CC-BY-SA, CARTO,
Esri, Google Maps com a sua chave, ou o servidor XYZ ou WMS que você configurar), elevação (Terrain
Tiles no AWS Open Data: SRTM/NASA, GMTED, ETOPO1; Open-Meteo sob CC BY 4.0 com o Copernicus DEM
GLO-90; OpenTopoData: NASA SRTM, ASTER GDEM), clima (API de histórico meteorológico do Open-Meteo
sob CC BY 4.0, reanálise ERA5 do Copernicus Climate Change Service, gratuita para uso não comercial;
NASA POWER, com o agradecimento que a NASA pede) e o assistente de IA (as APIs da Anthropic e da
OpenAI, usadas com a sua própria chave e conta sob os termos dessa empresa, que cobra o uso nessa
conta; as buscas do local por endereço usam o Nominatim do OpenStreetMap, © colaboradores do
OpenStreetMap sob a ODbL, dentro da sua política de uso; as imagens de satélite vêm do Esri World
Imagery ou, com a sua chave, do Google).

Os catálogos de fabricantes em [catalogs/](catalogs/) foram compilados das fichas técnicas públicas
dos fabricantes, e cada pacote cita sua fonte. Nomes de produtos e marcas pertencem aos seus donos;
o projeto não tem vínculo com nenhum deles, e os preços são valores de referência a confirmar com
um revendedor.
