# Fluxo de projeto

O fluxo segue a prática consolidada de projeto de irrigação (inventário e terreno, layout,
zonas, gerenciamento, linha principal, materiais e plotagem), adaptada a um app de navegador.

1. **Detalhes do projeto** (Arquivo → Detalhes do projeto…): nome, cliente, obra, projetista e
   notas, que vão para o carimbo da prancha e para os relatórios; Arquivo → Carimbo e responsável
   técnico… acrescenta o responsável técnico, os registros e o logotipo de um carimbo profissional
   ([Carimbo e documentos técnicos](technical-documents.md)). Unidades (métrico ou US) em
   Ferramentas → Unidades.
2. **Informações de fundo**: importe a base (DXF, DWG, DGN, uma planta em PDF, KML/KMZ, SHP,
   GeoJSON, GPX, CSV de topografia, GeoTIFF, imagem de satélite), desenhe limites, edificações e
   estradas, ou percorra-os com o GPS do aparelho (Desenhar → GPS no campo). Imagens e plantas fora
   de escala se ajustam com Alinhar por 2 pontos (AL). Georreferencie o projeto (Arquivo →
   Georreferência…) quando quiser mapas base, elevação e clima online ou exportação
   KML/GeoJSON/GPX. Projeto → Projeto automático → Detectar vegetação na imagem… transforma os
   gramados e as copas de uma vista aérea em áreas irrigadas, e Desenhar → Contornar pela imagem
   (`WAND`) contorna um talhão, gramado ou lago a partir de um clique dentro dele na imagem de
   satélite. Os pontos de levantamento entram por um assistente (colunas, separador decimal, sistema
   de coordenadas, prévia no mapa do mundo), e Arquivo → Inserir projeto… mescla outro projeto no
   seu lugar.
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
   cultura, solo, eficiência e balanço hídrico; Projeto → Clima do local… dá a elas o clima mensal,
   e Editar → Geometria → Subtrair da área deixa um lago ou um prédio fora de uma área, como ilha.
5. **Gerenciamento** (Projeto → Turnos de operação): turnos (quais válvulas, pivôs e estações de
   aspersores com válvula abrem juntos, horário e duração). Sem turnos definidos, considera-se que
   todas as válvulas abrem juntas (o pior caso para a linha principal e a fonte). *Automático…*
   agrupa as zonas no menor número de turnos que cabe na vazão da fonte (ou numa vazão e num número
   de zonas que você escolhe), as maiores demandas primeiro; Projeto → Agrupar zonas por energia…
   junta zonas de altura parecida, e Tarifa horária e horários dos turnos… escolhe os horários de
   menor custo de energia; Projeto → Agronomia → Programa de rega… distribui os turnos na janela
   diária de rega, com ciclo e pausa ([Agronomia e manejo da irrigação](agronomy.md)).
   **Fiação**: um controlador (CTRL) e as rotas de fios (WR) até as válvulas, desenhadas à mão ou
   ao longo das valas dos tubos (Zona → Rotas automáticas de fios…), dimensionadas no cálculo.
6. **Verificação** (Projeto → Verificação do projeto…): itens desconectados, tubos que se cruzam
   sem junção, pontas soltas, zonas sem emissores ou que misturam tipos de emissor, catálogo
   faltando, terreno ausente.
7. **Projetar** (F5): zonas, linha principal, telescopagem, lavagem, golpe de aríete, máquinas
   mecanizadas e materiais. Também é possível projetar só as zonas, só a linha principal, ou
   apenas analisar com os diâmetros atuais (inclusive automaticamente a cada edição). O menu Linha
   principal confere a linha principal mais a fundo: transientes hidráulicos, ventosas, simulação
   de 24 horas, operação sob demanda, criticidade dos tubos, calibração da rugosidade, o projeto ao
   longo da vida e fertirrigação. A elétrica da casa de bombas, o bombeamento solar e a análise da
   água entram no cálculo quando ligados ([Energia, água e máquinas](power-water-machines.md)).
8. **Relatórios e plotagem**: painel de relatórios, pranchas em PDF (uma folha, ou uma visão geral
   e uma folha por zona ou por área) com carimbo, legenda, seta norte, escala gráfica, lista de
   materiais, detalhes construtivos e gráficos; orçamento comercial; pacotes de documentos por
   leitor e os documentos técnicos (Relatórios → Documentos técnicos); exportações para outros CADs,
   GIS, BIM, EPANET e planilhas.
