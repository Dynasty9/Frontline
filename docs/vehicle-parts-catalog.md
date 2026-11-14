# Vehicle construction part catalog

Source revision: `ec2d275b`. 137 model keys, 84 construction-root groups.

Every model key is mapped below. Designs sharing a builder are grouped to avoid counting weapon/cargo variants as new designs. Each entry lists shared assemblies, authored sections in its root builder, and local helper construction. This is a source inventory, not a certified runtime bill of materials.

- Conditional branches are a union per builder root, not per-variant runtime presence.
- Comment/helper-name categories plus local construction are candidates, not verified identical meshes.
- Unlabelled construction is retained; only descriptive helper names can classify it automatically.
- Dynamic calls and inner-class construction require linked source inspection.
- Convoy team union and shadowed dispatchers do not add to design counts.
- Family-local helpers may already share a part within one family; ranking concerns cross-family extraction.

## Gameplay aliases

| Gameplay key | Model key |
|---|---|
| `aa_tech` | `aa_tech` |
| `angara` | `angara` |
| `angara_k` | `angara_k` |
| `blackfoot` | `blackfoot` |
| `bobcat` | `bobcat` |
| `btr` | `btr` |
| `cheetah` | `cheetah` |
| `darter` | `darter` |
| `falcon` | `falcon` |
| `fenghuang_uav` | `fenghuang` |
| `fia_truck` | `fia_truck` |
| `futura` | `futura` |
| `ghosthawk` | `ghosthawk` |
| `ghosthawk_stub` | `ghosthawk_stub` |
| `gorgon` | `gorgon` |
| `gun_trawler` | `gun_trawler` |
| `gunship` | `gunship` |
| `heli` | `heli` |
| `hellcat` | `hellcat` |
| `hemtt` | `hemtt` |
| `hemtt_ammo` | `hemtt_ammo` |
| `hemtt_medical` | `hemtt_medical` |
| `hemtt_repair` | `hemtt_repair` |
| `hummingbird` | `hummingbird` |
| `humvee` | `humvee` |
| `hunter` | `hunter` |
| `hunter_gmg` | `hunter_gmg` |
| `hunter_hmg` | `hunter_hmg` |
| `huron` | `huron` |
| `ifrit` | `ifrit` |
| `ifrit_gmg` | `ifrit_gmg` |
| `ifrit_hmg` | `ifrit_hmg` |
| `ifv` | `ifv` |
| `kajman` | `kajman` |
| `kamysh` | `kamysh` |
| `kuma` | `kuma` |
| `m900` | `m900` |
| `marid` | `marid` |
| `marshall` | `marshall` |
| `mb4wd_at` | `mb4wd_at` |
| `mb4wd_lmg` | `mb4wd_lmg` |
| `mohawk` | `mohawk` |
| `mora` | `mora` |
| `motorboat` | `motorboat` |
| `nyx_aa` | `nyx_aa` |
| `nyx_ac` | `nyx_ac` |
| `nyx_at` | `nyx_at` |
| `nyx_recon` | `nyx_recon` |
| `offroad` | `offroad` |
| `offroad_at` | `offroad_at` |
| `offroad_hmg` | `offroad_hmg` |
| `offroad_repair` | `offroad_repair` |
| `old_tank` | `old_tank` |
| `orca` | `orca` |
| `orca_armed` | `orca_armed` |
| `panther` | `panther` |
| `patrol_ship` | `patrol_ship` |
| `pawnee` | `pawnee` |
| `prowler` | `prowler` |
| `prowler_at` | `prowler_at` |
| `prowler_hmg` | `prowler_hmg` |
| `qilin` | `qilin` |
| `qilin_at` | `qilin_at` |
| `qilin_mg` | `qilin_mg` |
| `quadbike` | `quadbike` |
| `rhib` | `rhib` |
| `rhino` | `rhino` |
| `rhino_up` | `rhino_up` |
| `sandstorm` | `sandstorm` |
| `scorcher` | `scorcher` |
| `slammer` | `slammer` |
| `slammer_up` | `slammer_up` |
| `sochor` | `sochor` |
| `speedboat_hmg` | `speedboat_hmg` |
| `speedboat_minigun` | `speedboat_minigun` |
| `stomper` | `stomper` |
| `strider` | `strider` |
| `strider_gmg` | `strider_gmg` |
| `strider_hmg` | `strider_hmg` |
| `tank` | `tank` |
| `taru` | `taru` |
| `taru_lift` | `taru` |
| `tayran` | `darter` |
| `technical` | `technical` |
| `tempest` | `tempest` |
| `tempest_ammo` | `tempest_ammo` |
| `tempest_medical` | `tempest_medical` |
| `tempest_repair` | `tempest_repair` |
| `tigris` | `tigris` |
| `truck` | `truck` |
| `van_ambulance` | `van_ambulance` |
| `van_transport` | `van_transport` |
| `varsuk` | `varsuk` |
| `zamak` | `zamak` |
| `zamak_ammo` | `zamak_ammo` |
| `zamak_medical` | `zamak_medical` |
| `zamak_mrl` | `zamak_mrl` |
| `zamak_repair` | `zamak_repair` |

## Models

### a10

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.dispenser`, `VehicleAircraft.fin_set`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.pod`, `VehicleAircraft.refuel_receptacle`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.filler`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.digit_quads`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMarkings.stroke_quads`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.rotary`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmAttack._a10:288](../scripts\game\vehicles\vm_attack.gd#L288)
- Compass Ghost: the darker grey over the nose and cockpit, down the spine ó [VmAttack._a10:314](../scripts\game\vehicles\vm_attack.gd#L314)
- panel joints round the fuselage ó [VmAttack._a10:317](../scripts\game\vehicles\vm_attack.gd#L317)

**Local helper construction:** `VmAttack._a10_cockpit`, `VmAttack._a10_details`, `VmAttack._a10_engines`, `VmAttack._a10_gear`, `VmAttack._a10_gun`, `VmAttack._a10_stores`, `VmAttack._a10_tail`, `VmAttack._a10_wing`, `VmAttack._decal`, `VmAttack._ecm_pod`, `VmAttack._fin_at`, `VmAttack._gear_nodes`, `VmAttack._lathe`, `VmAttack._sec_pt`, `VmAttack._skin_x`, `VmAttack._skin_y`, `VmAttack._sniper`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmPlane._foil_t`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### aa_tech, technical

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCargo.crate_stack`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.vessel`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.roll_bar`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.gun_shield`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.pedestal`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.autocannon`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._hilux:981](../scripts\game\vehicles\vm_core.gd#L981)
- A burning pickup keeps its original finish away from the bonnet. ó [VmCore._hilux:982](../scripts\game\vehicles\vm_core.gd#L982)
- ladder frame, the front diff and the rear axle, the exhaust, fuel tank ó [VmCore._hilux:992](../scripts\game\vehicles\vm_core.gd#L992)
- (the exhaust hangs from the right frame rail, 5 cm over its centre line) ó [VmCore._hilux:998](../scripts\game\vehicles\vm_core.gd#L998)
- the body: bonnet, front wings and the cab's lower half in one panel, the bed's sides in another, their arches cut round the wheels ó [VmCore._hilux:1001](../scripts\game\vehicles\vm_core.gd#L1001)
- the bed: its walls, the top rails, the wheel tubs, a ribbed floor ó [VmCore._hilux:1007](../scripts\game\vehicles\vm_core.gd#L1007)
- the tailgate hanging open on its chains, dented ó [VmCore._hilux:1016](../scripts\game\vehicles\vm_core.gd#L1016)
- the glasshouse: the windscreen raked well back, the four-door cab, its back window; the panes laid on its faces ó [VmCore._hilux:1020](../scripts\game\vehicles\vm_core.gd#L1020)
- the doors: shut lines, handles; one rear door a replacement in primer ó [VmCore._hilux:1035](../scripts\game\vehicles\vm_core.gd#L1035)
- mud up the sills and round the arches ó [VmCore._hilux:1043](../scripts\game\vehicles\vm_core.gd#L1043)
- wing mirrors at the windscreen's foot ó [VmCore._hilux:1045](../scripts\game\vehicles\vm_core.gd#L1045)
- arches flared in black, rust round the rear ones, the side step ó [VmCore._hilux:1047](../scripts\game\vehicles\vm_core.gd#L1047)
- tail lights up the bed's corners, set in its back face ó [VmCore._hilux:1054](../scripts\game\vehicles\vm_core.gd#L1054)
- brushed-on sand camouflage on some: blotches down the flanks ó [VmCore._hilux:1059](../scripts\game\vehicles\vm_core.gd#L1059)
- the face: grille, square headlights, indicators, a dented bumper and the pipe bull bar welded across it, the number plate long gone ó [VmCore._hilux:1066](../scripts\game\vehicles\vm_core.gd#L1066)
- the rear: a step bumper, the tow ball on it. (The ball's mount runs along the bumper's top from its plate, hidden in the bed's back panel; the box is 1/6 m tall for a ball 4 cm in radius, its crown 0.76 m up.) ó [VmCore._hilux:1077](../scripts\game\vehicles\vm_core.gd#L1077)
- wipers, a whip antenna on the wing ó [VmCore._hilux:1083](../scripts\game\vehicles\vm_core.gd#L1083)
- the roll bar behind the cab: the hoop and its stays back to the bed rails ó [VmCore._hilux:1087](../scripts\game\vehicles\vm_core.gd#L1087)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._bx`, `VmCore._dshk`, `VmCore._hilux_dshk`, `VmCore._jerry`, `VmCore._tube`, `VmCore._zu23`.

### ac130

**Shared:** `VehicleAircraft.dispenser`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.refuel_receptacle`, `VehicleAircraft.turbine_exhaust`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.stroke_triangles`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleSurface.plane`, `VehicleWeapons.muzzle_brake`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmGunship._ac130:308](../scripts\game\vehicles\vm_gunship.gd#L308)
- the fuselage: the radome, the flight deck, the long constant section of the cargo hold (belly 0.65 m up, roof 4.75 m), the upswept tail ó [VmGunship._ac130:311](../scripts\game\vehicles\vm_gunship.gd#L311)
- the radome's joint, frame joints down the fuselage ó [VmGunship._ac130:333](../scripts\game\vehicles\vm_gunship.gd#L333)
- the main gear sponsons along the lower sides ó [VmGunship._ac130:340](../scripts\game\vehicles\vm_gunship.gd#L340)
- the closed wheel-well doors under each sponson, the joint at its nose ó [VmGunship._ac130:346](../scripts\game\vehicles\vm_gunship.gd#L346)
- the chaff and flare dispensers in the sponson's tail ó [VmGunship._ac130:351](../scripts\game\vehicles\vm_gunship.gd#L351)
- the wing on top: a constant-chord centre section out past the inboard engines, tapered outer panels with 2.5 degrees of dihedral; Fowler flaps inboard, ailerons outboard ó [VmGunship._ac130:353](../scripts\game\vehicles\vm_gunship.gd#L353)
- the fairing over the wing root on top of the fuselage ó [VmGunship._ac130:362](../scripts\game\vehicles\vm_gunship.gd#L362)
- the engines: long T56 nacelles slung under the wing, four-blade props ó [VmGunship._ac130:365](../scripts\game\vehicles\vm_gunship.gd#L365)
- the tail: the stabiliser with its elevators, the fin and rudder, the dorsal fillet running forward along the top ó [VmGunship._ac130:378](../scripts\game\vehicles\vm_gunship.gd#L378)
- the tail cone: the white tail light looking aft off its tip, the warning sensors either side ó [VmGunship._ac130:385](../scripts\game\vehicles\vm_gunship.gd#L385)
- the anti-collision beacons, low flattened domes on the roof and the belly; the antennas, the SATCOM dome ó [VmGunship._ac130:391](../scripts\game\vehicles\vm_gunship.gd#L391)
- the formation lights: pale green strips on the nose, the tail and the fin ó [VmGunship._ac130:400](../scripts\game\vehicles\vm_gunship.gd#L400)
- the strips on the fuselage's sides follow its curve: [z, from height, to height] ó [VmGunship._ac130:403](../scripts\game\vehicles\vm_gunship.gd#L403)
- markings: the black outline insignia aft and on the wings, team panels ó [VmGunship._ac130:410](../scripts\game\vehicles\vm_gunship.gd#L410)
- the tail number: the fiscal year small, the serial under it ó [VmGunship._ac130:419](../scripts\game\vehicles\vm_gunship.gd#L419)

**Local helper construction:** `VmGunship._ac130_cockpit`, `VmGunship._ac130_doors`, `VmGunship._ac130_gear`, `VmGunship._ac130_guns`, `VmGunship._ang`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._insignia_tris`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._shift`, `VmGunship._t56`, `VmGunship._text_tris`, `VmGunship._tyre`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### angara, angara_k

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.track_guard`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.launch_tube`, `VehicleWeapons.mmg`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._angara:1089](../scripts\game\vehicles\vm_csat.gd#L1089)
- the gun slot and mask, the 125 mm, the coax ó [VmCsat._angara:1096](../scripts\game\vehicles\vm_csat.gd#L1096)
- Afghanit: five launch tubes in a housing low on each flank, firing out ó [VmCsat._angara:1102](../scripts\game\vehicles\vm_csat.gd#L1102)
- each tube's mouth angled out of the housing and a little forward ó [VmCsat._angara:1105](../scripts\game\vehicles\vm_csat.gd#L1105)
- radar panels on the corners, each aperture facing out ó [VmCsat._angara:1111](../scripts\game\vehicles\vm_csat.gd#L1111)
- the soft-kill smoke launchers on the roof ó [VmCsat._angara:1116](../scripts\game\vehicles\vm_csat.gd#L1116)
- the gunner's sight (front left) and the commander's panoramic sight ó [VmCsat._angara:1122](../scripts\game\vehicles\vm_csat.gd#L1122)
- the remote weapon on top: a 12.7 mm, or the command tank's 30 mm turret ó [VmCsat._angara:1125](../scripts\game\vehicles\vm_csat.gd#L1125)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._era`, `VmCsat._face_rot`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._periscope`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._slats`, `VmCsat._sprocket`, `VmCsat._t14`, `VmCsat._taillight`, `VmCsat._tow`.

### apc, btr

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.piano_hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.trim_vane`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._btr80:1311](../scripts\game\vehicles\vm_core.gd#L1311)
- the hull: belly, the wheel wells' roof, the crease, the upper sides ó [VmCore._btr80:1316](../scripts\game\vehicles\vm_core.gd#L1316)
- the wheels on their axles, the wells' dark liners, mud flaps ó [VmCore._btr80:1324](../scripts\game\vehicles\vm_core.gd#L1324)
- the bow: the trim vane folded against the lower bow plate, tow hooks, a splash rail across the stem ó [VmCore._btr80:1331](../scripts\game\vehicles\vm_core.gd#L1331)
- the upper glacis and the window plate: the driver's and commander's windows with their shutters propped open, the lights in guards on the corners, the IR light on the left ó [VmCore._btr80:1342](../scripts\game\vehicles\vm_core.gd#L1342)
- the shutter hinged at the top, propped up and out ó [VmCore._btr80:1355](../scripts\game\vehicles\vm_core.gd#L1355)
- the roof: driver's and commander's hatches at the front, the troop hatches behind the turret, periscopes along the edges ó [VmCore._btr80:1361](../scripts\game\vehicles\vm_core.gd#L1361)
- the side doors between the second and third axles: the upper half in the sloped side, the lower half below the crease; firing ports, the stowage boxes and the exhausts aft, tow cable ó [VmCore._btr80:1368](../scripts\game\vehicles\vm_core.gd#L1368)
- the upper half hinged on its front edge, its firing port ó [VmCore._btr80:1376](../scripts\game\vehicles\vm_core.gd#L1376)
- the lower half, below the crease, folding down into a step on its long bottom hinge (its sealed face outboard on either side) ó [VmCore._btr80:1379](../scripts\game\vehicles\vm_core.gd#L1379)
- the stowage box on the sloped side, its lid hinged along the top ó [VmCore._btr80:1385](../scripts\game\vehicles\vm_core.gd#L1385)
- the engine deck: the louvred grilles, the access panels ó [VmCore._btr80:1390](../scripts\game\vehicles\vm_core.gd#L1390)
- the stern: the water-jet's flap, tail lights, tow hooks, the antenna ó [VmCore._btr80:1393](../scripts\game\vehicles\vm_core.gd#L1393)
- --- the BPU-1 turret: a low cone, the mantlet, the KPVT and the PKT ó [VmCore._btr80:1400](../scripts\game\vehicles\vm_core.gd#L1400)
- the KPVT: the heavy jacket over its rear third, the bare barrel, the muzzle brake; the coaxial PKT's port to its right ó [VmCore._btr80:1409](../scripts\game\vehicles\vm_core.gd#L1409)
- the gunner's sight on the left of the roof, a vision block right, the hatch ó [VmCore._btr80:1414](../scripts\game\vehicles\vm_core.gd#L1414)
- six smoke dischargers in a row across the back, firing over the turret ó [VmCore._btr80:1418](../scripts\game\vehicles\vm_core.gd#L1418)

**Local helper construction:** `VmCore._antenna`, `VmCore._bx`, `VmCore._cam`, `VmCore._hatch`, `VmCore._lamp`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._shackle`, `VmCore._taillight`.

### assault_boat

**Shared:** `VehicleBody.drum`, `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._zodiac:464](../scripts\game\vehicles\vm_boat.gd#L464)
- the tube's centreline: straight sides into a round bow that kicks up ó [VmBoat._zodiac:469](../scripts\game\vehicles\vm_boat.gd#L469)
- the tube ends: cones past the transom ó [VmBoat._zodiac:480](../scripts\game\vehicles\vm_boat.gd#L480)
- compartment seams round the tube ó [VmBoat._zodiac:483](../scripts\game\vehicles\vm_boat.gd#L483)
- inflation valves on top ó [VmBoat._zodiac:487](../scripts\game\vehicles\vm_boat.gd#L487)
- the hull: a shallow V of fabric under a flat floor, rising into the bow ó [VmBoat._zodiac:491](../scripts\game\vehicles\vm_boat.gd#L491)
- aluminium floorboards ó [VmBoat._zodiac:500](../scripts\game\vehicles\vm_boat.gd#L500)
- the transom with its knees and the motor pad ó [VmBoat._zodiac:503](../scripts\game\vehicles\vm_boat.gd#L503)
- 55 hp outboard on a tiller, its fuel tank and hose ó [VmBoat._zodiac:508](../scripts\game\vehicles\vm_boat.gd#L508)
- two paddles along the tubes, a rucksack and a dry bag lashed amidships ó [VmBoat._zodiac:517](../scripts\game\vehicles\vm_boat.gd#L517)
- the bow's towing ring and grab handle ó [VmBoat._zodiac:525](../scripts\game\vehicles\vm_boat.gd#L525)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._foil`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._tube`, `VmBoat._tube_kit`.

### blackfish, blackfish_armed

**Shared:** `VehicleAircraft.dispenser`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.turbine_exhaust`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleSurface.plane`, `VehicleWeapons.muzzle_brake`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmGunship._blackfish:616](../scripts\game\vehicles\vm_gunship.gd#L616)
- the blue underside, up to a line along the lower flanks ó [VmGunship._blackfish:640](../scripts\game\vehicles\vm_gunship.gd#L640)
- the sponsons: the main gear, fuel, the chaff and flare dispensers ó [VmGunship._blackfish:647](../scripts\game\vehicles\vm_gunship.gd#L647)
- the wing: straight, a touch of forward sweep, thick; flaperons along it ó [VmGunship._blackfish:657](../scripts\game\vehicles\vm_gunship.gd#L657)
- the fairing over the wing's centre section ó [VmGunship._blackfish:663](../scripts\game\vehicles\vm_gunship.gd#L663)
- the nacelles on their tilt pivots at the tips, the proprotors (the right one a mirror image, turning the other way) ó [VmGunship._blackfish:666](../scripts\game\vehicles\vm_gunship.gd#L666)
- the dorsal spine from the wing back to the tail, the formation lights ó [VmGunship._blackfish:679](../scripts\game\vehicles\vm_gunship.gd#L679)
- the targeting turret on its neck under the nose, antennas, the beacons ó [VmGunship._blackfish:690](../scripts\game\vehicles\vm_gunship.gd#L690)
- team panels on the wings and the tail ó [VmGunship._blackfish:701](../scripts\game\vehicles\vm_gunship.gd#L701)

**Local helper construction:** `VmGunship._ang`, `VmGunship._bf_cockpit`, `VmGunship._bf_doors`, `VmGunship._bf_gear`, `VmGunship._bf_guns`, `VmGunship._bf_nacelle`, `VmGunship._bf_tail`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._tyre`, `VmGunship._under`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### blackfoot

**Shared:** `VehicleAircraft.chin_turret`, `VehicleAircraft.cone`, `VehicleAircraft.fin_set`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.tailwheel`, `VehicleAircraft.trailing_gear`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleSurface.plane`, `VehicleWeapons.rotary`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._blackfoot:740](../scripts\game\vehicles\vm_heli.gd#L740)
- the stepped tandem canopy, framed, and the night-pilotage window ó [VmHeli._blackfoot:760](../scripts\game\vehicles\vm_heli.gd#L760)
- the bays, open; engine inlets; exhaust slots down the tail ó [VmHeli._blackfoot:767](../scripts\game\vehicles\vm_heli.gd#L767)
- the mast fairing and mast ó [VmHeli._blackfoot:772](../scripts\game\vehicles\vm_heli.gd#L772)
- the fantail: a shroud with an open duct, a fin over it, the T-tail ó [VmHeli._blackfoot:776](../scripts\game\vehicles\vm_heli.gd#L776)
- tailwheel under the boom ó [VmHeli._blackfoot:786](../scripts\game\vehicles\vm_heli.gd#L786)
- main gear legs out of their stubs: trailing beams and struts, six-sided hub covers ó [VmHeli._blackfoot:790](../scripts\game\vehicles\vm_heli.gd#L790)
- the bay doors opened out: three Hellfires on rails under each ó [VmHeli._blackfoot:795](../scripts\game\vehicles\vm_heli.gd#L795)
- the chin turret: XM301 three-barrel 20 mm, its faceted drum and the gun's cradle tucked under it ó [VmHeli._blackfoot:804](../scripts\game\vehicles\vm_heli.gd#L804)
- the barrels out of the receiver, one on top, clamped near the breech and at the muzzles ó [VmHeli._blackfoot:808](../scripts\game\vehicles\vm_heli.gd#L808)
- pitots and an antenna ó [VmHeli._blackfoot:812](../scripts\game\vehicles\vm_heli.gd#L812)
- the rotor: five blades with swept tips, a faceted hub shroud ó [VmHeli._blackfoot:816](../scripts\game\vehicles\vm_heli.gd#L816)

**Local helper construction:** `VmHeli._air`, `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rotor`, `VmHeli._skin`.

### blackwasp

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`.

**Authored sections:**

- Unlabelled construction / setup ó [VmFighter._blackwasp:952](../scripts\game\vehicles\vm_fighter.gd#L952)
- --- fuselage: [z, crown, shoulder x y, chine x y half-thickness, LEX underside corner x y, side wall foot x y, belly corner x y, keel] ó [VmFighter._blackwasp:961](../scripts\game\vehicles\vm_fighter.gd#L961)
- the F-22-style one-piece canopy, gold-coated, its sill frame ó [VmFighter._blackwasp:985](../scripts\game\vehicles\vm_fighter.gd#L985)
- The cockpit rim, seat back and pilot share the hull mesh underneath the glass. ó [VmFighter._blackwasp:995](../scripts\game\vehicles\vm_fighter.gd#L995)
- --- intakes and engine nacelles: caret mouths raked in two planes, the ducts turning round into the engines, the nozzles ó [VmFighter._blackwasp:1008](../scripts\game\vehicles\vm_fighter.gd#L1008)
- the nozzle: a hollow can, short sawtooth teeth round its lip, the flame holder deep inside ó [VmFighter._blackwasp:1027](../scripts\game\vehicles\vm_fighter.gd#L1027)
- --- wing: trapezoid, LE flaps, flaperons inboard, ailerons outboard ó [VmFighter._blackwasp:1041](../scripts\game\vehicles\vm_fighter.gd#L1041)
- diamond stabilators on the tail shelves ó [VmFighter._blackwasp:1045](../scripts\game\vehicles\vm_fighter.gd#L1045)
- twin fins canted 22 degrees out, rudders ó [VmFighter._blackwasp:1047](../scripts\game\vehicles\vm_fighter.gd#L1047)
- --- details: the gun port in the right LEX, the EOTS window under the nose, the tail hook, antennas, lights ó [VmFighter._blackwasp:1054](../scripts\game\vehicles\vm_fighter.gd#L1054)
- the arrestor hook stowed between the nozzles, its point showing ó [VmFighter._blackwasp:1069](../scripts\game\vehicles\vm_fighter.gd#L1069)
- --- panel lines: the weapon bay doors and the gear doors (sawtooth ends), the radome joint, access panels on the deck ó [VmFighter._blackwasp:1084](../scripts\game\vehicles\vm_fighter.gd#L1084)
- the radome joint: a sawtooth across the chined nose ó [VmFighter._blackwasp:1106](../scripts\game\vehicles\vm_fighter.gd#L1106)
- deck access panels and the fuel tank doors over the LEX ó [VmFighter._blackwasp:1110](../scripts\game\vehicles\vm_fighter.gd#L1110)
- the side weapon bays in the intake walls, the engine bay doors under the nacelles, the refuelling probe's door on the right of the nose ó [VmFighter._blackwasp:1118](../scripts\game\vehicles\vm_fighter.gd#L1118)
- radar-absorbent dark caps on the fin tips ó [VmFighter._blackwasp:1139](../scripts\game\vehicles\vm_fighter.gd#L1139)
- --- markings: low-visibility Navy star-and-bar, the air wing's tail code, the modex on the nose ó [VmFighter._blackwasp:1144](../scripts\game\vehicles\vm_fighter.gd#L1144)
- --- landing gear (shown on the ground): twin nose wheels with the catapult launch bar, the main legs out of the intake trunks, open doors ó [VmFighter._blackwasp:1161](../scripts\game\vehicles\vm_fighter.gd#L1161)

**Local helper construction:** `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._bw_half`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._cloop`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._ft`, `VmFighter._gear_door`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._loop`, `VmFighter._mesh`, `VmFighter._mixloop`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._project`, `VmFighter._put`, `VmFighter._qloop`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmFighter._zigzag`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### bobcat

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.crane`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._bobcat:1152](../scripts\game\vehicles\vm_nato.gd#L1152)
- the dozer blade, raised for travel: a curved mouldboard of three facets, its cutting edge, the push arms and the lifting rams ó [VmNato._bobcat:1155](../scripts\game\vehicles\vm_nato.gd#L1155)
- the crane: its slewing base on the roof's back right, the boom folded forward along the right side on its luffing ram, the inner boom run out onto a rest, the hook stowed at the boom's head ó [VmNato._bobcat:1169](../scripts\game\vehicles\vm_nato.gd#L1169)
- the main winch drum at the back of the roof, tow bars and tools ó [VmNato._bobcat:1177](../scripts\game\vehicles\vm_nato.gd#L1177)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### buzzard

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.duct`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleWeapons.autocannon`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._buzzard:480](../scripts\game\vehicles\vm_plane.gd#L480)
- the radome a shade darker, a joint band behind it ó [VmPlane._buzzard:500](../scripts\game\vehicles\vm_plane.gd#L500)
- dorsal spine from the canopy to the fin ó [VmPlane._buzzard:503](../scripts\game\vehicles\vm_plane.gd#L503)
- the canopy: windscreen and bubble, its bows ó [VmPlane._buzzard:505](../scripts\game\vehicles\vm_plane.gd#L505)
- the intakes: D-shaped mouths standing off the fuselage on splitter plates ó [VmPlane._buzzard:511](../scripts\game\vehicles\vm_plane.gd#L511)
- the wing: tapered, a little dihedral, flaps and ailerons ó [VmPlane._buzzard:520](../scripts\game\vehicles\vm_plane.gd#L520)
- tip tanks with their navigation lights ó [VmPlane._buzzard:523](../scripts\game\vehicles\vm_plane.gd#L523)
- tailplane and fin (rudder, elevators), the dorsal fillet ó [VmPlane._buzzard:528](../scripts\game\vehicles\vm_plane.gd#L528)
- the jet pipe ó [VmPlane._buzzard:533](../scripts\game\vehicles\vm_plane.gd#L533)
- probes, antennas, the airbrakes under the belly ó [VmPlane._buzzard:536](../scripts\game\vehicles\vm_plane.gd#L536)
- stores: gun pod on the centreline; bombs, rocket pods, Sidewinders ó [VmPlane._buzzard:542](../scripts\game\vehicles\vm_plane.gd#L542)
- national markings ó [VmPlane._buzzard:558](../scripts\game\vehicles\vm_plane.gd#L558)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### caesar

**Shared:** `VehicleAircraft.pitot`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._caesar:659](../scripts\game\vehicles\vm_plane.gd#L659)
- the livery: a stripe down each flank, a pinstripe above it ó [VmPlane._caesar:676](../scripts\game\vehicles\vm_plane.gd#L676)
- the cabin: a glass house, its pillars and a painted roof ó [VmPlane._caesar:682](../scripts\game\vehicles\vm_plane.gd#L682)
- door seams: the gull-wing doors' front and back edges, traced down the flank as it curves in under the cabin rather than standing straight off it ó [VmPlane._caesar:690](../scripts\game\vehicles\vm_plane.gd#L690)
- cowl inlets and exhaust stacks, the landing light ó [VmPlane._caesar:699](../scripts\game\vehicles\vm_plane.gd#L699)
- the wing: low, tapered, dihedral, flaps and ailerons, upturned tips ó [VmPlane._caesar:703](../scripts\game\vehicles\vm_plane.gd#L703)
- tail: the swept fin and the stabiliser ó [VmPlane._caesar:708](../scripts\game\vehicles\vm_plane.gd#L708)
- fixed tricycle gear: a nose leg, spring-steel mains, wheels in spats ó [VmPlane._caesar:712](../scripts\game\vehicles\vm_plane.gd#L712)
- the propeller: three blades with painted tips, the spinner ó [VmPlane._caesar:721](../scripts\game\vehicles\vm_plane.gd#L721)
- antennas on the roof and belly, the pitot under the left wing ó [VmPlane._caesar:723](../scripts\game\vehicles\vm_plane.gd#L723)

**Local helper construction:** `VmPlane._flank`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`.

### cheetah

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._cheetah:1191](../scripts\game\vehicles\vm_nato.gd#L1191)
- a 35 mm on each flank: the trunnion housing, the cradle, the long barrel with its muzzle velocity radar ring and brake ó [VmNato._cheetah:1200](../scripts\game\vehicles\vm_nato.gd#L1200)
- the ammunition feed chute and the missile box above the gun ó [VmNato._cheetah:1209](../scripts\game\vehicles\vm_nato.gd#L1209)
- four rounds, mounted by its inboard face on the bracket ó [VmNato._cheetah:1211](../scripts\game\vehicles\vm_nato.gd#L1211)
- the tracking radar (a dish in a drum) on the front of the roof, the optics beside it ó [VmNato._cheetah:1216](../scripts\game\vehicles\vm_nato.gd#L1216)
- hatches, the search radar on its folding mast at the back ó [VmNato._cheetah:1221](../scripts\game\vehicles\vm_nato.gd#L1221)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### civilian_0, civilian_1, civilian_2, civilian_3, civilian_4

**Shared:** `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleCargo.sideboard`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.mirror`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VehicleModels._car:735](../scripts\game\vehicle_models.gd#L735)
- glass: windscreen, rear screen, side windows (inset a touch) ó [VehicleModels._car:759](../scripts\game\vehicle_models.gd#L759)
- the wing mirror on its arm from the window's front corner, the door handle ó [VehicleModels._car:780](../scripts\game\vehicle_models.gd#L780)
- moulded bumpers, lights, plate ó [VehicleModels._car:783](../scripts\game\vehicle_models.gd#L783)
- the bed: its sides, the ribbed tailgate between them, the rubber mat ó [VehicleModels._car:795](../scripts\game\vehicle_models.gd#L795)
- wheels in dark arches ó [VehicleModels._car:800](../scripts\game\vehicle_models.gd#L800)

### darter

**Shared:** `VehicleAircraft.skid_runner`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._darter:1437](../scripts\game\vehicles\vm_heli.gd#L1437)
- the X of arms, a motor and guard ring at each end ó [VmHeli._darter:1451](../scripts\game\vehicles\vm_heli.gd#L1451)
- lights under the motors: red on the left and green on the right up front, white aft ó [VmHeli._darter:1465](../scripts\game\vehicles\vm_heli.gd#L1465)
- the camera on its gimbal under the nose ó [VmHeli._darter:1472](../scripts\game\vehicles\vm_heli.gd#L1472)
- skids ó [VmHeli._darter:1476](../scripts\game\vehicles\vm_heli.gd#L1476)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._skin`, `VmHeli._tube`.

### demining_drone, utility_drone

**Shared:** `VehicleAircraft.skid_runner`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFrames.aim`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._hexa:1488](../scripts\game\vehicles\vm_heli.gd#L1488)
- the hub: a hexagonal frame, the dome, the battery under it ó [VmHeli._hexa:1495](../scripts\game\vehicles\vm_heli.gd#L1495)
- six arms, alternately turning props, orientation colours on the front pair ó [VmHeli._hexa:1503](../scripts\game\vehicles\vm_heli.gd#L1503)
- skids on two legs each ó [VmHeli._hexa:1514](../scripts\game\vehicles\vm_heli.gd#L1514)
- a rack of four demolition charges and the ground-scanning sensor ó [VmHeli._hexa:1520](../scripts\game\vehicles\vm_heli.gd#L1520)
- the cargo box on its release hook ó [VmHeli._hexa:1533](../scripts\game\vehicles\vm_heli.gd#L1533)

**Local helper construction:** `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._tube`.

### ed1

**Shared:** `VehicleBody.drum`, `VehicleBody.paint_mesh`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._ed1:1386](../scripts\game\vehicles\vm_civ.gd#L1386)
- the flippers, swung forward and up off the front sprockets ó [VmCiv._ed1:1398](../scripts\game\vehicles\vm_civ.gd#L1398)
- carry handles on the hull sides ó [VmCiv._ed1:1403](../scripts\game\vehicles\vm_civ.gd#L1403)
- the payload box at the back ó [VmCiv._ed1:1408](../scripts\game\vehicles\vm_civ.gd#L1408)
- the arm, folded: turntable, shoulder, upper arm back, forearm forward ó [VmCiv._ed1:1411](../scripts\game\vehicles\vm_civ.gd#L1411)
- the sensor head: cameras and a light, the gripper's jaws under it ó [VmCiv._ed1:1422](../scripts\game\vehicles\vm_civ.gd#L1422)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._xbody`.

### falcon

**Shared:** `VehicleAircraft.cone`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.missile`, `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._falcon:1348](../scripts\game\vehicles\vm_heli.gd#L1348)
- panel seams and access hatches (no windows: nobody aboard) ó [VmHeli._falcon:1364](../scripts\game\vehicles\vm_heli.gd#L1364)
- the engine fairing on the back, its intake and exhaust; the mast ó [VmHeli._falcon:1369](../scripts\game\vehicles\vm_heli.gd#L1369)
- the boom, fins, stabiliser, the tail rotor on the left ó [VmHeli._falcon:1376](../scripts\game\vehicles\vm_heli.gd#L1376)
- the sensor ball hanging on its neck under the nose, antennas, the datalink dome ó [VmHeli._falcon:1383](../scripts\game\vehicles\vm_heli.gd#L1383)
- skids ó [VmHeli._falcon:1390](../scripts\game\vehicles\vm_heli.gd#L1390)
- stub wings with two pylons a side, a small missile on each ó [VmHeli._falcon:1392](../scripts\game\vehicles\vm_heli.gd#L1392)
- the rotor: four blades ó [VmHeli._falcon:1400](../scripts\game\vehicles\vm_heli.gd#L1400)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._skin`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### fenghuang

**Shared:** `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.missile`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._fenghuang:1013](../scripts\game\vehicles\vm_plane.gd#L1013)
- canards with elevators; the main wing with ailerons; fins at its tips ó [VmPlane._fenghuang:1028](../scripts\game\vehicles\vm_plane.gd#L1028)
- the engine's air scoop on top, the exhaust, the pusher propeller ó [VmPlane._fenghuang:1033](../scripts\game\vehicles\vm_plane.gd#L1033)
- the sensor ball on its neck, one window looking forward ó [VmPlane._fenghuang:1039](../scripts\game\vehicles\vm_plane.gd#L1039)
- fixed tricycle gear ó [VmPlane._fenghuang:1041](../scripts\game\vehicles\vm_plane.gd#L1041)
- antennas: the satcom blade, a whip raked back under the belly ó [VmPlane._fenghuang:1047](../scripts\game\vehicles\vm_plane.gd#L1047)
- four small missiles, two under each wing ó [VmPlane._fenghuang:1050](../scripts\game\vehicles\vm_plane.gd#L1050)

**Local helper construction:** `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### fia_truck, fia_truck_box

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.mesh_glass`, `VehicleCargo.body_door`, `VehicleCargo.flatbed`, `VehicleCargo.rung_ladder`, `VehicleCargo.shelter`, `VehicleCargo.sideboard`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.vessel`, `VehicleEquipment.winch`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.marker`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleGlazing.rectangle`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._truck:625](../scripts\game\vehicles\vm_civ.gd#L625)
- ladder frame, beam axles with their diffs, fuel tank, battery box ó [VmCiv._truck:633](../scripts\game\vehicles\vm_civ.gd#L633)
- the exhaust outboard of the right rail, its end open under the bed ó [VmCiv._truck:643](../scripts\game\vehicles\vm_civ.gd#L643)
- the cab over the front wheels, the short nose in front of it ó [VmCiv._truck:645](../scripts\game\vehicles\vm_civ.gd#L645)
- the cab's back window in its rubber seal ó [VmCiv._truck:651](../scripts\game\vehicles\vm_civ.gd#L651)
- shut lines, handle, the steps behind the wheel, mirrors on long arms ó [VmCiv._truck:656](../scripts\game\vehicles\vm_civ.gd#L656)
- black flares on the front arch, mudflaps ó [VmCiv._truck:666](../scripts\game\vehicles\vm_civ.gd#L666)
- the rear wheel's mudguard under the bed ó [VmCiv._truck:671](../scripts\game\vehicles\vm_civ.gd#L671)
- headlights in the nose corners (the cluster lens, the main beam inboard in it), indicators, roof markers ó [VmCiv._truck:673](../scripts\game\vehicles\vm_civ.gd#L673)
- grille between the lamps, 3 cm proud of the leaning nose; the 4x4's steel bumper with a winch, the tow hooks painted red under it, plate ó [VmCiv._truck:679](../scripts\game\vehicles\vm_civ.gd#L679)
- the radio whip on the cab roof's left back corner ó [VmCiv._truck:690](../scripts\game\vehicles\vm_civ.gd#L690)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._truck_bed`, `VmCiv._truck_box`, `VmCiv._truck_rear`, `VmCiv._xbody`.

### futura

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.track_guard`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleEquipment.vessel`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._futura:926](../scripts\game\vehicles\vm_csat.gd#L926)
- seams of the panels on the faceted roof ó [VmCsat._futura:934](../scripts\game\vehicles\vm_csat.gd#L934)
- the railgun: a boxy shroud round the breech end, two flat rails ahead held by spacer bands, an open frame at the muzzle ó [VmCsat._futura:937](../scripts\game\vehicles\vm_csat.gd#L937)
- the capacitor bank and its cooling vents at the back ó [VmCsat._futura:951](../scripts\game\vehicles\vm_csat.gd#L951)
- sights: the gunner's block, the commander's panoramic head, a remote MG ó [VmCsat._futura:957](../scripts\game\vehicles\vm_csat.gd#L957)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### ghosthawk, ghosthawk_stub

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.tailwheel`, `VehicleAircraft.trailing_gear`, `VehicleAircraft.wire_cutter`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.pull`, `VehicleDoors.slide_rail`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._ghost_hawk:527](../scripts\game\vehicles\vm_heli.gd#L527)
- windscreens: the front panes over the nose, the cockpit door windows ó [VmHeli._ghost_hawk:546](../scripts\game\vehicles\vm_heli.gd#L546)
- door seams, the gunners' windows (open), the sliding cabin doors ó [VmHeli._ghost_hawk:552](../scripts\game\vehicles\vm_heli.gd#L552)
- the top fairing over the gearbox, the engines either side of it ó [VmHeli._ghost_hawk:559](../scripts\game\vehicles\vm_heli.gd#L559)
- the shrouded exhausts, turned out and up ó [VmHeli._ghost_hawk:565](../scripts\game\vehicles\vm_heli.gd#L565)
- mast, swashplate, the IR jammer behind, wire cutters, pitots ó [VmHeli._ghost_hawk:568](../scripts\game\vehicles\vm_heli.gd#L568)
- steps, the cabin door's grab handle, the navigation lights ó [VmHeli._ghost_hawk:575](../scripts\game\vehicles\vm_heli.gd#L575)
- the tail pylon, the canted tail rotor high on its right, the stabilator ó [VmHeli._ghost_hawk:579](../scripts\game\vehicles\vm_heli.gd#L579)
- the tailwheel on its leg and drag brace ó [VmHeli._ghost_hawk:594](../scripts\game\vehicles\vm_heli.gd#L594)
- main gear: drag beams and shock struts under faceted fairings, faceted hub covers ó [VmHeli._ghost_hawk:597](../scripts\game\vehicles\vm_heli.gd#L597)
- door guns: miniguns on pintles in the gunners' windows ó [VmHeli._ghost_hawk:602](../scripts\game\vehicles\vm_heli.gd#L602)
- the External Stores Support System: anhedral stub wings over the cabin's rear, braced to the floor, two pylons and two pods a side ó [VmHeli._ghost_hawk:610](../scripts\game\vehicles\vm_heli.gd#L610)
- the rotor: four blades with swept tips under a faceted hub cap ó [VmHeli._ghost_hawk:621](../scripts\game\vehicles\vm_heli.gd#L621)

**Local helper construction:** `VmHeli._air`, `VmHeli._door_rail`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skin`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### gorgon

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.trim_vane`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.launch_tube`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._gorgon:677](../scripts\game\vehicles\vm_indep.gd#L677)
- the V-shaped belly between the wheels, the upper hull over them ó [VmIndep._gorgon:683](../scripts\game\vehicles\vm_indep.gd#L683)
- the wheel well's dark liner under the overhang ó [VmIndep._gorgon:689](../scripts\game\vehicles\vm_indep.gd#L689)
- mud flaps behind the first and last axles ó [VmIndep._gorgon:691](../scripts\game\vehicles\vm_indep.gd#L691)
- the hull's side: a chine strake at mid height, stowage boxes aft, the side's lifting eyes ó [VmIndep._gorgon:694](../scripts\game\vehicles\vm_indep.gd#L694)
- headlight clusters with guards at the bow's corners, tow eyes ó [VmIndep._gorgon:700](../scripts\game\vehicles\vm_indep.gd#L700)
- rear: tail lights, tow eyes, a whip antenna on each corner ó [VmIndep._gorgon:703](../scripts\game\vehicles\vm_indep.gd#L703)
- the bow: the trim vane folded on the glacis on its hinges, latched at the top; it stands 3.5 cm off the plate, on the old plate's inner face ó [VmIndep._gorgon:707](../scripts\game\vehicles\vm_indep.gd#L707)
- roof: the driver's hatch and periscopes front-left, a mirror; the engine grille front-right; the exhaust on the right flank ó [VmIndep._gorgon:716](../scripts\game\vehicles\vm_indep.gd#L716)
- the exhaust's housing on the flank, its louvres on the outer face ó [VmIndep._gorgon:723](../scripts\game\vehicles\vm_indep.gd#L723)
- the troop compartment's roof hatches, aft, hinged at the back ó [VmIndep._gorgon:726](../scripts\game\vehicles\vm_indep.gd#L726)
- the rear door: vision block, handle, hinges; a step under it ó [VmIndep._gorgon:729](../scripts\game\vehicles\vm_indep.gd#L729)
- the turret: low and faceted, the 30 mm in its mantlet with the coax beside it, a Titan tube on each side ó [VmIndep._gorgon:738](../scripts\game\vehicles\vm_indep.gd#L738)
- the Titan tube on its bracket ó [VmIndep._gorgon:751](../scripts\game\vehicles\vm_indep.gd#L751)
- smoke dischargers on the front corners ó [VmIndep._gorgon:754](../scripts\game\vehicles\vm_indep.gd#L754)
- roof: the gunner's sight front-left, the commander's panoramic sight right, his hatch behind it ó [VmIndep._gorgon:757](../scripts\game\vehicles\vm_indep.gd#L757)
- a stowage basket on the turret's back ó [VmIndep._gorgon:764](../scripts\game\vehicles\vm_indep.gd#L764)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._ring`, `VmIndep._smoke`.

### greyhawk

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.hardpoint`, `VehicleAircraft.turbine_exhaust`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleEquipment.sensor`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.rod_mesh`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._greyhawk:894](../scripts\game\vehicles\vm_plane.gd#L894)
- the dish housing a shade lighter, its joint line ó [VmPlane._greyhawk:912](../scripts\game\vehicles\vm_plane.gd#L912)
- the sensor ball hanging on its neck under the nose, its windows looking forward ó [VmPlane._greyhawk:914](../scripts\game\vehicles\vm_plane.gd#L914)
- canards, the wing with flaps and ailerons ó [VmPlane._greyhawk:916](../scripts\game\vehicles\vm_plane.gd#L916)
- the Y tail: ruddervators up, the ventral fin down ó [VmPlane._greyhawk:921](../scripts\game\vehicles\vm_plane.gd#L921)
- the turboprop: dorsal NACA inlet, ventral scoop, exhaust stubs; the prop ó [VmPlane._greyhawk:924](../scripts\game\vehicles\vm_plane.gd#L924)
- antennas: the satcom blades, the belly whips ó [VmPlane._greyhawk:932](../scripts\game\vehicles\vm_plane.gd#L932)
- two pylons, a Paveway on each ó [VmPlane._greyhawk:936](../scripts\game\vehicles\vm_plane.gd#L936)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gryphon

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.duct`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.pod`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFittings.filler`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._gryphon:573](../scripts\game\vehicles\vm_plane.gd#L573)
- D-shaped intakes on splitter plates, the canards on their shoulders ó [VmPlane._gryphon:600](../scripts\game\vehicles\vm_plane.gd#L600)
- the cranked delta, elevons along its trailing edge ó [VmPlane._gryphon:610](../scripts\game\vehicles\vm_plane.gd#L610)
- the dogtooth: a small step in the leading edge ó [VmPlane._gryphon:613](../scripts\game\vehicles\vm_plane.gd#L613)
- tip rails with Sidewinders, navigation lights ó [VmPlane._gryphon:616](../scripts\game\vehicles\vm_plane.gd#L616)
- the fin with its rudder, a fairing at the tip ó [VmPlane._gryphon:621](../scripts\game\vehicles\vm_plane.gd#L621)
- the afterburner nozzle, airbrakes on the tail cone ó [VmPlane._gryphon:624](../scripts\game\vehicles\vm_plane.gd#L624)
- probes and antennas, the gun port low on the left ó [VmPlane._gryphon:629](../scripts\game\vehicles\vm_plane.gd#L629)
- stores: a centreline tank, Paveways inboard, Mavericks outboard ó [VmPlane._gryphon:636](../scripts\game\vehicles\vm_plane.gd#L636)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gun_trawler

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCargo.crate_stack`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarine.fender`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.pintle`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`.

**Authored sections:**

- Unlabelled construction / setup ó [VmShips._gun_trawler:867](../scripts\game\vehicles\vm_ships.gd#L867)
- the transom's bulwark across the stern ó [VmShips._gun_trawler:878](../scripts\game\vehicles\vm_ships.gd#L878)
- the keel bar and the stem bar running up the bow ó [VmShips._gun_trawler:882](../scripts\game\vehicles\vm_ships.gd#L882)
- the skeg under the run, the propeller in its aperture, the rudder ó [VmShips._gun_trawler:903](../scripts\game\vehicles\vm_ships.gd#L903)
- rubbing bands, bilge keels, the bulwark capping ó [VmShips._gun_trawler:911](../scripts\game\vehicles\vm_ships.gd#L911)
- freeing ports in the bulwarks with rust running from them, rust and primer patches, a replaced plate, the registration on the bows ó [VmShips._gun_trawler:928](../scripts\game\vehicles\vm_ships.gd#L928)
- the hawse pipe with the anchor in it and rust bleeding down ó [VmShips._gun_trawler:948](../scripts\game\vehicles\vm_ships.gd#L948)
- tyres hung over the side as fenders ó [VmShips._gun_trawler:957](../scripts\game\vehicles\vm_ships.gd#L957)
- --- the deckhouse, white and streaked, and the wheelhouse on it ó [VmShips._gun_trawler:964](../scripts\game\vehicles\vm_ships.gd#L964)
- the deckhouse: a door and portholes each side, rust under them, a ladder up the back to the boat deck, handrails round the roof ó [VmShips._gun_trawler:993](../scripts\game\vehicles\vm_ships.gd#L993)
- sidelights in their screens on the wheelhouse's shoulders ó [VmShips._gun_trawler:1006](../scripts\game\vehicles\vm_ships.gd#L1006)
- the funnel (black-topped, sooty), a liferaft canister, a boat-deck locker ó [VmShips._gun_trawler:1021](../scripts\game\vehicles\vm_ships.gd#L1021)
- --- the wheelhouse roof: the DShK, radar mast with its scanner, a searchlight, horn, whips, a loudhailer ó [VmShips._gun_trawler:1028](../scripts\game\vehicles\vm_ships.gd#L1028)
- --- the mast and its derrick, the trawl winch, the fish hold hatch ó [VmShips._gun_trawler:1041](../scripts\game\vehicles\vm_ships.gd#L1041)
- shrouds down to the bulwark ó [VmShips._gun_trawler:1048](../scripts\game\vehicles\vm_ships.gd#L1048)
- --- the foredeck: the ZU-23-2 on a welded plinth (the turret), ammo crates, sandbags along the bulwark, the windlass and the bow fairlead ó [VmShips._gun_trawler:1076](../scripts\game\vehicles\vm_ships.gd#L1076)
- (one more on the first, set down a little askew) ó [VmShips._gun_trawler:1091](../scripts\game\vehicles\vm_ships.gd#L1091)
- --- the after deck: the net drum, the gantry with its blocks, the trawl doors hung outboard, nets piled with floats, fish boxes, a dan buoy ó [VmShips._gun_trawler:1107](../scripts\game\vehicles\vm_ships.gd#L1107)
- a block hanging from the beam, the warp to it, the trawl door on its chains ó [VmShips._gun_trawler:1127](../scripts\game\vehicles\vm_ships.gd#L1127)
- nets heaped on the deck beside the drum, floats through them ó [VmShips._gun_trawler:1145](../scripts\game\vehicles\vm_ships.gd#L1145)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._dshk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._surf`, `VmShips._sweep`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._whip`, `VmShips._zu23`.

### gunship

**Shared:** `VehicleAircraft.chin_turret`, `VehicleAircraft.cone`, `VehicleAircraft.cowling`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.missile`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.tailwheel`, `VehicleAircraft.trailing_gear`, `VehicleAircraft.turbine_exhaust`, `VehicleAircraft.wire_cutter`, `VehicleBody.bead`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.autocannon`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._apache:1594](../scripts\game\vehicles\vm_core.gd#L1594)
- the stepped canopy: the gunner's low in front, the pilot's high behind, the blast shield between them; the fairing over the gearbox behind ó [VmCore._apache:1611](../scripts\game\vehicles\vm_core.gd#L1611)
- the avionics bays along the lower flanks, their access panel seams ó [VmCore._apache:1616](../scripts\game\vehicles\vm_core.gd#L1616)
- the radar warning receivers on the nose ó [VmCore._apache:1622](../scripts\game\vehicles\vm_core.gd#L1622)
- --- the nose: the TADS drum with its two sensor heads, the PNVS above ó [VmCore._apache:1624](../scripts\game\vehicles\vm_core.gd#L1624)
- wire cutters over the canopy and under the chin ó [VmCore._apache:1636](../scripts\game\vehicles\vm_core.gd#L1636)
- --- the engines either side of the gearbox fairing: the nacelles on their pylons, the dark intakes, the exhaust suppressors turned out ó [VmCore._apache:1639](../scripts\game\vehicles\vm_core.gd#L1639)
- --- stub wings: Hellfires outboard, rocket pods inboard, rails at the tips ó [VmCore._apache:1650](../scripts\game\vehicles\vm_core.gd#L1650)
- --- the tail: the swept fin, the tail rotor on its left, the stabilator low at the back, the tailwheel under the fin ó [VmCore._apache:1661](../scripts\game\vehicles\vm_core.gd#L1661)
- --- main gear: trailing arms off the bays, the shock struts ó [VmCore._apache:1670](../scripts\game\vehicles\vm_core.gd#L1670)
- --- the M230 chain gun in its turret under the chin, its feeder and ammunition chute on the right ó [VmCore._apache:1674](../scripts\game\vehicles\vm_core.gd#L1674)
- --- the mast, the rotor and the Longbow radar dome over it ó [VmCore._apache:1681](../scripts\game\vehicles\vm_core.gd#L1681)
- antennas along the boom ó [VmCore._apache:1688](../scripts\game\vehicles\vm_core.gd#L1688)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmHeli._canopy`, `VmHeli._hellfires`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._mx`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hatchback, hatchback_sport

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleDoors.pull`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.headlamp`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.silencer`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.quad`, `VehicleWheelArches.tub`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._hatch:987](../scripts\game\vehicles\vm_civ.gd#L987)
- glasshouse ó [VmCiv._hatch:1010](../scripts\game\vehicles\vm_civ.gd#L1010)
- the concept's panoramic glass roof ó [VmCiv._hatch:1018](../scripts\game\vehicles\vm_civ.gd#L1018)
- door shut lines (z, foot): front door, rear door, the rear one stopping on the wheel arch; the body-coloured handles ó [VmCiv._hatch:1033](../scripts\game\vehicles\vm_civ.gd#L1033)
- the face: swept lamps, a slim upper grille, the wide lower intake ó [VmCiv._hatch:1040](../scripts\game\vehicles\vm_civ.gd#L1040)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._glasshouse`, `VmCiv._hatch_sport`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._slab`, `VmCiv._xbody`.

### heli

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleAircraft.pod`, `VehicleAircraft.tailwheel`, `VehicleAircraft.tank_stations`, `VehicleAircraft.trailing_gear`, `VehicleAircraft.wire_cutter`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.slide_rail`, `VehicleFittings.dome_light`, `VehicleFittings.filler`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._blackhawk:1708](../scripts\game\vehicles\vm_core.gd#L1708)
- glazing: the two-pane windscreen, the eyebrow windows over it, the cockpit doors' windows, the gunners' windows, the cabin doors' windows ó [VmCore._blackhawk:1726](../scripts\game\vehicles\vm_core.gd#L1726)
- the frame between the windscreen panes, the door seams and the cabin door's rail, the steps ó [VmCore._blackhawk:1735](../scripts\game\vehicles\vm_core.gd#L1735)
- (the rail laid on the hull's skin either side, as VmHeli._patch lays a pane) ó [VmCore._blackhawk:1740](../scripts\game\vehicles\vm_core.gd#L1740)
- the nose: the radome's seam, pitots on the roof, the wire cutters ó [VmCore._blackhawk:1749](../scripts\game\vehicles\vm_core.gd#L1749)
- --- the roof: the gearbox fairing, the engines either side with their dark intakes and the exhaust suppressors turned out, the IR jammer ó [VmCore._blackhawk:1757](../scripts\game\vehicles\vm_core.gd#L1757)
- --- the mast and the rotor: swept tips, the bifilar absorber on the hub ó [VmCore._blackhawk:1772](../scripts\game\vehicles\vm_core.gd#L1772)
- --- the stores wings over the cabin's rear, braced to the floor, a fuel tank on each ó [VmCore._blackhawk:1776](../scripts\game\vehicles\vm_core.gd#L1776)
- --- the tail: the swept pylon, the canted tail rotor on its right, the stabilator, the antenna along the boom, the tailwheel ó [VmCore._blackhawk:1783](../scripts\game\vehicles\vm_core.gd#L1783)
- --- main gear: the drag beam and the shock strut to each wheel ó [VmCore._blackhawk:1800](../scripts\game\vehicles\vm_core.gd#L1800)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmCore._fuel_tank`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._skin`, `VmHeli._tail_rotor`, `VmHeli._tube`, `VmPlane._sp`, `VmPlane.band`, `VmPlane.body`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`.

### hellcat

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleAircraft.wire_cutter`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.slide_rail`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._hellcat:932](../scripts\game\vehicles\vm_heli.gd#L932)
- glazing: windscreen, chin windows, cockpit doors; the sliding doors ó [VmHeli._hellcat:951](../scripts\game\vehicles\vm_heli.gd#L951)
- the roof fairing, engines with side exhausts, mast ó [VmHeli._hellcat:960](../scripts\game\vehicles\vm_heli.gd#L960)
- the sensor turret standing on its neck on the nose, pitots, wire cutters ó [VmHeli._hellcat:967](../scripts\game\vehicles\vm_heli.gd#L967)
- the tail: pylon, tail rotor on its left, tailplane on its right ó [VmHeli._hellcat:972](../scripts\game\vehicles\vm_heli.gd#L972)
- skids and their steps ó [VmHeli._hellcat:980](../scripts\game\vehicles\vm_heli.gd#L980)
- weapon pylons: a minigun inboard, a rocket pod out ó [VmHeli._hellcat:986](../scripts\game\vehicles\vm_heli.gd#L986)
- The outer pylon runs past the wing's trailing edge, so it hangs flush under the skin rather than standing on a fairing. ó [VmHeli._hellcat:991](../scripts\game\vehicles\vm_heli.gd#L991)
- the rotor: four BERP blades on the compact hub, under its domed cap ó [VmHeli._hellcat:1000](../scripts\game\vehicles\vm_heli.gd#L1000)

**Local helper construction:** `VmHeli._door_rail`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._skin`, `VmHeli._tail_rotor`.

### hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.body_door`, `VehicleCargo.crate_stack`, `VehicleCargo.flatbed`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.roller_shutter`, `VehicleCargo.rung_ladder`, `VehicleCargo.shelter`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.drum`, `VehicleEquipment.pump_cabinet`, `VehicleEquipment.tanker_top`, `VehicleEquipment.vessel`, `VehicleFittings.air_cleaner`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.marker`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarkings.cross`, `VehicleMarkings.cross_outline`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.bumper`, `VehicleMounts.crane`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._hemtt:1383](../scripts\game\vehicles\vm_nato.gd#L1383)
- the deck on its frame with its drop sides, six stake posts a side, the tailgate and the tall headboard, then the rear end ó [VmNato._hemtt:1390](../scripts\game\vehicles\vm_nato.gd#L1390)
- the canvas tilt over its bows, the back rolled up over the benches ó [VmNato._hemtt:1396](../scripts\game\vehicles\vm_nato.gd#L1396)
- the troop benches facing in, on folding legs, hinged to the sides ó [VmNato._hemtt:1404](../scripts\game\vehicles\vm_nato.gd#L1404)
- the boarding step under the tailgate ó [VmNato._hemtt:1408](../scripts\game\vehicles\vm_nato.gd#L1408)
- palletised crates and boxes lashed down, a tarp over one load ó [VmNato._hemtt:1411](../scripts\game\vehicles\vm_nato.gd#L1411)
- ammunition: pallets of boxes, four to a pallet and strapped down (plain pallet boards: slatted ones under ten stacks cost too many vertices), then the knuckle-boom crane at the back, folded forward over the load ó [VmNato._hemtt:1421](../scripts\game\vehicles\vm_nato.gd#L1421)
- the crane on its slewing ring and column with the main boom's luffing ram; the knuckle boom folded back under it, the hook at its end ó [VmNato._hemtt:1431](../scripts\game\vehicles\vm_nato.gd#L1431)
- the shelter: a tall square box body with plain sides, its rails and markers; the workshop has a ladder up the back and roof vents ó [VmNato._hemtt:1443](../scripts\game\vehicles\vm_nato.gd#L1443)
- roll-up shutters; the tool lockers hang under the deck between the axles, behind the fuel tank and battery box and clear of the tandem's wheels ó [VmNato._hemtt:1449](../scripts\game\vehicles\vm_nato.gd#L1449)
- the light mast, AC unit, the rear door ó [VmNato._hemtt:1455](../scripts\game\vehicles\vm_nato.gd#L1455)
- windows, the rear doors with a step, roof vents, red crosses ó [VmNato._hemtt:1462](../scripts\game\vehicles\vm_nato.gd#L1462)
- the tank: an oval barrel on cradles with its end caps, the walkway along its crown between folding rails over the three manholes, the pump cabinet and hose reels at the back ó [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477)
- the hazard placard ó [VmNato._hemtt:1485](../scripts\game\vehicles\vm_nato.gd#L1485)

**Local helper construction:** `VmNato._antenna`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_tail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### hummingbird, m900, pawnee

**Shared:** `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.bench`, `VehicleCab.mesh_glass`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._little_bird:409](../scripts\game\vehicles\vm_heli.gd#L409)
- the bubble: windscreen and chin windows, one framed sheet ó [VmHeli._little_bird:430](../scripts\game\vehicles\vm_heli.gd#L430)
- doors: the pilots' (off on the military birds), the cabin's behind ó [VmHeli._little_bird:436](../scripts\game\vehicles\vm_heli.gd#L436)
- a cheat line down the flank ó [VmHeli._little_bird:442](../scripts\game\vehicles\vm_heli.gd#L442)
- seat backs, seen through the openings ó [VmHeli._little_bird:452](../scripts\game\vehicles\vm_heli.gd#L452)
- roof fairing over the mast and the engine intake behind it ó [VmHeli._little_bird:455](../scripts\game\vehicles\vm_heli.gd#L455)
- exhaust under the boom root, the boom, the tail ó [VmHeli._little_bird:461](../scripts\game\vehicles\vm_heli.gd#L461)
- beacon, antennas, pitot, the landing light ó [VmHeli._little_bird:473](../scripts\game\vehicles\vm_heli.gd#L473)
- a step on a stub post off each skid ó [VmHeli._little_bird:480](../scripts\game\vehicles\vm_heli.gd#L480)
- the external personnel benches, two a side, facing out: the padded seat on its tray with a lip along the outer edge ó [VmHeli._little_bird:485](../scripts\game\vehicles\vm_heli.gd#L485)
- a grab rail over the doorway ó [VmHeli._little_bird:494](../scripts\game\vehicles\vm_heli.gd#L494)
- the weapons cross-bar under the cabin floor: minigun inboard, pod out ó [VmHeli._little_bird:497](../scripts\game\vehicles\vm_heli.gd#L497)
- the ammunition chute from the box in the cabin ó [VmHeli._little_bird:504](../scripts\game\vehicles\vm_heli.gd#L504)
- the FLIR ball hanging on its neck under the nose ó [VmHeli._little_bird:512](../scripts\game\vehicles\vm_heli.gd#L512)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._skin`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### humvee

**Shared:** `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.receiver`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleRunningGear.wishbone`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.hmg`, `VehicleWheelArches.tub`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._humvee:1179](../scripts\game\vehicles\vm_core.gd#L1179)
- the chassis under the body: frame, the wheel wells over each axle, the portal hub housings and the double wishbones out to them (each housing is its wheel's knuckle) ó [VmCore._humvee:1186](../scripts\game\vehicles\vm_core.gd#L1186)
- the body: bonnet over the wings, the cab's lower half and the rear deck in one panel, the arches cut round the wheels ó [VmCore._humvee:1195](../scripts\game\vehicles\vm_core.gd#L1195)
- the wheels, their mud flaps ó [VmCore._humvee:1200](../scripts\game\vehicles\vm_core.gd#L1200)
- the bonnet: its seam and the raised middle, the rubber T-latches either side, the intake grille on the right ó [VmCore._humvee:1206](../scripts\game\vehicles\vm_core.gd#L1206)
- (laid on the bonnet's slope, its face 3 cm proud so the recessed core clears the panel, as the deck grilles stand; its slats across the car) ó [VmCore._humvee:1213](../scripts\game\vehicles\vm_core.gd#L1213)
- the face: the slotted grille, headlights in the wing corners, the indicators, the bumper with its winch and lifting shackles ó [VmCore._humvee:1216](../scripts\game\vehicles\vm_core.gd#L1216)
- the cab: armoured walls lofted from the belt to the roof ó [VmCore._humvee:1225](../scripts\game\vehicles\vm_core.gd#L1225)
- the split windscreen, thick armoured glass in heavy frames ó [VmCore._humvee:1234](../scripts\game\vehicles\vm_core.gd#L1234)
- the door windows, small and square; the cab's back window ó [VmCore._humvee:1237](../scripts\game\vehicles\vm_core.gd#L1237)
- the doors: heavy armoured slabs proud of the body, their seams, hinges and the big latch handles ó [VmCore._humvee:1243](../scripts\game\vehicles\vm_core.gd#L1243)
- the wing mirrors on their arms ó [VmCore._humvee:1251](../scripts\game\vehicles\vm_core.gd#L1251)
- armour over the rear deck's sides ó [VmCore._humvee:1253](../scripts\game\vehicles\vm_core.gd#L1253)
- the rear: the deck lid, tail lights in the corners, the pintle, jerrycans ó [VmCore._humvee:1256](../scripts\game\vehicles\vm_core.gd#L1256)
- --- the O-GPK turret on the roof ring ó [VmCore._humvee:1266](../scripts\game\vehicles\vm_core.gd#L1266)
- the faceted shields: three across the front, angled wings, side panels, each with its ballistic window; the back left open for the gunner ó [VmCore._humvee:1271](../scripts\game\vehicles\vm_core.gd#L1271)
- the gun slot in the front shield and the M2 through it ó [VmCore._humvee:1288](../scripts\game\vehicles\vm_core.gd#L1288)
- the ballistic glass ring over the shields on the front ó [VmCore._humvee:1292](../scripts\game\vehicles\vm_core.gd#L1292)

**Local helper construction:** `VmCiv._face`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._antenna`, `VmCore._bx`, `VmCore._cam`, `VmCore._jerry`, `VmCore._m2`, `VmCore._shackle`, `VmCore._taillight`.

### hunter, hunter_gmg, hunter_hmg

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCargo.roof_rack`, `VehicleCloth.bag`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleRunningGear.wishbone`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._hunter:315](../scripts\game\vehicles\vm_nato.gd#L315)
- --- V-hull, engine block, suspension and the wheels ó [VmNato._hunter:321](../scripts\game\vehicles\vm_nato.gd#L321)
- the double wishbones, the coil-over leaning in behind them ó [VmNato._hunter:328](../scripts\game\vehicles\vm_nato.gd#L328)
- --- bonnet over the engine, fenders over the front wheels, the grille ó [VmNato._hunter:330](../scripts\game\vehicles\vm_nato.gd#L330)
- the wheel arch lip and mud flap behind the front wheel ó [VmNato._hunter:336](../scripts\game\vehicles\vm_nato.gd#L336)
- the hood's centre bulge and its latches ó [VmNato._hunter:343](../scripts\game\vehicles\vm_nato.gd#L343)
- bumper with tow shackles and a recovery winch ó [VmNato._hunter:347](../scripts\game\vehicles\vm_nato.gd#L347)
- --- the crew capsule: vertical lower sides, the upper sides leaning in, a lightly raked windscreen ó [VmNato._hunter:352](../scripts\game\vehicles\vm_nato.gd#L352)
- windscreen: two small thick panes in a heavy frame ó [VmNato._hunter:358](../scripts\game\vehicles\vm_nato.gd#L358)
- doors: seams, small thick windows on the upper sides, handles, hinges ó [VmNato._hunter:362](../scripts\game\vehicles\vm_nato.gd#L362)
- the steps under the doors, the mirror on its arm ó [VmNato._hunter:374](../scripts\game\vehicles\vm_nato.gd#L374)
- stowage box low on the capsule side by the rear door ó [VmNato._hunter:378](../scripts\game\vehicles\vm_nato.gd#L378)
- the engine air intake up the right A-pillar ó [VmNato._hunter:380](../scripts\game\vehicles\vm_nato.gd#L380)
- roof: the flush rails, antennas, the lights over the windscreen ó [VmNato._hunter:383](../scripts\game\vehicles\vm_nato.gd#L383)
- --- the cargo bed behind the capsule, fenders over the rear wheels ó [VmNato._hunter:388](../scripts\game\vehicles\vm_nato.gd#L388)
- the step up into the bed ó [VmNato._hunter:400](../scripts\game\vehicles\vm_nato.gd#L400)
- the spare wheel on its swing-out carrier ó [VmNato._hunter:403](../scripts\game\vehicles\vm_nato.gd#L403)
- --- the roof: a remote weapon station, or the gunner's hatch closed ó [VmNato._hunter:408](../scripts\game\vehicles\vm_nato.gd#L408)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._zy`.

### huron

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.gear_leg`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._huron:635](../scripts\game\vehicles\vm_heli.gd#L635)
- cockpit glazing: windscreen, chin windows, side windows; the crew door ó [VmHeli._huron:650](../scripts\game\vehicles\vm_heli.gd#L650)
- the row of small cabin windows ó [VmHeli._huron:661](../scripts\game\vehicles\vm_heli.gd#L661)
- the ramp: hinge line, its edges under the tail, the door in the back ó [VmHeli._huron:665](../scripts\game\vehicles\vm_heli.gd#L665)
- fuel sponsons down the flanks ó [VmHeli._huron:672](../scripts\game\vehicles\vm_heli.gd#L672)
- the gear: two wheels forward of the sponsons, two under their tails ó [VmHeli._huron:686](../scripts\game\vehicles\vm_heli.gd#L686)
- steps, lights, the rescue hoist over the door ó [VmHeli._huron:690](../scripts\game\vehicles\vm_heli.gd#L690)
- cargo hooks, the FLIR ball, pitots ó [VmHeli._huron:695](../scripts\game\vehicles\vm_heli.gd#L695)
- forward pylon, the shaft tunnel, the tall aft pylon with its engines ó [VmHeli._huron:701](../scripts\game\vehicles\vm_heli.gd#L701)
- masts, antennas, beacons ó [VmHeli._huron:717](../scripts\game\vehicles\vm_heli.gd#L717)
- the rotors: three-blade, contra-rotating, the aft one higher, each under a six-sided hub cap ó [VmHeli._huron:724](../scripts\game\vehicles\vm_heli.gd#L724)

**Local helper construction:** `VmHeli._air`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._skin`, `VmHeli._tube`.

### ifrit, ifrit_gmg, ifrit_hmg

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCargo.roof_rack`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._ifrit:265](../scripts\game\vehicles\vm_csat.gd#L265)
- the V-shaped belly between the wheels ó [VmCsat._ifrit:267](../scripts\game\vehicles\vm_csat.gd#L267)
- the faceted body: nose, bonnet, windscreen, cabin, rear face ó [VmCsat._ifrit:269](../scripts\game\vehicles\vm_csat.gd#L269)
- the lower nose (grille and bumper) and the tail below the rear door ó [VmCsat._ifrit:278](../scripts\game\vehicles\vm_csat.gd#L278)
- the door sills between the wheels, their ends cut to the arches ó [VmCsat._ifrit:281](../scripts\game\vehicles\vm_csat.gd#L281)
- a raised panel down the bonnet and the air intake grille before the screen ó [VmCsat._ifrit:286](../scripts\game\vehicles\vm_csat.gd#L286)
- the windscreen: two small panes in the raked front of the cabin ó [VmCsat._ifrit:290](../scripts\game\vehicles\vm_csat.gd#L290)
- A-pillar cover strips on the screen's facets ó [VmCsat._ifrit:295](../scripts\game\vehicles\vm_csat.gd#L295)
- side windows, door seams and lever handles, the doors' steps ó [VmCsat._ifrit:298](../scripts\game\vehicles\vm_csat.gd#L298)
- each door's gap runs up the body from the chine over the belt to the roof edge ó [VmCsat._ifrit:304](../scripts\game\vehicles\vm_csat.gd#L304)
- mirrors on stalks at the screen's base ó [VmCsat._ifrit:311](../scripts\game\vehicles\vm_csat.gd#L311)
- angular arches over the wheels and mud flaps behind them ó [VmCsat._ifrit:313](../scripts\game\vehicles\vm_csat.gd#L313)
- headlight clusters in the wings, rear lights, tow hooks ó [VmCsat._ifrit:318](../scripts\game\vehicles\vm_csat.gd#L318)
- whip antennas at the rear roof corners ó [VmCsat._ifrit:322](../scripts\game\vehicles\vm_csat.gd#L322)
- the grille in the nose, which leans forward toward its top, the bumper ó [VmCsat._ifrit:324](../scripts\game\vehicles\vm_csat.gd#L324)
- the rear: the door with its window and hinges, the spare wheel, the step ó [VmCsat._ifrit:328](../scripts\game\vehicles\vm_csat.gd#L328)
- roof: rails on a foot at each end, the hatch or the weapon station ó [VmCsat._ifrit:339](../scripts\game\vehicles\vm_csat.gd#L339)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._arch_offset`, `VmCsat._face_rot`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._mx`, `VmCsat._pane`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`.

### ifv

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._bradley:1437](../scripts\game\vehicles\vm_core.gd#L1437)
- running gear: front sprocket, six road wheels, rear idler ó [VmCore._bradley:1440](../scripts\game\vehicles\vm_core.gd#L1440)
- the hull: the belly with the steep lower nose, the upper hull out over the tracks with the long upper glacis ó [VmCore._bradley:1459](../scripts\game\vehicles\vm_core.gd#L1459)
- The glacis normal points up and forward, out of the plate. ó [VmCore._bradley:1469](../scripts\game\vehicles\vm_core.gd#L1469)
- the glacis: its armour plate with the bolt rows, the driver's hatch and periscopes front left, the engine access and grilles front right ó [VmCore._bradley:1471](../scripts\game\vehicles\vm_core.gd#L1471)
- the exhaust on the right of the nose, lights in guards, tow hooks ó [VmCore._bradley:1483](../scripts\game\vehicles\vm_core.gd#L1483)
- the sides: the appliqu√© armour tiles with their bolts, the skirts under them, the grab rail ó [VmCore._bradley:1489](../scripts\game\vehicles\vm_core.gd#L1489)
- the roof: the troop compartment's long cargo hatch hinged at its back edge, vision blocks ó [VmCore._bradley:1505](../scripts\game\vehicles\vm_core.gd#L1505)
- the rear: the big ramp with its door, hinges, stowage boxes either side, tail lights, a water can and kit ó [VmCore._bradley:1511](../scripts\game\vehicles\vm_core.gd#L1511)
- (turned about Y so the lid's latches face out the back) ó [VmCore._bradley:1521](../scripts\game\vehicles\vm_core.gd#L1521)
- --- the turret ó [VmCore._bradley:1526](../scripts\game\vehicles\vm_core.gd#L1526)
- the spaced armour on the turret's front faces ó [VmCore._bradley:1534](../scripts\game\vehicles\vm_core.gd#L1534)
- the 25 mm in its mantlet, the coax to its right ó [VmCore._bradley:1541](../scripts\game\vehicles\vm_core.gd#L1541)
- the TOW launcher box on its arm on the left ó [VmCore._bradley:1547](../scripts\game\vehicles\vm_core.gd#L1547)
- the IBAS sight head front left under its raised armoured door, the CIV on its column on the right, the hatches ó [VmCore._bradley:1550](../scripts\game\vehicles\vm_core.gd#L1550)
- the stowage basket round the back, bags and a bedroll in it ó [VmCore._bradley:1560](../scripts\game\vehicles\vm_core.gd#L1560)

**Local helper construction:** `VmCore._antenna`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._eye`, `VmCore._hatch`, `VmCore._hollow_tyre`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._oct`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._wheel_disc`, `VmCore._zy`.

### jet

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.duct`, `VehicleAircraft.fin_set`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.missile`, `VehicleAircraft.ogive`, `VehicleAircraft.pitot`, `VehicleAircraft.pod`, `VehicleAircraft.refuel_receptacle`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.filler`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`.

**Authored sections:**

- Unlabelled construction / setup ó [VmFighter._f16:695](../scripts\game\vehicles\vm_fighter.gd#L695)
- --- fuselage: radome, the round body, strakes flaring into the wing root [s, crown, keel, half-width, strake edge's half-span, its height] ó [VmFighter._f16:706](../scripts\game\vehicles\vm_fighter.gd#L706)
- the cockpit sill the canopy sits on, the dorsal spine behind it ó [VmFighter._f16:725](../scripts\game\vehicles\vm_fighter.gd#L725)
- the frameless bubble canopy (its bow behind the seat), the sill rails ó [VmFighter._f16:731](../scripts\game\vehicles\vm_fighter.gd#L731)
- --- the ventral intake: a hollow raked mouth, the splitter above it, the duct fairing running back under the fuselage ó [VmFighter._f16:740](../scripts\game\vehicles\vm_fighter.gd#L740)
- --- wing: leading-edge flaps the full span, flaperons inboard ó [VmFighter._f16:750](../scripts\game\vehicles\vm_fighter.gd#L750)
- all-moving tailerons, 10 degrees down ó [VmFighter._f16:756](../scripts\game\vehicles\vm_fighter.gd#L756)
- the fin with its rudder, the squadron band round its tip, the base housing behind it, the antenna cap ó [VmFighter._f16:759](../scripts\game\vehicles\vm_fighter.gd#L759)
- ventral fins, canted out under the strake shelves ó [VmFighter._f16:768](../scripts\game\vehicles\vm_fighter.gd#L768)
- split speedbrakes at the ends of the strake shelves ó [VmFighter._f16:773](../scripts\game\vehicles\vm_fighter.gd#L773)
- --- the F110's nozzle: actuator ring, petals, the pipe inside ó [VmFighter._f16:778](../scripts\game\vehicles\vm_fighter.gd#L778)
- --- details: pitot, AOA probes, IFF "bird slicers", the gun, refuelling receptacle, antennas, lights ó [VmFighter._f16:785](../scripts\game\vehicles\vm_fighter.gd#L785)
- The receptacle door sits on the crown of the dorsal spine (about y0 + 0.728 there), so it shows rather than sinking into the curved skin. ó [VmFighter._f16:797](../scripts\game\vehicles\vm_fighter.gd#L797)
- formation strip lights: nose sides, fin ó [VmFighter._f16:804](../scripts\game\vehicles\vm_fighter.gd#L804)
- --- panel lines: control-surface hinge lines are gaps; these are the access panels and the gear doors (closed flush) ó [VmFighter._f16:815](../scripts\game\vehicles\vm_fighter.gd#L815)
- --- stores ó [VmFighter._f16:829](../scripts\game\vehicles\vm_fighter.gd#L829)
- the tip launcher and its AMRAAM ó [VmFighter._f16:845](../scripts\game\vehicles\vm_fighter.gd#L845)
- Sniper pod on the right intake station, the ALQ-184 on the centreline ó [VmFighter._f16:850](../scripts\game\vehicles\vm_fighter.gd#L850)
- --- markings: low-vis star-and-bar on the intake and the wings, the wing's tail code and serial on the fin ó [VmFighter._f16:855](../scripts\game\vehicles\vm_fighter.gd#L855)
- --- landing gear (shown on the ground): the short nose leg behind the intake, the main legs splayed out from under the strakes, open doors ó [VmFighter._f16:869](../scripts\game\vehicles\vm_fighter.gd#L869)
- the main door hangs from the strake outboard of the well ó [VmFighter._f16:888](../scripts\game\vehicles\vm_fighter.gd#L888)

**Local helper construction:** `VmFighter._aim120`, `VmFighter._aim9x`, `VmFighter._alq184`, `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._f16_half`, `VmFighter._ft`, `VmFighter._gbu31`, `VmFighter._gear_door`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hband`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._mesh`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._pipe`, `VmFighter._poly_mesh`, `VmFighter._project`, `VmFighter._put`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._sniper`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### kajman

**Shared:** `VehicleAircraft.chin_turret`, `VehicleAircraft.cowling`, `VehicleAircraft.dispenser`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.tailwheel`, `VehicleAircraft.trailing_gear`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWeapons.autocannon`, `VehicleWeapons.launch_tube`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._kajman:1051](../scripts\game\vehicles\vm_heli.gd#L1051)
- the stepped cockpits: the gunner low in front, the pilot high behind ó [VmHeli._kajman:1072](../scripts\game\vehicles\vm_heli.gd#L1072)
- the cabin: split doors with a window in the upper half, side windows ó [VmHeli._kajman:1076](../scripts\game\vehicles\vm_heli.gd#L1076)
- the nose sensors ó [VmHeli._kajman:1084](../scripts\game\vehicles\vm_heli.gd#L1084)
- top fairing, the engines with their dust filters and exhaust deflectors ó [VmHeli._kajman:1089](../scripts\game\vehicles\vm_heli.gd#L1089)
- the dust protector: a cone ahead of a dark annular intake ó [VmHeli._kajman:1098](../scripts\game\vehicles\vm_heli.gd#L1098)
- the coaxial mast: the swashplate guide at its foot, the separator between the two rotors ó [VmHeli._kajman:1102](../scripts\game\vehicles\vm_heli.gd#L1102)
- stub wings: anhedral, three pylons a side, flare pods at the tips ó [VmHeli._kajman:1105](../scripts\game\vehicles\vm_heli.gd#L1105)
- main gear on trailing legs ó [VmHeli._kajman:1118](../scripts\game\vehicles\vm_heli.gd#L1118)
- the tail: a swept fin, the stabiliser with endplate fins, the tailwheel ó [VmHeli._kajman:1123](../scripts\game\vehicles\vm_heli.gd#L1123)
- the chin turret: 2A42 30 mm with its ammunition boxes either side ó [VmHeli._kajman:1132](../scripts\game\vehicles\vm_heli.gd#L1132)
- the cannon: its recoil sleeve out of the gun box, the barrel, the brake ó [VmHeli._kajman:1135](../scripts\game\vehicles\vm_heli.gd#L1135)
- the coaxial rotors: three blades each, the upper one turning the other way ó [VmHeli._kajman:1138](../scripts\game\vehicles\vm_heli.gd#L1138)

**Local helper construction:** `VmHeli._atgm_tubes`, `VmHeli._canopy`, `VmHeli._hull`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skin`, `VmHeli._tube`.

### kamysh

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._kamysh:721](../scripts\game\vehicles\vm_csat.gd#L721)
- the bustle box at the back ó [VmCsat._kamysh:727](../scripts\game\vehicles\vm_csat.gd#L727)
- mantlet, the 30 mm with its barrel jacket and muzzle brake, the coax ó [VmCsat._kamysh:729](../scripts\game\vehicles\vm_csat.gd#L729)
- the gunner's sight head (front left) and the commander's panoramic sight ó [VmCsat._kamysh:734](../scripts\game\vehicles\vm_csat.gd#L734)
- the twin Titan launchers on arms either side, smoke dischargers behind ó [VmCsat._kamysh:737](../scripts\game\vehicles\vm_csat.gd#L737)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._face_rot`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### kart

**Shared:** `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.silencer`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._kart:1215](../scripts\game\vehicles\vm_civ.gd#L1215)
- the frame: two main rails, cross members, the front stubs ó [VmCiv._kart:1225](../scripts\game\vehicles\vm_civ.gd#L1225)
- nose fairing, front panel, pods in the livery ó [VmCiv._kart:1239](../scripts\game\vehicles\vm_civ.gd#L1239)
- seat, steering wheel and column, pedals ó [VmCiv._kart:1257](../scripts\game\vehicles\vm_civ.gd#L1257)
- the two-stroke to the right of the seat, its airbox and silencer ó [VmCiv._kart:1264](../scripts\game\vehicles\vm_civ.gd#L1264)
- rear bumper and its plate ó [VmCiv._kart:1271](../scripts\game\vehicles\vm_civ.gd#L1271)

**Local helper construction:** `VmCiv._bent`, `VmCiv._rod`.

### kuma

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._kuma:446](../scripts\game\vehicles\vm_indep.gd#L446)
- running gear: front idler, seven road wheels, rear sprocket, four rollers ó [VmIndep._kuma:450](../scripts\game\vehicles\vm_indep.gd#L450)
- hull: the belly between the tracks (the lower glacis its front), the upper hull out over the tracks with the long shallow upper glacis ó [VmIndep._kuma:456](../scripts\game\vehicles\vm_indep.gd#L456)
- a bolted add-on plate over the glacis, the driver's hatch front-right ó [VmIndep._kuma:462](../scripts\game\vehicles\vm_indep.gd#L462)
- headlight clusters with guards on the front corners, tow eyes ó [VmIndep._kuma:468](../scripts\game\vehicles\vm_indep.gd#L468)
- skirts: three heavy armour modules forward, three light panels aft, the bow panel raked ó [VmIndep._kuma:471](../scripts\game\vehicles\vm_indep.gd#L471)
- the hull's sides: a stowage box and the tool rack above the skirts ó [VmIndep._kuma:480](../scripts\game\vehicles\vm_indep.gd#L480)
- engine deck grilles either side of the centre access panel ó [VmIndep._kuma:483](../scripts\game\vehicles\vm_indep.gd#L483)
- rear: tail lights, tow eyes ó [VmIndep._kuma:485](../scripts\game\vehicles\vm_indep.gd#L485)
- the exhaust louvres across the top of the rear plate, the slat cage standing off the back on its struts ó [VmIndep._kuma:489](../scripts\game\vehicles\vm_indep.gd#L489)
- the turret, its front cheeks just behind the glacis ó [VmIndep._kuma:497](../scripts\game\vehicles\vm_indep.gd#L497)
- bolt-on armour: flat slabs on the cheeks either side of the mantlet and along the sides ó [VmIndep._kuma:504](../scripts\game\vehicles\vm_indep.gd#L504)
- smoke dischargers: a group of four on each side, aft ó [VmIndep._kuma:517](../scripts\game\vehicles\vm_indep.gd#L517)
- the gun: mantlet, thermal sleeve, fume extractor, muzzle reference sensor ó [VmIndep._kuma:520](../scripts\game\vehicles\vm_indep.gd#L520)
- the coaxial MG left of the gun ó [VmIndep._kuma:528](../scripts\game\vehicles\vm_indep.gd#L528)
- roof: the EMES gunner's sight doghouse front-right, the PERI periscope behind it, the commander's and loader's hatches, the wind sensor ó [VmIndep._kuma:531](../scripts\game\vehicles\vm_indep.gd#L531)
- the bustle's stowage basket, the slat cage round it on its struts ó [VmIndep._kuma:543](../scripts\game\vehicles\vm_indep.gd#L543)
- a remote .50 over the loader's hatch ó [VmIndep._kuma:552](../scripts\game\vehicles\vm_indep.gd#L552)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._slats`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._track_belt`.

### m35

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleCargo.flatbed`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.panel`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._truck:1815](../scripts\game\vehicles\vm_core.gd#L1815)
- the chassis: frame rails, the axles and their diffs, the wheels ó [VmCore._truck:1819](../scripts\game\vehicles\vm_core.gd#L1819)
- the bonnet with the radiator grille in its nose, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks (the grilles lean with the bonnet's faces) ó [VmCore._truck:1825](../scripts\game\vehicles\vm_core.gd#L1825)
- the louvres down the bonnet's sides ó [VmCore._truck:1836](../scripts\game\vehicles\vm_core.gd#L1836)
- the brush guard: its hoop and three uprights standing on the bumper ó [VmCore._truck:1838](../scripts\game\vehicles\vm_core.gd#L1838)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms ó [VmCore._truck:1844](../scripts\game\vehicles\vm_core.gd#L1844)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box ó [VmCore._truck:1859](../scripts\game\vehicles\vm_core.gd#L1859)
- bolted through its hub to a carrier on the cab's back ó [VmCore._truck:1861](../scripts\game\vehicles\vm_core.gd#L1861)
- the cargo bed: the plank floor, the dropsides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle ó [VmCore._truck:1865](../scripts\game\vehicles\vm_core.gd#L1865)
- The tilt's section: straight walls 0.9 m high, then a half-ellipse roof 1.16 m to each side and 0.49 m high; the cloth hangs between the bows. ó [VmCore._truck:1873](../scripts\game\vehicles\vm_core.gd#L1873)
- (the back flap laced shut across the tail, inside the last bow) ó [VmCore._truck:1880](../scripts\game\vehicles\vm_core.gd#L1880)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._shackle`, `VmCore._taillight`, `VmNato._spare`.

### marid

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._marid:568](../scripts\game\vehicles\vm_csat.gd#L568)
- the glacis plane (for things mounted on it) ó [VmCsat._marid:577](../scripts\game\vehicles\vm_csat.gd#L577)
- the driver's windows at the top of the glacis, front left, and his hatch ó [VmCsat._marid:580](../scripts\game\vehicles\vm_csat.gd#L580)
- the engine's louvres on the right of the glacis, exhaust on the right side ó [VmCsat._marid:587](../scripts\game\vehicles\vm_csat.gd#L587)
- headlight clusters and tow hooks on the nose, smoke dischargers ó [VmCsat._marid:589](../scripts\game\vehicles\vm_csat.gd#L589)
- the wheels on three evenly spaced axles, mud flaps ó [VmCsat._marid:594](../scripts\game\vehicles\vm_csat.gd#L594)
- the crease's side: vision blocks and firing ports along the troop compartment, stowage boxes, the exhaust ó [VmCsat._marid:599](../scripts\game\vehicles\vm_csat.gd#L599)
- grab rails along the roof edge ó [VmCsat._marid:610](../scripts\game\vehicles\vm_csat.gd#L610)
- rear: the ramp with its door, hinges, water jets, lights, stowage ó [VmCsat._marid:613](../scripts\game\vehicles\vm_csat.gd#L613)
- roof: the troop compartment's hatches, a stowage basket ó [VmCsat._marid:628](../scripts\game\vehicles\vm_csat.gd#L628)
- twin remote weapon stations on one ring: the 12.7 mm on the left, the 40 mm on the right, the sight head between them ó [VmCsat._marid:635](../scripts\game\vehicles\vm_csat.gd#L635)
- 12.7 mm, left, and 40 mm, right, each with its ammunition on the outboard side ó [VmCsat._marid:645](../scripts\game\vehicles\vm_csat.gd#L645)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._face_rot`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._jerrycan`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._taillight`, `VmCsat._tow`.

### marshall

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.trim_vane`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleRunningGear.wishbone`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._marshall:548](../scripts\game\vehicles\vm_nato.gd#L548)
- lower hull between the wheels; the nose and tail blocks full width ó [VmNato._marshall:553](../scripts\game\vehicles\vm_nato.gd#L553)
- the upper hull: a vertical band over the wheels, then the sides leaning in ó [VmNato._marshall:557](../scripts\game\vehicles\vm_nato.gd#L557)
- wheel wells: dark liners under the overhang over each wheel ó [VmNato._marshall:562](../scripts\game\vehicles\vm_nato.gd#L562)
- glacis: the trim vane folded flat, the driver's hatch and periscopes, the engine deck grilles on the right, lights and tow eyes on the nose ó [VmNato._marshall:566](../scripts\game\vehicles\vm_nato.gd#L566)
- exhaust grille on the right side, forward ó [VmNato._marshall:582](../scripts\game\vehicles\vm_nato.gd#L582)
- side details: stowage bins on the sloping sides, vision blocks, a tow cable clipped along the hull ó [VmNato._marshall:584](../scripts\game\vehicles\vm_nato.gd#L584)
- roof over the troop compartment: two hatches, periscopes ó [VmNato._marshall:594](../scripts\game\vehicles\vm_nato.gd#L594)
- the rear: ramp with its door and the door's lever handle, hinges, lights ó [VmNato._marshall:599](../scripts\game\vehicles\vm_nato.gd#L599)
- the ramp's heavy hinges along its foot ó [VmNato._marshall:604](../scripts\game\vehicles\vm_nato.gd#L604)
- --- the turret: low and faceted, the 40 mm, smoke dischargers, the commander's panoramic sight on its mast ó [VmNato._marshall:611](../scripts\game\vehicles\vm_nato.gd#L611)
- gun: the mantlet, the barrel with its recoil sleeve, the muzzle brake ó [VmNato._marshall:619](../scripts\game\vehicles\vm_nato.gd#L619)
- coaxial MG port beside the mantlet ó [VmNato._marshall:623](../scripts\game\vehicles\vm_nato.gd#L623)
- sights: gunner's forward left, the commander's panoramic sight on a mast ó [VmNato._marshall:625](../scripts\game\vehicles\vm_nato.gd#L625)
- hatches, smoke dischargers, bustle stowage, antenna ó [VmNato._marshall:628](../scripts\game\vehicles\vm_nato.gd#L628)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._xy_bin`.

### mb4wd, mb4wd_at, mb4wd_lmg

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.dashboard`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.roll_bar`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleMounts.pedestal`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.mmg`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._mb4wd:466](../scripts\game\vehicles\vm_civ.gd#L466)
- frame, wheel tubs, axles (solid beam axles front and rear), the skid plate ó [VmCiv._mb4wd:474](../scripts\game\vehicles\vm_civ.gd#L474)
- the exhaust along the skid plate's edge, hung from the frame rail above ó [VmCiv._mb4wd:481](../scripts\game\vehicles\vm_civ.gd#L481)
- the tub: a floor pan with the arches cut out, walls standing on it ó [VmCiv._mb4wd:483](../scripts\game\vehicles\vm_civ.gd#L483)
- bonnet over a narrow engine bay, then the flat-topped wings with flares ó [VmCiv._mb4wd:489](../scripts\game\vehicles\vm_civ.gd#L489)
- hood latches, indicator on the wing, exposed hinges, the door's shut lines and handle, a black mirror, rock rails ó [VmCiv._mb4wd:499](../scripts\game\vehicles\vm_civ.gd#L499)
- (the left door's hinges are the mirror image of the right's) ó [VmCiv._mb4wd:503](../scripts\game\vehicles\vm_civ.gd#L503)
- (each shut line as (z, its foot): the front one stops on the arch) ó [VmCiv._mb4wd:506](../scripts\game\vehicles\vm_civ.gd#L506)
- square tail lights on the rear corners ó [VmCiv._mb4wd:513](../scripts\game\vehicles\vm_civ.gd#L513)
- the face: seven slots between round headlights, bumper with tow hooks. The slots are the gaps between eight body-coloured bars of a grille set 3 cm proud of the leaning panel, inside the headlights' bezels; it fills the opening below the bonnet's nose, which covers the panel above 0.9 m. ó [VmCiv._mb4wd:516](../scripts\game\vehicles\vm_civ.gd#L516)
- windscreen: an upright frame folding on the cowl, wipers ó [VmCiv._mb4wd:531](../scripts\game\vehicles\vm_civ.gd#L531)
- inside: dash, the wheel (left-hand drive), two buckets and a bench ó [VmCiv._mb4wd:544](../scripts\game\vehicles\vm_civ.gd#L544)
- the rear bench on the tub floor, its back leaning away from the sitters ó [VmCiv._mb4wd:550](../scripts\game\vehicles\vm_civ.gd#L550)
- the sport bar: a hoop behind the front seats, rails forward to the windscreen frame and back down to the rear corners, a diagonal clamped between the hoop and each rear rail, the feet bolted down ó [VmCiv._mb4wd:552](../scripts\game\vehicles\vm_civ.gd#L552)
- rear: spare wheel on the tailgate, bumper, plate; the fuel filler on the left quarter, its cap seated on the tub's side ó [VmCiv._mb4wd:562](../scripts\game\vehicles\vm_civ.gd#L562)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._lamp`, `VmCiv._lmg`, `VmCiv._mb_gun`, `VmCiv._mb_top`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCiv._zring`.

### mohawk

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.gear_leg`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.slide_rail`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radome`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._mohawk:830](../scripts\game\vehicles\vm_heli.gd#L830)
- the olive upper half of the scheme ó [VmHeli._mohawk:849](../scripts\game\vehicles\vm_heli.gd#L849)
- the cockpit: windscreen, chin windows, side windows ó [VmHeli._mohawk:851](../scripts\game\vehicles\vm_heli.gd#L851)
- the cabin door (right, forward), windows down both sides ó [VmHeli._mohawk:857](../scripts\game\vehicles\vm_heli.gd#L857)
- the ramp: hinge line, its edges ó [VmHeli._mohawk:864](../scripts\game\vehicles\vm_heli.gd#L864)
- sponsons with the twin-wheel main gear, the twin nosewheel ó [VmHeli._mohawk:868](../scripts\game\vehicles\vm_heli.gd#L868)
- the hoist over the door, the radome, pitots ó [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884)
- the cable hanging from the hoist's arm, its hook block at the bottom ó [VmHeli._mohawk:886](../scripts\game\vehicles\vm_heli.gd#L886)
- the roof: gearbox fairing, three engines, their intakes and exhausts ó [VmHeli._mohawk:892](../scripts\game\vehicles\vm_heli.gd#L892)
- mast, the IR jammer, antennas ó [VmHeli._mohawk:906](../scripts\game\vehicles\vm_heli.gd#L906)
- the tail pylon, the tail rotor on its left, the tailplane on its right ó [VmHeli._mohawk:911](../scripts\game\vehicles\vm_heli.gd#L911)
- the rotor: five BERP blades under a domed hub cap ó [VmHeli._mohawk:918](../scripts\game\vehicles\vm_heli.gd#L918)

**Local helper construction:** `VmHeli._door_rail`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._skin`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### mora

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._mora:352](../scripts\game\vehicles\vm_indep.gd#L352)
- running gear: front sprocket, six road wheels, rear idler, three rollers ó [VmIndep._mora:356](../scripts\game\vehicles\vm_indep.gd#L356)
- the hull: belly between the tracks, the upper hull out over them with the long glacis ó [VmIndep._mora:362](../scripts\game\vehicles\vm_indep.gd#L362)
- skirts: five bolted panels a side, the front one raked ó [VmIndep._mora:366](../scripts\game\vehicles\vm_indep.gd#L366)
- the hull's side seam at the deck line, a stowage box aft ó [VmIndep._mora:372](../scripts\game\vehicles\vm_indep.gd#L372)
- headlight clusters in guards on the glacis corners, tow hooks ó [VmIndep._mora:375](../scripts\game\vehicles\vm_indep.gd#L375)
- glacis: the driver's hatch and vision blocks front-left, the engine louvres front-right, lifting eyes ó [VmIndep._mora:378](../scripts\game\vehicles\vm_indep.gd#L378)
- exhaust: the louvred outlet on the right flank, forward ó [VmIndep._mora:389](../scripts\game\vehicles\vm_indep.gd#L389)
- roof: the troop compartment's long hatch, a vent, antennas at the back ó [VmIndep._mora:391](../scripts\game\vehicles\vm_indep.gd#L391)
- rear: the big door with its vision block, hinges and handle, a stowage bin either side of it, tail lights, the tow pintle ó [VmIndep._mora:395](../scripts\game\vehicles\vm_indep.gd#L395)
- the bins' lids hinge on the hull side, their catches face aft ó [VmIndep._mora:403](../scripts\game\vehicles\vm_indep.gd#L403)
- the turret: faceted, the RARDEN in its narrow mantlet, the chain gun beside it, sights and hatches on the roof ó [VmIndep._mora:410](../scripts\game\vehicles\vm_indep.gd#L410)
- gunner's sight left, the commander's sight right, two hatches ó [VmIndep._mora:422](../scripts\game\vehicles\vm_indep.gd#L422)
- the round hatch lids, hinged at the back ó [VmIndep._mora:426](../scripts\game\vehicles\vm_indep.gd#L426)
- four-barrel smoke dischargers on the front corners ó [VmIndep._mora:428](../scripts\game\vehicles\vm_indep.gd#L428)
- the bustle: a stowage basket with a rolled tarp and kit in it ó [VmIndep._mora:431](../scripts\game\vehicles\vm_indep.gd#L431)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._glacis_grille`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._track_belt`.

### motorboat

**Shared:** `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.bench`, `VehicleCab.mesh_glass`, `VehicleCab.steering_wheel`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.bow_eye`, `VehicleMarine.fender`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._motorboat:537](../scripts\game\vehicles\vm_boat.gd#L537)
- topsides round the cockpit, in two runs so they keep the chine ó [VmBoat._motorboat:554](../scripts\game\vehicles\vm_boat.gd#L554)
- the stripe, the rub rail under the sheer, spray rails on the bottom ó [VmBoat._motorboat:564](../scripts\game\vehicles\vm_boat.gd#L564)
- the transom above the sole, notched for the motor, and the splash well ó [VmBoat._motorboat:589](../scripts\game\vehicles\vm_boat.gd#L589)
- the stern bench in front of it: its moulded base, the cushion and backrest ó [VmBoat._motorboat:597](../scripts\game\vehicles\vm_boat.gd#L597)
- the centre console: a sloped dash, a wrap windscreen, wheel and throttle ó [VmBoat._motorboat:600](../scripts\game\vehicles\vm_boat.gd#L600)
- the windscreen: a raked front pane and two side wings, framed, a grab rail on top ó [VmBoat._motorboat:604](../scripts\game\vehicles\vm_boat.gd#L604)
- a seat on a cool box in front of the console, the helm bench behind it ó [VmBoat._motorboat:620](../scripts\game\vehicles\vm_boat.gd#L620)
- the bow rail on its stanchions ó [VmBoat._motorboat:628](../scripts\game\vehicles\vm_boat.gd#L628)
- cleats, a bow navigation light, the stern light's pole ó [VmBoat._motorboat:645](../scripts\game\vehicles\vm_boat.gd#L645)
- a non-skid sole between the topsides ó [VmBoat._motorboat:659](../scripts\game\vehicles\vm_boat.gd#L659)
- two fenders stowed on the sole, a VHF whip on the console ó [VmBoat._motorboat:665](../scripts\game\vehicles\vm_boat.gd#L665)
- the bow eye and the registration number on both bows ó [VmBoat._motorboat:671](../scripts\game\vehicles\vm_boat.gd#L671)
- 115 hp outboard on the transom notch ó [VmBoat._motorboat:683](../scripts\game\vehicles\vm_boat.gd#L683)

**Local helper construction:** `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._slab`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### neophron

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.duct`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleWeapons.autocannon`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._neophron:816](../scripts\game\vehicles\vm_plane.gd#L816)
- engine nacelles under the wing-root extensions, intakes raked back ó [VmPlane._neophron:842](../scripts\game\vehicles\vm_plane.gd#L842)
- LERX into the shoulder wing, the fin and the stabilators ó [VmPlane._neophron:851](../scripts\game\vehicles\vm_plane.gd#L851)
- tip rails with R-73s, lights, probes, antennas ó [VmPlane._neophron:857](../scripts\game\vehicles\vm_plane.gd#L857)
- stores: the gun pod; bombs, B-8 rocket pods and R-73s underwing ó [VmPlane._neophron:865](../scripts\game\vehicles\vm_plane.gd#L865)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### nyx_aa, nyx_ac, nyx_at, nyx_recon

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.autocannon`, `VehicleWeapons.hmg`, `VehicleWeapons.launch_tube`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._nyx:566](../scripts\game\vehicles\vm_indep.gd#L566)
- hull: the belly between the tracks, the upper hull over them with the long glacis ó [VmIndep._nyx:572](../scripts\game\vehicles\vm_indep.gd#L572)
- the driver's hatch and periscopes front-left, the engine grille on the glacis front-right, the exhaust on the right flank ó [VmIndep._nyx:578](../scripts\game\vehicles\vm_indep.gd#L578)
- headlights with guards on the glacis corners, tow eyes, smoke dischargers on the roof's front corners ó [VmIndep._nyx:587](../scripts\game\vehicles\vm_indep.gd#L587)
- a stowage box on each flank aft, tail lights, a jerrycan ó [VmIndep._nyx:592](../scripts\game\vehicles\vm_indep.gd#L592)
- rear: the crew door and its handle, the tow pintle, a jerrycan rack ó [VmIndep._nyx:595](../scripts\game\vehicles\vm_indep.gd#L595)
- the periscope mast, extended, at the back left ó [VmIndep._nyx:604](../scripts\game\vehicles\vm_indep.gd#L604)
- the radar: a flat array on a turning pedestal over its electronics ó [VmIndep._nyx:610](../scripts\game\vehicles\vm_indep.gd#L610)
- the weapon mount: a low armoured turntable at the back of the roof ó [VmIndep._nyx:620](../scripts\game\vehicles\vm_indep.gd#L620)
- the Rh 202 in its cradle on top, ammunition boxes either side, a sight ó [VmIndep._nyx:627](../scripts\game\vehicles\vm_indep.gd#L627)
- a twin launcher for the fire-and-forget missiles on the left, a sight head in the middle, the .50 on the right ó [VmIndep._nyx:637](../scripts\game\vehicles\vm_indep.gd#L637)
- two four-round pods either side of the sight head, the .50 under the left one ó [VmIndep._nyx:648](../scripts\game\vehicles\vm_indep.gd#L648)
- each pod is lugged to the cross tube on its inboard face ó [VmIndep._nyx:653](../scripts\game\vehicles\vm_indep.gd#L653)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._glacis_grille`, `VmIndep._idler`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._nyx_m2`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._track_belt`.

### offroad, offroad_at, offroad_hmg, offroad_repair

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCargo.crate_stack`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.sideboard`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.gas_bottle`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.filler`, `VehicleFittings.jerrycan`, `VehicleFittings.light_bar`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.silencer`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.bumper`, `VehicleMounts.crane`, `VehicleMounts.gun_shield`, `VehicleMounts.hitch`, `VehicleMounts.pedestal`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.hmg`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._offroad:268](../scripts\game\vehicles\vm_civ.gd#L268)
- ladder frame, the wheel tubs behind the wheels, axles and diffs, exhaust ó [VmCiv._offroad:275](../scripts\game\vehicles\vm_civ.gd#L275)
- the exhaust tucked up under the frame rail, out past the rear bumper ó [VmCiv._offroad:282](../scripts\game\vehicles\vm_civ.gd#L282)
- the cab and front wings in one panel, the nose a loft with its corners rounded off for the headlights to wrap round, the bed separate ó [VmCiv._offroad:284](../scripts\game\vehicles\vm_civ.gd#L284)
- the black lower lip and the intake under the grille ó [VmCiv._offroad:309](../scripts\game\vehicles\vm_civ.gd#L309)
- bed: walls on the tub, a ribbed liner, wheel tubs, the tailgate ó [VmCiv._offroad:313](../scripts\game\vehicles\vm_civ.gd#L313)
- glasshouse: windscreen raked hard back, a short cab with its back window ó [VmCiv._offroad:324](../scripts\game\vehicles\vm_civ.gd#L324)
- doors: shut lines, handles, mirrors; side steps under them ó [VmCiv._offroad:333](../scripts\game\vehicles\vm_civ.gd#L333)
- flared arches in black plastic ó [VmCiv._offroad:345](../scripts\game\vehicles\vm_civ.gd#L345)
- tall tail lights on the bed corners ó [VmCiv._offroad:350](../scripts\game\vehicles\vm_civ.gd#L350)
- fuel filler on the bed side ó [VmCiv._offroad:353](../scripts\game\vehicles\vm_civ.gd#L353)
- the face: the tall single-frame grille in a bright surround, slats, the centre bar on them, plate. The grille's plane leans back with the nose, 3 cm ahead of it (its domain y is height), so its recessed core shows. ó [VmCiv._offroad:355](../scripts\game\vehicles\vm_civ.gd#L355)
- wipers, the aerial on the wing by the windscreen pillar ó [VmCiv._offroad:366](../scripts\game\vehicles\vm_civ.gd#L366)
- rear: step bumper with its tread, plate, tow ball (its mount reaching back under the bumper from a plate bolted inside it; the box 20 cm deep for a ball 4 cm in radius, its crown 0.58 m up) ó [VmCiv._offroad:370](../scripts\game\vehicles\vm_civ.gd#L370)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._inset`, `VmCiv._jerrycan`, `VmCiv._lamp`, `VmCiv._m2`, `VmCiv._mirror`, `VmCiv._off_at`, `VmCiv._off_hmg`, `VmCiv._off_repair`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`.

### old_tank

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.track_guard`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.drum`, `VehicleEquipment.storage`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.pintle`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.spare_links`, `VehicleWeapons.coax`, `VehicleWheels.drum`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._t55:761](../scripts\game\vehicles\vm_core.gd#L761)
- --- running gear: front idler, five road wheels (the gap after the first), rear sprocket; the track sagging onto the wheels ó [VmCore._t55:765](../scripts\game\vehicles\vm_core.gd#L765)
- one road wheel a replacement, still in its old green ó [VmCore._t55:776](../scripts\game\vehicles\vm_core.gd#L776)
- --- the hull: the belly between the tracks with the lower glacis, the upper hull over the tracks, the glacis rising at 60 degrees ó [VmCore._t55:785](../scripts\game\vehicles\vm_core.gd#L785)
- The belly fits between the tracks. The upper hull widens above the return run, including when a road wheel is at full bump. ó [VmCore._t55:790](../scripts\game\vehicles\vm_core.gd#L790)
- The glacis normal points up and forward, out of the plate. ó [VmCore._t55:799](../scripts\game\vehicles\vm_core.gd#L799)
- the splash board: a V across the glacis, its point forward ó [VmCore._t55:801](../scripts\game\vehicles\vm_core.gd#L801)
- spare track links bolted across the glacis below it, tow hooks under the nose ó [VmCore._t55:808](../scripts\game\vehicles\vm_core.gd#L808)
- the driver's hatch front left and his two periscopes, the lights on the glacis corners: the headlight and the IR driving light on the left (its lens long gone), one headlight on the right ó [VmCore._t55:813](../scripts\game\vehicles\vm_core.gd#L813)
- The guard arches over the lamp. Keep its steel clear of the lens. ó [VmCore._t55:826](../scripts\game\vehicles\vm_core.gd#L826)
- --- fenders: thin shelves the full length over the tracks with a lip down their outer edge, on gussets, the front mudguards angled down (the left one bent up), the rear ones ó [VmCore._t55:830](../scripts\game\vehicles\vm_core.gd#L830)
- the right fender: three external fuel tanks (dented, one streaked with rust), a stowage box forward; their straps and pipes ó [VmCore._t55:836](../scripts\game\vehicles\vm_core.gd#L836)
- (each box tank, with its straps and filler cap, set a little askew where the tank is dented) ó [VmCore._t55:840](../scripts\game\vehicles\vm_core.gd#L840)
- the left fender: stowage boxes, the spare parts box, the oil tank; the exhaust louvre on the hull side above it, sooted round ó [VmCore._t55:849](../scripts\game\vehicles\vm_core.gd#L849)
- (turned about Y so the louvre faces out to the left) ó [VmCore._t55:855](../scripts\game\vehicles\vm_core.gd#L855)
- rust streaks down the hull sides and the glacis corners ó [VmCore._t55:858](../scripts\game\vehicles\vm_core.gd#L858)
- --- the engine deck: the louvred grilles, the access plates, the radiator grille across the back ó [VmCore._t55:861](../scripts\game\vehicles\vm_core.gd#L861)
- --- the rear: the sloped plate, the two 200-litre drums on their brackets (one rust-brown, one green), the unditching log under them, tail lights, tow hooks ó [VmCore._t55:868](../scripts\game\vehicles\vm_core.gd#L868)
- Each drum lies fore and aft with its bung head to the rear, strapped down to the two brackets off the plate. ó [VmCore._t55:874](../scripts\game\vehicles\vm_core.gd#L874)
- --- the turret: the cast dome ó [VmCore._t55:886](../scripts\game\vehicles\vm_core.gd#L886)
- the cast mantlet in the dome's front and the canvas boot over the gun ó [VmCore._t55:899](../scripts\game\vehicles\vm_core.gd#L899)
- the 100 mm: the long tapering barrel, the fume extractor near the muzzle ó [VmCore._t55:906](../scripts\game\vehicles\vm_core.gd#L906)
- the coaxial PKT's port right of the gun ó [VmCore._t55:913](../scripts\game\vehicles\vm_core.gd#L913)
- the L-2 IR searchlight on its bracket to the right of the gun, braced to the mantlet ó [VmCore._t55:916](../scripts\game\vehicles\vm_core.gd#L916)
- the gunner's sight port front left, the ventilator dome front right ó [VmCore._t55:920](../scripts\game\vehicles\vm_core.gd#L920)
- the commander's cupola on the left with its vision blocks and the small IR spotlight, the loader's hatch on the right with the DShK on its ring ó [VmCore._t55:925](../scripts\game\vehicles\vm_core.gd#L925)
- the DShK's pintle on the ring's race, its cradle under the receiver ó [VmCore._t55:937](../scripts\game\vehicles\vm_core.gd#L937)
- grab rails round the dome, the snorkel stowed across the back, a rolled tarpaulin, lifting eyes ó [VmCore._t55:940](../scripts\game\vehicles\vm_core.gd#L940)
- rust round the cupola and a streak down the dome's flank ó [VmCore._t55:958](../scripts\game\vehicles\vm_core.gd#L958)

**Local helper construction:** `VmCore._antenna`, `VmCore._bar`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._dshk`, `VmCore._eye`, `VmCore._hatch`, `VmCore._hollow_tyre`, `VmCore._idler`, `VmCore._oct`, `VmCore._on_face`, `VmCore._path`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._round_ring`, `VmCore._rz`, `VmCore._shackle`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._tube`, `VmCore._wheel_disc`.

### orca, orca_armed

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.slide_rail`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWeapons.rotary`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._orca:1152](../scripts\game\vehicles\vm_heli.gd#L1152)
- the windscreen, chin windows, cockpit door windows ó [VmHeli._orca:1172](../scripts\game\vehicles\vm_heli.gd#L1172)
- the sliding doors and a window behind them ó [VmHeli._orca:1177](../scripts\game\vehicles\vm_heli.gd#L1177)
- the roof fairing with the engine intakes and exhausts ó [VmHeli._orca:1183](../scripts\game\vehicles\vm_heli.gd#L1183)
- the fenestron: shroud with its open duct, the fin, the tailplane ó [VmHeli._orca:1197](../scripts\game\vehicles\vm_heli.gd#L1197)
- tricycle wheels: the nosewheel, mains in their fairings ó [VmHeli._orca:1207](../scripts\game\vehicles\vm_heli.gd#L1207)
- side pylons: a minigun on the left, a rocket pod on the right ó [VmHeli._orca:1214](../scripts\game\vehicles\vm_heli.gd#L1214)
- the rotor: four blades with swept tips under a domed hub cap ó [VmHeli._orca:1224](../scripts\game\vehicles\vm_heli.gd#L1224)

**Local helper construction:** `VmHeli._door_rail`, `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skin`, `VmHeli._tube`.

### panther

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._panther:1143](../scripts\game\vehicles\vm_nato.gd#L1143)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### patrol_ship

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.panel_hatch`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarine.fender`, `VehicleMarine.mooring`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.pintle`, `VehicleMounts.radar_array`, `VehicleMounts.radome`, `VehicleMounts.receiver`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.hmg`.

**Authored sections:**

- Unlabelled construction / setup ó [VmShips._patrol_ship:573](../scripts\game\vehicles\vm_ships.gd#L573)
- spray rails and chine flats on the bottom, the rubbing strake under the deck edge, a toe rail round the open decks, a capping on the bulwark ó [VmShips._patrol_ship:584](../scripts\game\vehicles\vm_ships.gd#L584)
- scuppers along the deck edge, exhaust outlets low aft, the hull number ó [VmShips._patrol_ship:614](../scripts\game\vehicles\vm_ships.gd#L614)
- draft marks at the stem and stern ó [VmShips._patrol_ship:623](../scripts\game\vehicles\vm_ships.gd#L623)
- --- the deckhouse: the pilothouse forward, the lower after house ó [VmShips._patrol_ship:628](../scripts\game\vehicles\vm_ships.gd#L628)
- the window band: dark surrounds, then the panes, pillars between them ó [VmShips._patrol_ship:640](../scripts\game\vehicles\vm_ships.gd#L640)
- window pillars at the facet corners, wipers on the windscreen ó [VmShips._patrol_ship:659](../scripts\game\vehicles\vm_ships.gd#L659)
- the roof, its visor over the windscreen, a coaming round its edge ó [VmShips._patrol_ship:665](../scripts\game\vehicles\vm_ships.gd#L665)
- the pilothouse's after wall above the after house: two small windows, a door to the roof ó [VmShips._patrol_ship:673](../scripts\game\vehicles\vm_ships.gd#L673)
- the after house: doors and portholes in its sides, a ladder up its back ó [VmShips._patrol_ship:676](../scripts\game\vehicles\vm_ships.gd#L676)
- the frame round the opening, the watertight door in it and its dogs ó [VmShips._patrol_ship:687](../scripts\game\vehicles\vm_ships.gd#L687)
- a life ring, a fire-hose box, the team panel ó [VmShips._patrol_ship:697](../scripts\game\vehicles\vm_ships.gd#L697)
- navigation sidelights on the pilothouse shoulders, red to port ó [VmShips._patrol_ship:701](../scripts\game\vehicles\vm_ships.gd#L701)
- --- the after house's roof: rails round it, four liferafts tipped outboard, the satcom dome, HVAC boxes, whips at the corners ó [VmShips._patrol_ship:709](../scripts\game\vehicles\vm_ships.gd#L709)
- the HVAC units, the bigger one's louvred grille facing forward ó [VmShips._patrol_ship:726](../scripts\game\vehicles\vm_ships.gd#L726)
- --- the pilothouse roof: the raked mast with the radar, searchlights, the EO ball, the horn, whips ó [VmShips._patrol_ship:730](../scripts\game\vehicles\vm_ships.gd#L730)
- the topmast, the yardarm with its lights and halyards, the masthead light ó [VmShips._patrol_ship:741](../scripts\game\vehicles\vm_ships.gd#L741)
- the EO ball standing on its neck, one window looking ahead ó [VmShips._patrol_ship:754](../scripts\game\vehicles\vm_ships.gd#L754)
- --- the foredeck: the forward Mk 38 (the turret), its ready-use lockers, a hatch, the windlass, bitts, the jackstaff and the anchor on its roller ó [VmShips._patrol_ship:756](../scripts\game\vehicles\vm_ships.gd#L756)
- fairleads through the bulwark by the bow bitts ó [VmShips._patrol_ship:769](../scripts\game\vehicles\vm_ships.gd#L769)
- the hatch, hinged at its forward edge and laid to the deck's sheer, and the dogs that close it down ó [VmShips._patrol_ship:773](../scripts\game\vehicles\vm_ships.gd#L773)
- the anchor: shank up on the roller, its flukes against the stem ó [VmShips._patrol_ship:792](../scripts\game\vehicles\vm_ships.gd#L792)
- --- lifelines from the bulwark's end aft round the stern, a gate at the transom ó [VmShips._patrol_ship:799](../scripts\game\vehicles\vm_ships.gd#L799)
- --- side decks: .50 cals on pedestals beside the pilothouse and aft ó [VmShips._patrol_ship:821](../scripts\game\vehicles\vm_ships.gd#L821)
- --- the after deck: the second Mk 38 trained aft, its lockers, hatches, vents, fenders, the ensign staff, the waterjets on the transom ó [VmShips._patrol_ship:827](../scripts\game\vehicles\vm_ships.gd#L827)
- the stern light on the staff's after face, looking aft ó [VmShips._patrol_ship:843](../scripts\game\vehicles\vm_ships.gd#L843)
- the stern's exhaust pipes ó [VmShips._patrol_ship:853](../scripts\game\vehicles\vm_ships.gd#L853)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._leaf`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_pitch`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._m2`, `VmShips._mk38`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._stem_z`, `VmShips._surf`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._vent`, `VmShips._whip`.

### prowler, prowler_at, prowler_hmg

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.bench`, `VehicleCab.dashboard`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.light_bar`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.roll_bar`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.pedestal`, `VehicleMounts.pintle`, `VehicleMounts.receiver`, `VehicleMounts.ring_mount`, `VehicleMounts.sight`, `VehicleProfiles.loft`, `VehicleRunningGear.wishbone`, `VehicleSurface.plane`, `VehicleWeapons.hmg`, `VehicleWeapons.launch_tube`, `VehicleWeapons.mmg`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._prowler:424](../scripts\game\vehicles\vm_nato.gd#L424)
- --- the chassis tub, belly plate and suspension ó [VmNato._prowler:429](../scripts\game\vehicles\vm_nato.gd#L429)
- the long-travel wishbones, each coil-over on the axle's outer side ó [VmNato._prowler:434](../scripts\game\vehicles\vm_nato.gd#L434)
- --- the flat bonnet, its fenders and the nose ó [VmNato._prowler:437](../scripts\game\vehicles\vm_nato.gd#L437)
- each fender sloping down outboard, the front one with a raked lip ó [VmNato._prowler:441](../scripts\game\vehicles\vm_nato.gd#L441)
- tube bumper with the winch, lights each side and on the cage ó [VmNato._prowler:446](../scripts\game\vehicles\vm_nato.gd#L446)
- --- the cockpit: dash, the cowl, seats, steering wheel ó [VmNato._prowler:452](../scripts\game\vehicles\vm_nato.gd#L452)
- rear deck: outward-facing benches either side, kit stowed between ó [VmNato._prowler:460](../scripts\game\vehicles\vm_nato.gd#L460)
- the spare wheel upright on the tailgate ó [VmNato._prowler:469](../scripts\game\vehicles\vm_nato.gd#L469)
- --- the roll cage: each side's A-pillar bent into the roof rail and on down over the deck to the tail, the B and C posts, side bar and diagonal, then the roof hoops across ó [VmNato._prowler:474](../scripts\game\vehicles\vm_nato.gd#L474)
- the work light bar on the front roof bar, antennas at the back ó [VmNato._prowler:493](../scripts\game\vehicles\vm_nato.gd#L493)
- the passenger's pintle MG (an M240-class .338) on a swing arm ó [VmNato._prowler:501](../scripts\game\vehicles\vm_nato.gd#L501)
- the ring mount on the cage roof, turning whole with the gun: the ring, the carriage bar across it under the post, the post clamped to the bar ó [VmNato._prowler:505](../scripts\game\vehicles\vm_nato.gd#L505)
- the pintle gun is the second gun, decoration here ó [VmNato._prowler:515](../scripts\game\vehicles\vm_nato.gd#L515)
- Titan launcher: the tube, the sight/command unit, the grip ó [VmNato._prowler:517](../scripts\game\vehicles\vm_nato.gd#L517)
- two reloads, each in its own launch tube, in a rack on the deck ó [VmNato._prowler:523](../scripts\game\vehicles\vm_nato.gd#L523)

**Local helper construction:** `VmNato._ammo_can`, `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._seat`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### qilin, qilin_at, qilin_mg

**Shared:** `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.bench`, `VehicleCab.dashboard`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleDoors.hinge`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.roll_bar`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.pedestal`, `VehicleMounts.ring_mount`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.launch_tube`, `VehicleWeapons.rotary`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._qilin:362](../scripts\game\vehicles\vm_csat.gd#L362)
- the belly pan and chassis rails ó [VmCsat._qilin:364](../scripts\game\vehicles\vm_csat.gd#L364)
- the nose over the radiator: a sloping bonnet ó [VmCsat._qilin:366](../scripts\game\vehicles\vm_csat.gd#L366)
- a vent in the bonnet before the screen ó [VmCsat._qilin:372](../scripts\game\vehicles\vm_csat.gd#L372)
- the open crew tub: floor and low side walls, the rear engine deck ó [VmCsat._qilin:376](../scripts\game\vehicles\vm_csat.gd#L376)
- the dash under the screen frame, the steering wheel, the seats ó [VmCsat._qilin:381](../scripts\game\vehicles\vm_csat.gd#L381)
- the passengers' benches over the engine, back to back, facing out, their backs meeting on the centre line ó [VmCsat._qilin:387](../scripts\game\vehicles\vm_csat.gd#L387)
- fenders: faceted mudguards over the wheels, steps between them ó [VmCsat._qilin:391](../scripts\game\vehicles\vm_csat.gd#L391)
- round headlamps behind their guard straps, the tail lights ó [VmCsat._qilin:398](../scripts\game\vehicles\vm_csat.gd#L398)
- mirrors on the screen frame ó [VmCsat._qilin:401](../scripts\game\vehicles\vm_csat.gd#L401)
- the exhaust's tail pipe out of the right rear, an open end ó [VmCsat._qilin:403](../scripts\game\vehicles\vm_csat.gd#L403)
- the grille, the bull bar's hoop over it and the bumper tube below ó [VmCsat._qilin:405](../scripts\game\vehicles\vm_csat.gd#L405)
- the spare wheel upright on the tail, jerrycans beside it ó [VmCsat._qilin:411](../scripts\game\vehicles\vm_csat.gd#L411)
- its carrier bolted to the tail below the hub, rising from the deck's edge ó [VmCsat._qilin:413](../scripts\game\vehicles\vm_csat.gd#L413)
- the roll cage: each side's A-pillar, roof rail and rear stay bent from one tube, the B and C hoops' legs and the cross bars welded to it, the dash bar across the front and a diagonal across the B hoop ó [VmCsat._qilin:417](../scripts\game\vehicles\vm_csat.gd#L417)
- braces from the B hoop's feet up toward the rear rails ó [VmCsat._qilin:432](../scripts\game\vehicles\vm_csat.gd#L432)
- the weapon ring on the cage over the gunner's station, braced out to the cage's sides; an armed Qilin's gun rides it on a carriage ó [VmCsat._qilin:435](../scripts\game\vehicles\vm_csat.gd#L435)
- the gun's post on the carriage, its cradle on top ó [VmCsat._qilin:446](../scripts\game\vehicles\vm_csat.gd#L446)
- the minigun: six barrels round a spindle, the motor and feed chute ó [VmCsat._qilin:450](../scripts\game\vehicles\vm_csat.gd#L450)
- the Vorona: a fat launch tube on a cradle, the thermal sight beside it ó [VmCsat._qilin:462](../scripts\game\vehicles\vm_csat.gd#L462)
- the thermal sight looks out through one big objective, 11 cm across ó [VmCsat._qilin:466](../scripts\game\vehicles\vm_csat.gd#L466)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._arch_offset`, `VmCsat._face_rot`, `VmCsat._jerrycan`, `VmCsat._plate`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### quadbike

**Shared:** `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleProfiles.revolve`, `VehicleRunningGear.wishbone`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._quad:912](../scripts\game\vehicles\vm_civ.gd#L912)
- frame, engine, swingarm ó [VmCiv._quad:918](../scripts\game\vehicles\vm_civ.gd#L918)
- double wishbones, the knuckle between them and a red coil-over to each front wheel ó [VmCiv._quad:921](../scripts\game\vehicles\vm_civ.gd#L921)
- the front body over the wheels, the console and tank, the rear body ó [VmCiv._quad:930](../scripts\game\vehicles\vm_civ.gd#L930)
- floorboards with their raised lips ó [VmCiv._quad:935](../scripts\game\vehicles\vm_civ.gd#L935)
- tubular racks front and back ó [VmCiv._quad:943](../scripts\game\vehicles\vm_civ.gd#L943)
- handlebars and the pod with its headlight, grips, levers ó [VmCiv._quad:956](../scripts\game\vehicles\vm_civ.gd#L956)
- (the pod is the headlight's housing, the lamp low in its tilted face) ó [VmCiv._quad:964](../scripts\game\vehicles\vm_civ.gd#L964)
- the brush guard, its cross bar clamped across the legs a third of the way up; the tail light, the exhaust from the engine back through its silencer, a tow hitch ó [VmCiv._quad:967](../scripts\game\vehicles\vm_civ.gd#L967)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._xbody`.

### rhib

**Shared:** `VehicleBody.bead`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.panel_hatch`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.roll_bar`, `VehicleFrames.tube`, `VehicleMarine.bow_eye`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radome`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._rhib:693](../scripts\game\vehicles\vm_boat.gd#L693)
- spray rails along the bottom ó [VmBoat._rhib:704](../scripts\game\vehicles\vm_boat.gd#L704)
- the collar: runs along the sheer, kicks up at the bow, its ends past the transom ó [VmBoat._rhib:718](../scripts\game\vehicles\vm_boat.gd#L718)
- the centre console under its radar arch ó [VmBoat._rhib:742](../scripts\game\vehicles\vm_boat.gd#L742)
- side lights on the console's shoulders, the team panel below them ó [VmBoat._rhib:757](../scripts\game\vehicles\vm_boat.gd#L757)
- the arch: two legs a side up to a platform with the radar, lights, whips. Each side is one tube bent up from its front foot, along under the platform's edge and down to its back foot, the feet bolted to the deck on plates; a rail between the legs is clamped on halfway up. ó [VmBoat._rhib:760](../scripts\game\vehicles\vm_boat.gd#L760)
- the masthead light's pole runs up into the light's base ó [VmBoat._rhib:774](../scripts\game\vehicles\vm_boat.gd#L774)
- The driver perches on the front of the first starboard seat to reach the wheel. ó [VmBoat._rhib:779](../scripts\game\vehicles\vm_boat.gd#L779)
- two rows of jockey seats, each with a grab bar ó [VmBoat._rhib:782](../scripts\game\vehicles\vm_boat.gd#L782)
- a seat box forward of the console with its cushion, the stern locker ó [VmBoat._rhib:792](../scripts\game\vehicles\vm_boat.gd#L792)
- bow: an anchor locker hatch hinged at its forward edge (laid on the deck as it rises to the bow), a cleat and the towing eye on the stem ó [VmBoat._rhib:798](../scripts\game\vehicles\vm_boat.gd#L798)
- twin outboards and the tie bar between them ó [VmBoat._rhib:809](../scripts\game\vehicles\vm_boat.gd#L809)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._tube`, `VmBoat._tube_kit`, `VmBoat._u`.

### rhino, rhino_up

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleRunningGear.wishbone`, `VehicleSurface.plane`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._rhino:646](../scripts\game\vehicles\vm_nato.gd#L646)
- the lower hull: a pointed nose under the glacis, sides inboard of the wheels ó [VmNato._rhino:651](../scripts\game\vehicles\vm_nato.gd#L651)
- the upper hull: the arrowhead nose climbing to a narrow front of the roof ó [VmNato._rhino:656](../scripts\game\vehicles\vm_nato.gd#L656)
- the driver's hatch centred at the top of the glacis, his periscopes, lights in guards on the nose, tow eyes ó [VmNato._rhino:664](../scripts\game\vehicles\vm_nato.gd#L664)
- big stowage bins along the leaning sides, the engine deck louvres ó [VmNato._rhino:673](../scripts\game\vehicles\vm_nato.gd#L673)
- --- the turret: wedged front faces round the gun, a long bustle ó [VmNato._rhino:685](../scripts\game\vehicles\vm_nato.gd#L685)
- the gun: mantlet, barrel with its thermal sleeve and fume extractor, the muzzle reference sensor ó [VmNato._rhino:692](../scripts\game\vehicles\vm_nato.gd#L692)
- sights: the gunner's ahead on the left, the commander's cupola and his panoramic sight on the right; the loader's hatch ó [VmNato._rhino:703](../scripts\game\vehicles\vm_nato.gd#L703)
- bins on the bustle sides ó [VmNato._rhino:712](../scripts\game\vehicles\vm_nato.gd#L712)
- the crosswind sensor on its mast ó [VmNato._rhino:717](../scripts\game\vehicles\vm_nato.gd#L717)
- a small sensor head on each front corner of the roof, its window forward ó [VmNato._rhino:720](../scripts\game\vehicles\vm_nato.gd#L720)
- --- urban package: ERA bricks on the turret front and cheeks and along the glacis, slat cages round the hull sides and back, a remote .50 ó [VmNato._rhino:728](../scripts\game\vehicles\vm_nato.gd#L728)
- the turret's front cheeks and the forward half of its sides ó [VmNato._rhino:731](../scripts\game\vehicles\vm_nato.gd#L731)
- both plates of the arrowhead glacis ó [VmNato._rhino:734](../scripts\game\vehicles\vm_nato.gd#L734)
- slat cages: a frame standing off each side and across the back ó [VmNato._rhino:736](../scripts\game\vehicles\vm_nato.gd#L736)
- the remote weapon station on the turret roof (it turns with the gun) ó [VmNato._rhino:744](../scripts\game\vehicles\vm_nato.gd#L744)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._era`, `VmNato._face_basis`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._xy_bin`.

### sandstorm

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.sight`, `VehicleMounts.travel_lock`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._sandstorm:1015](../scripts\game\vehicles\vm_nato.gd#L1015)
- the crew's cupola and periscopes forward, where a turret would be ó [VmNato._sandstorm:1018](../scripts\game\vehicles\vm_nato.gd#L1018)
- the launcher's travel rest on the roof, where the box's front end sits: two posts up from the deck and the padded bar across them ó [VmNato._sandstorm:1025](../scripts\game\vehicles\vm_nato.gd#L1025)
- the turntable and the launcher's base with its elevation rams ó [VmNato._sandstorm:1028](../scripts\game\vehicles\vm_nato.gd#L1028)
- the launcher box: hinged at its rear end, the pods' tubes facing forward ó [VmNato._sandstorm:1036](../scripts\game\vehicles\vm_nato.gd#L1036)
- each pod's face standing proud of the box on its end plate: six tube mouths in two rows behind the frangible covers ó [VmNato._sandstorm:1044](../scripts\game\vehicles\vm_nato.gd#L1044)
- ribs down the sides, the boom-hoists along the top edges ó [VmNato._sandstorm:1047](../scripts\game\vehicles\vm_nato.gd#L1047)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### scorcher

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.travel_lock`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.muzzle_brake`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._scorcher:962](../scripts\game\vehicles\vm_nato.gd#L962)
- the barrel's travel lock folded down on the glacis: one box arm from its hinge low on the plate up to the cradle ó [VmNato._scorcher:965](../scripts\game\vehicles\vm_nato.gd#L965)
- the tall box: sloped front faces, vertical sides, the bustle ó [VmNato._scorcher:973](../scripts\game\vehicles\vm_nato.gd#L973)
- side doors, roof hatches, the commander's cupola with a remote .50 ó [VmNato._scorcher:977](../scripts\game\vehicles\vm_nato.gd#L977)
- each door's face turned out of its own side, the grab bar near its front ó [VmNato._scorcher:979](../scripts\game\vehicles\vm_nato.gd#L979)
- the gun: trunnions at the turret front, the cradle, recoil cylinders, the long tube with its fume extractor and the double-baffle muzzle brake ó [VmNato._scorcher:993](../scripts\game\vehicles\vm_nato.gd#L993)
- the tube ends inside the brake's sleeve, so its windows stay open ó [VmNato._scorcher:1001](../scripts\game\vehicles\vm_nato.gd#L1001)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### sdv

**Shared:** `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.pull`, `VehicleFittings.headlamp`, `VehicleFittings.lifting_eye`, `VehicleFittings.searchlight`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._sdv:822](../scripts\game\vehicles\vm_boat.gd#L822)
- the raised hatch deck over the crew compartment, and its four hatches ó [VmBoat._sdv:833](../scripts\game\vehicles\vm_boat.gd#L833)
- forward: the pilot's and navigator's canopy, split down the middle, with viewports in its sloped front and sides ó [VmBoat._sdv:836](../scripts\game\vehicles\vm_boat.gd#L836)
- aft: the passengers' two flat hatches ó [VmBoat._sdv:852](../scripts\game\vehicles\vm_boat.gd#L852)
- lifting eyes at the deck's corners ó [VmBoat._sdv:859](../scripts\game\vehicles\vm_boat.gd#L859)
- the mast with the periscope head and a comms antenna beside it ó [VmBoat._sdv:863](../scripts\game\vehicles\vm_boat.gd#L863)
- nose: the sonar window and two lamps ó [VmBoat._sdv:870](../scripts\game\vehicles\vm_boat.gd#L870)
- the free-flooding hull's vent grilles and panel seams down each side ó [VmBoat._sdv:874](../scripts\game\vehicles\vm_boat.gd#L874)
- the skids it rests on ó [VmBoat._sdv:883](../scripts\game\vehicles\vm_boat.gd#L883)
- tail: the cone's end, cruciform fins and the duct round the propeller ó [VmBoat._sdv:885](../scripts\game\vehicles\vm_boat.gd#L885)

**Local helper construction:** `VmBoat._foil`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._sring`.

### sentinel

**Shared:** `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.drum`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._sentinel:953](../scripts\game\vehicles\vm_plane.gd#L953)
- the dorsal intake: a raked hood standing off the hump, its dark mouth ó [VmPlane._sentinel:969](../scripts\game\vehicles\vm_plane.gd#L969)
- the exhaust buried in the upper surface at the back ó [VmPlane._sentinel:974](../scripts\game\vehicles\vm_plane.gd#L974)
- (no exhaust glow: the pipe is buried in the upper surface to hide it) ó [VmPlane._sentinel:977](../scripts\game\vehicles\vm_plane.gd#L977)
- the cranked outer wings: elevons, the fold line ó [VmPlane._sentinel:979](../scripts\game\vehicles\vm_plane.gd#L979)
- body elevons along the inner trailing edges ó [VmPlane._sentinel:983](../scripts\game\vehicles\vm_plane.gd#L983)
- the sensor window under the nose, belly doors, the hook, antennas ó [VmPlane._sentinel:989](../scripts\game\vehicles\vm_plane.gd#L989)
- flush satcom and GPS patches on the hump, the refuelling probe door ó [VmPlane._sentinel:997](../scripts\game\vehicles\vm_plane.gd#L997)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### shikra

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.duct`, `VehicleAircraft.fin_set`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.missile`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.rod_mesh`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._shikra:737](../scripts\game\vehicles\vm_plane.gd#L737)
- the nacelles, raked intakes under the LEVCONs, round Su-35 nozzles ó [VmPlane._shikra:764](../scripts\game\vehicles\vm_plane.gd#L764)
- LEVCONs, the wing with ailerons and flaperons ó [VmPlane._shikra:773](../scripts\game\vehicles\vm_plane.gd#L773)
- tail booms carrying the all-moving tailplanes; all-moving canted fins ó [VmPlane._shikra:777](../scripts\game\vehicles\vm_plane.gd#L777)
- the sting between the nozzles ó [VmPlane._shikra:783](../scripts\game\vehicles\vm_plane.gd#L783)
- the gun at the right wing root, antennas, navigation lights ó [VmPlane._shikra:785](../scripts\game\vehicles\vm_plane.gd#L785)
- stores: Kh-38s under the nacelles, KAB bombs and R-73s under the wings ó [VmPlane._shikra:792](../scripts\game\vehicles\vm_plane.gd#L792)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### slammer, slammer_up

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_cable`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.pintle`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._slammer:953](../scripts\game\vehicles\vm_nato.gd#L953)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._chain`, `VmNato._era`, `VmNato._face_basis`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._mk_turret`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._xy`, `VmNato._zy_grille`, `VmNato._zy_hatch`.

### sochor

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.track_guard`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleEquipment.vessel`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.travel_lock`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWeapons.muzzle_brake`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._sochor:969](../scripts\game\vehicles\vm_csat.gd#L969)
- flat sides: a crew door, stowage boxes, vents; the ammunition door at the back ó [VmCsat._sochor:977](../scripts\game\vehicles\vm_csat.gd#L977)
- each crew door's sealed face looks out of its own side ó [VmCsat._sochor:979](../scripts\game\vehicles\vm_csat.gd#L979)
- a louvred vent on the side plate, which has leaned in to 1.5 m out at the vent's height ó [VmCsat._sochor:983](../scripts\game\vehicles\vm_csat.gd#L983)
- roof: hatches, the commander's panoramic sight, the remote 12.7 mm ó [VmCsat._sochor:991](../scripts\game\vehicles\vm_csat.gd#L991)
- the barrel on its trunnions: mantlet, recoil cylinders, fume extractor, the long tube ending inside the double-baffle muzzle brake's sleeve ó [VmCsat._sochor:998](../scripts\game\vehicles\vm_csat.gd#L998)
- the travel lock, folded down on the glacis: two arms converging from their hinges on the nose to the cradle ó [VmCsat._sochor:1010](../scripts\game\vehicles\vm_csat.gd#L1010)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### speedboat_hmg, speedboat_minigun

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarine.bow_eye`, `VehicleMarine.mooring`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.pedestal`, `VehicleMounts.radar_array`, `VehicleMounts.radome`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._surc:910](../scripts\game\vehicles\vm_boat.gd#L910)
- the fendering strake along the knuckle, spray rails on the bottom ó [VmBoat._surc:918](../scripts\game\vehicles\vm_boat.gd#L918)
- non-skid decks: the open troop deck aft and the foredeck ó [VmBoat._surc:938](../scripts\game\vehicles\vm_boat.gd#L938)
- armoured bulwarks round the troop deck, capped ó [VmBoat._surc:942](../scripts\game\vehicles\vm_boat.gd#L942)
- the bulwarks' ballistic panels: seams down their sloped faces ó [VmBoat._surc:954](../scripts\game\vehicles\vm_boat.gd#L954)
- the transom's bulwark, with a gate in the middle ó [VmBoat._surc:959](../scripts\game\vehicles\vm_boat.gd#L959)
- the cabin: near-vertical armoured walls, a band of steeply slanted glass ó [VmBoat._surc:963](../scripts\game\vehicles\vm_boat.gd#L963)
- the rear: a door below, a window above it ó [VmBoat._surc:982](../scripts\game\vehicles\vm_boat.gd#L982)
- wipers on the windscreen, armour seams on the lower walls ó [VmBoat._surc:988](../scripts\game\vehicles\vm_boat.gd#L988)
- side lights on the cabin's shoulders, the team panel aft of them ó [VmBoat._surc:993](../scripts\game\vehicles\vm_boat.gd#L993)
- the roof: a raked mast with the radar, a satcom dome, whips, searchlight, smoke dischargers at the front corners, grab rails ó [VmBoat._surc:996](../scripts\game\vehicles\vm_boat.gd#L996)
- side-deck handrails along the cabin ó [VmBoat._surc:1011](../scripts\game\vehicles\vm_boat.gd#L1011)
- the troop deck: benches with backrests along both bulwarks, facing inboard ó [VmBoat._surc:1018](../scripts\game\vehicles\vm_boat.gd#L1018)
- the rear gun on its pedestal ring mount, looking aft over the quarter (the post up from the deck into the race ring the gun's head turns on) ó [VmBoat._surc:1024](../scripts\game\vehicles\vm_boat.gd#L1024)
- 12.7 mm HMG: a long receiver, a heavy barrel with its muzzle brake, the ammunition can on the left (the spade grips are the mount's, below) ó [VmBoat._surc:1037](../scripts\game\vehicles\vm_boat.gd#L1037)
- M134 minigun: six barrels in a clamp, the motor housing, the feed chute ó [VmBoat._surc:1041](../scripts\game\vehicles\vm_boat.gd#L1041)
- bow remote weapon station: 40 mm GMG, sight on the right, ammo on the left ó [VmBoat._surc:1048](../scripts\game\vehicles\vm_boat.gd#L1048)
- the GMG feeds from the station's own box, not a container of its own ó [VmBoat._surc:1059](../scripts\game\vehicles\vm_boat.gd#L1059)
- the sight head: the day camera's window over the thermal imager's ó [VmBoat._surc:1062](../scripts\game\vehicles\vm_boat.gd#L1062)
- foredeck: twin bitts, a cleat each side, the towing eye on the stem (the bitts' posts 0.24 m apart, 6 cm round and 0.24 m tall) ó [VmBoat._surc:1066](../scripts\game\vehicles\vm_boat.gd#L1066)
- transom: twin waterjets with their steering nozzles and raised reversing buckets, tucked under a stern step; the stern light ó [VmBoat._surc:1075](../scripts\game\vehicles\vm_boat.gd#L1075)
- the towing eye standing out of the transom ó [VmBoat._surc:1087](../scripts\game\vehicles\vm_boat.gd#L1087)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._leaf`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### stomper

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.radome`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._stomper:1522](../scripts\game\vehicles\vm_nato.gd#L1522)
- the swing arm from the hull to the hub, its motor housing ó [VmNato._stomper:1528](../scripts\game\vehicles\vm_nato.gd#L1528)
- the armoured tub: a wedge nose, the flanks leaning in ó [VmNato._stomper:1531](../scripts\game\vehicles\vm_nato.gd#L1531)
- side pods over the wheels (batteries / engine), angular, low ó [VmNato._stomper:1536](../scripts\game\vehicles\vm_nato.gd#L1536)
- the space frame over the tub: rails, hoops and diagonals ó [VmNato._stomper:1539](../scripts\game\vehicles\vm_nato.gd#L1539)
- the sensor mast at the nose, raked forward over it: stereo cameras, laser scanners, a GPS dome ó [VmNato._stomper:1549](../scripts\game\vehicles\vm_nato.gd#L1549)
- the RCWS on the frame ó [VmNato._stomper:1567](../scripts\game\vehicles\vm_nato.gd#L1567)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### strider, strider_gmg, strider_hmg

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.lever`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._strider:166](../scripts\game\vehicles\vm_indep.gd#L166)
- the belly between the wheels (its front sloping under the nose) ó [VmIndep._strider:173](../scripts\game\vehicles\vm_indep.gd#L173)
- the nose and tail blocks ahead of and behind the wheel arches, the sills between ó [VmIndep._strider:175](../scripts\game\vehicles\vm_indep.gd#L175)
- the upper hull: a chine all round, then the armoured nose and windscreen in one steep slope, the cabin's sides leaning in, the engine deck a step lower at the back ó [VmIndep._strider:180](../scripts\game\vehicles\vm_indep.gd#L180)
- wheels in their dark wells, mud flaps behind the rear ones ó [VmIndep._strider:186](../scripts\game\vehicles\vm_indep.gd#L186)
- the arch's lip ó [VmIndep._strider:191](../scripts\game\vehicles\vm_indep.gd#L191)
- windscreen: two armoured panes in heavy frames on the slope, the pillar between ó [VmIndep._strider:194](../scripts\game\vehicles\vm_indep.gd#L194)
- a wiper over each pane ó [VmIndep._strider:201](../scripts\game\vehicles\vm_indep.gd#L201)
- the nose: headlight clusters in guards, tow shackles, a plate ó [VmIndep._strider:206](../scripts\game\vehicles\vm_indep.gd#L206)
- mirrors on their arms by the windscreen ó [VmIndep._strider:212](../scripts\game\vehicles\vm_indep.gd#L212)
- the side door: seams, an armoured window, the handle, a step below ó [VmIndep._strider:214](../scripts\game\vehicles\vm_indep.gd#L214)
- the shut lines up the sill and on up the cabin's leaning side ó [VmIndep._strider:217](../scripts\game\vehicles\vm_indep.gd#L217)
- a small rear-quarter window, the stowage bin over the rear wheel ó [VmIndep._strider:224](../scripts\game\vehicles\vm_indep.gd#L224)
- smoke dischargers on the deck corners, a whip antenna at each back corner ó [VmIndep._strider:228](../scripts\game\vehicles\vm_indep.gd#L228)
- rear: tail light clusters, the jerrycan rack on the left, a box on the right ó [VmIndep._strider:231](../scripts\game\vehicles\vm_indep.gd#L231)
- the box's catches face out the back, its lid hinged on the hull side ó [VmIndep._strider:236](../scripts\game\vehicles\vm_indep.gd#L236)
- the towing jaw between the tow eyes ó [VmIndep._strider:238](../scripts\game\vehicles\vm_indep.gd#L238)
- exhaust out of the right flank behind the rear wheel, under a heat shield ó [VmIndep._strider:240](../scripts\game\vehicles\vm_indep.gd#L240)
- roof: the driver's and commander's hatches with periscopes, the observer's hatch behind ó [VmIndep._strider:243](../scripts\game\vehicles\vm_indep.gd#L243)
- hinged at the front, by the periscopes, the handle at the back ó [VmIndep._strider:246](../scripts\game\vehicles\vm_indep.gd#L246)
- engine deck: two grilles with their slats, standing just proud of the deck so the radiator core shows below them ó [VmIndep._strider:251](../scripts\game\vehicles\vm_indep.gd#L251)
- the scout: the BAA sensor head (camera, thermal imager, rangefinder) high on a telescopic mast behind the cabin; the head pans ó [VmIndep._strider:259](../scripts\game\vehicles\vm_indep.gd#L259)
- the commander's periscope mast, folded low at the cabin's back corner ó [VmIndep._strider:270](../scripts\game\vehicles\vm_indep.gd#L270)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._tow_eyes`.

### suv

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleDoors.pull`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.silencer`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._suv:1143](../scripts\game\vehicles\vm_civ.gd#L1143)
- doors, chrome handles, the shoulder crease, black skirts, mirrors (each shut line as (z, its foot): the rear one stops on the arch) ó [VmCiv._suv:1171](../scripts\game\vehicles\vm_civ.gd#L1171)
- headlights flanking the kidneys, two rings in each, wrapping round ó [VmCiv._suv:1180](../scripts\game\vehicles\vm_civ.gd#L1180)
- the tail lights across the corners, a reflector under them ó [VmCiv._suv:1188](../scripts\game\vehicles\vm_civ.gd#L1188)
- lower intakes and fog lights, exhausts ó [VmCiv._suv:1192](../scripts\game\vehicles\vm_civ.gd#L1192)
- the twin kidneys: chrome-rimmed grilles of upright slats, 3 cm proud of the nose ó [VmCiv._suv:1197](../scripts\game\vehicles\vm_civ.gd#L1197)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._xbody`.

### tank

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.track_guard`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.lifting_eye`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mast_segment`, `VehicleMounts.pintle`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.coax`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._abrams:390](../scripts\game\vehicles\vm_core.gd#L390)
- --- running gear: front idler, seven road wheels, rear sprocket ó [VmCore._abrams:393](../scripts\game\vehicles\vm_core.gd#L393)
- --- the hull: the belly between the tracks with the lower glacis at its front, the upper hull out over the tracks with the long upper glacis ó [VmCore._abrams:412](../scripts\game\vehicles\vm_core.gd#L412)
- the glacis: the driver's hatch in the middle at its top, his three periscopes; a seam across the nose, lifting eyes ó [VmCore._abrams:421](../scripts\game\vehicles\vm_core.gd#L421)
- (the lid turned to lie on the glacis, hinged toward its top, its centre half its thickness out of the plate; the pivot boss on its back edge) ó [VmCore._abrams:425](../scripts\game\vehicles\vm_core.gd#L425)
- the front: headlight clusters in their guards on the fender tops, tow shackles on the lower glacis, the front fenders' rubber flaps ó [VmCore._abrams:436](../scripts\game\vehicles\vm_core.gd#L436)
- Rolled fenders wrap the top of the front idlers and hold the rubber flaps. ó [VmCore._abrams:443](../scripts\game\vehicles\vm_core.gd#L443)
- (turned about Y so its clamp bar and bolts face forward) ó [VmCore._abrams:446](../scripts\game\vehicles\vm_core.gd#L446)
- skirts: seven bolted panels a side, the first two heavy armoured ones, the front panel raked over the idler; a bolt line along their tops ó [VmCore._abrams:448](../scripts\game\vehicles\vm_core.gd#L448)
- the handrail-like lip of the fender over the skirts, a rear mudguard over the sprocket with its rubber flap ó [VmCore._abrams:475](../scripts\game\vehicles\vm_core.gd#L475)
- fuel filler caps on the deck over the sponsons ó [VmCore._abrams:480](../scripts\game\vehicles\vm_core.gd#L480)
- The recognition chevron lies flush on the skirt. ó [VmCore._abrams:483](../scripts\game\vehicles\vm_core.gd#L483)
- --- the engine deck: the big grille doors over the turbine and the transmission, the centre access plate, lifting eyes ó [VmCore._abrams:488](../scripts\game\vehicles\vm_core.gd#L488)
- --- the rear plate: the turbine exhaust grille across the middle, the tail light clusters, tow pintle and shackles, the infantry phone box ó [VmCore._abrams:496](../scripts\game\vehicles\vm_core.gd#L496)
- (each cluster sits in a deep armoured housing) ó [VmCore._abrams:500](../scripts\game\vehicles\vm_core.gd#L500)
- --- the turret ó [VmCore._abrams:505](../scripts\game\vehicles\vm_core.gd#L505)
- the main body: the crew compartment and the long bustle over the deck ó [VmCore._abrams:510](../scripts\game\vehicles\vm_core.gd#L510)
- the cheeks: armour blocks either side of the gun shield, swept back in plan, their faces near vertical over a deep undercut ó [VmCore._abrams:514](../scripts\game\vehicles\vm_core.gd#L514)
- the seam where the cheek block meets the turret side ó [VmCore._abrams:526](../scripts\game\vehicles\vm_core.gd#L526)
- the gun shield, recessed between the cheeks; the gunner's auxiliary sight port on it, the coax M240 to its right ó [VmCore._abrams:528](../scripts\game\vehicles\vm_core.gd#L528)
- the 120 mm: the sleeve in sections with their clamp bands, the bore evacuator, the muzzle and its reference sensor ó [VmCore._abrams:536](../scripts\game\vehicles\vm_core.gd#L536)
- --- the roof: the gunner's primary sight doghouse front right with its armoured doors, the commander's independent thermal viewer front left ó [VmCore._abrams:546](../scripts\game\vehicles\vm_core.gd#L546)
- (turned about Y so the leaf's finished face looks forward) ó [VmCore._abrams:551](../scripts\game\vehicles\vm_core.gd#L551)
- the commander's station on the right: the cupola ring with its vision blocks, the hatch, the .50 on its mount ahead of it ó [VmCore._abrams:559](../scripts\game\vehicles\vm_core.gd#L559)
- (the pintle's cradle goes under the .50's receiver, 10 cm behind roof_gun) ó [VmCore._abrams:565](../scripts\game\vehicles\vm_core.gd#L565)
- the loader's hatch on the left and his M240 on its pintle behind the gun shield kit, the pintle's socket on the roof just ahead of the hatch ring ó [VmCore._abrams:568](../scripts\game\vehicles\vm_core.gd#L568)
- the crosswind sensor mast at the back of the roof, the blow-off panels over the ammunition in the bustle, lifting eyes, antennas ó [VmCore._abrams:580](../scripts\game\vehicles\vm_core.gd#L580)
- M250 smoke dischargers on the flanks behind the cheeks ó [VmCore._abrams:590](../scripts\game\vehicles\vm_core.gd#L590)
- stowage boxes along the turret sides, their lids and latches ó [VmCore._abrams:592](../scripts\game\vehicles\vm_core.gd#L592)
- the bustle rack: a basket round the back of the bustle, packed with kit ó [VmCore._abrams:611](../scripts\game\vehicles\vm_core.gd#L611)
- A packed roll flattens where it rests and pinches under each webbing strap. ó [VmCore._abrams:613](../scripts\game\vehicles\vm_core.gd#L613)

**Local helper construction:** `VmCore._antenna`, `VmCore._bar`, `VmCore._bedroll`, `VmCore._belt`, `VmCore._breakaway_skirt`, `VmCore._bx`, `VmCore._eye`, `VmCore._hatch`, `VmCore._hollow_tyre`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._m2`, `VmCore._mirror`, `VmCore._mmg`, `VmCore._oct`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._skirt_bolt`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._wheel_disc`, `VmCore._zy`.

### taru

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.gear_leg`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.antenna`, `VehicleFittings.dome_light`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.hub_cap`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleSurface.plane`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._taru:1237](../scripts\game\vehicles\vm_heli.gd#L1237)
- the spine ó [VmHeli._taru:1243](../scripts\game\vehicles\vm_heli.gd#L1243)
- the cab, glazed all round its nose ó [VmHeli._taru:1254](../scripts\game\vehicles\vm_heli.gd#L1254)
- the engines and the gearbox fairing on the spine ó [VmHeli._taru:1276](../scripts\game\vehicles\vm_heli.gd#L1276)
- the tailplane with its twin fins, a ventral fin ó [VmHeli._taru:1291](../scripts\game\vehicles\vm_heli.gd#L1291)
- the legs: long oleo struts splayed out from the spine, braced ó [VmHeli._taru:1296](../scripts\game\vehicles\vm_heli.gd#L1296)
- the strut runs down to the axle's fitting over the wheel; one brace meets its barrel, the other its gland nut ó [VmHeli._taru:1301](../scripts\game\vehicles\vm_heli.gd#L1301)
- the transport pod on its four hooks ó [VmHeli._taru:1309](../scripts\game\vehicles\vm_heli.gd#L1309)
- the rear doors: their frame, the leaf, the split between the two halves ó [VmHeli._taru:1323](../scripts\game\vehicles\vm_heli.gd#L1323)
- the coaxial rotors: three blades each, turning against each other ó [VmHeli._taru:1335](../scripts\game\vehicles\vm_heli.gd#L1335)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._skin`, `VmHeli._tube`.

### tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.body_door`, `VehicleCargo.crate_stack`, `VehicleCargo.flatbed`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.roller_shutter`, `VehicleCargo.rung_ladder`, `VehicleCargo.shelter`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.gas_bottle`, `VehicleEquipment.pump_cabinet`, `VehicleEquipment.storage`, `VehicleEquipment.tanker_top`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.light_bar`, `VehicleFittings.marker`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarkings.cross`, `VehicleMarkings.cross_outline`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.bumper`, `VehicleMounts.crane`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._tempest:1205](../scripts\game\vehicles\vm_csat.gd#L1205)
- long missile crates stacked three high forward, rows of ammunition boxes behind them, each stack on its pallet and strapped down, cans at the tail. Shorter stacked cases preserve the clearance below the folded boom. ó [VmCsat._tempest:1211](../scripts\game\vehicles\vm_csat.gd#L1211)
- the loading crane behind the cab on its king post, its boom folded back over the load, the extension run out to the hook at its end ó [VmCsat._tempest:1221](../scripts\game\vehicles\vm_csat.gd#L1221)
- roller shutters on the sides, toolboxes under the body ó [VmCsat._tempest:1230](../scripts\game\vehicles\vm_csat.gd#L1230)
- the workshop's back door onto the platform, hinged on its right; its sill clears the body's bottom rail ó [VmCsat._tempest:1234](../scripts\game\vehicles\vm_csat.gd#L1234)
- the crane on the open platform behind on its king post, its boom luffed down along the roof onto its rest, the hook block at its head ó [VmCsat._tempest:1237](../scripts\game\vehicles\vm_csat.gd#L1237)
- a spare wheel standing on the platform, the welding set's oxygen and acetylene bottles in their rack against the bed side ó [VmCsat._tempest:1241](../scripts\game\vehicles\vm_csat.gd#L1241)
- the rear door with its window and steps (its sill clear of the body's bottom rail), the cross beside it, the roof's air units ó [VmCsat._tempest:1254](../scripts\game\vehicles\vm_csat.gd#L1254)
- the walkway along the crown over three manholes between folding handrails, the ladder up the barrel's back ó [VmCsat._tempest:1268](../scripts\game\vehicles\vm_csat.gd#L1268)
- the pump cabinet with its outlet and the hose reel at the back ó [VmCsat._tempest:1273](../scripts\game\vehicles\vm_csat.gd#L1273)
- troops: armoured sides, the canvas cover on its bows ó [VmCsat._tempest:1279](../scripts\game\vehicles\vm_csat.gd#L1279)
- the boarding ladder hung on the tailgate, its stiles toward the truck ó [VmCsat._tempest:1292](../scripts\game\vehicles\vm_csat.gd#L1292)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._arch_offset`, `VmCsat._cross`, `VmCsat._face_rot`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._locker`, `VmCsat._onface`, `VmCsat._plate`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tempest_box`, `VmCsat._tempest_flatbed`, `VmCsat._tow`, `VmCsat._typhoon`.

### tigris

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.skirt_bow`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.radar_array`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._tigris:749](../scripts\game\vehicles\vm_csat.gd#L749)
- the guns: a 35 mm in a cradle on each side, ammunition feed fairings ó [VmCsat._tigris:755](../scripts\game\vehicles\vm_csat.gd#L755)
- the tracking radar in its housing on the front of the roof ó [VmCsat._tigris:766](../scripts\game\vehicles\vm_csat.gd#L766)
- the optical sight beside it ó [VmCsat._tigris:769](../scripts\game\vehicles\vm_csat.gd#L769)
- the search radar: a flat antenna on a mast at the back ó [VmCsat._tigris:771](../scripts\game\vehicles\vm_csat.gd#L771)
- twin missile boxes either side of the mast ó [VmCsat._tigris:775](../scripts\game\vehicles\vm_csat.gd#L775)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._face_rot`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### tractor

**Shared:** `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleDoors.pull`, `VehicleFittings.air_cleaner`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.light_bar`, `VehicleFittings.mirror`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWheelArches.liner`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._tractor:1285](../scripts\game\vehicles\vm_civ.gd#L1285)
- engine, gearbox and the rear axle housings, the front beam axle ó [VmCiv._tractor:1295](../scripts\game\vehicles\vm_civ.gd#L1295)
- the bonnet, its grille and lamps, the weights hung on the front ó [VmCiv._tractor:1302](../scripts\game\vehicles\vm_civ.gd#L1302)
- louvres along the bonnet sides ó [VmCiv._tractor:1307](../scripts\game\vehicles\vm_civ.gd#L1307)
- wheels: small fronts under cycle wings, big rears with chevron lugs ó [VmCiv._tractor:1314](../scripts\game\vehicles\vm_civ.gd#L1314)
- the mudguards: a wide curved guard and its inner wall ó [VmCiv._tractor:1325](../scripts\game\vehicles\vm_civ.gd#L1325)
- the cab: floor, posts, white roof, glass all round ó [VmCiv._tractor:1335](../scripts\game\vehicles\vm_civ.gd#L1335)
- inside: the seat and the wheel ó [VmCiv._tractor:1358](../scripts\game\vehicles\vm_civ.gd#L1358)
- exhaust stack with its silencer and rain cap, the air intake stack with its pre-cleaner ó [VmCiv._tractor:1362](../scripts\game\vehicles\vm_civ.gd#L1362)
- steps on the left, the three-point hitch and the PTO at the back ó [VmCiv._tractor:1368](../scripts\game\vehicles\vm_civ.gd#L1368)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._xbody`.

### truck

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.bench`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.body_door`, `VehicleCargo.crate_stack`, `VehicleCargo.flatbed`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.roller_shutter`, `VehicleCargo.rung_ladder`, `VehicleCargo.shelter`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.drum`, `VehicleEquipment.gas_bottle`, `VehicleEquipment.pump_cabinet`, `VehicleEquipment.storage`, `VehicleEquipment.tanker_top`, `VehicleEquipment.vessel`, `VehicleFittings.air_cleaner`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.marker`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.bull_bar`, `VehicleFrames.cyl`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarkings.cross`, `VehicleMarkings.cross_outline`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.bumper`, `VehicleMounts.crane`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.missile_face`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._truck:1815](../scripts\game\vehicles\vm_core.gd#L1815)
- the chassis: frame rails, the axles and their diffs, the wheels ó [VmCore._truck:1819](../scripts\game\vehicles\vm_core.gd#L1819)
- the bonnet with the radiator grille in its nose, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks (the grilles lean with the bonnet's faces) ó [VmCore._truck:1825](../scripts\game\vehicles\vm_core.gd#L1825)
- the louvres down the bonnet's sides ó [VmCore._truck:1836](../scripts\game\vehicles\vm_core.gd#L1836)
- the brush guard: its hoop and three uprights standing on the bumper ó [VmCore._truck:1838](../scripts\game\vehicles\vm_core.gd#L1838)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms ó [VmCore._truck:1844](../scripts\game\vehicles\vm_core.gd#L1844)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box ó [VmCore._truck:1859](../scripts\game\vehicles\vm_core.gd#L1859)
- bolted through its hub to a carrier on the cab's back ó [VmCore._truck:1861](../scripts\game\vehicles\vm_core.gd#L1861)
- the cargo bed: the plank floor, the dropsides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle ó [VmCore._truck:1865](../scripts\game\vehicles\vm_core.gd#L1865)
- The tilt's section: straight walls 0.9 m high, then a half-ellipse roof 1.16 m to each side and 0.49 m high; the cloth hangs between the bows. ó [VmCore._truck:1873](../scripts\game\vehicles\vm_core.gd#L1873)
- (the back flap laced shut across the tail, inside the last bow) ó [VmCore._truck:1880](../scripts\game\vehicles\vm_core.gd#L1880)
- Unlabelled construction / setup ó [VmIndep._zamak:778](../scripts\game\vehicles\vm_indep.gd#L778)
- Unlabelled construction / setup ó [VmNato._hemtt:1383](../scripts\game\vehicles\vm_nato.gd#L1383)
- the deck on its frame with its drop sides, six stake posts a side, the tailgate and the tall headboard, then the rear end ó [VmNato._hemtt:1390](../scripts\game\vehicles\vm_nato.gd#L1390)
- the canvas tilt over its bows, the back rolled up over the benches ó [VmNato._hemtt:1396](../scripts\game\vehicles\vm_nato.gd#L1396)
- the troop benches facing in, on folding legs, hinged to the sides ó [VmNato._hemtt:1404](../scripts\game\vehicles\vm_nato.gd#L1404)
- the boarding step under the tailgate ó [VmNato._hemtt:1408](../scripts\game\vehicles\vm_nato.gd#L1408)
- palletised crates and boxes lashed down, a tarp over one load ó [VmNato._hemtt:1411](../scripts\game\vehicles\vm_nato.gd#L1411)
- ammunition: pallets of boxes, four to a pallet and strapped down (plain pallet boards: slatted ones under ten stacks cost too many vertices), then the knuckle-boom crane at the back, folded forward over the load ó [VmNato._hemtt:1421](../scripts\game\vehicles\vm_nato.gd#L1421)
- the crane on its slewing ring and column with the main boom's luffing ram; the knuckle boom folded back under it, the hook at its end ó [VmNato._hemtt:1431](../scripts\game\vehicles\vm_nato.gd#L1431)
- the shelter: a tall square box body with plain sides, its rails and markers; the workshop has a ladder up the back and roof vents ó [VmNato._hemtt:1443](../scripts\game\vehicles\vm_nato.gd#L1443)
- roll-up shutters; the tool lockers hang under the deck between the axles, behind the fuel tank and battery box and clear of the tandem's wheels ó [VmNato._hemtt:1449](../scripts\game\vehicles\vm_nato.gd#L1449)
- the light mast, AC unit, the rear door ó [VmNato._hemtt:1455](../scripts\game\vehicles\vm_nato.gd#L1455)
- windows, the rear doors with a step, roof vents, red crosses ó [VmNato._hemtt:1462](../scripts\game\vehicles\vm_nato.gd#L1462)
- the tank: an oval barrel on cradles with its end caps, the walkway along its crown between folding rails over the three manholes, the pump cabinet and hose reels at the back ó [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477)
- the hazard placard ó [VmNato._hemtt:1485](../scripts\game\vehicles\vm_nato.gd#L1485)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._shackle`, `VmCore._taillight`, `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`, `VmNato._antenna`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_tail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### van_ambulance, van_services, van_transport

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleCargo.roof_rack`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.slide_rail`, `VehicleFittings.exhaust`, `VehicleFittings.exhaust_run`, `VehicleFittings.grille`, `VehicleFittings.headlamp`, `VehicleFittings.light_bar`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.silencer`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleGlazing.rectangle`, `VehicleMarkings.cross`, `VehicleMarkings.cross_outline`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheelArches.tub`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._van:759](../scripts\game\vehicles\vm_civ.gd#L759)
- the exhaust under the floor, its end open behind the rear axle ó [VmCiv._van:773](../scripts\game\vehicles\vm_civ.gd#L773)
- the bonnet, and the body with the windscreen and the high roof ó [VmCiv._van:775](../scripts\game\vehicles\vm_civ.gd#L775)
- windows: the cab doors always; the rest on the minibus, rear doors on all ó [VmCiv._van:782](../scripts\game\vehicles\vm_civ.gd#L782)
- shut lines: cab door, and on the right the sliding door with its rail ó [VmCiv._van:795](../scripts\game\vehicles\vm_civ.gd#L795)
- a black rubbing strip, the flares' lips, the tall tail lights ó [VmCiv._van:799](../scripts\game\vehicles\vm_civ.gd#L799)
- rear doors: windows, hinges ó [VmCiv._van:806](../scripts\game\vehicles\vm_civ.gd#L806)
- (the left leaf's hinges are the mirror image of the right's) ó [VmCiv._van:809](../scripts\game\vehicles\vm_civ.gd#L809)
- (the rail run back from the door along the window line, 1 cm proud) ó [VmCiv._van:814](../scripts\game\vehicles\vm_civ.gd#L814)
- the barn doors' meeting line and the handle on the right-hand leaf ó [VmCiv._van:817](../scripts\game\vehicles\vm_civ.gd#L817)
- rear bumper with its step, plate ó [VmCiv._van:821](../scripts\game\vehicles\vm_civ.gd#L821)
- the face: the three-slat grille 3 cm proud of the leaning nose, the star on its slats, big swept headlights, the bumper ó [VmCiv._van:825](../scripts\game\vehicles\vm_civ.gd#L825)
- the big headlight: across the front corner and back along the wing ó [VmCiv._van:834](../scripts\game\vehicles\vm_civ.gd#L834)
- the moulded bumper, the slatted intake low in its face (the bumper's black face behind the slats), the plate; wipers parked under the windscreen ó [VmCiv._van:844](../scripts\game\vehicles\vm_civ.gd#L844)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._van_ambulance`, `VmCiv._van_services`, `VmCiv._xbody`.

### varsuk

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleBody.track_guard`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleEquipment.vessel`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lamp_unit`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_bank`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.pintle`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.coax`, `VehicleWeapons.hmg`, `VehicleWeapons.missile_box`, `VehicleWeapons.missile_face`, `VehicleWeapons.muzzle_sensor`, `VehicleWheels.drum`, `VehicleWheels.road`, `VehicleWheels.roller`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._varsuk:879](../scripts\game\vehicles\vm_csat.gd#L879)
- the bustle: a long box hung off the turret's back ó [VmCsat._varsuk:885](../scripts\game\vehicles\vm_csat.gd#L885)
- reactive armour on the cheeks either side of the mantlet, and on the roof ó [VmCsat._varsuk:891](../scripts\game\vehicles\vm_csat.gd#L891)
- mantlet, gun, coax ó [VmCsat._varsuk:896](../scripts\game\vehicles\vm_csat.gd#L896)
- commander's cupola (right) with the 12.7 mm, gunner's sight (left front) ó [VmCsat._varsuk:902](../scripts\game\vehicles\vm_csat.gd#L902)
- Drozd launchers on the flanks, their radar heads on the cheeks, smoke ó [VmCsat._varsuk:906](../scripts\game\vehicles\vm_csat.gd#L906)
- antennas at the bustle's back corners ó [VmCsat._varsuk:913](../scripts\game\vehicles\vm_csat.gd#L913)
- stowage on the bustle's back, a wind sensor mast ó [VmCsat._varsuk:915](../scripts\game\vehicles\vm_csat.gd#L915)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._cupola_mg`, `VmCsat._era`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### water_scooter

**Shared:** `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.filler`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleMarine.bow_eye`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._scooter:1108](../scripts\game\vehicles\vm_boat.gd#L1108)
- the bumper strake round the sheer and a livery band along each side ó [VmBoat._scooter:1116](../scripts\game\vehicles\vm_boat.gd#L1116)
- low gunwale lips round the footwells ó [VmBoat._scooter:1125](../scripts\game\vehicles\vm_boat.gd#L1125)
- sponsons near the stern ó [VmBoat._scooter:1132](../scripts\game\vehicles\vm_boat.gd#L1132)
- the hood: a rounded dome rising from the bow to the handlebar pod ó [VmBoat._scooter:1136](../scripts\game\vehicles\vm_boat.gd#L1136)
- the pedestal and the stepped three-place saddle on it ó [VmBoat._scooter:1144](../scripts\game\vehicles\vm_boat.gd#L1144)
- footwell mats ó [VmBoat._scooter:1159](../scripts\game\vehicles\vm_boat.gd#L1159)
- the boarding platform, its step and the grab handle behind the saddle ó [VmBoat._scooter:1161](../scripts\game\vehicles\vm_boat.gd#L1161)
- jet nozzle and reverse gate under the stern, tow eyes at both ends ó [VmBoat._scooter:1165](../scripts\game\vehicles\vm_boat.gd#L1165)
- the handlebar pod, bars and grips, a smoked visor, the display ó [VmBoat._scooter:1171](../scripts\game\vehicles\vm_boat.gd#L1171)
- mirrors on stalks off the pod ó [VmBoat._scooter:1176](../scripts\game\vehicles\vm_boat.gd#L1176)
- a strap across the pillion seat, grey panels down the pedestal's sides, air vents on the hood's shoulders, the fuel cap ó [VmBoat._scooter:1183](../scripts\game\vehicles\vm_boat.gd#L1183)
- (on the hood's dome section at z = -0.75: half-width 0.495 from 0.464 up 0.441) ó [VmBoat._scooter:1188](../scripts\game\vehicles\vm_boat.gd#L1188)
- the hood's storage hatch seam ó [VmBoat._scooter:1194](../scripts\game\vehicles\vm_boat.gd#L1194)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cushion`, `VmBoat._dome`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### wipeout

**Shared:** `VehicleAircraft.bomb`, `VehicleAircraft.fin_set`, `VehicleAircraft.formation_light`, `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.missile`, `VehicleAircraft.pitot`, `VehicleAircraft.refuel_receptacle`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.seeker`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.headlamp`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.searchlight`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.cyl`, `VehicleFrames.path`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.digit_quads`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.polygons`, `VehicleMarkings.stroke_quads`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.rotary`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`.

**Authored sections:**

- Unlabelled construction / setup ó [VmAttack._wipeout:764](../scripts\game\vehicles\vm_attack.gd#L764)
- [z, cx, cy, chine half-width, height above the chine, depth below, deck half-width, belly half-width, ridge] ó [VmAttack._wipeout:768](../scripts\game\vehicles\vm_attack.gd#L768)
- panel joints: thin raised frames round the fuselage ó [VmAttack._wipeout:787](../scripts\game\vehicles\vm_attack.gd#L787)

**Local helper construction:** `VmAttack._canopy_half`, `VmAttack._decal`, `VmAttack._facet`, `VmAttack._falchion`, `VmAttack._fbody`, `VmAttack._gear_nodes`, `VmAttack._hring`, `VmAttack._lathe`, `VmAttack._nac_half`, `VmAttack._sheet`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmAttack._wip_cockpit`, `VmAttack._wip_details`, `VmAttack._wip_engines`, `VmAttack._wip_gear`, `VmAttack._wip_gun`, `VmAttack._wip_stores`, `VmAttack._wip_tail`, `VmAttack._wip_wing`, `VmAttack._wst`, `VmAttack._zigzag`, `VmPlane._foil_t`, `VmPlane._tri`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### xian

**Shared:** `VehicleAircraft.chin_turret`, `VehicleAircraft.hardpoint`, `VehicleAircraft.intake_face`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.rod`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.rod_mesh`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehiclePropellers.disc_material`, `VehicleWeapons.launch_tube`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._xian:1101](../scripts\game\vehicles\vm_plane.gd#L1101)
- the stepped cockpit: the gunner's bubble low in front, the pilot's above ó [VmPlane._xian:1121](../scripts\game\vehicles\vm_plane.gd#L1121)
- the chin turret: a twin 23 mm that traverses ó [VmPlane._xian:1130](../scripts\game\vehicles\vm_plane.gd#L1130)
- troop doors on both sides, hinged at their front edges, a window in each and another aft of it, all fitted to the curved flanks; the rear ramp ó [VmPlane._xian:1137](../scripts\game\vehicles\vm_plane.gd#L1137)
- the wings, a lift fan in each, ailerons outboard ó [VmPlane._xian:1147](../scripts\game\vehicles\vm_plane.gd#L1147)
- wingtip pod with the lights ó [VmPlane._xian:1155](../scripts\game\vehicles\vm_plane.gd#L1155)
- stub wings below, with their stores ó [VmPlane._xian:1158](../scripts\game\vehicles\vm_plane.gd#L1158)
- four missile tubes packed two by two under the rack plate, held up to it by two strap cradles ó [VmPlane._xian:1169](../scripts\game\vehicles\vm_plane.gd#L1169)
- twin turbofans high on the back, vectoring nozzles, a fairing between them ó [VmPlane._xian:1179](../scripts\game\vehicles\vm_plane.gd#L1179)
- the fan face in the mouth, square to its lip (raked 0.3 aft per metre up, so it looks a little upward), the spinner standing out ahead ó [VmPlane._xian:1186](../scripts\game\vehicles\vm_plane.gd#L1186)
- twin tails canted outboard of the engines, rudders ó [VmPlane._xian:1193](../scripts\game\vehicles\vm_plane.gd#L1193)
- probes, antennas, the sensor under the nose ó [VmPlane._xian:1195](../scripts\game\vehicles\vm_plane.gd#L1195)

**Local helper construction:** `VmPlane._flank`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.lift_fan`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair

**Shared:** `VehicleBody.bead`, `VehicleBody.boundary`, `VehicleBody.cylinder`, `VehicleBody.drum`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleBody.rod`, `VehicleBody.seam`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.body_door`, `VehicleCargo.crate_stack`, `VehicleCargo.flatbed`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.roller_shutter`, `VehicleCargo.rung_ladder`, `VehicleCargo.shelter`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.drum`, `VehicleEquipment.gas_bottle`, `VehicleEquipment.pump_cabinet`, `VehicleEquipment.storage`, `VehicleEquipment.tanker_top`, `VehicleEquipment.vessel`, `VehicleFittings.air_cleaner`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lamp_unit`, `VehicleFittings.marker`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.silencer`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cyl`, `VehicleFrames.hose_reel`, `VehicleFrames.path`, `VehicleFrames.ram`, `VehicleFrames.rod_mesh`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMarkings.cross`, `VehicleMarkings.cross_outline`, `VehicleMarkings.digit_strokes`, `VehicleMarkings.plate`, `VehicleMarkings.stroke_rects`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.bumper`, `VehicleMounts.crane`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.missile_face`, `VehicleWheels.carrier`, `VehicleWheels.drum`, `VehicleWheels.pneumatic`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._zamak:778](../scripts\game\vehicles\vm_indep.gd#L778)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`.

## Local helper section index

### VmAttack._a10_cockpit

- Unlabelled construction / setup ó [VmAttack._a10_cockpit:334](../scripts\game\vehicles\vm_attack.gd#L334)
- the windscreen bow, the canopy's own front and rear frames ó [VmAttack._a10_cockpit:345](../scripts\game\vehicles\vm_attack.gd#L345)
- the windscreen's two corner posts: a flat front panel and side quarter lights ó [VmAttack._a10_cockpit:349](../scripts\game\vehicles\vm_attack.gd#L349)
- the canopy rails along both sills ó [VmAttack._a10_cockpit:353](../scripts\game\vehicles\vm_attack.gd#L353)
- the fairing behind the canopy, down into the spine ó [VmAttack._a10_cockpit:357](../scripts\game\vehicles\vm_attack.gd#L357)
- the refuelling receptacle (UARRSI) on the nose, its slipway lines ó [VmAttack._a10_cockpit:362](../scripts\game\vehicles\vm_attack.gd#L362)
- the boarding ladder's door under the left canopy rail ó [VmAttack._a10_cockpit:368](../scripts\game\vehicles\vm_attack.gd#L368)

### VmAttack._a10_details

- Unlabelled construction / setup ó [VmAttack._a10_details:641](../scripts\game\vehicles\vm_attack.gd#L641)
- navigation lights on the Hoerner tips, the anti-collision strobes ó [VmAttack._a10_details:642](../scripts\game\vehicles\vm_attack.gd#L642)
- the formation ("slime") lights: pale strips on the nose, the tail and fins ó [VmAttack._a10_details:647](../scripts\game\vehicles\vm_attack.gd#L647)
- the chaff and flare dispensers under the wing tips ó [VmAttack._a10_details:655](../scripts\game\vehicles\vm_attack.gd#L655)
- static dischargers trailing from the ailerons, the elevators and rudders ó [VmAttack._a10_details:658](../scripts\game\vehicles\vm_attack.gd#L658)
- antennas: UHF/VHF blades on the spine and belly, the IFF and TACAN, a GPS dome ó [VmAttack._a10_details:669](../scripts\game\vehicles\vm_attack.gd#L669)
- the angle-of-attack vane and a pitot probe on the nose's flanks ó [VmAttack._a10_details:676](../scripts\game\vehicles\vm_attack.gd#L676)
- the false canopy painted under the nose ó [VmAttack._a10_details:680](../scripts\game\vehicles\vm_attack.gd#L680)
- a Rebel airframe: their identification panels on the wings ó [VmAttack._a10_details:689](../scripts\game\vehicles\vm_attack.gd#L689)
- the low-vis star-and-bar on the nacelles' outer flanks, the upper left and the lower right wing; "USAF" is left off at this size ó [VmAttack._a10_details:692](../scripts\game\vehicles\vm_attack.gd#L692)
- "USAF" across the upper right wing and the lower left one, read from behind ó [VmAttack._a10_details:706](../scripts\game\vehicles\vm_attack.gd#L706)

### VmAttack._a10_engines

- Unlabelled construction / setup ó [VmAttack._a10_engines:443](../scripts\game\vehicles\vm_attack.gd#L443)
- deep inside the intake: the fan face, its 18 blades and spinner ó [VmAttack._a10_engines:460](../scripts\game\vehicles\vm_attack.gd#L460)
- the fan exhaust: the dark annulus between the core cowl and the nozzle ó [VmAttack._a10_engines:462](../scripts\game\vehicles\vm_attack.gd#L462)
- cowling joints round the nacelle: rings, since a solid disc at the first one (0.45 in) would close the intake ahead of the fan ó [VmAttack._a10_engines:465](../scripts\game\vehicles\vm_attack.gd#L465)
- the pylon from the fuselage shoulder to the nacelle's inner flank ó [VmAttack._a10_engines:469](../scripts\game\vehicles\vm_attack.gd#L469)

### VmAttack._a10_gear

- Unlabelled construction / setup ó [VmAttack._a10_gear:529](../scripts\game\vehicles\vm_attack.gd#L529)
- the open well along the pod's belly the wheel hangs out of ó [VmAttack._a10_gear:541](../scripts\game\vehicles\vm_attack.gd#L541)
- the chaff and flare dispensers in the pod's tail ó [VmAttack._a10_gear:543](../scripts\game\vehicles\vm_attack.gd#L543)
- retracted: the tyre a third out of the pod ó [VmAttack._a10_gear:545](../scripts\game\vehicles\vm_attack.gd#L545)
- let down: the wheel below and a little aft, the leg slanting from the pod's nose, its drag brace and torque links ó [VmAttack._a10_gear:549](../scripts\game\vehicles\vm_attack.gd#L549)
- the nose gear well's doors (closed in flight) ó [VmAttack._a10_gear:557](../scripts\game\vehicles\vm_attack.gd#L557)
- the taxi light on the leg ó [VmAttack._a10_gear:572](../scripts\game\vehicles\vm_attack.gd#L572)
- the two long well doors hanging open, their outer skins facing out ó [VmAttack._a10_gear:574](../scripts\game\vehicles\vm_attack.gd#L574)

### VmAttack._a10_gun

- Unlabelled construction / setup ó [VmAttack._a10_gun:376](../scripts\game\vehicles\vm_attack.gd#L376)
- the gun port: a dark recess in the nose's lower face ó [VmAttack._a10_gun:377](../scripts\game\vehicles\vm_attack.gd#L377)
- the seven barrels out of the port, held by the mid support ring and the muzzle clamp ó [VmAttack._a10_gun:380](../scripts\game\vehicles\vm_attack.gd#L380)
- gun gas soot fanning back under the nose ó [VmAttack._a10_gun:385](../scripts\game\vehicles\vm_attack.gd#L385)

### VmAttack._a10_stores

- Unlabelled construction / setup ó [VmAttack._a10_stores:586](../scripts\game\vehicles\vm_attack.gd#L586)
- a Maverick on a single LAU-117 rail ó [VmAttack._a10_stores:594](../scripts\game\vehicles\vm_attack.gd#L594)
- two Mavericks on the shoulders of a LAU-88 ó [VmAttack._a10_stores:599](../scripts\game\vehicles\vm_attack.gd#L599)
- two Sidewinders on a LAU-105 dual rail ó [VmAttack._a10_stores:612](../scripts\game\vehicles\vm_attack.gd#L612)
- the fuselage stations either side of the centre line, empty ó [VmAttack._a10_stores:617](../scripts\game\vehicles\vm_attack.gd#L617)

### VmAttack._a10_tail

- Unlabelled construction / setup ó [VmAttack._a10_tail:481](../scripts\game\vehicles\vm_attack.gd#L481)
- the elevator trim tabs ó [VmAttack._a10_tail:485](../scripts\game\vehicles\vm_attack.gd#L485)
- the fin-tip cap and its tail light ó [VmAttack._a10_tail:497](../scripts\game\vehicles\vm_attack.gd#L497)
- Moody's "FT" tail code, the serial and a black fin-tip band, both sides ó [VmAttack._a10_tail:505](../scripts\game\vehicles\vm_attack.gd#L505)
- (the band runs from just behind the fin's leading edge to the rudder's end) ó [VmAttack._a10_tail:517](../scripts\game\vehicles\vm_attack.gd#L517)

### VmAttack._a10_wing

- Unlabelled construction / setup ó [VmAttack._a10_wing:401](../scripts\game\vehicles\vm_attack.gd#L401)
- the Hoerner tips: the skin curling down at the ends ó [VmAttack._a10_wing:405](../scripts\game\vehicles\vm_attack.gd#L405)
- the deceleron split line along each aileron's trailing edge ó [VmAttack._a10_wing:407](../scripts\game\vehicles\vm_attack.gd#L407)
- panel lines on the upper skins: the slat and leading-edge panels, the spar joints, the centre-section break, the walkway ó [VmAttack._a10_wing:414](../scripts\game\vehicles\vm_attack.gd#L414)
- the black no-step walkway outline by the root ó [VmAttack._a10_wing:431](../scripts\game\vehicles\vm_attack.gd#L431)

### VmAttack._canopy_half

- Unlabelled construction / setup ó [VmAttack._canopy_half:840](../scripts\game\vehicles\vm_attack.gd#L840)

### VmAttack._decal

- Unlabelled construction / setup ó [VmAttack._decal:130](../scripts\game\vehicles\vm_attack.gd#L130)

### VmAttack._ecm_pod

- Unlabelled construction / setup ó [VmAttack._ecm_pod:634](../scripts\game\vehicles\vm_attack.gd#L634)

### VmAttack._facet

- Unlabelled construction / setup ó [VmAttack._facet:79](../scripts\game\vehicles\vm_attack.gd#L79)

### VmAttack._falchion

- it runs from the seeker dome's tip (0.465 len and the dome ahead of ctr) to the nozzle (0.5 len behind), and the missile's stations count from the middle of that ó [VmAttack._falchion:1078](../scripts\game\vehicles\vm_attack.gd#L1078)

### VmAttack._fbody

- Unlabelled construction / setup ó [VmAttack._fbody:743](../scripts\game\vehicles\vm_attack.gd#L743)

### VmAttack._fin_at

- Unlabelled construction / setup ó [VmAttack._fin_at:237](../scripts\game\vehicles\vm_attack.gd#L237)

### VmAttack._gear_nodes

- Unlabelled construction / setup ó [VmAttack._gear_nodes:252](../scripts\game\vehicles\vm_attack.gd#L252)

### VmAttack._hring

- Unlabelled construction / setup ó [VmAttack._hring:63](../scripts\game\vehicles\vm_attack.gd#L63)

### VmAttack._lathe

- Unlabelled construction / setup ó [VmAttack._lathe:52](../scripts\game\vehicles\vm_attack.gd#L52)

### VmAttack._nac_half

- Unlabelled construction / setup ó [VmAttack._nac_half:912](../scripts\game\vehicles\vm_attack.gd#L912)

### VmAttack._sec_pt

- Unlabelled construction / setup ó [VmAttack._sec_pt:195](../scripts\game\vehicles\vm_attack.gd#L195)

### VmAttack._sheet

- Unlabelled construction / setup ó [VmAttack._sheet:86](../scripts\game\vehicles\vm_attack.gd#L86)
- away from the axis (measured across the ring, not along it) ó [VmAttack._sheet:107](../scripts\game\vehicles\vm_attack.gd#L107)

### VmAttack._skin_x

- Unlabelled construction / setup ó [VmAttack._skin_x:217](../scripts\game\vehicles\vm_attack.gd#L217)

### VmAttack._skin_y

- Unlabelled construction / setup ó [VmAttack._skin_y:206](../scripts\game\vehicles\vm_attack.gd#L206)

### VmAttack._sniper

- Unlabelled construction / setup ó [VmAttack._sniper:626](../scripts\game\vehicles\vm_attack.gd#L626)

### VmAttack._star_bar

- Unlabelled construction / setup ó [VmAttack._star_bar:163](../scripts\game\vehicles\vm_attack.gd#L163)
- the bars: upper edge level with the star's arms, a radius long beyond the ring ó [VmAttack._star_bar:179](../scripts\game\vehicles\vm_attack.gd#L179)

### VmAttack._strokes

- Unlabelled construction / setup ó [VmAttack._strokes:137](../scripts\game\vehicles\vm_attack.gd#L137)

### VmAttack._text

- Unlabelled construction / setup ó [VmAttack._text:157](../scripts\game\vehicles\vm_attack.gd#L157)

### VmAttack._wheel

- Unlabelled construction / setup ó [VmAttack._wheel:274](../scripts\game\vehicles\vm_attack.gd#L274)

### VmAttack._wing_y

- Unlabelled construction / setup ó [VmAttack._wing_y:227](../scripts\game\vehicles\vm_attack.gd#L227)

### VmAttack._wip_cockpit

- Unlabelled construction / setup ó [VmAttack._wip_cockpit:808](../scripts\game\vehicles\vm_attack.gd#L808)
- [z, base height, half-width, height] ó [VmAttack._wip_cockpit:809](../scripts\game\vehicles\vm_attack.gd#L809)
- (a faint gold in the glass: the radar-reflective coating of a stealthy canopy) ó [VmAttack._wip_cockpit:815](../scripts\game\vehicles\vm_attack.gd#L815)
- frames: the armoured pane's bow, a hoop over the middle ó [VmAttack._wip_cockpit:817](../scripts\game\vehicles\vm_attack.gd#L817)
- the sills ó [VmAttack._wip_cockpit:824](../scripts\game\vehicles\vm_attack.gd#L824)
- the spine: a faceted fairing from the canopy back between the engines ó [VmAttack._wip_cockpit:830](../scripts\game\vehicles\vm_attack.gd#L830)
- the air-refuelling receptacle's door on the spine ó [VmAttack._wip_cockpit:834](../scripts\game\vehicles\vm_attack.gd#L834)

### VmAttack._wip_details

- Unlabelled construction / setup ó [VmAttack._wip_details:1090](../scripts\game\vehicles\vm_attack.gd#L1090)
- formation light strips along the chines ó [VmAttack._wip_details:1094](../scripts\game\vehicles\vm_attack.gd#L1094)
- antennas on the spine and belly, the angle-of-attack probes ó [VmAttack._wip_details:1101](../scripts\game\vehicles\vm_attack.gd#L1101)
- static dischargers on the wing tips ó [VmAttack._wip_details:1111](../scripts\game\vehicles\vm_attack.gd#L1111)
- light grey low-vis markings: the star-and-bar on the fuselage's upper flanks and the left wing, a tail code and serial on the fins ó [VmAttack._wip_details:1122](../scripts\game\vehicles\vm_attack.gd#L1122)
- the fin's outer skin, q.y up its span from the root: the airfoil's thickness there, at that point of the chord ó [VmAttack._wip_details:1141](../scripts\game\vehicles\vm_attack.gd#L1141)

### VmAttack._wip_engines

- Unlabelled construction / setup ó [VmAttack._wip_engines:920](../scripts\game\vehicles\vm_attack.gd#L920)
- the outer skin from the lip aft to the nozzle ó [VmAttack._wip_engines:928](../scripts\game\vehicles\vm_attack.gd#L928)
- the inlet's lip and duct, the fan face inside ó [VmAttack._wip_engines:932](../scripts\game\vehicles\vm_attack.gd#L932)
- the nozzle: its lip, the jet pipe's wall, the cone in it ó [VmAttack._wip_engines:937](../scripts\game\vehicles\vm_attack.gd#L937)
- cowling seams ó [VmAttack._wip_engines:943](../scripts\game\vehicles\vm_attack.gd#L943)
- the broad pylon blending the nacelle into the spine, tapered at both ends ó [VmAttack._wip_engines:948](../scripts\game\vehicles\vm_attack.gd#L948)
- the ends drawn in towards the pylon's middle ó [VmAttack._wip_engines:959](../scripts\game\vehicles\vm_attack.gd#L959)

### VmAttack._wip_gear

- Unlabelled construction / setup ó [VmAttack._wip_gear:998](../scripts\game\vehicles\vm_attack.gd#L998)
- the doors' seams along the belly, saw-toothed fore and aft ó [VmAttack._wip_gear:1009](../scripts\game\vehicles\vm_attack.gd#L1009)
- the pod's bay doors hanging open either side, their outer skins out ó [VmAttack._wip_gear:1023](../scripts\game\vehicles\vm_attack.gd#L1023)
- the nose gear on the centre line behind the gun fairing, its doors ó [VmAttack._wip_gear:1026](../scripts\game\vehicles\vm_attack.gd#L1026)
- the taxi light on the leg ó [VmAttack._wip_gear:1043](../scripts\game\vehicles\vm_attack.gd#L1043)

### VmAttack._wip_gun

- Unlabelled construction / setup ó [VmAttack._wip_gun:846](../scripts\game\vehicles\vm_attack.gd#L846)
- the barrels from inside the fairing, one clamp near the muzzles ó [VmAttack._wip_gun:852](../scripts\game\vehicles\vm_attack.gd#L852)
- the EO/IR targeting turret under the nose, its window looking ahead ó [VmAttack._wip_gun:856](../scripts\game\vehicles\vm_attack.gd#L856)

### VmAttack._wip_stores

- Unlabelled construction / setup ó [VmAttack._wip_stores:1051](../scripts\game\vehicles\vm_attack.gd#L1051)
- three Macers on a triple rack: two on the shoulders, one below ó [VmAttack._wip_stores:1059](../scripts\game\vehicles\vm_attack.gd#L1059)

### VmAttack._wip_tail

- Unlabelled construction / setup ó [VmAttack._wip_tail:973](../scripts\game\vehicles\vm_attack.gd#L973)
- the fin-tip fairing with its light ó [VmAttack._wip_tail:987](../scripts\game\vehicles\vm_attack.gd#L987)

### VmAttack._wip_wing

- Unlabelled construction / setup ó [VmAttack._wip_wing:868](../scripts\game\vehicles\vm_attack.gd#L868)
- the leading-edge root extensions: thin faceted strakes running forward from the wing roots along the chines ó [VmAttack._wip_wing:873](../scripts\game\vehicles\vm_attack.gd#L873)
- the deceleron split along the outer trailing edges ó [VmAttack._wip_wing:878](../scripts\game\vehicles\vm_attack.gd#L878)
- the lighter grey under the wing ó [VmAttack._wip_wing:884](../scripts\game\vehicles\vm_attack.gd#L884)
- panel lines on the upper skin ó [VmAttack._wip_wing:894](../scripts\game\vehicles\vm_attack.gd#L894)

### VmAttack._wst

- Unlabelled construction / setup ó [VmAttack._wst:725](../scripts\game\vehicles\vm_attack.gd#L725)

### VmAttack._zigzag

- Unlabelled construction / setup ó [VmAttack._zigzag:143](../scripts\game\vehicles\vm_attack.gd#L143)

### VmBoat._aim

- Unlabelled construction / setup ó [VmBoat._aim:278](../scripts\game\vehicles\vm_boat.gd#L278)

### VmBoat._bake

- Unlabelled construction / setup ó [VmBoat._bake:455](../scripts\game\vehicles\vm_boat.gd#L455)

### VmBoat._band

- Unlabelled construction / setup ó [VmBoat._band:156](../scripts\game\vehicles\vm_boat.gd#L156)

### VmBoat._band_mesh

- Unlabelled construction / setup ó [VmBoat._band_mesh:187](../scripts\game\vehicles\vm_boat.gd#L187)

### VmBoat._beam

- Unlabelled construction / setup ó [VmBoat._beam:148](../scripts\game\vehicles\vm_boat.gd#L148)

### VmBoat._cleat

- Unlabelled construction / setup ó [VmBoat._cleat:401](../scripts\game\vehicles\vm_boat.gd#L401)

### VmBoat._cushion

- Unlabelled construction / setup ó [VmBoat._cushion:1200](../scripts\game\vehicles\vm_boat.gd#L1200)

### VmBoat._deck_mesh

- Unlabelled construction / setup ó [VmBoat._deck_mesh:201](../scripts\game\vehicles\vm_boat.gd#L201)

### VmBoat._dome

- Unlabelled construction / setup ó [VmBoat._dome:1208](../scripts\game\vehicles\vm_boat.gd#L1208)
- At the last station rounding can put sin(PI) just below zero; a fractional power would make the hood's vertices and normals NaN. ó [VmBoat._dome:1212](../scripts\game\vehicles\vm_boat.gd#L1212)

### VmBoat._foil

- Unlabelled construction / setup ó [VmBoat._foil:257](../scripts\game\vehicles\vm_boat.gd#L257)

### VmBoat._hull

- Unlabelled construction / setup ó [VmBoat._hull:121](../scripts\game\vehicles\vm_boat.gd#L121)

### VmBoat._hw

- Unlabelled construction / setup ó [VmBoat._hw:131](../scripts\game\vehicles\vm_boat.gd#L131)

### VmBoat._leaf

- Unlabelled construction / setup ó [VmBoat._leaf:383](../scripts\game\vehicles\vm_boat.gd#L383)

### VmBoat._offset

- Unlabelled construction / setup ó [VmBoat._offset:322](../scripts\game\vehicles\vm_boat.gd#L322)

### VmBoat._outboard

- the clamp bracket on the transom and its tilt tube ó [VmBoat._outboard:416](../scripts\game\vehicles\vm_boat.gd#L416)
- swivel bracket and the leg, a streamlined strut down to the gearcase ó [VmBoat._outboard:427](../scripts\game\vehicles\vm_boat.gd#L427)
- anti-ventilation plate, the gearcase torpedo, skeg and propeller ó [VmBoat._outboard:431](../scripts\game\vehicles\vm_boat.gd#L431)
- the lower cowl (apron), the cowling with its parting line and air intake ó [VmBoat._outboard:437](../scripts\game\vehicles\vm_boat.gd#L437)

### VmBoat._panel

- Unlabelled construction / setup ó [VmBoat._panel:364](../scripts\game\vehicles\vm_boat.gd#L364)

### VmBoat._prop

- Unlabelled construction / setup ó [VmBoat._prop:406](../scripts\game\vehicles\vm_boat.gd#L406)

### VmBoat._pt

- Unlabelled construction / setup ó [VmBoat._pt:396](../scripts\game\vehicles\vm_boat.gd#L396)

### VmBoat._resample

- Unlabelled construction / setup ó [VmBoat._resample:303](../scripts\game\vehicles\vm_boat.gd#L303)

### VmBoat._rnd

- Unlabelled construction / setup ó [VmBoat._rnd:244](../scripts\game\vehicles\vm_boat.gd#L244)

### VmBoat._rod

- Unlabelled construction / setup ó [VmBoat._rod:288](../scripts\game\vehicles\vm_boat.gd#L288)

### VmBoat._rr

- Unlabelled construction / setup ó [VmBoat._rr:235](../scripts\game\vehicles\vm_boat.gd#L235)

### VmBoat._ry

- Unlabelled construction / setup ó [VmBoat._ry:229](../scripts\game\vehicles\vm_boat.gd#L229)

### VmBoat._rz

- Unlabelled construction / setup ó [VmBoat._rz:221](../scripts\game\vehicles\vm_boat.gd#L221)

### VmBoat._scale_xz

- Unlabelled construction / setup ó [VmBoat._scale_xz:1095](../scripts\game\vehicles\vm_boat.gd#L1095)

### VmBoat._sheer

- Unlabelled construction / setup ó [VmBoat._sheer:105](../scripts\game\vehicles\vm_boat.gd#L105)

### VmBoat._skin

- Unlabelled construction / setup ó [VmBoat._skin:176](../scripts\game\vehicles\vm_boat.gd#L176)

### VmBoat._slab

- Unlabelled construction / setup ó [VmBoat._slab:196](../scripts\game\vehicles\vm_boat.gd#L196)

### VmBoat._sring

- Unlabelled construction / setup ó [VmBoat._sring:265](../scripts\game\vehicles\vm_boat.gd#L265)

### VmBoat._station

- Unlabelled construction / setup ó [VmBoat._station:70](../scripts\game\vehicles\vm_boat.gd#L70)
- extra points on the topsides at "marks" (depths below the sheer), so a painted stripe there lies on flat faces of the hull, not across them ó [VmBoat._station:84](../scripts\game\vehicles\vm_boat.gd#L84)
- keep the section convex: a deep-V bow can't flare out above its chine, so there the chine eases onto the straight line from keel to sheer ó [VmBoat._station:90](../scripts\game\vehicles\vm_boat.gd#L90)

### VmBoat._stem

- Unlabelled construction / setup ó [VmBoat._stem:110](../scripts\game\vehicles\vm_boat.gd#L110)

### VmBoat._strip

- Unlabelled construction / setup ó [VmBoat._strip:212](../scripts\game\vehicles\vm_boat.gd#L212)

### VmBoat._top

- Unlabelled construction / setup ó [VmBoat._top:143](../scripts\game\vehicles\vm_boat.gd#L143)

### VmBoat._tube

- Unlabelled construction / setup ó [VmBoat._tube:294](../scripts\game\vehicles\vm_boat.gd#L294)

### VmBoat._tube_kit

- Unlabelled construction / setup ó [VmBoat._tube_kit:339](../scripts\game\vehicles\vm_boat.gd#L339)
- carrying handles on the inboard top ó [VmBoat._tube_kit:354](../scripts\game\vehicles\vm_boat.gd#L354)

### VmBoat._u

- Unlabelled construction / setup ó [VmBoat._u:116](../scripts\game\vehicles\vm_boat.gd#L116)

### VmCiv._bent

- Unlabelled construction / setup ó [VmCiv._bent:179](../scripts\game\vehicles\vm_civ.gd#L179)

### VmCiv._car_details

- Unlabelled construction / setup ó [VmCiv._car_details:1131](../scripts\game\vehicles\vm_civ.gd#L1131)

### VmCiv._face

- Unlabelled construction / setup ó [VmCiv._face:140](../scripts\game\vehicles\vm_civ.gd#L140)

### VmCiv._flare

- Unlabelled construction / setup ó [VmCiv._flare:102](../scripts\game\vehicles\vm_civ.gd#L102)

### VmCiv._glasshouse

- Unlabelled construction / setup ó [VmCiv._glasshouse:1086](../scripts\game\vehicles\vm_civ.gd#L1086)
- Fill the complement of the actual window apertures, including the wide C-pillars. This preserves the coupe and pickup silhouettes. ó [VmCiv._glasshouse:1113](../scripts\game\vehicles\vm_civ.gd#L1113)

### VmCiv._hatch_sport

- Unlabelled construction / setup ó [VmCiv._hatch_sport:1062](../scripts\game\vehicles\vm_civ.gd#L1062)
- spoiler over the hatch on two stays, its end plates ó [VmCiv._hatch_sport:1068](../scripts\game\vehicles\vm_civ.gd#L1068)
- twin tailpipes out of the diffuser ó [VmCiv._hatch_sport:1078](../scripts\game\vehicles\vm_civ.gd#L1078)

### VmCiv._inset

- Unlabelled construction / setup ó [VmCiv._inset:78](../scripts\game\vehicles\vm_civ.gd#L78)

### VmCiv._jerrycan

- Unlabelled construction / setup ó [VmCiv._jerrycan:214](../scripts\game\vehicles\vm_civ.gd#L214)

### VmCiv._lamp

- Unlabelled construction / setup ó [VmCiv._lamp:192](../scripts\game\vehicles\vm_civ.gd#L192)

### VmCiv._lmg

- Unlabelled construction / setup ó [VmCiv._lmg:235](../scripts\game\vehicles\vm_civ.gd#L235)

### VmCiv._m2

- Unlabelled construction / setup ó [VmCiv._m2:229](../scripts\game\vehicles\vm_civ.gd#L229)

### VmCiv._mb_gun

- Unlabelled construction / setup ó [VmCiv._mb_gun:598](../scripts\game\vehicles\vm_civ.gd#L598)
- ammunition stowed in the back ó [VmCiv._mb_gun:600](../scripts\game\vehicles\vm_civ.gd#L600)
- the post clamped to the bar; the recoilless rifle's cradle is the broader one, its cheeks reaching up to the gun's saddle ó [VmCiv._mb_gun:605](../scripts\game\vehicles\vm_civ.gd#L605)

### VmCiv._mb_top

- Unlabelled construction / setup ó [VmCiv._mb_top:579](../scripts\game\vehicles\vm_civ.gd#L579)
- the door frames the curtains zip into, the bows under the roof ó [VmCiv._mb_top:589](../scripts\game\vehicles\vm_civ.gd#L589)

### VmCiv._mirror

- Unlabelled construction / setup ó [VmCiv._mirror:209](../scripts\game\vehicles\vm_civ.gd#L209)

### VmCiv._off_at

- Unlabelled construction / setup ó [VmCiv._off_at:406](../scripts\game\vehicles\vm_civ.gd#L406)
- crates of rounds in the bed, the one by the tailgate strapped down ó [VmCiv._off_at:413](../scripts\game\vehicles\vm_civ.gd#L413)

### VmCiv._off_hmg

- Unlabelled construction / setup ó [VmCiv._off_hmg:388](../scripts\game\vehicles\vm_civ.gd#L388)
- ammo cans and a spare box by the gunner's feet ó [VmCiv._off_hmg:389](../scripts\game\vehicles\vm_civ.gd#L389)
- the pintle post braced on its bolted plate, the swivel and cradle on top ó [VmCiv._off_hmg:395](../scripts\game\vehicles\vm_civ.gd#L395)
- the shield: a flat plate with the barrel slot, angled wings, a vision slit ó [VmCiv._off_hmg:399](../scripts\game\vehicles\vm_civ.gd#L399)

### VmCiv._off_repair

- Unlabelled construction / setup ó [VmCiv._off_repair:428](../scripts\game\vehicles\vm_civ.gd#L428)
- a tool chest along each side, its lid hinged outboard and latched inboard ó [VmCiv._off_repair:431](../scripts\game\vehicles\vm_civ.gd#L431)
- a welding set's two bottles racked across the bed, capped ó [VmCiv._off_repair:437](../scripts\game\vehicles\vm_civ.gd#L437)
- the davit: a post in the corner, a boom swung out over the tailgate, its hook on the wire from the boom's end; the brace and winch drum on the post ó [VmCiv._off_repair:439](../scripts\game\vehicles\vm_civ.gd#L439)
- the amber beacon on its bar on the cab roof ó [VmCiv._off_repair:446](../scripts\game\vehicles\vm_civ.gd#L446)

### VmCiv._paint

- Unlabelled construction / setup ó [VmCiv._paint:68](../scripts\game\vehicles\vm_civ.gd#L68)
- a little dust and sun on top of it ó [VmCiv._paint:71](../scripts\game\vehicles\vm_civ.gd#L71)

### VmCiv._pane

- Unlabelled construction / setup ó [VmCiv._pane:134](../scripts\game\vehicles\vm_civ.gd#L134)

### VmCiv._plate

- Unlabelled construction / setup ó [VmCiv._plate:201](../scripts\game\vehicles\vm_civ.gd#L201)

### VmCiv._ring

- Unlabelled construction / setup ó [VmCiv._ring:145](../scripts\game\vehicles\vm_civ.gd#L145)

### VmCiv._rod

- Unlabelled construction / setup ó [VmCiv._rod:174](../scripts\game\vehicles\vm_civ.gd#L174)

### VmCiv._slab

- Unlabelled construction / setup ó [VmCiv._slab:165](../scripts\game\vehicles\vm_civ.gd#L165)

### VmCiv._spare

- Unlabelled construction / setup ó [VmCiv._spare:220](../scripts\game\vehicles\vm_civ.gd#L220)

### VmCiv._spg9

- Unlabelled construction / setup ó [VmCiv._spg9:240](../scripts\game\vehicles\vm_civ.gd#L240)
- the thin forward tube, the fat chamber, the venturi flaring at the back ó [VmCiv._spg9:241](../scripts\game\vehicles\vm_civ.gd#L241)
- clamping bands, the sight on the left (its objective window looking forward in line with the rubber eyecup at the back), trigger group underneath ó [VmCiv._spg9:248](../scripts\game\vehicles\vm_civ.gd#L248)
- the saddle the tube sits in ó [VmCiv._spg9:256](../scripts\game\vehicles\vm_civ.gd#L256)

### VmCiv._strut

- Unlabelled construction / setup ó [VmCiv._strut:159](../scripts\game\vehicles\vm_civ.gd#L159)

### VmCiv._team_side

- Unlabelled construction / setup ó [VmCiv._team_side:453](../scripts\game\vehicles\vm_civ.gd#L453)

### VmCiv._truck_bed

- Unlabelled construction / setup ó [VmCiv._truck_bed:702](../scripts\game\vehicles\vm_civ.gd#L702)
- a bench facing inboard along each side on its folding legs, hinged to the dropside, its back board high on the side above it ó [VmCiv._truck_bed:706](../scripts\game\vehicles\vm_civ.gd#L706)

### VmCiv._truck_box

- Unlabelled construction / setup ó [VmCiv._truck_box:717](../scripts\game\vehicles\vm_civ.gd#L717)
- the red clearance lamps high on the back corners ó [VmCiv._truck_box:724](../scripts\game\vehicles\vm_civ.gd#L724)
- the wind deflector over the cab ó [VmCiv._truck_box:726](../scripts\game\vehicles\vm_civ.gd#L726)

### VmCiv._truck_rear

- Unlabelled construction / setup ó [VmCiv._truck_rear:737](../scripts\game\vehicles\vm_civ.gd#L737)

### VmCiv._van_ambulance

- Unlabelled construction / setup ó [VmCiv._van_ambulance:863](../scripts\game\vehicles\vm_civ.gd#L863)
- The crosses are painted straight on the white body (the rear one on a white panel across the doors' windows), and stay on a wreck. ó [VmCiv._van_ambulance:866](../scripts\game\vehicles\vm_civ.gd#L866)
- a red beacon on each back corner of the roof ó [VmCiv._van_ambulance:871](../scripts\game\vehicles\vm_civ.gd#L871)
- the big cross on the roof ó [VmCiv._van_ambulance:876](../scripts\game\vehicles\vm_civ.gd#L876)
- light bar: red lenses either side of white ó [VmCiv._van_ambulance:878](../scripts\game\vehicles\vm_civ.gd#L878)

### VmCiv._van_services

- Unlabelled construction / setup ó [VmCiv._van_services:885](../scripts\game\vehicles\vm_civ.gd#L885)
- the roof rack: rails on four feet a side, five cross bars clamped on them ó [VmCiv._van_services:890](../scripts\game\vehicles\vm_civ.gd#L890)
- the ladder ó [VmCiv._van_services:892](../scripts\game\vehicles\vm_civ.gd#L892)
- amber beacon on its bar over the cab ó [VmCiv._van_services:897](../scripts\game\vehicles\vm_civ.gd#L897)
- red and white chevrons on the lower rear doors ó [VmCiv._van_services:899](../scripts\game\vehicles\vm_civ.gd#L899)

### VmCiv._xbody

- Unlabelled construction / setup ó [VmCiv._xbody:98](../scripts\game\vehicles\vm_civ.gd#L98)

### VmCiv._yloft

- Unlabelled construction / setup ó [VmCiv._yloft:108](../scripts\game\vehicles\vm_civ.gd#L108)

### VmCiv._zring

- Unlabelled construction / setup ó [VmCiv._zring:151](../scripts\game\vehicles\vm_civ.gd#L151)

### VmCore._airframe

- Unlabelled construction / setup ó [VmCore._airframe:1579](../scripts\game\vehicles\vm_core.gd#L1579)

### VmCore._ammo_can

- Unlabelled construction / setup ó [VmCore._ammo_can:350](../scripts\game\vehicles\vm_core.gd#L350)

### VmCore._antenna

- Unlabelled construction / setup ó [VmCore._antenna:307](../scripts\game\vehicles\vm_core.gd#L307)

### VmCore._bar

- Unlabelled construction / setup ó [VmCore._bar:106](../scripts\game\vehicles\vm_core.gd#L106)

### VmCore._bedroll

- Unlabelled construction / setup ó [VmCore._bedroll:674](../scripts\game\vehicles\vm_core.gd#L674)

### VmCore._belt

- Unlabelled construction / setup ó [VmCore._belt:274](../scripts\game\vehicles\vm_core.gd#L274)
- Include the bottom tangent. An inscribed polygon between samples leaves daylight under every pad, even on a perfectly flat road. ó [VmCore._belt:278](../scripts\game\vehicles\vm_core.gd#L278)

### VmCore._breakaway_skirt

- Unlabelled construction / setup ó [VmCore._breakaway_skirt:627](../scripts\game\vehicles\vm_core.gd#L627)
- The outer edge faces away from the center. The fracture faces into it. ó [VmCore._breakaway_skirt:655](../scripts\game\vehicles\vm_core.gd#L655)

### VmCore._bx

- Unlabelled construction / setup ó [VmCore._bx:74](../scripts\game\vehicles\vm_core.gd#L74)

### VmCore._cam

- Unlabelled construction / setup ó [VmCore._cam:64](../scripts\game\vehicles\vm_core.gd#L64)

### VmCore._dshk

- Unlabelled construction / setup ó [VmCore._dshk:732](../scripts\game\vehicles\vm_core.gd#L732)

### VmCore._eye

- Unlabelled construction / setup ó [VmCore._eye:356](../scripts\game\vehicles\vm_core.gd#L356)

### VmCore._fuel_tank

- Unlabelled construction / setup ó [VmCore._fuel_tank:1696](../scripts\game\vehicles\vm_core.gd#L1696)

### VmCore._hatch

- Unlabelled construction / setup ó [VmCore._hatch:338](../scripts\game\vehicles\vm_core.gd#L338)

### VmCore._hilux_dshk

- Unlabelled construction / setup ó [VmCore._hilux_dshk:1101](../scripts\game\vehicles\vm_core.gd#L1101)
- kit in the bed: ammo boxes, the spare tyre, a jerrycan, a crate ó [VmCore._hilux_dshk:1103](../scripts\game\vehicles\vm_core.gd#L1103)
- (the spare lies on the floor tipped up against the kit, its axle near upright) ó [VmCore._hilux_dshk:1107](../scripts\game\vehicles\vm_core.gd#L1107)
- strapped down to a ring on the bed floor ó [VmCore._hilux_dshk:1109](../scripts\game\vehicles\vm_core.gd#L1109)
- the pintle: the post on its plate welded to the bed floor, braced to its corners; the traversing head on it with the yoke, the gun, the welded shield wrapped round the gunner, a rust streak down its face ó [VmCore._hilux_dshk:1112](../scripts\game\vehicles\vm_core.gd#L1112)

### VmCore._hollow_tyre

- Unlabelled construction / setup ó [VmCore._hollow_tyre:195](../scripts\game\vehicles\vm_core.gd#L195)

### VmCore._idler

- Unlabelled construction / setup ó [VmCore._idler:255](../scripts\game\vehicles\vm_core.gd#L255)

### VmCore._jerry

- Unlabelled construction / setup ó [VmCore._jerry:344](../scripts\game\vehicles\vm_core.gd#L344)

### VmCore._lamp

- Unlabelled construction / setup ó [VmCore._lamp:296](../scripts\game\vehicles\vm_core.gd#L296)

### VmCore._m2

- Unlabelled construction / setup ó [VmCore._m2:366](../scripts\game\vehicles\vm_core.gd#L366)

### VmCore._mirror

- Unlabelled construction / setup ó [VmCore._mirror:1893](../scripts\game\vehicles\vm_core.gd#L1893)

### VmCore._mmg

- Unlabelled construction / setup ó [VmCore._mmg:373](../scripts\game\vehicles\vm_core.gd#L373)

### VmCore._oct

- Unlabelled construction / setup ó [VmCore._oct:150](../scripts\game\vehicles\vm_core.gd#L150)

### VmCore._on_face

- Unlabelled construction / setup ó [VmCore._on_face:123](../scripts\game\vehicles\vm_core.gd#L123)

### VmCore._path

- Unlabelled construction / setup ó [VmCore._path:101](../scripts\game\vehicles\vm_core.gd#L101)

### VmCore._periscope

- Unlabelled construction / setup ó [VmCore._periscope:332](../scripts\game\vehicles\vm_core.gd#L332)

### VmCore._rings

- Unlabelled construction / setup ó [VmCore._rings:134](../scripts\game\vehicles\vm_core.gd#L134)

### VmCore._road_wheel

- Unlabelled construction / setup ó [VmCore._road_wheel:221](../scripts\game\vehicles\vm_core.gd#L221)
- Outer fasteners catch the light along the rim of the dished pressing. ó [VmCore._road_wheel:237](../scripts\game\vehicles\vm_core.gd#L237)

### VmCore._round_ring

- Unlabelled construction / setup ó [VmCore._round_ring:717](../scripts\game\vehicles\vm_core.gd#L717)

### VmCore._rz

- Unlabelled construction / setup ó [VmCore._rz:142](../scripts\game\vehicles\vm_core.gd#L142)

### VmCore._shackle

- Unlabelled construction / setup ó [VmCore._shackle:326](../scripts\game\vehicles\vm_core.gd#L326)

### VmCore._skirt_bolt

- Unlabelled construction / setup ó [VmCore._skirt_bolt:666](../scripts\game\vehicles\vm_core.gd#L666)

### VmCore._smoke

- Unlabelled construction / setup ó [VmCore._smoke:314](../scripts\game\vehicles\vm_core.gd#L314)

### VmCore._sprocket

- Unlabelled construction / setup ó [VmCore._sprocket:247](../scripts\game\vehicles\vm_core.gd#L247)

### VmCore._taillight

- Unlabelled construction / setup ó [VmCore._taillight:301](../scripts\game\vehicles\vm_core.gd#L301)

### VmCore._tube

- Unlabelled construction / setup ó [VmCore._tube:96](../scripts\game\vehicles\vm_core.gd#L96)

### VmCore._wheel_disc

- Unlabelled construction / setup ó [VmCore._wheel_disc:160](../scripts\game\vehicles\vm_core.gd#L160)
- Radius, offset along the axle, and additional height on the crest of a rib. ó [VmCore._wheel_disc:164](../scripts\game\vehicles\vm_core.gd#L164)

### VmCore._zu23

- Unlabelled construction / setup ó [VmCore._zu23:1129](../scripts\game\vehicles\vm_core.gd#L1129)
- loose kit in the corners: ammunition boxes, a jerrycan ó [VmCore._zu23:1134](../scripts\game\vehicles\vm_core.gd#L1134)
- the side frames carrying the trunnions ó [VmCore._zu23:1142](../scripts\game\vehicles\vm_core.gd#L1142)
- the cradle, raised a little, with both guns ó [VmCore._zu23:1145](../scripts\game\vehicles\vm_core.gd#L1145)
- the ammunition box outboard of each gun, the spent-case chute under it ó [VmCore._zu23:1153](../scripts\game\vehicles\vm_core.gd#L1153)
- the gunner's seat and his sight on the left, the hand wheels, the second seat on the right ó [VmCore._zu23:1159](../scripts\game\vehicles\vm_core.gd#L1159)

### VmCore._zy

- Unlabelled construction / setup ó [VmCore._zy:113](../scripts\game\vehicles\vm_core.gd#L113)

### VmCsat._aim_y

- Unlabelled construction / setup ó [VmCsat._aim_y:90](../scripts\game\vehicles\vm_csat.gd#L90)

### VmCsat._antenna

- Unlabelled construction / setup ó [VmCsat._antenna:183](../scripts\game\vehicles\vm_csat.gd#L183)

### VmCsat._arch

- Unlabelled construction / setup ó [VmCsat._arch:125](../scripts\game\vehicles\vm_csat.gd#L125)
- the arch's top edge in side view (z, y), front foot to rear foot, and the band's underside 5 cm in, then the dark well face under that ó [VmCsat._arch:130](../scripts\game\vehicles\vm_csat.gd#L130)
- counter-clockwise in (z, y): along the underside, back along the top ó [VmCsat._arch:138](../scripts\game\vehicles\vm_csat.gd#L138)

### VmCsat._arch_offset

- Unlabelled construction / setup ó [VmCsat._arch_offset:148](../scripts\game\vehicles\vm_csat.gd#L148)

### VmCsat._cross

- Unlabelled construction / setup ó [VmCsat._cross:1321](../scripts\game\vehicles\vm_csat.gd#L1321)

### VmCsat._cupola_mg

- Unlabelled construction / setup ó [VmCsat._cupola_mg:868](../scripts\game\vehicles\vm_csat.gd#L868)

### VmCsat._era

- Unlabelled construction / setup ó [VmCsat._era:546](../scripts\game\vehicles\vm_csat.gd#L546)

### VmCsat._face_rot

- Unlabelled construction / setup ó [VmCsat._face_rot:494](../scripts\game\vehicles\vm_csat.gd#L494)

### VmCsat._gun125

- Unlabelled construction / setup ó [VmCsat._gun125:857](../scripts\game\vehicles\vm_csat.gd#L857)

### VmCsat._hatch

- Unlabelled construction / setup ó [VmCsat._hatch:200](../scripts\game\vehicles\vm_csat.gd#L200)

### VmCsat._headlight

- Unlabelled construction / setup ó [VmCsat._headlight:171](../scripts\game\vehicles\vm_csat.gd#L171)

### VmCsat._jerrycan

- Unlabelled construction / setup ó [VmCsat._jerrycan:194](../scripts\game\vehicles\vm_csat.gd#L194)

### VmCsat._locker

- Unlabelled construction / setup ó [VmCsat._locker:1315](../scripts\game\vehicles\vm_csat.gd#L1315)

### VmCsat._mx

- Unlabelled construction / setup ó [VmCsat._mx:81](../scripts\game\vehicles\vm_csat.gd#L81)

### VmCsat._onface

- Unlabelled construction / setup ó [VmCsat._onface:479](../scripts\game\vehicles\vm_csat.gd#L479)

### VmCsat._pane

- Unlabelled construction / setup ó [VmCsat._pane:112](../scripts\game\vehicles\vm_csat.gd#L112)

### VmCsat._periscope

- Unlabelled construction / setup ó [VmCsat._periscope:206](../scripts\game\vehicles\vm_csat.gd#L206)

### VmCsat._plate

- Unlabelled construction / setup ó [VmCsat._plate:106](../scripts\game\vehicles\vm_csat.gd#L106)

### VmCsat._rcws

- Unlabelled construction / setup ó [VmCsat._rcws:226](../scripts\game\vehicles\vm_csat.gd#L226)
- the trunnion arms either side of the cradle ó [VmCsat._rcws:229](../scripts\game\vehicles\vm_csat.gd#L229)
- The guns feed from the station's own box beside them, so none carries a can. ó [VmCsat._rcws:234](../scripts\game\vehicles\vm_csat.gd#L234)
- the sight head beside the gun under its lid, the ammunition box on the other side ó [VmCsat._rcws:248](../scripts\game\vehicles\vm_csat.gd#L248)

### VmCsat._running_gear

- Unlabelled construction / setup ó [VmCsat._running_gear:517](../scripts\game\vehicles\vm_csat.gd#L517)

### VmCsat._rwheel

- Unlabelled construction / setup ó [VmCsat._rwheel:502](../scripts\game\vehicles\vm_csat.gd#L502)

### VmCsat._sec

- Unlabelled construction / setup ó [VmCsat._sec:75](../scripts\game\vehicles\vm_csat.gd#L75)

### VmCsat._slats

- Unlabelled construction / setup ó [VmCsat._slats:1021](../scripts\game\vehicles\vm_csat.gd#L1021)

### VmCsat._smoke

- Unlabelled construction / setup ó [VmCsat._smoke:213](../scripts\game\vehicles\vm_csat.gd#L213)

### VmCsat._sprocket

- Unlabelled construction / setup ó [VmCsat._sprocket:507](../scripts\game\vehicles\vm_csat.gd#L507)

### VmCsat._stalker

- Unlabelled construction / setup ó [VmCsat._stalker:659](../scripts\game\vehicles\vm_csat.gd#L659)
- side skirts in bolted sections, the front one angled up toward the sprocket ó [VmCsat._stalker:669](../scripts\game\vehicles\vm_csat.gd#L669)
- the glacis: driver's hatch and periscopes front left, engine louvres front right, headlights in guards at the corners, tow hooks on the nose ó [VmCsat._stalker:674](../scripts\game\vehicles\vm_csat.gd#L674)
- upper sides: stowage boxes and vision blocks, the exhaust on the right ó [VmCsat._stalker:686](../scripts\game\vehicles\vm_csat.gd#L686)
- the rear: the troop door, its hinges and vision block, lights, stowage ó [VmCsat._stalker:697](../scripts\game\vehicles\vm_csat.gd#L697)
- a stowage bin either side of the door, its catches on the outside ó [VmCsat._stalker:707](../scripts\game\vehicles\vm_csat.gd#L707)
- roof: the troop compartment's hatches behind the turret ó [VmCsat._stalker:710](../scripts\game\vehicles\vm_csat.gd#L710)

### VmCsat._t100

- Unlabelled construction / setup ó [VmCsat._t100:794](../scripts\game\vehicles\vm_csat.gd#L794)
- the glacis: a chevron of reactive armour plates, the driver's hatch and periscope at its top, headlights at its corners, tow hooks on the nose ó [VmCsat._t100:804](../scripts\game\vehicles\vm_csat.gd#L804)
- the track guards on their gussets, the front mudguards raked down over the idlers ó [VmCsat._t100:815](../scripts\game\vehicles\vm_csat.gd#L815)
- side skirts: reactive armour on the front three sections, rubber behind ó [VmCsat._t100:821](../scripts\game\vehicles\vm_csat.gd#L821)
- stowage along the fenders behind the turret: bins left, fuel tanks right ó [VmCsat._t100:831](../scripts\game\vehicles\vm_csat.gd#L831)
- engine deck: grilles and the access panels ó [VmCsat._t100:838](../scripts\game\vehicles\vm_csat.gd#L838)
- the rear: the turbine's exhaust grille leaning back off the plate, the unditching beam, lights, hooks ó [VmCsat._t100:841](../scripts\game\vehicles\vm_csat.gd#L841)

### VmCsat._t14

- Unlabelled construction / setup ó [VmCsat._t14:1033](../scripts\game\vehicles\vm_csat.gd#L1033)
- the glacis: a grid of reactive armour blocks, the lights, tow hooks; the track guards on their gussets, the front mudguards raked over the idlers ó [VmCsat._t14:1043](../scripts\game\vehicles\vm_csat.gd#L1043)
- the crew capsule: three hatches abreast, periscopes ahead of each ó [VmCsat._t14:1053](../scripts\game\vehicles\vm_csat.gd#L1053)
- tall skirts: reactive armour forward, plain plates aft; slat cages round the engine bay ó [VmCsat._t14:1059](../scripts\game\vehicles\vm_csat.gd#L1059)
- engine deck: grilles, the exhaust on the left, stowage boxes on the deck ó [VmCsat._t14:1071](../scripts\game\vehicles\vm_csat.gd#L1071)

### VmCsat._taillight

- Unlabelled construction / setup ó [VmCsat._taillight:177](../scripts\game\vehicles\vm_csat.gd#L177)

### VmCsat._tempest_box

- Unlabelled construction / setup ó [VmCsat._tempest_box:1308](../scripts\game\vehicles\vm_csat.gd#L1308)

### VmCsat._tempest_flatbed

- Unlabelled construction / setup ó [VmCsat._tempest_flatbed:1300](../scripts\game\vehicles\vm_csat.gd#L1300)

### VmCsat._tow

- Unlabelled construction / setup ó [VmCsat._tow:188](../scripts\game\vehicles\vm_csat.gd#L188)

### VmCsat._tube

- Unlabelled construction / setup ó [VmCsat._tube:100](../scripts\game\vehicles\vm_csat.gd#L100)

### VmCsat._typhoon

- Unlabelled construction / setup ó [VmCsat._typhoon:1150](../scripts\game\vehicles\vm_csat.gd#L1150)
- the bumper block under the cab's nose ó [VmCsat._typhoon:1162](../scripts\game\vehicles\vm_csat.gd#L1162)
- the windscreen: two big flat panes, a pillar between them ó [VmCsat._typhoon:1164](../scripts\game\vehicles\vm_csat.gd#L1164)
- the grille on the cab front, headlights and tow hooks in the bumper ó [VmCsat._typhoon:1169](../scripts\game\vehicles\vm_csat.gd#L1169)
- the step ladder under the door, behind the front wheel ó [VmCsat._typhoon:1174](../scripts\game\vehicles\vm_csat.gd#L1174)
- mirrors on long arms ó [VmCsat._typhoon:1176](../scripts\game\vehicles\vm_csat.gd#L1176)
- the front wheel under its faceted arch, the rear tandem ó [VmCsat._typhoon:1178](../scripts\game\vehicles\vm_csat.gd#L1178)
- the rear tandem's mudguard ó [VmCsat._typhoon:1184](../scripts\game\vehicles\vm_csat.gd#L1184)
- fuel tank and battery box on the frame, the exhaust stack behind the cab ó [VmCsat._typhoon:1187](../scripts\game\vehicles\vm_csat.gd#L1187)
- the rear underrun bar ó [VmCsat._typhoon:1191](../scripts\game\vehicles\vm_csat.gd#L1191)
- roof: hatch, antennas, a twin work light facing forward ó [VmCsat._typhoon:1193](../scripts\game\vehicles\vm_csat.gd#L1193)

### VmFighter._aim120

- Unlabelled construction / setup ó [VmFighter._aim120:910](../scripts\game\vehicles\vm_fighter.gd#L910)

### VmFighter._aim9x

- Unlabelled construction / setup ó [VmFighter._aim9x:904](../scripts\game\vehicles\vm_fighter.gd#L904)

### VmFighter._alq184

- Unlabelled construction / setup ó [VmFighter._alq184:926](../scripts\game\vehicles\vm_fighter.gd#L926)

### VmFighter._awheel

- Unlabelled construction / setup ó [VmFighter._awheel:655](../scripts\game\vehicles\vm_fighter.gd#L655)

### VmFighter._burner

- Unlabelled construction / setup ó [VmFighter._burner:426](../scripts\game\vehicles\vm_fighter.gd#L426)

### VmFighter._bw_half

- Unlabelled construction / setup ó [VmFighter._bw_half:939](../scripts\game\vehicles\vm_fighter.gd#L939)

### VmFighter._ccr

- Unlabelled construction / setup ó [VmFighter._ccr:275](../scripts\game\vehicles\vm_fighter.gd#L275)

### VmFighter._circle2

- Unlabelled construction / setup ó [VmFighter._circle2:448](../scripts\game\vehicles\vm_fighter.gd#L448)

### VmFighter._cloop

- Unlabelled construction / setup ó [VmFighter._cloop:357](../scripts\game\vehicles\vm_fighter.gd#L357)

### VmFighter._decal

- Unlabelled construction / setup ó [VmFighter._decal:472](../scripts\game\vehicles\vm_fighter.gd#L472)

### VmFighter._dense

- Unlabelled construction / setup ó [VmFighter._dense:259](../scripts\game\vehicles\vm_fighter.gd#L259)

### VmFighter._duct

- Unlabelled construction / setup ó [VmFighter._duct:387](../scripts\game\vehicles\vm_fighter.gd#L387)

### VmFighter._f16_half

- Unlabelled construction / setup ó [VmFighter._f16_half:672](../scripts\game\vehicles\vm_fighter.gd#L672)

### VmFighter._ft

- Unlabelled construction / setup ó [VmFighter._ft:436](../scripts\game\vehicles\vm_fighter.gd#L436)

### VmFighter._gbu31

- Unlabelled construction / setup ó [VmFighter._gbu31:898](../scripts\game\vehicles\vm_fighter.gd#L898)

### VmFighter._gear_door

- Unlabelled construction / setup ó [VmFighter._gear_door:188](../scripts\game\vehicles\vm_fighter.gd#L188)

### VmFighter._gear_node

- Unlabelled construction / setup ó [VmFighter._gear_node:646](../scripts\game\vehicles\vm_fighter.gd#L646)

### VmFighter._glaze

- Unlabelled construction / setup ó [VmFighter._glaze:205](../scripts\game\vehicles\vm_fighter.gd#L205)

### VmFighter._hband

- Unlabelled construction / setup ó [VmFighter._hband:329](../scripts\game\vehicles\vm_fighter.gd#L329)

### VmFighter._hull

- Unlabelled construction / setup ó [VmFighter._hull:318](../scripts\game\vehicles\vm_fighter.gd#L318)

### VmFighter._hwrap

- Unlabelled construction / setup ó [VmFighter._hwrap:492](../scripts\game\vehicles\vm_fighter.gd#L492)

### VmFighter._insignia

- Unlabelled construction / setup ó [VmFighter._insignia:557](../scripts\game\vehicles\vm_fighter.gd#L557)

### VmFighter._leg

- Unlabelled construction / setup ó [VmFighter._leg:665](../scripts\game\vehicles\vm_fighter.gd#L665)

### VmFighter._lines

- Unlabelled construction / setup ó [VmFighter._lines:603](../scripts\game\vehicles\vm_fighter.gd#L603)

### VmFighter._loop

- Unlabelled construction / setup ó [VmFighter._loop:309](../scripts\game\vehicles\vm_fighter.gd#L309)

### VmFighter._mesh

- Unlabelled construction / setup ó [VmFighter._mesh:153](../scripts\game\vehicles\vm_fighter.gd#L153)

### VmFighter._mixloop

- Unlabelled construction / setup ó [VmFighter._mixloop:366](../scripts\game\vehicles\vm_fighter.gd#L366)

### VmFighter._msecs

- Unlabelled construction / setup ó [VmFighter._msecs:546](../scripts\game\vehicles\vm_fighter.gd#L546)

### VmFighter._outline

- Unlabelled construction / setup ó [VmFighter._outline:636](../scripts\game\vehicles\vm_fighter.gd#L636)

### VmFighter._petals

- Unlabelled construction / setup ó [VmFighter._petals:395](../scripts\game\vehicles\vm_fighter.gd#L395)

### VmFighter._pipe

- Unlabelled construction / setup ó [VmFighter._pipe:406](../scripts\game\vehicles\vm_fighter.gd#L406)

### VmFighter._poly_mesh

- Unlabelled construction / setup ó [VmFighter._poly_mesh:167](../scripts\game\vehicles\vm_fighter.gd#L167)

### VmFighter._project

- Unlabelled construction / setup ó [VmFighter._project:483](../scripts\game\vehicles\vm_fighter.gd#L483)

### VmFighter._put

- Unlabelled construction / setup ó [VmFighter._put:199](../scripts\game\vehicles\vm_fighter.gd#L199)

### VmFighter._qloop

- Unlabelled construction / setup ó [VmFighter._qloop:345](../scripts\game\vehicles\vm_fighter.gd#L345)

### VmFighter._rect2

- Unlabelled construction / setup ó [VmFighter._rect2:456](../scripts\game\vehicles\vm_fighter.gd#L456)

### VmFighter._ring

- Unlabelled construction / setup ó [VmFighter._ring:291](../scripts\game\vehicles\vm_fighter.gd#L291)

### VmFighter._rows

- Unlabelled construction / setup ó [VmFighter._rows:224](../scripts\game\vehicles\vm_fighter.gd#L224)

### VmFighter._skin

- Unlabelled construction / setup ó [VmFighter._skin:55](../scripts\game\vehicles\vm_fighter.gd#L55)
- a degenerate quad (a pointed nose): face along the section's radius ó [VmFighter._skin:86](../scripts\game\vehicles\vm_fighter.gd#L86)

### VmFighter._slab

- Unlabelled construction / setup ó [VmFighter._slab:179](../scripts\game\vehicles\vm_fighter.gd#L179)

### VmFighter._sniper

- Unlabelled construction / setup ó [VmFighter._sniper:917](../scripts\game\vehicles\vm_fighter.gd#L917)

### VmFighter._star2

- Unlabelled construction / setup ó [VmFighter._star2:461](../scripts\game\vehicles\vm_fighter.gd#L461)

### VmFighter._surf

- Unlabelled construction / setup ó [VmFighter._surf:442](../scripts\game\vehicles\vm_fighter.gd#L442)

### VmFighter._tan

- Unlabelled construction / setup ó [VmFighter._tan:251](../scripts\game\vehicles\vm_fighter.gd#L251)

### VmFighter._text

- Unlabelled construction / setup ó [VmFighter._text:574](../scripts\game\vehicles\vm_fighter.gd#L574)

### VmFighter._tri

- Unlabelled construction / setup ó [VmFighter._tri:141](../scripts\game\vehicles\vm_fighter.gd#L141)

### VmFighter._vn

- Unlabelled construction / setup ó [VmFighter._vn:127](../scripts\game\vehicles\vm_fighter.gd#L127)

### VmFighter._wrap

- Unlabelled construction / setup ó [VmFighter._wrap:521](../scripts\game\vehicles\vm_fighter.gd#L521)

### VmFighter._zigzag

- Unlabelled construction / setup ó [VmFighter._zigzag:623](../scripts\game\vehicles\vm_fighter.gd#L623)

### VmGunship._ac130_cockpit

- Unlabelled construction / setup ó [VmGunship._ac130_cockpit:430](../scripts\game\vehicles\vm_gunship.gd#L430)
- the windscreen: five panes across the steep front of the flight deck, framed; its top and bottom rails ó [VmGunship._ac130_cockpit:431](../scripts\game\vehicles\vm_gunship.gd#L431)
- two side windows each side, the eyebrow windows over them ó [VmGunship._ac130_cockpit:441](../scripts\game\vehicles\vm_gunship.gd#L441)
- the chin window low in the nose beside the nose gear ó [VmGunship._ac130_cockpit:448](../scripts\game\vehicles\vm_gunship.gd#L448)
- the pitot tubes ó [VmGunship._ac130_cockpit:451](../scripts\game\vehicles\vm_gunship.gd#L451)
- the air-refuelling receptacle (UARRSI) on the roof, its slipway open and the guide lines leading forward to it ó [VmGunship._ac130_cockpit:456](../scripts\game\vehicles\vm_gunship.gd#L456)

### VmGunship._ac130_doors

- Unlabelled construction / setup ó [VmGunship._ac130_doors:468](../scripts\game\vehicles\vm_gunship.gd#L468)
- the ramp and cargo door: seams along the lower sides of the upsweep and across it at the hinge, the ramp's end and the door's top ó [VmGunship._ac130_doors:477](../scripts\game\vehicles\vm_gunship.gd#L477)

### VmGunship._ac130_gear

- Unlabelled construction / setup ó [VmGunship._ac130_gear:585](../scripts\game\vehicles\vm_gunship.gd#L585)
- the nose gear: the strut, its torque links, the twin wheels, the doors ó [VmGunship._ac130_gear:588](../scripts\game\vehicles\vm_gunship.gd#L588)
- the main gear: the open wells, a strut and wheel at each station ó [VmGunship._ac130_gear:595](../scripts\game\vehicles\vm_gunship.gd#L595)

### VmGunship._ac130_guns

- Unlabelled construction / setup ó [VmGunship._ac130_guns:538](../scripts\game\vehicles\vm_gunship.gd#L538)
- the 25 mm GAU-12 Equalizer ó [VmGunship._ac130_guns:540](../scripts\game\vehicles\vm_gunship.gd#L540)
- the five barrels out of the mount's ball, clamped twice along their length ó [VmGunship._ac130_guns:544](../scripts\game\vehicles\vm_gunship.gd#L544)
- the 40 mm L/60 Bofors ó [VmGunship._ac130_guns:548](../scripts\game\vehicles\vm_gunship.gd#L548)
- (the mount's shield in the port, the cooling jacket, the barrel, the conical flash hider) ó [VmGunship._ac130_guns:551](../scripts\game\vehicles\vm_gunship.gd#L551)
- the 105 mm M102 howitzer ó [VmGunship._ac130_guns:559](../scripts\game\vehicles\vm_gunship.gd#L559)
- (the cradle in the port, the recoil sleeve, the barrel, the double-baffle muzzle brake with its side ports) ó [VmGunship._ac130_guns:562](../scripts\game\vehicles\vm_gunship.gd#L562)
- the AN/AAQ-117 infrared turret under the nose, the ALLTV turret in the front of the left sponson: balls on their necks, the windows turned out to port and down at the target the guns train on ó [VmGunship._ac130_guns:572](../scripts\game\vehicles\vm_gunship.gd#L572)

### VmGunship._ang

- Unlabelled construction / setup ó [VmGunship._ang:76](../scripts\game\vehicles\vm_gunship.gd#L76)

### VmGunship._bf_cockpit

- Unlabelled construction / setup ó [VmGunship._bf_cockpit:711](../scripts\game\vehicles\vm_gunship.gd#L711)

### VmGunship._bf_doors

- Unlabelled construction / setup ó [VmGunship._bf_doors:731](../scripts\game\vehicles\vm_gunship.gd#L731)

### VmGunship._bf_gear

- Unlabelled construction / setup ó [VmGunship._bf_gear:835](../scripts\game\vehicles\vm_gunship.gd#L835)

### VmGunship._bf_guns

- Unlabelled construction / setup ó [VmGunship._bf_guns:792](../scripts\game\vehicles\vm_gunship.gd#L792)
- the 40 mm ó [VmGunship._bf_guns:795](../scripts\game\vehicles\vm_gunship.gd#L795)
- the 105 mm and the 20 mm in the aft mount ó [VmGunship._bf_guns:806](../scripts\game\vehicles\vm_gunship.gd#L806)
- the Gatling's six barrels out of its drive housing, clamped twice ó [VmGunship._bf_guns:823](../scripts\game\vehicles\vm_gunship.gd#L823)
- the gunners' second sensor turret, its window looking out to port ó [VmGunship._bf_guns:827](../scripts\game\vehicles\vm_gunship.gd#L827)

### VmGunship._bf_nacelle

- Unlabelled construction / setup ó [VmGunship._bf_nacelle:747](../scripts\game\vehicles\vm_gunship.gd#L747)
- the engine's intake scoop on top, dark inside ó [VmGunship._bf_nacelle:761](../scripts\game\vehicles\vm_gunship.gd#L761)
- cooling grilles either side, the exhaust ó [VmGunship._bf_nacelle:765](../scripts\game\vehicles\vm_gunship.gd#L765)
- the navigation light, green on the right, red on the left ó [VmGunship._bf_nacelle:770](../scripts\game\vehicles\vm_gunship.gd#L770)

### VmGunship._bf_tail

- Unlabelled construction / setup ó [VmGunship._bf_tail:777](../scripts\game\vehicles\vm_gunship.gd#L777)
- the tail light looks aft off the tip of the boom ó [VmGunship._bf_tail:783](../scripts\game\vehicles\vm_gunship.gd#L783)

### VmGunship._decal

- Unlabelled construction / setup ó [VmGunship._decal:191](../scripts\game\vehicles\vm_gunship.gd#L191)

### VmGunship._dmesh

- Unlabelled construction / setup ó [VmGunship._dmesh:257](../scripts\game\vehicles\vm_gunship.gd#L257)
- (Godot's front faces wind clockwise, seen from their normal's side) ó [VmGunship._dmesh:261](../scripts\game\vehicles\vm_gunship.gd#L261)

### VmGunship._door

- Unlabelled construction / setup ó [VmGunship._door:103](../scripts\game\vehicles\vm_gunship.gd#L103)

### VmGunship._fin_at

- Unlabelled construction / setup ó [VmGunship._fin_at:277](../scripts\game\vehicles\vm_gunship.gd#L277)

### VmGunship._gear_node

- Unlabelled construction / setup ó [VmGunship._gear_node:65](../scripts\game\vehicles\vm_gunship.gd#L65)

### VmGunship._half_w

- Unlabelled construction / setup ó [VmGunship._half_w:87](../scripts\game\vehicles\vm_gunship.gd#L87)

### VmGunship._insignia_tris

- Unlabelled construction / setup ó [VmGunship._insignia_tris:133](../scripts\game\vehicles\vm_gunship.gd#L133)
- the star, its points just inside the circle ó [VmGunship._insignia_tris:134](../scripts\game\vehicles\vm_gunship.gd#L134)
- the circle, broken where the bars join it ó [VmGunship._insignia_tris:141](../scripts\game\vehicles\vm_gunship.gd#L141)

### VmGunship._patch

- Unlabelled construction / setup ó [VmGunship._patch:96](../scripts\game\vehicles\vm_gunship.gd#L96)

### VmGunship._propeller

- Unlabelled construction / setup ó [VmGunship._propeller:124](../scripts\game\vehicles\vm_gunship.gd#L124)

### VmGunship._ribbon

- Unlabelled construction / setup ó [VmGunship._ribbon:164](../scripts\game\vehicles\vm_gunship.gd#L164)

### VmGunship._seam

- Unlabelled construction / setup ó [VmGunship._seam:249](../scripts\game\vehicles\vm_gunship.gd#L249)

### VmGunship._shift

- Unlabelled construction / setup ó [VmGunship._shift:527](../scripts\game\vehicles\vm_gunship.gd#L527)

### VmGunship._t56

- Unlabelled construction / setup ó [VmGunship._t56:490](../scripts\game\vehicles\vm_gunship.gd#L490)
- a tall oval behind the spinner (the intake under it), the top running back into the wing's leading edge, the deep belly, the tail fairing ó [VmGunship._t56:492](../scripts\game\vehicles\vm_gunship.gd#L492)
- the cowl's panel joints ó [VmGunship._t56:508](../scripts\game\vehicles\vm_gunship.gd#L508)
- the engine and oil-cooler intake under the spinner: a lip standing proud of the cowl's face, dark inside ó [VmGunship._t56:512](../scripts\game\vehicles\vm_gunship.gd#L512)
- the exhaust: a short pipe out of the outboard side of the nacelle under the trailing edge, aft and toed out a little, soot streaked aft of it ó [VmGunship._t56:517](../scripts\game\vehicles\vm_gunship.gd#L517)

### VmGunship._text_tris

- Unlabelled construction / setup ó [VmGunship._text_tris:292](../scripts\game\vehicles\vm_gunship.gd#L292)

### VmGunship._tyre

- Unlabelled construction / setup ó [VmGunship._tyre:114](../scripts\game\vehicles\vm_gunship.gd#L114)

### VmGunship._under

- Unlabelled construction / setup ó [VmGunship._under:854](../scripts\game\vehicles\vm_gunship.gd#L854)

### VmGunship._wing_lines

- Unlabelled construction / setup ó [VmGunship._wing_lines:227](../scripts\game\vehicles\vm_gunship.gd#L227)

### VmHeli._air

- Unlabelled construction / setup ó [VmHeli._air:259](../scripts\game\vehicles\vm_heli.gd#L259)

### VmHeli._atgm_tubes

- the spine under the pylon (the tubes' frames hold them, so no sway braces), the plate the tubes hang from ó [VmHeli._atgm_tubes:1030](../scripts\game\vehicles\vm_heli.gd#L1030)

### VmHeli._canopy

- Unlabelled construction / setup ó [VmHeli._canopy:1016](../scripts\game\vehicles\vm_heli.gd#L1016)

### VmHeli._door_rail

- Unlabelled construction / setup ó [VmHeli._door_rail:228](../scripts\game\vehicles\vm_heli.gd#L228)

### VmHeli._ducted_fin

- Unlabelled construction / setup ó [VmHeli._ducted_fin:283](../scripts\game\vehicles\vm_heli.gd#L283)
- the outline's corners inside this wedge, in angular order ó [VmHeli._ducted_fin:292](../scripts\game\vehicles\vm_heli.gd#L292)

### VmHeli._fan

- Unlabelled construction / setup ó [VmHeli._fan:324](../scripts\game\vehicles\vm_heli.gd#L324)
- unevenly spaced, as on the real fans (it spreads the noise) ó [VmHeli._fan:327](../scripts\game\vehicles\vm_heli.gd#L327)

### VmHeli._gear

- Unlabelled construction / setup ó [VmHeli._gear:353](../scripts\game\vehicles\vm_heli.gd#L353)

### VmHeli._hellfires

- the spine under the pylon (the launcher's own rails hold the rounds, so no sway braces), the cross beam the rails hang from ó [VmHeli._hellfires:391](../scripts\game\vehicles\vm_heli.gd#L391)

### VmHeli._hull

- Unlabelled construction / setup ó [VmHeli._hull:181](../scripts\game\vehicles\vm_heli.gd#L181)
- Panel joins follow the authored skin; glazing sits above them, so seams cannot cut across a cockpit pane or change the hull outline. ó [VmHeli._hull:186](../scripts\game\vehicles\vm_heli.gd#L186)

### VmHeli._minigun

- Unlabelled construction / setup ó [VmHeli._minigun:369](../scripts\game\vehicles\vm_heli.gd#L369)
- the six barrels from the rotor at the housing's face, clamped past mid-length and just behind the muzzles ó [VmHeli._minigun:371](../scripts\game\vehicles\vm_heli.gd#L371)

### VmHeli._missile

- Unlabelled construction / setup ó [VmHeli._missile:385](../scripts\game\vehicles\vm_heli.gd#L385)

### VmHeli._mx

- Unlabelled construction / setup ó [VmHeli._mx:1007](../scripts\game\vehicles\vm_heli.gd#L1007)

### VmHeli._patch

- Unlabelled construction / setup ó [VmHeli._patch:206](../scripts\game\vehicles\vm_heli.gd#L206)

### VmHeli._path

- Unlabelled construction / setup ó [VmHeli._path:247](../scripts\game\vehicles\vm_heli.gd#L247)

### VmHeli._prop

- Unlabelled construction / setup ó [VmHeli._prop:1409](../scripts\game\vehicles\vm_heli.gd#L1409)

### VmHeli._ray_hit

- Unlabelled construction / setup ó [VmHeli._ray_hit:307](../scripts\game\vehicles\vm_heli.gd#L307)

### VmHeli._rbox

- Unlabelled construction / setup ó [VmHeli._rbox:253](../scripts\game\vehicles\vm_heli.gd#L253)

### VmHeli._rocket_pod

- Unlabelled construction / setup ó [VmHeli._rocket_pod:379](../scripts\game\vehicles\vm_heli.gd#L379)

### VmHeli._rotor

- Unlabelled construction / setup ó [VmHeli._rotor:272](../scripts\game\vehicles\vm_heli.gd#L272)

### VmHeli._rz

- Unlabelled construction / setup ó [VmHeli._rz:234](../scripts\game\vehicles\vm_heli.gd#L234)

### VmHeli._skids

- Unlabelled construction / setup ó [VmHeli._skids:339](../scripts\game\vehicles\vm_heli.gd#L339)

### VmHeli._skin

- Unlabelled construction / setup ó [VmHeli._skin:217](../scripts\game\vehicles\vm_heli.gd#L217)

### VmHeli._tail_rotor

- Unlabelled construction / setup ó [VmHeli._tail_rotor:276](../scripts\game\vehicles\vm_heli.gd#L276)

### VmHeli._tube

- Unlabelled construction / setup ó [VmHeli._tube:242](../scripts\game\vehicles\vm_heli.gd#L242)

### VmIndep._antenna

- Unlabelled construction / setup ó [VmIndep._antenna:126](../scripts\game\vehicles\vm_indep.gd#L126)

### VmIndep._glacis_grille

- Unlabelled construction / setup ó [VmIndep._glacis_grille:83](../scripts\game\vehicles\vm_indep.gd#L83)
- Turned half a turn past the plate's own tilt, so the grille's +Z faces out. ó [VmIndep._glacis_grille:85](../scripts\game\vehicles\vm_indep.gd#L85)

### VmIndep._idler

- Unlabelled construction / setup ó [VmIndep._idler:143](../scripts\game\vehicles\vm_indep.gd#L143)

### VmIndep._jerrycan

- Unlabelled construction / setup ó [VmIndep._jerrycan:131](../scripts\game\vehicles\vm_indep.gd#L131)

### VmIndep._light

- Unlabelled construction / setup ó [VmIndep._light:98](../scripts\game\vehicles\vm_indep.gd#L98)

### VmIndep._nyx_m2

- Unlabelled construction / setup ó [VmIndep._nyx_m2:664](../scripts\game\vehicles\vm_indep.gd#L664)

### VmIndep._oct

- Unlabelled construction / setup ó [VmIndep._oct:57](../scripts\game\vehicles\vm_indep.gd#L57)

### VmIndep._paint

- Unlabelled construction / setup ó [VmIndep._paint:50](../scripts\game\vehicles\vm_indep.gd#L50)

### VmIndep._plate

- Unlabelled construction / setup ó [VmIndep._plate:69](../scripts\game\vehicles\vm_indep.gd#L69)

### VmIndep._rcws

- Unlabelled construction / setup ó [VmIndep._rcws:293](../scripts\game\vehicles\vm_indep.gd#L293)
- the sight box on the right (the day camera's window over the thermal imager's round lens), the ammo box on the left ó [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)
- HK GMG: a squat receiver, a short thick barrel, the big belt box ó [VmIndep._rcws:305](../scripts\game\vehicles\vm_indep.gd#L305)
- M2: the long receiver, the barrel with its carrying handle, flash hider; its ammunition box is the station's, hung outboard of the yoke ó [VmIndep._rcws:309](../scripts\game\vehicles\vm_indep.gd#L309)

### VmIndep._ring

- Unlabelled construction / setup ó [VmIndep._ring:61](../scripts\game\vehicles\vm_indep.gd#L61)

### VmIndep._road_wheel

- Unlabelled construction / setup ó [VmIndep._road_wheel:138](../scripts\game\vehicles\vm_indep.gd#L138)

### VmIndep._round_light

- Unlabelled construction / setup ó [VmIndep._round_light:110](../scripts\game\vehicles\vm_indep.gd#L110)

### VmIndep._running_gear

- Unlabelled construction / setup ó [VmIndep._running_gear:328](../scripts\game\vehicles\vm_indep.gd#L328)

### VmIndep._sensor_head

- Unlabelled construction / setup ó [VmIndep._sensor_head:285](../scripts\game\vehicles\vm_indep.gd#L285)

### VmIndep._slats

- Unlabelled construction / setup ó [VmIndep._slats:319](../scripts\game\vehicles\vm_indep.gd#L319)

### VmIndep._smoke

- Unlabelled construction / setup ó [VmIndep._smoke:116](../scripts\game\vehicles\vm_indep.gd#L116)

### VmIndep._sprocket

- Unlabelled construction / setup ó [VmIndep._sprocket:148](../scripts\game\vehicles\vm_indep.gd#L148)

### VmIndep._tow_eyes

- Unlabelled construction / setup ó [VmIndep._tow_eyes:278](../scripts\game\vehicles\vm_indep.gd#L278)

### VmIndep._track_belt

- Unlabelled construction / setup ó [VmIndep._track_belt:155](../scripts\game\vehicles\vm_indep.gd#L155)

### VmIndep._zamak_ammo

- Unlabelled construction / setup ó [VmIndep._zamak_ammo:945](../scripts\game\vehicles\vm_indep.gd#L945)
- three layers of boxes on the pallet, strapped twice, a stencilled label on the outboard face ó [VmIndep._zamak_ammo:954](../scripts\game\vehicles\vm_indep.gd#L954)
- the front stacks under a tarp, its rolled edge ó [VmIndep._zamak_ammo:958](../scripts\game\vehicles\vm_indep.gd#L958)

### VmIndep._zamak_bed

- Unlabelled construction / setup ó [VmIndep._zamak_bed:886](../scripts\game\vehicles\vm_indep.gd#L886)
- under the back: tail lights on their brackets, the bumper bar, pintle, plate ó [VmIndep._zamak_bed:888](../scripts\game\vehicles\vm_indep.gd#L888)

### VmIndep._zamak_box

- Unlabelled construction / setup ó [VmIndep._zamak_box:968](../scripts\game\vehicles\vm_indep.gd#L968)

### VmIndep._zamak_cab

- Unlabelled construction / setup ó [VmIndep._zamak_cab:811](../scripts\game\vehicles\vm_indep.gd#L811)
- chassis rails and cross members, axles with their differentials, springs ó [VmIndep._zamak_cab:812](../scripts\game\vehicles\vm_indep.gd#L812)
- mud flaps behind the front wheel and the bogie ó [VmIndep._zamak_cab:819](../scripts\game\vehicles\vm_indep.gd#L819)
- the bonnet: louvres down its sides, the grille in front ó [VmIndep._zamak_cab:825](../scripts\game\vehicles\vm_indep.gd#L825)
- the wing over the front wheel: flat top, raked front, a valance ó [VmIndep._zamak_cab:832](../scripts\game\vehicles\vm_indep.gd#L832)
- a round headlight on the wing's front, the sidelight on top of it ó [VmIndep._zamak_cab:837](../scripts\game\vehicles\vm_indep.gd#L837)
- the bumper with its tow hooks and plate ó [VmIndep._zamak_cab:840](../scripts\game\vehicles\vm_indep.gd#L840)
- the cab: vertical lower half, the glasshouse leaning in a little ó [VmIndep._zamak_cab:845](../scripts\game\vehicles\vm_indep.gd#L845)
- the door's shut lines up the lower cab to the window line, the step and grab handle, the mirror on its arm ó [VmIndep._zamak_cab:856](../scripts\game\vehicles\vm_indep.gd#L856)
- the roof hatch and marker lights, an antenna on the back corner ó [VmIndep._zamak_cab:864](../scripts\game\vehicles\vm_indep.gd#L864)
- behind the cab: the spare wheel upright in its frame, the air intake, the fuel tank on the left and the battery box on the right ó [VmIndep._zamak_cab:869](../scripts\game\vehicles\vm_indep.gd#L869)
- the air cleaner canister strapped to the cab's back, its pre-cleaner on top ó [VmIndep._zamak_cab:873](../scripts\game\vehicles\vm_indep.gd#L873)
- the battery box's catches face outboard, its lid hinged on the frame side ó [VmIndep._zamak_cab:876](../scripts\game\vehicles\vm_indep.gd#L876)
- the exhaust's silencer under the right side of the cab ó [VmIndep._zamak_cab:878](../scripts\game\vehicles\vm_indep.gd#L878)

### VmIndep._zamak_cargo

- Unlabelled construction / setup ó [VmIndep._zamak_cargo:922](../scripts\game\vehicles\vm_indep.gd#L922)
- two oil drums at the front left, a crate stack at the front right ó [VmIndep._zamak_cargo:925](../scripts\game\vehicles\vm_indep.gd#L925)
- the middle: a pile under a tarpaulin, lashed down ó [VmIndep._zamak_cargo:931](../scripts\game\vehicles\vm_indep.gd#L931)
- the back: crates, sacks and jerrycans ó [VmIndep._zamak_cargo:933](../scripts\game\vehicles\vm_indep.gd#L933)

### VmIndep._zamak_fuel

- Unlabelled construction / setup ó [VmIndep._zamak_fuel:1032](../scripts\game\vehicles\vm_indep.gd#L1032)
- on top: the walkway beside the two manholes, fold-down rails either side ó [VmIndep._zamak_fuel:1038](../scripts\game\vehicles\vm_indep.gd#L1038)
- hazard placards and the fire extinguisher by the cabinet ó [VmIndep._zamak_fuel:1041](../scripts\game\vehicles\vm_indep.gd#L1041)
- the pump cabinet at the back: louvred doors over the outlets, a hazard placard on the left leaf, the hose reel on top, and a ladder up its back by the left leaf's hinges, clear of them and of the outlets ó [VmIndep._zamak_fuel:1044](../scripts\game\vehicles\vm_indep.gd#L1044)
- under the back: tail lights, bumper, pintle ó [VmIndep._zamak_fuel:1052](../scripts\game\vehicles\vm_indep.gd#L1052)

### VmIndep._zamak_medical

- Unlabelled construction / setup ó [VmIndep._zamak_medical:1006](../scripts\game\vehicles\vm_indep.gd#L1006)
- The red crosses are painted on white panels on the body, and stay on a wreck. ó [VmIndep._zamak_medical:1008](../scripts\game\vehicles\vm_indep.gd#L1008)
- the roof: a white panel with its cross, the rolled awning ó [VmIndep._zamak_medical:1016](../scripts\game\vehicles\vm_indep.gd#L1016)
- the back: two doors with the cross across them, two steps hung under them ó [VmIndep._zamak_medical:1019](../scripts\game\vehicles\vm_indep.gd#L1019)

### VmIndep._zamak_mrl

- Unlabelled construction / setup ó [VmIndep._zamak_mrl:1063](../scripts\game\vehicles\vm_indep.gd#L1063)
- stabiliser jacks behind the rear wheels, raised ó [VmIndep._zamak_mrl:1066](../scripts\game\vehicles\vm_indep.gd#L1066)
- the fire-control and reload boxes at the front of the deck ó [VmIndep._zamak_mrl:1070](../scripts\game\vehicles\vm_indep.gd#L1070)
- the turntable and its trunnion brackets ó [VmIndep._zamak_mrl:1074](../scripts\game\vehicles\vm_indep.gd#L1074)
- the elevating ram's base on the turntable ó [VmIndep._zamak_mrl:1082](../scripts\game\vehicles\vm_indep.gd#L1082)
- the pod: twelve cells, three rows of four, in the face on its end frame; its frame bands and the rear cover ó [VmIndep._zamak_mrl:1084](../scripts\game\vehicles\vm_indep.gd#L1084)

### VmIndep._zamak_repair

- Unlabelled construction / setup ó [VmIndep._zamak_repair:975](../scripts\game\vehicles\vm_indep.gd#L975)
- the side door on the right, hinged at its front edge, with its fold-down step; a shuttered locker on the left ó [VmIndep._zamak_repair:981](../scripts\game\vehicles\vm_indep.gd#L981)
- a ladder from the open deck up the back of the body, over the roof edge ó [VmIndep._zamak_repair:986](../scripts\game\vehicles\vm_indep.gd#L986)
- the crane on the deck: slewing ring, column, the boom folded forward over the roof from its heel at the column's top, its luffing ram and the hook hung under the boom's end. The column stands tall enough that the folded boom clears the body's roof (2.98) and rear edge, and the ram runs from the column's face up to the boom behind the body. ó [VmIndep._zamak_repair:988](../scripts\game\vehicles\vm_indep.gd#L988)
- the generator with its cooling louvres, the gas bottles racked by the bed's edge ó [VmIndep._zamak_repair:996](../scripts\game\vehicles\vm_indep.gd#L996)

### VmIndep._zamak_tilt

- Unlabelled construction / setup ó [VmIndep._zamak_tilt:898](../scripts\game\vehicles\vm_indep.gd#L898)
- the hoops showing through, the lashing along the bottom ó [VmIndep._zamak_tilt:900](../scripts\game\vehicles\vm_indep.gd#L900)
- the back: the flap rolled up under the roof, the dark inside, benches ó [VmIndep._zamak_tilt:911](../scripts\game\vehicles\vm_indep.gd#L911)

### VmNato._ammo_can

- Unlabelled construction / setup ó [VmNato._ammo_can:210](../scripts\game\vehicles\vm_nato.gd#L210)

### VmNato._antenna

- Unlabelled construction / setup ó [VmNato._antenna:216](../scripts\game\vehicles\vm_nato.gd#L216)

### VmNato._axles

- Unlabelled construction / setup ó [VmNato._axles:535](../scripts\game\vehicles\vm_nato.gd#L535)

### VmNato._beam

- Unlabelled construction / setup ó [VmNato._beam:188](../scripts\game\vehicles\vm_nato.gd#L188)

### VmNato._cam

- Unlabelled construction / setup ó [VmNato._cam:75](../scripts\game\vehicles\vm_nato.gd#L75)

### VmNato._cargo

- Unlabelled construction / setup ó [VmNato._cargo:1493](../scripts\game\vehicles\vm_nato.gd#L1493)
- the crate, two straps wrapped over it and down its sides to the bed ó [VmNato._cargo:1495](../scripts\game\vehicles\vm_nato.gd#L1495)

### VmNato._chain

- Unlabelled construction / setup ó [VmNato._chain:947](../scripts\game\vehicles\vm_nato.gd#L947)

### VmNato._cross

- Unlabelled construction / setup ó [VmNato._cross:1513](../scripts\game\vehicles\vm_nato.gd#L1513)

### VmNato._era

- Unlabelled construction / setup ó [VmNato._era:156](../scripts\game\vehicles\vm_nato.gd#L156)

### VmNato._extrude_z

- Unlabelled construction / setup ó [VmNato._extrude_z:1248](../scripts\game\vehicles\vm_nato.gd#L1248)

### VmNato._face_basis

- Unlabelled construction / setup ó [VmNato._face_basis:144](../scripts\game\vehicles\vm_nato.gd#L144)

### VmNato._gmg

- Unlabelled construction / setup ó [VmNato._gmg:264](../scripts\game\vehicles\vm_nato.gd#L264)

### VmNato._hemtt_cab_detail

- Unlabelled construction / setup ó [VmNato._hemtt_cab_detail:1340](../scripts\game\vehicles\vm_nato.gd#L1340)
- A pressed roof cap and an inset service panel break up the flat cab. ó [VmNato._hemtt_cab_detail:1342](../scripts\game\vehicles\vm_nato.gd#L1342)
- Door recess, raised inner pressing, hinges and a grab handle. ó [VmNato._hemtt_cab_detail:1346](../scripts\game\vehicles\vm_nato.gd#L1346)
- Worn step lips and lower door sill, where boots contact the paint. ó [VmNato._hemtt_cab_detail:1348](../scripts\game\vehicles\vm_nato.gd#L1348)

### VmNato._hemtt_chassis

- Unlabelled construction / setup ó [VmNato._hemtt_chassis:1257](../scripts\game\vehicles\vm_nato.gd#L1257)
- frame rails, the axles' beams and springs ó [VmNato._hemtt_chassis:1268](../scripts\game\vehicles\vm_nato.gd#L1268)
- the cab: a slightly raked windscreen, flat sides, the nose out in front ó [VmNato._hemtt_chassis:1272](../scripts\game\vehicles\vm_nato.gd#L1272)
- Open upper cab: the windows must reveal seats, dash and the far side, not a solid painted box immediately behind transparent glass. ó [VmNato._hemtt_chassis:1275](../scripts\game\vehicles\vm_nato.gd#L1275)
- the big grille, the bumper with the headlights in its ends, tow eyes, the towing pintle ó [VmNato._hemtt_chassis:1283](../scripts\game\vehicles\vm_nato.gd#L1283)
- each lamp housing: the headlight outboard, the amber indicator inboard ó [VmNato._hemtt_chassis:1289](../scripts\game\vehicles\vm_nato.gd#L1289)
- the sun visor over the windscreen ó [VmNato._hemtt_chassis:1294](../scripts\game\vehicles\vm_nato.gd#L1294)
- windscreen panes, door windows, door seams, handles, mirrors, steps ó [VmNato._hemtt_chassis:1296](../scripts\game\vehicles\vm_nato.gd#L1296)
- the ladder steps up to the door ó [VmNato._hemtt_chassis:1309](../scripts\game\vehicles\vm_nato.gd#L1309)
- the long black fender over both front axles, raked at its front ó [VmNato._hemtt_chassis:1311](../scripts\game\vehicles\vm_nato.gd#L1311)
- the roof hatch, marker lights, antenna ó [VmNato._hemtt_chassis:1315](../scripts\game\vehicles\vm_nato.gd#L1315)
- facing two quarter turns from the marker's +Z: forward ó [VmNato._hemtt_chassis:1318](../scripts\game\vehicles\vm_nato.gd#L1318)
- behind the cab: the engine's air cleaner (left) strapped to the cab's back, the exhaust stack (right), the spare wheel between ó [VmNato._hemtt_chassis:1321](../scripts\game\vehicles\vm_nato.gd#L1321)
- the round fuel tank on the left frame rail, the battery box on the right, air tanks ó [VmNato._hemtt_chassis:1327](../scripts\game\vehicles\vm_nato.gd#L1327)

### VmNato._hemtt_deck

- Unlabelled construction / setup ó [VmNato._hemtt_deck:1361](../scripts\game\vehicles\vm_nato.gd#L1361)

### VmNato._hemtt_tail

- Unlabelled construction / setup ó [VmNato._hemtt_tail:1368](../scripts\game\vehicles\vm_nato.gd#L1368)

### VmNato._hemtt_wheel

- Unlabelled construction / setup ó [VmNato._hemtt_wheel:1355](../scripts\game\vehicles\vm_nato.gd#L1355)

### VmNato._jerry

- Unlabelled construction / setup ó [VmNato._jerry:204](../scripts\game\vehicles\vm_nato.gd#L204)

### VmNato._lamp

- Unlabelled construction / setup ó [VmNato._lamp:193](../scripts\game\vehicles\vm_nato.gd#L193)

### VmNato._m2

- Unlabelled construction / setup ó [VmNato._m2:258](../scripts\game\vehicles\vm_nato.gd#L258)

### VmNato._mk_hull

- Unlabelled construction / setup ó [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- lower hull between the tracks: the lower nose plate, the belly, the tail ó [VmNato._mk_hull:794](../scripts\game\vehicles\vm_nato.gd#L794)
- the upper hull: the sponsons over the tracks, the glacis rising from the nose to the front of the roof, the roof flat back to the rear ó [VmNato._mk_hull:796](../scripts\game\vehicles\vm_nato.gd#L796)
- the nose: a heavy cast beak with tow eyes and the headlight clusters ó [VmNato._mk_hull:801](../scripts\game\vehicles\vm_nato.gd#L801)
- glacis: the engine access panel (hinged along its top) and the big intake grilles, the driver's hatch and periscopes at the top on the left ó [VmNato._mk_hull:807](../scripts\game\vehicles\vm_nato.gd#L807)
- the exhaust louvres on the left of the glacis, facing out of the side, the recess behind them clear of the side leaning in ó [VmNato._mk_hull:816](../scripts\game\vehicles\vm_nato.gd#L816)
- skirts: bolted heavy panels hanging off the sponsons, the front one raked ó [VmNato._mk_hull:819](../scripts\game\vehicles\vm_nato.gd#L819)
- the rail along the sponson edge and a tow cable on it ó [VmNato._mk_hull:826](../scripts\game\vehicles\vm_nato.gd#L826)
- tool boxes along the sponson (the hull roof aft stays clear: the bustle and its chains sweep over it), the long one's latch lever ó [VmNato._mk_hull:829](../scripts\game\vehicles\vm_nato.gd#L829)
- reactive armour bricks over the skirts and up the glacis, each facing out of the side it covers ó [VmNato._mk_hull:837](../scripts\game\vehicles\vm_nato.gd#L837)
- the glacis bricks lie along its slope (as _zy lays a plate), turned over so their covers face up and out of the plate ó [VmNato._mk_hull:843](../scripts\game\vehicles\vm_nato.gd#L843)
- the rear: the troop door with its lever handle and vision block, steps, stowage baskets ó [VmNato._mk_hull:856](../scripts\game\vehicles\vm_nato.gd#L856)

### VmNato._mk_running

- Unlabelled construction / setup ó [VmNato._mk_running:778](../scripts\game\vehicles\vm_nato.gd#L778)

### VmNato._mk_turret

- Unlabelled construction / setup ó [VmNato._mk_turret:879](../scripts\game\vehicles\vm_nato.gd#L879)
- the turret's body: the wedge in front, the main body over the ring ó [VmNato._mk_turret:882](../scripts\game\vehicles\vm_nato.gd#L882)
- the bustle, raised clear of the hull roof (the chains hang across the gap) ó [VmNato._mk_turret:886](../scripts\game\vehicles\vm_nato.gd#L886)
- ball-and-chain curtain along the bustle's rear and sides ó [VmNato._mk_turret:891](../scripts\game\vehicles\vm_nato.gd#L891)
- the gun: a small mantlet low in the wedge, the barrel's thermal sleeve in sections, the fume extractor, the muzzle reference sensor ó [VmNato._mk_turret:898](../scripts\game\vehicles\vm_nato.gd#L898)
- the gunner's sight box forward left, the commander's big panoramic sight forward right, the cupola behind it, the loader's hatch, the 60 mm mortar ó [VmNato._mk_turret:909](../scripts\game\vehicles\vm_nato.gd#L909)
- the loader's MG on its pintle, the wind sensor mast, antennas ó [VmNato._mk_turret:919](../scripts\game\vehicles\vm_nato.gd#L919)
- smoke dischargers on the wedge's flanks, side armour modules with their channels, stowage baskets along the bustle ó [VmNato._mk_turret:926](../scripts\game\vehicles\vm_nato.gd#L926)
- reactive armour bricks over the wedge's faces and the turret sides ó [VmNato._mk_turret:934](../scripts\game\vehicles\vm_nato.gd#L934)

### VmNato._namer_hull

- Unlabelled construction / setup ó [VmNato._namer_hull:1067](../scripts\game\vehicles\vm_nato.gd#L1067)
- the glacis over the engine, then the superstructure's sloped front face, its sides straight up from the sponsons ó [VmNato._namer_hull:1071](../scripts\game\vehicles\vm_nato.gd#L1071)
- the nose with tow eyes and lights in guards ó [VmNato._namer_hull:1077](../scripts\game\vehicles\vm_nato.gd#L1077)
- glacis: engine grilles, the engine access panel ó [VmNato._namer_hull:1083](../scripts\game\vehicles\vm_nato.gd#L1083)
- the exhaust louvres on the left side, as on the Merkava ó [VmNato._namer_hull:1088](../scripts\game\vehicles\vm_nato.gd#L1088)
- the driver's hatch and periscopes on the superstructure front, left ó [VmNato._namer_hull:1090](../scripts\game\vehicles\vm_nato.gd#L1090)
- skirts and side armour: heavy panels low, the superstructure's armour modules with a channel between them, stowage, tow cable ó [VmNato._namer_hull:1096](../scripts\game\vehicles\vm_nato.gd#L1096)
- smoke dischargers on the front roof corners ó [VmNato._namer_hull:1113](../scripts\game\vehicles\vm_nato.gd#L1113)
- roof: the commander's cupola with periscopes, hatches over the troop compartment, stowage at the back ó [VmNato._namer_hull:1115](../scripts\game\vehicles\vm_nato.gd#L1115)
- the rear: the big ramp with its door, hinges, steps ó [VmNato._namer_hull:1127](../scripts\game\vehicles\vm_nato.gd#L1127)

### VmNato._rcws

- Unlabelled construction / setup ó [VmNato._rcws:273](../scripts\game\vehicles\vm_nato.gd#L273)
- Samson-style: a wide box between two cradles, the sight head on top ó [VmNato._rcws:280](../scripts\game\vehicles\vm_nato.gd#L280)
- yoke arms either side of the cradle ó [VmNato._rcws:290](../scripts\game\vehicles\vm_nato.gd#L290)
- the sight unit on the left of the cradle: day camera and thermal windows side by side, under a sun lid ó [VmNato._rcws:300](../scripts\game\vehicles\vm_nato.gd#L300)

### VmNato._ring_z

- Unlabelled construction / setup ó [VmNato._ring_z:1240](../scripts\game\vehicles\vm_nato.gd#L1240)

### VmNato._road_wheel

- Unlabelled construction / setup ó [VmNato._road_wheel:772](../scripts\game\vehicles\vm_nato.gd#L772)

### VmNato._seat

- Unlabelled construction / setup ó [VmNato._seat:249](../scripts\game\vehicles\vm_nato.gd#L249)

### VmNato._shackle

- Unlabelled construction / setup ó [VmNato._shackle:233](../scripts\game\vehicles\vm_nato.gd#L233)

### VmNato._smoke

- Unlabelled construction / setup ó [VmNato._smoke:222](../scripts\game\vehicles\vm_nato.gd#L222)

### VmNato._spare

- Unlabelled construction / setup ó [VmNato._spare:239](../scripts\game\vehicles\vm_nato.gd#L239)

### VmNato._taillight

- Unlabelled construction / setup ó [VmNato._taillight:198](../scripts\game\vehicles\vm_nato.gd#L198)

### VmNato._team_mark

- Unlabelled construction / setup ó [VmNato._team_mark:244](../scripts\game\vehicles\vm_nato.gd#L244)

### VmNato._track_loop

- Unlabelled construction / setup ó [VmNato._track_loop:756](../scripts\game\vehicles\vm_nato.gd#L756)

### VmNato._tube

- Unlabelled construction / setup ó [VmNato._tube:183](../scripts\game\vehicles\vm_nato.gd#L183)

### VmNato._xy

- Unlabelled construction / setup ó [VmNato._xy:120](../scripts\game\vehicles\vm_nato.gd#L120)

### VmNato._xy_bin

- Unlabelled construction / setup ó [VmNato._xy_bin:135](../scripts\game\vehicles\vm_nato.gd#L135)

### VmNato._zy

- Unlabelled construction / setup ó [VmNato._zy:83](../scripts\game\vehicles\vm_nato.gd#L83)

### VmNato._zy_grille

- Unlabelled construction / setup ó [VmNato._zy_grille:97](../scripts\game\vehicles\vm_nato.gd#L97)

### VmNato._zy_hatch

- Unlabelled construction / setup ó [VmNato._zy_hatch:109](../scripts\game\vehicles\vm_nato.gd#L109)

### VmPlane._flank

- Unlabelled construction / setup ó [VmPlane._flank:128](../scripts\game\vehicles\vm_plane.gd#L128)

### VmPlane._foil_t

- Unlabelled construction / setup ó [VmPlane._foil_t:242](../scripts\game\vehicles\vm_plane.gd#L242)

### VmPlane._mx

- Unlabelled construction / setup ó [VmPlane._mx:177](../scripts\game\vehicles\vm_plane.gd#L177)

### VmPlane._sp

- Unlabelled construction / setup ó [VmPlane._sp:89](../scripts\game\vehicles\vm_plane.gd#L89)

### VmPlane._tri

- Unlabelled construction / setup ó [VmPlane._tri:74](../scripts\game\vehicles\vm_plane.gd#L74)

### VmPlane.agm

- Unlabelled construction / setup ó [VmPlane.agm:427](../scripts\game\vehicles\vm_plane.gd#L427)

### VmPlane.antenna

- Unlabelled construction / setup ó [VmPlane.antenna:452](../scripts\game\vehicles\vm_plane.gd#L452)

### VmPlane.band

- Unlabelled construction / setup ó [VmPlane.band:186](../scripts\game\vehicles\vm_plane.gd#L186)

### VmPlane.body

- Unlabelled construction / setup ó [VmPlane.body:158](../scripts\game\vehicles\vm_plane.gd#L158)

### VmPlane.body2

- Unlabelled construction / setup ó [VmPlane.body2:168](../scripts\game\vehicles\vm_plane.gd#L168)

### VmPlane.bomb

- Unlabelled construction / setup ó [VmPlane.bomb:406](../scripts\game\vehicles\vm_plane.gd#L406)

### VmPlane.drop_tank

- Unlabelled construction / setup ó [VmPlane.drop_tank:434](../scripts\game\vehicles\vm_plane.gd#L434)

### VmPlane.glow

- Unlabelled construction / setup ó [VmPlane.glow:277](../scripts\game\vehicles\vm_plane.gd#L277)
- (the texture's alpha makes it a soft round glow, not a lit square) ó [VmPlane.glow:285](../scripts\game\vehicles\vm_plane.gd#L285)

### VmPlane.gun_pod

- Unlabelled construction / setup ó [VmPlane.gun_pod:441](../scripts\game\vehicles\vm_plane.gd#L441)
- the barrel out of the pod's nose (its last few centimetres inside it), the muzzle brake on its end ó [VmPlane.gun_pod:444](../scripts\game\vehicles\vm_plane.gd#L444)

### VmPlane.lift_fan

- Unlabelled construction / setup ó [VmPlane.lift_fan:1067](../scripts\game\vehicles\vm_plane.gd#L1067)

### VmPlane.missile

- Unlabelled construction / setup ó [VmPlane.missile:419](../scripts\game\vehicles\vm_plane.gd#L419)

### VmPlane.mouth

- Unlabelled construction / setup ó [VmPlane.mouth:224](../scripts\game\vehicles\vm_plane.gd#L224)

### VmPlane.nav_lights

- Unlabelled construction / setup ó [VmPlane.nav_lights:458](../scripts\game\vehicles\vm_plane.gd#L458)

### VmPlane.nozzle

- Unlabelled construction / setup ó [VmPlane.nozzle:315](../scripts\game\vehicles\vm_plane.gd#L315)

### VmPlane.prop

- Unlabelled construction / setup ó [VmPlane.prop:353](../scripts\game\vehicles\vm_plane.gd#L353)
- the axis the blades turn about, in the pivot's own space (aft is +z, or +y for a rotor) ó [VmPlane.prop:362](../scripts\game\vehicles\vm_plane.gd#L362)
- the spinner: a pointed cone ahead of the hub ó [VmPlane.prop:364](../scripts\game\vehicles\vm_plane.gd#L364)

### VmPlane.pylon

- Unlabelled construction / setup ó [VmPlane.pylon:400](../scripts\game\vehicles\vm_plane.gd#L400)

### VmPlane.rocket_pod

- Unlabelled construction / setup ó [VmPlane.rocket_pod:412](../scripts\game\vehicles\vm_plane.gd#L412)

### VmPlane.rod

- Unlabelled construction / setup ó [VmPlane.rod:269](../scripts\game\vehicles\vm_plane.gd#L269)

### VmPlane.sec

- Unlabelled construction / setup ó [VmPlane.sec:99](../scripts\game\vehicles\vm_plane.gd#L99)

### VmPlane.skin

- Unlabelled construction / setup ó [VmPlane.skin:67](../scripts\game\vehicles\vm_plane.gd#L67)

### VmPlane.st_at

- Unlabelled construction / setup ó [VmPlane.st_at:141](../scripts\game\vehicles\vm_plane.gd#L141)

### VmPlane.stripe

- Unlabelled construction / setup ó [VmPlane.stripe:198](../scripts\game\vehicles\vm_plane.gd#L198)

### VmPlane.surf

- Unlabelled construction / setup ó [VmPlane.surf:248](../scripts\game\vehicles\vm_plane.gd#L248)

### VmPlane.surf_at

- Unlabelled construction / setup ó [VmPlane.surf_at:256](../scripts\game\vehicles\vm_plane.gd#L256)

### VmPlane.wing_marks

- Unlabelled construction / setup ó [VmPlane.wing_marks:465](../scripts\game\vehicles\vm_plane.gd#L465)

### VmShips._at

- Unlabelled construction / setup ó [VmShips._at:156](../scripts\game\vehicles\vm_ships.gd#L156)

### VmShips._bitts

- Unlabelled construction / setup ó [VmShips._bitts:350](../scripts\game\vehicles\vm_ships.gd#L350)

### VmShips._box_mesh

- Unlabelled construction / setup ó [VmShips._box_mesh:287](../scripts\game\vehicles\vm_ships.gd#L287)

### VmShips._bulwark

- Unlabelled construction / setup ó [VmShips._bulwark:73](../scripts\game\vehicles\vm_ships.gd#L73)

### VmShips._bx

- Unlabelled construction / setup ó [VmShips._bx:283](../scripts\game\vehicles\vm_ships.gd#L283)

### VmShips._coil

- Unlabelled construction / setup ó [VmShips._coil:355](../scripts\game\vehicles\vm_ships.gd#L355)

### VmShips._decal

- Unlabelled construction / setup ó [VmShips._decal:238](../scripts\game\vehicles\vm_ships.gd#L238)

### VmShips._deck_mesh

- Unlabelled construction / setup ó [VmShips._deck_mesh:213](../scripts\game\vehicles\vm_ships.gd#L213)

### VmShips._deck_pitch

- Unlabelled construction / setup ó [VmShips._deck_pitch:166](../scripts\game\vehicles\vm_ships.gd#L166)

### VmShips._deck_y

- Unlabelled construction / setup ó [VmShips._deck_y:65](../scripts\game\vehicles\vm_ships.gd#L65)

### VmShips._digits

- Unlabelled construction / setup ó [VmShips._digits:251](../scripts\game\vehicles\vm_ships.gd#L251)
- the side reads toward the bow on the right (-z), aft on the left ó [VmShips._digits:252](../scripts\game\vehicles\vm_ships.gd#L252)

### VmShips._dk

- Unlabelled construction / setup ó [VmShips._dk:160](../scripts\game\vehicles\vm_ships.gd#L160)

### VmShips._dshk

- Unlabelled construction / setup ó [VmShips._dshk:543](../scripts\game\vehicles\vm_ships.gd#L543)
- the pintle (its socket on the roof, the post, the cradle under the receiver) and three legs welded on to steady it ó [VmShips._dshk:546](../scripts\game\vehicles\vm_ships.gd#L546)

### VmShips._flag

- Unlabelled construction / setup ó [VmShips._flag:398](../scripts\game\vehicles\vm_ships.gd#L398)

### VmShips._hull

- Unlabelled construction / setup ó [VmShips._hull:183](../scripts\game\vehicles\vm_ships.gd#L183)

### VmShips._hull_bands

- Unlabelled construction / setup ó [VmShips._hull_bands:194](../scripts\game\vehicles\vm_ships.gd#L194)

### VmShips._insert

- Unlabelled construction / setup ó [VmShips._insert:134](../scripts\game\vehicles\vm_ships.gd#L134)

### VmShips._keel_y

- Unlabelled construction / setup ó [VmShips._keel_y:79](../scripts\game\vehicles\vm_ships.gd#L79)

### VmShips._liferaft

- Unlabelled construction / setup ó [VmShips._liferaft:374](../scripts\game\vehicles\vm_ships.gd#L374)
- the cradle's saddle ó [VmShips._liferaft:383](../scripts\game\vehicles\vm_ships.gd#L383)

### VmShips._lifering

- Unlabelled construction / setup ó [VmShips._lifering:362](../scripts\game\vehicles\vm_ships.gd#L362)

### VmShips._m2

- Unlabelled construction / setup ó [VmShips._m2:476](../scripts\game\vehicles\vm_ships.gd#L476)
- the post's flange on the deck plate, the post and the cradle under the receiver (an HMG of size 0.9: 0.144 wide, 0.171 high) ó [VmShips._m2:478](../scripts\game\vehicles\vm_ships.gd#L478)

### VmShips._mk38

- Unlabelled construction / setup ó [VmShips._mk38:433](../scripts\game\vehicles\vm_ships.gd#L433)
- the carriage: a low chamfered box on the turntable, the trunnion arms ó [VmShips._mk38:441](../scripts\game\vehicles\vm_ships.gd#L441)
- the cradle housing: chamfered section, its nose tapering round the barrel ó [VmShips._mk38:446](../scripts\game\vehicles\vm_ships.gd#L446)
- the barrel: a support sleeve out of the housing's nose, the long tube, a muzzle device on its end ó [VmShips._mk38:452](../scripts\game\vehicles\vm_ships.gd#L452)
- the electro-optical sight on the left, its windows forward ó [VmShips._mk38:455](../scripts\game\vehicles\vm_ships.gd#L455)
- the ammunition box on the right and its feed chute into the receiver ó [VmShips._mk38:461](../scripts\game\vehicles\vm_ships.gd#L461)
- the spent case chute under the housing, a cable loom at the back ó [VmShips._mk38:466](../scripts\game\vehicles\vm_ships.gd#L466)

### VmShips._rod

- Unlabelled construction / setup ó [VmShips._rod:299](../scripts\game\vehicles\vm_ships.gd#L299)

### VmShips._searchlight

- Unlabelled construction / setup ó [VmShips._searchlight:422](../scripts\game\vehicles\vm_ships.gd#L422)

### VmShips._station

- Unlabelled construction / setup ó [VmShips._station:87](../scripts\game\vehicles\vm_ships.gd#L87)
- a round bilge: a quarter superellipse from the keel up to the bilge's top, full amidships, easing into a V toward the bow ó [VmShips._station:101](../scripts\game\vehicles\vm_ships.gd#L101)
- points where the paint changes and at the deck's edge (always added, so every station of a hull has the same count) ó [VmShips._station:112](../scripts\game\vehicles\vm_ships.gd#L112)
- keep the section convex ó [VmShips._station:119](../scripts\game\vehicles\vm_ships.gd#L119)

### VmShips._stem_z

- Unlabelled construction / setup ó [VmShips._stem_z:171](../scripts\game\vehicles\vm_ships.gd#L171)

### VmShips._surf

- Unlabelled construction / setup ó [VmShips._surf:224](../scripts\game\vehicles\vm_ships.gd#L224)
- reading from outboard: toward the bow on the right side, aft on the left ó [VmShips._surf:229](../scripts\game\vehicles\vm_ships.gd#L229)

### VmShips._sweep

- Unlabelled construction / setup ó [VmShips._sweep:260](../scripts\game\vehicles\vm_ships.gd#L260)

### VmShips._torus

- Unlabelled construction / setup ó [VmShips._torus:322](../scripts\game\vehicles\vm_ships.gd#L322)

### VmShips._tube

- Unlabelled construction / setup ó [VmShips._tube:303](../scripts\game\vehicles\vm_ships.gd#L303)

### VmShips._u

- Unlabelled construction / setup ó [VmShips._u:152](../scripts\game\vehicles\vm_ships.gd#L152)

### VmShips._vent

- Unlabelled construction / setup ó [VmShips._vent:392](../scripts\game\vehicles\vm_ships.gd#L392)

### VmShips._whip

- Unlabelled construction / setup ó [VmShips._whip:416](../scripts\game\vehicles\vm_ships.gd#L416)

### VmShips._zu23

- Unlabelled construction / setup ó [VmShips._zu23:491](../scripts\game\vehicles\vm_ships.gd#L491)
- the lower carriage: a triangle of box beams with levelling jacks ó [VmShips._zu23:493](../scripts\game\vehicles\vm_ships.gd#L493)
- crude welds: a gusset onto the deck plate ó [VmShips._zu23:502](../scripts\game\vehicles\vm_ships.gd#L502)
- the upper carriage: a floor, two side frames up to the trunnions ó [VmShips._zu23:506](../scripts\game\vehicles\vm_ships.gd#L506)
- receivers, then each barrel from its jacket to the slotted flash hider ó [VmShips._zu23:514](../scripts\game\vehicles\vm_ships.gd#L514)
- the box magazine on the gun's outer side ó [VmShips._zu23:517](../scripts\game\vehicles\vm_ships.gd#L517)
- the cradle tying the two guns, the sight standing up on the left ó [VmShips._zu23:521](../scripts\game\vehicles\vm_ships.gd#L521)
- two seats with backrests behind the guns, each on its post, handwheels in front of them ó [VmShips._zu23:526](../scripts\game\vehicles\vm_ships.gd#L526)
- a slab of steel plate welded on in front of the cradle ó [VmShips._zu23:533](../scripts\game\vehicles\vm_ships.gd#L533)

