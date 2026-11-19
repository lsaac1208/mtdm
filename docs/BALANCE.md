# Balance pass (M6) — telemetry-driven

Method: 10 runs of the human-like bot (`--test=bot --bot_skill=human`: ~180 ms reaction cadence, 25 % missed defensive reads) before and after tuning. Every run prints a `TELEMETRY` JSON line (damage per attack source, death causes, per-encounter time/damage/deaths); `tools/telemetry_report.py` aggregates them. The bot is a proxy, not a human playtest.

## Findings (before)
- The elite's **sweep** was the top killer (7 of 21 deaths, 186 HP/run). Its hit band reached 128 px above the ground — a jump (apex ≈144 px) barely cleared it — and phase 2 shortened its wind-up to 0.55 s, below the spec's 0.65 s floor.
- Grunt claws were the second source (lunge of 300 px/s reached far beyond the visible claw).
- Group C deaths came from standing in taint pools while being attacked (45 % slow trapped the player).

## Changes
| Item | Before | After |
|---|---|---|
| Elite sweep band (px above ground) | 40–128 | 30–92 (still hits anyone standing; a jump clears it) |
| Elite sweep damage / active time | 26 / 0.16 s | 22 / 0.12 s |
| Elite sweep wind-up in phase 2 | 0.55 s | 0.65 s (spec floor) |
| Elite ground shock radius / damage | 190 px / 10 | 150 px / 8 |
| Elite phase-2 chop→sweep gap | 0.35 s | 0.5 s |
| Grunt lunge speed / damage | 300 px/s / 12 | 230 px/s / 10 |
| Taint slow / puddle DPS / pool DPS | ×0.55 / 8 / 10 | ×0.7 / 6 / 7 |

## Fairness gates (new tests, `elite_fairness`)
Sweep the input time across each wind-up and count the presses that avoid all damage:
- Sweep, jump: ≥ 0.30 s window (measured 0.36 s)
- Chop + ground shock, dash back: ≥ 0.15 s (0.18 s)
- Sweep, dash through: ≥ 0.15 s (0.18 s)

## Result
Deaths over 10 runs: **21 → 6**; elite deaths per run **1.8 → 0.2** while the elite still deals ≈125 HP of damage per fight (it remains the hardest encounter). Deaths are now spread across encounters with the peak at the burial wave and the elite.

### Before
```
runs: 10

## Damage taken per source (avg per run)
  尸将:sweep                           186.4
  普通尸祟:attack                        142.6
  尸将:chop                             98.9
  伏爬者:pounce                          67.7
  尸将:ground_shock                     59.3
  hazard:puddle                       51.9
  封印残尸:attack                         46.0
  瘴吐者:taint                           44.5
  封印残尸:seal_burst                      2.2
  瘴吐者:swipe                            1.2

## Death causes (total)
  尸将:sweep                         7
  普通尸祟:attack                      5
  尸将:ground_shock                  4
  尸将:chop                          3
  瘴吐者:taint                        1
  hazard:puddle                    1

## Encounters (avg per run)
  e8_elite           time   34.0s  damage  419.5  deaths 1.80
  e5_group_c         time    8.6s  damage   93.8  deaths 0.30
  e7c_burial_wave    time   11.0s  damage   44.8  deaths 0.00
  e3_group_a         time    6.3s  damage   31.9  deaths 0.00
  e7_group_b         time    7.9s  damage   23.9  deaths 0.00
  e1_village         time    4.1s  damage    4.8  deaths 0.00

```
### After
```
runs: 10

## Damage taken per source (avg per run)
  普通尸祟:attack                         96.9
  伏爬者:pounce                          89.5
  尸将:sweep                            52.1
  瘴吐者:taint                           42.0
  hazard:puddle                       33.7
  封印残尸:attack                         31.4
  尸将:ground_shock                     26.3
  尸将:chop                             24.0
  封印残尸:seal_burst                      2.2
  瘴吐者:swipe                            1.2

## Death causes (total)
  普通尸祟:attack                      2
  尸将:sweep                         1
  尸将:ground_shock                  1
  伏爬者:pounce                       1
  瘴吐者:taint                        1

## Encounters (avg per run)
  e8_elite           time   35.6s  damage  124.4  deaths 0.20
  e7c_burial_wave    time   13.8s  damage   81.5  deaths 0.30
  e5_group_c         time    9.0s  damage   77.7  deaths 0.10
  e3_group_a         time    5.7s  damage   22.6  deaths 0.00
  e7_group_b         time    8.5s  damage   17.6  deaths 0.00
  e1_village         time    4.3s  damage    8.0  deaths 0.00

```
