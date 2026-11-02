# Licença, componentes e dados de terceiros

O OpenCADIrrigation é distribuído sob a [licença MIT](../../../LICENSE.md). É uma ferramenta de apoio à
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
| Subconjuntos Noto Sans em `assets/fonts` (latino, Math, árabe, devanágari, bengali, gurmukhi, télugo, SC, JP) | texto dos PDFs em todas as escritas da interface | SIL OFL 1.1 ([assets/fonts/OFL.txt](../../../assets/fonts/OFL.txt)) |

Os serviços online, acessados quando você os usa, têm seus próprios termos, e o app mostra os
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

Os catálogos de fabricantes em [catalogs/](../../../catalogs/) foram compilados das fichas técnicas públicas
dos fabricantes, e cada pacote cita sua fonte. Nomes de produtos e marcas pertencem aos seus donos;
o projeto não tem vínculo com nenhum deles, e os preços são valores de referência a confirmar com
um revendedor.
