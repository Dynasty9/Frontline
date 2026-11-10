+++
title = "Reuse prepared battlefields"
summary = "Repeated desktop battles can load a validated starting battlefield instead of generating it again."
kind = "improved"
+++

Desktop hosts now cache the starting battlefield after generating it, and can
load packages prepared ahead of time. Reuse requires the same seed, player
setup, map options and game code/content. New random seeds still generate new
maps. The automatic cache holds up to eight entries and 2 GiB.

Terrain, structures, navigation, starting forces and random-number state remain
together. Cached and generated starts use the same Rust simulation and replay
verification. Corrupt or outdated packages are ignored and regenerated.

This speeds map preparation, not every part of loading: the client still builds
its visual world and uploads graphics resources. Packages can be hundreds of MiB.
See `docs/PRECOMPUTED_MAPS.md` for baking, compatibility and reproducible checks.

On a generated 3 km map with 500 starting soldiers, preparation took 314.5 seconds
uncached and 3.7-4.9 seconds on two cache hits. Two independent generations and
both hits produced identical starting bytes and independently verified 600-tick
replays. These are generator timings, not total visual loading time or an FPS
claim. Other applications remained running. Full results and conditions are in
`docs/performance/precomputed-maps.json`.

With rendering enabled on a 1 km / 500-soldier battlefield, launch to client-ready
went from 77.6 seconds uncached to 33.0-35.8 seconds cached. These measurements
exclude the title/menu and loading-screen fade; new random maps still generate
normally, and the visual world still needs preparation.
