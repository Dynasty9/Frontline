+++
title = "More deliberate tank handling"
summary = "Tank turrets accelerate and settle onto targets, hold their bearing through hull turns, and acquire a steady aim before firing."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: the tank engaging the RPG team."

[[screenshots]]
file = "after.jpg"
caption = "After: the same encounter with gradual traverse and deliberate gun laying."

[[videos]]
file = "tank-motion.mp4"
poster = "tank-motion-poster.jpg"
caption = "The tank turns, traverses its turret and advances past the wall. Recorded in the current build, October 2026."

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

- Tank drivers build into turns rather than instantly changing their turning speed.
- Turrets traverse with acceleration and braking, and return forward by the shortest arc.
- Gunners hold a steady aim briefly before firing, including when switching targets.
