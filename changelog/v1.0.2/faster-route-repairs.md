+++
title = "Smoother battles as the ground changes"
summary = "Changing terrain causes less disruption as the host updates routes around new walls, damage and fire."
kind = "improved"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

When walls go up, buildings come down or fires take hold, the host now updates the map soldiers and vehicles plan their routes on about ten times faster, so a big battle spends far less of each moment on it.

- **What changed:** every change to the ground used to cost the host several milliseconds of re-planning, on about
  a third of all of the game's updates in a big battle. It now redoes only what the change can reach: a fraction of
  a millisecond as a rule.
- **What didn't:** the routes. Soldiers and vehicles go exactly the way they did before, and a replayed battle plays
  out the same.
