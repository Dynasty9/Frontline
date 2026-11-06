# Renderer timing without mid-update synchronization

`PerfProbe` and the command-line FPS benchmark used to query viewport CPU/GPU
timings independently during `_process`. Godot 4.7.2 implements these getters as
synchronous render-thread calls. In separate-thread mode, the benchmark's early
query waits for work which could otherwise overlap the game update.

Both readers now consume three cached floats. `PerfProbe` samples at
`RenderingServer.frame_pre_draw`, after Godot's normal main/render synchronization
and before the next draw is queued. There is no extra worker, lock or timer. The
getters remain synchronous; moving them avoids an additional mid-update barrier.
Headless runs retain zero renderer timings. Node destruction disconnects the
signal normally.

The cache is the latest completed renderer measurement, read on the following
update. It is not exact same-frame attribution for a particular hitch. Wall-clock
frame durations and their differences retain their existing measurement path.

Engine implementation checked against the installed 4.7.2-stable tag:
- [Timing getters and synchronous wrappers](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/rendering_server_default.h)
- [Main-loop synchronization before drawing](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp)
- [Draw signal order](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/rendering_server_default.cpp)

## Validation

The headless fixture checks that repeated game updates retain cached timings
without querying the renderer. Draw callbacks refresh timings on the main thread.
Rendered checks pass with Forward+ and Compatibility, in both safe and separate
render-thread modes. The existing end-to-end performance report regression,
script import and Windows release export pass.

## Measurement limits

The separate render thread is an experimental Godot option; this change does not
enable it by default. All captures leave other applications running. The exported
ABBA comparison uses a 3 km city, 500 starting soldiers, 1280 x 720, High, uncapped,
30 seconds of warmup and 30 seconds of capture, with #139's unchanged server and
#141's renderer. It measures both a benchmark correction and any ordinary-play
benefit, so the FPS difference must not be described as a gameplay speedup.

| Exported benchmark run | FPS | p99 frame, ms | Server ticks in 30 s |
| --- | ---: | ---: | ---: |
| Original 1 | 61.03 | 26.28 | 1800 |
| Cached 1 | 81.74 | 23.15 | 1768 |
| Cached 2 | 89.21 | 19.14 | 1799 |
| Original 2 | 48.22 | 35.20 | 1759 |

Cached 1 and Original 2 fell behind the simulation clock; Original 2 also had
much higher GPU timings. The table preserves those results, but they are not
valid controls for an isolated percentage gain. Raw summaries are adjacent in
`render-timing.json`.

## Ordinary play

A diagnostic release build alternates the original late-update sampler and the
new draw-boundary sampler within one battle, with `--perf-at` and frame tracing
disabled. It collects only wall-clock frame intervals in 24 three-second ABBA
blocks after 30 seconds of warmup, discarding the first 12 frames after a switch.
This temporary diagnostic is absent from the production export.

In separate-thread mode, equally weighted block means were 13.347 ms before and
12.642 ms after: 74.92 and 79.10 FPS, a 5.6% difference. Mean block p99 was 20.705
and 19.815 ms. This single interleaved session supports a much smaller ordinary
play benefit than the benchmark change. Background load remains uncontrolled.
It does not establish steady 60 FPS or quantify a safe-mode gameplay gain.

Separate-thread runs logged texture-update errors during loading and an engine
render-thread finalization error at shutdown. The mode is experimental and is
not enabled by this PR. The development-build attempt was excluded because
per-frame synchronization warnings polluted its timings; an attempted release
`--script` invocation was unsupported and produced no measurements. The final
diagnostic uses an embedded temporary node in a release export instead.

The same release diagnostic in the default safe mode measured 23.791 / 23.848 ms
(42.03 / 41.93 FPS) with mean block p99 35.604 / 36.137 ms. This is effectively
neutral, not evidence of a safe-mode speedup. That session logged no rendering
errors, but reported eight ObjectDB instances at shutdown. Separate-thread and
safe-mode sessions ran at different times and must not be used as a controlled
mode-to-mode speed comparison.
