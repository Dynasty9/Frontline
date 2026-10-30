+++
title = "No more crash when an attack outlasts a squad it lost"
summary = "An attack continues safely when one of its squads is wiped out, instead of crashing later."
kind = "fixed"
+++

A battle could crash when a squad was wiped out partway through a planned attack and the attack dragged on for minutes after. The lost squad now drops out of the attack the moment it's gone.

- The rest of the attack carries on exactly as before. When it ends, only the squads still in the field get their new orders.
