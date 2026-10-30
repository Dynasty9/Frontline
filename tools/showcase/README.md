# UI presentation inventory

`catalog.json` records the evidence for the current unreleased commander HUD change. It does not regenerate historical releases.
Paths are relative to the repository root. `source_ref` identifies either an archived capture or the commit containing the inventory revision (find it with `git log -- tools/showcase/catalog.json`).

Render a capture with Godot 4.7.2 from the repository root: `godot --path . --` followed by its `arguments` and `--screenshot=out.png`. For Compatibility add `--rendering-method gl_compatibility` before `--`. Captures use the game's existing scenario/UI flags; convert the output to JPEG for the changelog. The live simulation can vary slightly in a frame, so comparisons prove layout rather than simulation determinism.

The archived original HUD `before.jpg` remains in the changelog. `previous-deck.jpg` is the matched comparison for the later visual simplification. No historical image was reconstructed. Inspect assets and verify the listed files exist, then run `python3 .github/scripts/changelog.py check`. This checkout has no separate presentation audit runner.
