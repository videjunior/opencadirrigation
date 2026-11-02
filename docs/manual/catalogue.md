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

The **default catalogue** ships 17 pipes (PE 16–50 mm, PVC DN 35–250, HDPE 110 and 160, 6" steel),
10 emitter families (PC and turbulent drippers, micro-sprinklers, PC bubbler, impact sprinkler, gun,
garden rotor and spray, demand point), 6 tapes and driplines, 36 valves and devices (1" to 6",
master valves, pressure-sustaining valves and hydrants with flow limiter among them), 18 pumps
(centrifugal 1 to 100 hp, submersible 3 to 30 hp) and about 330 fittings generated for every
nominal diameter (couplers, 90° and 45° elbows, tees, crosses, end caps, adapters and reducers, plus
lateral take-offs, tape ends and risers) and 12 copper wires (1 to 10 mm² enabled, AWG 18 to 8
disabled: enable them where AWG is the norm), with translated names and illustrative prices.

The editor (Design → Component catalog…) edits, duplicates and removes items, imports and exports
JSON, CSV per group and **Excel** (export, fill in prices in the spreadsheet and import it back), sets
the default catalogue for new projects and restores the original.

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
manufacturer, plus an `index.json`. Through the *Manufacturer catalogues…* dialog you add a pack to
the project, import an `.oci.cat` file or load a pack or a whole index by URL, which lets any dealer
or community keep its own repository. The project catalogue is exported in the same format. The
complete format, with the fields of every group and the contribution rules, is in
[catalogs/README.md](../../catalogs/README.md); `dart run tool/gen_catalogs.dart` validates the packs
(unique ids, plausible curves) and rebuilds the index.
