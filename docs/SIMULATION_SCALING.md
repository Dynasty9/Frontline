# Simulation scaling

## Implemented boundary

Desktop solo games use the existing authoritative Godot host in a separate,
private headless process. The visible process retains input, UI, interpolation,
models and effects. A random session token and protocol version protect the
loopback connection. Launch/readiness, pause/resume, reconnect ownership and exit
are managed by LocalServer. Public multiplayer retains the existing host flow;
web retains the in-process fallback. Protocol version is now 11, including the helicopter flight snapshot changes.

Rust accelerates numeric search: nearest-enemy candidate selection and abstract
navigation routes.
Once per tick the host supplies IDs, teams, positions and visibility factors to
PerceptionSearch. It returns at most seven candidates, ordered by distance and ID.
Godot still checks current lifecycle state, individual line of sight and weapons.
The GDScript implementation remains available for comparison or source checkouts
without the optional extension. RouteGraph skips degree-two intermediate search
states while preserving their two directional edge costs and reconstructed
waypoints. Terrain and danger changes update the same graph immediately. The
bindings run on the main thread; independent local-grid costing remains parallel.
Platforms without the extension use AStar3D. This is not a full Rust server rewrite.

## Work removed or bounded

- Map placement checks query spatial buckets instead of comparing every new
  object with every previously placed object. Exact overlap tests are retained.
- Static scenery replication uses a dirty set and a three-second rolling refresh;
  initial state is reliable and visibility reveals examine only unknown objects.
  Enemy supply and production remain private in initial properties and snapshots.
- Static scenery does not receive empty simulation calls; FOB queries use a
  maintained index with live team/completion/wreck filtering. Supply-truck
  management uses that same index; fog and commander queries use an owned-building
  index that follows capture, neutralisation and despawn.
- Cover invalidation follows rotated footprints and cover parts instead of a
  circumscribed square; long walls no longer re-evaluate distant ground.
- Navigation invalidates only cells whose solidity or cost actually changed.
  Rebuilding reuses unchanged borders and entrance-pair costs. Land orders are coalesced
  per entity, cancellable and processed four per tick. Graph rebuilding processes
  one dirty cluster per tick; fixed quotas avoid machine-speed-dependent order
  completion. Missing routes during
  rebuilding retry; valid unaffected routes can proceed. There is no full-map A*
  fallback when a hierarchical route fails.
- Local navigation grids use a bounded cache rather than eagerly duplicating every
  cell into thousands of local AStarGrid2D objects. Larger maps use 32 m clusters.
  Global terrain/navigation arrays are still dense: this is not infinite streaming.
- Formation cover searches compare candidates only with previously assigned men
  within the maximum search reach, preserving the same slots without repeatedly
  checking distant platoon members.
- Squad planning is staggered without extra random draws. Nearby members share
  threat assessments for up to 0.25 s; building contacts are shared for up to
  0.75 s. New contacts invalidate those assessments. Separated men assess their
  own sectors; sight, weapon timing and urgent reactions remain individual.
- Distant soldiers share baked model poses with generated mesh LOD through
  64 m spatial MultiMesh batches. Only active batches are visited each frame;
  empty batches expire after five to six seconds. Close models are
  created when needed. Distant color variation and subtle gestures are simplified.
  Hidden units never enter the batch. Selection stays on the individual soldier.
  Registered soldiers update their individual views in one loop, once per frame,
  avoiding hundreds of separate timing and profiling updates. Standalone preview
  soldiers retain their own frame callback.
- Vehicles retain articulated pivots and use one material surface per part beyond
  100 m. Near materials remain detailed. Wrecks skip this extra baking work during
  combat. This reduces draw submissions but adds work when a new vehicle loads.
- Neutral walls, floors and crates share drawing surfaces in 64 m cells. Changing
  an object removes only its triangles and restores its individual meshes; the
  rest of the cell stays batched. Original collision and entity state are retained.
- Walking observers bypass obstruction-cache bookkeeping for sight lines they
  cannot reuse. Stationary men, including men waiting for a route, retain the
  exact-line cache. Sight candidates, ray tests and weapon timing are unchanged.
- Squad marker status shares the existing 10 Hz overview refresh. Empty selection
  clears only previously marked soldiers; membership and ownership changes still
  apply immediately. Squad existence checks stop at the first living member
  instead of allocating a full membership list.
- Zoomed-out HUD drawing no longer projects every soldier for invisible close-up
  labels. Headquarters links, fog, town counts and minimap symbols use the small
  building indexes; the performance overlay no longer scans every entity for an unused count. Cosmetic network event batches stay below the normal datagram budget.
- Crater textures use bordered 512-sample array layers, with at most two layer
  uploads per frame. Cosmetic ground collision uses 32 m tiles around the camera,
  rebuilding at most two tiles per frame. Authoritative terrain remains complete.
  A small crater no longer uploads or rebuilds the entire 3 km heightfield.
- Initial client entities use the compressed join stream and staged loader from main,
  with a 45 ms construction budget while the loading curtain is up. Updates received during loading are retained. The 3D world stays hidden until
  initial construction finishes; later reinforcements do not restart loading. Shared soldier poses warm
  one per frame; a private battle waits for the loading acknowledgement before
  advancing combat. Individual close models also have a construction quota.
- Solid order arrows use two projected endpoints, dashed lines use batched draw
  calls, and squad overview groups refresh at 10 Hz while selection is immediate.
- Squad counters retain their last clear placement and firing stars share a
  triangulated mesh. The minimap paints structure changes in roughly 1 ms slices,
  keeping its previous complete image visible. Destruction may take additional
  frames to appear on the minimap; unit markers and input continue to update.
- Grass queues at most 225 nearby 32 m chunks, with a two-chunk/1 ms construction
  budget per frame and a two-chunk retention margin. This covers its longest
  170 m fade distance without generating all 9,216 chunks of a 3 km map.

## Dimensions and budgets

MapDims accepts 1024, 2048 or 3072 metres per side and configures each peer before
world allocation. Three times the width means nine times the area. The desktop
skirmish menu offers these sizes; missions retain their authored size by default.
CLI host, AI and stress modes accept --map-size.

Clients synchronize battle time from authoritative snapshots, with at most 100 ms
of interpolation while awaiting the next snapshot. Loading, a paused host or a
lost connection cannot keep advancing the displayed battle clock.

The authoritative simulation runs at 30 Hz (33.3 ms per tick). Rendering at 60 FPS
has a separate 16.67 ms frame budget. The old overlay added catch-up ticks into a
rendered frame, so a displayed 130 ms did not identify one specific slow function.
Separating processes removes simulation catch-up from the renderer, but does not
make a slow simulation acceptable. Reports include both frame and tick percentiles.

## Measurements, 17 October 2026

Reference PC: i9-11900K, RTX 3090, 64 GB RAM. Godot 4.7.2, 1280x720, zoom 130,
seed 3. Other user-owned game windows were open; these are local measurements,
not portable minimum-FPS guarantees. Source debug and exported release samples
must not be compared as if they were identical builds.

| Workload | Result |
| --- | --- |
| Early AI battle, 52 soldiers and 3532 entities | Smoothed tick 32.22 ms before working-set fixes, 6.24 ms afterward; final median 5.43 ms, p95 14.72 ms |
| Early 500-soldier perception investigation | GDScript candidate-search run median tick about 53 ms; first native run about 27 ms, with other costs still present |
| 500-soldier release view before distant batching | About 15 FPS, median frame 63 ms, p95 98 ms |
| First distant batching run | 51 FPS; still below target |
| Shared AI and HUD improvements, 3072 m release case | 127.8 FPS; frame median 7.09 ms, p95 11.96 ms, p99 15.76 ms, maximum 104.79 ms; 498 alive |
| Same release case, separate simulation | 301 ticks in the 10-second window; median 22.15 ms, p95 34.80 ms, maximum 45.99 ms |
| 2048 m headless source case | 299 ticks; median 31.55 ms, p95 44.17 ms; no global path fallback |
| 3072 m headless source case | 299 ticks; median 28.76 ms, p95 43.91 ms; approximately 3.08 GB Godot static memory; no global path fallback |
| Full generated 3 km, 480 soldiers plus 20 vehicles, high preset (before owned-building and mesh-LOD changes) | 17.4 FPS; frame median 58.79 ms, p95 89.23 ms. Server median 50.94 ms, p95 131.82 ms. Loaded successfully; 224,212 nodes. This scene remains below target. |
| Full generated 3 km, medium, after owned-building indexing | 17.7 FPS; server median 36.33 ms, p95 84.03 ms. Rules/fog work fell from 13.33 s to 1.08 s over the measurement window. |
| Full generated 3 km, medium, deferred scenery and spatial soldier batches | 17.2 FPS; frame median 59.17 ms, p95 84.45 ms. Server median 37.12 ms, p95 88.08 ms. Client loading fell from 268.23 s to 150.69 s; nodes fell to 110,835. Triangles fell to 4.10 million but draw calls rose to 14,233. This motivated simplifying distant soldier materials; it is not a successful FPS result. |
| First 180-second 3 km battle | 22.1 FPS; frame p95 80.24 ms, maximum 1039.50 ms. Whole-map crater texture and collision updates dominated the renderer. This invalidated the short-run result as a sustained claim. |
| Same duration after local terrain updates | 47.5 FPS; median frame 20.81 ms, p95 31.16 ms, p99 39.22 ms, maximum 79.87 ms. Still below target. |
| 180 seconds with pose warmup and shorter local routes | 53.7 FPS; frame median 18.18 ms, p95 27.58 ms, p99 32.91 ms, maximum 88.52 ms. Server median 23.90 ms, p95 47.15 ms. Still below target; measured before later HUD, generation and replication changes. |

During the sustained investigation, OS GPU counters showed two unrelated running
Godot sessions using approximately 60% of the GPU, with aggregate utilization
around 97%. Those sessions were left running pending permission to suspend them.
These measurements must not be presented as isolated GPU throughput.

The short 3 km rendered window meets the 60 FPS budget at the 99th percentile,
but contains a large hitch. It does not prove an unconditional 60 FPS minimum,
long-run stability, or the same performance in a dense city. Generated-world,
close-camera, mixed-unit and longer-run checks are tracked in SCALING_PROGRESS.md.

## Follow-up measurements, 27 October 2026

These changes do **not** establish sustained 60 FPS with the full HUD on the
generated 3 km battlefield. Other applications remain running. Prefer the paired
comparisons below over FPS from separate runs with different background load.

| Comparison | Result |
| --- | --- |
| Same battle, original scenery then shared surfaces, low preset, 480 soldiers and 20 vehicles initially | 38.06 to 44.32 FPS; repeated phases 42.54 to 46.55 FPS. About 1,000 draw submissions removed. |
| Same battle with shared scenery, HUD hidden then restored | 65.83 to 43.17 FPS. This isolates HUD cost; it is not a playable 60 FPS result. |
| Isolated 100-squad marker refresh, triangulated stars | 6.07 to 4.25 ms per refresh; star drawing itself 1.72 to 0.21 ms. Full-battle gains are smaller because not every squad is firing. |
| Alternating 500-soldier view-update microbenchmark | Individual callbacks 4.29/4.16/3.81 ms; shared loop 3.43/3.28/2.96 ms. Smoothing and poses still run for each soldier each frame. |
| Minimap rebuilding after roof destruction, before slicing | 100–134 ms synchronous rebuilds observed. Rebuilds now yield between groups of structures and retain the last complete image; the change targets hitches, not simulation throughput. |

## Verification and reproduction

The client constructs scenery models and cosmetic collision bodies in a moving
set of 128 m cells intersecting the camera frustum, with a preload margin for
roofs and shadows. Without a camera it uses the previous 9 by 9 square. Construction is limited to four
structures or 2 ms per frame; the initial loading curtain waits for nearby models.
Previously visited models remain cached but hidden outside this area. The server
retains the complete map, collision, cover and off-screen combat. This reduces
initial scene construction, but very distant scenery is omitted and a large camera
jump can briefly show models arriving. It is not a bounded-memory eviction system.

Nearby movement requests can reuse a valid route corridor. Each reused route
checks its new start and destination connections; obstruction or danger changes
invalidate the cache. Individual endpoints remain distinct. Quiet soldiers skip
cover enumeration when there are no threats, which preserves the existing empty
cover result without surveying surrounding structures.

See DEVELOPMENT.md for tools/benchmark_scaling.py and native build commands.
Artifacts include JSON, logs, screenshot and process RSS samples. Use fresh output
folders, separate ports and sequential performance runs. Simulation-only tests
cannot establish rendered FPS. Work quotas bound operations rather than wall time;
a single native A* or graph operation can still cause a timing spike.

Regression scenes cover structure lifecycle/index filtering, native and GDScript
perception against exhaustive candidate selection, blocked/reopened navigation,
replaced/cancelled path orders, and local-server commands/pause/reconnect/cleanup.

Rust is deliberately limited to numerical search. A full Rust server would also
need terrain, physics/LOS, combat, economy, AI, deterministic replay and a specified
transport. Godot high-level RPC is not a public interoperability contract. Retaining
Godot as the simulation host avoids silently changing those gameplay systems.

## References

- [Godot thread safety](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [Dedicated server exports](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)
- [SceneMultiplayer protocol caveat](https://github.com/godotengine/godot/blob/master/modules/multiplayer/doc_classes/SceneMultiplayer.xml)
- [Rust GDExtension bindings](https://godot-rust.github.io/book/)

- [Godot mesh level of detail](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)

## Integration check, 20 October 2026

PR #93 incorporates main's compressed join stream, staged terrain loading,
rejoin protocol, background script compilation and incremental navigation cost reuse.
The Windows installer includes the native library; Mac and browser exports exclude
its descriptor and use GDScript perception. The protocol change preserves private
session authentication alongside public reconnect identity.

The integrated focused suite passes all 13 regressions and seven gameplay smoke
scenarios. Platform update/link checks pass 36/36. The full behavior suite is under
review; repeatability checks passed both same-process reload and separate-process
full-map replay. No new 60 FPS acceptance claim is made by these correctness checks.

House containment queries use a floor-only spatial index maintained with the
normal structure index. They retain the same radius filtering and iteration
order; destruction and relocation remove old entries. Six scenario replays
matched all 24 pre-change fingerprints after this optimization.

Benchmark reports include aggregate system/view timing and physics CPU samples.
Use `--details` with `tools/benchmark_scaling.py` to additionally time individual
soldier methods (`--perf-details` in the game). Nested timers add instrumentation
work; compare reports with the same `detailed_timing` setting. The managed local
server receives the same profiling mode as its renderer.

Whole-map land navigation uses `NavRaster` byte solidity and float32 weights; AStarGrid2D search storage is allocated only for local clusters (or the explicit flat-grid diagnostic). At 3072 m, one raster allocates 45 MiB versus 686 MiB for a full AStarGrid2D. Seeded mutation and conversion tests compare both representations, including fractional weights. Formation selection caches geometry and incremental occupancy only within one synchronous `slots` call; no decisions survive terrain changes or later orders. Exhaustive-reference tests retain identical selections through 200-person groups.

## Overlay refresh isolation, 28 October 2026

The cached status overlay previously refreshed on every camera-offset or pointer change.
Blast shake and pointer movement could therefore bypass its 15 Hz limit. Status refresh
now uses the camera's unshaken transform. A separate pointer layer retains immediate
selection boxes, hover cards and order previews; camera panning, zooming and command
input still invalidate status immediately. The authoritative simulation is unchanged.

Exported Windows comparisons used a generated 3072 m map, 480 starting infantry and
20 starting vehicles, active commanders, seed 3, low graphics and the complete HUD at
1280 x 720. Other applications remained running. Alternating phases within one battle
reduce, but do not eliminate, background-load and battle-progression differences.

| Comparison | Control FPS | Changed FPS |
| --- | --- | --- |
| Natural blast shake, first phases | 41.60 / 45.59 | 48.61 |
| Natural blast shake, repeated phases | 45.59 / 47.57 | 51.30 |
| Continuously injected shake (diagnostic, not normal gameplay) | 38.72 / 42.54 | 55.93 |
| Moving pointer, first phases | 34.81 / 34.89 | 45.90 |
| Moving pointer, repeated phases | 34.89 / 36.64 | 48.99 |

The pointer comparison reproduces the former per-frame status invalidation while
keeping the pointer layer active in both phases. Status redraws fell from 120 per
120 measured frames to 37-39. The continuous-shake diagnostic fell from 120 to 32.
A separate 30-second full-battle run measured **47.47 FPS**, p50 **19.88 ms**, p95
**32.47 ms**, p99 **40.32 ms** and maximum **73.45 ms**. This does **not** meet the
60 FPS target. These results are workload-specific, not a capacity guarantee.

Rejected experiments included same-pixel minimap aggregation (slower with dispersed
units), rasterizing the whole minimap, larger soldier batch cells and collapsing
occluded counters (no repeatable full-frame improvement). Two-worker exports measured
40.74 and 34.63 FPS around a 33.12 FPS default-worker run; that variation does not
justify changing the default worker pool. No AI reactions or perception candidates
were removed to obtain these rendering results.


### Shared formation candidates

Each formation now prepares eligible ground cells and cover scores once. The optional
`FormationGround` native class scores those candidates and incrementally tracks occupied
positions; the GDScript fallback uses the same prepared candidates. Both preserve scan
order, strict comparisons, distance arithmetic and repeated occupancy subtraction.
The snapshot belongs to one synchronous order, so later terrain changes are evaluated
afresh. Cover anchors still use the existing selection rules.

The exhaustive placement fixture compares native and fallback paths through 200 men,
including trench cover, wall anchors and map boundaries. Alternating microbenchmarks
measured 200-person formation selection at **5.76-6.35 ms** with native scoring versus
**94.52-101.90 ms** before candidate preparation; the prepared GDScript path previously
measured **40.41-50.92 ms**. These are component timings, not whole-game speedups.

A first full rendered run using the workload above measured **54.25 FPS**, frame p50
**17.35 ms**, p95 **27.59 ms**, p99 **35.22 ms**, maximum **52.21 ms**. Server tick p50
was **26.33 ms**, p95 **52.20 ms**, p99 **65.86 ms**, maximum **93.61 ms**. It still
misses both the 60 FPS rendering target and the 30 Hz simulation tail budget. Separate
runs are affected by background load and battle progression, so this is not a controlled
14 percent speedup claim. Other applications remained running.


Ground-height and trench-containment checks now use a trench-only spatial index, updated
by the existing structure insertion/removal lifecycle. Exact segment tests, completed
construction checks and bridge precedence remain unchanged. A 6,000-point fixture
compares the original query through relocation, construction and removal. In consecutive
45-second detailed simulation runs, ground-query time fell from 1,594.55 to 496.97 ms;
tick p50/p95 moved from 24.59/49.05 to 23.66/47.38 ms. These runs retain profiling overhead.
The previous 189 ms movement outlier did not reproduce; detailed movement maxima were
0.32 and 5.13 ms, so there is no evidence for blaming normal movement on that outlier.

Typed distant-soldier batch records replace string-key lookups in the frame loop.
Alternating 500-soldier microbenchmarks measured 1.36-1.46 ms/frame before and
1.26-1.33 ms/frame after, with the same poses, grouping and instance transforms.


With the trench index and typed soldier batches, a subsequent full rendered run measured
**57.83 FPS**, p50 **16.18 ms**, p95 **25.88 ms**, p99 **32.57 ms**, maximum **45.67 ms**.
It still does not satisfy a minimum-60-FPS or p99 frame budget. All **24 simulation
fingerprints** matched main across attack, breach, trenches, tactics, grenade drills
and fire (seed 3, four samples per 60-second scenario).

Caching the roster into a texture reduced draw calls but did not improve alternating
FPS phases (direct 49.52/46.39/51.03, cached 45.34/47.28), so it was removed. A trial
half-frequency search for soldiers without a target retained reflexes but measured
49.93 FPS and 18.05 ms of soldier work per tick versus the prior 17.77 ms. Background
load and changed battle progression prevent a causal comparison; without a convincing
benefit, the original perception cadence was restored.


Moving-observer sight checks prepare the shared ray origin, mask and exclusions once
per target. Physics intersections and per-point smoke checks remain unchanged, including
early exit on the first visible point. Alternating 10,000-query microbenchmarks measured
blocked sight at 5.71-5.82 us before / 4.62-4.80 us after, clear sight at 2.57-2.63 /
2.34-2.37 us, and smoke at 5.17-5.21 / 4.03-4.07 us. This uses the existing physics
API directly; no new native physics binding or scan-cadence change is required.

Serial scene culling was also tested without reducing visible geometry. It measured
55.60 FPS (p95 28.05 ms), so the default threaded-culling threshold remains unchanged.


### Exact PR build validation

After removing diagnostics and retaining the ray-query change, sequential exported
runs (same seed, 480 starting infantry + 20 vehicles, commanders, full HUD, low preset,
30-second warm-up and sample, other applications left running) produced:

| Map | Average FPS | Frame p50 / p95 / p99 | Server tick p50 / p95 / p99 |
| --- | --- | --- | --- |
| 3072 m | 50.93 | 18.44 / 30.74 / 39.84 ms | 27.17 / 54.14 / 67.54 ms |
| 2048 m | 54.00 | 17.74 / 27.80 / 31.97 ms | 25.85 / 47.78 / 60.59 ms |

Both runs reported no runtime errors, but **neither meets 60 FPS**. The earlier
57.83 FPS run is not a stable capacity result. Component improvements are supported
by alternating measurements; these full runs cannot establish a precise overall
speedup while background load and battle progression vary. The remaining server
cost is predominantly soldier simulation, with occasional pathing and vehicle spikes.

The final Node regression suite passed 87 tests, and all 24 simulation fingerprints
still matched the pre-change main build after the sight-query change. CI caught one
standalone soldier-batch fixture with its old Dictionary type; it now uses DrawGroup.


Rendered checks passed 55/55 key/input assertions and 20/20 camera assertions. Before
and after cover-preview screenshots at 150% interface scale retain aligned positions.
Those short visual checks are not FPS benchmarks. Both baseline and changed visual
runs retain the existing two-resource shutdown warning; no script errors occurred.
The corrected standalone batch, structure index, terrain cover/update and map placement
tests also passed locally, and CI passed on the code commit.
