extends Node2D
## Builds and runs the demo level from LevelData: parallax wasteland,
## ground/platforms, hazards, props, checkpoints (篝火调息点), encounters,
## camera, zone atmosphere, death/respawn and the ending trigger.

const PlayerScript := preload("res://scripts/actors/player.gd")
const Checkpoint := preload("res://scripts/level/checkpoint.gd")
const Puddle := preload("res://scripts/fx/taint_puddle.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const ENV := "res://assets/env/"

var player: Player
var cam: Camera2D
var encounters: Array = []
var checkpoints: Array = []
var hud: CanvasLayer
var bg_layers: Array = []     # [{node, factor, y, yf}]
var fg_layers: Array = []
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


func _ready() -> void:
	Game.level = self
	_build_background()
	for n in ["Props", "Actors", "Fx"]:
		var node := Node2D.new()
		node.name = n
		add_child(node)
	$Props.z_index = 2
	$Fx.z_index = 10
	_build_ground()
	_build_platforms()
	_build_props()
	for pl in LevelData.POOLS:
		var pd := Puddle.new()
		pd.permanent = true
		pd.radius = pl[1]
		pd.dps = 10.0
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
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()
	_cam_x = player.position.x
	_cam_y = Game.GROUND_Y - 190
	_build_foreground()
	_build_overlay()
	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	add_child(PauseMenu.new())
	Sfx.play_ambience("amb_wind")
	_update_zone(true)


# ------------------------------------------------------------------ build
func _tex(name_: String) -> Texture2D:
	var p := ENV + name_ + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _build_background() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	cl.name = "BG"
	add_child(cl)
	var sky := TextureRect.new()
	sky.texture = _tex("sky")
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(sky)
	bg_layers.append({"node": sky, "factor": 0.0, "sky": true})
	# [texture, scroll factor, top y on screen at rest, vertical factor]
	for l in [["far", 0.08, 150.0, 0.03], ["mid", 0.22, 205.0, 0.08], ["near", 0.45, 250.0, 0.2]]:
		var t := _tex(l[0])
		if t == null:
			continue
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		cl.add_child(s)
		bg_layers.append({"node": s, "factor": l[1], "y": l[2], "yf": l[3]})


func _build_foreground() -> void:
	var t := _tex("fore")
	if t == null:
		return
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.modulate = Color(1, 1, 1, 0.92)
	cl.add_child(s)
	fg_layers.append({"node": s, "factor": 1.35, "y": 560.0, "yf": 1.0})


func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 3
	add_child(cl)
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var gt := _tex("ground")
	for g in LevelData.GROUND:
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(g[1] - g[0], 600)
		cs.shape = s
		cs.position = Vector2((g[0] + g[1]) / 2.0, g[2] + 300)
		body.add_child(cs)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(g[0], g[2] - 14), Vector2(g[1], g[2] - 14), Vector2(g[1], g[2] + 520), Vector2(g[0], g[2] + 520)])
		if gt:
			poly.texture = gt
			poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			poly.texture_offset = Vector2(0, -(g[2] - 14))
		else:
			poly.color = Color(0.2, 0.17, 0.14)
		poly.z_index = 1
		add_child(poly)


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
		var t := _tex("plat_" + p[3])
		if t:
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			var sc := w / float(t.get_width())
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(p[0], Game.GROUND_Y + 8 - t.get_height() * sc)
			sp.z_index = 2
			add_child(sp)
		else:
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(p[0], p[2]), Vector2(p[1], p[2]), Vector2(p[1], Game.GROUND_Y), Vector2(p[0], Game.GROUND_Y)])
			poly.color = Color(0.25, 0.21, 0.17)
			poly.z_index = 2
			add_child(poly)


# decorative props: [texture, x, scale, z, flip]
const PROPS := [
	["prop_house", 120.0, 0.9, -1, false], ["prop_tree", 620.0, 0.85, -1, false], ["prop_house", 1380.0, 0.8, -1, true],
	["prop_well", 1900.0, 0.7, -1, false], ["prop_tree", 2260.0, 0.9, -1, true],
	["prop_post", 2600.0, 0.8, -1, false], ["prop_cart", 3330.0, 0.75, -1, false], ["prop_tree", 3720.0, 1.0, -1, false],
	["prop_post", 4100.0, 0.8, -1, true],
	["prop_deadtree", 4560.0, 0.9, -1, false], ["prop_bones", 4880.0, 0.7, 3, false], ["prop_deadtree", 5420.0, 1.0, -1, true],
	["prop_bones", 5800.0, 0.6, 3, true], ["prop_deadtree", 6420.0, 0.85, -1, false],
	["prop_gate", 6620.0, 1.0, -1, false], ["prop_statue", 7000.0, 0.8, -1, false], ["prop_lantern", 7550.0, 0.8, -1, false],
	["prop_statue", 7900.0, 0.85, -1, true], ["prop_shrine", 8320.0, 0.9, -1, false],
	["prop_graves", 8640.0, 0.85, -1, false], ["prop_graves", 9200.0, 0.9, -1, true], ["prop_banner", 9560.0, 0.9, -1, false],
	["prop_graves", 9980.0, 0.85, -1, false], ["prop_deadtree", 10260.0, 1.0, -1, true],
]


func _build_props() -> void:
	for pr in PROPS:
		var t := _tex(pr[0])
		if t == null:
			continue
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.scale = Vector2(pr[2], pr[2])
		s.flip_h = pr[4]
		s.position = Vector2(pr[1] - t.get_width() * pr[2] / 2.0, Game.GROUND_Y + 6 - t.get_height() * pr[2])
		s.z_index = pr[3]
		$Props.add_child(s)


func _add_sign(s: Dictionary) -> void:
	var t := _tex("prop_stele")
	if t:
		var sp := Sprite2D.new()
		sp.texture = t
		sp.centered = false
		sp.scale = Vector2(0.5, 0.5)
		sp.position = Vector2(s.x - t.get_width() * 0.25, Game.GROUND_Y + 4 - t.get_height() * 0.5)
		$Props.add_child(sp)


func _build_gate() -> void:
	var g := preload("res://scripts/level/end_gate.gd").new()
	g.position = Vector2(LevelData.END_X, Game.GROUND_Y)
	$Props.add_child(g)


# ------------------------------------------------------------------ runtime
func shake(amount: float, dur: float) -> void:
	if Game.args.has("noshake"):
		return
	_shake = maxf(_shake, amount)
	_shake_t = maxf(_shake_t, dur)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_update_camera(delta)
	_update_zone(false)
	_update_signs()
	if not _ending and Game.cleared.has("e8_elite") and player.global_position.x >= LevelData.END_X - 20 and not player.dead:
		_finish()


func _process(delta: float) -> void:
	_shake_t = maxf(0.0, _shake_t - delta)
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		_shake = 0.0
	cam.offset = off
	var vs := get_viewport().get_visible_rect().size
	var left := cam.global_position.x - vs.x / 2.0
	var dy := cam.global_position.y - (Game.GROUND_Y - 190)
	for l in bg_layers + fg_layers:
		var n = l.node
		if l.get("sky", false):
			continue
		var s: Sprite2D = n
		s.region_rect = Rect2(left * l.factor, 0, vs.x + 4, s.texture.get_height())
		s.position = Vector2(0, l.y - dy * l.yf + (vs.y - 720.0) * 0.5)


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
	var look := player.facing * 110.0
	var tx := clampf(player.global_position.x + look, lo, hi)
	_cam_x = lerpf(_cam_x, tx, minf(1.0, delta * 4.0))
	var ty := minf(Game.GROUND_Y - 190.0, player.global_position.y - 150.0)
	_cam_y = lerpf(_cam_y, ty, minf(1.0, delta * 3.0))
	cam.global_position = Vector2(_cam_x, _cam_y)


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
	# smooth atmosphere blend toward the current zone
	var z2: Dictionary = LevelData.ZONES[zone_idx]
	for l in bg_layers:
		var n: CanvasItem = l.node
		n.modulate = n.modulate.lerp(z2.tint, 0.02 if not force else 1.0)
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


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	Game.deaths += 1
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
	_cam_x = player.global_position.x
	await hud.fade_in(0.6)
	Game.show_hint("篝火余温尚在……再来。", 3.0)
	_respawning = false


func _finish() -> void:
	_ending = true
	player.controls_locked = true
	Sfx.play("ending_chime", 0.0)
	await hud.fade_out(1.6, Color(0.92, 0.86, 0.72))
	Game.finish_demo()
