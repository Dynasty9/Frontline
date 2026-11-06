+++
title = "Performance measurements interrupt rendering less"
summary = "The performance overlay and benchmark reuse renderer timings collected at the draw boundary."
kind = "fixed"
+++

The overlay and benchmark previously asked the renderer for timings during game
updates. With a separate render thread, those requests wait for queued rendering
work and can make the game being measured substantially slower. Timings are now
collected once at the normal draw boundary and reused by both readers.

This corrects a measurement cost; it does not establish the same FPS gain in
ordinary play. Frame durations still use the wall clock. Renderer timings describe
the latest completed measurement and may lag the frame being displayed. The
existing default render-thread mode is unchanged.
