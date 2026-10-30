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
- The extracted simulation uses pinned numeric rules, with exact checkpoint comparisons across platforms as replay verification work continues.
- Guided missiles keep a consistent turn after overshooting their aim point, instead of letting rounding choose an erratic turn direction.
- This is groundwork for the server migration. Battles still use the existing simulation, and recordings are not yet independently verified.
