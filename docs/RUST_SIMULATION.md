# Rust simulation migration

Status: **in progress; the game still requires Godot to simulate a battle.**
The engine-independent crate retains actors, squads, geometry, terrain, economy,
commands and the connected battlefield scheduler. Its checkpoints and exact-byte
continuation tests cover these shared systems. The standalone battlefield runner
loads production definitions and verifies its command recordings without Godot.
Commander/naval and mission scheduling, initial-map setup, the socket host and
the live Godot client transition still need integration. Existing live-game
observer recordings remain unverified; they are not the new command recordings.

## Ownership

The destination is one authoritative Rust simulation, with Godot submitting
player intent and displaying observations. Local play and multiplayer must use
the same simulation. A headless verifier must run that same code without Godot,
graphics, network access or a wall clock.

| Component | Destination | Current implementation |
| --- | --- | --- |
| Perception candidates, formation scoring, route graph | `frontline_core` | Extracted; Godot bindings call the core |
| Infantry target acquisition | `frontline_core` | Retained actors build perception snapshots, schedule scans, resolve poses, visibility, mounted-gun arcs, weapon priorities, drones and forced targets, update shared squad reports and compute separation; the live dispatcher still runs in Godot |
| Gameplay RNG, including commander streams | `frontline_core` | Seeded PCG stream matches Godot 4.7; cosmetic RNG stays in Godot |
| Grenade, smoke, rocket, bomb and shell flight | `frontline_core` | Rust retains and advances flight state and queries native geometry; the adapter supplies holders and applies impacts |
| Retained projectile actors and impacts | `frontline_core` | Connected flight resolves shared holders, guided targets and support contacts, then applies impacts, spawns, smoke, recon and sound in order; the production world dispatcher remains unfinished |
| Shared actor storage and FPV ownership | `frontline_core` | Infantry, buildings, vehicles, projectiles and drones retain identities, state and shared casualty/transport links together; drones resolve living targets and operators inside Rust. Squad integration and complete world dispatch remain unfinished |
| Squad state and shared knowledge | `frontline_core` | Orders, contact caches, plans and tactical state have retained checkpoints. Travel, defense, assaults, morale, battle drills, house clearing and ammunition sharing operate on owned actors. Remaining duties and the complete production squad dispatcher still need integration |
| Retained buildings and economy transitions | `frontline_core` | Shared captures, destruction, crews, caches, tents, production, research, capacity and recruitment are reference-tested; the production world dispatcher remains unfinished |
| Deferred damage and rubble | `frontline_core` | The live world uses checkpointed explosion deadlines and pending rubble spawns, with an engine-only fallback. Godot still applies the resulting damage and creates structures |
| Fire, smoke and burning destruction | `frontline_core` | Retained fires apply ignition, spread, scorch damage, escape routes, battle records and geometry removal together; the live game still invokes Godot's fire loop |
| Spatial bucket ownership | `frontline_core` | Infantry, vehicle, building and closed-door queries use retained actor IDs and preserve cell/registration order through checkpoints |
| Weighted grid paths and cluster pair costs | `frontline_core` | Exact Godot route tie behavior; native cluster workers return costs in deterministic order |
| Boat navigation and driving | `frontline_core` | Water-cell construction, connected bodies, shore searches, routes, currents, steering, traffic, coming about and grounding recovery operate on retained state; the live dispatcher remains in Godot |
| Ground cells, crater heights and queued cover repairs | `frontline_core` | Rust retains terrain and ordered structure geometry, and performs edits, queries and cover repairs; Godot imports biome generation and forwards navigation notifications |
| Water shapes, bridge decks and water terrain rasterization | `frontline_core` | Ordered numeric rasterization; a Rust worker also applies the joining host's ground overrides; Godot still generates the initial shapes |
| Hierarchical route assembly, repairs and danger weights | `frontline_core` | Rust owns graph slots, borders, cost tables, repair order and terrain/danger revisions |
| FPV drone flight | `frontline_core` | Connected flight resolves retained operators and targets, applies shared blast damage and removes the drone afterward; production world dispatch remains in Godot |
| Guided missiles and support aircraft | `frontline_core` | Flight, target-lock loss, bomb release, burst schedules, pending hits and random draws; Godot supplies contacts and applies events |
| Entity identities and lifecycle order | `frontline_core` | Rust allocates authoritative IDs and retains ordered live identities through spawn/despawn; Godot still owns the corresponding actor state and scene objects |
| Entity state and full actor updates | Rust | `world.gd`, `entity.gd` and entity scripts |
| Infantry route movement | `frontline_core` | Route progress, vaulting, sliding, doors and ground caches extracted and reference-tested; the per-soldier adapter remains test-only because it is slower than GDScript |
| Stationary infantry movement | `frontline_core` | Neighbor separation, terrain settling, cover alignment and watch-sector/mounted turns extracted; the adapter remains test-only pending actor ownership |
| Infantry weapon cycles | `frontline_core` | Connected normal fighting and escort updates apply movement, cover shifts, aiming, bullet effects, reloads and downtime to retained state; the production dispatcher still runs in Godot |
| Infantry health, suppression and fatigue | `frontline_core` | Retained damage updates attribution, casualty links and squad reactions together; the live world dispatcher still runs in Godot |
| Infantry combat geometry | `frontline_core` | Eyes, exposed points, hit factors and cover postures extracted with reference tests; the adapter still supplies actor state |
| Infantry aim selection and sight cache | `frontline_core` | Target, blind and area-fire aiming extracted and reference-tested; the test adapter supplies posed target points and last-known squad contacts |
| Bullet resolution | `frontline_core` | Connected fire applies penetration, injuries, vehicle loss, blast effects, suppression, sound reports and battle records in order; the complete live world dispatcher remains unfinished |
| Explosions | `frontline_core` | Connected blasts apply casualties, vehicle/structure destruction, supply reroutes, fire, terrain and delayed chain reactions in order; the complete live world dispatcher remains unfinished |
| Blast knockback and disorientation | `frontline_core` | Fling trajectories, obstacle bounces, landings, flinching and dazed movement extracted with component checkpoints; Godot still applies task cleanup and speech |
| Wounded infantry and corpse timers | `frontline_core` | Connected wounded updates apply bleeding, carrier cleanup, pistol damage and crawl routes to shared world state; corpse cleanup and captive movement preserve ground caches and squad removal |
| Grenade reflex decisions | `frontline_core` | Owned actors retain notice memory, grenade claims, rescue/breach cleanup, task changes, shelter and dives; the live decision loop and task dispatcher remain in Godot |
| Grenade task movement | `frontline_core` | Owned smother, pickup and kick duties update the shared soldier/projectile state, including holder links; completed strikes and the live dispatcher remain in Godot |
| Automatic grenade attacks | `frontline_core` | Shared squad contacts and spatial groups drive retained throw/cook actions, ammunition and cooldowns; completed throws and the live dispatcher remain in Godot |
| Incoming mortars and busy-soldier grenade notices | `frontline_core` | Shared rounds drive retained warnings, memory, suppression, ducking and dives; the live dispatcher remains in Godot |
| Drone hearing and avoidance | `frontline_core` | Owned aircraft drive retained hearing memory, warnings and dives with the same random continuation; the live dispatcher remains in Godot |
| Infantry decision loop | `frontline_core` | Owned reflex priority, scavenging, building-entry selection and claims, special attacks, supply/cover decisions and sector watching; scan/separation scheduling and the live world dispatcher remain in Godot |
| Infantry special attacks | `frontline_core` | Owned actors select melee, rocket, mortar and drone targets and retain ammunition, cooldowns, pending actions and squad fire queues; the live dispatcher and completed weapon effects remain in Godot |
| Infantry supply decisions | `frontline_core` | Scavenging, nearest-body/depot choices, search timers and refill arithmetic extracted; Godot supplies spatial candidates and applies shared-store transfers, reloads and movement |
| Infantry medical tasks | `frontline_core` | Retained rescue/healing/limp duties update shared patient claims, shelter, movement and recovery; escort movement and fire are connected to shared combat, while squad rejoining, ledger callbacks and the live dispatcher remain in Godot |
| Construction, stretchers and prisoners | `frontline_core` | Connected builders apply work, cover/collision completion, repair, battle credit, supply roads and squad completion; retained stretchers and captors update shared patient/prisoner links. The production dispatcher still runs in Godot |
| Infantry arrival tasks | `frontline_core` | Boarding ranges, tunnel arrival, corpse/depot completion and ordered-throw inventory decisions extracted; Godot still applies boarding, tunnel membership, shared ammunition transfers and throws |
| Mounted infantry | `frontline_core` | Connected approach/climbing, gun claims, queued/autonomous mortar fire, anti-tank launches and defensive smoke use retained actors and geometry; production dispatch still runs in Godot |
| Infantry action state | `frontline_core` | Retained actors complete cooked throws, shared grenade handling, melee, door kicks, rockets, mortars and drones, including vehicle warning/smoke responses; the live world dispatcher still runs in Godot |
| Infantry hidden duties and status | `frontline_core` | Retained passengers, tunnel exits, treatment completion and prisoner departures update shared actors and squads; moving posture, flags and operator turns are extracted, while live dispatch and ledger/presentation callbacks remain in Godot |
| Infantry downtime | `frontline_core` | Retained actors share conversation claims, interruptions, team cooldowns, timed speech and laughter; rendering the emitted speech remains in Godot, and live dispatch still needs migration |
| Infantry scheduling | `frontline_core` | The complete retained soldier tick connects activity, recovery, interruptions, perception, decisions, every duty and final status in gameplay order; production world dispatch still runs in Godot |
| Retained infantry state | `frontline_core` | A typed actor combines component state, stable links, pending tasks and orders in a validated checkpoint; the live world still owns its Godot soldiers |
| Retained infantry orders and tactics | `frontline_core` | Actors issue and cancel routes, reject stale path completions, apply arrivals, review shelter, choose cover and derive movement speeds and sectors; the live world still dispatches its Godot soldiers |
| Retained infantry movement and observations | `frontline_core` | Actor updates connect recovery, fatigue, movement, automatic replanning, arrivals, separation, posture and status/activity codes; shared world effects and the remaining tick dispatch are still being migrated |
| Retained infantry squad orders | `frontline_core` | Move, halt, follow, attack, retreat, throw, stop and return-to-hold orders mutate the actor and return route/claim effects; player ownership checks and squad/world dispatch remain in Godot |
| Retained infantry actions and casualties | `frontline_core` | Actor state connects pending actions, interrupted updates, dives, blast recovery, damage, down/death/revive transitions and hidden/corpse state; shared combat, squad and world effects still need the complete Rust world |
| Complete fighting-position search | `frontline_core` | Candidate enumeration, reachability, protection, occupancy and final scoring run in one call; Godot supplies nearby structure and soldier records |
| House-entry task phases | `frontline_core` | Connected approach movement and fire, stack/door/grenade/entry transitions, deadlines, cooking, room targets and buddy orders update shared state; the production dispatcher still runs in Godot |
| House occupancy and breach selection | `frontline_core` | Floor containment, ordered openings, nearest walkable stack positions and competing squadmates extracted; Godot still supplies spatial candidates, squad contacts and decision timers |
| Injury behavior and special tasks | Rust | `soldier.gd`, `soldier_brain.gd`, `combat.gd` |
| Squad decisions and tactics | `frontline_core` | Complete retained squad updates connect upkeep, morale, plans, orders and support duties; production world dispatch remains in Godot |
| Commander and naval decisions | Rust | Commander and naval scripts still require migration |
| Vehicles and crews | `frontline_core` | Retained state, orders, repairs, boarding, ground/boat driving, flight, target acquisition, crew decisions and weapon operations are reference-tested; the live dispatcher and shared combat/economy effects still run in Godot |
| Battlefield box raycasts | `frontline_core` | Spatial grid with deterministic hit ties; Godot supplies geometry updates |
| Smoke volumes and geometric visibility | `frontline_core` | Rust checks exposed points against collision and smoke, retaining reusable obstruction proofs; Godot supplies target posture and scene changes |
| Route refinement, smoothing, corridor reuse and path requests | `frontline_core` | Native planner retains corridor history and request order; Godot supplies unit positions and delivers completed orders |
| Cover anchors and fighting-position selection | Rust | Rust generates anchors and evaluates protection/firing lanes; candidate search, claims and soldier state remain in cover/combat scripts |
| Supply, construction, upgrades, prisoners, victory | `frontline_core` | The combined rules tick connects support, fog, reserves, prisoners, victory, danger maps and logistics in their original order; the complete world loop remains unfinished |
| Team fog and danger maps | `frontline_core` | Retained observers, camouflage, recon photographs, remembered contacts and both route danger maps match Godot through exact checkpoint resumes |
| Support admission and delayed salvos | `frontline_core` | Retained payments, cooldowns, aircraft creation and delayed rounds match every support definition; complete world dispatch remains unfinished |
| Battle ledger and report privacy | `frontline_core` | Retained credit, casualties, captures, commander rejoins, unit/hero history, timeline and team-filtered reports are reference-tested; the live game still updates its Godot ledger |
| Missions, scripted events, initial map generation | Rust or immutable versioned input data | Map generators and mission director |
| Models, animation, smoothing, particles, camera, minimap | Godot | Existing presentation code |
| Input, selection and order previews | Godot | Existing UI; server validates all commands |
| Observation recordings | Godot viewer | Existing Format 1 recordings |
| Authoritative checkpoints, command replay, verification | Rust | Retained battlefield runner and standalone verifier implemented; commander/mission state and live socket recording remain unfinished |

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
retains the shot calculation; the connected blast/destruction operation is now
available, while the full vehicle firing loop still needs integration.

Connected vehicle orders submit ground routes, complete water routes,
search helicopter landing sites and cancel stale path completions. The reference
fixture compares 384 ordered states across 12 vehicle profiles, including AI crew
refusals and player overrides. Six core regressions and 500,836 exact transcript
bytes cover route admission and saved-state continuation.

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

Numeric version 2 pins Rust 1.94.0, glam 0.32.1 with its `libm` feature and libm
0.2.16 with `force-soft-floats`. Scalar transcendental functions use the same
implementation on every platform instead of the host system's math library.
Glam also prefers libm when Godot enables its `std` feature. Fast-math is disabled.
These choices follow [glam's math features](https://docs.rs/glam/0.32.1/glam/#optional-features)
and [libm's software-only override](https://github.com/rust-lang/compiler-builtins/blob/libm-v0.2.16/libm/Cargo.toml).

Component checkpoint headers contain a four-byte component tag, a little-endian
16-bit schema version and a 16-bit numeric version. They reject earlier numeric
rules rather than silently continuing with changed arithmetic. The separate
integer RNG stream remains unchanged.
Version 2 corrects vehicle nearest-walkable searches at the map's three-cell rim.
The prior rules could let an evading crew choose a point its own route graph
considered blocked. The connected aircraft fixture exposed the mismatch; a
boundary regression reproduces Godot's exact choice. Version 1 checkpoints fail
closed because this changes a mounted-missile evasion trajectory.

`native/core/tests/numeric_contract.rs` compares 239,196,553 committed bytes without
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
The connected bullet operation below now applies these stages directly to retained
actors and geometry. The complete live world dispatcher and verifier remain unfinished.

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
passed 180 tests at `1453d2c`. The connected infantry-decision change passes 533 core tests
in debug, plus 110 affected and numeric tests in release; its seven affected
Godot fixtures pass. The full game and cross-platform suites also run in CI.

## Actor-kind iteration

Owned actors retain ordered ID lists for soldiers, structures, vehicles,
projectiles and drones. Spawn/removal maintains them; checkpoint loading derives
them from the saved registration order. No checkpoint format changes. Projectile
and drone reactions, fire targeting, resupply, launch warnings, support services
and unit-grid rebuilds now visit only the relevant kinds. Scenery no longer adds
hash lookups to each of these scans. Two tests cover interleaved registration,
non-monotonic IDs, projectile churn, registry compaction and restored ordering.

The reproducible `actor_queries` example compares the old full-collection filter
with the ordered projectile list. Six paired runs alternate order, with other
apps running: 10,000 structures, 500 soldiers, 48 projectiles and 2,000 queries.
The full filter takes 191.662–206.134 ms; the type list takes 0.724–0.778 ms. Every
run checks the same result checksum. This measures actor lookup, not whole-battle
simulation or rendering. All 517 core tests pass in debug and release with the
existing numeric transcripts unchanged.

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
the next burst exactly where they do in Godot. The connected bullet dispatcher
below is now available; the full soldier decision loop still needs integration.

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
The connected bullet dispatcher below consumes these effects; the complete live
world loop remains unfinished.

Cover searches and reevaluation now use retained squad contacts, nearby soldiers
and borrowed building anchors. They preserve stale spatial membership until its
scheduled rebuild, squad-wide claims, destroyed or burning cover, route requests
and the exact timing of shared combat-cache refreshes. Six core tests cover these
boundaries and atomic rejection. The Godot fixture checks 27,648 complete actor
states, squad state, routes and RNG continuation; numeric CI adds 726,912 bytes.
This removes anchor-array packing from the owned operation; it is not a measured
whole-battle speedup, and the live soldier dispatcher still runs in Godot.

## Owned urgent reactions

Infantry reactions now read shared projectile handlers, nearby casualties,
collision bodies and aircraft directly. Smothering and kicking release existing
rescue/breach claims before assigning the new duty; pickup preserves its existing
cleanup behavior. A claimed grenade is unavailable to the next soldier. Busy
soldiers retain their restricted dive/duck responses. Incoming shells share
grenade memory, and muted warnings still consume their random draws.

The reference fixture checks 11,520 complete soldier states plus projectile
ownership, squad claims, navigation cancellations, speech, counters and random
continuation. It covers all reaction branches, memory eviction, contested rounds,
mount release, range/fuse boundaries, airborne drones and restored checkpoints.
Seven core tests cover contention, shelter ownership, warning order and failed
update atomicity. Numeric CI adds 3,603,381 bytes. The full soldier decision loop
and task/world dispatch still run in Godot.

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

## Retained grenade duties

`Actors.advance_infantry_grenade_task` advances approach, kicking, pickup and
smothering against the shared projectile collection. Picking up a round changes
its holder and stops its flight in the same operation as the soldier's action;
kicking schedules the existing strike rather than moving the round early. Missing
rounds, other holders, strict fuse thresholds, mounted turns and blocked approach
steps keep their current behavior. Dive initiation shares the urgent-reflex path.

Six core regressions cover shared-state updates, expired targets, checkpoint
resumes and rejected route changes without partial pickup or random consumption.
The Godot reference compares 23,040 actor states plus projectile bytes, path
cancellations, dive counters and random continuation. Numeric CI adds 860,276
exact transcript bytes. These operations still await the complete Rust world
dispatcher; they do not establish whole-battle replay verification.

## Connected infantry decisions

`Actors.think_infantry` runs the soldier's existing decision priority from retained
state: busy-duty reflexes, grenades, incoming shells, diving drones, melee,
scavenging, house entry, mortar/rocket/drone/grenade attacks, supply or cover, then
sector watching. It uses the shared squad's building-contact cache and breach
claim, live spatial membership, current actor positions and existing action
state. Personal-weapon stock still controls scavenging capacity, while the active
weapon controls reload duration, fighting range and ammunition rules. Returned speech, counters
and route requests preserve their order.

Eight core regressions cover overlapping priorities, shared claims and ammo,
cooking, checkpoint continuation and invalid-context rejection. The Godot
reference compares 32,256 actor states plus squad caches, projectile claims,
speech, counters, path requests/cancellations and random continuation, including
personal versus mounted weapon definitions. Numeric CI adds 2,174,751 exact
transcript bytes. Scan/separation scheduling, task execution, completed combat
effects and the whole-world dispatcher still need to be connected; this is not
a complete standalone server or a whole-battle verification claim.

## Shared infantry action completion

`Actors.complete_infantry_action` applies completed actions to the retained actor
collection. Throws and launches allocate match identities in order; grenade
pickup and throwback retain the round's fuse and update its holder and attribution.
Melee uses the shared casualty path and squad responses. Door kicks remove the
door leaf and warn nearby enemy squads. Rockets trigger vehicle smoke and crew
evasion before the launch event, preserving random consumption and spawn order.
Drone launches link the pilot and target to the new aircraft.

Ten core regressions cover these effects, queued cooking, stale rounds, checkpoint
resumes and rejected grenade updates. The Godot reference compares 12,288 actor
states plus squads, projectile/drone state, counters, speech, events and random
continuation. All six affected Godot fixtures pass. Numeric CI adds 4,535,997
exact transcript bytes. The complete world still needs to dispatch the returned
events, refresh door geometry and run every actor without Godot; this is not
whole-battle replay verification or an FPS result.

## Perception before decisions

`Actors.perceive_infantry` advances the retained scan clock, refreshes contacts
when due, reports ground contacts to the shared squad and computes separation.
It preserves the existing every-other-thought scan while a target exists and
immediate scans when it does not. Separation still runs on skipped scans, using
current actor positions in the tick's existing spatial buckets. Overlapping
soldiers consume the same random draws; dragged soldiers and carrying/prisoner
duties clear separation without drawing randomness.

The expanded acquisition fixture passes 18,432 complete actor-state comparisons:
half exercise acquisition directly and half exercise scheduling, shared reports
and separation, including checkpoint resumes. Five added core regressions cover
scan cadence, disappearing targets, report filtering, moved neighbors and invalid
context rejection. Four affected Godot fixtures pass. Numeric CI adds 1,565,992
exact bytes and retains the prior acquisition transcript unchanged. The live
controller and whole-world dispatch remain in Godot during migration.

## Retained travel tasks

`Actors.advance_infantry_travel` connects retreat, ordered grenades, boarding,
tunnel entry, drone operation and resupply to retained movement and shared actors.
Boarding claims seats and hides the passenger together; arriving soldiers consume
the same finite body ammunition. Tunnel entry records occupancy and the hidden
soldier's destination. Movement preserves pending-route waits, replanning, speed,
activity, door opening and enemy squad alerts. The returned ordered events retain
path requests, speech, counters and the door geometry refresh needed by the world.

Nine core regressions cover last-seat contention, boat and helicopter limits,
grenade fuses, missing drones, body stock, tunnel checkpoints and shared door
alerts. The Godot reference compares 14,336 actor states plus squads, structure
occupants, vehicle passengers, routes, speech, counters and random continuation.
Numeric CI adds 1,978,559 exact transcript bytes. Other tasks, the complete soldier
tick and the world event dispatcher still need integration; this is not a running
Rust match server or verified whole-battle replay.

## Shared infantry blast effects

`Actors.blast_infantry` uses the tick's spatial membership and current actor
positions to apply blast damage, shared casualty cleanup, squad reactions,
knockback and flinching before advancing to the next victim. This preserves
carrier/patient dependencies, ignores hidden soldiers, and reads wall materials,
trench cells and crater shelter from retained geometry and terrain.

Six core regressions cover ordered link release, damage before knockback, cover,
busy survivors, missing-source credit, checkpoint resumes and invalid geometry.
The Godot fixture compares 12,288 complete actor states plus squad state, speech,
counters and random continuation against the existing explosion loop. Health and
bleeding allow a 1e-9 difference for Godot's platform power function; Rust numeric
CI instead compares all 4,378,182 new transcript bytes exactly, with restored
actors, terrain, spatial membership, collision, squads and RNG. The connected
explosion operation below now applies vehicle/structure destruction, fire and
terrain effects. The complete live world dispatcher remains open; this is neither
whole-battle verification nor a frame-rate measurement.

## Shared structure damage and destruction

`Actors.damage_structure` retains hit attribution, door and alert thresholds,
car ignition and damage immunity. `Actors.destroy_structure` keeps wrecked FOBs
registered for repair, releases tunnel occupants and mounted gunners, schedules
cache cook-offs and rubble, and removes destroyed actors. The returned ordered
events and removed geometry let the world apply observations, ledger/rule effects,
fire heat, collision and navigation changes before continuing combat. Mount
release shares the same implementation with infantry commands.

Seven core regressions cover these transitions, shared links, credit, checkpoint
continuation and invalid damage. The Godot reference compares 6,144 soldier and
structure states over twelve structure kinds, including event order, complete
delayed-explosion parameters, rubble and RNG. Numeric CI adds 3,219,786 exact
bytes, including retained and removed actors, deferred effects and resumed random
state. The connected combat operation below consumes those effects, applying fire
heat, geometry, battle records and supply-network changes before the next hit.

## Infantry births and squad recruitment

`Actors.spawn_infantry` creates authoritative infantry directly from the match's
loadout and spawn inputs, including upgrades, special ammunition, initial
cooldowns and hold orders. Names use the existing one-integer draw before the
initial AI delay. `Squad.new` preserves the ID-based planning cadence without a
random draw; recruitment keeps member order, cached-center invalidation and
soldier links. Rejected births leave both allocation and random cursors unchanged.

Five core regressions cover these operations. The Godot comparison exercises all
sixteen current unit definitions, both upgrades, all initial life/posture states,
fixed and random names, duplicate recruitment and checkpoint resumes: 1,536
complete actor-state checks plus squad state and RNG. The numeric contract adds
760,644 exact bytes. Live spawning, squad ledger callbacks and whole-world
dispatch still run in Godot while the migration continues.

## Passenger evacuation, crew escape and wreck placement

Rust now resolves destroyed-vehicle passenger exits and injuries in stored order,
including shared casualty links, squad reactions and the difference between a
sinking boat's surrounding damage credit and a land vehicle's last attacker.
Nearby soldiers flinch after land-vehicle evacuation. Crew escape interleaves each
survival roll with that survivor's name, birth delay and injury roll before trying
the next man. Surviving crews retain their squad, refund and first speaker.
Wreck plans preserve blast age, weight, flip chances and blocked/map-edge landing
positions; their motion description remains an observation for Godot.

Seven core regressions and the Godot reference check 185 newly born crew members,
1,536 passenger/bystander states and 256 wreck plans, plus squad state and random
continuation. The reference captures the newly formed crew immediately before its
return-order callback. Numeric CI adds 2,634,965 exact bytes with restored state
between evacuation and crew births. The connected destruction operation below
now applies the ledger, sling, crew-return and wreck-creation effects together.

## Shared rescue and healing duties

Retained medical duties now read and update the same actor registry as combat.
Rescuers claim casualties immediately, choose prone shelter without applying a
combat-cover order, drag patients along retained routes and restore them when
treatment ends. Later medics observe the claim or revival without a state export
through Godot. Healing preserves its shorter treatment time and medicine upgrade;
limping soldiers request squad rejoining only after movement finishes.

Six core regressions cover competing medics, revived weapons, checkpoint resumes,
drag completion, limping and invalid input. The Godot reference compares 9,216
complete soldier states, squad state, routes, speech, properties and random
cursors across rescue, heal and limp duties. Shelter selection uses the GDScript
reference search, including ground cover, occupied positions and burning ground.
Numeric CI adds 2,316,391 exact bytes, including checkpoint continuation midway
through each sequence. These operations return ledger and rejoining effects;
the rule callbacks and the live world dispatcher remain unfinished. Escort firing
now uses the connected fighting operation described below.

## Shared stretcher pickup and delivery

Retained stretcher duties update both bearers and their casualty in actor order.
Pickup changes the partner's phase before his turn; a lost bearer triggers solo
takeover or dragging. Cancellation releases only the cancelling soldier's claim.
Delivery issues both return routes before removing the casualty from his squad
and admitting him to the tent for the existing 20- or 35-second treatment period.

Eight core regressions cover these transitions, the late-partner deadline,
restored state and invalid inputs. The Godot comparison checks 12,288 complete
soldier states after successive bearer updates, plus squad membership, routes,
speech and RNG. Numeric CI adds 2,376,159 exact bytes. These duties still await the
complete Rust world dispatcher. Hidden treatment completion has separate coverage;
the connected wounded lifecycle is described below.

## Hidden transport, tunnels and treatment completion

Retained hidden soldiers now follow their current transport, exit missing vehicles,
leave shared tunnel occupancy, finish tent treatment and depart when their prisoner
timer expires. Treatment restores health and weapons before selecting a return
base, retaining the existing penalty for wrecked FOBs, insertion-order ties and
random scatter after the revival speech draw. Prisoner departure removes shared
squad membership and actor storage without recycling an identity.

Six core regressions and 3,584 Godot actor-state comparisons cover all seven hidden
states, missing transports/shelters, base selection, deadlines and checkpoint
resumes. The reference also compares squad state, tunnel occupants, speech,
property changes, messages, movement requests and RNG. Numeric CI adds 5,317,037
exact bytes. Ledger/observation callbacks and the complete Rust
world dispatcher remain unfinished.

## Corpse cleanup and captive movement

Retained inactive infantry now resolve living carrier links, settle uncarried
bodies on cached ground and remove expired corpses from shared actors and squad
membership. Carried bodies retain their pose, and losing the last carrier still
defers cleanup until the following tick. Captives follow routes at the existing
speed with hands raised; surrendering soldiers remain stationary.

Six regressions and 1,536 Godot state comparisons cover the strict 300-second
cleanup deadline, stretcher claims, missing carriers, ground-cache expiry,
bridge/deformed ground and movement. Numeric CI adds 2,198,012 exact bytes with
checkpoint continuation. Wounded pistol/crawl behavior and the complete world
dispatcher remain unfinished.

## Shared prisoner capture and delivery

Retained captors approach, claim and escort the same prisoner state that movement
updates. Capture credits the battle record once and chooses a built, owned prison
in registration order, preserving the Rebels' tunnel preference and depot fallback.
Coalition captures start the existing intelligence clock. Captive route arrival
now applies detention and the guard's return order in that update, before another
actor runs. A removed prison is handled without dereferencing a freed scene object.

Seven core regressions cover credit, destination ties, missing destinations,
reassignment, arrival and rejected updates. The 5,120 Godot actor-state comparisons
also check squads, battle records, routes, speech, messages and random continuation.
The numeric corpus adds 4,200,640 exact bytes. Prisoner intelligence, freeing and
squad rejoining are covered below; the full world dispatcher still needs integration.

## Shared soldier downtime

The retained actor registry now advances idle behavior and conversation partners
together. Nearby candidates retain spatial query order; a new chat reserves both
soldiers and updates the team's cooldown before the next soldier acts. Ending
a chat releases the reciprocal link without clearing the partner's other state.
Due speech and laughter preserve their random draws, including suppressed solo
remarks. Moving soldiers still skip the squad danger-cache query.

Five core regressions and 4,608 Godot actor-state comparisons cover shared claims,
interruption, ordered speech, strict deadlines, squad caches and rejected clocks.
Numeric CI adds 3,326,032 exact bytes with checkpoint
continuation. The full fighting loop and live world dispatcher remain unfinished.

## Returning soldiers and squad membership

Retained rejoining selects the nearest section with the same side and commander,
using existing centroid caches, the six-member limit and registration-order ties.
If the commander disconnected, control passes to the last remaining teammate in
roster order, or the side's AI. When no section is close enough, Rust allocates its
identity, staggered planning timer and battle-record entry together. Membership,
hold position, cover reset and return routes preserve the existing thresholds.

Six regressions and 2,048 Godot actor-state comparisons cover ownership succession,
full sections, duplicate membership, new identities, strict distances and invalid
inputs, with complete squad and battle-record comparisons. Numeric CI adds 2,950,194
exact bytes with checkpoint continuation. The operation is ready for recovery and
prisoner-rule dispatch; the complete Rust world loop still needs integration.

## Prisoner custody and intelligence

Retained prisoner rules release unguarded soldiers when friends reach them, restore
their weapon and use the shared squad-rejoining operation. Otherwise, the nearest
eligible enemy claims the escort. Missions leave prisoners in place when there is
no prison within 200 metres. Losing a guard cancels the prison route; rescue is
considered on the next rules pass, matching the existing order.

Marching, held and interrogated prisoners retain their separate strict deadlines.
Rust builds intelligence from current bases, defenses, production, trucks, towns,
army strength and commander targets in the existing order. Reports consume the
same two random draws and are addressed only to the capturing side. A separate
versioned checkpoint preserves each prisoner's report history, including repeats
after the available facts are exhausted. The full rules/world dispatcher must
retain this state and forget a prisoner's history when that actor is removed.

Nine regressions and 6,144 complete Godot actor-state comparisons cover release,
competing guards, lost escorts, deadlines, report ordering, checkpoint resumes,
messages, squads, battle records and RNG continuation. Numeric CI adds 7,136,211
exact bytes. The full authoritative world dispatcher remains unfinished.

The complete local game suite passed 195 tests at `57afd00`. This prisoner update
passes all 650 core tests, 107 affected/numeric release tests and five focused
Godot fixtures. Other apps remained running throughout validation.

## Escaping fire

Retained soldiers clear burning shelter, defer cover reevaluation and route to a
walkable point seven metres away. Transported soldiers, mounted gunners, casualties
and committed grenade/stretcher/tunnel duties retain their existing restrictions.
An overlapping fire does not repeatedly overwrite the route before the cooldown;
random direction and forced warning draws remain in their original order.

Four regressions and 3,072 complete Godot soldier-state comparisons cover the
restrictions, exact deadlines, blocked ground, routes, speech and rejected input.
Numeric CI adds 3,009,688 exact bytes with checkpoint resumes. These operations
are also called by the retained fire dispatcher described below.

## Shared navigation edits

The retained navigation scene owns obstacle contributions, the path planner and
both route hierarchies. Removing a structure clears only its contributions,
including duplicate cells from overlapping parts; remaining walls and deep water
stay blocked. Bridge decks, vehicle map edges and terrain costs follow the existing
rules. Overlapping fire stamps retain their saturating counts and queue a repair
only when the route cost changes. Cluster size remains 16 or 32 metres, and repair
work keeps its fixed quota and infantry-first order.

Five core regressions cover ownership, bridges, heat counts, rejected edits and
checkpoint continuation. A Godot reference fixture compares 392 complete navigation
states and 1,536 routes, including edits while repairs are pending. Numeric CI adds
3,365,734 exact bytes. Retained fire destruction now invokes these operations;
the complete world dispatcher remains unfinished.

## Structure geometry retirement

Retained world geometry connects terrain, navigation, collision and the structure
and doorway indexes. Once an actor is removed, its navigation contributions and
spatial membership disappear immediately. Trees update surrounding ground costs;
camouflage net removal preserves overlapping nets. Other cover changes retain
their queued cell order. The collision body remains for later shots in the current
tick, matching Godot's deferred removal, then disappears at the tick boundary.
Geometry checkpoints include that pending removal list.

Five core regressions cover timing, overlapping ground effects, rejected inputs
and resumed removals. A Godot fixture compares 438 geometry states through actual
despawns, cover repairs and tick boundaries, with structure state and collision
queries. Ground cells, repair queues, navigation, collision, indexes and other
checkpoint fields compare exactly. Only stored double-precision sine/cosine cover
coefficients allow a 1e-15 Godot comparison tolerance: platform trig and pinned libm
can differ in their last bits. Rust numeric CI compares 1,474,524 exact bytes with
no tolerance. Fire invokes the combined retirement operation; the complete combat
and world dispatchers remain unfinished.

## Connected fire loop

Rust owns the complete fire update: ignition and blast flashes, wind-driven spread,
rain, grass patches, heat stamps, smoke, fuel and charring. Scorch damage updates
shared casualties, squads and battle records before issuing escape paths. Burning
destruction retires geometry immediately, so a later victim can use a newly opened
route in the same update. Collision remains until the tick boundary as above.

Five regressions and 4,608 complete Godot fire updates compare retained actors,
squads, ledger, navigation, geometry, smoke and random cursors, including checkpoint
resumes. The exact numeric corpus adds 9,628,857 bytes. All 673 debug core tests
pass. This loop is still reference-tested separately: the complete Rust world tick,
socket server and whole-battle replay verifier remain unfinished.

## Shared path completion

Retained navigation applies direct steps and queued results to soldiers and
vehicles without Godot callbacks. Replacing an order replaces its queued job;
stale direct submissions are ignored. Removed and stopped actors do not consume
the fixed job quota. Empty results during hierarchy repairs retry once per batch;
only a completed hierarchy can establish that a destination is unreachable.
Infantry cover failures and arrivals retain their existing state changes and
random draws, and return prison-arrival effects for the world to dispatch.

Five regressions cover replacements, cancellations, mixed actor queues, retries,
checkpoint continuation and rejected inputs. The connected fire fixture now also
processes hierarchy repairs and pending soldier/vehicle routes during its 4,608
Godot comparisons. Numeric CI adds 3,445,891 exact bytes for shared completions.
The complete world dispatcher remains unfinished.

## Structure collision construction

Rust constructs collision boxes from retained structure parts, with the same
part ordering, world transforms and construction gates as Godot. Movement and
opened doors replace the geometry immediately; cosmetic toss tilt does not change
cover. Removing the final door preserves an existing body's empty shape list.
Retired bodies cannot be refreshed before their deferred removal completes.

Four regressions cover construction, movement, shape order, rejected edits and
retirement resumes. A reference fixture compares 1,296 complete collision states
and 31,104 rays across 36 structure kinds, including the actual generated parts,
construction completion, moves and door removal. Numeric CI adds 432,704 exact
bytes. Retained structure creation now invokes this operation directly; shared
combat and the complete world dispatcher remain unfinished. The live game still
imports scene collision.

## Structure creation

Rust creates all 37 structure kinds from retained properties and immutable building
definition values. Parts, health, dimensions, fighting positions and ammo-cache
stock follow the existing spawn behavior. The connected spawn operation allocates
the actor and registers its navigation, collision, doors, spatial membership and
terrain repairs. Custom health and supplies survive initialization; unfinished
structures retain their original navigation and collision behavior.

Four regressions cover defaults, invalid creation, duplicate registration and
resumed creation/destruction. The Godot reference fixture checks 672 complete
world-geometry states, including 444 spawns across all kinds, default and explicit
dimensions, construction states, cover repairs and deferred removal. Numeric CI
adds 2,514,876 exact bytes for creation and destruction continuations. These are
component checks; the whole world dispatcher, automatic spawn effects and battle
replay verifier remain unfinished.

## Blast-tossed structures

Retained cars and crates now resolve blast strength, landing admission, tilt and
spin without scene nodes. An accepted throw immediately removes the old navigation
and cover, registers the new geometry and moves the actor. The returned origin,
velocity and spin let Godot animate the visual flight without controlling shelter.
Weak throws and blocked/out-of-map landings preserve the original draw order,
including the direction draw for an explosion directly underneath the object.

Four regressions cover collision/navigation movement, rejected throws, random
continuation and checkpoint resumes. The Godot reference fixture compares 1,024
attempts (674 accepted), 1,280 complete geometry states and 24,576 ray hit identities.
Godot's platform sine/cosine and portable libm can differ by one float step.
Linux diagnostics measured differences of 5.96e-8 in composed rotation coefficients
and one float step (4.77e-7) in offset box centers near 5 m; cancellation can make
this several steps near zero. Reference-only bases allow 2.4e-7 absolute error;
centers scale that bound by their magnitude (at least one). Identity, topology,
half-extents, actor state, random cursors and ray hit identities remain exact.
The comparison has rejection checks for larger transforms, changed IDs and sizes.
The existing double cover-coefficient tolerance is unchanged.
Rust continuation and the 11,562,980-byte numeric transcript use no tolerance.
The connected explosion operation now calls this between destruction and fire
ignition; the live game still uses the Godot toss method.

## Shared formation placement

Formation placement now reads retained terrain, navigation, structures and cover
anchors in one Rust operation. Ground candidates are prepared once per group;
anchor approaches and occupancy counts are reused across its slots. Structure
bucket order, scoring subtraction order, strict ties, map-edge clipping, wall-click
adjustment and compact/wide spacing preserve the existing placement rules.

Four regressions cover compact spacing, keeping formations on one side of a wall,
cover choice, invalid inputs and resumed geometry. The Godot reference compares
1,536 formations with 8,064 positions and their complete cover metadata, using
unfinished structures, queued terrain repairs, map edges and both formation widths.
The comparison is exact. Numeric CI adds 126,976 exact placement bytes. Shared
squad movement and crew return now consume these retained placements directly.

## Shared squad movement and crew return

Squad move orders now regroup retained soldiers, assign formation slots, choose
travel or bounding overwatch, and apply each member's command before moving on to
the next. Commands release rescue/breach claims and submit or replace routes in
the same order as Godot. Busy followers retain their original order gates; a
breacher already entering a house finishes that commitment. Travel slows the
leader when the group falls behind and sends followers to their final cover on
arrival. Bounds preserve fire-team ordering, urban leg lengths, threat direction,
recon-fire safety checks and random draws, including speech suppressed by cooldown.

Crew return shares this movement operation. The same cooldown, order ownership,
nearest-FOB and combat gates decide when crews head home. Arrival refunds supplies
once, removes living crewmen and leaves their wounded behind for rescue. Returned
events identify speech, messages, despawns, counters and cancelled ambush plans.
The world must apply the plan cancellation before later plan updates; complete
plan, squad and world dispatch remain unfinished.

The movement reference checks 2,304 successive orders/updates against Godot,
including exact actor and squad state, route queues, speech and random cursors.
Crew return adds 1,024 Godot comparisons of orders, removal, messages, supply and
random continuation. Seven Rust regressions cover claims, committed breaches,
leader loss, travel slowdown, friendly-fire avoidance, manual orders, combat gates,
one-time refunds and an uninterrupted-versus-restored continuation. Numeric CI
adds 4,958,595 movement bytes and 7,223,290 crew-return bytes. Navigation components
record changed bytes separately to avoid repeating unchanged map grids; comparison
remains exact and uses no hashes or floating-point tolerance.
The live game still uses the Godot squad dispatcher; these comparisons establish
compatibility of the retained operation, not a whole-battle performance result.

## Connected vehicle destruction

Retained vehicle damage now records the hit, updates health and alerts, then
finishes destruction before another world hit can run. A carrier's sling cargo
falls and takes damage recursively before its own passengers evacuate. Each
passenger casualty updates battle credit before the next passenger is injured;
sinking boats preserve the surrounding credit scope and produce no land wreck.
Supply losses update the source town or destination FOB's truck and replacement
timer. Wreck-placement draws precede crew survival, and surviving crews receive
their return order or immediate FOB refund before the burning wreck is created.
The wreck registers collision, navigation, spatial cells and cover, while the old
vehicle's collision remains until the tick boundary. Dropped sling cargo updates
its collision to the landing position before applying impact damage. Messages retain the lost
vehicle's name, team and position after its actor is removed.

Seven regressions check damage credit, duplicate hits, refunds, supply losses,
sinking, recursive sling destruction, invalid input and complete checkpoint
continuation. The Godot reference compares 192 destruction cases and 384 world
geometry states across the vehicle roster, including passenger and crew states,
route queues, squads, the battle ledger, burning lists and random cursors.
The numeric transcript adds 2,522,922 exact bytes for connected destruction and
resumed nonfatal/fatal hits. The live dispatcher and whole-battle replay verifier
are still unfinished; this is a connected operation in the engine-independent
world, not a claim that the standalone server is ready.

## Connected supply routes

Supply-network state retains depot identities, town order, FOB completion order,
current routes and previously painted roads. Rebuilding chooses parent FOBs in
completion order and clears neutral obstacles before calculating the next route.
Towns choose a working FOB, while wrecked FOBs retain their place in the supply
chain. Changed roads update terrain and navigation immediately; old road cells
remain as in the existing game. Removed obstacles stop blocking navigation now
and leave collision at the tick boundary.

Five regressions cover chain order, obstacle retirement, wrecked bases, missing
depots, route cycles, corrupt checkpoints and resumed rebuilds. A Godot reference
checks 256 rebuilds and 512 complete geometry states, exact structure/route state,
ordered removals and unchanged random cursors. An exact numeric transcript checks
both sides of collision retirement and repeated checkpoint continuations. The
connected combat operation invokes this when a FOB is wrecked; live rule dispatch,
the standalone socket server and whole-battle verification remain unfinished.

## Connected explosions and delayed destruction

An explosion now runs against retained Rust world state from first casualty to
final crater. Heavy impacts reach squad reports before casualties. Infantry use
the tick's spatial membership, while vehicles keep their registration order.
Each injury updates battle credit before the next victim; each vehicle finishes
passenger evacuation, crew return and wreck registration before the next hit.
New wrecks can therefore be damaged by the structure phase of the same explosion.

Structure damage opens doors, releases occupants and gunners, updates cover and
navigation, registers car ignition and rebuilds supply routes immediately when a
FOB is wrecked. Drone losses, thrown cover, fires and craters follow in their
original order. A destroyed wall retains its final collision state until tick
end, including a door blown open by that fatal hit. Missing throwers use the
caller's battle credit without leaking it into later damage. Due cache explosions
finish before queued rubble is created; newly scheduled explosions wait for the
next simulation step.

Eight regressions check connected destruction, ledger scope, supply changes,
door collision, delayed effects, invalid input and exact restored continuation.
The Godot comparison covers 64 mixed battles with two blasts and a delayed-effects
pass each, checking 384 geometry states plus actors, squads, routes, fires, battle
records, event deadlines, entity allocation and random cursors. It reuses the
existing blast-health and platform-geometry reference allowances; Rust numeric
checks remain exact. The new transcript adds 3,344,054 bytes across resumed blasts
and chain reactions. Remaining actor/AI updates, the
standalone server and whole-battle replay verification are still unfinished.

## Connected bullet fire

`Context::fire_bullet` runs the existing bullet stages against shared actors,
collision and visibility. Penetration damages cover before a stray victim is
considered. Vehicle damage finishes passenger injuries, crew escape and wreck
creation before a heavy hull's ricochet draw. Heavy-armour AP damage retains the
original absence of shooter credit. Target injury precedes the explosive round's
placement, which uses the victim's updated body center. Explosions finish before
near-miss suppression and enemy squads' sound reports.

`Gunfire` retains each shooter's reveal deadline in a bounded, versioned checkpoint.
Restoring the world therefore does not reveal gunfire earlier than uninterrupted
play. Shot and ricochet events carry rendering data; scene objects and animation
do not participate in hit decisions.

Five regressions cover injury/shot ordering, reveal deadlines, destruction before
ricochet, live/dead drone hits, rejected inputs and exact checkpoint continuation. The Godot comparison
fires 768 mixed rounds and checks 1,536 geometry states, actor and squad state,
effect endpoints/materials, supply routes, battle records, deferred effects and
random cursors. Fractional damage totals allow 1e-10 error in this reference only:
Godot's power function produced a measured 7.11e-15 difference after an HE round.
Counts, identity and outcomes remain exact, and rejection checks cover changed
damage and shot totals. Rust's 4,729,493-byte connected-fire transcript is compared
exactly in debug/release and across the supported CI platforms.

The reference binding remains an integration test adapter. Production actor ticks,
the complete Rust server, socket transport and whole-battle verification remain
unfinished; this component does not establish 60 FPS.

## Connected wounded infantry

Wounded updates now run against the retained world. Bleeding precedes stale carrier
cleanup, preserving the existing rescue and medicine factors. Bleedout records
credit before death, releases shared claims and cancels routes. Cries precede
pistol fire, and a carried patient does neither pistol aiming nor crawling.
Pistol hits use connected bullet resolution before the soldier settles on the
ground or seeks cover. Crawl arrivals and replans update shared navigation before
another actor runs. Immediate facing retains Godot's 32-bit angle assignment.

Five core regressions cover bleedout credit, carried patients, invalid input and
exact checkpoint continuation through firing. The Godot comparison checks 1,184
world geometry states across 64 cases, plus full actors, squads, effects, routes,
battle records and random cursors. The 5,701,213-byte numeric transcript includes
resumed bleeding, stale links, pistol fire and crawl orders. The full production
infantry dispatcher and standalone server still need integration.

## Connected normal fighting and escort fire

The retained fighting operation completes movement, door and route changes before
stationary settling and the weapon cycle. A cover shift submits its route before
stance and sight checks. A shot applies all bullet damage and speech before burst
recovery; an automatic reload reads the current weapon after damage can release a
mount. Activity selection and downtime follow the shot. Escorts retain their
threat-facing movement, fire without the normal movement penalty and abandon an
invalid rescue before any weapon or random update.

Six regressions cover ammunition, damage, cadence, reloads, escort cancellation,
invalid profiles and exact restored continuation. The Godot reference checks
1,536 geometry states plus actors, squads, shots, speech, chat deadlines, routes,
battle records and random cursors. Coverage requires actual fire, reloads, escorts,
idle behavior and shifts along cover. The numeric transcript adds 2,137,679 exact
bytes through resumed fights. Existing stationary and movement implementations are
reused. Remaining duties, production tick dispatch, the socket server and complete
battle verification are still unfinished.

## Connected mounted weapons

Gun crews now advance against retained actors, geometry and navigation. Tower
climbing finishes before the elevated firing position is set. Machine-gun claims
set the mounted weapon before the shared weapon cycle; traverse retains Godot's
half-turn endpoint convention. Mortars consume ordered fire missions or select
an autonomous target, finish laying the weapon and create attributed rounds.
Anti-tank crews scan exposed targets and finish traversing before firing. A
vehicle's smoke and evasion response completes before the launch effect.

The mounted operation reuses shared movement, bullet resolution and mortar launch
calculations. Six core regressions cover climbing, claims, ordered fire, both
anti-tank rounds, defensive smoke, rejected input and resumed state. A separate
angle regression covers the half-turn rounding case. The numeric transcript adds
5,842,831 exact bytes. The Godot comparison checks 1,448 geometry states across
64 mixed worlds, plus complete actor/squad state, effects, routes, battle records
and random cursors. It requires actual shots, climbing, mortar rounds, anti-tank
launches and defensive smoke. The production soldier dispatcher, standalone socket server
and whole-match replay verification remain unfinished.

## Connected action completion

Pending infantry actions now apply their world effects to retained state. Door
kicks remove closed-door query entries and update cover and collision before the
next actor. Melee injuries record damage and casualty credit, cancel interrupted
routes and emit hit feedback. Cooked throws retain their forced call and delay;
rocket smoke responses submit evasive vehicle routes before the launch effect.

Five core regressions cover door raycasts, melee credit, cooking, rejected input
and exact restored continuation. A Godot comparison exercises all twelve action
forms across 64 worlds and checks 384 geometry states, plus actors, squads,
ordnance effects, routes, battle records and random cursors. It reuses the
previously verified action implementation and numeric contract. Production tick
dispatch, the standalone socket server and whole-match verifier remain unfinished.

## Complete retained infantry tick

`Context.advance_infantry` runs recovery and activity clocks before interruptions,
then perception, decisions and the selected duty, and finally posture and status.
It connects every soldier task to retained actors, shared combat, navigation,
squads and battle records. Treatment and tent discharge update revival credit;
limping soldiers rejoin squads and submit their new route. Carrying, boarding,
tunnels and prisoner arrivals preserve their shared ownership changes. Definition
lookups supply unit and weapon data without calling Godot.

Seven reference cases run the complete tick against `Soldier.sim` across 448
world setups, including fighting, house entry, construction, mounted weapons,
actions, travel, carrying and custody. They compare shared actor/squad state,
geometry, routes, effects, battle records and random cursors.
Six core regressions cover fight continuation, interruption ordering, medical
recovery, tent ammunition, every lifecycle/task dispatch and invalid time steps.
The combined numeric transcript adds 11,539,973 exact bytes and compares uninterrupted
updates against restored state, including actors, squads, geometry, pending paths,
battle records, delayed effects, smoke, fire, gunfire, supply and random cursors.

This completes the retained soldier dispatcher, not the production world loop.
Vehicles, remaining shared systems, the standalone socket server and whole-match
replay verification still require integration. The comparison adapter rebuilds
perception for each call; the production world must share one snapshot per tick.

## Connected vehicle combat

Vehicle firing now resolves shared actors, cannon blasts, machine-gun hits and
missile countermeasures inside Rust. Smoke and crew evasion precede the launch
effect; damage completes before weapon recovery consumes its random draw, even
when an explosive round destroys its firing vehicle. Artillery launches retain
attribution and advance the salvo afterward. Support vehicles update recipients,
revival credit and speech together.

Three Godot reference cases compare the vehicle roster, artillery and service
updates, including actor/squad state, geometry, effects, battle records and random
cursors. Nine core regressions cover shared damage, smoke ordering, air defense,
wounded-target rejection, artillery, medical credit and invalid profiles. A
5,675,823-byte numeric transcript compares restored and uninterrupted world state.
The full vehicle dispatcher, standalone socket server and whole-match replay
verification remain unfinished.

## Connected vehicle movement

Vehicle scans now update opposing squad contacts directly. Crew decisions use
shared threats, infantry support and supply bases; withdrawal and evasion submit
their routes before the next vehicle acts. Drivers query retained terrain and
traffic, refresh their collision and shove nearby soldiers in the original order.
Smashing removes obstacle navigation immediately while retaining its collision
until tick end. Unarmoured light vehicles take their original collision damage,
including the complete destruction and crew sequence when it is fatal.

Four Godot reference cases compare scans, crew decisions, driving and obstacle
destruction across the roster. Driving uses the existing component comparison
tolerances; other actor state and random cursors compare exactly. Five core
regressions cover shared contacts, withdrawal routes, shoving, collision retirement
and invalid time steps. A 1,396,679-byte exact numeric transcript checks restored
and uninterrupted shared state. The complete vehicle and world dispatchers,
standalone socket server and whole-match replay verifier remain unfinished.

## Connected projectile and FPV updates

Projectile updates resolve grenade holders, smothering soldiers, guided targets,
source exclusion bodies and gunship contacts from retained actors. Support aircraft
retain the original infantry query order and double vehicle targeting weight.
Flight emits its ordered actions before shared blast damage, spawns, smoke changes,
reconnaissance marks and removal are applied. Grenade smothering damages the covering
soldier before the reduced blast; bombs and gunship shells retain their original
attribution. FPV updates resolve operator loss and living targets, mark the drone
dead before applying its blast, then remove it.

Recon marks are four float32 values (x, z, radius, expiration) in per-team insertion
order, matching the existing game. Smoke volumes enter and leave the shared
visibility state with their projectile. Native support snapshots preserve pending
hits and firing schedules instead of resetting the aircraft between comparisons.

Six core regressions cover casualties, smothering, missing holders, smoke expiry,
missile lock loss, bomb attribution, recon, FPV impacts, invalid time steps and
checkpoint continuation. A 1,653,080-byte numeric transcript records complete
shared state and recon marks through resumed updates. Two Godot reference cases
compare projectile/support and drone updates against the same mixed battlefield.
The production dispatcher, standalone server and whole-match verifier remain
unfinished.

## Retained defense and deliberate attacks

Squad defense orders preserve distant travel before spreading into cover, direct
defense, member leashes and ambush readiness. Assault bounds retain the original
member order, alternating teams, pinning/casualty gates, contact reports and
covering fire. A planned assault requires its plan; the unplanned-bound dispatcher
rejects that case instead of silently discarding the tactic.

`attack_plan.rs` creates either fire teams or whole-squad elements, chooses the
support position and covered flank from retained terrain, visibility and contacts,
and runs planning, movement, fixing fire, assault and fallback. Smoke, grenade
rushes, fire shifting, reinforcement, support requests and defensive consolidation
apply to the shared soldiers and route queues. The planning halt cancels movement
without clearing duties. Plan checkpoints retain timers, membership, speech gates,
smoke use and rush progress; they reject incompatible or malformed state.

Eight core checks cover defense, small-squad bounds, planning halts, support fire,
reinforcement, smoke, grenades, fallback, checkpoint continuation and invalid input.
Godot reference fixtures compare 2,304 defense/bound states and 2,560 deliberate
attack states: members, squads, complete plan checkpoints, speech, support messages,
random cursors and route completions. A 6,540,815-byte numeric transcript records
every changed checkpoint byte while omitting repeated unchanged blocks.
The complete world dispatcher, standalone socket server and whole-match verifier
remain unfinished.


## Connected transport and ground-vehicle updates

Passenger exits now update shared soldiers, clear transport links, replace a lost
leader and issue the section's defensive or deliberate-attack orders in Rust.
The same path handles exits onto shore. Newly created attack plans enter the
retained plan registry with monotonic IDs; no plan ID is consumed for defense.

`advance_ground_vehicle` connects weapon clocks, knockback, shared scans and crew
decisions, driving, turret stabilization, dismounts, artillery, aiming, firing,
service, obstacle collisions and flags. Slung cargo waits without advancing its
weapon clocks and falls through shared damage if its carrier link is orphaned.
Weapon profiles are validated before movement changes. A vehicle destroyed by its
own blast stops before support work; the Godot reference now has the same guard.

The ground dispatcher and dismount routines have checkpoint-continuation tests;
exact numeric transcripts include shared actors, geometry, squads, plans, damage,
supply, effects and random state. These are component integration checks. Aircraft,
boats, the full world scheduler, standalone socket server and whole-match replay
verification remain in progress.

Validation for this integration: all 826 debug core tests pass, as do 112 release
numeric-contract cases and seven focused release tests. Godot passes the complete
ground-vehicle roster comparison, 2,560 attack states including dismounts, and six
connected weapons, artillery, service, destruction and ordnance regressions.
The new exact transport and vehicle transcripts are 4,370,847 and 360,796 bytes.

## Connected aircraft updates

`advance_aircraft` connects the complete UAV, gunship, troop-lift and supply-flight
updates to shared actors. Pilots scan and fire in the original order; each rocket's
warning, smoke and evasive orders complete before the next rocket consumes scatter
randomness. Lift aircraft move their cargo, find landing sites, hook or release
loads and restore dismounting squads' orders. Supply flights update the destination
and income once. Aircraft lost to their own fire stop before further duties.

The reference comparison exposed a shared navigation error at the map edge:
nearest-walkable recovery accepted the outer three cells even though the vehicle
route graph excludes them. That lookup now matches Godot. Numeric contract 2 makes
the changed route rule explicit and rejects contract 1 checkpoints; the prior
corpus remains in Git history. The RNG stream itself has not changed.

Six aircraft regressions cover landings, sling transitions, deliveries, rocket
warnings, UAV flight and invalid input, including checkpoint continuation. All 834
debug core tests pass, including 113 numeric-contract cases. The 132 release checks
pass: 113 exact transcripts and 19 aircraft, navigation and structure regressions.
Godot passes the complete aircraft roster comparison, ground vehicles, mounted
combat, deliberate attacks/transport exits and geometry retirement. Import,
formatting, changelog and presentation audits pass. The combined CI job now allows
40 minutes: its prior run reached 20 minutes during the growing game suite, after
the four-platform numeric jobs and scenario/mission smoke checks passed.
Boats, the full world scheduler, standalone socket server and whole-match
verification remain unfinished.

## Connected boats and supply trucks

Boat updates now connect their retained navigation, currents, shared scans,
movement, shore unloading and combat in the original order. They retain recovery
attempts and emit the existing grounding/rejoin notices. Ground vehicles and boats
share the same registration-ordered traffic snapshot construction.

Supply trucks now resolve roadblocks from retained actors, deliver cargo and battle
credit once, update income and source status, reverse their route and retire on
return. Homecoming restores the matching source's replacement timer; an enemy-held
destination receives no supply. A blocked road produces one notice until its status
changes. Collision retirement uses the same end-of-tick rule as other despawns.

Eight focused core regressions cover these connected updates, including invalid
input and checkpoint continuation. Their exact numeric transcripts add 694,070
bytes. All 844 debug core tests and 127 release checks pass, including 115 exact
numeric transcripts. Godot passes complete ground-vehicle, aircraft, boat and truck
comparisons, plus boat navigation and handling regressions. Truck cases include
enemy building/vehicle roadblocks, default cargo loads, captured or missing bases
and a town whose replacement truck has already taken over. Import, formatting,
changelog and presentation checks pass. The prior aircraft revision `214a6c6`
passed full game CI and exact debug/release checks on all four platforms.
The production world scheduler, standalone server and whole-match verifier still
remain unfinished.

## Connected squad battle drills

Squad decisions now use retained actors, contacts, plans, spatial queries and
navigation. Morale keeps cover, leadership, nearby armor, friendly squads and
supporting fire in the same order. The priority tree preserves rout/rally,
shellfire displacement, bounding withdrawal, contact reactions, resuming movement
and house clearing. House entry shares the existing infantry breach operation.
Ambush fire discipline and ammunition transfers retain their original deadlines,
speech gates and random draws. These operations run when the squad dispatcher
calls them; they now feed the complete retained squad update described below.

Seven focused core regressions cover priority, protection from shellfire, wounded
contact reports, ammunition and reloads, invalid steps, busy clearing candidates
and checkpoint continuation. All 852 debug core tests pass. The 123 release checks
include 116 exact numeric-contract cases; the new 128-update squad transcript adds
5,755,540 bytes. Its saved continuation compares actors, squads, complete geometry,
routes and randomness; persisted byte comparisons separate navigation blocks to
avoid duplicating unchanged geometry. Existing numeric transcripts are unchanged.

Godot compares 1,536 squad operation states, including full actor and squad state,
speech, messages, behavior counters, path queues and random continuation. Existing
travel, defense/assault bounds and deliberate attack comparisons also pass. Import,
formatting, changelog and presentation audits pass. Other apps stayed running.
These checks do not establish a standalone Rust match or whole-match verification.

## Connected squad care and road ambushes

Rescue, medical and engineer assignments now operate on the retained soldiers,
rescue claims, routes and repair targets. Covering smoke keeps its existing delay,
medics retain priority, and stragglers update their new squad's battle record
immediately. Surrender releases duties, paths, weapon and squad membership in the
same order. Follow-up defense and room-clear calls use the same deadlines.

Road ambushes now retain their complete plan: rally, covered gun end, assault
line, flank guard, hold-fire period, spring conditions and faction-specific
withdrawal. Enemy aircraft and wounded soldiers do not spring the ambush. Contact
on approach, losses, routing and timeouts preserve their existing cancellation
rules. Plans have validated, versioned checkpoints and reuse the shared squad
orders and smoke-screen operation.

Godot compares 896 duty states and 384 ambush states, including actors, squads,
paths, speech, messages, random continuation and duty battle records. The only
nonexact reference comparison is the cosmetic rifle-drop direction: its tolerance
is 1e-7 because Godot's platform cosine differs slightly from Rust's pinned math.
Gameplay state remains exact, and the Rust numeric transcripts compare all saved
bits exactly. The new transcripts add 3,389,982 bytes for duties and 15,276,227 for
ambushes. Seven focused duty regressions and four ambush regressions cover shared
claims, priority, transfers, abandonment, checkpoints and both withdrawal styles.
These operations now feed the complete retained squad update described below;
standalone world integration remains unfinished.

All 865 debug core tests pass at this revision. Godot also passes the existing
1,536-state battle-drill comparison after smoke-screen reuse. Import, formatting,
changelog and presentation checks pass. These checks do not establish a complete
Rust match or a rendered frame-rate improvement; other apps stayed running.
The 136 release checks also pass, including all 118 exact numeric-contract cases.

## Complete retained squad update

The Rust squad tick now connects pruning and retirement, contact expiry, leader
succession, morale, deliberate or simple ambushes, priority decisions, crew return,
stragglers, overwatch, follow-up defense, clearing calls, travel, rescue, surrender,
medical work, construction, deliberate attacks and ammunition sharing. It keeps
the existing half-second decision clock. Plan cancellation applies immediately,
and the owner removes a retired squad before advancing the next one. Wiped-out
squads clear bodies' old squad ID in both Rust and Godot.

Four focused regressions cover skipped decision ticks, invalid steps, wounded
squad survival, plan cancellation and retirement credit. Godot passes 32 mixed
scenarios comparing whole ticks, both squads, actors, plans, battle records,
messages, speech, path queues and random continuation. The numeric transcript
compares 256 uninterrupted and checkpoint-resumed updates, including removal
before another squad runs. A normal headless attack scenario reaches its 60-second
final state without script errors. The production world loop, shared rules,
commander/mission dispatch, socket server and whole-match verifier remain unfinished.

The full debug suite passed 870 tests before the final landed-aircraft correction;
all nine focused squad/ambush checks pass with that correction. Final release
validation passes 128 checks, including all 119 exact numeric-contract cases.
The complete-squad transcript adds 13,670,019 bytes. All six Godot comparisons pass:
complete squad ticks, ambush plans, duties, battle drills, defense/assault bounds
and deliberate attacks. A two-process host/client smoke test also passes; the
client received 3,864 entities. Import, formatting, changelog and presentation
checks pass. The earlier `8df79ce` revision is fully green in CI. Other apps stayed
running; this is not a rendered frame-rate measurement.

## Retained squad and vehicle creation

Vehicle creation now initializes the complete actor and collision directly from
immutable definitions. Squad recruitment allocates identities, draws each name
before that soldier's think delay, applies loadouts and upgrades, registers battle
credit and issues the rally order against retained navigation. Transport recruitment
links and hides passengers immediately. Invalid definitions reject before birth
identities, randomness or ledger entries are committed.

Godot comparisons pass 392 vehicle states across all 98 definitions and 140 squad
and transport cases, including blocked spawn positions, both teams, upgrades,
near and distant rally points, speech, path completion and shared battle records.
The related structure-creation and vehicle-destruction comparisons also pass.
Seven focused Rust regressions cover creation, collision, invalid input, upgrades,
boarding and resumed recruitment. Exact numeric transcripts add 610,380 bytes for
vehicle creation and 9,875,856 bytes for 128 squad recruitment operations.
These are production primitives for the pending building/world dispatcher; they
do not complete the standalone server or whole-match replay verifier.
All 880 debug core tests and 128 release checks pass, including all 121 exact
numeric-contract cases. Import, changelog, presentation and formatting checks pass.
Other apps stayed running; no rendered frame-rate claim is made from these tests.

## Connected building services

Medic tents now recruit bearers and assign paired or lone stretcher jobs directly
against retained soldiers. They preserve living surrendering bearers, replace
dead or enemy bearers, wait for recent wounds and respect rescue/stretcher claims.
Gun positions preserve specialist preference, distance ties, stale crew removal,
watchtower manning and approach routes. Caches preserve ammunition and special
stock refills, reload speech and the final complete set of refills before removal.
Removal updates shared cover/navigation immediately and retires collision at the
normal tick boundary. Shared duty-release and mount-position code is reused by
squads, soldier commands and gun crews.

Godot passes 1,242 building-service updates, comparing complete soldiers and
structures, random continuation, speech, messages, counters, route queues and
geometry, with checkpoint resumes. The infantry-command, squad-duty and connected
gun-crew regressions pass after the shared helper changes. Five focused Rust tests
cover recruitment, casualty priority, gun selection, cache depletion, clocks and
checkpoint continuation. Capture, production and the complete world dispatcher
remain separate completion work.
All 886 debug core tests pass. The final release run passes 146 checks, including
all 122 exact numeric-contract cases and the affected command, squad-duty and
gun-crew tests. The new 9,216,159-byte service transcript records every changed
checkpoint byte and compares uninterrupted and resumed updates. Import, changelog,
presentation and formatting checks pass; other applications stayed running.

At `6794da5`, the full game CI job and Linux x64/ARM/macOS numeric jobs passed.
Windows passed the debug suite but reached the 20-minute limit while compiling
release test binaries. The numeric job now allows 40 minutes and retains both
complete debug and release suites; current-head CI must still complete.

## Connected captures and minefields

FOBs and towns now count retained soldiers, apply capture progress, credit the
capturing commander and rebuild both sides' supply routes before the next actor.
Last-FOB captures run the existing victory guard, including the opening delay and
mission exclusion. Town stock accrues before the periodic house count, preserves
the captured dump and supplies nearby soldiers. FOBs retain last-stand slowdown,
queue cancellation and wrecked-base resupply restrictions. Minefields use shared
blast, casualty, vehicle damage, terrain and removal code.

Godot comparisons pass 611 building updates across 32 cases for each kind,
including contested and neutral territory, ruined town income, warning messages,
reload speech, supply routes, battle credit, infantry/vehicle mine triggers and
checkpoint resumes. Blast health uses the existing 1e-9 Godot/libm comparison
tolerance; Rust continuation remains exact. The related 1,242 building-service
updates also pass. Six focused Rust tests cover captures, victory, mine triggers
and shared-state resumes. The exact numeric transcript adds 3,830,430 bytes of
state changes and events, including resumed supply networks and combat effects.
Production, the full world dispatcher, socket server and whole-match verification
remain completion work. Other applications stayed running.
All 893 debug core checks pass. Release passes 134 checks, including all 123 exact
numeric-contract cases plus the capture and service regressions. Import, changelog,
presentation and diff checks pass. These are simulation correctness checks, not
a rendered frame-rate result.

## Connected production, research and command ownership

The retained production update now checks current unit capacity, advances the
queue, credits the acting commander and creates complete squads or vehicles.
Recruitment applies current research, rally orders and transport links. Aircraft
keep their home pad, UAVs receive their destination and boats use the water grid
or the existing launch-position fallback. Research changes existing soldiers,
including casualties, in the same update. Queued forces belonging to an absent
commander remain recorded for reclaim, including a vehicle's passenger squads.
Capacity counts wounded, tent and tunnel occupants while excluding bearers and
passengers already counted through their vehicle. Supply spending preserves the
nearest single affordable FOB, integer stock splitting and Godot's distance-tie
ordering; refunds preserve the penalty for a wrecked base.

The Godot comparison passes every squad, vehicle and research definition in four
cases, each with three successive updates: current and absent commanders,
human/AI succession, upgraded recruits, capacity stalls, rally paths, ships and
aircraft. It compares all actors, queues, squads, ownership records, research,
battle credit, speech, warnings, geometry, path completion and RNG continuation.
Nine focused Rust regressions cover production, research, capacity, supply,
checkpoint rejection and resumed ownership. The exact numeric transcript adds
6,598,188 bytes across 336 uninterrupted/resumed updates, including complete
actor, route, squad, boat, economy and ownership checkpoints. The full rules/world
loop, standalone socket server and whole-match verification remain unfinished.
All 903 debug core tests and 133 release checks pass, including all 124 exact
numeric-contract cases. Import, formatting, changelog, presentation and diff
checks pass. Other apps stayed running; rendered performance is not measured here.

## Retained fog and navigation danger

Rust now collects observers from soldiers, vehicles, towers, towns, drones and
support aircraft, then updates team visibility against shared actors and terrain.
Photographs preserve float32 expiry, camouflage reduces ground detection and
hidden soldiers and mines retain their owner-only visibility. Remembered contacts,
seen buildings and drone masks survive checkpoints. A 16-metre observer grid
bounds nearby checks while retaining original candidate and actor order. Both
navigation hierarchies receive the existing capped enemy danger weights.

Godot comparisons pass 48 successive states across 12 cases, including flight
boundaries, camera expiry, camouflage, hidden soldiers, mines and remembered gun
positions. They compare all changed IDs, retained actors, fog state, danger arrays
and the complete navigation checkpoint. Seven focused Rust checks include a
newborn drone's first visibility notification, exact resumes and rejection of
invalid or excessive observer grids. The 5,156,587-byte numeric transcript covers
64 uninterrupted/resumed updates. All 911 debug core checks and 132 release checks
pass, including all 125 exact numeric-contract cases. The complete
rules/world loop, socket server and whole-match verifier remain unfinished; these
correctness checks do not establish rendered frame rate. Other apps stayed running.

The complete Check workflow at `1f4382b` passed the game suite and debug/release
numeric checks on Windows, macOS, Linux x64 and Linux ARM. Later heads require
their own CI results.

## Connected supply dispatch and headquarters reserves

Rust now dispatches town lorries before FOB replacements against retained actors
and supply routes. Towns preserve load thresholds, integer stock deductions and
the distinction between waiting for stock and waiting for a route. Active trucks
block duplicate dispatch; missing trucks are replaced with the next shared entity
identity. Wrecked FOBs retain their existing replacement behavior. HQ reserves
preserve the two-minute opening delay, 75-second cooldown, six-survivor threshold
(including bearers), current research and the first connected commander's ownership.
Scenarios and missions retain their existing exclusions.

The Godot comparison passes 160 updates across 32 cases. It compares complete
actors, squads, supply state, clocks, messages, battle credit, route completion,
geometry and RNG continuation, including a checkpoint resume after every update.
Six focused Rust regressions cover dispatch order, retry clocks, destroyed trucks,
ownership, research, reserve eligibility and malformed inputs. The numeric
transcript adds 3,932,846 bytes across 144 uninterrupted/resumed updates. All 918
debug core checks and 132 release checks pass, including all 126 numeric cases.
Import, formatting, changelog, presentation and diff checks pass. The complete rules/world
loop, socket server and whole-match verifier remain unfinished. Other apps stayed
running; these are correctness checks rather than rendered performance results.

## Connected support requests and delayed salvos

Rust now admits paid support against retained supply, cooldowns and battle credit.
Aircraft begin with their existing course, payload, camera, gunset and muzzle
sockets. Quiet recon and stealth strikes retain their warning rules; observer
demonstrations remain neutral and free. Delayed artillery, rockets, mortars and
smoke preserve reverse arrival order, scatter, sound decisions and random draws.
Due rounds are extracted in one pass before reverse processing, avoiding repeated
queue shifts. Cooldowns and pending rounds are included in exact checkpoints.

Godot comparisons pass all 20 support definitions in four cases with ten updates
each (800 states), comparing admission, ordered effects/messages, supply, complete
projectile bytes, battle records, queue state and RNG continuation. Seven focused
Rust checks cover payment, eligibility, warnings, reverse arrival order, every
sortie, exact resumes and malformed requests, including rejection before payment
when battle credit would overflow. The 1,495,196-byte numeric transcript covers
720 uninterrupted/resumed updates. Related Godot prisoner and captor checks pass
after sharing the unchanged grid-reference formatter. The complete world loop,
socket server and whole-match verifier remain unfinished. Other apps stayed running.
All 926 debug core checks and 143 release checks pass, including all 127 numeric
cases and the affected prisoner-rule regressions. Import, formatting, changelog,
presentation and diff checks pass. These checks do not measure rendered frame rate.

## Combined match rules

One Rust update now advances delayed support, team fog, headquarters reserves,
prisoner rescue and interrogation, victory, route danger and supply dispatch in
the same order as the existing match rules. Cadence timers retain their existing
no-catchup behavior. A single rules checkpoint includes their clocks, retained
subsystems, income history and base-name counters. Guard assignments also emit
the original captor counter.

The Godot comparison passes 160 updates across 32 scenarios, comparing actors,
squads, projectiles, visibility, intelligence history, messages, sounds, counters,
battle credit, geometry, completed routes and random continuation after each
update and checkpoint resume. Seven focused Rust regressions pass. The exact
numeric transcript adds 3,600,135 bytes across 192 uninterrupted/resumed updates.
The full 934-test debug core suite and 135 release checks pass, including all
128 numeric cases. Formatting, changelog, presentation and diff checks pass.
The complete world loop, standalone
socket server and whole-match verifier remain unfinished; these checks do not
measure rendered performance. Other apps stayed running.

## Production admission and the building pass

Training and research requests now enforce team eligibility, building readiness,
queue limits, research prerequisites and supply payment against retained Rust
state. Private warnings preserve the existing wording and remain silent for AI
orders. Cancellation refunds the newest order to nearby supply and reverses the
original buyer's spending. Ledger limits are checked before money or queues
change, using the same check as support calls.

The combined building pass preserves registration order across territory,
production, tents, gun positions, mines and caches. Earlier births consume
capacity before later buildings check it; completed research affects subsequent
recruits; buildings destroyed by an earlier blast are skipped. Decorative and
unfinished buildings retain their clocks.

The Godot comparison passes 6,912 states across every buildable roster entry and upgrade on both
teams, with six cases and nine successive commands each. It compares complete
building state, queues, supply, warnings and battle records, including saved-state
resumes. Six focused admission checks and four building-pass regressions pass.
The exact numeric order transcript adds 415,066 bytes across 216 commands.
All 945 debug core checks and 154 release checks pass, including all 129 exact
numeric cases and the affected ledger and support regressions.
Import, formatting, changelog, presentation and diff checks pass; Godot support
and battle-record regressions also pass after sharing the ledger guard.
The complete authoritative world, socket server and whole-match verifier remain
unfinished. Other apps stayed running; rendered performance was not measured.

## Building placement against retained geometry

Rust placement validation now preserves faction eligibility, strict map margins,
rotated footprints, trench gun positions, camouflage exceptions, bridge decks,
dry dock footings and open-water approaches. Supply roads, working-FOB build
radius, minimum FOB separation and expansion from friendly towns retain their
existing rules and warning text. Rectangle overlap shares the existing vehicle
collision calculation with a placement-only inset.

The Godot comparison passes 9,216 queries across every building definition,
both factions, rotated ground obstacles, water and damaged/unbuilt bases.
Admission and warning text match exactly; trench snapping permits 1e-6 reference
error for Godot's platform math. Five focused placement tests and five affected
vehicle-movement tests pass. The 89,316-byte exact Rust transcript covers 2,304
queries repeated after restoring actors, geometry, supply routes and water.
All 951 debug core tests and 140 release checks pass, including all 130 exact
numeric-contract cases. The eight affected Godot vehicle-world comparisons
also pass, covering shared scans, crews, driving, destruction, ground vehicles,
aircraft, boats and supply trucks after sharing the overlap calculation.
Command admission, placement creation and the complete world/server integration
remain in progress. No rendered performance result is claimed.

## Command ownership and returning players

The retained commander registry now admits connections, selects commandable units
in request order, deduplicates selections and transfers only AI attribution when
a human gives an order. Allied humans keep their existing shared control; an AI,
observer, enemy or unknown connection cannot use another commander's authority.
Departures transfer all owned forces to the last connected teammate or the side's
AI. Authenticated rejoins reclaim living squads and surviving vehicles, retarget
queued reinforcements, merge battle credit and optionally stand down the temporary
AI. Its extra automatic supply trucks stay automatic. Session authentication must
establish the old identity before this operation is admitted to the command log.

All 224 Godot comparison states pass across both sides, surviving and incapacitated
squads, human heirs, AI handovers, repeated rejoins and observers. The full actor,
squad, queue, commander registry and battle ledger match after every operation.
Eight focused regressions also check rejection before mutation on credit overflow.
The 1,435,016-byte exact numeric transcript covers 120 transitions, replaying each
after checkpoint restoration. All 139 relevant debug and release checks pass, including all
131 numeric cases. This is retained command state; the complete socket server and
authoritative world still need integration.

## Explicit squad orders

Attack, stop, construction, boarding, tunnel entry, bunker garrisoning, mounted-gun
assignment, mortar missions and grenade orders now operate on retained actors and
the shared route planner. Construction reuses the same assignment as autonomous
engineers. Orders preserve rescue-claim release, committed breach behavior,
specialist gunner preferences, available seats, ammo checks and speech RNG draws.

All 768 Godot comparison states pass across both sides and eight structure kinds.
Soldiers, squads, building gunners, path queues, speech, counters and random state
match, including route delivery and checkpoint restoration. The related squad
movement and engineer-duty Godot comparisons also pass. Seven focused Rust
regressions cover these transitions and invalid input without mutation. The exact
43,054,826-byte transcript checks 384 command continuations. Its component deltas
retain unchanged byte ranges so variable queue lengths do not duplicate map data.
All 153 relevant release checks pass, including 132 numeric cases and the manual
orders, movement and duty suites. Import, formatting, changelog and presentation
checks pass. Other apps stayed running; rendering performance was not measured.
This completes these squad methods; the complete server command dispatcher, world
and independent battle verifier remain in progress.

## Building creation and engineer assignment

Construction now validates authority and placement, charges supply, records battle
credit, creates the unfinished building and assigns commandable engineers against
retained Rust state. New FOB names advance only on successful placement. Failed
placement cannot consume supply; continued wall segments retain the first segment's
builder order. Explicit and automatic engineer selections share squad order handling.

All 384 Godot comparison states pass across all 24 building definitions, both teams,
allied human and AI ownership, repeat placements, map edges, dock approaches and
trench mounts. Actors, squads, route queues, supply, warnings, speech, battle records,
base names and random continuation match. Seven focused Rust regressions cover
admission, assignment and rejecting credit overflow before payment. The exact
52,879,864-byte numeric transcript checks 60 continuations after restoring state.
This operation is ready for the full server dispatcher; the standalone world,
transport and independent whole-battle verifier still need integration.

## Individual soldier commands

Individual move, attack, throw, stop, retreat and man-gun orders now update retained
soldiers and shared routes. They preserve unavailable soldiers' duties, friendly
target rejection, individual cover and leash, current weapon range, empty-ammo
speech, rescue-claim release and mounted-gun ownership. Gun assignment shares the
same implementation with squad entry orders.

All 432 Godot comparison states pass, as do seven focused Rust regressions.
The 25,530,373-byte exact transcript covers 256 resumed command transitions.
Related squad-order comparisons still cover all 768 states. Linux CI at the prior
revision found a platform-math difference in a rotated construction work spot;
the reference comparison now permits relative float rounding only in the work
destination, task position and delivered path. The rest of the state, identities, route topology,
random continuation and Rust numeric transcripts remain exact. All four platform
numeric jobs passed at that revision; the adjusted Godot check needs fresh CI.
The complete command dispatcher and standalone world are still in progress.
Validation also passed all 976 core debug tests through the construction change,
then 155 relevant release checks including all 134 exact numeric cases, construction,
squad orders and individual orders. Import, formatting, changelog and presentation
checks passed. Other apps stayed running; this is not a rendered FPS measurement.

## Authoritative command dispatch

`match_commands` connects all existing player-command families to retained Rust
state. Authenticated ownership determines selection and AI handoff; command packets
cannot supply a commander identity, weapon definition or price. Allied human
attribution, routed-squad refusal, formation spacing, shared assault plans,
individual orders, construction, production, fire missions, transport, support,
tunnel travel and message audiences follow the existing command path. Regrouping
cancels retained ambush plans before another tick.

`match_command_codec` encodes the same typed intent for local and remote sockets
and replay logs. Decoding rejects incompatible versions, unknown command tags,
invalid flags, nonfinite values, excessive lengths, truncation and trailing data.
Selection order and duplicate IDs survive decoding; authoritative selection
deduplicates them while preserving order. The host will attach authenticated
identity and admitted tick/sequence outside this payload.

Sixteen dispatcher regressions and four packet checks pass, including all 28
command and individual-order forms. Mixed-command continuation covers 112
transitions with 18,756,930 exact transcript bytes, including restored rules,
ownership, actors, squads, paths, attack/ambush plans and random state. All 1,012
core debug tests pass at this revision. The transport, live runtime and independent
whole-match verifier still require integration; these checks are not a claim of
whole-battle verification or 60 FPS.

## Retained battlefield scheduler

`match_state` owns the connected battlefield, rules, ownership, water, plans,
random stream, fire, gunfire and cadence clocks in one versioned checkpoint.
Restore rejects incompatible formats, malformed blocks, inconsistent map sizes
and reused group identities. `execute` routes decoded commands into this state.

`match_tick` advances fixed 1/60-second battlefield phases with fixed terrain,
hierarchy and path budgets. It preserves registration order, skips actors removed
by earlier updates, and snapshots vehicles, projectiles and drones together before
vehicle updates. Infantry throws can fly that tick; rounds launched by vehicles
wait until the following tick. New recruits wait for the next infantry pass,
while vehicles created during production update immediately. Research affects
later recruitment, services, crews and weapons. Queued prisoner arrivals apply
custody and guard-release effects before infantry updates. Deferred blasts and
collision retirement form the final phase, after the pending commander/mission pass.

Active buildings and combatants have derived registration-order indices. Scenery
does not participate in either scan, and restoring these indices does not change
actor checkpoint bytes or tie order. Tests cover spawn, removal and restoration.

Seven scheduler regressions cover these phase boundaries, encoded player movement,
clock exhaustion and a mixed battlefield resumed through 180 ticks. Three match
checkpoint checks cover connected commands, continuation and malformed saves.
The numeric contract also records 128 connected ticks across four seeds, restoring
all match state and rebuilding perception between comparison ticks.
The full core debug suite passes 1,025 tests, including all 137 exact numeric
cases. The connected-tick transcript contains 8,331,996 bytes; formatting,
changelog and presentation checks also pass. All 161 relevant release-mode checks pass.

This is the connected battlefield scheduler, not a standalone running match yet.
Versioned production content, commanders, missions, the socket host, Godot's live
client transition and independent whole-match replay verification remain required.
No rendered performance result is implied by these core tests.

## Current-main terrain integration

The alpine terrain merge preserves three movement classes, ground-relative actors,
water depth checks and ridge obstruction. Elevated maps still use the existing
Godot movement, collision and flight paths where the native ports do not yet
represent those rules. Elevated client joins retain the geology-aware loading
worker. Those compatibility paths must be removed as the corresponding Rust
heightfield and traversal support lands; full standalone simulation is not complete.

The merged-map full Godot run found movement/geometry mismatches in connected
engineer and fire comparisons, and old navigation fixture assumptions on water
maps. The terrain-aware traversal work below fixes those comparisons; the broader
batch still requires a passing rerun. Flat flight fixtures initialize their terrain;
all five actor, drone, guided-missile, projectile and support-flight checks pass.

Rust now retains immutable geology alongside deformed ground. It reproduces
bilinear heights, foot and hull slopes, slope-dependent movement costs, foundation
checks, raised trench floors, ground intersections and craters relative to the
surface. Elevated terrain uses checkpoint version 3; flat version 2 bytes remain
unchanged. Restoring validates sample dimensions and values and rebuilds slope
caches. Godot's terrain queries, crater edits and ground contacts use this port,
including worker imports and the two-channel deformation texture.

Five Godot terrain suites pass, including 1,920 direct reference comparisons and
texture-byte comparisons. The core debug suite passed 1,029 checks before adding
the elevated numeric contract and additional trench/foundation regressions.
All 138 numeric release cases pass; the new terrain continuation transcript adds
7,673,897 exact bytes. Native traversal, terrain-aware combat and flight still need
integration before the compatibility paths can be removed.

## Terrain-aware routes and swept movement

The retained planner now shares exact wall footprints and cell ownership with
navigation. Infantry can enter planning padding to reach cover, while whole-step
checks reject physical walls, diagonal corner cuts, map exits and deep water.
Blocked route goals use that same clearance check. Route smoothing borrows the
live terrain and bridge decks, so it does not duplicate the heightfield.

Navigation retains separate foot, wheeled and tracked grids. Hull slopes use the
eight-metre envelope; all three hierarchies receive danger changes and share the
repair quota in round-robin order. Vehicle definitions retain their tracked flag,
and queued routes, cached corridors and restored requests keep their movement
class. Planner, navigation, infantry-motion and vehicle checkpoint schemas change
with these rules; incompatible snapshots are rejected.

Godot's native-planner gate no longer excludes water or elevated maps. The new
reference fixture compares 720 routes, smoothing probes and swept steps across
flat ground, a ramp, a ridge and bridged water, with walls, fire, removals and
checkpoint restoration. Those comparisons pass, as do the existing path and
navigation comparisons. Connected engineer checks now match through 940 states;
fire, destruction and all 9,216 building-placement comparisons pass again.

Walking and stationary infantry use swept clearance and refreshed elevated ground.
Ground vehicles and supply routes use the correct slope class and swept steps;
supply vehicles no longer bypass physical obstacles. Vehicle spawning preserves
water height for boats and settles trucks onto ground before collision registration.
Godot loads a vehicle's definition before checking its class during spawn.
Driving, birth and production comparisons pass. Dives, blast knockback, dazed
movement, escorts, prisoner guards and stretcher followers also borrow the live
terrain for swept clearance, water depth and grounding. Retained medical tasks
place carried, dragged and abandoned casualties on the actual surface. These
special-movement comparisons pass across 2,880 interruptions in addition to the
720 route/sweep comparisons. Seven existing soldier movement/care suites pass.

Recovery borrows the live water state even before navigation repairs finish.
Deep-water searches can reach shore across the map; ordinary blocked positions
retain their nine-cell search. Retreats, casualty shelters, building exits,
passenger dismounts, destroyed transports, production and supply roads use the
same search and keep tracked hulls on their own grid. Living infantry recover
when a bridge disappears, and wading cancels prone dives. Gunner and transport
exits settle onto the actual ground.

Rotorcraft guidance now anticipates elevated terrain before horizontal travel.
Takeoff, cruise, sling pickup and gunship orbits use surface-relative targets;
UAVs look ahead along their velocity and maintain a four-metre clearance.
Landing-site searches reject uneven foundations. Released cargo rests on geology,
and dropped cargo damage depends on its height above the surface.

All 913 non-transcript core checks pass. Thirteen connected Godot movement,
aircraft and transport suites pass, including 24,000 direct flight steps on flat
and elevated terrain and complete ground, boat, aircraft and truck ticks. The
21 connected caller checks and three helper suites also pass. Cannon impacts clamp to the actual terrain or bridge surface. All 139 numeric transcript checks pass exactly in debug and release; Linux and macOS results remain a CI gate.
Terrain-aware combat, production content, commanders/missions, the standalone
server and independent whole-match verifier remain unfinished. These correctness
checks do not establish rendered performance.


## Production content and standalone battlefield replay

`native/server` is independent of Godot. Its immutable content is exported from
Defs, VehicleRoster, VehicleMotion and the baked weapon sockets. The committed
`native/content.json` retains all 98 vehicles, 16 unit types, 20 weapons,
production, construction, research and support definitions. Generate it with:

```powershell
godot --headless --path . res://tools/export_simulation_content.tscn
```

The same command with `-- --check` detects drift; the Node test suite and CI run
that check. Rust constructs production profiles from this content and advances
all vehicle classes and infantry through the retained match tick. Per-side FOB
names now reach the command dispatcher without sharing one faction's name list.

`Simulation::step` is the shared entry point for replay and the forthcoming
socket host. External inputs include authenticated player joins, departures,
reclaims and commands; identity does not come from a client command's body.
Checkpoints include the connected player registry. Loading rejects unknown
content and incompatible numeric/build versions.

The recorder stores the initial checkpoint and each tick's ordered admitted
inputs. The verifier independently reruns those ticks, recomputes the final state
and winner, and checks the transcript digest. It rejects truncation, extra bytes,
malformed inputs, out-of-order ticks, altered conclusions and incompatible
content/builds. A source/dependency fingerprint identifies the precise engine;
line-ending normalization keeps it stable across platforms. Full-map checkpoints
and state hashes are taken at recording boundaries, not periodically in the live
tick. The format bounds input, state and record sizes and permits up to 24 hours
of recorded simulation.

```powershell
cargo +1.94.0 run --locked --release --manifest-path native/Cargo.toml -p frontline_server --bin frontline-server -- verify recording.flr
```

The result identifies the initial-state hash, engine, final-state hash, tick and
winner. `concluded=false` means a verified checkpoint recording, not a completed
match. This proves continuation from the supplied initial state; an adjudicator
must match its initial-state hash to the intended match. It is not a signature
or proof that the supplied starting scenario was legitimate.

Eight standalone checks cover the full roster, real infantry updates, 180 ticks
of combat/orders/rejoin continuation, malformed admissions, tampered/truncated
recordings, recomputed victory and verification in a separate executable. All
eight cases pass in debug and release. The 16 dispatcher and seven battlefield
scheduler regressions pass in release, and the dispatcher numeric transcript is
unchanged. CI now runs standalone tests in both modes on all numeric platforms.

This is not the complete game migration. Mission scheduling,
initial-map setup, private socket observations and
Godot's visual-client transition are unfinished. Mission checkpoints are rejected
by this runner until a mission program is available. Live game recordings still
use the existing observer format; they are not accepted by this verifier.

## Terrain combat across the simulation boundary

Combat queries borrow the current terrain and bridge deck alongside the box
index. Soldiers, vehicle weapons, cover searches, blasts, bullets, guided rounds
and drones use the same query interface. Ground intersections take priority when
they precede a building or vehicle; exclusions apply to entity colliders. Only
unchanged box obstructions can be cached, so craters can reopen sight immediately.

Grenades settle relative to the surface; bombs and shells intercept hills before
their planned impact. FPV cruising looks ahead over geology, and support aircraft
use terrain-relative flight and weapon impacts. The Godot adapter retains the
native combat service on elevated maps. Terrain and deck storage are borrowed;
this does not copy the map on each ray or tick.

Local comparisons cover 3,000 mixed terrain/box rays, collision lifecycle,
visibility and 336 projectile/support cases over 91,224 steps. All 11 paired
battle scenarios preserve reference fingerprints and events. The full release
suite passes 915 core checks and eight standalone server checks. The later FPV
altitude correction passes its 16 connected Rust checks. Expanded Godot adapters
pass 144 drone cases and 84 support-aircraft cases, plus the projectile and battle
comparisons above. All 140 numeric transcripts pass exactly in debug and release
locally. All four CI platforms also pass at `74d9fdd`. The Godot comparison job
reached its timeout with two infantry dive-state mismatches; the retained dive
path now uses its controller's current surface result without overwriting it
from the movement height cache. All eight connected Godot infantry comparisons
now pass locally. The affected infantry-world numeric transcript is updated;
all 140 transcripts pass in release with the other 139 unchanged.

## Strategic commanders

The standalone runner now schedules production, construction, research, defense,
town capture, attack waves, road ambushes, support calls, naval patrols and troop
landings. Vehicle sling operations and temporary AI control after a disconnect
also run in Rust. Rejoining returns that temporary commander's force to the player.
Permanent allied AI keeps its own units.

Each side advances one strategic phase every half second, completing its cycle
in two seconds. Support targeting examines a bounded rotating candidate set.
Existing tactical squad and vehicle logic still executes the orders, including
leaving active attack plans running. Strategic clocks, roles, naval missions and
random state are checkpointed; replays recompute AI decisions from external inputs.
All 13 standalone checks pass in debug and release, including complete boarding,
transport and landing, checkpoint resumes, independent replay and disconnect/rejoin.
Two committed commander state hashes also match in both modes locally; the same
tests run on the four CI platforms.
Map landmark outposts still need the initial-map handoff.

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
