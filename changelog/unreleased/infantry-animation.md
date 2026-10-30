+++
title = "Infantry animation and impact preview"
summary = "An optional skinned rifleman preview adds captured movement, grounded feet, rifle grips and physical hit reactions. Soldiers make room before going prone beside walls."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "The earlier procedural rifleman"

[[screenshots]]
file = "after.jpg"
caption = "The optional imported rifleman after stepping back to clear the wall"

[[screenshots]]
file = "movement.jpg"
caption = "The optional riflemen moving into cover in an actual battle"

[[screenshots]]
file = "digging-game.jpg"
caption = "A rifleman digs during a sandbag construction order"

[[screenshots]]
file = "smoking-game.jpg"
caption = "A quiet-sector smoking idle, with the rifle slung"

[[screenshots]]
file = "ragdoll.jpg"
caption = "A staged blast demonstrates physical falls and dropped weapons"
[[screenshots]]
file = "mixamo-crouch.png"
caption = "The SWAT rifleman settles into cover using the Mixamo crouch cycle and baked rifle"
+++

- Soldiers check the space needed to go prone, take a short backward step when possible, settle their feet, then lower themselves. If the rear path is blocked, they stay crouched.
- The optional rifleman preview shares captured movement, terrain foot contacts, rifle grips, reload magazine handling, directional hit reactions and constrained skeletal ragdolls.
- A playable controller and animation inspector support terrain, skeleton inspection and projectile impacts. Tank recoil and impact motion are included in the battle preview.
- Imported characters and animations require separately installed local assets; they are not included in downloads. Other units keep their procedural appearance. This remains a preview, with unfinished activity animations and vehicle interactions.
- With local activity clips installed, riflemen use captured digging and smoking poses, keep their rifle slung, and drop the shovel physically when killed while digging.
- Recorded battles accept the new hit-reaction events, so combat recordings can load and seek correctly.

- The local rifle can be baked into a binary game resource with its textures embedded, preserving weapon grips and magazine handling without loading the original rifle FBX at runtime.
- The SWAT preview now uses a Mixamo source rig and crouch-walk cycle. Its animation viewer also discovers locally installed Rifle 8-Way Locomotion and Pro Rifle packs, plus the prone-to-kneel transition.
