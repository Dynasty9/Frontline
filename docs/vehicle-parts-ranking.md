# Most common remaining vehicle construction

Source revision: `a4647877`. 137 model keys, 84 construction-root groups.

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
| 1 | Turret mantlets and gun cradles | 28 | 25 | Pivot-relative shrouds and supports; retain weapon sockets and recoil parents. |
| 2 | Track drive sprockets | 18 | 6 | Toothed drive wheel with parameterized pitch, hub and rim; preserve track alignment. |
| 3 | Bumpers and bumper end caps | 16 | 22 | Section, end treatment, attachment points and tow cutouts; preserve vehicle width. |
| 4 | Aircraft pitot and probe fittings | 13 | 13 | Tapered tubes, bases and authored angled paths; leave specialized refuelling systems local. |
| 5 | Radar dishes and radomes | 12 | 14 | Separate dish and dome styles with pedestals; retain rotating parents. |
| 6 | Towing pintles and hitches | 10 | 11 | Mounting plate, jaws/pin or ball; recovery shackles are a separate shared part. |
| 7 | Turret bustle baskets and open stowage racks | 9 | 8 | Open frame paths and mesh panels; closed storage boxes are already shared. |
| 8 | Engine nacelles and cowling assemblies | 8 | 6 | Station loft plus service splits and mounts; aircraft silhouettes remain distinct. |
| 9 | Light guards and protective cages | 8 | 6 | Guard outline, standoffs and mounting feet; keep lamp optics shared. |
| 10 | Vehicle cranes and hoists | 7 | 8 | Boom sections, pivot joints and cable routing; vehicle layouts and movement stay local. |
| 11 | Cockpit dashboards and instrument consoles | 7 | 7 | Console profiles and instrument placements; keep cockpit layouts authored. |
| 12 | Marine propellers and rudders | 7 | 7 | Separate propeller, steering surface and waterjet families; aircraft propellers differ. |
| 13 | Cargo sideboards and tailgates | 6 | 7 | Panel runs, posts, hinges and latch placement on authored bed bounds. |
| 14 | Sensor and telescoping masts | 6 | 7 | Nested sections, collars and head mounts; optical housings already exist. |
| 15 | Gun receivers and breech housings | 5 | 5 | Parameterized receiver families, not one universal weapon silhouette. |
| 16 | Aircraft skids | 5 | 4 | Bent runner profiles, cross-struts and shoes; wheeled landing gear differs. |
| 17 | Fuel fillers and filler caps | 4 | 4 | Recess, neck, cap and optional tether; preserve supplied outward axis. |
| 18 | Helicopter wire cutters | 4 | 4 | Blade/support profile and attachment axis. |
| 19 | Slat/cage armour panels | 3 | 4 | Bounded rail/slat panels with clearance; reactive blocks remain separate. |
| 20 | Air cleaners, filters and snorkels | 3 | 3 | Filter housings, clamps and pipe transitions; not generic turbine ducts. |
| 21 | Steering wheels and control columns | 3 | 3 | Wheel/yoke profiles, spokes and column joints; author placement per cockpit. |
| 22 | Ship liferafts and life rings | 2 | 5 | Canister cradles and buoy attachments; distinct styles, not a single shape. |
| 23 | Spare-wheel carriers | 2 | 2 | Brackets and retention hardware around the shared spare wheel; wheel itself is extracted. |
| 24 | Suspension arms and hubs | 2 | 2 | Endpoint-based links, joints and spring/damper pairs; solid axles already exist. |
| 25 | Gun shields and weapon-station armour | 1 | 3 | Bent plate outlines and viewing slots; keep traverse envelope. |
| 26 | External fuel drums and drum cradles | 1 | 1 | Drum ribs, ends and cradles; tanker vessel and aerodynamic drop tank are different. |

## Existing assemblies with remaining local construction

| Rank | Part | Builder groups | Source sites | Suggested reuse |
|---|---|---:|---:|---|
| 1 | Door/ramp construction | 50 | 80 | Finish migrating compatible leaves to VehicleDoors; sliding rails and ramps need extensions. |
| 2 | Vents and grille construction | 44 | 55 | Migrate flat/outline vents; ducts and optimized ship vents may differ. |
| 3 | Exhaust construction | 41 | 38 | Extend stack adapters; silencers, turbine grilles and suppressors are not interchangeable. |
| 4 | Boarding steps and ladders | 29 | 41 | Use tread/ladder builders; retain folding stairs and helicopter-specific supports. |
| 5 | Window and canopy construction | 26 | 33 | Extend fitted glazing where compatible; do not enable transparency over solid hulls. |
| 6 | Closed bins and toolboxes | 20 | 23 | Migrate top-lid bins; upright cabinets require another opening orientation. |
| 7 | Seat and bench construction | 15 | 20 | Use shared seats; bench and jockey-seat layouts need separate dimension contracts. |
| 8 | Handrails and grab handles | 12 | 14 | Extend current rails and pulls; preserve optimized marine rail meshes. |
| 9 | Hose and tow-cable routes | 7 | 7 | Use supported cable routes; coils and wound drums need distinct construction. |

## Recommended order

Start with compatible migrations to **doors/ramps and vents/grilles**, which have the widest candidate coverage. For new assemblies, start with **track sprockets**: three family-local helpers already expose a similar construction boundary. Then tackle **bumpers, light guards and towing hardware**. Gun mantlets/cradles have the widest new-assembly coverage, but need several styles and careful preservation of pivot parents. Keep candidates below three builder groups as inventory only until another adopter is found. Counts below are source leads, not a migration commitment.

## Evidence by candidate

### Door/ramp construction

- **a10**: [VmAttack._a10_gear:601](../scripts/game/vehicles/vm_attack.gd#L601); [VmAttack._a10_gear:618](../scripts/game/vehicles/vm_attack.gd#L618)
- **aa_tech, technical**: [VmCore._hilux:869](../scripts/game/vehicles/vm_core.gd#L869)
- **ac130**: [VmGunship._ac130:369](../scripts/game/vehicles/vm_gunship.gd#L369); [VmGunship._ac130_gear:616](../scripts/game/vehicles/vm_gunship.gd#L616)
- **apc, btr**: [VmCore._btr80:1227](../scripts/game/vehicles/vm_core.gd#L1227)
- **blackfoot**: [VmHeli._blackfoot:796](../scripts/game/vehicles/vm_heli.gd#L796)
- **blackwasp**: [VmFighter._blackwasp:1190](../scripts/game/vehicles/vm_fighter.gd#L1190)
- **bobcat**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **caesar**: [VmPlane._caesar:816](../scripts/game/vehicles/vm_plane.gd#L816)
- **cheetah**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **fia_truck, fia_truck_box**: [VmCiv._truck_box:793](../scripts/game/vehicles/vm_civ.gd#L793)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:541](../scripts/game/vehicles/vm_heli.gd#L541); [VmHeli._ghost_hawk:547](../scripts/game/vehicles/vm_heli.gd#L547); [VmHeli._ghost_hawk:602](../scripts/game/vehicles/vm_heli.gd#L602)
- **gorgon**: [VmIndep._gorgon:778](../scripts/game/vehicles/vm_indep.gd#L778)
- **gun_trawler**: [VmShips._gun_trawler:1041](../scripts/game/vehicles/vm_ships.gd#L1041); [VmShips._gun_trawler:1154](../scripts/game/vehicles/vm_ships.gd#L1154); [VmShips._gun_trawler:1174](../scripts/game/vehicles/vm_ships.gd#L1174)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1106](../scripts/game/vehicles/vm_civ.gd#L1106)
- **heli**: [VmCore._blackhawk:1622](../scripts/game/vehicles/vm_core.gd#L1622); [VmCore._blackhawk:1631](../scripts/game/vehicles/vm_core.gd#L1631)
- **hellcat**: [VmHeli._hellcat:952](../scripts/game/vehicles/vm_heli.gd#L952)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1337](../scripts/game/vehicles/vm_nato.gd#L1337); [VmNato._hemtt_cab_detail:1387](../scripts/game/vehicles/vm_nato.gd#L1387); [VmNato._hemtt:1533](../scripts/game/vehicles/vm_nato.gd#L1533); [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:430](../scripts/game/vehicles/vm_heli.gd#L430); [VmHeli._little_bird:488](../scripts/game/vehicles/vm_heli.gd#L488)
- **huron**: [VmHeli._huron:651](../scripts/game/vehicles/vm_heli.gd#L651); [VmHeli._huron:666](../scripts/game/vehicles/vm_heli.gd#L666); [VmHeli._huron:691](../scripts/game/vehicles/vm_heli.gd#L691)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:262](../scripts/game/vehicles/vm_csat.gd#L262); [VmCsat._ifrit:265](../scripts/game/vehicles/vm_csat.gd#L265); [VmCsat._ifrit:283](../scripts/game/vehicles/vm_csat.gd#L283); [VmCsat._ifrit:314](../scripts/game/vehicles/vm_csat.gd#L314)
- **ifv**: [VmCore._bradley:1381](../scripts/game/vehicles/vm_core.gd#L1381)
- **jet**: [VmFighter._f16:866](../scripts/game/vehicles/vm_fighter.gd#L866); [VmFighter._f16:885](../scripts/game/vehicles/vm_fighter.gd#L885)
- **kajman**: [VmHeli._kajman:1078](../scripts/game/vehicles/vm_heli.gd#L1078)
- **kamysh**: [VmCsat._stalker:715](../scripts/game/vehicles/vm_csat.gd#L715)
- **m35**: [VmCore._truck:1741](../scripts/game/vehicles/vm_core.gd#L1741)
- **marid**: [VmCsat._marid:617](../scripts/game/vehicles/vm_csat.gd#L617)
- **marshall**: [VmNato._marshall:583](../scripts/game/vehicles/vm_nato.gd#L583); [VmNato._marshall:599](../scripts/game/vehicles/vm_nato.gd#L599)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:547](../scripts/game/vehicles/vm_civ.gd#L547); [VmCiv._mb_top:634](../scripts/game/vehicles/vm_civ.gd#L634)
- **mohawk**: [VmHeli._mohawk:860](../scripts/game/vehicles/vm_heli.gd#L860); [VmHeli._mohawk:867](../scripts/game/vehicles/vm_heli.gd#L867); [VmHeli._mohawk:887](../scripts/game/vehicles/vm_heli.gd#L887)
- **mora**: [VmIndep._mora:415](../scripts/game/vehicles/vm_indep.gd#L415)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:635](../scripts/game/vehicles/vm_indep.gd#L635)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:360](../scripts/game/vehicles/vm_civ.gd#L360)
- **orca, orca_armed**: [VmHeli._orca:1182](../scripts/game/vehicles/vm_heli.gd#L1182); [VmHeli._orca:1187](../scripts/game/vehicles/vm_heli.gd#L1187)
- **panther**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **patrol_ship**: [VmShips._patrol_ship:722](../scripts/game/vehicles/vm_ships.gd#L722); [VmShips._patrol_ship:725](../scripts/game/vehicles/vm_ships.gd#L725)
- **sandstorm**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **scorcher**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873); [VmNato._scorcher:996](../scripts/game/vehicles/vm_nato.gd#L996)
- **sentinel**: [VmPlane._sentinel:1204](../scripts/game/vehicles/vm_plane.gd#L1204); [VmPlane._sentinel:1212](../scripts/game/vehicles/vm_plane.gd#L1212)
- **slammer, slammer_up**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **sochor**: [VmCsat._sochor:1025](../scripts/game/vehicles/vm_csat.gd#L1025)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:972](../scripts/game/vehicles/vm_boat.gd#L972)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:217](../scripts/game/vehicles/vm_indep.gd#L217)
- **suv**: [VmCiv._suv:1241](../scripts/game/vehicles/vm_civ.gd#L1241)
- **tank**: [VmCore._abrams:397](../scripts/game/vehicles/vm_core.gd#L397); [VmCore._abrams:461](../scripts/game/vehicles/vm_core.gd#L461)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1323](../scripts/game/vehicles/vm_csat.gd#L1323); [VmCsat._tempest:1347](../scripts/game/vehicles/vm_csat.gd#L1347)
- **tigris**: [VmCsat._stalker:715](../scripts/game/vehicles/vm_csat.gd#L715)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:867](../scripts/game/vehicles/vm_civ.gd#L867); [VmCiv._van:878](../scripts/game/vehicles/vm_civ.gd#L878); [VmCiv._van_services:974](../scripts/game/vehicles/vm_civ.gd#L974)
- **wipeout**: [VmAttack._wip_cockpit:886](../scripts/game/vehicles/vm_attack.gd#L886); [VmAttack._wip_gear:1070](../scripts/game/vehicles/vm_attack.gd#L1070); [VmAttack._wip_gear:1084](../scripts/game/vehicles/vm_attack.gd#L1084); [VmAttack._wip_gear:1087](../scripts/game/vehicles/vm_attack.gd#L1087)
- **xian**: [VmPlane._xian:1470](../scripts/game/vehicles/vm_plane.gd#L1470)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:913](../scripts/game/vehicles/vm_indep.gd#L913); [VmIndep._zamak_repair:1062](../scripts/game/vehicles/vm_indep.gd#L1062); [VmIndep._zamak_medical:1111](../scripts/game/vehicles/vm_indep.gd#L1111); [VmIndep._zamak_fuel:1145](../scripts/game/vehicles/vm_indep.gd#L1145)

### Vents and grille construction

- **aa_tech, technical**: [VmCore._hilux:900](../scripts/game/vehicles/vm_core.gd#L900)
- **angara, angara_k**: [VmCsat._t14:1134](../scripts/game/vehicles/vm_csat.gd#L1134)
- **apc, btr**: [VmCore._btr80:1253](../scripts/game/vehicles/vm_core.gd#L1253)
- **assault_boat**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:796](../scripts/game/vehicles/vm_gunship.gd#L796)
- **bobcat**: [VmNato._namer_hull:1105](../scripts/game/vehicles/vm_nato.gd#L1105)
- **cheetah**: [VmNato._namer_hull:1105](../scripts/game/vehicles/vm_nato.gd#L1105)
- **fia_truck, fia_truck_box**: [VmCiv._truck:725](../scripts/game/vehicles/vm_civ.gd#L725)
- **futura**: [VmCsat._t100:873](../scripts/game/vehicles/vm_csat.gd#L873); [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878); [VmCsat._futura:994](../scripts/game/vehicles/vm_csat.gd#L994)
- **gorgon**: [VmIndep._gorgon:761](../scripts/game/vehicles/vm_indep.gd#L761)
- **greyhawk**: [VmPlane._greyhawk:1139](../scripts/game/vehicles/vm_plane.gd#L1139)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1112](../scripts/game/vehicles/vm_civ.gd#L1112)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- **humvee**: [VmCore._humvee:1060](../scripts/game/vehicles/vm_core.gd#L1060); [VmCore._humvee:1068](../scripts/game/vehicles/vm_core.gd#L1068)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:310](../scripts/game/vehicles/vm_nato.gd#L310)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:262](../scripts/game/vehicles/vm_csat.gd#L262); [VmCsat._ifrit:270](../scripts/game/vehicles/vm_csat.gd#L270); [VmCsat._ifrit:309](../scripts/game/vehicles/vm_csat.gd#L309)
- **ifv**: [VmCore._bradley:1339](../scripts/game/vehicles/vm_core.gd#L1339)
- **jet**: [VmFighter._f16:739](../scripts/game/vehicles/vm_fighter.gd#L739); [VmFighter._f16:767](../scripts/game/vehicles/vm_fighter.gd#L767)
- **kuma**: [VmIndep._kuma:512](../scripts/game/vehicles/vm_indep.gd#L512); [VmIndep._kuma:520](../scripts/game/vehicles/vm_indep.gd#L520)
- **m35**: [VmCore._truck:1734](../scripts/game/vehicles/vm_core.gd#L1734)
- **marshall**: [VmNato._marshall:562](../scripts/game/vehicles/vm_nato.gd#L562); [VmNato._marshall:581](../scripts/game/vehicles/vm_nato.gd#L581)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:269](../scripts/game/vehicles/vm_civ.gd#L269)
- **mora**: [VmIndep._mora:392](../scripts/game/vehicles/vm_indep.gd#L392); [VmIndep._mora:407](../scripts/game/vehicles/vm_indep.gd#L407); [VmIndep._mora:411](../scripts/game/vehicles/vm_indep.gd#L411)
- **motorboat**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:616](../scripts/game/vehicles/vm_indep.gd#L616)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:269](../scripts/game/vehicles/vm_civ.gd#L269); [VmCiv._offroad:336](../scripts/game/vehicles/vm_civ.gd#L336); [VmCiv._offroad:382](../scripts/game/vehicles/vm_civ.gd#L382)
- **old_tank**: [VmCore._t55:674](../scripts/game/vehicles/vm_core.gd#L674); [VmCore._t55:688](../scripts/game/vehicles/vm_core.gd#L688); [VmCore._t55:753](../scripts/game/vehicles/vm_core.gd#L753)
- **panther**: [VmNato._namer_hull:1105](../scripts/game/vehicles/vm_nato.gd#L1105)
- **patrol_ship**: [VmShips._vent:418](../scripts/game/vehicles/vm_ships.gd#L418); [VmShips._patrol_ship:875](../scripts/game/vehicles/vm_ships.gd#L875)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:398](../scripts/game/vehicles/vm_csat.gd#L398)
- **rhib**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419)
- **rhino, rhino_up**: [VmNato._rhino:678](../scripts/game/vehicles/vm_nato.gd#L678)
- **sandstorm**: [VmNato._mk_hull:827](../scripts/game/vehicles/vm_nato.gd#L827); [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **scorcher**: [VmNato._mk_hull:827](../scripts/game/vehicles/vm_nato.gd#L827); [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **sdv**: [VmBoat._sdv:864](../scripts/game/vehicles/vm_boat.gd#L864)
- **slammer, slammer_up**: [VmNato._mk_hull:827](../scripts/game/vehicles/vm_nato.gd#L827); [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **sochor**: [VmCsat._t100:873](../scripts/game/vehicles/vm_csat.gd#L873); [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878); [VmCsat._sochor:1025](../scripts/game/vehicles/vm_csat.gd#L1025)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:251](../scripts/game/vehicles/vm_indep.gd#L251)
- **tank**: [VmCore._abrams:397](../scripts/game/vehicles/vm_core.gd#L397); [VmCore._abrams:407](../scripts/game/vehicles/vm_core.gd#L407)
- **taru**: [VmHeli._taru:1302](../scripts/game/vehicles/vm_heli.gd#L1302)
- **tractor**: [VmCiv._tractor:1376](../scripts/game/vehicles/vm_civ.gd#L1376); [VmCiv._tractor:1384](../scripts/game/vehicles/vm_civ.gd#L1384)
- **varsuk**: [VmCsat._t100:873](../scripts/game/vehicles/vm_csat.gd#L873); [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878)
- **water_scooter**: [VmBoat._scooter:1193](../scripts/game/vehicles/vm_boat.gd#L1193)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_box:1046](../scripts/game/vehicles/vm_indep.gd#L1046); [VmIndep._zamak_fuel:1145](../scripts/game/vehicles/vm_indep.gd#L1145)

### Exhaust construction

- **a10**: [VmAttack._a10_engines:506](../scripts/game/vehicles/vm_attack.gd#L506)
- **aa_tech, technical**: [VmCore._hilux:827](../scripts/game/vehicles/vm_core.gd#L827)
- **ac130**: [VmGunship._t56:536](../scripts/game/vehicles/vm_gunship.gd#L536)
- **angara, angara_k**: [VmCsat._t14:1134](../scripts/game/vehicles/vm_csat.gd#L1134)
- **apc, btr**: [VmCore._btr80:1227](../scripts/game/vehicles/vm_core.gd#L1227)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:796](../scripts/game/vehicles/vm_gunship.gd#L796)
- **blackfoot**: [VmHeli._blackfoot:766](../scripts/game/vehicles/vm_heli.gd#L766)
- **caesar**: [VmPlane._caesar:820](../scripts/game/vehicles/vm_plane.gd#L820)
- **falcon**: [VmHeli._falcon:1378](../scripts/game/vehicles/vm_heli.gd#L1378)
- **futura**: [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:560](../scripts/game/vehicles/vm_heli.gd#L560)
- **gorgon**: [VmIndep._gorgon:761](../scripts/game/vehicles/vm_indep.gd#L761)
- **greyhawk**: [VmPlane._greyhawk:1139](../scripts/game/vehicles/vm_plane.gd#L1139)
- **gunship**: [VmCore._apache:1529](../scripts/game/vehicles/vm_core.gd#L1529)
- **heli**: [VmCore._blackhawk:1646](../scripts/game/vehicles/vm_core.gd#L1646)
- **hellcat**: [VmHeli._hellcat:961](../scripts/game/vehicles/vm_heli.gd#L961)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:456](../scripts/game/vehicles/vm_heli.gd#L456)
- **ifv**: [VmCore._bradley:1353](../scripts/game/vehicles/vm_core.gd#L1353)
- **kajman**: [VmHeli._kajman:1091](../scripts/game/vehicles/vm_heli.gd#L1091)
- **kart**: [VmCiv._kart:1337](../scripts/game/vehicles/vm_civ.gd#L1337)
- **kuma**: [VmIndep._kuma:520](../scripts/game/vehicles/vm_indep.gd#L520)
- **marid**: [VmCsat._marid:603](../scripts/game/vehicles/vm_csat.gd#L603)
- **marshall**: [VmNato._marshall:581](../scripts/game/vehicles/vm_nato.gd#L581)
- **mohawk**: [VmHeli._mohawk:893](../scripts/game/vehicles/vm_heli.gd#L893)
- **mora**: [VmIndep._mora:407](../scripts/game/vehicles/vm_indep.gd#L407)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:616](../scripts/game/vehicles/vm_indep.gd#L616)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:302](../scripts/game/vehicles/vm_civ.gd#L302)
- **old_tank**: [VmCore._t55:674](../scripts/game/vehicles/vm_core.gd#L674)
- **orca, orca_armed**: [VmHeli._orca:1193](../scripts/game/vehicles/vm_heli.gd#L1193)
- **patrol_ship**: [VmShips._patrol_ship:663](../scripts/game/vehicles/vm_ships.gd#L663); [VmShips._patrol_ship:901](../scripts/game/vehicles/vm_ships.gd#L901)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:396](../scripts/game/vehicles/vm_csat.gd#L396)
- **quadbike**: [VmCiv._quad:1042](../scripts/game/vehicles/vm_civ.gd#L1042)
- **sandstorm**: [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **scorcher**: [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **slammer, slammer_up**: [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- **sochor**: [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:240](../scripts/game/vehicles/vm_indep.gd#L240)
- **suv**: [VmCiv._suv:1261](../scripts/game/vehicles/vm_civ.gd#L1261)
- **tank**: [VmCore._abrams:407](../scripts/game/vehicles/vm_core.gd#L407)
- **varsuk**: [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:936](../scripts/game/vehicles/vm_indep.gd#L936)

### Boarding steps and ladders

- **aa_tech, technical**: [VmCore._hilux:827](../scripts/game/vehicles/vm_core.gd#L827); [VmCore._hilux:881](../scripts/game/vehicles/vm_core.gd#L881); [VmCore._hilux:917](../scripts/game/vehicles/vm_core.gd#L917)
- **apc, btr**: [VmCore._btr80:1242](../scripts/game/vehicles/vm_core.gd#L1242)
- **blackfoot**: [VmHeli._blackfoot:759](../scripts/game/vehicles/vm_heli.gd#L759)
- **bobcat**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **cheetah**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **fia_truck, fia_truck_box**: [VmCiv._truck:680](../scripts/game/vehicles/vm_civ.gd#L680); [VmCiv._truck:701](../scripts/game/vehicles/vm_civ.gd#L701)
- **gorgon**: [VmIndep._gorgon:778](../scripts/game/vehicles/vm_indep.gd#L778)
- **gryphon**: [VmPlane._gryphon:625](../scripts/game/vehicles/vm_plane.gd#L625)
- **gun_trawler**: [VmShips._gun_trawler:1041](../scripts/game/vehicles/vm_ships.gd#L1041)
- **gunship**: [VmCore._apache:1501](../scripts/game/vehicles/vm_core.gd#L1501)
- **heli**: [VmCore._blackhawk:1631](../scripts/game/vehicles/vm_core.gd#L1631)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1337](../scripts/game/vehicles/vm_nato.gd#L1337); [VmNato._hemtt_cab_detail:1387](../scripts/game/vehicles/vm_nato.gd#L1387); [VmNato._hemtt:1533](../scripts/game/vehicles/vm_nato.gd#L1533); [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:283](../scripts/game/vehicles/vm_csat.gd#L283); [VmCsat._ifrit:314](../scripts/game/vehicles/vm_csat.gd#L314)
- **kajman**: [VmHeli._kajman:1074](../scripts/game/vehicles/vm_heli.gd#L1074)
- **marshall**: [VmNato._marshall:599](../scripts/game/vehicles/vm_nato.gd#L599)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:302](../scripts/game/vehicles/vm_civ.gd#L302); [VmCiv._offroad:360](../scripts/game/vehicles/vm_civ.gd#L360); [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)
- **panther**: [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)
- **patrol_ship**: [VmShips._patrol_ship:725](../scripts/game/vehicles/vm_ships.gd#L725)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:382](../scripts/game/vehicles/vm_csat.gd#L382)
- **sandstorm**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **scorcher**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **slammer, slammer_up**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1084](../scripts/game/vehicles/vm_boat.gd#L1084)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:183](../scripts/game/vehicles/vm_indep.gd#L183); [VmIndep._strider:217](../scripts/game/vehicles/vm_indep.gd#L217)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1347](../scripts/game/vehicles/vm_csat.gd#L1347); [VmCsat._tempest:1392](../scripts/game/vehicles/vm_csat.gd#L1392)
- **tractor**: [VmCiv._tractor:1446](../scripts/game/vehicles/vm_civ.gd#L1446)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:890](../scripts/game/vehicles/vm_civ.gd#L890); [VmCiv._van_services:966](../scripts/game/vehicles/vm_civ.gd#L966)
- **water_scooter**: [VmBoat._scooter:1152](../scripts/game/vehicles/vm_boat.gd#L1152); [VmBoat._scooter:1169](../scripts/game/vehicles/vm_boat.gd#L1169)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1062](../scripts/game/vehicles/vm_indep.gd#L1062); [VmIndep._zamak_repair:1070](../scripts/game/vehicles/vm_indep.gd#L1070); [VmIndep._zamak_medical:1111](../scripts/game/vehicles/vm_indep.gd#L1111); [VmIndep._zamak_fuel:1145](../scripts/game/vehicles/vm_indep.gd#L1145)

### Turret mantlets and gun cradles

- **aa_tech, technical**: [VmCore._hilux_dshk:954](../scripts/game/vehicles/vm_core.gd#L954); [VmCore._zu23:993](../scripts/game/vehicles/vm_core.gd#L993)
- **ac130**: [VmGunship._ac130_guns:586](../scripts/game/vehicles/vm_gunship.gd#L586)
- **angara, angara_k**: [VmCsat._rcws:200](../scripts/game/vehicles/vm_csat.gd#L200)
- **apc, btr**: [VmCore._btr80:1265](../scripts/game/vehicles/vm_core.gd#L1265)
- **bobcat**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267)
- **cheetah**: [VmNato._cheetah:1233](../scripts/game/vehicles/vm_nato.gd#L1233)
- **futura**: [VmCsat._rcws:200](../scripts/game/vehicles/vm_csat.gd#L200)
- **gorgon**: [VmIndep._gorgon:787](../scripts/game/vehicles/vm_indep.gd#L787)
- **gun_trawler**: [VmShips._zu23:570](../scripts/game/vehicles/vm_ships.gd#L570)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._rcws:200](../scripts/game/vehicles/vm_csat.gd#L200)
- **ifv**: [VmCore._bradley:1412](../scripts/game/vehicles/vm_core.gd#L1412)
- **kamysh**: [VmCsat._kamysh:747](../scripts/game/vehicles/vm_csat.gd#L747)
- **kuma**: [VmIndep._kuma:553](../scripts/game/vehicles/vm_indep.gd#L553)
- **marshall**: [VmNato._marshall:618](../scripts/game/vehicles/vm_nato.gd#L618)
- **mora**: [VmIndep._mora:431](../scripts/game/vehicles/vm_indep.gd#L431)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:667](../scripts/game/vehicles/vm_indep.gd#L667)
- **old_tank**: [VmCore._t55:730](../scripts/game/vehicles/vm_core.gd#L730)
- **panther**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267)
- **patrol_ship**: [VmShips._mk38:480](../scripts/game/vehicles/vm_ships.gd#L480)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:466](../scripts/game/vehicles/vm_csat.gd#L466)
- **rhino, rhino_up**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267); [VmNato._rhino:699](../scripts/game/vehicles/vm_nato.gd#L699)
- **scorcher**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267); [VmNato._scorcher:1011](../scripts/game/vehicles/vm_nato.gd#L1011)
- **slammer, slammer_up**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267); [VmNato._mk_turret:914](../scripts/game/vehicles/vm_nato.gd#L914)
- **sochor**: [VmCsat._rcws:200](../scripts/game/vehicles/vm_csat.gd#L200); [VmCsat._sochor:1047](../scripts/game/vehicles/vm_csat.gd#L1047)
- **stomper**: [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256); [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267)
- **tigris**: [VmCsat._tigris:784](../scripts/game/vehicles/vm_csat.gd#L784)
- **varsuk**: [VmCsat._varsuk:935](../scripts/game/vehicles/vm_csat.gd#L935)

### Window and canopy construction

- **a10**: [VmAttack._sniper:673](../scripts/game/vehicles/vm_attack.gd#L673)
- **bobcat**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:602](../scripts/game/vehicles/vm_heli.gd#L602)
- **greyhawk**: [VmPlane._greyhawk:1126](../scripts/game/vehicles/vm_plane.gd#L1126)
- **gunship**: [VmCore._apache:1501](../scripts/game/vehicles/vm_core.gd#L1501); [VmCore._apache:1526](../scripts/game/vehicles/vm_core.gd#L1526); [VmHeli._canopy:1018](../scripts/game/vehicles/vm_heli.gd#L1018)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1335](../scripts/game/vehicles/vm_nato.gd#L1335); [VmNato._hemtt_chassis:1337](../scripts/game/vehicles/vm_nato.gd#L1337); [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- **humvee**: [VmCore._humvee:1130](../scripts/game/vehicles/vm_core.gd#L1130)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277); [VmNato._hunter:332](../scripts/game/vehicles/vm_nato.gd#L332); [VmNato._hunter:338](../scripts/game/vehicles/vm_nato.gd#L338); [VmNato._hunter:363](../scripts/game/vehicles/vm_nato.gd#L363)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:253](../scripts/game/vehicles/vm_csat.gd#L253)
- **kajman**: [VmHeli._canopy:1018](../scripts/game/vehicles/vm_heli.gd#L1018)
- **m35**: [VmCore._truck:1741](../scripts/game/vehicles/vm_core.gd#L1741)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:600](../scripts/game/vehicles/vm_civ.gd#L600)
- **motorboat**: [VmBoat._motorboat:589](../scripts/game/vehicles/vm_boat.gd#L589); [VmBoat._motorboat:593](../scripts/game/vehicles/vm_boat.gd#L593)
- **panther**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **patrol_ship**: [VmShips._mk38:490](../scripts/game/vehicles/vm_ships.gd#L490); [VmShips._patrol_ship:708](../scripts/game/vehicles/vm_ships.gd#L708); [VmShips._patrol_ship:722](../scripts/game/vehicles/vm_ships.gd#L722)
- **rhino, rhino_up**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **scorcher**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **sdv**: [VmBoat._sdv:859](../scripts/game/vehicles/vm_boat.gd#L859)
- **sentinel**: [VmPlane._sentinel:1204](../scripts/game/vehicles/vm_plane.gd#L1204)
- **slammer, slammer_up**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:978](../scripts/game/vehicles/vm_boat.gd#L978)
- **stomper**: [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:183](../scripts/game/vehicles/vm_indep.gd#L183); [VmIndep._strider:197](../scripts/game/vehicles/vm_indep.gd#L197); [VmIndep._strider:217](../scripts/game/vehicles/vm_indep.gd#L217); [VmIndep._strider:225](../scripts/game/vehicles/vm_indep.gd#L225)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:878](../scripts/game/vehicles/vm_civ.gd#L878)
- **wipeout**: [VmAttack._wip_cockpit:867](../scripts/game/vehicles/vm_attack.gd#L867); [VmAttack._wip_gun:912](../scripts/game/vehicles/vm_attack.gd#L912)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:913](../scripts/game/vehicles/vm_indep.gd#L913)

### Closed bins and toolboxes

- **angara, angara_k**: [VmCsat._t14:1134](../scripts/game/vehicles/vm_csat.gd#L1134)
- **apc, btr**: [VmCore._btr80:1227](../scripts/game/vehicles/vm_core.gd#L1227)
- **gorgon**: [VmIndep._gorgon:743](../scripts/game/vehicles/vm_indep.gd#L743)
- **gun_trawler**: [VmShips._gun_trawler:1069](../scripts/game/vehicles/vm_ships.gd#L1069)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1526](../scripts/game/vehicles/vm_nato.gd#L1526)
- **ifv**: [VmCore._bradley:1381](../scripts/game/vehicles/vm_core.gd#L1381)
- **kuma**: [VmIndep._kuma:509](../scripts/game/vehicles/vm_indep.gd#L509)
- **marid**: [VmCsat._marid:603](../scripts/game/vehicles/vm_csat.gd#L603)
- **marshall**: [VmNato._marshall:583](../scripts/game/vehicles/vm_nato.gd#L583)
- **mora**: [VmIndep._mora:415](../scripts/game/vehicles/vm_indep.gd#L415)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:632](../scripts/game/vehicles/vm_indep.gd#L632)
- **old_tank**: [VmCore._t55:660](../scripts/game/vehicles/vm_core.gd#L660); [VmCore._t55:674](../scripts/game/vehicles/vm_core.gd#L674)
- **patrol_ship**: [VmShips._patrol_ship:805](../scripts/game/vehicles/vm_ships.gd#L805); [VmShips._patrol_ship:875](../scripts/game/vehicles/vm_ships.gd#L875)
- **rhib**: [VmBoat._rhib:783](../scripts/game/vehicles/vm_boat.gd#L783); [VmBoat._rhib:790](../scripts/game/vehicles/vm_boat.gd#L790)
- **rhino, rhino_up**: [VmNato._rhino:678](../scripts/game/vehicles/vm_nato.gd#L678)
- **sochor**: [VmCsat._sochor:1025](../scripts/game/vehicles/vm_csat.gd#L1025)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:225](../scripts/game/vehicles/vm_indep.gd#L225)
- **tank**: [VmCore._abrams:505](../scripts/game/vehicles/vm_core.gd#L505)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1317](../scripts/game/vehicles/vm_csat.gd#L1317)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1062](../scripts/game/vehicles/vm_indep.gd#L1062)

### Track drive sprockets

- **angara, angara_k**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)
- **bobcat**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **cheetah**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **futura**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)
- **ifv**: [VmCore._sprocket:162](../scripts/game/vehicles/vm_core.gd#L162); [VmCore._bradley:1309](../scripts/game/vehicles/vm_core.gd#L1309)
- **kamysh**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)
- **kuma**: [VmIndep._sprocket:143](../scripts/game/vehicles/vm_indep.gd#L143)
- **mora**: [VmIndep._sprocket:143](../scripts/game/vehicles/vm_indep.gd#L143)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._sprocket:143](../scripts/game/vehicles/vm_indep.gd#L143)
- **old_tank**: [VmCore._sprocket:162](../scripts/game/vehicles/vm_core.gd#L162)
- **panther**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **sandstorm**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **scorcher**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **slammer, slammer_up**: [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)
- **sochor**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)
- **tank**: [VmCore._sprocket:162](../scripts/game/vehicles/vm_core.gd#L162); [VmCore._abrams:327](../scripts/game/vehicles/vm_core.gd#L327)
- **tigris**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)
- **varsuk**: [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)

### Bumpers and bumper end caps

- **aa_tech, technical**: [VmCore._hilux:900](../scripts/game/vehicles/vm_core.gd#L900); [VmCore._hilux:917](../scripts/game/vehicles/vm_core.gd#L917)
- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:650](../scripts/game/vehicle_models.gd#L650)
- **fia_truck, fia_truck_box**: [VmCiv._truck:725](../scripts/game/vehicles/vm_civ.gd#L725)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1322](../scripts/game/vehicles/vm_nato.gd#L1322)
- **humvee**: [VmCore._humvee:1068](../scripts/game/vehicles/vm_core.gd#L1068)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:327](../scripts/game/vehicles/vm_nato.gd#L327)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:262](../scripts/game/vehicles/vm_csat.gd#L262); [VmCsat._ifrit:309](../scripts/game/vehicles/vm_csat.gd#L309)
- **kart**: [VmCiv._kart:1345](../scripts/game/vehicles/vm_civ.gd#L1345)
- **m35**: [VmCore._truck:1723](../scripts/game/vehicles/vm_core.gd#L1723)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:562](../scripts/game/vehicles/vm_civ.gd#L562); [VmCiv._mb4wd:608](../scripts/game/vehicles/vm_civ.gd#L608)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:427](../scripts/game/vehicles/vm_nato.gd#L427)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._typhoon:1231](../scripts/game/vehicles/vm_csat.gd#L1231)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:890](../scripts/game/vehicles/vm_civ.gd#L890); [VmCiv._van:894](../scripts/game/vehicles/vm_civ.gd#L894)
- **water_scooter**: [VmBoat._scooter:1124](../scripts/game/vehicles/vm_boat.gd#L1124)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:897](../scripts/game/vehicles/vm_indep.gd#L897); [VmIndep._zamak_bed:957](../scripts/game/vehicles/vm_indep.gd#L957); [VmIndep._zamak_fuel:1160](../scripts/game/vehicles/vm_indep.gd#L1160)

### Seat and bench construction

- **aa_tech, technical**: [VmCore._zu23:1010](../scripts/game/vehicles/vm_core.gd#L1010)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:768](../scripts/game/vehicles/vm_civ.gd#L768)
- **gun_trawler**: [VmShips._zu23:576](../scripts/game/vehicles/vm_ships.gd#L576)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1470](../scripts/game/vehicles/vm_nato.gd#L1470); [VmNato._hemtt:1533](../scripts/game/vehicles/vm_nato.gd#L1533)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:446](../scripts/game/vehicles/vm_heli.gd#L446); [VmHeli._little_bird:480](../scripts/game/vehicles/vm_heli.gd#L480)
- **kart**: [VmCiv._kart:1328](../scripts/game/vehicles/vm_civ.gd#L1328); [VmCiv._kart:1337](../scripts/game/vehicles/vm_civ.gd#L1337)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:590](../scripts/game/vehicles/vm_civ.gd#L590); [VmCiv._mb4wd:600](../scripts/game/vehicles/vm_civ.gd#L600)
- **motorboat**: [VmBoat._motorboat:585](../scripts/game/vehicles/vm_boat.gd#L585); [VmBoat._motorboat:609](../scripts/game/vehicles/vm_boat.gd#L609)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:443](../scripts/game/vehicles/vm_nato.gd#L443)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:378](../scripts/game/vehicles/vm_csat.gd#L378)
- **rhib**: [VmBoat._rhib:783](../scripts/game/vehicles/vm_boat.gd#L783)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1016](../scripts/game/vehicles/vm_boat.gd#L1016)
- **tractor**: [VmCiv._tractor:1435](../scripts/game/vehicles/vm_civ.gd#L1435)
- **water_scooter**: [VmBoat._scooter:1193](../scripts/game/vehicles/vm_boat.gd#L1193)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_tilt:981](../scripts/game/vehicles/vm_indep.gd#L981)

### Aircraft pitot and probe fittings

- **blackfoot**: [VmHeli._blackfoot:815](../scripts/game/vehicles/vm_heli.gd#L815)
- **buzzard**: [VmPlane._buzzard:548](../scripts/game/vehicles/vm_plane.gd#L548)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:563](../scripts/game/vehicles/vm_heli.gd#L563)
- **gryphon**: [VmPlane._gryphon:641](../scripts/game/vehicles/vm_plane.gd#L641)
- **gunship**: [VmCore._apache:1512](../scripts/game/vehicles/vm_core.gd#L1512)
- **heli**: [VmCore._blackhawk:1638](../scripts/game/vehicles/vm_core.gd#L1638)
- **hellcat**: [VmHeli._hellcat:970](../scripts/game/vehicles/vm_heli.gd#L970)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:469](../scripts/game/vehicles/vm_heli.gd#L469)
- **huron**: [VmHeli._huron:696](../scripts/game/vehicles/vm_heli.gd#L696)
- **jet**: [VmFighter._f16:784](../scripts/game/vehicles/vm_fighter.gd#L784)
- **mohawk**: [VmHeli._mohawk:887](../scripts/game/vehicles/vm_heli.gd#L887)
- **neophron**: [VmPlane._neophron:1069](../scripts/game/vehicles/vm_plane.gd#L1069)
- **xian**: [VmPlane._xian:1522](../scripts/game/vehicles/vm_plane.gd#L1522)

### Handrails and grab handles

- **assault_boat**: [VmBoat._zodiac:513](../scripts/game/vehicles/vm_boat.gd#L513)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:571](../scripts/game/vehicles/vm_heli.gd#L571)
- **gun_trawler**: [VmShips._gun_trawler:1041](../scripts/game/vehicles/vm_ships.gd#L1041)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:488](../scripts/game/vehicles/vm_heli.gd#L488)
- **ifv**: [VmCore._bradley:1359](../scripts/game/vehicles/vm_core.gd#L1359)
- **marid**: [VmCsat._marid:614](../scripts/game/vehicles/vm_csat.gd#L614)
- **motorboat**: [VmBoat._motorboat:593](../scripts/game/vehicles/vm_boat.gd#L593); [VmBoat._motorboat:618](../scripts/game/vehicles/vm_boat.gd#L618)
- **old_tank**: [VmCore._t55:777](../scripts/game/vehicles/vm_core.gd#L777)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:986](../scripts/game/vehicles/vm_boat.gd#L986); [VmBoat._surc:1005](../scripts/game/vehicles/vm_boat.gd#L1005)
- **tank**: [VmCore._abrams:390](../scripts/game/vehicles/vm_core.gd#L390)
- **water_scooter**: [VmBoat._scooter:1169](../scripts/game/vehicles/vm_boat.gd#L1169)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:913](../scripts/game/vehicles/vm_indep.gd#L913)

### Radar dishes and radomes

- **a10**: [VmAttack._ecm_pod:688](../scripts/game/vehicles/vm_attack.gd#L688)
- **cheetah**: [VmNato._cheetah:1254](../scripts/game/vehicles/vm_nato.gd#L1254); [VmNato._cheetah:1260](../scripts/game/vehicles/vm_nato.gd#L1260)
- **gun_trawler**: [VmShips._gun_trawler:1076](../scripts/game/vehicles/vm_ships.gd#L1076)
- **gunship**: [VmCore._apache:1575](../scripts/game/vehicles/vm_core.gd#L1575)
- **heli**: [VmCore._blackhawk:1638](../scripts/game/vehicles/vm_core.gd#L1638)
- **mohawk**: [VmHeli._mohawk:887](../scripts/game/vehicles/vm_heli.gd#L887)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:650](../scripts/game/vehicles/vm_indep.gd#L650)
- **patrol_ship**: [VmShips._patrol_ship:778](../scripts/game/vehicles/vm_ships.gd#L778)
- **rhib**: [VmBoat._rhib:752](../scripts/game/vehicles/vm_boat.gd#L752)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:986](../scripts/game/vehicles/vm_boat.gd#L986)
- **tigris**: [VmCsat._tigris:797](../scripts/game/vehicles/vm_csat.gd#L797); [VmCsat._tigris:804](../scripts/game/vehicles/vm_csat.gd#L804)
- **varsuk**: [VmCsat._varsuk:947](../scripts/game/vehicles/vm_csat.gd#L947)

### Towing pintles and hitches

- **aa_tech, technical**: [VmCore._hilux:917](../scripts/game/vehicles/vm_core.gd#L917)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1322](../scripts/game/vehicles/vm_nato.gd#L1322)
- **humvee**: [VmCore._humvee:1114](../scripts/game/vehicles/vm_core.gd#L1114)
- **m35**: [VmCore._truck:1760](../scripts/game/vehicles/vm_core.gd#L1760)
- **mora**: [VmIndep._mora:415](../scripts/game/vehicles/vm_indep.gd#L415)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:635](../scripts/game/vehicles/vm_indep.gd#L635)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)
- **quadbike**: [VmCiv._quad:1042](../scripts/game/vehicles/vm_civ.gd#L1042)
- **tank**: [VmCore._abrams:407](../scripts/game/vehicles/vm_core.gd#L407)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_bed:957](../scripts/game/vehicles/vm_indep.gd#L957); [VmIndep._zamak_fuel:1160](../scripts/game/vehicles/vm_indep.gd#L1160)

### Turret bustle baskets and open stowage racks

- **gorgon**: [VmIndep._gorgon:820](../scripts/game/vehicles/vm_indep.gd#L820)
- **ifv**: [VmCore._bradley:1442](../scripts/game/vehicles/vm_core.gd#L1442)
- **kuma**: [VmIndep._kuma:580](../scripts/game/vehicles/vm_indep.gd#L580)
- **marid**: [VmCsat._marid:632](../scripts/game/vehicles/vm_csat.gd#L632)
- **mora**: [VmIndep._mora:457](../scripts/game/vehicles/vm_indep.gd#L457)
- **sandstorm**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **scorcher**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)
- **slammer, slammer_up**: [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873); [VmNato._mk_turret:948](../scripts/game/vehicles/vm_nato.gd#L948)
- **tank**: [VmCore._abrams:511](../scripts/game/vehicles/vm_core.gd#L511)

### Engine nacelles and cowling assemblies

- **a10**: [VmAttack._a10_engines:509](../scripts/game/vehicles/vm_attack.gd#L509)
- **ac130**: [VmGunship._t56:536](../scripts/game/vehicles/vm_gunship.gd#L536)
- **assault_boat**: [VmBoat._outboard:425](../scripts/game/vehicles/vm_boat.gd#L425)
- **falcon**: [VmHeli._falcon:1378](../scripts/game/vehicles/vm_heli.gd#L1378)
- **gunship**: [VmCore._apache:1529](../scripts/game/vehicles/vm_core.gd#L1529)
- **motorboat**: [VmBoat._outboard:425](../scripts/game/vehicles/vm_boat.gd#L425)
- **rhib**: [VmBoat._outboard:425](../scripts/game/vehicles/vm_boat.gd#L425)
- **wipeout**: [VmAttack._wip_engines:1004](../scripts/game/vehicles/vm_attack.gd#L1004)

### Light guards and protective cages

- **bobcat**: [VmNato._namer_hull:1099](../scripts/game/vehicles/vm_nato.gd#L1099)
- **cheetah**: [VmNato._namer_hull:1099](../scripts/game/vehicles/vm_nato.gd#L1099)
- **ifv**: [VmCore._bradley:1353](../scripts/game/vehicles/vm_core.gd#L1353)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:627](../scripts/game/vehicles/vm_indep.gd#L627)
- **panther**: [VmNato._namer_hull:1099](../scripts/game/vehicles/vm_nato.gd#L1099)
- **rhino, rhino_up**: [VmNato._rhino:669](../scripts/game/vehicles/vm_nato.gd#L669)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:209](../scripts/game/vehicles/vm_indep.gd#L209)
- **tank**: [VmCore._abrams:367](../scripts/game/vehicles/vm_core.gd#L367)

### Vehicle cranes and hoists

- **bobcat**: [VmNato._bobcat:1198](../scripts/game/vehicles/vm_nato.gd#L1198)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1495](../scripts/game/vehicles/vm_nato.gd#L1495)
- **huron**: [VmHeli._huron:691](../scripts/game/vehicles/vm_heli.gd#L691)
- **mohawk**: [VmHeli._mohawk:887](../scripts/game/vehicles/vm_heli.gd#L887)
- **sandstorm**: [VmNato._sandstorm:1069](../scripts/game/vehicles/vm_nato.gd#L1069)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1306](../scripts/game/vehicles/vm_csat.gd#L1306); [VmCsat._tempest:1328](../scripts/game/vehicles/vm_csat.gd#L1328)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1075](../scripts/game/vehicles/vm_indep.gd#L1075)

### Cockpit dashboards and instrument consoles

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1314](../scripts/game/vehicles/vm_nato.gd#L1314)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:590](../scripts/game/vehicles/vm_civ.gd#L590)
- **motorboat**: [VmBoat._motorboat:589](../scripts/game/vehicles/vm_boat.gd#L589)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:435](../scripts/game/vehicles/vm_nato.gd#L435)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:372](../scripts/game/vehicles/vm_csat.gd#L372)
- **quadbike**: [VmCiv._quad:1005](../scripts/game/vehicles/vm_civ.gd#L1005)
- **rhib**: [VmBoat._rhib:734](../scripts/game/vehicles/vm_boat.gd#L734)

### Hose and tow-cable routes

- **apc, btr**: [VmCore._btr80:1227](../scripts/game/vehicles/vm_core.gd#L1227)
- **assault_boat**: [VmBoat._zodiac:496](../scripts/game/vehicles/vm_boat.gd#L496)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1559](../scripts/game/vehicles/vm_nato.gd#L1559)
- **m35**: [VmCore._truck:1760](../scripts/game/vehicles/vm_core.gd#L1760)
- **patrol_ship**: [VmShips._patrol_ship:745](../scripts/game/vehicles/vm_ships.gd#L745)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1373](../scripts/game/vehicles/vm_csat.gd#L1373)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_fuel:1145](../scripts/game/vehicles/vm_indep.gd#L1145)

### Marine propellers and rudders

- **assault_boat**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419); [VmBoat._zodiac:496](../scripts/game/vehicles/vm_boat.gd#L496)
- **gun_trawler**: [VmShips._gun_trawler:951](../scripts/game/vehicles/vm_ships.gd#L951)
- **motorboat**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419)
- **patrol_ship**: [VmShips._patrol_ship:875](../scripts/game/vehicles/vm_ships.gd#L875)
- **rhib**: [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419); [VmBoat._rhib:798](../scripts/game/vehicles/vm_boat.gd#L798)
- **sdv**: [VmBoat._sdv:875](../scripts/game/vehicles/vm_boat.gd#L875)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1084](../scripts/game/vehicles/vm_boat.gd#L1084)

### Cargo sideboards and tailgates

- **aa_tech, technical**: [VmCore._hilux:850](../scripts/game/vehicles/vm_core.gd#L850)
- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:662](../scripts/game/vehicle_models.gd#L662)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:754](../scripts/game/vehicles/vm_civ.gd#L754); [VmCiv._truck_bed:760](../scripts/game/vehicles/vm_civ.gd#L760)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1461](../scripts/game/vehicles/vm_nato.gd#L1461)
- **m35**: [VmCore._truck:1760](../scripts/game/vehicles/vm_core.gd#L1760)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:340](../scripts/game/vehicles/vm_civ.gd#L340)

### Sensor and telescoping masts

- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:644](../scripts/game/vehicles/vm_indep.gd#L644)
- **slammer, slammer_up**: [VmNato._mk_turret:941](../scripts/game/vehicles/vm_nato.gd#L941)
- **stomper**: [VmNato._stomper:1649](../scripts/game/vehicles/vm_nato.gd#L1649)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:260](../scripts/game/vehicles/vm_indep.gd#L260); [VmIndep._strider:271](../scripts/game/vehicles/vm_indep.gd#L271)
- **tank**: [VmCore._abrams:493](../scripts/game/vehicles/vm_core.gd#L493)
- **varsuk**: [VmCsat._varsuk:958](../scripts/game/vehicles/vm_csat.gd#L958)

### Gun receivers and breech housings

- **futura**: [VmCsat._futura:980](../scripts/game/vehicles/vm_csat.gd#L980)
- **gun_trawler**: [VmShips._zu23:559](../scripts/game/vehicles/vm_ships.gd#L559)
- **kuma**: [VmIndep._rcws:306](../scripts/game/vehicles/vm_indep.gd#L306); [VmIndep._rcws:314](../scripts/game/vehicles/vm_indep.gd#L314)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1035](../scripts/game/vehicles/vm_boat.gd#L1035)
- **strider, strider_gmg, strider_hmg**: [VmIndep._rcws:306](../scripts/game/vehicles/vm_indep.gd#L306); [VmIndep._rcws:314](../scripts/game/vehicles/vm_indep.gd#L314)

### Aircraft skids

- **darter**: [VmHeli._darter:1484](../scripts/game/vehicles/vm_heli.gd#L1484)
- **demining_drone, utility_drone**: [VmHeli._hexa:1522](../scripts/game/vehicles/vm_heli.gd#L1522)
- **falcon**: [VmHeli._skids:326](../scripts/game/vehicles/vm_heli.gd#L326)
- **hellcat**: [VmHeli._skids:326](../scripts/game/vehicles/vm_heli.gd#L326); [VmHeli._hellcat:984](../scripts/game/vehicles/vm_heli.gd#L984)
- **hummingbird, m900, pawnee**: [VmHeli._skids:326](../scripts/game/vehicles/vm_heli.gd#L326)

### Fuel fillers and filler caps

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_load_detail:1416](../scripts/game/vehicles/vm_nato.gd#L1416)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:380](../scripts/game/vehicles/vm_civ.gd#L380)
- **tank**: [VmCore._abrams:394](../scripts/game/vehicles/vm_core.gd#L394)
- **water_scooter**: [VmBoat._scooter:1193](../scripts/game/vehicles/vm_boat.gd#L1193)

### Helicopter wire cutters

- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:563](../scripts/game/vehicles/vm_heli.gd#L563)
- **gunship**: [VmCore._apache:1526](../scripts/game/vehicles/vm_core.gd#L1526)
- **heli**: [VmCore._blackhawk:1638](../scripts/game/vehicles/vm_core.gd#L1638)
- **hellcat**: [VmHeli._hellcat:970](../scripts/game/vehicles/vm_heli.gd#L970)

### Slat/cage armour panels

- **angara, angara_k**: [VmCsat._t14:1121](../scripts/game/vehicles/vm_csat.gd#L1121)
- **kuma**: [VmIndep._kuma:520](../scripts/game/vehicles/vm_indep.gd#L520); [VmIndep._kuma:580](../scripts/game/vehicles/vm_indep.gd#L580)
- **rhino, rhino_up**: [VmNato._rhino:748](../scripts/game/vehicles/vm_nato.gd#L748)

### Air cleaners, filters and snorkels

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1361](../scripts/game/vehicles/vm_nato.gd#L1361)
- **kajman**: [VmHeli._kajman:1091](../scripts/game/vehicles/vm_heli.gd#L1091)
- **old_tank**: [VmCore._t55:777](../scripts/game/vehicles/vm_core.gd#L777)

### Steering wheels and control columns

- **kart**: [VmCiv._kart:1328](../scripts/game/vehicles/vm_civ.gd#L1328)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:435](../scripts/game/vehicles/vm_nato.gd#L435)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:372](../scripts/game/vehicles/vm_csat.gd#L372)

### Ship liferafts and life rings

- **gun_trawler**: [VmShips._lifering:388](../scripts/game/vehicles/vm_ships.gd#L388); [VmShips._liferaft:400](../scripts/game/vehicles/vm_ships.gd#L400); [VmShips._gun_trawler:1069](../scripts/game/vehicles/vm_ships.gd#L1069)
- **patrol_ship**: [VmShips._lifering:388](../scripts/game/vehicles/vm_ships.gd#L388); [VmShips._liferaft:400](../scripts/game/vehicles/vm_ships.gd#L400); [VmShips._patrol_ship:745](../scripts/game/vehicles/vm_ships.gd#L745); [VmShips._patrol_ship:757](../scripts/game/vehicles/vm_ships.gd#L757)

### Spare-wheel carriers

- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:382](../scripts/game/vehicles/vm_nato.gd#L382)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:926](../scripts/game/vehicles/vm_indep.gd#L926)

### Suspension arms and hubs

- **quadbike**: [VmCiv._quad:996](../scripts/game/vehicles/vm_civ.gd#L996)
- **stomper**: [VmNato._stomper:1628](../scripts/game/vehicles/vm_nato.gd#L1628)

### Gun shields and weapon-station armour

- **tank**: [VmCore._abrams:430](../scripts/game/vehicles/vm_core.gd#L430); [VmCore._abrams:444](../scripts/game/vehicles/vm_core.gd#L444); [VmCore._abrams:482](../scripts/game/vehicles/vm_core.gd#L482)

### External fuel drums and drum cradles

- **old_tank**: [VmCore._t55:697](../scripts/game/vehicles/vm_core.gd#L697)

