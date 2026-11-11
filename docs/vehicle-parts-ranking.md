# Most common remaining vehicle construction

Source revision: `14a8d702`. 137 model keys, 84 construction-root groups.

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
| 2 | Door/ramp construction | 40 | 64 | Finish migrating compatible leaves to VehicleDoors; sliding rails and ramps need extensions. |
| 3 | Exhaust construction | 34 | 31 | Extend stack adapters; silencers, turbine grilles and suppressors are not interchangeable. |
| 4 | Boarding steps and ladders | 26 | 36 | Use tread/ladder builders; retain folding stairs and helicopter-specific supports. |
| 5 | Window and canopy construction | 24 | 24 | Extend fitted glazing where compatible; do not enable transparency over solid hulls. |
| 6 | Seat and bench construction | 15 | 19 | Use shared seats; bench and jockey-seat layouts need separate dimension contracts. |
| 7 | Closed bins and toolboxes | 13 | 14 | Migrate top-lid bins; upright cabinets require another opening orientation. |
| 8 | Handrails and grab handles | 10 | 11 | Extend current rails and pulls; preserve optimized marine rail meshes. |
| 9 | Bumpers and bumper end caps | 8 | 8 | Section, end treatment, attachment points and tow cutouts; preserve vehicle width. |
| 10 | Engine nacelles and cowling assemblies | 7 | 5 | Station loft plus service splits and mounts; aircraft silhouettes remain distinct. |
| 11 | Radar dishes and radomes | 6 | 7 | Separate dish and dome styles with pedestals; retain rotating parents. |
| 12 | Turret mantlets and gun cradles | 6 | 7 | Pivot-relative shrouds and supports; retain weapon sockets and recoil parents. |
| 13 | Cockpit dashboards and instrument consoles | 4 | 4 | Console profiles and instrument placements; keep cockpit layouts authored. |
| 14 | Towing pintles and hitches | 4 | 4 | Mounting plate, jaws/pin or ball; recovery shackles are a separate shared part. |
| 15 | Cargo sideboards and tailgates | 3 | 3 | Panel runs, posts, hinges and latch placement on authored bed bounds. |
| 16 | Hose and tow-cable routes | 3 | 3 | Use supported cable routes; coils and wound drums need distinct construction. |
| 17 | Marine propellers and rudders | 2 | 2 | Separate propeller, steering surface and waterjet families; aircraft propellers differ. |
| 18 | Vehicle cranes and hoists | 2 | 2 | Boom sections, pivot joints and cable routing; vehicle layouts and movement stay local. |
| 19 | Aircraft pitot and probe fittings | 1 | 1 | Tapered tubes, bases and authored angled paths; leave specialized refuelling systems local. |
| 20 | Fuel fillers and filler caps | 1 | 1 | Recess, neck, cap and optional tether; preserve supplied outward axis. |
| 21 | Gun receivers and breech housings | 1 | 1 | Parameterized receiver families, not one universal weapon silhouette. |
| 22 | Sensor and telescoping masts | 1 | 1 | Nested sections, collars and head mounts; optical housings already exist. |

## Using the remaining candidates

The [assembly implementation review](vehicle-assembly-review.md) records migrations and supported shapes. Remaining matches are source leads: inspect the linked geometry before extending an API. Keep candidates below three compatible builder groups as inventory until another adopter is found. Mixed sections can still appear here after some of their parts migrate.

## Evidence by candidate

### Vents and grille construction

- **aa_tech, technical**: [VmCore._hilux:871](../scripts/game/vehicles/vm_core.gd#L871)
- **angara, angara_k**: [VmCsat._t14:1117](../scripts/game/vehicles/vm_csat.gd#L1117)
- **apc, btr**: [VmCore._btr80:1223](../scripts/game/vehicles/vm_core.gd#L1223)
- **assault_boat**: [VmBoat._outboard:416](../scripts/game/vehicles/vm_boat.gd#L416)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:796](../scripts/game/vehicles/vm_gunship.gd#L796)
- **bobcat**: [VmNato._namer_hull:1093](../scripts/game/vehicles/vm_nato.gd#L1093)
- **cheetah**: [VmNato._namer_hull:1093](../scripts/game/vehicles/vm_nato.gd#L1093)
- **fia_truck, fia_truck_box**: [VmCiv._truck:723](../scripts/game/vehicles/vm_civ.gd#L723)
- **futura**: [VmCsat._t100:863](../scripts/game/vehicles/vm_csat.gd#L863); [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868); [VmCsat._futura:984](../scripts/game/vehicles/vm_csat.gd#L984)
- **gorgon**: [VmIndep._gorgon:736](../scripts/game/vehicles/vm_indep.gd#L736)
- **greyhawk**: [VmPlane._greyhawk:1139](../scripts/game/vehicles/vm_plane.gd#L1139)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1110](../scripts/game/vehicles/vm_civ.gd#L1110)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1532](../scripts/game/vehicles/vm_nato.gd#L1532)
- **humvee**: [VmCore._humvee:1031](../scripts/game/vehicles/vm_core.gd#L1031); [VmCore._humvee:1039](../scripts/game/vehicles/vm_core.gd#L1039)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:308](../scripts/game/vehicles/vm_nato.gd#L308)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:260](../scripts/game/vehicles/vm_csat.gd#L260); [VmCsat._ifrit:268](../scripts/game/vehicles/vm_csat.gd#L268)
- **ifv**: [VmCore._bradley:1309](../scripts/game/vehicles/vm_core.gd#L1309)
- **jet**: [VmFighter._f16:739](../scripts/game/vehicles/vm_fighter.gd#L739); [VmFighter._f16:767](../scripts/game/vehicles/vm_fighter.gd#L767)
- **kuma**: [VmIndep._kuma:490](../scripts/game/vehicles/vm_indep.gd#L490)
- **m35**: [VmCore._truck:1703](../scripts/game/vehicles/vm_core.gd#L1703)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._spg9:269](../scripts/game/vehicles/vm_civ.gd#L269)
- **mora**: [VmIndep._mora:376](../scripts/game/vehicles/vm_indep.gd#L376); [VmIndep._mora:393](../scripts/game/vehicles/vm_indep.gd#L393)
- **motorboat**: [VmBoat._outboard:416](../scripts/game/vehicles/vm_boat.gd#L416)
- **nyx_aa, nyx_ac, nyx_at, nyx_recon**: [VmIndep._nyx:591](../scripts/game/vehicles/vm_indep.gd#L591)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._spg9:269](../scripts/game/vehicles/vm_civ.gd#L269); [VmCiv._offroad:336](../scripts/game/vehicles/vm_civ.gd#L336); [VmCiv._offroad:382](../scripts/game/vehicles/vm_civ.gd#L382)
- **old_tank**: [VmCore._t55:646](../scripts/game/vehicles/vm_core.gd#L646); [VmCore._t55:659](../scripts/game/vehicles/vm_core.gd#L659); [VmCore._t55:724](../scripts/game/vehicles/vm_core.gd#L724)
- **panther**: [VmNato._namer_hull:1093](../scripts/game/vehicles/vm_nato.gd#L1093)
- **patrol_ship**: [VmShips._vent:418](../scripts/game/vehicles/vm_ships.gd#L418); [VmShips._patrol_ship:874](../scripts/game/vehicles/vm_ships.gd#L874)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:396](../scripts/game/vehicles/vm_csat.gd#L396)
- **rhib**: [VmBoat._outboard:416](../scripts/game/vehicles/vm_boat.gd#L416)
- **rhino, rhino_up**: [VmNato._rhino:674](../scripts/game/vehicles/vm_nato.gd#L674)
- **sandstorm**: [VmNato._mk_hull:815](../scripts/game/vehicles/vm_nato.gd#L815); [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **scorcher**: [VmNato._mk_hull:815](../scripts/game/vehicles/vm_nato.gd#L815); [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **sdv**: [VmBoat._sdv:861](../scripts/game/vehicles/vm_boat.gd#L861)
- **slammer, slammer_up**: [VmNato._mk_hull:815](../scripts/game/vehicles/vm_nato.gd#L815); [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **sochor**: [VmCsat._t100:863](../scripts/game/vehicles/vm_csat.gd#L863); [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868); [VmCsat._sochor:1015](../scripts/game/vehicles/vm_csat.gd#L1015)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:241](../scripts/game/vehicles/vm_indep.gd#L241)
- **tank**: [VmCore._abrams:384](../scripts/game/vehicles/vm_core.gd#L384)
- **taru**: [VmHeli._taru:1310](../scripts/game/vehicles/vm_heli.gd#L1310)
- **tractor**: [VmCiv._tractor:1374](../scripts/game/vehicles/vm_civ.gd#L1374); [VmCiv._tractor:1382](../scripts/game/vehicles/vm_civ.gd#L1382)
- **varsuk**: [VmCsat._t100:863](../scripts/game/vehicles/vm_csat.gd#L863); [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868)
- **water_scooter**: [VmBoat._scooter:1186](../scripts/game/vehicles/vm_boat.gd#L1186)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_box:1019](../scripts/game/vehicles/vm_indep.gd#L1019); [VmIndep._zamak_fuel:1118](../scripts/game/vehicles/vm_indep.gd#L1118)

### Door/ramp construction

- **a10**: [VmAttack._a10_gear:601](../scripts/game/vehicles/vm_attack.gd#L601)
- **aa_tech, technical**: [VmCore._hilux:840](../scripts/game/vehicles/vm_core.gd#L840)
- **ac130**: [VmGunship._ac130:369](../scripts/game/vehicles/vm_gunship.gd#L369)
- **apc, btr**: [VmCore._btr80:1197](../scripts/game/vehicles/vm_core.gd#L1197)
- **blackfoot**: [VmHeli._blackfoot:795](../scripts/game/vehicles/vm_heli.gd#L795)
- **blackwasp**: [VmFighter._blackwasp:1190](../scripts/game/vehicles/vm_fighter.gd#L1190)
- **bobcat**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **caesar**: [VmPlane._caesar:816](../scripts/game/vehicles/vm_plane.gd#L816)
- **cheetah**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **fia_truck, fia_truck_box**: [VmCiv._truck_box:791](../scripts/game/vehicles/vm_civ.gd#L791)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:537](../scripts/game/vehicles/vm_heli.gd#L537); [VmHeli._ghost_hawk:543](../scripts/game/vehicles/vm_heli.gd#L543); [VmHeli._ghost_hawk:598](../scripts/game/vehicles/vm_heli.gd#L598)
- **gorgon**: [VmIndep._gorgon:753](../scripts/game/vehicles/vm_indep.gd#L753)
- **gun_trawler**: [VmShips._gun_trawler:1039](../scripts/game/vehicles/vm_ships.gd#L1039); [VmShips._gun_trawler:1152](../scripts/game/vehicles/vm_ships.gd#L1152); [VmShips._gun_trawler:1172](../scripts/game/vehicles/vm_ships.gd#L1172)
- **hatchback, hatchback_sport**: [VmCiv._hatch:1104](../scripts/game/vehicles/vm_civ.gd#L1104)
- **heli**: [VmCore._blackhawk:1588](../scripts/game/vehicles/vm_core.gd#L1588); [VmCore._blackhawk:1597](../scripts/game/vehicles/vm_core.gd#L1597)
- **hellcat**: [VmHeli._hellcat:954](../scripts/game/vehicles/vm_heli.gd#L954)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1325](../scripts/game/vehicles/vm_nato.gd#L1325); [VmNato._hemtt_cab_detail:1375](../scripts/game/vehicles/vm_nato.gd#L1375); [VmNato._hemtt:1521](../scripts/game/vehicles/vm_nato.gd#L1521); [VmNato._hemtt:1532](../scripts/game/vehicles/vm_nato.gd#L1532)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:426](../scripts/game/vehicles/vm_heli.gd#L426)
- **huron**: [VmHeli._huron:647](../scripts/game/vehicles/vm_heli.gd#L647); [VmHeli._huron:662](../scripts/game/vehicles/vm_heli.gd#L662); [VmHeli._huron:687](../scripts/game/vehicles/vm_heli.gd#L687)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:260](../scripts/game/vehicles/vm_csat.gd#L260); [VmCsat._ifrit:263](../scripts/game/vehicles/vm_csat.gd#L263); [VmCsat._ifrit:281](../scripts/game/vehicles/vm_csat.gd#L281)
- **jet**: [VmFighter._f16:866](../scripts/game/vehicles/vm_fighter.gd#L866); [VmFighter._f16:885](../scripts/game/vehicles/vm_fighter.gd#L885)
- **kajman**: [VmHeli._kajman:1080](../scripts/game/vehicles/vm_heli.gd#L1080)
- **m35**: [VmCore._truck:1710](../scripts/game/vehicles/vm_core.gd#L1710)
- **marshall**: [VmNato._marshall:579](../scripts/game/vehicles/vm_nato.gd#L579); [VmNato._marshall:595](../scripts/game/vehicles/vm_nato.gd#L595)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:547](../scripts/game/vehicles/vm_civ.gd#L547); [VmCiv._mb_top:632](../scripts/game/vehicles/vm_civ.gd#L632)
- **mohawk**: [VmHeli._mohawk:859](../scripts/game/vehicles/vm_heli.gd#L859); [VmHeli._mohawk:866](../scripts/game/vehicles/vm_heli.gd#L866); [VmHeli._mohawk:886](../scripts/game/vehicles/vm_heli.gd#L886)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:360](../scripts/game/vehicles/vm_civ.gd#L360)
- **orca, orca_armed**: [VmHeli._orca:1187](../scripts/game/vehicles/vm_heli.gd#L1187); [VmHeli._orca:1192](../scripts/game/vehicles/vm_heli.gd#L1192)
- **panther**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **patrol_ship**: [VmShips._patrol_ship:725](../scripts/game/vehicles/vm_ships.gd#L725)
- **scorcher**: [VmNato._scorcher:984](../scripts/game/vehicles/vm_nato.gd#L984)
- **sentinel**: [VmPlane._sentinel:1204](../scripts/game/vehicles/vm_plane.gd#L1204); [VmPlane._sentinel:1212](../scripts/game/vehicles/vm_plane.gd#L1212)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:969](../scripts/game/vehicles/vm_boat.gd#L969)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:207](../scripts/game/vehicles/vm_indep.gd#L207)
- **suv**: [VmCiv._suv:1239](../scripts/game/vehicles/vm_civ.gd#L1239)
- **tank**: [VmCore._abrams:384](../scripts/game/vehicles/vm_core.gd#L384); [VmCore._abrams:443](../scripts/game/vehicles/vm_core.gd#L443)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:865](../scripts/game/vehicles/vm_civ.gd#L865); [VmCiv._van:876](../scripts/game/vehicles/vm_civ.gd#L876); [VmCiv._van_services:972](../scripts/game/vehicles/vm_civ.gd#L972)
- **wipeout**: [VmAttack._wip_cockpit:886](../scripts/game/vehicles/vm_attack.gd#L886); [VmAttack._wip_gear:1070](../scripts/game/vehicles/vm_attack.gd#L1070)
- **xian**: [VmPlane._xian:1470](../scripts/game/vehicles/vm_plane.gd#L1470)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:887](../scripts/game/vehicles/vm_indep.gd#L887); [VmIndep._zamak_repair:1035](../scripts/game/vehicles/vm_indep.gd#L1035); [VmIndep._zamak_medical:1084](../scripts/game/vehicles/vm_indep.gd#L1084); [VmIndep._zamak_fuel:1118](../scripts/game/vehicles/vm_indep.gd#L1118)

### Exhaust construction

- **a10**: [VmAttack._a10_engines:506](../scripts/game/vehicles/vm_attack.gd#L506)
- **aa_tech, technical**: [VmCore._hilux:798](../scripts/game/vehicles/vm_core.gd#L798)
- **ac130**: [VmGunship._t56:536](../scripts/game/vehicles/vm_gunship.gd#L536)
- **angara, angara_k**: [VmCsat._t14:1117](../scripts/game/vehicles/vm_csat.gd#L1117)
- **apc, btr**: [VmCore._btr80:1197](../scripts/game/vehicles/vm_core.gd#L1197)
- **blackfish, blackfish_armed**: [VmGunship._bf_nacelle:796](../scripts/game/vehicles/vm_gunship.gd#L796)
- **blackfoot**: [VmHeli._blackfoot:765](../scripts/game/vehicles/vm_heli.gd#L765)
- **caesar**: [VmPlane._caesar:820](../scripts/game/vehicles/vm_plane.gd#L820)
- **falcon**: [VmHeli._falcon:1386](../scripts/game/vehicles/vm_heli.gd#L1386)
- **futura**: [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:556](../scripts/game/vehicles/vm_heli.gd#L556)
- **gorgon**: [VmIndep._gorgon:736](../scripts/game/vehicles/vm_indep.gd#L736)
- **greyhawk**: [VmPlane._greyhawk:1139](../scripts/game/vehicles/vm_plane.gd#L1139)
- **gunship**: [VmCore._apache:1492](../scripts/game/vehicles/vm_core.gd#L1492)
- **heli**: [VmCore._blackhawk:1612](../scripts/game/vehicles/vm_core.gd#L1612)
- **hellcat**: [VmHeli._hellcat:963](../scripts/game/vehicles/vm_heli.gd#L963)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:452](../scripts/game/vehicles/vm_heli.gd#L452)
- **ifv**: [VmCore._bradley:1323](../scripts/game/vehicles/vm_core.gd#L1323)
- **kajman**: [VmHeli._kajman:1093](../scripts/game/vehicles/vm_heli.gd#L1093)
- **kart**: [VmCiv._kart:1335](../scripts/game/vehicles/vm_civ.gd#L1335)
- **kuma**: [VmIndep._kuma:498](../scripts/game/vehicles/vm_indep.gd#L498)
- **marid**: [VmCsat._marid:593](../scripts/game/vehicles/vm_csat.gd#L593)
- **mohawk**: [VmHeli._mohawk:892](../scripts/game/vehicles/vm_heli.gd#L892)
- **old_tank**: [VmCore._t55:646](../scripts/game/vehicles/vm_core.gd#L646)
- **orca, orca_armed**: [VmHeli._orca:1198](../scripts/game/vehicles/vm_heli.gd#L1198)
- **patrol_ship**: [VmShips._patrol_ship:663](../scripts/game/vehicles/vm_ships.gd#L663); [VmShips._patrol_ship:899](../scripts/game/vehicles/vm_ships.gd#L899)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:394](../scripts/game/vehicles/vm_csat.gd#L394)
- **sandstorm**: [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **scorcher**: [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **slammer, slammer_up**: [VmNato._mk_hull:829](../scripts/game/vehicles/vm_nato.gd#L829)
- **sochor**: [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868)
- **tank**: [VmCore._abrams:394](../scripts/game/vehicles/vm_core.gd#L394)
- **varsuk**: [VmCsat._t100:868](../scripts/game/vehicles/vm_csat.gd#L868)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:910](../scripts/game/vehicles/vm_indep.gd#L910)

### Boarding steps and ladders

- **aa_tech, technical**: [VmCore._hilux:798](../scripts/game/vehicles/vm_core.gd#L798); [VmCore._hilux:852](../scripts/game/vehicles/vm_core.gd#L852); [VmCore._hilux:888](../scripts/game/vehicles/vm_core.gd#L888)
- **apc, btr**: [VmCore._btr80:1212](../scripts/game/vehicles/vm_core.gd#L1212)
- **blackfoot**: [VmHeli._blackfoot:758](../scripts/game/vehicles/vm_heli.gd#L758)
- **bobcat**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **cheetah**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **fia_truck, fia_truck_box**: [VmCiv._truck:678](../scripts/game/vehicles/vm_civ.gd#L678); [VmCiv._truck:699](../scripts/game/vehicles/vm_civ.gd#L699)
- **gorgon**: [VmIndep._gorgon:753](../scripts/game/vehicles/vm_indep.gd#L753)
- **gryphon**: [VmPlane._gryphon:625](../scripts/game/vehicles/vm_plane.gd#L625)
- **gun_trawler**: [VmShips._gun_trawler:1039](../scripts/game/vehicles/vm_ships.gd#L1039)
- **gunship**: [VmCore._apache:1464](../scripts/game/vehicles/vm_core.gd#L1464)
- **heli**: [VmCore._blackhawk:1597](../scripts/game/vehicles/vm_core.gd#L1597)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1325](../scripts/game/vehicles/vm_nato.gd#L1325); [VmNato._hemtt_cab_detail:1375](../scripts/game/vehicles/vm_nato.gd#L1375); [VmNato._hemtt:1521](../scripts/game/vehicles/vm_nato.gd#L1521); [VmNato._hemtt:1532](../scripts/game/vehicles/vm_nato.gd#L1532)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:312](../scripts/game/vehicles/vm_csat.gd#L312)
- **kajman**: [VmHeli._kajman:1076](../scripts/game/vehicles/vm_heli.gd#L1076)
- **marshall**: [VmNato._marshall:595](../scripts/game/vehicles/vm_nato.gd#L595)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:302](../scripts/game/vehicles/vm_civ.gd#L302); [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)
- **panther**: [VmNato._namer_hull:1143](../scripts/game/vehicles/vm_nato.gd#L1143)
- **patrol_ship**: [VmShips._patrol_ship:725](../scripts/game/vehicles/vm_ships.gd#L725)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:380](../scripts/game/vehicles/vm_csat.gd#L380)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1077](../scripts/game/vehicles/vm_boat.gd#L1077)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:173](../scripts/game/vehicles/vm_indep.gd#L173); [VmIndep._strider:207](../scripts/game/vehicles/vm_indep.gd#L207)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1375](../scripts/game/vehicles/vm_csat.gd#L1375)
- **tractor**: [VmCiv._tractor:1444](../scripts/game/vehicles/vm_civ.gd#L1444)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:888](../scripts/game/vehicles/vm_civ.gd#L888); [VmCiv._van_services:964](../scripts/game/vehicles/vm_civ.gd#L964)
- **water_scooter**: [VmBoat._scooter:1145](../scripts/game/vehicles/vm_boat.gd#L1145); [VmBoat._scooter:1162](../scripts/game/vehicles/vm_boat.gd#L1162)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1043](../scripts/game/vehicles/vm_indep.gd#L1043); [VmIndep._zamak_medical:1084](../scripts/game/vehicles/vm_indep.gd#L1084); [VmIndep._zamak_fuel:1118](../scripts/game/vehicles/vm_indep.gd#L1118)

### Window and canopy construction

- **a10**: [VmAttack._sniper:673](../scripts/game/vehicles/vm_attack.gd#L673)
- **bobcat**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:598](../scripts/game/vehicles/vm_heli.gd#L598)
- **greyhawk**: [VmPlane._greyhawk:1126](../scripts/game/vehicles/vm_plane.gd#L1126)
- **gunship**: [VmCore._apache:1464](../scripts/game/vehicles/vm_core.gd#L1464); [VmHeli._canopy:1020](../scripts/game/vehicles/vm_heli.gd#L1020)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1323](../scripts/game/vehicles/vm_nato.gd#L1323)
- **humvee**: [VmCore._humvee:1100](../scripts/game/vehicles/vm_core.gd#L1100)
- **hunter, hunter_gmg, hunter_hmg**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275); [VmNato._hunter:330](../scripts/game/vehicles/vm_nato.gd#L330); [VmNato._hunter:336](../scripts/game/vehicles/vm_nato.gd#L336); [VmNato._hunter:361](../scripts/game/vehicles/vm_nato.gd#L361)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:251](../scripts/game/vehicles/vm_csat.gd#L251)
- **kajman**: [VmHeli._canopy:1020](../scripts/game/vehicles/vm_heli.gd#L1020)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:598](../scripts/game/vehicles/vm_civ.gd#L598)
- **motorboat**: [VmBoat._motorboat:586](../scripts/game/vehicles/vm_boat.gd#L586)
- **panther**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **patrol_ship**: [VmShips._mk38:490](../scripts/game/vehicles/vm_ships.gd#L490); [VmShips._patrol_ship:708](../scripts/game/vehicles/vm_ships.gd#L708)
- **rhino, rhino_up**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **scorcher**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **sdv**: [VmBoat._sdv:856](../scripts/game/vehicles/vm_boat.gd#L856)
- **sentinel**: [VmPlane._sentinel:1204](../scripts/game/vehicles/vm_plane.gd#L1204)
- **slammer, slammer_up**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:975](../scripts/game/vehicles/vm_boat.gd#L975)
- **stomper**: [VmNato._rcws:275](../scripts/game/vehicles/vm_nato.gd#L275)
- **strider, strider_gmg, strider_hmg**: [VmIndep._strider:173](../scripts/game/vehicles/vm_indep.gd#L173); [VmIndep._strider:187](../scripts/game/vehicles/vm_indep.gd#L187)
- **wipeout**: [VmAttack._wip_cockpit:867](../scripts/game/vehicles/vm_attack.gd#L867); [VmAttack._wip_gun:912](../scripts/game/vehicles/vm_attack.gd#L912)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:887](../scripts/game/vehicles/vm_indep.gd#L887)

### Seat and bench construction

- **aa_tech, technical**: [VmCore._zu23:981](../scripts/game/vehicles/vm_core.gd#L981)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:766](../scripts/game/vehicles/vm_civ.gd#L766)
- **gun_trawler**: [VmShips._zu23:576](../scripts/game/vehicles/vm_ships.gd#L576)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1458](../scripts/game/vehicles/vm_nato.gd#L1458); [VmNato._hemtt:1521](../scripts/game/vehicles/vm_nato.gd#L1521)
- **hummingbird, m900, pawnee**: [VmHeli._little_bird:442](../scripts/game/vehicles/vm_heli.gd#L442); [VmHeli._little_bird:476](../scripts/game/vehicles/vm_heli.gd#L476)
- **kart**: [VmCiv._kart:1326](../scripts/game/vehicles/vm_civ.gd#L1326); [VmCiv._kart:1335](../scripts/game/vehicles/vm_civ.gd#L1335)
- **mb4wd, mb4wd_at, mb4wd_lmg**: [VmCiv._mb4wd:598](../scripts/game/vehicles/vm_civ.gd#L598)
- **motorboat**: [VmBoat._motorboat:582](../scripts/game/vehicles/vm_boat.gd#L582); [VmBoat._motorboat:606](../scripts/game/vehicles/vm_boat.gd#L606)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:441](../scripts/game/vehicles/vm_nato.gd#L441)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:376](../scripts/game/vehicles/vm_csat.gd#L376)
- **rhib**: [VmBoat._rhib:780](../scripts/game/vehicles/vm_boat.gd#L780)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1009](../scripts/game/vehicles/vm_boat.gd#L1009)
- **tractor**: [VmCiv._tractor:1433](../scripts/game/vehicles/vm_civ.gd#L1433)
- **water_scooter**: [VmBoat._scooter:1186](../scripts/game/vehicles/vm_boat.gd#L1186)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_tilt:954](../scripts/game/vehicles/vm_indep.gd#L954)

### Closed bins and toolboxes

- **angara, angara_k**: [VmCsat._t14:1117](../scripts/game/vehicles/vm_csat.gd#L1117)
- **apc, btr**: [VmCore._btr80:1197](../scripts/game/vehicles/vm_core.gd#L1197)
- **gun_trawler**: [VmShips._gun_trawler:1067](../scripts/game/vehicles/vm_ships.gd#L1067)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt:1514](../scripts/game/vehicles/vm_nato.gd#L1514)
- **ifv**: [VmCore._bradley:1351](../scripts/game/vehicles/vm_core.gd#L1351)
- **marid**: [VmCsat._marid:593](../scripts/game/vehicles/vm_csat.gd#L593)
- **marshall**: [VmNato._marshall:579](../scripts/game/vehicles/vm_nato.gd#L579)
- **mora**: [VmIndep._mora:397](../scripts/game/vehicles/vm_indep.gd#L397)
- **old_tank**: [VmCore._t55:632](../scripts/game/vehicles/vm_core.gd#L632)
- **rhib**: [VmBoat._rhib:780](../scripts/game/vehicles/vm_boat.gd#L780); [VmBoat._rhib:787](../scripts/game/vehicles/vm_boat.gd#L787)
- **rhino, rhino_up**: [VmNato._rhino:674](../scripts/game/vehicles/vm_nato.gd#L674)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._tempest:1300](../scripts/game/vehicles/vm_csat.gd#L1300)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_repair:1035](../scripts/game/vehicles/vm_indep.gd#L1035)

### Handrails and grab handles

- **assault_boat**: [VmBoat._zodiac:510](../scripts/game/vehicles/vm_boat.gd#L510)
- **ghosthawk, ghosthawk_stub**: [VmHeli._ghost_hawk:567](../scripts/game/vehicles/vm_heli.gd#L567)
- **gun_trawler**: [VmShips._gun_trawler:1039](../scripts/game/vehicles/vm_ships.gd#L1039)
- **ifv**: [VmCore._bradley:1329](../scripts/game/vehicles/vm_core.gd#L1329)
- **motorboat**: [VmBoat._motorboat:590](../scripts/game/vehicles/vm_boat.gd#L590); [VmBoat._motorboat:615](../scripts/game/vehicles/vm_boat.gd#L615)
- **old_tank**: [VmCore._t55:748](../scripts/game/vehicles/vm_core.gd#L748)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:983](../scripts/game/vehicles/vm_boat.gd#L983)
- **tank**: [VmCore._abrams:377](../scripts/game/vehicles/vm_core.gd#L377)
- **water_scooter**: [VmBoat._scooter:1162](../scripts/game/vehicles/vm_boat.gd#L1162)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:887](../scripts/game/vehicles/vm_indep.gd#L887)

### Bumpers and bumper end caps

- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:650](../scripts/game/vehicle_models.gd#L650)
- **ifrit, ifrit_gmg, ifrit_hmg**: [VmCsat._ifrit:260](../scripts/game/vehicles/vm_csat.gd#L260)
- **kart**: [VmCiv._kart:1343](../scripts/game/vehicles/vm_civ.gd#L1343)
- **m35**: [VmCore._truck:1692](../scripts/game/vehicles/vm_core.gd#L1692)
- **prowler, prowler_at, prowler_hmg**: [VmNato._prowler:425](../scripts/game/vehicles/vm_nato.gd#L425)
- **tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair**: [VmCsat._typhoon:1214](../scripts/game/vehicles/vm_csat.gd#L1214)
- **van_ambulance, van_services, van_transport**: [VmCiv._van:892](../scripts/game/vehicles/vm_civ.gd#L892)
- **water_scooter**: [VmBoat._scooter:1117](../scripts/game/vehicles/vm_boat.gd#L1117)

### Engine nacelles and cowling assemblies

- **a10**: [VmAttack._a10_engines:509](../scripts/game/vehicles/vm_attack.gd#L509)
- **ac130**: [VmGunship._t56:536](../scripts/game/vehicles/vm_gunship.gd#L536)
- **assault_boat**: [VmBoat._outboard:422](../scripts/game/vehicles/vm_boat.gd#L422)
- **falcon**: [VmHeli._falcon:1386](../scripts/game/vehicles/vm_heli.gd#L1386)
- **motorboat**: [VmBoat._outboard:422](../scripts/game/vehicles/vm_boat.gd#L422)
- **rhib**: [VmBoat._outboard:422](../scripts/game/vehicles/vm_boat.gd#L422)
- **wipeout**: [VmAttack._wip_engines:1004](../scripts/game/vehicles/vm_attack.gd#L1004)

### Radar dishes and radomes

- **a10**: [VmAttack._ecm_pod:688](../scripts/game/vehicles/vm_attack.gd#L688)
- **cheetah**: [VmNato._cheetah:1242](../scripts/game/vehicles/vm_nato.gd#L1242); [VmNato._cheetah:1248](../scripts/game/vehicles/vm_nato.gd#L1248)
- **gunship**: [VmCore._apache:1541](../scripts/game/vehicles/vm_core.gd#L1541)
- **heli**: [VmCore._blackhawk:1604](../scripts/game/vehicles/vm_core.gd#L1604)
- **tigris**: [VmCsat._tigris:787](../scripts/game/vehicles/vm_csat.gd#L787)
- **varsuk**: [VmCsat._varsuk:937](../scripts/game/vehicles/vm_csat.gd#L937)

### Turret mantlets and gun cradles

- **aa_tech, technical**: [VmCore._hilux_dshk:925](../scripts/game/vehicles/vm_core.gd#L925); [VmCore._zu23:964](../scripts/game/vehicles/vm_core.gd#L964)
- **ac130**: [VmGunship._ac130_guns:586](../scripts/game/vehicles/vm_gunship.gd#L586)
- **gun_trawler**: [VmShips._zu23:570](../scripts/game/vehicles/vm_ships.gd#L570)
- **old_tank**: [VmCore._t55:701](../scripts/game/vehicles/vm_core.gd#L701)
- **patrol_ship**: [VmShips._mk38:480](../scripts/game/vehicles/vm_ships.gd#L480)
- **qilin, qilin_at, qilin_mg**: [VmCsat._qilin:464](../scripts/game/vehicles/vm_csat.gd#L464)

### Cockpit dashboards and instrument consoles

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1302](../scripts/game/vehicles/vm_nato.gd#L1302)
- **motorboat**: [VmBoat._motorboat:586](../scripts/game/vehicles/vm_boat.gd#L586)
- **quadbike**: [VmCiv._quad:1003](../scripts/game/vehicles/vm_civ.gd#L1003)
- **rhib**: [VmBoat._rhib:731](../scripts/game/vehicles/vm_boat.gd#L731)

### Towing pintles and hitches

- **aa_tech, technical**: [VmCore._hilux:888](../scripts/game/vehicles/vm_core.gd#L888)
- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1310](../scripts/game/vehicles/vm_nato.gd#L1310)
- **offroad, offroad_at, offroad_hmg, offroad_repair**: [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)
- **quadbike**: [VmCiv._quad:1040](../scripts/game/vehicles/vm_civ.gd#L1040)

### Air cleaners, filters and snorkels

- **hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair**: [VmNato._hemtt_chassis:1349](../scripts/game/vehicles/vm_nato.gd#L1349)
- **kajman**: [VmHeli._kajman:1093](../scripts/game/vehicles/vm_heli.gd#L1093)
- **old_tank**: [VmCore._t55:748](../scripts/game/vehicles/vm_core.gd#L748)

### Cargo sideboards and tailgates

- **aa_tech, technical**: [VmCore._hilux:821](../scripts/game/vehicles/vm_core.gd#L821)
- **civilian_0, civilian_1, civilian_2, civilian_3, civilian_4**: [VehicleModels._car:662](../scripts/game/vehicle_models.gd#L662)
- **fia_truck, fia_truck_box**: [VmCiv._truck_bed:752](../scripts/game/vehicles/vm_civ.gd#L752)

### Hose and tow-cable routes

- **apc, btr**: [VmCore._btr80:1197](../scripts/game/vehicles/vm_core.gd#L1197)
- **m35**: [VmCore._truck:1729](../scripts/game/vehicles/vm_core.gd#L1729)
- **patrol_ship**: [VmShips._patrol_ship:745](../scripts/game/vehicles/vm_ships.gd#L745)

### Ship liferafts and life rings

- **gun_trawler**: [VmShips._lifering:388](../scripts/game/vehicles/vm_ships.gd#L388); [VmShips._liferaft:400](../scripts/game/vehicles/vm_ships.gd#L400); [VmShips._gun_trawler:1067](../scripts/game/vehicles/vm_ships.gd#L1067)
- **patrol_ship**: [VmShips._lifering:388](../scripts/game/vehicles/vm_ships.gd#L388); [VmShips._liferaft:400](../scripts/game/vehicles/vm_ships.gd#L400); [VmShips._patrol_ship:745](../scripts/game/vehicles/vm_ships.gd#L745); [VmShips._patrol_ship:757](../scripts/game/vehicles/vm_ships.gd#L757)

### Marine propellers and rudders

- **patrol_ship**: [VmShips._patrol_ship:874](../scripts/game/vehicles/vm_ships.gd#L874)
- **speedboat_hmg, speedboat_minigun**: [VmBoat._surc:1077](../scripts/game/vehicles/vm_boat.gd#L1077)

### Spare-wheel carriers

- **hunter, hunter_gmg, hunter_hmg**: [VmNato._hunter:380](../scripts/game/vehicles/vm_nato.gd#L380)
- **zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair**: [VmIndep._zamak_cab:900](../scripts/game/vehicles/vm_indep.gd#L900)

### Suspension arms and hubs

- **quadbike**: [VmCiv._quad:994](../scripts/game/vehicles/vm_civ.gd#L994)
- **stomper**: [VmNato._stomper:1615](../scripts/game/vehicles/vm_nato.gd#L1615)

### Vehicle cranes and hoists

- **huron**: [VmHeli._huron:687](../scripts/game/vehicles/vm_heli.gd#L687)
- **mohawk**: [VmHeli._mohawk:886](../scripts/game/vehicles/vm_heli.gd#L886)

### Gun shields and weapon-station armour

- **tank**: [VmCore._abrams:412](../scripts/game/vehicles/vm_core.gd#L412); [VmCore._abrams:426](../scripts/game/vehicles/vm_core.gd#L426); [VmCore._abrams:464](../scripts/game/vehicles/vm_core.gd#L464)

### Aircraft pitot and probe fittings

- **gunship**: [VmCore._apache:1475](../scripts/game/vehicles/vm_core.gd#L1475)

### External fuel drums and drum cradles

- **old_tank**: [VmCore._t55:668](../scripts/game/vehicles/vm_core.gd#L668)

### Fuel fillers and filler caps

- **water_scooter**: [VmBoat._scooter:1186](../scripts/game/vehicles/vm_boat.gd#L1186)

### Gun receivers and breech housings

- **futura**: [VmCsat._futura:970](../scripts/game/vehicles/vm_csat.gd#L970)

### Sensor and telescoping masts

- **stomper**: [VmNato._stomper:1636](../scripts/game/vehicles/vm_nato.gd#L1636)

