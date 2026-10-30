---
name: changelog-presentation
description: Write and present Frontline changelog entries, select evidence appropriate to each change, and render reusable showcase stages for PRs and release history.
---

Start from the player's question: what will I notice, and why is it useful? Give
one short outcome in the summary, one clear piece of evidence, and optional
details. Preserve the useful specifics in the body; do not repeat the summary.

Choose the medium by what proves the change:
- Appearance/layout: a legible still or matched before/after composition.
- Movement, timing, interaction, effects: a short WebM with a poster and controls.
  GIF is a secondary GitHub preview, not a replacement for seekable video.
- Sound: a user-started recording with context/captions. Silent video cannot
  demonstrate audio. If no authentic recording exists, use honest concise text.
- Performance: a measured comparison with conditions and units, or an explanation
  if measurements are unavailable. Do not invent a graph or imply speed through
  edited playback.
- Reliability, compatibility and invisible fixes: text is often the best medium.
  Do not add decorative gameplay just to give every entry a picture.

Use reusable stages in `tools/showcase/`: archive plates for release evidence,
controlled motion stages for side-by-side physics, and the game's scenario/UI
capture flags for actual gameplay and interactions. Consult `tools/showcase/README.md`
and `changelog/README.md` from the repository root. Prefer extending a stage's
configuration over making another one-off scene.

A stage should establish context, cue the action, hold the result, then loop
without a jarring unexplained cut. Keep camera, seed, duration, controls and scale
matched for comparisons. Give the subject enough screen space; use brief phase
labels, tracks, distance marks or a focused crop only when they clarify the claim.
Check composition, contrast and text at the actual embedded size, not just fullscreen.

Use real output. Record source ref, scenario/seed, camera, timing and capture
command in the presentation inventory. Preserve historical versions and dates.
A current-build reenactment must say so; never call it historical before footage.
If a historical medium cannot be reproduced, use its archived still with an
explicit evidence limitation rather than synthesizing a purported demonstration.

For each entry, register the medium, stage, evidence and rationale in
`tools/showcase/catalog.json`. The presentation audit catches missing assets and
unreviewed entries. Existing release content is regenerated only when requested;
ordinary game changes add an unreleased entry, without rewriting release metadata.

Before publishing, view representative beginning/action/result frames and the
encoded output, verify duration, audio policy and decode, run changelog validation
and presentation audit, and exercise the website's disclosure/media controls.
Keep source media available in the detail view. Choose the clearest artifact for
the overview, not an indiscriminate gallery. Give changed UI a small-window and
reduced-motion pass. Never make autoplay the only way to understand an entry.
