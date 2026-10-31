+++
title = "Move terrain, targeting, navigation and flight into Rust"
summary = "Terrain cover, infantry target acquisition, navigation and aircraft behavior now use the shared Rust core as the standalone server migration continues."
kind = "fixed"
+++

- Cosmetic debris no longer consumes gameplay randomness when cosmetic physics is unavailable.
- Grenade, smoke, rocket, bomb and shell flight now use the shared simulation core, preserving flight behavior, pickup, kicking and rethrowing.
- Battlefield raycasts now use the shared simulation core, updating when vehicles move, doors open and structures change.
- Sight checks and smoke screens now run in Rust, retaining immediate smoke changes and reusing obstruction only while the blocking geometry stays unchanged.
- Infantry contact evaluation now shares a Rust scan, preserving weapon priorities, mounted-gun arcs, drone reactions, forced targets and squad reports.
- Fighting positions and their protection checks now use Rust, retaining low cover, leaning fire and second-row shelter while avoiding redundant firing-lane checks.
- Ground edits, crater deformation and cover repairs now use Rust, preserving road speed, directional cover, camouflage and shell holes.
- Water terrain and bridge decks now use Rust. Joining a battle prepares its ground on a Rust worker while preserving fords, quays and the host's ground changes.
- Local navigation grids and boat routes now use Rust, preserving weighted paths and corner-blocking rules.
- Hierarchical routes, danger weighting and map repairs now run in Rust. Large-cluster route caches distinguish entrances that previously shared a truncated key.
- Route refinement, smoothing, shared corridors and queued movement orders also run in Rust, retaining fire avoidance and order completion quotas.
- FPV drones, guided missiles and support-aircraft attack schedules now use Rust, preserving target loss, smoke countermeasures, bomb runs, gun bursts and reconnaissance.
- Infantry movement has a Rust compatibility test covering doors, vaults and cover slides. The faster existing movement remains active while actor state is migrated.
- Rust weapon compatibility checks preserve cover fire, firing postures, ammunition and burst timing, including squadmates covering a reload. These checks run alongside the existing controller as soldier state is migrated.
- Health, suppression and fatigue also have Rust compatibility checks, covering wounded soldiers, repeated revivals, prisoners, damage credit and squad reactions.
- Infantry aim compatibility checks cover smoke, blocked sight, blind fire, firing through cover and last-known positions.
- Combat pose compatibility checks preserve eye heights, exposed body points, mounted-gun positions and hit factors in Rust, independently of the visual models.
- Bullet compatibility checks preserve accuracy, penetration, damage order, explosive rounds and near-miss suppression in the Rust core.
- Blast compatibility checks preserve cover and trench protection, prone shelter, knockback and flinching in the Rust core.
- Knockback and recovery checks preserve obstacle bounces, landings, flinching and dazed movement, including carried casualties and task interruption.
- Wounded-soldier checks preserve bleeding, medicine, rescue, pistol timing and corpse collection. A wounded soldier also safely releases a rescuer that has been removed.
- Grenade reflex checks preserve protecting wounded squadmates, throwing grenades back, kicking them away, ducking behind cover and cooking a throw.
- Grenade task checks preserve approaching, picking up and kicking a grenade, smothering it and diving clear, including blocked ground and fuse deadlines.
- House-entry checks preserve stacking, kicking closed doors, cooking and throwing into the room, taking cover for the explosion and entering with a buddy.
- Building checks preserve which house a contact occupies, usable doorways and windows, blocked stacking positions and the squadmate best placed to breach.
- Automatic grenade checks preserve target groups, hard-cover priorities, throw scatter, ammunition, cooldowns and cooking before a throw.
- Rust grenade warnings preserve the shared incoming-shell history after a prolonged bombardment, then discard it when a new grenade is noticed nearby.
- Incoming-round checks preserve warning order, suppression, ducking and dive priority, including soldiers busy rescuing or carrying casualties.
- Drone-avoidance checks preserve which aircraft soldiers hear, their warnings and the chance to dive from a close attack.
- Special-weapon checks preserve rocket and melee targets, mortar fire orders, drone launch timing, ammunition and cooldowns in Rust.
- Supply checks preserve scavenging, nearby bodies, ammo-cache and FOB destinations, refill rates and reload order.
- Complete cover searches now run in Rust, preserving preferred positions, squad spacing, burning ground and the existing search limit.
- Stationary-movement checks preserve giving nearby troops room, settling onto terrain, moving into a cover position and watching a sector.
- Medical-task checks preserve rescue, dragging, treatment timing and escorts. Soldiers also safely abandon these tasks when a patient or rescuer has been removed.
- Construction, stretcher and prisoner-escort checks preserve work priorities, paired carrying and solo takeover. These tasks also safely handle removed casualties, partners, tents, prisoners and work targets.
- Authoritative entity IDs now come from Rust, preserving creation order and keeping removed units' IDs from being reused as the server migration continues.
- The extracted simulation uses pinned numeric rules, with exact checkpoint comparisons across platforms as replay verification work continues.
- Guided missiles keep a consistent turn after overshooting their aim point, instead of letting rounding choose an erratic turn direction.
- This is groundwork for the server migration. Battles still use the existing simulation, and recordings are not yet independently verified.
