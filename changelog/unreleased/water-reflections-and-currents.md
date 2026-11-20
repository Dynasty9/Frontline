+++
title = "Water that mirrors the battlefield, and rivers that flow"
summary = "Rivers, ponds and the sea now reflect the banks, trees, bridges and boats around them, and rivers visibly run downstream round their bends."
kind = "improved"

[[videos]]
file = "shore-pan-comparison.webm"
poster = "shore-pan-poster.jpg"
caption = "Matched shoreline pan before and after the hit-validation fix. Compatibility, High water, reduced shadows and AA off; software capture, not a GPU benchmark."

[[videos]]
file = "river-pan-compatibility.webm"
poster = "river-pan-poster.jpg"
caption = "Current build, higher river camera. Compatibility with the same reduced shadow and AA settings; channel depth is visible, but flow lanes are faint at this height."

[[screenshots]]
file = "river-after.jpg"
caption = "A river now: the current's lanes run down the stream, the channel goes dark and the bridge shows in the water"

[[screenshots]]
file = "river-before.jpg"
caption = "The same river before"

[[screenshots]]
file = "beach-after.jpg"
caption = "Landing craft on the beach mirrored in the sea, and the far sea reflecting the sky evenly"

[[screenshots]]
file = "beach-before.jpg"
caption = "The same beach before"
+++

- **Reflections:** on High and Ultra water quality, whatever stands above the water shows in it: the banks and
  trees along a river, a bridge over it, landing craft on the beach, most of all when you look low across it.
  Where there's nothing to mirror, the sky shows as before.
- **Rivers flow:** the ripples run down the river and follow its bends, quick in mid-stream and slack under the
  banks, with long lanes of glassy water and strings of bubbles drifting down the current. Ponds lie still
  instead of drifting one way.
- **The sea:** the sun shines green through the thin tops of the waves when it's behind them, the wind's chop
  runs downwind, and the far sea mirrors the sky evenly instead of breaking into dark blotches.
- Medium keeps the flowing rivers and their lanes without the reflections; on Low the ripples still follow
  the current.

Reflections now require a front-to-back depth crossing and fade out when the refined hit is too far behind the visible surface. This guards against foreground silhouettes being accepted as reflected surfaces while the camera moves. Off-screen rays continue to use the sky fallback.

The stills show the original reflection pass, before this hit-validation follow-up. The matched clip compares 92e3102 with 1778b864 in the real naval scenario (seed 3): a low camera pans across the shore as boats move and the dock leaves the screen. The visible difference is subtle in this scene. Compatibility rendering completed without resource or shader errors; this does not establish Forward+ quality, horizon stability, or GPU cost. An uncontended same-scene hardware GPU comparison remains pending.

The higher-camera river clip shows the current build only. The channel stays darker than the banks, but the flow lanes are faint at this viewing height; stronger claims about normal-play readability need further review.
