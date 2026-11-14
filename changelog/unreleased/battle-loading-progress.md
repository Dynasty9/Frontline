+++
title = "Follow the battlefield as it loads"
summary = "Desktop battles now show map-generation stages instead of waiting silently for the host. Joining also skips a redundant vehicle pathfinding grid."
kind = "improved"
+++

The loading bar follows generation, building your view, and final rendering in order. Ground preparation reports completed rows instead of advancing on a four-second timer and then stopping. Starting a battle while scripts are still compiling keeps the loading screen responsive. Progress represents completed stages, not an estimate of seconds remaining.

Clients still build the same ground heights and slopes; vehicle pathfinding preparation stays with the host that runs the battle.
