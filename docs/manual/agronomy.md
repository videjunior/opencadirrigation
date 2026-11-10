# Agronomy and irrigation scheduling

Design → Agronomy holds the agronomic work of a project beyond the monthly requirement of
[Calculation and sizing](calculation.md#agronomy-mechanised-machines-and-field-calculators): the daily soil water
balance, the irrigation programme of the controller and the programme played on the plan, the irrigation forecast of
the coming days, the climate risk over the years, the runoff potential of the sprinklers, fertigation by crop stage,
uniformity in the field and the crops the FAO-56 table does not have. The dialogs read what the project already
holds: the site climate (Design → Site climate…), the crop, soil, irrigation method and ground cover of every
irrigated area, the system flows and, where it counts, the design results. **Save** in each of them keeps its
settings in the project as one undo step that keeps the design results; the project file writes them under `agronomy`
only when they differ from those of a new project. Their tables are in the **Agronomy** tab at the end of the reports
panel and in every report export (PDF, Excel, CSV, TXT). The irrigation forecast and the player never change the
project; the climate risk keeps its summary in it. On a phone every item is in ☰ → Design, with the same label.

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

## Playing the irrigation programme on the plan

*Play the programme on the plan…* (or **Play** in the Irrigation programme dialog) shows the programme working on
the drawing. It needs a designed project (F5) and a programme with runs; otherwise a message says what is missing. A
panel at the bottom holds *Back to the start of the cycle*, play and pause, *Go to the next start of a group*, the
speed (from 0.25 to 24 hours of programme a second), the clock and what runs, a slider over the cycle with the runs
drawn as blocks, and the exports. The drawing stays usable under it (pan, zoom, hotkeys); the panel steps aside, and
pauses, while a dialog is open or another tab is shown, and follows a new design at the same moment.

At every moment the drawing shows the areas of the running groups (system flows) tinted, their sprinklers' throw and
their emitters drawn wet, the pipes that carry water coloured by their velocity (blue slow, green at half the allowed
velocity, orange at it, red at one and a half times it) and drawn wider with more flow, the pumps on (a green ring with
turning spokes) or off (a grey ring with two bars), and a panel with the clock, the groups running, the total flow,
the pressure at the outlet of the running pumps (or at the supply when no pump runs), the pumps on and the level of
each reservoir. Between runs the system is at rest, the drawing dimmed.

- **Frame (PNG)**: the moment shown, 1600 pixels on its long side, with a band on top holding the clock and the
  numbers.
- **Animation (GIF)…**: the whole cycle, 480 pixels on its long side by default (320 to 800), a frame every half hour of a
  one-day cycle (48 frames) or every two hours of a longer one, plus one in every run too short for a step; with the
  base map when chosen (its tiles are downloaded like the assistant's pictures, from the map on screen); progress and
  Cancel. The palette has up to 256 colours a frame (octree quantizer, no dithering) and the animation loops.
- **Calendar (.ics)…**: the programme for the grower's phone calendar (RFC 5545): one event per start of every group
  (or of every cycle of cycle and soak), at the local clock time wherever the phone is (floating time), lasting its
  run time, repeating every cycle of the programme from today for the days chosen (30 by default), with the zones and
  the run time in the description; the run times are those of the design month of each area, or of a month chosen.

**Method.** The cycle is the programme's own period: every system flow runs every few days, on staggered days, so the
programme repeats after the least common multiple of the intervals, one day when every flow runs daily (at most 28
days are shown; a longer period is cut, and the panel says so). The cycle is circular: a run past midnight of its last
day carries on at the start. The state of a moment is the design result of the group running then (its flows,
velocities, pressures and pumps from the steady solution of that system flow), held for the whole run. Two groups
that overlap in time (a programme that does not fit its window) have their flows added on shared pipes and the
higher supply pressure shown, with a note: the design did not solve them together. A reservoir behind a supply follows
the continuity of its volume, dV/dt = inflow − outflow, with the flow each running group draws and the stage–volume
curve of the reservoir study, from the level set for the start of the day; it stops at the lowest operating level
(the intake runs dry) and at the full level (it spills), and the panel says so.

**Limits.** The player shows the steady state of each group, not the filling of the pipes nor the surges at the valve
changes (see the transients). The calendar does not apply the seasonal adjustment month by month: export it again for
another month. The exports are drawn on the dark canvas, framed on the groups, whatever the theme of the app. The
assistant looks at any moment of the programme with `programme_picture` and exports the animation and the calendar
with `export_programme_animation` and `export_programme_calendar`.

## Irrigation forecast

*Irrigation forecast…* keeps the project useful after the drawing is delivered: it takes the weather forecast of the
site and tells, for each irrigated area and each of the coming days, whether to irrigate, the net and gross depth,
the run time at the design's application rate and the **water budget** (%) to type into the controller. It needs a
georeferenced project with irrigated areas (crop, soil and method, as for the requirement table); run the design (F5)
first for the real application rates, else the nominal flow of the emitters is used and the dialog says so. The
project is never changed.

1. Choose the source: *MET Norway* (the default; open data free for any use, professional work included, with the
   credit) or *Open-Meteo* (its free API is for non-commercial use only, and the dialog says so).
2. Say how the soil stands: *Full today* (just irrigated, or after a good rain: the default), or *Last irrigation or
   rain some days ago*, with how many days ago and, if you know it, the depth that went into the soil.
3. Press **Get the forecast**. Nothing is fetched before that. The answer is kept on this device for as long as the
   service says it is valid (at least three hours for MET Norway, one for Open-Meteo), and **Fetch again** waits until
   the service allows another request (MET Norway asks not to repeat a request before its expiry time).
4. Read the grid: the days as columns, the ETo and the rain of each day on top, then each area with its programmed run
   time per event, the water budget of these days and, for each day, the run time in minutes or "skip". The table day
   by day gives the stage, Kc, ETc, effective rain, depletion, net and gross depth and the share of one programmed
   event. Both tables export as CSV, XLSX or PDF; the source, its credit and the time of the fetch are shown with them.

The assistant answers "how much should I irrigate today?" with the same plan (operation `irrigation_forecast`).

**Method.** MET Norway gives hourly values for the first two or three days and six-hourly ones after (about nine and
a half days in all); they are turned into local solar days (UTC + longitude/15): the extreme temperatures, the mean dew
point, the mean wind at 10 m brought to 2 m (FAO-56 eq. 47) and the rain of each period counted once. The ETo is the
FAO-56 Penman-Monteith of those daily values, with the solar radiation from the temperature range (FAO-56 eq. 50, kRs
0.16), the procedure FAO-56 gives for missing radiation, since MET Norway publishes none. Open-Meteo gives 16 days of
daily values with its own FAO-56 ETo, used as given. The crop is that of the area's requirement table and daily
water balance (its Kc curve on each date from the planting date read for the hemisphere of the site, ETc,loc =
Kr·Kc·ETo, TAW = AWC·Zr·Pw, RAW = p·TAW with p adjusted to the ETc of the day, Ks once the depletion passes RAW,
FAO-56 eq. 84); rain below 0.2·ETo only wets the surface and rain above field capacity percolates. An area is
irrigated on the day its depletion reaches the net depth of one event of the design programme, or the allowed
depletion of the stage if that is less; the irrigation refills the depletion (the refill share of its balance), the
gross depth is the net over the efficiency (with the leaching of the month) and the run time the gross depth over the
application rate. The water budget is the water the crop uses in the forecast days less the rain the root zone keeps,
over what the design programme applies in as many days of its design month (0 to 300 %).

**Assumptions and limits.** A forecast is uncertain, more so after the first three days: check it before irrigating
and fetch again the next day. The soil is taken as you said (no rain since the last irrigation; the days in between
use the site climate's ETo of the month, or the first forecast day's when the project has no climate), and no rain
falls after the last day of the forecast. When few hours of today are left in the forecast, today's ETo is tomorrow's
(the day is marked). Areas with a fixed daily depth do not change with the weather. Days are local solar days, which
can differ by an hour or two from the clock of the site. The radiation from the temperature range misses cloudy days
with a wide range of temperature.

## Climate risk over the years

*Climate risk over the years…* (under *Daily water balance…*) shows how the system as designed would have done in
each of the last thirty to forty real years, beside the one figure it was sized for (the ETo of the peak month of the
normals, or a typed peak ETo). It needs a georeferenced project and irrigated areas with their crop, soil and water
balance on; a design (F5) is not needed, but with one the capacity uses the emitter flows of the design instead of
the nominal ones.

1. Choose the daily series: *NASA POWER*, the daily point series of the site from 1984 to the last complete year
   (temperature, humidity, wind at 2 m, solar radiation, rain), downloaded only when you press **Analyse** (about 2 MB
   in 9 parts, with a progress bar and Cancel) and kept on this device (File → Saved downloaded data), so the next run
   reads it at once, offline too; or *The site climate's series*, the daily series kept with Design → Site climate (a
   station file or an earlier download), with nothing downloaded. The credit of the series (NASA's acknowledgement for
   NASA POWER) is shown with the results and kept with the summary.
2. Choose the **Non-exceedance probability** of the design values (50, 80, 90 or 95 %; 80 % is not exceeded in four
   years out of five) and the **Peak period** (7, 10, 15 or 30 days; 30 compares with the monthly normals, 7 to 15
   with the storage of the soil).
3. Press **Analyse**. The summary is kept in the project as one undo step (not the series) and appears in the
   *Irrigation management* tab of the reports and in every export (the tables *Climate risk: spread of the years* and
   *Climate risk: year by year*); run it again after changing the design, since the kept summary does not follow it.

For the project and for each area (**Show**): the P50, P80, P90, P95 and maximum of the yearly gross irrigation
requirement, of the gross demand of the peak period and of the peak-period ETo, beside the figure the design uses and
the system's capacity, with the years the design figure was exceeded; the reliability (the seasons in which the
system as designed kept the soil above the allowed depletion every day, and the days a year it did not); the worst
years, the longest dry spells, the yearly volume pumped; the trend of the period (Sen's slope with the Mann-Kendall
test at 5 %); a chart of every year (the years with deficit days marked) and the exceedance curve. The assistant runs
the same analysis with `climate_risk`.

**Method.** The ETo of each day is the FAO Penman-Monteith (FAO-56 eq. 6), with missing humidity, radiation or wind
estimated as its chapter 3 says. Every area runs the daily soil water balance of *Daily water balance…* (its crop,
Kc curve, planting date, root depth, p, soil, Kr and wetted fraction, efficiency and leaching, and the trigger saved
for it; a rainfed setting is evaluated irrigating at the allowed depletion), season by season and twice: without a
limit, which gives the requirement, and limited to the gross depth the system can apply in a day, which gives what it
would have applied and the deficit days (crop days that end with the depletion above the allowed depletion: the RAW,
or the regulated deficit of the stage). The capacity under a centre pivot or linear move is its depth per cycle over
the hours of a cycle times the programme's window; elsewhere it is the application rate of the emitters over the area
times the hours its system flow may run, the window shared among the flows in proportion to the hours each needs on
the design's peak day; an irrigation every n days may apply n days of capacity. The peak-period demand is the largest
mean, over the days chosen, of ETc,loc less the rain the root zone kept, over the gross/net factor of the month.
Seasonal crops count from their planting day (a season may run into the next year, "2019/20"); crops in the field all
year, and the site's own figures, by irrigation year, from the first day of the month whose mean rain most exceeds
its mean ETo. The probabilities are empirical (Weibull plotting positions i/(n+1), linear between ranks, kept within
the years observed: no distribution fitted, nothing extrapolated); the trend is Sen's slope and the Mann-Kendall test
with the variance corrected for ties, from 10 years, without removing serial correlation; a dry spell is the most
consecutive days with less than 1 mm of rain (the ETCCDI index CDD). A missing day takes the series' own mean ETo of
its month and no rain, and a season or year with more than 10 % of its days missing is left out.

**Limits.** Reanalysis data (NASA POWER: MERRA-2 over cells of about 50 km) smooth the local extremes: a station on the
site may show higher peaks of ETo and longer dry spells. The figures are a reference, not a guarantee. Only the first
crop cycle of an area is evaluated; paddy-rice percolation is not added; runoff and capillary rise are taken as zero,
as in the daily balance. The capacity is a daily limit shared in proportion to the design's peak hours, not a schedule
of the controller station by station; with partial refills the soil keeps room for rain, so the volume pumped can be
below the requirement of full refills even without deficit days.

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
