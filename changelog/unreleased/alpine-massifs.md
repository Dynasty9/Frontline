+++
title = "Break up mountain silhouettes"
summary = "Uneven mountain groups, lower passes and reshaped cliff shoulders replace repetitive ridges, with more varied moss-to-rock transitions."
kind = "improved"

[[screenshots]]
file = "wide-before.jpg"
caption = "Before: distant mountain groups and passes."

[[screenshots]]
file = "wide-after.jpg"
caption = "After: distant mountain groups and passes."

[[screenshots]]
file = "close-before.jpg"
caption = "Before: cliff shoulders and the valley floor."

[[screenshots]]
file = "close-after.jpg"
caption = "After: cliff shoulders and the valley floor."

[[screenshots]]
file = "detail-before.jpg"
caption = "Before: close cliff profile."

[[screenshots]]
file = "detail-after.jpg"
caption = "After: reshaped shoulder and snow shelf; camera follows local terrain."
+++

Distant scenery uses its own seeded height field instead of an equal-height ridge pattern. Floating-point heights and wider slope sampling avoid stepped snow shading. Medium/Far detail uses a finer indexed scenery mesh; Near retains the lighter grid.

Reusable rock forms now have uneven shoulders and irregular drainage cuts before the existing terrain erosion and road grading. These enter the authoritative terrain used by movement, construction and replay. Material coverage also varies with photographic rock relief.

The comparisons use the same seed, lighting and camera controls. The camera follows local ground height, so changed geology can shift its absolute height. Procedural trees and some smooth rock forms still limit realism; these are native game captures, not photographic composites.

Approach informed by [Wargaming's environment workflow](https://wargaming.com/en/news/making_battle_arenas_in_wows/): establish large landforms before surface detail.
