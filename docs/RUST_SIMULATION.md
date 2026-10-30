# Rust simulation migration

Status: **in progress; the game still requires Godot to simulate a battle.**
The engine-independent crate currently contains perception candidate selection,
formation scoring, contracted route search, gameplay randomness and ballistic
projectile flight state, drone and support-aircraft behavior, missile guidance,
weighted navigation grids, route planning, smoke, geometric visibility, fighting
positions, water geometry and terrain cell/deformation state. It is not a complete server, a
full-state save format, or a battle verifier. Existing recordings remain unverified.

## Ownership

The destination is one authoritative Rust simulation, with Godot submitting
player intent and displaying observations. Local play and multiplayer must use
the same simulation. A headless verifier must run that same code without Godot,
graphics, network access or a wall clock.

| Component | Destination | Current implementation |
| --- | --- | --- |
| Perception candidates, formation scoring, route graph | `frontline_core` | Extracted; Godot bindings call the core |
| Infantry target acquisition | `frontline_core` | Visibility, mounted-gun arcs, weapon priorities, drone reactions and forced targets in one numeric scan; Godot supplies current contact poses and applies squad reports |
| Gameplay RNG, including commander streams | `frontline_core` | Seeded PCG stream matches Godot 4.7; cosmetic RNG stays in Godot |
| Grenade, smoke, rocket, bomb and shell flight | `frontline_core` | Rust retains and advances flight state and queries native geometry; the adapter supplies holders and applies impacts |
| Weighted grid paths and cluster pair costs | `frontline_core` | Exact Godot route tie behavior; native cluster workers return costs in deterministic order |
| Ground cells, crater heights and queued cover repairs | `frontline_core` | Rust retains terrain and ordered structure geometry, and performs edits, queries and cover repairs; Godot imports biome generation and forwards navigation notifications |
| Water shapes, bridge decks and water terrain rasterization | `frontline_core` | Ordered numeric rasterization; a Rust worker also applies the joining host's ground overrides; Godot still generates the initial shapes |
| Hierarchical route assembly, repairs and danger weights | `frontline_core` | Rust owns graph slots, borders, cost tables, repair order and terrain/danger revisions |
| FPV drone flight | `frontline_core` | Climb, cruise, dive, loss of control and collision; Godot supplies targets and applies damage |
| Guided missiles and support aircraft | `frontline_core` | Flight, target-lock loss, bomb release, burst schedules, pending hits and random draws; Godot supplies contacts and applies events |
| Entity registry, stable IDs, spawn/despawn | Rust | `world.gd`, `entity.gd` |
| Infantry route movement | `frontline_core` | Route progress, vaulting, sliding, doors and ground caches extracted and reference-tested; the per-soldier adapter remains test-only because it is slower than GDScript |
| Infantry weapon cycles | `frontline_core` | Cover fire, postures, firing permissions, ammunition and burst recovery extracted with compatibility tests; adapters remain test-only until Rust owns the actor |
| Infantry health, suppression and fatigue | `frontline_core` | Numeric recovery, damage outcomes and down/death/revive transitions extracted with component checkpoints; actor cleanup, squad reactions and damage attribution remain Godot effects |
| Infantry combat geometry | `frontline_core` | Eyes, exposed points, hit factors and cover postures extracted with reference tests; the adapter still supplies actor state |
| Infantry aim selection and sight cache | `frontline_core` | Target, blind and area-fire aiming extracted and reference-tested; the test adapter supplies posed target points and last-known squad contacts |
| Bullet resolution | `frontline_core` | Accuracy, scatter, penetration, hit damage, explosive-round placement and near-miss suppression extracted with ordered stages; Godot still applies actor damage and explosion effects |
| Blast exposure | `frontline_core` | Infantry and structure damage, shelter, fling strength and flinch radius extracted; Godot still owns victims, vehicle armour and effect application |
| Blast knockback and disorientation | `frontline_core` | Fling trajectories, obstacle bounces, landings, flinching and dazed movement extracted with component checkpoints; Godot still applies task cleanup and speech |
| Wounded infantry and corpse timers | `frontline_core` | Bleeding, rescue/medicine modifiers, speech/pistol/crawl schedules and corpse collection decisions extracted; rescuer links, targeting and task effects remain in Godot |
| Grenade reflex decisions | `frontline_core` | Notice memory, protection of nearby casualties, throwback/kick priority, shelter queries, kick direction and cooking time extracted; Godot still owns task application and grenade handlers |
| Injury behavior and special tasks | Rust | `soldier.gd`, `soldier_brain.gd`, `combat.gd` |
| Squads, tactics, commander and naval decisions | Rust | Squad, tactics, commander and naval scripts |
| Vehicles and crews | Rust | Entity scripts and Godot spatial queries |
| Battlefield box raycasts | `frontline_core` | Spatial grid with deterministic hit ties; Godot supplies geometry updates |
| Smoke volumes and geometric visibility | `frontline_core` | Rust checks exposed points against collision and smoke, retaining reusable obstruction proofs; Godot supplies target posture and scene changes |
| Route refinement, smoothing, corridor reuse and path requests | `frontline_core` | Native planner retains corridor history and request order; Godot supplies unit positions and delivers completed orders |
| Cover anchors and fighting-position selection | Rust | Rust generates anchors and evaluates protection/firing lanes; candidate search, claims and soldier state remain in cover/combat scripts |
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
The core pins `glam` geometry and software `libm` transcendental functions; see
the numeric contract below. Godot reference checks and cross-platform checkpoint
checks are separate gates. Neither establishes whole-battle determinism while
authoritative state remains in GDScript.

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

The process boundary is a socket carrying commands toward the server and
tick-stamped observations/events toward each renderer. Local play connects over
loopback; remote players use the same protocol and authority checks. Internal
perception, navigation and combat queries stay inside the Rust process. The
GDScript-to-Rust calls used during migration are not the future network protocol.
The current launcher still starts a headless Godot server with native components.

Use versioned binary application messages over ENet/UDP, with reliable orders and
lifecycle changes and sequenced state updates. A snapshot that needs an earlier
baseline must identify it; joining and reconnecting clients need a reliable full
baseline, and loss must trigger recovery rather than partial state. Each peer gets
only the state allowed by team visibility. The raw packet layer is supported by
[ENetConnection](https://docs.godotengine.org/en/stable/classes/class_enetconnection.html);
Godot's scene RPC protocol is explicitly an engine implementation detail, unsuitable
as the Rust server's interoperability contract
([SceneMultiplayer documentation](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html)).
The standalone transport and whole-world simulation remain to be implemented.

Keep those application messages independent of ENet. The browser export cannot
open UDP sockets and must carry the same messages through a supported transport,
such as WebSocket; [Godot supports it on native and web exports](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).
Admission, visibility filtering and replay ordering still run in the same Rust
server. A slow reliable connection needs bounded observation queues and a fresh
baseline when it falls behind, not an accumulating backlog of obsolete states.
Offline browser play also needs an explicit migration path (the Rust core in a
browser worker); it cannot launch the desktop server executable.

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

### Numeric contract

Numeric version 1 pins Rust 1.94.0, glam 0.32.1 with its `libm` feature and libm
0.2.16 with `force-soft-floats`. Scalar transcendental functions use the same
implementation on every platform instead of the host system's math library.
Glam also prefers libm when Godot enables its `std` feature. Fast-math is disabled.
These choices follow [glam's math features](https://docs.rs/glam/0.32.1/glam/#optional-features)
and [libm's software-only override](https://github.com/rust-lang/compiler-builtins/blob/libm-v0.2.16/libm/Cargo.toml).

Component checkpoint headers contain a four-byte component tag, a little-endian
16-bit schema version and a 16-bit numeric version. They reject earlier numeric
rules rather than silently continuing with changed arithmetic. The separate
integer RNG stream remains unchanged.

`native/core/tests/numeric_contract.rs` compares 504,078 committed bytes without
tolerances: fixed-tick flight state, support events and RNG cursors, carved water,
craters, rotated box hits, cover anchors, spherical interpolation and infantry
movement, infantry cover fire, postures, ammunition, burst recovery, vitals, aiming,
combat poses, bullet resolution, blast exposure, knockback recovery and wounded
infantry schedules and grenade reflexes. CI runs
the same fixtures in debug and release on Windows x64, Linux
x64, Linux ARM64 and macOS ARM64. A mismatch reports the first different byte.
These fixtures guard the covered trajectories; they are not a proof for all
floating-point inputs or a substitute for full-world replay verification.

The numeric port exposed an unstable missile turn when its desired heading is
almost the reverse of its velocity. Both implementations now choose a fixed
perpendicular turn plane in that narrow case and retain the same turn-rate limit.
Tests perturb the aim point on either side of exact reversal, including vertical
flight. This is an intentional correction to the old rounding-sensitive behavior.
When a target is already within the permitted turn, steering reaches its heading
directly instead of accumulating interpolation error. Across the 96 guided-flight
reference cases, observed maximum position/velocity differences are 3.04 mm and
6.94 mm/s; the compatibility bounds are 5 mm and 10 mm/s. Impact frames, lock
changes and event data still match. Cross-platform Rust checkpoint checks use no
tolerance.

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
authenticity of an input history. Bomb drag uses the pinned software `exp` under
the numeric contract, and its checkpoints participate in exact-byte CI checks.

The 144-case flight fixture compares Rust against the retained GDScript reference
at 30 Hz, 60 Hz and coarser ticks, including impacts, held/dropped/kicked/rethrown
grenades, smoke expiry and checkpoint restores. Position tolerance is 1 mm and
velocity tolerance is 0.1 mm/s; gameplay scalar fields and impact parameters must
match exactly. The full default suite and the opt-in mission suite remain the
integration gates.

## Infantry movement

`InfantryMotion` advances route waypoints, stuck detection, barrier vaulting,
cover slides, ground-height caches and door waits against native navigation,
terrain and collision. Door decisions preserve speech RNG draws and opening
order. Mounted weapon turn limits use the post-move position. Its `FLIM` checkpoint
retains the route and every movement timer, including pending door identity.
Arrival and repath events still return to the Godot actor; this is not a full
infantry checkpoint.

The reference fixture compares 18,000 steps against the original movement at
30 Hz, 60 Hz and coarse ticks, including opening another soldier's door, route
replanning, duplicate waypoints, cover arrival and mounted turning. Events and
RNG cursors match exactly; poses allow 10 micrometres of floating-point rounding.

The temporary `rust_infantry_motion` world setting is only enabled by the fixture.
With other applications running, 1,000 moving steps took 3.27–3.95 ms in GDScript
and 8.48–9.51 ms through the native adapter (six alternating-order samples after
warmup). Packing and mirroring each actor is more expensive than this small
calculation. Normal play retains the faster existing path until the complete
Rust actor owns its state. These numbers are neither server throughput nor FPS.

## Infantry weapon controller

`InfantryWeapon` retains peek/watch/blind-fire state, firing and reload timers,
burst and ammunition counts, last-shot time and the low-ammunition announcement.
The core decides firing postures and permissions for moving soldiers, low cover,
leaning cover, gun crews, escorts, ambushes and pinned troops. Cover events retain
their order: the adapter applies reload speech, buddy cover and movement to a new
anchor before selecting posture. A new anchor can have a different height.

Shot preparation, combat resolution and shot recovery remain ordered stages.
Bullet damage consumes randomness and can change the shooter before recovery;
the adapter releases the RNG borrow before combat and uses the current reload
specification afterward. The existing partial-magazine rule is preserved: a
reload adds available rounds rather than replacing the rounds already loaded.
The `FLIW` checkpoint preserves the controller's state and rejects malformed or
incompatible input without changing live state. It is not an actor checkpoint:
aim selection, damage, life state, tasks and squad ownership still live in Godot.

The reference fixture compares 168,960 controller steps, including five postures,
cover shifts, squadmate responses, weapon changes during damage, finite/infinite
ammunition, scarce-round bursts, speech and exact RNG cursors. The test-port-only
`rust_infantry` option runs the native controller through real attack,
breach, trenches and fire scenarios, comparing existing battle fingerprints and
behavior counters every 15 seconds for 60 seconds. Those fingerprints are an
integration regression check, not cryptographic replay verification. Normal play
keeps the existing weapon controller until Rust owns actor state; no performance
gain is claimed from this per-soldier test adapter.
The full default suite passes 111 tests after this extraction, and all 75 core
tests pass in both debug and release. Cross-platform CI also compares the new
52,037-byte weapon transcript against one shared committed fixture.

## Infantry vitals

`InfantryVitals` retains health, repeated-wound count, suppression and recovery
timers, fatigue, bleed state and down/death timing. Damage decides survival,
downing or death without applying the actor transition early: battle damage
credit and squad notifications must observe the same life state as before. The
actor still performs task/mount cleanup, squad casualty reactions, visual events
and replicated health changes in their existing order. Suppression retains
cover-material caps, trench and retreat modifiers, reporting cadence and speech
draws. Fatigue preserves movement/carrying costs and posture-dependent recovery.

The `FLIV` checkpoint covers these numeric fields, not task state, rescuer links,
injury movement or the complete soldier. The test-only `rust_infantry` setting
enables weapon, vitals and aim adapters together. The vitals reference fixture checks
92,160 steps across every life state, including repeat wounds/revivals, bearers,
prisoners, damage attribution, squad morale, speech, properties and RNG cursors.
The four battle comparisons now exercise both controllers together. Core checks
also restore state between recovery/fatigue steps and reject malformed input.
The numeric CI corpus includes a 45,096-byte vitals transcript.

Wounded updates also use the vitals core for bleeding, medicine/rescue modifiers,
speech and pistol schedules, crawling eligibility and corpse collection. Separate
stages preserve intervening speech and firing effects before reading state again.
Losing a corpse's last bearer clears its carrier link first; ground settling and
despawn checks resume on the next tick, as before. A freed dragger is now cleared
without dereferencing it. A 61,441-step fixture compares state, ordered effects
and RNG, including carried/dragged casualties and pistol effects that change
remaining bleed time. Numeric CI adds an 80,457-byte transcript using the existing
`FLIV` fields. Rescuer ownership, actual pistol targeting, cover search and task
effects still depend on the Godot actor.
The full default suite passes 112 tests after this extraction; 81 core tests pass
in debug and release. These adapters remain test-only and do not establish a
complete soldier checkpoint or a 60 FPS performance result.

## Infantry aiming

`InfantryAim` owns the short sight cache and firing-point selection. It preserves
blind scatter, the strict 0.3-second sight refresh, structure and drone sight
rules, the chance of aiming through low cover, suppression fire and last-known
positions. It shares the retained collision and smoke world. Input validation
precedes cache changes and random draws; the component checkpoint records the
cached target, expiry and result.

The Godot comparison checks 20,480 decisions against the existing implementation,
including moving blockers, smoke, all soldier postures, drones, vehicles,
structures, invalid targets, contact expiry, RNG order and checkpoint resumes.
The existing attack, breach, trenches and fire battle comparisons also enable
this controller alongside native weapon and vitals logic. The numeric corpus
adds an 18,792-byte aiming transcript. Squad contact
selection and actor damage effects still require Godot; this is not
a complete actor or independently replayable battle. The full default suite passes
113 tests after this extraction; 87 core tests pass in debug and release.

## Infantry combat poses

The simulation's eyes, exposed body points, center, hit factors and over-cover
posture now have pure Rust calculations. They depend on gameplay pose, life,
cover, mount and movement state, with no animated skeleton or scene query.
Exposed points fit a two-element stack buffer. Direct target aiming, including
a wounded soldier's pistol fire, uses the shared Rust aim-point selection too.

The test-only infantry adapter compares 19,200 pose combinations and random
cursors with Godot, covering cover-height boundaries, all six life states,
all five postures, mounted guns and fire steps, movement, trenches and blind
fire. The exact numeric corpus adds 22,464 bytes of pose geometry. This removes
the geometry calculation's Godot dependency; full actor ownership, callbacks
for damage and the battle verifier are still migration work. The full default
suite passes 114 tests; 91 core tests pass in debug and release.

## Bullet resolution

`Bullet` calculates accuracy, misses, obstacle penetration, target damage,
explosive-round placement and near-miss suppression. The stages preserve
intervening gameplay effects: penetrating damage and stray hits precede surface
damage; target damage precedes reading the target's new body center for an
explosion. Each stage returns effects and releases the RNG borrow before the
adapter applies them. A round that misses through a penetrable wall preserves
the existing two wall-damage calls and only considers the first eligible man
behind it. These instantaneous shots finish within one tick; their temporary
state is not a saved battle checkpoint.

The reference fixture compares 12,288 shots, exact vectors, ordered damage and
explosion callbacks, statistics and RNG cursors. It covers infantry, vehicles,
drones, all four cover materials, smoke, optics, trenches, suppression, missed
penetrating rounds and life/pose changes during damage. The native infantry
battle comparisons also cover tank and grenade-drill scenarios, alongside attack,
breach, trenches and fire. Numeric CI adds 38,470 bytes of bullet transcripts.
Actor damage, vehicle armour responses, blast effects and spatial-query ownership
still live in Godot, so this is neither a standalone server nor a full verifier.

## Blast exposure

`Blast` computes infantry and structure exposure, preserving cover materials,
trench shelter, prone protection, falloff, fling strength and near-blast flinching.
Each victim receives damage before fling and flinch, so a death changes the later
reactions in the same order as before. Vehicles, drones, loose props, fire and
crater effects still run in Godot; this does not transfer actor ownership.

The reference fixture covers 2,048 blasts, exact effect order, vectors and RNG
cursors. Pinned software power differs from Godot's platform power by at most
4.27e-14 health in that fixture; its damage comparison allows 1e-10, while the
Rust cross-platform contract compares all 31,104 transcript bytes exactly.
Six native/reference battles also preserve their fingerprints and counters.

`InfantryShock` advances knockback, low-obstacle bounces, landings, flinching and
dazed wandering. It shares infantry turning rules with normal route movement.
The adapter keeps task cleanup and speech in their original order and retains
the same random cursor. The `FLIS` component checkpoint contains fling velocity,
flinging, dazed time and flinch time; position, tasks and other actor state still
need the complete world checkpoint. Numeric CI adds 74,496 bytes of shock state
and movement transcripts. These ports remain behind the infantry compatibility
flag until Rust owns the actors.

The shock fixture compares 92,160 reference steps, including mounted turning,
blocked terrain, carried casualties and task interruption. The full default suite
passes 119 tests; 116 core tests pass in debug and release.

## Grenade reflexes

`GrenadeMemory` retains noticed rounds in encounter order, with the same eviction
threshold as the existing AI. The Rust grenade decision checks nearby casualties,
attempts to smother, throw back or kick in order, then queries shelter before a
dive. The owning world classifies the blocking body's kind. The warning precedes
reaction randomness; task cleanup and speech still run after the decision.
The 4,096-case reference fixture compares actions, handlers, memory, effects,
random draws, kick vectors and cooking times. It includes held rounds, other
handlers, cover, suppression and wounded teammates. `FLGR` checkpoints only the
notice memory; task and handler ownership still require the whole actor/world
port. Numeric CI adds a 75,432-byte reflex transcript.

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

## Infantry target acquisition

Infantry target acquisition uses the shared numeric visibility and collision world
in one call. It preserves the first seven candidates, first-wins score ties,
machine-gunner and downed-target priorities, armor/rocket rules, mounted-gun arcs,
drone override order and forced structure attacks. Flanking contacts are still
reported even when a mounted gun cannot engage them; drones retain their existing
separate reporting behavior. The 600-case reference fixture checks current poses,
smoke, changed vehicle colliders, repeated scans and restored geometry. Contact
poses, behavior tasks and squad state are still supplied by Godot.

The fixture's 1,000-scan comparison includes preparation and report application:
GDScript samples were 42.56–45.16 ms and the packed native path 41.42–43.68 ms.
These overlapping ranges establish no large targeting speedup. The migration
removes repeated dictionary conversion, but retaining entity state inside the Rust
server is still needed to remove the intermediate contact-copy boundary.

## Terrain state

The cover core generates fighting positions from numeric structure parts and
evaluates protection/firing lanes against its collision world. It preserves face
and anchor order, height thresholds, overflow rows, trench fire steps, map limits
and rejection of positions inside other parts. Evaluation retains all threats in
the protection score and stops firing-lane queries after finding one clear lane.
The reference fixture compares 400 structures (8,043 anchors) and 3,000 evaluations
against Godot, including rotated overlapping parts, material classes, prone men,
changed/disabled shapes, raised or lowered ground and collision restores.
Position tolerance is 20 micrometres; normal/direction tolerance is 0.000001.
Anchor kinds, heights, protection fractions and firing decisions match exactly.
The fixture's alternating-order 1,000-evaluation comparison measured 21.16–23.08 ms
through GDScript versus 4.84–5.23 ms through Rust, including adapter work, with
other apps running. This is not a whole-battle FPS measurement. Candidate search,
claims and soldier state still live in Godot and remain migration work.

`Terrain` retains the nine terrain layers, crater height samples and pending cover
repair order. Roads, rectangles, trees, camouflage nets and craters update those
arrays in the core. Cover reconstruction uses numeric structure geometry and
preserves spatial encounter order and equal-cover tie rules. Structures register
their numeric geometry when added, moved or changed; the core retains the index
instead of rebuilding it from scene objects each batch. GDScript mirrors changed
cells for the renderer and remaining gameplay callers. Biome and initial water-shape generation
still run in Godot and import their numeric output; these are outstanding
standalone-server dependencies. Exact trench containment, ground height and
enfilade queries also use the retained geometry, including first-bay order at
junctions. Bridge occupancy is still supplied by the Godot water map.

Terrain checkpoints preserve every layer and height sample, fresh-ground behavior,
the revision, ordered structure geometry and the remaining repair queue. Reference
coverage compares 3,500 query positions, entire cell arrays, partial repair batches,
moved/completed/removed structures, doors, replicated properties, worker-thread
ground imports, edge/overlapping craters and restores between edits. The loading
worker only changes plain arrays; the main thread imports them into Rust while
retaining queued repairs and structure order.
Heights use a 1 micrometre comparison tolerance; cell data and gameplay
multipliers match exactly. This is component validation, not a full battle replay.
Godot's position hash and PCG stream are retained for crater shape generation;
the trigonometric/exponential arithmetic still needs platform equivalence checks.

An alternating-order comparison of the 9,216-cell cover repair fixture measured
GDScript samples of 12.65–17.57 ms versus 4.09–4.21 ms through Rust, including the
adapter's changed-cell copies (six samples each after two warm-up rounds). Other
apps stayed running. This measures cover repair, not a 500-unit battle or FPS.

## Water and joining terrain

`Water` retains coast, river, pond, ford and bridge shapes in a bounded versioned
checkpoint. Numeric queries reproduce shoreline curves, currents and bridge spans.
Painting and carving preserve sea/river-segment/pond order, shore and depth masks,
ford shelves, quay occlusion, bridge decks and the order of changed cells. Godot
still creates the initial shapes and uses its existing per-point water queries;
the runtime raster passes now run in Rust.

Joining terrain loads on a Rust worker over owned numeric arrays. It paints water,
applies the host's ground-kind overrides, refreshes terrain cover, then carves beds.
The main thread installs the result and updates existing image resources. No Godot
binding is called on a worker. The retained GDScript reference handles the legacy
loading path when the native module is unavailable. Leaving a loading world joins
its owned worker before releasing the adapter.

Reference coverage compares 13 raster results and 2,400 shoreline/current/bridge
queries, including overlapping shapes, repeated edits, checkpoints and worker loads.
Terrain kinds, decks, water masks and loaded height textures match exactly; height
samples use a 1 micrometre tolerance. A 9,216-cell paint/carve comparison including
adapter and image updates measured 29.45–33.54 ms through GDScript and 12.68–13.42 ms
through Rust (alternating order, six samples after warm-up, other apps running).
This is small-map loading work, not an FPS or large-map scaling measurement.

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
The terrain port passes all 105 default integration tests, 47 core tests in both
debug and release, and the cover-region and terrain texture/collision seam checks.
Infantry acquisition passes the full 106-test suite. After adding exact trench
queries, 51 core tests pass in debug and release, as do 24 relevant integration
checks covering infantry, armour, ground changes, helicopter flight and 6,000
trench query positions through building, movement and removal.
The subsequent fighting-position generation/evaluation port passes all 107 default
integration tests and 55 core tests in debug and release.
Water rasterization and Rust loading workers pass all 108 default integration
tests, 59 core tests in debug and release, and the delayed client-loading fixture.

A focused shell benchmark (100 shells, 100 ticks, headless, no collision queries)
measured about 14.6 ms for the GDScript path versus 4.6–5.6 ms for retained Rust
flight state. This is not an FPS measurement. The transitional GDScript RNG
adapter costs more per draw than the engine RNG (about 0.4 versus 0.15–0.23 µs in
a 100,000-draw check); direct Rust callers avoid that adapter. Whole-battle scaling
still needs measurement, and the 60 FPS completion gate remains open.
