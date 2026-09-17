# Manufacturer catalogues (`*.oci.cat`)

This folder is the open catalogue repository of OpenCADIrrigation: one JSON file per
manufacturer with nozzles, sprinklers, drippers, tapes, valves, pumps and fittings, with the
pressure × flow curves (`q = k·H^x`), wetted radius, pressure range and optional prices. The files
here are bundled with the app (Project → Component catalogue → Manufacturer catalogues) and
published with the site under `assets/catalogs/`. Anyone can maintain another folder like this
one (in a Git repository, on a dealer's site) and load its packs in the app by file or by URL.

The values here are typical catalogue data, for illustration and preliminary sizing. Always
confirm them on the manufacturer's data sheet; prices are left at zero to be filled in locally.

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
| `items` | integer | no | item count (informative, recomputed by the tool) |
| `catalog` | object | yes | the catalogue itself, in the same format the app writes with *Export JSON* |

`catalog` has six lists: `pipes`, `outlets`, `tapes`, `valves`, `pumps`, `fittings`. Every item
has a globally unique `id` (use a manufacturer prefix: `rb_5004`, `ntf_uniram_16_16_50`), a
`name`, optional `supplier`/`code` and a `cost` (price, 0 = unknown). Internal units are SI: flows
in m³/s, pressures in metres of water column, diameters in mm where the field name says so
(`innerMm`, `sizeMm`, `nominalMm`).

### Emitters (`outlets`)

```json
{
  "id": "rb_5004", "name": "Rain Bird 5004 Plus rotor", "kind": "sprinkler",
  "inletMm": 20, "riser": 0.1, "supplier": "Rain Bird", "cost": 0,
  "nozzles": [
    { "id": "5004_15", "name": "#1.5 (0.31 m³/h, R 7.6 m)",
      "curve": { "k": 1.57e-5, "x": 0.5, "radius": 7.6, "radiusB": 0.35 },
      "default": 30, "minH": 17, "maxH": 45, "cv": 0.03, "arc": 360 }
  ]
}
```

- `kind`: `sprinkler`, `microSprinkler`, `dripper`, `gun`, `demandPoint`.
- `curve.k` and `curve.x`: flow `q = k·H^x` in m³/s with `H` in m. To convert a nominal flow
  `q_n` (L/h) at `H_n` (m): `k = (q_n / 3.6e6) / H_n^x`. `x ≈ 0.5` for orifices, `≈ 0` for
  pressure-compensating (PC) emitters. `radius` is the wetted radius in m at `H_n`; `radiusB` the
  exponent of the radius with pressure (0.35 is typical).
- `default`, `minH`, `maxH`: design pressure and allowable range (m). `cv`: manufacturing
  coefficient of variation. `arc`: sector in degrees.

### Tapes and driplines (`tapes`)

```json
{ "id": "ntf_uniram_16_16_50", "name": "Netafim UniRam AS 16 mm 1.6 L/h @ 0.50 m",
  "innerMm": 14.2, "spacing": 0.5, "nominalMm": 16,
  "emitter": { "k": 3.2e-7, "x": 0.02 }, "barbK": 0.3, "cv": 0.03,
  "minH": 5, "maxH": 40, "defaultInletH": 15, "tolBelow": 50, "tolAbove": 160,
  "ratingM": 40, "supplier": "Netafim", "cost": 0 }
```

`spacing` is the emitter spacing (m); `emitter` the curve of one emitter; `tolBelow` /
`tolAbove` the pressure tolerance (% of nominal) accepted by the sizing; `ratingM` the pressure
rating (m).

### Valves and devices (`valves`)

`kind`: `control` (zone valve), `prv`, `gate`, `check`, `filter`, `meter`, `backflow`, `air`…
The head loss is `loss`: `{ "k": …, "n": 2 }` with `h = k·Q^n` (Q in m³/s, h in m), or
`DeviceLossCurve.fromK` in the app from the dimensionless K and the diameter. `minFlow`/`maxFlow`
in m³/s; `setting` the default outlet pressure of a PRV (m).

### Pumps (`pumps`)

`points`: list of `[Q, H]` (m³/s, m) along the curve; the app fits `H = a − b·Q²` through them.
`efficiency` (0–1), `powerKw`, `cost`.

### Pipes (`pipes`) and fittings (`fittings`)

Pipes: `nominalMm`, `innerMm`, `material`, `c` (Hazen-Williams), `roughnessMm`, `ratingM`,
`usage` (list among `lateral`, `zone`, `mainline`), `cost` per metre. Fittings: `kind`
(`tee`, `elbow`, `coupler`, `reducer`, `endCap`, `riser`, `valveBox`…), `sizeMm`, `size2Mm`.

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
