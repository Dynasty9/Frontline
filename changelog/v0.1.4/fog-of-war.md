+++
title = "A fog of war you can see"
summary = "See where your side has eyes on the ground and where enemy positions are only last-known reports."
kind = "new"
headline = true


[[screenshots]]
file = "fog-of-war.jpg"
caption = "The fog of war in a bridgehead battle"

[[screenshots]]
file = "before.jpg"
caption = "The same moment before: nothing showed where your vision ended"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Ground your side can't see right now is drawn darker on the battlefield and the minimap, so you know where your vision ends and where you need eyes.

- The edge is soft, aircraft overhead aren't darkened, and at night it's lighter because everything is dark already.
- **What you see darkened is exactly what's hidden from you:** enemies inside it don't show.
- **Last-known positions:** an enemy anyone on your side has seen stays marked where it was last seen for 90 seconds, with how long ago.
- The new eye button in the map layers turns the fog off.
