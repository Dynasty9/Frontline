# Rust simulation migration

Status: **desktop solo and multiplayer battles run in the separate Rust server;
browser solo battles run the same Rust simulation in a Web Worker.** Remaining
presentation checks and frame-time targets are still being completed. This
branch is not ready to release.

## Process boundary

Godot authors the initial battlefield in a short-lived headless process, then
exits. `frontline-server` loads that handoff and owns every subsequent gameplay
tick. The visible Godot process sends orders and draws filtered observations.
Local play connects over loopback; remote clients use the same application
protocol. Rendering never advances gameplay randomness or decides a casualty.

| Component | Owner |
| --- | --- |
| Infantry, vehicles, drones, ordnance, buildings and entity lifecycle | Rust `frontline_core` |
| Combat, injuries, rescue, prisoners, transport and construction | Rust `frontline_core` |
| Squads, perception, pathfinding, morale and tactical plans | Rust `frontline_core` |
| Economy, visibility, supply, support and victory rules | Rust `frontline_core` |
| Strategic commanders, naval plans and all five mission programs | Rust `frontline_server` |
| Authenticated commands, input ordering, checkpoints and verification | Rust `frontline_server` |
| Initial procedural map authoring and immutable content export | Godot, before the first tick |
| Models, animation, smoothing, effects, sound, camera, minimap and UI | Godot client |

The GDExtension in `native/src` remains necessary for map preparation and reference
comparisons. The engine-independent code in `native/core` and `native/server`
contains no Godot objects. The old GDScript simulation remains as a parity
reference. Browser map preparation uses the WebAssembly GDExtension once, then
releases the authoring world before starting the Rust worker and visual client.

## Socket protocol

Raw ENet/UDP carries versioned application messages, not Godot scene RPCs.
The 16-byte header contains `FLNP`, protocol version, message kind and sequence.
Reliable channel 0 carries authentication, orders, baselines, births, removals,
properties, ground tiles, roads, HUD updates, messages and reports. Channel 1 carries independently
applicable tick-stamped entity snapshots. Channel 2 carries expendable effects.

The trusted host supplies a 192-bit ticket, commander identity and team for each
admitted player. Clients present their ticket and exact simulation build ID;
they cannot supply another commander or choose a team through a gameplay packet.
Commands are bounded and checked again against current ownership and resources.
New connections and reconnects receive their own reliable baseline. Hidden enemy
IDs and private supply, orders and intelligence are filtered before transmission.
Map and large report data are chunked. Reliable queues, acknowledged bytes,
command rates and per-frame client parsing are bounded; a stalled peer is closed.

Protocol 3 sends the current deformation and crater layer in the compressed map
baseline, then absolute 32 m surface tiles on the reliable channel. Tiles are
idempotent and retained for late joiners; explosions only play cosmetic effects
on socket clients. Loading queues the latest copy of each tile, then applies a
bounded amount per frame through the existing progressive terrain texture upload.
Replay seeks receive the ground at the re-simulated tick. Roads also have current
baselines and reliable updates.

Simulation ticks run at 60 Hz. Observations currently publish at 15 Hz, with Godot
interpolation independent of tick advancement. Catch-up work is bounded; a slow
host changes wall-clock pacing without skipping deterministic simulation ticks.
Pause and playback speed change pacing, not the simulation delta.

Desktop packaging includes the server beside the Windows/Linux executable and
in `Contents/Helpers` on macOS. The updater installs and rolls back the game,
GDExtension and server together. Closing a game asks its owned server to finish
and flush the recording; unrelated applications are never stopped.

The browser worker replaces only the socket transport and filesystem. It uses
the shared FLNP packet encoder, simulation tick, command validator and FLRP
recorder/verifier. Its identity comes from the starting state, not from commands.
One packet bundle is transferred at a time; Godot consumes it within the same
2 ms packet-processing budget as socket clients. Worker catch-up is capped at
four ticks per turn. Browser multiplayer still requires the desktop build.
Leaving through the menu saves the finished recording to browser-local storage;
force-closing the tab cannot guarantee that final asynchronous write.

## Deterministic recording and verification

`.flrp` command recordings contain the exact initial checkpoint, simulation build
and content identifiers, ordered admitted commands, joins and disconnects, then
a declared final tick, state hash, input-chain hash and winner. They do not record
AI decisions: the verifier recomputes them. Initial checkpoints retain all random
streams, entity allocation, task queues, timers, navigation, commanders and mission
state. A seed and visible entity snapshots alone are insufficient.

`frontline-server verify RECORDING` independently restores and advances the battle
without Godot, graphics or network access. It rejects incompatible builds/content,
malformed or reordered inputs, truncation, trailing data, changed input digests
and a different final state or winner. A recording stopped before victory can be
verified as an unfinished battle; it is not a verified victory. Existing Format 1
observer archives remain a different format and are never relabeled as verified.

Verification establishes consistency with the supplied starting state and inputs.
It does not authenticate a client-created history. Competitive result acceptance
must additionally trust the server that admitted and recorded those inputs.

The native replay viewer opens `.flrp` files from the Replays menu or `--replay`.
Its play/pause, speed and timeline controls drive a private Rust playback process
using the same parser and tick entry point as the verifier. Seeking re-executes
from the starting state and reconnects a fresh observer so transient effects and
entities cannot survive a rewind. Seeking far into a long battle therefore costs
simulation work; it does not load an unverified visual snapshot as game state.
A readable footer supplies the timeline length only. The viewer labels the result
verified after the input digest, final state hash and winner all match, including
when seeking directly to the end. It distinguishes unfinished battles from
concluded games. Viewer commands and connections never enter the recorded world.

Full seed-1 mission playthroughs use the normal mission autopilot, then independently
verify the entire command recording. The November 3 numeric-4 run reached these
unmodified conclusions: Bridgehead victory at tick 10,219; Beachhead victory at
10,975; Ambush victory at 8,278; Kingpin defeat at 14,106. Each final checkpoint and
winner matched verification. Skyhook initially remained unfinished at tick 108,000
(30 simulated minutes): the old Godot mission also stranded its convoy on
disconnected mountain terrain. Preparing reachable vehicle approaches before the
battle fixes that stall without changing its objectives or autopilot. The corrected
Rust mission reaches defeat at tick 22,848; independent verification matches hash
`588d13dc030186525dac4aec29dab214754e135783fc2b939a0fc9fec99e08f1`.
These results do not claim every autopilot wins.
The manual `natural_mission_reaches_and_verifies_its_conclusion` test accepts
`FL_PLAYTHROUGH_INITIAL` and a new `FL_PLAYTHROUGH_RECORDING` path. Initial states
are authored with `--mission=KEY --seed=1 --export-simulation=PATH --port=UNIQUE`.

Numeric version 4 pins Rust 1.94.0, glam 0.32.1 with `libm`, and libm 0.2.16 with
`force-soft-floats`. Gameplay iteration, tie-breaking and work quotas have explicit
orders. Cosmetic randomness and wall-clock/network scheduling are outside state.
Cross-platform tests compare committed numeric transcripts and complete mission/
commander checkpoints in debug and release without tolerances. Godot parity tests
separately allow documented differences from the engine's platform math functions.
These covered trajectories are not a proof for every possible floating-point input.

Large map handoffs and server checkpoints compress their largest state block with
zlib in independent 64 KiB blocks. The versioned `FLZB` envelope records the exact
expanded size; decoding validates each stream's checksum, consumed bytes and
output length before appending it. The outer file limit remains 512 MiB and the
expanded match limit is 1 GiB. Raw core checkpoints retain their canonical bytes,
so the numeric gameplay goldens do not change. Compression does not quantize
positions, terrain, timers or random state. The Godot handoff is `FLIN` version 2
and the server checkpoint is `FLSS` version 2; older builds remain fail-closed.

The generated 3,072 m test reached 14,352 entities and 91 squads but exceeded the
old 512 MiB initial-state limit before simulation could start. That failure is
recorded in `build/rust-socket-generated-3072-cap-check/`. The compressed repeat
completed successfully; its performance and replay results are recorded below.

## Build and exercise

Run from the repository root with Rust 1.94.0 and Godot 4.7.2 installed:

```text
python tools/build_native.py
godot --headless --path . --import
godot --path . -- --local-server --mission=bridgehead --seed=1
cargo +1.94.0 test --locked --manifest-path native/Cargo.toml -p frontline_core -p frontline_server
godot --headless --path . res://tests/local_server_test.tscn
godot --headless --path . res://tests/native_lobby_test.tscn -- --port=7985
```

The launcher stores logs in `user://local_servers/` and recordings in
`user://replays/battle-<session>.flrp`. `FRONTLINE_SERVER` selects a server binary
in a source checkout. Set `FRONTLINE_GODOT` and run the ignored `godot_connects`
network test to exercise actual Godot/Rust ENet interoperability.

Desktop multiplayer uses the existing Godot ENet lobby as an opaque packet relay,
preserving its port and NAT mapping. The host renderer connects directly to Rust;
each remote player has a separately authenticated Rust connection behind the relay.
The lobby updates a private admission list and waits for Rust to acknowledge it
before opening a new connection. Tickets never enter broadcast lobby settings.
Joins, departures and ownership reclamation are recorded as authoritative inputs.
New arrivals receive the same starter squads at the earliest completed FOB as before.
Screen presence, pings and sketches are separately validated, rate-limited and
filtered to teammates and observers. Action notifications come from completed
simulation commands. These presentation messages do not affect replay state.

Public broadcasts use a separate trusted, read-only recorder ticket (peer -1).
It receives an omniscient render stream, with reliable snapshots and effects so
a lost static-state delta cannot leave a permanent hole in the archive. It never
joins the player roster, starts the match clock, submits commands, or changes
the canonical checkpoint. The host caches plain records and encoded state in
small entity-ID blocks; it creates no second Godot World or entity scene tree.
The winning tick's state and HUD precede the final report and end message.

Listed, unlocked games upload seekable format-2 observer archives through the
existing bounded, delayed replay service. Private games stay local. Archives
contain compressed terrain baselines and absolute ground updates, current roads
and public entity/HUD state; connection settings and tickets are excluded.
Successful broadcasts add their public replay ID to after-action reports through
the host's trusted control file, without modifying simulation state. The viewer
still reads format 1, advertises both formats, and keeps observer archives
explicitly unverified. The independent `.flrp` recording remains the source for
deterministic verification; uploading an observer archive cannot certify a win.

The native upload integration test records a Rust battle through a local
matchmaker, downloads every completed observer chunk, seeks both directions,
and independently verifies the separate command recording. The exported Chromium
test also loads the HTTP observer archive and seeks to its end and start after
verifying a browser-worker command replay. The existing model viewer still loads.
The website's 245 tests and matchmaker's 65 tests pass, including format negotiation
and refusal to label observer recordings as verified.

A generated initial state can also be run without a renderer:

```text
godot --headless --path . -- --mission=bridgehead --seed=1 --export-simulation=build/bridgehead.initial --port=7961
frontline-server run build/bridgehead.initial build/bridgehead.flrp 180
frontline-server verify build/bridgehead.flrp
```

`prepare INITIAL CHECKPOINT` imports without advancing. `serve INITIAL CONFIG
RECORDING` starts the socket host. Its private JSON config contains `bind`, admitted
`players` (`peer`, `team`, `name`, `token`) and optional `ready`, `stop`, `speed`,
`error` control-file paths. A private launcher can supply a `lease` heartbeat path;
the server finishes its recording if that owner stops renewing it for 30 seconds.
An optional `profile` (`path`, `warmup`, `duration`) measures wall-clock tick,
observation and individual simulation-phase costs outside deterministic state.
`infantry` includes its `infantry_*` breakdown (setup, status, perception, decisions,
duties and finish); do not add those subphases to the inclusive total again.
The clock never changes AI work quotas or enters a checkpoint. Keep admission tickets private. The initial importer
rejects already-running Godot worlds with active ordnance/plans rather than
silently losing state. Output recordings are created exclusively, never overwritten.
An optional `admissions` path accepts atomic updates containing `players` and a
lobby revision. The server writes the applied revision beside it with an
`.admitted` extension. Revoked connections close before replacements are admitted.
The application protocol is `FLNP` version 3; the Godot lobby version is 14.

## Validation and remaining completion gates

The preceding commit, `30b6019`, passed the complete Godot comparison job and debug/
release Rust checks on Windows x64, Linux x64, Linux ARM64 and macOS ARM64.
Current socket checks cover two teams, admission failures, privacy, bounded
messages, event projection and Godot interoperability. The normal launcher check
covers movement orders, pause/resume, ownership after reconnect, graceful recording
completion, independent verification and an owned-server crash. An 80-soldier
rendered socket battle completed without script errors. These are not 500-unit
rendering results or natural full-mission balance playthroughs.

The lobby integration check now passes two remote clients, joining after start,
commands that move replicated troops, team-only pings/sketches/presence, a lost
connection during generation, a later reconnect with a new ENet identity, ownership
recovery, private-ticket isolation, and independent verification of the resulting
recording. Rust socket tests also reject identity spoofing and revoked tickets,
preserve a live connection when the admission list is reordered, and enforce mark
limits and team privacy. Drop-in starter squads and reconnecting without duplicate
reinforcements have a deterministic replay regression.

Remaining release gates (latest measurements are recorded below):

- Meet the tail-frame budget in generated large-map, 500-unit rendered cases;
  average FPS alone is not a pass. Continue measuring with other apps running.
- Complete exports/installers and current-head cross-platform CI. Preserve gameplay
  with full scenario/mission regressions and visible comparison evidence.

The cosmetic lifecycle audit covers removed trees, burning buildings, artillery
recoil, surrender, death impulses and ships sinking after they leave the live
registry. The current observer and actual Godot/socket fixtures pass these cases.

Browser validation on 3 November: the real Chromium export generated a 1 km
battle with 20 soldiers, sent a move order, replicated movement, paused its clock,
saved on exit and reopened at a verified final tick (`BROWSER_SERVER_TEST failures=0`).
The native session test produces byte-identical commands, checkpoints and
recording bytes to `frontline-server`; the actual JavaScript worker also replays
the native fixture and a fresh WebAssembly instance verifies its live recording.
These are correctness checks, not browser FPS or 3 km memory measurements.
The production model-viewer bridge also rendered its Hunter after the battle test.
The reproducible web build completed, and a packaged Windows executable started
its Rust child and received all 24 entities in the 20-soldier fixture without script
errors. Native launcher/reconnect/recording regression and shared render-packet
server tests pass; current-head Linux/Docker and cross-platform CI remain release checks.

The 3 km navigation breakdown in `build/rust-socket-generated-3072-navigation/`
measured 74.59 FPS, frame p99 26.66 ms, and Rust tick p99 35.72 ms. Path searches
alone peaked at 45.08 ms; terrain-cover work peaked at 0.019 ms and hierarchy
repairs at 8.93 ms. This isolates long searches as a remaining simulation target;
the average frame rate does not establish steady 60 FPS. Other applications stayed
running. Socket clients now skip GDScript terrain reconstruction because the
baseline includes the completed surface; the follow-up below measures loading.

The next 3 km run, `build/rust-socket-generated-3072-path-detail/`, measured
67.46 FPS and frame p99 28.96 ms with other applications running. Rust ticks
averaged 11.62 ms, p99 34.83 ms. Of 3,983 path queries, 525 reused cached paths
and 83 failed. Global routing consumed 2.99 ms per tick on average and peaked
at 42.02 ms; local refinement peaked at 3.24 ms and smoothing at 1.19 ms.
There were 83 global-route samples over 16.67 ms. This points to failed searches
exhausting disconnected regions, rather than local refinement or smoothing.

The connectivity cache groups the permanent hierarchy graph. Temporary query
anchors and danger costs keep the cache; permanent links and border edits discard
it. Endpoints still attach and allocate in the same order, but disjoint component
sets return no route without an exhaustive A* traversal. Team graphs must have
matching topology when restoring a checkpoint. All 140 numeric transcripts still
match, including route choices and subsequent simulation state. The separate
stronger-heuristic experiment passed shortest-cost tests but changed six transcripts;
it was not included in this connectivity measurement.

The connectivity run (`build/rust-socket-generated-3072-connectivity/`, `8b5d601`)
reduced expanded graph nodes from 7.12 million to 2.83 million. Path preparation
fell from 3.36 to 1.85 ms per tick on average; path p99 fell from 25.72 to 12.89 ms.
Total Rust tick mean/p99 fell from 11.62/34.83 to 10.01/24.54 ms, with 110 of 1,199
ticks exceeding 16.67 ms. Rendered average was 69.46 FPS, frame p99 26.21 ms and
maximum 37.84 ms. Other applications remained running; these measurements still
miss the smooth-60 target. The slowest rendered frame included 16.21 ms of
snapshot processing. Per-frame view reports now expose these occasional costs
as well as average view totals.

The exact benchmark server independently verified all 3,018 recorded ticks and
final state `21ae4023f9e5a002fa33be114430ac2a4b7310db9df0a6c2ceb21410f6c9ad7a`.
The recording ended before victory and is verified as an unfinished battle.

Replaying that exact battle traced the long snapshot update to a burning roof:
creating its flame and ember particle programs took 16-21 ms. Temporary prewarm
nodes were freed along with the last references to their particle materials.
Godot then discarded the shared particle shaders and compiled them again on the
first visible fire. The client now retains those few materials for the match,
including the temporary smoke-screen and missile-trail programs, while freeing
their nodes normally. A focused rendered test measured first-fire construction
at 26.49 ms before and 0.53 ms with retained programs. Replaying the same command
recording reduced maximum snapshot processing from 21.46 to 2.08 ms. The automatic
replay director selected different camera views between runs, so their overall
frame rates are not a controlled comparison. Camera movement still exposes
scenery-construction spikes. A focused test traced the separate VFX spike to
first-use dirt-clod rendering: 16.50 ms before prewarming and 0.12 ms after.
The client now creates and draws that shared mesh below ground during loading.
Scenery batching collects one model or uploads one material surface per step,
checking the frame budget between steps. Original meshes stay visible until the
whole block is ready; changes or despawns cancel an unfinished replacement.

Numeric contract 3 also strengthens hierarchy A*'s distance estimate using the
minimum cost of a complete midpoint crossing. Independent Dijkstra comparisons
check shortest costs with roads, danger weights and disconnected goals. Six of
the former 140 exact transcripts changed through route tie-breaking; the other
134 matched before the deliberate version bump. The old corpus remains in Git
history, and incompatible checkpoints are rejected. Current local release checks
pass the complete core and server suites, all 140 new transcripts, and actual
Godot/Rust socket interoperability at `fa99fe8`.

That experiment's 3 km run measured 63.59 FPS, frame p99 32.79 ms, and Rust tick
mean/p99 11.48/29.54 ms. Expanded route nodes increased to 4.32 million. Inspection
of the actual starting graphs found infantry's minimum weight was 0.69998; the
fixed 0.5 estimate had weakened it. Numeric contract 4 instead uses
`(1 + minimum_weight) / 2`, retaining the valid bound without weakening an existing
estimate. New checks cover both cheap midpoint edges and ordinary road weights.
The corrected 3 km run examined 1.87 million route nodes, versus 2.83 million
in the connectivity control, with route p99 7.98 ms instead of 10.09 ms. Overall
performance still missed the target: 58.74 FPS, frame p99 34.56 ms, and Rust tick
mean/p99 11.31/28.28 ms. Other applications remained running; these separate
desktop runs establish reduced search work, not an overall FPS improvement.
Reports are in `build/rust-socket-generated-3072-adaptive/`. Its exact server
independently reproduced all 3,023 recorded ticks, with final state
`375fff0b8448bcd05b549f3347adb96440780f63b6d292046586928e1bc5fa25`.
The battle was unfinished. Local numeric checks pass; cross-platform checks of
version 4 remain pending.

Scenery now carries a noncanonical mutation revision. Observation generation
reuses unchanged structure state until its periodic unreliable-state refresh;
visibility filtering still runs every update. Restoring, cloning and replacing
actors cannot reuse a stale revision. These cache stamps never enter gameplay
state or recordings. The 140 core transcripts remain byte-identical after this
cache change, and server observation tests cover supply changes, hidden state,
replacement, spawn/removal order and periodic refresh.

An alternating microbenchmark with 14,000 walls and 500 soldiers measured mean
observation cost of 6.54/6.59 ms before and 4.45/4.30 ms after, about 33% lower.
p99 fell from 9.32/9.69 ms to 7.02/6.04 ms. Each run emitted the same 132,933
entity-state rows. No other task benchmark or build ran during those samples;
the user's other applications stayed running. Full-game measurements are still
needed because this isolates observation generation, not simulation or rendering.

The subsequent generated 3 km run with scenery revisions and clipped order-line
drawing measured 59.20 FPS, frame p95/p99 24.92/33.57 ms and maximum 61.62 ms.
Adjacent-frame difference p95/p99 was 10.51/15.17 ms, compared with 12.83/17.69 ms
in the adaptive-search control. Rust tick mean/p99 was 10.76/24.63 ms, with
observation mean/p99 1.54/8.68 ms. The search examined the same 1,865,398 nodes.
Order drawing p99 was 1.76 ms; in the fixed-camera replay control it was 2.83 ms.
The dash regression checks perspective and orthographic clipping against original
visible segments, preserving their order and spacing. Routine roster refreshes
defer at most one frame when the battlefield overlay also refreshes.

These runs still fail the frame and simulation budgets. Other applications remained
running, and the figures are separate desktop samples. Reports and the inspected
render are in `build/rust-socket-generated-3072-revisions/`. A retained-marker
prototype only moved average FPS from 60.13 to 61.60 while frame p99 rose from
31.21 to 31.62 ms in matched replay runs; it was removed.

The version-3 run nevertheless confirms the first-use fixes: maximum snapshot
processing was 2.04 ms and VFX 0.14 ms. Its exact server independently verified
all 3,028 recorded ticks, final state
`f1eef62b75131c4370ee20cfaa1056656cf07b8d4e33a9cced90b9a823eba124`.
The battle was unfinished. Reports are in
`build/rust-socket-generated-3072-heuristic/`; other applications stayed running.

Presentation tests cover artillery recoil, rifle drops for visible surrendering
enemies, and retained grass-fire state after loading and replay seek. Fire effects
deduplicate overlapping ignition/bootstrap messages without changing gameplay.

Client loading in that control fell from 79.12 to 28.81 seconds, with the ground
stage completing at 18.28 rather than 67.49 seconds. These are elapsed loading
milestones from separate desktop runs, not isolated CPU measurements. The complete
harness took 399.70 seconds, including map generation and shutdown, and reported
no script/server errors. Rendering still misses the frame-time target.

## Standalone infantry scale measurement

On November 2, 2026, the release server with initial navigation finalized ran 600 fixed ticks with 500
soldiers, two depots and the production rifle/fighter loadouts. Other applications
remained running. Each map produced 4,047 shots, 269 soldiers moving more than one
metre and 423 survivors; the benchmark asserts movement and combat occurred.

| Square map side | Mean tick | p95 | p99 | Maximum | Initial setup |
| --- | --- | --- | --- | --- | --- |
| 1,024 m | 3.202 ms | 4.527 ms | 5.723 ms | 7.945 ms | 616.19 ms |
| 2,048 m | 2.775 ms | 3.695 ms | 4.671 ms | 8.231 ms | 2,675.80 ms |
| 3,072 m | 2.823 ms | 3.776 ms | 5.285 ms | 9.758 ms | 6,600.55 ms |

These are short simulation-only samples on flat, mostly empty maps, without
strategic commanders, scenery, rendering or socket traffic. They are not a
before/after comparison with the original Godot measurement or proof of 60 FPS.
The smaller timing differences between map sizes are within uncontrolled desktop
variation. Larger maps increase startup memory/work; the tick does not scan the
entire map just because its dimensions increase.

Run the ignored benchmark explicitly in release mode. `FL_BENCH_SIDE` accepts
1024, 2048 or 3072:

```powershell
cargo +1.94.0 test --locked --release --manifest-path native/Cargo.toml -p frontline_server --test scale -- --ignored --nocapture --test-threads=1
```

## Rendered 500-soldier socket measurement

On November 3, 2026, a 12-second sample after eight seconds of warm-up used 500
soldiers, 200 scenery objects and active combat on the 1,024 m stress map. The
Godot renderer used the high preset at 1280 by 720 on an RTX 3090. Other apps
remained running. The client reported 499 living soldiers; the server had recorded
3,271 shots by its sample end. Simulation and rendering were separate processes.

| Measurement | Mean | p95 | p99 | Maximum |
| --- | --- | --- | --- | --- |
| Rendered frame | 95.3 FPS overall | 15.87 ms | 19.10 ms | 26.36 ms |
| Rust tick including observation generation | 3.86 ms | 5.66 ms | 6.55 ms | 27.58 ms |
| Simulation and input recording | 3.73 ms | 5.52 ms | 6.03 ms | 27.58 ms |
| Observation/event generation | 0.13 ms | 0.60 ms | 0.95 ms | 1.71 ms |

Frame-to-frame absolute differences were p95 8.19 ms and p99 11.21 ms. The largest
measured client categories averaged 2.22 ms/frame for distant soldier presentation,
1.36 ms for soldier views and 0.72 ms for minimap drawing. Peak sampled process RSS
was 2,223 MiB for Godot and 621 MiB for Rust. Startup and warm-up are excluded.

This sample exceeds 60 FPS on average but fails the tail-frame target. One Rust
tick also exceeded 16.67 ms. It is a stress layout, not a fully generated 2–3 km
battlefield, and is not directly comparable to the original 130 ms observation.

## Generated 2 km battlefield and phase costs

The November 3 follow-up used the generated 2,048 m map, seed 3, 500 infantry,
commanders and 8,640 entities, with the high preset at 1280 by 720. Each sample
measured 20 seconds after 15 seconds of warm-up. Other applications remained
running. Both the control and optimized builds used the separate Rust server.

| Measurement | Instrumented control | Optimized `cfad834` |
| --- | ---: | ---: |
| Rust tick mean, including observations | 9.569 ms | 7.405 ms |
| Rust tick p95 / p99 | 16.321 / 20.313 ms | 13.128 / 16.308 ms |
| Simulation and recording mean | 8.383 ms | 6.393 ms |
| Infantry mean | 4.154 ms | 3.374 ms |
| Rules and ledger mean | 1.272 ms | 0.770 ms |
| Vehicle phase mean, with no vehicles | 0.663 ms | 0.001 ms |
| Rendered average FPS | 73.64 | 74.98 |
| Frame p95 / p99 | 21.128 / 25.877 ms | 20.722 / 25.907 ms |
| Adjacent-frame difference p95 / p99 | 10.691 / 14.422 ms | 10.736 / 14.641 ms |

Prepared weapon profiles, indexed supply/statistics scans, reused snapshot buffers
and shared team observations reduce repeated work without changing AI cadence.
Stationary minimap camera wedges cache their ground intersections. The optimized
minimap cost was 0.763 ms/frame; distant soldier batches cost 2.118 ms/frame and
soldier presentation 1.291 ms/frame. A transform-cache prototype did not improve
rendered timings and was removed.

The clean optimized run had no script/server errors and 482 surviving soldiers at
server tick 2,102, with 6,310 shots. The earlier control ended at tick 2,101 with
482 survivors and 6,303 shots. Fixed-state numeric/replay tests, rather than these
wall-clock sampling boundaries, check unchanged gameplay. The first optimization
run exposed wildlife reading ground while a loading worker replaced it; the
repeat above includes the loading guard and its regression check.

The roughly 23% reduction concerns server tick time, not FPS. Navigation still
peaked at 18.30 ms, total ticks at 26.54 ms, and frames at 37.40 ms. Eleven of
1,200 server samples exceeded 16.67 ms. This is progress toward the frame target,
not proof of sustained minimum 60 FPS. Raw local reports are in
`build/rust-socket-generated-2048-phases/` and
`build/rust-socket-generated-2048-optimized/`.

The generated 3,072 m repeat at `2b8da93` used the same seed, 500 infantry,
commanders, preset and measurement window, with other applications running.
It completed without script/server errors: 72.56 FPS average, frame p95/p99
21.673/26.507 ms, and adjacent-frame difference p95/p99 10.670/14.205 ms.
The Rust tick averaged 11.613 ms, with p95/p99 28.483/36.183 ms. Navigation alone
averaged 3.408 ms and peaked at 50.167 ms; infantry averaged 3.803 ms. Thus the
larger map works but still misses the minimum frame and tick budgets. The client
spent 73.15 seconds loading after its terrain allocation; the complete harness
took 442.61 seconds including generation and shutdown.

Reports and the rendered view are in `build/rust-socket-generated-3072-compressed/`.
Independent verification reproduced all 3,023 ticks of its command recording,
matching final hash `ac892adeaad9a10f3d39de02d26bf10a09b832902a60024083bb2b8a80fd3627`.
The battle was unfinished, with no declared winner. Verification output is in
`build/verify-3072-compressed.log`.

The distant-soldier regression view places the same baked rifleman at 180 m with
an unchanged camera and lighting. The before image restores the former fixed
bounding box; the after image runs the corrected batch update. The CPU fixture
also checks a soldier below the waterline and preservation of spatial batching.

| Former bounds | Bounds expanded to the actual soldiers |
| --- | --- |
| ![Soldier incorrectly culled at elevation](screenshots/rust-simulation/batch-bounds-before.png) | ![The same soldier remains visible](screenshots/rust-simulation/batch-bounds-after.png) |

Distant soldier transforms now use GPU exponential smoothing between socket updates.
CPU positions retain the same smoothing for selection and detailed-model transitions.
Pose changes, camera movement, teleports, visibility and despawns refresh immediately;
ordinary packet motion uploads on the next rendered frame. A colored asymmetric
model at large coordinates matches CPU translation, wrapped yaw and lighting in
both Compatibility and Vulkan, with tests for fog, teleport and LOD transitions.

A fixed-camera replay of the same 3 km, 500-unit recording at 1280 x 720 High,
with other applications running, reduced mean distant-batch CPU work from 2.348 ms
to 0.671 ms (71%). The control averaged 68.54 FPS and the revised run 72.99 FPS.
Frame p99 was 24.85 ms before and 26.21 ms after; adjacent-frame difference p99
was 12.56 ms before and 14.81 ms after. This saves repeated transform work but
has not established lower frame-time tails or steady 60 FPS. The full reports
are `build/smoothing-cpu-replay.json` and `build/smoothing-deferred-replay.json`.

Squad strength indicators now retain their colored quad geometry while strength
is unchanged, using one mesh draw instead of two rectangle draws per soldier.
Vulkan and Compatibility image comparisons cover fractional placement and opacity
with mean pixel difference 0.000086. In a fresh controlled replay pair, squad-symbol
mean CPU time was 0.507 ms before and 0.485 ms after (p99 3.899/3.709 ms).
Sampled draw calls fell from 4,295 to 3,672. Overall FPS was 79.38/78.13 and frame
p99 was 25.08/25.55 ms; no overall frame-rate improvement is established by this
small batching change. Reports: `build/strength-{rects,mesh}-replay.json`.

Minimap soldier dots now share a MultiMesh draw; the map transform and team
colors are prepared once per update. The existing progressive layer schedule
and live camera wedge are unchanged. Vulkan and Compatibility comparisons match
the original pixels for 500 overlapping, selected, wounded and clipped soldiers,
including rotation, resizing and despawn. Focused dot-update CPU time fell by
56–58%. In the full 3 km replay, total minimap CPU work averaged 0.867 ms before
and 0.721 ms after (17% less), with p99 decreasing from 2.162 to 1.500 ms.
FPS was 72.12/82.06, frame p99 26.457/25.481 ms, and adjacent-frame difference
p99 15.054/13.995 ms. Other applications remained running, so the overall FPS
change is not solely attributable to this optimization. Steady 60 FPS remains
unproven. Reports: `build/minimap-{rects,batch}-replay.json`.

Supply dispatch and FOB enumeration use the existing active-structure index,
avoiding full scenery scans. Infantry build their activity context only when
the existing status timer expires. All 140 numeric fixtures retain their exact
expected state; focused regressions cover scenery, restored indices and status
changes between refreshes. No new simulation performance claim is made for
these changes until the generated-map benchmark is repeated.

## Close-camera model budget

The 3 km / 500-unit control replay at zoom 35 exposed a separate rendering
bottleneck: many nearby articulated soldiers each carry multiple material surfaces.
The renderer now reserves full articulation for 16 visible soldiers, preferring
selected troops and then proximity, with hysteresis to prevent swaps at a tie.
Every other soldier remains visible through the existing shared poses. Simulation,
fog, selection and commands retain the complete army.

On the same 1280 x 720 High replay, with other applications left running:

| Measurement | Unbounded nearby detail | 16 detailed models |
| --- | ---: | ---: |
| Average FPS | 30.02 | 65.74 |
| Frame p99 / maximum | 61.59 / 75.79 ms | 28.62 / 38.10 ms |
| Adjacent-frame difference p99 | 23.92 ms | 16.60 ms |
| Sampled draw calls | 15,714 | 4,424 |
| Soldier view mean / p99 | 5.129 / 14.884 ms | 2.177 / 4.354 ms |
| Render CPU median | 10.491 ms | 3.705 ms |
| GPU median | 8.500 ms | 4.708 ms |

This exceeds 60 FPS on average but still misses the minimum-frame target.
The largest remaining frame included a new detailed model plus HUD and shared
pose work. The detail-budget fixture checks the cap, selected-unit priority,
hidden/despawned exclusion and immediate refresh on camera turns. Existing
smoothing, visibility, pose and despawn checks pass. Reports are
`build/close-detail-control.json` and `build/close-detail-16.json`; paired screenshots
are included in the changelog. A material-per-joint LOD prototype was discarded:
it reduced draws but its extra mesh construction worsened frame-time tails.

The presentation lifecycle audit also covers retained data for removed trees and
sinking boats, post-despawn sinking effects in Godot, death impulses, recoil,
surrender and persistent fires, without changing canonical state. Twelve observation
tests, ten socket tests and the real Godot socket/replay check pass. Cursor presence
tests now refresh their intentionally unreliable packet, matching normal clients;
the previous send-once assumption caused a macOS CI timeout.

### Indexed observations and spread visual work

The next live 3 km / 500-soldier generated battle averaged 74.06 FPS, frame p99
26.58 ms and maximum 35.53 ms. Rust tick mean/p99 were 8.74/23.00 ms; rules and
ledger mean fell to 0.226 ms after using the active-building index. The saved
server independently verified all 3,019 recorded ticks as an unfinished battle,
with final hash `8c7a5b7fd2913661502861bbfe1d8e7dedf2bb31a91afe3667660c3af42af3f5`.
All 140 core numeric fixtures pass. Artifacts and the matching server are retained
in `build/rust-socket-generated-3072-detail-head/`.

Observation preparation now checks scenery revisions before looking up actor
state and uses hashed lookup storage, retaining registration order and explicitly
sorting removals. An alternating 14,000-scenery / 500-soldier microbenchmark measured
means of 4.144, 4.146 and 4.619 ms before versus 1.570, 1.304 and 1.212 ms after
(68% lower across these runs). Each emitted the same 132,933 rows over 180 updates.
Thirteen observation tests and ten socket tests pass, including visibility changes
after restoring actors and recovery of lost static updates. This microbenchmark
is not a new full-game FPS measurement.

Wildlife queries use 32 m cells and a separate aircraft list while retaining
nearest-threat ties and fog visibility. In 5,120 matched queries, CPU time fell
from 544,450 to 110,301 microseconds; rebuilding 200 indexes cost 159,984 instead
of 88,920 microseconds. The full close-view replay did not establish an overall
FPS gain from this change. Routine shared-pose uploads and squad-data preparation
now yield at most one frame to an overlay redraw. The subsequent close replay
measured 64.44 FPS, frame p99 30.32 ms and adjacent-frame difference p99 14.82 ms,
versus 63.28 FPS, 35.85 ms and 20.54 ms just before scheduling those updates.
Other apps remained running. Both runs still miss the frame budget; the first
16-model run above had lower frame p99 than these later repeats. Focused scheduling,
selection, fog, teleport and rendering fixtures pass.

The shutdown warning also occurs when loading scripts without creating a World:
synchronous loading leaked no objects, threaded ResourceLoader loading left seven
zero-reference RefCounted objects, and loading through WorkerThreadPool left eight.
This matches the open Godot [LoadToken leak](https://github.com/godotengine/godot/issues/120661)
and its [pending engine fix](https://github.com/godotengine/godot/pull/121025).
The probes are in `build/load-leak-{sync,threaded,worker}.log`; this is an engine
loading caveat, not evidence of retained Rust battle state. No engine fork or
synchronous-startup workaround is included.

### Prepared articulated models

Live detailed soldiers now copy pristine per-unit/team rigs prepared during
loading. Meshes and materials are shared; joints and all animation state are
independent. This reduces clothing/face variation to one appearance per unit and
team, while retaining individual breathing and death variants. Debug model views
still use the original builder. The fixture covers all unit definitions on both
teams; six representative types also render pixel-identically to the original
seed in Forward+ and Compatibility (`soldier-template-visual.tscn`). A quick-exit
music-worker lifetime error found by that fixture is fixed.

Eight alternating, warmed rounds of 30 constructions each measured 7.923 ms for
original construction and 0.816 ms for copies (90% less), including insertion
into the scene tree. The same close replay measured a 2.384 ms construction peak
versus 9.536 ms in the preceding run. Overall performance was worse in this
repeat: 56.38 FPS, frame p99 36.93 ms, adjacent-frame difference p99 15.99 ms.
Other applications remained running; this does not establish a total FPS gain.
Evidence: `build/model-copy-bench.log`, `build/close-templates.json`, and paired
render comparisons in `build/soldier-template-{forward_plus,gl_compatibility}.png`.
The preceding `73d721f` passed full Godot regressions and all desktop/browser
exports; final-head platform checks remain required.

### Bulk cosmetic collision sampling

Cosmetic heightfield tiles now sample the existing Rust terrain in one call,
replacing 1,089 GDScript/native crossings per tile. The original GDScript path
remains for comparison mode. Hills, craters, trench-mask thresholds and the far
map boundary compare byte-for-byte across four elevated fixtures, with invalid
requests rejected and canonical terrain unchanged. Both native terrain suites
and all 140 numeric contract fixtures pass.

Eight alternating warmed rounds of 50 tile samples measured 1.944 ms for the
per-sample path versus 0.0247 ms for the bulk path (98.7% less sampling work).
This excludes the engine's collision-shape update and is not an FPS measurement.
The retained measurement is `build/collision-sampling-bench.log`; an earlier
run overlapping numeric tests is explicitly excluded. The Windows release export
also completes without import or export errors.

The fresh packaged Windows 3 km / 500-soldier live battle at this revision failed
the performance target: 35.66 FPS, frame p99 49.68 ms, maximum 56.67 ms and adjacent
frame difference p99 22.96 ms. Rust ticks averaged 16.48 ms (p99 53.58 ms);
infantry was the largest simulation phase at 9.27 ms on average. Cosmetic terrain
sampling peaked at 0.019 ms. Other apps remained running. The saved server
independently verified all 3,035 ticks, with final state hash
`afe7833ff97407184d3ad7148b3d472958dc9567479e7d2746d7c604158de498`.
Artifacts are in `build/rust-release-generated-3072-collision/` and
`build/collision-release-replay-verification.log`.

A subsequent paired playback of that recording measured 74.16 FPS in the release
export and 63.00 FPS in the development runtime, with frame p99 30.77/36.98 ms and
maximum 81.98/85.58 ms. This establishes neither a live-game speedup nor steady
60 FPS; the different workload and changing background load limit comparisons.
The valid runs are in `build/runtime-comparison.log`; an earlier attempt overlapping
the browser test was stopped before measurement and excluded. Current browser
simulation, observer playback and model rendering pass in real Chromium, and the
Windows and web exports complete successfully.

The roster texture-cache experiment was rejected. In an ABBA release playback,
the original averaged 89.46/85.59 FPS (frame p99 20.16/27.48 ms) and the prototype
76.36/91.20 FPS (p99 29.55/22.04 ms). It showed no consistent frame-time benefit
and made small scaled text less legible. A separate GDScript text-width cache was
also rejected: Godot's existing measurement path took 14,709 microseconds versus
102,174 for the extra cache over 56,000 calls. Neither prototype is shipped.
Artifacts are `build/roster-comparison.log` and `build/ui-width-benchmark.log`.

### Indexed owned buildings and infantry timing

The finer infantry breakdown identified a scenery-sized scan in target-list setup.
The actor registry now retains owned buildings in registration order, updating the
list on spawn, removal and capture and rebuilding it after restore. Infantry and
vehicle phases copy that small list; commander censuses reuse it and the vehicle
index. The diagnostic callbacks do not change commands, events or checkpoints.

An ABBA simulation-only comparison imported the already verified generated 3 km /
500-soldier starting battlefield into instrumented builds. Each ran 2,100 ticks
without external commands and measured the last 1,200. This diagnostic import is
not replay verification; the production verifier still rejects mismatched builds.
All four final canonical state hashes were identical:
`736d4bdbba47fa0e73ef63cc49ad58b2f359cbcc59890d746b1a27fba32e75fb`.

Target setup averaged 0.869/0.815 ms before and 0.0088/0.0089 ms after, about 99%
less. Infantry averaged 3.407/3.254 ms before and 2.424/2.484 ms after, about 26%
less. Total tick means were 6.261/6.027 ms before and 5.131/6.139 ms after; p99 was
18.37/16.71 ms before and 15.57/17.91 ms after. The second changed run includes a
719 ms maximum, mostly inside navigation, and is retained rather than discarded.
Other apps stayed running; these results do not establish rendered FPS or a hard
frame-time bound. Evidence: `build/infantry-index-comparison.json`.

After also indexing the commander census, a further diagnostic retained the same
canonical hash and measured 5.538 ms total mean / 16.43 ms p99. Commander/mission
time averaged 0.042 ms (p99 1.50 ms), versus 0.103 ms (p99 3.32 ms) in the first
instrumented run. This is a separate follow-up, not a controlled overall speedup.

The fresh packaged live battle at `2551a09` averaged 92.66 FPS, frame p95 15.95 ms,
p99 19.63 ms and maximum 24.81 ms; adjacent-frame difference p99 was 8.63 ms.
Rust ticks averaged 6.62 ms, p99 17.86 ms, with 22 of 1,200 ticks over 16.67 ms.
Infantry averaged 2.73 ms (p99 4.95 ms), while navigation averaged 1.62 ms
(p99 10.41 ms). The same 3 km / 500-unit / high-preset setup and other apps were
retained, but changing background load means the difference from the earlier
35.66 FPS run is not a controlled code speedup. Neither frame nor tick tails meet
the target. The matching server independently verified all 3,014 ticks of this
unfinished battle, final state
`033718652d8d0bcf8622e511efa0b076a2dba5c97d7d5b6b69a323ce7a271f3c`.
Evidence: `build/rust-release-generated-3072-owned/` and
`build/ownership-release-replay-verification.log`.

### Reusing local route costs

Local grids cache up to 512 directed path costs, including unreachable results.
Actual obstacle/weight edits and bulk loads invalidate them; checkpoint restore
starts cold. Search ordering, route costs and canonical state remain unchanged.
The cache unit test, grid/hierarchy/navigation/boat regressions and all 140 numeric
contracts pass. In the same diagnostic ABBA workload described above, navigation
means were 1.368/1.396 ms before and 1.266/1.151 ms after (about 13% less); medians
were 0.470/0.451 ms before and 0.180/0.179 ms after (about 61% less).
Total tick means were 4.768/4.802 ms before and 4.915/4.607 ms after, essentially
unchanged. Navigation p99 was 7.87/8.29 ms before and 10.15/7.83 ms after, so this
does not establish a tail improvement. All four canonical state hashes matched
the earlier diagnostic. Evidence: `build/navigation-cache-comparison.json`.

### Squad-summary preparation and minimap diagnostics

Squad overview updates now group visible members first and calculate each group's
status in typed locals, writing the public summary once. Member ordering, centroids,
leader status, wounded/lost pips and immediate selection remain unchanged. Eight
alternating warmed rounds over 500 soldiers measured 1.495 ms before and 1.218 ms
after on average (about 19% less summary preparation). Each round preserved the
public summary fields; the lifecycle tests additionally check leader removal and
centroids after recovery. This microbenchmark is not a rendered FPS claim.
Evidence: `build/squad-locals-bench.log`.

Minimap profiling now reports ground, fighting, units, co-command and camera
separately. A retained-background prototype passed headless and Vulkan/OpenGL
pixel checks but was rejected: ABBA playback measured original frame p99
18.21/17.39 ms versus 18.26/18.79 ms with the prototype, saving only about
0.026 ms of average minimap work. The simpler progressive layers remain.
An extra typed squad-summary object was also rejected after measuring slower
than the original; the retained change uses locals without that allocation.
Evidence: `build/minimap-background-comparison.json` and
`build/squad-summary-bench.log`.
