# Minimap invalidation from world events

The baked map now listens to structure registry births/removals and ownership
changes. It no longer scans every structure at two-second intervals to compare
roof and footprint counts. Same-owner assignments are ignored by the entity
setter; registration still explicitly updates the owned-structure list.

Only roofs, floors, bridges and tall walls request a bake. Trees and debris keep
their existing policy of catching up with the next building change. Road-count
checks are unchanged and constant-time. New bakes start at most once per two
seconds, retain the last complete image, and keep the existing incremental paint
budget. Replacing one roof with another no longer fools the count-based check.

## Detection benchmark

Godot 4.7.2, Windows, 14,000 unchanged structures, 24 alternating checks against
the previous implementation, other applications running. The old coroutine's
active slices are summed; time spent yielding is excluded. Neither branch paints
a new image. There are no concurrent local builds or tests.

| Check | Mean CPU elapsed time | Maximum |
| --- | ---: | ---: |
| Previous scan | 12.136 ms | 13.790 ms |
| Event-driven, no changes | 0.009 ms | 0.028 ms |

This is a component measurement, not frame time or FPS. The previous scan was
spread across frames, and the separate painting cost is unchanged. Raw samples
and the instrumented old detection loop are in `build/minimap-detection*` and
`build/minimap-before.gd` in the minimap-change-events worktree.

## Validation

The lifecycle fixture uses the same registry/despawn/ownership paths as the
socket client and retained reference host. It checks unchanged scenery, births,
equal-count replacement, cooldown coalescing, neutral/owned transitions, ignored
tree changes, road additions and the resulting roof/ruin/road pixels. Existing
12,000-structure bake, cancellation, progressive-layer, fighting marker and dot
fixtures also pass. Godot import and the headless attack scenario pass; the latter
still reports resource/ObjectDB cleanup warnings at exit. No network or replay
format changes are involved. This change does not establish steady 60 FPS.
