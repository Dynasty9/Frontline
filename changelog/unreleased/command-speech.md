+++
title = "Readable warnings in crowded battles"
summary = "At command zoom, repeated squad shouts share one bubble and urgent calls take priority over overlapping chatter."
kind = "improved"

[[screenshots]]
file = "before.png"
caption = "Before: individual grenade warnings overlap across the command view. PR #112, seed 3, 500 initial soldiers, 35 m zoom, 62 seconds."

[[screenshots]]
file = "after.png"
caption = "After: repeated squad warnings share a bubble, with up to 32 visible phrases. Same scenario and camera; visual evidence, not an FPS comparison."
+++

- Command views show up to 32 visible phrases, favoring selected units, radio orders and casualty calls.
- Zoom in to see individual speech. Audio, orders and soldier behavior are unchanged.

- Routine squad summaries, roster refreshes and overlay drawing take separate preparation frames to avoid doing them all together. Camera movement and input still refresh the display immediately.
