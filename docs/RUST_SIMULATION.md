# Rust simulation migration

Status: **desktop solo play runs in the separate Rust server; multiplayer lobby,
replay viewing and browser integration are still being completed.** This branch
is not ready to release. The socket server already accepts multiple authenticated
Godot clients, but the multiplayer menu still starts the legacy host path.

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
reference and for the multiplayer/browser paths still awaiting integration.

## Socket protocol

Raw ENet/UDP carries versioned application messages, not Godot scene RPCs.
The 16-byte header contains `FLNP`, protocol version, message kind and sequence.
Reliable channel 0 carries authentication, orders, baselines, births, removals,
properties, HUD updates, messages and reports. Channel 1 carries independently
applicable tick-stamped entity snapshots. Channel 2 carries expendable effects.

The trusted host supplies a 192-bit ticket, commander identity and team for each
admitted player. Clients present their ticket and exact simulation build ID;
they cannot supply another commander or choose a team through a gameplay packet.
Commands are bounded and checked again against current ownership and resources.
New connections and reconnects receive their own reliable baseline. Hidden enemy
IDs and private supply, orders and intelligence are filtered before transmission.
Map and large report data are chunked. Reliable queues, acknowledged bytes,
command rates and per-frame client parsing are bounded; a stalled peer is closed.

Simulation ticks run at 60 Hz. Observations currently publish at 15 Hz, with Godot
interpolation independent of tick advancement. Catch-up work is bounded; a slow
host changes wall-clock pacing without skipping deterministic simulation ticks.
Pause and playback speed change pacing, not the simulation delta.

Desktop packaging includes the server beside the Windows/Linux executable and
in `Contents/Helpers` on macOS. The updater installs and rolls back the game,
GDExtension and server together. Closing a game asks its owned server to finish
and flush the recording; unrelated applications are never stopped.

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

Numeric version 2 pins Rust 1.94.0, glam 0.32.1 with `libm`, and libm 0.2.16 with
`force-soft-floats`. Gameplay iteration, tie-breaking and work quotas have explicit
orders. Cosmetic randomness and wall-clock/network scheduling are outside state.
Cross-platform tests compare committed numeric transcripts and complete mission/
commander checkpoints in debug and release without tolerances. Godot parity tests
separately allow documented differences from the engine's platform math functions.
These covered trajectories are not a proof for every possible floating-point input.

## Build and exercise

Run from the repository root with Rust 1.94.0 and Godot 4.7.2 installed:

```text
python tools/build_native.py
godot --headless --path . --import
godot --path . -- --local-server --mission=bridgehead --seed=1
cargo +1.94.0 test --locked --manifest-path native/Cargo.toml -p frontline_core -p frontline_server
godot --headless --path . res://tests/local_server_test.tscn
```

The launcher stores logs in `user://local_servers/` and recordings in
`user://replays/battle-<session>.flrp`. `FRONTLINE_SERVER` selects a server binary
in a source checkout. Set `FRONTLINE_GODOT` and run the ignored `godot_connects`
network test to exercise actual Godot/Rust ENet interoperability.

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
An optional `profile` (`path`, `warmup`, `duration`) measures wall-clock tick and
observation costs outside deterministic state. Keep admission tickets private. The initial importer
rejects already-running Godot worlds with active ordnance/plans rather than
silently losing state. Output recordings are created exclusively, never overwritten.

## Validation and remaining completion gates

The preceding commit, `30b6019`, passed the complete Godot comparison job and debug/
release Rust checks on Windows x64, Linux x64, Linux ARM64 and macOS ARM64.
Current socket checks cover two teams, admission failures, privacy, bounded
messages, event projection and Godot interoperability. The normal launcher check
covers movement orders, pause/resume, ownership after reconnect, graceful recording
completion, independent verification and an owned-server crash. An 80-soldier
rendered socket battle completed without script errors. These are not 500-unit
rendering results or natural full-mission balance playthroughs.

Remaining release gates:

- Connect multiplayer lobby, drop-in/rejoin and co-command interactions to Rust.
- Play command recordings through the normal replay UI with seek and verification.
- Carry current roads, terrain deformation and remaining cosmetic lifecycle events
  through joining and live observations.
- Integrate browser transport/runtime without a desktop process assumption.
- Run generated large-map, 500-unit rendered cases and inspect tail frame times,
  frame-to-frame variation and memory with other applications running.
- Complete exports/installers and current-head cross-platform CI. Preserve gameplay
  with full scenario/mission regressions and visible comparison evidence.

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
