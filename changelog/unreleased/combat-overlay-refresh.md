+++
title = "Smoother large battles"
summary = "Large formation orders take less work, and pointer feedback updates independently of squad counters."
kind = "improved"

[[screenshots]]
file = "after.jpg"
caption = "Cover previews stay aligned at enlarged interface scale while updating independently of squad counters."
+++

- Selection boxes, tooltips and order previews update immediately in their own drawing layer, without rebuilding every squad counter as the pointer moves.
- Camera shake keeps the existing status refresh rate. Panning, zooming, selection and commands still refresh the counters immediately.
- Combat and camera shake are unchanged.

- Large formation orders spend less time choosing ground while keeping the same cover choices, spacing and placement order.
- Soldiers spend less time checking ground and trench heights in built-up areas. Distant squads draw more efficiently with the same poses.
- Moving soldiers check visibility more efficiently, preserving the effects of smoke, doors and cover.
