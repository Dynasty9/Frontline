+++
title = "Joining a battle loads it before it starts"
summary = "Joining waits for the whole battlefield to arrive and load, avoiding a half-built map and long freezes."
kind = "fixed"


[[screenshots]]
file = "loading-screen.jpg"
caption = "Joining a running battle: the loading screen waits while the battlefield goes up"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

When you join someone else's battle, the loading screen now stays up until the whole battlefield has arrived and been built, and it arrives in a second or two, so you no longer drop into a half-built map that freezes for seconds at a time.

- **The loading screen waits for the battle**: it shows how far it has got (the water, the town, every building
  and tree, the cover) and only lifts once it's all there, instead of lifting on an empty field.
- **Faster to arrive**: the host sends the battlefield packed into about a twentieth of the space it used to take,
  so all of it arrives within a second or two instead of trickling in over half a minute or more.
- **No more long freezes after it lifts**: the buildings and trees are put up a few at a time behind the loading
  screen, rather than in a handful of frames that each held the game for seconds.
- **The ground matches the host's**: the paving in the town squares and the ground under bridges and the harbour
  quay were open ground on a joining player's map, though they're road in the battle itself; they're road now.
- Host and players must update together: a game with this change can't join a battle hosted by an older one.
