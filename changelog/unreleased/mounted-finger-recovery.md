+++
title = "Recover mounted hand poses after reloading"
summary = "Prototype skinned gunners no longer retain finger rotations from an interrupted rifle reload."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: mounting after reloading retains the reload finger pose."

[[screenshots]]
file = "after.jpg"
caption = "After: the saved rifle grip pose is restored before mounted arm contact."
+++

The shared procedural fallback restores saved grip finger rotations for mounted crews, including when their personal rifle is hidden. The M2 fixture now begins from a sampled reload and checks finger recovery alongside moving palm contact and platform clearance. This removes history-dependent poses; it does not add anatomically fitted finger wrapping or mounted reload animation.
