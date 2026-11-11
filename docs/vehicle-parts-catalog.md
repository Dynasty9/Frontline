# Vehicle construction part catalog

Source revision: `a4647877`. 137 model keys, 84 construction-root groups.

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

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmAttack._a10:318](../scripts/game/vehicles/vm_attack.gd#L318)
- Compass Ghost: the darker grey over the nose and cockpit, down the spine — [VmAttack._a10:344](../scripts/game/vehicles/vm_attack.gd#L344)
- panel joints round the fuselage — [VmAttack._a10:347](../scripts/game/vehicles/vm_attack.gd#L347)

**Local helper construction:** `VmAttack._a10_cockpit`, `VmAttack._a10_details`, `VmAttack._a10_engines`, `VmAttack._a10_gear`, `VmAttack._a10_gun`, `VmAttack._a10_stores`, `VmAttack._a10_tail`, `VmAttack._a10_wing`, `VmAttack._decal`, `VmAttack._ecm_pod`, `VmAttack._fin_at`, `VmAttack._gear_nodes`, `VmAttack._lathe`, `VmAttack._sec_pt`, `VmAttack._skin_x`, `VmAttack._skin_y`, `VmAttack._sniper`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmPlane._foil_t`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### aa_tech, technical

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._hilux:818](../scripts/game/vehicles/vm_core.gd#L818)
- ladder frame, the front diff and the rear axle, the exhaust, fuel tank — [VmCore._hilux:827](../scripts/game/vehicles/vm_core.gd#L827)
- the body: bonnet, front wings and the cab's lower half in one panel, the bed's sides in another, their arches cut round the wheels — [VmCore._hilux:835](../scripts/game/vehicles/vm_core.gd#L835)
- the bed: its walls, the top rails, the wheel tubs, a ribbed floor — [VmCore._hilux:841](../scripts/game/vehicles/vm_core.gd#L841)
- the tailgate hanging open on its chains, dented — [VmCore._hilux:850](../scripts/game/vehicles/vm_core.gd#L850)
- the glasshouse: the windscreen raked well back, the four-door cab, its back window; the panes laid on its faces — [VmCore._hilux:854](../scripts/game/vehicles/vm_core.gd#L854)
- the doors: shut lines, handles; one rear door a replacement in primer — [VmCore._hilux:869](../scripts/game/vehicles/vm_core.gd#L869)
- mud up the sills and round the arches — [VmCore._hilux:877](../scripts/game/vehicles/vm_core.gd#L877)
- wing mirrors at the windscreen's foot — [VmCore._hilux:879](../scripts/game/vehicles/vm_core.gd#L879)
- arches flared in black, rust round the rear ones, the side step — [VmCore._hilux:881](../scripts/game/vehicles/vm_core.gd#L881)
- tail lights up the bed's corners — [VmCore._hilux:888](../scripts/game/vehicles/vm_core.gd#L888)
- brushed-on sand camouflage on some: blotches down the flanks — [VmCore._hilux:893](../scripts/game/vehicles/vm_core.gd#L893)
- the face: grille, square headlights, indicators, a dented bumper and the pipe bull bar welded across it, the number plate long gone — [VmCore._hilux:900](../scripts/game/vehicles/vm_core.gd#L900)
- the rear: a step bumper, the tow ball — [VmCore._hilux:917](../scripts/game/vehicles/vm_core.gd#L917)
- wipers, a whip antenna on the wing — [VmCore._hilux:921](../scripts/game/vehicles/vm_core.gd#L921)
- the roll bar behind the cab — [VmCore._hilux:925](../scripts/game/vehicles/vm_core.gd#L925)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._bar`, `VmCore._bx`, `VmCore._dshk`, `VmCore._hilux_dshk`, `VmCore._jerry`, `VmCore._path`, `VmCore._tube`, `VmCore._zu23`.

### ac130

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup — [VmGunship._ac130:331](../scripts/game/vehicles/vm_gunship.gd#L331)
- the fuselage: the radome, the flight deck, the long constant section of the cargo hold (belly 0.65 m up, roof 4.75 m), the upswept tail — [VmGunship._ac130:334](../scripts/game/vehicles/vm_gunship.gd#L334)
- the radome's joint, frame joints down the fuselage — [VmGunship._ac130:356](../scripts/game/vehicles/vm_gunship.gd#L356)
- the main gear sponsons along the lower sides — [VmGunship._ac130:363](../scripts/game/vehicles/vm_gunship.gd#L363)
- the closed wheel-well doors under each sponson, the joint at its nose — [VmGunship._ac130:369](../scripts/game/vehicles/vm_gunship.gd#L369)
- the chaff and flare dispensers in the sponson's tail — [VmGunship._ac130:374](../scripts/game/vehicles/vm_gunship.gd#L374)
- the wing on top: a constant-chord centre section out past the inboard engines, tapered outer panels with 2.5 degrees of dihedral; Fowler flaps inboard, ailerons outboard — [VmGunship._ac130:378](../scripts/game/vehicles/vm_gunship.gd#L378)
- the fairing over the wing root on top of the fuselage — [VmGunship._ac130:387](../scripts/game/vehicles/vm_gunship.gd#L387)
- the engines: long T56 nacelles slung under the wing, four-blade props — [VmGunship._ac130:390](../scripts/game/vehicles/vm_gunship.gd#L390)
- the tail: the stabiliser with its elevators, the fin and rudder, the dorsal fillet running forward along the top — [VmGunship._ac130:403](../scripts/game/vehicles/vm_gunship.gd#L403)
- the tail cone: the white tail light, the warning sensors either side — [VmGunship._ac130:410](../scripts/game/vehicles/vm_gunship.gd#L410)
- the anti-collision beacons, the antennas, the SATCOM dome — [VmGunship._ac130:415](../scripts/game/vehicles/vm_gunship.gd#L415)
- the formation lights: pale green strips on the nose, the tail and the fin — [VmGunship._ac130:423](../scripts/game/vehicles/vm_gunship.gd#L423)
- markings: the black outline insignia aft and on the wings, team panels — [VmGunship._ac130:430](../scripts/game/vehicles/vm_gunship.gd#L430)
- the tail number: the fiscal year small, the serial under it — [VmGunship._ac130:439](../scripts/game/vehicles/vm_gunship.gd#L439)

**Local helper construction:** `VmGunship._ac130_cockpit`, `VmGunship._ac130_doors`, `VmGunship._ac130_gear`, `VmGunship._ac130_guns`, `VmGunship._ang`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._insignia_tris`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._shift`, `VmGunship._t56`, `VmGunship._text_tris`, `VmGunship._tyre`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### angara, angara_k

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._angara:1154](../scripts/game/vehicles/vm_csat.gd#L1154)
- the gun slot and mask, the 125 mm, the coax — [VmCsat._angara:1161](../scripts/game/vehicles/vm_csat.gd#L1161)
- Afghanit: five launch tubes in a housing low on each flank, firing out — [VmCsat._angara:1167](../scripts/game/vehicles/vm_csat.gd#L1167)
- radar panels on the corners — [VmCsat._angara:1174](../scripts/game/vehicles/vm_csat.gd#L1174)
- the soft-kill smoke launchers on the roof — [VmCsat._angara:1177](../scripts/game/vehicles/vm_csat.gd#L1177)
- the gunner's sight (front left) and the commander's panoramic sight — [VmCsat._angara:1182](../scripts/game/vehicles/vm_csat.gd#L1182)
- the remote weapon on top: a 12.7 mm, or the command tank's 30 mm turret — [VmCsat._angara:1190](../scripts/game/vehicles/vm_csat.gd#L1190)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._slats`, `VmCsat._sprocket`, `VmCsat._t14`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### apc, btr

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._btr80:1170](../scripts/game/vehicles/vm_core.gd#L1170)
- the hull: belly, the wheel wells' roof, the crease, the upper sides — [VmCore._btr80:1175](../scripts/game/vehicles/vm_core.gd#L1175)
- the wheels on their axles, the wells' dark liners, mud flaps — [VmCore._btr80:1183](../scripts/game/vehicles/vm_core.gd#L1183)
- the bow: the trim vane folded against the lower bow plate, tow hooks, a splash rail across the stem — [VmCore._btr80:1190](../scripts/game/vehicles/vm_core.gd#L1190)
- the upper glacis and the window plate: the driver's and commander's windows with their shutters propped open, the lights in guards on the corners, the IR light on the left — [VmCore._btr80:1199](../scripts/game/vehicles/vm_core.gd#L1199)
- the shutter hinged at the top, propped up and out — [VmCore._btr80:1212](../scripts/game/vehicles/vm_core.gd#L1212)
- the roof: driver's and commander's hatches at the front, the troop hatches behind the turret, periscopes along the edges — [VmCore._btr80:1220](../scripts/game/vehicles/vm_core.gd#L1220)
- the side doors between the second and third axles: the upper half in the sloped side, the lower half below the crease; firing ports, the stowage boxes and the exhausts aft, tow cable — [VmCore._btr80:1227](../scripts/game/vehicles/vm_core.gd#L1227)
- the lower half, below the crease, folding down into a step — [VmCore._btr80:1242](../scripts/game/vehicles/vm_core.gd#L1242)
- the engine deck: the louvred grilles, the access panels — [VmCore._btr80:1253](../scripts/game/vehicles/vm_core.gd#L1253)
- the stern: the water-jet's flap, tail lights, tow hooks, the antenna — [VmCore._btr80:1258](../scripts/game/vehicles/vm_core.gd#L1258)
- --- the BPU-1 turret: a low cone, the mantlet, the KPVT and the PKT — [VmCore._btr80:1265](../scripts/game/vehicles/vm_core.gd#L1265)
- the KPVT: the perforated jacket over its rear half, the bare barrel, the muzzle — [VmCore._btr80:1274](../scripts/game/vehicles/vm_core.gd#L1274)
- the gunner's sight on the left of the roof, a vision block right, the hatch — [VmCore._btr80:1283](../scripts/game/vehicles/vm_core.gd#L1283)
- six smoke dischargers in a row across the back, firing over the turret — [VmCore._btr80:1289](../scripts/game/vehicles/vm_core.gd#L1289)

**Local helper construction:** `VmCore._antenna`, `VmCore._bx`, `VmCore._cam`, `VmCore._hatch`, `VmCore._lamp`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmCore._zy`.

### assault_boat

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._zodiac:452](../scripts/game/vehicles/vm_boat.gd#L452)
- the tube's centreline: straight sides into a round bow that kicks up — [VmBoat._zodiac:457](../scripts/game/vehicles/vm_boat.gd#L457)
- the tube ends: cones past the transom — [VmBoat._zodiac:468](../scripts/game/vehicles/vm_boat.gd#L468)
- compartment seams round the tube — [VmBoat._zodiac:471](../scripts/game/vehicles/vm_boat.gd#L471)
- inflation valves on top — [VmBoat._zodiac:475](../scripts/game/vehicles/vm_boat.gd#L475)
- the hull: a shallow V of fabric under a flat floor, rising into the bow — [VmBoat._zodiac:479](../scripts/game/vehicles/vm_boat.gd#L479)
- aluminium floorboards — [VmBoat._zodiac:488](../scripts/game/vehicles/vm_boat.gd#L488)
- the transom with its knees and the motor pad — [VmBoat._zodiac:491](../scripts/game/vehicles/vm_boat.gd#L491)
- 55 hp outboard on a tiller, its fuel tank and hose — [VmBoat._zodiac:496](../scripts/game/vehicles/vm_boat.gd#L496)
- two paddles along the tubes, a rucksack and a dry bag lashed amidships — [VmBoat._zodiac:505](../scripts/game/vehicles/vm_boat.gd#L505)
- the bow's towing ring and grab handle — [VmBoat._zodiac:513](../scripts/game/vehicles/vm_boat.gd#L513)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._foil`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._tube`, `VmBoat._tube_kit`.

### blackfish, blackfish_armed

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.build`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup — [VmGunship._blackfish:644](../scripts/game/vehicles/vm_gunship.gd#L644)
- the blue underside, up to a line along the lower flanks — [VmGunship._blackfish:668](../scripts/game/vehicles/vm_gunship.gd#L668)
- the sponsons: the main gear, fuel, the chaff and flare dispensers — [VmGunship._blackfish:675](../scripts/game/vehicles/vm_gunship.gd#L675)
- the wing: straight, a touch of forward sweep, thick; flaperons along it — [VmGunship._blackfish:687](../scripts/game/vehicles/vm_gunship.gd#L687)
- the fairing over the wing's centre section — [VmGunship._blackfish:693](../scripts/game/vehicles/vm_gunship.gd#L693)
- the nacelles on their tilt pivots at the tips, the proprotors (the right one a mirror image, turning the other way) — [VmGunship._blackfish:696](../scripts/game/vehicles/vm_gunship.gd#L696)
- the dorsal spine from the wing back to the tail, the formation lights — [VmGunship._blackfish:709](../scripts/game/vehicles/vm_gunship.gd#L709)
- the targeting turret under the nose, antennas, the beacons — [VmGunship._blackfish:718](../scripts/game/vehicles/vm_gunship.gd#L718)
- team panels on the wings and the tail — [VmGunship._blackfish:732](../scripts/game/vehicles/vm_gunship.gd#L732)

**Local helper construction:** `VmGunship._ang`, `VmGunship._bf_cockpit`, `VmGunship._bf_doors`, `VmGunship._bf_gear`, `VmGunship._bf_guns`, `VmGunship._bf_nacelle`, `VmGunship._bf_tail`, `VmGunship._decal`, `VmGunship._dmesh`, `VmGunship._door`, `VmGunship._fin_at`, `VmGunship._gear_node`, `VmGunship._half_w`, `VmGunship._patch`, `VmGunship._propeller`, `VmGunship._ribbon`, `VmGunship._seam`, `VmGunship._tyre`, `VmGunship._under`, `VmGunship._wing_lines`, `VmPlane._foil_t`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.mouth`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### blackfoot

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._blackfoot:739](../scripts/game/vehicles/vm_heli.gd#L739)
- the stepped tandem canopy, framed, and the night-pilotage window — [VmHeli._blackfoot:759](../scripts/game/vehicles/vm_heli.gd#L759)
- the bays, open; engine inlets; exhaust slots down the tail — [VmHeli._blackfoot:766](../scripts/game/vehicles/vm_heli.gd#L766)
- the mast fairing and mast — [VmHeli._blackfoot:771](../scripts/game/vehicles/vm_heli.gd#L771)
- the fantail: a shroud with an open duct, a fin over it, the T-tail — [VmHeli._blackfoot:775](../scripts/game/vehicles/vm_heli.gd#L775)
- tailwheel under the boom — [VmHeli._blackfoot:785](../scripts/game/vehicles/vm_heli.gd#L785)
- main gear legs out of their stubs — [VmHeli._blackfoot:790](../scripts/game/vehicles/vm_heli.gd#L790)
- the bay doors opened out: three Hellfires on rails under each — [VmHeli._blackfoot:796](../scripts/game/vehicles/vm_heli.gd#L796)
- the chin turret: XM301 three-barrel 20 mm — [VmHeli._blackfoot:805](../scripts/game/vehicles/vm_heli.gd#L805)
- pitots and an antenna — [VmHeli._blackfoot:815](../scripts/game/vehicles/vm_heli.gd#L815)
- the rotor: five blades with swept tips, a faceted hub shroud — [VmHeli._blackfoot:819](../scripts/game/vehicles/vm_heli.gd#L819)

**Local helper construction:** `VmHeli._air`, `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rotor`, `VmHeli._tube`.

### blackwasp

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.gear_leg`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup — [VmFighter._blackwasp:997](../scripts/game/vehicles/vm_fighter.gd#L997)
- --- fuselage: [z, crown, shoulder x y, chine x y half-thickness, LEX underside corner x y, side wall foot x y, belly corner x y, keel] — [VmFighter._blackwasp:1006](../scripts/game/vehicles/vm_fighter.gd#L1006)
- the F-22-style one-piece canopy, gold-coated, its sill frame — [VmFighter._blackwasp:1030](../scripts/game/vehicles/vm_fighter.gd#L1030)
- --- intakes and engine nacelles: caret mouths raked in two planes, the ducts turning round into the engines, the nozzles — [VmFighter._blackwasp:1038](../scripts/game/vehicles/vm_fighter.gd#L1038)
- the nozzle: a hollow can, short sawtooth teeth round its lip, the flame holder deep inside — [VmFighter._blackwasp:1057](../scripts/game/vehicles/vm_fighter.gd#L1057)
- --- wing: trapezoid, LE flaps, flaperons inboard, ailerons outboard — [VmFighter._blackwasp:1071](../scripts/game/vehicles/vm_fighter.gd#L1071)
- diamond stabilators on the tail shelves — [VmFighter._blackwasp:1075](../scripts/game/vehicles/vm_fighter.gd#L1075)
- twin fins canted 22 degrees out, rudders — [VmFighter._blackwasp:1077](../scripts/game/vehicles/vm_fighter.gd#L1077)
- --- details: the gun port in the right LEX, the EOTS window under the nose, the tail hook, antennas, lights — [VmFighter._blackwasp:1084](../scripts/game/vehicles/vm_fighter.gd#L1084)
- the arrestor hook stowed between the nozzles, its point showing — [VmFighter._blackwasp:1099](../scripts/game/vehicles/vm_fighter.gd#L1099)
- --- panel lines: the weapon bay doors and the gear doors (sawtooth ends), the radome joint, access panels on the deck — [VmFighter._blackwasp:1113](../scripts/game/vehicles/vm_fighter.gd#L1113)
- the radome joint: a sawtooth across the chined nose — [VmFighter._blackwasp:1135](../scripts/game/vehicles/vm_fighter.gd#L1135)
- deck access panels and the fuel tank doors over the LEX — [VmFighter._blackwasp:1139](../scripts/game/vehicles/vm_fighter.gd#L1139)
- the side weapon bays in the intake walls, the engine bay doors under the nacelles, the refuelling probe's door on the right of the nose — [VmFighter._blackwasp:1147](../scripts/game/vehicles/vm_fighter.gd#L1147)
- radar-absorbent dark caps on the fin tips — [VmFighter._blackwasp:1168](../scripts/game/vehicles/vm_fighter.gd#L1168)
- --- markings: low-visibility Navy star-and-bar, the air wing's tail code, the modex on the nose — [VmFighter._blackwasp:1173](../scripts/game/vehicles/vm_fighter.gd#L1173)
- --- landing gear (shown on the ground): twin nose wheels with the catapult launch bar, the main legs out of the intake trunks, open doors — [VmFighter._blackwasp:1190](../scripts/game/vehicles/vm_fighter.gd#L1190)

**Local helper construction:** `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._bw_half`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._cloop`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._ft`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._loop`, `VmFighter._mesh`, `VmFighter._mixloop`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._project`, `VmFighter._put`, `VmFighter._qloop`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmFighter._zigzag`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### bobcat

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleEquipment.skirt`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._bobcat:1180](../scripts/game/vehicles/vm_nato.gd#L1180)
- the dozer blade, raised for travel: a curved mouldboard of three facets, its cutting edge, the push arms and the lifting rams — [VmNato._bobcat:1183](../scripts/game/vehicles/vm_nato.gd#L1183)
- the crane: its slewing base on the roof's back right, the boom folded forward along the right side onto a rest, the hook stowed — [VmNato._bobcat:1198](../scripts/game/vehicles/vm_nato.gd#L1198)
- the main winch drum at the back of the roof, tow bars and tools — [VmNato._bobcat:1210](../scripts/game/vehicles/vm_nato.gd#L1210)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### buzzard

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._buzzard:492](../scripts/game/vehicles/vm_plane.gd#L492)
- the radome a shade darker, a joint band behind it — [VmPlane._buzzard:512](../scripts/game/vehicles/vm_plane.gd#L512)
- dorsal spine from the canopy to the fin — [VmPlane._buzzard:515](../scripts/game/vehicles/vm_plane.gd#L515)
- the canopy: windscreen and bubble, its bows — [VmPlane._buzzard:517](../scripts/game/vehicles/vm_plane.gd#L517)
- the intakes: D-shaped mouths standing off the fuselage on splitter plates — [VmPlane._buzzard:523](../scripts/game/vehicles/vm_plane.gd#L523)
- the wing: tapered, a little dihedral, flaps and ailerons — [VmPlane._buzzard:532](../scripts/game/vehicles/vm_plane.gd#L532)
- tip tanks with their navigation lights — [VmPlane._buzzard:535](../scripts/game/vehicles/vm_plane.gd#L535)
- tailplane and fin (rudder, elevators), the dorsal fillet — [VmPlane._buzzard:540](../scripts/game/vehicles/vm_plane.gd#L540)
- the jet pipe — [VmPlane._buzzard:545](../scripts/game/vehicles/vm_plane.gd#L545)
- probes, antennas, the airbrakes under the belly — [VmPlane._buzzard:548](../scripts/game/vehicles/vm_plane.gd#L548)
- stores: gun pod on the centreline; bombs, rocket pods, Sidewinders — [VmPlane._buzzard:554](../scripts/game/vehicles/vm_plane.gd#L554)
- national markings — [VmPlane._buzzard:570](../scripts/game/vehicles/vm_plane.gd#L570)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### caesar

**Shared:** `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._caesar:785](../scripts/game/vehicles/vm_plane.gd#L785)
- the livery: a stripe down each flank, a pinstripe above it — [VmPlane._caesar:802](../scripts/game/vehicles/vm_plane.gd#L802)
- the cabin: a glass house, its pillars and a painted roof — [VmPlane._caesar:808](../scripts/game/vehicles/vm_plane.gd#L808)
- door seams — [VmPlane._caesar:816](../scripts/game/vehicles/vm_plane.gd#L816)
- cowl inlets and exhaust stacks, the landing light — [VmPlane._caesar:820](../scripts/game/vehicles/vm_plane.gd#L820)
- the wing: low, tapered, dihedral, flaps and ailerons, upturned tips — [VmPlane._caesar:824](../scripts/game/vehicles/vm_plane.gd#L824)
- tail: the swept fin and the stabiliser — [VmPlane._caesar:829](../scripts/game/vehicles/vm_plane.gd#L829)
- fixed tricycle gear: a nose leg, spring-steel mains, wheels in spats — [VmPlane._caesar:833](../scripts/game/vehicles/vm_plane.gd#L833)
- the propeller: three blades with painted tips, the spinner — [VmPlane._caesar:842](../scripts/game/vehicles/vm_plane.gd#L842)
- antennas on the roof and belly, the pitot under the left wing — [VmPlane._caesar:844](../scripts/game/vehicles/vm_plane.gd#L844)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`.

### cheetah

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleEquipment.skirt`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._cheetah:1224](../scripts/game/vehicles/vm_nato.gd#L1224)
- a 35 mm on each flank: the trunnion housing, the cradle, the long barrel with its muzzle velocity radar ring and brake — [VmNato._cheetah:1233](../scripts/game/vehicles/vm_nato.gd#L1233)
- the ammunition feed chute and the missile box above the gun — [VmNato._cheetah:1244](../scripts/game/vehicles/vm_nato.gd#L1244)
- the tracking radar (a dish in a drum) on the front of the roof, the optics beside it — [VmNato._cheetah:1254](../scripts/game/vehicles/vm_nato.gd#L1254)
- hatches, the search radar on its folding mast at the back — [VmNato._cheetah:1260](../scripts/game/vehicles/vm_nato.gd#L1260)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### civilian_0, civilian_1, civilian_2, civilian_3, civilian_4

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VehicleModels._car:602](../scripts/game/vehicle_models.gd#L602)
- glass: windscreen, rear screen, side windows (inset a touch) — [VehicleModels._car:626](../scripts/game/vehicle_models.gd#L626)
- bumpers, lights, plate — [VehicleModels._car:650](../scripts/game/vehicle_models.gd#L650)
- the bed: sides and tailgate — [VehicleModels._car:662](../scripts/game/vehicle_models.gd#L662)
- wheels in dark arches — [VehicleModels._car:667](../scripts/game/vehicle_models.gd#L667)

### darter

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._darter:1446](../scripts/game/vehicles/vm_heli.gd#L1446)
- the X of arms, a motor and guard ring at each end — [VmHeli._darter:1460](../scripts/game/vehicles/vm_heli.gd#L1460)
- lights: green on the right, red on the left, white aft — [VmHeli._darter:1474](../scripts/game/vehicles/vm_heli.gd#L1474)
- the camera on its gimbal under the nose — [VmHeli._darter:1480](../scripts/game/vehicles/vm_heli.gd#L1480)
- skids — [VmHeli._darter:1484](../scripts/game/vehicles/vm_heli.gd#L1484)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._tube`.

### demining_drone, utility_drone

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._hexa:1496](../scripts/game/vehicles/vm_heli.gd#L1496)
- the hub: a hexagonal frame, the dome, the battery under it — [VmHeli._hexa:1503](../scripts/game/vehicles/vm_heli.gd#L1503)
- six arms, alternately turning props, orientation colours on the front pair — [VmHeli._hexa:1511](../scripts/game/vehicles/vm_heli.gd#L1511)
- skids on two legs each — [VmHeli._hexa:1522](../scripts/game/vehicles/vm_heli.gd#L1522)
- a rack of four demolition charges and the ground-scanning sensor — [VmHeli._hexa:1528](../scripts/game/vehicles/vm_heli.gd#L1528)
- the cargo box on its release hook — [VmHeli._hexa:1541](../scripts/game/vehicles/vm_heli.gd#L1541)

**Local helper construction:** `VmHeli._prop`, `VmHeli._rbox`, `VmHeli._tube`.

### ed1

**Shared:** `VehicleBody.paint_mesh`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._ed1:1464](../scripts/game/vehicles/vm_civ.gd#L1464)
- the flippers, swung forward and up off the front sprockets — [VmCiv._ed1:1476](../scripts/game/vehicles/vm_civ.gd#L1476)
- carry handles on the hull sides — [VmCiv._ed1:1481](../scripts/game/vehicles/vm_civ.gd#L1481)
- the payload box at the back — [VmCiv._ed1:1486](../scripts/game/vehicles/vm_civ.gd#L1486)
- the arm, folded: turntable, shoulder, upper arm back, forearm forward — [VmCiv._ed1:1489](../scripts/game/vehicles/vm_civ.gd#L1489)
- the sensor head: cameras and a light, the gripper's jaws under it — [VmCiv._ed1:1500](../scripts/game/vehicles/vm_civ.gd#L1500)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._xbody`.

### falcon

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._falcon:1357](../scripts/game/vehicles/vm_heli.gd#L1357)
- panel seams and access hatches (no windows: nobody aboard) — [VmHeli._falcon:1373](../scripts/game/vehicles/vm_heli.gd#L1373)
- the engine fairing on the back, its intake and exhaust; the mast — [VmHeli._falcon:1378](../scripts/game/vehicles/vm_heli.gd#L1378)
- the boom, fins, stabiliser, the tail rotor on the left — [VmHeli._falcon:1386](../scripts/game/vehicles/vm_heli.gd#L1386)
- the sensor ball under the nose, antennas, the datalink dome — [VmHeli._falcon:1393](../scripts/game/vehicles/vm_heli.gd#L1393)
- skids — [VmHeli._falcon:1400](../scripts/game/vehicles/vm_heli.gd#L1400)
- stub wings with two pylons a side, a small missile on each — [VmHeli._falcon:1402](../scripts/game/vehicles/vm_heli.gd#L1402)
- the rotor: four blades — [VmHeli._falcon:1410](../scripts/game/vehicles/vm_heli.gd#L1410)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### fenghuang

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._fenghuang:1228](../scripts/game/vehicles/vm_plane.gd#L1228)
- canards with elevators; the main wing with ailerons; fins at its tips — [VmPlane._fenghuang:1243](../scripts/game/vehicles/vm_plane.gd#L1243)
- the engine's air scoop on top, the exhaust, the pusher propeller — [VmPlane._fenghuang:1248](../scripts/game/vehicles/vm_plane.gd#L1248)
- the sensor ball — [VmPlane._fenghuang:1254](../scripts/game/vehicles/vm_plane.gd#L1254)
- fixed tricycle gear — [VmPlane._fenghuang:1258](../scripts/game/vehicles/vm_plane.gd#L1258)
- antennas: the satcom blade, a whip — [VmPlane._fenghuang:1264](../scripts/game/vehicles/vm_plane.gd#L1264)
- four small missiles, two under each wing — [VmPlane._fenghuang:1267](../scripts/game/vehicles/vm_plane.gd#L1267)

**Local helper construction:** `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### fia_truck, fia_truck_box

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleEquipment.winch`, `VehicleFittings.headlamp`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._truck:672](../scripts/game/vehicles/vm_civ.gd#L672)
- ladder frame, beam axles with their diffs, fuel tank, battery box — [VmCiv._truck:680](../scripts/game/vehicles/vm_civ.gd#L680)
- the cab over the front wheels, the short nose in front of it — [VmCiv._truck:691](../scripts/game/vehicles/vm_civ.gd#L691)
- shut lines, handle, the steps behind the wheel, mirrors on long arms — [VmCiv._truck:701](../scripts/game/vehicles/vm_civ.gd#L701)
- black flares on the front arch, mudflaps — [VmCiv._truck:711](../scripts/game/vehicles/vm_civ.gd#L711)
- the rear wheel's mudguard under the bed — [VmCiv._truck:716](../scripts/game/vehicles/vm_civ.gd#L716)
- headlights in the nose corners, indicators, roof markers — [VmCiv._truck:718](../scripts/game/vehicles/vm_civ.gd#L718)
- grille between the lamps, the 4x4's steel bumper with a winch, plate — [VmCiv._truck:725](../scripts/game/vehicles/vm_civ.gd#L725)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._truck_bed`, `VmCiv._truck_box`, `VmCiv._truck_rear`, `VmCiv._xbody`.

### futura

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._futura:969](../scripts/game/vehicles/vm_csat.gd#L969)
- seams of the panels on the faceted roof — [VmCsat._futura:977](../scripts/game/vehicles/vm_csat.gd#L977)
- the railgun: a boxy shroud round the breech end, two flat rails ahead held by spacer bands, an open frame at the muzzle — [VmCsat._futura:980](../scripts/game/vehicles/vm_csat.gd#L980)
- the capacitor bank and its cooling vents at the back — [VmCsat._futura:994](../scripts/game/vehicles/vm_csat.gd#L994)
- sights: the gunner's block, the commander's panoramic head, a remote MG — [VmCsat._futura:1000](../scripts/game/vehicles/vm_csat.gd#L1000)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### ghosthawk, ghosthawk_stub

**Shared:** `VehicleAircraft.rocket_pod`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._ghost_hawk:522](../scripts/game/vehicles/vm_heli.gd#L522)
- windscreens: the front panes over the nose, the cockpit door windows — [VmHeli._ghost_hawk:541](../scripts/game/vehicles/vm_heli.gd#L541)
- door seams, the gunners' windows (open), the sliding cabin doors — [VmHeli._ghost_hawk:547](../scripts/game/vehicles/vm_heli.gd#L547)
- the top fairing over the gearbox, the engines either side of it — [VmHeli._ghost_hawk:554](../scripts/game/vehicles/vm_heli.gd#L554)
- the shrouded exhausts, turned out and up — [VmHeli._ghost_hawk:560](../scripts/game/vehicles/vm_heli.gd#L560)
- mast, swashplate, the IR jammer behind, wire cutters, pitots — [VmHeli._ghost_hawk:563](../scripts/game/vehicles/vm_heli.gd#L563)
- steps, a grab handle, the navigation lights — [VmHeli._ghost_hawk:571](../scripts/game/vehicles/vm_heli.gd#L571)
- the tail pylon, the canted tail rotor high on its right, the stabilator — [VmHeli._ghost_hawk:575](../scripts/game/vehicles/vm_heli.gd#L575)
- tailwheel — [VmHeli._ghost_hawk:590](../scripts/game/vehicles/vm_heli.gd#L590)
- main gear: drag beam and shock strut, faceted hub covers — [VmHeli._ghost_hawk:595](../scripts/game/vehicles/vm_heli.gd#L595)
- door guns: miniguns on pintles in the gunners' windows — [VmHeli._ghost_hawk:602](../scripts/game/vehicles/vm_heli.gd#L602)
- the External Stores Support System: anhedral stub wings over the cabin's rear, braced to the floor, two pylons and two pods a side — [VmHeli._ghost_hawk:610](../scripts/game/vehicles/vm_heli.gd#L610)
- the rotor: four blades with swept tips under a faceted hub cap — [VmHeli._ghost_hawk:621](../scripts/game/vehicles/vm_heli.gd#L621)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### gorgon

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._gorgon:727](../scripts/game/vehicles/vm_indep.gd#L727)
- the V-shaped belly between the wheels, the upper hull over them — [VmIndep._gorgon:733](../scripts/game/vehicles/vm_indep.gd#L733)
- the wheel well's dark liner under the overhang — [VmIndep._gorgon:739](../scripts/game/vehicles/vm_indep.gd#L739)
- the hull's side: a chine strake at mid height, stowage boxes aft, the side's lifting eyes — [VmIndep._gorgon:743](../scripts/game/vehicles/vm_indep.gd#L743)
- headlight clusters with guards at the bow's corners, tow eyes — [VmIndep._gorgon:749](../scripts/game/vehicles/vm_indep.gd#L749)
- rear: tail lights, tow eyes, a whip antenna on each corner — [VmIndep._gorgon:752](../scripts/game/vehicles/vm_indep.gd#L752)
- the bow: the trim vane folded on the glacis, its hinge line — [VmIndep._gorgon:756](../scripts/game/vehicles/vm_indep.gd#L756)
- roof: the driver's hatch and periscopes front-left, a mirror; the engine grille front-right; the exhaust on the right flank — [VmIndep._gorgon:761](../scripts/game/vehicles/vm_indep.gd#L761)
- the troop compartment's roof hatches, aft — [VmIndep._gorgon:774](../scripts/game/vehicles/vm_indep.gd#L774)
- the rear door: vision block, handle, hinges; a step under it — [VmIndep._gorgon:778](../scripts/game/vehicles/vm_indep.gd#L778)
- the turret: low and faceted, the 30 mm in its mantlet with the coax beside it, a Titan tube on each side — [VmIndep._gorgon:787](../scripts/game/vehicles/vm_indep.gd#L787)
- the Titan tube on its bracket — [VmIndep._gorgon:802](../scripts/game/vehicles/vm_indep.gd#L802)
- smoke dischargers on the front corners — [VmIndep._gorgon:807](../scripts/game/vehicles/vm_indep.gd#L807)
- roof: the gunner's sight front-left, the commander's panoramic sight right, his hatch behind it — [VmIndep._gorgon:810](../scripts/game/vehicles/vm_indep.gd#L810)
- a stowage basket on the turret's back — [VmIndep._gorgon:820](../scripts/game/vehicles/vm_indep.gd#L820)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._smoke`, `VmIndep._tb`.

### greyhawk

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehiclePropellers.blade`, `VehiclePropellers.circle`, `VehiclePropellers.disc_material`, `VehiclePropellers.spinner`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._greyhawk:1106](../scripts/game/vehicles/vm_plane.gd#L1106)
- the dish housing a shade lighter, its joint line — [VmPlane._greyhawk:1124](../scripts/game/vehicles/vm_plane.gd#L1124)
- the sensor ball under the nose, its window looking forward — [VmPlane._greyhawk:1126](../scripts/game/vehicles/vm_plane.gd#L1126)
- canards, the wing with flaps and ailerons — [VmPlane._greyhawk:1131](../scripts/game/vehicles/vm_plane.gd#L1131)
- the Y tail: ruddervators up, the ventral fin down — [VmPlane._greyhawk:1136](../scripts/game/vehicles/vm_plane.gd#L1136)
- the turboprop: dorsal NACA inlet, ventral scoop, exhaust stubs; the prop — [VmPlane._greyhawk:1139](../scripts/game/vehicles/vm_plane.gd#L1139)
- antennas: the satcom blades, the belly whips — [VmPlane._greyhawk:1147](../scripts/game/vehicles/vm_plane.gd#L1147)
- two pylons, a Paveway on each — [VmPlane._greyhawk:1151](../scripts/game/vehicles/vm_plane.gd#L1151)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.prop`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gryphon

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._gryphon:585](../scripts/game/vehicles/vm_plane.gd#L585)
- D-shaped intakes on splitter plates, the canards on their shoulders — [VmPlane._gryphon:612](../scripts/game/vehicles/vm_plane.gd#L612)
- the cranked delta, elevons along its trailing edge — [VmPlane._gryphon:622](../scripts/game/vehicles/vm_plane.gd#L622)
- the dogtooth: a small step in the leading edge — [VmPlane._gryphon:625](../scripts/game/vehicles/vm_plane.gd#L625)
- tip rails with Sidewinders, navigation lights — [VmPlane._gryphon:628](../scripts/game/vehicles/vm_plane.gd#L628)
- the fin with its rudder, a fairing at the tip — [VmPlane._gryphon:633](../scripts/game/vehicles/vm_plane.gd#L633)
- the afterburner nozzle, airbrakes on the tail cone — [VmPlane._gryphon:636](../scripts/game/vehicles/vm_plane.gd#L636)
- probes and antennas, the gun port low on the left — [VmPlane._gryphon:641](../scripts/game/vehicles/vm_plane.gd#L641)
- stores: a centreline tank, Paveways inboard, Mavericks outboard — [VmPlane._gryphon:648](../scripts/game/vehicles/vm_plane.gd#L648)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### gun_trawler

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmShips._gun_trawler:915](../scripts/game/vehicles/vm_ships.gd#L915)
- the transom's bulwark across the stern — [VmShips._gun_trawler:926](../scripts/game/vehicles/vm_ships.gd#L926)
- the keel bar and the stem bar running up the bow — [VmShips._gun_trawler:930](../scripts/game/vehicles/vm_ships.gd#L930)
- the skeg under the run, the propeller in its aperture, the rudder — [VmShips._gun_trawler:951](../scripts/game/vehicles/vm_ships.gd#L951)
- rubbing bands, bilge keels, the bulwark capping — [VmShips._gun_trawler:959](../scripts/game/vehicles/vm_ships.gd#L959)
- freeing ports in the bulwarks with rust running from them, rust and primer patches, a replaced plate, the registration on the bows — [VmShips._gun_trawler:976](../scripts/game/vehicles/vm_ships.gd#L976)
- the hawse pipe with the anchor in it and rust bleeding down — [VmShips._gun_trawler:996](../scripts/game/vehicles/vm_ships.gd#L996)
- tyres hung over the side as fenders — [VmShips._gun_trawler:1005](../scripts/game/vehicles/vm_ships.gd#L1005)
- --- the deckhouse, white and streaked, and the wheelhouse on it — [VmShips._gun_trawler:1012](../scripts/game/vehicles/vm_ships.gd#L1012)
- the deckhouse: a door and portholes each side, rust under them, a ladder up the back to the boat deck, handrails round the roof — [VmShips._gun_trawler:1041](../scripts/game/vehicles/vm_ships.gd#L1041)
- sidelights in their screens on the wheelhouse's shoulders — [VmShips._gun_trawler:1054](../scripts/game/vehicles/vm_ships.gd#L1054)
- the funnel (black-topped, sooty), a liferaft canister, a boat-deck locker — [VmShips._gun_trawler:1069](../scripts/game/vehicles/vm_ships.gd#L1069)
- --- the wheelhouse roof: the DShK, radar mast with its scanner, a searchlight, horn, whips, a loudhailer — [VmShips._gun_trawler:1076](../scripts/game/vehicles/vm_ships.gd#L1076)
- --- the mast and its derrick, the trawl winch, the fish hold hatch — [VmShips._gun_trawler:1089](../scripts/game/vehicles/vm_ships.gd#L1089)
- shrouds down to the bulwark — [VmShips._gun_trawler:1096](../scripts/game/vehicles/vm_ships.gd#L1096)
- --- the foredeck: the ZU-23-2 on a welded plinth (the turret), ammo crates, sandbags along the bulwark, the windlass and the bow fairlead — [VmShips._gun_trawler:1124](../scripts/game/vehicles/vm_ships.gd#L1124)
- --- the after deck: the net drum, the gantry with its blocks, the trawl doors hung outboard, nets piled with floats, fish boxes, a dan buoy — [VmShips._gun_trawler:1154](../scripts/game/vehicles/vm_ships.gd#L1154)
- a block hanging from the beam, the warp to it, the trawl door on its chains — [VmShips._gun_trawler:1174](../scripts/game/vehicles/vm_ships.gd#L1174)
- nets heaped on the deck beside the drum, floats through them — [VmShips._gun_trawler:1192](../scripts/game/vehicles/vm_ships.gd#L1192)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._dshk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._surf`, `VmShips._sweep`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._whip`, `VmShips._zu23`.

### gunship

**Shared:** `VehicleAircraft.rocket_pod`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._apache:1483](../scripts/game/vehicles/vm_core.gd#L1483)
- the stepped canopy: the gunner's low in front, the pilot's high behind, the blast shield between them; the fairing over the gearbox behind — [VmCore._apache:1501](../scripts/game/vehicles/vm_core.gd#L1501)
- the avionics bays along the lower flanks, their access panel seams — [VmCore._apache:1506](../scripts/game/vehicles/vm_core.gd#L1506)
- the radar warning receivers and a pitot on the nose — [VmCore._apache:1512](../scripts/game/vehicles/vm_core.gd#L1512)
- --- the nose: the TADS drum with its two sensor heads, the PNVS above — [VmCore._apache:1514](../scripts/game/vehicles/vm_core.gd#L1514)
- wire cutters over the canopy and under the chin — [VmCore._apache:1526](../scripts/game/vehicles/vm_core.gd#L1526)
- --- the engines either side of the gearbox fairing: the nacelles on their pylons, the dark intakes, the exhaust suppressors turned out — [VmCore._apache:1529](../scripts/game/vehicles/vm_core.gd#L1529)
- --- stub wings: Hellfires outboard, rocket pods inboard, rails at the tips — [VmCore._apache:1539](../scripts/game/vehicles/vm_core.gd#L1539)
- --- the tail: the swept fin, the tail rotor on its left, the stabilator low at the back, the tailwheel under the fin — [VmCore._apache:1550](../scripts/game/vehicles/vm_core.gd#L1550)
- --- main gear: trailing arms off the bays, the shock struts — [VmCore._apache:1560](../scripts/game/vehicles/vm_core.gd#L1560)
- --- the M230 chain gun in its turret under the chin — [VmCore._apache:1565](../scripts/game/vehicles/vm_core.gd#L1565)
- --- the mast, the rotor and the Longbow radar dome over it — [VmCore._apache:1575](../scripts/game/vehicles/vm_core.gd#L1575)
- antennas along the boom — [VmCore._apache:1582](../scripts/game/vehicles/vm_core.gd#L1582)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmHeli._canopy`, `VmHeli._hellfires`, `VmHeli._hull`, `VmHeli._missile`, `VmHeli._mx`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hatchback, hatchback_sport

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._hatch:1060](../scripts/game/vehicles/vm_civ.gd#L1060)
- glasshouse — [VmCiv._hatch:1083](../scripts/game/vehicles/vm_civ.gd#L1083)
- the concept's panoramic glass roof — [VmCiv._hatch:1091](../scripts/game/vehicles/vm_civ.gd#L1091)
- door shut lines: front door, rear door — [VmCiv._hatch:1106](../scripts/game/vehicles/vm_civ.gd#L1106)
- the face: swept lamps, a slim upper grille, the wide lower intake — [VmCiv._hatch:1112](../scripts/game/vehicles/vm_civ.gd#L1112)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._glasshouse`, `VmCiv._hatch_sport`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._xbody`.

### heli

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._blackhawk:1604](../scripts/game/vehicles/vm_core.gd#L1604)
- glazing: the two-pane windscreen, the eyebrow windows over it, the cockpit doors' windows, the gunners' windows, the cabin doors' windows — [VmCore._blackhawk:1622](../scripts/game/vehicles/vm_core.gd#L1622)
- the frame between the windscreen panes, the door seams and the cabin door's rail, the steps — [VmCore._blackhawk:1631](../scripts/game/vehicles/vm_core.gd#L1631)
- the nose: the radome's seam, pitots on the roof, the wire cutters — [VmCore._blackhawk:1638](../scripts/game/vehicles/vm_core.gd#L1638)
- --- the roof: the gearbox fairing, the engines either side with their dark intakes and the exhaust suppressors turned out, the IR jammer — [VmCore._blackhawk:1646](../scripts/game/vehicles/vm_core.gd#L1646)
- --- the mast and the rotor: swept tips, the bifilar absorber on the hub — [VmCore._blackhawk:1659](../scripts/game/vehicles/vm_core.gd#L1659)
- --- the stores wings over the cabin's rear, braced to the floor, a fuel tank on each — [VmCore._blackhawk:1669](../scripts/game/vehicles/vm_core.gd#L1669)
- --- the tail: the swept pylon, the canted tail rotor on its right, the stabilator, the antenna along the boom, the tailwheel — [VmCore._blackhawk:1676](../scripts/game/vehicles/vm_core.gd#L1676)
- --- main gear: the drag beam and the shock strut to each wheel — [VmCore._blackhawk:1695](../scripts/game/vehicles/vm_core.gd#L1695)

**Local helper construction:** `VmCore._airframe`, `VmCore._bx`, `VmCore._fuel_tank`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hellcat

**Shared:** `VehicleAircraft.rocket_pod`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._hellcat:933](../scripts/game/vehicles/vm_heli.gd#L933)
- glazing: windscreen, chin windows, cockpit doors; the sliding doors — [VmHeli._hellcat:952](../scripts/game/vehicles/vm_heli.gd#L952)
- the roof fairing, engines with side exhausts, mast — [VmHeli._hellcat:961](../scripts/game/vehicles/vm_heli.gd#L961)
- the sensor turret on the nose, pitots, wire cutters — [VmHeli._hellcat:970](../scripts/game/vehicles/vm_heli.gd#L970)
- the tail: pylon, tail rotor on its left, tailplane on its right — [VmHeli._hellcat:976](../scripts/game/vehicles/vm_heli.gd#L976)
- skids — [VmHeli._hellcat:984](../scripts/game/vehicles/vm_heli.gd#L984)
- weapon pylons: a minigun inboard, a rocket pod out — [VmHeli._hellcat:990](../scripts/game/vehicles/vm_heli.gd#L990)
- the rotor: four BERP blades on the compact hub — [VmHeli._hellcat:1002](../scripts/game/vehicles/vm_heli.gd#L1002)

**Local helper construction:** `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### hemtt, hemtt_ammo, hemtt_cargo, hemtt_fuel, hemtt_medical, hemtt_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._hemtt:1451](../scripts/game/vehicles/vm_nato.gd#L1451)
- drop sides and the headboard — [VmNato._hemtt:1461](../scripts/game/vehicles/vm_nato.gd#L1461)
- the canvas tilt over its bows, the back rolled up over the benches — [VmNato._hemtt:1470](../scripts/game/vehicles/vm_nato.gd#L1470)
- palletised crates and boxes lashed down, a tarp over one load — [VmNato._hemtt:1484](../scripts/game/vehicles/vm_nato.gd#L1484)
- ammunition: pallets of boxes, then the knuckle-boom crane at the back, folded forward over the load — [VmNato._hemtt:1495](../scripts/game/vehicles/vm_nato.gd#L1495)
- the shelter: a tall box body with a ribbed roof edge — [VmNato._hemtt:1519](../scripts/game/vehicles/vm_nato.gd#L1519)
- roll-up shutters with their slats, tool lockers below — [VmNato._hemtt:1526](../scripts/game/vehicles/vm_nato.gd#L1526)
- the light mast, AC unit, the rear door and ladder, a vice bench — [VmNato._hemtt:1533](../scripts/game/vehicles/vm_nato.gd#L1533)
- windows, the rear doors with a step, roof vents, red crosses — [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- the tank: an oval barrel on cradles, its end caps, the walkway on top with its rail, manholes, the pump cabinet and hose reels at the back — [VmNato._hemtt:1559](../scripts/game/vehicles/vm_nato.gd#L1559)
- the hazard placard — [VmNato._hemtt:1575](../scripts/game/vehicles/vm_nato.gd#L1575)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_cargo_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_load_detail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### hummingbird, m900, pawnee

**Shared:** `VehicleAircraft.rocket_pod`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._little_bird:403](../scripts/game/vehicles/vm_heli.gd#L403)
- the bubble: windscreen and chin windows, one framed sheet — [VmHeli._little_bird:424](../scripts/game/vehicles/vm_heli.gd#L424)
- doors: the pilots' (off on the military birds), the cabin's behind — [VmHeli._little_bird:430](../scripts/game/vehicles/vm_heli.gd#L430)
- a cheat line down the flank — [VmHeli._little_bird:436](../scripts/game/vehicles/vm_heli.gd#L436)
- seat backs, seen through the openings — [VmHeli._little_bird:446](../scripts/game/vehicles/vm_heli.gd#L446)
- roof fairing over the mast and the engine intake behind it — [VmHeli._little_bird:449](../scripts/game/vehicles/vm_heli.gd#L449)
- exhaust under the boom root, the boom, the tail — [VmHeli._little_bird:456](../scripts/game/vehicles/vm_heli.gd#L456)
- beacon, antennas, pitot, the landing light — [VmHeli._little_bird:469](../scripts/game/vehicles/vm_heli.gd#L469)
- the external personnel benches, two a side — [VmHeli._little_bird:480](../scripts/game/vehicles/vm_heli.gd#L480)
- a grab rail over the doorway — [VmHeli._little_bird:488](../scripts/game/vehicles/vm_heli.gd#L488)
- the weapons cross-bar under the cabin floor: minigun inboard, pod out — [VmHeli._little_bird:491](../scripts/game/vehicles/vm_heli.gd#L491)
- the ammunition chute from the box in the cabin — [VmHeli._little_bird:498](../scripts/game/vehicles/vm_heli.gd#L498)
- the FLIR ball under the nose — [VmHeli._little_bird:506](../scripts/game/vehicles/vm_heli.gd#L506)

**Local helper construction:** `VmHeli._air`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._patch`, `VmHeli._path`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._skids`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### humvee

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._humvee:1033](../scripts/game/vehicles/vm_core.gd#L1033)
- the chassis under the body: frame, the portal hub housings and the A-arms out to each wheel, the drivetrain block — [VmCore._humvee:1040](../scripts/game/vehicles/vm_core.gd#L1040)
- the body: bonnet over the wings, the cab's lower half and the rear deck in one panel, the arches cut round the wheels — [VmCore._humvee:1049](../scripts/game/vehicles/vm_core.gd#L1049)
- the wheels, their mud flaps — [VmCore._humvee:1054](../scripts/game/vehicles/vm_core.gd#L1054)
- the bonnet: its seam and the raised middle, the rubber T-latches either side, the intake grille on the right — [VmCore._humvee:1060](../scripts/game/vehicles/vm_core.gd#L1060)
- the face: the slotted grille, headlights in the wing corners, the indicators, the bumper with its winch and lifting shackles — [VmCore._humvee:1068](../scripts/game/vehicles/vm_core.gd#L1068)
- the cab: armoured walls lofted from the belt to the roof — [VmCore._humvee:1083](../scripts/game/vehicles/vm_core.gd#L1083)
- the split windscreen, thick armoured glass in heavy frames — [VmCore._humvee:1092](../scripts/game/vehicles/vm_core.gd#L1092)
- the door windows, small and square; the cab's back window — [VmCore._humvee:1095](../scripts/game/vehicles/vm_core.gd#L1095)
- the doors: heavy armoured slabs proud of the body, their seams, hinges and the big latch handles — [VmCore._humvee:1101](../scripts/game/vehicles/vm_core.gd#L1101)
- the wing mirrors on their arms — [VmCore._humvee:1109](../scripts/game/vehicles/vm_core.gd#L1109)
- armour over the rear deck's sides — [VmCore._humvee:1111](../scripts/game/vehicles/vm_core.gd#L1111)
- the rear: the deck lid, tail lights in the corners, the pintle, jerrycans — [VmCore._humvee:1114](../scripts/game/vehicles/vm_core.gd#L1114)
- --- the O-GPK turret on the roof ring — [VmCore._humvee:1125](../scripts/game/vehicles/vm_core.gd#L1125)
- the faceted shields: three across the front, angled wings, side panels, each with its ballistic window; the back left open for the gunner — [VmCore._humvee:1130](../scripts/game/vehicles/vm_core.gd#L1130)
- the gun slot in the front shield and the M2 through it — [VmCore._humvee:1147](../scripts/game/vehicles/vm_core.gd#L1147)
- the ballistic glass ring over the shields on the front — [VmCore._humvee:1151](../scripts/game/vehicles/vm_core.gd#L1151)

**Local helper construction:** `VmCiv._face`, `VmCiv._inset`, `VmCiv._pane`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCore._ammo_can`, `VmCore._antenna`, `VmCore._bar`, `VmCore._bx`, `VmCore._cam`, `VmCore._jerry`, `VmCore._m2`, `VmCore._shackle`, `VmCore._taillight`.

### hunter, hunter_gmg, hunter_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.storage`, `VehicleEquipment.winch`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._hunter:294](../scripts/game/vehicles/vm_nato.gd#L294)
- --- V-hull, engine block, suspension and the wheels — [VmNato._hunter:300](../scripts/game/vehicles/vm_nato.gd#L300)
- --- bonnet over the engine, fenders over the front wheels, the grille — [VmNato._hunter:310](../scripts/game/vehicles/vm_nato.gd#L310)
- the wheel arch lip and mud flap behind the front wheel — [VmNato._hunter:316](../scripts/game/vehicles/vm_nato.gd#L316)
- the hood's centre bulge and its latches — [VmNato._hunter:323](../scripts/game/vehicles/vm_nato.gd#L323)
- bumper with tow shackles and a recovery winch — [VmNato._hunter:327](../scripts/game/vehicles/vm_nato.gd#L327)
- --- the crew capsule: vertical lower sides, the upper sides leaning in, a lightly raked windscreen — [VmNato._hunter:332](../scripts/game/vehicles/vm_nato.gd#L332)
- windscreen: two small thick panes in a heavy frame — [VmNato._hunter:338](../scripts/game/vehicles/vm_nato.gd#L338)
- doors: seams, small thick windows on the upper sides, handles, hinges — [VmNato._hunter:342](../scripts/game/vehicles/vm_nato.gd#L342)
- the steps under the doors, the mirror on its arm — [VmNato._hunter:354](../scripts/game/vehicles/vm_nato.gd#L354)
- stowage box low on the capsule side by the rear door — [VmNato._hunter:358](../scripts/game/vehicles/vm_nato.gd#L358)
- the engine air intake up the right A-pillar — [VmNato._hunter:360](../scripts/game/vehicles/vm_nato.gd#L360)
- roof: rails, antennas, the lights over the windscreen — [VmNato._hunter:363](../scripts/game/vehicles/vm_nato.gd#L363)
- --- the cargo bed behind the capsule, fenders over the rear wheels — [VmNato._hunter:368](../scripts/game/vehicles/vm_nato.gd#L368)
- the spare wheel on its swing-out carrier — [VmNato._hunter:382](../scripts/game/vehicles/vm_nato.gd#L382)
- --- the roof: a remote weapon station, or the gunner's hatch closed — [VmNato._hunter:388](../scripts/game/vehicles/vm_nato.gd#L388)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._zy`.

### huron

**Shared:** `VehicleAircraft.gear_leg`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._huron:636](../scripts/game/vehicles/vm_heli.gd#L636)
- cockpit glazing: windscreen, chin windows, side windows; the crew door — [VmHeli._huron:651](../scripts/game/vehicles/vm_heli.gd#L651)
- the row of small cabin windows — [VmHeli._huron:662](../scripts/game/vehicles/vm_heli.gd#L662)
- the ramp: hinge line, its edges under the tail, the door in the back — [VmHeli._huron:666](../scripts/game/vehicles/vm_heli.gd#L666)
- fuel sponsons down the flanks — [VmHeli._huron:673](../scripts/game/vehicles/vm_heli.gd#L673)
- the gear: two wheels forward of the sponsons, two under their tails — [VmHeli._huron:687](../scripts/game/vehicles/vm_heli.gd#L687)
- steps, lights, the rescue hoist over the door — [VmHeli._huron:691](../scripts/game/vehicles/vm_heli.gd#L691)
- cargo hooks, the FLIR ball, pitots — [VmHeli._huron:696](../scripts/game/vehicles/vm_heli.gd#L696)
- forward pylon, the shaft tunnel, the tall aft pylon with its engines — [VmHeli._huron:703](../scripts/game/vehicles/vm_heli.gd#L703)
- masts, antennas, beacons — [VmHeli._huron:717](../scripts/game/vehicles/vm_heli.gd#L717)
- the rotors: three-blade, contra-rotating, the aft one higher — [VmHeli._huron:724](../scripts/game/vehicles/vm_heli.gd#L724)

**Local helper construction:** `VmHeli._air`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._tube`.

### ifrit, ifrit_gmg, ifrit_hmg

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._ifrit:249](../scripts/game/vehicles/vm_csat.gd#L249)
- the V-shaped belly between the wheels — [VmCsat._ifrit:251](../scripts/game/vehicles/vm_csat.gd#L251)
- the faceted body: nose, bonnet, windscreen, cabin, rear face — [VmCsat._ifrit:253](../scripts/game/vehicles/vm_csat.gd#L253)
- the lower nose (grille and bumper) and the tail below the rear door — [VmCsat._ifrit:262](../scripts/game/vehicles/vm_csat.gd#L262)
- the door sills between the wheels, their ends cut to the arches — [VmCsat._ifrit:265](../scripts/game/vehicles/vm_csat.gd#L265)
- a raised panel down the bonnet and the air intake grille before the screen — [VmCsat._ifrit:270](../scripts/game/vehicles/vm_csat.gd#L270)
- the windscreen: two small panes in the raked front of the cabin — [VmCsat._ifrit:275](../scripts/game/vehicles/vm_csat.gd#L275)
- A-pillar cover strips on the screen's facets — [VmCsat._ifrit:280](../scripts/game/vehicles/vm_csat.gd#L280)
- side windows, door seams and handles, the doors' steps — [VmCsat._ifrit:283](../scripts/game/vehicles/vm_csat.gd#L283)
- mirrors on stalks at the screen's base — [VmCsat._ifrit:296](../scripts/game/vehicles/vm_csat.gd#L296)
- angular arches over the wheels and mud flaps behind them — [VmCsat._ifrit:298](../scripts/game/vehicles/vm_csat.gd#L298)
- headlight clusters in the wings, rear lights, tow hooks — [VmCsat._ifrit:303](../scripts/game/vehicles/vm_csat.gd#L303)
- whip antennas at the rear roof corners — [VmCsat._ifrit:307](../scripts/game/vehicles/vm_csat.gd#L307)
- the grille, the bumper — [VmCsat._ifrit:309](../scripts/game/vehicles/vm_csat.gd#L309)
- the rear: the door with its window and hinges, the spare wheel, the step — [VmCsat._ifrit:314](../scripts/game/vehicles/vm_csat.gd#L314)
- roof: rails, the hatch or the weapon station — [VmCsat._ifrit:325](../scripts/game/vehicles/vm_csat.gd#L325)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._mx`, `VmCsat._pane`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`.

### ifv

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lifting_eye`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._bradley:1306](../scripts/game/vehicles/vm_core.gd#L1306)
- running gear: front sprocket, six road wheels, rear idler — [VmCore._bradley:1309](../scripts/game/vehicles/vm_core.gd#L1309)
- the hull: the belly with the steep lower nose, the upper hull out over the tracks with the long upper glacis — [VmCore._bradley:1328](../scripts/game/vehicles/vm_core.gd#L1328)
- the glacis: its armour plate with the bolt rows, the driver's hatch and periscopes front left, the engine access and grilles front right — [VmCore._bradley:1339](../scripts/game/vehicles/vm_core.gd#L1339)
- the exhaust on the right of the nose, lights in guards, tow hooks — [VmCore._bradley:1353](../scripts/game/vehicles/vm_core.gd#L1353)
- the sides: the appliqué armour tiles with their bolts, the skirts under them, the grab rail — [VmCore._bradley:1359](../scripts/game/vehicles/vm_core.gd#L1359)
- the roof: the troop compartment's long cargo hatch, vision blocks — [VmCore._bradley:1375](../scripts/game/vehicles/vm_core.gd#L1375)
- the rear: the big ramp with its door, hinges, stowage boxes either side, tail lights, a water can and kit — [VmCore._bradley:1381](../scripts/game/vehicles/vm_core.gd#L1381)
- --- the turret — [VmCore._bradley:1397](../scripts/game/vehicles/vm_core.gd#L1397)
- the spaced armour on the turret's front faces — [VmCore._bradley:1405](../scripts/game/vehicles/vm_core.gd#L1405)
- the 25 mm in its mantlet, the coax to its right — [VmCore._bradley:1412](../scripts/game/vehicles/vm_core.gd#L1412)
- the TOW launcher box on its arm on the left — [VmCore._bradley:1422](../scripts/game/vehicles/vm_core.gd#L1422)
- the IBAS sight head front left, the CIV on the right, the hatches — [VmCore._bradley:1428](../scripts/game/vehicles/vm_core.gd#L1428)
- the stowage basket round the back, bags and a bedroll in it — [VmCore._bradley:1442](../scripts/game/vehicles/vm_core.gd#L1442)

**Local helper construction:** `VmCore._antenna`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._oct`, `VmCore._on_face`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._tooth`, `VmCore._zy`.

### jet

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.gear_leg`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup — [VmFighter._f16:694](../scripts/game/vehicles/vm_fighter.gd#L694)
- --- fuselage: radome, the round body, strakes flaring into the wing root [s, crown, keel, half-width, strake edge's half-span, its height] — [VmFighter._f16:705](../scripts/game/vehicles/vm_fighter.gd#L705)
- the cockpit sill the canopy sits on, the dorsal spine behind it — [VmFighter._f16:724](../scripts/game/vehicles/vm_fighter.gd#L724)
- the frameless bubble canopy (its bow behind the seat), the sill rails — [VmFighter._f16:730](../scripts/game/vehicles/vm_fighter.gd#L730)
- --- the ventral intake: a hollow raked mouth, the splitter above it, the duct fairing running back under the fuselage — [VmFighter._f16:739](../scripts/game/vehicles/vm_fighter.gd#L739)
- --- wing: leading-edge flaps the full span, flaperons inboard — [VmFighter._f16:749](../scripts/game/vehicles/vm_fighter.gd#L749)
- all-moving tailerons, 10 degrees down — [VmFighter._f16:755](../scripts/game/vehicles/vm_fighter.gd#L755)
- the fin with its rudder, the squadron band round its tip, the base housing behind it, the antenna cap — [VmFighter._f16:758](../scripts/game/vehicles/vm_fighter.gd#L758)
- ventral fins, canted out under the strake shelves — [VmFighter._f16:767](../scripts/game/vehicles/vm_fighter.gd#L767)
- split speedbrakes at the ends of the strake shelves — [VmFighter._f16:772](../scripts/game/vehicles/vm_fighter.gd#L772)
- --- the F110's nozzle: actuator ring, petals, the pipe inside — [VmFighter._f16:777](../scripts/game/vehicles/vm_fighter.gd#L777)
- --- details: pitot, AOA probes, IFF "bird slicers", the gun, refuelling receptacle, antennas, lights — [VmFighter._f16:784](../scripts/game/vehicles/vm_fighter.gd#L784)
- formation strip lights: nose sides, fin — [VmFighter._f16:803](../scripts/game/vehicles/vm_fighter.gd#L803)
- --- panel lines: control-surface hinge lines are gaps; these are the access panels and the gear doors (closed flush) — [VmFighter._f16:812](../scripts/game/vehicles/vm_fighter.gd#L812)
- --- stores — [VmFighter._f16:826](../scripts/game/vehicles/vm_fighter.gd#L826)
- the tip launcher and its AMRAAM — [VmFighter._f16:842](../scripts/game/vehicles/vm_fighter.gd#L842)
- Sniper pod on the right intake station, the ALQ-184 on the centreline — [VmFighter._f16:847](../scripts/game/vehicles/vm_fighter.gd#L847)
- --- markings: low-vis star-and-bar on the intake and the wings, the wing's tail code and serial on the fin — [VmFighter._f16:852](../scripts/game/vehicles/vm_fighter.gd#L852)
- --- landing gear (shown on the ground): the short nose leg behind the intake, the main legs splayed out from under the strakes, open doors — [VmFighter._f16:866](../scripts/game/vehicles/vm_fighter.gd#L866)
- the main door hangs from the strake outboard of the well — [VmFighter._f16:885](../scripts/game/vehicles/vm_fighter.gd#L885)

**Local helper construction:** `VmFighter._aim120`, `VmFighter._aim9x`, `VmFighter._alq184`, `VmFighter._awheel`, `VmFighter._burner`, `VmFighter._ccr`, `VmFighter._circle2`, `VmFighter._decal`, `VmFighter._dense`, `VmFighter._duct`, `VmFighter._f16_half`, `VmFighter._ft`, `VmFighter._gbu31`, `VmFighter._gear_node`, `VmFighter._glaze`, `VmFighter._hband`, `VmFighter._hull`, `VmFighter._hwrap`, `VmFighter._insignia`, `VmFighter._leg`, `VmFighter._lines`, `VmFighter._mesh`, `VmFighter._msecs`, `VmFighter._outline`, `VmFighter._petals`, `VmFighter._pipe`, `VmFighter._poly_mesh`, `VmFighter._project`, `VmFighter._put`, `VmFighter._rect2`, `VmFighter._ring`, `VmFighter._rows`, `VmFighter._skin`, `VmFighter._slab`, `VmFighter._sniper`, `VmFighter._star2`, `VmFighter._surf`, `VmFighter._tan`, `VmFighter._text`, `VmFighter._tri`, `VmFighter._vn`, `VmFighter._wrap`, `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.drop_tank`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### kajman

**Shared:** `VehicleAircraft.rocket_pod`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleEquipment.sensor`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._kajman:1052](../scripts/game/vehicles/vm_heli.gd#L1052)
- the stepped cockpits: the gunner low in front, the pilot high behind — [VmHeli._kajman:1074](../scripts/game/vehicles/vm_heli.gd#L1074)
- the cabin: split doors with a window in the upper half, side windows — [VmHeli._kajman:1078](../scripts/game/vehicles/vm_heli.gd#L1078)
- the nose sensors — [VmHeli._kajman:1086](../scripts/game/vehicles/vm_heli.gd#L1086)
- top fairing, the engines with their dust filters and exhaust deflectors — [VmHeli._kajman:1091](../scripts/game/vehicles/vm_heli.gd#L1091)
- the dust protector: a cone ahead of a dark annular intake — [VmHeli._kajman:1097](../scripts/game/vehicles/vm_heli.gd#L1097)
- the coaxial mast — [VmHeli._kajman:1103](../scripts/game/vehicles/vm_heli.gd#L1103)
- stub wings: anhedral, three pylons a side, flare pods at the tips — [VmHeli._kajman:1107](../scripts/game/vehicles/vm_heli.gd#L1107)
- main gear on trailing legs — [VmHeli._kajman:1121](../scripts/game/vehicles/vm_heli.gd#L1121)
- the tail: a swept fin, the stabiliser with endplate fins, the tailwheel — [VmHeli._kajman:1127](../scripts/game/vehicles/vm_heli.gd#L1127)
- the chin turret: 2A42 30 mm with its ammunition boxes either side — [VmHeli._kajman:1137](../scripts/game/vehicles/vm_heli.gd#L1137)
- the coaxial rotors: three blades each, the upper one turning the other way — [VmHeli._kajman:1148](../scripts/game/vehicles/vm_heli.gd#L1148)

**Local helper construction:** `VmHeli._atgm_tubes`, `VmHeli._canopy`, `VmHeli._hull`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tube`.

### kamysh

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._kamysh:739](../scripts/game/vehicles/vm_csat.gd#L739)
- the bustle box at the back — [VmCsat._kamysh:745](../scripts/game/vehicles/vm_csat.gd#L745)
- mantlet, the 30 mm with its barrel jacket and muzzle brake, the coax — [VmCsat._kamysh:747](../scripts/game/vehicles/vm_csat.gd#L747)
- the gunner's sight head (front left) and the commander's panoramic sight — [VmCsat._kamysh:754](../scripts/game/vehicles/vm_csat.gd#L754)
- the twin Titan launchers on arms either side, smoke dischargers behind — [VmCsat._kamysh:763](../scripts/game/vehicles/vm_csat.gd#L763)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### kart

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._kart:1286](../scripts/game/vehicles/vm_civ.gd#L1286)
- the frame: two main rails, cross members, the front stubs — [VmCiv._kart:1296](../scripts/game/vehicles/vm_civ.gd#L1296)
- nose fairing, front panel, pods in the livery — [VmCiv._kart:1310](../scripts/game/vehicles/vm_civ.gd#L1310)
- seat, steering wheel and column, pedals — [VmCiv._kart:1328](../scripts/game/vehicles/vm_civ.gd#L1328)
- the two-stroke to the right of the seat, its airbox and silencer — [VmCiv._kart:1337](../scripts/game/vehicles/vm_civ.gd#L1337)
- rear bumper and its plate — [VmCiv._kart:1345](../scripts/game/vehicles/vm_civ.gd#L1345)

**Local helper construction:** `VmCiv._bent`, `VmCiv._rod`.

### kuma

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._kuma:475](../scripts/game/vehicles/vm_indep.gd#L475)
- running gear: front idler, seven road wheels, rear sprocket, four rollers — [VmIndep._kuma:479](../scripts/game/vehicles/vm_indep.gd#L479)
- hull: the belly between the tracks (the lower glacis its front), the upper hull out over the tracks with the long shallow upper glacis — [VmIndep._kuma:485](../scripts/game/vehicles/vm_indep.gd#L485)
- a bolted add-on plate over the glacis, the driver's hatch front-right — [VmIndep._kuma:491](../scripts/game/vehicles/vm_indep.gd#L491)
- headlight clusters with guards on the front corners, tow eyes — [VmIndep._kuma:497](../scripts/game/vehicles/vm_indep.gd#L497)
- skirts: three heavy armour modules forward, three light panels aft, the bow panel raked — [VmIndep._kuma:500](../scripts/game/vehicles/vm_indep.gd#L500)
- the hull's sides: a stowage box and the tool rack above the skirts — [VmIndep._kuma:509](../scripts/game/vehicles/vm_indep.gd#L509)
- engine deck grilles either side of the centre access panel — [VmIndep._kuma:512](../scripts/game/vehicles/vm_indep.gd#L512)
- rear: tail lights, tow eyes — [VmIndep._kuma:516](../scripts/game/vehicles/vm_indep.gd#L516)
- the exhaust louvres across the top of the rear plate, the slat cage standing off the back on its struts — [VmIndep._kuma:520](../scripts/game/vehicles/vm_indep.gd#L520)
- the turret, its front cheeks just behind the glacis — [VmIndep._kuma:530](../scripts/game/vehicles/vm_indep.gd#L530)
- bolt-on armour: flat slabs on the cheeks either side of the mantlet and along the sides — [VmIndep._kuma:537](../scripts/game/vehicles/vm_indep.gd#L537)
- smoke dischargers: a group of four on each side, aft — [VmIndep._kuma:550](../scripts/game/vehicles/vm_indep.gd#L550)
- the gun: mantlet, thermal sleeve, fume extractor, muzzle reference sensor — [VmIndep._kuma:553](../scripts/game/vehicles/vm_indep.gd#L553)
- the coaxial MG left of the gun — [VmIndep._kuma:561](../scripts/game/vehicles/vm_indep.gd#L561)
- roof: the EMES gunner's sight doghouse front-right, the PERI periscope behind it, the commander's and loader's hatches, the wind sensor — [VmIndep._kuma:564](../scripts/game/vehicles/vm_indep.gd#L564)
- the bustle's stowage basket, the slat cage round it on its struts — [VmIndep._kuma:580](../scripts/game/vehicles/vm_indep.gd#L580)
- a remote .50 over the loader's hatch — [VmIndep._kuma:590](../scripts/game/vehicles/vm_indep.gd#L590)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._slats`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### m35

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._truck:1712](../scripts/game/vehicles/vm_core.gd#L1712)
- the chassis: frame rails, the axles and their diffs, the wheels — [VmCore._truck:1716](../scripts/game/vehicles/vm_core.gd#L1716)
- the bonnet, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks — [VmCore._truck:1723](../scripts/game/vehicles/vm_core.gd#L1723)
- the louvres down the bonnet's sides — [VmCore._truck:1734](../scripts/game/vehicles/vm_core.gd#L1734)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms — [VmCore._truck:1741](../scripts/game/vehicles/vm_core.gd#L1741)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box — [VmCore._truck:1756](../scripts/game/vehicles/vm_core.gd#L1756)
- the cargo bed: floor, sides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle — [VmCore._truck:1760](../scripts/game/vehicles/vm_core.gd#L1760)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._path`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmNato._spare`.

### marid

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._marid:570](../scripts/game/vehicles/vm_csat.gd#L570)
- the glacis plane (for things mounted on it) — [VmCsat._marid:579](../scripts/game/vehicles/vm_csat.gd#L579)
- the driver's windows at the top of the glacis, front left, and his hatch — [VmCsat._marid:582](../scripts/game/vehicles/vm_csat.gd#L582)
- the engine's louvres on the right of the glacis, exhaust on the right side — [VmCsat._marid:589](../scripts/game/vehicles/vm_csat.gd#L589)
- headlight clusters and tow hooks on the nose, smoke dischargers — [VmCsat._marid:593](../scripts/game/vehicles/vm_csat.gd#L593)
- the wheels on three evenly spaced axles, mud flaps — [VmCsat._marid:598](../scripts/game/vehicles/vm_csat.gd#L598)
- the crease's side: vision blocks and firing ports along the troop compartment, stowage boxes, the exhaust — [VmCsat._marid:603](../scripts/game/vehicles/vm_csat.gd#L603)
- grab rails along the roof edge — [VmCsat._marid:614](../scripts/game/vehicles/vm_csat.gd#L614)
- rear: the ramp with its door, hinges, water jets, lights, stowage — [VmCsat._marid:617](../scripts/game/vehicles/vm_csat.gd#L617)
- roof: the troop compartment's hatches, a stowage basket — [VmCsat._marid:632](../scripts/game/vehicles/vm_csat.gd#L632)
- twin remote weapon stations on one ring: the 12.7 mm on the left, the 40 mm on the right, the sight head between them — [VmCsat._marid:640](../scripts/game/vehicles/vm_csat.gd#L640)
- 12.7 mm, left — [VmCsat._marid:653](../scripts/game/vehicles/vm_csat.gd#L653)
- 40 mm, right — [VmCsat._marid:659](../scripts/game/vehicles/vm_csat.gd#L659)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._jerrycan`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._taillight`, `VmCsat._tow`.

### marshall

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._marshall:544](../scripts/game/vehicles/vm_nato.gd#L544)
- lower hull between the wheels; the nose and tail blocks full width — [VmNato._marshall:549](../scripts/game/vehicles/vm_nato.gd#L549)
- the upper hull: a vertical band over the wheels, then the sides leaning in — [VmNato._marshall:553](../scripts/game/vehicles/vm_nato.gd#L553)
- wheel wells: dark liners under the overhang over each wheel — [VmNato._marshall:558](../scripts/game/vehicles/vm_nato.gd#L558)
- glacis: the trim vane folded flat, the driver's hatch and periscopes, the engine deck grilles on the right, lights and tow eyes on the nose — [VmNato._marshall:562](../scripts/game/vehicles/vm_nato.gd#L562)
- exhaust grille on the right side, forward — [VmNato._marshall:581](../scripts/game/vehicles/vm_nato.gd#L581)
- side details: stowage bins on the sloping sides, the hull door seams, vision blocks, a tow cable — [VmNato._marshall:583](../scripts/game/vehicles/vm_nato.gd#L583)
- roof over the troop compartment: two hatches, periscopes — [VmNato._marshall:593](../scripts/game/vehicles/vm_nato.gd#L593)
- the rear: ramp with its door, hinges, lights, steps — [VmNato._marshall:599](../scripts/game/vehicles/vm_nato.gd#L599)
- --- the turret: low and faceted, the 40 mm, smoke dischargers, the commander's panoramic sight on its mast — [VmNato._marshall:610](../scripts/game/vehicles/vm_nato.gd#L610)
- gun: the mantlet, the barrel with its jacket, the muzzle brake — [VmNato._marshall:618](../scripts/game/vehicles/vm_nato.gd#L618)
- coaxial MG port beside the mantlet — [VmNato._marshall:625](../scripts/game/vehicles/vm_nato.gd#L625)
- sights: gunner's forward left, the commander's panoramic sight on a mast — [VmNato._marshall:627](../scripts/game/vehicles/vm_nato.gd#L627)
- hatches, smoke dischargers, bustle stowage, antenna — [VmNato._marshall:633](../scripts/game/vehicles/vm_nato.gd#L633)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._xy`, `VmNato._zy`.

### mb4wd, mb4wd_at, mb4wd_lmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._mb4wd:515](../scripts/game/vehicles/vm_civ.gd#L515)
- frame, wells, axles (solid beam axles front and rear), the skid plate — [VmCiv._mb4wd:523](../scripts/game/vehicles/vm_civ.gd#L523)
- the tub: a floor pan with the arches cut out, walls standing on it — [VmCiv._mb4wd:531](../scripts/game/vehicles/vm_civ.gd#L531)
- bonnet over a narrow engine bay, then the flat-topped wings with flares — [VmCiv._mb4wd:537](../scripts/game/vehicles/vm_civ.gd#L537)
- hood latches, indicator on the wing, exposed hinges, the door's shut lines and handle, a black mirror, rock rails — [VmCiv._mb4wd:547](../scripts/game/vehicles/vm_civ.gd#L547)
- square tail lights on the rear corners — [VmCiv._mb4wd:559](../scripts/game/vehicles/vm_civ.gd#L559)
- the face: seven slots between round headlights, bumper with tow hooks — [VmCiv._mb4wd:562](../scripts/game/vehicles/vm_civ.gd#L562)
- windscreen: an upright frame folding on the cowl, wipers — [VmCiv._mb4wd:577](../scripts/game/vehicles/vm_civ.gd#L577)
- inside: dash, the wheel (left-hand drive), two buckets and a bench — [VmCiv._mb4wd:590](../scripts/game/vehicles/vm_civ.gd#L590)
- the sport bar: a hoop behind the front seats, rails to the windscreen and down to the rear corners, padded — [VmCiv._mb4wd:600](../scripts/game/vehicles/vm_civ.gd#L600)
- rear: spare wheel on the tailgate, bumper, plate, third light — [VmCiv._mb4wd:608](../scripts/game/vehicles/vm_civ.gd#L608)

**Local helper construction:** `VmCiv._bent`, `VmCiv._face`, `VmCiv._flare`, `VmCiv._inset`, `VmCiv._lamp`, `VmCiv._lmg`, `VmCiv._mb_gun`, `VmCiv._mb_top`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCiv._zring`.

### mohawk

**Shared:** `VehicleAircraft.gear_leg`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleRotors.tail`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._mohawk:833](../scripts/game/vehicles/vm_heli.gd#L833)
- the olive upper half of the scheme — [VmHeli._mohawk:852](../scripts/game/vehicles/vm_heli.gd#L852)
- the cockpit: windscreen, chin windows, side windows — [VmHeli._mohawk:854](../scripts/game/vehicles/vm_heli.gd#L854)
- the cabin door (right, forward), windows down both sides — [VmHeli._mohawk:860](../scripts/game/vehicles/vm_heli.gd#L860)
- the ramp: hinge line, its edges — [VmHeli._mohawk:867](../scripts/game/vehicles/vm_heli.gd#L867)
- sponsons with the twin-wheel main gear, the twin nosewheel — [VmHeli._mohawk:871](../scripts/game/vehicles/vm_heli.gd#L871)
- the hoist over the door, the radome, pitots — [VmHeli._mohawk:887](../scripts/game/vehicles/vm_heli.gd#L887)
- the roof: gearbox fairing, three engines, their intakes and exhausts — [VmHeli._mohawk:893](../scripts/game/vehicles/vm_heli.gd#L893)
- mast, the IR jammer, antennas — [VmHeli._mohawk:906](../scripts/game/vehicles/vm_heli.gd#L906)
- the tail pylon, the tail rotor on its left, the tailplane on its right — [VmHeli._mohawk:912](../scripts/game/vehicles/vm_heli.gd#L912)
- the rotor: five BERP blades — [VmHeli._mohawk:919](../scripts/game/vehicles/vm_heli.gd#L919)

**Local helper construction:** `VmHeli._gear`, `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._rz`, `VmHeli._tail_rotor`, `VmHeli._tube`.

### mora

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.lifting_eye`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._mora:366](../scripts/game/vehicles/vm_indep.gd#L366)
- running gear: front sprocket, six road wheels, rear idler, three rollers — [VmIndep._mora:370](../scripts/game/vehicles/vm_indep.gd#L370)
- the hull: belly between the tracks, the upper hull out over them with the long glacis — [VmIndep._mora:376](../scripts/game/vehicles/vm_indep.gd#L376)
- skirts: five bolted panels a side, the front one raked — [VmIndep._mora:380](../scripts/game/vehicles/vm_indep.gd#L380)
- the hull's side seam at the deck line, a stowage box aft — [VmIndep._mora:386](../scripts/game/vehicles/vm_indep.gd#L386)
- headlight clusters in guards on the glacis corners, tow hooks — [VmIndep._mora:389](../scripts/game/vehicles/vm_indep.gd#L389)
- glacis: the driver's hatch and vision blocks front-left, the engine louvres front-right, lifting eyes — [VmIndep._mora:392](../scripts/game/vehicles/vm_indep.gd#L392)
- exhaust: the louvred outlet on the right flank, forward — [VmIndep._mora:407](../scripts/game/vehicles/vm_indep.gd#L407)
- roof: the troop compartment's long hatch, a vent, antennas at the back — [VmIndep._mora:411](../scripts/game/vehicles/vm_indep.gd#L411)
- rear: the big door with its vision block and handles, a stowage bin either side of it, tail lights, the tow pintle — [VmIndep._mora:415](../scripts/game/vehicles/vm_indep.gd#L415)
- the turret: faceted, the RARDEN in its narrow mantlet, the chain gun beside it, sights and hatches on the roof — [VmIndep._mora:431](../scripts/game/vehicles/vm_indep.gd#L431)
- gunner's sight left, the commander's sight right, two hatches — [VmIndep._mora:445](../scripts/game/vehicles/vm_indep.gd#L445)
- four-barrel smoke dischargers on the front corners — [VmIndep._mora:454](../scripts/game/vehicles/vm_indep.gd#L454)
- the bustle: a stowage basket with a rolled tarp and kit in it — [VmIndep._mora:457](../scripts/game/vehicles/vm_indep.gd#L457)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### motorboat

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMarine.mooring`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._motorboat:525](../scripts/game/vehicles/vm_boat.gd#L525)
- topsides round the cockpit, in two runs so they keep the chine — [VmBoat._motorboat:542](../scripts/game/vehicles/vm_boat.gd#L542)
- the stripe, the rub rail under the sheer, spray rails on the bottom — [VmBoat._motorboat:552](../scripts/game/vehicles/vm_boat.gd#L552)
- the transom above the sole, notched for the motor, and the splash well — [VmBoat._motorboat:577](../scripts/game/vehicles/vm_boat.gd#L577)
- the stern bench in front of it — [VmBoat._motorboat:585](../scripts/game/vehicles/vm_boat.gd#L585)
- the centre console: a sloped dash, a wrap windscreen, wheel and throttle — [VmBoat._motorboat:589](../scripts/game/vehicles/vm_boat.gd#L589)
- the windscreen: a raked front pane and two side wings, framed, a grab rail on top — [VmBoat._motorboat:593](../scripts/game/vehicles/vm_boat.gd#L593)
- a seat on a cool box in front of the console, the helm bench behind it — [VmBoat._motorboat:609](../scripts/game/vehicles/vm_boat.gd#L609)
- the bow rail on its stanchions — [VmBoat._motorboat:618](../scripts/game/vehicles/vm_boat.gd#L618)
- cleats, a bow navigation light, the stern light's pole — [VmBoat._motorboat:635](../scripts/game/vehicles/vm_boat.gd#L635)
- a non-skid sole between the topsides — [VmBoat._motorboat:649](../scripts/game/vehicles/vm_boat.gd#L649)
- two fenders stowed on the sole, a VHF whip on the console — [VmBoat._motorboat:655](../scripts/game/vehicles/vm_boat.gd#L655)
- the bow eye and the registration number on both bows — [VmBoat._motorboat:663](../scripts/game/vehicles/vm_boat.gd#L663)
- 115 hp outboard on the transom notch — [VmBoat._motorboat:675](../scripts/game/vehicles/vm_boat.gd#L675)

**Local helper construction:** `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._slab`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### neophron

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._neophron:1028](../scripts/game/vehicles/vm_plane.gd#L1028)
- engine nacelles under the wing-root extensions, intakes raked back — [VmPlane._neophron:1054](../scripts/game/vehicles/vm_plane.gd#L1054)
- LERX into the shoulder wing, the fin and the stabilators — [VmPlane._neophron:1063](../scripts/game/vehicles/vm_plane.gd#L1063)
- tip rails with R-73s, lights, probes, antennas — [VmPlane._neophron:1069](../scripts/game/vehicles/vm_plane.gd#L1069)
- stores: the gun pod; bombs, B-8 rocket pods and R-73s underwing — [VmPlane._neophron:1077](../scripts/game/vehicles/vm_plane.gd#L1077)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.gun_pod`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### nyx_aa, nyx_ac, nyx_at, nyx_recon

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._nyx:604](../scripts/game/vehicles/vm_indep.gd#L604)
- hull: the belly between the tracks, the upper hull over them with the long glacis — [VmIndep._nyx:610](../scripts/game/vehicles/vm_indep.gd#L610)
- the driver's hatch and periscopes front-left, the engine grille on the glacis front-right, the exhaust on the right flank — [VmIndep._nyx:616](../scripts/game/vehicles/vm_indep.gd#L616)
- headlights with guards on the glacis corners, tow eyes, smoke dischargers on the roof's front corners — [VmIndep._nyx:627](../scripts/game/vehicles/vm_indep.gd#L627)
- a stowage box on each flank aft, tail lights, a jerrycan — [VmIndep._nyx:632](../scripts/game/vehicles/vm_indep.gd#L632)
- rear: the crew door and its handle, the tow pintle, a jerrycan rack — [VmIndep._nyx:635](../scripts/game/vehicles/vm_indep.gd#L635)
- the periscope mast, extended, at the back left — [VmIndep._nyx:644](../scripts/game/vehicles/vm_indep.gd#L644)
- the radar: a flat array on a turning pedestal over its electronics — [VmIndep._nyx:650](../scripts/game/vehicles/vm_indep.gd#L650)
- the weapon mount: a low armoured turntable at the back of the roof — [VmIndep._nyx:660](../scripts/game/vehicles/vm_indep.gd#L660)
- the Rh 202 in its cradle on top, ammunition boxes either side, a sight — [VmIndep._nyx:667](../scripts/game/vehicles/vm_indep.gd#L667)
- a twin launcher for the fire-and-forget missiles on the left, a sight head in the middle, the .50 on the right — [VmIndep._nyx:680](../scripts/game/vehicles/vm_indep.gd#L680)
- two four-round pods either side of the sight head, the .50 under the left one — [VmIndep._nyx:693](../scripts/game/vehicles/vm_indep.gd#L693)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._idler`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._nyx_m2`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._road_wheel`, `VmIndep._running_gear`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._sprocket`, `VmIndep._tb`, `VmIndep._track_belt`.

### offroad, offroad_at, offroad_hmg, offroad_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.jerrycan`, `VehicleFittings.parked_wiper`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._offroad:295](../scripts/game/vehicles/vm_civ.gd#L295)
- ladder frame, the wells behind the wheels, axles and diffs, exhaust — [VmCiv._offroad:302](../scripts/game/vehicles/vm_civ.gd#L302)
- the cab and front wings in one panel, the nose a loft with its corners rounded off for the headlights to wrap round, the bed separate — [VmCiv._offroad:311](../scripts/game/vehicles/vm_civ.gd#L311)
- the black lower lip and the intake under the grille — [VmCiv._offroad:336](../scripts/game/vehicles/vm_civ.gd#L336)
- bed: walls on the tub, a ribbed liner, wheel tubs, the tailgate — [VmCiv._offroad:340](../scripts/game/vehicles/vm_civ.gd#L340)
- glasshouse: windscreen raked hard back, a short cab with its back window — [VmCiv._offroad:351](../scripts/game/vehicles/vm_civ.gd#L351)
- doors: shut lines, handles, mirrors; side steps under them — [VmCiv._offroad:360](../scripts/game/vehicles/vm_civ.gd#L360)
- flared arches in black plastic — [VmCiv._offroad:372](../scripts/game/vehicles/vm_civ.gd#L372)
- tall tail lights on the bed corners — [VmCiv._offroad:377](../scripts/game/vehicles/vm_civ.gd#L377)
- fuel filler on the bed side — [VmCiv._offroad:380](../scripts/game/vehicles/vm_civ.gd#L380)
- the face: the tall single-frame grille in a bright surround, slats, plate — [VmCiv._offroad:382](../scripts/game/vehicles/vm_civ.gd#L382)
- wipers, aerial — [VmCiv._offroad:395](../scripts/game/vehicles/vm_civ.gd#L395)
- rear: step bumper, plate, tow ball — [VmCiv._offroad:399](../scripts/game/vehicles/vm_civ.gd#L399)

**Local helper construction:** `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._inset`, `VmCiv._jerrycan`, `VmCiv._lamp`, `VmCiv._m2`, `VmCiv._mirror`, `VmCiv._off_at`, `VmCiv._off_hmg`, `VmCiv._off_repair`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._ring`, `VmCiv._rod`, `VmCiv._spare`, `VmCiv._spg9`, `VmCiv._strut`, `VmCiv._team_side`, `VmCiv._xbody`, `VmCiv._yloft`, `VmCiv._zring`.

### old_tank

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.lifting_eye`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._t55:583](../scripts/game/vehicles/vm_core.gd#L583)
- --- running gear: front idler, five road wheels (the gap after the first), rear sprocket; the track sagging onto the wheels — [VmCore._t55:587](../scripts/game/vehicles/vm_core.gd#L587)
- one road wheel a replacement, still in its old green — [VmCore._t55:598](../scripts/game/vehicles/vm_core.gd#L598)
- --- the hull: the belly between the tracks with the lower glacis, the upper hull over the tracks, the glacis rising at 60 degrees — [VmCore._t55:607](../scripts/game/vehicles/vm_core.gd#L607)
- the splash board: a V across the glacis, its point forward — [VmCore._t55:618](../scripts/game/vehicles/vm_core.gd#L618)
- spare track links bolted across the glacis below it, tow hooks under the nose — [VmCore._t55:625](../scripts/game/vehicles/vm_core.gd#L625)
- the driver's hatch front left and his two periscopes, the lights on the glacis corners: the headlight and the IR driving light on the left (its lens long gone), one headlight on the right — [VmCore._t55:631](../scripts/game/vehicles/vm_core.gd#L631)
- --- fenders: thin shelves the full length over the tracks, on brackets, the front mudguards angled down (the left one bent up), the rear ones — [VmCore._t55:649](../scripts/game/vehicles/vm_core.gd#L649)
- the right fender: three external fuel tanks (dented, one streaked with rust), a stowage box forward; their straps and pipes — [VmCore._t55:660](../scripts/game/vehicles/vm_core.gd#L660)
- the left fender: stowage boxes, the spare parts box, the oil tank; the exhaust louvre on the hull side above it, sooted round — [VmCore._t55:674](../scripts/game/vehicles/vm_core.gd#L674)
- rust streaks down the hull sides and the glacis corners — [VmCore._t55:685](../scripts/game/vehicles/vm_core.gd#L685)
- --- the engine deck: the louvred grilles, the access plates, the radiator grille across the back — [VmCore._t55:688](../scripts/game/vehicles/vm_core.gd#L688)
- --- the rear: the sloped plate, the two 200-litre drums on their brackets (one rust-brown, one green), the unditching log under them, tail lights, tow hooks — [VmCore._t55:697](../scripts/game/vehicles/vm_core.gd#L697)
- --- the turret: the cast dome — [VmCore._t55:717](../scripts/game/vehicles/vm_core.gd#L717)
- the cast mantlet in the dome's front and the canvas boot over the gun — [VmCore._t55:730](../scripts/game/vehicles/vm_core.gd#L730)
- the 100 mm: the long tapering barrel, the fume extractor near the muzzle — [VmCore._t55:737](../scripts/game/vehicles/vm_core.gd#L737)
- the coaxial PKT's port right of the gun — [VmCore._t55:743](../scripts/game/vehicles/vm_core.gd#L743)
- the L-2 IR searchlight on its bracket to the right of the gun — [VmCore._t55:746](../scripts/game/vehicles/vm_core.gd#L746)
- the gunner's sight port front left, the ventilator dome front right — [VmCore._t55:753](../scripts/game/vehicles/vm_core.gd#L753)
- the commander's cupola on the left with its vision blocks and the small IR spotlight, the loader's hatch on the right with the DShK on its ring — [VmCore._t55:759](../scripts/game/vehicles/vm_core.gd#L759)
- grab rails round the dome, the snorkel stowed across the back, a rolled tarpaulin, lifting eyes — [VmCore._t55:777](../scripts/game/vehicles/vm_core.gd#L777)
- rust round the cupola and a streak down the dome's flank — [VmCore._t55:795](../scripts/game/vehicles/vm_core.gd#L795)

**Local helper construction:** `VmCore._antenna`, `VmCore._bar`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._dshk`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._oct`, `VmCore._on_face`, `VmCore._path`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._round_ring`, `VmCore._rz`, `VmCore._shackle`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._tooth`, `VmCore._tube`.

### orca, orca_armed

**Shared:** `VehicleAircraft.gear_leg`, `VehicleAircraft.rocket_pod`, `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._orca:1162](../scripts/game/vehicles/vm_heli.gd#L1162)
- the windscreen, chin windows, cockpit door windows — [VmHeli._orca:1182](../scripts/game/vehicles/vm_heli.gd#L1182)
- the sliding doors and a window behind them — [VmHeli._orca:1187](../scripts/game/vehicles/vm_heli.gd#L1187)
- the roof fairing with the engine intakes and exhausts — [VmHeli._orca:1193](../scripts/game/vehicles/vm_heli.gd#L1193)
- the fenestron: shroud with its open duct, the fin, the tailplane — [VmHeli._orca:1208](../scripts/game/vehicles/vm_heli.gd#L1208)
- tricycle wheels: the nosewheel, mains in their fairings — [VmHeli._orca:1218](../scripts/game/vehicles/vm_heli.gd#L1218)
- side pylons: a minigun on the left, a rocket pod on the right — [VmHeli._orca:1225](../scripts/game/vehicles/vm_heli.gd#L1225)
- the rotor: four blades with swept tips — [VmHeli._orca:1235](../scripts/game/vehicles/vm_heli.gd#L1235)

**Local helper construction:** `VmHeli._ducted_fin`, `VmHeli._fan`, `VmHeli._gear`, `VmHeli._hull`, `VmHeli._minigun`, `VmHeli._mx`, `VmHeli._patch`, `VmHeli._ray_hit`, `VmHeli._rbox`, `VmHeli._rocket_pod`, `VmHeli._rotor`, `VmHeli._tube`.

### panther

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleEquipment.skirt`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._panther:1171](../scripts/game/vehicles/vm_nato.gd#L1171)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_running`, `VmNato._namer_hull`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._tube`, `VmNato._zy`.

### patrol_ship

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmShips._patrol_ship:622](../scripts/game/vehicles/vm_ships.gd#L622)
- spray rails and chine flats on the bottom, the rubbing strake under the deck edge, a toe rail round the open decks, a capping on the bulwark — [VmShips._patrol_ship:633](../scripts/game/vehicles/vm_ships.gd#L633)
- scuppers along the deck edge, exhaust outlets low aft, the hull number — [VmShips._patrol_ship:663](../scripts/game/vehicles/vm_ships.gd#L663)
- draft marks at the stem and stern — [VmShips._patrol_ship:672](../scripts/game/vehicles/vm_ships.gd#L672)
- --- the deckhouse: the pilothouse forward, the lower after house — [VmShips._patrol_ship:677](../scripts/game/vehicles/vm_ships.gd#L677)
- the window band: dark surrounds, then the panes, pillars between them — [VmShips._patrol_ship:689](../scripts/game/vehicles/vm_ships.gd#L689)
- window pillars at the facet corners, wipers on the windscreen — [VmShips._patrol_ship:708](../scripts/game/vehicles/vm_ships.gd#L708)
- the roof, its visor over the windscreen, a coaming round its edge — [VmShips._patrol_ship:714](../scripts/game/vehicles/vm_ships.gd#L714)
- the pilothouse's after wall above the after house: two small windows, a door to the roof — [VmShips._patrol_ship:722](../scripts/game/vehicles/vm_ships.gd#L722)
- the after house: doors and portholes in its sides, a ladder up its back — [VmShips._patrol_ship:725](../scripts/game/vehicles/vm_ships.gd#L725)
- a life ring, a fire-hose box, the team panel — [VmShips._patrol_ship:745](../scripts/game/vehicles/vm_ships.gd#L745)
- navigation sidelights on the pilothouse shoulders, red to port — [VmShips._patrol_ship:749](../scripts/game/vehicles/vm_ships.gd#L749)
- --- the after house's roof: rails round it, four liferafts tipped outboard, the satcom dome, HVAC boxes, whips at the corners — [VmShips._patrol_ship:757](../scripts/game/vehicles/vm_ships.gd#L757)
- --- the pilothouse roof: the raked mast with the radar, searchlights, the EO ball, the horn, whips — [VmShips._patrol_ship:778](../scripts/game/vehicles/vm_ships.gd#L778)
- the topmast, the yardarm with its lights and halyards, the masthead light — [VmShips._patrol_ship:789](../scripts/game/vehicles/vm_ships.gd#L789)
- --- the foredeck: the forward Mk 38 (the turret), its ready-use lockers, a hatch, the windlass, bitts, the jackstaff and the anchor on its roller — [VmShips._patrol_ship:805](../scripts/game/vehicles/vm_ships.gd#L805)
- fairleads through the bulwark by the bow bitts — [VmShips._patrol_ship:819](../scripts/game/vehicles/vm_ships.gd#L819)
- the anchor: shank up on the roller, its flukes against the stem — [VmShips._patrol_ship:840](../scripts/game/vehicles/vm_ships.gd#L840)
- --- lifelines from the bulwark's end aft round the stern, a gate at the transom — [VmShips._patrol_ship:847](../scripts/game/vehicles/vm_ships.gd#L847)
- --- side decks: .50 cals on pedestals beside the pilothouse and aft — [VmShips._patrol_ship:869](../scripts/game/vehicles/vm_ships.gd#L869)
- --- the after deck: the second Mk 38 trained aft, its lockers, hatches, vents, fenders, the ensign staff, the waterjets on the transom — [VmShips._patrol_ship:875](../scripts/game/vehicles/vm_ships.gd#L875)
- the stern light and the stern's exhaust pipes — [VmShips._patrol_ship:901](../scripts/game/vehicles/vm_ships.gd#L901)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._skin`, `VmBoat._strip`, `VmShips._at`, `VmShips._bitts`, `VmShips._box_mesh`, `VmShips._bulwark`, `VmShips._bx`, `VmShips._coil`, `VmShips._decal`, `VmShips._deck_mesh`, `VmShips._deck_y`, `VmShips._digits`, `VmShips._dk`, `VmShips._flag`, `VmShips._hull`, `VmShips._hull_bands`, `VmShips._insert`, `VmShips._keel_y`, `VmShips._liferaft`, `VmShips._lifering`, `VmShips._m2`, `VmShips._mk38`, `VmShips._rod`, `VmShips._searchlight`, `VmShips._station`, `VmShips._stem_z`, `VmShips._surf`, `VmShips._torus`, `VmShips._tube`, `VmShips._u`, `VmShips._vent`, `VmShips._whip`.

### prowler, prowler_at, prowler_hmg

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCab.seat`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.winch`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._prowler:404](../scripts/game/vehicles/vm_nato.gd#L404)
- --- the chassis tub, belly plate and suspension — [VmNato._prowler:409](../scripts/game/vehicles/vm_nato.gd#L409)
- --- the flat bonnet, its fenders and the nose — [VmNato._prowler:417](../scripts/game/vehicles/vm_nato.gd#L417)
- tube bumper with the winch, lights each side and on the cage — [VmNato._prowler:427](../scripts/game/vehicles/vm_nato.gd#L427)
- --- the cockpit: dash, the cowl, seats, steering wheel — [VmNato._prowler:435](../scripts/game/vehicles/vm_nato.gd#L435)
- rear deck: outward-facing benches either side, kit stowed between — [VmNato._prowler:443](../scripts/game/vehicles/vm_nato.gd#L443)
- the spare wheel upright on the tailgate — [VmNato._prowler:453](../scripts/game/vehicles/vm_nato.gd#L453)
- --- the roll cage — [VmNato._prowler:458](../scripts/game/vehicles/vm_nato.gd#L458)
- light bar on the front roof bar, antennas at the back — [VmNato._prowler:476](../scripts/game/vehicles/vm_nato.gd#L476)
- the passenger's pintle MG (an M240-class .338) on a swing arm — [VmNato._prowler:486](../scripts/game/vehicles/vm_nato.gd#L486)
- the ring mount on the cage roof — [VmNato._prowler:493](../scripts/game/vehicles/vm_nato.gd#L493)
- the pintle gun is the second gun, decoration here — [VmNato._prowler:506](../scripts/game/vehicles/vm_nato.gd#L506)
- Titan launcher: the tube, the sight/command unit, the grip — [VmNato._prowler:508](../scripts/game/vehicles/vm_nato.gd#L508)
- two reloads in a rack on the deck — [VmNato._prowler:518](../scripts/game/vehicles/vm_nato.gd#L518)

**Local helper construction:** `VmNato._ammo_can`, `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._seat`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### qilin, qilin_at, qilin_mg

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.seat`, `VehicleFittings.antenna`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._qilin:351](../scripts/game/vehicles/vm_csat.gd#L351)
- the belly pan and chassis rails — [VmCsat._qilin:353](../scripts/game/vehicles/vm_csat.gd#L353)
- the nose over the radiator: a sloping bonnet — [VmCsat._qilin:355](../scripts/game/vehicles/vm_csat.gd#L355)
- a vent in the bonnet before the screen — [VmCsat._qilin:361](../scripts/game/vehicles/vm_csat.gd#L361)
- the open crew tub: floor and low side walls, the rear engine deck — [VmCsat._qilin:367](../scripts/game/vehicles/vm_csat.gd#L367)
- the dash under the screen frame, the steering wheel, the seats — [VmCsat._qilin:372](../scripts/game/vehicles/vm_csat.gd#L372)
- the passengers' bench over the engine, back to back, facing out — [VmCsat._qilin:378](../scripts/game/vehicles/vm_csat.gd#L378)
- fenders: faceted mudguards over the wheels, steps between them — [VmCsat._qilin:382](../scripts/game/vehicles/vm_csat.gd#L382)
- round headlamps with guards, the indicators — [VmCsat._qilin:389](../scripts/game/vehicles/vm_csat.gd#L389)
- mirrors on the screen frame — [VmCsat._qilin:394](../scripts/game/vehicles/vm_csat.gd#L394)
- exhaust out of the right rear — [VmCsat._qilin:396](../scripts/game/vehicles/vm_csat.gd#L396)
- the grille and bull bar — [VmCsat._qilin:398](../scripts/game/vehicles/vm_csat.gd#L398)
- the spare wheel upright on the tail, jerrycans beside it — [VmCsat._qilin:407](../scripts/game/vehicles/vm_csat.gd#L407)
- the roll cage — [VmCsat._qilin:411](../scripts/game/vehicles/vm_csat.gd#L411)
- the weapon ring on the cage over the gunner's station — [VmCsat._qilin:432](../scripts/game/vehicles/vm_csat.gd#L432)
- the minigun: six barrels round a spindle, the motor and feed chute — [VmCsat._qilin:450](../scripts/game/vehicles/vm_csat.gd#L450)
- the Vorona: a fat launch tube on a cradle, the thermal sight beside it — [VmCsat._qilin:466](../scripts/game/vehicles/vm_csat.gd#L466)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._jerrycan`, `VmCsat._onface`, `VmCsat._plate`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### quadbike

**Shared:** `VehicleBody.paint_mesh`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._quad:987](../scripts/game/vehicles/vm_civ.gd#L987)
- frame, engine, swingarm — [VmCiv._quad:993](../scripts/game/vehicles/vm_civ.gd#L993)
- double wishbones and a shock to each front wheel — [VmCiv._quad:996](../scripts/game/vehicles/vm_civ.gd#L996)
- the front body over the wheels, the console and tank, the rear body — [VmCiv._quad:1005](../scripts/game/vehicles/vm_civ.gd#L1005)
- floorboards with their raised lips — [VmCiv._quad:1010](../scripts/game/vehicles/vm_civ.gd#L1010)
- tubular racks front and back — [VmCiv._quad:1018](../scripts/game/vehicles/vm_civ.gd#L1018)
- handlebars and the pod with its headlight, grips, levers — [VmCiv._quad:1031](../scripts/game/vehicles/vm_civ.gd#L1031)
- the brush guard, the tail light, the exhaust out back, a tow hitch — [VmCiv._quad:1042](../scripts/game/vehicles/vm_civ.gd#L1042)

**Local helper construction:** `VmCiv._bent`, `VmCiv._lamp`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._xbody`.

### rhib

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.seat`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMarine.mooring`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._rhib:685](../scripts/game/vehicles/vm_boat.gd#L685)
- spray rails along the bottom — [VmBoat._rhib:696](../scripts/game/vehicles/vm_boat.gd#L696)
- the collar: runs along the sheer, kicks up at the bow, its ends past the transom — [VmBoat._rhib:710](../scripts/game/vehicles/vm_boat.gd#L710)
- the centre console under its radar arch — [VmBoat._rhib:734](../scripts/game/vehicles/vm_boat.gd#L734)
- side lights on the console's shoulders, the team panel below them — [VmBoat._rhib:749](../scripts/game/vehicles/vm_boat.gd#L749)
- the arch: two legs a side up to a platform with the radar, lights, whips — [VmBoat._rhib:752](../scripts/game/vehicles/vm_boat.gd#L752)
- two rows of jockey seats, each with a grab bar — [VmBoat._rhib:773](../scripts/game/vehicles/vm_boat.gd#L773)
- a seat box forward of the console, the stern locker — [VmBoat._rhib:783](../scripts/game/vehicles/vm_boat.gd#L783)
- bow: an anchor locker hatch, a cleat and the towing eye on the stem — [VmBoat._rhib:790](../scripts/game/vehicles/vm_boat.gd#L790)
- twin outboards and the tie bar between them — [VmBoat._rhib:798](../scripts/game/vehicles/vm_boat.gd#L798)

**Local helper construction:** `VmBoat._aim`, `VmBoat._bake`, `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._foil`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._offset`, `VmBoat._outboard`, `VmBoat._prop`, `VmBoat._resample`, `VmBoat._rnd`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._tube`, `VmBoat._tube_kit`, `VmBoat._u`.

### rhino, rhino_up

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._rhino:651](../scripts/game/vehicles/vm_nato.gd#L651)
- the lower hull: a pointed nose under the glacis, sides inboard of the wheels — [VmNato._rhino:656](../scripts/game/vehicles/vm_nato.gd#L656)
- the upper hull: the arrowhead nose climbing to a narrow front of the roof — [VmNato._rhino:661](../scripts/game/vehicles/vm_nato.gd#L661)
- the driver's hatch centred at the top of the glacis, his periscopes, lights in guards on the nose, tow eyes — [VmNato._rhino:669](../scripts/game/vehicles/vm_nato.gd#L669)
- big stowage bins along the leaning sides, the engine deck louvres — [VmNato._rhino:678](../scripts/game/vehicles/vm_nato.gd#L678)
- --- the turret: wedged front faces round the gun, a long bustle — [VmNato._rhino:692](../scripts/game/vehicles/vm_nato.gd#L692)
- the gun: mantlet, barrel with its thermal sleeve and fume extractor, the muzzle reference sensor — [VmNato._rhino:699](../scripts/game/vehicles/vm_nato.gd#L699)
- sights: the gunner's ahead on the left, the commander's cupola and his panoramic sight on the right; the loader's hatch — [VmNato._rhino:710](../scripts/game/vehicles/vm_nato.gd#L710)
- bins on the bustle sides — [VmNato._rhino:725](../scripts/game/vehicles/vm_nato.gd#L725)
- --- urban package: ERA bricks on the turret front and cheeks and along the glacis, slat cages round the hull sides and back, a remote .50 — [VmNato._rhino:740](../scripts/game/vehicles/vm_nato.gd#L740)
- the turret's front cheeks and the forward half of its sides — [VmNato._rhino:743](../scripts/game/vehicles/vm_nato.gd#L743)
- both plates of the arrowhead glacis — [VmNato._rhino:746](../scripts/game/vehicles/vm_nato.gd#L746)
- slat cages: a frame standing off each side and across the back — [VmNato._rhino:748](../scripts/game/vehicles/vm_nato.gd#L748)
- the remote weapon station on the turret roof (it turns with the gun) — [VmNato._rhino:762](../scripts/game/vehicles/vm_nato.gd#L762)

**Local helper construction:** `VmNato._antenna`, `VmNato._axles`, `VmNato._cam`, `VmNato._era`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._on_face`, `VmNato._rcws`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._xy`.

### sandstorm

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._sandstorm:1033](../scripts/game/vehicles/vm_nato.gd#L1033)
- the crew's cupola and periscopes forward, where a turret would be — [VmNato._sandstorm:1036](../scripts/game/vehicles/vm_nato.gd#L1036)
- the launcher's travel rest on the roof, where the box's front end sits — [VmNato._sandstorm:1044](../scripts/game/vehicles/vm_nato.gd#L1044)
- the turntable and the launcher's base with its elevation rams — [VmNato._sandstorm:1048](../scripts/game/vehicles/vm_nato.gd#L1048)
- the launcher box: hinged at its rear end, the pods' tubes facing forward — [VmNato._sandstorm:1056](../scripts/game/vehicles/vm_nato.gd#L1056)
- each pod's face: six tube mouths behind the frangible covers — [VmNato._sandstorm:1064](../scripts/game/vehicles/vm_nato.gd#L1064)
- ribs down the sides, the boom-hoists along the top edges — [VmNato._sandstorm:1069](../scripts/game/vehicles/vm_nato.gd#L1069)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy`.

### scorcher

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._scorcher:984](../scripts/game/vehicles/vm_nato.gd#L984)
- the barrel's travel lock folded down on the glacis — [VmNato._scorcher:987](../scripts/game/vehicles/vm_nato.gd#L987)
- the tall box: sloped front faces, vertical sides, the bustle — [VmNato._scorcher:992](../scripts/game/vehicles/vm_nato.gd#L992)
- side doors, roof hatches, the commander's cupola with a remote .50 — [VmNato._scorcher:996](../scripts/game/vehicles/vm_nato.gd#L996)
- the gun: trunnions at the turret front, the cradle, recoil cylinders, the long tube with its fume extractor and the double-baffle muzzle brake — [VmNato._scorcher:1011](../scripts/game/vehicles/vm_nato.gd#L1011)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._zy`.

### sdv

**Shared:** `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.lifting_eye`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._sdv:811](../scripts/game/vehicles/vm_boat.gd#L811)
- the raised hatch deck over the crew compartment, and its four hatches — [VmBoat._sdv:822](../scripts/game/vehicles/vm_boat.gd#L822)
- forward: the pilot's and navigator's canopy, split down the middle, with viewports in its sloped front and sides — [VmBoat._sdv:825](../scripts/game/vehicles/vm_boat.gd#L825)
- aft: the passengers' two flat hatches — [VmBoat._sdv:841](../scripts/game/vehicles/vm_boat.gd#L841)
- lifting eyes at the deck's corners — [VmBoat._sdv:848](../scripts/game/vehicles/vm_boat.gd#L848)
- the mast with the periscope head and a comms antenna beside it — [VmBoat._sdv:852](../scripts/game/vehicles/vm_boat.gd#L852)
- nose: the sonar window and two lamps — [VmBoat._sdv:859](../scripts/game/vehicles/vm_boat.gd#L859)
- the free-flooding hull's vent grilles and panel seams down each side — [VmBoat._sdv:864](../scripts/game/vehicles/vm_boat.gd#L864)
- the skids it rests on — [VmBoat._sdv:873](../scripts/game/vehicles/vm_boat.gd#L873)
- tail: the cone's end, cruciform fins and the duct round the propeller — [VmBoat._sdv:875](../scripts/game/vehicles/vm_boat.gd#L875)

**Local helper construction:** `VmBoat._foil`, `VmBoat._panel`, `VmBoat._prop`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._sring`.

### sentinel

**Shared:** `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._sentinel:1168](../scripts/game/vehicles/vm_plane.gd#L1168)
- the dorsal intake: a raked hood standing off the hump, its dark mouth — [VmPlane._sentinel:1184](../scripts/game/vehicles/vm_plane.gd#L1184)
- the exhaust buried in the upper surface at the back — [VmPlane._sentinel:1189](../scripts/game/vehicles/vm_plane.gd#L1189)
- (no exhaust glow: the pipe is buried in the upper surface to hide it) — [VmPlane._sentinel:1192](../scripts/game/vehicles/vm_plane.gd#L1192)
- the cranked outer wings: elevons, the fold line — [VmPlane._sentinel:1194](../scripts/game/vehicles/vm_plane.gd#L1194)
- body elevons along the inner trailing edges — [VmPlane._sentinel:1198](../scripts/game/vehicles/vm_plane.gd#L1198)
- the sensor window under the nose, belly doors, the hook, antennas — [VmPlane._sentinel:1204](../scripts/game/vehicles/vm_plane.gd#L1204)
- flush satcom and GPS patches on the hump, the refuelling probe door — [VmPlane._sentinel:1212](../scripts/game/vehicles/vm_plane.gd#L1212)

**Local helper construction:** `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### shikra

**Shared:** `VehicleAircraft.duct`, `VehicleAircraft.hardpoint`, `VehicleAircraft.inset`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._shikra:949](../scripts/game/vehicles/vm_plane.gd#L949)
- the nacelles, raked intakes under the LEVCONs, round Su-35 nozzles — [VmPlane._shikra:976](../scripts/game/vehicles/vm_plane.gd#L976)
- LEVCONs, the wing with ailerons and flaperons — [VmPlane._shikra:985](../scripts/game/vehicles/vm_plane.gd#L985)
- tail booms carrying the all-moving tailplanes; all-moving canted fins — [VmPlane._shikra:989](../scripts/game/vehicles/vm_plane.gd#L989)
- the sting between the nozzles — [VmPlane._shikra:995](../scripts/game/vehicles/vm_plane.gd#L995)
- the gun at the right wing root, antennas, navigation lights — [VmPlane._shikra:997](../scripts/game/vehicles/vm_plane.gd#L997)
- stores: Kh-38s under the nacelles, KAB bombs and R-73s under the wings — [VmPlane._shikra:1004](../scripts/game/vehicles/vm_plane.gd#L1004)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.body2`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.missile`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.nozzle`, `VmPlane.pylon`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### slammer, slammer_up

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.cable`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._slammer:975](../scripts/game/vehicles/vm_nato.gd#L975)

**Local helper construction:** `VmNato._antenna`, `VmNato._cam`, `VmNato._chain`, `VmNato._era`, `VmNato._gmg`, `VmNato._jerry`, `VmNato._lamp`, `VmNato._m2`, `VmNato._mk_hull`, `VmNato._mk_running`, `VmNato._mk_turret`, `VmNato._on_face`, `VmNato._rcws`, `VmNato._road_wheel`, `VmNato._shackle`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._track_loop`, `VmNato._xy`, `VmNato._zy`.

### sochor

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._sochor:1017](../scripts/game/vehicles/vm_csat.gd#L1017)
- flat sides: a crew door, stowage boxes, vents; the ammunition door at the back — [VmCsat._sochor:1025](../scripts/game/vehicles/vm_csat.gd#L1025)
- roof: hatches, the commander's panoramic sight, the remote 12.7 mm — [VmCsat._sochor:1035](../scripts/game/vehicles/vm_csat.gd#L1035)
- the barrel on its trunnions: mantlet, recoil cylinders, fume extractor, the long tube and the muzzle brake — [VmCsat._sochor:1047](../scripts/game/vehicles/vm_csat.gd#L1047)
- the travel lock, folded down on the glacis — [VmCsat._sochor:1062](../scripts/game/vehicles/vm_csat.gd#L1062)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._era`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._rcws`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`, `VmCsat._tube`.

### speedboat_hmg, speedboat_minigun

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.rectangle`, `VehicleMarine.mooring`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._surc:900](../scripts/game/vehicles/vm_boat.gd#L900)
- the fendering strake along the knuckle, spray rails on the bottom — [VmBoat._surc:908](../scripts/game/vehicles/vm_boat.gd#L908)
- non-skid decks: the open troop deck aft and the foredeck — [VmBoat._surc:928](../scripts/game/vehicles/vm_boat.gd#L928)
- armoured bulwarks round the troop deck, capped — [VmBoat._surc:932](../scripts/game/vehicles/vm_boat.gd#L932)
- the bulwarks' ballistic panels: seams down their sloped faces — [VmBoat._surc:944](../scripts/game/vehicles/vm_boat.gd#L944)
- the transom's bulwark, with a gate in the middle — [VmBoat._surc:949](../scripts/game/vehicles/vm_boat.gd#L949)
- the cabin: near-vertical armoured walls, a band of steeply slanted glass — [VmBoat._surc:953](../scripts/game/vehicles/vm_boat.gd#L953)
- the rear: a door below, a window above it — [VmBoat._surc:972](../scripts/game/vehicles/vm_boat.gd#L972)
- wipers on the windscreen, armour seams on the lower walls — [VmBoat._surc:978](../scripts/game/vehicles/vm_boat.gd#L978)
- side lights on the cabin's shoulders, the team panel aft of them — [VmBoat._surc:983](../scripts/game/vehicles/vm_boat.gd#L983)
- the roof: a raked mast with the radar, a satcom dome, whips, searchlight, smoke dischargers at the front corners, grab rails — [VmBoat._surc:986](../scripts/game/vehicles/vm_boat.gd#L986)
- side-deck handrails along the cabin — [VmBoat._surc:1005](../scripts/game/vehicles/vm_boat.gd#L1005)
- the troop deck: benches with backrests along both bulwarks — [VmBoat._surc:1016](../scripts/game/vehicles/vm_boat.gd#L1016)
- the rear gun on its pedestal ring mount, looking aft over the quarter — [VmBoat._surc:1023](../scripts/game/vehicles/vm_boat.gd#L1023)
- 12.7 mm HMG: a long receiver, a heavy barrel with its muzzle brake — [VmBoat._surc:1035](../scripts/game/vehicles/vm_boat.gd#L1035)
- M134 minigun: six barrels in a clamp, the motor housing, the feed chute — [VmBoat._surc:1042](../scripts/game/vehicles/vm_boat.gd#L1042)
- bow remote weapon station: 40 mm GMG, sight on the right, ammo on the left — [VmBoat._surc:1053](../scripts/game/vehicles/vm_boat.gd#L1053)
- foredeck: twin bitts, a cleat each side, the towing eye on the stem — [VmBoat._surc:1074](../scripts/game/vehicles/vm_boat.gd#L1074)
- transom: twin waterjets with their steering nozzles and raised reversing buckets, tucked under a stern step; the stern light — [VmBoat._surc:1084](../scripts/game/vehicles/vm_boat.gd#L1084)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cleat`, `VmBoat._deck_mesh`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._panel`, `VmBoat._pt`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._ry`, `VmBoat._rz`, `VmBoat._scale_xz`, `VmBoat._sheer`, `VmBoat._station`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### stomper

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmNato._stomper:1622](../scripts/game/vehicles/vm_nato.gd#L1622)
- the swing arm from the hull to the hub, its motor housing — [VmNato._stomper:1628](../scripts/game/vehicles/vm_nato.gd#L1628)
- the armoured tub: a wedge nose, the flanks leaning in — [VmNato._stomper:1631](../scripts/game/vehicles/vm_nato.gd#L1631)
- side pods over the wheels (batteries / engine), angular, low — [VmNato._stomper:1636](../scripts/game/vehicles/vm_nato.gd#L1636)
- the space frame over the tub: rails, hoops and diagonals — [VmNato._stomper:1639](../scripts/game/vehicles/vm_nato.gd#L1639)
- the sensor mast at the nose: stereo cameras, laser scanners, a GPS dome — [VmNato._stomper:1649](../scripts/game/vehicles/vm_nato.gd#L1649)
- the RCWS on the frame — [VmNato._stomper:1666](../scripts/game/vehicles/vm_nato.gd#L1666)

**Local helper construction:** `VmNato._antenna`, `VmNato._beam`, `VmNato._cam`, `VmNato._gmg`, `VmNato._lamp`, `VmNato._m2`, `VmNato._rcws`, `VmNato._smoke`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`.

### strider, strider_gmg, strider_hmg

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleEquipment.sensor`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tow_shackle`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._strider:169](../scripts/game/vehicles/vm_indep.gd#L169)
- the belly between the wheels (its front sloping under the nose) — [VmIndep._strider:176](../scripts/game/vehicles/vm_indep.gd#L176)
- the nose and tail blocks ahead of and behind the wheel arches, the sills between — [VmIndep._strider:178](../scripts/game/vehicles/vm_indep.gd#L178)
- the upper hull: a chine all round, then the armoured nose and windscreen in one steep slope, the cabin's sides leaning in, the engine deck a step lower at the back — [VmIndep._strider:183](../scripts/game/vehicles/vm_indep.gd#L183)
- wheels in their dark wells, mud flaps behind the rear ones — [VmIndep._strider:189](../scripts/game/vehicles/vm_indep.gd#L189)
- the arch's lip — [VmIndep._strider:194](../scripts/game/vehicles/vm_indep.gd#L194)
- windscreen: two armoured panes in heavy frames on the slope, the pillar between — [VmIndep._strider:197](../scripts/game/vehicles/vm_indep.gd#L197)
- a wiper over each pane — [VmIndep._strider:204](../scripts/game/vehicles/vm_indep.gd#L204)
- the nose: headlight clusters in guards, tow shackles, a plate — [VmIndep._strider:209](../scripts/game/vehicles/vm_indep.gd#L209)
- mirrors on their arms by the windscreen — [VmIndep._strider:215](../scripts/game/vehicles/vm_indep.gd#L215)
- the side door: seams, an armoured window, the handle, a step below — [VmIndep._strider:217](../scripts/game/vehicles/vm_indep.gd#L217)
- a small rear-quarter window, the stowage bin over the rear wheel — [VmIndep._strider:225](../scripts/game/vehicles/vm_indep.gd#L225)
- smoke dischargers on the deck corners, a whip antenna at each back corner — [VmIndep._strider:229](../scripts/game/vehicles/vm_indep.gd#L229)
- rear: tail light clusters, the jerrycan rack on the left, a box on the right — [VmIndep._strider:232](../scripts/game/vehicles/vm_indep.gd#L232)
- exhaust out of the right flank behind the rear wheel, under a heat shield — [VmIndep._strider:240](../scripts/game/vehicles/vm_indep.gd#L240)
- roof: the driver's and commander's hatches with periscopes, the observer's hatch behind — [VmIndep._strider:243](../scripts/game/vehicles/vm_indep.gd#L243)
- engine deck: two grilles with their slats — [VmIndep._strider:251](../scripts/game/vehicles/vm_indep.gd#L251)
- the scout: the BAA sensor head (camera, thermal imager, rangefinder) high on a telescopic mast behind the cabin; the head pans — [VmIndep._strider:260](../scripts/game/vehicles/vm_indep.gd#L260)
- the commander's periscope mast, folded low at the cabin's back corner — [VmIndep._strider:271](../scripts/game/vehicles/vm_indep.gd#L271)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._rcws`, `VmIndep._sensor_head`, `VmIndep._smoke`, `VmIndep._tb`, `VmIndep._tow_eyes`.

### suv

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleFittings.headlamp`, `VehicleFittings.parked_wiper`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._suv:1213](../scripts/game/vehicles/vm_civ.gd#L1213)
- doors, chrome handles, the shoulder crease, black skirts, mirrors — [VmCiv._suv:1241](../scripts/game/vehicles/vm_civ.gd#L1241)
- headlights flanking the kidneys, two rings in each, wrapping round — [VmCiv._suv:1249](../scripts/game/vehicles/vm_civ.gd#L1249)
- the tail lights across the corners, a reflector under them — [VmCiv._suv:1257](../scripts/game/vehicles/vm_civ.gd#L1257)
- lower intakes and fog lights, exhausts — [VmCiv._suv:1261](../scripts/game/vehicles/vm_civ.gd#L1261)
- the twin kidneys — [VmCiv._suv:1266](../scripts/game/vehicles/vm_civ.gd#L1266)

**Local helper construction:** `VmCiv._car_details`, `VmCiv._face`, `VmCiv._flare`, `VmCiv._glasshouse`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._xbody`.

### tank

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleFittings.ammo_can`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.lifting_eye`, `VehicleFittings.periscope`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleSurface.plane`, `VehicleTracks.shoes`, `VehicleTracks.wheel_envelope`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._abrams:324](../scripts/game/vehicles/vm_core.gd#L324)
- --- running gear: front idler, seven road wheels, rear sprocket — [VmCore._abrams:327](../scripts/game/vehicles/vm_core.gd#L327)
- --- the hull: the belly between the tracks with the lower glacis at its front, the upper hull out over the tracks with the long upper glacis — [VmCore._abrams:346](../scripts/game/vehicles/vm_core.gd#L346)
- the glacis: the driver's hatch in the middle at its top, his three periscopes; a seam across the nose, lifting eyes — [VmCore._abrams:355](../scripts/game/vehicles/vm_core.gd#L355)
- the front: headlight clusters in their guards on the fender tops, tow shackles on the lower glacis, the front fenders' rubber flaps — [VmCore._abrams:367](../scripts/game/vehicles/vm_core.gd#L367)
- skirts: seven bolted panels a side, the first two heavy armoured ones, the front panel raked over the idler; a bolt line along their tops — [VmCore._abrams:375](../scripts/game/vehicles/vm_core.gd#L375)
- the handrail-like lip of the fender over the skirts, a rear mudguard — [VmCore._abrams:390](../scripts/game/vehicles/vm_core.gd#L390)
- fuel filler caps on the deck over the sponsons — [VmCore._abrams:394](../scripts/game/vehicles/vm_core.gd#L394)
- --- the engine deck: the big grille doors over the turbine and the transmission, the centre access plate, lifting eyes — [VmCore._abrams:397](../scripts/game/vehicles/vm_core.gd#L397)
- --- the rear plate: the turbine exhaust grille across the middle, the tail light clusters, tow pintle and shackles, the infantry phone box — [VmCore._abrams:407](../scripts/game/vehicles/vm_core.gd#L407)
- --- the turret — [VmCore._abrams:421](../scripts/game/vehicles/vm_core.gd#L421)
- the main body: the crew compartment and the long bustle over the deck — [VmCore._abrams:426](../scripts/game/vehicles/vm_core.gd#L426)
- the cheeks: armour blocks either side of the gun shield, swept back in plan, their faces near vertical over a deep undercut — [VmCore._abrams:430](../scripts/game/vehicles/vm_core.gd#L430)
- the seam where the cheek block meets the turret side — [VmCore._abrams:442](../scripts/game/vehicles/vm_core.gd#L442)
- the gun shield, recessed between the cheeks; the gunner's auxiliary sight port on it, the coax M240 to its right — [VmCore._abrams:444](../scripts/game/vehicles/vm_core.gd#L444)
- the 120 mm: the sleeve in sections with their clamp bands, the bore evacuator, the muzzle and its reference sensor — [VmCore._abrams:454](../scripts/game/vehicles/vm_core.gd#L454)
- --- the roof: the gunner's primary sight doghouse front right with its armoured doors, the commander's independent thermal viewer front left — [VmCore._abrams:461](../scripts/game/vehicles/vm_core.gd#L461)
- the commander's station on the right: the cupola ring with its vision blocks, the hatch, the .50 on its mount ahead of it — [VmCore._abrams:472](../scripts/game/vehicles/vm_core.gd#L472)
- the loader's hatch on the left and his M240 behind the gun shield kit — [VmCore._abrams:482](../scripts/game/vehicles/vm_core.gd#L482)
- the crosswind sensor mast at the back of the roof, the blow-off panels over the ammunition in the bustle, lifting eyes, antennas — [VmCore._abrams:493](../scripts/game/vehicles/vm_core.gd#L493)
- M250 smoke dischargers on the flanks behind the cheeks — [VmCore._abrams:503](../scripts/game/vehicles/vm_core.gd#L503)
- stowage boxes along the turret sides, their lids and latches — [VmCore._abrams:505](../scripts/game/vehicles/vm_core.gd#L505)
- the bustle rack: a basket round the back of the bustle, packed with kit — [VmCore._abrams:511](../scripts/game/vehicles/vm_core.gd#L511)

**Local helper construction:** `VmCore._ammo_can`, `VmCore._antenna`, `VmCore._belt`, `VmCore._bx`, `VmCore._cam`, `VmCore._eye`, `VmCore._hatch`, `VmCore._idler`, `VmCore._jerry`, `VmCore._lamp`, `VmCore._m2`, `VmCore._mirror`, `VmCore._mmg`, `VmCore._oct`, `VmCore._periscope`, `VmCore._rings`, `VmCore._road_wheel`, `VmCore._shackle`, `VmCore._smoke`, `VmCore._sprocket`, `VmCore._taillight`, `VmCore._tooth`, `VmCore._zy`.

### taru

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.seam`, `VehicleBody.skin`, `VehicleCab.mesh_glass`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleRotors.blade`, `VehicleRotors.main`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmHeli._taru:1248](../scripts/game/vehicles/vm_heli.gd#L1248)
- the spine — [VmHeli._taru:1255](../scripts/game/vehicles/vm_heli.gd#L1255)
- the cab, glazed all round its nose — [VmHeli._taru:1266](../scripts/game/vehicles/vm_heli.gd#L1266)
- the engines and the gearbox fairing on the spine — [VmHeli._taru:1288](../scripts/game/vehicles/vm_heli.gd#L1288)
- the tailplane with its twin fins, a ventral fin — [VmHeli._taru:1302](../scripts/game/vehicles/vm_heli.gd#L1302)
- the legs: long oleo struts splayed out from the spine, braced — [VmHeli._taru:1307](../scripts/game/vehicles/vm_heli.gd#L1307)
- the transport pod on its four hooks — [VmHeli._taru:1320](../scripts/game/vehicles/vm_heli.gd#L1320)
- the coaxial rotors: three blades each, turning against each other — [VmHeli._taru:1344](../scripts/game/vehicles/vm_heli.gd#L1344)

**Local helper construction:** `VmHeli._hull`, `VmHeli._patch`, `VmHeli._rotor`, `VmHeli._tube`.

### tempest, tempest_ammo, tempest_fuel, tempest_medical, tempest_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._tempest:1279](../scripts/game/vehicles/vm_csat.gd#L1279)
- long missile crates stacked forward, ammunition boxes behind them, cans at the tail, all strapped down — [VmCsat._tempest:1285](../scripts/game/vehicles/vm_csat.gd#L1285)
- Shorter stacked cases preserve the clearance below the folded boom. — [VmCsat._tempest:1291](../scripts/game/vehicles/vm_csat.gd#L1291)
- the loading crane behind the cab, its boom folded back over the load — [VmCsat._tempest:1306](../scripts/game/vehicles/vm_csat.gd#L1306)
- roller shutters on the sides, toolboxes under the body — [VmCsat._tempest:1317](../scripts/game/vehicles/vm_csat.gd#L1317)
- the workshop's back door onto the platform — [VmCsat._tempest:1323](../scripts/game/vehicles/vm_csat.gd#L1323)
- the crane on the open platform behind, its boom along the roof — [VmCsat._tempest:1328](../scripts/game/vehicles/vm_csat.gd#L1328)
- a spare wheel standing on the platform, a welding bottle rack — [VmCsat._tempest:1335](../scripts/game/vehicles/vm_csat.gd#L1335)
- the rear door with its steps, the cross on it, the roof's air units — [VmCsat._tempest:1347](../scripts/game/vehicles/vm_csat.gd#L1347)
- the pump cabinet and hose reels at the back — [VmCsat._tempest:1373](../scripts/game/vehicles/vm_csat.gd#L1373)
- troops: armoured sides, the canvas cover on its bows — [VmCsat._tempest:1379](../scripts/game/vehicles/vm_csat.gd#L1379)
- the boarding ladder hung on the tailgate — [VmCsat._tempest:1392](../scripts/game/vehicles/vm_csat.gd#L1392)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._arch`, `VmCsat._cross`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._plate`, `VmCsat._rz`, `VmCsat._sec`, `VmCsat._taillight`, `VmCsat._tempest_box`, `VmCsat._tempest_flatbed`, `VmCsat._tow`, `VmCsat._tube`, `VmCsat._typhoon`.

### tigris

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._tigris:778](../scripts/game/vehicles/vm_csat.gd#L778)
- the guns: a 35 mm in a cradle on each side, ammunition feed fairings — [VmCsat._tigris:784](../scripts/game/vehicles/vm_csat.gd#L784)
- the tracking radar in its housing on the front of the roof — [VmCsat._tigris:797](../scripts/game/vehicles/vm_csat.gd#L797)
- the optical sight beside it — [VmCsat._tigris:800](../scripts/game/vehicles/vm_csat.gd#L800)
- the search radar: a flat antenna on a mast at the back — [VmCsat._tigris:804](../scripts/game/vehicles/vm_csat.gd#L804)
- twin missile boxes either side of the mast — [VmCsat._tigris:808](../scripts/game/vehicles/vm_csat.gd#L808)

**Local helper construction:** `VmCsat._antenna`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._stalker`, `VmCsat._taillight`, `VmCsat._tow`.

### tractor

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.exhaust`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.revolve`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._tractor:1359](../scripts/game/vehicles/vm_civ.gd#L1359)
- engine, gearbox and the rear axle housings, the front beam axle — [VmCiv._tractor:1369](../scripts/game/vehicles/vm_civ.gd#L1369)
- the bonnet, its grille and lamps, the weights hung on the front — [VmCiv._tractor:1376](../scripts/game/vehicles/vm_civ.gd#L1376)
- louvres along the bonnet sides — [VmCiv._tractor:1384](../scripts/game/vehicles/vm_civ.gd#L1384)
- wheels: small fronts under cycle wings, big rears with chevron lugs — [VmCiv._tractor:1391](../scripts/game/vehicles/vm_civ.gd#L1391)
- the mudguards: a wide curved guard and its inner wall — [VmCiv._tractor:1402](../scripts/game/vehicles/vm_civ.gd#L1402)
- the cab: floor, posts, white roof, glass all round — [VmCiv._tractor:1412](../scripts/game/vehicles/vm_civ.gd#L1412)
- inside: the seat and the wheel — [VmCiv._tractor:1435](../scripts/game/vehicles/vm_civ.gd#L1435)
- exhaust stack with its silencer and rain cap, the air intake — [VmCiv._tractor:1440](../scripts/game/vehicles/vm_civ.gd#L1440)
- steps on the left, the three-point hitch and the PTO at the back — [VmCiv._tractor:1446](../scripts/game/vehicles/vm_civ.gd#L1446)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._plate`, `VmCiv._rod`, `VmCiv._strut`, `VmCiv._xbody`.

### truck

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.exhaust`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.mudflap`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.ladder`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmCore._truck:1712](../scripts/game/vehicles/vm_core.gd#L1712)
- the chassis: frame rails, the axles and their diffs, the wheels — [VmCore._truck:1716](../scripts/game/vehicles/vm_core.gd#L1716)
- the bonnet, the flat wings over the front wheels with the headlights on them, the brush guard, the bumper and its tow hooks — [VmCore._truck:1723](../scripts/game/vehicles/vm_core.gd#L1723)
- the louvres down the bonnet's sides — [VmCore._truck:1734](../scripts/game/vehicles/vm_core.gd#L1734)
- the cab: its walls lofted up to the roof, the flat windscreen in two panes, door windows, the doors' seams, mirrors on their arms — [VmCore._truck:1741](../scripts/game/vehicles/vm_core.gd#L1741)
- behind the cab: the spare wheel standing up, the fuel tank, a tool box — [VmCore._truck:1756](../scripts/game/vehicles/vm_core.gd#L1756)
- the cargo bed: floor, sides and the tailgate, the canvas tilt on its bows, the rope lashing, tail lights, mudflaps and the pintle — [VmCore._truck:1760](../scripts/game/vehicles/vm_core.gd#L1760)
- Unlabelled construction / setup — [VmIndep._zamak:835](../scripts/game/vehicles/vm_indep.gd#L835)
- Unlabelled construction / setup — [VmNato._hemtt:1451](../scripts/game/vehicles/vm_nato.gd#L1451)
- drop sides and the headboard — [VmNato._hemtt:1461](../scripts/game/vehicles/vm_nato.gd#L1461)
- the canvas tilt over its bows, the back rolled up over the benches — [VmNato._hemtt:1470](../scripts/game/vehicles/vm_nato.gd#L1470)
- palletised crates and boxes lashed down, a tarp over one load — [VmNato._hemtt:1484](../scripts/game/vehicles/vm_nato.gd#L1484)
- ammunition: pallets of boxes, then the knuckle-boom crane at the back, folded forward over the load — [VmNato._hemtt:1495](../scripts/game/vehicles/vm_nato.gd#L1495)
- the shelter: a tall box body with a ribbed roof edge — [VmNato._hemtt:1519](../scripts/game/vehicles/vm_nato.gd#L1519)
- roll-up shutters with their slats, tool lockers below — [VmNato._hemtt:1526](../scripts/game/vehicles/vm_nato.gd#L1526)
- the light mast, AC unit, the rear door and ladder, a vice bench — [VmNato._hemtt:1533](../scripts/game/vehicles/vm_nato.gd#L1533)
- windows, the rear doors with a step, roof vents, red crosses — [VmNato._hemtt:1544](../scripts/game/vehicles/vm_nato.gd#L1544)
- the tank: an oval barrel on cradles, its end caps, the walkway on top with its rail, manholes, the pump cabinet and hose reels at the back — [VmNato._hemtt:1559](../scripts/game/vehicles/vm_nato.gd#L1559)
- the hazard placard — [VmNato._hemtt:1575](../scripts/game/vehicles/vm_nato.gd#L1575)

**Local helper construction:** `VmCiv._inset`, `VmCiv._yloft`, `VmCore._antenna`, `VmCore._bx`, `VmCore._lamp`, `VmCore._path`, `VmCore._shackle`, `VmCore._taillight`, `VmCore._tube`, `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`, `VmNato._antenna`, `VmNato._beam`, `VmNato._cargo`, `VmNato._cross`, `VmNato._extrude_z`, `VmNato._hemtt_cab_detail`, `VmNato._hemtt_cargo_detail`, `VmNato._hemtt_chassis`, `VmNato._hemtt_deck`, `VmNato._hemtt_load_detail`, `VmNato._hemtt_wheel`, `VmNato._ring_z`, `VmNato._shackle`, `VmNato._spare`, `VmNato._taillight`, `VmNato._team_mark`, `VmNato._tube`, `VmNato._zy`.

### van_ambulance, van_services, van_transport

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleCab.mesh_glass`, `VehicleFittings.headlamp`, `VehicleFittings.rectangular_headlamp`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.quad`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleSurface.quad`, `VehicleWheelArches.liner`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmCiv._van:832](../scripts/game/vehicles/vm_civ.gd#L832)
- the bonnet, and the body with the windscreen and the high roof — [VmCiv._van:847](../scripts/game/vehicles/vm_civ.gd#L847)
- windows: the cab doors always; the rest on the minibus, rear doors on all — [VmCiv._van:854](../scripts/game/vehicles/vm_civ.gd#L854)
- shut lines: cab door, and on the right the sliding door with its rail — [VmCiv._van:867](../scripts/game/vehicles/vm_civ.gd#L867)
- a black rubbing strip, the flares' lips, the tall tail lights — [VmCiv._van:871](../scripts/game/vehicles/vm_civ.gd#L871)
- rear doors: windows, hinges — [VmCiv._van:878](../scripts/game/vehicles/vm_civ.gd#L878)
- rear bumper with its step, plate — [VmCiv._van:890](../scripts/game/vehicles/vm_civ.gd#L890)
- the face: three slats and the star, big swept headlights, the bumper — [VmCiv._van:894](../scripts/game/vehicles/vm_civ.gd#L894)
- the big headlight: across the front corner and back along the wing — [VmCiv._van:902](../scripts/game/vehicles/vm_civ.gd#L902)

**Local helper construction:** `VmCiv._flare`, `VmCiv._lamp`, `VmCiv._mirror`, `VmCiv._paint`, `VmCiv._pane`, `VmCiv._plate`, `VmCiv._slab`, `VmCiv._strut`, `VmCiv._van_ambulance`, `VmCiv._van_services`, `VmCiv._xbody`.

### varsuk

**Shared:** `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleBody.skin`, `VehicleCloth.bag`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleEquipment.skirt`, `VehicleEquipment.storage`, `VehicleFittings.antenna`, `VehicleFittings.barrel`, `VehicleFittings.hatch`, `VehicleFittings.periscope`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.smoke_tube`, `VehicleFittings.tail_cluster`, `VehicleFittings.tow_shackle`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleTracks.shoes`, `VehicleWheels.road`.

**Authored sections:**

- Unlabelled construction / setup — [VmCsat._varsuk:918](../scripts/game/vehicles/vm_csat.gd#L918)
- the bustle: a long box hung off the turret's back — [VmCsat._varsuk:924](../scripts/game/vehicles/vm_csat.gd#L924)
- reactive armour on the cheeks either side of the mantlet, and on the roof — [VmCsat._varsuk:930](../scripts/game/vehicles/vm_csat.gd#L930)
- mantlet, gun, coax — [VmCsat._varsuk:935](../scripts/game/vehicles/vm_csat.gd#L935)
- commander's cupola (right) with the 12.7 mm, gunner's sight (left front) — [VmCsat._varsuk:941](../scripts/game/vehicles/vm_csat.gd#L941)
- Drozd launchers on the flanks, their radar heads on the cheeks, smoke — [VmCsat._varsuk:947](../scripts/game/vehicles/vm_csat.gd#L947)
- antennas at the bustle's back corners — [VmCsat._varsuk:956](../scripts/game/vehicles/vm_csat.gd#L956)
- stowage on the bustle's back, a wind sensor mast — [VmCsat._varsuk:958](../scripts/game/vehicles/vm_csat.gd#L958)

**Local helper construction:** `VmCsat._aim_y`, `VmCsat._antenna`, `VmCsat._cupola_mg`, `VmCsat._era`, `VmCsat._gun125`, `VmCsat._hatch`, `VmCsat._headlight`, `VmCsat._onface`, `VmCsat._periscope`, `VmCsat._plate`, `VmCsat._running_gear`, `VmCsat._rwheel`, `VmCsat._sec`, `VmCsat._smoke`, `VmCsat._sprocket`, `VmCsat._t100`, `VmCsat._taillight`, `VmCsat._tow`.

### water_scooter

**Shared:** `VehicleBody.paint_mesh`, `VehicleFrames.aim`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`.

**Authored sections:**

- Unlabelled construction / setup — [VmBoat._scooter:1116](../scripts/game/vehicles/vm_boat.gd#L1116)
- the bumper strake round the sheer and a livery band along each side — [VmBoat._scooter:1124](../scripts/game/vehicles/vm_boat.gd#L1124)
- low gunwale lips round the footwells — [VmBoat._scooter:1133](../scripts/game/vehicles/vm_boat.gd#L1133)
- sponsons near the stern — [VmBoat._scooter:1140](../scripts/game/vehicles/vm_boat.gd#L1140)
- the hood: a rounded dome rising from the bow to the handlebar pod — [VmBoat._scooter:1144](../scripts/game/vehicles/vm_boat.gd#L1144)
- the pedestal and the stepped three-place saddle on it — [VmBoat._scooter:1152](../scripts/game/vehicles/vm_boat.gd#L1152)
- footwell mats — [VmBoat._scooter:1167](../scripts/game/vehicles/vm_boat.gd#L1167)
- the boarding platform, its step and the grab handle behind the saddle — [VmBoat._scooter:1169](../scripts/game/vehicles/vm_boat.gd#L1169)
- jet nozzle and reverse gate under the stern, tow eyes at both ends — [VmBoat._scooter:1175](../scripts/game/vehicles/vm_boat.gd#L1175)
- the handlebar pod, bars and grips, a smoked visor, the display — [VmBoat._scooter:1181](../scripts/game/vehicles/vm_boat.gd#L1181)
- mirrors on stalks off the pod — [VmBoat._scooter:1186](../scripts/game/vehicles/vm_boat.gd#L1186)
- a strap across the pillion seat, grey panels down the pedestal's sides, air vents on the hood's shoulders, the fuel cap — [VmBoat._scooter:1193](../scripts/game/vehicles/vm_boat.gd#L1193)
- (on the hood's dome section at z = -0.75: half-width 0.495 from 0.464 up 0.441) — [VmBoat._scooter:1198](../scripts/game/vehicles/vm_boat.gd#L1198)
- the hood's storage hatch seam — [VmBoat._scooter:1204](../scripts/game/vehicles/vm_boat.gd#L1204)

**Local helper construction:** `VmBoat._band`, `VmBoat._band_mesh`, `VmBoat._beam`, `VmBoat._cushion`, `VmBoat._dome`, `VmBoat._hull`, `VmBoat._hw`, `VmBoat._rod`, `VmBoat._rr`, `VmBoat._rz`, `VmBoat._sheer`, `VmBoat._skin`, `VmBoat._station`, `VmBoat._stem`, `VmBoat._strip`, `VmBoat._top`, `VmBoat._u`.

### wipeout

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMarkings.polygons`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`.

**Authored sections:**

- Unlabelled construction / setup — [VmAttack._wipeout:816](../scripts/game/vehicles/vm_attack.gd#L816)
- [z, cx, cy, chine half-width, height above the chine, depth below, deck half-width, belly half-width, ridge] — [VmAttack._wipeout:820](../scripts/game/vehicles/vm_attack.gd#L820)
- panel joints: thin raised frames round the fuselage — [VmAttack._wipeout:839](../scripts/game/vehicles/vm_attack.gd#L839)

**Local helper construction:** `VmAttack._canopy_half`, `VmAttack._decal`, `VmAttack._facet`, `VmAttack._falchion`, `VmAttack._fbody`, `VmAttack._gear_nodes`, `VmAttack._hring`, `VmAttack._lathe`, `VmAttack._nac_half`, `VmAttack._sheet`, `VmAttack._star_bar`, `VmAttack._strokes`, `VmAttack._text`, `VmAttack._wheel`, `VmAttack._wing_y`, `VmAttack._wip_cockpit`, `VmAttack._wip_details`, `VmAttack._wip_engines`, `VmAttack._wip_gear`, `VmAttack._wip_gun`, `VmAttack._wip_stores`, `VmAttack._wip_tail`, `VmAttack._wip_wing`, `VmAttack._wst`, `VmAttack._zigzag`, `VmPlane._foil_t`, `VmPlane._sp`, `VmPlane._tri`, `VmPlane.agm`, `VmPlane.antenna`, `VmPlane.body`, `VmPlane.bomb`, `VmPlane.glow`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### xian

**Shared:** `VehicleAircraft.hardpoint`, `VehicleAircraft.rocket_pod`, `VehicleAirfoils.section`, `VehicleAirfoils.surface`, `VehicleAirfoils.thickness`, `VehicleBody.fastener`, `VehicleBody.paint_mesh`, `VehicleFittings.marker`, `VehicleFittings.signal_lens`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.tube`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehiclePropellers.disc_material`.

**Authored sections:**

- Unlabelled construction / setup — [VmPlane._xian:1433](../scripts/game/vehicles/vm_plane.gd#L1433)
- the stepped cockpit: the gunner's bubble low in front, the pilot's above — [VmPlane._xian:1453](../scripts/game/vehicles/vm_plane.gd#L1453)
- the chin turret: a twin 23 mm that traverses — [VmPlane._xian:1462](../scripts/game/vehicles/vm_plane.gd#L1462)
- troop doors on both sides, the rear ramp — [VmPlane._xian:1470](../scripts/game/vehicles/vm_plane.gd#L1470)
- the wings, a lift fan in each, ailerons outboard — [VmPlane._xian:1480](../scripts/game/vehicles/vm_plane.gd#L1480)
- wingtip pod with the lights — [VmPlane._xian:1488](../scripts/game/vehicles/vm_plane.gd#L1488)
- stub wings below, with their stores — [VmPlane._xian:1491](../scripts/game/vehicles/vm_plane.gd#L1491)
- twin turbofans high on the back, vectoring nozzles, a fairing between them — [VmPlane._xian:1506](../scripts/game/vehicles/vm_plane.gd#L1506)
- twin tails canted outboard of the engines, rudders — [VmPlane._xian:1520](../scripts/game/vehicles/vm_plane.gd#L1520)
- probes, antennas, the sensor under the nose — [VmPlane._xian:1522](../scripts/game/vehicles/vm_plane.gd#L1522)

**Local helper construction:** `VmPlane._mx`, `VmPlane._sp`, `VmPlane.antenna`, `VmPlane.band`, `VmPlane.body`, `VmPlane.glow`, `VmPlane.lift_fan`, `VmPlane.mouth`, `VmPlane.nav_lights`, `VmPlane.pylon`, `VmPlane.rocket_pod`, `VmPlane.rod`, `VmPlane.sec`, `VmPlane.skin`, `VmPlane.st_at`, `VmPlane.stripe`, `VmPlane.surf`, `VmPlane.surf_at`, `VmPlane.wing_marks`.

### zamak, zamak_ammo, zamak_cargo, zamak_fuel, zamak_medical, zamak_mrl, zamak_repair

**Shared:** `VehicleBody.boundary`, `VehicleBody.fastener`, `VehicleBody.fitted`, `VehicleBody.paint_mesh`, `VehicleBody.panel`, `VehicleCab.framed_face`, `VehicleCab.interior`, `VehicleCab.mesh_glass`, `VehicleCab.seat`, `VehicleCab.upper`, `VehicleCargo.pallet`, `VehicleCargo.restraints`, `VehicleCloth.canopy`, `VehicleCloth.load_cover`, `VehicleCloth.panel`, `VehicleDoors.closed`, `VehicleDoors.hinge`, `VehicleDoors.pull`, `VehicleDoors.rectangle`, `VehicleEquipment.vessel`, `VehicleFittings.antenna`, `VehicleFittings.grille`, `VehicleFittings.hatch`, `VehicleFittings.headlamp`, `VehicleFittings.jerrycan`, `VehicleFittings.mirror`, `VehicleFittings.rectangular_headlamp`, `VehicleFittings.signal_lens`, `VehicleFittings.tow_shackle`, `VehicleFittings.vent`, `VehicleFittings.wiper`, `VehicleFrames.aim`, `VehicleFrames.beam`, `VehicleFrames.path`, `VehicleFrames.railing`, `VehicleFrames.step`, `VehicleFrames.tube`, `VehicleGlazing.polygon`, `VehicleGlazing.rectangle`, `VehicleMaterials.key`, `VehicleMaterials.profile`, `VehicleProfiles.loft`, `VehicleProfiles.revolve`, `VehicleRunningGear.axle`, `VehicleRunningGear.frame`, `VehicleSurface.plane`, `VehicleSurface.quad`, `VehicleWheels.pneumatic`, `VehicleWheels.ring`, `VehicleWheels.spare`.

**Authored sections:**

- Unlabelled construction / setup — [VmIndep._zamak:835](../scripts/game/vehicles/vm_indep.gd#L835)

**Local helper construction:** `VmIndep._antenna`, `VmIndep._jerrycan`, `VmIndep._light`, `VmIndep._oct`, `VmIndep._paint`, `VmIndep._plate`, `VmIndep._ring`, `VmIndep._round_light`, `VmIndep._zamak_ammo`, `VmIndep._zamak_bed`, `VmIndep._zamak_box`, `VmIndep._zamak_cab`, `VmIndep._zamak_cargo`, `VmIndep._zamak_fuel`, `VmIndep._zamak_medical`, `VmIndep._zamak_mrl`, `VmIndep._zamak_repair`, `VmIndep._zamak_tilt`.

## Local helper section index

### VmAttack._a10_cockpit

- Unlabelled construction / setup — [VmAttack._a10_cockpit:364](../scripts/game/vehicles/vm_attack.gd#L364)
- the windscreen bow, the canopy's own front and rear frames — [VmAttack._a10_cockpit:375](../scripts/game/vehicles/vm_attack.gd#L375)
- the windscreen's two corner posts: a flat front panel and side quarter lights — [VmAttack._a10_cockpit:379](../scripts/game/vehicles/vm_attack.gd#L379)
- the canopy rails along both sills — [VmAttack._a10_cockpit:383](../scripts/game/vehicles/vm_attack.gd#L383)
- the fairing behind the canopy, down into the spine — [VmAttack._a10_cockpit:387](../scripts/game/vehicles/vm_attack.gd#L387)
- the refuelling receptacle (UARRSI) on the nose, its slipway lines — [VmAttack._a10_cockpit:392](../scripts/game/vehicles/vm_attack.gd#L392)
- the boarding ladder's door under the left canopy rail — [VmAttack._a10_cockpit:399](../scripts/game/vehicles/vm_attack.gd#L399)

### VmAttack._a10_details

- Unlabelled construction / setup — [VmAttack._a10_details:695](../scripts/game/vehicles/vm_attack.gd#L695)
- navigation lights on the Hoerner tips, the anti-collision strobes — [VmAttack._a10_details:696](../scripts/game/vehicles/vm_attack.gd#L696)
- the formation ("slime") lights: pale strips on the nose, the tail and fins — [VmAttack._a10_details:701](../scripts/game/vehicles/vm_attack.gd#L701)
- the chaff and flare dispensers under the wing tips — [VmAttack._a10_details:707](../scripts/game/vehicles/vm_attack.gd#L707)
- static dischargers trailing from the ailerons, the elevators and rudders — [VmAttack._a10_details:710](../scripts/game/vehicles/vm_attack.gd#L710)
- antennas: UHF/VHF blades on the spine and belly, the IFF and TACAN, a GPS dome — [VmAttack._a10_details:721](../scripts/game/vehicles/vm_attack.gd#L721)
- the angle-of-attack vane and a pitot probe on the nose's flanks — [VmAttack._a10_details:728](../scripts/game/vehicles/vm_attack.gd#L728)
- the false canopy painted under the nose — [VmAttack._a10_details:732](../scripts/game/vehicles/vm_attack.gd#L732)
- a Rebel airframe: their identification panels on the wings — [VmAttack._a10_details:741](../scripts/game/vehicles/vm_attack.gd#L741)
- the low-vis star-and-bar on the nacelles' outer flanks, the upper left and the lower right wing; "USAF" is left off at this size — [VmAttack._a10_details:744](../scripts/game/vehicles/vm_attack.gd#L744)
- "USAF" across the upper right wing and the lower left one, read from behind — [VmAttack._a10_details:758](../scripts/game/vehicles/vm_attack.gd#L758)

### VmAttack._a10_engines

- Unlabelled construction / setup — [VmAttack._a10_engines:481](../scripts/game/vehicles/vm_attack.gd#L481)
- inside the intake: the fan face, its blades and spinner — [VmAttack._a10_engines:499](../scripts/game/vehicles/vm_attack.gd#L499)
- the fan exhaust: the dark annulus between the core cowl and the nozzle — [VmAttack._a10_engines:506](../scripts/game/vehicles/vm_attack.gd#L506)
- cowling joints round the nacelle — [VmAttack._a10_engines:509](../scripts/game/vehicles/vm_attack.gd#L509)
- the pylon from the fuselage shoulder to the nacelle's inner flank — [VmAttack._a10_engines:512](../scripts/game/vehicles/vm_attack.gd#L512)

### VmAttack._a10_gear

- Unlabelled construction / setup — [VmAttack._a10_gear:572](../scripts/game/vehicles/vm_attack.gd#L572)
- the open well along the pod's belly the wheel hangs out of — [VmAttack._a10_gear:584](../scripts/game/vehicles/vm_attack.gd#L584)
- the chaff and flare dispensers in the pod's tail — [VmAttack._a10_gear:586](../scripts/game/vehicles/vm_attack.gd#L586)
- retracted: the tyre a third out of the pod — [VmAttack._a10_gear:588](../scripts/game/vehicles/vm_attack.gd#L588)
- let down: the wheel below and a little aft, the leg slanting from the pod's nose, its drag brace and torque links — [VmAttack._a10_gear:592](../scripts/game/vehicles/vm_attack.gd#L592)
- the nose gear well's doors (closed in flight) — [VmAttack._a10_gear:601](../scripts/game/vehicles/vm_attack.gd#L601)
- the taxi light on the leg — [VmAttack._a10_gear:616](../scripts/game/vehicles/vm_attack.gd#L616)
- the two long well doors hanging open — [VmAttack._a10_gear:618](../scripts/game/vehicles/vm_attack.gd#L618)

### VmAttack._a10_gun

- Unlabelled construction / setup — [VmAttack._a10_gun:407](../scripts/game/vehicles/vm_attack.gd#L407)
- the gun port: a dark recess in the nose's lower face — [VmAttack._a10_gun:408](../scripts/game/vehicles/vm_attack.gd#L408)
- the muzzle bore — [VmAttack._a10_gun:415](../scripts/game/vehicles/vm_attack.gd#L415)
- the barrel clamp and the mid support ring — [VmAttack._a10_gun:417](../scripts/game/vehicles/vm_attack.gd#L417)
- gun gas soot fanning back under the nose — [VmAttack._a10_gun:423](../scripts/game/vehicles/vm_attack.gd#L423)

### VmAttack._a10_stores

- Unlabelled construction / setup — [VmAttack._a10_stores:630](../scripts/game/vehicles/vm_attack.gd#L630)
- a Maverick on a single LAU-117 rail — [VmAttack._a10_stores:638](../scripts/game/vehicles/vm_attack.gd#L638)
- two Mavericks on the shoulders of a LAU-88 — [VmAttack._a10_stores:643](../scripts/game/vehicles/vm_attack.gd#L643)
- two Sidewinders on a LAU-105 dual rail — [VmAttack._a10_stores:656](../scripts/game/vehicles/vm_attack.gd#L656)
- the fuselage stations either side of the centre line, empty — [VmAttack._a10_stores:661](../scripts/game/vehicles/vm_attack.gd#L661)

### VmAttack._a10_tail

- Unlabelled construction / setup — [VmAttack._a10_tail:524](../scripts/game/vehicles/vm_attack.gd#L524)
- the elevator trim tabs — [VmAttack._a10_tail:528](../scripts/game/vehicles/vm_attack.gd#L528)
- the fin-tip cap and its tail light — [VmAttack._a10_tail:540](../scripts/game/vehicles/vm_attack.gd#L540)
- Moody's "FT" tail code, the serial and a black fin-tip band, both sides — [VmAttack._a10_tail:548](../scripts/game/vehicles/vm_attack.gd#L548)
- (the band runs from just behind the fin's leading edge to the rudder's end) — [VmAttack._a10_tail:560](../scripts/game/vehicles/vm_attack.gd#L560)

### VmAttack._a10_wing

- Unlabelled construction / setup — [VmAttack._a10_wing:439](../scripts/game/vehicles/vm_attack.gd#L439)
- the Hoerner tips: the skin curling down at the ends — [VmAttack._a10_wing:443](../scripts/game/vehicles/vm_attack.gd#L443)
- the deceleron split line along each aileron's trailing edge — [VmAttack._a10_wing:445](../scripts/game/vehicles/vm_attack.gd#L445)
- panel lines on the upper skins: the slat and leading-edge panels, the spar joints, the centre-section break, the walkway — [VmAttack._a10_wing:452](../scripts/game/vehicles/vm_attack.gd#L452)
- the black no-step walkway outline by the root — [VmAttack._a10_wing:469](../scripts/game/vehicles/vm_attack.gd#L469)

### VmAttack._canopy_half

- Unlabelled construction / setup — [VmAttack._canopy_half:892](../scripts/game/vehicles/vm_attack.gd#L892)

### VmAttack._decal

- Unlabelled construction / setup — [VmAttack._decal:130](../scripts/game/vehicles/vm_attack.gd#L130)

### VmAttack._ecm_pod

- Unlabelled construction / setup — [VmAttack._ecm_pod:682](../scripts/game/vehicles/vm_attack.gd#L682)
- the radomes darker — [VmAttack._ecm_pod:688](../scripts/game/vehicles/vm_attack.gd#L688)

### VmAttack._facet

- Unlabelled construction / setup — [VmAttack._facet:79](../scripts/game/vehicles/vm_attack.gd#L79)

### VmAttack._falchion

- Unlabelled construction / setup — [VmAttack._falchion:1138](../scripts/game/vehicles/vm_attack.gd#L1138)

### VmAttack._fbody

- Unlabelled construction / setup — [VmAttack._fbody:795](../scripts/game/vehicles/vm_attack.gd#L795)

### VmAttack._fin_at

- Unlabelled construction / setup — [VmAttack._fin_at:267](../scripts/game/vehicles/vm_attack.gd#L267)

### VmAttack._gear_nodes

- Unlabelled construction / setup — [VmAttack._gear_nodes:282](../scripts/game/vehicles/vm_attack.gd#L282)

### VmAttack._hring

- Unlabelled construction / setup — [VmAttack._hring:63](../scripts/game/vehicles/vm_attack.gd#L63)

### VmAttack._lathe

- Unlabelled construction / setup — [VmAttack._lathe:52](../scripts/game/vehicles/vm_attack.gd#L52)

### VmAttack._nac_half

- Unlabelled construction / setup — [VmAttack._nac_half:968](../scripts/game/vehicles/vm_attack.gd#L968)

### VmAttack._sec_pt

- Unlabelled construction / setup — [VmAttack._sec_pt:225](../scripts/game/vehicles/vm_attack.gd#L225)

### VmAttack._sheet

- Unlabelled construction / setup — [VmAttack._sheet:86](../scripts/game/vehicles/vm_attack.gd#L86)
- away from the axis (measured across the ring, not along it) — [VmAttack._sheet:107](../scripts/game/vehicles/vm_attack.gd#L107)

### VmAttack._skin_x

- Unlabelled construction / setup — [VmAttack._skin_x:247](../scripts/game/vehicles/vm_attack.gd#L247)

### VmAttack._skin_y

- Unlabelled construction / setup — [VmAttack._skin_y:236](../scripts/game/vehicles/vm_attack.gd#L236)

### VmAttack._sniper

- Unlabelled construction / setup — [VmAttack._sniper:669](../scripts/game/vehicles/vm_attack.gd#L669)
- the head's joint, its window looking forward and down — [VmAttack._sniper:673](../scripts/game/vehicles/vm_attack.gd#L673)

### VmAttack._star_bar

- Unlabelled construction / setup — [VmAttack._star_bar:193](../scripts/game/vehicles/vm_attack.gd#L193)
- the bars: upper edge level with the star's arms, a radius long beyond the ring — [VmAttack._star_bar:209](../scripts/game/vehicles/vm_attack.gd#L209)

### VmAttack._strokes

- Unlabelled construction / setup — [VmAttack._strokes:136](../scripts/game/vehicles/vm_attack.gd#L136)

### VmAttack._text

- Unlabelled construction / setup — [VmAttack._text:175](../scripts/game/vehicles/vm_attack.gd#L175)

### VmAttack._wheel

- Unlabelled construction / setup — [VmAttack._wheel:304](../scripts/game/vehicles/vm_attack.gd#L304)

### VmAttack._wing_y

- Unlabelled construction / setup — [VmAttack._wing_y:257](../scripts/game/vehicles/vm_attack.gd#L257)

### VmAttack._wip_cockpit

- Unlabelled construction / setup — [VmAttack._wip_cockpit:860](../scripts/game/vehicles/vm_attack.gd#L860)
- [z, base height, half-width, height] — [VmAttack._wip_cockpit:861](../scripts/game/vehicles/vm_attack.gd#L861)
- (a faint gold in the glass: the radar-reflective coating of a stealthy canopy) — [VmAttack._wip_cockpit:867](../scripts/game/vehicles/vm_attack.gd#L867)
- frames: the armoured pane's bow, a hoop over the middle — [VmAttack._wip_cockpit:869](../scripts/game/vehicles/vm_attack.gd#L869)
- the sills — [VmAttack._wip_cockpit:876](../scripts/game/vehicles/vm_attack.gd#L876)
- the spine: a faceted fairing from the canopy back between the engines — [VmAttack._wip_cockpit:882](../scripts/game/vehicles/vm_attack.gd#L882)
- the air-refuelling receptacle's door on the spine — [VmAttack._wip_cockpit:886](../scripts/game/vehicles/vm_attack.gd#L886)

### VmAttack._wip_details

- Unlabelled construction / setup — [VmAttack._wip_details:1150](../scripts/game/vehicles/vm_attack.gd#L1150)
- formation light strips along the chines — [VmAttack._wip_details:1154](../scripts/game/vehicles/vm_attack.gd#L1154)
- antennas on the spine and belly, the angle-of-attack probes — [VmAttack._wip_details:1160](../scripts/game/vehicles/vm_attack.gd#L1160)
- static dischargers on the wing tips — [VmAttack._wip_details:1170](../scripts/game/vehicles/vm_attack.gd#L1170)
- light grey low-vis markings: the star-and-bar on the fuselage's upper flanks and the left wing, a tail code and serial on the fins — [VmAttack._wip_details:1181](../scripts/game/vehicles/vm_attack.gd#L1181)
- the fin's outer skin, q.y up its span from the root: the airfoil's thickness there, at that point of the chord — [VmAttack._wip_details:1200](../scripts/game/vehicles/vm_attack.gd#L1200)

### VmAttack._wip_engines

- Unlabelled construction / setup — [VmAttack._wip_engines:976](../scripts/game/vehicles/vm_attack.gd#L976)
- the outer skin from the lip aft to the nozzle — [VmAttack._wip_engines:984](../scripts/game/vehicles/vm_attack.gd#L984)
- the inlet's lip and duct, the fan face inside — [VmAttack._wip_engines:988](../scripts/game/vehicles/vm_attack.gd#L988)
- the nozzle: its lip, the jet pipe's wall, the cone in it — [VmAttack._wip_engines:998](../scripts/game/vehicles/vm_attack.gd#L998)
- cowling seams — [VmAttack._wip_engines:1004](../scripts/game/vehicles/vm_attack.gd#L1004)
- the broad pylon blending the nacelle into the spine, tapered at both ends — [VmAttack._wip_engines:1009](../scripts/game/vehicles/vm_attack.gd#L1009)
- the ends drawn in towards the pylon's middle — [VmAttack._wip_engines:1020](../scripts/game/vehicles/vm_attack.gd#L1020)

### VmAttack._wip_gear

- Unlabelled construction / setup — [VmAttack._wip_gear:1059](../scripts/game/vehicles/vm_attack.gd#L1059)
- the doors' seams along the belly, saw-toothed fore and aft — [VmAttack._wip_gear:1070](../scripts/game/vehicles/vm_attack.gd#L1070)
- the pod's bay doors hanging open either side — [VmAttack._wip_gear:1084](../scripts/game/vehicles/vm_attack.gd#L1084)
- the nose gear on the centre line behind the gun fairing, its doors — [VmAttack._wip_gear:1087](../scripts/game/vehicles/vm_attack.gd#L1087)

### VmAttack._wip_gun

- Unlabelled construction / setup — [VmAttack._wip_gun:898](../scripts/game/vehicles/vm_attack.gd#L898)
- the EO/IR targeting turret under the nose, its window looking ahead — [VmAttack._wip_gun:912](../scripts/game/vehicles/vm_attack.gd#L912)

### VmAttack._wip_stores

- Unlabelled construction / setup — [VmAttack._wip_stores:1111](../scripts/game/vehicles/vm_attack.gd#L1111)
- three Macers on a triple rack: two on the shoulders, one below — [VmAttack._wip_stores:1119](../scripts/game/vehicles/vm_attack.gd#L1119)

### VmAttack._wip_tail

- Unlabelled construction / setup — [VmAttack._wip_tail:1034](../scripts/game/vehicles/vm_attack.gd#L1034)
- the fin-tip fairing with its light — [VmAttack._wip_tail:1048](../scripts/game/vehicles/vm_attack.gd#L1048)

### VmAttack._wip_wing

- Unlabelled construction / setup — [VmAttack._wip_wing:924](../scripts/game/vehicles/vm_attack.gd#L924)
- the leading-edge root extensions: thin faceted strakes running forward from the wing roots along the chines — [VmAttack._wip_wing:929](../scripts/game/vehicles/vm_attack.gd#L929)
- the deceleron split along the outer trailing edges — [VmAttack._wip_wing:934](../scripts/game/vehicles/vm_attack.gd#L934)
- the lighter grey under the wing — [VmAttack._wip_wing:940](../scripts/game/vehicles/vm_attack.gd#L940)
- panel lines on the upper skin — [VmAttack._wip_wing:950](../scripts/game/vehicles/vm_attack.gd#L950)

### VmAttack._wst

- Unlabelled construction / setup — [VmAttack._wst:777](../scripts/game/vehicles/vm_attack.gd#L777)

### VmAttack._zigzag

- Unlabelled construction / setup — [VmAttack._zigzag:155](../scripts/game/vehicles/vm_attack.gd#L155)

### VmBoat._aim

- Unlabelled construction / setup — [VmBoat._aim:278](../scripts/game/vehicles/vm_boat.gd#L278)

### VmBoat._bake

- Unlabelled construction / setup — [VmBoat._bake:443](../scripts/game/vehicles/vm_boat.gd#L443)

### VmBoat._band

- Unlabelled construction / setup — [VmBoat._band:156](../scripts/game/vehicles/vm_boat.gd#L156)

### VmBoat._band_mesh

- Unlabelled construction / setup — [VmBoat._band_mesh:187](../scripts/game/vehicles/vm_boat.gd#L187)

### VmBoat._beam

- Unlabelled construction / setup — [VmBoat._beam:148](../scripts/game/vehicles/vm_boat.gd#L148)

### VmBoat._cleat

- Unlabelled construction / setup — [VmBoat._cleat:386](../scripts/game/vehicles/vm_boat.gd#L386)

### VmBoat._cushion

- Unlabelled construction / setup — [VmBoat._cushion:1210](../scripts/game/vehicles/vm_boat.gd#L1210)

### VmBoat._deck_mesh

- Unlabelled construction / setup — [VmBoat._deck_mesh:201](../scripts/game/vehicles/vm_boat.gd#L201)

### VmBoat._dome

- Unlabelled construction / setup — [VmBoat._dome:1218](../scripts/game/vehicles/vm_boat.gd#L1218)
- At the last station rounding can put sin(PI) just below zero; a fractional power would make the hood's vertices and normals NaN. — [VmBoat._dome:1222](../scripts/game/vehicles/vm_boat.gd#L1222)

### VmBoat._foil

- Unlabelled construction / setup — [VmBoat._foil:257](../scripts/game/vehicles/vm_boat.gd#L257)

### VmBoat._hull

- Unlabelled construction / setup — [VmBoat._hull:121](../scripts/game/vehicles/vm_boat.gd#L121)

### VmBoat._hw

- Unlabelled construction / setup — [VmBoat._hw:131](../scripts/game/vehicles/vm_boat.gd#L131)

### VmBoat._offset

- Unlabelled construction / setup — [VmBoat._offset:322](../scripts/game/vehicles/vm_boat.gd#L322)

### VmBoat._outboard

- the clamp bracket on the transom and its tilt tube — [VmBoat._outboard:404](../scripts/game/vehicles/vm_boat.gd#L404)
- swivel bracket and the leg, a streamlined strut down to the gearcase — [VmBoat._outboard:415](../scripts/game/vehicles/vm_boat.gd#L415)
- anti-ventilation plate, the gearcase torpedo, skeg and propeller — [VmBoat._outboard:419](../scripts/game/vehicles/vm_boat.gd#L419)
- the lower cowl (apron), the cowling with its parting line and air intake — [VmBoat._outboard:425](../scripts/game/vehicles/vm_boat.gd#L425)

### VmBoat._panel

- Unlabelled construction / setup — [VmBoat._panel:364](../scripts/game/vehicles/vm_boat.gd#L364)

### VmBoat._prop

- Unlabelled construction / setup — [VmBoat._prop:391](../scripts/game/vehicles/vm_boat.gd#L391)

### VmBoat._pt

- Unlabelled construction / setup — [VmBoat._pt:381](../scripts/game/vehicles/vm_boat.gd#L381)

### VmBoat._resample

- Unlabelled construction / setup — [VmBoat._resample:303](../scripts/game/vehicles/vm_boat.gd#L303)

### VmBoat._rnd

- Unlabelled construction / setup — [VmBoat._rnd:244](../scripts/game/vehicles/vm_boat.gd#L244)

### VmBoat._rod

- Unlabelled construction / setup — [VmBoat._rod:288](../scripts/game/vehicles/vm_boat.gd#L288)

### VmBoat._rr

- Unlabelled construction / setup — [VmBoat._rr:235](../scripts/game/vehicles/vm_boat.gd#L235)

### VmBoat._ry

- Unlabelled construction / setup — [VmBoat._ry:229](../scripts/game/vehicles/vm_boat.gd#L229)

### VmBoat._rz

- Unlabelled construction / setup — [VmBoat._rz:221](../scripts/game/vehicles/vm_boat.gd#L221)

### VmBoat._scale_xz

- Unlabelled construction / setup — [VmBoat._scale_xz:1103](../scripts/game/vehicles/vm_boat.gd#L1103)

### VmBoat._sheer

- Unlabelled construction / setup — [VmBoat._sheer:105](../scripts/game/vehicles/vm_boat.gd#L105)

### VmBoat._skin

- Unlabelled construction / setup — [VmBoat._skin:176](../scripts/game/vehicles/vm_boat.gd#L176)

### VmBoat._slab

- Unlabelled construction / setup — [VmBoat._slab:196](../scripts/game/vehicles/vm_boat.gd#L196)

### VmBoat._sring

- Unlabelled construction / setup — [VmBoat._sring:265](../scripts/game/vehicles/vm_boat.gd#L265)

### VmBoat._station

- Unlabelled construction / setup — [VmBoat._station:70](../scripts/game/vehicles/vm_boat.gd#L70)
- extra points on the topsides at "marks" (depths below the sheer), so a painted stripe there lies on flat faces of the hull, not across them — [VmBoat._station:84](../scripts/game/vehicles/vm_boat.gd#L84)
- keep the section convex: a deep-V bow can't flare out above its chine, so there the chine eases onto the straight line from keel to sheer — [VmBoat._station:90](../scripts/game/vehicles/vm_boat.gd#L90)

### VmBoat._stem

- Unlabelled construction / setup — [VmBoat._stem:110](../scripts/game/vehicles/vm_boat.gd#L110)

### VmBoat._strip

- Unlabelled construction / setup — [VmBoat._strip:212](../scripts/game/vehicles/vm_boat.gd#L212)

### VmBoat._top

- Unlabelled construction / setup — [VmBoat._top:143](../scripts/game/vehicles/vm_boat.gd#L143)

### VmBoat._tube

- Unlabelled construction / setup — [VmBoat._tube:294](../scripts/game/vehicles/vm_boat.gd#L294)

### VmBoat._tube_kit

- Unlabelled construction / setup — [VmBoat._tube_kit:339](../scripts/game/vehicles/vm_boat.gd#L339)
- carrying handles on the inboard top — [VmBoat._tube_kit:354](../scripts/game/vehicles/vm_boat.gd#L354)

### VmBoat._u

- Unlabelled construction / setup — [VmBoat._u:116](../scripts/game/vehicles/vm_boat.gd#L116)

### VmCiv._bent

- Unlabelled construction / setup — [VmCiv._bent:180](../scripts/game/vehicles/vm_civ.gd#L180)

### VmCiv._car_details

- Unlabelled construction / setup — [VmCiv._car_details:1201](../scripts/game/vehicles/vm_civ.gd#L1201)

### VmCiv._face

- Unlabelled construction / setup — [VmCiv._face:141](../scripts/game/vehicles/vm_civ.gd#L141)

### VmCiv._flare

- Unlabelled construction / setup — [VmCiv._flare:103](../scripts/game/vehicles/vm_civ.gd#L103)

### VmCiv._glasshouse

- Unlabelled construction / setup — [VmCiv._glasshouse:1157](../scripts/game/vehicles/vm_civ.gd#L1157)
- Fill the complement of the actual window apertures, including the wide C-pillars. This preserves the coupe and pickup silhouettes. — [VmCiv._glasshouse:1184](../scripts/game/vehicles/vm_civ.gd#L1184)

### VmCiv._hatch_sport

- Unlabelled construction / setup — [VmCiv._hatch_sport:1134](../scripts/game/vehicles/vm_civ.gd#L1134)
- spoiler over the hatch on two stays, its end plates — [VmCiv._hatch_sport:1140](../scripts/game/vehicles/vm_civ.gd#L1140)

### VmCiv._inset

- Unlabelled construction / setup — [VmCiv._inset:79](../scripts/game/vehicles/vm_civ.gd#L79)

### VmCiv._jerrycan

- Unlabelled construction / setup — [VmCiv._jerrycan:215](../scripts/game/vehicles/vm_civ.gd#L215)

### VmCiv._lamp

- Unlabelled construction / setup — [VmCiv._lamp:193](../scripts/game/vehicles/vm_civ.gd#L193)

### VmCiv._lmg

- Unlabelled construction / setup — [VmCiv._lmg:250](../scripts/game/vehicles/vm_civ.gd#L250)
- 200-round box under the left of the receiver — [VmCiv._lmg:261](../scripts/game/vehicles/vm_civ.gd#L261)

### VmCiv._m2

- Unlabelled construction / setup — [VmCiv._m2:229](../scripts/game/vehicles/vm_civ.gd#L229)
- the ammo can on its tray, the belt up into the feed — [VmCiv._m2:241](../scripts/game/vehicles/vm_civ.gd#L241)

### VmCiv._mb_gun

- Unlabelled construction / setup — [VmCiv._mb_gun:643](../scripts/game/vehicles/vm_civ.gd#L643)
- ammunition stowed in the back — [VmCiv._mb_gun:647](../scripts/game/vehicles/vm_civ.gd#L647)

### VmCiv._mb_top

- Unlabelled construction / setup — [VmCiv._mb_top:624](../scripts/game/vehicles/vm_civ.gd#L624)
- the door frames the curtains zip into, the bows under the roof — [VmCiv._mb_top:634](../scripts/game/vehicles/vm_civ.gd#L634)

### VmCiv._mirror

- Unlabelled construction / setup — [VmCiv._mirror:208](../scripts/game/vehicles/vm_civ.gd#L208)

### VmCiv._off_at

- Unlabelled construction / setup — [VmCiv._off_at:446](../scripts/game/vehicles/vm_civ.gd#L446)
- a crate of rounds lashed in the bed — [VmCiv._off_at:453](../scripts/game/vehicles/vm_civ.gd#L453)

### VmCiv._off_hmg

- Unlabelled construction / setup — [VmCiv._off_hmg:416](../scripts/game/vehicles/vm_civ.gd#L416)
- ammo cans and a spare box by the gunner's feet — [VmCiv._off_hmg:422](../scripts/game/vehicles/vm_civ.gd#L422)
- the shield: a flat plate with the barrel slot, angled wings, a vision slit — [VmCiv._off_hmg:433](../scripts/game/vehicles/vm_civ.gd#L433)

### VmCiv._off_repair

- Unlabelled construction / setup — [VmCiv._off_repair:469](../scripts/game/vehicles/vm_civ.gd#L469)
- the davit: a post in the corner, a boom swung out over the tailgate — [VmCiv._off_repair:485](../scripts/game/vehicles/vm_civ.gd#L485)
- beacon on the roof — [VmCiv._off_repair:494](../scripts/game/vehicles/vm_civ.gd#L494)

### VmCiv._paint

- Unlabelled construction / setup — [VmCiv._paint:69](../scripts/game/vehicles/vm_civ.gd#L69)
- a little dust and sun on top of it — [VmCiv._paint:72](../scripts/game/vehicles/vm_civ.gd#L72)

### VmCiv._pane

- Unlabelled construction / setup — [VmCiv._pane:135](../scripts/game/vehicles/vm_civ.gd#L135)

### VmCiv._plate

- Unlabelled construction / setup — [VmCiv._plate:201](../scripts/game/vehicles/vm_civ.gd#L201)

### VmCiv._ring

- Unlabelled construction / setup — [VmCiv._ring:146](../scripts/game/vehicles/vm_civ.gd#L146)

### VmCiv._rod

- Unlabelled construction / setup — [VmCiv._rod:175](../scripts/game/vehicles/vm_civ.gd#L175)

### VmCiv._slab

- Unlabelled construction / setup — [VmCiv._slab:166](../scripts/game/vehicles/vm_civ.gd#L166)

### VmCiv._spare

- Unlabelled construction / setup — [VmCiv._spare:221](../scripts/game/vehicles/vm_civ.gd#L221)

### VmCiv._spg9

- Unlabelled construction / setup — [VmCiv._spg9:268](../scripts/game/vehicles/vm_civ.gd#L268)
- the thin forward tube, the fat chamber, the venturi flaring at the back — [VmCiv._spg9:269](../scripts/game/vehicles/vm_civ.gd#L269)
- clamping bands, the sight on the left, trigger group underneath — [VmCiv._spg9:276](../scripts/game/vehicles/vm_civ.gd#L276)
- the saddle the tube sits in — [VmCiv._spg9:283](../scripts/game/vehicles/vm_civ.gd#L283)

### VmCiv._strut

- Unlabelled construction / setup — [VmCiv._strut:160](../scripts/game/vehicles/vm_civ.gd#L160)

### VmCiv._team_side

- Unlabelled construction / setup — [VmCiv._team_side:502](../scripts/game/vehicles/vm_civ.gd#L502)

### VmCiv._truck_bed

- Unlabelled construction / setup — [VmCiv._truck_bed:749](../scripts/game/vehicles/vm_civ.gd#L749)
- headboard and a cab guard of bars — [VmCiv._truck_bed:754](../scripts/game/vehicles/vm_civ.gd#L754)
- dropsides on stake posts, the tailgate; their hinges and catches — [VmCiv._truck_bed:760](../scripts/game/vehicles/vm_civ.gd#L760)
- a bench with a back along the side — [VmCiv._truck_bed:768](../scripts/game/vehicles/vm_civ.gd#L768)

### VmCiv._truck_box

- Unlabelled construction / setup — [VmCiv._truck_box:782](../scripts/game/vehicles/vm_civ.gd#L782)
- barn doors: their seam, hinges and the locking bars — [VmCiv._truck_box:793](../scripts/game/vehicles/vm_civ.gd#L793)
- the wind deflector over the cab — [VmCiv._truck_box:801](../scripts/game/vehicles/vm_civ.gd#L801)

### VmCiv._truck_rear

- Unlabelled construction / setup — [VmCiv._truck_rear:810](../scripts/game/vehicles/vm_civ.gd#L810)

### VmCiv._van_ambulance

- Unlabelled construction / setup — [VmCiv._van_ambulance:929](../scripts/game/vehicles/vm_civ.gd#L929)
- the big cross on the roof — [VmCiv._van_ambulance:942](../scripts/game/vehicles/vm_civ.gd#L942)
- light bar: red lenses either side of white — [VmCiv._van_ambulance:945](../scripts/game/vehicles/vm_civ.gd#L945)

### VmCiv._van_services

- Unlabelled construction / setup — [VmCiv._van_services:955](../scripts/game/vehicles/vm_civ.gd#L955)
- roof rack rails on their feet — [VmCiv._van_services:960](../scripts/game/vehicles/vm_civ.gd#L960)
- the ladder — [VmCiv._van_services:966](../scripts/game/vehicles/vm_civ.gd#L966)
- amber beacon over the cab — [VmCiv._van_services:971](../scripts/game/vehicles/vm_civ.gd#L971)
- red and white chevrons on the lower rear doors — [VmCiv._van_services:974](../scripts/game/vehicles/vm_civ.gd#L974)

### VmCiv._xbody

- Unlabelled construction / setup — [VmCiv._xbody:99](../scripts/game/vehicles/vm_civ.gd#L99)

### VmCiv._yloft

- Unlabelled construction / setup — [VmCiv._yloft:109](../scripts/game/vehicles/vm_civ.gd#L109)

### VmCiv._zring

- Unlabelled construction / setup — [VmCiv._zring:152](../scripts/game/vehicles/vm_civ.gd#L152)

### VmCore._airframe

- Unlabelled construction / setup — [VmCore._airframe:1468](../scripts/game/vehicles/vm_core.gd#L1468)

### VmCore._ammo_can

- Unlabelled construction / setup — [VmCore._ammo_can:263](../scripts/game/vehicles/vm_core.gd#L263)

### VmCore._antenna

- Unlabelled construction / setup — [VmCore._antenna:220](../scripts/game/vehicles/vm_core.gd#L220)

### VmCore._bar

- Unlabelled construction / setup — [VmCore._bar:106](../scripts/game/vehicles/vm_core.gd#L106)

### VmCore._belt

- Unlabelled construction / setup — [VmCore._belt:199](../scripts/game/vehicles/vm_core.gd#L199)

### VmCore._bx

- Unlabelled construction / setup — [VmCore._bx:74](../scripts/game/vehicles/vm_core.gd#L74)

### VmCore._cam

- Unlabelled construction / setup — [VmCore._cam:64](../scripts/game/vehicles/vm_core.gd#L64)

### VmCore._dshk

- Unlabelled construction / setup — [VmCore._dshk:554](../scripts/game/vehicles/vm_core.gd#L554)

### VmCore._eye

- Unlabelled construction / setup — [VmCore._eye:269](../scripts/game/vehicles/vm_core.gd#L269)

### VmCore._fuel_tank

- Unlabelled construction / setup — [VmCore._fuel_tank:1589](../scripts/game/vehicles/vm_core.gd#L1589)

### VmCore._hatch

- Unlabelled construction / setup — [VmCore._hatch:251](../scripts/game/vehicles/vm_core.gd#L251)

### VmCore._hilux_dshk

- Unlabelled construction / setup — [VmCore._hilux_dshk:940](../scripts/game/vehicles/vm_core.gd#L940)
- kit in the bed: ammo boxes, the spare tyre, a jerrycan, a crate — [VmCore._hilux_dshk:947](../scripts/game/vehicles/vm_core.gd#L947)
- the traversing head: the yoke, the gun, the shield, a box on the cradle — [VmCore._hilux_dshk:954](../scripts/game/vehicles/vm_core.gd#L954)

### VmCore._idler

- Unlabelled construction / setup — [VmCore._idler:192](../scripts/game/vehicles/vm_core.gd#L192)

### VmCore._jerry

- Unlabelled construction / setup — [VmCore._jerry:257](../scripts/game/vehicles/vm_core.gd#L257)

### VmCore._lamp

- Unlabelled construction / setup — [VmCore._lamp:204](../scripts/game/vehicles/vm_core.gd#L204)

### VmCore._m2

- Unlabelled construction / setup — [VmCore._m2:279](../scripts/game/vehicles/vm_core.gd#L279)

### VmCore._mirror

- Unlabelled construction / setup — [VmCore._mirror:1782](../scripts/game/vehicles/vm_core.gd#L1782)

### VmCore._mmg

- Unlabelled construction / setup — [VmCore._mmg:299](../scripts/game/vehicles/vm_core.gd#L299)

### VmCore._oct

- Unlabelled construction / setup — [VmCore._oct:150](../scripts/game/vehicles/vm_core.gd#L150)

### VmCore._on_face

- Unlabelled construction / setup — [VmCore._on_face:123](../scripts/game/vehicles/vm_core.gd#L123)

### VmCore._path

- Unlabelled construction / setup — [VmCore._path:101](../scripts/game/vehicles/vm_core.gd#L101)

### VmCore._periscope

- Unlabelled construction / setup — [VmCore._periscope:245](../scripts/game/vehicles/vm_core.gd#L245)

### VmCore._rings

- Unlabelled construction / setup — [VmCore._rings:134](../scripts/game/vehicles/vm_core.gd#L134)

### VmCore._road_wheel

- Unlabelled construction / setup — [VmCore._road_wheel:157](../scripts/game/vehicles/vm_core.gd#L157)

### VmCore._round_ring

- Unlabelled construction / setup — [VmCore._round_ring:539](../scripts/game/vehicles/vm_core.gd#L539)

### VmCore._rz

- Unlabelled construction / setup — [VmCore._rz:142](../scripts/game/vehicles/vm_core.gd#L142)

### VmCore._shackle

- Unlabelled construction / setup — [VmCore._shackle:239](../scripts/game/vehicles/vm_core.gd#L239)

### VmCore._smoke

- Unlabelled construction / setup — [VmCore._smoke:227](../scripts/game/vehicles/vm_core.gd#L227)

### VmCore._sprocket

- Unlabelled construction / setup — [VmCore._sprocket:162](../scripts/game/vehicles/vm_core.gd#L162)

### VmCore._taillight

- Unlabelled construction / setup — [VmCore._taillight:214](../scripts/game/vehicles/vm_core.gd#L214)

### VmCore._tooth

- Unlabelled construction / setup — [VmCore._tooth:182](../scripts/game/vehicles/vm_core.gd#L182)

### VmCore._tube

- Unlabelled construction / setup — [VmCore._tube:96](../scripts/game/vehicles/vm_core.gd#L96)

### VmCore._zu23

- Unlabelled construction / setup — [VmCore._zu23:977](../scripts/game/vehicles/vm_core.gd#L977)
- loose kit in the corners: ammunition boxes, a jerrycan — [VmCore._zu23:982](../scripts/game/vehicles/vm_core.gd#L982)
- the side frames carrying the trunnions — [VmCore._zu23:990](../scripts/game/vehicles/vm_core.gd#L990)
- the cradle, raised a little, with both guns — [VmCore._zu23:993](../scripts/game/vehicles/vm_core.gd#L993)
- the ammunition box outboard of each gun, the spent-case chute under it — [VmCore._zu23:1004](../scripts/game/vehicles/vm_core.gd#L1004)
- the gunner's seat and his sight on the left, the hand wheels, the second seat on the right — [VmCore._zu23:1010](../scripts/game/vehicles/vm_core.gd#L1010)

### VmCore._zy

- Unlabelled construction / setup — [VmCore._zy:113](../scripts/game/vehicles/vm_core.gd#L113)

### VmCsat._aim_y

- Unlabelled construction / setup — [VmCsat._aim_y:98](../scripts/game/vehicles/vm_csat.gd#L98)

### VmCsat._antenna

- Unlabelled construction / setup — [VmCsat._antenna:156](../scripts/game/vehicles/vm_csat.gd#L156)

### VmCsat._arch

- Unlabelled construction / setup — [VmCsat._arch:128](../scripts/game/vehicles/vm_csat.gd#L128)

### VmCsat._cross

- Unlabelled construction / setup — [VmCsat._cross:1425](../scripts/game/vehicles/vm_csat.gd#L1425)

### VmCsat._cupola_mg

- Unlabelled construction / setup — [VmCsat._cupola_mg:901](../scripts/game/vehicles/vm_csat.gd#L901)

### VmCsat._era

- Unlabelled construction / setup — [VmCsat._era:549](../scripts/game/vehicles/vm_csat.gd#L549)

### VmCsat._gun125

- Unlabelled construction / setup — [VmCsat._gun125:892](../scripts/game/vehicles/vm_csat.gd#L892)

### VmCsat._hatch

- Unlabelled construction / setup — [VmCsat._hatch:173](../scripts/game/vehicles/vm_csat.gd#L173)

### VmCsat._headlight

- Unlabelled construction / setup — [VmCsat._headlight:139](../scripts/game/vehicles/vm_csat.gd#L139)

### VmCsat._jerrycan

- Unlabelled construction / setup — [VmCsat._jerrycan:167](../scripts/game/vehicles/vm_csat.gd#L167)

### VmCsat._mx

- Unlabelled construction / setup — [VmCsat._mx:89](../scripts/game/vehicles/vm_csat.gd#L89)

### VmCsat._onface

- Unlabelled construction / setup — [VmCsat._onface:486](../scripts/game/vehicles/vm_csat.gd#L486)

### VmCsat._pane

- Unlabelled construction / setup — [VmCsat._pane:120](../scripts/game/vehicles/vm_csat.gd#L120)

### VmCsat._periscope

- Unlabelled construction / setup — [VmCsat._periscope:179](../scripts/game/vehicles/vm_csat.gd#L179)

### VmCsat._plate

- Unlabelled construction / setup — [VmCsat._plate:114](../scripts/game/vehicles/vm_csat.gd#L114)

### VmCsat._rcws

- Unlabelled construction / setup — [VmCsat._rcws:197](../scripts/game/vehicles/vm_csat.gd#L197)
- the trunnion arms either side of the cradle — [VmCsat._rcws:200](../scripts/game/vehicles/vm_csat.gd#L200)
- the sight head beside the gun, the ammunition box on the other side — [VmCsat._rcws:229](../scripts/game/vehicles/vm_csat.gd#L229)

### VmCsat._running_gear

- Unlabelled construction / setup — [VmCsat._running_gear:521](../scripts/game/vehicles/vm_csat.gd#L521)

### VmCsat._rwheel

- Unlabelled construction / setup — [VmCsat._rwheel:498](../scripts/game/vehicles/vm_csat.gd#L498)

### VmCsat._rz

- Unlabelled construction / setup — [VmCsat._rz:81](../scripts/game/vehicles/vm_csat.gd#L81)

### VmCsat._sec

- Unlabelled construction / setup — [VmCsat._sec:75](../scripts/game/vehicles/vm_csat.gd#L75)

### VmCsat._slats

- Unlabelled construction / setup — [VmCsat._slats:1074](../scripts/game/vehicles/vm_csat.gd#L1074)

### VmCsat._smoke

- Unlabelled construction / setup — [VmCsat._smoke:186](../scripts/game/vehicles/vm_csat.gd#L186)

### VmCsat._sprocket

- Unlabelled construction / setup — [VmCsat._sprocket:503](../scripts/game/vehicles/vm_csat.gd#L503)

### VmCsat._stalker

- Unlabelled construction / setup — [VmCsat._stalker:675](../scripts/game/vehicles/vm_csat.gd#L675)
- side skirts in bolted sections, the front one angled up toward the sprocket — [VmCsat._stalker:685](../scripts/game/vehicles/vm_csat.gd#L685)
- the glacis: driver's hatch and periscopes front left, engine louvres front right, headlights in guards at the corners, tow hooks on the nose — [VmCsat._stalker:691](../scripts/game/vehicles/vm_csat.gd#L691)
- upper sides: stowage boxes and vision blocks, the exhaust on the right — [VmCsat._stalker:705](../scripts/game/vehicles/vm_csat.gd#L705)
- the rear: the troop door, its hinges and vision block, lights, stowage — [VmCsat._stalker:715](../scripts/game/vehicles/vm_csat.gd#L715)
- roof: the troop compartment's hatches behind the turret — [VmCsat._stalker:727](../scripts/game/vehicles/vm_csat.gd#L727)

### VmCsat._t100

- Unlabelled construction / setup — [VmCsat._t100:829](../scripts/game/vehicles/vm_csat.gd#L829)
- the glacis: a chevron of reactive armour plates, the driver's hatch and periscope at its top, headlights at its corners, tow hooks on the nose — [VmCsat._t100:839](../scripts/game/vehicles/vm_csat.gd#L839)
- fender shelves, the front mudguards — [VmCsat._t100:850](../scripts/game/vehicles/vm_csat.gd#L850)
- side skirts: reactive armour on the front three sections, rubber behind — [VmCsat._t100:856](../scripts/game/vehicles/vm_csat.gd#L856)
- stowage along the fenders behind the turret: bins left, fuel tanks right — [VmCsat._t100:866](../scripts/game/vehicles/vm_csat.gd#L866)
- engine deck: grilles and the access panels — [VmCsat._t100:873](../scripts/game/vehicles/vm_csat.gd#L873)
- the rear: the turbine's exhaust grille, the unditching beam, lights, hooks — [VmCsat._t100:878](../scripts/game/vehicles/vm_csat.gd#L878)

### VmCsat._t14

- Unlabelled construction / setup — [VmCsat._t14:1093](../scripts/game/vehicles/vm_csat.gd#L1093)
- the glacis: a grid of reactive armour blocks, the lights, tow hooks — [VmCsat._t14:1103](../scripts/game/vehicles/vm_csat.gd#L1103)
- the crew capsule: three hatches abreast, periscopes ahead of each — [VmCsat._t14:1115](../scripts/game/vehicles/vm_csat.gd#L1115)
- tall skirts: reactive armour forward, plain plates aft; slat cages round the engine bay — [VmCsat._t14:1121](../scripts/game/vehicles/vm_csat.gd#L1121)
- engine deck: grilles, the exhaust on the left, stowage boxes on the deck — [VmCsat._t14:1134](../scripts/game/vehicles/vm_csat.gd#L1134)

### VmCsat._taillight

- Unlabelled construction / setup — [VmCsat._taillight:150](../scripts/game/vehicles/vm_csat.gd#L150)

### VmCsat._tempest_box

- Unlabelled construction / setup — [VmCsat._tempest_box:1418](../scripts/game/vehicles/vm_csat.gd#L1418)

### VmCsat._tempest_flatbed

- Unlabelled construction / setup — [VmCsat._tempest_flatbed:1402](../scripts/game/vehicles/vm_csat.gd#L1402)

### VmCsat._tow

- Unlabelled construction / setup — [VmCsat._tow:161](../scripts/game/vehicles/vm_csat.gd#L161)

### VmCsat._tube

- Unlabelled construction / setup — [VmCsat._tube:108](../scripts/game/vehicles/vm_csat.gd#L108)

### VmCsat._typhoon

- Unlabelled construction / setup — [VmCsat._typhoon:1219](../scripts/game/vehicles/vm_csat.gd#L1219)
- the bumper block under the cab's nose — [VmCsat._typhoon:1231](../scripts/game/vehicles/vm_csat.gd#L1231)
- the windscreen: two big flat panes, a pillar between them — [VmCsat._typhoon:1233](../scripts/game/vehicles/vm_csat.gd#L1233)
- the grille on the cab front, headlights and tow hooks in the bumper — [VmCsat._typhoon:1238](../scripts/game/vehicles/vm_csat.gd#L1238)
- door window and the small one behind it, the door seam and handle — [VmCsat._typhoon:1245](../scripts/game/vehicles/vm_csat.gd#L1245)
- the step ladder under the door, behind the front wheel — [VmCsat._typhoon:1248](../scripts/game/vehicles/vm_csat.gd#L1248)
- mirrors on long arms — [VmCsat._typhoon:1250](../scripts/game/vehicles/vm_csat.gd#L1250)
- the front wheel under its faceted arch, the rear tandem — [VmCsat._typhoon:1252](../scripts/game/vehicles/vm_csat.gd#L1252)
- the rear tandem's mudguard — [VmCsat._typhoon:1258](../scripts/game/vehicles/vm_csat.gd#L1258)
- fuel tank and battery box on the frame, the exhaust stack behind the cab — [VmCsat._typhoon:1261](../scripts/game/vehicles/vm_csat.gd#L1261)
- the rear underrun bar — [VmCsat._typhoon:1265](../scripts/game/vehicles/vm_csat.gd#L1265)
- roof: hatch, antennas, a light — [VmCsat._typhoon:1267](../scripts/game/vehicles/vm_csat.gd#L1267)

### VmFighter._aim120

- Unlabelled construction / setup — [VmFighter._aim120:933](../scripts/game/vehicles/vm_fighter.gd#L933)

### VmFighter._aim9x

- Unlabelled construction / setup — [VmFighter._aim9x:917](../scripts/game/vehicles/vm_fighter.gd#L917)

### VmFighter._alq184

- Unlabelled construction / setup — [VmFighter._alq184:967](../scripts/game/vehicles/vm_fighter.gd#L967)

### VmFighter._awheel

- Unlabelled construction / setup — [VmFighter._awheel:654](../scripts/game/vehicles/vm_fighter.gd#L654)

### VmFighter._burner

- Unlabelled construction / setup — [VmFighter._burner:409](../scripts/game/vehicles/vm_fighter.gd#L409)

### VmFighter._bw_half

- Unlabelled construction / setup — [VmFighter._bw_half:984](../scripts/game/vehicles/vm_fighter.gd#L984)

### VmFighter._ccr

- Unlabelled construction / setup — [VmFighter._ccr:258](../scripts/game/vehicles/vm_fighter.gd#L258)

### VmFighter._circle2

- Unlabelled construction / setup — [VmFighter._circle2:431](../scripts/game/vehicles/vm_fighter.gd#L431)

### VmFighter._cloop

- Unlabelled construction / setup — [VmFighter._cloop:340](../scripts/game/vehicles/vm_fighter.gd#L340)

### VmFighter._decal

- Unlabelled construction / setup — [VmFighter._decal:455](../scripts/game/vehicles/vm_fighter.gd#L455)

### VmFighter._dense

- Unlabelled construction / setup — [VmFighter._dense:242](../scripts/game/vehicles/vm_fighter.gd#L242)

### VmFighter._duct

- Unlabelled construction / setup — [VmFighter._duct:370](../scripts/game/vehicles/vm_fighter.gd#L370)

### VmFighter._f16_half

- Unlabelled construction / setup — [VmFighter._f16_half:671](../scripts/game/vehicles/vm_fighter.gd#L671)

### VmFighter._ft

- Unlabelled construction / setup — [VmFighter._ft:419](../scripts/game/vehicles/vm_fighter.gd#L419)

### VmFighter._gbu31

- Unlabelled construction / setup — [VmFighter._gbu31:895](../scripts/game/vehicles/vm_fighter.gd#L895)
- strakes: either side and below — [VmFighter._gbu31:902](../scripts/game/vehicles/vm_fighter.gd#L902)
- the tail kit's fins (X) — [VmFighter._gbu31:906](../scripts/game/vehicles/vm_fighter.gd#L906)

### VmFighter._gear_node

- Unlabelled construction / setup — [VmFighter._gear_node:645](../scripts/game/vehicles/vm_fighter.gd#L645)

### VmFighter._glaze

- Unlabelled construction / setup — [VmFighter._glaze:188](../scripts/game/vehicles/vm_fighter.gd#L188)

### VmFighter._hband

- Unlabelled construction / setup — [VmFighter._hband:312](../scripts/game/vehicles/vm_fighter.gd#L312)

### VmFighter._hull

- Unlabelled construction / setup — [VmFighter._hull:301](../scripts/game/vehicles/vm_fighter.gd#L301)

### VmFighter._hwrap

- Unlabelled construction / setup — [VmFighter._hwrap:475](../scripts/game/vehicles/vm_fighter.gd#L475)

### VmFighter._insignia

- Unlabelled construction / setup — [VmFighter._insignia:540](../scripts/game/vehicles/vm_fighter.gd#L540)

### VmFighter._leg

- Unlabelled construction / setup — [VmFighter._leg:664](../scripts/game/vehicles/vm_fighter.gd#L664)

### VmFighter._lines

- Unlabelled construction / setup — [VmFighter._lines:602](../scripts/game/vehicles/vm_fighter.gd#L602)

### VmFighter._loop

- Unlabelled construction / setup — [VmFighter._loop:292](../scripts/game/vehicles/vm_fighter.gd#L292)

### VmFighter._mesh

- Unlabelled construction / setup — [VmFighter._mesh:150](../scripts/game/vehicles/vm_fighter.gd#L150)

### VmFighter._mixloop

- Unlabelled construction / setup — [VmFighter._mixloop:349](../scripts/game/vehicles/vm_fighter.gd#L349)

### VmFighter._msecs

- Unlabelled construction / setup — [VmFighter._msecs:529](../scripts/game/vehicles/vm_fighter.gd#L529)

### VmFighter._outline

- Unlabelled construction / setup — [VmFighter._outline:635](../scripts/game/vehicles/vm_fighter.gd#L635)

### VmFighter._petals

- Unlabelled construction / setup — [VmFighter._petals:378](../scripts/game/vehicles/vm_fighter.gd#L378)

### VmFighter._pipe

- Unlabelled construction / setup — [VmFighter._pipe:389](../scripts/game/vehicles/vm_fighter.gd#L389)

### VmFighter._poly_mesh

- Unlabelled construction / setup — [VmFighter._poly_mesh:164](../scripts/game/vehicles/vm_fighter.gd#L164)

### VmFighter._project

- Unlabelled construction / setup — [VmFighter._project:466](../scripts/game/vehicles/vm_fighter.gd#L466)

### VmFighter._put

- Unlabelled construction / setup — [VmFighter._put:182](../scripts/game/vehicles/vm_fighter.gd#L182)

### VmFighter._qloop

- Unlabelled construction / setup — [VmFighter._qloop:328](../scripts/game/vehicles/vm_fighter.gd#L328)

### VmFighter._rect2

- Unlabelled construction / setup — [VmFighter._rect2:439](../scripts/game/vehicles/vm_fighter.gd#L439)

### VmFighter._ring

- Unlabelled construction / setup — [VmFighter._ring:274](../scripts/game/vehicles/vm_fighter.gd#L274)

### VmFighter._rows

- Unlabelled construction / setup — [VmFighter._rows:207](../scripts/game/vehicles/vm_fighter.gd#L207)

### VmFighter._skin

- Unlabelled construction / setup — [VmFighter._skin:52](../scripts/game/vehicles/vm_fighter.gd#L52)
- a degenerate quad (a pointed nose): face along the section's radius — [VmFighter._skin:83](../scripts/game/vehicles/vm_fighter.gd#L83)

### VmFighter._slab

- Unlabelled construction / setup — [VmFighter._slab:176](../scripts/game/vehicles/vm_fighter.gd#L176)

### VmFighter._sniper

- Unlabelled construction / setup — [VmFighter._sniper:949](../scripts/game/vehicles/vm_fighter.gd#L949)
- the rotating head: a faceted nose, its window — [VmFighter._sniper:952](../scripts/game/vehicles/vm_fighter.gd#L952)

### VmFighter._star2

- Unlabelled construction / setup — [VmFighter._star2:444](../scripts/game/vehicles/vm_fighter.gd#L444)

### VmFighter._surf

- Unlabelled construction / setup — [VmFighter._surf:425](../scripts/game/vehicles/vm_fighter.gd#L425)

### VmFighter._tan

- Unlabelled construction / setup — [VmFighter._tan:234](../scripts/game/vehicles/vm_fighter.gd#L234)

### VmFighter._text

- Unlabelled construction / setup — [VmFighter._text:569](../scripts/game/vehicles/vm_fighter.gd#L569)

### VmFighter._tri

- Unlabelled construction / setup — [VmFighter._tri:138](../scripts/game/vehicles/vm_fighter.gd#L138)

### VmFighter._vn

- Unlabelled construction / setup — [VmFighter._vn:124](../scripts/game/vehicles/vm_fighter.gd#L124)

### VmFighter._wrap

- Unlabelled construction / setup — [VmFighter._wrap:504](../scripts/game/vehicles/vm_fighter.gd#L504)

### VmFighter._zigzag

- Unlabelled construction / setup — [VmFighter._zigzag:622](../scripts/game/vehicles/vm_fighter.gd#L622)

### VmGunship._ac130_cockpit

- Unlabelled construction / setup — [VmGunship._ac130_cockpit:450](../scripts/game/vehicles/vm_gunship.gd#L450)
- the windscreen: five panes across the steep front of the flight deck, framed; its top and bottom rails — [VmGunship._ac130_cockpit:451](../scripts/game/vehicles/vm_gunship.gd#L451)
- two side windows each side, the eyebrow windows over them — [VmGunship._ac130_cockpit:461](../scripts/game/vehicles/vm_gunship.gd#L461)
- the chin window low in the nose beside the nose gear — [VmGunship._ac130_cockpit:468](../scripts/game/vehicles/vm_gunship.gd#L468)
- the pitot tubes — [VmGunship._ac130_cockpit:471](../scripts/game/vehicles/vm_gunship.gd#L471)
- the air-refuelling receptacle (UARRSI) on the roof and its slipway — [VmGunship._ac130_cockpit:476](../scripts/game/vehicles/vm_gunship.gd#L476)

### VmGunship._ac130_doors

- Unlabelled construction / setup — [VmGunship._ac130_doors:487](../scripts/game/vehicles/vm_gunship.gd#L487)
- the ramp and cargo door: seams along the lower sides of the upsweep and across it at the hinge, the ramp's end and the door's top — [VmGunship._ac130_doors:496](../scripts/game/vehicles/vm_gunship.gd#L496)

### VmGunship._ac130_gear

- Unlabelled construction / setup — [VmGunship._ac130_gear:613](../scripts/game/vehicles/vm_gunship.gd#L613)
- the nose gear: the strut, its torque links, the twin wheels, the doors — [VmGunship._ac130_gear:616](../scripts/game/vehicles/vm_gunship.gd#L616)
- the main gear: the open wells, a strut and wheel at each station — [VmGunship._ac130_gear:623](../scripts/game/vehicles/vm_gunship.gd#L623)

### VmGunship._ac130_guns

- Unlabelled construction / setup — [VmGunship._ac130_guns:558](../scripts/game/vehicles/vm_gunship.gd#L558)
- the 25 mm GAU-12 Equalizer — [VmGunship._ac130_guns:560](../scripts/game/vehicles/vm_gunship.gd#L560)
- the 40 mm L/60 Bofors — [VmGunship._ac130_guns:572](../scripts/game/vehicles/vm_gunship.gd#L572)
- (the mount's shield in the port, the cooling jacket, the barrel, the conical flash hider) — [VmGunship._ac130_guns:575](../scripts/game/vehicles/vm_gunship.gd#L575)
- the 105 mm M102 howitzer — [VmGunship._ac130_guns:583](../scripts/game/vehicles/vm_gunship.gd#L583)
- (the cradle in the port, the recoil sleeve, the barrel, the double-baffle muzzle brake with its side ports) — [VmGunship._ac130_guns:586](../scripts/game/vehicles/vm_gunship.gd#L586)
- the AN/AAQ-117 infrared turret under the nose, the ALLTV turret in the front of the left sponson — [VmGunship._ac130_guns:598](../scripts/game/vehicles/vm_gunship.gd#L598)

### VmGunship._ang

- Unlabelled construction / setup — [VmGunship._ang:76](../scripts/game/vehicles/vm_gunship.gd#L76)

### VmGunship._bf_cockpit

- Unlabelled construction / setup — [VmGunship._bf_cockpit:742](../scripts/game/vehicles/vm_gunship.gd#L742)

### VmGunship._bf_doors

- Unlabelled construction / setup — [VmGunship._bf_doors:762](../scripts/game/vehicles/vm_gunship.gd#L762)

### VmGunship._bf_gear

- Unlabelled construction / setup — [VmGunship._bf_gear:874](../scripts/game/vehicles/vm_gunship.gd#L874)

### VmGunship._bf_guns

- Unlabelled construction / setup — [VmGunship._bf_guns:824](../scripts/game/vehicles/vm_gunship.gd#L824)
- the 40 mm — [VmGunship._bf_guns:827](../scripts/game/vehicles/vm_gunship.gd#L827)
- the 105 mm and the 20 mm in the aft mount — [VmGunship._bf_guns:838](../scripts/game/vehicles/vm_gunship.gd#L838)
- the gunners' second sensor turret — [VmGunship._bf_guns:865](../scripts/game/vehicles/vm_gunship.gd#L865)

### VmGunship._bf_nacelle

- Unlabelled construction / setup — [VmGunship._bf_nacelle:778](../scripts/game/vehicles/vm_gunship.gd#L778)
- the engine's intake scoop on top, dark inside — [VmGunship._bf_nacelle:792](../scripts/game/vehicles/vm_gunship.gd#L792)
- cooling grilles either side, the exhaust — [VmGunship._bf_nacelle:796](../scripts/game/vehicles/vm_gunship.gd#L796)
- the navigation light, green on the right, red on the left — [VmGunship._bf_nacelle:802](../scripts/game/vehicles/vm_gunship.gd#L802)

### VmGunship._bf_tail

- Unlabelled construction / setup — [VmGunship._bf_tail:810](../scripts/game/vehicles/vm_gunship.gd#L810)

### VmGunship._decal

- Unlabelled construction / setup — [VmGunship._decal:191](../scripts/game/vehicles/vm_gunship.gd#L191)

### VmGunship._dmesh

- Unlabelled construction / setup — [VmGunship._dmesh:257](../scripts/game/vehicles/vm_gunship.gd#L257)
- (Godot's front faces wind clockwise, seen from their normal's side) — [VmGunship._dmesh:261](../scripts/game/vehicles/vm_gunship.gd#L261)

### VmGunship._door

- Unlabelled construction / setup — [VmGunship._door:103](../scripts/game/vehicles/vm_gunship.gd#L103)

### VmGunship._fin_at

- Unlabelled construction / setup — [VmGunship._fin_at:277](../scripts/game/vehicles/vm_gunship.gd#L277)

### VmGunship._gear_node

- Unlabelled construction / setup — [VmGunship._gear_node:65](../scripts/game/vehicles/vm_gunship.gd#L65)

### VmGunship._half_w

- Unlabelled construction / setup — [VmGunship._half_w:87](../scripts/game/vehicles/vm_gunship.gd#L87)

### VmGunship._insignia_tris

- Unlabelled construction / setup — [VmGunship._insignia_tris:133](../scripts/game/vehicles/vm_gunship.gd#L133)
- the star, its points just inside the circle — [VmGunship._insignia_tris:134](../scripts/game/vehicles/vm_gunship.gd#L134)
- the circle, broken where the bars join it — [VmGunship._insignia_tris:141](../scripts/game/vehicles/vm_gunship.gd#L141)

### VmGunship._patch

- Unlabelled construction / setup — [VmGunship._patch:96](../scripts/game/vehicles/vm_gunship.gd#L96)

### VmGunship._propeller

- Unlabelled construction / setup — [VmGunship._propeller:124](../scripts/game/vehicles/vm_gunship.gd#L124)

### VmGunship._ribbon

- Unlabelled construction / setup — [VmGunship._ribbon:164](../scripts/game/vehicles/vm_gunship.gd#L164)

### VmGunship._seam

- Unlabelled construction / setup — [VmGunship._seam:249](../scripts/game/vehicles/vm_gunship.gd#L249)

### VmGunship._shift

- Unlabelled construction / setup — [VmGunship._shift:547](../scripts/game/vehicles/vm_gunship.gd#L547)

### VmGunship._t56

- Unlabelled construction / setup — [VmGunship._t56:509](../scripts/game/vehicles/vm_gunship.gd#L509)
- a tall oval behind the spinner (the intake under it), the top running back into the wing's leading edge, the deep belly, the tail fairing — [VmGunship._t56:511](../scripts/game/vehicles/vm_gunship.gd#L511)
- the cowl's panel joints — [VmGunship._t56:527](../scripts/game/vehicles/vm_gunship.gd#L527)
- the engine and oil-cooler intake under the spinner: a lip standing proud of the cowl's face, dark inside — [VmGunship._t56:531](../scripts/game/vehicles/vm_gunship.gd#L531)
- the exhaust: a short pipe out of the outboard side of the nacelle under the trailing edge, soot streaked aft of it — [VmGunship._t56:536](../scripts/game/vehicles/vm_gunship.gd#L536)

### VmGunship._text_tris

- Unlabelled construction / setup — [VmGunship._text_tris:297](../scripts/game/vehicles/vm_gunship.gd#L297)
- (each stroke runs a little past its ends to close the corners) — [VmGunship._text_tris:313](../scripts/game/vehicles/vm_gunship.gd#L313)

### VmGunship._tyre

- Unlabelled construction / setup — [VmGunship._tyre:114](../scripts/game/vehicles/vm_gunship.gd#L114)

### VmGunship._under

- Unlabelled construction / setup — [VmGunship._under:893](../scripts/game/vehicles/vm_gunship.gd#L893)

### VmGunship._wing_lines

- Unlabelled construction / setup — [VmGunship._wing_lines:227](../scripts/game/vehicles/vm_gunship.gd#L227)

### VmHeli._air

- Unlabelled construction / setup — [VmHeli._air:246](../scripts/game/vehicles/vm_heli.gd#L246)

### VmHeli._atgm_tubes

- Unlabelled construction / setup — [VmHeli._atgm_tubes:1032](../scripts/game/vehicles/vm_heli.gd#L1032)

### VmHeli._canopy

- Unlabelled construction / setup — [VmHeli._canopy:1018](../scripts/game/vehicles/vm_heli.gd#L1018)

### VmHeli._ducted_fin

- Unlabelled construction / setup — [VmHeli._ducted_fin:270](../scripts/game/vehicles/vm_heli.gd#L270)
- the outline's corners inside this wedge, in angular order — [VmHeli._ducted_fin:279](../scripts/game/vehicles/vm_heli.gd#L279)

### VmHeli._fan

- Unlabelled construction / setup — [VmHeli._fan:311](../scripts/game/vehicles/vm_heli.gd#L311)
- unevenly spaced, as on the real fans (it spreads the noise) — [VmHeli._fan:314](../scripts/game/vehicles/vm_heli.gd#L314)

### VmHeli._gear

- Unlabelled construction / setup — [VmHeli._gear:344](../scripts/game/vehicles/vm_heli.gd#L344)

### VmHeli._hellfires

- Unlabelled construction / setup — [VmHeli._hellfires:387](../scripts/game/vehicles/vm_heli.gd#L387)

### VmHeli._hull

- Unlabelled construction / setup — [VmHeli._hull:181](../scripts/game/vehicles/vm_heli.gd#L181)
- Panel joins follow the authored skin; glazing sits above them, so seams cannot cut across a cockpit pane or change the hull outline. — [VmHeli._hull:186](../scripts/game/vehicles/vm_heli.gd#L186)

### VmHeli._minigun

- Unlabelled construction / setup — [VmHeli._minigun:360](../scripts/game/vehicles/vm_heli.gd#L360)

### VmHeli._missile

- Unlabelled construction / setup — [VmHeli._missile:378](../scripts/game/vehicles/vm_heli.gd#L378)

### VmHeli._mx

- Unlabelled construction / setup — [VmHeli._mx:1009](../scripts/game/vehicles/vm_heli.gd#L1009)

### VmHeli._patch

- Unlabelled construction / setup — [VmHeli._patch:206](../scripts/game/vehicles/vm_heli.gd#L206)

### VmHeli._path

- Unlabelled construction / setup — [VmHeli._path:234](../scripts/game/vehicles/vm_heli.gd#L234)

### VmHeli._prop

- Unlabelled construction / setup — [VmHeli._prop:1419](../scripts/game/vehicles/vm_heli.gd#L1419)

### VmHeli._ray_hit

- Unlabelled construction / setup — [VmHeli._ray_hit:294](../scripts/game/vehicles/vm_heli.gd#L294)

### VmHeli._rbox

- Unlabelled construction / setup — [VmHeli._rbox:240](../scripts/game/vehicles/vm_heli.gd#L240)

### VmHeli._rocket_pod

- Unlabelled construction / setup — [VmHeli._rocket_pod:373](../scripts/game/vehicles/vm_heli.gd#L373)

### VmHeli._rotor

- Unlabelled construction / setup — [VmHeli._rotor:259](../scripts/game/vehicles/vm_heli.gd#L259)

### VmHeli._rz

- Unlabelled construction / setup — [VmHeli._rz:221](../scripts/game/vehicles/vm_heli.gd#L221)

### VmHeli._skids

- Unlabelled construction / setup — [VmHeli._skids:326](../scripts/game/vehicles/vm_heli.gd#L326)
- wear shoes under the skid — [VmHeli._skids:333](../scripts/game/vehicles/vm_heli.gd#L333)

### VmHeli._tail_rotor

- Unlabelled construction / setup — [VmHeli._tail_rotor:263](../scripts/game/vehicles/vm_heli.gd#L263)

### VmHeli._tube

- Unlabelled construction / setup — [VmHeli._tube:229](../scripts/game/vehicles/vm_heli.gd#L229)

### VmIndep._antenna

- Unlabelled construction / setup — [VmIndep._antenna:121](../scripts/game/vehicles/vm_indep.gd#L121)

### VmIndep._idler

- Unlabelled construction / setup — [VmIndep._idler:138](../scripts/game/vehicles/vm_indep.gd#L138)

### VmIndep._jerrycan

- Unlabelled construction / setup — [VmIndep._jerrycan:126](../scripts/game/vehicles/vm_indep.gd#L126)

### VmIndep._light

- Unlabelled construction / setup — [VmIndep._light:87](../scripts/game/vehicles/vm_indep.gd#L87)

### VmIndep._nyx_m2

- Unlabelled construction / setup — [VmIndep._nyx_m2:710](../scripts/game/vehicles/vm_indep.gd#L710)

### VmIndep._oct

- Unlabelled construction / setup — [VmIndep._oct:57](../scripts/game/vehicles/vm_indep.gd#L57)

### VmIndep._paint

- Unlabelled construction / setup — [VmIndep._paint:50](../scripts/game/vehicles/vm_indep.gd#L50)

### VmIndep._plate

- Unlabelled construction / setup — [VmIndep._plate:68](../scripts/game/vehicles/vm_indep.gd#L68)

### VmIndep._rcws

- Unlabelled construction / setup — [VmIndep._rcws:294](../scripts/game/vehicles/vm_indep.gd#L294)
- the sight box on the right, the ammo box on the left — [VmIndep._rcws:301](../scripts/game/vehicles/vm_indep.gd#L301)
- HK GMG: a squat receiver, a short thick barrel, the big belt box — [VmIndep._rcws:306](../scripts/game/vehicles/vm_indep.gd#L306)
- M2: the long receiver, the barrel with its carrying handle, flash hider — [VmIndep._rcws:314](../scripts/game/vehicles/vm_indep.gd#L314)

### VmIndep._ring

- Unlabelled construction / setup — [VmIndep._ring:61](../scripts/game/vehicles/vm_indep.gd#L61)

### VmIndep._road_wheel

- Unlabelled construction / setup — [VmIndep._road_wheel:133](../scripts/game/vehicles/vm_indep.gd#L133)

### VmIndep._round_light

- Unlabelled construction / setup — [VmIndep._round_light:103](../scripts/game/vehicles/vm_indep.gd#L103)

### VmIndep._running_gear

- Unlabelled construction / setup — [VmIndep._running_gear:342](../scripts/game/vehicles/vm_indep.gd#L342)

### VmIndep._sensor_head

- Unlabelled construction / setup — [VmIndep._sensor_head:286](../scripts/game/vehicles/vm_indep.gd#L286)

### VmIndep._slats

- Unlabelled construction / setup — [VmIndep._slats:327](../scripts/game/vehicles/vm_indep.gd#L327)

### VmIndep._smoke

- Unlabelled construction / setup — [VmIndep._smoke:112](../scripts/game/vehicles/vm_indep.gd#L112)

### VmIndep._sprocket

- Unlabelled construction / setup — [VmIndep._sprocket:143](../scripts/game/vehicles/vm_indep.gd#L143)

### VmIndep._tb

- Unlabelled construction / setup — [VmIndep._tb:77](../scripts/game/vehicles/vm_indep.gd#L77)

### VmIndep._tow_eyes

- Unlabelled construction / setup — [VmIndep._tow_eyes:279](../scripts/game/vehicles/vm_indep.gd#L279)

### VmIndep._track_belt

- Unlabelled construction / setup — [VmIndep._track_belt:158](../scripts/game/vehicles/vm_indep.gd#L158)

### VmIndep._zamak_ammo

- Unlabelled construction / setup — [VmIndep._zamak_ammo:1019](../scripts/game/vehicles/vm_indep.gd#L1019)
- the front stacks under a tarp, its rolled edge — [VmIndep._zamak_ammo:1033](../scripts/game/vehicles/vm_indep.gd#L1033)

### VmIndep._zamak_bed

- Unlabelled construction / setup — [VmIndep._zamak_bed:943](../scripts/game/vehicles/vm_indep.gd#L943)
- under the back: tail lights on their brackets, the bumper bar, pintle, plate — [VmIndep._zamak_bed:957](../scripts/game/vehicles/vm_indep.gd#L957)

### VmIndep._zamak_box

- Unlabelled construction / setup — [VmIndep._zamak_box:1040](../scripts/game/vehicles/vm_indep.gd#L1040)
- roof vents — [VmIndep._zamak_box:1046](../scripts/game/vehicles/vm_indep.gd#L1046)

### VmIndep._zamak_cab

- Unlabelled construction / setup — [VmIndep._zamak_cab:868](../scripts/game/vehicles/vm_indep.gd#L868)
- chassis rails and cross members, axles with their differentials, springs — [VmIndep._zamak_cab:869](../scripts/game/vehicles/vm_indep.gd#L869)
- the bonnet: louvres down its sides, the grille in front — [VmIndep._zamak_cab:881](../scripts/game/vehicles/vm_indep.gd#L881)
- the wing over the front wheel: flat top, raked front, a valance — [VmIndep._zamak_cab:888](../scripts/game/vehicles/vm_indep.gd#L888)
- a round headlight on the wing's front, the sidelight on top of it — [VmIndep._zamak_cab:894](../scripts/game/vehicles/vm_indep.gd#L894)
- the bumper with its tow hooks and plate — [VmIndep._zamak_cab:897](../scripts/game/vehicles/vm_indep.gd#L897)
- the cab: vertical lower half, the glasshouse leaning in a little — [VmIndep._zamak_cab:902](../scripts/game/vehicles/vm_indep.gd#L902)
- door window and rear quarter light, the door's seams and handle, the step and grab handle, the mirror on its arm — [VmIndep._zamak_cab:913](../scripts/game/vehicles/vm_indep.gd#L913)
- the roof hatch and marker lights, an antenna on the back corner — [VmIndep._zamak_cab:921](../scripts/game/vehicles/vm_indep.gd#L921)
- behind the cab: the spare wheel upright in its frame, the air intake, the fuel tank on the left and the battery box on the right — [VmIndep._zamak_cab:926](../scripts/game/vehicles/vm_indep.gd#L926)
- the exhaust's silencer under the right side of the cab — [VmIndep._zamak_cab:936](../scripts/game/vehicles/vm_indep.gd#L936)

### VmIndep._zamak_cargo

- Unlabelled construction / setup — [VmIndep._zamak_cargo:992](../scripts/game/vehicles/vm_indep.gd#L992)
- two oil drums at the front left, a crate stack at the front right — [VmIndep._zamak_cargo:995](../scripts/game/vehicles/vm_indep.gd#L995)
- the middle: a pile under a tarpaulin, lashed down — [VmIndep._zamak_cargo:1005](../scripts/game/vehicles/vm_indep.gd#L1005)
- the back: crates, sacks and jerrycans — [VmIndep._zamak_cargo:1007](../scripts/game/vehicles/vm_indep.gd#L1007)

### VmIndep._zamak_fuel

- Unlabelled construction / setup — [VmIndep._zamak_fuel:1129](../scripts/game/vehicles/vm_indep.gd#L1129)
- on top: two manholes, the walkway, fold-down rails — [VmIndep._zamak_fuel:1135](../scripts/game/vehicles/vm_indep.gd#L1135)
- hazard placards and the fire extinguisher by the cabinet — [VmIndep._zamak_fuel:1142](../scripts/game/vehicles/vm_indep.gd#L1142)
- the pump cabinet at the back: louvred doors, the hose reel on top, a ladder up its back — [VmIndep._zamak_fuel:1145](../scripts/game/vehicles/vm_indep.gd#L1145)
- under the back: tail lights, bumper, pintle — [VmIndep._zamak_fuel:1160](../scripts/game/vehicles/vm_indep.gd#L1160)

### VmIndep._zamak_medical

- Unlabelled construction / setup — [VmIndep._zamak_medical:1096](../scripts/game/vehicles/vm_indep.gd#L1096)
- the roof: a white panel with its cross, the rolled awning — [VmIndep._zamak_medical:1106](../scripts/game/vehicles/vm_indep.gd#L1106)
- the back: two doors with the cross across them, handles, a step — [VmIndep._zamak_medical:1111](../scripts/game/vehicles/vm_indep.gd#L1111)

### VmIndep._zamak_mrl

- Unlabelled construction / setup — [VmIndep._zamak_mrl:1171](../scripts/game/vehicles/vm_indep.gd#L1171)
- stabiliser jacks behind the rear wheels, raised — [VmIndep._zamak_mrl:1174](../scripts/game/vehicles/vm_indep.gd#L1174)
- the fire-control and reload boxes at the front of the deck — [VmIndep._zamak_mrl:1178](../scripts/game/vehicles/vm_indep.gd#L1178)
- the turntable and its trunnion brackets — [VmIndep._zamak_mrl:1182](../scripts/game/vehicles/vm_indep.gd#L1182)
- the elevating ram's base on the turntable — [VmIndep._zamak_mrl:1190](../scripts/game/vehicles/vm_indep.gd#L1190)
- the pod: twelve cells, three rows of four, its frame bands and covers — [VmIndep._zamak_mrl:1192](../scripts/game/vehicles/vm_indep.gd#L1192)

### VmIndep._zamak_repair

- Unlabelled construction / setup — [VmIndep._zamak_repair:1056](../scripts/game/vehicles/vm_indep.gd#L1056)
- the side door on the right with its fold-down step, a locker on the left — [VmIndep._zamak_repair:1062](../scripts/game/vehicles/vm_indep.gd#L1062)
- a ladder up the back of the body — [VmIndep._zamak_repair:1070](../scripts/game/vehicles/vm_indep.gd#L1070)
- the crane on the deck: slewing base, column, the boom folded forward over the roof, its ram and hook — [VmIndep._zamak_repair:1075](../scripts/game/vehicles/vm_indep.gd#L1075)
- generator and gas bottles chained to the deck — [VmIndep._zamak_repair:1084](../scripts/game/vehicles/vm_indep.gd#L1084)

### VmIndep._zamak_tilt

- Unlabelled construction / setup — [VmIndep._zamak_tilt:968](../scripts/game/vehicles/vm_indep.gd#L968)
- the hoops showing through, the lashing along the bottom — [VmIndep._zamak_tilt:970](../scripts/game/vehicles/vm_indep.gd#L970)
- the back: the flap rolled up under the roof, the dark inside, benches — [VmIndep._zamak_tilt:981](../scripts/game/vehicles/vm_indep.gd#L981)

### VmNato._ammo_can

- Unlabelled construction / setup — [VmNato._ammo_can:171](../scripts/game/vehicles/vm_nato.gd#L171)

### VmNato._antenna

- Unlabelled construction / setup — [VmNato._antenna:177](../scripts/game/vehicles/vm_nato.gd#L177)

### VmNato._axles

- Unlabelled construction / setup — [VmNato._axles:530](../scripts/game/vehicles/vm_nato.gd#L530)

### VmNato._beam

- Unlabelled construction / setup — [VmNato._beam:144](../scripts/game/vehicles/vm_nato.gd#L144)

### VmNato._cam

- Unlabelled construction / setup — [VmNato._cam:75](../scripts/game/vehicles/vm_nato.gd#L75)

### VmNato._cargo

- Unlabelled construction / setup — [VmNato._cargo:1583](../scripts/game/vehicles/vm_nato.gd#L1583)

### VmNato._chain

- Unlabelled construction / setup — [VmNato._chain:969](../scripts/game/vehicles/vm_nato.gd#L969)

### VmNato._cross

- Unlabelled construction / setup — [VmNato._cross:1608](../scripts/game/vehicles/vm_nato.gd#L1608)

### VmNato._era

- Unlabelled construction / setup — [VmNato._era:115](../scripts/game/vehicles/vm_nato.gd#L115)

### VmNato._extrude_z

- Unlabelled construction / setup — [VmNato._extrude_z:1287](../scripts/game/vehicles/vm_nato.gd#L1287)

### VmNato._gmg

- Unlabelled construction / setup — [VmNato._gmg:230](../scripts/game/vehicles/vm_nato.gd#L230)
- the drum feeding in from the right — [VmNato._gmg:237](../scripts/game/vehicles/vm_nato.gd#L237)

### VmNato._hemtt_cab_detail

- Unlabelled construction / setup — [VmNato._hemtt_cab_detail:1379](../scripts/game/vehicles/vm_nato.gd#L1379)
- A pressed roof cap and an inset service panel break up the flat cab. — [VmNato._hemtt_cab_detail:1381](../scripts/game/vehicles/vm_nato.gd#L1381)
- Door recess, raised inner pressing, hinges and a grab handle. — [VmNato._hemtt_cab_detail:1385](../scripts/game/vehicles/vm_nato.gd#L1385)
- Worn step lips and lower door sill, where boots contact the paint. — [VmNato._hemtt_cab_detail:1387](../scripts/game/vehicles/vm_nato.gd#L1387)

### VmNato._hemtt_cargo_detail

- Unlabelled construction / setup — [VmNato._hemtt_cargo_detail:1394](../scripts/game/vehicles/vm_nato.gd#L1394)
- Segmented bed rails, latch hardware and small rub marks on each hinge. — [VmNato._hemtt_cargo_detail:1397](../scripts/game/vehicles/vm_nato.gd#L1397)

### VmNato._hemtt_chassis

- Unlabelled construction / setup — [VmNato._hemtt_chassis:1296](../scripts/game/vehicles/vm_nato.gd#L1296)
- frame rails, the axles' beams and springs — [VmNato._hemtt_chassis:1307](../scripts/game/vehicles/vm_nato.gd#L1307)
- the cab: a slightly raked windscreen, flat sides, the nose out in front — [VmNato._hemtt_chassis:1311](../scripts/game/vehicles/vm_nato.gd#L1311)
- Open upper cab: the windows must reveal seats, dash and the far side, not a solid painted box immediately behind transparent glass. — [VmNato._hemtt_chassis:1314](../scripts/game/vehicles/vm_nato.gd#L1314)
- the big grille, the bumper with the headlights in its ends, tow eyes, the pintle — [VmNato._hemtt_chassis:1322](../scripts/game/vehicles/vm_nato.gd#L1322)
- the sun visor over the windscreen — [VmNato._hemtt_chassis:1335](../scripts/game/vehicles/vm_nato.gd#L1335)
- windscreen panes, door windows, door seams, handles, mirrors, steps — [VmNato._hemtt_chassis:1337](../scripts/game/vehicles/vm_nato.gd#L1337)
- the ladder steps up to the door — [VmNato._hemtt_chassis:1350](../scripts/game/vehicles/vm_nato.gd#L1350)
- the long black fender over both front axles, raked at its front — [VmNato._hemtt_chassis:1352](../scripts/game/vehicles/vm_nato.gd#L1352)
- the roof hatch, marker lights, antenna — [VmNato._hemtt_chassis:1356](../scripts/game/vehicles/vm_nato.gd#L1356)
- behind the cab: the engine's air cleaner (left), the exhaust stack (right), the spare wheel between — [VmNato._hemtt_chassis:1361](../scripts/game/vehicles/vm_nato.gd#L1361)
- fuel tank and battery box on the frame, air tanks — [VmNato._hemtt_chassis:1367](../scripts/game/vehicles/vm_nato.gd#L1367)

### VmNato._hemtt_deck

- Unlabelled construction / setup — [VmNato._hemtt_deck:1434](../scripts/game/vehicles/vm_nato.gd#L1434)

### VmNato._hemtt_load_detail

- Unlabelled construction / setup — [VmNato._hemtt_load_detail:1412](../scripts/game/vehicles/vm_nato.gd#L1412)
- Rolled rims, reinforcing hoops and filler bungs identify oil drums. — [VmNato._hemtt_load_detail:1416](../scripts/game/vehicles/vm_nato.gd#L1416)
- Straps wrap over the load and down its sides to the pallet. — [VmNato._hemtt_load_detail:1424](../scripts/game/vehicles/vm_nato.gd#L1424)

### VmNato._hemtt_wheel

- Unlabelled construction / setup — [VmNato._hemtt_wheel:1408](../scripts/game/vehicles/vm_nato.gd#L1408)

### VmNato._jerry

- Unlabelled construction / setup — [VmNato._jerry:165](../scripts/game/vehicles/vm_nato.gd#L165)

### VmNato._lamp

- Unlabelled construction / setup — [VmNato._lamp:149](../scripts/game/vehicles/vm_nato.gd#L149)

### VmNato._m2

- Unlabelled construction / setup — [VmNato._m2:216](../scripts/game/vehicles/vm_nato.gd#L216)

### VmNato._mk_hull

- Unlabelled construction / setup — [VmNato._mk_hull:812](../scripts/game/vehicles/vm_nato.gd#L812)
- lower hull between the tracks: the lower nose plate, the belly, the tail — [VmNato._mk_hull:814](../scripts/game/vehicles/vm_nato.gd#L814)
- the upper hull: the sponsons over the tracks, the glacis rising from the nose to the front of the roof, the roof flat back to the rear — [VmNato._mk_hull:816](../scripts/game/vehicles/vm_nato.gd#L816)
- the nose: a heavy cast beak with tow eyes and the headlight clusters — [VmNato._mk_hull:821](../scripts/game/vehicles/vm_nato.gd#L821)
- glacis: engine access panels and the big intake grilles, the driver's hatch and periscopes at the top on the left — [VmNato._mk_hull:827](../scripts/game/vehicles/vm_nato.gd#L827)
- the exhaust louvres on the left of the glacis — [VmNato._mk_hull:841](../scripts/game/vehicles/vm_nato.gd#L841)
- skirts: bolted heavy panels hanging off the sponsons, the front one raked — [VmNato._mk_hull:843](../scripts/game/vehicles/vm_nato.gd#L843)
- the rail along the sponson edge and a tow cable on it — [VmNato._mk_hull:850](../scripts/game/vehicles/vm_nato.gd#L850)
- tool boxes along the sponson (the hull roof aft stays clear: the bustle and its chains sweep over it) — [VmNato._mk_hull:853](../scripts/game/vehicles/vm_nato.gd#L853)
- reactive armour bricks over the skirts and up the glacis — [VmNato._mk_hull:861](../scripts/game/vehicles/vm_nato.gd#L861)
- the rear: the troop door with its vision block, steps, stowage baskets — [VmNato._mk_hull:873](../scripts/game/vehicles/vm_nato.gd#L873)

### VmNato._mk_running

- Unlabelled construction / setup — [VmNato._mk_running:796](../scripts/game/vehicles/vm_nato.gd#L796)
- the sprocket's teeth ring — [VmNato._mk_running:803](../scripts/game/vehicles/vm_nato.gd#L803)

### VmNato._mk_turret

- Unlabelled construction / setup — [VmNato._mk_turret:895](../scripts/game/vehicles/vm_nato.gd#L895)
- the turret's body: the wedge in front, the main body over the ring — [VmNato._mk_turret:898](../scripts/game/vehicles/vm_nato.gd#L898)
- the bustle, raised clear of the hull roof (the chains hang across the gap) — [VmNato._mk_turret:902](../scripts/game/vehicles/vm_nato.gd#L902)
- ball-and-chain curtain along the bustle's rear and sides — [VmNato._mk_turret:907](../scripts/game/vehicles/vm_nato.gd#L907)
- the gun: a small mantlet low in the wedge, the barrel's thermal sleeve in sections, the fume extractor, the muzzle reference sensor — [VmNato._mk_turret:914](../scripts/game/vehicles/vm_nato.gd#L914)
- the gunner's sight box forward left, the commander's big panoramic sight forward right, the cupola behind it, the loader's hatch, the 60 mm mortar — [VmNato._mk_turret:925](../scripts/game/vehicles/vm_nato.gd#L925)
- the loader's MG on its pintle, the wind sensor mast, antennas — [VmNato._mk_turret:941](../scripts/game/vehicles/vm_nato.gd#L941)
- smoke dischargers on the wedge's flanks, side armour modules with their channels, stowage baskets along the bustle — [VmNato._mk_turret:948](../scripts/game/vehicles/vm_nato.gd#L948)
- reactive armour bricks over the wedge's faces and the turret sides — [VmNato._mk_turret:956](../scripts/game/vehicles/vm_nato.gd#L956)

### VmNato._namer_hull

- Unlabelled construction / setup — [VmNato._namer_hull:1089](../scripts/game/vehicles/vm_nato.gd#L1089)
- the glacis over the engine, then the superstructure's sloped front face, its sides straight up from the sponsons — [VmNato._namer_hull:1093](../scripts/game/vehicles/vm_nato.gd#L1093)
- the nose with tow eyes and lights in guards — [VmNato._namer_hull:1099](../scripts/game/vehicles/vm_nato.gd#L1099)
- glacis: engine grilles, access panels — [VmNato._namer_hull:1105](../scripts/game/vehicles/vm_nato.gd#L1105)
- the driver's hatch and periscopes on the superstructure front, left — [VmNato._namer_hull:1114](../scripts/game/vehicles/vm_nato.gd#L1114)
- skirts and side armour: heavy panels low, the superstructure's armour modules with a channel between them, stowage, tow cable — [VmNato._namer_hull:1120](../scripts/game/vehicles/vm_nato.gd#L1120)
- smoke dischargers on the front roof corners — [VmNato._namer_hull:1137](../scripts/game/vehicles/vm_nato.gd#L1137)
- roof: the commander's cupola with periscopes, hatches over the troop compartment, stowage at the back — [VmNato._namer_hull:1139](../scripts/game/vehicles/vm_nato.gd#L1139)
- the rear: the big ramp with its door, hinges, steps — [VmNato._namer_hull:1155](../scripts/game/vehicles/vm_nato.gd#L1155)

### VmNato._on_face

- Unlabelled construction / setup — [VmNato._on_face:103](../scripts/game/vehicles/vm_nato.gd#L103)

### VmNato._rcws

- Unlabelled construction / setup — [VmNato._rcws:249](../scripts/game/vehicles/vm_nato.gd#L249)
- Samson-style: a wide box between two cradles — [VmNato._rcws:256](../scripts/game/vehicles/vm_nato.gd#L256)
- yoke arms either side of the cradle — [VmNato._rcws:267](../scripts/game/vehicles/vm_nato.gd#L267)
- the sight unit on the left of the cradle: day camera and thermal windows — [VmNato._rcws:277](../scripts/game/vehicles/vm_nato.gd#L277)

### VmNato._ring_z

- Unlabelled construction / setup — [VmNato._ring_z:1279](../scripts/game/vehicles/vm_nato.gd#L1279)

### VmNato._road_wheel

- Unlabelled construction / setup — [VmNato._road_wheel:790](../scripts/game/vehicles/vm_nato.gd#L790)

### VmNato._seat

- Unlabelled construction / setup — [VmNato._seat:208](../scripts/game/vehicles/vm_nato.gd#L208)

### VmNato._shackle

- Unlabelled construction / setup — [VmNato._shackle:192](../scripts/game/vehicles/vm_nato.gd#L192)

### VmNato._smoke

- Unlabelled construction / setup — [VmNato._smoke:183](../scripts/game/vehicles/vm_nato.gd#L183)

### VmNato._spare

- Unlabelled construction / setup — [VmNato._spare:198](../scripts/game/vehicles/vm_nato.gd#L198)

### VmNato._taillight

- Unlabelled construction / setup — [VmNato._taillight:159](../scripts/game/vehicles/vm_nato.gd#L159)

### VmNato._team_mark

- Unlabelled construction / setup — [VmNato._team_mark:203](../scripts/game/vehicles/vm_nato.gd#L203)

### VmNato._track_loop

- Unlabelled construction / setup — [VmNato._track_loop:774](../scripts/game/vehicles/vm_nato.gd#L774)

### VmNato._tube

- Unlabelled construction / setup — [VmNato._tube:139](../scripts/game/vehicles/vm_nato.gd#L139)

### VmNato._xy

- Unlabelled construction / setup — [VmNato._xy:92](../scripts/game/vehicles/vm_nato.gd#L92)

### VmNato._zy

- Unlabelled construction / setup — [VmNato._zy:82](../scripts/game/vehicles/vm_nato.gd#L82)

### VmPlane._foil_t

- Unlabelled construction / setup — [VmPlane._foil_t:232](../scripts/game/vehicles/vm_plane.gd#L232)

### VmPlane._mx

- Unlabelled construction / setup — [VmPlane._mx:167](../scripts/game/vehicles/vm_plane.gd#L167)

### VmPlane._sp

- Unlabelled construction / setup — [VmPlane._sp:94](../scripts/game/vehicles/vm_plane.gd#L94)

### VmPlane._tri

- Unlabelled construction / setup — [VmPlane._tri:79](../scripts/game/vehicles/vm_plane.gd#L79)

### VmPlane.agm

- Unlabelled construction / setup — [VmPlane.agm:436](../scripts/game/vehicles/vm_plane.gd#L436)

### VmPlane.antenna

- Unlabelled construction / setup — [VmPlane.antenna:466](../scripts/game/vehicles/vm_plane.gd#L466)

### VmPlane.band

- Unlabelled construction / setup — [VmPlane.band:176](../scripts/game/vehicles/vm_plane.gd#L176)

### VmPlane.body

- Unlabelled construction / setup — [VmPlane.body:148](../scripts/game/vehicles/vm_plane.gd#L148)

### VmPlane.body2

- Unlabelled construction / setup — [VmPlane.body2:158](../scripts/game/vehicles/vm_plane.gd#L158)

### VmPlane.bomb

- Unlabelled construction / setup — [VmPlane.bomb:396](../scripts/game/vehicles/vm_plane.gd#L396)
- the yellow high-explosive band, the lugs — [VmPlane.bomb:399](../scripts/game/vehicles/vm_plane.gd#L399)

### VmPlane.drop_tank

- Unlabelled construction / setup — [VmPlane.drop_tank:447](../scripts/game/vehicles/vm_plane.gd#L447)

### VmPlane.glow

- Unlabelled construction / setup — [VmPlane.glow:267](../scripts/game/vehicles/vm_plane.gd#L267)
- (the texture's alpha makes it a soft round glow, not a lit square) — [VmPlane.glow:275](../scripts/game/vehicles/vm_plane.gd#L275)

### VmPlane.gun_pod

- Unlabelled construction / setup — [VmPlane.gun_pod:456](../scripts/game/vehicles/vm_plane.gd#L456)

### VmPlane.lift_fan

- Unlabelled construction / setup — [VmPlane.lift_fan:1399](../scripts/game/vehicles/vm_plane.gd#L1399)

### VmPlane.missile

- Unlabelled construction / setup — [VmPlane.missile:422](../scripts/game/vehicles/vm_plane.gd#L422)

### VmPlane.mouth

- Unlabelled construction / setup — [VmPlane.mouth:214](../scripts/game/vehicles/vm_plane.gd#L214)

### VmPlane.nav_lights

- Unlabelled construction / setup — [VmPlane.nav_lights:471](../scripts/game/vehicles/vm_plane.gd#L471)

### VmPlane.nozzle

- Unlabelled construction / setup — [VmPlane.nozzle:305](../scripts/game/vehicles/vm_plane.gd#L305)

### VmPlane.prop

- Unlabelled construction / setup — [VmPlane.prop:343](../scripts/game/vehicles/vm_plane.gd#L343)
- the axis the blades turn about, in the pivot's own space (aft is +z, or +y for a rotor) — [VmPlane.prop:352](../scripts/game/vehicles/vm_plane.gd#L352)
- the spinner: a pointed cone ahead of the hub — [VmPlane.prop:354](../scripts/game/vehicles/vm_plane.gd#L354)

### VmPlane.pylon

- Unlabelled construction / setup — [VmPlane.pylon:390](../scripts/game/vehicles/vm_plane.gd#L390)

### VmPlane.rocket_pod

- Unlabelled construction / setup — [VmPlane.rocket_pod:416](../scripts/game/vehicles/vm_plane.gd#L416)

### VmPlane.rod

- Unlabelled construction / setup — [VmPlane.rod:259](../scripts/game/vehicles/vm_plane.gd#L259)

### VmPlane.sec

- Unlabelled construction / setup — [VmPlane.sec:104](../scripts/game/vehicles/vm_plane.gd#L104)

### VmPlane.skin

- Unlabelled construction / setup — [VmPlane.skin:72](../scripts/game/vehicles/vm_plane.gd#L72)

### VmPlane.st_at

- Unlabelled construction / setup — [VmPlane.st_at:131](../scripts/game/vehicles/vm_plane.gd#L131)

### VmPlane.stripe

- Unlabelled construction / setup — [VmPlane.stripe:188](../scripts/game/vehicles/vm_plane.gd#L188)

### VmPlane.surf

- Unlabelled construction / setup — [VmPlane.surf:238](../scripts/game/vehicles/vm_plane.gd#L238)

### VmPlane.surf_at

- Unlabelled construction / setup — [VmPlane.surf_at:246](../scripts/game/vehicles/vm_plane.gd#L246)

### VmPlane.wing_marks

- Unlabelled construction / setup — [VmPlane.wing_marks:477](../scripts/game/vehicles/vm_plane.gd#L477)

### VmShips._at

- Unlabelled construction / setup — [VmShips._at:156](../scripts/game/vehicles/vm_ships.gd#L156)

### VmShips._bitts

- Unlabelled construction / setup — [VmShips._bitts:376](../scripts/game/vehicles/vm_ships.gd#L376)

### VmShips._box_mesh

- Unlabelled construction / setup — [VmShips._box_mesh:313](../scripts/game/vehicles/vm_ships.gd#L313)

### VmShips._bulwark

- Unlabelled construction / setup — [VmShips._bulwark:73](../scripts/game/vehicles/vm_ships.gd#L73)

### VmShips._bx

- Unlabelled construction / setup — [VmShips._bx:309](../scripts/game/vehicles/vm_ships.gd#L309)

### VmShips._coil

- Unlabelled construction / setup — [VmShips._coil:381](../scripts/game/vehicles/vm_ships.gd#L381)

### VmShips._decal

- Unlabelled construction / setup — [VmShips._decal:232](../scripts/game/vehicles/vm_ships.gd#L232)

### VmShips._deck_mesh

- Unlabelled construction / setup — [VmShips._deck_mesh:207](../scripts/game/vehicles/vm_ships.gd#L207)

### VmShips._deck_y

- Unlabelled construction / setup — [VmShips._deck_y:65](../scripts/game/vehicles/vm_ships.gd#L65)

### VmShips._digits

- Unlabelled construction / setup — [VmShips._digits:249](../scripts/game/vehicles/vm_ships.gd#L249)
- where along the side this digit sits: reading from outboard — [VmShips._digits:255](../scripts/game/vehicles/vm_ships.gd#L255)
- the side reads toward the bow on the right (-z), aft on the left — [VmShips._digits:278](../scripts/game/vehicles/vm_ships.gd#L278)

### VmShips._dk

- Unlabelled construction / setup — [VmShips._dk:160](../scripts/game/vehicles/vm_ships.gd#L160)

### VmShips._dshk

- Unlabelled construction / setup — [VmShips._dshk:593](../scripts/game/vehicles/vm_ships.gd#L593)

### VmShips._flag

- Unlabelled construction / setup — [VmShips._flag:424](../scripts/game/vehicles/vm_ships.gd#L424)

### VmShips._hull

- Unlabelled construction / setup — [VmShips._hull:177](../scripts/game/vehicles/vm_ships.gd#L177)

### VmShips._hull_bands

- Unlabelled construction / setup — [VmShips._hull_bands:188](../scripts/game/vehicles/vm_ships.gd#L188)

### VmShips._insert

- Unlabelled construction / setup — [VmShips._insert:134](../scripts/game/vehicles/vm_ships.gd#L134)

### VmShips._keel_y

- Unlabelled construction / setup — [VmShips._keel_y:79](../scripts/game/vehicles/vm_ships.gd#L79)

### VmShips._liferaft

- Unlabelled construction / setup — [VmShips._liferaft:400](../scripts/game/vehicles/vm_ships.gd#L400)
- the cradle's saddle — [VmShips._liferaft:409](../scripts/game/vehicles/vm_ships.gd#L409)

### VmShips._lifering

- Unlabelled construction / setup — [VmShips._lifering:388](../scripts/game/vehicles/vm_ships.gd#L388)

### VmShips._m2

- Unlabelled construction / setup — [VmShips._m2:511](../scripts/game/vehicles/vm_ships.gd#L511)

### VmShips._mk38

- Unlabelled construction / setup — [VmShips._mk38:467](../scripts/game/vehicles/vm_ships.gd#L467)
- the carriage: a low chamfered box on the turntable, the trunnion arms — [VmShips._mk38:475](../scripts/game/vehicles/vm_ships.gd#L475)
- the cradle housing: chamfered section, its nose tapering round the barrel — [VmShips._mk38:480](../scripts/game/vehicles/vm_ships.gd#L480)
- the barrel: a support sleeve, the long tapering tube, a muzzle device — [VmShips._mk38:486](../scripts/game/vehicles/vm_ships.gd#L486)
- the electro-optical sight on the left, its windows forward — [VmShips._mk38:490](../scripts/game/vehicles/vm_ships.gd#L490)
- the ammunition box on the right and its feed chute into the receiver — [VmShips._mk38:496](../scripts/game/vehicles/vm_ships.gd#L496)
- the spent case chute under the housing, a cable loom at the back — [VmShips._mk38:501](../scripts/game/vehicles/vm_ships.gd#L501)

### VmShips._rod

- Unlabelled construction / setup — [VmShips._rod:325](../scripts/game/vehicles/vm_ships.gd#L325)

### VmShips._searchlight

- Unlabelled construction / setup — [VmShips._searchlight:448](../scripts/game/vehicles/vm_ships.gd#L448)

### VmShips._station

- Unlabelled construction / setup — [VmShips._station:87](../scripts/game/vehicles/vm_ships.gd#L87)
- a round bilge: a quarter superellipse from the keel up to the bilge's top, full amidships, easing into a V toward the bow — [VmShips._station:101](../scripts/game/vehicles/vm_ships.gd#L101)
- points where the paint changes and at the deck's edge (always added, so every station of a hull has the same count) — [VmShips._station:112](../scripts/game/vehicles/vm_ships.gd#L112)
- keep the section convex — [VmShips._station:119](../scripts/game/vehicles/vm_ships.gd#L119)

### VmShips._stem_z

- Unlabelled construction / setup — [VmShips._stem_z:165](../scripts/game/vehicles/vm_ships.gd#L165)

### VmShips._surf

- Unlabelled construction / setup — [VmShips._surf:218](../scripts/game/vehicles/vm_ships.gd#L218)
- reading from outboard: toward the bow on the right side, aft on the left — [VmShips._surf:223](../scripts/game/vehicles/vm_ships.gd#L223)

### VmShips._sweep

- Unlabelled construction / setup — [VmShips._sweep:286](../scripts/game/vehicles/vm_ships.gd#L286)

### VmShips._torus

- Unlabelled construction / setup — [VmShips._torus:348](../scripts/game/vehicles/vm_ships.gd#L348)

### VmShips._tube

- Unlabelled construction / setup — [VmShips._tube:329](../scripts/game/vehicles/vm_ships.gd#L329)

### VmShips._u

- Unlabelled construction / setup — [VmShips._u:152](../scripts/game/vehicles/vm_ships.gd#L152)

### VmShips._vent

- Unlabelled construction / setup — [VmShips._vent:418](../scripts/game/vehicles/vm_ships.gd#L418)

### VmShips._whip

- Unlabelled construction / setup — [VmShips._whip:442](../scripts/game/vehicles/vm_ships.gd#L442)

### VmShips._zu23

- Unlabelled construction / setup — [VmShips._zu23:536](../scripts/game/vehicles/vm_ships.gd#L536)
- the lower carriage: a triangle of box beams with levelling jacks — [VmShips._zu23:538](../scripts/game/vehicles/vm_ships.gd#L538)
- crude welds: a gusset onto the deck plate — [VmShips._zu23:547](../scripts/game/vehicles/vm_ships.gd#L547)
- the upper carriage: a floor, two side frames up to the trunnions — [VmShips._zu23:551](../scripts/game/vehicles/vm_ships.gd#L551)
- receivers, barrel jackets, barrels and flash hiders — [VmShips._zu23:559](../scripts/game/vehicles/vm_ships.gd#L559)
- the box magazine on the gun's outer side — [VmShips._zu23:566](../scripts/game/vehicles/vm_ships.gd#L566)
- the cradle tying the two guns, the sight standing up on the left — [VmShips._zu23:570](../scripts/game/vehicles/vm_ships.gd#L570)
- two seats with backrests behind the guns, handwheels in front of them — [VmShips._zu23:576](../scripts/game/vehicles/vm_ships.gd#L576)
- a slab of steel plate welded on in front of the cradle — [VmShips._zu23:583](../scripts/game/vehicles/vm_ships.gd#L583)

