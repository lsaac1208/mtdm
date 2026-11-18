# Acceptance report — 2026-11-18T16:22Z

Commit: `562a4b8` on `dev/vertical-slice-20261118` · Godot: `4.7.2.stable.official.ed1daf0bf`

| Gate | Result |
|---|---|
| Engine tests (TESTS DONE pass=41 fail=0) | PASS |
| bot_1: TEST bot_completes_demo PASS sim_time=332s deaths=0 kills=24 parries=5 run_time=02:25 | PASS |
| bot_2: TEST bot_completes_demo PASS sim_time=312s deaths=0 kills=24 parries=2 run_time=02:19 | PASS |
| bot_3: TEST bot_completes_demo PASS sim_time=298s deaths=0 kills=24 parries=5 run_time=02:06 | PASS |
| bot_human_1: TEST bot_completes_demo PASS sim_time=138s deaths=0 kills=24 parries=7 run_time=02:17 | PASS |
| bot_human_2: TEST bot_completes_demo PASS sim_time=134s deaths=0 kills=24 parries=7 run_time=02:13 | PASS |
| bot_human_3: TEST bot_completes_demo PASS sim_time=186s deaths=1 kills=25 parries=10 run_time=03:06 | PASS |
| Export + package Linux/Windows (0.1.3) | PASS |
| Exported Linux build tests (TESTS DONE pass=41 fail=0) | PASS |
| Exported Linux build bot: TEST bot_completes_demo PASS sim_time=374s deaths=1 kills=26 parries=3 run_time=02:31 | PASS |
| Rendered captures under Xvfb (50 frames) | PASS |

## Spec conformance (docs/05 §2.1–2.3, docs/03)
```
SPEC player hurtbox 44x138                            OK   (44.0, 138.0)
SPEC player run 260 / dash ~520                       OK   260 / 540
SPEC player sprite ~150 px tall                       OK   152 px
SPEC slash band 55..145 px                            OK   55..145
SPEC down slash reaches ground                        OK   bottom 0
SPEC grunt hurtbox 46x124                             OK   (46.0, 124.0)
SPEC grunt visual height ~132 px                      OK   126 px
SPEC crawler hurtbox 92x46                            OK   (92.0, 46.0)
SPEC crawler visual height ~54 px                     OK   50 px
SPEC husk hurtbox 50x138                              OK   (50.0, 138.0)
SPEC husk visual height ~144 px                       OK   144 px
SPEC spitter hurtbox 52x130                           OK   (52.0, 130.0)
SPEC spitter visual height ~138 px                    OK   126 px
SPEC elite hurtbox 72x172                             OK   (72.0, 172.0)
SPEC elite visual height ~180 px                      OK   184 px
SPEC crawler top < slash band bottom (whiff)          OK   
SPEC grunt wind-up 0.35-0.45 s                        OK   0.40 s
SPEC husk seal burst radius ~110 px                   OK   115 px
SPEC taint puddle r=65 px, 4.5 s                      OK   65 px / 4.5 s
SPEC elite chop/sweep wind-up 0.65-0.85 s (phase 1)   OK   0.80 / 0.65 s (see elite_windup_readable)
SPEC elite armour: light hits never stagger           OK   interrupt_poise=9999
```

## Engine checks
```
TEST move_right_1s                PASS  moved=249 px (spec 260 px/s)
TEST jump_and_land                PASS  apex=144 px
TEST dash                         PASS  dash dist=91 (left)
TEST hslash_whiffs_crawler        PASS  crawler hp 26 -> 26
TEST hslash_hits_grunt            PASS  grunt hp 34 -> 24
TEST downslash_hits_crawler       PASS  crawler hp 26 -> 10
TEST dash_slash_hits_crawler      PASS  crawler hp -> 12
TEST grunt_staggers_on_light_hit  PASS  state=stagger
TEST combo_kills_grunt            PASS  
TEST parry_on_timed_guard         PASS  parries=1 hp=100
TEST parry_staggers_enemy         PASS  grunt state=stagger
TEST husk_seal_burst_triggers     PASS  after melee chain, state=burst_prep
TEST husk_burst_punishes_greed    PASS  player hp 100 -> 60
TEST talisman_no_seal_pressure    PASS  seal=0
TEST spitter_fires_parabolic_glob PASS  t=2.3s
TEST glob_leaves_taint_puddle     PASS  
TEST talisman_interrupts_spitter  PASS  state=stagger
TEST elite_windup_readable        PASS  windup_chop lead=0.80s (spec 0.65–0.85)
TEST elite_armor_ignores_light_hit PASS  state chase -> chase
TEST player_dies                  PASS  
TEST respawn_at_checkpoint        PASS  x=310 cp=260 hp=100
TEST encounter_locks_on_trigger   PASS  state=active
TEST encounter_clears             PASS  state=cleared alive=0
TEST route_e1_village             PASS  
TEST route_e2_crawler             PASS  
TEST route_e3_group_a             PASS  
TEST route_e4_spitter             PASS  
TEST route_e5_group_c             PASS  
TEST route_e6_husk                PASS  
TEST route_e7_group_b             PASS  
TEST route_e7c_burial_wave        PASS  
TEST route_e8_elite               PASS  
TEST demo_completes               PASS  scene=res://scenes/ending.tscn
TEST restart_keeps_progress       PASS  x=2460 cp1=2400
TEST new_run_resets_state         PASS  cleared=0 cp=0 x=320 alive=9 actors=10
TEST no_stale_actors              PASS  stale=0
TEST spawns_on_surfaces           PASS  []
TEST gamepad_actions_fire         PASS  []
TEST hero_anim_no_pops            PASS  max body-centre jump 18.1 px at hero_01_ready f135
TEST enemies_cross_ledges         PASS  []
TEST spec_conformance             PASS  21/21 rows
TESTS DONE pass=41 fail=0
```

## Rendered performance (1280x720, software GL / llvmpipe, busiest wave)
```
FPS 69  frame_ms 14.5  objects 216
FPS 63  frame_ms 15.9  objects 220
FPS 62  frame_ms 16.1  objects 227
FPS 66  frame_ms 15.2  objects 229
FPS 70  frame_ms 14.3  objects 216
```

## Not verifiable here
- Human playtest (feel, difficulty, first-time readability).
- Listening test of audio (mix verified numerically from a movie-writer recording only).
- Windows runtime (export built; no Windows/Wine available).
- Physical gamepad (bindings verified by injected joypad events).
- Real-GPU frame rate.
