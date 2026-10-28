+++
title = "Smoother large battles"
summary = "Large battles draw buildings and squad symbols with less repeated work, while damage, cover and individual soldiers keep their existing behavior."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "The large-map battle before scenery drawing is combined."

[[screenshots]]
file = "after.jpg"
caption = "Combined scenery drawing preserves the buildings and their shadows during combat."
+++

- Static buildings share drawing work. A damaged or moved structure updates immediately without rebuilding its neighbors.
- Soldiers share frame-update bookkeeping while retaining individual movement smoothing, poses and selection.
- Squad counters keep a clear screen position as nearby units move, reducing clutter and repeated layout work.
- Firing markers reuse their star geometry, and the minimap refreshes damaged buildings gradually while keeping the previous map visible.
- Moving soldiers avoid recording sight checks they cannot reuse; soldiers standing still, including those waiting for a route, retain their obstruction cache.
