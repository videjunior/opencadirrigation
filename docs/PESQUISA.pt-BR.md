# Estudo técnico: CADs de irrigação, hidráulica de redes e as decisões do OpenCADIrrigation

> Tradução em português. A versão canônica, mantida em inglês, é [TECHNICAL_STUDY.md](TECHNICAL_STUDY.md).

Estudo iniciado em 15/09/2026 e ampliado em 16/09/2026 e em 25/10/2026. Este documento reúne a
pesquisa que orienta a arquitetura do OpenCADIrrigation (CAD de irrigação para o navegador): o que
os CADs comerciais fazem, a hidráulica e a agronomia que o motor implementa, com as equações e
exemplos numéricos, as formulações de dimensionamento, as análises de transientes e de operação, a
automação do traçado, os algoritmos de terreno e de desempenho, os formatos de arquivo estudados e
as fontes. Onde uma fórmula aparece, o módulo que a implementa está indicado, e o teste que a valida
também.

Este documento não cita empresas nem produtos de software concorrentes, nem produtos de CAD; as fontes são normas,
literatura técnica, software aberto (os mecanismos de referência e as bibliotecas que validam os
formatos) e a documentação da API dos provedores de modelos que o assistente de IA chama.

## Sumário

1. [Escopo e método](#1-escopo-e-método)
2. [O que um projetista espera de um CAD de irrigação](#2-o-que-um-projetista-espera-de-um-cad-de-irrigação)
3. [Por que um CAD de irrigação aberto no navegador](#3-por-que-um-cad-de-irrigação-aberto-no-navegador)
4. [Unidades e convenções do motor](#4-unidades-e-convenções-do-motor)
5. [Perda de carga contínua](#5-perda-de-carga-contínua)
6. [Perdas localizadas](#6-perdas-localizadas)
7. [Múltiplas saídas: fator F](#7-múltiplas-saídas-fator-f)
8. [Emissores e aspersores](#8-emissores-e-aspersores)
9. [Uniformidade](#9-uniformidade)
10. [Laterais e linhas de derivação](#10-laterais-e-linhas-de-derivação)
11. [Redes: o Global Gradient Algorithm](#11-redes-o-global-gradient-algorithm)
12. [Bombas e energia](#12-bombas-e-energia)
13. [Golpe de aríete e classes de pressão](#13-golpe-de-aríete-e-classes-de-pressão)
14. [Transientes hidráulicos](#14-transientes-hidráulicos)
15. [Dimensionamento](#15-dimensionamento)
16. [Linha principal, turnos e fontes](#16-linha-principal-turnos-e-fontes)
17. [Análises de operação](#17-análises-de-operação)
18. [Lavagem, conexões, fiação e lista de materiais](#18-lavagem-conexões-fiação-e-lista-de-materiais)
19. [Traçado automático](#19-traçado-automático)
20. [Vegetação em imagens aéreas](#20-vegetação-em-imagens-aéreas)
21. [Agronomia](#21-agronomia)
22. [Pivôs centrais e outras máquinas](#22-pivôs-centrais-e-outras-máquinas)
23. [Terreno e geoprocessamento](#23-terreno-e-geoprocessamento)
24. [Formatos de arquivo](#24-formatos-de-arquivo)
25. [Desempenho e arquitetura de software](#25-desempenho-e-arquitetura-de-software)
26. [Assistente de projeto](#26-assistente-de-projeto)
27. [Assistente de IA](#27-assistente-de-ia)
28. [Validação](#28-validação)
29. [Lacunas e trabalhos futuros](#29-lacunas-e-trabalhos-futuros)
30. [Glossário](#30-glossário)
31. [Fontes](#31-fontes)

---

## 1. Escopo e método

Perguntas que o estudo procurou responder:

1. O que um projetista espera de um CAD de irrigação, na ordem em que trabalha? Resposta na
   seção 2, a partir da prática profissional e dos manuais de projeto (National Engineering
   Handbook do NRCS, capítulos 7 e 11; Keller & Bliesner; manuais de irrigação da FAO).
2. Por que um CAD de irrigação aberto e no navegador, e que princípios isso impõe? Seção 3.
3. Quais equações são consenso na literatura e nos manuais de engenharia (NRCS, FAO, Keller &
   Bliesner, EPANET) e como testá-las? Seções 4 a 14, com exemplos numéricos recalculados.
4. Como dimensionar de forma reproduzível e explicável, e como analisar a operação do sistema
   depois de dimensionado (um dia de operação, tarifas, redes a demanda, energia, confiabilidade,
   calibração, fertirrigação)? Seções 15 a 18.
5. Que automação ajuda o traçado, e que métodos de agronomia e de máquinas o projeto precisa?
   Seções 19 a 22.
6. Que algoritmos de terreno, geoprocessamento, formatos e desempenho um CAD web precisa e como
   implementá-los sem bibliotecas nativas? Seções 23 a 25; os assistentes de projeto e de IA nas
   seções 26 e 27.

Fontes primárias: o manual do EPANET 2.2, os capítulos 2, 4, 7 (microirrigação) e 11 (aspersão) da
parte 623 do National Engineering Handbook do NRCS, o FAO-56, os boletins de irrigação e drenagem
29, 45, 46 e 59 da FAO, os manuais de irrigação da FAO, Keller & Bliesner (1990), Wylie & Streeter
(1993) e Chaudhry (2014) para os transientes, o manual M51 da AWWA para as ventosas, artigos
revisados sobre fator de atrito, emissores, uniformidade, operação de redes e análise de imagens, a
especificação aberta do formato DWG, as especificações de PDF, OpenType, LAS, LandXML e IFC e a
documentação dos serviços públicos de elevação e de clima.

Este estudo não cita produtos de software concorrentes nem as empresas que os fazem, nem produtos de
CAD. Fabricantes de componentes de irrigação aparecem apenas como origem dos dados dos catálogos, os
formatos de arquivo pelo nome do formato (DXF, DWG R2000) e os provedores de dados, mapas e IA como
fontes.

---

## 2. O que um projetista espera de um CAD de irrigação

### 2.1 Processo de projeto

A prática consolidada nos manuais de projeto (NRCS NEH 623, capítulos 7 e 11; Keller & Bliesner,
1990) organiza o trabalho em etapas, e é essa ordem que o menu Projeto e o tutorial seguem:

1. Detalhes do projeto: cliente, obra, projetista, unidades.
2. Informações de fundo: limites, edificações, estradas e, sobretudo, as **elevações** (curvas de
   nível, cotas e linhas de quebra), porque a topografia governa as pressões.
3. Layout: fontes de água, emissores, válvulas de controle, bombas, acessórios e tubos.
4. **Projeto das zonas**: dimensionar ou analisar da válvula de zona até os emissores, dentro da
   janela de pressão que garante a uniformidade.
5. **Gerenciamento**: quais válvulas operam juntas (turnos), por quanto tempo, e o que isso exige
   da fonte.
6. **Projeto da linha principal**: dimensionar ou analisar da fonte até as válvulas, turno a turno.
7. Materiais: conexões selecionadas automaticamente e lista de materiais com custos.
8. Plantas e relatórios: prancha com carimbo, legenda, escala e as tabelas de resultados.

### 2.2 Modelo de objetos

O modelo do OpenCADIrrigation (`entities.dart`) separa quatro famílias de itens:

- **Itens de zona**, a jusante de uma válvula de controle: tubo de zona, lateral com emissores
  igualmente espaçados (sprayline), fita ou tubo gotejador com emissores integrados, emissor
  individual, acessório (regulador, registro, filtro), junção e área irrigada com requisito
  hídrico. Geradores criam blocos de laterais com linha de derivação e válvula, grades de aspersores, anéis em
  volta de árvores e traçados automáticos (seção 19).
- **Itens de linha principal**: fonte de água, tubo principal, bomba, junção, acessório (filtros,
  hidrômetros, a válvula mestra, válvulas redutoras e sustentadoras de pressão, hidrantes com
  limitador de vazão, ventosas), válvula de controle, pivô central ou linear (uma demanda com
  pressão requerida própria) e **aspersores com válvula incorporada** (valve-in-head): emissores
  desenhados na linha principal, cada um com a válvula no corpo, agrupados em estações do
  controlador (seção 16.2).
- **Itens elétricos**: controlador (estações, tensão de saída, acessórios, custo) e rota de fio (o
  caminho dos condutores de estação e comum do controlador pelas válvulas).
- **Itens de desenho**: ponto, linha, polilinha, retângulo, círculo, arco, spline, hachura, cotas
  (linear, angular, radial ou de diâmetro, por ordenada e chamada), símbolos, texto, imagem, curva
  de nível, cota de ponto, **linha de quebra** (um divisor, um talvegue ou a borda de um terraço que
  o modelo do terreno não pode atravessar), comentário e nuvem de revisão; os blocos do usuário (um
  conjunto nomeado de entidades com um ponto-base) ficam no projeto e são inseridos como cópias.

Regras estruturais adotadas: uma válvula de controle sempre separa zona de linha principal; itens
de zona não se ligam a itens de linha principal sem uma válvula entre eles; vértices coincidentes
(dentro da tolerância de conexão) formam um nó; um item pontual sobre um tubo divide o tubo; não há
limite para o número de conexões numa junção, porque o solver de rede aceita qualquer grau. As rotas
de fio formam um grafo próprio e nunca tocam a rede hidráulica.

### 2.3 Banco de dados de componentes

Sete grupos (tubos, emissores com bocais, fitas, válvulas e acessórios, bombas, conexões, fios),
todos em SI, com os campos que a hidráulica e a fiação exigem:

- **Tubo**: diâmetro nominal, diâmetro interno real (o que entra no cálculo), C de Hazen-Williams,
  rugosidade, material (que dá o Ks de Scobey, o n de Manning e a redução da classe de pressão com a
  temperatura), classe de pressão, uso (lateral, zona, linha principal), custo por metro.
- **Fita**: CV de fabricação, diâmetro interno, pressão de entrada padrão, mínima e máxima,
  tolerâncias acima e abaixo, coeficiente de perda dos barbs, constante e expoente do emissor,
  espaçamento, classe.
- **Emissor e bocal**: q = k·H^x, raio molhado R = a·H^b (as duas leis ajustadas a linhas de
  catálogo, seção 8), arco, pressões mínima e máxima, CV, tolerância de vazão (±5 % é o valor
  usual), um perfil radial medido opcional (ensaio com coletores, seção 9.1), tipo (aspersor,
  microaspersor, gotejador, borbulhador, canhão, ponto de demanda).
- **Válvula e acessório**: perda h = K·Q^n + C, vazões mínima e máxima, tipo (controle, mestra, PRV,
  PSV, controladora de vazão ou hidrante com limitador, bloqueio, retenção, antirrefluxo, filtro,
  hidrômetro, ventosa), ajuste de uma válvula reguladora.
- **Bomba**: pontos (Q, H) ajustados a uma parábola, rendimento (um valor só ou uma curva), curva de
  NPSH requerido, potência nominal, a frequência da rede em que a curva foi levantada, instalação
  submersa ou de superfície.
- **Conexão**: tipo, diâmetros, custo.
- **Fio**: seção do condutor (mm², bitolas AWG convertidas), resistência por quilômetro (cobre
  ≈ 18,1 Ω·mm²/km quando não informada), custo por metro.

Os catálogos de fabricantes são arquivos JSON abertos (`catalogs/`), com dados típicos de catálogo
público e preços a preencher localmente; um item pode trazer o código com que é credenciado para
financiamento do BNDES (FINAME), que a lista de materiais e o orçamento mostram.

### 2.4 Métodos que o motor precisa cobrir

Do que a prática de projeto exige, o motor implementa:

- Perda de carga por **Hazen-Williams** com C por tubo e ajuste global (escala ou deslocamento)
  para envelhecimento, por **Darcy-Weisbach** (laminar, transição e turbulento) com viscosidade pela
  temperatura, e por **Scobey** e **Manning**.
- **Perdas localizadas** por percentual do comprimento, pelas curvas e tês que o desenho implica,
  pela curva própria de cada acessório, e a perda dos barbs por emissor nas fitas.
- **Janela de pressão** dos emissores derivada da tolerância de vazão (±5 % → cerca de ±10 % de
  pressão para expoente 0,5) e das pressões mínima e máxima do catálogo; fitas com tolerâncias
  assimétricas (por exemplo +20 % e −30 % da pressão de entrada).
- **Análise** com vazões nominais (rápida) e **análise detalhada** com emissores dependentes da
  pressão, por um solver de rede completo com bombas (de rotação fixa ou variável), PRVs, PSVs,
  válvulas controladoras de vazão e retenções.
- **Dimensionamento por programação linear** (topografia, janela de pressão, velocidade, classe de
  pressão na temperatura da água, economia, diâmetros habilitados e fixos, número de diâmetros por
  lateral e por linha de derivação) e por **velocidade máxima**, com racionalização dos diâmetros de montante
  para jusante.
- **Pressão da válvula** escolhida para que a pressão média dos emissores seja a nominal, ou, para
  fitas reguladas, para garantir a pressão mínima da linha de derivação.
- **Fonte de água** com pressão calculada (poço com nível negativo, reservatório com altura
  positiva) ou fixa (rede pública, com vazão e pressão de projeto e máximas).
- **Gerenciamento** por turnos, com duty de cada fonte por turno e tempos de operação a partir dos
  requisitos hídricos das áreas; agrupamento automático das zonas, pivôs e estações valve-in-head em
  turnos, pela vazão ou pela menor energia.
- **Transientes** pelo método das características (fechamento de válvulas, desligamento de bombas,
  separação de coluna, ventosas, reservatórios hidropneumáticos), um **dia de operação** como
  simulação de período estendido, programação pela tarifa, vazões a demanda, criticidade,
  calibração e fertirrigação.
- **Fiação das válvulas**: bitolas dos condutores de estação e comum pela queda de tensão nos
  solenoides, sistemas de dois fios com decodificadores, rotas automáticas pelas valas, estações do
  controlador e válvulas simultâneas.
- **Densograma**: a água aplicada pelos aspersores como desenhados, com a uniformidade por área.
- **Elevação** em cada nó do grafo a partir do modelo do terreno.

### 2.5 Relatórios e ferramentas gráficas

Resumo das zonas (vazão, pressões admissíveis e reais, variação admissível e real, pressão a jusante
da válvula, perda na válvula), uniformidade (CU, DU do quartil inferior, EU de Keller-Karmeli),
tabelas de tubos e emissores (cotas, pressões, vazões, velocidades, diâmetros), linha principal e
duty das fontes, estações valve-in-head, bombas e acessórios, requisitos hídricos por cultura, mês e
estádio, agronomia, programa do controlador, lavagem, golpe de aríete e transientes, pivôs, vãos e
pacotes de aspersores, lista de materiais (também por zona e de uma seleção) com custos anualizados
e um orçamento; gráficos de linha piezométrica, de perfil e das curvas das bombas, sobreposições de
velocidade, pressão, diâmetros, mínimos e máximos e declividade/aspecto, envelope de posição do
linha de derivação, densograma (a água aplicada pelos aspersores como desenhados) e vista 3D do terreno; fiação
das válvulas (estações, bitolas, tensão nos solenoides, decodificadores).

### 2.6 Formatos

Importação de DXF, DWG, DGN V7, plantas em PDF, KML/KMZ, SHP (também zips com vários shapefiles),
GeoJSON, GPX, LandXML, nuvens de pontos LAS, INP do EPANET, CSV/XYZ/PNEZD, GeoTIFF e imagens
georreferenciadas; exportação de DXF (R2000 e R12), DWG (R2000), PDF (pranchas,
conjuntos de pranchas, detalhes e gráficos), PNG, SVG, KML/KMZ, GeoJSON, shapefiles, GPX, LandXML,
IFC 4, INP do EPANET e relatórios em CSV, TXT, XLSX e PDF; projeto em JSON aberto com o catálogo
embutido.

---

## 3. Por que um CAD de irrigação aberto no navegador

Observações gerais sobre o cenário, sem referência a produtos:

- As ferramentas profissionais de projeto de irrigação são, em regra, aplicativos de desktop para
  um único sistema operacional ou plug-ins de plataformas CAD pagas, com licença comercial, bancos
  de componentes fechados e formatos de projeto proprietários.
- Na web existem sobretudo calculadoras de fabricantes (lateral, linha de derivação, bomba) e serviços
  fechados por assinatura voltados a paisagismo.
- O motor de rede aberto de referência, já consolidado, é o EPANET (domínio público, US EPA),
  voltado a redes de abastecimento e sem os objetos de irrigação (laterais, fitas, válvulas de zona,
  turnos).
- Quem projeta em campo, em tablet ou em máquinas sem privilégio de instalação fica mal atendido.

Princípios que decorrem disso e que o OpenCADIrrigation adota:

1. Rodar no navegador sem instalação e sem servidor, com os dados no computador do usuário.
2. Formato de projeto e de catálogo em JSON aberto e documentado.
3. Motor hidráulico transparente, com as equações documentadas e testadas contra referências
   públicas, e com o solver do EPANET como base para redes.
4. Interface nos 20 idiomas mais falados e pensada também para toque.

---

## 4. Unidades e convenções do motor

Internamente tudo é SI: comprimento em m, vazão em m³/s, carga em metros de coluna de água, pressão
em Pa, diâmetro em m, velocidade em m/s (`units.dart`). A interface converte para métrico (L/h,
m³/h, m.c.a. ou kPa, mm) ou US (gpm, psi, polegadas, pés). Constantes: 1 m.c.a. = 9,80665 kPa =
1,42197 psi; 1 bar = 10,197 m.c.a.; 1 L/h = 2,7778 × 10⁻⁷ m³/s; 1 m³/h = 2,7778 × 10⁻⁴ m³/s.

Viscosidade cinemática da água (m²/s) em função da temperatura, por ajuste de tabela entre 0 e
50 °C (erro < 1 %): 1,004 × 10⁻⁶ a 20 °C; 1,13 × 10⁻⁶ a 15,6 °C (60 °F, valor usual nos manuais
norte-americanos). A pressão de vapor da água vem da fórmula de Tetens,
p_v = 0,61078·exp(17,27·T/(T + 237,3)) kPa, 0,24 m de água a 20 °C; a carga atmosférica, da
atmosfera padrão na cota do local, 10,33 m ao nível do mar.

Os catálogos guardam k dos emissores em m³/s por m^x. Conversão da vazão nominal q_n (L/h) a H_n (m):
k = (q_n / 3,6 × 10⁶) / H_n^x. Exemplo: 1,6 L/h a 10 m com x = 0,5 → k = 1,4055 × 10⁻⁷.

---

## 5. Perda de carga contínua

Módulo `friction.dart`; testes em `hydraulics_test.dart` e `valves_formulas_test.dart`.

### 5.1 Hazen-Williams

h_f = 10,67 · L · Q^1,852 / (C^1,852 · D^4,871), com Q em m³/s, D em m. Válida para água a
temperatura ambiente e escoamento turbulento; C ≈ 140 a 150 para PVC e PE (a prática é adotar
valores um pouco menores nos diâmetros pequenos, em torno de 135 a 140, e até 150 nos grandes).
Estudos com PE mostram que o C só é constante para V > 0,7 m/s e 20 a 30 °C; fora disso o erro
chega a 19 %, o que justifica oferecer Darcy-Weisbach.

Formas derivadas usadas no código: resistência r tal que h_f = r·Q^1,852; gradiente unitário
J = h_f/L; diâmetro equivalente de n laterais idênticas em paralelo (regra prática de projeto):
D_eq = (d^4,871 · n^1,852)^0,2053.

**Exemplo.** L = 100 m, Q = 5 m³/h (1,389 × 10⁻³ m³/s), C = 150:
D = 50,0 mm → V = 0,707 m/s, h_f = 1,106 m (J = 1,11 m/100 m);
D = 46,8 mm (PVC DN 50 real) → V = 0,807 m/s, h_f = 1,526 m.

### 5.2 Darcy-Weisbach

h_f = f · (L/D) · V²/(2g), Re = V·D/ν.

- Laminar (Re < 2000): f = 64/Re.
- Transição (2000 a 4000): a interpolação cúbica do EPANET (polinômio de Dunlop), que casa o valor
  laminar 0,032 em Re = 2000 e o valor e a inclinação de Swamee-Jain em Re = 4000, ambos avaliados
  em Re = 4000 como no código-fonte do EPANET; a função é contínua e a inclinação coincide no
  extremo turbulento (testes "transitional regime is continuous" e "transitional cubic matches the
  turbulent slope at Re = 4000 (EPANET)"). Como no EPANET, a curva desce um pouco abaixo de 0,032
  perto de Re 2500 antes de subir.
- Turbulento: **Swamee-Jain** f = 0,25 / [log₁₀(ε/(3,7D) + 5,74/Re^0,9)]², explícita, com erro
  inferior a 1 % em relação a Colebrook-White 1/√f = −2·log₁₀(ε/(3,7D) + 2,51/(Re·√f)), que o código
  também resolve iterativamente como referência.
- Blasius f = 0,3164·Re^−0,25 para tubos lisos com Re < 10⁵ (laterais de PE e fitas).

Rugosidades ε: PVC e PE 0,0015 a 0,007 mm; aço 0,045 mm; ferro fundido 0,26 mm.

**Exemplo** (mesmo tubo de 50 mm, ε = 0,0015 mm, ν = 1,004 × 10⁻⁶): Re = 35 227, f = 0,0226,
h_f = 1,153 m, contra 1,106 m por Hazen-Williams com C = 150 (diferença de 4 %, coerente com o
teste "Darcy-Weisbach agrees with Hazen-Williams for smooth PVC").

### 5.3 Scobey

A fórmula de Scobey (1930), a tradicional das laterais de aspersão de aço e de alumínio com
engates, está implementada na forma SI de Keller & Bliesner h_f = 4,1 × 10⁻³ · K_s · L · Q^1,9 / D^4,9
(Q em m³/s, D em m), o mesmo que h_f = 2,59 × 10⁻³ · K_s · L · V^1,9 / D^1,1 com V em m/s, como resistência
r = 4,1 × 10⁻³ · K_s · L / D^4,9, de modo que h_f = r·Q^1,9. (Até esta revisão o motor punha o 4,1 da forma
em vazão na forma em velocidade, o que exagerava a perda em 58 %.) Com K_s = 0,40 a perda é a de
Hazen-Williams com C 120–130, a equivalência usual do alumínio com engates. O coeficiente
vem do material do tubo do catálogo (Keller & Bliesner 1990): K_s = 0,32 para plástico, 0,40 para
alumínio com engates (e concreto), 0,42 para aço galvanizado com engates e ferro dúctil.

### 5.4 Manning

Para um tubo circular cheio, h_f = 10,29 · n² · L · Q² / D^(16/3) (SI; Chow 1959), resistência
r = 10,29·n²·L/D^(16/3). O n de Manning por material: 0,009 para PVC e PE, 0,011 para alumínio, 0,012
para aço, 0,013 para ferro dúctil e concreto. **Exemplo**: o tubo de 50 mm da seção 5.1 com n = 0,009
dá h_f = 1,40 m, um pouco acima dos 1,11 m de Hazen-Williams: Manning, uma lei de canais rugosos, é
conservadora para tubos pequenos e lisos. A exportação para o EPANET grava Manning como a sua
fórmula de Chezy-Manning (C-M) e Scobey, que o EPANET não tem, como Darcy-Weisbach com um aviso.

As quatro leis estão disponíveis em todo lugar onde uma perda é calculada: as análises de zona e de
linha principal, o dimensionamento, o tubo dos vãos do pivô e o solver de rede, que usa o
coeficiente próprio de cada tubo (teste "the solver uses them: one pipe between two reservoirs
carries the flow of the law").

### 5.5 Expoente da vazão

O fator F de Christiansen e a linearização do LP dependem do expoente m da lei de perda
(`flowExponent`): 1,852 em Hazen-Williams, 1,85 em Darcy-Weisbach (entre os 1,75 de Blasius e os
2,0 do regime rugoso pleno), 1,9 em Scobey e 2,0 em Manning. Dentro do solver de rede o gradiente
de um tubo usa n = 1,852 (Hazen-Williams), 1,9 (Scobey) e 2,0 (Darcy-Weisbach e Manning).

---

## 6. Perdas localizadas

Módulo `minor_losses.dart`. Duas formas equivalentes:

- h_m = K·V²/(2g), com K de Crane TP-410 e da literatura de irrigação: cotovelo 90° 0,4 a 0,8, raio
  longo 0,2 a 0,4, tê passagem 0,2 a 0,6, tê derivação 1,0 a 1,8, registro gaveta 0,15, globo 6 a
  10, redução 0,1 a 0,5, entrada 0,5, saída 1,0.
- Forma de vazão h_m = m·Q² (estilo EPANET), com m = K / (2g·A²), usada dentro do solver.
- Comprimento equivalente L_e = K·D/f, o método usual dos CADs de irrigação para acrescentar as
  perdas a cada segmento.

O OpenCADIrrigation oferece dois métodos (`MinorLossMethod`), ambos desligados quando as perdas
localizadas são desligadas nos parâmetros do projeto:

- **Percentual do comprimento** (o padrão, 5 %): os tubos de zona e de linha principal são
  analisados com um comprimento equivalente L·(1 + p); laterais e fitas ficam só com a perda dos
  barbs.
- **Conexões do desenho** (`NetworkBuilder._assignFittingLosses`, método dos coeficientes de
  conexões do Crane TP-410): o K das curvas e tês que o desenho implica é somado aos trechos de tubo
  de zona e de linha principal vizinhos, e nenhum percentual é aplicado. Um vértice onde dois tubos
  se encontram e a direção gira 67,5° ou mais é um cotovelo de 90° (K = 0,75); a partir de 22,5°, um
  cotovelo de 45° (K = 0,35); o K vai para o tubo que sai do vértice. Num nó de três ou mais tubos o
  par mais alinhado é a passagem (K = 0,4, metade em cada um dos seus dois tubos) e cada um dos
  demais tubos é uma derivação (K = 1,5). Testes em `minor_fittings_test.dart`.

Acessórios e válvulas seguem a curva própria h = K·Q^n + C (Q em m³/s), ajustada por regressão
log-log a partir de pontos de catálogo ou construída a partir de um K adimensional e do diâmetro.

Em laterais de gotejamento, a perda nas conexões dos emissores (barbs) chega a 30 a 50 % do total;
o fator Kd por emissor das fitas do catálogo modela essa perda.

---

## 7. Múltiplas saídas: fator F

Christiansen (1942): a perda de uma lateral com N saídas iguais é h_lateral = F · h_f(Q_entrada),
com

F = 1/(m+1) + 1/(2N) + √(m−1)/(6N²).

Primeira saída a meio espaçamento (Jensen-Fratini): F = (2N/(2N−1)) · [1/(m+1) + √(m−1)/(6N²)].
**Scaloppi (1988)** para a primeira saída a uma distância r·S arbitrária:
F_a = (N·F + r − 1)/(N + r − 1), que se reduz a F quando r = 1 (teste "Scaloppi adjustment reduces
to F when r=1").

**Exemplo.** N = 20, m = 1,852: F = 0,3760; com a primeira saída a meio espaçamento, 0,3600;
N = 100: 0,3556, tendendo a 1/(m+1) = 0,3506.

O motor usa F para estimativas rápidas (calculadora de lateral, comparação com o solver no teste
"friction loss agrees with Christiansen estimate"); o cálculo de projeto usa a análise passo a
passo e o solver de rede, que não precisam da hipótese de vazões iguais.

---

## 8. Emissores e aspersores

Módulo `emitter.dart`.

- Lei do emissor **q = k·H^x**. x = 0,5 para orifícios e regime turbulento; 0,6 a 0,8 para longo
  percurso; 1,0 para laminar; 0 a 0,1 para autocompensantes (0,02 a 0,05 típico). Ajuste por
  mínimos quadrados em log q = log k + x·log H (teste "fit recovers exponent").
- Sensibilidade: Δq/q ≈ x · ΔH/H. Logo, ±5 % de vazão equivalem a ±10 % de pressão para x = 0,5.
  Janela exata a partir da lei inversa (`headWindow`): H/H_n ∈ [0,95^(1/x), 1,05^(1/x)]:

| x | H/H_n mínimo | H/H_n máximo | Faixa total |
|---|---|---|---|
| 0,53 | 0,908 | 1,096 | 18,9 % |
| 0,50 | 0,902 | 1,103 | 20,0 % |
| 0,47 | 0,897 | 1,109 | 21,3 % |
| 0,10 (PC) | 0,599 | 1,629 | 103 % (limitado então pelas pressões mínima e máxima do catálogo) |

  Os três primeiros valores são os que a prática de projeto associa à tolerância de ±5 % de vazão.
- Raio molhado R = a·H^b (b ≈ 0,35).
- **Bocais a partir de um catálogo** (`EmitterCurve.fitTable`): linhas de pressão, vazão e,
  opcionalmente, raio molhado viram as duas leis de potência q = k·H^x e R = a·H^b, cada uma ajustada
  por mínimos quadrados em escala log-log; com uma só linha de raio supõe-se b = 0,5 (o alcance
  crescendo como a velocidade do jato). O pior desvio relativo das linhas em relação a cada lei é
  informado, de modo que um erro de digitação numa linha aparece antes de o bocal entrar no
  catálogo.
- Taxa de aplicação (precipitação) PR = q / (S_l · S_m), com S_l o espaçamento ao longo da lateral
  e S_m a distância perpendicular entre laterais, tanto na malha quadrada quanto na triangular
  (desencontrada); só quando S_m é dado como o lado de um triângulo equilátero a área leva o fator
  sen 60°. Em unidades US, PR [in/h] = 96,3·gpm/(S·L).
  Exemplo: aspersor de 1,9 m³/h a 15 × 17 m → 7,45 mm/h.
- Espaçamento recomendado: 50 % do diâmetro molhado ("head-to-head") sem vento; 40 a 45 % com vento.
- **CU de sobreposição**: o motor simula a lâmina numa célula de espaçamento a partir de um perfil
  radial triangular de cada aspersor e calcula o CU de Christiansen do padrão sobreposto, como
  verificação de cobertura (teste "head-to-head overlap gives high CU"); o resultado entra no resumo
  da zona para aspersores com raio molhado.

---

## 9. Uniformidade

Módulo `uniformity.dart`.

- **CU de Christiansen**: CU = 100·[1 − Σ|x_i − x̄| / (n·x̄)]. Satisfatório ≥ 85 % em aspersão.
  Exemplo: vazões relativas 1,00, 1,10, 0,95, 1,05, 0,90 → CU = 94,0 %.
- **DU do quartil inferior**: média do quarto menor sobre a média geral. Relação aproximada
  CU ≈ 100 − 0,63·(100 − DU).
- **EU de Keller-Karmeli (1974)**: EU = 100·(1 − 1,27·CV/√n)·(q_min/q_méd), com CV do fabricante e n
  emissores por planta. Classificação ASAE: > 94 % excelente, 90 a 94 % bom, 80 a 90 % aceitável,
  < 80 % ruim; com fertirrigação o NRCS pede EU ≥ 85 %.
  Exemplo: CV = 0,03, q_min/q_méd = 0,90 → EU = 86,6 % com 1 emissor por planta e 88,3 % com 4.
  O n vem da área irrigada que contém os emissores da zona (ou do parâmetro global).
- **Uniformidade estatística** U_s = 100·(1 − CV_total); **variação de vazão** q_var =
  (q_max − q_min)/q_max, desejável ≤ 10 %, aceitável ≤ 20 %.
- Regra de laterais de aspersão: variação de pressão ≤ 20 % da pressão de operação, que dá ≈ 10 % de
  vazão para x = 0,5.

### 9.1 Densograma

O CU de sobreposição da seção 8 idealiza o arranjo como uma malha infinita. O densograma (módulo
`densogram.dart`) soma o setor molhado de cada aspersor e microaspersor **como desenhado**: posição,
arco e orientação (anti-horário a partir da orientação, como na tela) e, depois de um cálculo, a
pressão e a vazão de cada emissor (assim o raio R = a·H^b e a vazão seguem a pressão real ao longo
das laterais). Um aspersor espalha sua vazão q pelo setor de ângulo θ com um perfil radial f(r/R)
normalizado para que o volume integre de volta a q:

- triangular f = 1 − r/R (aspersores de impacto de um bocal): i(r) = q·(1 − r/R) / (θR²/6);
- elíptico f = √(1 − (r/R)²) (rotores de vários bocais, microaspersores): i(r) = q·f / (θR²/3);
- uniforme f = 1 (sprays, precipitação equalizada): i = q / (θR²/2);
- **medido**: um bocal pode trazer a distribuição radial de um ensaio com coletores
  (`NozzleSpec.profile`, lida de uma tabela de distância e lâmina: as distâncias escaladas pela
  estação molhada mais distante, que é o raio molhado, e as lâminas pela maior). Entre as estações a
  lâmina é linear, constante antes da primeira e caindo a zero depois da última; a intensidade é
  i(r) = q·f(r/R) / (θR²·∫₀¹ f(x)·x dx), o momento integrado por trapézios em 64 passos, de modo que o
  volume volta a ser exatamente q.

O **vento** deforma o padrão por um modelo cinemático de primeira ordem: a água que uma gota leva do
aspersor ao deslocamento v em ar parado cai em v + a·|v|·ŵ, com ŵ a direção para onde o vento sopra e
a = k·u, u a velocidade do vento na altura do aspersor e k um coeficiente de deriva (0,07 s/m por
padrão; a limitado a 0,9). Os padrões assim se deslocam e se alongam a favor do vento, como os
estudos de aspersores isolados no vento relatam (Seginer, Kantz and Nir 1991). Cada célula da grade
é levada de volta à sua origem em ar parado (o inverso do deslocamento, em forma fechada) e a
intensidade se divide pelo alongamento local da área J = 1 + a·v∥/|v|, o que conserva o volume. O
modelo não substitui padrões medidos em dias de vento.

As intensidades são somadas numa grade (um quarto do menor raio por padrão, engrossada para no
máximo 60 000 células) e avaliadas dentro de cada área irrigada que contém aspersores (ou nas
células molhadas quando não há nenhuma): intensidade média, mínima e máxima, CU, DU do quartil
inferior, **coeficiente de programação** SC = média / média dos 5 % de células mais secas (quanto
mais tempo o sistema precisa funcionar para os pontos mais secos receberem a lâmina média; 1 é
perfeito, até cerca de 1,3 é bom) e a fração de células abaixo da metade da média. Cada área é
julgada — e pintada — contra a sua própria média: um gramado de sprays (≈ 40 mm/h) ao lado de um de
rotores (≈ 13 mm/h) são ambos uniformes mesmo com intensidades diferentes, o que uma estatística
única misturada esconderia. Os testes conferem que cada perfil integra à vazão (os medidos também),
que meio círculo molha a sua metade com o dobro da intensidade, que o espaçamento cabeça a cabeça dá
CU alto e o espaçamento largo, bem mais baixo, e que o vento conserva o volume enquanto leva a água a
favor dele.

---

## 10. Laterais e linhas de derivação

Módulo `lateral.dart` (Wu & Gitlin 1975; Keller & Bliesner 1990).

- **Análise passo a passo do fim para o início**: H_i = H_{i+1} + h_f(Q_{i+1}, S) ± ΔZ,
  Q_i = Q_{i+1} + q(H_i). Para uma pressão de entrada conhecida, itera-se sobre a pressão final
  (`analyzeLateralFromInlet`); para uma pressão média desejada, procura-se a pressão de entrada que a
  produz (`analyzeLateralForMeanPressure`), que é o critério de ajuste da válvula.
- Perfis de pressão: aclive, horizontal, declive suave (mínimo no fim), declive acentuado (mínimo no
  meio, porque o ganho por gravidade supera o atrito). Teste "downhill slope raises end pressure".
- Repartição usual da perda admissível: 55 % na lateral e 45 % na linha de derivação.
- **Posição de alimentação**: alimentar pelo meio reduz a perda a ≈ 1/(2^m · 2) e permite laterais
  1,6 a 1,7 vezes mais longas. `allowableFeedPositions` avalia alimentar uma lateral de comprimento
  L numa fração f (0 = extremidade, 0,5 = centro), com os dois ramos partilhando a pressão de entrada
  escolhida para que a média seja a nominal, e devolve as posições aceitáveis e a ótima; é o
  "envelope da linha de derivação" pintado no desenho e o teste "feed positions: centre feed is best on flat
  ground".
- **Comprimento máximo**: bisseção sobre L, múltiplo do espaçamento, até a variação atingir a janela
  (teste "max lateral length is monotonic").

---

## 11. Redes: o Global Gradient Algorithm

Módulo `network.dart` (Todini & Pilati 1988, conforme o manual do EPANET 2.2), com o solver
esparso de `sparse_solver.dart`. Testes em `network_test.dart`, `network_robustness_test.dart` e
`valves_formulas_test.dart`.

### 11.1 Formulação

Para cada trecho ij com perda h_ij(Q):

- tubo: h = r·|Q|^n·sgn(Q) + m·Q·|Q|, com r e n da lei de atrito da seção 5;
- bomba: h = −ω²·(h₀ − r·(Q/ω)^n), ou a parábola ajustada do catálogo;
- emissor: tubo fictício até um reservatório na cota do emissor, com n = 1/x e r = (1/k)^n, que é a
  forma como o EPANET trata emissores q = C·p^γ. Sua vazão é uma variável de estado, atualizada pelo
  mesmo passo de Newton de um tubo: nessa forma em vazão a lei p = (q/k)^(1/x) é convexa. Linearizar
  q(p) (como o motor fazia até outubro de 2026) passa do ponto, porque dq/dp é infinito em p = 0, e
  emissores trabalhando perto de pressão zero abriam e fechavam sem fim: 55 % de um conjunto de
  redes aleatórias bem dimensionadas nunca convergiam, 72 % com emissores autocompensantes.
  Gradientes abaixo de 10⁻⁶ usam uma lei linear, como o EPANET faz com o RQtol: um emissor faminto
  segura seu nó em pressão perto de zero e deixa passar o que chega. O passo nunca leva um emissor
  a mais de 10 % acima do que sua lei dá na pressão atual (o Newton passa do ponto numa lei íngreme
  vindo de baixo: x = 0,02 é p ∝ q⁵⁰), expoentes abaixo de 0,01 são tomados como 0,01 pela mesma
  vazão a 10 m, e a forma em vazão é avaliada até 1000 m. O emissor é unidirecional: quando sua
  vazão ficaria negativa ele fecha (sem vazão de saída e, ao contrário de um reservatório, sem
  retorno para a rede) e reabre numa verificação de estado quando a pressão é positiva (testes
  "emitters under negative pressure", `network_robustness_test`).

Define-se g_ij = ∂h/∂Q = n·r·|Q|^{n−1} + 2·m·|Q| (em Darcy-Weisbach acrescenta-se ∂r/∂Q·|Q|^n) e o
fator de correção y_ij = h_ij(Q)·sgn(Q). Em cada iteração resolve-se o sistema linear simétrico
positivo definido A·H = F, com

A_ii = Σ_j 1/g_ij, A_ij = −1/g_ij, F_i = Σ_j (Q_ij + y_ij/g_ij) − D_i + Σ_f H_f/g_if,

os últimos termos para reservatórios de carga fixa. As vazões atualizam-se por
Q_ij ← Q_ij − (1/g_ij)·(y_ij − (H_i − H_j)).

### 11.2 Válvulas e casos especiais

Os modelos das válvulas são os do EPANET.

- **PRV** ativa força H_j = H_ajuste (A_jj += 10⁸, F_j += 10⁸·H_ajuste); fechada, h = 10⁸·Q. O estado
  segue a lógica do EPANET: ativa → aberta quando a carga de montante menos a perda da válvula
  totalmente aberta fica abaixo do ajuste, aberta → ativa quando a carga de jusante (não a de
  montante) passa do ajuste (testes "PRV holds downstream pressure", "an open pressure reducing
  valve whose inlet is just above the setting stays open").
- **PSV** (válvula sustentadora de pressão) ativa mantém o seu nó de montante no ajuste
  (A_ii += 10⁸, F_i += 10⁸·H_ajuste) e a sua vazão sai da continuidade nesse nó. Estados como no
  `psvstatus` do EPANET: ativa → aberta quando a carga de jusante mais a perda da válvula totalmente
  aberta passa do ajuste (aberta, a válvula deixaria o montante acima dele de qualquer jeito); ativa
  ou aberta → fechada com vazão invertida; aberta → ativa quando a carga de montante cai abaixo do
  ajuste; fechada → aberta ou ativa quando as cargas voltariam a empurrar a vazão para a frente (teste
  "a PSV holds the upstream pressure at its setting and limits the flow accordingly").
- **FCV** (válvula controladora de vazão) ativa deixa passar a sua vazão de ajuste: uma vazão fixa de
  uma ponta à outra, com uma condutância ínfima de 10⁻⁸ entre elas para que nenhum dos lados fique
  sem carga, como o EPANET faz. Ela abre (passando menos que o ajuste) quando a carga através dela
  fica negativa e volta a ativa quando a vazão atinge o ajuste. Um **hidrante com limitador de
  vazão** é uma FCV cujo ajuste é a vazão digitada, ou a vazão nominal do item do catálogo (testes
  "an FCV lets its flow setting through, or less when the head is not there", "a hydrant flow
  limiter in a project limits the flow of its branch").
- Válvula de retenção, num tubo ou como acessório próprio: fecha quando o escoamento inverte ou a
  carga fica contra ela e reabre quando a queda de carga volta a ser positiva (teste "a check valve
  fitted as a device stops reverse flow"; a retenção como acessório deixava a água voltar).
- Bomba: linearizada em |Q| enquanto aberta, como no EPANET; fecha só quando o ganho de carga pedido
  passa da carga de shutoff e reabre abaixo dela, na vazão que sua curva dá para essa carga (um passo
  com vazão invertida a travava fechada para sempre).
- Acessórios: curva h = K·Q^n + C do catálogo. A **válvula mestra** da linha principal é um desses
  acessórios para a hidráulica; na parte elétrica ela é a saída de válvula mestra do seu controlador
  (seção 18.1).
- O gradiente de um acessório ou de uma válvula aberta nunca fica abaixo de 10⁻⁷ (o RQtol do
  EPANET): com perda quase nula em vazão quase nula (uma ventosa numa linha parada) um piso menor,
  10⁻⁹ até outubro de 2026, deixava o sistema mal condicionado demais para resolver ao lado da
  condutância de 1/10⁸ de uma bomba fechada.
- Demanda dependente da pressão nos emissores (Wagner): é a análise detalhada do projeto, com a
  vazão real de cada emissor.

### 11.3 Convergência e álgebra

Critério: Σ|ΔQ|/Σ|Q| < 10⁻⁵, ou Σ|ΔQ| < 10⁻⁹ m³/s em redes (quase) sem vazão, onde a medida
relativa é ruído, com até 200 iterações (`NetworkOptions`); mais apertado que os 10⁻³ do EPANET
porque as zonas de gotejamento têm vazões minúsculas por nó. Como no EPANET, os estados (retenções,
bombas, emissores que reabrem, PRVs, PSVs e FCVs) só mudam quando as vazões convergiram, e nas dez
primeiras iterações a cada duas: mudá-los a cada iteração deixava dispositivos unidirecionais perto
do ponto de troca em ciclo. Um conjunto fixo de redes em árvore aleatórias precisa convergir para
soluções que satisfazem a continuidade e as leis de perda de carga (`network_robustness_test`).

**Partes em repouso.** Trechos fechados (uma válvula ou retenção fechada, uma bomba parada) podem
isolar uma parte da rede sem carga fixa e de onde nada é retirado: uma linha parada atrás de uma
bomba desligada. Resolvida junto com o resto, essa parte tinha o nível segurado só pelas
condutâncias de 1/10⁸ dos trechos fechados, ao lado de condutâncias de 10⁷ dentro dela, e o sistema
ficava singular por arredondamento: redes paradas divergiam. Em cada iteração o solver encontra
essas partes (union-find sobre os trechos abertos; uma parte está ocupada quando tem um
reservatório, uma demanda ou um emissor com vazão, ou alimenta uma bomba, uma FCV ou uma PRV ou PSV
ativa) e nivela cada uma na carga média através dos seus trechos fechados — o valor que as suas
condutâncias iguais dariam — ou no seu emissor mais baixo quando ele está abaixo disso, porque a
água escoa por ali. Os seus nós entram no sistema como cargas conhecidas e os seus trechos não levam
vazão (testes "converge level at the mean head across the closed links, whatever their size", para
linhas de 10 a 800 trechos, e "drain down to their lowest emitter").

A matriz A é montada como esparsa e fatorada por LDLᵀ com ordenação por grau mínimo; para redes
ramificadas (quase árvores) a fatoração não gera preenchimento e o custo é próximo de linear, o que
permite zonas com milhares de nós (teste "large branched network is fast").

### 11.4 Uso no projeto

A zona é resolvida como rede completa: reservatório de carga fixa no nó de jusante da válvula
(pressão da válvula), nós com emissores agregados, trechos da linha de derivação e laterais. A **pressão da
válvula** é achada por bissecção para que a pressão média dos emissores seja a nominal (a versão
"análise rápida" usa demandas fixas e um ajuste linear em duas passagens). A linha principal é
resolvida por turno com fontes de pressão fixa ou calculada, bombas e as demandas das válvulas, dos
pivôs e das estações valve-in-head (seção 16).

---

## 12. Bombas e energia

Módulo `pump.dart`; seleção em `pump_selection.dart`. Testes em `pump_devices_test.dart`,
`mains_frequency_test.dart` e `valves_formulas_test.dart`.

- Curva H(Q) quadrática H = a·Q² + b·Q + c ajustada por mínimos quadrados a três ou mais pontos
  (dois pontos dão reta; um ponto gera a curva sintética de três pontos do EPANET). Relação de
  velocidade ω pelas leis de afinidade: H(Q) = ω²·H_base(Q/ω); Q ∝ N, H ∝ N², P ∝ N³.
- Curva do sistema H_sis(Q) = H_estático + k·Q^n; ponto de operação na interseção, por bissecção.
- Potência hidráulica P = ρ·g·Q·H; potência de eixo divide pelo rendimento. Região preferida 70 a
  120 % da vazão de melhor rendimento.
- **Curva de rendimento**: quando o catálogo dá pontos (Q, η), o rendimento na vazão q e na relação
  de rotação ω é a curva na rotação plena lida na vazão homóloga q/ω (as leis de afinidade mantêm o
  rendimento dos pontos homólogos), linear entre os pontos e no mínimo 5 %; senão, o rendimento único
  do item. A energia anual de cada turno usa esse valor.
- **NPSH**: o NPSH requerido de uma curva de pontos (Q, NPSHr) escala como NPSHr(q, ω) =
  NPSHr₁(q/ω)·ω² (o último segmento prolongado além da curva, porque o NPSH requerido continua
  subindo para o fim da curva). O NPSH disponível na entrada da bomba é NPSHd = H_atm(z) + p_entrada
  − p_v(T), a carga atmosférica na cota do local mais a carga de pressão na entrada menos a pressão de
  vapor na temperatura da água; `pump_npsh` avisa quando NPSHd < NPSHr + 0,6 m (a ANSI/HI 9.6.1
  recomenda uma margem de 0,5 a 1,5 m ou uma razão para a maioria dos serviços).
- **Custo anual** = capital · CRF + energia, com CRF = i(1+i)^n / ((1+i)^n − 1). Para i = 10 % e
  n = 10 anos, CRF = 0,16275. Energia [kWh/ano] = P[kW] · horas/ano; o custo da energia da carga
  de entrada entra no objetivo do LP (seção 15).
- **Seleção automática** (`pump_selection.dart`): para o pior duty da fonte, classifica as bombas
  do catálogo pela capacidade de atender vazão e carga com folga e escolhe o motor padrão IEC que
  cobre a potência de eixo com fator de serviço 1,15. Quando a água está mais funda que a altura
  de sucção prática, só bombas submersas servem.
- **Altura de sucção**: o nó de uma fonte representa a superfície da água, então um poço começa
  com pressão zero no nível da água e a pressão na entrada de uma bomba de superfície é menos a
  altura de sucção (desnível estático mais as perdas da tubulação de sucção). O limite prático é
  a carga atmosférica na cota do local (10,33 m ao nível do mar, atmosfera padrão) menos a pressão
  de vapor a 20 °C (0,24 m) e uma reserva de 3 m para o NPSH requerido e a margem: cerca de 7,1 m
  ao nível do mar e 5,9 m a 1000 m. Uma bomba de superfície em operação além disso gera o aviso
  `pump_suction_lift`. Uma bomba marcada como *submersa* no catálogo fica instalada no nível da
  água da fonte que a alimenta: sua entrada não tem sucção e o desnível aparece no tubo que sobe a
  partir dela; o balanço de energia não muda. O relatório lista bombas e acessórios numa tabela
  própria com pressões de entrada e saída, altura da bomba ou perda, e situação.

### 12.1 Frequência da rede elétrica

A curva de uma bomba é levantada numa frequência de rede (`PumpSpec.ratedHz`; `hz` nos pacotes de
catálogo, sendo de 60 Hz o pacote de bombas incluído), e o local tem a sua (`DesignParameters.mainsHz`,
50 ou 60 Hz). Um motor de indução de rotação fixa gira em proporção à frequência, então o construtor
da rede dá à bomba a relação de rotação ω = f_rede / f_curva (vezes a relação que o usuário digitou):
uma curva de 60 Hz numa rede de 50 Hz roda a 5/6 = 0,833 da sua rotação, entrega 0,833 da vazão em
pontos homólogos, 0,694 da altura e precisa de 0,579 da potência. Uma curva sem frequência informada
é lida como está. A seleção de bombas lê todas as curvas na rotação da rede, e a faixa de vazão
admitida escala com ela (Q ∝ N). Para o desligamento da bomba da seção 14 a rotação de trabalho do
motor vem dos seus polos e da rede: a rotação síncrona 120·f/p menos cerca de 3 % de escorregamento,
arredondada a 50 rpm, 3500 rpm (2 polos) e 1750 rpm (4 polos) em 60 Hz, 2900 e 1450 rpm em 50 Hz
(testes "a 60 Hz pump on 50 Hz mains runs at 5/6 of the speed; a variable speed drive is not slowed",
"pump selection reads the curves at the speed of the mains").

### 12.2 Bombas de rotação variável com pressão alvo

Uma bomba com pressão de saída alvo tem inversor de frequência (`PumpEntity.targetPressureM`): em
cada turno o dimensionador acha a relação de rotação, entre a mínima (0,5 por padrão, no mínimo 0,1)
e a relação própria da bomba, em que a pressão de saída é igual ao alvo, por bissecção sobre a
rotação com toda a linha principal resolvida a cada passo (até 0,05 m ou 10⁻⁴ de rotação, no máximo
30 passos; três rodadas quando vários inversores interagem). A frequência da rede não reduz a
rotação de um inversor. Quando nem a rotação mais alta alcança o alvo o projeto informa
`vfd_target_unreachable`, quando a mais baixa já passa do alvo `vfd_below_min_speed`, e quando uma
fonte calculada precisa completar uma pressão de que as válvulas precisam `vfd_target_low`. A
rotação pertence ao turno: os resultados dos acessórios a trazem, o gráfico das curvas das bombas
desenha a curva nessa rotação, e a energia usa o rendimento no ponto homólogo (teste "a
variable-speed pump holds its outlet pressure flow after flow; NPSH and efficiency curves").

---

## 13. Golpe de aríete e classes de pressão

Módulo `water_hammer.dart`; verificação em `Designer.checkSurge`. A análise completa de transientes
pelo método das características está na seção 14.

### 13.1 Verificação de Joukowsky

- Joukowsky: ΔH = a·ΔV/g. Celeridade a = √[(K/ρ) / (1 + K·D/(E·e))], com K = 2,2 GPa,
  E_PVC ≈ 3 GPa, E_PEAD ≈ 0,9 GPa, E_aço ≈ 200 GPa.
- Tempo crítico de fechamento 2L/a: fechamentos mais rápidos produzem a sobrepressão total; mais
  lentos, uma fração proporcional (o parâmetro "tempo de fechamento da válvula", 3 s nos exemplos
  com solenoides).

| Tubo DN 100 | Celeridade | ΔH para ΔV = 1,5 m/s | 2L/a para 500 m |
|---|---|---|---|
| PVC, parede 5 mm | 375 m/s | 57,3 m | 2,67 s |
| PEAD, parede 9,1 mm | 281 m/s | 43,0 m | 3,56 s |
| Aço, parede 4 mm | 1314 m/s | 200,9 m | 0,76 s |

- Regra prática: V ≤ 1,5 m/s (5 ft/s) em tubulações termoplásticas enterradas (ASAE S376.2), o
  limite padrão dos tubos de zona; os 2,0 m/s padrão da linha principal são aceitos onde a
  verificação do golpe confirma a classe.
- Classe do tubo (PN 6, 8, 10, 12,5, 16; PVC classe B 60 m, C 90 m, D 120 m) comparada com a pressão
  estática máxima mais a sobrepressão; o pior trecho de cada tubo entra na aba Golpe de aríete.

### 13.2 Classes de pressão e a temperatura da água

Os tubos termoplásticos perdem parte da classe de pressão quando a água está quente
(`pipeTemperatureDerating`, `PipeSpec.ratingAt`): o PVC mantém a classe inteira até 25 °C e 0,9 dela a
30 °C, 0,8 a 35 °C, 0,7 a 40 °C e 0,6 a 45 °C (ISO 1452-2 Anexo A e as fichas técnicas da NBR 14312);
o PE a mantém até 20 °C, 0,87 a 30 °C e 0,74 a 40 °C (ISO 4427-1 Anexo A, 50 anos); linear entre os
pontos e mantida no último valor acima da tabela. Tubos de metal e de concreto mantêm a classe.
Exemplo: um tubo de PVC de classe 100 m (PN 10) com água a 35 °C fica com 80 m. A classe na
temperatura da água do projeto é a que o dimensionamento respeita (seção 15.5), a que os resultados
informam e a que as verificações de golpe e de transientes comparam (teste "warm water derates the
class: PVC passes at 20 °C but not at 35 °C").

---

## 14. Transientes hidráulicos

Módulos `transient.dart` (o método das características em qualquer rede) e
`transient_analysis.dart` (os estudos de um projeto: transientes, posicionamento de ventosas e a
simulação de 24 horas da seção 17.1), segundo Wylie & Streeter (1993), *Fluid Transients in
Systems*, e Chaudhry (2014), *Applied Hydraulic Transients*. Testes em `transient_test.dart` e
`transient_analysis_test.dart`.

### 14.1 Equações e grade

Ao longo das características C⁺ e C⁻ de um tubo as equações de quantidade de movimento e de
continuidade ficam, na forma em carga e vazão,

H_P = C_P − B_P·Q_P e H_P = C_M + B_M·Q_P, com C_P = H_A + B·Q_A, C_M = H_B − B·Q_B, B = a/(gA),

e o termo de atrito linearizado como B_P = B + R·|Q_A| (R a resistência de atrito de um trecho), o
que mantém o regime permanente exato e o esquema estável com atrito grande. Num ponto interior da
grade H_P = (C_P·B_M + C_M·B_P)/(B_P + B_M) e Q_P = (C_P − C_M)/(B_P + B_M).

- **Celeridade**: da parede de cada tubo do catálogo pela fórmula de Korteweg da seção 13.1.
- **Grade**: um só passo de tempo Δt para todo o sistema e Δx = a·Δt em cada tubo. As celeridades
  são ajustadas para caber um número inteiro de trechos dentro de ±10 %; um tubo que não pode ser
  ajustado usa interpolação na linha espacial com número de Courant abaixo de um; um tubo muito
  mais curto que a·Δt é concentrado numa coluna rígida de água (inércia L/(gA) e o seu atrito), no
  máximo 2 % do comprimento total. O tubo mais longo recebe pelo menos 8 trechos enquanto um
  orçamento de trabalho de pontos da grade × passos permitir (4·10⁷; 2·10⁷ nos estudos de projeto),
  e Δt é no máximo um décimo do tempo de parada I·ω/T de cada bomba desligada. Todo ajuste é
  informado.
- **Cadeias fundidas**: tubos em série do mesmo diâmetro e celeridade, unidos em nós que não
  retiram água, formam uma só grade de características que mantém o perfil de cotas, de modo que um
  ponto alto dentro dela ainda cavita.
- **Atrito**: Darcy-Weisbach quase permanente com um fator constante por tubo, o que reproduz a
  perda de carga permanente na vazão permanente: um tubo de Hazen-Williams recebe o seu fator de
  Darcy equivalente na vazão permanente, e um tubo sem vazão (abaixo de 0,02 m/s) o fator a 1 m/s.
- Cargas e pressões são manométricas, como no solver permanente; as cargas de vapor e barométrica
  são absolutas, a barométrica a da cota do local e a de vapor a da temperatura da água.

### 14.2 Condições de contorno

Os nós são resolvidos um a um, acoplados só onde elementos pontuais os unem (Newton num pequeno
sistema denso); um passo em que um estado muda (uma retenção fechando, uma cavidade se formando,
uma bolsa de ar se fechando) é resolvido de novo.

- Reservatórios, pontas mortas, junções em série e em derivação.
- **Válvulas**: a relação de orifício ΔH = ΔH₀·(Q/(τ·Q₀))², calibrada pela perda permanente do
  acessório, com a abertura relativa τ(t) de um curso τ = τ_fim + (τ₀ − τ_fim)·(1 − t/T)^E (E = 1 é um
  fechamento linear) ou de uma tabela. Uma válvula colocada num tubo tem a perda aberta de um
  registro gaveta, ΔH = K·V²/2g·(1/τ² − 1): ela só estrangula perto do fim do curso, e o seu
  fechamento efetivo é bem mais curto que o curso.
- **Demandas e emissores** como orifícios, Q = Q₀·(p/p₀)^x (x = 0,5); uma demanda para como uma vazão
  prescrita que cai linearmente (o contorno da fórmula de Michaud) ou como um orifício cujo τ cai
  linearmente, que é como o fechamento de uma válvula de zona aparece visto da linha principal.
- **Retenções** fecham com vazão invertida e reabrem quando a carga volta a empurrar para a frente;
  a lei do orifício é regularizada perto da vazão nula.

**Exemplo** (o exemplo da API): um reservatório de 100 m alimentando um tubo de 1000 m e 0,5 m
(a = 1000 m/s), fechado de uma vez por uma válvula com 0,998 m/s. A carga na válvula sobe a·V/g =
101,8 m e oscila com o período 4L/a = 4 s; um fechamento lento de tempo t_c > 2L/a dá cerca de
2·L·V/(g·t_c) de Michaud (testes "instantaneous closure: Joukowsky surge a·ΔV/g and the 4L/a
period", "slow demand stop: Michaud surge 2·L·V/(g·tc)", "slow valve closure: first-interval orifice
solution, below Joukowsky, rigid column when very slow", "friction damps the oscillation", "mass is
conserved at a branching junction").

### 14.3 Desligamento de bomba

Depois de uma falta de energia a relação de rotação α da bomba cai pela equação da rotação
I·ω_R·dα/dt = −T_R·β, integrada num passo como α_P = α − (k/2)·(β + β_P) com k = T_R·Δt/(I·ω_R), e o
modelo de torque β = β₀·α² + (1 − β₀)·α·v, v = Q/Q_R ≥ 0: o torque em vazão nula é β₀ do torque de
operação (0,5 por padrão) e a potência cresce linearmente com a vazão em rotação constante, uma
simplificação documentada da curva homóloga de torque de uma bomba radial. A carga segue as leis de
afinidade, H = a·Q·|Q| + b·α·Q + c·α², a quadrática da curva prolongada além da sua faixa (em α = 0 o
rotor parado é uma perda quadrática), e a retenção incorporada fecha com vazão invertida.

O momento de inércia da bomba e do motor, quando não informado, é estimado a partir da potência
nominal P (kW) e da rotação N (milhares de rpm) pelas correlações de Thorley & Faithfull (1992),
*Inertias of pumps and their driving motors*:

I_bomba = 0,03768·(P/N³)^0,9556 e I_motor = 0,0043·(P/N)^1,48 (kg·m²).

Exemplo: 15 kW a 3500 rpm dão 0,0138 + 0,0371 = 0,051 kg·m². Num estudo de projeto a potência é a
nominal do item do catálogo (senão a potência de eixo no ponto de operação) e a rotação a dos polos
do motor na rede (seção 12.1), vezes a rotação de um inversor (testes "run-down follows the pump
boundary condition until the reflection returns; the check valve closes", "the inertia estimate
grows with the power and falls with the speed").

### 14.4 Separação de coluna

Onde a pressão cai à pressão de vapor o modelo de cavidade de vapor discreta (DVCM) mantém a carga
na carga de vapor naquele nó ou ponto da grade; as vazões de um lado e de outro então diferem, e o
volume da cavidade integra a diferença com uma ponderação ψ (0,5 por padrão, de 0,5 a 1; Bergant,
Simpson & Tijsseling 2006):

∀_P = ∀ + Δt·[ψ·(Q_saída,P − Q_entrada,P) + (1 − ψ)·(Q_saída − Q_entrada)].

A cavidade colapsa quando as vazões do passo a enchem, e o colapso produz os pulsos curtos de
pressão da separação de coluna. **Cavidades vazias**: uma cavidade esvaziada só pelas vazões do
passo anterior, enquanto as vazões deste passo a abririam de novo (a carga do líquido cairia abaixo
da carga de vapor), fica na carga de vapor com volume nulo em vez de colapsar; colapsá-la fazia a
carga cair abaixo da carga de vapor no passo seguinte. Um nó fundido interpolado dentro de uma
cadeia é mantido na sua carga de vapor ou acima dela, porque um ponto alto entre pontos da grade
tomaria emprestadas as cargas dos pontos mais baixos (teste "column separation: vapour cavity at the
valve after the downsurge").

### 14.5 Ventosas

Uma ventosa de tríplice função (terminologia do AWWA M51) num nó admite ar pelo orifício grande
quando a pressão cai abaixo da atmosférica e o expele pelo orifício de saída (igual numa ventosa
simples de ar/vácuo, menor numa saída antigolpe), com coeficientes de descarga de 0,6. O ar admitido
forma uma bolsa isotérmica, p·∀ = m·R·T, cuja massa integra as vazões do orifício pela regra dos
trapézios (Wylie & Streeter 1993). A vazão mássica é o escoamento isentrópico de um gás perfeito por
um bocal: subsônico,

ṁ = C_dA·√(2κ/(κ−1)·p_m·ρ_m·[r^(2/κ) − r^((κ+1)/κ)]), r = p_j/p_m,

enquanto r está acima da razão crítica (2/(κ+1))^(κ/(κ−1)) = 0,528, e bloqueado abaixo dela,
ṁ = 0,685·C_dA·p_m/√(R·T) (κ = 1,4, R = 287,05 J/(kg·K)). Dois detalhes fazem as iterações de
Newton do nó convergirem:

- a vazão do orifício cresce com √Δp, infinitamente íngreme em Δp = 0, onde as iterações iam e
  voltavam sem fim: dentro de ±10 Pa (cerca de 1 mm de água) da pressão atmosférica a lei é
  interpolada linearmente;
- uma bolsa que encolhe abaixo de 1 cm³ fecha a ventosa: a boia já fechou, e a lei rígida de uma
  bolsa que desaparece só travaria o passo (a ventosa pode voltar a abrir num passo posterior).

Teste "a combination air valve admits air at a high point when the head drops below the pipe".

### 14.6 Reservatórios hidropneumáticos

Um reservatório de ar (tanque hidropneumático) num nó guarda gás pela lei politrópica H*·∀ⁿ = C (H*
a carga absoluta do gás, n = 1,2 por padrão: 1 é isotérmico, 1,4 adiabático), ligado por um orifício
com coeficientes de perda diferentes na entrada e na saída do reservatório (2,5 e 1,0 cargas
cinéticas, um orifício diferencial que estrangula mais a entrada). A vazão para dentro do
reservatório com a carga H no nó é a raiz de H − R·Q·|Q| − z_w(Q) − C/∀(Q)ⁿ + H_b = 0, com
∀(Q) = ∀ − Δt·(Q₀ + Q)/2 e o nível z_w seguindo a área da superfície livre quando informada (Wylie &
Streeter 1993; Chaudhry 2014). O reservatório comporta três vezes o seu volume de gás quando não
informado, e `transient_vessel_drained` avisa quando o gás o enche (teste "an air vessel at the
discharge limits the downsurge").

### 14.7 Estudos de transientes de um projeto

`TransientStudy` aplica o método à linha principal permanente de cada turno exatamente como o
dimensionamento a analisa (`Designer.mainlineNetworkFor`: fontes calculadas na pressão de que as
válvulas precisam, as rotações dos inversores no turno):

- **Fechamento de válvulas**: as válvulas de zona e os pivôs do turno, vistos da linha principal como
  orifícios cuja abertura cai a zero no tempo de fechamento dos parâmetros do projeto, e os
  aspersores das estações valve-in-head que o turno programa;
- **Desligamento de bomba**: uma falta de energia em todas as bombas em operação no turno (seção
  14.3);
- **Fechamento de registro**: um item da linha principal cujo tipo no catálogo é bloqueio ou válvula
  mestra, no seu próprio tempo de fechamento.

Cada tubo usa a celeridade da sua parede no catálogo, o seu comprimento físico (o dimensionamento
soma as perdas localizadas como comprimento; a perda permanente é mantida) e a sua classe de pressão
na temperatura da água; as ventosas desenhadas na linha principal atuam como ventosas de tríplice
função do seu tamanho nominal. A duração é escolhida a partir do evento e de seis períodos 4L/a do
caminho mais longo (mais 5 s, entre 15 e 120 s). Para cada entidade de tubo o estudo guarda as
envoltórias de carga e de pressão do transiente contra a classe e contra o vácuo
(`transient_overpressure`, `transient_underpressure`, `transient_vacuum`), as cavidades de vapor
(`transient_column_separation_pipe`) e o ar admitido, o perfil ao longo do caminho crítico (cotas do
tubo e do terreno, carga permanente, as duas envoltórias e a linha da classe), a pressão no tempo na
descarga da bomba e no pior ponto, e as ocorrências que a planta marca (sobrepressão, vácuo,
separação de coluna, ar admitido). Testes: nos exemplos da cana e da gravidade, "every scenario runs
and the steady state lies inside the envelopes"; "an instantaneous closure on a simple line gives
about the Joukowsky surge", "a power failure trips the pump: the check valve closes, the speed
falls, the discharge drops", e uma linha principal de fazenda com algumas centenas de tubos simulada
por dezenas de segundos num teste que limita o seu tempo de execução.

### 14.8 Posicionamento de ventosas

`suggestMainlineAirValves` monta o perfil de cada caminho de uma fonte de água até uma ponta da linha
principal (cotas do tubo e do terreno, a menor linha piezométrica permanente dos turnos, a envoltória
mínima do transiente quando um estudo é informado, diâmetros internos, bombas e retenções) e coloca
ventosas nele pela prática do manual M51 da AWWA, *Air-Release, Air/Vacuum, and Combination Air
Valves* (`air_valves.dart`):

- pontos altos do tubo, e do tubo em relação à linha piezométrica: ventosas de tríplice função;
- aumentos da declividade descendente: ventosas de ar/vácuo (ou de tríplice função), que admitem ar
  quando a linha se esvazia; reduções da declividade ascendente: ventosas de expulsão de ar (ou de
  tríplice função), onde o ar se acumula em operação;
- subidas, descidas e trechos horizontais longos: uma ventosa pelo menos a cada 400 a 800 m (1/4 a
  1/2 milha), com os intervalos maiores divididos em partes iguais;
- a descarga de uma bomba (ar/vácuo), 1 m a jusante das retenções, e a ponta da linha;
- pontos onde a linha piezométrica permanente chega a menos de 2 m do tubo, e onde a envoltória
  mínima do transiente cai abaixo da pressão atmosférica (proteção contra vácuo).

Declividades abaixo de 0,0005 contam como horizontais, uma mudança de declividade de 0,005 conta num
vértice, um ponto alto precisa de 0,1 m de subida e de descida em volta dele, e sugestões a menos de
20 m uma da outra são fundidas.

O dimensionamento segue o procedimento do M51 com a vazão de orifício da seção 14.5: o orifício
grande de uma ventosa de ar/vácuo ou de tríplice função deixa passar o ar que substitui a maior
vazão de esvaziamento com a pressão interna 5 psi (34,5 kPa) abaixo da atmosférica, e expele o ar
que a vazão de enchimento desloca com 2 psi (13,8 kPa) acima dela. A vazão de esvaziamento é a do
tubo cheio escoando por gravidade na declividade que se afasta da ventosa, a perda de Hazen-Williams
igual à declividade: Q = (S·C^1,852·D^4,871/10,67)^(1/1,852) ≈ 0,278·C·D^2,63·S^0,54 (C = 140); a vazão
de enchimento padrão é a de 0,3 m/s (1 ft/s), a velocidade de enchimento que o M51 recomenda. O
orifício pequeno de uma ventosa de expulsão de ar libera o ar que a água carrega, 2 % da vazão em
volume à pressão atmosférica, na pressão de operação. O tamanho nominal é o seguinte da série padrão
(25 a 600 mm para ventosas de ar/vácuo e de tríplice função, 12,5 a 50 mm para expulsão de ar) e o
item do catálogo que serve; as ventosas sugeridas são inseridas nos tubos nas suas posições.
Exemplo (o exemplo da API): uma linha de 2000 m e 0,3 m que sobe 20 m até o meio recebe ventosas de
tríplice função a 500 m (subida longa), 1000 m (ponto alto), 1500 m (descida longa) e 2000 m (ponta
da linha) (testes "a hill: high point, line end and valves on the long ascent and descent", "orifice
sizing by compressible flow, gravity drainage by Hazen-Williams", "the transient minimum envelope
adds vacuum protection; a catalogue without air valves is reported").

---

## 15. Dimensionamento

Módulos `lp.dart`, `lp_sizing.dart`, `designer.dart`. Testes em `lp_test.dart`,
`sizing_features_test.dart`, `design_test.dart` e `pressure_class_test.dart`.

### 15.1 Velocidade máxima

Para cada unidade dimensionável (entidade com tubo "computer sized"), o menor diâmetro habilitado do
catálogo, do uso certo (lateral, zona ou linha principal), cuja velocidade a vazão máxima do trecho
respeita o limite (2,0, 1,5 e 2,0 m/s por padrão). É o dimensionamento por velocidade clássico dos
manuais e a primeira etapa dos dois métodos aqui, porque fornece as vazões nominais que o LP precisa.

### 15.2 Programação linear

Formulação (lp_sizing.dart):

- **Variáveis**: para cada unidade u e cada diâmetro candidato d, a fração x_ud do comprimento da
  unidade construída com d; mais uma variável de carga livre por zona (pressão de entrada) ou por
  fonte de pressão calculada.
- **Objetivo**: minimizar Σ_u Σ_d c_ud · x_ud + Σ_h e_h · H_h, onde c_ud é o custo anualizado do
  trecho todo em d (custo por metro × comprimento × CRF) e e_h o custo anual por metro de carga
  (potência da vazão do turno × horas × preço da energia / rendimento), com um peso mínimo quando não
  há bomba para o LP ainda preferir a menor carga.
- **Restrições**: Σ_d x_ud = 1 para cada unidade; para cada nó crítico, a pressão
  H_h − Σ_u Σ_d L_ud · x_ud − termos constantes ∈ [P_mín, P_máx], onde L_ud é a perda do trecho da
  unidade que está no caminho até o nó quando construído inteiramente com d (a perda é linear nas
  frações porque a vazão em cada unidade é fixada pela etapa de velocidade; ela inclui o atrito da lei
  escolhida e as perdas localizadas do método das conexões); velocidade máxima e classe de pressão
  via o conjunto de diâmetros candidatos; fixação de tubos não dimensionáveis.
- **Nós críticos** da zona: a ponta, o nó mais alto e o mais baixo de cada lateral e cada emissor
  isolado (com teto). Se a análise não confirmar a janela, os emissores de pressão mínima e máxima
  entram como restrições adicionais e o LP roda de novo, até quatro rodadas.
- **Arredondamento e telescopagem**: as frações são convertidas no número permitido de diâmetros
  por unidade (1 lateral, 3 linha de derivação, 3 linha principal por padrão), maiores diâmetros a montante; as
  unidades com mais de um diâmetro são divididas em entidades antes da análise final.
- **Solver**: simplex denso de duas fases com regra de Dantzig e fallback de Bland contra ciclagem;
  os problemas têm centenas de variáveis e restrições, o que cabe num tableau denso. Detecta
  inviabilidade e ilimitação (teste "simplex: equality rows, infeasible and unbounded detection").

Uma simplificação comum em ferramentas de dimensionamento é reduzir cada lateral a um tubo
equivalente com um emissor concentrado antes do LP; aqui a lateral é uma unidade com seus nós
críticos, sem redução.

### 15.3 Reparo e racionalização

Depois do LP (ou só com a velocidade, no método guloso), a zona é analisada e, se um emissor viola a
janela, sobe-se o diâmetro da unidade do caminho crítico com maior redução de perda por custo, até
atender (`_repairZone`). Em seguida a racionalização garante diâmetros não crescentes de montante
para jusante. O teste "LP design meets the pressure window and costs no more than greedy" compara os
dois métodos no exemplo do pomar.

### 15.4 Pressão da válvula e resultados

A análise detalhada final escolhe a pressão a jusante da válvula por bissecção para que a pressão
média dos emissores seja a nominal (para fitas reguladas, para garantir a pressão mínima da
linha de derivação). A perda na válvula vem da sua curva; a pressão requerida a montante alimenta a linha
principal. A variação admissível da zona vem da tolerância de vazão do emissor (ou do parâmetro
"variação máxima da zona") e a real é medida sobre os emissores agregados.

### 15.5 Classe de pressão como restrição

Um tubo precisa aguentar a pressão que acaba levando, e essa pressão só é conhecida depois de uma
análise da rede dimensionada. O dimensionamento a aprende, então, em passadas (`_requiredRating`):
depois de uma passada, a maior pressão permanente nas pontas de cada segmento de cada unidade
dimensionável é comparada com a classe do seu tubo na temperatura da água do projeto (seção 13.2);
uma unidade cujo tubo tem classe abaixo dela recebe essa pressão como classe mínima, e a passada
seguinte só lhe oferece, no LP e nas etapas do método guloso, os tubos do catálogo com classe para
ela. São até três passadas para cada zona e para a linha principal, e a racionalização e a análise
final seguem a última. Quando nenhum candidato do catálogo tem classe suficiente, a unidade fica com
todos os candidatos e a análise informa `pressure_rating_exceeded`. A exigência é a pressão
permanente; o golpe (seção 13.1) e os transientes (seção 14) são verificados depois contra a mesma
classe reduzida (testes "a 95 m supply never gets PN 80 PVC", para o LP e o método guloso, e
"nothing in the catalogue withstands the pressure: sized as before and warned").

---

## 16. Linha principal, turnos e fontes

### 16.1 Turnos e fontes

- **Turnos** (system flows): conjuntos de válvulas de zona, pivôs e estações valve-in-head que
  operam juntos, com hora de início e duração. Sem turnos definidos, supõe-se que todos operam juntos
  (o pior caso para a linha principal e a fonte).
- **Turnos automáticos** (`management.dart`): a demanda de cada zona (a vazão de projeto, ou a vazão
  nominal dos emissores na pressão nominal), de cada pivô (a vazão da máquina) e de cada estação
  valve-in-head (os seus aspersores na pressão nominal) é empacotada por first-fit decrescente no
  menor número de turnos cujo total fica dentro da vazão máxima (por padrão a vazão de projeto das
  fontes) e, opcionalmente, de um número máximo de zonas; uma demanda maior que o limite ganha um
  turno só dela e é reportada. Os turnos funcionam um depois do outro. A seção 17.4 os agrupa pela
  menor energia.
- **Demandas**: para cada válvula, a vazão da zona e a pressão requerida a montante; para cada pivô,
  a vazão e a pressão de entrada da máquina (o pacote de aspersores da seção 22.1 pode pedir mais que
  a hidráulica simples da máquina); para cada estação valve-in-head programada, os seus aspersores
  (seção 16.2).
- **LP da linha principal**: as mesmas variáveis de fração por diâmetro, com uma restrição de pressão
  requerida em cada válvula em cada turno, e custo de energia ponderado pelas horas de cada turno
  sobre as horas anuais. Fontes de pressão fixa entram como constantes; fontes calculadas têm a
  carga como variável.
- **Análise por turno**: rede completa da linha principal com bombas (ponto de operação, ou a
  rotação que um inversor ajusta nesse turno, seção 12.2), PRVs, PSVs, válvulas controladoras de
  vazão, retenções, acessórios e as demandas; resultado por fonte (duty: vazão, pressão disponível,
  requerida, déficit, cota), por válvula (disponível versus requerida), por estação valve-in-head e
  por tubo; energia anual, com a curva de rendimento de cada bomba.
- **Fontes calculadas e bombas**: a pressão requerida de uma fonte calculada é o déficit da pior
  válvula com a fonte a pressão zero, ou seja, depois da carga que as bombas do turno acrescentam
  na sua vazão de operação. Quando esse déficit é negativo as bombas (ou a cota) já cobrem a
  necessidade: a análise mantém a fonte em zero, reporta a pressão requerida como zero com a sobra
  ao lado, e o excesso aparece ao longo da linha principal e nas válvulas. Uma bomba é julgada,
  portanto, pelo seu duty (carga requerida mais a carga que ela acrescenta) e pela sobra, não pelas
  pressões das válvulas, que o projeto sempre atende.
- **Malhas**: numa linha principal malhada os diâmetros decidem como a vazão se divide, e o LP,
  escrito sobre as vazões da etapa de velocidade, usa caminhos em árvore (mensagem
  `lp_loops_approx`). Depois do primeiro LP a rede é analisada com os novos diâmetros e o LP é
  resolvido de novo com as vazões redistribuídas, até mais quatro vezes, até a escolha de diâmetros
  se estabilizar: a ideia do gradiente de Alperovits & Shamir (1977) com este LP em cada passo. A
  análise final confere as pressões; o teste "looped mainline sizing with LP adds the approximation
  note and still converges" garante o comportamento.

### 16.2 Estações valve-in-head

Um aspersor desenhado na linha principal tem a válvula no próprio corpo, o aspersor com válvula
incorporada (valve-in-head) da interface (`valve_in_head.dart`). A
estação é a unidade que os turnos programam e que o controlador aciona: um aspersor sem nome de zona
é uma estação sozinho (o seu id), aspersores com o mesmo nome de zona formam a estação `vih:<nome>`,
com os solenoides em paralelo numa só estação. Um turno programa uma estação listando-a ao lado das
suas válvulas de zona e pivôs:

- uma estação que algum turno lista funciona **só** nos turnos que a listam, e o dimensionamento dá
  aos seus aspersores a pressão nominal ali, como dá a uma válvula de zona a pressão de que a zona
  precisa: a necessidade no nó da linha principal de cada aspersor é a sua pressão nominal mais a
  haste, e o aspersor crítico da estação entra no déficit da fonte e no dimensionamento da linha
  principal;
- uma estação que nenhum turno lista funciona em **todos** os turnos sem influir na pressão da fonte,
  como as saídas da linha principal se comportavam antes de poderem ser programadas, de modo que os
  projetos que nunca as programaram mantêm os seus resultados (teste "flows that list no
  valve-in-head station give the results of before");
- no LP da linha principal os aspersores de uma estação programada têm o limite inferior
  max(mínimo da janela, pressão nominal) nos turnos em que funcionam; os não programados mantêm a sua
  janela de pressão em todos os turnos;
- nas análises que dimensionam os tubos (fontes calculadas a pressão zero) um aspersor programado
  retira a sua vazão nominal como demanda fixa, como uma válvula de zona retira a vazão da sua zona;
  nas análises finais os aspersores são emissores dependentes da pressão, cuja vazão cresce com a
  pressão da fonte enquanto as perdas crescem com a vazão deles, então a pressão das fontes
  calculadas é elevada a partir da primeira estimativa até o pior aspersor receber o que precisa (no
  máximo 30 rodadas, até 1 mm);
- um aspersor desligado num turno mantém o seu nó sem emissor funcionando, de modo que todos os turnos
  têm os mesmos nós e trechos.

Os resultados trazem um duty por estação e turno (`VihDuty`: aspersores, vazão, menor e maior
pressão nos bocais contra a janela, o aspersor crítico e a sua necessidade) na aba de relatório
"Aspersores com válvula", com as mensagens `vih_not_in_flow` (uma estação que nenhum turno lista
enquanto o projeto tem turnos), `vih_pressure_deficit` e `vih_pressure_high`. As estações passam por
todas as outras análises com a sua programação: a altura estática para a seleção da bomba conta o
pior aspersor das estações programadas, a simulação de 24 horas liga os aspersores nas janelas dos
seus turnos, os transientes os fecham com as válvulas de zona do turno, a programação pela tarifa e
o agrupamento por energia os tomam como demandas, a fiação dá a cada estação uma estação de um
controlador (seção 18.1), o programa do controlador e a fertirrigação usam as áreas irrigadas dos
seus aspersores, e a exportação para o EPANET de um turno grava como emissores os aspersores das
estações que ele aciona. Testes em `valve_in_head_test.dart`, entre eles "heads run only in the flows
that schedule them, the worst at its nominal pressure".

---

## 17. Análises de operação

Um projeto dimensionado é um regime permanente por turno. As análises desta seção olham o sistema em
operação: ao longo de um dia, sob uma tarifa, com os agricultores abrindo hidrantes quando querem,
com a energia como objetivo, com um tubo fora de serviço, contra leituras de campo e enquanto um
fertilizante percorre a rede. Elas trabalham sobre a linha principal exatamente como o
dimensionamento a resolve para um conjunto de válvulas (`Designer.mainlineNetworkFor`), e
`network_ops.dart` as liga ao projeto para os diálogos; o que propõem (horas de início, turnos, rotas
de fio, uma escala de C) volta como valores que o usuário aplica num único passo de desfazer.

### 17.1 Um dia de operação

Módulo `eps.dart`, uma simulação de período estendido que segue o avanço no tempo do EPANET (Rossman
2000; algoritmos de análise do EPANET 2.2): cada passo hidráulico resolve a rede com os
reservatórios de nível variável como cargas fixas nos seus níveis atuais e depois integra os seus
volumes no passo, por Euler explícito com as vazões do início do passo (como o EPANET) ou pelo
preditor-corretor de Heun (uma segunda solução no fim do passo, de segunda ordem). O passo é
encurtado no próximo evento de horário, de padrão ou de controle, quando um reservatório encheria ou
esvaziaria e quando um reservatório atinge o nível de um controle; um reservatório cheio fecha os
trechos que o fariam transbordar e um vazio os que o esvaziariam. Multiplicadores de demanda e de
emissores seguem padrões no tempo, horários de trechos abrem as válvulas de zona na hora de início
pela sua duração, horários de demanda ligam as demandas de nós da linha principal (uma zona vista da
linha principal), e controles simples acionam trechos por um nível de reservatório, num instante ou
numa hora do relógio. A energia de cada bomba é ∫ρ·g·Q·H/η dt, e o seu custo, o preço de uma função
de tarifa da hora. Cada solução parte das vazões da anterior, sobre uma cópia da rede (testes "a tank
filled at constant inflow reaches the analytic level", "a tank draining through a pipe follows the
analytic curve with a small step", "pump energy and its cost match the hand calculation").

`simulateDay` (`transient_analysis.dart`) roda os turnos de um projeto ao longo de um dia nas suas
horas de início e durações, cada janela tomada módulo 24 h e dividida na meia-noite. Uma só rede
guarda a demanda de cada válvula de zona e pivô, ligada nas janelas dos turnos a que pertence; o que
difere entre os turnos é replicado e programado: uma fonte cuja pressão o dimensionamento calcula por
turno vira uma fonte por pressão atrás de uma retenção (a mais alta alimenta quando os turnos se
sobrepõem), e uma bomba cujo inversor gira em rotações diferentes em turnos diferentes, uma bomba
por rotação (a mais rápida dos turnos em funcionamento opera). Cada bomba fica ligada enquanto um dos
turnos que ela atende funciona, e uma fonte calculada conta como uma bomba que dá a sua pressão, como
na energia do dimensionamento; os aspersores de uma estação valve-in-head funcionam nas janelas dos
turnos que acionam a estação. O passo hidráulico é de no máximo uma hora e é cortado onde um turno
começa ou termina. O resultado é a série de cada passo, o resumo por hora e a energia e o seu custo ao
preço dos parâmetros, com uma faixa de ponta opcional (18 a 21 h por padrão, com multiplicador 1, uma
tarifa plana) (testes "the energy and its cost match the hand calculation", "flows across midnight
and overlapping flows").

### 17.2 Programação pela tarifa

Módulo `tariff.dart`. Uma tarifa é um conjunto de estações do ano (meses), cada uma com preços de
energia por faixa do dia, demandas (encargos mensais por kW da maior potência retirada a qualquer
hora e nas faixas de ponta, um dia levando 1/30 deles) e um **desconto da irrigação** opcional numa
janela diária escolhida pelo consumidor. A regra brasileira (Portaria Normativa MME nº 137, de 8 de
junho de 2026) é o padrão: até 8 h 30 min por dia, contínuas ou em até três blocos de meias horas
inteiras, nunca entre 17:00 e 21:30, possivelmente diferentes por estação, com os descontos da
Resolução Normativa ANEEL nº 1.000/2021, art. 186, sobre a tarifa de consumo (energia):

| Grupo do consumidor | Nordeste e área da SUDENE | Norte, Centro-Oeste e demais municípios de Minas Gerais | Demais regiões |
|---|---|---|---|
| A (média e alta tensão) | 90 % | 80 % | 70 % |
| B (baixa tensão) | 73 % | 67 % | 60 % |

As tarefas são os turnos do projeto, cada um com a sua duração diária e a sua potência elétrica (a
potência de eixo das fontes calculadas na sua carga requerida, com o rendimento de bomba dos
parâmetros, mais a das bombas com o rendimento próprio, sobre o rendimento do motor), precedências e
um limite diário de horas de bombeamento. O programador escolhe as horas de início e os blocos de
desconto que minimizam o custo diário:

- os turnos funcionam um de cada vez (a rede é dimensionada para um turno de cada vez) e todos os dias
  igual, dentro de um dia de programação que começa no fim do intervalo excluído (21:30) salvo
  indicação em contrário; nenhuma tarefa atravessa esse instante;
- o dia é cortado em passos de 15 min: os inícios caem em passos e as durações são arredondadas para
  cima a passos inteiros no empacotamento, enquanto os custos usam os minutos exatos; o desconto é
  decidido por meia hora;
- para uma ordem dada das tarefas, uma programação dinâmica sobre os passos, cujo estado é a tarefa em
  funcionamento (e quanto dela já correu), as meias horas com desconto usadas, os blocos abertos, se a
  meia hora atual tem desconto e (quando um bloco pode atravessar o início do dia) se a primeira
  tinha, acha as horas de início e os blocos juntos, de forma exata;
- quando as precedências deixam poucas ordens (24 por padrão) todas são resolvidas e a programação é
  ótima para o modelo. Com mais tarefas o método é uma heurística documentada: parte das ordens dada,
  decrescente e crescente por potência e, até 8 tarefas, da melhor ordem para uma janela de todo o
  desconto em cada lugar em que ela cabe; a partir de cada uma alterna (a) a melhor ordem para os
  blocos do plano atual — exata sobre todas as ordens por uma programação dinâmica sobre subconjuntos
  de tarefas até 12 tarefas, trocas de pares e inserções acima disso — e (b) a programação conjunta
  exata para essa ordem, enquanto o custo cai, e guarda o melhor plano;
- uma demanda de ponta sobre a maior potência retirada nas faixas de ponta é tratada de forma exata
  resolvendo uma vez por limite de potência permitida na ponta.

Tudo é determinístico; o plano é comparado com as tarefas nas suas horas de início atuais (testes
"exact against a brute force over every start and block choice", "the Brazilian discounts and
rule", "peak demand charge: the small job takes the peak").

### 17.3 Redes a demanda

Módulo `on_demand.dart`, segundo o Boletim de Irrigação e Drenagem 59 da FAO (Lamaddalena & Sagardoy
2000, *Performance analysis of on-demand pressurized irrigation systems*). Numa rede coletiva em que
cada agricultor abre um hidrante quando quer, a vazão de projeto de um trecho vem da **primeira
fórmula de Clément** (Clément 1966): cada hidrante i está aberto com probabilidade p_i,
independentemente dos outros, e a vazão de um trecho que atende os hidrantes a jusante dele, não
excedida com a qualidade de funcionamento Pq, é

Q = Σ p_i·d_i + U(Pq)·√(Σ p_i·(1 − p_i)·d_i²)   (FAO 59 eq. 12),

com d_i a vazão nominal e U(Pq) a variável normal padrão (1,645 para 95 %; calculada exatamente pelo
algoritmo AS 241 de Wichura quando não informada). p_i = t_i/T', t_i as horas que o hidrante i
precisa ficar aberto por dia do período de pico e T' = r·24 h o tempo de funcionamento da rede (r o
coeficiente de utilização), ou p_i = q_s·A_i/(r·d_i) a partir da vazão contínua específica q_s e da
área do lote A_i. Nas extremidades as vazões são somadas: um trecho que atende N_min hidrantes ou
menos leva todos eles, nenhum trecho leva menos que os seus N_min maiores hidrantes (N_min = 4, como
no Box 1 do FAO 59), um trecho nunca leva menos que um a jusante dele, e com hidrantes iguais o
número de abertos é arredondado para cima. As malhas são informadas e deixadas de fora (a fórmula
precisa de uma árvore).

**Exemplo** (FAO 59, Box 1 e Tabela 2): 19 hidrantes de 10 L/s atendendo 3 ha cada um, q_s = 0,327
L/s por ha, r = 0,667: p = 0,327·3/(0,667·10) = 0,147; na cabeça da rede Σp·d = 27,9 L/s,
σ = 15,4 L/s e Q = 27,9 + 1,645·15,4 = 53,3 L/s, 5,33 hidrantes, arredondados para 6: 60 L/s; todos os
trechos da tabela são reproduzidos (teste "FAO 59 Box 1 / Table 2: every section").

A **verificação aleatória** (FAO 59, capítulo 5) resolve C configurações de hidrantes abertos ao
mesmo tempo com o solver de rede (C = o maior entre 200 e o número de hidrantes mais um): um hidrante
aberto j da configuração r está satisfeito quando a sua carga de pressão H_j,r ≥ H_min; por hidrante
são informados o déficit relativo de pressão ΔH_j,r = (H_j,r − H_min)/H_min (eq. 52) e a
confiabilidade α_j = Σ_r Ih_j,r·Ip_j,r / Σ_r Ih_j,r (eq. 54, a fração das configurações com o
hidrante aberto em que ele está satisfeito), e por configuração a fração de hidrantes insatisfeitos.
Com uma vazão a montante Q as configurações vêm do modelo de geração aleatória do capítulo 3 do
FAO 59: hidrantes sorteados uniformemente ao acaso, sem reposição, até |Q_conf − Q| < ε, ε a menor
vazão de hidrante (Bethery et al. 1981); sem ela, cada hidrante abre independentemente com a sua
probabilidade. Os sorteios vêm de um gerador recursivo múltiplo combinado MRG32k3a com semente
(L'Ecuyer 1999), exato em dupla precisão, de modo que uma verificação é reproduzível em qualquer
plataforma; os quantis são lineares entre estatísticas de ordem (Hyndman & Fan 1996, definição 7).
Os hidrantes têm limitadores de vazão: o FAO 59 supõe que todo hidrante aberto retira a sua vazão
nominal qualquer que seja a pressão, o que uma solução por demanda dá diretamente; opcionalmente um
hidrante abaixo de H_min entrega como um orifício, pela solução dirigida pela pressão da seção 17.5.

### 17.4 Agrupamento das zonas por energia

Módulo `energy_grouping.dart`. A bomba de um turno precisa entregar a maior carga de que qualquer uma
das suas zonas precisa, então as zonas que precisam de menos recebem mais pressão do que usam:
agrupar zonas com cargas requeridas parecidas economiza energia. É o problema de setorização de
Jiménez-Bello, Martínez Alzamora, Bou Soler & Bartolín Ayala (2010) e de Carrillo Cobo, Rodríguez
Díaz, Montesinos, López Luque & Camacho Poyato (2011), que buscam com um algoritmo genético e um
modelo da rede.

Modelo: a zona i retira q_i por t_i horas e precisa da carga de pressão h_i na sua válvula, cujo nó
fica na cota z_i. Um grupo bombeia Q = Σ q_i do nível da fonte z_s e precisa entregar
H = max_i (z_i + h_i + k_i·Q^m) − z_s, sendo k_i·Q^m a perda da bomba até a válvula i (m = 1,852; a
vazão do grupo inteira tomada ao longo do caminho, exata para um tubo único e a favor da segurança
numa linha principal ramificada); a bomba mantém H enquanto alguma zona do grupo está aberta, então
o grupo usa E = ρ·g·H·Σ q_i·t_i/η. Método: (1) first-fit decrescente pela vazão, a referência da
seção 16.1; (2) as zonas ordenadas pela carga piezométrica requerida e cortadas em grupos
consecutivos por uma programação dinâmica sobre (zonas colocadas, grupos usados), cada grupo dentro
do limite de vazão e do número de zonas por grupo, para cada número de grupos permitido, guardando o
mais barato dentro das horas diárias; (3) a partir do melhor dos dois, mudanças de uma zona para outro
grupo (ou um novo) e trocas de duas zonas enquanto alguma reduz a energia dentro de todos os limites;
depois, uma segunda busca local com a carga de cada grupo calculada exatamente pelo dimensionador (a
linha principal resolvida para aquele conjunto de válvulas, no máximo 200 chamadas). As estações
valve-in-head entram no nó do seu aspersor mais exigente, os pivôs no seu nó da linha principal.
Determinístico (teste "zones of similar head together: 30 % less energy than first fit by flow").

### 17.5 Criticidade

Módulo `criticality.dart`: análise N−1. Cada tubo (ou cada trecho escolhido) é fechado por sua vez e,
por cenário, são informados a demanda isolada de todas as fontes, a demanda que as pressões restantes
não conseguem entregar e os déficits de pressão nos nós de demanda (numa linha principal, cada
válvula ou pivô do turno precisando da carga do seu projeto). Numa rede alimentada por uma só fonte
através de uma árvore, fechar um tubo isola tudo a jusante dele e as pressões do resto não podem
cair (menos vazão, perdas menores, uma curva de bomba decrescente dá mais carga), então a perda é
informada sem solução; nos demais casos a parte ainda ligada a uma fonte é resolvida de novo.

A demanda não entregue vem de uma **solução dirigida pela pressão** (Wagner, Shamir & Marks 1988, com
pressão mínima nula): uma demanda d é entregue inteira enquanto a carga de pressão atinge a
requerida, e abaixo dela como um orifício, q = d·√(p/p_req), parando em p ≤ 0. O solver não tem saída
com vazão limitada, então os dois regimes são um conjunto ativo: cada nó começa com a sua demanda
inteira como demanda fixa; um nó abaixo da sua pressão requerida vira um emissor q = (d/√p_req)·p^0,5
na solução seguinte, e um nó emissor que sobe acima da exigência volta à demanda fixa; passar um nó
ao regime de orifício só reduz as vazões e aumenta as pressões, então o conjunto se estabiliza em
poucas rodadas (no máximo 12). Uma curva íngreme de acessório em série com um orifício também
limitaria a vazão, mas o método do gradiente reduz uma vazão superestimada por uma lei h ∝ Q^n só por
um fator (1 − 1/n) por iteração e mantém o limite só de forma aproximada (testes "pressure-driven
demand: full above the requirement, orifice below", "tree: closing a pipe cuts off what is
downstream, without a solution", "loop: the other way round keeps the nodes connected, at a lower
pressure").

### 17.6 Calibração da rugosidade

Módulo `calibration.dart`. Uma escala do C de Hazen-Williams por grupo de tubos (um fator global, ou
um por material: os materiais com mais comprimento ganham um grupo cada e os demais dividem o último)
é ajustada a pressões e vazões medidas por mínimos quadrados ponderados, com o solver de rede no laço.
Cada resíduo é (modelo − medido)/σ, sendo σ o erro padrão da leitura (0,5 m para uma pressão por
padrão; 2 % de uma vazão, no mínimo 0,1 L/s), e o objetivo é a soma dos seus quadrados. Um fator é
achado por busca da razão áurea na faixa permitida, 0,3 a 1,5 (Kiefer 1953); mais fatores, por
Levenberg–Marquardt (Levenberg 1944; Marquardt 1963) com jacobiano por diferenças progressivas, a
escala de Marquardt no amortecimento e os fatores mantidos dentro da faixa. Os erros padrão
aproximados vêm de s²·(JᵀJ)⁻¹ na solução. Num projeto as leituras são feitas nos pontos de medição da
linha principal de um turno (uma válvula de zona ou pivô, uma fonte, uma junção, o lado de montante
de um acessório) e nas vazões que saem das fontes; uma pressão lida numa fonte é a carga que a rede
recebe, uma condição de contorno e não um resíduo. O fator encontrado vira a escala de C dos
parâmetros do projeto (testes "one global factor: golden section recovers C = 120 from a pipe built
with 150", "two groups in series: Levenberg–Marquardt recovers both factors", "flows split between
parallel pipes tell their roughness apart").

### 17.7 Fertirrigação

Módulo `fertigation.dart`. Os tempos de percurso são de escoamento em pistão ao longo das vazões
permanentes: atravessar um tubo leva o seu volume sobre a sua vazão, V/|Q| (acessórios e bombas não
guardam volume). O produto aparece num nó primeiro depois do caminho mais rápido a partir do ponto de
injeção (Dijkstra 1959) e o nó recebe a concentração plena quando o caminho mais lento também chegou
(o caminho mais longo sobre as direções das vazões, que formam um grafo acíclico numa solução
permanente). Para o produto sair de todos os tubos, a injeção precisa parar pelo menos a chegada mais
lenta à saída mais distante antes do fim da irrigação. O programa divide a irrigação em pré-molhamento,
injeção e lavagem (um quarto, metade e um quarto por padrão, a regra prática comum; Burt, O'Connor &
Ruehr 1995), a lavagem nunca mais curta que esse tempo de percurso; a massa de produto é a dose por
hectare vezes a área sobre a fração do nutriente no produto (0,46 para o N da ureia), a solução
estoque é essa massa sobre a sua concentração, a taxa de injeção é o volume de estoque sobre o tempo
de injeção e a concentração na água de irrigação é a massa sobre a água injetada com ela. Num projeto o
produto é injetado numa fonte ou numa bomba da linha principal, percorre a linha principal até cada
válvula e pivô do turno e depois cada zona a partir da sua válvula (os resultados de zona de um
dimensionamento detalhado). Um **venturi** num desvio em torno de um regulador, filtro ou válvula
funciona quando a perda desse acessório dá o diferencial de que a sua curva de sucção precisa, ou,
sem curva, pelo menos 20 % da pressão de entrada (uma regra prática comum para o início da sucção)
(testes "one pipe: travel time is volume over flow", "two paths: first appearance by the fast one,
full concentration by the slow one", "plan: quarters of the irrigation, amounts by hand").

---

## 18. Lavagem, conexões, fiação e lista de materiais

- **Lavagem** (`analyzeFlushing`): cada fita recebe na ponta a vazão que produz a velocidade de
  lavagem (0,3 m/s por padrão) e a zona é resolvida de novo; acha-se a pressão de válvula que mantém a
  pressão mínima na ponta (1 m) e reporta-se a vazão de lavagem, as pressões e a velocidade máxima. É
  a etapa mais pesada do cálculo em zonas com muitas fitas.
- **Conexões** (`fittings.dart`): a partir do grafo já dimensionado, luvas por barra de tubo (6 m),
  cotovelos de 90° e 45° e tês e cruzetas pela geometria dos nós, reduções onde o diâmetro muda,
  tampões nas pontas, derivações de lateral, finais de fita e hastes de emissores; cada uma procura o
  item do catálogo do tipo e diâmetro (ou o nome genérico quando não há).
- **Lista de materiais** (`buildBom`): tubos por diâmetro e classe, emissores, fitas, válvulas,
  acessórios, bombas selecionadas (com horímetro no painel quando pedido), pivôs (máquina, torres,
  aspersores, reguladores e, do pacote de aspersores, canhão final, bomba auxiliar, braço de canto e
  os cabos dos vãos e de alimentação), conexões e os itens elétricos (fios por bitola, controladores
  com os seus sensores e acessórios, dois conectores à prova d'água por solenoide), com custos
  unitários, total, custo anualizado (CRF) e energia anual. As mesmas linhas também são separadas
  pelo lugar onde ficam instaladas (cada zona, a linha principal, cada pivô, a parte elétrica), e os
  materiais de uma seleção do desenho podem ser listados sozinhos (um trecho da obra, um pedido:
  tubos por metro e itens por unidade aos preços do catálogo, sem as conexões, que pertencem às
  junções entre os itens). Os itens credenciados no FINAME do BNDES mostram o seu código.

### 18.1 Fiação das válvulas

Módulo `electrical.dart`, fiação convencional de solenoides de 24 V CA: cada válvula tem um condutor
de estação vindo do controlador e todas compartilham um condutor comum (retorno) lançado pelas
mesmas rotas. As rotas de fio formam um grafo (vértices dentro da tolerância de conexão se fundem; um
controlador ou uma válvula sobre um vértice ou sobre uma rota vira nó, dividindo a rota ali); o
caminho mínimo (Dijkstra) a partir de cada controlador alcança as válvulas, cada válvula vai para o
controlador mais próximo e as estações são numeradas pela distância.

Enquanto a válvula *v* abre ela puxa a corrente de partida I_in; as outras válvulas do seu turno já
estão ligadas e puxam a corrente de retenção I_h. A tensão no solenoide é

  U_v = U_c − I_in · r_s · L_v − Σ_{e ∈ caminho(v)} I_e · r_c · ℓ_e,

onde U_c é a saída do controlador, r_s e r_c a resistência por metro dos condutores de estação e
comum, L_v o comprimento da rota até *v* e, para cada trecho *e* do comum no caminho, ℓ_e o seu
comprimento e I_e a corrente das válvulas do turno além dele (I_in para *v*, I_h para as outras). Os
comprimentos incluem a folga (10 % por padrão). O projeto escolhe, para cada controlador, a bitola do
comum e a bitola de estação de cada válvula com o **menor custo** tal que U_v ≥ U_min (20 V por
padrão) para toda válvula em todo turno a que pertence: para cada comum candidato, cada válvula
pega o fio de estação mais barato que mantém a sua tensão (as tensões não dependem dos fios de
estação das outras válvulas), e vence a combinação viável mais barata. Quando nenhum fio atende uma
válvula, fica o mais grosso e a válvula é reportada. Exemplo (conferido nos testes): rotas de 50,
150 e 200 m com cobre de 1 mm² (18,1 Ω/km), três válvulas de um turno, 0,37 A de partida e 0,22 A
de retenção, 10 % de folga: a válvula mais distante recebe 24 − 1,47 − 2,13 ≈ 20,4 V.

- As **estações valve-in-head** são estações como as válvulas de zona, depois das válvulas de zona do
  seu controlador (o que alcança mais dos seus aspersores), com os solenoides dos aspersores em
  paralelo: o condutor de estação segue as rotas do controlador até cada aspersor (a união dos seus
  caminhos) e em cada trecho leva a corrente de partida de todos os aspersores além dele, como o
  comum leva; a tensão é calculada em cada aspersor e a estação fica com a menor. Um aspersor que
  nenhuma rota alcança é informado como sem fiação, os outros aspersores da estação ainda ligados.
- As **válvulas mestras** da linha principal são acionadas pela saída de válvula mestra do
  controlador (estação 0): ficam ligadas, em retenção, com cada grupo de zonas do seu controlador.
- A contagem de estações de um controlador inclui as suas estações valve-in-head; mais válvulas que
  estações gera `elec_stations`, mais válvulas ligadas ao mesmo tempo do que o controlador permite
  `elec_simultaneous`.

### 18.2 Rotas automáticas dos fios

Módulo `wire_routing.dart`: os fios são lançados pelas valas dos tubos. Os tubos da linha principal e
de zona (nunca as laterais e as fitas) viram um grafo: vértices dentro da tolerância (0,1 m) são um nó,
e um tubo que termina sobre outro ou o cruza se une a ele ali. Cada controlador, válvula de zona,
válvula mestra e relé de partida de bomba é ligado no ponto mais próximo de um tubo, por um pequeno
ramal quando está fora dos tubos (ramais acima de 30 m são informados); cada válvula vai para o
controlador mais próximo pelas valas, e as rotas de cada controlador formam uma árvore:

- **caminhos mínimos** (o padrão na fiação convencional, em que cada válvula tem o seu condutor de
  estação): a união dos caminhos mínimos do controlador até as suas válvulas, uma árvore de caminhos
  mínimos (Dijkstra 1959), de modo que cada condutor de estação é tão curto quanto as valas permitem;
- **Steiner** (para um caminho de dois fios, em que só o comprimento da rota conta): a heurística de
  caminhos mínimos para a árvore de Steiner em grafos (Takahashi & Matsuyama 1980): a árvore cresce a
  partir do controlador pelo caminho mínimo até a válvula mais próxima ainda fora dela, no máximo o
  dobro do comprimento ótimo.

As árvores voltam como polilinhas que compartilham os vértices das pontas, com as válvulas nos seus
vértices, de modo que os projetos de fiação das seções 18.1 e 18.3 as conectam. A válvula mestra e o
relé de partida da bomba recebem estações depois das válvulas de zona (ou os terminais dedicados do
controlador); todos os aspersores de uma estação valve-in-head vão para um controlador (o mais
próximo da maioria deles) e recebem uma estação (testes "shortest paths along the trenches, stations
by distance", "a Steiner-like tree for a two-wire path is shorter than the shortest paths").

### 18.3 Sistemas de dois fios

Módulo `two_wire.dart`. Um par de condutores sai do controlador e corre pelas rotas passando por cada
válvula; um decodificador emendado no par numa válvula aciona os solenoides de 1, 2, 4 ou 6
estações, as válvulas ao alcance de um cabo de solenoide a partir dele (30 m pelas rotas). O par
sempre leva a corrente de repouso de cada decodificador e, enquanto estações funcionam, as correntes
dos seus solenoides. Os dois condutores levam a corrente, então a queda num trecho do caminho é
ΔU = I·2·R'·L, com I a corrente de tudo o que está além do trecho (lei de Ohm em volta do laço) e L o
comprimento do cabo (rota mais folga). Para cada controlador o projeto escolhe o fio mais barato da
lista (o mais fino num empate) que mantém cada decodificador com uma estação em funcionamento na
tensão mínima ou acima dela enquanto cada estação de um turno abre (partida) com as outras estações
do turno em retenção; válvulas fora de qualquer turno funcionam sozinhas, e sem turnos todas as
válvulas funcionam juntas, como no projeto hidráulico. Como as quedas crescem com o comprimento, a
maior distância que um fio permite é o traçado escalado até o pior decodificador atingir o mínimo.
Os valores padrão são ordens de grandeza, a substituir pelas fichas técnicas: 34 V no caminho, pelo
menos 24 V num decodificador, 1 mA de corrente de repouso por decodificador, e as correntes dos
solenoides dos parâmetros do projeto tomadas na linha (a favor da segurança: um decodificador
converte a energia da linha e consome menos na tensão mais alta). Aterramento: um supressor de surto
com haste de aterramento no controlador, depois a cada 12 decodificadores ou 150 m de caminho, o que
vier primeiro, e em cada ponta do caminho, uma regra prática dos guias de instalação, configurável.
Os aspersores de uma estação valve-in-head são pontos do caminho como as válvulas de zona, com
decodificadores nos aspersores como a prática do dois fios os coloca em gramados; uma saída de
decodificador aciona até dois solenoides de uma estação em paralelo, e quando uma estação abre a
partida de todos os seus aspersores carrega o par de uma vez (testes "voltage along the pair by
hand, the cheapest wire that keeps 24 V", "grounding points: every 150 m or 12 decoders, the
controller and the ends").

### 18.4 Orçamento e economia

Módulo `proposal.dart`. O orçamento põe preço na lista de materiais com uma margem de venda, soma a
mão de obra (uma fração do custo dos materiais), a escavação das valas, linhas livres (serviços,
deslocamento, comissionamento), um desconto, impostos sobre o subtotal com desconto e o frete. As
valas dos tubos enterrados são agrupadas por uso e diâmetro: largura conforme o ajuste, ou o diâmetro
externo mais 0,2 m (no mínimo 0,3 m); profundidade a do eixo do tubo mais meio diâmetro mais o berço.
As linhas sem preço são contadas e informadas.

O **retorno** de um investimento I que dá um benefício anual B enquanto custa C (energia) para
funcionar, em n anos à taxa de desconto r: payback simples I/(B − C); valor presente líquido
VPL = −I + Σ_{a=1..n} (B − C)/(1 + r)^a; taxa interna de retorno a r que zera o VPL, por bissecção
(nenhuma quando o líquido anual não é positivo). O **cronograma da obra** lista as tarefas com trabalho
a fazer (locação, escavação das valas, assentamento dos tubos, reaterro, válvulas e acessórios,
fiação, laterais e fitas, emissores, estação de bombeamento e filtragem, teste de pressão e lavagem),
cada uma durando a sua quantidade sobre a produção de uma equipe por dia útil (números típicos de
uma equipe pequena com valetadeira, que o projeto pode mudar) dividida entre as equipes, cada uma
começando quando o trabalho de que depende começou (valas, tubos e reaterro com um dia de diferença;
válvulas, fiação, laterais e emissores depois de assentados os tubos enterrados; a estação de
bombeamento em paralelo; o teste no fim). Para projetos brasileiros o relatório dá a categoria do
licenciamento ambiental da Resolução CONAMA 284/2001 (anexo) pela área irrigada e pelo método, só
informativa (aspersão: abaixo de 100 ha A, até 1 000 ha B, acima C; microirrigação: 500 e 1 000 ha;
superfície: 50 e 100 ha), porque a vigência da resolução e as regras de cada órgão estadual precisam
ser verificadas.

---

## 19. Traçado automático

As ferramentas de projeto automático desenham o que um projetista colocaria item por item:
aspersores num gramado, zonas por vazão, válvulas e tubos, blocos de laterais num talhão, anéis em
volta de árvores, traçados esportivos e de golfe e o pivô que cabe numa área. Elas produzem entidades
comuns, que o projetista dimensiona e analisa como qualquer desenho, e toda escolha desempata pelo
índice do item, de modo que a mesma entrada sempre dá o mesmo traçado.

### 19.1 Aspersores de paisagismo

Módulo `auto_layout.dart`, segundo a prática de projeto de paisagismo e de aspersão (Irrigation
Association, *Landscape Irrigation Best Management Practices*, 2014; Keller & Bliesner 1990,
capítulos 5 e 6; NRCS NEH 623 capítulo 11). A região irrigada é o contorno menos as suas exclusões
(edificações, canteiros, caminhos, que podem ficar dentro do contorno, cruzá-lo ou se sobrepor),
guardada como anéis fechados com a região à esquerda.

- **Espaçamento**: cabeça a cabeça (espaçamento = raio molhado), um percentual do diâmetro molhado
  (50 % é cabeça a cabeça; Keller & Bliesner 1990, tabela 5.2, pedem 50 a 65 % conforme o vento) ou
  digitado. O bocal de círculo completo de referência é um que vem com **setoriais equalizados** (um
  bocal de quarto e de meio círculo daquele arco com tolerância de 5°, alcançando quase o mesmo, dentro
  de 15 %, com a vazão da sua fração do arco, dentro de 20 %) e cujo raio não passa do que a parte
  mais larga da área permite (aspersores em bordas opostas lançam um no outro): o maior raio que
  cumpre isso, ou seja, o menor número de aspersores.
- **Posicionamento**: aspersores primeiro nos cantos (um vértice do contorno que gira mais de 25°; um
  canto mais agudo que 45° não tem aspersor próprio, os primeiros aspersores das suas duas bordas
  molham a ponta), depois ao longo de cada borda com no máximo o espaçamento, depois numa malha
  quadrada ou triangular no interior (fileiras ao longo da borda mais longa do contorno por padrão;
  uma malha triangular tem fileiras a 0,866 espaçamento uma da outra, as alternadas deslocadas meio
  espaçamento), afastada meio espaçamento das bordas. Uma faixa mais estreita que 0,6 espaçamento
  recebe uma fileira só de aspersores de borda; aspersores nunca ficam a menos de 0,4 espaçamento um
  do outro; uma exclusão pequena (perímetro abaixo de três espaçamentos: um anel de árvore, um
  canteiro pequeno) não recebe aspersores em volta, os aspersores ficam fora dela e lançam por cima.
- **Cobertura**: onde um ponto da área fica a mais de 0,72 espaçamento de todos os aspersores (o ponto
  mais distante de uma malha quadrada fica a 0,707, o de uma triangular a 0,577, cujo limite é 0,66) um
  aspersor é acrescentado, o maior círculo vazio primeiro: cada célula da grade perto do alcance ou
  além dele sobe até o ponto mais distante à sua volta, um vértice do diagrama de Voronoi dos
  aspersores. Depois, quatro rodadas de relaxação centroidal levam os aspersores interiores perto de
  bordas irregulares ao centroide das células mais próximas deles, quando isso os mantém dentro, longe
  do contorno e dos outros aspersores.
- **Arcos e bocais**: cada aspersor molha o setor que se abre para a área (anti-horário a partir da
  sua orientação, como o desenho e o densograma o traçam), e um setorial recebe o bocal cuja vazão é
  proporcional ao seu arco, q = q_completo·arco/360, para que todo aspersor aplique a mesma lâmina
  (precipitação equalizada): a vazão mais próxima em escala logarítmica, o raio não menor que 0,9 do de
  referência. `layout_mp_mismatch` informa um bocal que erra a sua vazão em mais de 15 %,
  `layout_radius_short` um que lança curto demais. Uma família sem setoriais equalizados
  (microaspersores, aspersores de impacto) recebe só círculos completos, numa malha recuada meio
  espaçamento.
- **Avaliação**: a uniformidade do resultado pelo modelo do densograma da seção 9.1 (CU de
  Christiansen, DU do quartil inferior, coeficiente de programação, fração seca) e a água lançada
  fora da área.

O maior círculo inscrito de uma região (usado aqui, nos modelos e no ajuste de pivô) é o seu polo de
inacessibilidade, achado pela busca em quadtree de Garcia-Castellanos & Lombardo (2007). Testes:
"rectangle: corners, edges and interior head to head, CU above 94 %", "L-shapes: both arms treated
alike, every point within reach, CU above 85 %", "a house in the lawn: three-quarter circles at its
corners, nothing inside, CU above 85 %", "quarter, half and full circles take the nozzles of their
share of the flow".

### 19.2 Zonas por vazão

Módulo `zoning.dart`: aspersores (ou áreas de gotejamento) são agrupados em zonas de válvula cuja
vazão fica dentro dos limites da válvula e da fonte, sem nunca misturar emissores que aplicam água em
intensidades diferentes, cada zona compacta e numa peça só e as zonas de uma classe com vazões
equilibradas (Irrigation Association 2014, prática "agrupar emissores de precipitação parecida";
Keller & Bliesner 1990, capítulo 17). As classes de precipitação são spray (um aspersor que lança
menos de 6,5 m), rotor, microaspersor, borbulhador, gotejamento e canhão. O agrupamento é um
crescimento de regiões com capacidade sobre um grafo de vizinhos mais próximos (8 vizinhos; itens
mais afastados que 2,5 distâncias típicas de vizinho não são vizinhos, de modo que gramados separados
ganham zonas separadas): tantas sementes quanto a vazão pede, espalhadas por amostragem do ponto mais
distante; a zona menos carregada pega, um de cada vez, o vizinho ainda sem zona mais próximo da sua
semente, parando na vazão média de zona da sua classe mais 10 % antes de as outras alcançarem; as
sementes vão para o meio das suas zonas e o crescimento se repete (três rodadas); zonas mais leves
que metade da média se fundem a uma vizinha quando as duas cabem; e uma última passada move itens de
borda das zonas mais pesadas para as vizinhas mais leves enquanto as duas continuam numa peça só
(testes "zones within the flow, contiguous, compact and balanced", "head types and precipitation
classes never share a zone; separate lawns get their own zones").

### 19.3 Válvulas e rotas dos tubos

Módulo `routing.dart`. Cada zona recebe uma válvula (numa linha principal dada, junto da zona do lado
do ponto de conexão, num manifold no ponto de conexão, ou onde o usuário a pôs; a menor válvula do
catálogo cuja faixa de vazão contém a vazão da zona) e tubos de zona que ligam cada aspersor a ela
como uma árvore; depois uma árvore de linha principal liga o ponto de conexão (fonte de água ou
bomba) a cada válvula. Os tubos são polilinhas com um vértice em cada aspersor, de modo que o
construtor da rede conecta cada aspersor; eles ficam a 0,3 m dos aspersores e das válvulas das
outras zonas (o que uniria duas zonas) e contornam edificações e outras exclusões pelo caminho mais
curto entre os cantos das exclusões afastados 0,5 m (um grafo de visibilidade).

As árvores das zonas usam o compromisso Prim–Dijkstra de Alpert, Hu, Huang, Kahng & Karger (1995):
cada aspersor se liga à árvore onde c·(comprimento do caminho a partir da válvula) + (comprimento do
tubo) é menor, c = 0 dando a árvore geradora mínima (o menor tubo) e c = 1 a árvore de caminhos
mínimos (o menor atrito até o aspersor mais distante); c = 0,25 mantém o tubo curto sem caminhos
serpenteantes longos. Os tubos candidatos vão de cada aspersor aos seus dez vizinhos mais próximos, e
um viés torna um tubo diagonal 15 % mais caro a 45° do que um ao longo ou através das fileiras, de
modo que as laterais seguem as fileiras, o traçado retilíneo da prática. A linha principal é uma
árvore de Steiner gulosa: a válvula mais próxima da árvore se liga a ela no ponto mais próximo de
qualquer um dos seus tubos, com um tê ali (Takahashi & Matsuyama 1980) (testes "every zone is a tree
from its valve with a vertex at every head", "pipes go round a building").

### 19.4 Talhões, blocos e anéis de árvores

- **Divisão de talhões** (`field_subdivision.dart`): um talhão agrícola é cortado em blocos de
  irrigação não maiores que uma área, ou que a vazão que um bloco pode retirar dada a vazão dos
  emissores por hectare, em faixas ao longo das fileiras ou numa grade que também limita o comprimento
  das laterais (o dobro com a linha de derivação no meio), com carreadores entre os blocos (4 m por padrão, que
  também mantêm afastadas as pontas das fitas de duas zonas) e uma largura mínima de bloco (10 m). Os
  cortes dão aos blocos áreas líquidas iguais: a área do talhão entre dois cortes é integrada
  exatamente, descontados os carreadores, e cada corte é posicionado por bissecção, de modo que os
  turnos retiram a mesma vazão (Keller & Bliesner 1990, capítulos 17 e 21; NRCS NEH 623 capítulo 7).
  Um talhão côncavo pode cair em várias peças por faixa. Cada bloco recebe o lado da sua linha de derivação (para
  o ponto de conexão, ou no meio) e a posição da sua válvula, pronto para o gerador de blocos (testes
  "strips of equal area within the limit, roads between them", "a grid keeps every lateral within the
  limit").
- **Anéis de árvores** (`tree_rings.dart`): em volta de cada árvore de uma grade de plantio dentro de
  uma área (espaçamento entre plantas × entre fileiras com deslocamentos, as árvores a um raio de anel
  do contorno) ou de posições levantadas (agrupadas em fileiras na direção das fileiras), um anel de
  tubo gotejador de um raio (0,6 m por padrão) ou um número de gotejadores num pequeno tubo em anel (4
  por padrão), ligado a uma lateral ao longo da fileira; as laterais partem de uma linha de derivação através das
  fileiras com a válvula da zona. Um anel de emissores em volta do tronco molha a zona radicular de uma
  árvore jovem de modo uniforme em todos os lados e longe do tronco (Keller & Bliesner 1990, capítulos
  15 e 16; NRCS NEH 623 capítulo 7). Cada anel é desenhado como duas metades do ponto onde a lateral
  entra nele ao ponto onde ela sai, ambos vértices da lateral, de modo que o construtor da rede o liga
  nas duas pontas (teste "every ring is joined to its lateral at both ends, round its tree").

### 19.5 Modelos esportivos e de golfe

Módulo `templates.dart`, segundo a prática de gramados esportivos e de campos de golfe (Keller &
Bliesner 1990, capítulo 5; Irrigation Association 2014; as recomendações da United States Golf
Association para o green e o seu colar). Cada modelo devolve os aspersores com os seus arcos e bocais
de precipitação equalizada para uma família de aspersores e a uniformidade sobre o gramado.

- **Campo de futebol** (105 × 68 m, o tamanho que a Regra 1 da IFAB recomenda para jogos
  internacionais): fileiras ao longo das linhas laterais, as duas de fora sobre as linhas laterais com
  meios círculos, quartos de círculo nos cantos e meios círculos nas linhas de fundo. Cinco fileiras
  ficam a 17,0 m uma da outra e precisam de um raio de pelo menos 17 m (com 18 m: 7 aspersores por
  fileira, a 17,5 m, 35 aspersores); quatro fileiras ficam a 22,7 m (R ≥ 23 m; com 24 m: 6 por
  fileira, a 21 m, 24 aspersores); três fileiras ficam a 34 m (R ≥ 34 m, rotores grandes ou canhões;
  com 35 m: 4 por fileira, a 35 m, 12 aspersores). Ao longo de uma fileira os aspersores ficam no
  máximo a um raio um do outro.
- **Campo interno de pista de atletismo**: a área dentro da guia de uma pista padrão de 400 m (raio
  da guia de 36,50 m, retas de 84,39 m) traçada como um gramado com fileiras ao longo das retas.
- **Green de golfe**: rotores num anel recuado fora do colar, no máximo a um raio um do outro, cada um
  um setorial que se abre sobre o green pelo ângulo que o green ocupa visto dele mais uma margem sobre
  o colar; nada dentro da superfície de putting.
- **Tee**: um retângulo traçado como gramado. **Fairway**: fileiras paralelas ao eixo a 0,866
  espaçamento uma da outra, aspersores a um espaçamento ao longo de cada uma, as fileiras alternadas
  deslocadas meio espaçamento (triângulos equiláteros, cabeça a cabeça); círculos completos, ou meios
  círculos em fileiras ao longo das duas bordas.

Testes "3, 4 or 5 rows: head to head, part circles on the lines, CU above 93 %", "golf green: rotors
outside the collar throwing onto the green, CU above 88 %".

### 19.6 Ajuste de pivô

Módulo `pivot_fit.dart`: o maior pivô central de círculo completo que cabe num talhão evitando os seus
obstáculos, e o pivô setorial (centro, raio e setor) que irriga a maior área dentro do talhão. O
comprimento da máquina é uma soma de vãos padrão (34,4, 41,8, 48,8, 54,9 e 62,2 m, isto é, de 113 a
204 pés; no máximo dois comprimentos de vão, os menos numerosos primeiro) mais um balanço (0 a
25,9 m), e o raio molhado é o comprimento da máquina mais o alcance do último aspersor ou do canhão
(Keller & Bliesner 1990, capítulo 14; NRCS NEH 623 capítulo 11). O círculo completo fica no centro do
maior círculo inscrito (o polo de inacessibilidade do talhão menos os seus obstáculos, obstáculos
pontuais como um poste com a sua folga) com a máquina mais longa cujo raio molhado cabe. Para um
setorial, dados um centro e um raio, o setor é exato: cada pedaço do contorno do talhão ou de um
obstáculo dentro do raio bloqueia as direções que ele ocupa visto do centro, cada obstáculo pontual as
direções do seu círculo de folga, e as direções livres entre os bloqueios formam arcos que estão ou
todos dentro do talhão ou todos fora; o arco mais largo dentro é o setor (mais estreito que 30° não
vale uma máquina). Os centros são procurados numa grade de 24 × 24 e nos cantos e bordas do talhão,
onde os pivôs setoriais costumam ficar, e depois refinados por uma busca por padrões (testes "an
L-shaped field: a three-quarter circle round the inner corner beats the full circle", "a rectangle: a
sector from the edge waters more than the inscribed circle").

---

## 20. Vegetação em imagens aéreas

Módulo `vegetation.dart` (Projeto → Projeto automático → Detectar vegetação na imagem). Gramados, canteiros,
árvores e arbustos são encontrados numa imagem aérea, o mapa de fundo na tela ou uma foto aérea
posicionada no desenho, e saem como contornos em metros do mundo, prontos para virar as áreas
irrigadas de um projeto. É processamento de imagem simples, linear no número de pixels, rodando no
próprio dispositivo: sem serviço externo, sem rede, sem modelo treinado. O diálogo lembra ao usuário
que as imagens têm termos de uso.

1. **Grade de trabalho**: a imagem é reduzida por médias em blocos até no máximo 1,2 milhão de pixels
   (cerca de 1100 × 1100) e não mais fina que 5 cm no terreno: pixels mais finos acrescentam tempo, não
   precisão, ao contorno de uma área irrigada, e a prévia precisa continuar ao vivo num celular.
   Pixels transparentes (blocos do mapa não carregados) não têm dado e contam como a borda da imagem.
2. **Índice de vegetação**: o excesso de verde ExG = 2g − r − b sobre as coordenadas cromáticas
   r = R/(R+G+B), g, b (Woebbecke, Meyer, Von Bargen & Mortensen 1995). No código a soma R + G + B é
   amortecida em 30 (de 765), para que o matiz aleatório de pixels quase pretos (sombra profunda, ruído
   de compressão) não seja lido como verde, e o índice é limitado ao dobro do excesso de verde sobre
   azul, min(2G − R − B, 2(G − B))/(R + G + B + 30): piscinas turquesa, reflexos do céu e sombras azuis
   no pavimento têm o verde bem acima do vermelho (um ExG alto) mas não mais verde que azul, enquanto as
   folhas refletem claramente mais verde que azul (o limite nunca atua nelas). Uma mediana 3 × 3 tira o
   ruído sem mover as bordas. ExG em vez de VARI = (G − R)/(G + R − B) (Gitelson, Kaufman, Stark &
   Rundquist 2002): o VARI divide por uma diferença que cruza o zero em pixels cinzentos e azulados
   (pavimento, telhados, sombras, água) e precisa ser cortado, então o seu histograma não tem forma
   estável para um limiar; o ExG é limitado, linear nas coordenadas cromáticas e independente do nível
   de iluminação, e o ExG com limiar pelo método de Otsu é a máscara de vegetação clássica de imagens
   RGB (comparado com os outros índices de cor por Meyer & Neto 2008).
3. **Limiar**: Otsu (1979) sobre o histograma do índice, a divisão que maximiza a variância entre
   classes; de novo abaixo dela quando a classe de baixo também é verde (um parque ou um campo de golfe
   enchendo a vista: dois tons de grama); entre duas modas separadas, o meio do trecho vazio. Ele é
   mantido entre 0,04 e 0,20 (uma vista toda de pavimento tem uma moda só, que o Otsu dividiria; abaixo
   da faixa superfícies cinzentas e marrons com um tom de cor passam por vegetação, acima dela gramados
   claros se perdem), mais o deslocamento do usuário; a separabilidade de Otsu (variância entre classes
   sobre a total) diz quando a vegetação e o resto não têm cores distintas.
4. **Limpeza**: um filtro de maioria (a mediana binária: um pixel toma a classe da maioria dos seus
   vizinhos num raio de 0,2 m, calculado com somas em caixa em tempo linear qualquer que seja o raio)
   remove pontos e linhas mais estreitos que cerca desse raio e fecha lacunas tão estreitas quanto.
   Diferente de uma abertura e de um fechamento, ele não move uma borda: ao longo de uma borda
   irregular ele acrescenta tantos pixels quantos tira, onde uma abertura raspa os que se projetam.
5. **Árvores e arbustos contra gramado**: a copa é áspera e mais escura — folhas e as suas sombras
   mudam o brilho de um decímetro para outro, enquanto a grama aparada é uniforme. A textura é a fração
   dos passos de brilho de 0,2 m, entre pixels de vegetação de uma janela de 1 m, maiores que um décimo
   do seu brilho: relativa, para que um gramado na sombra de um prédio continue liso, e uma fração em vez
   de uma média, para que a linha de uma sombra atravessando um gramado (alguns passos grandes entre
   muitos pequenos) não seja textura; pixels de pavimento não contam, então a borda de um gramado também
   não. Um pixel é copa quando fração/0,4 + 0,3·(100 − brilho)/100 passa de 1 (o brilho, a luma média da
   janela, de 0 a 255; grama aparada fica em cerca de 0 a 0,3 ao sol e 0,6 a 0,9 na sombra profunda,
   copas de árvores de 1,1 a 1,9); o viés do usuário move o limite, e a máscara de copa é limpa pela
   maioria dos seus vizinhos de vegetação num raio de 0,3 m.
6. **Manchas e buracos**: as componentes 8-conexas de cada classe mantida, as de menos de 5 m²
   deixadas de fora; os buracos são o resto 4-conexo da imagem cercado por uma mancha (caminhos,
   pavimento, edificações, piscinas, ou uma mancha da outra classe), os de menos de 4 m² cobertos pela
   mancha.
7. **Contornos**: marching squares percorrido em volta de cada mancha e de cada buraco a partir do
   seu primeiro pixel, as selas resolvidas pela conectividade para que os contornos de uma mancha e dos
   seus buracos nunca se cruzem, levados a coordenadas do mundo pelos quatro cantos da imagem (bilinear:
   exato para os retângulos da vista do mapa de fundo e de uma imagem posicionada), suavizados sem
   encolhimento pelo filtro λ|μ de Taubin (Taubin 1995; λ = 0,5, μ = −0,53: a escada dos pixels some, a
   área fica) e simplificados por Douglas–Peucker (1973) com tolerância de 0,25 m, reduzida à metade
   até o polígono não se cruzar. O Douglas–Peucker mantém vértices do contorno, então as suas cordas
   cortam os cantos arredondados e o polígono sai uma fração de pixel menor em toda a volta (cerca de 2 %
   de um gramado de 400 m²); um deslocamento ao longo das normais devolve essa área.

Uma área irrigada não tem buracos: cada mancha vira uma área (nomeada pela sua classe, com valores
agronômicos iniciais: gramado com Kc 0,85 da tabela 12 do FAO-56 para grama de estação quente no meio
da estação, zona radicular de 0,3 m, aspersores com a eficiência de spray do orçamento hídrico e uso de
água alto; árvores e arbustos com Kc 0,6, raízes de 0,4 m, gotejamento com a sua eficiência molhando
metade do solo e uso de água moderado), e cada buraco que é pavimento, uma edificação ou água, uma
polilinha fechada na camada de desenho, para que o traçado automático de aspersores o deixe de fora.
Um buraco preenchido por uma mancha da outra classe mantida não é repetido: essa mancha é uma área
própria, aninhada na de fora.

**Precisão em cenas sintéticas** (`vegetation_test.dart`): um jardim de 48 × 36 m com 10 cm por pixel,
com o ruído, a textura e as bordas suaves de uma imagem real, tem um gramado de 384 m² com um pátio de
12 m² e uma árvore, um gramado de 154 m² com metade na sombra de um prédio, duas copas de árvore sobre
pavimento com as suas sombras, solo nu, uma piscina e uma mancha verde de 2,25 m². A detecção encontra
dois gramados e três copas; os gramados dentro de 2 % da sua área (3 % líquida do pátio e da árvore), as
copas dentro de 8 % com os centroides a menos de 0,15 m, o pátio dentro de 5 % como exclusão, a metade
sombreada de um gramado mantida como gramado, pavimento, solo, piscina e sombras deixados de fora, a
fração com vegetação dentro de 5 % da verdade, e um contorno simplificado dentro da sua tolerância em
relação ao bruto. Um parque enchendo a vista (rough, um fairway viçoso e um bunker de areia) é dividido
entre areia e grama, não entre os dois verdes, e uma imagem só de gramado dá uma mancha sobre toda a
vista.

O que ele não consegue ver: gramados em sombra profunda ou secos e cor de palha (baixe o limiar),
gramado sob a copa das árvores (visto como copa), a textura das copas em imagens suaves e
reamostradas (vista como gramado: mova o limite de copa), água verde, grama sintética e telhados
verdes (vistos como vegetação); e os contornos só são tão bons quanto as imagens (a sua data, a sua
resolução e o seu ajuste ao desenho).

---

## 21. Agronomia

Módulos `agronomy.dart` (o requisito de cada área irrigada do projeto), `climate.dart`, `crops.dart`,
`soils.dart`, `effective_rain.dart`, `irrigation_requirement.dart`, `climate_online.dart`,
`solar_pumping.dart`, `wetted_bulb.dart` e `water_budget.dart`, com base no FAO-56 (Allen, Pereira,
Raes & Smith 1998) e nos manuais de irrigação da FAO.

### 21.1 Requisito diário e o programa do controlador

- ETc = Kc · ETo (mm/dia), com o Kc da curva da cultura da seção 21.3 ou, sem uma cultura da tabela,
  o Kc típico de meia estação oferecido por cultura.
- Água prontamente disponível RAW = CAD · Z_r · f (mm), com CAD em mm/m de solo, profundidade
  radicular Z_r em m e fração de esgotamento admissível f (MAD).
- Intervalo entre irrigações I = ⌊RAW / ETc⌋ dias (mínimo 1).
- Lâmina líquida por evento = ETc · I; lâmina bruta = líquida / eficiência (0,90 gotejamento, 0,75
  aspersão, 0,85 pivô como valores usuais; a área define a sua).
- Taxa de aplicação da zona PR = vazão / área; tempo por evento
  T = lâmina bruta · fração molhada / PR; volume por evento = lâmina bruta · área · fração molhada.
  A tabela de requisitos hídricos aplica a mesma fração molhada ao volume e às horas diárias, de
  modo que as duas tabelas concordam.
- **Programa do controlador**: cada turno roda pelo maior tempo de evento das áreas que as suas zonas
  (e estações valve-in-head, pelas áreas que contêm pelo menos um quinto dos seus aspersores) irrigam,
  a cada intervalo de dias, em sequência a partir da hora de início do dia (ou nas horas próprias),
  num calendário de N dias exportável em CSV; turnos que rodam a cada poucos dias começam em dias
  escalonados para não se acumularem, e o pico de horas de bombeamento por dia sai no relatório.

### 21.2 Evapotranspiração de referência

`fao56Eto` calcula a ETo de referência da grama pela equação de Penman-Monteith da FAO (FAO-56 eq. 6,
a planilha de cálculo do Box 11), diária ou para o dia médio de um decêndio ou de um mês, com todos os
termos do capítulo 3: pressão (eq. 7) e constante psicrométrica (eq. 8), pressões de vapor de
saturação e real (eqs. 11 a 19, a partir do ponto de orvalho, de um psicrômetro ou da umidade
relativa), radiação extraterrestre (eqs. 21 a 25, com o ângulo horário do pôr do sol limitado para que
o dia e a noite polares funcionem), horas de luz (eq. 34), radiação solar pela insolação (Angström,
eq. 35), radiação de céu limpo (eqs. 36 e 37), saldo de radiação (eqs. 38 a 40), fluxo de calor no
solo mensal (eqs. 43 e 44) e o vento a 2 m a partir de outra altura (eq. 47). Os dados faltantes seguem
o capítulo 3 do FAO-56: o ponto de orvalho tomado como Tmin (eq. 48), a radiação pela amplitude
térmica pela fórmula de Hargreaves (eq. 50, k_Rs 0,16 no interior e 0,19 no litoral, limitada à
radiação de céu limpo) ou a fórmula das ilhas (eq. 51), 2 m/s quando falta o vento, e pelo menos
0,5 m/s na eq. 6; as estimativas usadas são listadas com o resultado. `fao56MonthlySeries` dá os doze
meses no dia 15, com o fluxo de calor no solo pelos meses vizinhos (o ano tomado como cíclico), e a
equação de Hargreaves-Samani (eq. 52) é a alternativa. Os testes reproduzem os exemplos resolvidos do
FAO-56: Exemplo 17 (ETo mensal em Bangkok em abril, 5,72 mm/dia), Exemplo 18 (Uccle em 6 de julho,
3,88 mm/dia contra os 3,9 do livro) e Exemplo 20 (Lyon em julho só com Tmax e Tmin, 4,56 mm/dia), com
os seus termos intermediários.

**Clima da internet** (`climate_online.dart`): as normais mensais são montadas a partir das séries
diárias da API de clima histórico do Open-Meteo (as reanálises ERA5 e ERA5-Land desde 1940, cerca de
cinco dias atrás do tempo real: ETo, chuva, temperaturas, vento, radiação, umidade e ponto de
orvalho) ou da API diária por ponto do NASA POWER (meteorologia do MERRA-2 e radiação do
CERES/FLASHFlux desde 1981; a sua climatologia dá temperaturas mensais extremas e não médias, então as
normais vêm da diária). As duas dispensam chave e respondem a requisições de outra origem. O download
é cortês: requisições uma depois da outra dentro de um orçamento de chamadas por minuto (o Open-Meteo
conta uma requisição com mais de 10 variáveis ou mais de duas semanas de dados como várias chamadas,
variáveis/10 × dias/14), novas tentativas, esperas no HTTP 429 e cancelamento entre requisições. Um
mês de um ano conta quando dias suficientes dele têm chuva e temperaturas; a ETo diária é calculada
por Penman-Monteith onde há temperaturas e radiação; a chuva provável é o total mensal excedido em
quatro anos de cada cinco (posições de Weibull m/(n + 1), linear entre postos). A API gratuita do
Open-Meteo é para uso não comercial e os seus dados são creditados como CC BY 4.0; a NASA pede o seu
agradecimento, que o programa mostra.

### 21.3 Culturas e estádios

`crops.dart` guarda uma tabela das culturas que os projetistas mais encontram, cada entrada citando as
linhas do FAO-56 que usa: as durações dos estádios inicial, de desenvolvimento, de meia estação e
final (tabela 11), Kc ini, Kc mid, Kc end e a altura máxima (tabela 12), os coeficientes basais Kcb
(tabela 17), a profundidade radicular e a fração de esgotamento p para ETc ≈ 5 mm/dia (tabela 22) e a
tolerância à salinidade da tabela 4 do FAO-29 Rev. 1 (Ayers & Westcot 1985; segundo Maas & Hoffman
1977 e Maas 1984). A curva do coeficiente de cultura único é Kc ini no estádio inicial, uma reta até
Kc mid no desenvolvimento, Kc mid na meia estação e uma reta até Kc end no estádio final (FAO-56
eq. 66); a média num mês ou num decêndio é a integral exata da curva linear por partes, de modo que um
decêndio dá o valor gráfico da figura 36 do FAO-56. Kc mid e Kc end são ajustados para um clima
diferente de UR mín = 45 % e u₂ = 2 m/s por Kc + [0,04(u₂ − 2) − 0,004(URmín − 45)]·(h/3)^0,3 (eqs. 62 e
65, u₂ limitado a 1–6 m/s, URmín a 20–80 % e h a 0,1–10 m; Kc end só acima de 0,45); o Kc ini vem do
intervalo médio entre molhamentos e da lâmina infiltrada (Anexo 7, eqs. 7-1 a 7-4, eq. 59 entre
molhamento leve e pesado, eqs. 60 e 61 para molhamento parcial); a cobertura esparsa reduz o Kcb mid
pela eq. 98; o p é ajustado à ETc, p = p_tabela + 0,04·(5 − ETc), limitado a 0,1–0,8. Para irrigação
localizada o fator de redução Kr pela cobertura do solo GC é o de Keller & Bliesner (1990),
Kr = 0,1·√Pd com Pd a cobertura em percentual (aplicado pela FAO como Td = Ud·0,1·√Pd), ou um dos três
que a FAO tabela (Savva & Frenken 2002, Irrigation Manual Module 9, tabela 1): Keller & Karmeli
GC/0,85, Freeman & Garzoli GC + 0,5·(1 − GC) a partir de 50 % de cobertura, e Decroix 0,1 + GC. Um ciclo
perene cobre o ano todo e recomeça a cada aniversário da sua brotação (testes "Example 28: Kc on days
20, 40, 70 and 95 for dry beans", "Box 15: Kc mid adjusted for RHmin 30 % and u2 2.2 m/s", "Example 41:
30 % cover, 2 m tall, Kcb full 1.15 gives Kcb mid 0.75 (eq. 98)").

### 21.4 Solos e chuva efetiva

`soils.dart` dá às doze classes texturais do USDA as suas propriedades de água e de infiltração, cada
campo da sua fonte: a capacidade de água disponível da tabela 2-1 do NRCS NEH Part 652 (Irrigation
Guide, 1997) (1 in/ft = 83,3 mm/m); capacidade de campo, ponto de murcha, porosidade e condutividade
saturada a partir das médias de Rawls, Brakensiek & Saxton (1982); as faixas da tabela 19 do FAO-56 e
a água facilmente e totalmente evaporável; a taxa de infiltração básica e o acúmulo superficial
admissível por declividade do protocolo SWAT da Irrigation Association para controladores baseados no
clima (2008), como a especificação WaterSense da US EPA o adota; a faixa de infiltração para aspersão
da tabela 2-6 do NEH 652; e a intensidade máxima de aplicação da aspersão por declividade da tabela
11-4 do capítulo 11 da Seção 15 do NEH do USDA-SCS (1983), com os seus ajustes para solo descoberto
(−25 %) e grama (+25 %). Uma classe textural também sai dos percentuais de areia e argila pelos
limites do triângulo textural do USDA (Soil Survey Manual, Handbook 18).

Chuva efetiva (`effective_rain.dart`), sobre totais mensais em mm, proporcional aos dias para parte
de um mês:

- USDA-SCS (1970) Technical Release 21, como no capítulo 2 da Parte 623 do NEH (eqs. 2-84 e 2-85,
  tabela 2-43): Pe = SF·(0,70917·Pt^0,82416 − 0,11556)·10^(0,02426·ETc) em polegadas, com o fator de
  armazenamento de água no solo SF = 0,531747 + 0,295164·D − 0,057697·D² + 0,003804·D³ (D o
  armazenamento utilizável, a lâmina líquida de aplicação em polegadas; SF = 1 em D = 3 in), nunca
  mais que a chuva nem que a ETc;
- USDA-SCS simplificado, como no Boletim de Irrigação e Drenagem 46 da FAO (Smith 1992):
  Pe = P·(125 − 0,2·P)/125 para P ≤ 250 mm, 125 + 0,1·P acima;
- chuva provável da FAO/AGLW (FAO-46): Pe = 0,6·P − 10 para P ≤ 70 mm, 0,8·P − 24 acima;
- a fórmula empírica da FAO de Brouwer & Heibloem (1986), Training Manual nº 3:
  Pe = 0,6·P − 10 para P < 75 mm, 0,8·P − 25 acima;
- uma fração fixa da chuva (0,7 a 0,9 usual).

Os testes reproduzem o exemplo resolvido e a tabela 2-43 do NEH 623 e os exemplos do manual de
treinamento da FAO.

### 21.5 Requisito por cultura, mês e estádio

`irrigation_requirement.dart` monta a tabela que uma outorga pede ("lâmina líquida e bruta por
cultura e por período"): por ciclo de cultura e por mês de um ano típico, ou por período definido pelo
usuário, ETo, Kc, ETc, chuva efetiva, lâmina líquida, lixiviação, lâmina bruta, água prontamente
disponível, intervalo máximo, lâmina e horas por evento e volumes. Cada ciclo de cultura mantém o
seu Kc e as suas linhas; o Kc nunca é tirado em média entre culturas, e só lâminas e volumes são
somados.

- ETc,loc = Kr·ETc para irrigação localizada (Keller & Bliesner 1990; FAO Module 9 eq. 2);
- líquida = ETc,loc − Pe (mais, para o arroz inundado, a percolação, a saturação inicial e a lâmina
  de água de Brouwer & Heibloem 1986, seção 4.4);
- necessidade de lixiviação LR = CEa/(5·CEe − CEa) para irrigação por superfície e por aspersão
  (FAO-29 eq. 9, CEe para o rendimento potencial escolhido na reta da eq. 10 e da tabela 4 do FAO-29),
  e LR = CEa/(2·máx CEe) para gotejamento de alta frequência (Keller & Bliesner 1990, máx CEe a CEe de
  rendimento nulo); nenhuma quando 5·CEe ≤ CEa (a água é salina demais para a cultura);
- bruta = líquida/(Ea·(1 − LR)), ou, pelo raciocínio do Exemplo 3 do FAO-29 (as perdas de aplicação já
  lixiviam), máx(líquida/Ea, líquida/(1 − LR));
- TAW = CAD·Zr (FAO-56 eq. 82), RAW = p·TAW (eq. 83) com p ajustado à ETc, vezes a fração molhada Pw
  na irrigação localizada; intervalo máximo = RAW / lâmina líquida diária.

Testes: "Example 3: maize, river water of 1.2 dS/m", "irrigation frequency at peak demand (Example
6): 2 days, 434 litres per tree", "FAO Training Manual 3, section 4.4: paddy rice in April needs
313 mm".

### 21.6 Bombeamento solar

`solar_pumping.dart` dimensiona um sistema de bombeamento fotovoltaico para o volume diário de água de
cada mês, nos termos da IEC 62253:2011 (gerador fotovoltaico, condicionador de potência, conjunto
motobomba, altura manométrica total, volume diário de água). A energia hidráulica diária é
E_h = ρ·g·H·V; a energia do gerador é E = P·H_T·PR/G_stc, com a produtividade de referência H_T/G_stc
(horas de sol pleno, G_stc = 1 kW/m²) e a taxa de desempenho PR da IEC 61724-1 a partir das perdas por
sujeira, cabos, descasamento e outras e do fator de temperatura 1 + γ·(T_c − 25), γ ≈ −0,004/°C para
silício cristalino, com a temperatura da célula pelo método NOCT T_c = T_a + (NOCT − 20)·G/800 (Duffie
& Beckman, seção 23.3). A irradiação no gerador inclinado vem da média mensal no plano horizontal pelo
modelo de céu isotrópico de Liu & Jordan, H_T = H·[(1 − H_d/H)·R_b + (H_d/H)·(1 + cos β)/2 +
ρ_g·(1 − cos β)/2] (Duffie & Beckman eq. 2.19.1), a fração difusa mensal de Erbs, Klein & Duffie
(1982) (K_T limitado a 0,3–0,8) e R_b a razão entre a radiação extraterrestre diária na superfície
inclinada e no plano horizontal no dia médio do mês (Klein 1977), integrada numericamente ao longo do
dia para que qualquer orientação funcione (igual à forma fechada para superfícies voltadas para o
equador, teste "the numerical Rb equals the closed form for equator-facing surfaces"). O gerador é
dimensionado para o mês crítico (o mês mais escuro com a maior necessidade), o volume que ele eleva em
cada mês é informado e a energia é comparada com a da rede; a irradiação vem do download de clima
(MJ/m²/dia ÷ 3,6 = kWh/m²/dia).

### 21.7 Bulbo molhado e área molhada

`wetted_bulb.dart`: o solo molhado sob um gotejador por Schwartzman & Zur (1986), como reapresentado
por Cruz-Bautista et al. (2016): largura (diâmetro) W = 1,82·V^0,22·(K_s/q)^−0,17 e profundidade
Z = 2,54·V^0,63·(K_s/q)^0,45, com W e Z em m, o volume aplicado V em m³, a condutividade saturada K_s em
m/s e a vazão do emissor q em m³/s. O ajuste vem de dois solos (K_s ≈ 2,5·10⁻⁶ e 2,5·10⁻⁵ m/s) e de
duas fontes pontuais na superfície (4,3 e 20 L/h); fora dessa faixa ele extrapola e estudos
posteriores encontraram erros de dezenas de por cento, então ensaios de campo têm precedência. A
tabela de Keller & Bliesner (1990) dá a largura molhada de um emissor de 4 L/h por textura,
profundidade do solo e estratificação (como reproduzida pela FAO no Module 9, tabela 4), e a
percentagem de área molhada é Pw = 100·Np·Se·W/(Sp·Sr) (Module 9 eq. 10), o espaçamento de emissores
que conta limitado a Se' = 0,8·W para que círculos molhados separados não sejam tomados por uma faixa
contínua (testes "a 4 L/h emitter applying 8 L in a loam (Ks 13.2 mm/h)", "eq. 10: 5 emitters 1.2 m
apart wetting 2.26 m on 6 × 6 m trees give 38 %").

### 21.8 Orçamento hídrico de paisagismo e ciclo e infiltração

`water_budget.dart` segue a California Model Water Efficient Landscape Ordinance (MWELO, California
Code of Regulations, Title 23, §§ 490–495, revisão de 2015, Apêndice B): a água aplicada máxima
permitida MAWA = ETo·0,62·[ETAF·LA + (1 − ETAF)·SLA] (galões americanos por ano com a ETo em polegadas
por ano e as áreas em ft²; ETAF 0,55 para áreas residenciais e 0,45 para não residenciais, LA toda a
área de paisagismo incluindo as áreas especiais SLA) e o uso total de água estimado
ETWU = ETo·0,62·Σ(ETAF·HA) sobre as hidrozonas, ETAF = PF/IE para as áreas comuns (IE = 0,75 para spray
e 0,81 para gotejamento) e 1,0 para as áreas especiais; fatores de planta pelas faixas do WUCOLS (muito
baixo 0–0,1, baixo 0,1–0,3, moderado 0,4–0,6, alto 0,7–1,0). Em unidades métricas a ETo em mm e as
áreas em m² dão litros (1 mm em 1 m² é 1 L) sem fator de conversão. O **ciclo e infiltração** divide
uma rega que escorreria: a maior duração antes do escoamento é R_t = 60·ASA/(PR − IR) minutos e o
ciclo seguinte começa no mínimo D_a/IR depois do início do anterior (D_a a lâmina por ciclo), pelo
protocolo SWAT (seção 4.3), a taxa de infiltração IR e o acúmulo superficial admissível ASA vindo do
solo e da declividade da seção 21.4 (teste "1.5 in/h sprays on a clay loam with 5 % slope applying
0.5 in").

---

## 22. Pivôs centrais e outras máquinas

Módulo `pivot.dart` (Keller & Bliesner 1990, capítulo 14; Chu & Moe 1972) para a hidráulica da
máquina, e `mechanised.dart`, que roda para cada máquina de um projeto o pacote de aspersores e o
percentímetro (`pivot_package.dart`) e, quando os seus dados são informados, o braço de canto
(`corner_arm.dart`), a prescrição de taxa variável (`vri.dart`) e o projeto elétrico
(`pivot_electrical.dart`), com o ponto do pivô na pressão que a linha principal lhe dá.

- **Capacidade**: Q = A · lâmina bruta / tempo de ciclo. Para R = 300 m (área irrigada 28,3 ha, com
  o alcance do último aspersor), 8 mm em 24 h: Q = 94,2 m³/h. Num pivô setorial a área, e portanto
  a vazão, escalam com o ângulo varrido.
- **Distribuição da vazão**: num pivô a vazão que passa a uma distância r é Q·(1 − (r/R)²), porque a
  área irrigada cresce com r²; num linear é Q·(1 − r/L). O canhão final soma-se a toda a extensão.
- **Atrito**: integração numérica (Simpson, 200 passos) do gradiente de perda ao longo do tubo do
  vão com a vazão variável, pela lei de atrito do projeto (tubo dos vãos de aço galvanizado: Scobey
  K_s = 0,42, Manning n = 0,012); para um pivô o resultado equivale ao fator de Chu & Moe ≈ 0,543 vezes
  a perda de um tubo com a vazão total.
- **Pressão de entrada**: pressão do último aspersor (ou do canhão) + atrito + subida do terreno na
  pior direção (o azimute em que a ponta fica mais alta, obtido do modelo do terreno) + altura do
  tubo + perdas da máquina; cada torre é verificada, porque uma subida brusca a meio caminho pode
  governar. O resultado entra como demanda na linha principal (ou o requisito do próprio pacote,
  quando é maior, seção 22.1) e o déficit é reportado.
- **Taxa de aplicação** na extremidade: média I = 2·Q·R/(R²·w), da vazão por metro na ponta sobre a
  largura molhada w (Q já é a vazão do setor, sem correção adicional pelo ângulo), e pico (perfil
  elíptico) 4/π vezes a média; comparação com o limite de infiltração do solo, quando informado.
- **Vãos e bocais**: por vão, número de aspersores (espaçamento ao longo do tubo), vazão por
  aspersor, pressão a meio vão e o bocal do catálogo mais próximo; é a base do relatório de vãos e
  da lista de materiais (torres, aspersores, reguladores).

### 22.1 Pacote de aspersores e percentímetro

`pivot_package.dart` monta a carta de bocais de um pivô central ou linear:

- **Saídas**: posições ao longo da máquina a partir do ponto do pivô (ou da entrada de um linear), vão
  a vão no espaçamento de cada vão, o balanço incluído, ou uma lista explícita.
- **Vazão por saída** para uma lâmina uniforme (Heermann & Hein 1968; NRCS NEH 623 capítulo 11,
  eq. 11-44): cada saída atende o anel entre os pontos a meio caminho dos seus vizinhos,
  q_i = Q·(b_i² − b_{i−1}²)/R², o clássico q = 2·r·S·Q/R² para espaçamento uniforme, somando Q
  exatamente; um linear recebe q_i = Q·(b_i − b_{i−1})/L. R é o raio efetivo: comprimento do tubo mais
  o alcance do último aspersor, ou L + 0,9·R_canhão com um canhão funcionando a volta toda, cuja parte é
  Q·(1 − L²/R²) (eq. 11-46); um canhão usado só nos cantos é somado aos aspersores enquanto funciona.
- **Pressão em cada saída**: atrito saída a saída com a vazão que resta no tubo, pelo tubo de cada
  vão; subida do terreno nas posições de projeto e na pior; altura do tubo com a flecha do vão; perdas
  da máquina. Um pendural ganha o seu comprimento em carga estática e perde o atrito da mangueira mais
  o pescoço de ganso e as conexões, K·V²/2g (K = 1,5; Keller & Bliesner 1990, capítulo 16).
- **Reguladores**: a pressão nominal mais próxima da pressão alvo dos bocais, do catálogo ou da série
  padrão de 6 a 50 psi; um regulador precisa de 5 psi acima da sua pressão nominal na entrada para
  regular (Kansas State University MF3608, *Interpreting and Using Center Pivot Sprinkler Designs*,
  2022), e abaixo disso a sua saída é tomada como a entrada menos essa margem.
- **Bocais**: o bocal do catálogo cuja vazão na pressão do bocal fica mais perto do requisito, ou uma
  série numerada de diâmetros de orifício (passos de 1/128 de polegada, a numeração dos bocais de
  spray de pivô) dimensionados pela equação do orifício q = C_d·(π/4)·d²·√(2gh), C_d = 0,97, o
  coeficiente implícito nos coeficientes de descarga dos bocais da tabela 11-13 do capítulo 11 do
  NEH 623. Saídas que precisariam de menos da metade do menor bocal são tampadas e o seu anel passa
  para a saída seguinte (o espaçamento combinado do capítulo 11 do NEH 623).
- **Bomba auxiliar** (booster): uma bomba auxiliar na ponta dá ao canhão a sua pressão sem subir a da
  entrada; a sua potência de eixo é ρ·g·q·ΔH/η e o motor padrão seguinte é escolhido.
- **Percentímetro**: a velocidade da última torre regular a 100 % vem do trem de acionamento (rpm do
  motor sobre as relações das caixas central e de roda, vezes o perímetro de rolamento do pneu, que uma
  designação como 11.2-38 estima) ou é informada; o tempo por volta é 2π·r_última/v e a lâmina bruta
  Q·T/A; num ajuste p a torre anda p % do tempo, então o tempo e a lâmina crescem por 100/p (Kansas State
  MF3608; Keller & Bliesner 1990, capítulo 16).

Exemplo (os testes, segundo o capítulo 11 do NEH 623): o aspersor a 1200 pés do pivô com espaçamento
de 10 pés descarrega 10,69 gpm (eq. 11-44), dimensionado como um bocal um pouco maior que 7/32 de
polegada a 45 psi; um canhão final leva cerca de 120 gpm (eq. 11-46); uma volta de 66 horas a 2,0 pés
por minuto da torre final aplica 0,90 in; uma bomba auxiliar que dá a um canhão de 65 psi a sua pressão
na ponta de uma lateral de 45 psi precisa de 2,7 hp a 65 %.

### 22.2 Braço de canto

`corner_arm.dart`: um vão rígido articulado na última torre regular cuja ponta segue um caminho de
guia (um fio enterrado ao longo do contorno do talhão, recuado para dentro), de modo que a máquina se
estende nos cantos de um talhão quadrado e se dobra de volta ao longo dos lados. Modelo geométrico,
segundo a descrição dos sistemas de canto em Keller & Bliesner (1990, capítulo 16) e no capítulo 11
do NRCS NEH 623:

- a articulação H(θ) = C + R₀·(cos θ, sen θ) gira com a máquina a velocidade angular constante; a
  ponta T é o ponto do caminho a um comprimento de braço L_c de H do lado de trás, |T − H| = L_c, com o
  ângulo do braço φ (0 alinhado com a máquina, positivo para trás) limitado a φ_máx (120°); onde o
  caminho está fora de alcance o braço fica reto (falta), onde está mais perto do que o braço dobrado
  alcança ele fica em φ_máx (sobra);
- a área que o braço acrescenta fica entre o círculo da articulação e a trajetória da ponta do braço
  (ponta, balanço e alcance do último aspersor, tomados ao longo do braço), suposta estrelada em
  relação ao ponto do pivô, o que vale para caminhos de guia convexos;
- para uma lâmina uniforme um trecho do braço precisa entregar q = κ·dA/dθ, com dA/dθ a área que ele
  varre por radiano de rotação da máquina (só o movimento para a frente conta) e κ = 2π·d/T_volta, a
  mesma regra que dá à máquina principal q = Q·(b₂² − b₁²)/R²;
- os aspersores do braço formam bancos (quatro por padrão) dimensionados para o braço reto,
  q_banco = κ·((R₀ + s₁)² − (R₀ + s₀)²)/2, ligados em sequência conforme o braço se estende: um banco liga
  quando a vazão que ele deveria entregar chega à metade da sua vazão de projeto; a razão de serviço
  também é informada para pacotes que pulsam os bancos;
- uma ponta que anda mais de cinco vezes mais rápido que a torre da articulação significa que o braço
  saltou sobre o caminho de guia (`corner_arm_jump`).

Simplificações: terreno plano, braço rígido, a ponta exatamente sobre o caminho, velocidade constante
da máquina (os limites de velocidade do acionamento do braço não são modelados, só a razão de
velocidade da ponta é informada), o alcance do último aspersor continuando a linha do braço, e um
caminho fechado em volta do ponto do pivô (teste "flow versus angle: peak in the corners, symmetric
about the diagonals").

### 22.3 Prescrição de taxa variável

`vri.dart`: o ajuste do percentímetro (velocidade) de cada setor angular e, com controle por zona, a
razão de serviço dos bancos radiais de aspersores, para que a máquina aplique lâminas alvo dadas por
zonas (polígonos) ou por setores. Com **controle por velocidade** a lâmina de uma passada é
inversamente proporcional à velocidade, d(p) = d₁₀₀·100/p (o percentímetro), então um setor com alvo d
anda a p = 100·d₁₀₀/d, limitado ao ajuste mais lento que o painel aceita (5 % por padrão) e a 100 %:
alvos abaixo de d₁₀₀ não são alcançáveis só pela velocidade e alvos além do ajuste mais lento são
limitados. Com **controle por zona** o setor anda na velocidade do seu banco mais molhado e os outros
bancos pulsam com razão d_banco/d_setor (os modos de controle por velocidade e por zona da VRI de
aspersão sítio-específica, Evans et al. 2013, *Irrigation Science* 31: 871–887). As lâminas das zonas
são amostradas em pontos de área igual de cada setor e anel, e o alvo de um setor é a média ponderada
pela área (ou o máximo ou o mínimo, por escolha); a prescrição é exportada em CSV em ângulos do desenho
ou em azimutes de bússola (teste "zone control: the sector runs at the speed of its wettest bank, the
others pulse").

### 22.4 Projeto elétrico de uma máquina

`pivot_electrical.dart`, para uma alimentação trifásica (480 V por padrão):

- corrente do motor I = P/(√3·U·η·cos φ), P a potência nominal (0,55 kW, η 0,70, cos φ 0,72 por padrão
  para os motores das torres); corrente de partida (rotor bloqueado) k·I com fator de potência baixo
  (partida direta, k ≈ 6 com cos φ 0,4);
- queda de tensão vão a vão com a corrente de cada motor além do vão,
  ΔU = √3·L·(R·ΣI·cos φ + X·ΣI·sen φ), a forma trifásica do Anexo G da IEC 60364-5-52 (b = 1;
  resistência do condutor em serviço 1,25 vez o seu valor a 20 °C; reatância 0,08 mΩ/m quando
  desconhecida), verificada em funcionamento (todos os motores e a bomba auxiliar ligados, o pior caso
  do ciclo de alinhamento, no máximo 5 %) e enquanto cada motor parte com os outros funcionando (no
  máximo 15 %);
- o cabo dos vãos é a menor seção da lista de condutores de cobre classe 2 da IEC 60228 que mantém as
  duas quedas dentro dos limites;
- o gerador é o maior entre os kVA em funcionamento sobre o carregamento permitido (0,8) e o tamanho
  que limita a queda de tensão quando o maior motor parte, S = X''_d·S_RB·(1 − queda)/queda (IEEE Std
  399, estudos de partida de motores; IEEE Std 446, dimensionamento de geradores; X''_d = 0,2 pu e queda
  de 20 % por padrão), arredondado para cima até um valor padrão;
- num ajuste do percentímetro cada torre acompanha a última para se manter alinhada, então funciona
  uma fração do tempo proporcional ao seu raio, e a última torre a fração do percentímetro (Keller &
  Bliesner 1990, capítulo 16): a potência média.

Teste "end-gun booster: 120 gpm × 58 ft at 65 % (NEH 623 ch. 11) needs a 3 kW motor with the service
factor".

### 22.5 Carretéis com canhão

`traveller.dart`, segundo o capítulo 11 do NRCS NEH 623 e Keller & Bliesner (1990, capítulo 8):

- espaçamento entre faixas (caminhos) como percentual do diâmetro molhado pela classe de vento (tabela
  11-31): sem vento 80 %; vento até 2,2 m/s (5 mph) 70 % com bocais de anel e 75 % com bocais cônicos;
  até 4,5 m/s (10 mph) 60 a 65 %; ventos mais fortes 50 a 55 %; com uma largura de talhão o número de
  faixas é arredondado para cima e o espaçamento uniformizado, nunca mais largo que a tabela (cálculo
  de exemplo 11-17);
- lâmina bruta d = q/(S·v) e a velocidade para uma lâmina alvo v = q/(S·d) (eq. 11-40);
- intensidade de aplicação sob o canhão I = q/(π·(0,9·R)²·θ/360), a área molhada tomada em 90 % do raio
  (eq. 11-39);
- atrito da mangueira ao longo de toda a mangueira (a água também passa pelas voltas que ficam no
  carretel), por Hazen-Williams ou Darcy-Weisbach para PE; as perdas da turbina e do carretel são o
  valor do fabricante (o NEH 623 observa que costumam passar de 10 psi com acionamento por turbina);
- pressão de entrada no hidrante = pressão do canhão + atrito da mangueira + perda do acionamento +
  altura do canhão + subida do terreno; potência P = ρ·g·q·H/η.

Teste "sample calculation 11-17: 515 gpm gun, 455 ft diameter, 2,640 ft field, 2.56 in".

### 22.6 Irrigação por superfície

`surface_irrigation.dart` avalia e dimensiona sulcos, faixas e bacias em nível com o modelo de
balanço de volume de Walker & Skogerboe (1987) como exposto no Boletim de Irrigação e Drenagem 45 da
FAO (Walker 1989), com as famílias de infiltração revisadas do NRCS do capítulo 4 do NEH 623 como
solos padrão:

- **Infiltração**: Kostiakov-Lewis z = k·τ^a + f₀·τ (FAO 45 eq. 15), por metro de sulco ou por metro de
  largura; a infiltração do sulco escala com o perímetro molhado, k e f₀ vezes WP/WP_ref (capítulo 4 do
  NEH 623, eqs. 4-76 a 4-78).
- **Seção do escoamento**: A·R^(2/3) = ρ₁·A^ρ₂ a partir das leis de potência A = σ₁·y^σ₂ e WP = γ₁·y^γ₂,
  ρ₂ = 5/3 − (2/3)·γ₂/σ₂ e ρ₁ = σ₁^(5/3−ρ₂)/γ₁^(2/3) (eqs. 40 a 45; escoamento laminar largo ρ₁ = 1,
  ρ₂ = 5/3); área na entrada por Manning na profundidade normal, A₀ = (Q₀·n/(ρ₁·√S₀))^(1/ρ₂) (eq. 48),
  ou com a declividade de atrito y₀/x em áreas em nível (eq. 60, generalizada para as leis de potência
  do sulco).
- **Avanço**: o balanço de volume Q₀·t = σ_y·A₀·x + σ_z·k·t^a·x + f₀·t·x/(1 + r) (eq. 46) com σ_y = 0,77 e
  σ_z = (a + r(1 − a) + 1)/((1 + r)(1 + a)) (eq. 47), o avanço em potência x = p·t^r ajustado na metade e
  no comprimento total (o método dos dois pontos de Elliott & Walker 1982), resolvido por
  Newton-Raphson com salvaguarda de bissecção.
- **Depleção e recessão**: sulcos recuam no corte; faixas com saída livre se esvaziam y₀·L/(2·Q₀)
  depois do corte (eq. 99) e recuam no tempo de Strelkoff (1977) (eqs. 96 a 98); bacias em nível
  recuam verticalmente, a água que fica na superfície se espalhando por igual e infiltrando no lugar.
- **Desempenho**: lâmina infiltrada ao longo da área a partir do tempo de oportunidade
  τ(x) = t_rec(x) − t_av(x) (eq. 55); eficiência de aplicação, eficiência de requisito, uniformidade de
  distribuição do quartil inferior, percolação profunda e escoamento no fim.
- **Projeto**: o corte para a lâmina requerida (sulcos t_co = τ_req + t_L, eq. 68; faixas pela
  depleção de Strelkoff; bacias t_co = (Z_req·L − σ_y·y₀·L)/Q₀ + t_L, eq. 113) e a vazão que maximiza a
  eficiência de aplicação entre a mínima (a vazão de espalhamento da faixa 0,000357·L·√S₀/n m³/min/m de
  Hart et al. 1980, eq. 93) e a máxima não erosiva Q = (V^ρ₂·n/(ρ₁·√S₀))^(1/(ρ₂−1)) (eq. 67; bacias eq.
  115); e os parâmetros de Kostiakov-Lewis a partir de dois pontos de avanço de uma avaliação de campo
  (eqs. 49 a 54).

Os testes reproduzem os exemplos resolvidos do FAO 45, como o sulco de 200 m com 0,15 m³/min cujo
avanço leva cerca de 65 min e a recessão de Strelkoff do exemplo de faixa (824 − 147 = 677 min).

### 22.7 Tubo janelado

`gated_pipe.dart`: um tubo janelado (ou tubo flexível com furos) alimentando sulcos. Ao longo do tubo a
vazão cai janela a janela e a carga de pressão muda com o atrito da vazão que resta no tubo
(Hazen-Williams ou Darcy-Weisbach) e com a declividade do terreno, o balanço de energia do capítulo 4
do NRCS NEH 623, eq. 4-89, aplicado trecho a trecho em vez de com a vazão toda no comprimento todo (a
recuperação da carga cinética desprezada). Cada janela é um orifício q = C_d·A·√(2gh), C_d = 0,61 para
uma abertura de aresta viva (U.S. Bureau of Reclamation, *Water Measurement Manual*, capítulo 13); a
área requerida dá um diâmetro equivalente, e o furo é o menor perfurador padrão pelo menos desse
tamanho (1/2 a 1-1/2 polegada em passos de 1/8, depois 1-3/4 e 2 polegadas), parcialmente fechado até
a área requerida (uma janela regulável) ou, para furos fixos, passando a vazão do furo inteiro. A
carga mínima na entrada entrega o alvo pelo maior furo na janela crítica.

---

## 23. Terreno e geoprocessamento

### 23.1 Modelo digital do terreno

Módulos `terrain.dart` e `tin.dart`.

- Amostras: cotas de ponto e vértices das curvas de nível, densificadas a cada 5 m (parâmetro), com
  um hash espacial para consultas rápidas.
- **TIN de Delaunay** pelo algoritmo de Bowyer-Watson (inserção incremental com remoção dos
  triângulos cujo circuncírculo contém o ponto novo), com localização de triângulo por grade
  uniforme e interpolação linear por coordenadas baricêntricas. Exato em rampas planas (teste
  "Delaunay of a plane reproduces the plane exactly") e igual ao modelo que os CADs chamam de DTM. A
  triangulação trabalha em coordenadas relativas ao canto inferior esquerdo das amostras e trata um
  ponto sobre um circuncírculo (quatro pontos co-circulares: uma célula de malha regular, cotas nos
  cantos de um retângulo) como fora dele, de modo que a diagonal segue a ordem de inserção e mover
  ou georreferenciar um projeto (inclusive em coordenadas UTM) não muda seu terreno.
- **Linhas de quebra** (um divisor, o fundo de um talvegue, a borda de um terraço, de uma estrada ou
  de um aterro): os seus segmentos viram arestas da triangulação, de modo que a superfície dobra ao
  longo deles em vez de ser interpolada através. Depois da triangulação de Delaunay cada segmento de
  restrição, dividido em qualquer vértice que esteja sobre ele, é forçado trocando as diagonais que
  ele cruza (Sloan 1993): uma aresta que cruza o segmento é trocada quando os seus dois triângulos
  formam um quadrilátero convexo; senão ela espera os vizinhos serem trocados primeiro. Um vértice de
  linha de quebra pode trazer a sua cota levantada; um sem ela (NaN) a toma dos outros dados do
  terreno naquele ponto (IDW), e a linha de quebra é amostrada a cada passo de densificação com a cota
  linear ao longo de cada segmento, as amostras alimentando também o IDW (testes "without the
  breakline the valley is bridged; with it the surface folds along the channel", "a long diagonal
  breakline is forced through a dense triangulation").
- **IDW** (inverso da distância sobre os vizinhos mais próximos, com anéis de busca no hash) como
  método alternativo e como complemento fora do casco convexo do TIN. Cada amostra conta uma vez: as
  células compartilham chaves de hash, e uma célula distante trazendo de volta uma lista já lida
  pesava algumas cotas em dobro, numa quantidade que dependia de onde o desenho estava
  (`invariance_test`).
- Levantamentos com mais de 12 000 pontos são decimados uniformemente para a triangulação, mas o
  IDW mantém todos (teste "very large surveys are decimated for the TIN but kept for IDW"); o programa
  avisa uma vez para um terreno desse tamanho.
- **Curvas de nível geradas**: marching sobre os triângulos (interseção do plano de cada nível com
  cada aresta), segmentos encadeados em polilinhas com fechamento de anéis; intervalo automático
  escolhido para no máximo cerca de 20 curvas.
- **Declividade e aspecto** (`slope_map.dart`): pelo plano do triângulo sob um ponto, ou por
  diferenças centrais de 1 m fora do TIN; o mapa de declividade amostra o terreno numa grade quadrada
  (a célula cresce para caber num orçamento de células, células fora do casco dos dados deixadas de
  fora) e o colore por classe de declividade (limites superiores 2, 5, 10, 15, 20, 30 e 45 %, segundo
  as fases de declive do Soil Survey Manual do USDA, capítulo 3, arredondadas para o traçado de
  irrigação: verdes onde as laterais correm livres, amarelos e laranjas onde precisam de compensação de
  pressão ou de traçado em nível, vermelhos e roxo onde o terreno é íngreme) ou por aspecto (o azimute
  da maior descida em oito setores ao redor de uma roda de matizes, esmaecido abaixo de 1 %), com a
  fração da área em cada classe.
- Cada nó do grafo (inclusive os emissores agregados) recebe a cota do modelo, mais a altura da
  haste e menos a profundidade de enterro.

### 23.2 Nuvens de pontos e superfícies levantadas

- **LAS** (`las.dart`, ASPRS LAS Specification 1.4 R15, 2019): versões 1.0 a 1.4, formatos de
  registro de ponto 0 a 10 com a sua escala e o seu deslocamento, lidos como fluxo em pedaços de
  qualquer tamanho que guarda só o cabeçalho, um registro parcial e uma grade. Um filtro de
  classificação mantém os pontos de solo (classe 2) por padrão e pula os retidos; uma nuvem não
  classificada recorre ao ponto mais baixo de cada célula (o solo nu, sobre o qual ficam vegetação e
  edificações). Os pontos são decimados numa grade durante a leitura (`point_grid.dart`: uma grade
  regular sobre os limites com no máximo tantas células quanto o terreno triangula, um ponto por
  célula — a média da célula, o seu ponto mais baixo ou o ponto mais perto do centro), de modo que o
  terreno fica dentro do seu limite qualquer que seja o tamanho da nuvem. O sistema de coordenadas vem
  dos registros de tamanho variável (o GeoKeyDirectoryTag do GeoTIFF com o código EPSG projetado ou
  geográfico e as unidades lineares e verticais, ou o registro OGC WKT do LAS 1.4, também num registro
  estendido no fim do arquivo). Nuvens comprimidas (LAZ) são reconhecidas pelos bits de compressão do
  byte do formato de ponto e recusadas com `las_laz_unsupported` (testes "every version and point
  format: ground points on the plane, CRS from the keys or the WKT", "SAD 69 coordinates land on the
  SIRGAS 2000 points (the IBGE translation)").
- **LandXML 1.2** (`landxml.dart`, o schema de 2008): o leitor pega CgPoints (grupos aninhados também),
  Surfaces — a Definition (pontos e faces, o TIN guardado) ou os dados de origem (curvas, linhas de
  quebra, pontos, contornos) — decimados numa grade até o limite do terreno, e os tubos das redes de
  tubos; o CoordinateSystem (código EPSG, OGC WKT ou um nome) posiciona os dados, unidades imperiais
  são convertidas, e as coordenadas são lidas na ordem "norte este cota" do formato. O gravador dá o
  terreno do projeto como uma Surface (o TIN de `tin.dart` e as curvas e cotas de que ele foi feito),
  os itens pontuais como CgPoints no terreno com um código que diz o seu tipo, para locação, e os tubos
  como uma rede de tubos por zona e uma para a linha principal: um Pipe por segmento desenhado
  (circular, com o diâmetro interno e o C de Hazen-Williams, e a vazão de projeto e a piezométrica nas
  duas pontas quando há resultados) entre Structs nos vértices cujas geratrizes inferiores são o
  terreno menos a profundidade de enterro menos meio diâmetro interno. A ordem dos elementos, os
  atributos obrigatórios e os nomes únicos de Struct e Pipe do schema são respeitados (teste "the
  document follows the LandXML 1.2 structure").

### 23.3 Elevação da internet

Módulo `dem_online.dart`. Três fontes gratuitas, sem chave:

| Fonte | Dado | Resolução | Acesso |
|---|---|---|---|
| Terrain Tiles no AWS Open Data (a padrão) | SRTM, GMTED, ETOPO1 em blocos PNG "terrarium" | cerca de 30 m | blocos, com CORS, sem limite de taxa |
| Open-Meteo Elevation API | Copernicus DEM GLO-90 | 90 m | 100 pontos por chamada, cada ponto contado como uma chamada (ritmo de 550 pontos por minuto) |
| OpenTopoData | NASA SRTM, ASTER GDEM | 30 m | 100 pontos por chamada, uma chamada por segundo; sem cabeçalho de outra origem, então só no aplicativo de desktop |

A grade sobre o projeto (ou a área visível) é limitada em pontos (o espaçamento cresce quando a área
é grande). Para os blocos, o zoom é o menor cujo pixel não é maior que o espaçamento da grade (entre 8
e 14: o dado tem cerca de 30 m, então mais que isso só interpola, e o zoom cai até o número de blocos
caber), cada pixel terrarium se decodifica como cota = R·256 + G + B/256 − 32768 m, e os pontos são
amostrados bilinearmente; para os serviços de pontos as chamadas são feitas em lote e com ritmo, com
novas tentativas e esperas no HTTP 429. As respostas viram cotas de ponto e a geração de curvas pode
seguir automaticamente. Cotas já existentes no projeto (curvas de levantamento, cotas digitadas,
dados de exemplo) que não podem pertencer ao datum do modelo baixado — as duas faixas não se sobrepõem
e o intervalo entre elas passa de metade do relevo do próprio modelo — dariam um terreno cheio de
picos: o programa detecta isso e pergunta se deve substituí-las. A resolução de 30 a 90 m serve ao
relevo geral e não substitui um levantamento, o que o diálogo avisa.

### 23.4 Coordenadas e datums

- **UTM ↔ WGS84** pelas séries de Krüger na formulação de Karney (2011), com precisão milimétrica
  dentro do fuso, fuso automático com as exceções da Noruega e Svalbard, e origem local para manter
  as coordenadas do desenho pequenas (teste "UTM inverse round trip").
- **Datums** (`datum.dart`): arquivos nos datums geodésicos do Brasil são posicionados por translação
  geocêntrica. O SIRGAS 2000, o datum oficial (IBGE, Resolução do Presidente nº 1/2005), foi realizado
  sobre o ITRF2000 na época 2000,4 e concorda com as realizações atuais do WGS 84 em poucos centímetros
  nessa época; a placa se move 1 a 2 cm por ano, então uma posição observada hoje difere das suas
  coordenadas SIRGAS 2000 em até cerca de meio metro, e na precisão de uma planta de irrigação os dois
  são tratados como idênticos (o ETRS89 e o NAD83 também). SAD 69 → SIRGAS 2000: ΔX = −67,35 m,
  ΔY = +3,88 m, ΔZ = −38,22 m (R.PR 1/2005; elipsoide do SAD 69 a = 6 378 160 m, f = 1/298,25; GRS 80
  para o SIRGAS 2000). Córrego Alegre → SAD 69: ΔX = −138,70 m, ΔY = +164,40 m, ΔZ = +34,40 m (R.PR
  23/1989, elipsoide Internacional 1924), que composta com a anterior dá Córrego Alegre → SIRGAS 2000
  ΔX = −206,05 m, ΔY = +168,28 m, ΔZ = −3,82 m. As duas translações de três parâmetros têm precisão de
  alguns metros: as redes clássicas têm distorções dessa ordem, que só uma transformação por grade
  remove. Latitude e longitude vão para X, Y, Z geocêntricos no elipsoide de origem, são transladadas
  e voltam no elipsoide de destino (início de Bowring refinado por iteração); a projeção transversa de
  Mercator funciona em qualquer elipsoide (as séries de Krüger até n³).
- **Reconhecimento do CRS de um arquivo**: WKT 1 no sabor ESRI dos arquivos `.prj` e no da OGC (OGC
  01-009), WKT 2 (ISO 19162:2019), códigos EPSG (os códigos geográficos e UTM dos datums acima) e URNs
  da OGC; um sistema não reconhecido traz um código de problema (`crs_datum_unknown`,
  `crs_projection_unsupported`, `crs_unparsed`, `crs_geocentric`) para a interface avisar, em vez de os
  dados irem silenciosamente para o lugar errado.
- **Posicionamento** (`GeoPlacement`): dados UTM num datum compatível com o WGS 84 no fuso do projeto
  são um deslocamento simples (exato); dados geográficos e dados em outro datum, fuso ou projeção
  passam pela latitude e longitude WGS 84, com a conversão de datum, e pelo fuso UTM do projeto; sem
  georreferência do projeto uma é criada a partir dos dados (o seu fuso, a origem arredondada a
  100 m); coordenadas locais ou não reconhecidas são mantidas, e as grandes (além de 100 km) são
  deslocadas por uma origem local arredondada. Coordenadas só contam como graus quando todo par cabe na
  faixa de longitude/latitude e pelo menos metade tem quatro ou mais casas decimais (testes "SAD 69 and
  Córrego Alegre to SIRGAS 2000 agree with the Molodensky formula and round-trip", "UTM on SIRGAS 2000
  in the project zone is a plain offset; another zone goes through lat/lon").
- **Coordenadas coladas** (`parseLatLon`): decimais com ponto ou vírgula, letras de hemisfério,
  graus/minutos/segundos, links do Google Maps e URIs `geo:`; a ordem lon, lat (KML) é reconhecida
  quando só ela faz sentido.
- As exportações KML, KMZ, GeoJSON e GPX convertem cada vértice para WGS84 pela georreferência do
  projeto e precisam dela (o aplicativo a pede); shapefiles, LandXML, IFC e o arquivo do EPANET são
  gravados nas coordenadas UTM da georreferência quando há uma e em metros locais caso contrário.

---

## 24. Formatos de arquivo

### 24.1 DXF

Formato de texto do DXF, organizado em pares "código de grupo / valor". O leitor (`dxf.dart`)
percorre as seções BLOCKS e ENTITIES e lê LINE (10/20 e 11/21), LWPOLYLINE (vértices 10/20 em ordem,
bulge 42, flag 70 de fechamento, elevação 38), POLYLINE com VERTEX (elevação no código 30 ou nos Z
iguais dos vértices; vértices de controle de spline ignorados), CIRCLE, ARC (50/51 em graus),
ELLIPSE (polilinha pelos eixos 11/21, pela razão 40 e pelos parâmetros 41/42), SPLINE, HATCH, SOLID
e TRACE, TEXT, ATTRIBs visíveis, MTEXT (blocos 3 seguidos do 1, ponto de alinhamento 11/21 quando
72/73 pedem, a direção como ângulo ou vetor), LEADER (a sua linha; a ponta de seta e a nota são
desenhadas pelo programa) e POINT, com a camada (8) e a cor (62); a tabela LAYER e a variável
$INSUNITS definem camadas e a escala. Um bulge b descreve um arco de ângulo 4·atan(b) entre dois
vértices, amostrado a cada 15°. Os textos saem como texto simples: os caracteres `\U+XXXX` dos
arquivos numa página de código, os símbolos `%%c`, `%%d` e `%%p` (diâmetro, grau, mais ou menos),
`%%%`, as chaves de sublinhado e sobrelinhado e a notação de circunflexo dos caracteres de controle;
no MTEXT, os caracteres escapados, as quebras de linha e os espaços não separáveis viram espaços, as
frações empilhadas `a/b`, e os códigos de formatação e as chaves de agrupamento são removidos.

- **SPLINE**: com pontos de ajuste (11/21) vira uma spline editável por eles; senão a própria curva
  NURBS é avaliada pelo algoritmo de de Boor a partir do grau (71), dos nós (40), dos pontos de
  controle (10/20) e dos pesos (41, curvas racionais), com vetor de nós uniforme fixado nas pontas
  quando o arquivo não traz nenhum, e importada como polilinha.
- **HATCH**: os contornos (91/92) — contornos de polilinha com bulges ou contornos de arestas feitos
  de linhas, arcos circulares (arcos horários espelhados), arcos elípticos e splines — viram uma
  hachura cujo primeiro contorno é o limite e os demais são ilhas (mantidas como polilinhas
  fechadas); o flag de sólido (70) e a primeira linha do padrão (ângulo 53, espaçamento pelos
  deslocamentos 45/46, senão 3,175 mm vezes a escala do padrão) dão o preenchimento.
- **SOLID e TRACE**: triângulos e quadriláteros preenchidos, cujos cantos vêm na ordem 1-2-4-3,
  viram hachuras sólidas.
- **Extrusão (0, 0, −1)**: as entidades planas (CIRCLE, ARC, LWPOLYLINE, POLYLINE 2D, HATCH,
  SOLID, TRACE, TEXT, ATTRIB) são gravadas em coordenadas do objeto, e espelhar num programa de CAD
  costuma deixar uma extrusão (210/220/230) de (0, 0, −1), cujo eixo X do objeto é o −X do mundo
  pelo algoritmo do eixo arbitrário. Essas entidades, as referências INSERT e DIMENSION e o eixo
  menor de uma ELLIPSE são espelhados de volta para coordenadas do mundo (um arco de a a b vira o
  arco de 180° − b a 180° − a); LINE, POINT, SPLINE, MTEXT e polilinhas 3D já estão em coordenadas
  do mundo. Outras extrusões (entidades 3D) são projetadas como estão.

Blocos: cada BLOCK guarda o ponto-base (10/20) e suas entidades; INSERT (ponto 10/20, escalas 41/42,
rotação 50, matriz 70/71 com espaçamentos 44/45) e o bloco anônimo de cada DIMENSION (código 2, já
em coordenadas do desenho) são expandidos por uma transformação afim, com referências aninhadas
compostas até oito níveis. Entidades na camada 0 ganham a camada da referência e a cor BYBLOCK a
cor dela; círculos e arcos permanecem círculos e arcos quando a transformação preserva as formas
(rotação, escala uniforme, espelhamento — um arco espelhado gira no outro sentido e os ângulos de
textos e hachuras seguem as direções espelhadas) e viram polilinhas quando há escala anisotrópica;
os pontos de definição das cotas (camada Defpoints) não entram. O texto é decodificado como UTF-8
(R2007+) ou Latin-1 (cp1252 dos arquivos antigos).

Dois escritores: a exportação R2000 com entidades nativas (seção 24.3) e, como escolha
separada para programas antigos, um arquivo R12 (AC1009) das primitivas (LINE, POLYLINE, CIRCLE,
ARC, TEXT e POINT com a sua elevação, splines e símbolos como polilinhas, hachuras como contorno e
linhas, cotas como linhas e texto) em camadas com índice de cor, o denominador comum de todos os
CADs.

### 24.2 DWG

O DWG é binário e proprietário; a Open Design Alliance publica uma especificação de engenharia
reversa que serviu de base para o leitor (`dwg.dart`, 2,0 mil linhas) e para o escritor
(`dwg_writer.dart`, 1,7 mil linhas), ambos em Dart puro.

- **Versões**: AC1012 (R13), AC1014 (R14), AC1015 (2000), AC1018 (2004), AC1021 (2007), AC1024
  (2010), AC1027 (2013), AC1032 (2018). Versões desconhecidas são rejeitadas com mensagem clara.
- **Contêineres**: R13 a R2000 têm seções localizadas por um índice no cabeçalho, sem compressão;
  R2004 e R2010 a R2018 usam páginas comprimidas com um esquema LZ77 próprio e um mapa de páginas
  e seções; R2007 é o caso mais difícil: páginas intercaladas com códigos Reed-Solomon (blocos de
  239 bytes repetidos), que precisam ser desintercaladas e descomprimidas antes de ler.
- **Dados**: os objetos são endereçados pelo mapa de objetos (handles), e cada objeto é um fluxo de
  bits com códigos de tamanho variável (B, BB, BS, BL, BD, DD, MC, MS, H, entre outros); o leitor
  monta inteiros de vários bytes aritmeticamente porque as operações bit a bit do dart2js são de
  32 bits. O CRC-16 do cabeçalho é verificado contra a soma gravada em arquivos reais. O
  mapa de handles é uma lista de pares (handle, deslocamento) codificados por diferença em seções: a
  especificação reinicia as diferenças a cada seção, alguns escritores as mantêm correndo, e as duas
  leituras concordam na primeira seção, então são distinguidas conferindo objetos espalhados pelo
  mapa inteiro (conferir só as primeiras entradas lia errado 64 dos 750 objetos de um arquivo
  real).
- **Blocos e cotas**: INSERT (tipo 7) e MINSERT (8) trazem o ponto de inserção, as escalas
  (R13/R14 em três BD; R2000+ com um código BB que escolhe entre 1,1,1, um valor único, X = 1 ou
  três valores DD relativos ao X), a rotação, a extrusão, o flag de atributos, o vetor da matriz e,
  no fluxo de handles, o cabeçalho do bloco. BLOCK_HEADER (49) fornece o nome, o ponto-base e as
  entidades do bloco: primeira e última (R13–R2000, com os handles em sequência) ou a lista de
  entidades pertencentes (R2004+); a pertinência também vem do `entmode` 0 com o handle do dono.
  As cotas (tipos 20 a 26) são lidas só pelo fluxo de handles (estilo e bloco anônimo `*D`), pois a
  geometria já está no bloco em coordenadas do desenho. A expansão reutiliza a transformação afim do
  leitor DXF. Três detalhes de formato descobertos com o LibreDWG: handles com códigos 6, 8, A e C
  são deslocamentos relativos ao handle do objeto que os contém; em R2007+ as entradas de tabela
  não têm os bits "xref referenciado" e "xref dependente" (só o índice BS); e em R13/R14 o tamanho
  em bits dos objetos vem depois do handle e dos dados estendidos, não antes.
- **Curvas e preenchimentos**: ELLIPSE (35), SOLID (31), TRACE (32), SPLINE (36) e HATCH (78) são
  decodificados com o mesmo layout que o LibreDWG usa (cenário da spline, grau, nós, pontos de
  controle com pesos opcionais, pontos de ajuste; a partir do R2013 os flags da spline; os campos de
  gradiente da hachura a partir do R2004, os contornos com seus tipos de aresta e, a partir do
  R2010, os dados de ajuste das arestas spline) e entregues às mesmas conversões dos equivalentes
  DXF; LEADER (45) é lido como a sua polilinha, e os textos são decodificados como no DXF. Os dez
  desenhos de exemplo de R13 a R2018 das fixtures de teste dão exatamente as entidades que o
  LibreDWG lista para eles.
- **Detalhes iguais aos do leitor DXF**: polilinhas 2D mantêm os arcos dos vértices (o VERTEX_2D
  traz as larguras inicial e final e o bulge; vértices do quadro de spline são ignorados), textos
  alinhados são posicionados pelo ponto de alinhamento, e a extrusão de círculos, arcos,
  polilinhas, textos, sólidos, hachuras, elipses e referências de bloco é lida e aplicada como no
  DXF. Um desenho gravado pelo LibreDWG a partir de um arquivo do ezdxf (fixture de teste
  `curves_r2000`) é lido igual ao próprio DXF.
- **Escritor R2000**: um banco de dados de desenho completo (seção 24.3): as tabelas de controle
  (camadas com a sua cor, estado e tipo de linha, tipos de linha com tracejados, estilo de texto,
  viewport, appid, estilos de cota), os dicionários de objetos nomeados com layouts, o espaço do
  modelo e do papel, definições de bloco com as suas definições de atributo, e as entidades nativas
  LINE, LWPOLYLINE (com arcos), CIRCLE, ARC, POINT, TEXT, MTEXT, SPLINE, HATCH, SOLID, INSERT com
  ATTRIBs, DIMENSION (alinhada, angular, de raio, de diâmetro, de ordenada) com o seu bloco anônimo,
  e LEADER. As cores do R2000 são só índices de cor (as cores verdadeiras chegaram com o formato
  R2004), e os caracteres fora da página de código são gravados na notação `\U+XXXX` que os programas
  de CAD leem. O layout dos bytes segue a especificação da Open Design Alliance como o LibreDWG a
  implementa; a ordem dos campos e os valores padrão foram conferidos contra arquivos
  reais e validados com o LibreDWG (`dwgread`, `dwg2dxf`), que o teste executa quando está
  instalado, além de relidos pelo próprio leitor.

### 24.3 O desenho CAD nativo

Módulos `cad_drawing.dart` e `cad_export.dart`: os dois escritores R2000 (DXF AC1015 em
`dxf_r2000.dart`, DWG AC1015 em `dwg_writer.dart`) recebem um único modelo do desenho, de modo que o
DXF e o DWG levam o mesmo desenho, em metros do mundo, para o trabalho continuar num programa de CAD:

- as entidades de desenho continuam o que são: linhas, polilinhas leves (os arcos das nuvens de
  revisão e dos setores de pivô como bulges), círculos, arcos, splines (a curva Catmull-Rom
  centrípeta do aplicativo convertida exatamente numa B-spline cúbica, um trecho de Bézier por par de
  pontos de ajuste com as tangentes da forma de Barry–Goldman nas suas pontas e nós de
  multiplicidade três nas junções espaçados pelos comprimentos das cordas, mais os seus pontos de
  ajuste), hachuras (sólidas, ou o padrão ANSI31 girado e escalado para o ângulo e o espaçamento da
  hachura), texto e texto multilinha;
- as cotas são entidades DIMENSION (alinhada, angular de 3 pontos, de raio, de diâmetro, de
  ordenada) com os seus blocos anônimos `*D` já desenhados, para que os programas as mostrem sem
  recalcular, em estilos de cota cujos tamanhos são os tamanhos de papel da ISO-25 vezes um DIMSCALE
  que deixa o texto com 0,5 m e cujos fator de comprimento e sufixo mostram as unidades do projeto; os
  chamados são entidades LEADER com a sua nota como texto multilinha;
- símbolos e itens hidráulicos são referências a pequenos blocos (um por tipo) cujos atributos
  invisíveis NAME, ITEM, NOZZLE, ZONE e STATIONS levam o nome, o item de catálogo, o bocal, a zona e as
  estações da entidade, na camada do item; os blocos de usuário do projeto também são definições de
  bloco;
- as curvas de nível mantêm a sua elevação, as cotas de ponto e os vértices das linhas de quebra são
  pontos 3D; fitas, rotas de fios e linhas de quebra usam um tipo de linha tracejado;
- as camadas levam o índice de cor e, no DXF, a cor verdadeira (código 420, lido pelos programas de CAD a partir do
  formato R2004), o seu tipo de linha e os seus estados ligada, travada e de plotagem; os nomes de tabela são
  tornados válidos (os caracteres `<>/\":;?*|=,` e o acento grave viram `_`); o DXF tem $INSUNITS em
  metros, o seu texto em ASCII com `\U+XXXX` para o resto ($DWGCODEPAGE ANSI_1252), de modo que é lido
  igual qualquer que seja a codificação que um programa presuma, e todos os handles e donos do banco
  de dados.

`tool/formats/check_exports.py` valida os dois arquivos com o ezdxf (auditoria sem erros) e o
LibreDWG, e `cad_export_test.dart` os relê.

### 24.4 KML e KMZ

XML do Google Earth com coordenadas lon, lat, altitude em WGS84; KMZ é um zip com o KML e recursos.
Pastas viram camadas, linhas com altitude ou atributo ELEV viram curvas de nível, pontos com altitude
viram cotas. A projeção para UTM é feita com fuso automático e origem local; a exportação faz o
caminho inverso com uma pasta por camada.

### 24.5 Shapefile, CSV/PNEZD

- **Leitor de shapefile**: `.shp` (geometria com cabeçalho big-endian de 100 bytes e registros
  little-endian: pontos, polilinhas, polígonos, multipontos e variantes Z), `.dbf` (atributos dBase,
  de onde vêm a elevação ELEV/Z/COTA e o nome NAME/NOME/ID, decodificados conforme o `.cpg` ou como
  UTF-8 quando válido e Latin-1 caso contrário) e `.prj` (sistema de referência, com as conversões de
  datum da seção 23.4), aceitos dentro de um zip, também vários shapefiles num só zip. Sem `.prj`, as
  coordenadas só são tratadas como graus quando cabem na faixa de latitude/longitude e pelo menos
  metade tem quatro ou mais casas decimais; um desenho local em metros fica como está.
- **Escritor de shapefile** (`shp_writer.dart`, ESRI Shapefile Technical Description, 1998): um
  shapefile por camada e tipo de geometria (pontos, polilinhas, polígonos; as variantes Z onde uma
  elevação faz sentido: curvas de nível, cotas de ponto e, com um terreno, os tubos na sua cota de
  enterro e os itens pontuais no terreno), com o índice `.shx`, atributos `.dbf` em UTF-8 declarados
  por um `.cpg` (os atributos do GeoJSON mais campos tipados: item de catálogo, diâmetros,
  comprimento, vazões, velocidades e pressões nas unidades do projeto indicadas no campo, cotas, áreas
  e culturas), um `.prj` e tudo num zip; coordenadas no fuso UTM do projeto sobre o SIRGAS 2000 ou o
  WGS 84, ou metros locais sem georreferência.
- **Pontos de levantamento**: CSV, TXT, XYZ e PNEZD (ponto, norte, este, cota, descrição) com
  detecção de colunas pelo cabeçalho ou pela posição, separadores vírgula, ponto e vírgula, tab e
  espaço, vírgula decimal e reconhecimento de lat/lon.

### 24.6 GeoJSON, GPX, DGN, EPANET e IFC

- **GeoJSON** (`geojson_reader.dart`, RFC 7946, e a especificação de 2008 para o seu membro `crs`):
  uma FeatureCollection, uma Feature, uma GeometryCollection ou uma geometria solta de qualquer tipo,
  furos e coleções aninhadas incluídos; longitude/latitude no WGS 84, ou UTM no SIRGAS 2000, no SAD 69
  ou no Córrego Alegre quando um `crs` o nomeia; uma terceira coordenada é a cota, e as propriedades
  dão nome à feição (`name`, `nome`, `nombre`, `id`, `label`), uma cota (`elevation`, `elev`, `z`,
  `cota`, `altitude`) ou uma camada.
- **GPX** (`gpx.dart`, schema GPX 1.1, 2004), para o trabalho de campo com um receptor GPS ou um
  celular: o escritor põe cada item pontual (aspersores, as saídas das laterais, válvulas, junções,
  bombas, fontes, dispositivos, controladores, centros de pivô) como um waypoint com o seu nome,
  tipo, item de catálogo e cota do terreno, e os itens lineares como trilhas ou rotas; o leitor toma
  os waypoints como cotas de ponto e as rotas e trilhas como polilinhas (GPX 1.1 ou 1.0). A ordem dos
  elementos do schema é respeitada.
- **DGN V7** (`dgn.dart`, o arquivo de projeto ISFF): linhas, sequências de linhas, formas, curvas,
  cadeias e formas complexas, círculos, elipses e arcos, texto e células, níveis como camadas,
  arquivos 2D e 3D; coordenadas pelas unidades de resolução com a razão unidade mestre/subunidade e a
  origem global do cabeçalho, inteiros de 32 bits na ordem de palavras middle-endian e ponto flutuante
  no formato VAX D, ângulos em 1/360000 de grau. O DGN V8 (um documento composto OLE) é reconhecido e
  recusado.
- **EPANET INP** (`epanet_inp.dart`, EPANET 2.2 Users Manual EPA/600/R-20/133): o escritor parte do
  grafo do construtor de rede (laterais agregadas em nós emissores) com os tubos dimensionados: fontes
  e a entrada de uma zona exportada são reservatórios na sua cota mais a sua pressão; tubos, laterais e
  fitas são tubos (comprimentos com o acréscimo das perdas localizadas, como na nossa análise; perdas
  dos conectores como perdas localizadas); válvulas de retenção, uma válvula de uso geral com a sua
  curva de perda em série com um tubo curto de status CV; bombas, uma curva de carga de vários pontos
  amostrada da parábola do catálogo com a sua rotação; PRV, PSV e FCV com os seus ajustes e a perda
  aberta como coeficiente de perda localizada; válvulas de zona e dispositivos com h = K·Q^n + C,
  válvulas de uso geral com uma curva de perda de carga; emissores agregados, coeficientes [EMITTERS]
  para o expoente global único do EPANET (o mais comum da rede), um emissor de outro expoente mantendo
  a sua vazão na sua pressão nominal e um autocompensante (x < 0,1) virando uma demanda base, cada um
  com um código. As opções dão as unidades, a fórmula de perda de carga (H-W, D-W, C-M) e a
  viscosidade relativa na temperatura de projeto. Um arquivo por turno, os aspersores
  valve-in-head como emissores nos turnos que operam a sua estação. O leitor monta a nossa rede a partir
  de qualquer arquivo de entrada (uma curva de GPV ajustada de volta para h = K·Q^n + C) ou um desenho
  dela.
- **IFC 4** (`ifc.dart`, arquivo STEP ISO 10303-21 do schema IFC4, ISO 16739-1:2018, Reference View),
  para software de BIM e de obras de terraplenagem: IfcProject → IfcSite com o TIN do terreno como o
  corpo do sítio (IfcTriangulatedFaceSet) e, com georreferência, IfcMapConversion e IfcProjectedCRS (o
  código EPSG do fuso UTM); tubos, laterais e fitas são IfcPipeSegment com um IfcSweptDiskSolid ao
  longo do tubo na sua profundidade de enterro; aspersores e emissores, IfcFlowTerminal com ObjectType
  `IRRIGATION_<KIND>` (o IFC4 não tem classe de terminal para saídas de irrigação: o sprinkler de
  combate a incêndio e o terminal sanitário são outras coisas); válvulas, IfcValve (válvulas de zona
  USERDEFINED `ZONECONTROL`), filtros IfcFilter, hidrômetros IfcFlowMeter, bombas IfcPump,
  reservatórios IfcTank, cada um com os conjuntos de propriedades padrão, um conjunto próprio
  `OCI_Hydraulics` (vazão, pressões, velocidade, item de catálogo, zona) e as informações de
  fabricante do seu item; cada zona e a linha principal é um IfcDistributionSystem. Os GlobalIds
  derivam dos ids do projeto e da entidade, de modo que o mesmo projeto exporta os mesmos ids. As
  conexões não são exportadas (o projeto as seleciona sem posições).

### 24.7 GeoTIFF, world files e imagens

TIFF com as tags GeoTIFF ModelPixelScale/ModelTiepoint ou ModelTransformation e as chaves de CRS
(UTM ou geográfico). Um raster de uma banda (float ou inteiro) é tratado como DEM e vira grade de
cotas, com nodata ignorado; rasters RGB são imagens de fundo. Imagens JPG e PNG aceitam world files
(.jgw, .pgw, .wld) dentro de um zip: x = A·col + B·lin + C e y = D·col + E·lin + F para o centro
de cada pixel, de modo que o eixo das colunas (A, D) dá o tamanho do pixel e a rotação
(atan2(D, A)) e o canto superior esquerdo fica meio pixel atrás nos dois eixos; a matriz
ModelTransformation do GeoTIFF é tratada do mesmo modo. Sem georreferência, a imagem é colocada
na vista e ajustada por dois pontos (transformação de similaridade: translação, rotação e escala).
Arquivos BigTIFF (deslocamentos de 64 bits) são recusados pelo nome em vez de falharem depois, assim
como rasters de mais de 100 milhões de pixels.

### 24.8 Saída em PDF

- **Escritor** (`pdf.dart`, ISO 32000-1 gravado como PDF 1.4): objetos com tabela xref, caminhos
  vetoriais, recorte e fluxos de conteúdo comprimidos com Flate. O texto que o WinAnsi representa fica
  nas fontes padrão Helvetica; qualquer outro texto é diagramado por `fonts/pdf_fonts.dart` em trechos
  de uma direção, uma escrita e uma fonte, moldado com as tabelas OpenType das fontes Noto embutidas
  (Sans, Math para símbolos, Arabic, Devanagari, Bengali, Gurmukhi, Telugu, chinês simplificado e
  japonês) e desenhado com uma fonte Type0 por fonte TrueType (uma descendente CIDFontType2,
  codificação Identity-H, CIDToGIDMap /Identity, larguras, um subconjunto embutido e uma CMap
  ToUnicode). Copiar e buscar dão o texto lógico: o primeiro glifo de cada grupo moldado aponta para o
  texto do grupo e os outros para nada, e um glifo que representa textos diferentes (um esqueleto de
  letra árabe compartilhado, o primeiro glifo de sílabas índicas diferentes) recebe um CID por texto,
  uma cópia do glifo acrescentada depois do fim da fonte. O negrito é simulado com o modo de
  renderização de texto 2 e um traço fino. Uma fonte ausente cai para a fonte seguinte da cadeia,
  depois para a aproximação WinAnsi do caractere e, por fim, para "?". As imagens são XObjects de
  imagem: dados JPEG passados adiante (DCTDecode), qualquer outra coisa decodificada e guardada como
  RGB (FlateDecode) com uma máscara suave para o canal alfa, a opacidade por um ExtGState, e imagens
  grandes reamostradas para o tamanho em que são impressas.
- **Moldagem de texto** (`fonts/`, Dart puro, segundo a especificação OpenType 1.9 e os seus
  documentos de desenvolvimento de escritas): os caracteres são normalizados contra a fonte
  (decomposição e composição canônicas, marcas reordenadas pela classe de combinação), mapeados para
  glifos, e o moldador da escrita define as máscaras de recursos — a junção árabe pelos tipos de
  junção do ArabicShaping.txt nas formas posicionais (isol, fina, medi, init), depois rlig
  (lam-alef), calt e liga, as marcas modificadoras mantidas junto da sua base (UAX #53); as sílabas
  índicas (as tags da nova especificação dev2, bng2, gur2, tel2) com a consoante base encontrada, as
  matras pré-base, o reph e as formas de reordenação pré-base movidos, os recursos básicos (nukt,
  akhn, rphf, rkrf, pref, blwf, abvf, half, pstf, vatu, cjct) aplicados dentro de cada sílaba e os
  recursos de apresentação (init, pres, abvs, blws, psts, haln, calt) depois; então o GPOS (kerning,
  acoplamento de marca e de marca sobre marca, abvm, blwm, dist) com os avanços das marcas zerados
  onde a escrita pede. São lidos os tipos de lookup 1 a 8 do GSUB e 1 a 9 do GPOS; as tabelas de
  dispositivo e de variação são ignoradas (o texto do PDF é escalado, não ajustado à grade). A direção
  vem de um Algoritmo Bidirecional Unicode simplificado (UAX #9: nível do parágrafo, tipos fracos,
  parênteses pareados, neutros, níveis implícitos e reordenação; incorporações, substituições e
  isolamentos explícitos não são interpretados), e os trechos da direita para a esquerda saem do
  moldador em ordem visual com espelhamento. O gerador de subconjunto mantém os contornos dos glifos
  usados (e os componentes dos glifos compostos) sem renumerar, de modo que os CIDs são os ids dos
  glifos. Os trechos dos textos da interface em árabe, urdu, hindi, marata, bengali, punjabi e télugo
  precisam ser moldados com os glifos e as posições de um mecanismo de referência (HarfBuzz, gravado em
  `test/fixtures/shaping`) em pelo menos 99 % dos trechos (`text_shaping_test.dart`).
- **Pranchas** (`plot.dart`, `pdf_sheet.dart`, `sheet_set.dart`): a prancha é montada em espaço do
  papel, penas, símbolos e textos em milímetros de papel, com escala automática ou fixa, carimbo,
  legenda, seta norte, escala gráfica, o mapa de fundo e as imagens sob o desenho, a tabela de
  revisões (as nuvens de revisão com o seu número, data e descrição) e páginas de relatório. Um
  **conjunto de pranchas** é uma visão geral mais uma prancha por zona ou por área irrigada (ajustada a
  ela, com as outras zonas em cinza ou omitidas; zonas na ordem natural dos seus nomes) e as janelas do
  desenho que o usuário escolheu, cada uma com a sua escala e o seu título.
- **Detalhes construtivos** (`details.dart`): oito detalhes típicos desenhados por código com os
  valores do projeto (diâmetros dos tubos, profundidades de enterro, os ajustes de vala do orçamento,
  os modelos de catálogo em uso, pressões dos resultados), numa escala de detalhe escolhida para caber
  numa célula da prancha: o corte da vala, uma válvula de controle na sua caixa, um aspersor sobre uma
  junta articulada ou um tubo de subida, o conector inicial de uma linha de gotejamento, uma ventosa,
  um bloco de ancoragem numa curva, a sucção de uma bomba de superfície e uma estação de filtragem. Os
  valores típicos seguem a prática corrente: os recobrimentos mínimos da ASAE S376.2 para tubulações
  termoplásticas enterradas quando o projeto não tem profundidade (0,45 m até 65 mm de diâmetro
  externo, 0,60 m até 125 mm, 0,75 m acima), a submergência da sucção S = 2,5·D + 0,1 m dos livros de
  hidráulica (Azevedo Netto, *Manual de Hidráulica*), e o empuxo numa curva T = 2·p·A·sen(θ/2) na
  pressão de ensaio (1,5 vez a maior pressão de trabalho, senão a classe do tubo) contra uma tensão
  admissível do solo (50 kPa por padrão), o que dá a área de apoio do bloco.
- **Gráficos** (`plot_charts.dart`), desenhados como itens de plotagem para que o PDF imprima o que a
  tela mostra: a linha piezométrica da linha principal em cada turno (da fonte até a
  válvula com a menor folga de pressão, com a carga que essa válvula exige), o perfil longitudinal do
  terreno ao longo dela ou de um caminho desenhado com a ferramenta de perfil (pontos mais baixo e
  mais alto marcados), e a curva de cada bomba com o seu ponto de operação em cada turno (e a curva na
  rotação em que um inversor a opera).
- A prancha também é exportada como **PNG** (96 a 300 dpi, a resolução reduzida para ficar dentro de
  40 milhões de pixels e 8192 pixels por lado), a partir do mesmo layout reproduzido num raster.

### 24.9 Plantas em PDF como fundo

`pdf_reader.dart` (ISO 32000-1, e arquivos PDF 2.0 gravados do mesmo jeito) lê a estrutura do arquivo
— o cabeçalho procurado no primeiro kilobyte, tabelas de referência cruzada clássicas e fluxos de
referência cruzada, fluxos de objetos, a cadeia de atualizações incrementais (vale a definição mais
nova) e arquivos híbridos; uma tabela danificada ou ausente é reconstruída varrendo o arquivo em busca
de objetos — e os filtros de fluxo (Flate e LZW com os preditores PNG e TIFF, ASCIIHex, ASCII85,
RunLength; para imagens, DCT passado adiante e fax CCITT). Imagens JPEG 2000 e JBIG2 ficam de fora com
um aviso, os fluxos decodificados têm teto para que um arquivo pequeno não se expanda em gigabytes, e
arquivos criptografados são recusados (`pdf_encrypted`), pois mesmo os que abrem sem senha precisariam
das cifras RC4/AES. Uma página é interpretada sob demanda em itens neutros no espaço da página como
exibida (pontos, vezes /UserUnit, origem no canto inferior esquerdo da caixa de corte, /Rotate
aplicado, para que a planta entre do jeito que um visualizador a mostra): contornos, com as curvas
achatadas dentro de uma tolerância ligada ao tamanho da página e os segmentos traçados de um mesmo
estilo que se encontram ponta com ponta unidos em polilinhas (programas de CAD costumam gravar cada
linha sozinha); trechos de texto unidos ao longo da sua linha de base com origem, altura e ângulo,
decodificados pela CMap ToUnicode, senão pela codificação da fonte (WinAnsi, MacRoman, Standard,
Symbol, Differences com os nomes de glifo padrão) ou pelas CMaps Unicode das fontes compostas, o texto
invisível (a camada de OCR das digitalizações) deixado de fora; e as imagens recodificadas como PNG com
os quatro cantos do raster. Os grupos de conteúdo opcional dão nome à camada do que envolvem, o
conteúdo de camadas desligadas por padrão é marcado como oculto, e o recorte é aproximado pela caixa
envolvente de cada caminho de recorte intersectada ao longo da pilha de estados gráficos (o que uma
moldura de mapa ou uma viewport de CAD esconde fica de fora, nada visível se perde); sombreamentos,
padrões, grupos de transparência, anotações e desenhos de glifos Type 3 não são interpretados, e o
trabalho de uma página tem teto (200 000 segmentos de caminho, `pdf_truncated`).

`pdf_import.dart` posiciona uma página no desenho na escala do papel: em 1:N uma unidade do PDF
(1/72 de polegada na folha) vale N × 0,0254/72 m, ou um fator para uma planta gravada em metros ou
milímetros; a escala escrita na folha (`ESCALA 1:500`, `Scale 1/200`, um `1:250` solto) é detectada e
proposta, e as ferramentas de alinhamento por dois pontos e de georreferência então ajustam a planta a
pontos conhecidos. Caminhos de dois pontos viram linhas, os mais longos polilinhas, os caminhos
fechados polilinhas fechadas; as áreas preenchidas entram como contornos (máscaras brancas de papel e
um preenchimento cobrindo a página inteira ficam de fora); os textos mantêm a sua altura e o seu
ângulo; as imagens, os seus cantos (uma imagem espelhada é invertida). Cada importação tem uma camada,
uma por camada do PDF abaixo dela e, opcionalmente, uma por cor, com as cores da planta tornadas
visíveis na tela escura.

### 24.10 SVG e XLSX

- **SVG**: a mesma cena da prancha em PDF em milímetros, um grupo por camada.
- **XLSX**: SpreadsheetML mínimo (Office Open XML): uma planilha por tabela, cabeçalho em negrito,
  números como números e strings inline, sem tabela de strings compartilhadas; um leitor do mesmo
  subconjunto permite reimportar catálogos editados numa planilha.

### 24.11 Verificação com leitores independentes

Os leitores e escritores são conferidos contra software de terceiros, não só entre si.
`tool/formats/make_fixtures.py` grava em `test/fixtures/formats` arquivos de importação produzidos
por outras bibliotecas: DXF R12, R2000, R2010 (em milímetros) e R2018 do ezdxf com blocos,
bulges, MTEXT e polilinha 3D; DWG R2000 do LibreDWG; shapefiles do pyshp (polígonos UTM com `.prj`,
polilinhas Z com atributo ELEV, pontos WGS84, multipontos Z, um `.shp` solto em coordenadas
locais); GeoTIFF do tifffile (DEM float32 UTM com nodata, DEM int16 geográfico, ortofoto RGB);
PNG e JPG do Pillow com world files, um deles rotacionado 30°; KML e KMZ no estilo do Google Earth
com pastas aninhadas, MultiGeometry, SchemaData e anel interno; catálogos em CSV de fabricante e
XLSX do openpyxl. Arquivos LAS de todas as versões e formatos de ponto (um no SAD 69, uma cópia
comprimida) e arquivos DGN V7 em 2D e 3D, também gravados por escritores independentes, são
conferidos por `las_test.dart` e `dgn_test.dart`. `test/core/formats_test.dart` importa cada arquivo
do script e confere posições, elevações, nomes e camadas, e grava todas as exportações em
`build/formats`, que `tool/formats/check_exports.py` valida com ezdxf (auditoria), LibreDWG
(`dwgread`, `dwg2dxf`), lxml (KML, SVG), openpyxl, pypdf e as regras do RFC 7946 para GeoJSON. Essa
bateria encontrou e corrigiu: atributos DBF em UTF-8 lidos como Latin-1; shapefile local sem `.prj`
tomado por lat/lon; sinal invertido na rotação de world files e do ModelTransformation; blocos, cotas
e polilinhas 3D ignorados em DXF e DWG; handles relativos, bits de xref em R2007+ e ordem do
cabeçalho de objetos em R13/R14 no leitor DWG; nomes com aspas de polegada (1/2") quebrando a
leitura de catálogos XLSX.

### 24.12 Projeto e catálogos

O projeto `.oci.json` e o catálogo `.oci.cat` são JSON com chave `format` e `version`; a estrutura
está no README (seção 11) e em `catalogs/README.md`. A decisão de embutir o catálogo no projeto torna o
arquivo autossuficiente e legível; a biblioteca de blocos de usuário também viaja no projeto, e as
exportações DXF e DWG a gravam como definições de bloco.

---

## 25. Desempenho e arquitetura de software

- **Motor em Dart puro** (`lib/core`, cerca de 74 mil linhas), sem Flutter, executado num Web Worker
  no navegador e num isolate no desktop. O protocolo (`design_job.dart`) envia o projeto em JSON sem
  imagens e recebe progresso, resultados e as entidades redimensionadas; um contador de edições
  descarta os resultados de um projeto alterado durante o cálculo. O mesmo motor roda na VM do Dart
  por trás da linha de comando `bin/oci.dart` (design, analyze, check, export, bom) e é uma biblioteca
  à parte, `lib/core/api.dart`, documentada com exemplos executáveis em `docs/API.pt-BR.md`.
- **Índice espacial**: R-tree estática empacotada por Sort-Tile-Recursive (Leutenegger et al.,
  1997): itens ordenados por x, fatiados em √P faixas, cada faixa ordenada por y e cortada em folhas
  de 12 itens; os nós pais são empacotados da mesma forma até a raiz. Construção O(n log n) a cada
  edição, consulta O(log n + k) com os índices devolvidos em ordem de desenho. Medido com 40 mil
  entidades: construção em cerca de 30 ms, consulta da janela visível em 9 µs contra 700 µs da
  varredura linear. O painter, a seleção, a janela de seleção e o snap consultam o índice.
- **Prancheta**: a cena (mapa base, entidades, resultados, rótulos) é gravada uma vez por mudança do
  que ela mostra e desenhada a partir de uma imagem enquanto só o cursor se move; o marcador de snap,
  a prévia da ferramenta e o item sob o cursor são pintados por cima. As chamadas de desenho são
  agrupadas por estilo e os vértices a menos de um pixel são omitidos. No CanvasKit um traço
  suavizado com mais de um pixel físico é rasterizado na CPU sobre os limites do seu caminho, por
  isso as linhas de 1 px são hairlines numa tela comum e os traços mais largos vão em segmentos
  separados com pontas quadradas (quadriláteros na GPU); uma vista com mais de 40 mil vértices de
  linhas numa tela de alta densidade desenha as linhas de 1 px como hairlines. Uma cena que leva mais
  de 20 ms acompanha o arrasto e o zoom como imagem deslocada e é redesenhada nítida 120 ms depois que
  a vista para (ou a cada algumas centenas de milissegundos enquanto ela continua se movendo). O snap
  testa só os segmentos ao alcance do cursor (cruzar todos os segmentos de duas curvas de nível
  longas levava segundos). Medido no Chrome num projeto de 34 mil entidades em 178 camadas, em tela
  comum e em tela 2×: mover o mouse de 600 e 880 ms para menos de dois quadros, um passo de arrasto
  de 320 e 465 ms para menos de dois quadros, um passo de zoom de 0,8 e 1,6 s para cerca de 85 ms,
  uma seleção de 630 e 935 ms para cerca de 180 ms.
- **Agregação de emissores**: cada lateral vira até 100 nós com emissores agrupados
  (`maxNodesPerLateral`); um talhão de 44 fitas de 120 m tem 4400 nós e dimensiona em cerca de 2 s.
  Fitas de zonas vizinhas com pontas coincidentes são fundidas pelo construtor do grafo, o que dobra
  a zona e o tempo: os exemplos deixam faixas entre blocos.
- **Solver esparso**: LDLᵀ com ordenação por grau mínimo; a matriz das zonas ramificadas é quase
  uma árvore, sem preenchimento.
- **Desfazer**: snapshots das entidades a cada ação, até 150 passos enquanto as cópias guardadas
  somam menos de 400 000 entidades (um desenho grande guarda menos passos), com rótulos para o painel
  de histórico; cada vez do assistente de IA é um passo (seção 27.10).
- **Armazenamento**: chave/valor do navegador com autosave, recentes, versões e recuperação, dentro
  do limite de cerca de 5 MB por origem (3,5 MB por projeto). Um projeto com mais de 256 kB de JSON é
  guardado comprimido com gzip e codificado em base64, o que mantém projetos de dezenas de megabytes
  de JSON dentro da cota (o texto deles comprime cerca de dez vezes); a cópia automática avisa uma vez
  quando deixa de fora imagens embutidas ou não consegue guardar um projeto. A cópia feita depois de
  edições e cálculos é comprimida pelo navegador (`CompressionStream`, base64 pelo `FileReader`) em
  segundo plano e guardada quando termina; comprimi-la em Dart na thread da interface travava o app
  por cerca de um segundo depois do cálculo do exemplo de cultura em linhas e por oito segundos num
  projeto de 34 mil entidades. As mensagens do assistente de projeto vêm prontas do worker junto com
  o cálculo (a verificação por trás delas triangula o terreno), e as mensagens de progresso do
  cálculo não invalidam o desenho guardado.
- **Link de compartilhamento** (`share_link.dart`): um projeto viaja dentro do próprio endereço,
  comprimido com gzip e codificado em base64url no fragmento (`#p=…`), a parte de um endereço que os
  navegadores nunca enviam a servidor algum; imagens embutidas e resultados do projeto ficam de fora
  (quem recebe calcula de novo), um link com mais de 60 000 caracteres gera um aviso (aplicativos de
  e-mail e de conversa podem cortá-lo) e um com mais de 1,8 milhão é recusado.
- **Início sem rede**: a versão web é um progressive web app com o seu próprio service worker,
  registrado depois que o aplicativo desenhou a tela e o navegador ficou ocioso; ele guarda em cache os
  arquivos de uma versão, cada um conferido contra o seu SHA-256, um cache por versão, e uma página
  mantém a versão com que começou. Depois da primeira visita o aplicativo inicia sem rede; blocos de
  mapa, downloads de elevação e de clima e o assistente de IA continuam precisando dela.
- **Interface**: 20 idiomas, da direita para a esquerda em árabe e urdu; projetada também para toque;
  o aplicativo web funciona em celulares. As pastas `android/` e `ios/` existem, mas nenhuma versão
  móvel nativa é produzida ou testada.
- **Temas**: escuro (o padrão) e claro, trocados na hora em Ver → Tema (ou seguindo o sistema) sem
  perder os projetos ou os diálogos abertos. Toda cor da interface é um de 76 tokens de uma paleta com
  um valor escuro e um claro (`lib/app/theme.dart`), lido na hora de desenhar; os tokens de texto do
  tema claro são conferidos para um contraste WCAG AA de 4,5:1 sobre toda superfície clara
  (`test/widget_theme_test.dart`). Na tela branca do tema claro as cores do desenho e dos resultados
  seguem a regra usual de exibição dos CADs: cores brancas e quase brancas (luminância relativa acima
  de 0,85) são desenhadas quase pretas, as outras cores claras são escurecidas em luz linear até uma
  luminância de 0,20 (4,2:1 contra o branco) mantendo o seu matiz, e as mais escuras são desenhadas
  como são; a seleção é magenta em vez de amarela. Os dados nunca mudam de cor, e as plotagens e as
  exportações (PDF, SVG, PNG e os arquivos CAD) são papel e não seguem o tema da interface.
- **Site**: páginas geradas com conteúdo HTML real para os buscadores, porque o Flutter desenha em
  canvas (ver README, seção 13).

---

## 26. Assistente de projeto

Módulos `advisor.dart` (só leitura) e `auto_fix.dart`; painel `advice_panel.dart` (aba Mensagens e
verificação do projeto).

- **Conselhos**: a verificação do projeto, uma varredura das configurações e as mensagens dos
  últimos resultados viram uma lista só; cada problema tem gravidade (erro, aviso, nota), os itens e
  a zona / turno envolvidos, uma explicação (por que importa, como resolver) e as correções
  automáticas que se aplicam. O mesmo problema vindo de vários turnos aparece uma vez, com os turnos
  listados; sem nenhuma fonte de água, os itens desconectados da linha principal não são repetidos.
  Toda mensagem, as novas incluídas (classe de pressão, estações valve-in-head, inversores de
  frequência, NPSH, o pacote de aspersores, o braço de canto, a taxa variável e o projeto elétrico das
  máquinas, materiais sem preço), tem a sua explicação, e um botão "Perguntar à IA" a entrega ao
  assistente de IA (seção 27).
- **Verificação do projeto** (`design_check.dart`), entre outras: uma zona que mistura gotejamento
  ou borbulhadores com emissores aéreos, ou aspersores aéreos cuja água por área molhada (a vazão
  sobre o setor que molham na pressão nominal, no círculo do maior alcance da família) difere mais de
  1,8 vez (sprays com rotores, setores parciais com o bocal de um círculo completo), pois um único
  tempo de rega não serve aos dois (`zone_mixed_emitters`); estações valve-in-head que nenhum turno
  lista quando o projeto tem turnos (`vih_not_in_flow`).
- **Configurações impossíveis**: limites de velocidade fora de 0,3–5 m/s, horas por ano fora de
  1–8760, juros fora de 0–50 %, prazo fora de 1–100 anos, rendimento da bomba fora de 20–95 %,
  tarifa negativa, tolerância de conexão fora de 1 mm–1 m, variação na zona fora de 0–60 %,
  temperatura da água fora de 0–60 °C, nenhum tubo habilitado no catálogo para um uso que o projeto
  exige, máximos da fonte abaixo dos valores de projeto, zonas fora de todos os turnos, turnos
  vazios, durações zero, pressão de emissor ou fita fora da faixa do bocal / fita (o que esvazia a
  janela de pressão) e rotação de bomba fora de 40–130 %.
- **Correções** (um passo de desfazer cada): ligar um item desconectado ao tubo ou item compatível
  mais próximo a até max(2 m, 20 × tolerância), cortando o tubo sob ele (a válvula prefere o ponto
  onde a linha principal encontra o início da sua zona); excluir tubos de comprimento zero; remover
  vértices repetidos e itens duplicados; renomear zonas repetidas; pressão da fonte calculada; a
  bomba do catálogo de menor custo de ciclo de vida que atende todos os duties da fonte (só
  submersas quando a água está mais funda que a altura de sucção), ou uma nova no tubo que sai da
  fonte; o tubo mais barato do mesmo uso cuja classe, reduzida pela temperatura da água, aguenta a
  pressão em regime (ou regime + golpe) com diâmetro interno não menor; a menor válvula de controle
  cuja faixa cobre a vazão da zona; um modelo do catálogo para um que falta; turnos reagrupados por
  first-fit decreasing para que nenhum passe da vazão de projeto da fonte (as estações valve-in-head
  programadas indo junto); conexões genéricas; parâmetros padrão; um turno novo para as zonas
  deixadas de fora; a pressão nominal do emissor; os fios mais grossos do catálogo habilitados (ou os
  fios padrão acrescentados) quando um solenoide recebe tensão de menos; o próximo tamanho padrão de
  controlador (4, 6, 8, 9, 12, 16, 24, 32, 48 estações…) quando um controlador tem mais válvulas que
  estações. Ligar tubos que se cruzam e pôr a fonte na única ponta livre da linha principal supõem a
  intenção: são oferecidos, nunca aplicados sozinhos.
- **Corrigir automaticamente**: rodadas de correções seguras — desenho e configurações primeiro,
  depois as que precisam de resultados —, cada uma seguida de um cálculo, até uma rodada não mudar
  nada (no máximo seis), tudo num único passo de desfazer; uma correção já tentada não se repete.
- **Otimizar**: dimensionamento LP com o custo da energia, opcionalmente todos os tubos livres, a
  menor válvula adequada por zona e a bomba de menor custo de ciclo de vida por fonte; o resultado
  só fica quando tem menos erros ou, com os mesmos, menor custo anual (investimento anualizado +
  energia).
- Depois de um cálculo com erros a aba Mensagens abre sozinha e o seu rótulo conta os problemas.

---

## 27. Assistente de IA

O assistente de IA opcional (Projeto → Assistente de IA…; comandos AI, IA, ASK; um botão na barra de
status em janelas com pelo menos 1000 pixels de largura; o botão "Perguntar à IA" de cada mensagem do
projeto) é um agente embutido no programa: uma conversa com um grande modelo de linguagem que lê o
projeto aberto, planeja, faz perguntas, altera o desenho e as configurações com a permissão do
usuário e executa o próprio motor do programa para conferir o seu trabalho. Ele abre num painel
encaixado ao lado do desenho (400 pixels de largura; uma folha inferior sobre o desenho nos
celulares), que fica aberto enquanto o agente trabalha, de modo que o usuário vê o desenho mudar,
digita novas instruções e o interrompe a qualquer momento; cada aba de projeto tem a sua conversa. Ele
não tem servidor, como o resto do programa: o navegador (ou o aplicativo de desktop) chama o provedor
do modelo escolhido, a Anthropic ou a OpenAI, diretamente com a chave de API do próprio usuário para
esse provedor, e o provedor cobra o uso na conta do usuário; o painel mostra uma estimativa dos
tokens e do custo de cada resposta e da conversa. O laço, as ferramentas, as permissões e os dados do
projeto não dependem do provedor (`lib/core/ai/agent_loop.dart`, `project_context.dart`, as
ferramentas de `lib/app/ai/`); os dois clientes e os seus formatos são as seções 27.1 a 27.3.

### 27.1 Provedores e modelos

`lib/core/ai/llm.dart` reúne o que o assistente precisa de qualquer provedor: os modelos (`AiModel`,
com provedor, nível e preços de lista), os tokens e o seu custo estimado (`AiUsage`), os erros
(`AiError`), o cancelamento (`AiCancel`), as partes de uma mensagem e a troca HTTP como uma função
injetada (`AiTransport`: fetch com um abort controller no navegador, o corpo lido como fluxo, sem
cookies nem referrer; `HttpClient` no desktop; um falso roteirizado nos testes). Dois clientes
implementam `AiClient`: `AnthropicClient` (`claude_api.dart`, a API Messages) e `OpenAiClient`
(`openai_api.dart`, a API Responses); os nomes da primeira versão, só da Anthropic (`ClaudeApi`,
`ClaudeModel`…), continuam como apelidos.

| Provedor | Nível | Modelo (id) | US$ por milhão de tokens, entrada / saída | Observações |
|---|---|---|---|---|
| Anthropic | topo | Claude Fable 5.1 (`claude-fable-5-1`) | 10 / 50 | raciocínio sempre ligado; exige retenção de dados de 30 dias; vezes longas |
| Anthropic | topo | Claude Opus 5.5 (`claude-opus-5-5`) | 4 / 20 | o padrão |
| Anthropic | intermediário | Claude Sonnet 5.5 (`claude-sonnet-5-5`) | 2 / 10 | |
| Anthropic | rápido | Claude Haiku 5.5 (`claude-haiku-5-5`) | 0,1 / 0,5 | acima de 100 000 tokens de entrada, 5 × |
| OpenAI | topo | GPT-6 Astra (`gpt-6-astra`) | 10 / 50 | vezes longas |
| OpenAI | intermediário | GPT-6.1 Sol (`gpt-6.1-sol`) | 2 / 10 | |
| OpenAI | rápido | GPT-6 Luna (`gpt-6-luna`) | 0,1 / 0,5 | |
| OpenAI | intermediário | GPT-6 Sol (`gpt-6-sol`), GPT-5.6 Terra (`gpt-5.6-terra`) | 2 / 10; 2 / 12 | versões anteriores |

Leituras e gravações de cache têm os seus próprios preços de lista (gravações a 1,25 vez o preço de
entrada, a taxa do cache de cinco minutos da Anthropic). Na OpenAI, prompts acima de 272 000 tokens de
entrada custam o dobro dos preços de entrada e de cache e 1,5 vez o preço de saída. Todo modelo aceita
os cinco níveis de esforço (low, medium por padrão, high, xhigh, max: `output_config.effort` na
Anthropic, `reasoning.effort` na OpenAI). Os modelos de vezes longas têm tempos de espera maiores
(seção 27.2). O custo de uma resposta é calculado pelo preço do modelo que de fato a atendeu (um
fallback de recusa pode ser outro modelo, o Claude Opus 5 ou o Opus 4.8, precificados embora não
oferecidos), com as iterações de compactação da Anthropic somadas às contagens do nível superior.
Trocar para outra empresa, ou entre modelos da OpenAI, começa uma conversa nova (a anterior não é
enviada); um modelo Claude pode assumir a conversa de outro modelo Claude. O Claude Fable 5.1 pedido
por uma organização sem retenção de dados de 30 dias é recusado pela API; o erro é reconhecido e a
mensagem sugere o Claude Opus 5.5.

### 27.2 Requisições e fluxos

**Anthropic** (`POST https://api.anthropic.com/v1/messages`, `anthropic-version: 2026-10-21`). Os
cabeçalhos levam a chave (`x-api-key`), no navegador `anthropic-dangerous-direct-browser-access: true`
(sem ele a API não envia cabeçalhos de outra origem e o navegador bloqueia a resposta) e
`anthropic-beta` com os betas que a requisição usa (`server-side-fallback-2026-07-01`,
`task-budgets-2026-03-13`, `context-management-2025-06-27`, `compact-2026-01-12`). O corpo: o modelo,
`max_tokens` 64 000, `stream: true`, o prompt de sistema como um bloco de texto com um ponto de quebra
de cache, as ferramentas numa ordem fixa, cada uma com `eager_input_streaming: true` (as entradas
chegam em fluxo à medida que são geradas, e é por isso que o laço confere ele mesmo cada entrada), as
mensagens desde a última compactação, `thinking: {type: "adaptive"}` (fora no Fable 5.1, que sempre
raciocina e não aceita esse ajuste), `output_config` com o esforço e, no Opus 5.5, no Sonnet 5.5 e no
Haiku 5.5 quando há teto de gasto, um orçamento de tarefa (`task_budget: {type: "tokens", total}`, o
teto dividido pelo preço de saída, no mínimo 20 000 tokens) pelo qual o modelo se orienta, um
`cache_control` no nível superior (cache automático da conversa que cresce), `fallbacks: "default"` no
Fable, no Opus e no Sonnet (uma requisição que um classificador de segurança recusa é respondida por
outro modelo em vez de falhar) e a gestão de contexto da seção 27.5. O fluxo (server-sent events):
`message_start` (modelo, uso), `content_block_start`, `content_block_delta` (texto, raciocínio,
assinatura, o JSON da entrada de uma ferramenta, citações, um resumo de compactação) e
`content_block_stop`, `message_delta` (o motivo da parada com os seus detalhes: a categoria e a
explicação de uma recusa), `message_stop`, `error` e `ping`. Os blocos de raciocínio voltam ao
histórico sem alteração, com as suas assinaturas; depois de um fallback no meio de uma resposta, os
blocos de raciocínio e de uso de ferramentas antes do último marcador de fallback ficam de fora
(mantido o seu texto) e o marcador é descartado.

**OpenAI** (`POST https://api.openai.com/v1/responses`). A chave vai como `authorization: Bearer`. O
corpo: o modelo, `instructions` (o prompt de sistema), `input` (a conversa: os itens de saída
exatamente como voltaram, as saídas das funções, as mensagens do usuário), as ferramentas de função
com `strict: false` (os esquemas têm campos opcionais, que o modo estrito não admite; o laço confere
ele mesmo as entradas), `reasoning: {effort}`, `max_output_tokens` 64 000, `stream: true`,
`store: false` (nada fica guardado do lado da OpenAI para requisições posteriores) com
`include: ["reasoning.encrypted_content"]`, de modo que os itens de raciocínio voltam cifrados e são
reenviados na requisição seguinte, e a gestão de contexto da seção 27.5. As imagens são partes
`input_image` (data URLs, detalhe "auto") e os PDFs partes `input_file` (nome do arquivo e data URL).
O fluxo: `response.created`, `in_progress` e `queued`; `response.output_item.added` e `.done`;
`response.output_text.delta`; `response.function_call_arguments.delta`; `response.completed`;
`response.incomplete` (o limite de tamanho, ou `content_filter`, uma recusa); `response.failed` (códigos
de política como `bio_policy`, `misalignment_policy_violation`, `invalid_prompt` e
`image_content_policy_violation` são recusas); e `error`. As partes de recusa de uma mensagem também
são uma recusa. Os tokens de entrada em cache vêm de `input_tokens_details` (tokens lidos do cache e
gravados nele).

**Erros e novas tentativas** (os dois clientes): os tipos de erro são distinguidos (autenticação,
permissão, cobrança — o `insufficient_quota` da OpenAI —, não encontrado ou um modelo que a conta não
pode usar, requisição inválida, requisição grande demais — `context_length_exceeded` —, limite de
taxa, sobrecarga, servidor, rede, tempo esgotado, fluxo interrompido, retenção de dados);
sobrecargas, limites de taxa e erros de servidor e de rede são tentados de novo no máximo duas vezes,
depois do `retry-after` (ou `retry-after-ms`) que a API pede, até 30 s, ou de uma espera exponencial
(2 s, 4 s para limites de taxa, 1,5 s para a rede, dobrando), nunca depois que parte da resposta
chegou. Uma requisição esgota o tempo sem linha de status em 90 s, ou sem dados por 180 s (300 s e
600 s para os modelos de vezes longas, que podem raciocinar por minutos). Um campo opcional que um
modelo recusa (um erro de requisição inválida que cita `fallbacks`, `task_budget`, a gestão de
contexto ou a limpeza de resultados de ferramentas) é retirado e a mesma requisição é enviada de novo
na hora, e fica de fora para esse modelo pelo resto da sessão; uma combinação recusada de edições de
contexto retira primeiro a limpeza, depois a compactação. A chave é removida de todo texto de erro,
inclusive as suas cópias mascaradas.

### 27.3 Um laço, dois formatos

O laço nunca olha dentro dos formatos dos provedores. `llm_formats.dart` reúne os dois num só lugar
(`AnthropicFormat`, `OpenAiFormat`): as definições de ferramentas, a mensagem do usuário (texto,
imagens, PDFs), os resultados das ferramentas (texto e imagens, com um indicador de erro ou, na
OpenAI, cujas saídas de função não têm um, o prefixo `Error: `), as notas do programa, e as chamadas
de ferramentas e o texto de uma resposta. O histórico de uma conversa é guardado no formato do
próprio provedor e só cresce: uma resposta volta exatamente como veio, e essas funções só montam
entradas novas e leem as antigas. Uma rodada de resultados é, na Anthropic, uma mensagem do usuário
com todo `tool_result` primeiro, depois o que o usuário escreveu nesse meio-tempo, depois a nota do
programa como um bloco de texto (o que mantém válido o histórico que só cresce, qualquer que seja a
continuação da vez); na OpenAI, os itens `function_call_output`, depois uma mensagem do usuário com o
que ele escreveu nesse meio-tempo, depois a nota como uma mensagem `developer`. Cada formato também
lê de volta as suas próprias formas, e os testes conferem que todo tipo de entrada é lido de volta sem
alteração e que uma troca inteira convertida de um formato para o outro e de volta não perde nada
(`ai_formats_test.dart`). Uma entrada de ferramenta cujo JSON não é interpretável é guardada bruta e
respondida com um resultado de erro `INVALID_JSON`.

### 27.4 O laço de agente

Uma tarefa começa com a mensagem do usuário e é uma sequência de requisições (`AgentLoop.run`): o
modelo responde com texto e, possivelmente, chamadas de ferramentas; o programa confere cada chamada
contra o JSON schema da ferramenta (tipos, enums, campos obrigatórios e desconhecidos,
recursivamente, e o máximo de itens que uma lista pode ter), executa-a no projeto aberto e devolve
todos os resultados, toda chamada respondida e em ordem; o modelo continua até encerrar a sua vez sem
ferramentas, até o limite de etapas (uma etapa é uma requisição; 50 por tarefa por padrão, de 5 a
200), até o teto de gasto (US$ 2 por tarefa por padrão; de 0,5 a 20, ou nenhum) ou até o usuário
apertar Parar. Na penúltima etapa, uma nota pede ao modelo que não chame mais ferramentas e diga o
que fez e o que falta; a 80 % do teto uma nota, uma única vez, pede que termine a etapa em que está e
pare; passado o teto nenhuma nova requisição é feita; as chamadas pedidas na última etapa, ou depois
de Parar, são respondidas com um resultado de erro que diz isso; e uma tarefa interrompida pelo
limite de etapas ou pelo teto mostra um botão Continuar. As mensagens digitadas enquanto o agente
trabalha ficam na fila ("Mandar na próxima etapa") e chegam a ele com a próxima rodada de resultados
de ferramentas, marcadas como escritas nesse meio-tempo; o que ainda estiver na fila quando a vez
termina vira a próxima mensagem. Uma recusa, ou uma chamada de ferramenta cortada pelo limite de
tamanho, descarta a resposta com uma mensagem de erro; quando nada voltou, a pergunta e os seus
anexos ficam prontos para serem enviados de novo. Resultados com mais de 16 000 caracteres são
cortados com uma nota pedindo menos (um filtro, paginação). O texto chega ao painel em fluxo à
medida que é gerado, com uma linha de estado (pensando, executando uma ferramenta, esperando uma
aprovação, esperando antes de uma nova tentativa) e o tempo decorrido.

### 27.5 Gestão de contexto

As tarefas longas mantêm as suas requisições limitadas no servidor, onde o modelo o aceita (um
ajuste, ligado por padrão; a conversa inteira continua no painel):

- **Anthropic**: compactação por limiar (`compact_20260112`, disparada em 150 000 tokens de entrada;
  a API não aceita menos de 50 000): o servidor resume a conversa anterior num bloco de compactação
  que volta com a resposta, e daí em diante só as mensagens a partir desse bloco são enviadas. A
  limpeza de resultados antigos de ferramentas (`clear_tool_uses_20250919`, disparada em 80 000
  tokens de entrada, mantidos os quatro últimos usos de ferramentas, pelo menos 10 000 tokens limpos
  de cada vez) tira imagens e tabelas antigas da cópia do servidor, nunca os resultados das notas, do
  playbook, do manual, das perguntas, do plano, da lista de tarefas e da busca de operações.
- **OpenAI**: compactação no servidor (`context_management` com `compact_threshold` 200 000): depois
  de um item de compactação, a entrada começa nele. As imagens dos resultados de ferramentas além das
  três mais novas são trocadas por uma nota curta quando passam de seis (em degraus, para que o prefixo
  em cache mude raramente), só na requisição: o histórico guardado e as imagens do próprio usuário
  ficam.

Uma compactação é anunciada na conversa.

### 27.6 Ferramentas, operações e cobertura

70 ferramentas vão com cada requisição, numa ordem fixa, pois fazem parte do prefixo em cache (as suas
definições ocupam cerca de 88 000 caracteres, uns 22 000 tokens, em cache junto com o prompt de
sistema). Cada uma é uma camada fina sobre o controlador e o motor, de modo que o modelo trabalha com
os números do próprio programa e toda alteração é um passo de desfazer comum:

- **leitura**: resumo do projeto, itens por tipo, camada ou zona, um item com as suas propriedades e
  as linhas de relatório que o citam, parâmetros, busca no catálogo, tabelas de relatório, mensagens
  do projeto, cotas, medições; as análises (transientes, a simulação de 24 horas, criticidade, vazões
  sob demanda, agrupamento por energia, uniformidade), a classificação de bombas e as sugestões de
  ventosas; selecionar e aproximar a vista de itens e mostrar uma mensagem;
- **alteração**: itens (criar, atualizar, excluir, transformar), parâmetros, catálogo (itens lidos de
  uma ficha técnica de fabricante que o usuário anexou, cada valor conferido antes da inserção;
  remover um item em uso é recusado), turnos, camadas, dados do projeto, orçamento e regras de
  rótulos; o cálculo do projeto, uma correção, corrigir automaticamente, otimizar; as automações da
  seção 19 (traçado de aspersores com zoneamento e roteamento, blocos de laterais, subdivisão de
  áreas, anéis de árvores, modelos esportivos, ajuste de pivô), áreas de vegetação (seção 20), bomba,
  ventosas, agrupamento por energia e rotas de fios; uma exportação (sempre confirmada);
- **imagens e o terreno** (seção 27.7); **o local**: `find_site` (um endereço ou nome de lugar pelo
  Nominatim do OpenStreetMap: no máximo oito buscas por conversa, com pelo menos um segundo entre
  elas, em cache, com a atribuição que os seus termos pedem), `set_site`, o mapa de fundo da tela,
  `download_terrain` e `download_climate` pelos downloads do próprio programa, e `import_attachment`
  para desenhos e arquivos de SIG que o usuário anexou (DXF, DWG, DGN, KML/KMZ, shapefile, GeoJSON,
  GPX, LandXML, IFC, EPANET, LAS, GeoTIFF; até 60 MB, nunca enviados ao modelo);
- **o próprio trabalho**: uma lista de tarefas que o usuário vê acima da conversa; `ask_user` (de uma
  a quatro perguntas com duas a quatro opções cada, respondidas em cartões, onde o usuário pode
  escrever uma resposta própria ou pular); `present_plan`; as notas de IA do projeto; os playbooks; os
  exemplos (listar, ler, abrir numa aba nova); e o manual (seção 27.8).

As descrições informam ao modelo as convenções: coordenadas em metros com x para leste e y para
norte, propriedades dos itens no SI como no arquivo do projeto, relatórios nas unidades de exibição
do projeto, ids consultados antes de serem usados (um item também pode ser citado pelo nome, e um nome
ambíguo é um erro que lista os ids). As ferramentas conferem os próprios valores (faixas, pontos, ids)
antes de qualquer alteração, de modo que uma chamada recusada deixa o projeto como estava, com uma
mensagem com que o modelo pode agir; uma alteração é recusada enquanto um cálculo roda.

O resto do programa é alcançado por três despachantes. `find_operations` e `run_operation` cobrem 101
operações que não são enviadas, para que as requisições fiquem pequenas (edições de desenho como
offset, aparar, estender, dividir, matriz e alinhar, cotas e nuvens de revisão, blocos, camadas, a
vista, desfazer, refazer e o histórico, abas, terreno, georreferência e imagens, importações,
análises, calculadoras, máquinas, pranchas e o catálogo), cada uma com o seu esquema, o seu efeito e a
sua confirmação. `run_command` executa qualquer apelido de comando ou ação pelo nome: um comando que
abre um diálogo executa a operação por trás dele, sem o diálogo, e uma ferramenta de desenho que
depende dos cliques do usuário responde com o que chamar em vez dela. `get_setting` e `set_setting`
cobrem 133 configurações (os parâmetros de projeto, unidades, dados do projeto, orçamento, vista,
snap, padrões das ferramentas e opções do programa), tipadas e conferidas contra as suas faixas.
`docs/AI_TOOLS.md`, gerado a partir do mapa de cobertura (`ai_coverage.dart`) por
`widget_ai_coverage_test.dart`, lista toda função que um usuário alcança e o que o modelo usa para
ela: 45 ações de comando, 48 ferramentas de desenho, 311 apelidos de comando, 286 itens dos menus do
desktop e do celular, 70 diálogos e 624 das suas opções, 246 campos de painéis, 12 controles da barra
de status e 23 opções de vista, 1665 ao todo, das quais 1633 são cobertas e 32 não fazem sentido para
o modelo (a caixa Sobre, o idioma da interface…), cada uma com o seu motivo; nenhuma falta. O teste
falha quando um comando, uma ferramenta, um item de menu ou um diálogo novo não tem rota, ou quando uma
rota não leva a nada.

### 27.7 Visão

O modelo vê o projeto por imagens com um mapeamento exato (`view_snapshot.dart`, `vision_*.dart`):

- **`view_snapshot`**: um PNG do desenho como a tela o desenha (cores das camadas, a sobreposição de
  resultados) sobre um mapa de fundo — `current` (o mapa que a tela mostra), `satellite` (imagens
  aéreas: Esri World Imagery, ou o satélite do Google pela Map Tiles API quando o usuário informou uma
  chave do Google), `street` ou `none`; por padrão a imagem de satélite sempre que o projeto está
  georreferenciado, para que o modelo desenhe sobre o que de fato existe no terreno, senão o mapa da
  tela —, com uma grade métrica rotulada e, se pedidos, rótulos (ids ou nomes, itens hidráulicos
  primeiro, rótulos que se sobreporiam deixados de fora) e uma legenda das cores das camadas. Os blocos de mapa são baixados fora da tela no zoom da imagem (um pixel do bloco
  por cerca de um pixel da imagem; um nível abaixo de cada vez onde as imagens aéreas acabam, z17–18
  na maior parte das áreas agrícolas, e o ancestral mais próximo onde falta um bloco) e guardados em
  cache durante a conversa (400 blocos); a vista e o mapa de fundo do usuário nunca mudam, e só
  quando os blocos do mapa da tela não podem ser baixados fora dela a vista vai até lá por um momento
  e volta, o que o resultado informa. Uma imagem tem no máximo 1568 pixels no lado maior (1024 por
  padrão) e cerca de 1,15 megapixel, para que nenhum provedor a reescale e o modelo leia as posições
  na grade de pixels descrita.
- **O mapeamento**: toda imagem tem um id (`s1`, `s2`…; `u1`… para as que o usuário anexa; as 80 mais
  recentes guardadas por conversa) e informa o seu mapeamento: norte para cima, pixels quadrados, a
  caixa do mundo [minX, minY, maxX, maxY] e s metros por pixel, com x = minX + px·s e
  y = maxY − py·s para o pixel (px, py) contado a partir do canto superior esquerdo. `image_to_world`
  converte os pixels que o modelo escolhe em coordenadas do projeto, e pontos do projeto em pixels,
  exatamente, até 500 de cada vez, com a área, o perímetro e o centroide de um contorno fechado, de
  modo que o modelo nunca faz a conta; uma parte de uma imagem anterior pode ser mostrada de novo em
  resolução plena (`snapshot` com `pixel_bbox`).
- **`preview_geometry`** desenha pontos, polilinhas e polígonos propostos (até 30 formas e 5000
  pontos) em magenta sobre uma imagem nova, sem alterar o projeto, com as coordenadas de cada forma
  arredondadas a 0,01 m, o seu comprimento ou a sua área, e avisos (um contorno que cruza a si mesmo,
  um polígono sem área).
- **O terreno**: `terrain_picture` desenha o relevo a partir do modelo do terreno, um sombreamento
  iluminado do noroeste com cores por cota (verde no baixo, branco no alto, com a faixa) ou pelas
  classes de declividade da seção 23.1 ou pelo aspecto, curvas de nível rotuladas num intervalo
  redondo que dá de 10 a 15 linhas (ou num intervalo dado) e hachura onde as cotas estão longe de
  qualquer dado, sozinho ou sobre a imagem de satélite e sob o desenho, com o mesmo mapeamento;
  `terrain_profile` dá o terreno ao longo de uma linha ou de um item (comprimento, subida e descida, as
  declividades mais fortes, os extremos, os pontos altos locais onde o ar se acumula num tubo, e uma
  tabela de distância, x, y, z e declividade); `terrain_info` diz do que o modelo do terreno é feito e
  até onde as suas cotas são confiáveis.
- **As imagens do usuário**: o painel anexa uma imagem da vista atual com o seu mapeamento (para
  apontar coisas: "a linha principal ao longo desta estrada"), e um ajuste, desligado por padrão
  porque custa tokens, manda uma imagem do desenho junto com os resultados de cada rodada que alterou
  o projeto, para que o modelo confira o que fez.

As imagens do desenho e do mapa de satélite vão ao provedor de IA com a conversa, e os termos de uso
do provedor das imagens valem para elas, o que o painel informa.

### 27.8 Instruções, manual, playbooks e notas

O prompt de sistema (`ai_prompt.dart`; em inglês, a língua de trabalho do modelo; cerca de 13 300
caracteres, uns 3 300 tokens) é montado a partir do próprio programa: o que o programa é; os fatos de
que toda requisição precisa (os números vêm das ferramentas e pertencem ao desenho para o qual foram
calculados; metros com x para leste e y para norte; SI nas entradas das ferramentas, unidades de
exibição nos relatórios); como o cálculo transforma o desenho num grafo (os dois escopos, a
tolerância de conexão com o seu padrão real, o que se liga a quê, onde a linha principal começa e o
que ela precisa alcançar); o que um cálculo faz e quando um projeto está pronto; as permissões; como
usar as ferramentas e conduzir uma tarefa (uma lista de tarefas a partir de três etapas, as notas e o
playbook primeiro, os dados que faltam perguntados cedo numa só chamada); os índices dos playbooks e
do manual; e o idioma das respostas, que segue a interface, a menos que o usuário escreva em outro. As
instruções permanentes do usuário, das configurações, são acrescentadas (`<user_instructions>`, a
partir da conversa seguinte). Ele não tem dados do projeto e é fixo durante uma conversa, para que o
raciocínio anterior e o prefixo em cache continuem válidos.

`read_manual` entrega os detalhes sob demanda: 20 tópicos (desenho, entidades, parâmetros, catálogo,
cálculo, turnos, mensagens, verificação, valores, unidades, terreno, agronomia, máquinas, parte
elétrica, relatórios, ferramentas, operações, playbooks, erros comuns e um exemplo resolvido), vários
deles restringíveis a um item. As suas tabelas são geradas a partir do programa quando um tópico é
lido (todo tipo de item e toda chave com a sua unidade, o seu padrão e o rótulo do painel; todo
parâmetro de projeto com a sua chave no arquivo do projeto, a sua faixa e o seu efeito; todo código de
mensagem com a sua explicação e as suas correções; o catálogo; toda ferramenta e operação com
chamadas de exemplo; os valores que o motor usa), e as partes escritas são conferidas por
`widget_ai_manual_test.dart`, que falha quando falta uma chave de item, um parâmetro, um código de
mensagem, uma tabela de relatório ou uma ferramenta, quando um padrão escrito à mão difere do padrão
do motor, quando o texto cita uma ferramenta que não existe ou uma chamada de exemplo não cabe no seu
esquema, e que reexecuta o exemplo resolvido num projeto novo.

Os doze playbooks (`playbooks.dart`: pomar com gotejamento, culturas em linha com fita, estufa,
aspersores de paisagismo, campo esportivo, buraco de golfe, pivô central, linear, gotejamento por
gravidade, viveiro, pastagem, café em nível) são roteiros passo a passo escritos a partir de como os
quinze exemplos são montados: o que perguntar, as ferramentas em ordem, valores típicos e
verificações, cada um começando pela imagem de satélite e conferindo as formas traçadas antes de
criá-las. As notas de IA do projeto (os requisitos do cliente, as respostas do usuário, as decisões;
no máximo 8000 caracteres) ficam no arquivo do projeto (`aiNotes`), de modo que vão junto quando ele
é salvo ou compartilhado, são gravadas num passo de desfazer, lidas com a primeira mensagem de cada
conversa e editáveis nas configurações.

### 27.9 Dados do projeto

O que o modelo recebe sobre o projeto com a primeira mensagem (`buildProjectContext`) é um texto
compacto que o usuário lê antes de qualquer envio: todo número vem do que o programa já calculou — as
tabelas de relatório, as mensagens do projeto, os resultados do cálculo —, de modo que o assistente lê
exatamente o que os relatórios mostram, nas unidades do projeto, com um cabeçalho que nomeia as
unidades. O usuário marca as partes (a seleção primeiro, depois o resumo do projeto, as mensagens, os
resultados, os materiais, os parâmetros e o catálogo); o texto é determinístico para um dado estado do
projeto, de modo que a prévia é o que é enviado, e é limitado a 18 000 caracteres (cerca de quatro a
seis mil tokens), para que um desenho grande não vire uma conta grande. O orçamento é repartido entre
as partes por pesos (seleção 15 %, mensagens 20 %, resultados 30 %, materiais 10 %, catálogo 11 %,
projeto e parâmetros 7 % cada); uma parte que precisa de menos deixa o resto para as outras, e uma
parte encurtada diz quantas linhas ficaram de fora. A estimativa de tokens mostrada é grosseira (sem
tokenizador local: cerca de quatro caracteres latinos por token, menos para outras escritas). Os dados
podem ser anexados de novo a uma mensagem posterior, e o modelo lê mais com as suas ferramentas.

### 27.10 Permissões, o plano, desfazer e pontos de retorno

Toda ferramenta declara o seu efeito — leitura, alteração (um passo de desfazer), exportação (um
arquivo) ou rede (uma requisição a outro serviço que não muda nada) —, e um despachante assume o
efeito do que executa. O modo (`AgentPermission`) decide do que uma chamada precisa:

- **somente leitura**: alterações (os downloads de terreno e de clima entre elas, pois acrescentam
  dados ao projeto) e exportações são recusadas com uma explicação que o modelo repassa (ele pode
  descrever a alteração em vez de fazê-la), enquanto as consultas que não mudam nada (a busca de
  endereço, um pacote de catálogo num endereço) continuam funcionando, com a aprovação do usuário;
- **planejar primeiro**: o modelo explora com as ferramentas de leitura e apresenta um plano
  (`present_plan`, um cartão com "Aprovar e pedir antes de cada alteração", "Aprovar e aplicar
  automaticamente" e "Pedir mudanças"); as alterações são recusadas até a aprovação e então rodam no
  modo escolhido, dentro da mesma tarefa (as consultas que não mudam nada são perguntadas, como em
  somente leitura);
- **perguntar antes de cada alteração** (o padrão): um cartão com Aplicar, Pular e Parar para cada
  alteração e cada requisição a outro serviço (a busca do local, os downloads de terreno e de clima);
  uma alteração pulada volta ao modelo como recusada, para não ser repetida a menos que o usuário
  peça;
- **aplicar alterações automaticamente**: alterações e requisições a outros serviços valem à medida
  que chegam, mas exportações, a exclusão de mais de 20 itens, mudar uma georreferência existente e as
  poucas outras ações que não podem ser desfeitas continuam sendo confirmadas.

Cada vez da IA é uma entrada do histórico: a primeira alteração abre um grupo de desfazer e o fim da
vez o fecha, com um resumo do que mudou (itens acrescentados, alterados e removidos por tipo, e quais
configurações: parâmetros, catálogo, turnos, camadas, dados do projeto, orçamento, regras de rótulos)
e um botão "Desfazer estas alterações" que funciona enquanto nada mais mudou no projeto desde então;
os resultados que o assistente calculou depois da sua última alteração são mantidos. Cada mensagem do
usuário também é um ponto de retorno: "Voltar a este ponto" leva a conversa de volta a antes dela e o
projeto ao estado que tinha então, pelo histórico de desfazer (refazer o traz para a frente de novo),
estado encontrado pelo rótulo e pela hora do passo que levou a ele, pois as posições mudam quando
passos antigos são descartados; quando o histórico já não chega lá, só a conversa volta. A mensagem
volta à caixa de entrada.

Comandos rápidos na caixa de entrada: `/new`, `/clear`, `/cost` e `/plan` agem na hora (uma conversa
nova, o custo até agora, o modo de plano), e `/design`, `/check`, `/report`, `/quote` e `/export`
mandam um pedido pronto. A conversa pode ser salva em Markdown (as mensagens, cada chamada de
ferramenta com o seu resumo e o seu estado, as alterações e o custo), e uma resposta pode ser copiada
ou inserida no desenho como texto, como o memorial descritivo que o assistente redige a partir do
projeto.

### 27.11 O que é enviado, e as chaves

Nada é enviado antes de o usuário enviar uma mensagem. A requisição leva então a mensagem, os seus
anexos (imagens; PDFs como documentos ou, por escolha, o seu texto extraído no próprio dispositivo
pelo leitor de PDF da seção 24.9, que gasta muito menos tokens mas perde as figuras e o leiaute das
tabelas; arquivos de texto; até 20 MB cada; desenhos e arquivos de SIG só como uma nota de que estão
ali, para o `import_attachment`), os dados do projeto que o usuário marcou e as notas de IA do projeto
(com a primeira mensagem), as mensagens anteriores da conversa, o prompt de sistema e as definições
das ferramentas e, enquanto o modelo trabalha, os resultados das ferramentas que ele chama (tabelas,
itens, imagens). As ferramentas que consultam outros serviços (a busca de endereço, cotas, clima,
pacotes de catálogo num endereço) mandam a eles só o necessário e pedem a aprovação do usuário, salvo
quando as alterações valem automaticamente. A vista "Dados enviados" mostra o texto exato da próxima
mensagem, as instruções e as ferramentas.

Cada provedor tem a sua chave. Uma chave fica na memória durante a sessão, por padrão; com "Lembrar a
chave neste dispositivo" ela vai para o armazenamento do navegador, onde os scripts da página (as
estatísticas de visita do site entre eles) poderiam lê-la, o que o painel avisa. Ela nunca entra num
arquivo de projeto, no autosave, num link de compartilhamento ou numa exportação, vai só para o
endereço da API do seu provedor (`api.anthropic.com` ou `api.openai.com`), no seu cabeçalho, e é
removida de qualquer texto de erro.

### 27.12 Validação

`ai_agent_test.dart` cobre as requisições e o fluxo da Anthropic (a requisição que a API documenta,
os ajustes do Fable 5.1, orçamentos de tarefa e compactação onde o modelo os aceita, campos opcionais
retirados, a limpeza de resultados de ferramentas) e o laço (as suas ferramentas e o seu histórico,
entradas inválidas, os modos e o modo de plano, confirmações, o limite de etapas, o teto de gasto, as
mensagens escritas durante o trabalho, a parada, erros e novas tentativas, retenção de dados, recusas,
fallbacks e os seus preços, a chave só no seu cabeçalho); `ai_openai_test.dart` a API Responses (a
requisição, as saídas das funções, imagens e PDFs, a compactação, a retirada de imagens, os erros, a
lista de modelos); `ai_formats_test.dart` os dois formatos; `ai_context_test.dart` os dados do projeto.
Testes de widget cobrem as ferramentas, a visão (a ida e volta exata do mapeamento, a imagem de
satélite que deixa a vista e o mapa do usuário como estavam, imagens e perfis do terreno sobre
superfícies conhecidas), as operações, o mapa de cobertura, o manual e o agente inteiro (um projeto
pequeno das perguntas ao relatório, as mensagens escritas durante o trabalho, o ponto de retorno, o
teto e o Continuar, os comandos rápidos, o painel encaixado e a folha do celular). Todos rodam contra
modelos roteirizados: nenhum teste chama a rede.

### 27.13 Limites

O assistente precisa da rede e do serviço do provedor (não funciona sem conexão). No navegador, uma
chave que a OpenAI recusa parece uma falha de rede, pois esse erro vem sem cabeçalhos de outra origem
e o navegador o esconde (a mensagem avisa isso). O assistente é tão confiável quanto o modelo, e é
por isso que todo número sobre o projeto é lido do programa e toda alteração pode ser recusada,
desfeita ou voltada a um ponto de retorno; uma posição escolhida numa imagem vale o pixel que o modelo
escolhe (s metros). As imagens não pedem aprovação, embora baixem blocos de mapa; análises longas que
o modelo pede rodam na thread da interface; as conversas não são salvas com o projeto, por decisão de
projeto (um arquivo ou link compartilhado levaria a conversa e as suas imagens), mas ficam guardadas
no armazenamento do navegador (IndexedDB) por projeto, as 12 mais recentes com as imagens e os anexos
pequenos, até que a opção que as guarda seja desligada, o que as apaga; o uso é cobrado pelo provedor na conta da chave; e os clientes foram testados contra
falsos roteirizados das duas APIs, não contra os serviços reais.

---

## 28. Validação

A suíte tem cerca de 1.900 testes (`flutter test`). Os que validam os métodos contra referências:

| Teste | Referência |
|---|---|
| Hazen-Williams matches textbook value | Valor tabelado de manual de hidráulica |
| Darcy-Weisbach agrees with Hazen-Williams for smooth PVC | Coerência entre fórmulas em PVC liso (diferença de poucos por cento) |
| Swamee-Jain close to Colebrook | Erro < 1 % (Swamee & Jain 1976) |
| transitional cubic matches the turbulent slope at Re = 4000 (EPANET) | Polinômio de Dunlop como codificado no EPANET |
| Manning: 10.29·n²·L·Q²/D^(16/3); the solver uses them: one pipe between two reservoirs carries the flow of the law | Chow 1959; coerência do solver com cada lei |
| Christiansen F factor table values; Scaloppi adjustment | Tabelas de Keller & Bliesner; Scaloppi 1988 |
| pressure dependent emitters; PRV holds downstream pressure; two reservoirs in a loop split the flow | Casos do manual do EPANET |
| a PSV holds the upstream pressure at its setting and limits the flow accordingly; an FCV lets its flow setting through, or less when the head is not there | Modelos de válvula do EPANET |
| emitters under negative pressure (closed, no backflow, reopen) | Balanço de massa de emissores unidirecionais |
| converge level at the mean head across the closed links, whatever their size; drain down to their lowest emitter | Balanço das condutâncias dos trechos fechados |
| friction loss agrees with Christiansen estimate | Solver versus fator F |
| downhill slope raises end pressure; feed positions | Wu & Gitlin 1975 |
| a 95 m supply never gets PN 80 PVC; warm water derates the class | Redução por temperatura da ISO 1452-2 e da ISO 4427-1 |
| a 60 Hz pump on 50 Hz mains runs at 5/6 of the speed | Leis de afinidade |
| PVC celerity in expected range | 300 a 600 m/s em PVC |
| instantaneous closure: Joukowsky surge a·ΔV/g and the 4L/a period; slow demand stop: Michaud surge 2·L·V/(g·tc) | Joukowsky; Michaud; Wylie & Streeter 1993 |
| column separation: vapour cavity at the valve after the downsurge; run-down follows the pump boundary condition | DVCM (Bergant, Simpson & Tijsseling 2006); Wylie & Streeter 1993 |
| the inertia estimate grows with the power and falls with the speed | Thorley & Faithfull 1992 |
| a hill: high point, line end and valves on the long ascent and descent; orifice sizing by compressible flow | AWWA M51; escoamento isentrópico por orifício |
| a tank filled at constant inflow reaches the analytic level; a tank draining through a pipe follows the analytic curve | Soluções analíticas |
| FAO 59 Box 1 / Table 2: every section | Lamaddalena & Sagardoy 2000 |
| matches reference quantiles; reference sequence from the all-12345 state | Wichura 1988; L'Ecuyer 1999 |
| exact against a brute force over every start and block choice | Enumeração exaustiva |
| pressure-driven demand: full above the requirement, orifice below | Wagner, Shamir & Marks 1988 |
| one global factor: golden section recovers C = 120 from a pipe built with 150 | Verdade sintética |
| capital recovery factor; operating point | Fórmulas financeiras e de bombas |
| solenoid voltage by hand (valve B opening, A and C holding); voltage along the pair by hand, the cheapest wire that keeps 24 V | Lei de Ohm ao longo dos condutores e ao redor do par |
| Example 17, 18 and 20 (ETo); Example 28 and Box 15 (Kc); Example 41 (sparse cover) | Allen et al. 1998 (FAO-56) |
| worked example: ETc 7.6 in, rain 4.7 in; Table 2-43 cells for 3 in of soil water storage | NRCS NEH 623, capítulo 2 |
| Example 3: maize, river water of 1.2 dS/m | Ayers & Westcot 1985 (FAO-29) |
| the numerical Rb equals the closed form for equator-facing surfaces | Duffie & Beckman |
| eq. 10: 5 emitters 1.2 m apart wetting 2.26 m on 6 × 6 m trees give 38 % | FAO Irrigation Manual, módulo 9 |
| MAWA of a residential landscape in US units | MWELO, Apêndice B |
| worked example: 200 m furrow, 0.15 m³/min, advance about 65 min; the Strelkoff depletion terms of the worked iteration | Walker 1989 (FAO 45) |
| discharge of the sprinkler 1,200 ft from the pivot with 10 ft spacing: 10.69 gpm (eq. 11-44); sample calculation 11-17 | NRCS NEH 623, capítulo 11 |
| drop span by span with the motors beyond each span running (IEC 60364-5-52 Annex G) | IEC 60364-5-52 |
| sector pivot: same cycle time gives a proportionally lower application rate | Keller & Bliesner, capítulo 14 |
| every profile spreads the whole flow over the wetted circle; head-to-head spacing is uniform, wide spacing is not; wind moves the water downwind and keeps its volume | Balanço de volume; Keller & Bliesner, capítulo 5 |
| two lawns and three tree crowns, the areas within a few per cent | Cena aérea sintética de áreas conhecidas |
| marching squares: the outline of every region holds exactly the pixels it encloses | Propriedade do percurso de contorno |
| Delaunay of a plane reproduces the plane exactly; without the breakline the valley is bridged, with it the surface folds along the channel | Propriedade do interpolador linear; triangulação restrita |
| UTM inverse round trip; georeference from a lat/lon origin | Karney 2011 |
| SAD 69 and Córrego Alegre to SIRGAS 2000 agree with the Molodensky formula and round-trip | IBGE R.PR 1/2005 e R.PR 23/1989 |
| every version and point format: ground points on the plane | ASPRS LAS 1.4 |
| O CRC-16 confere com a soma gravada em arquivos reais; o LibreDWG aceita o arquivo | Arquivos reais e ferramenta independente |
| example_\<version\>: splines, hatches, solids and the ellipse like LibreDWG reads them | Entidades listadas pelo LibreDWG |
| is an AC1015 file in metres, ASCII, with handles and owners; LibreDWG reads it and converts it to DXF | Auditoria do ezdxf; LibreDWG |
| \<language\> runs shape like the reference engine | HarfBuzz |
| LP design meets the pressure window and costs no more than greedy | Otimalidade relativa do LP |
| an exchange converted from one format to the other and back loses nothing | Ida e volta entre os dois formatos de comunicação |
| pixel ↔ world mapping: square pixels, exact round trip, image_to_world both ways | Inversa exata do mapeamento das imagens |
| terrain profile on a plane: exact rise, fall, extremes and slope | Plano analítico |
| every action, tool, alias, menu item and dialog has a route for the AI | As listas de funções do próprio programa |

Os exemplos da galeria funcionam como testes de integração: os quinze projetos, nos 20 idiomas,
constroem, passam na verificação, dimensionam com todas as zonas dentro da janela e sem déficit
de fonte, imprimem cada célula de relatório como número simples, e batem com os arquivos publicados.
Todo trecho de código de `docs/API.md` (e da sua tradução, `docs/API.pt-BR.md`) é executado por
`test/core/api_examples_test.dart`.

---

## 29. Lacunas e trabalhos futuros

Do ponto de vista da pesquisa, o que a literatura e a prática de projeto sugerem como próximos passos:

1. **Malhas no LP**: o LP da linha principal de uma rede malhada é resolvido de novo com as vazões
   dos seus próprios diâmetros até a escolha se estabilizar, mas sobre caminhos em árvore; uma
   formulação exata (decomposição por laços ou programação não linear) continua em aberto.
2. **Transientes**: atrito não permanente (o modelo é quase permanente), características de bomba
   nos quatro quadrantes em vez do modelo simplificado de torque do desligamento, os transientes
   dentro das zonas (o estudo vê uma zona como um orifício na sua válvula) e a liberação distribuída
   de ar.
3. **Sprayline "unconnected"** automática.
4. **Exportação DWG e DXF**: versões mais novas que o R2000 (cores verdadeiras no DWG) e
   entidades como multileaders e tabelas.
5. **Qualidade da água**: risco de entupimento e química da água junto com a fertirrigação, e a
   dispersão do produto injetado (os tempos de deslocamento são de escoamento em pistão).
6. **Sistema elétrico**: diagramas de ligação de campo.
7. **Densograma com vento**: padrões medidos em dias de vento ou um modelo balístico de gotas em vez
   da deriva de primeira ordem.
8. **Colaboração**: edição simultânea, mantendo o princípio de não depender de servidor próprio (o
   compartilhamento por link já funciona sem um).
9. **Vegetação**: imagens no infravermelho próximo (índices de vegetação verdadeiros) e a altura do
   dossel a partir de um modelo de superfície separariam melhor gramado, arbustos e árvores do que a
   cor e a textura.
10. **Testes de navegador** para o comportamento em tempo de execução (idioma do sistema, início sem
    rede).

Limites atuais que o programa informa ao usuário: o navegador guarda cerca de 3,5 MB de texto por
projeto (depois da compressão); arquivos BigTIFF e rasters acima de 100 milhões de pixels são
recusados; levantamentos acima de 12 000 amostras são reduzidos para o TIN; LAS comprimido (LAZ), DGN
V8, PDFs criptografados e as imagens JPEG 2000 e JBIG2 dos PDFs não são lidos; o OpenTopoData só
funciona no aplicativo de desktop; as exportações CAD são R2000 (cores verdadeiras no DXF,
índices de cor no DWG) ou R12; o assistente de IA precisa da rede e só foi testado contra falsos
roteirizados das duas APIs de modelos; e nenhuma versão móvel nativa é produzida (o aplicativo web
funciona em celulares).

---

## 30. Glossário

| Termo (pt) | Inglês | Significado |
|---|---|---|
| Zona | Zone | Conjunto de tubos e emissores a jusante de uma válvula de controle |
| Linha principal | Mainline | Da fonte de água às válvulas de zona |
| Linha de derivação | Submain | Tubo de zona que alimenta as laterais |
| Lateral | Sprayline / lateral | Tubo com emissores igualmente espaçados |
| Fita / tubo gotejador | Tape / dripline | Lateral com emissores integrados |
| Turno | System flow | Válvulas que operam juntas |
| Duty | Duty | Vazão e pressão exigidas de uma fonte num turno |
| Janela de pressão | Pressure window | Faixa de pressão dos emissores que mantém a vazão dentro da tolerância |
| Telescopagem | Telescoping | Diâmetros decrescentes ao longo de um tubo |
| CU, DU, EU | idem | Coeficientes de uniformidade de Christiansen, do quartil inferior e de emissão |
| CRF | Capital recovery factor | Fator que anualiza um custo de capital |
| TIN / MDT | TIN / DTM | Modelo do terreno por triangulação |
| Linha de quebra | Breakline | Linha que a triangulação do terreno precisa seguir |
| GGA | Global Gradient Algorithm | Método de Todini-Pilati para redes |
| BOM | Bill of materials | Lista de materiais |
| PRV | Pressure-reducing valve | Válvula reguladora de pressão |
| PSV | Pressure-sustaining valve | Válvula sustentadora de pressão |
| FCV | Flow-control valve | Válvula controladora de vazão (o limitador de vazão de um hidrante) |
| Válvula mestra | Master valve | Válvula da linha principal que o controlador abre com cada zona |
| Estação valve-in-head | Valve-in-head station | Aspersores na linha principal, cada um com a sua válvula, que abrem juntos |
| Inversor de frequência | VFD | Acionamento de rotação variável de uma bomba |
| NPSH | Net positive suction head | Altura positiva líquida de sucção, disponível e requerida |
| MOC | Method of characteristics | Método das características para transientes |
| DVCM | Discrete vapour cavity model | Modelo de cavidade de vapor discreta da separação de coluna |
| EPS | Extended-period simulation | Simulação de período estendido: sequência de soluções permanentes no tempo |
| VRI | Variable-rate irrigation | Irrigação de taxa variável de um pivô |
| ETo, ETc, Kc | idem | Evapotranspiração de referência e da cultura, coeficiente de cultura |
| LR | Leaching requirement | Fração de lixiviação |
| ExG | Excess green | Índice de excesso de verde de uma imagem RGB |

---

## 31. Fontes

Hidráulica e redes:
- Rossman, L. et al. EPANET 2.2 User Manual, Analysis Algorithms: https://epanet-manual.readthedocs.io/en/latest/analysis_algorithms.html
- EPANET 2.2 Users Manual, EPA/600/R-20/133 (formato do arquivo de entrada); Rossman, L. A. (2000). EPANET 2 Users Manual.
- Todini, E.; Pilati, S. (1988). A gradient algorithm for the analysis of pipe networks. Computer Applications in Water Supply, vol. 1.
- Swamee, P. K.; Jain, A. K. (1976). Explicit equations for pipe-flow problems. J. Hydraulics Div. ASCE 102(5).
- Scobey (1930), a fórmula de atrito das laterais de aspersão de aço e de alumínio; Chow (1959), o n de Manning.
- Christiansen, J. E. (1942). Irrigation by sprinkling. Univ. California Bull. 670.
- Scaloppi, E. J. (1988). Adjusted F factor for multiple-outlet pipes. J. Irrig. Drain. Eng. 114(1): https://ascelibrary.org/doi/10.1061/%28ASCE%290733-9437%281988%29114%3A1%28169%29
- Wu, I. P.; Gitlin, H. M. (1975). Energy gradient line for drip irrigation laterals. J. Irrig. Drain. Div. ASCE 101(4).
- Keller, J.; Bliesner, R. D. (1990). Sprinkle and Trickle Irrigation. Van Nostrand Reinhold.
- Keller, J.; Karmeli, D. (1974). Trickle irrigation design parameters. Trans. ASAE 17(4).
- Chu, S. T.; Moe, D. L. (1972). Hydraulics of a center pivot system. Trans. ASAE 15(5).
- Alperovits & Shamir (1977). Water Resources Research 13(6) (redes malhadas dimensionadas por programação linear, resolvidas de novo com as novas vazões).
- Hazen-Williams versus Darcy-Weisbach em PE: https://iwaponline.com/aqua/article/74/8/493/108822/ ; https://elibrary.asabe.org/abstract.asp?JID=3&AID=25699 ; fatores C por material: Keller & Bliesner (1990)
- Emissores: https://doi.org/10.3390/w14071034 ; https://doi.org/10.3390/w18020244 ; https://workforce.libretexts.org/Bookshelves/Water_Systems_Technology/Irrigation_Systems_Management_(AET_021)/14:_Microirrigation/14.06:_Uniformity
- Uniformidade: Xue et al. (2023), Irrigation and Drainage: https://onlinelibrary.wiley.com/doi/abs/10.1002/ird.2837 ; https://www.sciencedirect.com/science/article/abs/pii/S1537511005002205
- Laterais: https://link.springer.com/article/10.1007/BF00273380 ; https://www.sciencedirect.com/science/article/abs/pii/S0378377417304079
- Fator de atrito: https://www.sciencedirect.com/science/article/pii/S2090447919300176
- Velocidade e golpe de aríete: ASAE S376.2 (tubulações termoplásticas de irrigação enterradas; velocidade de no máximo 1,5 m/s); Joukowsky: https://www.instrumentationblog.in/joukowsky-equation-water-hammer/
- Bombas: ANSI/HI 9.6.1 (margem de NPSH); as curvas e as leis de afinidade como no manual do EPANET 2.2.
- Classes de pressão e temperatura: ISO 1452-2, Anexo A (PVC-U); ISO 4427-1, Anexo A (PE, 50 anos); fichas técnicas da NBR 14312.
- Perdas localizadas: Crane TP-410; https://neutrium.net/articles/fluid-flow/pressure-loss-from-fittings-excess-head-k-method/
- NRCS National Engineering Handbook, Part 623, cap. 7 (Microirrigation) e cap. 11 (Sprinkler): https://www.wcc.nrcs.usda.gov/ftpref/wntsc/waterMgt/irrigation/NEH15/ch7.pdf , .../ch11.pdf
- FAO Irrigation Manual, módulos 8 e 9: https://www.fao.org/4/ai596e/ai596e.pdf
- Allen, R. G. et al. (1998). FAO Irrigation and Drainage Paper 56: Crop evapotranspiration.

Transientes e ventosas:
- Wylie & Streeter (1993). Fluid Transients in Systems.
- Chaudhry (2014). Applied Hydraulic Transients.
- Thorley & Faithfull (1992). Inertias of pumps and their driving motors; Thorley (2004). Fluid Transients in Pipeline Systems.
- Bergant, Simpson & Tijsseling (2006) (separação de coluna: a ponderação do modelo de cavidade de vapor discreta).
- AWWA Manual M51. Air-Release, Air/Vacuum, and Combination Air Valves.

Operação de redes:
- Clément (1966). Calcul des débits dans les réseaux d'irrigation fonctionnant à la demande. La Houille Blanche 5.
- Lamaddalena & Sagardoy (2000). Performance analysis of on-demand pressurized irrigation systems. FAO Irrigation and Drainage Paper 59.
- Bethery et al. (1981) (geração aleatória de configurações de hidrantes).
- L'Ecuyer (1999). Good parameters and implementations for combined multiple recursive random number generators. Operations Research 47(1).
- Wichura (1988). Algorithm AS 241: the percentage points of the normal distribution. Applied Statistics 37(3).
- Hyndman & Fan (1996) (quantis amostrais, definição 7).
- Wagner, Shamir & Marks (1988). Water distribution reliability: simulation methods. J. Water Resources Planning and Management 114(3).
- Jiménez-Bello, Martínez Alzamora, Bou Soler & Bartolín Ayala (2010). Methodology for grouping intakes of pressurised irrigation networks into sectors to minimise energy consumption. Biosystems Engineering 105(4).
- Carrillo Cobo, Rodríguez Díaz, Montesinos, López Luque & Camacho Poyato (2011). Low energy consumption seasonal calendar for sectoring operation in pressurized irrigation networks. Irrigation Science 29.
- Kiefer (1953). Sequential minimax search for a maximum. Proc. American Mathematical Society 4.
- Levenberg (1944). Quarterly of Applied Mathematics 2; Marquardt (1963). J. SIAM 11.
- Dijkstra (1959) (caminhos mínimos).
- Burt, O'Connor & Ruehr (1995). Fertigation. Irrigation Training and Research Center, California Polytechnic State University.
- Portaria Normativa MME nº 137, de 8 de junho de 2026 (janela do desconto da irrigação); Resolução Normativa ANEEL nº 1.000/2021, art. 186 (descontos).
- Resolução CONAMA nº 284/2001 (licenciamento ambiental de empreendimentos de irrigação).

Traçado, roteamento e fiação:
- Irrigation Association (2014). Landscape Irrigation Best Management Practices.
- Garcia-Castellanos & Lombardo (2007). Scottish Geographical Journal 123 (polo de inacessibilidade).
- Alpert, Hu, Huang, Kahng & Karger (1995). IEEE Trans. Computer-Aided Design 14(7) (compromisso Prim–Dijkstra).
- Takahashi & Matsuyama (1980). An approximate solution for the Steiner problem in graphs. Mathematica Japonica 24.
- IFAB, Regra 1 (o campo de jogo); World Athletics (a pista de 400 m); recomendações de construção de greens da United States Golf Association para o green e o seu colar.

Análise de imagens:
- Woebbecke, Meyer, Von Bargen & Mortensen (1995). Color indices for weed identification under various soil, residue, and lighting conditions. Trans. ASAE 38(1).
- Otsu (1979). A threshold selection method from gray-level histograms. IEEE Trans. SMC 9(1).
- Meyer & Neto (2008). Verification of color vegetation indices for automated crop imaging applications. Comput. Electron. Agric. 63(2).
- Gitelson, Kaufman, Stark & Rundquist (2002). Novel algorithms for remote estimation of vegetation fraction. Remote Sens. Environ. 80(1).
- Taubin (1995). Curve and surface smoothing without shrinkage. ICCV.
- Douglas & Peucker (1973). Algorithms for the reduction of the number of points required to represent a digitized line or its caricature. Cartographica 10(2).

Agronomia:
- Ayers & Westcot (1985). FAO Irrigation and Drainage Paper 29 Rev. 1; Maas & Hoffman (1977); Maas (1984).
- Savva & Frenken (2002). FAO Irrigation Manual, Module 9.
- Brouwer & Heibloem (1986). FAO Irrigation Water Management Training Manual No. 3.
- Smith (1992). FAO Irrigation and Drainage Paper 46.
- USDA-SCS (1970). Technical Release 21; NRCS National Engineering Handbook Part 623, cap. 2 (1993).
- USDA-NRCS National Engineering Handbook Part 652, Irrigation Guide (1997); USDA-SCS National Engineering Handbook Section 15, cap. 11, Sprinkle Irrigation (1983); USDA-NRCS Soil Survey Manual (Handbook 18).
- Rawls, Brakensiek & Saxton (1982). Estimation of soil water properties. Trans. ASAE 25(5): 1316–1320.
- Irrigation Association, SWAT climatologically based controllers 8th draft testing protocol (2008); US EPA WaterSense specification for weather-based irrigation controllers (2011).
- California Model Water Efficient Landscape Ordinance (California Code of Regulations, Title 23, §§ 490–495, revisão de 2015); Water Use Classification of Landscape Species (University of California Cooperative Extension).
- Schwartzman, M.; Zur, B. (1986). Emitter spacing and geometry of wetted soil volume. J. Irrig. Drain. Eng. 112(3): 242–253; Cruz-Bautista et al. (2016), Tecnología y Ciencias del Agua 7(1): 45–55.
- IEC 62253:2011, Photovoltaic pumping systems; IEC 61724-1 (performance ratio).
- Duffie & Beckman. Solar Engineering of Thermal Processes; Erbs, Klein & Duffie (1982); Klein (1977); Cooper (1969); Liu & Jordan (céu isotrópico).
- Open-Meteo historical weather API (archive-api.open-meteo.com; ERA5 e ERA5-Land, CC BY 4.0); NASA POWER daily point API (power.larc.nasa.gov).

Máquinas e irrigação por superfície:
- Heermann & Hein (1968) (vazão por saída de um pivô central).
- Kansas State University (2022). MF3608, Interpreting and Using Center Pivot Sprinkler Designs.
- Evans et al. (2013). Irrigation Science 31: 871–887 (irrigação de taxa variável).
- IEC 60364-5-52, Anexo G (queda de tensão); IEC 60228 (condutores); IEEE Std 399 (partida de motores); IEEE Std 446 (geradores).
- Seginer, Kantz e Nir (1991) (padrões de aspersores com vento).
- Walker & Skogerboe (1987); Walker (1989), FAO Irrigation and Drainage Paper 45.
- Elliott & Walker (1982) (método dos dois pontos); Strelkoff (1977) (recessão em faixas); Hart et al. (1980) (escoamento de espalhamento em faixas).
- NRCS National Engineering Handbook Part 623, cap. 4 (Surface irrigation); U.S. Bureau of Reclamation, Water Measurement Manual, cap. 13.

Terreno, geoprocessamento e algoritmos:
- Karney, C. F. F. (2011). Transverse Mercator with an accuracy of a few nanometers. Journal of Geodesy 85(8).
- Bowyer, A. (1981); Watson, D. F. (1981). Computing the n-dimensional Delaunay tessellation. The Computer Journal 24(2).
- Sloan, S. W. (1993). A fast algorithm for generating constrained Delaunay triangulations. Computers & Structures 47(3): 441–450 (triangulação de Delaunay restrita).
- Leutenegger, S. T.; Lopez, M. A.; Edgington, J. (1997). STR: a simple and efficient algorithm for R-tree packing. ICDE.
- Terrain Tiles no AWS Open Data (blocos terrarium: SRTM, GMTED, ETOPO1).
- Open-Meteo Elevation API: https://open-meteo.com/en/docs/elevation-api ; Copernicus DEM GLO-90.
- OpenTopoData: https://www.opentopodata.org/ (SRTM, ASTER).
- IBGE, Resolução do Presidente nº 1/2005 (SIRGAS 2000; parâmetros do SAD 69) e nº 23/1989 (parâmetros do Córrego Alegre).
- OGC 01-009 (WKT 1); ISO 19162:2019 (WKT 2); EPSG Geodetic Parameter Dataset.
- ASPRS LAS Specification 1.4 – R15 (2019); OGC GeoTIFF Standard 1.1; schema LandXML 1.2 (2008).

Formatos:
- Open Design Alliance. Open Design Specification for .dwg files (versão 5.4.1).
- LibreDWG: https://www.gnu.org/software/libredwg/ ; ezdxf (validação dos arquivos DXF).
- DXF Reference: a especificação publicada do formato (R12 a 2018).
- ESRI Shapefile Technical Description (1998); estrutura de arquivo do dBASE III; GeoTIFF Specification 1.8.2; OGC KML 2.3; RFC 7946 (GeoJSON) e The GeoJSON Format Specification rev. 1.0 (2008); GPX 1.1 Schema Documentation (2004); especificação ISFF do arquivo de projeto DGN V7 (1994).
- ISO 32000-1 (PDF 1.7) e PDF Reference 1.4 (Adobe); especificação OpenType 1.9 e os seus documentos de desenvolvimento de escritas; Unicode UAX #9 (algoritmo bidirecional), UAX #53 (renderização de marcas árabes) e ArabicShaping.txt; HarfBuzz (mecanismo de moldagem de referência dos testes).
- ISO 10303-21 (arquivo físico STEP); ISO 16739-1:2018 (IFC4 ADD2 TC1).
- ECMA-376 Office Open XML (SpreadsheetML).
- ASAE S376.2 (recobrimento mínimo de tubulações termoplásticas enterradas); Azevedo Netto, Manual de Hidráulica (submergência da sucção).

Assistente de IA:
- Anthropic Messages API, versão 2026-10-21 (https://api.anthropic.com/v1/messages): streaming, uso de ferramentas, raciocínio adaptativo, esforço, cache de prompts, o fallback de recusa no servidor, orçamentos de tarefa e gestão de contexto (compactação e limpeza de resultados de ferramentas).
- OpenAI Responses API (https://api.openai.com/v1/responses): eventos em fluxo, ferramentas de função, esforço de raciocínio, raciocínio cifrado com `store: false`, compactação no servidor.
- API de busca Nominatim do OpenStreetMap (nominatim.openstreetmap.org) e a sua política de uso (no máximo uma requisição por segundo, atribuição, dados sob ODbL).
