# Estudo técnico: CADs de irrigação, hidráulica de redes e as decisões do OpenCADIrrigation

> Tradução em português. A versão canônica, mantida em inglês, é [TECHNICAL_STUDY.md](TECHNICAL_STUDY.md).

Estudo iniciado em 15/09/2026 e ampliado em 16/09/2026. Este documento reúne a pesquisa que
orienta a arquitetura do OpenCADIrrigation (CAD de irrigação para o navegador):
o que os CADs comerciais fazem, a hidráulica e a agronomia que o motor implementa, com as
equações e exemplos numéricos, as formulações de dimensionamento, os algoritmos de terreno e de
desempenho, os formatos de arquivo estudados e as fontes. Onde uma fórmula aparece, o módulo que a
implementa está indicado, e o teste que a valida também.

Este documento não cita empresas nem produtos de software de terceiros; as fontes são normas,
literatura técnica e software de domínio público.

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
10. [Laterais e submains](#10-laterais-e-submains)
11. [Redes: o Global Gradient Algorithm](#11-redes-o-global-gradient-algorithm)
12. [Bombas e energia](#12-bombas-e-energia)
13. [Golpe de aríete e classes de pressão](#13-golpe-de-aríete-e-classes-de-pressão)
14. [Dimensionamento](#14-dimensionamento)
15. [Linha principal, turnos e fontes](#15-linha-principal-turnos-e-fontes)
16. [Lavagem, conexões e lista de materiais](#16-lavagem-conexões-e-lista-de-materiais)
17. [Agronomia](#17-agronomia)
18. [Pivô central e linear](#18-pivô-central-e-linear)
19. [Terreno e geoprocessamento](#19-terreno-e-geoprocessamento)
20. [Formatos de arquivo](#20-formatos-de-arquivo)
21. [Desempenho e arquitetura de software](#21-desempenho-e-arquitetura-de-software)
22. [Validação](#22-validação)
23. [Lacunas e trabalhos futuros](#23-lacunas-e-trabalhos-futuros)
24. [Glossário](#24-glossário)
25. [Fontes](#25-fontes)

---

## 1. Escopo e método

Perguntas que o estudo procurou responder:

1. O que um projetista espera de um CAD de irrigação, na ordem em que trabalha? Resposta na
   seção 2, a partir da prática profissional e dos manuais de projeto (National Engineering
   Handbook do NRCS, capítulos 7 e 11; Keller & Bliesner; manuais de irrigação da FAO).
2. Por que um CAD de irrigação aberto e no navegador, e que princípios isso impõe? Seção 3.
3. Quais equações são consenso na literatura e nos manuais de engenharia (NRCS, FAO, Keller &
   Bliesner, EPANET) e como testá-las? Seções 4 a 13, com exemplos numéricos recalculados.
4. Como dimensionar de forma reproduzível e explicável? Seções 14 a 16.
5. Que algoritmos de terreno, geoprocessamento, formatos e desempenho um CAD web precisa e como
   implementá-los sem bibliotecas nativas? Seções 19 a 21.

Fontes primárias: o manual do EPANET 2.2, os capítulos 7 (microirrigação) e 11 (aspersão) do
National Engineering Handbook do NRCS, o FAO-56, os manuais de irrigação da FAO, Keller & Bliesner
(1990), artigos revisados sobre fator de atrito, emissores e uniformidade, a especificação aberta do
formato DWG e a documentação dos serviços públicos de elevação.

Este estudo não cita empresas nem produtos de software de terceiros. Fabricantes de componentes de
irrigação aparecem apenas como origem dos dados dos catálogos, e formatos de arquivo de terceiros
apenas pelo nome do formato.

---

## 2. O que um projetista espera de um CAD de irrigação

### 2.1 Processo de projeto

A prática consolidada nos manuais de projeto (NRCS NEH 623, capítulos 7 e 11; Keller & Bliesner,
1990) organiza o trabalho em etapas, e é essa ordem que o menu Projeto e o tutorial seguem:

1. Detalhes do projeto: cliente, obra, projetista, unidades.
2. Informações de fundo: limites, edificações, estradas e, sobretudo, as **elevações** (curvas de
   nível e cotas), porque a topografia governa as pressões.
3. Layout: fontes de água, emissores, válvulas de controle, bombas, acessórios e tubos.
4. **Projeto das zonas**: dimensionar ou analisar da válvula de zona até os emissores, dentro da
   janela de pressão que garante a uniformidade.
5. **Gerenciamento**: quais válvulas operam juntas (turnos), por quanto tempo, e o que isso exige
   da fonte.
6. **Projeto da linha principal**: dimensionar ou analisar da fonte até as válvulas, turno a turno.
7. Materiais: conexões selecionadas automaticamente e lista de materiais com custos.
8. Plantas e relatórios: prancha com carimbo, legenda, escala e as tabelas de resultados.

### 2.2 Modelo de objetos

O modelo do OpenCADIrrigation (`entities.dart`) separa três famílias de itens:

- **Itens de zona**, a jusante de uma válvula de controle: tubo de zona, lateral com emissores
  igualmente espaçados (sprayline), fita ou tubo gotejador com emissores integrados, emissor
  individual, acessório (regulador, registro, filtro), junção e área irrigada com requisito
  hídrico. Geradores criam blocos de laterais com submain e válvula e grades de aspersores.
- **Itens de linha principal**: fonte de água, tubo principal, bomba, junção, acessório, válvula de
  controle e pivô central ou linear (uma demanda com pressão requerida própria).
- **Itens de desenho**: ponto, linha, polilinha, retângulo, círculo, arco, spline, hachura, cotas
  (linear, angular, radial e chamada), símbolos, texto, imagem, curva de nível e cota de ponto.

Regras estruturais adotadas: uma válvula de controle sempre separa zona de linha principal; itens
de zona não se ligam a itens de linha principal sem uma válvula entre eles; vértices coincidentes
(dentro da tolerância de conexão) formam um nó; um item pontual sobre um tubo divide o tubo; não há
limite para o número de conexões numa junção, porque o solver de rede aceita qualquer grau. Cotas
por diâmetro e por ordenada não foram implementadas.

### 2.3 Banco de dados de componentes

Seis grupos (tubos, emissores com bocais, fitas, válvulas e acessórios, bombas, conexões), todos em
SI, com os campos que a hidráulica exige:

- **Tubo**: diâmetro nominal, diâmetro interno real (o que entra no cálculo), C de Hazen-Williams,
  rugosidade, classe de pressão, uso (lateral, zona, linha principal), custo por metro.
- **Fita**: CV de fabricação, diâmetro interno, pressão de entrada padrão, mínima e máxima,
  tolerâncias acima e abaixo, coeficiente de perda dos barbs, constante e expoente do emissor,
  espaçamento, classe.
- **Emissor e bocal**: q = k·H^x, raio molhado R = a·H^b, arco, pressões mínima e máxima, CV,
  tolerância de vazão (±5 % é o valor usual), tipo (aspersor, microaspersor, gotejador, borbulhador,
  canhão, ponto de demanda).
- **Válvula e acessório**: perda h = K·Q^n + C, vazões mínima e máxima, pressão de saída de um
  regulador.
- **Bomba**: pontos (Q, H) ajustados a uma parábola, eficiência, potência.
- **Conexão**: tipo, diâmetros, custo.

Os catálogos de fabricantes são arquivos JSON abertos (`catalogs/`), com dados típicos de catálogo
público e preços a preencher localmente.

### 2.4 Métodos que o motor precisa cobrir

Do que a prática de projeto exige, o motor implementa:

- Perda de carga por **Hazen-Williams** com C por tubo e ajuste global (escala ou deslocamento)
  para envelhecimento, e por **Darcy-Weisbach** (laminar, transição e turbulento) para fitas e
  tubos pequenos, com viscosidade pela temperatura.
- **Perdas localizadas** por percentual do comprimento, por comprimento equivalente ou pela curva
  própria de cada acessório, e a perda dos barbs por emissor nas fitas.
- **Janela de pressão** dos emissores derivada da tolerância de vazão (±5 % → cerca de ±10 % de
  pressão para expoente 0,5) e das pressões mínima e máxima do catálogo; fitas com tolerâncias
  assimétricas (por exemplo +20 % e −30 % da pressão de entrada).
- **Análise** com vazões nominais (rápida) e **análise detalhada** com emissores dependentes da
  pressão, por um solver de rede completo.
- **Dimensionamento por programação linear** (topografia, janela de pressão, velocidade, economia,
  diâmetros habilitados e fixos, número de diâmetros por lateral e por submain) e por **velocidade
  máxima**, com racionalização dos diâmetros de montante para jusante.
- **Pressão da válvula** escolhida para que a pressão média dos emissores seja a nominal, ou, para
  fitas reguladas, para garantir a pressão mínima de submain.
- **Fonte de água** com pressão calculada (poço com nível negativo, reservatório com altura
  positiva) ou fixa (rede pública, com vazão e pressão de projeto e máximas).
- **Gerenciamento** por turnos, com duty de cada fonte por turno e tempos de operação a partir dos
  requisitos hídricos das áreas.
- **Elevação** em cada nó do grafo a partir do modelo do terreno.

### 2.5 Relatórios e ferramentas gráficas

Resumo das zonas (vazão, pressões admissíveis e reais, variação admissível e real, pressão a jusante
da válvula, perda na válvula), uniformidade (CU, DU do quartil inferior, EU de Keller-Karmeli),
tabelas de tubos e emissores (cotas, pressões, vazões, velocidades, diâmetros), linha principal e
duty das fontes, requisitos hídricos, agronomia, programa do controlador, lavagem, golpe de aríete,
pivôs e vãos, lista de materiais com custos anualizados; gráficos de linha piezométrica e de perfil,
sobreposições de velocidade, pressão, diâmetros e mínimos e máximos, envelope de posição do submain
e vista 3D do terreno.

### 2.6 Formatos

Importação de DXF, DWG, KML/KMZ, SHP, CSV/XYZ/PNEZD, GeoTIFF e imagens georreferenciadas;
exportação de DXF, DWG, PDF, SVG, KML/KMZ, GeoJSON e relatórios em CSV, TXT, XLSX e PDF; projeto em
JSON aberto com o catálogo embutido.

---

## 3. Por que um CAD de irrigação aberto no navegador

Observações gerais sobre o cenário, sem referência a produtos:

- As ferramentas profissionais de projeto de irrigação são, em regra, aplicativos de desktop para
  um único sistema operacional ou plug-ins de plataformas CAD pagas, com licença comercial, bancos
  de componentes fechados e formatos de projeto proprietários.
- Na web existem sobretudo calculadoras de fabricantes (lateral, submain, bomba) e serviços
  fechados por assinatura voltados a paisagismo; um CAD completo, aberto e gratuito no navegador
  não existia.
- O único motor de rede aberto e consolidado é o EPANET (domínio público, US EPA), voltado a
  redes de abastecimento e sem os objetos de irrigação (laterais, fitas, válvulas de zona, turnos).
- Quem projeta em campo, em tablet ou em máquinas sem privilégio de instalação, fica sem opção.

Princípios que decorrem disso e que o OpenCADIrrigation adota:

1. Rodar no navegador sem instalação e sem servidor, com os dados no computador do usuário.
2. Formato de projeto e de catálogo em JSON aberto e documentado.
3. Motor hidráulico transparente, com as equações documentadas e testadas contra referências
   públicas, e com o solver do EPANET como base para redes.
4. Interface trilíngue e pensada também para toque.

---

## 4. Unidades e convenções do motor

Internamente tudo é SI: comprimento em m, vazão em m³/s, carga em metros de coluna de água, pressão
em Pa, diâmetro em m, velocidade em m/s (`units.dart`). A interface converte para métrico (L/h,
m³/h, m.c.a. ou kPa, mm) ou US (gpm, psi, polegadas, pés). Constantes: 1 m.c.a. = 9,80665 kPa =
1,42197 psi; 1 bar = 10,197 m.c.a.; 1 L/h = 2,7778 × 10⁻⁷ m³/s; 1 m³/h = 2,7778 × 10⁻⁴ m³/s.

Viscosidade cinemática da água (m²/s) em função da temperatura, por ajuste de tabela entre 0 e
50 °C (erro < 1 %): 1,004 × 10⁻⁶ a 20 °C; 1,13 × 10⁻⁶ a 15,6 °C (60 °F, valor usual nos manuais norte-americanos).

Os catálogos guardam k dos emissores em m³/s por m^x. Conversão da vazão nominal q_n (L/h) a H_n (m):
k = (q_n / 3,6 × 10⁶) / H_n^x. Exemplo: 1,6 L/h a 10 m com x = 0,5 → k = 1,4055 × 10⁻⁷.

---

## 5. Perda de carga contínua

Módulo `friction.dart`; testes em `hydraulics_test.dart`.

### 5.1 Hazen-Williams

h_f = 10,67 · L · Q^1,852 / (C^1,852 · D^4,871), com Q em m³/s, D em m. Válida para água a
temperatura ambiente e escoamento turbulento; C ≈ 140 a 150 para PVC e PE (a prática é adotar valores
um pouco menores nos diâmetros pequenos, em torno de 135 a 140, e até 150 nos grandes). Estudos com PE mostram que o C só é constante para V > 0,7 m/s e
20 a 30 °C; fora disso o erro chega a 19 %, o que justifica oferecer Darcy-Weisbach.

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

### 5.3 Expoente da vazão

O fator F de Christiansen e a linearização do LP dependem do expoente m da lei de perda: 1,852 em
Hazen-Williams, 1,75 em Blasius, 2,0 em Darcy-Weisbach turbulento pleno (`flowExponent`).

---

## 6. Perdas localizadas

Módulo `minor_losses.dart`. Duas formas equivalentes:

- h_m = K·V²/(2g), com K de Crane TP-410 e da literatura de irrigação: cotovelo 90° 0,4 a 0,8, raio
  longo 0,2 a 0,4, tê passagem 0,2 a 0,6, tê derivação 1,0 a 1,8, registro gaveta 0,15, globo 6 a
  10, redução 0,1 a 0,5, entrada 0,5, saída 1,0.
- Forma de vazão h_m = m·Q² (estilo EPANET), com m = K / (2g·A²), usada dentro do solver.
- Comprimento equivalente L_e = K·D/f, o método usual dos CADs de irrigação para acrescentar as
  perdas a cada segmento. O OpenCADIrrigation usa o percentual do comprimento (5 % por padrão) para
  tubos e a curva própria de cada acessório do catálogo.

Acessórios e válvulas seguem h = K·Q^n + C (Q em m³/s), ajustada por regressão log-log a partir de
pontos de catálogo ou construída a partir de um K adimensional e do diâmetro.

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

---

## 10. Laterais e submains

Módulo `lateral.dart` (Wu & Gitlin 1975; Keller & Bliesner 1990).

- **Análise passo a passo do fim para o início**: H_i = H_{i+1} + h_f(Q_{i+1}, S) ± ΔZ,
  Q_i = Q_{i+1} + q(H_i). Para uma pressão de entrada conhecida, itera-se sobre a pressão final
  (`analyzeLateralFromInlet`); para uma pressão média desejada, procura-se a pressão de entrada que a
  produz (`analyzeLateralForMeanPressure`), que é o critério de ajuste da válvula.
- Perfis de pressão: aclive, horizontal, declive suave (mínimo no fim), declive acentuado (mínimo no
  meio, porque o ganho por gravidade supera o atrito). Teste "downhill slope raises end pressure".
- Repartição usual da perda admissível: 55 % na lateral e 45 % no submain.
- **Posição de alimentação**: alimentar pelo meio reduz a perda a ≈ 1/(2^m · 2) e permite laterais
  1,6 a 1,7 vezes mais longas. `allowableFeedPositions` avalia alimentar uma lateral de comprimento
  L numa fração f (0 = extremidade, 0,5 = centro), com os dois ramos partilhando a pressão de entrada
  escolhida para que a média seja a nominal, e devolve as posições aceitáveis e a ótima; é o
  "envelope do submain" pintado no desenho e o teste "feed positions: centre feed is best on flat
  ground".
- **Comprimento máximo**: bisseção sobre L, múltiplo do espaçamento, até a variação atingir a janela
  (teste "max lateral length is monotonic").

---

## 11. Redes: o Global Gradient Algorithm

Módulo `network.dart` (Todini & Pilati 1988, conforme o manual do EPANET 2.2), com o solver
esparso de `sparse_solver.dart`. Testes em `network_test.dart`.

### 11.1 Formulação

Para cada trecho ij com perda h_ij(Q):

- tubo: h = r·|Q|^n·sgn(Q) + m·Q·|Q|;
- bomba: h = −ω²·(h₀ − r·(Q/ω)^n), ou a parábola ajustada do catálogo;
- emissor: tubo fictício até um reservatório na cota do emissor, com n = 1/x e r = (1/k)^n, que é a
  forma como o EPANET trata emissores q = C·p^γ. O emissor é unidirecional: quando a carga do nó
  fica abaixo da cota do emissor ele fecha (sem vazão de saída e, ao contrário de um reservatório,
  sem retorno para a rede) e reabre assim que a pressão volta a ser positiva; a mudança de estado
  conta como mudança de status na convergência (testes "emitters under negative pressure").

Define-se g_ij = ∂h/∂Q = n·r·|Q|^{n−1} + 2·m·|Q| (em Darcy-Weisbach acrescenta-se ∂r/∂Q·|Q|^n) e o
fator de correção y_ij = h_ij(Q)·sgn(Q). Em cada iteração resolve-se o sistema linear simétrico
positivo definido A·H = F, com

A_ii = Σ_j 1/g_ij, A_ij = −1/g_ij, F_i = Σ_j (Q_ij + y_ij/g_ij) − D_i + Σ_f H_f/g_if,

os últimos termos para reservatórios de carga fixa. As vazões atualizam-se por
Q_ij ← Q_ij − (1/g_ij)·(y_ij − (H_i − H_j)).

### 11.2 Válvulas e casos especiais

- PRV ativa força H_j = H_ajuste (A_jj += 10⁸, F_j += 10⁸·H_ajuste); fechada, h = 10⁸·Q; a lógica de
  estado decide entre ativa, aberta e fechada a cada iteração (teste "PRV holds downstream pressure").
- Válvula de retenção: fecha quando o escoamento inverte.
- Acessórios: curva h = K·Q^n + C do catálogo.
- Demanda dependente da pressão nos emissores (Wagner): é a análise detalhada do projeto, com a
  vazão real de cada emissor.

### 11.3 Convergência e álgebra

Critério: Σ|ΔQ|/Σ|Q| < 10⁻⁵, ou Σ|ΔQ| < 10⁻⁹ m³/s em redes (quase) sem vazão, onde a medida
relativa é ruído, com até 200 iterações (`NetworkOptions`); mais apertado que os 10⁻³ do EPANET
porque as zonas de gotejamento têm vazões minúsculas por nó. A matriz A é montada como esparsa e fatorada por LDLᵀ com ordenação por grau
mínimo; para redes ramificadas (quase árvores) a fatoração não gera preenchimento e o custo é
próximo de linear, o que permite zonas com milhares de nós (teste "large branched network is fast").

### 11.4 Uso no projeto

A zona é resolvida como rede completa: reservatório de carga fixa no nó de jusante da válvula
(pressão da válvula), nós com emissores agregados, trechos de submain e laterais. A **pressão da
válvula** é achada por bissecção para que a pressão média dos emissores seja a nominal (a versão
"análise rápida" usa demandas fixas e um ajuste linear em duas passagens). A linha principal é
resolvida por turno com fontes de pressão fixa ou calculada, bombas e as demandas das válvulas e dos
pivôs (seção 15).

---

## 12. Bombas e energia

Módulo `pump.dart`.

- Curva H(Q) quadrática H = a·Q² + b·Q + c ajustada por mínimos quadrados a três ou mais pontos
  (dois pontos dão reta; um ponto gera a curva sintética de três pontos do EPANET). Relação de
  velocidade ω pelas leis de afinidade: H(Q) = ω²·H_base(Q/ω); Q ∝ N, H ∝ N², P ∝ N³.
- Curva do sistema H_sis(Q) = H_estático + k·Q^n; ponto de operação na interseção, por bissecção.
- Potência hidráulica P = ρ·g·Q·H; potência de eixo divide pela eficiência. NPSH disponível deve
  superar o requerido com margem de 0,5 a 1 m; região preferida 70 a 120 % da vazão de melhor
  eficiência.
- **Custo anual** = capital · CRF + energia, com CRF = i(1+i)^n / ((1+i)^n − 1). Para i = 10 % e
  n = 10 anos, CRF = 0,16275. Energia [kWh/ano] = P[kW] · horas/ano; o custo da energia da carga
  de entrada entra no objetivo do LP (seção 14).
- **Seleção automática** (`pump_selection.dart`): para o pior duty da fonte, classifica as bombas
  do catálogo pela capacidade de atender vazão e carga com folga e escolhe o motor padrão IEC que
  cobre a potência de eixo com fator de serviço 1,15.

---

## 13. Golpe de aríete e classes de pressão

Módulo `water_hammer.dart`; verificação em `Designer.checkSurge`.

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

- Regras práticas: V ≤ 1,5 m/s em laterais e PVC classe 200; 1,5 a 2,5 m/s em linhas principais.
- Classe do tubo (PN 6, 8, 10, 12,5, 16; PVC classe B 60 m, C 90 m, D 120 m) comparada com a pressão
  estática máxima mais a sobrepressão; o pior trecho de cada tubo entra na aba Golpe de aríete.

---

## 14. Dimensionamento

Módulos `lp.dart`, `lp_sizing.dart`, `designer.dart`. Testes em `lp_test.dart`,
`sizing_features_test.dart`, `design_test.dart`.

### 14.1 Velocidade máxima

Para cada unidade dimensionável (entidade com tubo "computer sized"), o menor diâmetro habilitado do
catálogo, do uso certo (lateral, zona ou linha principal), cuja velocidade a vazão máxima do trecho
respeita o limite (2,0, 1,5 e 2,0 m/s por padrão). É o dimensionamento por velocidade clássico dos
manuais e a primeira etapa dos dois métodos aqui, porque fornece as vazões nominais que o LP precisa.

### 14.2 Programação linear

Formulação (lp_sizing.dart):

- **Variáveis**: para cada unidade u e cada diâmetro candidato d, a fração x_ud do comprimento da
  unidade construída com d; mais uma variável de carga livre por zona (pressão de entrada) ou por
  fonte de pressão calculada.
- **Objetivo**: minimizar Σ_u Σ_d c_ud · x_ud + Σ_h e_h · H_h, onde c_ud é o custo anualizado do
  trecho todo em d (custo por metro × comprimento × CRF) e e_h o custo anual por metro de carga
  (potência da vazão do turno × horas × preço da energia / eficiência), com um peso mínimo quando não
  há bomba para o LP ainda preferir a menor carga.
- **Restrições**: Σ_d x_ud = 1 para cada unidade; para cada nó crítico, a pressão
  H_h − Σ_u Σ_d L_ud · x_ud − termos constantes ∈ [P_mín, P_máx], onde L_ud é a perda do trecho da
  unidade que está no caminho até o nó quando construído inteiramente com d (a perda é linear nas
  frações porque a vazão em cada unidade é fixada pela etapa de velocidade); velocidade máxima via
  o conjunto de diâmetros candidatos; fixação de tubos não dimensionáveis.
- **Nós críticos** da zona: a ponta, o nó mais alto e o mais baixo de cada lateral e cada emissor
  isolado (com teto). Se a análise não confirmar a janela, os emissores de pressão mínima e máxima
  entram como restrições adicionais e o LP roda de novo, até quatro rodadas.
- **Arredondamento e telescopagem**: as frações são convertidas no número permitido de diâmetros
  por unidade (1 lateral, 3 submain, 3 linha principal por padrão), maiores diâmetros a montante; as
  unidades com mais de um diâmetro são divididas em entidades antes da análise final.
- **Solver**: simplex denso de duas fases com regra de Dantzig e fallback de Bland contra ciclagem;
  os problemas têm centenas de variáveis e restrições, o que cabe num tableau denso. Detecta
  inviabilidade e ilimitação (teste "simplex: equality rows, infeasible and unbounded detection").

Uma simplificação comum em ferramentas de dimensionamento é reduzir cada lateral a um tubo
equivalente com um emissor concentrado antes do LP; aqui a lateral é uma unidade com seus nós
críticos, sem redução.

### 14.3 Reparo e racionalização

Depois do LP (ou só com a velocidade, no método guloso), a zona é analisada e, se um emissor viola a
janela, sobe-se o diâmetro da unidade do caminho crítico com maior redução de perda por custo, até
atender (`_repairZone`). Em seguida a racionalização garante diâmetros não crescentes de montante
para jusante. O teste "LP design meets the pressure window and costs no more than greedy" compara os
dois métodos no exemplo do pomar.

### 14.4 Pressão da válvula e resultados

A análise detalhada final escolhe a pressão a jusante da válvula por bissecção para que a pressão
média dos emissores seja a nominal (para fitas reguladas, para garantir a pressão mínima de
submain). A perda na válvula vem da sua curva; a pressão requerida a montante alimenta a linha
principal. A variação admissível da zona vem da tolerância de vazão do emissor (ou do parâmetro
"variação máxima da zona") e a real é medida sobre os emissores agregados.

---

## 15. Linha principal, turnos e fontes

- **Turnos** (system flows): conjuntos de válvulas que operam juntas, com hora de início e duração.
  Sem turnos definidos, cada válvula (e cada pivô) é um turno.
- **Demandas**: para cada válvula, a vazão da zona e a pressão requerida a montante; para cada pivô,
  a vazão e a pressão de entrada da máquina.
- **LP da linha principal**: as mesmas variáveis de fração por diâmetro, com uma restrição de pressão
  requerida em cada válvula em cada turno, e custo de energia ponderado pelas horas de cada turno
  sobre as horas anuais. Fontes de pressão fixa entram como constantes; fontes calculadas têm a
  carga como variável.
- **Análise por turno**: rede completa da linha principal com bombas (ponto de operação), PRVs,
  retenções, acessórios e as demandas; resultado por fonte (duty: vazão, pressão disponível,
  requerida, déficit, cota), por válvula (disponível versus requerida) e por tubo; energia anual.
- **Malhas**: o LP usa caminhos em árvore (mensagem `lp_loops_approx`) e a análise final confere as
  pressões; o teste "looped mainline sizing with LP adds the approximation note and still converges"
  garante o comportamento.

---

## 16. Lavagem, conexões e lista de materiais

- **Lavagem** (`analyzeFlushing`): cada fita recebe na ponta a vazão que produz a velocidade de
  lavagem (0,3 m/s por padrão) e a zona é resolvida de novo; acha-se a pressão de válvula que mantém a
  pressão mínima na ponta (1 m) e reporta-se a vazão de lavagem, as pressões e a velocidade máxima. É
  a etapa mais pesada do cálculo em zonas com muitas fitas.
- **Conexões** (`fittings.dart`): a partir do grafo já dimensionado, luvas por barra de tubo (6 m),
  cotovelos de 90° e 45° e tês e cruzetas pela geometria dos nós, reduções onde o diâmetro muda,
  tampões nas pontas, derivações de lateral, finais de fita e hastes de emissores; cada uma procura o
  item do catálogo do tipo e diâmetro (ou o nome genérico quando não há).
- **Lista de materiais** (`buildBom`): tubos por diâmetro e classe, emissores, fitas, válvulas,
  acessórios, bombas selecionadas, pivôs (máquina, torres, aspersores, reguladores) e conexões, com
  custos unitários, total, custo anualizado (CRF) e energia anual.

---

## 17. Agronomia

Módulo `agronomy.dart`, com base no FAO-56 e nos manuais de irrigação da FAO.

- ETc = Kc · ETo (mm/dia); Kc de meia estação típicos são oferecidos por cultura.
- Água prontamente disponível RAW = CAD · Z_r · f (mm), com CAD em mm/m de solo, profundidade
  radicular Z_r em m e fração de esgotamento admissível f (MAD).
- Intervalo entre irrigações I = ⌊RAW / ETc⌋ dias (mínimo 1).
- Lâmina líquida por evento = ETc · I; lâmina bruta = líquida / eficiência (0,90 gotejamento, 0,75
  aspersão, 0,85 pivô como valores usuais; a área define a sua).
- Taxa de aplicação da zona PR = vazão / área; tempo por evento
  T = lâmina bruta · fração molhada / PR; volume por evento = lâmina bruta · área · fração molhada.
  A tabela de requisitos hídricos aplica a mesma fração molhada ao volume e às horas diárias, de
  modo que as duas tabelas concordam.
- **Programa do controlador**: cada turno roda pelo maior tempo de evento das áreas que suas zonas
  irrigam, a cada intervalo de dias, em sequência a partir da hora de início do dia (ou nas horas
  próprias), num calendário de N dias exportável em CSV; o pico de horas de bombeamento por dia sai
  no relatório.

---

## 18. Pivô central e linear

Módulo `pivot.dart` (Keller & Bliesner 1990, capítulo 14; Chu & Moe 1972).

- **Capacidade**: Q = A · lâmina bruta / tempo de ciclo. Para R = 300 m (área irrigada 28,3 ha, com
  o alcance do último aspersor), 8 mm em 24 h: Q = 94,2 m³/h. Num pivô setorial a área, e portanto
  a vazão, escalam com o ângulo varrido.
- **Distribuição da vazão**: num pivô a vazão que passa a uma distância r é Q·(1 − (r/R)²), porque a
  área irrigada cresce com r²; num linear é Q·(1 − r/L). O canhão final soma-se a toda a extensão.
- **Atrito**: integração numérica (Simpson, 200 passos) do gradiente de perda ao longo do tubo do
  vão com a vazão variável; para um pivô o resultado equivale ao fator de Chu & Moe ≈ 0,543 vezes a
  perda de um tubo com a vazão total.
- **Pressão de entrada**: pressão do último aspersor (ou do canhão) + atrito + subida do terreno na
  pior direção (o azimute em que a ponta fica mais alta, obtido do modelo do terreno) + altura do
  tubo + perdas da máquina; cada torre é verificada, porque uma subida brusca a meio caminho pode
  governar. O resultado entra como demanda na linha principal e o déficit é reportado.
- **Taxa de aplicação** na extremidade: média I = 2·Q·R/(R²·w), da vazão por metro na ponta sobre a
  largura molhada w (Q já é a vazão do setor, sem correção adicional pelo ângulo), e pico (perfil
  elíptico) 4/π vezes a média; comparação com o limite de infiltração do solo, quando informado.
- **Vãos e bocais**: por vão, número de aspersores (espaçamento ao longo do tubo), vazão por
  aspersor, pressão a meio vão e o bocal do catálogo mais próximo; é a base do relatório de vãos e
  da lista de materiais (torres, aspersores, reguladores).

---

## 19. Terreno e geoprocessamento

### 19.1 Modelo digital do terreno

Módulos `terrain.dart` e `tin.dart`.

- Amostras: cotas de ponto e vértices das curvas de nível, densificadas a cada 5 m (parâmetro), com
  um hash espacial para consultas rápidas.
- **TIN de Delaunay** pelo algoritmo de Bowyer-Watson (inserção incremental com remoção dos
  triângulos cujo circuncírculo contém o ponto novo), com localização de triângulo por grade
  uniforme e interpolação linear por coordenadas baricêntricas. Exato em rampas planas (teste
  "Delaunay of a plane reproduces the plane exactly") e igual ao modelo que os CADs chamam de DTM.
- **IDW** (inverso da distância sobre os vizinhos mais próximos, com anéis de busca no hash) como
  método alternativo e como complemento fora do casco convexo do TIN.
- Levantamentos com mais de 12 000 pontos são decimados uniformemente para a triangulação, mas o
  IDW mantém todos (teste "very large surveys are decimated for the TIN but kept for IDW").
- **Curvas de nível geradas**: marching sobre os triângulos (interseção do plano de cada nível com
  cada aresta), segmentos encadeados em polilinhas com fechamento de anéis; intervalo automático
  escolhido para no máximo cerca de 20 curvas. Declividade e aspecto vêm do plano do triângulo.
- Cada nó do grafo (inclusive os emissores agregados) recebe a cota do modelo, mais a altura da
  haste e menos a profundidade de enterro.

### 19.2 Elevação da internet

Módulo `dem_online.dart`. Dois serviços gratuitos, sem chave e com CORS:

| Serviço | Dado | Resolução | Limites |
|---|---|---|---|
| Open-Meteo Elevation API | Copernicus DEM GLO-90 | 90 m | 100 pontos por chamada |
| OpenTopoData | NASA SRTM, ASTER GDEM | 30 m | 100 pontos por chamada, 1 chamada por segundo |

A grade sobre o projeto (ou a área visível) é limitada em pontos (o espaçamento cresce quando a
área é grande), as chamadas são feitas em lote e as respostas viram cotas de ponto; a geração de
curvas pode seguir automaticamente. A resolução de 30 a 90 m serve ao relevo geral e não substitui
um levantamento, o que o diálogo avisa.

### 19.3 Coordenadas

- **UTM ↔ WGS84** pelas séries de Krüger na formulação de Karney (2011), com precisão milimétrica
  dentro do fuso, fuso automático com as exceções da Noruega e Svalbard, e origem local para manter
  as coordenadas do desenho pequenas (teste "UTM inverse round trip").
- **Coordenadas coladas** (`parseLatLon`): decimais com ponto ou vírgula, letras de hemisfério,
  graus/minutos/segundos, links do Google Maps e URIs `geo:`; a ordem lon, lat (KML) é reconhecida
  quando só ela faz sentido.
- Exportações geográficas (KML, KMZ, GeoJSON) convertem cada vértice para WGS84 pela georreferência
  do projeto; sem georreferência, o app a pede.

---

## 20. Formatos de arquivo

### 20.1 DXF

Formato de texto do AutoCAD organizado em pares "código de grupo / valor". O leitor (`dxf.dart`)
percorre as seções BLOCKS e ENTITIES e lê LINE (10/20 e 11/21), LWPOLYLINE (vértices 10/20 em ordem,
bulge 42, flag 70 de fechamento, elevação 38), POLYLINE com VERTEX (elevação no código 30 ou nos Z
iguais dos vértices; vértices de controle de spline ignorados), CIRCLE, ARC (50/51 em graus),
ELLIPSE e SPLINE (aproximados por polilinhas: a elipse pelos eixos 11/21 e razão 40, a spline pelos
pontos de ajuste 11/21 ou pelo polígono de controle), TEXT, ATTRIB e MTEXT (blocos 3 seguidos do 1,
códigos de formatação removidos, ponto de alinhamento 11/21 quando 72/73 pedem) e POINT, com a
camada (8) e a cor (62); a tabela LAYER e a variável $INSUNITS definem camadas e a escala. Um bulge
b descreve um arco de ângulo 4·atan(b) entre dois vértices, amostrado a cada 15°.

Blocos: cada BLOCK guarda o ponto-base (10/20) e suas entidades; INSERT (ponto 10/20, escalas 41/42,
rotação 50, matriz 70/71 com espaçamentos 44/45) e o bloco anônimo de cada DIMENSION (código 2, já
em coordenadas do desenho) são expandidos por uma transformação afim, com referências aninhadas
compostas até oito níveis. Entidades na camada 0 ganham a camada da referência e a cor BYBLOCK a
cor dela; círculos e arcos permanecem círculos e arcos quando a transformação é uma similaridade e
viram polilinhas quando há escala anisotrópica ou espelhamento; os pontos de definição das cotas
(camada Defpoints) não entram. O texto é decodificado como UTF-8 (R2007+) ou Latin-1 (cp1252 dos
arquivos antigos). O escritor produz um arquivo R12 com tabela de camadas, o denominador comum de
todos os CADs.

### 20.2 DWG

O DWG é binário e proprietário; a Open Design Alliance publica uma especificação de engenharia
reversa que serviu de base para o leitor (`dwg.dart`, 1,6 mil linhas) e para o escritor
(`dwg_writer.dart`, 1,3 mil linhas), ambos em Dart puro.

- **Versões**: AC1012 (R13), AC1014 (R14), AC1015 (2000), AC1018 (2004), AC1021 (2007), AC1024
  (2010), AC1027 (2013), AC1032 (2018). Versões desconhecidas são rejeitadas com mensagem clara.
- **Contêineres**: R13 a R2000 têm seções localizadas por um índice no cabeçalho, sem compressão;
  R2004 e R2010 a R2018 usam páginas comprimidas com um esquema LZ77 próprio e um mapa de páginas
  e seções; R2007 é o caso mais difícil: páginas intercaladas com códigos Reed-Solomon (blocos de
  239 bytes repetidos), que precisam ser desintercaladas e descomprimidas antes de ler.
- **Dados**: os objetos são endereçados pelo mapa de objetos (handles), e cada objeto é um fluxo de
  bits com códigos de tamanho variável (B, BB, BS, BL, BD, DD, MC, MS, H, entre outros); o leitor
  monta inteiros de vários bytes aritmeticamente porque as operações bit a bit do dart2js são de
  32 bits. O CRC-16 do cabeçalho é verificado (teste "CRC-16 matches the checksum AutoCAD wrote").
- **Escritor R2000**: banco mínimo mas completo: tabelas de controle (camadas, tipos de linha,
  estilo de texto, viewport, appid, estilo de cota), dicionários de objetos nomeados com layouts,
  espaço do modelo e do papel, e as entidades LINE, LWPOLYLINE, CIRCLE, ARC, POINT e TEXT. A ordem
  dos campos e os valores padrão foram conferidos contra arquivos gravados pelo AutoCAD e validados
  com o LibreDWG (`dwgread`, `dwg2dxf`), que o teste executa quando está instalado, além de relidos
  pelo próprio leitor.
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

### 20.3 KML e KMZ

XML do Google Earth com coordenadas lon, lat, altitude em WGS84; KMZ é um zip com o KML e recursos.
Pastas viram camadas, linhas com altitude ou atributo ELEV viram curvas de nível, pontos com altitude
viram cotas. A projeção para UTM é feita com fuso automático e origem local; a exportação faz o
caminho inverso com uma pasta por camada.

### 20.4 Shapefile, CSV/PNEZD

- **Shapefile**: `.shp` (geometria com cabeçalho big-endian de 100 bytes e registros little-endian:
  pontos, polilinhas, polígonos, multipontos e variantes Z), `.dbf` (atributos dBase, de onde vêm a
  elevação ELEV/Z/COTA e o nome NAME/NOME/ID, decodificados conforme o `.cpg` ou como UTF-8 quando
  válido e Latin-1 caso contrário) e `.prj` (sistema de referência), aceitos dentro de um zip. Sem
  `.prj`, as coordenadas só são tratadas como graus quando cabem na faixa de latitude/longitude e
  pelo menos metade tem quatro ou mais casas decimais; um desenho local em metros fica como está.
- **Pontos de levantamento**: CSV, TXT, XYZ e PNEZD (ponto, norte, este, cota, descrição) com
  detecção de colunas pelo cabeçalho ou pela posição, separadores vírgula, ponto e vírgula, tab e
  espaço, vírgula decimal e reconhecimento de lat/lon.

### 20.5 GeoTIFF, world files e imagens

TIFF com as tags GeoTIFF ModelPixelScale/ModelTiepoint ou ModelTransformation e as chaves de CRS
(UTM ou geográfico). Um raster de uma banda (float ou inteiro) é tratado como DEM e vira grade de
cotas, com nodata ignorado; rasters RGB são imagens de fundo. Imagens JPG e PNG aceitam world files
(.jgw, .pgw, .wld) dentro de um zip: x = A·col + B·lin + C e y = D·col + E·lin + F para o centro
de cada pixel, de modo que o eixo das colunas (A, D) dá o tamanho do pixel e a rotação
(atan2(D, A)) e o canto superior esquerdo fica meio pixel atrás nos dois eixos; a matriz
ModelTransformation do GeoTIFF é tratada do mesmo modo. Sem georreferência, a imagem é colocada
na vista e ajustada por dois pontos (transformação de similaridade: translação, rotação e escala).

### 20.6 PDF, SVG e XLSX

- **PDF 1.4** próprio (`pdf.dart`): objetos com tabela xref, caminhos vetoriais, fontes padrão
  Helvetica com codificação WinAnsi (acentos do português e do espanhol), recorte e fluxos de
  conteúdo comprimidos com Flate. A prancha (`plot.dart`, `pdf_sheet.dart`) é montada em espaço do
  papel: penas, símbolos e textos em milímetros de papel, com escala automática ou fixa, carimbo,
  legenda, seta norte, escala gráfica e páginas de relatório.
- **SVG**: a mesma cena em milímetros, um grupo por camada.
- **XLSX**: SpreadsheetML mínimo (Office Open XML): uma planilha por tabela, cabeçalho em negrito,
  números como números e strings inline, sem tabela de strings compartilhadas; um leitor do mesmo
  subconjunto permite reimportar catálogos editados no Excel.

### 20.7 Verificação com leitores independentes

Os leitores e escritores são conferidos contra software de terceiros, não só entre si.
`tool/formats/make_fixtures.py` grava em `test/fixtures/formats` arquivos de importação produzidos
por outras bibliotecas: DXF R12, R2000, R2010 (em milímetros) e R2018 do ezdxf com blocos,
bulges, MTEXT e polilinha 3D; DWG R2000 do LibreDWG; shapefiles do pyshp (polígonos UTM com `.prj`,
polilinhas Z com atributo ELEV, pontos WGS84, multipontos Z, um `.shp` solto em coordenadas
locais); GeoTIFF do tifffile (DEM float32 UTM com nodata, DEM int16 geográfico, ortofoto RGB);
PNG e JPG do Pillow com world files, um deles rotacionado 30°; KML e KMZ no estilo do Google Earth
com pastas aninhadas, MultiGeometry, SchemaData e anel interno; catálogos em CSV de fabricante e
XLSX do openpyxl. `test/core/formats_test.dart` importa cada um e confere posições, elevações,
nomes e camadas, e grava todas as exportações em `build/formats`, que
`tool/formats/check_exports.py` valida com ezdxf (auditoria), LibreDWG (`dwgread`, `dwg2dxf`),
lxml (KML, SVG), openpyxl, pypdf e as regras do RFC 7946 para GeoJSON. Essa bateria encontrou e
corrigiu: atributos DBF em UTF-8 lidos como Latin-1; shapefile local sem `.prj` tomado por
lat/lon; sinal invertido na rotação de world files e do ModelTransformation; blocos, cotas e
polilinhas 3D ignorados em DXF e DWG; handles relativos, bits de xref em R2007+ e ordem do
cabeçalho de objetos em R13/R14 no leitor DWG; nomes com aspas de polegada (1/2") quebrando a
leitura de catálogos XLSX.

### 20.8 Projeto e catálogos

O projeto `.oci.json` e o catálogo `.oci.cat` são JSON com chave `format` e `version`; a estrutura
está no README (seção 11) e em `catalogs/README.md`. A decisão de embutir o catálogo no projeto torna o
arquivo autossuficiente e legível.

---

## 21. Desempenho e arquitetura de software

- **Motor em Dart puro** (`lib/core`, 18 mil linhas), sem Flutter, executado num Web Worker no
  navegador e num isolate no desktop. O protocolo (`design_job.dart`) envia o projeto em JSON sem
  imagens e recebe progresso, resultados e as entidades redimensionadas; um contador de edições
  descarta resultados de um projeto alterado durante o cálculo.
- **Índice espacial**: R-tree estática empacotada por Sort-Tile-Recursive (Leutenegger et al.,
  1997): itens ordenados por x, fatiados em √P faixas, cada faixa ordenada por y e cortada em folhas
  de 12 itens; os nós pais são empacotados da mesma forma até a raiz. Construção O(n log n) a cada
  edição, consulta O(log n + k) com os índices devolvidos em ordem de desenho. Medido com 40 mil
  entidades: construção em cerca de 30 ms, consulta da janela visível em 9 µs contra 700 µs da
  varredura linear. O painter, a seleção, a janela de seleção e o snap consultam o índice.
- **Agregação de emissores**: cada lateral vira até 100 nós com emissores agrupados
  (`maxNodesPerLateral`); um talhão de 44 fitas de 120 m tem 4400 nós e dimensiona em cerca de 2 s. Fitas de zonas vizinhas com pontas
  coincidentes são fundidas pelo construtor do grafo, o que dobra a zona e o tempo: os exemplos
  deixam faixas entre blocos.
- **Solver esparso**: LDLᵀ com ordenação por grau mínimo; a matriz das zonas ramificadas é quase
  uma árvore, sem preenchimento.
- **Desfazer**: snapshots das entidades a cada ação (até 50), com rótulos para o painel de histórico.
- **Armazenamento**: chave/valor do navegador com autosave, recentes, versões e recuperação, dentro
  do limite de cerca de 5 MB por origem (3,5 MB por projeto).
- **Site**: páginas geradas com conteúdo HTML real para os buscadores, porque o Flutter desenha em
  canvas (ver README, seção 13).

---

## 22. Validação

A suíte tem 350 testes (`flutter test`). Os que validam a hidráulica contra referências:

| Teste | Referência |
|---|---|
| Hazen-Williams matches textbook value | Valor tabelado de manual de hidráulica |
| Darcy-Weisbach agrees with Hazen-Williams for smooth PVC | Coerência entre fórmulas em PVC liso (diferença de poucos por cento) |
| Swamee-Jain close to Colebrook | Erro < 1 % (Swamee & Jain 1976) |
| transitional cubic matches the turbulent slope at Re = 4000 (EPANET) | Polinômio de Dunlop como codificado no EPANET |
| Christiansen F factor table values; Scaloppi adjustment | Tabelas de Keller & Bliesner; Scaloppi 1988 |
| pressure dependent emitters; PRV holds downstream pressure; two reservoirs in a loop split the flow | Casos do manual do EPANET |
| emitters under negative pressure (closed, no backflow, reopen) | Balanço de massa de emissores unidirecionais |
| friction loss agrees with Christiansen estimate | Solver versus fator F |
| downhill slope raises end pressure; feed positions | Wu & Gitlin 1975 |
| sector pivot: same cycle time gives a proportionally lower application rate | Keller & Bliesner, capítulo 14 |
| PVC celerity in expected range | 300 a 600 m/s em PVC |
| capital recovery factor; operating point | Fórmulas financeiras e de bombas |
| Delaunay of a plane reproduces the plane exactly | Propriedade do interpolador linear |
| UTM inverse round trip; georeference from a lat/lon origin | Karney 2011 |
| CRC-16 matches the checksum AutoCAD wrote; LibreDWG accepts the file | Arquivos reais e ferramenta independente |
| LP design meets the pressure window and costs no more than greedy | Otimalidade relativa do LP |

Os exemplos da galeria funcionam como testes de integração: os quinze projetos, nos três idiomas,
constroem, passam na verificação, dimensionam com todas as zonas dentro da janela e sem déficit
de fonte, imprimem cada célula de relatório como número simples, e batem com os arquivos publicados.

---

## 23. Lacunas e trabalhos futuros

Do ponto de vista da pesquisa, o que a literatura e a prática de projeto sugerem como próximos passos:

1. **Malhas no LP**: formulação exata para redes malhadas (o LP atual usa caminhos em árvore e a
   análise final confere); a literatura de otimização de redes sugere decomposição por laços ou
   programação não linear.
2. **Transientes**: um método das características para golpe de aríete com válvulas e bombas, em vez
   da estimativa de Joukowsky.
3. **Sprayline "unconnected"** automática e valve-in-head com zona própria por aspersor como
   entidade dedicada.
4. **Splines e hachuras no DWG**: SPLINE e HATCH na importação; mais entidades e versões mais
   novas na exportação.
5. **Fertirrigação e qualidade da água**: cálculo de injeção e tempos de deslocamento da água na
   rede.
6. **Sistema elétrico**: fios, controladores e solenoides na lista de materiais.
7. **Colaboração**: compartilhamento por link e edição simultânea, mantendo o princípio de não
   depender de servidor próprio (por exemplo, arquivos em serviços do usuário).
8. **Testes de navegador** para o comportamento em tempo de execução (idioma do sistema, PWA).

---

## 24. Glossário

| Termo (pt) | Inglês | Significado |
|---|---|---|
| Zona | Zone | Conjunto de tubos e emissores a jusante de uma válvula de controle |
| Linha principal | Mainline | Da fonte de água às válvulas de zona |
| Submain | Submain | Tubo de zona que alimenta as laterais |
| Lateral | Sprayline / lateral | Tubo com emissores igualmente espaçados |
| Fita / tubo gotejador | Tape / dripline | Lateral com emissores integrados |
| Turno | System flow | Válvulas que operam juntas |
| Duty | Duty | Vazão e pressão exigidas de uma fonte num turno |
| Janela de pressão | Pressure window | Faixa de pressão dos emissores que mantém a vazão dentro da tolerância |
| Telescopagem | Telescoping | Diâmetros decrescentes ao longo de um tubo |
| CU, DU, EU | idem | Coeficientes de uniformidade de Christiansen, do quartil inferior e de emissão |
| CRF | Capital recovery factor | Fator que anualiza um custo de capital |
| TIN / MDT | TIN / DTM | Modelo do terreno por triangulação |
| GGA | Global Gradient Algorithm | Método de Todini-Pilati para redes |
| BOM | Bill of materials | Lista de materiais |
| PRV | Pressure-reducing valve | Válvula reguladora de pressão |

---

## 25. Fontes

Hidráulica e redes:
- Rossman, L. et al. EPANET 2.2 User Manual, Analysis Algorithms: https://epanet-manual.readthedocs.io/en/latest/analysis_algorithms.html
- Todini, E.; Pilati, S. (1988). A gradient algorithm for the analysis of pipe networks. Computer Applications in Water Supply, vol. 1.
- Swamee, P. K.; Jain, A. K. (1976). Explicit equations for pipe-flow problems. J. Hydraulics Div. ASCE 102(5).
- Christiansen, J. E. (1942). Irrigation by sprinkling. Univ. California Bull. 670.
- Scaloppi, E. J. (1988). Adjusted F factor for multiple-outlet pipes. J. Irrig. Drain. Eng. 114(1): https://ascelibrary.org/doi/10.1061/%28ASCE%290733-9437%281988%29114%3A1%28169%29
- Wu, I. P.; Gitlin, H. M. (1975). Energy gradient line for drip irrigation laterals. J. Irrig. Drain. Div. ASCE 101(4).
- Keller, J.; Bliesner, R. D. (1990). Sprinkle and Trickle Irrigation. Van Nostrand Reinhold.
- Keller, J.; Karmeli, D. (1974). Trickle irrigation design parameters. Trans. ASAE 17(4).
- Chu, S. T.; Moe, D. L. (1972). Hydraulics of a center pivot system. Trans. ASAE 15(5).
- Hazen-Williams versus Darcy-Weisbach em PE: https://iwaponline.com/aqua/article/74/8/493/108822/ ; https://elibrary.asabe.org/abstract.asp?JID=3&AID=25699 ; fatores C: https://simupipe.com/resources/hazen-williams-c-factor
- Emissores: https://doi.org/10.3390/w14071034 ; https://doi.org/10.3390/w18020244 ; https://workforce.libretexts.org/Bookshelves/Water_Systems_Technology/Irrigation_Systems_Management_(AET_021)/14:_Microirrigation/14.06:_Uniformity
- Uniformidade: Xue et al. (2023), Irrigation and Drainage: https://onlinelibrary.wiley.com/doi/abs/10.1002/ird.2837 ; https://www.sciencedirect.com/science/article/abs/pii/S1537511005002205
- Laterais: https://link.springer.com/article/10.1007/BF00273380 ; https://www.sciencedirect.com/science/article/abs/pii/S0378377417304079
- Fator de atrito: https://www.sciencedirect.com/science/article/pii/S2090447919300176
- Golpe de aríete e velocidade: https://www.rainbird.com/professionals/irrigation-design-tip-sizing-pipe ; https://www.instrumentationblog.in/joukowsky-equation-water-hammer/
- Bombas: https://www.northridgepumps.com/article-9_how-to-read-a-pump-curve
- Perdas localizadas: Crane TP-410; https://simupipe.com/resources/k-factor-table ; https://neutrium.net/articles/fluid-flow/pressure-loss-from-fittings-excess-head-k-method/
- NRCS National Engineering Handbook, Part 623, cap. 7 (Microirrigation) e cap. 11 (Sprinkler): https://www.wcc.nrcs.usda.gov/ftpref/wntsc/waterMgt/irrigation/NEH15/ch7.pdf , .../ch11.pdf
- FAO Irrigation Manual, módulos 8 e 9: https://www.fao.org/4/ai596e/ai596e.pdf
- Allen, R. G. et al. (1998). FAO Irrigation and Drainage Paper 56: Crop evapotranspiration.

Terreno, geoprocessamento e algoritmos:
- Karney, C. F. F. (2011). Transverse Mercator with an accuracy of a few nanometers. Journal of Geodesy 85(8).
- Bowyer, A. (1981); Watson, D. F. (1981). Computing the n-dimensional Delaunay tessellation. The Computer Journal 24(2).
- Leutenegger, S. T.; Lopez, M. A.; Edgington, J. (1997). STR: a simple and efficient algorithm for R-tree packing. ICDE.
- Open-Meteo Elevation API: https://open-meteo.com/en/docs/elevation-api ; Copernicus DEM GLO-90.
- OpenTopoData: https://www.opentopodata.org/ (SRTM, ASTER).

Formatos:
- Open Design Alliance. Open Design Specification for .dwg files (versão 5.4.1).
- LibreDWG: https://www.gnu.org/software/libredwg/
- Autodesk DXF Reference.
- ESRI Shapefile Technical Description (1998); GeoTIFF Specification 1.8.2; PDF Reference 1.4 (Adobe); ECMA-376 Office Open XML (SpreadsheetML); OGC KML 2.3; RFC 7946 (GeoJSON).
