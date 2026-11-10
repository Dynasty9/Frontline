# Rust simulation migration

Status: **desktop solo and multiplayer battles run in the separate Rust server;
browser solo battles run the same Rust simulation in a Web Worker.** Remaining
presentation checks and frame-time targets are still being completed. This
branch is not ready to release.

Performance measurements and past validation results are kept in the
[measurement log](performance/rust-simulation.md). Matched atlas experiments
improved average frame time, but later captures slowed under changing background
load. No capture establishes a steady minimum of 60 FPS.

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
| Strategic commanders, naval plans and all five mission programs | Rust `frontline_runtime` |
| Command validation, input ordering, checkpoints and verification | Rust `frontline_runtime` |
| Connection authentication, sockets and native process controls | Rust `frontline_server` |
| Initial procedural map authoring and immutable content export | Godot, before the first tick |
| Models, animation, smoothing, effects, sound, camera, minimap and UI | Godot client |

The GDExtension in `native/src` remains necessary for map preparation and reference
comparisons. The engine-independent code in `native/core` and `native/runtime`
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
Lobby-relayed packets queue before decoding, with a 4 MiB / 32,768-packet limit.
Each frame finishes at most 256 packets and stops starting more after 2 ms;
the current packet always finishes. Reliable acknowledgements advance only after
decoding, and close/reconnect clears pending packets.

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

## Build and exercise

Run from the repository root with Rust 1.94.0 and Godot 4.7.2 installed:

```text
python tools/build_native.py
godot --headless --path . --import
godot --path . -- --local-server --mission=bridgehead --seed=1
cargo +1.94.0 test --locked --manifest-path native/Cargo.toml -p frontline_core -p frontline_runtime -p frontline_server
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
Website and matchmaker tests cover format negotiation and refusal to label
observer recordings as verified.

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

## Code organization

| Responsibility | Location |
| --- | --- |
| Numeric state, tactical rules and algorithms | `native/core/src/` |
| Tick order, command admission and player lifecycle | `native/runtime/src/simulation.rs` |
| Canonical inputs and full-match checkpoint validation | `native/runtime/src/simulation/{input,codec}.rs` |
| Commander state, census and phase scheduling | `native/runtime/src/commander.rs` |
| Construction and recruitment, squad assignments, navy, checkpoints | `native/runtime/src/commander/{logistics,tactics,naval,codec}.rs` |
| Shared render projection and application framing | `native/runtime/src/{render,observation,protocol}.rs` |
| Socket transport and scheduling | `native/server/src/{network,serve}.rs` |
| Browser worker adapter | `native/browser/src/session.rs` |
| Running match ownership and live/replay lifecycle | `native/runtime/src/session.rs` |
| Recording, playback and independent verification | `native/runtime/src/replay.rs` |
| Immutable content schema, loading and compiled profiles | `native/runtime/src/content/` |
| Shared world context | `native/core/src/world.rs` |
| Pausable route frontier and query overlay | `native/core/src/route_graph/search.rs` |
| Godot transport consumption and visual world updates | `scripts/game/simulation_client.gd` |
| Shared soldier meshes and animation shader | `scripts/game/soldier_view_batch.gd`, `scripts/shaders/soldier_batch.gdshader` |

The desktop host and browser worker depend on `frontline_runtime`; neither is
a dependency of the runtime. Shared package metadata and dependency versions live
in `native/Cargo.toml`. The [crate-boundary decision](architecture/rust-workspace.md)
describes the interfaces and dependency direction. Transport adapters own I/O and
wall-clock scheduling; they do not duplicate simulation rules. Keep algorithm
modules in the core free of Godot objects.
The legacy Godot simulation and bindings still support map authoring and parity
checks, so removing them is a separate migration rather than code cleanup.

## Validation and remaining completion gates

Run the native server and browser suites after changing simulation orchestration:

```sh
cargo +1.94.0 test --locked --release --manifest-path native/Cargo.toml -p frontline_runtime -p frontline_server -p frontline_browser
```

Commander and mission tests compare deterministic state against checked-in golden
hashes. Replay tests cover continuation, corruption, input ordering and conclusions;
socket and browser tests exercise their adapters. CI additionally runs debug and
release checks on Windows, Linux x64/ARM64 and macOS ARM64, plus actual WebAssembly.
Do not regenerate numeric goldens for a mechanical refactor.

Numeric Godot fixture tests share `tests/lib/fixture.mjs` for process launch,
timeout and engine-error detection; each test retains its own behavioral asserts.
Interactive, rendered and long-running scenes keep their own lifecycle settings.

Core and runtime source layout contributes to `ENGINE_ID`, so even a
behavior-preserving runtime refactor creates a new build identity. Native transport
source is outside that simulation identity; incompatible wire changes must bump
the protocol version. Existing recordings require their original
build; do not bypass identity checks to open them in a changed simulation.

Remaining release gates:

- Meet the tail-frame budget in generated large-map, 500-unit rendered cases,
  with other applications running. Average FPS alone is not a pass.
- Complete current-head exports, installer checks, cross-platform CI and visible
  gameplay checks. Previous results remain in the measurement log with their
  tested build and workload.


Desktop map generation supports [versioned precomputed starting battlefields](PRECOMPUTED_MAPS.md).
The cached bytes are the original initial-state transfer, not a resumed match or
a second simulation implementation. Exact input/build identity and payload
integrity are checked before the existing Rust importer consumes them.
