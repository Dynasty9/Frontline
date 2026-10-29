# Vehicle handling and weapon origins

The movement caps below are **tactical field speeds**, not maximum paved-road or
level-flight performance. Per-vehicle speeds live in `Defs.VEHICLES`; boat cruise caps are retuned below, while land and air caps are retained.
terrain, grip, braking distance, traffic, and flight approach guidance can reduce
them. Converting all of them to catalogue maxima would make the small battlefield
and existing flight missions play very differently.

`VehicleMotion` assigns the actuator and handling profile for every buildable
vehicle. Angular data is authored in degrees per second (acceleration in degrees
per second squared), then converted once to radians. Tank and IFV variants have
individual drive overrides; old tanks, manual pintles, AA drives, artillery and
heavy-lift helicopters do not share one generic fast response. These are
**plausible game tuning estimates**, not certified measurements of every named
real-world variant. In particular, fictional vehicles inherit the closest family.

The scale of the modern tank profile is consistent with the 40 deg/s illustrative
MBT traverse discussed in the US Army's [July–August 1997 ARMOR](https://d34w7g4gy10iej.cloudfront.net/pubs/pdf_33768.pdf).
[KNDS's Leopard 2 A7 overview](https://knds.com/en/products/systems/leopard/leopard-2-a7)
and [Kongsberg's PROTECTOR RS4 overview](https://www.kongsberg.com/what-we-do/defence-and-security/remote-weapon-systems/protector-rs4/)
identify the relevant vehicle and remote-station roles; neither is treated as a
source for the estimated acceleration or traverse constants in this game.

## Motion and aiming rules

- All vehicle turrets accelerate and brake onto a bearing, including the slow
  artillery laying drive. Returning forward uses the shortest arc at half speed.
- Tanks retain their 0.3-second steady firing solution and target reacquisition.
  Hull stabilization consumes available traverse speed rather than adding an
  unlimited extra motor on top of the slew.
- Tracked hulls accelerate into pivots and recovery turns. Wheeled vehicles retain
  their wheelbase/steering-lock turning circle and cannot pivot at zero speed,
  including while backing out of an obstruction.
- Helicopter acceleration, braking, yaw rate and yaw acceleration depend on the
  airframe family; a sling load further reduces them. Chin guns stop at 110 degrees either side of the nose, so the airframe must
  turn for targets behind it. Horizontal cruise caps,
  vertical acceleration and landing safety envelopes are retained.
- Mounted M240/PKM-class weapons traverse at 55 deg/s; M2/DShK-class weapons at
  35 deg/s, mortar pits at 12 deg/s, and anti-tank posts at 20 deg/s. The authoritative gunner must bring the bearing within 2 degrees
  before firing. Rendering follows that bearing rather than another free slew.
- Boats use individual hull profiles for thrust, helm/engine response, lateral
  grip, turn radius, propeller wash and astern thrust; see the naval audit below. Support passes retain
  their existing paths and speeds. Orbiting gunship bank now matches its speed
  and turn radius (`atan(v² / (r*g))`).

## Barrel origins

The procedural model's muzzle markers are the geometry source of truth.
`vehicle_socket_data.gd` is a geometry-only bake, so the server does not create
meshes or materials to find a weapon. It records each socket's position and
whether it moves with the turret, preserving scale and off-centre mounts.

Regenerate after changing a weapon model (from the repository root):

```sh
godot --headless --path . res://tests/fixtures/vehicle-sockets.tscn -- --write-sockets
```

Normal tests compare all baked sockets against actual model markers, including
nonzero hull yaw, turret yaw, pitch and roll. Vehicle bullets and tank shells use
these positions. Each AC-130/Blackfish gun has its own named 25/40/105 mm socket;
the old shared point underneath the fuselage is gone. Gunship shells retain their
source aircraft id, allowing the local visual to begin at the locally rendered
barrel and converge onto the unchanged authoritative impact path. This uses the
existing replicated thrower field; packet layout is unchanged.

Effects trust a valid visible model marker rather than rejecting it for being
more than four metres from a rough server estimate. Despawned/missing or hidden
models fall back to the authoritative origin. Missile pods and artillery launch
angles retain their existing approximations; this change corrects bullet/main-gun
and orbiting-gunship barrel origins.

## Complete roster audit

Speed is the unobstructed tactical cap in m/s (multiply by 3.6 for km/h).
Hull rate is the tracked pivot / aircraft yaw cap; wheeled turning is instead
limited by wheelbase, steering lock and grip, and boat yaw by hydrodynamics.
Acceleration and brakes are m/s²; boat entries use their separate hull model.

| Key | Vehicle | Speed | Gun traverse °/s | Hull yaw °/s | Accel | Brakes |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `aa_tech` | AA Technical | 10.5 | 35 | 50 | 2.6 | 6.0 |
| `angara` | T-140 Angara | 7.0 | 38 | 30 | 1.2 | 4.0 |
| `angara_k` | T-140K Angara | 7.0 | 36 | 30 | 1.2 | 4.0 |
| `blackfoot` | AH-99 Blackfoot | 23.0 | 60 | 40 | 5.0 | 6.0 |
| `bobcat` | CRV-6e Bobcat | 6.0 | 45 | 35 | 1.1 | 4.0 |
| `btr` | BTR | 10.5 | 30 | 38 | 1.9 | 5.0 |
| `cheetah` | IFV-6a Cheetah | 6.5 | 75 | 38 | 1.9 | 5.0 |
| `darter` | AR-2 Darter | 11.0 | 50 | 45 | 4.0 | 5.0 |
| `falcon` | MQ-12 Falcon | 16.0 | 50 | 45 | 4.0 | 5.0 |
| `fenghuang_uav` | KH-3A Fenghuang | 18.0 | 50 | 45 | 4.0 | 5.0 |
| `fia_truck` | Truck | 9.5 | 45 | 35 | 1.1 | 4.0 |
| `futura` | T-100X Futura | 7.0 | 42 | 30 | 1.2 | 4.0 |
| `ghosthawk` | UH-80 Ghost Hawk | 21.0 | 35 | 20 | 2.8 | 4.0 |
| `ghosthawk_stub` | UH-80 Ghost Hawk (Stub Wings) | 21.0 | 60 | 40 | 5.0 | 6.0 |
| `gorgon` | AFV-4 Gorgon | 10.5 | 45 | 38 | 1.9 | 5.0 |
| `gun_trawler` | Gun Trawler | 5.0 | 35 | — | — | — |
| `gunship` | Attack Helicopter | 22.0 | 60 | 40 | 5.0 | 6.0 |
| `heli` | Supply Helicopter | 20.0 | 40 | 28 | 3.8 | 5.0 |
| `hellcat` | WY-55 Hellcat | 22.0 | 60 | 40 | 5.0 | 6.0 |
| `hemtt` | HEMTT Transport | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `hemtt_ammo` | HEMTT Ammo | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `hemtt_medical` | HEMTT Medical | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `hemtt_repair` | HEMTT Repair | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `hummingbird` | MH-9 Hummingbird | 24.0 | 40 | 28 | 3.8 | 5.0 |
| `humvee` | Humvee | 12.0 | 55 | 55 | 3.0 | 6.5 |
| `hunter` | Hunter | 11.0 | 55 | 55 | 3.0 | 6.5 |
| `hunter_gmg` | Hunter GMG | 11.0 | 55 | 55 | 3.0 | 6.5 |
| `hunter_hmg` | Hunter HMG | 11.0 | 55 | 55 | 3.0 | 6.5 |
| `huron` | CH-67 Huron | 18.0 | 35 | 20 | 2.8 | 4.0 |
| `ifrit` | Ifrit | 12.0 | 55 | 55 | 3.0 | 6.5 |
| `ifrit_gmg` | Ifrit GMG | 12.0 | 55 | 55 | 3.0 | 6.5 |
| `ifrit_hmg` | Ifrit HMG | 12.0 | 55 | 55 | 3.0 | 6.5 |
| `ifv` | IFV | 8.5 | 45 | 38 | 1.9 | 5.0 |
| `kajman` | Mi-48 Kajman | 21.0 | 60 | 40 | 5.0 | 6.0 |
| `kamysh` | BTR-K Kamysh | 8.5 | 45 | 38 | 1.9 | 5.0 |
| `kuma` | MBT-52 Kuma | 7.0 | 40 | 30 | 1.2 | 4.0 |
| `m900` | M900 | 23.0 | 40 | 28 | 3.8 | 5.0 |
| `marid` | MSE-3 Marid | 10.5 | 45 | 38 | 1.9 | 5.0 |
| `marshall` | AMV-7 Marshall | 10.5 | 45 | 38 | 1.9 | 5.0 |
| `mb4wd_at` | MB 4WD AT | 12.5 | 35 | 50 | 2.6 | 6.0 |
| `mb4wd_lmg` | MB 4WD LMG | 12.5 | 35 | 50 | 2.6 | 6.0 |
| `mohawk` | CH-49 Mohawk | 19.0 | 35 | 20 | 2.8 | 4.0 |
| `mora` | FV-720 Mora | 7.5 | 32 | 38 | 1.9 | 5.0 |
| `motorboat` | Armed Motorboat | 16.0 | 45 | — | — | — |
| `nyx_aa` | AWC 302 Nyx (AA) | 9.5 | 40 | 48 | 2.2 | 5.0 |
| `nyx_ac` | AWC 304 Nyx (Autocannon) | 9.5 | 40 | 48 | 2.2 | 5.0 |
| `nyx_at` | AWC 301 Nyx (AT) | 9.5 | 40 | 48 | 2.2 | 5.0 |
| `nyx_recon` | AWC 303 Nyx (Recon) | 9.5 | 40 | 48 | 2.2 | 5.0 |
| `offroad` | Offroad | 12.0 | 55 | 55 | 3.0 | 6.5 |
| `offroad_at` | Offroad AT | 11.0 | 35 | 50 | 2.6 | 6.0 |
| `offroad_hmg` | Offroad HMG | 11.5 | 35 | 50 | 2.6 | 6.0 |
| `offroad_repair` | Offroad Repair | 12.0 | 45 | 35 | 1.1 | 4.0 |
| `old_tank` | Old Tank | 5.5 | 16 | 22 | 0.8 | 3.4 |
| `orca` | PO-30 Orca | 22.0 | 40 | 28 | 3.8 | 5.0 |
| `orca_armed` | PO-30 Orca (Armed) | 22.0 | 60 | 40 | 5.0 | 6.0 |
| `panther` | IFV-6c Panther | 6.5 | 45 | 38 | 1.9 | 5.0 |
| `patrol_ship` | Patrol Ship | 13.5 | 45 | — | — | — |
| `pawnee` | AH-9 Pawnee | 24.0 | 60 | 40 | 5.0 | 6.0 |
| `prowler` | Prowler | 13.5 | 55 | 55 | 3.0 | 6.5 |
| `prowler_at` | Prowler AT | 13.5 | 55 | 55 | 3.0 | 6.5 |
| `prowler_hmg` | Prowler HMG | 13.5 | 35 | 50 | 2.6 | 6.0 |
| `qilin` | Qilin | 13.0 | 55 | 55 | 3.0 | 6.5 |
| `qilin_at` | Qilin AT | 13.0 | 55 | 55 | 3.0 | 6.5 |
| `qilin_mg` | Qilin Minigun | 13.0 | 35 | 50 | 2.6 | 6.0 |
| `quadbike` | Quadbike | 10.0 | 55 | 55 | 3.0 | 6.5 |
| `rhib` | RHIB | 18.0 | 45 | — | — | — |
| `rhino` | Rhino MGS | 11.0 | 28 | 30 | 1.2 | 4.0 |
| `rhino_up` | Rhino MGS UP | 10.0 | 26 | 30 | 1.2 | 4.0 |
| `sandstorm` | M5 Sandstorm | 6.0 | 10 | 26 | 1.1 | 3.8 |
| `scorcher` | M4 Scorcher | 6.0 | 10 | 26 | 1.1 | 3.8 |
| `slammer` | M2A1 Slammer | 6.5 | 36 | 30 | 1.2 | 4.0 |
| `slammer_up` | M2A4 Slammer UP | 6.0 | 34 | 30 | 1.2 | 4.0 |
| `sochor` | 2S9 Sochor | 7.0 | 10 | 26 | 1.1 | 3.8 |
| `speedboat_hmg` | Speedboat HMG | 15.0 | 45 | — | — | — |
| `speedboat_minigun` | Speedboat Minigun | 15.0 | 45 | — | — | — |
| `stomper` | UGV Stomper RCWS | 4.5 | 55 | 55 | 3.0 | 6.5 |
| `strider` | Strider | 11.5 | 55 | 55 | 3.0 | 6.5 |
| `strider_gmg` | Strider GMG | 11.5 | 55 | 55 | 3.0 | 6.5 |
| `strider_hmg` | Strider HMG | 11.5 | 55 | 55 | 3.0 | 6.5 |
| `tank` | Battle Tank | 6.5 | 40 | 30 | 1.2 | 4.0 |
| `taru` | Mi-290 Taru | 18.0 | 35 | 20 | 2.8 | 4.0 |
| `taru_lift` | Mi-290 Taru (Lift) | 18.0 | 35 | 20 | 2.8 | 4.0 |
| `tayran` | AR-2 Tayran | 11.0 | 50 | 45 | 4.0 | 5.0 |
| `technical` | Technical | 11.0 | 35 | 50 | 2.6 | 6.0 |
| `tempest` | Tempest Transport | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `tempest_ammo` | Tempest Ammo | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `tempest_medical` | Tempest Medical | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `tempest_repair` | Tempest Repair | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `tigris` | ZSU-39 Tigris | 8.5 | 75 | 38 | 1.9 | 5.0 |
| `truck` | Supply Truck | 9.0 | 45 | 35 | 1.1 | 4.0 |
| `van_ambulance` | Van Ambulance | 10.5 | 45 | 35 | 1.1 | 4.0 |
| `van_transport` | Van Transport | 10.5 | 45 | 35 | 1.1 | 4.0 |
| `varsuk` | T-100 Varsuk | 7.0 | 30 | 30 | 1.2 | 4.0 |
| `zamak` | Zamak Transport | 8.5 | 45 | 35 | 1.1 | 4.0 |
| `zamak_ammo` | Zamak Ammo | 8.5 | 45 | 35 | 1.1 | 4.0 |
| `zamak_medical` | Zamak Medical | 8.5 | 45 | 35 | 1.1 | 4.0 |
| `zamak_mrl` | Zamak MRL | 8.0 | 10 | 26 | 1.1 | 3.8 |
| `zamak_repair` | Zamak Repair | 8.5 | 45 | 35 | 1.1 | 4.0 |

The audit can be regenerated as JSON by adding `-- --audit-out=/absolute/path.json`
to `tests/fixtures/vehicle-motion.tscn`. Unarmed vehicles still have a return/aim
profile for consistent defaults; that does not give them a weapon. Tests exercise
both 30 and 60 Hz, heavy/light helicopter differences, bounded traverse and
braking, missing-shooter fallbacks, and separate banked gunship barrel origins.

## Boat movement audit

Boat rows above omit car-style hull yaw/acceleration/brake values: boats use
`Vehicle.BOAT_HULLS` and hydrodynamic forces rather than the land profiles.
The two armed riverine craft have the same hull and propulsion, so their movement
matches despite different faction names. These are loaded tactical cruise caps,
not guaranteed maximum speeds in ideal conditions. All handling values are tuning
estimates; the [US Navy Mk VI fact sheet](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2173363/mark-vi-patrol-boat/)
lists 25+ knots cruise and 35+ knots sprint, supporting a 13.5 m/s cruise cap for
the patrol ship rather than treating it as a slow displacement vessel.

| Boat | Cruise m/s (knots) | Full thrust m/s² | Engine response s | Helm hard-over s | Hull yaw response s | Low-speed radius m | Lateral acceleration cap m/s² | Astern thrust fraction |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RHIB | 18 (35.0) | 2.5 | 0.65 | 0.6 | 0.45 | 6.63 | 4.2 | 0.45 |
| Armed motorboat | 16 (31.1) | 2.1 | 0.8 | 0.7 | 0.55 | 5.7 | 3.6 | 0.4 |
| Both riverine speedboats | 15 (29.2) | 1.6 | 1.2 | 1.0 | 0.85 | 12.98 | 3.0 | 0.5 |
| Patrol ship | 13.5 (26.2) | 0.95 | 2.4 | 1.7 | 1.6 | 26.5 | 2.0 | 0.55 |
| Gun trawler | 5 (9.7) | 0.35 | 4.0 | 3.0 | 3.2 | 32.4 | 0.65 | 0.35 |

Thrust falls away against speed-dependent drag, so full thrust is not sustained
acceleration. Engine response is time from idle to full ahead; ahead-to-astern
reversal takes longer. Hard turns bleed speed through lateral slip. Radius is the
low-speed geometric parameter, not a promise of that radius at cruise: lateral
force limits widen fast turns. Helm alone at rest cannot rotate the hull; engine
wash can turn a boat as it gathers way. The trawler has weaker propeller wash,
slower helm and engine response, and weaker astern thrust than the jet patrol ship.
Stopping still requires drag and reverse thrust, not car brakes.

`vehicle-motion.tscn` checks all six boats at 30/60 Hz in open water, including
speed convergence, acceleration response, idle coasting, stopping and astern speed, turning speed loss,
relative hull responses and the no-flow/no-turn condition. `tests/boats.test.mjs`
checks navigation, backing, stopping, skid and beach landings on actual coastlines.

Measured time to 90% cruise from rest at 60 Hz: RHIB 11.68 s, motorboat 12.43 s,
both riverine craft 15.40 s, patrol ship 23.65 s and trawler 24.58 s.
