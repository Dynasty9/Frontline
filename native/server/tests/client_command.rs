use frontline_core::match_commands::{Action, Command};
use frontline_server::client_command::decode;
use serde_json::json;

#[test]
fn existing_client_orders_map_to_the_replay_command_vocabulary() {
    for t in [
        "move",
        "assault",
        "defend",
        "dismount",
        "attack",
        "stop",
        "retreat",
        "build",
        "build_many",
        "fire_mission",
        "work",
        "enter",
        "sling",
        "board",
        "throw",
        "support",
        "demo_support",
        "train",
        "research",
        "cancel",
        "rally",
        "tunnel_exit",
        "chat",
    ] {
        let value = json!({"t":t,"squads":[3,5],"vehicles":[8],"pos":[1,2,3],"face":[0,0,1],"mode":2,"target":9,
            "kind":if t == "throw" {"frag"} else if t == "fire_mission" {"he"} else {"barracks"},
            "items":[[[1,2,3],0.5,4]],"soldier":11,"building":12,"item":"rifle_squad","exit":14,"text":" Forward! ","team_only":true});
        let command =
            decode(&serde_json::to_vec(&value).unwrap()).unwrap_or_else(|e| panic!("{t}: {e}"));
        assert_eq!(command.squads, vec![3, 5]);
        assert_eq!(command.vehicles, vec![8]);
        assert_eq!(
            Command::decode(&command.encode().unwrap()).unwrap(),
            command
        );
    }
    for order in ["move", "attack", "throw", "stop", "retreat", "man"] {
        let value = json!({"t":"unit","o":order,"soldier":3,"target":4,"pos":[0,0,0]});
        assert!(matches!(
            decode(&serde_json::to_vec(&value).unwrap()).unwrap().action,
            Action::Unit { .. }
        ));
    }
}

#[test]
fn malformed_or_impersonating_commands_never_reach_admission() {
    for value in [
        json!([]),
        json!({"t":"player_joined","peer":7}),
        json!({"t":"stop","owner":7}),
        json!({"t":"stop","reclaim":7}),
        json!({"t":"move","pos":[0,0]}),
        json!({"t":"move","pos":[0,0,1e30]}),
        json!({"t":"move","pos":[0,0,0],"mode":3}),
        json!({"t":"stop","squads":[-1]}),
        json!({"t":"stop","squads":[1.5]}),
        json!({"t":"throw","pos":[0,0,0],"kind":"nuclear"}),
        json!({"t":"chat","text":"Hello","team_only":"yes"}),
        json!({"t":"unit","soldier":1,"o":"unknown"}),
    ] {
        assert!(
            decode(&serde_json::to_vec(&value).unwrap()).is_err(),
            "{value}"
        );
    }
    assert!(decode(&vec![b' '; frontline_server::client_command::MAX_BYTES + 1]).is_err());
    assert!(decode(b"{\"t\":\"move\",\"pos\":[NaN,0,0]}").is_err());
    let c = decode(br#"{"t":"chat","text":"  On your left  ","team_only":true}"#).unwrap();
    assert_eq!(
        c.action,
        Action::Chat {
            text: "On your left".into(),
            team_only: true
        }
    );
}
