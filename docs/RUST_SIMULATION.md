# Rust simulation migration

Status: **in progress; the game still requires Godot to simulate a battle.**
The engine-independent crate currently contains perception candidate selection,
formation scoring, contracted route search, gameplay randomness and ballistic
projectile flight state, drone and support-aircraft behavior, missile guidance,
weighted navigation grids, route planning, smoke and geometric visibility. It is not a complete server, a
full-state save format, or a battle verifier. Existing recordings remain unverified.

## Ownership

The destination is one authoritative Rust simulation, with Godot submitting
player intent and displaying observations. Local play and multiplayer must use
the same simulation. A headless verifier must run that same code without Godot,
graphics, network access or a wall clock.

| Component | Destination | Current implementation |
| --- | --- | --- |
| Perception candidates, formation scoring, route graph | `frontline_core` | Extracted; Godot bindings call the core |
| Gameplay RNG, including commander streams | `frontline_core` | Seeded PCG stream matches Godot 4.7; cosmetic RNG stays in Godot |
| Grenade, smoke, rocket, bomb and shell flight | `frontline_core` | Rust retains and advances flight state and queries native geometry; the adapter supplies holders and applies impacts |
| Weighted grid paths and cluster pair costs | `frontline_core` | Exact Godot route tie behavior; native cluster workers return costs in deterministic order |
| Hierarchical route assembly, repairs and danger weights | `frontline_core` | Rust owns graph slots, borders, cost tables, repair order and terrain/danger revisions |
| FPV drone flight | `frontline_core` | Climb, cruise, dive, loss of control and collision; Godot supplies targets and applies damage |
| Guided missiles and support aircraft | `frontline_core` | Flight, target-lock loss, bomb release, burst schedules, pending hits and random draws; Godot supplies contacts and applies events |
| Entity registry, stable IDs, spawn/despawn | Rust | `world.gd`, `entity.gd` |
| Infantry movement, weapons, injuries, special tasks | Rust | `soldier.gd`, `soldier_brain.gd` |
| Squads, tactics, commander and naval decisions | Rust | Squad, tactics, commander and naval scripts |
| Vehicles and crews | Rust | Entity scripts and Godot spatial queries |
| Battlefield box raycasts | `frontline_core` | Spatial grid with deterministic hit ties; Godot supplies geometry updates |
| Smoke volumes and geometric visibility | `frontline_core` | Rust checks exposed points against collision and smoke, retaining reusable obstruction proofs; Godot supplies target posture and scene changes |
| Route refinement, smoothing, corridor reuse and path requests | `frontline_core` | Native planner retains corridor history and request order; Godot supplies unit positions and delivers completed orders |
| Terrain and cover evaluation | Rust | Terrain/nav/combat scripts |
| Supply, construction, upgrades, prisoners, victory | Rust | `rules.gd`, structures and battle scripts |
| Missions, scripted events, initial map generation | Rust or immutable versioned input data | Map generators and mission director |
| Models, animation, smoothing, particles, camera, minimap | Godot | Existing presentation code |
| Input, selection and order previews | Godot | Existing UI; server validates all commands |
| Observation recordings | Godot viewer | Existing Format 1 recordings |
| Authoritative checkpoints, command replay, verification | Rust | Not implemented |

No authoritative stage may call back into Godot when the migration is complete.
Passing scene objects through Rust, or putting a Rust supervisor around the
current headless executable, does not meet that boundary.

## Migration constraints

Keep the live game usable while replacing systems. Preserve existing behavior
and validate each replacement against its GDScript counterpart, then remove the
old authoritative path once coverage is complete. Do not silently replace rescue,
breaching, vehicles or missions with simplified behavior to make the port run.

Godot bindings belong in `native/src`; engine-independent state and algorithms
belong in `native/core`. The core must not depend on Godot types or objects.
The current core uses the same pinned `glam` geometry implementation as the
binding. That preserves the extraction's arithmetic, but is not a promise of
cross-platform floating-point determinism.

Use stable entity IDs instead of object pointers. Preserve explicit update and
tie-break order. Hash tables may support lookup, but their iteration must not
decide gameplay. Parallel jobs may calculate independent results; deterministic
application order and fixed work quotas must decide when those results affect
the simulation. Wall-clock path budgets and first-worker-finished decisions
cannot determine battle outcomes.

Rendering must never advance gameplay randomness. The fallback debris renderer
previously consumed `world.rng`; it now uses cosmetic randomness. Other state
coupling, caches, queue positions and physics queries still need auditing before whole-game determinism is claimed.

## Commands and observations

The Rust host owns tick numbering and command order. At admission it authenticates
the peer, bounds and normalizes the request, then assigns its execution tick and
sequence. During execution it checks current ownership, resources and gameplay
preconditions. Record the ordered admitted requests and their outcomes, including
requests rejected because state changed before execution. Record joins,
disconnects, ownership changes and other external simulation inputs as well.

Godot receives initial state plus bounded observation updates keyed by stable
IDs, with simulation ticks, spawns, removals and cosmetic events. It interpolates
between observations independently of simulation ticks. Server-side visibility
filtering must retain the current fog-of-war privacy boundary; a client must not
receive hidden enemy state just because the renderer can hide its model.

Start with the shared core behind the current binding while systems migrate.
Only extract a standalone transport when the whole authoritative tick can run
without callbacks into scene objects. The final local server must retain current
loopback authentication, version checks and owner-exit cleanup. A process split
alone does not reduce simulation cost or guarantee 60 FPS.

## Deterministic replay contract

A simulation replay needs all of the following, separate from Format 1 observer
recordings:

- An exact simulation/rules/content identifier, checkpoint schema, tick rate and
  numeric contract. Unknown versions must fail rather than replay under new rules.
- A complete initial state, including map/collision data, every RNG stream and
  cursor, entity-ID allocation, AI/task state, timers, pending work, rules and
  mission state. A seed plus network entity snapshots is insufficient.
- A monotonically ordered input log with execution tick, sequence and actor.
  Commands must use deterministic numeric representations and bounded payloads.
- Canonically serialized authoritative state at checkpoints, with a cryptographic
  hash. Include any cache whose contents change later decisions, or reconstruct
  it deterministically as part of loading. Display state is excluded.
- A declared final tick, expected state hash and result. Truncated input is an
  error, not a verified early victory.

The verifier loads the matching core, restores initial state, runs the recorded
inputs and compares every checkpoint. It exits unsuccessfully at the first
divergence and reports the tick and subsystem. Tests must cover altered commands,
RNG state, checkpoint state, version, ordering, missing data and final outcome.
Checkpoint resume must produce the same subsequent hashes as uninterrupted play.

Reproducing an outcome proves consistency with the supplied inputs and rules.
It does not establish that a client-generated input history is authentic.
Trusted competitive results additionally need a server-authenticated input log.
Do not set the public recording API's `verified` flag based on viewer playback,
kernel tests or a client-provided final hash.

## Completion gates

1. A standalone Rust process runs every supported scenario and mission with no
   Godot installation. All authoritative ownership rows above have migrated.
2. The Godot client runs solo and multiplayer entirely from observations; host/
   client command, visibility, disconnect and cleanup regressions pass.
3. Repeated full battles and checkpoint resumes yield identical hashes in debug
   and release. Windows/Linux equivalence is tested before advertising portability;
   incompatible arithmetic must be fixed or explicitly version-restricted.
4. The standalone verifier catches tampering and truncation, reproduces match
   conclusions, and rejects incompatible versions. Old observer recordings still
   play without being relabeled as verified.
5. Measured 500-unit battles on large maps meet the rendering and simulation
   budgets, including tail frame times and frame-to-frame variation, with other
   applications left running. No speedup is inferred just from using Rust.

## Current checks

Run `cargo +1.94.0 test --locked --manifest-path native/Cargo.toml -p frontline_core`
without Godot to test the extracted algorithms. `python tools/build_native.py`
builds the same core into the extension used by the game. Import Godot afterward.
The route-graph, formation-occupancy and perception fixtures check the bindings
against gameplay/reference behavior. `tests/cosmetic-random.test.mjs` verifies
that visible fallback debris leaves the gameplay RNG state and sequence unchanged.
These checks do not yet verify a complete battle.

## Migrated authoritative state

`SimulationRandom` owns the world and commander random streams in Rust. The
GDScript adapter retains the old seeded API and uses Godot only in engine-only
checkouts. `random.rs` fixes PCG stream selection and the standard-build float
mapping; changes to either require a replay rules version change. The reference
is [Godot 4.7 RandomPCG](https://github.com/godotengine/godot/blob/4.7/core/math/random_pcg.h).
The compatibility fixture compares 70,000 mixed draws and every intermediate
state, including reversed/equal integer bounds and the full signed 32-bit range.

`Flight` owns ballistic projectile position, velocity, timers, fuse, smoke and
trajectory endpoints. Godot keeps observation mirrors for existing gameplay
callers. Pickup, kick and rethrow reset the Rust state explicitly; each tick
provides holder inputs; Rust queries its collision world directly.
Battlefield box raycasts now run in Rust, while geometry updates, damage,
smothering, creation and removal remain Godot responsibilities. Thus this is not an autonomous battle simulator.

Flight checkpoints have a strict versioned little-endian encoding of every
field, preserving floating-point bits. The decoder rejects unknown versions,
truncation, trailing data, invalid tags/flags and nonfinite values without changing
live state. Tests restore these checkpoints mid-flight and compare subsequent
states and outcomes. This verifies component resume, not a battle result or the
authenticity of an input history. Bomb drag still uses floating-point `exp`, so
cross-platform bit identity is not yet guaranteed.

The 144-case flight fixture compares Rust against the retained GDScript reference
at 30 Hz, 60 Hz and coarser ticks, including impacts, held/dropped/kicked/rethrown
grenades, smoke expiry and checkpoint restores. Position tolerance is 1 mm and
velocity tolerance is 0.1 mm/s; gameplay scalar fields and impact parameters must
match exactly. The full default suite and the opt-in mission suite remain the
integration gates.

## Battlefield collision

`CollisionWorld` owns numeric box transforms and extents, indexed in 32 m X/Z
cells. Segment traversal visits only crossed cells, deduplicates boxes without
per-query allocations, and resolves exact ties by entity/shape ID. The adapter
updates moving entities, rebuilt shapes and opened doors before queries. Destroyed
bodies remain until the tick ends, preserving the former deferred-removal behavior.
Shape-resource edits invalidate the native copy as well. The retained Godot
reference can be selected with the internal `gdscript_collision` test setting.
Unsupported geometry disables native collision for that battle with a warning;
this compatibility fallback must disappear before standalone-server completion.

Native exhaustive tests cover index traversal, edits, exclusions and stable ties.
A 3,000-ray integration fixture compares hits and normals against Godot for 150
rotated boxes. Lifecycle tests check immediate movement, shape edits and removal,
including shielding by a destroyed body through the end of its final tick.
This migrates the ray query, not all combat decisions or terrain state.

`Visibility` owns smoke volumes keyed by projectile ID and the smoke from burning
terrain. Radius, position, type and despawn changes update those volumes before
the next query. Multi-point sight checks run against the core's collision world;
stationary observers can reuse obstruction only while the same numeric box
geometry blocks every exposed point. Visible results and smoke-only obstruction
are always checked again. The bounded proof cache can be reconstructed after
loading because it only eliminates equivalent queries.

Collision and smoke checkpoints retain sorted stable IDs and exact geometry,
with bounded decoding and no engine references. The native fixture compares
3,000 visibility cases with Godot, including repeated/moving queries, posture,
exclusions, moving/resized geometry, smoke changes and component restores. Core
tests cover proof eviction, invalid input and resume. These are still component
checkpoints, not a complete battle save.

## Grid navigation and aircraft

`NavigationGrid` replaces engine AStarGrid2D for local cluster searches and boat
routes. Its weighted octile search preserves Godot's neighbor order and heap tie
behavior. Cluster cost builds run on Rust workers over immutable numeric data;
engine objects stay on the calling thread and results retain input order.
Terrain cells have versioned checkpoints; temporary search scratch is rebuilt.
`Hierarchy` owns HPA graph assembly, incremental repairs, cost-table reuse and
danger weighting. Its checkpoints retain graph slots, neighbor order, ID cursors,
pending repairs and all versions/cost tables; local search scratch is rebuilt.
Restored graphs keep returning identical routes as terrain and danger change.
`PathPlanner` refines abstract routes, string-pulls waypoints, shares checked
corridors between nearby orders and retains the deterministic request queue.
It preserves the original short-move shortcut, fire avoidance, padded-wall
destinations, per-team danger invalidation and fixed completion quotas. A route
starts from the unit's position when its job executes, not when it was queued.
Its checkpoints include cached corridors because they can change later paths,
and include cancelled queue slots, replacements and the current batch boundary.
Elapsed-time diagnostics are excluded. Godot still resolves unit IDs and delivers
the results to soldier/vehicle tasks; that adapter must move into the Rust entity
registry with those systems.
The reference fixture compares 3,840 paths, mutations and pair costs against
Godot, and core tests compare costs across different worker counts.
The hierarchical fixture compares 2,880 routes with terrain edits, danger changes,
partial repairs and checkpoint resumes on 16 m and 32 m clusters. Entrance-cache
keys now retain both coordinates; the former single-byte key could alias different
entrances in a 32 m cluster.

The path-planner reference fixture compares 5,760 complete routes, including
fire and terrain edits, shared corridors, per-team danger changes and restored
planner checkpoints. It also compares callback order under fixed quotas,
replacements and cancellations, including orders queued during map generation.
One Windows run with other applications and the integration suite running took
9,770 ms in the retained GDScript planner and 4,186 ms in the native planner for
those same queries, alternating which implementation ran first. Both used the
native local-grid kernels. This is a small-map route workload, not a 500-unit
battle, an isolated benchmark or evidence of 60 FPS.

`DroneFlight` and `GuidedFlight` retain their timers, steering and targeting state.
They query `CollisionWorld` without engine callbacks. The Godot adapters supply
live targets and operator/smoke inputs, then apply damage and entity removal.
Reference fixtures cover 72 FPV flights and 96 guided missile flights, including
lost targets, loss of control, smoke, shoot-downs and proximity impacts. Steering
uses Godot's normalization and rotation arithmetic; a different algebraically
equivalent matrix caused accumulated trajectory drift in the reference test.

`SupportFlight` owns jet bomb releases, A-10 pending rounds, orbiting gun schedules
and recon-mark timing. Its 42-case fixture compares every tick's observations,
events, damage parameters and RNG state for all five orbiting weapon sets,
empty and occupied target areas, and three tick rates. It preserves the original
order of random draws and pending impacts. Core resume tests include mid-burst
checkpoints and restore the accompanying RNG stream. Aircraft weapon sockets
are supplied as immutable model data; Rust computes banked muzzle positions and
retains them in the version 2 support-flight checkpoint. The reference fixture
checks default and model-specific sockets and shell ownership after the current
vehicle-handling changes on `main`. These are component
checkpoints; they do not include the whole battle or verify its conclusion.

## Validation limits from this migration

The opt-in mission suite currently wins bridgehead and beachhead, but loses
skyhook, ambush and kingpin. These same three
losses reproduce at the same simulation times on the pre-port `f1ec9a0` commit
(230, 250 and 360 seconds respectively). They are baseline failures, not evidence
that the full mission completion gate is met. Keep reporting them until resolved.
The integrated default suite passed 101 tests after the aircraft, grid,
hierarchical planner, route refinement/smoothing and request-queue ports,
including multiplayer authority, combat, breaching and seed reproducibility.
The later visibility port passes all 102 default integration tests and its
mission run reproduces the same baseline outcomes. These checks do not
cover full battle checkpoints or replay verification.

A focused shell benchmark (100 shells, 100 ticks, headless, no collision queries)
measured about 14.6 ms for the GDScript path versus 4.6–5.6 ms for retained Rust
flight state. This is not an FPS measurement. The transitional GDScript RNG
adapter costs more per draw than the engine RNG (about 0.4 versus 0.15–0.23 µs in
a 100,000-draw check); direct Rust callers avoid that adapter. Whole-battle scaling
still needs measurement, and the 60 FPS completion gate remains open.
