# Baking explosion effects

The game uses offline fluid simulations as relightable animated surfaces.
The raw VDB downloads and intermediate renders are deliberately kept outside
Git. Attribution, license and archive hashes are in `assets/vfx/LICENSE.md`.

## Rebuild

Use Blender 4.3 or later with Cycles CPU support, Python 3, NumPy, OpenCV and the OpenEXR Python package.
The shipping pack also uses [Intel Open Image Denoise 2.5.1](https://github.com/RenderKit/oidn/releases/tag/v2.5.1)
(`oidnDenoise`), an offline tool that is not included in the game.
Extract the two source archives, then run from the repository root:

```sh
blender -b --factory-startup --python tools/vfx/bake_volumes.py -- \
  --source /scratch/DustImpact/DustImpactVDB --kind dust --output /scratch/dust-frames
blender -b --factory-startup --python tools/vfx/bake_volumes.py -- \
  --source /scratch/ground_explosion/ground_explosion_VDB --kind fuel --output /scratch/fuel-frames
python tools/vfx/pack_flipbooks.py --source /scratch/dust-frames --kind dust --output assets/vfx --oidn /path/to/oidnDenoise
python tools/vfx/pack_flipbooks.py --source /scratch/fuel-frames --kind fuel --output assets/vfx --oidn /path/to/oidnDenoise
```

The baker resumes completed frames. Use a new output directory when changing
resolution, camera, density or lighting. The shipping bake uses 256 px
tiles, up to 512 samples (64 minimum, adaptive threshold 0.025), 64 frames, and
35°/65° elevation views. The first completed frames used fixed 512 samples;
`--fixed-samples` retains that reference mode. Time samples follow
`t = (frame / 63)^1.5`, allocating more frames to the fast opening. Runtime
inverts this mapping; changing it requires changing the shader too.

Three colored directional lights encode three independent scattering responses
in one render. A second pass reverses them. Fuel gets a third, unlit emission
pass in half-float EXR so bright cores retain their detail. The packer builds bidirectional DIS optical flow to warp adjacent frames
before blending. Alpha-weighted coefficients prevent dark outlines during that
blend. Motion is a visual interpolation aid, not a simulation of the blast.
Tiny per-frame bounds maps trim transparent space before rasterization; the
shader unions neighboring frames and camera views to preserve the silhouette.
These maps must stay lossless, linear and without mipmaps. Lighting and motion
atlases use standard S3TC/ETC2 compression so the browser can sample them too.

Clouds keep separate pooled surfaces so the renderer can sort overlapping
transparent bursts by depth. The high setting caps these at 28 dust and 12 fuel
surfaces; fragments and earth fans use shared instance rings. Bounds trimming
reduces transparent overdraw without sacrificing that cloud ordering. Low and
medium settings also avoid loading the optical-flow maps.
Opaque scenery clips a bounded density profile through each cloud instead of
depth-testing its flat middle. The shader integrates only the density ahead of
the sampled surface, so armor and walls intersect softly and foreground cover
still occludes the cloud. Thickness is an opacity-based approximation, not
collision-aware fluid flow. It uses the existing depth sample and no new atlas;
fully covered pixels are rejected before the animation-map reads.
Soil clouds ramp up behind the flash, use lower optical density and clear sooner
than fuel smoke. A small transmission floor prevents saturated dust texels from
remaining opaque when density is reduced. The existing GunFx flash batch presents
the initial impulse immediately, avoiding startup latency in a short GPU emitter.

Ground marks use `Res.GROUND_DECAL_LAYER`; terrain and roads receive them, while
walls, vehicles and effects keep their ordinary layers. HE uses lighter scorch
than fuel, with strength preserved through pool reuse and fading. Local crater
normals sample the height field at quarter-metre spacing to retain the bowl slopes.
With S3TC compression and mipmaps, the six animation atlases occupy about
58.7 MiB; omitting the two motion maps reduces that to 37.3 MiB. The two lossless
bounds maps add only 1 KiB. These figures describe the animation textures, not
the whole scene's graphics memory.

## Visual references and limits

- [Unity's six-way lighting explanation](https://unity.com/blog/engine-platform/realistic-smoke-with-6-way-lighting-in-vfx-graph)
  describes why directional scattering maps preserve smoke self-shadowing more
  convincingly than surface normals. Our Blender baker is original code; no
  Unity exporter code or package is bundled.
- [JangaFX's source animations](https://jangafx.com/software/embergen/download/free-vdb-animations/)
  supply the connected billows and turbulent dissipation.
- [DVIDS grenade range footage](https://www.dvidshub.net/video/743551/grenade-range-b-roll)
  is a visual reference for a brief, pale daytime burst and drifting smoke.
  It is not a size calibration or a shipped texture.
- [DVIDS artillery-impact photograph](https://www.dvidshub.net/image/35313/army-denies-insurgent-stronghold-diyala)
  shows the dense, uneven fans of earth in the opening burst. It informs the
  broad ejecta strips and their rapid breakup, rather than a glowing spark spray.

Ground composition, moisture, confinement and fuel change a real explosion's
appearance. The game's roughly 110 mm visual scale is an art direction target,
not a calibrated prediction from calibre. HE and grenade bursts favor dust,
short flashes and dark fragments; sustained flame belongs to fuel. Two baked
views improve the RTS camera range but remain an approximation to a volume.
Validate both renderers, nearby opaque geometry, elevated ground, night/day,
close/RTS cameras, pause/time scale, and a saturated pool before changing these
assets. Capture real output through `tools/showcase/` for review.

## Validation and measurement

With Godot 4.7.x imported into the project:

```sh
GODOT=/path/to/godot node --test tests/armament-effects.test.mjs
FL_TEST_RENDER=1 GODOT=/path/to/godot node --test tests/armament-effects.test.mjs
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --fixed-fps 60 --resolution 1280x720 res://tests/fixtures/blast-benchmark.tscn
```

The opt-in rendering checks need a display (Xvfb works). They sweep opaque cover
through the production cloud shader with perspective and orthographic cameras,
partly transparent and opaque texels, both renderers, and MSAA off/4x. Pixel
readback checks full foreground occlusion, continuity across the billboard
plane, and increasing visible density. Renderers warm up before sampling.
They also check dust onset/clearing and run a Forward+ decal test that compares
ground, cover and opaque-smoke pixels with each real ground mark enabled/disabled.

The benchmark emits `BLAST_BENCH` JSON for 69 seeded HE bursts over four
simulated seconds. It fixes High effects, 2x MSAA and full render scale, warms
the effect programs, and measures the last 180 of 240 frames. Positions have
their own random generator so changing cosmetic randomness does not move the
comparison's bursts. Run both revisions on the same engine, device and renderer,
with other rendering/baking work stopped, and repeat to expose timing variance.
Frame times are wall time through `frame_post_draw`, not GPU timestamp queries.
This controlled scene isolates effects; it is not a full-battle FPS estimate.
