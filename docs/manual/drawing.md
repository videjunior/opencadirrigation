# Drawing and editing

## Drawing entities

Line, polyline (open or closed), rectangle, circle, arc, spline (smooth curve through the points),
hatch (lines or solid), symbol (north arrow, tree, building, tank, well, valve box, pump house,
gate, filter station), text, linear, angular, radial and diameter (Ø) dimensions, ordinate
dimension (the X or Y of a point from the drawing origin: a vertical leader writes X, a horizontal
one Y), leader, image (georeferenced raster, PDF plan or picture placed by hand), contour line,
breakline, spot height and irrigated area. Review entities: **comments** (a note with its author,
date and a resolved flag, optionally with a field photo) and **revision clouds** (a scalloped outline
with the revision tag, date and description; the sheet's revision table lists them), each with its
report tab. Draw → Field photo… pins a photo to the drawing as a comment, at the position its GPS
gives, at the device's position or at a click. Draw → Dimension style… sets the text height,
arrowheads (none, arrow, tick or dot), decimals and unit of every dimension of the project, on the
screen, on the sheets and in DXF/DWG; the default draws them as earlier versions did. A double click
on a text edits it in place (Enter keeps it, or Ctrl+Enter for a text of several lines; Esc cancels).

## Snaps

Endpoints, midpoints, centres, quadrants, intersections (lines, arcs and circles), perpendicular and
tangent from the previous point, extension beyond the end of a line, hydraulic nodes, "on" pipes
and laterals (the nearest point of the segment), circle perimeters, grid, ortho, polar tracking
(F10) and 45° lock with Shift. The tolerance is in pixels, so it does not depend on the zoom. The
marker changes shape with the snap type.

View → Snaps and drawing… turns each object snap on or off (endpoint, midpoint, centre, quadrant,
node, intersection, perpendicular, tangent, nearest, extension) and sets the snap distance, polar
tracking, ortho, the grid step, the **dynamic input** (length and angle beside the cursor: type the
length, Tab, then the angle, or a bearing such as N45E or an azimuth such as A120; Enter places the
point), the **magnifier** over the finger on touch screens and *Edit while the design runs* (off by
default: the design then works on a copy, and its results, out of date once you change something, are
discarded). Typed while drawing, `END`, `MID`, `CEN`, `QUA`, `NOD`, `INT`, `PER`, `TAN`, `NEA` or
`EXT` (and their Portuguese names) choose the snap of the next point only, as *Snap for the next
point* does in the right-button menu; `NON` clears it. These settings and those of the drawing tools
are kept in this browser for the next visits and tabs.

## Selection and grips

Click selects; Shift+click toggles; a window dragged left to right selects what lies entirely
inside it and right to left what it crosses (the usual CAD convention). Edit → Select ▸ adds
*Select similar* (same kind and catalogue item, or same kind on the same layer), *Quick select…* (by
kind, layer, catalogue item, zone, or a range of length, area, elevation, pressure or diameter, to
replace, add to, take from or filter the selection), all on the current layer, and the **lasso** (by
hand or by clicks) and **fence** tools; the Layers tab selects the items of a layer. When the
selection mixes kinds, Properties shows a chip per kind and edits one kind at a time; a field whose
values differ stays empty and any number typed applies to all. Up to 60 selected entities show
**grips**: drag a vertex to move it, drag the midpoint of a segment to insert a vertex, Ctrl+click a
vertex to remove it. With *keep connections* (on by default) dragging a pipe node takes the
valves, items and wire routes sharing it along; dragging a wire vertex moves only the wires.

## Transformations

Move (drag, or Move `M` with a base point and a destination clicked or typed), Copy with a base
point (`CO`, repeated from the same base point until Esc), rotate, mirror (keeping the original or
not; texts stay readable and symbols are reflected), scale, offset (the preview is the copy it makes),
trim and extend against the selected or visible entities (closing segments, circles, arcs and
splines included), cut pipes, rectangular or polar array and alignment by two points (moves, rotates
and scales an image or an imported drawing in one go). Rotate, Scale and Offset take the angle, the
factor or the distance typed on the command line. Edit → Geometry ▸ has **stretch** (by a window),
**fillet** (a circular curve, T = R·tan(Δ/2)) and **chamfer** between two lines or at a vertex,
**break at two points**, **join** (lines, polylines and arcs, pipes of one kind, wires, contours and
breaklines with coincident ends, never across a valve), **explode** (polylines, hatches, splines,
leaders, pipes, laterals and tapes into segments, keeping the emitters), **convert to area** (closed
polylines, circles, hatches and closed splines), and **Subtract from area**: a closed shape selected
with an irrigated area becomes an island of it (a pond, a building), a notch, or splits it, and leaves
the drawing; *Remove the islands of the area* gives the whole outline back. **Lengthen** (`LEN`)
changes an open item at its nearest end by a difference, to a total length or by a percentage (the
outlets of a spray lateral stay where they were); **Outline by a click inside** (`BO`) makes the
smallest region the drawn lines close around a point, as a polyline or an irrigated area; the
drawing order puts the selection in front or behind (`TOFRONT`, `TOBACK`). Each edit is one undo
step with its own name. Measure (`ME`) keeps its last result on the drawing and in its panel, with
a button to copy it: the distance between two points, the length along several points or the area and
perimeter of an outline (modes D, M and A). Inserting a valve,
junction, pump or device on a pipe splits the pipe at that point. Zone → Device on the selected
laterals… puts the same device (regulator, gate valve…) at the inlet of every selected lateral and
tape; Turn the selected laterals into blank pipe keeps their path without emitters.

## User blocks

Edit → Save selection as block (`WBLOCK`) keeps the selection as a named block with a base point
(a valve manifold, a standard head layout, a title); Insert block (`INSERT`) places copies with a
rotation and a scale at a picked or typed point, each insertion one undo step with new ids and the
layers it lacks. The library travels in the project file and exports as DXF/DWG block definitions.

A block of drawing items (lines, polylines, circles, arcs, splines, hatches, symbols, texts,
dimensions, leaders) can go in as a **block reference**: the definition drawn where the reference is,
with its rotation and scale. Texts written `{TAG}` in the selection become **attributes**, whose
values each reference holds (Properties edits them); a block marked to count in the bill of
materials lists its references there. When saving a block, the selection can be replaced by a
reference to it, and redefining a block updates all its references. Edit → Blocks ▸ edits a block in
place (`BEDIT`: change the copies, then *Save block*), explodes references into plain items, and
exports or imports the block library (`.oci-blocks.json`, or the blocks of another project file). A
block with hydraulic or terrain items always goes in as copies, which the design sees; references are
passive for the calculation and go to DXF/DWG as INSERT with ATTRIB.

## Layers

Every entity type is born on its default layer (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Layers imported from DXF/DWG/KML/PDF are
preserved. A layer can be hidden (leaves the drawing, the snap and the selection) or locked
(visible but not editable). View → Layers ▸ isolates the layers of the selection (or the current
one) and shows every layer again (`LAYISO`, `LAYUNISO`), and *Layer states…* keeps named states of
which layers are shown and locked ("hydraulic sheet", "electrical sheet") to restore with one choice;
Edit → Move to the current layer (`LAYCUR`). The traveller lanes and furrow sets are born on the
TRAVELLERS and SURFACE_IRRIGATION layers, made with the first of them.

## Labels

View → Labels shows names and sizes; View → Conditional labels… adds rules that write a result
next to the pipes (velocity, flow, pressure, head loss, diameter), outlets (pressure, flow) or
valves (flow, pressure, downstream pressure) where it is above or below a value, or always, in a
colour of their own (velocity above 1.5 m/s in red, say). The rules travel with the project.

## History

Every action produces a named state (add line, move 3 items, design, import…). Undo and redo walk
up to 150 states (fewer in very large drawings: the copies kept stay below 400 000 entities); the
History panel jumps to any of them. The dialogs that edit the project in place (details,
parameters, units, catalogue, management, quote, conditional labels, title block) make one undo
step each when closed with OK: the edits are kept, the project is marked as modified and results
computed with the old settings are discarded; Cancel, Esc or a click outside puts everything back
as it was. A dialog that generates something (a layout, a block
of laterals, the routes of the wires) and every answer of the AI assistant that changed the
project are one step too; an analysis that changes no item records no step.

## Comparing copies

File → Compare with… sets the open project against another tab, a version kept in the browser or a
file: the items added, removed and changed (matched by id, each shown on the drawing), the settings
that differ (details, parameters, catalogue, layers, system flows, blocks) and the main figures of
both (items, pipe and lateral lengths, outlets, valves, irrigated area and, with results, the largest
flow, the pressures and the cost of the materials). File → Bring back the comments of a copy… adds
the review comments and revision clouds of a reviewed copy (matched by id, else by place and text),
so a project can be reviewed without a server. File → Version history compares a version with the
project and opens it in a tab of its own.
