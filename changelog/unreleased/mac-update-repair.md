+++
title = "Mac updates only when a new version is available"
summary = "Frontline on Mac no longer downloads the same release again on every launch. New releases still install automatically."
kind = "fixed"
+++

Mac builds use the built-in simulation and do not need the extra simulation library shipped on Windows and Linux. The updater now recognises that, while keeping automatic repair for Windows and Linux installations missing that library.

On Mac, move Frontline out of the disk image into a writable Applications folder so it can replace the app when an update arrives.
