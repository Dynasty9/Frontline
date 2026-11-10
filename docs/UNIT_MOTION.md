# Shared unit motion prototype

**Status:** Integrated prototype with optional imported riflemen; see [current setup and validation](../tests/mocap/SKINNED.md).
**Updated:** 2026-10-23

## Decision and scope

Keep simulation, damage and navigation server-authoritative. Reuse visual animation
and impact components across models. Start validation with one rifleman and one tank.
Procedural meshes remain the default. Locally installed character and animation assets
enable skinned Coalition riflemen with captured locomotion, contact IK and skeletal ragdolls.

The reusable pieces are:

- `HumanoidRig`: joint names, collision shapes, mass and anatomical limits shared by
  human ragdolls. Clothes and weapons are independent of this description.
- `HumanoidGait`: shared Animation resources for contact, passing and recovery poses,
  sampled by each soldier at his own movement phase. Walk/run blending keeps one gait
  controller across models. These are provisional authored curves, not motion capture.
- `HumanoidMotion`: acceleration and turning weight shifts, counter-motion of the head
  and shoulders, and directional hit recovery on top of the existing actions.
- `ImpactResponse`: bounded, critically damped reactions with an analytic update so
  throttled rendering does not make the spring unstable. Used by humans and vehicles.
- `Ragdoll`: takes the current pose, preserved travel velocity and a separate hit velocity.
  Blast spin is coherent across the body; bullet impulses are restrained. Settling now
  considers angular movement as well as linear movement.

`Fx.UNIT_HIT` carries entity ID, world direction and normalized strength. `Fx.DIE`
also carries travel velocity. Net version 12 separates incompatible peers. The hit
direction is available from current combat; precise limb hit locations are not yet
part of that event. Living hits remain animation overlays, not gameplay knockdowns.

Ragdolls are local cosmetic physics, capped at 16 nearby bodies by PhysicsFx. Wall
colliders and the ground stop them; their final positions need not match across peers.
Tank suspension reacts to hits; the existing wreck system still owns destruction and
the server-selected final wreck position. The lab also exercises a heavy rigid-body
wreck, but does not add detachable turrets or a new vehicle destruction model.

## Why this first

Rewriting all units around a third-party skeleton before testing an actual animation
asset would entangle asset choices with combat code. Retaining the procedural fallback
lets the existing specialist actions keep working while a single imported rifleman is
evaluated. The trade-off is that the present rigid joints cannot provide smooth skin
deformation at shoulders, elbows and knees.

## Animation acquisition

First candidate: [MoCap Online Rifle, FBX format](https://mocaponline.com/products/rifle).
The vendor lists in-place and root-motion versions, aiming, crouch movement and turns,
reloads, and transition clips. Evaluate the exact tier's animation list before buying;
prone/crawl, casualty dragging and crew work must be checked separately. The
[free sampler](https://mocaponline.com/pages/free-animations) requires an email form.
No purchase or email submission has been made, and compatibility is not yet verified.

Alternative: [Kubold Rifle Animset Pro](https://www.kubold.com/store), whose store
states that packs include FBX source files. Check its
[animation lists](https://www.kubold.com/downloads) for required stance coverage.

Acceptance criteria for a sample:

1. Import a skinned humanoid and its clips into Godot 4.7.2; verify scale, forward axis,
   rest pose, and feet at ground level. Use Godot humanoid retargeting to one shared rig.
2. Use in-place clips driven by authoritative speed. Test idle/walk/run blending,
   strafing, turn-in-place, start/stop and standing/crouching transitions.
3. Check the rifle socket, two-hand grip and aim layering at several directions.
4. Transfer the exact animated bone pose and movement into the shared ragdoll. A skinned
   character needs a Skeleton3D adapter; the current Node3D rig is not that adapter.
5. Test multiple body proportions, wall collisions, 30/60 Hz rendering and a full squad.
   Only then commit to a paid pack and convert the other models.

Paid source assets must not be committed to a public repository without a license
that permits source redistribution. Keep evaluation files outside tracked assets.

## Running the lab

From the repository root:

```text
godot --path . tests/unit_motion_lab.tscn -- --no-stun
godot --headless --path . tests/unit_motion_lab.tscn -- --no-stun
godot --headless --path . tests/impact_response_test.tscn -- --no-stun
godot --path . tests/unit_motion_lab.tscn -- --screenshot=build/impact.png --shot-at=6.25 --no-stun
```

The lab has no battle, network listener or AI. At two seconds it shows directional
reactions, at six seconds a blast throws the rifleman toward a solid wall, and at nine
seconds the tank becomes a heavy physics body. It exits at fourteen seconds. Watch the
sequence, not just a still frame: a screenshot cannot establish animation quality.

The [MCO sample trial](../tests/mocap/README.md) now imports real rifle clips with an
AnimationTree, shows the supplied skinned mannequin, and retargets onto the existing
articulated rifleman with ragdoll handoff. The next milestone is a final skinned
rifleman and Skeleton3D ragdoll adapter. Foot locking, physical knockdowns/get-up
and detachable vehicle parts remain follow-up work, not completed features.

## Validation

Checked with Godot 4.7.2 on Windows:

- Project import: no script or parse errors.
- `tests/impact_response_test.tscn`: hit direction, frame-rate independence, repeated-hit bounds,
  long-frame recovery and retained travel velocity pass.
- Lab: completes headless and rendered, with wall/floor collision bounds checked.
- Attack and tank scenarios: reach FINAL; both hit-reaction counters fire.
- Host/client on a dedicated local port: client receives 3,772 entities; no script errors.
- Changelog validation and whitespace checks pass.

The attack scenario reports seven leaked objects and two resources at shutdown. The
same warning reproduces in the unchanged HEAD checkout; it is not resolved here.
Before/after images use the same lab and camera, with the baseline loading HEAD's
models and animation code. The local `build/unit-motion.mp4` records the full sequence.

The local motion evaluation also has an interactive viewer
(`tests/mocap/viewer.tscn`, or `play_skinned.ps1 -Viewer`): choose an installed
sample clip, scrub and slow playback, compare the source mannequin, and click the
skinned rifleman to test projectile reactions and ragdolls against a wall.
