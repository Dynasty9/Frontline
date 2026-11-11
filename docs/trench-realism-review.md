# Trench realism review

Implemented in `codex/trench-realism`, in a separate worktree created from
`origin/main` at `a89bd759bee003ee208f65ad4b8e418158994254`.

Trenches now excavate in stages, retain unfinished work, acquire deeper cover,
follow the terrain and connect through ramps. Engineers reserve distinct work
stations and throw visible soil using the existing digging animation. Finished
sections include fire steps, duckboards and occasional recessed supply/rest bays.
Damage leaves a shallower, obstructed excavation which the repair order clears.
Troops yield in narrow passages and climb high lips more slowly.

The server derives excavation and collapse stages from replicated progress and
health, using the same quantization on both peers. Network version 13 prevents
old clients from drawing or colliding with the previous trench geometry.

## Evidence

[Matched before/after](../changelog/unreleased/trench-realism/comparison.jpg)
shows the same seed, camera and simulation time. Both full 1600x900 frames are
scaled to 1280x720 without cropping and stacked with short labels.
The baseline runs the exact commit above with only the external capture script
from this branch. It is an actual baseline render, not a reconstructed old look.

[Construction and repair](../changelog/unreleased/trench-realism/digging.mp4)
is a silent 30-second H.264 clip, 1280x720 at 10 fps, with a
[poster](../changelog/unreleased/trench-realism/digging.jpg).
Three real 30 Hz simulation ticks advance between saved frames. A three-person
engineer team receives the normal work order. At 18 seconds the fixture applies
90% damage and issues the normal repair order. It does not accelerate build rates.
The recording shows 52.6% construction at 6 seconds, completion by 15 seconds,
662.5/3000 HP during repair at 19 seconds and full repair by 30 seconds.
Opening, digging, completion, damage and repair frames were inspected; the
encoded video decodes without errors. Media totals approximately 4.2 MB.

Reproduce from the repository root with Godot 4.7.2 (console build on Windows),
using an absolute output prefix outside Git:

```sh
godot --path . --fixed-fps 30 --resolution 1600x900 --script tests/fixtures/environment-views.gd -- --scenario=trenches --seed=3 --offscreen --nohud --set=perf:0 --preset=high --mood=day --capture-set=trenches --capture-prefix=/absolute/scratch/network
godot --path . --fixed-fps 30 --resolution 1600x900 --script tests/fixtures/environment-views.gd -- --scenario=trenches --seed=3 --offscreen --nohud --set=perf:0 --preset=high --mood=day --capture-set=trench-build --capture-prefix=/absolute/scratch/digging
ffmpeg -framerate 10 -i /absolute/scratch/digging-frames/%04d.png -vf scale=1280:720 -c:v libx264 -crf 29 -pix_fmt yuv420p -movflags +faststart digging.mp4
```

For the baseline, copy the capture script outside both checkouts, then run that
absolute script path from the baseline checkout. The held view uses focus
`(0,-28)`, zoom 24, pitch -48 degrees and yaw 0.5 radians at simulation time 2 s.
Construction uses focus `(-90,80)`, zoom 13, pitch -38 and yaw 0.35.
Repeat the network capture with engine `--rendering-method gl_compatibility`.
Both Forward+ and Compatibility were inspected; the latter includes explicit
linear-to-sRGB conversion in the trench shaders.

## Validation

Build the native navigation extension before importing or running gameplay:

```sh
python tools/build_native.py
godot --headless --path . --import
node --test --test-concurrency=2 tests/*.test.mjs
python .github/scripts/changelog.py check
python tools/showcase/audit.py
```

The trench fixture covers partial/light and completed/heavy cover, interruption,
open ends, connections between different excavation stages, recessed bays,
persistent local collapse, repair, snapshot quantization, reliable completion,
work-station reservations including approaching crews, traffic yielding,
separation, elevated protection and floor geometry, gun-crew grounding and
shovel soil release/landing. Cached mesh depths are checked against gameplay
queries after damage, and occupants reassess changed cover heights. It also checks floor winding against the former
sky-visible hole.

A live local ENet host/client pair completed without script errors; the client
reported 3,557 entities (3,531 structures and 26 soldiers). Both peers used the
new protocol. This supplements the snapshot fixture; it does not establish
network-loss or late-join coverage during excavation.

## Limits

The first broad run lacked the native extension: 111 tests, 101 passed,
3 failed and 7 skipped. The route-graph test required that missing extension;
the original fallback defensive layout lost 7 of 16 defenders against a limit of 5.
Inspection located the losses at the flank emplacements. The scenario now extends
its protective trench line across both flanks; the fallback rerun passes the
unchanged casualty limit (30682.5619 ms). The scenario test checks the new extent.
The fallback breach scenario left one defender alive on both this branch and
unchanged origin/main. The initial failures are retained for provenance. The casualty limit is unchanged.
With native navigation the extended line loses one defender and turns back the
surviving tank at 564/1000 HP and z=-92.11. The updated scenario expectation
requires armour to be destroyed or damaged and withdrawn beyond the attack;
it no longer requires a retreating tank to lose at least half its health.

The native broad suite, before the final geometry-cache and defense-layout
changes, completed:

```text
111 tests; 104 passed; 0 failed; 7 skipped
Duration: 717592.1177 ms
```

The final focused terrain/trench rerun passed 3/3 (21604.7835 ms).
After the defense-layout update, native defense and trench-assault scenarios
passed 2/2 (68618.5861 ms).
Direct structure-index, terrain-update, placement, snapshot-index, terrain-cover
and structure-view regressions each report `failures=0`.
The final import has no script or parse errors. Changelog validation passes;
the presentation audit verifies 147 entries and all source hashes.
Full-suite results include deterministic replay and ENet authority checks.
The final geometry-cache changes are additionally covered by the focused rerun.


The seven default skips are opt-in blast/decal/crater rendering checks.
Long mission completion, browser exports, low-end GPU performance and an isolated
matched FPS benchmark were not run. Native Compatibility inspection is not a
WebGL browser test. There is no claim of a frame-rate improvement.
Baseline and changed off-screen capture processes both report existing resource
leak warnings on exit; the captures themselves complete.

## Rebuild cost

A serial A/B/B/A headless diagnostic rebuilt 40 six-metre sections five times
per process after one warm-up. The same external `trench-bench.gd` was used on
both revisions; this measures CPU mesh construction, not rendered frame rate.
The diagnostic is retained alongside the local logs in the worktree parent.

| Revision | Vertices | Median rebuild | Range (10 samples) |
| --- | ---: | ---: | ---: |
| origin/main baseline | 89,136 | 183.520 ms | 177.534-189.597 ms |
| Trench realism | 124,500 | 338.309 ms | 330.412-403.688 ms |

Caching shared samples and section connections removed the initial multi-second
rebuild cost. Rebuilding a large network still causes a noticeable main-thread
pause. The mesh is rebuilt on excavation/damage changes, not every frame;
chunking or amortizing rebuilds is future work if larger construction networks
make these pauses unacceptable. No FPS claim is inferred from this diagnostic.
