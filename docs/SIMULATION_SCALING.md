# Simulation scaling

## Implemented boundary

Desktop solo games use the existing authoritative Godot host in a separate,
private headless process. The visible process retains input, UI, interpolation,
models and effects. A random session token and protocol version protect the
loopback connection. Launch/readiness, pause/resume, reconnect ownership and exit
are managed by LocalServer. Public multiplayer retains the existing host flow;
web retains the in-process fallback. Protocol version is now 10.

Rust accelerates one measured numeric hotspot: nearest-enemy candidate selection.
Once per tick the host supplies IDs, teams, positions and visibility factors to
PerceptionSearch. It returns at most seven candidates, ordered by distance and ID.
Godot still checks current lifecycle state, individual line of sight and weapons.
The GDScript implementation remains available for comparison or source checkouts
without the optional extension. This is not a full Rust server rewrite.

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
- Squad planning is staggered without extra random draws. Nearby members share
  threat assessments for up to 0.25 s; building contacts are shared for up to
  0.75 s. New contacts invalidate those assessments. Separated men assess their
  own sectors; sight, weapon timing and urgent reactions remain individual.
- Distant soldiers share baked model poses with generated mesh LOD through
  64 m spatial MultiMesh batches. Empty batches expire after five seconds. Close models are
  created when needed. Distant color variation and subtle gestures are simplified.
  Hidden units never enter the batch. Selection stays on the individual soldier.
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
- Grass queues at most 225 nearby 32 m chunks, with a two-chunk/1 ms construction
  budget per frame and a two-chunk retention margin. This covers its longest
  170 m fade distance without generating all 9,216 chunks of a 3 km map.

## Dimensions and budgets

MapDims accepts 1024, 2048 or 3072 metres per side and configures each peer before
world allocation. Three times the width means nine times the area. The desktop
skirmish menu offers these sizes; missions retain their authored size by default.
CLI host, AI and stress modes accept --map-size.

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

## Verification and reproduction

The client constructs scenery models and cosmetic collision bodies in a moving
9 by 9 set of 128 m cells around the camera. Construction is limited to four
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
