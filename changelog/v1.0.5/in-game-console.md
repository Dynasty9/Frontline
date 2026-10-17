+++
title = "A console that tells you why the game is slow"
summary = "Press the key under Esc (` or ~) for a console. Type why and it works out what's holding your frame rate back; bench measures what each graphics setting costs you; graph shows every frame and its stutters."
kind = "new"

[[screenshots]]
file = "console-why.jpg"
caption = "why: what's holding the frame rate back, and the stutters of the last minute"

[[screenshots]]
file = "frame-graph.jpg"
caption = "graph: every frame of the last few seconds, split into what its time went on, stutters marked in red"
+++

- **`why`** looks at the last few seconds and says what's limiting you: your screen's refresh rate, the graphics
  card, or the processor, and which part of the game takes the most. It also flags stutters, a flood of engine
  errors, an integrated graphics chip and a slow connection to the host.
- **`bench`** turns each graphics setting down in turn (shadows, ambient occlusion, grass, water, render scale and
  more), times it, and lists what each one saves, the most first. It puts your settings back when it's done.
  `bench quick` is faster.
- **`graph`** pins a frame-time graph to the screen; **`hitches`** lists the latest stutters and what each one
  was; **`top`** shows the costliest parts of the game.
- **`render`**, **`sys`**, **`net`** and **`errors`** show what's being drawn, your computer, your connection and
  anything the engine has complained about.
- **`set shadows off`**, **`preset low`** and the like change settings on the spot; **`perf 3`** brings up the
  full performance overlay.
- **`report`** writes all of it to a file and copies it to the clipboard, ready to paste to whoever is helping.
- Tab completes, Up and Down bring back what you typed, Esc closes it. The key can be changed in Settings >
  Controls.
- The compact performance overlay (F3) no longer draws its GPU bar over its first line, or its last line
  below the panel.
