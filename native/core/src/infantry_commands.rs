//! Squad orders change retained infantry state; shared claims are released by the world.
use crate::infantry::{Goal, Infantry};
use crate::infantry_action::Round;
use crate::infantry_controller::Task;
use crate::infantry_orders::RouteOrder;
use crate::path_planner::PathPlanner;
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug)]
pub enum Command {
    Move {
        slot: Vector3,
        mode: u8,
        face: Vector3,
    },
    Halt {
        face: Vector3,
    },
    Follow {
        position: Vector3,
        mode: u8,
        face: Vector3,
    },
    Attack {
        target: u32,
        position: Vector3,
        slot: Vector3,
    },
    Retreat {
        position: Vector3,
    },
    Throw {
        position: Vector3,
        round: Round,
    },
    Stop,
    ReturnToHold,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Release {
    Rescue(u32),
    Breach(u32),
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Ordered {
    pub accepted: bool,
    pub release: Option<Release>,
    pub cancel_path: bool,
    pub route: Option<RouteOrder>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Command {
    fn valid(self) -> bool {
        match self {
            Self::Move { slot, mode, face } => point(slot) && mode <= 2 && point(face),
            Self::Halt { face } => point(face),
            Self::Follow {
                position,
                mode,
                face,
            } => point(position) && mode <= 2 && point(face),
            Self::Attack {
                target,
                position,
                slot,
            } => target != 0 && point(position) && point(slot),
            Self::Retreat { position } => point(position),
            Self::Throw { position, round } => point(position) && round != Round::HighExplosive,
            Self::Stop | Self::ReturnToHold => true,
        }
    }
}

impl Infantry {
    pub fn command(
        &mut self,
        order: Command,
        nav: &PathPlanner,
        mount_position: Option<Vector3>,
    ) -> Result<Ordered, &'static str> {
        if !self.valid()
            || !order.valid()
            || mount_position.is_some_and(|p| !point(p) || !point(p + Vector3::X * 2.0))
        {
            return Err("invalid infantry command");
        }
        let allowed = match order {
            Command::ReturnToHold => true,
            Command::Retreat { .. } => self.duty.kind.can_retreat(self.vitals.life),
            Command::Halt { .. } | Command::Follow { .. } => {
                self.duty.kind == Task::Fight
                    && self
                        .duty
                        .kind
                        .can_take_orders(self.vitals.life, self.duty.phase)
            }
            _ => self
                .duty
                .kind
                .can_take_orders(self.vitals.life, self.duty.phase),
        };
        if !allowed {
            return Ok(Ordered::default());
        }
        if self.orders.path_revision == i64::MAX as u64 {
            return Err("infantry path revision exhausted");
        }
        let mut out = Ordered {
            accepted: true,
            ..Default::default()
        };
        match order {
            Command::Move { slot, mode, face } => {
                if self.duty.kind == Task::Breach && self.duty.phase >= 1 {
                    self.orders.hold_position = slot;
                    self.hold_face(face);
                    self.orders.leash = 9.0;
                    self.entry.reordered = true;
                    return Ok(out);
                }
                out.release = self.clear_duty(nav, mount_position);
                self.orders.hold_position = slot;
                self.hold_face(face);
                self.orders.leash = 9.0;
                self.cover.at_cover = false;
                self.cover.kind = 0;
                self.clear_cover();
                self.weapon.peek_up = false;
                self.fight.forced_target = 0;
                out.route = Some(self.go_to(slot, Goal::Slot, mode)?);
            }
            Command::Halt { face } => {
                self.stop_moving()?;
                out.cancel_path = true;
                self.orders.hold_position = nav.nearest_walkable(self.motion.position).unwrap();
                self.hold_face(face);
                self.orders.leash = 8.0;
                self.cover.at_cover = false;
                self.cover.kind = 0;
                self.clear_cover();
                self.weapon.peek_up = false;
                self.cover.evaluate_at = 0.0;
            }
            Command::Follow {
                position,
                mode,
                face,
            } => {
                self.orders.hold_position = position;
                self.orders.hold_face = face;
                self.cover.at_cover = false;
                if self.is_moving() && f64::from(flat(self.orders.goal - position).length()) < 3.0 {
                    self.orders.move_mode = mode;
                } else {
                    out.route = Some(self.go_to(position, Goal::Slot, mode)?);
                }
            }
            Command::Attack {
                target,
                position,
                slot,
            } => {
                out.release = self.clear_duty(nav, mount_position);
                self.fight.forced_target = u64::from(target);
                self.orders.hold_position = slot;
                self.orders.hold_face = normalized(flat(position - slot));
                self.orders.leash = 10.0;
                self.cover.at_cover = false;
                out.route = Some(self.go_to(slot, Goal::Slot, 0)?);
            }
            Command::Retreat { position } => {
                out.release = self.clear_duty(nav, mount_position);
                self.duty.kind = Task::Retreat;
                self.fight.forced_target = 0;
                self.orders.hold_position = position;
                self.cover.at_cover = false;
                out.route = Some(self.go_to(position, Goal::Task, 2)?);
            }
            Command::Throw { position, round } => {
                out.release = self.clear_duty(nav, mount_position);
                self.duty.kind = Task::Throw;
                self.duty.position = position;
                self.duty.throw_kind = round;
                let direction = flat(position - self.motion.position);
                let distance = f64::from(direction.length());
                if distance > 24.0 {
                    out.route = Some(self.go_to(
                        self.motion.position + normalized(direction) * (distance - 22.0) as f32,
                        Goal::Task,
                        1,
                    )?);
                }
            }
            Command::Stop => {
                out.release = self.clear_duty(nav, mount_position);
                self.fight.forced_target = 0;
                self.stop_moving()?;
                out.cancel_path = true;
                self.orders.hold_position = self.motion.position;
                self.cover.at_cover = false;
                self.cover.evaluate_at = 0.0;
            }
            Command::ReturnToHold => {
                self.duty.kind = Task::Fight;
                self.duty.entity = 0;
                self.duty.partner = 0;
                self.orders.backwards = false;
                self.cover.at_cover = false;
                self.cover.evaluate_at = 0.0;
                if f64::from(flat(self.motion.position - self.orders.hold_position).length())
                    > self.orders.leash
                {
                    out.route = Some(self.go_to(self.orders.hold_position, Goal::Slot, 1)?);
                }
            }
        }
        Ok(out)
    }

    fn hold_face(&mut self, face: Vector3) {
        if f64::from(face.length()) > 0.1 {
            self.orders.hold_face = face;
        }
    }

    fn clear_duty(
        &mut self,
        nav: &PathPlanner,
        mount_position: Option<Vector3>,
    ) -> Option<Release> {
        let release = match self.duty.kind {
            Task::Rescue if self.duty.entity != 0 => Some(Release::Rescue(self.duty.entity as u32)),
            Task::Breach if self.identity.squad != 0 => Some(Release::Breach(self.identity.squad)),
            Task::Man if self.emplacement.structure != 0 => {
                self.emplacement.mortar_aim = None;
                self.emplacement.target = 0;
                self.emplacement.scan_timer = 0.0;
                self.emplacement.structure = 0;
                self.identity.mounted_weapon.clear();
                if self.orders.base_y > 0.0 {
                    if let Some(position) = mount_position {
                        self.motion.position =
                            nav.nearest_walkable(position + Vector3::X * 2.0).unwrap();
                    }
                }
                self.orders.base_y = 0.0;
                self.motion.position.y = 0.0;
                self.duty.kind = Task::Fight;
                self.duty.entity = 0;
                self.cover.at_cover = false;
                self.cover.kind = 0;
                self.clear_cover();
                self.cover.evaluate_at = 0.0;
                return None;
            }
            _ => None,
        };
        self.duty.kind = Task::Fight;
        self.duty.entity = 0;
        self.duty.partner = 0;
        self.orders.backwards = false;
        release
    }
}
