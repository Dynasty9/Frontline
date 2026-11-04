+++
title = "Move battle simulation into a separate Rust server"
summary = "Desktop battles run in a separate Rust server and browser solo battles use a Rust worker, with authenticated commands, reconnect support and deterministic command recordings that play, seek and verify in the replay viewer."
kind = "improved"

[[screenshots]]
file = "verified-replay.jpg"
caption = "The replay viewer independently reruns a short recorded battle and verifies its final state. This battle ended before either side won."

[[screenshots]]
file = "close-detail-before.png"
caption = "Before: detailed soldier models make this close view of a 500-unit battle expensive to draw."

[[screenshots]]
file = "close-detail-after.png"
caption = "After: selected and nearby troops receive the articulated-model budget; all other troops remain visible through shared models. The same replay averaged 65.7 FPS versus 30.0 FPS before, though frame spikes remain."

[[screenshots]]
file = "shared-lod-before.png"
caption = "Before: shared soldier models use the default distance for reducing mesh detail."

[[screenshots]]
file = "shared-lod-after.png"
caption = "After: shared soldiers reduce geometry earlier while nearby articulated models keep their detail. This close-view sample reduced GPU p99 from 5.63 to 5.05 ms; overall frame spikes still exceed the 60 FPS budget."

[[screenshots]]
file = "leader-marks-before.png"
caption = "Before: squad leader chevrons are rebuilt from lines whenever the battlefield overlay refreshes."

[[screenshots]]
file = "leader-marks-after.png"
caption = "After: the same leader cues use the shared symbol atlas. Repeated close-view runs reduced frame p99 from 23.1–25.0 ms to 21.1–22.7 ms; the 60 FPS frame-time target remains open."

[[screenshots]]
file = "player-hud-before.png"
caption = "Before: the player HUD repeatedly rebuilds unchanged support labels and squad orders, while last-seen minimap markers are drawn from lines."

[[screenshots]]
file = "player-hud-after.png"
caption = "After: unchanged HUD state is retained and minimap intel uses the shared atlas. Repeated 500-unit player-view runs averaged 60.1–60.6 FPS versus 52.2–53.2 before; frame spikes still exceed the 60 FPS budget."

[[screenshots]]
file = "world-contact-markers.png"
caption = "Last-seen battlefield contacts, before on the left and after on the right. Shared diamond drawings retain the normal question-mark font, fading and larger vehicle markers."
[[screenshots]]
file = "collapse-pool.png"
caption = "Before (left) and prepared emitters (right): collapse sparks and ash retain their appearance while reusing particle systems. Individual particle positions differ."

+++

- Desktop battles now run in a separate Rust process while Godot draws the battlefield and handles your orders. Infantry, vehicles, combat, logistics, tactical AI, commanders and the five operations use the same authoritative simulation.
- Multiplayer keeps its existing lobby connection. Friends can join running battles, receive their starter troops at the original FOB, and reclaim surviving forces after reconnecting. Teammate cursors, pings, sketches and action notifications pass through the Rust server with team privacy intact.
- Remote clients process relayed updates within the same per-frame budget as direct connections, avoiding a burst of network messages decoding all at once. Queues are bounded, and acknowledgements follow processed state.
- Pausing freezes battle time. Reconnecting returns you to the same battle and troops. Closing a session finishes its command recording so the independent verifier can reproduce its final state and outcome.
- The server sends each side only the enemy state it is allowed to see. Orders, sounds, combat effects, radio messages and battle reports travel through the socket connection.
- Transport capacity includes squads carried by vehicles without separate seat definitions. Helicopter boarding uses height above the local ground, and Beachhead reinforcements start aboard their transport.
- Sky Hook's convoy starts on ground from which its vehicles can reach the outpost, fixing a mission stall caused by reinforcements stranded on mountain slopes.
- Troops can complete long routes across navigation regions. Diving uses current ground height, and starting a different-sized map rebuilds its ground correctly.
- Unreachable movement orders use cached map connectivity instead of repeatedly searching the whole navigation graph. Opening or closing a crossing refreshes that connectivity.
- Armies of at least 256 combatants share a deterministic route-search budget, carrying excess requests into following ticks to reduce simulation spikes. Smaller battles keep their existing schedule.
- Repeated local navigation costs reuse bounded caches, clearing them when obstacles or terrain weights change; route choices stay the same.
- Reachable route searches use a tighter distance estimate to examine fewer junctions while preserving shortest route cost. Equally priced routes can differ, so command recordings require the matching simulation version.
- Cosmetic debris no longer advances gameplay randomness. New command recordings preserve the full starting battlefield and player inputs; existing observer archives remain unverified recordings.
- Command recordings open in Replays, with pause, speed and timeline controls. Rewinding reruns the recorded commands; verification checks the final state and distinguishes unfinished battles from concluded games.
- Generated-map scenery restores pavements, fences and overhead wires correctly through the socket connection.
- Scenery batching spreads collection and mesh uploads across frames, keeping the original models visible until each block is ready.
- Reconnecting and seeking a replay restore the current craters, roads and active grass fires. Ground updates arrive independently of explosion effects and apply progressively.
- Artillery recoil and visible surrendering soldiers' dropped rifles reach the Godot client through simulation events.
- Prewarmed fire, smoke-screen and missile-trail particle materials remain cached for the match, avoiding shader recompilation when their first visible effect appears.
- Dirt-clod rendering warms up during loading, avoiding another shader-creation pause after the first explosion.
- Loading a socket battlefield imports its finished terrain instead of rebuilding the same elevated surface in GDScript.
- Soldier updates reuse prepared weapon definitions, supply totals use the existing unit/building indexes, and teammates share observation preparation. Stationary minimap camera wedges reuse their ground intersections while retaining immediate camera feedback.
- Unchanged scenery reuses its prepared network state, while damage, construction, supply and visibility changes still reach clients immediately at the next observation update.
- Long order lines skip offscreen dash projections without moving the visible dashes. Routine roster refreshes move to the next frame when the battlefield overlay is also updating.
- Attack-plan markers discard old drawing records each refresh, preventing their cache from growing throughout a long battle.
- Squad leader chevrons reuse the symbol atlas, reducing overlay drawing spikes while retaining the same leaders and troops.
- Speech bubbles reuse wrapped text and draw their flat backgrounds directly, reducing repeated overlay work while retaining the messages, colors and placement.
- The fire-support panel changes label themes only when their state changes, and squad-order labels update when a new server summary arrives. Cooldowns and command input remain responsive.
- Last-seen enemy markers reuse the minimap symbol atlas, retaining their fading and the larger vehicle diamonds while reducing drawing spikes.
- Last-seen battlefield diamonds also reuse the symbol atlas. The minimap retains its camera and compass drawing while unchanged, with immediate updates when the view or pointer moves.
- Hidden articulated soldier models stop updating their joints as shared models move, reducing CPU work without removing troops or nearby detail. Revealing a soldier or starting a ragdoll restores its current position immediately.
- Burned-out buildings reuse prepared spark and ash emitters, avoiding repeated particle-system construction during combat. Up to eight collapses keep their effects at once; further collapses replace the oldest fading effect. Building damage and scorch marks are unchanged.
- Closing an already disconnected simulation session avoids a redundant disconnect call and its engine error.
- Wildlife waits for the battlefield to finish loading before reading terrain being prepared on a worker thread.
- Large-map starting states and command recordings use lossless compressed blocks, retaining exact state for independent verification.
- Distant soldier batches expand their bounds for elevated and airborne troops, preventing models from disappearing above the old flat-ground bounds.
- Distant soldiers smooth their movement on the GPU between socket updates, reducing repeated CPU transform uploads while preserving immediate visibility and teleport changes.
- Client movement smoothing reuses each unit's current transform, reducing repeated engine reads while keeping movement and teleport behavior unchanged.
- Command views limit fully articulated models to four selected or nearby soldiers; zooming below 22 m retains up to 16 for close inspection. Other troops use shared standing, crouching, prone and walking models, preserving the full army and gameplay while reducing drawing cost.
- Shared soldier models reduce mesh detail earlier as they recede, cutting geometry without removing troops.
- New detailed models build one at a time. Squad-overview preparation yields at most one frame to a HUD redraw, keeping selection immediate.
- Stationary battlefield overlays prepare drawing across three frames and display the completed image together. Camera movement, zoom and commands still refresh immediately, reducing routine frame-time variation.
- Soldier-batch uploads also avoid squad-summary and roster work, yielding at most two frames while GPU motion continues. This reduces overlapping client work without changing simulation timing.
- Detailed soldiers reuse prepared geometry with independent animation, reducing construction pauses when troops enter the camera view. Clothing and face variation is reduced within each unit type and team.
- Closing the game during music or sound preparation waits for the audio workers to finish safely.
- Wildlife looks for nearby threats through spatial cells; soaring birds check aircraft directly instead of scanning every soldier.
- Cosmetic ground colliders sample hills, craters and trenches in one Rust call per tile, reducing collision-update spikes.
- Squad summaries calculate each group once, reducing repeated HUD work while keeping selection immediate.
- Squad strength indicators reuse their geometry until the number or condition of their soldiers changes, reducing HUD drawing calls.
- Unchanged roster rows retain their drawing commands, refreshing when selection, casualties, status or appearance changes. Fractional scrolling and interface scaling keep the same text and symbols.
- Minimap firefight markers reuse position reads, map transforms and ring styling within each refresh.
- Terrain fog of war calculates its cached visibility mask in Rust and draws one texture, reducing visibility-update spikes while preserving the same terrain horizon and refresh rate.
- Minimap soldier dots share one draw batch and reuse map transforms and team colors, retaining selection, wounded colors, overlap and immediate camera feedback.
- Supply dispatch checks active buildings instead of every scenery object. Infantry refresh activity descriptions only when their existing status timer expires.
- Victory checks use the active-building index rather than scanning every tree and wall.
- Infantry, vehicles and commanders reuse the list of owned buildings, updating it when a building is created, captured or removed instead of scanning all scenery every tick.
- Browser solo games run the same Rust simulation in a separate worker. Leaving through the menu saves a command recording that can be reopened and verified in Replays.
- Public battle broadcasts read the Rust server's observer stream without running another battlefield. Seeking restores roads and terrain changes; older observer recordings still open. These viewing archives remain separate from verified command replays.
- Exported games include the immutable game data required to start their simulation.
- Windows native components include their C runtime, so starting a battle does not require a separate Visual C++ redistributable installation.
- Large-map rendering performance is still under measurement; this change does not yet establish steady 60 FPS with 500 units.
