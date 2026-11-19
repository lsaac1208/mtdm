class_name HeroClips
extends RefCounted
## Keyframed clips for the hero cut-out rig (tools/rig/hero_rig_def.py).
## Angles are degrees added to the bone rest pose; "@root" is a pixel offset
## of the root bone in rig (source-art) pixels. Times are normalized 0..1.
##
## Sign conventions (bones hang down / point up in the rest pose, y-down):
##   legs & arms (pointing down): negative = swing forward (toward facing)
##   spine/neck/head (pointing up): positive = lean forward
##   shin/forearm: positive = bend backward (knee) / negative = elbow forward

static func _cycle(keys: Array, phase: float) -> Array:
	# shift a looping key list by `phase` (0..1), keeping it sorted and closed
	var out := []
	for k in keys:
		out.append([fposmod(k[0] + phase, 1.0), k[1]])
	out.sort_custom(func(a, b): return a[0] < b[0])
	var first = out[0][1]
	var last = out[out.size() - 1][1]
	# boundary keys so the curve wraps cleanly
	var t0: float = out[0][0]
	var t1: float = out[out.size() - 1][0]
	var span := (1.0 - t1) + t0
	var edge = lerp(last, first, (1.0 - t1) / maxf(span, 0.001)) if span > 0.0 else first
	if t0 > 0.0:
		out.push_front([0.0, edge])
	if t1 < 1.0:
		out.append([1.0, edge])
	return out


static func clips() -> Dictionary:
	var c := {}
	# ---------------------------------------------------------------- idle
	c["idle"] = {"len": 2.6, "loop": true, "tracks": {
		"spine": [[0, 0.0], [0.5, 1.6], [1, 0.0]],
		"neck": [[0, 0.0], [0.5, -1.0], [1, 0.0]],
		"head": [[0, 0.0], [0.55, 1.2], [1, 0.0]],
		"shoulder_f": [[0, 0.0], [0.5, -2.0], [1, 0.0]],
		"forearm_f": [[0, 0.0], [0.5, -2.5], [1, 0.0]],
		"shoulder_b": [[0, 0.0], [0.5, 2.0], [1, 0.0]],
		"forearm_b": [[0, 0.0], [0.5, 1.5], [1, 0.0]],
		"@root": [[0, Vector2(0, 0)], [0.5, Vector2(0, 1.6)], [1, Vector2(0, 0)]],
	}}
	# ---------------------------------------------------------------- run / walk
	var run_thigh := [[0.0, -30.0], [0.25, -6.0], [0.5, 26.0], [0.75, -2.0]]
	var run_shin := [[0.0, 6.0], [0.18, 14.0], [0.45, 24.0], [0.65, 80.0], [0.85, 30.0]]
	var run_arm := [[0.0, 26.0], [0.5, -30.0]]
	var run_fore := [[0.0, 6.0], [0.5, -48.0]]
	c["run"] = {"len": 0.56, "loop": true, "tracks": {
		"thigh_f": _cycle(run_thigh, 0.0), "shin_f": _cycle(run_shin, 0.0),
		"thigh_b": _cycle(run_thigh, 0.5), "shin_b": _cycle(run_shin, 0.5),
		"shoulder_f": _cycle([[0.0, 20.0], [0.5, -16.0]], 0.0), "forearm_f": _cycle([[0.0, 4.0], [0.5, -18.0]], 0.0),
		"sword": _cycle([[0.0, 18.0], [0.5, 34.0]], 0.0),
		"shoulder_b": _cycle(run_arm, 0.5), "forearm_b": _cycle(run_fore, 0.5),
		"spine": [[0, 9.0], [0.25, 11.0], [0.5, 9.0], [0.75, 11.0], [1, 9.0]],
		"head": [[0, -4.0], [0.25, -5.5], [0.5, -4.0], [0.75, -5.5], [1, -4.0]],
		"@root": [[0, Vector2(0, 7)], [0.12, Vector2(0, 9)], [0.32, Vector2(0, -3)], [0.5, Vector2(0, 7)],
			[0.62, Vector2(0, 9)], [0.82, Vector2(0, -3)], [1, Vector2(0, 7)]],
	}}
	var walk_thigh := [[0.0, -20.0], [0.5, 18.0]]
	var walk_shin := [[0.0, 4.0], [0.4, 10.0], [0.7, 38.0], [0.9, 10.0]]
	c["walk"] = {"len": 1.0, "loop": true, "tracks": {
		"thigh_f": _cycle(walk_thigh, 0.0), "shin_f": _cycle(walk_shin, 0.0),
		"thigh_b": _cycle(walk_thigh, 0.5), "shin_b": _cycle(walk_shin, 0.5),
		"shoulder_f": _cycle([[0.0, 12.0], [0.5, -12.0]], 0.0),
		"shoulder_b": _cycle([[0.0, 12.0], [0.5, -12.0]], 0.5),
		"spine": [[0, 3.0], [1, 3.0]],
		"@root": [[0, Vector2(0, 3)], [0.25, Vector2(0, -1)], [0.5, Vector2(0, 3)], [0.75, Vector2(0, -1)], [1, Vector2(0, 3)]],
	}}
	# ---------------------------------------------------------------- air
	c["jump"] = {"len": 0.35, "loop": false, "tracks": {
		"thigh_f": [[0, -14.0], [1, -46.0]], "shin_f": [[0, 22.0], [1, 72.0]],
		"thigh_b": [[0, -4.0], [1, -8.0]], "shin_b": [[0, 18.0], [1, 34.0]],
		"shoulder_f": [[0, 0.0], [1, -35.0]], "forearm_f": [[0, 0.0], [1, -40.0]],
		"shoulder_b": [[0, 0.0], [1, 30.0]], "forearm_b": [[0, 0.0], [1, -20.0]],
		"spine": [[0, 4.0], [1, 6.0]], "head": [[0, 0.0], [1, -6.0]],
		"@root": [[0, Vector2(0, 0)], [1, Vector2(0, -6)]],
	}}
	c["fall"] = {"len": 0.4, "loop": false, "tracks": {
		"thigh_f": [[0, -46.0], [1, -20.0]], "shin_f": [[0, 72.0], [1, 26.0]],
		"thigh_b": [[0, -8.0], [1, -2.0]], "shin_b": [[0, 34.0], [1, 16.0]],
		"shoulder_f": [[0, -35.0], [1, -55.0]], "forearm_f": [[0, -40.0], [1, -20.0]],
		"shoulder_b": [[0, 30.0], [1, 45.0]], "forearm_b": [[0, -20.0], [1, -10.0]],
		"spine": [[0, 6.0], [1, 2.0]], "head": [[0, -6.0], [1, 2.0]],
	}}
	c["land"] = {"len": 0.22, "loop": false, "tracks": {
		"thigh_f": [[0, -40.0], [0.4, -45.0], [1, -12.0]], "shin_f": [[0, 75.0], [0.4, 85.0], [1, 20.0]],
		"thigh_b": [[0, 25.0], [0.4, 30.0], [1, 8.0]], "shin_b": [[0, 60.0], [0.4, 70.0], [1, 18.0]],
		"spine": [[0, 14.0], [0.4, 16.0], [1, 4.0]],
		"shoulder_f": [[0, -20.0], [1, 0.0]], "shoulder_b": [[0, 25.0], [1, 0.0]],
		"@root": [[0, Vector2(0, 22)], [0.4, Vector2(0, 26)], [1, Vector2(0, 4)]],
	}}
	# ---------------------------------------------------------------- reactions
	c["hit"] = {"len": 0.35, "loop": false, "tracks": {
		"spine": [[0, -14.0], [0.3, -18.0], [1, -4.0]], "head": [[0, -10.0], [0.3, -14.0], [1, -2.0]],
		"shoulder_f": [[0, 25.0], [1, 8.0]], "forearm_f": [[0, -50.0], [1, -20.0]],
		"shoulder_b": [[0, 30.0], [1, 10.0]], "forearm_b": [[0, -45.0], [1, -15.0]],
		"thigh_f": [[0, -18.0], [1, -8.0]], "shin_f": [[0, 25.0], [1, 10.0]],
		"thigh_b": [[0, 22.0], [1, 10.0]], "shin_b": [[0, 30.0], [1, 12.0]],
		"@root": [[0, Vector2(-6, 6)], [1, Vector2(-2, 2)]],
	}}
	c["block"] = {"len": 0.2, "loop": false, "tracks": {
		"thigh_f": [[0, -6.0], [1, -26.0]], "shin_f": [[0, 10.0], [1, 46.0]],
		"thigh_b": [[0, 6.0], [1, 24.0]], "shin_b": [[0, 10.0], [1, 40.0]],
		"spine": [[0, 2.0], [1, 6.0]],
		"shoulder_f": [[0, 0.0], [1, -70.0]], "forearm_f": [[0, 0.0], [1, -70.0]],
		"sword": [[0, 0.0], [1, -95.0]],
		"shoulder_b": [[0, 0.0], [1, -40.0]], "forearm_b": [[0, 0.0], [1, -60.0]],
		"@root": [[0, Vector2(0, 2)], [1, Vector2(0, 14)]],
	}}
	c["dash"] = {"len": 0.22, "loop": false, "tracks": {
		"spine": [[0, 10.0], [1, 24.0]], "head": [[0, 0.0], [1, -10.0]],
		"thigh_f": [[0, -30.0], [1, -48.0]], "shin_f": [[0, 30.0], [1, 70.0]],
		"thigh_b": [[0, 30.0], [1, 48.0]], "shin_b": [[0, 20.0], [1, 30.0]],
		"shoulder_f": [[0, 10.0], [1, 40.0]], "sword": [[0, 0.0], [1, 30.0]],
		"shoulder_b": [[0, 10.0], [1, 45.0]],
		"@root": [[0, Vector2(0, 8)], [1, Vector2(0, 20)]],
	}}
	c["dead"] = {"len": 0.6, "loop": false, "tracks": {
		"spine": [[0, 6.0], [0.5, 28.0], [1, 34.0]], "head": [[0, 0.0], [1, 24.0]],
		"thigh_f": [[0, -20.0], [1, -70.0]], "shin_f": [[0, 30.0], [1, 120.0]],
		"thigh_b": [[0, 10.0], [1, 20.0]], "shin_b": [[0, 30.0], [1, 100.0]],
		"shoulder_f": [[0, 0.0], [1, -20.0]], "forearm_f": [[0, 0.0], [1, -30.0]], "sword": [[0, 0.0], [1, -40.0]],
		"shoulder_b": [[0, 0.0], [1, 10.0]],
		"@root": [[0, Vector2(0, 6)], [1, Vector2(0, 46)]],
	}}
	# ---------------------------------------------------------------- attack anticipation / recovery
	# (the contact frames use the painted action poses from concept sheet 02)
	c["windup_slash"] = {"len": 0.08, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [1, 115.0]], "forearm_f": [[0, 0.0], [1, -25.0]], "sword": [[0, 0.0], [1, 10.0]],
		"spine": [[0, 2.0], [1, -8.0]], "thigh_f": [[0, 0.0], [1, -20.0]], "shin_f": [[0, 0.0], [1, 30.0]],
		"thigh_b": [[0, 0.0], [1, 14.0]], "shin_b": [[0, 0.0], [1, 20.0]],
		"shoulder_b": [[0, 0.0], [1, 30.0]],
		"@root": [[0, Vector2(0, 0)], [1, Vector2(-4, 8)]],
	}}
	c["windup_over"] = {"len": 0.12, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [1, -175.0]], "forearm_f": [[0, 0.0], [1, -20.0]], "sword": [[0, 0.0], [1, 60.0]],
		"shoulder_b": [[0, 0.0], [1, -160.0]], "forearm_b": [[0, 0.0], [1, -30.0]],
		"spine": [[0, 2.0], [1, -10.0]], "head": [[0, 0.0], [1, -8.0]],
		"thigh_f": [[0, 0.0], [1, -22.0]], "shin_f": [[0, 0.0], [1, 30.0]],
		"@root": [[0, Vector2(0, 0)], [1, Vector2(0, -4)]],
	}}
	c["windup_thrust"] = {"len": 0.1, "loop": false, "tracks": {
		"shoulder_f": [[0, 0.0], [1, 45.0]], "forearm_f": [[0, 0.0], [1, -95.0]], "sword": [[0, 0.0], [1, -40.0]],
		"spine": [[0, 2.0], [1, -6.0]], "thigh_f": [[0, 0.0], [1, -30.0]], "shin_f": [[0, 0.0], [1, 40.0]],
		"thigh_b": [[0, 0.0], [1, 26.0]], "shin_b": [[0, 0.0], [1, 30.0]],
		"@root": [[0, Vector2(0, 0)], [1, Vector2(-8, 12)]],
	}}
	c["recover"] = {"len": 0.25, "loop": false, "tracks": {
		"shoulder_f": [[0, -40.0], [1, 0.0]], "forearm_f": [[0, -30.0], [1, 0.0]], "sword": [[0, -30.0], [1, 0.0]],
		"spine": [[0, 12.0], [1, 2.0]], "thigh_f": [[0, -28.0], [1, 0.0]], "shin_f": [[0, 40.0], [1, 0.0]],
		"thigh_b": [[0, 20.0], [1, 0.0]], "shin_b": [[0, 30.0], [1, 0.0]],
		"@root": [[0, Vector2(6, 14)], [1, Vector2(0, 0)]],
	}}
	c["cast"] = {"len": 0.12, "loop": false, "tracks": {
		"shoulder_b": [[0, 0.0], [1, -60.0]], "forearm_b": [[0, 0.0], [1, -70.0]],
		"shoulder_f": [[0, 0.0], [1, 20.0]], "spine": [[0, 2.0], [1, -4.0]],
		"@root": [[0, Vector2(0, 0)], [1, Vector2(-2, 4)]],
	}}
	return c
