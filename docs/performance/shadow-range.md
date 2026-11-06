# Camera-fitted directional shadows

The directional light retains its preset, four cascades, filtering and softness.
For a downward command view, its maximum range now ends beyond the furthest
visible ground receiver. Four viewport corner rays meet a plane at -8 m, below
built-in geology, water and deformation. The range includes a 16 m margin and
the existing fade interval, rounds up to 32 m, and never exceeds the preset.
Coverage expands immediately; shrinking needs 64 m of headroom. Horizon views,
below-floor cameras and terrain reflection captures retain the preset range.

This prunes distant shadow work while preserving offscreen casters that project
onto visible ground. It does not cull casters by camera visibility or change
simulation, fog, models, selection or map dimensions. Godot documents the range
and fade behavior in [DirectionalLight3D](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html).

## Measurements

Windows, i9-11900K, RTX 3090, Godot 4.7.2 Forward+, 1280 x 720, High preset,
uncapped, 3 km city with 500 starting soldiers. Other applications remain running.
The renderer includes #140; the unchanged #112 server is used for both ranges.

Two sessions alternate the original 800 m range and fitted 352 m range in the
same running battle: 24 three-second blocks after 30 seconds of warmup. The first
12 frames after each switch are discarded. Order is ABBA in the first session,
BAAB in the second. No local builds or tests overlap capture. Results below are
means of equally weighted valid blocks, not a mean weighted by frame count.

| Session | Renderer CPU before / fitted, ms | GPU before / fitted, ms | Primitives before / fitted |
| --- | ---: | ---: | ---: |
| ABBA | 7.293 / 6.158 | 6.635 / 6.394 | 6.535 M / 5.396 M |
| BAAB | 6.033 / 5.502 | 6.390 / 6.099 | 6.393 M / 5.284 M |

Renderer CPU cost falls 8.8–15.6%, GPU cost 3.6–4.6%, and drawn primitives about
17%. One complete ABBA quartet is excluded because its control range did not
remain at 800 m. The adjacent JSON records every block, exclusions and p99 frame
times. Original raw samples and drivers remain under `build/shadow-alternating*`
in the camera-shadow-range worktree.

Whole-frame means were 28.615 / 25.594 ms and 23.218 / 22.315 ms, respectively.
Background load varied sharply, including another independently running game
rendering task. These captures support reduced render work, not a sustained-60-FPS
claim. Earlier separate-process controls varied from 42.84 to 51.98 FPS, while two
fitted runs missed simulation ticks; those runs are not used for an FPS speedup.
Two combined captures with #139's server reached 46.85 and 52.46 FPS, still below
the steady 60 FPS target.

## Coverage

The headless fixture checks 144 camera configurations with a 9 x 9 receiver grid:
aspect ratios, FOV, altitude, pitch and roll, plus loading, horizon fallback,
reflection captures and stable panning. Five rendered views on each desktop
renderer compare shadow interiors against the original range, including a tall
caster beyond the view footprint and a low sun. Every case retains its shadows
(zero missing dark interior samples). The fitted cascades can resolve sharper
edges; pixel identity is not expected. Tests and the Windows export pass.

Representative comparisons are attached to the changelog entry: original on
the left, fitted on the right. These are controlled fixtures, not battle footage.
Moving-camera play on low-end GPUs and browser WebGL have not been benchmarked.
