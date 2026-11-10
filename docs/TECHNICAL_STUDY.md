# Technical study: irrigation CADs, network hydraulics and the decisions behind OpenCADIrrigation

> Canonical version, maintained in English. Portuguese translation: [PESQUISA.pt-BR.md](PESQUISA.pt-BR.md).

Study started on 15 September 2026 and extended on 16 September and 25 October 2026. This document gathers the
research that guides the architecture of OpenCADIrrigation (an irrigation CAD for the browser): what commercial CADs do,
the hydraulics and agronomy the engine implements, with the equations and numerical examples, the sizing formulations,
the transient and operation analyses, the layout automation, the terrain and performance algorithms, the file formats
studied and the sources. Wherever a formula appears, the module that implements it is named, and so is the test that
validates it.

This document does not cite competing software companies or products, nor CAD products; the sources are standards, technical literature,
open software (the reference engines and the libraries that validate the formats) and the API documentation of the
model providers the AI assistant calls.

## Contents

1. [Scope and method](#1-scope-and-method)
2. [What a designer expects from an irrigation CAD](#2-what-a-designer-expects-from-an-irrigation-cad)
3. [Why an open irrigation CAD in the browser](#3-why-an-open-irrigation-cad-in-the-browser)
4. [Engine units and conventions](#4-engine-units-and-conventions)
5. [Friction head loss](#5-friction-head-loss)
6. [Minor losses](#6-minor-losses)
7. [Multiple outlets: the F factor](#7-multiple-outlets-the-f-factor)
8. [Emitters and sprinklers](#8-emitters-and-sprinklers)
9. [Uniformity](#9-uniformity)
10. [Laterals and submains](#10-laterals-and-submains)
11. [Networks: the Global Gradient Algorithm](#11-networks-the-global-gradient-algorithm)
12. [Pumps and energy](#12-pumps-and-energy)
13. [Water hammer and pressure ratings](#13-water-hammer-and-pressure-ratings)
14. [Hydraulic transients](#14-hydraulic-transients)
15. [Pipe sizing](#15-pipe-sizing)
16. [Mainline, system flows and supplies](#16-mainline-system-flows-and-supplies)
17. [Operation analyses](#17-operation-analyses)
18. [Flushing, fittings, wiring and bill of materials](#18-flushing-fittings-wiring-and-bill-of-materials)
19. [Automatic layout](#19-automatic-layout)
20. [Vegetation in aerial imagery](#20-vegetation-in-aerial-imagery)
21. [Agronomy](#21-agronomy)
22. [Centre pivots and other machines](#22-centre-pivots-and-other-machines)
23. [Terrain and geoprocessing](#23-terrain-and-geoprocessing)
24. [File formats](#24-file-formats)
25. [Performance and software architecture](#25-performance-and-software-architecture)
26. [Design assistant](#26-design-assistant)
27. [AI assistant](#27-ai-assistant)
28. [Validation](#28-validation)
29. [Gaps and future work](#29-gaps-and-future-work)
30. [Glossary](#30-glossary)
31. [Sources](#31-sources)

---

## 1. Scope and method

Questions the study set out to answer:

1. What does a designer expect from an irrigation CAD, in the order they work? Answered in
   section 2, from professional practice and the design manuals (NRCS National Engineering
   Handbook, chapters 7 and 11; Keller & Bliesner; FAO irrigation manuals).
2. Why an open, browser-based irrigation CAD, and which principles does that impose? Section 3.
3. Which equations are consensus in the literature and the engineering manuals (NRCS, FAO,
   Keller & Bliesner, EPANET) and how to test them? Sections 4 to 14, with recomputed numerical
   examples.
4. How to size pipes in a reproducible, explainable way, and how to analyse the operation of the
   system once it is sized (a day of operation, tariffs, on-demand networks, energy, reliability,
   calibration, fertigation)? Sections 15 to 18.
5. Which automation helps the layout, and which agronomy and machine methods does the design need?
   Sections 19 to 22.
6. Which terrain, geoprocessing, format and performance algorithms does a web CAD need, and how to
   implement them without native libraries? Sections 23 to 25; the design and AI assistants in
   sections 26 and 27.

Primary sources: the EPANET 2.2 manual, chapters 2, 4, 7 (microirrigation) and 11 (sprinkler) of
the NRCS National Engineering Handbook part 623, FAO-56, FAO Irrigation and Drainage Papers 29, 45,
46 and 59, the FAO irrigation manuals, Keller & Bliesner (1990), Wylie & Streeter (1993) and
Chaudhry (2014) for transients, AWWA Manual M51 for air valves, peer-reviewed papers on friction
factors, emitters, uniformity, network operation and image analysis, the open specification of the
DWG format, the PDF, OpenType, LAS, LandXML and IFC specifications and the documentation of the public
elevation and climate services.

This study does not name competing software products or their makers, nor CAD products. Irrigation
component manufacturers appear only as the origin of catalogue data, file formats only by the name of
the format (DXF, DWG R2000), and the data, map and AI providers as sources.

---

## 2. What a designer expects from an irrigation CAD

### 2.1 Design process

The practice consolidated in the design manuals (NRCS NEH 623, chapters 7 and 11; Keller &
Bliesner, 1990) organises the work in stages, and that is the order the Project menu and the
tutorial follow:

1. Project details: client, site, designer, units.
2. Background information: boundaries, buildings, roads and, above all, the **elevations** (contour
   lines, spot heights and breaklines), because topography governs the pressures.
3. Layout: water supplies, emitters, control valves, pumps, devices and pipes.
4. **Zone design**: size or analyse from the zone valve to the emitters, within the pressure window
   that guarantees uniformity.
5. **Management**: which valves operate together (system flows), for how long, and what that
   demands from the supply.
6. **Mainline design**: size or analyse from the supply to the valves, flow by flow.
7. Materials: automatically selected fittings and a costed bill of materials.
8. Plans and reports: sheet with title block, legend, scale and the result tables.

### 2.2 Object model

The OpenCADIrrigation model (`entities.dart`) separates four families of items:

- **Zone items**, downstream of a control valve: zone pipe, lateral with equally spaced emitters
  (sprayline), tape or dripline with integral emitters, single emitter, device (regulator, gate
  valve, filter), junction and irrigated area with its water requirement. Generators create lateral
  blocks with submain and valve, sprinkler grids, tree rings and automatic layouts (section 19).
- **Mainline items**: water supply, mainline pipe, pump, junction, device (filters, meters, the
  master valve, pressure-reducing and pressure-sustaining valves, hydrants with flow limiters, air
  valves), control valve, centre pivot or linear move (a demand with its own required pressure) and
  **valve-in-head sprinklers**: emitters drawn on the mainline, each with its valve in the head,
  grouped into controller stations (section 16.2).
- **Electrical items**: controller (stations, output voltage, accessories, cost) and wire route (the
  path of the station and common conductors from a controller through the valves).
- **Drawing items**: point, line, polyline, rectangle, circle, arc, spline, hatch, dimensions
  (linear, angular, radial or diameter, ordinate and leader), symbols, text, image, contour line,
  spot height, **breakline** (a ridge, channel or terrace edge the terrain model must not cut
  across), comment and revision cloud; user blocks (a named set of entities with a base point) are
  kept in the project and inserted as copies.

Structural rules adopted: a control valve always separates zone from mainline; zone items do not
connect to mainline items without a valve between them; coincident vertices (within the connection
tolerance) form a node; a point item on a pipe splits the pipe; there is no limit to the number of
connections at a junction, because the network solver accepts any degree. Wire routes form a graph
of their own and never touch the hydraulic network.

### 2.3 Component database

Seven groups (pipes, emitters with nozzles, tapes, valves and devices, pumps, fittings, wires), all
in SI, with the fields the hydraulics and the wiring require:

- **Pipe**: nominal diameter, real inner diameter (the one used in the calculation), Hazen-Williams
  C, roughness, material (which gives the Scobey Ks, the Manning n and the temperature derating of
  the pressure class), pressure rating, usage (lateral, zone, mainline), cost per metre.
- **Tape**: manufacturing CV, inner diameter, default, minimum and maximum inlet pressure,
  tolerances above and below, barb loss coefficient, emitter constant and exponent, spacing,
  rating.
- **Emitter and nozzle**: q = k·H^x, wetted radius R = a·H^b (both fitted from data-sheet rows,
  section 8), arc, minimum and maximum pressure, CV, flow tolerance (±5 % is the usual value), an
  optional measured radial profile (catch-can test, section 9.1), kind (sprinkler,
  micro-sprinkler, dripper, bubbler, gun, demand point).
- **Valve and device**: loss h = K·Q^n + C, minimum and maximum flow, kind (control, master, PRV,
  PSV, flow control or hydrant with flow limiter, isolation, check, backflow, filter, meter, air
  release), setting of a regulating valve.
- **Pump**: (Q, H) points fitted to a parabola, efficiency (a single value or a curve), NPSH
  required curve, rated power, the mains frequency the curve was measured at, submersible or
  surface installation.
- **Fitting**: kind, diameters, cost.
- **Wire**: conductor section (mm², AWG sizes converted), resistance per kilometre (copper
  ≈ 18.1 Ω·mm²/km when not given), cost per metre.

Manufacturer catalogues are open JSON files (`catalogs/`), with typical public catalogue data and
prices to be filled in locally; an item may carry the code under which it is credentialed for
financing by the Brazilian development bank (BNDES FINAME), which the bill of materials and the
quote show.

### 2.4 Methods the engine must cover

Of what design practice requires, the engine implements:

- Friction loss by **Hazen-Williams** with C per pipe and a global adjustment (scale or offset) for
  ageing, by **Darcy-Weisbach** (laminar, transition and turbulent) with viscosity from
  temperature, and by **Scobey** and **Manning**.
- **Minor losses** as a percentage of the length, from the bends and tees the drawing implies, by
  the own curve of every device, and the per-emitter barb loss in tapes.
- **Pressure window** of the emitters derived from the flow tolerance (±5 % → about ±10 % of
  pressure for exponent 0.5) and from the minimum and maximum pressures in the catalogue; tapes
  with asymmetric tolerances (for instance +20 % and −30 % of the inlet pressure).
- **Analysis** with nominal flows (fast) and **detailed analysis** with pressure-dependent
  emitters, by a complete network solver with pumps (fixed or variable speed), PRVs, PSVs, flow
  control valves and check valves.
- **Sizing by linear programming** (topography, pressure window, velocity, pressure class at the
  water temperature, economics, enabled and fixed diameters, number of diameters per lateral and
  per submain) and by **maximum velocity**, with rationalisation of diameters from upstream to
  downstream.
- **Valve pressure** chosen so that the mean emitter pressure equals the nominal one, or, for
  regulated tapes, to guarantee the minimum submain pressure.
- **Water supply** with calculated pressure (well with a negative water level, reservoir with a
  positive height) or fixed (mains, with design and maximum flow and pressure).
- **Management** by system flows, with the duty of every supply per flow and operating times from
  the water requirements of the areas; automatic grouping of the zones, pivots and valve-in-head
  stations into flows, by flow or for the least energy.
- **Transients** by the method of characteristics (valve closures, pump trips, column separation,
  air valves, surge vessels), a **day of operation** as an extended-period simulation, tariff-aware
  scheduling, on-demand flows, criticality, calibration and fertigation.
- **Valve wiring**: station and common conductor sizes by solenoid voltage drop, two-wire decoder
  systems, automatic routes along the trenches, controller stations and simultaneous valves.
- **Densogram**: the water applied by the sprinklers as drawn, with its uniformity per area.
- **Elevation** at every node of the graph from the terrain model.

### 2.5 Reports and graphical tools

Zone summary (flow, allowable and actual pressures, allowable and actual variation, pressure
downstream of the valve, valve loss), uniformity (CU, low-quarter DU, Keller-Karmeli EU), pipe and
emitter tables (elevations, pressures, flows, velocities, diameters), mainline and supply duties,
valve-in-head stations, pumps and devices, water requirements by crop, month and stage, agronomy,
controller programme, flushing, water hammer and transients, pivots, spans and sprinkler packages,
bill of materials (also by zone and of a selection) with annualised costs and a quote; hydraulic
grade line, profile and pump curve charts, overlays of velocity, pressure, diameters,
minimum/maximum pressure and slope/aspect, submain position envelope, densogram (the water applied
by the sprinklers as drawn) and 3D view of the terrain; valve wiring (stations, wire sizes, solenoid
voltages, decoders).

### 2.6 Formats

Import of DXF, DWG, DGN V7, PDF plans, KML/KMZ, SHP (zips of several shapefiles too), GeoJSON, GPX,
LandXML, LAS point clouds, EPANET INP, CSV/XYZ/PNEZD, GeoTIFF and georeferenced images; export of
DXF (R2000 and R12), DWG (R2000), PDF (sheets, sets of sheets, details and charts),
PNG, SVG, KML/KMZ, GeoJSON, shapefiles, GPX, LandXML, IFC 4, EPANET INP and reports in CSV, TXT,
XLSX and PDF; project in open JSON with the catalogue embedded.

---

## 3. Why an open irrigation CAD in the browser

General observations about the landscape, without reference to products:

- Professional irrigation design tools are, as a rule, desktop applications for a single operating
  system or plug-ins of paid CAD platforms, with commercial licences, closed component databases
  and proprietary project formats.
- On the web there are mostly manufacturer calculators (lateral, submain, pump) and closed
  subscription services aimed at landscaping.
- The established open reference engine for networks is EPANET (public domain, US EPA), aimed at
  water distribution networks and without the irrigation objects (laterals, tapes, zone valves,
  system flows).
- Whoever designs in the field, on a tablet or on machines without installation privileges is
  poorly served.

Principles that follow from this and that OpenCADIrrigation adopts:

1. Run in the browser with no installation and no server, with the data on the user's computer.
2. Project and catalogue formats in open, documented JSON.
3. A transparent hydraulic engine, with the equations documented and tested against public
   references, and with the EPANET solver as the basis for networks.
4. An interface in the 20 most spoken languages, designed for touch as well.

---

## 4. Engine units and conventions

Internally everything is SI: length in m, flow in m³/s, head in metres of water column, pressure in
Pa, diameter in m, velocity in m/s (`units.dart`). The interface converts to metric (L/h, m³/h,
m w.c. or kPa, mm) or US (gpm, psi, inches, feet). Constants: 1 m w.c. = 9.80665 kPa = 1.42197 psi;
1 bar = 10.197 m w.c.; 1 L/h = 2.7778 × 10⁻⁷ m³/s; 1 m³/h = 2.7778 × 10⁻⁴ m³/s.

Kinematic viscosity of water (m²/s) as a function of temperature, by a table fit between 0 and
50 °C (error < 1 %): 1.004 × 10⁻⁶ at 20 °C; 1.13 × 10⁻⁶ at 15.6 °C (60 °F, the usual value in North
American manuals). The vapour pressure of water comes from Tetens' formula,
p_v = 0.61078·exp(17.27·T/(T + 237.3)) kPa, 0.24 m of water at 20 °C; the atmospheric head from the
standard atmosphere at the site elevation, 10.33 m at sea level.

Catalogues store the emitter k in m³/s per m^x. Conversion of a nominal flow q_n (L/h) at H_n (m):
k = (q_n / 3.6 × 10⁶) / H_n^x. Example: 1.6 L/h at 10 m with x = 0.5 → k = 1.4055 × 10⁻⁷.

---

## 5. Friction head loss

Module `friction.dart`; tests in `hydraulics_test.dart` and `valves_formulas_test.dart`.

### 5.1 Hazen-Williams

h_f = 10.67 · L · Q^1.852 / (C^1.852 · D^4.871), with Q in m³/s, D in m. Valid for water at room
temperature and turbulent flow; C ≈ 140 to 150 for PVC and PE (practice adopts slightly lower
values in small diameters, around 135 to 140, and up to 150 in large ones). Studies on PE show
that C is only constant for V > 0.7 m/s and 20 to 30 °C; outside that range the error reaches 19 %,
which justifies offering Darcy-Weisbach.

Derived forms used in the code: resistance r such that h_f = r·Q^1.852; unit gradient J = h_f/L;
equivalent diameter of n identical laterals in parallel (a design rule of thumb):
D_eq = (d^4.871 · n^1.852)^0.2053.

**Example.** L = 100 m, Q = 5 m³/h (1.389 × 10⁻³ m³/s), C = 150:
D = 50.0 mm → V = 0.707 m/s, h_f = 1.106 m (J = 1.11 m/100 m);
D = 46.8 mm (real PVC DN 50) → V = 0.807 m/s, h_f = 1.526 m.

### 5.2 Darcy-Weisbach

h_f = f · (L/D) · V²/(2g), Re = V·D/ν.

- Laminar (Re < 2000): f = 64/Re.
- Transition (2000 to 4000): the cubic interpolation of EPANET (Dunlop's polynomial), matching the
  laminar value 0.032 at Re = 2000 and the Swamee-Jain value and slope at Re = 4000, both evaluated
  at Re = 4000 as in the EPANET source; the function is continuous and its slope matches at the
  turbulent end (tests "transitional regime is continuous" and "transitional cubic matches the
  turbulent slope at Re = 4000 (EPANET)"). As in EPANET, the curve dips slightly below 0.032 around
  Re 2500 before rising.
- Turbulent: **Swamee-Jain** f = 0.25 / [log₁₀(ε/(3.7D) + 5.74/Re^0.9)]², explicit, with an error
  below 1 % against Colebrook-White 1/√f = −2·log₁₀(ε/(3.7D) + 2.51/(Re·√f)), which the code also
  solves iteratively as a reference.
- Blasius f = 0.3164·Re^−0.25 for smooth pipes with Re < 10⁵ (PE laterals and tapes).

Roughness ε: PVC and PE 0.0015 to 0.007 mm; steel 0.045 mm; cast iron 0.26 mm.

**Example** (the same 50 mm pipe, ε = 0.0015 mm, ν = 1.004 × 10⁻⁶): Re = 35 227, f = 0.0226,
h_f = 1.153 m, against 1.106 m by Hazen-Williams with C = 150 (a 4 % difference, consistent with
the test "Darcy-Weisbach agrees with Hazen-Williams for smooth PVC").

### 5.3 Scobey

The formula of Scobey (1930), the traditional one for sprinkler laterals of steel and aluminium
with couplers, is implemented in the SI form of Keller & Bliesner h_f = 4.1 × 10⁻³ · K_s · L · Q^1.9 / D^4.9
(Q in m³/s, D in m), the same as h_f = 2.59 × 10⁻³ · K_s · L · V^1.9 / D^1.1 with V in m/s, as resistance
r = 4.1 × 10⁻³ · K_s · L / D^4.9 so that h_f = r·Q^1.9. (Until this revision the engine put the 4.1 of
the flow form into the velocity form, which overstated the loss by 58 %.) With K_s = 0.40 the loss is
that of Hazen-Williams C 120–130, the usual equivalence for aluminium with couplers. The
coefficient comes from the material of the catalogue pipe (Keller & Bliesner 1990): K_s = 0.32 for
plastic, 0.40 for aluminium with couplers (and concrete), 0.42 for galvanised steel with couplers
and ductile iron.

### 5.4 Manning

For a full circular pipe, h_f = 10.29 · n² · L · Q² / D^(16/3) (SI; Chow 1959), resistance
r = 10.29·n²·L/D^(16/3). Manning n by material: 0.009 for PVC and PE, 0.011 for aluminium, 0.012
for steel, 0.013 for ductile iron and concrete. **Example**: the 50 mm pipe of section 5.1 with
n = 0.009 gives h_f = 1.40 m, a little above the 1.11 m of Hazen-Williams: Manning, a law of
rough channels, is conservative for small smooth pipes. The EPANET export writes Manning as its
Chezy-Manning formula (C-M) and Scobey, which EPANET does not have, as Darcy-Weisbach with a
warning.

All four laws are available everywhere a loss is computed: the zone and mainline analyses, the
sizing, the pivot span pipe and the network solver, which uses each pipe's own coefficient (test
"the solver uses them: one pipe between two reservoirs carries the flow of the law").

### 5.5 Flow exponent

Christiansen's F factor and the LP linearisation depend on the exponent m of the loss law
(`flowExponent`): 1.852 in Hazen-Williams, 1.85 in Darcy-Weisbach (between Blasius' 1.75 and the
fully rough 2.0), 1.9 in Scobey and 2.0 in Manning. Inside the network solver the gradient of a pipe
uses n = 1.852 (Hazen-Williams), 1.9 (Scobey) and 2.0 (Darcy-Weisbach and Manning).

---

## 6. Minor losses

Module `minor_losses.dart`. Two equivalent forms:

- h_m = K·V²/(2g), with K from Crane TP-410 and the irrigation literature: 90° elbow 0.4 to 0.8,
  long radius 0.2 to 0.4, tee run 0.2 to 0.6, tee branch 1.0 to 1.8, gate valve 0.15, globe 6 to
  10, reducer 0.1 to 0.5, entrance 0.5, exit 1.0.
- Flow form h_m = m·Q² (EPANET style), with m = K / (2g·A²), used inside the solver.
- Equivalent length L_e = K·D/f, the usual method of irrigation CADs to add the losses to every
  segment.

OpenCADIrrigation offers two methods (`MinorLossMethod`), both off when minor losses are switched
off in the design parameters:

- **Percentage of the length** (the default, 5 %): the zone and mainline pipes are analysed with an
  equivalent length L·(1 + p); laterals and tapes keep their barb losses only.
- **Fittings of the drawing** (`NetworkBuilder._assignFittingLosses`, method of the fitting
  coefficients of Crane TP-410): the K of the bends and tees the drawing implies is added to the
  zone and mainline pipe links next to them, and no percentage is applied. A vertex where two pipes
  meet and the direction turns by 67.5° or more is a 90° elbow (K = 0.75); from 22.5° a 45° elbow
  (K = 0.35); the K goes to the pipe leaving the vertex. At a node of three or more pipes the
  straightest pair is the run (K = 0.4, half on each of its two pipes) and every other pipe is a
  branch (K = 1.5). Tests in `minor_fittings_test.dart`.

Devices and valves follow their own curve h = K·Q^n + C (Q in m³/s), fitted by log-log regression
from catalogue points or built from a dimensionless K and the diameter.

In drip laterals, the loss at the emitter connections (barbs) reaches 30 to 50 % of the total; the
per-emitter Kd factor of the catalogue tapes models that loss.

---

## 7. Multiple outlets: the F factor

Christiansen (1942): the loss of a lateral with N equal outlets is h_lateral = F · h_f(Q_inlet),
with

F = 1/(m+1) + 1/(2N) + √(m−1)/(6N²).

First outlet at half a spacing (Jensen-Fratini): F = (2N/(2N−1)) · [1/(m+1) + √(m−1)/(6N²)].
**Scaloppi (1988)** for a first outlet at an arbitrary distance r·S:
F_a = (N·F + r − 1)/(N + r − 1), which reduces to F when r = 1 (test "Scaloppi adjustment reduces
to F when r=1").

**Example.** N = 20, m = 1.852: F = 0.3760; with the first outlet at half a spacing, 0.3600;
N = 100: 0.3556, tending to 1/(m+1) = 0.3506.

The engine uses F for quick estimates (lateral calculator, comparison with the solver in the test
"friction loss agrees with Christiansen estimate"); the design calculation uses the step-by-step
analysis and the network solver, which do not need the equal-flow assumption.

---

## 8. Emitters and sprinklers

Module `emitter.dart`.

- Emitter law **q = k·H^x**. x = 0.5 for orifices and turbulent flow; 0.6 to 0.8 for long path;
  1.0 for laminar; 0 to 0.1 for pressure-compensating (0.02 to 0.05 typical). Least-squares fit of
  log q = log k + x·log H (test "fit recovers exponent").
- Sensitivity: Δq/q ≈ x · ΔH/H. Hence ±5 % of flow equals ±10 % of pressure for x = 0.5. Exact
  window from the inverse law (`headWindow`): H/H_n ∈ [0.95^(1/x), 1.05^(1/x)]:

| x | Minimum H/H_n | Maximum H/H_n | Total range |
|---|---|---|---|
| 0.53 | 0.908 | 1.096 | 18.9 % |
| 0.50 | 0.902 | 1.103 | 20.0 % |
| 0.47 | 0.897 | 1.109 | 21.3 % |
| 0.10 (PC) | 0.599 | 1.629 | 103 % (then limited by the minimum and maximum pressures of the catalogue) |

  The first three values are the ones design practice associates with the ±5 % flow tolerance.
- Wetted radius R = a·H^b (b ≈ 0.35).
- **Nozzles from a data sheet** (`EmitterCurve.fitTable`): rows of pressure, flow and, optionally,
  wetted radius become the two power laws q = k·H^x and R = a·H^b, each fitted by least squares in
  log-log space; with a single radius row b = 0.5 is assumed (the throw growing like the jet
  velocity). The worst relative deviation of the rows from each law is reported, so a typing error
  in a row shows before the nozzle enters the catalogue.
- Application rate (precipitation) PR = q / (S_l · S_m), with S_l the spacing along the lateral and
  S_m the perpendicular distance between laterals, for both square and staggered (triangular) grids;
  only when S_m is given as the side of an equilateral triangle does the area carry the sin 60°
  factor. In US units, PR [in/h] = 96.3·gpm/(S·L). Example: a 1.9 m³/h sprinkler at 15 × 17 m →
  7.45 mm/h.
- Recommended spacing: 50 % of the wetted diameter ("head-to-head") without wind; 40 to 45 % with
  wind.
- **Overlap CU**: the engine simulates the applied depth in one spacing cell from a triangular
  radial profile of every sprinkler and computes the Christiansen CU of the overlapped pattern, as a
  coverage check (test "head-to-head overlap gives high CU"); the result goes to the zone summary
  for sprinklers with a wetted radius.

---

## 9. Uniformity

Module `uniformity.dart`.

- **Christiansen CU**: CU = 100·[1 − Σ|x_i − x̄| / (n·x̄)]. Satisfactory ≥ 85 % in sprinkler
  irrigation. Example: relative flows 1.00, 1.10, 0.95, 1.05, 0.90 → CU = 94.0 %.
- **Low-quarter DU**: mean of the lowest quarter over the overall mean. Approximate relation
  CU ≈ 100 − 0.63·(100 − DU).
- **Keller-Karmeli EU (1974)**: EU = 100·(1 − 1.27·CV/√n)·(q_min/q_mean), with the manufacturer CV
  and n emitters per plant. ASAE classification: > 94 % excellent, 90 to 94 % good, 80 to 90 %
  fair, < 80 % poor; with fertigation the NRCS asks for EU ≥ 85 %.
  Example: CV = 0.03, q_min/q_mean = 0.90 → EU = 86.6 % with 1 emitter per plant and 88.3 % with 4.
  The n comes from the irrigated area containing the emitters of the zone (or from the global
  parameter).
- **Statistical uniformity** U_s = 100·(1 − CV_total); **flow variation** q_var =
  (q_max − q_min)/q_max, desirable ≤ 10 %, acceptable ≤ 20 %.
- Sprinkler lateral rule: pressure variation ≤ 20 % of the operating pressure, which gives ≈ 10 %
  of flow for x = 0.5.

### 9.1 Densogram

The overlap CU of section 8 idealises the layout as an infinite grid. The densogram (module
`densogram.dart`) instead adds up the wetted sector of every sprinkler and micro-sprinkler **as
drawn**: position, arc and orientation (counter-clockwise from the orientation, as drawn on the
screen), and, after a design, the pressure and flow of each emitter (so the radius R = a·H^b and
the flow follow the real pressure along the laterals). A sprinkler spreads its flow q over its
sector of angle θ with a radial profile f(r/R) normalised so that the volume integrates back to q:

- triangular f = 1 − r/R (single-nozzle impact sprinklers): i(r) = q·(1 − r/R) / (θR²/6);
- elliptical f = √(1 − (r/R)²) (multi-nozzle rotors, micro-sprinklers): i(r) = q·f / (θR²/3);
- uniform f = 1 (spray heads, matched precipitation): i = q / (θR²/2);
- **measured**: a nozzle may carry the radial distribution of a catch-can test (`NozzleSpec.profile`,
  read from a table of distance and depth: distances scaled to the farthest wet station, which is
  the wetted radius, and depths to the largest). Between the stations the depth is linear, flat
  before the first one and falling to zero after the last; the rate is
  i(r) = q·f(r/R) / (θR²·∫₀¹ f(x)·x dx), the moment integrated by trapezoids over 64 steps, so the
  volume is again exactly q.

**Wind** distorts the pattern by a first-order kinematic model: the water a drop carries from the
head to the calm-air offset v lands at v + a·|v|·ŵ, with ŵ the direction the wind blows towards and
a = k·u, u the wind speed at sprinkler height and k a drift coefficient (0.07 s/m by default; a
limited to 0.9). The patterns thus shift and stretch downwind as the studies of single sprinklers
in wind report (Seginer, Kantz and Nir 1991). Every grid cell is mapped back to its calm-air source
(the inverse of the displacement, in closed form) and the rate divides by the local area stretch
J = 1 + a·v∥/|v|, which keeps the volume. The model is not a substitute for measured windy-day
patterns.

The rates are summed on a grid (a quarter of the smallest radius by default, coarsened to at most
60 000 cells) and evaluated inside every irrigated area that holds sprinklers (or over the wetted
cells when there is none): mean, minimum and maximum rate, CU, low-quarter DU, **scheduling
coefficient** SC = mean / mean of the driest 5 % of the cells (how much longer the system must run
so the driest spots receive the mean depth; 1 is perfect, up to about 1.3 is good) and the share of
cells below half the mean. Each area is judged — and painted — against its own mean: a lawn of spray
heads (≈ 40 mm/h) next to one of rotors (≈ 13 mm/h) are both uniform even though their rates
differ, which a single mixed statistic would hide. Tests check that every profile integrates to the
flow (the measured ones too), that a half circle waters its own half at twice the rate, that
head-to-head spacing gives a high CU and wide spacing a much lower one, and that wind keeps the
volume while moving the water downwind.

---

## 10. Laterals and submains

Module `lateral.dart` (Wu & Gitlin 1975; Keller & Bliesner 1990).

- **Step-by-step analysis from the end to the inlet**: H_i = H_{i+1} + h_f(Q_{i+1}, S) ± ΔZ,
  Q_i = Q_{i+1} + q(H_i). For a known inlet pressure, the end pressure is iterated
  (`analyzeLateralFromInlet`); for a desired mean pressure, the inlet pressure that produces it is
  searched (`analyzeLateralForMeanPressure`), which is the criterion for setting the valve.
- Pressure profiles: uphill, level, gentle downhill (minimum at the end), steep downhill (minimum
  in the middle, because the gravity gain beats the friction). Test "downhill slope raises end
  pressure".
- Usual split of the allowable loss: 55 % in the lateral and 45 % in the submain.
- **Feed position**: feeding at the middle reduces the loss to ≈ 1/(2^m · 2) and allows laterals
  1.6 to 1.7 times longer. `allowableFeedPositions` evaluates feeding a lateral of length L at a
  fraction f (0 = end, 0.5 = centre), with both branches sharing the inlet pressure chosen so that
  the mean is the nominal one, and returns the acceptable positions and the best one; that is the
  "submain envelope" painted on the drawing and the test "feed positions: centre feed is best on
  flat ground".
- **Maximum length**: bisection over L, a multiple of the spacing, until the variation reaches the
  window (test "max lateral length is monotonic").

---

## 11. Networks: the Global Gradient Algorithm

Module `network.dart` (Todini & Pilati 1988, as in the EPANET 2.2 manual), with the sparse solver
of `sparse_solver.dart`. Tests in `network_test.dart`, `network_robustness_test.dart` and
`valves_formulas_test.dart`.

### 11.1 Formulation

For every link ij with head loss h_ij(Q):

- pipe: h = r·|Q|^n·sgn(Q) + m·Q·|Q|, with r and n from the friction law of section 5;
- pump: h = −ω²·(h₀ − r·(Q/ω)^n), or the parabola fitted from the catalogue;
- emitter: a fictitious pipe to a reservoir at the emitter elevation, with n = 1/x and
  r = (1/k)^n, which is how EPANET treats emitters q = C·p^γ. Its flow is a state variable
  updated by the same Newton step as a pipe's: in this flow form the law p = (q/k)^(1/x) is
  convex. Linearising q(p) instead (as the engine did until October 2026) overshoots, because
  dq/dp is infinite at p = 0, and emitters working near zero pressure flipped open and closed
  without end: 55 % of a set of random, sensibly sized networks never converged, 72 % with
  pressure-compensating emitters. Gradients below 10⁻⁶ use a linear law, as EPANET does with
  RQtol: a starved emitter then holds its node at about zero pressure and passes what arrives.
  The step never takes an emitter more than 10 % above what its law gives at the current
  pressure (Newton overshoots a steep law from below: x = 0.02 is p ∝ q⁵⁰), exponents below 0.01
  are taken as 0.01 through the same flow at 10 m, and the flow form is evaluated up to 1000 m.
  The emitter is one-way: when its flow would turn negative it closes (no outflow and, unlike a
  reservoir link, no backflow into the network) and it reopens at a status check once the
  pressure is positive (tests "emitters under negative pressure", `network_robustness_test`).

Define g_ij = ∂h/∂Q = n·r·|Q|^{n−1} + 2·m·|Q| (in Darcy-Weisbach add ∂r/∂Q·|Q|^n) and the
correction term y_ij = h_ij(Q)·sgn(Q). Every iteration solves the symmetric positive-definite
linear system A·H = F, with

A_ii = Σ_j 1/g_ij, A_ij = −1/g_ij, F_i = Σ_j (Q_ij + y_ij/g_ij) − D_i + Σ_f H_f/g_if,

the last terms for fixed-head reservoirs. Flows are updated by
Q_ij ← Q_ij − (1/g_ij)·(y_ij − (H_i − H_j)).

### 11.2 Valves and special cases

The valve models are EPANET's.

- An active **PRV** forces H_j = H_setting (A_jj += 10⁸, F_j += 10⁸·H_setting); closed, h = 10⁸·Q.
  Its status follows EPANET's logic: active → open when the inlet head less the loss of the fully
  open valve falls below the setting, open → active when the outlet head (not the inlet) rises
  above it (test "PRV holds downstream pressure", "an open pressure reducing valve whose inlet
  is just above the setting stays open").
- An active **PSV** (pressure-sustaining valve) holds its upstream node at the setting
  (A_ii += 10⁸, F_i += 10⁸·H_setting) and its flow follows from continuity at that node. Status as
  EPANET's `psvstatus`: active → open when the downstream head plus the loss of the fully open
  valve exceeds the setting (open, the valve would leave the upstream above it anyway); active or
  open → closed on reverse flow; open → active when the upstream head falls below the setting;
  closed → open or active when the heads would push the flow forwards again (test "a PSV holds the
  upstream pressure at its setting and limits the flow accordingly").
- An active **FCV** (flow-control valve) passes its flow setting: a fixed flow from one end to the
  other, with a vanishing conductance of 10⁻⁸ between them so that neither side is left without a
  head, as EPANET does. It opens (passing less than the setting) when the head across it turns
  negative and becomes active again when the flow reaches the setting. A **hydrant with a flow
  limiter** is an FCV whose setting is the flow typed, or the rated flow of the catalogue item
  (tests "an FCV lets its flow setting through, or less when the head is not there", "a hydrant
  flow limiter in a project limits the flow of its branch").
- Check valve, on a pipe or as a device of its own: closes when the flow reverses or the head
  turns against it, reopens when the head drop is positive again (test "a check valve fitted as a
  device stops reverse flow"; device check valves used to let water run backwards).
- Pump: linearised at |Q| while open, as EPANET does; it closes only when the head gain asked
  for exceeds its shutoff head and reopens below it, at the flow its curve gives for that head
  (one step with a reversed flow used to lock it closed for good).
- Devices: the catalogue curve h = K·Q^n + C. The **master valve** on the mainline is such a
  device for the hydraulics; electrically it is the master-valve output of its controller
  (section 18.1).
- The gradient of a device or an open valve never falls below 10⁻⁷ (EPANET's RQtol): with nearly
  no loss at nearly no flow (an air valve on a line at rest) a smaller floor, 10⁻⁹ until October
  2026, made the system too ill-conditioned to solve next to the 1/10⁸ conductance of a closed
  pump.
- Pressure-dependent demand at the emitters (Wagner): that is the detailed design analysis, with
  the real flow of every emitter.

### 11.3 Convergence and algebra

Criterion: Σ|ΔQ|/Σ|Q| < 10⁻⁵, or Σ|ΔQ| < 10⁻⁹ m³/s for networks carrying (almost) no flow, where
the relative measure is noise, with up to 200 iterations (`NetworkOptions`); tighter than EPANET's
10⁻³ because drip zones have minute flows per node. As in EPANET, statuses (check valves, pumps,
reopening emitters, PRVs, PSVs and FCVs) change only when the flows have converged, and in the
first ten iterations every other one: changing them at every iteration let one-way devices near
their switching point cycle. A fixed set of random tree networks must converge to solutions that
satisfy continuity and the head-loss laws (`network_robustness_test`).

**Parts at rest.** Closed links (a closed valve or check valve, an idle pump) may cut off a part of
the network that holds no fixed head and from which nothing is drawn: a line at rest behind an
idle pump. Solved with the rest, such a part had its level held only by the 1/10⁸ conductances of
the closed links, next to conductances of 10⁷ inside it, and the system was singular to rounding:
idle networks used to diverge. At every iteration the solver finds those parts (union-find over the
open links; a part is busy when it holds a reservoir, a demand or a flowing emitter, or feeds a
pump, an FCV or an active PRV or PSV) and levels each one at the mean head across its closed links
— the value their equal conductances would give — or at its lowest emitter when that is lower,
since the water drains out there. Its nodes enter the system as known heads and its links carry no
flow (tests "converge level at the mean head across the closed links, whatever their size", for
lines of 10 to 800 links, and "drain down to their lowest emitter").

The matrix A is assembled as sparse and factorised by LDLᵀ with minimum-degree ordering; for
branched networks (nearly trees) the factorisation creates no fill-in and the cost is close to
linear, which allows zones with thousands of nodes (test "large branched network is fast").

### 11.4 Use in the design

The zone is solved as a complete network: a fixed-head reservoir at the node downstream of the
valve (valve pressure), nodes with lumped emitters, submain and lateral links. The **valve
pressure** is found by bisection so that the mean emitter pressure equals the nominal one (the
"quick analysis" version uses fixed demands and a two-pass linear adjustment). The mainline is
solved per system flow with fixed- or calculated-pressure supplies, pumps and the demands of the
valves, pivots and valve-in-head stations (section 16).

---

## 12. Pumps and energy

Module `pump.dart`; selection in `pump_selection.dart`. Tests in `pump_devices_test.dart`,
`mains_frequency_test.dart` and `valves_formulas_test.dart`.

- Quadratic H(Q) curve H = a·Q² + b·Q + c fitted by least squares to three or more points (two
  points give a line; one point generates EPANET's synthetic three-point curve). Speed ratio ω by
  the affinity laws: H(Q) = ω²·H_base(Q/ω); Q ∝ N, H ∝ N², P ∝ N³.
- System curve H_sys(Q) = H_static + k·Q^n; operating point at the intersection, by bisection.
- Hydraulic power P = ρ·g·Q·H; shaft power divides by the efficiency. Preferred region 70 to 120 %
  of the best-efficiency flow.
- **Efficiency curve**: when the catalogue gives (Q, η) points the efficiency at flow q and speed
  ratio ω is the full-speed curve read at the homologous flow q/ω (the affinity laws keep the
  efficiency of homologous points), linear between the points and at least 5 %; otherwise the
  single efficiency of the item. The annual energy of every system flow uses it.
- **NPSH**: the required NPSH of a curve of (Q, NPSHr) points scales as NPSHr(q, ω) =
  NPSHr₁(q/ω)·ω² (the last segment extended beyond the curve, as the required NPSH keeps rising
  towards run-out). The available NPSH at the pump inlet is NPSHa = H_atm(z) + p_inlet − p_v(T), the
  atmospheric head at the site elevation plus the inlet pressure head minus the vapour pressure at
  the water temperature; `pump_npsh` warns when NPSHa < NPSHr + 0.6 m (ANSI/HI 9.6.1 recommends a
  margin of 0.5 to 1.5 m or a ratio for most services).
- **Annual cost** = capital · CRF + energy, with CRF = i(1+i)^n / ((1+i)^n − 1). For i = 10 % and
  n = 10 years, CRF = 0.16275. Energy [kWh/year] = P[kW] · hours/year; the energy cost of the inlet
  head enters the LP objective (section 15).
- **Automatic selection** (`pump_selection.dart`): for the worst duty of the supply, ranks the
  catalogue pumps by their ability to meet flow and head with margin and picks the standard IEC
  motor that covers the shaft power with a 1.15 service factor. When the water lies deeper than
  the practical suction lift, only submersible pumps are suitable.
- **Suction lift**: a supply node stands for its water surface, so a well starts at zero pressure
  at the water level and the pressure at the inlet of a surface pump is minus the suction lift
  (static lift plus suction pipe losses). The practical limit is the atmospheric head at the site
  elevation (10.33 m at sea level, standard atmosphere) minus the vapour pressure at 20 °C
  (0.24 m) and a 3 m allowance for the required NPSH and margin: about 7.1 m at sea level and
  5.9 m at 1000 m. A running surface pump beyond it raises `pump_suction_lift`. A pump flagged
  *submersible* in the catalogue is installed at the water level of the supply that feeds it: its
  inlet sees no suction and the lift shows in the pipe that rises from it; the energy balance does
  not change. The report lists pumps and devices in their own table with inlet and outlet
  pressures, pump head or loss, and state.

### 12.1 Mains frequency

A pump curve is measured at one mains frequency (`PumpSpec.ratedHz`; `hz` in the catalogue packs,
the bundled pump pack being 60 Hz), and the site has its own (`DesignParameters.mainsHz`, 50 or
60 Hz). A fixed-speed induction motor turns in proportion to the frequency, so the network builder
gives the pump the speed ratio ω = f_mains / f_rated (times the ratio the user typed): a 60 Hz
curve on 50 Hz mains runs at 5/6 = 0.833 of its speed, delivers 0.833 of the flow at homologous
points, 0.694 of the head and needs 0.579 of the power. A curve whose frequency is not stated is
read as it is. Pump selection reads every curve at the speed of the mains, and the allowed flow
range scales with it (Q ∝ N). For the pump trip of section 14 the running speed of the motor comes
from its poles and the mains: the synchronous speed 120·f/p less about 3 % slip, to the nearest
50 rpm, 3500 rpm (2 poles) and 1750 rpm (4 poles) at 60 Hz, 2900 and 1450 rpm at 50 Hz (tests "a
60 Hz pump on 50 Hz mains runs at 5/6 of the speed; a variable speed drive is not slowed", "pump
selection reads the curves at the speed of the mains").

### 12.2 Variable-speed pumps with a target pressure

A pump with a target outlet pressure has a variable-speed drive (`PumpEntity.targetPressureM`):
in every system flow the designer finds the speed ratio, between the minimum (0.5 by default, at
least 0.1) and the pump's own ratio, at which the outlet pressure equals the target, by bisection
on the speed with the whole mainline solved at every step (to 0.05 m or 10⁻⁴ of speed, at most 30
steps; three rounds when several drives interact). The mains frequency does not slow a drive. When
even the highest speed falls short the design reports `vfd_target_unreachable`, when the lowest is
already above the target `vfd_below_min_speed`, and when a calculated supply has to make up a
pressure the valves need `vfd_target_low`. The speed belongs to the flow: the device results carry
it, the pump curve chart draws the curve at that speed, and the energy uses the efficiency at the
homologous point (test "a variable-speed pump holds its outlet pressure flow after flow; NPSH
and efficiency curves").

---

## 13. Water hammer and pressure ratings

Module `water_hammer.dart`; check in `Designer.checkSurge`. The full transient analysis by the
method of characteristics is in section 14.

### 13.1 Joukowsky check

- Joukowsky: ΔH = a·ΔV/g. Celerity a = √[(K/ρ) / (1 + K·D/(E·e))], with K = 2.2 GPa,
  E_PVC ≈ 3 GPa, E_HDPE ≈ 0.9 GPa, E_steel ≈ 200 GPa.
- Critical closure time 2L/a: faster closures produce the full surge; slower ones a proportional
  fraction (the "valve closure time" parameter, 3 s in the examples with solenoid valves).

| DN 100 pipe | Celerity | ΔH for ΔV = 1.5 m/s | 2L/a for 500 m |
|---|---|---|---|
| PVC, 5 mm wall | 375 m/s | 57.3 m | 2.67 s |
| HDPE, 9.1 mm wall | 281 m/s | 43.0 m | 3.56 s |
| Steel, 4 mm wall | 1314 m/s | 200.9 m | 0.76 s |

- Rule of thumb: V ≤ 1.5 m/s (5 ft/s) in buried thermoplastic pipelines (ASAE S376.2), the default
  limit of the zone pipes; the 2.0 m/s default of the mainline is accepted where the surge check
  confirms the class.
- Pipe rating (PN 6, 8, 10, 12.5, 16; PVC class B 60 m, C 90 m, D 120 m) compared with the maximum
  static pressure plus surge; the worst segment of every pipe goes to the Water hammer tab.

### 13.2 Pressure classes and the water temperature

Thermoplastic pipes lose part of their pressure class when the water is warm
(`pipeTemperatureDerating`, `PipeSpec.ratingAt`): PVC keeps the whole class up to 25 °C and 0.9 of
it at 30 °C, 0.8 at 35 °C, 0.7 at 40 °C and 0.6 at 45 °C (ISO 1452-2 Annex A and the NBR 14312
data sheets); PE keeps it up to 20 °C, 0.87 at 30 °C and 0.74 at 40 °C (ISO 4427-1 Annex A, 50
years); linear in between and held at the last value above the table. Metal and concrete pipes keep
their rating. Example: a PVC pipe rated 100 m (PN 10) carrying water at 35 °C is rated 80 m. The rating
at the design water temperature is the one the sizing respects (section 15.5), the results report
and the water hammer and transient checks compare with (test "warm water derates the class: PVC
passes at 20 °C but not at 35 °C").

---

## 14. Hydraulic transients

Modules `transient.dart` (the method of characteristics on any network) and
`transient_analysis.dart` (the studies on a project: transients, air valve placement and the
24-hour simulation of section 17.1), after Wylie & Streeter (1993), *Fluid Transients in Systems*,
and Chaudhry (2014), *Applied Hydraulic Transients*. Tests in `transient_test.dart` and
`transient_analysis_test.dart`.

### 14.1 Equations and grid

Along the characteristics C⁺ and C⁻ of a pipe the momentum and continuity equations become, in head
and flow form,

H_P = C_P − B_P·Q_P and H_P = C_M + B_M·Q_P, with C_P = H_A + B·Q_A, C_M = H_B − B·Q_B, B = a/(gA),

and the friction term linearised as B_P = B + R·|Q_A| (R the friction resistance of a reach), which
keeps the steady state exact and the scheme stable with large friction. At an interior grid point
H_P = (C_P·B_M + C_M·B_P)/(B_P + B_M) and Q_P = (C_P − C_M)/(B_P + B_M).

- **Wave speed**: from the catalogue wall of every pipe by the Korteweg formula of section 13.1.
- **Grid**: one time step Δt for the whole system and Δx = a·Δt in every pipe. The wave speeds are
  adjusted to fit a whole number of reaches within ±10 %; a pipe that cannot be fitted uses
  space-line interpolation with a Courant number below one; a pipe much shorter than a·Δt is lumped
  into a rigid water column (inertia L/(gA) and its friction), at most 2 % of the total length.
  The longest pipe gets at least 8 reaches as far as a work budget of grid points × steps allows
  (4·10⁷; 2·10⁷ in the project studies), and Δt is at most a tenth of the run-down time I·ω/T of
  every tripped pump. Every adjustment is reported.
- **Merged chains**: series pipes of the same diameter and celerity, joined at nodes that draw no
  water, are one characteristic grid that keeps the elevation profile, so a high point inside it
  still cavitates.
- **Friction**: quasi-steady Darcy-Weisbach with a constant factor per pipe, the one that
  reproduces the steady head loss at the steady flow: a Hazen-Williams pipe gets its equivalent
  Darcy factor at the steady flow, and a pipe without flow (below 0.02 m/s) the factor at 1 m/s.
- Heads and pressures are gauge, as in the steady solver; the vapour and barometric heads are
  absolute, the barometric head that of the site elevation and the vapour head that of the water
  temperature.

### 14.2 Boundary conditions

Nodes are solved one by one, coupled only where point elements join them (Newton on a small dense
system); a step in which a state changes (a check valve closing, a cavity forming, an air pocket
closing) is solved again.

- Reservoirs, dead ends, series and branching junctions.
- **Valves**: the orifice relation ΔH = ΔH₀·(Q/(τ·Q₀))², the steady loss of the device calibrating
  it, with the relative opening τ(t) of a stroke τ = τ_end + (τ₀ − τ_end)·(1 − t/T)^E (E = 1 is a
  linear closure) or of a table. A valve placed on a pipe has the open loss of a gate valve,
  ΔH = K·V²/2g·(1/τ² − 1): it throttles only near the end of its stroke, so its effective closure
  is much shorter than the stroke.
- **Demands and emitters** as orifices, Q = Q₀·(p/p₀)^x (x = 0.5); a demand stops either as a
  prescribed flow falling linearly (the boundary of Michaud's formula) or as an orifice whose τ
  falls linearly, which is how a zone valve closing looks from the mainline.
- **Check valves** close on reverse flow and reopen when the head pushes forwards again; the
  orifice law is regularised near zero flow.

**Example** (the API example): a reservoir of 100 m feeding a 1000 m pipe of 0.5 m (a = 1000 m/s)
closed at once by a valve carrying 0.998 m/s. The head at the valve rises by a·V/g = 101.8 m and
oscillates with the period 4L/a = 4 s; a slow closure of time t_c > 2L/a gives about Michaud's
2·L·V/(g·t_c) instead (tests "instantaneous closure: Joukowsky surge a·ΔV/g and the 4L/a period",
"slow demand stop: Michaud surge 2·L·V/(g·tc)", "slow valve closure: first-interval orifice
solution, below Joukowsky, rigid column when very slow", "friction damps the oscillation", "mass is
conserved at a branching junction").

### 14.3 Pump trip

After a power failure the speed ratio α of the pump falls by the speed equation
I·ω_R·dα/dt = −T_R·β, integrated over a step as α_P = α − (k/2)·(β + β_P) with k = T_R·Δt/(I·ω_R),
and the torque model β = β₀·α² + (1 − β₀)·α·v, v = Q/Q_R ≥ 0: the torque at zero flow is β₀ of the
operating torque (0.5 by default) and the power grows linearly with the flow at constant speed, a
documented simplification of the homologous torque curve of a radial pump. The head follows the
affinity laws, H = a·Q·|Q| + b·α·Q + c·α², the quadratic of the curve extended beyond its range (at
α = 0 the stopped impeller is a quadratic loss), and the built-in check valve closes on reverse
flow.

The moment of inertia of pump and motor, when not given, is estimated from the rated power P (kW)
and the speed N (thousands of rpm) by the correlations of Thorley & Faithfull (1992), *Inertias of
pumps and their driving motors*:

I_pump = 0.03768·(P/N³)^0.9556 and I_motor = 0.0043·(P/N)^1.48 (kg·m²).

Example: 15 kW at 3500 rpm gives 0.0138 + 0.0371 = 0.051 kg·m². In a project study the power is the
rated power of the catalogue item (else the shaft power at the operating point) and the speed that
of the motor's poles on the mains (section 12.1), times the speed of a drive (tests "run-down
follows the pump boundary condition until the reflection returns; the check valve closes", "the
inertia estimate grows with the power and falls with the speed").

### 14.4 Column separation

Where the pressure falls to the vapour pressure the discrete vapour cavity model (DVCM) holds the
head at the vapour head at that node or grid point; the flows on either side then differ, and the
cavity volume integrates their difference with a weighting ψ (0.5 by default, 0.5 to 1; Bergant,
Simpson & Tijsseling 2006):

∀_P = ∀ + Δt·[ψ·(Q_out,P − Q_in,P) + (1 − ψ)·(Q_out − Q_in)].

The cavity collapses when the flows of the step fill it, and the collapse produces the short
pressure pulses of column separation. **Empty cavities**: a cavity emptied only by the flows of the
previous step, while the flows of this step would open it again (the liquid head would fall below
the vapour head), stays at the vapour head with no volume instead of collapsing; collapsing it made
the head drop below the vapour head at the next step. A merged node interpolated inside a chain is
kept at or above its own vapour head, since a high point between grid points would otherwise borrow
the heads of the lower ones (test "column separation: vapour cavity at the valve after the
downsurge").

### 14.5 Air valves

A combination air valve (AWWA M51 terminology) at a node admits air through its large orifice when
the pressure falls below atmospheric and exhausts it through the outflow orifice (equal for a plain
air/vacuum valve, smaller for an anti-slam exhaust), with discharge coefficients of 0.6. The air
admitted forms an isothermal pocket, p·∀ = m·R·T, whose mass integrates the orifice flows by the
trapezoidal rule (Wylie & Streeter 1993). The mass flow is the isentropic flow of a perfect gas
through a nozzle: subsonic,

ṁ = C_dA·√(2κ/(κ−1)·p_u·ρ_u·[r^(2/κ) − r^((κ+1)/κ)]), r = p_d/p_u,

while r is above the critical ratio (2/(κ+1))^(κ/(κ−1)) = 0.528, and choked below it,
ṁ = 0.685·C_dA·p_u/√(R·T) (κ = 1.4, R = 287.05 J/(kg·K)). Two details make the Newton iterations
of the node converge:

- the orifice flow grows with √Δp, infinitely steep at Δp = 0, where the iterations went back and
  forth for ever: within ±10 Pa (about 1 mm of water) of the atmospheric pressure the law is
  interpolated linearly;
- a shrinking pocket smaller than 1 cm³ closes the valve: the float has shut, and the stiff law of
  a vanishing pocket would only stall the step (the valve may open again at a later step).

Test "a combination air valve admits air at a high point when the head drops below the pipe".

### 14.6 Surge vessels

An air vessel (hydropneumatic tank) at a node holds gas following the polytropic law H*·∀ⁿ = C (H*
the absolute head of the gas, n = 1.2 by default: 1 is isothermal, 1.4 adiabatic), connected through
an orifice with different loss coefficients into and out of the vessel (2.5 and 1.0 velocity heads,
a differential orifice throttling the inflow more). The flow into the vessel at the node head H is
the root of H − R·Q·|Q| − z_w(Q) − C/∀(Q)ⁿ + H_b = 0, with ∀(Q) = ∀ − Δt·(Q₀ + Q)/2 and the water level
z_w following the free-surface area when given (Wylie & Streeter 1993; Chaudhry 2014). The vessel
holds three times its gas volume unless stated, and `transient_vessel_drained` warns when the gas
fills it (test "an air vessel at the discharge limits the downsurge").

### 14.7 Transient studies of a project

`TransientStudy` runs the method on the steady mainline of every system flow exactly as the design
analyses it (`Designer.mainlineNetworkFor`: calculated supplies at the pressure the valves need,
the drive speeds of the flow):

- **Valve closure**: the zone valves and pivots of the flow, seen from the mainline as orifices
  whose opening falls to zero in the closure time of the design parameters, and the heads of the
  valve-in-head stations the flow schedules;
- **Pump trip**: a power failure of every running pump of the flow (section 14.3);
- **Isolation valve closure**: an item of the mainline whose catalogue kind is an isolation or
  master valve, in its own closure time.

Every pipe takes its celerity from its catalogue wall, its physical length (the design adds the
minor losses as length; the steady loss is kept) and its pressure class at the water temperature;
the air release devices drawn on the mainline act as combination air valves of their nominal size.
The duration is chosen from the event and six periods 4L/a of the longest path (plus 5 s, between
15 and 120 s). For every pipe entity the study keeps the transient envelopes of head and pressure
against the class and against vacuum (`transient_overpressure`, `transient_underpressure`,
`transient_vacuum`), the vapour cavities (`transient_column_separation_pipe`) and the air admitted,
the profile along the critical path (pipe and ground elevations, steady head, the two envelopes
and the class line), the pressure in time at the pump discharge and at the worst point, and the
findings the plan marks (overpressure, vacuum, column separation, air admitted). Tests: on the
sugarcane and gravity examples, "every scenario runs and the steady state lies inside the
envelopes"; "an instantaneous closure on a simple line gives about the Joukowsky surge", "a power
failure trips the pump: the check valve closes, the speed falls, the discharge drops", and a farm
mainline of a few hundred pipes simulated over tens of seconds in a test that bounds its run time.

### 14.8 Air valve placement

`suggestMainlineAirValves` builds the profile of every path from a water supply to an end of the
mainline (pipe and ground elevations, the lowest steady grade line of the flows, the transient
minimum envelope when a study is given, bores, pumps and check valves) and places air valves on it
by the practice of AWWA Manual M51, *Air-Release, Air/Vacuum, and Combination Air Valves*
(`air_valves.dart`):

- high points of the pipe, and of the pipe against the grade line: combination valves;
- increases in downward slope: air/vacuum (or combination) valves, which admit air when the line
  drains; decreases in upward slope: air-release (or combination) valves, where air collects in
  operation;
- long ascents, descents and horizontal runs: a valve at least every 400 to 800 m (1/4 to 1/2
  mile), longer gaps split into equal parts;
- the discharge of a pump (air/vacuum), 1 m downstream of check valves, and the end of the line;
- points where the steady grade line comes within 2 m of the pipe, and where the transient minimum
  envelope drops below atmospheric pressure (vacuum protection).

Slopes under 0.0005 count as horizontal, a change of slope of 0.005 counts at a vertex, a high point
needs 0.1 m of rise and fall around it, and suggestions closer than 20 m are merged.

Sizing follows the M51 procedure with the orifice flow of section 14.5: the large orifice of an
air/vacuum or combination valve passes the air that replaces the largest drainage flow with the
inside pressure 5 psi (34.5 kPa) below atmospheric, and exhausts the air the filling flow displaces
2 psi (13.8 kPa) above it. The drainage flow is the pipe running full by gravity down the slope that
drains away from the valve, the Hazen-Williams loss equal to the slope:
Q = (S·C^1.852·D^4.871/10.67)^(1/1.852) ≈ 0.278·C·D^2.63·S^0.54 (C = 140); the filling flow defaults
to 0.3 m/s (1 ft/s), the filling rate M51 recommends. The small orifice of an air-release valve
releases the air the water carries, 2 % of the flow by volume at atmospheric pressure, at the
operating pressure. The nominal size is the next of the standard series (25 to 600 mm for air/vacuum
and combination valves, 12.5 to 50 mm for air release) and the catalogue item that fits; the
suggested valves are inserted on the pipes at their positions. Example (the API example): a 2000 m
line of 0.3 m rising 20 m to its middle gets combination valves at 500 m (long ascent), 1000 m
(high point), 1500 m (long descent) and 2000 m (end of the line) (tests "a hill: high point, line
end and valves on the long ascent and descent", "orifice sizing by compressible flow, gravity
drainage by Hazen-Williams", "the transient minimum envelope adds vacuum protection; a catalogue
without air valves is reported").

---

## 15. Pipe sizing

Modules `lp.dart`, `lp_sizing.dart`, `designer.dart`. Tests in `lp_test.dart`,
`sizing_features_test.dart`, `design_test.dart` and `pressure_class_test.dart`.

### 15.1 Maximum velocity

For every sizable unit (an entity with a "computer sized" pipe), the smallest enabled catalogue
diameter, of the right usage (lateral, zone or mainline), whose velocity at the maximum flow of the
link respects the limit (2.0, 1.5 and 2.0 m/s by default). It is the classic velocity sizing of the
manuals and the first step of both methods here, because it provides the nominal flows the LP needs.

### 15.2 Linear programming

Formulation (lp_sizing.dart):

- **Variables**: for every unit u and every candidate diameter d, the fraction x_ud of the length
  of the unit built with d; plus one free head variable per zone (inlet pressure) or per
  calculated-pressure supply.
- **Objective**: minimise Σ_u Σ_d c_ud · x_ud + Σ_h e_h · H_h, where c_ud is the annualised cost of
  the whole link in d (cost per metre × length × CRF) and e_h the annual cost per metre of head
  (power of the flow's discharge × hours × energy price / efficiency), with a minimum weight when
  there is no pump so that the LP still prefers the lowest head.
- **Constraints**: Σ_d x_ud = 1 for every unit; for every critical node, the pressure
  H_h − Σ_u Σ_d L_ud · x_ud − constant terms ∈ [P_min, P_max], where L_ud is the loss of the part of
  the unit on the path to the node when built entirely with d (the loss is linear in the fractions
  because the flow in every unit is fixed by the velocity step; it includes the friction of the law
  chosen and the minor losses of the fittings method); maximum velocity and pressure class through
  the set of candidate diameters; fixed non-sizable pipes.
- **Critical nodes** of the zone: the end, the highest and the lowest node of every lateral and
  every single emitter (capped). If the analysis does not confirm the window, the emitters at
  minimum and maximum pressure become additional constraints and the LP runs again, up to four
  rounds.
- **Rounding and telescoping**: the fractions are converted into the allowed number of diameters
  per unit (1 lateral, 3 submain, 3 mainline by default), largest diameters upstream; units with
  more than one diameter are split into entities before the final analysis.
- **Solver**: dense two-phase simplex with Dantzig's rule and a Bland fallback against cycling; the
  problems have hundreds of variables and constraints, which fits a dense tableau. It detects
  infeasibility and unboundedness (test "simplex: equality rows, infeasible and unbounded
  detection").

A common simplification in sizing tools is to reduce every lateral to an equivalent pipe with one
concentrated emitter before the LP; here the lateral is a unit with its critical nodes, without
reduction.

### 15.3 Repair and rationalisation

After the LP (or with the velocity step only, in the greedy method), the zone is analysed and, if an
emitter violates the window, the diameter of the unit on the critical path with the largest loss
reduction per cost is increased until it is met (`_repairZone`). Then the rationalisation
guarantees non-increasing diameters from upstream to downstream. The test "LP design meets the
pressure window and costs no more than greedy" compares the two methods on the orchard example.

### 15.4 Valve pressure and results

The final detailed analysis chooses the pressure downstream of the valve by bisection so that the
mean emitter pressure equals the nominal one (for regulated tapes, to guarantee the minimum submain
pressure). The valve loss comes from its curve; the required upstream pressure feeds the mainline.
The allowable variation of the zone comes from the emitter flow tolerance (or from the "maximum
zone variation" parameter) and the actual one is measured over the lumped emitters.

### 15.5 Pressure class as a constraint

A pipe must withstand the pressure it ends up carrying, and that pressure is only known after an
analysis of the sized network. The sizing therefore learns it in passes (`_requiredRating`): after a
pass, the highest steady pressure at the ends of every segment of each computer-sized unit is
compared with the rating of its pipe at the design water temperature (section 13.2); a unit whose
pipe is rated below it gets that pressure as its minimum rating, and the next pass offers it, in the
LP and in the greedy steps alike, only the catalogue pipes rated for it. There are up to three
passes for every zone and for the mainline, and the rationalisation and the final analysis follow
the last one. When no candidate of the catalogue is rated high enough, the unit keeps every
candidate and the analysis reports `pressure_rating_exceeded`. The requirement is the steady
pressure; the surge (section 13.1) and the transients (section 14) are checked against the same
derated class afterwards (tests "a 95 m supply never gets PN 80 PVC", for the LP and the greedy
method, and "nothing in the catalogue withstands the pressure: sized as before and warned").

---

## 16. Mainline, system flows and supplies

### 16.1 System flows and supplies

- **System flows**: sets of zone valves, pivots and valve-in-head stations operating together,
  with start time and duration. Without defined flows, all of them are assumed to operate together
  (the worst case for the mainline and the supply).
- **Automatic system flows** (`management.dart`): the demand of every zone (the design flow, or the
  nominal flow of its emitters at their nominal pressure), of every pivot (the machine flow) and of
  every valve-in-head station (its heads at their nominal pressure) is packed first-fit decreasing
  into the fewest flows whose total stays within the maximum flow (the design flow of the supplies
  by default) and, optionally, a maximum number of zones; a demand larger than the limit gets a
  flow of its own and is reported. The flows run one after the other. Section 17.4 groups them for
  the least energy instead.
- **Demands**: for every valve, the zone flow and the required upstream pressure; for every pivot,
  the flow and the inlet pressure of the machine (the sprinkler package of section 22.1 may ask for
  more than the plain machine hydraulics); for every scheduled valve-in-head station, its heads
  (section 16.2).
- **Mainline LP**: the same fraction-per-diameter variables, with a required-pressure constraint at
  every valve in every flow, and the energy cost weighted by the hours of every flow over the annual
  hours. Fixed-pressure supplies enter as constants; calculated supplies have the head as a
  variable.
- **Analysis per flow**: the complete mainline network with pumps (operating point, or the speed a
  variable-speed drive sets in that flow, section 12.2), PRVs, PSVs, flow-control valves, check
  valves, devices and the demands; results per supply (duty: flow, available pressure, required
  pressure, deficit, elevation), per valve (available versus required), per valve-in-head station
  and per pipe; annual energy, with the efficiency curve of every pump.
- **Calculated supplies and pumps**: the required pressure of a calculated supply is the deficit
  of the worst valve with the supply at zero pressure, i.e. after the head the pumps of the flow
  add at their operating flow. When that deficit is negative the pumps (or the elevation) already
  cover the need: the analysis keeps the supply at zero, reports the required pressure as zero
  with the surplus beside it, and the extra pressure shows along the mainline and at the valves.
  A pump is therefore judged by its duty (required head plus the head it adds) and by the
  surplus, not by the valve pressures, which the design always meets.
- **Loops**: in a looped mainline the sizes decide how the flow splits, and the LP, written on the
  flows of the velocity step, uses tree paths (message `lp_loops_approx`). After the first LP the
  network is analysed with the new sizes and the LP is solved again with the redistributed flows,
  up to four more times, until the choice of diameters settles: the gradient idea of Alperovits &
  Shamir (1977) with this LP at every step. The final analysis checks the pressures; the test
  "looped mainline sizing with LP adds the approximation note and still converges" guards the
  behaviour.

### 16.2 Valve-in-head stations

A sprinkler drawn on the mainline has its valve in the head (`valve_in_head.dart`). The station is
the unit the system flows schedule and the controller wires: a head without a zone name is a
station of its own (its id), heads sharing a zone name form the station `vih:<name>`, their
solenoids in parallel on one station. A flow schedules a station by listing it beside its zone
valves and pivots:

- a station some flow lists runs **only** in the flows that list it, and the design gives its heads
  their nominal pressure there, as it gives a zone valve the pressure its zone needs: the need at
  the mainline node of every head is its nominal pressure plus the riser, and the critical head of
  the station enters the deficit of the supply and of the mainline sizing;
- a station no flow lists runs in **every** flow without a say on the supply pressure, which is how
  the mainline outlets behaved before they could be scheduled, so the projects that never scheduled
  them keep their results (test "flows that list no valve-in-head station give the results of
  before");
- in the mainline LP the heads of a scheduled station have the lower bound max(window minimum,
  nominal pressure) in the flows they run in; unscheduled heads keep their pressure window in every
  flow;
- in the analyses that size the pipes (calculated supplies at zero pressure) a scheduled head
  draws its nominal flow as a fixed demand, as a zone valve draws the flow of its zone; in the final
  analyses the heads are pressure-dependent emitters, whose flow grows with the supply pressure
  while the losses grow with their flow, so the pressure of the calculated supplies is raised from
  the first estimate until the worst head gets its need (at most 30 rounds, to 1 mm);
- a head that is off in a flow keeps its node with no emitter running, so every flow has the same
  nodes and links.

The results hold a duty per station and flow (`VihDuty`: heads, flow, lowest and highest nozzle
pressure against the window, the critical head and its need) in the report tab "Valve-in-head",
with the messages `vih_not_in_flow` (a station no flow lists while the project has
flows), `vih_pressure_deficit` and `vih_pressure_high`. The stations go through every other
analysis with their schedule: the static lift for the pump selection counts the worst head of the
scheduled stations, the 24-hour simulation runs the heads in the windows of their flows, the
transients close them with the zone valves of the flow, the tariff scheduling and the energy
grouping take them as demands, the wiring gives each station one station of a controller (section
18.1), the controller programme and fertigation use the irrigated areas of their heads, and the
EPANET export of a flow writes the heads of the stations it runs as emitters. Tests in
`valve_in_head_test.dart`, among them "heads run only in the flows that schedule them, the worst
at its nominal pressure".

---

## 17. Operation analyses

A sized design is one steady state per system flow. The analyses of this section look at the system
in operation: over a day, under a tariff, with farmers opening hydrants at will, with the energy as
the goal, with a pipe out of service, against field readings and while a fertiliser travels
through it. They work on the mainline exactly as the design solves it for a set of valves
(`Designer.mainlineNetworkFor`), and `network_ops.dart` joins them to the project for the dialogs;
what they propose (start hours, system flows, wire routes, a C scale) comes back as values the user
applies as one undo step.

### 17.1 A day of operation

Module `eps.dart`, an extended-period simulation that follows the time stepping of EPANET (Rossman
2000; EPANET 2.2 analysis algorithms): every hydraulic step solves the network with the tanks as
fixed heads at their current levels, then integrates the tank volumes over the step, by explicit
Euler with the flows at the start of the step (as EPANET) or by Heun's predictor-corrector (a second
solution at the end of the step, second order). The step is cut short at the next schedule, pattern
or control event, when a tank would fill or empty, and when a tank reaches the level of a control; a
full tank closes the links that would overfill it and an empty one those that would drain it. Demand
and emitter multipliers follow time patterns, link schedules open the zone valves at their start
hour for their duration, demand schedules switch on the demands of mainline nodes (a zone seen from
the mainline), and simple controls switch links by a tank level, at a time or at a clock hour. The
energy of every pump is ∫ρ·g·Q·H/η dt, its cost the price of a tariff function of the hour. Each
solution starts from the flows of the previous one, on a copy of the network (tests "a tank filled
at constant inflow reaches the analytic level", "a tank draining through a pipe follows the
analytic curve with a small step", "pump energy and its cost match the hand calculation").

`simulateDay` (`transient_analysis.dart`) runs the system flows of a project over a day at their
start hours and durations, each window taken modulo 24 h and split at midnight. One network holds
the demand of every zone valve and pivot, switched on in the windows of the flows it belongs to;
what differs between flows is replicated and scheduled: a supply whose pressure the design
calculates per flow becomes one source per pressure behind a check valve (the higher one feeds when
flows overlap), and a pump whose drive runs at different speeds in different flows one pump per
speed (the fastest of the running flows runs). Every pump is on while one of the flows it serves
runs, and a calculated supply counts as a pump giving its pressure, as in the energy of the design;
the heads of a valve-in-head station run in the windows of the flows that run the station. The
hydraulic step is at most one hour and is cut where a flow starts or stops. The result is the
series of every step, the hourly summary and the energy and its cost at the price of the
parameters, with an optional peak band (18 to 21 h by default, at a multiplier of 1, a flat tariff)
(tests "the energy and its cost match the hand calculation", "flows across midnight and
overlapping flows").

### 17.2 Tariff-aware scheduling

Module `tariff.dart`. A tariff is a set of seasons (months), each with energy prices by band of the
day, demand charges (monthly charges per kW of the highest power drawn at any time and in the peak
bands, a day carrying 1/30 of them) and an optional **irrigation discount** in a daily window the
consumer chooses. The Brazilian rule (Portaria Normativa MME nº 137, de 8 de junho de 2026) is the
default: up to 8 h 30 min a day, continuous or in up to three blocks of whole half hours, never
between 17:00 and 21:30, possibly different by season, with the discounts of Resolução Normativa
ANEEL nº 1.000/2021, art. 186, on the consumption (energy) tariff:

| Consumer group | Northeast and SUDENE area | North, Centre-West and the rest of Minas Gerais | Other regions |
|---|---|---|---|
| A (medium and high voltage) | 90 % | 80 % | 70 % |
| B (low voltage) | 73 % | 67 % | 60 % |

The jobs are the system flows of the design, each with its daily duration and electrical power (the
shaft power of the calculated supplies at their required head, with the pump efficiency of the
parameters, plus that of the pumps with their own efficiency, over the motor efficiency),
precedences and a daily limit of pumping hours. The scheduler chooses the start times and the
discount blocks that minimise the daily cost:

- the flows run one at a time (the network is designed for one flow at a time) and every day the
  same, inside a scheduling day that starts at the end of the excluded interval (21:30) unless set
  otherwise; no job runs across that instant;
- the day is cut into steps of 15 min: starts fall on steps and durations are rounded up to whole
  steps for the packing, while the costs use the exact minutes; the discount is decided per half
  hour;
- for a given order of the jobs, a dynamic programme over the steps, whose state is the job running
  (and how far it is), the discounted half hours used, the blocks opened, whether the current half
  hour is discounted and (when a block may cross the start of the day) whether the first one was,
  finds the start times and the blocks together, exactly;
- when the precedences leave few orders (24 by default) every order is solved and the schedule is
  optimal for the model. With more jobs the method is a documented heuristic: it starts from the
  given, power-descending and power-ascending orders and, up to 8 jobs, from the best order for one
  window of the whole discount at every place it fits; from each it alternates (a) the best order
  for the blocks of the current plan — exact over every order by a dynamic programme over subsets of
  jobs up to 12 jobs, pairwise swaps and insertions beyond — and (b) the exact joint programme for
  that order, while the cost falls, and keeps the best plan;
- a peak demand charge on the highest power drawn in the peak bands is handled exactly by solving
  once per cap on the power allowed in the peak.

Everything is deterministic; the plan is compared with the jobs at their current start hours (tests
"exact against a brute force over every start and block choice", "the Brazilian discounts and
rule", "peak demand charge: the small job takes the peak").

### 17.3 On-demand networks

Module `on_demand.dart`, after FAO Irrigation and Drainage Paper 59 (Lamaddalena & Sagardoy 2000,
*Performance analysis of on-demand pressurized irrigation systems*). In a collective network where
every farmer opens a hydrant when he wants, the design flow of a section comes from **Clément's
first formula** (Clément 1966): every hydrant i is open with probability p_i, independently of the
others, and the flow of a section serving the hydrants downstream of it, not exceeded with the
operating quality Pq, is

Q = Σ p_i·d_i + U(Pq)·√(Σ p_i·(1 − p_i)·d_i²)   (FAO 59 eq. 12),

with d_i the nominal discharge and U(Pq) the standard normal deviate (1.645 for 95 %; computed
exactly by Wichura's algorithm AS 241 unless given). p_i = t_i/T', t_i being the hours hydrant i
must be open per day of the peak period and T' = r·24 h the operating time of the network (r the
coefficient of utilisation), or p_i = q_s·A_i/(r·d_i) from the specific continuous discharge q_s and
the plot area A_i. At the extremities the flows are summed: a section serving N_min hydrants or
fewer carries them all, no section carries less than its N_min largest hydrants (N_min = 4, as in
FAO 59 Box 1), a section never carries less than one downstream of it, and with equal hydrants the
number open is rounded up. Loops are reported and left out (the formula needs a tree).

**Example** (FAO 59 Box 1 and Table 2): 19 hydrants of 10 L/s serving 3 ha each, q_s = 0.327 L/s
per ha, r = 0.667: p = 0.327·3/(0.667·10) = 0.147; at the head of the network
Σp·d = 27.9 L/s, σ = 15.4 L/s and Q = 27.9 + 1.645·15.4 = 53.3 L/s, 5.33 hydrants, rounded up to 6:
60 L/s; every section of the table is reproduced (test "FAO 59 Box 1 / Table 2: every section").

The **random check** (FAO 59 chapter 5) solves C configurations of hydrants open at once with the
network solver (C = the larger of 200 and the number of hydrants plus one): an open hydrant j of
configuration r is satisfied when its pressure head H_j,r ≥ H_min; per hydrant the relative pressure
deficit ΔH_j,r = (H_j,r − H_min)/H_min (eq. 52) and the reliability
α_j = Σ_r Ih_j,r·Ip_j,r / Σ_r Ih_j,r (eq. 54, the share of the configurations with the hydrant open
in which it is satisfied) are reported, and per configuration the share of unsatisfied hydrants.
With an upstream discharge Q the configurations come from the random generation model of FAO 59
chapter 3: hydrants drawn uniformly at random, without replacement, until |Q_conf − Q| < ε, ε the
smallest hydrant discharge (Bethery et al. 1981); without one, every hydrant is open independently
with its probability. The draws come from a seeded combined multiple-recursive generator MRG32k3a
(L'Ecuyer 1999), exact in double precision, so a check is reproducible on every platform; quantiles
are linear between order statistics (Hyndman & Fan 1996, definition 7). Hydrants have flow
limiters: FAO 59 assumes that every open hydrant draws its nominal discharge whatever its pressure,
which a demand-driven solution gives directly; optionally a hydrant below H_min delivers like an
orifice through the pressure-driven solution of section 17.5.

### 17.4 Energy grouping of the zones

Module `energy_grouping.dart`. The pump of a system flow must deliver the highest head any of its
zones needs, so the zones that need less get more pressure than they use: grouping zones with
similar required heads saves energy. This is the sectoring problem of Jiménez-Bello, Martínez
Alzamora, Bou Soler & Bartolín Ayala (2010) and of Carrillo Cobo, Rodríguez Díaz, Montesinos, López
Luque & Camacho Poyato (2011), who search with a genetic algorithm and a network model.

Model: zone i draws q_i for t_i hours and needs the pressure head h_i at its valve, whose node lies
at z_i. A group pumps Q = Σ q_i from the source level z_s and must deliver
H = max_i (z_i + h_i + k_i·Q^m) − z_s, k_i·Q^m being the loss from the pump to valve i (m = 1.852;
the whole group flow taken along the path, exact for a single pipe and on the safe side for a
branched mainline); the pump holds H while any zone of the group is open, so the group uses
E = ρ·g·H·Σ q_i·t_i/η. Method: (1) first-fit decreasing by flow, the baseline of section 16.1;
(2) the zones sorted by required piezometric head and cut into consecutive groups by a dynamic
programme over (zones placed, groups used), every group within the flow cap and the zones per
group, for every number of groups allowed, the cheapest within the daily hours kept; (3) from the
better of the two, moves of one zone to another group (or a new one) and swaps of two zones while
one lowers the energy within every limit; then a second local search with the head of each group
computed exactly by the designer (the mainline solved for that set of valves, at most 200 calls).
Valve-in-head stations take part at the node of their most demanding head, pivots at their
mainline node. Deterministic (test "zones of similar head together: 30 % less energy than first
fit by flow").

### 17.5 Criticality

Module `criticality.dart`: N−1 analysis. Every pipe (or every link chosen) is closed in turn and,
per scenario, the demand cut off from every source, the demand the remaining pressures cannot
deliver and the pressure deficits at the demand nodes are reported (for a mainline, every valve or
pivot of the flow needing the head of its design). In a network fed by one source through a tree,
closing a pipe cuts off everything downstream of it and the pressures of the rest cannot fall (less
flow, smaller losses, a falling pump curve gives more head), so the loss is reported without a
solution; elsewhere the part still connected to a source is solved again.

The demand not delivered comes from a **pressure-driven solution** (Wagner, Shamir & Marks 1988,
with zero minimum pressure): a demand d is delivered in full while the pressure head reaches the
required one, and below it like an orifice, q = d·√(p/p_req), stopping at p ≤ 0. The solver has no
flow-limited outlet, so the two regimes are an active set: every node starts with its full demand
as a fixed demand; a node below its required pressure becomes an emitter q = (d/√p_req)·p^0.5 in the
next solution, and an emitter node that rises above the requirement goes back to the fixed demand;
moving a node to the orifice regime only lowers the flows and raises the pressures, so the set
settles in a few rounds (at most 12). A steep device curve in series with an orifice would also cap
the flow, but the gradient method shrinks an over-estimated flow through a law h ∝ Q^n only by a
factor (1 − 1/n) per iteration and holds the cap only approximately (tests "pressure-driven demand:
full above the requirement, orifice below", "tree: closing a pipe cuts off what is downstream,
without a solution", "loop: the other way round keeps the nodes connected, at a lower pressure").

### 17.6 Calibration of the roughness

Module `calibration.dart`. A Hazen-Williams C scale per group of pipes (one global factor, or one
per material: the materials with the most length get a group each and the rest share the last) is
fitted to measured pressures and flows by weighted least squares, with the network solver in the
loop. Every residual is (model − measured)/σ, σ being the standard error of the reading (0.5 m for a
pressure by default; 2 % of a flow, at least 0.1 L/s), and the objective the sum of their squares.
One factor is found by golden-section search over the allowed range, 0.3 to 1.5 (Kiefer 1953); more
factors by Levenberg–Marquardt (Levenberg 1944; Marquardt 1963) with a forward-difference Jacobian,
the Marquardt scaling of the damping and the factors kept inside the range. The approximate
standard errors come from s²·(JᵀJ)⁻¹ at the solution. On a project the readings are taken at the
measuring points of the mainline of a system flow (a zone valve or pivot, a supply, a junction, the
upstream side of a device) and the flows leaving the supplies; a pressure read at a supply is the
head the network receives, a boundary condition rather than a residual. The factor found becomes
the C scale of the design parameters (tests "one global factor: golden section recovers C = 120
from a pipe built with 150", "two groups in series: Levenberg–Marquardt recovers both factors",
"flows split between parallel pipes tell their roughness apart").

### 17.7 Fertigation

Module `fertigation.dart`. Travel times are plug flow along the steady flows: crossing a pipe takes
its volume over its flow, V/|Q| (devices and pumps hold no volume). The product first appears at a
node after the fastest path from the injection point (Dijkstra 1959) and the node gets the full
concentration once the slowest path has arrived too (the longest path over the flow directions,
which form an acyclic graph in a steady solution). For the product to be flushed out of every
pipe, the injection must stop at least the slowest arrival at the farthest outlet before the
irrigation ends. The schedule divides the irrigation into pre-wetting, injection and flushing (one
quarter, one half and one quarter by default, the common rule of thumb; Burt, O'Connor & Ruehr
1995), the flushing never shorter than that travel time; the product mass is the dose per hectare
times the area over the nutrient share of the product (0.46 for the N of urea), the stock solution
that mass over its concentration, the injection rate the stock volume over the injection time and
the concentration in the irrigation water the mass over the water injected with it. On a project
the product is injected at a supply or at a mainline pump, travels along the mainline to every valve
and pivot of the flow and then inside every zone from its valve (the zone results of a detailed
design). A **venturi** on a bypass across a regulator, filter or valve works when the loss of that
device gives the differential its suction curve needs, or, without a curve, at least 20 % of the
inlet pressure (a common rule of thumb for the start of suction) (tests "one pipe: travel time is
volume over flow", "two paths: first appearance by the fast one, full concentration by the slow
one", "plan: quarters of the irrigation, amounts by hand").

---

## 18. Flushing, fittings, wiring and bill of materials

- **Flushing** (`analyzeFlushing`): every tape receives at its end the flow that produces the
  flushing velocity (0.3 m/s by default) and the zone is solved again; the valve pressure that keeps
  the minimum end pressure (1 m) is found and the flushing flow, the pressures and the maximum
  velocity are reported. It is the heaviest step of the calculation in zones with many tapes.
- **Fittings** (`fittings.dart`): from the sized graph, couplers per pipe stick (6 m), 90° and 45°
  elbows and tees and crosses from the geometry of the nodes, reducers where the diameter changes,
  end caps at dead ends, lateral take-offs, tape ends and emitter risers; each one looks for the
  catalogue item of that kind and size (or a generic name when there is none).
- **Bill of materials** (`buildBom`): pipes by diameter and rating, emitters, tapes, valves,
  devices, selected pumps (with an hour meter on the panel when asked), pivots (machine, towers,
  sprinklers, regulators and, from the sprinkler package, end gun, booster, corner arm and the span
  and supply cables), fittings and the electrical items (wires by size, controllers with their
  sensors and accessories, two waterproof connectors per solenoid), with unit costs, total,
  annualised cost (CRF) and annual energy. The same lines are also split by where they are
  installed (each zone, the mainline, each pivot, the electrical part), and the materials of a
  selection of the drawing can be listed on their own (a stretch of the works, one order: pipes by
  the metre and items by the unit at the catalogue prices, without the fittings, which belong to the
  joints between items). Items credentialed for BNDES FINAME financing show their code.

### 18.1 Valve wiring

Module `electrical.dart`, conventional wiring of 24 V AC solenoids: every valve has a station
conductor from the controller and all valves share one common (return) conductor laid along the
same routes. The wire routes form a graph (vertices within the connection tolerance merge; a
controller or valve on a vertex or on a route becomes a node, splitting the route there); the
shortest path (Dijkstra) from every controller reaches the valves, each valve goes to its nearest
controller and the stations are numbered by distance.

While valve *v* opens it draws the inrush current I_in; the other valves of its system flow are
already on and draw the holding current I_h. The voltage at the solenoid is

  U_v = U_c − I_in · r_s · L_v − Σ_{e ∈ path(v)} I_e · r_c · ℓ_e,

where U_c is the controller output, r_s and r_c the resistance per metre of the station and common
conductors, L_v the route length to *v* and, for every stretch *e* of the common on the way, ℓ_e its
length and I_e the current of the valves of the flow beyond it (I_in for *v*, I_h for the others).
Lengths include the slack allowance (10 % by default). The design picks, for every controller, the
common size and the station size of every valve with the **lowest cost** such that U_v ≥ U_min
(20 V by default) for every valve in every flow it belongs to: for each candidate common, each
valve takes the cheapest station wire that keeps its voltage (the voltages do not depend on the
other valves' station wires), and the cheapest feasible combination wins. When no wire can serve a
valve, the thickest is kept and the valve is reported. Example (checked in the tests): routes of
50, 150 and 200 m with 1 mm² copper (18.1 Ω/km), three valves of one flow, 0.37 A inrush and 0.22 A
holding, 10 % slack: the farthest valve gets 24 − 1.47 − 2.13 ≈ 20.4 V.

- **Valve-in-head stations** are stations like zone valves, after the zone valves of their
  controller (the one that reaches most of their heads), with the solenoids of their heads in
  parallel: the station conductor follows the routes from the controller to every head (the union
  of their paths) and on every stretch carries the inrush current of all the heads beyond it, as
  the common does; the voltage is computed at every head and the station takes the lowest. A head
  that no route reaches is reported unwired, the other heads of its station still wired.
- **Master valves** on the mainline are driven by the controller's master-valve output (station 0):
  they are on, holding, with every group of zones of their controller.
- The station count of a controller includes its valve-in-head stations; more valves than
  stations raises `elec_stations`, more valves on at once than the controller allows
  `elec_simultaneous`.

### 18.2 Automatic wire routes

Module `wire_routing.dart`: the wires are laid along the pipe trenches. The mainline and zone pipes
(laterals and tapes never) become a graph: vertices within the tolerance (0.1 m) are one node, and a
pipe ending on another or crossing it joins it there. Every controller, zone valve, master valve and
pump-start relay is attached at the nearest point of a pipe, through a short stub when it is off the
pipes (stubs over 30 m are reported); each valve goes to the controller nearest along the trenches,
and every controller's routes form a tree:

- **shortest paths** (the default for conventional wiring, where every valve has a station conductor
  of its own): the union of the shortest paths from the controller to its valves, a shortest-path
  tree (Dijkstra 1959), so every station conductor is as short as the trenches allow;
- **Steiner** (for a two-wire path, where only the route length counts): the shortest-path heuristic
  for the Steiner tree in graphs (Takahashi & Matsuyama 1980): the tree grows from the controller by
  the shortest path to the nearest valve not yet on it, at most twice the optimum length.

The trees come back as polylines sharing their end vertices, with the valves on their vertices, so
the wiring designs of sections 18.1 and 18.3 connect them. The master valve and the pump-start relay
take stations after the zone valves (or the controller's dedicated terminals); all the heads of a
valve-in-head station go to one controller (the nearest to most of them) and take one station
(tests "shortest paths along the trenches, stations by distance", "a Steiner-like tree for a
two-wire path is shorter than the shortest paths").

### 18.3 Two-wire systems

Module `two_wire.dart`. One pair of conductors leaves the controller and runs along the routes past
every valve; a decoder spliced on the pair at a valve drives the solenoids of 1, 2, 4 or 6 stations,
the valves within the reach of a solenoid cable from it (30 m along the routes). The pair always
carries the idle current of every decoder and, while stations run, their solenoid currents. Both
conductors carry the current, so the drop along a stretch of the path is ΔU = I·2·R'·L, with I the
current of everything beyond the stretch (Ohm's law around the loop) and L the cable length (route
plus slack). For every controller the design takes the cheapest wire of the list (the thinnest on a
tie) that keeps every decoder with a running station at or above the minimum voltage while each
station of a system flow opens (inrush) with the other stations of the flow holding; valves in no
flow run alone, and without flows every valve runs at once, as in the hydraulic design. Because the
drops grow with the length, the largest distance a wire allows is the layout scaled until the worst
decoder reaches the minimum. Defaults are orders of magnitude, to be replaced by the data sheets: 34 V
on the path, at least 24 V at a decoder, 1 mA idle current per decoder, and the solenoid currents of
the design parameters taken on the line (on the safe side: a decoder converts the line power and
draws less at the higher voltage). Grounding: a surge arrester with a ground rod at the controller,
then every 12 decoders or 150 m of path, whichever comes first, and at every end of the path, a rule
of thumb of installation guides, configurable. The heads of a valve-in-head station are points of
the path like zone valves, with decoders at the heads as two-wire practice puts them on turf; a
decoder output drives up to two solenoids of one station in parallel, and when a station opens the
inrush of all its heads loads the pair at once (tests "voltage along the pair by hand, the cheapest
wire that keeps 24 V", "grounding points: every 150 m or 12 decoders, the controller and the ends").

### 18.4 Quote and economics

Module `proposal.dart`. The quote prices the bill of materials with a sale margin, adds labour (a
share of the materials cost), the excavation of the trenches, free lines (services, travel,
commissioning), a discount, taxes on the discounted subtotal and freight. The trenches of the buried
pipes are grouped by use and diameter: width as set, or the outside diameter plus 0.2 m (at least
0.3 m); depth the burial depth of the pipe axis plus half the diameter plus the bedding. Lines without
a price are counted and reported.

The **payback** of an investment I that returns a yearly benefit B while it costs C (energy) to run
over n years at the discount rate r: simple payback I/(B − C); net present value
NPV = −I + Σ_{y=1..n} (B − C)/(1 + r)^y; internal rate of return the r that makes NPV = 0, by
bisection (none when the yearly net is not positive). The **construction schedule** lists the tasks
with work to do (staking out, trench excavation, pipe laying, backfill, valves and devices, wiring,
laterals and tapes, emitters, pump and filter station, pressure test and flushing), each lasting its
quantity over the output of a crew per working day (typical figures for a small crew with a
trencher, which the project may change) divided among the crews, each starting when the work it
follows has started (trenches, pipes and backfill a day apart; valves, wiring, laterals and emitters
once the buried pipes are laid; the pumping station in parallel; the test at the end). For Brazilian
projects the report gives the category of the environmental licensing of Resolution CONAMA 284/2001
(annex) by the irrigated area and the method, informative only (sprinkler: below 100 ha A, up to
1 000 ha B, beyond C; micro-irrigation: 500 and 1 000 ha; surface: 50 and 100 ha), since the validity
of the resolution and the rules of each state agency must be checked.

---

## 19. Automatic layout

The automatic design tools draw what a designer would otherwise place item by item: heads over a
lawn, zones by flow, valves and pipes, blocks of laterals over a field, rings round trees, sports
and golf layouts and the pivot that fits a field. They produce ordinary entities, which the
designer sizes and analyses like any drawing, and every choice breaks ties by item index, so the
same input always gives the same layout.

### 19.1 Landscape heads

Module `auto_layout.dart`, after landscape and sprinkler design practice (Irrigation Association,
*Landscape Irrigation Best Management Practices*, 2014; Keller & Bliesner 1990, chapters 5 and 6;
NRCS NEH 623 chapter 11). The irrigated region is the outline minus its exclusions (buildings, beds,
paths, which may lie inside the outline, cross it or overlap each other), held as closed loops with
the region to their left.

- **Spacing**: head to head (spacing = wetted radius), a percentage of the wetted diameter (50 % is
  head to head; Keller & Bliesner 1990, table 5.2, ask for 50 to 65 % by wind) or typed. The
  reference full-circle nozzle is one that comes with **matched part circles** (a quarter and a half
  circle nozzle of that arc within 5°, throwing about as far, within 15 %, with the flow of its share
  of the arc, within 20 %) and whose radius does not exceed what the widest part of the area allows
  (heads on opposite edges throw to each other): the largest such radius, so the fewest heads.
- **Placement**: heads in the corners first (a boundary vertex turning more than 25°; a corner
  sharper than 45° gets no head of its own, the first heads of its two edges water the tip), then
  along every edge at no more than the spacing, then on a square or triangular grid inside (rows
  along the longest edge of the outline by default; a triangular grid has rows 0.866 spacings apart,
  alternate rows shifted half a spacing), kept half a spacing from the edges. A strip narrower than
  0.6 spacings gets one row of edge heads; heads are never closer than 0.4 spacings; a small
  exclusion (a perimeter under three spacings: a tree ring, a small bed) gets no heads round it, the
  heads keeping out of it and throwing over it.
- **Coverage**: wherever a point of the area is farther than 0.72 spacings from every head (a
  square grid's farthest point is at 0.707, a triangular one's at 0.577, whose limit is 0.66) a head
  is added, the largest empty circle first: every raster cell near or beyond reach climbs to the
  farthest point around it, a vertex of the Voronoi diagram of the heads. Then four rounds of
  centroidal relaxation move the interior heads near irregular edges to the centroid of the cells
  nearest to them, when that keeps them inside, away from the boundary and from the other heads.
- **Arcs and nozzles**: every head waters the sector that opens into the area (counter-clockwise
  from its orientation, as the painter and the densogram draw it), and a part circle gets the nozzle
  whose flow is proportional to its arc, q = q_full·arc/360, so that every head applies the same depth
  (matched precipitation): the flow closest on a log scale, the radius not shorter than 0.9 of the
  reference. `layout_mp_mismatch` reports a nozzle that misses its flow by more than 15 %,
  `layout_radius_short` one that throws too short. A family without matched part circles
  (micro-sprinklers, impact sprinklers) gets full circles only, on a grid inset half a spacing.
- **Evaluation**: the uniformity of the result by the densogram model of section 9.1 (Christiansen
  CU, low-quarter DU, scheduling coefficient, dry share) and the water thrown outside the area.

The largest inscribed circle of a region (used here, by the templates and by the pivot fit) is its
pole of inaccessibility, found by the quadtree search of Garcia-Castellanos & Lombardo (2007).
Tests: "rectangle: corners, edges and interior head to head, CU above 94 %", "L-shapes: both arms
treated alike, every point within reach, CU above 85 %", "a house in the lawn: three-quarter
circles at its corners, nothing inside, CU above 85 %", "quarter, half and full circles take the
nozzles of their share of the flow".

### 19.2 Zoning by flow

Module `zoning.dart`: heads (or drip areas) are grouped into valve zones whose flow stays within the
valve and supply limits, never mixing emitters that apply water at different rates, each zone compact
and in one piece and the zones of a class with balanced flows (Irrigation Association 2014, practice
"group emitters with like precipitation rates"; Keller & Bliesner 1990, chapter 17). The precipitation
classes are spray (a sprinkler throwing less than 6.5 m), rotor, micro-sprinkler, bubbler, drip and
gun. The grouping is a capacitated region growing on a nearest-neighbour graph (8 neighbours; items
farther apart than 2.5 typical neighbour distances are not neighbours, so separate lawns get separate
zones): as many seeds as the flow asks for, spread by farthest-point sampling; the least loaded zone
takes, one at a time, the unassigned neighbour nearest to its seed, stopping at the mean zone flow of
its class plus 10 % before the others catch up; seeds move to the middle of their zones and the growth
repeats (three rounds); zones lighter than half the mean merge into a neighbour when both fit; and a
last pass moves boundary items from heavier to lighter neighbouring zones while both stay in one
piece (tests "zones within the flow, contiguous, compact and balanced", "head types and
precipitation classes never share a zone; separate lawns get their own zones").

### 19.3 Valves and pipe routes

Module `routing.dart`. Every zone gets a valve (on a given mainline, next to the zone on the side of
the point of connection, in a manifold at the point of connection, or where the user put it; the
smallest catalogue valve whose flow range holds the zone flow) and zone pipes joining every head to
it as a tree; then a mainline tree joins the point of connection (water supply or pump) to every
valve. The pipes are polylines with a vertex at every head, so the network builder connects each
head; they keep 0.3 m clear of the heads and valves of the other zones (which would join two zones)
and go round buildings and other exclusions by the shortest path through the corners of the
exclusions pushed out by 0.5 m (a visibility graph).

The zone trees use the Prim–Dijkstra trade-off of Alpert, Hu, Huang, Kahng & Karger (1995): every head
joins the tree where c·(path length from the valve) + (pipe length) is least, c = 0 giving the minimum
spanning tree (the least pipe) and c = 1 the shortest-path tree (the least friction to the farthest
head); c = 0.25 keeps the pipe short without long serpentine paths. Candidate pipes go from every head
to its ten nearest neighbours, and a bias makes a diagonal pipe 15 % dearer at 45° than one along or
across the rows, so the laterals follow the rows, the rectilinear layout of practice. The mainline is
a greedy Steiner tree: the valve nearest to the tree joins it at the nearest point of any of its pipes,
with a tee there (Takahashi & Matsuyama 1980) (tests "every zone is a tree from its valve with a vertex
at every head", "pipes go round a building").

### 19.4 Fields, blocks and tree rings

- **Field subdivision** (`field_subdivision.dart`): an agricultural field is cut into irrigation
  blocks no larger than an area, or than the flow a block may draw given the emitter flow per
  hectare, as strips along the rows or as a grid that also limits the length of the laterals (twice
  as long with the submain in the middle), with service roads between the blocks (4 m by default,
  which also keep the tape ends of two zones apart) and a minimum block width (10 m). The cuts give
  the blocks equal net areas: the field area between two cuts is integrated exactly, roads taken out,
  and every cut is placed by bisection, so the shifts draw the same flow (Keller & Bliesner 1990,
  chapters 17 and 21; NRCS NEH 623 chapter 7). A concave field may fall in several pieces per strip.
  Every block gets the side of its submain (towards the point of connection, or in the middle) and
  the position of its valve, ready for the block generator (tests "strips of equal area within the
  limit, roads between them", "a grid keeps every lateral within the limit").
- **Tree rings** (`tree_rings.dart`): around every tree of a planting grid inside an area (plant ×
  row spacing with offsets, trees kept a ring radius from the outline) or of surveyed positions
  (grouped into rows along the row direction), a ring of dripline of a radius (0.6 m by default) or a
  number of drippers on a small ring pipe (4 by default), joined to a lateral along the row; the
  laterals start from a submain across the rows with the zone valve. A ring of emitters round the
  trunk wets the root zone of a young tree evenly on every side and away from the trunk (Keller &
  Bliesner 1990, chapters 15 and 16; NRCS NEH 623 chapter 7). Each ring is drawn as two halves from
  the point where the lateral enters it to the point where it leaves it, both vertices of the
  lateral, so the network builder joins it at both ends (test "every ring is joined to its lateral at
  both ends, round its tree").

### 19.5 Sports and golf templates

Module `templates.dart`, after sports turf and golf course practice (Keller & Bliesner 1990,
chapter 5; Irrigation Association 2014; the United States Golf Association recommendations for the
green and its collar). Each template returns the heads with their arcs and matched-precipitation
nozzles for a head family and the uniformity over the turf.

- **Football pitch** (105 × 68 m, the size IFAB Law 1 recommends for international matches): rows
  along the touchlines, the outer two on the touchlines with half circles, quarter circles in the
  corners and half circles on the goal lines. Five rows are 17.0 m apart and need a radius of at
  least 17 m (with 18 m: 7 heads a row, 17.5 m apart, 35 heads); four rows are 22.7 m apart
  (R ≥ 23 m; with 24 m: 6 a row, 21 m apart, 24 heads); three rows are 34 m apart (R ≥ 34 m, large
  rotors or guns; with 35 m: 4 a row, 35 m apart, 12 heads). Along a row the heads stand no farther
  apart than the radius.
- **Running track infield**: the area inside the kerb of a standard 400 m track (36.50 m kerb radius,
  84.39 m straights) laid out as a lawn with rows along the straights.
- **Golf green**: rotors on a ring a set-back outside the collar, no farther apart than their
  radius, each a part circle opening onto the green over the angle the green spans from it plus a
  margin onto the collar; nothing inside the putting surface.
- **Tee**: a rectangle laid out as a lawn. **Fairway**: rows parallel to the centreline 0.866
  spacings apart, heads one spacing apart along each, alternate rows shifted half a spacing
  (equilateral triangles, head to head); full circles, or half circles on rows along both edges.

Tests "3, 4 or 5 rows: head to head, part circles on the lines, CU above 93 %", "golf green: rotors
outside the collar throwing onto the green, CU above 88 %".

### 19.6 Pivot fit

Module `pivot_fit.dart`: the largest full-circle centre pivot that fits a field avoiding its
obstacles, and the part-circle pivot (centre, radius and sector) that irrigates the most area inside
the field. The machine length is a sum of standard spans (34.4, 41.8, 48.8, 54.9 and 62.2 m, that is
113 to 204 ft; at most two span lengths, the fewest first) plus an overhang (0 to 25.9 m), and the
wetted radius is the machine length plus the throw of the end sprinkler or gun (Keller & Bliesner
1990, chapter 14; NRCS NEH 623 chapter 11). The full circle stands at the centre of the largest
inscribed circle (the pole of inaccessibility of the field less its obstacles, point obstacles such
as a power pole with their clearance) with the longest machine whose wetted radius fits. For a part
circle, given a centre and a radius the sector is exact: every piece of the field outline or of an
obstacle within the radius blocks the directions it spans as seen from the centre, every point
obstacle the directions of its clearance circle, and the free directions between the blocks form
arcs that are either wholly inside the field or wholly outside; the widest arc inside is the sector
(narrower than 30° is not worth a machine). Centres are searched on a grid of 24 × 24 and at the
corners and edges of the field, where part-circle pivots often stand, then refined by a pattern
search (tests "an L-shaped field: a three-quarter circle round the inner corner beats the full
circle", "a rectangle: a sector from the edge waters more than the inscribed circle").

---

## 20. Vegetation in aerial imagery

Module `vegetation.dart` (Design → Automatic design → Detect vegetation in the image). Lawns, planted beds, trees
and shrubs are found in an aerial image, the base map on the screen or an aerial photo placed in the
drawing, and come out as outlines in world metres, ready to become the irrigated areas of a design.
It is plain image processing, linear in the number of pixels, run on the device: no service, no
network, no trained model. The dialog reminds the user that the imagery has terms of use.

1. **Working raster**: the image is averaged in blocks down to at most 1.2 million pixels (about
   1100 × 1100) and no finer than 5 cm on the ground: finer pixels add time, not accuracy, to the
   outline of an irrigated area, and the preview has to stay live on a phone. Transparent pixels
   (map tiles not loaded) carry no data and count as the edge of the image.
2. **Vegetation index**: the excess green ExG = 2g − r − b on the chromatic coordinates r = R/(R+G+B),
   g, b (Woebbecke, Meyer, Von Bargen & Mortensen 1995). In the code the sum R + G + B is damped by
   30 (of 765), so that the random hue of near-black pixels (deep shadow, compression noise) does
   not read as green, and the index is capped by twice the excess of green over blue,
   min(2G − R − B, 2(G − B))/(R + G + B + 30): turquoise pools, sky reflections and blue shadows on
   paving have green well above red (a high ExG) but no more green than blue, while leaves reflect
   clearly more green than blue (the cap never binds on them). A 3 × 3 median takes the noise out
   without moving the edges. ExG rather than VARI = (G − R)/(G + R − B) (Gitelson, Kaufman, Stark &
   Rundquist 2002): VARI divides by a difference that crosses zero on grey and bluish pixels (paving,
   roofs, shadows, water) and has to be clipped, so its histogram has no stable shape to threshold;
   ExG is bounded, linear in the chromatic coordinates and independent of the illumination level,
   and ExG thresholded by Otsu's method is the classic vegetation mask of RGB images (compared with
   the other colour indices by Meyer & Neto 2008).
3. **Threshold**: Otsu (1979) on the histogram of the index, the split that maximises the
   between-class variance; again below it when the class below is green too (a park or a golf course
   filling the view: two shades of grass); between two separate modes, the middle of the empty
   stretch. It is kept within 0.04 to 0.20 (a view that is all paving has a single mode, which Otsu
   would split; below the range grey and brown surfaces with a colour cast pass for vegetation, above
   it pale lawns are lost), plus the user's offset; Otsu's separability (between-class over total
   variance) tells when vegetation and the rest have no distinct colours.
4. **Clean-up**: a majority filter (the binary median: a pixel takes the class of most of its
   neighbours within 0.2 m, computed with box sums in linear time whatever the radius) removes specks
   and lines narrower than about that radius and fills gaps as narrow. Unlike an opening and a closing
   it does not move a boundary: along a ragged edge it adds as many pixels as it takes away, where an
   opening shaves the ones that stick out.
5. **Trees and shrubs against turf**: canopy is rough and darker — leaves and their shadows change
   the brightness from one decimetre to the next, while mown grass is even. The texture is the share
   of the brightness steps over 0.2 m, between vegetated pixels of a 1 m window, larger than a tenth of
   their brightness: relative, so a lawn in the shade of a building stays smooth, and a share rather
   than a mean, so the line of a shadow across a lawn (a few large steps among many small ones) is not
   texture; pixels of paving do not count, so neither is the edge of a lawn. A pixel is canopy when
   share/0.4 + 0.3·(100 − brightness)/100 passes 1 (brightness the mean luma of the window, 0–255;
   mown turf scores about 0 to 0.3 in the sun and 0.6 to 0.9 in deep shade, tree crowns 1.1 to 1.9);
   the user's bias moves the limit, and the canopy mask is cleaned by the majority of its vegetated
   neighbours within 0.3 m.
6. **Patches and holes**: the 8-connected components of every class kept, those under 5 m² left
   out; holes are the 4-connected rest of the image enclosed by a patch (paths, paving, buildings,
   pools, or a patch of the other class), those under 4 m² covered by the patch.
7. **Outlines**: marching squares walked round every patch and hole from its first pixel, saddles
   resolved by the connectivity so that the outlines of a patch and of its holes never cross, mapped to
   world coordinates through the four corners of the image (bilinear: exact for the rectangles of the
   base map view and of a placed image), smoothed without shrinkage by Taubin's λ|μ filter (Taubin
   1995; λ = 0.5, μ = −0.53: the staircase of the pixels goes, the area stays) and simplified by
   Douglas–Peucker (1973) with a tolerance of 0.25 m, halved until the polygon does not cross itself.
   Douglas–Peucker keeps vertices of the outline, so its chords cut the rounded corners and the
   polygon comes out a fraction of a pixel smaller all round (about 2 % of a lawn of 400 m²); an offset
   along the normals gives that area back.

An irrigated area has no holes: every patch becomes an area (named by its class, with agronomic
starting values: turf Kc 0.85 from FAO-56 table 12 for warm-season turf at mid season, a 0.3 m root
zone, sprinklers at the spray efficiency of the water budget and high water use; trees and shrubs Kc
0.6, 0.4 m roots, drip at its efficiency wetting half the ground and moderate water use), and every
hole that is paving, a building or water a closed polyline on the drawing layer, so that the automatic
head layout leaves it out. A hole filled by a patch of the other class kept is not repeated: that
patch is an area of its own, nested in the outer one.

**Accuracy on synthetic scenes** (`vegetation_test.dart`): a 48 × 36 m garden at 10 cm per pixel, with
the noise, texture and soft edges of a real image, holds a lawn of 384 m² with a 12 m² patio and a
tree, a lawn of 154 m² half in a building's shade, two tree crowns on paving with their shadows, bare
soil, a pool and a 2.25 m² green speck. The detection finds two lawns and three crowns; the lawns
within 2 % of their area (3 % net of the patio and the tree), the crowns within 8 % with their
centroids within 0.15 m, the patio within 5 % as an exclusion, the shaded half of a lawn kept as turf,
paving, soil, the pool and the shadows left out, the vegetated share within 5 % of the truth, and a
simplified outline within its tolerance of the raw one. A park filling the view (rough, a lush fairway
and a sand bunker) is split between sand and grass, not between the two greens, and an image of lawn
only gives one patch over the whole view.

What it cannot see: lawns in deep shadow or dry and straw-coloured (lower the threshold), lawn under
tree canopy (seen as canopy), the texture of crowns in soft, resampled imagery (seen as turf: move the
canopy limit), green water, artificial turf and green roofs (seen as vegetation); and the outlines
are only as good as the imagery (its date, resolution and fit to the drawing).

### 20.1 Crop rows

Module `crop_rows.dart` (Design → Automatic design → Crop rows from the image). Drip laterals in a row crop are laid
along the planting rows already in the field; the tool reads their direction, their spacing, how many cross the field,
how sure the reading is and, where the image shows them, the plant spacing along the rows and the canopy ground cover,
from the satellite base map or a placed aerial photo rendered north up with square pixels over the outline. It is plain
image processing on the device, linear in the pixels for every direction tried: no service, no trained model.

1. **Signal.** The pixels inside the outline and outside its holes that carry data form the mask. The colour is
   high-passed by subtracting its mean over a box of 1.25 × the widest spacing searched (only pixels of the field
   count), which removes the shading and the patches of the field and keeps the stripes, divided by its RMS over the
   same box (floored at a quarter of the field's) so that a dark orchard and a bright bare patch weigh alike, and
   projected on its first principal component (Pearson 1901), the colour axis along which the image varies most once
   the field-scale changes are gone: green against red soil in one field, dark canopy against a lighter cover crop in
   another. Its sign makes the canopy positive (the projection correlates with the excess green of section 20, less half
   the standardised brightness); values beyond four robust standard deviations (1.4826 × the median absolute deviation)
   are clipped, so a road or a roof does not rule the result.
2. **Direction, coarse.** The field is cut into square blocks of about 3.5 × the widest spacing; for every direction θ
   (steps of at most 1°) the pixels of each block are binned by their distance across θ, a discrete Radon projection
   (Radon 1917), and the share of the variance the bins explain, R²(θ) = between-bin over total sum of squares, is
   averaged over the blocks. Straight stripes along θ make the bins differ; any other direction averages them out. The
   spacings searched start at three pixels of the imagery, below which the period is the grain of the image itself.
3. **Spacing, coarse.** The autocorrelation of the block profiles at that direction, averaged over the blocks; the first
   peak that reaches half of the highest between the closest and the widest spacing (the first, not the highest: the
   profile of narrow rows peaks at every multiple of the spacing). A peak whose half or third lag correlates at least
   half as well is a multiple of rows closer than the range, and no rows are read.
4. **Fine values.** R² of one profile across the whole field on a grid round the coarse direction, the step a quarter
   of the angular width of the peak (spacing over the length of the rows): about 0.1° over a field a hundred spacings
   long. The spacing is then searched within ±6 % on the power of the Hann-windowed discrete Fourier transform of the
   whole-field profile, its peak refined by a parabola through the logarithm of the power (sub-bin interpolation; Quinn
   1994 for the reasoning), and the phase of that harmonic places the rows. When the whole-field profile repeats far
   less than the block profiles, the rows bend: the coarse values stand and the result says so. Which band of a
   period is the crop is the greener and darker one, save when both are vegetation and the other is clearly the wider
   (a closed canopy whose narrow alleys lie in its shade): then the wider.
5. **Rows, plants and cover.** Lines at the spacing and phase found over the whole outline, clipped to it and to its
   holes; a line counts as a row when at least max(1 m, half a spacing) of it lies in the field. The plant spacing is the
   first peak, between max(4 pixels, 0.25 m) and 1.2 × the row spacing, of the autocorrelation of the signal sampled
   along the centre of the rows and averaged over at most 150 rows (independent of the phase of each row); hedgerows have
   none, and the plant spacing is then unknown. The ground cover is the share of the field above the Otsu (1979)
   threshold of the signal smoothed over 3 × 3 pixels, given only when its histogram has two populations by the
   bimodality coefficient BC = (skewness² + 1)/(excess kurtosis + 3) > 5/9 (SAS Institute 1990; Pfister, Schwarz,
   Janczyk, Dale & Freeman 2013; 5/9 is the value of a uniform distribution): the canopy share of a vertical image, the
   usual stand-in for the ground shaded at noon of FAO-56 (Allen et al. 1998).

**Confidence** = angular prominence × periodicity: (1 − median R² over all directions ÷ the largest R²) times the
autocorrelation of the profile at the spacing. No published benchmark of this measure exists: the limits of clear rows
(0.35) and of an uncertain reading (0.15) were set on the synthetic fields of `crop_rows_test.dart` and on real imagery
checked during development (almond orchards and coffee read with confidences of 0.67 to 0.96, vineyards and olive
hedgerows at their spacings; a town, a pasture, a forest, a harvested pivot and a coarse overview gave confidence 0). A field larger than 2.5 million pixels at the pixel size
needed is read on a window in its middle and its rows extended over the whole field.

**Accuracy on synthetic fields**: nine fields from 0° to 178.9° and 2 to 10 m are read within ±1° and ±3 % (in fact
within 0.1° and 0.2 %), the lines on the canopy bands within 0.08 of a spacing, the row count within one and the ground
cover within 0.05, also with heavy noise, 30 % of the plants missing, an L-shaped outline with a hole and coordinates of
millions of metres. It assumes rows straight over the area, evenly spaced, visible at about three pixels per spacing and
an image of one date; shadows count as canopy.

---

## 21. Agronomy

Modules `agronomy.dart` (the requirement of every irrigated area in the design), `climate.dart`,
`crops.dart`, `soils.dart`, `effective_rain.dart`, `irrigation_requirement.dart`,
`climate_online.dart`, `solar_pumping.dart`, `wetted_bulb.dart` and `water_budget.dart`, based on
FAO-56 (Allen, Pereira, Raes & Smith 1998) and the FAO irrigation manuals.

### 21.1 Daily requirement and the controller programme

- ETc = Kc · ETo (mm/day), with Kc from the crop curve of section 21.3 or, without a crop of the
  table, the typical mid-season Kc offered per crop.
- Readily available water RAW = AWC · Z_r · f (mm), with AWC in mm per metre of soil, root depth
  Z_r in m and allowable depletion fraction f (MAD).
- Irrigation interval I = ⌊RAW / ETc⌋ days (at least 1).
- Net depth per event = ETc · I; gross depth = net / efficiency (0.90 drip, 0.75 sprinkler, 0.85
  pivot as usual values; the area defines its own).
- Zone application rate PR = flow / area; time per event
  T = gross depth · wetted fraction / PR; volume per event = gross depth · area · wetted fraction.
  The water-requirement table applies the same wetted fraction to the daily volume and hours, so
  both tables agree.
- **Controller programme**: every system flow runs for the longest event time of the areas its
  zones (and valve-in-head stations, through the areas holding at least a fifth of their heads)
  irrigate, every interval of days, in sequence from the day's start hour (or at their own hours),
  in an N-day calendar exportable as CSV; flows that run every few days start on staggered days so
  that they do not pile up, and the peak pumping hours per day go to the report.

### 21.2 Reference evapotranspiration

`fao56Eto` computes the grass reference ETo with the FAO Penman-Monteith equation (FAO-56 eq. 6,
the Box 11 calculation sheet), daily or for the mean day of a ten-day period or month, with every
term of chapter 3: pressure (eq. 7) and psychrometric constant (eq. 8), saturation and actual vapour
pressures (eqs. 11 to 19, from the dew point, a psychrometer or the relative humidity),
extraterrestrial radiation (eqs. 21 to 25, the sunset hour angle clamped so that polar day and night
work), daylight hours (eq. 34), solar radiation from sunshine (Angström, eq. 35), clear-sky
radiation (eqs. 36 and 37), net radiation (eqs. 38 to 40), monthly soil heat flux (eqs. 43 and 44)
and the wind at 2 m from another height (eq. 47). Missing data follow FAO-56 chapter 3: the dew
point taken as Tmin (eq. 48), the radiation from the temperature range by Hargreaves' formula
(eq. 50, k_Rs 0.16 inland and 0.19 on the coast, limited to the clear-sky radiation) or the island
formula (eq. 51), 2 m/s when the wind is missing, and at least 0.5 m/s in eq. 6; the estimates used
are listed with the result. `fao56MonthlySeries` gives the twelve months at the 15th, the soil heat
flux from the neighbouring months (the year taken as cyclic), and the Hargreaves-Samani equation
(eq. 52) is the alternative. The tests reproduce the worked examples of FAO-56: Example 17 (monthly
ETo in Bangkok in April, 5.72 mm/day), Example 18 (Uccle on 6 July, 3.88 mm/day against the 3.9 of
the book) and Example 20 (Lyon in July from Tmax and Tmin only, 4.56 mm/day), with their
intermediate terms.

**Climate from the internet** (`climate_online.dart`): monthly normals are built from the daily
series of the Open-Meteo historical weather API (the ERA5 and ERA5-Land reanalyses from 1940, about
five days behind real time: ETo, rain, temperatures, wind, radiation, humidity and dew point) or the
NASA POWER daily point API (MERRA-2 meteorology and CERES/FLASHFlux radiation from 1981; its
climatology endpoint gives extreme rather than mean monthly temperatures, so the normals come from
the daily one). Both are keyless and answer cross-origin requests. The download is polite: requests
one after another within a budget of calls per minute (Open-Meteo counts a request with more than 10
variables or more than two weeks of data as several calls, variables/10 × days/14), retries, waits
on HTTP 429 and cancellation between requests. A month of a year counts when enough of its days have
rain and temperatures; daily ETo is computed by Penman-Monteith wherever temperatures and radiation
exist; the dependable rain is the monthly total exceeded in four years out of five (Weibull plotting
positions m/(n + 1), linear between ranks). The free Open-Meteo API is for non-commercial use and its
data are credited as CC BY 4.0; NASA asks for its acknowledgement, which the program shows.

### 21.3 Crops and growth stages

`crops.dart` holds a table of the crops designers meet most, every entry citing the FAO-56 rows it
uses: the lengths of the initial, development, mid-season and late stages (table 11), Kc ini, Kc mid,
Kc end and the maximum height (table 12), the basal coefficients Kcb (table 17), the root depth and
the depletion fraction p for ETc ≈ 5 mm/day (table 22) and the salt tolerance of FAO-29 Rev. 1 table
4 (Ayers & Westcot 1985; after Maas & Hoffman 1977 and Maas 1984). The single crop coefficient curve
is Kc ini through the initial stage, a straight line to Kc mid over the development stage, Kc mid
through the mid-season and a straight line to Kc end over the late season (FAO-56 eq. 66); the mean
over a month or a ten-day period is the exact integral of the piecewise-linear curve, so a decade
gives the graphical value of FAO-56 figure 36. Kc mid and Kc end are adjusted for a climate other
than RHmin = 45 % and u₂ = 2 m/s by Kc + [0.04(u₂ − 2) − 0.004(RHmin − 45)]·(h/3)^0.3 (eqs. 62 and 65,
u₂ limited to 1–6 m/s, RHmin to 20–80 % and h to 0.1–10 m; Kc end only above 0.45); Kc ini comes from
the mean interval between wettings and the infiltrated depth (Annex 7, eqs. 7-1 to 7-4, eq. 59
between light and heavy wetting, eqs. 60 and 61 for partial wetting); sparse cover reduces Kcb mid
by eq. 98; p is adjusted to the ETc rate, p = p_table + 0.04·(5 − ETc), limited to 0.1–0.8. For
localized irrigation the reduction factor Kr for the ground cover GC is that of Keller & Bliesner
(1990), Kr = 0.1·√Pd with Pd the cover in per cent (applied by FAO as Td = Ud·0.1·√Pd), or one of
the three FAO tabulates (Savva & Frenken 2002, Irrigation Manual Module 9, table 1): Keller & Karmeli
GC/0.85, Freeman & Garzoli GC + 0.5·(1 − GC) from 50 % cover, and Decroix 0.1 + GC. A perennial cycle
covers the whole year and restarts on every anniversary of its green-up (tests "Example 28: Kc on
days 20, 40, 70 and 95 for dry beans", "Box 15: Kc mid adjusted for RHmin 30 % and u2 2.2 m/s",
"Example 41: 30 % cover, 2 m tall, Kcb full 1.15 gives Kcb mid 0.75 (eq. 98)").

### 21.4 Soils and effective rain

`soils.dart` gives the twelve USDA texture classes their water and intake properties, each field from
its source: the available water capacity of NRCS NEH Part 652 (Irrigation Guide, 1997) table 2-1
(1 in/ft = 83.3 mm/m); field capacity, wilting point, porosity and saturated conductivity from the
means of Rawls, Brakensiek & Saxton (1982); the FAO-56 table 19 ranges and readily and total
evaporable water; the basic intake rate and the allowable surface accumulation by slope of the
Irrigation Association SWAT testing protocol for climatologically based controllers (2008) as the US
EPA WaterSense specification adopts it; the sprinkler intake range of NEH 652 table 2-6; and the
maximum sprinkler application rate by slope of the USDA-SCS NEH Section 15 chapter 11 (1983) table
11-4, with its adjustments for bare soil (−25 %) and grass (+25 %). A texture class also comes from
the sand and clay percentages by the boundaries of the USDA texture triangle (Soil Survey Manual,
Handbook 18).

Effective rain (`effective_rain.dart`), on monthly totals in mm, prorated by days for a part of a
month:

- USDA-SCS (1970) Technical Release 21, as in NEH Part 623 chapter 2 (eqs. 2-84 and 2-85, table
  2-43): Pe = SF·(0.70917·Pt^0.82416 − 0.11556)·10^(0.02426·ETc) in inches, with the soil water storage
  factor SF = 0.531747 + 0.295164·D − 0.057697·D² + 0.003804·D³ (D the usable storage, the net depth
  of application in inches; SF = 1 at D = 3 in), never more than the rain nor the ETc;
- USDA-SCS simplified, as in FAO Irrigation and Drainage Paper 46 (Smith 1992):
  Pe = P·(125 − 0.2·P)/125 for P ≤ 250 mm, 125 + 0.1·P above;
- FAO/AGLW dependable rain (FAO-46): Pe = 0.6·P − 10 for P ≤ 70 mm, 0.8·P − 24 above;
- the FAO empirical formula of Brouwer & Heibloem (1986), Training Manual No. 3:
  Pe = 0.6·P − 10 for P < 75 mm, 0.8·P − 25 above;
- a fixed share of the rain (0.7 to 0.9 usual).

Tests reproduce the worked example and table 2-43 of NEH 623 and the examples of the FAO training
manual.

### 21.5 Requirement by crop, month and stage

`irrigation_requirement.dart` builds the table a water permit asks for ("net and gross depth by crop
and by period"): per crop cycle and per month of a typical year, or per period the user defines,
ETo, Kc, ETc, effective rain, net depth, leaching, gross depth, readily available water, maximum
interval, depth and hours per event and volumes. Every crop cycle keeps its own Kc and rows; Kc is
never averaged across crops, and only depths and volumes are added up.

- ETc,loc = Kr·ETc for localized irrigation (Keller & Bliesner 1990; FAO Module 9 eq. 2);
- net = ETc,loc − Pe (plus, for paddy rice, the percolation, the initial saturation and the water
  layer of Brouwer & Heibloem 1986, section 4.4);
- leaching requirement LR = ECw/(5·ECe − ECw) for surface and sprinkler irrigation (FAO-29 eq. 9, ECe
  for the chosen yield potential on the straight line of FAO-29 eq. 10 and table 4), and
  LR = ECw/(2·max ECe) for high-frequency drip (Keller & Bliesner 1990, max ECe the zero-yield ECe);
  none when 5·ECe ≤ ECw (the water is too saline for the crop);
- gross = net/(Ea·(1 − LR)), or, by the reasoning of FAO-29 Example 3 (application losses already
  leach), max(net/Ea, net/(1 − LR));
- TAW = AWC·Zr (FAO-56 eq. 82), RAW = p·TAW (eq. 83) with p adjusted to ETc, times the wetted fraction
  Pw for localized irrigation; maximum interval = RAW / net daily depth.

Tests: "Example 3: maize, river water of 1.2 dS/m", "irrigation frequency at peak demand (Example 6):
2 days, 434 litres per tree", "FAO Training Manual 3, section 4.4: paddy rice in April needs 313 mm".

### 21.6 Solar pumping

`solar_pumping.dart` sizes a photovoltaic pumping system for the daily water volume of every month,
in the terms of IEC 62253:2011 (PV generator, power conditioner, motor-pump set, total dynamic head,
daily water volume). The daily hydraulic energy is E_h = ρ·g·H·V; the array energy is
E = P·H_T·PR/G_stc, with the reference yield H_T/G_stc (peak sun hours, G_stc = 1 kW/m²) and the
performance ratio PR of IEC 61724-1 from the soiling, wiring, mismatch and other losses and the
temperature factor 1 + γ·(T_c − 25), γ ≈ −0.004/°C for crystalline silicon, with the cell temperature
by the NOCT method T_c = T_a + (NOCT − 20)·G/800 (Duffie & Beckman, section 23.3). The irradiation on
the tilted array comes from the monthly mean on the horizontal by the isotropic sky model of Liu &
Jordan, H_T = H·[(1 − H_d/H)·R_b + (H_d/H)·(1 + cos β)/2 + ρ_g·(1 − cos β)/2] (Duffie & Beckman eq.
2.19.1), the monthly diffuse fraction of Erbs, Klein & Duffie (1982) (K_T limited to 0.3–0.8) and R_b
the ratio of the daily extraterrestrial radiation on the tilted surface to that on the horizontal on
the mean day of the month (Klein 1977), integrated numerically over the day so that any orientation
works (equal to the closed form for equator-facing surfaces, test "the numerical Rb equals the
closed form for equator-facing surfaces"). The array is sized for the critical month (the darkest
month with the largest need), the volume it lifts in every month is reported and the energy is
compared with grid power; the irradiation comes from the climate download (MJ/m²/day ÷ 3.6 =
kWh/m²/day).

### 21.7 Wetted bulb and wetted area

`wetted_bulb.dart`: the wetted soil under a drip emitter by Schwartzman & Zur (1986), restated by
Cruz-Bautista et al. (2016): width (diameter) W = 1.82·V^0.22·(K_s/q)^−0.17 and depth
Z = 2.54·V^0.63·(K_s/q)^0.45, with W and Z in m, the applied volume V in m³, the saturated conductivity
K_s in m/s and the emitter flow q in m³/s. The fit comes from two soils (K_s ≈ 2.5·10⁻⁶ and
2.5·10⁻⁵ m/s) and two surface point sources (4.3 and 20 L/h); outside that range it extrapolates and
later studies found errors of tens of per cent, so field tests take precedence. The table of Keller &
Bliesner (1990) gives the wetted width of a 4 L/h emitter by texture, soil depth and stratification
(as reproduced by FAO Module 9, table 4), and the percentage of wetted area is
Pw = 100·Np·Se·W/(Sp·Sr) (Module 9 eq. 10), the emitter spacing that counts limited to Se' = 0.8·W so
that separate wetted circles are not taken for a continuous strip (tests "a 4 L/h emitter applying 8 L
in a loam (Ks 13.2 mm/h)", "eq. 10: 5 emitters 1.2 m apart wetting 2.26 m on 6 × 6 m trees give
38 %").

### 21.8 Landscape water budget and cycle and soak

`water_budget.dart` follows the California Model Water Efficient Landscape Ordinance (MWELO,
California Code of Regulations, Title 23, §§ 490–495, 2015 revision, Appendix B): the maximum applied
water allowance MAWA = ETo·0.62·[ETAF·LA + (1 − ETAF)·SLA] (US gallons a year with ETo in inches a
year and areas in ft²; ETAF 0.55 for residential and 0.45 for non-residential areas, LA the whole
landscape including the special landscape areas SLA) and the estimated total water use
ETWU = ETo·0.62·Σ(ETAF·HA) over the hydrozones, ETAF = PF/IE for regular areas (IE = 0.75 for overhead
spray and 0.81 for drip) and 1.0 for special areas; plant factors by the WUCOLS ranges (very low
0–0.1, low 0.1–0.3, moderate 0.4–0.6, high 0.7–1.0). In metric units ETo in mm and areas in m² give
litres (1 mm on 1 m² is 1 L) without a conversion factor. **Cycle and soak** splits a run that would
run off: the longest run before runoff is R_t = 60·ASA/(PR − IR) minutes and the next cycle starts no
earlier than D_a/IR after the previous one started (D_a the depth per cycle), by the SWAT protocol
(section 4.3), the intake rate IR and the allowable surface accumulation ASA coming from the soil and
slope of section 21.4 (test "1.5 in/h sprays on a clay loam with 5 % slope applying 0.5 in").

### 21.9 Climate risk over the years

Modules `climate_risk.dart` and `climate_risk_stats.dart` (Design → Agronomy → Climate risk over the years). A system is
sized for one figure, the ETo of the peak month of the normals or a typed peak ETo; the analysis runs the system as
designed through every real year of a daily series of the site instead.

- **Weather**: the NASA POWER daily point series (MERRA-2 meteorology and GEWEX SRB / CERES radiation, every parameter
  from 1984, when its solar radiation starts) or the daily series kept with the site climate. The ETo of each day is
  the FAO Penman-Monteith of section 21.2 (`dailyPenmanMonteith`), missing terms estimated as FAO-56 chapter 3 says.
  A day without ETo takes the series' own mean ETo of its month and a day without rain counts as dry; a season or year
  with more than a tenth of its days filled is left out.
- **Balance**: every irrigated area with a water balance runs the daily soil water balance of FAO-56 chapter 8
  (`soil_water_balance.dart`, the inputs of the daily water balance dialog) season by season, twice: without a limit,
  which gives the irrigation requirement, and with the gross depth the designed system can apply a day, which gives what
  it would have applied and the deficit days (crop days that end with the depletion above the RAW, or above the
  regulated deficit of the stage); a season with none is reliable. The daily capacity is, under a machine, its depth
  per revolution over the hours of a revolution times the programme's window, and elsewhere the application rate of the
  emitters over the area times the share of the window of its system flow (shares in proportion to the hours each flow
  needs on the design's peak day); an interval trigger of n days may apply n days of it.
- **Peak period**: the largest mean over 7, 10, 15 or 30 consecutive days of ETc,loc less the rain the root zone kept
  (effective rain less deep percolation), over the gross/net factor of the month; the peak-period ETo is the largest
  mean ETo over as many days.
- **Years**: seasonal crops from their planting day (a season may run into the next year); year-round crops and the
  site's figures by irrigation year, from the first day of the month whose mean rain most exceeds its mean ETo, so that
  the soil may start at field capacity and the dry season of either hemisphere falls inside one year.
- **Probabilities**: empirical non-exceedance with Weibull plotting positions, F(x₍ᵢ₎) = i/(n + 1) for the i-th smallest
  of n values (Weibull 1939; Chow, Maidment & Mays 1988, section 12.5; the positions of the dependable rain of section
  21.2), the value of a probability interpolated linearly between ranks and clamped to the sample: no distribution is
  fitted, nothing is extrapolated beyond the years observed.
- **Trend**: Sen's slope, the median of the slopes of every pair of years (Sen 1968), and the Mann-Kendall test (Mann
  1945; Kendall 1975) with S = Σ sign(xⱼ − xᵢ), the variance corrected for ties, Var(S) = [n(n−1)(2n+5) − Σ
  t(t−1)(2t+5)]/18, and the continuity-corrected Z, two-sided at 5 % (|Z| > 1.96), as Helsel & Hirsch (2002, chapter 12)
  describe it; the normal approximation needs about ten values, so shorter series give no test, and serial correlation
  is not removed.
- **Dry spell**: the ETCCDI index CDD, the most consecutive days with less than 1 mm of rain (Karl, Nicholls & Ghazi
  1999; Zhang et al. 2011), a missing day ending the spell.

Reanalysis data are means over cells of tens of kilometres and smooth the extremes a station on the site would show.
The tests check the statistics, the peak means, the irrigation year and the capped balance by hand (5 mm/day of gross
capacity against an ETc of 5 mm/day: 356 events, 1780 mm, 351 deficit days) and simulate a pivot of the gallery by hand;
two real NASA POWER answers (one across a new year, one before 1984 with the sentinel −999 for the missing radiation)
are parsed. Only a summary, a few numbers per site year and per area and season, is kept in the project.

### 21.10 Irrigation forecast

Modules `forecast_online.dart` and `irrigation_forecast.dart` (Design → Agronomy → Irrigation forecast). The daily
water balance runs forward from today over the days of a weather forecast, for every irrigated area.

- **Forecast**: MET Norway Locationforecast 2.0 (about nine and a half days, hourly for the first two to three days,
  six-hourly after) or the Open-Meteo Forecast API (16 daily values with its own FAO-56 ETo, used as given). MET's hours
  are taken to local solar days (UTC + longitude/15, since a time-zone database would be a dependency): the extreme
  temperatures, the mean dew point, the mean wind at 10 m brought to 2 m (FAO-56 eq. 47) and the precipitation of each
  1- or 6-hour period counted once. A later day must be covered for 18 hours; when the forecast covers less than 12
  hours of today, tomorrow's ETo stands for today's.
- **ETo**: FAO Penman-Monteith (FAO-56 eq. 6, section 21.2) on the daily values. MET Norway publishes no solar
  radiation, so it comes from the temperature range, Rs = kRs·√(Tmax − Tmin)·Ra (FAO-56 eq. 50, kRs 0.16, limited to
  the clear-sky radiation), the procedure FAO-56 gives for missing radiation. The daylight cloud cover through Kasten &
  Czeplak (1980), Rs = Rso·(1 − 0.75·C^3.4), was tried and dropped: on the five whole days of the answer recorded for
  the tests it gave an ETo 19 % above the one Open-Meteo published for the same place and days, eq. 50 −1 % (mean
  absolute difference 0.3 mm/day). One site and five days is thin evidence, and eq. 50 misses cloudy days with a wide
  range of temperature.
- **Balance**: the crop as its requirement table and daily balance take it: the Kc curve on each date from the planting
  date read for the hemisphere of the site, ETc,loc = Kr·Kc·ETo, TAW = AWC·Zr·Pw, RAW = p·TAW with p adjusted to the ETc
  of the day (FAO-56 Table 22, note 2), Ks of eq. 84; rain below 0.2·ETo only wets the surface and rain above field
  capacity percolates (eq. 88).
- **When and how much**: an area is irrigated on the day its depletion would reach the smaller of the allowed depletion
  of the stage and the net depth of one event of the design programme, so the programme's interval is kept while the
  weather asks for the design depth; the irrigation refills the depletion (the refill share of the balance settings),
  the gross depth is the net over the efficiency with the leaching requirement of the month, and the run time the gross
  depth over the application rate of the area in the design results.
- **Water budget**: 100 × (the water the crop uses in the forecast days − the rain the root zone keeps) ÷ (the days ×
  the daily depth the design programme applies in its design month), held within 0 to 300 %, the seasonal adjustment a
  controller takes; the starting deficit is left out (it is not the weather's share).

The tests compare the daily values and the ETo of the recorded MET answer with an independent calculation (for
2026-11-10: Tmax 26.3 °C, Tmin 14.9 °C, Tdew 13.68 °C, u₂ 2.64 m/s, ETo 4.928 mm) and check the plans by hand (a
deficit carried until the fifth day, rain that skips an irrigation, both hemispheres in January). The answer is kept
on the device and never fetched again before the service's `Expires` time (MET's terms), and kept at least three hours
for MET Norway (half its six-hour update interval outside the Nordic area), one for Open-Meteo.

### 21.11 The programme on the plan

Modules `programme_playback.dart`, `programme_calendar.dart`, `ics.dart` and `gif_animation.dart` (Design → Agronomy →
Play the programme on the plan). Every system flow runs every few days on staggered days, so the programme repeats
after the least common multiple of the intervals (one day when every flow is daily; at most 28 days are played); the
cycle is circular, a run past its last midnight carrying on at the start. A moment shows the steady solution of the
group running then, held over its run; two overlapping groups have their flows added on shared pipes and the higher
supply head shown, with a note. A reservoir behind a supply follows the continuity of its volume, dV/dt = Q_in − ΣQ_drawn,
along the time line, its level read on the stage–volume curve of the reservoir study (inverted) and held between the
lowest operating level (dry) and the full level (spilling); the tests check the volumes by hand (an inflow of 7.2 m³/h
and a draw of 180 m³/h for 2 h on a basin of 1000 m² with vertical walls: 2500 → 2543.2 → 2197.6 → 2312.8 m³). The
calendar follows RFC 5545: lines folded at 75 octets without splitting a character, escaped text, floating local times,
a `DURATION`, an `RRULE` every cycle and stable `UID`s from an FNV-1a hash. The animated GIF has a palette of up to 256
colours a frame (octree quantizer, no dithering) and loops.

---

## 22. Centre pivots and other machines

Module `pivot.dart` (Keller & Bliesner 1990, chapter 14; Chu & Moe 1972) for the machine hydraulics,
and `mechanised.dart`, which runs for every machine of a design the sprinkler package and timer
chart (`pivot_package.dart`) and, when their data are given, the corner arm (`corner_arm.dart`), the
variable-rate prescription (`vri.dart`) and the electrical design (`pivot_electrical.dart`), with the
pivot point at the pressure the mainline gives it.

- **Capacity**: Q = A · gross depth / cycle time. For R = 300 m (28.3 ha irrigated, including the
  throw of the last sprinkler), 8 mm in 24 h: Q = 94.2 m³/h. For a sector pivot the area, and hence
  the flow, scale with the swept angle.
- **Flow distribution**: in a pivot the flow passing a distance r is Q·(1 − (r/R)²), because the
  irrigated area grows with r²; in a linear it is Q·(1 − r/L). The end gun adds along the whole
  length.
- **Friction**: numerical integration (Simpson, 200 steps) of the loss gradient along the span pipe
  with the varying flow, by the friction law of the design (galvanised steel span pipe: Scobey
  K_s = 0.42, Manning n = 0.012); for a pivot the result equals the Chu & Moe factor ≈ 0.543 times
  the loss of a pipe carrying the total flow.
- **Inlet pressure**: pressure of the last sprinkler (or the end gun) + friction + ground rise in
  the worst direction (the azimuth where the end sits highest, obtained from the terrain model) +
  pipe height + machine losses; every tower is checked, because a sharp rise half-way can govern.
  The result enters the mainline as a demand (or the package's own requirement when it is higher,
  section 22.1) and the deficit is reported.
- **Application rate** at the outer end: average I = 2·Q·R/(R²·w), from the flow per unit length at
  the end over the wetted width w (Q already being the sector flow, no further sector correction),
  and peak (elliptical profile) 4/π times the average; compared with the soil infiltration limit
  when given.
- **Spans and nozzles**: per span, number of sprinklers (spacing along the pipe), flow per
  sprinkler, pressure at mid-span and the closest catalogue nozzle; the basis of the span report
  and of the bill of materials (towers, sprinklers, regulators).

### 22.1 Sprinkler package and timer chart

`pivot_package.dart` builds the nozzle chart of a centre pivot or linear move:

- **Outlets**: positions along the machine from the pivot point (or the inlet of a linear), span by
  span at each span's own spacing, the overhang included, or an explicit list.
- **Flow per outlet** for a uniform depth (Heermann & Hein 1968; NRCS NEH 623 chapter 11, eq. 11-44):
  each outlet serves the ring between the points half-way to its neighbours,
  q_i = Q·(b_i² − b_{i−1}²)/R², the classic q = 2·r·S·Q/R² for even spacing, adding up to Q exactly; a
  linear move gets q_i = Q·(b_i − b_{i−1})/L. R is the effective radius: pipe length plus the throw of
  the last sprinkler, or L + 0.9·R_gun with an end gun running all the way round, whose share is
  Q·(1 − L²/R²) (eq. 11-46); a gun used only in the corners is added to the sprinklers while it runs.
- **Pressure at every outlet**: friction outlet by outlet with the flow left in the pipe, by the
  pipe of each span; ground rise in the design and worst positions; pipe height with the arch of the
  span; machine losses. A drop gains its length in static head and loses the hose friction plus the
  gooseneck and fittings, K·V²/2g (K = 1.5; Keller & Bliesner 1990, chapter 16).
- **Regulators**: the nominal rating nearest the target nozzle pressure, from the catalogue or the
  standard 6 to 50 psi series; a regulator needs its inlet 5 psi above its rating to regulate (Kansas
  State University MF3608, *Interpreting and Using Center Pivot Sprinkler Designs*, 2022), and below
  that its outlet is taken as the inlet less that margin.
- **Nozzles**: the catalogue nozzle whose flow at the nozzle pressure is closest to the requirement,
  or a numbered series of orifice diameters (1/128-inch steps, the numbering of pivot spray nozzles)
  sized with the orifice equation q = C_d·(π/4)·d²·√(2gh), C_d = 0.97, the coefficient implied by the
  nozzle discharge coefficients of NEH 623 chapter 11, table 11-13. Outlets that would need less
  than half the smallest nozzle are plugged and their ring passes to the next outlet (the
  combination spacing of NEH 623 chapter 11).
- **Booster**: a booster pump at the end gives the gun its pressure without raising the inlet;
  its shaft power is ρ·g·q·ΔH/η and the next standard motor is chosen.
- **Timer chart**: the speed of the last regular tower at 100 % comes from the drive train (motor rpm
  over the centre and wheel gearbox ratios, times the rolling circumference of the tyre, which a
  designation such as 11.2-38 estimates) or is given; the time per revolution is 2π·r_last/v and the
  gross depth Q·T/A; at a timer setting p the tower runs p % of the time, so the time and the depth
  grow by 100/p (Kansas State MF3608; Keller & Bliesner 1990, chapter 16).

Example (the tests, after NEH 623 chapter 11): the sprinkler 1200 ft from the pivot with 10 ft
spacing discharges 10.69 gpm (eq. 11-44), sized as a nozzle a little larger than 7/32 in at 45 psi; an
end gun takes about 120 gpm (eq. 11-46); a 66-hour revolution at 2.0 ft/min of the end tower applies
0.90 in; a booster giving a 65 psi gun its pressure on a 45 psi lateral end needs 2.7 hp at 65 %.

### 22.2 Corner arm

`corner_arm.dart`: a rigid span hinged at the last regular tower whose tip follows a guidance path
(a buried wire along the field boundary offset inwards), so the machine swings out into the corners
of a square field and folds back along the sides. Geometric model, after the description of corner
systems in Keller & Bliesner (1990, chapter 16) and NRCS NEH 623 chapter 11:

- the hinge H(θ) = C + R₀·(cos θ, sin θ) turns with the machine at a constant angular speed; the tip T
  is the point of the path at the arm length L_c from H on the trailing side, |T − H| = L_c, with the
  arm angle φ (0 in line with the machine, positive trailing) limited to φ_max (120°); where the path
  is beyond reach the arm stays straight (shortfall), where it is closer than the folded arm reaches
  it stays at φ_max (overrun);
- the area the arm adds lies between the hinge circle and the trajectory of the arm end (tip,
  overhang and throw of the last sprinkler, taken along the arm), assumed star-shaped around the
  pivot point, which holds for convex guide paths;
- for a uniform depth a stretch of arm must deliver q = κ·dA/dθ, with dA/dθ the area it sweeps per
  radian of machine rotation (only forward motion counts) and κ = 2π·d/T_rev, the same rule that gives
  the main machine q = Q·(b₂² − b₁²)/R²;
- the arm's sprinklers form banks (four by default) sized for the straight arm,
  q_bank = κ·((R₀ + s₁)² − (R₀ + s₀)²)/2, switched on in sequence as the arm extends: a bank is on when
  the flow it should deliver reaches half its design flow; the duty ratio is also reported for
  packages that pulse their banks;
- a tip moving more than five times faster than the hinge tower means the arm jumped across the
  guide path (`corner_arm_jump`).

Simplifications: level ground, rigid arm, the tip exactly on the path, constant machine speed (the
speed limits of the arm drive are not modelled, only the tip speed ratio is reported), the throw of
the last sprinkler continuing the arm line, and a closed path around the pivot point (test "flow
versus angle: peak in the corners, symmetric about the diagonals").

### 22.3 Variable-rate prescription

`vri.dart`: the percent-timer (speed) setting of every angular sector and, with zone control, the
duty of the radial sprinkler banks, so that the machine applies target depths given by zones
(polygons) or by sectors. With **speed control** the depth of a pass is inversely proportional to the
speed, d(p) = d₁₀₀·100/p (the timer chart), so a sector with target d runs at p = 100·d₁₀₀/d, limited
to the slowest setting the panel accepts (5 % by default) and 100 %: targets below d₁₀₀ cannot be
reached by speed alone and targets beyond the slowest setting are capped. With **zone control** the
sector runs at the speed of its wettest bank and the other banks pulse on and off with a duty
d_bank/d_sector (the speed and zone control modes of site-specific sprinkler VRI, Evans et al. 2013,
*Irrigation Science* 31: 871–887). Zone depths are sampled at equal-area points of every sector and
ring, and a sector's target is their area-weighted mean (or their maximum or minimum, by choice); the
prescription is exported as CSV in drawing angles or compass bearings (test "zone control: the
sector runs at the speed of its wettest bank, the others pulse").

### 22.4 Electrical design of a machine

`pivot_electrical.dart`, for a three-phase supply (480 V by default):

- motor current I = P/(√3·U·η·cos φ), P the rated output (0.55 kW, η 0.70, cos φ 0.72 by default for
  the tower motors); starting (locked-rotor) current k·I at a low power factor (direct-on-line, k ≈ 6
  at cos φ 0.4);
- voltage drop span by span with the current of every motor beyond the span,
  ΔU = √3·L·(R·ΣI·cos φ + X·ΣI·sin φ), the three-phase form of IEC 60364-5-52 Annex G (b = 1;
  conductor resistance in service 1.25 times its value at 20 °C; reactance 0.08 mΩ/m when unknown),
  checked running (every motor and the booster on, the worst case of the alignment cycling, at most
  5 %) and while each motor starts with the others running (at most 15 %);
- the span cable is the smallest section of the IEC 60228 class-2 copper list that keeps both drops
  within the limits;
- the generator is the larger of the running kVA over the allowed loading (0.8) and the size that
  limits the voltage dip when the largest motor starts, S = X''_d·S_LR·(1 − dip)/dip (IEEE Std 399,
  motor-starting studies; IEEE Std 446, generator sizing; X''_d = 0.2 per unit and a 20 % dip by
  default), rounded up to a standard rating;
- at a timer setting every tower keeps aligned with the last one, so it runs a share of the time
  proportional to its radius, and the last tower the timer fraction (Keller & Bliesner 1990, chapter
  16): the average power.

Test "end-gun booster: 120 gpm × 58 ft at 65 % (NEH 623 ch. 11) needs a 3 kW motor with the service
factor".

### 22.5 Travelling guns

`traveller.dart`, after NRCS NEH 623 chapter 11 and Keller & Bliesner (1990, chapter 8):

- lane (towpath) spacing as a percentage of the wetted diameter by wind class (table 11-31): no wind
  80 %; wind up to 2.2 m/s (5 mph) 70 % with ring nozzles and 75 % with tapered nozzles; up to
  4.5 m/s (10 mph) 60 to 65 %; stronger winds 50 to 55 %; with a field width the number of lanes is
  rounded up and the spacing evened out, never wider than the table (sample calculation 11-17);
- gross depth d = q/(S·v) and the speed for a target depth v = q/(S·d) (eq. 11-40);
- application rate under the gun I = q/(π·(0.9·R)²·θ/360), the wetted area taken on 90 % of the radius
  (eq. 11-39);
- hose friction along the whole hose (the water also runs through the coils left on the drum), by
  Hazen-Williams or Darcy-Weisbach for PE; the turbine and drum losses are the maker's value (NEH 623
  notes they usually exceed 10 psi with turbine drives);
- inlet pressure at the hydrant = gun pressure + hose friction + drive loss + gun height + ground
  rise; power P = ρ·g·q·H/η.

Test "sample calculation 11-17: 515 gpm gun, 455 ft diameter, 2,640 ft field, 2.56 in".

### 22.6 Surface irrigation

`surface_irrigation.dart` evaluates and designs furrows, borders and level basins with the
volume-balance model of Walker & Skogerboe (1987) as set out in FAO Irrigation and Drainage Paper 45
(Walker 1989), with the revised NRCS intake families of NEH 623 chapter 4 as default soils:

- **Infiltration**: Kostiakov-Lewis z = k·τ^a + f₀·τ (FAO 45 eq. 15), per metre of furrow or per metre
  of width; furrow intake scales with the wetted perimeter, k and f₀ times WP/WP_ref (NEH 623 chapter
  4, eqs. 4-76 to 4-78).
- **Flow section**: A·R^(2/3) = ρ₁·A^ρ₂ from the power laws A = σ₁·y^σ₂ and WP = γ₁·y^γ₂,
  ρ₂ = 5/3 − (2/3)·γ₂/σ₂ and ρ₁ = σ₁^(5/3−ρ₂)/γ₁^(2/3) (eqs. 40 to 45; wide sheet flow ρ₁ = 1,
  ρ₂ = 5/3); inlet area by Manning at normal depth, A₀ = (Q₀·n/(ρ₁·√S₀))^(1/ρ₂) (eq. 48), or with the
  friction slope y₀/x on level fields (eq. 60, generalised to the furrow power laws).
- **Advance**: the volume balance Q₀·t = σ_y·A₀·x + σ_z·k·t^a·x + f₀·t·x/(1 + r) (eq. 46) with
  σ_y = 0.77 and σ_z = (a + r(1 − a) + 1)/((1 + r)(1 + a)) (eq. 47), the power advance x = p·t^r fitted on
  the half and the full length (the two-point method of Elliott & Walker 1982), solved by
  Newton-Raphson with a bisection safeguard.
- **Depletion and recession**: furrows recede at cutoff; open-end borders deplete y₀·L/(2·Q₀) after
  cutoff (eq. 99) and recede over the time of Strelkoff (1977) (eqs. 96 to 98); level basins recede
  vertically, the water left on the surface spreading evenly and infiltrating in place.
- **Performance**: infiltrated depth along the field from the opportunity time
  τ(x) = t_rec(x) − t_adv(x) (eq. 55); application efficiency, requirement efficiency, low-quarter
  distribution uniformity, deep percolation and tailwater ratios.
- **Design**: the cutoff for the required depth (furrows t_co = τ_req + t_L, eq. 68; borders from the
  Strelkoff depletion; basins t_co = (Z_req·L − σ_y·y₀·L)/Q₀ + t_L, eq. 113) and the inflow that maximises
  the application efficiency between the minimum (the border spreading flow
  0.000357·L·√S₀/n m³/min/m of Hart et al. 1980, eq. 93) and the non-erosive maximum
  Q = (V^ρ₂·n/(ρ₁·√S₀))^(1/(ρ₂−1)) (eq. 67; basins eq. 115); and the Kostiakov-Lewis parameters from two
  advance points of a field evaluation (eqs. 49 to 54).

The tests reproduce the worked examples of FAO 45, e.g. the 200 m furrow at 0.15 m³/min whose advance
takes about 65 min and the Strelkoff recession of the border example (824 − 147 = 677 min).

### 22.7 Gated pipe

`gated_pipe.dart`: a gated pipe (or lay-flat pipe with punched holes) feeding furrows. Along the pipe
the flow falls gate by gate and the pressure head changes with the friction of the flow left in the
pipe (Hazen-Williams or Darcy-Weisbach) and with the ground slope, the energy balance of NRCS NEH 623
chapter 4, eq. 4-89, applied stretch by stretch instead of with the whole flow over the whole length
(velocity-head recovery neglected). Every gate is an orifice q = C_d·A·√(2gh), C_d = 0.61 for a
sharp-edged opening (U.S. Bureau of Reclamation, *Water Measurement Manual*, chapter 13); the
required area gives an equivalent diameter, and the hole is the smallest standard punch at least that
large (1/2 to 1-1/2 inch in 1/8-inch steps, then 1-3/4 and 2 inches), partly closed to the required
area (an adjustable gate) or, for fixed holes, passing the flow of the full hole. The minimum inlet
head delivers the target through the largest hole at the critical gate.

---

## 23. Terrain and geoprocessing

### 23.1 Digital terrain model

Modules `terrain.dart` and `tin.dart`.

- Samples: spot heights and contour-line vertices, densified every 5 m (parameter), with a spatial
  hash for fast queries.
- **Delaunay TIN** by the Bowyer-Watson algorithm (incremental insertion removing the triangles
  whose circumcircle contains the new point), with triangle location by a uniform grid and linear
  interpolation by barycentric coordinates. Exact on planar slopes (test "Delaunay of a plane
  reproduces the plane exactly") and the same as the model CADs call a DTM. The triangulation works
  in coordinates relative to the lower-left corner of the samples and treats a point on a
  circumcircle (four co-circular points: a cell of a regular grid, spot heights at the corners of
  a rectangle) as outside it, so the diagonal follows the insertion order and moving or
  georeferencing a project (UTM coordinates included) does not change its terrain.
- **Breaklines** (a ridge, a channel bottom, the edge of a terrace, road or embankment): their
  segments become edges of the triangulation, so the surface folds along them instead of being
  interpolated across. After the Delaunay triangulation every constraint segment, split at any
  vertex lying on it, is forced in by flipping the diagonals it crosses (Sloan 1993): an edge crossing
  the segment is flipped when its two triangles form a convex quadrilateral, otherwise it waits for
  its neighbours to be flipped first. A breakline vertex may carry its surveyed elevation; one
  without (NaN) takes it from the other terrain data there (IDW), and the breakline is sampled every
  densify step with the elevation linear along each segment, the samples feeding the IDW too (tests
  "without the breakline the valley is bridged; with it the surface folds along the channel", "a long
  diagonal breakline is forced through a dense triangulation").
- **IDW** (inverse distance over the nearest neighbours, with search rings in the hash) as an
  alternative method and as a complement outside the convex hull of the TIN. Every sample counts
  once: cells share hashed keys, and a far cell bringing back a list already taken used to weight
  some spot heights twice, by an amount that depended on where the drawing lay
  (`invariance_test`).
- Surveys with more than 12 000 points are decimated uniformly for the triangulation, but the IDW
  keeps them all (test "very large surveys are decimated for the TIN but kept for IDW"); the program
  says so once for a terrain that large.
- **Generated contour lines**: marching over the triangles (intersection of every level plane with
  every edge), segments chained into polylines with ring closure; the automatic interval is chosen
  for about 20 contours at most.
- **Slope and aspect** (`slope_map.dart`): from the plane of the triangle under a point, or by
  central differences over 1 m outside the TIN; the slope map samples the terrain on a square grid
  (the cell grows to stay within a cell budget, cells outside the hull of the data left out) and
  colours it by slope class (upper bounds 2, 5, 10, 15, 20, 30 and 45 %, after the slope phases of
  the USDA Soil Survey Manual, chapter 3, rounded for irrigation layout: greens where laterals run
  freely, yellows and oranges where they need pressure compensation or a contour layout, reds and
  purple where the ground is steep) or by aspect (the compass bearing of the steepest descent in
  eight sectors around a hue wheel, dimmed under 1 %), with the share of the area in each class.
- Every node of the graph (lumped emitters included) receives the model elevation, plus the riser
  height and minus the burial depth.

### 23.2 Point clouds and surveyed surfaces

- **LAS** (`las.dart`, ASPRS LAS Specification 1.4 R15, 2019): versions 1.0 to 1.4, point data
  record formats 0 to 10 with their scale and offset, read as a stream in chunks of any size that
  keeps only the header, one partial record and a grid. A classification filter keeps the ground
  points (class 2) by default and skips the withheld ones; an unclassified cloud falls back to the
  lowest point of every cell (bare ground, where vegetation and buildings sit above it). The points
  are decimated on a grid while reading (`point_grid.dart`: a regular grid over the bounds with at
  most as many cells as the terrain triangulates, one point per cell — the mean of the cell, its
  lowest point or the point nearest the centre), so the terrain stays within its limit whatever the
  size of the cloud. The coordinate system comes from the variable-length records (the GeoTIFF
  GeoKeyDirectoryTag with the projected or geographic EPSG code and the linear and vertical units, or
  the OGC WKT record of LAS 1.4, also in an extended record at the end of the file). Compressed
  clouds (LAZ) are recognised by the compression bits of the point format byte and refused with
  `las_laz_unsupported` (tests "every version and point format: ground points on the plane, CRS from
  the keys or the WKT", "SAD 69 coordinates land on the SIRGAS 2000 points (the IBGE translation)").
- **LandXML 1.2** (`landxml.dart`, the 2008 schema): the reader takes CgPoints (nested groups too),
  Surfaces — the Definition (points and faces, the TIN kept) or the source data (contours,
  breaklines, data points, boundaries) — decimated on a grid to the terrain limit, and the pipes of
  pipe networks; the CoordinateSystem (EPSG code, OGC WKT or a name) places the data, Imperial units
  are converted, and the coordinates are read in the "northing easting elevation" order of the
  format. The writer gives the project's terrain as a Surface (the TIN of `tin.dart` and the contours
  and spot heights it was built from), the point items as CgPoints at the ground with a code naming
  their type, for stake-out, and the pipes as one pipe network per zone and one for the mainline: a
  Pipe per drawn segment (circular, with the inner diameter and Hazen-Williams C, and the design flow
  and grade at both ends when results exist) between Structs at the vertices whose inverts are the
  ground less the burial depth less half the inner diameter. Element order, required attributes and
  the unique Struct and Pipe names of the schema are respected (test "the document follows the
  LandXML 1.2 structure").

### 23.3 Online elevation

Module `dem_online.dart`. Three free, keyless sources:

| Source | Data | Resolution | Access |
|---|---|---|---|
| Terrain Tiles on AWS Open Data (the default) | SRTM, GMTED, ETOPO1 in "terrarium" PNG tiles | about 30 m | tiles, cross-origin enabled, no rate limit |
| Open-Meteo Elevation API | Copernicus DEM GLO-90 | 90 m | 100 points per call, every point counted as a call (paced at 550 points a minute) |
| OpenTopoData | NASA SRTM, ASTER GDEM | 30 m | 100 points per call, one call a second; no cross-origin header, so desktop builds only |

The grid over the project (or the visible area) is limited in points (the spacing grows with the
area). For the tiles, the zoom is the smallest whose pixel is not larger than the grid spacing
(between 8 and 14: the data is about 30 m, so more only interpolates, and the zoom drops until the
tile count fits), every terrarium pixel decodes as elevation = R·256 + G + B/256 − 32768 m, and the
points are sampled bilinearly; for the point services the calls are batched and paced, with retries
and waits on HTTP 429. The answers become spot heights and contour generation can follow
automatically. Elevations already in the project (survey contours, typed spot heights, example
data) that cannot belong to the datum of the downloaded model — the two ranges do not overlap and the
gap exceeds half the model's own relief — would give a terrain full of spikes: the program detects it
and asks whether to replace them. The 30 to 90 m resolution serves the general relief and does not
replace a survey, which the dialog says.

### 23.4 Coordinates and datums

- **UTM ↔ WGS84** by the Krüger series in Karney's formulation (2011), with millimetre accuracy
  inside the zone, automatic zone with the Norway and Svalbard exceptions, and a local origin to
  keep drawing coordinates small (test "UTM inverse round trip").
- **Datums** (`datum.dart`): files on the geodetic datums of Brazil are placed by geocentric
  translation. SIRGAS 2000, the official datum (IBGE, Resolução do Presidente nº 1/2005), was
  realised on ITRF2000 at epoch 2000.4 and agrees with the current WGS 84 realisations to a few
  centimetres at that epoch; the plate moves 1 to 2 cm a year, so a position observed today differs
  from its SIRGAS 2000 coordinates by up to about half a metre, and at the accuracy of an irrigation
  map the two are treated as identical (ETRS89 and NAD83 likewise). SAD 69 → SIRGAS 2000:
  ΔX = −67.35 m, ΔY = +3.88 m, ΔZ = −38.22 m (R.PR 1/2005; SAD 69 ellipsoid a = 6 378 160 m,
  f = 1/298.25; GRS 80 for SIRGAS 2000). Córrego Alegre → SAD 69: ΔX = −138.70 m, ΔY = +164.40 m,
  ΔZ = +34.40 m (R.PR 23/1989, International 1924 ellipsoid), which composed with the above gives
  Córrego Alegre → SIRGAS 2000 ΔX = −206.05 m, ΔY = +168.28 m, ΔZ = −3.82 m. Both three-parameter
  shifts are accurate to a few metres: the classical networks hold distortions of that order, which
  only a grid-based transformation removes. Latitude and longitude go to geocentric X, Y, Z on the
  source ellipsoid, are translated and come back on the target ellipsoid (Bowring's start refined by
  iteration); the transverse Mercator works on any ellipsoid (the Krüger series to n³).
- **Recognising a file's CRS**: WKT 1 in the ESRI flavour of `.prj` files and the OGC one (OGC
  01-009), WKT 2 (ISO 19162:2019), EPSG codes (geographic and UTM codes of the datums above) and OGC
  URNs; an unrecognised system carries a problem code (`crs_datum_unknown`,
  `crs_projection_unsupported`, `crs_unparsed`, `crs_geocentric`) for the interface to warn about,
  instead of the data being put silently in the wrong place.
- **Placement** (`GeoPlacement`): UTM data on a WGS 84 compatible datum in the project's zone is a
  plain offset (exact); geographic data and data on another datum, zone or projection go through
  WGS 84 latitude and longitude, with the datum shift, and the project's UTM zone; without a project
  georeference one is created from the data (its zone, the origin rounded to 100 m); local or
  unrecognised coordinates are kept, and large ones (beyond 100 km) are moved by a rounded local
  origin. Coordinates count as degrees only when every pair fits the longitude/latitude range and at
  least half carry four or more decimals (tests "SAD 69 and Córrego Alegre to SIRGAS 2000 agree with
  the Molodensky formula and round-trip", "UTM on SIRGAS 2000 in the project zone is a plain offset;
  another zone goes through lat/lon").
- **Pasted coordinates** (`parseLatLon`): decimals with dot or comma, hemisphere letters,
  degrees/minutes/seconds, Google Maps links and `geo:` URIs; the lon, lat order (KML) is
  recognised when only it makes sense.
- KML, KMZ, GeoJSON and GPX exports convert every vertex to WGS84 through the project georeference
  and need one (the app asks for it); shapefiles, LandXML, IFC and the EPANET file are written in the
  UTM coordinates of the georeference when there is one and in local metres otherwise.

---

## 24. File formats

### 24.1 DXF

The text format of DXF, organised in "group code / value" pairs. The reader (`dxf.dart`) walks the
BLOCKS and ENTITIES sections and reads LINE (10/20 and 11/21), LWPOLYLINE (vertices 10/20 in
order, bulge 42, closing flag 70, elevation 38), POLYLINE with VERTEX (elevation in code 30 or in
the equal Z of the vertices; spline control vertices ignored), CIRCLE, ARC (50/51 in degrees),
ELLIPSE (a polyline from the axes 11/21, the ratio 40 and the parameters 41/42), SPLINE, HATCH,
SOLID and TRACE, TEXT, visible ATTRIBs, MTEXT (code 3 chunks followed by 1, alignment point 11/21
when 72/73 ask for it, the direction as an angle or a vector), LEADER (its line; the arrowhead and
the note are drawn by the program) and POINT, with the layer (8) and the colour (62); the LAYER table
and the $INSUNITS variable define layers and scale. A bulge b describes an arc of angle 4·atan(b)
between two vertices, sampled every 15°. Texts come out as plain text: the `\U+XXXX` characters of
files in a code page, the `%%c`, `%%d` and `%%p` symbols (diameter, degree, plus/minus), `%%%`, the
underline and overline toggles and the caret notation of control characters; in MTEXT, the escaped
characters, line breaks and non-breaking spaces become spaces, stacked fractions `a/b`, and the
formatting codes and grouping braces are dropped.

- **SPLINE**: with fit points (11/21) it becomes an editable spline through them; otherwise the
  NURBS curve itself is evaluated by de Boor's algorithm from the degree (71), the knots (40), the
  control points (10/20) and the weights (41, rational curves), with a clamped uniform knot vector
  when the file gives none, and imported as a polyline.
- **HATCH**: the boundary paths (91/92) — polyline paths with bulges or edge paths made of lines,
  circular arcs (clockwise arcs mirrored), elliptical arcs and splines — become a hatch whose first
  path is the outline and whose other paths are islands (kept as closed polylines); the solid flag
  (70) and the first pattern line (angle 53, spacing from the offsets 45/46, 3.175 mm times the
  pattern scale otherwise) give the fill.
- **SOLID and TRACE**: filled triangles and quadrilaterals, whose corners come in the order
  1-2-4-3, become solid hatches.
- **Extrusion (0, 0, −1)**: the planar entities (CIRCLE, ARC, LWPOLYLINE, 2D POLYLINE, HATCH,
  SOLID, TRACE, TEXT, ATTRIB) are written in object coordinates, and mirroring in a CAD program
  often leaves an extrusion (210/220/230) of (0, 0, −1), whose object X axis is the world −X by the
  arbitrary axis algorithm. Those entities, the INSERT and DIMENSION references and the minor axis
  of an ELLIPSE are mirrored back into world coordinates (an arc from a to b becomes the arc from
  180° − b to 180° − a); LINE, POINT, SPLINE, MTEXT and 3D polylines are in world coordinates
  already. Other extrusions (3D entities) are projected as they are.

Blocks: every BLOCK keeps its base point (10/20) and its entities; INSERT (point 10/20, scales
41/42, rotation 50, array 70/71 with spacings 44/45) and the anonymous block of every DIMENSION
(code 2, already in drawing coordinates) are expanded by an affine transformation, with nested
references composed up to eight levels. Entities on layer 0 take the layer of the reference and
BYBLOCK colour takes its colour; circles and arcs stay circles and arcs when the transformation
keeps shapes (rotation, uniform scale, mirroring — a mirrored arc turns the other way and texts and
hatch angles follow the mirrored directions) and become polylines under anisotropic scaling; dimension
definition points (Defpoints layer) are left out. Text is decoded as UTF-8 (R2007+) or Latin-1
(cp1252 of the older files).

Two writers: the R2000 export with native entities (section 24.3) and, as a separate choice
for older programs, an R12 file (AC1009) of the primitives (LINE, POLYLINE, CIRCLE, ARC, TEXT and
POINT with its elevation, splines and symbols as polylines, hatches as outline and lines, dimensions
as lines and text) on layers with a colour index, the common denominator of all CADs.

### 24.2 DWG

DWG is binary and proprietary; the Open Design Alliance publishes a reverse-engineered
specification that served as the basis for the reader (`dwg.dart`, 2.0 thousand lines) and the
writer (`dwg_writer.dart`, 1.7 thousand lines), both in pure Dart.

- **Versions**: AC1012 (R13), AC1014 (R14), AC1015 (2000), AC1018 (2004), AC1021 (2007), AC1024
  (2010), AC1027 (2013), AC1032 (2018). Unknown versions are rejected with a clear message.
- **Containers**: R13 to R2000 have sections located by an index in the header, without
  compression; R2004 and R2010 to R2018 use compressed pages with their own LZ77 scheme and a map
  of pages and sections; R2007 is the hardest case: pages interleaved with Reed-Solomon codes
  (repeated 239-byte blocks), which must be de-interleaved and decompressed before reading.
- **Data**: objects are addressed through the object map (handles), and every object is a bit
  stream with variable-length codes (B, BB, BS, BL, BD, DD, MC, MS, H, among others); the reader
  assembles multi-byte integers arithmetically because dart2js bitwise operations are 32-bit. The
  header CRC-16 is verified against the checksum stored in real files. The handle map is a
  list of (handle, offset) pairs delta-coded in sections: the specification restarts the deltas at
  every section, some writers keep them running, and both readings agree on the first section, so
  they are told apart by checking objects spread over the whole map (checking the first entries
  only misread 64 of the 750 objects of a real-world file).
- **Blocks and dimensions**: INSERT (type 7) and MINSERT (8) carry the insertion point, the scales
  (R13/R14 as three BD; R2000+ with a BB code choosing between 1,1,1, a single value, X = 1 or three
  DD values relative to X), the rotation, the extrusion, the attributes flag, the array vector and,
  in the handle stream, the block header. BLOCK_HEADER (49) gives the name, the base point and the
  entities of the block: first and last (R13–R2000, with the handles in sequence) or the list of
  owned entities (R2004+); ownership also comes from `entmode` 0 with the owner handle. Dimensions
  (types 20 to 26) are read only through the handle stream (style and anonymous `*D` block), since
  the geometry is already in the block in drawing coordinates. The expansion reuses the affine
  transformation of the DXF reader. Three format details discovered with LibreDWG: handles with
  codes 6, 8, A and C are offsets relative to the handle of the containing object; in R2007+ the
  table entries have no "xref referenced" and "xref dependent" bits (only the BS index); and in
  R13/R14 the bit size of objects comes after the handle and the extended data, not before.
- **Curves and fills**: ELLIPSE (35), SOLID (31), TRACE (32), SPLINE (36) and HATCH (78) are
  decoded with the same layout LibreDWG uses (spline scenario, degree, knots, control points with
  optional weights, fit points; from R2013 the spline flags; hatch gradient fields from R2004, the
  boundary paths with their edge types and, from R2010, the fit data of spline edges) and handed to
  the same conversions as their DXF counterparts; LEADER (45) is read as its polyline, and the texts
  are decoded as in DXF. The ten sample drawings from R13 to R2018 in the test fixtures give exactly
  the entities that LibreDWG lists for them.
- **Details that match the DXF reader**: 2D polylines keep the arcs of their vertices (VERTEX_2D
  carries the start and end widths and the bulge; spline frame vertices are skipped), aligned
  texts are placed by their alignment point, and the extrusion of circles, arcs, polylines, texts,
  solids, hatches, ellipses and block references is read and applied as in DXF. A drawing written
  by LibreDWG from an ezdxf file (test fixture `curves_r2000`) reads back like the DXF itself.
- **R2000 writer**: a complete drawing database (section 24.3): the control tables (layers with
  their colour, state and linetype, linetypes with dashes, text style, viewport, appid, dimension
  styles), the named-object dictionaries with layouts, model and paper space, block definitions with
  their attribute definitions, and the native entities LINE, LWPOLYLINE (with arcs), CIRCLE, ARC,
  POINT, TEXT, MTEXT, SPLINE, HATCH, SOLID, INSERT with ATTRIBs, DIMENSION (aligned, angular,
  radius, diameter, ordinate) with its anonymous block, and LEADER. R2000 colours are colour indices
  only (true colours came with the R2004 format), and characters outside the code page are written in
  the `\U+XXXX` notation CAD programs read. The byte layout follows the Open Design Alliance
  specification as LibreDWG implements it; the field order and the default values were checked
  against real-world files and validated with LibreDWG (`dwgread`, `dwg2dxf`), which the
  test runs when installed, besides being re-read by our own reader.

### 24.3 The native CAD drawing

Modules `cad_drawing.dart` and `cad_export.dart`: both R2000 writers (DXF AC1015 in
`dxf_r2000.dart`, DWG AC1015 in `dwg_writer.dart`) take one model of the drawing, so the DXF and the
DWG carry the same drawing, in world metres, for the work to go on in a CAD program:

- drawing entities stay what they are: lines, lightweight polylines (the arcs of revision clouds and
  pivot sectors as bulges), circles, arcs, splines (the app's centripetal Catmull-Rom curve converted
  exactly into a cubic B-spline, one Bézier span per pair of fit points with the tangents of the
  Barry–Goldman form at its ends and knots of multiplicity three at the joints spaced by the chord
  lengths, plus its fit points), hatches (solid, or the ANSI31 pattern turned and scaled to the
  hatch's angle and spacing), text and multiline text;
- dimensions are DIMENSION entities (aligned, 3-point angular, radius, diameter, ordinate) with their
  anonymous `*D` blocks already drawn, so that programs show them without recomputing, in dimension
  styles whose sizes are the ISO-25 paper sizes times a DIMSCALE that makes the text 0.5 m and whose
  length factor and suffix show the project's units; leaders are LEADER entities with their note as
  multiline text;
- symbols and hydraulic items are references to small blocks (one per kind) whose invisible
  attributes NAME, ITEM, NOZZLE, ZONE and STATIONS carry the entity's name, catalogue item, nozzle,
  zone and stations, on the item's layer; the user blocks of the project are block definitions too;
- contours keep their elevation, spot heights and breakline vertices are 3D points; tapes, wire
  routes and breaklines use a dashed linetype;
- layers carry the colour index and, in DXF, the true colour (code 420, read by CAD programs from the R2004 format on),
  their linetype and their on, locked and plot states; table names are made valid (the characters
  `<>/\":;?*|=,` and the backquote become `_`); the DXF has $INSUNITS in metres, its text in ASCII
  with `\U+XXXX` for the rest ($DWGCODEPAGE ANSI_1252), so it reads the same whatever encoding a
  program assumes, and every handle and owner of the database.

`tool/formats/check_exports.py` validates both files with ezdxf (audit without errors) and LibreDWG,
and `cad_export_test.dart` reads them back.

### 24.4 KML and KMZ

Google Earth XML with lon, lat, altitude coordinates in WGS84; KMZ is a zip with the KML and
resources. Folders become layers, lines with altitude or an ELEV attribute become contour lines,
points with altitude become spot heights. The projection to UTM uses an automatic zone and a local
origin; the export does the reverse path with one folder per layer.

### 24.5 Shapefile, CSV/PNEZD

- **Shapefile reader**: `.shp` (geometry with a 100-byte big-endian header and little-endian
  records: points, polylines, polygons, multipoints and Z variants), `.dbf` (dBase attributes, where
  the elevation ELEV/Z/COTA and the name NAME/NOME/ID come from, decoded as the `.cpg` says or as
  UTF-8 when valid and Latin-1 otherwise) and `.prj` (reference system, with the datum shifts of
  section 23.4), accepted inside a zip, also several shapefiles in one zip. Without `.prj`,
  coordinates are only treated as degrees when they fit the latitude/longitude range and at least
  half of them have four or more decimals; a local drawing in metres stays as it is.
- **Shapefile writer** (`shp_writer.dart`, ESRI Shapefile Technical Description, 1998): one shapefile
  per layer and geometry type (points, polylines, polygons; the Z variants where an elevation is
  meaningful: contours, spot heights and, with a terrain, the pipes at their burial elevation and the
  point items at the ground), with the `.shx` index, `.dbf` attributes in UTF-8 declared by a `.cpg`
  (the GeoJSON attributes plus typed fields: catalogue item, diameters, length, flows, velocities and
  pressures in the project's units named in the field, elevations, areas and crops), a `.prj` and
  everything zipped; coordinates in the project's UTM zone on SIRGAS 2000 or WGS 84, or local metres
  without a georeference.
- **Survey points**: CSV, TXT, XYZ and PNEZD (point, northing, easting, elevation, description)
  with column detection by header or position, comma, semicolon, tab and space separators, decimal
  comma and lat/lon recognition.

### 24.6 GeoJSON, GPX, DGN, EPANET and IFC

- **GeoJSON** (`geojson_reader.dart`, RFC 7946, and the 2008 specification for its `crs` member): a
  FeatureCollection, a Feature, a GeometryCollection or a bare geometry of every type, holes and
  nested collections included; longitude/latitude on WGS 84, or UTM on SIRGAS 2000, SAD 69 or
  Córrego Alegre when a `crs` names it; a third coordinate is the elevation, properties name the
  feature (`name`, `nome`, `nombre`, `id`, `label`), give an elevation (`elevation`, `elev`, `z`,
  `cota`, `altitude`) or a layer.
- **GPX** (`gpx.dart`, GPX 1.1 schema, 2004), for field work with a GPS receiver or phone: the writer
  puts every point item (heads, the outlets of the laterals, valves, junctions, pumps, supplies,
  devices, controllers, pivot centres) as a waypoint with its name, type, catalogue item and ground
  elevation, and the linear items as tracks or routes; the reader takes waypoints as spot heights
  and routes and tracks as polylines (GPX 1.1 or 1.0). The element order of the schema is kept.
- **DGN V7** (`dgn.dart`, the ISFF design file): lines, line strings, shapes, curves, complex chains
  and shapes, circles, ellipses and arcs, text and cells, levels as layers, 2D and 3D files;
  coordinates from the units of resolution with the master/sub-unit ratio and the global origin of
  the header, 32-bit integers in middle-endian word order and floating point in VAX D format, angles
  in 1/360000 degree. DGN V8 (an OLE compound document) is recognised and refused.
- **EPANET INP** (`epanet_inp.dart`, EPANET 2.2 Users Manual EPA/600/R-20/133): the writer starts
  from the graph of the network builder (laterals lumped into emitter nodes) with the sized pipes:
  supplies and the inlet of an exported zone are reservoirs at their elevation plus their pressure;
  pipes, laterals and tapes are pipes (lengths with the minor-loss allowance, as in our analysis;
  barb losses as minor losses); check valves a general-purpose valve with their loss curve in series
  with a short pipe of status CV; pumps a multi-point head curve sampled from the catalogue parabola
  with their speed; PRV, PSV and FCV with their settings and the open loss as a minor-loss
  coefficient; zone valves and devices with h = K·Q^n + C general-purpose valves with a head-loss
  curve; lumped emitters [EMITTERS] coefficients for the single global exponent of EPANET (the most
  common of the network), an emitter of another exponent keeping its flow at its nominal pressure and
  a pressure-compensating one (x < 0.1) becoming a base demand, each with a code. The options give
  the units, the head-loss formula (H-W, D-W, C-M) and the relative viscosity at the design
  temperature. One file per system flow, the valve-in-head heads as emitters in the flows that run
  their station. The reader builds our network from any input file (a GPV curve fitted back to
  h = K·Q^n + C) or a drawing of it.
- **IFC 4** (`ifc.dart`, ISO 10303-21 STEP file of the IFC4 schema, ISO 16739-1:2018, Reference
  View), for BIM and site-works software: IfcProject → IfcSite with the terrain TIN as the site's
  body (IfcTriangulatedFaceSet) and, with a georeference, IfcMapConversion and IfcProjectedCRS (the
  EPSG code of the UTM zone); pipes, laterals and tapes are IfcPipeSegment with an IfcSweptDiskSolid
  along the pipe at its burial depth; heads and emitters IfcFlowTerminal with ObjectType
  `IRRIGATION_<KIND>` (IFC4 has no terminal class for irrigation outlets: the fire-suppression
  sprinkler and the sanitary terminal are other things); valves IfcValve (zone valves USERDEFINED
  `ZONECONTROL`), filters IfcFilter, meters IfcFlowMeter, pumps IfcPump, reservoirs IfcTank, each
  with the standard property sets, a custom `OCI_Hydraulics` set (flow, pressures, velocity,
  catalogue item, zone) and the manufacturer information of its item; every zone and the mainline is
  an IfcDistributionSystem. GlobalIds derive from the project and entity ids, so the same project
  exports the same ids. Fittings are not exported (the design selects them without positions).

### 24.7 GeoTIFF, world files and images

TIFF with the GeoTIFF tags ModelPixelScale/ModelTiepoint or ModelTransformation and the CRS keys
(UTM or geographic). A single-band raster (float or integer) is treated as a DEM and becomes a grid
of spot heights, with nodata ignored; RGB rasters are background images. JPG and PNG images accept
world files (.jgw, .pgw, .wld) inside a zip: x = A·col + B·row + C and y = D·col + E·row + F for
the centre of every pixel, so the column axis (A, D) gives the pixel size and the rotation
(atan2(D, A)) and the top-left corner sits half a pixel back on both axes; the GeoTIFF
ModelTransformation matrix is treated the same way. Without a georeference, the image is placed in
the view and fitted by two points (similarity transformation: translation, rotation and scale).
BigTIFF files (64-bit offsets) are refused by name rather than failing later, and so are rasters of
more than 100 million pixels.

### 24.8 PDF output

- **Writer** (`pdf.dart`, ISO 32000-1 written as PDF 1.4): objects with an xref table, vector paths,
  clipping and Flate-compressed content streams. Text that WinAnsi can represent stays in the
  standard Helvetica fonts; any other text is laid out by `fonts/pdf_fonts.dart` into runs of one
  direction, script and font, shaped with the OpenType tables of the bundled Noto fonts (Sans, Math
  for symbols, Arabic, Devanagari, Bengali, Gurmukhi, Telugu, Simplified Chinese and Japanese) and
  drawn with a Type0 font per TrueType font (a CIDFontType2 descendant, Identity-H encoding,
  CIDToGIDMap /Identity, widths, an embedded subset and a ToUnicode CMap). Copy and search give the
  logical text: the first glyph of each shaped cluster maps to the cluster's text and the others to
  nothing, and a glyph standing for different texts (a shared Arabic letter skeleton, the first glyph
  of different Indic syllables) gets one CID per text, a copy of the glyph appended after the end of
  the font. Bold is simulated with text rendering mode 2 and a thin stroke. A missing font degrades
  to the next font of the chain, then to the WinAnsi approximation of the character, finally to "?".
  Images are image XObjects: JPEG data passed through (DCTDecode), anything else decoded and stored
  as RGB (FlateDecode) with a soft mask for the alpha channel, opacity through an ExtGState, large
  images downsampled for the size they are printed at.
- **Shaping** (`fonts/`, pure Dart, after the OpenType specification 1.9 and its script development
  documents): characters are normalised against the font (canonical decomposition and composition,
  marks reordered by combining class), mapped to glyphs, and the script shaper sets the feature
  masks — Arabic joining by the joining types of ArabicShaping.txt into the positional forms (isol,
  fina, medi, init), then rlig (lam-alef), calt and liga, the modifier marks kept by their base
  (UAX #53); Indic syllables (the new-spec tags dev2, bng2, gur2, tel2) with the base consonant found,
  pre-base matras, reph and pre-base-reordering forms moved, the basic features (nukt, akhn, rphf,
  rkrf, pref, blwf, abvf, half, pstf, vatu, cjct) applied within each syllable and the presentation
  features (init, pres, abvs, blws, psts, haln, calt) after; then GPOS (kerning, mark and
  mark-to-mark attachment, abvm, blwm, dist) with mark advances zeroed where the script asks. GSUB
  lookup types 1 to 8 and GPOS 1 to 9 are read; device and variation tables are ignored (PDF text is
  scaled, not hinted). Direction comes from a simplified Unicode Bidirectional Algorithm (UAX #9:
  paragraph level, weak types, paired brackets, neutrals, implicit levels and reordering; explicit
  embeddings, overrides and isolates are not interpreted), and right-to-left runs come out of the
  shaper in visual order with mirroring. The subsetter keeps the outlines of the glyphs used (and the
  components of composite glyphs) without renumbering, so the CIDs are the glyph ids. Runs of the
  interface strings in Arabic, Urdu, Hindi, Marathi, Bengali, Punjabi and Telugu must shape with the
  glyphs and positions of a reference engine (HarfBuzz, recorded in `test/fixtures/shaping`) in at
  least 99 % of the runs (`text_shaping_test.dart`).
- **Sheets** (`plot.dart`, `pdf_sheet.dart`, `sheet_set.dart`): the sheet is built in paper space,
  pens, symbols and texts in paper millimetres, with automatic or fixed scale, title block, legend,
  north arrow, scale bar, the base map and the images under the drawing, the revision table (the
  revision clouds with their number, date and description) and report pages. A **set of sheets** is
  an overview plus one sheet per zone or per irrigated area (fitted to it, with the other zones
  greyed or left out; zones in the natural order of their names) and the windows of the drawing the
  user chose, each with its own scale and title.
- **Construction details** (`details.dart`): eight typical details drawn by code with the values of
  the design (pipe diameters, burial depths, the trench settings of the quote, the catalogue models
  in use, pressures from the results), at a detail scale chosen to fit a cell of the sheet: the trench
  section, a control valve in its box, a sprinkler on a swing joint or a riser, the start connector of
  a drip line, an air valve, a thrust block at a bend, the suction of a surface pump and a filter
  station. Typical values follow common practice: the minimum covers of ASAE S376.2 for buried
  thermoplastic pipelines when the project has no depth (0.45 m up to 65 mm outside diameter, 0.60 m
  up to 125 mm, 0.75 m above), the suction submergence S = 2.5·D + 0.1 m of the hydraulics textbooks
  (Azevedo Netto, *Manual de Hidráulica*), and the thrust of a bend T = 2·p·A·sin(θ/2) at the test
  pressure (1.5 times the highest working pressure, else the pipe class) against an allowable soil
  bearing (50 kPa by default), which gives the bearing area of the block.
- **Charts** (`plot_charts.dart`), drawn as plot items so the PDF prints what the screen shows: the
  hydraulic grade line of the mainline in every system flow (from the supply to the valve with the
  least pressure margin, with the head that valve requires), the longitudinal profile of the ground
  along it or along a path drawn with the profile tool (lowest and highest points marked), and the
  curve of every pump with its duty point in each flow (and the curve at the speed a drive runs it).
- The sheet is also exported as **PNG** (96 to 300 dpi, the resolution lowered to stay within 40
  million pixels and 8192 pixels a side), from the same layout replayed on a raster.

### 24.9 PDF plans as an underlay

`pdf_reader.dart` (ISO 32000-1, and PDF 2.0 files written the same way) reads the file structure —
the header found within the first kilobyte, classic cross-reference tables and cross-reference
streams, object streams, the chain of incremental updates (the newest definition wins) and hybrid
files; a damaged or missing table is rebuilt by scanning the file for objects — and the stream
filters (Flate and LZW with the PNG and TIFF predictors, ASCIIHex, ASCII85, RunLength; for images
DCT passed through and CCITT fax). JPEG 2000 and JBIG2 images are left out with a warning, decoded
streams are capped so a small file cannot expand into gigabytes, and encrypted files are refused
(`pdf_encrypted`), since even those that open without a password would need the RC4/AES ciphers. A
page is interpreted on demand into neutral items in displayed page space (points, times /UserUnit,
origin at the bottom-left corner of the crop box, /Rotate applied, so the plan comes in the way a
viewer shows it): outlines, with curves flattened within a tolerance tied to the page size and the
stroked segments of one style that meet end to end merged into polylines (CAD programs often write
every line on its own); text runs joined along their baseline with origin, height and angle, decoded
through the ToUnicode CMap, else the font encoding (WinAnsi, MacRoman, Standard, Symbol, Differences
with the standard glyph names) or the Unicode CMaps of composite fonts, invisible text (the OCR layer
of scans) left out; and images re-encoded as PNG with the four corners of the raster. Optional
content groups name the layer of what they enclose, content of layers off by default is marked
hidden, and clipping is approximated by the bounding box of each clipping path intersected along the
graphics state stack (what a map frame or a CAD viewport hides stays out, nothing visible is lost);
shadings, patterns, transparency groups, annotations and Type 3 glyph drawings are not interpreted,
and the work of a page is capped (200 000 path segments, `pdf_truncated`).

`pdf_import.dart` places a page in the drawing at the paper scale: at 1:N one PDF unit (1/72 inch on
the sheet) is N × 0.0254/72 m, or a factor for a plan written in metres or millimetres; the scale
written on the sheet (`ESCALA 1:500`, `Scale 1/200`, a lone `1:250`) is detected and proposed, and the
two-point align and georeference tools then fit the plan to known points. Two-point paths become
lines, longer ones polylines, closed paths closed polylines; filled areas come in as outlines
(paper-white masks and a fill covering the whole page left out); texts keep their height and angle;
images their corners (a mirrored image flipped). Every import has a layer, one per PDF layer below it
and optionally one per colour, with the plan's colours made visible on the dark canvas.

### 24.10 SVG and XLSX

- **SVG**: the same scene as the PDF sheet in millimetres, one group per layer.
- **XLSX**: minimal SpreadsheetML (Office Open XML): one sheet per table, bold header, numbers as
  numbers and inline strings, without a shared-strings table; a reader of the same subset allows
  re-importing catalogues edited in a spreadsheet.

### 24.11 Verification with independent readers

The readers and writers are checked against third-party software, not only against each other.
`tool/formats/make_fixtures.py` writes to `test/fixtures/formats` import files produced by other
libraries: DXF R12, R2000, R2010 (in millimetres) and R2018 from ezdxf with blocks, bulges, MTEXT
and a 3D polyline; DWG R2000 from LibreDWG; shapefiles from pyshp (UTM polygons with `.prj`, Z
polylines with an ELEV attribute, WGS84 points, Z multipoints, a bare `.shp` in local
coordinates); GeoTIFF from tifffile (float32 UTM DEM with nodata, int16 geographic DEM, RGB
orthophoto); PNG and JPG from Pillow with world files, one of them rotated 30°; Google Earth style
KML and KMZ with nested folders, MultiGeometry, SchemaData and an inner ring; manufacturer CSV and
openpyxl XLSX catalogues. LAS files of every version and point format (one on SAD 69, a compressed
copy) and DGN V7 files in 2D and 3D, written by independent writers too, are checked by
`las_test.dart` and `dgn_test.dart`. `test/core/formats_test.dart` imports every file of the
script and checks positions, elevations, names and layers, and writes every export to
`build/formats`, which
`tool/formats/check_exports.py` validates with ezdxf (audit), LibreDWG (`dwgread`, `dwg2dxf`),
lxml (KML, SVG), openpyxl, pypdf and the RFC 7946 rules for GeoJSON. That battery found and fixed:
UTF-8 DBF attributes read as Latin-1; a local shapefile without `.prj` taken for lat/lon; an
inverted sign in the rotation of world files and ModelTransformation; blocks, dimensions and 3D
polylines ignored in DXF and DWG; relative handles, xref bits in R2007+ and the object header order
in R13/R14 in the DWG reader; names with inch quotes (1/2") breaking the reading of XLSX
catalogues.

### 24.12 Project and catalogues

The `.oci.json` project and the `.oci.cat` catalogue are JSON with `format` and `version` keys; the
structure is in the manual (docs/manual/file-formats.md) and in `catalogs/README.md`. The decision to embed the
catalogue in the project makes the file self-contained and readable; the library of user blocks
travels in the project too, and the DXF and DWG exports write it as block definitions.

### 24.13 Curves read off a picture

Modules `curve_digitiser.dart`, `curve_trace.dart` and `curve_fits.dart` (Design → Digitise a curve from a picture).

- **Calibration**: two clicked points per axis give its values and its direction (the vertical value does not change
  along the horizontal axis and the other way round): six equations for the six coefficients of the general affine
  mapping u = a·px + b·py + c, v = d·px + e·py + f, where u and v are the values of the axes or their decimal logarithms
  on a logarithmic axis. Rotated and sheared scans read exactly; a perspective is not affine. The calibration is refused
  when two points of an axis coincide, its two values are equal, a logarithmic value is at or below zero, or the axes
  were clicked less than 10° apart (an error of the clicks is amplified by up to 1/sin 10° ≈ 5.8: a guard against an
  ill-conditioned mapping, not an engineering threshold).
- **Trace**: the colour clicked is the pixel nearby that differs most from the background; the pixels kept lie between
  the background and that colour within a tolerance (60 RGB units by default, at most half the distance between curve
  and background), so the blended edge of an anti-aliased line counts and a light grid or a curve of another colour
  does not. The trace steps one pixel along the horizontal axis, takes the run of pixels nearest to where the last
  steps lead, bridges gaps up to 12 pixels and stops at longer ones; it assumes one value of the curve for each
  horizontal value. These are algorithm settings, documented in the code.
- **Fits**: the head points go through `PumpCurve.fit` (section 12): the least-squares parabola when it stays within
  3 % of the highest head (the head tolerance of acceptance grade 1B of ISO 9906) without a hump, else the monotone
  piecewise cubic through the points (Fritsch & Carlson 1980); without an efficiency curve the shaft power gives
  η = ρ·g·Q·H / P at each power point, H read on the fitted head curve (P taken as the shaft power, P2). The flow–pressure
  points are fitted to q = k·Hˣ by least squares in log–log space (`EmitterCurve.fitTable`, section 8), and a radial
  profile is normalised by the wetted radius read and the largest rate (the measured profile of the densogram, section
  9.1).

The tests recover exact values on straight, rotated (25°), sheared (axes 78° apart) and logarithmic charts, trace a
synthetic 660 × 440 chart with a grid, a crossing curve and a legend within 0.15 m of head (one pixel is 1/7 m), and
check the fits by hand (a shaft power of 8 353.28 W at 0.02 m³/s, 32 m and η 0.75; a 4 L/h orifice dripper at 10 m).

---

## 25. Performance and software architecture

- **Pure Dart engine** (`lib/core`, about 74 thousand lines), without Flutter, run in a Web Worker
  in the browser and in an isolate on desktop. The protocol (`design_job.dart`) sends the project as
  JSON without images and receives progress, results and the resized entities; an edit counter
  discards the results of a project changed during the calculation. The same engine runs in the Dart
  VM behind the command line `bin/oci.dart` (design, analyze, check, export, bom) and is a library of
  its own, `lib/core/api.dart`, documented with runnable examples in `docs/API.md`.
- **Spatial index**: a static R-tree packed by Sort-Tile-Recursive (Leutenegger et al., 1997):
  items sorted by x, sliced into √P strips, every strip sorted by y and cut into leaves of 12
  items; parent nodes are packed the same way up to the root. O(n log n) construction on every
  edit, O(log n + k) query with the indices returned in drawing order. Measured with 40 thousand
  entities: construction in about 30 ms, visible-window query in 9 µs against 700 µs for a linear
  scan. The painter, the selection, the window selection and the snap query the index.
- **Canvas**: the scene (base map, entities, results, labels) is recorded once per change of what
  it shows and drawn from a picture of it while only the cursor moves; the snap marker, the tool
  preview and the item under the cursor are painted over it. Drawing calls are gathered by paint and
  vertices closer than a pixel are left out. In CanvasKit an anti-aliased stroke wider than one
  device pixel is rasterised on the CPU over the bounds of its path, so 1 px lines are hairlines on a
  standard screen and wider strokes go as separate segments with square ends (quads on the GPU); a
  view with more than 40 thousand vertices of linework on a high-density screen draws its 1 px lines
  as hairlines. A scene that takes more than 20 ms follows a pan or a zoom as a moved picture and is
  drawn sharp 120 ms after the view rests (or every few hundred milliseconds while it keeps moving).
  The snap tests only the segments within reach of the cursor (pairing every segment of two long
  contours for their crossing took seconds). Measured in Chrome on a project of 34 thousand
  entities on 178 layers, on a standard and on a 2× screen: a mouse move from 600 and 880 ms to under
  two frames, a pan step from 320 and 465 ms to under two frames, a zoom step from 0.8 and 1.6 s to
  about 85 ms, a selection from 630 and 935 ms to about 180 ms.
- **Emitter lumping**: every lateral becomes up to 100 nodes with grouped emitters
  (`maxNodesPerLateral`); a block of 44 tapes of 120 m has 4400 nodes and sizes in about 2 s. Tapes
  of neighbouring zones with coincident ends are merged by the graph builder, which doubles the zone
  and the time: the examples leave strips between blocks.
- **Sparse solver**: LDLᵀ with minimum-degree ordering; the matrix of branched zones is almost a
  tree, without fill-in.
- **Undo**: entity snapshots on every action, up to 150 steps while the copies kept stay below
  400 000 entities in all (a large drawing keeps fewer steps), with labels for the history panel; a
  turn of the AI assistant is one step (section 27.10).
- **Storage**: browser key/value with autosave, recents, versions and recovery, within the limit of
  about 5 MB per origin (3.5 MB per project). A project larger than 256 kB of JSON is stored gzipped
  and base64-encoded, which keeps projects of tens of megabytes of JSON within the quota (their text
  compresses about tenfold); the automatic copy says once when it leaves out embedded images or
  cannot keep a project. The copy made after edits and designs is compressed by the browser
  (`CompressionStream`, base64 by `FileReader`) in the background and stored when done; compressing
  it in Dart on the interface thread held the app for about a second after a design of the row-crop
  example and for eight seconds on a project of 34 thousand entities. The design assistant's
  messages come built with the design from the worker (their check triangulates the terrain), and
  the design's progress messages do not invalidate the cached drawing.
- **Share link** (`share_link.dart`): a project travels inside the address itself, gzipped and
  base64url-encoded in the fragment (`#p=…`), the part of an address browsers never send to any
  server; embedded pictures and design results are left out (the receiver designs again), a link
  longer than 60 000 characters is warned about (e-mail and chat apps may cut it) and one longer
  than 1.8 million refused.
- **Offline start**: the web build is a progressive web app with its own service worker, registered
  once the app has painted and the browser is idle; it caches the files of a build, each checked
  against its SHA-256, one cache per build, and a page keeps the build it started with. After the
  first visit the app starts without a network; map tiles, elevation and climate downloads and the
  AI assistant still need it.
- **Interface**: 20 languages, right to left for Arabic and Urdu; designed for touch as well; the
  web app works on phones. The `android/` and `ios/` folders exist, but no native mobile build is
  produced or tested.
- **Themes**: dark (the default) and light, switched live under View → Theme (or following the
  system) without losing the open projects or dialogs. Every interface colour is one of 76 tokens of
  a palette with a dark and a light value (`lib/app/theme.dart`), read when painting; the light text
  tokens are checked for a WCAG AA contrast of 4.5:1 on every light surface
  (`test/widget_theme_test.dart`). On the white canvas of the light theme the drawing and result
  colours follow the usual CAD display rule: white and near-white colours (relative luminance above
  0.85) draw near-black, other light colours are darkened in linear light to a luminance of 0.20
  (4.2:1 against white) keeping their hue, and darker ones are drawn as they are; the selection is
  magenta instead of yellow. The data never changes colour, and the plots and exports (PDF, SVG, PNG
  and the CAD files) are paper and do not follow the interface theme.
- **Site**: pages generated with real HTML content for the search engines, because Flutter paints
  on a canvas (see docs/manual/languages-and-site.md).

---

## 26. Design assistant

Modules `advisor.dart` (read-only) and `auto_fix.dart`; panel `advice_panel.dart` (Messages tab and
design check).

- **Advice**: the design check, a sweep of the settings and the messages of the latest results are
  merged into one list; each problem has a severity (error, warning, note), the items and the
  zone / system flow involved, an explanation (why it matters, how to fix it) and the automatic
  corrections that apply. The same problem reported by several flows is shown once with the flows
  listed; without any water supply the unconnected mainline items are not repeated. Every message,
  the new ones included (pressure class, valve-in-head stations, variable-speed drives, NPSH, the
  sprinkler package, corner arm, variable rate and electrical design of the machines, unpriced
  materials), has its explanation, and an "Ask the AI" button hands it to the AI assistant
  (section 27).
- **Design check** (`design_check.dart`), among others: a zone that mixes drip or bubblers with
  overhead emitters, or overhead heads whose water per wetted area (flow over the sector they wet at
  the nominal pressure, on the circle of the family's longest throw) differs by more than 1.8 times
  (sprays with rotors, part circles with the nozzle of a full circle), since one run time cannot suit
  both (`zone_mixed_emitters`); valve-in-head stations no system flow lists while the project has
  flows (`vih_not_in_flow`).
- **Impossible settings**: velocity limits outside 0.3–5 m/s, hours per year outside 1–8760,
  interest outside 0–50 %, term outside 1–100 years, pump efficiency outside 20–95 %, negative
  tariff, connection tolerance outside 1 mm–1 m, zone variation outside 0–60 %, water temperature
  outside 0–60 °C, no enabled catalogue pipe for a use the design needs, supply maxima below the
  design values, zones in no system flow, empty flows, zero durations, emitter or tape pressures
  outside the nozzle / tape range (which makes the pressure window empty) and pump speeds outside
  40–130 %.
- **Corrections** (one undo step each): join an unconnected item to the closest compatible pipe or
  item within max(2 m, 20 × tolerance), cutting the pipe under it (a valve prefers the point where
  the mainline meets the start of its zone); delete zero-length pipes; remove repeated vertices and
  duplicated items; rename repeated zones; calculated supply pressure; the catalogue pump with the
  lowest life-cycle cost that meets every duty of the supply (only submersible ones when the water
  is deeper than the suction lift), or a new one on the pipe leaving the supply; the cheapest pipe
  of the same use whose class, derated for the water temperature, withstands the steady (or steady +
  surge) pressure with a bore not smaller; the smallest control valve whose range covers the zone
  flow; a catalogue model for a missing one; system flows regrouped first-fit decreasing so none
  exceeds the supply design flow (the scheduled valve-in-head stations moving with them); generic
  fittings; default parameters; a new flow for the zones left out; the nominal emitter pressure; the
  thicker catalogue wires enabled (or the default wires added) when a solenoid gets too little
  voltage; the next standard controller size (4, 6, 8, 9, 12, 16, 24, 32, 48 stations…) when a
  controller has more valves than stations. Joining crossing pipes and placing a supply at the only
  free mainline end guess the intent and are offered, never applied on their own.
- **Fix automatically**: rounds of safe corrections — drawing and settings first, then the ones
  that need results — each followed by a design, until a round changes nothing (at most six), all
  in one undo step; a correction already tried is not repeated.
- **Optimise**: LP sizing with the energy cost, optionally every pipe free, the smallest suitable
  valve per zone and the lowest life-cycle-cost pump per supply; the result is kept only when it
  has fewer errors or, with as many, a lower annual cost (annualised investment + energy).
- After a design with errors the Messages tab opens by itself and its label counts the problems.

### 26.1 Design scorecard

Module `scorecard.dart` (Design → Design scorecard). The scorecard turns what the results, the design check, the advice
and the analyses already compute into one index, reproducible from the table it prints. Every indicator has a value, a
target, the source of the target and a score from 0 to 100 given by a piecewise-linear function between stated anchors
(value → score), held at the end scores beyond the first and the last:

| Indicator | Anchors (value → score) | Where the target comes from |
|---|---|---|
| Emission uniformity EU (drip and micro zones) | 0 → 0, 70 → 60, 80 → 70, 90 → 80, 94 → 90, 100 → 100 | The ASAE classes of ASABE EP405.1 as section 9 states them (above 94 % excellent, 90–94 % good, 80–90 % fair, below 80 % poor; Keller & Karmeli 1974); the anchor at 70 % is the program's own step inside the poor class |
| Overlap CU (sprinkler zones) | 0 → 0, 75 → 60, 85 → 80, 100 → 100 | 85 % satisfactory (Keller & Bliesner 1990; ISO 15886-3); 75 % is the limit of the program's own design check (`area_uniformity_low`) |
| Flow variation q_var | 0 → 100, 10 → 90, 20 → 70, 100 → 0 | 10 % desirable and 20 % acceptable as section 9 states them; the scorecard prints Keller & Bliesner (1990) beside them, but section 9 gives no reference for these two limits, so they stand as the program's working bands |
| A criterion that must hold everywhere | the share that meets it: 0 % → 0, 100 % → 100 | The velocity limit of each use (design parameters; ASAE S376.2), the pressure class at the water temperature (ISO 1452-2, ISO 4427-2, ABNT NBR 14312), the pressure window of the emitters (design parameters; ASABE EP405.1, UNE-EN 13742-1), the pressure each zone needs, the catalogue range of the pumps, 70–120 % of the best-efficiency flow (section 12), the soil intake (NRCS NEH 15-11), runoff (NRCS NEH 623 ch. 4), the peak FAO-56 demand in the window, the surge within the class (AWWA M23, M55), the NPSH margin and suction lift (ANSI/HI 9.6.1), the life-cycle cost against the cheapest alternative (NIST Handbook 135), the warnings of the check, a priced bill of materials |
| A count that must be zero | 0 → 100, 1 or more → 0 | Errors of the check and of the design; high points of the mainline without an air valve (AWWA M51) |

The anchor scores follow one convention, the grade bands A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, E below: the top class of a
standard ends at the A limit, the next at B, and so on. A share is weighted by pipe length, by the water the emitters
deliver, by flow (times the hours of the system flow for the pumps), by area or by count; the uniformity indicators are
flow-weighted means of the zones. A category is the weighted mean of its assessed indicators and the overall score the
weighted mean of the assessed categories, every weight 1 (the code takes others; the dialog does not edit them). The
points an indicator would add at 100 are (100 − s)·(w / Σw of its category)·(W / ΣW of the assessed categories), and
the list of improvements is sorted by them. An indicator that cannot be computed (no zone of its kind, no prices, an
analysis not run, a pump without an efficiency curve) is not assessed and left out of every mean; one without any
reference value (kWh per m³ and per ha·mm, cost and equivalent annual cost per area, energy share of the life-cycle
cost) is reported only. The share of the pump head the critical zone uses (the surplus head at the supply over the pump
boost) stands for the energy burnt in the valves, which the results define without splitting the critical path into
lift, emitter pressure and losses. Pivot uniformity, the full transient analysis, the 24-hour simulation and the
densogram DU are left out (their results are not kept with the design, or too slow for a table rebuilt after edits),
and application efficiency is an input, not a result. The ageing test runs the analysis of the design over its life
with its defaults (15 years, Hazen-Williams C −0.5 a year, roughness +0.01 mm a year, 10 % clogging, CV +0.05).

The tests check every function at, between and beyond its anchors, the means and the points to gain (raising an
indicator to 100 adds exactly its points), the orchard example (grade A, with EU, head use and energy recomputed by hand
from its results) and a deliberately worse variant (zone pipes forced to the smallest size: lower overall and more than
10 points lower in uniformity).

---

## 27. AI assistant

The optional AI assistant (Design → AI assistant…; commands AI, IA, ASK; a status-bar button on
windows at least 1000 pixels wide; the "Ask the AI" button of every design message) is an agent built
into the program: a conversation with a large language model that reads the open project, plans,
asks questions, changes the drawing and the settings with the user's permission, and runs the
program's own engine to check its work. It opens in a panel docked beside the drawing (400 pixels
wide; a bottom sheet over the drawing on phones), which stays open while the agent works, so the
user watches the drawing change, types further instructions and stops it at any time; each project
tab has its own conversation. It is serverless like the rest of the program: the browser (or the
desktop app) calls the provider of the chosen model directly with the user's own API key for that
provider, and the provider bills the usage to the user's account; the panel shows an estimate of the
tokens and the cost of every answer and of the conversation. Six providers are offered: Anthropic
(Claude), OpenAI (GPT), Google (Gemini), xAI (Grok), Meta (Muse) and OpenRouter, a marketplace whose
one key reaches the models of the others and many more through its own servers. The loop, the
tools, the permissions and the project data do not depend on the provider
(`lib/core/ai/agent_loop.dart`, `project_context.dart`, the tools of `lib/app/ai/`); the six clients
and their formats are sections 27.1 to 27.3. The clients of Google, xAI, Meta and OpenRouter were
written from each company's documentation of 2026-11-10 and are tested against scripted transcripts
that copy the formats it documents; none of them has been run with a real key.

### 27.1 Providers and models

`lib/core/ai/llm.dart` holds what the assistant needs from any provider: the models (`AiModel`, with
provider, tier and list prices), tokens and their estimated cost (`AiUsage`), errors (`AiError`),
cancellation (`AiCancel`), the parts of a message, and the HTTP exchange as an injected function
(`AiTransport`: fetch with an abort controller in the browser, the body read as a stream, without
cookies or referrer; `HttpClient` on the desktop; a scripted fake in the tests). `AiProvider` names
each provider with the only host its key is ever sent to, the page where keys are made, how its keys
usually start (a hint, never enforced) and the page of its billing. Six clients implement
`AiClient`: `AnthropicClient` (`claude_api.dart`, the Messages API), `OpenAiClient`
(`openai_api.dart`, the Responses API), `XaiClient`, `MetaClient` and `OpenRouterClient`
(`xai_api.dart`, `meta_api.dart`, `openrouter_api.dart`: the Responses APIs of xAI, Meta and
OpenRouter, which have OpenAI's shape, so each is `OpenAiClient` with its hooks changed: the address,
the headers, the body, the items replayed, the usage, the errors and the optional fields) and
`GeminiClient` (`gemini_api.dart`, Google's Interactions API, written from the neutral format by
`GeminiFormat`, section 27.3); the names of the first, Anthropic-only version (`ClaudeApi`,
`ClaudeModel`…) remain as aliases.

| Provider | Tier | Model (id) | US$ per million tokens, input / output | Notes |
|---|---|---|---|---|
| Anthropic | top | Claude Fable 5.2 (`claude-fable-5-2`) | 8 / 40 | thinking always on; needs 30-day data retention; long turns |
| Anthropic | top | Claude Opus 5.5 (`claude-opus-5-5`) | 4 / 20 | the default |
| Anthropic | intermediate | Claude Sonnet 5.5 (`claude-sonnet-5-5`) | 2 / 10 | |
| Anthropic | fast | Claude Haiku 5.5 (`claude-haiku-5-5`) | 0.1 / 0.5 | above 100 000 input tokens, 5 × |
| OpenAI | top | GPT-6 Astra (`gpt-6-astra`) | 10 / 50 | long turns |
| OpenAI | intermediate | GPT-6.1 Sol (`gpt-6.1-sol`) | 2 / 10 | |
| OpenAI | fast | GPT-6.1 Terra (`gpt-6.1-terra`) | 1 / 5 | |
| OpenAI | fast | GPT-6 Luna (`gpt-6-luna`) | 0.1 / 0.5 | |
| OpenAI | intermediate | GPT-6 Sol (`gpt-6-sol`), GPT-5.6 Terra (`gpt-5.6-terra`) | 2 / 10; 2 / 12 | earlier releases |
| Google | top | Gemini 4 Argon (`gemini-4-argon`) | 4 / 20 | half price until 2026-12-01; efforts low, medium, high; long turns |
| Google | intermediate | Gemini 3.8 Flash (`gemini-3.8-flash`) | 1.5 / 7.5 | half price until 2027-01-01; free tier; efforts low, medium, high |
| Google | fast | Gemini 3.5 Flash-Lite (`gemini-3.5-flash-lite`) | 0.3 / 2.5 | free tier; efforts low, medium, high |
| xAI | top | Grok 4.7 (`grok-4.7`) | 2 / 6 | from 200 000 prompt tokens, 2 ×; efforts low to xhigh; PDFs as text |
| xAI | fast | Grok 4.3 (`grok-4.3`) | 1.25 / 2.5 | as Grok 4.7 |
| Meta | top | Muse Wonder (`muse-wonder-1.0`) | 4 / 20 | long turns |
| Meta | intermediate | Muse Spark 1.3 (`muse-spark-1.3`) | 1.25 / 4.25 | |
| Meta | fast | Muse Ember (`muse-ember-1.0`) | 0.1 / 0.5 | above 200 000 input tokens, 3 × |
| OpenRouter | top to fast | Claude Fable 5.2, Opus 5.5, Sonnet 5.5, Haiku 5.5; GPT-6 Astra, GPT-6.1 Sol, GPT-6.1 Terra; Gemini 4 Argon, Gemini 3.8 Flash; Grok 4.7; Muse Spark 1.3 (`anthropic/claude-fable-5.2`…) | the makers' prices as OpenRouter lists them (Gemini 3.8 Flash 1.65 / 8.25) | the long-prompt rules of the makers; answers of at most 32 000 tokens (Fable 5.2, GPT-6 Astra) or 64 000 (Opus 5.5, Grok 4.7, Muse Spark 1.3) |
| OpenRouter | intermediate, fast | Auto Router (`openrouter/auto`), Free Models Router (`openrouter/free`) | the price of the model each picks; free | routers |

Cache reads and writes have their own list prices (writes at 1.25 times the input price, the rate of
Anthropic's five-minute cache; Google, xAI and Meta bill nothing for writing to their automatic
caches, and their usage reports no cache writes). OpenAI prompts above 272 000 input tokens cost
twice the input and cache prices and 1.5 times the output price; a rule of this kind (`longAbove`,
`longInput`, `longOutput`) applies to the whole request once its input passes the threshold. An
introductory price (`introUntil`, `introFactor`) multiplies every price until the day it names, and
the meter prices a request at the prices of its day. The models of Anthropic, OpenAI and Meta take
the five effort levels (low, medium by default, high, xhigh, max: Anthropic `output_config.effort`,
the Responses APIs `reasoning.effort`); a model that takes fewer (`AiModel.efforts`) gets the nearest
below (`effortFor`): Gemini's thinking levels stop at high, Grok's at xhigh. The models with long
turns get longer timeouts (section 27.2). `vision`, `pdf`, `tools` and `priced` say whether a model
reads pictures, reads an attached PDF whole (else the PDF goes as its text, extracted on the device),
calls tools, and has known prices (a router has none). The cost of an answer is priced at the model
that actually served it (a refusal fallback may be another model, Claude Opus 5 or Opus 4.8, priced
though not offered; a router reports the model it chose), with Anthropic's compaction iterations
added to the top-level counts; an answer of a model the table does not price costs what the
provider says it charged (`AiUsage.charged`, OpenRouter's `usage.cost`). Switching to another
company, or between two models of a company other than Anthropic, starts a new conversation (the
earlier one is not sent); a Claude model can take over the conversation of another Claude model. A
choice or a kept conversation of Claude Fable 5.1 goes on with Claude Fable 5.2, which replaced it.
Claude Fable 5.2 asked from an organisation without 30-day data retention is refused by the API; the
error is recognised and the message suggests Claude Opus 5.5.

**Models from OpenRouter's list** (`openrouter_catalog.dart`). `GET https://openrouter.ai/api/v1/models`
(public, no key, no header of the app) gives every model OpenRouter serves; a row becomes an `AiModel`
of OpenRouter when its endpoints include the Responses API, it answers in text and it has a price
(aliases left out): the prices per token as listed (per million in the app), the cache prices when
listed (else the input price), the first price override that depends on the prompt's length alone
(those by hour of the day ignored), the efforts it lists, the output limit of its top provider (32 000
when none is given) capped at 128 000 tokens and half the context window, and whether it reads
pictures and calls tools. Its tier is a band of the output price (top from US$ 15 per million tokens,
intermediate from 4, fast below; routers intermediate), not a judgement of quality. The models the
user adds are kept in the preferences and registered again at start (`AiModel.register`); the last
copy of the list is kept on the device for offline use.

### 27.2 Requests and streams

**Anthropic** (`POST https://api.anthropic.com/v1/messages`, `anthropic-version: 2026-10-21`). The
headers carry the key (`x-api-key`), in the browser `anthropic-dangerous-direct-browser-access: true`
(without it the API sends no cross-origin headers and the browser blocks the answer), and
`anthropic-beta` with the betas the request uses (`server-side-fallback-2026-07-01`,
`task-budgets-2026-03-13`, `context-management-2025-06-27`, `compact-2026-01-12`). The body: the
model, `max_tokens` (the model's output limit, 128 000 on the Claude 5.x models, lower under a spending
cap), `stream: true`, the system prompt as one text block with a cache
breakpoint, the tools in a fixed order, each with `eager_input_streaming: true` (inputs stream as
they are generated, which is why the loop checks every input itself), the messages since the last
compaction, `thinking: {type: "adaptive"}` (left out for Fable 5.2, which always thinks and takes no
setting), `output_config` with the effort and, when the caller gives one, a task budget
(`task_budget: {type: "tokens", total}`, at least 20 000 tokens) the model paces itself against (the
assistant gives none: a token countdown shown to the model made it stop early, so the app's own step
limit and spending cap end a task), a top-level `cache_control` (automatic
caching of the growing conversation), `fallbacks: "default"` on Fable, Opus and Sonnet (a request a
safety classifier declines is answered by another model instead of failing), and the context
management of section 27.5. The stream (server-sent events): `message_start` (model, usage),
`content_block_start`, `content_block_delta` (text, thinking, signature, the JSON of a tool input,
citations, a compaction summary) and `content_block_stop`, `message_delta` (the stop reason with its
details: the category and explanation of a refusal), `message_stop`, `error` and `ping`. Thinking
blocks go back in the history unchanged, with their signatures; after a fallback in the middle of an
answer, the thinking and tool-use blocks before the last fallback marker are left out (their text
kept) and the marker is dropped.

**OpenAI** (`POST https://api.openai.com/v1/responses`). The key goes as `authorization: Bearer`. The
body: the model, `instructions` (the system prompt), `input` (the conversation: the output items
exactly as they came back, the function outputs, the user's messages), the function tools with
`strict: false` (the schemas have optional fields, which strict mode does not allow; the loop checks
the inputs itself), `reasoning: {effort}`, `max_output_tokens` (the model's output limit, 128 000 on
the GPT-6 models, lower under a spending cap), `stream: true`, `store: false`
(nothing is kept on OpenAI's side for later requests) with `include: ["reasoning.encrypted_content"]`,
so that the reasoning items come back encrypted and go back in the next request, and the context
management of section 27.5. Pictures are `input_image` parts (data URLs, detail "auto") and PDFs
`input_file` parts (file name and data URL). The stream: `response.created`, `in_progress` and
`queued`; `response.output_item.added` and `.done`; `response.output_text.delta`;
`response.function_call_arguments.delta`; `response.completed`; `response.incomplete` (the length
limit, or `content_filter`, a refusal); `response.failed` (policy codes such as `bio_policy`,
`misalignment_policy_violation`, `invalid_prompt` and `image_content_policy_violation` are refusals);
and `error`. The refusal parts of a message are a refusal too. Cached input tokens come from
`input_tokens_details` (cached and cache-write tokens).

**xAI** (`POST https://api.x.ai/v1/responses`, `XaiClient`). The Responses request of OpenAI with
`store: false` and `include: ["reasoning.encrypted_content"]` (the encrypted reasoning goes back
unchanged; asking for it also keeps xAI from storing the thinking trace for later requests), a
`prompt_cache_key` derived from the system prompt and the first entry of the conversation (stable for
a conversation, so its requests reach the server that cached its prefix; xAI's cache is automatic and
writing to it is free), the sampling xAI's guide asks for (`temperature` 0.7, `top_p` 0.95) and
function tools only; no `context_management` (xAI parses it but does not run it; `compact()` calls
xAI's stateless `/v1/responses/compact` and is tested, not wired into the loop). The usage leaves the
reasoning tokens out of `output_tokens` and they are added back (billed at the output price). Grok
reads JPEG and PNG only, so a WebP or a GIF is converted at the same size (a picture with
transparent pixels or a GIF to PNG, the rest to JPEG), the result kept so that the bytes stay the same
from one request to the next; the app sends a PDF as its text, since an attached file turns on xAI's
attachment search, a server-side tool billed per call. Errors come as `{"code": "…", "error": "…"}`;
a key xAI does not know gets a 400, read as an authentication error.

**Meta** (`POST https://api.meta.ai/v1/responses`, `MetaClient`). The Responses request with
`store: false` and `include: ["reasoning.encrypted_content"]`, never `previous_response_id`; the output
items go back as they came, but a reasoning item without its encrypted content, or with nothing
after it, is left out of the request (the stored history keeps it), and assistant text before a call
carries `phase: "commentary"`. A constant `prompt_cache_key` for the app; no `context_management`
(the API has none) and no built-in tool. Pictures go in user messages and inside function outputs as
`input_image` data URLs, PDFs as `input_file` data URLs. The errors follow Meta's statuses, types and
codes (402 billing, 503 overloaded, 504 not retried, since the same request would time out again), and
three are recovered: a request that does not fit the context window is sent again asking for the
room left (at least 16 000 tokens), an output limit the API names is learnt for that model, and a
reasoning item the API no longer accepts is dropped from the request.

**OpenRouter** (`POST https://openrouter.ai/api/v1/responses`, `OpenRouterClient`). Stateless only
(OpenRouter refuses `store: true` and `previous_response_id`): the Responses request with
`store: false`, no `context_management` (not in its request schema), a top-level `cache_control`
(`{type: ephemeral}`) that turns on the automatic cache breakpoint of the models that need one,
Anthropic's above all (not sent to OpenAI's models, which cache by themselves), a `session_id`
derived from the system prompt and the first message, which keeps the requests of a conversation on
one provider so that its cache is found again, and two headers that name the app for OpenRouter's
rankings (`HTTP-Referer: https://opencadirrigation.com`, `X-OpenRouter-Title: OpenCADIrrigation`),
nothing about the user. Replayed assistant messages, reasoning items and calls carry the ids
OpenRouter requires; the reasoning of every maker comes back as `reasoning` items (OpenAI's encrypted
content, Anthropic's thinking text with its signature, Google's thought signatures) and goes back as it
came. The pictures of tool results stay inside the function outputs for the `anthropic/` and `openai/`
models and go in a user message right after the results for the others. A PDF goes to a model that
reads files itself as it is, and otherwise through OpenRouter's free parser (`plugins: [{id:
file-parser, pdf: {engine: cloudflare-ai}}]`). The usage carries the `cost` OpenRouter charged, and
the answer names the model that answered. Errors are read from OpenRouter's canonical `error_type`
beside the Responses `code`: 402 no credit (the in-flight spending budget, which holds the price of
the largest answer a request allows, is waited for), 403 budgets, moderation and guardrails, 408,
429 (the free models' daily limit waits until 00:00 UTC and is not retried), 502 and 503 no provider.

**Google** (`POST https://generativelanguage.googleapis.com/v1beta/interactions`, `GeminiClient`). The
Interactions API, which Google recommends for new projects, in its stateless mode: `store: false`, the
whole conversation in `input` as a list of steps, the key in `x-goog-api-key` and `content-type` the
only headers (what the CORS preflight allows), `system_instruction`, the function tools (their
schemas converted to the subset of JSON Schema Gemini takes, the limits it does not take written into
the descriptions), `generation_config` with the `thinking_level` of the effort and `max_output_tokens`,
and `stream: true`. The stream: `interaction.created`, `interaction.status_update`, each step as
`step.start` → `step.delta` (text, the JSON of a call's arguments, a thought signature) → `step.stop`,
`interaction.completed` with the usage (input, cached, output, thought and tool-use tokens), and
`error`. `thought` steps carry an encrypted signature that stateless mode must send back exactly as it
came, in its place. Pictures go at the media resolution `ultra_high` (2240 tokens a picture), or `high`
for a model that turns it down; a request is kept under 20 MB; a model with long turns waits at least
15 minutes for the next event. A safety, recitation or other policy block ends the answer as a
refusal with its category; quotas say whether to wait (with the wait Google gives in the body, since
the page cannot read `retry-after`) or to set up billing.

**Errors and retries** (every client): the error types are told apart (authentication, permission,
billing — OpenAI's `insufficient_quota` —, not found or a model the account cannot use, invalid
request, request too large — `context_length_exceeded` —, rate limit, overloaded, server, network,
timeout, interrupted stream, data retention, no credit, a spending limit, a refusal); overloads, rate
limits, server and network errors are retried at most twice, after the `retry-after` (or
`retry-after-ms`) the API asks for, up to 30 s, or an exponential backoff (2 s, 4 s for rate limits,
1.5 s for the network, doubling), never once part of the answer has arrived. A request times out with
no status line after 90 s, or no data for 180 s (300 s and 600 s for the models with long turns, which
may think for minutes; the idle time doubles at the two highest efforts). An optional field a model
turns down (an invalid-request error that names `fallbacks`, `task_budget`, the context management,
the clearing of tool results, or a field of the newer clients such as `prompt_cache_key`,
`cache_control`, `session_id` or the `ultra_high` resolution) is dropped and the same request sent
again at once, and left out for that model for the rest of the session; a rejected combination of context edits drops
the clearing first, then compaction. The key is removed from every error text, masked copies of it
included.

### 27.3 One loop, two formats

The loop never looks into the providers' formats. `llm_formats.dart` holds the two wire formats in one
place
(`AnthropicFormat`, `OpenAiFormat`): tool definitions, the user's message (text, pictures, PDFs),
tool results (text and pictures, with an error flag, or, on OpenAI, whose function outputs have
none, the prefix `Error: `), notes from the program, and the tool calls and text of an answer. The
history of a conversation is kept in the provider's own format and only grows: an answer goes back
exactly as it came, and these functions only build new entries and read old ones. A round of
results is, for Anthropic, one user message with every `tool_result` first, then what the user wrote
meanwhile, then the program's note as a text block (which keeps the append-only history valid
however the turn goes on); for OpenAI, the `function_call_output` items, then a user message with
what the user wrote meanwhile, then the note as a `developer` message. Each format also reads its
own shapes back, and the tests check that every kind of entry reads back unchanged and that a whole
exchange converted from one format to the other and back loses nothing (`ai_formats_test.dart`). A
tool input whose JSON does not parse is kept raw and answered with an `INVALID_JSON` error result.

The Responses format is the neutral one the four newer clients share. xAI, Meta and OpenRouter speak
it as it is, each changing only what its API needs in the request (the items it replays, its
fields). Google's conversation is kept in it too and translated at every request by `GeminiFormat`,
deterministically (the same history always gives the same bytes, so that the implicit cache matches
the prefix): messages and function calls become Gemini's steps, function outputs become
`function_result` steps named after their calls, and any step of Gemini's own (a `thought` with its
signature) is kept in the history as a `gemini_step` item holding the step as it came, so that every
step goes back unchanged. A conversation never mixes formats: changing company starts a new one.

### 27.4 The agent loop

A task starts with the user's message and is a sequence of requests (`AgentLoop.run`): the model
answers with text and, possibly, tool calls; the program checks every call against the JSON schema
of the tool (types, enums, required and unknown fields, recursively, and the most items an array may
have), runs it on the open project and sends every result back, every call answered and in order;
the model goes on until it ends its turn without tools, the step limit is reached (a step is one
request; 50 per task by default, 5 to 200), the spending cap is reached (US$ 2 per task by default;
0.5 to 20, or none), or the user presses Stop. On the step before the last, a note asks the model to
call no more tools and to say what it did and what is left; at 80 % of the cap a note, once, asks it
to finish the step it is on and stop; past the cap no new request is made; calls asked for at the
last step, or after Stop, are answered with an error result that says so; and a task stopped by the
step limit or the cap shows a Continue button. Messages typed while the agent works are queued
("Send at the next step") and reach it with the next round of tool results, marked as written
meanwhile; what is still queued when the turn ends becomes the next message. A refusal, or a tool
call cut by the length limit, discards the answer with an error message; when nothing came back the
question and its attachments stay ready to be sent again. Results longer than 16 000 characters are
cut with a note asking for less (a filter, paging). The text streams into the panel as it arrives,
with a status line (thinking, running a tool, waiting for an approval, waiting before a retry) and
the elapsed time.

**Second opinion** (`/second`, or the button on the last answer). The last answer, the user's
question and the whole compact project data (section 27.9) go to another model in one request
without tools (the medium effort, or the nearest the model takes, and at most 16 000 output tokens),
to that model's company with its own key: the models of the other companies the user has a key for
come first, each company's most capable first, then the other models of the conversation's company;
a router without known prices is left out. Its system prompt asks for a verdict (agree, agree with
reservations, disagree) and then the points, the most important first, each with the figure it rests
on, and says that the material is data, not instructions. The review is shown marked as a second
opinion and its tokens and cost are added to the conversation's, but it does not enter the history:
the conversation's own model reads it only when the user sends it on (*Answer the review*), as
quoted material to check point by point against the project with its tools.

### 27.5 Context management

Long tasks keep their requests bounded on the server, where the model takes it (a setting, on by
default; the whole conversation stays in the panel):

- **Anthropic**: threshold compaction (`compact_20260112`, triggered at 150 000 input tokens; the
  API takes no less than 50 000): the server summarises the earlier conversation into a compaction
  block that comes back with the answer, and from then on only the messages from that block onward
  are sent. The clearing of old tool results (`clear_tool_uses_20250919`, triggered at 80 000 input
  tokens, the last four tool uses kept, at least 10 000 tokens cleared at a time) removes old
  pictures and tables from the server's copy, never the results of the notes, the playbook, the
  manual, the questions, the plan, the to-do list and the operation search.
- **OpenAI**: server-side compaction (`context_management` with `compact_threshold` 200 000): after a
  compaction item, the input starts at it. Pictures in tool results beyond the newest three are
  replaced by a short note once there are more than six (in steps, so the cached prefix changes
  rarely), in the request only: the stored history and the user's own pictures stay.
- **Google, xAI, Meta and OpenRouter**: no compaction on the server (their models have
  `compaction: false`); the older pictures of tool results are pruned from each request as for
  OpenAI.

A compaction is announced in the conversation.

### 27.6 Tools, operations and coverage

75 tools are sent with every request, in a fixed order, since they are part of the cached prefix
(their definitions take about 103 000 characters, some 26 000 tokens, cached with the system
prompt). Each is a thin wrapper over the controller and the engine, so the model works with the
program's own numbers and every change is an ordinary undo step:

- **reading**: project summary, items by type, layer or zone, one item with its properties and the
  report rows that name it, parameters, catalogue search, report tables, design messages,
  elevations, measurements; the analyses (transients, the 24-hour simulation, criticality, on-demand
  flows, energy grouping, uniformity), pump ranking and air valve suggestions; selecting and zooming
  to items and showing a message;
- **changing**: items (create, update, delete, transform), parameters, catalogue (items read from a
  manufacturer's data sheet the user attached, every value checked before insertion; removing an
  item in use is refused), system flows, layers, project details, quote and label rules; the design,
  a correction, fix automatically, optimise; the automations of section 19 (sprinkler layout with
  zoning and routing, lateral blocks, field subdivision, tree rings, sports templates, pivot fit),
  vegetation areas (section 20), pump, air valves, energy grouping and wire routes; an export
  (always confirmed);
- **pictures and the terrain** (section 27.7), with the outline of a field or of every field of an
  area traced on the imagery and a field photo pinned where it was taken as a review comment; **the
  site**: `find_site` (an address or place name through OpenStreetMap Nominatim: at most eight
  searches per conversation, at least a second apart, cached, with the attribution its terms ask
  for), `set_site`, the base map on screen, `download_terrain` and `download_climate` through the
  program's own downloads, and `import_attachment` for drawings and GIS files the user attached
  (DXF, DWG, DGN, KML/KMZ, shapefile, GeoJSON, GPX, LandXML, IFC, EPANET, LAS, GeoTIFF; up to 60 MB,
  never sent to the model);
- **the work itself**: a to-do list the user sees above the conversation; `ask_user` (one to four
  questions with two to four options each, answered on cards, where the user may write an answer of
  their own or skip); `present_plan`; the project's AI notes; a long attachment read in parts
  (`read_attachment`) or searched by a smaller model of the same company (`summarize_attachment`);
  the playbooks; the examples (list, read, open in a new tab); and the manual (section 27.8).

The descriptions tell the model the conventions: coordinates in metres with x east and y north, item
properties in SI as in the project file, reports in the project's display units, ids looked up
before they are used (an item may also be named, and an ambiguous name is an error listing the ids).
The tools check the values themselves (ranges, points, ids) before anything changes, so a refused
call leaves the project as it was, with a message the model can act on; a change is refused while a
design runs.

The rest of the program is reached through three dispatchers. `find_operations` and `run_operation`
cover 216 operations that are not sent, so the requests stay small, each with its own schema, effect
and confirmation: drawing edits (offset, trim, extend, split, array, align, stretch, fillet,
chamfer, break, join, explode), dimensions and revision clouds, blocks and their libraries, layers
and layer states, the view, undo, redo and the history, tabs, recent projects and versions, terrain,
georeference, datum and images, imports, the analyses and studies, calculators, machines, pump
stations and reservoirs, the agronomy of section 21 (daily water balance, irrigation programme,
field tests, fertigation by stage, the climate risk, the irrigation forecast and the programme
played on the plan), the power and water analyses, the technical documents and the title block,
sheets and their preview, the catalogue (with the curves read off a picture, section 24.13), the
crop rows read from the image (section 20.1), the design scorecard (section 26.1), comparisons and
review comments. `run_command` runs any command alias or action by name: a command that opens a
dialog runs the operation behind it, without the dialog, and a drawing tool that takes the user's
clicks answers with what to call instead. `get_setting` and `set_setting` cover 152 settings (the
design parameters, units, project details, quote, view, snapping, tool defaults and program
options), typed and range-checked. `docs/AI_TOOLS.md`, generated from the coverage map
(`ai_coverage.dart`) by `widget_ai_coverage_test.dart`, lists every function a user can reach and
what the model uses for it: 57 command actions, 62 drawing tools, 402 command aliases, 375 items of
the desktop and phone menus, 123 dialogs and 847 of their options, 333 panel fields, 13 status-bar
controls and 31 view options, 2243 in all, of which 2167 are covered and 76 have no meaning for the
model (the About box, the interface language…), each with its reason; none is missing. The test
fails when a new command, tool, menu item or dialog has no route, or a route leads nowhere. These
are the counts of version 1.7.0: `docs/AI_TOOLS.md` is regenerated with every change of the
coverage, and `web_docs_test.dart` fails when this section, the manual or the site's reference quote
other numbers than it.

### 27.7 Vision

The model sees the project through pictures with an exact mapping (`view_snapshot.dart`,
`vision_*.dart`):

- **`view_snapshot`**: one PNG of the drawing as the canvas draws it (layer colours, the result
  overlay) over a base map — `current` (the map the screen shows), `satellite` (aerial imagery: Esri
  World Imagery, or Google satellite through the Map Tiles API when the user set a Google key),
  `street` or `none`; by default the satellite image whenever the project is georeferenced, so that
  the model draws over what is really on the ground, otherwise the map on screen — with a labelled
  metre grid and, on request, labels (ids or names, hydraulic items first, overlapping labels left
  out) and a legend of the layer colours. The tiles are fetched off screen at the zoom of the picture (a tile pixel about one picture pixel; one level lower at a time
  where the imagery ends, z17–18 over most farmland, and the nearest ancestor where a tile is
  missing) and cached for the conversation (400 tiles); the user's view and base map never change,
  and only when the tiles of the map on screen cannot be fetched off screen does the view go there for
  a moment and come back, which the result says. A picture is at most what the model reads unscaled
  (`PictureLimits.of`; 1024 pixels on its longest side by default): 2576 pixels and about 3.6
  megapixels on the Claude models that read pictures at high resolution (Fable 5.2, Opus 5.5, Sonnet
  5.5 and Haiku 5.5, also through OpenRouter), otherwise 1568 pixels and about 1.15 megapixels, with
  the shorter side at most 768 pixels on OpenAI's models (also through OpenRouter), so that the
  provider does not rescale it and the model reads positions on the pixel grid described.
- **The mapping**: every picture has an id (`s1`, `s2`…; `u1`… for those the user attaches; the last
  80 kept per conversation) and states its mapping: north up, square pixels, the world bbox [minX,
  minY, maxX, maxY] and s metres per pixel, with x = minX + px·s and y = maxY − py·s for the pixel
  (px, py) counted from the top-left corner. `image_to_world` converts the pixels the model picks into
  project coordinates, and project points into pixels, exactly, up to 500 at a time, with the area,
  perimeter and centroid of a closed outline, so the model never does the arithmetic; a part of an
  earlier picture can be shown again at full resolution (`snapshot` with `pixel_bbox`).
- **`preview_geometry`** draws proposed points, polylines and polygons (up to 30 shapes and 5000
  points) in magenta over a fresh picture without changing the project, with each shape's
  coordinates rounded to 0.01 m, its length or area, and warnings (an outline that crosses itself, a
  polygon without area).
- **The terrain**: `terrain_picture` draws the relief from the terrain model, a hillshade lit from the
  north-west with colours by elevation (green low to white high, with the range) or by the slope
  classes of section 23.1 or the aspect, labelled contours at a round interval giving 10 to 15 lines
  (or a given one) and hatching where heights are far from any data, alone or over the satellite
  image and under the drawing, with the same mapping; `terrain_profile` gives the ground along a line
  or an item (length, rise and fall, the steepest slopes, the extremes, local high points where air
  gathers in a pipe, and a table of distance, x, y, z and slope); `terrain_info` says what the model
  is made of and how far its heights can be trusted.
- **The user's pictures**: the panel attaches a picture of the current view with its mapping (to
  point at things: "the mainline along this road"), and a setting, off by default since it costs
  tokens, sends a picture of the drawing with the results of every round that changed the project,
  so the model can check what it did.

The pictures of the drawing and of the satellite map go to the AI provider with the conversation,
and the imagery provider's terms of use apply to them, which the panel says.

### 27.8 Instructions, manual, playbooks and notes

The system prompt (`ai_prompt.dart`; in English, the model's working language; about 13 300
characters, some 3 300 tokens) is built from the program itself: what the program is; the facts
every request needs (numbers come from the tools and belong to the drawing they were computed for;
metres with x east and y north; SI in the tool inputs, display units in the reports); how the design
turns the drawing into a graph (the two scopes, the connection tolerance with its real default, what
joins what, where the mainline starts and what it must reach); what a design run does and when a
design is finished; the permissions; how to use the tools and work through a task (a to-do list for
three or more steps, the notes and the playbook first, the missing facts asked early in one call);
the indexes of the playbooks and of the manual; and the answering language, which follows the
interface unless the user writes in another. The user's standing instructions from the settings
are appended (`<user_instructions>`, from the next conversation on). It holds no project data and is
fixed for a conversation, so that the earlier reasoning and the cached prefix stay valid.

`read_manual` serves the details on demand: 20 topics (drawing, entities, parameters, catalogue,
design, flows, messages, verification, values, units, terrain, agronomy, machines, electrical,
reports, tools, operations, playbooks, mistakes and a worked example), several of them narrowed to
an item. Their tables are generated from the program when a topic is read (every item type and key
with its unit, default and panel label; every design parameter with its project-file key, range and
effect; every message code with its explanation and corrections; the catalogue; every tool and
operation with example calls; the values the engine uses), and the written parts are checked by
`widget_ai_manual_test.dart`, which fails when an item key, a parameter, a message code, a report
table or a tool is missing, when a default written by hand differs from the engine's, when the text
names a tool that does not exist or an example call does not fit its schema, and which replays the
worked example on a new project.

The twelve playbooks (`playbooks.dart`: drip orchard, row crops with tape, greenhouse, landscape
sprinklers, sports field, golf hole, centre pivot, linear move, gravity drip, nursery, pasture, coffee
on contours) are step-by-step workflows written from how the fifteen examples are built: what to
ask, the tools in order, typical values and checks, each starting from the satellite picture and
checking traced shapes before creating them. The project's AI notes (the client's requirements, the
user's answers, decisions; at most 8000 characters) are stored in the project file (`aiNotes`), so
they travel with it when it is saved or shared, written in one undo step, read with the first message
of each conversation, and editable in the settings.

### 27.9 Project data

What the model is told about the project with the first message (`buildProjectContext`) is a compact
text the user reads before anything is sent: every number comes from what the program already
computed — the report tables, the design messages, the design results —, so the assistant reads
exactly what the reports show, in the project units, with a header naming the units. The user ticks
the parts (the selection first, then the project summary, the messages, the results, the materials,
the parameters and the catalogue); the text is deterministic for a given project state, so the
preview is what is sent, and it is bounded to 18 000 characters (about four to six thousand tokens),
so a large drawing does not turn into a large bill. The budget is split among the parts by weights
(selection 15 %, messages 20 %, results 30 %, materials 10 %, catalogue 11 %, project and parameters
7 % each); a part that needs less leaves the rest to the others, and a shortened part says how many
lines were left out. The token estimate shown is rough (no tokenizer offline: about four Latin
characters per token, fewer for other scripts). The data can be attached again to a later message,
and the model reads more with its tools.

### 27.10 Permissions, the plan, undo and checkpoints

Every tool declares its effect — read, write (an undo step), export (a file) or network (a request
to another service that changes nothing) — and a dispatcher takes the effect of what it runs. The
mode (`AgentPermission`) decides what a call needs:

- **read only**: changes (the terrain and climate downloads among them, since they add data to the
  project) and exports are refused with an explanation the model passes on (it may describe the
  change instead), while lookups that change nothing (the address search, a catalogue pack at an
  address) still run, with the user's approval;
- **plan first**: the model explores with the read tools and presents a plan (`present_plan`, a card
  with "Approve, ask before each change", "Approve, apply automatically" and "Ask for changes");
  changes are refused until it is approved, and then run in the mode chosen, within the same task
  (lookups that change nothing are asked, as in read only);
- **ask before each change** (the default): a card with Apply, Skip and Stop for every change and
  every request to another service (the site search, the terrain and climate downloads); a skipped
  change goes back to the model as declined, not to be repeated unless the user asks;
- **apply changes automatically**: changes and requests to other services run as they come, but
  exports, the deletion of more than 20 items, moving an existing georeference and the few other
  steps that cannot be undone are still confirmed.

Every AI turn is one entry of the history: the first change opens an undo group and the end of the
turn closes it, with a summary of what changed (items added, changed and removed by kind, and which
settings: parameters, catalogue, system flows, layers, project details, quote, label rules) and an
"Undo these changes" button that works while nothing else has changed in the project since; results
the assistant computed after its last change are kept. Every message of the user is also a
checkpoint: "Rewind to here" takes the conversation back to before it and the project to the state
it had then, through the undo history (redo brings it forward again), the state being found by the
label and time of the step that led to it, since positions shift when old steps are dropped; when
the history no longer reaches it, only the conversation goes back. The message returns to the input
box.

Quick commands in the input box: `/new`, `/clear`, `/cost` and `/plan` act at once (a new
conversation, the cost so far, plan mode), and `/design`, `/check`, `/report`, `/quote` and `/export`
send a prepared request. The conversation can be saved as Markdown (the messages, every tool call
with its summary and state, the changes and the cost), and an answer can be copied or inserted into
the drawing as text, such as the written technical report the assistant drafts from the design.

### 27.11 What is sent, and the keys

Nothing is sent until the user sends a message. The request then carries the message, its
attachments (pictures; PDFs as documents or, by choice, their text extracted on the device by the PDF
reader of section 24.9, which takes far fewer tokens but loses the figures and the layout of tables;
text files; up to 20 MB each; drawings and GIS files only as a note that they are there, for
`import_attachment`), the project data the user ticked and the project's AI notes (with the first
message), the earlier messages of the conversation, the system prompt and the tool definitions, and,
while the model works, the results of the tools it calls (tables, items, pictures). Tools that ask
other services (the address search, elevations, climate, catalogue packs at an address) send them
only what they need and ask for the user's approval unless changes apply automatically. The "Data
sent" view shows the exact text of the next message, the instructions and the tools.

Each provider has its own key. A key is kept in memory for the session by default; with "Remember
the key on this device" it goes into the browser storage, where the scripts of the page (the site's
visit statistics among them) could read it, which the panel says. It never enters a project file,
the autosave, a share link or an export, it goes only to its own provider's API host
(`api.anthropic.com`, `api.openai.com`, `generativelanguage.googleapis.com`, `api.x.ai`, `api.meta.ai`
or `openrouter.ai`), in its header, and it is removed from any error text, masked copies included.

### 27.12 Validation

`ai_agent_test.dart` covers the Anthropic requests and stream (the request the API documents, Fable
5.2's settings, task budgets and compaction where the model takes them, optional fields dropped, the
clearing of tool results) and the loop (its tools and history, invalid inputs, the modes and plan
mode, confirmations, the step limit, the spending cap, steering, stopping, errors and retries, data
retention, refusals, fallbacks and their prices, the key only in its header); `ai_openai_test.dart`
the Responses API (the request, function outputs, pictures and PDFs, compaction, the pruning of
pictures, errors, the model list); `ai_gemini_test.dart`, `ai_xai_test.dart`, `ai_meta_test.dart` and
`ai_openrouter_test.dart` the four newer clients against scripted transcripts that copy each
company's documented formats (the request, tool turns replaying the reasoning byte for byte, pictures
and PDFs, streams, usage and cost, stops and refusals, every documented error and retry);
`ai_openrouter_catalog_test.dart` OpenRouter's list read into models; `ai_providers_test.dart` the
hosts, key pages, prices and introductory prices of the companies; `ai_formats_test.dart` the two
formats; `ai_context_test.dart` the project data. Widget tests cover the tools, the vision (the exact round trip of the mapping, the
satellite picture leaving the user's view and map as they were, terrain pictures and profiles on
known surfaces), the operations, the coverage map, the manual and the whole agent (a small project
from the questions to the report, steering, rewind, the cap and Continue, quick commands, the docked
panel and the phone sheet). All run against scripted models: no test calls the network.

### 27.13 Limits

The assistant needs the network and the provider's service (it does not work offline). In the
browser a key OpenAI rejects looks like a network failure, since that error comes without
cross-origin headers and the browser hides it (the message says so). The assistant is as reliable
as the model, which is why every figure about the design is read from the program and every change
can be refused, undone or rewound; a position picked on a picture is as good as the pixel the model
picks (s metres). Pictures ask for no approval, though they download map tiles; long analyses the
model asks for run on the interface thread; conversations are not saved with the project, by design
(a shared file or link would carry the chat and its pictures), but they are kept in the browser's
storage (IndexedDB) by project, the 24 most recently saved with their pictures and small
attachments, until the setting that keeps them is turned off, which deletes them; the usage is billed
by the provider to the account of the key; and the clients have been tested against scripted fakes
of the six APIs, not against the live services: the four added in 1.7.0 were written from each
company's documentation of 2026-11-10 and have never been run with a real key. In a browser, the
page cannot read Meta's request id and rate-limit headers nor OpenRouter's waits, which the desktop
app can.

---

## 28. Validation

The suite has about 1,900 tests (`flutter test`). Those validating the methods against references:

| Test | Reference |
|---|---|
| Hazen-Williams matches textbook value | Tabulated value from a hydraulics manual |
| Darcy-Weisbach agrees with Hazen-Williams for smooth PVC | Consistency between formulas on smooth PVC (a few per cent difference) |
| Swamee-Jain close to Colebrook | Error < 1 % (Swamee & Jain 1976) |
| transitional cubic matches the turbulent slope at Re = 4000 (EPANET) | Dunlop's polynomial as coded in EPANET |
| Manning: 10.29·n²·L·Q²/D^(16/3); the solver uses them: one pipe between two reservoirs carries the flow of the law | Chow 1959; consistency of the solver with each law |
| Christiansen F factor table values; Scaloppi adjustment | Keller & Bliesner tables; Scaloppi 1988 |
| pressure dependent emitters; PRV holds downstream pressure; two reservoirs in a loop split the flow | Cases from the EPANET manual |
| a PSV holds the upstream pressure at its setting and limits the flow accordingly; an FCV lets its flow setting through, or less when the head is not there | EPANET's valve models |
| emitters under negative pressure (closed, no backflow, reopen) | Mass balance of one-way emitters |
| converge level at the mean head across the closed links, whatever their size; drain down to their lowest emitter | Balance of the closed-link conductances |
| friction loss agrees with Christiansen estimate | Solver versus F factor |
| downhill slope raises end pressure; feed positions | Wu & Gitlin 1975 |
| a 95 m supply never gets PN 80 PVC; warm water derates the class | ISO 1452-2 and ISO 4427-1 derating |
| a 60 Hz pump on 50 Hz mains runs at 5/6 of the speed | Affinity laws |
| PVC celerity in expected range | 300 to 600 m/s in PVC |
| instantaneous closure: Joukowsky surge a·ΔV/g and the 4L/a period; slow demand stop: Michaud surge 2·L·V/(g·tc) | Joukowsky; Michaud; Wylie & Streeter 1993 |
| column separation: vapour cavity at the valve after the downsurge; run-down follows the pump boundary condition | DVCM (Bergant, Simpson & Tijsseling 2006); Wylie & Streeter 1993 |
| the inertia estimate grows with the power and falls with the speed | Thorley & Faithfull 1992 |
| a hill: high point, line end and valves on the long ascent and descent; orifice sizing by compressible flow | AWWA M51; isentropic orifice flow |
| a tank filled at constant inflow reaches the analytic level; a tank draining through a pipe follows the analytic curve | Analytic solutions |
| FAO 59 Box 1 / Table 2: every section | Lamaddalena & Sagardoy 2000 |
| matches reference quantiles; reference sequence from the all-12345 state | Wichura 1988; L'Ecuyer 1999 |
| exact against a brute force over every start and block choice | Exhaustive enumeration |
| pressure-driven demand: full above the requirement, orifice below | Wagner, Shamir & Marks 1988 |
| one global factor: golden section recovers C = 120 from a pipe built with 150 | Synthetic truth |
| capital recovery factor; operating point | Financial and pump formulas |
| solenoid voltage by hand (valve B opening, A and C holding); voltage along the pair by hand, the cheapest wire that keeps 24 V | Ohm's law along the conductors and around the pair |
| Example 17, 18 and 20 (ETo); Example 28 and Box 15 (Kc); Example 41 (sparse cover) | Allen et al. 1998 (FAO-56) |
| worked example: ETc 7.6 in, rain 4.7 in; Table 2-43 cells for 3 in of soil water storage | NRCS NEH 623 chapter 2 |
| Example 3: maize, river water of 1.2 dS/m | Ayers & Westcot 1985 (FAO-29) |
| the numerical Rb equals the closed form for equator-facing surfaces | Duffie & Beckman |
| eq. 10: 5 emitters 1.2 m apart wetting 2.26 m on 6 × 6 m trees give 38 % | FAO Irrigation Manual Module 9 |
| MAWA of a residential landscape in US units | MWELO Appendix B |
| worked example: 200 m furrow, 0.15 m³/min, advance about 65 min; the Strelkoff depletion terms of the worked iteration | Walker 1989 (FAO 45) |
| discharge of the sprinkler 1,200 ft from the pivot with 10 ft spacing: 10.69 gpm (eq. 11-44); sample calculation 11-17 | NRCS NEH 623 chapter 11 |
| drop span by span with the motors beyond each span running (IEC 60364-5-52 Annex G) | IEC 60364-5-52 |
| sector pivot: same cycle time gives a proportionally lower application rate | Keller & Bliesner, chapter 14 |
| every profile spreads the whole flow over the wetted circle; head-to-head spacing is uniform, wide spacing is not; wind moves the water downwind and keeps its volume | Volume balance; Keller & Bliesner, chapter 5 |
| two lawns and three tree crowns, the areas within a few per cent | Synthetic aerial scene of known areas |
| marching squares: the outline of every region holds exactly the pixels it encloses | Property of the boundary walk |
| Delaunay of a plane reproduces the plane exactly; without the breakline the valley is bridged, with it the surface folds along the channel | Property of the linear interpolator; constrained triangulation |
| UTM inverse round trip; georeference from a lat/lon origin | Karney 2011 |
| SAD 69 and Córrego Alegre to SIRGAS 2000 agree with the Molodensky formula and round-trip | IBGE R.PR 1/2005 and R.PR 23/1989 |
| every version and point format: ground points on the plane | ASPRS LAS 1.4 |
| The CRC-16 matches the checksum stored in real files; LibreDWG accepts the file | Real files and an independent tool |
| example_\<version\>: splines, hatches, solids and the ellipse like LibreDWG reads them | Entities listed by LibreDWG |
| is an AC1015 file in metres, ASCII, with handles and owners; LibreDWG reads it and converts it to DXF | ezdxf audit; LibreDWG |
| \<language\> runs shape like the reference engine | HarfBuzz |
| LP design meets the pressure window and costs no more than greedy | Relative optimality of the LP |
| an exchange converted from one format to the other and back loses nothing | Round trip of the two wire formats |
| pixel ↔ world mapping: square pixels, exact round trip, image_to_world both ways | Exact inverse of the picture mapping |
| terrain profile on a plane: exact rise, fall, extremes and slope | Analytic plane |
| every action, tool, alias, menu item and dialog has a route for the AI | The program's own lists of its functions |

The gallery examples work as integration tests: the fifteen projects, in the 20 languages,
build, pass the check, size with every zone inside the window and without supply deficit, print
every report cell as a plain number, and match the published files. Every snippet of `docs/API.md`
(and of its translation, `docs/API.pt-BR.md`) is run by `test/core/api_examples_test.dart`.

---

## 29. Gaps and future work

From the research point of view, what the literature and design practice suggest as next steps:

1. **Loops in the LP**: the mainline LP of a looped network is solved again with the flows of its
   own sizes until the choice settles, but on tree paths; an exact formulation (loop decomposition
   or non-linear programming) remains open.
2. **Transients**: unsteady friction (the model is quasi-steady), four-quadrant pump
   characteristics instead of the simplified torque model of the trip, the transients inside the
   zones (the study sees a zone as an orifice at its valve) and distributed air release.
3. Automatic **"unconnected" sprayline**.
4. **DWG and DXF export**: versions newer than R2000 (true colours in DWG) and entities such
   as multileaders and tables.
5. **Water quality**: clogging risk and water chemistry next to fertigation, and dispersion of the
   injected product (the travel times are plug flow).
6. **Electrical system**: field wiring diagrams.
7. **Densogram in wind**: measured windy-day patterns or a ballistic drop model instead of the
   first-order drift.
8. **Collaboration**: simultaneous editing, keeping the principle of not depending on a server of
   our own (sharing by link already works without one).
9. **Vegetation**: near-infrared imagery (true vegetation indices) and canopy height from a surface
   model would separate lawn, shrubs and trees better than colour and texture.
10. **Browser tests** for runtime behaviour (system language, offline start).

Current limits the program states to the user: the browser keeps about 3.5 MB of stored text per
project (after compression); BigTIFF files and rasters above 100 million pixels are refused;
surveys above 12 000 samples are thinned for the TIN; compressed LAS (LAZ), DGN V8, encrypted PDFs
and the JPEG 2000 and JBIG2 images of PDFs are not read; OpenTopoData works only in the desktop
build; the CAD exports are R2000 (DXF true colours, DWG colour indices) or R12; the AI
assistant needs the network and has been tested against scripted fakes of the six model APIs only;
and no native mobile build is produced (the web app works on phones).

---

## 30. Glossary

| Term | Portuguese | Meaning |
|---|---|---|
| Zone | Zona | Set of pipes and emitters downstream of a control valve |
| Mainline | Linha principal | From the water supply to the zone valves |
| Submain | Submain | Zone pipe feeding the laterals |
| Sprayline / lateral | Lateral | Pipe with equally spaced emitters |
| Tape / dripline | Fita / tubo gotejador | Lateral with integral emitters |
| System flow | Turno | Valves operating together |
| Duty | Duty | Flow and pressure required from a supply in a system flow |
| Pressure window | Janela de pressão | Emitter pressure range keeping the flow within tolerance |
| Telescoping | Telescopagem | Decreasing diameters along a pipe |
| CU, DU, EU | idem | Christiansen, low-quarter and emission uniformity coefficients |
| CRF | CRF | Capital recovery factor, which annualises a capital cost |
| TIN / DTM | TIN / MDT | Terrain model by triangulation |
| Breakline | Linha de quebra | Line the terrain triangulation must follow |
| GGA | GGA | Global Gradient Algorithm, the Todini-Pilati method for networks |
| BOM | Lista de materiais | Bill of materials |
| PRV | Válvula reguladora de pressão | Pressure-reducing valve |
| PSV | Válvula sustentadora de pressão | Pressure-sustaining valve |
| FCV | Válvula controladora de vazão | Flow-control valve (a hydrant's flow limiter) |
| Master valve | Válvula mestra | Mainline valve the controller opens with every zone |
| Valve-in-head station | Estação valve-in-head | Sprinklers on the mainline, each with its valve, opening together |
| VFD | Inversor de frequência | Variable-speed drive of a pump |
| NPSH | NPSH | Net positive suction head, available and required |
| MOC | Método das características | Method of characteristics for transients |
| DVCM | DVCM | Discrete vapour cavity model of column separation |
| EPS | Simulação de período estendido | Sequence of steady solutions in time |
| VRI | Irrigação de taxa variável | Variable-rate irrigation of a pivot |
| ETo, ETc, Kc | idem | Reference and crop evapotranspiration, crop coefficient |
| LR | Fração de lixiviação | Leaching requirement |
| ExG | ExG | Excess green index of an RGB image |

---

## 31. Sources

Hydraulics and networks:
- Rossman, L. et al. EPANET 2.2 User Manual, Analysis Algorithms: https://epanet-manual.readthedocs.io/en/latest/analysis_algorithms.html
- EPANET 2.2 Users Manual, EPA/600/R-20/133 (input file format); Rossman, L. A. (2000). EPANET 2 Users Manual.
- Todini, E.; Pilati, S. (1988). A gradient algorithm for the analysis of pipe networks. Computer Applications in Water Supply, vol. 1.
- Swamee, P. K.; Jain, A. K. (1976). Explicit equations for pipe-flow problems. J. Hydraulics Div. ASCE 102(5).
- Scobey (1930), the friction formula of steel and aluminium sprinkler laterals; Chow (1959), Manning's n.
- Christiansen, J. E. (1942). Irrigation by sprinkling. Univ. California Bull. 670.
- Scaloppi, E. J. (1988). Adjusted F factor for multiple-outlet pipes. J. Irrig. Drain. Eng. 114(1): https://ascelibrary.org/doi/10.1061/%28ASCE%290733-9437%281988%29114%3A1%28169%29
- Wu, I. P.; Gitlin, H. M. (1975). Energy gradient line for drip irrigation laterals. J. Irrig. Drain. Div. ASCE 101(4).
- Keller, J.; Bliesner, R. D. (1990). Sprinkle and Trickle Irrigation. Van Nostrand Reinhold.
- Keller, J.; Karmeli, D. (1974). Trickle irrigation design parameters. Trans. ASAE 17(4).
- Chu, S. T.; Moe, D. L. (1972). Hydraulics of a center pivot system. Trans. ASAE 15(5).
- Alperovits & Shamir (1977). Water Resources Research 13(6) (looped networks sized by linear programming, re-solved with the new flows).
- Hazen-Williams versus Darcy-Weisbach in PE: https://iwaponline.com/aqua/article/74/8/493/108822/ ; https://elibrary.asabe.org/abstract.asp?JID=3&AID=25699 ; C factors by material: Keller & Bliesner (1990)
- Emitters: https://doi.org/10.3390/w14071034 ; https://doi.org/10.3390/w18020244 ; https://workforce.libretexts.org/Bookshelves/Water_Systems_Technology/Irrigation_Systems_Management_(AET_021)/14:_Microirrigation/14.06:_Uniformity
- Uniformity: Xue et al. (2023), Irrigation and Drainage: https://onlinelibrary.wiley.com/doi/abs/10.1002/ird.2837 ; https://www.sciencedirect.com/science/article/abs/pii/S1537511005002205
- Laterals: https://link.springer.com/article/10.1007/BF00273380 ; https://www.sciencedirect.com/science/article/abs/pii/S0378377417304079
- Friction factor: https://www.sciencedirect.com/science/article/pii/S2090447919300176
- Velocity and water hammer: ASAE S376.2 (buried thermoplastic irrigation pipelines; velocity at most 1.5 m/s); Joukowsky: https://www.instrumentationblog.in/joukowsky-equation-water-hammer/
- Pumps: ANSI/HI 9.6.1 (NPSH margin); the curves and the affinity laws as in the EPANET 2.2 manual.
- Pressure classes and temperature: ISO 1452-2, Annex A (PVC-U); ISO 4427-1, Annex A (PE, 50 years); NBR 14312 data sheets.
- Minor losses: Crane TP-410; https://neutrium.net/articles/fluid-flow/pressure-loss-from-fittings-excess-head-k-method/
- NRCS National Engineering Handbook, Part 623, chapter 7 (Microirrigation) and chapter 11 (Sprinkler): https://www.wcc.nrcs.usda.gov/ftpref/wntsc/waterMgt/irrigation/NEH15/ch7.pdf , .../ch11.pdf
- FAO Irrigation Manual, modules 8 and 9: https://www.fao.org/4/ai596e/ai596e.pdf
- Allen, R. G. et al. (1998). FAO Irrigation and Drainage Paper 56: Crop evapotranspiration.

Transients and air valves:
- Wylie & Streeter (1993). Fluid Transients in Systems.
- Chaudhry (2014). Applied Hydraulic Transients.
- Thorley & Faithfull (1992). Inertias of pumps and their driving motors; Thorley (2004). Fluid Transients in Pipeline Systems.
- Bergant, Simpson & Tijsseling (2006) (column separation: the weighting of the discrete vapour cavity model).
- AWWA Manual M51. Air-Release, Air/Vacuum, and Combination Air Valves.

Operation of networks:
- Clément (1966). Calcul des débits dans les réseaux d'irrigation fonctionnant à la demande. La Houille Blanche 5.
- Lamaddalena & Sagardoy (2000). Performance analysis of on-demand pressurized irrigation systems. FAO Irrigation and Drainage Paper 59.
- Bethery et al. (1981) (random generation of hydrant configurations).
- L'Ecuyer (1999). Good parameters and implementations for combined multiple recursive random number generators. Operations Research 47(1).
- Wichura (1988). Algorithm AS 241: the percentage points of the normal distribution. Applied Statistics 37(3).
- Hyndman & Fan (1996) (sample quantiles, definition 7).
- Wagner, Shamir & Marks (1988). Water distribution reliability: simulation methods. J. Water Resources Planning and Management 114(3).
- Jiménez-Bello, Martínez Alzamora, Bou Soler & Bartolín Ayala (2010). Methodology for grouping intakes of pressurised irrigation networks into sectors to minimise energy consumption. Biosystems Engineering 105(4).
- Carrillo Cobo, Rodríguez Díaz, Montesinos, López Luque & Camacho Poyato (2011). Low energy consumption seasonal calendar for sectoring operation in pressurized irrigation networks. Irrigation Science 29.
- Kiefer (1953). Sequential minimax search for a maximum. Proc. American Mathematical Society 4.
- Levenberg (1944). Quarterly of Applied Mathematics 2; Marquardt (1963). J. SIAM 11.
- Dijkstra (1959) (shortest paths).
- Burt, O'Connor & Ruehr (1995). Fertigation. Irrigation Training and Research Center, California Polytechnic State University.
- Portaria Normativa MME nº 137, de 8 de junho de 2026 (irrigation discount window); Resolução Normativa ANEEL nº 1.000/2021, art. 186 (discounts).
- Resolução CONAMA nº 284/2001 (environmental licensing of irrigation projects).

Layout, routing and wiring:
- Irrigation Association (2014). Landscape Irrigation Best Management Practices.
- Garcia-Castellanos & Lombardo (2007). Scottish Geographical Journal 123 (pole of inaccessibility).
- Alpert, Hu, Huang, Kahng & Karger (1995). IEEE Trans. Computer-Aided Design 14(7) (Prim–Dijkstra trade-off).
- Takahashi & Matsuyama (1980). An approximate solution for the Steiner problem in graphs. Mathematica Japonica 24.
- IFAB Law 1 (the pitch); World Athletics (the 400 m track); United States Golf Association green construction recommendations for the green and its collar.

Image analysis:
- Radon (1917). Über die Bestimmung von Funktionen durch ihre Integralwerte längs gewisser Mannigfaltigkeiten.
- Pearson (1901). On lines and planes of closest fit to systems of points in space. Phil. Mag. 2.
- Quinn (1994). Estimating frequency by interpolation using Fourier coefficients. IEEE Trans. Signal Process. 42(5).
- Pfister, Schwarz, Janczyk, Dale & Freeman (2013). Good things peak in pairs: a note on the bimodality coefficient. Front. Psychol. 4; SAS Institute (1990) (the bimodality coefficient).
- Woebbecke, Meyer, Von Bargen & Mortensen (1995). Color indices for weed identification under various soil, residue, and lighting conditions. Trans. ASAE 38(1).
- Otsu (1979). A threshold selection method from gray-level histograms. IEEE Trans. SMC 9(1).
- Meyer & Neto (2008). Verification of color vegetation indices for automated crop imaging applications. Comput. Electron. Agric. 63(2).
- Gitelson, Kaufman, Stark & Rundquist (2002). Novel algorithms for remote estimation of vegetation fraction. Remote Sens. Environ. 80(1).
- Taubin (1995). Curve and surface smoothing without shrinkage. ICCV.
- Douglas & Peucker (1973). Algorithms for the reduction of the number of points required to represent a digitized line or its caricature. Cartographica 10(2).

Agronomy:
- Weibull (1939) (plotting positions); Chow, Maidment & Mays (1988). Applied Hydrology, section 12.5.
- Sen (1968). J. Am. Stat. Assoc. 63: 1379 (the slope of a trend); Mann (1945); Kendall (1975); Helsel & Hirsch (2002). Statistical Methods in Water Resources, USGS TWRI 4-A3, chapter 12.
- Karl, Nicholls & Ghazi (1999); Zhang et al. (2011) (the ETCCDI climate indices, CDD).
- Kasten & Czeplak (1980) (solar radiation from cloud cover, tried for the irrigation forecast and not used).
- MET Norway Locationforecast 2.0, terms of service and licence: https://api.met.no/doc/TermsOfService , https://api.met.no/doc/License
- RFC 5545 (iCalendar).
- Ayers & Westcot (1985). FAO Irrigation and Drainage Paper 29 Rev. 1; Maas & Hoffman (1977); Maas (1984).
- Savva & Frenken (2002). FAO Irrigation Manual, Module 9.
- Brouwer & Heibloem (1986). FAO Irrigation Water Management Training Manual No. 3.
- Smith (1992). FAO Irrigation and Drainage Paper 46.
- USDA-SCS (1970). Technical Release 21; NRCS National Engineering Handbook Part 623, chapter 2 (1993).
- USDA-NRCS National Engineering Handbook Part 652, Irrigation Guide (1997); USDA-SCS National Engineering Handbook Section 15, chapter 11, Sprinkle Irrigation (1983); USDA-NRCS Soil Survey Manual (Handbook 18).
- Rawls, Brakensiek & Saxton (1982). Estimation of soil water properties. Trans. ASAE 25(5): 1316–1320.
- Irrigation Association, SWAT climatologically based controllers 8th draft testing protocol (2008); US EPA WaterSense specification for weather-based irrigation controllers (2011).
- California Model Water Efficient Landscape Ordinance (California Code of Regulations, Title 23, §§ 490–495, 2015 revision); Water Use Classification of Landscape Species (University of California Cooperative Extension).
- Schwartzman, M.; Zur, B. (1986). Emitter spacing and geometry of wetted soil volume. J. Irrig. Drain. Eng. 112(3): 242–253; Cruz-Bautista et al. (2016), Tecnología y Ciencias del Agua 7(1): 45–55.
- IEC 62253:2011, Photovoltaic pumping systems; IEC 61724-1 (performance ratio).
- Duffie & Beckman. Solar Engineering of Thermal Processes; Erbs, Klein & Duffie (1982); Klein (1977); Cooper (1969); Liu & Jordan (isotropic sky).
- Open-Meteo historical weather API (archive-api.open-meteo.com; ERA5 and ERA5-Land, CC BY 4.0); NASA POWER daily point API (power.larc.nasa.gov).

Machines and surface irrigation:
- Heermann & Hein (1968) (flow per outlet of a centre pivot).
- Kansas State University (2022). MF3608, Interpreting and Using Center Pivot Sprinkler Designs.
- Evans et al. (2013). Irrigation Science 31: 871–887 (variable-rate irrigation).
- IEC 60364-5-52, Annex G (voltage drop); IEC 60228 (conductors); IEEE Std 399 (motor starting); IEEE Std 446 (generators).
- Seginer, Kantz and Nir (1991) (sprinkler patterns in wind).
- Walker & Skogerboe (1987); Walker (1989), FAO Irrigation and Drainage Paper 45.
- Elliott & Walker (1982) (two-point method); Strelkoff (1977) (border recession); Hart et al. (1980) (border spreading flow).
- NRCS National Engineering Handbook Part 623, chapter 4 (Surface irrigation); U.S. Bureau of Reclamation, Water Measurement Manual, chapter 13.

Terrain, geoprocessing and algorithms:
- Karney, C. F. F. (2011). Transverse Mercator with an accuracy of a few nanometers. Journal of Geodesy 85(8).
- Bowyer, A. (1981); Watson, D. F. (1981). Computing the n-dimensional Delaunay tessellation. The Computer Journal 24(2).
- Sloan, S. W. (1993). A fast algorithm for generating constrained Delaunay triangulations. Computers & Structures 47(3): 441–450.
- Leutenegger, S. T.; Lopez, M. A.; Edgington, J. (1997). STR: a simple and efficient algorithm for R-tree packing. ICDE.
- Terrain Tiles on AWS Open Data (terrarium tiles: SRTM, GMTED, ETOPO1).
- Open-Meteo Elevation API: https://open-meteo.com/en/docs/elevation-api ; Copernicus DEM GLO-90.
- OpenTopoData: https://www.opentopodata.org/ (SRTM, ASTER).
- IBGE, Resolução do Presidente nº 1/2005 (SIRGAS 2000; SAD 69 parameters) and nº 23/1989 (Córrego Alegre parameters).
- OGC 01-009 (WKT 1); ISO 19162:2019 (WKT 2); EPSG Geodetic Parameter Dataset.
- ASPRS LAS Specification 1.4 – R15 (2019); OGC GeoTIFF Standard 1.1; LandXML 1.2 schema (2008).

Formats:
- Open Design Alliance. Open Design Specification for .dwg files (version 5.4.1).
- LibreDWG: https://www.gnu.org/software/libredwg/ ; ezdxf (validation of the DXF files).
- DXF Reference: the published specification of the format (R12 to 2018).
- ESRI Shapefile Technical Description (1998); dBASE III file structure; GeoTIFF Specification 1.8.2; OGC KML 2.3; RFC 7946 (GeoJSON) and The GeoJSON Format Specification rev. 1.0 (2008); GPX 1.1 Schema Documentation (2004); ISFF specification of the DGN V7 design file (1994).
- ISO 32000-1 (PDF 1.7) and PDF Reference 1.4 (Adobe); OpenType specification 1.9 and its script development documents; Unicode UAX #9 (bidirectional algorithm), UAX #53 (Arabic mark rendering) and ArabicShaping.txt; HarfBuzz (reference shaping engine of the tests).
- ISO 10303-21 (STEP physical file); ISO 16739-1:2018 (IFC4 ADD2 TC1).
- ECMA-376 Office Open XML (SpreadsheetML).
- ASAE S376.2 (minimum cover of buried thermoplastic pipelines); Azevedo Netto, Manual de Hidráulica (suction submergence).

AI assistant:
- Anthropic Messages API, version 2026-10-21 (https://api.anthropic.com/v1/messages): streaming, tool use, adaptive thinking, effort, prompt caching, the server-side refusal fallback, task budgets and context management (compaction and the clearing of tool results).
- OpenAI Responses API (https://api.openai.com/v1/responses): streaming events, function tools, reasoning effort, encrypted reasoning with `store: false`, server-side compaction.
- OpenStreetMap Nominatim search API (nominatim.openstreetmap.org) and its usage policy (at most one request a second, attribution, ODbL data).
