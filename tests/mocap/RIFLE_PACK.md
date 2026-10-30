# Local rifle package

The M4 mesh and textures are licensed MoCap Online content. They are separate
from the character and animation provider. Neither the source files nor the
generated package belongs in the public Git repository.

After importing the local M4 source assets, bake them from the repository root:

```powershell
godot --headless --path . --script tests/mocap/bake_rifle.gd
```

This writes `assets/local_mocap/runtime/m4.scn`. It contains one compressed
binary scene with embedded mesh and texture resources. The bake asserts that
the scene has no external dependencies and can be loaded independently.
Godot includes the binary scene in its normal game package on export.
Export presets exclude the legacy MoCap FBX folder, including the original rifle.
The runtime loader no longer imports the source FBX or
loads its JPG textures. It preserves the geometry used by the magazine splitter.

This is packaging, not DRM or a change of license. Keep the package private as a
build input and distribute it only as part of the licensed game. Release license
and extraction requirements still need to be satisfied before publishing.

With `--swat-units`, the character source and crouch leg cycle come from Mixamo.
The old mannequin evaluation mode remains available for comparison. The M4 is
still MoCap Online content; changing animation providers does not change that.
