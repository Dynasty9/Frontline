use frontline_core as sim;
use frontline_server::{
    content::Content,
    observation::{self, View},
    simulation::Simulation,
};
use sim::{
    actors::{Actor, Actors},
    infantry::Infantry,
    structure::Structure,
    vector::Vector3,
};

fn map(c: &Content, actors: Vec<Actor>) -> Simulation {
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
    let mut state = sim::match_state::MatchState::empty(geometry, water, boats, 1, false).unwrap();
    state.scenario = true;
    state.field.actors = Actors::from_entries(1000, actors).unwrap();
    Simulation::new(state, 7, c).unwrap()
}
fn soldier(id: u32, side: i8) -> Actor {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = side;
    s.identity.owner = 7 + i32::from(side);
    s.identity.unit = "rifleman".into();
    s.identity.name = format!("Soldier {id}");
    s.motion.position = Vector3::new(id as f32, 0., 2.);
    Actor::Soldier(Box::new(s))
}
fn replace(s: &mut Simulation, edit: impl Fn(&mut Actor)) {
    let mut actors: Vec<_> = s.state.field.actors.iter().cloned().collect();
    for a in &mut actors {
        edit(a);
    }
    s.state.field.actors = Actors::from_entries(1000, actors).unwrap();
}
fn records(packets: &[Vec<u8>]) -> Vec<(u32, Vec<u8>)> {
    let mut out = vec![];
    for packet in packets {
        assert!(packet.len() <= 1100);
        let mut b = &packet[4..];
        while !b.is_empty() {
            let id = u32::from_le_bytes(b[..4].try_into().unwrap());
            let len = b[4] as usize;
            out.push((id, b[5..5 + len].to_vec()));
            b = &b[5 + len..];
        }
    }
    out
}

#[test]
#[ignore = "manual observation scale measurement"]
fn observation_scale() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![]);
    for i in 0..14_000 {
        s.state
            .field
            .actors
            .spawn(Actor::Structure(Box::new(Structure {
                kind: "house_wall".into(),
                position: Vector3::new((i % 128) as f32, 0., (i / 128) as f32),
                ..Default::default()
            })))
            .unwrap();
    }
    for i in 0..500 {
        s.state
            .field
            .actors
            .spawn(soldier(i, (i % 2) as i8))
            .unwrap();
    }
    let checkpoint = s.checkpoint().unwrap();
    let mut view = View::new(-1).unwrap();
    assert_eq!(view.update(&s, &c).births.len(), 14_500);
    let mut times = vec![];
    let mut rows = 0;
    for _ in 0..180 {
        let started = std::time::Instant::now();
        let update = view.update(&s, &c);
        times.push(started.elapsed().as_secs_f64() * 1000.);
        assert!(
            update.births.is_empty() && update.despawns.is_empty() && update.properties.is_empty()
        );
        rows += records(&update.snapshots).len();
    }
    assert!(
        rows > 180 * 500,
        "Stationary scenery still needs recovery refreshes"
    );
    assert_eq!(checkpoint, s.checkpoint().unwrap());
    let mean = times.iter().sum::<f64>() / times.len() as f64;
    times.sort_by(f64::total_cmp);
    println!(
        "OBSERVATION_SCALE mean={mean:.3} p99={:.3} max={:.3} rows={rows}",
        times[178], times[179]
    );
}

#[test]
fn observation_cache_preserves_spawn_order_and_sorts_removals() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![soldier(9, 0), soldier(1, 0), soldier(8, 0)]);
    let mut view = View::new(0).unwrap();
    assert_eq!(
        view.update(&s, &c)
            .births
            .iter()
            .map(|b| b.id)
            .collect::<Vec<_>>(),
        [9, 1, 8]
    );
    for id in [9, 1, 8] {
        s.state.field.actors.remove(id);
    }
    assert_eq!(view.update(&s, &c).despawns, [1, 8, 9]);
    assert!(view.update(&s, &c).despawns.is_empty());
}

#[test]
fn reused_snapshot_storage_preserves_refreshes_changes_and_actor_layouts() {
    let c = Content::bundled().unwrap();
    let mut s = map(
        &c,
        vec![
            soldier(1, 0),
            Actor::Structure(Box::new(Structure {
                id: 3,
                kind: "fob".into(),
                team: 0,
                ..Default::default()
            })),
        ],
    );
    let mut view = View::new(0).unwrap();
    assert_eq!(view.update(&s, &c).births.len(), 2);
    let mut refreshed = false;
    for tick in 0..65 {
        if tick == 5 {
            s.state.field.actors.set_structure_supply(3, 173.).unwrap();
        }
        if tick == 10 {
            replace(&mut s, |a| {
                if let Actor::Structure(b) = a {
                    b.hp *= 0.5;
                }
            });
        }
        let update = view.update(&s, &c);
        let rows = records(&update.snapshots);
        assert!(rows.iter().any(|(id, _)| *id == 1));
        for (id, bytes) in &rows {
            assert_eq!(
                *bytes,
                observation::state(&s, s.state.field.actors.get(*id).unwrap(), 0, &c)
            );
        }
        if tick == 5 || tick == 10 {
            assert!(rows.iter().any(|(id, _)| *id == 3));
        }
        if tick > 10 && rows.iter().any(|(id, _)| *id == 3) {
            refreshed = true;
        }
    }
    assert!(
        refreshed,
        "Stationary objects must recover after a lost unreliable update"
    );
}
#[test]
fn unseen_units_never_enter_the_stream_and_lost_contacts_stop_exposing_state() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![soldier(1, 0), soldier(2, 1)]);
    let mut view = View::new(0).unwrap();
    let first = view.update(&s, &c);
    assert_eq!(first.births.iter().map(|b| b.id).collect::<Vec<_>>(), [1]);
    assert!(records(&first.snapshots).iter().all(|r| r.0 == 1));
    replace(&mut s, |a| {
        if let Actor::Soldier(v) = a {
            v.identity.visible = 3;
        }
    });
    let reveal = view.update(&s, &c);
    assert_eq!(reveal.births.iter().map(|b| b.id).collect::<Vec<_>>(), [2]);
    replace(&mut s, |a| {
        if let Actor::Soldier(v) = a {
            v.identity.visible = 0;
            v.motion.position.x += 1.;
        }
    });
    let hidden = view.update(&s, &c);
    assert_eq!(
        records(&hidden.snapshots)
            .iter()
            .find(|r| r.0 == 2)
            .unwrap()
            .1,
        Vec::<u8>::new()
    );
    assert!(hidden.properties.is_empty());
    s.state.field.actors.remove(2);
    assert_eq!(view.update(&s, &c).despawns, [2]);
    assert!(View::new(2).is_err());
}
#[test]
fn enemy_buildings_redact_supply_and_orders_in_spawns_snapshots_and_capture_updates() {
    let c = Content::bundled().unwrap();
    let building = Structure {
        id: 3,
        team: 1,
        kind: "fob".into(),
        seen: 1,
        supply: 1234.,
        queue_fraction: 0.8,
        inside: vec![2],
        queue: vec![sim::structure::Production {
            item: "rifle_squad".into(),
            remaining: 1.,
            total: 2.,
            owner: 8,
            cost: 100,
        }],
        ..Default::default()
    };
    let mut s = map(&c, vec![Actor::Structure(Box::new(building))]);
    let mut enemy = View::new(0).unwrap();
    let private = enemy.update(&s, &c);
    assert!(private.births[0].props.get("supply").is_none());
    assert!(private.births[0].props.get("queue").is_none());
    let bytes = &private.births[0].state;
    assert_eq!(&bytes[6..8], &[0, 0]);
    assert_eq!(&bytes[11..13], &[0, 0]);
    let mut own = View::new(1).unwrap();
    let friendly = own.update(&s, &c);
    assert_eq!(friendly.births[0].props["supply"], 1234.);
    assert_eq!(friendly.births[0].props["queue"][0], "rifle_squad");
    assert!(own.update(&s, &c).snapshots.is_empty());
    replace(&mut s, |a| {
        if let Actor::Structure(b) = a {
            b.team = 0;
            b.seen = 3;
        }
    });
    let lost = own.update(&s, &c);
    assert_eq!(lost.properties[0].1["queue"], serde_json::json!([]));
    assert_eq!(&records(&lost.snapshots)[0].1[6..8], &[0, 0]);
}
#[test]
fn compact_entity_payloads_keep_godot_layout_and_packet_boundaries() {
    let c = Content::bundled().unwrap();
    let mut actors: Vec<_> = (1..=100).map(|id| soldier(id, 0)).collect();
    actors.push(Actor::Vehicle(Box::new(sim::vehicle::Vehicle {
        id: 101,
        kind: "ghosthawk".into(),
        team: 0,
        position: Vector3::new(10., 20., 30.),
        flight_pitch: -0.2,
        flight_roll: 0.3,
        sling_cargo: 12,
        ..Default::default()
    })));
    actors.push(Actor::Projectile(
        sim::projectile_actor::Projectile::from_spawn(
            102,
            sim::projectile_actor::Spawn {
                flight: sim::projectile_actor::ballistic(
                    sim::projectile::Kind::Smoke,
                    Vector3::ZERO,
                    Vector3::ZERO,
                ),
                team: 0,
                thrower: 1,
                called_by: 0,
            },
        )
        .unwrap(),
    ));
    let s = map(&c, actors);
    let mut view = View::new(-1).unwrap();
    let update = view.update(&s, &c);
    assert!(update.snapshots.len() > 1);
    let rs = records(&update.snapshots);
    assert_eq!(rs.len(), 102);
    assert_eq!(rs[0].1.len(), 31);
    assert_eq!(&rs[0].1[..4], &1f32.to_le_bytes());
    assert_eq!(rs[100].1.len(), 28);
    assert_eq!(&rs[100].1[20..24], &12u32.to_le_bytes());
    assert_eq!(rs[101].1.len(), 14);
    assert!(update.properties.is_empty());
    for b in update.births {
        assert_eq!(
            b.state,
            observation::state(&s, s.state.field.actors.get(b.id).unwrap(), -1, &c)
        );
    }
}

#[test]
fn hud_and_reports_hide_enemy_totals_without_mutating_replay_state() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![soldier(1, 0), soldier(2, 1)]);
    s.state.field.battle.joined(7, 0, "Ada").unwrap();
    s.state.field.battle.joined(9, 1, "Grace").unwrap();
    s.state
        .field
        .battle
        .add(9, 1, sim::battle_stats::VALUE_KILLED, 12345.)
        .unwrap();
    let before = s.checkpoint().unwrap();
    let hud = observation::hud(&s, &c, 0).unwrap();
    assert!(hud["teams"][0]["cap"].as_u64().unwrap() > 0);
    assert_eq!(hud["teams"][1], serde_json::json!({}));
    let report = observation::report(&s, &c, 0).unwrap();
    assert_eq!(report["players"].as_array().unwrap().len(), 1);
    assert_eq!(report["sides"][1], serde_json::json!({}));
    assert_eq!(report["tl"][0][2], -1.);
    let full = observation::report(&s, &c, -1).unwrap();
    assert_eq!(full["sides"][1]["val_killed"], 12345.);
    assert_eq!(before, s.checkpoint().unwrap());
}

#[test]
fn render_events_preserve_visibility_impulses_and_private_messages_without_changing_state() {
    use observation::events::{admits, Events};
    use sim::match_commands::{Audience, Event, MessageKind};
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![soldier(1, 0), soldier(2, 1)]);
    s.state.owners.connect(7, 0).unwrap();
    s.names.insert(7, "Commander".into());
    replace(&mut s, |a| {
        if let Actor::Soldier(m) = a {
            if m.identity.id == 1 {
                m.vitals.life = sim::infantry_vitals::Life::Dead;
                m.shock.flinging = true;
                m.shock.velocity = Vector3::new(3., 4., 5.);
            }
        }
    });
    let frame = frontline_server::simulation::Frame {
        tick: 1,
        commands: vec![
            Event::Deed {
                peer: 7,
                text: "Training a squad".into(),
                position: Vector3::X,
                major: false,
            },
            Event::Deed {
                peer: -1,
                text: "AI training".into(),
                position: Vector3::X,
                major: false,
            },
            Event::Message {
                audience: Audience::Peer(7),
                kind: MessageKind::Warning,
                text: "private rejection".into(),
                position: None,
            },
            Event::Message {
                audience: Audience::Team(1),
                kind: MessageKind::Chat,
                text: "secret orders".into(),
                position: Some(Vector3::X),
            },
        ],
        events: vec![
            sim::match_tick::Event::Deferred(sim::world_combat::Event::Shot {
                shooter: 2,
                target: 1,
                muzzle: Vector3::X,
                end: Vector3::ZERO,
                hit: true,
                blocked: false,
                impact: 2,
                sound: "rifle".into(),
            }),
            sim::match_tick::Event::Infantry(sim::infantry_world::Event::Died(1)),
            sim::match_tick::Event::Infantry(sim::infantry_world::Event::Died(1)),
        ],
    };
    let before = s.checkpoint().unwrap();
    let out = Events::collect(&s, &frame);
    assert_eq!(
        out.deeds,
        vec![(
            7,
            0,
            serde_json::json!([7, "Training a squad", [1., 0., 0.], false])
        )]
    );
    assert_eq!(out.effects.len(), 2);
    assert_eq!(out.effects[0].mask, 2);
    assert!(!out.effects[0].reliable);
    assert_eq!(
        out.effects[1].data,
        serde_json::json!([15, 1, [3., 4., 5.], 1])
    );
    assert!(out.effects[1].reliable);
    assert!(admits(out.messages[0].audience, 7, 0));
    assert!(!admits(out.messages[0].audience, 9, 0));
    assert!(!admits(out.messages[1].audience, 7, 0));
    assert!(admits(out.messages[1].audience, 9, 1));
    assert!(admits(out.messages[1].audience, 11, -1));
    assert_eq!(before, s.checkpoint().unwrap());
}

#[test]
fn recoil_and_surrender_effects_follow_actor_visibility_without_advancing_gameplay() {
    use observation::events::Events;
    let c = Content::bundled().unwrap();
    let mut s = map(
        &c,
        vec![
            soldier(1, 1),
            Actor::Vehicle(Box::new(sim::vehicle::Vehicle {
                id: 2,
                team: 1,
                kind: "sochor".into(),
                ..Default::default()
            })),
        ],
    );
    let frame = frontline_server::simulation::Frame {
        tick: 1,
        commands: vec![sim::match_commands::Event::Brain(
            sim::squad_brain::Event::Surrendered {
                soldier: 1,
                team: 1,
                position: Vector3::X,
                drop_direction: Vector3::Z,
            },
        )],
        events: vec![sim::match_tick::Event::Vehicle(
            sim::vehicle_world::Event::Combat(sim::vehicle_combat_world::Event::Recoil {
                vehicle: 2,
                direction: -Vector3::Z,
            }),
        )],
    };
    for visible in [false, true] {
        replace(&mut s, |a| match a {
            Actor::Soldier(m) => m.identity.visible = if visible { 3 } else { 0 },
            Actor::Vehicle(v) => v.visible = if visible { 3 } else { 0 },
            _ => {}
        });
        let before = s.checkpoint().unwrap();
        let out = Events::collect(&s, &frame);
        assert_eq!(out.effects.len(), 2);
        assert_eq!(
            out.effects[0].data,
            serde_json::json!([3, [1., 0., 0.], [0., 0., 1.]])
        );
        assert_eq!(
            out.effects[1].data,
            serde_json::json!([19, 2, [0., 0., -1.]])
        );
        assert!(out.effects[0].reliable && !out.effects[1].reliable);
        assert!(out
            .effects
            .iter()
            .all(|e| e.mask == if visible { 3 } else { 2 }));
        assert_eq!(before, s.checkpoint().unwrap());
    }
}

#[test]
fn removed_scenery_and_boats_keep_their_final_visual_events() {
    use sim::structure_damage::{Damage, Event as DamageEvent};
    use sim::vehicle_loss_world::{Event as LossEvent, Notice};
    let c = Content::bundled().unwrap();
    let s = map(&c, vec![]);
    let before = s.checkpoint().unwrap();
    let frame = frontline_server::simulation::Frame {
        tick: 1,
        commands: vec![],
        events: vec![
            sim::match_tick::Event::Fire(sim::fires::Event::BurnedDown {
                structure: 1,
                damage: Damage {
                    applied: true,
                    removed: Some(Box::new(Structure {
                        id: 1, kind: "tree".into(), team: -1, variant: 2,
                        position: Vector3::X, size: Vector3::splat(4.), yaw: 0.3,
                        ..Default::default()
                    })),
                    events: vec![DamageEvent::TreeFall(0.5)],
                },
            }),
            sim::match_tick::Event::Vehicle(sim::vehicle_world::Event::Loss(LossEvent::Sunk {
                vehicle: Notice { id: 2, team: 0, position: Vector3::Z, name: "Patrol boat".into() },
                heavy: false,
            })),
        ],
    };
    let out = observation::events::Events::collect(&s, &frame);
    assert_eq!(out.effects.len(), 3);
    assert_eq!(out.effects[0].data, serde_json::json!([17, [1., 0., 0.], [2., 2., 2.], 0.3]));
    assert_eq!(out.effects[1].data, serde_json::json!([10, [1., 0., 0.], 0.5, 1, 2]));
    assert_eq!(out.effects[2].data, serde_json::json!([18, 2, [0., 0., 1.]]));
    assert!(out.effects.iter().all(|effect| effect.reliable && effect.mask == 3));
    assert_eq!(before, s.checkpoint().unwrap());
}

#[test]
fn persistent_effects_keep_the_newest_live_fires_with_their_remaining_lifetime() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![]);
    for i in 0..26 {
        s.state
            .field
            .fires
            .start_patch(
                Vector3::X * i as f32,
                1.,
                20. + i as f64,
                0,
                &mut s.state.field.geometry,
                &mut vec![],
            )
            .unwrap();
    }
    let before = s.checkpoint().unwrap();
    let fires = observation::events::Events::persistent(&s);
    let fires = fires.as_array().unwrap();
    assert_eq!(fires.len(), 24);
    assert_eq!(fires[0], serde_json::json!([16, [2., 0., 0.], 1., 22.]));
    assert_eq!(fires[23], serde_json::json!([16, [25., 0., 0.], 1., 45.]));
    assert_eq!(before, s.checkpoint().unwrap());
}

#[test]
fn map_projection_uses_godots_bridge_tags_and_never_sends_simulation_geometry() {
    let c = Content::bundled().unwrap();
    let mut s = map(&c, vec![]);
    s.state.water.bridges.push(sim::water::Bridge {
        a: Vector3::ZERO,
        b: Vector3::X * 10.,
        half_width: 3.,
        quay: true,
    });
    s.state.field.geometry.terrain.crater(Vector3::ZERO, 2.0);
    let data = frontline_server::serve::map(&s).unwrap();
    let mut r = sim::state_codec::Reader::new(&data, b"FLVM\x02\0\0\0").unwrap();
    let meta: serde_json::Value = serde_json::from_slice(r.bytes(1_000_000).unwrap()).unwrap();
    assert_eq!(meta["water"]["bridges"][0][3], "quay");
    assert_eq!(r.bytes(4096).unwrap().len(), 4096);
    assert_eq!(
        r.bytes(1_000_000).unwrap().len(),
        s.state.field.geometry.terrain.landform.samples().len() * 4
    );
    let heights = frontline_server::compression::decode(r.bytes(100_000).unwrap(), 65536).unwrap();
    assert_eq!(
        heights,
        frontline_server::terrain_view::heights(&s.state.field.geometry.terrain)
    );
    let craters = frontline_server::compression::decode(r.bytes(100_000).unwrap(), 4096).unwrap();
    assert_eq!(
        craters,
        s.state.field.geometry.terrain.layers[sim::terrain::CRATER]
    );
    r.finish().unwrap();
    assert!(data.len() < 20_000);
}

#[test]
fn maps_without_bridges_accept_the_empty_deck_mask_used_by_godot_scenarios() {
    let mut terrain = sim::terrain::Terrain::blank(64).unwrap();
    terrain.layers[sim::terrain::BASE].fill(sim::terrain::WATER);
    let empty = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &[]).unwrap();
    let zero =
        sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &vec![0; 4096]).unwrap();
    assert_eq!(empty.checkpoint(), zero.checkpoint());
    assert!(sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &[0; 3]).is_err());
}
