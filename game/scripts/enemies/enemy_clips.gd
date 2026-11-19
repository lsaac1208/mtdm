class_name EnemyClips
extends RefCounted
## Keyframed clips for the enemy cut-out rigs (tools/rig/*_rig_def.py).
## Same conventions as HeroClips: degrees added to rest, "@root" = pixel offset
## in source-art pixels, normalized times. Limbs hang down: negative = forward.

static func _c(keys: Array, phase: float) -> Array:
	return HeroClips._cycle(keys, phase)


static func for_type(t: String) -> Dictionary:
	match t:
		"grunt":
			return grunt()
		"elite":
			return elite()
		"spitter":
			return spitter()
		"husk":
			return husk()
		"crawler":
			return crawler()
	return {}


## Painted pose name -> rig clip. Poses not listed stay painted (contact frames).
static func pose_map(t: String) -> Dictionary:
	match t:
		"grunt":
			return {"grunt_idle": "walk", "grunt_walk": "walk", "grunt_alert": "alert", "grunt_windup": "windup"}
		"elite":
			return {"elite_main": "walk", "elite_idle": "idle"}
		"spitter":
			return {"spitter_idle": "walk", "spitter_side": "walk", "spitter_detect": "alert", "spitter_windup": "windup",
				"spitter_recover": "recover", "spitter_hit": "hit"}
		"crawler":
			return {"crawler_idle": "walk", "crawler_crawl": "walk", "crawler_alert": "alert", "crawler_retreat": "walk"}
		"husk":
			return {"husk_idle": "walk", "husk_walk": "walk", "husk_side": "windup", "husk_hit": "hit", "husk_awaken": "awaken"}
	return {}


static func grunt() -> Dictionary:
	var c := {}
	c["idle"] = {"len": 2.2, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, 3.0], [1, 0.0]], "head": [[0, 0.0], [0.3, 6.0], [0.6, -3.0], [1, 0.0]],
		"shoulder_f": [[0, 0.0], [0.5, 6.0], [1, 0.0]], "forearm_f": [[0, 0.0], [0.5, 8.0], [1, 0.0]],
		"shoulder_b": [[0, 0.0], [0.5, -4.0], [1, 0.0]],
		"@root": [[0, Vector2.ZERO], [0.5, Vector2(0, 2)], [1, Vector2.ZERO]]}}
	# lurching, uneven shamble: the front leg drags, head lolls
	c["walk"] = {"len": 1.1, "loop": true, "tracks": {
		"thigh_f": _c([[0.0, -16.0], [0.55, 14.0]], 0.0), "shin_f": _c([[0.0, 6.0], [0.4, 12.0], [0.75, 34.0]], 0.0),
		"thigh_b": _c([[0.0, -12.0], [0.5, 16.0]], 0.5), "shin_b": _c([[0.0, 4.0], [0.7, 26.0]], 0.5),
		"shoulder_f": _c([[0.0, 10.0], [0.5, -6.0]], 0.0), "forearm_f": _c([[0.0, 0.0], [0.5, 14.0]], 0.0),
		"shoulder_b": _c([[0.0, -10.0], [0.5, 12.0]], 0.0), "forearm_b": _c([[0.0, 0.0], [0.5, -10.0]], 0.0),
		"spine": [[0, 4.0], [0.3, 9.0], [0.55, 3.0], [0.8, 8.0], [1, 4.0]],
		"head": [[0, -6.0], [0.35, 10.0], [0.7, -10.0], [1, -6.0]],
		"@root": [[0, Vector2(0, 2)], [0.25, Vector2(0, -2)], [0.55, Vector2(0, 4)], [0.8, Vector2(0, -1)], [1, Vector2(0, 2)]]}}
	c["alert"] = {"len": 0.3, "loop": false, "tracks": {
		"spine": [[0, 6.0], [1, -10.0]], "head": [[0, 10.0], [1, -16.0]],
		"shoulder_f": [[0, 0.0], [1, -40.0]], "forearm_f": [[0, 0.0], [1, -25.0]],
		"shoulder_b": [[0, 0.0], [1, -55.0]], "forearm_b": [[0, 0.0], [1, -20.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(0, -4)]]}}
	# 0.4 s pounce wind-up: rear back, both claws up
	c["windup"] = {"len": 0.4, "loop": false, "tracks": {
		"spine": [[0, 0.0], [1, -16.0]], "head": [[0, 0.0], [1, -12.0]],
		"shoulder_f": [[0, 0.0], [1, -120.0]], "forearm_f": [[0, 0.0], [1, -30.0]],
		"shoulder_b": [[0, 0.0], [1, -140.0]], "forearm_b": [[0, 0.0], [1, -40.0]],
		"thigh_f": [[0, 0.0], [1, -22.0]], "shin_f": [[0, 0.0], [1, 36.0]],
		"thigh_b": [[0, 0.0], [1, 10.0]], "shin_b": [[0, 0.0], [1, 18.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-10, 10)]]}}
	return c


static func elite() -> Dictionary:
	var c := {}
	c["idle"] = {"len": 2.8, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, 2.5], [1, 0.0]], "head": [[0, 0.0], [0.5, -2.0], [1, 0.0]],
		"shoulder_f": [[0, 0.0], [0.5, 3.0], [1, 0.0]], "shoulder_b": [[0, 0.0], [0.5, -3.0], [1, 0.0]],
		"@root": [[0, Vector2.ZERO], [0.5, Vector2(0, 3)], [1, Vector2.ZERO]]}}
	# heavy stomp: long stance, body drops hard on each footfall, cleaver drags
	c["walk"] = {"len": 1.3, "loop": true, "tracks": {
		"thigh_f": _c([[0.0, -18.0], [0.5, 12.0]], 0.0), "shin_f": _c([[0.0, 4.0], [0.6, 8.0], [0.8, 30.0]], 0.0),
		"thigh_b": _c([[0.0, -18.0], [0.5, 12.0]], 0.5), "shin_b": _c([[0.0, 4.0], [0.6, 8.0], [0.8, 30.0]], 0.5),
		"shoulder_f": _c([[0.0, 6.0], [0.5, -4.0]], 0.0), "weapon": _c([[0.0, -4.0], [0.5, 4.0]], 0.0),
		"shoulder_b": _c([[0.0, -8.0], [0.5, 8.0]], 0.0),
		"spine": [[0, 3.0], [0.1, 6.0], [0.5, 3.0], [0.6, 6.0], [1, 3.0]],
		"@root": [[0, Vector2(0, 2)], [0.08, Vector2(0, 7)], [0.3, Vector2(0, -2)], [0.5, Vector2(0, 2)],
			[0.58, Vector2(0, 7)], [0.8, Vector2(0, -2)], [1, Vector2(0, 2)]]}}
	# overhead chop: cleaver hauled up and back over the shoulder (0.8 s)
	c["windup_chop"] = {"len": 0.8, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [0.6, 160.0], [1, 172.0]], "forearm_f": [[0, 0.0], [1, -40.0]], "weapon": [[0, 0.0], [1, 30.0]],
		"shoulder_b": [[0, 0.0], [1, -60.0]], "forearm_b": [[0, 0.0], [1, -30.0]],
		"spine": [[0, 0.0], [1, -14.0]], "head": [[0, 0.0], [1, -10.0]],
		"thigh_f": [[0, 0.0], [1, -16.0]], "shin_f": [[0, 0.0], [1, 20.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-8, -4)]]}}
	c["recover_chop"] = {"len": 1.0, "loop": false, "tracks": {
		"shoulder_f": [[0, -70.0], [0.7, -60.0], [1, -20.0]], "forearm_f": [[0, -20.0], [1, 0.0]], "weapon": [[0, 20.0], [1, 0.0]],
		"spine": [[0, 26.0], [0.7, 22.0], [1, 8.0]], "head": [[0, 10.0], [1, 0.0]],
		"thigh_f": [[0, -30.0], [1, -10.0]], "shin_f": [[0, 50.0], [1, 15.0]],
		"thigh_b": [[0, 20.0], [1, 6.0]], "shin_b": [[0, 30.0], [1, 10.0]],
		"@root": [[0, Vector2(10, 22)], [0.7, Vector2(8, 18)], [1, Vector2(0, 4)]]}}
	# horizontal sweep: draw back (0.65 s), then a fast rig-driven swing
	c["windup_sweep"] = {"len": 0.65, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [1, 95.0]], "forearm_f": [[0, 0.0], [1, -20.0]], "weapon": [[0, 0.0], [1, 70.0]],
		"spine": [[0, 0.0], [1, -10.0]], "shoulder_b": [[0, 0.0], [1, -30.0]],
		"thigh_f": [[0, 0.0], [1, -20.0]], "shin_f": [[0, 0.0], [1, 26.0]], "thigh_b": [[0, 0.0], [1, 14.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-12, 8)]]}}
	c["sweep"] = {"len": 0.18, "loop": false, "tracks": {
		"shoulder_f": [[0, 95.0], [0.6, -90.0], [1, -105.0]], "forearm_f": [[0, -20.0], [1, -10.0]], "weapon": [[0, 70.0], [0.6, -20.0], [1, -30.0]],
		"spine": [[0, -10.0], [1, 16.0]], "shoulder_b": [[0, -30.0], [1, 30.0]],
		"thigh_f": [[0, -20.0], [1, -34.0]], "shin_f": [[0, 26.0], [1, 40.0]], "thigh_b": [[0, 14.0], [1, 26.0]],
		"@root": [[0, Vector2(-12, 8)], [1, Vector2(14, 14)]]}}
	c["recover_sweep"] = {"len": 0.8, "loop": false, "tracks": {
		"shoulder_f": [[0, -105.0], [0.5, -95.0], [1, -10.0]], "weapon": [[0, -30.0], [1, 0.0]],
		"spine": [[0, 16.0], [1, 4.0]], "thigh_f": [[0, -34.0], [1, -8.0]], "shin_f": [[0, 40.0], [1, 10.0]],
		"@root": [[0, Vector2(14, 14)], [1, Vector2(0, 2)]]}}
	# armour broken: drops to one knee, head bowed (punish window)
	c["kneel"] = {"len": 0.35, "loop": false, "tracks": {
		"spine": [[0, 0.0], [1, 30.0]], "head": [[0, 0.0], [1, 22.0]],
		"thigh_f": [[0, 0.0], [1, -70.0]], "shin_f": [[0, 0.0], [1, 100.0]],
		"thigh_b": [[0, 0.0], [1, 30.0]], "shin_b": [[0, 0.0], [1, 90.0]],
		"shoulder_f": [[0, 0.0], [1, -20.0]], "weapon": [[0, 0.0], [1, -50.0]],
		"shoulder_b": [[0, 0.0], [1, -10.0]], "forearm_b": [[0, 0.0], [1, -30.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(4, 52)]]}}
	c["roar"] = {"len": 1.1, "loop": false, "tracks": {
		"spine": [[0, 0.0], [0.3, -22.0], [1, -18.0]], "head": [[0, 0.0], [0.3, -26.0], [1, -20.0]],
		"shoulder_f": [[0, 0.0], [0.3, -60.0], [1, -50.0]], "shoulder_b": [[0, 0.0], [0.3, 70.0], [1, 60.0]],
		"forearm_b": [[0, 0.0], [0.3, -40.0], [1, -35.0]],
		"@root": [[0, Vector2.ZERO], [0.3, Vector2(0, -8)], [1, Vector2(0, -6)]]}}
	c["recoil"] = {"len": 0.5, "loop": false, "tracks": {
		"spine": [[0, -16.0], [1, 0.0]], "head": [[0, -14.0], [1, 0.0]],
		"shoulder_f": [[0, 40.0], [1, 0.0]], "weapon": [[0, 30.0], [1, 0.0]],
		"@root": [[0, Vector2(-14, 4)], [1, Vector2.ZERO]]}}
	c["dead"] = {"len": 1.2, "loop": false, "tracks": {
		"spine": [[0, 0.0], [0.4, 26.0], [1, 48.0]], "head": [[0, 0.0], [1, 40.0]],
		"thigh_f": [[0, 0.0], [0.4, -70.0], [1, -80.0]], "shin_f": [[0, 0.0], [0.4, 100.0], [1, 120.0]],
		"thigh_b": [[0, 0.0], [0.4, 30.0], [1, 40.0]], "shin_b": [[0, 0.0], [0.4, 90.0], [1, 110.0]],
		"shoulder_f": [[0, 0.0], [1, -30.0]], "weapon": [[0, 0.0], [0.6, -60.0], [1, -80.0]],
		"shoulder_b": [[0, 0.0], [1, 30.0]],
		"@root": [[0, Vector2.ZERO], [0.4, Vector2(4, 52)], [1, Vector2(10, 90)]]}}
	return c


static func spitter() -> Dictionary:
	var c := {}
	c["idle"] = {"len": 2.0, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, -3.0], [1, 0.0]], "neck": [[0, 0.0], [0.5, -6.0], [1, 0.0]],
		"shoulder_b": [[0, 0.0], [0.5, 4.0], [1, 0.0]],
		"@root": [[0, Vector2.ZERO], [0.5, Vector2(0, 2)], [1, Vector2.ZERO]]}}
	c["walk"] = {"len": 1.3, "loop": true, "tracks": {
		"thigh_f": _c([[0.0, -14.0], [0.5, 12.0]], 0.0), "shin_f": _c([[0.0, 4.0], [0.75, 26.0]], 0.0),
		"thigh_b": _c([[0.0, -10.0], [0.5, 12.0]], 0.5), "shin_b": _c([[0.0, 4.0], [0.75, 22.0]], 0.5),
		"shoulder_b": _c([[0.0, -12.0], [0.5, 12.0]], 0.0),
		"spine": [[0, 2.0], [0.25, 6.0], [0.5, 2.0], [0.75, 6.0], [1, 2.0]],
		"neck": [[0, 0.0], [0.5, 8.0], [1, 0.0]],
		"@root": [[0, Vector2(0, 2)], [0.25, Vector2(0, -1)], [0.5, Vector2(0, 2)], [0.75, Vector2(0, -1)], [1, Vector2(0, 2)]]}}
	c["alert"] = {"len": 0.4, "loop": false, "tracks": {
		"neck": [[0, 0.0], [1, 14.0]], "head": [[0, 0.0], [1, -10.0]], "shoulder_b": [[0, 0.0], [1, -30.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(0, -3)]]}}
	# 0.9 s inhale: arch back, neck reared up to swell the sac
	c["windup"] = {"len": 0.9, "loop": false, "tracks": {
		"spine": [[0, 0.0], [1, -20.0]], "neck": [[0, 0.0], [1, -34.0]], "head": [[0, 0.0], [1, -16.0]],
		"shoulder_b": [[0, 0.0], [1, 30.0]], "thigh_f": [[0, 0.0], [1, -12.0]], "shin_f": [[0, 0.0], [1, 16.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-8, -6)]]}}
	c["recover"] = {"len": 1.2, "loop": false, "tracks": {
		"spine": [[0, 22.0], [0.8, 18.0], [1, 6.0]], "neck": [[0, 30.0], [0.8, 24.0], [1, 6.0]], "head": [[0, 14.0], [1, 0.0]],
		"shoulder_b": [[0, -20.0], [1, 0.0]], "thigh_f": [[0, -10.0], [1, 0.0]], "shin_f": [[0, 20.0], [1, 0.0]],
		"@root": [[0, Vector2(6, 10)], [1, Vector2.ZERO]]}}
	c["hit"] = {"len": 0.4, "loop": false, "tracks": {
		"spine": [[0, -18.0], [1, -4.0]], "neck": [[0, -20.0], [1, 0.0]], "shoulder_b": [[0, 30.0], [1, 0.0]],
		"@root": [[0, Vector2(-8, 4)], [1, Vector2.ZERO]]}}
	return c


static func husk() -> Dictionary:
	var c := {}
	c["idle"] = {"len": 3.2, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, 1.0], [1, 0.0]], "head": [[0, 0.0], [0.5, 2.0], [1, 0.0]],
		"@root": [[0, Vector2.ZERO], [0.5, Vector2(0, 0.6)], [1, Vector2.ZERO]]}}
	# stiff ritual step: little knee bend, the body stays upright, arm held out
	c["walk"] = {"len": 1.6, "loop": true, "tracks": {
		"thigh_f": _c([[0.0, -12.0], [0.5, 10.0]], 0.0), "shin_f": _c([[0.0, 2.0], [0.75, 14.0]], 0.0),
		"thigh_b": _c([[0.0, -12.0], [0.5, 10.0]], 0.5), "shin_b": _c([[0.0, 2.0], [0.75, 14.0]], 0.5),
		"shoulder_f": [[0, -4.0], [0.5, 4.0], [1, -4.0]],
		"spine": [[0, 0.0], [0.25, 2.0], [0.5, 0.0], [0.75, 2.0], [1, 0.0]],
		"head": [[0, 0.0], [0.5, -3.0], [1, 0.0]],
		"@root": [[0, Vector2(0, 1)], [0.25, Vector2(0, -1)], [0.5, Vector2(0, 1)], [0.75, Vector2(0, -1)], [1, Vector2(0, 1)]]}}
	c["awaken"] = {"len": 0.9, "loop": false, "tracks": {
		"spine": [[0, 6.0], [0.3, -12.0], [1, 0.0]], "head": [[0, 12.0], [0.3, -18.0], [1, 0.0]],
		"shoulder_f": [[0, 60.0], [0.3, -40.0], [1, 0.0]],
		"@root": [[0, Vector2(0, 4)], [0.3, Vector2(0, -4)], [1, Vector2.ZERO]]}}
	# 0.55 s: sleeve drawn back and up
	c["windup"] = {"len": 0.55, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [1, -70.0]], "forearm_f": [[0, 0.0], [1, -40.0]],
		"spine": [[0, 0.0], [1, -10.0]], "head": [[0, 0.0], [1, -6.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-4, 2)]]}}
	c["hit"] = {"len": 0.5, "loop": false, "tracks": {
		"spine": [[0, -14.0], [1, 0.0]], "head": [[0, -10.0], [1, 0.0]], "shoulder_f": [[0, 40.0], [1, 0.0]],
		"@root": [[0, Vector2(-5, 2)], [1, Vector2.ZERO]]}}
	return c


static func crawler() -> Dictionary:
	var c := {}
	c["idle"] = {"len": 1.6, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, -3.0], [1, 0.0]], "head": [[0, 0.0], [0.3, -8.0], [0.6, 4.0], [1, 0.0]],
		"@root": [[0, Vector2.ZERO], [0.5, Vector2(0, -1.5)], [1, Vector2.ZERO]]}}
	# fast diagonal-pair scuttle: long forelimbs reach and drag the body forward
	var reach := [[0.0, -38.0], [0.5, 26.0]]
	var claw := [[0.0, -10.0], [0.3, 20.0], [0.7, -30.0]]
	c["walk"] = {"len": 0.38, "loop": true, "tracks": {
		"fore_f": _c(reach, 0.0), "claw_f": _c(claw, 0.0),
		"fore_b": _c(reach, 0.5), "claw_b": _c(claw, 0.5),
		"hind_b": _c([[0.0, 22.0], [0.5, -18.0]], 0.0), "hfoot_b": _c([[0.0, 0.0], [0.6, -24.0]], 0.0),
		"hind_f": _c([[0.0, 22.0], [0.5, -18.0]], 0.5), "hfoot_f": _c([[0.0, 0.0], [0.6, -24.0]], 0.5),
		"spine": [[0, -4.0], [0.25, 3.0], [0.5, -4.0], [0.75, 3.0], [1, -4.0]],
		"head": [[0, 4.0], [0.5, -4.0], [1, 4.0]],
		"@root": [[0, Vector2(0, 0)], [0.25, Vector2(0, -4)], [0.5, Vector2(0, 0)], [0.75, Vector2(0, -4)], [1, Vector2(0, 0)]]}}
	c["alert"] = {"len": 0.3, "loop": false, "tracks": {
		"spine": [[0, 0.0], [1, -26.0]], "head": [[0, 0.0], [1, -20.0]],
		"fore_f": [[0, 0.0], [1, -50.0]], "claw_f": [[0, 0.0], [1, -40.0]],
		"fore_b": [[0, 0.0], [1, -30.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(0, -8)]]}}
	# coiled crouch before the pounce
	c["prep"] = {"len": 0.26, "loop": false, "tracks": {
		"spine": [[0, 0.0], [1, 10.0]], "head": [[0, 0.0], [1, 12.0]],
		"hind_b": [[0, 0.0], [1, 30.0]], "hfoot_b": [[0, 0.0], [1, -30.0]],
		"hind_f": [[0, 0.0], [1, 30.0]], "hfoot_f": [[0, 0.0], [1, -30.0]],
		"fore_f": [[0, 0.0], [1, 20.0]], "fore_b": [[0, 0.0], [1, 20.0]],
		"@root": [[0, Vector2.ZERO], [1, Vector2(-6, 8)]]}}
	return c
