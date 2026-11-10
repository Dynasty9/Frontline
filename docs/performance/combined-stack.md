# Combined performance stack validation

2026-11-05; i9-11900K / RTX 3090 / Godot 4.7.2. Other applications left running. No owned builds or tests overlapped captures.

Control renderer: PR #112 ecd6a29. Candidate: local integration 1b7232a, combining #134-#143. Both used the same integrated Rust server, initial 3072 m battlefield and 500 starting soldiers, team 0, High Forward+, safe render threading, 1280x720, focus 0,0, zoom 130, uncapped. 30 s warmup and 30 s capture. This isolates renderer versions; it does not measure the Rust route optimization against its old server.

| Run | Average FPS | p99 frame ms | p99 frame difference ms | Server ticks | Valid workload |
|---|---:|---:|---:|---:|---|
| stack-before-1 | 40.84 | 40.20 | 16.22 | 1800 | Yes |
| stack-after-1 | 36.54 | 45.73 | 17.32 | 1783 | No - missed ticks |
| stack-after-2 | 48.77 | 36.57 | 13.44 | 1801 | Yes |
| stack-before-2 | 30.96 | 58.58 | 20.59 | 1699 | No - missed ticks |

The valid control/candidate reached the same final server tick 3602. Their FPS was 40.84 and 48.77, but this is only one matched pair. The invalid runs show substantial background-load variation; no repeatable percentage FPS improvement is claimed. All four results are retained to avoid selecting only favorable measurements.

Rendering fell from about 7.2 million primitives to 5.45 million. Sustained 60 FPS is not demonstrated: even the faster valid candidate has a 36.57 ms p99 frame, above the 16.67 ms budget.

Integrated validation: native release build, import, 14 focused Godot tests, Windows release export, changelog check and presentation audit passed. Each individual follow-up PR passed its current-head CI and is ready for review.

Additional terrain experiment: 24 alternating 3 s blocks within one live battle, first 12 frames discarded. 0.5 m to 1 m fine grid reduced equal-block mean frame time 26.275 to 24.925 ms, GPU 7.698 to 7.313 ms, primitives 5.306M to 4.598M. Not published: modest gain, close-up crater/trench fidelity not validated. Production terrain unchanged.

Experimental separate renderer threading is not enabled: it has texture upload and shutdown errors in exported gameplay. Timing-boundary fix #143 avoids an unnecessary synchronization but is not a safe-mode FPS improvement by itself.
