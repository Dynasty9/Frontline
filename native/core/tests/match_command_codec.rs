use frontline_core::match_command_codec::MAX_COMMAND_BYTES;
use frontline_core::match_commands::{Action, Command, Placement, UnitOrder};
use frontline_core::vector::Vector3;
fn commands() -> Vec<Command> {
    let position = Vector3::new(13.7, 0., -17.3);
    let face = Vector3::NEG_Z;
    let mut actions = vec![
        Action::Move {
            position,
            face,
            mode: 2,
        },
        Action::Assault { position, face },
        Action::Defend { position, face },
        Action::Dismount,
        Action::Attack(17),
        Action::Stop,
        Action::Retreat,
        Action::Build {
            kind: "trench".into(),
            position,
            yaw: 0.37,
        },
        Action::BuildMany {
            kind: "sandbags".into(),
            items: vec![
                Placement {
                    position,
                    yaw: 0.1,
                    length: None,
                },
                Placement {
                    position,
                    yaw: 0.2,
                    length: Some(6.),
                },
            ],
        },
        Action::FireMission {
            building: 7,
            position,
            smoke: true,
        },
        Action::Work(4),
        Action::Enter(5),
        Action::Sling(6),
        Action::Board(7),
        Action::Throw {
            position,
            smoke: false,
        },
        Action::Support {
            kind: "mortars".into(),
            position,
            direction: face,
        },
        Action::DemoSupport {
            kind: "mortars".into(),
            position,
            direction: face,
        },
        Action::Produce {
            building: 7,
            item: "rifle_squad".into(),
            research: false,
        },
        Action::Cancel(7),
        Action::Rally {
            building: 7,
            position,
        },
        Action::TunnelExit {
            building: 7,
            exit: 8,
        },
        Action::Chat {
            text: "Ready, командир".into(),
            team_only: true,
        },
    ];
    for order in [
        UnitOrder::Move {
            position,
            face,
            mode: 1,
        },
        UnitOrder::Attack(9),
        UnitOrder::Throw {
            position,
            smoke: true,
        },
        UnitOrder::Stop,
        UnitOrder::Retreat,
        UnitOrder::Man(7),
    ] {
        actions.push(Action::Unit { soldier: 17, order });
    }
    actions
        .into_iter()
        .map(|action| Command {
            squads: vec![6, 2, 6],
            vehicles: vec![4, 7],
            action,
        })
        .collect()
}
#[test]
fn every_order_round_trips_with_selection_order_and_duplicate_ids_intact() {
    for command in commands() {
        let bytes = command.encode().unwrap();
        assert_eq!(Command::decode(&bytes).unwrap(), command);
        assert_eq!(Command::decode(&bytes).unwrap().encode().unwrap(), bytes);
    }
}
#[test]
fn all_truncations_and_trailing_bytes_are_rejected() {
    for command in commands() {
        let mut bytes = command.encode().unwrap();
        for n in 0..bytes.len() {
            assert!(
                Command::decode(&bytes[..n]).is_err(),
                "accepted {n} of {} bytes",
                bytes.len()
            );
        }
        bytes.push(0);
        assert!(Command::decode(&bytes).is_err());
    }
}
#[test]
fn unknown_versions_tags_invalid_flags_and_nonfinite_positions_are_rejected() {
    let command = Command {
        squads: vec![],
        vehicles: vec![],
        action: Action::Throw {
            position: Vector3::ZERO,
            smoke: false,
        },
    };
    let original = command.encode().unwrap();
    for (index, value) in [(4, 99), (6, 99), (16, 255), (29, 2)] {
        let mut bytes = original.clone();
        bytes[index] = value;
        assert!(Command::decode(&bytes).is_err());
    }
    let mut bytes = original;
    bytes[17..21].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Command::decode(&bytes).is_err());
}
#[test]
fn hostile_lengths_and_invalid_outbound_commands_are_bounded() {
    let mut bytes = Command {
        squads: vec![],
        vehicles: vec![],
        action: Action::Stop,
    }
    .encode()
    .unwrap();
    bytes[8..12].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(Command::decode(&bytes).is_err());
    assert!(Command::decode(&vec![0; MAX_COMMAND_BYTES + 1]).is_err());
    for action in [
        Action::Move {
            position: Vector3::NAN,
            face: Vector3::ZERO,
            mode: 0,
        },
        Action::Move {
            position: Vector3::ZERO,
            face: Vector3::ZERO,
            mode: 3,
        },
        Action::Chat {
            text: "bad\0text".into(),
            team_only: false,
        },
        Action::BuildMany {
            kind: "trench".into(),
            items: vec![Placement {
                position: Vector3::ZERO,
                yaw: 0.,
                length: Some(f64::INFINITY),
            }],
        },
    ] {
        assert!(Command {
            squads: vec![],
            vehicles: vec![],
            action
        }
        .encode()
        .is_err());
    }
}
