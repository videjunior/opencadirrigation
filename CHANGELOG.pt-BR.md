# Histórico de versões

O que mudou em cada versão do OpenCADIrrigation, da mais nova para a mais antiga. O app mostra a sua versão em
Ajuda → Sobre e na barra de status; o `pubspec.yaml` a guarda, e o checklist de lançamento do
[CONTRIBUTING.md](CONTRIBUTING.md#releasing) acrescenta aqui a seção de cada versão nova. Inglês (canônico):
[CHANGELOG.md](CHANGELOG.md).

## 1.6.1 (2026-11-04)

- **A estatística de visitas volta a contar todo mundo**: o site e o app carregam o Google Analytics com os seus
  cookies, como até a 1.5.2 (cada página vista e cada abertura do app; publicidade sempre negada; o endereço sem a parte
  depois do `#`). Na 1.6.0, quem não apertava *Aceitar* era contado sem cookies, e o Google Analytics 4 deixa essas
  visitas fora dos relatórios até um site ter milhares delas por dia; o aviso nem aparecia onde o app abre sozinho, então
  quase ninguém era contado. Nenhum aviso pergunta mais: *Preferências de cookies*, no rodapé das páginas, o abre, e o
  seu *Recusar* apaga os cookies e deixa de carregar a estatística naquele navegador (um *Recusar* dado na 1.6.0 é
  mantido). A política de privacidade, a FAQ e o manual dizem isso em todos os idiomas.
- **Novidades depois de uma atualização**: uma versão sem novidades próprias mostra as da versão mais nova a quem ainda
  não as viu.

## 1.6.0 (2026-11-02)

Uma varredura do projeto inteiro, com defeitos corrigidos em todas as áreas, e funções novas em treze delas: estações
de bombeamento e reservatórios, balanço hídrico diário, análises de energia e água, documentos técnicos, referências
de bloco, uma paleta de comandos e mais.

### O que se comporta diferente

- **Clima pelo NASA POWER**: Projeto → Clima do local baixa do NASA POWER por padrão (livre para qualquer uso); o
  Open-Meteo continua disponível, marcado como não comercial.
- **Datum do local**: a georreferência nomeia o datum do lugar (SIRGAS 2000 no Brasil e no resto da América do Sul e
  Central, ETRS89 na Europa, WGS84 nos demais) ou o escolhido; o `.prj` dos shapefiles e as exportações LandXML, IFC e
  EPANET diziam SIRGAS 2000 em toda parte.
- **Áreas gotejadas da galeria**: as áreas de gotejamento e microaspersão dos exemplos levam a cobertura do solo da
  sua cultura (Kr de 0,50 a 0,94 em vez de 1), então as lâminas e os tempos de rega são menores.
- **Carimbo profissional**: assim que algum campo dele é preenchido, o carimbo tem 40 mm de altura em vez de 30 mm, e
  a área de desenho da folha fica 10 mm menor.
- **Modelo do terreno**: o TIN não depende mais da ordem dos itens (pontos co-circulares e repetidos); as cotas nesses
  pontos podem mudar alguns milímetros.
- **Comprimento dos tubos ao longo do terreno**: as perdas e a lista de materiais usam o comprimento na encosta (2 % a
  mais em 20 % de declive, 12 % a mais em 50 %).
- **Edição**: `CO` passa a ser a ferramenta Copiar, com ponto-base (`COPYCLIP` e Ctrl+C copiam para a área de
  transferência), e Esc termina a polilinha mantendo o que foi traçado.

### Motor e hidráulica

- **Estações de bombeamento** (*Estação de bombeamento…* nas Propriedades da bomba): bombas em paralelo ou em série,
  reservas e partida escalonada, com o ponto de cada bomba em cada turno; Selecionar bomba faz uma estação das bombas
  em paralelo.
- **Operação real dos setores** (Parâmetros de projeto): cada setor e pivô também roda na pressão que a linha
  principal de fato entrega a ele, numa tabela da aba Linha principal.
- **Pilotos de válvula**: as válvulas de setor e as da linha principal podem reduzir a pressão a jusante, sustentar a
  de montante, ou as duas coisas.
- **Dimensionamento**: a classe do tubo cobre o golpe de aríete; nos morros com fonte calculada a linha piezométrica
  fica acima do tubo; os pontos altos sem ventosa são apontados; o PL leva o balanço de energia de cada anel.
- **O projeto ao longo da vida** (menu Linha principal): o projeto calculado envelhecido (tubos mais rugosos) e
  entupido (emissores) ao lado do novo.
- **Reservatório ou açude** (Propriedades da fonte): curva cota–área–volume pelo terreno, volume útil, corte, dias de
  demanda e tempo de enchimento; o nível desce e sobe na simulação de 24 horas.
- **Vasos de ar e volantes de inércia**: um vaso de ar numa junção da linha principal e um volante na bomba entram nos
  transientes; as análises longas da rede mostram o progresso e param com Cancelar.
- **Curvas de bomba** passam pelos seus pontos quando a parábola ajustada tem corcova; **fitas e laterais** contam a
  partir da ponta ligada à derivação; **dispositivos desenhados sobre a válvula** vêm depois dela.
- **Programação linear**: sem ciclos nos vértices degenerados (100 unidades em 1,5 s em vez de 5,5 min), e o limite de
  iterações é separado do problema inviável.
- **Golpe de aríete** triado ao longo do caminho da água (Michaud); **fita regulada** com regulador na entrada;
  **rendimento** do motor e do inversor na energia; emissores autocompensantes abaixo da faixa trabalham como
  orifícios.
- **Mensagens novas**: setor mantido abaixo da pressão nominal por um regulador, bomba abaixo da vazão mínima, setor
  cujo desnível passa da janela, pressão abaixo da atmosférica, sobra numa válvula que não regula.

### Projeto automático

- **Contornar pela imagem** (menu Desenhar, `WAND`): um clique dentro de um talhão, gramado ou lago o contorna na
  imagem de satélite (precisa de georreferência e de internet), com tolerância, suavização e detalhe; `V` contorna
  todos os talhões da vista.
- **Comprimento máximo da lateral** nos diálogos de bloco (B), SUBDIV e LAYOUT: subindo e descendo, pela variação de
  vazão admitida e pelo declive, com o que o limita, aviso quando a mais longa desenhada passa dele e *Usar o máximo
  calculado*.
- **Corrigir automaticamente e Otimizar** listam cada correção e mudança com uma caixa: *Manter só as marcadas* e
  *Mostrar no desenho*.
- Uma área desenhada cruzando a si mesma é avisada na hora; o orçamento guarda a profundidade padrão da adutora (0,6
  m) e dos tubos de setor (0 = na superfície); os anéis de árvores contornam lagos e recortes; a prévia do OFFSET é o
  resultado.
- Os blocos guiados cobrem o polígono inteiro e avisam quando as linhas passam do raio das curvas da guia; as rotas
  não compartilham vértices; áreas que se cruzam viram áreas simples; hidrozonas nunca dividem uma válvula.
- O Corrigir automaticamente deixa as decisões (bomba na rede pública, turnos novos) com você e o Otimizar trabalha
  por etapas; avisos de espaçamento e de uniformidade pelo densograma; prévias depois de uma pausa, com progresso e
  Cancelar.

### Agronomia

- **Projeto → Agronomia**: balanço hídrico diário do solo (FAO-56 cap. 8, déficit regulado por estágio, produção
  relativa pelo Ky) e programa de rega (janela diária, ciclo e pausa, ajuste sazonal, programa por estação e mês,
  CSV).
- Também ali: escoamento potencial (pivôs, lineares, zonas de aspersão), fertirrigação por estágio, uniformidade no
  campo (latas, densograma de lâmina, avaliações de CU e DU) e culturas do usuário, com uma aba *Manejo da irrigação* nos
  relatórios.
- **Arquivos de estação do INMET** (CSV ou ZIP) no Clima do local dão as normais e a série diária; a verificação do
  projeto compara a capacidade com a demanda de pico e a aplicação das máquinas com o solo.
- Uma regra para a irrigação localizada em todas as tabelas (Kr pela cobertura), Kc ajustado ao clima e ao intervalo
  de rega, normais de estação, faixas da CONAMA 284 como no texto oficial.
- Avisos de intensidade de aplicação acima da que o solo absorve, de ETo diferente da do clima do local, de data de
  plantio ambígua e de água salina demais para a cultura.

### Máquinas, energia e água

- **Elétrica da casa de bombas** (menu Projeto): motor IE3, tipo de partida, alimentador pela NBR 5410, curto-circuito
  pela IEC 60909, transformador ou gerador e grupo tarifário, e a alimentação dos pivôs.
- **Bombeamento solar do projeto** (isolado pela IEC 62253, ou ligado à rede pela Lei 14.300/2022), descontado do
  custo de energia; **Qualidade da água e filtragem**: risco de entupimento, filtros, cloro e ácido.
- **Vários pivôs na propriedade** (Projeto → Projeto automático), **Sistema de dois fios** (menu Zona, decodificadores
  na lista de materiais), **Faixas de carretel** e **Sulcos com tubo janelado** (menu Linha principal).
- Aba de relatório *Energia, água e máquinas*; o braço de canto não rega mais um anel duas vezes; a elétrica do linear
  e do braço, o aviso de volta lenta e os limites de corrente dos controladores.

### Documentos técnicos e pranchas

- **Arquivo → Carimbo e responsável técnico**: empresa, logotipo, responsável técnico, conselho, registro,
  ART/RRT/TRT, CAR, outorga, município/UF, etapa, número do desenho e revisões; *Salvar como meu padrão*.
- **Datum** em Arquivo → Georreferência; **quadrícula de coordenadas** UTM ou geográfica nas pranchas; folhas a mais
  de **declividade** e de **exposição**.
- **Arquivo → Exportar pacote de documentos (PDF)**: proposta, outorga e licenciamento, instalação, memorial técnico,
  operação e manutenção, cada um com capa, sumário, seções numeradas, plantas e assinatura.
- **Relatórios → Documentos técnicos**: quadro de outorga com automonitoramento (Resoluções ANA 1.939/2017 e
  188/2024), memorial descritivo e de cálculo (escrito sem a IA) e plano de operação e manutenção.
- Também ali: orçamento por composições (BDI pelo Acórdão TCU 2622/2013, cronograma físico-financeiro) e custo do
  ciclo de vida (NIST Handbook 135), em PDF, XLSX, CSV ou Markdown e nos pacotes.
- Relatórios: *Declividade por área irrigada* e as normas dos critérios sob cada tabela (PDF, CSV, TXT); verificação
  de captação sem medidor de vazão nem horímetro.

### Desenho CAD

- **Ver → Snaps e desenho**: cada snap à parte, entrada dinâmica, a lupa do toque e a edição durante o cálculo; END,
  MID, INT… só para o próximo ponto (NON limpa).
- Tab fixa o comprimento digitado e depois o ângulo, que aceita azimutes (A45) e rumos (N45E); coordenadas de campo
  como `23S 456789 7654321`, `UTM e,n`, `LL -22.5,-47.1` e GMS; pressão em kgf/cm².
- **Camadas**: estados de camadas com nome, LAYISO e LAYUNISO, Mover para a camada atual; o clique duplo edita um
  texto no lugar; Desenhar → Estilo de cota; TOFRONT e TOBACK.
- **Referências de bloco** com atributos `{TAG}`, contadas na lista de materiais quando marcadas, inseridas como
  referência ou como cópias, editadas no lugar (BEDIT) e explodidas; a biblioteca de blocos exporta e importa
  (`.oci-blocks.json`).
- Uma seleção mista edita um tipo de item por vez; as configurações de desenho e de snap ficam guardadas neste
  navegador; Desenhar → Foto de campo (pelo GPS da foto, do aparelho ou por clique); Alongar (`LEN`) e Contorno por
  clique interno (`BO`).
- **Arquivo → Comparar com…** outra aba, uma versão ou um arquivo, e **Trazer comentários de uma cópia**; as versões
  se comparam e abrem numa aba.
- **Edição**: Mover e Copiar com ponto-base, ângulo, fator e distância digitados, aparar e estender até contornos
  fechados, círculos, arcos e splines, selecionar semelhantes, seleção rápida, laço, cerca e por camada.
- Também: unir, explodir, concordância, chanfro, esticar, quebrar em dois pontos e converter em área; Medir mantém o
  resultado, soma comprimentos e mede áreas; menu de contexto no toque e na caneta; Backspace apaga a seleção.
- **Cópias no navegador** vão para o IndexedDB, gravadas 3 s depois da última edição e ao fechar, recuperadas item a
  item; Salvar como, Salvar como cópia e Arquivo → Armazenamento do navegador (baixar todos, pedir para manter);
  Cancelar no cartão de progresso.
- Servidor do mapa de ruas configurável e os termos de cada mapa; colar entre projetos mantém o lugar no mapa.

### Arquivos e formatos

- **Importação de pontos** (CSV, TXT, XYZ, PTS, PNEZD): um assistente com o papel de cada coluna, o separador decimal,
  o sistema de coordenadas e uma prévia no mapa do mundo que avisa de pontos distantes.
- **Arquivo → Exportar desenho → Pontos para locação (PNEZD)**; **Arquivo → Dados baixados guardados** mantém o MDT
  on-line e o clima no aparelho.
- **Folhas** de tamanho personalizado (e as alongadas ISO e ANSI), camadas no PDF e PDF/A-2b.
- As sobreposições de imagem do KMZ entram como fundo georreferenciado; blocos de levantamento com cota viram cotas;
  DXF/DWG exportados levam os dados hidráulicos (XDATA) e voltam como rede.
- GeoTIFF, BigTIFF e COG grandes reduzidos durante a leitura; projeções policônica, Albers e cônica conforme de
  Lambert; páginas de código CJK; um link de projeto grande pergunta antes de abrir.
- Pontos sem cota viram marcadores; unidades e cores do DWG; o CRS dos GeoTIFF; limites contra bombas de zip e blocos
  explosivos; DXF, DWG e LAS lidos em fatias com Cancelar; espaço papel fora.

### Modelo, catálogos e linha de comando

- **Áreas com ilhas**: Editar → Geometria → Subtrair da área (um lago, um prédio) dá a área e a água líquidas, o
  layout fica fora da ilha, e DXF/DWG/SHP/KML/GeoJSON a levam; *Remover as ilhas da área*.
- **Arquivo → Inserir projeto…** mescla outro `.oci.json` no seu lugar do terreno.
- **Tubos por norma**: pacotes ISO 1452, EN 12201, IS 4985 e IS 4984 com preços de referência datados (fonte e data no
  diálogo); o catálogo e o seu CSV nas unidades do projeto (polegadas, psi, gpm, preço por pé).
- **Parâmetros de projeto → Projetos novos**: de onde vem cada valor inicial, *Usar estes parâmetros nos projetos
  novos* e *Voltar ao padrão da região*.
- **Linha de comando**: `import`, `new`, `set`, `pack add` e lotes com `--out-dir`; o motor como pacote sem Flutter
  (`dart tool/engine_package.dart`, `dart compile exe`).
- Arquivos lidos item a item (campos desconhecidos preservados) com relatório de reparo, formato na versão 2 com
  migrações, TIN de 10 a 25 vezes mais rápido, catálogo padrão corrigido e conferido quanto à plausibilidade, CSV pela
  RFC 4180, `oci validate`, `oci schema`.
- Colagem no motor (itens de mesmo id renomeados, preços convertidos), tubos ASTM em polegadas, ft H₂O, a frequência
  da rede da região; o catálogo de fábrica e o seu padrão são restaurados, carregados ou esquecidos à parte, depois de
  uma confirmação.

### Assistente de IA

- **Aplicar o resto da tarefa** no cartão de aprovação; **Conversas do projeto** (lista, nova, abrir, apagar,
  exportar, importar): `/new` guarda a conversa atual, `/clear` a apaga.
- Configurações: **Testar a conexão** com o modelo (tempo, custo, limites), **Ajustar o esforço a cada etapa**, aviso
  quando o app está em segundo plano e notificações do sistema.
- **Custos por passo** sob cada resposta, com a fração lida do cache; um modelo menor lê os anexos longos
  (`summarize_attachment`).
- Alcança todas as funções novas e a edição da varredura (esticar, concordar, chanfrar, quebrar, unir, explodir,
  converter em área), Salvar como cópia, o armazenamento do navegador, os termos e o servidor dos mapas e a ETo pelas
  normais de estação.
- Permissões por configuração e por efeito, o cartão executa exatamente o que mostrou, os seus passos de desfazer
  separados das suas edições, uma conversa por aba, o conteúdo do projeto lido como dado, a seleção fixada enquanto
  planeja.

### Interface e tutorial

- **Ctrl+K** acha qualquer menu, comando ou ajuste (no celular, no topo do ☰); **Ajuda → Manual (F1)** e um **?** nas
  janelas e painéis; Ajuda → Novidades; Ajuda → Relatar problema ou sugerir função.
- **Ver → Interface**: tamanho, alto contraste, modo foco (Ctrl+Alt+F), o painel lateral recolhido, a sua borda
  arrastada até qualquer largura; uma **prévia das folhas** na exportação PDF e PNG.
- **Tutorial**: 90 passos em capítulos, com trilhas no cartão, continuando de onde parou, uma trilha curta para o
  toque, trilhas rápidas (gotejamento, paisagismo, pivô) e demonstrações de IA que não enviam nada; ele abre numa aba
  própria.
- Uma aba nova sem nome diz *Novo projeto* no idioma do momento.
- Números no formato do idioma; layouts de celular e de tablet; relatórios interativos (ordenar, filtrar, copiar, CSV,
  achar o item); diálogos com Cancelar de verdade; alvos de 48 px no toque e rótulos; Ajuda → Mensagens recentes.
- **Traduções**: totais do orçamento, pontos da curva da bomba e outros rótulos que ficavam em inglês em 17 idiomas
  foram traduzidos; um nome por conceito (*linha de derivação* em português, *portalaterales* em espanhol, *Auslass*
  para todo emissor em alemão), mantido por um glossário testado (`tool/i18n/glossary.json`).

### Site e app instalado

- **Abrir com** e compartilhar arquivos e fotos com o app instalado; uma segunda abertura vai para a janela já aberta.
- **Fontes** de todas as escritas servidas pelo próprio site (nenhum pedido ao Google); o **guia do usuário** no site
  (`/manual/`, `/pt/manual/`).
- **Ajuda → Termos dos dados**, com os créditos nas pranchas e no relatório; **Ver → Mapa base → Guardar o mapa da
  área para o campo**.
- **Privacidade e termos**: o site tem política de privacidade e termos de uso em todos os idiomas, com link no rodapé das páginas e em Ajuda → Sobre; o Sobre também diz que
  um profissional habilitado confere e assina o projeto feito com o app.
- **Estatísticas de visita em Consent Mode**: as páginas e o app carregam o Google Analytics em Consent Mode v2 (a
  publicidade sempre negada); sem consentimento, ele não grava cookie e manda avisos sem cookies (cada página e cada
  início do app), e os cookies só vêm depois de *Aceitar* no aviso que as páginas mostram uma vez. *Preferências de
  cookies*, no rodapé das páginas, muda a resposta, e recusar apaga os cookies.
- **Segurança**: uma Content Security Policy em cada página (scripts só do site, nenhum script inline), uma
  configuração de hospedagem versionada (`hosting/firebase.json`) com `Referrer-Policy`, `Permissions-Policy`,
  revalidação dos arquivos do app e redirecionamento permanente de `/en/`; os avisos das chaves dizem quem poderia ler
  uma chave lembrada.
- **Aviso de versão nova**: o app instalado e uma aba deixada aberta ficam sabendo da versão nova e oferecem
  recarregar nela (o trabalho não salvo vai para o autossalvamento).
- **Cópia offline menor**: os pacotes de idioma, as fontes do PDF e a lista de licenças só são guardados quando
  usados; a cópia para abrir sem rede passou de cerca de 28 para cerca de 17 MB, e um lançamento não baixa mais todos
  os idiomas.
- **Uma instalação em cada idioma**: cada página de idioma tem o seu manifest (nomes, atalhos e endereço de início
  naquele idioma), com uma captura de celular para a tela de instalação; o `hreflang` também cita os genéricos `pt` e
  `zh`.
- **Documentação**: um README curto com o manual em `docs/manual/` (inglês e português), este histórico,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, modelos de issue e de pull request e `CITATION.cff`; a regra
  editorial é testada por hash.
- Revisão das traduções por falantes nativos numa planilha (`tool/i18n_review.dart`); modelos de Discussions e imagem
  social do repositório.

### Engenharia

- **Teste de fumaça de ponta a ponta** do build de produção no Chromium, no WebKit e no Firefox, também no CI.
- Uma lista só de nomes proibidos (`tool/hooks/banned-names.sha256`) para o teste e para o hook de pre-commit;
  `test/seams/` reúne os testes que atravessam módulos.
- **Armazenamento do navegador cheio**: saem primeiro as versões e os projetos já salvos em arquivo, nunca o trabalho
  não salvo, e o aviso fica até uma cópia caber.
- CI no GitHub Actions com Dependabot, hooks de pre-commit, testes-guarda (worker de cálculo, pureza do motor, marca,
  data do site), `tool/release.dart`, fontes do PDF refeitas, build de macOS funcional, Flutter fixado em 3.47.9,
  nenhum teste chegando à rede.

## 1.5.2 (2026-10-31)

- Os emissores das fitas e dos tubos gotejadores aparecem iguais em qualquer sobreposição: pontos pequenos sobre a
  linha, na posição real de cada emissor, rareados com o zoom afastado; só a cor muda (a da sua própria pressão na
  sobreposição de pressão).

## 1.5.1 (2026-10-31)

- O fim do cálculo não trava mais o app: a cópia automática no navegador é comprimida pelo navegador em segundo
  plano, e as mensagens do assistente de projeto vêm prontas do cálculo.

## 1.5.0 (2026-10-31)

- Prancheta fluida com dezenas de milhares de itens e centenas de camadas: o desenho fica guardado entre quadros, um
  desenho pesado acompanha arrasto e zoom como imagem deslocada, e snaps e alças não varrem mais o projeto inteiro.

## 1.4.0 (2026-10-30)

- Cálculo do projeto até 25 vezes mais rápido, com exatamente os mesmos resultados.

## 1.3.0 (2026-10-30)

- O assistente de IA vê o desenho sobre a imagem de satélite, contorna talhões na imagem, segue os pontos e linhas
  marcados no mapa, aceita ditado, guarda as conversas no navegador, revisa o projeto com `/review`, confere a
  prancha antes de exportar e fixa fotos de campo com GPS.

## 1.2.0 (2026-10-26)

- O app abre num projeto vazio com uma tela de início: onde fica a área (endereço ou coordenadas) e se o projeto
  será feito com o assistente de IA; o assistente foi revisado e o site fala dele.

## 1.1.0 (2026-10-25)

- O assistente de IA opcional (Claude ou GPT, com a chave do próprio usuário) trabalha no projeto com as ferramentas
  do programa; projeto automático (distribuição de aspersores, zonas, traçado, divisão de talhões, ajuste de pivô),
  transientes hidráulicos e tema claro.

## 1.0.1 (2026-10-19)

- O código-fonte é publicado sob a licença MIT; o site e o app dizem isso e levam ao repositório.

## 1.0.0 (2026-09-22)

- Primeira versão pública: desenho CAD, rede hidráulica, dimensionamento por programação linear, relatórios,
  pranchas em PDF, DXF e DWG, tutorial interativo, galeria de exemplos, abertura sem rede e 20 idiomas.
