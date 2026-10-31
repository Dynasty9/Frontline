//! Stable identities and registration order, independent of presentation objects.
use crate::state_codec::{Reader, Writer};
use std::collections::HashMap;

const SCHEMA: &[u8; 8] = b"FLEN\x01\0\0\0";
pub const MAX_ENTITIES: usize = 1_000_000;
const EXHAUSTED: u64 = u32::MAX as u64 + 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Kind {
    Soldier,
    Structure,
    Vehicle,
    Projectile,
    Drone,
}

impl TryFrom<u8> for Kind {
    type Error = &'static str;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Soldier),
            1 => Ok(Self::Structure),
            2 => Ok(Self::Vehicle),
            3 => Ok(Self::Projectile),
            4 => Ok(Self::Drone),
            _ => Err("unknown entity kind"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Identity {
    pub id: u32,
    pub kind: Kind,
}

#[derive(Clone, Debug)]
pub struct Entities {
    next_id: u64,
    order: Vec<Option<Identity>>,
    // Lookup never determines simulation order.
    slots: HashMap<u32, usize>,
}

impl Default for Entities {
    fn default() -> Self {
        Self {
            next_id: 1,
            order: Vec::new(),
            slots: HashMap::new(),
        }
    }
}

impl Entities {
    pub fn from_entries(next_id: u64, entries: &[Identity]) -> Result<Self, &'static str> {
        if !(1..=EXHAUSTED).contains(&next_id) || entries.len() > MAX_ENTITIES {
            return Err("invalid entity registry size or cursor");
        }
        let mut result = Self {
            next_id,
            order: Vec::with_capacity(entries.len()),
            slots: HashMap::with_capacity(entries.len()),
        };
        for entry in entries {
            if entry.id == 0 || u64::from(entry.id) >= next_id {
                return Err("entity identity exceeds allocation cursor");
            }
            if result.slots.insert(entry.id, result.order.len()).is_some() {
                return Err("duplicate entity identity");
            }
            result.order.push(Some(*entry));
        }
        Ok(result)
    }

    pub fn next_id(&self) -> u64 {
        self.next_id
    }

    pub fn len(&self) -> usize {
        self.slots.len()
    }

    pub fn is_empty(&self) -> bool {
        self.slots.is_empty()
    }

    pub fn get(&self, id: u32) -> Option<Identity> {
        self.slots.get(&id).and_then(|&slot| self.order[slot])
    }

    pub fn iter(&self) -> impl Iterator<Item = Identity> + '_ {
        self.order.iter().filter_map(|entry| *entry)
    }

    pub fn spawn(&mut self, kind: Kind) -> Result<u32, &'static str> {
        if self.next_id == EXHAUSTED || self.len() == MAX_ENTITIES {
            return Err("entity registry exhausted");
        }
        let id = self.next_id as u32;
        self.slots.insert(id, self.order.len());
        self.order.push(Some(Identity { id, kind }));
        self.next_id += 1;
        Ok(id)
    }

    pub fn remove(&mut self, id: u32) -> bool {
        let Some(slot) = self.slots.remove(&id) else {
            return false;
        };
        self.order[slot] = None;
        // Long battles shed projectile slots without changing survivor order.
        if self.order.len() > self.len() * 2 + 1024 {
            self.order.retain(Option::is_some);
            for (slot, entry) in self.order.iter().enumerate() {
                self.slots.insert(entry.unwrap().id, slot);
            }
        }
        true
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(SCHEMA);
        out.u64(self.next_id);
        out.u32(self.len() as u32);
        for entry in self.iter() {
            out.u32(entry.id);
            out.byte(entry.kind as u8);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 20 + MAX_ENTITIES * 5 {
            return Err("entity checkpoint exceeds limit");
        }
        let mut input = Reader::new(bytes, SCHEMA)?;
        let next_id = input.u64()?;
        let count = input.u32()? as usize;
        if count > MAX_ENTITIES || bytes.len() != 20 + count * 5 {
            return Err("invalid entity checkpoint length");
        }
        let mut entries = Vec::with_capacity(count);
        for _ in 0..count {
            entries.push(Identity {
                id: input.u32()?,
                kind: input.byte()?.try_into()?,
            });
        }
        input.finish()?;
        Self::from_entries(next_id, &entries)
    }
}
