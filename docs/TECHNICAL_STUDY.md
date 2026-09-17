# Technical study: irrigation CADs, network hydraulics and the decisions behind OpenCADIrrigation

> Canonical version, maintained in English. Portuguese translation: [PESQUISA.pt-BR.md](PESQUISA.pt-BR.md).

Study started on 15 September 2026 and extended on 16 September 2026. This document gathers the
research that guides the architecture of OpenCADIrrigation (an open-source irrigation CAD for the
browser): what commercial CADs do, the hydraulics and agronomy the engine implements, with the
equations and numerical examples, the sizing formulations, the terrain and performance algorithms,
the file formats studied and the sources. Wherever a formula appears, the module that implements
it is named, and so is the test that validates it.

This document does not cite third-party software companies or products; the sources are standards,
technical literature and public-domain software.

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
14. [Pipe sizing](#14-pipe-sizing)
15. [Mainline, system flows and supplies](#15-mainline-system-flows-and-supplies)
16. [Flushing, fittings and bill of materials](#16-flushing-fittings-and-bill-of-materials)
17. [Agronomy](#17-agronomy)
18. [Centre pivot and linear move](#18-centre-pivot-and-linear-move)
19. [Terrain and geoprocessing](#19-terrain-and-geoprocessing)
20. [File formats](#20-file-formats)
21. [Performance and software architecture](#21-performance-and-software-architecture)
22. [Validation](#22-validation)
23. [Gaps and future work](#23-gaps-and-future-work)
24. [Glossary](#24-glossary)
25. [Sources](#25-sources)

---

## 1. Scope and method

Questions the study set out to answer:

1. What does a designer expect from an irrigation CAD, in the order they work? Answered in
   section 2, from professional practice and the design manuals (NRCS National Engineering
   Handbook, chapters 7 and 11; Keller & Bliesner; FAO irrigation manuals).
2. Why an open, browser-based irrigation CAD, and which principles does that impose? Section 3.
3. Which equations are consensus in the literature and the engineering manuals (NRCS, FAO,
   Keller & Bliesner, EPANET) and how to test them? Sections 4 to 13, with recomputed numerical
   examples.
4. How to size pipes in a reproducible, explainable way? Sections 14 to 16.
5. Which terrain, geoprocessing, format and performance algorithms does a web CAD need, and how to
   implement them without native libraries? Sections 19 to 21.

Primary sources: the EPANET 2.2 manual, chapters 7 (microirrigation) and 11 (sprinkler) of the NRCS
National Engineering Handbook, FAO-56, the FAO irrigation manuals, Keller & Bliesner (1990),
peer-reviewed papers on friction factors, emitters and uniformity, the open specification of the
DWG format and the documentation of the public elevation services.

This study does not cite third-party software companies or products. Irrigation component
manufacturers appear only as the origin of catalogue data, and third-party file formats only by the
name of the format.

---

## 2. What a designer expects from an irrigation CAD

### 2.1 Design process

The practice consolidated in the design manuals (NRCS NEH 623, chapters 7 and 11; Keller &
Bliesner, 1990) organises the work in stages, and that is the order the Project menu and the
tutorial follow:

1. Project details: client, site, designer, units.
2. Background information: boundaries, buildings, roads and, above all, the **elevations** (contour
   lines and spot heights), because topography governs the pressures.
3. Layout: water supplies, emitters, control valves, pumps, devices and pipes.
4. **Zone design**: size or analyse from the zone valve to the emitters, within the pressure window
   that guarantees uniformity.
5. **Management**: which valves operate together (system flows), for how long, and what that
   demands from the supply.
6. **Mainline design**: size or analyse from the supply to the valves, flow by flow.
7. Materials: automatically selected fittings and a costed bill of materials.
8. Plans and reports: sheet with title block, legend, scale and the result tables.

### 2.2 Object model

The OpenCADIrrigation model (`entities.dart`) separates three families of items:

- **Zone items**, downstream of a control valve: zone pipe, lateral with equally spaced emitters
  (sprayline), tape or dripline with integral emitters, single emitter, device (regulator, gate
  valve, filter), junction and irrigated area with its water requirement. Generators create lateral
  blocks with submain and valve, and sprinkler grids.
- **Mainline items**: water supply, mainline pipe, pump, junction, device, control valve and centre
  pivot or linear move (a demand with its own required pressure).
- **Drawing items**: point, line, polyline, rectangle, circle, arc, spline, hatch, dimensions
  (linear, angular, radial and leader), symbols, text, image, contour line and spot height.

Structural rules adopted: a control valve always separates zone from mainline; zone items do not
connect to mainline items without a valve between them; coincident vertices (within the connection
tolerance) form a node; a point item on a pipe splits the pipe; there is no limit to the number of
connections at a junction, because the network solver accepts any degree. Diameter and ordinate
dimensions were not implemented.

### 2.3 Component database

Six groups (pipes, emitters with nozzles, tapes, valves and devices, pumps, fittings), all in SI,
with the fields the hydraulics require:

- **Pipe**: nominal diameter, real inner diameter (the one used in the calculation), Hazen-Williams
  C, roughness, pressure rating, usage (lateral, zone, mainline), cost per metre.
- **Tape**: manufacturing CV, inner diameter, default, minimum and maximum inlet pressure,
  tolerances above and below, barb loss coefficient, emitter constant and exponent, spacing,
  rating.
- **Emitter and nozzle**: q = k·H^x, wetted radius R = a·H^b, arc, minimum and maximum pressure,
  CV, flow tolerance (±5 % is the usual value), kind (sprinkler, micro-sprinkler, dripper, bubbler,
  gun, demand point).
- **Valve and device**: loss h = K·Q^n + C, minimum and maximum flow, outlet pressure of a
  regulator.
- **Pump**: (Q, H) points fitted to a parabola, efficiency, power.
- **Fitting**: kind, diameters, cost.

Manufacturer catalogues are open JSON files (`catalogs/`), with typical public catalogue data and
prices to be filled in locally.

### 2.4 Methods the engine must cover

Of what design practice requires, the engine implements:

- Friction loss by **Hazen-Williams** with C per pipe and a global adjustment (scale or offset) for
  ageing, and by **Darcy-Weisbach** (laminar, transition and turbulent) for tapes and small pipes,
  with viscosity from temperature.
- **Minor losses** as a percentage of the length, by equivalent length or by the own curve of every
  device, and the per-emitter barb loss in tapes.
- **Pressure window** of the emitters derived from the flow tolerance (±5 % → about ±10 % of
  pressure for exponent 0.5) and from the minimum and maximum pressures in the catalogue; tapes
  with asymmetric tolerances (for instance +20 % and −30 % of the inlet pressure).
- **Analysis** with nominal flows (fast) and **detailed analysis** with pressure-dependent
  emitters, by a complete network solver.
- **Sizing by linear programming** (topography, pressure window, velocity, economics, enabled and
  fixed diameters, number of diameters per lateral and per submain) and by **maximum velocity**,
  with rationalisation of diameters from upstream to downstream.
- **Valve pressure** chosen so that the mean emitter pressure equals the nominal one, or, for
  regulated tapes, to guarantee the minimum submain pressure.
- **Water supply** with calculated pressure (well with a negative water level, reservoir with a
  positive height) or fixed (mains, with design and maximum flow and pressure).
- **Management** by system flows, with the duty of every supply per flow and operating times from
  the water requirements of the areas.
- **Elevation** at every node of the graph from the terrain model.

### 2.5 Reports and graphical tools

Zone summary (flow, allowable and actual pressures, allowable and actual variation, pressure
downstream of the valve, valve loss), uniformity (CU, low-quarter DU, Keller-Karmeli EU), pipe and
emitter tables (elevations, pressures, flows, velocities, diameters), mainline and supply duties,
water requirements, agronomy, controller programme, flushing, water hammer, pivots and spans, bill
of materials with annualised costs; hydraulic grade line and profile charts, overlays of velocity,
pressure, diameters and minimum/maximum pressure, submain position envelope and 3D view of the
terrain.

### 2.6 Formats

Import of DXF, DWG, KML/KMZ, SHP, CSV/XYZ/PNEZD, GeoTIFF and georeferenced images; export of DXF,
DWG, PDF, SVG, KML/KMZ, GeoJSON and reports in CSV, TXT, XLSX and PDF; project in open JSON with the
catalogue embedded.

---

## 3. Why an open irrigation CAD in the browser

General observations about the landscape, without reference to products:

- Professional irrigation design tools are, as a rule, desktop applications for a single operating
  system or plug-ins of paid CAD platforms, with commercial licences, closed component databases
  and proprietary project formats.
- On the web there are mostly manufacturer calculators (lateral, submain, pump) and closed
  subscription services aimed at landscaping; a complete, open, free CAD in the browser did not
  exist.
- The only open, established network engine is EPANET (public domain, US EPA), aimed at water
  distribution networks and without the irrigation objects (laterals, tapes, zone valves, system
  flows).
- Whoever designs in the field, on a tablet or on machines without installation privileges is left
  without an option.

Principles that follow from this and that OpenCADIrrigation adopts:

1. Run in the browser with no installation and no server, with the data on the user's computer.
2. Project and catalogue formats in open, documented JSON.
3. A transparent hydraulic engine, with the equations documented and tested against public
   references, and with the EPANET solver as the basis for networks.
4. A trilingual interface, designed for touch as well.

---

## 4. Engine units and conventions

Internally everything is SI: length in m, flow in m³/s, head in metres of water column, pressure in
Pa, diameter in m, velocity in m/s (`units.dart`). The interface converts to metric (L/h, m³/h,
m w.c. or kPa, mm) or US (gpm, psi, inches, feet). Constants: 1 m w.c. = 9.80665 kPa = 1.42197 psi;
1 bar = 10.197 m w.c.; 1 L/h = 2.7778 × 10⁻⁷ m³/s; 1 m³/h = 2.7778 × 10⁻⁴ m³/s.

Kinematic viscosity of water (m²/s) as a function of temperature, by a table fit between 0 and
50 °C (error < 1 %): 1.004 × 10⁻⁶ at 20 °C; 1.13 × 10⁻⁶ at 15.6 °C (60 °F, the usual value in North
American manuals).

Catalogues store the emitter k in m³/s per m^x. Conversion of a nominal flow q_n (L/h) at H_n (m):
k = (q_n / 3.6 × 10⁶) / H_n^x. Example: 1.6 L/h at 10 m with x = 0.5 → k = 1.4055 × 10⁻⁷.

---

## 5. Friction head loss

Module `friction.dart`; tests in `hydraulics_test.dart`.

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

### 5.3 Flow exponent

Christiansen's F factor and the LP linearisation depend on the exponent m of the loss law: 1.852
in Hazen-Williams, 1.75 in Blasius, 2.0 in fully turbulent Darcy-Weisbach (`flowExponent`).

---

## 6. Minor losses

Module `minor_losses.dart`. Two equivalent forms:

- h_m = K·V²/(2g), with K from Crane TP-410 and the irrigation literature: 90° elbow 0.4 to 0.8,
  long radius 0.2 to 0.4, tee run 0.2 to 0.6, tee branch 1.0 to 1.8, gate valve 0.15, globe 6 to
  10, reducer 0.1 to 0.5, entrance 0.5, exit 1.0.
- Flow form h_m = m·Q² (EPANET style), with m = K / (2g·A²), used inside the solver.
- Equivalent length L_e = K·D/f, the usual method of irrigation CADs to add the losses to every
  segment. OpenCADIrrigation uses a percentage of the length (5 % by default) for pipes and the own
  curve of every catalogue device.

Devices and valves follow h = K·Q^n + C (Q in m³/s), fitted by log-log regression from catalogue
points or built from a dimensionless K and the diameter.

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
of `sparse_solver.dart`. Tests in `network_test.dart`.

### 11.1 Formulation

For every link ij with head loss h_ij(Q):

- pipe: h = r·|Q|^n·sgn(Q) + m·Q·|Q|;
- pump: h = −ω²·(h₀ − r·(Q/ω)^n), or the parabola fitted from the catalogue;
- emitter: a fictitious pipe to a reservoir at the emitter elevation, with n = 1/x and
  r = (1/k)^n, which is how EPANET treats emitters q = C·p^γ. The emitter is one-way: when the node
  head falls below the emitter elevation it is closed (no outflow and, unlike a reservoir link, no
  backflow into the network) and it reopens as soon as the pressure turns positive; an open/closed
  change counts as a status change for convergence (tests "emitters under negative pressure").

Define g_ij = ∂h/∂Q = n·r·|Q|^{n−1} + 2·m·|Q| (in Darcy-Weisbach add ∂r/∂Q·|Q|^n) and the
correction term y_ij = h_ij(Q)·sgn(Q). Every iteration solves the symmetric positive-definite
linear system A·H = F, with

A_ii = Σ_j 1/g_ij, A_ij = −1/g_ij, F_i = Σ_j (Q_ij + y_ij/g_ij) − D_i + Σ_f H_f/g_if,

the last terms for fixed-head reservoirs. Flows are updated by
Q_ij ← Q_ij − (1/g_ij)·(y_ij − (H_i − H_j)).

### 11.2 Valves and special cases

- An active PRV forces H_j = H_setting (A_jj += 10⁸, F_j += 10⁸·H_setting); closed, h = 10⁸·Q; the
  status logic decides between active, open and closed at every iteration (test "PRV holds
  downstream pressure").
- Check valve: closes when the flow reverses.
- Devices: the catalogue curve h = K·Q^n + C.
- Pressure-dependent demand at the emitters (Wagner): that is the detailed design analysis, with
  the real flow of every emitter.

### 11.3 Convergence and algebra

Criterion: Σ|ΔQ|/Σ|Q| < 10⁻⁵, or Σ|ΔQ| < 10⁻⁹ m³/s for networks carrying (almost) no flow, where
the relative measure is noise, with up to 200 iterations (`NetworkOptions`); tighter than EPANET's
10⁻³ because drip zones have minute flows per node. The matrix A is assembled as sparse and
factorised by LDLᵀ with minimum-degree ordering; for branched networks (nearly trees) the
factorisation creates no fill-in and the cost is close to linear, which allows zones with thousands
of nodes (test "large branched network is fast").

### 11.4 Use in the design

The zone is solved as a complete network: a fixed-head reservoir at the node downstream of the
valve (valve pressure), nodes with lumped emitters, submain and lateral links. The **valve
pressure** is found by bisection so that the mean emitter pressure equals the nominal one (the
"quick analysis" version uses fixed demands and a two-pass linear adjustment). The mainline is
solved per system flow with fixed- or calculated-pressure supplies, pumps and the demands of the
valves and pivots (section 15).

---

## 12. Pumps and energy

Module `pump.dart`.

- Quadratic H(Q) curve H = a·Q² + b·Q + c fitted by least squares to three or more points (two
  points give a line; one point generates EPANET's synthetic three-point curve). Speed ratio ω by
  the affinity laws: H(Q) = ω²·H_base(Q/ω); Q ∝ N, H ∝ N², P ∝ N³.
- System curve H_sys(Q) = H_static + k·Q^n; operating point at the intersection, by bisection.
- Hydraulic power P = ρ·g·Q·H; shaft power divides by the efficiency. Available NPSH must exceed
  the required one with a margin of 0.5 to 1 m; preferred region 70 to 120 % of the
  best-efficiency flow.
- **Annual cost** = capital · CRF + energy, with CRF = i(1+i)^n / ((1+i)^n − 1). For i = 10 % and
  n = 10 years, CRF = 0.16275. Energy [kWh/year] = P[kW] · hours/year; the energy cost of the inlet
  head enters the LP objective (section 14).
- **Automatic selection** (`pump_selection.dart`): for the worst duty of the supply, ranks the
  catalogue pumps by their ability to meet flow and head with margin and picks the standard IEC
  motor that covers the shaft power with a 1.15 service factor.

---

## 13. Water hammer and pressure ratings

Module `water_hammer.dart`; check in `Designer.checkSurge`.

- Joukowsky: ΔH = a·ΔV/g. Celerity a = √[(K/ρ) / (1 + K·D/(E·e))], with K = 2.2 GPa,
  E_PVC ≈ 3 GPa, E_HDPE ≈ 0.9 GPa, E_steel ≈ 200 GPa.
- Critical closure time 2L/a: faster closures produce the full surge; slower ones a proportional
  fraction (the "valve closure time" parameter, 3 s in the examples with solenoid valves).

| DN 100 pipe | Celerity | ΔH for ΔV = 1.5 m/s | 2L/a for 500 m |
|---|---|---|---|
| PVC, 5 mm wall | 375 m/s | 57.3 m | 2.67 s |
| HDPE, 9.1 mm wall | 281 m/s | 43.0 m | 3.56 s |
| Steel, 4 mm wall | 1314 m/s | 200.9 m | 0.76 s |

- Rules of thumb: V ≤ 1.5 m/s in laterals and class 200 PVC; 1.5 to 2.5 m/s in mainlines.
- Pipe rating (PN 6, 8, 10, 12.5, 16; PVC class B 60 m, C 90 m, D 120 m) compared with the maximum
  static pressure plus surge; the worst segment of every pipe goes to the Water hammer tab.

---

## 14. Pipe sizing

Modules `lp.dart`, `lp_sizing.dart`, `designer.dart`. Tests in `lp_test.dart`,
`sizing_features_test.dart`, `design_test.dart`.

### 14.1 Maximum velocity

For every sizable unit (an entity with a "computer sized" pipe), the smallest enabled catalogue
diameter, of the right usage (lateral, zone or mainline), whose velocity at the maximum flow of the
link respects the limit (2.0, 1.5 and 2.0 m/s by default). It is the classic velocity sizing of the
manuals and the first step of both methods here, because it provides the nominal flows the LP needs.

### 14.2 Linear programming

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
  because the flow in every unit is fixed by the velocity step); maximum velocity through the set of
  candidate diameters; fixed non-sizable pipes.
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

### 14.3 Repair and rationalisation

After the LP (or with the velocity step only, in the greedy method), the zone is analysed and, if an
emitter violates the window, the diameter of the unit on the critical path with the largest loss
reduction per cost is increased until it is met (`_repairZone`). Then the rationalisation
guarantees non-increasing diameters from upstream to downstream. The test "LP design meets the
pressure window and costs no more than greedy" compares the two methods on the orchard example.

### 14.4 Valve pressure and results

The final detailed analysis chooses the pressure downstream of the valve by bisection so that the
mean emitter pressure equals the nominal one (for regulated tapes, to guarantee the minimum submain
pressure). The valve loss comes from its curve; the required upstream pressure feeds the mainline.
The allowable variation of the zone comes from the emitter flow tolerance (or from the "maximum
zone variation" parameter) and the actual one is measured over the lumped emitters.

---

## 15. Mainline, system flows and supplies

- **System flows**: sets of valves operating together, with start time and duration. Without
  defined flows, every valve (and every pivot) is its own flow.
- **Demands**: for every valve, the zone flow and the required upstream pressure; for every pivot,
  the flow and the inlet pressure of the machine.
- **Mainline LP**: the same fraction-per-diameter variables, with a required-pressure constraint at
  every valve in every flow, and the energy cost weighted by the hours of every flow over the annual
  hours. Fixed-pressure supplies enter as constants; calculated supplies have the head as a
  variable.
- **Analysis per flow**: the complete mainline network with pumps (operating point), PRVs, check
  valves, devices and the demands; results per supply (duty: flow, available pressure, required
  pressure, deficit, elevation), per valve (available versus required) and per pipe; annual energy.
- **Loops**: the LP uses tree paths (message `lp_loops_approx`) and the final analysis checks the
  pressures; the test "looped mainline sizing with LP adds the approximation note and still
  converges" guards the behaviour.

---

## 16. Flushing, fittings and bill of materials

- **Flushing** (`analyzeFlushing`): every tape receives at its end the flow that produces the
  flushing velocity (0.3 m/s by default) and the zone is solved again; the valve pressure that keeps
  the minimum end pressure (1 m) is found and the flushing flow, the pressures and the maximum
  velocity are reported. It is the heaviest step of the calculation in zones with many tapes.
- **Fittings** (`fittings.dart`): from the sized graph, couplers per pipe stick (6 m), 90° and 45°
  elbows and tees and crosses from the geometry of the nodes, reducers where the diameter changes,
  end caps at dead ends, lateral take-offs, tape ends and emitter risers; each one looks for the
  catalogue item of that kind and size (or a generic name when there is none).
- **Bill of materials** (`buildBom`): pipes by diameter and rating, emitters, tapes, valves,
  devices, selected pumps, pivots (machine, towers, sprinklers, regulators) and fittings, with unit
  costs, total, annualised cost (CRF) and annual energy.

---

## 17. Agronomy

Module `agronomy.dart`, based on FAO-56 and the FAO irrigation manuals.

- ETc = Kc · ETo (mm/day); typical mid-season Kc values are offered per crop.
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
  zones irrigate, every interval of days, in sequence from the day's start hour (or at their own
  hours), in an N-day calendar exportable as CSV; the peak pumping hours per day go to the report.

---

## 18. Centre pivot and linear move

Module `pivot.dart` (Keller & Bliesner 1990, chapter 14; Chu & Moe 1972).

- **Capacity**: Q = A · gross depth / cycle time. For R = 300 m (28.3 ha irrigated, including the
  throw of the last sprinkler), 8 mm in 24 h: Q = 94.2 m³/h. For a sector pivot the area, and hence
  the flow, scale with the swept angle.
- **Flow distribution**: in a pivot the flow passing a distance r is Q·(1 − (r/R)²), because the
  irrigated area grows with r²; in a linear it is Q·(1 − r/L). The end gun adds along the whole
  length.
- **Friction**: numerical integration (Simpson, 200 steps) of the loss gradient along the span pipe
  with the varying flow; for a pivot the result equals the Chu & Moe factor ≈ 0.543 times the loss
  of a pipe carrying the total flow.
- **Inlet pressure**: pressure of the last sprinkler (or the end gun) + friction + ground rise in
  the worst direction (the azimuth where the end sits highest, obtained from the terrain model) +
  pipe height + machine losses; every tower is checked, because a sharp rise half-way can govern.
  The result enters the mainline as a demand and the deficit is reported.
- **Application rate** at the outer end: average I = 2·Q·R/(R²·w), from the flow per unit length at
  the end over the wetted width w (Q already being the sector flow, no further sector correction),
  and peak (elliptical profile) 4/π times the average; compared with the soil infiltration limit
  when given.
- **Spans and nozzles**: per span, number of sprinklers (spacing along the pipe), flow per
  sprinkler, pressure at mid-span and the closest catalogue nozzle; the basis of the span report
  and of the bill of materials (towers, sprinklers, regulators).

---

## 19. Terrain and geoprocessing

### 19.1 Digital terrain model

Modules `terrain.dart` and `tin.dart`.

- Samples: spot heights and contour-line vertices, densified every 5 m (parameter), with a spatial
  hash for fast queries.
- **Delaunay TIN** by the Bowyer-Watson algorithm (incremental insertion removing the triangles
  whose circumcircle contains the new point), with triangle location by a uniform grid and linear
  interpolation by barycentric coordinates. Exact on planar slopes (test "Delaunay of a plane
  reproduces the plane exactly") and the same as the model CADs call a DTM.
- **IDW** (inverse distance over the nearest neighbours, with search rings in the hash) as an
  alternative method and as a complement outside the convex hull of the TIN.
- Surveys with more than 12 000 points are decimated uniformly for the triangulation, but the IDW
  keeps them all (test "very large surveys are decimated for the TIN but kept for IDW").
- **Generated contour lines**: marching over the triangles (intersection of every level plane with
  every edge), segments chained into polylines with ring closure; the automatic interval is chosen
  for about 20 contours at most. Slope and aspect come from the triangle plane.
- Every node of the graph (lumped emitters included) receives the model elevation, plus the riser
  height and minus the burial depth.

### 19.2 Online elevation

Module `dem_online.dart`. Two free services, without a key and with CORS:

| Service | Data | Resolution | Limits |
|---|---|---|---|
| Open-Meteo Elevation API | Copernicus DEM GLO-90 | 90 m | 100 points per call |
| OpenTopoData | NASA SRTM, ASTER GDEM | 30 m | 100 points per call, 1 call per second |

The grid over the project (or the visible area) is limited in points (the spacing grows with the
area), the calls are batched and the answers become spot heights; contour generation can follow
automatically. The 30 to 90 m resolution serves the general relief and does not replace a survey,
which the dialog says.

### 19.3 Coordinates

- **UTM ↔ WGS84** by the Krüger series in Karney's formulation (2011), with millimetre accuracy
  inside the zone, automatic zone with the Norway and Svalbard exceptions, and a local origin to
  keep drawing coordinates small (test "UTM inverse round trip").
- **Pasted coordinates** (`parseLatLon`): decimals with dot or comma, hemisphere letters,
  degrees/minutes/seconds, Google Maps links and `geo:` URIs; the lon, lat order (KML) is
  recognised when only it makes sense.
- Geographic exports (KML, KMZ, GeoJSON) convert every vertex to WGS84 through the project
  georeference; without one, the app asks for it.

---

## 20. File formats

### 20.1 DXF

AutoCAD's text format organised in "group code / value" pairs. The reader (`dxf.dart`) walks the
BLOCKS and ENTITIES sections and reads LINE (10/20 and 11/21), LWPOLYLINE (vertices 10/20 in
order, bulge 42, closing flag 70, elevation 38), POLYLINE with VERTEX (elevation in code 30 or in
the equal Z of the vertices; spline control vertices ignored), CIRCLE, ARC (50/51 in degrees),
ELLIPSE and SPLINE (approximated by polylines: the ellipse from the axes 11/21 and ratio 40, the
spline from the fit points 11/21 or the control polygon), TEXT, ATTRIB and MTEXT (code 3 chunks
followed by 1, formatting codes stripped, alignment point 11/21 when 72/73 ask for it) and POINT,
with the layer (8) and the colour (62); the LAYER table and the $INSUNITS variable define layers
and scale. A bulge b describes an arc of angle 4·atan(b) between two vertices, sampled every 15°.

Blocks: every BLOCK keeps its base point (10/20) and its entities; INSERT (point 10/20, scales
41/42, rotation 50, array 70/71 with spacings 44/45) and the anonymous block of every DIMENSION
(code 2, already in drawing coordinates) are expanded by an affine transformation, with nested
references composed up to eight levels. Entities on layer 0 take the layer of the reference and
BYBLOCK colour takes its colour; circles and arcs stay circles and arcs when the transformation is
a similarity and become polylines under anisotropic scaling or mirroring; dimension definition
points (Defpoints layer) are left out. Text is decoded as UTF-8 (R2007+) or Latin-1 (cp1252 of the
older files). The writer produces an R12 file with a layer table, the common denominator of all
CADs.

### 20.2 DWG

DWG is binary and proprietary; the Open Design Alliance publishes a reverse-engineered
specification that served as the basis for the reader (`dwg.dart`, 1.6 thousand lines) and the
writer (`dwg_writer.dart`, 1.3 thousand lines), both in pure Dart.

- **Versions**: AC1012 (R13), AC1014 (R14), AC1015 (2000), AC1018 (2004), AC1021 (2007), AC1024
  (2010), AC1027 (2013), AC1032 (2018). Unknown versions are rejected with a clear message.
- **Containers**: R13 to R2000 have sections located by an index in the header, without
  compression; R2004 and R2010 to R2018 use compressed pages with their own LZ77 scheme and a map
  of pages and sections; R2007 is the hardest case: pages interleaved with Reed-Solomon codes
  (repeated 239-byte blocks), which must be de-interleaved and decompressed before reading.
- **Data**: objects are addressed through the object map (handles), and every object is a bit
  stream with variable-length codes (B, BB, BS, BL, BD, DD, MC, MS, H, among others); the reader
  assembles multi-byte integers arithmetically because dart2js bitwise operations are 32-bit. The
  header CRC-16 is verified (test "CRC-16 matches the checksum AutoCAD wrote").
- **R2000 writer**: a minimal but complete database: control tables (layers, line types, text
  style, viewport, appid, dimension style), named object dictionaries with layouts, model and paper
  space, and the entities LINE, LWPOLYLINE, CIRCLE, ARC, POINT and TEXT. The field order and the
  default values were checked against files written by AutoCAD and validated with LibreDWG
  (`dwgread`, `dwg2dxf`), which the test runs when installed, besides being re-read by our own
  reader.
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

### 20.3 KML and KMZ

Google Earth XML with lon, lat, altitude coordinates in WGS84; KMZ is a zip with the KML and
resources. Folders become layers, lines with altitude or an ELEV attribute become contour lines,
points with altitude become spot heights. The projection to UTM uses an automatic zone and a local
origin; the export does the reverse path with one folder per layer.

### 20.4 Shapefile, CSV/PNEZD

- **Shapefile**: `.shp` (geometry with a 100-byte big-endian header and little-endian records:
  points, polylines, polygons, multipoints and Z variants), `.dbf` (dBase attributes, where the
  elevation ELEV/Z/COTA and the name NAME/NOME/ID come from, decoded as the `.cpg` says or as UTF-8
  when valid and Latin-1 otherwise) and `.prj` (reference system), accepted inside a zip. Without
  `.prj`, coordinates are only treated as degrees when they fit the latitude/longitude range and at
  least half of them have four or more decimals; a local drawing in metres stays as it is.
- **Survey points**: CSV, TXT, XYZ and PNEZD (point, northing, easting, elevation, description)
  with column detection by header or position, comma, semicolon, tab and space separators, decimal
  comma and lat/lon recognition.

### 20.5 GeoTIFF, world files and images

TIFF with the GeoTIFF tags ModelPixelScale/ModelTiepoint or ModelTransformation and the CRS keys
(UTM or geographic). A single-band raster (float or integer) is treated as a DEM and becomes a grid
of spot heights, with nodata ignored; RGB rasters are background images. JPG and PNG images accept
world files (.jgw, .pgw, .wld) inside a zip: x = A·col + B·row + C and y = D·col + E·row + F for
the centre of every pixel, so the column axis (A, D) gives the pixel size and the rotation
(atan2(D, A)) and the top-left corner sits half a pixel back on both axes; the GeoTIFF
ModelTransformation matrix is treated the same way. Without a georeference, the image is placed in
the view and fitted by two points (similarity transformation: translation, rotation and scale).

### 20.6 PDF, SVG and XLSX

- **Own PDF 1.4** (`pdf.dart`): objects with an xref table, vector paths, standard Helvetica fonts
  with WinAnsi encoding (Portuguese and Spanish accents), clipping and Flate-compressed content
  streams. The sheet (`plot.dart`, `pdf_sheet.dart`) is built in paper space: pens, symbols and
  texts in paper millimetres, with automatic or fixed scale, title block, legend, north arrow,
  scale bar and report pages.
- **SVG**: the same scene in millimetres, one group per layer.
- **XLSX**: minimal SpreadsheetML (Office Open XML): one sheet per table, bold header, numbers as
  numbers and inline strings, without a shared-strings table; a reader of the same subset allows
  re-importing catalogues edited in Excel.

### 20.7 Verification with independent readers

The readers and writers are checked against third-party software, not only against each other.
`tool/formats/make_fixtures.py` writes to `test/fixtures/formats` import files produced by other
libraries: DXF R12, R2000, R2010 (in millimetres) and R2018 from ezdxf with blocks, bulges, MTEXT
and a 3D polyline; DWG R2000 from LibreDWG; shapefiles from pyshp (UTM polygons with `.prj`, Z
polylines with an ELEV attribute, WGS84 points, Z multipoints, a bare `.shp` in local
coordinates); GeoTIFF from tifffile (float32 UTM DEM with nodata, int16 geographic DEM, RGB
orthophoto); PNG and JPG from Pillow with world files, one of them rotated 30°; Google Earth style
KML and KMZ with nested folders, MultiGeometry, SchemaData and an inner ring; manufacturer CSV and
openpyxl XLSX catalogues. `test/core/formats_test.dart` imports every one and checks positions,
elevations, names and layers, and writes every export to `build/formats`, which
`tool/formats/check_exports.py` validates with ezdxf (audit), LibreDWG (`dwgread`, `dwg2dxf`),
lxml (KML, SVG), openpyxl, pypdf and the RFC 7946 rules for GeoJSON. That battery found and fixed:
UTF-8 DBF attributes read as Latin-1; a local shapefile without `.prj` taken for lat/lon; an
inverted sign in the rotation of world files and ModelTransformation; blocks, dimensions and 3D
polylines ignored in DXF and DWG; relative handles, xref bits in R2007+ and the object header order
in R13/R14 in the DWG reader; names with inch quotes (1/2") breaking the reading of XLSX
catalogues.

### 20.8 Project and catalogues

The `.oci.json` project and the `.oci.cat` catalogue are JSON with `format` and `version` keys; the
structure is in the README (section 11) and in `catalogs/README.md`. The decision to embed the
catalogue in the project makes the file self-contained and readable.

---

## 21. Performance and software architecture

- **Pure Dart engine** (`lib/core`, 18 thousand lines), without Flutter, run in a Web Worker in the
  browser and in an isolate on desktop. The protocol (`design_job.dart`) sends the project as JSON
  without images and receives progress, results and the resized entities; an edit counter discards
  the results of a project changed during the calculation.
- **Spatial index**: a static R-tree packed by Sort-Tile-Recursive (Leutenegger et al., 1997):
  items sorted by x, sliced into √P strips, every strip sorted by y and cut into leaves of 12
  items; parent nodes are packed the same way up to the root. O(n log n) construction on every
  edit, O(log n + k) query with the indices returned in drawing order. Measured with 40 thousand
  entities: construction in about 30 ms, visible-window query in 9 µs against 700 µs for a linear
  scan. The painter, the selection, the window selection and the snap query the index.
- **Emitter lumping**: every lateral becomes up to 100 nodes with grouped emitters
  (`maxNodesPerLateral`); a block of 44 tapes of 120 m has 4400 nodes and sizes in about 2 s. Tapes
  of neighbouring zones with coincident ends are merged by the graph builder, which doubles the zone
  and the time: the examples leave strips between blocks.
- **Sparse solver**: LDLᵀ with minimum-degree ordering; the matrix of branched zones is almost a
  tree, without fill-in.
- **Undo**: entity snapshots on every action (up to 50), with labels for the history panel.
- **Storage**: browser key/value with autosave, recents, versions and recovery, within the limit of
  about 5 MB per origin (3.5 MB per project).
- **Site**: pages generated with real HTML content for the search engines, because Flutter paints
  on a canvas (see README, section 13).

---

## 22. Validation

The suite has 343 tests (`flutter test`). Those validating the hydraulics against references:

| Test | Reference |
|---|---|
| Hazen-Williams matches textbook value | Tabulated value from a hydraulics manual |
| Darcy-Weisbach agrees with Hazen-Williams for smooth PVC | Consistency between formulas on smooth PVC (a few per cent difference) |
| Swamee-Jain close to Colebrook | Error < 1 % (Swamee & Jain 1976) |
| transitional cubic matches the turbulent slope at Re = 4000 (EPANET) | Dunlop's polynomial as coded in EPANET |
| Christiansen F factor table values; Scaloppi adjustment | Keller & Bliesner tables; Scaloppi 1988 |
| pressure dependent emitters; PRV holds downstream pressure; two reservoirs in a loop split the flow | Cases from the EPANET manual |
| emitters under negative pressure (closed, no backflow, reopen) | Mass balance of one-way emitters |
| friction loss agrees with Christiansen estimate | Solver versus F factor |
| downhill slope raises end pressure; feed positions | Wu & Gitlin 1975 |
| sector pivot: same cycle time gives a proportionally lower application rate | Keller & Bliesner, chapter 14 |
| PVC celerity in expected range | 300 to 600 m/s in PVC |
| capital recovery factor; operating point | Financial and pump formulas |
| Delaunay of a plane reproduces the plane exactly | Property of the linear interpolator |
| UTM inverse round trip; georeference from a lat/lon origin | Karney 2011 |
| CRC-16 matches the checksum AutoCAD wrote; LibreDWG accepts the file | Real files and an independent tool |
| LP design meets the pressure window and costs no more than greedy | Relative optimality of the LP |

The gallery examples work as integration tests: the fifteen projects, in the three languages,
build, pass the check, size with every zone inside the window and without supply deficit, print
every report cell as a plain number, and match the published files.

---

## 23. Gaps and future work

From the research point of view, what the literature and design practice suggest as next steps:

1. **Loops in the LP**: an exact formulation for looped networks (the current LP uses tree paths
   and the final analysis checks); the network optimisation literature suggests loop decomposition
   or non-linear programming.
2. **Transients**: a method of characteristics for water hammer with valves and pumps, instead of
   the Joukowsky estimate.
3. Automatic **"unconnected" sprayline** and valve-in-head with its own zone per sprinkler as a
   dedicated entity.
4. **Splines and hatches in DWG**: SPLINE and HATCH on import; more entities and newer versions on
   export.
5. **Fertigation and water quality**: injection calculation and water travel times in the network.
6. **Electrical system**: wires, controllers and solenoids in the bill of materials.
7. **Collaboration**: sharing by link and simultaneous editing, keeping the principle of not
   depending on a server of our own (for instance, files in the user's services).
8. **Browser tests** for runtime behaviour (system language, PWA).

---

## 24. Glossary

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
| GGA | GGA | Global Gradient Algorithm, the Todini-Pilati method for networks |
| BOM | Lista de materiais | Bill of materials |
| PRV | Válvula reguladora de pressão | Pressure-reducing valve |

---

## 25. Sources

Hydraulics and networks:
- Rossman, L. et al. EPANET 2.2 User Manual, Analysis Algorithms: https://epanet-manual.readthedocs.io/en/latest/analysis_algorithms.html
- Todini, E.; Pilati, S. (1988). A gradient algorithm for the analysis of pipe networks. Computer Applications in Water Supply, vol. 1.
- Swamee, P. K.; Jain, A. K. (1976). Explicit equations for pipe-flow problems. J. Hydraulics Div. ASCE 102(5).
- Christiansen, J. E. (1942). Irrigation by sprinkling. Univ. California Bull. 670.
- Scaloppi, E. J. (1988). Adjusted F factor for multiple-outlet pipes. J. Irrig. Drain. Eng. 114(1): https://ascelibrary.org/doi/10.1061/%28ASCE%290733-9437%281988%29114%3A1%28169%29
- Wu, I. P.; Gitlin, H. M. (1975). Energy gradient line for drip irrigation laterals. J. Irrig. Drain. Div. ASCE 101(4).
- Keller, J.; Bliesner, R. D. (1990). Sprinkle and Trickle Irrigation. Van Nostrand Reinhold.
- Keller, J.; Karmeli, D. (1974). Trickle irrigation design parameters. Trans. ASAE 17(4).
- Chu, S. T.; Moe, D. L. (1972). Hydraulics of a center pivot system. Trans. ASAE 15(5).
- Hazen-Williams versus Darcy-Weisbach in PE: https://iwaponline.com/aqua/article/74/8/493/108822/ ; https://elibrary.asabe.org/abstract.asp?JID=3&AID=25699 ; C factors: https://simupipe.com/resources/hazen-williams-c-factor
- Emitters: https://doi.org/10.3390/w14071034 ; https://doi.org/10.3390/w18020244 ; https://workforce.libretexts.org/Bookshelves/Water_Systems_Technology/Irrigation_Systems_Management_(AET_021)/14:_Microirrigation/14.06:_Uniformity
- Uniformity: Xue et al. (2023), Irrigation and Drainage: https://onlinelibrary.wiley.com/doi/abs/10.1002/ird.2837 ; https://www.sciencedirect.com/science/article/abs/pii/S1537511005002205
- Laterals: https://link.springer.com/article/10.1007/BF00273380 ; https://www.sciencedirect.com/science/article/abs/pii/S0378377417304079
- Friction factor: https://www.sciencedirect.com/science/article/pii/S2090447919300176
- Water hammer and velocity: https://www.rainbird.com/professionals/irrigation-design-tip-sizing-pipe ; https://www.instrumentationblog.in/joukowsky-equation-water-hammer/
- Pumps: https://www.northridgepumps.com/article-9_how-to-read-a-pump-curve
- Minor losses: Crane TP-410; https://simupipe.com/resources/k-factor-table ; https://neutrium.net/articles/fluid-flow/pressure-loss-from-fittings-excess-head-k-method/
- NRCS National Engineering Handbook, Part 623, chapter 7 (Microirrigation) and chapter 11 (Sprinkler): https://www.wcc.nrcs.usda.gov/ftpref/wntsc/waterMgt/irrigation/NEH15/ch7.pdf , .../ch11.pdf
- FAO Irrigation Manual, modules 8 and 9: https://www.fao.org/4/ai596e/ai596e.pdf
- Allen, R. G. et al. (1998). FAO Irrigation and Drainage Paper 56: Crop evapotranspiration.

Terrain, geoprocessing and algorithms:
- Karney, C. F. F. (2011). Transverse Mercator with an accuracy of a few nanometers. Journal of Geodesy 85(8).
- Bowyer, A. (1981); Watson, D. F. (1981). Computing the n-dimensional Delaunay tessellation. The Computer Journal 24(2).
- Leutenegger, S. T.; Lopez, M. A.; Edgington, J. (1997). STR: a simple and efficient algorithm for R-tree packing. ICDE.
- Open-Meteo Elevation API: https://open-meteo.com/en/docs/elevation-api ; Copernicus DEM GLO-90.
- OpenTopoData: https://www.opentopodata.org/ (SRTM, ASTER).

Formats:
- Open Design Alliance. Open Design Specification for .dwg files (version 5.4.1).
- LibreDWG: https://www.gnu.org/software/libredwg/
- Autodesk DXF Reference.
- ESRI Shapefile Technical Description (1998); GeoTIFF Specification 1.8.2; PDF Reference 1.4 (Adobe); ECMA-376 Office Open XML (SpreadsheetML); OGC KML 2.3; RFC 7946 (GeoJSON).
