# Manufacturer catalogues (`*.oci.cat`)

This folder is the open catalogue repository of OpenCADIrrigation: one JSON file per
manufacturer with nozzles, sprinklers, drippers, tapes, valves, pumps, pipes and fittings, with the
pressure × flow curves (`q = k·H^x`), wetted radius, pressure range and optional prices. The files
here are bundled with the app (Project → Component catalogue → Manufacturer catalogues) and
published with the site under `assets/catalogs/`. Anyone can maintain another folder like this
one (in a Git repository, on a dealer's site) and load its packs in the app by file or by URL.

The data were taken from the manufacturers' published tables (the `sources` of each pack list the
documents): nozzle curves and radii are least-squares fits of the pressure, flow and radius rows,
emitter constants, exponents, inner diameters and barb losses are as printed, valve losses are
fitted to the loss tables (or derived from Kv), pump curves come from the selection tables. They are
for design and preliminary sizing; always confirm them on the current data sheet. Prices are left
at zero, to be filled in locally.

| Pack | Products |
|---|---|
| `hunter` | PGP Ultra / I-20 and I-25 rotors, MP Rotator, HDL-PC dripline, ICV / PGV valves |
| `rainbird` | 5004 Plus (Rain Curtain, low-angle, MPR nozzles), 8005, 1804 + MPR sprays, XFD / XFS, PEB / PESB |
| `toro` | T5 RapidSet, Aqua-Traxx 16 / 22 mm, BlueLine PC 16 / 18 / 20 mm |
| `netafim` | UniRam AS, DripNet PC, Streamline X, PCJ, SuperNet LR, GyroNet LR, MegaNet 15D |
| `rivulis` | D5000, Hydro PC, T-Tape, Ro-Drip, Supertif, S2000 (standard and flow regulated), Rondo |
| `naandanjain` | 5022, 5022 SD, 5035, 427B AG sprinklers, Hadar 7110 |
| `jain` | Turbo Excel Plus, J-Turbo Line Super, Turbo Cascade PC, J-Turbo Key Plus |
| `nelson` | R2000WF / R2000LP, R33, R3000 pivot Rotator (3TN nozzles), SR100 Big Gun |
| `senninger` | Wobbler, i-Wob2, PMR-MF pressure regulators |
| `irritec` | Multibar C, P1, iDrop PC and turbulent drippers |
| `bermad` | IR-105 control and IR-120 pressure reducing valves, DN 40–150 |
| `schneider` | BC-21 / BC-22 / BC-23 centrifugal and SUB 4" submersible pumps (60 Hz) |
| `amancowavin` | PVC Linha Fixa PN 40 / 80 (NBR 14312), DEFOFORT PN 60 / 80 / 125, Linha Móvel ERR |
| `multilit` | PVC irrigation pipes PN 40 / 60 / 80 (NBR 14312) |

## Using them in the app

- **Bundled**: Project → Component catalogue → *Manufacturer catalogues…* lists the packs in this
  folder; *Add* copies the items into the project catalogue (existing ids are kept).
- **File**: *Import pack (.oci.cat)…* opens a pack from disk. The catalogue's *Import* button also
  accepts `.oci.cat`, besides JSON, CSV and XLSX.
- **URL**: paste the address of a pack (`https://…/rainbird.oci.cat`) or of an index
  (`https://…/index.json`) and click *Load from URL*. An index lists several packs.
- **Publish**: *Export pack .oci.cat…* writes the current project catalogue in this format.

## Pack format

A pack is a JSON object (UTF-8). Recommended extension: `.oci.cat`. Keys:

| key | type | required | description |
|---|---|---|---|
| `format` | string | yes | always `"opencadirrigation-catalog"` |
| `version` | integer | yes | format version; currently `1` |
| `id` | string | yes | stable lowercase identifier (`[a-z0-9_-]`); also the file name (`<id>.oci.cat`) |
| `brand` | string | yes | manufacturer |
| `name` | string | no | pack name (default: the manufacturer) |
| `description` | string | no | product lines covered |
| `source` | string | no | URL of the source data sheet / catalogue |
| `license` | string | no | licence of the data (e.g. `CC0-1.0`) |
| `updated` | string | no | date of the data, `YYYY-MM-DD` |
| `author` | string | no | who prepared the file |
| `sources` | list of strings | no | the documents the data were taken from (titles or URLs) |
| `currency` | string | when priced | ISO 4217 code of the prices (`BRL`, `USD`, `EUR`…); a pack with prices must state it |
| `items` | integer | no | item count (informative, recomputed by the tool) |
| `catalog` | object | yes | the catalogue itself, in the same format the app writes with *Export JSON* |

`catalog` has six lists: `pipes`, `outlets`, `tapes`, `valves`, `pumps`, `fittings`. Every item
has a globally unique `id` (use a manufacturer prefix: `rb_5004`, `ntf_uniram_16_16_50`), a
`name`, optional `sup` (supplier), `code` and `enabled`, and a `cost` (price, 0 = unknown). Internal
units are SI: flows in m³/s, pressures in metres of water column, diameters in mm where the field
name says so (`idMm`, `sizeMm`, `nominalMm`). The key names below are exactly the ones the app
reads and writes; unknown `kind` values are rejected.

### Emitters (`outlets`)

```json
{
  "id": "rb_5004", "name": "Rain Bird 5004 Plus rotor", "kind": "sprinkler",
  "inletMm": 20, "riser": 0.1, "sup": "Rain Bird", "cost": 0,
  "nozzles": [
    { "id": "5004_15", "name": "#1.5 Rain Curtain (0.34 m³/h, R 10.6 m @ 3.0 bar)",
      "curve": { "k": 1.5575e-5, "x": 0.527, "ra": 9.08142, "rb": 0.045 },
      "defH": 30.6, "minH": 17.3, "maxH": 45.9, "cv": 0.03, "arc": 360 }
  ]
}
```

- `kind`: `sprinkler`, `microSprinkler`, `dripper`, `bubbler`, `gun`, `demandPoint`.
- `curve.k` and `curve.x`: flow `q = k·H^x` in m³/s with `H` in m. To convert a nominal flow
  `q_n` (L/h) at `H_n` (m): `k = (q_n / 3.6e6) / H_n^x`. `x ≈ 0.5` for orifices, `≈ 0` for
  pressure-compensating (PC) emitters (use 0.02: a small residual slope keeps the solver well
  conditioned). `ra` and `rb` give the wetted radius `R = ra·H^rb` (m); for a radius `R_n` at
  `H_n`: `ra = R_n / H_n^rb`, with `rb` fitted to the table or 0.2–0.35 when unknown (0 for a
  regulated micro-sprinkler with a fixed wetted diameter).
- `defH`, `minH`, `maxH`: design pressure and allowable range (m). `cv`: manufacturing
  coefficient of variation. `arc`: sector in degrees. `tolB` / `tolA` (optional, default 0.05):
  flow tolerance below / above nominal as a fraction, used by the sizing.

### Tapes and driplines (`tapes`)

```json
{ "id": "ntf_uniram_16_16_50", "name": "Netafim UniRam AS 16010 1.6 L/h @ 0.50 m (PC, AS)",
  "idMm": 14.2, "spacing": 0.5, "nominalMm": 16,
  "emitter": { "k": 4.18434e-7, "x": 0.02 }, "barbK": 1.3, "cv": 0.03,
  "minH": 5.1, "maxH": 35.7, "inletH": 20.4, "tolB": 50, "tolA": 150,
  "ratingM": 35.7, "sup": "Netafim", "code": "16010", "cost": 0 }
```

`idMm` is the inner diameter (mm); `spacing` the emitter spacing (m); `emitter` the curve of one
emitter; `barbK` the local loss coefficient of one emitter (`K·V²/2g`, the Kd of the data sheets); `inletH` the default inlet pressure (m); `tolB` / `tolA` the pressure tolerance (% of
nominal) accepted by the sizing; `ratingM` the pressure rating (m). Optional `c` (Hazen-Williams)
and `roughMm` override the defaults for the tape wall.

### Valves and devices (`valves`)

`kind`: `control` (zone valve), `prv`, `isolation` (gate or ball valve), `check`, `backflow`,
`filter`, `meter`, `airRelease`, `other`. The head loss is `loss`: `{ "k": …, "n": 2, "c": 0 }`
with `h = k·Q^n + c` (Q in m³/s, h in m; `n` defaults to 2 and `c` to 0), or `DeviceLossCurve.fromK`
in the app from the dimensionless K and the diameter. `sizeMm` the diameter; `minQ`/`maxQ` in
m³/s; `setting` the default outlet pressure of a PRV (m).

### Pumps (`pumps`)

`points`: list of `[Q, H]` (m³/s, m) along the curve; the app fits a least-squares quadratic
`H = a·Q² + b·Q + c` through them (three or more points; two give a straight line; one gives the
EPANET-style three-point curve). `eff` (0–1), `kw` (motor power), `minQ`/`maxQ` (m³/s), `cost`,
`sub` (`true` for a submersible pump, installed at the water level; `false` or absent for a
surface pump, whose suction lift is checked).

### Pipes (`pipes`) and fittings (`fittings`)

Pipes: `nominalMm`, `idMm` (inner diameter), `material` (`pvc`, `pehd`, `peld`, `steel`, `aluminium`, `concrete`), `c`
(Hazen-Williams), `roughMm`, `ratingM`, `wallMm`, `usage` (list among `lateral`, `zone`,
`mainline`), `cost` per metre. Fittings: `kind` (`coupler`, `elbow90`, `elbow45`, `tee`, `cross`,
`reducer`, `endCap`, `adapter`, `takeOff`, `tapeEnd`, `riser`), `sizeMm`, `size2Mm` (second size of
reducers and reducing tees), optional `mat`.

### Prices and currency

`cost` is the price in the pack currency (`currency`, ISO 4217). When a priced pack is added to a
project in another currency the app converts the prices with its reference exchange rates and says
so; a pack with prices but without `currency` is added as it is, with a warning. Leave the prices at
zero when they are unknown: the design assistant lists the unpriced items and the economic sizing
estimates the price of an unpriced pipe from its wall cross-section. *Export pack .oci.cat…* writes the
project currency when the catalogue has prices.

## Index (`index.json`)

```json
{ "format": "opencadirrigation-catalog-index", "version": 1,
  "packs": [ { "id": "rainbird", "brand": "Rain Bird", "description": "…",
               "file": "rainbird.oci.cat", "items": 11 } ] }
```

`file` is relative to the index. Given an index URL, the app downloads every pack listed.

## Contributing

1. Copy an existing pack or export your catalogue from the app (*Export pack .oci.cat…*).
2. Use ids with a manufacturer prefix and fill `source` with the URL of the data sheet.
3. Run `dart run tool/gen_catalogs.dart`: it validates (unique ids, plausible curves), normalises
   the JSON and updates `index.json`. `--check` only verifies (used by CI/tests).
4. Open a pull request. The tests in `test/core/catalog_packs_test.dart` make sure every pack
   loads and that ids do not collide with the default catalogue.
