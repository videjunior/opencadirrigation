<p align="center"><img src="web/brand/logo-horizontal.png" width="560" alt="OpenCADIrrigation"></p>

<p align="center"><a href="https://opencadirrigation.com/pt/">opencadirrigation.com/pt</a> · <a href="https://opencadirrigation.com">English</a> · <a href="https://opencadirrigation.com/es/">Español</a> · <a href="LICENSE.md">Licença MIT</a></p>

<p align="center"><a href="README.md">English</a> · <strong>Português</strong></p>

# OpenCADIrrigation

CAD de código aberto, escrito em Flutter/Dart, para projeto de sistemas de irrigação pressurizada: desenho, rede
hidráulica, dimensionamento de tubulações, relatórios e plotagem, direto no navegador, sem instalação, sem servidor e
sem cadastro, mais um assistente de IA opcional (Claude ou GPT, com a sua própria chave) que desenha e projeta com
você. Os projetos ficam no seu computador. Publicado sob a [licença MIT](LICENSE.md). Esta é a tradução do
[README em inglês](README.md), que é o canônico.

<p align="center"><img src="web/screenshots/design-1440x900.png" width="900" alt="Projeto de irrigação dimensionado com diâmetros, pressões e resultados por zona"></p>

## Comece em cinco minutos

1. Abra [opencadirrigation.com/pt](https://opencadirrigation.com/pt/) e clique em **Abrir o app** (ou abra um exemplo
   ou o tutorial direto da página). Ele roda no Chrome, Edge, Firefox e Safari, no computador, no tablet e no
   celular, e se instala como aplicativo que abre sem rede depois da primeira visita.
2. Diga onde fica a área (um endereço ou coordenadas) e se o projeto será feito com o assistente de IA, ou abra um
   exemplo pronto: Ajuda → Boas-vindas e galeria de exemplos, com o **tutorial interativo**.
3. Desenhe a área e a rede, ou deixe os geradores ou o assistente fazerem isso; pressione **F5** para projetar.
4. Leia os resultados no painel **Relatórios** (F2) e exporte pranchas em PDF, DXF, DWG, Excel e mais; salve o
   projeto com **Ctrl+S** (`.oci.json`).

Mais em [início em cinco minutos](docs/manual/pt-BR/getting-started.md).

## O que é

Um único aplicativo que cobre o ciclo completo de um projeto de irrigação pressurizada:

- **Agente de IA opcional**: o Claude (Anthropic) ou o GPT (OpenAI), com a sua própria chave de
  API, trabalha no projeto aberto com as ferramentas do próprio programa: responde perguntas,
  pergunta o que falta, planeja, desenha, projeta, verifica e escreve o memorial, com a sua
  aprovação e um desfazer para cada resposta ([Assistente de IA](docs/manual/pt-BR/ai-assistant.md)); nada é
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
- **Dimensionamento automático** de laterais, linhas de derivação e linha principal por programação linear
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

## Para quem

Projetistas de irrigação agrícola e paisagística, agrônomos, engenheiros, revendas, professores e
estudantes. O tutorial interativo e a galeria de exemplos permitem começar sem ler manual.

## Princípios

| Princípio | O que significa na prática |
|---|---|
| Aberto | Código, formato de projeto (`.oci.json`), catálogos (`.oci.cat`) e exemplos são arquivos legíveis, documentados neste repositório. |
| No navegador | Chrome, Edge, Firefox e Safari, em computador, tablet e celular; instalável como PWA, que abre sem rede depois da primeira visita. Também compila para desktop (macOS, Windows, Linux). Não há builds nativos para Android e iOS: no celular e no tablet use o app web. |
| Sem servidor | Não há servidor por trás do app nem cadastro. Projetos ficam no navegador e em arquivos locais. A internet é usada para o que você pede (mapas base, elevação e clima online, busca de endereços, catálogos por URL e o assistente de IA opcional, o único recurso que envia dados do projeto, para o provedor de IA que você escolher), para as fontes das escritas e dos símbolos que o app não traz (Google Fonts) e, nas páginas do site e só se você aceitar, para as estatísticas de visita; veja a [Armazenamento, privacidade e rede](docs/manual/pt-BR/privacy-and-network.md). |
| Motor transparente | Cada fórmula está documentada no código e no [estudo técnico](docs/PESQUISA.pt-BR.md), com testes que a comparam a valores de referência. |
| 20 idiomas | Interface em português, inglês, espanhol, chinês, hindi, árabe, francês, bengali, russo, urdu, indonésio, alemão, japonês, marati, vietnamita, télugo, hauçá, turco, panjabi e suaíli; o app abre no idioma do sistema, e em árabe e urdu a interface é da direita para a esquerda. |

## Manual

O manual está em [docs/manual/pt-BR/](docs/manual/pt-BR/README.md) (inglês, o canônico: [docs/manual/](docs/manual/README.md)):

- [Início em cinco minutos](docs/manual/pt-BR/getting-started.md): abrir o app, a galeria de exemplos, os parâmetros de endereço
- [Fluxo de projeto](docs/manual/pt-BR/workflow.md): da área aos relatórios, passo a passo
- [Interface](docs/manual/pt-BR/interface.md): layout, menus, layout compacto e atalhos de teclado
- [Desenho e edição](docs/manual/pt-BR/drawing.md): entidades, snaps, seleção, transformações, blocos, camadas
- [Rede hidráulica](docs/manual/pt-BR/hydraulic-network.md): itens hidráulicos, regras de conexão, geradores, projeto automático
- [Catálogo de componentes](docs/manual/pt-BR/catalogue.md): tubos, emissores, válvulas, bombas, preços e pacotes de fabricantes
- [Terreno](docs/manual/pt-BR/terrain.md): curvas de nível, cotas, modelo do terreno, elevação online
- [Cálculo e dimensionamento](docs/manual/pt-BR/calculation.md): parâmetros, etapas do cálculo, verificação e assistente de projeto, análises
- [Assistente de IA](docs/manual/pt-BR/ai-assistant.md): o que o assistente opcional faz, o que ele envia e como é controlado
- [Relatórios, plotagem e exportação](docs/manual/pt-BR/reports-and-export.md): painel de relatórios, pranchas em PDF, orçamento, exportações
- [Formatos de arquivo](docs/manual/pt-BR/file-formats.md): o arquivo de projeto e cada formato de importação e exportação
- [Armazenamento, privacidade e rede](docs/manual/pt-BR/privacy-and-network.md): o que fica no navegador, o que sai e para quem
- [Idiomas e site](docs/manual/pt-BR/languages-and-site.md): os 20 idiomas, o site, a abertura sem rede e a hospedagem
- [Arquitetura do código](docs/manual/pt-BR/architecture.md): a árvore de código e as decisões de projeto
- [Desenvolvimento e testes](docs/manual/pt-BR/development.md): comandos, como estender, o que cada teste garante
- [Limitações conhecidas e próximos passos](docs/manual/pt-BR/limitations.md): o que o app ainda não faz
- [Referências](docs/manual/pt-BR/references.md): normas, livros e artigos por trás do motor
- [Licença, componentes e dados de terceiros](docs/manual/pt-BR/licence.md): licença MIT, os componentes e as fontes de dados

O estudo técnico por trás do motor é o [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md) (inglês:
[docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md)); a API do motor é o [docs/API.pt-BR.md](docs/API.pt-BR.md)
([docs/API.md](docs/API.md)); o que o assistente de IA alcança está em [docs/AI_TOOLS.md](docs/AI_TOOLS.md).

## Contribuição, segurança e licença

- [CONTRIBUTING.md](CONTRIBUTING.md): como propor mudanças, catálogos, exemplos e traduções, a regra editorial e o
  checklist de lançamento; [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- [SECURITY.md](SECURITY.md): como relatar uma vulnerabilidade em particular.
- [CHANGELOG.pt-BR.md](CHANGELOG.pt-BR.md): o que mudou em cada versão; [CITATION.cff](CITATION.cff) para citá-lo.
- O app é uma ferramenta de apoio: um profissional habilitado confere e assina o projeto feito com ele (termos de uso
  em <https://opencadirrigation.com/pt/terms/>, política de privacidade em <https://opencadirrigation.com/pt/privacy/>).
- [Licença MIT](LICENSE.md); componentes e dados de terceiros no [capítulo da licença](docs/manual/pt-BR/licence.md).
