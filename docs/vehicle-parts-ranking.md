# Most common remaining vehicle construction

Source revision: `69a1df03`. 137 model keys, 84 construction-root groups.

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
| 1 | Air cleaners, filters and snorkels | 3 | 3 | Filter housings, clamps and pipe transitions; not generic turbine ducts. |
| 2 | Ship liferafts and life rings | 2 | 5 | Canister cradles and buoy attachments; distinct styles, not a single shape. |
| 3 | Spare-wheel carriers | 2 | 2 | Brackets and retention hardware around the shared spare wheel; wheel itself is extracted. |
| 4 | Suspension arms and hubs | 2 | 2 | Endpoint-based links, joints and spring/damper pairs; solid axles already exist. |
| 5 | Gun shields and weapon-station armour | 1 | 3 | Bent plate outlines and viewing slots; keep traverse envelope. |
| 6 | External fuel drums and drum cradles | 1 | 1 | Drum ribs, ends and cradles; tanker vessel and aerodynamic drop tank are different. |

## Existing assemblies with remaining local construction

| Rank | Part | Builder groups | Source sites | Suggested reuse |
|---|---|---:|---:|---|
| 1 | Vents and grille construction | 43 | 49 | Migrate flat/outline vents; ducts and optimized ship vents may differ. |
| 2 | Door/ramp construction | 41 | 65 | Finish migrating compatible leaves to VehicleDoors; sliding rails and ramps need extensions. |
| 3 | Boarding steps and ladders | 26 | 36 | Use tread/ladder builders; retain folding stairs and helicopter-specific supports. |
| 4 | Exhaust construction | 26 | 23 | Extend stack adapters; silencers, turbine grilles and suppressors are not interchangeable. |
| 5 | Window and canopy construction | 25 | 25 | Extend fitted glazing where compatible; do not enable transparency over solid hulls. |
| 6 | Seat and bench construction | 15 | 19 | Use shared seats; bench and jockey-seat layouts need separate dimension contracts. |
| 7 | Closed bins and toolboxes | 13 | 14 | Migrate top-lid bins; upright cabinets require another opening orientation. |
| 8 | Fenders and mudguards | 13 | 13 | Flat sheets with bead, bolts and stays; faceted armoured arches stay authored. |
| 9 | Commander's cupolas and vision blocks | 11 | 10 | Ring, flange and vision-block housings; hatches and weapon rings stay separate. |
| 10 | Rectangular hatch lids | 10 | 15 | Flat lids with coaming, hinges and handle; round hatches use VehicleFittings.hatch. |
| 11 | Handrails and grab handles | 10 | 11 | Extend current rails and pulls; preserve optimized marine rail meshes. |
| 12 | Sight heads and panoramic sights | 9 | 8 | Armoured head, bezelled windows and visor; lofted or cylindrical heads stay authored. |
| 13 | Machine guns | 8 | 10 | Receiver-to-muzzle construction with feed and grips; DShK-style finned barrels may stay authored. |
| 14 | Bumpers and bumper end caps | 8 | 8 | Section, end treatment, attachment points and tow cutouts; preserve vehicle width. |
| 15 | Turret mantlets and gun cradles | 8 | 8 | Pivot-relative shrouds and supports; retain weapon sockets and recoil parents. |
| 16 | Automatic cannon | 7 | 8 | Breech-to-muzzle sleeve, tube and brake; returns the caller's muzzle. |
| 17 | Engine nacelles and cowling assemblies | 7 | 5 | Station loft plus service splits and mounts; aircraft silhouettes remain distinct. |
| 18 | Radar dishes and radomes | 6 | 7 | Separate dish and dome styles with pedestals; retain rotating parents. |
| 19 | Rotary barrel clusters | 6 | 4 | Barrel ring, clamps and bores along any axis; housings and motors stay authored. |
| 20 | Saddle fuel tanks | 6 | 4 | Round or box tanks on the frame rail; aircraft drop tanks are a different store. |
| 21 | Cockpit dashboards and instrument consoles | 4 | 4 | Console profiles and instrument placements; keep cockpit layouts authored. |
| 22 | Missile launch tubes | 4 | 4 | Tube, collars and covers; box launchers with tube mouths are a separate design. |
| 23 | Towing pintles and hitches | 4 | 4 | Mounting plate, jaws/pin or ball; recovery shackles are a separate shared part. |
| 24 | Cargo sideboards and tailgates | 3 | 3 | Panel runs, posts, hinges and latch placement on authored bed bounds. |
| 25 | Dome and anti-collision lights | 3 | 3 | Round lens on a base; box lamps and light bars stay authored. |
| 26 | Hose and tow-cable routes | 3 | 3 | Use supported cable routes; coils and wound drums need distinct construction. |
| 27 | Rolled tarps and bedrolls | 2 | 3 | Rolled canvas with straps; draped covers use VehicleCloth.load_cover. |
| 28 | Coaxial machine-gun ports | 2 | 2 | Port sleeve, barrel and flash hider; the caller keeps the muzzle marker. |
| 29 | Marine propellers and rudders | 2 | 2 | Separate propeller, steering surface and waterjet families; aircraft propellers differ. |
| 30 | Vehicle cranes and hoists | 2 | 2 | Boom sections, pivot joints and cable routing; vehicle layouts and movement stay local. |
| 31 | Aircraft pitot and probe fittings | 1 | 1 | Tapered tubes, bases and authored angled paths; leave specialized refuelling systems local. |
| 32 | Fuel fillers and filler caps | 1 | 1 | Recess, neck, cap and optional tether; preserve supplied outward axis. |
| 33 | Gun receivers and breech housings | 1 | 1 | Parameterized receiver families, not one universal weapon silhouette. |
| 34 | Navigation sidelights | 1 | 1 | Red to port, green to starboard on a housing with a visor; screens stay authored. |
| 35 | Rotor masts | 1 | 1 | Shaft, bearing housing, splines and bolted collars; hubs and blades stay in VehicleRotors.main. |
| 36 | Sensor and telescoping masts | 1 | 1 | Nested sections, collars and head mounts; optical housings already exist. |
| 37 | Track drive sprockets | 1 | 1 | Toothed drive wheel with parameterized pitch, hub and rim; preserve track alignment. |

## Using the remaining candidates

The [assembly implementation review](vehicle-assembly-review.md) records migrations and supported shapes. Remaining matches are source leads: inspect the linked geometry before extending an API. Keep candidates below three compatible builder groups as inventory until another adopter is found. Mixed sections can still appear here after some of their parts migrate.

## Evidence by candidate

### Vents and grille construction

- **aa_tech, technical**: [VmCore._hilux:838](../scripts\game\vehicles\vm_core.gd#L838)
- **angara, angara_k**: [VmCsat._t14:1056](../scripts\game\vehicles\vm_csat.gd#L1056)
- **apc, btr**: [VmCore._btr80:1185](../scripts\game\vehicles\vm_core.gd#L1185)
- **assault_boat**: [VmBoat._outboard:416](../scripts\game\vehicles\vm_boat.gd#L416)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:793](../scripts\game\vehicles\vm_gunship.gd#L793)
- **bobcat**: [VmNato._namer_hull:1055](../scripts\game\vehicles\vm_nato.gd#L1055)
- **cheetah**: [VmNato._namer_hull:1055](../scripts\game\vehicles\vm_nato.gd#L1055)
- **fia_truck, fia_truck_box**: [VmCiv._truck:696](../scripts\game\vehicles\vm_civ.gd#L696)
- **futura**: [VmCsat._t100:821](../scripts\game\vehicles\vm_csat.gd#L821); [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826); [VmCsat._futura:935](../scripts\game\vehicles\vm_csat.gd#L935)
- **gorgon**: [VmIndep._gorgon:712](../scripts\game\vehicles\vm_indep.gd#L712)
- **greyhawk**: [VmPlane._greyhawk:1141](../scripts\game\vehicles\vm_plane.gd#L1141)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1083](../scripts\game\vehicles\vm_civ.gd#L1083)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1488](../scripts\game\vehicles\vm_nato.gd#L1488)
- **humvee**: [VmCore._humvee:993](../scripts\game\vehicles\vm_core.gd#L993); [VmCore._humvee:1001](../scripts\game\vehicles\vm_core.gd#L1001)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:290](../scripts\game\vehicles\vm_nato.gd#L290)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:247](../scripts\game\vehicles\vm_csat.gd#L247); [VmCsat._ifrit:255](../scripts\game\vehicles\vm_csat.gd#L255)
- **ifv**: [VmCore._bradley:1265](../scripts\game\vehicles\vm_core.gd#L1265)
- **jet**: [VmFighter._f16:739](../scripts\game\vehicles\vm_fighter.gd#L739); [VmFighter._f16:767](../scripts\game\vehicles\vm_fighter.gd#L767)
- **kuma**: [VmIndep._kuma:478](../scripts\game\vehicles\vm_indep.gd#L478)
- **m35**: [VmCore._truck:1647](../scripts\game\vehicles\vm_core.gd#L1647)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:242](../scripts\game\vehicles\vm_civ.gd#L242)
- **mora**: [VmIndep._mora:369](../scripts\game\vehicles\vm_indep.gd#L369); [VmIndep._mora:386](../scripts\game\vehicles\vm_indep.gd#L386)
- **motorboat**: [VmBoat._outboard:416](../scripts\game\vehicles\vm_boat.gd#L416)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:575](../scripts\game\vehicles\vm_indep.gd#L575)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:242](../scripts\game\vehicles\vm_civ.gd#L242); [VmCiv._offroad:309](../scripts\game\vehicles\vm_civ.gd#L309); [VmCiv._offroad:355](../scripts\game\vehicles\vm_civ.gd#L355)
- **old_tank**: [VmCore._t55:620](../scripts\game\vehicles\vm_core.gd#L620); [VmCore._t55:633](../scripts\game\vehicles\vm_core.gd#L633); [VmCore._t55:696](../scripts\game\vehicles\vm_core.gd#L696)
- **panther**: [VmNato._namer_hull:1055](../scripts\game\vehicles\vm_nato.gd#L1055)
- **patrol_ship**: [VmShips._vent:418](../scripts\game\vehicles\vm_ships.gd#L418); [VmShips._patrol_ship:864](../scripts\game\vehicles\vm_ships.gd#L864)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:383](../scripts\game\vehicles\vm_csat.gd#L383)
- **rhib**: [VmBoat._outboard:416](../scripts\game\vehicles\vm_boat.gd#L416)
- **rhino, rhino_up**: [VmNato._rhino:643](../scripts\game\vehicles\vm_nato.gd#L643)
- **sandstorm**: [VmNato._mk_hull:778](../scripts\game\vehicles\vm_nato.gd#L778); [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **scorcher**: [VmNato._mk_hull:778](../scripts\game\vehicles\vm_nato.gd#L778); [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **sdv**: [VmBoat._sdv:862](../scripts\game\vehicles\vm_boat.gd#L862)
- **slammer, slammer_up**: [VmNato._mk_hull:778](../scripts\game\vehicles\vm_nato.gd#L778); [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **sochor**: [VmCsat._t100:821](../scripts\game\vehicles\vm_csat.gd#L821); [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826); [VmCsat._sochor:961](../scripts\game\vehicles\vm_csat.gd#L961)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:241](../scripts\game\vehicles\vm_indep.gd#L241)
- **tank**: [VmCore._abrams:364](../scripts\game\vehicles\vm_core.gd#L364)
- **taru**: [VmHeli._taru:1293](../scripts\game\vehicles\vm_heli.gd#L1293)
- **tractor**: [VmCiv._tractor:1347](../scripts\game\vehicles\vm_civ.gd#L1347); [VmCiv._tractor:1355](../scripts\game\vehicles\vm_civ.gd#L1355)
- **varsuk**: [VmCsat._t100:821](../scripts\game\vehicles\vm_csat.gd#L821); [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826)
- **water_scooter**: [VmBoat._scooter:1180](../scripts\game\vehicles\vm_boat.gd#L1180)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_box:984](../scripts\game\vehicles\vm_indep.gd#L984); [VmIndep._zamak_fuel:1083](../scripts\game\vehicles\vm_indep.gd#L1083)

### Door/ramp construction

- **a10**: [VmAttack._a10_gear:594](../scripts\game\vehicles\vm_attack.gd#L594)
- **aa_tech, technical**: [VmCore._hilux:807](../scripts\game\vehicles\vm_core.gd#L807)
- **ac130**: [VmGunship._ac130:369](../scripts\game\vehicles\vm_gunship.gd#L369)
- **apc, btr**: [VmCore._btr80:1159](../scripts\game\vehicles\vm_core.gd#L1159)
- **blackfoot**: [VmHeli._blackfoot:789](../scripts\game\vehicles\vm_heli.gd#L789)
- **blackwasp**: [VmFighter._blackwasp:1190](../scripts\game\vehicles\vm_fighter.gd#L1190)
- **bobcat**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **caesar**: [VmPlane._caesar:818](../scripts\game\vehicles\vm_plane.gd#L818)
- **cheetah**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **fia_truck, fia_truck_box**: [VmCiv._truck_box:764](../scripts\game\vehicles\vm_civ.gd#L764)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:532](../scripts\game\vehicles\vm_heli.gd#L532); [VmHeli._ghost_hawk:538](../scripts\game\vehicles\vm_heli.gd#L538); [VmHeli._ghost_hawk:592](../scripts\game\vehicles\vm_heli.gd#L592)
- **gorgon**: [VmIndep._gorgon:728](../scripts\game\vehicles\vm_indep.gd#L728)
- **gun_trawler**: [VmShips._gun_trawler:1030](../scripts\game\vehicles\vm_ships.gd#L1030); [VmShips._gun_trawler:1143](../scripts\game\vehicles\vm_ships.gd#L1143); [VmShips._gun_trawler:1163](../scripts\game\vehicles\vm_ships.gd#L1163)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1077](../scripts\game\vehicles\vm_civ.gd#L1077)
- **heli**: [VmCore._blackhawk:1533](../scripts\game\vehicles\vm_core.gd#L1533); [VmCore._blackhawk:1542](../scripts\game\vehicles\vm_core.gd#L1542)
- **hellcat**: [VmHeli._hellcat:944](../scripts\game\vehicles\vm_heli.gd#L944)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1280](../scripts\game\vehicles\vm_nato.gd#L1280); [VmNato._hemtt_cab_detail:1331](../scripts\game\vehicles\vm_nato.gd#L1331); [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477); [VmNato._hemtt:1488](../scripts\game\vehicles\vm_nato.gd#L1488)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:423](../scripts\game\vehicles\vm_heli.gd#L423)
- **huron**: [VmHeli._huron:641](../scripts\game\vehicles\vm_heli.gd#L641); [VmHeli._huron:656](../scripts\game\vehicles\vm_heli.gd#L656); [VmHeli._huron:681](../scripts\game\vehicles\vm_heli.gd#L681)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:247](../scripts\game\vehicles\vm_csat.gd#L247); [VmCsat._ifrit:250](../scripts\game\vehicles\vm_csat.gd#L250); [VmCsat._ifrit:268](../scripts\game\vehicles\vm_csat.gd#L268)
- **ifv**: [VmCore._bradley:1350](../scripts\game\vehicles\vm_core.gd#L1350)
- **jet**: [VmFighter._f16:866](../scripts\game\vehicles\vm_fighter.gd#L866); [VmFighter._f16:885](../scripts\game\vehicles\vm_fighter.gd#L885)
- **kajman**: [VmHeli._kajman:1068](../scripts\game\vehicles\vm_heli.gd#L1068)
- **m35**: [VmCore._truck:1654](../scripts\game\vehicles\vm_core.gd#L1654)
- **marshall**: [VmNato._marshall:555](../scripts\game\vehicles\vm_nato.gd#L555); [VmNato._marshall:570](../scripts\game\vehicles\vm_nato.gd#L570)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:520](../scripts\game\vehicles\vm_civ.gd#L520); [VmCiv._mb_top:605](../scripts\game\vehicles\vm_civ.gd#L605)
- **mohawk**: [VmHeli._mohawk:851](../scripts\game\vehicles\vm_heli.gd#L851); [VmHeli._mohawk:858](../scripts\game\vehicles\vm_heli.gd#L858); [VmHeli._mohawk:878](../scripts\game\vehicles\vm_heli.gd#L878)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:333](../scripts\game\vehicles\vm_civ.gd#L333)
- **orca, orca_armed**: [VmHeli._orca:1172](../scripts\game\vehicles\vm_heli.gd#L1172); [VmHeli._orca:1177](../scripts\game\vehicles\vm_heli.gd#L1177)
- **panther**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **patrol_ship**: [VmShips._patrol_ship:715](../scripts\game\vehicles\vm_ships.gd#L715)
- **scorcher**: [VmNato._scorcher:947](../scripts\game\vehicles\vm_nato.gd#L947)
- **sentinel**: [VmPlane._sentinel:1206](../scripts\game\vehicles\vm_plane.gd#L1206); [VmPlane._sentinel:1214](../scripts\game\vehicles\vm_plane.gd#L1214)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:970](../scripts\game\vehicles\vm_boat.gd#L970)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:207](../scripts\game\vehicles\vm_indep.gd#L207)
- **suv**: [VmCiv._suv:1212](../scripts\game\vehicles\vm_civ.gd#L1212)
- **tank**: [VmCore._abrams:364](../scripts\game\vehicles\vm_core.gd#L364); [VmCore._abrams:421](../scripts\game\vehicles\vm_core.gd#L421)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:838](../scripts\game\vehicles\vm_civ.gd#L838); [VmCiv._van:849](../scripts\game\vehicles\vm_civ.gd#L849); [VmCiv._van_services:945](../scripts\game\vehicles\vm_civ.gd#L945)
- **wipeout**: [VmAttack._wip_cockpit:879](../scripts\game\vehicles\vm_attack.gd#L879); [VmAttack._wip_gear:1059](../scripts\game\vehicles\vm_attack.gd#L1059)
- **xian**: [VmPlane._xian:1472](../scripts\game\vehicles\vm_plane.gd#L1472)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:854](../scripts\game\vehicles\vm_indep.gd#L854); [VmIndep._zamak_repair:1000](../scripts\game\vehicles\vm_indep.gd#L1000); [VmIndep._zamak_medical:1049](../scripts\game\vehicles\vm_indep.gd#L1049); [VmIndep._zamak_fuel:1083](../scripts\game\vehicles\vm_indep.gd#L1083)

### Boarding steps and ladders

- **aa_tech, technical**: [VmCore._hilux:765](../scripts\game\vehicles\vm_core.gd#L765); [VmCore._hilux:819](../scripts\game\vehicles\vm_core.gd#L819); [VmCore._hilux:855](../scripts\game\vehicles\vm_core.gd#L855)
- **apc, btr**: [VmCore._btr80:1174](../scripts\game\vehicles\vm_core.gd#L1174)
- **blackfoot**: [VmHeli._blackfoot:752](../scripts\game\vehicles\vm_heli.gd#L752)
- **bobcat**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **cheetah**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **fia_truck, fia_truck_box**: [VmCiv._truck:651](../scripts\game\vehicles\vm_civ.gd#L651); [VmCiv._truck:672](../scripts\game\vehicles\vm_civ.gd#L672)
- **gorgon**: [VmIndep._gorgon:728](../scripts\game\vehicles\vm_indep.gd#L728)
- **gryphon**: [VmPlane._gryphon:627](../scripts\game\vehicles\vm_plane.gd#L627)
- **gun_trawler**: [VmShips._gun_trawler:1030](../scripts\game\vehicles\vm_ships.gd#L1030)
- **gunship**: [VmCore._apache:1412](../scripts\game\vehicles\vm_core.gd#L1412)
- **heli**: [VmCore._blackhawk:1542](../scripts\game\vehicles\vm_core.gd#L1542)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1280](../scripts\game\vehicles\vm_nato.gd#L1280); [VmNato._hemtt_cab_detail:1331](../scripts\game\vehicles\vm_nato.gd#L1331); [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477); [VmNato._hemtt:1488](../scripts\game\vehicles\vm_nato.gd#L1488)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:299](../scripts\game\vehicles\vm_csat.gd#L299)
- **kajman**: [VmHeli._kajman:1064](../scripts\game\vehicles\vm_heli.gd#L1064)
- **marshall**: [VmNato._marshall:570](../scripts\game\vehicles\vm_nato.gd#L570)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:275](../scripts\game\vehicles\vm_civ.gd#L275); [VmCiv._offroad:372](../scripts\game\vehicles\vm_civ.gd#L372)
- **panther**: [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)
- **patrol_ship**: [VmShips._patrol_ship:715](../scripts\game\vehicles\vm_ships.gd#L715)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:367](../scripts\game\vehicles\vm_csat.gd#L367)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1071](../scripts\game\vehicles\vm_boat.gd#L1071)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:173](../scripts\game\vehicles\vm_indep.gd#L173); [VmIndep._strider:207](../scripts\game\vehicles\vm_indep.gd#L207)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1305](../scripts\game\vehicles\vm_csat.gd#L1305)
- **tractor**: [VmCiv._tractor:1417](../scripts\game\vehicles\vm_civ.gd#L1417)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:861](../scripts\game\vehicles\vm_civ.gd#L861); [VmCiv._van_services:937](../scripts\game\vehicles\vm_civ.gd#L937)
- **water_scooter**: [VmBoat._scooter:1139](../scripts\game\vehicles\vm_boat.gd#L1139); [VmBoat._scooter:1156](../scripts\game\vehicles\vm_boat.gd#L1156)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1008](../scripts\game\vehicles\vm_indep.gd#L1008); [VmIndep._zamak_medical:1049](../scripts\game\vehicles\vm_indep.gd#L1049); [VmIndep._zamak_fuel:1083](../scripts\game\vehicles\vm_indep.gd#L1083)

### Exhaust construction

- **a10**: [VmAttack._a10_engines:499](../scripts\game\vehicles\vm_attack.gd#L499)
- **aa_tech, technical**: [VmCore._hilux:765](../scripts\game\vehicles\vm_core.gd#L765)
- **angara, angara_k**: [VmCsat._t14:1056](../scripts\game\vehicles\vm_csat.gd#L1056)
- **apc, btr**: [VmCore._btr80:1159](../scripts\game\vehicles\vm_core.gd#L1159)
- **blackfoot**: [VmHeli._blackfoot:759](../scripts\game\vehicles\vm_heli.gd#L759)
- **caesar**: [VmPlane._caesar:822](../scripts\game\vehicles\vm_plane.gd#L822)
- **futura**: [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:551](../scripts\game\vehicles\vm_heli.gd#L551)
- **gorgon**: [VmIndep._gorgon:712](../scripts\game\vehicles\vm_indep.gd#L712)
- **greyhawk**: [VmPlane._greyhawk:1141](../scripts\game\vehicles\vm_plane.gd#L1141)
- **heli**: [VmCore._blackhawk:1557](../scripts\game\vehicles\vm_core.gd#L1557)
- **ifv**: [VmCore._bradley:1279](../scripts\game\vehicles\vm_core.gd#L1279)
- **kajman**: [VmHeli._kajman:1081](../scripts\game\vehicles\vm_heli.gd#L1081)
- **kart**: [VmCiv._kart:1308](../scripts\game\vehicles\vm_civ.gd#L1308)
- **kuma**: [VmIndep._kuma:486](../scripts\game\vehicles\vm_indep.gd#L486)
- **marid**: [VmCsat._marid:576](../scripts\game\vehicles\vm_csat.gd#L576)
- **old_tank**: [VmCore._t55:620](../scripts\game\vehicles\vm_core.gd#L620)
- **patrol_ship**: [VmShips._patrol_ship:653](../scripts\game\vehicles\vm_ships.gd#L653); [VmShips._patrol_ship:890](../scripts\game\vehicles\vm_ships.gd#L890)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:381](../scripts\game\vehicles\vm_csat.gd#L381)
- **sandstorm**: [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **scorcher**: [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **slammer, slammer_up**: [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- **sochor**: [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826)
- **tank**: [VmCore._abrams:374](../scripts\game\vehicles\vm_core.gd#L374)
- **varsuk**: [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:875](../scripts\game\vehicles\vm_indep.gd#L875)

### Window and canopy construction

- **a10**: [VmAttack._sniper:666](../scripts\game\vehicles\vm_attack.gd#L666)
- **bobcat**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:592](../scripts\game\vehicles\vm_heli.gd#L592)
- **greyhawk**: [VmPlane._greyhawk:1128](../scripts\game\vehicles\vm_plane.gd#L1128)
- **gunship**: [VmCore._apache:1412](../scripts\game\vehicles\vm_core.gd#L1412); [VmHeli._canopy:1008](../scripts\game\vehicles\vm_heli.gd#L1008)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1278](../scripts\game\vehicles\vm_nato.gd#L1278)
- **humvee**: [VmCore._humvee:1062](../scripts\game\vehicles\vm_core.gd#L1062)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259); [VmNato._hunter:312](../scripts\game\vehicles\vm_nato.gd#L312); [VmNato._hunter:318](../scripts\game\vehicles\vm_nato.gd#L318); [VmNato._hunter:343](../scripts\game\vehicles\vm_nato.gd#L343)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:238](../scripts\game\vehicles\vm_csat.gd#L238)
- **kajman**: [VmHeli._canopy:1008](../scripts\game\vehicles\vm_heli.gd#L1008)
- **kuma**: [VmIndep._rcws:291](../scripts\game\vehicles\vm_indep.gd#L291)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:571](../scripts\game\vehicles\vm_civ.gd#L571)
- **motorboat**: [VmBoat._motorboat:586](../scripts\game\vehicles\vm_boat.gd#L586)
- **panther**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **patrol_ship**: [VmShips._mk38:490](../scripts\game\vehicles\vm_ships.gd#L490); [VmShips._patrol_ship:698](../scripts\game\vehicles\vm_ships.gd#L698)
- **rhino, rhino_up**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **scorcher**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **sdv**: [VmBoat._sdv:857](../scripts\game\vehicles\vm_boat.gd#L857)
- **sentinel**: [VmPlane._sentinel:1206](../scripts\game\vehicles\vm_plane.gd#L1206)
- **slammer, slammer_up**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:976](../scripts\game\vehicles\vm_boat.gd#L976)
- **stomper**: [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:173](../scripts\game\vehicles\vm_indep.gd#L173); [VmIndep._strider:187](../scripts\game\vehicles\vm_indep.gd#L187); [VmIndep._rcws:291](../scripts\game\vehicles\vm_indep.gd#L291)
- **wipeout**: [VmAttack._wip_cockpit:860](../scripts\game\vehicles\vm_attack.gd#L860); [VmAttack._wip_gun:901](../scripts\game\vehicles\vm_attack.gd#L901)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:854](../scripts\game\vehicles\vm_indep.gd#L854)

### Seat and bench construction

- **aa_tech, technical**: [VmCore._zu23:945](../scripts\game\vehicles\vm_core.gd#L945)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:739](../scripts\game\vehicles\vm_civ.gd#L739)
- **gun_trawler**: [VmShips._zu23:566](../scripts\game\vehicles\vm_ships.gd#L566)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1414](../scripts\game\vehicles\vm_nato.gd#L1414); [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:439](../scripts\game\vehicles\vm_heli.gd#L439); [VmHeli._little_bird:471](../scripts\game\vehicles\vm_heli.gd#L471)
- **kart**: [VmCiv._kart:1299](../scripts\game\vehicles\vm_civ.gd#L1299); [VmCiv._kart:1308](../scripts\game\vehicles\vm_civ.gd#L1308)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:571](../scripts\game\vehicles\vm_civ.gd#L571)
- **motorboat**: [VmBoat._motorboat:582](../scripts\game\vehicles\vm_boat.gd#L582); [VmBoat._motorboat:606](../scripts\game\vehicles\vm_boat.gd#L606)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:424](../scripts\game\vehicles\vm_nato.gd#L424)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:363](../scripts\game\vehicles\vm_csat.gd#L363)
- **rhib**: [VmBoat._rhib:781](../scripts\game\vehicles\vm_boat.gd#L781)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1010](../scripts\game\vehicles\vm_boat.gd#L1010)
- **tractor**: [VmCiv._tractor:1406](../scripts\game\vehicles\vm_civ.gd#L1406)
- **water_scooter**: [VmBoat._scooter:1180](../scripts\game\vehicles\vm_boat.gd#L1180)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_tilt:919](../scripts\game\vehicles\vm_indep.gd#L919)

### Closed bins and toolboxes

- **angara, angara_k**: [VmCsat._t14:1056](../scripts\game\vehicles\vm_csat.gd#L1056)
- **apc, btr**: [VmCore._btr80:1159](../scripts\game\vehicles\vm_core.gd#L1159)
- **gun_trawler**: [VmShips._gun_trawler:1058](../scripts\game\vehicles\vm_ships.gd#L1058)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1470](../scripts\game\vehicles\vm_nato.gd#L1470)
- **ifv**: [VmCore._bradley:1307](../scripts\game\vehicles\vm_core.gd#L1307)
- **marid**: [VmCsat._marid:576](../scripts\game\vehicles\vm_csat.gd#L576)
- **marshall**: [VmNato._marshall:555](../scripts\game\vehicles\vm_nato.gd#L555)
- **mora**: [VmIndep._mora:390](../scripts\game\vehicles\vm_indep.gd#L390)
- **old_tank**: [VmCore._t55:606](../scripts\game\vehicles\vm_core.gd#L606)
- **rhib**: [VmBoat._rhib:781](../scripts\game\vehicles\vm_boat.gd#L781); [VmBoat._rhib:788](../scripts\game\vehicles\vm_boat.gd#L788)
- **rhino, rhino_up**: [VmNato._rhino:643](../scripts\game\vehicles\vm_nato.gd#L643)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1230](../scripts\game\vehicles\vm_csat.gd#L1230)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1000](../scripts\game\vehicles\vm_indep.gd#L1000)

### Fenders and mudguards

- **futura**: [VmCsat._t100:798](../scripts\game\vehicles\vm_csat.gd#L798); [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:600](../scripts\game\vehicles\vm_heli.gd#L600)
- **gun_trawler**: [VmShips._gun_trawler:994](../scripts\game\vehicles\vm_ships.gd#L994)
- **heli**: [VmCore._blackhawk:1582](../scripts\game\vehicles\vm_core.gd#L1582)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:290](../scripts\game\vehicles\vm_nato.gd#L290)
- **motorboat**: [VmBoat._motorboat:652](../scripts\game\vehicles\vm_boat.gd#L652)
- **old_tank**: [VmCore._t55:606](../scripts\game\vehicles\vm_core.gd#L606); [VmCore._t55:620](../scripts\game\vehicles\vm_core.gd#L620)
- **patrol_ship**: [VmShips._patrol_ship:864](../scripts\game\vehicles\vm_ships.gd#L864)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:397](../scripts\game\vehicles\vm_nato.gd#L397)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:367](../scripts\game\vehicles\vm_csat.gd#L367)
- **sochor**: [VmCsat._t100:798](../scripts\game\vehicles\vm_csat.gd#L798); [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)
- **tank**: [VmCore._abrams:333](../scripts\game\vehicles\vm_core.gd#L333)
- **varsuk**: [VmCsat._t100:798](../scripts\game\vehicles\vm_csat.gd#L798); [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)

### Commander's cupolas and vision blocks

- **apc, btr**: [VmCore._btr80:1211](../scripts\game\vehicles\vm_core.gd#L1211)
- **gorgon**: [VmIndep._gorgon:728](../scripts\game\vehicles\vm_indep.gd#L728)
- **kamysh**: [VmCsat._stalker:676](../scripts\game\vehicles\vm_csat.gd#L676)
- **marid**: [VmCsat._marid:576](../scripts\game\vehicles\vm_csat.gd#L576)
- **marshall**: [VmNato._marshall:555](../scripts\game\vehicles\vm_nato.gd#L555)
- **mora**: [VmIndep._mora:369](../scripts\game\vehicles\vm_indep.gd#L369); [VmIndep._mora:390](../scripts\game\vehicles\vm_indep.gd#L390)
- **old_tank**: [VmCore._t55:733](../scripts\game\vehicles\vm_core.gd#L733)
- **sandstorm**: [VmNato._mk_hull:831](../scripts\game\vehicles\vm_nato.gd#L831)
- **scorcher**: [VmNato._mk_hull:831](../scripts\game\vehicles\vm_nato.gd#L831); [VmNato._scorcher:947](../scripts\game\vehicles\vm_nato.gd#L947)
- **slammer, slammer_up**: [VmNato._mk_hull:831](../scripts\game\vehicles\vm_nato.gd#L831)
- **tigris**: [VmCsat._stalker:676](../scripts\game\vehicles\vm_csat.gd#L676)

### Rectangular hatch lids

- **apc, btr**: [VmCore._btr80:1211](../scripts\game\vehicles\vm_core.gd#L1211)
- **falcon**: [VmHeli._falcon:1364](../scripts\game\vehicles\vm_heli.gd#L1364)
- **gun_trawler**: [VmShips._gun_trawler:1078](../scripts\game\vehicles\vm_ships.gd#L1078)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1031](../scripts\game\vehicles\vm_civ.gd#L1031); [VmCiv._hatch_sport:1105](../scripts\game\vehicles\vm_civ.gd#L1105); [VmCiv._hatch_sport:1111](../scripts\game\vehicles\vm_civ.gd#L1111)
- **mora**: [VmIndep._mora:405](../scripts\game\vehicles\vm_indep.gd#L405); [VmIndep._mora:417](../scripts\game\vehicles\vm_indep.gd#L417)
- **patrol_ship**: [VmShips._patrol_ship:795](../scripts\game\vehicles\vm_ships.gd#L795); [VmShips._patrol_ship:864](../scripts\game\vehicles\vm_ships.gd#L864)
- **rhib**: [VmBoat._rhib:788](../scripts\game\vehicles\vm_boat.gd#L788)
- **sdv**: [VmBoat._sdv:820](../scripts\game\vehicles\vm_boat.gd#L820); [VmBoat._sdv:839](../scripts\game\vehicles\vm_boat.gd#L839)
- **tank**: [VmCore._abrams:321](../scripts\game\vehicles\vm_core.gd#L321)
- **water_scooter**: [VmBoat._scooter:1191](../scripts\game\vehicles\vm_boat.gd#L1191)

### Handrails and grab handles

- **assault_boat**: [VmBoat._zodiac:510](../scripts\game\vehicles\vm_boat.gd#L510)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:561](../scripts\game\vehicles\vm_heli.gd#L561)
- **gun_trawler**: [VmShips._gun_trawler:1030](../scripts\game\vehicles\vm_ships.gd#L1030)
- **ifv**: [VmCore._bradley:1285](../scripts\game\vehicles\vm_core.gd#L1285)
- **motorboat**: [VmBoat._motorboat:590](../scripts\game\vehicles\vm_boat.gd#L590); [VmBoat._motorboat:615](../scripts\game\vehicles\vm_boat.gd#L615)
- **old_tank**: [VmCore._t55:715](../scripts\game\vehicles\vm_core.gd#L715)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:984](../scripts\game\vehicles\vm_boat.gd#L984)
- **tank**: [VmCore._abrams:356](../scripts\game\vehicles\vm_core.gd#L356)
- **water_scooter**: [VmBoat._scooter:1156](../scripts\game\vehicles\vm_boat.gd#L1156)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:854](../scripts\game\vehicles\vm_indep.gd#L854)

### Sight heads and panoramic sights

- **gun_trawler**: [VmShips._zu23:560](../scripts\game\vehicles\vm_ships.gd#L560)
- **marshall**: [VmNato._marshall:581](../scripts\game\vehicles\vm_nato.gd#L581)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:249](../scripts\game\vehicles\vm_civ.gd#L249)
- **mora**: [VmIndep._mora:405](../scripts\game\vehicles\vm_indep.gd#L405)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:249](../scripts\game\vehicles\vm_civ.gd#L249)
- **patrol_ship**: [VmShips._mk38:490](../scripts\game\vehicles\vm_ships.gd#L490)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:447](../scripts\game\vehicles\vm_csat.gd#L447)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1040](../scripts\game\vehicles\vm_boat.gd#L1040)
- **tank**: [VmCore._abrams:421](../scripts\game\vehicles\vm_core.gd#L421)

### Machine guns

- **aa_tech, technical**: [VmCore._dshk:501](../scripts\game\vehicles\vm_core.gd#L501); [VmCore._hilux_dshk:878](../scripts\game\vehicles\vm_core.gd#L878)
- **apc, btr**: [VmCore._btr80:1197](../scripts\game\vehicles\vm_core.gd#L1197)
- **gun_trawler**: [VmShips._dshk:583](../scripts\game\vehicles\vm_ships.gd#L583); [VmShips._gun_trawler:1065](../scripts\game\vehicles\vm_ships.gd#L1065)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._off_hmg:389](../scripts\game\vehicles\vm_civ.gd#L389)
- **old_tank**: [VmCore._dshk:501](../scripts\game\vehicles\vm_core.gd#L501); [VmCore._t55:700](../scripts\game\vehicles\vm_core.gd#L700)
- **scorcher**: [VmNato._scorcher:947](../scripts\game\vehicles\vm_nato.gd#L947)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1040](../scripts\game\vehicles\vm_boat.gd#L1040)
- **tank**: [VmCore._abrams:406](../scripts\game\vehicles\vm_core.gd#L406)

### Bumpers and bumper end caps

- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:650](../scripts\game\vehicle_models.gd#L650)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:247](../scripts\game\vehicles\vm_csat.gd#L247)
- **kart**: [VmCiv._kart:1316](../scripts\game\vehicles\vm_civ.gd#L1316)
- **m35**: [VmCore._truck:1636](../scripts\game\vehicles\vm_core.gd#L1636)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:408](../scripts\game\vehicles\vm_nato.gd#L408)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._typhoon:1144](../scripts\game\vehicles\vm_csat.gd#L1144)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:865](../scripts\game\vehicles\vm_civ.gd#L865)
- **water_scooter**: [VmBoat._scooter:1111](../scripts\game\vehicles\vm_boat.gd#L1111)

### Turret mantlets and gun cradles

- **aa_tech, technical**: [VmCore._hilux_dshk:892](../scripts\game\vehicles\vm_core.gd#L892); [VmCore._zu23:931](../scripts\game\vehicles\vm_core.gd#L931)
- **ac130**: [VmGunship._ac130_guns:583](../scripts\game\vehicles\vm_gunship.gd#L583)
- **gun_trawler**: [VmShips._zu23:560](../scripts\game\vehicles\vm_ships.gd#L560)
- **kuma**: [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)
- **old_tank**: [VmCore._t55:675](../scripts\game\vehicles\vm_core.gd#L675)
- **patrol_ship**: [VmShips._mk38:480](../scripts\game\vehicles\vm_ships.gd#L480)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:447](../scripts\game\vehicles\vm_csat.gd#L447)
- **strider, strider_gmg, strider_hmg**: [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)

### Automatic cannon

- **ac130**: [VmGunship._ac130_guns:561](../scripts\game\vehicles\vm_gunship.gd#L561); [VmGunship._ac130_guns:569](../scripts\game\vehicles\vm_gunship.gd#L569)
- **blackfish, blackfish_armed**: [VmGunship._bf_guns:823](../scripts\game\vehicles\vm_gunship.gd#L823)
- **blackfoot**: [VmHeli._blackfoot:798](../scripts\game\vehicles\vm_heli.gd#L798)
- **kajman**: [VmHeli._kajman:1128](../scripts\game\vehicles\vm_heli.gd#L1128)
- **marid**: [VmCsat._marid:612](../scripts\game\vehicles\vm_csat.gd#L612)
- **marshall**: [VmNato._marshall:581](../scripts\game\vehicles\vm_nato.gd#L581)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1040](../scripts\game\vehicles\vm_boat.gd#L1040)

### Engine nacelles and cowling assemblies

- **a10**: [VmAttack._a10_engines:502](../scripts\game\vehicles\vm_attack.gd#L502)
- **ac130**: [VmGunship._t56:538](../scripts\game\vehicles\vm_gunship.gd#L538)
- **assault_boat**: [VmBoat._outboard:422](../scripts\game\vehicles\vm_boat.gd#L422)
- **falcon**: [VmHeli._falcon:1369](../scripts\game\vehicles\vm_heli.gd#L1369)
- **motorboat**: [VmBoat._outboard:422](../scripts\game\vehicles\vm_boat.gd#L422)
- **rhib**: [VmBoat._outboard:422](../scripts\game\vehicles\vm_boat.gd#L422)
- **wipeout**: [VmAttack._wip_engines:993](../scripts\game\vehicles\vm_attack.gd#L993)

### Radar dishes and radomes

- **a10**: [VmAttack._ecm_pod:681](../scripts\game\vehicles\vm_attack.gd#L681)
- **cheetah**: [VmNato._cheetah:1198](../scripts\game\vehicles\vm_nato.gd#L1198); [VmNato._cheetah:1203](../scripts\game\vehicles\vm_nato.gd#L1203)
- **gunship**: [VmCore._apache:1486](../scripts\game\vehicles\vm_core.gd#L1486)
- **heli**: [VmCore._blackhawk:1549](../scripts\game\vehicles\vm_core.gd#L1549)
- **tigris**: [VmCsat._tigris:747](../scripts\game\vehicles\vm_csat.gd#L747)
- **varsuk**: [VmCsat._varsuk:888](../scripts\game\vehicles\vm_csat.gd#L888)

### Rotary barrel clusters

- **ac130**: [VmGunship._ac130_guns:561](../scripts\game\vehicles\vm_gunship.gd#L561)
- **blackfoot**: [VmHeli._blackfoot:798](../scripts\game\vehicles\vm_heli.gd#L798)
- **ghosthawk, ghosthawk_stub**: [VmHeli._minigun:356](../scripts\game\vehicles\vm_heli.gd#L356)
- **hellcat**: [VmHeli._minigun:356](../scripts\game\vehicles\vm_heli.gd#L356)
- **hummingbird, m900, pawnee**: [VmHeli._minigun:356](../scripts\game\vehicles\vm_heli.gd#L356); [VmHeli._little_bird:482](../scripts\game\vehicles\vm_heli.gd#L482)
- **orca, orca_armed**: [VmHeli._minigun:356](../scripts\game\vehicles\vm_heli.gd#L356)

### Saddle fuel tanks

- **assault_boat**: [VmBoat._zodiac:493](../scripts\game\vehicles\vm_boat.gd#L493)
- **futura**: [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)
- **heli**: [VmCore._blackhawk:1582](../scripts\game\vehicles\vm_core.gd#L1582)
- **old_tank**: [VmCore._t55:606](../scripts\game\vehicles\vm_core.gd#L606)
- **sochor**: [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)
- **varsuk**: [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)

### Cockpit dashboards and instrument consoles

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1257](../scripts\game\vehicles\vm_nato.gd#L1257)
- **motorboat**: [VmBoat._motorboat:586](../scripts\game\vehicles\vm_boat.gd#L586)
- **quadbike**: [VmCiv._quad:976](../scripts\game\vehicles\vm_civ.gd#L976)
- **rhib**: [VmBoat._rhib:731](../scripts\game\vehicles\vm_boat.gd#L731)

### Missile launch tubes

- **angara, angara_k**: [VmCsat._angara:1089](../scripts\game\vehicles\vm_csat.gd#L1089)
- **gorgon**: [VmIndep._gorgon:737](../scripts\game\vehicles\vm_indep.gd#L737)
- **kajman**: [VmHeli._atgm_tubes:1022](../scripts\game\vehicles\vm_heli.gd#L1022)
- **kamysh**: [VmCsat._kamysh:715](../scripts\game\vehicles\vm_csat.gd#L715)

### Towing pintles and hitches

- **aa_tech, technical**: [VmCore._hilux:855](../scripts\game\vehicles\vm_core.gd#L855)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1265](../scripts\game\vehicles\vm_nato.gd#L1265)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:372](../scripts\game\vehicles\vm_civ.gd#L372)
- **quadbike**: [VmCiv._quad:1013](../scripts\game\vehicles\vm_civ.gd#L1013)

### Air cleaners, filters and snorkels

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1304](../scripts\game\vehicles\vm_nato.gd#L1304)
- **kajman**: [VmHeli._kajman:1081](../scripts\game\vehicles\vm_heli.gd#L1081)
- **old_tank**: [VmCore._t55:715](../scripts\game\vehicles\vm_core.gd#L715)

### Cargo sideboards and tailgates

- **aa_tech, technical**: [VmCore._hilux:788](../scripts\game\vehicles\vm_core.gd#L788)
- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:662](../scripts\game\vehicle_models.gd#L662)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:725](../scripts\game\vehicles\vm_civ.gd#L725)

### Dome and anti-collision lights

- **a10**: [VmAttack._a10_details:689](../scripts\game\vehicles\vm_attack.gd#L689)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._off_repair:467](../scripts\game\vehicles\vm_civ.gd#L467)
- **van_ambulance, van_services, van_transport**: [VmCiv._van_services:942](../scripts\game\vehicles\vm_civ.gd#L942)

### Hose and tow-cable routes

- **apc, btr**: [VmCore._btr80:1159](../scripts\game\vehicles\vm_core.gd#L1159)
- **m35**: [VmCore._truck:1673](../scripts\game\vehicles\vm_core.gd#L1673)
- **patrol_ship**: [VmShips._patrol_ship:735](../scripts\game\vehicles\vm_ships.gd#L735)

### Ship liferafts and life rings

- **gun_trawler**: [VmShips._lifering:388](../scripts\game\vehicles\vm_ships.gd#L388); [VmShips._liferaft:400](../scripts\game\vehicles\vm_ships.gd#L400); [VmShips._gun_trawler:1058](../scripts\game\vehicles\vm_ships.gd#L1058)
- **patrol_ship**: [VmShips._lifering:388](../scripts\game\vehicles\vm_ships.gd#L388); [VmShips._liferaft:400](../scripts\game\vehicles\vm_ships.gd#L400); [VmShips._patrol_ship:735](../scripts\game\vehicles\vm_ships.gd#L735); [VmShips._patrol_ship:747](../scripts\game\vehicles\vm_ships.gd#L747)

### Rolled tarps and bedrolls

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_load_detail:1360](../scripts\game\vehicles\vm_nato.gd#L1360)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_tilt:919](../scripts\game\vehicles\vm_indep.gd#L919); [VmIndep._zamak_ammo:971](../scripts\game\vehicles\vm_indep.gd#L971)

### Coaxial machine-gun ports

- **kajman**: [VmHeli._kajman:1138](../scripts\game\vehicles\vm_heli.gd#L1138)
- **taru**: [VmHeli._taru:1335](../scripts\game\vehicles\vm_heli.gd#L1335)

### Marine propellers and rudders

- **patrol_ship**: [VmShips._patrol_ship:864](../scripts\game\vehicles\vm_ships.gd#L864)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1071](../scripts\game\vehicles\vm_boat.gd#L1071)

### Spare-wheel carriers

- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:362](../scripts\game\vehicles\vm_nato.gd#L362)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:867](../scripts\game\vehicles\vm_indep.gd#L867)

### Suspension arms and hubs

- **quadbike**: [VmCiv._quad:967](../scripts\game\vehicles\vm_civ.gd#L967)
- **stomper**: [VmNato._stomper:1571](../scripts\game\vehicles\vm_nato.gd#L1571)

### Vehicle cranes and hoists

- **huron**: [VmHeli._huron:681](../scripts\game\vehicles\vm_heli.gd#L681)
- **mohawk**: [VmHeli._mohawk:878](../scripts\game\vehicles\vm_heli.gd#L878)

### Gun shields and weapon-station armour

- **tank**: [VmCore._abrams:392](../scripts\game\vehicles\vm_core.gd#L392); [VmCore._abrams:406](../scripts\game\vehicles\vm_core.gd#L406); [VmCore._abrams:439](../scripts\game\vehicles\vm_core.gd#L439)

### Aircraft pitot and probe fittings

- **gunship**: [VmCore._apache:1423](../scripts\game\vehicles\vm_core.gd#L1423)

### External fuel drums and drum cradles

- **old_tank**: [VmCore._t55:642](../scripts\game\vehicles\vm_core.gd#L642)

### Fuel fillers and filler caps

- **water_scooter**: [VmBoat._scooter:1180](../scripts\game\vehicles\vm_boat.gd#L1180)

### Gun receivers and breech housings

- **futura**: [VmCsat._futura:921](../scripts\game\vehicles\vm_csat.gd#L921)

### Navigation sidelights

- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:835](../scripts\game\vehicles\vm_indep.gd#L835)

### Rotor masts

- **tank**: [VmCore._abrams:450](../scripts\game\vehicles\vm_core.gd#L450)

### Sensor and telescoping masts

- **stomper**: [VmNato._stomper:1592](../scripts\game\vehicles\vm_nato.gd#L1592)

### Track drive sprockets

- **tank**: [VmCore._abrams:356](../scripts\game\vehicles\vm_core.gd#L356)

