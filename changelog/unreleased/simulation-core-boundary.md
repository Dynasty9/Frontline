+++
title = "Move solo battle simulation into a separate Rust server"
summary = "Solo battles run separately from rendering, with authenticated commands, reconnect support and deterministic command recordings. Command recordings play, seek and verify in the replay viewer; multiplayer and browser integration remain in progress."
kind = "improved"

[[screenshots]]
file = "verified-replay.jpg"
caption = "The replay viewer independently reruns a short recorded battle and verifies its final state. This battle ended before either side won."
+++

- Solo battles now run in a separate Rust process while Godot draws the battlefield and handles your orders. Infantry, vehicles, combat, logistics, tactical AI, commanders and the five operations use the same authoritative simulation.
- Pausing freezes battle time. Reconnecting returns you to the same battle and troops. Closing a session finishes its command recording so the independent verifier can reproduce its final state and outcome.
- The server sends each side only the enemy state it is allowed to see. Orders, sounds, combat effects, radio messages and battle reports travel through the socket connection.
- Transport capacity includes squads carried by vehicles without separate seat definitions. Helicopter boarding uses height above the local ground, and Beachhead reinforcements start aboard their transport.
- Troops can complete long routes across navigation regions. Diving uses current ground height, and starting a different-sized map rebuilds its ground correctly.
- Cosmetic debris no longer advances gameplay randomness. New command recordings preserve the full starting battlefield and player inputs; existing observer archives remain unverified recordings.
- Command recordings open in Replays, with pause, speed and timeline controls. Rewinding reruns the recorded commands; verification checks the final state and distinguishes unfinished battles from concluded games.
- Generated-map scenery restores pavements, fences and overhead wires correctly through the socket connection.
- Soldier updates reuse prepared weapon definitions, supply totals use the existing unit/building indexes, and teammates share observation preparation. Stationary minimap camera wedges reuse their ground intersections while retaining immediate camera feedback.
- Wildlife waits for the battlefield to finish loading before reading terrain being prepared on a worker thread.
- Large-map starting states and command recordings use lossless compressed blocks, retaining exact state for independent verification.
- Distant soldier batches expand their bounds for elevated and airborne troops, preventing models from disappearing above the old flat-ground bounds.
- Multiplayer lobby and browser integration are still being completed. Large-map rendering performance is still under measurement; this change does not yet establish 60 FPS with 500 units.
