# Terreno

- **Fontes de elevação**: curvas de nível desenhadas (com incremento automático e opção de
  suavizar), linhas de quebra (`BRK`: cristas, canais e taludes em que a superfície deve dobrar),
  cotas de ponto (a elevação é pedida a cada clique), pontos de levantamento (CSV, TXT, XYZ, PTS,
  PNEZD, pelo assistente de importação), DXF/DWG/DGN com elevação (polilinhas em camadas de contorno
  ou com cota; no DXF e no DWG também faces 3D, malhas e blocos de levantamento cujo atributo ou
  inserção traz a cota), KML com altitude, shapefile com Z ou atributo de elevação, waypoints de GPX,
  nuvens de pontos LAS (a classe de terreno), superfícies e pontos LandXML, GeoTIFF de elevação
  (raster de uma banda, também BigTIFF e GeoTIFF otimizado para a nuvem, amostrado na grade sem
  decodificar o resto) e a **elevação da internet**.
- **Modelo digital**: triangulação de Delaunay (TIN) restrita pelas linhas de quebra, com
  interpolação linear nos triângulos, exata em rampas planas, e interpolação por inverso da
  distância como alternativa e como complemento fora do casco convexo (com as amostras de fato mais
  próximas, perto ou longe dos dados). As curvas de nível são amostradas a cada 5 m (ajustável). O
  TIN aceita até 40 000 amostras como estão; acima disso ele mantém todas as amostras do seu próprio
  levantamento (curvas de nível, cotas de ponto, linhas de quebra, pontos) e uma distribuição
  uniforme do modelo de elevação baixado, com os cantos do seu contorno, o que o app avisa uma vez por
  projeto (a interpolação IDW usa todas); nuvens de pontos e superfícies LandXML são rarefeitas numa
  grade ao serem lidas. O modelo não depende da ordem dos itens: as amostras são numeradas pela
  posição antes da triangulação, então pontos co-circulares (a célula de uma grade) recebem sempre a
  mesma diagonal, e amostras no mesmo lugar (a 1 mm) se fundem, com o vértice de uma linha de quebra
  vencendo os outros pontos e os pontos de mesma natureza ficando com a média das cotas. Uma cota
  desconhecida nunca vira 0 m, e itens hidráulicos a mais de 10 m fora dos dados de terreno são
  avisados (`outside_terrain`: a cota deles é extrapolada).
- **Elevação da internet** (Projeto → Terreno → Baixar elevação da internet (MDT)…): uma grade de
  pontos sobre o projeto ou sobre a área visível é consultada em serviços públicos e gratuitos, sem
  chave: Terrain Tiles no AWS Open Data (SRTM 30 m, GMTED, ETOPO1; o padrão), Open-Meteo (Copernicus
  GLO-90; 600 coordenadas por minuto) e, nos builds para desktop, OpenTopoData (SRTM 30 m, ASTER
  30 m; a sua API pública não envia cabeçalho CORS, então navegadores não podem usá-la). Por padrão
  o download substitui as cotas que você informou, que costumam estar em outro datum que o modelo.
  Num projeto vazio basta colar a coordenada do local (decimal, link do Google Maps ou
  graus/minutos/segundos): a origem do desenho vai para lá e a elevação é baixada num quadrado ao
  redor. Ao terminar, as curvas de nível podem ser geradas automaticamente com intervalo escolhido a
  partir do desnível. Os blocos e pontos baixados ficam guardados no aparelho (Arquivo → Dados
  baixados guardados…), então refazer o terreno não os baixa de novo e funciona com conexão fraca no
  campo.
- **Ferramentas**: gerar curvas de nível do modelo (curvas derivadas, que não realimentam o modelo),
  vista 3D do terreno com os tubos drapejados, mapas de declividade e de exposição (Ver →
  sobreposição, com a fração da área em cada classe de declividade), perfil ao longo de um caminho
  (com o tubo e a linha piezométrica quando há resultados), e a pressão de cada emissor considera a
  cota do terreno mais a altura da haste menos a profundidade de enterro.
