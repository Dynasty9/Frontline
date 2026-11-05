+++
title = "Steadier route planning and reliable battle endings"
summary = "Large battles can spread long route searches across updates, and matches deliver the final battlefield state before showing the result."
kind = "improved"
+++

- Long route searches now pause at their work limit and resume from where they stopped. New orders and changed terrain replace stale searches.
- Saved battles preserve unfinished searches so replay verification makes the same decisions.
- Desktop and browser battle endings include the final units, effects and resource totals before the report appears.
- Soldier actions avoid copying entire routes, and unit and vehicle definitions are prepared once when a match loads. The existing combat and movement rules remain in place.
