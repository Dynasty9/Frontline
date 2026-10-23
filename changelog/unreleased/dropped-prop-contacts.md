+++
title = "Dropped rifles regain contact with their owner"
summary = "Released rifles and magazines stop ignoring body parts after clearing the initial grip."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: permanent owner exclusions let the rifle intersect the fallen soldier."

[[screenshots]]
file = "after.jpg"
caption = "After: the released rifle clears the grip and collides with the body."
+++

Each dropped prop retains collision protection only for parts it still overlaps. Once clear, normal collision resumes with that part. Both the viewer and gameplay collision masks include ragdoll bodies, and dense overlap queries conservatively keep protection until clearance can be established.
