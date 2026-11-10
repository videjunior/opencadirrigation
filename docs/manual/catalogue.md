# Component catalogue

The project catalogue has seven groups: **pipes**, **emitters** (with nozzles), **tapes**, **valves
and devices**, **pumps**, **fittings** and **wires**. All internal hydraulic values are in SI.

| Group | Main fields |
|---|---|
| Pipes | DN, inner diameter, material (which sets the Scobey and Manning coefficients and the derating of PVC and PE pressure classes with warm water), Hazen-Williams C, roughness, pressure rating, usage (lateral, zone, mainline), cost per metre, supplier, code |
| Emitters and nozzles | Kind (sprinkler, micro-sprinkler, dripper, bubbler, gun, demand point), curve `q = k·H^x`, wetted radius `R = a·H^b`, arc, default, minimum and maximum pressure, manufacturing CV, flow tolerance, inlet diameter, riser height, cost; a nozzle curve can be fitted to the rows of its data sheet (pressure, flow and radius pasted as a table), and a measured radial profile (catch-can test) feeds the densogram |
| Tapes | Inner diameter, emitter spacing and curve, barb coefficient, CV, default, minimum and maximum inlet pressure, tolerances above and below, rating, cost per metre |
| Valves and devices | Kind (zone, master, PRV, pressure-sustaining, flow control, gate, check, backflow, filter, meter, air valve, other), diameter, loss `h = K·Q^n + C`, minimum and maximum flow, default setting, cost |
| Pumps | (Q, H) points fitted to a parabola, efficiency (or an efficiency curve), NPSH required curve, power, maximum flow, submersible or surface, the mains frequency the curve was measured at, cost |
| Fittings | Kind (coupler, 90° and 45° elbow, tee, cross, reducer, end cap, adapter, lateral take-off, tape end, riser), diameters, cost |
| Wires | Conductor section (mm²), resistance (Ω/km), cost per metre, supplier, code; CSV columns `mm2` or `awg`, `ohmKm` (copper is assumed when only the section is given) |

Any item can also carry the FINAME code under which it is credentialed for financing by the
Brazilian development bank BNDES; the bill of materials and the quote show it.

The editor shows and takes the values in the units of the project and keeps them in SI: in a US
project, diameters in inches, classes and pressures in the pressure unit (psi, bar, kPa, ft H₂O),
spacings and prices per foot, the flows of valves and the pump curves (Q@H, efficiency, NPSH) in
gpm; a default metric project is unchanged. The exported CSV is in the units of the project too, with
the unit in the name of each column (`nominal_in`, `rating_psi`, `spacing_ft`, `maxQ_gpm`,
`points_gpm_psi`, `cost_per_ft`), and the import reads such columns and those of price lists
("DN (in)", "PN (psi)", "Cost (per ft)", `q_gph`).

The **default catalogue** ships 17 pipes (PE 16–50 mm, PVC DN 35–250, HDPE 110 and 160, 6" steel),
10 emitter families (PC and turbulent drippers, micro-sprinklers, PC bubbler, impact sprinkler, gun,
garden rotor and spray, demand point), 6 tapes and driplines, 36 valves and devices (1" to 6",
master valves, pressure-sustaining valves and hydrants with flow limiter among them), 18 pumps
(centrifugal 1 to 100 hp, submersible 3 to 30 hp) and about 330 fittings generated for every
nominal diameter (couplers, 90° and 45° elbows, tees, crosses, end caps, adapters and reducers, plus
lateral take-offs, tape ends and risers) and 12 copper wires (1 to 10 mm² enabled, AWG 18 to 8
disabled: enable them where AWG is the norm), with translated names and illustrative prices. The PVC
PN 80 pipes have the inner diameters and walls of NBR 14312 up to DN 150 and of ISO 1452-2 S 12.5
above, the PE PN 6 pipes the wall of PE 80 SDR 21, the impact sprinkler nozzles a discharge
coefficient of 0.96 and every pump a motor its curve fits. A plausibility check runs over the default
catalogue and every pack: the hoop stress of a thermoplastic wall against its class, a nozzle passing
no more than an ideal orifice of its bore, the hydraulic power within 0.85 of the motor with its
service factor (NEMA MG 1).

The editor (Design → Component catalog…) edits, duplicates and removes items, imports and exports
JSON, CSV per group and **Excel** (export, fill in prices in the spreadsheet and import it back), sets
the default catalogue for new projects (*Use as default for new projects*) and, as separate actions that each ask
first, saying how many items leave and how many objects use them, *Restore the factory catalog…*,
*Load my default…* and *Forget my default…*. An imported row without an id gets a stable one (from
its supplier, code and name), so the same row imported again updates its own item and never another
list's; replacing an item the drawing uses is warned about, and rows without a diameter, curve or
section are left out with a warning. The CSV follows RFC 4180; the `kv` column is the flow
coefficient of the data sheets (Δp = (Q/Kv)² bar) and `kcoef` the K of K·v²/2g; a PN without a unit up
to 25 is asked about (bar or metres of head). An item switched off or removed that the drawing still
uses shows as itself, marked, in the Properties.

## Digitise a curve from a picture

**Design → Digitise a curve from a picture…** (right below *Component catalog…*; on a phone ☰ → Design) reads a curve
off a picture of a chart (a catalogue page, a screenshot, a photo of a data sheet) and puts it into the project's
catalogue. Nothing leaves the device. It reads three kinds of chart:

- **Pump**: the head against the flow and, as further curves of the same picture, the efficiency, the NPSH required
  and the shaft power, sharing the horizontal (flow) axis, each with its own vertical axis.
- **Outlet or sprinkler**: the flow against the pressure (tick *Flow along the horizontal axis* when the chart is drawn
  that way), fitted to q = k·Hˣ.
- **Sprinkler radial profile**: the application rate against the distance from the head.

**How to use it.**

1. Open the picture (*Open picture…*), paste it (Ctrl+V of a screenshot) or drop the file on the window. PNG, JPEG and
   WebP are read; a photo is turned upright by its EXIF tag, and a picture larger than 3200 pixels is reduced.
2. **Horizontal axis**: click two ticks of the axis far apart and type their values; choose the unit and, for a
   logarithmic scale, *Logarithmic*. **Vertical axis**: the same on the vertical axis of the curve. The tool moves on
   by itself after the second click of each axis.
3. **Points**: click along the curve. Drag a point to move it; select one and press Delete (or *Delete point*, or a
   right-click) to remove it; *Undo* takes back the last change. The mouse wheel or a pinch zooms, dragging the
   picture pans, and a button in the corner shows the whole picture again. A magnifier follows the mouse; on a touch
   screen a long press shows it and the point goes where the finger lifts.
4. Or **Automatic trace**: set the two limits along the horizontal axis (*From*, *To*) and the number of points, then
   click on the curve. Its colour is followed to both sides and evenly spaced points are placed, which you then
   correct. Raise the *Colour tolerance* for a faint or blurred line, lower it when the trace jumps to something else.
5. Check the **Fit**: the fitted curve is drawn over the picture, and the table lists each point with its residual.
6. Choose where it goes and press **Apply to the catalogue**: one undo step. *Export CSV* and *Copy points* give the
   points in the units of the axes. The picture, the calibration and the points stay with the tab while the dialog is
   closed (not in the project file).

**Where it goes.**

- **Pump**, new or updated: the head points replace the pump's curve (the engine fits them as it fits a data sheet:
  the least-squares parabola when it stays within 3 % of the highest head, the head tolerance of ISO 9906 grade 1B,
  else the monotone curve through the points), and their range of flows becomes the pump's minimum and maximum flow;
  the efficiency points replace the efficiency curve (its best value becomes the single efficiency); the NPSH points
  replace the NPSH curve. Without an efficiency curve, the shaft power gives the efficiency at each power point,
  η = ρ·g·Q·H / P, with H read on the fitted head curve. A pump without a rated power takes the largest shaft power
  read. A new pump needs at least three head points.
- **Outlet**: a new outlet (one nozzle, the chart's pressures as its range and the middle one as its default), a
  nozzle of an outlet of the catalogue, or the emitter of a drip tape. Only k and x change: the wetted radius and the
  start of pressure compensation stay.
- **Profile**: the measured profile of a nozzle (distance over the wetted radius read, rate over its largest value),
  which the densogram uses with *Use the measured profile of the nozzles that have one*.

**Method.** The two points of each axis give its values and its direction (the vertical value does not change along
the horizontal axis, and the other way round): the general affine mapping u = a·x + b·y + c, v = d·x + e·y + f, with
u and v the values, or their decimal logarithms on a logarithmic axis, so rotated and sheared scans read right. The
calibration is refused, with the reason, when the two points of an axis are at the same place, its two values are
equal, a logarithmic axis has a value at or below zero, or the two axes were clicked less than 10° apart. The
automatic trace takes the colour clicked (the pixel nearby that differs most from the background) and keeps the
pixels whose colour lies between the background and that colour (the blended edge of an anti-aliased line counts; a
light grid line or a curve of another colour does not); it follows the curve one pixel at a time along the horizontal
axis, taking the run of pixels nearest to where the last steps lead, bridges short gaps (a grid line drawn over the
curve, a label) and stops at longer ones. The flow–pressure points are fitted to q = k·Hˣ by least squares in log–log
space, the pump points as above. The assistant reads a chart from an attached picture with its own vision and does
the same through `fit_curve_points`, `apply_curve_points` and `export_curve_points`.

**Limits.** A photo taken at an angle (perspective) is not affine and reads only approximately: photograph the page
square on, or use a scan. The trace assumes one value of the curve for each horizontal value, as catalogue curves are;
a chart with several impeller diameters is read one diameter at a time. The power curve is taken as the shaft power
(P2): from a chart of the motor's input power (P1) the efficiency is the overall one, so set the pump's motor
efficiency to 100 % then. The rated frequency of the pump, the wetted radius of a nozzle and the costs are not read
from the picture: set them in the catalogue.

## Prices and currency

Every price of a project (catalogue, energy tariff, pivot machines) is in one currency, stored as an
ISO 4217 code with the symbol shown in tables and reports (Design → Design parameters → Currency).
A new project takes the currency of the machine's region when the system locale of the interface
language names one (`pt-PT` → EUR, `en-IN` → INR, `de-CH` → CHF), else the currency of the most
populous country of the language (pt BRL, en USD, es MXN, de/fr EUR, ja JPY, zh CNY, hi/mr/te/pa INR,
bn BDT, ur PKR, ar EGP, ru RUB, tr TRY, id IDR, vi VND, ha NGN, sw TZS). The illustrative prices of the
default catalogue and the default energy tariff (0.75 R$/kWh) are written in reais and converted with
reference exchange rates (European Central Bank and exchangerate-api.com, 2026-09-21), so every
language gets the same design; they only order the options for the economic sizing and should be
replaced by a local price list. Choosing another currency asks whether to convert every price, with
the reference rate offered and editable, and becomes the currency of new projects. The saved default
catalogue remembers its currency and is converted for projects in another one. The gallery examples
use the currency of their language (in the app, the user's currency). The list includes the Chilean
UF (`CLF`), the inflation-indexed unit public subsidy contests ask budgets in (taken as CLP 40 000;
type the day's value when converting).

Items without a price (manufacturer packs come without them) are reported by the design assistant
(`bom_unpriced`); the bill of materials leaves them out of the totals and the economic sizing prices a
pipe without cost in proportion to its wall cross-section, calibrated on the priced pipes of the same
material, so the diameters keep their order.

## Manufacturer catalogues (`.oci.cat`)

Fourteen packs ship with the app (259 items): Hunter, Rain Bird, Toro, Netafim, Rivulis,
NaanDanJain, Jain, Nelson and Senninger (sprinklers, micro-sprinklers, drippers, tapes and
driplines, pivot sprinklers, big guns, valves and regulators), Irritec (driplines and drippers),
Bermad (hydraulic valves), Schneider (centrifugal and 4" submersible pumps, with curves measured at
60 Hz), and Amanco Wavin and Multilit (PVC irrigation pipes, NBR 14312). The data come from the
manufacturers' published tables: nozzle curves `q = k·H^x` and radii `R = a·H^b` fitted by least
squares to the pressure, flow and radius rows (the radius anchored at the design pressure), emitter
constants, exponents, inner diameters and barb losses (Kd) as printed, pressure ranges and wall
classes, valve losses fitted to the loss tables (or taken from Kv), and pump curves from the
selection tables (pump efficiency estimated from the rated power, since the tables omit it). Each
pack lists its source documents (`sources`). Prices are left at zero; a pack that carries prices
states their currency (`currency`) and is converted to the project currency when added; a pump
states the frequency its curve was measured at (`hz`), so on other mains (Design parameters) a
fixed-speed pump turns in proportion. They live in [catalogs/](../../catalogs/) as JSON files, one per
manufacturer, plus an `index.json`.

Five generic packs, with no brand, hold thermoplastic pipes by standard: `iso1452` (PVC-U by
ISO 1452-2, PN 6 to 16), `en12201` (PE 100 by EN 12201-2, SDR 26 to 11), `is4985` (PVC-U by IS 4985,
classes 1 to 6) and `is4984` (PE 100 and PE 80 by IS 4984), dn 20 to 315 mm, 415 pipes generated by
`tool/gen_catalogs.dart` from the tables of the standards with every wall checked against its class,
and `astm` (PVC in inches by ASTM D2241, SDR 21 and 26, and D1785, Schedule 40 and 80). The first four
carry reference prices with their source and date (`pricesSource`, `pricesDate`), shown in the
*Manufacturer catalogues…* dialog and to the AI assistant: the 2024 agricultural price list of the
Sardinia region (EUR, supplied and laid) for the ISO and EN packs and the 2023-24 schedule of rates of
Maharashtra Jeevan Pradhikaran (INR, supply) for the IS packs, the published rows as printed and the
other sizes from a fit by the mass per metre. Through the *Manufacturer catalogues…* dialog you add a pack to
the project, import an `.oci.cat` file or load a pack or a whole index by URL, which lets any dealer
or community keep its own repository. The project catalogue is exported in the same format. The
complete format, with the fields of every group and the contribution rules, is in
[catalogs/README.md](../../catalogs/README.md); `dart run tool/gen_catalogs.dart` validates the packs
(unique ids, plausible curves) and rebuilds the index.
