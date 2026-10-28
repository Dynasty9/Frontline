+++
title = "Smoother large battles"
summary = "Large formation orders take less work, and pointer feedback updates independently of squad counters."
kind = "improved"
+++

- Selection boxes, tooltips and order previews update immediately in their own drawing layer, without rebuilding every squad counter as the pointer moves.
- Camera shake keeps the existing status refresh rate. Panning, zooming, selection and commands still refresh the counters immediately.
- Combat and camera shake are unchanged.

- Formation orders evaluate nearby ground once for the whole group. Native builds score those candidates in Rust, keeping the same cover choices, spacing and placement order; other builds use the GDScript fallback.
- Ground-height checks look up nearby trenches directly instead of scanning surrounding buildings. Distant soldier batches also spend less time on per-frame bookkeeping.
- Moving soldiers reuse ray-query setup while checking a target, preserving visibility through smoke, doors and cover.
