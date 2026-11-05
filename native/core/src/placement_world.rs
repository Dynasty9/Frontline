//! Placement spends supply, registers occupied ground and assigns engineers in one server operation.
use crate::battle_stats::BattleStats;
use crate::building_placement::{Definition, Distances};
use crate::command_handoff::Changed;
use crate::command_ownership::Ownership;
use crate::economy;
use crate::infantry::Infantry;
use crate::rules_world::Rules;
use crate::squad_movement::Context;
use crate::squad_movement::{self, flat, point};
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::water::Water;

pub struct Request<'a> {
    pub peer: i32,
    pub team: i8,
    pub position: Vector3,
    pub yaw: f64,
    pub size: Option<Vector3>,
    pub squads: &'a [u32],
    pub assign: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Warning { peer: i32, text: String },
    Placed { id: u32, ownership: Changed },
    Squad(squad_movement::Event),
}
fn warning(peer: i32, text: String) -> Vec<Event> {
    if peer > 0 {
        vec![Event::Warning { peer, text }]
    } else {
        vec![]
    }
}
impl Context<'_> {
    pub fn place_building(
        &mut self,
        rules: &mut Rules,
        owners: &Ownership,
        battle: &mut BattleStats,
        water: &Water,
        request: Request<'_>,
        definition: Option<&Definition<'_>>,
        distances: &Distances,
        fob_names: &[String],
        engineer: &dyn Fn(&Infantry) -> bool,
        display: &dyn Fn(&Structure) -> String,
    ) -> Result<Vec<Event>, &'static str> {
        let Request {
            peer,
            team,
            mut position,
            mut yaw,
            size,
            squads,
            assign,
        } = request;
        if !point(position)
            || !yaw.is_finite()
            || yaw.abs() > 1e12
            || size
                .is_some_and(|s| !s.is_finite() || s.min_element() <= 0. || s.max_element() > 8192.)
            || squads.len() > 100_000
            || !self.now.is_finite()
            || self.now.abs() > 1e12 - 100.
        {
            return Err("invalid building order");
        }
        if !(0..=1).contains(&team) || owners.team_of(peer) != team {
            return Ok(vec![]);
        }
        let Some(def) = definition else {
            return Ok(vec![]);
        };
        if !def.valid() {
            return Err("invalid building definition");
        }
        if def.teams & (1 << team) == 0 {
            return Ok(vec![]);
        }
        let mut variant = 0;
        if matches!(def.key, "mg_nest" | "hmg_nest") {
            if let Some(spot) = self
                .geometry
                .trench_mount_spot(self.actors, position, yaw)?
            {
                position = spot.position;
                yaw = spot.yaw;
                variant = 1;
            }
        }
        let error = self.geometry.placement_error(
            self.actors,
            &rules.network,
            water,
            team,
            Some(def),
            position,
            yaw,
            distances,
            display,
        )?;
        if !error.is_empty() {
            return Ok(warning(peer, error));
        }
        if self.actors.entities().len() >= crate::entities::MAX_ENTITIES
            || self.actors.entities().next_id() > u32::MAX as u64
        {
            return Err("entity registry exhausted");
        }
        let name = if def.key == "fob" {
            if fob_names.is_empty()
                || fob_names.len() > 4096
                || fob_names
                    .iter()
                    .any(|n| n.is_empty() || n.len() > 4096 || n.contains('\0'))
                || rules.fob_names_used[team as usize] == u64::MAX
            {
                return Err("invalid base names");
            }
            fob_names[(rules.fob_names_used[team as usize] % fob_names.len() as u64) as usize]
                .clone()
        } else {
            String::new()
        };
        let mut st = Structure {
            kind: def.key.into(),
            team,
            owner: peer,
            position,
            yaw,
            size: size.unwrap_or(Vector3::ONE),
            variant,
            name,
            built: false,
            progress: 0.,
            ..Default::default()
        };
        st.id = self.actors.entities().next_id() as u32;
        st.initialize(Some(def.body), self.geometry.terrain.half())?;
        battle.check_add(peer, team, 14, f64::from(def.cost))?;
        if !economy::spend(self.actors, team, position, def.cost)? {
            return Ok(warning(
                peer,
                format!(
                    "Not enough supply at a nearby FOB for {} ({}).",
                    def.name, def.cost
                ),
            ));
        }
        battle.add(peer, team, 14, f64::from(def.cost))?;
        if def.key == "fob" {
            rules.fob_names_used[team as usize] += 1;
        }
        self.geometry.register_structure(&mut st, self.actors)?;
        let id = self
            .actors
            .spawn(crate::actors::Actor::Structure(Box::new(st)))?;
        let mut builders = if assign {
            owners.select_squads(peer, squads, self.squads)?
        } else {
            vec![]
        };
        if assign && builders.is_empty() {
            let mut distance = 1e9;
            for q in self.squads.iter_mut() {
                if q.order == "build"
                    || !owners.can_command(peer, q.team, q.owner)
                    || !q
                        .members
                        .iter()
                        .filter_map(|&id| self.actors.soldier(id))
                        .any(engineer)
                {
                    continue;
                }
                let d = f64::from(flat(q.centroid(self.now, self.actors) - position).length());
                if d < distance {
                    distance = d;
                    builders.clear();
                    builders.push(q.id);
                }
            }
        }
        let changed = owners.take_command(peer, &builders, &[], self.squads, self.actors)?;
        let mut out = vec![Event::Placed {
            id,
            ownership: changed,
        }];
        for q in builders {
            out.extend(self.order_work(q, id)?.into_iter().map(Event::Squad));
        }
        Ok(out)
    }
}
