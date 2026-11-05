# Imported infantry animation coverage

Audited 2026-11-03 against the shared SoldierModel routing and local Mixamo files.
This is routing coverage, not visual approval. A clip appearing in the viewer does not mean gameplay uses it.

## Procedural action routes (26)

- `MELEE`
- `HEAL`
- `DRAG`
- `CARRY`
- `DRAGGED`
- `CARRIED`
- `VAULT`
- `DIVE`
- `SLIDE`
- `FLUNG`
- `FLINCH`
- `HANDSUP`
- `PICKUP`
- `PISTOL`
- `LAUNCH`
- `CLIMB`
- `IDLE_CHAT`
- `IDLE_LAUGH`
- `IDLE_SIT`
- `IDLE_STRETCH`
- `IDLE_CHECK`
- `IDLE_LOOK`
- `KICK`
- `SMOTHER`
- `COOK`
- `WINDED`

## Additional procedural or hybrid cases

- Cover lean/hiding and mounted-gun crew poses bypass standard captured locomotion. Mounted grips use target IK.
- Downed/writhing, wounded crawl, surrender/captive poses, dragging and carrying need appropriate clips and partner alignment.
- Physical ragdolls and blast flight should remain physics-driven; captured hit reactions can precede them.
- Installed prone clips supply entry, idle, forward/backward crawl, stops, firing, reload, full-body grenade throw and kneeling recovery. Terrain contacts and weapon grips still need correction; prone magazine events currently reuse standing reload timing and need clip-specific calibration.
- Crouch direction clips and stationary stand/kneel transitions are captured. Stance blending, toe flattening, foot contacts and knee direction remain procedural corrections; terrain IK belongs on top.
- Vehicle-specific sitting, boarding and piloting are not covered merely by installing a clip. Seat and hand anchors, timing and visibility still need integration.
- Without the optional imported actor/assets, the original procedural model remains a fallback.

## Already using captured base animation

Standing/crouched idle, walking/running, standard shooting/reload; grenade toss; stationary digging and smoking; prone entry; weapon stow/draw. Hit reaction is a captured upper-body overlay. Playground jumping also uses the installed rifle jump.

With the local Male Injured Pack installed, standing LIMP uses injured walk/idle and DAZED uses injured stumble idle. The rifle is slung, walk playback follows movement speed, and activity time persists while equipment transitions sample other clips. `injured_actions.tscn -- --swat-units` covers movement, idle, dazed and armed recovery. The other injured clips and Action Adventure Pack are candidates, not additional gameplay routes. The latter's tucked jump has not replaced the current jump.

The playground's prone key now uses the battlefield soldier's clearance/backstep logic, then settles before lowering. Directional movement cancels a pending backstep. The playground test includes a wall case; this does not certify all terrain or dynamic-obstacle combinations.

2026-11-05 validation: SWAT injury/recovery and playground controls/wall sequence pass and were rendered. The stricter `prone_backstep.tscn -- --swat-units` still fails its unchanged planted-foot speed limit: 0.108795 m/s versus 0.002 m/s allowed, with zero wall crossing and a 0.032740 m maximum joint step. Running the previous committed renderer/controller routing produces identical values. This existing foot-slide issue remains open; the passing wall test is not a no-sliding claim.

The playground jump samples that captured flight using vertical velocity and waits for physical ground contact before blending back to locomotion. Early, normal and delayed landing timing is covered by `tests/mocap/jump_timing.tscn`; this is not a new battlefield jump action.

## Installed but not fully routed

Sitting Idle, Piloting, Jostled Passenger, Entering Car, Exiting Car; rifle-pack turn/start/stop/death variants. Rifle Prone To Kneel now supplies the exit to crouched/standing locomotion.

## Catalog candidates verified on Mixamo

Source: https://www.mixamo.com/#/?page=1&query=crawl&type=Motion%2CMotionPack

Downloaded and locally installed prone family:
- Prone Forward, Prone Idle, Prone Forward Stop.
- Moving Backward In Prone Position, Prone Backwards Stop.
- Prone Firing Rifle (full body), Prone Reloading, Throw Grenade (prone).
- Existing Rifle Kneel To Prone and Rifle Prone To Kneel transitions.

Prone Backwards Start, Prone Left Turn, Prone Right Turn and Prone Roll are now imported and available in the viewer. Backwards Start is wired before the backward crawl loop; turns and roll are inspection clips, not gameplay routes yet.

Imported: Crouch To Prone, Prone To Crouch Transition, Rifle Prone Hit Reaction, Prone Death, and Crawl Backwards In Prone. The first three now supply gameplay entry, recovery and prone hit overlays. Prone Death and the alternate crawl are viewer clips; lethal gameplay still uses physical ragdolls, and backward movement uses the already validated rifle crawl.

Downloaded in this pass: Getting Up, Rifle Stand To Kneel, Rifle Kneel To Stand, Rifle Aim To Down, Rifle Down To Aim, crouched Throw Grenade, kneeling Grenade Throw, Smash and rifle Dive Roll. The stance pair and crouched throw are routed into gameplay. Getting Up, aim transitions, the longer kneeling throw, melee and roll remain inspection candidates until their timing, grips and action fit are validated. Jumping Over Into Combat and the 20-clip Pistol/Handgun Locomotion Pack are also downloaded and installed for inspection, not yet gameplay-routed.

Other visible candidates to preview before choosing:
- Grenade Throw — kneeling, pulling pin with teeth.
- Throw Grenade — crouched throw.
- Rifle Stand To Kneel; Rifle Aim To Down.
- Smash — strike with the back of a rifle or staff.
- Dive Roll — rifle dive roll (not automatically a suitable belly-down dive).
- Jumping Over Into Combat — obstacle crossing (must match obstacle height).
- Pistol/Handgun Locomotion Pack — 20 animations.

Generic Crawling (hands and knees), Low Crawl, Crawl Forward and zombie variants are also listed. Do not substitute these blindly for the armed prone family.

The site is a shared catalog, not a guarantee that all results belong to one coherent pack. Keep the existing SWAT target skeleton, preview the related rifle clips together, then test entry, loop, stop and exit with equipment and terrain contacts.

## Still needs sourcing/fit review

Medical treatment and paired casualty drag/carry; launcher handling; grenade cooking, kicking and smothering; exhausted/dazed/limping behavior; relaxed chat/laugh/stretch/check/look; ladder climbing and vehicle/mounted-weapon interactions. No exact matches are claimed for these yet.

## Current replacement progress

The shared actor routes the installed prone family, including moving rifle crawl instead of procedural sling/hand reach. Forward and backward crawl playback follows movement speed, stops settle to captured idle, and recovery returns to normal locomotion. Dedicated throw recovery does not replay the prone entry.

Focused captured-prone, stance interruption, native grip/hit recovery and crouch/throw regression tests pass. The controlled sequence was rendered and inspected. This is not full battle, uneven-terrain or multiplayer validation. The remaining SWAT catalog is not downloaded or integrated yet. Raw source FBXs remain local and ignored; this change does not package them for distribution.
