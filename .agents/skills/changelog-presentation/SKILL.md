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

Keep repository media small by default:
- Prefer one combined before/after sheet for appearance changes, or one short
  compressed video plus its poster for motion. For changes spanning many vehicles
  or objects, combine representative examples rather than committing an image
  for every object. Add another sheet only when it proves something distinct.
- Capture and inspect as broadly as needed, but keep raw frames, individual
  captures, full-roster sheets, alternate encodes and debugging renders in a
  temporary directory outside the repository. Review coverage does not require
  checking in every capture. Do not upload the raw set elsewhere unless requested.
- Commit only the final compact presentation. Reuse those files from review docs
  and the changelog instead of keeping duplicate copies in both directories.
  Prefer JPEG/WebP for stills and WebM/MP4 for motion; avoid large PNG sequences
  and GIFs when a video communicates the same evidence more efficiently.
- Inspect encoded dimensions and total bytes before committing. Aim for under
  1 MB of stills per change and only a few MB for a short video, while keeping the
  evidence legible. These are targets, not approval gates: reduce resolution,
  duration or redundant examples first, and explain any necessary larger output.
- Keep source revisions, capture commands and settings in the inventory so the
  evidence can be reproduced without storing raw captures in Git. Register the
  final committed media in the catalog; local-only captures need not be listed
  as repository assets. Preserve existing released evidence unless asked to
  change it.

Use reusable stages in `tools/showcase/`: source media for release evidence,
controlled motion stages for side-by-side physics, and the game's scenario/UI
capture flags for actual gameplay and interactions. Consult `tools/showcase/README.md`
and `changelog/README.md` from the repository root. Prefer extending a stage's
configuration over making another one-off scene.

Before designing presentation, inspect the main site and its shared components.
Use its shadcn/Radix primitives, theme tokens, condensed display headings, brass
accent and thin rules. On the website, show source media directly with HTML
headings and captions. Do not nest a branded poster or screenshot of a card inside
another card, repeat the title inside the image, or introduce a separate palette.
Keep source screenshots uncropped and legible within compact comparison sheets.
Simple side-by-side or grid comparisons with short labels are encouraged; avoid
decorative archive plates or nested UI chrome.

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
`tools/showcase/entries/<entry-slug>.json` (one record per file, not an array).
Do not append new records to the legacy `tools/showcase/catalog.json`: concurrent
PRs conflict there. See `tools/showcase/entries/README.md` for the format. The presentation audit catches missing assets and
unreviewed entries. Existing release content is regenerated only when requested;
ordinary game changes add an unreleased entry, without rewriting release metadata.

Before publishing, view representative beginning/action/result frames and the
encoded output, verify duration, audio policy and decode, run changelog validation
and presentation audit, and exercise the website's disclosure/media controls.
Make the final combined sheet or encoded clip available in the detail view; this
does not require publishing individual source captures. Choose the clearest
artifact for the overview, not an indiscriminate gallery. Give changed UI a small-window and
reduced-motion pass. Never make autoplay the only way to understand an entry.

When reviewing changes to the changelog itself, distinguish layout comparisons
from gameplay evidence. Use `[layout_comparison]` for entry-specific old/new layout
captures, under a separate collapsed disclosure. Render actual components at a
matched viewport, record revisions and label cropped viewport captures. If an
entry is new, label its old-layout render as a reconstruction using current content.
