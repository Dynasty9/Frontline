+++
title = "Less work during busy battles"
summary = "Busy battles spend less time maintaining routes and rebuilding animated combat markers."
kind = "improved"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Pathfinding spends less time maintaining its cache, and animated combat markers reuse their geometry.

- Long routes no longer scan the entire local navigation cache when replacing an old entry.
- Combat markers keep the same pulsing, rotating shape with less work per frame.

These changes reduce specific costs; they do not establish 60 FPS support for 500-unit battles on large maps.
