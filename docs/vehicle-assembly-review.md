# Shared vehicle assembly implementation review

This pass adds 22 construction groups (23 primary APIs) and migrates compatible equipment across the roster. Each API reaches at least three independent active builder groups; aliases and the convoy union do not establish extra adopters. The test reads the registry and checks that requirement against the active construction index.

These are construction changes, not new vehicle silhouettes. Barrels, muzzle sockets, moving parents, crane poses and cargo placement remain caller-owned. Small fasteners are mainly visible in close-ups. The shared surface/material library is reused; no additional texture assets were added.

## Extracted assemblies

Counts below are distinct root sets, not variant counts. A builder can contain conditional equipment; this is source coverage, not proof that every variant displays the part.

| Assembly | API | Builder groups | Active builders | Shape boundary |
|---|---|---:|---|---|
| Gun mantlets and cradles | `VehicleMounts.mantlet` | 22 | `VmCore._bradley`, `VmCore._btr80`, `VmCsat._angara`, `VmCsat._futura`, `VmCsat._ifrit`, `VmCsat._kamysh`, `VmCsat._sochor`, `VmCsat._tigris`, `VmCsat._varsuk`, `VmIndep._gorgon`, `VmIndep._kuma`, `VmIndep._mora`, `VmIndep._nyx`, `VmNato._bobcat`, `VmNato._cheetah`, `VmNato._hunter`, `VmNato._marshall`, `VmNato._panther`, `VmNato._rhino`, `VmNato._scorcher`, `VmNato._slammer`, `VmNato._stomper` | Box castings and cradle supports; bespoke cast/lofted mantlets retain their outlines. |
| Track drive sprockets | `VehicleWheels.sprocket` | 18 | `VmCore._abrams`, `VmCore._bradley`, `VmCore._t55`, `VmCsat._angara`, `VmCsat._futura`, `VmCsat._kamysh`, `VmCsat._sochor`, `VmCsat._tigris`, `VmCsat._varsuk`, `VmIndep._kuma`, `VmIndep._mora`, `VmIndep._nyx`, `VmNato._bobcat`, `VmNato._cheetah`, `VmNato._panther`, `VmNato._sandstorm`, `VmNato._scorcher`, `VmNato._slammer` | Single/twin rims, tooth count and exactly one X-axis wheel registration. |
| Bumpers | `VehicleMounts.bumper` | 11 | `VmCiv._mb4wd`, `VmCiv._offroad`, `VmCiv._truck`, `VmCiv._van`, `VmCore._hilux`, `VmCore._humvee`, `VmCore._truck`, `VmCsat._ifrit`, `VmIndep._zamak`, `VmNato._hemtt`, `VmNato._hunter` | Dimensioned steel/moulded box sections; bent tubular bars and body-integral noses remain authored. |
| Aircraft pitots | `VehicleAircraft.pitot` | 12 | `VmCore._blackhawk`, `VmFighter._f16`, `VmHeli._blackfoot`, `VmHeli._ghost_hawk`, `VmHeli._hellcat`, `VmHeli._huron`, `VmHeli._little_bird`, `VmHeli._mohawk`, `VmPlane._buzzard`, `VmPlane._gryphon`, `VmPlane._neophron`, `VmPlane._xian` | Exact endpoints; tapered probe and sleeve. Refuelling booms are not pitots. |
| Radar covers and arrays | `VehicleMounts.radar_array` | 5 | `VmBoat._surc`, `VmCsat._tigris`, `VmIndep._nyx`, `VmShips._gun_trawler`, `VmShips._patrol_ship` | Flat scanner/array and ellipsoid cover styles; exposed dishes remain specialised. |
| Radar covers and arrays | `VehicleMounts.radome` | 4 | `VmBoat._rhib`, `VmBoat._surc`, `VmHeli._mohawk`, `VmShips._patrol_ship` | Flat scanner/array and ellipsoid cover styles; exposed dishes remain specialised. |
| Towing jaws | `VehicleMounts.hitch` | 6 | `VmCore._abrams`, `VmCore._humvee`, `VmCore._truck`, `VmIndep._mora`, `VmIndep._nyx`, `VmIndep._zamak` | Open jaws with vertical pin; tow balls and weapon pintles remain distinct. |
| Stowage baskets | `VehicleMounts.basket` | 9 | `VmCore._abrams`, `VmCore._bradley`, `VmCsat._marid`, `VmIndep._gorgon`, `VmIndep._kuma`, `VmIndep._mora`, `VmNato._sandstorm`, `VmNato._scorcher`, `VmNato._slammer` | Open floor, rails and stanchions; keep cargo outside the helper. |
| Engine cowlings | `VehicleAircraft.cowling` | 6 | `VmCore._apache`, `VmCore._blackhawk`, `VmHeli._huron`, `VmHeli._kajman`, `VmHeli._mohawk`, `VmHeli._taru` | Authored helicopter station loops with skin, seams and fasteners; aircraft nozzle and inlet topology remains specific. |
| Light guards | `VehicleMounts.light_guard` | 30 | `VmCore._abrams`, `VmCore._bradley`, `VmCore._btr80`, `VmCore._truck`, `VmCsat._angara`, `VmCsat._futura`, `VmCsat._ifrit`, `VmCsat._kamysh`, `VmCsat._marid`, `VmCsat._sochor`, `VmCsat._tempest`, `VmCsat._tigris`, `VmCsat._varsuk`, `VmIndep._gorgon`, `VmIndep._kuma`, `VmIndep._mora`, `VmIndep._nyx`, `VmIndep._strider`, `VmIndep._zamak`, `VmNato._bobcat`, `VmNato._cheetah`, `VmNato._hunter`, `VmNato._marshall`, `VmNato._panther`, `VmNato._prowler`, `VmNato._rhino`, `VmNato._sandstorm`, `VmNato._scorcher`, `VmNato._slammer`, `VmNato._stomper` | Four family adapters retain optics and use one cage/foot builder. |
| Crane booms | `VehicleMounts.boom` | 5 | `VmCsat._tempest`, `VmIndep._zamak`, `VmNato._bobcat`, `VmNato._hemtt`, `VmNato._sandstorm` | Endpoint or box adapters retain folded pose and hydraulics; rescue winch housings remain local. |
| Dashboards | `VehicleCab.dashboard` | 3 | `VmCiv._mb4wd`, `VmCsat._qilin`, `VmNato._prowler` | Three open ground cabs; hull-shaped marine consoles retain their shell. |
| Steering wheels | `VehicleCab.steering_wheel` | 5 | `VmBoat._rhib`, `VmCiv._kart`, `VmCiv._mb4wd`, `VmCsat._qilin`, `VmNato._prowler` | Ring, spokes and hub with caller-owned column. |
| Marine screws | `VehicleMarine.propeller` | 5 | `VmBoat._motorboat`, `VmBoat._rhib`, `VmBoat._sdv`, `VmBoat._zodiac`, `VmShips._gun_trawler` | Pitched blades and hub; rudders and waterjets are separate assemblies. |
| Cargo sideboards | `VehicleCargo.sideboard` | 4 | `VmCiv._offroad`, `VmCiv._truck`, `VmCore._truck`, `VmNato._hemtt` | Flat leaves and ribs; authored stake posts and open tailgate angles remain local. |
| Sensor masts | `VehicleMounts.mast_segment` | 5 | `VmCore._abrams`, `VmCsat._varsuk`, `VmIndep._nyx`, `VmIndep._strider`, `VmNato._slammer` | Stage dimensions and collars; heads and pan parents unchanged. |
| Gun receivers | `VehicleMounts.receiver` | 14 | `VmBoat._surc`, `VmCore._hilux`, `VmCore._t55`, `VmIndep._kuma`, `VmIndep._strider`, `VmNato._bobcat`, `VmNato._hunter`, `VmNato._panther`, `VmNato._prowler`, `VmNato._rhino`, `VmNato._scorcher`, `VmNato._slammer`, `VmNato._stomper`, `VmShips._gun_trawler` | Receiver shells and feed-cover hardware; barrels, feed boxes and sockets remain local. |
| Aircraft skid runners | `VehicleAircraft.skid_runner` | 5 | `VmHeli._darter`, `VmHeli._falcon`, `VmHeli._hellcat`, `VmHeli._hexa`, `VmHeli._little_bird` | Shared runner path; drone and helicopter cross-strut layouts remain local. |
| Fuel filler caps | `VehicleFittings.filler` | 3 | `VmCiv._offroad`, `VmCore._abrams`, `VmNato._hemtt` | Explicit outward normal, gasket, neck and cap grip. |
| Wire cutters | `VehicleAircraft.wire_cutter` | 4 | `VmCore._apache`, `VmCore._blackhawk`, `VmHeli._ghost_hawk`, `VmHeli._hellcat` | Blade profile and fasteners with original attachment axes. |
| Slat armour | `VehicleMounts.slats` | 3 | `VmCsat._angara`, `VmIndep._kuma`, `VmNato._rhino` | Horizontal/vertical open panels; hull stand-offs stay authored. |
| Service hose reels | `VehicleFrames.hose_reel` | 3 | `VmCsat._tempest`, `VmIndep._zamak`, `VmNato._hemtt` | Wound pack, flanges and hub on three truck families. |
| Door and ramp leaves | `VehicleDoors.leaf` | 19 | `VmAttack._a10`, `VmAttack._wipeout`, `VmCiv._offroad`, `VmCiv._truck`, `VmCore._bradley`, `VmCore._truck`, `VmCsat._ifrit`, `VmCsat._kamysh`, `VmCsat._marid`, `VmCsat._sochor`, `VmCsat._tempest`, `VmCsat._tigris`, `VmGunship._ac130`, `VmIndep._mora`, `VmIndep._nyx`, `VmNato._hemtt`, `VmNato._sandstorm`, `VmNato._scorcher`, `VmNato._slammer` | Existing body, ramp and gear panels; preserves hardware and moving parents. |

## Existing assemblies migrated

| Catalog category | Changes and retained distinctions |
|---|---|
| Doors/ramps and aircraft wheel-bay doors | `VehicleDoors.leaf` adds fitted skin and edge treatment to existing rectangular leaves, preserving their hardware and parents; sculpted cockpit shells retain authored outlines. |
| Windows and canopies | Compatible box panes use `VehicleGlazing.rectangle`; opaque hull-backed glazing stays opaque. Curved and lofted glazing retains its shape. |
| Vents and grilles | Abrams rear, Kuma rear, Mora exhaust and Marshall engine/outlet grilles replace backing/slat duplication with `VehicleFittings.grille`. Curved ducts remain separate. |
| Closed bins and toolboxes | Compatible top-opening bins on Abrams, T-55, Strider, Kuma, Nyx, Gorgon, Sochor and patrol ship use `VehicleEquipment.storage`; upright cabinets retain their opening direction. |
| Boarding steps and ladders | Thin running boards on offroad, Ifrit, Tempest, Zamak and NATO tracked hulls use `VehicleFrames.step`. Folding stairs and their support mechanisms remain authored. |
| Handrails and handles | SURC deck runs use `VehicleFrames.railing`; Marid and Littlebird grabs use `VehicleDoors.pull`. Existing optimized ship rails stay intact. |
| Seats and benches | MB4WD bucket seats use `VehicleCab.seat`; bench seats remain benches. |
| Exhausts | Short exhausts on offroad, quad, SUV, Strider and Nyx use the shared exhaust with its new unshielded option. Turbine exhausts remain distinct from tailpipes. |
| Hoses and cables | Zodiac fuel line uses the supported cable path. HEMTT, Tempest and Zamak service reels share wound hose/flange construction. |

## Catalog candidates retained as specialized construction

Every catalog category was considered, but a broad keyword match is not enough to justify a shared assembly. These candidates do not establish three compatible construction sites under the agreed reuse rule:

| Candidate | Disposition |
|---|---|
| Gun shields | Different cut-out and bent-plate outlines remain authored; do not replace them with a generic box. |
| Suspension arms | Sparse wishbone/swing-arm evidence does not establish three matching mechanisms. Existing axle/gear helpers remain in use. |
| Air cleaners, filters and snorkels | Truck filter cans, helicopter inlet filters and snorkel pipework are different assemblies; no universal filter wrapper added. |
| Missile launch rails | The catalog found no qualifying independent sites; existing pylons and weapon-specific racks remain. |
| External fuel drums | Filler caps are now shared, but full drum/cradle construction lacks three compatible independent adopters. |
| Spare-wheel carriers | Shared spare wheels stay shared; bespoke carrier frames lack three matching independent designs. |
| Liferafts and life rings | Canisters, cradles and rings are distinct, with insufficient independent adopters of each style. |

Within migrated categories, cast mantlets, tow balls, exposed radar dishes, refuelling probes, boat waterjets/rudders, rescue-winch housings and aircraft inlet/nozzle topology remain specialized. The refreshed ranking still lists remaining source leads, including mixed sections where only some geometry migrated.

## Validation and evidence

- Godot 4.7.2 import and ten vehicle tests pass: assembly openings and leaf bounds, wheels, sockets, motion, rotors, LOD, materials, surfaces, detail and source coverage.
- All 137 catalog model keys plus three wrecks rendered in Compatibility; overview sheets reviewed locally. Matched before/after detail captures use baseline `26ca2f2`. Only one combined sheet is committed.
- The 30-second fixed-step roster scenario exits successfully, with no script errors. Shutdown reports leaked ObjectDB instances and two resources still in use; this pass does not resolve those cleanup warnings.
- Forward+ was attempted but Vulkan initialization failed on this machine and Godot fell back to Compatibility. Forward+ appearance is unverified.
- Across 135 models in the existing geometry metric stage: nodes 4,376 → 4,376; meshes 3,043 → 3,043; material surfaces 6,214 → 6,308 (+1.51%); vertices 26,099,637 → 27,104,155 (+3.85%). All per-model wheel/rotor registration counts are unchanged (764 wheels, 28 rotors total). These are geometry measurements, not FPS or build-time claims.

Reproduce coverage with `python3 tools/vehicles/construction-index.py --output /tmp/vehicle-index.json`; see `tools/vehicles/assembly-extractions.json` for the tested API list. Reproduce geometry with `tools/vehicles/construction-metrics.tscn` on baseline and current revisions. Capture settings are beside the combined sheet in the changelog folder.
