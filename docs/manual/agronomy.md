# Agronomy and irrigation scheduling

Design → Agronomy holds the agronomic work of a project beyond the monthly requirement of
[Calculation and sizing](calculation.md#agronomy-mechanised-machines-and-field-calculators): the daily soil water
balance, the irrigation programme of the controller, the runoff potential of the sprinklers, fertigation by crop
stage, uniformity in the field and the crops the FAO-56 table does not have. The dialogs read what the project
already holds: the site climate (Design → Site climate…), the crop, soil, irrigation method and ground cover of every
irrigated area, the system flows and, where it counts, the design results. **Save** in each of them keeps its
settings in the project as one undo step that keeps the design results; the project file writes them under `agronomy`
only when they differ from those of a new project. Their tables are in the **Agronomy** tab at the end of the reports
panel and in every report export (PDF, Excel, CSV, TXT).

Every table of the app applies the same rule to localised irrigation: ETc,loc = Kr·Kc·ETo over the whole area, with
Kr from the ground cover of the area (or typed) and the wetted fraction only in the readily available water. Kc mid
and Kc end follow the minimum humidity and the wind of the site climate (FAO-56 equations 62 and 65), and Kc ini the
interval and depth of the irrigations in sprinkler and surface irrigation (FAO-56 Annex 7).

## Daily soil water balance

*Daily water balance…* follows the root zone of one irrigated area day by day, by FAO-56 chapter 8 with the single
crop coefficient of its crop: the crop uses Kr·Kc·ETo, the stress coefficient Ks cuts its water use once the
depletion passes the readily available water, rain below 0.2·ETo evaporates and the surplus percolates. The area
needs its water balance turned on in its Properties, with a crop (or ETo and Kc typed).

- **When to irrigate**: at the allowed depletion, every N days, or never (rain only). With *Regulated deficit by
  stage*, each of the four growth stages has its allowed depletion as a fraction of the total available water: up to
  the crop's factor p there is no stress, above it the crop is under a regulated deficit.
- **Refill** of the depletion (%), the depletion at the start, and the weather: the typical year of the normals (with
  the number of rain events a month) or a year of the daily series downloaded or read from a station file.
- **Results**: the period, the irrigations, the deep percolation, the days of stress and the relative yield by the
  seasonal Ky of FAO-33 (0 takes the crop's), with a chart of the depletion against the readily (RAW) and the total
  (TAW) available water.

## Irrigation programme

*Irrigation programme…* lays out the run of every system flow as a controller is set: the system flows run one after
another from the start of the **daily irrigation window** (start hour and length; 24 h is no window), and the message
`schedule_over_window` warns when the flows of a day do not fit it. With **cycle and soak**, the event of a sprinkler
zone whose soil does not take its application rate is split into cycles no longer than the run before runoff (with a
shortest cycle and a most cycles per event), and other flows run in the pauses. The **seasonal adjustment** gives
each month the share of the design month's run time, from the monthly requirement or typed. The result is the
programme by controller station and month and the runs of the day, both exported as CSV, and the window used on the
busiest day against the peak hours; *Put the programme by station and the runs in the reports* adds them to the
reports.

## Runoff potential

*Runoff potential…* sets the application of the sprinklers against the soil:

- **Centre pivots and linear moves**, span by span: the elliptical pattern of the sprinklers (the peak is 4/π of the
  mean rate, whatever the speed) against the NRCS intake family of the soil of the area under the machine and its
  surface storage (NEH 623 chapter 4, NEH 652), with the first irrigation after tillage; it gives the depth of each
  pass, its runoff, the largest depth per pass without runoff and the smallest timer setting.
- **Sprinkler areas**: the rate of the zones against the basic intake of the soil, with the run of an event and the
  longest run without runoff.

## Fertigation by stage

*Fertigation by stage…* splits the doses of N, P₂O₅ and K₂O of the crop cycle over the four stages of the Kc curve
(by the water use of each stage in the typical year, or by shares typed) and gives them in the irrigations of the
stage found by the daily water balance, every Nth of them: the product of each event (the phosphate and potash
products first, their nitrogen counted, the nitrogen product for the rest), the stock solution, its injection rate
over the share of the event that injects and the concentration while injecting. The rise of the electrical
conductivity of the water comes from the dissolved salts (EC ≈ TDS/640, FAO-29; urea left out) and is set against
what the crop takes without loss. The Fertigation analysis of the Mainline menu (travel times, injection plan,
venturi) stays as before.

## Uniformity in the field

*Uniformity in the field…* has three parts:

- **Depth of one event of the programme**: each sprinkler's rate times the hours its zone runs in one event, summed
  over the zones, which is what a catch can measures; it can be shown on the drawing in place of the rate of the
  densogram.
- **Virtual catch cans** laid over an area on a grid (spacings, rotation, mouth diameter, test duration), with the
  reading the design expects in each can, exported as CSV to lay out a field test.
- **Field evaluations**: the volumes read in the cans (row by row; `-` for a lost can) or the emitter flows measured,
  with CU, DU and the statistical uniformity set against the design's. The evaluations are kept in the project.

## User crops

*User crops…* adds crops the FAO-56 table does not have (passion fruit, papaya, açaí, cocoa, black pepper,
eucalyptus…) with the FAO-56 single crop coefficient curve: Kc initial, mid and end, the length of the four stages
(all 0 is an evergreen at Kc mid all year), the planting month, the root depth, the factor p, the height, the
salinity threshold, Ky and the source of the values. The irrigated areas pick them after the FAO-56 crops in their
crop list and get the monthly table, the programme and the water balance.

## Weather station files

Design → Site climate… → *Import a station file…* reads the CSV files of the automatic stations of INMET (Brazil's
National Institute of Meteorology: the hourly files of its historical data portal, one per station and year, or a zip
with several years) and the exports of BDMEP (daily or hourly rows). The hours, in UTC, are taken to the local day by
the longitude, the days with too few hours are left out, the wind at 10 m is brought to 2 m (FAO-56 equation 47) and
the daily ETo comes by Penman-Monteith; the file gives the monthly normals of the station and the daily series of the
water balance. The *Station normals* tab of the same dialog takes the monthly means of any station (temperatures,
humidity, wind, sunshine, rain; blank cells estimated as FAO-56 says) and works out their ETo by Penman-Monteith.

## Checks

The design check and the Messages tab also compare the system with the crops:

| Code | Meaning |
|---|---|
| `capacity_below_peak` | The system cannot apply the gross requirement of the month of largest demand within the irrigation window (24 h when none is set): the system flows run one after another, each as long as the area of its zones that needs the most hours |
| `pivot_capacity_below_peak` | A centre pivot or linear move whose depth per revolution in the hours of the window is below the peak gross requirement of the area under it |
| `pivot_runoff` | Runoff under a machine: at its end the peak rate of the sprinklers exceeds the infiltration of the soil beyond what the surface holds |
| `area_rate_exceeds_soil`, `area_eto_climate`, `area_planting_date`, `area_leaching_infeasible` | Sprinklers of an area applying more than the soil and its slope take in (with the cycle and soak that avoids it), an ETo typed on an area that differs from the site climate, a planting date that is ambiguous or not a date, water too saline for the crop |

## The gallery examples

The drip and micro-sprinkler areas of the example gallery take the ground cover of their crop instead of a full
cover, from FAO-56 equation 76 with the mean Kcb and the height of the crop and Kr = 0.1·√Pd (Keller and Bliesner):
grapes 0.25 (Kr 0.50), tomatoes 0.88 (0.94), peppers 0.75 (0.87), coffee 0.6 (0.77), the vegetables of the gravity
example 0.73 (0.85) and bananas 0.68 (0.82). Their depths and run times are smaller than in earlier versions; the
garden (watered by the plant factor of its hydrozones) and the sugarcane (full cover) stay at 1.
