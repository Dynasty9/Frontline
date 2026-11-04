use crate::simulation::Simulation;
use frontline_core::{squad_brain, squad_movement, vector::Vector3};

fn pick(lines: &[&str], variant: u8) -> String {
    lines[usize::from(variant) % lines.len()].into()
}
fn side(s: &Simulation, id: u32) -> i8 {
    s.state
        .field
        .actors
        .soldier(id)
        .map_or(-1, |m| m.identity.team)
}
pub(super) fn movement(s: &Simulation, id: u32, call: squad_movement::Call, v: u8) -> String {
    use squad_movement::Call::*;
    let regular = side(s, id) == 0;
    let lines: &[&str] = match call {
        Leader if regular => &[
            "Sarge is down, I've got command!",
            "On me! I'm taking the squad!",
            "I've got it, form on me!",
        ],
        Leader => &[
            "I lead now! Follow me!",
            "Brothers, on me!",
            "I'm in command!",
        ],
        Move => &[
            "Moving!",
            "Move up!",
            "On me!",
            "Let's go!",
            "Copy, moving.",
        ],
        Bound if regular => &[
            "Bounding overwatch! Alpha moving, Bravo cover!",
            "By teams - bound! Watch your sectors!",
            "Alpha go, Bravo cover!",
            "Leapfrog it up, one team covering!",
        ],
        Bound => &[
            "Half of you cover, half move! Go!",
            "Move in pairs, cover each other!",
            "You go, we cover! Then us!",
        ],
        Moving => &["Moving!", "Going!", "On the move!", "Bounding!"],
        Set => &["Set!", "Set! Move up!", "In position, go!", "Covering!"],
        Recon if regular => &[
            "Recon by fire!",
            "Putting rounds in that treeline!",
            "Spraying it - see if they bite!",
            "Rounds into that house!",
        ],
        Recon => &["Shoot it up, see who's there!", "Fire into it!"],
        Defend => &[
            "Dig in here!",
            "Hold this line!",
            "Find cover, watch your front!",
            "We hold here.",
            "Nobody gets past us.",
        ],
        Assault => &[
            "Advance! Bounding, by teams!",
            "Move up, cover to cover!",
            "Let's push! Watch your sectors!",
            "Go, go! I'll cover!",
        ],
        AssaultBound => &["Moving!", "Covering!", "Set! Move up!", "Go!"],
        Pinned => &[
            "We're pinned!",
            "Can't move, too much fire!",
            "Hold here, return fire!",
        ],
        Attack => &["Engaging!", "Target spotted, moving in!", "Light 'em up!"],
        Work => &["On it.", "Get building!", "Let's get this up."],
        Board => &["Mount up!", "Everybody in!", "Load up, let's go!"],
        Bunker => &["Into the bunker!", "Get inside!", "Man the slits!"],
        FireMission => &["Fire mission, HE. Copy!", "Fire mission, smoke. Copy!"],
        Individual => &[
            "On it.",
            "Moving.",
            "Copy that.",
            "Roger.",
            "Got it.",
            "Going.",
        ],
        OutOfAmmo => &["Out of ammo!"],
    };
    pick(lines, v)
}
pub(super) fn brain(
    s: &Simulation,
    id: u32,
    call: squad_brain::Call,
    v: u8,
    target: Option<Vector3>,
) -> String {
    use squad_brain::Call::*;
    let regular = side(s, id) == 0;
    if call == Contact {
        if let (Some(m), Some(p)) = (s.state.field.actors.soldier(id), target) {
            let d = p - m.motion.position;
            let distance = ((f64::from(Vector3::new(d.x, 0., d.z).length()) / 25.).round() * 25.)
                .max(25.) as i64;
            let angle = f64::from(d.x).atan2(f64::from(-d.z));
            let index = (angle / std::f64::consts::FRAC_PI_4).round() as i32;
            let direction = [
                "north",
                "north-east",
                "east",
                "south-east",
                "south",
                "south-west",
                "west",
                "north-west",
            ][index.rem_euclid(8) as usize];
            return match v % 3 {
                0 => format!("Contact! {direction}, {distance} metres!"),
                1 => format!("Contact {direction}! {distance} metres, return fire!"),
                _ => format!("Enemy {direction}, {distance} metres! Get down!"),
            };
        }
    }
    let lines: &[&str] = match call {
        Retreat => &["Fall back! Fall back!"],
        Rout => &[
            "Run! Get out of here!",
            "We can't hold! Go, go!",
            "Leave it! Run!",
            "Fall back! Fall back!",
        ],
        Rally => &[
            "Alright... alright. On me, form up!",
            "Get a grip! Form on me!",
            "Enough running. We hold here.",
        ],
        Displace => &[
            "Incoming! Out of the impact area, move!",
            "They've got us zeroed! Move, move!",
            "Arty! Get out of here, go!",
            "Shells! Move it, move it!",
        ],
        BackToLine => &["It's lifted. Back to the line!", "Back to your positions!"],
        Withdraw => &[
            "Break contact! Smoke out, fall back by teams!",
            "Pull back! Bounding back, go!",
            "Too many of them! Fall back, covering fire!",
        ],
        WithdrawDone => &[
            "We're clear! Count off, check your ammo!",
            "Hold here! Reload, watch your front!",
            "Alright, we're out. Get your breath.",
        ],
        NearAmbush if regular => &[
            "Near ambush! Assault through! Go, go, go!",
            "Ambush! Into them, move!",
            "Get out of the kill zone - assault!",
        ],
        NearAmbush => &["Ambush! At them!", "Charge them! Go!"],
        Contact => &["Contact!"],
        Ambush | AmbushSpring if regular => {
            &["FIRE!", "Now! Open fire!", "Hit them!", "Light them up!"]
        }
        Ambush => &["NOW! Fire!", "Kill them!", "Fire, fire!"],
        AmbushSpring => &["NOW! Kill them!", "Allahu akbar! Fire!", "Fire, fire!"],
        NeedAmmo => &[
            "Ammo! Throw me a mag!",
            "I'm low! Mags!",
            "Anyone got a mag?",
        ],
        GiveAmmo => &["Here, catch!", "Mag! Make it count!", "Take these."],
        Reload => &["Reloading!", "Changing mag!", "Cover me, reloading!"],
        Clear => &[
            "Clearing that house!",
            "I'll take the door - on me!",
            "Stack up, we clear it!",
            "Checking the building!",
        ],
        CoverRescue => &[
            "Covering fire!",
            "Suppress them!",
            "Lay it down, get him out!",
        ],
        Straggler if regular => &[
            "I'm all that's left! I'm with you!",
            "They got my whole squad... I'm with you guys.",
            "Mind if I tag along?",
        ],
        Straggler => &[
            "My brothers are dead! I fight with you!",
            "I'm with you now!",
        ],
        Welcome => &[
            "Get in here! Take the left.",
            "On me. Watch our flank.",
            "Good to have you.",
        ],
        ClearDone if regular => &[
            "Clear!",
            "Room clear!",
            "Clear! Next room!",
            "Building clear!",
        ],
        ClearDone => &["Empty!", "Nobody here!", "Clear!"],
        Surrender => &[
            "Don't shoot! I surrender!",
            "I give up! I give up!",
            "Okay! Okay! Don't shoot!",
        ],
        AmbushSetOut if regular => &[
            "We hit them on the road. Move quiet.",
            "Ambush on the road - nobody fires till I do.",
            "Into the ambush position. Silence from here.",
        ],
        AmbushSetOut => &[
            "We wait for them by the road. Quiet now.",
            "We'll hit them on the road. Follow me.",
        ],
        AmbushWithdraw if regular => &[
            "Cease fire! Pull back to the rally point!",
            "That's it - break contact, go!",
            "Done! Smoke, back by teams!",
        ],
        AmbushWithdraw => &[
            "Enough! Go, go - scatter!",
            "Back! Back to the rally point!",
            "Melt away! Go!",
        ],
    };
    pick(lines, v)
}
