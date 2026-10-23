+++
title = "Clean shutdown during music startup"
summary = "Closing a game or demo during music synthesis waits for the worker to finish safely."
kind = "fixed"
+++

Fixes script errors when a quick exit freed the music synthesizer while it was still generating samples.
