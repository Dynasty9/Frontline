+++
title = "Less work during busy battles"
summary = "Pathfinding spends less time maintaining its cache, and animated combat markers reuse their geometry."
kind = "improved"
+++

- Long routes no longer scan the entire local navigation cache when replacing an old entry.
- Combat markers keep the same pulsing, rotating shape with less work per frame.

These changes reduce specific costs; they do not establish 60 FPS support for 500-unit battles on large maps.
