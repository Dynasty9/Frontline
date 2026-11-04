use super::*;

fn scene(c: &Content) -> MatchState {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 4096];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side: 64,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.victory.mission = true;
    for team in 0..2 {
        state
            .field
            .actors
            .spawn_infantry(
                sim::infantry_spawn::Spawn {
                    team,
                    owner: -1 - i32::from(team),
                    position: Vector3::X * (team as f32 * 20.),
                    yaw: 0.,
                    name: "Test".into(),
                    squad: 0,
                    life: Life::Alive,
                    posture: sim::infantry_pose::Posture::Stand,
                    armor_upgrade: false,
                    grenade_upgrade: false,
                },
                &c.loadouts["rifleman"],
                &mut state.field.rng,
            )
            .unwrap();
    }
    state
        .field
        .geometry
        .spawn_vehicle(
            &mut state.field.actors,
            sim::vehicle_birth::Spawn {
                team: 0,
                owner: -1,
                position: Vector3::ZERO,
                yaw: 0.,
            },
            c.vehicle_birth("hunter_hmg").unwrap(),
        )
        .unwrap();
    state
}
fn edit(state: &mut MatchState, id: u32, mut f: impl FnMut(&mut Actor)) {
    state.field.actors = sim::actors::Actors::from_entries(
        state.field.actors.entities().next_id(),
        state
            .field
            .actors
            .iter()
            .cloned()
            .map(|mut a| {
                if a.identity().id == id {
                    f(&mut a);
                }
                a
            })
            .collect(),
    )
    .unwrap();
}
fn evaluate(m: &mut Mission, s: &mut MatchState, c: &Content) {
    c.with_profiles(&[], |p, profiles| {
        m.evaluate(&mut Context {
            state: s,
            content: c,
            shared: &p.shared,
            profiles,
            host: 7,
            events: &mut vec![],
        })
    })
    .unwrap();
}
fn objective(goal: Goal) -> Objective {
    let mut o = Objective::new("goal", "Test objective", goal, Some(Vector3::ZERO), 5.);
    o.state = 1;
    o
}

#[test]
fn convoy_approach_avoids_disconnected_ground_and_keeps_its_distance() {
    let c = Content::bundled().unwrap();
    let mut s = scene(&c);
    let nav = &mut s.field.geometry.navigation;
    for z in 0..64 {
        assert!(nav.planner.set_cell(z * 64 + 11, 0, 3, 0));
        assert!(nav.vehicles.set_cell([11, z as i32], true, 1.));
    }
    assert!(nav.finalize(1));
    c.with_profiles(&[], |p, profiles| {
        let mut events = vec![];
        let mut w = Context {
            state: &mut s,
            content: &c,
            shared: &p.shared,
            profiles,
            host: 7,
            events: &mut events,
        };
        let from = Vector3::new(-27., 0., -27.);
        let to = Vector3::new(27., 0., 27.);
        let spawn = w.vehicle_approach(from, to).unwrap();
        assert!(spawn.x > -20. && distance(spawn, to) >= 60.);
        assert_eq!(w.vehicle_approach(spawn, to).unwrap(), spawn);
        assert!(w.vehicle_approach(to - Vector3::X * 40., to).is_err());
    });
}

#[test]
fn hud_keeps_briefings_hidden_objectives_and_casualties_consistent() {
    let c = Content::bundled().unwrap();
    let mut s = scene(&c);
    let mut m = Mission::new(Kind::Bridgehead, &s, false);
    m.census(&s);
    let mut hold = objective(Goal::Hold);
    hold.seconds = 120.;
    hold.progress = 59.;
    hold.have = 1;
    hold.label = "A".into();
    m.objectives.push(hold);
    let mut hidden = objective(Goal::Destroy);
    hidden.state = 0;
    m.objectives.push(hidden);
    edit(&mut s, 1, |a| {
        if let Actor::Soldier(s) = a {
            s.vitals.life = Life::Downed;
        }
    });
    edit(&mut s, 2, |a| {
        if let Actor::Soldier(s) = a {
            s.vitals.life = Life::Captive;
        }
    });
    let info = m.info(&s, &c);
    assert_eq!(info["title"], "Bridgehead");
    assert_eq!(info["op"], "Operation Broken Crossing");
    assert_eq!(info["objs"].as_array().unwrap().len(), 1);
    assert_eq!(info["objs"][0][6], "1:01  contested");
    assert_eq!(info["lost"], serde_json::json!([0, 1]));
    assert_eq!(info["kills"], 1);
    m.objectives[0].mark = false;
    assert!(m.info(&s, &c)["objs"][0][4].is_null());
}

#[test]
fn all_objective_kinds_check_live_force_position_and_progress() {
    let c = Content::bundled().unwrap();
    for goal in [
        Goal::Reach,
        Goal::Clear,
        Goal::Hold,
        Goal::Guard,
        Goal::Destroy,
        Goal::Protect,
        Goal::Timer,
        Goal::Deliver,
        Goal::Extract,
    ] {
        let mut s = scene(&c);
        let mut m = Mission::new(Kind::Bridgehead, &s, false);
        let mut o = objective(goal);
        o.seconds = 0.5;
        if matches!(goal, Goal::Destroy | Goal::Protect) {
            o.entities = vec![2];
        }
        if goal == Goal::Destroy {
            edit(&mut s, 2, |a| {
                if let Actor::Soldier(s) = a {
                    s.vitals.life = Life::Dead;
                }
            });
        }
        if goal == Goal::Deliver {
            o.entities = vec![3];
        }
        m.objectives.push(o);
        evaluate(&mut m, &mut s, &c);
        assert_eq!(
            m.objectives[0].state,
            if matches!(goal, Goal::Guard | Goal::Protect) {
                1
            } else {
                2
            },
            "{goal:?}"
        );
        assert_eq!(m.over, 0);
    }
}

#[test]
fn passengers_do_not_take_ground_and_slung_vehicles_do_not_complete_delivery() {
    let c = Content::bundled().unwrap();
    let mut s = scene(&c);
    s.field.actors.board(3, 1, 8, false, 0.).unwrap();
    let mut m = Mission::new(Kind::Bridgehead, &s, false);
    let mut o = objective(Goal::Reach);
    o.afoot = true;
    m.objectives.push(o);
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 1);
    m.objectives[0].afoot = false;
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 2);
    m.objectives = vec![objective(Goal::Deliver)];
    m.objectives[0].entities = vec![3];
    edit(&mut s, 3, |a| {
        if let Actor::Vehicle(v) = a {
            v.slung_by = 99;
        }
    });
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 1);
    edit(&mut s, 3, |a| {
        if let Actor::Vehicle(v) = a {
            v.slung_by = 0;
            v.position.y = 2.;
        }
    });
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 1);
    edit(&mut s, 3, |a| {
        if let Actor::Vehicle(v) = a {
            v.position.y = 0.;
        }
    });
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 2);
}

#[test]
fn contested_holds_optional_losses_deadlines_and_force_losses_preserve_mission_rules() {
    let c = Content::bundled().unwrap();
    let mut s = scene(&c);
    let mut m = Mission::new(Kind::Bridgehead, &s, false);
    let mut o = objective(Goal::Hold);
    o.seconds = 0.5;
    o.grace = 1.;
    m.objectives.push(o);
    edit(&mut s, 2, |a| {
        if let Actor::Soldier(s) = a {
            s.motion.position = Vector3::ZERO;
        }
    });
    // Two friendly units can finish while outnumbering one attacker.
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 2);
    m.objectives[0].state = 1;
    m.objectives[0].progress = 0.;
    for id in [1, 3] {
        edit(&mut s, id, |a| match a {
            Actor::Soldier(s) => s.motion.position = Vector3::X * 20.,
            Actor::Vehicle(v) => v.position = Vector3::X * 20.,
            _ => {}
        });
    }
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 1);
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.over, 2);
    assert_eq!(s.victory.winner, 1);
    let mut s = scene(&c);
    let mut m = Mission::new(Kind::Bridgehead, &s, false);
    let mut o = objective(Goal::Protect);
    o.optional = true;
    o.entities = vec![2];
    m.objectives.push(o);
    edit(&mut s, 2, |a| {
        if let Actor::Soldier(s) = a {
            s.vitals.life = Life::Dead;
        }
    });
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.objectives[0].state, 3);
    assert_eq!(m.over, 0);
    m.deadline = 1.;
    s.field.now = 1.;
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.over, 2);
    let mut s = scene(&c);
    let mut m = Mission::new(Kind::Bridgehead, &s, false);
    edit(&mut s, 1, |a| {
        if let Actor::Soldier(s) = a {
            s.vitals.life = Life::Downed;
        }
    });
    s.field.now = 6.;
    evaluate(&mut m, &mut s, &c);
    assert_eq!(m.end_text, "Your force has been wiped out.");
}
