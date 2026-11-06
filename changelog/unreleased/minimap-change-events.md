+++
title = "A minimap that responds to building changes"
summary = "Large maps no longer scan every structure just to discover that a building changed."
kind = "improved"
+++

The minimap now listens for buildings appearing, disappearing or changing hands.
It keeps its existing two-second refresh interval and paints changes across
several frames while the previous complete map remains visible.

In a check with 14,000 unchanged structures, detection took 0.009 ms instead
of 12.1 ms of accumulated scan work. The old scan was spread across frames;
painting costs are separate. This removes the periodic full-map detection scan. It also catches a destroyed
roof when another roof appears elsewhere during the same interval, a case the
old roof count could miss. Moving units, fog, selection and camera controls keep
their existing refresh schedule. No whole-frame FPS improvement is claimed.
