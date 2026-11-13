# Loading and selectable battlefields

Work started 2026-11-13 07:49 UTC. The requested minimum five-hour iteration
window ends at 12:49 UTC. PR #222 is based on `a541c8d0` (PR #217). This log records results, rejected experiments and remaining
limits; it does not claim that an untested option is faster.

## Measurement contract

- Primary: Deploy to the loading curtain disappearing, including the private
  server launch, compilation still in flight, construction and render warm-up.
- Secondary: process startup, host generation, client terrain, scenery/models,
  readiness, and memory/package size. Do not add overlapping host/client stages.
- Run rendered controls and candidates serially on the same seed, map, renderer,
  graphics preset and viewport. Retain unsuccessful runs. Record background load.
- Check first-process and repeat loads separately. Do not call a repeat run a
  cold filesystem-cache test; the OS cache is not being purged.
- Do not achieve a faster clock by revealing missing collision, delaying commands,
  advancing combat unseen or moving a long stall into the first camera movement.

## Starting evidence

The preceding PR's synthetic 1,024 m terrain-install test measured 25.1 s before
and 24.6 s after skipping client vehicle-slope preparation, with other work
running. That difference does not establish a useful overall improvement.
The rendered attack fixture took 103.1 s from world allocation to client ready,
including 91.7 s before receipt of map state and 10.9 s after entity construction.
These stages overlap host work and client scene preparation; they do not identify
the root cause on their own. Fine-grained markers are the first experiment.

## Intended scope

Three curated battlefields, selectable for skirmish and hosted battles. Keep
campaign missions and explicit scenario tests intact. Store expensive static
map work ahead of play, with deterministic initial forces assigned to the current
players. Validate map identity and stale/missing data, export inclusion, joins,
terrain equality, navigation and representative AI battles. Inspect each map
and the selection UI in both renderers before presenting it as finished.

## Iterations

1. Added host/client phase markers and a Deploy-to-playable clock. The first
   rendered 1,024 m seed-3 baseline took **227.0 seconds** from local server
   launch to the curtain disappearing (Forward+, high preset, 1280x720,
   i9-11900K / RTX 3090 / 64 GB RAM). Other Godot jobs were running. Preserve
   this as a diagnostic run, not a controlled performance claim.
   Host terrain preparation took about 33 s, scenery about 67 s and navigation
   finalization about 13 s. The client needed substantial additional work after
   receiving the map. Raw logs: `C:/temp/frontline-load-baseline-01*`.
2. A first static-map package for seed 3 occupies 15,691,256 bytes. A generated
   versus restored comparison matched terrain arrays, navigation cells, entity
   snapshots, RNG state and IDs, but failed the entity-properties comparison.
   The restore also still took 88.8 s under background load. Neither correctness
   nor a useful end-to-end improvement is established by this prototype.
3. The first 1280x720 map-picker capture is legible and fits the operation panel.
   The run reported resource preloading errors; investigate before accepting it.
4. The property mismatch was caused by normal spawning snapping tiny nonzero
   saved Y coordinates to zero. Restores now retain the recorded position.
   A second diagnostic run found that rebuilding structures' navigation cells
   and refreshing all terrain cells consumed almost all the cache's savings.
   Format 3 stores these cells, their obstacle membership and terrain textures.
5. Format 3 passed the full seed-3 host-state and client-ground equality check:
   generated host 162.009 s, restored host 19.614 s; client ground 29.446 s versus
   5.913 s. Host restoration itself reached forces at 3.672 s; navigation graph
   finalization then took 15.029 s. These are same-process component checks under
   competing load, not a rendered time-to-playable comparison. The package is
   33,805,094 bytes. Raw evidence: `C:/temp/frontline-battlefield-equality-03.log`.
6. Host-setup tests passed for all choices and campaign mode switching. A
   960x600 Compatibility capture fits the map field without clipping. Waiting
   for background compilation before the screenshot tool quits removed the
   preload errors; the process still reports 37 leaked objects at exit.
7. The first rendered prepared-map run still took **212.283 s** from launch to
   playable. It used observer mode (17 soldiers), so it is not a matched pair
   with the earlier 227 s player-side diagnostic. Host setup took 37.7 s under
   contention. Client entities finished at 117.0 s, but readiness followed at
   193.9 s: model preparation is now a major remaining wait. The full process
   lifetime was 550.6 s, which includes startup and shutdown; it must not be
   reported as loading time. The run exited cleanly and saved an inspectable
   town view in `C:/temp/frontline-map-cache-render-01/`.
   Subsequent review found that the cached image path omitted the dirty region
   that schedules GPU height-texture uploads. Exclude this run from performance
   claims: matching CPU heights alone did not establish matching rendered terrain.
   The restore now marks the full image dirty, and the client regression checks it.
8. Current experiments: cached hierarchical route costs, an 8 ms loading-only
   budget for scenery and soldier poses, deferring photo textures until a view
   requests them, and skipping character-archive mounting in the private
   headless server. Small navigation tests passed for prepared costs and the
   invalid-cost fallback. Full-map, rendered and export validation remain pending.
9. Navigation regression passed for infantry, wheeled and tracked routes, including
   malformed prepared-cost fallback (`NAVIGATION_BUDGET_TEST failures=0
   rebuild_steps=4`). Soldier pose scheduling passed its loading/gameplay budget
   checks and existing LOD assertions (`SOLDIER_BATCH_TEST failures=0 lod_levels=5`).
   The first pose test was cancelled during startup; it is not counted as a pass.
10. The native release library built successfully. Earlier local runs used the
    GDScript/AStar3D fallback because this checkout had not imported the extension.
    Final comparisons must use one consistent backend. The first new import used
    a runner without APPDATA and failed to open user data; it was stopped and
    restarted with explicit Windows user-data paths. Retain its log as invalid.
    Fifteen Godot processes were present during this investigation, mostly from
    unrelated worktrees. These runs cannot establish unloaded-machine timings.
    Three consecutive Windows counter samples showed 100% total CPU, 29.7–29.9 GB
    available memory and an average disk queue below 0.013. This identifies CPU
    contention in the test environment; it does not explain all player loading.
11. The benchmark now locks renderer, mood and player side. CLI lighting was not
    forwarded to the private server; it now is. `--host --battlefield=...` also
    applies the same validated catalogue options as the interactive host picker.
12. Final-format Alder Valley baked and passed its package readback. The expanded
    native comparison is running; Stonebridge and Highland Junction follow in
    the same baker. Remaining eager visual source assets total under 1 MB, so
    further broad preload edits were rejected in favour of validating the major
    terrain, navigation and model work. The harness can now record a matched
    camera pan as well as a parked view, to expose work deferred into play.
13. Native attack smoke test completed 40 simulation seconds with exit 0 and no
    script errors. The map parity test now requires the restore marker, compares
    scenery/objective metadata, and checks 180 simulation ticks after destruction.
14. Alder Valley and Stonebridge packages occupy 35,195,799 and 40,824,633 bytes.
    Shipping every package inside the browser PCK would increase initial network
    wait substantially. Web therefore retains the same selectable seeded layouts
    but generates them; desktop exports ship the prepared data. Per-map browser
    downloads are a possible later optimization, not implemented in this change.
15. All three initial packages passed source, engine and checksum validation;
    Highland Junction occupies 42,895,411 bytes. The visible-host Alder overview
    restored cached scenery and reached deployment in 48.457 s under contention,
    then exited 0. Its 800 m overview shows raised terrain and the expected coast
    and river. Dark road strips require a matched generated-image check before
    being attributed to this change. Eleven objects were reported leaked at exit.
16. The private server previously resumed when client objects were ready, before
    the 24 rendered warm-up frames and curtain fade. Readiness now waits for the
    curtain to disappear in private games; ordinary network joins keep their
    immediate acknowledgement. Added regression coverage for both paths.
    The in-progress Alder comparison was stopped when this changed the world
    source identity; it is incomplete, not a passing result. Packages are being
    rebuilt with this change and the additional town-dressing source dependency.
17. Matched 1280x720 Forward+ overviews (day, high preset, 800 m distance,
    pitch -75 degrees) show the same raised ground, coast, roads and buildings
    for generated and prepared Alder Valley. The dark road strips are present
    in both. The generated visible host reached deployment at 127.869 s versus
    48.457 s for the prepared run, but these are diagnostic construction timings
    under variable contention, not a controlled Deploy-to-playable result.
18. Process inspection found rendered Godot at Above Normal priority and headless
    workers at Normal on this machine. Total CPU remained 100%. Only the owned
    offline bake and regression trees were raised to Above Normal to prevent
    starvation; those elapsed timings are excluded from gameplay load claims.
    Native navigation and scenery-streaming regressions both exited 0 without
    errors. The origin of the rendered process priority was not established.

19. Final packages rebuilt successfully with all 20 source identities. The source,
    engine and checksum check passes. Native client-loading regression passes
    including the curtain readiness gate. Windows export and all-map parity
    (routes, destruction, 180 ticks and client height upload) are in progress.

20. Expanded parity failed after scenery destruction on all three maps (22
    assertions): initial state matched, but route graphs did not rebuild and
    Alder/Stonebridge simulation subsequently diverged. A direct runtime probe
    confirmed PackedByteArray assignment shares storage (`a=[3,2], b=[3,2]`).
    Restored HNav mirrors now duplicate the live rasters, so dirty detection
    sees the prior cell values. Packages and full parity are being rerun.
    Diagnostic run 06 was interrupted when the tool runtime reset; run 07 was
    explicitly stopped after the smaller probe confirmed the defect. Neither
    is a passing result. The first broad-test attempt used an old Node binary
    and rejected its CLI flag; the supported bundled runtime is now running.

21. Independent raster mirrors fixed post-destruction parity and sampled entity
    state. A granular follow-up found only cost-table differences after 180 ticks:
    generation shared identical cluster matrices, and later relinking modified
    those shared arrays. Relinking now duplicates its small matrix before edits;
    a focused generated-versus-serialized mutation regression covers this.
22. The first exported private run reached play with simulation time 100 ms at
    reveal. It reconnected under CPU starvation, reset the reported launch clock,
    and logged a freed-world curtain callback. Exclude its timing from speed
    claims. Launch timing now survives retries; curtain completion uses a weak
    reference so a cancelled join can safely dispose its world. Priority was
    changed mid-run only to finish this diagnostic. Future comparisons must
    normalize the whole process tree from launch and report that condition.
23. Broad tests: 18 passed (determinism, infantry and ground); 13 air/sea/armour
    checks could not run because their shared game startup timed out. Only those
    two files are being retried, with a temporary 600 s startup allowance and
    unchanged simulation assertions. A cancelled-load regression initially had
    a weakref type-inference parse error; its type is now explicit and it is
    being rerun.

24. Final all-map parity passed (`BATTLEFIELD_MAP_TEST failures=0`): every
    starting state, both-side routes for infantry/wheels/tracks, scenery removal,
    180 simulation ticks and client ground/height upload matched. Focused route
    mutation and cancelled-load tests also passed. All four scenario groups and
    determinism passed across the original and startup-budget retry runs.
25. Final import, Windows release export and browser release export exited 0
    without script/parse/engine errors. Highland Junction and Alder Compatibility
    overviews were inspected; the small 960x600 map picker with reduced motion
    fits without clipping. Existing exit-leak warnings remain (10–12 objects).
    The benchmark now has an explicit Windows-only `--above-normal` diagnostic
    flag, recording successful priority application for client and server.

26. Final matched release-export comparison completed in prepared/generated/generated/prepared order. All four runs exited 0 with no engine or script errors. Same Alder Valley, player side 0, day, high, Forward+, 1280x720, camera at 0,0 / 130 m, first pan 40 m/s. Both processes used the recorded Above Normal benchmark priority; total CPU was 100% busy before every run. OS caches were not purged. Results are reproducible evidence under contention, not clean-machine estimates or cold-cache measurements.

27. Exported public Stonebridge host/client completed with both exits 0 and no errors. The client dropped at 22.6 s, rejoined with its nine units, and the host recorded rejoined=1, rejoin_returned=2 and rejoin_ai_stood_down=1. Initial readiness probes incorrectly relied on Windows UDP bind exclusivity; those attempts were stopped without launching a client. Reading the OS endpoint table by the owned host PID fixed the harness. Two intervening runner attempts referenced a nonexistent executable and performed no game test. Source startup tracing now distinguishes console, menu and command-dispatch time under FL_DEBUG_LOAD.
28. Linux CI rejected the assumption that fresh generation matches a Windows bake byte for byte: tiny angle/position differences occurred on all maps, and Stonebridge generated 4,243 structures versus the canonical package's 4,263. This is a cross-platform generator difference, not evidence that the serialized restore round trip is correct. Validation now separately checks deterministic shipped-map loads (including routes, destruction, 180 ticks and client terrain), then explicitly rebakes on the CI platform and retains exact generated-versus-restored assertions. No tolerance or assertion was removed. The shipped data remains canonical across desktop hosts; procedural fallback/browser details can differ by platform. The first CI parity failure is retained as evidence.

29. Final progress review found that client scenery preparation still displayed the completed Taking cover stage. The client now reserves the final fifth of its construction progress for remaining soldier poses and scenery/batch work. The counter-based regression passes: pose completion advances progress, scenery has its own stage, and neither queue may remain when Ready is announced. This is a progress-reporting change after the measured export; it does not remove or defer preparation work. Packages are rebaked because the world source identity changed. The source-tree public host/client repeat timed out after 600 s without a handshake or script errors; its cause is unresolved. A debug-export attempt could not run because only release export templates are installed. The successful release-export rejoin check remains separate evidence. The final source-tree private-server load completed cleanly in both Forward+ and Compatibility with reduced motion, and the settled loading capture shows Preparing soldiers at 70%. All three final packages passed bake readback and source/checksum validation. Linux CI on the preceding commit passed both map modes and the complete gameplay suite.

## Final matched measurements

| Run | Deploy to playable | Host navigation ready | First-pan frame p50 / p95 / p99 | Worst frame |
| --- | ---: | ---: | ---: | ---: |
| Prepared 1 | 51.449 s | 8.776 s | 26.858 / 53.247 / 513.355 ms | 771.086 ms |
| Generated 1 | 126.552 s | 58.437 s | 27.241 / 61.248 / 298.161 ms | 514.961 ms |
| Generated 2 | 127.224 s | 70.290 s | 27.996 / 47.980 / 519.086 ms | 779.292 ms |
| Prepared 2 | 50.649 s | 7.793 s | 27.288 / 46.178 / 530.157 ms | 778.136 ms |

The mean full wait fell from 126.888 s to 51.049 s (59.8% less) in this four-run comparison. This isolates prepared-map reuse: both controls use the final build's other loading improvements. It does not establish a percentage gain over the original public release. Prepared host map restoration itself took 2.609–2.682 s; client scenery still used 16.1–16.2 s of measured construction work. Stages overlap and should not be summed. Every private simulation was at 100 ms when revealed, so the improvement did not advance combat unseen.

The first pan still contains roughly 0.5–0.8 s stalls in both paths. This change does **not** establish smooth first movement or sustained 60 FPS. Peak client RSS was 2.38–2.46 GB prepared versus 2.39–2.44 GB generated; peak server RSS was 0.929–0.930 GB versus 0.933–0.935 GB. These are sampled working sets, not VRAM or total system memory. The measured packages added 118,919,118 bytes before installer compression (the final progress-reporting rebuild is 118,918,039 bytes). Windows includes them; the browser export excludes them.

Compact machine-readable evidence: [prepared-battlefields-results.json](prepared-battlefields-results.json). Full local logs and captures: C:/temp/frontline-matched-final-{cached-1,generated-1,generated-2,cached-2}/. Generated and prepared town captures were visually inspected for ground, road and scenery consistency. Small-window and reduced-motion selection checks passed; the existing small text and overview road-strip appearance were not redesigned here.

## AAA comparison and target

Forspoken's developers describe roughly 1–2 second loads on some NVMe SSDs and
about 10 seconds on SATA SSDs, explicitly depending on hardware. This is a
published developer claim, not a measurement on this machine or the same work:
[PC loading explanation](https://steamcommunity.com/app/1680880/discussions/0/3766732716817835011/).
PlayStation describes near-instant character switching and fast travel in
Spider-Man 2, which is streaming within a prepared world rather than generating
a new simulation:
[official game page](https://www.playstation.com/en-us/games/marvels-spider-man-2/).

These are useful expectations for prepared content, not a fair numerical
benchmark against Frontline's procedural generation. The relevant design lesson
is to ship expensive static work and measure the complete player wait. A
sub-10-second prepared-map load is an aspiration for this investigation, not an
achieved result or a promise. Report remaining compilation, model preparation,
navigation and first-camera stalls even when a map component becomes faster.

## Further options

- Keep the prepared maps and loading-only model budgets from this change. They
  remove repeatable terrain/navigation work while preserving current commanders
  and simulation state. Desktop package size grows by about 119 MB.
- Prewarm a reusable private simulation process while the player browses the
  menu. This could overlap compilation with choosing a map, at the cost of
  background CPU and memory. It needs cancellation, crash and idle-lifetime
  handling; it is not implemented or timed here.
- Bake reusable scenery meshes and character pose data. This targets the
  remaining client construction work but increases shipped assets and requires
  checks across graphics backends. Measure first-camera movement as well as
  the curtain, so the cost is not simply deferred into play.
- Download only the selected prepared map in the browser, with versioned cache
  and checksum checks. This trades generation time for network transfer without
  putting every map into the initial website payload. It is not implemented.
