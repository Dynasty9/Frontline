# Shared vehicle surfaces and bodywork

These comparisons isolate the exterior pass: before **649e896**, after **7ca2504**.
Both versions already include the earlier shared wheel, track, glazing and rotor improvements.
Native Godot 4.6.3 captures (the project targets 4.7), 1600×900, seed 3, team 0,
Compatibility renderer, identical studio light and camera per pair; five process frames.
Images are uncropped. Close body views intentionally exclude parts of the full vehicle.

## Body comparisons

| Vehicle | Before | After |
|---|---|---|
| heli | ![Before](body-heli-before.jpg) | ![After](body-heli-after.jpg) |
| zamak | ![Before](body-zamak-before.jpg) | ![After](body-zamak-after.jpg) |
| hemtt | ![Before](body-hemtt-before.jpg) | ![After](body-hemtt-after.jpg) |
| tempest | ![Before](body-tempest-before.jpg) | ![After](body-tempest-after.jpg) |

The helicopter's broad flat shading becomes curved skin shading; thin joins and fasteners follow
the existing stations. Angular stealth sections keep their creases. Truck doors use pressed panels
with gaskets and screws; Zamak bonnet vents have raised louvres. These additions are built through
shared family methods, so their cargo, fuel, medical and other variants inherit them.

## Finish coverage

| Profiles | Shared change |
|---|---|
| Armor, aircraft, automotive, marine | Separate paint relief strengths, roughness, weathering and clearcoat response |
| Rotor, plastic | Fine moulded grain with restrained reflections |
| Rubber | Matte relief and weathered surface film |
| Canvas | Photographic relief plus filtered weave; broader fabric tone variation |
| Steel, gunmetal, track | Directional roughness grain; stronger wear on track metal |
| Glass | Lower roughness; less opaque transparent cab panes |
| Nonslip, tread | Stronger grip relief with companion normal maps |
| Oxidized | Mineral rust over exposed metal with photographic normal relief |
| Wood | Directional fibres over existing local wood pattern |
| Burnt | Ash variation and rough char relief |

Six photographic normal sources are bundled ambientCG CC0 assets; the other two maps derive from
original MIT heights. Eight 512px linear normal maps have mipmaps enabled. Bake hashes and licences
live in `assets/vehicles/surfaces/`. Paint relief is deliberately weaker than fabric and grip.

| Before | After |
|---|---|
| ![Before finishes](swatches-before-roster-00.jpg) | ![After finishes](swatches-after-roster-00.jpg) |
| ![Before finishes](swatches-before-roster-01.jpg) | ![After finishes](swatches-after-roster-01.jpg) |

## Whole vehicle comparisons

Changes to fine roughness and grain are subtle at this scale; body geometry and canvas read more clearly. These are material upgrades, not a complete silhouette rebuild.

| Vehicle | Before | After |
|---|---|---|
| gun_trawler | ![Before](before-gun_trawler.jpg) | ![After](after-gun_trawler.jpg) |
| heli | ![Before](before-heli.jpg) | ![After](after-heli.jpg) |
| hunter | ![Before](before-hunter.jpg) | ![After](after-hunter.jpg) |
| offroad | ![Before](before-offroad.jpg) | ![After](after-offroad.jpg) |
| old_tank | ![Before](before-old_tank.jpg) | ![After](after-old_tank.jpg) |
| patrol_ship | ![Before](before-patrol_ship.jpg) | ![After](after-patrol_ship.jpg) |
| rhib | ![Before](before-rhib.jpg) | ![After](after-rhib.jpg) |
| tank | ![Before](before-tank.jpg) | ![After](after-tank.jpg) |
| wreck_tank | ![Before](before-wreck_tank.jpg) | ![After](after-wreck_tank.jpg) |
| zamak | ![Before](before-zamak.jpg) | ![After](after-zamak.jpg) |

## Roster inspection

All 143 subjects rendered and reviewed in the front-view sheets, including parked cars and wrecks. Material tests also build both faction palettes. Additional rear views cover twelve subjects in team 1.

[Roster sheet 1](roster-after-roster-00.jpg) · [Roster sheet 2](roster-after-roster-01.jpg) · [Roster sheet 3](roster-after-roster-02.jpg) · [Roster sheet 4](roster-after-roster-03.jpg) · [Roster sheet 5](roster-after-roster-04.jpg) · [Roster sheet 6](roster-after-roster-05.jpg) · [Roster sheet 7](roster-after-roster-06.jpg) · [Roster sheet 8](roster-after-roster-07.jpg) · [Roster sheet 9](roster-after-roster-08.jpg) · [Roster sheet 10](roster-after-roster-09.jpg) · [Roster sheet 11](roster-after-roster-10.jpg) · [Roster sheet 12](roster-after-roster-11.jpg) · 

![Rear views, team 1](rear-team1-roster-00.jpg)

Forward+ cross-checks: [heli](forward-heli.jpg) · [zamak](forward-zamak.jpg) · [tank](forward-tank.jpg) · [patrol_ship](forward-patrol_ship.jpg)

## Reproduce and validate

Use `tools/showcase/vehicle-surfaces.tscn` with `--surface-single --surface-ground`.
For the body pairs, add `--surface-kinds=heli --surface-focus=0,1.4,-2 --surface-size=5`,
or `--surface-kinds=zamak,hemtt,tempest --surface-focus=0,2,-2.8 --surface-size=5`.
The baseline uses the same extended capture harness. Default view direction is `(1,.65,-1.25)`.
For finish sheets use `--surface-swatches`; omit single/kinds for the full roster.
Set `--rendering-method gl_compatibility` before the scene and `--surface-out=OUTPUT` after `--`.
Repeat selected subjects with `--rendering-method forward_plus` for the desktop cross-check.

Six tests passed across materials, components, rotors, distance meshes, motion and sockets.
New assertions check normal-map mipmaps and body smoothing without vertex/bounds changes.
Roster and sling scenarios completed with no script errors; roster reported shutdown resource warnings.
No performance improvement is claimed; the shader adds three normal texture samples per detailed surface.
