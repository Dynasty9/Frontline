# Changelog

Every release of Frontline, newest first. The game updates itself; downloads, and this changelog with pictures,
are on [the website](https://web-production-5a4c1.up.railway.app/changelog/). Each change is written up in [`changelog/`](changelog/) as part of
the pull request that makes it.

## v1.0.12: Mountain battlefields

*10 November 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.12)

### New

#### Mountain battlefields

Seeded snowy mountains, mossy hills and river valleys now surround the towns and roads of standard battles.

![Before: the flat battlefield with the same seed and camera.](changelog/v1.0.12/mountain-battlefields/before.jpg)

<details>
<summary>Explore this change</summary>

- Mountains, hills and valleys generate from the battle seed. Towns, starting bases, roads and river crossings retain usable valley corridors, with forests on lower ground.
- Layered photographic rock, cool shaded gullies and connected snowfields give the mountains an Alpine appearance. Sky visibility and distant ridge shadows are baked into the terrain, updating when the lighting mood changes.
- Fractured bedrock, tilted shelves and weathered ledges break up the mountain faces. Larger photographic slabs catch the light above smaller scree, while snow settles on gentler shelves and leaves steep cliffs exposed. Finer distant silhouettes keep the horizon from looking angular.
- Standard-battle woods grow in denser clusters. Tree bark and foliage share spatial drawing batches while individual trees still burn and fall.
- Alpine rivers have blue-green water. Optional Alpine distance haze separates the mountain ranges, and optional Mountain reflections capture distant terrain in the water without rendering the whole battle twice.
- Troops and vehicles follow the terrain and avoid slopes they cannot climb. Ridges obstruct shots and observation; helicopters clear rising ground and land at the correct elevation.
- Construction checks the whole footprint. Trenches, craters, fires, targeting and the minimap follow the landscape.
- Multiplayer joiners receive the same terrain as the host, and battle recordings preserve it when seeking forward or backward.

Campaign missions retain their existing terrain layout and woodland density so their authored routes and cover remain intact.

![After: fractured mountain belts and denser woods around the town and river valley.](changelog/v1.0.12/mountain-battlefields/after.jpg)

![Looking inland through the coastal valley with Mountain reflections enabled.](changelog/v1.0.12/mountain-battlefields/valley.jpg)

</details>

### Improved

#### Woodland follows the mountain slopes

Greener gullies, contour-following woods and vegetation on mountain ledges replace randomly scattered greenery.

![Before: noise-driven green patches and compact, scattered woods.](changelog/v1.0.12/alpine-habitats/before.jpg)

<details>
<summary>Explore this change</summary>

- Soil cover responds to shelter, slope and aspect, with less arbitrary colour variation across the valleys.
- Open valley ground has fewer isolated random trees; planting favours groves and sheltered mountain pockets.
- Woods spread along contours, and conifers can root on suitable mountain ledges. Exposed ribs and high peaks remain largely bare.
- Scrub favours sheltered bowls, while stones occupy drier and steeper ground. Tree limits do not relax building foundation checks.

![After: greener sheltered ground and woodland following the terrain, with the same seed and camera.](changelog/v1.0.12/alpine-habitats/after.jpg)

![Closer daylight view of conifers on suitable ledges and woodland following the lower slopes.](changelog/v1.0.12/alpine-habitats/detail.jpg)

</details>

#### Break up mountain silhouettes

Uneven mountain groups, lower passes and reshaped cliff shoulders replace repetitive ridges, with more varied moss-to-rock transitions.

![Before: distant mountain groups and passes.](changelog/v1.0.12/alpine-massifs/wide-before.jpg)

<details>
<summary>Explore this change</summary>

Distant scenery uses its own seeded height field instead of an equal-height ridge pattern. Floating-point heights and wider slope sampling avoid stepped snow shading. Medium/Far detail uses a finer indexed scenery mesh; Near retains the lighter grid.

Reusable rock forms now have uneven shoulders and irregular drainage cuts before the existing terrain erosion and road grading. These enter the authoritative terrain used by movement, construction and replay. Material coverage also varies with photographic rock relief.

The comparisons use the same seed, lighting and camera controls. The camera follows local ground height, so changed geology can shift its absolute height. Procedural trees and some smooth rock forms still limit realism; these are native game captures, not photographic composites.

Approach informed by [Wargaming's environment workflow](https://wargaming.com/en/news/making_battle_arenas_in_wows/): establish large landforms before surface detail.

![After: distant mountain groups and passes.](changelog/v1.0.12/alpine-massifs/wide-after.jpg)

![Before: cliff shoulders and the valley floor.](changelog/v1.0.12/alpine-massifs/close-before.jpg)

![After: cliff shoulders and the valley floor.](changelog/v1.0.12/alpine-massifs/close-after.jpg)

![Before: close cliff profile.](changelog/v1.0.12/alpine-massifs/detail-before.jpg)

![After: reshaped shoulder and snow shelf; camera follows local terrain.](changelog/v1.0.12/alpine-massifs/detail-after.jpg)

</details>

#### Separate distant mountain ranges with sky haze

Optional alpine haze takes on the sky colour and settles lightly into lower valleys.

![Before: shared terrain baseline, identical seed and camera.](changelog/v1.0.12/alpine-perspective/before.jpg)

<details>
<summary>Explore this change</summary>

Uses existing alpine_haze option and engine fog; no new volumetric pass. Disabled/flat-map paths reset both additions. Compatibility may approximate aerial perspective differently.

Technique reference: [research source](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).

![After: Optional alpine haze takes on the sky colour and settles lightly into lower valleys.](changelog/v1.0.12/alpine-perspective/after.jpg)

![Before: matching closer camera, shared baseline.](changelog/v1.0.12/alpine-perspective/close-before.jpg)

![After: the same closer camera; surface changes remain subtle.](changelog/v1.0.12/alpine-perspective/close-after.jpg)

![Before: focused comparison under matched lighting.](changelog/v1.0.12/alpine-perspective/target-before.jpg)

![After: Watch the tone and separation of the distant ridges in hazy weather.](changelog/v1.0.12/alpine-perspective/target-after.jpg)

</details>

#### Broken stone across mountain faces

Mountain faces gain broken mineral layers, darker weathered seams and uneven pockets of loose stone.

![Before: the previous rock material, with the same seed, golden-hour lighting and camera.](changelog/v1.0.12/alpine-rock-relief/before.jpg)

<details>
<summary>Explore this change</summary>

Cliff materials combine larger elongated fractures with smaller photographic grain.
The detail is baked into the existing material textures, including normals and
occlusion, so it uses no additional terrain texture samples. Tilted mineral beds
break across the faces rather than forming continuous stripes.
Sheltered seams weather darker, while loose stone collects unevenly on gentler
ground and in pockets. These masks reuse existing texture reads.

This improves surface shading; mountain silhouettes and movement limits are unchanged.

![After: interrupted mineral layers and darker weathering break up broad rock faces.](changelog/v1.0.12/alpine-rock-relief/after.jpg)

![Closer daylight view of varied rock surfaces and sheltered stone pockets.](changelog/v1.0.12/alpine-rock-relief/detail.jpg)

</details>

#### Rock faces with depth and greener foothills

Mountain faces gain distinct rock masses, relief-aware moss and snow, and small conifer stands at their feet.

![Previous terrain, seed 3, golden-hour command camera.](changelog/v1.0.12/alpine-surface-detail/before.jpg)

<details>
<summary>Explore this change</summary>

- Rock breaks through moss and snow according to the photographed surface relief. Crevices retain shade and each surface has its own roughness.
- Generated buttresses, bowls and saddles become part of the terrain before weathering and road grading, keeping movement and shots aligned with the landscape.
- Small conifer stands give the foothills a clearer sense of scale while retaining normal tree collision, fire and destruction.
- Offline-packed material maps retain the same texture-sample count; mip filtering reduces distant grain.

![The same seed and camera with shaped rock masses, relief-aware surfaces and foothill conifers.](changelog/v1.0.12/alpine-surface-detail/after.jpg)

</details>

#### More varied mountain surfaces and vegetation

Mineral bands, dry grass, scrub and scattered stones break up the alpine landscape, with vegetation changing as the ground rises.

![Before: the preceding material pass, seed 3 and golden-hour command camera.](changelog/v1.0.12/alpine-variation/before.jpg)

<details>
<summary>Explore this change</summary>

- Rock faces mix broad mineral colours, weathering bands and broken scree. Moss and dry grass vary in smaller patches instead of covering entire slopes evenly.
- Mixed lower woods transition toward conifers and an uneven tree line. Low scrub gives way to scattered stones higher up; snowy summits remain bare.
- Small scrub and stones are passable scenery, grounded individually and batched for rendering. Their seeded placement is shared by multiplayer and recordings.

![After: varied mineral and ground patches with elevation-dependent vegetation.](changelog/v1.0.12/alpine-variation/after.jpg)

![A closer daylight view: low scrub and small stone clusters sit on the terrain beneath mixed woods and conifers.](changelog/v1.0.12/alpine-variation/detail.jpg)

</details>

#### Release notes you can scan, then explore

See what changed at a glance, with a focused visual and expandable detail. The full release history now uses the same clearer presentation.

![After: a short outcome and one lead visual, with original notes and captures under Explore this change.](changelog/v1.0.12/clearer-release-history/overview.jpg)

<details>
<summary>Explore this change</summary>

All 87 published entries now begin with a concise player-facing summary. Archived
images appear directly in the site’s brass-and-ink layout; existing motion clips keep their
playback controls and attribution. Expand **Explore this change** for the original
notes, screenshots and supporting clips. Original release dates and feature claims
are preserved.

Motion is shown with video when recorded evidence exists. Interface changes use
stills; invisible fixes and unrecorded sound or performance changes use text.
Historical screenshots remain historical evidence, and current-build demonstrations
are labelled as such.

The same overview/detail structure is used in the generated repository changelog
and future release notes. Reusable capture stages, media-selection guidance and
an evidence audit make this part of preparing each new change.

The page shares the main site’s condensed headings, thin rules and shadcn/Radix
components. Desktop entries place an explanation beside uncropped media; narrow
screens stack the same content. Supporting notes expand beneath each entry.

Every existing entry includes **Compare changelog layouts**: a separate, collapsed
old/new presentation review. Both views use the same viewport and can be enlarged.
These compare the release-note layout itself, independently of the feature media.

![Before: the same release opens with all supporting screenshots and full notes.](changelog/v1.0.12/clearer-release-history/before.jpg)

![The overview and detail control remain readable on a narrow phone screen. Images open at full size.](changelog/v1.0.12/clearer-release-history/phone.jpg)

![Expand the original notes and supporting gallery without leaving the release.](changelog/v1.0.12/clearer-release-history/details.jpg)

![On phones, the same explanation and uncropped image stack into one readable column.](changelog/v1.0.12/clearer-release-history/phone-entry.jpg)

![Compare changelog layouts opens an entry-specific old/new presentation review, with both captures available at full size.](changelog/v1.0.12/clearer-release-history/layout-review-ui.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it. This entry is new; its content is rendered through both layouts for comparison.

![Before: old changelog layout](changelog/v1.0.12/clearer-release-history/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.12/clearer-release-history/layout-after.jpg)

</details>

#### Add directional weathering to cliffs

Narrow mineral stains run down exposed cliffs, interrupted by ledges and changes in rock type.

![Before: shared terrain baseline, identical seed and camera.](changelog/v1.0.12/cliff-runoff/before.jpg)

<details>
<summary>Explore this change</summary>

One extra scalar noise read per terrain fragment. This is directional material weathering rather than a hydrology simulation; geometry and traversal do not change.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

![After: Narrow mineral stains run down exposed cliffs, interrupted by ledges and changes in rock type.](changelog/v1.0.12/cliff-runoff/after.jpg)

![Before: matching closer camera, shared baseline.](changelog/v1.0.12/cliff-runoff/close-before.jpg)

![After: the same closer camera; surface changes remain subtle.](changelog/v1.0.12/cliff-runoff/close-after.jpg)

![Before: focused comparison under matched lighting.](changelog/v1.0.12/cliff-runoff/target-before.jpg)

![After: Watch for narrow dark vertical stains across the lit central face.](changelog/v1.0.12/cliff-runoff/target-after.jpg)

</details>

#### Smoother large battles

Large formation orders take less work, and pointer feedback updates independently of squad counters.

![Cover previews stay aligned at enlarged interface scale while updating independently of squad counters.](changelog/v1.0.12/combat-overlay-refresh/after.jpg)

<details>
<summary>Explore this change</summary>

- Selection boxes, tooltips and order previews update immediately in their own drawing layer, without rebuilding every squad counter as the pointer moves.
- Camera shake keeps the existing status refresh rate. Panning, zooming, selection and commands still refresh the counters immediately.
- Combat and camera shake are unchanged.

- Large formation orders spend less time choosing ground while keeping the same cover choices, spacing and placement order.
- Soldiers spend less time checking ground and trench heights in built-up areas. Distant squads draw more efficiently with the same poses.
- Moving soldiers check visibility more efficiently, preserving the effects of smoke, doors and cover.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.12/combat-overlay-refresh/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.12/combat-overlay-refresh/layout-after.jpg)

</details>

#### Natural coasts, fuller forests and alpine surfaces

Surveyed Alpine ranges, fuller forests and photographed town surfaces give the generated battlefield more natural detail.

[Watch: Native tour of Alpine ranges, coastal forest cover, town surfaces and finer meadow detail. Current PR with animated camera, wind and water; matched before/after stills remain below.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/environment-realism-extended/native-tour.webm))

<details>
<summary>Explore this change</summary>

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

Broadleaf crowns have smaller branches and more open gaps at the same triangle count. Photographed foliage uses its own surface detail, with consistent colour and two-sided lighting instead of an extra layer of procedural leaf noise.

Country tracks have varied rut widths, intermittent centre grass and broader worn patches. Their joins to town asphalt use a short broken edge instead of a wide blurred band.

Mountain weathering follows baked downhill catchments. Snow persists in sheltered drainage channels while exposed ribs remain visible; changing the sunlight reuses the same drainage mask.

Rivers continue beyond the battlefield into irregular scenery pools, with matching banks and riverbeds. These distant extensions do not change playable water or navigation.

Browser lighting follows the displaced mountain slopes and softly lights photographed tree canopies while keeping the cheaper vertex-lighting renderer. Rain surrounds the camera with finer streaks; soft splashes follow ground and water height and disappear at distance.

Procedural clouds have smooth edges in both renderers, with subdued moonlit shading at night. Reflected clouds on the sea follow that night lighting instead of retaining their daytime brightness.

![After the extended environment pass: panorama. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-panorama-after.jpg)

![Before the extended environment pass: panorama. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-panorama-before.jpg)

![Before the extended environment pass: town. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-town-before.jpg)

![After the extended environment pass: town. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-town-after.jpg)

![Before the extended environment pass: meadow. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-meadow-before.jpg)

![After the extended environment pass: meadow. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-meadow-after.jpg)

![Before the extended environment pass: forest. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-forest-before.jpg)

![After the extended environment pass: forest. Matched parent-branch and current cameras, seed and lighting.](changelog/v1.0.12/environment-realism-extended/comparison-forest-after.jpg)

![Before: the ocean ends in a square beside the scenery.](changelog/v1.0.12/environment-realism-extended/coast-before.jpg)

![After: distant water follows bays around the mountains. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/coast-after.jpg)

![Before: sparse hillside trees and bare ground, matching close camera.](changelog/v1.0.12/environment-realism-extended/forest-before.jpg)

![After: fuller canopies, connected stands and woodland ground cover, matching close camera.](changelog/v1.0.12/environment-realism-extended/forest-after.jpg)

![Compatibility before: linear ground colours were displayed too dark.](changelog/v1.0.12/environment-realism-extended/compat-before.jpg)

![Compatibility after: corrected material output brings ground and foliage into the same palette.](changelog/v1.0.12/environment-realism-extended/compat-after.jpg)

![Before: smooth white snow on the coastal ridge.](changelog/v1.0.12/environment-realism-extended/snow-before.jpg)

![After: photographed powder, granular relief and dirtier melt edges. Same ridge, seed and camera.](changelog/v1.0.12/environment-realism-extended/snow-after.jpg)

![Before: distant forest stays sunlit below a mountain ridge.](changelog/v1.0.12/environment-realism-extended/lighting-before.jpg)

![After: the ridge shades its valley and forest. Same golden-hour lighting, seed and camera.](changelog/v1.0.12/environment-realism-extended/lighting-after.jpg)

![Before: repeated procedural peaks surround the valley.](changelog/v1.0.12/environment-realism-extended/ranges-before.jpg)

![After: surveyed Alpine ridges form separate mountain groups and lower passes. Same seed, camera and lighting.](changelog/v1.0.12/environment-realism-extended/ranges-after.jpg)

![Before: oversized aggregate makes the asphalt look like coarse gravel.](changelog/v1.0.12/environment-realism-extended/street-before.jpg)

![After: finer photographed aggregate keeps larger cracks and repairs. Same street, seed, lighting and camera.](changelog/v1.0.12/environment-realism-extended/street-after.jpg)

![Before: the photograph overrides the roof colour and leaves concrete yellow.](changelog/v1.0.12/environment-realism-extended/roof-before.jpg)

![After: calibrated terracotta, concrete and wood retain photographed surface detail. Same house and camera.](changelog/v1.0.12/environment-realism-extended/roof-after.jpg)

![Before: beige and cyan roofs dominate the town overview.](changelog/v1.0.12/environment-realism-extended/town-colour-before.jpg)

![After: terracotta and weathered grey roofs remain distinct at command-camera distance. Same town and lighting.](changelog/v1.0.12/environment-realism-extended/town-colour-after.jpg)

![Before: the parking pad stops at grass and a full-height curb.](changelog/v1.0.12/environment-realism-extended/driveway-before.jpg)

![After: a continuous entrance crosses the sidewalk through a lowered curb. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/driveway-after.jpg)

![Before: upright tree silhouettes remain flat when seen from above.](changelog/v1.0.12/environment-realism-extended/canopy-before.jpg)

![After: elevation-aware crowns and hillside shadows give the forest volume. Same seed, lighting and steep camera.](changelog/v1.0.12/environment-realism-extended/canopy-after.jpg)

![Before: rounded height samples leave fine stripes across snow edges.](changelog/v1.0.12/environment-realism-extended/precision-before.jpg)

![After: full-precision slopes keep snow edges smooth. Same terrain, seed and camera.](changelog/v1.0.12/environment-realism-extended/precision-after.jpg)

![Close meadow before: broad ribbon blades and plain ground. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/meadow-before.jpg)

![Close meadow after: fine pointed blades over photographed turf, with variation from soil moisture. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/meadow-after.jpg)

![Low meadow view before: broad ribbon blades and plain ground. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/meadow-wide-before.jpg)

![Low meadow view after: fine pointed blades over photographed turf, with variation from soil moisture. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/meadow-wide-after.jpg)

![Before: oversized branch cards and evenly scattered bushes across the meadow.](changelog/v1.0.12/environment-realism-extended/shrub-before.jpg)

![After: smaller photographed branches form patches with open gaps. Same meadow, seed, lighting and camera.](changelog/v1.0.12/environment-realism-extended/shrub-after.jpg)

![Before: oversized leaf groups close the broadleaf crown.](changelog/v1.0.12/environment-realism-extended/leaves-before.jpg)

![After: smaller branches leave natural gaps, with consistent photographed colour and two-sided lighting. Same tree and camera.](changelog/v1.0.12/environment-realism-extended/leaves-after.jpg)

![Before: broadleaf stands form dense, rounded masses.](changelog/v1.0.12/environment-realism-extended/leaves-wide-before.jpg)

![After: finer open crowns remain readable at stand distance, at the same triangle count. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/leaves-wide-after.jpg)

![Before: the dirt lane fades through a broad blurred band at the town street.](changelog/v1.0.12/environment-realism-extended/lane-join-before.jpg)

![After: a shorter broken asphalt edge separates the surfaces, with patchier wear along the dirt lane. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/lane-join-after.jpg)

![Before: noise-based weathering and elevation-led snow.](changelog/v1.0.12/environment-realism-extended/drainage-before.jpg)

![After: downhill catchments place weathering and retained snow along connected gullies. Same terrain and camera.](changelog/v1.0.12/environment-realism-extended/drainage-after.jpg)

![Before: noise-based weathering and elevation-led snow.](changelog/v1.0.12/environment-realism-extended/snow-channels-before.jpg)

![After: downhill catchments place weathering and retained snow along connected gullies. Same terrain and camera.](changelog/v1.0.12/environment-realism-extended/snow-channels-after.jpg)

![Before: the river ends at a straight battlefield boundary.](changelog/v1.0.12/environment-realism-extended/river-end-before.jpg)

![After: the channel continues into an irregular scenery pool. Same seed, camera and lighting.](changelog/v1.0.12/environment-realism-extended/river-end-after.jpg)

![Before: the river ends at a straight battlefield boundary.](changelog/v1.0.12/environment-realism-extended/river-valley-before.jpg)

![After: the channel continues into an irregular scenery pool. Same seed, camera and lighting.](changelog/v1.0.12/environment-realism-extended/river-valley-after.jpg)

![Before: flat vertex lighting on displaced ridges and dark leaf cards in the browser.](changelog/v1.0.12/environment-realism-extended/browser-forest-before.jpg)

![After: browser lighting follows mountain slopes and softly lights tree canopies.](changelog/v1.0.12/environment-realism-extended/browser-forest-after.jpg)

![Before: the browser lights displaced mountain vertices as flat ground.](changelog/v1.0.12/environment-realism-extended/browser-panorama-before.jpg)

![After: mountain vertex normals follow the displaced terrain. Same browser settings.](changelog/v1.0.12/environment-realism-extended/browser-panorama-after.jpg)

![Before: bright rain streaks and white square splashes.](changelog/v1.0.12/environment-realism-extended/rain-close-before.jpg)

![After: finer streaks and soft splashes that follow the terrain height.](changelog/v1.0.12/environment-realism-extended/rain-close-after.jpg)

![Before: the rain emitter forms a bright patch at the camera target.](changelog/v1.0.12/environment-realism-extended/rain-valley-before.jpg)

![After: rain surrounds the camera and distant splashes fade away.](changelog/v1.0.12/environment-realism-extended/rain-valley-after.jpg)

![Before: block-shaped cloud edges and bright nighttime cloud cover.](changelog/v1.0.12/environment-realism-extended/night-clouds-before.jpg)

![Before: pale cloud reflections cover the sea beneath a dark night sky.](changelog/v1.0.12/environment-realism-extended/night-water-before.jpg)

![After: reflected clouds follow the moonlit sky while direct moon highlights remain. Same seed, camera and mood.](changelog/v1.0.12/environment-realism-extended/night-water-after.jpg)

![After: continuous cloud edges and subdued moonlit cover. Same seed and camera.](changelog/v1.0.12/environment-realism-extended/night-clouds-after.jpg)

[Watch: Before: broad bright streaks and square splashes. Six seconds at fixed 30 fps; silent.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/environment-realism-extended/rain-before.webm))

[Watch: After: finer streaks and soft splashes on terrain and water. Six seconds at fixed 30 fps; silent.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/environment-realism-extended/rain-after.webm))

</details>

#### Cab depth and rounded tyres for the cargo truck

The HEMTT cargo truck now has visible cab interiors, transparent glass, rounded tyre shoulders and draped canvas loads.

![After: seats and dashboard behind glass, rounded tyre shoulders and shaped cloth covers.](changelog/v1.0.12/hemtt-cab-depth/after.jpg)

<details>
<summary>Explore this change</summary>

- The upper cab is open behind its windows, with seats, headrests, dashboard and steering wheel. Transparent panes switch to opaque glass at long distances; wrecks lose the intact panes.
- Rounded rubber sidewalls surround recessed wheel rims. Smaller staggered tread blocks replace the previous broad bars and rotate with the wheels.
- Canvas loads have curved, folded shells and restraints that follow their shape. Painted bumpers and fuel tanks retain a nonmetallic coating.

![Before: the previous detail pass, with identical ground, shadows, camera and lighting.](changelog/v1.0.12/hemtt-cab-depth/before.jpg)

![The rebuilt supply truck in the game's terrain and daylight lighting.](changelog/v1.0.12/hemtt-cab-depth/in-game.jpg)

</details>

#### More readable detail on the HEMTT cargo truck

The cargo truck gains framed windows, wipers, tyre tread and distinct load hardware.

![Cargo truck after: window frames, tyre tread, bed latches and strapped cargo.](changelog/v1.0.12/hemtt-cargo-detail/close-after.jpg)

<details>
<summary>Explore this change</summary>

- Window gaskets, wipers and raised door panels give the cab more definition.
- Tyre lugs change the wheel silhouette; drum hoops, filler caps and load straps distinguish the cargo.
- Step lips and bed hinges carry localized rub marks. The other HEMTT variants retain their existing models while this art direction is evaluated.

![Before: the same truck with the CC0 material pass, under identical lighting.](changelog/v1.0.12/hemtt-cargo-detail/close-before.jpg)

![After at a wider, gameplay-scale studio view.](changelog/v1.0.12/hemtt-cargo-detail/wide-after.jpg)

![Before at the identical wider camera scale.](changelog/v1.0.12/hemtt-cargo-detail/wide-before.jpg)

</details>

#### Frame the alpine battlefield with a photographic daylight sky

Natural cloud forms and a sun-aligned photographic sky replace the plain daylight backdrop.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/photographic-daylight-sky/target-before.jpg)

<details>
<summary>Explore this change</summary>

Daylight uses a bundled 2K CC0 HDR panorama from Poly Haven, rotated to match the sunlight. Its static shader lets Godot cache sky lighting and reflections. Other weather and night moods retain their existing skies. No network download is needed.

[Asset and authors](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | [CC0 license](https://polyhaven.com/license).

![Revised: target view, matching seed and camera.](changelog/v1.0.12/photographic-daylight-sky/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/photographic-daylight-sky/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/photographic-daylight-sky/wide-after.jpg)

</details>

#### Steadier minimap updates

Minimap drawing is spread across frames while camera and pointer feedback stays responsive.

![The minimap keeps its detail while its layers take turns updating.](changelog/v1.0.12/progressive-minimap/after.jpg)

<details>
<summary>Explore this change</summary>

- Map details, combat markers, units and co-op markers take turns updating, reducing the work that lands on any one frame.
- The camera wedge and pointer update every frame. Rotating or resizing the minimap keeps all its layers aligned.
- Large-map building checks run in small slices, and soldiers share repeated smoothing calculations without changing their movement.

![Map layers remain aligned when the minimap turns with the camera.](changelog/v1.0.12/progressive-minimap/rotated.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.12/progressive-minimap/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.12/progressive-minimap/layout-after.jpg)

</details>

#### Separate ranges with distance-based scattering

Distant mountain groups lose contrast into sky-coloured haze while nearby ground retains its detail.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-01-aerial/target-before.jpg)

<details>
<summary>Explore this change</summary>

Exponential extinction with sky-coloured in-scattering; a deliberately simplified approximation, not a full atmospheric solver. Uses the existing Alpine haze option.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-16-accurate-atmospheric-scattering).

The revision reduces the broad pale wash, delays scattering until beyond nearby terrain, and lets high ridges retain contrast. Approved layer relief and texture-scale changes are retained in this parent branch.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-01-aerial/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-01-aerial/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-01-aerial/wide-after.jpg)

</details>

#### Give geological layers surface relief

Rock beds catch light along their ledges instead of appearing only as painted colour bands.

![Before: target view, matching seed and camera.](changelog/v1.0.12/realism-02-strata/target-before.jpg)

<details>
<summary>Explore this change</summary>

Screen-space derivatives perturb normals from the existing tilted bedding field. No displaced collision surface or new texture reads.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

![After: target view, matching seed and camera.](changelog/v1.0.12/realism-02-strata/target-after.jpg)

![Before: wide view, matching seed and camera.](changelog/v1.0.12/realism-02-strata/wide-before.jpg)

![After: wide view, matching seed and camera.](changelog/v1.0.12/realism-02-strata/wide-after.jpg)

</details>

#### Blend rock detail across different scales

Broad cliff fractures and smaller joint patterns break up recognisable repeated rock tiles.

![Before: target view, matching seed and camera.](changelog/v1.0.12/realism-03-rock-scales/target-before.jpg)

<details>
<summary>Explore this change</summary>

A second triplanar colour/normal scale is blended coherently. Six extra material reads at Medium/Far detail; Near keeps the cheaper original material.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

![After: target view, matching seed and camera.](changelog/v1.0.12/realism-03-rock-scales/target-after.jpg)

![Before: wide view, matching seed and camera.](changelog/v1.0.12/realism-03-rock-scales/wide-before.jpg)

![After: wide view, matching seed and camera.](changelog/v1.0.12/realism-03-rock-scales/wide-after.jpg)

</details>

#### Distinguish loose scree from solid cliffs

Sheltered lower slopes collect pale loose stone while exposed walls retain darker bedrock.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-04-talus/target-before.jpg)

<details>
<summary>Explore this change</summary>

Uses existing slope, elevation and baked shelter to weight the existing scree photographs. A deposition-inspired material mask, not new sediment simulation.

Research: [primary reference](https://wargaming.com/en/news/making_battle_arenas_in_wows/).

Loose stone collects in broken sheltered pockets, with photographic height detail breaking the deposit edge instead of a pale blanket across every lower slope.

Scree now forms irregular drainage fans instead of repeating yellow bands across distant mountains. Neutral stone coloration, coarse breakup and exposed bedrock interrupt the deposits.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-04-talus/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-04-talus/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-04-talus/wide-after.jpg)

</details>

#### Break up smooth snow with wind-shaped surface detail

Snow shelves gain shallow wind grooves and granular highlights instead of perfectly smooth white surfaces.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-05-snow-surface/target-before.jpg)

<details>
<summary>Explore this change</summary>

Adds derivative-filtered snow surface relief and changes its roughness coherently. The wind-groove approximation extends the existing slope/exposure snow coverage; it does not implement the reference occlusion map.

Research: [primary reference](https://download.nvidia.com/developer/SDK/Individual_Samples/DEMOS/Direct3D9/src/SnowAccumulation/Docs/SnowAccumulation.pdf).

Wind grooves now bend and break at two scales, with subdued granular shading, rather than forming evenly spaced parallel stripes.

Snow collects in connected sheltered shelves with irregular wind-scoured rock windows, broken edges and softer two-scale surface relief.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-05-snow-surface/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-05-snow-surface/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-05-snow-surface/wide-after.jpg)

</details>

#### Give damp cliff streaks a wet surface response

Sheltered runoff channels darken and develop a restrained sheen while exposed rock remains dry.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-06-seepage/target-before.jpg)

<details>
<summary>Explore this change</summary>

Existing runoff/shelter fields drive darkening, roughness and a bounded direct-light lobe. This is persistent seepage styling, not a hydrology simulation.

Research: [primary reference](https://seblagarde.wordpress.com/2013/03/19/water-drop-3a-physically-based-wet-surfaces/).

Compatibility retains damp colour and roughness but skips the extra direct-light sheen to avoid bright faceting.

Seepage follows connected runoff channels with variable shelter, darkening narrow damp areas rather than tinting a whole cliff.

Wet cliffs now show broad connected drainage stains and smaller vertical tributaries, with a darker, cooler surface response that remains visible at normal viewing distances.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-06-seepage/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-06-seepage/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-06-seepage/wide-after.jpg)

</details>

#### Replace cone-like spruce tiers with ragged boughs

Conifers have broken, asymmetric branch silhouettes that read as trees against rock and snow.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-07-spruce-boughs/target-before.jpg)

<details>
<summary>Explore this change</summary>

A shared low-polygon bough mesh replaces each solid cone tier, preserving the existing tree batching, burn state and placement.

Research: [primary reference](https://wargaming.com/en/news/creating_levels/).

Spruce sprays have divided tips and irregular branch lengths, producing fuller foliage with broken edges rather than flat triangular tiers.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-07-spruce-boughs/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-07-spruce-boughs/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-07-spruce-boughs/wide-after.jpg)

</details>

#### Give alpine stones angular fractured shapes

Stones at the mountain foot have irregular broken faces instead of flattened round primitives.

[Watch: Fractured stones at close range, then the surrounding slope. Native current-PR camera recording; simulation held, wind animated. The matched stills below show before and after.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/realism-08-fractured-stones/native-tour.webm))

<details>
<summary>Explore this change</summary>

A small set of cached seeded faceted meshes replaces decorative pebble spheres. Placement, passability and replicated dressing data stay unchanged.

Research: [primary reference](https://wargaming.com/en/news/creating_levels/).

Natural stones also use a rough granular material instead of the masonry material with mortar joints.

Decorative stones use the bundled rock photograph with triplanar projection, retaining their shared fractured meshes and avoiding flat grey surfaces.

Alpine dressing combines slabs, angular cobbles and smaller fragments in denser, varied clusters. Fine fragments are batched separately and culled at distance; larger stones remain visible.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-08-fractured-stones/target-before.jpg)

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-08-fractured-stones/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-08-fractured-stones/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-08-fractured-stones/wide-after.jpg)

</details>

#### Make meadow colour follow broad soil pockets

Connected dry grass and richer moss patches replace evenly green valley floors.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-09-meadow-mosaic/target-before.jpg)

<details>
<summary>Explore this change</summary>

Broad moisture and exposure masks reuse existing world-space noise and shelter, with fine photographic detail retained. No extra scatter or draw calls.

Research: [primary reference](https://wargaming.com/en/news/making_battle_arenas_in_wows/).

Meadow colour follows shelter and aspect more strongly, with quieter dry-grass colour that avoids broad camouflage-like brown blobs.

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-09-meadow-mosaic/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-09-meadow-mosaic/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-09-meadow-mosaic/wide-after.jpg)

</details>

#### Blend gravel into alpine shorelines

Coastal margins transition through exposed gravel and darker wet stone instead of a uniformly sandy strip.

[Watch: A close orbit over gravel, wet margins and exposed sand, followed by coastal context. Native current-PR recording; camera and water animated. Compare the matched stills below.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/realism-10-shore-gravel/native-tour.webm))

<details>
<summary>Explore this change</summary>

The existing shoreline and slope masks select photographic gravel and damp roughness. Water depth, wading and boat navigation remain authoritative and unchanged.

Research: [primary reference](https://seblagarde.wordpress.com/2013/03/19/water-drop-3a-physically-based-wet-surfaces/).

Gravel collects in broken coves and steeper banks, preserving sandy openings instead of tracing a continuous band around the whole coast.

Shorelines now blend neutral gravel, darker washed margins and exposed sand through irregular deposits, with photographic breakup at their edges.

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/realism-10-shore-gravel/target-before.jpg)

![Revised: target view, matching seed and camera.](changelog/v1.0.12/realism-10-shore-gravel/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/realism-10-shore-gravel/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/realism-10-shore-gravel/wide-after.jpg)

</details>

#### Give rock crevices more depth

Sheltered rock crevices receive stronger ambient occlusion while exposed rock stays open to sky light.

![Before: shared terrain baseline, identical seed and camera.](changelog/v1.0.12/rock-occlusion/before.jpg)

<details>
<summary>Explore this change</summary>

No new texture reads. Occlusion affects ambient lighting, with the existing direct-light contribution retained. This is a material approximation, not new ray tracing.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems/part-iii-materials/chapter-17-ambient-occlusion).

![After: Sheltered rock crevices receive stronger ambient occlusion while exposed rock stays open to sky light.](changelog/v1.0.12/rock-occlusion/after.jpg)

![Before: matching closer camera, shared baseline.](changelog/v1.0.12/rock-occlusion/close-before.jpg)

![After: the same closer camera; surface changes remain subtle.](changelog/v1.0.12/rock-occlusion/close-after.jpg)

![Before: focused comparison under matched lighting.](changelog/v1.0.12/rock-occlusion/target-before.jpg)

![After: Watch the shaded recess beside the central rib under diffuse light.](changelog/v1.0.12/rock-occlusion/target-after.jpg)

</details>

#### Break up repeating cliff textures

World-space texture warping breaks up repeated slab patterns without adding material samples.

![Before: shared terrain baseline, identical seed and camera.](changelog/v1.0.12/rock-warp/before.jpg)

<details>
<summary>Explore this change</summary>

Three additional scalar noise reads per terrain fragment; material reads stay at eighteen. Warping is fixed in world space and shared by colour and normal coordinates.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

![After: World-space texture warping breaks up repeated slab patterns without adding material samples.](changelog/v1.0.12/rock-warp/after.jpg)

![Before: matching closer camera, shared baseline.](changelog/v1.0.12/rock-warp/close-before.jpg)

![After: the same closer camera; surface changes remain subtle.](changelog/v1.0.12/rock-warp/close-after.jpg)

![Before: focused comparison under matched lighting.](changelog/v1.0.12/rock-warp/target-before.jpg)

![After: Watch the large fracture patterns on the bright central rock rib.](changelog/v1.0.12/rock-warp/target-after.jpg)

</details>

#### Break up alpine snowfields

Wind exposure and rock relief break up snow edges, with cooler compacted snow in sheltered pockets.

![Before: shared terrain baseline, identical seed and camera.](changelog/v1.0.12/snow-deposition/before.jpg)

<details>
<summary>Explore this change</summary>

No new texture reads. Fixed prevailing wind is a visual deposition heuristic, not weather simulation. Authoritative terrain and snowline settings are unchanged.

Technique reference: [research source](https://download.nvidia.com/developer/SDK/Individual_Samples/DEMOS/Direct3D9/src/SnowAccumulation/Docs/SnowAccumulation.pdf).

![After: Wind exposure and rock relief break up snow edges, with cooler compacted snow in sheltered pockets.](changelog/v1.0.12/snow-deposition/after.jpg)

![Before: matching closer camera, shared baseline.](changelog/v1.0.12/snow-deposition/close-before.jpg)

![After: the same closer camera; surface changes remain subtle.](changelog/v1.0.12/snow-deposition/close-after.jpg)

![Before: focused comparison under matched lighting.](changelog/v1.0.12/snow-deposition/target-before.jpg)

![After: Watch the boundary between snow and bare rock on the foreground peak.](changelog/v1.0.12/snow-deposition/target-after.jpg)

</details>

#### More deliberate tank handling

Tank turrets accelerate and settle onto targets, hold their bearing through hull turns, and acquire a steady aim before firing.

[Watch: The tank turns, traverses its turret and advances past the wall. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/tank-operation/tank-motion.mp4))

<details>
<summary>Explore this change</summary>

- Tank drivers build into turns rather than instantly changing their turning speed.
- Turrets traverse with acceleration and braking, and return forward by the shortest arc.
- Gunners hold a steady aim briefly before firing, including when switching targets.

![Before: the tank engaging the RPG team.](changelog/v1.0.12/tank-operation/before.jpg)

![After: the same encounter with gradual traverse and deliberate gun laying.](changelog/v1.0.12/tank-operation/after.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.12/tank-operation/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.12/tank-operation/layout-after.jpg)

</details>

#### Safer routes across hills and water

Tracks and wheels choose suitable slopes, and infantry wade through shallows instead of walking underwater.

<details>
<summary>Explore this change</summary>

- Infantry, wheeled vehicles and tracked vehicles use separate terrain limits. Vehicles account for nearby steep ground across their footprint, and supply trucks no longer bypass blocked terrain.
- Routes favour easier ground and roads. Connected areas are calculated when the map loads, and newly opened passages become available without treating separated shores as reachable.
- Soldiers can wade through water up to 55 cm deep. Deeper water is blocked even if an old terrain label calls it shallow; bridge decks remain usable.
- Movement checks the whole step, including dives, separation and vehicle recovery. Old routes cannot carry units through newly blocked ground or deep water.
- Living soldiers stay upright while wading. Spawning and disembarking use safe ground; soldiers stranded by a removed crossing recover to a safe bank.
- Ambush Alley autoplay uses its available mortars against spotted convoy vehicles stopped on the road, so it can finish the ambush under the updated movement rules.

</details>

#### Connect houses and streets with gardens, paths and grounded furniture

Scanned materials, weathered roads and leafy canopies give towns and their surrounding hills more natural detail.

[Watch: Native camera tour of photographed town surfaces, door paths and connected plots. Current PR with simulation held; the original stills below provide before/after evidence.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/town-ground-and-frontages/native-tour.webm))

<details>
<summary>Explore this change</summary>

Paving follows the terrain instead of sitting at flat-map height. Street furniture and wire endpoints carry their authoritative elevation into multiplayer and replays. House plots have maintained ground, narrow foundation aprons and routes to actual front or side doors; fences leave pedestrian and driveway gaps and break into short sections. Wild grass and shrubs stay outside maintained plots.

Photographic CC0 asphalt, paving slabs and grass/soil replace the flat procedural surfaces. Real-world texture scale, normal and roughness maps, per-slab wear and broad dry/green patches keep detail readable near houses and across the town. Urban grass clumps are shorter.

Road entrances blend through broken gravel edges; repaired asphalt patches and dark stains interrupt the carriageway. Roofs use aged tile and rough concrete scans, while timber fences have photographed grain and section-to-section weathering. Metal fences show dull paint and rust.

Brick, plaster, bark and country-road gravel also use scanned detail. Concrete driveways differ from paving-slab footpaths, with broad staining across sidewalks and roofs.

Trees, hedges and shrubs have open, photographed leaf and needle silhouettes. Patchy distant forests follow hills outside the battlefield using a small prebaked tree atlas: two triangles per tree, with cliffs, high peaks and coasts kept clear. Set View distance / detail to Near for the lighter view.

![Previous photographic surfaces: matching close camera.](changelog/v1.0.12/town-ground-and-frontages/detail-before.jpg)

![Broken road transitions, stained asphalt and weathered surfaces: matching close camera.](changelog/v1.0.12/town-ground-and-frontages/detail-after.jpg)

![Previous proposal: target view, matching seed and camera.](changelog/v1.0.12/town-ground-and-frontages/target-before.jpg)

![Revised: target view, matching seed and camera.](changelog/v1.0.12/town-ground-and-frontages/target-after.jpg)

![Previous proposal: wide view, matching seed and camera.](changelog/v1.0.12/town-ground-and-frontages/wide-before.jpg)

![Revised: wide view, matching seed and camera.](changelog/v1.0.12/town-ground-and-frontages/wide-after.jpg)

![Previous canopy and bare background slopes: matching panorama.](changelog/v1.0.12/town-ground-and-frontages/forest-before.jpg)

![Photographed canopy and dense background forest patches: matching panorama.](changelog/v1.0.12/town-ground-and-frontages/forest-after.jpg)

</details>

#### Deeper cabs and rounded tyres across more vehicles

Military truck variants and civilian cars gain visible interiors, while shared wheels gain rounded tyres, recessed rims and fitted tread.

![After: the Zamak has an open cab, rounded tyres and a draped cargo cover with fitted restraints.](changelog/v1.0.12/vehicle-detail-rollout/zamak-after.jpg)

<details>
<summary>Explore this change</summary>

- The cab treatment now covers every HEMTT, Zamak and Tempest mission body, plus the Offroad pickup, hatchback and SUV families.
- Rounded tyres and inset rims extend across the shared wheel builders. Road vehicles use finer tread; aircraft tyres stay smooth, and specialised tracked road wheels keep their own construction.
- The Zamak cargo and ammunition loads use the same draped cloth system as the HEMTT. Restraints follow the cover instead of floating over it.
- Glass switches to an opaque fallback at long distances and is removed from wrecks. Wheel detail rotates with the existing wheel pivots.

![Before: the same Zamak, camera, ground and lighting before the detail rollout.](changelog/v1.0.12/vehicle-detail-rollout/zamak-before.jpg)

![The Offroad pickup now has a visible cab interior and rounded road tyres.](changelog/v1.0.12/vehicle-detail-rollout/offroad-after.jpg)

</details>

#### Weight behind the gun

Older tanks, modern armour, aircraft and mounted weapons turn and acquire targets at distinct, deliberate rates. Vehicle and gunship rounds begin at their own barrels.

[Watch: Before / after, real time: the old tank, modern tank and IFV acquire the same target 90 degrees to their right. Older drives take longer to settle.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/vehicle-motion-and-muzzles/tanks-comparison.webm))

<details>
<summary>Explore this change</summary>

- Tank, IFV, anti-aircraft, artillery, light vehicle and helicopter weapons have different traverse rates, with acceleration and braking onto the target.
- Older tank drives take longer to acquire; modern tanks keep a steady firing solution as the hull turns, within the turret motor's available speed.
- Mounted machine guns, mortars and anti-tank posts must lay onto their bearing before firing.
- Tracked hulls build into pivots, wheeled vehicles cannot spin in place while reversing, and heavy-lift helicopters answer more slowly than lighter airframes.
- Vehicle and gunship rounds leave the correct model barrels, including scaled helicopter mounts and each of the gunship's separately positioned guns.

- Boats now have hull-specific cruise speeds, acceleration, engine and helm response, turning circles and astern thrust: quick RHIBs, heavier riverine craft, a deliberate jet patrol ship and a slow steel trawler.

[Watch: Before / after, real time: RHIB, patrol ship and trawler receive six seconds of full ahead, four seconds hard right, then a stop order. Course dots show the different turns.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/vehicle-motion-and-muzzles/boats-comparison.webm))

[Watch: Before / after launch-origin visualization: coloured pulses mark the actual 25, 40 and 105 mm launch points. Each gun now starts at its own barrel instead of below the fuselage.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/vehicle-motion-and-muzzles/aircraft-comparison.webm))

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.12/vehicle-motion-and-muzzles/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.12/vehicle-motion-and-muzzles/layout-after.jpg)

</details>

#### Distinct surfaces across the vehicle roster

Armor, aircraft, civilian vehicles and boats now have distinct finishes, finer texture detail and wear that stays attached as they move.

![Civilian paint after: fine surface detail replaces the oversized wear patches.](changelog/v1.0.12/vehicle-surface-library/hatchback-after.jpg)

<details>
<summary>Explore this change</summary>

- Matte armor paint, smoother aircraft coatings, civilian clearcoat, rubber tyres, canvas covers and exposed metal now respond differently to light.
- Large blotches on civilian bodywork give way to fine surface texture and restrained wear. Boat walking decks have a rough nonslip finish.
- Camouflage, wear and lower-body dirt stay on the vehicle when it moves or climbs. Faction colors are preserved.
- The water scooter’s curved hood no longer produces invalid surface normals.

- CC0 coating, rubber, fabric and metal textures now feed the shared finishes. Painted cargo drums lose their bare-metal sparkle, the RHIB has a treaded deck, and worn trawler fittings have localized corrosion.

![Before: the same hatchback, camera, seed and lighting.](changelog/v1.0.12/vehicle-surface-library/hatchback-before.jpg)

![Armor after: matte coatings, finer relief and distinct rubber and metal.](changelog/v1.0.12/vehicle-surface-library/tank-after.jpg)

![Before: the same tank, camera, seed and lighting.](changelog/v1.0.12/vehicle-surface-library/tank-before.jpg)

![Shared finishes under the same lighting: coatings, rubber, canvas, metal, glass and nonslip.](changelog/v1.0.12/vehicle-surface-library/surface-swatches.jpg)

</details>

### Fixed

#### Softer beaches and rolling surf

Fine gravel fades into beach sand, and breakers roll toward shore without a sharp ribbon across the water.

[Watch: Six seconds of matched native motion: before on the left, after on the right. Watch the offshore crease disappear.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.12) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.12/shoreline-blending/comparison.mp4))

<details>
<summary>Explore this change</summary>

Beach gravel now uses fine photographed grains in broad, feathered deposits instead of large mountain-rock chips. Coastal foam breaks into patches and shallow water fades more gently over the sand.

The surf's repeating shape now joins smoothly between waves, removing the hard crease across the water. These are surface changes; water depths and routes remain the same.

![Before: oversized gray chips and a sharp offshore wave crease.](changelog/v1.0.12/shoreline-blending/waterline-before.jpg)

![After: fine warm grains, softer water contact and a continuous breaker.](changelog/v1.0.12/shoreline-blending/waterline-after.jpg)

![Before, at town viewing distance.](changelog/v1.0.12/shoreline-blending/town-before.jpg)

![After, with the same town, camera and lighting.](changelog/v1.0.12/shoreline-blending/town-after.jpg)

</details>

## v1.0.11: Watch battles and revisit the action

*28 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.11)

### New

#### Watch battles and revisit the action

Watch public battles in the browser and revisit saved action with camera and timeline controls.

![A recorded test battle running in the browser, with the game's own camera and a seekable timeline.](changelog/v1.0.11/battle-viewer/browser.jpg)

<details>
<summary>Explore this change</summary>

Watch public battles in the browser, or revisit saved battles with camera controls and a seekable timeline.

Public battles can now broadcast to a browser viewer, using Frontline's own
3D battlefield. Open **Battles → Watch** on the website, move the camera, or
let the observer camera follow the fighting. Public broadcasts aim to stay only a few seconds behind the players; password-protected and unlisted battles stay private.

The host also saves a replay locally. Open **Replays** in the desktop menu and
choose a recording folder to watch it again, pause, change speed, or drag the
timeline back to an earlier moment. Public recordings remain available on the
website for seven days when the server's recording storage is enabled.

Saved replays load fully before playback starts. Loading progress and all replay
controls, including the scrubber, live inside the game itself.

These are host recordings, not independently verified results. Recordings made
before this feature cannot be reconstructed from an old after-action report.

The browser battlefield fills the available window, keeping the FPS meter clear of the site header. Replay controls use the desktop Signal interface and sit beside the minimap, with the director caption above the timeline.

![Find recordings from the Battles page. The 3D viewer works best on a desktop.](changelog/v1.0.11/battle-viewer/mobile.jpg)

![Saved replays load completely before playback, with progress and controls inside the game.](changelog/v1.0.11/battle-viewer/loading.jpg)

![The fitted browser player keeps the FPS meter visible and integrates replay controls beside the desktop minimap.](changelog/v1.0.11/battle-viewer/fitted.png)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/battle-viewer/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/battle-viewer/layout-after.jpg)

</details>

#### Inspect vehicles on the website

Inspect vehicle models on the website with rotation and zoom controls.

![Browse the roster and inspect the game's vehicle models on the website.](changelog/v1.0.11/website-field-manual/desktop.jpg)

<details>
<summary>Explore this change</summary>

Explore vehicles directly on the website, with an interactive model preview using the Field Manual's models, lighting, rotation and zoom.

- Search vehicles by name, faction or role and filter by availability.
- Switch vehicles without restarting the 3D viewer. Compressed browser assets reduce the first download.
- Inspect models in a new slate survey bay, with a fading grid, warm corner markings and clearer lighting, shared by the website and the in-game Field Manual.
- Quiet digital interference occasionally passes through the survey grid; reduced-motion settings keep it still.
- Watch armed support aircraft perform their real gun run, bombing pass or orbit in the embedded training range. Replay resets the aircraft and targets without rebuilding the range; return to model inspection at any time.
- Select a vehicle to inspect its 3D model directly beside the roster. Drag to turn it, scroll to zoom, or use the camera buttons with a keyboard. The page uses the site's familiar styling around the game's own model stage.

![The in-game Field Manual shares the new slate survey bay and model lighting.](changelog/v1.0.11/website-field-manual/manual.jpg)

![Watch the aircraft's actual attack sequence in a training range inside the page.](changelog/v1.0.11/website-field-manual/gun-run.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/website-field-manual/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/website-field-manual/layout-after.jpg)

</details>

### Improved

#### Less work during busy battles

Busy battles spend less time maintaining routes and rebuilding animated combat markers.

<details>
<summary>Explore this change</summary>

Pathfinding spends less time maintaining its cache, and animated combat markers reuse their geometry.

- Long routes no longer scan the entire local navigation cache when replacing an old entry.
- Combat markers keep the same pulsing, rotating shape with less work per frame.

These changes reduce specific costs; they do not establish 60 FPS support for 500-unit battles on large maps.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/battle-hotpaths/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/battle-hotpaths/layout-after.jpg)

</details>

#### Less repeated work in large battles

Large battles avoid repeated scenery and visibility work while keeping the battlefield responsive.

![After: the same map and camera, with visibility-aware rendering and native routes. Combat evolves independently between runs.](changelog/v1.0.11/battle-work-budget/after.png)

<details>
<summary>Explore this change</summary>

Scenery follows the camera's view, and soldiers avoid repeating sight checks against unchanged walls.

- Scenery loads around what the camera can see, including a margin for roofs and screen edges.
- Large maps store navigation cells compactly, saving about 1.25 GiB across the two 3 km land grids.
- Replay recording reuses unchanged scenery and encodes completed chunks in the background to reduce battle stalls.
- Formation planning reuses nearby cover checks while retaining the same selected positions.
- Native path search skips intermediate cost nodes while retaining terrain and danger costs.
- Soldiers reuse confirmed obstruction by an unchanged wall. Opening a door or changing the blocking geometry immediately requires a fresh check; smoke remains live.

- Distant soldiers outside the camera view no longer rebuild render batches.
- Tactical symbols retain their image between 15 Hz updates while the camera and pointer are still; camera movement and input refresh them immediately.

Large-map performance is still being measured. These changes do not establish 60 FPS support for 500-unit battles.

![Before: the generated 3 km battlefield at command zoom.](changelog/v1.0.11/battle-work-budget/before.png)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/battle-work-budget/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/battle-work-budget/layout-after.jpg)

</details>

#### See the troops you command

See troops and terrain more clearly through lighter haze and translucent battlefield markers.

![After: thinner haze, transparent symbols and quieter commander markers leave the troops visible.](changelog/v1.0.11/clearer-battlefield/battlefield-after.jpg)

<details>
<summary>Explore this change</summary>

Lighter atmospheric haze and translucent battlefield markers keep soldiers, vehicles and terrain readable, even when zoomed out.

- Atmospheric haze is much lighter in every weather preset and continues thinning as the camera pulls back. Fog of war, enemy visibility and combat smoke are unchanged.
- Squad and vehicle symbols are translucent outlines over the battlefield. Solid counters remain in the tactical map, minimap and roster.
- Squad symbols fade in with distance instead of stacking over nearby soldiers. Individual status icons lose their opaque backplates, and squad-strength pips replace overlapping per-soldier bars at squad zoom.
- Teammate view frames and selection rings are thinner and quieter. A teammate's selection is a coordination hint, not an exclusive ownership badge.

![Before: hazy weather and solid squad markers compete with the troops.](changelog/v1.0.11/clearer-battlefield/battlefield-before.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/clearer-battlefield/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/clearer-battlefield/layout-after.jpg)

</details>

#### Helicopters fly like helicopters

Helicopters carry momentum, bank through turns and flare into a hover before landing.

[Watch: A Mohawk banks and settles over its sling pickup. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.11) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.11/helicopter-flight/helicopter-turn.mp4))

<details>
<summary>Explore this change</summary>

Rotorcraft carry momentum through turns, bank and pitch as they accelerate, and flare into a stable hover before landing.

- Attack, troop and supply helicopters accelerate, brake, climb and descend smoothly instead of instantly changing direction or vertical speed.
- Aircraft lean into the force of a turn and raise their noses to brake. Gunships can move sideways while keeping their guns on target.
- Transports settle before putting down troops or picking up a sling load. Heavy loads make flight more deliberate.
- Stop holds a troop transport in the air, including with a vehicle on its sling. Give a new move order to carry on; new orders also interrupt an approach to land.
- Flight remains controlled by the host, with the same bank and pitch sent to every player. Ground vehicles and drones keep their existing movement.

![After: the same mid-flight order produces a banked turn while momentum carries through.](changelog/v1.0.11/helicopter-flight/after.jpg)

![Before: a transport changes direction directly toward its new destination.](changelog/v1.0.11/helicopter-flight/before.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/helicopter-flight/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/helicopter-flight/layout-after.jpg)

</details>

#### A new introduction to Frontline

Discover Frontline through tactical decisions, combined-arms footage and operation briefings.

![From your first tactical decision to a combined-arms battle.](changelog/v1.0.11/homepage-story/after-desktop.jpg)

<details>
<summary>Explore this change</summary>

Discover the game through battlefield decisions, combined-arms footage and selectable operation briefings.

- The homepage builds from squad tactics to armour, fire support and amphibious operations, with varied layouts and quieter motion inspired by the game's Signal interface.
- Browse mission briefings one at a time, with the force details available on mobile as well as desktop.
- Gameplay comes straight after the opening footage, without the repeating tickers and statistics grid.

![Choose an operation to see its briefing and your starting force.](changelog/v1.0.11/homepage-story/after-missions.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/homepage-story/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/homepage-story/layout-after.jpg)

</details>

#### Smoother large battles

Large battles draw scenery and squad symbols more efficiently while preserving combat behavior.

![Combined scenery drawing preserves the buildings and their shadows during combat.](changelog/v1.0.11/large-battle-drawing/after.jpg)

<details>
<summary>Explore this change</summary>

Large battles draw buildings and squad symbols with less repeated work, while damage, cover and individual soldiers keep their existing behavior.

- Static buildings share drawing work. A damaged or moved structure updates immediately without rebuilding its neighbors.
- Soldiers share frame-update bookkeeping while retaining individual movement smoothing, poses and selection.
- Squad counters keep a clear screen position as nearby units move, reducing clutter and repeated layout work.
- Firing markers reuse their star geometry, and the minimap refreshes damaged buildings gradually while keeping the previous map visible.
- Moving soldiers avoid recording sight checks they cannot reuse; soldiers standing still, including those waiting for a route, retain their obstruction cache.

![The large-map battle before scenery drawing is combined.](changelog/v1.0.11/large-battle-drawing/before.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/large-battle-drawing/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/large-battle-drawing/layout-after.jpg)

</details>

#### Command all allied troops

Coordinate freely with teammates by selecting and ordering any allied troop or vehicle.

<details>
<summary>Explore this change</summary>

All commanders on a side can select and order every allied squad, vehicle and individual soldier, without ownership locks.

- Click, drag-select and use the order-of-battle list to command any allied unit, including troops recruited by a teammate.
- Giving an AI-controlled unit an order brings it under human command so the AI does not overwrite it. Teammates can all keep commanding it.
- Allied engineers can build for any commander, and tunnel orders work for all allied passengers.
- Current teammate selections remain coordination cues, not control restrictions. Enemies and neutral units still cannot be commanded; observers can inspect but cannot issue orders.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/shared-allied-command/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/shared-allied-command/layout-after.jpg)

</details>

#### Large-battle simulation and rendering improvements

Play larger skirmishes with less repeated simulation work and more efficient distant-unit drawing.

![A full generated 3,072 metre battlefield, started with 480 soldiers and 20 vehicles. The 60 FPS target remains under validation.](changelog/v1.0.11/simulation-working-sets/after.png)

<details>
<summary>Explore this change</summary>

Desktop solo battles run simulation separately, share more AI work, and draw distant soldiers more efficiently. Skirmishes offer maps up to 3,072 metres across.

- Static scenery no longer runs an empty building simulation every tick. Fire and combat still affect it.
- Supply and unit-cap checks search the bases directly, including changes from construction, capture and destruction.
- Performance diagnostics now distinguish sustained simulation cost from occasional slow ticks.
- Updating nearby cover no longer rebuilds routes through ground whose movement cost has not changed.
- Desktop solo battles and missions run their simulation separately from drawing, with pause, resume and reconnect support.
- Skirmish setup offers 1,024, 2,048 and 3,072 metre square maps. Larger maps need more memory.
- Squad members share threat assessments and building contacts; individual weapons, visibility and damage still work independently.
- Distant soldiers share simpler animated poses, while close-up soldiers retain detailed movement.
- Movement orders spread pathfinding work across ticks, including when buildings are destroyed or routes are blocked.
- Updates include the native simulation helper as well as the game executable.

- Explosions update nearby terrain textures and cosmetic ground collision instead of rebuilding the entire map.
- Large maps load without drawing the partly built battlefield; the private simulation waits until loading finishes.
- Static scenery replication and map placement avoid repeated whole-map searches.
- Nearby scenery loads first; distant scenery is cached as you explore the map.
- Cosmetic grass, bushes and stones build around the camera rather than across the whole map during play.
- Nearby units can reuse checked movement corridors, while keeping their own destinations.
- Short unobstructed moves respond immediately, including dashes into cover.
- Squads retry an unvisited house when a rifleman becomes available to clear it.
- Soldiers checking buildings search house floors directly, skipping unrelated nearby scenery.
- Emplaced gunners choose targets their gun can reach instead of fixating on enemies outside its firing arc.
- Soldiers evaluate the same reaction priorities with less decision-processing overhead.
- Squad callsigns and order labels reuse their drawings while tracking the camera, reducing interface work in large battles.
- Stationary units avoid redundant model-transform updates, and distant soldier batches avoid rebuilding string keys each frame.
- Radio notifications reuse unchanged text drawings between their arrival flashes and fade-out.
- Distant vehicles simplify material surfaces while retaining their moving parts; close-up vehicles keep their detailed materials.
- Distant soldier rendering visits active pose batches instead of every cached pose each frame.
- Squad status markers share a short overview refresh, and empty selections avoid scanning every soldier.
- The minimap keeps distant fighting markers separate on larger maps.
- Stationary vehicles avoid repeatedly updating unchanged hull, turret and wheel transforms.
- The battlefield overlay reuses its drawing between status updates while the camera and pointer are still; interaction redraws immediately.
- Visibility checks skip unrelated projectiles and reuse each soldier's observation point within a scan.
- Capturing towns updates only changed supply roads instead of repainting the whole map; long diagonal roads check only nearby ground cells.
- Squads checking for enemy buildings use the owned-building index instead of searching unrelated scenery.
- The battle clock follows the simulation server, excluding loading time and stopping when the host pauses.
- Large assault formations check only nearby squadmates when choosing cover, retaining the same positions with fewer comparisons.

![The earlier 500-soldier rendering test on a 1,024 metre map.](changelog/v1.0.11/simulation-working-sets/before.png)

![Detailed vehicle materials at distant camera range, magnified for comparison.](changelog/v1.0.11/simulation-working-sets/vehicle-before.png)

![Distant vehicles share simpler material surfaces while retaining their silhouettes and moving turrets.](changelog/v1.0.11/simulation-working-sets/vehicle-after.png)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/simulation-working-sets/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/simulation-working-sets/layout-after.jpg)

</details>

#### A clearer way around Frontline

Find your next battle, account and rank information through clearer website navigation.

![Signed in: play shortcuts, your progress and the latest updates. Preview shown with sample player data.](changelog/v1.0.11/site-journeys/player-home.jpg)

<details>
<summary>Explore this change</summary>

A simpler site menu, a returning-player home, and a dedicated rank guide make it easier to find your next battle.

- The menu now separates the game tour, live battles, commanders and updates. Account actions stay in the account menu; project links stay in the footer.
- Signed-in players get a compact home with play shortcuts, progress and recent updates. Visitors still see the gameplay introduction.
- New devices see Download first. After the browser has opened Frontline before, Launch becomes the primary action.
- The rank guide explains experience and unlocks. Choose your personal insignia in your profile.
- Signing in keeps your place, including a friend's battle invitation. An account remains optional to play.

![New here: download the game and follow three steps to your first battle.](changelog/v1.0.11/site-journeys/guest-play.jpg)

![Leaderboards and the rank guide now live together under Commanders.](changelog/v1.0.11/site-journeys/rank-guide.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/site-journeys/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/site-journeys/layout-after.jpg)

</details>

#### Squads stick together

Squads stay closer together and choose cover on the same side of walls.

![After: four soldiers take cover against the middle wall; the fifth stacks in a second row 1.5 metres behind them, with reduced protection. Same scenario, seed, time and camera as before.](changelog/v1.0.11/squad-cohesion/after.jpg)

<details>
<summary>Explore this change</summary>

Squads move in tighter groups and choose nearby cover on the same side of walls.

- Move and defend orders keep soldiers in a compact circle instead of a long line.
- Soldiers favor cover beside their squad instead of spreading out across walls.
- When a tall wall's front row is full, soldiers stack a pace behind it instead of lying farther out in the open. The rear row still benefits from the wall blocking fire, but lacks the close-cover protection of hugging it.
- Travelling squads follow their leader through gaps, and the leader slows for stragglers.

![Before: one squad spreads across all three walls while seeking cover. Enemies are beyond the walls, outside this view.](changelog/v1.0.11/squad-cohesion/before.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/squad-cohesion/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/squad-cohesion/layout-after.jpg)

</details>

### Fixed

#### Keep large interfaces within reach

Keep menus, controls and multiplayer rosters reachable in small windows and at large interface scales.

![After: the roster scrolls while Start and Close stay clearly in view.](changelog/v1.0.11/large-interface-layouts/lobby-after.jpg)

<details>
<summary>Explore this change</summary>

Pause menus, controls, lobby rosters and the server browser stay usable at maximum interface scale and in small windows.

- Pause and controls dialogs scroll when their contents cannot fit, with focused buttons brought into view.
- Full eight-player lobby rosters scroll without pushing Join, Ready, Start or Leave out of reach.
- Server-browser filters and direct-connect fields wrap instead of forcing the screen wider than the window.
- Repeatedly opening a dialog no longer shifts its resting position. Resizing during its opening animation keeps it centered.

![Before: a full co-op roster pushes the lobby actions into the bottom edge.](changelog/v1.0.11/large-interface-layouts/lobby-before.jpg)

![Before: maximum interface scale pushes the Controls dialog beyond the window.](changelog/v1.0.11/large-interface-layouts/controls-before.jpg)

![After: the dialog fits the window and its contents can be scrolled.](changelog/v1.0.11/large-interface-layouts/controls-after.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.11/large-interface-layouts/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.11/large-interface-layouts/layout-after.jpg)

</details>

## v1.0.10: Console tools and fuzzy completion

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.10)

### Improved

#### Find console commands as you type

Find console commands and their arguments through suggestions that narrow as you type.

![Browse the full command list without leaving the console.](changelog/v1.0.10/console-completion/after.jpg)

<details>
<summary>Explore this change</summary>

A scrollable command dropdown lists every command, then narrows to fuzzy matches and argument suggestions as you type.

- An empty prompt shows every command with its description in a scrollable dropdown.
- Typing finds close matches, including partial spellings and small typos. Arguments get suggestions too.
- Use Up/Down to choose, then Tab or Enter to insert; you can also click a suggestion. Inserting never executes it.
- Ctrl+Up/Down browses your command history. Esc dismisses suggestions before closing the console.
- Completing in the middle of a line keeps the arguments that follow it.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.10/console-completion/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.10/console-completion/layout-after.jpg)

</details>

#### A console you can copy, search and save

Copy, search and save console output, and paste commands using familiar shortcuts.

![Console tools for copying, finding and saving output.](changelog/v1.0.10/text-console/after.jpg)

<details>
<summary>Explore this change</summary>

Select and copy console output, paste commands, search scrollback and save transcripts, with familiar terminal shortcuts.

- Select text and copy it with Ctrl+C or the right-click menu. Paste into the command prompt with Ctrl+V or Ctrl+Shift+V.
- Copy all output or save a plain-text transcript with the toolbar.
- Find output with Ctrl+F; Enter and Shift+Enter move through matches.
- Clear output with Ctrl+L, jump through scrollback with Ctrl+Home/End, and adjust text size with Ctrl+plus/minus.
- Ctrl+C with nothing selected clears the prompt and safely stops a running benchmark.
- Command history, Tab completion, undo/redo and normal text editing remain available.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.10/text-console/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.10/text-console/layout-after.jpg)

</details>

### Fixed

#### Sign in to the game from your website login

Use your existing website session to sign into Frontline without repeating the GitHub login.

<details>
<summary>Explore this change</summary>

Already signed into the website? Signing in from the game now uses that account and returns you to Frontline automatically.

The website no longer asks you to sign in with GitHub again when you're already signed in.
Your game and website keep separate sessions, so both stay signed in. If the browser blocks opening the game
automatically, use **Open Frontline** to return.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.10/existing-website-login/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.10/existing-website-login/layout-after.jpg)

</details>

## v1.0.9: A new look for the whole interface

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.9)

### Improved

#### A new look for the whole interface

A consistent tactical interface makes battle controls, menus, the Field Manual and reports easier to scan.

![The battle's interface sits straight on the battlefield](changelog/v1.0.9/signal-interface/battle-hud.jpg)

<details>
<summary>Explore this change</summary>

Every screen now reads like a battle management display: the battle's interface sits straight on the battlefield with no boxes, states are short codes, every figure lines up in mono, and one colour marks what's selected. The menus, the multiplayer screens, the Field Manual and the after-action report follow.

- **No more boxes:** the status line, the order of battle, fire support, the selection and the orders sit on the
  battlefield over a soft darkening at the screen's edges, with thin rules between rows.
- **Short codes:** each squad's line says what it's doing in a few characters (`PINNED · TO SPT D4`, `MOV E8`),
  supply reads `SUP 2115 +230/M`, the clock `T+04:31`, and a man's role `RFL`, `MG` or `MED`.
- **Fire support** lists the missions that are ready; the rest fold into one line with the next one's countdown.
- **Orders** are a grid of keys, the order you're giving lit up.
- **Alerts** come in three levels: a plain line, a yellow caution and a red warning that flickers in.
- **On the battlefield** base and town names, hover cards and cursor hints lose their boxes, and `+115 SUP` is a
  small tag rather than the biggest text on the screen.
- **The menus:** entries in capitals that light up while they're open, the account on one line top right, a new
  version or a battle to rejoin as one line each. New Operation picks a side from three rows and the time of day
  from one, and each mission is a line with its briefing under it.
- **Multiplayer:** the server browser lists battles as rows (players, status and connection as short codes) with
  the details beside them; hosting puts each choice on its own row; the lobby shows each side as a list of seats
  marked HOST, YOU, READY or OPEN, and its chat reads like the battle's message log.
- **The Field Manual** lists every entry with a small square in its side's colour, and its numbers as a table with
  counted bars. **The statistics and the after-action report** have every figure in mono, counted bars and plain
  lines on the timeline.
- **The loading screen** sets the briefing out in rows and counts its progress in steps; **the end of a battle**
  types VICTORY or DEFEAT on through a burst of interference, with the battle's clock under it.
- **Settings:** on/off and short choices are rows of segments, amounts are counted bars, and the tabs are
  underlined. New: **Settings > Interface > Reduce motion** makes everything appear at once instead of typing or
  flickering in.
- **F1** is a key reference in three columns, using your own key bindings, instead of a page of paragraphs.
- **The message history (L)** opens in place of the latest messages, only as tall as what's in it.
- **Fixed:** the sign-in panel could open as an empty strip down the screen, and the Missions and Insignia panels
  could run off the bottom of it.

![The same moment before](changelog/v1.0.9/signal-interface/battle-hud-before.jpg)

![The main menu](changelog/v1.0.9/signal-interface/main-menu.jpg)

![Missions: each one on a line, the briefing under it](changelog/v1.0.9/signal-interface/missions.jpg)

![Hosting a battle: every choice on its own row](changelog/v1.0.9/signal-interface/host-a-battle.jpg)

![The Field Manual](changelog/v1.0.9/signal-interface/field-manual.jpg)

![The after-action report](changelog/v1.0.9/signal-interface/after-action-report.jpg)

![Settings: short choices as segments, amounts as counted bars](changelog/v1.0.9/signal-interface/settings.jpg)

![F1 is now a key reference you can take in at a glance](changelog/v1.0.9/signal-interface/key-reference.jpg)

![The Esc menu](changelog/v1.0.9/signal-interface/pause-menu.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.9/signal-interface/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.9/signal-interface/layout-after.jpg)

</details>

#### Battles load sooner, and without freezing

Enter battles sooner with a responsive loading screen and no long freeze after loading finishes.

<details>
<summary>Explore this change</summary>

A battle no longer freezes for several seconds after it has loaded, it's ready to play sooner, and the loading bar keeps moving while the battlefield is laid out instead of sitting still.

- **No freeze after loading:** the long stop between the loading bar filling and the battle starting is gone.
- **Ready sooner:** buildings, trees, vehicles and the town's street furniture are put together much faster, so you're
  playing several seconds earlier.
- **A window that answers:** the loading bar moves stage by stage, and Windows no longer calls the game "Not
  Responding" while a battle loads.
- Everything looks and plays exactly as before.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.9/battle-loads-without-freezing/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.9/battle-loads-without-freezing/layout-after.jpg)

</details>

### Fixed

#### Joining a battle loads it before it starts

Joining waits for the whole battlefield to arrive and load, avoiding a half-built map and long freezes.

![Joining a running battle: the loading screen waits while the battlefield goes up](changelog/v1.0.9/joining-loads-first/loading-screen.jpg)

<details>
<summary>Explore this change</summary>

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

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.9/joining-loads-first/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.9/joining-loads-first/layout-after.jpg)

</details>

## v1.0.8: UI and more!

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.8)

### Improved

#### A new look for the battle's interface

A clearer battle overlay puts concise unit states, aligned figures and selected actions directly over the field.

![The battle's interface sits straight on the battlefield](changelog/v1.0.8/signal-interface/battle-hud.jpg)

<details>
<summary>Explore this change</summary>

The battle's interface now reads like a battle management display laid onto the battlefield: no more boxes, short codes instead of sentences, every figure lined up in mono, and one colour for what's selected.

- **No more boxes:** the status line, the order of battle, fire support, the selection and the orders sit on the
  battlefield over a soft darkening at the screen's edges, with thin rules between rows.
- **Short codes:** each squad's line says what it's doing in a few characters (`PINNED · TO SPT D4`, `MOV E8`),
  supply reads `SUP 2115 +230/M`, the clock `T+04:31`, and a man's role `RFL`, `MG` or `MED`.
- **Fire support** lists the missions that are ready; the rest fold into one line with the next one's countdown.
- **Orders** are a grid of keys, the order you're giving lit up.
- **The selection** shows the squad's state once, its plan's stages, and a cell for each man with his role.
- **Alerts** come in three levels: a plain line, a yellow caution and a red warning that flickers in.
- **On the battlefield** base and town names, hover cards and cursor hints lose their boxes, and `+115 SUP` is a
  small tag rather than the biggest text on the screen.
- **Settings:** on/off and short choices are rows of segments, amounts are counted bars, and the tabs are
  underlined. New: **Settings > Interface > Reduce motion** makes everything appear at once instead of typing or
  flickering in.
- **F1** is a key reference in three columns, using your own key bindings, instead of a page of paragraphs.
- **The message history (L)** opens in place of the latest messages, only as tall as what's in it.

![The same moment before](changelog/v1.0.8/signal-interface/battle-hud-before.jpg)

![Settings: short choices as segments, amounts as counted bars](changelog/v1.0.8/signal-interface/settings.jpg)

![F1 is now a key reference you can take in at a glance](changelog/v1.0.8/signal-interface/key-reference.jpg)

![The Esc menu](changelog/v1.0.8/signal-interface/pause-menu.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.8/signal-interface/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.8/signal-interface/layout-after.jpg)

</details>

### Fixed

#### Website links work again after an uninstall

Starting Frontline restores its website links if another uninstall or system cleanup removed them.

<details>
<summary>Explore this change</summary>

If the links from the website were taken away (uninstalling another copy of Frontline, or a registry cleaner), the game never claimed them back, so Join, Find Match and signing in on the website did nothing. Starting the game sets them up again now.

- Each time it starts, the game checks that your system still opens website links with it, and sets them up again
  if not.
- With more than one copy of the game, links open the one you started last.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.8/links-claimed-again/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.8/links-claimed-again/layout-after.jpg)

</details>

## v1.0.7: Small fixes

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.7)

### Fixed

#### Website links reach the game you have open

Website sign-in and join links reach the running game instead of opening another copy after an update.

<details>
<summary>Explore this change</summary>

Signing in on the website, or pressing Join or Find Match there, could start a second copy of the game instead of going to the one you had open. It happened after the game had updated itself. The link goes to the open game now.

- The same happened to a game started while another copy of it was still running, once that other copy had closed.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.7/links-reach-the-open-game/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.7/links-reach-the-open-game/layout-after.jpg)

</details>

## v1.0.6: Performance

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.6)

### Improved

#### The game opens faster

The title and menu appear sooner while the rest of the game prepares in the background.

<details>
<summary>Explore this change</summary>

The title and the menu come up seconds sooner after you launch the game. The rest of the game gets ready behind the title while it plays, instead of before anything shows.

- **The title shows sooner:** the game used to prepare everything it would need for a battle before showing
  anything at all. Now it shows the title and the menu as soon as they're ready, and prepares the battle behind
  them while the title plays.
- **Starting a battle straight away** (in the first few seconds) waits behind the loading screen for that to
  finish; after that, battles start as quickly as before.
- **The Field Manual and the Settings** are put together the first time you open them, not every time the game
  starts.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.6/faster-launch/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.6/faster-launch/layout-after.jpg)

</details>

#### Battlefields are laid out faster

Spend less time preparing terrain, roads and cover before entering a battle.

<details>
<summary>Explore this change</summary>

Laying out a new battlefield - the rivers and the sea, the roads, the cover the ground gives - is several times quicker, so a battle or a mission starts several seconds sooner. The ground comes out exactly as it did.

- **Why:** the water, the roads and the cover were worked out cell by cell over far more of the map than they
  touch, and some of it two or three times over. Now each is worked out only where it reaches, once, and the
  water and the cover are shared out over all your processor's cores.
- **What didn't change:** the battlefield. Every river, road, house, hedge and tree is where it was, the cover and
  the routes are the same, and a replayed battle plays out the same.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.6/faster-map-generation/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.6/faster-map-generation/layout-after.jpg)

</details>

## v1.0.5: Performance and more

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.5)

### New

#### Leaderboards, and a page for every commander

Compare commander rankings and explore players' records, battle histories and after-action reports.

![The leaderboards: experience of all time, this month and this week, with you marked](changelog/v1.0.5/leaderboards-and-public-profiles/leaderboards.jpg)

<details>
<summary>Explore this change</summary>

The website ranks the commanders with the most experience, of all time, this month and this week, and every player has a page of their own: their rank, their record, and the battles they've fought, after-action reports and all.

- **Leaderboards** on the website rank experience, all time, this month and this week. Signed in, you'll find yourself marked on it, wherever you are. Experience is timed on the matchmaker's clock, so nobody can claim more than they've played.
- **Every commander has a page**: their rank, experience, battles won and place on the board, their career, and every battle they've fought signed in, each with its after-action report and every commander in it rated the way the game rates them. Find anyone by callsign; a host's name in the battle list leads to theirs.
- **Your battles are public now.** Before, your service record was only ever shown to you. If you'd rather keep it that way, untick **Show my battles** on your profile: your rank and record stay on your page, your battles and career come off it, and the game still shows them to you.
- **Your picture**: your insignia, or the picture on your GitHub account, if you signed in with GitHub. Pick it on your profile.
- **Sign out everywhere** on your profile signs your account out of every game and browser it's signed in to.
- **A battle counts on your record** (battles fought and won) only if it earned experience: two minutes or more. A battle abandoned in its first minute no longer counts as fought, or won.

![A commander's page: their rank and record, their career and their battles](changelog/v1.0.5/leaderboards-and-public-profiles/player.jpg)

![A battle's after-action report on the website, every commander rated as the game rates them](changelog/v1.0.5/leaderboards-and-public-profiles/battle.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/leaderboards-and-public-profiles/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/leaderboards-and-public-profiles/layout-after.jpg)

</details>

#### A console that tells you why the game is slow

Use the console to investigate slow frames, compare graphics settings and inspect stutters.

![why: what's holding the frame rate back, and the stutters of the last minute](changelog/v1.0.5/in-game-console/console-why.jpg)

<details>
<summary>Explore this change</summary>

Press the key under Esc (` or ~) for a console. Type why and it works out what's holding your frame rate back; bench measures what each graphics setting costs you; graph shows every frame and its stutters.

- **`why`** looks at the last few seconds and says what's limiting you: your screen's refresh rate, the graphics
  card, or the processor, and which part of the game takes the most. It also flags stutters, a flood of engine
  errors, an integrated graphics chip and a slow connection to the host.
- **`bench`** turns each graphics setting down in turn (shadows, ambient occlusion, grass, water, render scale and
  more), times it, and lists what each one saves, the most first. It puts your settings back when it's done.
  `bench quick` is faster.
- **`graph`** pins a frame-time graph to the screen; **`hitches`** lists the latest stutters and what each one
  was; **`top`** shows the costliest parts of the game.
- **`render`**, **`sys`**, **`net`** and **`errors`** show what's being drawn, your computer, your connection and
  anything the engine has complained about.
- **`set shadows off`**, **`preset low`** and the like change settings on the spot; **`perf 3`** brings up the
  full performance overlay.
- **`report`** writes all of it to a file and copies it to the clipboard, ready to paste to whoever is helping.
- Tab completes, Up and Down bring back what you typed, Esc closes it. The key can be changed in Settings >
  Controls.
- The compact performance overlay (F3) no longer draws its GPU bar over its first line, or its last line
  below the panel.

![graph: every frame of the last few seconds, split into what its time went on, stutters marked in red](changelog/v1.0.5/in-game-console/frame-graph.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/in-game-console/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/in-game-console/layout-after.jpg)

</details>

#### Installers for Windows and the Mac

Install Frontline with a Windows setup wizard or Mac disk image, in a location that supports updates.

![The Windows installer: no administrator rights needed](changelog/v1.0.5/installers/windows-setup.jpg)

<details>
<summary>Explore this change</summary>

The game now comes with an installer on Windows and a disk image on the Mac, so it lands where it can keep itself up to date, with a shortcut to start it from.

- **Windows:** the download is a setup wizard. It needs no administrator rights, puts Frontline in your Start menu
  (and on the desktop, if you like), and uninstalls from Settings > Apps.
- **Mac:** the download is a disk image: open it and drag Frontline into Applications.
- Either way the game goes where it can update itself. On Windows the website's Join buttons work straight away,
  before you've even started the game.
- The zips are still there, a link under each download button, to run the game from anywhere without installing it.
  Linux keeps its zip.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/installers/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/installers/layout-after.jpg)

</details>

### Improved

#### Boats handle like boats

Boats carry momentum, slide through turns and use reverse thrust to stop instead of braking like cars.

[Watch: An RHIB turns toward the beach, trailing a curved wake as it comes ashore. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.5) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.5/boats-handle-like-boats/boat-turn.mp4))

<details>
<summary>Explore this change</summary>

Boats no longer drive like cars on water. They slide through it, skid in a hard turn, have no brakes, answer the helm after a moment and are carried by a river's current, and their coxswains handle them like it.

- **No brakes:** a boat slows on the water's drag and goes astern to stop. An RHIB at full speed needs some
  40 m to stop, a patrol ship 60 m and more, so they ease off well before where they're going.
- **Skidding:** in a hard turn a boat slides, her bow pointing inside the turn and her stern swinging out,
  and loses speed doing it. At speed she can't turn as tight as she can going slow.
- **Steering needs water past the rudder:** a boat stopped turns by going ahead on her engines, and going
  astern she hardly steers.
- **A moment to answer:** engines and helm take a moment, a patrol ship a long one, so her coxswain puts the
  helm over early and meets her with opposite helm as she comes round.
- **Rivers have a current:** it runs south, fastest in mid-stream, and carries a boat with it.
- **The Gun Trawler** is a deep, slow fishing hull: the slowest to answer, the widest turner, and she heels
  out of a turn where the speedboats bank into it.
- **Fighting on the move:** on an attack a boat keeps going at a steady speed instead of stopping dead to shoot,
  and only lies to to fight it out with an enemy that's dropped astern of her.
- **Coming about:** an RHIB with its beach just behind it spins round and runs in bow first.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/boats-handle-like-boats/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/boats-handle-like-boats/layout-after.jpg)

</details>

#### Wildlife caught in the fighting

Wildlife flees nearby danger and can be caught in the fighting without changing combat outcomes.

![Fish stunned by a shell in the water, floating up belly-up](changelog/v1.0.5/wildlife-in-the-fighting/stunned-fish.jpg)

<details>
<summary>Explore this change</summary>

The animals run from more of the battle now, and can be killed by it: a round through a flock or a shell among them brings them down in a puff of blood and feathers. It's only for the eye, so a round that hits a bird flies on exactly as it would have.

- **They can be killed:** a round through a bird, a rat, a hare or a dolphin, or into the water right over a
  fish, kills it in a puff of blood (and feathers, from a bird), and a shell kills whatever is close and throws
  it. Birds tumble out of the air and the dead lie on their sides where they fell, then are cleared away out of
  sight after a while. Fish stunned by a shell in the water float up belly-up.
- **Only for the eye:** none of it touches the battle. A round that hits a bird flies on as it would have, and
  each player's game has animals of its own.
- **They run from more:** rounds cracking past or striking nearby, a grass fire (they keep clear while it burns),
  a tree coming down, a helicopter flying low, and one of their own killed. Crows, gulls and bats now make off
  instead of circling on, and a fright spreads: when one flock goes up, the flocks feeding nearby follow.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/wildlife-in-the-fighting/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/wildlife-in-the-fighting/layout-after.jpg)

</details>

### Fixed

#### A rare crash at the start of a battle

A rare crash while preparing a battlefield's routes has been fixed.

<details>
<summary>Explore this change</summary>

Starting a battle could, once in a long while, crash the game while it worked out the routes across the map. It no longer can.

- The crash came while the loading screen read "Plotting the routes", in the first battle after starting the game.
- The same fault could, even more rarely, crash the game as it started up and made its sounds.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/battle-start-crash/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/battle-start-crash/layout-after.jpg)

</details>

#### Big ships come about without running aground

Large boats use the space available to turn, rejoin their route and back away from the shore.

<details>
<summary>Explore this change</summary>

A patrol ship sent somewhere astern now turns the way it has room for and joins its route further on, instead of circling back to where it started and running up the beach. A boat that touches the shore backs off it.

- A patrol ship (or a gun trawler) needs a lot of water to turn round. Sent somewhere behind it, it used to come
  round, then turn back for the start of its route next to where it had begun, go round again and end up on
  the beach. Now it picks its route up further on once it's round, and reaches where it was sent.
- It comes about towards where it's going, and if the shore is in the way on that side, it turns the other way,
  out to sea.
- It backs into a spot not far behind it instead of swinging out in a wide loop.
- A boat that runs onto a bank or beach goes astern off it, swings its bow round and carries on, instead of
  sitting on the sand. Sent somewhere close in by the shore, it settles as near as it can get instead of
  backing off and trying again for ever.
- Where its route rounds a point of land, a boat no longer cuts the corner over it.
- A boat steering round another one standing in its way now keeps to the open water side.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/big-ships-come-about/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/big-ships-come-about/layout-after.jpg)

</details>

#### No more crash when an attack outlasts a squad it lost

An attack continues safely when one of its squads is wiped out, instead of crashing later.

<details>
<summary>Explore this change</summary>

A battle could crash when a squad was wiped out partway through a planned attack and the attack dragged on for minutes after. The lost squad now drops out of the attack the moment it's gone.

- The rest of the attack carries on exactly as before. When it ends, only the squads still in the field get their new orders.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/lost-squad-crash/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/lost-squad-crash/layout-after.jpg)

</details>

#### Roads no longer show through smoke and explosions

Smoke, flames and blast dust now cover roads naturally instead of leaving sharp road-shaped gaps.

![Before and after: shells bursting at a crossroads in town](changelog/v1.0.5/roads-under-smoke/before-after.jpg)

<details>
<summary>Explore this change</summary>

Smoke, flames and dust from a blast on or near a road now cover the road like the ground around it, instead of the road showing through them in hard-edged strips.

- Smoke drifting over a road no longer stops in a sharp line at the road's edges.
- Flames on a road now burn over the whole road, not just over the stripes of a zebra crossing.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/roads-under-smoke/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/roads-under-smoke/layout-after.jpg)

</details>

#### The website opens the game on Windows, and signing in says what's happening

Website launch and join links reach Frontline on Windows, and sign-in shows its progress clearly.

![Signing in from the game: the steps, and the one you're on](changelog/v1.0.5/website-links-on-windows/game-sign-in.jpg)

<details>
<summary>Explore this change</summary>

On Windows the website's Launch, Join and Find Match buttons, and its sign-in for the game, never reached the game: it couldn't set itself up to take them. Now it can, and signing in from the game shows each step as it goes.

- **Fixed:** on Windows, the game never managed to set itself up to open the website's links, so Launch Frontline,
  Join, Find Match and the sign-in handed back from the website did nothing. Start the game once after it updates
  and they all work.
- **Signing in from the game** lists the steps (sign in with GitHub on the website, let your browser open
  Frontline, the game signs in) and shows which one you're on, with a line that keeps moving while it waits for the
  website. When the website hands the sign-in back it says it's signing in; if something went wrong it says what,
  with a Try again button.
- **On the website**, after you sign in for the game it shows the two steps, and whether your browser opened the
  game. If it didn't, it says what to do, with a button to open it again.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.5/website-links-on-windows/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.5/website-links-on-windows/layout-after.jpg)

</details>

## v1.0.4: Touchups

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.4)

### Improved

#### Scenarios and battles start sooner

Scenarios and battles become ready sooner by reusing route calculations across similar ground.

<details>
<summary>Explore this change</summary>

Working out the routes across a new battlefield now takes about half the time and far less of your processor, so a scenario is ready in about half the time and a full battle a second or so sooner.

- **Why:** most of a battlefield is open ground much like the rest of it. The way across each patch is now worked
  out once for every patch that's just the same, instead of for each in turn.
- **What didn't change:** the routes. Soldiers and vehicles go exactly the way they did before, and a replayed battle
  plays out the same.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.4/sooner-battle-start/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.4/sooner-battle-start/layout-after.jpg)

</details>

#### Signing in on the website, in one click

Sign in from any website page, then go straight to your profile and record.

![Sign in opens over the page you're on](changelog/v1.0.4/website-sign-in-and-pages/sign-in.jpg)

<details>
<summary>Explore this change</summary>

Sign in, in the website's header, opens a sign-in window over whatever page you're on, and once you're in it takes you to your profile. The front page is about the game now; ranks have a page of their own.

- **Sign in** in the header opens a sign-in window right where you are: no scrolling down the page to find it.
- Back from GitHub, the window says it's signing you in, then takes you to **your profile**: your rank, your record,
  your callsign and your insignia. If GitHub didn't sign you in, it says why, with the button to try again.
- The front page shows the game off. The live battles, the ranks and insignia, the downloads and your profile each
  have a page of their own, in the header.
- Old links still work: the game's Download button goes to the downloads, and `/account` to your profile.

![The ranks and every insignia, on a page of their own](changelog/v1.0.4/website-sign-in-and-pages/ranks.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.4/website-sign-in-and-pages/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.4/website-sign-in-and-pages/layout-after.jpg)

</details>

### Fixed

#### Splashes leave rings of foam again

Water impacts and sinking boats leave spreading foam instead of flat square artifacts.

![Before and after: a shell's splash in the sea](changelog/v1.0.4/foam-rings/before-after.jpg)

<details>
<summary>Explore this change</summary>

A shell landing in the water, a boat going down and rounds hitting the sea leave rings and boils of foam on the water again, instead of flat white squares that turned blue as the swell rolled over them.

- A shell bursting in the water throws up its column and leaves a ring of foam running outward and breaking up,
  with white water boiling where the column fell back.
- A sinking boat churns the water white as she goes down, and leaves a slick of oil spreading where she sank.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.4/foam-rings/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.4/foam-rings/layout-after.jpg)

</details>

## v1.0.3: Just a little more

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.3)

### New

#### Wildlife: birds, rats, hares, fish, ducks and dolphins

Birds, land animals and marine life inhabit the battlefield and react to nearby fighting.

[Watch: Fish swim together beneath the river surface. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.3) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.3/wildlife/fish-swimming.webm))

<details>
<summary>Explore this change</summary>

The battlefield has life of its own now. Birds feed in the fields and burst up at gunfire, crows and gulls wheel overhead, rats run along the walls in town, fish jump in the rivers, ducks paddle on the ponds and dolphins roll through the swell offshore. Settings > Graphics > Wildlife turns it down, or off.

- **In the fields:** flocks of sparrows and starlings feed on the tracks, yards and mud, hopping and pecking, and
  move on now and then. Pigeons gather about the town. Hares sit out in the grass and graze.
- **Overhead:** crows and buzzards turn circles in the sky, gulls along the coast, and their shadows sweep over
  the ground. At night bats flit about low down instead.
- **In the water:** fish swim under the surface of the rivers and ponds and now and then jump, ducks paddle about
  and upend to feed, and out at sea a pod of dolphins rolls up through the surface to breathe, one sometimes
  leaping clear.
- **They take fright:** a burst of fire or a shell landing sends the birds up all at once with a rush of wings,
  and soldiers and vehicles coming near flush them too. Rats bolt for a hole in the nearest wall, hares zigzag
  away across the field, fish dart off and ducks take to the air. Animals only react to the troops you can see,
  so they never give away a hidden enemy.
- **You can hear them:** birdsong, a pigeon's coo, crows and gulls calling, the rush of a flock going up, a rat's
  squeak and the splash of a jumping fish, on the ambience volume.
- **The time of day matters:** small birds and the soaring ones roost at night, when more rats come out. Fewer
  birds fly in the rain.
- **It costs little and is yours to set:** only the area round your camera is alive, so a bigger map costs no
  more. **Settings > Graphics > Wildlife** sets it to Plenty, Some or Off, and the quality presets choose for you
  (Off on Low, Some on Medium, Plenty on High and Ultra).

![Mallards on a pond, one upending to feed](changelog/v1.0.3/wildlife/ducks.jpg)

[Watch: Dolphins surface and leap through the ocean swell. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.3) ([Direct WEBM](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.3/wildlife/dolphin-leap.webm))

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.3/wildlife/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.3/wildlife/layout-after.jpg)

</details>

### Improved

#### The website gets a Play button, and a page for your account

Launch the game, browse live battles and manage your account from dedicated website pages.

![Play: launch the game, find a match, or download it](changelog/v1.0.3/website-pages/play.jpg)

<details>
<summary>Explore this change</summary>

The Frontline website is more than one long page now: Play opens the game on your computer (or gets it for you), the live battles have a page of their own, and your account page is where you rename yourself and pick your insignia.

- **Play**, at the top of every page, opens the game you have installed, or Find Match straight away. If nothing opens, the page tells you how to get the game going the first time.
- **Live battles** have their own page, and the header says how many are on. A friend's invite link from the game opens it, with their battle at the top.
- **Your account** shows your rank and record, lets you change your callsign, and holds your insignia collection. The menu on your insignia in the header takes you there, or signs you out.
- On a phone, the site's links fold into a menu, and the Play page tells you the game needs a computer.

![Your account: your rank, your callsign and the insignia you wear](changelog/v1.0.3/website-pages/account.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.3/website-pages/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.3/website-pages/layout-after.jpg)

</details>

## v1.0.2: I don't even know

*17 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.2)

### New

#### Frontline on the Mac

Play Frontline on Apple silicon and Intel Macs, with multiplayer, updates and trackpad camera controls.

<details>
<summary>Explore this change</summary>

Frontline now comes for macOS too, on Apple silicon and Intel Macs: the whole game, multiplayer included, and it keeps itself up to date like the others. On a MacBook, the trackpad drives the camera.

- **Getting it:** download it from the website, unzip it and move Frontline into Applications, where it can update
  itself.
- **The first time:** Apple hasn't notarized the game yet, so macOS won't open it at first. Open System Settings >
  Privacy & Security and choose **Open Anyway**; after that it opens like any other app.
- **Join links** on the website open the Mac game too.
- **On a trackpad:** scroll with two fingers to drag the map, pinch to zoom, and hold Option to turn and tilt the view
  instead. Shift and two fingers turn what you're placing. On a Magic Mouse, **Settings > Interface > Two-finger
  scroll** makes scrolling zoom instead.
- Keys are named the Mac way: the Command key shows as **Cmd**.
- Needs macOS 13 or later on Apple silicon, or macOS 11 or later on an Intel Mac.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/mac-build/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/mac-build/layout-after.jpg)

</details>

#### Play in your browser

Play solo Frontline in your browser without installing the game; multiplayer remains on desktop.

![An AI battle in a browser tab](changelog/v1.0.2/play-in-a-browser/browser-battle.jpg)

<details>
<summary>Explore this change</summary>

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

![The menu in the browser: multiplayer points you to the desktop game](changelog/v1.0.2/play-in-a-browser/browser-menu.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/play-in-a-browser/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/play-in-a-browser/layout-after.jpg)

</details>

#### Sign in with GitHub

Use GitHub to create an account and sign into the game through the Frontline website.

![Sign in with GitHub sends you to the website, and waits for you there](changelog/v1.0.2/sign-in-with-github/sign-in.jpg)

<details>
<summary>Explore this change</summary>

Sign in with your GitHub account: the game opens the Frontline website, you sign in with GitHub there, and the game signs in by itself. The first time makes your account, named after you on GitHub.

- **Sign in with GitHub** (on the main menu, or at the end of a battle) opens the website. Sign in with GitHub there, let your browser open Frontline, and the game is signed in. You never type a password into the game.
- **Your first sign-in makes your account**, with your GitHub username as your callsign. Rename it in the game whenever you like.
- **The website has it too**: sign in there with GitHub to see your rank and pick your insignia.
- **The game and the website sign in separately**, so signing out of one leaves the other signed in.
- **Closed the game while you were signing in?** The website starts it again, signed in.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/sign-in-with-github/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/sign-in-with-github/layout-after.jpg)

</details>

### Improved

#### Smoother battles as the ground changes

Changing terrain causes less disruption as the host updates routes around new walls, damage and fire.

<details>
<summary>Explore this change</summary>

When walls go up, buildings come down or fires take hold, the host now updates the map soldiers and vehicles plan their routes on about ten times faster, so a big battle spends far less of each moment on it.

- **What changed:** every change to the ground used to cost the host several milliseconds of re-planning, on about
  a third of all of the game's updates in a big battle. It now redoes only what the change can reach: a fraction of
  a millisecond as a rule.
- **What didn't:** the routes. Soldiers and vehicles go exactly the way they did before, and a replayed battle plays
  out the same.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/faster-route-repairs/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/faster-route-repairs/layout-after.jpg)

</details>

#### Battles use less memory

Battles use less memory for route planning while units follow the same routes.

<details>
<summary>Explore this change</summary>

Route planning keeps much less of the map in memory at once, so a battle needs about 120 MB less. Units find exactly the same routes as before.

- A battle now takes about 120 MB less memory, which matters most in the browser, where a page can't use more than
  2 GB.
- Units take exactly the same routes as before.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/lighter-pathfinding/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/lighter-pathfinding/layout-after.jpg)

</details>

#### An ocean that swells, and a sea for every weather

Boats ride waves shaped by the weather, with water quality options for less powerful hardware.

[Watch: A patrol ship pitches and rolls as waves pass beneath it. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.2) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.2/ocean-swell/ocean-swell.mp4))

<details>
<summary>Explore this change</summary>

Real waves roll in off the sea now: a long swell crossed by the wind's chop, which boats ride. The weather sets the sea, from glassy at dawn to a storm in the rain, and a new Water quality setting keeps it quick on slower machines and in the browser.

- **Waves you can see:** a long swell rolls in off the open sea in sets, and the wind's own shorter waves run across it. The crests come up sharp and the troughs broad, and boats rise, pitch and roll on the same waves.
- **The weather sets the sea:** glassy at dawn, dusk and golden hour, a moderate sea by day, choppy under cloud, and a storm sea in the rain, with whitecaps tearing off the crests and streaks of foam down the wind.
- **The surf** now rises as it comes in over the shallows before it breaks on the beach.
- **Light on the shallows:** the ripples throw dancing light onto the sand under clear water.
- **In the browser,** the sun glitters on the water as it does on the desktop.
- **Water quality** (Settings > Graphics): Low skips the see-through water for speed, Medium is the full sea, High adds the light on the shallows and the wind's streaks, and Ultra a finer swell. The browser starts on Medium.

![The patrol ship riding a sunlit swell, the sun's glitter broken up along the waves](changelog/v1.0.2/ocean-swell/swell.jpg)

![A storm sea in the rain](changelog/v1.0.2/ocean-swell/storm.jpg)

![Glassy water at dawn](changelog/v1.0.2/ocean-swell/calm-dawn.jpg)

![Before and after: a sunny sea and an overcast one](changelog/v1.0.2/ocean-swell/before-after.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/ocean-swell/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/ocean-swell/layout-after.jpg)

</details>

#### Gunfire that looks like the real thing

Gunfire uses quicker flashes, finer tracers and more natural smoke to make the action easier to read.

![Rifles firing over a wall: before, every round threw up a big white cloud; now a tight flash that lights the wall and a quick puff of stone dust](changelog/v1.0.2/realistic-gunfire/rifles-before-after.jpg)

<details>
<summary>Explore this change</summary>

Muzzle flashes, tracers, bullet impacts and gun smoke are now sized and timed to life: small, quick, bright flashes, thin tracers that glow at night, and smoke that billows and shades itself instead of hanging in round puffs.

- **Muzzle flashes at real size:** a rifle's is a hand's breadth of flame, a .50's a forearm's, an autocannon's a
  man's height, each gone in a frame and split into petals by the flash hider (or thrown out sideways by a heavy
  gun's muzzle brake). Seen from high up they still twinkle, so you can tell who's firing.
- **Burning gas:** a shot's gas glows for an instant before it cools into a breath of smoke. A tank's gun throws
  out a fireball that rolls into a cloud hanging in front of it; rockets and mortars do the same at the tube.
- **Tracers** are thin, bright threads at night and fainter and shorter by day, as they really look.
- **Bullet impacts** are small and quick: a crown of dust and soil off the ground, a puff of stone dust and chips
  off a wall, a dry burst off sandbags, instead of the big bursts of before.
- **Smoke billows:** gun smoke and dust are shaded as clouds, lit on the sun's side and in their own shadow on the
  other, and no two come out round.

![A tank's main gun: a fireball of burning gas that rolls into smoke](changelog/v1.0.2/realistic-gunfire/tank-fireball.jpg)

![The smoke a tank's gun leaves: round puffs before, one billowing cloud now](changelog/v1.0.2/realistic-gunfire/tank-smoke-before-after.jpg)

![At night every shot lights up what's round it](changelog/v1.0.2/realistic-gunfire/night.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/realistic-gunfire/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/realistic-gunfire/layout-after.jpg)

</details>

#### A tactical survey map behind the menus

Menus sit over a calmer tactical map with labelled contours, heights and a numbered grid.

![The main menu in v1.0.0 (left) and now](changelog/v1.0.2/survey-map/before-and-after.jpg)

<details>
<summary>Explore this change</summary>

The living map behind the title, menu and loading screen is now a tactical survey sheet with lettered contours, spot heights and a numbered grid. It's calmer, the view pans slowly as clouds drift over, and now and then a burst of interference turns up a contact or a plan.

- **A survey sheet:** the map is drawn like a military survey of hill country seen from high up. Fine contours with a heavier index contour every fifth line, lettered with its height; spot heights on the summits; and the map grid numbered round the edges, with a ruler in the margins.
- **Calmer:** the lines are about as faint as the map on the splash screen, and the ground drifts at a quarter of its old speed, so it stays in the background.
- **The view pans:** the map slides slowly by as the view moves east, new ground is surveyed in from the right, and clouds drift over it, casting soft shadows.
- **It follows you:** instead of a hill rising under the cursor, the whole map leans a little after it. A click sends a faint ring across the map instead of a ripple.
- **The map at work:** every few seconds a burst of interference flashes across the map, and what it passes turns up for a few seconds: an enemy contact with its grid reference, a unit moving off along its track, or an axis of advance pencilled in to an objective.

![The main menu, after a survey has turned up a contact, a unit and an axis of advance](changelog/v1.0.2/survey-map/menu.jpg)

![A burst of interference crossing the map](changelog/v1.0.2/survey-map/interference.jpg)

![The title, just after the map wakes](changelog/v1.0.2/survey-map/title.jpg)

![The loading screen](changelog/v1.0.2/survey-map/loading.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/survey-map/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/survey-map/layout-after.jpg)

</details>

### Fixed

#### Boats come about for a destination astern

Boats ordered behind themselves turn toward the destination instead of continuing the wrong way.

<details>
<summary>Explore this change</summary>

A boat sent somewhere straight behind it now turns round and goes there, instead of sailing off the other way with its men still aboard. Wheeled vehicles turn round sooner for a point behind them too.

- An RHIB, gunboat or patrol ship lying still and sent back the way its stern points could hold its course and keep
  going the wrong way for good, so a landing party never reached its beach. Now it puts the helm over and comes
  round, the enemy's boats as well as yours.
- Trucks, cars and other wheeled vehicles sent somewhere behind them turn round on full lock straight away, rather
  than rolling on ahead before they start to turn.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/boats-come-about/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/boats-come-about/layout-after.jpg)

</details>

#### The Field Manual opens over the account card

The Field Manual and Settings stay above the account card, keeping their controls accessible.

![The Field Manual from the menu, its search and Close button in the clear](changelog/v1.0.2/field-manual-on-top/field-manual.jpg)

<details>
<summary>Explore this change</summary>

Opened from the menu, the Field Manual and Settings now cover everything behind them, so the account card no longer hides the manual's side filter, search and Close button.

- The account card and the menu's notices sat on top of the Field Manual and Settings when they were open from the
  main menu. Both now come to the front as they open (a join invitation still shows over them).

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.2/field-manual-on-top/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.2/field-manual-on-top/layout-after.jpg)

</details>

## v1.0.1: Tons of stuff 2

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.1)

### New

#### Ranks and insignia

Earn experience in signed-in battles, climb 50 ranks and unlock patches for your callsign.

![Your insignia: the patches you've unlocked, and the ones still to come](changelog/v1.0.1/ranks-and-insignia/collection.jpg)

<details>
<summary>Explore this change</summary>

Sign in and every battle you fight earns XP. Climb 50 ranks from Recruit to General of the Army, and each one unlocks a military patch to wear beside your callsign.

- **XP:** every battle you fight while signed in counts, the longer the better, and a win is worth half as much again. Leaving early still earns half. Battles under two minutes, and battles you only watch, don't count.
- **50 ranks:** Private, Corporal, Sergeant, Staff Sergeant, Master Sergeant, Lieutenant, Captain, Major and Colonel, five grades each, then the five grades of general. The first comes in a battle or two.
- **Insignia:** you start with ten patches, one for each branch of the army, and every rank adds its own, from subdued training patches up to the generals' gold stars. Another 100 are on show but locked for now: medals, badges, ribbons, and company patches in the style of the Vietnam war.
- **Wear one:** click the patch on the account card at the top right of the main menu to open your collection and pick one. Players in the lobby see it beside your name, and the after-action report shows what each battle earned.
- **On the website:** the Insignia section shows the same collection, and lets you pick your insignia there too.

![A promotion in the after-action report, and the patch that comes with it](changelog/v1.0.1/ranks-and-insignia/promotion.jpg)

![All 160: starter and rank patches, then the awards and unit patches still locked](changelog/v1.0.1/ranks-and-insignia/all-insignia.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.1/ranks-and-insignia/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.1/ranks-and-insignia/layout-after.jpg)

</details>

#### Error reports

Optional automatic error reports help developers diagnose failures and crashes.

![The switch, at the bottom of Settings > Interface](changelog/v1.0.1/error-reports/send-error-reports.jpg)

<details>
<summary>Explore this change</summary>

When something goes wrong in the game, or it crashes, it now tells the developers what failed and where, so it can be fixed. Nothing about you is sent, and Settings turns it off.

- **What's sent:** what went wrong and where in the game's code, the game's version, your operating system and
  graphics card, and whether you were in the menus or a battle.
- **What isn't:** your name, callsign, account, files or address. Paths on your computer are taken out before
  anything is sent.
- **Crashes** are sent the next time you start the game.
- **To turn it off:** Settings > Interface > Send error reports.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.1/error-reports/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.1/error-reports/layout-after.jpg)

</details>

#### Rejoin a battle you dropped out of

Return to your side and surviving force after a dropped connection, crash or accidental departure.

![Back on the main menu after dropping out: Rejoin gets you back into the battle](changelog/v1.0.1/rejoin-a-battle/rejoin-card.jpg)

<details>
<summary>Explore this change</summary>

Lost your connection, crashed or left by mistake? The main menu now offers Rejoin for as long as the battle lasts, and you're back on your side with whatever of your force is still fighting.

- **Rejoin from the main menu:** after a lost connection, a crash or Leave Battle, a card in the corner says whose battle you left and when, with **Rejoin**. It's still there after you restart the game, and **Forget** clears it.
- **Your own place back:** the same side and colour, and your squads and vehicles that are still fighting, including units you'd queued that came out while you were gone.
- **While you're away** your teammates command your forces, or the AI if nobody is left on your side. When you come back, an AI that was only standing in for you hands everything back.
- **Closed battles too:** a battle closed to new players, behind a password or with every seat taken still lets its own players back in, without asking for the password again.
- **In missions** you get your share of the force back.
- **One record for the whole battle:** the after-action report and your service record count what you did before and after you dropped out as one, and if the battle ended while you were away, you get its report when you rejoin.
- **After a crash** you can rejoin straight away: the host lets your old connection go as soon as you're back, instead of waiting a minute or more for it to time out.
- **HQ reserves** go to a commander who is still in the battle, not to one who has left.
- Playing online needs this version on every computer in the battle.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.1/rejoin-a-battle/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.1/rejoin-a-battle/layout-after.jpg)

</details>

#### A server browser, and a lobby that shows who's coming

Browse online and local battles, then see teams, available seats and player readiness before starting.

![Joining a battle and the lobby, before and after](changelog/v1.0.1/server-browser/before-and-after.jpg)

<details>
<summary>Explore this change</summary>

Find any battle being hosted, online or on your own network, in a proper server browser. Hosting sets up co-op, versus or a mission (with a password if you like), and the lobby shows who's on which side, the seats left, who's connecting and who's ready.

- **Server Browser** (it replaces Join Game) lists every battle being hosted: its name, host, mode (and side or
  mission), players and seats, whether it's waiting in the lobby or already running, and how good the connection
  should be. Search it, filter it, sort it by any column; it keeps itself up to date. Double-click a battle to join.
- **Battles on your own network** show up there too, marked LAN, even with no internet.
- **Host a Battle** (it replaces Host Multiplayer): pick co-op against the AI, versus, or a mission; your side; how
  many seats; the time of day; and who can join: anyone, friends with a password, or only your network.
- **Host Co-op on a mission** now lists it in the server browser, so friends can find it without your IP address.
- **The lobby** shows both sides with every player, where the AI will play, the open seats, anyone still connecting,
  and who's ready. Players press Ready; the host can change the settings, remove a player and start when they like.
  You hear a chime when someone arrives, and the taskbar flashes if the game is in the background.
- **Copy invite link** in the lobby gives a link to send a friend: it opens the battle on the website, and Join
  there starts the game and brings them in.
- **Joining shows each step** as it happens, asks for the password if there is one, and says plainly what went wrong
  if it can't get in.
- Players with the same name get a number, so two "Commander"s can tell themselves apart.

![The server browser: every battle being hosted, with its mode, players, status and connection](changelog/v1.0.1/server-browser/browser.jpg)

![Hosting: co-op against the AI, versus or a mission, and who can join](changelog/v1.0.1/server-browser/host.jpg)

![The lobby: both sides, the seats still open, who's ready, and an invite link](changelog/v1.0.1/server-browser/lobby.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.1/server-browser/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.1/server-browser/layout-after.jpg)

</details>

### Improved

#### Battles and the game start sooner

Spend less time waiting for the game to launch and for the host to prepare a battle.

<details>
<summary>Explore this change</summary>

The host lays out a new battle about a second faster, and the game is ready about half a second sooner after you launch it.

- **New battles:** the routes soldiers and vehicles plan across the map are now worked out on all of your
  processor's cores at once, instead of one.
- **Launching the game:** its sounds are made in the background while the menu comes up, instead of holding it up.
  Each sound is now the same every time you play.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.1/faster-start/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.1/faster-start/layout-after.jpg)

</details>

## v1.0.0: Tons of stuff

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v1.0.0)

### New

#### Battle statistics and the after-action report

Review the battle at a glance, then explore commanders, units and the moments that changed the fight.

![The end of a battle: the result, and your rating](changelog/v1.0.0/after-action-report/victory.jpg)

<details>
<summary>Explore this change</summary>

Hold Tab for your side's figures as the battle goes. When it ends, the result slams onto the screen, your rating fills its bar, and the after-action report shows the whole battle: both sides head to head, every commander rated, every unit, and how the fight swung.

- **Hold Tab** for the battle statistics; a tap still opens the tactical map. **Esc > Battle Statistics** keeps them open. Until the battle is over, the enemy's figures are classified.
- **The end of a battle** greys out the battlefield behind a banner: VICTORY or DEFEAT lands with a hit, your rating fills its bar, and the report rises into place. Click to skip.
- **Summary:** the two sides head to head on kills, losses, vehicles, buildings, the value of what each destroyed, accuracy, prisoners, FOBs and towns taken, wounded saved and supply; honours such as Most valuable, Marksman and Tank hunter; and the soldiers with the most kills.
- **Commanders:** every player and AI gets a rating out of 100, mostly what they destroyed against what they lost, then their marksmanship and their share of the fight. Click one to see how it was made, and everything they did.
- **Units:** every squad and vehicle with its kills, losses, men still standing, time in action and fate.
- **Timeline:** men, vehicles, kills and supply over the whole battle, with FOBs, towns, vehicles lost and fire missions marked. Hover for the figures at any moment.
- Every tab comes in row by row: numbers count up, bars and dials fill, honours land one at a time, and the lines draw themselves.
- Kills go to whoever did them, fire support and mines included, even when a wounded man bleeds out later.

![The after-action report: head to head, honours and the soldiers who stood out](changelog/v1.0.0/after-action-report/report-summary.jpg)

![Every commander rated, and what the rating is made of](changelog/v1.0.0/after-action-report/report-commanders.jpg)

![How the battle swung](changelog/v1.0.0/after-action-report/report-timeline.jpg)

![Hold Tab in a battle for your side's figures so far](changelog/v1.0.0/after-action-report/battle-statistics.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/after-action-report/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/after-action-report/layout-after.jpg)

</details>

#### A changelog for every release

Find out what each release changes through notes on the website, linked from the game's update notice.

![An update downloaded and ready, with a link to what's in it](changelog/v1.0.0/changelog/whats-new.jpg)

<details>
<summary>Explore this change</summary>

Every release now comes with a changelog: what changed and why it matters, with screenshots. It's on the website, and the game's update notice links straight to it.

- **The website's new Changelog page** lists every release, newest first: its name, the date, a summary, and each change with its screenshots. The front page shows what's new in the latest.
- **What's new in the game:** the update notice has a button that opens the changelog for the version it's installing.
- **The release notes on GitHub** are the same changelog.
- **Updates check the Frontline server first** for the latest version, so the game, the website and the server always agree on what's current.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/changelog/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/changelog/layout-after.jpg)

</details>

#### Field defences rebuilt, and four new ones

Build more recognizable fieldworks, including new HESCO walls, barricades, camouflage nets and ammo caches.

![Wire, tank traps, minefields and concrete walls, before and after](changelog/v1.0.0/field-defences/before-and-after.jpg)

<details>
<summary>Explore this change</summary>

Sandbags, wire, tank traps, minefields, walls, nests, pits, bunkers and towers all look like the real thing now. New: HESCO walls, Rebel barricades, camouflage nets and ammo caches.

- **Sandbags** are stacked the way soldiers really lay them, and each side fills its own: tan and olive bags for the Coalition, hessian and white feed sacks for the Rebels.
- **Barbed wire** is now three coils of razor wire on steel pickets (wooden stakes for the Rebels). **Tank traps** are steel hedgehogs standing on three legs.
- **Minefields** are buried under loosened earth inside a taped cordon with red warning triangles. Only your own side ever sees them.
- **Concrete walls** are now rows of T-wall slabs. Mortar pits, AT posts, bunkers and watchtowers get proper weapons, bracing, ladders, roofs and earth banked against their walls.
- **New: HESCO barrier** (Coalition): earth-filled cells, chest high. Stand and fire over it. It stops even a .50 cal, and vehicles can't get through.
- **New: Barricade** (Rebels): drums, tyres, rubble and scrap, chest high. Stand and fire over it. A tank shoves it aside, and the tyres burn with thick black smoke.
- **New: Camouflage net** (both sides): put it over a gun pit, a mortar or a parked vehicle. Enemies on the ground or in the air have to come twice as close to spot what's under it. It doesn't stop bullets.
- **New: Ammo cache** (both sides): men within 7 m top up their rounds, grenades and rockets until it runs dry, and soldiers out of ammo head for it before the FOB. If it's destroyed, it explodes, and rounds keep going off for a few seconds.
- The computer opponent builds all four.

![Two new chest-high walls: the Coalition's HESCO barrier and the Rebels' barricade](changelog/v1.0.0/field-defences/hesco-and-barricade.jpg)

![A camouflage net over a parked car](changelog/v1.0.0/field-defences/camouflage-net.jpg)

![An ammo cache behind a minefield's marker tape, beside an MG nest](changelog/v1.0.0/field-defences/ammo-cache.jpg)

![MG and .50 cal nests](changelog/v1.0.0/field-defences/gun-nests.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/field-defences/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/field-defences/layout-after.jpg)

</details>

#### Change any key

Find and change any keyboard action, with two bindings per action and individual resets.

![Settings > Controls: every action by category, with two keys each](changelog/v1.0.0/rebindable-controls/controls.jpg)

<details>
<summary>Explore this change</summary>

Every key the game uses can now be changed in Settings > Controls: grouped by category, two keys per action, with a search box and a reset for each.

- **Every action, by category:** camera, saved views, orders, abilities and fire support, building, control groups, co-commanders, interface, and the observer's controls. The mouse's own controls are listed at the end.
- **Two keys for each**, including combinations with Ctrl, Shift or Alt, a modifier on its own, and the mouse's side buttons. Click a key and press the new one; Esc cancels, right-click clears it.
- **A key that's already taken** moves to the new action, the page says which action lost it, and Undo puts it back.
- **Search** for an action or a key, reset one action, or reset everything.
- **The hints follow your keys:** the command card, the controls help (F1), tooltips and the loading screen's tips all show the keys as you've set them.
- **Two new optional keys:** one to ping at the cursor (hold it for the ping wheel), and one to step through your co-commanders' views.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/rebindable-controls/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/rebindable-controls/layout-after.jpg)

</details>

#### Interface themes, and the living map in battle

Choose an interface palette that suits you, with matching menus and a tactical frame over the battlefield.

![Night Vision, Thermal, Arctic and Dusk](changelog/v1.0.0/interface-themes/themes.jpg)

<details>
<summary>Explore this change</summary>

Pick a theme for the whole interface in Settings > Interface: Field Brass, Night Vision, Thermal, Arctic or Dusk. Panels get a new tactical frame, and the living map now shows through behind the menus in a battle.

- **Five themes:** Field Brass (the original), Night Vision, Thermal, Arctic and Dusk. Each recolours the interface and the living map's contour lines; green, red and yellow still mean what they always did.
- **Changes live:** the interface recolours as soon as you pick a theme, and the map's colours flow into the new ones.
- **A tactical frame:** panels have accent brackets on their corners, like the crosses on the map's grid, and a faint glow. The button under the cursor glows too.
- **The map in battle:** the Esc menu, the help, the settings and the end of the battle sit over a see-through version of the living map, with the battlefield showing through. At the end of a battle a wave wakes it from the middle of the screen.

![The Esc menu in a battle, over the map (Night Vision)](changelog/v1.0.0/interface-themes/battle-menu.jpg)

![The end of a battle (Thermal)](changelog/v1.0.0/interface-themes/victory.jpg)

![Choosing a theme in Settings > Interface (Dusk)](changelog/v1.0.0/interface-themes/settings.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/interface-themes/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/interface-themes/layout-after.jpg)

</details>

#### A living map behind the title and menu

A moving topographic map brings the title, menus and loading screen to life.

![The title, just after the wave has woken the map](changelog/v1.0.0/living-map/title.jpg)

<details>
<summary>Explore this change</summary>

The title screen, the main menu and the loading screen now sit on a living topographic map: its ground slowly shifts, its contour lines glow in changing colours, and it reacts to your cursor.

- **The map moves:** hills slowly drift, merge and part, and the contour lines slide up and down the slopes.
- **The colours change:** the lines turn through brass, ember, rose, violet, blue and jade over a minute and a half, blending across the screen.
- **It follows you:** the ground rises in a hill under your cursor, and a click sends a ripple across the map.
- **The title comes alive:** it starts exactly as the splash screen looks, then a wave runs out of the emblem and wakes the map. The title lifts away and the menu glides in. Click or press a key to skip it.
- **The loading screen:** a survey beam sweeps the map and the view closes in on the ground, then dives into it as the battle fades in.
- The menu's 3D gun position is gone; the map replaces it.

![The main menu, with a hill rising under the cursor](changelog/v1.0.0/living-map/menu.jpg)

![The loading screen, closing in on the ground](changelog/v1.0.0/living-map/loading.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/living-map/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/living-map/layout-after.jpg)

</details>

#### A service record, and a sign-in you can find

Sign in from the main menu to keep a battle history and reopen past after-action reports.

![The account card on the main menu](changelog/v1.0.0/service-record/account-card.jpg)

<details>
<summary>Explore this change</summary>

Sign in from the account card at the top right of the main menu. Signed in, every battle you fight goes on your service record, and you can open any of their after-action reports again.

- **Signing in** is now at the top right of the main menu, with **Create account** beside it. The end of a battle offers it too. You still don't need an account to play.
- **Your service record** keeps every battle you fight as a commander: what it was, your side, the result and length, your rating, kills and losses.
- **Service Record** on the main menu shows your career (battles, wins, kills, K/D, average rating and time in battle) and every battle, newest first. Click one for its after-action report.
- **Battles fought signed out** or offline wait on your computer (the last ten) and go on your record when you sign in.

![Your service record: your career, and every battle](changelog/v1.0.0/service-record/service-record.jpg)

![Any battle's after-action report, opened again](changelog/v1.0.0/service-record/past-report.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/service-record/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/service-record/layout-after.jpg)

</details>

### Improved

#### Gunfire that hits hard

Read a firefight through muzzle flashes, recoil, tracers and impacts that respond to the surface they hit.

![A tank and an IFV firing at night: the flashes light up the vehicles and the ground, and the shell's tracer streaks to its target](changelog/v1.0.0/gunfire-effects/night-armour.jpg)

<details>
<summary>Explore this change</summary>

Muzzle flashes, tracers, recoil and bullet impacts are rebuilt from scratch: every shot flashes and kicks, tracers glow in each side's colour, and what a round hits decides what flies off it.

- **Muzzle flashes:** a white-hot burst with a tongue of flame thrown out ahead, bigger for a machine gun and bigger
  again for a .50 or an autocannon. Each one lights up its surroundings for a moment, which is striking at night,
  and leaves a breath of smoke. Spent cases spin out of the rifle and pile up round a machine gun.
- **Recoil on every shot:** rifles kick back into the shoulder and the muzzle climbs, mounted guns jump on their
  mounts, and a tank's turret jolts back when the main gun fires.
- **Tracers** glow red for the Coalition and green for the Rebels, and stay visible however far out you zoom.
- **Impacts depend on what's hit:** earth spurts up with clods raining down, stone walls throw grit and chips,
  sandbags burst into dust, wood splinters, hedges and trees shed leaves, steel throws sparks, and water throws up
  a white splash. The impact shows when the round arrives, and now and then a round ricochets off and goes
  whining away.
- **Tank guns** fire with a blinding flash, a fireball, burning flecks, a rolling cloud of smoke and dust blasted
  off the ground. **Rockets** kick up a back-blast behind the launcher.
- Heavy firefights run about as fast as they did before.

![A tank's main gun by day](changelog/v1.0.0/gunfire-effects/tank-gun.jpg)

![Rounds landing in a field: earth spurting up, grit flying, dust hanging](changelog/v1.0.0/gunfire-effects/rounds-landing.jpg)

![The same moment before and after](changelog/v1.0.0/gunfire-effects/before-after-night.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/gunfire-effects/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/gunfire-effects/layout-after.jpg)

</details>

#### Water that looks like water, and sea battles to match

Fight across rolling water with breaking surf, boat wakes and vessels that visibly sink when destroyed.

[Watch: A burning boat settles into the sea as foam spreads around its hull. Recorded in the current build, October 2026.](https://web-production-5a4c1.up.railway.app/changelog/#v1.0.0) ([Direct MP4](https://raw.githubusercontent.com/Dynasty9/Frontline/main/changelog/v1.0.0/water-and-sea-battles/boat-sinking.mp4))

<details>
<summary>Explore this change</summary>

The sea rolls in and breaks on the beach, you can see the sand through the shallows, and boats leave real wakes. A boat that's sunk now goes down burning and leaves an oil slick, instead of just vanishing.

- **The sea:** a swell rolls in off the open sea, and boats rise and roll on the waves you see. Breakers spill along the beach, run up the sand and drain back, leaving it dark and wet.
- **See into the water:** sand shows through the shallows and the sea turns turquoise, then deep blue farther out. Rivers and ponds are murky.
- **Light on the water:** the sky and clouds reflect in it, the sun glitters off the ripples (a moon path at night, only a sheen under cloud), and rain dimples it with rings.
- **Wakes:** boats churn up white water astern and push a bow wave out in a V; fast boats throw spray. A boat hidden in the fog of war hides her wake too.
- **Sinking:** a boat that's sunk blows up, lists over and goes down by the bow or the stern, burning until the water closes over the fire. Foam boils up where she went, and an oil slick spreads with wreckage drifting in it.
- **Fire on the water:** shells throw up a column of spray and leave a ring of foam, bullets kick up white spouts, and a shell that hits a boat bursts in flame instead of a splash.

![Gunboats off the beach: their wakes, the swell, and the shallows going from turquoise to deep blue](changelog/v1.0.0/water-and-sea-battles/sea-battle.jpg)

![The patrol ship lying off the beach while a boat burns in the surf](changelog/v1.0.0/water-and-sea-battles/patrol-ship.jpg)

![The harbour: clear shallows over the sand, surf running up the beach](changelog/v1.0.0/water-and-sea-battles/harbour.jpg)

![Before and after: the harbour and the river](changelog/v1.0.0/water-and-sea-battles/before-after.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/water-and-sea-battles/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/water-and-sea-battles/layout-after.jpg)

</details>

#### Towns in the help and loading tips

Learn how towns are captured and supplied through in-game help and loading tips.

<details>
<summary>Explore this change</summary>

The in-game help (F1) now explains towns: how to take one, what holding it gives you, and that you can click a dump for its details.

- **F1 help:** a new Towns line covers taking a town, what it gives you, and clicking its dump. The Supply line points at the income shown in the top bar.
- **Loading screen:** two new tips point new players at the villages, and warn that a town shelled to ruins gives far less.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/towns-in-help/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/towns-in-help/layout-after.jpg)

</details>

### Fixed

#### No network error when more players join

Additional players can join a multiplayer battle without triggering network errors for everyone else.

<details>
<summary>Explore this change</summary>

In a battle with three or more players, everyone else's game reported a network error each time another player joined. It no longer does.

- **More players:** a third or later player joining no longer sets off an error on the other players' games.
- **Long map builds:** every player's connection to the host still waits patiently while the host lays out the map,
  so nobody is dropped before the battle starts.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v1.0.0/joins-with-more-players/layout-before.jpg)

![After: new changelog layout](changelog/v1.0.0/joins-with-more-players/layout-after.jpg)

</details>

## v0.1.8: Co-commanders

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.8)

In co-op you can see what the other commanders on your side are doing: where they're looking, what they've selected and what they're about to order. Pings and map sketches let you talk without typing.

### New

#### See what your co-commanders are doing

See teammates' selections, attention and planned actions so you can coordinate attacks and fire support.

![Two commanders: one aiming artillery, one digging a trench line, with their views, pings and the Command Net](changelog/v0.1.8/co-commanders/co-commanders.jpg)

<details>
<summary>Explore this change</summary>

Each commander on your side gets a colour, and you see where they're looking, their cursor, what they control and what they're about to commit to, so two of you don't shell the same wood or storm the same house.

- **Where they're looking:** a viewfinder on the ground labelled with their name, a wedge on the minimap, and a marker at the edge of your screen when they're looking elsewhere. Click it to look there.
- **Their cursor**, with a tag saying what they're doing: "Digging a trench line", "Aiming 155 mm Artillery", "Ordering an attack".
- **What they control:** their name and colour in the order of battle, their initials on their units' symbols, and a ring round whatever they have selected.
- **What they're about to do:** the building they're placing, the line they're dragging out, or a fire mission's target area with a hazard sign.
- **The Command Net** (top right) lists each teammate's latest move, with buttons to look at their view or follow it live.
- When a teammate builds, calls in support, trains a unit or starts research, the rest of the side is told, so everyone knows where the shared supply went. Settings > Interface can turn all of this off.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.8/co-commanders/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.8/co-commanders/layout-after.jpg)

</details>

#### Pings and map sketches

Point out threats, request help and sketch plans directly on the shared battlefield and minimap.

<details>
<summary>Explore this change</summary>

Mark an enemy, a unit or a spot with a ping, pick a call from the ping wheel, or draw on the map for your side.

- **Ping:** Alt + click on the battlefield or the minimap. A ping on an enemy sticks to him while he's in sight.
- **Ping wheel:** hold Alt and the left button, then let go on attack, on my way, need support, danger, defend or look. "On my way" draws a line from your units to the spot.
- **Sketch:** Alt + right-drag draws a line your side can see, on the battlefield or the minimap.
- **Space** jumps to the newest alert or ping. Pings chime and go in the message log.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.8/pings/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.8/pings/layout-after.jpg)

</details>

## v0.1.7: Window Size

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.7)

The game opens at the window size you chose, and the squad card fits even at the largest interface scale.

### Fixed

#### The game opens at the window size you chose

Frontline opens at your chosen window size, or maximizes when that size will not fit your screen.

![A 4:3 screen at the default and largest scales](changelog/v0.1.7/window-size/four-three.jpg)

<details>
<summary>Explore this change</summary>

Settings > Display > Window size was saved but ignored at launch, so the game always opened small. Now it opens at your size, and maximises if that doesn't fit your screen.

- The window opens at the size you picked, so the interface (which follows the window) is the size you expect from the start.
- If the size doesn't fit your screen with its title bar, the window is maximised instead of being pushed off the top.

![An ultrawide screen at the largest scale](changelog/v0.1.7/window-size/ultrawide.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.7/window-size/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.7/window-size/layout-after.jpg)

</details>

#### The squad card fits a narrow panel

Attack stages and squad orders remain readable together at the largest interface scale.

<details>
<summary>Explore this change</summary>

At the largest interface scale, an attack's PLAN › MOVE › ASSAULT › SECURE steps were drawn over the squad's orders. Now they move to a line of their own when there's no room.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.7/squad-card/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.7/squad-card/layout-after.jpg)

</details>

## v0.1.6: Towns and Supply

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.6)

The town and every village now have a supply dump worth fighting for. Hold one and it sends trucks of supply to your nearest FOB; lose it and the enemy gets them.

### New

#### Capturable towns that give supply

Capture settlements to produce supplies, then protect the trucks bringing them back to your FOB.

![A village's supply dump, flying the holder's colours](changelog/v0.1.6/towns/village-dump.jpg)

<details>
<summary>Explore this change</summary>

Each village and the town has a named supply dump. Hold the ground round it and the place is yours: it produces supply, and its own truck drives it to your nearest FOB.

- **Eleven places to take:** the town and ten villages, each with a name. Nobody holds them at the start.
- **Taking one:** have men inside its ring with none of the enemy's. A squad takes a village in about 30 seconds and the town in about 50, faster with more men. With both sides inside, the capture freezes, and the holder is warned as soon as the enemy starts.
- **Supply:** a held village makes 24 a minute and the town 60. Shelled or burnt houses cut that. Whatever's in the dump changes hands with the town.
- **The town's truck** drives each load to your nearest FOB on a road of its own, which can be ambushed or blocked like any supply road. A destroyed truck loses its load.
- **More reasons to hold them:** you can build a FOB near a town you hold, your men refill ammunition at its dump, and it gives you sight around it. Prisoners can tell you about towns and their trucks.
- **The AI goes for them too:** it sends squads to take towns from the start, holds them, and counts enemy-held towns as targets.

![Selecting a dump: who holds it, its stock, and its truck](changelog/v0.1.6/towns/village-selected.jpg)

![The town square, before and after](changelog/v0.1.6/towns/town-square.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.6/towns/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.6/towns/layout-after.jpg)

</details>

### Improved

#### A clearer supply picture

See which towns support your force, how much they produce, and where their delivery trucks are going.

<details>
<summary>Explore this change</summary>

The top bar shows your income per minute and how many towns you hold, and the order of battle lists each town's stock, rate and truck.

- **Top bar:** income per minute beside your supply, and **TOWNS 3 / 11**.
- **Town lines** beside the FOB lines show each town's stock and rate and where its truck is going. A town being taken, or whose truck was destroyed or blocked, gets a red line of its own.
- **On the minimap** each town is a flag in its holder's colour inside its ring, and the ring fills with the colour of whoever is taking it.
- **On the battlefield** each town has a name plate, its ring is drawn on the ground when the camera is near, and a capture bar shows over the dump.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.6/supply-picture/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.6/supply-picture/layout-after.jpg)

</details>

## v0.1.5: Roaring Fires

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.5)

Fires roar and crackle instead of surging like surf, and many explosions at once no longer distort.

### Fixed

#### Fires roar instead of surging

Burning buildings produce a steady roar and crackle instead of a repeated swell and fade.

<details>
<summary>Explore this change</summary>

Burning buildings had the same rolling-surf sound the wind used to have. Now a fire is a steady roar with crackles on top.

- The roar sits in the middle of the range instead of a low rumble, at the same loudness as before.
- It loops without a dip or a jump.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.5/fire-sound/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.5/fire-sound/layout-after.jpg)

</details>

#### No more distortion when shells land together

Overlapping explosions no longer overload the sound output and distort.

<details>
<summary>Explore this change</summary>

When several explosions went off at once the sound could clip. A limiter on the master volume now holds it just under the top, and everyday levels are unchanged.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.5/explosion-clipping/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.5/explosion-clipping/layout-after.jpg)

</details>

## v0.1.4: Reconnaissance

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.4)

You can see what your side can see: the fog of war is drawn on the battlefield and the minimap. Aircraft spot as they fly, and recon flights, overwatch drones and manned watchtowers push the fog back.

### New

#### A fog of war you can see

See where your side has eyes on the ground and where enemy positions are only last-known reports.

![The fog of war in a bridgehead battle](changelog/v0.1.4/fog-of-war/fog-of-war.jpg)

<details>
<summary>Explore this change</summary>

Ground your side can't see right now is drawn darker on the battlefield and the minimap, so you know where your vision ends and where you need eyes.

- The edge is soft, aircraft overhead aren't darkened, and at night it's lighter because everything is dark already.
- **What you see darkened is exactly what's hidden from you:** enemies inside it don't show.
- **Last-known positions:** an enemy anyone on your side has seen stays marked where it was last seen for 90 seconds, with how long ago.
- The new eye button in the map layers turns the fog off.

![The same moment before: nothing showed where your vision ended](changelog/v0.1.4/fog-of-war/before.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.4/fog-of-war/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.4/fog-of-war/layout-after.jpg)

</details>

#### Aircraft that spot, recon flights and overwatch drones

Use aircraft and overwatch drones to reveal ground ahead of your troops.

![A recon pass lights a strip over the Rebel positions](changelog/v0.1.4/recon-flights/recon-pass.jpg)

<details>
<summary>Explore this change</summary>

Every aircraft now reveals the ground it flies over. New fire-support calls fly recon passes along a line you draw, or put a drone overhead to watch one spot.

- **Aircraft spot as they fly:** bomb runs, gun runs, gunships and armed drones all reveal what's around them. The minimap shows every aircraft.
- **Recon passes** (from minute two): the Coalition's A-149 Gryphon flies fast and high, the Rebels' Caesar spotter flies slow and low. Drag out a line; the strip they fly over stays lit for six seconds.
- **Overwatch drones** (from minute four): an unarmed drone circles a spot for about a minute and shows what's around it.
- **Watchtowers** see further, and further still with a lookout up them. Placing one shows its reach.
- **The Rebels get a drone too:** the AR-2 Tayran quadcopter, at the Helipad.
- The enemy is warned when a recon flight or overwatch drone comes over, and the AI calls recon flights before it attacks ground it can't see.

![The Caesar spotter plane](changelog/v0.1.4/recon-flights/spotter-plane.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.4/recon-flights/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.4/recon-flights/layout-after.jpg)

</details>

## v0.1.3: Soundtrack

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.3)

A synthesised orchestral soundtrack that follows the fighting, a volume slider for each kind of sound, and wind that sounds like wind.

### New

#### A soundtrack that follows the fighting

The score builds with the fighting, relaxes during quieter moments, and responds to victory or defeat.

<details>
<summary>Explore this change</summary>

Music, made in code like everything else: a theme for the menu, and a battle score that builds as the fighting heats up and eases off in the lulls.

- **Instruments:** strings, horns, a wordless choir, piano, timpani, a war drum and a snare, played through a concert-hall reverb.
- **The menu** has a two-minute theme in D minor.
- **In battle** the score comes in layers: strings and a few piano notes when it's calm; a low-strings pulse, drums and horns as the fighting grows. After a long stretch at full intensity it eases off, and in quiet spells it rests.
- **Victory and defeat** each get a short sting.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.3/soundtrack/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.3/soundtrack/layout-after.jpg)

</details>

### Improved

#### A volume slider for each kind of sound

Balance music, effects, ambience and interface sounds separately, or mute the game while it is in the background.

![Settings > Audio](changelog/v0.1.3/audio-settings/audio-settings.jpg)

<details>
<summary>Explore this change</summary>

Settings > Audio has separate sliders for music, effects, ambience and the interface, plus a switch for music in battle and one to mute the game in the background.

- **Master, Music, Effects, Ambience and Interface**, each on its own slider.
- **Music in battle** can be switched off while keeping the menu music.
- **Mute in the background** silences the game when you switch away.
- The sliders follow your ears: halfway sounds about half as loud.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.3/audio-settings/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.3/audio-settings/layout-after.jpg)

</details>

### Fixed

#### Wind that sounds like wind, not surf

Hear irregular gusts and distant fighting instead of a repeating surf-like ambience.

<details>
<summary>Explore this change</summary>

The ambience used to sound like waves breaking. Now it's rushing air with gusts that come and go, over far-off artillery and gunfire.

- The wind no longer swells and fades on a fixed four-second cycle, or gets louder as you zoom out.
- The distant battle is far-off thumps and bursts instead of a low rumble.
- Wind, rain and the distant battle loop without a seam.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.3/wind/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.3/wind/layout-after.jpg)

</details>

## v0.1.2: Fire and Smoke

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.2)

Things catch fire now: woods, hedgerows, timber roofs and wrecks burn and spread it downwind. Explosions and smoke are bigger and look the part.

### New

#### Fire that spreads

Fire spreads through nearby flammable scenery, with the wind influencing where it takes hold next.

![A hedgerow and a grass fire, with smoke drifting downwind](changelog/v0.1.2/fire/fire-day.jpg)

<details>
<summary>Explore this change</summary>

Shells, bombs and burning wrecks set things alight. Fires take hold, roar, spread to whatever will burn nearby (much more readily downwind), and burn themselves out.

- **What burns:** trees, hedges, crates, watchtowers, log dugouts, tents and plank huts, timber roofs and parked cars. Stone, brick, concrete, earth, sandbags and steel don't.
- **What sets it off:** blasts (a shell or bomb often, a grenade rarely), cars that have been badly shot up, and destroyed vehicles, which now burn where they died.
- **Grass fires:** a heavy round in long grass or undergrowth can start a ring of low flames creeping outward over blackened ground.
- **Spreading:** at full blaze a fire jumps to what's nearby, so a hedgerow or a wood can go up one tree after another.

![The same fires at night](changelog/v0.1.2/fire/fire-night.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.2/fire/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.2/fire/layout-after.jpg)

</details>

### Improved

#### Bigger explosions and smoke

See the force of an explosion in its fireball and debris, followed by a continuous column of drifting smoke.

![Explosions before and after](changelog/v0.1.2/explosions-and-smoke/before-and-after.jpg)

<details>
<summary>Explore this change</summary>

Explosions throw a proper fireball and debris, and smoke rises as one billowing column instead of a string of puffs.

- Fireballs last long enough to see, and the bigger the round, the bigger the blast.
- Smoke from fires and wrecks rises as a continuous column and drifts with the wind.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.2/explosions-and-smoke/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.2/explosions-and-smoke/layout-after.jpg)

</details>

## v0.1.1: Interface Scale

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.1)

The interface grows with your window, stays sharp at any size, and can go much bigger without panels running into each other.

### Improved

#### An interface that's big enough, and stays sharp

Make the interface larger without blurring text or pushing essential controls into one another.

![Before and after, at 1080p](changelog/v0.1.1/interface-scale/before-and-after.jpg)

<details>
<summary>Explore this change</summary>

Interface scale now follows the size of your window, text and symbols stay crisp at any scale, and it goes much bigger without the panels overlapping.

- **Follows the window:** at 100% the interface takes the same share of the screen at any resolution, so it's bigger at 1440p and 4K than before.
- **Sharp at any size:** text and map symbols are drawn at the scale they're shown, not stretched.
- **Goes bigger:** the slider reaches the largest scale your window has room for (2× at 1080p, 2.67× at 1440p).
- **No collisions:** the minimap, selection panel and command card make room for each other, and the Field Manual and observer bar stay on screen.
- It follows window resizes and fullscreen switches as they happen.

![The largest scale, with Settings open](changelog/v0.1.1/interface-scale/largest.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.1/interface-scale/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.1/interface-scale/layout-after.jpg)

</details>

## v0.1.0: First Release

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.0)

The first build you can download and play: the whole game as it stands, now with online play through Find Match, missions, camera controls from other RTS games, restyled soldiers, and a game that keeps itself up to date.

### New

#### Online play: Find Match and a list of battles

Find an open battle or host one for others to join, usually without configuring your router.

![Join Game: the battles being hosted, and connect by address](changelog/v0.1.0/online-play/join-a-battle.jpg)

<details>
<summary>Explore this change</summary>

Press Find Match to drop into an open battle, or host one for the next player to find. Join Game lists every battle being hosted, and most home routers need no setup.

- **Find Match** joins the best open battle (ones still in the lobby first, then the fullest). If there isn't one, it hosts a battle and lists it for others.
- **Join Game** shows every battle being hosted: its commander, how many are in it, and whether it's still in the lobby or already fighting.
- **No port forwarding for most players.** Your game and the host's are introduced to each other and connect directly; the game traffic never goes through a server. A few strict networks (some mobile and campus ones) can't be reached this way, and the lobby says so.
- **Join by address** still works for LAN and VPN games.
- **Accounts are optional.** Sign in beside your callsign and it's yours: no one else can register it, and battles you host show a tick.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/online-play/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/online-play/layout-after.jpg)

</details>

#### Missions

Play five objective-driven operations alone or with friends, with radio updates guiding the action.

![Kingpin, one of the missions](changelog/v0.1.0/missions/kingpin.jpg)

<details>
<summary>Explore this change</summary>

Five short operations with objectives and radio traffic, to play alone or in co-op.

- Each mission sets a side, a goal and a time of day, and ends in **Mission accomplished** or **Mission failed**.
- Play them alone, or host one for friends to join in co-op.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/missions/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/missions/layout-after.jpg)

</details>

#### The game keeps itself up to date

Get new versions in the background and restart when you are ready to play them.

![An update downloaded and ready](changelog/v0.1.0/self-updating/update-ready.jpg)

<details>
<summary>Explore this change</summary>

When a new version comes out, the game downloads it in the background, checks it, and asks you to restart. Quitting works too: the next launch is the new version.

- The menu shows the download's progress, then **Restart**.
- Every download is checked against the checksum published with the release before it's installed.
- If the game's folder can't be written to, it links to the download instead.
- The version you're running is shown at the bottom right of the menu.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/self-updating/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/self-updating/layout-after.jpg)

</details>

#### The Frontline website

Find live battles, join them in the game, and download Frontline from one website.

<details>
<summary>Explore this change</summary>

The battles being hosted right now, a Join button that opens the game and connects you, and the latest download.

- **Join from the browser:** click Join on any battle and the game opens (or the one you have open takes over) and connects you.
- **Downloads** for Windows and Linux, always the latest version.
- Start the game once after downloading, so your computer knows how to open the site's Join links.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/website/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/website/layout-after.jpg)

</details>

### Improved

#### Camera controls from other RTS games, and a clearer minimap

Keep your focus while zooming, orbit the battlefield, and use the whole minimap without buttons covering its edges.

![The new camera, tilted over a village](changelog/v0.1.0/camera-and-minimap/camera.jpg)

<details>
<summary>Explore this change</summary>

The mouse wheel zooms towards the cursor, middle-drag turns and tilts, and the minimap's edges aren't hidden under buttons any more.

- **Zoom toward the cursor:** whatever you aim at stays under the mouse.
- **Middle-drag** turns (left and right) and tilts (up and down). **Alt + middle-drag** grabs and drags the map.
- **Shift** pans faster, and panning eases in and out.
- **Backspace** (or the compass on the minimap) resets the view, **Ctrl + F** follows the selection, and **Ctrl + F5 to F8** save views that **F5 to F8** recall.
- Jumps to alerts, bases and groups glide instead of cutting.
- The minimap's buttons moved off the map, so its top row and right-hand column are visible.

![The minimap before and after](changelog/v0.1.0/camera-and-minimap/minimap.jpg)

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/camera-and-minimap/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/camera-and-minimap/layout-after.jpg)

</details>

#### Restyled soldiers

Recognize soldiers and their roles more easily from the battle camera, with clearer silhouettes and equipment.

<details>
<summary>Explore this change</summary>

Soldiers have a new look, after the early Metal Gear Solid games: chunkier, clearer silhouettes that read well from the battle camera.

- New proportions and gear for both sides, so riflemen, gunners and engineers are easier to tell apart at a glance.

</details>

<details>
<summary>Compare changelog layouts</summary>

Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it.

![Before: old changelog layout](changelog/v0.1.0/restyled-soldiers/layout-before.jpg)

![After: new changelog layout](changelog/v0.1.0/restyled-soldiers/layout-after.jpg)

</details>
