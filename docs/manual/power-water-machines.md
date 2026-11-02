# Power, water and machines

These analyses run as a step of the design, after the valve wiring, once they are switched on in their dialog, and
their results are in the **Power, water and machines** tab of the reports panel and in every report export: the
electrics of the pump house and of the pivots' supply, solar pumping, the water analysis with its filtration and
treatment, and the two-wire valve wiring. Their settings are kept in the project file under `agb`, only what differs
from the defaults. Travelling-gun lanes and furrow sets are items of the drawing that the design reads as demand
points of the mainline. The dialogs:

| Menu | Dialog |
|---|---|
| Design | Pump house electrics…, Solar pumping of the design…, Water quality and filtration… |
| Design → Automatic design | Several pivots in the property… |
| Zone | Two-wire system (decoders)… |
| Mainline | Traveller lanes…, Furrows with gated pipe… |

## Pump house electrics

For every electric pump: the motor (the output from the pump data, or the next standard motor above the largest shaft
power of its duties, with the efficiency of IEC 60034-30-1 class IE3), its current, the starting method (direct,
star-delta, soft-starter or drive, with the largest direct start set in the dialog) and the feeder cable sized by
ampacity (NBR 5410, Tables 36 to 40, as IEC 60364-5-52, with the insulation, installation method, temperature and
grouping chosen), by the voltage drop running (6.2.7) and while starting (10 % at the starter, 6.5.1.3.3), and by the
short circuit (IEC 60909). For the supply: the transformer (NBR 5440) or the generator, the short-circuit current,
the installed load, the largest simultaneous demand, the largest start and the probable tariff group; the pivots with
an electrical design can draw from the same transformer (span cable, collector ring, end tower). The figures come
from the last design; with *Include the pump house electrics in the design and the bill of materials*, the cables,
the starter panels and the transformer or generator enter the bill of materials.

## Solar pumping of the design

- **Off-grid**: the photovoltaic array of the month of largest need (IEC 62253) for the daily volume of every month
  (from the crop requirement tables, else the volume the system flows pump in a day) against the total dynamic head
  of the design, with the tilted irradiation of the site and the performance ratio of IEC 61724-1. The pumps draw
  nothing from the grid: the energy cost of the design goes to zero, and the months the array cannot serve are
  reported.
- **Grid-tied**: the array of the yearly pumping energy, compensated as Brazil's Lei 14.300/2022 sets (the Fio B paid
  on the credits by the year billed; an access asked before 7 January 2023 has no Fio B until 2045). The energy cost
  of the design deducts what the array gives.

The modules, their structure and the inverter (or pump drive) enter the bill of materials at the prices of the
dialog. The solar pumping calculator of the Tools menu stays for a quick estimate.

## Water quality and filtration

Type the water analysis (an empty field is not analysed): source, pH, electrical conductivity, dissolved and
suspended solids, iron, manganese, calcium, bacteria and temperature. The clogging hazard of drip and micro
irrigation water follows the classes of Nakayama (1982) and Nakayama and Bucks (1986); the Langelier index tells
scaling water; the filter opening is a fraction of the smallest passage of the emitters (the media, disc or screen
filter that gives it); chlorination (continuous free chlorine at the end of the lines, or shocks) and acid (to the pH
wanted) use the doses of the extension literature, and the injector doses at the design flow.

## Two-wire system

*Two-wire system (decoders)…* turns the valve wiring into a two-wire system: one pair of wires leaves the controller
along the wire routes and passes every valve, and a decoder on the pair drives the valves within the reach of its
solenoid cable. With *Use two-wire in the design and the bill of materials*, the design sizes the pair of every
controller (voltage at every decoder, grounding points) and the bill of materials lists the decoders, the two-wire
cable, the surge arresters with their ground rods and the splices instead of the station wires. It needs a controller
and wire routes (Zone → Wire route, or Automatic wire routes).

## Several pivots in the property

Select the outline of the property (an irrigated area or a closed polyline) and, with it, the closed shapes to keep
clear of (legal reserves, roads, buildings, machines already drawn). The dialog looks for the arrangement of centre
pivots of standard spans that irrigates the most: the largest full circle first, and lattices of equal machines, each
grown as far as it fits, with a clearance between the circles and from the boundary, within the flow allowed (the
water right; by default the largest flow of the supply), the end sprinkler throw, the smallest wetted radius, the
most pivots and the fewest and most towers. The common mainline joins the supply to every pivot point by the shortest
network (a minimum spanning tree).

## Traveller lanes and furrows

- **Traveller lanes** (layer TRAVELLERS): parallel lanes of a travelling gun across the selected field, spaced by the
  wind table of NRCS NEH 623 chapter 11 for the wetted diameter of the gun; each lane starts at a hydrant on the edge
  of the field and runs the hose length. Every hydrant is a demand of the mainline with the flow and the pressure the
  traveller needs there (gun pressure, hose friction, drive loss, gun height and the rise of the ground); the lanes
  of one reel are served one after the other, and the report gives the speed for the target depth, the travel and
  set-up times and the pressure the design leaves at the hydrant.
- **Furrows with gated pipe** (layer SURFACE_IRRIGATION): the furrows run from the selected head line (its first
  point is the inlet). The volume-balance model (FAO 45) finds the inflow per furrow of the highest efficiency and
  the cutoff time for the depth; the gated pipe of the farthest set gives the pressure at the inlet, which is a
  demand of the mainline, with one system flow per position of the sets.

Both are drawn on the drawing board, on the sheets and in the DXF/DWG exports, and enter the report and the bill of
materials. The hose-reel traveller and gated pipe calculators of the Tools menu stay for a quick estimate.
