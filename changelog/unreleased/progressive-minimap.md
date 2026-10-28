+++
title = "Steadier minimap updates"
summary = "Minimap drawing is spread across frames while camera and pointer feedback stays responsive."
kind = "improved"

[[screenshots]]
file = "after.jpg"
caption = "The minimap keeps its detail while its layers take turns updating."

[[screenshots]]
file = "rotated.jpg"
caption = "Map layers remain aligned when the minimap turns with the camera."
+++

- Map details, combat markers, units and co-op markers take turns updating, reducing the work that lands on any one frame.
- The camera wedge and pointer update every frame. Rotating or resizing the minimap keeps all its layers aligned.
- Large-map building checks run in small slices, and soldiers share repeated smoothing calculations without changing their movement.
