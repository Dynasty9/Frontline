use super::*;
use serde_json::{json, Value};

impl Goal {
    fn key(self) -> &'static str {
        match self {
            Self::Reach => "reach",
            Self::Clear => "clear",
            Self::Hold => "hold",
            Self::Guard => "guard",
            Self::Destroy => "destroy",
            Self::Protect => "protect",
            Self::Timer => "timer",
            Self::Deliver => "deliver",
            Self::Extract => "extract",
        }
    }
}
impl Objective {
    fn progress_text(&self) -> String {
        match self.goal {
            Goal::Hold | Goal::Timer => {
                let left = (self.seconds - self.progress).max(0.) as u64;
                let mut text = format!("{}:{:02}", left / 60, left % 60);
                if self.goal == Goal::Hold && self.state == 1 && self.have > 0 {
                    text.push_str("  contested");
                }
                text
            }
            Goal::Destroy => {
                let need = if self.need > 0 {
                    self.need
                } else {
                    self.entities.len() as i32
                };
                format!("{}/{}", self.have.min(need), need)
            }
            Goal::Extract => format!("{}/{}", self.have, self.need.max(1)),
            Goal::Clear if self.state == 1 && (1..=4).contains(&self.have) => {
                format!("{} left", self.have)
            }
            Goal::Guard if self.state == 1 && self.have > 0 => "contested".into(),
            _ => String::new(),
        }
    }
}
impl Mission {
    /// Presentation only: observation filtering decides which peers receive this briefing.
    pub fn info(&self, state: &MatchState, content: &Content) -> Value {
        let definition = content.definitions["missions"]
            .as_array()
            .and_then(|missions| missions.iter().find(|m| m["key"] == self.kind.key()));
        let lost = |ids: &BTreeSet<u32>| {
            ids.iter()
                .filter(|&&id| match state.field.actors.get(id) {
                    Some(Actor::Soldier(s)) => {
                        matches!(s.vitals.life, Life::Dead | Life::Surrender | Life::Captive)
                    }
                    _ => true,
                })
                .count()
        };
        let objectives: Vec<_> = self
            .objectives
            .iter()
            .filter(|o| o.state != 0)
            .map(|o| {
                let position = if o.mark {
                    o.position.map(|p| p.to_array())
                } else {
                    None
                };
                json!([
                    o.label,
                    o.text,
                    o.state,
                    o.goal.key(),
                    position,
                    o.radius,
                    o.progress_text(),
                    o.optional
                ])
            })
            .collect();
        json!({
            "key": self.kind.key(),
            "title": definition.and_then(|d| d["title"].as_str()).unwrap_or(self.kind.key()),
            "op": definition.and_then(|d| d["op"].as_str()).unwrap_or(""),
            "side": self.side, "over": self.over, "end": self.end_text,
            "el": state.field.now - self.start_time,
            "left": if self.deadline > 0. { self.deadline - state.field.now } else { -1. },
            "objs": objectives, "sup": self.support,
            "focus": self.focus.to_array(), "fyaw": self.focus_yaw,
            "lost": [lost(&self.ours), self.ours.len()], "kills": lost(&self.theirs)
        })
    }
}
