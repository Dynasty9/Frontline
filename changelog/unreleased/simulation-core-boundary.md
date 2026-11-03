+++
title = "Move battle simulation into a separate Rust server"
summary = "Desktop solo and multiplayer battles run separately from rendering, with authenticated commands, reconnect support and deterministic command recordings. Command recordings play, seek and verify in the replay viewer; browser integration remains in progress."
kind = "improved"

[[screenshots]]
file = "verified-replay.jpg"
caption = "The replay viewer independently reruns a short recorded battle and verifies its final state. This battle ended before either side won."
+++

- Desktop battles now run in a separate Rust process while Godot draws the battlefield and handles your orders. Infantry, vehicles, combat, logistics, tactical AI, commanders and the five operations use the same authoritative simulation.
- Multiplayer keeps its existing lobby connection. Friends can join running battles, receive their starter troops at the original FOB, and reclaim surviving forces after reconnecting. Teammate cursors, pings, sketches and action notifications pass through the Rust server with team privacy intact.
- Pausing freezes battle time. Reconnecting returns you to the same battle and troops. Closing a session finishes its command recording so the independent verifier can reproduce its final state and outcome.
- The server sends each side only the enemy state it is allowed to see. Orders, sounds, combat effects, radio messages and battle reports travel through the socket connection.
- Transport capacity includes squads carried by vehicles without separate seat definitions. Helicopter boarding uses height above the local ground, and Beachhead reinforcements start aboard their transport.
- Sky Hook's convoy starts on ground from which its vehicles can reach the outpost, fixing a mission stall caused by reinforcements stranded on mountain slopes.
- Troops can complete long routes across navigation regions. Diving uses current ground height, and starting a different-sized map rebuilds its ground correctly.
- Unreachable movement orders use cached map connectivity instead of repeatedly searching the whole navigation graph. Opening or closing a crossing refreshes that connectivity.
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
- Wildlife waits for the battlefield to finish loading before reading terrain being prepared on a worker thread.
- Large-map starting states and command recordings use lossless compressed blocks, retaining exact state for independent verification.
- Distant soldier batches expand their bounds for elevated and airborne troops, preventing models from disappearing above the old flat-ground bounds.
- Browser integration is still being completed. Large-map rendering performance is still under measurement; this change does not yet establish steady 60 FPS with 500 units.
