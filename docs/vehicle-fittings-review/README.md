# Vehicle service fittings review

Before: `d5cea3d` (main after PR #150). After: `fdfdf1f`. Captured with Godot 4.7.2, seed 3, team 0, at 1600 × 900. These are incremental construction improvements; the exterior paint and unique silhouettes are inherited from main.

The grille core is recessed behind angled slats; exhaust tips have actual uncapped geometry and an inward-facing soot sleeve. Rubber flaps gain a curled edge, ribs and a clamp. Bags have softened shells, a sewn welt and fitted straps. Existing solid Slammer/Scorcher bag supports were hiding their contents and are now shallow trays.

## Close inspection

| Subject | Before | After |
|---|---|---|
| hemtt cab, grille and exhaust | ![](close-before-hemtt.jpg) | ![](close-after-hemtt.jpg) |
| zamak cab, grille and exhaust | ![](close-before-zamak.jpg) | ![](close-after-zamak.jpg) |
| tempest cab, grille and exhaust | ![](close-before-tempest.jpg) | ![](close-after-tempest.jpg) |
| marshall rear / stowage | ![](rear-before-marshall.jpg) | ![](rear-after-marshall.jpg) |
| slammer rear / stowage | ![](rear-before-slammer.jpg) | ![](rear-after-slammer.jpg) |
| ifrit rear / stowage | ![](rear-before-ifrit.jpg) | ![](rear-after-ifrit.jpg) |
| scorcher rear / stowage | ![](rear-before-scorcher.jpg) | ![](rear-after-scorcher.jpg) |

## Shared construction

![](construction-roster-00.jpg)

New builder examples, not historical comparison footage. The inspection light differs from the vehicle stage so recesses and fabric construction can be seen.

## Affected family comparisons

All 20 affected families have a representative before/after below. Armed, support and upgraded variants inherit their family helpers. Small fittings are intentionally subtle at whole-vehicle scale; use the close views to judge them. This pass does not claim a full-roster visual rework.

| Family | Before | After |
|---|---|---|
| hemtt | ![](before-hemtt.jpg) | ![](after-hemtt.jpg) |
| zamak | ![](before-zamak.jpg) | ![](after-zamak.jpg) |
| tempest | ![](before-tempest.jpg) | ![](after-tempest.jpg) |
| hunter | ![](before-hunter.jpg) | ![](after-hunter.jpg) |
| ifrit | ![](before-ifrit.jpg) | ![](after-ifrit.jpg) |
| strider | ![](before-strider.jpg) | ![](after-strider.jpg) |
| prowler | ![](before-prowler.jpg) | ![](after-prowler.jpg) |
| marshall | ![](before-marshall.jpg) | ![](after-marshall.jpg) |
| rhino | ![](before-rhino.jpg) | ![](after-rhino.jpg) |
| slammer | ![](before-slammer.jpg) | ![](after-slammer.jpg) |
| scorcher | ![](before-scorcher.jpg) | ![](after-scorcher.jpg) |
| sandstorm | ![](before-sandstorm.jpg) | ![](after-sandstorm.jpg) |
| panther | ![](before-panther.jpg) | ![](after-panther.jpg) |
| bobcat | ![](before-bobcat.jpg) | ![](after-bobcat.jpg) |
| cheetah | ![](before-cheetah.jpg) | ![](after-cheetah.jpg) |
| marid | ![](before-marid.jpg) | ![](after-marid.jpg) |
| varsuk | ![](before-varsuk.jpg) | ![](after-varsuk.jpg) |
| mora | ![](before-mora.jpg) | ![](after-mora.jpg) |
| kuma | ![](before-kuma.jpg) | ![](after-kuma.jpg) |
| gorgon | ![](before-gorgon.jpg) | ![](after-gorgon.jpg) |

## Reproduction and validation

```sh
godot --path CHECKOUT --rendering-method gl_compatibility --audio-driver Dummy tools/showcase/vehicle-surfaces.tscn -- --surface-out=OUTPUT --surface-single --surface-kinds=KINDS --surface-ground
```

Both revisions use the same studio light, five process frames, bounds-based whole-vehicle camera and direction `(1, .65, -1.25)`. Truck close-ups add `--surface-focus=0,2,-2.8 --surface-size=5` for fixed framing. Rear views add `--surface-rear`, direction `(-1,.65,1.25)`. Construction uses `--surface-fittings` without ground or single mode.

Forward+ uses the same 20 family keys without `--surface-single`, producing these two sheets:

![](forward-roster-00.jpg)
![](forward-roster-01.jpg)

Six vehicle tests pass, covering materials across the roster and both teams, components, LOD, movement, sockets and rotors. Added assertions check uncapped exhaust geometry, inward-facing sleeves, arbitrary-axis placement and folded fitting mounts. The seeded roster scenario ran without script errors; shutdown reported ObjectDB/resource cleanup warnings. These tests establish integration, not a measured rendering performance improvement.
