//! A soldier completes recovery, interruptions, decisions and duty before the next soldier runs.
use crate::bullet_world::Gunfire;
use crate::fires::Fires;
use crate::infantry::Infantry;
use crate::infantry_action_owned::Defense;
use crate::infantry_care_owned;
use crate::infantry_carry_owned::{self, Event as Carry};
use crate::infantry_controller::{Stage, Task};
use crate::infantry_cover::CoverWorld;
use crate::infantry_decision::{self, Speech as Thought};
use crate::infantry_fight_world::{self, Event as Combat, Profile as WeaponProfile};
use crate::infantry_fire::MountedGun;
use crate::infantry_hidden_owned::Event as Hidden;
use crate::infantry_prison_owned::{self, Event as Prison};
use crate::infantry_scan::ScanProfile;
use crate::infantry_travel_owned::{Event as Movement, Transport};
use crate::infantry_update::ActivityContext;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::Weapon;
use crate::perception::PerceptionSearch;
use crate::spatial::SpatialIndex;
use crate::squad::Report;
use crate::structure::Structure;
use crate::supply_network::SupplyNetwork;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::world_combat;
use crate::world_geometry::WorldGeometry;

#[derive(Clone, Copy)]
pub struct Unit<'a> {
    pub bearer: bool,
    pub healing: f64,
    pub building: f64,
    pub weapon: Option<(&'a str, Weapon)>,
}
pub struct Profiles<'a> {
    pub unit: &'a dyn Fn(&Infantry) -> Unit<'a>,
    pub weapon: &'a dyn Fn(&Infantry) -> Option<WeaponProfile<'a>>,
    pub gun: &'a dyn Fn(&Structure) -> Option<MountedGun>,
    pub build_time: &'a dyn Fn(&Structure) -> Option<f64>,
    pub defense: &'a dyn Fn(&Vehicle) -> Defense<'a>,
    pub armor: &'a dyn Fn(&Vehicle) -> Armor,
    pub vehicle_hit: &'a dyn Fn(&Vehicle) -> f64,
    pub transport: &'a dyn Fn(&Vehicle) -> Transport,
}
pub struct Tick<'a> {
    pub search: &'a PerceptionSearch,
    pub gunfire: &'a mut Gunfire,
    pub network: &'a mut SupplyNetwork,
    pub impacts: &'a mut Vec<Report>,
    pub chat: &'a mut [f64; 2],
    pub owned: &'a [u32],
    pub players: &'a [(i32, i8)],
    pub depots: [u32; 2],
    pub medicine: [bool; 2],
    pub optics: [bool; 2],
    pub warheads: [bool; 2],
    pub squad_names: [&'a str; 2],
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Combat(Combat),
    Prison(Prison),
    Removed(u32),
    Died(u32),
    PatchedUp(u32),
    Rejoined {
        soldier: u32,
        result: crate::infantry_rejoin::Rejoined,
    },
}
fn parts<'a>(
    geometry: &'a mut WorldGeometry,
    units: &'a SpatialIndex,
    fires: &'a Fires,
) -> (CoverWorld<'a>, &'a SpatialIndex) {
    (
        CoverWorld {
            terrain: &geometry.terrain,
            nav: &geometry.navigation.planner,
            collision: &mut geometry.collision,
            heat: fires.hot(),
            deck: &geometry.deck,
            units,
            structures: &geometry.structures,
        },
        &geometry.doors,
    )
}
fn speech(id: u32, text: &str, out: &mut Vec<Event>) {
    out.push(Event::Combat(Combat::Speech {
        id,
        text: text.into(),
    }));
}
fn stat(key: &'static str, out: &mut Vec<Event>) {
    out.push(Event::Combat(Combat::World(world_combat::Event::Stat(key))));
}
fn thought(cue: Thought) -> &'static str {
    match cue {
        Thought::Reflex(n) => [
            "GRENADE!",
            "Grenade! Get down!",
            "Frag!",
            "GRENADE! Get back!",
            "Get down! I've got it!",
            "Get away from it!",
            "Incoming!",
            "INCOMING!",
            "Mortars! Get down!",
            "Drone! Drone!",
            "I hear a drone!",
            "FPV inbound!",
        ][n as usize],
        Thought::Scavenge(n) => {
            ["Grabbing ammo.", "Taking his mags.", "He won't need these."][n as usize]
        }
        Thought::Reload(n) => ["Reloading!", "Changing mag!", "Cover me, reloading!"][n as usize],
        Thought::Special(n) => [
            "Rocket out! Backblast clear!",
            "RPG!",
            "Drone up.",
            "Target's out of range!",
            "Rounds out!",
            "Firing for effect!",
            "Hang it!",
        ][n as usize],
        Thought::Cook(n) => ["Cooking one!", "Two... three...", "Hold it, hold it..."][n as usize],
        Thought::Throw(n) => ["Frag out!", "Grenade out!", "Fire in the hole!"][n as usize],
        Thought::Breach(n) => [
            "They're in the house! Stacking on the door!",
            "Enemy inside! I'll frag the room!",
            "Cover me, grenade through the door!",
            "Got one in the building! Moving to the door!",
        ][n as usize],
        Thought::OutOfAmmo => "Out of ammo!",
        Thought::Supply(false) => "Falling back for ammo!",
        Thought::Supply(true) => "Back to the ammo cache!",
    }
}

impl Context<'_> {
    fn infantry_movements(
        &mut self,
        id: u32,
        events: Vec<Movement>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        for event in events {
            self.apply_infantry_movement(id, event)?;
            out.push(Event::Combat(Combat::Movement { id, event }));
        }
        Ok(())
    }
    fn infantry_prison_events(
        &mut self,
        events: Vec<Prison>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        for event in events {
            if let Prison::Movement(id, movement) = event {
                self.infantry_movements(id, vec![movement], out)?;
            } else {
                out.push(Event::Prison(event));
            }
        }
        Ok(())
    }
    fn infantry_revived(
        &mut self,
        id: u32,
        cue: u8,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier(id).ok_or("missing revived infantry")?;
        self.battle
            .add(s.identity.owner, s.identity.team, 23, 1.0)?;
        stat("revived", out);
        speech(
            id,
            [
                "Thanks, doc.",
                "I'm good, I'm good!",
                "Back in the fight.",
                "Ugh... let's go.",
            ][cue as usize],
            out,
        );
        Ok(())
    }
    fn infantry_thought(
        &mut self,
        id: u32,
        profiles: &Profiles<'_>,
        tick: &Tick<'_>,
        out: &mut Vec<Event>,
        phase: &mut impl FnMut(&'static str),
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier(id).unwrap();
        let squad = s.identity.squad;
        let unit = (profiles.unit)(s);
        let weapon = (profiles.weapon)(s);
        let bearer = unit.bearer;
        let scan = self.actors.perceive_infantry(
            id,
            self.now,
            ScanProfile {
                bearer,
                weapon_range: weapon.map_or(0.0, |p| p.bullet.range),
                armor_piercing: weapon.is_some_and(|p| p.piercing),
            },
            self.squads.iter_mut().find(|q| q.id == squad),
            self.units,
            tick.search,
            &mut crate::collision::RayScene {
                boxes: &mut self.geometry.collision,
                ground: crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            },
            self.visibility,
            |v| i32::from((profiles.armor)(v).level),
            self.rng,
        )?;
        if let Some(scan) = scan {
            for _ in 0..scan.reused {
                stat("perception_blocked_reused", out);
            }
        }
        phase("infantry_perception");
        let (mut world, _) = parts(self.geometry, self.units, self.fires);
        let decision = self.actors.think_infantry(
            id,
            self.now,
            infantry_decision::Profile {
                stock: (!self.actors.soldier(id).unwrap().identity.weapon.is_empty())
                    .then_some(unit.weapon)
                    .flatten()
                    .map(|(_, w)| (w.ammunition, w)),
                weapon_range: weapon.map(|p| p.bullet.range),
                weapon_ammunition: weapon.map_or(0, |p| p.fire.weapon.ammunition),
                bearer,
            },
            self.squads.iter_mut().find(|q| q.id == squad),
            &mut world,
            self.visibility,
            tick.owned,
            |v| i32::from((profiles.armor)(v).level),
            |s| (profiles.unit)(s).bearer,
            self.rng,
        )?;
        if decision.cancel_path {
            self.geometry.navigation.planner.cancel(id.into());
        }
        if let Some(route) = decision.route {
            self.apply_infantry_movement(id, Movement::Route(route))?;
        }
        for cue in decision.speech {
            speech(id, thought(cue), out);
        }
        for key in decision.stats {
            stat(key, out);
        }
        phase("infantry_decisions");
        Ok(())
    }

    pub fn advance_infantry(
        &mut self,
        id: u32,
        dt: f64,
        profiles: &Profiles<'_>,
        tick: &mut Tick<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        self.advance_infantry_profiled(id, dt, profiles, tick, &mut |_| {})
    }

    pub fn advance_infantry_profiled(
        &mut self,
        id: u32,
        dt: f64,
        profiles: &Profiles<'_>,
        tick: &mut Tick<'_>,
        phase: &mut impl FnMut(&'static str),
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing infantry update")?;
        let gun = self
            .actors
            .structure(s.emplacement.structure as u32)
            .and_then(profiles.gun);
        if !infantry_fight_world::valid_step(dt, self.now, gun) {
            return Err("invalid infantry tick");
        }
        if self
            .actors
            .soldier_mut(id)
            .unwrap()
            .controller
            .activity_due(dt)?
        {
            let s = self.actors.soldier(id).unwrap();
            let activity = ActivityContext {
                task_target_exists: self.actors.get(s.duty.entity as u32).is_some(),
                mounted_exists: self.actors.get(s.emplacement.structure as u32).is_some(),
                chat_partner_exists: self.actors.get(s.idle.partner as u32).is_some(),
                ambush_target: self
                    .squads
                    .iter()
                    .any(|q| q.id == s.identity.squad && q.ambush)
                    && self.actors.infantry_target_valid(s.fight.target as u32),
            };
            self.actors
                .soldier_mut(id)
                .unwrap()
                .update_activity(activity);
        }
        let s = self.actors.soldier_mut(id).unwrap();
        s.recover(dt, self.now)?;
        let mut out = vec![];
        if s.shock.flinging {
            let (dazed, cue) = s.fling_tick(
                dt,
                &self.geometry.navigation.planner,
                self.rng,
                crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            )?;
            if dazed {
                stat("dazed", &mut out);
            }
            if let Some(cue) = cue {
                speech(
                    id,
                    ["...my ears...", "What... what happened?", "Ugh..."][cue as usize],
                    &mut out,
                );
            }
        } else {
            match s.vitals.life {
                Life::Alive => {
                    let ground =
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck);
                    if ground.too_deep(s.motion.position) {
                        s.motion.position = self
                            .geometry
                            .navigation
                            .planner
                            .nearest_walkable(s.motion.position, ground)
                            .ok_or("invalid swimming recovery")?;
                        s.motion.position.y = ground.height(s.motion.position) as f32;
                        s.motion.ground_until = -1.0;
                    }
                    if ground.depth(s.motion.position) > 0.15 {
                        s.controller.dive_timer = 0.0;
                        s.posture = crate::infantry_pose::Posture::Stand;
                    }
                    let stage = s.alive_stage(dt, self.rng)?;
                    phase("infantry_status");
                    match stage {
                        Stage::Dazed => {
                            let mount = self
                                .actors
                                .mount_turn(self.actors.soldier(id).unwrap(), gun)?;
                            self.actors.soldier_mut(id).unwrap().dazed_tick(
                                dt,
                                mount,
                                &self.geometry.navigation.planner,
                                self.rng,
                                crate::traversal::Ground::new(
                                    &self.geometry.terrain,
                                    &self.geometry.deck,
                                ),
                            )?;
                        }
                        Stage::Dive => self.actors.soldier_mut(id).unwrap().dive_tick(
                            dt,
                            self.now,
                            &self.geometry.navigation.planner,
                            crate::traversal::Ground::new(
                                &self.geometry.terrain,
                                &self.geometry.deck,
                            ),
                        )?,
                        Stage::Action => {
                            let team = self.actors.soldier(id).unwrap().identity.team;
                            let warhead = if team >= 0 && tick.warheads[team as usize] {
                                1.5
                            } else {
                                1.0
                            };
                            out.extend(
                                self.advance_infantry_action(id, warhead, profiles.defense)?
                                    .into_iter()
                                    .map(Event::Combat),
                            );
                        }
                        Stage::Flinch => {}
                        Stage::Think | Stage::Duty => {
                            if stage == Stage::Think {
                                self.infantry_thought(id, profiles, tick, &mut out, phase)?;
                            }
                            let s = self.actors.soldier(id).unwrap();
                            if s.vitals.life == Life::Alive
                                && s.action.remaining <= 0.0
                                && s.controller.dive_timer <= 0.0
                            {
                                self.infantry_duty(id, dt, gun, profiles, tick, &mut out)?;
                                phase("infantry_duties");
                            }
                        }
                    }
                }
                Life::Downed => {
                    let team = s.identity.team;
                    let medicine = team >= 0 && tick.medicine[team as usize];
                    let optics = team >= 0 && tick.optics[team as usize];
                    for event in self.advance_wounded(
                        id,
                        crate::infantry_wounded_world::Input {
                            dt,
                            medicine,
                            optics,
                            gun,
                        },
                        tick.gunfire,
                        tick.network,
                        tick.impacts,
                        profiles.armor,
                        profiles.vehicle_hit,
                    )? {
                        use crate::infantry_wounded_world::Event as Wounded;
                        match event {
                            Wounded::World(e) => out.push(Event::Combat(Combat::World(e))),
                            Wounded::Died(id) => out.push(Event::Died(id)),
                            Wounded::Movement { id, event } => {
                                out.push(Event::Combat(Combat::Movement { id, event }))
                            }
                            Wounded::Cry { id, cue } => speech(
                                id,
                                [
                                    "MEDIC!",
                                    "I'm hit! Medic!",
                                    "Help me!",
                                    "Medic! Over here!",
                                    "Argh! I'm hit!",
                                    "Somebody help!",
                                ][cue as usize],
                                &mut out,
                            ),
                        }
                    }
                }
                Life::Hidden => {
                    let weapon = (profiles.unit)(s).weapon.map(|(key, w)| (key, w.magazine));
                    let result = self.actors.advance_infantry_hidden(
                        id,
                        dt,
                        weapon,
                        &self.geometry.navigation.planner,
                        self.squads,
                        self.rng,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )?;
                    for event in result.events {
                        match event {
                            Hidden::Stat(key) => stat(key, &mut out),
                            Hidden::Revived(cue) => self.infantry_revived(id, cue, &mut out)?,
                            Hidden::Route(route) => {
                                self.infantry_movements(id, vec![Movement::Route(route)], &mut out)?
                            }
                            Hidden::PatchedUp => out.push(Event::PatchedUp(id)),
                        }
                    }
                    if result.removed.is_some() {
                        out.push(Event::Removed(id));
                    }
                }
                Life::Dead | Life::Captive | Life::Surrender => {
                    let (mut world, doors) = parts(self.geometry, self.units, self.fires);
                    let result = self.actors.advance_infantry_inactive(
                        id,
                        dt,
                        self.now,
                        gun,
                        self.squads,
                        &mut world,
                        doors,
                        self.rng,
                    )?;
                    self.infantry_movements(id, result.movement, &mut out)?;
                    self.infantry_prison_events(result.prison, &mut out)?;
                    if result.removed.is_some() {
                        out.push(Event::Removed(id));
                    }
                }
            }
        }
        phase("infantry_status");
        if let Some(s) = self.actors.soldier_mut(id) {
            let ammunition = (profiles.weapon)(s).map(|p| p.fire.weapon.ammunition);
            let leader = self
                .squads
                .iter()
                .any(|q| q.id == s.identity.squad && q.leader == id);
            s.finish_tick(dt, self.now, ammunition, leader)?;
        }
        phase("infantry_finish");
        Ok(out)
    }

    fn infantry_duty(
        &mut self,
        id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        profiles: &Profiles<'_>,
        tick: &mut Tick<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier(id).unwrap();
        let unit = (profiles.unit)(s);
        let weapon = (profiles.weapon)(s);
        let task = s.duty.kind;
        let team = s.identity.team;
        match task {
            Task::Fight | Task::Escort => out.extend(
                self.advance_fighting(
                    id,
                    dt,
                    gun,
                    tick.chat,
                    profiles.weapon,
                    tick.gunfire,
                    tick.network,
                    tick.impacts,
                    profiles.armor,
                    profiles.vehicle_hit,
                )?
                .into_iter()
                .map(Event::Combat),
            ),
            Task::Build => {
                let time = self
                    .actors
                    .structure(s.duty.entity as u32)
                    .and_then(profiles.build_time);
                out.extend(
                    self.advance_build(
                        id,
                        dt,
                        unit.building,
                        time,
                        gun,
                        profiles.weapon,
                        tick.gunfire,
                        tick.network,
                        tick.impacts,
                        profiles.armor,
                        profiles.vehicle_hit,
                    )?
                    .into_iter()
                    .map(Event::Combat),
                );
            }
            Task::Breach => out.extend(
                self.advance_breach(
                    id,
                    dt,
                    gun,
                    profiles.weapon,
                    tick.gunfire,
                    tick.network,
                    tick.impacts,
                    profiles.armor,
                    profiles.vehicle_hit,
                )?
                .into_iter()
                .map(Event::Combat),
            ),
            Task::Man => out.extend(
                self.advance_mount(
                    id,
                    dt,
                    gun,
                    tick.owned,
                    profiles.weapon,
                    profiles.defense,
                    tick.gunfire,
                    tick.network,
                    tick.impacts,
                    profiles.armor,
                    profiles.vehicle_hit,
                )?
                .into_iter()
                .map(Event::Combat),
            ),
            Task::Rescue | Task::Heal | Task::Limp => {
                let restored = self
                    .actors
                    .soldier(s.duty.entity as u32)
                    .and_then(|s| (profiles.unit)(s).weapon)
                    .map(|(key, w)| (key, w.magazine));
                let (mut world, doors) = parts(self.geometry, self.units, self.fires);
                let result = self.actors.advance_infantry_care(
                    id,
                    dt,
                    self.now,
                    infantry_care_owned::Profile {
                        heal_rate: unit.healing,
                        medicine_upgrade: team >= 0 && tick.medicine[team as usize],
                        weapon_range: weapon.map_or(0.0, |p| p.bullet.range),
                        unarmed: weapon.is_none(),
                        gun,
                        restored_weapon: restored,
                    },
                    self.squads,
                    &mut world,
                    doors,
                    self.rng,
                )?;
                self.infantry_movements(id, result.movement, out)?;
                if let Some(cue) = result.drag_speech {
                    speech(
                        id,
                        [
                            "I've got you!",
                            "Hang on, I've got you!",
                            "Grab on!",
                            "Moving him!",
                        ][cue as usize],
                        out,
                    );
                }
                if let Some((who, cue)) = result.revived {
                    self.infantry_revived(who, cue, out)?;
                    stat("patched_up", out);
                }
                if result.rejoin {
                    let joined = self.actors.rejoin_infantry(
                        id,
                        self.now,
                        tick.players,
                        self.squads,
                        self.next_squad,
                        self.battle,
                        tick.squad_names[usize::from(team == 1)],
                    )?;
                    if let Some(route) = joined.route {
                        self.apply_infantry_movement(id, Movement::Route(route))?;
                    }
                    out.push(Event::Rejoined {
                        soldier: id,
                        result: joined,
                    });
                }
            }
            Task::Stretcher => {
                let (mut world, doors) = parts(self.geometry, self.units, self.fires);
                for event in self.actors.advance_infantry_stretcher(
                    id,
                    dt,
                    self.now,
                    gun,
                    self.squads,
                    &mut world,
                    doors,
                    self.rng,
                )? {
                    match event {
                        Carry::Movement(who, event) => {
                            self.infantry_movements(who, vec![event], out)?
                        }
                        Carry::Speech(who, cue) => speech(
                            who,
                            match cue {
                                infantry_carry_owned::Speech::Lift => "Lift on three!",
                                infantry_carry_owned::Speech::Solo => "I've got him!",
                                infantry_carry_owned::Speech::BearerDown => {
                                    "Bearer down! I'll drag him!"
                                }
                            },
                            out,
                        ),
                        Carry::IntoTent { .. } => stat("into_tent", out),
                    }
                }
            }
            Task::Captor => {
                let value = self
                    .actors
                    .soldier(s.duty.entity as u32)
                    .map_or(0.0, |p| (self.man)(p, self.squads).value);
                let (mut world, doors) = parts(self.geometry, self.units, self.fires);
                let events = self.actors.advance_infantry_captor(
                    id,
                    dt,
                    self.now,
                    infantry_prison_owned::Profile {
                        value,
                        fallback_depot: tick.depots[usize::from(team == 1)],
                        gun,
                    },
                    self.battle,
                    self.squads,
                    &mut world,
                    doors,
                    self.rng,
                )?;
                self.infantry_prison_events(events, out)?;
            }
            Task::Retreat
            | Task::Throw
            | Task::Board
            | Task::Tunnel
            | Task::Pilot
            | Task::Resupply => {
                let (mut world, doors) = parts(self.geometry, self.units, self.fires);
                let stock = (!s.identity.weapon.is_empty())
                    .then_some(unit.weapon)
                    .flatten()
                    .map(|(_, w)| w.ammunition);
                let events = self.actors.advance_infantry_travel(
                    id,
                    dt,
                    self.now,
                    stock,
                    gun,
                    profiles.transport,
                    self.squads,
                    &mut world,
                    doors,
                    self.rng,
                )?;
                self.infantry_movements(id, events, out)?;
            }
            Task::GrenadePickup | Task::GrenadeKick | Task::Smother => {
                let result = self.actors.advance_infantry_grenade_task(
                    id,
                    dt,
                    self.now,
                    gun,
                    self.units,
                    &self.geometry.navigation.planner,
                    self.rng,
                )?;
                if result.cancel_path {
                    self.geometry.navigation.planner.cancel(id.into());
                }
                if result.dived {
                    stat("dive", out);
                }
            }
            Task::Unknown => self.actors.soldier_mut(id).unwrap().duty.kind = Task::Fight,
        }
        Ok(())
    }
}
