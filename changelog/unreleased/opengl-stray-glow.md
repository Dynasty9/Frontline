+++
title = "No stray glow in the middle of the map on OpenGL"
summary = "On computers that draw the game with OpenGL, a small white shape no longer glows on the ground in the middle of the map."
kind = "fixed"
+++

- Muzzle flashes, tracers, smoke and flying debris waiting to be used could draw from leftover graphics memory as a
  bright shape at the centre of the map. They now start out empty, as they always did with Vulkan and Direct3D.
