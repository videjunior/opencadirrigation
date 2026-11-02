# Começando em cinco minutos

1. Abra [opencadirrigation.com](https://opencadirrigation.com) e clique em **Abrir o app** (ou abra
   um exemplo ou o tutorial direto da página). Nas visitas seguintes o app abre sozinho, num projeto
   vazio, com uma tela de início que pergunta duas coisas: **onde fica a área** (um endereço buscado
   no OpenStreetMap, ou coordenadas; o projeto é georreferenciado ali, no mapa de satélite) e **se
   você quer projetar com o assistente de IA**.
2. Desenhe a área, deixe o assistente projetar ou abra um exemplo pronto: Ajuda → Boas-vindas e
   galeria de exemplos (com o **tutorial interativo**, 90 passos) ou Arquivo → Exemplos. O tutorial
   abre numa aba própria; o seu cartão tem um menu de capítulos e trilhas (o tutorial completo, uma
   trilha curta para o toque e trilhas rápidas de gotejamento num talhão, de paisagismo e de pivô
   central) e continua de onde você parou. Ctrl+K (Ajuda → Pesquisar comandos…) acha qualquer menu,
   comando ou ajuste pelo nome, e Ajuda → Manual (F1), ou o **?** de uma janela ou painel, explica
   cada parte do programa com o seu capítulo deste manual a um clique.
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

## Galeria de exemplos

| id | Projeto | Conteúdo | Zonas |
|---|---|---|---|
| `orchard` | Pomar | Microaspersão em citros e gotejamento em uva, poço, bomba e filtro, terreno em declive | 2 |
| `garden` | Jardim residencial | Sprays pop-up no gramado da frente, rotores atrás, gotejamento nos canteiros; rede pública com hidrômetro e anti-refluxo | 3 |
| `sportsField` | Campo de futebol | 105 × 68 m, aspersores de impacto em cinco linhas com bocais equivalentes nas linhas do campo, reservatório, bomba, turnos noturnos | 5 |
| `rowCrop` | Lavoura gotejada | Quatro talhões de tomate com fita, linhas de derivação com válvulas, filtro de tela, bomba, declive de 1 % | 4 |
| `pivot` | Pivô central | Pivô de 300 m em milho, adutora, poço e bomba; relatório de torres, vãos e bocais | 1 pivô |
| `greenhouse` | Estufa de hortaliças | Quatro túneis de pimentão com tubo gotejador autocompensante, reservatório, bomba pequena e filtro de discos | 4 |
| `nursery` | Viveiro de mudas | Três canteiros com microaspersores suspensos em malha 4 × 4 m, caixa d’água elevada, bomba pequena e filtro de discos | 3 |
| `coffee` | Cafezal em curvas de nível | Três talhões em encosta com laterais curvas que seguem as curvas de nível (bloco guiado), tubo gotejador PC, poço e bomba | 3 |
| `bananas` | Bananal | Dois talhões com microaspersores autocompensantes em 5 × 5 m, poço com bomba submersa e filtro de discos | 2 |
| `sugarcane` | Cana-de-açúcar subsuperficial | Tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, linhas de derivação enterradas, filtro de tela e ventosa | 2 |
| `gravity` | Gotejamento por gravidade | Reservatório 40 m acima dos talhões, sem bomba: registro, válvula reguladora de pressão e filtro na adutora | 2 |
| `pasture` | Pastagem em aspersão | Três piquetes com linhas de aspersores de impacto em 12 × 18 m, reservatório, bomba e válvula de retenção | 3 |
| `golf` | Buraco de golfe | Tee com sprays, fairway com rotores em malha triangular e green com rotores no perímetro, lago e bomba | 4 |
| `sectorPivot` | Pivô setorial com canhão | Pivô de 250 m que gira 270° com canhão final de 12 m³/h, lago, bomba de 20 cv e registro | 1 pivô |
| `linear` | Pivô linear | Lateral móvel de 392 m percorrendo 800 m ao longo de um canal, captação com bomba de 30 cv | 1 linear |

Todo exemplo com válvulas tem também a parte elétrica: um controlador junto à bomba (ou ao
cabeçal de controle) e as rotas de fios ao lado da linha principal até cada válvula. O cálculo dá
a cada válvula uma estação e uma bitola, verifica a tensão no solenoide e põe fios, controlador e
conectores na lista de materiais (aba Elétrico). Os exemplos de pivô e linear não têm válvulas
solenoides para ligar. As áreas de gotejamento e de microaspersão levam a cobertura do solo da sua
cultura ([Agronomia e manejo da irrigação](agronomy.md#os-exemplos-da-galeria)).

Os exemplos abrem pela tela de boas-vindas (Ajuda → Boas-vindas e galeria de exemplos…), pelo
menu Arquivo → Exemplos e pela URL. Os mesmos projetos estão em [examples/](../../../examples/) como
`.oci.json`, uma pasta por idioma da interface (`examples/de/`, `examples/ja/`, … 20 ao todo): o
mesmo desenho em todas, com nomes, culturas e itens de catálogo no idioma da pasta.

## Parâmetros de URL

| Parâmetro | Efeito |
|---|---|
| `?example=garden` | Abre o exemplo indicado (`orchard`, `garden`, `sportsField`, `rowCrop`, `pivot`, `greenhouse`, `nursery`, `coffee`, `bananas`, `sugarcane`, `gravity`, `pasture`, `golf`, `sectorPivot`, `linear`). |
| `?design=1` | Projeta ao carregar. |
| `?ai=1` | Abre o assistente de IA ao lado do desenho (o botão "Abrir o assistente de IA" do site e o atalho do app). |
| `?tutorial=N` | Abre o tutorial interativo no passo N (de 1 a 90). |
| `?lang=pt` (qualquer código de [Idiomas e site](languages-and-site.md)) | Idioma desta visita (não altera a preferência salva). |
| `/pt/`, `/es/`, `/de/`, … | Página de entrada de cada idioma sob o seu código (os 20), com o mesmo efeito de `?lang` (a página raiz é a inglesa). |
| `#p=…` | Um projeto compartilhado por link (Arquivo → Compartilhar por link…): abre como cópia numa aba nova. A parte depois do `#` nunca é enviada a nenhum servidor. |
