+++
title = "Bundled infantry character and animations"
summary = "The optional SWAT character and its animations now travel with Frontline instead of requiring local asset downloads."
kind = "improved"
[[screenshots]]
file = "runtime.jpg"
caption = "SWAT and rifle rendered from the runtime bundle in a checkout with no source assets."
+++

The SWAT character, 251 animation scenes, textures and rifle are bundled as compiled runtime resources. The game and character playground load the same package. Duplicate meshes have been removed from animation clips, and character textures are limited to 2K to keep the download manageable.

