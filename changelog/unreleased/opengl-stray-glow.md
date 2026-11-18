+++
title = "No stray glow in the middle of the map on OpenGL"
summary = "On computers that draw the game with OpenGL, a small white shape no longer glows on the ground in the middle of the map."
kind = "fixed"

[[screenshots]]
file = "compatibility-origin.jpg"
caption = "Current-build check at the map centre, with fires nearby. Stock Godot 4.7.2 Compatibility, Medium, software OpenGL, revision 217199e. The stray glow did not reproduce in the matching pre-fix capture on this renderer; this is not a before/after demonstration."
+++

- Muzzle flashes, tracers, smoke and flying debris waiting to be used could draw from leftover graphics memory as a
  bright shape at the centre of the map. They now start out empty, as they always did with Vulkan and Direct3D.

**Visual check:** the current build renders the map centre without the stray white shape in this capture. The memory-dependent fault did not appear in the matching pre-fix run on this cloud renderer, so the affected hardware still needs a before/after check.

For context, the [released impact close-up](https://github.com/Dynasty9/Frontline/blob/217199eff3950b2873a27cac00c17d216f001755/changelog/v1.0.13/realistic-armament-effects/impacts-close.webm?raw=true) shows the intended dust, debris and sparks when rounds hit dirt, stone and metal. This is historical Forward+ footage from v1.0.13, not evidence of the OpenGL glow correction.
