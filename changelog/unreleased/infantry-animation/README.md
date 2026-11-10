# Animation review footage

Captured from PR #98 after integrating main `1891009`, using Godot 4.7.2 and the locally installed SWAT/Mixamo assets. Videos are rendered by the game, with no generated or retouched character frames. Fixed-step recording is not a real-time performance measurement.

| Recording | Coverage | Setup |
| --- | --- | --- |
| [Battle, 28 seconds](gameplay.mp4) | Squad movement, cover, reload, firing, bullet reaction, blast ragdoll, tank impact and destruction | Actual `motion` battle; camera cuts and hits at 8/10/17/22 seconds are staged |
| [Wall to prone, 8 seconds](wall-to-prone.mp4) | Backward clearance step, foot settling, crouch-to-prone transition | Actual server-controlled soldier; staged suppression beside a wall |
| [Activities, 18 seconds](game-activities.mp4) | Digging, slung rifle, smoking, lethal-hit response and dropped shovel | Normal construction order; forced idle choice and lethal hit at 13 seconds |
| [All installed clips, 3:12](animation-catalog.mp4) | All 56 locally installed clips, each played for its complete duration or at least two seconds | Isolated animation inspector, clearly labeled; not proof of gameplay routing |

The catalog includes vehicle entry/exit, sitting and piloting clips. Those are **preview-only**; complete vehicle interaction and full-roster integration are not implemented. The imported assets remain local and are not included in game downloads. Missing assets use procedural fallback.

Close-up captures disable depth of field and grass for inspection. Battle capture retains grass. Recordings report ObjectDB instances at shutdown; that cleanup warning remains unresolved.

## Catalog timestamps

Each timestamp starts a complete clip; the extra 0.4 seconds allows the end pose to remain visible. These names match the inspector.

| Start | Segment | Clip |
| --- | --- | --- |
| 0:00 | 2.40 s | `MOB1_CrouchWalk_F` |
| 0:02 | 2.40 s | `MOB1_CrouchWalk_F_IPC` |
| 0:04 | 2.40 s | `MOB1_Jog_F` |
| 0:07 | 2.40 s | `MOB1_Jog_F_IPC` |
| 0:09 | 7.16 s | `MOB1_Stand_Relaxed_Fgt_v4` |
| 0:16 | 4.50 s | `MOB1_Stand_Relaxed_Idle` |
| 0:21 | 2.40 s | `MOB1_Stand_Relaxed_to_Walk_F` |
| 0:23 | 2.40 s | `MOB1_Stand_Relaxed_to_Walk_F_IPC` |
| 0:26 | 2.40 s | `MOB1_Walk_F` |
| 0:28 | 2.40 s | `MOB1_Walk_F_IPC` |
| 0:30 | 2.40 s | `W2_Jog_Aim_F_Loop` |
| 0:33 | 2.40 s | `W2_Jog_Aim_F_Loop_IPC` |
| 0:35 | 4.40 s | `W2_Stand_Aim_Idle_v2` |
| 0:40 | 2.40 s | `W2_Stand_Aim_To_Relaxed` |
| 0:42 | 5.10 s | `W2_Stand_Relaxed_Idle_v2` |
| 0:47 | 2.40 s | `W2_Walk_Aim_F_Loop` |
| 0:50 | 2.40 s | `W2_Walk_Aim_F_Loop_IPC` |
| 0:52 | 5.23 s | `mixamo_activities__Digging` |
| 0:57 | 5.87 s | `mixamo_activities__Entering_Car` |
| 1:03 | 6.20 s | `mixamo_activities__Exiting_Car` |
| 1:09 | 3.07 s | `mixamo_activities__Jostled_Passenger` |
| 1:12 | 10.10 s | `mixamo_activities__Piloting` |
| 1:22 | 6.80 s | `mixamo_activities__Sitting_Idle` |
| 1:29 | 18.30 s | `mixamo_activities__Smoking` |
| 1:48 | 2.40 s | `mixamo_basic_shooter__firing_rifle` |
| 1:50 | 2.40 s | `mixamo_basic_shooter__hit_reaction` |
| 1:52 | 3.70 s | `mixamo_basic_shooter__reloading` |
| 1:56 | 3.50 s | `mixamo_basic_shooter__rifle_aiming_idle` |
| 2:00 | 2.40 s | `mixamo_basic_shooter__rifle_jump` |
| 2:02 | 2.40 s | `mixamo_basic_shooter__rifle_run` |
| 2:04 | 2.40 s | `mixamo_basic_shooter__run_backwards` |
| 2:07 | 2.40 s | `mixamo_basic_shooter__strafe` |
| 2:09 | 2.40 s | `mixamo_basic_shooter__strafe_(2)` |
| 2:12 | 2.40 s | `mixamo_basic_shooter__strafe_left` |
| 2:14 | 2.40 s | `mixamo_basic_shooter__strafe_right` |
| 2:16 | 3.60 s | `mixamo_basic_shooter__toss_grenade` |
| 2:20 | 2.40 s | `mixamo_basic_shooter__turn_left` |
| 2:22 | 2.40 s | `mixamo_basic_shooter__turning_right_45_degrees` |
| 2:25 | 2.40 s | `mixamo_basic_shooter__walking` |
| 2:27 | 2.40 s | `mixamo_basic_shooter__walking_backwards` |
| 2:30 | 2.40 s | `mixamo_shooter__firing_rifle` |
| 2:32 | 2.40 s | `mixamo_shooter__jump_backward` |
| 2:34 | 2.40 s | `mixamo_shooter__jump_forward` |
| 2:37 | 3.50 s | `mixamo_shooter__rifle_aiming_idle` |
| 2:40 | 2.40 s | `mixamo_shooter__rifle_run` |
| 2:43 | 2.40 s | `mixamo_shooter__run_backwards` |
| 2:45 | 2.40 s | `mixamo_shooter__start_walking` |
| 2:48 | 2.43 s | `mixamo_shooter__start_walking_backwards` |
| 2:50 | 3.07 s | `mixamo_shooter__stop_walking` |
| 2:53 | 2.40 s | `mixamo_shooter__strafe` |
| 2:56 | 2.40 s | `mixamo_shooter__strafe_(2)` |
| 2:58 | 2.40 s | `mixamo_shooter__walk_backwards_stop` |
| 3:00 | 2.40 s | `mixamo_shooter__walking` |
| 3:03 | 2.40 s | `mixamo_shooter__walking_backwards` |
| 3:05 | 3.46 s | `mixamo_shooter__walking_to_dying` |
| 3:09 | 2.40 s | `mixamo_transition__Rifle_Kneel_To_Prone` |
