+++
title = "Safer routes across hills and water"
summary = "Tracks and wheels choose suitable slopes, and infantry wade through shallows instead of walking underwater."
kind = "improved"
+++

- Infantry, wheeled vehicles and tracked vehicles use separate terrain limits. Vehicles account for nearby steep ground across their footprint, and supply trucks no longer bypass blocked terrain.
- Routes favour easier ground and roads. Connected areas are calculated when the map loads, and newly opened passages become available without treating separated shores as reachable.
- Soldiers can wade through water up to 55 cm deep. Deeper water is blocked even if an old terrain label calls it shallow; bridge decks remain usable.
- Movement checks the whole step, including dives, separation and vehicle recovery. Old routes cannot carry units through newly blocked ground or deep water.
- Living soldiers stay upright while wading. Spawning and disembarking use safe ground; soldiers stranded by a removed crossing recover to a safe bank.
- Ambush Alley autoplay uses its available mortars against spotted convoy vehicles stopped on the road, so it can finish the ambush under the updated movement rules.
