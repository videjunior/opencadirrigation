# Third-party test files

The DWG and DXF drawings at the top of this folder (`example_*.dwg`,
`example_2000.dxf`, `sample_*.dwg`) and in `2000/`, `2004/`, `2007/`, `2010/`
and `2018/` (the drawings of single entities with their `.txt` property
listings), 54 files in all, are **not part of OpenCADIrrigation and are not
covered by its MIT licence**.

They are byte-for-byte copies of test data of [GNU LibreDWG](https://www.gnu.org/software/libredwg/)
(`test/test-data/` in its repository; checked against commit
`86e04c74669a515460c909486489b5ae6e47f542` on 2026-11-02). LibreDWG is
distributed under the GNU General Public License, version 3 or later, and
these files are redistributed here unchanged under the same terms. Some of
them were produced by the LibreDWG contributors with third-party CAD
programs and may carry those programs' own notices.

They serve only the tests of the DWG and DXF readers (`test/core/dwg_test.dart`
and the format tests): the app never ships them (no file of `test/` is an
asset in `pubspec.yaml`), and no code of this project is derived from them.

The other fixtures belong to this project (MIT):

- `formats/`: written by `tool/formats/make_fixtures.py` with independent
  libraries (ezdxf, pyshp, Pillow, tifffile, openpyxl) and LibreDWG;
- `shaping/`: written by `tool/fonts/make_shaping_fixtures.py` from the fonts
  of `assets/fonts` and the strings of `assets/i18n`.

Recorded weather forecasts in `forecast/` (the tests of the irrigation
forecast) are data of their providers, kept under their CC BY 4.0 licences:

- `forecast/met_locationforecast.json`: based on data from MET Norway
  (Locationforecast 2.0 "complete" for -22.7253, -47.6492, fetched on
  2026-11-10 03:00 UTC), trimmed to the variables the app reads and to the
  hours before 2026-11-15 06:00 UTC;
- `forecast/open_meteo_forecast.json`: weather data by Open-Meteo.com (the
  Forecast API answer for the same point and day, unchanged but for the
  whitespace).

`climate_risk/` holds two answers of the NASA POWER daily point API
(power.larc.nasa.gov, recorded unchanged on 2026-11-10 at 22.90° S, 47.06° W):
public data, free for any use. The data was obtained from the National
Aeronautics and Space Administration (NASA) Langley Research Center's
Prediction Of Worldwide Energy Resources (POWER) project funded through the
NASA Earth Science Division.
