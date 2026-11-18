+++
title = "Keep recordings across service restarts"
summary = "Battle recordings can use private object storage when recording storage is configured."
kind = "improved"

[[videos]]
file = "restart.webm"
poster = "restart.jpg"
caption = "A synthetic battle is recorded locally, then the same recording plays after a local storage-fixture restart. The restart occurs off-screen; replay footage is labeled 4x. This shows playback, not concurrent-upload correctness or production availability."
+++

The clip uses an isolated test service and synthetic scenario data only. Playback
controls and the advancing timeline are real game output. Recording footage is
normal speed; replay footage is compressed to 4x with an explicit label.
Separate tests check payload persistence, ordering, retention and failure handling.
Production recording storage has not been activated by this change.
