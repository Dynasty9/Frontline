# Client overview and soldier presentation

## 5 November: separate preparation frames

The stationary overlay already prepared three drawing layers on separate frames.
The pending roster and squad-summary paths could nevertheless force work onto
those same frames. The HUD now finishes an overlay refresh, then reserves frames
for pending summaries and roster drawing before starting another routine refresh.
Camera, projection, input, resize and visibility changes still invalidate immediately.
Queued roster work gets priority on the next free frame; a 200 ms guard prevents
routine summaries from starving the overlay on very slow machines.

Command view coalesces duplicate squad shouts and displays up to 32 visible phrases,
prioritizing selected units, radio orders and casualty calls. Close-view speech,
audio, authoritative simulation and replay identity are unchanged.

### Matched rendered comparison

Windows, Godot 4.7.2 release exports, Forward+, High, 1280x720, uncapped; a flat
1024 m stress map, 500 initial soldiers, combat, seed 3, observer, focus 0,0,
35 m zoom. Each run warmed up for 30 seconds after loading and measured 30 seconds.
Other applications remained running, and no local builds/tests ran during captures.
Order: control, HUD, HUD + snapshots, HUD + snapshots, HUD, control.

| Build | Average FPS, runs 1 / 2 | Frame p99, ms | Adjacent-frame difference p99, ms |
| --- | --- | --- | --- |
| #112 ecd6a29 | 63.60 / 64.86 | 31.356 / 34.336 | 12.490 / 13.702 |
| Overview d01fd0d | 76.31 / 74.17 | 25.112 / 24.697 | 9.403 / 10.803 |
| Overview + snapshot retention | 71.70 / 75.89 | 27.555 / 25.475 | 12.582 / 10.162 |

The overview comparison averages 17.1% more FPS, 24.2% lower frame p99 and
22.9% lower adjacent-frame-difference p99. Both repeated overview runs improve
on both controls. This does **not** meet a 16.67 ms frame-time target.

Snapshot retention reduces mean soldier presentation from 1.588/1.633 ms to
1.579/1.496 ms, but this observer comparison does not establish an additional
whole-frame improvement. Do not attribute the full stack's gain to snapshot
retention or Rust simulation changes.

These captures precede the small follow-up for low-FPS scheduling fairness and
hidden-soldier retention. Those paths have explicit regression coverage; final
captures are reported separately. These are stationary observer stress samples,
not a guarantee for every map, camera movement, machine or background workload.

Raw logs, aligned traces and screenshots: `build/stack-{control,hud,combined}-{1,2}/`
in the render-overlay-budget worktree. Compact results: [client-overview.json](client-overview.json).
Reproduce each export with:

```powershell
python tools/benchmark_scaling.py --godot <export>/Frontline.exe --exported --rendered --local-server --map-size 1024 --units 500 --team -1 --mode combat --seed 3 --warmup 30 --duration 30 --zoom 35 --preset high --width 1280 --height 720 --timeout 600 --output <fresh-directory>
```

Set `FL_DEBUG_FRAME_TRACE=1` for aligned component timing. Run builds sequentially;
use the same native DLL/server binaries and do not compare headless FPS to rendering.

### Validation and rejected prototypes

Five focused overview/speech tests pass. The actual HUD coordinator test checks
non-overlapping routine workloads, progress, low-FPS fairness, and immediate
camera/projection/input/resize/hide-show invalidation. The staged pixels are checked
on Vulkan and Compatibility. Four soldier tests cover packet invalidation,
selection, hidden and newly visible units, observer changes, detail promotion,
shared poses, teleports and native interpolation.

Retained speech canvas nodes reduced speech callback time but did not improve
whole-frame measurements, so that prototype was discarded. Speech limiting alone
also did not establish a speedup; its role is bounding crowded command displays.
The last four articulated models remain: a prior zero-detail experiment did not
justify removing them. No rendering preset or simulation frequency was lowered.
