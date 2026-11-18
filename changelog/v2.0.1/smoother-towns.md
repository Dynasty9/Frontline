+++
title = "Smoother frame rate over towns, fewer stutters"
summary = "Looking over the town draws about a third as much as before, so the frame rate there roughly doubles, and panning or jumping the camera seldom stalls while scenery and grass are built."
kind = "improved"

[[screenshots]]
file = "comparison.jpg"
caption = "The same town views before and after: the picture is unchanged, drawn in well under half the draws"
+++

- **Towns draw far less.** Houses, garden walls and trees are merged block by block as soon as a block is built (in a town that used to wait for the whole neighbourhood, so it hardly ever happened), and each model casts its shadow from one shape instead of one per material. Over the town, the draws a frame fell from about 8,000 to about 2,000, and the time the processor spends preparing the picture from 17 ms to under 6.
- **Far fewer freezes on camera moves.** Scenery and grass coming into view are built nearest first, a few milliseconds' worth each frame, instead of all in one frame (up to most of a second over a street of houses). A parked car or wreck seen for the first time still costs a short hitch.
- **Vehicles appear faster.** Their distant-view meshes are made once for each kind and shared, so a tank's model builds in about a third of the time.
- **Solo battles' connection readout** (in the console's `why` and `net`) now says that the host is your own computer and its round trip follows your frame rate, instead of blaming the network.
