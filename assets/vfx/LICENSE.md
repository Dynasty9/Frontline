# Explosion flipbooks

The `dust_*.png` and `fuel_*.png` textures are derived from JangaFX's free
EmberGen volume animations, released under **CC0 1.0 (public domain)**.
The original license is preserved in [CC0-JangaFX.txt](CC0-JangaFX.txt).

- Publisher and license statement: <https://jangafx.com/software/embergen/download/free-vdb-animations/>
- Dust: **Grenade Dust Impact**, `GrenadeDustImpactVDB.zip`.
  <https://www.mediafire.com/file/6vgbsjl9bnfy7xx/GrenadeDustImpactVDB.zip/file>
  SHA-256: `fcf51583861c86146fcd391e830eb9e1ed440a477628d1e00f0371a60f0feb6a`
- Fuel: **Ground Explosion**, `GroundExplosionVDB.zip`.
  <https://www.mediafire.com/file/vm64xg0vta64qgl/GroundExplosionVDB.zip/file>
  SHA-256: `47c2c1d352b3c0dce31e462d09ede9f8bc95b5333ca9764564073b02113dc7b9`

Downloaded 2026-11-06. These are simulated fluid volumes, not recordings of
real explosions. No reference footage or third-party executable is bundled.
Frontline's original baking, packing and runtime code lives in `tools/vfx/`
and `scripts/game/blast_flipbooks.gd`.

Each sequence contains 64 time samples from two elevations. Positive RGB
stores light arriving from camera right, up and front; negative RGB stores
left, down and back. Positive alpha is opacity, negative alpha is integrated
fuel emission (the dry-dust negative map is RGB only). The motion texture contains forward and backward optical flow.
The small bounds textures store each frame's occupied rectangle for trimming
transparent pixels before drawing.
Coefficients are linear and premultiplied by opacity; do not import these maps
as sRGB, repair their alpha borders, or premultiply them a second time.
