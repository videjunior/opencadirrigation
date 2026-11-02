# Licence, third-party components and data

OpenCADIrrigation is released under the [MIT licence](../../LICENSE.md). It is an engineering aid: its
results depend on the data entered and on the catalogue values, and a qualified designer should
check a design before it is built (the licence carries no warranty).

| Component | Used for | Licence |
|---|---|---|
| Flutter and the Dart SDK | framework and language | BSD-3-Clause |
| [`web`](https://pub.dev/packages/web) | browser APIs (files, storage, workers, geolocation, streamed requests) | BSD-3-Clause |
| [`xml`](https://pub.dev/packages/xml) | KML, GPX, LandXML and XLSX | MIT |
| [`archive`](https://pub.dev/packages/archive) | KMZ, XLSX, zipped shapefiles, PDF streams, compressed share links and stored projects | MIT |
| [`image`](https://pub.dev/packages/image) | raster images, images in PDFs, vegetation detection and the brand assets | MIT |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | icon font | MIT |
| CanvasKit (Skia) | rendering, served by the site with the app | BSD-3-Clause |
| Material Icons, Roboto, Noto | interface fonts (Roboto served with the app; Noto fetched on demand for other scripts and kept for offline use) | Apache-2.0, SIL OFL 1.1 |
| Noto Sans subsets in `assets/fonts` (Latin, Math, Arabic, Devanagari, Bengali, Gurmukhi, Telugu, SC, JP) | text of the PDFs in every interface script | SIL OFL 1.1 ([assets/fonts/OFL.txt](../../assets/fonts/OFL.txt)) |

Online services, reached when you use them, have their own terms; the app shows their
credits: base maps (© OpenStreetMap contributors under the ODbL, OpenTopoMap under CC-BY-SA, CARTO,
Esri, Google Maps with your own key, or the XYZ or WMS server you configure), elevation (Terrain
Tiles on AWS Open Data: SRTM/NASA, GMTED, ETOPO1; Open-Meteo under CC BY 4.0 with the Copernicus DEM
GLO-90; OpenTopoData: NASA SRTM, ASTER GDEM), climate (Open-Meteo historical weather API under CC BY
4.0, ERA5 reanalysis of the Copernicus Climate Change Service, free for non-commercial use; NASA
POWER, with the acknowledgement NASA asks for) and the AI assistant (the APIs of Anthropic and
OpenAI, used with your own key and account under that company's terms, which bill the usage to
that account; site searches by address use OpenStreetMap's Nominatim, © OpenStreetMap contributors
under the ODbL, within its usage policy; the satellite pictures come from Esri World Imagery or,
with your key, Google).

The manufacturer catalogues in [catalogs/](../../catalogs/) were compiled from the manufacturers' public
data sheets, and every pack names its source. Product names and trademarks belong to their owners;
the project is not affiliated with any of them, and prices are reference values to confirm with a
dealer.
