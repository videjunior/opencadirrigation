# Catálogo de componentes

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

## Preços e moeda

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

## Catálogos de fabricantes (`.oci.cat`)

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
[catalogs/](../../../catalogs/) como arquivos JSON, um por fabricante, mais um `index.json`. Pelo diálogo
*Catálogos de fabricantes…* você adiciona um pacote ao projeto, importa um arquivo `.oci.cat` ou
carrega um pacote ou um índice inteiro por URL, o que permite a qualquer revenda ou comunidade manter
o próprio repositório. O catálogo do projeto também é exportado nesse formato. O formato completo,
com os campos de cada grupo e as regras de contribuição, está em [catalogs/README.md](../../../catalogs/README.md);
`dart run tool/gen_catalogs.dart` valida os pacotes (ids únicos, curvas plausíveis) e refaz o índice.
