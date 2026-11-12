# Frontline infantry runtime assets

`infantry.zip` is a Godot runtime resource pack, mounted by `InfantryAssets` at startup. It contains the Mixamo SWAT character, 262 animation scenes, compiled textures capped at 2048 pixels, and the baked M4 rifle. Animation scenes contain skeletons and animation tracks, without duplicate character meshes. No raw FBX files or legacy MoCap animations are included.

These assets are **not covered by the repository's MIT license**. Adobe/Mixamo owns the character and animation content; Motus Digital/MoCap Online owns the rifle content. The bundle is supplied as part of Frontline, not as a standalone asset library. Do not extract, redistribute, or sell its contents as assets. Packaging is not encryption or DRM, and does not grant additional rights.

Provider terms:
- https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- https://mocaponline.com/pages/standard-license

To rebuild with the locally licensed inputs already imported:

```powershell
godot --headless --path . --script tests/mocap/bake_rifle.gd
godot --path . res://tests/mocap/bake_rhib_helm.tscn
godot --headless --path . --script tests/mocap/pack_infantry.gd
```

The original downloads remain ignored under `assets/local_mocap`. All export presets include the runtime bundle and exclude that source directory. Existing resource paths are retained inside the pack so the game and animation viewer use the same assets. Ordinary battles use the bundled SWAT character for detailed Coalition riflemen by default. The existing `--skinned-units --swat-units` launch still selects it.
