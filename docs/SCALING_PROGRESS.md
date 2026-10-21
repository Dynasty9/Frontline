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
