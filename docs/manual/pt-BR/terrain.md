# Terreno

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
