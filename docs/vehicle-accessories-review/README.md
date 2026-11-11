# Vehicle antennas, mirrors and barrels review

Before: `37085ab` (main after PR #153). After: `21ed5c4`. Godot 4.7.2, seed 3, team 0, 1600 × 900. These changes build on the merged exterior and service-fitting work.

## Matched close-ups

| Part | Before | After |
|---|---|---|
| Slammer muzzle and sleeve | ![](barrel-before-slammer.jpg) | ![](barrel-after-slammer.jpg) |
| HEMTT mirror, viewed from behind | ![](mirror-before-hemtt.jpg) | ![](mirror-after-hemtt.jpg) |
| Slammer radio mount | ![](antenna-before-slammer.jpg) | ![](antenna-after-slammer.jpg) |

The gun has a real opening with an inward-facing bore, an annular crown, sleeve seams and clamp latches. The mirror has a moulded shell, rubber perimeter, slightly convex face and support arms routed around its edges. The radio whip has a bolted foot, rubber boot and helical spring. The long whip is cropped in the mount close-up; whole-vehicle views below retain its tip.

Mirror finish uses environment reflections. This is not a live planar rear-view camera; dark surroundings can leave the face dark, as in this studio. Tiny attachments remain subtle at ordinary RTS camera distances.

## Shared construction

![](components-roster-00.jpg)

These are new helper examples under an inspection light, not historical before/after footage. The antenna example has a shorter whip to expose its base.

## Coverage

- Shared antennas: core, NATO, CSAT and independent land-vehicle whip helpers, plus technicals. Aircraft blades, ship aerials and radar arrays retain their authored construction.
- Shared mirrors: HEMTT, Tempest, Zamak, Hunter, Ifrit, Strider, Qilin, Humvee, technicals and the core truck, including variants using those builders.
- Shared barrels: Abrams, T-55, Slammer, Rhino, Kuma, Varsuk, Angara, Scorcher and Sochor. The T-55 remains unsleeved. Extractors, reference sensors, gun markers and elevation/recoil ownership stay with their family builders; the artillery brakes now have open annular baffles.

## Representative whole-vehicle pairs

| Vehicle | Before | After |
|---|---|---|
| hemtt | ![](before-hemtt.jpg) | ![](after-hemtt.jpg) |
| zamak | ![](before-zamak.jpg) | ![](after-zamak.jpg) |
| tempest | ![](before-tempest.jpg) | ![](after-tempest.jpg) |
| hunter | ![](before-hunter.jpg) | ![](after-hunter.jpg) |
| ifrit | ![](before-ifrit.jpg) | ![](after-ifrit.jpg) |
| strider | ![](before-strider.jpg) | ![](after-strider.jpg) |
| slammer | ![](before-slammer.jpg) | ![](after-slammer.jpg) |
| rhino | ![](before-rhino.jpg) | ![](after-rhino.jpg) |
| kuma | ![](before-kuma.jpg) | ![](after-kuma.jpg) |
| varsuk | ![](before-varsuk.jpg) | ![](after-varsuk.jpg) |
| scorcher | ![](before-scorcher.jpg) | ![](after-scorcher.jpg) |
| sochor | ![](before-sochor.jpg) | ![](after-sochor.jpg) |
| angara | ![](before-angara.jpg) | ![](after-angara.jpg) |
| tank | ![](before-tank.jpg) | ![](after-tank.jpg) |
| old_tank | ![](before-old_tank.jpg) | ![](after-old_tank.jpg) |
| humvee | ![](before-humvee.jpg) | ![](after-humvee.jpg) |
| technical | ![](before-technical.jpg) | ![](after-technical.jpg) |
| truck | ![](before-truck.jpg) | ![](after-truck.jpg) |
| qilin | ![](before-qilin.jpg) | ![](after-qilin.jpg) |

## Full roster comparison

Both revisions rendered all 143 showcase entries. These include unchanged aircraft, ships and civilian vehicles as regression context; this does not mean every entry received new fittings.

| Sheet | Before | After |
|---|---|---|
| 1 | ![](roster-before-roster-00.jpg) | ![](roster-after-roster-00.jpg) |
| 2 | ![](roster-before-roster-01.jpg) | ![](roster-after-roster-01.jpg) |
| 3 | ![](roster-before-roster-02.jpg) | ![](roster-after-roster-02.jpg) |
| 4 | ![](roster-before-roster-03.jpg) | ![](roster-after-roster-03.jpg) |
| 5 | ![](roster-before-roster-04.jpg) | ![](roster-after-roster-04.jpg) |
| 6 | ![](roster-before-roster-05.jpg) | ![](roster-after-roster-05.jpg) |
| 7 | ![](roster-before-roster-06.jpg) | ![](roster-after-roster-06.jpg) |
| 8 | ![](roster-before-roster-07.jpg) | ![](roster-after-roster-07.jpg) |
| 9 | ![](roster-before-roster-08.jpg) | ![](roster-after-roster-08.jpg) |
| 10 | ![](roster-before-roster-09.jpg) | ![](roster-after-roster-09.jpg) |
| 11 | ![](roster-before-roster-10.jpg) | ![](roster-after-roster-10.jpg) |
| 12 | ![](roster-before-roster-11.jpg) | ![](roster-after-roster-11.jpg) |

## Renderer and integration checks

![](forward-roster-00.jpg)
![](forward-roster-01.jpg)

Forward+ checked the same 19 representative vehicles. Six vehicle tests pass, covering roster materials in both palettes, components, LOD, movement, sockets and rotors. New checks cover uncapped barrel geometry, inward-facing bores, arbitrary-axis placement, gun-marker parentage, folded mounts and the separate mirror finish. The seeded roster scenario ran without script errors; shutdown reported ObjectDB/resource cleanup warnings.

## Reproduce

```sh
godot --path CHECKOUT --rendering-method gl_compatibility --audio-driver Dummy tools/showcase/vehicle-surfaces.tscn -- --surface-out=OUTPUT --surface-single --surface-kinds=KINDS --surface-ground
```

Whole views use the same bounds-based framing, studio light and direction `(1,.65,-1.25)`. Fixed close-ups add:

| Detail | Flags |
|---|---|
| Mirror | `--surface-kinds=hemtt --surface-focus=-1.52,2.28,-4.52 --surface-size=1.4 --surface-rear` |
| Antenna base | `--surface-kinds=slammer --surface-focus=1.05,2.9,3.15 --surface-size=1.4 --surface-rear` |
| Barrel | `--surface-kinds=slammer --surface-focus=0,2.22,-4.6 --surface-size=2.1` |

Rear views use direction `(-1,.65,1.25)`. Full roster sheets omit `--surface-single` and `--surface-kinds`. Construction uses `--surface-accessories` without ground/single flags. Forward+ uses `--rendering-method forward_plus` and the 19 whole-vehicle keys without single mode. Every capture waits five process frames before saving.
