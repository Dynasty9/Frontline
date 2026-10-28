# Skinned rifleman and in-game evaluation

## Current demo

To record every locally installed clip once (at least two seconds per clip), run:
`godot --path . --fixed-fps 30 --write-movie build/catalog.avi tests/mocap/viewer.tscn -- --swat-units --record-catalog`.
The viewer labels each clip and prints its start/end times and `CATALOG PASS clips=N` on completion.
This is isolated animation playback; vehicle entry, seating and other available clips are not necessarily routed into gameplay.

Latest integration recording: `build/backstep-in-game-final.mp4` (8 seconds). A real server-controlled rifleman backs away from a wall, settles, and goes prone. The rendered regression measures 0.980 m retreat, 0.000093 m/s fully planted support drift and a 0.050 m maximum sampled joint step. Both character rigs also pass the isolated backstep fixture. Blocked rear paths and cancelled orders are covered without imported assets.

The default battle clock remains 30 Hz. Opt-in skinned characters use 120 Hz physics while simulation remains 30 Hz. The active inspection camera now controls detail selection, and animation movement uses the interpolated rendered position to avoid stepping through false sideways poses when reversing. Earlier battle/controller recordings and measurements below are development history, not final validation of this merge. WAN latency/loss and final art quality remain unverified.
Use `powershell -File tests/mocap/play_skinned.ps1 -Swat` for the in-game rifleman/tank
sequence, or add `-Controller` for playable movement on terrain. `-Viewer -Swat` opens
the animation, skeleton and projectile inspector. The military character is the local
`assets/local_mocap/mixamo/Swat.fbx`; the original preview character remains available
without `-Swat`. Assets remain local and Git-ignored.

The current shared controller includes captured directional movement, reloads, forefoot
support while running, terrain contacts, grips, recoil, hit reactions and skeletal death
handoff. Current local gameplay and rendered localhost multiplayer checks pass. Remaining work includes directional crouch,
finger posing, activity/vehicle interaction coverage and crowd performance;
this is still an evaluation prototype, not completed AAA character presentation.

The sections below retain the development history. Later measurements supersede earlier
results, particularly the class-cache audit, multiplayer death-order correction and
running forefoot support. The scenario now honors the launcher's `--seed=3`.

## Original preview asset

The original local asset is Vanguard by T. Choonyung / Mixamo, obtained as the Soldier.glb
example from the Three.js repository. It is an armoured science-fiction soldier,
not a photorealistic contemporary infantry asset. Its original skin weights,
normal maps and proportions are preserved.

Sources:
- https://github.com/mrdoob/three.js/blob/dev/examples/models/gltf/Soldier.glb
- https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

Adobe documents royalty-free use of Mixamo characters in games and films. Do not
assume the sample repository's code license grants standalone asset redistribution.
The character and MCO source pack remain in ignored `assets/local_mocap/`.

## Run

Use Godot 4.7.2 from the worktree root, after importing the locally installed assets.
The character file is `assets/local_mocap/character/Soldier.glb`. MCO setup is in
[README.md](README.md).

```powershell
godot --path . tests/mocap/skinned_demo.tscn -- --no-stun
godot --path . -- --scenario=motion --skinned-units --no-stun --port=7980 --focus=-1,-3 --zoom=12 --pitch=-20 --cam-yaw=3.6 --preset=ultra --set=ragdolls:true,dof:false --perf=0 --mood=day
```

`--skinned-units` also works in ordinary games: Coalition riflemen use the imported
skin. Other unit types retain their existing models. Missing local character assets
fall back to procedural units. The Field Manual keeps its procedural previews.

The motion scenario runs real squad AI, movement, aiming, damage and effects in the
actual game, plus scheduled damage at 8/17 seconds and tank hits at 10/22 seconds to
make reactions and deaths repeatable. These are staged demonstration hits, not
claims about randomly occurring combat. Host-authoritative state and FX replication
remain the source of truth; the skin and ragdoll are presentation.

## Animation and contacts

- Rifle idle/walk/jog share an AnimationLibrary. Different models preserve their
  own rest orientations and bone lengths; no source-mesh deformation is copied.
- Foot contact derives from the source gait. Planted feet retain world positions,
  pelvis height resolves reach, then analytical two-bone IK places the ankles.
- A single calibrated trigger-hand socket owns the rifle. The support arm reaches
  a fixed weapon-local foregrip. The muzzle effect comes from the imported gun. Both grip positions and the support
  palm orientation remain tied to the weapon. Fallback actions use their gameplay
  weapon direction, and put-away actions hide the imported rifle.
- Hit recovery is layered over the spine; firing gives the gun a damped kick.
- Actions absent from the sample use the existing gameplay pose transferred onto
  the same skin. This preserves crouch/prone and action semantics, but those actions
  do not become captured animation merely by using a skinned mesh.
- Death transfers the current Skeleton3D pose to thirteen jointed rigid bodies,
  retains travel/impact velocity, and drops a separate physical rifle. The game
  supplies its real terrain/cover collision layers. Physics is bounded in time
  and uses the existing active-ragdoll cap.

The free sample does not supply directional strafes, turns, prone rifle locomotion,
reloads, hit clips or get-up animations. A complete authored rifle set and final
military art remain necessary to reach a modern AAA character standard. Contact
checks are useful correctness evidence; visual quality still needs review in motion.

The showcase temporarily selects Ultra quality without saving player settings.
The game command explicitly enables ragdolls because existing user preferences may
disable them. The showcase ends after 34 seconds; the combat scenario can use
`--quit-after=28`. Record either with `--write-movie build/output.avi --fixed-fps 30`
before the `--` separator.

For this Windows worktree, `powershell -File tests/mocap/play_skinned.ps1` launches
the 28-second combat inspection; add `-Showcase` for the 34-second close-up sequence.
The launcher finds Godot on PATH or in the primary checkout's `build/tools/godot`.
`--motion-camera` cuts between the rifleman and tank without changing simulation.
The inspection capture reduces grass and particle density to make contacts visible.

## Verification in this worktree

- Godot 4.7.2 import: no script or parse errors.
- Full 34-second showcase: peak support-hand error 0.00000386 m and planted-foot
  error 0.00000382 m; 8,470 accumulated contact samples in the wall/floor sequence.
  These measure socket/ankle agreement, not a claim of photorealism.
- A complete 28-second battlefield run exercised two skinned hit reactions,
  one skeletal ragdoll, a tank hit and tank destruction. The scheduled blast is
  intentionally repeatable; surrounding combat uses the ordinary AI.
- Rendered multiplayer client: 3,756 entities received, including 18 soldiers and
  one vehicle; client exited without script/runtime errors after ten seconds of
  populated-world simulation. The host logged an existing ENet MTU warning.
- Changelog validation and whitespace checks passed. The rendered game still
  reports ObjectDB shutdown leaks (six in the latest reviewed run).

An earlier capture exhausted memory while many unrelated Godot test processes
were running. It was discarded. An earlier multiplayer test ended its host before
its slow rendered client finished and hit an existing co-command disconnect RPC
error; the subsequent populated-world client test completed cleanly.

Videos are local output under `build/`: `skinned-rifleman.mp4` (close-up),
`skinned-battle.mp4` (combat inspection), and `skinned-battle-wide.mp4` (wide battle).

## Uneven ground and stance handoff

`tests/mocap/stance_contacts.tscn` runs a 14-second regression with one boot on a
12 cm platform, kneeling, prone, returning to captured aiming, and walking.
It verifies independent ankle heights, maximum grip/contact error, and the first
frame of each switch between captured and procedural animation. The latest run
measured 2.60 mm peak planted-ankle error, below 0.002 mm support-hand error,
and a 16.3 mm maximum first-frame pelvis displacement at those switches.
The video is `build/stance-contacts.mp4`.

Battlefield foot placement now queries the real ground height at each contact;
stance handoffs blend over 0.24 seconds before contact solving. This smooths the
handoff but does not replace authored prone/get-up clips. A subsequent 20-second
rendered motion scenario and project import completed without script errors.

Purchase audit: the [MCO Rifle list](https://mocaponline.com/products/rifle)
explicitly lists crouch transitions and reloads, but prone/get-up coverage has not
been verified. Do not treat the generic Pro-tier description as proof of those
specific clips. The [Modular Male Soldier candidate](https://www.fab.com/listings/2ceaca60-9e68-495f-8e30-17055b091f0b)
uses Epic's skeleton and lists Unreal Engine as its included format; direct Godot
source availability is unverified. Neither is approved here as a complete purchase
solution for all required actions and final character art.

## Next asset trial: verified coverage, not yet imported

The next animation candidate is [Kubold Rifle Animset Pro on Fab](https://www.fab.com/listings/e0eed5c5-54a6-41cc-bfa9-62b26c309bca).
The seller listing showed a starting price of USD 59.99 before tax during this
review; check the selected license tier at checkout. The [publisher store](https://www.kubold.com/store)
confirms source FBX files are included for use in other engines.

The [published Unreal pack clip list](https://www.kubold.com/s/RifleAnimsetProUE4_List.pdf)
explicitly contains `Rifle_Idle2Prone`, `Rifle_Crouch2Prone`,
`Rifle_Prone2Idle`, `Rifle_Prone2Crouch`, `Rifle_Prone_Reload`,
`Rifle_Prone_Burst`, prone forward/backward locomotion and prone turns.
These address concrete gaps in the imported MCO sample. The Unity store splits
some prone coverage into a separate product: do not assume differently packaged
products have the same clip inventory. No paid pack has been purchased, imported,
or visually validated in this worktree yet.

A character candidate is [Slayver's Mercenary](https://slayver.artstation.com/store/72W6/mercenary).
Its publisher lists a separate skeletal FBX, 17,631 triangles, 2K PBR textures,
and Epic/Unity rig support. Those are useful source-format and RTS cost indicators,
not proof of deformation quality. Chrome's origin approval gate declined access
when attempting visual inspection. The model therefore remains an unreviewed
candidate, not a purchase recommendation. No download or purchase was attempted.

Once licensed sources are available, acceptance still requires an actual import:
check rest pose, shoulder and hip deformation, foot contact through each transition,
two-handed weapon reach, action timing, current-pose ragdoll handoff, and the same
rendered combat sequence. Store renders and numerical socket checks alone cannot
establish the requested visual quality.

## Hit reactions in fallback stances

Kneeling and prone previously advanced the impact spring without applying its
rotation to the skeleton. Both captured and procedural poses now apply the same
spine response before weapon contact solving. The stance scene delivers opposite
lateral hits at 4.8 and 6.8 seconds to exercise those paths.

The rendered 14-second run (`build/stance-hits.mp4`) completed without errors;
peak ankle error remained 2.60 mm and support-hand error below 0.002 mm. Reviewed
frames show maintained rifle contacts, but the reaction is subtle and the
procedural transition into prone still lacks an authored supporting-hand motion.
This fix is not evidence that the final animation quality goal is complete.

## Interactive animation viewer

Run `powershell -File tests/mocap/play_skinned.ps1 -Viewer`, or open
`tests/mocap/viewer.tscn` in Godot. It stays open until you close the window.
The list discovers all 17 installed rifle/mobility FBX animation files, including
root-motion and in-place variants. Horizontal root translation is normalized for
stationary inspection; the list is not claiming 17 unique performances.

Select a clip, pause, scrub its timeline, or change playback speed. Right-drag
orbits the camera and the wheel zooms. Foot contact correction can be disabled;
the original mocap mannequin can be shown to compare source motion with the
retargeted skin. Mobility clips hide the rifle because they are unarmed.

Click the skinned character to fire a visible projectile from the camera.
Choose a nonfatal reaction, fatal ragdoll, or heavy impact. Swept collision checks
hit the animated body segments or the environment; already fallen rigid bodies
can also be shot. Reset restores the character and replays the selected clip.
Impact testing is disabled while viewing the original mannequin.

`--viewer-test` cycles all clips, fires two camera-ray projectiles, checks hit and
death counts, and resets the actor before exiting. Use this after the scene path.
`viewer-test2.log` completed with 17 clips, two projectile hits, one ragdoll, and a successful reset; its error log is empty. The viewer screenshot was inspected for layout and legibility.


The source mannequin rifle now uses a fixed `RightHandMiddle1` socket. The socket
is calibrated once from the imported aiming reference, accounting for the trigger
and support knuckles being at different heights; it then follows the authored
bone rotation. This replaces per-frame aiming between the hands, which tilted the
barrel and discarded authored roll. The vendor Maya placement values are not
applied blindly as Godot-local transforms. `--source-model` opens the viewer with
the original mannequin selected; `--source-preview` additionally exits after three
seconds for visual captures. `--preview-clip=NAME` selects a source filename stem.

## Model inspection overlays

The Motion Lab's right-hand inspector offers shaded, shaded-plus-triangles,
wireframe-only, and skeleton-only modes. The triangle material uses the original
skinned mesh, so it follows animation and ragdolls without a separate rigid copy.
Skeleton lines and joint crosses draw the selected model's live bone poses in
X-ray. Major joint names can be shown, or select any bone (including fingers) to
highlight and label it. Switching between the source mannequin and retargeted
character refreshes the bone list and mesh statistics.

Counts describe the character's base-LOD triangle buffers, vertices, mesh instances
and surfaces. They exclude the gun, stage, and inspection overlays; these are asset
counts, not a GPU draw-call/performance measurement. `--inspection-preview` enables
bones and triangle overlay and exits after three seconds for screenshot checks.
Inspection verification: rendered triangle overlays follow the posed skin and ragdoll; the source skeleton-only view was inspected. The viewer regression passed all 17 clips, two projectile hits, one death, model switching, mesh modes, and reset without script errors.

## Mixamo SWAT trial

Install the user's downloaded `Shooter Pack.zip`, `Basic Shooter Pack.zip`,
`Ch15_nonPBR.fbx`, and `Rifle Kneel To Prone.fbx` from Downloads using
`python tests/mocap/prepare_mixamo.py`, then import the project in Godot.
All source assets remain under the ignored `assets/local_mocap/mixamo/` folder.

Launch `powershell -File tests/mocap/play_skinned.ps1 -Viewer -Swat` to select
Swat Guy instead of Vanguard and add the 32 installed Mixamo animation files to
the 17 MCO entries. Pack names are preserved in clip keys because overlapping
filenames are not proof of identical motion. Counts are files, not unique actions.
The SWAT mesh has 65 bones and 46,301 base-LOD triangles.

MCO clips use the existing retargeting/contact pipeline. Mixamo entries animate
the same SWAT rig directly, preserving authored foot motion and support-hand
release during reloads; the foot-correction and MCO-mannequin switches are disabled
for those native previews. Their rifle uses a separate socket calibrated in the
Mixamo aiming reference. One-shot actions hold their last frame rather than looping.
The with-skin transition FBX also contains a static `Take 001`; the loader explicitly
selects its actual `mixamo_com` motion (1.967 seconds).

`-Swat` also works with the showcase and combat launcher. Combat continues to use
MCO locomotion and existing procedural action fallbacks; the newly downloaded
Mixamo action clips are currently exposed in the viewer, not yet mapped to battle
state transitions. Additional prone-to-kneel and prone-idle downloads were not
present when this trial began.


## Playable rifle controller

Run `powershell -ExecutionPolicy Bypass -File tests/mocap/play_skinned.ps1 -Controller -Swat`, or choose **Play character** in the viewer. WASD moves relative to the camera, Shift runs, Space jumps, C/Ctrl toggles crouch, R reloads, and Home resets. Right-drag rotates the camera; the rifleman follows that heading while A/D strafe. The inspector and click-to-shoot impacts remain available. The back button returns to individual clip inspection.

`rifle_animation_controller.gd` accepts local velocity, grounded state, crouch state, and action requests. It blends phase-aligned forward/backward/strafe cycles, idle/run weights, and action entry/exit. The demo owns keyboard input and CharacterBody3D collision; these are separate from the shared pose driver. Jump height comes from physics, while the clip supplies the limb motion. Reload uses an upper-body layer so locomotion can continue.

The supplied M4's disconnected magazine is split into a separate mesh at runtime, retaining its UVs and material. It follows the left hand between removal and insertion, with magwell contact IK and a fixed trigger-hand socket. This profile is specific to the Basic Shooter reload and supplied M4; other weapons need their own grip and event timing.

Coverage limits: crouch borrows the MCO unarmed crouch pelvis/legs with a rifle upper body. There are no authored rifle crouch strafes in the installed packs. This playable controller is a local evaluation scene; battlefield units still use the existing mocap/procedural routing. Connecting the new driver to RTS actions, movement and authoritative reload timing remains separate integration work.

Validation: `controller.tscn -- --swat-units --controller-test` exercises walk/run, diagonals, backward crouch, bound jump/reload key press and release, landing, projectile death, and reset. A rendered 15-second run checks the same sequence. `build/controller-demo.mp4` records the latest pass.


## Ragdoll self-collision regression

Run `ragdoll_limits.tscn -- --swat-units --assert-ragdoll` with optional `--ragdoll-pose=crouch` or `--ragdoll-pose=prone`. The scene applies a repeatable impact toward a wall. It checks pose continuity, battlefield collision-layer overrides, capsule penetration between non-connected parts, and joint-anchor separation from one second after impact through settlement. Limits are 4 cm transient penetration and 5 cm joint separation; these are tolerances, not a guarantee of mathematically zero overlap.

Connected parts alone receive collision exceptions. The chest capsule extends down over the abdomen. Jolt position iterations are ten and contact slop is 5 mm, improving constraint accuracy at the project's 30 Hz tick rate. Large-battle CPU cost has not been benchmarked. Released props temporarily exclude overlapping owner parts until they clear them.


## Terrain controller trial

The controller now opens on a 40 m terrain patch with a dirt uphill/downhill track and rolling side banks. The terrain render mesh also generates the collision mesh. Per-foot raycasts supply height and surface normals to the shared pose driver; pelvis lowering keeps the downhill leg within reach. Leaving the patch and falling resets the character. This is confined to the motion lab, not a change to RTS map generation.

`--controller-test` now runs for 18 seconds and checks ascent above 0.8 m, descent below 0.2 m, jumping relative to local ground, crouch/backward movement, sole-reference penetration below 2 cm, magazine stow/replacement visibility, projectile ragdoll, and reset. The measured path climbed 1.56 m. `build/terrain-demo.mp4` is the rendered run. Sole-reference checks do not measure every skinned boot vertex or cover arbitrary cliffs.

The Basic Shooter reload profile hides the magazine from 0.68 to 1.12 seconds while the hand visits the pouch. Visibility is derived from playback time and restored outside reloads, including when scrubbing backwards.


## Foot transition regression

The old moving-foot anchor released at 22 cm and replaced foot orientation with a rest-derived slope pose. The playable driver now anchors only while stationary, fades contact influence and terrain normals, preserves captured toe-off, and uses the captured knee bend direction. A low-pass pelvis correction and locomotion transition filter precede final IK. Movement clips align their left-foot swing apex; idle advances on its own clock rather than freezing at the stopped gait phase. Imported loop endpoints crossfade over the last tenth of their cycle.

The controller enables SceneTree physics interpolation while open and restores the previous setting on exit. Reset clears contact and animation history and resets interpolation for body/camera. See https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_quick_start_guide.html .

The route test also limits the largest frame-to-frame IK correction change to 12 cm at 30 physics ticks per second. The previous driver measured 22.2 cm; the revised driver measured 10.7 cm. This metric measures solver correction, not absolute foot displacement or perceived animation quality. Ground penetration, ascent/descent, jump, reload visibility, ragdoll and reset checks remain in place. `build/smooth-motion.mp4` records the rendered run at 60 fps. The borrowed crouch motion and unmatched source pack styles remain asset limitations.

## Activity previews
The viewer loads the local `mixamo/activities` folder: Smoking, Digging, Sitting Idle (hands on thighs), Piloting, Entering Car, Exiting Car, and Jostled Passenger. These are preview-only clips; entry/exit are non-looping, and activity previews have no handheld rifle. `downloads.json` records the source and hashes beside the ignored FBXs.

Run `res://tests/mocap/activities.tscn -- --swat-units` for the shared gameplay fallback smoke/chat/sit regression. It checks back attachment and free hands. The procedural fallback is not the newly downloaded mocap; vehicle anchors and authored sling transitions remain outstanding.

## Native locomotion in live battles

With `--skinned-units --swat-units`, standing riflemen use the shared native directional driver. The loader now lives at `scripts/game/mixamo_clips.gd`; its animation libraries are cached per model and preview/gameplay subset. Procedural fallback remains for prone, reload and activity actions. Returning to standing resets contact history and blends the previous pose before solving foot contacts. `native_riflemen` reports installed drivers in scenario stats.

Standing gameplay reloads now feed normalized `act_time / rifle.reload` into the shared driver; magazine timings remain in source-clip seconds. `gameplay_reload.tscn` exercises completed and interrupted reloads through SoldierModel. `--reload-before` renders the procedural baseline without asserting the native magazine checks. The motion battle stages an empty-magazine reload at two seconds using the real soldier reload method. Prone/crouched reloads remain procedural.

The battle inspection camera follows the animated pelvis for living as well as ragdolled riflemen. It checks three sightlines across the body height, tries alternative sides and shorter distances, and uses an overhead fallback for enclosed subjects. `camera_clearance.tscn` verifies a face-only occluder that the former pelvis ray missed. Smoke is not a physics occluder and may still obscure footage.

Crouched gameplay reloads now use `overlay_reload` after the procedural stance. The Spine subtree is blended into the captured pose; all other local bone poses are restored before weapon placement. `gameplay_reload.tscn -- --swat-units --crouch-reload` checks unchanged world foot transforms plus completed/interrupted magazine states. The recorded result is `build/crouch-reload.mp4`. Prone and mounted-gun reloads remain separate outstanding work.

Stationary crouch fallback now applies `ground_kneel`: the left supporting boot uses its rest orientation and ankle clearance, while the rear toe determines its ankle height. Both use the shared two-bone IK and a contact weight fading over about 0.17 seconds with movement. The flat-floor reload test previously measured toe joints at -4.17/-6.40 cm; after correction they are +0.86/+0.86 cm. This checks joints and rendered boots, not all skinned vertices or arbitrary steep slopes.


## Mounted weapon coverage

Run `res://tests/mocap/mounted_grips.tscn -- --swat-units --gun=m2` (or `dshk`, `m240`, `pkm`). The scene uses `Structure.crew_stance`, the matching platform height and dimensions, and full traverse with recoil. It exits nonzero if either palm misses its anchor by 1 cm or sampled leg segments approach the platform within 7 cm. This is a contact check, not a complete skinned-mesh collision check.

Current rendered SWAT results: M2 and DShK pass (18 cm minimum leg-segment clearance). M240 and PKM fail: maximum palm errors 4.0/4.7 cm and leg joints enter the platform by 5.1/6.7 cm. Do not treat the paired-handle result as support for every mounted weapon. Trials that moved the body back and increased torso lean passed some contact checks but produced an excessively hunched pose; those runtime changes were removed. Lowering the pelvis also produced poor posture. The smaller guns need a fitted whole-body pose, including wrist orientation and supporting legs, rather than further increasing spine bend. Finger wrapping, turning steps, and reload choreography remain unfinished for all mounted guns.

The motion scenario assigns the inspection camera to each scripted reload/hit recipient. The camera holds unscripted deaths for 1.2 seconds before selecting a living rifleman, but preserves the staged blast subject from 17 to 22 seconds. `camera_clearance.tscn` verifies both selection rules. Battle counters establish that actions occurred; footage is still required to assess their visibility and quality, especially prone reloads that use the procedural fallback.

`gameplay_stances.tscn -- --swat-units` tests actual SoldierModel transitions, including interrupted rises and drops. Corrected kneeling feet previously jumped 40.5 cm in one physics step because all procedural postures shared a blend state. Distinct posture states and 0.65-second whole-body blends reduce the maximum sampled joint displacement to 12.7 cm. The test limits it to 15 cm at 30 Hz and checks head-joint ground clearance. It does not establish whole-mesh collision clearance or natural authored prone motion.

Stationary prone idle/shooting in the optional SWAT gameplay path now plays the downloaded `Rifle Kneel To Prone` clip and holds its final supported pose. The shared driver handles interruptions and weapon attachment. `gameplay_stances.tscn` verifies that the captured branch is used and the settled head remains above 23 cm on flat ground. Crawling, prone reloads, over-cover aiming, slope fitting, and an authored get-up remain separate work. `prone_capture.tscn` previews the unmodified captured clip for comparison.


## Gameplay prone-to-ragdoll handoff

`ragdoll_limits.tscn -- --swat-units --ragdoll-pose=gameplay_prone --impact-at=1.0 --assert-ragdoll` now drives SoldierModel through the captured prone clip and calls the real `PhysicsFx.ragdoll` entry point with a Soldier holder and minimal world-stat stub. It verifies every bone transform across creation and a following dead-model pose update, uses game ground/cover collision layers, and checks that the pelvis does not fall through the ground. The other existing ragdoll poses keep their previous viewer path.

Impacts at 0.35, 1.0, and 2.5 seconds pass. After one second of settling relative to each impact, maximum nonadjacent capsule overlap across those runs was 1.19 cm and joint-anchor separation 2.46 cm. The complete run at 1.0 seconds is recorded in `build/prone-handoff.mp4`. These are focused physics checks, not a multiplayer death-event test or whole-mesh collision proof. The final prone pose also showed an initial 12 cm joint-anchor discrepancy before settling; unchanged bone transforms at creation do not prove the subsequent constraint correction is visually smooth. That initial constraint response still needs inspection.

The initial prone shoulder-anchor mismatch is now corrected: `SkinnedRagdoll.anchors` stores the captured parent-local attachment used by PhysicsServer3D. Joint angular frames and limits remain bind-pose based. The handoff test asserts configured attachment alignment below 1 mm. It separately reports `first_second_separation`; this still reaches about 9 cm in the mid-transition impact and is not covered by the settled 5 cm threshold. Larger solver increases and flexion-limit trials were removed because they did not consistently resolve the early response. Eight position iterations retain the existing settled overlap/separation checks across idle, crouched, and prone fixtures; broad load profiling is still outstanding.

Ragdoll drawing now preserves captured local bone positions, drives the pelvis from physics, and aims simulated body segments toward their child bodies while retaining twist. This prevents solver separation from stretching the skin. The tests check bone-length error below 1 mm and settled skin-to-collider origin offset below 5 cm. SWAT idle/crouch/prone and the older character idle fixture pass; early physical separation is unchanged and remains separately reported.

`ragdoll_budget.tscn -- --swat-units` checks 16 active ragdolls, replacement by a 17th, duplicate death handling without another eviction, weapon reparenting, and physics cleanup after 14 seconds. `build/ragdoll-budget.mp4` records the passing fixture. Reported timing percentiles summarize samples of Godot's physics monitor, which may repeat cached readings; they are observations rather than a full-battle frame-time benchmark.

`ragdoll_limits.tscn` accepts `--impact-kind=0` (bullet), `1` (blast, default), or `2` (collapse). With `--ragdoll-pose=gameplay_prone`, these exercise the actual `PhysicsFx.ragdoll` handoff and assert each body's initial velocity before simulation. Bullet velocity is applied fully to Spine2 and at 15% to other parts, matching the original ragdoll policy; blasts affect every part and collapse retains only travel. The released rifle also respects the death type. All three retain the captured pose and existing settled collision/skin checks. Initial constraint separation remains a separate limitation.

Knee frames now use the captured thigh/shin bend plane, with flexion on the frame's X axis and unchanged 2.4-radian flexion / 0.04-radian lateral limits. Nearly straight knees keep the rest-frame fallback. The knee-only change passes SWAT standing/crouched/prone blast fixtures and the older character's standing fixture; the analogous elbow trial was removed because it worsened early separation and failed the older rig's skin-offset bound. The fixture now reports and bounds initial non-connected capsule overlap separately; none was found in these poses. In the captured prone blast, settled skin offset decreased from 2.45 cm to 0.76 cm, while first-second separation remains about 9 cm.

Living game poses, the viewer, playable controller, and showcase now call `capture_motion` after final contact/grip corrections. `ragdoll_momentum.tscn` analytically checks root-translation cancellation, a known forearm translation/rotation, center-of-mass velocity at death, weapon travel, and reset behavior on both character rigs. `ragdoll_limits.tscn -- --swat-units --ragdoll-pose=jog --impact-kind=0 --assert-ragdoll` exercises an animated moving collapse. `build/momentum-jog-framed.mp4` and `build/battle-momentum.mp4` record the focused and game scenarios. Early separation is still unresolved; sampled animation motion changes the settling trajectory, so the earlier knee-only metrics are historical comparisons, not current guarantees.

`reload_death.tscn -- --swat-units --reload-death-at=1.3` exercises a fatal hit during the captured gameplay reload. Tested clip times 0.2, 0.6, 0.9, 1.3, and 2.0 cover seated, removed, stowed, replacement-in-hand, and reinserted states. Checks cover unchanged handoff transform, independent body/drop, indexed magazine vertices above the ground, timed cleanup, and revival. `--reload-death-before` suppresses the detach marker to reproduce the former shared-rifle behavior for comparison; it is a fixture-only baseline. The collision bounds use only indexed magazine vertices because the split ArrayMesh retains unused rifle vertices. `build/reload-drop-after.mp4` records the corrected case.

`prop_contacts.tscn -- --swat-units` holds a rifle overlapping the pelvis, verifies that protection remains, moves it clear, then drops it onto the frozen owner and verifies actual contact. This uses gameplay ragdoll layer 16. Standing/prone blast and jogging bullet limit fixtures, the reload-drop fixture, and the 16-body budget fixture pass with temporary prop exceptions. `build/reload-owner-contact.mp4` records the corrected release. The jogging **blast** limit fixture currently fails torso/forearm overlap: 4.73 cm with restored contacts, 5.66 cm with permanent exceptions in the comparison run. The 4 cm assertion remains unchanged; this newly exercised moving-blast case is unresolved.

Ten position iterations resolve the previously failing jogging-blast settled-overlap check: 4.73 cm at eight iterations becomes 1.66 cm at ten. Impact times 0.6, 1.0, and 1.4 seconds pass the existing settled checks, as do SWAT standing/crouched/prone and the older character standing. The 0.6-second jog impact still reaches 13.2 cm of first-second joint separation, which is reported separately and remains unfinished. The 16-body budget fixture passes; its cached monitor readings are not a full-battle CPU benchmark. `build/jog-blast-after.mp4` records the corrected landing, and `build/battle-contacts-solver.mp4` records the combined gameplay changes.


### Hinge direction audit (2026-10-21)

This supersedes the historical passing results above. The captured bend-plane frame has positive physical flexion, but Godot/Jolt angular limits use the opposite sign. Knees and elbows now allow API X angles -2.4 through +0.03 radians. Asymmetric rest-frame fallback limits are corrected as well. `hinge_direction.tscn -- --swat-units` reads the actual right-knee bounds and applies them to an isolated 1.5-radian hinge: it retains 1.5, while the reversed control snaps to -2.4. This passes on Godot 4.7.2.

Current project configuration remains 30 Hz, ten position iterations and default velocity iterations. Standing bullet collapse passes (2.90 cm settled anchor separation, 2.87 cm skin offset); see `build/hinge-sign-corrected.mp4`. Standing and crouched blasts and the original character standing blast FAIL the unchanged settled checks (about 6-7 cm anchor separation); crouched skin offset reaches 8.83 cm. Jogging blast at 1 second passes. These failures are not waived. Higher solver-iteration experiments were removed because they did not consistently resolve them.

The fixture accepts `--physics-hz=60` for timestep diagnosis only. SWAT idle/crouch/jog/gameplay_prone blasts all pass at 60 Hz, with settled anchor gaps 4.06/2.12/2.43/0.27 cm and first-second gaps 4.14/3.86/4.85/3.97 cm. Changing the global game tick requires gameplay and performance validation; production remains 30 Hz. The fixture also reports initial floor overlap, anchor velocity mismatch, knee flexion, and the joint/time of the worst first-second separation. `--without-animation-momentum` isolates sampled motion: it did not resolve the original jogging knee snap.


### 60 Hz project validation (2026-10-21)

The project now uses 60 physics ticks per second. `main.gd` no longer overrides that setting to 30 when `--timescale` is supplied. This supersedes the 30 Hz configuration described above. No assertion tolerances were widened. The older rig's standing blast passes (3.54 cm settled gap); jogging blast impact times 0.6 and 1.4 also pass. The 0.6-second impact still reaches 6.67 cm early separation, so this is not proof of perfectly rigid connections throughout impact.

Current-project checks: terrain controller PASS (0.018 cm maximum foot penetration, 7.21 cm contact change, jump/reload/stow/replacement/impact/reset); 16-ragdoll eviction, duplicate-death and cleanup PASS; attack seed 3 reaches 30 seconds; AI-v-AI seed 3 reaches 120 seconds; host/client port 7965 completes with 3,749 received entities. No script errors were found. Attack and AI-v-AI retain the prior seven-object/two-resource shutdown warnings. Network coverage is a replication smoke test, not a visual multiplayer ragdoll comparison.

`build/battle-60hz.mp4` records 28 seconds of actual gameplay with reload, soldier hits, a skinned ragdoll and tank destruction. The contact sheet confirms those presentations, but smoke partly obscures the fall. A separate unrecorded small motion scene reports 161.1 FPS and 0.90 ms server tick on the local RTX 3090 system (`build/tick60-perf.log`). This is not a large-battle benchmark or an isolated before/after performance comparison. Changing the simulation rate changes seeded combat outcomes; balance and large-battle performance remain to be evaluated.


### Smoke-aware inspection camera

The optional combat camera now ranks cover-clear infantry viewpoints using the length of the eye-to-pelvis segment inside active smoke spheres. It reads both fire smoke and smoke-grenade projectile radii, matching the gameplay line-of-sight sources. The camera clearance test checks a blocked preferred view, selection of a smoke-free alternative, starting inside smoke, and a region behind the subject; cover clearance and subject-retarget assertions remain enabled. Project import and the fixture pass.

`build/battle-smoke-clearance.mp4` records the updated 28-second sequence. Persistent smoke is less obstructive in the reviewed frames, while the transient blast dust still conceals the initial fall around 17.6 seconds. The following landed body is visible. Blast particles are not part of the gameplay smoke-sphere lists. The unchanged scenario still records reload/hit/blast/skinned_ragdoll/tank-destruction events, but its combat counts differ from the previous recording despite seed 3, so those recordings are not a controlled gameplay-equivalence comparison. Six ObjectDB instances are reported at shutdown; no script errors were found.


### Authored locomotion stride

MixamoClips retains horizontal hip-root travel as animation metadata before removing root translation. The shared controller scales that travel through the character skeleton transform and blends distances using the same directional/run weights as the poses. Clips with no measurable travel retain the previous 1.8-m fallback and need explicit stride authoring if introduced as locomotion replacements.

Measured distances in metres: walk 1.356, run 2.304, backward walk 1.499, backward run 1.373, left strafe 1.426, right strafe 1.076. `stride_sync.tscn -- --swat-units` compares actual foot motion with authored stride lengths against the old 1.8-m clock after warmup. All six samples reduce mean planar ankle speed while near the floor: forward walk 0.821 to 0.707 m/s; forward run 2.155 to 2.051; backward walk 0.881 to 0.818; backward run 1.715 to 1.488; left strafe 1.262 to 1.224; right strafe 1.247 to 1.087. These residual speeds are substantial: this is a timing correction, not completed foot planting. The 3.5-cm ankle-height proxy includes contact transitions and is not a full sole-contact model.

The rendered terrain controller passes unchanged thresholds, with maximum contact-correction change decreasing from 7.21 cm to 6.00 cm and maximum sole penetration 0.0082 cm. Gameplay reload stow/replacement/interruption also passes. `build/controller-authored-stride.mp4` records the route, including jump, crouch, reload, ragdoll and reset. Still images illustrate different phase timing but do not alone prove temporal smoothness.
`build/battle-authored-stride.mp4` records the shared stride change in the motion battle with the smoke-aware camera. Reviewed frames show the infantry, tank impacts, ragdoll aftermath and wreck; the blast remains partially obscured. The run reports six ObjectDB instances at shutdown and no script errors.


### Moving-step anchors

The shared controller plants below 2.5 cm authored lift, releases above 6.5 cm or 28 cm horizontal stretch, and rearms after a swing. Plant weights fade over roughly 83 ms; reach influence tapers from 12 to 28 cm and existing target smoothing remains. Jump and reset clear both weights and anchors. The fixture also forces a one-metre overreach and checks release, then verifies airborne/reset cleanup.

With authored stride retained, mean near-floor ankle speed changes from 0.707 to 0.640 m/s walking forward, 2.051 to 2.047 running forward, 0.818 to 0.798 walking backward, 1.488 to 1.065 running backward, 1.224 to 1.148 strafing left, and 1.087 to 0.945 strafing right. The existing old-stride comparison still passes in all six samples. These are aggregate ankle proxies, not proof of perfect planted soles. Forward running remains essentially unchanged.

The rendered controller route passes unchanged checks: maximum correction change 5.99 cm, negligible sole penetration, and successful jump/reload/stow/replacement/ragdoll/reset. `build/controller-foot-plants.mp4` records it; `build/foot-plant-run-detail.jpg` samples one running second at ten frames per second. Those frames retain a coherent leg swing, but remaining sliding and full temporal quality need more work.
`build/battle-foot-plants.mp4` records the current shared controller in gameplay. Reviewed frames include infantry movement, tank impact, the fallen skinned body and tank wreck. No script errors were reported; six ObjectDB instances remain at shutdown.


### Preserve captured gait (extra pose filter removed)

The per-bone exponential locomotion filter reduced the effective stride and delayed contact. Removing that filter (including its stored pose array) reduces near-floor ankle drift in all six samples while retaining movement velocity blending, the pose-transition blend, and action blending. Forward run changes from 2.047 to 1.146 m/s; forward walk 0.640 to 0.511; backward walk 0.798 to 0.646; backward run 1.065 to 0.745; left strafe 1.148 to 0.964; right strafe 0.945 to 0.546.

An additional toe measurement matters because ankle motion includes foot roll. Forward-run near-floor toe speed changes from 1.836 to 0.634 m/s. Other current toe speeds are 0.907 forward walk, 1.382 backward walk, 0.532 backward run, 1.652 left strafe, and 1.019 right strafe. These still leave significant contact work; they do not establish a perfectly stationary sole. A toe-height planting/pivot experiment did not solve the issue and was removed.

The old assertion that authored stride must always beat a 1.8-m clock failed for backward running after the filter removal (0.745 versus 0.665 m/s ankle drift). That comparison is not a physical invariant: the arbitrary clock can accidentally compensate for other pose effects. The test retains those diagnostic numbers but now enforces explicit absolute ankle limits [0.6,1.3,0.7,0.85,1.05,0.65] and toe limits [1.0,0.75,1.45,0.65,1.8,1.15], ordered forward walk/run, backward walk/run, left/right strafe. Both sets improve on the preceding controller's measured values. Asset-stride checks and anchor/jump/reset checks remain.

The terrain route passes unchanged limits, with maximum foot-contact correction 7.09 cm and negligible penetration. Gameplay reload stow/replacement/interruption passes. `build/controller-unfiltered-gait.mp4` is the recorded route; `build/unfiltered-run-detail.jpg` samples a running second at ten frames per second for pose inspection.
`build/battle-unfiltered-gait.mp4` records the current gameplay path. Reviewed frames show riflemen, the staged tank hit, fallen skinned body and tank wreck. The recording has no script errors and reports six ObjectDB instances at shutdown. Blast visibility remains imperfect.


### Foliage clearance and quick-exit teardown

The optional combat camera collects nearby bush bounds from existing Grass chunks and rejects eye-to-body rays through them. It includes mesh instance transforms, terrain deformation and a 20-cm allowance for leaf displacement. Bushes removed by deep deformation are skipped. These are conservative visual bounds, not new gameplay colliders. Fully enclosed subjects, other units and transient blast dust can still obstruct a view.

The camera fixture creates a non-colliding bush, verifies obstruction, and finds a clear alternative. Headless Godot's dummy renderer returns identity GPU instance transforms, so the headless fixture uses an equivalent node transform; the rendered fixture exercises the actual MultiMesh instance transform. Both pass along with cover, smoke, subject-retarget and ragdoll-hold assertions. `build/battle-foliage-clearance.mp4` is the reviewed 28-second battle recording; the fallen rifleman remains visible in its sampled post-blast frames. Before/after recordings differ in combat details and are not a controlled simulation-equivalence test.

The first quick rendered fixture also reproduced a music shutdown race (`_wav` and `_render` called on a previously freed object). Music now joins its outstanding synthesis task in `_exit_tree` before its state can be freed. The same rendered fixture subsequently exits without script errors. This does not resolve all previously observed ObjectDB shutdown warnings in full battle recordings.

### Active-camera animation rate and crowd profiling

Soldier animation LOD now uses the viewport's current camera. Previously the inactive RTS camera could throttle a close-up inspection subject to one update every six frames. `camera_animation_rate.tscn` exercises the real Soldier view path with a pose counter: 12 close-up frames produce 12 poses, 12 off-screen frames produce two, and switching back resumes immediately. Crew animation remains exempt from distance throttling.

`scaling.tscn` adds 12 rifle squads to the real motion scenario (71 soldiers, 52 skinned with the SWAT flags). Run with the normal motion flags plus `--timescale=2 --perf-at=5 --novsync --focus=0,16 --zoom=52 --pitch=-40`. It reports frame percentiles, the existing overlay's smoothed visual-system CPU averages, and renderer CPU/GPU timings. Its root is named Main so the existing overlay can locate World; the previous Scaling root prevented that profiler from collecting its breakdown.

The profiled local run (`build/scaling-profiled.log`) measured 43.2 FPS, 20.83-ms median and 38.89-ms p95 frame times, approximately 8.23 ms for soldier view updates, 2.43 ms for grass, and 4.86 ms GPU render time. These timings overlap and should not be summed. Earlier unprofiled runs reported 25.3 FPS skinned and 33.6 FPS procedural; run-to-run combat, warm-up and system-load variation prevent claiming an improvement from those numbers. No animation performance optimization has been established by this comparison. Soldier view CPU remains the largest measured visual subsystem cost.

The camera-rate fixture passes both headless and rendered. The project import is clean. The fresh 28-second recording, build/battle-active-camera.mp4, shows the moving riflemen, tank hit, fallen skinned rifleman and tank wreck in reviewed frames. The recording has no script errors but reports eight ObjectDB leaks on exit. Still frames do not prove temporal smoothness; the camera-rate assertions establish the update-frequency fix. Remaining foot sliding, transient blast obscuration and full-battle performance are unresolved.

### Bounded horizontal foot corrections

The contact target already eases through plant/release weights, but a second exponential filter on its horizontal offset made planted feet lag behind world anchors. Directly assigning that offset improved flat-ground drift but failed the unchanged terrain-route limit: a 13.62-cm correction change occurred at 1.083 seconds during movement startup. The retained implementation instead moves the horizontal offset toward its target at no more than 4 m/s. Ordinary rifle locomotion can track its anchor without filter lag, while abrupt plant/release corrections remain bounded. Vertical smoothing is unchanged.

Current six-case ankle drift (m/s, forward walk/run, backward walk/run, left/right) is [0.358, 0.789, 0.557, 0.215, 0.720, 0.291], versus the preceding controller's [0.511, 1.146, 0.646, 0.745, 0.964, 0.546]. The corresponding toe measurements are [0.959, 0.660, 1.330, 0.542, 1.558, 0.980]; forward walk/run and backward run are slightly worse, while the other three improve. Near-floor point movement includes authored foot roll and is not a pure planted-contact metric. Residual sliding remains.

The stride fixture now enforces tighter ankle limits [0.4, 0.85, 0.6, 0.3, 0.8, 0.35] and retains the previous toe limits. The terrain route passes its unchanged 12-cm correction limit with 7.11 cm maximum, negligible sole penetration, and jump/reload/magazine/ragdoll/reset checks passing. Controller failure output now includes the worst correction magnitude and time, so a contact failure can be located without another instrumentation edit. Logs: build/bounded-plants-stride.log and build/bounded-plants-controller.log. The rejected unbounded experiment remains only in build artifacts, not production code.

Rendered validation: build/controller-bounded-plants.mp4 passes the same route assertions, and build/bounded-plants-run-detail.jpg samples one running second at 10 fps. build/battle-bounded-plants.mp4 records the current actual gameplay path for 28 seconds; reviewed frames show rifle movement/shooting, the tank impact, the fallen skinned rifleman and tank destruction. No script errors were logged; six ObjectDB leak warnings remain at shutdown. These recordings do not establish final AAA-quality animation or multiplayer parity.

### Captured rifle firing recoil

The gameplay firing event already called SoldierModel.fire_kick, but native animation paths never advanced or applied SkinnedRifleman's recoil spring. The procedural weapon seating path did. Captured movement, captured prone and native previews now apply the spring as a small upper-chest rotation around the weapon's right axis before placing the rifle. This moves the authored hands and rifle together instead of translating the gun away from the support hand. Procedural seating retains its existing recoil handling.

native_recoil.tscn tests four actor headings: upward muzzle motion, unchanged weapon-relative support-hand transform, unchanged planted foot and spring recovery. It checks that all three captured entry points consume firing events and that sixteen world-space incoming-hit combinations move the head along the projectile direction. The rendered six-second burst preview is build/native-rifle-recoil.mp4, with 10-fps sampled frames in build/native-rifle-recoil-detail.jpg. The ragdoll momentum fixture also passes root/limb/COM/weapon inheritance and reset checks. This is a layered procedural recoil response, not a newly acquired authored firing animation.

The current gameplay recording is build/battle-native-recoil.mp4 (28 seconds). Reviewed frames include firing riflemen, a tank impact, a fallen skinned rifleman and the tank wreck. No script errors were logged, but eight ObjectDB leaks remain on exit. Project import and changelog validation pass. Multiplayer and high-count performance were not rerun for this recoil-layer change.

### Clean revival and demo reset

SkinnedRifleman.reset_motion clears sampled poses, limb motion, root velocity and both impact/recoil springs, then records the current root position as the travel origin. Revival calls it after leaving the dead state. The controller and viewer call it after teleporting the actor to the reset position, including resets while still alive. Previously revival retained spring offsets/velocities, and the viewer cleared only its incoming-hit spring. A reset teleport could also enter the following procedural pose as root travel.

The momentum fixture now primes both springs before death, verifies all transient state is cleared on revival, then checks a live reset and teleport followed by a real procedural pose. It retains the existing root/limb/angular/COM/weapon inheritance assertions. The fixture passes in build/reset-impact-momentum.log. This resets transient presentation motion; it does not add an authored get-up animation.

Rendered controller validation also passes all unchanged route checks, including lethal impact and reset, in build/controller-clean-reset.log. build/controller-clean-reset.mp4 records the route; build/controller-clean-reset-review.jpg samples the death/reset interval at four frames per second. Project import and changelog checks pass. This turn did not rerun full battle or multiplayer validation.

### Wall-impact regression and captured running handoff

ragdoll_limits.tscn now supports --wall-impact with a 6 m/s blast toward a measured wall face. The fixture requires actual reported wall contact, measures capsule penetration against the front plane throughout the collision, and asserts that every measured capsule remains within that face's extent. This prevents a missed wall or a trip around its edge from passing. The original self-overlap, joint-gap, skin-offset and bone-length limits remain enabled with --assert-ragdoll. --ragdoll-pose=rifle_run uses the shared native rifle controller and samples its moving limb velocities before death.

Standing wall impact measured 8.1 mm maximum penetration. Captured running at impact times 0.6, 1.0 and 1.4 seconds measured 35.0, 39.3 and 22.1 mm respectively, below the new 40-mm wall limit. Corresponding settled joint gaps were 3.6, 8.9 and 14.5 mm, and first-second gaps 44.0, 42.5 and 41.2 mm. All cases confirmed wall contact and passed existing body/skin bounds. This is finite tolerance, not a claim of zero penetration or arbitrary-speed collision coverage. Logs: build/ragdoll-wall-impact.log, build/rifle-wall-early.log, build/rifle-run-wall-impact.log, build/rifle-wall-late.log.

Run from the worktree: godot --path . tests/mocap/ragdoll_limits.tscn -- --swat-units --wall-impact --ragdoll-pose=rifle_run --assert-ragdoll. The wall mode has a closer inspection camera. Production physics was unchanged by this validation work.

The closer rendered run is build/rifle-wall-closeup.mp4; sampled collision/settling frames are build/rifle-wall-closeup-review.jpg. The negative control (--wall-impact --impact-kind=2 with the stationary pose) deliberately produces no wall contact and exits with failure, confirming that zero penetration alone cannot pass. Wall measurement failures now exit with status 1 rather than leaving the scene running. No production physics changes or multiplayer revalidation were made in this wall-test pass.

### Wall penetration diagnosis

The wall fixture now reports the worst body and time, identifying the native-running baseline as RightForeArm at 0.183 seconds after impact (39.28 mm). Isolated startup-setting experiments were restored afterward: doubling velocity steps to 20 worsened penetration to 43.61 mm; doubling position steps to 20 worsened it to 56.03 mm. Both failed the existing 40-mm wall limit. Reducing continuous_cd_movement_threshold from 0.75 to 0.25 improved this one sample to 33.78 mm; reducing continuous_cd_max_penetration from 0.25 to 0.05 produced 38.01 mm with RightArm becoming the worst part. These are single-case experiments, not broad improvements, and none was retained in project.godot. The existing 10 position steps, default velocity/CCD settings and 5-mm penetration slop remain.

Godot's setting definitions were checked against https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html : the CCD movement threshold and allowed penetration are fractions of a body's inner radius. The measured residual is therefore not resolved by simply increasing solver iterations or reducing one CCD allowance. Logs are build/wall-solver-velocity20.log, wall-solver-position20.log, wall-solver-ccd_threshold.log and wall-solver-ccd_penetration.log. build/probe_wall_solver.py is an ignored diagnostic helper that restores the original project bytes in a finally block; it is not part of the runtime.

### Coherent blast angular handoff

The previous blast path added the same angular velocity to every body but omitted the corresponding tangential velocity at each limb's center of mass. Connected anchors therefore started with inconsistent velocities even for a frozen character. The ragdoll now computes the captured mass-weighted center and adds omega cross (limb COM minus body COM) alongside the shared blast spin. Sampled animation motion, root travel and the direct blast velocity remain separate contributions. Bullet and collapse paths have zero added blast spin.

The new no-animation wall case checks anchor velocity agreement below 0.001 m/s; it measures about 0.00000049 m/s. Running impact at 1.0 seconds improves initial anchor velocity mismatch from 0.737 to 0.218 m/s; remaining mismatch comes from sampled limb motion. The 0.6/1.4-second running cases measure 0.103/0.181 m/s. Existing wall, self-overlap, joint separation and skin-length limits all pass for these running cases, stationary SWAT, crouch, gameplay prone, original-model standing and SWAT bullet impact.

This is not a universal penetration improvement: running wall penetration is now 32.5/39.1/23.9 mm at impact times 0.6/1.0/1.4, while the stationary no-animation wall case is 33.8 mm (previously the stationary baseline was 8.1 mm). Different angular motion changes which limbs hit the wall and when. The 40-mm wall bound remains unchanged. The moving blast recording is build/rifle-coherent-blast.mp4, with reviewed collision frames in build/rifle-coherent-blast-review.jpg. All detailed measurements are in build/coherent-blast-*.log. The project-wide physics settings remain unchanged.

The actual-game recording build/battle-coherent-blast.mp4 completes 28 seconds without script errors. Reviewed frames show firing riflemen, tank impact, the fallen skinned blast victim and tank destruction. Six ObjectDB leaks remain on exit. Project import and changelog validation pass. Multiplayer and crowd performance were not rerun for this handoff correction.

### Recorded-audio shutdown diagnosis and cleanup

A verbose ordinary rendered motion run exits without ObjectDB leaks (build/mocap-shutdown-verbose.log). The matching recorded run reports three AudioStreamWAV and three AudioStreamPlaybackWAV objects on Effects/Ambience buses (build/movie-shutdown-verbose.log), not leaked ragdoll bodies or character meshes. tests/mocap/audio_exit_probe.gd reproduces a single stream/playback leak with only a looping audio player under --write-movie. Adding --drain-audio stops the player, clears its stream and allows two process frames before quitting; that control exits without leaks. Logs: build/audio-exit-raw.log and build/audio-exit-drained.log.

The game's --quit-after recording path now pauses the scene, prevents Music/Sfx from starting further playback, stops all audio-player types and clears their streams, then allows two final recording frames before quitting. Ordinary timed runs retain immediate shutdown. This specifically addresses the recorded-audio cleanup issue; it does not claim that every application exit path or engine resource is leak-free. The probe can be run with godot --verbose --path . --fixed-fps 60 --write-movie build/audio-exit.avi --script tests/mocap/audio_exit_probe.gd -- --drain-audio; omit --drain-audio for the known failing control.

Recording detection uses Engine.get_write_movie_path(), not OS.get_cmdline_args(): the initial command-line flag check did not enter the drain branch. The paused minimal probe also exits without leaked audio objects (build/audio-exit-paused.log), matching the production shutdown sequence.

Full recorded-battle validation now exits without ObjectDB, leaked-instance or script-error messages (build/battle-audio-drained.log). The movie has 1683 frames at 60 fps, including the two cleanup frames; build/battle-audio-drained.mp4 is the saved result. Its 20-27-second audio window remains present (mean -31.7 dB, peak -10.3 dB), and the final tank-wreck frame was inspected. The asserted paused probe also exits cleanly (build/audio-exit-verified.log). This supersedes the earlier audio-leak limitation for timed recordings; multiplayer and other quit paths were not revalidated.

Native locomotion support grip: rifle_animation_controller captures the idle wrist relative to the rifle and solves the existing left arm IK after locomotion/contact/recoil blending. Action weight releases the constraint for jump/reload. SWAT six-direction palm drift falls from 28.4 mm maximum to 6.6 mm; full running reach remains the limiting case. tests/mocap/native_grip.tscn checks six directions and an authored reload release relative to forearm length. Original preview rig native clips have a separate scale mismatch, so their smaller absolute errors are not comparable. Native recoil checks and the rendered terrain route pass; build/controller-support-grip.mp4 and its contact sheet were reviewed. This change does not constrain prone, preview activities or mounted weapons.

Crouch aim correction: the crouch sample supplies pelvis/legs while the rifle clips supply the upper body. Previously the unchanged local Spine rotation inherited the unarmed pelvis lean and tipped the muzzle down. Preserve Hips * Spine orientation before replacing the pelvis, then derive the Spine rotation against the resulting pelvis. Reload samples and overlay_reload use the same receiving-pelvis correction. tests/mocap/crouch_aim.tscn compares simultaneous standing/crouched rifle directions through idle, forward, strafe, reload and reload-overlay blends. Before/after close-up frames are in changelog/unreleased/crouched-rifle-aim; build/grip-crouch-fixed.mp4 shows the corrected movement. Actual gameplay still uses its procedural grounded kneel for stationary crouch; captured crouch locomotion is currently the controller-demo path. The 28-second battle-support-grip.mp4 verifies the earlier support-grip change in the game and predates this crouch/reload correction.

Foot release investigation: separate fully weighted locked-foot motion from the existing near-floor ankle/toe metrics. The old reach fade reaches zero at the same 0.28 m animation-offset distance that releases the plant, accelerating the foot back toward the moving sample before release. Keeping the release threshold unchanged and extending the fade endpoint to 0.40 m retains partial support until the existing time-based release takes over. Six planted average speeds change from [0.0268,0.0901,0.3783,1.2406,0.4909,0.0244] to [0.0161,0.0844,0.2028,0.6703,0.2697,0.0087] m/s for forward walk/run, backward walk/run, left/right strafe. Existing ankle/toe limits are unchanged; backward-walk and left-strafe near-floor toe metrics worsen slightly (1.330 to 1.392 and 1.558 to 1.625), so this is not a universal improvement or a no-sliding claim. The stride test now separately bounds fully weighted plants. Removing the fade entirely, slowing release and holding plants longer were tested and rejected because backward toe motion worsened; the 2 m/s correction-rate experiment also regressed running ankles. All those experiments are reverted. Before/after footage is build/foot-release-comparison.mp4 (before left, after right), with ten-frame-per-second strafe samples inspected. Baseline toe clearance is within about 5 mm, so floor penetration is not the main remaining cause.

Final gentle-release terrain recording passes jump, landing, hill ascent/descent, magazine stow/replacement, ragdoll and reset. Maximum correction change is 9.37 cm (below the unchanged 12 cm guard); maximum sole penetration is about 0.0011 mm. build/controller-gentle-plants.mp4 and its contact sheet were inspected. Changelog and whitespace checks pass. Full-battle and multiplayer checks were not repeated for this one-parameter foot-contact adjustment.

Gameplay crouch integration: SoldierModel routes moving CROUCH (>0.1 m/s) through the shared native controller when available; stationary crouch keeps ground_kneel and its reload overlay. Mounted and over-wall crouch retain their dedicated poses. tests/mocap/gameplay_crouch_walk.tscn executes the actual SoldierModel.pose path through stand/walk/crouch/stop/reload/restart/stand. Baseline native=false fails the new route check. The initial integration exposed a 0.521 m hand jump because sampling actor.pose restarted transitions; extracting _retarget_source allows pure lower-body sampling without contact, recoil or mode side effects. Separately the support-hand constraint now fades with the existing posture transition, fixing the 0.460 m interrupted-stance hand jump. Final moving sequence maximum step is 0.136 m; interrupted stance test is 0.0965 m, both below the unchanged 0.15 m limit. Crouch aim, gameplay kneeling reload, terrain route, six-direction stride and ragdoll momentum checks pass. build/gameplay-crouch-fixed.mp4 and its contact sheet were inspected. This supersedes the earlier note that captured crouch movement was limited to the controller demo.

Full battle rerun: build/battle-crouch-routing.mp4 records 1683 frames (28.05 s), with the latest gameplay routing and planted-foot changes. The contact sheet shows rifle movement, infantry impact/fall, tank impacts and the burning wreck. The recording exits without script, parse or ObjectDB leak messages. It is a broad runtime/render check; the dedicated gameplay_crouch_walk fixture provides the deterministic routing evidence. Multiplayer was not rerun for this visual-path change.

Visual limitation from the latest battle contact sheet: a near-wall rifleman shows an exaggerated raised-leg pose around 4 seconds, despite the isolated crouch sequence passing. Treat this as unresolved cover/vault/posture interaction, not as proof of finished natural movement; reproduce and inspect the actual gameplay state next. The full quality goal remains open.

Raised leg near cover: isolated rendered VAULT and SLIDE poses showed that the old procedural SLIDE reproduces the kick-like screenshot (build/slide-audit.jpg); VAULT does not. The initial vault suspicion was wrong. A rendered game trace also observed a crouched SLIDE during cover movement. Headless World runs omit visual models, so empty bone traces from those runs were not evidence about rendered poses. SoldierModel's slide now uses root tilt 0.55, hip height 0.63, leading thigh 0.8 and trailing thigh/knee 1.1/-2.4, rather than the old combined root/thigh tilt that sent the foot upward. Early lower-hip variants penetrated the floor and were replaced. tests/mocap/gameplay_slide.tscn exercises standing and crouched entry/exit. SWAT final settled ankle heights are 0.105-0.123 m and maximum sampled joint step is 0.140 m, under the existing-style 0.15 m guard. build/gameplay-slide-route.mp4 and its contact sheet were inspected. Original preview rig, with its actual MCO fallback path, has acceptable settled ankle heights (0.136-0.154 m) but fails transition distance (0.351 m); that remains unresolved and is not claimed as passing. The latest full battle predates the slide change; this turn's visual evidence is the actual SoldierModel pose fixture.

Original-rig slide follow-up: diagnostic bone/time reporting placed the original 0.351 m spike at RightFoot, 4.833 s, during ordinary walking after the slide. The MCO _ground_feet solver discarded up to 0.35 m of horizontal plant correction immediately at release. A Vector2 correction now approaches the requested offset at 4 m/s, retaining the existing vertical floor constraint. Mode changes and reset_motion clear the offsets; reset also unlocks old anchors. After that fix the worst remaining jump was LeftFoot, 0.312 m at 6.017 s, when crouched walking switched to sliding without changing posture mode. Slides now use a distinct full-body pose mode, so the existing posture blend applies on entry and exit. Final original-rig route maximum is 0.0897 m; SWAT remains 0.1402 m, both under the unchanged 0.15 m limit. Original stepped-ground test: foot error 3.83 mm, grip error below 0.002 mm, switch delta 1.71 mm. Reset/momentum checks include clearing a planted foot and a nonzero contact offset. build/original-slide-blended.mp4/contact sheet inspected. These results supersede the earlier original-rig transition failure note.

Latest full battle recording build/battle-slide-polish.mp4 contains 1683 frames at 60 fps (28.05 s), with no script/parse/ObjectDB-leak messages. The contact sheet was inspected for infantry movement, impacts, ragdolls and tank wreck effects. Import, changelog and whitespace checks pass. The original-rig transition issue is now resolved by the measured fixtures; the full professional-quality goal remains open, and multiplayer/crowd performance were not revalidated in this pass.

### Class-cache audit and multiplayer death ordering

Godot had indexed full named-class backup scripts in build/ despite that folder being Git-ignored. SoldierModel resolved to build/soldier_model_before_slide.gd, and a SkinnedRagdoll backup was also present. Both backups were renamed to .gd.txt and the project reimported. The class cache now resolves both names to scripts/game/. Never leave full class_name script backups with a .gd extension anywhere under the project. Earlier post-import footage is not authoritative evidence for these classes.

Fresh corrected-cache checks pass: death_event_order (five stale alive poses after death, delayed downed/dead state, confirmed revival), ragdoll_camera (near active camera creates, distant active camera suppresses), gameplay_slide (SWAT maximum joint step 0.1402 m; original 0.0897 m), gameplay_crouch_walk (0.1355 m), gameplay_stances (0.0965 m), and ragdoll_momentum. The no-animation wall-impact check retains coherent initial anchor velocity (0.00000049 m/s), actual wall contact and 33.8 mm maximum penetration. Logs are build/verified-*.log.

The rendered network_animation fixture with headless host and rendered SWAT client passes crouch, hit reaction and persistent ragdoll checks (build/network-verified-{host,client}.log). It uses a separate active camera while moving the inactive RTS camera far away. The client screenshot build/network-animation-client.png was inspected. Run tests/mocap/network_animation.tscn in two processes with matching --port: host uses --host --players=2 --team=-1 --no-stun; client uses --join=127.0.0.1 --team=-1 --no-stun --skinned-units --swat-units. This checks visual replication with the existing protocol; it does not simulate packet loss.

Fresh gameplay recording after repairing the class cache: build/battle-verified.mp4, 1683 frames at 60 fps (28.05 s). Reviewed contact sheet build/battle-verified-review.jpg shows rifle movement and cover, infantry blast/ragdoll, tank impact and burning wreck. No script/parse errors or ObjectDB leaks appear in its log. This replaces the earlier battle footage as current-code evidence. It is still a prototype, with remaining contact sliding, interaction coverage and crowd performance work; it does not establish the requested final professional quality.

### Running forefoot support

The ankle-only plant constrained the wrong point during toe-off: even a stationary ankle allowed the toe to slide as the captured foot rotated. The shared controller now uses a support point interpolated between ankle and ToeBase with its existing walk/run speed range (1.4-3.4 m/s). It solves the ankle offset needed to hold that point, retaining the existing lift timing, release, correction smoothing and terrain solver.

Six-direction comparison uses the same weighted support point in both versions. Fully weighted support speeds (m/s) change from [0.0161,0.3861,0.2028,1.3081,0.2963,0.0777] to [0.0161,0.000115,0.2028,0.5188,0.2507,0.000747]. Near-ground toe speeds change from [0.9339,0.5457,1.3921,0.5453,1.6251,0.9290] to [0.9339,0.0916,1.3921,0.2480,1.5994,0.8156]. Order: forward walk/run, backward walk/run, left/right strafe. Running ankle speed increases because the ankle now rolls about the support point; stride_sync retains ankle guards for walking and bounds toe/support motion for running. It does not treat ankle rotation as sole sliding. Backward running still has residual support drift; this is an improvement, not perfect contact.

Rejected experiments: preserving horizontal pelvis residuals improved some directions but worsened others; restored importer unchanged. Anchoring every gait directly on the toe and using toe height alone (or minimum ankle/toe lift) for lock timing lost walking contact samples; restored original contact timing. Only speed-blended support survives. Evidence: build/pelvis-baseline.log, build/forefoot-support-baseline.log, build/forefoot-support.log, and build/forefoot-stride_sync.log. Ignored exploratory probes omit assertions and their PASS text is not validation; the permanent stride_sync test is the passing regression gate.

Rendered six-second backward-run/left-strafe comparison: build/forefoot-comparison.mp4, before left and after right. Both 5-fps contact sheets were inspected. The terrain controller passes jump/landing/reload/stow/replacement/ragdoll/reset, with 0.105 mm maximum ankle-floor penetration and 9.61 cm maximum contact correction change (unchanged 12 cm bound). Crouch-walk, interrupted stances and slides pass; slide maximum joint step is 0.1385 m. Foot-support changes require no replicated state changes.

Final checks for forefoot support: native_grip, crouch_aim and ragdoll_momentum pass. Running wall impact passes with actual contact, 37.1 mm maximum penetration, 28.5 mm first-second joint separation and negligible skin stretch (build/forefoot-running-wall.log). Import succeeds and class-cache entries still reference production SoldierModel/SkinnedRagdoll. The importer matches its pre-experiment SHA-256 exactly.

Fresh in-game recording build/battle-forefoot.mp4 contains 1683 frames at 60 fps (28.05 s); its contact sheet was inspected. It shows infantry movement and falls, tank impact and the burning wreck. This run has earlier combat deaths and different camera framing than battle-verified, so use forefoot-comparison.mp4 for controlled gait comparison rather than treating those two battles as a matched A/B. No script/parse errors or ObjectDB leaks appear in the recording log. Overall visual quality remains unfinished; backward support slip, activity integration and crowd performance are still open. Multiplayer was not repeated for this local foot-support correction.

### Scenario seed correction

The main scenario launch branch ignored --seed while AI battles and missions applied it. The branch now forwards fixed_seed before Net.start_game. tests/mocap/scenario_seed.tscn exercises the real launch path and fails on the old code (build/scenario-seed-before.log). Run headless with --fixed-fps 60 before the separator and --scenario=motion --seed=3 --no-stun --port=<unique> afterward.

Two fresh seed-3 processes at one simulation second produce identical soldier-position hash 2581693616 and RNG state 8981993674454182092. Seed 7 produces hash 2013660396 and RNG state 881945755196213292. A separate shell comparison requires equal repeated-seed output and a distinct alternate-seed output. Logs: build/scenario-seed-7992.log through -7994.log. The 28-second headless motion run fires motion_demo_reload, motion_demo_hit, motion_demo_blast and vehicle_hit_reaction once, and vehicle_destroyed once (build/seeded-motion-events.log). These observations establish the tested initialization and sequence, not bitwise renderer/physics determinism across machines.

The first actual seed-3 recording (build/battle-seed3.mp4) reproduced the intended events but exposed a close overhead fallback at three seconds, when foliage blocked one of the camera's three visibility rays. The camera now ranks the number of clear face/pelvis/feet rays, then smoke depth, rather than discarding all partially clear views. If the subject is enclosed, it starts from the normal offset instead of a 1.5 m overhead offset. Existing cover/smoke/foliage tests plus partial-foot-obstruction and fully-enclosed framing tests pass (build/seeded-camera-test.log). Matched three-second screenshots in changelog/unreleased/inspection-camera-framing were inspected: the new shot retains a readable full-body distance, though nearby foliage and other soldiers can still obscure parts of the subject.

Final seeded recording: build/battle-seed3-camera.mp4 (1683 frames, 60 fps, 28.05 s). Full contact sheet and matched three-second before/after frames inspected. The overhead jump is gone; reload, infantry impact/fall and tank destruction remain visible. No script/parse errors or ObjectDB leaks appear in the recording log. Seed and camera regression checks, changelog validation and whitespace checks pass. Multiplayer and crowd performance were not repeated for this launch/demo-camera change. The broader character-quality goal remains open.

### Contact timing follows the support point

Frame traces of backward running separated grounded toe slip from airborne support motion. The old fully weighted plant metric counted toes about 5 cm above their resting height and reported large motion during lift-off; that was not all ground sliding. At actual touchdown the toe could already be near the floor while the ankle remained above the old plant threshold. Contact position used the forefoot, but contact timing still used ankle height.

The controller now blends ankle/toe height with the same speed weight as support position, retaining the existing 0.025/0.065 m thresholds, reach fade, release distance and correction smoothing. Walking is unchanged. Removing the reach fade was tried and rejected: it barely changed near-ground running toe drift and worsened backward-walk toe drift. That experiment is fully reverted.

Near-floor toe speed (m/s), before/after: forward walk 0.9339/0.9339; forward run 0.0916/0.0366; backward walk 1.3921/1.3921; backward run 0.2480/0.1129; left strafe 1.5994/1.6040; right strafe 0.8156/0.8221. This targets running touchdown, not every gait. The stride regression tightens forward/backward running toe bounds to 0.05/0.14 m/s. Its fully weighted support metric now also requires near-floor height, using the correctly blended support rest height; it no longer labels airborne motion as ground sliding. On that same corrected metric, backward running changes from 0.00140 to 0.00465 m/s, a small worsening during fully established contact; most improvement is in touchdown, not the fully locked interval. Bound remains under 0.01 m/s. Logs: build/support-timing-baseline.log and build/support-timing-final-stride.log; diagnostics in build/backward-floor-detail.log.

Rendered comparison build/support-timing-comparison.mp4 is before left / after right. Five-fps frames inspected. The 18-second terrain recording build/controller-support-timing.mp4 exercises hill ascent/descent, jump/landing, reload stow/replacement, ragdoll and reset. It passes with maximum ankle-floor penetration about 0.0012 mm and correction change 0.1005 m, below the unchanged 0.12 m guard. Contact sheet inspected. Gameplay slide/crouch/interrupted stance, native grip and ragdoll momentum tests pass. Import is clean and class-cache entries still resolve production scripts. Full battle, multiplayer and crowd-performance checks were not repeated for this timing correction. The overall quality goal remains open.

### Crowd profiling and redundant pose work

Fresh seeded scaling baseline: 71 soldiers / 52 skinned, 38.1 FPS, median frame 23.61 ms, p95 45.36 ms, soldier view CPU 8.45 ms (build/crowd-current.log). The idle hit layer rewrote three spine bones even with a zero spring offset. It now advances the spring but returns before skeleton writes for negligible offsets. The native_recoil fixture checks unchanged idle poses across 10,000 updates and retains its four headings / 16 directional hits. That focused loop drops from 51,378 to 5,002 microseconds on this machine. A second crowd run measured 36.6 FPS and 8.62 ms soldier view time, so this alone does not establish any overall frame-rate gain. Both runs remain below the desired smooth large-battle target.

A headless pose breakdown (build/pose-profile.log) identifies crouch retargeting as avoidable work: the whole source body was retargeted before the driver discarded its upper body. _retarget_source now accepts the driver's existing upper-body mask, skipping those bones only in the crouch sampling path; full original-rig retargeting remains unchanged. lower_retarget.tscn compares all retained local transforms over 12 crouch phases, proving equivalent lower-body results and untouched upper-body poses. Isolated total pose/capture time changes from about 305 to 226 microseconds for stationary crouch and 408 to 346 microseconds for moving crouch (build/pose-profile-lower.log); these are local script timings, not a whole-game FPS claim.

Gameplay crouch/reload/restart, crouched aiming, interrupted stances, six-direction stride and original-rig stance contacts pass. Original contact errors: foot 3.83 mm, grip 0.074 mm, stance switch 1.71 mm. The crowd screenshot build/crowd-current.png was inspected to verify the populated RTS setup; it is a workload view, not close-up animation-quality evidence.

Final populated run with selective retargeting measures 39.0 FPS, median 22.86 ms, p95 43.33 ms and soldier-view CPU 8.13 ms (build/crowd-lower-retarget.log). This modest single-run difference does not establish a stable 60-FPS crowd; broader optimization remains necessary. The rendered 10-second gameplay crouch/stop/reload/restart/stand route passes, with maximum joint step 0.1355 m. build/crouch-selective-retarget.mp4 and its contact sheet were inspected. Import, changelog and whitespace checks pass. No script/parse errors or ObjectDB leaks appear in that render log. Multiplayer was not repeated for the pose-work optimization.

### Native locomotion blends

The shared controller now evaluates mixed clips in an AnimationTree and reads the resulting skeleton once. Single active clips retain direct sampling. The graph resource is shared but playback parameters belong to each soldier; blend_independence.tscn checks separate timing, weights, local poses and return to idle. Stride coverage now includes intermediate forward/backward speeds. Grip, recoil, crouched aiming, lower-body retarget equivalence, gameplay crouch and interrupted stance fixtures pass (build/hybrid-*.log).

The isolated moving-pose profile measures about 203 microseconds standing and 283 crouching versus 247 and 346 previously. A populated run measured 37.5 FPS and 8.30 ms soldier-view CPU, but an editor import overlapped that run; it is not a controlled performance comparison. No overall FPS improvement is established.

build/controller-native-blends.mp4 records 18 seconds of terrain movement, jump, reload, ragdoll and reset. The rendered contact sheet was inspected; the unchanged controller guards pass, including contact correction below 0.12 m. Import, changelog and whitespace checks pass. Multiplayer was not repeated.

Diagonal movement remains visibly unproven and numerically poor: the near-floor toe probe measures roughly 2.4 m/s sliding for two diagonal directions. An isolated vector-stride timing experiment worsened this to 2.6–2.7 m/s and was not applied. The next investigation must examine blended foot trajectories and contact phases rather than assume cadence alone fixes diagonal motion. These results do not establish professional animation quality.

### Diagonal trajectory investigation

The raw blended left ankle reaches y=0.061 m in forward-left movement, below its roughly 0.117 m standing sole height (build/diagonal-probe.log). It plants around phase 0.13, stretches out and releases by phase 0.30. Source clips individually retain higher stance trajectories (build/trajectory-probe.log). Rotation blending therefore distorts end-effector motion; cadence alone does not explain this defect.

An isolated prototype samples 64 local foot positions per clip, blends them at matching phases and restores those endpoints with leg IK before ground contacts. Combined with vector stride timing, the diagonal near-floor ankle metric becomes 0.56 m/s forward-left and 0.33 backward-right. A support-velocity condition changes these only slightly to 0.57 and 0.33; it does not resolve the remaining issue. Toe drift remains about 2.18 and 2.09 m/s (build/foot-direction-contacts.log). Blending toe directions too reduces those to 2.13 and 1.98, still insufficient.

build/diagonal-comparison.mp4 is an eight-second, two-character comparison: current controller left, foot-target/vector-stride/support-velocity experiment right. Its 2-FPS contact sheet was inspected for clearance and leg shape. The render finished without reported script errors or object leaks. These ignored build prototypes are diagnostic only; no experiment was promoted into gameplay. Contact timing and toe rotation still need investigation, followed by transition, terrain, grip and crowd-cost validation before adoption.

### Shared diagonal trajectory correction

Subsequent ground-contact measurements distinguish actual contact (within 5 mm of the toe's rest sole height) from low airborne swing (the earlier 35 mm band). The original diagonal toe speeds in this tighter band are 2.31 m/s forward-left and 2.15 backward-right. Preserving blended ankle and toe trajectories plus vector stride timing reduces these to 0.708 and 0.283 m/s. Forward-right measures 0.259 and backward-left 0.155. The wider near-floor measurement remains useful for identifying low, fast swings; it is not interchangeable with grounded sliding.

That trajectory correction is now in the shared controller. Samples are cached per model, and correction fades in over the first 15% of minor-axis movement instead of switching at a fixed velocity. Toe-only contacts and the experimental support-velocity condition were rejected. Contact locking otherwise remains unchanged.

stride_sync retains its previous eight cases and adds all four diagonal ground-contact bounds with minimum sample coverage. native_grip now covers ten cases including diagonals, all below its existing 7 mm limit. Blend independence, terrain jump/reload/ragdoll/reset, gameplay crouch/stop/reload/restart, and native recoil/directional hits pass. Maximum terrain contact-correction change is 0.0684 m against the unchanged 0.12 m bound. Import and changelog/whitespace checks pass. The rendered build/diagonal-foot-paths.mp4 compares old left/new right; its contact sheet was inspected. This improves the shared gameplay path but does not eliminate sliding or prove the final quality target. Crowd cost and multiplayer still require rechecking.

The updated seeded battle is recorded in build/battle-foot-paths.mp4 (28.05 seconds, 1683 frames). Its contact sheet was inspected across rifle fire, impacts, the wall-side ragdoll, tank fire and the burning wreck. Runtime counters confirm one demonstration reload/hit/blast each, two skinned ragdolls, a vehicle hit reaction and a destroyed vehicle. No script errors or object leaks are reported. The existing play_skinned.ps1 -Swat launcher runs this scenario; -Controller opens the interactive terrain route. This recording is presentation evidence, not a real-time FPS benchmark.

A subsequent unrecorded crowd run, with no concurrent import or test process, measures 39.3 FPS with 71 soldiers / 52 skinned, median frame 22.22 ms, p95 43.90 ms, soldier-view CPU 8.08 ms (build/crowd-foot-paths.log). This does not establish a performance gain over earlier noisy runs, and remains below 60 FPS. Multiplayer was not repeated for this animation-only correction.

### Multiplayer validation after trajectory correction

network_animation.tscn now requests a crouch-to-standing transition and diagonal movement on the host before the existing hit/death sequence. The rendered client must observe both velocity components, a fully standing pose, support-hand error below 7 mm, a hit reaction and a persistent ragdoll. Two localhost host/client runs pass (build/network-foot-client.log and build/network-foot-clear-client.log); the second reports maximum support-hand error 0.00000485 m. This validates the shared updated controller through real snapshots, without changing the production protocol.

The first screenshots were obscured by foliage and depth of field. The fixture camera now uses a closer elevated angle. Rerun the client with --preset=high --set=dof:false,grass:0 for inspection; those settings are for visibility, not performance evidence. The new build/network-animation-diagonal.png and build/network-animation-client.png were inspected: the standing rifle grip and settled skeletal body are visible. Host/client logs contain no script errors or leak warnings. This supersedes the previous multiplayer-not-repeated note for the trajectory change. Packet loss, remote WAN latency and cross-version compatibility were not tested.

### Diagonal toe anchors

After trajectory preservation, the remaining forward-left contact drift came partly from anchoring an ankle/toe mixture and fading that anchor toward the moving pose. Diagonal movement now anchors the toe and retains full horizontal weight until the existing 0.28 m stretch-release condition. Lift-based contact timing is unchanged. Both changes use the same smooth directional weight as trajectory correction, leaving cardinal movement unchanged.

Grounded diagonal toe speeds change from [0.708, 0.259, 0.155, 0.283] to [0.153, 0.034, 0.077, 0.019] m/s for forward-left, forward-right, backward-left and backward-right respectively. stride_sync tightens its four limits and adds a full continuous turn: maximum correction change 0.0672 m, below the existing 0.12 m guard. The eight cardinal/intermediate-speed cases retain their previous limits. Grip across ten movement cases, gameplay crouch/reload/restart and directional recoil/hits pass.

build/diagonal-anchors.mp4 compares the prior trajectory-only controller on the left with toe anchoring on the right. build/controller-diagonal-anchors.mp4 records the 18-second terrain/jump/reload/impact/reset route and passes all existing route guards (contact change 0.0684 m). Both contact sheets were inspected. Import and error/leak scans are clean; changelog and whitespace checks pass. Full battle, multiplayer and crowd performance were not repeated for this contact-only adjustment. Residual forward-left sliding remains; the overall quality objective is still open.

### Avoid discarded standing-foot work in crouch

The standing diagonal-foot trajectory solve was still running at full crouch weight, immediately before crouch retargeting replaced all affected leg poses. The controller now skips that solve only when crouch_weight is exactly 1.0; transition frames retain it. crouch_foot_paths.tscn compares every local bone transform against a reference that always runs the solve, over 360 rotating movement samples with crouch entry and exit. Maximum position and basis-vector differences are both zero. Direct basis comparison avoids quaternion angle-to noise around identical rotations.

Isolated forward-left crouch pose/capture time changes from 352 to 308 microseconds; backward-right changes from 355 to 315 (build/crouch-path-before.log and build/crouch-path-after-isolated.log). Standing results remain in the prior range. This is an 11–12% reduction in these crouched pose updates, not a whole-game FPS claim.

build/crouch-foot-skip.mp4 records the unchanged ten-second gameplay crouch/stop/reload/restart/stand sequence. Its guards pass with maximum joint step 0.13477 m, and its contact sheet was inspected. Import, changelog and whitespace checks pass. This optimization does not address the remaining visual-quality gaps.

The separate unrecorded crowd run reports 38.2 FPS, median frame 24.07 ms, p95 41.67 ms and soldier-view CPU 8.20 ms with 52 skinned soldiers (build/crowd-crouch-foot-skip.log). This remains within the prior run-to-run range and establishes no whole-game FPS improvement. The optimization is retained for its measured isolated savings with identical poses; the principal crowd bottleneck remains unresolved. Multiplayer was not repeated for this equivalence-checked optimization.

### Crowd cadence investigation (rejected scheduling change)

The scaling fixture now reports native standing/crouching controller updates per frame and average live pose-mode counts. These counters distinguish native locomotion from captured prone and procedural fallback; they do not measure each mode's CPU time.

A focused twelve-rifleman experiment reproduced synchronized distant posing: zero updates on one frame, twelve on the next. Scheduling by process frame plus entity ID yielded six updates each frame, while all twelve still updated every frame at close range. However, the actual populated benchmark did not improve: baseline 38.9 FPS / p95 42.42 ms; staggered runs 36.8 / 50.0 and 37.2 / 43.33. The scheduling change was reverted, along with its proposed changelog and permanent fixture. Diagnostic fixture copies remain under build/pose_cadence_probe.*. The shared game retains its previous distance/frustum scheduling.

The native standing/crouch update counter's median was only two per frame in this workload. Earlier native-controller micro-optimizations therefore cannot by themselves explain or solve the overall crowd cost. The next profiling target is the complete SoldierModel path, including procedural fallback and work performed before the native branch.

With original scheduling restored, build/crowd-pose-modes.log reports mean live mode counts of 4.54 native locomotion, zero captured prone and 47.46 procedural fallback among 52 skinned soldiers. That run measures 37.6 FPS and 8.24 ms soldier-view CPU. The dominant population is therefore the fallback path, although per-mode timing is still required before assigning CPU cost to it. Whitespace and changelog checks pass; no successful runtime optimization is claimed from this scheduling experiment.

### Stationary fallback profiling and weapon-fit convergence

The expanded scaling counter identifies about 40.9 stationary crouched soldiers, 3.6 crouch/run and 2.7 leaning/idle in the fallback population (build/crowd-fallback-states.log). An isolated complete SoldierModel.pose profile measures stationary crouch at 184 microseconds: procedural transfer including weapon seating 85, seating itself 43, knee correction 29 and motion capture 34. These nested timings must not be added together as independent costs. Native crouch walking measures 287 microseconds, so fallback is not inherently the slower path; its population makes it important here.

The fallback weapon-fit loop previously repeated all three projection passes even when no target moved. It now stops after a pass with no shift; constrained poses retain up to three passes, and the two final arm solves are unchanged. Local seating measurements fall from about 43 to 35 microseconds for crouch idle, 43 to 28 for crouch shooting and 40 to 30 for leaning shooting (build/fallback-profile-converged.log). The populated result remains 38.8 FPS / 8.03 ms soldier-view CPU, versus 39.1 / 8.10 immediately before: no overall frame-rate improvement is established.

Both original and SWAT stance/contact fixtures pass, including their step, grip and posture-switch bounds. The rendered build/seat-converged-stances.mp4 passes standing/kneeling/prone and interrupted transitions with maximum joint step 0.0965 m. Its contact sheet was inspected. This is redundant-work removal, not a new animation-quality claim; multiplayer was not repeated for the convergence early exit.

An isolated build/hidden_mesh_probe.tscn experiment removes only leaf MeshInstance3D nodes beneath the already-hidden procedural root of successfully skinned soldiers, preserving all transform joints. It removes 845 nodes in this crowd and reports 41.2 FPS, median 22.10 ms and p95 41.67 ms (build/crowd-hidden-mesh-probe.log), compared with 38.8 FPS before. This is one exploratory result, not a demonstrated stable gain. Mesh removal has not been applied to production: visual, attachment, lifecycle and fallback behavior need verification first. The weapon-convergence change's import, changelog and whitespace checks pass.

### Hidden mesh cleanup in unit construction

Successful skinned unit construction now queues the replaced procedural mesh leaves for deletion, after binding the procedural pose rig and loading the skin. Transform nodes and any mesh nodes with children are retained. Cleanup remains inside the successful-load branch; unskinned units keep their procedural geometry.

skinned_geometry.tscn exercises the real World/Soldier construction path and waits for deferred deletion. Procedural-only reports zero skins / eleven procedural units; original and SWAT variants each report four skins / seven procedural units. All check retained skin meshes, rifle and magazine nodes, retarget-map joints, gun/pistol/grenade/stretcher pivots, and ordinary procedural geometry. Logs: build/skinned-geometry-{procedural,original,swat}.log.

The populated production-path run reports 40.0 FPS and 7.99 ms soldier-view CPU (build/crowd-hidden-mesh-cleanup.log), versus 38.8 / 8.03 in the preceding baseline. The exploratory run reported 41.2 FPS. This removes confirmed unused geometry, but the modest timing difference does not establish the desired 60-FPS crowd performance.

The production-path recording build/battle-hidden-mesh-cleanup.mp4 completes 1,683 frames (28.05 seconds). Its contact sheet was inspected: skinned soldiers, settled ragdolls and the tank wreck remain visible after cleanup. Runtime counters confirm one scheduled reload, hit and blast, two skinned ragdolls, one vehicle hit reaction and one vehicle destruction. Import and recording logs contain no script/parse errors or leak reports. This sampled visual check does not establish continuous motion quality; multiplayer was not repeated for mesh cleanup.

### Diagonal landing diagnosis

The 720-frame forward-left probe (build/diagonal-landing-probe.log) isolates the remaining contact slip to eight right-foot landing samples: plant_ready is true, anchor weight is zero, and toe clearance is 0.9–4.6 mm. Their mean horizontal speed is 5.55 m/s. Fully anchored left-foot samples average 0.000021 m/s; right-foot samples average 0.0206 m/s. Increasing diagonal stretch release from 0.28 to 0.40 m, delaying release until toe lift exceeds 20 mm, and combining both did not improve the landing samples. All experiments were reverted. The next correction should address landing detection and weight acquisition, not stretch-release timing. These ignored probes are diagnostics, not regression coverage or proof of improved animation.

### Toe-first diagonal landing correction

The retained correction detects diagonal toe contact below 5 mm, acquires the zero-error anchor immediately, permits 0.40 m of diagonal travel before stretch release, and raises diagonal horizontal correction speed from 4 to 6 m/s. These changes work together: earlier landing alone exhausts the old anchor travel early and worsens sliding. Straight movement retains its existing values.

SWAT stride_sync now requires every diagonal ground-contact mean below 0.002 m/s. Results are 0.000539/0.000134/0.000038/0.000021 m/s versus 0.1534/0.0341/0.0765/0.0193 before. Turning maximum correction change is 0.10081 m, within the existing 0.12 m bound but higher than the former 0.06717 m. Native grip passes all ten cases and reload release. The original rig passes stance_contacts; stride_sync's SWAT stride calibration assertion rejects that rig before motion testing, so it provides no original-rig stride evidence.

Rendered build/diagonal-landing-comparison.mp4 shows before on the left and after on the right. The 18-second build/controller-landing.mp4 passes terrain, jump, crouch, reload/stow/replacement, impact, ragdoll and reset; maximum foot penetration is 0.000001 m and contact correction change 0.10051 m. Both contact sheets were inspected. This improves the measured landing defect but does not establish final motion polish or multiplayer validation of this change.

### Landing correction in multiplayer and at lower pose rates

A fresh localhost host/rendered-client run on port 8021 passes crouch, diagonal movement, support grip (0.000005 m maximum), hit reaction and skeletal death. The current client diagonal and ragdoll screenshots were inspected. Logs: build/network-landing-client.log and build/network-landing-host{,-errors}.log. This verifies the existing local replication path, not WAN latency or packet loss.

An isolated 30 Hz pose-step probe preserves the eight cardinal stride bounds and measures diagonal ground-contact means 0.000107/0.000012/0.000017/0.000018 m/s. Its turn correction reaches 0.20024 m per sample; the pre-landing controller reaches 0.13351 m. Both fail the unchanged 0.12 m per-frame bound written for 60 Hz. The larger changes are consistent with the 6 versus 4 m/s horizontal correction limits over twice the timestep, but this does not prove perceptual smoothness at 30 Hz. Do not present the lower-rate probe as a passing full fixture; a rendered low-rate turn review remains outstanding. Logs: build/stride-30.log and build/stride-30-before.log.

The updated in-game recording build/battle-landing.mp4 completes 1,683 frames / 28.05 seconds. The contact sheet was inspected, and battle counters confirm the scheduled reload, hit and blast, two skinned ragdolls, a tank hit reaction and vehicle destruction. The recording log has no script/parse errors or leak reports. This is the current full battle video for the toe-first landing controller.

### Released-foot return at 30 Hz

The rendered build/turn-cadence.mp4 compares current 60 Hz and 30 Hz pose updates over the same eight-second turn. The largest root-relative knee/ankle displacement is 0.1678 / 0.2953 m per pose sample. A dense frame sheet around 4.4 seconds isolates the larger right-foot movement during backward-diagonal swing.

The retained change applies the 6 m/s diagonal correction cap only while locked; released feet return at the existing 4 m/s rate. The matched 30 Hz before/after render build/turn-release-comparison.mp4 records maximum joint steps 0.29526 / 0.26865 m. Its dense frame sheet was inspected. This is a modest reduction, not proof of final perceptual smoothness. The extended stride_sync test now covers an eight-second 30 Hz turn with a 0.28 m joint-step bound; the previous controller exceeds it. Cardinal bounds and all four diagonal contact means below 0.002 m/s continue to pass. Logs: build/release-follow-regression.log and build/turn-release-comparison.log. Multiplayer and the full battle were not repeated for this release-speed-only change.

### First-second ragdoll wall-impact audit

The existing fixture measured early anchor separation but only asserted settled separation; self-overlap was checked at creation and after one second. It now records first-second nonadjacent capsule overlap and enforces 0.06 m transient overlap/anchor-gap bounds, retaining the tighter settled limits. These are regression ceilings, not a claim of anatomically perfect contact.

At 60 Hz, SWAT wall-impact runs from idle/crouch/prone/rifle_run show maximum early overlap 0.01287/0.01938/0.01273/0.05088 m and early anchor gaps 0.03671/0.03749/0.05734/0.04419 m. Maximum wall penetration is 0.03382/0.00882/0.02554/0.03866 m. All fall within the new transient bounds and existing settled/wall limits. The running case remains the largest early self-overlap (Spine2/RightForeArm at 0.167 seconds after impact).

The running impact was rendered as build/ragdoll-wall-audit.mp4, and a dense contact sheet around the wall collision was inspected. An isolated increase from 10 to 16 position-solver iterations raised wall penetration to 0.04635 m and failed the existing wall bound; project.godot was restored to 10. No physics-quality improvement is claimed from this audit. Logs: build/ragdoll-wall-{idle,crouch,prone}-audit.log, build/ragdoll-wall-running-audit.log, build/ragdoll-wall-16.log and build/ragdoll-impact-bounds.log.

### Earlier speculative impact contacts

The retained setting is physics/jolt_physics_3d/simulation/speculative_contact_distance=0.04, up from the engine default 0.02. It reduces the running wall case's early self-overlap from 0.05088 to 0.03281 m, wall penetration from 0.03866 to 0.02615 m and early joint gap from 0.04419 to 0.03226 m. The first-second overlap assertion is tightened to 0.04 m. SWAT idle/crouch/prone cases and the original rig's idle wall case pass; dropped-rifle overlap protection and owner collision also pass. A separate velocity-iterations=20 experiment failed the wall penetration bound and was reverted.

The running case was rendered in build/ragdoll-contact04.mp4 and its dense impact contact sheet inspected. Logs: build/contact04-{idle,crouch,prone,original,props,regression}.log and build/ragdoll-wall-contact04.log. The setting is global, so effects outside these cases still need broader coverage; speculative contacts can respond before actual surface contact. Reference: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-jolt-physics-3d-simulation-speculative-contact-distance

The retained contact setting also completes the 28.05-second in-game recording build/battle-contact.mp4 with no script/parse errors or leak reports. The contact sheet was inspected for soldier impacts, settled ragdolls and the tank wreck. This is current full-battle footage; it does not replace a dense-crowd performance benchmark or multiplayer revalidation of the global contact setting.

### Contact setting cost under load

Serialized rendered crowd runs with identical seed/settings report 40.1 FPS at contact distance 0.02 and 39.6 FPS at 0.04; median frame time is 22.22 ms in both and p95 41.67/42.42 ms. Each contains 71 soldiers and 52 skins. This pair does not establish a material frame-rate difference or meet the desired 60 FPS. Logs: build/contact-crowd-{before,after}.log.

The 16-active-ragdoll budget test passes eviction, duplicate-death protection and cleanup at both distances. Real-time rendered runs (no MovieMaker or fixed-fps acceleration) report physics median 2.220/2.658 ms and p95 27.393/26.669 ms. These are engine-monitor samples, not per-body solver profiling; the single pair is indicative rather than a statistical performance claim. Logs: build/contact-budget-realtime-{before,after}.log. Earlier accelerated headless timings were stale and must not be used for comparison (build/contact-budget-{before,after}.log).

The current contact setting and released-foot correction pass a fresh localhost host/rendered-client run on port 8026: crouch, diagonal movement, support grip (0.0000045 m), hit and skeletal death all pass. The settled client ragdoll screenshot was inspected. Logs: build/network-contact-client.log and build/network-contact-host{,-errors}.log. WAN latency/loss remains untested.

### Motion-sampling orientation reuse

_sample_motion now stores each orientation normalized once and uses its transpose as the previous orientation's inverse. Previously it renormalized the previous basis on every sample. The momentum fixture compares 120 rotating/scaled prop samples with the previous calculation (spin error below 0.001 rad/s) and checks translation, root motion, angular COM transfer and reset behavior.

The isolated fallback profile reports sampling around 30.6–33.0 microseconds after versus 31.3–33.6 before; differences are small and whole-pose timings vary. No overall frame-rate gain is established. Logs: build/motion-normalization-{before,after,regression,wall,import}.log. This is redundant-work removal with equivalent momentum checks, not an animation-quality claim.

### Directional-hit stance preview

Existing native_recoil.gd already checks four world hit directions at four headings while standing; it is not limited to event delivery. The additional build/directional_hits.gd preview renders four hits each while standing, crouched and prone. Each six-second stance segment allows 2.2 seconds to settle before the hits, avoiding confusion with the kneel-to-prone transition. Current footage: build/directional-hits-settled.mp4 (18 seconds, 1,080 frames); its prone impact contact sheet was inspected. The earlier 12-second build/directional-hits.mp4 included hits during the prone transition and should not be used as settled-stance evidence.

The preview records 12 fired reactions and a 0.000155 m maximum standing/procedural grip error. That metric does not independently measure the captured prone support grip, so it must not be presented as a three-stance grip proof. This pass adds review footage, not a changed hit model or final-quality certification.

### Captured prone grip under directional hits

The native_grip fixture now settles the prone clip at four headings and applies four world hit directions plus recoil at each heading. It checks both palm positions in rifle space throughout 120 recovery frames per hit and bounds drift below 1 mm, alongside hit recovery. Existing locomotion and reload-release checks remain in the same fixture. Log: build/prone-grip-regression.log.

A separate alignment probe finds the prone left palm 28.7 mm from the standing grip in rifle space. The rendered build/prone-grip-closeup.png was inspected: the hand remains below the fore-end in a different captured hold. No runtime socket correction was made solely to force equality with standing. This verifies stability of the captured hold; it does not certify finger-by-finger contact with the weapon mesh.

### Fore-end mesh versus stable palm calibration

The close-up grip stability conclusion does not prove the fingers surround the fore-end. A direct receiver-mesh probe in rifle space finds the fore-end at x +/-0.03067 m, y 0.07110–0.13244 m for z 0.23–0.32 m. In the captured prone pose, left finger base joints are around y -0.006 to 0.0 m and tips around y 0.045–0.074 m. Thus most fingers sit below the actual handguard, with only their tips reaching its underside. The source finger joints are posed; this is a mismatch between the captured hold and this rifle's mesh placement, not missing finger tracks. Log: build/prone-foreend-probe.log; close-up: build/prone-grip-closeup.png.

The next grip correction should target the real fore-end while preserving the trigger-hand anchor and authored releases during reloads. The existing tests intentionally only establish stability; they cannot certify mesh contact. No runtime change was made in this diagnostic pass.

## Rifle contact and crouch refinements

The M4 support grip is calibrated against its imported handguard geometry. Native locomotion offsets the captured wrist by (0, 0.04, -0.03) metres in rifle space; prone adds 0.065 metres vertically after the descent. The native grip regression checks absolute fore-end contact as well as movement drift, hit recovery, and reload release.

Stationary crouch uses the same captured rifle controller as crouch movement. Its contact solver fades out swing height and flattens the soles at rest; gameplay_reload checks both feet stay within 2 cm of the flat test floor during reload.

Run tests/mocap/crouch_slope.tscn with --swat-units to verify stationary crouch sole alignment on four slopes at four headings.

Stationary crouch adds a 0.12 m pelvis drop, faded with crouch weight and speed, before contact IK. The gameplay stance regression bounds the settled hip height; ragdoll_limits supports --ragdoll-pose=gameplay_crouch to exercise death from this pose.

Ragdoll ankles allow ±0.6 radians of flexion, while retaining ±0.25 radians on the other axes. The crouched bullet-impact regression exposed an early ankle-anchor gap with the former shared torso limits; keep the existing overlap, separation, and skin-stretch gates when changing these limits.

The crouch drop follows requested planar velocity rather than the blended velocity, whose zero crossing during reversals is not a stop. Its rate is limited to 0.4 m/s. tests/mocap/crouch_transitions.tscn checks starts, stops, and reversals at 60 Hz and with --physics-hz=30.

Crouch contact anchors retain full horizontal correction until release. Released crouched feet limit correction recovery to 1.2 m/s; standing and running retain their existing limits. The crouch transition regression bounds planted-foot sliding to 2 mm/s and checks leg movement at both supported test rates.

Directional crouch remains a coverage limitation: the supplied MCO sample contains only MOB1_CrouchWalk_F_IPC. A trial combining its crouched pelvis with the standing directional foot-path cache increased planted sliding to 0.035 m/s even with smoothed direction weights (baseline below 0.0001 m/s), so it was reverted. Matching authored crouch side/back clips, or a separately validated directional retargeting solution, are still needed for final-quality coverage.

The network_animation fixture now pauses the replicated unit in crouched idle before standing diagonal movement, then sends a hit and lethal event. It requires the client to reach the settled crouch pose and retain the rifle support grip as well as observing the hit and ragdoll. This remains a localhost test, not latency/loss coverage.


Current review recording: build/battle-contact-final.mp4 (28.05 seconds), including the standing anchor and cover-grip changes. Frame review reveals that a wall obscures much of the rifleman around the early reload; camera clearance still needs work before this is a finished showcase. The localhost network test includes stationary crouch and passed with a 0.00000482 m maximum support-grip error. The recording contains the scheduled reload/hit/blast, two skinned ragdolls, vehicle hit reaction and tank destruction; these results do not establish final art quality or latency/loss behavior.

Cover fallback poses reuse the native aiming socket and support-hand orientation, captured during Mixamo installation. The legacy socket remains for actors without native clips. tests/mocap/cover_grip.tscn checks both lean directions at four headings, including lateral hits/recoil and socket reinitialization, against the M4 trigger-knuckle and support-palm targets.

The fallback socket translation uses the receiving rig's actual trigger-knuckle offset. This matters for Soldier.glb: procedural poses restore its own bone lengths, which differ from the imported native clip. The captured socket rotation is shared, but its translation must not assume the source hand proportions.

Standing contacts also retain their anchors until release. In stride_sync, backward-walk planted support drift decreased from 0.151 to 0.0063 m/s and left-strafe drift from 0.159 to about 0.016 m/s. Released standing correction now recovers at 3 m/s; the existing 30 Hz turn bound passes at 0.277 m per maximum sampled joint step. The backward near-floor toe ceiling is 1.5 m/s instead of 1.45 because it includes free toe roll, while actual planted-support limits were tightened to 0.01 m/s backward and 0.02 m/s leftward. These are regression measures, not a claim that all foot motion is final quality.

Camera clearance also compares solid-cover visibility when combined foliage/cover scores tie. The focused regression places a wall across rays already obscured by a bush: it fails with the prior selection rule and passes with the solid-cover tie-break. This does not model occlusion by other soldiers.

The 28.05-second build/battle-solid-clearance.mp4 validates the new camera rule in the live scenario with no reported runtime errors and all scheduled events. Its frame sheet still shows the early wall obstruction, so the tie-break fixes a reproduced edge case but does not resolve the observed showcase defect. Continue investigating the actual obstructed frame; do not treat this recording as final camera validation.

The exact obstructed battle pose at 4.5 seconds exposed a separate camera defect: all three centerline rays cleared the wall edge while the wall hid the shoulders. The camera now checks a 0.7 m-wide body envelope at each sampled height. camera_clearance reproduces the measured wall/eye/pelvis positions, proves all former center rays are clear, and requires the selected new view to clear the wider envelope.

Latest reviewed recording: build/battle-body-clearance.mp4 (28.05 seconds). The same 4.5-second frame now shows the rifleman's body beside the wall instead of behind it; before/after captures are in changelog/unreleased/motion-camera-clearance/body-width-{before,after}.png. The full frame sheet also retains visible infantry, blast ragdoll and tank destruction. Import, camera regression, changelog and whitespace checks pass. The fixed envelope does not guarantee clearance for every extended prone limb or nearby soldier; this is not a final-quality sign-off.

Fallback rifle poses cache the native aiming finger rotations during clip installation and restore them before posture blending. Slung weapons and mounted crews are excluded. The cover_grip regression corrupts the preceding finger pose and verifies recovery in both lean directions at four headings on both rigs. Rendered SWAT reload-to-cover captures show the formerly open support fingers closing around the handguard. This fixes stale action state; it does not establish finger-by-finger mesh contact for the original character or mounted weapons.

Cover poses now restore the captured local shoulder/arm/forearm/hand rotations after transferring the procedural torso, before hit and transition blending. The previous tucked cover pose produced 0.103 m forearm/chest collider overlap and a 0.095 m first-second joint gap. The same SWAT bullet-death fixture now reports 0.0056 m initial overlap and 0.033 m peak early joint gap without relaxing bounds. The fixture adds gameplay_lean and gameplay_peek poses. build/lean-impact-comparison.mp4 shows before left/after right. Initial foot-collider floor overlap remains about 0.109 m in this fallback pose and needs separate correction; this improvement does not resolve that defect.

Stationary lean feet use ground_cover after procedural pose blending and before motion capture. Each ankle is solved against local terrain height and normal, with a speed-dependent contact weight. cover_contacts checks both rigs, two lean sides, four headings, flat ground/slopes, and movement release. The SWAT cover bullet-death floor overlap decreases from 0.109 to 0.0169 m; the remaining capsule allowance is bounded below 0.02 m for cover deaths. Early joint gap is 0.0387 m, settled gap 0.0183 m, and the existing overlap/stretch bounds pass. build/cover-ground-comparison.mp4 compares the grounded cover pose and fall, before left/after right. The full battle recording predates these contact changes.

Close-up impact replay: run tests/mocap/directional_hits.tscn with --swat-units. It sends four scripted horizontal hits through the gameplay rifle pose, then transfers to a blast ragdoll and requires physical wall contact. build/directional-hits.mp4 is the 12-second recording. The independent native_recoil regression passes 16 direction/heading cases, muzzle rise, grip retention, foot stability and recovery; native_grip passes movement, prone directional hits and reload release. This replay demonstrates the existing spring response, not authored location-specific injury animations.

Captured frontal flinch: the installed basic_shooter hit_reaction clip is 0.4333 seconds. Its spine/neck/head rotations are applied relative to its first frame, at 35% strength with a short fade, scaled by squared frontal incidence. A direction-agnostic trial failed the rear-hit direction regression and was replaced by this frontal gate. native_recoil checks the five tracks, gate and 16 direction/heading responses. Native grip/prone tests pass; build/authored-hit-comparison.mp4 shows the spring-only baseline left and captured frontal addition right. The in-game battle recording predates this addition; side/rear and location-specific authored reactions remain incomplete.

The captured flinch now finishes its current short cycle under repeated hits. Incoming hits always kick the directional spring, but cannot rewind or erase an active captured reaction. native_recoil covers frontal/side/rear interruptions, recovery, retrigger and reset. The burst fixture at build/hit_burst.tscn records three frontal hits 80 ms apart and a frontal/side pair. This does not add authored side/rear injury clips.

Reviewed burst comparison: build/hit-burst-comparison.mp4. Import, directional/recoil regression, changelog and whitespace checks pass. The wider battle and multiplayer recordings have not yet been refreshed for the captured flinch changes.


Native original-rig correction: the old Mixamo loader copied meter/Y-up local tracks directly into the centimeter/Z-up Vanguard skeleton, collapsing its limbs. mixamo_clips._retarget now converts rest-space rotations, retains receiving limb translations, and transforms hip displacement/root travel to receiving units. native_retarget samples 85 poses per rig and asserts non-hip translations retain authored lengths; both rendered checks pass. native_grip and native_recoil pass both original and SWAT, including reload release and directional/prone impacts. Fresh images: build/native-retarget-original.png and build/native-retarget-swat.png. This supersedes earlier assumptions that the native original-rig path was verified. Overall professional-quality presentation, all activity interactions and a refreshed in-game movie remain unproven.


Broader retarget audit: SWAT gameplay_reload with --crouch-reload and gameplay_stances pass, but stride_sync now fails the first forward-walk near-floor ankle limit: 0.55869 m/s vs 0.4 maximum (fully planted support 0.015998 m/s remains below 0.02). Source and SWAT rest orientations differ about 0.019 rad at thigh/shin despite matching foot global rest; finger difference reaches 0.481 rad. Full-weight plant acquisition trial reduced the ankle metric to 0.48035 but still failed; increasing landing threshold to 0.04 made it 0.62284 with planted drift 0.04129. Both trials were reverted. Do not weaken the regression or treat the retarget fix as locomotion-complete. build/battle-retarget.mp4 is the latest 28-second live battle replay, with the retarget change and original contact logic; the reviewed contact sheet shows infantry, impacts, ragdolls and tank destruction. Walking contact timing remains unresolved.


Walking contact correction: per-frame trace found the right foot dipping below the landing height while still traveling over 4 m/s, acquiring an anchor then exceeding the separation limit before its real landing. The shared controller now considers raw support world speed for ankle landing and adds up to 4.5 cm swing clearance until motion slows. Diagonal toe contact retains its independent rule. SWAT stride_sync passes unchanged bounds: forward near-floor ankle 0.20209 m/s, fully planted support 0.003876 m/s; four diagonal toe metrics below 0.000158 m/s, turn contact change 0.100001 m, 30 Hz maximum joint step 0.279738 m (close to existing 0.28 bound). Native grip and crouched gameplay reload pass. build/walk-contact-comparison.mp4 is before left / after right, five seconds; inspected its 10 fps landing sequence. The live battle movie predates this contact correction. Overall quality remains incomplete.

Cross-rig check: original character forward walk passes (near-floor ankle 0.09004 m/s), but forward run fails: no fully planted support samples and toe drift 0.63360 m/s against 0.05. This is not resolved by the SWAT contact fix. Original run contact/reach requires further investigation. SWAT gameplay stance transitions, import, changelog and whitespace checks pass.


Cross-rig running correction: the original rest pelvis is 1.061308 m high versus the Mixamo source 0.9536 m. Scaling pelvis displacement and root-travel distance by the height ratio restores its missing run plants. Native stride expectations now explicitly cover both authored character sizes; contact/sliding/turn limits are unchanged. New anchors acquire full weight immediately (their current positional error is zero). Released horizontal corrections retain the 3 m/s rate but cap each pose update at 0.08 m, avoiding a large additive swing jump at 30 Hz without changing 60 Hz diagonal behavior. Both stride_sync runs pass: original forward-run toe drift about 0.004 m/s and planted drift about 0.00009 m/s; original/SWAT 30 Hz max joint steps 0.26386/0.25705 m. Both native_grip runs pass ten movement cases, prone hits and reload release. Logs stride-bounded-original.log and stride-bounded-swat.log are authoritative. The previous global 2.4 m/s release trial regressed SWAT diagonal toe contact and was replaced by the per-update bound.

Final scaled-motion validation: original native_recoil passes all headings/directions; original running blast-to-wall ragdoll reports wall contact, 0.0380 m first-second joint separation, 0.0103 m settled separation, and no script errors. Import/changelog/whitespace checks pass. build/run-contact-comparison.mp4 compares original unscaled motion on the left with final scaled motion/contact fixes on the right; the 10 fps landing sequence was inspected. The full battle movie still predates these changes.


Refreshed integrated recordings: build/battle-grounded.mp4 (28.05 seconds) includes the final rest-space/height-scale retarget, motion-aware landing, immediate plant acquisition and bounded release updates. build/controller-grounded.mp4 (18 seconds) exercises the playable terrain lab. The controller passes jump/reload/ragdoll/reset, ascent to 1.5567 m ground height and descent, magazine stow/replacement, maximum foot penetration 0.000000656 m, maximum contact correction change 0.100026 m. SWAT crouch_slope and cover_contacts pass after these changes. Viewer loading now depends on installed rifle clips instead of SWAT model identity; original-model viewer regression passes 56 clips, three projectile hits, two deaths and reset, including native-animation ragdoll handoff.

The launcher now honors `-Swat` in controller mode: use `-Controller -Swat` for the military model or `-Controller` for the original character. Both terrain-controller regressions pass, including original maximum foot penetration 0.000001207 m.


Latest localhost network audit (port 8050): network-framed-client.log passes moving/stationary crouch, diagonal movement, captured cover fingers, 0.008629 m cover toe clearance error, maximum grip error 0.000004272 m, repeated frontal flinch without rewind and skeletal death. The inspection camera now follows the fallen hips, with a check that head, hands, feet and hips all remain in the viewport; the refreshed network-animation-client.png was inspected and shows the full corpse. Host stderr is empty. WAN/loss remains untested. gameplay_crouch_walk had a stale expectation for the retired procedural stationary kneel; it now requires native crouch, settled crouch drop and stopped blend velocity. The move/stop/reload/restart/stand sequence passes, maximum joint step 0.0918 m. No sliding or transition limit was relaxed.


Stationary crouch cache: the current crowd has about 45 native poses among 52 skins, unlike the older fallback-dominated runs. Fresh baseline (crowd-grounded-baseline.log) is 32.4 FPS, 27.78 ms median frame, 46.62 ms p95 and 11.50 ms soldier-view CPU. The controller now reuses only its pre-contact local crouch sample when phase and actor global transform are exactly unchanged; reset invalidates it. Contacts, stance blending, upper body, reloads, recoil and hit reactions still update. Isolated stationary crouch pose/capture cost decreases from 237 to 168 microseconds; moving crouch remains about 300 microseconds. The 720-frame crouch_cache comparison covers movement, stationary turns, slope, reload, reset and stance transitions on both rigs. Max world-joint differences are 0.1553 mm SWAT and 0.01187 mm original; max basis-vector differences 0.0008912 and 0.0001063. This is bounded numerical equivalence, not bit identity. The uncached/uncached control reports zero differences. The initial stricter new-test bound was rejected after measuring IK sensitivity to world-space retarget roundoff; no existing movement/contact regression bound was changed. The new test independently limits joints to 0.5 mm and orientation axes to approximately 0.1 degree.

The serialized cached crowd run reports 34.2 FPS, 25.0 ms median, 48.61 ms p95 and 10.36 ms soldier-view CPU (crowd-crouch-cache.log). Compared with 32.4 FPS / 27.78 / 46.62 / 11.50 before, this single pair does not establish a stable frame-rate gain; tail pacing remains poor and 60 FPS is unmet. Terrain controller and rendered move/stop/crouch/reload/restart/stand checks pass unchanged, maximum joint step 0.0918 m. build/crouch-cache-route.mp4 and its contact sheet were inspected. Import/changelog/whitespace checks pass. Full battle and multiplayer were not rerun for this bounded-equivalence optimization.


Native IK feasibility check: the installed Godot 4.7.2 exposes TwoBoneIK3D. An isolated three-bone probe in build/native_ik_probe.gd sets manual skeleton processing, target (1, 1, 0) and pole (0, 0, 2). Immediately after Skeleton3D.advance, the endpoint is still (0, 2, 0) and modification_processed has not fired. After frame processing, the callback observes the solved endpoint (1, 1, 0), while the ordinary bone getter again returns the original (0, 2, 0). This rules out a direct synchronous replacement for solve_limb, whose callers immediately read corrected hands, feet and death momentum. No production solver was changed; moving the entire contact/grip/capture chain into modifier callbacks would need separate proof and profiling.

Current integrated recording: build/battle-current.mp4 is 1,683 frames / 28.05 seconds at 1600x900, recorded with the stationary-crouch cache. build/battle-current.log contains no SCRIPT ERROR, ERROR or WARNING entries. The sampled nine-frame sheet shows infantry movement/cover, wall impacts, fallen characters, tank impact and destruction; it was visually inspected. This is sampled visual verification, not proof of smooth motion throughout the movie or live 60 FPS. Recording took 79 seconds. Environment/tank art remains coarse relative to the imported infantry, and the crowd p95 issue remains unresolved. No production code changed during this feasibility/recording pass; multiplayer was not rerun.

Motion capture sampling now reads the skeleton world transform once per character and passes raw bone transforms into _sample_motion, which already normalizes the orientation. This removes the extra joint/world_pose call chain and its duplicate normalization. The 600-frame isolated profile reports capture cost 23.44/24.02/23.65/26.16 microseconds for idle/crouched idle/walk/crouched walk, versus 31.04/33.19/29.45/30.63 before. This measures sampling cost only, not whole-battle FPS. ragdoll_momentum now compares 120 translated/turning animated poses against the previous joint-based sampling on both rigs: maximum spin difference 0.00001304 rad/s (SWAT) and 0.00001280 (original), with linear velocity differences below 0.00001 m/s. Existing analytic COM transfer, root cancellation and reset checks pass. Import, changelog and whitespace checks pass.

A broader running-wall-blast check exposed an existing failure: SWAT rifle_run, impact-kind=1, wall-impact, assert-ragdoll reports first-second Spine2/RightForeArm overlap 0.0487225 m against the unchanged 0.04 m bound. Reverting only the sampling optimization and repeating yields 0.0487226 m, confirming this is not introduced by the sampling change. Logs are build/capture-ragdoll.log and build/capture-ragdoll-baseline.log. The optimized sampling was restored. The chest/forearm contact failure remains unresolved and is the next ragdoll investigation; do not describe this scenario as passing. No new crowd-FPS or multiplayer run was made for the sampling change. The latest battle recording predates it.


Wall-impact timestep diagnosis: speculative margins 0.05/0.06/0.08 m were tested and rejected. At 0.06 the SWAT running wall case improves to 0.01621 m early self-overlap and 0.02211 m wall penetration, but original running forearm wall penetration rises to 0.07191 m. At 0.08 SWAT self-overlap is 0.05758 m and original wall penetration 0.04290 m. Idle/crouch/prone SWAT and prop contacts passed at 0.06; this does not outweigh the original-rig regression. project.godot is restored to 0.04 m.

At 120 Hz with the original 0.04 m margin, both running wall cases pass: SWAT early overlap 0.01440 m / wall penetration 0.01530 m / early joint gap 0.01534 m; original 0.01298 / 0.02548 / 0.01935 m. A controlled build/impact_step_probe.gd keeps the original 60 Hz animation and captured death state and changes only the physics rate at impact: SWAT early overlap is 0.01718 m, wall penetration 0.01216 m, early joint gap 0.02369 m. This supports a physics-step diagnosis rather than an improved starting animation pose. No existing contact bound was relaxed.

The global 120 Hz change was rejected on performance grounds and reverted to 60 Hz: serialized 71-soldier / 52-skin crowd measurements are 33.6 FPS, 25.67 ms median / 53.97 ms p95 at 60 Hz versus 23.8 FPS, 36.59 / 69.26 ms at 120 Hz. World._physics_process currently runs the whole authoritative simulation every physics tick. A viable higher physics rate needs separate battle simulation scheduling and corrected entity render interpolation; simply increasing the project setting is not an acceptable completed fix.

build/forearm-step-comparison.mp4 shows current 60 Hz left / diagnostic 120 Hz right for four seconds. Its dense impact sheet was inspected; the 120 Hz movie passes unchanged bounds. This is an experiment, not the shipped/current demo configuration. The default wall-impact self-contact failure remains unresolved. No production physics change is retained from this pass; multiplayer was not rerun.


Retained split-clock implementation: physics now runs at 120 Hz with a 12-step catch-up ceiling; World accumulates scaled time and runs battle logic at 60 updates per second. Entity.ip_offset uses the battle fraction, including the intermediate physics tick. PhysicsFx retains the engine physics fraction for ragdolls and debris. The simulation_clock fixture checks 60/120 Hz inputs, time scales 0.5/1/5, retained elapsed time, the intermediate host transform and pause. Import passes. There is no network wire-format change.

The isolated running-wall regression now passes by default on both rigs: SWAT early overlap 0.01440 m / wall penetration 0.01530 m, original 0.01298 / 0.02548 m. SWAT idle/crouch/prone wall impacts and dropped-prop contacts pass unchanged bounds. The split-clock crowd run is 33.9 FPS, 26.077 ms median / 50.117 ms p95 versus the prior 60 Hz baseline 33.6 FPS, 25.67 / 53.97; the naive global 120 Hz version was 23.8 FPS, 36.59 / 69.26. This single serialized comparison shows recovery of the observed large scheduling penalty, not a stable FPS improvement or achievement of 60 FPS.

Fresh localhost replication (port 8060) passes crouched movement/stop, diagonal movement, cover fingers/feet, grip (max error 0.00000769 m), repeated frontal flinch without rewind, and fully framed death. The client corpse screenshot was inspected; host stderr is empty and both processes exited. Headless attack/tank scenarios ran 60 game seconds at timescale 5 without script errors. The first unseeded attack run reported seven leaked objects / two retained resources at shutdown; no such warnings occurred in the subsequent seed-3 comparison. Seed-3 attack at 60 and 120 physics Hz produces matching final combat reports (Rebels 118 shots/10 hits; Coalition 728/25) with the 60 Hz battle clock. This does not establish all-seed determinism or resolve the intermittent shutdown warning.

build/battle-split-clock.mp4 records 1,684 frames at 60 FPS, 1600x900, including infantry combat, fallen soldiers and tank destruction. Its sampled contact sheet was inspected; the log contains no script errors. Changelog before/after images now compare the same running wall fixture at 60/120 Hz. Clock/contact tests, import, changelog and whitespace checks pass. WAN/loss testing and final visual polish remain unfinished.


Directional crouch investigation: the local assets still contain only the forward MCO crouch clip. A limited +/-45-degree lower-body yaw trial with upper-body aim compensation increased planted sliding to 0.0230 m/s in crouch_transitions (unchanged limit 0.002 m/s). It was reverted; the restored controller reports 0.0000941 m/s at 120 Hz. No directional-crouch improvement is retained. The attempted before movie loaded the trial script after startup and is not valid comparison evidence; that process was stopped. build/crouch-heading-restored.log confirms the baseline is restored.

Military material correction: raw Swat.fbx surfaces Ch15_body and Ch15_body1 have normal_enabled=true and valid Swat_7/Swat_8 normal textures, but normal_scale=0. The shared SkinnedRifleman build now sets normal_scale=1 alongside its existing SWAT material calibration. build/material_detail.tscn captures the same stationary pose and lighting with strength 0 and 1 from front/back; the supplied maps and rendered front/back views were inspected. Fabric folds, vest webbing and equipment shading are restored. No mesh, skin weights, poses or animation timing changed. The main battle video predates this material-only correction.

The material audit also found the runtime-bound M4 JPG textures have mipmaps/generate=false, whereas the SWAT PNG textures have mipmaps enabled. The rifle appears excessively noisy/bright in the close-up. This is a separate presentation issue to investigate; no weapon material change has been made in this pass.


Rifle texture filtering: prepare_assets.py now creates or updates texture import sidecars with mipmaps/generate=true for the extracted JPG/PNG assets. It preserves existing UID/compression/other settings. A fresh minimal sidecar was accepted and completed by Godot; the new standard-library test exercises actual extraction into a temporary repository, fresh sidecar creation, repeated preparation, identity/custom-setting preservation and exact asset bytes. The user's supplied archive was re-prepared (30 files) and imported successfully. Runtime checks confirm 11 mip levels on M4DF2048, M4NM2048 and M4AO2048. The shared rifle material now opts into anisotropic filtering, using the existing player setting.

Matched close-ups build/rifle-mips-before.png and build/rifle-mips-aniso.png were inspected: the receiver, barrel and magazine have substantially less speckled minification. The source M4 material's albedo multiplier is approximately white, so the remaining light-grey finish is authored rather than a lost tint; it was not arbitrarily darkened. Geometry, grip sockets and animation timing are unchanged. Changelog before/after images are in rifle-texture-filtering. Import, fresh/repeat preparation test and changelog/whitespace checks pass. No new network or crowd benchmark was run for this texture-only change.

build/battle-materials.mp4 refreshes the in-game recording with both material corrections and the split clocks: 1,684 frames at 60 FPS / 28.07 seconds, 1600x900. The recording log has no errors or warnings. The sampled contact sheet was inspected. This remains a prototype with directional crouch, complete activity coverage, frame pacing and final overall art quality unfinished.

## Mounted finger recovery audit

Mounting immediately after sampling the rifle reload at 0.8 seconds retained up to 0.658436 radians of stale finger rotation. The shared fallback now restores the saved native grip finger rotations for crews as well as personal-weapon cover poses. The military M2 rendered fixture passes moving palm contact (0.000000421 m), platform clearance (0.180058 m), and finger recovery (0.000691 radians, quaternion numerical precision). Cover grip checks still pass. Matched before/after renders were inspected; fingers still need fitted wrapping around the actual mounted handles.

Broader tests exposed unfinished mounted geometry: original-model DShK palm error is 0.054010 m, and military M240 palm error is 0.040280 m with 0.052318 m platform penetration. Those bounds remain unchanged and these configurations fail; do not describe all mounted weapons or both models as validated. These are follow-up reach/stance problems, distinct from the corrected stale-finger state. The focused seven-second recording is `build/mounted-reload-recovery.mp4`.

The hidden procedural-pivot optimization was rejected: crowd results were 34.9 FPS versus 35.2 baseline, with unverified slung-weapon transitions. The original shared pose application was restored and import/M2 checks passed.

## Prone wall clearance

The wall fixture reproduced a 0.292024 m bone crossing during captured crouch-to-prone entry. Soldier now checks the whole transition envelope against L_COVER before choosing prone and in the shared posture sanity pass. The resulting crouch is authoritative; this is not a client-only pose override. The guard also clears a crawl action when prone is blocked. The static transition envelope was sized from sampled source motion with body margin; it is intentionally conservative and can reject a tighter possible pose. It does not solve collision for dives, existing ragdolls, or automatic relocation.

`tests/mocap/prone_wall.tscn` requests prone near a wall, verifies blocked posture and body clearance, then moves the wall away and verifies captured prone resumes. Front/rear/side military tests and a rotated original-rig test pass with zero measured crossing. The rendered before/after screenshots were inspected. `build/prone-wall-clearance.mp4` shows the blocked transition followed by clear-space entry.

The subsequent mounted-reach experiments are saved only in ignored build candidates; production remains at the preceding mounted-finger fix while wall clearance takes priority.

Validation for prone clearance: full import and seed-3 attack scenario (60 simulated seconds) finish without script errors. The localhost host/client animation fixture passes cover, crouch, repeated hits and ragdoll replication; it is a general regression check, not a networked reproduction of this wall case. The focused wall fixture checks every transition frame from the prone request, not only the final pose.

## PR gameplay recordings

The PR includes `changelog/unreleased/infantry-animation/gameplay.mp4`, captured from the ordinary `--scenario=motion --seed=3 --skinned-units --swat-units --motion-camera` battle, plus `game-activities.mp4`. The latter uses `tests/mocap/activities_game.tscn` with the same scenario and asset flags: it stages a normal sandbag work order and smoking idle choice, then applies a lethal hit. Its assertions require both activity states to occur. Use `--fixed-fps 60 --write-movie build/activities.avi` before `--` to record it. Local source assets are required. Recorded fixed-step movies do not measure real-time frame rate. The activity run reports ObjectDB instances at shutdown; cleanup remains unverified.
