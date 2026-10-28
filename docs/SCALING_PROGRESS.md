# 500-unit scaling implementation

Target: 500 combined active units, 2 km then 3 km square maps, sustained 60 FPS.
Reference machine: Intel i9-11900K (8 cores / 16 threads), NVIDIA RTX 3090.
Preserve individual combat, authoritative outcomes and off-screen simulation.

## Acceptance gates

- [ ] A: repeatable stress matrix, rendered frame percentiles, long-run memory and simulation reports
- [x] B: bounded path scheduling and incremental graph rebuilds, lifecycle regression tests
- [x] C: managed local headless server, startup/readiness/version/exit/failure handling
- [ ] D: 500-unit simulation and rendering budgets on current map
- [ ] E: 2 km map, memory and multiplayer validation
- [ ] F: 3 km map, same validation
- [x] G: assess native/Rust work using measured remaining hotspots; implement if required

## Work log

- Earlier investigation removed scenery ticks, indexed FOB queries and eliminated unchanged navigation invalidations.
- Added a real-game stress scenario with configurable unit count, scenery, combat/march/idle modes and seed.

Do not interpret an unchecked gate or a headless result as validated 60 FPS support.

- B and C regression scenes pass, including blocked/reopened routes, order cancellation, delayed construction, commands, pause/resume, reconnect and child failure.
- G: native candidate selection implemented and checked against the GDScript reference; a full Rust simulation rewrite is not required by the measured evidence.
- Latest completed sustained sparse-map test: 53.7 FPS over 180 seconds, below target.
- Full generated 3 km mixed-unit runs complete without errors, but remain around 17 FPS. Deferred scenery reduced client loading from 268 s to 151 s and halved scene nodes. Spatial soldier batches reduced triangles but increased draw calls; a single-material distant pose is under validation. Close-camera and sustained target acceptance remain outstanding.

## 20 October continuation

- Private server joins now survive the menu lobby refresh; exported clients receive their battle.
- Grass streaming bounds nearby chunks; measured construction cost fell from about 11.8 to 0.12 ms per rendered frame in the two 3 km runs. Overall frame time did not improve in those runs; substantial unrelated CPU load prevents a controlled comparison.
- Headless entities no longer dispatch visual callbacks. Short clear local moves bypass the path queue so immediate cover movement is responsive.
- The full behavior suite after that change passes 52/60 tests. Remaining failures cover attack attrition, tank/defense outcomes, fire damage, gun hits, house clearing and grenade reactions. Assertions have not been relaxed.
- Latest diagnostic headless 3 km / 480 soldiers + 20 vehicles run: 366 measured ticks over 20 seconds; p50 50.26 ms, p95 89.19 ms, maximum 128.03 ms. No runtime errors, but the simulation budget fails. This was not a controlled idle-machine benchmark.
- A focused regression confirms busy riflemen no longer permanently skip an unvisited house; the tactics scenario still clears only one house and remains unresolved.
- Keep PR #93 in draft. Rendered 60 FPS and the larger-map acceptance gates remain unmet.

- Floor-only spatial lookup preserves all 24 fingerprints across six 60-second scenario replays. Its lifecycle/filter/order regression passes. The next headless 3 km run measured p50 44.52 ms, p95 82.04 ms and maximum 124.97 ms across 414 ticks; CPU contention still applies.
- The gun-crew regression exposed fixation on out-of-arc targets. Mounted gun scoring now retains awareness of those contacts but selects targets inside its arc; the focused regression and original guns scenario both pass.
- The lost-squad regression now forces squad removal and frees the dead before ending the plan, instead of depending on seed-specific casualties. This directly exercises the old lifetime crash and passes.

- The 21 infantry, armour and ground scenario checks now pass. Outcome assertions accept a damaged tank retreating and a broken infantry attack rather than requiring fixed casualty totals. House clearing checks both secured floor IDs. Grenade handling checks all three reflexes across three seeds; a direct fire fixture checks damage and escape without depending on a soldier randomly entering the fire. These replace brittle expectations, not the gameplay mechanics.
- The latest 3 km rendered low-preset check (480 soldiers, 20 vehicles, 30 seconds, 1280x720) measured 19.70 FPS, p50 48.81 ms, p95 69.18 ms, maximum 180.65 ms. GPU time was 2.87 ms median and render CPU time 9.50 ms. The target still fails; unrelated CPU load makes this diagnostic evidence rather than a controlled acceptance comparison.
- Client profiling now separates snapshot decoding and command-link drawing from the other view work.

- All 61 gameplay tests pass after the scenario checks above. Soldier decision dispatch now follows the same priorities directly, removing per-leaf tree/callable dispatch. A 60-case reference-tree test passes and all 24 fingerprints across six battle replays match before/after. The isolated 20,000-decision benchmark fell from 418-714 ms to 118-166 ms; this is dispatch overhead, not a whole-simulation speedup.
- Client attribution at low quality: squad symbols 8.25 ms/frame, distant soldier batches 3.65 ms/frame, snapshot decoding 1.30 ms/frame, command links 0.17 ms/frame. That run overlapped correctness tests and is profiling evidence only, not an FPS acceptance run.

- Retained callsign/order-label drawings pass a lifecycle/position/font/color test. The rendered 1 km 500-unit check was visually inspected; symbol time fell from 8.45 to 3.77 ms/frame in the diagnostic runs. The newer run measured 24.95 FPS (p50 37.60 ms, p95 60.54 ms), still failing the target. The runs are not a controlled overall-speedup comparison.
- All export presets exclude `build/*`, keeping local benchmark images, reports and helper scripts out of release packages. A Windows export confirms none are packed.

- Stationary interpolation and ground settling skip unchanged transforms, including the soldier view's stationary-facing path. Live Godot notification checks cover idle, movement, turning and teleport behavior.
- Distant soldier batches use numeric pose/cell keys; pose, team, movement, visibility and expiry checks pass. The generated-map screenshot was inspected.
- Notifications retain steady drawings between arrival flashes and departure fades; the draw-count lifecycle regression passes.
- Profiling now includes minimap, roster, notifications and resource drawing, plus physics CPU samples. Nested soldier timers are opt-in (`--details` in the benchmark tool); reports record `detailed_timing` on both processes. The A/B runs did not demonstrate a speedup from removing nested timers.
- Latest 1 km generated-map diagnostic: 24.64 FPS, frame p50 38.52 ms / p95 59.11 ms, simulation p50 40.32 ms / p95 92.83 ms. Minimap and roster drawing together cost about 3.1 ms/frame. Sparse controls measured 228.48 FPS with 20 soldiers and 29.09 FPS with 480 soldiers plus 20 vehicles. These narrow the remaining bottleneck to battlefield density; they do not satisfy the acceptance gates.

- Vehicle distance materials preserve hull/turret/wheel pivots and detailed near
  geometry. Magnified before/after renders were inspected. Wrecks skip extra
  baking to avoid combat-time construction spikes. The focused regression covers
  real tank turrets, wrecks, bounds, excluded parts and empty pivots.
- Active soldier batches avoid revisiting every cached animation pose each
  frame. The sparse mixed-unit diagnostic measured 34.62 FPS; its batch work was
  about 2.45 ms/frame. Increasing cells from 64 to 128 m did not improve FPS and
  was reverted. A cosmetic debris-budget experiment also showed no gain and was
  reverted.
- Selection and squad overview regressions cover ownership, deaths, new members,
  freed references, strength pips and status refresh. Selection input cost in the
  next generated-map diagnostic was about 0.23 ms/frame.
- Latest generated 1 km, 480 soldiers + 20 vehicles, low, 1280x720, 20-second
  diagnostic: 29.14 FPS, frame p50 32.91 ms / p95 46.85 ms / maximum 80.07 ms;
  simulation p50 39.17 ms / p95 94.04 ms. Screenshot inspected. Other user-owned
  workloads were active, including a separate animation recording; this is not
  controlled acceptance evidence. Both performance gates remain unmet.
- All 69 gameplay tests and all 13 scaling regression scenes pass. CI for
  `f96db1a` passed, including Linux checks and Windows/Linux native builds.
- Export-only worker experiments (same sparse mixed-unit case, 15 seconds):
  default workers / safe render thread 33.33 FPS; four workers / safe render
  thread 36.96 FPS; four workers / separate render thread 41.43 FPS. The latter
  still had frame p95 34.39 ms and simulation p95 55.13 ms. No engine default
  has been changed on this evidence; cross-platform and sustained checks remain.
- A new minimap regression reproduced two remote fights collapsing into one
  marker on 2 km and 3 km maps. A two-coordinate cell key fixes the collision;
  the test also checks same-cell grouping and hidden/dead filtering.

- A 60-second generated 2 km diagnostic measured 32.52 FPS, frame p50 29.87 ms /
  p95 40.95 ms / maximum 113.07 ms; simulation p50 30.32 ms / p95 54.54 ms.
  The screenshot was inspected. This still fails both performance gates.
- A native nearby-unit prototype passed 71 tests including exact result-order,
  hidden-unit, vehicle, movement, team-change and despawn checks. Its isolated
  query benchmark improved, but the full simulation comparison measured median
  ticks of 42.84 ms with it versus 31.48 ms without it. It was reverted, including
  the staged library; no additional native object-reference API ships.
- Vehicle transform notifications now have direct regression coverage. Idle
  hulls, turrets, barrels and wheels no longer receive unchanged transforms;
  movement, elevation, recoil and suspension still update. Windows export passes.
- The subsequent 30-second 2 km mixed battle measured 29.45 FPS (frame p50
  32.20 ms / p95 48.35 ms), simulation p50 33.50 ms / p95 64.75 ms. The render
  was inspected. The shorter window and external load preclude attributing the
  difference to the transform change; this is not a demonstrated FPS improvement.
- A sparse mixed-unit control with the HUD hidden reached 64.61 FPS (frame
  p95 20.28 ms), showing significant interface overhead but still missing the
  strict frame gate. Hiding the HUD is diagnostic only.
- Explicit rectangle batching was investigated and rejected. Both triangle
  arrays and retained MultiMesh instances produced pixel-identical output in
  Forward+ and Compatibility. However, an alternating-frame control showed
  ordinary rectangles already use one draw call; the custom builders took
  roughly four times longer to prepare. Neither prototype is retained. An
  apparent 38.88 FPS mixed-battle result is therefore not claimed as a speedup.

- Stationary battlefield overlays retain drawings between 30 Hz updates, carrying
  elapsed time across uneven frames; camera, pointer and input changes redraw
  immediately. Real draw-count tests cover both paths. The earlier capped-cadence
  sparse mixed-battle diagnostic measured 41.82 FPS; its image was inspected.
- A separate-render-thread experiment reached 49.35 FPS but produced texture
  update and shutdown errors. It is rejected; safe rendering remains the default.
  Switching to Mobile rendering measured 43.38 FPS and does not resolve the gap.
- Smoke visibility uses a lifecycle-maintained smoke-only collection. Tests compare
  1,000 seeded rays with the exhaustive reference and cover radius, position, type,
  despawn and fire-smoke changes. Individual scans reuse their observation point;
  the seven-contact limit and target preference are unchanged. The next headless
  diagnostic measured median 31.65 ms / p95 58.80 ms versus 30.42 / 55.00 ms before;
  this does not establish a whole-simulation improvement under the external load.

- Main's helicopter changes are integrated with snapshot protocol 11. All 72 local
  checks pass, and CI for d6d7fdb passed Linux gameplay plus Windows/Linux native
  builds, exports and the macOS installer checks.
- The integrated 3 km, initially 480-soldier/20-vehicle, 120-second rendered run
  measured 31.21 FPS (frame p50 30.33 / p95 49.17 ms); simulation p50 27.66 /
  p95 67.12 ms. It ended with 221 soldiers alive, so it does not prove sustained
  500-unit capacity. Peak combined client/server RSS was about 6.86 GiB.
- Worst-tick diagnostics isolated a 656.87 ms headless tick: 635.59 ms was in
  structure updates, where town captures repainted the whole road network.
  Incremental road updates reduced total structure work to 244.13 ms across the
  next entire 120-second measurement; its worst tick was 288.06 ms in other
  systems. A separate animation recording started during that run, so this is
  hotspot evidence, not controlled FPS acceptance.
- Road regression coverage includes unchanged networks, added routes, coordinate
  changes with unchanged point counts, removals, and exhaustive raster comparison
  for diagonal, horizontal, vertical, degenerate, off-map and seeded segments.
  Water and cover values remain identical. The renderer minimap-cache experiment
  was removed after its input check exposed a co-command hover regression.

- With incremental road painting and row-wise segment bounds, the next 120-second
  headless 3 km run measured median 22.50 / p95 51.46 / maximum 170.78 ms, with
  241.33 ms total structure work. No animation preview was active when this run
  started, so none needed suspension. Both simulation gates still fail.
- The previous tick timer omitted terrain maintenance and graveyard cleanup.
  Reports now include those stages and retain the worst tick's system breakdown;
  a real-game report test checks that its duration equals the measured maximum.
  Historical tick numbers above therefore understate complete logic cost.

- All 74 local checks and CI passed at 6a3b1b2. The subsequent rendered 3 km
  60-second diagnostic measured 28.82 FPS, frame p50 32.87 / p95 51.42 ms.
  Complete simulation ticks measured p50 31.73 / p95 68.32 / maximum 202.94 ms.
  Terrain/cleanup was only 82.72 ms total; the worst tick spent 157.91 ms in
  squad planning. The rendered image was inspected; performance still fails.
- Tactical enemy-building checks now use the existing owned-building index.
  Reference comparisons cover 120 seeded destinations plus visibility, capture,
  neutralisation and destruction. An isolated 3,000-scenery-object control took
  736-741 ms for 100 old checks versus 14-16 ms with the index. This is a query
  improvement, not a measured whole-game FPS claim.
- Client snapshots previously discarded the server timestamp, leaving loading
  time and host slowdown in the battle clock. Clients now synchronize that clock
  and extrapolate for at most 100 ms without another snapshot. Direct snapshot,
  ENet authority and real private-server pause/resume/reconnect checks pass.

- Optional detailed reports now include the maximum individual call as well as
  accumulated time, and split squad planning into phases. This isolated a
  149.63 ms assault-execution call; ordinary squad formation calls peaked below
  0.64 ms. Attack plans place larger combined elements directly through terrain.
- Formation cover searches prefilter previously assigned men once per slot to
  the maximum possible search reach. Candidate ordering and scoring remain
  unchanged. All 16 reference cases match exactly, including wall anchors,
  trenches, narrow/wide formations, 1-96 men and map edges. In the 200-man
  isolated control, the original placement took 192.11 ms versus 28.00 ms.
  All 76 local tests and CI pass at b726482. The exported 3 km Forward+
  control (480 soldiers, 20 vehicles, commanders, low preset, 1280x720,
  30-second measurement after 30 seconds warmup) averaged 25.86 FPS, with
  frame p50/p95 36.98/54.24 ms. Complete server ticks were 36.23/77.37 ms
  p50/p95, maximum 183.11 ms (122.98 ms pathing). It ended with 444 soldiers
  alive. Other user-owned workloads were active; this is not a controlled
  before/after attribution or sustained 500-unit acceptance result.
- A sequential Compatibility renderer control averaged 22.10 FPS and showed
  severe battlefield rendering corruption in the inspected screenshot. It is
  rejected; the temporary export override was restored. Forward+ remains the
  default. Both runs fail all frame and simulation acceptance gates.
- An occupied-row proximity-query prototype matched 600 seeded reference
  queries, including result order and units moving after the hash rebuild.
  It helped very broad queries but slowed common small searches, so it was
  removed rather than adding another index to every simulation tick.


## 23 October follow-up

- PR #93 is merged. Further work starts from 8f938b9 on
  `codex/battle-hotpaths`; the 60 FPS acceptance gates remain open.
- Local navigation grids now use insertion order for LRU eviction rather than
  scanning every cached grid. A seeded reference test compares 1,800 accesses
  at each of the 16 m and 32 m cluster sizes and verifies edits both while
  resident and after eviction. The 2,500-miss
  isolated control took 160-192 ms before versus 51-62 ms afterward.
- On the same generated 3 km map, 100 route queries retained identical lengths
  and waypoint counts. Total query-loop time was 534 ms before and 491 ms after;
  the maximum query was 47.36 versus 42.16 ms. These single-run diagnostics do
  not establish an FPS improvement. Hierarchy size and obstacle detail remain
  unchanged.
- Animated combat markers reuse one star polygon and transform it for each
  marker. The rendered 12,000-marker drawing control took 241 ms before versus
  109 ms afterward. Reference geometry checks cover 100 phases; both rendered
  images were inspected, including a following untransformed drawing.
- Per-instance transform caching slowed the moving-soldier control. Typed batch
  records gave only small/inconsistent gains. Neither experiment is retained.
- All 78 game tests pass, and the Windows release export succeeds. The opt-in
  full-mission campaign was not enabled. A final rendered marker check exits
  without errors and preserves the following drawing's coordinates.
- Additional cache controls: 2,500 misses at the 32 m cluster size took
  234-253 ms before versus 201-203 ms after. Cache hits cost more: 100,000
  hits took 46-47 ms before versus 61-65 ms after (about 0.15-0.19 microseconds
  extra per hit). This is an eviction improvement, not a claim that every
  navigation operation is faster.
- A 200-marker rendered control measured 0.160/0.177 ms render CPU before/after
  and essentially the same 201 draw calls; script drawing took 589/350 ms
  across 180 frames. The renderer-side cost is small, but not zero.
- Exported battle controls remain below 60 FPS. Early sequential controls
  measured 29.01/27.56 FPS on the old build and 24.65/23.51 FPS on the modified
  build. A concurrent video encoder was observed using roughly nine cores;
  other applications also remained active. A fresh baseline export reached
  29.00 FPS and a navigation-only export 29.66 FPS. These measurements do not
  establish a whole-game improvement. Further isolation results are recorded
  in [PR #97](https://github.com/Dynasty9/Frontline/pull/97).
- The canvas-transform marker prototype reached only 25.29 FPS when exported
  on its own. Despite its isolated CPU savings, it is not retained. The final
  implementation transforms the cached vertices in native code and submits
  the same world-space polygon command as before, without canvas state changes.
  Earlier marker timings above describe the discarded canvas-transform version.


## Work-budget follow-up (23 October)

The following controls use the pre-cohesion/replay base `5adeda0`. Later integration
must be checked separately. Other applications remain running at the user's request.

- Camera-frustum scenery residency replaces the fixed square, retaining a margin
  for roofs and shadows. Sampled visibility tests cover camera angles, aspect ratios,
  FOV and heights. Distant soldier batches skip cells outside a conservative view
  margin; camera-pan and visible-point tests pass.
- Blocked sight checks reuse obstruction only with unchanged endpoints, exclusions
  and blocking collision boxes. Tests cover movement, posture, collision layers,
  shape disabling/resizing, door removal, freed blockers and smoke dissipation.
  A repeated blocked-query control took 43-44 ms cached versus 73-75 ms fresh for
  10,000 calls. Positive sight and smoke remain live. This is not a whole-game claim.
- The tactical overlay retains a raster between 15 Hz stationary updates. Camera,
  pointer and input invalidate immediately; resizing and hide/show have tests.
  Reducing soldiers' candidate budget regressed infantry scenarios and was removed.
  A minimap raster experiment changed FPS by less than 1% and was also removed.
- Rust RouteGraph contracts degree-two search states while preserving directional
  edge costs and reconstructed waypoints. 900 seeded comparisons (excluding deleted
  endpoints) cover danger changes and removals; navigation rebuild/order tests pass.
  On a synthetic 120,000-node graph, 120 nearby searches took 6.2-11.2 ms versus
  22.1-23.5 ms with AStar3D. On a generated 3 km map, 100 complete path requests took
  349-384 ms versus 437-489 ms; maximum requests were 19.7-21.0 versus 38.9-41.5 ms.
  Equal-cost route choices can differ: smoothed total distance differed by 0.27%,
  with individual differences from -1.54% to +6.53%. All 80 gameplay tests pass.
  Graph assembly now runs on the main thread because the Rust binding requires it;
  local-grid costing remains parallel. The generated graph build took about 7 s.
- Sequential exported Forward+ controls: 3072 m generated map, 480 soldiers,
  20 vehicles, commanders, seed 3, low preset, 1280x720, 30 s warmup + 30 s sample.

| Build | Average FPS | Frame p50 / p95 / p99 (ms) | Tick p50 / p95 / max (ms) |
| --- | --- | --- | --- |
| `5adeda0` baseline | 35.73 | 26.88 / 40.85 / 52.65 | 27.03 / 57.06 / 108.23 |
| Rendering + exact sight cache + native routes | 43.17 | 21.98 / 35.48 / 50.04 | 29.53 / 62.93 / 111.18 |

This pair is about 21% faster on average rendering, but simulation timing did not
improve and all strict acceptance gates still fail. Battles evolve differently;
439-456 soldiers survived the later sample windows, so these are not sustained
500-alive acceptance runs. Peak observed server RSS was 4027/3723 MiB. Earlier
controls ranged from 20 to 43 FPS as desktop contention changed; do not attribute
that whole range to code changes. Before/after rendered images were inspected.
Local artifacts: `build/bench-work-budget-base-control`,
`build/bench-work-budget-route`, `build/route-generated.log`, and
`build/native-route-all-tests2.log`. The 60 FPS goal remains open.

## Current-main integration and replay stalls

Rebased onto `de6bff8` (cohesion and replay recording included). Sequential
exported controls with the same workload above measured 38.65 FPS on current main
and 45.57 FPS with rendering/native-route changes, before the changes below.
Both had server p99 around 445 ms and maxima around 662 ms. The worst tick spent
613-637 ms selecting squad positions; snapshot-stage totals included recording.

Further changes preserve exhaustive formation choices through 200-man groups,
replace full-map AStarGrid2D storage with compact land rasters, and cache unchanged
replay scenery in entity-ID blocks. Recording samples visit the moving registry;
completed immutable chunks are encoded by one bounded worker. Checkpoint tests
compare live properties and observer packet bytes after damage, spawn/despawn,
and continued combat, and the existing forward/backward seek test passes.

Detailed-profile controls (timing instrumentation enabled, other apps running):

| Stage | Formation/raster only | Plus replay changes |
| --- | ---: | ---: |
| Server ticks in sample | 618 | 839 |
| Replay main-thread total | 8307 ms | 850 ms |
| Checkpoint total / max | 2145 / 230 ms | 182 / 27 ms |
| Replay sampling total / max | 4296 / 81 ms | 662 / 19 ms |
| Tick p50 / p95 / p99 | 34.77 / 96.57 / 445.29 ms | 30.89 / 59.69 / 75.08 ms |
| Tick maximum | 463.30 ms | 365.59 ms |
| Client average FPS | 47.76 | 43.15 |

The worker encoding cost still exists off the simulation thread. Recording's
main-thread reduction is about 90%; it is not a 90% whole-game speedup. The faster
server advances further (463 versus 450 surviving soldiers), changing the battle
phase. The later outlier spans soldier scanning and snapshot transmission and
cannot be attributed to a single algorithm from wall-clock timing alone. These
runs do not meet 60 FPS; desktop contention remains uncontrolled by request.
Artifacts: `build/bench-integration-base`, `build/bench-integration-route`,
`build/bench-integration-formation`, `build/bench-integration-replay`.

The final uninstrumented replay/raster comparison ran the candidate first and
current main second, sequentially with other apps running:

| Build | FPS | Frame p50 / p95 / p99 | Tick p50 / p95 / p99 / max | Server ticks | Peak client / server RSS |
| --- | ---: | --- | --- | ---: | --- |
| Current main `de6bff8` | 38.96 | 24.83 / 35.54 / 45.90 ms | 31.86 / 92.41 / 451.87 / 682.50 ms | 628 | 2984 / 4117 MiB |
| `c3e8f89` | 44.56 | 21.14 / 34.86 / 47.74 ms | 28.96 / 55.50 / 76.16 / 150.78 ms | 863 | 2822 / 2534 MiB |

Average rendering improves 14.4%, server p99 falls 83.1%, and peak server RSS
falls 38.4%. Frame p99 does not improve; the 60 FPS target remains open. This
comparison has 449/446 surviving soldiers respectively. All 84 local tests and
PR CI passed for this revision. Artifacts: `build/bench-replay-base-final` and
`build/bench-replay-final`.

A further moving-observer obstruction experiment passed 3000 comparisons against
fresh physics rays and halved an isolated moving-eye benchmark. It increased
lifetime blocked-result reuse from 49,349 to 165,054, but the exported control
measured 40.92 FPS, tick p50 28.84 ms and p99 86.80 ms. Soldier work per sampled
tick did not improve. The added geometric proof/cache sharing was removed;
only collision-margin and disabled-body invalidation checks were retained.
Artifact: `build/bench-sight-final`.

An export with script stack tracking disabled measured 33.73 FPS after the sight
experiment's 40.92 FPS. This uncontrolled desktop comparison does not establish
the setting's causal cost; no improvement was demonstrated, and stack tracking
remains enabled. Artifact: `build/bench-no-stacks`. The final retained sight
cache also checks collision margins and disabled-body state; its targeted physics
fixture and final import pass. The final raster/replay revision passed 84 tests;
the discarded moving-sight experiment separately passed the same 84-test suite.


### Further navigation experiments (not retained)

Other applications remained running throughout these measurements. The retained
2 km export averaged 51.84 FPS, with frame p99 33.46 ms and tick
p50/p95/p99/max 26.05/44.41/57.39/69.13 ms. Peak server RSS was 1262 MiB;
435 soldiers survived. This also misses the minimum 60 FPS target.
Artifact: `build/bench-replay-2km`.

A deterministic work quota counted native graph visits and bounded local-grid
work, allowing at least one indivisible search to progress each tick. A 65,536
work quota reduced the worst sampled tick from 150.78 to 69.96 ms, but maximum
path wait increased from 3862 to 6258 ms. It passed all 84 gameplay tests, but
that order-latency tradeoff was not accepted.

Allowing cached results through without consuming graph-search slots reduced
maximum wait to 5266 ms, still worse than the retained control. A looser 131,072
quota also failed to demonstrate a better tradeoff:

| Experiment | FPS | Tick p50 / p95 / p99 / max (ms) | Max path wait (ms) |
| --- | ---: | --- | ---: |
| Retained replay/formation candidate | 44.56 | 28.96 / 55.50 / 76.16 / 150.78 | 3862 |
| 65,536 work quota | 44.85 | 27.27 / 50.00 / 62.18 / 69.96 | 6258 |
| Same quota, cached deliveries bypass search slots | 44.55 | 29.86 / 50.97 / 70.87 / 88.87 | 5266 |
| 131,072 quota, cached deliveries bypass search slots | 36.57 | 33.74 / 62.20 / 81.31 / 185.06 | 5227 |

These are sequential desktop measurements, not isolated causal estimates. The
last run's worst tick was dominated by squads (142.08 ms), not pathing (13.67 ms).
Artifacts: `build/bench-quota-final`, `build/bench-quota-bypass`,
`build/bench-quota128`. All quota and search-counter changes were removed.

A separate corridor-cache experiment retained routes across unrelated terrain
and danger changes, invalidated their crossed clusters immediately, and expired
them after 30 scheduler steps. Focused invalidation tests passed, but the broad
suite passed only 83/84: the breach scenario left a defender fighting after the
house-clearing drill. Removing cached-delivery acceleration did not fix it;
restoring the original global invalidation did. This experiment was removed,
without relaxing the gameplay assertion.

Remaining measured costs are soldier simulation and client rendering/submission.
The retained detailed sample spent 19.39 seconds of aggregate simulation-thread
time in soldiers across 839 ticks; nested fighting and thinking costs overlap
that total. The retained client reported about 4400 draw calls, render CPU p50
5.23 ms and GPU p50 4.64 ms. Combining tree geometry needs to retain per-tree
material coordinates, wind, charring and falling; no tree batching or visual
simplification was introduced in this pass. Neither a server-language rewrite
nor fewer perception candidates is established as a safe solution by this data.
