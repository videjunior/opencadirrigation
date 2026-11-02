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
for design and preliminary sizing; always confirm them on the current data sheet. The manufacturer
packs leave the prices at zero, to be filled in locally; the generic pipe packs built from the
standards (`iso1452`, `en12201`, `is4985`, `is4984`) carry reference prices from public price
lists, with their source and date (see [Packs built from the standards](#packs-built-from-the-standards)).

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
| `astm` | PVC pressure pipes in inches: ASTM D2241 SDR 21 / 26 and ASTM D1785 Schedule 40 / 80 (generic, by the standards) |
| `iso1452` | PVC-U pressure pipes of ISO 1452-2, PN 6 / 8 / 10 / 12.5 / 16, dn 20–315 mm (generic; reference prices in EUR) |
| `en12201` | PE 100 pressure pipes of EN 12201-2 / ISO 4427-2, SDR 26 / 21 / 17 / 13.6 / 11 (PN 6–16), dn 20–315 mm (generic; reference prices in EUR) |
| `is4985` | PVC-U pipes of IS 4985 (India), classes 1–6 (0.25–1.25 MPa), dn 20–315 mm (generic; reference prices in INR) |
| `is4984` | PE pipes of IS 4984 (India), PE 100 PN 4–16 and PE 80 PN 4–10, dn 20–315 mm (generic; reference prices in INR) |

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
| `pricesSource` | string | no | where the prices came from (document, items, what a price includes) and how the ones it does not give were estimated |
| `pricesDate` | string | no | date of the prices, `YYYY-MM-DD` |
| `items` | integer | no | item count (informative, recomputed by the tool) |
| `catalog` | object | yes | the catalogue itself, in the same format the app writes with *Export JSON* |

`catalog` has seven lists, `pipes`, `outlets`, `tapes`, `valves`, `pumps`, `fittings` and `wires`
(the conductors from the controller to the solenoids), and `finame`, an object giving the
financing code (Brazilian BNDES FINAME) of an item by id. Every item has a globally unique `id`
(use a manufacturer prefix: `rb_5004`, `ntf_uniram_16_16_50`), a `name`, optional `sup`
(supplier), `code` and `enabled`, and a `cost` (price, 0 = unknown). Internal units are SI: flows in
m³/s, pressures in metres of water column, diameters in mm where the field name says so (`idMm`,
`sizeMm`, `nominalMm`). The key names below are exactly the ones the app reads and writes. A `kind`
the app does not know (a newer version's) falls back to a default (`other` for valves) and is
reported when the file is read; an item that cannot be read at all is kept aside, not lost.

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
`filter`, `meter`, `airRelease`, `other`, `master` (the master valve the controller opens with every
zone), `psv` (pressure sustaining) and `fcv` (flow control, the flow limiter of a hydrant). The head
loss is `loss`: `{ "k": …, "n": 2, "c": 0 }` with `h = k·Q^n + c` (Q in m³/s, h in m; `n` defaults
to 2 and `c` to 0); from a data sheet's flow coefficient Kv (m³/h at 1 bar) `k = 3600² / (Kv² ·
0.0980665)`, from the dimensionless K of `K·v²/2g` `DeviceLossCurve.fromK` in the app. `sizeMm` the
diameter; `minQ`/`maxQ` in m³/s; `setting` the default outlet pressure of a PRV (m).

### Wires (`wires`)

`mm2` (conductor cross-section), `ohm` (resistance of one conductor, Ω per km at 20 °C; absent =
copper of that section), `cost` per metre.

### Pumps (`pumps`)

`points`: list of `[Q, H]` (m³/s, m) along the curve; the app fits a least-squares quadratic
`H = a·Q² + b·Q + c` through them (three or more points; two give a straight line; one gives the
EPANET-style three-point curve). `eff` (0–1), `kw` (motor power), `minQ`/`maxQ` (m³/s), `cost`,
`sub` (`true` for a submersible pump, installed at the water level; `false` or absent for a
surface pump, whose suction lift is checked), `hz` (the mains frequency the curve was measured at;
on a project whose mains frequency differs — Design parameters — a fixed-speed pump turns in
proportion, so a 60 Hz curve on 50 Hz mains gives 5/6 of the flow and 69 % of the head; absent =
not stated, read as it is), `effPts` and `npsh` (lists of `[Q, efficiency]` and `[Q, NPSH required]`).

### Pipes (`pipes`) and fittings (`fittings`)

Pipes: `nominalMm`, `idMm` (inner diameter), `material` (`pvc`, `pehd`, `peld`, `steel`, `aluminium`, `concrete`), `c`
(Hazen-Williams), `roughMm`, `ratingM`, `wallMm`, `usage` (list among `lateral`, `zone`,
`mainline`), `cost` per metre. Fittings: `kind` (`coupler`, `elbow90`, `elbow45`, `tee`, `cross`,
`reducer`, `endCap`, `adapter`, `takeOff`, `tapeEnd`, `riser`), `sizeMm`, `size2Mm` (second size of
reducers and reducing tees), optional `mat`.

### Plausibility

`dart run tool/gen_catalogs.dart --check` and the tests (`test/core/catalog_plausibility_test.dart`)
check every pack physically: a thermoplastic pipe wall must withstand its pressure class (the hoop
stress `σ = P·(SDR − 1)/2` within the design stress of PVC 14.7 MPa, PE 100 8 MPa, low-density PE
3.2 MPa), a sprinkler nozzle whose name gives its bore (`3.5 mm`, `3.0 × 1.8 mm`) cannot pass more
than an ideal orifice (discharge coefficient ≤ 1), and the hydraulic power along a pump curve stays
within 0.85 of the motor at its service factor (NEMA MG 1: 1.4 for a 1 hp submersible, 1.15 for a
common motor). A value that fails was most likely misread from the data sheet.

### Prices and currency

`cost` is the price in the pack currency (`currency`, ISO 4217). When a priced pack is added to a
project in another currency the app converts the prices with its reference exchange rates and says
so; a pack with prices but without `currency` is added as it is, with a warning. Say where the
prices came from in `pricesSource` (the document, its items, what a price includes, and how the
prices it does not give were estimated) and their date in `pricesDate`, as the packs built from the
standards do. Leave the prices at zero when they are unknown and no trustworthy source is at hand:
the design assistant lists the unpriced items and the economic sizing estimates the price of an
unpriced pipe from its wall cross-section. *Export pack .oci.cat…* writes the project currency when
the catalogue has prices.

## Packs built from the standards

`astm`, `iso1452`, `en12201`, `is4985` and `is4984` are not edited by hand: `tool/gen_catalogs.dart`
builds them from `lib/core/model/pipe_standards.dart`, and `--check` fails when a file differs from
what it builds. Each class (PN, SDR or IS class) of a standard gives one pipe per size of its table:

- `nominalMm` is the nominal outside diameter dn, `wallMm` the wall of the table (the nominal wall
  e_n of ISO 1452-2 and EN 12201-2, which is also their least wall at any point; the least wall
  e_min of IS 4985 and IS 4984) and `idMm` = dn − 2·wall (nominal outside diameter and table wall,
  without the tolerances);
- `ratingM` is the class in metres of water (1 bar = 10.197 m); `material` `pvc` or `pehd`; `c` and
  `roughMm` as the default catalogue (PVC 150 / 0.0015 mm; PE 145 / 0.003 mm up to 50 mm, 150 /
  0.002 mm above); `usage` laterals and submains up to 32 mm, submains and mains up to 110 mm,
  mains above; `sup` the standard;
- the ids are `<pack>_<class>_<dn>`: `iso1452_pn10_110`, `en12201_sdr11_63`, `is4985_class3_110`,
  `is4984_pe100_pn6_110`.

| Pack | Table | Design stress of the wall × class check |
|---|---|---|
| `iso1452` | ISO 1452-2:2009 Table 2: PN 6 / 8 / 10 / 12.5 / 16 are S 16 / 12.5 / 10 / 8 / 6.3 up to dn 90 and S 20 / 16 / 12.5 / 10 / 8 above; at least 1.5 mm | MRS 25 MPa over the design coefficient: 10 MPa up to dn 90 (C = 2.5), 12.5 MPa above (C = 2.0) |
| `en12201` | EN 12201-2 Table 2, PE 100 SDR 26 / 21 / 17 / 13.6 / 11 = PN 6 / 8 / 10 / 12.5 / 16; at least 2.0 mm (3.0 mm for 32 mm SDR 11, as the standard rounds the small sizes) | 8 MPa (MRS 10 MPa, C = 1.25) |
| `is4985` | IS 4985:2021 Table 1, classes 1 to 6 = 0.25 / 0.4 / 0.6 / 0.8 / 1.0 / 1.25 MPa at 27 °C | 8.6 MPa at 27 °C |
| `is4984` | IS 4984:2016 Table 4 as replaced by Amendment 2 (2022): PE 100 PN 4 / 6 / 8 / 10 / 12.5 / 16 = SDR 33 / 21 / 17 / 13.6 / 11 / 9, PE 80 PN 4 / 6 / 8 / 10 = SDR 26 / 17 / 13.6 / 11 | the design stress of its Table 1 × 0.85 (PN at 27 °C): PE 100 8 × 0.85 = 6.8 MPa, PE 80 6.3 × 0.85 = 5.36 MPa |
| `astm` | ASTM D2241 SDR 21 / 26 and ASTM D1785 Schedule 40 / 80, inch sizes | plausibility rules only |

The ISO 1452-2 and EN 12201-2 walls are the ISO 4065 values: e = dn/(2S + 1) with the exact series
value S = 10^(k/10), worked to 0.01 mm and rounded up to 0.1 mm. The generator checks every pipe it
builds: the wall not below the table's, the hoop stress at the class, σ = P·(SDR − 1)/2 with SDR =
dn/wall, within the design stress of the standard (3 % for the rounding of the published classes),
and the plausibility rules above.

Prices: the rows a public price document gives are used as printed; the other pipes of the pack are
priced by a least-squares line through those rows, price per metre = a + b·m with m the mass per
metre π·(dn − wall)·wall·ρ (PVC-U 1400 kg/m³, PE 960 kg/m³), weighted by 1/price² and with the fixed
part a ≥ 0. `pricesSource` names the document and gives the line.

| Pack | Prices | Date |
|---|---|---|
| `iso1452`, `en12201` | Regione Autonoma della Sardegna, *Prezzario regionale dell'agricoltura*, 2024 update (Decreto n. 36 prot. 4817 of 12.12.2024), items F.001 to F.006: PVC-U (UNI EN 1452-2) PN 6 / 10 / 16 and PE 100 (UNI EN 12201-2) PN 10 / 16 / 25, supplied **and laid** with their joints and fittings (trench and bedding excluded), EUR per metre without VAT. Item F.004.004 (PE 100 SDR 17, 90 mm, printed at the price of the SDR 11 pipe) is taken as a misprint and priced by the line. | 2024-12-12 |
| `is4985`, `is4984` | Maharashtra Jeevan Pradhikaran, *State Schedule of Rates 2023-24* (in force from 20 June 2023): section I(II) item 1, PVC pipes to IS 4985 with solvent-cement couplers, 4 to 12.5 kg/cm², 63 to 315 mm; section I(IX) item 1, PE 100 pipes to IS 4984, 6 to 16 kg/cm², 63 to 315 mm; supplied to the stores, INR per metre without GST. PE 100 PN 4 and the PE 80 pipes are priced by the line (the PN 4 rows of Corrigendum 1 are stated with GST and are not used). | 2023-06-20 |

They are reference prices to compare sizes and classes; replace them with a local price list before
a quotation.

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
3. Run `dart run tool/gen_catalogs.dart`: it builds the packs of the standards, validates (unique
   ids, plausible curves, walls against classes), normalises the JSON and updates `index.json`.
   `--check` only verifies (used by CI/tests). The packs built from the standards change in
   `lib/core/model/pipe_standards.dart`, not in their files.
4. Open a pull request. The tests in `test/core/catalog_packs_test.dart` make sure every pack
   loads and that ids do not collide with the default catalogue.
