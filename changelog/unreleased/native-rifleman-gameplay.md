+++
title = "Smoother movement for prototype riflemen"
summary = "The optional SWAT riflemen use the shared directional animation controller in battles."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Earlier SWAT battle prototype, before native directional locomotion integration."

[[screenshots]]
file = "after.jpg"
caption = "Live battle with the shared native locomotion driver installed on four riflemen."
+++

Opt-in SWAT riflemen now blend forward, backward, strafe, walking, running and idle motion using the same driver as the playable motion lab. Animation libraries are shared between soldiers. Unsupported actions retain their procedural fallback; this is still a local-asset prototype.
