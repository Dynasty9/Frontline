+++
title = "Faster route checks on large battlefields"
summary = "The server spends less time checking whether a destination is reachable, while retaining the same routes and battle results."
kind = "improved"
+++

Before planning a route, the server checks whether its endpoints are connected.
That check now walks graph storage in order and joins connected groups, avoiding
a depth-first traversal through every weighted route node.

On the saved 3 km city, the 300,549-node check averaged 12.3 ms instead of 20.4 ms
in an alternating release-build microbenchmark. This is the connectivity check,
not a whole-game FPS improvement. Replaying 3,600 ticks from the same starting
state produced matching command/event and gameplay-state hashes.
