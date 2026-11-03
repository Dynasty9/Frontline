//! Render effects are derived from completed ticks without advancing gameplay or its RNG.
use crate::simulation::{Frame, Simulation};
use frontline_core as sim;
use serde_json::{json, Value};
use sim::{match_commands::Audience, vector::Vector3};

pub struct Effect {
    pub mask: u8,
    pub reliable: bool,
    pub data: Value,
}
pub struct Message {
    pub audience: Audience,
    pub data: Value,
}
#[derive(Default)]
pub struct Events {
    pub blasts: Vec<(Vector3, f64)>,
    pub effects: Vec<Effect>,
    pub messages: Vec<Message>,
    pub properties: Vec<(u32, u8, Value)>,
}
fn p(v: Vector3) -> Value {
    json!(v.to_array())
}
pub fn admits(a: Audience, peer: i32, team: i8) -> bool {
    match a {
        Audience::Everyone => true,
        Audience::Peer(id) => peer == id,
        Audience::Team(side) => team < 0 || side < 0 || team == side,
    }
}
impl Events {
    pub fn collect(s: &Simulation, frame: &Frame) -> Self {
        let mut out = Self::default();
        for e in &frame.commands {
            out.command(s, e);
        }
        for e in &frame.events {
            use sim::match_tick::Event as E;
            match e {
                E::Infantry(e) => out.infantry(s, e),
                E::Building(e) => out.building(s, e),
                E::Fire(e) => out.fire(s, e),
                E::Vehicle(e) => out.vehicle(s, e),
                E::Ordnance(e) => match e {
                    sim::ordnance_world::Event::Combat(e) => out.combat(s, e),
                    sim::ordnance_world::Event::Sound {
                        name,
                        volume,
                        position,
                    } => out.fx(3, false, json!([14, name, volume, p(*position)])),
                    sim::ordnance_world::Event::Smothered {
                        team,
                        position,
                        name,
                        ..
                    } => out.msg(
                        Audience::Team(*team),
                        "alert",
                        format!("{name} threw himself on a grenade to save his squad."),
                        Some(*position),
                    ),
                    sim::ordnance_world::Event::Spawn(_) => {}
                },
                E::Squad(e) => match e {
                    sim::squad_world::Event::Brain(e) => out.brain(s, e),
                    sim::squad_world::Event::Attack(e) => out.attack(s, e),
                    sim::squad_world::Event::Removed(_) => {}
                },
                E::Rules(e) => out.rules(s, e),
                E::Deferred(e) => out.combat(s, e),
            }
        }
        out
    }
    fn mask(s: &Simulation, id: u32) -> u8 {
        s.state.field.actors.get(id).map_or(0, |a| {
            u8::from(super::can_know(s, a, 0)) | (u8::from(super::can_know(s, a, 1)) << 1)
        })
    }
    fn fx(&mut self, mask: u8, reliable: bool, data: Value) {
        self.effects.push(Effect {
            mask,
            reliable,
            data,
        });
    }
    fn msg(
        &mut self,
        audience: Audience,
        kind: &str,
        text: impl Into<String>,
        at: Option<Vector3>,
    ) {
        let team = if let Audience::Team(t) = audience {
            t
        } else {
            -1
        };
        self.messages.push(Message {
            audience,
            data: json!([team, kind, text.into(), at.map(p)]),
        });
    }
    fn say(&mut self, s: &Simulation, id: u32, text: &str) {
        self.fx(Self::mask(s, id), false, json!([2, id, text]));
    }
    fn command(&mut self, s: &Simulation, e: &sim::match_commands::Event) {
        use sim::match_commands::{Event as E, MessageKind as K};
        match e {
            E::Message {
                audience,
                kind,
                text,
                position,
            } => self.msg(
                *audience,
                match kind {
                    K::Alert => "alert",
                    K::Warning => "warn",
                    K::Info => "info",
                    K::Chat => "chat",
                    K::Radio => "radio",
                    K::Intel => "intel",
                },
                text,
                *position,
            ),
            E::Speech { soldier, text } => self.say(s, *soldier, text),
            E::Squad(e) => self.movement(s, e),
            E::Brain(e) => self.brain(s, e),
            E::Attack(e) => self.attack(s, e),
            E::Support(e) => self.support(e),
            E::Placement(e) => match e {
                sim::placement_world::Event::Warning { peer, text } => {
                    self.msg(Audience::Peer(*peer), "warn", text, None)
                }
                sim::placement_world::Event::Squad(e) => self.movement(s, e),
                sim::placement_world::Event::Placed { .. } => {}
            },
            E::Ownership(_) | E::Deed { .. } => {}
        }
    }
    fn death(&mut self, s: &Simulation, id: u32) {
        let Some(man) = s.state.field.actors.soldier(id) else {
            return;
        };
        if man.vitals.life != sim::infantry_vitals::Life::Dead {
            return;
        }
        if self
            .effects
            .iter()
            .any(|e| e.data[0] == 15 && e.data[1] == id)
        {
            return;
        }
        let mut direction = Vector3::new(man.hit_direction.x, 0., man.hit_direction.z);
        direction = if direction.length() > 0.05 {
            direction.normalize()
        } else {
            Vector3::new(man.motion.yaw.sin() as f32, 0., man.motion.yaw.cos() as f32)
        };
        let (kind, impulse) = if man.shock.flinging {
            (1, man.shock.velocity)
        } else {
            match man.hit_kind.as_str() {
                "explosion" => (1, direction * 4. + Vector3::Y * 2.5),
                "bullet" | "melee" => (0, direction * 2.6 + Vector3::Y * 0.4),
                _ => (2, Vector3::ZERO),
            }
        };
        self.fx(Self::mask(s, id), true, json!([15, id, p(impulse), kind]));
    }
    fn hit(&mut self, s: &Simulation, id: u32, hit: &sim::infantry_effects::InfantryHit) {
        if hit.previous_life != sim::infantry_vitals::Life::Dead
            && s.state
                .field
                .actors
                .soldier(id)
                .is_some_and(|m| m.vitals.life == sim::infantry_vitals::Life::Dead)
        {
            self.death(s, id);
        }
        if let Some(speech) = hit.casualty_speech {
            let name = s
                .state
                .field
                .actors
                .soldier(id)
                .map_or("Soldier", |m| m.identity.name.as_str());
            let text = match speech.cue {
                0 => "Man down!".into(),
                1 => format!("{name} is hit!"),
                2 => "We've got wounded!".into(),
                _ => format!("Medic! {name} is down!"),
            };
            self.say(s, speech.soldier, &text);
        }
        if let Some(cue) = hit.speech {
            self.say(
                s,
                id,
                ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"][usize::from(cue) % 4],
            );
        }
    }
    fn suppressed(&mut self, s: &Simulation, e: sim::squad::Speech) {
        self.say(
            s,
            e.soldier,
            [
                "I'm pinned!",
                "Can't move!",
                "Heads down!",
                "They've got us pinned!",
            ][usize::from(e.cue) % 4],
        );
    }
    fn combat(&mut self, s: &Simulation, e: &sim::world_combat::Event) {
        use sim::world_combat::Event as E;
        match e {
            E::Shot {
                shooter,
                muzzle,
                end,
                impact,
                sound,
                ..
            } => self.fx(
                Self::mask(s, *shooter),
                false,
                json!([0, p(*muzzle), p(*end), impact, sound, shooter]),
            ),
            E::Ricochet {
                position,
                direction,
            } => self.fx(3, false, json!([6, p(*position), p(*direction)])),
            E::Explosion { position, size } => {
                self.blasts.push((*position, *size));
                self.fx(3, true, json!([1, p(*position), size]));
            }
            E::Infantry(v) => {
                if let Some(hit) = &v.hit {
                    self.hit(s, v.soldier, hit);
                }
            }
            E::InfantryHit { id, hit } => self.hit(s, *id, hit),
            E::Speech(e) => self.suppressed(s, *e),
            E::Vehicle(e) => self.loss(s, e),
            E::Structure { id, damage } => self.damage(s, *id, damage),
            E::Fire(e) => self.fire(s, e),
            E::DroneDown { id, position, team } => {
                self.fx(3, false, json!([4, p(*position), [0.2, 0.2, 0.2, 1.0], 6]));
                self.msg(
                    Audience::Team(*team),
                    "alert",
                    "Drone lost.",
                    Some(*position),
                );
                let _ = id;
            }
            E::Toss { id, flight } => self.properties.push((
                *id,
                Self::mask(s, *id),
                json!({"toss":[p(flight.origin),flight.yaw,p(flight.velocity),p(flight.spin)]}),
            )),
            E::VehicleBlast { .. } | E::Despawn(_) | E::Rubble(_) | E::Stat(_) => {}
        }
    }
    fn infantry(&mut self, s: &Simulation, e: &sim::infantry_world::Event) {
        use sim::infantry_world::Event as E;
        match e {
            E::Combat(e) => self.fight(s, e),
            E::Prison(e) => match e {
                sim::infantry_prison_owned::Event::Movement(id, e) => self.travel(s, *id, e),
                sim::infantry_prison_owned::Event::Speech { captor, cue } => self.say(
                    s,
                    *captor,
                    [
                        "Move! Hands where I can see them!",
                        "On your feet! Walk!",
                        "Easy... keep those hands up.",
                    ][usize::from(*cue) % 3],
                ),
                sim::infantry_prison_owned::Event::CapturedAlert(id) => {
                    if let Some(m) = s.state.field.actors.soldier(*id) {
                        self.msg(
                            Audience::Team(m.identity.team),
                            "alert",
                            format!("{} has been captured!", m.identity.name),
                            Some(m.motion.position),
                        );
                    }
                }
                _ => {}
            },
            E::Died(id) => self.death(s, *id),
            E::PatchedUp(_) | E::Removed(_) | E::Rejoined { .. } => {}
        }
    }
    fn fight(&mut self, s: &Simulation, e: &sim::infantry_fight_world::Event) {
        use sim::infantry_fight_world::Event as E;
        match e {
            E::World(e) => self.combat(s, e),
            E::Speech { id, text } => self.say(s, *id, text),
            E::Movement { id, event } => self.travel(s, *id, event),
            E::Ordnance(e) => self.action(s, e),
            E::Construction(e) => match e {
                sim::infantry_build_world::Construction::Sound { position } => {
                    self.fx(3, false, json!([7, "build", p(*position)]))
                }
                _ => {}
            },
        }
    }
    fn travel(&mut self, s: &Simulation, id: u32, e: &sim::infantry_travel_owned::Event) {
        use sim::infantry_travel_owned::Event as E;
        match e {
            E::BreachSpeech(c) => self.say(
                s,
                id,
                ["Breaching!", "Door!", "Kicking it in!"][usize::from(*c) % 3],
            ),
            E::ThrowSpeech(round) => self.say(
                s,
                id,
                if *round == sim::infantry_action::Round::Smoke {
                    "Smoke out!"
                } else {
                    "Frag out!"
                },
            ),
            E::GotAmmo => self.say(s, id, "Got ammo."),
            E::Door { id, kicked } => self.door(s, *id, *kicked),
            _ => {}
        }
    }
    fn door(&mut self, s: &Simulation, id: u32, kicked: bool) {
        self.properties
            .push((id, Self::mask(s, id), json!({"door":false,"dk":kicked})));
        if let Some(st) = s.state.field.actors.structure(id) {
            self.fx(
                Self::mask(s, id),
                false,
                json!([
                    7,
                    if kicked { "door_kick" } else { "door" },
                    p(st.position + Vector3::Y)
                ]),
            );
        }
    }
    fn action(&mut self, s: &Simulation, e: &sim::infantry_action_owned::Event) {
        use sim::infantry_action_owned::Event as E;
        match e {
            E::Launch {
                position,
                direction,
            } => self.fx(3, false, json!([8, p(*position), p(*direction)])),
            E::Mortar(position) => self.fx(3, false, json!([12, p(*position)])),
            E::Melee {
                target,
                position,
                hit,
            } => {
                self.fx(Self::mask(s, *target), false, json!([9, p(*position)]));
                self.hit(s, *target, hit);
            }
            E::Door(id) => self.door(s, *id, true),
            E::Spawn(_) | E::Smoke { .. } => {}
        }
    }
    fn damage(&mut self, s: &Simulation, id: u32, d: &sim::structure_damage::Damage) {
        let Some(st) = d
            .removed
            .as_deref()
            .or_else(|| s.state.field.actors.structure(id))
        else {
            return;
        };
        let mask = if st.team < 0 {
            3
        } else {
            st.seen | (1 << st.team)
        };
        for e in &d.events {
            use sim::structure_damage::Event as E;
            match e {
                E::Door => self.door(s, id, true),
                E::Debris(n) => self.fx(
                    mask,
                    false,
                    json!([4, p(st.position + Vector3::Y), [0.45, 0.4, 0.32, 1.0], n]),
                ),
                E::TreeFall(yaw) => {
                    self.fx(mask, true, json!([10, p(st.position), yaw, id, st.variant]))
                }
                E::UnderAttack => self.msg(
                    Audience::Team(st.team),
                    "alert",
                    format!(
                        "{} is under attack!",
                        if st.name.is_empty() {
                            &st.kind
                        } else {
                            &st.name
                        }
                    ),
                    Some(st.position),
                ),
                E::FobWrecked => self.msg(
                    Audience::Team(st.team),
                    "alert",
                    format!(
                        "FOB {} has been wrecked! Repair it with engineers.",
                        st.name
                    ),
                    Some(st.position),
                ),
                E::DestroyedAlert => self.msg(
                    Audience::Team(st.team),
                    "alert",
                    format!(
                        "{} destroyed.",
                        if st.name.is_empty() {
                            &st.kind
                        } else {
                            &st.name
                        }
                    ),
                    Some(st.position),
                ),
                _ => {}
            }
        }
    }
    fn fire(&mut self, s: &Simulation, e: &sim::fires::Event) {
        use sim::fires::Event as E;
        match e {
            E::Grass(patch) => self.fx(
                3,
                true,
                json!([16, p(patch.position), patch.radius, patch.life]),
            ),
            E::BurnedDown { structure, damage } => {
                if let Some(st) = damage.removed.as_deref() {
                    self.fx(
                        3,
                        true,
                        json!([17, p(st.position), p(st.size * 0.5), st.yaw]),
                    );
                }
                self.damage(s, *structure, damage);
            }
            E::Scorched { soldier, hit, .. } => self.hit(s, *soldier, hit),
            E::Ignited {
                structure,
                alert: true,
                ..
            } => {
                if let Some(st) = s.state.field.actors.structure(*structure) {
                    self.msg(
                        Audience::Team(st.team),
                        "alert",
                        format!("{} is on fire!", st.kind),
                        Some(st.position),
                    );
                }
            }
            _ => {}
        }
    }
    fn vehicle(&mut self, s: &Simulation, e: &sim::vehicle_world::Event) {
        use sim::vehicle_world::Event as E;
        match e {
            E::Combat(e) => match e {
                sim::vehicle_combat_world::Event::Combat(e) => self.fight(s, e),
                sim::vehicle_combat_world::Event::Cannon {
                    vehicle,
                    from,
                    impact,
                } => self.fx(
                    Self::mask(s, *vehicle),
                    false,
                    json!([5, p(*from), p(*impact), vehicle]),
                ),
                sim::vehicle_combat_world::Event::Service(e) => match e {
                    sim::vehicle_service::ServiceEffect::Reload { soldier, speech } => self.say(
                        s,
                        *soldier,
                        ["Reloading!", "Changing mag!", "Cover me, reloading!"]
                            [usize::from(*speech) % 3],
                    ),
                    sim::vehicle_service::ServiceEffect::Revived { soldier, .. } => {
                        self.say(s, *soldier, "Thanks, doc!")
                    }
                    _ => {}
                },
                sim::vehicle_combat_world::Event::Recoil { .. } => {}
            },
            E::Movement(e) => match e {
                sim::vehicle_movement_world::Event::Loss(e) => self.loss(s, e),
                sim::vehicle_movement_world::Event::Smashed {
                    structure: st,
                    tree_yaw,
                } => {
                    self.fx(
                        3,
                        false,
                        json!([
                            4,
                            p(st.position + Vector3::Y * 0.8),
                            [0.45, 0.4, 0.32, 1.0],
                            8
                        ]),
                    );
                    self.fx(3, false, json!([7, "thud", p(st.position)]));
                    if let Some(yaw) = tree_yaw {
                        self.fx(3, true, json!([10, p(st.position), yaw, st.id, st.variant]));
                    }
                }
                _ => {}
            },
            E::Loss(e) => self.loss(s, e),
            E::Attack(e) => self.attack(s, e),
            E::Delivered {
                team,
                position,
                amount,
            } => self.fx(1u8 << *team, true, json!([11, p(*position), amount, team])),
            E::RoadBlocked {
                team,
                position,
                name,
                ..
            } => self.msg(
                Audience::Team(*team),
                "warn",
                format!("{name}: road blocked."),
                Some(*position),
            ),
            E::Sling { .. } => {}
        }
    }
    fn loss(&mut self, s: &Simulation, e: &sim::vehicle_loss_world::Event) {
        use sim::vehicle_loss_world::Event as E;
        match e {
            E::UnderFire(v) => self.msg(
                Audience::Team(v.team),
                "alert",
                format!("{} is under fire!", v.name),
                Some(v.position),
            ),
            E::Destroyed { vehicle: v, .. } => {
                self.msg(
                    Audience::Team(v.team),
                    "alert",
                    format!("{} destroyed!", v.name),
                    Some(v.position),
                );
                self.fx(
                    3,
                    false,
                    json!([4, p(v.position), [0.25, 0.25, 0.23, 1.0], 12]),
                );
            }
            E::Sunk { vehicle: v, .. } => {
                self.msg(
                    Audience::Team(v.team),
                    "alert",
                    format!("{} is sinking!", v.name),
                    Some(v.position),
                );
                self.fx(3, true, json!([18, v.id, p(v.position)]));
            }
            E::Passenger { id, hit } => self.hit(s, *id, hit),
            E::Squad(e) => self.movement(s, e),
            E::Fire(e) => self.fire(s, e),
            E::Wreck {
                id,
                origin,
                yaw,
                flight: Some(f),
            } => self.properties.push((
                *id,
                Self::mask(s, *id),
                json!({"toss":[p(*origin),yaw,p(f.velocity),p(f.spin)]}),
            )),
            E::Bailout { vehicle: v, .. } => self.msg(
                Audience::Team(v.team),
                "alert",
                format!("{} crew bailed out!", v.name),
                Some(v.position),
            ),
            E::TruckLost {
                vehicle: v,
                destination,
                cargo,
                ..
            } => self.msg(
                Audience::Team(v.team),
                "alert",
                format!("Supply truck to {destination} lost ({cargo} supplies)."),
                Some(v.position),
            ),
            _ => {}
        }
    }
    fn support(&mut self, e: &sim::support_calls::Event) {
        use sim::support_calls::Event as E;
        match e {
            E::Warn { peer, text } => self.msg(Audience::Peer(*peer), "warn", text, None),
            E::Message {
                team,
                alert,
                text,
                position,
            } => self.msg(
                Audience::Team(*team),
                if *alert { "alert" } else { "info" },
                text,
                Some(*position),
            ),
            E::Sound { name, position } => self.fx(3, false, json!([7, name, p(*position)])),
            E::Mark { position, radius } => self.fx(3, false, json!([13, p(*position), radius])),
            E::Born { .. } | E::Stat(_) => {}
        }
    }
    fn movement(&mut self, s: &Simulation, e: &sim::squad_movement::Event) {
        if let sim::squad_movement::Event::Speech {
            soldier,
            call,
            variant,
        } = e
        {
            let text = super::speech::movement(s, *soldier, *call, *variant);
            self.say(s, *soldier, &text);
        }
    }
    fn brain(&mut self, s: &Simulation, e: &sim::squad_brain::Event) {
        use sim::squad_brain::Event as E;
        match e {
            E::Movement(e) => self.movement(s, e),
            E::Speech {
                soldier,
                call,
                variant,
                target,
            } => self.say(
                s,
                *soldier,
                &super::speech::brain(s, *soldier, *call, *variant, *target),
            ),
            E::Message {
                squad,
                message,
                position,
            } => {
                if let Some(q) = s.state.field.squads.iter().find(|q| q.id == *squad) {
                    let suffix = match message {
                        sim::squad_brain::Message::Rout => "is routing!",
                        sim::squad_brain::Message::Rally => "has rallied.",
                        sim::squad_brain::Message::Displace => "is moving out of the shellfire.",
                        sim::squad_brain::Message::Withdraw => "is breaking contact.",
                        sim::squad_brain::Message::NearAmbush => "ambushed - assaulting through!",
                        sim::squad_brain::Message::AmbushSprang => "has sprung the ambush!",
                    };
                    self.msg(
                        Audience::Team(q.team),
                        "alert",
                        format!("Squad {} {suffix}", q.id),
                        Some(*position),
                    );
                }
            }
            E::Surrendered {
                team,
                position,
                drop_direction,
                ..
            } => self.fx(
                1u8 << *team,
                true,
                json!([3, p(*position), p(*drop_direction)]),
            ),
            E::Joined { .. } | E::Stat(_) => {}
        }
    }
    fn attack(&mut self, s: &Simulation, e: &sim::attack_plan::Event) {
        use sim::attack_plan::Event as E;
        match e {
            E::Squad(e) => self.movement(s, e),
            E::Speech { soldier, text } => self.say(s, *soldier, text),
            E::NeedsSupport {
                team,
                squad,
                position,
            } => self.msg(
                Audience::Team(*team),
                "alert",
                format!("Squad {squad} needs support!"),
                Some(*position),
            ),
            E::Stat(_) => {}
        }
    }
    fn building(&mut self, s: &Simulation, e: &sim::structures_tick::Event) {
        use sim::structures_tick::Event as E;
        match e {
            E::Territory(e) => match e {
                sim::structure_world::Event::Combat(e) => self.combat(s, e),
                sim::structure_world::Event::Service(e) => self.service(s, e),
                sim::structure_world::Event::Warning { place, .. } => self.msg(
                    Audience::Team(place.team),
                    "alert",
                    format!("{} is being captured!", place.name),
                    Some(place.position),
                ),
                sim::structure_world::Event::Captured {
                    place, old_team, ..
                } => {
                    self.msg(
                        Audience::Team(place.team),
                        "info",
                        format!("{} captured.", place.name),
                        Some(place.position),
                    );
                    if *old_team >= 0 {
                        self.msg(
                            Audience::Team(*old_team),
                            "alert",
                            format!("{} lost!", place.name),
                            Some(place.position),
                        );
                    }
                }
                _ => {}
            },
            E::Service(e) => self.service(s, e),
            E::Production(e) => match e {
                sim::structure_production::Event::CapWarning { peer, .. } => self.msg(
                    Audience::Peer(*peer),
                    "warn",
                    "Unit cap reached. Build another FOB.",
                    None,
                ),
                sim::structure_production::Event::Research { team, name } => self.msg(
                    Audience::Team(*team),
                    "info",
                    format!("{name} researched."),
                    None,
                ),
                sim::structure_production::Event::Ready { team, name } => self.msg(
                    Audience::Team(*team),
                    "info",
                    format!("{name} ready."),
                    None,
                ),
                sim::structure_production::Event::Movement(e) => self.movement(s, e),
                _ => {}
            },
        }
    }
    fn service(&mut self, s: &Simulation, e: &sim::structure_services::Event) {
        match e {
            sim::structure_services::Event::Reload { soldier, variant } => self.say(
                s,
                *soldier,
                ["Reloading!", "Changing mag!", "Cover me, reloading!"][usize::from(*variant) % 3],
            ),
            sim::structure_services::Event::CacheEmpty { team, position, .. } => self.msg(
                Audience::Team(*team),
                "info",
                "Ammo cache exhausted.",
                Some(*position),
            ),
            _ => {}
        }
    }
    fn rules(&mut self, s: &Simulation, e: &sim::rules_world::Event) {
        use sim::rules_world::Event as E;
        match e {
            E::Support(e) => self.support(e),
            E::Logistics(e) => match e {
                sim::rules_logistics::Event::Movement(e) => self.movement(s, e),
                sim::rules_logistics::Event::Reserves { team, depot, .. } => self.msg(
                    Audience::Team(*team),
                    "info",
                    "Reserve squad has arrived.",
                    Some(*depot),
                ),
                _ => {}
            },
            E::Freed {
                team,
                name,
                position,
                ..
            } => self.msg(
                Audience::Team(*team),
                "info",
                format!("{name} is free!"),
                Some(*position),
            ),
            E::Intelligence(i) => self.msg(
                Audience::Team(i.team),
                "intel",
                format!("{} {}", i.text, i.fact.text),
                i.fact.position,
            ),
            E::Visibility(_) | E::Captor(_) | E::Winner(_) => {}
        }
    }
}
