//! Cover decisions borrow the world's existing anchors and read its retained occupancy.
use crate::actors::Actors;
use crate::collision::CollisionWorld;
use crate::cover_search::{self, NearbyClaim, Scene, SearchResult, SquadClaim};
use crate::infantry::{Goal, Infantry};
use crate::infantry_tactics::{CoverOrder, CoverRequest, Shelter};
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::structure::Structure;
use crate::terrain::Terrain;
use crate::vector::Vector3;

pub struct CoverWorld<'a> {
    pub terrain: &'a Terrain,
    pub nav: &'a PathPlanner,
    pub collision: &'a mut CollisionWorld,
    pub heat: &'a [u8],
    pub deck: &'a [u8],
    pub units: &'a SpatialIndex,
    pub structures: &'a SpatialIndex,
}

#[derive(Clone, Copy)]
pub struct CoverIntent {
    pub now: f64,
    pub anchor: Vector3,
    pub radius: f64,
    pub weapon_range: f64,
    pub unarmed: bool,
}

impl Structure {
    pub fn cover_material(&self) -> u8 {
        match self.kind.as_str() {
            "low_wall" => {
                if self.variant % 3 == 1 {
                    0
                } else {
                    2
                }
            }
            "crates" => {
                if self.variant == 0 {
                    0
                } else {
                    1
                }
            }
            "medic_tent" | "watchtower" => 0,
            "car" | "house_wall" | "barracks" | "research" | "depot" | "factory" | "tree"
            | "town" | "ammo_cache" => 1,
            "trench" | "bunker" | "fob" | "hesco" => 3,
            _ => 2,
        }
    }
}

impl Actors {
    pub fn infantry_threats(
        &self,
        id: u32,
        now: f64,
        squad: Option<&Squad>,
    ) -> Result<Vec<Vector3>, &'static str> {
        let s = self.soldier(id).ok_or("missing infantry")?;
        if !now.is_finite()
            || now.abs() > 1e12 - 10.0
            || squad.is_some_and(|q| q.id != s.identity.squad)
        {
            return Err("invalid infantry threat context");
        }
        let mut threats = squad.map_or_else(Vec::new, |q| {
            q.threat_points(s.motion.position, 3, now, self)
        });
        if threats.is_empty() {
            threats.push(s.orders.hold_position + s.orders.hold_face * 40.0 + Vector3::Y * 1.5);
        }
        Ok(threats)
    }

    pub(crate) fn find_infantry_cover(
        &self,
        s: &Infantry,
        intent: CoverIntent,
        prone: bool,
        threats: &[Vector3],
        squad: Option<&Squad>,
        world: &mut CoverWorld<'_>,
    ) -> Result<SearchResult, &'static str> {
        if world.units.cell_size() != UNIT_CELL
            || world.structures.cell_size() != STRUCTURE_CELL
            || !intent.radius.is_finite()
            || !(0.0..=512.0).contains(&intent.radius)
            || squad.as_ref().is_some_and(|q| q.id != s.identity.squad)
        {
            return Err("invalid retained cover context");
        }
        let grouped = squad.is_some() && !s.orders.detached && !prone;
        let radius = if grouped {
            intent.radius.min(3.0)
        } else {
            intent.radius
        };
        let structures: Vec<_> = self
            .structures_near(world.structures, intent.anchor, radius + 4.0, false)?
            .into_iter()
            .filter_map(|id| self.structure(id))
            .filter(|st| st.built && !st.anchors.is_empty() && st.burn <= 0.0)
            .map(|st| crate::cover_search::Structure {
                id: st.id.into(),
                built: st.built,
                burn: st.burn,
                material: st.cover_material(),
                positions: st.anchors.as_slice(),
            })
            .collect();
        let squad_claims: Vec<_> = squad.as_ref().map_or_else(Vec::new, |q| {
            q.members
                .iter()
                .filter_map(|&id| self.soldier(id))
                .map(|s| SquadClaim {
                    id: s.identity.id.into(),
                    alive: s.vitals.life == Life::Alive,
                    covering: s.cover.at_cover || s.orders.purpose == Goal::Cover,
                    position: s.cover.position,
                })
                .collect()
        });
        let nearby_claims: Vec<_> = world
            .units
            .candidate_cells(intent.anchor, radius + 1.3)?
            .filter_map(|(cell, id)| self.soldier(id).map(|other| (cell, other)))
            .filter(|(_, other)| {
                other.identity.id != s.identity.id
                    && other.identity.team == s.identity.team
                    && other.vitals.life == Life::Alive
            })
            .map(|(cell, other)| NearbyClaim {
                id: other.identity.id.into(),
                team: other.identity.team.into(),
                alive: true,
                gone: false,
                position: other.motion.position,
                cover_position: other.cover.position,
                cell: [cell.0, cell.1],
            })
            .collect();
        cover_search::find(
            cover_search::Input {
                id: s.identity.id.into(),
                team: s.identity.team.into(),
                position: s.motion.position,
                anchor: intent.anchor,
                radius: intent.radius,
                grouped,
                prone,
                unarmed: intent.unarmed,
                weapon_range: intent.weapon_range,
                current_structure: s.cover.structure,
                current_anchor: s.cover.anchor,
            },
            threats,
            &mut Scene {
                terrain: world.terrain,
                navigation: world.nav,
                collision: world.collision,
                heat: world.heat,
                deck: world.deck,
                structures: &structures,
                squad_claims: &squad_claims,
                nearby_claims: &nearby_claims,
            },
        )
    }

    fn plan_infantry_cover(
        &self,
        s: &mut Infantry,
        intent: CoverIntent,
        threats: &[Vector3],
        mut squad: Option<&mut Squad>,
        world: &mut CoverWorld<'_>,
        rng: &mut SimulationRandom,
    ) -> Result<CoverOrder, &'static str> {
        let own_danger = s.vitals.suppression > 5.0 || !s.fight.visible_targets.is_empty();
        let danger = own_danger || squad.as_ref().is_some_and(|q| q.combat_status(intent.now));
        let search =
            self.find_infantry_cover(s, intent, false, threats, squad.as_deref(), world)?;
        let result = s.apply_cover_choice(
            CoverRequest {
                time: intent.now,
                anchor: intent.anchor,
                radius: intent.radius,
                threats,
                grouped: squad.is_some() && !s.orders.detached,
                unarmed: intent.unarmed,
                weapon_range: intent.weapon_range,
                danger,
            },
            search,
            rng,
        )?;
        // The legacy short circuit only refreshes this cache when he actually moves to cover.
        if result.route.is_some() && s.orders.purpose == Goal::Cover && !own_danger {
            if let Some(q) = squad.as_mut() {
                q.in_combat(intent.now);
            }
        }
        Ok(result)
    }

    pub fn seek_infantry_cover(
        &mut self,
        id: u32,
        intent: CoverIntent,
        squad: Option<&mut Squad>,
        world: &mut CoverWorld<'_>,
        rng: &mut SimulationRandom,
    ) -> Result<CoverOrder, &'static str> {
        let threats = self.infantry_threats(id, intent.now, squad.as_deref())?;
        let mut next = self.soldier(id).unwrap().clone();
        let mut random = *rng;
        let result =
            self.plan_infantry_cover(&mut next, intent, &threats, squad, world, &mut random)?;
        *self.soldier_mut(id).unwrap() = next;
        *rng = random;
        Ok(result)
    }

    pub fn review_infantry_cover(
        &mut self,
        id: u32,
        now: f64,
        weapon_range: f64,
        unarmed: bool,
        squad: Option<&mut Squad>,
        world: &mut CoverWorld<'_>,
        rng: &mut SimulationRandom,
    ) -> Result<Option<CoverOrder>, &'static str> {
        let threats = self.infantry_threats(id, now, squad.as_deref())?;
        let mut next = self.soldier(id).unwrap().clone();
        let shelter = self.structure(next.cover.structure as u32);
        let anchors: Vec<_> = shelter.map_or_else(Vec::new, |st| {
            st.anchors.iter().map(|a| a.position).collect()
        });
        let need = next.reevaluate_cover(
            now,
            shelter.map(|st| Shelter {
                gone: false,
                burn: st.burn,
                anchors: &anchors,
            }),
            &threats,
        )?;
        let mut random = *rng;
        let result = if need {
            let intent = CoverIntent {
                now,
                anchor: next.orders.hold_position,
                radius: next.orders.leash,
                weapon_range,
                unarmed,
            };
            Some(self.plan_infantry_cover(
                &mut next,
                intent,
                &threats,
                squad,
                world,
                &mut random,
            )?)
        } else {
            None
        };
        *self.soldier_mut(id).unwrap() = next;
        *rng = random;
        Ok(result)
    }
}
