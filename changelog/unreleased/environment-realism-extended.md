+++
title = "Natural coasts, fuller forests and alpine surfaces"
summary = "Irregular bays, fuller forests, textured snow and woodland ground cover give the battlefield more natural variation."
kind = "improved"

[[screenshots]]
file = "coast-before.jpg"
caption = "Before: the ocean ends in a square beside the scenery."

[[screenshots]]
file = "coast-after.jpg"
caption = "After: distant water follows bays around the mountains. Same seed and camera."

[[screenshots]]
file = "forest-before.jpg"
caption = "Before: sparse hillside trees and bare ground, matching close camera."

[[screenshots]]
file = "forest-after.jpg"
caption = "After: fuller canopies, connected stands and woodland ground cover, matching close camera."

[[screenshots]]
file = "compat-before.jpg"
caption = "Compatibility before: linear ground colours were displayed too dark."

[[screenshots]]
file = "compat-after.jpg"
caption = "Compatibility after: corrected material output brings ground and foliage into the same palette."
[[screenshots]]
file = "snow-before.jpg"
caption = "Before: smooth white snow on the coastal ridge."

[[screenshots]]
file = "snow-after.jpg"
caption = "After: photographed powder, granular relief and dirtier melt edges. Same ridge, seed and camera."
[[screenshots]]
file = "lighting-before.jpg"
caption = "Before: distant forest stays sunlit below a mountain ridge."

[[screenshots]]
file = "lighting-after.jpg"
caption = "After: the ridge shades its valley and forest. Same golden-hour lighting, seed and camera."
[[screenshots]]
file = "ranges-before.jpg"
caption = "Before: repeated procedural peaks surround the valley."

[[screenshots]]
file = "ranges-after.jpg"
caption = "After: surveyed Alpine ridges form separate mountain groups and lower passes. Same seed, camera and lighting."
[[screenshots]]
file = "street-before.jpg"
caption = "Before: oversized aggregate makes the asphalt look like coarse gravel."

[[screenshots]]
file = "street-after.jpg"
caption = "After: finer photographed aggregate keeps larger cracks and repairs. Same street, seed, lighting and camera."
[[screenshots]]
file = "roof-before.jpg"
caption = "Before: the photograph overrides the roof colour and leaves concrete yellow."

[[screenshots]]
file = "roof-after.jpg"
caption = "After: calibrated terracotta, concrete and wood retain photographed surface detail. Same house and camera."

[[screenshots]]
file = "town-colour-before.jpg"
caption = "Before: beige and cyan roofs dominate the town overview."

[[screenshots]]
file = "town-colour-after.jpg"
caption = "After: terracotta and weathered grey roofs remain distinct at command-camera distance. Same town and lighting."
[[screenshots]]
file = "driveway-before.jpg"
caption = "Before: the parking pad stops at grass and a full-height curb."

[[screenshots]]
file = "driveway-after.jpg"
caption = "After: a continuous entrance crosses the sidewalk through a lowered curb. Same seed and camera."

[[screenshots]]
file = "canopy-before.jpg"
caption = "Before: upright tree silhouettes remain flat when seen from above."

[[screenshots]]
file = "canopy-after.jpg"
caption = "After: elevation-aware crowns and hillside shadows give the forest volume. Same seed, lighting and steep camera."


[[screenshots]]
file = "precision-before.jpg"
caption = "Before: rounded height samples leave fine stripes across snow edges."

[[screenshots]]
file = "precision-after.jpg"
caption = "After: full-precision slopes keep snow edges smooth. Same terrain, seed and camera."

[[screenshots]]
file = "meadow-before.jpg"
caption = "Close meadow before: broad ribbon blades and plain ground. Same seed and camera."

[[screenshots]]
file = "meadow-after.jpg"
caption = "Close meadow after: fine pointed blades over photographed turf, with variation from soil moisture. Same seed and camera."

[[screenshots]]
file = "meadow-wide-before.jpg"
caption = "Low meadow view before: broad ribbon blades and plain ground. Same seed and camera."

[[screenshots]]
file = "meadow-wide-after.jpg"
caption = "Low meadow view after: fine pointed blades over photographed turf, with variation from soil moisture. Same seed and camera."

[[screenshots]]
file = "shrub-before.jpg"
caption = "Before: oversized branch cards and evenly scattered bushes across the meadow."

[[screenshots]]
file = "shrub-after.jpg"
caption = "After: smaller photographed branches form patches with open gaps. Same meadow, seed, lighting and camera."

+++

The ocean keeps detailed waves near the battlefield and uses a coarser surface beyond it.

Hillside woods use varied photographed tree silhouettes and a shared placement/ground-cover mask. Five baked elevations blend as the camera tilts, showing crowns from above and full silhouettes near the horizon. High/Ultra shadows also ground these trees against the hillside. Offline edge correction removes the dark fringe from their canopies.

Snow uses photographed powder at its original two-metre scale, with darker melt edges. Forest floors blend moss and leaf litter beneath the same hillside stands. Detailed surfaces follow the terrain-detail setting; texture arrays keep these layers within the browser renderer's sampler budget.

Distant ridges now shade their valleys and forests with cached terrain lighting. Changing the time of day refreshes that lighting without rebuilding the forest. Standing rainwater stays on gentle ground instead of making cliff faces reflect like puddles.

Surrounding ranges now use real Alpine elevation shapes, composed into varied fictional mountain groups. Lower ridges close the horizon between the peaks. The source data is bundled and processed during map creation; no terrain downloads or extra per-frame material samples are needed.

Town asphalt now separates fine aggregate from broad cracks, repairs and stains. Streets and junctions share the same world-space material, blended in linear light in both renderers. Normal maps follow sloping roads and paving instead of lighting every surface as if it were flat.

Photographic building materials now respect their intended colours. Calibrated roof tiles, concrete, wood and bark retain the scan detail without turning grey roofs cyan or all tiled roofs pale beige.

Driveways now connect to the street through lowered sidewalk crossings with sloping shoulders. Curbs meet the asphalt, and grass stays out of the paved entrance.

Meadow grass and shrubs remain visible on elevated ground, and small decorative stones rest on the actual hillside. Trees and buildings also stay resident when a low camera looks up a high slope. Grass thins below the snow line and stops on bare steep faces instead of leaving stray clumps in unsuitable terrain.

Elevated surfaces retain full height precision, removing the fine stepping that showed through snow and slope shading. Ground-level staining on walls follows the hillside instead of sea level.

Meadows use fine pointed blades over photographed turf, with wetter sheltered soil and drier exposed patches. The clumps retain their previous triangle count. Local height bounds keep distance fading centred on each patch of vegetation, even when much taller mountains surround it.

Low shrubs use smaller photographed branches and grow in seeded patches with open gaps. Their root shading follows each plant rather than its elevation. Distant forest atlases also load correctly in exported builds.

Local games share the scenery batching used by network clients. Returning to already-built scenery reveals it promptly while off-screen buildings retain their combat collision. Batched roofs and other tinted surfaces keep their colours in both renderers, including grey roofs in the browser.

World-space wood, plaster and weathering stay in place when scenery enters a batch. Shrub leaves receive light from both sides without reversing their back-face normals.
