+++
title = "Play in your browser"
summary = "Play solo Frontline in your browser without installing the game; multiplayer remains on desktop."
kind = "new"


[[screenshots]]
file = "browser-battle.jpg"
caption = "An AI battle in a browser tab"

[[screenshots]]
file = "browser-menu.jpg"
caption = "The menu in the browser: multiplayer points you to the desktop game"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Frontline now comes as a browser build too: the same game, played alone, with nothing to download or install. Multiplayer still needs the desktop game.

- **What you can play:** Play vs AI, Missions and Watch AI Battle, plus the Field Manual, Settings, and signing in to
  keep your service record.
- **Multiplayer and co-op** need the Windows, Mac or Linux game: a browser can't make the direct connections a battle
  between players runs over. The menu links to the downloads instead.
- **It looks a little different:** there's no screen-space lighting, volumetric fog or dust trailing behind flung
  earth, which the browser's renderer can't draw. Settings it can't use are hidden.
- The battlefield takes about 30 seconds to lay out, a stage at a time, with the loading screen showing how far it's
  got. After that the battle runs about as fast as it does on the desktop.
- **The first battle takes a while:** the first time, the browser also prepares the game's graphics, so the page
  holds for about a minute before the battle appears (if the browser asks, choose Wait). It keeps them, so after that
  a battle only waits for its map.
- **Lighter on effects:** particles run on the processor, and explosions, muzzle flashes and fires don't light up
  their surroundings, so nothing stalls the battle the first time it happens.
- Each release comes with the browser build alongside the Windows, Mac and Linux downloads.
