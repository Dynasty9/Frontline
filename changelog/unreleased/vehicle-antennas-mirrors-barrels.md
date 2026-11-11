+++
title = "Shared antennas, mirrors and hollow gun barrels"
summary = "Vehicle radio whips gain spring mounts, mirrors gain housings and reflective faces, and major tank and artillery guns gain open muzzles and segmented thermal sleeves."
kind = "improved"

[[screenshots]]
file = "details.jpg"
caption = "Combined before/after: hollow barrel, rear-view mirror and spring-mounted antenna."

[[screenshots]]
file = "vehicles.jpg"
caption = "Combined comparison of 19 representative vehicles; before is left and after is right within each pair."

[[screenshots]]
file = "components.jpg"
caption = "Shared construction: antenna, mirror face and back, and hollow barrel."

[[videos]]
file = "antenna-motion.webm"
poster = "antenna-motion.jpg"
caption = "Controlled motion comparison: rigid reference on the left, movement-responsive antenna on the right. Forward, lateral and reverse inputs are followed by settling."

+++

- The core, NATO, CSAT and independent vehicle builders share tapered radio whips with bolted bases, rubber boots and helical springs.
- Ten vehicle families share rear-view mirror construction, including trucks, MRAPs, Humvees and technicals. Mirror glass uses its own reflective finish.
- Nine tank and artillery families share open gun tubes. Family-specific extractors, muzzle sensors and animation pivots remain authored separately; the T-55 retains its unsleeved barrel.
- Small attachments are most visible close up. Fixed fittings reuse the existing material batches. Each moving whip uses one pivot and one material batch, driven by one spring per vehicle; no physics bodies or mirror camera are added.

- Nearby visible antennas trail travel and react to acceleration and braking, then settle when stopped. Distant/hidden antennas skip motion updates.
