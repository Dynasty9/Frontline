+++
title = "What each graphics setting costs"
summary = "A benchmark now measures what each graphics setting costs the graphics card. On an RTX 3090 at 1080p, shadows, anti-aliasing and fire shadows are what cost; the Cinematic camera and lens effects, heat haze and cloud shadows hardly register."
kind = "improved"
+++

Measured on an RTX 3090 at 1920 x 1080, Cinematic settings, a tank battle at golden hour seen from the command camera, the battle held still. Each setting was switched off and on ten times in a row. The figures are from two separate runs:

| Setting | Costs the graphics card |
|---|---|
| Shadow quality Ultra (against Off) | 7 to 9 ms a frame |
| Render scale 100% (against 50%) | 7 ms |
| Anti-aliasing MSAA 4x + SMAA (against Off) | 3 ms |
| Shadows from fire and flares (nearest 6) | about 3 ms |
| Texture filtering 16x | about 1.7 ms |
| View distance Far (against Near) | about 1.4 ms |
| Global illumination | 1.1 ms |
| Ambient occlusion, depth of field | about 0.5 ms each |
| Lens flare, sun shafts, local exposure, eye adaptation, film look, heat haze, physical sky, cloud shadows, adaptive shadows | too little to measure (under about half a millisecond each) |

The whole frame took about 16 ms. A slower card pays more, in roughly the same order. The physical sky costs more when the camera is tilted up and a lot of sky is in view.
