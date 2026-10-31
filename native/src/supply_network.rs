use crate::actors::ActorStateCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::supply_network::SupplyNetwork;
use godot::prelude::*;

fn read_roads(input: &Array<Variant>) -> Option<[Vec<Vec<frontline_core::vector::Vector3>>; 3]> {
    if input.len() != 3 {
        return None;
    }
    let mut groups = std::array::from_fn(|_| vec![]);
    let mut total = 0;
    for (i, value) in input.iter_shared().enumerate() {
        let group = value.try_to::<Array<Variant>>().ok()?;
        if group.len() > 100_000 {
            return None;
        }
        for value in group.iter_shared() {
            let line = value.try_to::<PackedVector3Array>().ok()?;
            total += line.len();
            if total > 1_000_000 {
                return None;
            }
            groups[i].push(line.as_slice().iter().copied().map(crate::point).collect());
        }
    }
    Some(groups)
}
fn roads(input: &[Vec<Vec<frontline_core::vector::Vector3>>; 3]) -> Array<Variant> {
    input
        .iter()
        .map(|group| {
            group
                .iter()
                .map(|line| {
                    line.iter()
                        .map(|p| Vector3::new(p.x, p.y, p.z))
                        .collect::<PackedVector3Array>()
                        .to_variant()
                })
                .collect::<Array<Variant>>()
                .to_variant()
        })
        .collect()
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
pub(crate) struct SupplyNetworkCore {
    base: Base<RefCounted>,
    pub(crate) core: SupplyNetwork,
}
#[godot_api]
impl SupplyNetworkCore {
    #[func]
    fn load_state(
        &mut self,
        depots: PackedInt64Array,
        towns: PackedInt64Array,
        completed: i64,
        paths: Array<Variant>,
        painted: Array<Variant>,
    ) -> bool {
        if depots.len() != 2 || towns.len() > 100_000 {
            return false;
        }
        let parse = || -> Option<SupplyNetwork> {
            Some(SupplyNetwork {
                depots: [
                    u32::try_from(depots[0]).ok()?,
                    u32::try_from(depots[1]).ok()?,
                ],
                towns: towns
                    .as_slice()
                    .iter()
                    .map(|id| u32::try_from(*id).ok())
                    .collect::<Option<_>>()?,
                completed: u32::try_from(completed).ok()?,
                roads: read_roads(&paths)?,
                painted: read_roads(&painted)?,
            })
        };
        let Some(state) = parse().filter(SupplyNetwork::valid) else {
            return false;
        };
        self.core = state;
        true
    }
    #[func]
    fn rebuild(
        &mut self,
        team: u8,
        mut actors: Gd<ActorStateCore>,
        mut geometry: Gd<WorldGeometryCore>,
    ) -> Array<Variant> {
        let mut geometry = geometry.bind_mut();
        let Some(geometry) = &mut geometry.core else {
            return Array::new();
        };
        match self
            .core
            .rebuild(team, &mut actors.bind_mut().core, geometry)
        {
            Ok(removed) => varray![&removed
                .into_iter()
                .map(i64::from)
                .collect::<PackedInt64Array>()],
            Err(error) => {
                godot_error!("{error}");
                Array::new()
            }
        }
    }
    #[func]
    fn register_start(&mut self, id: u32, mut actors: Gd<ActorStateCore>) -> bool {
        self.core
            .register_start(id, &mut actors.bind_mut().core)
            .is_ok()
    }
    #[func]
    fn route_to(&self, id: u32, actors: Gd<ActorStateCore>) -> PackedVector3Array {
        self.core
            .route_to(&actors.bind().core, id)
            .iter()
            .map(|p| Vector3::new(p.x, p.y, p.z))
            .collect()
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        varray![
            &self
                .core
                .depots
                .iter()
                .map(|id| i64::from(*id))
                .collect::<PackedInt64Array>(),
            &self
                .core
                .towns
                .iter()
                .map(|id| i64::from(*id))
                .collect::<PackedInt64Array>(),
            self.core.completed,
            &roads(&self.core.roads),
            &roads(&self.core.painted)
        ]
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().map_or_else(
            |_| PackedByteArray::new(),
            |b| PackedByteArray::from(b.as_slice()),
        )
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = SupplyNetwork::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }
}
