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
| Material Icons, Roboto, Noto | fontes da interface (Roboto servida com o app; Noto servida pelo site em `fonts/`, baixada sob demanda para outras escritas e guardada para uso sem rede) | Apache-2.0, SIL OFL 1.1 |
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

**No trabalho profissional.** Ajuda → Termos dos dados lista os dados de terceiros que o projeto
leva e, para cada fonte de elevação, clima e busca de endereços, o crédito, o que o uso gratuito
permite e um link para os termos (os mapas base têm os seus em Ver → Mapa base → Termos dos mapas).
Os serviços gratuitos do Open-Meteo são para uso não comercial, então o download do clima começa no
NASA POWER (livre para qualquer uso) e a elevação online no Terrain Tiles; o Open-Meteo continua
disponível, marcado como não comercial. As pranchas (PDF, PNG, SVG) imprimem, uma por linha, o
crédito do mapa base sob o desenho, das imagens de mapa guardadas para o campo e da elevação online
que mostram, e o relatório tem a tabela **Fontes de dados e créditos** (no painel de relatórios, no
PDF, no Excel e no CSV): mantenha os créditos ao entregar ou publicar o trabalho. O mapa guardado
para o campo (Ver → Mapa base → Guardar o mapa da área para o campo) segue os termos de cada
provedor: só os blocos que a página já mostrou para OpenStreetMap, OpenTopoMap, CARTO e Esri (a
política da Fundação OpenStreetMap proíbe baixar áreas dos seus blocos para uso off-line), os blocos
do seu próprio servidor baixados para a área, nada para os mapas do Google.

Os catálogos de fabricantes em [catalogs/](../../../catalogs/) foram compilados das fichas técnicas públicas
dos fabricantes, e cada pacote cita sua fonte. Nomes de produtos e marcas pertencem aos seus donos;
o projeto não tem vínculo com nenhum deles, e os preços são valores de referência a confirmar com
um revendedor.
