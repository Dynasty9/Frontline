use frontline_core::entities::{Entities, Identity, Kind};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct EntityRegistryCore {
    base: Base<RefCounted>,
    core: Entities,
}

fn kind(name: &GString) -> Option<Kind> {
    match name.to_string().as_str() {
        "soldier" => Some(Kind::Soldier),
        "structure" => Some(Kind::Structure),
        "vehicle" => Some(Kind::Vehicle),
        "projectile" => Some(Kind::Projectile),
        "drone" => Some(Kind::Drone),
        _ => None,
    }
}

#[godot_api]
impl EntityRegistryCore {
    #[func]
    fn initialize(
        &mut self,
        next_id: i64,
        ids: PackedInt64Array,
        kinds: PackedStringArray,
    ) -> bool {
        let Ok(next_id) = u64::try_from(next_id) else {
            return false;
        };
        if ids.len() != kinds.len() || ids.len() > frontline_core::entities::MAX_ENTITIES {
            return false;
        }
        let mut entries = Vec::with_capacity(ids.len());
        for (id, name) in ids.as_slice().iter().zip(kinds.as_slice()) {
            let (Ok(id), Some(kind)) = (u32::try_from(*id), kind(name)) else {
                return false;
            };
            entries.push(Identity { id, kind });
        }
        let Ok(core) = Entities::from_entries(next_id, &entries) else {
            return false;
        };
        self.core = core;
        true
    }

    #[func]
    fn spawn(&mut self, name: GString) -> i64 {
        kind(&name)
            .and_then(|kind| self.core.spawn(kind).ok())
            .map(i64::from)
            .unwrap_or(0)
    }

    #[func]
    fn remove(&mut self, id: i64) -> bool {
        u32::try_from(id).is_ok_and(|id| self.core.remove(id))
    }

    #[func]
    fn next_id(&self) -> i64 {
        self.core.next_id() as i64
    }

    #[func]
    fn ids(&self) -> PackedInt64Array {
        self.core.iter().map(|entry| i64::from(entry.id)).collect()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Entities::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
