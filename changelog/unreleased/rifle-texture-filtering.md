+++
title = "Cleaner rifle textures"
summary = "Imported rifle textures now use mipmaps and anisotropic filtering."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Unfiltered high-resolution rifle maps produced a noisy surface."

[[screenshots]]
file = "after.jpg"
caption = "The same pose and lighting with mipmaps and anisotropic filtering."
+++

Local MCO asset preparation now enables mipmaps for its 3D textures, including the rifle's colour, normal and ambient-occlusion maps. Materials assigned at runtime did not trigger the editor's automatic 3D texture setup. The rifle also uses the player's anisotropic-filtering setting for angled surfaces. Repeating preparation preserves existing import identities and other settings.
