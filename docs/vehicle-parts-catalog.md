# Vehicle construction part catalog

Source revision: `69a1df03`. 137 model keys, 84 construction-root groups.

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

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmAttack._a10:318](../scripts\game\vehicles\vm_attack.gd#L318)
- Compass Ghost: the darker grey over the nose and cockpit, down the spine ó [VmAttack._a10:344](../scripts\game\vehicles\vm_attack.gd#L344)
- panel joints round the fuselage ó [VmAttack._a10:347](../scripts\game\vehicles\vm_attack.gd#L347)

**Local helper construction:** `VmAttack._a10_cockpit`, `VmAttack._a10_details`, `VmAttack._a10_engines`, `VmAttack._a10_gear`, `VmAttack._a10_gun`, `VmAttack._a10_stores`, `VmAttack._a10_tail`, `VmAttack._a10_wing`, `VmAttack._decal`, `VmAttack._ecm_pod`, `VmAttack._fin_at`, `VmAttack._gear_nodes`, `VmAttack._lathe`, `VmAttack._sec_pt`, `VmAttack._skin_x`, `VmAttack._skin_y`, `VmAttack._sniper`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmPlane._foil_t`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### aa_tech, technical

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.vessel`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.autocannon`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._hilux:756](../scripts\game\vehicles\vm_core.gd#L756)
- ladder frame, the front diff and the rear axle, the exhaust, fuel tank ó [VmCore._hilux:765](../scripts\game\vehicles\vm_core.gd#L765)
- the body: bonnet, front wings and the cab's lower half in one panel, the bed's sides in another, their arches cut round the wheels ó [VmCore._hilux:773](../scripts\game\vehicles\vm_core.gd#L773)
- the bed: its walls, the top rails, the wheel tubs, a ribbed floor ó [VmCore._hilux:779](../scripts\game\vehicles\vm_core.gd#L779)
- the tailgate hanging open on its chains, dented ó [VmCore._hilux:788](../scripts\game\vehicles\vm_core.gd#L788)
- the glasshouse: the windscreen raked well back, the four-door cab, its back window; the panes laid on its faces ó [VmCore._hilux:792](../scripts\game\vehicles\vm_core.gd#L792)
- the doors: shut lines, handles; one rear door a replacement in primer ó [VmCore._hilux:807](../scripts\game\vehicles\vm_core.gd#L807)
- mud up the sills and round the arches ó [VmCore._hilux:815](../scripts\game\vehicles\vm_core.gd#L815)
- wing mirrors at the windscreen's foot ó [VmCore._hilux:817](../scripts\game\vehicles\vm_core.gd#L817)
- arches flared in black, rust round the rear ones, the side step ó [VmCore._hilux:819](../scripts\game\vehicles\vm_core.gd#L819)
- tail lights up the bed's corners ó [VmCore._hilux:826](../scripts\game\vehicles\vm_core.gd#L826)
- brushed-on sand camouflage on some: blotches down the flanks ó [VmCore._hilux:831](../scripts\game\vehicles\vm_core.gd#L831)
- the face: grille, square headlights, indicators, a dented bumper and the pipe bull bar welded across it, the number plate long gone ó [VmCore._hilux:838](../scripts\game\vehicles\vm_core.gd#L838)
- the rear: a step bumper, the tow ball ó [VmCore._hilux:855](../scripts\game\vehicles\vm_core.gd#L855)
- wipers, a whip antenna on the wing ó [VmCore._hilux:859](../scripts\game\vehicles\vm_core.gd#L859)
- the roll bar behind the cab ó [VmCore._hilux:863](../scripts\game\vehicles\vm_core.gd#L863)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._bar`, `VmCore._bx`, `VmCore._dshk`, `VmCore._hilux_dshk`, `VmCore._jerry`, `VmCore._path`, `VmCore._tube`, `VmCore._zu23`.

### ac130

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAircraft.turbine_exhaust`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleSurface.plane`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmGunship._ac130:331](../scripts\game\vehicles\vm_gunship.gd#L331)
- the fuselage: the radome, the flight deck, the long constant section of the cargo hold (belly 0.65 m up, roof 4.75 m), the upswept tail ó [VmGunship._ac130:334](../scripts\game\vehicles\vm_gunship.gd#L334)
- the radome's joint, frame joints down the fuselage ó [VmGunship._ac130:356](../scripts\game\vehicles\vm_gunship.gd#L356)
- the main gear sponsons along the lower sides ó [VmGunship._ac130:363](../scripts\game\vehicles\vm_gunship.gd#L363)
- the closed wheel-well doors under each sponson, the joint at its nose ó [VmGunship._ac130:369](../scripts\game\vehicles\vm_gunship.gd#L369)
- the chaff and flare dispensers in the sponson's tail ó [VmGunship._ac130:374](../scripts\game\vehicles\vm_gunship.gd#L374)
- the wing on top: a constant-chord centre section out past the inboard engines, tapered outer panels with 2.5 degrees of dihedral; Fowler flaps inboard, ailerons outboard ó [VmGunship._ac130:378](../scripts\game\vehicles\vm_gunship.gd#L378)
- the fairing over the wing root on top of the fuselage ó [VmGunship._ac130:387](../scripts\game\vehicles\vm_gunship.gd#L387)
- the engines: long T56 nacelles slung under the wing, four-blade props ó [VmGunship._ac130:390](../scripts\game\vehicles\vm_gunship.gd#L390)
- the tail: the stabiliser with its elevators, the fin and rudder, the dorsal fillet running forward along the top ó [VmGunship._ac130:403](../scripts\game\vehicles\vm_gunship.gd#L403)
- the tail cone: the white tail light looking aft off its tip, the warning sensors either side ó [VmGunship._ac130:410](../scripts\game\vehicles\vm_gunship.gd#L410)
- the anti-collision beacons, low flattened domes on the roof and the belly; the antennas, the SATCOM dome ó [VmGunship._ac130:416](../scripts\game\vehicles\vm_gunship.gd#L416)
- the formation lights: pale green strips on the nose, the tail and the fin ó [VmGunship._ac130:425](../scripts\game\vehicles\vm_gunship.gd#L425)
- markings: the black outline insignia aft and on the wings, team panels ó [VmGunship._ac130:432](../scripts\game\vehicles\vm_gunship.gd#L432)
- the tail number: the fiscal year small, the serial under it ó [VmGunship._ac130:441](../scripts\game\vehicles\vm_gunship.gd#L441)

**Local helper construction:** `VmGunship._ac130_cockpit`, `VmGunship._ac130_doors`, `VmGunship._ac130_gear`, `VmGunship._ac130_guns`, `VmGunship._ang`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._insignia_tris`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._shift`, `VmGunship._t56`, `VmGunship._text_tris`, `VmGunship._tyre`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### angara, angara_k

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._angara:1076](../scripts\game\vehicles\vm_csat.gd#L1076)
- the gun slot and mask, the 125 mm, the coax ó [VmCsat._angara:1083](../scripts\game\vehicles\vm_csat.gd#L1083)
- Afghanit: five launch tubes in a housing low on each flank, firing out ó [VmCsat._angara:1089](../scripts\game\vehicles\vm_csat.gd#L1089)
- radar panels on the corners ó [VmCsat._angara:1096](../scripts\game\vehicles\vm_csat.gd#L1096)
- the soft-kill smoke launchers on the roof ó [VmCsat._angara:1099](../scripts\game\vehicles\vm_csat.gd#L1099)
- the gunner's sight (front left) and the commander's panoramic sight ó [VmCsat._angara:1104](../scripts\game\vehicles\vm_csat.gd#L1104)
- the remote weapon on top: a 12.7 mm, or the command tank's 30 mm turret ó [VmCsat._angara:1107](../scripts\game\vehicles\vm_csat.gd#L1107)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._slats`, `VmCsat._sprocket`, `VmCsat._t14`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### apc, btr

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._btr80:1102](../scripts\game\vehicles\vm_core.gd#L1102)
- the hull: belly, the wheel wells' roof, the crease, the upper sides ó [VmCore._btr80:1107](../scripts\game\vehicles\vm_core.gd#L1107)
- the wheels on their axles, the wells' dark liners, mud flaps ó [VmCore._btr80:1115](../scripts\game\vehicles\vm_core.gd#L1115)
- the bow: the trim vane folded against the lower bow plate, tow hooks, a splash rail across the stem ó [VmCore._btr80:1122](../scripts\game\vehicles\vm_core.gd#L1122)
- the upper glacis and the window plate: the driver's and commander's windows with their shutters propped open, the lights in guards on the corners, the IR light on the left ó [VmCore._btr80:1131](../scripts\game\vehicles\vm_core.gd#L1131)
- the shutter hinged at the top, propped up and out ó [VmCore._btr80:1144](../scripts\game\vehicles\vm_core.gd#L1144)
- the roof: driver's and commander's hatches at the front, the troop hatches behind the turret, periscopes along the edges ó [VmCore._btr80:1152](../scripts\game\vehicles\vm_core.gd#L1152)
- the side doors between the second and third axles: the upper half in the sloped side, the lower half below the crease; firing ports, the stowage boxes and the exhausts aft, tow cable ó [VmCore._btr80:1159](../scripts\game\vehicles\vm_core.gd#L1159)
- the lower half, below the crease, folding down into a step ó [VmCore._btr80:1174](../scripts\game\vehicles\vm_core.gd#L1174)
- the engine deck: the louvred grilles, the access panels ó [VmCore._btr80:1185](../scripts\game\vehicles\vm_core.gd#L1185)
- the stern: the water-jet's flap, tail lights, tow hooks, the antenna ó [VmCore._btr80:1190](../scripts\game\vehicles\vm_core.gd#L1190)
- --- the BPU-1 turret: a low cone, the mantlet, the KPVT and the PKT ó [VmCore._btr80:1197](../scripts\game\vehicles\vm_core.gd#L1197)
- the KPVT: the heavy jacket over its rear third, the bare barrel, the muzzle brake; the coaxial PKT's port to its right ó [VmCore._btr80:1206](../scripts\game\vehicles\vm_core.gd#L1206)
- the gunner's sight on the left of the roof, a vision block right, the hatch ó [VmCore._btr80:1211](../scripts\game\vehicles\vm_core.gd#L1211)
- six smoke dischargers in a row across the back, firing over the turret ó [VmCore._btr80:1215](../scripts\game\vehicles\vm_core.gd#L1215)

**Local helper construction:** `VmCore._antenna`, `VmCore._bx`, `VmCore._cam`, `VmCore._hatch`, `VmCore._lamp`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmCore._zy`.

### assault_boat

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._zodiac:449](../scripts\game\vehicles\vm_boat.gd#L449)
- the tube's centreline: straight sides into a round bow that kicks up ó [VmBoat._zodiac:454](../scripts\game\vehicles\vm_boat.gd#L454)
- the tube ends: cones past the transom ó [VmBoat._zodiac:465](../scripts\game\vehicles\vm_boat.gd#L465)
- compartment seams round the tube ó [VmBoat._zodiac:468](../scripts\game\vehicles\vm_boat.gd#L468)
- inflation valves on top ó [VmBoat._zodiac:472](../scripts\game\vehicles\vm_boat.gd#L472)
- the hull: a shallow V of fabric under a flat floor, rising into the bow ó [VmBoat._zodiac:476](../scripts\game\vehicles\vm_boat.gd#L476)
- aluminium floorboards ó [VmBoat._zodiac:485](../scripts\game\vehicles\vm_boat.gd#L485)
- the transom with its knees and the motor pad ó [VmBoat._zodiac:488](../scripts\game\vehicles\vm_boat.gd#L488)
- 55 hp outboard on a tiller, its fuel tank and hose ó [VmBoat._zodiac:493](../scripts\game\vehicles\vm_boat.gd#L493)
- two paddles along the tubes, a rucksack and a dry bag lashed amidships ó [VmBoat._zodiac:502](../scripts\game\vehicles\vm_boat.gd#L502)
- the bow's towing ring and grab handle ó [VmBoat._zodiac:510](../scripts\game\vehicles\vm_boat.gd#L510)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._foil`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._tube`, `VmBoat._tube_kit`.

### blackfish, blackfish_armed

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAircraft.turbine_exhaust`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmGunship._blackfish:641](../scripts\game\vehicles\vm_gunship.gd#L641)
- the blue underside, up to a line along the lower flanks ó [VmGunship._blackfish:665](../scripts\game\vehicles\vm_gunship.gd#L665)
- the sponsons: the main gear, fuel, the chaff and flare dispensers ó [VmGunship._blackfish:672](../scripts\game\vehicles\vm_gunship.gd#L672)
- the wing: straight, a touch of forward sweep, thick; flaperons along it ó [VmGunship._blackfish:684](../scripts\game\vehicles\vm_gunship.gd#L684)
- the fairing over the wing's centre section ó [VmGunship._blackfish:690](../scripts\game\vehicles\vm_gunship.gd#L690)
- the nacelles on their tilt pivots at the tips, the proprotors (the right one a mirror image, turning the other way) ó [VmGunship._blackfish:693](../scripts\game\vehicles\vm_gunship.gd#L693)
- the dorsal spine from the wing back to the tail, the formation lights ó [VmGunship._blackfish:706](../scripts\game\vehicles\vm_gunship.gd#L706)
- the targeting turret under the nose, antennas, the beacons ó [VmGunship._blackfish:715](../scripts\game\vehicles\vm_gunship.gd#L715)
- team panels on the wings and the tail ó [VmGunship._blackfish:729](../scripts\game\vehicles\vm_gunship.gd#L729)

**Local helper construction:** `VmGunship._ang`, `VmGunship._bf_cockpit`, `VmGunship._bf_doors`, `VmGunship._bf_gear`, `VmGunship._bf_guns`, `VmGunship._bf_nacelle`, `VmGunship._bf_tail`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._tyre`, `VmGunship._under`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### blackfoot

**Shared:** `VehicleAircraft.pitot`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._blackfoot:732](../scripts\game\vehicles\vm_heli.gd#L732)
- the stepped tandem canopy, framed, and the night-pilotage window ó [VmHeli._blackfoot:752](../scripts\game\vehicles\vm_heli.gd#L752)
- the bays, open; engine inlets; exhaust slots down the tail ó [VmHeli._blackfoot:759](../scripts\game\vehicles\vm_heli.gd#L759)
- the mast fairing and mast ó [VmHeli._blackfoot:764](../scripts\game\vehicles\vm_heli.gd#L764)
- the fantail: a shroud with an open duct, a fin over it, the T-tail ó [VmHeli._blackfoot:768](../scripts\game\vehicles\vm_heli.gd#L768)
- tailwheel under the boom ó [VmHeli._blackfoot:778](../scripts\game\vehicles\vm_heli.gd#L778)
- main gear legs out of their stubs ó [VmHeli._blackfoot:783](../scripts\game\vehicles\vm_heli.gd#L783)
- the bay doors opened out: three Hellfires on rails under each ó [VmHeli._blackfoot:789](../scripts\game\vehicles\vm_heli.gd#L789)
- the chin turret: XM301 three-barrel 20 mm ó [VmHeli._blackfoot:798](../scripts\game\vehicles\vm_heli.gd#L798)
- the barrels out of the receiver, one on top, clamped near the breech and at the muzzles ó [VmHeli._blackfoot:802](../scripts\game\vehicles\vm_heli.gd#L802)
- pitots and an antenna ó [VmHeli._blackfoot:806](../scripts\game\vehicles\vm_heli.gd#L806)
- the rotor: five blades with swept tips, a faceted hub shroud ó [VmHeli._blackfoot:810](../scripts\game\vehicles\vm_heli.gd#L810)

**Local helper construction:** `VmHeli._air`, `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rotor`, `VmHeli._tube`.

### blackwasp

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.gear_leg`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmFighter._blackwasp:997](../scripts\game\vehicles\vm_fighter.gd#L997)
- --- fuselage: [z, crown, shoulder x y, chine x y half-thickness, LEX underside corner x y, side wall foot x y, belly corner x y, keel] ó [VmFighter._blackwasp:1006](../scripts\game\vehicles\vm_fighter.gd#L1006)
- the F-22-style one-piece canopy, gold-coated, its sill frame ó [VmFighter._blackwasp:1030](../scripts\game\vehicles\vm_fighter.gd#L1030)
- --- intakes and engine nacelles: caret mouths raked in two planes, the ducts turning round into the engines, the nozzles ó [VmFighter._blackwasp:1038](../scripts\game\vehicles\vm_fighter.gd#L1038)
- the nozzle: a hollow can, short sawtooth teeth round its lip, the flame holder deep inside ó [VmFighter._blackwasp:1057](../scripts\game\vehicles\vm_fighter.gd#L1057)
- --- wing: trapezoid, LE flaps, flaperons inboard, ailerons outboard ó [VmFighter._blackwasp:1071](../scripts\game\vehicles\vm_fighter.gd#L1071)
- diamond stabilators on the tail shelves ó [VmFighter._blackwasp:1075](../scripts\game\vehicles\vm_fighter.gd#L1075)
- twin fins canted 22 degrees out, rudders ó [VmFighter._blackwasp:1077](../scripts\game\vehicles\vm_fighter.gd#L1077)
- --- details: the gun port in the right LEX, the EOTS window under the nose, the tail hook, antennas, lights ó [VmFighter._blackwasp:1084](../scripts\game\vehicles\vm_fighter.gd#L1084)
- the arrestor hook stowed between the nozzles, its point showing ó [VmFighter._blackwasp:1099](../scripts\game\vehicles\vm_fighter.gd#L1099)
- --- panel lines: the weapon bay doors and the gear doors (sawtooth ends), the radome joint, access panels on the deck ó [VmFighter._blackwasp:1113](../scripts\game\vehicles\vm_fighter.gd#L1113)
- the radome joint: a sawtooth across the chined nose ó [VmFighter._blackwasp:1135](../scripts\game\vehicles\vm_fighter.gd#L1135)
- deck access panels and the fuel tank doors over the LEX ó [VmFighter._blackwasp:1139](../scripts\game\vehicles\vm_fighter.gd#L1139)
- the side weapon bays in the intake walls, the engine bay doors under the nacelles, the refuelling probe's door on the right of the nose ó [VmFighter._blackwasp:1147](../scripts\game\vehicles\vm_fighter.gd#L1147)
- radar-absorbent dark caps on the fin tips ó [VmFighter._blackwasp:1168](../scripts\game\vehicles\vm_fighter.gd#L1168)
- --- markings: low-visibility Navy star-and-bar, the air wing's tail code, the modex on the nose ó [VmFighter._blackwasp:1173](../scripts\game\vehicles\vm_fighter.gd#L1173)
- --- landing gear (shown on the ground): twin nose wheels with the catapult launch bar, the main legs out of the intake trunks, open doors ó [VmFighter._blackwasp:1190](../scripts\game\vehicles\vm_fighter.gd#L1190)

**Local helper construction:** `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._bw_half`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._cloop`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._ft`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._loop`, `VmFighter._mesh`, `VmFighter._mixloop`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._project`, `VmFighter._put`, `VmFighter._qloop`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmFighter._zigzag`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### bobcat

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._bobcat:1126](../scripts\game\vehicles\vm_nato.gd#L1126)
- the dozer blade, raised for travel: a curved mouldboard of three facets, its cutting edge, the push arms and the lifting rams ó [VmNato._bobcat:1129](../scripts\game\vehicles\vm_nato.gd#L1129)
- the crane: its slewing base on the roof's back right, the boom folded forward along the right side onto a rest, the hook stowed ó [VmNato._bobcat:1144](../scripts\game\vehicles\vm_nato.gd#L1144)
- the main winch drum at the back of the roof, tow bars and tools ó [VmNato._bobcat:1156](../scripts\game\vehicles\vm_nato.gd#L1156)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### buzzard

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._buzzard:494](../scripts\game\vehicles\vm_plane.gd#L494)
- the radome a shade darker, a joint band behind it ó [VmPlane._buzzard:514](../scripts\game\vehicles\vm_plane.gd#L514)
- dorsal spine from the canopy to the fin ó [VmPlane._buzzard:517](../scripts\game\vehicles\vm_plane.gd#L517)
- the canopy: windscreen and bubble, its bows ó [VmPlane._buzzard:519](../scripts\game\vehicles\vm_plane.gd#L519)
- the intakes: D-shaped mouths standing off the fuselage on splitter plates ó [VmPlane._buzzard:525](../scripts\game\vehicles\vm_plane.gd#L525)
- the wing: tapered, a little dihedral, flaps and ailerons ó [VmPlane._buzzard:534](../scripts\game\vehicles\vm_plane.gd#L534)
- tip tanks with their navigation lights ó [VmPlane._buzzard:537](../scripts\game\vehicles\vm_plane.gd#L537)
- tailplane and fin (rudder, elevators), the dorsal fillet ó [VmPlane._buzzard:542](../scripts\game\vehicles\vm_plane.gd#L542)
- the jet pipe ó [VmPlane._buzzard:547](../scripts\game\vehicles\vm_plane.gd#L547)
- probes, antennas, the airbrakes under the belly ó [VmPlane._buzzard:550](../scripts\game\vehicles\vm_plane.gd#L550)
- stores: gun pod on the centreline; bombs, rocket pods, Sidewinders ó [VmPlane._buzzard:556](../scripts\game\vehicles\vm_plane.gd#L556)
- national markings ó [VmPlane._buzzard:572](../scripts\game\vehicles\vm_plane.gd#L572)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### caesar

**Shared:** `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._caesar:787](../scripts\game\vehicles\vm_plane.gd#L787)
- the livery: a stripe down each flank, a pinstripe above it ó [VmPlane._caesar:804](../scripts\game\vehicles\vm_plane.gd#L804)
- the cabin: a glass house, its pillars and a painted roof ó [VmPlane._caesar:810](../scripts\game\vehicles\vm_plane.gd#L810)
- door seams ó [VmPlane._caesar:818](../scripts\game\vehicles\vm_plane.gd#L818)
- cowl inlets and exhaust stacks, the landing light ó [VmPlane._caesar:822](../scripts\game\vehicles\vm_plane.gd#L822)
- the wing: low, tapered, dihedral, flaps and ailerons, upturned tips ó [VmPlane._caesar:826](../scripts\game\vehicles\vm_plane.gd#L826)
- tail: the swept fin and the stabiliser ó [VmPlane._caesar:831](../scripts\game\vehicles\vm_plane.gd#L831)
- fixed tricycle gear: a nose leg, spring-steel mains, wheels in spats ó [VmPlane._caesar:835](../scripts\game\vehicles\vm_plane.gd#L835)
- the propeller: three blades with painted tips, the spinner ó [VmPlane._caesar:844](../scripts\game\vehicles\vm_plane.gd#L844)
- antennas on the roof and belly, the pitot under the left wing ó [VmPlane._caesar:846](../scripts\game\vehicles\vm_plane.gd#L846)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`.

### cheetah

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._cheetah:1170](../scripts\game\vehicles\vm_nato.gd#L1170)
- a 35 mm on each flank: the trunnion housing, the cradle, the long barrel with its muzzle velocity radar ring and brake ó [VmNato._cheetah:1179](../scripts\game\vehicles\vm_nato.gd#L1179)
- the ammunition feed chute and the missile box above the gun ó [VmNato._cheetah:1188](../scripts\game\vehicles\vm_nato.gd#L1188)
- the tracking radar (a dish in a drum) on the front of the roof, the optics beside it ó [VmNato._cheetah:1198](../scripts\game\vehicles\vm_nato.gd#L1198)
- hatches, the search radar on its folding mast at the back ó [VmNato._cheetah:1203](../scripts\game\vehicles\vm_nato.gd#L1203)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### civilian_0, civilian_1, civilian_2, civilian_3, civilian_4

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VehicleModels._car:602](../scripts\game\vehicle_models.gd#L602)
- glass: windscreen, rear screen, side windows (inset a touch) ó [VehicleModels._car:626](../scripts\game\vehicle_models.gd#L626)
- bumpers, lights, plate ó [VehicleModels._car:650](../scripts\game\vehicle_models.gd#L650)
- the bed: sides and tailgate ó [VehicleModels._car:662](../scripts\game\vehicle_models.gd#L662)
- wheels in dark arches ó [VehicleModels._car:667](../scripts\game\vehicle_models.gd#L667)

### darter

**Shared:** `VehicleAircraft.skid_runner`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._darter:1436](../scripts\game\vehicles\vm_heli.gd#L1436)
- the X of arms, a motor and guard ring at each end ó [VmHeli._darter:1450](../scripts\game\vehicles\vm_heli.gd#L1450)
- lights under the motors: red on the left and green on the right up front, white aft ó [VmHeli._darter:1464](../scripts\game\vehicles\vm_heli.gd#L1464)
- the camera on its gimbal under the nose ó [VmHeli._darter:1471](../scripts\game\vehicles\vm_heli.gd#L1471)
- skids ó [VmHeli._darter:1475](../scripts\game\vehicles\vm_heli.gd#L1475)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._tube`.

### demining_drone, utility_drone

**Shared:** `VehicleAircraft.skid_runner`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._hexa:1487](../scripts\game\vehicles\vm_heli.gd#L1487)
- the hub: a hexagonal frame, the dome, the battery under it ó [VmHeli._hexa:1494](../scripts\game\vehicles\vm_heli.gd#L1494)
- six arms, alternately turning props, orientation colours on the front pair ó [VmHeli._hexa:1502](../scripts\game\vehicles\vm_heli.gd#L1502)
- skids on two legs each ó [VmHeli._hexa:1513](../scripts\game\vehicles\vm_heli.gd#L1513)
- a rack of four demolition charges and the ground-scanning sensor ó [VmHeli._hexa:1519](../scripts\game\vehicles\vm_heli.gd#L1519)
- the cargo box on its release hook ó [VmHeli._hexa:1532](../scripts\game\vehicles\vm_heli.gd#L1532)

**Local helper construction:** `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._tube`.

### ed1

**Shared:** `VehicleBody.paint_mesh`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._ed1:1435](../scripts\game\vehicles\vm_civ.gd#L1435)
- the flippers, swung forward and up off the front sprockets ó [VmCiv._ed1:1447](../scripts\game\vehicles\vm_civ.gd#L1447)
- carry handles on the hull sides ó [VmCiv._ed1:1452](../scripts\game\vehicles\vm_civ.gd#L1452)
- the payload box at the back ó [VmCiv._ed1:1457](../scripts\game\vehicles\vm_civ.gd#L1457)
- the arm, folded: turntable, shoulder, upper arm back, forearm forward ó [VmCiv._ed1:1460](../scripts\game\vehicles\vm_civ.gd#L1460)
- the sensor head: cameras and a light, the gripper's jaws under it ó [VmCiv._ed1:1471](../scripts\game\vehicles\vm_civ.gd#L1471)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._xbody`.

### falcon

**Shared:** `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._falcon:1348](../scripts\game\vehicles\vm_heli.gd#L1348)
- panel seams and access hatches (no windows: nobody aboard) ó [VmHeli._falcon:1364](../scripts\game\vehicles\vm_heli.gd#L1364)
- the engine fairing on the back, its intake and exhaust; the mast ó [VmHeli._falcon:1369](../scripts\game\vehicles\vm_heli.gd#L1369)
- the boom, fins, stabiliser, the tail rotor on the left ó [VmHeli._falcon:1376](../scripts\game\vehicles\vm_heli.gd#L1376)
- the sensor ball under the nose, antennas, the datalink dome ó [VmHeli._falcon:1383](../scripts\game\vehicles\vm_heli.gd#L1383)
- skids ó [VmHeli._falcon:1390](../scripts\game\vehicles\vm_heli.gd#L1390)
- stub wings with two pylons a side, a small missile on each ó [VmHeli._falcon:1392](../scripts\game\vehicles\vm_heli.gd#L1392)
- the rotor: four blades ó [VmHeli._falcon:1400](../scripts\game\vehicles\vm_heli.gd#L1400)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### fenghuang

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._fenghuang:1230](../scripts\game\vehicles\vm_plane.gd#L1230)
- canards with elevators; the main wing with ailerons; fins at its tips ó [VmPlane._fenghuang:1245](../scripts\game\vehicles\vm_plane.gd#L1245)
- the engine's air scoop on top, the exhaust, the pusher propeller ó [VmPlane._fenghuang:1250](../scripts\game\vehicles\vm_plane.gd#L1250)
- the sensor ball ó [VmPlane._fenghuang:1256](../scripts\game\vehicles\vm_plane.gd#L1256)
- fixed tricycle gear ó [VmPlane._fenghuang:1260](../scripts\game\vehicles\vm_plane.gd#L1260)
- antennas: the satcom blade, a whip ó [VmPlane._fenghuang:1266](../scripts\game\vehicles\vm_plane.gd#L1266)
- four small missiles, two under each wing ó [VmPlane._fenghuang:1269](../scripts\game\vehicles\vm_plane.gd#L1269)

**Local helper construction:** `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### fia_truck, fia_truck_box

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleCargo.sideboard`, `VehicleDoors.leaf`, `VehicleEquipment.vessel`, `VehicleEquipment.winch`, `VehicleFittings.filler`, `VehicleFittings.headlamp`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._truck:643](../scripts\game\vehicles\vm_civ.gd#L643)
- ladder frame, beam axles with their diffs, fuel tank, battery box ó [VmCiv._truck:651](../scripts\game\vehicles\vm_civ.gd#L651)
- the cab over the front wheels, the short nose in front of it ó [VmCiv._truck:662](../scripts\game\vehicles\vm_civ.gd#L662)
- shut lines, handle, the steps behind the wheel, mirrors on long arms ó [VmCiv._truck:672](../scripts\game\vehicles\vm_civ.gd#L672)
- black flares on the front arch, mudflaps ó [VmCiv._truck:682](../scripts\game\vehicles\vm_civ.gd#L682)
- the rear wheel's mudguard under the bed ó [VmCiv._truck:687](../scripts\game\vehicles\vm_civ.gd#L687)
- headlights in the nose corners, indicators, roof markers ó [VmCiv._truck:689](../scripts\game\vehicles\vm_civ.gd#L689)
- grille between the lamps, the 4x4's steel bumper with a winch, plate ó [VmCiv._truck:696](../scripts\game\vehicles\vm_civ.gd#L696)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._truck_bed`, `VmCiv._truck_box`, `VmCiv._truck_rear`, `VmCiv._xbody`.

### futura

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._futura:910](../scripts\game\vehicles\vm_csat.gd#L910)
- seams of the panels on the faceted roof ó [VmCsat._futura:918](../scripts\game\vehicles\vm_csat.gd#L918)
- the railgun: a boxy shroud round the breech end, two flat rails ahead held by spacer bands, an open frame at the muzzle ó [VmCsat._futura:921](../scripts\game\vehicles\vm_csat.gd#L921)
- the capacitor bank and its cooling vents at the back ó [VmCsat._futura:935](../scripts\game\vehicles\vm_csat.gd#L935)
- sights: the gunner's block, the commander's panoramic head, a remote MG ó [VmCsat._futura:941](../scripts\game\vehicles\vm_csat.gd#L941)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### ghosthawk, ghosthawk_stub

**Shared:** `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.wire_cutter`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._ghost_hawk:513](../scripts\game\vehicles\vm_heli.gd#L513)
- windscreens: the front panes over the nose, the cockpit door windows ó [VmHeli._ghost_hawk:532](../scripts\game\vehicles\vm_heli.gd#L532)
- door seams, the gunners' windows (open), the sliding cabin doors ó [VmHeli._ghost_hawk:538](../scripts\game\vehicles\vm_heli.gd#L538)
- the top fairing over the gearbox, the engines either side of it ó [VmHeli._ghost_hawk:545](../scripts\game\vehicles\vm_heli.gd#L545)
- the shrouded exhausts, turned out and up ó [VmHeli._ghost_hawk:551](../scripts\game\vehicles\vm_heli.gd#L551)
- mast, swashplate, the IR jammer behind, wire cutters, pitots ó [VmHeli._ghost_hawk:554](../scripts\game\vehicles\vm_heli.gd#L554)
- steps, a grab handle, the navigation lights ó [VmHeli._ghost_hawk:561](../scripts\game\vehicles\vm_heli.gd#L561)
- the tail pylon, the canted tail rotor high on its right, the stabilator ó [VmHeli._ghost_hawk:565](../scripts\game\vehicles\vm_heli.gd#L565)
- tailwheel ó [VmHeli._ghost_hawk:580](../scripts\game\vehicles\vm_heli.gd#L580)
- main gear: drag beam and shock strut, faceted hub covers ó [VmHeli._ghost_hawk:585](../scripts\game\vehicles\vm_heli.gd#L585)
- door guns: miniguns on pintles in the gunners' windows ó [VmHeli._ghost_hawk:592](../scripts\game\vehicles\vm_heli.gd#L592)
- the External Stores Support System: anhedral stub wings over the cabin's rear, braced to the floor, two pylons and two pods a side ó [VmHeli._ghost_hawk:600](../scripts\game\vehicles\vm_heli.gd#L600)
- the rotor: four blades with swept tips under a faceted hub cap ó [VmHeli._ghost_hawk:611](../scripts\game\vehicles\vm_heli.gd#L611)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### gorgon

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWeapons.launch_tube`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._gorgon:678](../scripts\game\vehicles\vm_indep.gd#L678)
- the V-shaped belly between the wheels, the upper hull over them ó [VmIndep._gorgon:684](../scripts\game\vehicles\vm_indep.gd#L684)
- the wheel well's dark liner under the overhang ó [VmIndep._gorgon:690](../scripts\game\vehicles\vm_indep.gd#L690)
- the hull's side: a chine strake at mid height, stowage boxes aft, the side's lifting eyes ó [VmIndep._gorgon:694](../scripts\game\vehicles\vm_indep.gd#L694)
- headlight clusters with guards at the bow's corners, tow eyes ó [VmIndep._gorgon:700](../scripts\game\vehicles\vm_indep.gd#L700)
- rear: tail lights, tow eyes, a whip antenna on each corner ó [VmIndep._gorgon:703](../scripts\game\vehicles\vm_indep.gd#L703)
- the bow: the trim vane folded on the glacis, its hinge line ó [VmIndep._gorgon:707](../scripts\game\vehicles\vm_indep.gd#L707)
- roof: the driver's hatch and periscopes front-left, a mirror; the engine grille front-right; the exhaust on the right flank ó [VmIndep._gorgon:712](../scripts\game\vehicles\vm_indep.gd#L712)
- the troop compartment's roof hatches, aft, hinged at the back ó [VmIndep._gorgon:725](../scripts\game\vehicles\vm_indep.gd#L725)
- the rear door: vision block, handle, hinges; a step under it ó [VmIndep._gorgon:728](../scripts\game\vehicles\vm_indep.gd#L728)
- the turret: low and faceted, the 30 mm in its mantlet with the coax beside it, a Titan tube on each side ó [VmIndep._gorgon:737](../scripts\game\vehicles\vm_indep.gd#L737)
- the Titan tube on its bracket ó [VmIndep._gorgon:750](../scripts\game\vehicles\vm_indep.gd#L750)
- smoke dischargers on the front corners ó [VmIndep._gorgon:753](../scripts\game\vehicles\vm_indep.gd#L753)
- roof: the gunner's sight front-left, the commander's panoramic sight right, his hatch behind it ó [VmIndep._gorgon:756](../scripts\game\vehicles\vm_indep.gd#L756)
- a stowage basket on the turret's back ó [VmIndep._gorgon:763](../scripts\game\vehicles\vm_indep.gd#L763)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._smoke`, `VmIndep._tb`.

### greyhawk

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._greyhawk:1108](../scripts\game\vehicles\vm_plane.gd#L1108)
- the dish housing a shade lighter, its joint line ó [VmPlane._greyhawk:1126](../scripts\game\vehicles\vm_plane.gd#L1126)
- the sensor ball under the nose, its window looking forward ó [VmPlane._greyhawk:1128](../scripts\game\vehicles\vm_plane.gd#L1128)
- canards, the wing with flaps and ailerons ó [VmPlane._greyhawk:1133](../scripts\game\vehicles\vm_plane.gd#L1133)
- the Y tail: ruddervators up, the ventral fin down ó [VmPlane._greyhawk:1138](../scripts\game\vehicles\vm_plane.gd#L1138)
- the turboprop: dorsal NACA inlet, ventral scoop, exhaust stubs; the prop ó [VmPlane._greyhawk:1141](../scripts\game\vehicles\vm_plane.gd#L1141)
- antennas: the satcom blades, the belly whips ó [VmPlane._greyhawk:1149](../scripts\game\vehicles\vm_plane.gd#L1149)
- two pylons, a Paveway on each ó [VmPlane._greyhawk:1153](../scripts\game\vehicles\vm_plane.gd#L1153)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gryphon

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.pitot`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._gryphon:587](../scripts\game\vehicles\vm_plane.gd#L587)
- D-shaped intakes on splitter plates, the canards on their shoulders ó [VmPlane._gryphon:614](../scripts\game\vehicles\vm_plane.gd#L614)
- the cranked delta, elevons along its trailing edge ó [VmPlane._gryphon:624](../scripts\game\vehicles\vm_plane.gd#L624)
- the dogtooth: a small step in the leading edge ó [VmPlane._gryphon:627](../scripts\game\vehicles\vm_plane.gd#L627)
- tip rails with Sidewinders, navigation lights ó [VmPlane._gryphon:630](../scripts\game\vehicles\vm_plane.gd#L630)
- the fin with its rudder, a fairing at the tip ó [VmPlane._gryphon:635](../scripts\game\vehicles\vm_plane.gd#L635)
- the afterburner nozzle, airbrakes on the tail cone ó [VmPlane._gryphon:638](../scripts\game\vehicles\vm_plane.gd#L638)
- probes and antennas, the gun port low on the left ó [VmPlane._gryphon:643](../scripts\game\vehicles\vm_plane.gd#L643)
- stores: a centreline tank, Paveways inboard, Mavericks outboard ó [VmPlane._gryphon:650](../scripts\game\vehicles\vm_plane.gd#L650)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gun_trawler

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmShips._gun_trawler:904](../scripts\game\vehicles\vm_ships.gd#L904)
- the transom's bulwark across the stern ó [VmShips._gun_trawler:915](../scripts\game\vehicles\vm_ships.gd#L915)
- the keel bar and the stem bar running up the bow ó [VmShips._gun_trawler:919](../scripts\game\vehicles\vm_ships.gd#L919)
- the skeg under the run, the propeller in its aperture, the rudder ó [VmShips._gun_trawler:940](../scripts\game\vehicles\vm_ships.gd#L940)
- rubbing bands, bilge keels, the bulwark capping ó [VmShips._gun_trawler:948](../scripts\game\vehicles\vm_ships.gd#L948)
- freeing ports in the bulwarks with rust running from them, rust and primer patches, a replaced plate, the registration on the bows ó [VmShips._gun_trawler:965](../scripts\game\vehicles\vm_ships.gd#L965)
- the hawse pipe with the anchor in it and rust bleeding down ó [VmShips._gun_trawler:985](../scripts\game\vehicles\vm_ships.gd#L985)
- tyres hung over the side as fenders ó [VmShips._gun_trawler:994](../scripts\game\vehicles\vm_ships.gd#L994)
- --- the deckhouse, white and streaked, and the wheelhouse on it ó [VmShips._gun_trawler:1001](../scripts\game\vehicles\vm_ships.gd#L1001)
- the deckhouse: a door and portholes each side, rust under them, a ladder up the back to the boat deck, handrails round the roof ó [VmShips._gun_trawler:1030](../scripts\game\vehicles\vm_ships.gd#L1030)
- sidelights in their screens on the wheelhouse's shoulders ó [VmShips._gun_trawler:1043](../scripts\game\vehicles\vm_ships.gd#L1043)
- the funnel (black-topped, sooty), a liferaft canister, a boat-deck locker ó [VmShips._gun_trawler:1058](../scripts\game\vehicles\vm_ships.gd#L1058)
- --- the wheelhouse roof: the DShK, radar mast with its scanner, a searchlight, horn, whips, a loudhailer ó [VmShips._gun_trawler:1065](../scripts\game\vehicles\vm_ships.gd#L1065)
- --- the mast and its derrick, the trawl winch, the fish hold hatch ó [VmShips._gun_trawler:1078](../scripts\game\vehicles\vm_ships.gd#L1078)
- shrouds down to the bulwark ó [VmShips._gun_trawler:1085](../scripts\game\vehicles\vm_ships.gd#L1085)
- --- the foredeck: the ZU-23-2 on a welded plinth (the turret), ammo crates, sandbags along the bulwark, the windlass and the bow fairlead ó [VmShips._gun_trawler:1113](../scripts\game\vehicles\vm_ships.gd#L1113)
- --- the after deck: the net drum, the gantry with its blocks, the trawl doors hung outboard, nets piled with floats, fish boxes, a dan buoy ó [VmShips._gun_trawler:1143](../scripts\game\vehicles\vm_ships.gd#L1143)
- a block hanging from the beam, the warp to it, the trawl door on its chains ó [VmShips._gun_trawler:1163](../scripts\game\vehicles\vm_ships.gd#L1163)
- nets heaped on the deck beside the drum, floats through them ó [VmShips._gun_trawler:1181](../scripts\game\vehicles\vm_ships.gd#L1181)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._dshk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._surf`, `VmShips._sweep`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._whip`, `VmShips._zu23`.

### gunship

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.turbine_exhaust`, `VehicleAircraft.wire_cutter`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.autocannon`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._apache:1394](../scripts\game\vehicles\vm_core.gd#L1394)
- the stepped canopy: the gunner's low in front, the pilot's high behind, the blast shield between them; the fairing over the gearbox behind ó [VmCore._apache:1412](../scripts\game\vehicles\vm_core.gd#L1412)
- the avionics bays along the lower flanks, their access panel seams ó [VmCore._apache:1417](../scripts\game\vehicles\vm_core.gd#L1417)
- the radar warning receivers and a pitot on the nose ó [VmCore._apache:1423](../scripts\game\vehicles\vm_core.gd#L1423)
- --- the nose: the TADS drum with its two sensor heads, the PNVS above ó [VmCore._apache:1425](../scripts\game\vehicles\vm_core.gd#L1425)
- wire cutters over the canopy and under the chin ó [VmCore._apache:1437](../scripts\game\vehicles\vm_core.gd#L1437)
- --- the engines either side of the gearbox fairing: the nacelles on their pylons, the dark intakes, the exhaust suppressors turned out ó [VmCore._apache:1440](../scripts\game\vehicles\vm_core.gd#L1440)
- --- stub wings: Hellfires outboard, rocket pods inboard, rails at the tips ó [VmCore._apache:1452](../scripts\game\vehicles\vm_core.gd#L1452)
- --- the tail: the swept fin, the tail rotor on its left, the stabilator low at the back, the tailwheel under the fin ó [VmCore._apache:1463](../scripts\game\vehicles\vm_core.gd#L1463)
- --- main gear: trailing arms off the bays, the shock struts ó [VmCore._apache:1473](../scripts\game\vehicles\vm_core.gd#L1473)
- --- the M230 chain gun in its turret under the chin ó [VmCore._apache:1478](../scripts\game\vehicles\vm_core.gd#L1478)
- --- the mast, the rotor and the Longbow radar dome over it ó [VmCore._apache:1486](../scripts\game\vehicles\vm_core.gd#L1486)
- antennas along the boom ó [VmCore._apache:1493](../scripts\game\vehicles\vm_core.gd#L1493)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmHeli._canopy`, `VmHeli._hellfires`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._mx`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hatchback, hatchback_sport

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._hatch:1031](../scripts\game\vehicles\vm_civ.gd#L1031)
- glasshouse ó [VmCiv._hatch:1054](../scripts\game\vehicles\vm_civ.gd#L1054)
- the concept's panoramic glass roof ó [VmCiv._hatch:1062](../scripts\game\vehicles\vm_civ.gd#L1062)
- door shut lines: front door, rear door ó [VmCiv._hatch:1077](../scripts\game\vehicles\vm_civ.gd#L1077)
- the face: swept lamps, a slim upper grille, the wide lower intake ó [VmCiv._hatch:1083](../scripts\game\vehicles\vm_civ.gd#L1083)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._glasshouse`, `VmCiv._hatch_sport`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._xbody`.

### heli

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.pitot`, `VehicleAircraft.wire_cutter`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._blackhawk:1515](../scripts\game\vehicles\vm_core.gd#L1515)
- glazing: the two-pane windscreen, the eyebrow windows over it, the cockpit doors' windows, the gunners' windows, the cabin doors' windows ó [VmCore._blackhawk:1533](../scripts\game\vehicles\vm_core.gd#L1533)
- the frame between the windscreen panes, the door seams and the cabin door's rail, the steps ó [VmCore._blackhawk:1542](../scripts\game\vehicles\vm_core.gd#L1542)
- the nose: the radome's seam, pitots on the roof, the wire cutters ó [VmCore._blackhawk:1549](../scripts\game\vehicles\vm_core.gd#L1549)
- --- the roof: the gearbox fairing, the engines either side with their dark intakes and the exhaust suppressors turned out, the IR jammer ó [VmCore._blackhawk:1557](../scripts\game\vehicles\vm_core.gd#L1557)
- --- the mast and the rotor: swept tips, the bifilar absorber on the hub ó [VmCore._blackhawk:1573](../scripts\game\vehicles\vm_core.gd#L1573)
- --- the stores wings over the cabin's rear, braced to the floor, a fuel tank on each ó [VmCore._blackhawk:1582](../scripts\game\vehicles\vm_core.gd#L1582)
- --- the tail: the swept pylon, the canted tail rotor on its right, the stabilator, the antenna along the boom, the tailwheel ó [VmCore._blackhawk:1589](../scripts\game\vehicles\vm_core.gd#L1589)
- --- main gear: the drag beam and the shock strut to each wheel ó [VmCore._blackhawk:1608](../scripts\game\vehicles\vm_core.gd#L1608)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmCore._fuel_tank`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hellcat

**Shared:** `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleAircraft.wire_cutter`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._hellcat:925](../scripts\game\vehicles\vm_heli.gd#L925)
- glazing: windscreen, chin windows, cockpit doors; the sliding doors ó [VmHeli._hellcat:944](../scripts\game\vehicles\vm_heli.gd#L944)
- the roof fairing, engines with side exhausts, mast ó [VmHeli._hellcat:953](../scripts\game\vehicles\vm_heli.gd#L953)
- the sensor turret on the nose, pitots, wire cutters ó [VmHeli._hellcat:960](../scripts\game\vehicles\vm_heli.gd#L960)
- the tail: pylon, tail rotor on its left, tailplane on its right ó [VmHeli._hellcat:966](../scripts\game\vehicles\vm_heli.gd#L966)
- skids ó [VmHeli._hellcat:974](../scripts\game\vehicles\vm_heli.gd#L974)
- weapon pylons: a minigun inboard, a rocket pod out ó [VmHeli._hellcat:980](../scripts\game\vehicles\vm_heli.gd#L980)
- the rotor: four BERP blades on the compact hub ó [VmHeli._hellcat:992](../scripts\game\vehicles\vm_heli.gd#L992)

**Local helper construction:** `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.bumper`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._hemtt:1395](../scripts\game\vehicles\vm_nato.gd#L1395)
- drop sides and the headboard ó [VmNato._hemtt:1405](../scripts\game\vehicles\vm_nato.gd#L1405)
- the canvas tilt over its bows, the back rolled up over the benches ó [VmNato._hemtt:1414](../scripts\game\vehicles\vm_nato.gd#L1414)
- palletised crates and boxes lashed down, a tarp over one load ó [VmNato._hemtt:1428](../scripts\game\vehicles\vm_nato.gd#L1428)
- ammunition: pallets of boxes, then the knuckle-boom crane at the back, folded forward over the load ó [VmNato._hemtt:1439](../scripts\game\vehicles\vm_nato.gd#L1439)
- the shelter: a tall box body with a ribbed roof edge ó [VmNato._hemtt:1463](../scripts\game\vehicles\vm_nato.gd#L1463)
- roll-up shutters with their slats, tool lockers below ó [VmNato._hemtt:1470](../scripts\game\vehicles\vm_nato.gd#L1470)
- the light mast, AC unit, the rear door and ladder, a vice bench ó [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477)
- windows, the rear doors with a step, roof vents, red crosses ó [VmNato._hemtt:1488](../scripts\game\vehicles\vm_nato.gd#L1488)
- the tank: an oval barrel on cradles, its end caps, the walkway on top with its rail, manholes, the pump cabinet and hose reels at the back ó [VmNato._hemtt:1503](../scripts\game\vehicles\vm_nato.gd#L1503)
- the hazard placard ó [VmNato._hemtt:1518](../scripts\game\vehicles\vm_nato.gd#L1518)

**Local helper construction:** `VmNato._antenna`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_cargo_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_load_detail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### hummingbird, m900, pawnee

**Shared:** `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.skid_runner`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._little_bird:396](../scripts\game\vehicles\vm_heli.gd#L396)
- the bubble: windscreen and chin windows, one framed sheet ó [VmHeli._little_bird:417](../scripts\game\vehicles\vm_heli.gd#L417)
- doors: the pilots' (off on the military birds), the cabin's behind ó [VmHeli._little_bird:423](../scripts\game\vehicles\vm_heli.gd#L423)
- a cheat line down the flank ó [VmHeli._little_bird:429](../scripts\game\vehicles\vm_heli.gd#L429)
- seat backs, seen through the openings ó [VmHeli._little_bird:439](../scripts\game\vehicles\vm_heli.gd#L439)
- roof fairing over the mast and the engine intake behind it ó [VmHeli._little_bird:442](../scripts\game\vehicles\vm_heli.gd#L442)
- exhaust under the boom root, the boom, the tail ó [VmHeli._little_bird:448](../scripts\game\vehicles\vm_heli.gd#L448)
- beacon, antennas, pitot, the landing light ó [VmHeli._little_bird:460](../scripts\game\vehicles\vm_heli.gd#L460)
- the external personnel benches, two a side ó [VmHeli._little_bird:471](../scripts\game\vehicles\vm_heli.gd#L471)
- a grab rail over the doorway ó [VmHeli._little_bird:479](../scripts\game\vehicles\vm_heli.gd#L479)
- the weapons cross-bar under the cabin floor: minigun inboard, pod out ó [VmHeli._little_bird:482](../scripts\game\vehicles\vm_heli.gd#L482)
- the ammunition chute from the box in the cabin ó [VmHeli._little_bird:489](../scripts\game\vehicles\vm_heli.gd#L489)
- the FLIR ball under the nose ó [VmHeli._little_bird:497](../scripts\game\vehicles\vm_heli.gd#L497)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### humvee

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.receiver`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._humvee:966](../scripts\game\vehicles\vm_core.gd#L966)
- the chassis under the body: frame, the portal hub housings and the A-arms out to each wheel, the drivetrain block ó [VmCore._humvee:973](../scripts\game\vehicles\vm_core.gd#L973)
- the body: bonnet over the wings, the cab's lower half and the rear deck in one panel, the arches cut round the wheels ó [VmCore._humvee:982](../scripts\game\vehicles\vm_core.gd#L982)
- the wheels, their mud flaps ó [VmCore._humvee:987](../scripts\game\vehicles\vm_core.gd#L987)
- the bonnet: its seam and the raised middle, the rubber T-latches either side, the intake grille on the right ó [VmCore._humvee:993](../scripts\game\vehicles\vm_core.gd#L993)
- the face: the slotted grille, headlights in the wing corners, the indicators, the bumper with its winch and lifting shackles ó [VmCore._humvee:1001](../scripts\game\vehicles\vm_core.gd#L1001)
- the cab: armoured walls lofted from the belt to the roof ó [VmCore._humvee:1016](../scripts\game\vehicles\vm_core.gd#L1016)
- the split windscreen, thick armoured glass in heavy frames ó [VmCore._humvee:1025](../scripts\game\vehicles\vm_core.gd#L1025)
- the door windows, small and square; the cab's back window ó [VmCore._humvee:1028](../scripts\game\vehicles\vm_core.gd#L1028)
- the doors: heavy armoured slabs proud of the body, their seams, hinges and the big latch handles ó [VmCore._humvee:1034](../scripts\game\vehicles\vm_core.gd#L1034)
- the wing mirrors on their arms ó [VmCore._humvee:1042](../scripts\game\vehicles\vm_core.gd#L1042)
- armour over the rear deck's sides ó [VmCore._humvee:1044](../scripts\game\vehicles\vm_core.gd#L1044)
- the rear: the deck lid, tail lights in the corners, the pintle, jerrycans ó [VmCore._humvee:1047](../scripts\game\vehicles\vm_core.gd#L1047)
- --- the O-GPK turret on the roof ring ó [VmCore._humvee:1057](../scripts\game\vehicles\vm_core.gd#L1057)
- the faceted shields: three across the front, angled wings, side panels, each with its ballistic window; the back left open for the gunner ó [VmCore._humvee:1062](../scripts\game\vehicles\vm_core.gd#L1062)
- the gun slot in the front shield and the M2 through it ó [VmCore._humvee:1079](../scripts\game\vehicles\vm_core.gd#L1079)
- the ballistic glass ring over the shields on the front ó [VmCore._humvee:1083](../scripts\game\vehicles\vm_core.gd#L1083)

**Local helper construction:** `VmCiv._face`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._antenna`, `VmCore._bar`, `VmCore._bx`, `VmCore._cam`, `VmCore._jerry`, `VmCore._m2`, `VmCore._shackle`, `VmCore._taillight`.

### hunter, hunter_gmg, hunter_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._hunter:274](../scripts\game\vehicles\vm_nato.gd#L274)
- --- V-hull, engine block, suspension and the wheels ó [VmNato._hunter:280](../scripts\game\vehicles\vm_nato.gd#L280)
- --- bonnet over the engine, fenders over the front wheels, the grille ó [VmNato._hunter:290](../scripts\game\vehicles\vm_nato.gd#L290)
- the wheel arch lip and mud flap behind the front wheel ó [VmNato._hunter:296](../scripts\game\vehicles\vm_nato.gd#L296)
- the hood's centre bulge and its latches ó [VmNato._hunter:303](../scripts\game\vehicles\vm_nato.gd#L303)
- bumper with tow shackles and a recovery winch ó [VmNato._hunter:307](../scripts\game\vehicles\vm_nato.gd#L307)
- --- the crew capsule: vertical lower sides, the upper sides leaning in, a lightly raked windscreen ó [VmNato._hunter:312](../scripts\game\vehicles\vm_nato.gd#L312)
- windscreen: two small thick panes in a heavy frame ó [VmNato._hunter:318](../scripts\game\vehicles\vm_nato.gd#L318)
- doors: seams, small thick windows on the upper sides, handles, hinges ó [VmNato._hunter:322](../scripts\game\vehicles\vm_nato.gd#L322)
- the steps under the doors, the mirror on its arm ó [VmNato._hunter:334](../scripts\game\vehicles\vm_nato.gd#L334)
- stowage box low on the capsule side by the rear door ó [VmNato._hunter:338](../scripts\game\vehicles\vm_nato.gd#L338)
- the engine air intake up the right A-pillar ó [VmNato._hunter:340](../scripts\game\vehicles\vm_nato.gd#L340)
- roof: rails, antennas, the lights over the windscreen ó [VmNato._hunter:343](../scripts\game\vehicles\vm_nato.gd#L343)
- --- the cargo bed behind the capsule, fenders over the rear wheels ó [VmNato._hunter:348](../scripts\game\vehicles\vm_nato.gd#L348)
- the spare wheel on its swing-out carrier ó [VmNato._hunter:362](../scripts\game\vehicles\vm_nato.gd#L362)
- --- the roof: a remote weapon station, or the gunner's hatch closed ó [VmNato._hunter:368](../scripts\game\vehicles\vm_nato.gd#L368)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._zy`.

### huron

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.gear_leg`, `VehicleAircraft.pitot`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._huron:626](../scripts\game\vehicles\vm_heli.gd#L626)
- cockpit glazing: windscreen, chin windows, side windows; the crew door ó [VmHeli._huron:641](../scripts\game\vehicles\vm_heli.gd#L641)
- the row of small cabin windows ó [VmHeli._huron:652](../scripts\game\vehicles\vm_heli.gd#L652)
- the ramp: hinge line, its edges under the tail, the door in the back ó [VmHeli._huron:656](../scripts\game\vehicles\vm_heli.gd#L656)
- fuel sponsons down the flanks ó [VmHeli._huron:663](../scripts\game\vehicles\vm_heli.gd#L663)
- the gear: two wheels forward of the sponsons, two under their tails ó [VmHeli._huron:677](../scripts\game\vehicles\vm_heli.gd#L677)
- steps, lights, the rescue hoist over the door ó [VmHeli._huron:681](../scripts\game\vehicles\vm_heli.gd#L681)
- cargo hooks, the FLIR ball, pitots ó [VmHeli._huron:686](../scripts\game\vehicles\vm_heli.gd#L686)
- forward pylon, the shaft tunnel, the tall aft pylon with its engines ó [VmHeli._huron:693](../scripts\game\vehicles\vm_heli.gd#L693)
- masts, antennas, beacons ó [VmHeli._huron:710](../scripts\game\vehicles\vm_heli.gd#L710)
- the rotors: three-blade, contra-rotating, the aft one higher ó [VmHeli._huron:717](../scripts\game\vehicles\vm_heli.gd#L717)

**Local helper construction:** `VmHeli._air`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._tube`.

### ifrit, ifrit_gmg, ifrit_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._ifrit:234](../scripts\game\vehicles\vm_csat.gd#L234)
- the V-shaped belly between the wheels ó [VmCsat._ifrit:236](../scripts\game\vehicles\vm_csat.gd#L236)
- the faceted body: nose, bonnet, windscreen, cabin, rear face ó [VmCsat._ifrit:238](../scripts\game\vehicles\vm_csat.gd#L238)
- the lower nose (grille and bumper) and the tail below the rear door ó [VmCsat._ifrit:247](../scripts\game\vehicles\vm_csat.gd#L247)
- the door sills between the wheels, their ends cut to the arches ó [VmCsat._ifrit:250](../scripts\game\vehicles\vm_csat.gd#L250)
- a raised panel down the bonnet and the air intake grille before the screen ó [VmCsat._ifrit:255](../scripts\game\vehicles\vm_csat.gd#L255)
- the windscreen: two small panes in the raked front of the cabin ó [VmCsat._ifrit:260](../scripts\game\vehicles\vm_csat.gd#L260)
- A-pillar cover strips on the screen's facets ó [VmCsat._ifrit:265](../scripts\game\vehicles\vm_csat.gd#L265)
- side windows, door seams and handles, the doors' steps ó [VmCsat._ifrit:268](../scripts\game\vehicles\vm_csat.gd#L268)
- mirrors on stalks at the screen's base ó [VmCsat._ifrit:281](../scripts\game\vehicles\vm_csat.gd#L281)
- angular arches over the wheels and mud flaps behind them ó [VmCsat._ifrit:283](../scripts\game\vehicles\vm_csat.gd#L283)
- headlight clusters in the wings, rear lights, tow hooks ó [VmCsat._ifrit:288](../scripts\game\vehicles\vm_csat.gd#L288)
- whip antennas at the rear roof corners ó [VmCsat._ifrit:292](../scripts\game\vehicles\vm_csat.gd#L292)
- the grille, the bumper ó [VmCsat._ifrit:294](../scripts\game\vehicles\vm_csat.gd#L294)
- the rear: the door with its window and hinges, the spare wheel, the step ó [VmCsat._ifrit:299](../scripts\game\vehicles\vm_csat.gd#L299)
- roof: rails, the hatch or the weapon station ó [VmCsat._ifrit:310](../scripts\game\vehicles\vm_csat.gd#L310)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._mx`, `VmCsat._pane`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`.

### ifv

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._bradley:1232](../scripts\game\vehicles\vm_core.gd#L1232)
- running gear: front sprocket, six road wheels, rear idler ó [VmCore._bradley:1235](../scripts\game\vehicles\vm_core.gd#L1235)
- the hull: the belly with the steep lower nose, the upper hull out over the tracks with the long upper glacis ó [VmCore._bradley:1254](../scripts\game\vehicles\vm_core.gd#L1254)
- the glacis: its armour plate with the bolt rows, the driver's hatch and periscopes front left, the engine access and grilles front right ó [VmCore._bradley:1265](../scripts\game\vehicles\vm_core.gd#L1265)
- the exhaust on the right of the nose, lights in guards, tow hooks ó [VmCore._bradley:1279](../scripts\game\vehicles\vm_core.gd#L1279)
- the sides: the appliqu√© armour tiles with their bolts, the skirts under them, the grab rail ó [VmCore._bradley:1285](../scripts\game\vehicles\vm_core.gd#L1285)
- the roof: the troop compartment's long cargo hatch hinged at its back edge, vision blocks ó [VmCore._bradley:1301](../scripts\game\vehicles\vm_core.gd#L1301)
- the rear: the big ramp with its door, hinges, stowage boxes either side, tail lights, a water can and kit ó [VmCore._bradley:1307](../scripts\game\vehicles\vm_core.gd#L1307)
- --- the turret ó [VmCore._bradley:1323](../scripts\game\vehicles\vm_core.gd#L1323)
- the spaced armour on the turret's front faces ó [VmCore._bradley:1331](../scripts\game\vehicles\vm_core.gd#L1331)
- the 25 mm in its mantlet, the coax to its right ó [VmCore._bradley:1338](../scripts\game\vehicles\vm_core.gd#L1338)
- the TOW launcher box on its arm on the left ó [VmCore._bradley:1344](../scripts\game\vehicles\vm_core.gd#L1344)
- the IBAS sight head front left under its raised armoured door, the CIV on its column on the right, the hatches ó [VmCore._bradley:1350](../scripts\game\vehicles\vm_core.gd#L1350)
- the stowage basket round the back, bags and a bedroll in it ó [VmCore._bradley:1360](../scripts\game\vehicles\vm_core.gd#L1360)

**Local helper construction:** `VmCore._antenna`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._oct`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._zy`.

### jet

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.pitot`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmFighter._f16:694](../scripts\game\vehicles\vm_fighter.gd#L694)
- --- fuselage: radome, the round body, strakes flaring into the wing root [s, crown, keel, half-width, strake edge's half-span, its height] ó [VmFighter._f16:705](../scripts\game\vehicles\vm_fighter.gd#L705)
- the cockpit sill the canopy sits on, the dorsal spine behind it ó [VmFighter._f16:724](../scripts\game\vehicles\vm_fighter.gd#L724)
- the frameless bubble canopy (its bow behind the seat), the sill rails ó [VmFighter._f16:730](../scripts\game\vehicles\vm_fighter.gd#L730)
- --- the ventral intake: a hollow raked mouth, the splitter above it, the duct fairing running back under the fuselage ó [VmFighter._f16:739](../scripts\game\vehicles\vm_fighter.gd#L739)
- --- wing: leading-edge flaps the full span, flaperons inboard ó [VmFighter._f16:749](../scripts\game\vehicles\vm_fighter.gd#L749)
- all-moving tailerons, 10 degrees down ó [VmFighter._f16:755](../scripts\game\vehicles\vm_fighter.gd#L755)
- the fin with its rudder, the squadron band round its tip, the base housing behind it, the antenna cap ó [VmFighter._f16:758](../scripts\game\vehicles\vm_fighter.gd#L758)
- ventral fins, canted out under the strake shelves ó [VmFighter._f16:767](../scripts\game\vehicles\vm_fighter.gd#L767)
- split speedbrakes at the ends of the strake shelves ó [VmFighter._f16:772](../scripts\game\vehicles\vm_fighter.gd#L772)
- --- the F110's nozzle: actuator ring, petals, the pipe inside ó [VmFighter._f16:777](../scripts\game\vehicles\vm_fighter.gd#L777)
- --- details: pitot, AOA probes, IFF "bird slicers", the gun, refuelling receptacle, antennas, lights ó [VmFighter._f16:784](../scripts\game\vehicles\vm_fighter.gd#L784)
- formation strip lights: nose sides, fin ó [VmFighter._f16:803](../scripts\game\vehicles\vm_fighter.gd#L803)
- --- panel lines: control-surface hinge lines are gaps; these are the access panels and the gear doors (closed flush) ó [VmFighter._f16:812](../scripts\game\vehicles\vm_fighter.gd#L812)
- --- stores ó [VmFighter._f16:826](../scripts\game\vehicles\vm_fighter.gd#L826)
- the tip launcher and its AMRAAM ó [VmFighter._f16:842](../scripts\game\vehicles\vm_fighter.gd#L842)
- Sniper pod on the right intake station, the ALQ-184 on the centreline ó [VmFighter._f16:847](../scripts\game\vehicles\vm_fighter.gd#L847)
- --- markings: low-vis star-and-bar on the intake and the wings, the wing's tail code and serial on the fin ó [VmFighter._f16:852](../scripts\game\vehicles\vm_fighter.gd#L852)
- --- landing gear (shown on the ground): the short nose leg behind the intake, the main legs splayed out from under the strakes, open doors ó [VmFighter._f16:866](../scripts\game\vehicles\vm_fighter.gd#L866)
- the main door hangs from the strake outboard of the well ó [VmFighter._f16:885](../scripts\game\vehicles\vm_fighter.gd#L885)

**Local helper construction:** `VmFighter._aim120`, `VmFighter._aim9x`, `VmFighter._alq184`, `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._f16_half`, `VmFighter._ft`, `VmFighter._gbu31`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hband`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._mesh`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._pipe`, `VmFighter._poly_mesh`, `VmFighter._project`, `VmFighter._put`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._sniper`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### kajman

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWeapons.autocannon`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._kajman:1042](../scripts\game\vehicles\vm_heli.gd#L1042)
- the stepped cockpits: the gunner low in front, the pilot high behind ó [VmHeli._kajman:1064](../scripts\game\vehicles\vm_heli.gd#L1064)
- the cabin: split doors with a window in the upper half, side windows ó [VmHeli._kajman:1068](../scripts\game\vehicles\vm_heli.gd#L1068)
- the nose sensors ó [VmHeli._kajman:1076](../scripts\game\vehicles\vm_heli.gd#L1076)
- top fairing, the engines with their dust filters and exhaust deflectors ó [VmHeli._kajman:1081](../scripts\game\vehicles\vm_heli.gd#L1081)
- the dust protector: a cone ahead of a dark annular intake ó [VmHeli._kajman:1090](../scripts\game\vehicles\vm_heli.gd#L1090)
- the coaxial mast: the swashplate guide at its foot, the separator between the two rotors ó [VmHeli._kajman:1095](../scripts\game\vehicles\vm_heli.gd#L1095)
- stub wings: anhedral, three pylons a side, flare pods at the tips ó [VmHeli._kajman:1098](../scripts\game\vehicles\vm_heli.gd#L1098)
- main gear on trailing legs ó [VmHeli._kajman:1112](../scripts\game\vehicles\vm_heli.gd#L1112)
- the tail: a swept fin, the stabiliser with endplate fins, the tailwheel ó [VmHeli._kajman:1118](../scripts\game\vehicles\vm_heli.gd#L1118)
- the chin turret: 2A42 30 mm with its ammunition boxes either side ó [VmHeli._kajman:1128](../scripts\game\vehicles\vm_heli.gd#L1128)
- the cannon: its recoil sleeve out of the gun box, the barrel, the brake ó [VmHeli._kajman:1135](../scripts\game\vehicles\vm_heli.gd#L1135)
- the coaxial rotors: three blades each, the upper one turning the other way ó [VmHeli._kajman:1138](../scripts\game\vehicles\vm_heli.gd#L1138)

**Local helper construction:** `VmHeli._atgm_tubes`, `VmHeli._canopy`, `VmHeli._hull`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tube`.

### kamysh

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._kamysh:699](../scripts\game\vehicles\vm_csat.gd#L699)
- the bustle box at the back ó [VmCsat._kamysh:705](../scripts\game\vehicles\vm_csat.gd#L705)
- mantlet, the 30 mm with its barrel jacket and muzzle brake, the coax ó [VmCsat._kamysh:707](../scripts\game\vehicles\vm_csat.gd#L707)
- the gunner's sight head (front left) and the commander's panoramic sight ó [VmCsat._kamysh:712](../scripts\game\vehicles\vm_csat.gd#L712)
- the twin Titan launchers on arms either side, smoke dischargers behind ó [VmCsat._kamysh:715](../scripts\game\vehicles\vm_csat.gd#L715)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### kart

**Shared:** `VehicleBody.paint_mesh`, `VehicleCab.steering_wheel`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._kart:1257](../scripts\game\vehicles\vm_civ.gd#L1257)
- the frame: two main rails, cross members, the front stubs ó [VmCiv._kart:1267](../scripts\game\vehicles\vm_civ.gd#L1267)
- nose fairing, front panel, pods in the livery ó [VmCiv._kart:1281](../scripts\game\vehicles\vm_civ.gd#L1281)
- seat, steering wheel and column, pedals ó [VmCiv._kart:1299](../scripts\game\vehicles\vm_civ.gd#L1299)
- the two-stroke to the right of the seat, its airbox and silencer ó [VmCiv._kart:1308](../scripts\game\vehicles\vm_civ.gd#L1308)
- rear bumper and its plate ó [VmCiv._kart:1316](../scripts\game\vehicles\vm_civ.gd#L1316)

**Local helper construction:** `VmCiv._bent`, `VmCiv._rod`.

### kuma

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.grille`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._kuma:441](../scripts\game\vehicles\vm_indep.gd#L441)
- running gear: front idler, seven road wheels, rear sprocket, four rollers ó [VmIndep._kuma:445](../scripts\game\vehicles\vm_indep.gd#L445)
- hull: the belly between the tracks (the lower glacis its front), the upper hull out over the tracks with the long shallow upper glacis ó [VmIndep._kuma:451](../scripts\game\vehicles\vm_indep.gd#L451)
- a bolted add-on plate over the glacis, the driver's hatch front-right ó [VmIndep._kuma:457](../scripts\game\vehicles\vm_indep.gd#L457)
- headlight clusters with guards on the front corners, tow eyes ó [VmIndep._kuma:463](../scripts\game\vehicles\vm_indep.gd#L463)
- skirts: three heavy armour modules forward, three light panels aft, the bow panel raked ó [VmIndep._kuma:466](../scripts\game\vehicles\vm_indep.gd#L466)
- the hull's sides: a stowage box and the tool rack above the skirts ó [VmIndep._kuma:475](../scripts\game\vehicles\vm_indep.gd#L475)
- engine deck grilles either side of the centre access panel ó [VmIndep._kuma:478](../scripts\game\vehicles\vm_indep.gd#L478)
- rear: tail lights, tow eyes ó [VmIndep._kuma:482](../scripts\game\vehicles\vm_indep.gd#L482)
- the exhaust louvres across the top of the rear plate, the slat cage standing off the back on its struts ó [VmIndep._kuma:486](../scripts\game\vehicles\vm_indep.gd#L486)
- the turret, its front cheeks just behind the glacis ó [VmIndep._kuma:494](../scripts\game\vehicles\vm_indep.gd#L494)
- bolt-on armour: flat slabs on the cheeks either side of the mantlet and along the sides ó [VmIndep._kuma:501](../scripts\game\vehicles\vm_indep.gd#L501)
- smoke dischargers: a group of four on each side, aft ó [VmIndep._kuma:514](../scripts\game\vehicles\vm_indep.gd#L514)
- the gun: mantlet, thermal sleeve, fume extractor, muzzle reference sensor ó [VmIndep._kuma:517](../scripts\game\vehicles\vm_indep.gd#L517)
- the coaxial MG left of the gun ó [VmIndep._kuma:525](../scripts\game\vehicles\vm_indep.gd#L525)
- roof: the EMES gunner's sight doghouse front-right, the PERI periscope behind it, the commander's and loader's hatches, the wind sensor ó [VmIndep._kuma:528](../scripts\game\vehicles\vm_indep.gd#L528)
- the bustle's stowage basket, the slat cage round it on its struts ó [VmIndep._kuma:540](../scripts\game\vehicles\vm_indep.gd#L540)
- a remote .50 over the loader's hatch ó [VmIndep._kuma:549](../scripts\game\vehicles\vm_indep.gd#L549)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._slats`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### m35

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleCargo.sideboard`, `VehicleDoors.leaf`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.headlamp`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._truck:1625](../scripts\game\vehicles\vm_core.gd#L1625)
- the chassis: frame rails, the axles and their diffs, the wheels ó [VmCore._truck:1629](../scripts\game\vehicles\vm_core.gd#L1629)
- the bonnet, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks ó [VmCore._truck:1636](../scripts\game\vehicles\vm_core.gd#L1636)
- the louvres down the bonnet's sides ó [VmCore._truck:1647](../scripts\game\vehicles\vm_core.gd#L1647)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms ó [VmCore._truck:1654](../scripts\game\vehicles\vm_core.gd#L1654)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box ó [VmCore._truck:1669](../scripts\game\vehicles\vm_core.gd#L1669)
- the cargo bed: floor, sides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle ó [VmCore._truck:1673](../scripts\game\vehicles\vm_core.gd#L1673)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._path`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmNato._spare`.

### marid

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.light_guard`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._marid:543](../scripts\game\vehicles\vm_csat.gd#L543)
- the glacis plane (for things mounted on it) ó [VmCsat._marid:552](../scripts\game\vehicles\vm_csat.gd#L552)
- the driver's windows at the top of the glacis, front left, and his hatch ó [VmCsat._marid:555](../scripts\game\vehicles\vm_csat.gd#L555)
- the engine's louvres on the right of the glacis, exhaust on the right side ó [VmCsat._marid:562](../scripts\game\vehicles\vm_csat.gd#L562)
- headlight clusters and tow hooks on the nose, smoke dischargers ó [VmCsat._marid:566](../scripts\game\vehicles\vm_csat.gd#L566)
- the wheels on three evenly spaced axles, mud flaps ó [VmCsat._marid:571](../scripts\game\vehicles\vm_csat.gd#L571)
- the crease's side: vision blocks and firing ports along the troop compartment, stowage boxes, the exhaust ó [VmCsat._marid:576](../scripts\game\vehicles\vm_csat.gd#L576)
- grab rails along the roof edge ó [VmCsat._marid:587](../scripts\game\vehicles\vm_csat.gd#L587)
- rear: the ramp with its door, hinges, water jets, lights, stowage ó [VmCsat._marid:590](../scripts\game\vehicles\vm_csat.gd#L590)
- roof: the troop compartment's hatches, a stowage basket ó [VmCsat._marid:605](../scripts\game\vehicles\vm_csat.gd#L605)
- twin remote weapon stations on one ring: the 12.7 mm on the left, the 40 mm on the right, the sight head between them ó [VmCsat._marid:612](../scripts\game\vehicles\vm_csat.gd#L612)
- 12.7 mm, left, and 40 mm, right, each with its ammunition on the outboard side ó [VmCsat._marid:622](../scripts\game\vehicles\vm_csat.gd#L622)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._jerrycan`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._taillight`, `VmCsat._tow`.

### marshall

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._marshall:518](../scripts\game\vehicles\vm_nato.gd#L518)
- lower hull between the wheels; the nose and tail blocks full width ó [VmNato._marshall:523](../scripts\game\vehicles\vm_nato.gd#L523)
- the upper hull: a vertical band over the wheels, then the sides leaning in ó [VmNato._marshall:527](../scripts\game\vehicles\vm_nato.gd#L527)
- wheel wells: dark liners under the overhang over each wheel ó [VmNato._marshall:532](../scripts\game\vehicles\vm_nato.gd#L532)
- glacis: the trim vane folded flat, the driver's hatch and periscopes, the engine deck grilles on the right, lights and tow eyes on the nose ó [VmNato._marshall:536](../scripts\game\vehicles\vm_nato.gd#L536)
- exhaust grille on the right side, forward ó [VmNato._marshall:553](../scripts\game\vehicles\vm_nato.gd#L553)
- side details: stowage bins on the sloping sides, the hull door seams, vision blocks, a tow cable ó [VmNato._marshall:555](../scripts\game\vehicles\vm_nato.gd#L555)
- roof over the troop compartment: two hatches, periscopes ó [VmNato._marshall:565](../scripts\game\vehicles\vm_nato.gd#L565)
- the rear: ramp with its door, hinges, lights, steps ó [VmNato._marshall:570](../scripts\game\vehicles\vm_nato.gd#L570)
- --- the turret: low and faceted, the 40 mm, smoke dischargers, the commander's panoramic sight on its mast ó [VmNato._marshall:581](../scripts\game\vehicles\vm_nato.gd#L581)
- gun: the mantlet, the barrel with its recoil sleeve, the muzzle brake ó [VmNato._marshall:589](../scripts\game\vehicles\vm_nato.gd#L589)
- coaxial MG port beside the mantlet ó [VmNato._marshall:593](../scripts\game\vehicles\vm_nato.gd#L593)
- sights: gunner's forward left, the commander's panoramic sight on a mast ó [VmNato._marshall:595](../scripts\game\vehicles\vm_nato.gd#L595)
- hatches, smoke dischargers, bustle stowage, antenna ó [VmNato._marshall:598](../scripts\game\vehicles\vm_nato.gd#L598)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._zy`.

### mb4wd, mb4wd_at, mb4wd_lmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.dashboard`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.receiver`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.mmg`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._mb4wd:488](../scripts\game\vehicles\vm_civ.gd#L488)
- frame, wells, axles (solid beam axles front and rear), the skid plate ó [VmCiv._mb4wd:496](../scripts\game\vehicles\vm_civ.gd#L496)
- the tub: a floor pan with the arches cut out, walls standing on it ó [VmCiv._mb4wd:504](../scripts\game\vehicles\vm_civ.gd#L504)
- bonnet over a narrow engine bay, then the flat-topped wings with flares ó [VmCiv._mb4wd:510](../scripts\game\vehicles\vm_civ.gd#L510)
- hood latches, indicator on the wing, exposed hinges, the door's shut lines and handle, a black mirror, rock rails ó [VmCiv._mb4wd:520](../scripts\game\vehicles\vm_civ.gd#L520)
- square tail lights on the rear corners ó [VmCiv._mb4wd:532](../scripts\game\vehicles\vm_civ.gd#L532)
- the face: seven slots between round headlights, bumper with tow hooks ó [VmCiv._mb4wd:535](../scripts\game\vehicles\vm_civ.gd#L535)
- windscreen: an upright frame folding on the cowl, wipers ó [VmCiv._mb4wd:550](../scripts\game\vehicles\vm_civ.gd#L550)
- inside: dash, the wheel (left-hand drive), two buckets and a bench ó [VmCiv._mb4wd:563](../scripts\game\vehicles\vm_civ.gd#L563)
- the sport bar: a hoop behind the front seats, rails to the windscreen and down to the rear corners, padded ó [VmCiv._mb4wd:571](../scripts\game\vehicles\vm_civ.gd#L571)
- rear: spare wheel on the tailgate, bumper, plate, third light ó [VmCiv._mb4wd:579](../scripts\game\vehicles\vm_civ.gd#L579)

**Local helper construction:** `VmCiv._bent`, `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._lamp`, `VmCiv._lmg`, `VmCiv._mb_gun`, `VmCiv._mb_top`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCiv._zring`.

### mohawk

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.gear_leg`, `VehicleAircraft.pitot`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radome`, `VehicleProfiles.loft`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._mohawk:824](../scripts\game\vehicles\vm_heli.gd#L824)
- the olive upper half of the scheme ó [VmHeli._mohawk:843](../scripts\game\vehicles\vm_heli.gd#L843)
- the cockpit: windscreen, chin windows, side windows ó [VmHeli._mohawk:845](../scripts\game\vehicles\vm_heli.gd#L845)
- the cabin door (right, forward), windows down both sides ó [VmHeli._mohawk:851](../scripts\game\vehicles\vm_heli.gd#L851)
- the ramp: hinge line, its edges ó [VmHeli._mohawk:858](../scripts\game\vehicles\vm_heli.gd#L858)
- sponsons with the twin-wheel main gear, the twin nosewheel ó [VmHeli._mohawk:862](../scripts\game\vehicles\vm_heli.gd#L862)
- the hoist over the door, the radome, pitots ó [VmHeli._mohawk:878](../scripts\game\vehicles\vm_heli.gd#L878)
- the roof: gearbox fairing, three engines, their intakes and exhausts ó [VmHeli._mohawk:884](../scripts\game\vehicles\vm_heli.gd#L884)
- mast, the IR jammer, antennas ó [VmHeli._mohawk:899](../scripts\game\vehicles\vm_heli.gd#L899)
- the tail pylon, the tail rotor on its left, the tailplane on its right ó [VmHeli._mohawk:904](../scripts\game\vehicles\vm_heli.gd#L904)
- the rotor: five BERP blades ó [VmHeli._mohawk:911](../scripts\game\vehicles\vm_heli.gd#L911)

**Local helper construction:** `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### mora

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.grille`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.autocannon`, `VehicleWeapons.coax`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._mora:343](../scripts\game\vehicles\vm_indep.gd#L343)
- running gear: front sprocket, six road wheels, rear idler, three rollers ó [VmIndep._mora:347](../scripts\game\vehicles\vm_indep.gd#L347)
- the hull: belly between the tracks, the upper hull out over them with the long glacis ó [VmIndep._mora:353](../scripts\game\vehicles\vm_indep.gd#L353)
- skirts: five bolted panels a side, the front one raked ó [VmIndep._mora:357](../scripts\game\vehicles\vm_indep.gd#L357)
- the hull's side seam at the deck line, a stowage box aft ó [VmIndep._mora:363](../scripts\game\vehicles\vm_indep.gd#L363)
- headlight clusters in guards on the glacis corners, tow hooks ó [VmIndep._mora:366](../scripts\game\vehicles\vm_indep.gd#L366)
- glacis: the driver's hatch and vision blocks front-left, the engine louvres front-right, lifting eyes ó [VmIndep._mora:369](../scripts\game\vehicles\vm_indep.gd#L369)
- exhaust: the louvred outlet on the right flank, forward ó [VmIndep._mora:384](../scripts\game\vehicles\vm_indep.gd#L384)
- roof: the troop compartment's long hatch, a vent, antennas at the back ó [VmIndep._mora:386](../scripts\game\vehicles\vm_indep.gd#L386)
- rear: the big door with its vision block and handles, a stowage bin either side of it, tail lights, the tow pintle ó [VmIndep._mora:390](../scripts\game\vehicles\vm_indep.gd#L390)
- the turret: faceted, the RARDEN in its narrow mantlet, the chain gun beside it, sights and hatches on the roof ó [VmIndep._mora:405](../scripts\game\vehicles\vm_indep.gd#L405)
- gunner's sight left, the commander's sight right, two hatches ó [VmIndep._mora:417](../scripts\game\vehicles\vm_indep.gd#L417)
- four-barrel smoke dischargers on the front corners ó [VmIndep._mora:423](../scripts\game\vehicles\vm_indep.gd#L423)
- the bustle: a stowage basket with a rolled tarp and kit in it ó [VmIndep._mora:426](../scripts\game\vehicles\vm_indep.gd#L426)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### motorboat

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._motorboat:522](../scripts\game\vehicles\vm_boat.gd#L522)
- topsides round the cockpit, in two runs so they keep the chine ó [VmBoat._motorboat:539](../scripts\game\vehicles\vm_boat.gd#L539)
- the stripe, the rub rail under the sheer, spray rails on the bottom ó [VmBoat._motorboat:549](../scripts\game\vehicles\vm_boat.gd#L549)
- the transom above the sole, notched for the motor, and the splash well ó [VmBoat._motorboat:574](../scripts\game\vehicles\vm_boat.gd#L574)
- the stern bench in front of it ó [VmBoat._motorboat:582](../scripts\game\vehicles\vm_boat.gd#L582)
- the centre console: a sloped dash, a wrap windscreen, wheel and throttle ó [VmBoat._motorboat:586](../scripts\game\vehicles\vm_boat.gd#L586)
- the windscreen: a raked front pane and two side wings, framed, a grab rail on top ó [VmBoat._motorboat:590](../scripts\game\vehicles\vm_boat.gd#L590)
- a seat on a cool box in front of the console, the helm bench behind it ó [VmBoat._motorboat:606](../scripts\game\vehicles\vm_boat.gd#L606)
- the bow rail on its stanchions ó [VmBoat._motorboat:615](../scripts\game\vehicles\vm_boat.gd#L615)
- cleats, a bow navigation light, the stern light's pole ó [VmBoat._motorboat:632](../scripts\game\vehicles\vm_boat.gd#L632)
- a non-skid sole between the topsides ó [VmBoat._motorboat:646](../scripts\game\vehicles\vm_boat.gd#L646)
- two fenders stowed on the sole, a VHF whip on the console ó [VmBoat._motorboat:652](../scripts\game\vehicles\vm_boat.gd#L652)
- the bow eye and the registration number on both bows ó [VmBoat._motorboat:660](../scripts\game\vehicles\vm_boat.gd#L660)
- 115 hp outboard on the transom notch ó [VmBoat._motorboat:672](../scripts\game\vehicles\vm_boat.gd#L672)

**Local helper construction:** `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._slab`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### neophron

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._neophron:1030](../scripts\game\vehicles\vm_plane.gd#L1030)
- engine nacelles under the wing-root extensions, intakes raked back ó [VmPlane._neophron:1056](../scripts\game\vehicles\vm_plane.gd#L1056)
- LERX into the shoulder wing, the fin and the stabilators ó [VmPlane._neophron:1065](../scripts\game\vehicles\vm_plane.gd#L1065)
- tip rails with R-73s, lights, probes, antennas ó [VmPlane._neophron:1071](../scripts\game\vehicles\vm_plane.gd#L1071)
- stores: the gun pod; bombs, B-8 rocket pods and R-73s underwing ó [VmPlane._neophron:1079](../scripts\game\vehicles\vm_plane.gd#L1079)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### nyx_aa, nyx_ac, nyx_at, nyx_recon

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.exhaust`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.radar_array`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.autocannon`, `VehicleWeapons.hmg`, `VehicleWeapons.launch_tube`, `VehicleWheels.ring`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._nyx:563](../scripts\game\vehicles\vm_indep.gd#L563)
- hull: the belly between the tracks, the upper hull over them with the long glacis ó [VmIndep._nyx:569](../scripts\game\vehicles\vm_indep.gd#L569)
- the driver's hatch and periscopes front-left, the engine grille on the glacis front-right, the exhaust on the right flank ó [VmIndep._nyx:575](../scripts\game\vehicles\vm_indep.gd#L575)
- headlights with guards on the glacis corners, tow eyes, smoke dischargers on the roof's front corners ó [VmIndep._nyx:586](../scripts\game\vehicles\vm_indep.gd#L586)
- a stowage box on each flank aft, tail lights, a jerrycan ó [VmIndep._nyx:591](../scripts\game\vehicles\vm_indep.gd#L591)
- rear: the crew door and its handle, the tow pintle, a jerrycan rack ó [VmIndep._nyx:594](../scripts\game\vehicles\vm_indep.gd#L594)
- the periscope mast, extended, at the back left ó [VmIndep._nyx:603](../scripts\game\vehicles\vm_indep.gd#L603)
- the radar: a flat array on a turning pedestal over its electronics ó [VmIndep._nyx:609](../scripts\game\vehicles\vm_indep.gd#L609)
- the weapon mount: a low armoured turntable at the back of the roof ó [VmIndep._nyx:619](../scripts\game\vehicles\vm_indep.gd#L619)
- the Rh 202 in its cradle on top, ammunition boxes either side, a sight ó [VmIndep._nyx:626](../scripts\game\vehicles\vm_indep.gd#L626)
- a twin launcher for the fire-and-forget missiles on the left, a sight head in the middle, the .50 on the right ó [VmIndep._nyx:636](../scripts\game\vehicles\vm_indep.gd#L636)
- two four-round pods either side of the sight head, the .50 under the left one ó [VmIndep._nyx:647](../scripts\game\vehicles\vm_indep.gd#L647)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._nyx_m2`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### offroad, offroad_at, offroad_hmg, offroad_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCargo.sideboard`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.jerrycan`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleMounts.receiver`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWeapons.hmg`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._offroad:268](../scripts\game\vehicles\vm_civ.gd#L268)
- ladder frame, the wells behind the wheels, axles and diffs, exhaust ó [VmCiv._offroad:275](../scripts\game\vehicles\vm_civ.gd#L275)
- the cab and front wings in one panel, the nose a loft with its corners rounded off for the headlights to wrap round, the bed separate ó [VmCiv._offroad:284](../scripts\game\vehicles\vm_civ.gd#L284)
- the black lower lip and the intake under the grille ó [VmCiv._offroad:309](../scripts\game\vehicles\vm_civ.gd#L309)
- bed: walls on the tub, a ribbed liner, wheel tubs, the tailgate ó [VmCiv._offroad:313](../scripts\game\vehicles\vm_civ.gd#L313)
- glasshouse: windscreen raked hard back, a short cab with its back window ó [VmCiv._offroad:324](../scripts\game\vehicles\vm_civ.gd#L324)
- doors: shut lines, handles, mirrors; side steps under them ó [VmCiv._offroad:333](../scripts\game\vehicles\vm_civ.gd#L333)
- flared arches in black plastic ó [VmCiv._offroad:345](../scripts\game\vehicles\vm_civ.gd#L345)
- tall tail lights on the bed corners ó [VmCiv._offroad:350](../scripts\game\vehicles\vm_civ.gd#L350)
- fuel filler on the bed side ó [VmCiv._offroad:353](../scripts\game\vehicles\vm_civ.gd#L353)
- the face: the tall single-frame grille in a bright surround, slats, plate ó [VmCiv._offroad:355](../scripts\game\vehicles\vm_civ.gd#L355)
- wipers, aerial ó [VmCiv._offroad:368](../scripts\game\vehicles\vm_civ.gd#L368)
- rear: step bumper, plate, tow ball ó [VmCiv._offroad:372](../scripts\game\vehicles\vm_civ.gd#L372)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._inset`, `VmCiv._jerrycan`, `VmCiv._lamp`, `VmCiv._m2`, `VmCiv._mirror`, `VmCiv._off_at`, `VmCiv._off_hmg`, `VmCiv._off_repair`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCiv._zring`.

### old_tank

**Shared:** `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lifting_eye`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.coax`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._t55:530](../scripts\game\vehicles\vm_core.gd#L530)
- --- running gear: front idler, five road wheels (the gap after the first), rear sprocket; the track sagging onto the wheels ó [VmCore._t55:534](../scripts\game\vehicles\vm_core.gd#L534)
- one road wheel a replacement, still in its old green ó [VmCore._t55:545](../scripts\game\vehicles\vm_core.gd#L545)
- --- the hull: the belly between the tracks with the lower glacis, the upper hull over the tracks, the glacis rising at 60 degrees ó [VmCore._t55:554](../scripts\game\vehicles\vm_core.gd#L554)
- the splash board: a V across the glacis, its point forward ó [VmCore._t55:565](../scripts\game\vehicles\vm_core.gd#L565)
- spare track links bolted across the glacis below it, tow hooks under the nose ó [VmCore._t55:572](../scripts\game\vehicles\vm_core.gd#L572)
- the driver's hatch front left and his two periscopes, the lights on the glacis corners: the headlight and the IR driving light on the left (its lens long gone), one headlight on the right ó [VmCore._t55:578](../scripts\game\vehicles\vm_core.gd#L578)
- --- fenders: thin shelves the full length over the tracks with a lip down their outer edge, on brackets, the front mudguards angled down (the left one bent up), the rear ones ó [VmCore._t55:595](../scripts\game\vehicles\vm_core.gd#L595)
- the right fender: three external fuel tanks (dented, one streaked with rust), a stowage box forward; their straps and pipes ó [VmCore._t55:606](../scripts\game\vehicles\vm_core.gd#L606)
- the left fender: stowage boxes, the spare parts box, the oil tank; the exhaust louvre on the hull side above it, sooted round ó [VmCore._t55:620](../scripts\game\vehicles\vm_core.gd#L620)
- rust streaks down the hull sides and the glacis corners ó [VmCore._t55:630](../scripts\game\vehicles\vm_core.gd#L630)
- --- the engine deck: the louvred grilles, the access plates, the radiator grille across the back ó [VmCore._t55:633](../scripts\game\vehicles\vm_core.gd#L633)
- --- the rear: the sloped plate, the two 200-litre drums on their brackets (one rust-brown, one green), the unditching log under them, tail lights, tow hooks ó [VmCore._t55:642](../scripts\game\vehicles\vm_core.gd#L642)
- --- the turret: the cast dome ó [VmCore._t55:662](../scripts\game\vehicles\vm_core.gd#L662)
- the cast mantlet in the dome's front and the canvas boot over the gun ó [VmCore._t55:675](../scripts\game\vehicles\vm_core.gd#L675)
- the 100 mm: the long tapering barrel, the fume extractor near the muzzle ó [VmCore._t55:682](../scripts\game\vehicles\vm_core.gd#L682)
- the coaxial PKT's port right of the gun ó [VmCore._t55:686](../scripts\game\vehicles\vm_core.gd#L686)
- the L-2 IR searchlight on its bracket to the right of the gun ó [VmCore._t55:689](../scripts\game\vehicles\vm_core.gd#L689)
- the gunner's sight port front left, the ventilator dome front right ó [VmCore._t55:696](../scripts\game\vehicles\vm_core.gd#L696)
- the commander's cupola on the left with its vision blocks and the small IR spotlight, the loader's hatch on the right with the DShK on its ring ó [VmCore._t55:700](../scripts\game\vehicles\vm_core.gd#L700)
- grab rails round the dome, the snorkel stowed across the back, a rolled tarpaulin, lifting eyes ó [VmCore._t55:715](../scripts\game\vehicles\vm_core.gd#L715)
- rust round the cupola and a streak down the dome's flank ó [VmCore._t55:733](../scripts\game\vehicles\vm_core.gd#L733)

**Local helper construction:** `VmCore._antenna`, `VmCore._bar`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._dshk`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._oct`, `VmCore._on_face`, `VmCore._path`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._round_ring`, `VmCore._rz`, `VmCore._shackle`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._tube`.

### orca, orca_armed

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAircraft.rocket_pod`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._orca:1152](../scripts\game\vehicles\vm_heli.gd#L1152)
- the windscreen, chin windows, cockpit door windows ó [VmHeli._orca:1172](../scripts\game\vehicles\vm_heli.gd#L1172)
- the sliding doors and a window behind them ó [VmHeli._orca:1177](../scripts\game\vehicles\vm_heli.gd#L1177)
- the roof fairing with the engine intakes and exhausts ó [VmHeli._orca:1183](../scripts\game\vehicles\vm_heli.gd#L1183)
- the fenestron: shroud with its open duct, the fin, the tailplane ó [VmHeli._orca:1197](../scripts\game\vehicles\vm_heli.gd#L1197)
- tricycle wheels: the nosewheel, mains in their fairings ó [VmHeli._orca:1207](../scripts\game\vehicles\vm_heli.gd#L1207)
- side pylons: a minigun on the left, a rocket pod on the right ó [VmHeli._orca:1214](../scripts\game\vehicles\vm_heli.gd#L1214)
- the rotor: four blades with swept tips ó [VmHeli._orca:1224](../scripts\game\vehicles\vm_heli.gd#L1224)

**Local helper construction:** `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tube`.

### panther

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._panther:1117](../scripts\game\vehicles\vm_nato.gd#L1117)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### patrol_ship

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radar_array`, `VehicleMounts.radome`, `VehicleMounts.receiver`, `VehicleSurface.plane`, `VehicleWeapons.hmg`.

**Authored sections:**

- Unlabelled construction / setup ó [VmShips._patrol_ship:612](../scripts\game\vehicles\vm_ships.gd#L612)
- spray rails and chine flats on the bottom, the rubbing strake under the deck edge, a toe rail round the open decks, a capping on the bulwark ó [VmShips._patrol_ship:623](../scripts\game\vehicles\vm_ships.gd#L623)
- scuppers along the deck edge, exhaust outlets low aft, the hull number ó [VmShips._patrol_ship:653](../scripts\game\vehicles\vm_ships.gd#L653)
- draft marks at the stem and stern ó [VmShips._patrol_ship:662](../scripts\game\vehicles\vm_ships.gd#L662)
- --- the deckhouse: the pilothouse forward, the lower after house ó [VmShips._patrol_ship:667](../scripts\game\vehicles\vm_ships.gd#L667)
- the window band: dark surrounds, then the panes, pillars between them ó [VmShips._patrol_ship:679](../scripts\game\vehicles\vm_ships.gd#L679)
- window pillars at the facet corners, wipers on the windscreen ó [VmShips._patrol_ship:698](../scripts\game\vehicles\vm_ships.gd#L698)
- the roof, its visor over the windscreen, a coaming round its edge ó [VmShips._patrol_ship:704](../scripts\game\vehicles\vm_ships.gd#L704)
- the pilothouse's after wall above the after house: two small windows, a door to the roof ó [VmShips._patrol_ship:712](../scripts\game\vehicles\vm_ships.gd#L712)
- the after house: doors and portholes in its sides, a ladder up its back ó [VmShips._patrol_ship:715](../scripts\game\vehicles\vm_ships.gd#L715)
- a life ring, a fire-hose box, the team panel ó [VmShips._patrol_ship:735](../scripts\game\vehicles\vm_ships.gd#L735)
- navigation sidelights on the pilothouse shoulders, red to port ó [VmShips._patrol_ship:739](../scripts\game\vehicles\vm_ships.gd#L739)
- --- the after house's roof: rails round it, four liferafts tipped outboard, the satcom dome, HVAC boxes, whips at the corners ó [VmShips._patrol_ship:747](../scripts\game\vehicles\vm_ships.gd#L747)
- --- the pilothouse roof: the raked mast with the radar, searchlights, the EO ball, the horn, whips ó [VmShips._patrol_ship:768](../scripts\game\vehicles\vm_ships.gd#L768)
- the topmast, the yardarm with its lights and halyards, the masthead light ó [VmShips._patrol_ship:779](../scripts\game\vehicles\vm_ships.gd#L779)
- --- the foredeck: the forward Mk 38 (the turret), its ready-use lockers, a hatch, the windlass, bitts, the jackstaff and the anchor on its roller ó [VmShips._patrol_ship:795](../scripts\game\vehicles\vm_ships.gd#L795)
- fairleads through the bulwark by the bow bitts ó [VmShips._patrol_ship:808](../scripts\game\vehicles\vm_ships.gd#L808)
- the anchor: shank up on the roller, its flukes against the stem ó [VmShips._patrol_ship:829](../scripts\game\vehicles\vm_ships.gd#L829)
- --- lifelines from the bulwark's end aft round the stern, a gate at the transom ó [VmShips._patrol_ship:836](../scripts\game\vehicles\vm_ships.gd#L836)
- --- side decks: .50 cals on pedestals beside the pilothouse and aft ó [VmShips._patrol_ship:858](../scripts\game\vehicles\vm_ships.gd#L858)
- --- the after deck: the second Mk 38 trained aft, its lockers, hatches, vents, fenders, the ensign staff, the waterjets on the transom ó [VmShips._patrol_ship:864](../scripts\game\vehicles\vm_ships.gd#L864)
- the stern light on the staff's after face, looking aft ó [VmShips._patrol_ship:880](../scripts\game\vehicles\vm_ships.gd#L880)
- the stern's exhaust pipes ó [VmShips._patrol_ship:890](../scripts\game\vehicles\vm_ships.gd#L890)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._m2`, `VmShips._mk38`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._stem_z`, `VmShips._surf`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._vent`, `VmShips._whip`.

### prowler, prowler_at, prowler_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.dashboard`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWeapons.hmg`, `VehicleWeapons.launch_tube`, `VehicleWeapons.mmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._prowler:384](../scripts\game\vehicles\vm_nato.gd#L384)
- --- the chassis tub, belly plate and suspension ó [VmNato._prowler:389](../scripts\game\vehicles\vm_nato.gd#L389)
- --- the flat bonnet, its fenders and the nose ó [VmNato._prowler:397](../scripts\game\vehicles\vm_nato.gd#L397)
- each fender sloping down outboard, the front one with a raked lip ó [VmNato._prowler:401](../scripts\game\vehicles\vm_nato.gd#L401)
- tube bumper with the winch, lights each side and on the cage ó [VmNato._prowler:408](../scripts\game\vehicles\vm_nato.gd#L408)
- --- the cockpit: dash, the cowl, seats, steering wheel ó [VmNato._prowler:416](../scripts\game\vehicles\vm_nato.gd#L416)
- rear deck: outward-facing benches either side, kit stowed between ó [VmNato._prowler:424](../scripts\game\vehicles\vm_nato.gd#L424)
- the spare wheel upright on the tailgate ó [VmNato._prowler:434](../scripts\game\vehicles\vm_nato.gd#L434)
- --- the roll cage ó [VmNato._prowler:439](../scripts\game\vehicles\vm_nato.gd#L439)
- light bar on the front roof bar, antennas at the back ó [VmNato._prowler:457](../scripts\game\vehicles\vm_nato.gd#L457)
- the passenger's pintle MG (an M240-class .338) on a swing arm ó [VmNato._prowler:467](../scripts\game\vehicles\vm_nato.gd#L467)
- the ring mount on the cage roof ó [VmNato._prowler:471](../scripts\game\vehicles\vm_nato.gd#L471)
- the pintle gun is the second gun, decoration here ó [VmNato._prowler:484](../scripts\game\vehicles\vm_nato.gd#L484)
- Titan launcher: the tube, the sight/command unit, the grip ó [VmNato._prowler:486](../scripts\game\vehicles\vm_nato.gd#L486)
- two reloads, each in its own launch tube, in a rack on the deck ó [VmNato._prowler:492](../scripts\game\vehicles\vm_nato.gd#L492)

**Local helper construction:** `VmNato._ammo_can`, `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._seat`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### qilin, qilin_at, qilin_mg

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.dashboard`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWeapons.launch_tube`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._qilin:336](../scripts\game\vehicles\vm_csat.gd#L336)
- the belly pan and chassis rails ó [VmCsat._qilin:338](../scripts\game\vehicles\vm_csat.gd#L338)
- the nose over the radiator: a sloping bonnet ó [VmCsat._qilin:340](../scripts\game\vehicles\vm_csat.gd#L340)
- a vent in the bonnet before the screen ó [VmCsat._qilin:346](../scripts\game\vehicles\vm_csat.gd#L346)
- the open crew tub: floor and low side walls, the rear engine deck ó [VmCsat._qilin:352](../scripts\game\vehicles\vm_csat.gd#L352)
- the dash under the screen frame, the steering wheel, the seats ó [VmCsat._qilin:357](../scripts\game\vehicles\vm_csat.gd#L357)
- the passengers' bench over the engine, back to back, facing out ó [VmCsat._qilin:363](../scripts\game\vehicles\vm_csat.gd#L363)
- fenders: faceted mudguards over the wheels, steps between them ó [VmCsat._qilin:367](../scripts\game\vehicles\vm_csat.gd#L367)
- round headlamps with guards, the indicators ó [VmCsat._qilin:374](../scripts\game\vehicles\vm_csat.gd#L374)
- mirrors on the screen frame ó [VmCsat._qilin:379](../scripts\game\vehicles\vm_csat.gd#L379)
- exhaust out of the right rear ó [VmCsat._qilin:381](../scripts\game\vehicles\vm_csat.gd#L381)
- the grille and bull bar ó [VmCsat._qilin:383](../scripts\game\vehicles\vm_csat.gd#L383)
- the spare wheel upright on the tail, jerrycans beside it ó [VmCsat._qilin:392](../scripts\game\vehicles\vm_csat.gd#L392)
- the roll cage ó [VmCsat._qilin:396](../scripts\game\vehicles\vm_csat.gd#L396)
- the weapon ring on the cage over the gunner's station ó [VmCsat._qilin:417](../scripts\game\vehicles\vm_csat.gd#L417)
- the minigun: six barrels round a spindle, the motor and feed chute ó [VmCsat._qilin:435](../scripts\game\vehicles\vm_csat.gd#L435)
- the Vorona: a fat launch tube on a cradle, the thermal sight beside it ó [VmCsat._qilin:447](../scripts\game\vehicles\vm_csat.gd#L447)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._jerrycan`, `VmCsat._onface`, `VmCsat._plate`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### quadbike

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.exhaust`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._quad:958](../scripts\game\vehicles\vm_civ.gd#L958)
- frame, engine, swingarm ó [VmCiv._quad:964](../scripts\game\vehicles\vm_civ.gd#L964)
- double wishbones and a shock to each front wheel ó [VmCiv._quad:967](../scripts\game\vehicles\vm_civ.gd#L967)
- the front body over the wheels, the console and tank, the rear body ó [VmCiv._quad:976](../scripts\game\vehicles\vm_civ.gd#L976)
- floorboards with their raised lips ó [VmCiv._quad:981](../scripts\game\vehicles\vm_civ.gd#L981)
- tubular racks front and back ó [VmCiv._quad:989](../scripts\game\vehicles\vm_civ.gd#L989)
- handlebars and the pod with its headlight, grips, levers ó [VmCiv._quad:1002](../scripts\game\vehicles\vm_civ.gd#L1002)
- the brush guard, the tail light, the exhaust out back, a tow hitch ó [VmCiv._quad:1013](../scripts\game\vehicles\vm_civ.gd#L1013)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._xbody`.

### rhib

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.seat`, `VehicleCab.steering_wheel`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMarine.mooring`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radome`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._rhib:682](../scripts\game\vehicles\vm_boat.gd#L682)
- spray rails along the bottom ó [VmBoat._rhib:693](../scripts\game\vehicles\vm_boat.gd#L693)
- the collar: runs along the sheer, kicks up at the bow, its ends past the transom ó [VmBoat._rhib:707](../scripts\game\vehicles\vm_boat.gd#L707)
- the centre console under its radar arch ó [VmBoat._rhib:731](../scripts\game\vehicles\vm_boat.gd#L731)
- side lights on the console's shoulders, the team panel below them ó [VmBoat._rhib:746](../scripts\game\vehicles\vm_boat.gd#L746)
- the arch: two legs a side up to a platform with the radar, lights, whips ó [VmBoat._rhib:749](../scripts\game\vehicles\vm_boat.gd#L749)
- the masthead light's pole runs up into the light's base ó [VmBoat._rhib:765](../scripts\game\vehicles\vm_boat.gd#L765)
- two rows of jockey seats, each with a grab bar ó [VmBoat._rhib:771](../scripts\game\vehicles\vm_boat.gd#L771)
- a seat box forward of the console, the stern locker ó [VmBoat._rhib:781](../scripts\game\vehicles\vm_boat.gd#L781)
- bow: an anchor locker hatch, a cleat and the towing eye on the stem ó [VmBoat._rhib:788](../scripts\game\vehicles\vm_boat.gd#L788)
- twin outboards and the tie bar between them ó [VmBoat._rhib:796](../scripts\game\vehicles\vm_boat.gd#L796)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._tube`, `VmBoat._tube_kit`, `VmBoat._u`.

### rhino, rhino_up

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.slats`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._rhino:616](../scripts\game\vehicles\vm_nato.gd#L616)
- the lower hull: a pointed nose under the glacis, sides inboard of the wheels ó [VmNato._rhino:621](../scripts\game\vehicles\vm_nato.gd#L621)
- the upper hull: the arrowhead nose climbing to a narrow front of the roof ó [VmNato._rhino:626](../scripts\game\vehicles\vm_nato.gd#L626)
- the driver's hatch centred at the top of the glacis, his periscopes, lights in guards on the nose, tow eyes ó [VmNato._rhino:634](../scripts\game\vehicles\vm_nato.gd#L634)
- big stowage bins along the leaning sides, the engine deck louvres ó [VmNato._rhino:643](../scripts\game\vehicles\vm_nato.gd#L643)
- --- the turret: wedged front faces round the gun, a long bustle ó [VmNato._rhino:657](../scripts\game\vehicles\vm_nato.gd#L657)
- the gun: mantlet, barrel with its thermal sleeve and fume extractor, the muzzle reference sensor ó [VmNato._rhino:664](../scripts\game\vehicles\vm_nato.gd#L664)
- sights: the gunner's ahead on the left, the commander's cupola and his panoramic sight on the right; the loader's hatch ó [VmNato._rhino:675](../scripts\game\vehicles\vm_nato.gd#L675)
- bins on the bustle sides ó [VmNato._rhino:684](../scripts\game\vehicles\vm_nato.gd#L684)
- --- urban package: ERA bricks on the turret front and cheeks and along the glacis, slat cages round the hull sides and back, a remote .50 ó [VmNato._rhino:699](../scripts\game\vehicles\vm_nato.gd#L699)
- the turret's front cheeks and the forward half of its sides ó [VmNato._rhino:702](../scripts\game\vehicles\vm_nato.gd#L702)
- both plates of the arrowhead glacis ó [VmNato._rhino:705](../scripts\game\vehicles\vm_nato.gd#L705)
- slat cages: a frame standing off each side and across the back ó [VmNato._rhino:707](../scripts\game\vehicles\vm_nato.gd#L707)
- the remote weapon station on the turret roof (it turns with the gun) ó [VmNato._rhino:715](../scripts\game\vehicles\vm_nato.gd#L715)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._era`, `VmNato._face_basis`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._xy`.

### sandstorm

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._sandstorm:984](../scripts\game\vehicles\vm_nato.gd#L984)
- the crew's cupola and periscopes forward, where a turret would be ó [VmNato._sandstorm:987](../scripts\game\vehicles\vm_nato.gd#L987)
- the launcher's travel rest on the roof, where the box's front end sits ó [VmNato._sandstorm:994](../scripts\game\vehicles\vm_nato.gd#L994)
- the turntable and the launcher's base with its elevation rams ó [VmNato._sandstorm:998](../scripts\game\vehicles\vm_nato.gd#L998)
- the launcher box: hinged at its rear end, the pods' tubes facing forward ó [VmNato._sandstorm:1006](../scripts\game\vehicles\vm_nato.gd#L1006)
- each pod's face: six tube mouths behind the frangible covers ó [VmNato._sandstorm:1014](../scripts\game\vehicles\vm_nato.gd#L1014)
- ribs down the sides, the boom-hoists along the top edges ó [VmNato._sandstorm:1019](../scripts\game\vehicles\vm_nato.gd#L1019)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy`.

### scorcher

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._scorcher:935](../scripts\game\vehicles\vm_nato.gd#L935)
- the barrel's travel lock folded down on the glacis ó [VmNato._scorcher:938](../scripts\game\vehicles\vm_nato.gd#L938)
- the tall box: sloped front faces, vertical sides, the bustle ó [VmNato._scorcher:943](../scripts\game\vehicles\vm_nato.gd#L943)
- side doors, roof hatches, the commander's cupola with a remote .50 ó [VmNato._scorcher:947](../scripts\game\vehicles\vm_nato.gd#L947)
- the gun: trunnions at the turret front, the cradle, recoil cylinders, the long tube with its fume extractor and the double-baffle muzzle brake ó [VmNato._scorcher:962](../scripts\game\vehicles\vm_nato.gd#L962)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy`.

### sdv

**Shared:** `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.lifting_eye`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.propeller`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._sdv:809](../scripts\game\vehicles\vm_boat.gd#L809)
- the raised hatch deck over the crew compartment, and its four hatches ó [VmBoat._sdv:820](../scripts\game\vehicles\vm_boat.gd#L820)
- forward: the pilot's and navigator's canopy, split down the middle, with viewports in its sloped front and sides ó [VmBoat._sdv:823](../scripts\game\vehicles\vm_boat.gd#L823)
- aft: the passengers' two flat hatches ó [VmBoat._sdv:839](../scripts\game\vehicles\vm_boat.gd#L839)
- lifting eyes at the deck's corners ó [VmBoat._sdv:846](../scripts\game\vehicles\vm_boat.gd#L846)
- the mast with the periscope head and a comms antenna beside it ó [VmBoat._sdv:850](../scripts\game\vehicles\vm_boat.gd#L850)
- nose: the sonar window and two lamps ó [VmBoat._sdv:857](../scripts\game\vehicles\vm_boat.gd#L857)
- the free-flooding hull's vent grilles and panel seams down each side ó [VmBoat._sdv:862](../scripts\game\vehicles\vm_boat.gd#L862)
- the skids it rests on ó [VmBoat._sdv:871](../scripts\game\vehicles\vm_boat.gd#L871)
- tail: the cone's end, cruciform fins and the duct round the propeller ó [VmBoat._sdv:873](../scripts\game\vehicles\vm_boat.gd#L873)

**Local helper construction:** `VmBoat._foil`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._sring`.

### sentinel

**Shared:** `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._sentinel:1170](../scripts\game\vehicles\vm_plane.gd#L1170)
- the dorsal intake: a raked hood standing off the hump, its dark mouth ó [VmPlane._sentinel:1186](../scripts\game\vehicles\vm_plane.gd#L1186)
- the exhaust buried in the upper surface at the back ó [VmPlane._sentinel:1191](../scripts\game\vehicles\vm_plane.gd#L1191)
- (no exhaust glow: the pipe is buried in the upper surface to hide it) ó [VmPlane._sentinel:1194](../scripts\game\vehicles\vm_plane.gd#L1194)
- the cranked outer wings: elevons, the fold line ó [VmPlane._sentinel:1196](../scripts\game\vehicles\vm_plane.gd#L1196)
- body elevons along the inner trailing edges ó [VmPlane._sentinel:1200](../scripts\game\vehicles\vm_plane.gd#L1200)
- the sensor window under the nose, belly doors, the hook, antennas ó [VmPlane._sentinel:1206](../scripts\game\vehicles\vm_plane.gd#L1206)
- flush satcom and GPS patches on the hump, the refuelling probe door ó [VmPlane._sentinel:1214](../scripts\game\vehicles\vm_plane.gd#L1214)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### shikra

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._shikra:951](../scripts\game\vehicles\vm_plane.gd#L951)
- the nacelles, raked intakes under the LEVCONs, round Su-35 nozzles ó [VmPlane._shikra:978](../scripts\game\vehicles\vm_plane.gd#L978)
- LEVCONs, the wing with ailerons and flaperons ó [VmPlane._shikra:987](../scripts\game\vehicles\vm_plane.gd#L987)
- tail booms carrying the all-moving tailplanes; all-moving canted fins ó [VmPlane._shikra:991](../scripts\game\vehicles\vm_plane.gd#L991)
- the sting between the nozzles ó [VmPlane._shikra:997](../scripts\game\vehicles\vm_plane.gd#L997)
- the gun at the right wing root, antennas, navigation lights ó [VmPlane._shikra:999](../scripts\game\vehicles\vm_plane.gd#L999)
- stores: Kh-38s under the nacelles, KAB bombs and R-73s under the wings ó [VmPlane._shikra:1006](../scripts\game\vehicles\vm_plane.gd#L1006)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### slammer, slammer_up

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.coax`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._slammer:926](../scripts\game\vehicles\vm_nato.gd#L926)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._chain`, `VmNato._era`, `VmNato._face_basis`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._mk_turret`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._xy`, `VmNato._zy`.

### sochor

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._sochor:953](../scripts\game\vehicles\vm_csat.gd#L953)
- flat sides: a crew door, stowage boxes, vents; the ammunition door at the back ó [VmCsat._sochor:961](../scripts\game\vehicles\vm_csat.gd#L961)
- roof: hatches, the commander's panoramic sight, the remote 12.7 mm ó [VmCsat._sochor:971](../scripts\game\vehicles\vm_csat.gd#L971)
- the barrel on its trunnions: mantlet, recoil cylinders, fume extractor, the long tube and the muzzle brake ó [VmCsat._sochor:978](../scripts\game\vehicles\vm_csat.gd#L978)
- the travel lock, folded down on the glacis ó [VmCsat._sochor:993](../scripts\game\vehicles\vm_csat.gd#L993)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### speedboat_hmg, speedboat_minigun

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.dome_light`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.radar_array`, `VehicleMounts.radome`, `VehicleMounts.receiver`, `VehicleSurface.plane`, `VehicleWeapons.hmg`, `VehicleWeapons.rotary`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._surc:898](../scripts\game\vehicles\vm_boat.gd#L898)
- the fendering strake along the knuckle, spray rails on the bottom ó [VmBoat._surc:906](../scripts\game\vehicles\vm_boat.gd#L906)
- non-skid decks: the open troop deck aft and the foredeck ó [VmBoat._surc:926](../scripts\game\vehicles\vm_boat.gd#L926)
- armoured bulwarks round the troop deck, capped ó [VmBoat._surc:930](../scripts\game\vehicles\vm_boat.gd#L930)
- the bulwarks' ballistic panels: seams down their sloped faces ó [VmBoat._surc:942](../scripts\game\vehicles\vm_boat.gd#L942)
- the transom's bulwark, with a gate in the middle ó [VmBoat._surc:947](../scripts\game\vehicles\vm_boat.gd#L947)
- the cabin: near-vertical armoured walls, a band of steeply slanted glass ó [VmBoat._surc:951](../scripts\game\vehicles\vm_boat.gd#L951)
- the rear: a door below, a window above it ó [VmBoat._surc:970](../scripts\game\vehicles\vm_boat.gd#L970)
- wipers on the windscreen, armour seams on the lower walls ó [VmBoat._surc:976](../scripts\game\vehicles\vm_boat.gd#L976)
- side lights on the cabin's shoulders, the team panel aft of them ó [VmBoat._surc:981](../scripts\game\vehicles\vm_boat.gd#L981)
- the roof: a raked mast with the radar, a satcom dome, whips, searchlight, smoke dischargers at the front corners, grab rails ó [VmBoat._surc:984](../scripts\game\vehicles\vm_boat.gd#L984)
- side-deck handrails along the cabin ó [VmBoat._surc:1003](../scripts\game\vehicles\vm_boat.gd#L1003)
- the troop deck: benches with backrests along both bulwarks ó [VmBoat._surc:1010](../scripts\game\vehicles\vm_boat.gd#L1010)
- the rear gun on its pedestal ring mount, looking aft over the quarter ó [VmBoat._surc:1017](../scripts\game\vehicles\vm_boat.gd#L1017)
- 12.7 mm HMG: a long receiver, a heavy barrel with its muzzle brake, the ammunition can on the left (the spade grips are the mount's, below) ó [VmBoat._surc:1029](../scripts\game\vehicles\vm_boat.gd#L1029)
- M134 minigun: six barrels in a clamp, the motor housing, the feed chute ó [VmBoat._surc:1033](../scripts\game\vehicles\vm_boat.gd#L1033)
- bow remote weapon station: 40 mm GMG, sight on the right, ammo on the left ó [VmBoat._surc:1040](../scripts\game\vehicles\vm_boat.gd#L1040)
- foredeck: twin bitts, a cleat each side, the towing eye on the stem ó [VmBoat._surc:1061](../scripts\game\vehicles\vm_boat.gd#L1061)
- transom: twin waterjets with their steering nozzles and raised reversing buckets, tucked under a stern step; the stern light ó [VmBoat._surc:1071](../scripts\game\vehicles\vm_boat.gd#L1071)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### stomper

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmNato._stomper:1565](../scripts\game\vehicles\vm_nato.gd#L1565)
- the swing arm from the hull to the hub, its motor housing ó [VmNato._stomper:1571](../scripts\game\vehicles\vm_nato.gd#L1571)
- the armoured tub: a wedge nose, the flanks leaning in ó [VmNato._stomper:1574](../scripts\game\vehicles\vm_nato.gd#L1574)
- side pods over the wheels (batteries / engine), angular, low ó [VmNato._stomper:1579](../scripts\game\vehicles\vm_nato.gd#L1579)
- the space frame over the tub: rails, hoops and diagonals ó [VmNato._stomper:1582](../scripts\game\vehicles\vm_nato.gd#L1582)
- the sensor mast at the nose: stereo cameras, laser scanners, a GPS dome ó [VmNato._stomper:1592](../scripts\game\vehicles\vm_nato.gd#L1592)
- the RCWS on the frame ó [VmNato._stomper:1609](../scripts\game\vehicles\vm_nato.gd#L1609)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### strider, strider_gmg, strider_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.sensor`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.exhaust`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.gmg`, `VehicleWeapons.hmg`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._strider:159](../scripts\game\vehicles\vm_indep.gd#L159)
- the belly between the wheels (its front sloping under the nose) ó [VmIndep._strider:166](../scripts\game\vehicles\vm_indep.gd#L166)
- the nose and tail blocks ahead of and behind the wheel arches, the sills between ó [VmIndep._strider:168](../scripts\game\vehicles\vm_indep.gd#L168)
- the upper hull: a chine all round, then the armoured nose and windscreen in one steep slope, the cabin's sides leaning in, the engine deck a step lower at the back ó [VmIndep._strider:173](../scripts\game\vehicles\vm_indep.gd#L173)
- wheels in their dark wells, mud flaps behind the rear ones ó [VmIndep._strider:179](../scripts\game\vehicles\vm_indep.gd#L179)
- the arch's lip ó [VmIndep._strider:184](../scripts\game\vehicles\vm_indep.gd#L184)
- windscreen: two armoured panes in heavy frames on the slope, the pillar between ó [VmIndep._strider:187](../scripts\game\vehicles\vm_indep.gd#L187)
- a wiper over each pane ó [VmIndep._strider:194](../scripts\game\vehicles\vm_indep.gd#L194)
- the nose: headlight clusters in guards, tow shackles, a plate ó [VmIndep._strider:199](../scripts\game\vehicles\vm_indep.gd#L199)
- mirrors on their arms by the windscreen ó [VmIndep._strider:205](../scripts\game\vehicles\vm_indep.gd#L205)
- the side door: seams, an armoured window, the handle, a step below ó [VmIndep._strider:207](../scripts\game\vehicles\vm_indep.gd#L207)
- a small rear-quarter window, the stowage bin over the rear wheel ó [VmIndep._strider:215](../scripts\game\vehicles\vm_indep.gd#L215)
- smoke dischargers on the deck corners, a whip antenna at each back corner ó [VmIndep._strider:219](../scripts\game\vehicles\vm_indep.gd#L219)
- rear: tail light clusters, the jerrycan rack on the left, a box on the right ó [VmIndep._strider:222](../scripts\game\vehicles\vm_indep.gd#L222)
- exhaust out of the right flank behind the rear wheel, under a heat shield ó [VmIndep._strider:230](../scripts\game\vehicles\vm_indep.gd#L230)
- roof: the driver's and commander's hatches with periscopes, the observer's hatch behind ó [VmIndep._strider:233](../scripts\game\vehicles\vm_indep.gd#L233)
- hinged at the front, by the periscopes, the handle at the back ó [VmIndep._strider:236](../scripts\game\vehicles\vm_indep.gd#L236)
- engine deck: two grilles with their slats ó [VmIndep._strider:241](../scripts\game\vehicles\vm_indep.gd#L241)
- the scout: the BAA sensor head (camera, thermal imager, rangefinder) high on a telescopic mast behind the cabin; the head pans ó [VmIndep._strider:250](../scripts\game\vehicles\vm_indep.gd#L250)
- the commander's periscope mast, folded low at the cabin's back corner ó [VmIndep._strider:261](../scripts\game\vehicles\vm_indep.gd#L261)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._tb`, `VmIndep._tow_eyes`.

### suv

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleFittings.exhaust`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._suv:1184](../scripts\game\vehicles\vm_civ.gd#L1184)
- doors, chrome handles, the shoulder crease, black skirts, mirrors ó [VmCiv._suv:1212](../scripts\game\vehicles\vm_civ.gd#L1212)
- headlights flanking the kidneys, two rings in each, wrapping round ó [VmCiv._suv:1220](../scripts\game\vehicles\vm_civ.gd#L1220)
- the tail lights across the corners, a reflector under them ó [VmCiv._suv:1228](../scripts\game\vehicles\vm_civ.gd#L1228)
- lower intakes and fog lights, exhausts ó [VmCiv._suv:1232](../scripts\game\vehicles\vm_civ.gd#L1232)
- the twin kidneys ó [VmCiv._suv:1237](../scripts\game\vehicles\vm_civ.gd#L1237)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._xbody`.

### tank

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCloth.roll`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lifting_eye`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.basket`, `VehicleMounts.cupola`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWeapons.coax`, `VehicleWeapons.hmg`, `VehicleWeapons.mmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._abrams:290](../scripts\game\vehicles\vm_core.gd#L290)
- --- running gear: front idler, seven road wheels, rear sprocket ó [VmCore._abrams:293](../scripts\game\vehicles\vm_core.gd#L293)
- --- the hull: the belly between the tracks with the lower glacis at its front, the upper hull out over the tracks with the long upper glacis ó [VmCore._abrams:312](../scripts\game\vehicles\vm_core.gd#L312)
- the glacis: the driver's hatch in the middle at its top, his three periscopes; a seam across the nose, lifting eyes ó [VmCore._abrams:321](../scripts\game\vehicles\vm_core.gd#L321)
- the front: headlight clusters in their guards on the fender tops, tow shackles on the lower glacis, the front fenders' rubber flaps ó [VmCore._abrams:333](../scripts\game\vehicles\vm_core.gd#L333)
- skirts: seven bolted panels a side, the first two heavy armoured ones, the front panel raked over the idler; a bolt line along their tops ó [VmCore._abrams:341](../scripts\game\vehicles\vm_core.gd#L341)
- the handrail-like lip of the fender over the skirts, a rear mudguard over the sprocket with its rubber flap ó [VmCore._abrams:356](../scripts\game\vehicles\vm_core.gd#L356)
- fuel filler caps on the deck over the sponsons ó [VmCore._abrams:361](../scripts\game\vehicles\vm_core.gd#L361)
- --- the engine deck: the big grille doors over the turbine and the transmission, the centre access plate, lifting eyes ó [VmCore._abrams:364](../scripts\game\vehicles\vm_core.gd#L364)
- --- the rear plate: the turbine exhaust grille across the middle, the tail light clusters, tow pintle and shackles, the infantry phone box ó [VmCore._abrams:374](../scripts\game\vehicles\vm_core.gd#L374)
- --- the turret ó [VmCore._abrams:383](../scripts\game\vehicles\vm_core.gd#L383)
- the main body: the crew compartment and the long bustle over the deck ó [VmCore._abrams:388](../scripts\game\vehicles\vm_core.gd#L388)
- the cheeks: armour blocks either side of the gun shield, swept back in plan, their faces near vertical over a deep undercut ó [VmCore._abrams:392](../scripts\game\vehicles\vm_core.gd#L392)
- the seam where the cheek block meets the turret side ó [VmCore._abrams:404](../scripts\game\vehicles\vm_core.gd#L404)
- the gun shield, recessed between the cheeks; the gunner's auxiliary sight port on it, the coax M240 to its right ó [VmCore._abrams:406](../scripts\game\vehicles\vm_core.gd#L406)
- the 120 mm: the sleeve in sections with their clamp bands, the bore evacuator, the muzzle and its reference sensor ó [VmCore._abrams:414](../scripts\game\vehicles\vm_core.gd#L414)
- --- the roof: the gunner's primary sight doghouse front right with its armoured doors, the commander's independent thermal viewer front left ó [VmCore._abrams:421](../scripts\game\vehicles\vm_core.gd#L421)
- the commander's station on the right: the cupola ring with its vision blocks, the hatch, the .50 on its mount ahead of it ó [VmCore._abrams:432](../scripts\game\vehicles\vm_core.gd#L432)
- the loader's hatch on the left and his M240 behind the gun shield kit ó [VmCore._abrams:439](../scripts\game\vehicles\vm_core.gd#L439)
- the crosswind sensor mast at the back of the roof, the blow-off panels over the ammunition in the bustle, lifting eyes, antennas ó [VmCore._abrams:450](../scripts\game\vehicles\vm_core.gd#L450)
- M250 smoke dischargers on the flanks behind the cheeks ó [VmCore._abrams:460](../scripts\game\vehicles\vm_core.gd#L460)
- stowage boxes along the turret sides, their lids and latches ó [VmCore._abrams:462](../scripts\game\vehicles\vm_core.gd#L462)
- the bustle rack: a basket round the back of the bustle, packed with kit ó [VmCore._abrams:467](../scripts\game\vehicles\vm_core.gd#L467)

**Local helper construction:** `VmCore._ammo_can`, `VmCore._antenna`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._m2`, `VmCore._mirror`, `VmCore._mmg`, `VmCore._oct`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._zy`.

### taru

**Shared:** `VehicleAircraft.cowling`, `VehicleAircraft.turbine_exhaust`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.dome_light`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.mast`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmHeli._taru:1237](../scripts\game\vehicles\vm_heli.gd#L1237)
- the spine ó [VmHeli._taru:1244](../scripts\game\vehicles\vm_heli.gd#L1244)
- the cab, glazed all round its nose ó [VmHeli._taru:1255](../scripts\game\vehicles\vm_heli.gd#L1255)
- the engines and the gearbox fairing on the spine ó [VmHeli._taru:1277](../scripts\game\vehicles\vm_heli.gd#L1277)
- the tailplane with its twin fins, a ventral fin ó [VmHeli._taru:1293](../scripts\game\vehicles\vm_heli.gd#L1293)
- the legs: long oleo struts splayed out from the spine, braced ó [VmHeli._taru:1298](../scripts\game\vehicles\vm_heli.gd#L1298)
- the transport pod on its four hooks ó [VmHeli._taru:1311](../scripts\game\vehicles\vm_heli.gd#L1311)
- the coaxial rotors: three blades each, turning against each other ó [VmHeli._taru:1335](../scripts\game\vehicles\vm_heli.gd#L1335)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._tube`.

### tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.light_guard`, `VehicleProfiles.revolve`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._tempest:1192](../scripts\game\vehicles\vm_csat.gd#L1192)
- long missile crates stacked forward, ammunition boxes behind them, cans at the tail, all strapped down ó [VmCsat._tempest:1198](../scripts\game\vehicles\vm_csat.gd#L1198)
- Shorter stacked cases preserve the clearance below the folded boom. ó [VmCsat._tempest:1204](../scripts\game\vehicles\vm_csat.gd#L1204)
- the loading crane behind the cab, its boom folded back over the load ó [VmCsat._tempest:1219](../scripts\game\vehicles\vm_csat.gd#L1219)
- roller shutters on the sides, toolboxes under the body ó [VmCsat._tempest:1230](../scripts\game\vehicles\vm_csat.gd#L1230)
- the workshop's back door onto the platform ó [VmCsat._tempest:1236](../scripts\game\vehicles\vm_csat.gd#L1236)
- the crane on the open platform behind, its boom along the roof ó [VmCsat._tempest:1241](../scripts\game\vehicles\vm_csat.gd#L1241)
- a spare wheel standing on the platform, a welding bottle rack ó [VmCsat._tempest:1248](../scripts\game\vehicles\vm_csat.gd#L1248)
- the rear door with its steps, the cross on it, the roof's air units ó [VmCsat._tempest:1260](../scripts\game\vehicles\vm_csat.gd#L1260)
- the pump cabinet and hose reels at the back ó [VmCsat._tempest:1286](../scripts\game\vehicles\vm_csat.gd#L1286)
- troops: armoured sides, the canvas cover on its bows ó [VmCsat._tempest:1292](../scripts\game\vehicles\vm_csat.gd#L1292)
- the boarding ladder hung on the tailgate ó [VmCsat._tempest:1305](../scripts\game\vehicles\vm_csat.gd#L1305)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._cross`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._plate`, `VmCsat._rz`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tempest_box`, `VmCsat._tempest_flatbed`, `VmCsat._tow`, `VmCsat._tube`, `VmCsat._typhoon`.

### tigris

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.panel_hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.radar_array`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.autocannon`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._tigris:730](../scripts\game\vehicles\vm_csat.gd#L730)
- the guns: a 35 mm in a cradle on each side, ammunition feed fairings ó [VmCsat._tigris:736](../scripts\game\vehicles\vm_csat.gd#L736)
- the tracking radar in its housing on the front of the roof ó [VmCsat._tigris:747](../scripts\game\vehicles\vm_csat.gd#L747)
- the optical sight beside it ó [VmCsat._tigris:750](../scripts\game\vehicles\vm_csat.gd#L750)
- the search radar: a flat antenna on a mast at the back ó [VmCsat._tigris:752](../scripts\game\vehicles\vm_csat.gd#L752)
- twin missile boxes either side of the mast ó [VmCsat._tigris:756](../scripts\game\vehicles\vm_csat.gd#L756)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### tractor

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.exhaust`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._tractor:1330](../scripts\game\vehicles\vm_civ.gd#L1330)
- engine, gearbox and the rear axle housings, the front beam axle ó [VmCiv._tractor:1340](../scripts\game\vehicles\vm_civ.gd#L1340)
- the bonnet, its grille and lamps, the weights hung on the front ó [VmCiv._tractor:1347](../scripts\game\vehicles\vm_civ.gd#L1347)
- louvres along the bonnet sides ó [VmCiv._tractor:1355](../scripts\game\vehicles\vm_civ.gd#L1355)
- wheels: small fronts under cycle wings, big rears with chevron lugs ó [VmCiv._tractor:1362](../scripts\game\vehicles\vm_civ.gd#L1362)
- the mudguards: a wide curved guard and its inner wall ó [VmCiv._tractor:1373](../scripts\game\vehicles\vm_civ.gd#L1373)
- the cab: floor, posts, white roof, glass all round ó [VmCiv._tractor:1383](../scripts\game\vehicles\vm_civ.gd#L1383)
- inside: the seat and the wheel ó [VmCiv._tractor:1406](../scripts\game\vehicles\vm_civ.gd#L1406)
- exhaust stack with its silencer and rain cap, the air intake ó [VmCiv._tractor:1411](../scripts\game\vehicles\vm_civ.gd#L1411)
- steps on the left, the three-point hitch and the PTO at the back ó [VmCiv._tractor:1417](../scripts\game\vehicles\vm_civ.gd#L1417)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._xbody`.

### truck

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCargo.sideboard`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.leaf`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.panel_hatch`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.hose_reel`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCore._truck:1625](../scripts\game\vehicles\vm_core.gd#L1625)
- the chassis: frame rails, the axles and their diffs, the wheels ó [VmCore._truck:1629](../scripts\game\vehicles\vm_core.gd#L1629)
- the bonnet, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks ó [VmCore._truck:1636](../scripts\game\vehicles\vm_core.gd#L1636)
- the louvres down the bonnet's sides ó [VmCore._truck:1647](../scripts\game\vehicles\vm_core.gd#L1647)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms ó [VmCore._truck:1654](../scripts\game\vehicles\vm_core.gd#L1654)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box ó [VmCore._truck:1669](../scripts\game\vehicles\vm_core.gd#L1669)
- the cargo bed: floor, sides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle ó [VmCore._truck:1673](../scripts\game\vehicles\vm_core.gd#L1673)
- Unlabelled construction / setup ó [VmIndep._zamak:777](../scripts\game\vehicles\vm_indep.gd#L777)
- Unlabelled construction / setup ó [VmNato._hemtt:1395](../scripts\game\vehicles\vm_nato.gd#L1395)
- drop sides and the headboard ó [VmNato._hemtt:1405](../scripts\game\vehicles\vm_nato.gd#L1405)
- the canvas tilt over its bows, the back rolled up over the benches ó [VmNato._hemtt:1414](../scripts\game\vehicles\vm_nato.gd#L1414)
- palletised crates and boxes lashed down, a tarp over one load ó [VmNato._hemtt:1428](../scripts\game\vehicles\vm_nato.gd#L1428)
- ammunition: pallets of boxes, then the knuckle-boom crane at the back, folded forward over the load ó [VmNato._hemtt:1439](../scripts\game\vehicles\vm_nato.gd#L1439)
- the shelter: a tall box body with a ribbed roof edge ó [VmNato._hemtt:1463](../scripts\game\vehicles\vm_nato.gd#L1463)
- roll-up shutters with their slats, tool lockers below ó [VmNato._hemtt:1470](../scripts\game\vehicles\vm_nato.gd#L1470)
- the light mast, AC unit, the rear door and ladder, a vice bench ó [VmNato._hemtt:1477](../scripts\game\vehicles\vm_nato.gd#L1477)
- windows, the rear doors with a step, roof vents, red crosses ó [VmNato._hemtt:1488](../scripts\game\vehicles\vm_nato.gd#L1488)
- the tank: an oval barrel on cradles, its end caps, the walkway on top with its rail, manholes, the pump cabinet and hose reels at the back ó [VmNato._hemtt:1503](../scripts\game\vehicles\vm_nato.gd#L1503)
- the hazard placard ó [VmNato._hemtt:1518](../scripts\game\vehicles\vm_nato.gd#L1518)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._path`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`, `VmNato._antenna`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_cargo_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_load_detail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### van_ambulance, van_services, van_transport

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.headlamp`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.bumper`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCiv._van:803](../scripts\game\vehicles\vm_civ.gd#L803)
- the bonnet, and the body with the windscreen and the high roof ó [VmCiv._van:818](../scripts\game\vehicles\vm_civ.gd#L818)
- windows: the cab doors always; the rest on the minibus, rear doors on all ó [VmCiv._van:825](../scripts\game\vehicles\vm_civ.gd#L825)
- shut lines: cab door, and on the right the sliding door with its rail ó [VmCiv._van:838](../scripts\game\vehicles\vm_civ.gd#L838)
- a black rubbing strip, the flares' lips, the tall tail lights ó [VmCiv._van:842](../scripts\game\vehicles\vm_civ.gd#L842)
- rear doors: windows, hinges ó [VmCiv._van:849](../scripts\game\vehicles\vm_civ.gd#L849)
- rear bumper with its step, plate ó [VmCiv._van:861](../scripts\game\vehicles\vm_civ.gd#L861)
- the face: three slats and the star, big swept headlights, the bumper ó [VmCiv._van:865](../scripts\game\vehicles\vm_civ.gd#L865)
- the big headlight: across the front corner and back along the wing ó [VmCiv._van:873](../scripts\game\vehicles\vm_civ.gd#L873)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._van_ambulance`, `VmCiv._van_services`, `VmCiv._xbody`.

### varsuk

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.evacuator`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.cupola`, `VehicleMounts.era_brick`, `VehicleMounts.light_guard`, `VehicleMounts.mantlet`, `VehicleMounts.mast_segment`, `VehicleMounts.receiver`, `VehicleMounts.sight`, `VehicleMounts.turret_ring`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleWeapons.coax`, `VehicleWeapons.hmg`, `VehicleWheels.road`, `VehicleWheels.sprocket`.

**Authored sections:**

- Unlabelled construction / setup ó [VmCsat._varsuk:861](../scripts\game\vehicles\vm_csat.gd#L861)
- the bustle: a long box hung off the turret's back ó [VmCsat._varsuk:867](../scripts\game\vehicles\vm_csat.gd#L867)
- reactive armour on the cheeks either side of the mantlet, and on the roof ó [VmCsat._varsuk:873](../scripts\game\vehicles\vm_csat.gd#L873)
- mantlet, gun, coax ó [VmCsat._varsuk:878](../scripts\game\vehicles\vm_csat.gd#L878)
- commander's cupola (right) with the 12.7 mm, gunner's sight (left front) ó [VmCsat._varsuk:884](../scripts\game\vehicles\vm_csat.gd#L884)
- Drozd launchers on the flanks, their radar heads on the cheeks, smoke ó [VmCsat._varsuk:888](../scripts\game\vehicles\vm_csat.gd#L888)
- antennas at the bustle's back corners ó [VmCsat._varsuk:897](../scripts\game\vehicles\vm_csat.gd#L897)
- stowage on the bustle's back, a wind sensor mast ó [VmCsat._varsuk:899](../scripts\game\vehicles\vm_csat.gd#L899)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._cupola_mg`, `VmCsat._era`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### water_scooter

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup ó [VmBoat._scooter:1103](../scripts\game\vehicles\vm_boat.gd#L1103)
- the bumper strake round the sheer and a livery band along each side ó [VmBoat._scooter:1111](../scripts\game\vehicles\vm_boat.gd#L1111)
- low gunwale lips round the footwells ó [VmBoat._scooter:1120](../scripts\game\vehicles\vm_boat.gd#L1120)
- sponsons near the stern ó [VmBoat._scooter:1127](../scripts\game\vehicles\vm_boat.gd#L1127)
- the hood: a rounded dome rising from the bow to the handlebar pod ó [VmBoat._scooter:1131](../scripts\game\vehicles\vm_boat.gd#L1131)
- the pedestal and the stepped three-place saddle on it ó [VmBoat._scooter:1139](../scripts\game\vehicles\vm_boat.gd#L1139)
- footwell mats ó [VmBoat._scooter:1154](../scripts\game\vehicles\vm_boat.gd#L1154)
- the boarding platform, its step and the grab handle behind the saddle ó [VmBoat._scooter:1156](../scripts\game\vehicles\vm_boat.gd#L1156)
- jet nozzle and reverse gate under the stern, tow eyes at both ends ó [VmBoat._scooter:1162](../scripts\game\vehicles\vm_boat.gd#L1162)
- the handlebar pod, bars and grips, a smoked visor, the display ó [VmBoat._scooter:1168](../scripts\game\vehicles\vm_boat.gd#L1168)
- mirrors on stalks off the pod ó [VmBoat._scooter:1173](../scripts\game\vehicles\vm_boat.gd#L1173)
- a strap across the pillion seat, grey panels down the pedestal's sides, air vents on the hood's shoulders, the fuel cap ó [VmBoat._scooter:1180](../scripts\game\vehicles\vm_boat.gd#L1180)
- (on the hood's dome section at z = -0.75: half-width 0.495 from 0.464 up 0.441) ó [VmBoat._scooter:1185](../scripts\game\vehicles\vm_boat.gd#L1185)
- the hood's storage hatch seam ó [VmBoat._scooter:1191](../scripts\game\vehicles\vm_boat.gd#L1191)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cushion`, `VmBoat._dome`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### wipeout

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.leaf`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleWeapons.rotary`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup ó [VmAttack._wipeout:809](../scripts\game\vehicles\vm_attack.gd#L809)
- [z, cx, cy, chine half-width, height above the chine, depth below, deck half-width, belly half-width, ridge] ó [VmAttack._wipeout:813](../scripts\game\vehicles\vm_attack.gd#L813)
- panel joints: thin raised frames round the fuselage ó [VmAttack._wipeout:832](../scripts\game\vehicles\vm_attack.gd#L832)

**Local helper construction:** `VmAttack._canopy_half`, `VmAttack._decal`, `VmAttack._facet`, `VmAttack._falchion`, `VmAttack._fbody`, `VmAttack._gear_nodes`, `VmAttack._hring`, `VmAttack._lathe`, `VmAttack._nac_half`, `VmAttack._sheet`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmAttack._wip_cockpit`, `VmAttack._wip_details`, `VmAttack._wip_engines`, `VmAttack._wip_gear`, `VmAttack._wip_gun`, `VmAttack._wip_stores`, `VmAttack._wip_tail`, `VmAttack._wip_wing`, `VmAttack._wst`, `VmAttack._zigzag`, `VmPlane._foil_t`, `VmPlane._sp`, `VmPlane._tri`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### xian

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.pitot`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.nav_light`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehiclePropellers.disc_material`.

**Authored sections:**

- Unlabelled construction / setup ó [VmPlane._xian:1435](../scripts\game\vehicles\vm_plane.gd#L1435)
- the stepped cockpit: the gunner's bubble low in front, the pilot's above ó [VmPlane._xian:1455](../scripts\game\vehicles\vm_plane.gd#L1455)
- the chin turret: a twin 23 mm that traverses ó [VmPlane._xian:1464](../scripts\game\vehicles\vm_plane.gd#L1464)
- troop doors on both sides, the rear ramp ó [VmPlane._xian:1472](../scripts\game\vehicles\vm_plane.gd#L1472)
- the wings, a lift fan in each, ailerons outboard ó [VmPlane._xian:1482](../scripts\game\vehicles\vm_plane.gd#L1482)
- wingtip pod with the lights ó [VmPlane._xian:1490](../scripts\game\vehicles\vm_plane.gd#L1490)
- stub wings below, with their stores ó [VmPlane._xian:1493](../scripts\game\vehicles\vm_plane.gd#L1493)
- twin turbofans high on the back, vectoring nozzles, a fairing between them ó [VmPlane._xian:1508](../scripts\game\vehicles\vm_plane.gd#L1508)
- twin tails canted outboard of the engines, rudders ó [VmPlane._xian:1522](../scripts\game\vehicles\vm_plane.gd#L1522)
- probes, antennas, the sensor under the nose ó [VmPlane._xian:1524](../scripts\game\vehicles\vm_plane.gd#L1524)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.lift_fan`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fender`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleCloth.roll`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.filler`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.hose_reel`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleMounts.boom`, `VehicleMounts.boom_box`, `VehicleMounts.bumper`, `VehicleMounts.hitch`, `VehicleMounts.light_guard`, `VehicleMounts.turret_ring`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleRunningGear.fuel_tank`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup ó [VmIndep._zamak:777](../scripts\game\vehicles\vm_indep.gd#L777)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`.

## Local helper section index

### VmAttack._a10_cockpit

- Unlabelled construction / setup ó [VmAttack._a10_cockpit:364](../scripts\game\vehicles\vm_attack.gd#L364)
- the windscreen bow, the canopy's own front and rear frames ó [VmAttack._a10_cockpit:375](../scripts\game\vehicles\vm_attack.gd#L375)
- the windscreen's two corner posts: a flat front panel and side quarter lights ó [VmAttack._a10_cockpit:379](../scripts\game\vehicles\vm_attack.gd#L379)
- the canopy rails along both sills ó [VmAttack._a10_cockpit:383](../scripts\game\vehicles\vm_attack.gd#L383)
- the fairing behind the canopy, down into the spine ó [VmAttack._a10_cockpit:387](../scripts\game\vehicles\vm_attack.gd#L387)
- the refuelling receptacle (UARRSI) on the nose, its slipway lines ó [VmAttack._a10_cockpit:392](../scripts\game\vehicles\vm_attack.gd#L392)
- the boarding ladder's door under the left canopy rail ó [VmAttack._a10_cockpit:399](../scripts\game\vehicles\vm_attack.gd#L399)

### VmAttack._a10_details

- Unlabelled construction / setup ó [VmAttack._a10_details:688](../scripts\game\vehicles\vm_attack.gd#L688)
- navigation lights on the Hoerner tips, the anti-collision strobes ó [VmAttack._a10_details:689](../scripts\game\vehicles\vm_attack.gd#L689)
- the formation ("slime") lights: pale strips on the nose, the tail and fins ó [VmAttack._a10_details:694](../scripts\game\vehicles\vm_attack.gd#L694)
- the chaff and flare dispensers under the wing tips ó [VmAttack._a10_details:700](../scripts\game\vehicles\vm_attack.gd#L700)
- static dischargers trailing from the ailerons, the elevators and rudders ó [VmAttack._a10_details:703](../scripts\game\vehicles\vm_attack.gd#L703)
- antennas: UHF/VHF blades on the spine and belly, the IFF and TACAN, a GPS dome ó [VmAttack._a10_details:714](../scripts\game\vehicles\vm_attack.gd#L714)
- the angle-of-attack vane and a pitot probe on the nose's flanks ó [VmAttack._a10_details:721](../scripts\game\vehicles\vm_attack.gd#L721)
- the false canopy painted under the nose ó [VmAttack._a10_details:725](../scripts\game\vehicles\vm_attack.gd#L725)
- a Rebel airframe: their identification panels on the wings ó [VmAttack._a10_details:734](../scripts\game\vehicles\vm_attack.gd#L734)
- the low-vis star-and-bar on the nacelles' outer flanks, the upper left and the lower right wing; "USAF" is left off at this size ó [VmAttack._a10_details:737](../scripts\game\vehicles\vm_attack.gd#L737)
- "USAF" across the upper right wing and the lower left one, read from behind ó [VmAttack._a10_details:751](../scripts\game\vehicles\vm_attack.gd#L751)

### VmAttack._a10_engines

- Unlabelled construction / setup ó [VmAttack._a10_engines:474](../scripts\game\vehicles\vm_attack.gd#L474)
- inside the intake: the fan face, its blades and spinner ó [VmAttack._a10_engines:492](../scripts\game\vehicles\vm_attack.gd#L492)
- the fan exhaust: the dark annulus between the core cowl and the nozzle ó [VmAttack._a10_engines:499](../scripts\game\vehicles\vm_attack.gd#L499)
- cowling joints round the nacelle ó [VmAttack._a10_engines:502](../scripts\game\vehicles\vm_attack.gd#L502)
- the pylon from the fuselage shoulder to the nacelle's inner flank ó [VmAttack._a10_engines:505](../scripts\game\vehicles\vm_attack.gd#L505)

### VmAttack._a10_gear

- Unlabelled construction / setup ó [VmAttack._a10_gear:565](../scripts\game\vehicles\vm_attack.gd#L565)
- the open well along the pod's belly the wheel hangs out of ó [VmAttack._a10_gear:577](../scripts\game\vehicles\vm_attack.gd#L577)
- the chaff and flare dispensers in the pod's tail ó [VmAttack._a10_gear:579](../scripts\game\vehicles\vm_attack.gd#L579)
- retracted: the tyre a third out of the pod ó [VmAttack._a10_gear:581](../scripts\game\vehicles\vm_attack.gd#L581)
- let down: the wheel below and a little aft, the leg slanting from the pod's nose, its drag brace and torque links ó [VmAttack._a10_gear:585](../scripts\game\vehicles\vm_attack.gd#L585)
- the nose gear well's doors (closed in flight) ó [VmAttack._a10_gear:594](../scripts\game\vehicles\vm_attack.gd#L594)
- the taxi light on the leg ó [VmAttack._a10_gear:609](../scripts\game\vehicles\vm_attack.gd#L609)
- the two long well doors hanging open ó [VmAttack._a10_gear:611](../scripts\game\vehicles\vm_attack.gd#L611)

### VmAttack._a10_gun

- Unlabelled construction / setup ó [VmAttack._a10_gun:407](../scripts\game\vehicles\vm_attack.gd#L407)
- the gun port: a dark recess in the nose's lower face ó [VmAttack._a10_gun:408](../scripts\game\vehicles\vm_attack.gd#L408)
- the seven barrels out of the port, held by the mid support ring and the muzzle clamp ó [VmAttack._a10_gun:411](../scripts\game\vehicles\vm_attack.gd#L411)
- gun gas soot fanning back under the nose ó [VmAttack._a10_gun:416](../scripts\game\vehicles\vm_attack.gd#L416)

### VmAttack._a10_stores

- Unlabelled construction / setup ó [VmAttack._a10_stores:623](../scripts\game\vehicles\vm_attack.gd#L623)
- a Maverick on a single LAU-117 rail ó [VmAttack._a10_stores:631](../scripts\game\vehicles\vm_attack.gd#L631)
- two Mavericks on the shoulders of a LAU-88 ó [VmAttack._a10_stores:636](../scripts\game\vehicles\vm_attack.gd#L636)
- two Sidewinders on a LAU-105 dual rail ó [VmAttack._a10_stores:649](../scripts\game\vehicles\vm_attack.gd#L649)
- the fuselage stations either side of the centre line, empty ó [VmAttack._a10_stores:654](../scripts\game\vehicles\vm_attack.gd#L654)

### VmAttack._a10_tail

- Unlabelled construction / setup ó [VmAttack._a10_tail:517](../scripts\game\vehicles\vm_attack.gd#L517)
- the elevator trim tabs ó [VmAttack._a10_tail:521](../scripts\game\vehicles\vm_attack.gd#L521)
- the fin-tip cap and its tail light ó [VmAttack._a10_tail:533](../scripts\game\vehicles\vm_attack.gd#L533)
- Moody's "FT" tail code, the serial and a black fin-tip band, both sides ó [VmAttack._a10_tail:541](../scripts\game\vehicles\vm_attack.gd#L541)
- (the band runs from just behind the fin's leading edge to the rudder's end) ó [VmAttack._a10_tail:553](../scripts\game\vehicles\vm_attack.gd#L553)

### VmAttack._a10_wing

- Unlabelled construction / setup ó [VmAttack._a10_wing:432](../scripts\game\vehicles\vm_attack.gd#L432)
- the Hoerner tips: the skin curling down at the ends ó [VmAttack._a10_wing:436](../scripts\game\vehicles\vm_attack.gd#L436)
- the deceleron split line along each aileron's trailing edge ó [VmAttack._a10_wing:438](../scripts\game\vehicles\vm_attack.gd#L438)
- panel lines on the upper skins: the slat and leading-edge panels, the spar joints, the centre-section break, the walkway ó [VmAttack._a10_wing:445](../scripts\game\vehicles\vm_attack.gd#L445)
- the black no-step walkway outline by the root ó [VmAttack._a10_wing:462](../scripts\game\vehicles\vm_attack.gd#L462)

### VmAttack._canopy_half

- Unlabelled construction / setup ó [VmAttack._canopy_half:885](../scripts\game\vehicles\vm_attack.gd#L885)

### VmAttack._decal

- Unlabelled construction / setup ó [VmAttack._decal:130](../scripts\game\vehicles\vm_attack.gd#L130)

### VmAttack._ecm_pod

- Unlabelled construction / setup ó [VmAttack._ecm_pod:675](../scripts\game\vehicles\vm_attack.gd#L675)
- the radomes darker ó [VmAttack._ecm_pod:681](../scripts\game\vehicles\vm_attack.gd#L681)

### VmAttack._facet

- Unlabelled construction / setup ó [VmAttack._facet:79](../scripts\game\vehicles\vm_attack.gd#L79)

### VmAttack._falchion

- Unlabelled construction / setup ó [VmAttack._falchion:1127](../scripts\game\vehicles\vm_attack.gd#L1127)

### VmAttack._fbody

- Unlabelled construction / setup ó [VmAttack._fbody:788](../scripts\game\vehicles\vm_attack.gd#L788)

### VmAttack._fin_at

- Unlabelled construction / setup ó [VmAttack._fin_at:267](../scripts\game\vehicles\vm_attack.gd#L267)

### VmAttack._gear_nodes

- Unlabelled construction / setup ó [VmAttack._gear_nodes:282](../scripts\game\vehicles\vm_attack.gd#L282)

### VmAttack._hring

- Unlabelled construction / setup ó [VmAttack._hring:63](../scripts\game\vehicles\vm_attack.gd#L63)

### VmAttack._lathe

- Unlabelled construction / setup ó [VmAttack._lathe:52](../scripts\game\vehicles\vm_attack.gd#L52)

### VmAttack._nac_half

- Unlabelled construction / setup ó [VmAttack._nac_half:957](../scripts\game\vehicles\vm_attack.gd#L957)

### VmAttack._sec_pt

- Unlabelled construction / setup ó [VmAttack._sec_pt:225](../scripts\game\vehicles\vm_attack.gd#L225)

### VmAttack._sheet

- Unlabelled construction / setup ó [VmAttack._sheet:86](../scripts\game\vehicles\vm_attack.gd#L86)
- away from the axis (measured across the ring, not along it) ó [VmAttack._sheet:107](../scripts\game\vehicles\vm_attack.gd#L107)

### VmAttack._skin_x

- Unlabelled construction / setup ó [VmAttack._skin_x:247](../scripts\game\vehicles\vm_attack.gd#L247)

### VmAttack._skin_y

- Unlabelled construction / setup ó [VmAttack._skin_y:236](../scripts\game\vehicles\vm_attack.gd#L236)

### VmAttack._sniper

- Unlabelled construction / setup ó [VmAttack._sniper:662](../scripts\game\vehicles\vm_attack.gd#L662)
- the head's joint, its window looking forward and down ó [VmAttack._sniper:666](../scripts\game\vehicles\vm_attack.gd#L666)

### VmAttack._star_bar

- Unlabelled construction / setup ó [VmAttack._star_bar:193](../scripts\game\vehicles\vm_attack.gd#L193)
- the bars: upper edge level with the star's arms, a radius long beyond the ring ó [VmAttack._star_bar:209](../scripts\game\vehicles\vm_attack.gd#L209)

### VmAttack._strokes

- Unlabelled construction / setup ó [VmAttack._strokes:136](../scripts\game\vehicles\vm_attack.gd#L136)

### VmAttack._text

- Unlabelled construction / setup ó [VmAttack._text:175](../scripts\game\vehicles\vm_attack.gd#L175)

### VmAttack._wheel

- Unlabelled construction / setup ó [VmAttack._wheel:304](../scripts\game\vehicles\vm_attack.gd#L304)

### VmAttack._wing_y

- Unlabelled construction / setup ó [VmAttack._wing_y:257](../scripts\game\vehicles\vm_attack.gd#L257)

### VmAttack._wip_cockpit

- Unlabelled construction / setup ó [VmAttack._wip_cockpit:853](../scripts\game\vehicles\vm_attack.gd#L853)
- [z, base height, half-width, height] ó [VmAttack._wip_cockpit:854](../scripts\game\vehicles\vm_attack.gd#L854)
- (a faint gold in the glass: the radar-reflective coating of a stealthy canopy) ó [VmAttack._wip_cockpit:860](../scripts\game\vehicles\vm_attack.gd#L860)
- frames: the armoured pane's bow, a hoop over the middle ó [VmAttack._wip_cockpit:862](../scripts\game\vehicles\vm_attack.gd#L862)
- the sills ó [VmAttack._wip_cockpit:869](../scripts\game\vehicles\vm_attack.gd#L869)
- the spine: a faceted fairing from the canopy back between the engines ó [VmAttack._wip_cockpit:875](../scripts\game\vehicles\vm_attack.gd#L875)
- the air-refuelling receptacle's door on the spine ó [VmAttack._wip_cockpit:879](../scripts\game\vehicles\vm_attack.gd#L879)

### VmAttack._wip_details

- Unlabelled construction / setup ó [VmAttack._wip_details:1139](../scripts\game\vehicles\vm_attack.gd#L1139)
- formation light strips along the chines ó [VmAttack._wip_details:1143](../scripts\game\vehicles\vm_attack.gd#L1143)
- antennas on the spine and belly, the angle-of-attack probes ó [VmAttack._wip_details:1149](../scripts\game\vehicles\vm_attack.gd#L1149)
- static dischargers on the wing tips ó [VmAttack._wip_details:1159](../scripts\game\vehicles\vm_attack.gd#L1159)
- light grey low-vis markings: the star-and-bar on the fuselage's upper flanks and the left wing, a tail code and serial on the fins ó [VmAttack._wip_details:1170](../scripts\game\vehicles\vm_attack.gd#L1170)
- the fin's outer skin, q.y up its span from the root: the airfoil's thickness there, at that point of the chord ó [VmAttack._wip_details:1189](../scripts\game\vehicles\vm_attack.gd#L1189)

### VmAttack._wip_engines

- Unlabelled construction / setup ó [VmAttack._wip_engines:965](../scripts\game\vehicles\vm_attack.gd#L965)
- the outer skin from the lip aft to the nozzle ó [VmAttack._wip_engines:973](../scripts\game\vehicles\vm_attack.gd#L973)
- the inlet's lip and duct, the fan face inside ó [VmAttack._wip_engines:977](../scripts\game\vehicles\vm_attack.gd#L977)
- the nozzle: its lip, the jet pipe's wall, the cone in it ó [VmAttack._wip_engines:987](../scripts\game\vehicles\vm_attack.gd#L987)
- cowling seams ó [VmAttack._wip_engines:993](../scripts\game\vehicles\vm_attack.gd#L993)
- the broad pylon blending the nacelle into the spine, tapered at both ends ó [VmAttack._wip_engines:998](../scripts\game\vehicles\vm_attack.gd#L998)
- the ends drawn in towards the pylon's middle ó [VmAttack._wip_engines:1009](../scripts\game\vehicles\vm_attack.gd#L1009)

### VmAttack._wip_gear

- Unlabelled construction / setup ó [VmAttack._wip_gear:1048](../scripts\game\vehicles\vm_attack.gd#L1048)
- the doors' seams along the belly, saw-toothed fore and aft ó [VmAttack._wip_gear:1059](../scripts\game\vehicles\vm_attack.gd#L1059)
- the pod's bay doors hanging open either side ó [VmAttack._wip_gear:1073](../scripts\game\vehicles\vm_attack.gd#L1073)
- the nose gear on the centre line behind the gun fairing, its doors ó [VmAttack._wip_gear:1076](../scripts\game\vehicles\vm_attack.gd#L1076)

### VmAttack._wip_gun

- Unlabelled construction / setup ó [VmAttack._wip_gun:891](../scripts\game\vehicles\vm_attack.gd#L891)
- the barrels from inside the fairing, one clamp near the muzzles ó [VmAttack._wip_gun:897](../scripts\game\vehicles\vm_attack.gd#L897)
- the EO/IR targeting turret under the nose, its window looking ahead ó [VmAttack._wip_gun:901](../scripts\game\vehicles\vm_attack.gd#L901)

### VmAttack._wip_stores

- Unlabelled construction / setup ó [VmAttack._wip_stores:1100](../scripts\game\vehicles\vm_attack.gd#L1100)
- three Macers on a triple rack: two on the shoulders, one below ó [VmAttack._wip_stores:1108](../scripts\game\vehicles\vm_attack.gd#L1108)

### VmAttack._wip_tail

- Unlabelled construction / setup ó [VmAttack._wip_tail:1023](../scripts\game\vehicles\vm_attack.gd#L1023)
- the fin-tip fairing with its light ó [VmAttack._wip_tail:1037](../scripts\game\vehicles\vm_attack.gd#L1037)

### VmAttack._wip_wing

- Unlabelled construction / setup ó [VmAttack._wip_wing:913](../scripts\game\vehicles\vm_attack.gd#L913)
- the leading-edge root extensions: thin faceted strakes running forward from the wing roots along the chines ó [VmAttack._wip_wing:918](../scripts\game\vehicles\vm_attack.gd#L918)
- the deceleron split along the outer trailing edges ó [VmAttack._wip_wing:923](../scripts\game\vehicles\vm_attack.gd#L923)
- the lighter grey under the wing ó [VmAttack._wip_wing:929](../scripts\game\vehicles\vm_attack.gd#L929)
- panel lines on the upper skin ó [VmAttack._wip_wing:939](../scripts\game\vehicles\vm_attack.gd#L939)

### VmAttack._wst

- Unlabelled construction / setup ó [VmAttack._wst:770](../scripts\game\vehicles\vm_attack.gd#L770)

### VmAttack._zigzag

- Unlabelled construction / setup ó [VmAttack._zigzag:155](../scripts\game\vehicles\vm_attack.gd#L155)

### VmBoat._aim

- Unlabelled construction / setup ó [VmBoat._aim:278](../scripts\game\vehicles\vm_boat.gd#L278)

### VmBoat._bake

- Unlabelled construction / setup ó [VmBoat._bake:440](../scripts\game\vehicles\vm_boat.gd#L440)

### VmBoat._band

- Unlabelled construction / setup ó [VmBoat._band:156](../scripts\game\vehicles\vm_boat.gd#L156)

### VmBoat._band_mesh

- Unlabelled construction / setup ó [VmBoat._band_mesh:187](../scripts\game\vehicles\vm_boat.gd#L187)

### VmBoat._beam

- Unlabelled construction / setup ó [VmBoat._beam:148](../scripts\game\vehicles\vm_boat.gd#L148)

### VmBoat._cleat

- Unlabelled construction / setup ó [VmBoat._cleat:386](../scripts\game\vehicles\vm_boat.gd#L386)

### VmBoat._cushion

- Unlabelled construction / setup ó [VmBoat._cushion:1197](../scripts\game\vehicles\vm_boat.gd#L1197)

### VmBoat._deck_mesh

- Unlabelled construction / setup ó [VmBoat._deck_mesh:201](../scripts\game\vehicles\vm_boat.gd#L201)

### VmBoat._dome

- Unlabelled construction / setup ó [VmBoat._dome:1205](../scripts\game\vehicles\vm_boat.gd#L1205)
- At the last station rounding can put sin(PI) just below zero; a fractional power would make the hood's vertices and normals NaN. ó [VmBoat._dome:1209](../scripts\game\vehicles\vm_boat.gd#L1209)

### VmBoat._foil

- Unlabelled construction / setup ó [VmBoat._foil:257](../scripts\game\vehicles\vm_boat.gd#L257)

### VmBoat._hull

- Unlabelled construction / setup ó [VmBoat._hull:121](../scripts\game\vehicles\vm_boat.gd#L121)

### VmBoat._hw

- Unlabelled construction / setup ó [VmBoat._hw:131](../scripts\game\vehicles\vm_boat.gd#L131)

### VmBoat._offset

- Unlabelled construction / setup ó [VmBoat._offset:322](../scripts\game\vehicles\vm_boat.gd#L322)

### VmBoat._outboard

- the clamp bracket on the transom and its tilt tube ó [VmBoat._outboard:401](../scripts\game\vehicles\vm_boat.gd#L401)
- swivel bracket and the leg, a streamlined strut down to the gearcase ó [VmBoat._outboard:412](../scripts\game\vehicles\vm_boat.gd#L412)
- anti-ventilation plate, the gearcase torpedo, skeg and propeller ó [VmBoat._outboard:416](../scripts\game\vehicles\vm_boat.gd#L416)
- the lower cowl (apron), the cowling with its parting line and air intake ó [VmBoat._outboard:422](../scripts\game\vehicles\vm_boat.gd#L422)

### VmBoat._panel

- Unlabelled construction / setup ó [VmBoat._panel:364](../scripts\game\vehicles\vm_boat.gd#L364)

### VmBoat._prop

- Unlabelled construction / setup ó [VmBoat._prop:391](../scripts\game\vehicles\vm_boat.gd#L391)

### VmBoat._pt

- Unlabelled construction / setup ó [VmBoat._pt:381](../scripts\game\vehicles\vm_boat.gd#L381)

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

- Unlabelled construction / setup ó [VmBoat._scale_xz:1090](../scripts\game\vehicles\vm_boat.gd#L1090)

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

- Unlabelled construction / setup ó [VmCiv._bent:180](../scripts\game\vehicles\vm_civ.gd#L180)

### VmCiv._car_details

- Unlabelled construction / setup ó [VmCiv._car_details:1172](../scripts\game\vehicles\vm_civ.gd#L1172)

### VmCiv._face

- Unlabelled construction / setup ó [VmCiv._face:141](../scripts\game\vehicles\vm_civ.gd#L141)

### VmCiv._flare

- Unlabelled construction / setup ó [VmCiv._flare:103](../scripts\game\vehicles\vm_civ.gd#L103)

### VmCiv._glasshouse

- Unlabelled construction / setup ó [VmCiv._glasshouse:1128](../scripts\game\vehicles\vm_civ.gd#L1128)
- Fill the complement of the actual window apertures, including the wide C-pillars. This preserves the coupe and pickup silhouettes. ó [VmCiv._glasshouse:1155](../scripts\game\vehicles\vm_civ.gd#L1155)

### VmCiv._hatch_sport

- Unlabelled construction / setup ó [VmCiv._hatch_sport:1105](../scripts\game\vehicles\vm_civ.gd#L1105)
- spoiler over the hatch on two stays, its end plates ó [VmCiv._hatch_sport:1111](../scripts\game\vehicles\vm_civ.gd#L1111)

### VmCiv._inset

- Unlabelled construction / setup ó [VmCiv._inset:79](../scripts\game\vehicles\vm_civ.gd#L79)

### VmCiv._jerrycan

- Unlabelled construction / setup ó [VmCiv._jerrycan:215](../scripts\game\vehicles\vm_civ.gd#L215)

### VmCiv._lamp

- Unlabelled construction / setup ó [VmCiv._lamp:193](../scripts\game\vehicles\vm_civ.gd#L193)

### VmCiv._lmg

- Unlabelled construction / setup ó [VmCiv._lmg:236](../scripts\game\vehicles\vm_civ.gd#L236)

### VmCiv._m2

- Unlabelled construction / setup ó [VmCiv._m2:230](../scripts\game\vehicles\vm_civ.gd#L230)

### VmCiv._mb_gun

- Unlabelled construction / setup ó [VmCiv._mb_gun:614](../scripts\game\vehicles\vm_civ.gd#L614)
- ammunition stowed in the back ó [VmCiv._mb_gun:618](../scripts\game\vehicles\vm_civ.gd#L618)

### VmCiv._mb_top

- Unlabelled construction / setup ó [VmCiv._mb_top:595](../scripts\game\vehicles\vm_civ.gd#L595)
- the door frames the curtains zip into, the bows under the roof ó [VmCiv._mb_top:605](../scripts\game\vehicles\vm_civ.gd#L605)

### VmCiv._mirror

- Unlabelled construction / setup ó [VmCiv._mirror:208](../scripts\game\vehicles\vm_civ.gd#L208)

### VmCiv._off_at

- Unlabelled construction / setup ó [VmCiv._off_at:419](../scripts\game\vehicles\vm_civ.gd#L419)
- a crate of rounds lashed in the bed ó [VmCiv._off_at:426](../scripts\game\vehicles\vm_civ.gd#L426)

### VmCiv._off_hmg

- Unlabelled construction / setup ó [VmCiv._off_hmg:389](../scripts\game\vehicles\vm_civ.gd#L389)
- ammo cans and a spare box by the gunner's feet ó [VmCiv._off_hmg:395](../scripts\game\vehicles\vm_civ.gd#L395)
- the shield: a flat plate with the barrel slot, angled wings, a vision slit ó [VmCiv._off_hmg:406](../scripts\game\vehicles\vm_civ.gd#L406)

### VmCiv._off_repair

- Unlabelled construction / setup ó [VmCiv._off_repair:442](../scripts\game\vehicles\vm_civ.gd#L442)
- the davit: a post in the corner, a boom swung out over the tailgate ó [VmCiv._off_repair:458](../scripts\game\vehicles\vm_civ.gd#L458)
- beacon on the roof ó [VmCiv._off_repair:467](../scripts\game\vehicles\vm_civ.gd#L467)

### VmCiv._paint

- Unlabelled construction / setup ó [VmCiv._paint:69](../scripts\game\vehicles\vm_civ.gd#L69)
- a little dust and sun on top of it ó [VmCiv._paint:72](../scripts\game\vehicles\vm_civ.gd#L72)

### VmCiv._pane

- Unlabelled construction / setup ó [VmCiv._pane:135](../scripts\game\vehicles\vm_civ.gd#L135)

### VmCiv._plate

- Unlabelled construction / setup ó [VmCiv._plate:201](../scripts\game\vehicles\vm_civ.gd#L201)

### VmCiv._ring

- Unlabelled construction / setup ó [VmCiv._ring:146](../scripts\game\vehicles\vm_civ.gd#L146)

### VmCiv._rod

- Unlabelled construction / setup ó [VmCiv._rod:175](../scripts\game\vehicles\vm_civ.gd#L175)

### VmCiv._slab

- Unlabelled construction / setup ó [VmCiv._slab:166](../scripts\game\vehicles\vm_civ.gd#L166)

### VmCiv._spare

- Unlabelled construction / setup ó [VmCiv._spare:221](../scripts\game\vehicles\vm_civ.gd#L221)

### VmCiv._spg9

- Unlabelled construction / setup ó [VmCiv._spg9:241](../scripts\game\vehicles\vm_civ.gd#L241)
- the thin forward tube, the fat chamber, the venturi flaring at the back ó [VmCiv._spg9:242](../scripts\game\vehicles\vm_civ.gd#L242)
- clamping bands, the sight on the left, trigger group underneath ó [VmCiv._spg9:249](../scripts\game\vehicles\vm_civ.gd#L249)
- the saddle the tube sits in ó [VmCiv._spg9:256](../scripts\game\vehicles\vm_civ.gd#L256)

### VmCiv._strut

- Unlabelled construction / setup ó [VmCiv._strut:160](../scripts\game\vehicles\vm_civ.gd#L160)

### VmCiv._team_side

- Unlabelled construction / setup ó [VmCiv._team_side:475](../scripts\game\vehicles\vm_civ.gd#L475)

### VmCiv._truck_bed

- Unlabelled construction / setup ó [VmCiv._truck_bed:720](../scripts\game\vehicles\vm_civ.gd#L720)
- headboard and a cab guard of bars ó [VmCiv._truck_bed:725](../scripts\game\vehicles\vm_civ.gd#L725)
- dropsides on stake posts, the tailgate; their hinges and catches ó [VmCiv._truck_bed:731](../scripts\game\vehicles\vm_civ.gd#L731)
- a bench with a back along the side ó [VmCiv._truck_bed:739](../scripts\game\vehicles\vm_civ.gd#L739)

### VmCiv._truck_box

- Unlabelled construction / setup ó [VmCiv._truck_box:753](../scripts\game\vehicles\vm_civ.gd#L753)
- barn doors: their seam, hinges and the locking bars ó [VmCiv._truck_box:764](../scripts\game\vehicles\vm_civ.gd#L764)
- the wind deflector over the cab ó [VmCiv._truck_box:772](../scripts\game\vehicles\vm_civ.gd#L772)

### VmCiv._truck_rear

- Unlabelled construction / setup ó [VmCiv._truck_rear:781](../scripts\game\vehicles\vm_civ.gd#L781)

### VmCiv._van_ambulance

- Unlabelled construction / setup ó [VmCiv._van_ambulance:900](../scripts\game\vehicles\vm_civ.gd#L900)
- the big cross on the roof ó [VmCiv._van_ambulance:913](../scripts\game\vehicles\vm_civ.gd#L913)
- light bar: red lenses either side of white ó [VmCiv._van_ambulance:916](../scripts\game\vehicles\vm_civ.gd#L916)

### VmCiv._van_services

- Unlabelled construction / setup ó [VmCiv._van_services:926](../scripts\game\vehicles\vm_civ.gd#L926)
- roof rack rails on their feet ó [VmCiv._van_services:931](../scripts\game\vehicles\vm_civ.gd#L931)
- the ladder ó [VmCiv._van_services:937](../scripts\game\vehicles\vm_civ.gd#L937)
- amber beacon over the cab ó [VmCiv._van_services:942](../scripts\game\vehicles\vm_civ.gd#L942)
- red and white chevrons on the lower rear doors ó [VmCiv._van_services:945](../scripts\game\vehicles\vm_civ.gd#L945)

### VmCiv._xbody

- Unlabelled construction / setup ó [VmCiv._xbody:99](../scripts\game\vehicles\vm_civ.gd#L99)

### VmCiv._yloft

- Unlabelled construction / setup ó [VmCiv._yloft:109](../scripts\game\vehicles\vm_civ.gd#L109)

### VmCiv._zring

- Unlabelled construction / setup ó [VmCiv._zring:152](../scripts\game\vehicles\vm_civ.gd#L152)

### VmCore._airframe

- Unlabelled construction / setup ó [VmCore._airframe:1379](../scripts\game\vehicles\vm_core.gd#L1379)

### VmCore._ammo_can

- Unlabelled construction / setup ó [VmCore._ammo_can:250](../scripts\game\vehicles\vm_core.gd#L250)

### VmCore._antenna

- Unlabelled construction / setup ó [VmCore._antenna:207](../scripts\game\vehicles\vm_core.gd#L207)

### VmCore._bar

- Unlabelled construction / setup ó [VmCore._bar:106](../scripts\game\vehicles\vm_core.gd#L106)

### VmCore._belt

- Unlabelled construction / setup ó [VmCore._belt:188](../scripts\game\vehicles\vm_core.gd#L188)

### VmCore._bx

- Unlabelled construction / setup ó [VmCore._bx:74](../scripts\game\vehicles\vm_core.gd#L74)

### VmCore._cam

- Unlabelled construction / setup ó [VmCore._cam:64](../scripts\game\vehicles\vm_core.gd#L64)

### VmCore._dshk

- Unlabelled construction / setup ó [VmCore._dshk:501](../scripts\game\vehicles\vm_core.gd#L501)

### VmCore._eye

- Unlabelled construction / setup ó [VmCore._eye:256](../scripts\game\vehicles\vm_core.gd#L256)

### VmCore._fuel_tank

- Unlabelled construction / setup ó [VmCore._fuel_tank:1500](../scripts\game\vehicles\vm_core.gd#L1500)

### VmCore._hatch

- Unlabelled construction / setup ó [VmCore._hatch:238](../scripts\game\vehicles\vm_core.gd#L238)

### VmCore._hilux_dshk

- Unlabelled construction / setup ó [VmCore._hilux_dshk:878](../scripts\game\vehicles\vm_core.gd#L878)
- kit in the bed: ammo boxes, the spare tyre, a jerrycan, a crate ó [VmCore._hilux_dshk:885](../scripts\game\vehicles\vm_core.gd#L885)
- the traversing head: the yoke, the gun, the shield, a box on the cradle ó [VmCore._hilux_dshk:892](../scripts\game\vehicles\vm_core.gd#L892)

### VmCore._idler

- Unlabelled construction / setup ó [VmCore._idler:181](../scripts\game\vehicles\vm_core.gd#L181)

### VmCore._jerry

- Unlabelled construction / setup ó [VmCore._jerry:244](../scripts\game\vehicles\vm_core.gd#L244)

### VmCore._lamp

- Unlabelled construction / setup ó [VmCore._lamp:193](../scripts\game\vehicles\vm_core.gd#L193)

### VmCore._m2

- Unlabelled construction / setup ó [VmCore._m2:266](../scripts\game\vehicles\vm_core.gd#L266)

### VmCore._mirror

- Unlabelled construction / setup ó [VmCore._mirror:1695](../scripts\game\vehicles\vm_core.gd#L1695)

### VmCore._mmg

- Unlabelled construction / setup ó [VmCore._mmg:273](../scripts\game\vehicles\vm_core.gd#L273)

### VmCore._oct

- Unlabelled construction / setup ó [VmCore._oct:150](../scripts\game\vehicles\vm_core.gd#L150)

### VmCore._on_face

- Unlabelled construction / setup ó [VmCore._on_face:123](../scripts\game\vehicles\vm_core.gd#L123)

### VmCore._path

- Unlabelled construction / setup ó [VmCore._path:101](../scripts\game\vehicles\vm_core.gd#L101)

### VmCore._periscope

- Unlabelled construction / setup ó [VmCore._periscope:232](../scripts\game\vehicles\vm_core.gd#L232)

### VmCore._rings

- Unlabelled construction / setup ó [VmCore._rings:134](../scripts\game\vehicles\vm_core.gd#L134)

### VmCore._road_wheel

- Unlabelled construction / setup ó [VmCore._road_wheel:157](../scripts\game\vehicles\vm_core.gd#L157)

### VmCore._round_ring

- Unlabelled construction / setup ó [VmCore._round_ring:486](../scripts\game\vehicles\vm_core.gd#L486)

### VmCore._rz

- Unlabelled construction / setup ó [VmCore._rz:142](../scripts\game\vehicles\vm_core.gd#L142)

### VmCore._shackle

- Unlabelled construction / setup ó [VmCore._shackle:226](../scripts\game\vehicles\vm_core.gd#L226)

### VmCore._smoke

- Unlabelled construction / setup ó [VmCore._smoke:214](../scripts\game\vehicles\vm_core.gd#L214)

### VmCore._sprocket

- Unlabelled construction / setup ó [VmCore._sprocket:162](../scripts\game\vehicles\vm_core.gd#L162)

### VmCore._taillight

- Unlabelled construction / setup ó [VmCore._taillight:201](../scripts\game\vehicles\vm_core.gd#L201)

### VmCore._tube

- Unlabelled construction / setup ó [VmCore._tube:96](../scripts\game\vehicles\vm_core.gd#L96)

### VmCore._zu23

- Unlabelled construction / setup ó [VmCore._zu23:915](../scripts\game\vehicles\vm_core.gd#L915)
- loose kit in the corners: ammunition boxes, a jerrycan ó [VmCore._zu23:920](../scripts\game\vehicles\vm_core.gd#L920)
- the side frames carrying the trunnions ó [VmCore._zu23:928](../scripts\game\vehicles\vm_core.gd#L928)
- the cradle, raised a little, with both guns ó [VmCore._zu23:931](../scripts\game\vehicles\vm_core.gd#L931)
- the ammunition box outboard of each gun, the spent-case chute under it ó [VmCore._zu23:939](../scripts\game\vehicles\vm_core.gd#L939)
- the gunner's seat and his sight on the left, the hand wheels, the second seat on the right ó [VmCore._zu23:945](../scripts\game\vehicles\vm_core.gd#L945)

### VmCore._zy

- Unlabelled construction / setup ó [VmCore._zy:113](../scripts\game\vehicles\vm_core.gd#L113)

### VmCsat._aim_y

- Unlabelled construction / setup ó [VmCsat._aim_y:98](../scripts\game\vehicles\vm_csat.gd#L98)

### VmCsat._antenna

- Unlabelled construction / setup ó [VmCsat._antenna:154](../scripts\game\vehicles\vm_csat.gd#L154)

### VmCsat._arch

- Unlabelled construction / setup ó [VmCsat._arch:128](../scripts\game\vehicles\vm_csat.gd#L128)

### VmCsat._cross

- Unlabelled construction / setup ó [VmCsat._cross:1338](../scripts\game\vehicles\vm_csat.gd#L1338)

### VmCsat._cupola_mg

- Unlabelled construction / setup ó [VmCsat._cupola_mg:850](../scripts\game\vehicles\vm_csat.gd#L850)

### VmCsat._era

- Unlabelled construction / setup ó [VmCsat._era:521](../scripts\game\vehicles\vm_csat.gd#L521)

### VmCsat._gun125

- Unlabelled construction / setup ó [VmCsat._gun125:840](../scripts\game\vehicles\vm_csat.gd#L840)

### VmCsat._hatch

- Unlabelled construction / setup ó [VmCsat._hatch:171](../scripts\game\vehicles\vm_csat.gd#L171)

### VmCsat._headlight

- Unlabelled construction / setup ó [VmCsat._headlight:139](../scripts\game\vehicles\vm_csat.gd#L139)

### VmCsat._jerrycan

- Unlabelled construction / setup ó [VmCsat._jerrycan:165](../scripts\game\vehicles\vm_csat.gd#L165)

### VmCsat._mx

- Unlabelled construction / setup ó [VmCsat._mx:89](../scripts\game\vehicles\vm_csat.gd#L89)

### VmCsat._onface

- Unlabelled construction / setup ó [VmCsat._onface:465](../scripts\game\vehicles\vm_csat.gd#L465)

### VmCsat._pane

- Unlabelled construction / setup ó [VmCsat._pane:120](../scripts\game\vehicles\vm_csat.gd#L120)

### VmCsat._periscope

- Unlabelled construction / setup ó [VmCsat._periscope:177](../scripts\game\vehicles\vm_csat.gd#L177)

### VmCsat._plate

- Unlabelled construction / setup ó [VmCsat._plate:114](../scripts\game\vehicles\vm_csat.gd#L114)

### VmCsat._rcws

- Unlabelled construction / setup ó [VmCsat._rcws:195](../scripts\game\vehicles\vm_csat.gd#L195)
- the trunnion arms either side of the cradle ó [VmCsat._rcws:198](../scripts\game\vehicles\vm_csat.gd#L198)
- The guns feed from the station's own box beside them, so none carries a can. ó [VmCsat._rcws:203](../scripts\game\vehicles\vm_csat.gd#L203)
- the sight head beside the gun under its lid, the ammunition box on the other side ó [VmCsat._rcws:217](../scripts\game\vehicles\vm_csat.gd#L217)

### VmCsat._running_gear

- Unlabelled construction / setup ó [VmCsat._running_gear:492](../scripts\game\vehicles\vm_csat.gd#L492)

### VmCsat._rwheel

- Unlabelled construction / setup ó [VmCsat._rwheel:477](../scripts\game\vehicles\vm_csat.gd#L477)

### VmCsat._rz

- Unlabelled construction / setup ó [VmCsat._rz:81](../scripts\game\vehicles\vm_csat.gd#L81)

### VmCsat._sec

- Unlabelled construction / setup ó [VmCsat._sec:75](../scripts\game\vehicles\vm_csat.gd#L75)

### VmCsat._slats

- Unlabelled construction / setup ó [VmCsat._slats:1005](../scripts\game\vehicles\vm_csat.gd#L1005)

### VmCsat._smoke

- Unlabelled construction / setup ó [VmCsat._smoke:184](../scripts\game\vehicles\vm_csat.gd#L184)

### VmCsat._sprocket

- Unlabelled construction / setup ó [VmCsat._sprocket:482](../scripts\game\vehicles\vm_csat.gd#L482)

### VmCsat._stalker

- Unlabelled construction / setup ó [VmCsat._stalker:636](../scripts\game\vehicles\vm_csat.gd#L636)
- side skirts in bolted sections, the front one angled up toward the sprocket ó [VmCsat._stalker:646](../scripts\game\vehicles\vm_csat.gd#L646)
- the glacis: driver's hatch and periscopes front left, engine louvres front right, headlights in guards at the corners, tow hooks on the nose ó [VmCsat._stalker:652](../scripts\game\vehicles\vm_csat.gd#L652)
- upper sides: stowage boxes and vision blocks, the exhaust on the right ó [VmCsat._stalker:666](../scripts\game\vehicles\vm_csat.gd#L666)
- the rear: the troop door, its hinges and vision block, lights, stowage ó [VmCsat._stalker:676](../scripts\game\vehicles\vm_csat.gd#L676)
- roof: the troop compartment's hatches behind the turret ó [VmCsat._stalker:688](../scripts\game\vehicles\vm_csat.gd#L688)

### VmCsat._t100

- Unlabelled construction / setup ó [VmCsat._t100:777](../scripts\game\vehicles\vm_csat.gd#L777)
- the glacis: a chevron of reactive armour plates, the driver's hatch and periscope at its top, headlights at its corners, tow hooks on the nose ó [VmCsat._t100:787](../scripts\game\vehicles\vm_csat.gd#L787)
- fender shelves, the front mudguards ó [VmCsat._t100:798](../scripts\game\vehicles\vm_csat.gd#L798)
- side skirts: reactive armour on the front three sections, rubber behind ó [VmCsat._t100:804](../scripts\game\vehicles\vm_csat.gd#L804)
- stowage along the fenders behind the turret: bins left, fuel tanks right ó [VmCsat._t100:814](../scripts\game\vehicles\vm_csat.gd#L814)
- engine deck: grilles and the access panels ó [VmCsat._t100:821](../scripts\game\vehicles\vm_csat.gd#L821)
- the rear: the turbine's exhaust grille, the unditching beam, lights, hooks ó [VmCsat._t100:826](../scripts\game\vehicles\vm_csat.gd#L826)

### VmCsat._t14

- Unlabelled construction / setup ó [VmCsat._t14:1017](../scripts\game\vehicles\vm_csat.gd#L1017)
- the glacis: a grid of reactive armour blocks, the lights, tow hooks ó [VmCsat._t14:1027](../scripts\game\vehicles\vm_csat.gd#L1027)
- the crew capsule: three hatches abreast, periscopes ahead of each ó [VmCsat._t14:1037](../scripts\game\vehicles\vm_csat.gd#L1037)
- tall skirts: reactive armour forward, plain plates aft; slat cages round the engine bay ó [VmCsat._t14:1043](../scripts\game\vehicles\vm_csat.gd#L1043)
- engine deck: grilles, the exhaust on the left, stowage boxes on the deck ó [VmCsat._t14:1056](../scripts\game\vehicles\vm_csat.gd#L1056)

### VmCsat._taillight

- Unlabelled construction / setup ó [VmCsat._taillight:148](../scripts\game\vehicles\vm_csat.gd#L148)

### VmCsat._tempest_box

- Unlabelled construction / setup ó [VmCsat._tempest_box:1331](../scripts\game\vehicles\vm_csat.gd#L1331)

### VmCsat._tempest_flatbed

- Unlabelled construction / setup ó [VmCsat._tempest_flatbed:1315](../scripts\game\vehicles\vm_csat.gd#L1315)

### VmCsat._tow

- Unlabelled construction / setup ó [VmCsat._tow:159](../scripts\game\vehicles\vm_csat.gd#L159)

### VmCsat._tube

- Unlabelled construction / setup ó [VmCsat._tube:108](../scripts\game\vehicles\vm_csat.gd#L108)

### VmCsat._typhoon

- Unlabelled construction / setup ó [VmCsat._typhoon:1132](../scripts\game\vehicles\vm_csat.gd#L1132)
- the bumper block under the cab's nose ó [VmCsat._typhoon:1144](../scripts\game\vehicles\vm_csat.gd#L1144)
- the windscreen: two big flat panes, a pillar between them ó [VmCsat._typhoon:1146](../scripts\game\vehicles\vm_csat.gd#L1146)
- the grille on the cab front, headlights and tow hooks in the bumper ó [VmCsat._typhoon:1151](../scripts\game\vehicles\vm_csat.gd#L1151)
- door window and the small one behind it, the door seam and handle ó [VmCsat._typhoon:1158](../scripts\game\vehicles\vm_csat.gd#L1158)
- the step ladder under the door, behind the front wheel ó [VmCsat._typhoon:1161](../scripts\game\vehicles\vm_csat.gd#L1161)
- mirrors on long arms ó [VmCsat._typhoon:1163](../scripts\game\vehicles\vm_csat.gd#L1163)
- the front wheel under its faceted arch, the rear tandem ó [VmCsat._typhoon:1165](../scripts\game\vehicles\vm_csat.gd#L1165)
- the rear tandem's mudguard ó [VmCsat._typhoon:1171](../scripts\game\vehicles\vm_csat.gd#L1171)
- fuel tank and battery box on the frame, the exhaust stack behind the cab ó [VmCsat._typhoon:1174](../scripts\game\vehicles\vm_csat.gd#L1174)
- the rear underrun bar ó [VmCsat._typhoon:1178](../scripts\game\vehicles\vm_csat.gd#L1178)
- roof: hatch, antennas, a light ó [VmCsat._typhoon:1180](../scripts\game\vehicles\vm_csat.gd#L1180)

### VmFighter._aim120

- Unlabelled construction / setup ó [VmFighter._aim120:933](../scripts\game\vehicles\vm_fighter.gd#L933)

### VmFighter._aim9x

- Unlabelled construction / setup ó [VmFighter._aim9x:917](../scripts\game\vehicles\vm_fighter.gd#L917)

### VmFighter._alq184

- Unlabelled construction / setup ó [VmFighter._alq184:967](../scripts\game\vehicles\vm_fighter.gd#L967)

### VmFighter._awheel

- Unlabelled construction / setup ó [VmFighter._awheel:654](../scripts\game\vehicles\vm_fighter.gd#L654)

### VmFighter._burner

- Unlabelled construction / setup ó [VmFighter._burner:409](../scripts\game\vehicles\vm_fighter.gd#L409)

### VmFighter._bw_half

- Unlabelled construction / setup ó [VmFighter._bw_half:984](../scripts\game\vehicles\vm_fighter.gd#L984)

### VmFighter._ccr

- Unlabelled construction / setup ó [VmFighter._ccr:258](../scripts\game\vehicles\vm_fighter.gd#L258)

### VmFighter._circle2

- Unlabelled construction / setup ó [VmFighter._circle2:431](../scripts\game\vehicles\vm_fighter.gd#L431)

### VmFighter._cloop

- Unlabelled construction / setup ó [VmFighter._cloop:340](../scripts\game\vehicles\vm_fighter.gd#L340)

### VmFighter._decal

- Unlabelled construction / setup ó [VmFighter._decal:455](../scripts\game\vehicles\vm_fighter.gd#L455)

### VmFighter._dense

- Unlabelled construction / setup ó [VmFighter._dense:242](../scripts\game\vehicles\vm_fighter.gd#L242)

### VmFighter._duct

- Unlabelled construction / setup ó [VmFighter._duct:370](../scripts\game\vehicles\vm_fighter.gd#L370)

### VmFighter._f16_half

- Unlabelled construction / setup ó [VmFighter._f16_half:671](../scripts\game\vehicles\vm_fighter.gd#L671)

### VmFighter._ft

- Unlabelled construction / setup ó [VmFighter._ft:419](../scripts\game\vehicles\vm_fighter.gd#L419)

### VmFighter._gbu31

- Unlabelled construction / setup ó [VmFighter._gbu31:895](../scripts\game\vehicles\vm_fighter.gd#L895)
- strakes: either side and below ó [VmFighter._gbu31:902](../scripts\game\vehicles\vm_fighter.gd#L902)
- the tail kit's fins (X) ó [VmFighter._gbu31:906](../scripts\game\vehicles\vm_fighter.gd#L906)

### VmFighter._gear_node

- Unlabelled construction / setup ó [VmFighter._gear_node:645](../scripts\game\vehicles\vm_fighter.gd#L645)

### VmFighter._glaze

- Unlabelled construction / setup ó [VmFighter._glaze:188](../scripts\game\vehicles\vm_fighter.gd#L188)

### VmFighter._hband

- Unlabelled construction / setup ó [VmFighter._hband:312](../scripts\game\vehicles\vm_fighter.gd#L312)

### VmFighter._hull

- Unlabelled construction / setup ó [VmFighter._hull:301](../scripts\game\vehicles\vm_fighter.gd#L301)

### VmFighter._hwrap

- Unlabelled construction / setup ó [VmFighter._hwrap:475](../scripts\game\vehicles\vm_fighter.gd#L475)

### VmFighter._insignia

- Unlabelled construction / setup ó [VmFighter._insignia:540](../scripts\game\vehicles\vm_fighter.gd#L540)

### VmFighter._leg

- Unlabelled construction / setup ó [VmFighter._leg:664](../scripts\game\vehicles\vm_fighter.gd#L664)

### VmFighter._lines

- Unlabelled construction / setup ó [VmFighter._lines:602](../scripts\game\vehicles\vm_fighter.gd#L602)

### VmFighter._loop

- Unlabelled construction / setup ó [VmFighter._loop:292](../scripts\game\vehicles\vm_fighter.gd#L292)

### VmFighter._mesh

- Unlabelled construction / setup ó [VmFighter._mesh:150](../scripts\game\vehicles\vm_fighter.gd#L150)

### VmFighter._mixloop

- Unlabelled construction / setup ó [VmFighter._mixloop:349](../scripts\game\vehicles\vm_fighter.gd#L349)

### VmFighter._msecs

- Unlabelled construction / setup ó [VmFighter._msecs:529](../scripts\game\vehicles\vm_fighter.gd#L529)

### VmFighter._outline

- Unlabelled construction / setup ó [VmFighter._outline:635](../scripts\game\vehicles\vm_fighter.gd#L635)

### VmFighter._petals

- Unlabelled construction / setup ó [VmFighter._petals:378](../scripts\game\vehicles\vm_fighter.gd#L378)

### VmFighter._pipe

- Unlabelled construction / setup ó [VmFighter._pipe:389](../scripts\game\vehicles\vm_fighter.gd#L389)

### VmFighter._poly_mesh

- Unlabelled construction / setup ó [VmFighter._poly_mesh:164](../scripts\game\vehicles\vm_fighter.gd#L164)

### VmFighter._project

- Unlabelled construction / setup ó [VmFighter._project:466](../scripts\game\vehicles\vm_fighter.gd#L466)

### VmFighter._put

- Unlabelled construction / setup ó [VmFighter._put:182](../scripts\game\vehicles\vm_fighter.gd#L182)

### VmFighter._qloop

- Unlabelled construction / setup ó [VmFighter._qloop:328](../scripts\game\vehicles\vm_fighter.gd#L328)

### VmFighter._rect2

- Unlabelled construction / setup ó [VmFighter._rect2:439](../scripts\game\vehicles\vm_fighter.gd#L439)

### VmFighter._ring

- Unlabelled construction / setup ó [VmFighter._ring:274](../scripts\game\vehicles\vm_fighter.gd#L274)

### VmFighter._rows

- Unlabelled construction / setup ó [VmFighter._rows:207](../scripts\game\vehicles\vm_fighter.gd#L207)

### VmFighter._skin

- Unlabelled construction / setup ó [VmFighter._skin:52](../scripts\game\vehicles\vm_fighter.gd#L52)
- a degenerate quad (a pointed nose): face along the section's radius ó [VmFighter._skin:83](../scripts\game\vehicles\vm_fighter.gd#L83)

### VmFighter._slab

- Unlabelled construction / setup ó [VmFighter._slab:176](../scripts\game\vehicles\vm_fighter.gd#L176)

### VmFighter._sniper

- Unlabelled construction / setup ó [VmFighter._sniper:949](../scripts\game\vehicles\vm_fighter.gd#L949)
- the rotating head: a faceted nose, its window ó [VmFighter._sniper:952](../scripts\game\vehicles\vm_fighter.gd#L952)

### VmFighter._star2

- Unlabelled construction / setup ó [VmFighter._star2:444](../scripts\game\vehicles\vm_fighter.gd#L444)

### VmFighter._surf

- Unlabelled construction / setup ó [VmFighter._surf:425](../scripts\game\vehicles\vm_fighter.gd#L425)

### VmFighter._tan

- Unlabelled construction / setup ó [VmFighter._tan:234](../scripts\game\vehicles\vm_fighter.gd#L234)

### VmFighter._text

- Unlabelled construction / setup ó [VmFighter._text:569](../scripts\game\vehicles\vm_fighter.gd#L569)

### VmFighter._tri

- Unlabelled construction / setup ó [VmFighter._tri:138](../scripts\game\vehicles\vm_fighter.gd#L138)

### VmFighter._vn

- Unlabelled construction / setup ó [VmFighter._vn:124](../scripts\game\vehicles\vm_fighter.gd#L124)

### VmFighter._wrap

- Unlabelled construction / setup ó [VmFighter._wrap:504](../scripts\game\vehicles\vm_fighter.gd#L504)

### VmFighter._zigzag

- Unlabelled construction / setup ó [VmFighter._zigzag:622](../scripts\game\vehicles\vm_fighter.gd#L622)

### VmGunship._ac130_cockpit

- Unlabelled construction / setup ó [VmGunship._ac130_cockpit:452](../scripts\game\vehicles\vm_gunship.gd#L452)
- the windscreen: five panes across the steep front of the flight deck, framed; its top and bottom rails ó [VmGunship._ac130_cockpit:453](../scripts\game\vehicles\vm_gunship.gd#L453)
- two side windows each side, the eyebrow windows over them ó [VmGunship._ac130_cockpit:463](../scripts\game\vehicles\vm_gunship.gd#L463)
- the chin window low in the nose beside the nose gear ó [VmGunship._ac130_cockpit:470](../scripts\game\vehicles\vm_gunship.gd#L470)
- the pitot tubes ó [VmGunship._ac130_cockpit:473](../scripts\game\vehicles\vm_gunship.gd#L473)
- the air-refuelling receptacle (UARRSI) on the roof and its slipway ó [VmGunship._ac130_cockpit:478](../scripts\game\vehicles\vm_gunship.gd#L478)

### VmGunship._ac130_doors

- Unlabelled construction / setup ó [VmGunship._ac130_doors:489](../scripts\game\vehicles\vm_gunship.gd#L489)
- the ramp and cargo door: seams along the lower sides of the upsweep and across it at the hinge, the ramp's end and the door's top ó [VmGunship._ac130_doors:498](../scripts\game\vehicles\vm_gunship.gd#L498)

### VmGunship._ac130_gear

- Unlabelled construction / setup ó [VmGunship._ac130_gear:610](../scripts\game\vehicles\vm_gunship.gd#L610)
- the nose gear: the strut, its torque links, the twin wheels, the doors ó [VmGunship._ac130_gear:613](../scripts\game\vehicles\vm_gunship.gd#L613)
- the main gear: the open wells, a strut and wheel at each station ó [VmGunship._ac130_gear:620](../scripts\game\vehicles\vm_gunship.gd#L620)

### VmGunship._ac130_guns

- Unlabelled construction / setup ó [VmGunship._ac130_guns:559](../scripts\game\vehicles\vm_gunship.gd#L559)
- the 25 mm GAU-12 Equalizer ó [VmGunship._ac130_guns:561](../scripts\game\vehicles\vm_gunship.gd#L561)
- the five barrels out of the mount's ball, clamped twice along their length ó [VmGunship._ac130_guns:565](../scripts\game\vehicles\vm_gunship.gd#L565)
- the 40 mm L/60 Bofors ó [VmGunship._ac130_guns:569](../scripts\game\vehicles\vm_gunship.gd#L569)
- (the mount's shield in the port, the cooling jacket, the barrel, the conical flash hider) ó [VmGunship._ac130_guns:572](../scripts\game\vehicles\vm_gunship.gd#L572)
- the 105 mm M102 howitzer ó [VmGunship._ac130_guns:580](../scripts\game\vehicles\vm_gunship.gd#L580)
- (the cradle in the port, the recoil sleeve, the barrel, the double-baffle muzzle brake with its side ports) ó [VmGunship._ac130_guns:583](../scripts\game\vehicles\vm_gunship.gd#L583)
- the AN/AAQ-117 infrared turret under the nose, the ALLTV turret in the front of the left sponson ó [VmGunship._ac130_guns:595](../scripts\game\vehicles\vm_gunship.gd#L595)

### VmGunship._ang

- Unlabelled construction / setup ó [VmGunship._ang:76](../scripts\game\vehicles\vm_gunship.gd#L76)

### VmGunship._bf_cockpit

- Unlabelled construction / setup ó [VmGunship._bf_cockpit:739](../scripts\game\vehicles\vm_gunship.gd#L739)

### VmGunship._bf_doors

- Unlabelled construction / setup ó [VmGunship._bf_doors:759](../scripts\game\vehicles\vm_gunship.gd#L759)

### VmGunship._bf_gear

- Unlabelled construction / setup ó [VmGunship._bf_gear:866](../scripts\game\vehicles\vm_gunship.gd#L866)

### VmGunship._bf_guns

- Unlabelled construction / setup ó [VmGunship._bf_guns:820](../scripts\game\vehicles\vm_gunship.gd#L820)
- the 40 mm ó [VmGunship._bf_guns:823](../scripts\game\vehicles\vm_gunship.gd#L823)
- the 105 mm and the 20 mm in the aft mount ó [VmGunship._bf_guns:834](../scripts\game\vehicles\vm_gunship.gd#L834)
- the Gatling's six barrels out of its drive housing, clamped twice ó [VmGunship._bf_guns:853](../scripts\game\vehicles\vm_gunship.gd#L853)
- the gunners' second sensor turret ó [VmGunship._bf_guns:857](../scripts\game\vehicles\vm_gunship.gd#L857)

### VmGunship._bf_nacelle

- Unlabelled construction / setup ó [VmGunship._bf_nacelle:775](../scripts\game\vehicles\vm_gunship.gd#L775)
- the engine's intake scoop on top, dark inside ó [VmGunship._bf_nacelle:789](../scripts\game\vehicles\vm_gunship.gd#L789)
- cooling grilles either side, the exhaust ó [VmGunship._bf_nacelle:793](../scripts\game\vehicles\vm_gunship.gd#L793)
- the navigation light, green on the right, red on the left ó [VmGunship._bf_nacelle:798](../scripts\game\vehicles\vm_gunship.gd#L798)

### VmGunship._bf_tail

- Unlabelled construction / setup ó [VmGunship._bf_tail:805](../scripts\game\vehicles\vm_gunship.gd#L805)
- the tail light looks aft off the tip of the boom ó [VmGunship._bf_tail:811](../scripts\game\vehicles\vm_gunship.gd#L811)

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

- Unlabelled construction / setup ó [VmGunship._shift:548](../scripts\game\vehicles\vm_gunship.gd#L548)

### VmGunship._t56

- Unlabelled construction / setup ó [VmGunship._t56:511](../scripts\game\vehicles\vm_gunship.gd#L511)
- a tall oval behind the spinner (the intake under it), the top running back into the wing's leading edge, the deep belly, the tail fairing ó [VmGunship._t56:513](../scripts\game\vehicles\vm_gunship.gd#L513)
- the cowl's panel joints ó [VmGunship._t56:529](../scripts\game\vehicles\vm_gunship.gd#L529)
- the engine and oil-cooler intake under the spinner: a lip standing proud of the cowl's face, dark inside ó [VmGunship._t56:533](../scripts\game\vehicles\vm_gunship.gd#L533)
- the exhaust: a short pipe out of the outboard side of the nacelle under the trailing edge, aft and toed out a little, soot streaked aft of it ó [VmGunship._t56:538](../scripts\game\vehicles\vm_gunship.gd#L538)

### VmGunship._text_tris

- Unlabelled construction / setup ó [VmGunship._text_tris:297](../scripts\game\vehicles\vm_gunship.gd#L297)
- (each stroke runs a little past its ends to close the corners) ó [VmGunship._text_tris:313](../scripts\game\vehicles\vm_gunship.gd#L313)

### VmGunship._tyre

- Unlabelled construction / setup ó [VmGunship._tyre:114](../scripts\game\vehicles\vm_gunship.gd#L114)

### VmGunship._under

- Unlabelled construction / setup ó [VmGunship._under:885](../scripts\game\vehicles\vm_gunship.gd#L885)

### VmGunship._wing_lines

- Unlabelled construction / setup ó [VmGunship._wing_lines:227](../scripts\game\vehicles\vm_gunship.gd#L227)

### VmHeli._air

- Unlabelled construction / setup ó [VmHeli._air:246](../scripts\game\vehicles\vm_heli.gd#L246)

### VmHeli._atgm_tubes

- Unlabelled construction / setup ó [VmHeli._atgm_tubes:1022](../scripts\game\vehicles\vm_heli.gd#L1022)

### VmHeli._canopy

- Unlabelled construction / setup ó [VmHeli._canopy:1008](../scripts\game\vehicles\vm_heli.gd#L1008)

### VmHeli._ducted_fin

- Unlabelled construction / setup ó [VmHeli._ducted_fin:270](../scripts\game\vehicles\vm_heli.gd#L270)
- the outline's corners inside this wedge, in angular order ó [VmHeli._ducted_fin:279](../scripts\game\vehicles\vm_heli.gd#L279)

### VmHeli._fan

- Unlabelled construction / setup ó [VmHeli._fan:311](../scripts\game\vehicles\vm_heli.gd#L311)
- unevenly spaced, as on the real fans (it spreads the noise) ó [VmHeli._fan:314](../scripts\game\vehicles\vm_heli.gd#L314)

### VmHeli._gear

- Unlabelled construction / setup ó [VmHeli._gear:340](../scripts\game\vehicles\vm_heli.gd#L340)

### VmHeli._hellfires

- Unlabelled construction / setup ó [VmHeli._hellfires:380](../scripts\game\vehicles\vm_heli.gd#L380)

### VmHeli._hull

- Unlabelled construction / setup ó [VmHeli._hull:181](../scripts\game\vehicles\vm_heli.gd#L181)
- Panel joins follow the authored skin; glazing sits above them, so seams cannot cut across a cockpit pane or change the hull outline. ó [VmHeli._hull:186](../scripts\game\vehicles\vm_heli.gd#L186)

### VmHeli._minigun

- Unlabelled construction / setup ó [VmHeli._minigun:356](../scripts\game\vehicles\vm_heli.gd#L356)
- the six barrels from the rotor at the housing's face, clamped past mid-length and just behind the muzzles ó [VmHeli._minigun:358](../scripts\game\vehicles\vm_heli.gd#L358)

### VmHeli._missile

- Unlabelled construction / setup ó [VmHeli._missile:371](../scripts\game\vehicles\vm_heli.gd#L371)

### VmHeli._mx

- Unlabelled construction / setup ó [VmHeli._mx:999](../scripts\game\vehicles\vm_heli.gd#L999)

### VmHeli._patch

- Unlabelled construction / setup ó [VmHeli._patch:206](../scripts\game\vehicles\vm_heli.gd#L206)

### VmHeli._path

- Unlabelled construction / setup ó [VmHeli._path:234](../scripts\game\vehicles\vm_heli.gd#L234)

### VmHeli._prop

- Unlabelled construction / setup ó [VmHeli._prop:1409](../scripts\game\vehicles\vm_heli.gd#L1409)

### VmHeli._ray_hit

- Unlabelled construction / setup ó [VmHeli._ray_hit:294](../scripts\game\vehicles\vm_heli.gd#L294)

### VmHeli._rbox

- Unlabelled construction / setup ó [VmHeli._rbox:240](../scripts\game\vehicles\vm_heli.gd#L240)

### VmHeli._rocket_pod

- Unlabelled construction / setup ó [VmHeli._rocket_pod:366](../scripts\game\vehicles\vm_heli.gd#L366)

### VmHeli._rotor

- Unlabelled construction / setup ó [VmHeli._rotor:259](../scripts\game\vehicles\vm_heli.gd#L259)

### VmHeli._rz

- Unlabelled construction / setup ó [VmHeli._rz:221](../scripts\game\vehicles\vm_heli.gd#L221)

### VmHeli._skids

- Unlabelled construction / setup ó [VmHeli._skids:326](../scripts\game\vehicles\vm_heli.gd#L326)

### VmHeli._tail_rotor

- Unlabelled construction / setup ó [VmHeli._tail_rotor:263](../scripts\game\vehicles\vm_heli.gd#L263)

### VmHeli._tube

- Unlabelled construction / setup ó [VmHeli._tube:229](../scripts\game\vehicles\vm_heli.gd#L229)

### VmIndep._antenna

- Unlabelled construction / setup ó [VmIndep._antenna:119](../scripts\game\vehicles\vm_indep.gd#L119)

### VmIndep._idler

- Unlabelled construction / setup ó [VmIndep._idler:136](../scripts\game\vehicles\vm_indep.gd#L136)

### VmIndep._jerrycan

- Unlabelled construction / setup ó [VmIndep._jerrycan:124](../scripts\game\vehicles\vm_indep.gd#L124)

### VmIndep._light

- Unlabelled construction / setup ó [VmIndep._light:87](../scripts\game\vehicles\vm_indep.gd#L87)

### VmIndep._nyx_m2

- Unlabelled construction / setup ó [VmIndep._nyx_m2:665](../scripts\game\vehicles\vm_indep.gd#L665)

### VmIndep._oct

- Unlabelled construction / setup ó [VmIndep._oct:57](../scripts\game\vehicles\vm_indep.gd#L57)

### VmIndep._paint

- Unlabelled construction / setup ó [VmIndep._paint:50](../scripts\game\vehicles\vm_indep.gd#L50)

### VmIndep._plate

- Unlabelled construction / setup ó [VmIndep._plate:68](../scripts\game\vehicles\vm_indep.gd#L68)

### VmIndep._rcws

- Unlabelled construction / setup ó [VmIndep._rcws:284](../scripts\game\vehicles\vm_indep.gd#L284)
- the sight box on the right (the day camera's window over the thermal imager's round lens), the ammo box on the left ó [VmIndep._rcws:291](../scripts\game\vehicles\vm_indep.gd#L291)
- HK GMG: a squat receiver, a short thick barrel, the big belt box ó [VmIndep._rcws:296](../scripts\game\vehicles\vm_indep.gd#L296)
- M2: the long receiver, the barrel with its carrying handle, flash hider; its ammunition box is the station's, hung outboard of the yoke ó [VmIndep._rcws:300](../scripts\game\vehicles\vm_indep.gd#L300)

### VmIndep._ring

- Unlabelled construction / setup ó [VmIndep._ring:61](../scripts\game\vehicles\vm_indep.gd#L61)

### VmIndep._road_wheel

- Unlabelled construction / setup ó [VmIndep._road_wheel:131](../scripts\game\vehicles\vm_indep.gd#L131)

### VmIndep._round_light

- Unlabelled construction / setup ó [VmIndep._round_light:101](../scripts\game\vehicles\vm_indep.gd#L101)

### VmIndep._running_gear

- Unlabelled construction / setup ó [VmIndep._running_gear:319](../scripts\game\vehicles\vm_indep.gd#L319)

### VmIndep._sensor_head

- Unlabelled construction / setup ó [VmIndep._sensor_head:276](../scripts\game\vehicles\vm_indep.gd#L276)

### VmIndep._slats

- Unlabelled construction / setup ó [VmIndep._slats:310](../scripts\game\vehicles\vm_indep.gd#L310)

### VmIndep._smoke

- Unlabelled construction / setup ó [VmIndep._smoke:110](../scripts\game\vehicles\vm_indep.gd#L110)

### VmIndep._sprocket

- Unlabelled construction / setup ó [VmIndep._sprocket:141](../scripts\game\vehicles\vm_indep.gd#L141)

### VmIndep._tb

- Unlabelled construction / setup ó [VmIndep._tb:77](../scripts\game\vehicles\vm_indep.gd#L77)

### VmIndep._tow_eyes

- Unlabelled construction / setup ó [VmIndep._tow_eyes:269](../scripts\game\vehicles\vm_indep.gd#L269)

### VmIndep._track_belt

- Unlabelled construction / setup ó [VmIndep._track_belt:148](../scripts\game\vehicles\vm_indep.gd#L148)

### VmIndep._zamak_ammo

- Unlabelled construction / setup ó [VmIndep._zamak_ammo:957](../scripts\game\vehicles\vm_indep.gd#L957)
- the front stacks under a tarp, its rolled edge ó [VmIndep._zamak_ammo:971](../scripts\game\vehicles\vm_indep.gd#L971)

### VmIndep._zamak_bed

- Unlabelled construction / setup ó [VmIndep._zamak_bed:882](../scripts\game\vehicles\vm_indep.gd#L882)
- under the back: tail lights on their brackets, the bumper bar, pintle, plate ó [VmIndep._zamak_bed:896](../scripts\game\vehicles\vm_indep.gd#L896)

### VmIndep._zamak_box

- Unlabelled construction / setup ó [VmIndep._zamak_box:978](../scripts\game\vehicles\vm_indep.gd#L978)
- roof vents ó [VmIndep._zamak_box:984](../scripts\game\vehicles\vm_indep.gd#L984)

### VmIndep._zamak_cab

- Unlabelled construction / setup ó [VmIndep._zamak_cab:810](../scripts\game\vehicles\vm_indep.gd#L810)
- chassis rails and cross members, axles with their differentials, springs ó [VmIndep._zamak_cab:811](../scripts\game\vehicles\vm_indep.gd#L811)
- the bonnet: louvres down its sides, the grille in front ó [VmIndep._zamak_cab:823](../scripts\game\vehicles\vm_indep.gd#L823)
- the wing over the front wheel: flat top, raked front, a valance ó [VmIndep._zamak_cab:830](../scripts\game\vehicles\vm_indep.gd#L830)
- a round headlight on the wing's front, the sidelight on top of it ó [VmIndep._zamak_cab:835](../scripts\game\vehicles\vm_indep.gd#L835)
- the bumper with its tow hooks and plate ó [VmIndep._zamak_cab:838](../scripts\game\vehicles\vm_indep.gd#L838)
- the cab: vertical lower half, the glasshouse leaning in a little ó [VmIndep._zamak_cab:843](../scripts\game\vehicles\vm_indep.gd#L843)
- door window and rear quarter light, the door's seams and handle, the step and grab handle, the mirror on its arm ó [VmIndep._zamak_cab:854](../scripts\game\vehicles\vm_indep.gd#L854)
- the roof hatch and marker lights, an antenna on the back corner ó [VmIndep._zamak_cab:862](../scripts\game\vehicles\vm_indep.gd#L862)
- behind the cab: the spare wheel upright in its frame, the air intake, the fuel tank on the left and the battery box on the right ó [VmIndep._zamak_cab:867](../scripts\game\vehicles\vm_indep.gd#L867)
- the exhaust's silencer under the right side of the cab ó [VmIndep._zamak_cab:875](../scripts\game\vehicles\vm_indep.gd#L875)

### VmIndep._zamak_cargo

- Unlabelled construction / setup ó [VmIndep._zamak_cargo:930](../scripts\game\vehicles\vm_indep.gd#L930)
- two oil drums at the front left, a crate stack at the front right ó [VmIndep._zamak_cargo:933](../scripts\game\vehicles\vm_indep.gd#L933)
- the middle: a pile under a tarpaulin, lashed down ó [VmIndep._zamak_cargo:943](../scripts\game\vehicles\vm_indep.gd#L943)
- the back: crates, sacks and jerrycans ó [VmIndep._zamak_cargo:945](../scripts\game\vehicles\vm_indep.gd#L945)

### VmIndep._zamak_fuel

- Unlabelled construction / setup ó [VmIndep._zamak_fuel:1067](../scripts\game\vehicles\vm_indep.gd#L1067)
- on top: two manholes, the walkway, fold-down rails ó [VmIndep._zamak_fuel:1073](../scripts\game\vehicles\vm_indep.gd#L1073)
- hazard placards and the fire extinguisher by the cabinet ó [VmIndep._zamak_fuel:1080](../scripts\game\vehicles\vm_indep.gd#L1080)
- the pump cabinet at the back: louvred doors, the hose reel on top, a ladder up its back ó [VmIndep._zamak_fuel:1083](../scripts\game\vehicles\vm_indep.gd#L1083)
- under the back: tail lights, bumper, pintle ó [VmIndep._zamak_fuel:1096](../scripts\game\vehicles\vm_indep.gd#L1096)

### VmIndep._zamak_medical

- Unlabelled construction / setup ó [VmIndep._zamak_medical:1034](../scripts\game\vehicles\vm_indep.gd#L1034)
- the roof: a white panel with its cross, the rolled awning ó [VmIndep._zamak_medical:1044](../scripts\game\vehicles\vm_indep.gd#L1044)
- the back: two doors with the cross across them, handles, a step ó [VmIndep._zamak_medical:1049](../scripts\game\vehicles\vm_indep.gd#L1049)

### VmIndep._zamak_mrl

- Unlabelled construction / setup ó [VmIndep._zamak_mrl:1107](../scripts\game\vehicles\vm_indep.gd#L1107)
- stabiliser jacks behind the rear wheels, raised ó [VmIndep._zamak_mrl:1110](../scripts\game\vehicles\vm_indep.gd#L1110)
- the fire-control and reload boxes at the front of the deck ó [VmIndep._zamak_mrl:1114](../scripts\game\vehicles\vm_indep.gd#L1114)
- the turntable and its trunnion brackets ó [VmIndep._zamak_mrl:1118](../scripts\game\vehicles\vm_indep.gd#L1118)
- the elevating ram's base on the turntable ó [VmIndep._zamak_mrl:1126](../scripts\game\vehicles\vm_indep.gd#L1126)
- the pod: twelve cells, three rows of four, its frame bands and covers ó [VmIndep._zamak_mrl:1128](../scripts\game\vehicles\vm_indep.gd#L1128)

### VmIndep._zamak_repair

- Unlabelled construction / setup ó [VmIndep._zamak_repair:994](../scripts\game\vehicles\vm_indep.gd#L994)
- the side door on the right with its fold-down step, a locker on the left ó [VmIndep._zamak_repair:1000](../scripts\game\vehicles\vm_indep.gd#L1000)
- a ladder up the back of the body ó [VmIndep._zamak_repair:1008](../scripts\game\vehicles\vm_indep.gd#L1008)
- the crane on the deck: slewing base, column, the boom folded forward over the roof, its ram and hook ó [VmIndep._zamak_repair:1013](../scripts\game\vehicles\vm_indep.gd#L1013)
- generator and gas bottles chained to the deck ó [VmIndep._zamak_repair:1022](../scripts\game\vehicles\vm_indep.gd#L1022)

### VmIndep._zamak_tilt

- Unlabelled construction / setup ó [VmIndep._zamak_tilt:906](../scripts\game\vehicles\vm_indep.gd#L906)
- the hoops showing through, the lashing along the bottom ó [VmIndep._zamak_tilt:908](../scripts\game\vehicles\vm_indep.gd#L908)
- the back: the flap rolled up under the roof, the dark inside, benches ó [VmIndep._zamak_tilt:919](../scripts\game\vehicles\vm_indep.gd#L919)

### VmNato._ammo_can

- Unlabelled construction / setup ó [VmNato._ammo_can:171](../scripts\game\vehicles\vm_nato.gd#L171)

### VmNato._antenna

- Unlabelled construction / setup ó [VmNato._antenna:177](../scripts\game\vehicles\vm_nato.gd#L177)

### VmNato._axles

- Unlabelled construction / setup ó [VmNato._axles:504](../scripts\game\vehicles\vm_nato.gd#L504)

### VmNato._beam

- Unlabelled construction / setup ó [VmNato._beam:146](../scripts\game\vehicles\vm_nato.gd#L146)

### VmNato._cam

- Unlabelled construction / setup ó [VmNato._cam:75](../scripts\game\vehicles\vm_nato.gd#L75)

### VmNato._cargo

- Unlabelled construction / setup ó [VmNato._cargo:1526](../scripts\game\vehicles\vm_nato.gd#L1526)

### VmNato._chain

- Unlabelled construction / setup ó [VmNato._chain:920](../scripts\game\vehicles\vm_nato.gd#L920)

### VmNato._cross

- Unlabelled construction / setup ó [VmNato._cross:1551](../scripts\game\vehicles\vm_nato.gd#L1551)

### VmNato._era

- Unlabelled construction / setup ó [VmNato._era:114](../scripts\game\vehicles\vm_nato.gd#L114)

### VmNato._extrude_z

- Unlabelled construction / setup ó [VmNato._extrude_z:1230](../scripts\game\vehicles\vm_nato.gd#L1230)

### VmNato._face_basis

- Unlabelled construction / setup ó [VmNato._face_basis:102](../scripts\game\vehicles\vm_nato.gd#L102)

### VmNato._gmg

- Unlabelled construction / setup ó [VmNato._gmg:223](../scripts\game\vehicles\vm_nato.gd#L223)

### VmNato._hemtt_cab_detail

- Unlabelled construction / setup ó [VmNato._hemtt_cab_detail:1323](../scripts\game\vehicles\vm_nato.gd#L1323)
- A pressed roof cap and an inset service panel break up the flat cab. ó [VmNato._hemtt_cab_detail:1325](../scripts\game\vehicles\vm_nato.gd#L1325)
- Door recess, raised inner pressing, hinges and a grab handle. ó [VmNato._hemtt_cab_detail:1329](../scripts\game\vehicles\vm_nato.gd#L1329)
- Worn step lips and lower door sill, where boots contact the paint. ó [VmNato._hemtt_cab_detail:1331](../scripts\game\vehicles\vm_nato.gd#L1331)

### VmNato._hemtt_cargo_detail

- Unlabelled construction / setup ó [VmNato._hemtt_cargo_detail:1338](../scripts\game\vehicles\vm_nato.gd#L1338)
- Segmented bed rails, latch hardware and small rub marks on each hinge. ó [VmNato._hemtt_cargo_detail:1341](../scripts\game\vehicles\vm_nato.gd#L1341)

### VmNato._hemtt_chassis

- Unlabelled construction / setup ó [VmNato._hemtt_chassis:1239](../scripts\game\vehicles\vm_nato.gd#L1239)
- frame rails, the axles' beams and springs ó [VmNato._hemtt_chassis:1250](../scripts\game\vehicles\vm_nato.gd#L1250)
- the cab: a slightly raked windscreen, flat sides, the nose out in front ó [VmNato._hemtt_chassis:1254](../scripts\game\vehicles\vm_nato.gd#L1254)
- Open upper cab: the windows must reveal seats, dash and the far side, not a solid painted box immediately behind transparent glass. ó [VmNato._hemtt_chassis:1257](../scripts\game\vehicles\vm_nato.gd#L1257)
- the big grille, the bumper with the headlights in its ends, tow eyes, the pintle ó [VmNato._hemtt_chassis:1265](../scripts\game\vehicles\vm_nato.gd#L1265)
- the sun visor over the windscreen ó [VmNato._hemtt_chassis:1278](../scripts\game\vehicles\vm_nato.gd#L1278)
- windscreen panes, door windows, door seams, handles, mirrors, steps ó [VmNato._hemtt_chassis:1280](../scripts\game\vehicles\vm_nato.gd#L1280)
- the ladder steps up to the door ó [VmNato._hemtt_chassis:1293](../scripts\game\vehicles\vm_nato.gd#L1293)
- the long black fender over both front axles, raked at its front ó [VmNato._hemtt_chassis:1295](../scripts\game\vehicles\vm_nato.gd#L1295)
- the roof hatch, marker lights, antenna ó [VmNato._hemtt_chassis:1299](../scripts\game\vehicles\vm_nato.gd#L1299)
- behind the cab: the engine's air cleaner (left), the exhaust stack (right), the spare wheel between ó [VmNato._hemtt_chassis:1304](../scripts\game\vehicles\vm_nato.gd#L1304)
- the round fuel tank on the left frame rail, the battery box on the right, air tanks ó [VmNato._hemtt_chassis:1310](../scripts\game\vehicles\vm_nato.gd#L1310)

### VmNato._hemtt_deck

- Unlabelled construction / setup ó [VmNato._hemtt_deck:1378](../scripts\game\vehicles\vm_nato.gd#L1378)

### VmNato._hemtt_load_detail

- Unlabelled construction / setup ó [VmNato._hemtt_load_detail:1356](../scripts\game\vehicles\vm_nato.gd#L1356)
- Rolled rims, reinforcing hoops and filler bungs identify oil drums. ó [VmNato._hemtt_load_detail:1360](../scripts\game\vehicles\vm_nato.gd#L1360)
- Straps wrap over the load and down its sides to the pallet. ó [VmNato._hemtt_load_detail:1368](../scripts\game\vehicles\vm_nato.gd#L1368)

### VmNato._hemtt_wheel

- Unlabelled construction / setup ó [VmNato._hemtt_wheel:1352](../scripts\game\vehicles\vm_nato.gd#L1352)

### VmNato._jerry

- Unlabelled construction / setup ó [VmNato._jerry:165](../scripts\game\vehicles\vm_nato.gd#L165)

### VmNato._lamp

- Unlabelled construction / setup ó [VmNato._lamp:151](../scripts\game\vehicles\vm_nato.gd#L151)

### VmNato._m2

- Unlabelled construction / setup ó [VmNato._m2:217](../scripts\game\vehicles\vm_nato.gd#L217)

### VmNato._mk_hull

- Unlabelled construction / setup ó [VmNato._mk_hull:763](../scripts\game\vehicles\vm_nato.gd#L763)
- lower hull between the tracks: the lower nose plate, the belly, the tail ó [VmNato._mk_hull:765](../scripts\game\vehicles\vm_nato.gd#L765)
- the upper hull: the sponsons over the tracks, the glacis rising from the nose to the front of the roof, the roof flat back to the rear ó [VmNato._mk_hull:767](../scripts\game\vehicles\vm_nato.gd#L767)
- the nose: a heavy cast beak with tow eyes and the headlight clusters ó [VmNato._mk_hull:772](../scripts\game\vehicles\vm_nato.gd#L772)
- glacis: engine access panels and the big intake grilles, the driver's hatch and periscopes at the top on the left ó [VmNato._mk_hull:778](../scripts\game\vehicles\vm_nato.gd#L778)
- the exhaust louvres on the left of the glacis ó [VmNato._mk_hull:792](../scripts\game\vehicles\vm_nato.gd#L792)
- skirts: bolted heavy panels hanging off the sponsons, the front one raked ó [VmNato._mk_hull:794](../scripts\game\vehicles\vm_nato.gd#L794)
- the rail along the sponson edge and a tow cable on it ó [VmNato._mk_hull:801](../scripts\game\vehicles\vm_nato.gd#L801)
- tool boxes along the sponson (the hull roof aft stays clear: the bustle and its chains sweep over it) ó [VmNato._mk_hull:804](../scripts\game\vehicles\vm_nato.gd#L804)
- reactive armour bricks over the skirts and up the glacis, each facing out of the side it covers ó [VmNato._mk_hull:812](../scripts\game\vehicles\vm_nato.gd#L812)
- the glacis bricks lie along its slope (as _zy lays a plate), turned over so their covers face up and out of the plate ó [VmNato._mk_hull:818](../scripts\game\vehicles\vm_nato.gd#L818)
- the rear: the troop door with its vision block, steps, stowage baskets ó [VmNato._mk_hull:831](../scripts\game\vehicles\vm_nato.gd#L831)

### VmNato._mk_running

- Unlabelled construction / setup ó [VmNato._mk_running:749](../scripts\game\vehicles\vm_nato.gd#L749)

### VmNato._mk_turret

- Unlabelled construction / setup ó [VmNato._mk_turret:853](../scripts\game\vehicles\vm_nato.gd#L853)
- the turret's body: the wedge in front, the main body over the ring ó [VmNato._mk_turret:856](../scripts\game\vehicles\vm_nato.gd#L856)
- the bustle, raised clear of the hull roof (the chains hang across the gap) ó [VmNato._mk_turret:860](../scripts\game\vehicles\vm_nato.gd#L860)
- ball-and-chain curtain along the bustle's rear and sides ó [VmNato._mk_turret:865](../scripts\game\vehicles\vm_nato.gd#L865)
- the gun: a small mantlet low in the wedge, the barrel's thermal sleeve in sections, the fume extractor, the muzzle reference sensor ó [VmNato._mk_turret:872](../scripts\game\vehicles\vm_nato.gd#L872)
- the gunner's sight box forward left, the commander's big panoramic sight forward right, the cupola behind it, the loader's hatch, the 60 mm mortar ó [VmNato._mk_turret:883](../scripts\game\vehicles\vm_nato.gd#L883)
- the loader's MG on its pintle, the wind sensor mast, antennas ó [VmNato._mk_turret:893](../scripts\game\vehicles\vm_nato.gd#L893)
- smoke dischargers on the wedge's flanks, side armour modules with their channels, stowage baskets along the bustle ó [VmNato._mk_turret:899](../scripts\game\vehicles\vm_nato.gd#L899)
- reactive armour bricks over the wedge's faces and the turret sides ó [VmNato._mk_turret:907](../scripts\game\vehicles\vm_nato.gd#L907)

### VmNato._namer_hull

- Unlabelled construction / setup ó [VmNato._namer_hull:1039](../scripts\game\vehicles\vm_nato.gd#L1039)
- the glacis over the engine, then the superstructure's sloped front face, its sides straight up from the sponsons ó [VmNato._namer_hull:1043](../scripts\game\vehicles\vm_nato.gd#L1043)
- the nose with tow eyes and lights in guards ó [VmNato._namer_hull:1049](../scripts\game\vehicles\vm_nato.gd#L1049)
- glacis: engine grilles, access panels ó [VmNato._namer_hull:1055](../scripts\game\vehicles\vm_nato.gd#L1055)
- the driver's hatch and periscopes on the superstructure front, left ó [VmNato._namer_hull:1064](../scripts\game\vehicles\vm_nato.gd#L1064)
- skirts and side armour: heavy panels low, the superstructure's armour modules with a channel between them, stowage, tow cable ó [VmNato._namer_hull:1070](../scripts\game\vehicles\vm_nato.gd#L1070)
- smoke dischargers on the front roof corners ó [VmNato._namer_hull:1087](../scripts\game\vehicles\vm_nato.gd#L1087)
- roof: the commander's cupola with periscopes, hatches over the troop compartment, stowage at the back ó [VmNato._namer_hull:1089](../scripts\game\vehicles\vm_nato.gd#L1089)
- the rear: the big ramp with its door, hinges, steps ó [VmNato._namer_hull:1101](../scripts\game\vehicles\vm_nato.gd#L1101)

### VmNato._rcws

- Unlabelled construction / setup ó [VmNato._rcws:232](../scripts\game\vehicles\vm_nato.gd#L232)
- Samson-style: a wide box between two cradles, the sight head on top ó [VmNato._rcws:239](../scripts\game\vehicles\vm_nato.gd#L239)
- yoke arms either side of the cradle ó [VmNato._rcws:249](../scripts\game\vehicles\vm_nato.gd#L249)
- the sight unit on the left of the cradle: day camera and thermal windows side by side, under a sun lid ó [VmNato._rcws:259](../scripts\game\vehicles\vm_nato.gd#L259)

### VmNato._ring_z

- Unlabelled construction / setup ó [VmNato._ring_z:1222](../scripts\game\vehicles\vm_nato.gd#L1222)

### VmNato._road_wheel

- Unlabelled construction / setup ó [VmNato._road_wheel:743](../scripts\game\vehicles\vm_nato.gd#L743)

### VmNato._seat

- Unlabelled construction / setup ó [VmNato._seat:208](../scripts\game\vehicles\vm_nato.gd#L208)

### VmNato._shackle

- Unlabelled construction / setup ó [VmNato._shackle:192](../scripts\game\vehicles\vm_nato.gd#L192)

### VmNato._smoke

- Unlabelled construction / setup ó [VmNato._smoke:183](../scripts\game\vehicles\vm_nato.gd#L183)

### VmNato._spare

- Unlabelled construction / setup ó [VmNato._spare:198](../scripts\game\vehicles\vm_nato.gd#L198)

### VmNato._taillight

- Unlabelled construction / setup ó [VmNato._taillight:159](../scripts\game\vehicles\vm_nato.gd#L159)

### VmNato._team_mark

- Unlabelled construction / setup ó [VmNato._team_mark:203](../scripts\game\vehicles\vm_nato.gd#L203)

### VmNato._track_loop

- Unlabelled construction / setup ó [VmNato._track_loop:727](../scripts\game\vehicles\vm_nato.gd#L727)

### VmNato._tube

- Unlabelled construction / setup ó [VmNato._tube:141](../scripts\game\vehicles\vm_nato.gd#L141)

### VmNato._xy

- Unlabelled construction / setup ó [VmNato._xy:92](../scripts\game\vehicles\vm_nato.gd#L92)

### VmNato._zy

- Unlabelled construction / setup ó [VmNato._zy:82](../scripts\game\vehicles\vm_nato.gd#L82)

### VmPlane._foil_t

- Unlabelled construction / setup ó [VmPlane._foil_t:232](../scripts\game\vehicles\vm_plane.gd#L232)

### VmPlane._mx

- Unlabelled construction / setup ó [VmPlane._mx:167](../scripts\game\vehicles\vm_plane.gd#L167)

### VmPlane._sp

- Unlabelled construction / setup ó [VmPlane._sp:94](../scripts\game\vehicles\vm_plane.gd#L94)

### VmPlane._tri

- Unlabelled construction / setup ó [VmPlane._tri:79](../scripts\game\vehicles\vm_plane.gd#L79)

### VmPlane.agm

- Unlabelled construction / setup ó [VmPlane.agm:436](../scripts\game\vehicles\vm_plane.gd#L436)

### VmPlane.antenna

- Unlabelled construction / setup ó [VmPlane.antenna:466](../scripts\game\vehicles\vm_plane.gd#L466)

### VmPlane.band

- Unlabelled construction / setup ó [VmPlane.band:176](../scripts\game\vehicles\vm_plane.gd#L176)

### VmPlane.body

- Unlabelled construction / setup ó [VmPlane.body:148](../scripts\game\vehicles\vm_plane.gd#L148)

### VmPlane.body2

- Unlabelled construction / setup ó [VmPlane.body2:158](../scripts\game\vehicles\vm_plane.gd#L158)

### VmPlane.bomb

- Unlabelled construction / setup ó [VmPlane.bomb:396](../scripts\game\vehicles\vm_plane.gd#L396)
- the yellow high-explosive band, the lugs ó [VmPlane.bomb:399](../scripts\game\vehicles\vm_plane.gd#L399)

### VmPlane.drop_tank

- Unlabelled construction / setup ó [VmPlane.drop_tank:447](../scripts\game\vehicles\vm_plane.gd#L447)

### VmPlane.glow

- Unlabelled construction / setup ó [VmPlane.glow:267](../scripts\game\vehicles\vm_plane.gd#L267)
- (the texture's alpha makes it a soft round glow, not a lit square) ó [VmPlane.glow:275](../scripts\game\vehicles\vm_plane.gd#L275)

### VmPlane.gun_pod

- Unlabelled construction / setup ó [VmPlane.gun_pod:456](../scripts\game\vehicles\vm_plane.gd#L456)

### VmPlane.lift_fan

- Unlabelled construction / setup ó [VmPlane.lift_fan:1401](../scripts\game\vehicles\vm_plane.gd#L1401)

### VmPlane.missile

- Unlabelled construction / setup ó [VmPlane.missile:422](../scripts\game\vehicles\vm_plane.gd#L422)

### VmPlane.mouth

- Unlabelled construction / setup ó [VmPlane.mouth:214](../scripts\game\vehicles\vm_plane.gd#L214)

### VmPlane.nav_lights

- Unlabelled construction / setup ó [VmPlane.nav_lights:472](../scripts\game\vehicles\vm_plane.gd#L472)

### VmPlane.nozzle

- Unlabelled construction / setup ó [VmPlane.nozzle:305](../scripts\game\vehicles\vm_plane.gd#L305)

### VmPlane.prop

- Unlabelled construction / setup ó [VmPlane.prop:343](../scripts\game\vehicles\vm_plane.gd#L343)
- the axis the blades turn about, in the pivot's own space (aft is +z, or +y for a rotor) ó [VmPlane.prop:352](../scripts\game\vehicles\vm_plane.gd#L352)
- the spinner: a pointed cone ahead of the hub ó [VmPlane.prop:354](../scripts\game\vehicles\vm_plane.gd#L354)

### VmPlane.pylon

- Unlabelled construction / setup ó [VmPlane.pylon:390](../scripts\game\vehicles\vm_plane.gd#L390)

### VmPlane.rocket_pod

- Unlabelled construction / setup ó [VmPlane.rocket_pod:416](../scripts\game\vehicles\vm_plane.gd#L416)

### VmPlane.rod

- Unlabelled construction / setup ó [VmPlane.rod:259](../scripts\game\vehicles\vm_plane.gd#L259)

### VmPlane.sec

- Unlabelled construction / setup ó [VmPlane.sec:104](../scripts\game\vehicles\vm_plane.gd#L104)

### VmPlane.skin

- Unlabelled construction / setup ó [VmPlane.skin:72](../scripts\game\vehicles\vm_plane.gd#L72)

### VmPlane.st_at

- Unlabelled construction / setup ó [VmPlane.st_at:131](../scripts\game\vehicles\vm_plane.gd#L131)

### VmPlane.stripe

- Unlabelled construction / setup ó [VmPlane.stripe:188](../scripts\game\vehicles\vm_plane.gd#L188)

### VmPlane.surf

- Unlabelled construction / setup ó [VmPlane.surf:238](../scripts\game\vehicles\vm_plane.gd#L238)

### VmPlane.surf_at

- Unlabelled construction / setup ó [VmPlane.surf_at:246](../scripts\game\vehicles\vm_plane.gd#L246)

### VmPlane.wing_marks

- Unlabelled construction / setup ó [VmPlane.wing_marks:479](../scripts\game\vehicles\vm_plane.gd#L479)

### VmShips._at

- Unlabelled construction / setup ó [VmShips._at:156](../scripts\game\vehicles\vm_ships.gd#L156)

### VmShips._bitts

- Unlabelled construction / setup ó [VmShips._bitts:376](../scripts\game\vehicles\vm_ships.gd#L376)

### VmShips._box_mesh

- Unlabelled construction / setup ó [VmShips._box_mesh:313](../scripts\game\vehicles\vm_ships.gd#L313)

### VmShips._bulwark

- Unlabelled construction / setup ó [VmShips._bulwark:73](../scripts\game\vehicles\vm_ships.gd#L73)

### VmShips._bx

- Unlabelled construction / setup ó [VmShips._bx:309](../scripts\game\vehicles\vm_ships.gd#L309)

### VmShips._coil

- Unlabelled construction / setup ó [VmShips._coil:381](../scripts\game\vehicles\vm_ships.gd#L381)

### VmShips._decal

- Unlabelled construction / setup ó [VmShips._decal:232](../scripts\game\vehicles\vm_ships.gd#L232)

### VmShips._deck_mesh

- Unlabelled construction / setup ó [VmShips._deck_mesh:207](../scripts\game\vehicles\vm_ships.gd#L207)

### VmShips._deck_y

- Unlabelled construction / setup ó [VmShips._deck_y:65](../scripts\game\vehicles\vm_ships.gd#L65)

### VmShips._digits

- Unlabelled construction / setup ó [VmShips._digits:249](../scripts\game\vehicles\vm_ships.gd#L249)
- where along the side this digit sits: reading from outboard ó [VmShips._digits:255](../scripts\game\vehicles\vm_ships.gd#L255)
- the side reads toward the bow on the right (-z), aft on the left ó [VmShips._digits:278](../scripts\game\vehicles\vm_ships.gd#L278)

### VmShips._dk

- Unlabelled construction / setup ó [VmShips._dk:160](../scripts\game\vehicles\vm_ships.gd#L160)

### VmShips._dshk

- Unlabelled construction / setup ó [VmShips._dshk:583](../scripts\game\vehicles\vm_ships.gd#L583)

### VmShips._flag

- Unlabelled construction / setup ó [VmShips._flag:424](../scripts\game\vehicles\vm_ships.gd#L424)

### VmShips._hull

- Unlabelled construction / setup ó [VmShips._hull:177](../scripts\game\vehicles\vm_ships.gd#L177)

### VmShips._hull_bands

- Unlabelled construction / setup ó [VmShips._hull_bands:188](../scripts\game\vehicles\vm_ships.gd#L188)

### VmShips._insert

- Unlabelled construction / setup ó [VmShips._insert:134](../scripts\game\vehicles\vm_ships.gd#L134)

### VmShips._keel_y

- Unlabelled construction / setup ó [VmShips._keel_y:79](../scripts\game\vehicles\vm_ships.gd#L79)

### VmShips._liferaft

- Unlabelled construction / setup ó [VmShips._liferaft:400](../scripts\game\vehicles\vm_ships.gd#L400)
- the cradle's saddle ó [VmShips._liferaft:409](../scripts\game\vehicles\vm_ships.gd#L409)

### VmShips._lifering

- Unlabelled construction / setup ó [VmShips._lifering:388](../scripts\game\vehicles\vm_ships.gd#L388)

### VmShips._m2

- Unlabelled construction / setup ó [VmShips._m2:511](../scripts\game\vehicles\vm_ships.gd#L511)

### VmShips._mk38

- Unlabelled construction / setup ó [VmShips._mk38:467](../scripts\game\vehicles\vm_ships.gd#L467)
- the carriage: a low chamfered box on the turntable, the trunnion arms ó [VmShips._mk38:475](../scripts\game\vehicles\vm_ships.gd#L475)
- the cradle housing: chamfered section, its nose tapering round the barrel ó [VmShips._mk38:480](../scripts\game\vehicles\vm_ships.gd#L480)
- the barrel: a support sleeve, the long tapering tube, a muzzle device ó [VmShips._mk38:486](../scripts\game\vehicles\vm_ships.gd#L486)
- the electro-optical sight on the left, its windows forward ó [VmShips._mk38:490](../scripts\game\vehicles\vm_ships.gd#L490)
- the ammunition box on the right and its feed chute into the receiver ó [VmShips._mk38:496](../scripts\game\vehicles\vm_ships.gd#L496)
- the spent case chute under the housing, a cable loom at the back ó [VmShips._mk38:501](../scripts\game\vehicles\vm_ships.gd#L501)

### VmShips._rod

- Unlabelled construction / setup ó [VmShips._rod:325](../scripts\game\vehicles\vm_ships.gd#L325)

### VmShips._searchlight

- Unlabelled construction / setup ó [VmShips._searchlight:448](../scripts\game\vehicles\vm_ships.gd#L448)

### VmShips._station

- Unlabelled construction / setup ó [VmShips._station:87](../scripts\game\vehicles\vm_ships.gd#L87)
- a round bilge: a quarter superellipse from the keel up to the bilge's top, full amidships, easing into a V toward the bow ó [VmShips._station:101](../scripts\game\vehicles\vm_ships.gd#L101)
- points where the paint changes and at the deck's edge (always added, so every station of a hull has the same count) ó [VmShips._station:112](../scripts\game\vehicles\vm_ships.gd#L112)
- keep the section convex ó [VmShips._station:119](../scripts\game\vehicles\vm_ships.gd#L119)

### VmShips._stem_z

- Unlabelled construction / setup ó [VmShips._stem_z:165](../scripts\game\vehicles\vm_ships.gd#L165)

### VmShips._surf

- Unlabelled construction / setup ó [VmShips._surf:218](../scripts\game\vehicles\vm_ships.gd#L218)
- reading from outboard: toward the bow on the right side, aft on the left ó [VmShips._surf:223](../scripts\game\vehicles\vm_ships.gd#L223)

### VmShips._sweep

- Unlabelled construction / setup ó [VmShips._sweep:286](../scripts\game\vehicles\vm_ships.gd#L286)

### VmShips._torus

- Unlabelled construction / setup ó [VmShips._torus:348](../scripts\game\vehicles\vm_ships.gd#L348)

### VmShips._tube

- Unlabelled construction / setup ó [VmShips._tube:329](../scripts\game\vehicles\vm_ships.gd#L329)

### VmShips._u

- Unlabelled construction / setup ó [VmShips._u:152](../scripts\game\vehicles\vm_ships.gd#L152)

### VmShips._vent

- Unlabelled construction / setup ó [VmShips._vent:418](../scripts\game\vehicles\vm_ships.gd#L418)

### VmShips._whip

- Unlabelled construction / setup ó [VmShips._whip:442](../scripts\game\vehicles\vm_ships.gd#L442)

### VmShips._zu23

- Unlabelled construction / setup ó [VmShips._zu23:526](../scripts\game\vehicles\vm_ships.gd#L526)
- the lower carriage: a triangle of box beams with levelling jacks ó [VmShips._zu23:528](../scripts\game\vehicles\vm_ships.gd#L528)
- crude welds: a gusset onto the deck plate ó [VmShips._zu23:537](../scripts\game\vehicles\vm_ships.gd#L537)
- the upper carriage: a floor, two side frames up to the trunnions ó [VmShips._zu23:541](../scripts\game\vehicles\vm_ships.gd#L541)
- receivers, barrel jackets, barrels and flash hiders ó [VmShips._zu23:549](../scripts\game\vehicles\vm_ships.gd#L549)
- the box magazine on the gun's outer side ó [VmShips._zu23:556](../scripts\game\vehicles\vm_ships.gd#L556)
- the cradle tying the two guns, the sight standing up on the left ó [VmShips._zu23:560](../scripts\game\vehicles\vm_ships.gd#L560)
- two seats with backrests behind the guns, handwheels in front of them ó [VmShips._zu23:566](../scripts\game\vehicles\vm_ships.gd#L566)
- a slab of steel plate welded on in front of the cradle ó [VmShips._zu23:573](../scripts\game\vehicles\vm_ships.gd#L573)

