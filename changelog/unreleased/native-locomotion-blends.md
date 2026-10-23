+++
title = "Reduce blended rifle animation work"
summary = "Mixed rifle movement uses Godot's native animation blending."
kind = "improved"
+++

The opt-in skinned rifleman evaluates mixed movement clips through a shared native blend graph, with independent animation timing for each soldier. Single-clip movement keeps its direct sampling path. Foot placement, weapon grips and action overlays still use the shared controller.

This reduces animation processing in local measurements. Diagonal foot sliding remains unfinished.
