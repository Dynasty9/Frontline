+++
title = "Reduce sliding during rifle movement"
summary = "Planted feet follow their ground anchors more closely."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Earlier controller route with delayed horizontal foot correction."

[[screenshots]]
file = "after.jpg"
caption = "The same running route with bounded horizontal anchor correction."
+++

Replaces a second horizontal smoothing pass that delayed planted feet behind their ground targets with a bounded correction. Plant and release transitions still ease, abrupt corrections are limited, and vertical ground correction remains smoothed. This reduces measured ankle drift across forward, backward and sideways movement; some sliding and toe movement remain.
