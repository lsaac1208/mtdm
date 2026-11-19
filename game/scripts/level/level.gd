extends Node2D
## Builds and runs the demo level from LevelData: parallax wasteland,
## ground/platforms, hazards, props, checkpoints (篝火调息点), encounters,
## camera, zone atmosphere, death/respawn and the ending trigger.

const PlayerScript := preload("res://scripts/actors/player.gd")
const Checkpoint := preload("res://scripts/level/checkpoint.gd")
const Puddle := preload("res://scripts/fx/taint_puddle.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const RouteArt := preload("res://scripts/level/painted_route.gd")
const ZONE_BLEND := 320.0


## Weight of each zone's background set at world x (smooth crossfade at borders).
func zone_weights(x: float) -> Array:
	var n: int = LevelData.ZONES.size()
	var w := []
	w.resize(n)
	w.fill(0.0)
	var i := 0
	for k in n:
		if x >= LevelData.ZONES[k].x:
			i = k
	w[i] = 1.0
	if i + 1 < n:
		var b: float = LevelData.ZONES[i + 1].x
		var t := smoothstep(b - ZONE_BLEND, b + ZONE_BLEND, x)
		w[i] = 1.0 - t
		w[i + 1] = t
	if i > 0:
		var b0: float = LevelData.ZONES[i].x
		var t0 := smoothstep(b0 - ZONE_BLEND, b0 + ZONE_BLEND, x)
		w[i - 1] = 1.0 - t0
		w[i] = minf(w[i], t0)
	return w


## Smoothly blended directional 2.5D character lighting for `world_pos`,
## combining the interpolated zone palette with the strongest nearby dynamic
## light source (flickering campfire, active talisman barrier, or taint mire).
func zone_light(world_pos: Vector2) -> Dictionary:
	var w: Array = zone_weights(world_pos.x)
	var key_dir := Vector3.ZERO
	var key := Color(0, 0, 0, 1)
	var shadow := Color(0, 0, 0, 1)
	var rim := Color(0, 0, 0, 1)
	var bounce := Color(0, 0, 0, 1)
	var haze := Color(0, 0, 0, 0)
	var soil := Color(0, 0, 0, 1)
	var rim_str := 0.0
	var bounce_str := 0.0
	var shadow_lean := 0.0
	var wsum := 0.0
	for i in LevelData.ZONES.size():
		var wi: float = w[i]
		if wi <= 0.0001:
			continue
		var ld: Dictionary = LevelData.ZONES[i].light
		key_dir += (ld.key_dir as Vector3) * wi
		key += (ld.key as Color) * wi
		shadow += (ld.shadow as Color) * wi
		rim += (ld.rim as Color) * wi
		bounce += (ld.bounce as Color) * wi
		haze += (ld.haze as Color) * wi
		soil += (ld.soil as Color) * wi
		rim_str += float(ld.rim_str) * wi
		bounce_str += float(ld.bounce_str) * wi
		shadow_lean += float(ld.shadow_lean) * wi
		wsum += wi
	if wsum > 0.0001:
		key_dir /= wsum
		key /= wsum
		shadow /= wsum
		rim /= wsum
		bounce /= wsum
		haze /= wsum
		soil /= wsum
		rim_str /= wsum
		bounce_str /= wsum
		shadow_lean /= wsum
	else:
		key_dir = Vector3(0.62, -0.64, 0.45)
	key.a = 1.0
	shadow.a = 1.0
	rim.a = 1.0
	bounce.a = 1.0
	soil.a = 1.0

	var chest := world_pos + Vector2(0.0, -72.0)
	var pt_dir := Vector3(0.0, 0.0, 1.0)
	var pt_col := Color(1.0, 0.58, 0.22)
	var pt_str := 0.0
	for cp in checkpoints:
		if not is_instance_valid(cp):
			continue
		var fire_pos: Vector2 = cp.global_position + Vector2(0.0, -24.0)
		var d: Vector2 = fire_pos - chest
		var dist := d.length()
		if dist < 340.0:
			var flick := 0.88 + 0.12 * sin(cp.t * 11.5) * sin(cp.t * 6.7)
			var f := pow(1.0 - dist / 340.0, 1.65) * 0.92 * flick
			if f > pt_str:
				pt_str = f
				pt_col = Color(1.0, 0.58, 0.22)
				pt_dir = Vector3(d.x, d.y, 110.0).normalized()
	for enc in encounters:
		if not is_instance_valid(enc) or enc.state != "active":
			continue
		for bar in enc.barriers:
			if not is_instance_valid(bar):
				continue
			var bpos: Vector2 = bar.global_position + Vector2(0.0, -90.0)
			var d: Vector2 = bpos - chest
			var dist := d.length()
			if dist < 260.0:
				var pulse := 0.82 + 0.18 * sin(bar.t * 5.0)
				var f := pow(1.0 - dist / 260.0, 1.8) * 0.58 * pulse
				if f > pt_str:
					pt_str = f
					pt_col = Color(1.0, 0.80, 0.36)
					pt_dir = Vector3(d.x, d.y, 120.0).normalized()
	for pd in get_tree().get_nodes_in_group("taint_puddle"):
		if not is_instance_valid(pd):
			continue
		var max_r: float = pd.radius + 115.0
		var d: Vector2 = (pd.global_position + Vector2(0.0, -8.0)) - chest
		var dist := d.length()
		if dist < max_r:
			var f := pow(1.0 - dist / max_r, 1.7) * 0.26   # was 0.52: dyed the whole costume olive
			if f > pt_str:
				pt_str = f
				pt_col = Color(0.62, 0.92, 0.40)
				pt_dir = Vector3(d.x, d.y, 90.0).normalized()

	return {
		"key_dir": key_dir.normalized(),
		"key": key,
		"shadow": shadow,
		"rim": rim,
		"rim_str": rim_str,
		"bounce": bounce,
		"bounce_str": bounce_str,
		"haze": haze,
		"soil": soil,
		"shadow_lean": shadow_lean,
		"point_dir": pt_dir,
		"point_color": pt_col,
		"point_strength": pt_str,
	}

var player: Player
var cam: Camera2D
var encounters: Array = []
var checkpoints: Array = []
var hud: CanvasLayer
var route_art := RouteArt.new()
var fog_rect: ColorRect
var zone_idx := -1
var _shake := 0.0
var _shake_t := 0.0
var _cam_bounds := Vector2(0, LevelData.LENGTH)
var _respawning := false
var _ending := false
var _sign_shown := {}
var _cam_x := 0.0
var _cam_y := 0.0
var _cam_look := 110.0
var _kick := Vector2.ZERO
var _kick_t := 0.0
var _kick_len := 0.11


func _ready() -> void:
	Game.level = self
	add_child(route_art)
	for n in ["Props", "Actors", "Fx"]:
		var node := Node2D.new()
		node.name = n
		add_child(node)
	$Props.z_index = 2
	$Fx.z_index = 10
	_build_ground()
	_build_platforms()
	for pl in LevelData.POOLS:
		var pd := Puddle.new()
		pd.permanent = true
		pd.radius = pl[1]
		pd.dps = 7.0
		pd.position = Vector2(pl[0], Game.GROUND_Y)
		$Props.add_child(pd)
	for c in LevelData.CHECKPOINTS:
		var cp := Checkpoint.new()
		cp.cp_id = c.id
		cp.position = Vector2(c.x, Game.GROUND_Y)
		$Props.add_child(cp)
		checkpoints.append(cp)
	for s in LevelData.SIGNS:
		_add_sign(s)
	_build_gate()
	player = PlayerScript.new()
	var start_x: float = LevelData.CHECKPOINTS[Game.checkpoint_id].x + 60.0
	if Game.args.has("startx"):
		start_x = float(Game.args.startx)
	player.position = Vector2(start_x, Game.GROUND_Y - 2)
	$Actors.add_child(player)
	player.died.connect(_on_player_died)
	if Game.args.has("startx") and Game.args.has("skip_cleared"):
		for e in LevelData.ENCOUNTERS:
			var right: float = e.lock[1] if e.lock.size() == 2 else e.enemies[0][1]
			if right < start_x:
				Game.cleared[e.id] = true
	for e in LevelData.ENCOUNTERS:
		var enc := Encounter.new()
		add_child(enc)
		enc.setup(e)
		encounters.append(enc)
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()
	_cam_x = player.position.x
	_cam_y = Game.GROUND_Y - 190
	_cam_look = player.facing * 110.0
	cam.global_position = Vector2(_cam_x, _cam_y)
	cam.reset_physics_interpolation()
	player.reset_physics_interpolation()
	_build_motes()
	_build_overlay()
	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	add_child(PauseMenu.new())
	Sfx.play_ambience("amb_wind")
	_update_zone(true)


# ------------------------------------------------------------------ build
var motes: CPUParticles2D


func _build_motes() -> void:
	motes = CPUParticles2D.new()
	motes.amount = 220
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(720, 380)
	motes.direction = Vector2(-1, 0)
	motes.spread = 40.0
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 30.0
	motes.scale_amount_min = 2.5
	motes.scale_amount_max = 6.5
	motes.z_index = 15
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.8, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	motes.color_ramp = g
	var dot := GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	motes.texture = dot
	motes.scale_amount_min = 0.25
	motes.scale_amount_max = 0.6
	add_child(motes)


func _set_motes(z: Dictionary) -> void:
	if motes == null or not z.has("motes"):
		return
	var m: Array = z.motes
	motes.color = m[0]
	motes.gravity = Vector2(-6.0, m[1])
	motes.initial_velocity_max = 10.0 + m[2] * 3.0


func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 3
	add_child(cl)
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/atmosphere.gdshader")
	fog_rect.material = m
	cl.add_child(fog_rect)


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 1
	add_child(body)
	for g in LevelData.GROUND:
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(g[1] - g[0], 600)
		cs.shape = s
		cs.position = Vector2((g[0] + g[1]) / 2.0, g[2] + 300)
		body.add_child(cs)
		route_art.add_soil(g[0], g[1], g[2])


func _build_platforms() -> void:
	var body := StaticBody2D.new()
	body.name = "Platforms"
	add_child(body)
	for p in LevelData.PLATFORMS:
		var w: float = p[1] - p[0]
		var h: float = Game.GROUND_Y - p[2] + 10.0
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(w, h)
		cs.shape = s
		cs.position = Vector2(p[0] + w / 2.0, p[2] + h / 2.0)
		body.add_child(cs)
		# Keep the painting's own proportions: scale to the block height and
		# build the block from the painting's left and right ends, meeting
		# in the middle, instead of squashing the whole image to fit.
		var tex: Texture2D = route_art.texture(p[3])
		var sc := h / float(tex.get_height())
		var half_src := minf(w * 0.5 / sc, tex.get_width() * 0.5)
		var zi := 0
		for k in LevelData.ZONES.size():
			if p[0] >= LevelData.ZONES[k].x:
				zi = k
		var lt: Dictionary = LevelData.ZONES[zi].light
		var shade: Color = (lt.shadow as Color).lerp(Color.WHITE, 0.42)
		for side in 2:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.region_enabled = true
			# each half is 2 px wider than w/2 so the two overlap at the seam
			var src_w := half_src + 2.0 / sc
			var src_x := 0.0 if side == 0 else tex.get_width() - src_w
			sprite.region_rect = Rect2(src_x, 0, src_w, tex.get_height())
			sprite.scale = Vector2.ONE * sc
			sprite.position = Vector2(p[0] + (0.0 if side == 0 else w * 0.5 - 2.0), p[2])
			sprite.z_index = 2
			# Sit the painted block in its zone's light: the raw paintings are
			# fully saturated and read as pasted-on next to the hazy backdrop.
			sprite.modulate = Color(shade.r, shade.g, shade.b, 1.0)
			add_child(sprite)
		var contact := Sprite2D.new()
		contact.texture = Fx.dot_texture()
		contact.scale = Vector2(w * 1.18, 22.0) / 24.0 * 1.5
		contact.position = Vector2(p[0] + w * 0.5, Game.GROUND_Y + 1.0)
		contact.modulate = Color(0.10, 0.07, 0.05, 0.38)
		contact.z_index = 1
		add_child(contact)


func _add_sign(s: Dictionary) -> void:
	var marker := Sprite2D.new()
	marker.texture = route_art.texture(s.art)
	var height := 78.0 if s.x == 470.0 else 56.0
	marker.scale = Vector2.ONE * height / marker.texture.get_height()
	marker.offset.y = -marker.texture.get_height() * 0.5
	marker.position = Vector2(s.x, Game.GROUND_Y + 1.0)
	$Props.add_child(marker)


func _build_gate() -> void:
	var g := preload("res://scripts/level/end_gate.gd").new()
	g.position = Vector2(LevelData.END_X, Game.GROUND_Y)
	$Props.add_child(g)


# ------------------------------------------------------------------ runtime
var _punch := 0.0
var _punch_t := 0.0
var _punch_len := 0.2


func punch(amount: float, dur: float) -> void:
	if Game.args.has("noshake") or Game.shake_scale <= 0.0:
		return
	amount *= Game.shake_scale
	_punch = maxf(_punch if _punch_t > 0.0 else 0.0, amount)
	_punch_t = dur
	_punch_len = dur


func shake(amount: float, dur: float) -> void:
	if Game.args.has("noshake") or Game.shake_scale <= 0.0:
		return
	amount *= Game.shake_scale
	_shake = maxf(_shake, amount)
	_shake_t = maxf(_shake_t, dur)


func kick(vec: Vector2, dur := 0.11) -> void:
	if Game.args.has("noshake") or Game.shake_scale <= 0.0:
		return
	_kick = vec * Game.shake_scale
	_kick_t = dur
	_kick_len = maxf(dur, 0.01)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_update_camera(delta)
	_update_zone(false)
	_update_signs()
	if not _ending and Game.cleared.has("e8_elite") and player.global_position.x >= LevelData.END_X - 20 and not player.dead:
		_finish()


func _process(delta: float) -> void:
	var udt := Game.unscaled_delta(delta)
	if Game.args.has("noshake") or Game.shake_scale <= 0.0:
		_shake = 0.0
		_shake_t = 0.0
		_kick = Vector2.ZERO
		_kick_t = 0.0
		_punch = 0.0
		_punch_t = 0.0
	_shake_t = maxf(0.0, _shake_t - udt)
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		_shake = 0.0
	if _kick_t > 0.0:
		_kick_t = maxf(0.0, _kick_t - udt)
		var kk := sin(PI * clampf(1.0 - _kick_t / _kick_len, 0.0, 1.0))
		off += _kick * kk
	else:
		_kick = Vector2.ZERO
	cam.offset = off
	if _punch_t > 0.0:
		_punch_t = maxf(0.0, _punch_t - udt)
		var z := 1.0 + _punch * sin(PI * (1.0 - _punch_t / _punch_len))
		cam.zoom = Vector2(z, z)
	else:
		cam.zoom = Vector2.ONE
	var vs := get_viewport().get_visible_rect().size
	var cpos := cam.get_screen_center_position()
	route_art.follow(cpos, vs, zone_weights(cpos.x))


func _update_camera(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var lo := -200.0 + vs.x / 2.0
	var hi := LevelData.LENGTH + 200.0 - vs.x / 2.0
	for enc in encounters:
		var b: Array = enc.locked_bounds()
		if b.size() == 2:
			lo = b[0] - 60.0 + vs.x / 2.0
			hi = b[1] + 60.0 - vs.x / 2.0
			if hi < lo:
				var m := (lo + hi) / 2.0
				lo = m
				hi = m
	var ppos := player.global_position
	_cam_look = lerpf(_cam_look, player.facing * 110.0, 1.0 - exp(-5.5 * delta))
	var tx := clampf(ppos.x + _cam_look, lo, hi)
	_cam_x = lerpf(_cam_x, tx, 1.0 - exp(-6.5 * delta))
	var ty := minf(Game.GROUND_Y - 190.0, ppos.y - 150.0)
	_cam_y = lerpf(_cam_y, ty, 1.0 - exp(-4.8 * delta))
	cam.global_position = Vector2(_cam_x, _cam_y)
	if motes:
		motes.global_position = cam.global_position


func _update_zone(force: bool) -> void:
	var x := player.global_position.x
	var idx := 0
	for i in LevelData.ZONES.size():
		if x >= LevelData.ZONES[i].x:
			idx = i
	if idx != zone_idx or force:
		var first := zone_idx == -1
		zone_idx = idx
		var z: Dictionary = LevelData.ZONES[idx]
		if not first or force:
			Game.zone_entered.emit(z.cn, z.en)
		Sfx.play_music(z.music)
		Sfx.play_ambience(z.get("amb", "amb_wind"))
		_set_motes(z)
	# smooth atmosphere blend toward the current zone
	var z2: Dictionary = LevelData.ZONES[zone_idx]
	if fog_rect:
		var m: ShaderMaterial = fog_rect.material
		var cur: Color = m.get_shader_parameter("fog_color") if m.get_shader_parameter("fog_color") != null else z2.fog
		m.set_shader_parameter("fog_color", cur.lerp(z2.fog, 0.02 if not force else 1.0))
		m.set_shader_parameter("cam_x", cam.global_position.x if cam else 0.0)


func _update_signs() -> void:
	for s in LevelData.SIGNS:
		var near := absf(player.global_position.x - s.x) < 120.0
		if near and not _sign_shown.get(s.x, false):
			_sign_shown[s.x] = true
			Game.show_hint(s.text, 6.0)
		elif not near and absf(player.global_position.x - s.x) > 400.0:
			_sign_shown[s.x] = false


func resume_zone_music() -> void:
	Sfx.play_music(LevelData.ZONES[maxi(zone_idx, 0)].music)


func active_encounter_id() -> String:
	for enc in encounters:
		if enc.state == "active":
			return enc.data.id
	return ""


func _on_player_died() -> void:
	var eid := active_encounter_id()
	if eid != "":
		Game.tel_enc(eid, "deaths", 1.0)
	if _respawning:
		return
	_respawning = true
	Game.deaths += 1
	print("DEATH x=%.0f zone=%s cp=%d" % [player.global_position.x, LevelData.ZONES[maxi(zone_idx, 0)].en, Game.checkpoint_id])
	await get_tree().create_timer(1.4).timeout
	await hud.fade_out(0.6)
	for enc in encounters:
		enc.reset()
	for p in get_tree().get_nodes_in_group("taint_puddle"):
		if not p.permanent:
			p.queue_free()
	Game.boss_changed.emit(null)
	var cpx: float = LevelData.CHECKPOINTS[Game.checkpoint_id].x
	player.respawn_at(Vector2(cpx + 50.0, Game.GROUND_Y - 4))
	player.reset_physics_interpolation()
	_cam_x = player.global_position.x
	_cam_look = player.facing * 110.0
	cam.global_position = Vector2(_cam_x, _cam_y)
	cam.reset_physics_interpolation()
	await hud.fade_in(0.6)
	Game.show_hint("篝火余温尚在……再来。", 3.0)
	_respawning = false


func _finish() -> void:
	_ending = true
	player.controls_locked = true
	Sfx.play("ending_chime", 0.0)
	await hud.fade_out(1.6, Color(0.92, 0.86, 0.72))
	Game.finish_demo()
