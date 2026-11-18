# Most common remaining vehicle construction

Source revision: `ec2d275b`. 137 model keys, 84 construction-root groups.

Counts are **distinct builder groups with candidate evidence**, not instances or variant counts. Sites are distinct source sections. A high count means broad potential reuse; it does not prove that all shapes fit the same API.

- Conditional branches are a union per builder root, not per-variant runtime presence.
- Comment/helper-name categories plus local construction are candidates, not verified identical meshes.
- Unlabelled construction is retained; only descriptive helper names can classify it automatically.
- Dynamic calls and inner-class construction require linked source inspection.
- Convoy team union and shadowed dispatchers do not add to design counts.
- Family-local helpers may already share a part within one family; ranking concerns cross-family extraction.

## Candidates for dedicated assemblies

| Rank | Part | Builder groups | Source sites | Suggested reuse |
|---|---|---:|---:|---|
| 1 | Ship liferafts and life rings | 2 | 5 | Canister cradles and buoy attachments; distinct styles, not a single shape. |

## Existing assemblies with remaining local construction

| Rank | Part | Builder groups | Source sites | Suggested reuse |
|---|---|---:|---:|---|
| 1 | Window and canopy construction | 25 | 23 | Extend fitted glazing where compatible; do not enable transparency over solid hulls. |
| 2 | Door/ramp construction | 23 | 38 | Finish migrating compatible leaves to VehicleDoors; sliding rails and ramps need extensions. |
| 3 | Vents and grille construction | 21 | 22 | Migrate flat/outline vents; ducts and optimized ship vents may differ. |
| 4 | Boarding steps and ladders | 19 | 18 | Use tread/ladder builders; retain folding stairs and helicopter-specific supports. |
| 5 | Exhaust construction | 18 | 17 | Extend stack adapters; silencers, turbine grilles and suppressors are not interchangeable. |
| 6 | Boat bow eyes | 9 | 5 | Ring with a backing plate on the stem. |
| 7 | Turret mantlets and gun cradles | 8 | 8 | Pivot-relative shrouds and supports; retain weapon sockets and recoil parents. |
| 8 | Rectangular hatch lids | 7 | 10 | Flat lids with coaming, hinges and handle; round hatches use VehicleFittings.hatch. |
| 9 | Fenders and mudguards | 7 | 8 | Flat sheets with bead, bolts and stays; faceted armoured arches stay authored. |
| 10 | Machine guns | 7 | 7 | Receiver-to-muzzle construction with feed and grips; DShK-style finned barrels may stay authored. |
| 11 | Seat and bench construction | 7 | 7 | Use shared seats; bench and jockey-seat layouts need separate dimension contracts. |
| 12 | Engine nacelles and cowling assemblies | 7 | 5 | Station loft plus service splits and mounts; aircraft silhouettes remain distinct. |
| 13 | Bumpers and bumper end caps | 6 | 6 | Section, end treatment, attachment points and tow cutouts; preserve vehicle width. |
| 14 | Truck cargo beds | 5 | 8 | Deck, runners, rails, posts, dropsides and tailgate on authored bounds. |
| 15 | Automatic cannon | 5 | 6 | Breech-to-muzzle sleeve, tube and brake; returns the caller's muzzle. |
| 16 | Handrails and grab handles | 5 | 6 | Extend current rails and pulls; preserve optimized marine rail meshes. |
| 17 | Radar dishes and radomes | 5 | 6 | Separate dish and dome styles with pedestals; retain rotating parents. |
| 18 | Sight heads and panoramic sights | 5 | 5 | Armoured head, bezelled windows and visor; lofted or cylindrical heads stay authored. |
| 19 | Rotary barrel clusters | 5 | 4 | Barrel ring, clamps and bores along any axis; housings and motors stay authored. |
| 20 | Cockpit dashboards and instrument consoles | 4 | 4 | Console profiles and instrument placements; keep cockpit layouts authored. |
| 21 | Helicopter landing gear | 4 | 4 | Drag beam, strut and oleo to the caller's wheel pivot; tailwheel leg, brace and crown. |
| 22 | Saddle fuel tanks | 4 | 4 | Round or box tanks on the frame rail; aircraft drop tanks are a different store. |
| 23 | Towing pintles and hitches | 4 | 4 | Mounting plate, jaws and pin; tow balls and recovery shackles are separate parts. |
| 24 | Pedestal gun mounts | 3 | 5 | Plate, post, braces, swivel and yoke around the caller's pivot. |
| 25 | Vehicle cranes and hoists | 3 | 4 | Boom sections, pivot joints and cable routing; vehicle layouts and movement stay local. |
| 26 | Commander's cupolas and vision blocks | 3 | 3 | Ring, flange and vision-block housings; hatches and weapon rings stay separate. |
| 27 | Dome and anti-collision lights | 3 | 3 | Round lens on a base; box lamps and light bars stay authored. |
| 28 | Lamp units | 3 | 3 | Housing, inserts, indicator and guard; light bars stay authored. |
| 29 | Plates, crosses and lettering | 3 | 3 | Embossed plate in a holder; cross on a ground; the shared stroke font. |
| 30 | Rolled tarps and bedrolls | 2 | 3 | Rolled canvas with straps; draped covers use VehicleCloth.load_cover. |
| 31 | Air cleaners, filters and snorkels | 2 | 2 | Filter housings, clamps and pipe transitions; not generic turbine ducts. |
| 32 | Cargo sideboards and tailgates | 2 | 2 | Panel runs, posts, hinges and latch placement on authored bed bounds. |
| 33 | Closed bins and toolboxes | 2 | 2 | Migrate top-lid bins; upright cabinets require another opening orientation. |
| 34 | Countermeasure dispensers | 2 | 2 | Box with a field of slots on one face. |
| 35 | Marine propellers and rudders | 2 | 2 | Screw propellers share VehicleMarine.propeller; rudders and waterjets have no shared builder yet. |
| 36 | Missile launch tubes | 2 | 2 | Tube, collars and covers; box launchers with tube mouths are a separate design. |
| 37 | Smoke discharger banks | 2 | 2 | Bracket, junction box and tubes from the family's own layout. |
| 38 | Gun shields and weapon-station armour | 1 | 3 | Bent plate outlines and viewing slots; keep traverse envelope. |
| 39 | Air-launched missiles | 1 | 1 | Revolved body, nose style, slab fins, band and rail. |
| 40 | Aircraft pitot and probe fittings | 1 | 1 | Tapered tubes, bases and authored angled paths; leave specialized refuelling systems local. |
| 41 | Bore evacuators | 1 | 1 | Tapered chamber on the gun tube; muzzle sensors and brakes stay authored. |
| 42 | Door levers and sliding-door rails | 1 | 1 | Handle with boss and pin; rail with brackets along a surface. |
| 43 | External fuel drums and drum cradles | 1 | 1 | Drum ribs, ends and cradles; tanker vessel and aerodynamic drop tank are different. |
| 44 | Formation lights and refuelling receptacles | 1 | 1 | Strips and doors laid on the skin, open or closed, with lead-in lines. |
| 45 | Fuel fillers and filler caps | 1 | 1 | Recess, neck, cap and optional tether; preserve supplied outward axis. |
| 46 | Gun receivers and breech housings | 1 | 1 | Parameterized receiver families, not one universal weapon silhouette. |
| 47 | Hose and tow-cable routes | 1 | 1 | Use supported cable routes; coils and wound drums need distinct construction. |
| 48 | Muzzle brakes and muzzle sensors | 1 | 1 | Sleeve, baffles and side ports from the barrel's end; sensor box with its bore window. |
| 49 | Roll cages and bull bars | 1 | 1 | Tube members with detected joints, clamps and base plates. |
| 50 | Rotor masts | 1 | 1 | Shaft, bearing housing, splines and bolted collars; hubs and blades stay in VehicleRotors.main. |
| 51 | Searchlights and light bars | 1 | 1 | Barrel lamp on a yoke or bracket; lens rows in a bar housing. |
| 52 | Suspension arms and hubs | 1 | 1 | Endpoint-based links, joints and spring/damper pairs; solid axles already exist. |

## Using the remaining candidates

The [assembly implementation review](vehicle-assembly-review.md) records migrations and supported shapes. Remaining matches are source leads: inspect the linked geometry before extending an API. Keep candidates below three compatible builder groups as inventory until another adopter is found. Mixed sections can still appear here after some of their parts migrate.

## Evidence by candidate

### Window and canopy construction

- **bobcat**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:602](../scripts\game\vehicles\vm_heli.gd#L602)
- **gunship**: [VmCore._apache:1611](../scripts\game\vehicles\vm_core.gd#L1611); [VmHeli._canopy:1016](../scripts\game\vehicles\vm_heli.gd#L1016)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1294](../scripts\game\vehicles\vm_nato.gd#L1294)
- **humvee**: [VmCore._humvee:1271](../scripts\game\vehicles\vm_core.gd#L1271)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300); [VmNato._hunter:352](../scripts\game\vehicles\vm_nato.gd#L352)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:269](../scripts\game\vehicles\vm_csat.gd#L269)
- **kajman**: [VmHeli._canopy:1016](../scripts\game\vehicles\vm_heli.gd#L1016)
- **kuma**: [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:248](../scripts\game\vehicles\vm_civ.gd#L248)
- **motorboat**: [VmBoat._motorboat:600](../scripts\game\vehicles\vm_boat.gd#L600)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:248](../scripts\game\vehicles\vm_civ.gd#L248)
- **panther**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **patrol_ship**: [VmShips._mk38:455](../scripts\game\vehicles\vm_ships.gd#L455); [VmShips._patrol_ship:659](../scripts\game\vehicles\vm_ships.gd#L659)
- **rhino, rhino_up**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **scorcher**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **sdv**: [VmBoat._sdv:870](../scripts\game\vehicles\vm_boat.gd#L870)
- **sentinel**: [VmPlane._sentinel:989](../scripts\game\vehicles\vm_plane.gd#L989)
- **slammer, slammer_up**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:988](../scripts\game\vehicles\vm_boat.gd#L988); [VmBoat._surc:1062](../scripts\game\vehicles\vm_boat.gd#L1062)
- **stomper**: [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:180](../scripts\game\vehicles\vm_indep.gd#L180); [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:844](../scripts\game\vehicles\vm_civ.gd#L844); [VmCiv._van_ambulance:866](../scripts\game\vehicles\vm_civ.gd#L866)
- **wipeout**: [VmAttack._wip_cockpit:815](../scripts\game\vehicles\vm_attack.gd#L815); [VmAttack._wip_gun:856](../scripts\game\vehicles\vm_attack.gd#L856)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:856](../scripts\game\vehicles\vm_indep.gd#L856)

### Door/ramp construction

- **a10**: [VmAttack._a10_gear:557](../scripts\game\vehicles\vm_attack.gd#L557)
- **aa_tech, technical**: [VmCore._hilux:1035](../scripts\game\vehicles\vm_core.gd#L1035)
- **ac130**: [VmGunship._ac130:346](../scripts\game\vehicles\vm_gunship.gd#L346)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:546](../scripts\game\vehicles\vm_heli.gd#L546); [VmHeli._ghost_hawk:552](../scripts\game\vehicles\vm_heli.gd#L552); [VmHeli._ghost_hawk:602](../scripts\game\vehicles\vm_heli.gd#L602)
- **gun_trawler**: [VmShips._gun_trawler:1107](../scripts\game\vehicles\vm_ships.gd#L1107); [VmShips._gun_trawler:1127](../scripts\game\vehicles\vm_ships.gd#L1127)
- **heli**: [VmCore._blackhawk:1726](../scripts\game\vehicles\vm_core.gd#L1726); [VmCore._blackhawk:1735](../scripts\game\vehicles\vm_core.gd#L1735)
- **hellcat**: [VmHeli._hellcat:951](../scripts\game\vehicles\vm_heli.gd#L951)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1296](../scripts\game\vehicles\vm_nato.gd#L1296); [VmNato._hemtt_cab_detail:1348](../scripts\game\vehicles\vm_nato.gd#L1348)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:436](../scripts\game\vehicles\vm_heli.gd#L436)
- **huron**: [VmHeli._huron:650](../scripts\game\vehicles\vm_heli.gd#L650); [VmHeli._huron:665](../scripts\game\vehicles\vm_heli.gd#L665); [VmHeli._huron:690](../scripts\game\vehicles\vm_heli.gd#L690)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:278](../scripts\game\vehicles\vm_csat.gd#L278); [VmCsat._ifrit:281](../scripts\game\vehicles\vm_csat.gd#L281)
- **jet**: [VmFighter._f16:797](../scripts\game\vehicles\vm_fighter.gd#L797)
- **kajman**: [VmHeli._kajman:1076](../scripts\game\vehicles\vm_heli.gd#L1076)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:499](../scripts\game\vehicles\vm_civ.gd#L499); [VmCiv._mb_top:589](../scripts\game\vehicles\vm_civ.gd#L589)
- **mohawk**: [VmHeli._mohawk:857](../scripts\game\vehicles\vm_heli.gd#L857); [VmHeli._mohawk:864](../scripts\game\vehicles\vm_heli.gd#L864); [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:333](../scripts\game\vehicles\vm_civ.gd#L333)
- **orca, orca_armed**: [VmHeli._orca:1172](../scripts\game\vehicles\vm_heli.gd#L1172); [VmHeli._orca:1177](../scripts\game\vehicles\vm_heli.gd#L1177)
- **sentinel**: [VmPlane._sentinel:989](../scripts\game\vehicles\vm_plane.gd#L989); [VmPlane._sentinel:997](../scripts\game\vehicles\vm_plane.gd#L997)
- **suv**: [VmCiv._suv:1171](../scripts\game\vehicles\vm_civ.gd#L1171)
- **tank**: [VmCore._abrams:488](../scripts\game\vehicles\vm_core.gd#L488); [VmCore._abrams:546](../scripts\game\vehicles\vm_core.gd#L546)
- **van_ambulance, van_services, van_transport**: [VmCiv._van_ambulance:866](../scripts\game\vehicles\vm_civ.gd#L866); [VmCiv._van_services:899](../scripts\game\vehicles\vm_civ.gd#L899)
- **wipeout**: [VmAttack._wip_gear:1009](../scripts\game\vehicles\vm_attack.gd#L1009)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:856](../scripts\game\vehicles\vm_indep.gd#L856)

### Vents and grille construction

- **assault_boat**: [VmBoat._outboard:431](../scripts\game\vehicles\vm_boat.gd#L431)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:765](../scripts\game\vehicles\vm_gunship.gd#L765)
- **greyhawk**: [VmPlane._greyhawk:924](../scripts\game\vehicles\vm_plane.gd#L924)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1040](../scripts\game\vehicles\vm_civ.gd#L1040)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1462](../scripts\game\vehicles\vm_nato.gd#L1462)
- **humvee**: [VmCore._humvee:1206](../scripts\game\vehicles\vm_core.gd#L1206)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:330](../scripts\game\vehicles\vm_nato.gd#L330)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:278](../scripts\game\vehicles\vm_csat.gd#L278)
- **jet**: [VmFighter._f16:740](../scripts\game\vehicles\vm_fighter.gd#L740); [VmFighter._f16:768](../scripts\game\vehicles\vm_fighter.gd#L768)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:241](../scripts\game\vehicles\vm_civ.gd#L241)
- **mora**: [VmIndep._mora:391](../scripts\game\vehicles\vm_indep.gd#L391)
- **motorboat**: [VmBoat._outboard:431](../scripts\game\vehicles\vm_boat.gd#L431)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:241](../scripts\game\vehicles\vm_civ.gd#L241); [VmCiv._offroad:309](../scripts\game\vehicles\vm_civ.gd#L309)
- **old_tank**: [VmCore._t55:849](../scripts\game\vehicles\vm_core.gd#L849); [VmCore._t55:920](../scripts\game\vehicles\vm_core.gd#L920)
- **patrol_ship**: [VmShips._vent:392](../scripts\game\vehicles\vm_ships.gd#L392); [VmShips._patrol_ship:827](../scripts\game\vehicles\vm_ships.gd#L827)
- **rhib**: [VmBoat._outboard:431](../scripts\game\vehicles\vm_boat.gd#L431)
- **sdv**: [VmBoat._sdv:874](../scripts\game\vehicles\vm_boat.gd#L874)
- **taru**: [VmHeli._taru:1291](../scripts\game\vehicles\vm_heli.gd#L1291)
- **tractor**: [VmCiv._tractor:1307](../scripts\game\vehicles\vm_civ.gd#L1307)
- **water_scooter**: [VmBoat._scooter:1183](../scripts\game\vehicles\vm_boat.gd#L1183)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_fuel:1044](../scripts\game\vehicles\vm_indep.gd#L1044)

### Boarding steps and ladders

- **aa_tech, technical**: [VmCore._hilux:992](../scripts\game\vehicles\vm_core.gd#L992)
- **apc, btr**: [VmCore._btr80:1379](../scripts\game\vehicles\vm_core.gd#L1379)
- **blackfoot**: [VmHeli._blackfoot:760](../scripts\game\vehicles\vm_heli.gd#L760)
- **bobcat**: [VmNato._namer_hull:1127](../scripts\game\vehicles\vm_nato.gd#L1127)
- **cheetah**: [VmNato._namer_hull:1127](../scripts\game\vehicles\vm_nato.gd#L1127)
- **fia_truck, fia_truck_box**: [VmCiv._truck:633](../scripts\game\vehicles\vm_civ.gd#L633)
- **gryphon**: [VmPlane._gryphon:613](../scripts\game\vehicles\vm_plane.gd#L613)
- **gun_trawler**: [VmShips._gun_trawler:993](../scripts\game\vehicles\vm_ships.gd#L993)
- **gunship**: [VmCore._apache:1611](../scripts\game\vehicles\vm_core.gd#L1611)
- **heli**: [VmCore._blackhawk:1735](../scripts\game\vehicles\vm_core.gd#L1735)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1296](../scripts\game\vehicles\vm_nato.gd#L1296); [VmNato._hemtt_cab_detail:1348](../scripts\game\vehicles\vm_nato.gd#L1348)
- **kajman**: [VmHeli._kajman:1072](../scripts\game\vehicles\vm_heli.gd#L1072)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:275](../scripts\game\vehicles\vm_civ.gd#L275)
- **panther**: [VmNato._namer_hull:1127](../scripts\game\vehicles\vm_nato.gd#L1127)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1075](../scripts\game\vehicles\vm_boat.gd#L1075)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:180](../scripts\game\vehicles\vm_indep.gd#L180)
- **van_ambulance, van_services, van_transport**: [VmCiv._van_services:892](../scripts\game\vehicles\vm_civ.gd#L892)
- **water_scooter**: [VmBoat._scooter:1144](../scripts\game\vehicles\vm_boat.gd#L1144)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_fuel:1044](../scripts\game\vehicles\vm_indep.gd#L1044)

### Exhaust construction

- **a10**: [VmAttack._a10_engines:462](../scripts\game\vehicles\vm_attack.gd#L462)
- **aa_tech, technical**: [VmCore._hilux:992](../scripts\game\vehicles\vm_core.gd#L992)
- **angara, angara_k**: [VmCsat._t14:1071](../scripts\game\vehicles\vm_csat.gd#L1071)
- **blackfoot**: [VmHeli._blackfoot:767](../scripts\game\vehicles\vm_heli.gd#L767)
- **caesar**: [VmPlane._caesar:699](../scripts\game\vehicles\vm_plane.gd#L699)
- **futura**: [VmCsat._t100:841](../scripts\game\vehicles\vm_csat.gd#L841)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:565](../scripts\game\vehicles\vm_heli.gd#L565)
- **gorgon**: [VmIndep._gorgon:723](../scripts\game\vehicles\vm_indep.gd#L723)
- **heli**: [VmCore._blackhawk:1757](../scripts\game\vehicles\vm_core.gd#L1757)
- **ifv**: [VmCore._bradley:1483](../scripts\game\vehicles\vm_core.gd#L1483)
- **kajman**: [VmHeli._kajman:1089](../scripts\game\vehicles\vm_heli.gd#L1089)
- **kuma**: [VmIndep._kuma:489](../scripts\game\vehicles\vm_indep.gd#L489)
- **marid**: [VmCsat._marid:599](../scripts\game\vehicles\vm_csat.gd#L599)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:275](../scripts\game\vehicles\vm_civ.gd#L275)
- **old_tank**: [VmCore._t55:849](../scripts\game\vehicles\vm_core.gd#L849)
- **patrol_ship**: [VmShips._patrol_ship:614](../scripts\game\vehicles\vm_ships.gd#L614); [VmShips._patrol_ship:853](../scripts\game\vehicles\vm_ships.gd#L853)
- **sochor**: [VmCsat._t100:841](../scripts\game\vehicles\vm_csat.gd#L841)
- **varsuk**: [VmCsat._t100:841](../scripts\game\vehicles\vm_csat.gd#L841)

### Boat bow eyes

- **bobcat**: [VmNato._namer_hull:1077](../scripts\game\vehicles\vm_nato.gd#L1077)
- **cheetah**: [VmNato._namer_hull:1077](../scripts\game\vehicles\vm_nato.gd#L1077)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1283](../scripts\game\vehicles\vm_nato.gd#L1283)
- **kuma**: [VmIndep._kuma:485](../scripts\game\vehicles\vm_indep.gd#L485)
- **panther**: [VmNato._namer_hull:1077](../scripts\game\vehicles\vm_nato.gd#L1077)
- **rhino, rhino_up**: [VmNato._rhino:664](../scripts\game\vehicles\vm_nato.gd#L664)
- **sandstorm**: [VmNato._mk_hull:801](../scripts\game\vehicles\vm_nato.gd#L801)
- **scorcher**: [VmNato._mk_hull:801](../scripts\game\vehicles\vm_nato.gd#L801)
- **slammer, slammer_up**: [VmNato._mk_hull:801](../scripts\game\vehicles\vm_nato.gd#L801)

### Turret mantlets and gun cradles

- **aa_tech, technical**: [VmCore._zu23:1145](../scripts\game\vehicles\vm_core.gd#L1145)
- **ac130**: [VmGunship._ac130_guns:562](../scripts\game\vehicles\vm_gunship.gd#L562)
- **gun_trawler**: [VmShips._zu23:521](../scripts\game\vehicles\vm_ships.gd#L521); [VmShips._dshk:546](../scripts\game\vehicles\vm_ships.gd#L546)
- **kuma**: [VmIndep._rcws:309](../scripts\game\vehicles\vm_indep.gd#L309)
- **old_tank**: [VmCore._t55:899](../scripts\game\vehicles\vm_core.gd#L899)
- **patrol_ship**: [VmShips._mk38:446](../scripts\game\vehicles\vm_ships.gd#L446)
- **strider, strider_gmg, strider_hmg**: [VmIndep._rcws:309](../scripts\game\vehicles\vm_indep.gd#L309)
- **xian**: [VmPlane._xian:1169](../scripts\game\vehicles\vm_plane.gd#L1169)

### Rectangular hatch lids

- **falcon**: [VmHeli._falcon:1364](../scripts\game\vehicles\vm_heli.gd#L1364)
- **gun_trawler**: [VmShips._gun_trawler:1041](../scripts\game\vehicles\vm_ships.gd#L1041)
- **hatchback, hatchback_sport**: [VmCiv._hatch:987](../scripts\game\vehicles\vm_civ.gd#L987); [VmCiv._hatch_sport:1062](../scripts\game\vehicles\vm_civ.gd#L1062); [VmCiv._hatch_sport:1068](../scripts\game\vehicles\vm_civ.gd#L1068)
- **mora**: [VmIndep._mora:410](../scripts\game\vehicles\vm_indep.gd#L410)
- **sdv**: [VmBoat._sdv:833](../scripts\game\vehicles\vm_boat.gd#L833); [VmBoat._sdv:852](../scripts\game\vehicles\vm_boat.gd#L852)
- **tank**: [VmCore._abrams:421](../scripts\game\vehicles\vm_core.gd#L421)
- **water_scooter**: [VmBoat._scooter:1194](../scripts\game\vehicles\vm_boat.gd#L1194)

### Fenders and mudguards

- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:610](../scripts\game\vehicles\vm_heli.gd#L610)
- **heli**: [VmCore._blackhawk:1776](../scripts\game\vehicles\vm_core.gd#L1776)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:330](../scripts\game\vehicles\vm_nato.gd#L330)
- **old_tank**: [VmCore._t55:849](../scripts\game\vehicles\vm_core.gd#L849)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:437](../scripts\game\vehicles\vm_nato.gd#L437)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:391](../scripts\game\vehicles\vm_csat.gd#L391)
- **tank**: [VmCore._abrams:436](../scripts\game\vehicles\vm_core.gd#L436); [VmCore._abrams:443](../scripts\game\vehicles\vm_core.gd#L443)

### Machine guns

- **aa_tech, technical**: [VmCore._dshk:732](../scripts\game\vehicles\vm_core.gd#L732)
- **apc, btr**: [VmCore._btr80:1400](../scripts\game\vehicles\vm_core.gd#L1400)
- **gun_trawler**: [VmShips._gun_trawler:1028](../scripts\game\vehicles\vm_ships.gd#L1028)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:648](../scripts\game\vehicles\vm_indep.gd#L648)
- **old_tank**: [VmCore._dshk:732](../scripts\game\vehicles\vm_core.gd#L732); [VmCore._t55:925](../scripts\game\vehicles\vm_core.gd#L925)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1048](../scripts\game\vehicles\vm_boat.gd#L1048)
- **tank**: [VmCore._abrams:528](../scripts\game\vehicles\vm_core.gd#L528)

### Seat and bench construction

- **blackwasp**: [VmFighter._blackwasp:995](../scripts\game\vehicles\vm_fighter.gd#L995)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1396](../scripts\game\vehicles\vm_nato.gd#L1396)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:452](../scripts\game\vehicles\vm_heli.gd#L452)
- **kart**: [VmCiv._kart:1264](../scripts\game\vehicles\vm_civ.gd#L1264)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:562](../scripts\game\vehicles\vm_civ.gd#L562)
- **water_scooter**: [VmBoat._scooter:1183](../scripts\game\vehicles\vm_boat.gd#L1183)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_tilt:911](../scripts\game\vehicles\vm_indep.gd#L911)

### Engine nacelles and cowling assemblies

- **a10**: [VmAttack._a10_engines:465](../scripts\game\vehicles\vm_attack.gd#L465)
- **ac130**: [VmGunship._t56:517](../scripts\game\vehicles\vm_gunship.gd#L517)
- **assault_boat**: [VmBoat._outboard:437](../scripts\game\vehicles\vm_boat.gd#L437)
- **falcon**: [VmHeli._falcon:1369](../scripts\game\vehicles\vm_heli.gd#L1369)
- **motorboat**: [VmBoat._outboard:437](../scripts\game\vehicles\vm_boat.gd#L437)
- **rhib**: [VmBoat._outboard:437](../scripts\game\vehicles\vm_boat.gd#L437)
- **wipeout**: [VmAttack._wip_engines:943](../scripts\game\vehicles\vm_attack.gd#L943)

### Bumpers and bumper end caps

- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:278](../scripts\game\vehicles\vm_csat.gd#L278)
- **kart**: [VmCiv._kart:1271](../scripts\game\vehicles\vm_civ.gd#L1271)
- **m35**: [VmCore._truck:1825](../scripts\game\vehicles\vm_core.gd#L1825)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._typhoon:1162](../scripts\game\vehicles\vm_csat.gd#L1162)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:825](../scripts\game\vehicles\vm_civ.gd#L825)
- **water_scooter**: [VmBoat._scooter:1116](../scripts\game\vehicles\vm_boat.gd#L1116)

### Truck cargo beds

- **aa_tech, technical**: [VmCore._hilux:1001](../scripts\game\vehicles\vm_core.gd#L1001); [VmCore._hilux:1007](../scripts\game\vehicles\vm_core.gd#L1007); [VmCore._hilux:1054](../scripts\game\vehicles\vm_core.gd#L1054); [VmCore._hilux_dshk:1112](../scripts\game\vehicles\vm_core.gd#L1112)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._cargo:1495](../scripts\game\vehicles\vm_nato.gd#L1495)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:388](../scripts\game\vehicles\vm_nato.gd#L388)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._off_at:413](../scripts\game\vehicles\vm_civ.gd#L413)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:996](../scripts\game\vehicles\vm_indep.gd#L996)

### Automatic cannon

- **ac130**: [VmGunship._ac130_guns:540](../scripts\game\vehicles\vm_gunship.gd#L540); [VmGunship._ac130_guns:548](../scripts\game\vehicles\vm_gunship.gd#L548)
- **blackfish, blackfish_armed**: [VmGunship._bf_guns:795](../scripts\game\vehicles\vm_gunship.gd#L795)
- **marid**: [VmCsat._marid:635](../scripts\game\vehicles\vm_csat.gd#L635)
- **marshall**: [VmNato._marshall:611](../scripts\game\vehicles\vm_nato.gd#L611)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1048](../scripts\game\vehicles\vm_boat.gd#L1048)

### Handrails and grab handles

- **assault_boat**: [VmBoat._zodiac:525](../scripts\game\vehicles\vm_boat.gd#L525)
- **gun_trawler**: [VmShips._gun_trawler:993](../scripts\game\vehicles\vm_ships.gd#L993)
- **motorboat**: [VmBoat._motorboat:604](../scripts\game\vehicles\vm_boat.gd#L604); [VmBoat._motorboat:628](../scripts\game\vehicles\vm_boat.gd#L628)
- **old_tank**: [VmCore._t55:940](../scripts\game\vehicles\vm_core.gd#L940)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:856](../scripts\game\vehicles\vm_indep.gd#L856)

### Radar dishes and radomes

- **cheetah**: [VmNato._cheetah:1216](../scripts\game\vehicles\vm_nato.gd#L1216); [VmNato._cheetah:1221](../scripts\game\vehicles\vm_nato.gd#L1221)
- **gunship**: [VmCore._apache:1681](../scripts\game\vehicles\vm_core.gd#L1681)
- **heli**: [VmCore._blackhawk:1749](../scripts\game\vehicles\vm_core.gd#L1749)
- **mohawk**: [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884)
- **tigris**: [VmCsat._tigris:766](../scripts\game\vehicles\vm_csat.gd#L766)

### Sight heads and panoramic sights

- **marshall**: [VmNato._marshall:611](../scripts\game\vehicles\vm_nato.gd#L611)
- **mora**: [VmIndep._mora:410](../scripts\game\vehicles\vm_indep.gd#L410)
- **patrol_ship**: [VmShips._mk38:455](../scripts\game\vehicles\vm_ships.gd#L455)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1048](../scripts\game\vehicles\vm_boat.gd#L1048)
- **tank**: [VmCore._abrams:546](../scripts\game\vehicles\vm_core.gd#L546)

### Rotary barrel clusters

- **ac130**: [VmGunship._ac130_guns:540](../scripts\game\vehicles\vm_gunship.gd#L540)
- **ghosthawk, ghosthawk_stub**: [VmHeli._minigun:369](../scripts\game\vehicles\vm_heli.gd#L369)
- **hellcat**: [VmHeli._minigun:369](../scripts\game\vehicles\vm_heli.gd#L369); [VmHeli._hellcat:986](../scripts\game\vehicles\vm_heli.gd#L986)
- **hummingbird, m900, pawnee**: [VmHeli._minigun:369](../scripts\game\vehicles\vm_heli.gd#L369); [VmHeli._little_bird:497](../scripts\game\vehicles\vm_heli.gd#L497)
- **orca, orca_armed**: [VmHeli._minigun:369](../scripts\game\vehicles\vm_heli.gd#L369)

### Cockpit dashboards and instrument consoles

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1275](../scripts\game\vehicles\vm_nato.gd#L1275)
- **motorboat**: [VmBoat._motorboat:600](../scripts\game\vehicles\vm_boat.gd#L600)
- **quadbike**: [VmCiv._quad:930](../scripts\game\vehicles\vm_civ.gd#L930)
- **rhib**: [VmBoat._rhib:742](../scripts\game\vehicles\vm_boat.gd#L742)

### Helicopter landing gear

- **a10**: [VmAttack._a10_gear:549](../scripts\game\vehicles\vm_attack.gd#L549)
- **ac130**: [VmGunship._ac130_gear:595](../scripts\game\vehicles\vm_gunship.gd#L595)
- **blackfish, blackfish_armed**: [VmGunship._blackfish:647](../scripts\game\vehicles\vm_gunship.gd#L647)
- **mohawk**: [VmHeli._mohawk:868](../scripts\game\vehicles\vm_heli.gd#L868)

### Saddle fuel tanks

- **aa_tech, technical**: [VmCore._hilux:992](../scripts\game\vehicles\vm_core.gd#L992)
- **assault_boat**: [VmBoat._zodiac:508](../scripts\game\vehicles\vm_boat.gd#L508)
- **heli**: [VmCore._blackhawk:1776](../scripts\game\vehicles\vm_core.gd#L1776)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1449](../scripts\game\vehicles\vm_nato.gd#L1449)

### Towing pintles and hitches

- **aa_tech, technical**: [VmCore._hilux_dshk:1112](../scripts\game\vehicles\vm_core.gd#L1112)
- **gun_trawler**: [VmShips._dshk:546](../scripts\game\vehicles\vm_ships.gd#L546)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1283](../scripts\game\vehicles\vm_nato.gd#L1283)
- **tank**: [VmCore._abrams:568](../scripts\game\vehicles\vm_core.gd#L568)

### Pedestal gun mounts

- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:610](../scripts\game\vehicles\vm_indep.gd#L610)
- **tank**: [VmCore._abrams:514](../scripts\game\vehicles\vm_core.gd#L514); [VmCore._abrams:528](../scripts\game\vehicles\vm_core.gd#L528)
- **water_scooter**: [VmBoat._scooter:1144](../scripts\game\vehicles\vm_boat.gd#L1144); [VmBoat._scooter:1183](../scripts\game\vehicles\vm_boat.gd#L1183)

### Vehicle cranes and hoists

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1421](../scripts\game\vehicles\vm_nato.gd#L1421)
- **huron**: [VmHeli._huron:690](../scripts\game\vehicles\vm_heli.gd#L690)
- **mohawk**: [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884); [VmHeli._mohawk:886](../scripts\game\vehicles\vm_heli.gd#L886)

### Commander's cupolas and vision blocks

- **marid**: [VmCsat._marid:599](../scripts\game\vehicles\vm_csat.gd#L599)
- **marshall**: [VmNato._marshall:584](../scripts\game\vehicles\vm_nato.gd#L584)
- **old_tank**: [VmCore._t55:958](../scripts\game\vehicles\vm_core.gd#L958)

### Dome and anti-collision lights

- **a10**: [VmAttack._a10_details:642](../scripts\game\vehicles\vm_attack.gd#L642)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1075](../scripts\game\vehicles\vm_boat.gd#L1075)
- **van_ambulance, van_services, van_transport**: [VmCiv._van_ambulance:871](../scripts\game\vehicles\vm_civ.gd#L871)

### Lamp units

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1283](../scripts\game\vehicles\vm_nato.gd#L1283)
- **suv**: [VmCiv._suv:1180](../scripts\game\vehicles\vm_civ.gd#L1180)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:825](../scripts\game\vehicles\vm_civ.gd#L825)

### Plates, crosses and lettering

- **aa_tech, technical**: [VmCore._hilux:1066](../scripts\game\vehicles\vm_core.gd#L1066)
- **motorboat**: [VmBoat._motorboat:671](../scripts\game\vehicles\vm_boat.gd#L671)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_ammo:954](../scripts\game\vehicles\vm_indep.gd#L954)

### Ship liferafts and life rings

- **gun_trawler**: [VmShips._lifering:362](../scripts\game\vehicles\vm_ships.gd#L362); [VmShips._liferaft:374](../scripts\game\vehicles\vm_ships.gd#L374); [VmShips._gun_trawler:1021](../scripts\game\vehicles\vm_ships.gd#L1021)
- **patrol_ship**: [VmShips._lifering:362](../scripts\game\vehicles\vm_ships.gd#L362); [VmShips._liferaft:374](../scripts\game\vehicles\vm_ships.gd#L374); [VmShips._patrol_ship:697](../scripts\game\vehicles\vm_ships.gd#L697); [VmShips._patrol_ship:709](../scripts\game\vehicles\vm_ships.gd#L709)

### Rolled tarps and bedrolls

- **tank**: [VmCore._abrams:443](../scripts\game\vehicles\vm_core.gd#L443); [VmCore._bedroll:674](../scripts\game\vehicles\vm_core.gd#L674)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_ammo:958](../scripts\game\vehicles\vm_indep.gd#L958)

### Air cleaners, filters and snorkels

- **kajman**: [VmHeli._kajman:1089](../scripts\game\vehicles\vm_heli.gd#L1089)
- **old_tank**: [VmCore._t55:940](../scripts\game\vehicles\vm_core.gd#L940)

### Cargo sideboards and tailgates

- **aa_tech, technical**: [VmCore._hilux:1016](../scripts\game\vehicles\vm_core.gd#L1016)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._off_at:413](../scripts\game\vehicles\vm_civ.gd#L413)

### Closed bins and toolboxes

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1449](../scripts\game\vehicles\vm_nato.gd#L1449)
- **ifv**: [VmCore._bradley:1511](../scripts\game\vehicles\vm_core.gd#L1511)

### Countermeasure dispensers

- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:489](../scripts\game\vehicles\vm_civ.gd#L489)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:799](../scripts\game\vehicles\vm_civ.gd#L799)

### Marine propellers and rudders

- **patrol_ship**: [VmShips._patrol_ship:827](../scripts\game\vehicles\vm_ships.gd#L827)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1075](../scripts\game\vehicles\vm_boat.gd#L1075)

### Missile launch tubes

- **angara, angara_k**: [VmCsat._angara:1102](../scripts\game\vehicles\vm_csat.gd#L1102)
- **gorgon**: [VmIndep._gorgon:738](../scripts\game\vehicles\vm_indep.gd#L738)

### Smoke discharger banks

- **marshall**: [VmNato._marshall:611](../scripts\game\vehicles\vm_nato.gd#L611)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:996](../scripts\game\vehicles\vm_boat.gd#L996)

### Gun shields and weapon-station armour

- **tank**: [VmCore._abrams:514](../scripts\game\vehicles\vm_core.gd#L514); [VmCore._abrams:528](../scripts\game\vehicles\vm_core.gd#L528); [VmCore._abrams:568](../scripts\game\vehicles\vm_core.gd#L568)

### Air-launched missiles

- **xian**: [VmPlane._xian:1169](../scripts\game\vehicles\vm_plane.gd#L1169)

### Aircraft pitot and probe fittings

- **mohawk**: [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884)

### Bore evacuators

- **scorcher**: [VmNato._scorcher:993](../scripts\game\vehicles\vm_nato.gd#L993)

### Door levers and sliding-door rails

- **quadbike**: [VmCiv._quad:956](../scripts\game\vehicles\vm_civ.gd#L956)

### External fuel drums and drum cradles

- **old_tank**: [VmCore._t55:868](../scripts\game\vehicles\vm_core.gd#L868)

### Formation lights and refuelling receptacles

- **jet**: [VmFighter._f16:785](../scripts\game\vehicles\vm_fighter.gd#L785)

### Fuel fillers and filler caps

- **water_scooter**: [VmBoat._scooter:1183](../scripts\game\vehicles\vm_boat.gd#L1183)

### Gun receivers and breech housings

- **futura**: [VmCsat._futura:937](../scripts\game\vehicles\vm_csat.gd#L937)

### Hose and tow-cable routes

- **patrol_ship**: [VmShips._patrol_ship:697](../scripts\game\vehicles\vm_ships.gd#L697)

### Muzzle brakes and muzzle sensors

- **scorcher**: [VmNato._scorcher:993](../scripts\game\vehicles\vm_nato.gd#L993)

### Roll cages and bull bars

- **m35**: [VmCore._truck:1825](../scripts\game\vehicles\vm_core.gd#L1825)

### Rotor masts

- **tank**: [VmCore._abrams:580](../scripts\game\vehicles\vm_core.gd#L580)

### Searchlights and light bars

- **patrol_ship**: [VmShips._patrol_ship:730](../scripts\game\vehicles\vm_ships.gd#L730)

### Suspension arms and hubs

- **stomper**: [VmNato._stomper:1528](../scripts\game\vehicles\vm_nato.gd#L1528)

