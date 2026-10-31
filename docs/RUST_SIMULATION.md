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
| Infantry target acquisition | `frontline_core` | Retained actors build perception snapshots and resolve poses, visibility, mounted-gun arcs, weapon priorities, drones and forced targets; the live adapter and squad-report application still run in Godot |
| Gameplay RNG, including commander streams | `frontline_core` | Seeded PCG stream matches Godot 4.7; cosmetic RNG stays in Godot |
| Grenade, smoke, rocket, bomb and shell flight | `frontline_core` | Rust retains and advances flight state and queries native geometry; the adapter supplies holders and applies impacts |
| Retained projectile actors and impacts | `frontline_core` | Ballistic, guided and support actors retain ownership, holder/handler links and attribution with flight checkpoints; ordered impact, spawn, smoke, recon and sound effects still await the Rust world dispatcher |
| Shared actor storage and FPV ownership | `frontline_core` | Infantry, buildings, vehicles, projectiles and drones retain identities, state and shared casualty/transport links together; drones resolve living targets and operators inside Rust. Squad integration and complete world dispatch remain unfinished |
| Squad state and shared knowledge | `frontline_core` | Orders, contact caches, plan links and tactical state have retained checkpoints; centroid, contact reports, threats, succession and casualty morale operate on owned actors. Squad orders, drills and the full squad tick still run in Godot |
| Retained buildings and economy transitions | `frontline_core` | Geometry, links, queues and timers have retained checkpoints; construction, capture, town income and production transitions match Godot. Shared rule effects, destruction, crews and the complete building dispatcher remain unfinished |
| Deferred damage and rubble | `frontline_core` | The live world uses checkpointed explosion deadlines and pending rubble spawns, with an engine-only fallback. Godot still applies the resulting damage and creates structures |
| Spatial bucket ownership | `frontline_core` | Infantry, vehicle, building and closed-door queries use retained actor IDs and preserve cell/registration order through checkpoints |
| Weighted grid paths and cluster pair costs | `frontline_core` | Exact Godot route tie behavior; native cluster workers return costs in deterministic order |
| Boat navigation and driving | `frontline_core` | Water-cell construction, connected bodies, shore searches, routes, currents, steering, traffic, coming about and grounding recovery operate on retained state; the live dispatcher remains in Godot |
| Ground cells, crater heights and queued cover repairs | `frontline_core` | Rust retains terrain and ordered structure geometry, and performs edits, queries and cover repairs; Godot imports biome generation and forwards navigation notifications |
| Water shapes, bridge decks and water terrain rasterization | `frontline_core` | Ordered numeric rasterization; a Rust worker also applies the joining host's ground overrides; Godot still generates the initial shapes |
| Hierarchical route assembly, repairs and danger weights | `frontline_core` | Rust owns graph slots, borders, cost tables, repair order and terrain/danger revisions |
| FPV drone flight | `frontline_core` | Climb, cruise, dive, loss of control and collision; Godot supplies targets and applies damage |
| Guided missiles and support aircraft | `frontline_core` | Flight, target-lock loss, bomb release, burst schedules, pending hits and random draws; Godot supplies contacts and applies events |
| Entity identities and lifecycle order | `frontline_core` | Rust allocates authoritative IDs and retains ordered live identities through spawn/despawn; Godot still owns the corresponding actor state and scene objects |
| Entity state and full actor updates | Rust | `world.gd`, `entity.gd` and entity scripts |
| Infantry route movement | `frontline_core` | Route progress, vaulting, sliding, doors and ground caches extracted and reference-tested; the per-soldier adapter remains test-only because it is slower than GDScript |
| Stationary infantry movement | `frontline_core` | Neighbor separation, terrain settling, cover alignment and watch-sector/mounted turns extracted; the adapter remains test-only pending actor ownership |
| Infantry weapon cycles | `frontline_core` | Cover fire, postures, firing permissions, ammunition and burst recovery extracted with compatibility tests; adapters remain test-only until Rust owns the actor |
| Infantry health, suppression and fatigue | `frontline_core` | Numeric recovery, damage outcomes and down/death/revive transitions extracted with component checkpoints; actor cleanup, squad reactions and damage attribution remain Godot effects |
| Infantry combat geometry | `frontline_core` | Eyes, exposed points, hit factors and cover postures extracted with reference tests; the adapter still supplies actor state |
| Infantry aim selection and sight cache | `frontline_core` | Target, blind and area-fire aiming extracted and reference-tested; the test adapter supplies posed target points and last-known squad contacts |
| Bullet resolution | `frontline_core` | Accuracy, scatter, penetration, hit damage, explosive-round placement and near-miss suppression extracted with ordered stages; Godot still applies actor damage and explosion effects |
| Blast exposure | `frontline_core` | Infantry and structure damage, shelter, fling strength and flinch radius extracted; Godot still owns victims, vehicle armour and effect application |
| Blast knockback and disorientation | `frontline_core` | Fling trajectories, obstacle bounces, landings, flinching and dazed movement extracted with component checkpoints; Godot still applies task cleanup and speech |
| Wounded infantry and corpse timers | `frontline_core` | Bleeding, rescue/medicine modifiers, speech/pistol/crawl schedules and corpse collection decisions extracted; rescuer links, targeting and task effects remain in Godot |
| Grenade reflex decisions | `frontline_core` | Notice memory, protection of nearby casualties, throwback/kick priority, shelter queries, kick direction and cooking time extracted; Godot still owns task application and grenade handlers |
| Grenade task movement | `frontline_core` | Smother, pickup and kick approaches, covering geometry and dive direction extracted; Godot still applies action callbacks and holder links |
| Automatic grenade attacks | `frontline_core` | Contact scores, range/posture gates, throw scatter, ammunition and cooldowns extracted; Godot still supplies squad contacts and nearby groups and applies the throw/cook actions |
| Incoming mortars and busy-soldier grenade notices | `frontline_core` | Ordered warning, range/fuse gates, memory and dive decisions extracted; Godot applies warning, suppression, duck and dive effects |
| Drone hearing and avoidance | `frontline_core` | Ordered hearing memory, warning choices and dive chances extracted with component checkpoints; Godot applies speech and dive effects |
| Infantry special attacks | `frontline_core` | Owned actors select melee, rocket, mortar and drone targets and retain ammunition, cooldowns, pending actions and squad fire queues; the live dispatcher and completed weapon effects remain in Godot |
| Infantry supply decisions | `frontline_core` | Scavenging, nearest-body/depot choices, search timers and refill arithmetic extracted; Godot supplies spatial candidates and applies shared-store transfers, reloads and movement |
| Infantry medical tasks | `frontline_core` | Rescue/healing stages, treatment deadlines, safe-anchor selection, dragging poses and escort movement extracted; Godot still owns patient links, movement requests and recovery effects |
| Construction, stretchers and prisoners | `frontline_core` | Construction priorities/timers, paired carrying stages, bearer takeover and prisoner escort geometry extracted; Godot still applies work, shared casualty links, tent delivery and capture effects |
| Infantry arrival tasks | `frontline_core` | Boarding ranges, tunnel arrival, corpse/depot completion and ordered-throw inventory decisions extracted; Godot still applies boarding, tunnel membership, shared ammunition transfers and throws |
| Mounted infantry | `frontline_core` | Approach/climbing stages, scan clocks, anti-tank target selection and gun traverse extracted; Godot still owns mount links, fire queues and weapon effects |
| Infantry action state | `frontline_core` | Typed pending actions, queued cooked throws, poses and completion admission extracted; Godot still advances the actor controller and applies throws, strikes, launches and door effects |
| Infantry hidden duties and status | `frontline_core` | Hidden-duty deadlines, moving posture, status flags and drone-operator turns extracted; Godot still applies treatment, tunnel and prisoner callbacks |
| Infantry downtime | `frontline_core` | Calm timers, idle choices, conversation partners, timed speech and laughter extracted with checkpoints and random cursor comparisons; Godot still applies the actor's speech effects |
| Infantry scheduling | `frontline_core` | Activity/scan/think clocks, interruption priority, dive movement and order/duty gates extracted; Godot still dispatches task callbacks and the remaining decision loop |
| Retained infantry state | `frontline_core` | A typed actor combines component state, stable links, pending tasks and orders in a validated checkpoint; the live world still owns its Godot soldiers |
| Retained infantry orders and tactics | `frontline_core` | Actors issue and cancel routes, reject stale path completions, apply arrivals, review shelter, choose cover and derive movement speeds and sectors; the live world still dispatches its Godot soldiers |
| Retained infantry movement and observations | `frontline_core` | Actor updates connect recovery, fatigue, movement, automatic replanning, arrivals, separation, posture and status/activity codes; shared world effects and the remaining tick dispatch are still being migrated |
| Retained infantry squad orders | `frontline_core` | Move, halt, follow, attack, retreat, throw, stop and return-to-hold orders mutate the actor and return route/claim effects; player ownership checks and squad/world dispatch remain in Godot |
| Retained infantry actions and casualties | `frontline_core` | Actor state connects pending actions, interrupted updates, dives, blast recovery, damage, down/death/revive transitions and hidden/corpse state; shared combat, squad and world effects still need the complete Rust world |
| Complete fighting-position search | `frontline_core` | Candidate enumeration, reachability, protection, occupancy and final scoring run in one call; Godot supplies nearby structure and soldier records |
| House-entry task phases | `frontline_core` | Stack/door/grenade/entry transitions, deadlines, cooking and room targets extracted with component checkpoints; Godot still owns movement callbacks and squad entry effects |
| House occupancy and breach selection | `frontline_core` | Floor containment, ordered openings, nearest walkable stack positions and competing squadmates extracted; Godot still supplies spatial candidates, squad contacts and decision timers |
| Injury behavior and special tasks | Rust | `soldier.gd`, `soldier_brain.gd`, `combat.gd` |
| Squads, tactics, commander and naval decisions | Rust | Squad, tactics, commander and naval scripts |
| Vehicles and crews | `frontline_core` | Retained state, orders, repairs, boarding, ground/boat driving, flight, target acquisition, crew decisions and weapon operations are reference-tested; the live dispatcher and shared combat/economy effects still run in Godot |
| Battlefield box raycasts | `frontline_core` | Spatial grid with deterministic hit ties; Godot supplies geometry updates |
| Smoke volumes and geometric visibility | `frontline_core` | Rust checks exposed points against collision and smoke, retaining reusable obstruction proofs; Godot supplies target posture and scene changes |
| Route refinement, smoothing, corridor reuse and path requests | `frontline_core` | Native planner retains corridor history and request order; Godot supplies unit positions and delivers completed orders |
| Cover anchors and fighting-position selection | Rust | Rust generates anchors and evaluates protection/firing lanes; candidate search, claims and soldier state remain in cover/combat scripts |
| Supply, construction, upgrades, prisoners, victory | Rust | `rules.gd`, structures and battle scripts |
| Battle ledger and report privacy | `frontline_core` | Retained credit, casualties, captures, commander rejoins, unit/hero history, timeline and team-filtered reports are reference-tested; the live game still updates its Godot ledger |
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

## Entity identity ownership

Authoritative `World.spawn` obtains IDs from `Entities`; removal retires the
identity without recycling it. Lookup uses a hash table, while simulation and
checkpoint iteration retain registration order independently of that table.
Expired slots are compacted in order so prolonged projectile churn does not
accumulate a slot for every entity ever created. Allocation stops before the
existing 32-bit wire ID can wrap. Imported registries reject duplicate IDs,
unknown kinds and an allocation cursor that could overwrite a live identity.

The `FLEN` checkpoint contains the next ID and ordered live identities, including
their kinds. This is lifecycle state only, not an actor or battle checkpoint.
Godot still owns actor fields and the per-kind simulation lists. Clients build
presentation objects using the server's IDs and do not allocate authoritative
ones. The adapter is enabled by default; the test port can retain the GDScript
allocator for reference comparisons. Platforms without the module retain it too.

Core tests cover 20,000 allocations/removals, survivor order through compaction,
checkpoint continuation, exhausted IDs and malformed input. The Godot fixture
compares 4,096 live spawns against the reference lifecycle, checks callbacks and
restores checkpoints between operations. Battle fingerprints also verify that
the Rust identity order and cursor agree with the current scene registry.

## Shared actor ownership

`Actors` retains infantry, vehicle, projectile, FPV and structure actors alongside the ordered entity
registry. Allocation, removal and checkpoints use the same stable IDs; hash-table
iteration never chooses update or serialization order. Restoring rejects mismatched
IDs/kinds, duplicate identities, oversized blocks and unsupported actor kinds.
It does not yet contain squads or the whole match state.

Casualty transitions update rescue claims, stretcher carriers and controlled
drones in this collection. An obsolete rescue release cannot clear another man's
newer claim. Squad breach claims still need the squad owner. FPV flight resolves
its operator and infantry/vehicle target directly from owned actors, preserves its
last aim point when a target disappears, and keeps spawn-time IDs separate from
current links. Detonation and shoot-down remain distinct, idempotent outcomes;
the complete world must apply their damage, notifications and removals.

The Godot comparison covers 384 shared release/down/death/fling transitions and
72 flights over 4,523 steps, including operator/target death and removal,
shoot-downs and repeated checkpoint restores. Eight Rust tests cover allocation
churn, shared cleanup, continuation, attribution and malformed input; numeric CI
adds 751,072 exact bytes. This collection is not a standalone match server.

## Retained vehicles

Vehicle checkpoints retain crew interruptions and saved orders, passenger and
sling links, ground/boat routes, flight controls, weapons, repair progress,
artillery queues, avoidance limits and naval recovery timers. Visual suspension,
models and interpolation caches are excluded. Nonfinite sentinels become typed
optional values; NaN is rejected rather than silently treated as absent.

Vehicle move/assault/attack/stop orders preserve crew withdrawal gates and stale
route rejection. Repairs, missile rearming, observation flags, turret drive limits
and settled aiming operate on retained state. Shared boarding updates both the
vehicle and the soldier, including hidden duties and occupied seats. Unit buckets
keep soldiers before vehicles, even when their entity registrations interleave.

The fixture compares 25,315 vehicle states across the roster, repairs, orders,
target changes, turret steps, shared boarding and checkpoint resumes. Live imports
also cover roster battles, naval movement, helicopter supply and sling operations.
Numeric CI adds 543,888 bytes.

Ground driving now updates retained steering, speed, route indices and recovery
directly, borrowing Rust navigation and terrain. It preserves tracked pivots,
wheeled turn limits, braking, reversing, traffic spacing, obstacle avoidance,
attack-move stops and the truck's lane offset. Stuck recovery retains random
draws and route revisions; rejected input cannot partially move the vehicle.
Turret and hull motors share the same acceleration/braking calculation.

The driving fixture compares 26,880 steps across the ground roster with moving
traffic, impassable ground, trenches, interrupted movement and checkpoint resumes.
Six core tests cover continued trajectories, recovery, invalid inputs and turning
constraints; numeric CI adds 1,304,492 bytes. Shared collision effects and full
vehicle combat dispatch still need to move before the
Rust world can run the complete battle. This adapter is a reference test, not a
new per-vehicle runtime boundary.

Combat crews now decide directly against retained vehicle state and borrowed
contacts/navigation. Withdrawal, repair at a FOB, missile evasion, saved-order
resumption, waiting for friendly infantry and facing nearby threats preserve
the existing priority, deadlines and player override. Crew-owned moves do not
discard the saved order. Notifications, counters and route requests return as
ordered effects for the world dispatcher; no Godot callbacks run in the core.

The crew fixture compares 12,288 steps with the existing behavior tree, including
mission retreat limits, missing FOBs, hidden threats, mounted infantry, resumed
orders and checkpoints. Seven core tests cover priority, support, deadlines,
continuation and rejected input. Numeric CI adds 515,853 bytes. The live vehicle
dispatcher still uses Godot while flight, combat and shared effects migrate.

Rotorcraft guidance now updates retained position, velocity, heading, cyclic
pitch/roll and pilot yaw rate against Rust terrain and bridge decks. Momentum,
hover braking, ground clearance, cargo handling and fixed integration substeps
match the existing pilot. UAV guidance retains orbit phase, course changes and
turning limits. The aircraft controllers still need their scan/fire dispatch.

The flight fixture compares 24,000 steps across the aircraft roster, including
course changes, sling loading, landing, bridge decks, terrain height and saved
state. Six core tests cover hover settling, coarse steps, clearance, loaded
handling, checkpoint continuation and invalid input; numeric CI adds 461,672
bytes. Godot still dispatches flight during a live battle.

Sling operations now update the helicopter and cargo in the same retained actor
collection: admission, pickup orders, hooking, swing, release and cleanup when
either actor disappears. A dropped load returns its fall-damage and impact event;
the complete vehicle combat dispatcher must still apply that damage in Rust.
The reference fixture compares 9,117 states, including capacity/type/team gates,
blocked landing cells, removed actors, gentle drops and damaging falls.

Transport pilot phases retain climb, cruise, touchdown, stable pickup hover,
unloading delays, holding and return-to-pad orders. Supply pilots retain ordered
destination scoring, captured/destroyed-destination handling, delivery requests
and return flights. The 76,800-step reference fixture compares the pilots' state
and ordered cargo/delivery requests, with shared effects checked separately. It
does not claim a complete aircraft combat tick. Twelve core tests cover these
transitions and shared sling links; numeric CI adds 1,004,404 exact transcript
bytes, including checkpoint continuation. These operations await live integration
with the Rust world and economy.

Vehicle armour and firing cycles operate on retained state. Bullet and blast
damage preserve soft/light/heavy armour, anti-air fire, front/rear/top hits,
ricochets, blast shove, track breaks, alerts and the destruction trigger. Shared
destruction remains a world effect: heavy-armour ricochet draws happen after AP
damage, so escaping passengers can consume randomness first.

Weapon selection preserves SAM/ATGM priority and deadlines, settled tank aim,
cannon worthiness, machine-gun range/armour restrictions and burst lengths.
Shot completion runs after shared effects, preserving the burst-recovery draw
after bullet damage. The world still needs cannon geometry,
shared damage/crew effects and the complete firing dispatcher.

Godot fixtures compare 7,392 damage states and 21,120 firing cycles across the
roster. They compare ordered requests, random cursors and checkpointed state;
controlled shared-effect draws expose sequencing mistakes without claiming full
vehicle destruction coverage. Twelve core tests cover these rules and rejection
without mutation. Numeric CI adds 1,627,548 exact transcript bytes.

Dismounts update retained infantry and transport state together, preserving
passenger order, skipped or removed passengers, boat shore placement and the last
exiting squad's assault/defend request. Arrival, damage, visible-enemy and boat
landing checks use owned actors and the retained spatial index. The complete
squad dispatcher still needs to apply the resulting order and leader speech.
Reference checks compare 640 vehicle states and 621 passenger states plus order
requests. Five core tests cover exits, repeated passenger entries, retained orders,
landing gates and invalid steps; numeric CI adds 4,823,547 exact transcript bytes.
The existing bounded nearest-cell fallback is preserved, including its result
when a boat's local search finds no bank.

Guided vehicle launches and defensive smoke create owned projectile state and
allocate stable identities inside Rust. Launch warnings preserve named targets
and the first eligible vehicle in registration order. Smoke preserves ammunition,
cooldowns, four grenade trajectories and random continuation. Weapon completion
remains after synchronous launch warnings; smoke precedes the crew response.
The launch fixture compares 1,816 vehicle/projectile states and warning checks,
including aircraft launch positions, removed targets and checkpoint restoration.
It isolates projectile creation from crew evasion, which has separate reference
coverage; the complete shared firing dispatcher remains unfinished. Five core
tests cover creation, warning order, continuation and rejection without mutation.
Numeric CI adds 773,648 exact launch transcript bytes.

Artillery retains queued fire missions, automatic-target admission, laying and
reload delays, aim gates and salvo progress. Each round creates owned shell state
with its scatter, origin, destination and flight duration before the salvo advances.
Gunship rockets allocate one round at a time, allowing warnings and smoke draws
before the next round's spread. Reference fixtures compare 39,509 states, including
queued versus automatic targets, stalled aiming, shell variants and interleaved
smoke. Godot's stored laying angle differs from portable libm by at most
1.78e-15 radians in this fixture; that reference angle allows 1e-12 radians, while
Rust checkpoint continuation and cross-platform numeric transcripts remain exact.

Gunship control preserves scan and rocket clocks, attack orbits, destination
limits, target facing, damaged-aircraft altitude and salvo gates. A further 19,200
reference steps compare lost targets, sparse infantry and all attack-helicopter
variants. Weapon effects and crew reactions are checked separately from this
guidance fixture. Nine core tests cover these artillery/rocket/gunship operations;
numeric CI adds 6,184,235 exact transcript bytes. Target selection, shared combat
effects and the whole vehicle/world dispatcher still need full integration.

Cannon shots resolve target posture, barrel sockets, turret pivots and aircraft
attitude from retained actors. The shot uses Rust terrain and collision, including
trench-lip impacts and enfilade, and returns muzzle/blast data for ordered effects.
The reference fixture compares 1,320 muzzle/shot states across the roster,
including unmapped-model fallbacks, blocked rays, trench geometry and checkpoint
resumes. Six core tests cover those cases, shared RNG continuation and invalid
input without mutation. Numeric CI adds 772,224 exact transcript bytes. This
retains the shot calculation; the shared blast/destruction dispatcher is still
being connected to the owned world.

Boat navigation retains weighted water cells and derives connected-water labels
on loading. Terrain import preserves shallow-water costs, impassable bridges and
partly dry cells. Shore searches, hull-width clearance and six-metre route
waypoints retain the existing tie order. The reference fixture compares 3,072
query sets against Godot's own AStarGrid2D, including disconnected water, bridges,
shoreline ties, weighted routes and checkpoint restoration.

The complete boat-driving controller now operates on retained vehicle, water and
navigation state: throttle/rudder response, drag, skid, current, attack speed,
traffic, backing into close destinations, coming about into open water, rejoining
routes and backing off a bank. Ground and boat driving share avoidance logic,
with each using its own passability query. The fixture compares 43,200 steps,
including grounding, rejoining and seaward turns, across all six boat types.
Twelve core tests and a 2,173,616-byte numeric transcript cover the navigation and
controller. This does not yet replace the live vehicle/world dispatcher or boat
destruction and disembarkation effects.

Support vehicles now update retained recipients directly: repair HP and tracks,
refill rifle/special ammunition and vehicle missiles, heal nearby troops and
revive uncarried casualties. Infantry follows spatial-bucket order, then vehicles
follow registration order. Reload speech consumes its random draws before special
ammunition; revival speech follows the medical chance. The one-second service
cadence and moving-vehicle gates retain existing behavior. Recipients are staged
until content checks finish, so a missing loadout cannot leave a partial refill.

The fixture compares 36,864 actor states plus speech, service counters, property
updates and random cursors against the existing service tick, including disabled
weapons, opposing teams, hidden/dead men, carried casualties and reverse motion.
Six core tests cover shared effects, checkpoint continuation and rollback;
numeric CI adds 4,480,649 exact bytes. Battle statistics and presentation effects
return to the world dispatcher; the live game still uses the Godot service tick.

Vehicle acquisition now reads retained actors and spatial buckets directly. It
derives infantry exposure from owned posture, cover and mount links, then checks
collision and smoke without a Godot callback. Current-target preference, aircraft
and missile priorities, building visibility, forced targets and repeated nearby
squad reports preserve the existing order. Buildings are queried only when no
unit was selected. Unchanged obstructions reuse the existing visibility proofs;
smoke and moved obstacles are checked again.

The fixture compares 4,224 scans across the vehicle roster against the actual
Godot scan, including selected targets, report order and obstruction reuse.
Eight core tests check ties, aircraft eligibility, smoke, moved walls, removed
mounts, building fog, forced-target range and invalid input. Numeric CI adds
157,776 exact bytes, with actor checkpoint continuation. This acquisition path
is ready for the Rust world; the live vehicle dispatcher still runs in Godot.

## Retained squads

`Squad` retains ordered membership, known/heard contacts, briefing and centroid
caches, orders, formation slots, morale, drill/tactic deadlines, queued mortar
missions, clearing assignments and links to attack/ambush plans. Plan identities
must be supplied by the importer; the referenced plan state is not contained in
the squad checkpoint. Diagnostic behavior-tree strings are excluded.

Centroids, combat status, shared threat selection, leader succession and casualty
morale now operate on owned actors. Equal-distance threats retain reporting order;
new contacts invalidate the appropriate caches, while repeated contacts preserve
the existing briefing cadence. Succession and casualty speech consume the same
random draws and update the speaking soldier's cooldown.

The fixture compares 1,024 complete squad/actor states and RNG cursors, including
removed members, wounded/dead contacts, delayed briefings and checkpoint restores.
Live captures also preserve squads in eleven battle scenarios at 0/10/30 seconds
and on the 500-soldier, 2,048 m map. Seven core tests cover strict decoding,
continuation and shared decisions; numeric CI adds 3,320,016 bytes. Full squad
orders, tactics, morale upkeep and battle-drill dispatch still need migration.

## Retained structures

`Structure` retains building state, collision/navigation parts, cover anchors,
spatial membership, supply/capture state, pending production, crew/passenger links,
fire state and private work timers. Scene objects, model colours, network dirtiness
and cosmetic toss animation are not authoritative state. The ordered actor
collection accepts structure checkpoints alongside soldiers and projectiles.

Construction, repairs, extinguishing, doors, charred variants, staggered building
clocks, town income/house loss, capture and production transitions have Godot
comparisons. Last-FOB capture slowdown, contested towns, alert cooldowns, research
ignoring the unit cap and the existing production-fraction cadence are preserved.
Results return capture/completion effects for the world dispatcher to apply.

The fixture compares 1,152 complete structure states, including checkpoint
restoration and actor registration. Live imports also preserve structures in
eleven battle scenarios and the 500-soldier, 2,048 m map. Nine core tests cover
state decoding, actor ownership and transition boundaries; numeric CI adds
1,873,704 exact bytes. Destruction, shared economy effects, crew assignment
and the full building dispatcher remain in progress.

## Deferred damage and rubble

Ammo-cache cook-offs now schedule explosions in an owned Rust queue. Deadlines
use battle time; the world drains due events after commanders/mission updates
and before recording the completed tick. Equal deadlines keep insertion order,
and blasts caused by a chain reaction wait for a later step. Rubble creation
follows those blasts, retaining request order and registering ruins before the
next step. Leaving a match discards its queues. Engine-only checkouts use the
same clock and ordering.

This deliberately replaces scene-timer delivery with the first simulation step
at or after each deadline. Damage, scatter, random draws and the existing
five-to-nine-blast profiles are unchanged. Queue checkpoints preserve deadlines,
sequence allocation, pending explosion data and pending rubble descriptors.
Invalid schedules leave the queue and RNG untouched; restores reject overdue
or duplicate events.

The reference fixture compares 38,400 steps and 2,554 blasts, including checkpoint
resumes, equal deadlines, unchanged battle time and the live world's delivery
path after the cache is freed. Rubble checks cover checkpoint resumes, destroyed
buildings and ruins created by a deferred blast. Five core tests cover delivery,
continuation and invalid input; numeric CI adds 924,970 bytes. Scenario callbacks
still need simulation-owned scheduling for whole-battle replays.

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

`native/core/tests/numeric_contract.rs` compares 68,644,649 committed bytes without
tolerances: fixed-tick flight state, support events and RNG cursors, carved water,
craters, rotated box hits, cover anchors, spherical interpolation and infantry
movement, infantry cover fire, postures, ammunition, burst recovery, vitals, aiming,
combat poses, bullet resolution, blast exposure, knockback recovery and wounded
infantry schedules, grenade reflexes, grenade task movement and house-entry
phases, building selection, automatic grenade attacks, incoming shells and drone
reactions, special attacks, infantry supply, medical/work duties, arrival tasks, mounted weapons, action state, hidden duties, downtime, scheduling, complete cover searches and stationary
infantry movement. CI runs
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
passes 179 tests; 507 core tests pass in debug and release.

## Spatial query state

Spatial indexes retain bucket membership independently from current actor positions.
The existing tick builds unit buckets before movement, then queries current positions
inside those buckets. Checkpoints preserve both states, including bucket insertion
order, so an intervening command cannot change which equally suitable unit is chosen.
Building queries deduplicate overlapping cells in encounter order; door queries keep
the first blocking door. Removed actor IDs are ignored. Wide queries visit occupied
cells rather than enumerating an unbounded empty rectangle.

The fixture compares 8,192 query cases across movement, removal and checkpoint
restoration. Live snapshots compare infantry, building, floor and door queries in
fourteen battle scenarios and the 500-soldier, 2,048 m map. Unit queries include
retained vehicles in the same ordering as the Godot world. Numeric CI adds
665,896 bytes of index state and ordered results. This is shared query ownership,
not the complete Rust tick or a new live-game performance claim.

## Retained projectiles and impacts

`Projectile` combines the existing ballistic, guided and support flight states
with thrower/player credit, target identity, holders, handlers and throwback
counts. Pickup, kicking, rethrowing and lost holders mutate that same state.
The impact stage preserves blast profiles, armour direction, smoke rounds,
smothering, missile lock loss and support-aircraft child-round attribution.
Smothering is tested at the grenade's position after its final flight step.

Impacts return ordered effects for the world: injury, explosion, spawned round,
recon mark, sound, notice, counter and removal. The world still needs to apply
them to its complete actor set. The Godot fixture compares 168 cases and 46,825
steps, including effect order, all flight variants, handler changes, RNG and
checkpoint continuation. Numeric CI adds 1,286,942 exact state/effect bytes.
Actor checkpoints and returned effects do not replace the unfinished battle
checkpoint, command replay or standalone server.

## Retained infantry actions and casualties

Retained soldiers now run action starts/poses/completions, cooking into a queued
throw, fatigue and interruption priority, diving, flinching, blast flight and
dazed recovery. Returned combat effects still need application by the world;
they do not call scene objects. The fixture compares 16,896 steps against the
existing actor, including complete actor state, RNG and checkpoint restoration.

Casualty operations release rescue, stretcher, breach and drone links by stable
ID, stop routes, retain loot, restore wounded soldiers and preserve shelter,
vehicle-following and corpse deadlines. The world must apply shared releases
only when the other actor still belongs to that relationship. The fixture
compares 3,072 actor transitions, including death impulses and random cursors.
The numeric corpus adds 2,023,864 action/interruption bytes and 1,159,863 casualty
bytes. These are actor checks; whole-battle replay verification remains unfinished.

## Infantry tasks and reflexes

Typed squad orders now operate on the retained actor. Formation adjustments keep
a nearby route, retreat can release a rescuer, and a breacher with a cooked grenade
keeps his commitment before following a new move order. Mount release resets its
aim and places the gunner back on walkable ground. Shared rescue and breach claims
are returned as stable-ID effects for the world to apply before route dispatch.
These are internal squad orders, not a socket command authorization layer.
The Godot fixture compares 3,840 combinations of life, duty, phase and order,
including shared claims, route requests, checkpoint resumes and rejected input.
Numeric CI adds 1,255,452 exact transcript bytes for these commands.

Retained movement now connects the route controller to automatic replanning and
arrival handling. Recovery, fatigue, separation, stationary movement, posture and
status/activity observations also read and update that same actor. Shared effects
return stable IDs and ordered data; a door-opening event retains the soldier's
position before movement so nearby enemy reports keep their original meaning.
These methods do not advance the complete actor brain or world yet.

The connected update fixture compares 18,000 movement steps, including geometry,
door effects, speech, random draws and intermediate actor checkpoint restores.
It also compares 8,880 activity-label cases across life states, duties and actions.
Numeric CI adds 886,128 exact transcript bytes for the connected updates.

Retained actors apply route requests and completions directly. Each request has a
revision, so a delayed result cannot replace a newer order. Unreachable cover,
cancelled routes, arrival posture and prison arrivals retain their previous order
and random draws. The world receives a typed route or prison event; there is no
Godot callback inside the actor.

Cover review, seeking, flank/rear sectors and movement speed also operate on the
retained actor. The search uses the existing native terrain, navigation and
collision world. Its choice changes cover state and issues the next route in one
operation. Destroyed, moved or burning shelter, suppression, fatigue and crawling
keep their existing thresholds. The bindings share the scene importer used by
the live cover search. These actor operations are not yet the live world loop.

Godot comparisons cover 4,096 route-order cases and 10,240 tactical checks, including
the resulting actor state and random cursor. Core tests also reject invalid input
without changing the actor or random stream. Exact cross-platform transcripts
cover both operations and checkpoint continuation.

`Infantry` combines the retained components with identity, catalogue keys, queued
paths, fighting positions, duty phases, casualty links, house entry, mounted-gun
orders and contact memory. Its `FLIN` checkpoint preserves private pending work
alongside observation fields; visual objects, animation and render timing stay
outside it. Entity links are bounded stable IDs, and absent actors can be
represented without retaining a Godot object. The enclosing match checkpoint
still needs the world's queues, definitions, squads, geometry and random streams.

Import and restore validate types, numeric versions, text, collection limits and
all embedded component states before replacing a retained actor. Tests cover
resuming controller draws, ordered links, maximum component blocks, truncation,
nonfinite values and removed entities. The Godot import uses the same component
conversions as the compatibility adapters. This import is for transferring state,
not a new per-frame serialization path. Numeric CI adds 166,320 actor transcript
bytes; actor checkpoints alone do not verify a complete battle.
The real-battle checks also cover switching between 1,024 m and 2,048 m maps
with the same seed. Biome reuse now checks both image and grid dimensions;
previously a same-seed reload could install the previous map's smaller ground
array into the larger world.

`Controller` retains activity, scan, think and dive clocks in an `FLSC` checkpoint.
Its update stages preserve dazed, dive, action and flinch priority before thinking
or ordinary duties; inactive stages do not advance their timers or consume draws.
An action completion or thought that starts a new interruption cannot also execute
an ordinary task in that tick. Dive movement shares the native navigation grid.
The order and busy-duty gates retain the distinction between rescuing a casualty
and accepting a retreat. A 35,328-case fixture compares callbacks, timers, poses,
navigation, state, order gates and RNG against the previous controller. Numeric
CI adds 583,501 bytes. Task callbacks and the remaining decision loop still run
in Godot; this scheduling adapter remains test-only.
The compatibility suite also compares a generated battle with commanders for
120 seconds and 500 soldiers fighting on a 2,048 m map for 30 seconds. State
fingerprints and behavior counters match at each sample (30 and 10 seconds,
respectively). These headless comparisons check behavior, not rendering speed.

`Idle` retains calm time, activity, deadlines, the conversation partner, queued
lines and laughter in an `FLID` checkpoint. Ordered partner selection, idle
choices, conversation scripts and random draws preserve the existing behavior.
Speech is delivered one event at a time, retaining any random draws in callbacks.
The world still owns the shared team conversation cooldown. A 32,768-step fixture
compares both speakers, interruption, dialogue, callbacks and RNG, including two
removed-object cases. Target validation accepts stale references before checking
their lifetime, so Godot's argument type check cannot abort the update first.
Numeric CI adds 329,943 bytes. The adapter remains test-only pending actor ownership.

`Control` retains hidden-duty deadlines and the previous simulated position in
an `FLCT` checkpoint. Vehicle passengers follow their vehicle without advancing
that deadline; treatment, tunnels and prisoners keep their existing release
order. Motion posture corrections, status flags and drone-operator turns use the
same thresholds as the existing controller, including mounted traverse limits.
A 28,672-step fixture compares state, effects, random cursors and tunnel membership.
Four removed-object cases cover vehicles, tunnels, drones and treatment tents;
invalid binding inputs leave retained state unchanged. Numeric CI adds a
194,852-byte transcript. The adapter remains test-only pending full actor ownership.

`ActionState` retains typed action payloads, duration and a queued cooked throw.
Completion checks the current grenade holder, kick range and target lifetime.
A failed kick still ducks; cooking starts the queued throw before its speech;
callbacks run before later state effects such as the kick's duck timer. Action
poses preserve cooking stance, launcher tracking and instantaneous initial facing.

The 24,576-step frozen-reference fixture compares all action kinds, callback order,
queued transitions and random cursors. Seven removed-target cases cover rockets,
drones, melee, doors, pickup, rethrowing and kicking. The `FLAC` checkpoint retains
the pending action and queue; the Godot adapter still applies actor effects and
remains test-only. Numeric CI adds 1,593,816 exact bytes.

`Mount` retains climbing phases, the anti-tank scan timer and selected target.
Gun laying uses the same traverse limits as infantry movement. Anti-tank scans
preserve the 130 m range, last-contact distance ties, team visibility, exposed
points, smoke and obstruction reuse. The adapter keeps mount claims, fire queues,
cooldowns and shot effects in their existing order and remains test-only.

A 15,360-step frozen-reference fixture covers watchtowers, both machine-gun nests,
mortar pits and anti-tank posts, comparing state, shots, callback order and random
cursors. Removed mounts are checked before casting or using their old references.
The `FLMT` component checkpoint retains approach and scan state; it does not
contain the whole soldier or fire mission. Numeric CI adds 566,843 exact bytes.

`infantry_travel` preserves boarding ranges, helicopter height gates, boat pickup
after reaching the water's edge, route refreshes, tunnel entry and ordered throws.
Supply arrival preserves shared corpse transfers and the depot's completion
threshold, including the existing signed transfer if another refill happened on
the way. Effects still run in Godot and the adapter remains test-only.

A 24,576-step frozen-reference fixture checks positions, routes, inventories,
vehicle seats, tunnel membership, callbacks and RNG cursors. Removed destinations
are checked before casting their old references. Unknown grenade types are
rejected before command ownership or tasks change; frag and smoke orders retain
their existing behavior. Numeric CI adds 53,248 exact arrival-decision bytes.
Naval and tunnel scenarios also join the native/reference battle comparisons.
The tunnel comparison exposed a shared conversation cooldown that survived a
new match and changed subsequent random draws even in two reference runs. That
cooldown now belongs to the world; the reload regression exercises actual banter.

`Duty` retains construction sound deadlines and stretcher/captor stages. Work
preserves completion, suppression, movement and nearby-threat priorities. Paired
bearers wait for one another, claim a casualty together and transfer to solo
dragging if a partner is lost. Prisoner escorts preserve approach distances,
blocked-ground fallback and the existing idle RNG draw. Work/capture callbacks,
shared casualty links, tent delivery and return orders still run in Godot, in
their original order. The adapter remains behind the infantry compatibility flag.

A frozen GDScript reference compares 30,720 duty steps and their effects, including
RNG-consuming callbacks. Six removed-object cases cover prisoners, casualties,
partners, tents, work targets and nearby threats. `FLDU` component checkpoints
retain phase, task timer and construction-sound timer; numeric CI adds 901,120
exact transcript bytes. These are not complete actor checkpoints.

`Treatment` retains rescue/healing stages and treatment deadlines. Rescue keeps
the approach range, route refresh, casualty claim, drag and treatment sequence;
healing keeps medicine modifiers and the shorter treatment for a living patient.
Escort movement preserves side selection, blocked-ground animation and mounted
turn limits. Dragging and safe-anchor selection use the same movement and
navigation core as other infantry tasks. Godot still applies patient links,
movement requests, speech and recovery effects in their original order.

An 18,432-step reference fixture compares these tasks, including RNG-consuming
callbacks, pending paths, invalid patients and checkpoint resumes. Four removed-
entity cases also verify that rescue, healing and escort release stale references
before casting them. Numeric CI adds 323,584 exact medical transcript bytes.
The adapter remains test-only pending authoritative actor ownership.

`InfantryMotion::stationary` applies spacing, refreshes the ground cache, settles
onto terrain/bridge decks, aligns the soldier with cover and turns toward cover
or a watch sector while preserving firing and mounted-turn restrictions. The
ordered separation query preserves overlap RNG draws and ignores hidden/dead
neighbors. A 15,360-step reference fixture compares positions, orientation,
ground-cache deadlines, shuffling and RNG cursors, with checkpoint resumes.
Numeric CI adds 327,680 bytes of stationary movement and separation transcripts.
These adapters remain test-only; actor ownership and the rest of the soldier
controller still need migration before a standalone server can run them.

`SupplyTimers` retains scavenge and destination-search deadlines. Scavenging
preserves the ordered nearby-body query and the truncated 65-percent ammunition
threshold. Destination searches preserve body priority, strict distance ties,
cache/FOB preferences and destination scatter. Replenishment keeps integer
magazine-reserve increments and four ordered special-ammunition draws; reload
and its speech finish before those draws. Shared corpse stores, movement and
the resupply arrival task still belong to Godot. `FLSU` checkpoints contain the
two search deadlines. A 16,384-step reference fixture compares ammunition,
corpse loot, destinations, reloads, callbacks and RNG cursors; numeric CI adds
209,936 exact transcript bytes.

`InfantryArsenal` retains rocket, drone and mortar ammunition and their cooldowns,
plus melee recovery. Rocket targeting preserves visible-vehicle priority,
reported vehicle age/range gates, native collision/smoke checks and forced
structure fallback. Melee retains the world's ordered nearby-soldier query.
Mortars preserve queued fire missions, queue cancellation outside 25–140 m,
automatic search delays and firing intervals. Drone launches retain their
controller gate, search delay and randomized recovery. The test adapter still
asks Godot rules for mortar/drone targets and applies the existing action effects;
this is not complete infantry ownership. `FLAR` checkpoints contain ammunition
and cooldowns. Numeric CI adds 140,052 exact transcript bytes.
The 32,768-decision reference fixture checks targets, cover, smoke, inventory,
cooldowns, queue consumption, action effects and their random cursors. It also
checks the ground-cache update and the state visible to target-query callbacks.

Drone hearing and avoidance also run in the core. `DroneMemory` preserves hearing
order, its 17-entry eviction rule, altitude-aware distance, warning choices and
the chance to dive from a close attack. Warning RNG draws remain between their
corresponding dive checks; the adapter delivers the resulting cosmetic speech
events before applying a dive. `World.say` only emits a cosmetic event and does
not consume gameplay randomness. The dive's direction draw remains afterward.
A 20,480-step reference fixture compares real warning events, ordered memory,
dive state, movement cancellation and final RNG cursors. `FLDM` checkpoints
retain hearing memory; numeric CI adds 96,510 exact transcript bytes.

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
Mortar warnings share this memory, so it can exceed 25 entries before a new nearby
grenade causes eviction. The adapter and checkpoint reader accept that history;
long histories use a lookup set while retaining encounter order. A 65-shell
regression checks the real warning path, checkpoint restoration and the next
grenade's warning and eviction behavior.

Incoming mortar decisions now use the same core memory. They retain the projectile
order, urgent-warning distance, suppression/duck sequence and early exit on a
dive. Busy soldiers retain their existing duck-only mortar response. The busy
grenade reflex shares the ordinary notice implementation, with its existing
gone-round handling; its unused alternate throwback branch has been removed.
The adapter applies warnings and dives in order, preserving intervening speech
and dive random draws. Numeric CI adds a 92,488-byte shell-notice transcript.
A 12,288-step reference fixture checks both duty modes, warning order, shared
memory, suppression, ducking, dive directions, path cancellation and RNG cursors.
The busy-grenade path is also compared with the previous implementation.

Grenade task movement also runs in the core: closing on a round, the fuse
deadlines for pickup and kicking, the one-second smother approach, chest-cover
geometry and dive direction. A 46,080-step fixture compares the task controller
with the existing code, including blocked approaches, mounted turns, changing
holders, disappearing rounds and the subsequent pickup, rethrow and kick action
callbacks. Those callbacks and entity links remain in Godot until actor ownership
moves. Numeric CI adds a 16,090-byte movement transcript.

`GrenadeAttack` retains grenade inventory and the next check/throw deadline in an
`FLGA` checkpoint. It ranks the squad's contacts by nearby enemies and hard cover,
preserves the first tie and applies the same range, posture and contact-age gates.
It consumes the chance, scatter and cooldown draws before the existing cooking
and action callbacks. Godot still supplies squad memory and nearby-group counts.
The reference fixture compares 12,288 decisions, including cooking, queued throws,
speech, ammunition, cooldowns, random draws and contact selection.
Numeric CI adds 67,540 bytes of attack state, throws and RNG cursors.

## House entry

`Breach` owns the five entry phases, stack and grenade deadlines, cooking start
and the empty-room clearing flags. Its `FLBC` checkpoint preserves these fields;
it does not include the actor's route, house/door references or squad claims.
The controller preserves the movement and weapon callbacks before each phase's
decision. Doors must be kicked before throwing, cooked fuses retain their minimum,
and a new order waits until the grenade delay ends before returning to the squad.
Stack-side geometry and grenade placement inside the room also run in Rust.
The adapter still applies door, grenade, speech and buddy-entry effects in Godot.
The 46,080-step reference fixture checks phase state, routes, action callbacks,
door opening, throws, buddy orders, speech, squad claims and RNG cursors. It also
exercises abandoned contacts, destroyed doors, stalled paths and changed orders.
Numeric CI adds 148,944 bytes of phase state, geometry, decisions and RNG cursors.

The building-query core tests floor containment and doorway/window geometry in
the same encounter order as the host. Breach selection compares the nearest
walkable stack positions, retains the window penalty and yields immediately if a
better-positioned squadmate could take the first suitable contact. The adapter
still supplies the spatial candidates and the squad's cached contacts. Native
nearest-walkable searches share the existing path planner's ordered ring search.
A 2,048-case reference fixture compares breach choices and 16,384 occupancy
queries, with rotated houses, openings, blocked ground and squadmate competition.
Numeric CI adds a 79,993-byte building and doorway transcript.

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

## Retained infantry firing

Infantry aiming now resolves target poses, exposed points, recent squad reports
and covering-fire orders directly from retained Rust actors. The sight deadline
and obstruction reuse survive checkpoints; blind fire keeps its original random
draws. Squadmates respond in member order, and muted speech still consumes the
same draws. Squad morale determines accuracy and pinning thresholds.

Shot preparation retains ammunition, bursts, speech cooldown, activity and last
shot time. Muzzles come from authoritative pose and catalog mount geometry,
including trench guns, traverse limits and blind fire. Bullet effects run before
shot recovery, so their random draws and changes to suppression or weapon affect
the next burst exactly where they do in Godot. The shared bullet dispatcher and
full soldier decision loop still need migration.

The fixture compares 12,288 complete actor states, aim selection, speech, random
cursors and state on both sides of the bullet-effect boundary. Muzzles use a
10-micrometre Godot comparison tolerance; Rust numeric CI checks 3,412,306 exact
bytes across firing, aiming and checkpoint continuation. Ten focused core tests
cover thresholds, suppressed speech, missing content and resumed firing.

The retained weapon sequence also advances reload/fire clocks, applies the cover
cycle and covering responses, moves along eligible unclaimed cover anchors, then
chooses posture, checks sight and lays the gun. The cover shift uses retained
structure anchors, squad claims, spatial membership and navigation; its route
request precedes stance selection. Mounted guns track their target during burst
cooldowns and fire only within traverse and alignment limits. Normal, escort and
crew modes retain their suppression, movement and hit-dirt exceptions.

The complete Godot weapon-tick comparison checks 49,152 actor states, including
shared squad caches, speech, counters, route requests and shot state before and
after effects. Ten core tests cover ordering, claims, reachability, pinning,
traverse and invalid inputs. Numeric CI adds 5,641,041 exact bytes. These calls
are ready for the Rust world loop; the live soldier loop remains in Godot.

Retained resupply now transfers shared corpse stock, chooses nearby bodies,
caches or FOBs, issues routes and returns to the hold position after collection.
Search and speech cooldowns, wrecked-FOB ranking, mounted reload overrides and
random draws keep their existing order. Seven core tests cover stock contention,
cooldown boundaries, ties, missing targets and rejected-route atomicity. The
Godot comparison checks 13,824 complete actor states and numeric CI adds
4,517,466 exact bytes, including resumes from saved state. The live dispatcher
still runs in Godot.

Shared infantry combat effects now update owned recipients, released casualty
links and both squads together. Damage retains last-enemy attribution, reports,
winning morale, casualty morale and speech order. Suppression reads retained
mounts and trench posture; bullet near misses preserve spatial order and skip
friendly, dead and directly hit soldiers. Muted speech still consumes the same
random draws. The Godot comparison checks 18,432 complete actor states and squad
states, speech, counters and damage credit. Seven core tests cover shared effects
and atomic rejection; numeric CI adds 1,689,413 bytes with checkpoint resumes.
Full bullet/blast dispatch and the world loop remain unfinished.

Cover searches and reevaluation now use retained squad contacts, nearby soldiers
and borrowed building anchors. They preserve stale spatial membership until its
scheduled rebuild, squad-wide claims, destroyed or burning cover, route requests
and the exact timing of shared combat-cache refreshes. Six core tests cover these
boundaries and atomic rejection. The Godot fixture checks 27,648 complete actor
states, squad state, routes and RNG continuation; numeric CI adds 726,912 bytes.
This removes anchor-array packing from the owned operation; it is not a measured
whole-battle speedup, and the live soldier dispatcher still runs in Godot.

## Owned special attacks

Melee, rockets, FPV launches and mortar missions now read retained actors and
spatial membership directly. Mortar selection keeps friendly clearance, enemy
clusters and the explicit ownership order of emplacements. FPVs retain vehicle
priority, armour scores, visibility exceptions and infantry cluster checks.
Rocket reports use retained ground caches and collision geometry. Accepted
attacks update the soldier's pending action, route revision, ammunition and
cooldown; queued mortar missions update the shared squad. Rejected actions leave
the actor, queue and random stream unchanged.

The Godot fixture compares 32,768 complete actor states, target queries, squad
queues, speech, navigation cancellations, counters and random continuation. It
covers range boundaries, stale spatial cells, blocked rays, active drone
operators, missing squads, muted speech and checkpoint resumes. Twelve core tests
cover target ties, friendly clearance and rejection; numeric CI adds 2,784,443
bytes. The live soldier dispatcher and completed strikes/launches remain in Godot.

## Battle ledger

`BattleStats` retains commander and side totals, unit and hero records, attribution,
capture credit, event history and the thinned strength/supply timeline. Report
filtering preserves the current visibility rules: enemy strength, stock, spending,
unit records and support calls remain private during the battle. Tied hero scores
use the same ordering as Godot. Sampling only visits actors when a sample is due.

Rejoining merges commander totals without recounting the side. Configured names
survive checkpoints, including delayed credit under the previous peer identity.
The Godot comparison checks 8,192 ledger updates plus filtered reports and saved
state resumes. Eight core tests cover attribution, neutral sources, prisoners,
capture ties, sample thinning, rejoining, visibility and malformed checkpoints.
Numeric CI adds 2,163,840 exact bytes. The live ledger remains in Godot pending the
complete Rust dispatcher; this is not yet a verified battle conclusion.

## Infantry target acquisition

Infantry target acquisition uses the shared numeric visibility and collision world
in one call. It preserves the first seven candidates, first-wins score ties,
machine-gunner and downed-target priorities, armor/rocket rules, mounted-gun arcs,
drone override order and forced structure attacks. Flanking contacts are still
reported even when a mounted gun cannot engage them; drones retain their existing
separate reporting behavior. The 600-case reference fixture checks current poses,
smoke, changed vehicle colliders, repeated scans and restored geometry. Contact
poses and squad state are still supplied by Godot in the live adapter.

The retained actor path now builds the tick's perception snapshot directly from
Rust infantry, vehicles and terrain. It reuses occupied bucket storage across
rebuilds. The snapshot preserves concealment, quiet cover, recent wounded fire,
netted vehicles and aircraft exceptions; scanning rechecks current casualty
eligibility without refilling the original seven candidates. Stable IDs retain
the full unsigned entity range. Infantry then resolves exposed points and mount
arcs from owned actors and retains its selected and visible contacts. The result
identifies the ground contacts to report separately from drone observations.

The new fixture compares 18,432 complete infantry states, selected/visible targets,
report order and obstruction reuse against the actual Godot scan. Seven core
tests cover snapshot timing, tie order, concealment, removed contacts, mounts,
bearers, drones, forced structures, invalid input and checkpoint continuation.
Numeric CI adds 984,712 exact bytes. The full infantry decision loop and shared
squad/world dispatch remain unfinished.

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

## Complete cover search

`cover_search::find` collects structure and ground candidates, preserves Godot's
candidate tie order, checks navigation and group reachability, evaluates shelter,
penalizes occupied positions and chooses the final fighting position in one call.
The limit remains 20 reachable structure evaluations; ground candidates do not
consume that limit. Claims use the world's existing spatial membership, which can
precede a soldier's movement in the current tick. Terrain, navigation and collision
are borrowed from their retained core state; heat and deck arrays are borrowed
without copying the map. Nearby actor and structure records still come from Godot.

The native path is active by default; platforms without the module keep GDScript.
The fixture compares 4,270 searches, including equal-score candidates across the
sort threshold, burning/unbuilt cover, ground cover, group limits, occupied spots
and stale spatial membership. Six battle fixtures retain identical fingerprints
and behavior counters. Numeric CI adds 29,019 exact result bytes.

An alternating comparison measured 1,000 searches at 659–687 ms through GDScript
versus 61–65 ms through Rust, including scene packing (six samples after two warm-up
rounds, other apps running). This is roughly 10–11 times faster for this fixture,
not a whole-game FPS result.

Four headless 500-unit combat runs on a 2,048 m map used reference/native/native/
reference order, a 15-second warm-up and a 10-second observation window. Other apps
stayed running; 495 soldiers remained alive in every window. Tick milliseconds:

| Run | Median | p95 | p99 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Reference 1 | 17.897 | 27.289 | 35.188 | 36.982 |
| Native 1 | 17.728 | 25.265 | 27.676 | 31.585 |
| Native 2 | 18.018 | 26.218 | 28.546 | 38.569 |
| Reference 2 | 17.848 | 26.204 | 29.226 | 31.942 |

The median did not improve measurably in this case. Tail samples varied and do not
establish a consistent battle-wide gain. The test still spends most of its time
in soldier ticks; a cheaper cover search does not by itself meet the rendering
target. Raw local reports: `build/rust-cover-search-500-2048/`.

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
