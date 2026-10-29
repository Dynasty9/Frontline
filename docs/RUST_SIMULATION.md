# Rust simulation migration

Status: **in progress; the game still requires Godot to simulate a battle.**
The engine-independent crate currently contains perception candidate selection,
formation scoring and contracted route search. It is not a complete server, a
full-state save format, or a battle verifier. Existing recordings remain unverified.

## Ownership

The destination is one authoritative Rust simulation, with Godot submitting
player intent and displaying observations. Local play and multiplayer must use
the same simulation. A headless verifier must run that same code without Godot,
graphics, network access or a wall clock.

| Component | Destination | Current implementation |
| --- | --- | --- |
| Perception candidates, formation scoring, route graph | `frontline_core` | Extracted; Godot bindings call the core |
| Entity registry, stable IDs, spawn/despawn | Rust | `world.gd`, `entity.gd` |
| Infantry movement, weapons, injuries, special tasks | Rust | `soldier.gd`, `soldier_brain.gd` |
| Squads, tactics, commander and naval decisions | Rust | Squad, tactics, commander and naval scripts |
| Vehicles, crews, drones, projectiles | Rust | Entity scripts and Godot spatial queries |
| Terrain, collision, cover, line of sight, path jobs | Rust | Terrain/nav/combat scripts and Godot physics |
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
coupling, random streams (including commanders), caches, queue positions and
physics queries still need auditing before whole-game determinism is claimed.

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
