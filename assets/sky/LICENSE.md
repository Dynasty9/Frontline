# Daylight panorama

Kloofendal 48d Partly Cloudy (Pure Sky), by Greg Zaal (photography) and Jarod Guest (sky edits), Poly Haven. CC0 1.0, redistribution and commercial use permitted.

- Source: https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky
- License: https://polyhaven.com/license
- Original 2K HDR: https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/kloofendal_48d_partly_cloudy_puresky_2k.hdr
- Original MD5: 2eba3a4d7eeb23cbfbeca364c97e7980

The bundled panorama is unmodified. Runtime rotation aligns the photographed sun with the daylight directional light. Highlights are limited in the shader to avoid an oversized sun contribution in the low-resolution reflection cache.

`cloud_noise.res` is project-generated seamless 3D noise, not part of the photograph. Rebuild it with `tools/vfx/bake_cloud_noise.gd`; it stores a 64³ single-channel volume so cloud rendering needs no runtime noise generation.
