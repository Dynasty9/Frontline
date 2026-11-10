# MCO sample evaluation

This local demo uses the supplied **MCO Demo Pack v2**, MotusMan v55 FBX rig.
It compares the existing procedural rifleman, the same model driven by mocap,
and the supplied skinned mannequin. It is a development scene, not a replacement
for battlefield units. The source FBX and textures are excluded from Git.

The subsequent [skinned rifleman integration](SKINNED.md) adds a separate armored
character, contact IK, same-mesh skeletal ragdolls and opt-in battlefield units.
The limitations below describe this original comparison scene.

## Run from the repository root

```powershell
python tests/mocap/prepare_assets.py C:/Users/dines/Downloads/MCO_Demo_Pack_v2.zip
godot --headless --path . --import
godot --path . tests/mocap/demo.tscn -- --no-stun
```

Preparation also enables mipmaps for the supplied 3D textures, preserving existing import IDs and other settings. Rerun preparation and import for an existing installation to apply this correction. Check fresh/repeated preparation with `python tests/mocap/test_prepare_assets.py`.

Use the Godot 4.7.2 console executable in place of `godot` if it is not on PATH.
The scene ends after 26 seconds. `--duration=SECONDS` shortens the run;
`--screenshot=build/frame.png --shot-at=5` captures a frame.

```powershell
godot --path . --write-movie build/mocap-demo.avi --fixed-fps 30 tests/mocap/demo.tscn -- --no-stun
```

## What the demo exercises

| Time | Action |
| --- | --- |
| 0-3 s | Rifle aiming idle |
| 3-7 s | Rifle walk, speed-driven AnimationTree |
| 7-11 s | Rifle jog |
| 11-14 s | Unarmed crouch walk from the mobility sample |
| 14-17 s | Authored aiming-to-relaxed transition |
| 17-20 s | Hit spring layered onto the procedural soldier rigs |
| 20-26 s | Retargeted rifleman hands its pose to the shared ragdoll |

`MocapCharacter` shares clips through an AnimationLibrary and blends idle/walk/jog
with AnimationTree. It preserves the source's constant bone tracks, removes embedded
cameras, fixes texture references, and strips horizontal root translation for the RTS
movement controller. The M4 uses a fixed animated RightHandMiddle1 socket calibrated in the imported
aiming reference, accounting for the different trigger/support grip heights.
This preserves authored weapon roll and pitch through stance changes.
`MocapRetarget` maps eleven joints by rest-space rotation while retaining target limb
lengths. It passes the current articulated pose to the existing Ragdoll; the demo
checks handoff positions and settled wall/floor bounds.

## Buying decision and remaining work

The sample is suitable for proving this pipeline. Prefer one coherent rifle library
from the same vendor/rig family if its full clip list covers the game's stances.
The sample does not prove strafing, backward motion, prone, reloads, turning, firing
layers, foot locking, slopes, or get-up transitions. The crouch clip is unarmed.
Different proportions still need foot and two-hand IK. The original articulated
model retains rigid shoulders and simplified feet even with better motion.

The supplied mannequin is evaluation art. A final skinned military character still
needs compatible rigging/retargeting. Native Skeleton3D ragdolls, production animation
state integration, squad-scale performance and networked imported-unit testing are
follow-up work. The mannequin keeps animating during the articulated rifleman's
ragdoll demonstration; it does not yet have its own skeletal physics adapter.

The separate `tests/unit_motion_lab.tscn` demonstrates tank hit recovery and heavy
wreck settling; the human animation pack supplies no tank physics or animation.

## Verified in this worktree

Godot 4.7.2 imported the project without script/parse errors. The complete rendered
26-second run and headless physics run completed. Ragdoll joint-position handoff
error was 0.000000 m; monitored rigid bodies contacted the wall and stayed within
the floor/wall bounds. The shared impact-response tests passed. The encoded
1600x900, 30 fps video and its stage contact sheet were checked visually.

Local outputs: `build/mocap-demo.mp4`, `build/mocap-final.png`, and
`build/rifleman-tank-physics.mp4` (the earlier shared-physics lab recording).
