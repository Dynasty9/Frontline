+++
title = "Less geometry for distant ground cover"
summary = "Distant bushes and stones use simpler meshes, while nearby ground cover retains its original shapes."
kind = "improved"
+++

Grass blades now share their repeated vertices. Bushes and stones share meshes
with automatic levels of detail, reducing geometry as they recede from the camera.
Placement, density, wind, shadows and blast damage stay the same.

A controlled distant-view test draws 246 triangles instead of 860. Close and
medium views match the original pixels on both desktop rendering paths. This
reduces rendering work; it does not establish sustained 60 FPS for large battles.
