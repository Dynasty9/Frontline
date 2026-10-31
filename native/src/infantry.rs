use crate::simulation_random::SimulationRandomCore;
use frontline_core::drone_reaction::DroneMemory;
use frontline_core::grenade_attack::GrenadeAttack;
use frontline_core::grenade_reaction::GrenadeMemory;
use frontline_core::infantry::*;
use frontline_core::infantry_action::{Action, ActionState, Round, Throw};
use frontline_core::infantry_aim::InfantryAim;
use frontline_core::infantry_control::Control;
use frontline_core::infantry_orders::{Arrival, PathFinish};
use frontline_core::infantry_tactics::{CoverRequest, Shelter};
use frontline_core::infantry_update::{ActivityContext, Movement};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryStateCore {
    base: Base<RefCounted>,
    core: Option<Infantry>,
}

fn read<T: FromGodot>(v: &Array<Variant>, i: usize) -> Option<T> {
    v.get(i)?.try_to().ok()
}
fn row(v: &Array<Variant>, i: usize, count: usize) -> Option<Array<Variant>> {
    let r: Array<Variant> = read(v, i)?;
    (r.len() == count).then_some(r)
}
fn text(v: &Array<Variant>, i: usize, limit: usize) -> Option<String> {
    let s: GString = read(v, i)?;
    if s.len() > limit {
        return None;
    }
    let s = s.to_string();
    (s.len() <= limit).then_some(s)
}
fn point(v: &Array<Variant>, i: usize) -> Option<frontline_core::vector::Vector3> {
    Some(crate::point(read(v, i)?))
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn mount(
    v: &Array<Variant>,
    index: usize,
) -> Option<Option<(frontline_core::vector::Vector3, f64)>> {
    let m: PackedFloat64Array = read(v, index)?;
    if m.is_empty() {
        return Some(None);
    }
    if m.len() != 4 {
        return None;
    }
    Some(Some((
        frontline_core::vector::Vector3::new(m[0] as f32, m[1] as f32, m[2] as f32),
        m[3],
    )))
}
fn id(v: &Array<Variant>, i: usize) -> Option<u64> {
    Some(u64::from(read::<u32>(v, i)?))
}
fn ids(v: &Array<Variant>, i: usize, limit: usize) -> Option<Vec<u64>> {
    let a: PackedInt64Array = read(v, i)?;
    if a.len() > limit {
        return None;
    }
    a.as_slice()
        .iter()
        .map(|n| Some(u64::from(u32::try_from(*n).ok()?)))
        .collect()
}
fn round(v: &Array<Variant>, i: usize) -> Option<Round> {
    match read::<u8>(v, i)? {
        0 => Some(Round::Frag),
        1 => Some(Round::Smoke),
        2 => Some(Round::HighExplosive),
        _ => None,
    }
}
fn opening(v: &Array<Variant>) -> Option<Opening> {
    if v.len() != 4 {
        return None;
    }
    Some(Opening {
        id: id(v, 0)?,
        center: point(v, 1)?,
        normal: point(v, 2)?,
        door: read(v, 3)?,
    })
}
fn state(v: &Array<Variant>) -> Option<Infantry> {
    if v.len() != 10 {
        return None;
    }
    let i = row(v, 0, 12)?;
    let credit: Array<Variant> = read(&i, 11)?;
    let identity = Identity {
        id: read(&i, 0)?,
        team: read(&i, 1)?,
        owner: read(&i, 2)?,
        gone: read(&i, 3)?,
        visible: read(&i, 4)?,
        seen: read(&i, 5)?,
        unit: text(&i, 6, 128)?,
        name: text(&i, 7, 1024)?,
        squad: read(&i, 8)?,
        weapon: text(&i, 9, 128)?,
        mounted_weapon: text(&i, 10, 128)?,
        hit_by: if credit.is_empty() {
            None
        } else {
            if credit.len() != 4 {
                return None;
            }
            Some(Credit {
                owner: read(&credit, 0)?,
                team: read(&credit, 1)?,
                unit: text(&credit, 2, 128)?,
                soldier: read(&credit, 3)?,
            })
        },
    };
    let c = row(v, 1, 14)?;
    let motion = row(&c, 1, 3)?;
    let grenades = row(&c, 4, 2)?;
    let control = row(&c, 6, 3)?;
    let aim = row(&c, 10, 3)?;
    let o = row(v, 2, 11)?;
    let cover = row(v, 3, 12)?;
    let d = row(v, 4, 9)?;
    let l = row(v, 5, 12)?;
    let e = row(v, 6, 10)?;
    let choice: Array<Variant> = read(&e, 2)?;
    let entry_opening: Array<Variant> = read(&e, 4)?;
    let m = row(v, 7, 6)?;
    let mortar_aim: PackedVector3Array = read(&m, 3)?;
    if mortar_aim.len() > 1 {
        return None;
    }
    let f = row(v, 8, 16)?;
    let p = row(v, 9, 7)?;
    let s = Infantry {
        identity,
        vitals: crate::infantry_vitals::decode(read::<PackedFloat64Array>(&c, 0)?.as_slice())?,
        motion: crate::infantry_motion::state(
            read::<PackedFloat64Array>(&motion, 0)?.as_slice(),
            read(&motion, 1)?,
            read(&motion, 2)?,
        )?,
        weapon: crate::infantry_weapon::decode_state(
            read::<PackedFloat64Array>(&c, 2)?.as_slice(),
        )?,
        arsenal: crate::infantry_arsenal::state(&read(&c, 3)?)?,
        grenades: GrenadeAttack {
            frags: read(&grenades, 0)?,
            cooldown: read(&grenades, 1)?,
        },
        supply: crate::infantry_supply::state(&read(&c, 5)?)?,
        control: Control {
            hidden: read::<u8>(&control, 0)?.try_into().ok()?,
            hidden_timer: read(&control, 1)?,
            previous_position: point(&control, 2)?,
        },
        idle: crate::infantry_idle::state(&read(&c, 7)?)?,
        controller: crate::infantry_controller::state(&read(&c, 8)?)?,
        shock: crate::infantry_shock::decode(read::<PackedFloat64Array>(&c, 9)?.as_slice())?,
        aim: InfantryAim {
            sight_target: id(&aim, 0)?,
            sight_until: read(&aim, 1)?,
            visible: read(&aim, 2)?,
        },
        grenade_memory: GrenadeMemory {
            seen: ids(&c, 11, 100_000)?,
        },
        drone_memory: DroneMemory {
            heard: ids(&c, 12, 17)?,
        },
        action: crate::infantry_action::state(&read(&c, 13)?)?,
        orders: Orders {
            pending_path: read(&o, 0)?,
            path_revision: u64::try_from(read::<i64>(&o, 1)?).ok()?,
            goal: point(&o, 2)?,
            purpose: read::<u8>(&o, 3)?.try_into().ok()?,
            move_mode: read(&o, 4)?,
            base_y: read(&o, 5)?,
            backwards: read(&o, 6)?,
            hold_position: point(&o, 7)?,
            hold_face: point(&o, 8)?,
            leash: read(&o, 9)?,
            detached: read(&o, 10)?,
        },
        cover: FightingPosition {
            kind: read(&cover, 0)?,
            position: point(&cover, 1)?,
            at_cover: read(&cover, 2)?,
            lean_direction: point(&cover, 3)?,
            threat: point(&cover, 4)?,
            evaluate_at: read(&cover, 5)?,
            normal: point(&cover, 6)?,
            height: read(&cover, 7)?,
            material: read(&cover, 8)?,
            structure: id(&cover, 9)?,
            anchor: read(&cover, 10)?,
            shifting: read(&cover, 11)?,
        },
        duty: Duty {
            kind: read::<u8>(&d, 0)?.try_into().ok()?,
            entity: id(&d, 1)?,
            partner: id(&d, 2)?,
            phase: read(&d, 3)?,
            timer: read(&d, 4)?,
            position: point(&d, 5)?,
            second_position: point(&d, 6)?,
            front: read(&d, 7)?,
            throw_kind: round(&d, 8)?,
        },
        links: Links {
            vehicle: id(&l, 0)?,
            dragged_by: id(&l, 1)?,
            rescue_claimed: id(&l, 2)?,
            carried_by: ids(&l, 3, 64)?,
            stretcher_claimed: read(&l, 4)?,
            captor: id(&l, 5)?,
            hidden_in: id(&l, 6)?,
            tent_dead: read(&l, 7)?,
            home: id(&l, 8)?,
            prison_destination: id(&l, 9)?,
            intel_left: read(&l, 10)?,
            intel_timer: read(&l, 11)?,
        },
        entry: HouseEntry {
            clear: read(&e, 0)?,
            no_frag: read(&e, 1)?,
            selected: if choice.is_empty() {
                None
            } else {
                if choice.len() != 3 {
                    return None;
                }
                Some(BreachChoice {
                    house: id(&choice, 0)?,
                    opening: opening(&read(&choice, 1)?)?,
                    enemy: id(&choice, 2)?,
                })
            },
            house: id(&e, 3)?,
            opening: if entry_opening.is_empty() {
                None
            } else {
                Some(opening(&entry_opening)?)
            },
            next_check: read(&e, 5)?,
            cooking_started: read(&e, 6)?,
            grenade: id(&e, 7)?,
            wait_until: read(&e, 8)?,
            reordered: read(&e, 9)?,
        },
        emplacement: Emplacement {
            structure: id(&m, 0)?,
            target: id(&m, 1)?,
            scan_timer: read(&m, 2)?,
            mortar_aim: mortar_aim.as_slice().first().copied().map(crate::point),
            mortar_round: round(&m, 4)?,
            mortar_delay: read(&m, 5)?,
        },
        fight: Fight {
            target: id(&f, 0)?,
            forced_target: id(&f, 1)?,
            visible_targets: ids(&f, 2, 100_000)?,
            covering_until: read(&f, 3)?,
            covering_position: point(&f, 4)?,
            fire_team: read(&f, 5)?,
            out_of_ammo_said: read(&f, 6)?,
            controlled_drone: id(&f, 7)?,
            sector: point(&f, 8)?,
            separation: point(&f, 9)?,
            shuffling: read(&f, 10)?,
            noticed_grenade: id(&f, 11)?,
            flee_fire_at: read(&f, 12)?,
            build_sound_timer: read(&f, 13)?,
            loot: read(&f, 14)?,
            smokes: read(&f, 15)?,
        },
        posture: read::<u8>(&p, 0)?.try_into().ok()?,
        activity: read(&p, 1)?,
        flags: read(&p, 2)?,
        doing: read(&p, 3)?,
        doing_entity: id(&p, 4)?,
        hit_direction: point(&p, 5)?,
        hit_kind: text(&p, 6, 128)?,
    };
    s.valid().then_some(s)
}

fn encode_ids(ids: &[u64]) -> PackedInt64Array {
    ids.iter().map(|id| *id as i64).collect()
}
fn encode_opening(o: Opening) -> Array<Variant> {
    varray![o.id as i64, vector(o.center), vector(o.normal), o.door]
}
fn throw(t: Throw) -> Array<Variant> {
    varray![
        0i64,
        vector(t.position),
        t.round as i32,
        t.fuse,
        Vector3::ZERO
    ]
}
fn action(s: ActionState) -> Array<Variant> {
    let mut payload = varray![0i64, Vector3::ZERO, 0i32, 3.4f64, Vector3::ZERO];
    let code = match s.current {
        Action::None => 0,
        Action::Throw(t) => {
            payload = throw(t);
            1
        }
        Action::Rethrow { grenade, position } => {
            payload.set(0, &(grenade as i64).to_variant());
            payload.set(1, &vector(position).to_variant());
            2
        }
        Action::ThrowIn { position, fuse } => {
            payload.set(1, &vector(position).to_variant());
            payload.set(3, &fuse.to_variant());
            3
        }
        Action::Kick { grenade, velocity } => {
            payload.set(0, &(grenade as i64).to_variant());
            payload.set(4, &vector(velocity).to_variant());
            4
        }
        Action::DoorKick { door, position } => {
            payload.set(0, &(door as i64).to_variant());
            payload.set(1, &vector(position).to_variant());
            5
        }
        Action::Cook => 6,
        Action::Melee { target } => {
            payload.set(0, &(target as i64).to_variant());
            7
        }
        Action::Pickup { grenade } => {
            payload.set(0, &(grenade as i64).to_variant());
            8
        }
        Action::Launch { target } => {
            payload.set(0, &(target as i64).to_variant());
            9
        }
        Action::LaunchDrone { target } => {
            payload.set(0, &(target as i64).to_variant());
            10
        }
        Action::Mortar { position, round } => {
            payload.set(1, &vector(position).to_variant());
            payload.set(2, &(round as i32).to_variant());
            11
        }
    };
    varray![
        code,
        s.remaining,
        &payload,
        &s.queued_throw.map_or_else(Array::new, throw)
    ]
}
fn encode(s: &Infantry) -> Array<Variant> {
    let i = &s.identity;
    let credit = i.hit_by.as_ref().map_or_else(Array::new, |h| {
        varray![h.owner, h.team as i32, &GString::from(&h.unit), h.soldier]
    });
    let identity = varray![
        i.id,
        i.team as i32,
        i.owner,
        i.gone,
        i.visible,
        i.seen,
        &GString::from(&i.unit),
        &GString::from(&i.name),
        i.squad,
        &GString::from(&i.weapon),
        &GString::from(&i.mounted_weapon),
        &credit
    ];
    let path: PackedVector3Array = s.motion.path.iter().copied().map(vector).collect();
    let motion = varray![
        &crate::infantry_motion::observation(&s.motion),
        &path,
        s.motion.door as i64
    ];
    let components = varray![
        &crate::infantry_vitals::observation(s.vitals),
        &motion,
        &crate::infantry_weapon::observation(&s.weapon),
        &crate::infantry_arsenal::encode(s.arsenal),
        &varray![s.grenades.frags, s.grenades.cooldown],
        &crate::infantry_supply::encode(s.supply),
        &varray![
            s.control.hidden as i32,
            s.control.hidden_timer,
            vector(s.control.previous_position)
        ],
        &crate::infantry_idle::encode(&s.idle),
        &crate::infantry_controller::encode(s.controller),
        &crate::infantry_shock::observation(s.shock),
        &varray![s.aim.sight_target as i64, s.aim.sight_until, s.aim.visible],
        &encode_ids(&s.grenade_memory.seen),
        &encode_ids(&s.drone_memory.heard),
        &action(s.action),
    ];
    let o = &s.orders;
    let orders = varray![
        o.pending_path,
        o.path_revision as i64,
        vector(o.goal),
        o.purpose as i32,
        o.move_mode,
        o.base_y,
        o.backwards,
        vector(o.hold_position),
        vector(o.hold_face),
        o.leash,
        o.detached
    ];
    let c = &s.cover;
    let cover = varray![
        c.kind,
        vector(c.position),
        c.at_cover,
        vector(c.lean_direction),
        vector(c.threat),
        c.evaluate_at,
        vector(c.normal),
        c.height,
        c.material as i32,
        c.structure as i64,
        c.anchor,
        c.shifting
    ];
    let d = &s.duty;
    let duty = varray![
        d.kind as i32,
        d.entity as i64,
        d.partner as i64,
        d.phase,
        d.timer,
        vector(d.position),
        vector(d.second_position),
        d.front,
        d.throw_kind as i32
    ];
    let l = &s.links;
    let links = varray![
        l.vehicle as i64,
        l.dragged_by as i64,
        l.rescue_claimed as i64,
        &encode_ids(&l.carried_by),
        l.stretcher_claimed,
        l.captor as i64,
        l.hidden_in as i64,
        l.tent_dead,
        l.home as i64,
        l.prison_destination as i64,
        l.intel_left,
        l.intel_timer
    ];
    let e = &s.entry;
    let choice = e.selected.map_or_else(Array::new, |b| {
        varray![b.house as i64, &encode_opening(b.opening), b.enemy as i64]
    });
    let opening = e.opening.map_or_else(Array::new, encode_opening);
    let entry = varray![
        e.clear,
        e.no_frag,
        &choice,
        e.house as i64,
        &opening,
        e.next_check,
        e.cooking_started,
        e.grenade as i64,
        e.wait_until,
        e.reordered
    ];
    let m = &s.emplacement;
    let aim: PackedVector3Array = m.mortar_aim.into_iter().map(vector).collect();
    let mount = varray![
        m.structure as i64,
        m.target as i64,
        m.scan_timer,
        &aim,
        m.mortar_round as i32,
        m.mortar_delay
    ];
    let f = &s.fight;
    let fight = varray![
        f.target as i64,
        f.forced_target as i64,
        &encode_ids(&f.visible_targets),
        f.covering_until,
        vector(f.covering_position),
        f.fire_team,
        f.out_of_ammo_said,
        f.controlled_drone as i64,
        vector(f.sector),
        vector(f.separation),
        f.shuffling,
        f.noticed_grenade as i64,
        f.flee_fire_at,
        f.build_sound_timer,
        f.loot,
        f.smokes
    ];
    let pose = varray![
        s.posture as i32,
        s.activity,
        s.flags,
        s.doing,
        s.doing_entity as i64,
        vector(s.hit_direction),
        &GString::from(&s.hit_kind)
    ];
    varray![
        &identity,
        &components,
        &orders,
        &cover,
        &duty,
        &links,
        &entry,
        &mount,
        &fight,
        &pose
    ]
}

#[godot_api]
impl InfantryStateCore {
    #[func]
    fn recover(&mut self, dt: f64, now: f64) -> bool {
        self.core
            .as_mut()
            .is_some_and(|s| s.recover(dt, now).is_ok())
    }

    #[func]
    fn fatigue(&mut self, dt: f64) -> bool {
        self.core.as_mut().is_some_and(|s| s.fatigue(dt).is_ok())
    }

    #[func]
    fn finish_tick(
        &mut self,
        dt: f64,
        now: f64,
        ammunition: PackedInt32Array,
        leader: bool,
    ) -> i32 {
        if ammunition.len() > 1 {
            return -1;
        }
        self.core
            .as_mut()
            .and_then(|s| {
                s.finish_tick(dt, now, ammunition.as_slice().first().copied(), leader)
                    .ok()
            })
            .map_or(-1, i32::from)
    }

    #[func]
    fn update_activity(
        &mut self,
        task_target: bool,
        mounted: bool,
        chat_partner: bool,
        ambush_target: bool,
    ) -> bool {
        let Some(s) = self.core.as_mut() else {
            return false;
        };
        s.update_activity(ActivityContext {
            task_target_exists: task_target,
            mounted_exists: mounted,
            chat_partner_exists: chat_partner,
            ambush_target,
        });
        true
    }

    #[func]
    fn compute_separation(
        &mut self,
        rows: Array<Variant>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> bool {
        let Some(s) = self.core.as_mut() else {
            return false;
        };
        let Some(neighbors) = crate::infantry_motion::neighbor_rows(rows) else {
            return false;
        };
        s.compute_separation(&neighbors, &mut rng.bind_mut().core)
            .is_ok()
    }

    #[func]
    fn stand(
        &mut self,
        input: Array<Variant>,
        navigation: Gd<crate::path_planner::PathPlannerCore>,
        terrain: Gd<crate::terrain::TerrainCore>,
        deck: PackedByteArray,
    ) -> bool {
        let Some(s) = self.core.as_mut() else {
            return false;
        };
        if input.len() != 4 {
            return false;
        }
        (|| {
            let navigation = navigation.bind();
            let terrain = terrain.bind();
            s.stand(
                read(&input, 0)?,
                read(&input, 1)?,
                read(&input, 2)?,
                mount(&input, 3)?,
                navigation.core.as_ref()?,
                terrain.core.as_ref()?,
                deck.as_slice(),
            )
            .ok()
        })()
        .is_some()
    }

    #[func]
    #[allow(clippy::too_many_arguments)]
    fn move_route(
        &mut self,
        input: Array<Variant>,
        doors: Array<Variant>,
        navigation: Gd<crate::path_planner::PathPlannerCore>,
        terrain: Gd<crate::terrain::TerrainCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<SimulationRandomCore>,
        deck: PackedByteArray,
    ) -> Array<Variant> {
        let Some(s) = self.core.as_mut() else {
            return Array::new();
        };
        if input.len() != 7 {
            return Array::new();
        }
        let result = (|| {
            let i = Movement {
                dt: read(&input, 0)?,
                time: read(&input, 1)?,
                speed: read(&input, 2)?,
                danger: read(&input, 3)?,
                has_doors: read(&input, 4)?,
                door_still_closed: read(&input, 5)?,
                mount: mount(&input, 6)?,
            };
            let doors = crate::infantry_motion::doors(doors)?;
            let navigation = navigation.bind();
            let terrain = terrain.bind();
            s.move_route(
                i,
                navigation.core.as_ref()?,
                terrain.core.as_ref()?,
                &mut collision.bind_mut().core,
                &mut rng.bind_mut().core,
                deck.as_slice(),
                &doors,
            )
            .ok()
        })();
        result.map_or_else(Array::new, |result| {
            let route = result.route.map_or_else(Array::new, |r| {
                varray![r.revision as i64, vector(r.job.destination), r.job.care]
            });
            let door = result.opened_door.map_or_else(Array::new, |d| {
                varray![d.id as i64, d.kicked, vector(d.by_position)]
            });
            varray![
                result.moving,
                &route,
                i32::from(result.arrival == Arrival::Prison),
                &door,
                result.speech.map_or(-1, i32::from),
                result.slid
            ]
        })
    }

    #[func]
    fn movement_speed(&self, danger: bool) -> f64 {
        self.core
            .as_ref()
            .map_or(-1.0, |s| s.movement_speed(danger))
    }

    #[func]
    fn crawling(&self, danger: bool) -> bool {
        self.core.as_ref().is_some_and(|s| s.crawling(danger))
    }

    #[func]
    fn sector_direction(
        &self,
        threats: PackedVector3Array,
        centroid: Vector3,
        members: i64,
        last: bool,
    ) -> Variant {
        let Some(s) = self.core.as_ref() else {
            return Variant::nil();
        };
        if threats.len() > 4096 {
            return Variant::nil();
        }
        let Ok(members) = usize::try_from(members) else {
            return Variant::nil();
        };
        let threats: Vec<_> = threats
            .as_slice()
            .iter()
            .copied()
            .map(crate::point)
            .collect();
        s.sector_direction(&threats, crate::point(centroid), members, last)
            .map_or_else(|_| Variant::nil(), |p| vector(p).to_variant())
    }

    #[func]
    fn reevaluate_cover(
        &mut self,
        now: f64,
        shelter: Array<Variant>,
        threats: PackedVector3Array,
    ) -> Variant {
        let Some(s) = self.core.as_mut() else {
            return Variant::nil();
        };
        if threats.len() > 4096 {
            return Variant::nil();
        }
        let result = (|| {
            let positions: PackedVector3Array = if shelter.is_empty() {
                PackedVector3Array::new()
            } else {
                if shelter.len() != 3 {
                    return None;
                }
                read(&shelter, 2)?
            };
            if positions.len() > 100_000 {
                return None;
            }
            let positions: Vec<_> = positions
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect();
            let held = if shelter.is_empty() {
                None
            } else {
                Some(Shelter {
                    gone: read(&shelter, 0)?,
                    burn: read(&shelter, 1)?,
                    anchors: &positions,
                })
            };
            let threats: Vec<_> = threats
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect();
            s.reevaluate_cover(now, held, &threats).ok()
        })();
        result.map_or_else(Variant::nil, |value| value.to_variant())
    }

    #[func]
    #[allow(clippy::too_many_arguments)]
    fn seek_cover(
        &mut self,
        input: Array<Variant>,
        threats: PackedVector3Array,
        buildings: Array<Variant>,
        mates: Array<Variant>,
        nearby: Array<Variant>,
        heat: PackedByteArray,
        deck: PackedByteArray,
        terrain: Gd<crate::terrain::TerrainCore>,
        navigation: Gd<crate::path_planner::PathPlannerCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(s) = self.core.as_mut() else {
            return Array::new();
        };
        if input.len() != 7 || threats.len() > 4096 {
            return Array::new();
        }
        let result = (|| {
            let threats: Vec<_> = threats
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect();
            let request = CoverRequest {
                time: read(&input, 0)?,
                anchor: point(&input, 1)?,
                radius: read(&input, 2)?,
                threats: &threats,
                grouped: read(&input, 3)?,
                unarmed: read(&input, 4)?,
                weapon_range: read(&input, 5)?,
                danger: read(&input, 6)?,
            };
            crate::cover_search::with_scene(
                buildings,
                mates,
                nearby,
                heat,
                deck,
                terrain,
                navigation,
                &mut collision,
                |scene| s.seek_cover(request, scene, &mut rng.bind_mut().core).ok(),
            )
        })();
        result.map_or_else(Array::new, |result| {
            let route = result
                .route
                .map_or_else(Array::new, |r| varray![r.revision as i64, r.job.care]);
            varray![
                result.search.candidates as i64,
                result.search.evaluations as i64,
                &route
            ]
        })
    }

    #[func]
    fn go_to(&mut self, destination: Vector3, purpose: i32, mode: i32) -> Array<Variant> {
        let Some(s) = self.core.as_mut() else {
            return Array::new();
        };
        let Some(purpose) = u8::try_from(purpose)
            .ok()
            .and_then(|p| Goal::try_from(p).ok())
        else {
            return Array::new();
        };
        let Ok(mode) = u8::try_from(mode) else {
            return Array::new();
        };
        let Ok(order) = s.go_to(crate::point(destination), purpose, mode) else {
            return Array::new();
        };
        varray![order.revision as i64, order.job.care]
    }

    #[func]
    fn stop_moving(&mut self) -> bool {
        self.core.as_mut().is_some_and(|s| s.stop_moving().is_ok())
    }

    #[func]
    fn accept_path(
        &mut self,
        revision: i64,
        path: PackedVector3Array,
        now: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> i32 {
        let Some(s) = self.core.as_mut() else {
            return -1;
        };
        let Ok(revision) = u64::try_from(revision) else {
            return -1;
        };
        if path.len() > 1_000_000 {
            return -1;
        }
        let path = path.as_slice().iter().copied().map(crate::point).collect();
        match s.accept_path(revision, path, now, &mut rng.bind_mut().core) {
            Ok(PathFinish::Ignored) => 0,
            Ok(PathFinish::Following) => 1,
            Ok(PathFinish::Arrived(Arrival::None)) => 2,
            Ok(PathFinish::Arrived(Arrival::Prison)) => 3,
            Ok(PathFinish::Unreachable) => 4,
            Err(_) => -1,
        }
    }

    #[func]
    fn arrived(&mut self, now: f64, mut rng: Gd<SimulationRandomCore>) -> i32 {
        let Some(s) = self.core.as_mut() else {
            return -1;
        };
        match s.arrived(now, &mut rng.bind_mut().core) {
            Ok(Arrival::None) => 0,
            Ok(Arrival::Prison) => 1,
            Err(_) => -1,
        }
    }

    #[func]
    fn load_state(&mut self, values: Array<Variant>) -> bool {
        let Some(s) = state(&values) else {
            return false;
        };
        self.core = Some(s);
        true
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        self.core.as_ref().map_or_else(Array::new, encode)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .and_then(|s| s.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(s) = Infantry::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(s);
        true
    }
}
