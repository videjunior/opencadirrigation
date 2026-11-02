# Drawing and editing

## Drawing entities

Line, polyline (open or closed), rectangle, circle, arc, spline (smooth curve through the points),
hatch (lines or solid), symbol (north arrow, tree, building, tank, well, valve box, pump house,
gate, filter station), text, linear, angular, radial and diameter (Ø) dimensions, ordinate
dimension (the X or Y of a point from the drawing origin: a vertical leader writes X, a horizontal
one Y), leader, image (georeferenced raster, PDF plan or picture placed by hand), contour line,
breakline, spot height and irrigated area. Review entities: **comments** (a note with its author,
date and a resolved flag) and **revision clouds** (a scalloped outline with the revision tag, date
and description; the sheet's revision table lists them), each with its report tab.

## Snaps

Endpoints, midpoints, centres, quadrants, intersections (lines, arcs and circles), perpendicular and
tangent from the previous point, extension beyond the end of a line, hydraulic nodes, "on" pipes
and laterals (the nearest point of the segment), circle perimeters, grid, ortho, polar tracking
(F10) and 45° lock with Shift. The tolerance is in pixels, so it does not depend on the zoom. The
marker changes shape with the snap type.

## Selection and grips

Click selects; Shift+click toggles; a window dragged left to right selects what lies entirely
inside it and right to left what it crosses (the usual CAD convention). Up to 60 selected entities show
**grips**: drag a vertex to move it, drag the midpoint of a segment to insert a vertex, Ctrl+click a
vertex to remove it. With *keep connections* (on by default) dragging a pipe node takes the
valves, items and wire routes sharing it along; dragging a wire vertex moves only the wires.

## Transformations

Move (drag), rotate, mirror (keeping the original or not), scale, offset, trim and extend against
the selected or visible entities, cut pipes, rectangular or polar array and alignment by two
points (moves, rotates and scales an image or an imported drawing in one go). Inserting a valve,
junction, pump or device on a pipe splits the pipe at that point. Zone → Device on the selected
laterals… puts the same device (regulator, gate valve…) at the inlet of every selected lateral and
tape; Turn the selected laterals into blank pipe keeps their path without emitters.

## User blocks

Edit → Save selection as block (`WBLOCK`) keeps the selection as a named block with a base point
(a valve manifold, a standard head layout, a title); Insert block (`INSERT`) places copies with a
rotation and a scale at a picked or typed point, each insertion one undo step with new ids and the
layers it lacks. The library travels in the project file and exports as DXF/DWG block definitions.

## Layers

Every entity type is born on its default layer (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Layers imported from DXF/DWG/KML/PDF are
preserved. A layer can be hidden (leaves the drawing, the snap and the selection) or locked
(visible but not editable).

## Labels

View → Labels shows names and sizes; View → Conditional labels… adds rules that write a result
next to the pipes (velocity, flow, pressure, head loss, diameter), outlets (pressure, flow) or
valves (flow, pressure, downstream pressure) where it is above or below a value, or always, in a
colour of their own (velocity above 1.5 m/s in red, say). The rules travel with the project.

## History

Every action produces a named state (add line, move 3 items, design, import…). Undo and redo walk
up to 150 states (fewer in very large drawings: the copies kept stay below 400 000 entities); the
History panel jumps to any of them. The dialogs that edit the project in place (details,
parameters, units, catalogue, management) also make one undo step each, however they are closed
(OK, Esc or a click outside): the edits are kept, the project is marked as modified and results
computed with the old settings are discarded. A dialog that generates something (a layout, a block
of laterals, the routes of the wires) and every answer of the AI assistant that changed the
project are one step too.
