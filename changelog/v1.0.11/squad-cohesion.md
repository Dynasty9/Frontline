+++
title = "Squads stick together"
summary = "Squads stay closer together and choose cover on the same side of walls."
kind = "improved"


[[screenshots]]
file = "after.jpg"
caption = "After: four soldiers take cover against the middle wall; the fifth stacks in a second row 1.5 metres behind them, with reduced protection. Same scenario, seed, time and camera as before."

[[screenshots]]
file = "before.jpg"
caption = "Before: one squad spreads across all three walls while seeking cover. Enemies are beyond the walls, outside this view."



[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Squads move in tighter groups and choose nearby cover on the same side of walls.

- Move and defend orders keep soldiers in a compact circle instead of a long line.
- Soldiers favor cover beside their squad instead of spreading out across walls.
- When a tall wall's front row is full, soldiers stack a pace behind it instead of lying farther out in the open. The rear row still benefits from the wall blocking fire, but lacks the close-cover protection of hugging it.
- Travelling squads follow their leader through gaps, and the leader slows for stragglers.
